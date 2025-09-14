local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")

local UIUtils = {}

-- Check if point is in rectangle
function UIUtils.pointInRect(px, py, rect)
  return px >= rect.x and py >= rect.y and px <= rect.x + rect.w and py <= rect.y + rect.h
end

-- Create a button with hover states
function UIUtils.drawButton(x, y, w, h, text, hover, active, options)
  options = options or {}
  local cornerRadius = 0
  local textColor = options.textColor
  local bgColor, borderColor
  
  -- Determine colors based on state
  if active then
    bgColor = options.activeBg or Theme.colors.bg4
    borderColor = options.activeBorder or Theme.colors.accent
    textColor = textColor or Theme.colors.textHighlight
  elseif hover then
    bgColor = options.hoverBg or Theme.colors.bg3
    borderColor = options.hoverBorder or Theme.colors.borderBright
    textColor = textColor or Theme.colors.textHighlight
  else
    bgColor = options.bg or Theme.colors.bg2
    borderColor = options.border or Theme.colors.border
    textColor = textColor or Theme.colors.text
  end
  
  -- Draw button background
  Theme.drawGradientGlowRect(x, y, w, h, cornerRadius,
    bgColor, Theme.colors.bg1, borderColor, 
    hover and Theme.effects.glowSubtle or Theme.effects.glowWeak)
  
  -- Draw button text
  if text then
    Theme.setColor(textColor)
    local font = options.font or Theme.fonts.normal
    love.graphics.setFont(font)
    local textW = font:getWidth(text)
    local textH = font:getHeight()
    love.graphics.print(text, x + (w - textW) * 0.5, y + (h - textH) * 0.5)
  end
  
  return { x = x, y = y, w = w, h = h }
end

-- Create a text input field
function UIUtils.drawTextInput(x, y, w, h, text, focused, placeholder, options)
  options = options or {}
  local cornerRadius = 0
  
  -- Colors based on focus state
  local bgColor = focused and Theme.colors.bg3 or Theme.colors.bg1
  local borderColor = focused and Theme.colors.accent or Theme.colors.border
  
  -- Draw input background
  Theme.drawGradientGlowRect(x, y, w, h, cornerRadius,
    bgColor, Theme.colors.bg0, borderColor, 
    focused and Theme.effects.glowMedium or Theme.effects.glowWeak)
  
  -- Text content
  local displayText = text
  if displayText == "" and placeholder then
    displayText = placeholder
  end
  
  if displayText and displayText ~= "" then
    local textColor = (text == "" and placeholder) and Theme.colors.textTertiary or Theme.colors.text
    Theme.setColor(textColor)
    local font = options.font or Theme.fonts.normal
    love.graphics.setFont(font)
    local textY = y + (h - font:getHeight()) * 0.5
    love.graphics.print(displayText, x + 8, textY)
  end
  
  -- Cursor for focused input
  if focused and text then
    local cursorX = x + 8
    if text ~= "" then
      local font = options.font or Theme.fonts.normal
      cursorX = cursorX + font:getWidth(text)
    end
    
    -- Blinking cursor
    local cursorAlpha = 0.5 + 0.5 * math.sin(love.timer.getTime() * 4)
    Theme.setColor(Theme.withAlpha(Theme.colors.textHighlight, cursorAlpha))
    love.graphics.rectangle("fill", cursorX, y + 4, 1, h - 8)
  end
  
  return { x = x, y = y, w = w, h = h }
end

