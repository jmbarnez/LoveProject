local NodeMarket = {}

local function clamp(x, a, b) return math.max(a, math.min(b, x)) end

-- Return raw candles for a node
function NodeMarket.getCandles(node)
  return node and node.candles or {}
end

-- Return aggregated candles by intervalSeconds (1s if nil/<=1)
function NodeMarket.getAggregatedCandles(node, intervalSeconds)
  if not node then return {} end
  local candles = node.candles
  if not candles or #candles == 0 then return {} end
  if not intervalSeconds or intervalSeconds <= 1 then return candles end

  local interval = intervalSeconds
  local aggregated = {}
  local currentBucket = nil
  local currentO, currentH, currentL, currentC, currentV = nil, nil, nil, nil, 0

  for _, candle in ipairs(candles) do
    local bucket = math.floor(candle.t / interval) * interval
    if not currentBucket or bucket ~= currentBucket then
      -- Close previous bucket if exists
      if currentBucket then
        table.insert(aggregated, {
          o = currentO,
          h = currentH,
          l = currentL,
          c = currentC,
          v = currentV,
          t = currentBucket
        })
      end
      -- Start new bucket
      currentBucket = bucket
      currentO = candle.o
      currentH = candle.h
      currentL = candle.l
      currentC = candle.c
      currentV = candle.v
    else
      -- Update current bucket
      currentH = math.max(currentH, candle.h)
      currentL = math.min(currentL, candle.l)
      currentC = candle.c
      currentV = currentV + candle.v
    end
  end

  -- Add the last bucket
  if currentBucket then
    table.insert(aggregated, {
      o = currentO,
      h = currentH,
      l = currentL,
      c = currentC,
      v = currentV,
      t = currentBucket
    })
  end

  return aggregated
end

