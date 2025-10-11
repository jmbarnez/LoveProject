local ChartAnimations = {}

-- Animation state for each coin
local animations = {}

-- Animation types
ChartAnimations.ANIM_TYPES = {
  PRICE_CHANGE = "price_change",
  NEW_CANDLE = "new_candle",
  VOLUME_SPIKE = "volume_spike"
}

function ChartAnimations.init()
  animations = {}
end

function ChartAnimations.addPriceChangeAnimation(coinSymbol, oldPrice, newPrice, x, y)
  local change = newPrice - oldPrice
  local direction = change >= 0 and 1 or -1
  
  if not animations[coinSymbol] then
    animations[coinSymbol] = {}
  end
  
  table.insert(animations[coinSymbol], {
    type = ChartAnimations.ANIM_TYPES.PRICE_CHANGE,
    startTime = love.timer and love.timer.getTime() or os.time(),
    duration = 2.0,
    oldPrice = oldPrice,
    newPrice = newPrice,
    direction = direction,
    x = x,
    y = y,
    alpha = 1.0
  })
end

function ChartAnimations.addNewCandleAnimation(coinSymbol, candleX, candleY, candleW, candleH)
  if not animations[coinSymbol] then
    animations[coinSymbol] = {}
  end
  
  table.insert(animations[coinSymbol], {
    type = ChartAnimations.ANIM_TYPES.NEW_CANDLE,
    startTime = love.timer and love.timer.getTime() or os.time(),
    duration = 1.0,
    x = candleX,
    y = candleY,
    w = candleW,
    h = candleH,
    scale = 0.0
  })
end

function ChartAnimations.addVolumeSpikeAnimation(coinSymbol, x, y, intensity)
  if not animations[coinSymbol] then
    animations[coinSymbol] = {}
  end
  
  table.insert(animations[coinSymbol], {
    type = ChartAnimations.ANIM_TYPES.VOLUME_SPIKE,
    startTime = love.timer and love.timer.getTime() or os.time(),
    duration = 1.5,
    x = x,
    y = y,
    intensity = math.min(1.0, intensity),
    alpha = 1.0,
    radius = 0
  })
end

function ChartAnimations.update(dt)
  local currentTime = love.timer and love.timer.getTime() or os.time()
  
  for coinSymbol, coinAnimations in pairs(animations) do
    for i = #coinAnimations, 1, -1 do
      local anim = coinAnimations[i]
      local elapsed = currentTime - anim.startTime
      local progress = math.min(1.0, elapsed / anim.duration)
      
      if anim.type == ChartAnimations.ANIM_TYPES.PRICE_CHANGE then
        anim.alpha = 1.0 - progress
        anim.y = anim.y - (dt * 30 * anim.direction) -- Float upward for gains, downward for losses
        
      elseif anim.type == ChartAnimations.ANIM_TYPES.NEW_CANDLE then
        -- Ease-out scale animation
        anim.scale = 1.0 - math.pow(1.0 - progress, 3)
        
      elseif anim.type == ChartAnimations.ANIM_TYPES.VOLUME_SPIKE then
        anim.alpha = 1.0 - progress
        anim.radius = progress * 20 * anim.intensity
      end
      
      -- Remove completed animations
      if progress >= 1.0 then
        table.remove(coinAnimations, i)
      end
    end
    
    -- Clean up empty animation tables
    if #coinAnimations == 0 then
      animations[coinSymbol] = nil
    end
  end
end

function ChartAnimations.draw(coinSymbol)
  if not animations[coinSymbol] then return end
  
  for _, anim in ipairs(animations[coinSymbol]) do
    if anim.type == ChartAnimations.ANIM_TYPES.PRICE_CHANGE then
      local color = anim.direction >= 0 and {0.3, 0.8, 0.4} or {0.8, 0.3, 0.4}
      color[4] = anim.alpha
      
      love.graphics.setColor(color)
      love.graphics.setFont(love.graphics.getFont())
      
      local text = string.format("%+.3f", anim.newPrice - anim.oldPrice)
      love.graphics.print(text, anim.x, anim.y)
      
    elseif anim.type == ChartAnimations.ANIM_TYPES.NEW_CANDLE then
      -- Draw a subtle highlight around new candles
      love.graphics.setColor(1.0, 1.0, 1.0, 0.3 * anim.scale)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", 
        anim.x - anim.w * 0.1, 
        anim.y - anim.h * 0.1, 
        anim.w * 1.2, 
        anim.h * 1.2)
      
    elseif anim.type == ChartAnimations.ANIM_TYPES.VOLUME_SPIKE then
      -- Draw expanding circles for volume spikes
      love.graphics.setColor(0.2, 0.8, 1.0, anim.alpha * 0.4)
      love.graphics.setLineWidth(2)
      love.graphics.circle("line", anim.x, anim.y, anim.radius)
      
      if anim.radius > 10 then
        love.graphics.setColor(0.2, 0.8, 1.0, anim.alpha * 0.2)
        love.graphics.circle("line", anim.x, anim.y, anim.radius * 0.5)
      end
    end
  end
end

function ChartAnimations.getActiveAnimationCount(coinSymbol)
  if not animations[coinSymbol] then return 0 end
  return #animations[coinSymbol]
end

function ChartAnimations.clearAnimations(coinSymbol)
  if coinSymbol then
    animations[coinSymbol] = nil
  else
    animations = {}
  end
end

-- Smooth interpolation function
function ChartAnimations.smoothStep(t)
  return t * t * (3.0 - 2.0 * t)
end

-- Easing functions
function ChartAnimations.easeOutCubic(t)
  return 1.0 - math.pow(1.0 - t, 3)
end

function ChartAnimations.easeInOutSine(t)
  return -(math.cos(math.pi * t) - 1) / 2
end

return ChartAnimations