-- Create a scrollable list
function UIUtils.drawScrollableList(x, y, w, h, items, scroll, itemHeight, drawItem, options)
  options = options or {}
  local cornerRadius = 0
  
  -- Background
  Theme.drawGradientGlowRect(x, y, w, h, cornerRadius,
    Theme.colors.bg1, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak)
  
  if not items or #items == 0 then
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.setFont(Theme.fonts.normal)
    love.graphics.print("No items", x + 8, y + 8)
    return { x = x, y = y, w = w, h = h }, {}
  end
  
  -- Calculate visible range
  local contentHeight = #items * itemHeight
  local maxScroll = math.max(0, contentHeight - h)
  scroll = math.max(0, math.min(maxScroll, scroll))
  
  local startIndex = math.floor(scroll / itemHeight) + 1
  local endIndex = math.min(#items, startIndex + math.ceil(h / itemHeight))
  
  -- Set up clipping
  love.graphics.push()
  love.graphics.intersectScissor(x, y, w, h)
  
  local itemRects = {}
  local mx, my = Viewport.getMousePosition()
  
  -- Draw visible items
  for i = startIndex, endIndex do
    local item = items[i]
    local itemY = y + (i - 1) * itemHeight - scroll
    local hover = mx >= x and mx <= x + w and my >= itemY and my <= itemY + itemHeight
    
    if drawItem then
      drawItem(item, i, x, itemY, w, itemHeight, hover)
    end
    
    itemRects[i] = { x = x, y = itemY, w = w, h = itemHeight, item = item, index = i }
  end
  
  love.graphics.pop()
  
  -- Scroll bar
  if contentHeight > h then
    local scrollBarW = 8
    local scrollBarH = h * (h / contentHeight)
    local scrollBarY = y + (scroll / maxScroll) * (h - scrollBarH)
    
    Theme.setColor(Theme.colors.bg3)
    love.graphics.rectangle("fill", x + w - scrollBarW - 2, y + 2, scrollBarW, h - 4)
    
    Theme.setColor(Theme.colors.accent)
    love.graphics.rectangle("fill", x + w - scrollBarW - 2, scrollBarY, scrollBarW, scrollBarH)
  end
  
  return { x = x, y = y, w = w, h = h, scroll = scroll, maxScroll = maxScroll }, itemRects
end

-- Create a tab bar
function UIUtils.drawTabBar(x, y, w, h, tabs, activeTab, options)
  options = options or {}
  local mx, my = Viewport.getMousePosition()
  local tabRects = {}
  
  if not tabs or #tabs == 0 then
    return { x = x, y = y, w = w, h = h }, tabRects
  end
  
  local tabWidth = w / #tabs
  
  for i, tab in ipairs(tabs) do
    local tabX = x + (i - 1) * tabWidth
    local isActive = (tab.id == activeTab)
    local hover = mx >= tabX and mx <= tabX + tabWidth and my >= y and my <= y + h
    
    local bgColor = isActive and Theme.colors.bg3 or (hover and Theme.colors.bg2 or Theme.colors.bg1)
    local borderColor = isActive and Theme.colors.accent or Theme.colors.border
    
    Theme.drawGradientGlowRect(tabX, y, tabWidth, h, 0,
      bgColor, Theme.colors.bg0, borderColor, Theme.effects.glowWeak)
    
    -- Tab text
    local textColor = isActive and Theme.colors.textHighlight or Theme.colors.text
    Theme.setColor(textColor)
    love.graphics.setFont(Theme.fonts.normal)
    local textW = Theme.fonts.normal:getWidth(tab.label or tab.id)
    local textX = tabX + (tabWidth - textW) * 0.5
    local textY = y + (h - Theme.fonts.normal:getHeight()) * 0.5
    love.graphics.print(tab.label or tab.id, textX, textY)
    
    tabRects[i] = { x = tabX, y = y, w = tabWidth, h = h, tab = tab }
  end
  
  return { x = x, y = y, w = w, h = h }, tabRects
end

-- Create a progress bar
function UIUtils.drawProgressBar(x, y, w, h, progress, color, options)
  options = options or {}
  local cornerRadius = 0
  local bgColor = options.bgColor or Theme.colors.bg1
  local borderColor = options.borderColor or Theme.colors.border
  
  progress = math.max(0, math.min(1, progress))
  
  -- Background
  Theme.setColor(bgColor)
  love.graphics.rectangle("fill", x, y, w, h, cornerRadius)
  
  -- Progress fill
  if progress > 0 then
    local fillW = math.floor(w * progress)
    Theme.setColor(color or Theme.colors.accent)
    love.graphics.rectangle("fill", x, y, fillW, h, cornerRadius)
    
    -- Inner highlight
    if fillW > 4 then
      Theme.setColor(Theme.withAlpha(Theme.colors.highlight, 0.3))
      love.graphics.rectangle("fill", x + 1, y + 1, fillW - 2, 2)
    end
  end
  
  -- Border
  Theme.setColor(borderColor)
  love.graphics.rectangle("line", x, y, w, h, cornerRadius)
  
  -- Progress text
  if options.showText then
    local text = string.format("%.0f%%", progress * 100)
    Theme.setColor(Theme.colors.text)
    love.graphics.setFont(Theme.fonts.small)
    local textW = Theme.fonts.small:getWidth(text)
    local textX = x + (w - textW) * 0.5
    local textY = y + (h - Theme.fonts.small:getHeight()) * 0.5
    love.graphics.print(text, textX, textY)
  end
  
  return { x = x, y = y, w = w, h = h }
end

-- Create a tooltip
function UIUtils.drawTooltip(x, y, text, options)
  options = options or {}
  local font = options.font or Theme.fonts.small
  local padding = options.padding or 8
  local cornerRadius = 0
  
  if not text or text == "" then return end
  
  love.graphics.setFont(font)
  local textW = font:getWidth(text)
  local textH = font:getHeight()
  local w = textW + padding * 2
  local h = textH + padding * 2
  
  -- Keep tooltip on screen
  local sw, sh = Viewport.getDimensions()
  if x + w > sw then x = sw - w end
  if y + h > sh then y = y - h - 10 end
  
  -- Background
  Theme.drawGradientGlowRect(x, y, w, h, cornerRadius,
    Theme.colors.bg3, Theme.colors.bg2, Theme.colors.borderBright, Theme.effects.glowMedium)
  
  -- Text
  Theme.setColor(Theme.colors.text)
  love.graphics.print(text, x + padding, y + padding)
end

-- Layout helpers
function UIUtils.layoutVertical(items, startX, startY, spacing)
  local y = startY
  local results = {}
  
  for _, item in ipairs(items) do
    results[#results + 1] = { x = startX, y = y, w = item.w, h = item.h }
    y = y + item.h + spacing
  end
  
  return results, y - spacing
end

function UIUtils.layoutHorizontal(items, startX, startY, spacing)
  local x = startX
  local results = {}
  
  for _, item in ipairs(items) do
    results[#results + 1] = { x = x, y = startY, w = item.w, h = item.h }
    x = x + item.w + spacing
  end
  
  return results, x - spacing
end

-- Grid layout
function UIUtils.layoutGrid(items, startX, startY, cols, itemW, itemH, spacingX, spacingY)
  local results = {}
  
  for i, item in ipairs(items) do
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)
    local x = startX + col * (itemW + spacingX)
    local y = startY + row * (itemH + spacingY)
    
    results[#results + 1] = { x = x, y = y, w = itemW, h = itemH, item = item }
  end
  
  return results
end

return UIUtils