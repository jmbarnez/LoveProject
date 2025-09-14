local NodeMarket = {}

local function clamp(x, a, b) return math.max(a, math.min(b, x)) end

-- Global candle aggregation width (seconds); fixed to 1s for consistent data
NodeMarket.candleWidth = 1.0
local MAX_CANDLES = 1200 -- up to 20 minutes at 1s resolution

-- Global transaction history for all nodes
NodeMarket.globalTransactionHistory = {}


local function pick(list)
  return list[1 + (math.random(#list))]
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

local function expovariate(rate)
  local u = math.random()
  if u <= 1e-12 then u = 1e-12 end
  return -math.log(u) / rate
end

-- Gaussian helper for smoother distributions
local function gaussian(mu, sigma)
  local u1 = math.random()
  local u2 = math.random()
  if u1 <= 1e-12 then u1 = 1e-12 end
  local z0 = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
  return mu + z0 * (sigma or 1)
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
    orderRate = 2.5 + math.random() * 1.5, -- trades per second
    nextOrderIn = expovariate(3.0),
    supply = (math.random(20, 2000)) * 1e6, -- circulating supply (fictional)
  }
  -- Smooth trend model
  node.mid = basePrice
  node.drift = 0.0
  node.vol = basePrice * 0.0015
  node.trendTarget = basePrice
  node.trendChangeIn = 2.0 + math.random() * 3.0

  -- Start with no initial candles - let the chart build from live data
  node.dayOpen = basePrice
  return node
end


function NodeMarket._updateCandle(node, price, vol, when)
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
    last = node.candles[#node.candles]
    if last then
      last.h = math.max(last.h, price)
      last.l = math.min(last.l, price)
      last.c = price
      last.v = (last.v or 0) + (vol or 0)
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


-- Processes a new order - now executes directly without order book
function NodeMarket.submitOrder(symbol, orderType, quantity, price, isLimitOrder)
  local node = nil
  for _, n in ipairs(NodeMarket.nodes) do
    if n.symbol == symbol then
      node = n
      break
    end
  end

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

  -- Update candle data
  local now = love.timer and love.timer.getTime() or os.time()
  NodeMarket._updateCandle(node, executedPrice, quantity, now)

  -- Record transaction in global history
  local transaction = {
    type = (isLimitOrder and (orderType == "BUY" and "LIMIT_BUY" or "LIMIT_SELL") or orderType),
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
    makeNode("AST", "AstraNode", math.random(40, 120) + math.random()),
    makeNode("NOVA", "NovaNode", math.random(8, 30) + math.random()),
    makeNode("QRP", "QuarkNode", math.random(0, 2) + math.random()),
    makeNode("PHN", "PhotonNode", math.random(50, 180) + math.random()),
    makeNode("VLT", "VoltiumNode", math.random(2, 10) + math.random()),
    makeNode("NEB", "NebulaNode", math.random(5, 18) + math.random()),
    makeNode("CRN", "ChronosNode", math.random(20, 60) + math.random()),
    makeNode("LUM", "LumosNode", math.random(1, 8) + math.random()),
  }
  NodeMarket.nodes = nodes
  NodeMarket._inited = true
end

function NodeMarket.update(dt)
  if not NodeMarket._inited then NodeMarket.init() end
  local now = love.timer and love.timer.getTime() or os.time()
  for _, c in ipairs(NodeMarket.nodes) do
    -- Smooth trend evolution
    c.trendChangeIn = c.trendChangeIn - dt
    if c.trendChangeIn <= 0 then
      -- pick a new distant trend target with very small random change
      local pct = gaussian(0, 0.002)
      c.trendTarget = math.max(c.tick or 0.001, c.trendTarget * (1 + pct))
      c.trendChangeIn = 2.0 + math.random() * 3.0
    end
    -- Ease mid toward target with small noise
    c.mid = c.mid + (c.trendTarget - c.mid) * (0.6 * dt)
    c.mid = math.max(c.tick or 0.001, c.mid * (1 + gaussian(0, 0.0006)))

    c.nextOrderIn = c.nextOrderIn - dt
    while c.nextOrderIn <= 0 do
      -- AI trading simulation - just affects price movement
      local orderSize = math.random(4, 20) * 10
      local priceSkew = gaussian(0, 0.0015)
      local simulatedPrice = c.mid * (1 + priceSkew)

      -- Simulate market activity by updating price and volume
      c.price = simulatedPrice
      c.dayHigh = math.max(c.dayHigh, simulatedPrice)
      c.dayLow = math.min(c.dayLow, simulatedPrice)
      c.dayVolume = c.dayVolume + orderSize * 0.1  -- Smaller volume impact for simulation

      -- Update candles with simulated trading
      NodeMarket._updateCandle(c, simulatedPrice, orderSize * 0.1, now)

      -- Record simulated AI transaction in global history (randomly decide buy/sell)
      local tradeType = math.random() > 0.5 and "BUY" or "SELL"
      local transaction = {
        type = tradeType,
        symbol = c.symbol,
        quantity = orderSize * 0.1,
        price = simulatedPrice,
        timestamp = os.time(),
        isPlayerTrade = false  -- Mark as AI trade
      }
      table.insert(NodeMarket.globalTransactionHistory, transaction)

      -- Schedule next simulated trade
      local rate = c.orderRate
      c.nextOrderIn = c.nextOrderIn + expovariate(rate)
    end
    
    -- Ensure candles are up-to-date even if there are no trades
    NodeMarket._updateCandle(c, c.price, 0, now)
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
  }
end

function NodeMarket.getCandles(node)
  return node.candles
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

return NodeMarket
