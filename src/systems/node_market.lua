local NodeMarket = {}
local TechnicalIndicators = require("src.systems.technical_indicators")

local function clamp(x, a, b) return math.max(a, math.min(b, x)) end

-- Apply time-based exponential decay to rolling volumes and then add value
local function applyRollingVolume(c, addValue, now)
  if not c or not c.liquidity then return end
  local liq = c.liquidity
  local last = liq.lastVolUpdate or now
  local dt = math.max(0, (now - last))
  -- Windows in seconds
  local w24 = 86400
  local w7 = 604800
  local w30 = 2592000
  -- Decay factors
  local d24 = math.exp(-dt / w24)
  local d7 = math.exp(-dt / w7)
  local d30 = math.exp(-dt / w30)
  liq.volume24h = (liq.volume24h or 0) * d24 + (addValue or 0)
  liq.volume7d = (liq.volume7d or 0) * d7 + (addValue or 0)
  liq.volume30d = (liq.volume30d or 0) * d30 + (addValue or 0)
  liq.lastVolUpdate = now
end


-- Return raw candles for a node
function NodeMarket.getCandles(node)
  return node and node.candles or {}
end

-- Update liquidity calculations for a node
local function updateLiquidity(c)
  if not c or not c.liquidity then return end
  
  -- Liquidity depth recalculation using cap EMA
  local emaAlpha = 0.01
  c.liquidity.capEMA = (c.liquidity.capEMA or c.marketCap)
  c.liquidity.capEMA = c.liquidity.capEMA * (1 - emaAlpha) + c.marketCap * emaAlpha
  local baseLiquidityRatio = (c.liquidity.baseRatio or 0.10)
  local volAdjustment = 1 + ((c.garch and c.garch.sigma or 0.1) * 15)
  volAdjustment = math.max(0.85, math.min(1.3, volAdjustment))
  local volume7dMA = (c.liquidity.volume7d or 0) / 7
  local volumeTrend = volume7dMA > 0 and ((c.liquidity.volume24h or 0) / math.max(1, volume7dMA)) or 1
  volumeTrend = math.max(0.9, math.min(1.1, volumeTrend))
  local capRef = math.max(1, c.liquidity.capEMA)
  local unclampedTarget = capRef * baseLiquidityRatio * volAdjustment * volumeTrend
  local minLiquidity = capRef * 0.001
  local maxLiquidity = capRef * 0.10
  local targetDepth = math.max(minLiquidity, math.min(maxLiquidity, unclampedTarget))
  
  -- Update order book depth with smoothing
  local currentDepth = c.liquidity.orderBookDepth or targetDepth
  local maxStep = math.max(1, currentDepth * 0.02)
  local deltaDepth = targetDepth - currentDepth
  if deltaDepth > maxStep then 
    deltaDepth = maxStep 
  elseif deltaDepth < -maxStep then 
    deltaDepth = -maxStep 
  end
  c.liquidity.orderBookDepth = currentDepth + deltaDepth
  
  return c.liquidity.orderBookDepth
end

-- Update buy/sell pressure based on price movement and trade size
local function updateMarketPressure(c, priceChange, tradeSize)
  if not c or not c.liquidity then return end
  local pressureChange = (priceChange > 0 and 0.01 or -0.01) * math.sqrt(tradeSize or 1)
  c.liquidity.buyPressure = clamp((c.liquidity.buyPressure or 0.5) + pressureChange, 0.1, 0.9)
end

-- Return raw candles
function NodeMarket.getCandles(node)
  return node.candles
end

-- Return aggregated candles by intervalSeconds (1s if nil/<=1)
function NodeMarket.getAggregatedCandles(node, intervalSeconds)
  if not node then return {} end
  local candles = node.candles
  if not candles or #candles == 0 then return {} end
  if not intervalSeconds or intervalSeconds <= 1 then return candles end
  return TechnicalIndicators.aggregateCandles(candles, intervalSeconds)
end