-- Return downsampled candles with simple slicing
function NodeMarket.getDownsampledCandles(node, intervalSeconds, targetCount)
  if not node then return {} end
  local agg = NodeMarket.getAggregatedCandles(node, intervalSeconds)
  if not targetCount or targetCount <= 0 then return agg end
  local n = #agg
  if n == 0 then return agg end
  local keep = math.min(n, targetCount)
  local slice = {}
  local start = math.max(1, n - keep + 1)
  for i = start, n do
    slice[#slice + 1] = agg[i]
  end
  return slice
end

-- Global candle aggregation width (seconds); fixed to 1s for consistent data
NodeMarket.candleWidth = 1.0
local MAX_CANDLES = 14400 -- up to 4 hours at 1s resolution

-- Global transaction history for all nodes
NodeMarket.globalTransactionHistory = {}

local function pick(list)
  return list[1 + math.random(#list - 1)]
end

local companies = {
  "Astra Dynamics", "Nova Labs", "Quark Systems", "PhotonX Industries",
  "VoltWorks", "Nebula Capital", "ChronoTech", "Lumos Foundry",
}

local palette = {
  {0.30, 0.85, 0.60, 1.0}, -- green
  {0.30, 0.70, 1.00, 1.0}, -- blue
  {0.95, 0.70, 0.25, 1.0}, -- amber
  {0.85, 0.50, 0.90, 1.0}, -- purple
  {0.95, 0.30, 0.40, 1.0}, -- red
  {0.40, 0.90, 0.90, 1.0}, -- cyan
}

local function simpleRandom(low, high)
  return low + math.random() * (high - low)
end

-- Simplified global state (just time)
function NodeMarket._updateGlobalState(dt)
  NodeMarket.state = NodeMarket.state or { time = 0 }
  local st = NodeMarket.state
  st.time = st.time + dt
end

local function makeNode(symbol, name, basePrice)
  local t = love.timer and love.timer.getTime() or os.time()
  local node = {
    symbol = symbol,
    name = name,
    company = pick(companies),
    color = palette[1 + ((#symbol + #name) % #palette)],
    candles = {},
    lastCandleT = math.floor(t / NodeMarket.candleWidth) * NodeMarket.candleWidth,
    price = basePrice,
    dayOpen = basePrice,
    dayHigh = basePrice,
    dayLow = basePrice,
    dayVolume = 0,
    orderRate = 1.0, -- trades per second
    nextOrderIn = simpleRandom(0.5, 2.0),
    -- Initial supply and market cap
    supply = 1e9,
    marketCap = basePrice * 1e9,
    liquidity = {
      bidAskSpread = 0.002,  -- Initial spread (0.2%)
      orderBookDepth = 1000000,  -- Base order book depth
      buyPressure = 0.5,  -- 0-1 value indicating buy/sell pressure
      volume24h = 0,
    },
    -- Simple trend model for gradual drifts
    mid = basePrice,
    trendTarget = basePrice,
    trendChangeIn = simpleRandom(10, 30), -- seconds until trend change
  }
  return node
end

-- Update candle data
local function _updateCandle(node, price, vol, when)
  local t = when or (love.timer and love.timer.getTime() or os.time())
  local width = NodeMarket.candleWidth or 1.0
  local bucket = math.floor(t / width) * width

  local last = node.candles[#node.candles]

  -- If the current bucket is ahead of the last candle's time, fill in the gap
  if not last or bucket > node.lastCandleT then
    local prevClose = last and last.c or price
    local startBucket = last and (node.lastCandleT + width) or bucket

    for b = startBucket, bucket, width do
      table.insert(node.candles, { o = prevClose, h = prevClose, l = prevClose, c = prevClose, v = 0, t = b })
      if #node.candles > MAX_CANDLES then table.remove(node.candles, 1) end
    end

    -- Now update the newest candle with the trade
    local candle = node.candles[#node.candles]
    if candle then
      candle.h = math.max(candle.h, price)
      candle.l = math.min(candle.l, price)
      candle.c = price
      candle.v = (candle.v or 0) + (vol or 0)
    end

    node.lastCandleT = bucket
  else
    -- Update the existing candle for the current time bucket
    last.h = math.max(last.h, price)
    last.l = math.min(last.l, price)
    last.c = price
    last.v = (last.v or 0) + (vol or 0)
  end
end

-- Processes a new order - executes directly
function NodeMarket.submitOrder(symbol, orderType, quantity, price, isLimitOrder)
  local node = NodeMarket.getNodeBySymbol(symbol)
  if not node then return false, "Node not found" end
  if not quantity or quantity <= 0 then return false, "Invalid quantity" end

  local executedPrice = price

  if not isLimitOrder then
    -- Market order - use current market price with small spread simulation
    if orderType == "BUY" then
      executedPrice = node.price * 1.001  -- Small spread for market buy
    else
      executedPrice = node.price * 0.999  -- Small spread for market sell
    end
  else
    -- Limit order - use specified price
    if not price or price <= 0 then return false, "Invalid price for limit order" end
    executedPrice = price
  end

  -- Update the node's price and volume to reflect the trade
  node.price = executedPrice
  node.dayHigh = math.max(node.dayHigh, executedPrice)
  node.dayLow = math.min(node.dayLow, executedPrice)
  node.dayVolume = node.dayVolume + quantity
  node.marketCap = node.price * node.supply
  node.liquidity.volume24h = node.dayVolume  -- Simple proxy

  -- Update candle data
  local now = love.timer and love.timer.getTime() or os.time()
  _updateCandle(node, executedPrice, quantity, now)

  -- Record transaction in global history
  local transaction = {
    type = orderType,
    symbol = symbol,
    quantity = quantity,
    price = executedPrice,
    timestamp = os.time(),
    isPlayerTrade = true  -- Mark as player trade
  }
  table.insert(NodeMarket.globalTransactionHistory, transaction)

  return true, "Order executed successfully", executedPrice
end

-- Public API
function NodeMarket.init()
  if NodeMarket._inited then return end
  math.randomseed(os.time() % 2147483647)
  -- Ensure default candle width is set
  NodeMarket.candleWidth = NodeMarket.candleWidth or 1.0
  local nodes = {
    makeNode("AST", "AstraNode", simpleRandom(40, 120)),
    makeNode("NOVA", "NovaNode", simpleRandom(8, 30)),
    makeNode("QRP", "QuarkNode", simpleRandom(0, 2)),
    makeNode("PHN", "PhotonNode", simpleRandom(50, 180)),
    makeNode("VLT", "VoltiumNode", simpleRandom(2, 10)),
    makeNode("NEB", "NebulaNode", simpleRandom(5, 18)),
    makeNode("CRN", "ChronosNode", simpleRandom(20, 60)),
    makeNode("LUM", "LumosNode", simpleRandom(1, 8)),
  }
  NodeMarket.nodes = nodes
  -- Initialize global state
  NodeMarket.state = {
    time = 0,
  }
  NodeMarket._inited = true
end

function NodeMarket.update(dt)
  if not NodeMarket._inited then NodeMarket.init() end
  local now = love.timer and love.timer.getTime() or os.time()
  NodeMarket._updateGlobalState(dt)
  for _, c in ipairs(NodeMarket.nodes) do
    -- Simple trend evolution
    c.trendChangeIn = c.trendChangeIn - dt
    if c.trendChangeIn <= 0 then
      -- Pick a new trend target with small random change
      local pct = (math.random() - 0.5) * 0.02  -- +/-1% change
      c.trendTarget = math.max(0.01, c.trendTarget * (1 + pct))
      c.trendChangeIn = simpleRandom(10, 30)  -- 10-30s trends
    end
    -- Ease mid toward target
    c.mid = c.mid + (c.trendTarget - c.mid) * 0.05 * dt

    c.nextOrderIn = c.nextOrderIn - dt
    while c.nextOrderIn <= 0 do
      -- Simple volatility (base 0.5%)
      local baseVol = 0.005
      local vol = baseVol * (1 + (c.liquidity.buyPressure - 0.5) * 0.5)  -- Pressure slightly affects vol
      -- Random change
      local change = (math.random() - 0.5) * vol * 2  -- +/- vol
      -- Add trend pull
      local trendInfluence = ((c.mid - c.price) / c.price) * 0.001  -- Small pull to mid
      change = change + trendInfluence
      -- Clamp to prevent extremes
      change = clamp(change, -0.01, 0.01)  -- Max 1% per tick

      local simulatedPrice = c.price * (1 + change)
      simulatedPrice = math.max(0.01, simulatedPrice)

      -- Update price
      c.price = simulatedPrice
      c.dayHigh = math.max(c.dayHigh, c.price)
      c.dayLow = math.min(c.dayLow, c.price)
      c.marketCap = c.price * c.supply
      c.liquidity.volume24h = c.dayVolume  -- Simple proxy

      -- Simple volume, higher on bigger moves
      local volume = simpleRandom(100, 1000) * (1 + math.abs(change) * 100)
      -- Small chance for large volume influx
      if math.random() < 0.01 then
        volume = volume * simpleRandom(5, 10)
      end
      c.dayVolume = c.dayVolume + volume

      -- Update candles
      _updateCandle(c, c.price, volume, now)

      -- Update buy/sell pressure based on simulated order direction
      local isBuy = math.random() < c.liquidity.buyPressure
      local pressureDelta = (isBuy and 0.01 or -0.01)
      c.liquidity.buyPressure = clamp(c.liquidity.buyPressure + pressureDelta, 0.1, 0.9)
      -- Mean-revert pressure slowly
      c.liquidity.buyPressure = c.liquidity.buyPressure + (0.5 - c.liquidity.buyPressure) * 0.005

      -- Record simulated AI transaction
      local aiQuantity = volume / c.price
      local transaction = {
        type = isBuy and "BUY" or "SELL",
        symbol = c.symbol,
        quantity = aiQuantity,
        price = c.price,
        timestamp = os.time(),
        isPlayerTrade = false
      }
      table.insert(NodeMarket.globalTransactionHistory, transaction)

      -- Schedule next simulated trade
      c.nextOrderIn = c.nextOrderIn + simpleRandom(0.5, 2.0)
    end

    -- Ensure candles are up-to-date even if no trades
    _updateCandle(c, c.price, 0, now)
  end
end

function NodeMarket.getNodes()
  if not NodeMarket._inited then NodeMarket.init() end
  return NodeMarket.nodes
end

function NodeMarket.getNode(index)
  local list = NodeMarket.getNodes()
  return list[index]
end

function NodeMarket.getNodeBySymbol(symbol)
  if not NodeMarket.nodes then return nil end
  for _, c in ipairs(NodeMarket.nodes) do
    if c.symbol == symbol then
      return c
    end
  end
  return nil
end

function NodeMarket.getStats(node)
  if not node then return nil end
  local last = node.candles[#node.candles]
  local price = last and last.c or node.price
  local change = node.dayOpen > 0 and ((price - node.dayOpen) / node.dayOpen) * 100 or 0
  return {
    price = price,
    changePct = change,
    dayHigh = node.dayHigh,
    dayLow = node.dayLow,
    dayVolume = node.dayVolume,
    marketCap = (node.supply or 0) * price,
    sigma = 0.005,  -- Fixed base volatility
    regimeState = 0,
    volMultiplier = 1.0,
  }
end

function NodeMarket.getCandleWidth()
  return NodeMarket.candleWidth or 1.0
end

-- Get all transactions for a specific node symbol
function NodeMarket.getNodeTransactions(symbol)
  local nodeTransactions = {}
  for _, transaction in ipairs(NodeMarket.globalTransactionHistory) do
    if transaction.symbol == symbol then
      table.insert(nodeTransactions, transaction)
    end
  end
  return nodeTransactions
end

-- Get all global transactions
function NodeMarket.getAllTransactions()
  return NodeMarket.globalTransactionHistory
end

-- Compute global market statistics (totals across all nodes)
function NodeMarket.getGlobalStats()
  if not NodeMarket._inited then NodeMarket.init() end
  local totalCap = 0
  local totalVol24h = 0
  
  for _, c in ipairs(NodeMarket.nodes or {}) do
    totalCap = totalCap + (c.marketCap or (c.price or 0) * (c.supply or 0))
    if c.liquidity and c.liquidity.volume24h then
      totalVol24h = totalVol24h + c.liquidity.volume24h
    end
  end
  
  return {
    totalMarketCap = totalCap,
    totalVolume24h = totalVol24h,
    nodeCount = #(NodeMarket.nodes or {})
  }
end

return NodeMarket
