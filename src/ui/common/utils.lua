local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")

local UIUtils = {}

-- Normalize key labels for display across UI components.
-- Provides shorthand for mouse buttons, modifiers, and single-character keys.
function UIUtils.formatKeyLabel(key, fallback)
    if not key or key == "" then return fallback or "" end

    key = tostring(key)
    local normalized = key:lower()

    if normalized == "mouse1" then return "LMB" end
    if normalized == "mouse2" then return "RMB" end
    if normalized == "space" then return "SPACE" end
    if normalized == "lshift" or normalized == "rshift" then return "SHIFT" end

    if #key == 1 then
        return key:upper()
    end

    return key:upper()
end

-- UI Caching system for expensive calculations
local textMetricsCache = {}
local cacheCounter = 0

-- Cache text metrics (width/height) to avoid repeated font:getWidth/getHeight calls
function UIUtils.getCachedTextMetrics(text, font)
    if not text or not font then return {width = 0, height = 0} end

    -- Create a cache key using available font properties
    local fontHeight = font:getHeight() or 12
    local lineHeight = fontHeight
    if font.getLineHeight then
        lineHeight = font:getLineHeight() or fontHeight
    end
    local fontKey = tostring(fontHeight) .. "_" .. tostring(lineHeight)
    local cacheKey = tostring(text) .. "_" .. fontKey
    local cached = textMetricsCache[cacheKey]

    if not cached then
        cached = {
            width = font:getWidth(text),
            height = font:getHeight()
        }
        textMetricsCache[cacheKey] = cached

        -- Periodic cleanup to prevent memory leaks
        cacheCounter = cacheCounter + 1
        if cacheCounter > 5000 then
            cacheCounter = 0
            -- Clear old entries (simple FIFO eviction)
            local newCache = {}
            local count = 0
            for k, v in pairs(textMetricsCache) do
                if count < 1000 then
                    newCache[k] = v
                    count = count + 1
                end
            end
            textMetricsCache = newCache
        end
    end

    return cached
end

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
  
  -- Play hover sound effect (only once per hover state)
  if hover and not active and not options._hoverPlayed then
    local UISounds = require("src.ui.sounds")
    if UISounds and UISounds.playButtonHover then
      UISounds.playButtonHover()
    end
    -- Mark as played to avoid repeated sounds
    options._hoverPlayed = true
  elseif not hover then
    -- Reset hover sound flag when not hovering
    options._hoverPlayed = false
  end
  
  -- Add subtle scale effect for hover
  local scaleX, scaleY = 1, 1
  if hover and not active then
    scaleX = 1.01 -- Very subtle scale up
    scaleY = 1.01
    local offsetX = (w * (scaleX - 1)) * 0.5
    local offsetY = (h * (scaleY - 1)) * 0.5
    x = x - offsetX
    y = y - offsetY
    w = w * scaleX
    h = h * scaleY
  end
  
  -- Determine colors based on state - transparent backgrounds
  if active then
    bgColor = options.activeBg or {Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], 0.3}
    borderColor = options.activeBorder or Theme.colors.accent
    textColor = textColor or Theme.colors.textHighlight
  elseif hover then
    bgColor = options.hoverBg or {Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], 0.2}
    borderColor = options.hoverBorder or Theme.colors.borderBright
    textColor = textColor or Theme.colors.textHighlight
  else
    bgColor = options.bg or {0, 0, 0, 0} -- Fully transparent
    borderColor = options.border or Theme.colors.border
    textColor = textColor or Theme.colors.text
  end
  
  -- Enhanced glow for hover state - much brighter on hover
  local glowIntensity = hover and Theme.effects.glowStrong or Theme.effects.glowWeak
  
  -- Draw button background
  Theme.drawGradientGlowRect(x, y, w, h, cornerRadius,
    bgColor, Theme.colors.bg1, borderColor, glowIntensity, false)
  
  -- Draw button text
  if text then
    Theme.setColor(textColor)
    local font = options.font or Theme.fonts.normal
    love.graphics.setFont(font)
    local metrics = UIUtils.getCachedTextMetrics(text, font)
    local textW, textH = metrics.width, metrics.height
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
    local metrics = UIUtils.getCachedTextMetrics(displayText, font)
    local textY = y + (h - metrics.height) * 0.5
    love.graphics.print(displayText, x + 8, textY)
  end
  
  -- Cursor for focused input
  if focused and text then
    local cursorX = x + 8
    if text ~= "" then
      local font = options.font or Theme.fonts.normal
      local metrics = UIUtils.getCachedTextMetrics(text, font)
      cursorX = cursorX + metrics.width
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
    Theme.colors.bg1, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak, false)
  
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
    
    -- Use main button theme for consistent styling
    local tabText = tab.label or tab.id
    Theme.drawStyledButton(tabX, y, tabWidth, h, tabText, hover, 1.0, nil, isActive)
    
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
    local metrics = UIUtils.getCachedTextMetrics(text, Theme.fonts.small)
    local textX = x + (w - metrics.width) * 0.5
    local textY = y + (h - metrics.height) * 0.5
    love.graphics.print(text, textX, textY)
  end
  
  return { x = x, y = y, w = w, h = h }
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