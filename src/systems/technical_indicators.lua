local TechnicalIndicators = {}

-- Helper functions
local function sum(values, start, len)
  local total = 0
  for i = start, start + len - 1 do
    total = total + (values[i] or 0)
  end
  return total
end

local function sma(values, period, index)
  if index < period then return nil end
  return sum(values, index - period + 1, period) / period
end

local function ema(values, period, index, prevEma)
  if index < 1 then return nil end
  if not prevEma then
    return values[index]
  end
  local multiplier = 2 / (period + 1)
  return (values[index] * multiplier) + (prevEma * (1 - multiplier))
end

-- Aggregate 1-second candles into larger timeframes
function TechnicalIndicators.aggregateCandles(candles, intervalSeconds)
  if not candles or #candles == 0 or not intervalSeconds or intervalSeconds <= 1 then
    return candles
  end

  local aggregated = {}
  local currentBucket = nil

  for _, candle in ipairs(candles) do
    local bucketTime = math.floor(candle.t / intervalSeconds) * intervalSeconds
    
    if not currentBucket or bucketTime > currentBucket.t then
      -- Finalize the previous bucket if it exists
      if currentBucket then
        table.insert(aggregated, currentBucket)
      end
      
      -- Start a new bucket
      currentBucket = {
        o = candle.o,
        h = candle.h,
        l = candle.l,
        c = candle.c,
        v = candle.v or 0,
        t = bucketTime
      }
    else
      -- Continue aggregating into the current bucket
      currentBucket.h = math.max(currentBucket.h, candle.h)
      currentBucket.l = math.min(currentBucket.l, candle.l)
      currentBucket.c = candle.c
      currentBucket.v = (currentBucket.v or 0) + (candle.v or 0)
    end
  end

  -- Add the last bucket if it exists
  if currentBucket then
    table.insert(aggregated, currentBucket)
  end

  return aggregated
end

-- RSI (Relative Strength Index)
function TechnicalIndicators.calculateRSI(candles, period)
  period = period or 14
  if #candles < period + 1 then return {} end
  
  local rsi = {}
  local gains = {}
  local losses = {}
  
  -- Calculate price changes
  for i = 2, #candles do
    local change = candles[i].c - candles[i-1].c
    gains[i] = math.max(0, change)
    losses[i] = math.max(0, -change)
  end
  
  -- Calculate initial average gain and loss
  local avgGain = sum(gains, 2, period) / period
  local avgLoss = sum(losses, 2, period) / period
  
  for i = period + 1, #candles do
    if i == period + 1 then
      -- First RSI calculation
      local rs = avgLoss == 0 and 100 or avgGain / avgLoss
      rsi[i] = 100 - (100 / (1 + rs))
    else
      -- Subsequent RSI calculations using smoothed averages
      avgGain = (avgGain * (period - 1) + gains[i]) / period
      avgLoss = (avgLoss * (period - 1) + losses[i]) / period
      local rs = avgLoss == 0 and 100 or avgGain / avgLoss
      rsi[i] = 100 - (100 / (1 + rs))
    end
  end
  
  return rsi
end

-- MACD (Moving Average Convergence Divergence)
function TechnicalIndicators.calculateMACD(candles, fastPeriod, slowPeriod, signalPeriod)
  fastPeriod = fastPeriod or 12
  slowPeriod = slowPeriod or 26
  signalPeriod = signalPeriod or 9
  
  if #candles < slowPeriod then return {}, {}, {} end
  
  local closes = {}
  for i = 1, #candles do
    closes[i] = candles[i].c
  end
  
  local fastEMA = {}
  local slowEMA = {}
  local macdLine = {}
  local signalLine = {}
  local histogram = {}
  
  -- Calculate EMAs
  for i = 1, #closes do
    fastEMA[i] = ema(closes, fastPeriod, i, fastEMA[i-1])
    slowEMA[i] = ema(closes, slowPeriod, i, slowEMA[i-1])
    
    if fastEMA[i] and slowEMA[i] then
      macdLine[i] = fastEMA[i] - slowEMA[i]
    end
  end
  
  -- Calculate signal line (EMA of MACD)
  for i = 1, #macdLine do
    if macdLine[i] then
      signalLine[i] = ema(macdLine, signalPeriod, i, signalLine[i-1])
      
      if signalLine[i] then
        histogram[i] = macdLine[i] - signalLine[i]
      end
    end
  end
  
  return macdLine, signalLine, histogram
end