-- Return downsampled candles with simple caching keyed by symbol/interval/targetCount and last candle timestamp
function NodeMarket.getDownsampledCandles(node, intervalSeconds, targetCount)
  if not node then return {} end
  local agg = NodeMarket.getAggregatedCandles(node, intervalSeconds)
  if not targetCount or targetCount <= 0 then return agg end
  -- Return a stable time-anchored slice of the most recent aggregated candles.
  -- Avoid count-based regrouping which causes the first visible candle to shift.
  local n = #agg
  if n == 0 then return agg end
  local keep = math.min(n, targetCount + 256) -- small buffer for panning without regrouping
  local start = math.max(1, n - keep + 1)
  local slice = {}
  for i = start, n do slice[#slice+1] = agg[i] end
  return slice
end

-- Global candle aggregation width (seconds); fixed to 1s for consistent data
NodeMarket.candleWidth = 1.0
local MAX_CANDLES = 14400 -- up to 4 hours at 1s resolution

-- Global transaction history for all nodes
NodeMarket.globalTransactionHistory = {}
NodeMarket._candleCache = {}


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

-- Global/sector factor model with news/events and activity cycle
function NodeMarket._updateGlobalState(dt)
  NodeMarket.state = NodeMarket.state or { time = 0, sectors = 3 }
  local st = NodeMarket.state
  st.time = (st.time or 0) + dt
  st.sectors = st.sectors or 3

  -- Activity cycle (e.g., liquidity/activity waves)
  local period = 300 -- ~5 minutes
  local phase = (st.time % period) / period
  st.activityCycle = 1 + 0.30 * math.sin(2 * math.pi * phase)

  -- Mean-reverting global and sector drifts (Ornstein-Uhlenbeck)
  st.globalDrift = st.globalDrift or 0.0
  st.globalVolBoost = st.globalVolBoost or 0.0
  st.liqStress = st.liqStress or 0.0
  st.sectorDrift = st.sectorDrift or {}
  st.sectorVol = st.sectorVol or {}
  local theta = 0.6
  local sig = 0.05
  local sdt = math.sqrt(math.max(dt, 1e-4))
  st.globalDrift = st.globalDrift + (-theta * st.globalDrift) * dt + gaussian(0, sig) * sdt * 0.01
  for i = 1, (st.sectors or 3) do
    local sd = st.sectorDrift[i] or 0
    st.sectorDrift[i] = sd + (-theta * sd) * dt + gaussian(0, sig) * sdt * 0.01
    -- decay sector-specific vol boosts
    st.sectorVol[i] = math.max(0, (st.sectorVol[i] or 0) + (-1.5 * (st.sectorVol[i] or 0)) * dt)
  end

  -- News events: occasional global volatility and liquidity stress bursts
  st.nextNewsIn = st.nextNewsIn or (60 + math.random(180))
  st.newsRemaining = st.newsRemaining or 0
  if st.newsRemaining > 0 then
    st.newsRemaining = st.newsRemaining - dt
    if st.newsRemaining <= 0 then
      st.globalVolBoost = 0
      st.liqStress = 0
    end
  else
    st.nextNewsIn = st.nextNewsIn - dt
    if st.nextNewsIn <= 0 then
      st.newsRemaining = 10 + math.random(20)
      st.nextNewsIn = 120 + math.random(240)
      st.globalVolBoost = 0.5 + math.random() * 0.8
      st.liqStress = 0.2 + math.random() * 0.3
      local sidx = 1 + math.floor(math.random() * (st.sectors or 3))
      st.sectorVol[sidx] = (st.sectorVol[sidx] or 0) + 0.5 + math.random()
      st.sectorDrift[sidx] = (st.sectorDrift[sidx] or 0) + (math.random() * 0.02 - 0.01)
    end
  end
end

local function makeNode(symbol, name, basePrice)
  local t = love.timer and love.timer.getTime() or os.time()
  local node = {
    symbol = symbol,
    name = name,
    company = pick(companies),
    color = palette[1 + ((#symbol + #name) % #palette)],
    sector = math.random(1, (NodeMarket.state and NodeMarket.state.sectors) or 3),
    candles = {},
    lastCandleT = math.floor(t / NodeMarket.candleWidth) * NodeMarket.candleWidth,
    price = basePrice,
    dayOpen = basePrice,
    dayHigh = basePrice,
    dayLow = basePrice,
    dayVolume = 0,
    orderRate = 4.0 + math.random() * 3.0, -- increased trades per second
    activityFactor = 0.8 + math.random() * 0.7, -- per-node activity scaler (0.8x - 1.5x)
    nextOrderIn = expovariate(3.0),
    -- Initial supply and market cap
    supply = 1e9,  -- Fixed supply for now
    
    -- Market cap and liquidity metrics
    marketCap = 1e9,  -- Starting market cap of 1 billion
    liquidity = {
      bidAskSpread = 0.002,  -- Initial spread (0.2%)
      orderBookDepth = 1000000,  -- Increased base order book depth (10x)
      slippageFactor = 1.0,  -- Multiplier for price impact
      lastTradeSize = 0,  -- Size of last trade
      buyPressure = 0.5,  -- 0-1 value indicating buy/sell pressure
      volume24h = 0,  -- Will be calculated from actual trades
      volume7d = 0,   -- Will be calculated from actual trades
      volume30d = 0,  -- Will be calculated from actual trades
      -- Long-term market cap EMA to stabilize liquidity sizing
      capEMA = 1e9,
      -- Per-node base liquidity ratio (10%-25% of cap)
      baseRatio = 0.10 + math.random() * 0.15,
      -- Timestamp of last rolling volume update (same timebase as 'now')
      lastVolUpdate = t,
    },
    
    -- RSI parameters (14-period RSI) with Wilder smoothing
    rsi = {
      period = 14,
      avgGain = 0,
      avgLoss = 0,
      value = 50,  -- Neutral RSI starts at 50
      lastPrice = basePrice,
      warmupCount = 0,
    },
    
    -- GARCH(1,1) model parameters
    garch = {
      -- Long-term average volatility (annualized)
      omega = 0.04 / 365, 
      -- GARCH coefficient (volatility clustering)
      alpha = 0.1 + math.random() * 0.1, 
      -- ARCH coefficient (shock persistence)
      beta = 0.85 + math.random() * 0.1,
      -- Current conditional volatility (std dev)
      sigma = 0.02,
      -- Previous squared return
      lastReturn2 = 0,
      -- Volatility mean reversion speed
      meanReversion = 0.05 + math.random() * 0.05
    },
    
    -- Market regime state
    regime = {
      -- Current volatility regime (0 = normal, 1 = high, -1 = low)
      state = 0,
      -- Time in current regime
      timeInRegime = 0,
      -- Base volatility multiplier for current regime
      volMultiplier = 1.0,
      -- Time until next regime change (seconds)
      nextRegimeChange = 3600 + math.random(3600) -- 1-2 hours
    }
  }
  
  -- Ensure stationarity: keep alpha+beta < 0.98
  do
    local s = node.garch.alpha + node.garch.beta
    if s > 0.98 then
      local scale = 0.98 / s
      node.garch.alpha = node.garch.alpha * scale
      node.garch.beta = node.garch.beta * scale
    end
  end
  
  -- Initialize GARCH model with some historical data
  for i = 1, 100 do
    local ts = 1.0 / (252 * 24 * 60 * 60)
    -- simulate a tiny step to warm sigma
    local retStep = gaussian(0, 1) * node.garch.sigma * math.sqrt(ts)
    local sigma2 = node.garch.omega * ts + node.garch.alpha * (retStep^2) + node.garch.beta * (node.garch.sigma^2)
    sigma2 = clamp(sigma2, 1e-10, 0.5)
    node.garch.sigma = math.sqrt(sigma2)
  end
  
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
    local candle = node.candles[#node.candles]
    if candle then
      candle.h = math.max(candle.h, price)
      candle.l = math.min(candle.l, price)
      candle.c = price
      candle.v = (candle.v or 0) + (vol * 10)  -- 10x volume for candles
    end
    
    node.lastCandleT = bucket
  else
    -- Update the existing candle for the current time bucket (10x volume)
    last.h = math.max(last.h, price)
    last.l = math.min(last.l, price)
    last.c = price
    last.v = (last.v or 0) + ((vol or 0) * 10)  -- 10x volume
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

  -- Update candle data and rolling volumes
  local now = love.timer and love.timer.getTime() or os.time()
  NodeMarket._updateCandle(node, executedPrice, quantity, now)
  applyRollingVolume(node, quantity * executedPrice, now)

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
  -- Initialize global state (no seeding; start from scratch each run)
  NodeMarket.state = {
    time = 0,
    sectors = 3,
    activityCycle = 1.0,
    globalDrift = 0.0,
    globalVolBoost = 0.0,
    liqStress = 0.0,
    nextNewsIn = 60 + math.random(180),
    newsRemaining = 0,
    sectorDrift = {0, 0, 0},
    sectorVol = {0, 0, 0},
  }
  NodeMarket._inited = true
end

function NodeMarket.update(dt)
  if not NodeMarket._inited then NodeMarket.init() end
  local now = love.timer and love.timer.getTime() or os.time()
  NodeMarket._updateGlobalState(dt)
  local st = NodeMarket.state or {}
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

    -- Update market regime
    c.regime.timeInRegime = c.regime.timeInRegime + dt
    if c.regime.timeInRegime >= c.regime.nextRegimeChange then
      -- Change to a new regime
      c.regime.state = math.random(-1, 1)
      c.regime.timeInRegime = 0
      c.regime.nextRegimeChange = 1800 + math.random(5400) -- 0.5 to 2 hours
      
      -- Set volatility multiplier based on new regime
      if c.regime.state > 0 then
        -- High volatility regime (tempered)
        c.regime.volMultiplier = 1.2 + math.random() * 0.3
      elseif c.regime.state < 0 then
        -- Low volatility regime (tempered)
        c.regime.volMultiplier = 0.6 + math.random() * 0.2
      else
        -- Normal volatility
        c.regime.volMultiplier = 0.8 + math.random() * 0.2
      end
    end
    
    c.nextOrderIn = c.nextOrderIn - dt
    while c.nextOrderIn <= 0 do
      -- Calculate time step in trading years (1s)
      local timeStep = 1.0 / (252 * 24 * 60 * 60)
      
      -- Enhanced GARCH volatility with more dynamic parameters
      local epsilon = gaussian(0, 1)
      local sigma = c.garch.sigma
      
      -- More reactive GARCH parameters
      local alpha = 0.1 + math.random() * 0.1  -- More responsive to recent shocks
      local beta = 0.85 + math.random() * 0.1  -- Higher persistence
      local omega = 0.0001 * (0.8 + math.random() * 0.4)  -- Base volatility level
      
      local returnStep = epsilon * sigma * math.sqrt(timeStep)
      local sigma2 = omega * timeStep + alpha * (returnStep^2) + beta * (sigma^2)
      sigma2 = clamp(sigma2, 1e-8, 1.0)  -- Allow higher max volatility
      c.garch.sigma = math.sqrt(sigma2)
      
      -- More dynamic regime-based volatility with global/sector boosts
      local volScale = 1 + math.max(0, math.min(1.5, (st.globalVolBoost or 0) + ((st.sectorVol and st.sectorVol[c.sector]) or 0)))
      local regimeVol = c.garch.sigma * (c.regime.volMultiplier * (0.9 + math.random() * 0.2)) * volScale
      
      -- Enhanced price movement with momentum and mean reversion
      local meanRev = 0.3 * math.log((c.mid > 0 and c.mid or c.price) / (c.price > 0 and c.price or 1))
      local drift = (c.drift * 1.5 + meanRev + (st.globalDrift or 0) + ((st.sectorDrift and st.sectorDrift[c.sector]) or 0)) * timeStep
      
      -- Add occasional larger moves (fat tails)
      local shockSize = 1.0
      if math.random() < 0.01 then  -- 1% chance of a larger move
        shockSize = 2.0 + math.random() * 3.0  -- 2-5x normal move
      end
      
      local shock = gaussian(0, 1) * regimeVol * math.sqrt(timeStep) * shockSize
      local priceChange = math.exp(drift + shock) - 1.0
      
      -- Dynamic price limits based on volatility
      local maxMove = 0.01 + (regimeVol * 2)  -- Allow larger moves in high vol
      priceChange = clamp(priceChange, -maxMove, maxMove)
      
      -- RSI smoothing (Wilder)
      local delta = c.price - (c.rsi.lastPrice or c.price)
      local gain = delta > 0 and delta or 0
      local loss = delta < 0 and (-delta) or 0
      if c.rsi.warmupCount < c.rsi.period then
        c.rsi.warmupCount = c.rsi.warmupCount + 1
        -- incremental average for warmup
        c.rsi.avgGain = ((c.rsi.avgGain * (c.rsi.warmupCount - 1)) + gain) / c.rsi.warmupCount
        c.rsi.avgLoss = ((c.rsi.avgLoss * (c.rsi.warmupCount - 1)) + loss) / c.rsi.warmupCount
      else
        c.rsi.avgGain = (c.rsi.avgGain * (c.rsi.period - 1) + gain) / c.rsi.period
        c.rsi.avgLoss = (c.rsi.avgLoss * (c.rsi.period - 1) + loss) / c.rsi.period
      end
      local rs = (c.rsi.avgLoss > 1e-12) and (c.rsi.avgGain / c.rsi.avgLoss) or 100
      c.rsi.value = 100 - (100 / (1 + rs))
      c.rsi.lastPrice = c.price

      -- RSI influence: small bias, stronger only beyond 70/30
      local rsiScore = (c.rsi.value - 50) / 50  -- [-1,1]
      local rsiEffectMax = 0.006  -- 0.6% max influence
      local intensity = math.abs(c.rsi.value - 50) >= 20 and 1.0 or 0.5  -- full beyond 70/30
      local rsiFactor = -rsiScore * rsiEffectMax * intensity
      
      -- Calculate new price with momentum, mean reversion, and RSI factor
      -- Increased and variable order sizes with occasional block trades
      local orderSize = math.random(20, 120) * (10 * (c.activityFactor or 1.0))
      if math.random() < 0.05 then
        orderSize = orderSize * (2.0 + math.random() * 3.0)
      end
      local volumeImpact = (orderSize / 1e6) * 0.01 -- Slightly increased impact for larger volumes
      local simulatedPrice = c.price * (1 + priceChange + volumeImpact + rsiFactor)
      
      -- Prevent negative prices
      simulatedPrice = math.max(0.01, simulatedPrice)
      
      -- Compute trade size and instantaneous price impact against current depth
      local tradeSize = orderSize * 0.1
      local obDepth = math.max(1, (c.liquidity and c.liquidity.orderBookDepth) or 1)
      local priceImpact = ((tradeSize * simulatedPrice) / obDepth) * ((c.liquidity and c.liquidity.slippageFactor) or 1.0)

      -- Update price with micro-structure noise and liquidity impact
      local noise = gaussian(0, 0.0005)  -- Small random noise
      local liquidityImpact = priceImpact * (math.random() > 0.5 and 1 or -1)
      c.price = simulatedPrice * (1 + noise + liquidityImpact)
      
      -- Update trading volume metrics using time-based decay
      c.liquidity.lastTradeSize = tradeSize
      applyRollingVolume(c, tradeSize * c.price, now)
      
      -- Update buy/sell pressure (0 = all sells, 1 = all buys)
      local pressureChange = (priceChange > 0 and 0.01 or -0.01) * math.sqrt(tradeSize)
      c.liquidity.buyPressure = clamp((c.liquidity.buyPressure or 0.5) + pressureChange, 0.1, 0.9)
      
      -- Update high/low with some additional randomness
      local tickSize = 0.01  -- Minimum price movement
      c.price = math.floor(c.price / tickSize + 0.5) * tickSize  -- Round to nearest tick
      
      c.dayHigh = math.max(c.dayHigh, c.price)
      c.dayLow = math.min(c.dayLow, c.price)

      -- Update market cap based on current price and supply
      c.marketCap = c.price * c.supply
      
      -- Let the price move more freely by not trying to maintain a specific market cap
      -- The market cap will naturally fluctuate with price changes

      -- Update bid-ask spread based on recent volatility and depth
      c.liquidity.bidAskSpread = math.max(0.0005, math.min(0.05,
          c.garch.sigma * 5 * (1 + 1 / (1 + (c.liquidity.orderBookDepth or 1) / 1000000)) * (1 + (st.liqStress or 0))
      ))

      -- Recalculate order book depth using a stabilized market cap (EMA) and activity
      -- Maintain a long-term market cap EMA to avoid runaway liquidity growth
      local emaAlpha = 0.01  -- slow EMA so depth follows regime, not noise
      if not c.liquidity.capEMA or c.liquidity.capEMA <= 0 then c.liquidity.capEMA = c.marketCap end
      c.liquidity.capEMA = c.liquidity.capEMA * (1 - emaAlpha) + c.marketCap * emaAlpha

      -- Base liquidity ratio varies per node (10%-25% of cap)
      local baseLiquidityRatio = (c.liquidity and c.liquidity.baseRatio) or 0.10

      -- Reduce volatility impact on liquidity and clamp it
      local volAdjustment = 1 + (c.garch.sigma * 15)
      volAdjustment = math.max(0.85, math.min(1.3, volAdjustment))

      -- Smoother volume trend calculation (7-day moving average), lightly bounded
      local volume7dMA = (c.liquidity.volume7d or 0) / 7
      local volumeTrend = volume7dMA > 0 and ((c.liquidity.volume24h or 0) / math.max(1, volume7dMA)) or 1
      volumeTrend = math.max(0.9, math.min(1.1, volumeTrend))

      -- Calculate target depth based on cap EMA
      local capRef = math.max(1, c.liquidity.capEMA)
      local unclampedTarget = capRef * baseLiquidityRatio * volAdjustment * volumeTrend

      -- Clamp target liquidity to a realistic band relative to cap EMA
      local minLiquidity = capRef * 0.001    -- 0.1% floor
      local maxLiquidity = capRef * 0.10     -- 10% ceiling
      local targetDepth = math.max(minLiquidity, math.min(maxLiquidity, unclampedTarget))

      -- Transition with a bounded per-step change to prevent drift
      local currentDepth = c.liquidity.orderBookDepth or targetDepth
      local maxStep = math.max(1, currentDepth * 0.02)  -- limit change to 2% per update
      local delta = targetDepth - currentDepth
      if delta > maxStep then delta = maxStep elseif delta < -maxStep then delta = -maxStep end
      c.liquidity.orderBookDepth = currentDepth + delta
      
      -- Enhanced volume simulation with doubled base volume and occasional spikes
      local volumeMultiplier = 2.0  -- Double the base volume
      
      -- Larger volume on significant price moves
      if math.abs(priceChange) > regimeVol * 2 then
        volumeMultiplier = volumeMultiplier * (2.0 + math.random() * 3.0)  -- 2x-5x on large moves
      end
      
      -- 20% chance of a volume spike (unrelated to price movement)
      if math.random() < 0.2 then
        volumeMultiplier = volumeMultiplier * (5.0 + math.random() * 10.0)  -- 5x-15x spike
      end
      
      -- Volume is also higher during high volatility
      local volFactor = 1.0 + (c.garch.sigma * 10)  -- 1x to 4x based on volatility
      volumeMultiplier = volumeMultiplier * volFactor
      
      -- Calculate volume based on order size and multiplier
      local volumeToAdd = orderSize * volumeMultiplier
      c.dayVolume = (c.dayVolume or 0) + volumeToAdd
      
      -- Update candles with finalized price (volume already scaled in _updateCandle)
      NodeMarket._updateCandle(c, c.price, orderSize, now)

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

      -- Schedule next simulated trade (scale by node + global activity and events)
      local rate = c.orderRate * (c.activityFactor or 1.0) * (st.activityCycle or 1.0) * (1 + 0.5 * (st.globalVolBoost or 0))
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
    sigma = node.garch and node.garch.sigma or 0,
    regimeState = node.regime and node.regime.state or 0,
    volMultiplier = node.regime and node.regime.volMultiplier or 1.0,
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
