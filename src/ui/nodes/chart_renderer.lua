local Theme = require("src.core.theme")
local NodeMarket = require("src.systems.node_market")
local TechnicalIndicators = require("src.systems.technical_indicators")

local ChartRenderer = {}

-- Local helpers (kept internal to renderer)
local function minmax(samples, i0, i1)
  local mn, mx = math.huge, -math.huge
  local n = #samples
  local validStart = math.max(1, i0)
  local validEnd = math.min(n, i1)
  for i = validStart, validEnd do
    local s = samples[i]
    if s then
      mn = math.min(mn, s.l)
      mx = math.max(mx, s.h)
    end
  end
  if not (mn < math.huge) then
    mn, mx = 0, 1
    if n > 0 then
      local lastCandle = samples[n]
      mn, mx = lastCandle.l, lastCandle.h
    end
  end
  return mn, mx
end

local function formatPrice(p)
  -- Format with appropriate decimal places based on price
  if p >= 100 then
    return string.format("%.0f", p)  -- No decimals for large numbers
  elseif p >= 1 then
    return string.format("%.2f", p)  -- 2 decimals for medium numbers
  else
    return string.format("%.4f", p)  -- 4 decimals for small numbers
  end
end

local function drawCandles(samples, x, y, w, h, reqVisible, padL, padR, yScale, yOffset, startIndex)
  local n = #samples
  if n == 0 then return 0, 1, 8, 1, 0 end
  reqVisible = math.max(1, math.floor((reqVisible or n)))
  local i0 = math.floor(startIndex or (n - reqVisible + 1))
  local i1 = i0 + reqVisible - 1
  padL = math.max(0, padL or math.floor(reqVisible * 0.1))
  padR = math.max(0, padR or math.floor(reqVisible * 0.2))
  local totalSlots = reqVisible + padL + padR
  local cw = w / totalSlots
  local mn, mx = minmax(samples, i0, i1)
  local pad = (mx - mn) * 0.05
  mn, mx = mn - pad, mx + pad
  local baseCenter = 0.5 * (mn + mx)
  local baseRange = (mx - mn)
  yScale = math.max(0.1, yScale or 1.0)
  yOffset = yOffset or 0.0
  local viewRange = baseRange / yScale
  local viewCenter = baseCenter + yOffset
  mn, mx = viewCenter - viewRange * 0.5, viewCenter + viewRange * 0.5
  if mn == mx then mx = mn + 1 end
  local scaleY = h / (mx - mn)
  local gapPx = math.max(1, math.floor(cw * 0.2))  -- Increased gap between candles
  local bodyMax = math.max(1, math.floor(cw - gapPx))  -- Body width = candle width - gap

  Theme.setColor(Theme.colors.bg3)
  love.graphics.setLineWidth(1)
  for k = 0, 4 do
    local gy = y + h - (h * k / 4)
    love.graphics.line(x, math.floor(gy) + 0.5, x + w, math.floor(gy) + 0.5)
  end

  for i = i0, i1 do
    local s = samples[i]
    if s then
      local idx = i - i0
      local cx = x + (padL + idx) * cw + cw * 0.5
      local cxp = math.floor(cx) + 0.5
      local openY = y + h - (s.o - mn) * scaleY
      local closeY = y + h - (s.c - mn) * scaleY
      local highY = y + h - (s.h - mn) * scaleY
      local lowY = y + h - (s.l - mn) * scaleY
      if lowY < highY then highY, lowY = lowY, highY end
      local up = s.c >= s.o
      local bodyH = math.max(1, math.abs(closeY - openY))
      local bodyW = math.max(1, bodyMax)
      
      -- Draw wick (always neutral color)
      Theme.setColor(Theme.colors.bg3)
      love.graphics.setLineWidth(1)
      love.graphics.line(cxp, highY, cxp, lowY)
      
      -- Set candle color based on direction - ensure always green for up, red for down
      local candleColor = up and Theme.colors.success or Theme.colors.danger
      
      if bodyW <= 1.5 then
        -- Thin candle - just draw a line in the appropriate color
        Theme.setColor(candleColor)
        love.graphics.setLineWidth(1.5)  -- Slightly thicker line for visibility
        love.graphics.line(cxp, math.min(openY, closeY), cxp, math.max(openY, closeY))
      else
        -- Regular candle - draw filled body with outline
        local bx = math.floor(cx - bodyW * 0.5) + 0.5
        local by = math.min(openY, closeY)
        
        -- Draw filled body - ensure color is always set
        Theme.setColor(candleColor)
        love.graphics.rectangle("fill", bx, by, bodyW, bodyH)
        
        -- Draw outline in the same color but darker for better visibility
        local r, g, b, a = love.graphics.getColor()
        Theme.setColor({r * 0.7, g * 0.7, b * 0.7, 1})
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", bx, by, bodyW, bodyH)
      end
    end
  end
  return mn, mx, cw, i0, i1