-- Bollinger Bands
function TechnicalIndicators.calculateBollingerBands(candles, period, stdDev)
  period = period or 20
  stdDev = stdDev or 2
  
  if #candles < period then return {}, {}, {} end
  
  local upperBand = {}
  local middleBand = {}
  local lowerBand = {}
  
  for i = period, #candles do
    local closes = {}
    for j = i - period + 1, i do
      table.insert(closes, candles[j].c)
    end
    
    -- Calculate SMA (middle band)
    local smaValue = sum(closes, 1, #candles) / #candles
    middleBand[i] = smaValue
    
    -- Calculate standard deviation
    local variance = 0
    for _, price in ipairs(closes) do
      variance = variance + math.pow(price - smaValue, 2)
    end
    local standardDeviation = math.sqrt(variance / #closes)
    
    upperBand[i] = smaValue + (stdDev * standardDeviation)
    lowerBand[i] = smaValue - (stdDev * standardDeviation)
  end
  
  return upperBand, middleBand, lowerBand
end

-- Volume Weighted Average Price (VWAP)
function TechnicalIndicators.calculateVWAP(candles, startIndex)
  startIndex = startIndex or 1
  local vwap = {}
  local cumulativeVolPrice = 0
  local cumulativeVolume = 0
  
  for i = startIndex, #candles do
    local candle = candles[i]
    local typicalPrice = (candle.h + candle.l + candle.c) / 3
    local volume = candle.v or 0
    
    cumulativeVolPrice = cumulativeVolPrice + (typicalPrice * volume)
    cumulativeVolume = cumulativeVolume + volume
    
    vwap[i] = cumulativeVolume > 0 and cumulativeVolPrice / cumulativeVolume or typicalPrice
  end
  
  return vwap
end

-- Stochastic Oscillator
function TechnicalIndicators.calculateStochastic(candles, kPeriod, dPeriod)
  kPeriod = kPeriod or 14
  dPeriod = dPeriod or 3
  
  if #candles < kPeriod then return {}, {} end
  
  local kPercent = {}
  local dPercent = {}
  
  for i = kPeriod, #candles do
    local highestHigh = -math.huge
    local lowestLow = math.huge
    
    -- Find highest high and lowest low in the period
    for j = i - kPeriod + 1, i do
      highestHigh = math.max(highestHigh, candles[j].h)
      lowestLow = math.min(lowestLow, candles[j].l)
    end
    
    local currentClose = candles[i].c
    kPercent[i] = highestHigh == lowestLow and 50 or 
                  ((currentClose - lowestLow) / (highestHigh - lowestLow)) * 100
  end
  
  -- Calculate %D (SMA of %K)
  for i = kPeriod + dPeriod - 1, #candles do
    local kSum = 0
    for j = i - dPeriod + 1, i do
      kSum = kSum + (kPercent[j] or 0)
    end
    dPercent[i] = kSum / dPeriod
  end
  
  return kPercent, dPercent
end

-- Support/Resistance levels detection
function TechnicalIndicators.findSupportResistance(candles, lookback, strength)
  lookback = lookback or 20
  strength = strength or 3
  
  local supports = {}
  local resistances = {}
  
  for i = lookback + 1, #candles - lookback do
    local candle = candles[i]
    local isSupport = true
    local isResistance = true
    
    -- Check if current low/high is a local minimum/maximum
    for j = i - lookback, i + lookback do
      if j ~= i and candles[j] then
        if candles[j].l <= candle.l then
          isSupport = false
        end
        if candles[j].h >= candle.h then
          isResistance = false
        end
      end
    end
    
    -- Verify strength by checking if price has tested this level multiple times
    if isSupport then
      local testCount = 0
      for j = math.max(1, i - lookback * 2), math.min(#candles, i + lookback * 2) do
        if math.abs(candles[j].l - candle.l) < (candle.l * 0.002) then
          testCount = testCount + 1
        end
      end
      if testCount >= strength then
        table.insert(supports, {index = i, price = candle.l, strength = testCount})
      end
    end
    
    if isResistance then
      local testCount = 0
      for j = math.max(1, i - lookback * 2), math.min(#candles, i + lookback * 2) do
        if math.abs(candles[j].h - candle.h) < (candle.h * 0.002) then
          testCount = testCount + 1
        end
      end
      if testCount >= strength then
        table.insert(resistances, {index = i, price = candle.h, strength = testCount})
      end
    end
  end
  
  return supports, resistances
end

return TechnicalIndicators