end

-- Draw a closing-price line chart
local function drawLine(samples, x, y, w, h, reqVisible, padL, padR, yScale, yOffset, startIndex)
  local n = #samples
  if n == 0 then return 0, 1, 8, 1, 0 end
  reqVisible = math.max(1, math.floor((reqVisible or n)))
  local i0 = math.floor(startIndex or (n - reqVisible + 1))
  local i1 = i0 + reqVisible - 1
  padL = math.max(0, padL or math.floor(reqVisible * 0.1))
  padR = math.max(0, padR or math.floor(reqVisible * 0.2))
  local totalSlots = reqVisible + padL + padR
  local cw = w / totalSlots
  local mn, mx = minmax(samples, i0, i1)
  local pad = (mx - mn) * 0.05
  mn, mx = mn - pad, mx + pad
  local baseCenter = 0.5 * (mn + mx)
  local baseRange = (mx - mn)
  yScale = math.max(0.1, yScale or 1.0)
  yOffset = yOffset or 0.0
  local viewRange = baseRange / yScale
  local viewCenter = baseCenter + yOffset
  mn, mx = viewCenter - viewRange * 0.5, viewCenter + viewRange * 0.5
  if mn == mx then mx = mn + 1 end
  local scaleY = h / (mx - mn)

  Theme.setColor(Theme.colors.bg3)
  love.graphics.setLineWidth(1)
  for k = 0, 4 do
    local gy = y + h - (h * k / 4)
    love.graphics.line(x, math.floor(gy) + 0.5, x + w, math.floor(gy) + 0.5)
  end

  -- Build path for line through close values
  local path = {}
  for i = i0, i1 do
    local s = samples[i]
    if s then
      local idx = i - i0
      local cx = x + (padL + idx) * cw + cw * 0.5
      local cy = y + h - (s.c - mn) * scaleY
      table.insert(path, math.floor(cx) + 0.5)
      table.insert(path, math.floor(cy) + 0.5)
    end
  end

  Theme.setColor(Theme.colors.accent)
  if #path >= 4 then
    love.graphics.line(path)
  end

  return mn, mx, cw, i0, i1
end

function ChartRenderer.draw(self, node, x, y, w, h)
  -- Use theme's small font for consistency
  local font = Theme.fonts.small
  love.graphics.setFont(font)
  
  -- Chart background
  Theme.drawGradientGlowRect(x, y, w, h, 4, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)

  -- Chart controls (Time ranges)
  local opts = { "5s", "15s", "30s", "1m", "5m", "15m", "30m", "1h", "4h", "1d" }
  local bw, bh = 38, 22
  local pad = 5
  self._rangeButtons = {}
  for i, opt in ipairs(opts) do
    local bx = x + 10 + (i - 1) * (bw + pad)
    local by = y + 8
    local selected = (self.range == opt)
    Theme.drawGradientGlowRect(bx, by, bw, bh, 4, selected and Theme.colors.primary or Theme.colors.bg2, Theme.colors.bg1, selected and Theme.colors.accent or Theme.colors.border, Theme.effects.glowWeak)
    Theme.setColor(selected and Theme.colors.textHighlight or Theme.colors.text)
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.printf(opt, bx, by + 4, bw, "center")
    table.insert(self._rangeButtons, { x = bx, y = by, w = bw, h = bh, id = opt })
  end

  -- Style toggle (Candles / Line) on the right
  self._styleButtons = {}
  local sbw = 56
  local sby = y + 8
  local sx2 = x + w - 10 - sbw
  local sx1 = sx2 - pad - sbw
  local styles = {
    { id = "candle", label = "Candle", x = sx1 },
    { id = "line", label = "Line", x = sx2 },
  }
  for _, s in ipairs(styles) do
    local selected = (self.chartType == s.id)
    Theme.drawGradientGlowRect(s.x, sby, sbw, bh, 4, selected and Theme.colors.primary or Theme.colors.bg2, Theme.colors.bg1, selected and Theme.colors.accent or Theme.colors.border, Theme.effects.glowWeak)
    Theme.setColor(selected and Theme.colors.textHighlight or Theme.colors.text)
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.printf(s.label, s.x, sby + 4, sbw, "center")
    table.insert(self._styleButtons, { x = s.x, y = sby, w = sbw, h = bh, id = s.id })
  end

  -- Chart area
  local chartX = x + 8
  local chartY = y + 40
  local chartW = w - 16
  local chartH = h - 48
  -- Split into candle area (top ~80%) and volume area (bottom ~20%)
  local volH = math.floor(chartH * 0.20)
  local candleH = math.max(10, chartH - volH - 6)
  local volY = chartY + candleH + 4
  self._chartRect = { x = chartX, y = chartY, w = chartW, h = candleH }

  -- Determine desired visible count and fetch downsampled candles from market API
  local basePxPerCandle = 8
  local zoom = math.max(0.05, math.min(32.0, self.zoom or 1.0))
  local pxPerCandle = basePxPerCandle * zoom

  -- Calculate how many candles fit in the chart width with proper spacing
  local gapPx = math.max(1, math.floor(pxPerCandle * 0.15))  -- 15% gap between candles
  local candleWithGapPx = pxPerCandle + gapPx
  local requestedVisible = math.max(1, math.floor(chartW / candleWithGapPx))
  local candles = NodeMarket.getDownsampledCandles(node, self.intervalSeconds, requestedVisible + math.floor(requestedVisible * 0.5) + 32)

  local visible = math.max(1, math.min(#candles, requestedVisible))
  local n = #candles

  love.graphics.push()
  love.graphics.setScissor(chartX, chartY, chartW, chartH)

  -- Adjust padding for better candle spacing
  local padL = math.max(1, math.floor(requestedVisible * 0.03))  -- Reduced left padding
  local padR = math.max(2, math.floor(requestedVisible * 0.05))  -- Reduced right padding

  -- Constrain xPanBars to prevent chart from disappearing off edges
  local maxPanLeft = math.max(0, n - visible)  -- Can't pan past the start of data
  local maxPanRight = 0  -- Can't pan past the end (newest data)
  self.xPanBars = math.max(-maxPanRight, math.min(maxPanLeft, self.xPanBars or 0))

  -- Calculate start index: newest data on the right, pan left to see older data
  local startIndex = n - visible + 1 - (self.xPanBars or 0)
  startIndex = math.max(1, math.min(n - visible + 1, startIndex))

  local mn, mx, cw, i0, i1
  if self.chartType == "line" then
    mn, mx, cw, i0, i1 = drawLine(candles, chartX, chartY, chartW, candleH, visible, padL, padR, self.yScale, self.yOffset, startIndex)
  else
    mn, mx, cw, i0, i1 = drawCandles(candles, chartX, chartY, chartW, candleH, visible, padL, padR, self.yScale, self.yOffset, startIndex)
  end
  
  -- Volume histogram at the bottom of the chart (separate area)
  local maxV = 0
  local visibleCandles = {}
  
  -- First pass: collect visible candles and find max volume
  for i = i0, i1 do
    local s = candles[i]
    if s and s.v and s.v > 0 then
      table.insert(visibleCandles, s)
      maxV = math.max(maxV, s.v)
    end
  end
  
  -- Only draw if we have valid volume data
  if maxV > 0 then
    -- Add a small buffer to maxV to prevent the largest bar from touching the top
    maxV = maxV * 1.2
    
    -- Draw volume bars for visible candles
    for i, s in ipairs(visibleCandles) do
      local idx = (i0 + i - 1) - i0
      local cx = chartX + (padL + idx) * cw + cw * 0.5
      local barW = math.max(1, math.floor(cw * 0.6))  -- Slightly thinner bars for better spacing
      
      -- Calculate bar height based on volume, with minimum height
      local vH = math.max(1, math.floor((s.v / maxV) * (volH - 2)))
      
      local bx = math.floor(cx - barW * 0.5) + 0.5
      local by = volY + (volH - vH)
      local up = s.c >= s.o
      
      -- Consistent alpha for better visibility
      local alpha = 0.7
      
      Theme.setColor(Theme.withAlpha(up and Theme.colors.success or Theme.colors.danger, alpha))
      love.graphics.rectangle("fill", bx, by, barW, vH, 1, 1)  -- Slightly rounded corners
    end
  end
  love.graphics.setScissor()
  love.graphics.pop()

  -- Last price line and tag
  local last = candles[i1]
  if last and mx and mn then
    local scaleY = candleH / (mx - mn)
    local py = chartY + candleH - (last.c - mn) * scaleY
    Theme.setColor(Theme.colors.bg3)
    love.graphics.setLineWidth(1)
    love.graphics.line(chartX, math.floor(py) + 0.5, chartX + chartW, math.floor(py) + 0.5)
    local tag = formatPrice(last.c)
    local tw = font:getWidth(tag)
    Theme.setColor(Theme.withAlpha(Theme.colors.bg0, 0.8))
    love.graphics.rectangle("fill", chartX + chartW - tw - 10, py - font:getHeight() * 0.5 - 2, tw + 8, font:getHeight() + 4, 3, 3)
    Theme.setColor(Theme.colors.text)
    love.graphics.print(tag, chartX + chartW - tw - 6, py - font:getHeight() * 0.5)
  end

  -- Draw Y-axis (Price) - positioned to not overlap with right panels
  local font = Theme.fonts.small
  love.graphics.setFont(font)
  Theme.setColor(Theme.colors.text)
  self._yAxisLabels = {}

  local textHeight = font:getHeight()
  local minSpacing = textHeight + 12  -- Increased spacing
  local maxLabels = 5  -- Fixed number of Y-axis labels for consistency
  for i = 0, maxLabels - 1 do
    local price = mn + (mx - mn) * (i / (maxLabels - 1))
    local py = chartY + candleH - (candleH * i / (maxLabels - 1))
    local priceText = formatPrice(price)
    local textW = font:getWidth(priceText)
    local labelX = chartX + chartW - textW - 8
    local labelY = py - textHeight / 2
    table.insert(self._yAxisLabels, { x = labelX - 20, y = labelY - 5, w = textW + 40, h = textHeight + 10 })
    Theme.setColor(Theme.withAlpha(Theme.colors.bg0, 0.7))
    love.graphics.rectangle("fill", labelX - 2, labelY - 1, textW + 4, textHeight + 2)
    Theme.setColor(Theme.colors.text)
    love.graphics.print(priceText, labelX, labelY)
  end

  -- X-axis time labels removed as requested
end

return ChartRenderer
