local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")

local Bounty = {
  dragging = false,
  dragDX = 0,
  dragDY = 0,
  x = nil,
  y = nil,
  closeDown = false,
  visible = false,
  scrollY = 0,
  contentHeight = 0,
}

local function panel(x, y, w, h, title)
  -- Enhanced window styling matching shop window
  Theme.drawGradientGlowRect(x, y, w, h, 8,
    Theme.colors.bg1, Theme.colors.bg0,
    Theme.colors.accent, Theme.effects.glowWeak)
  Theme.drawEVEBorder(x, y, w, h, 8, Theme.colors.border, 6)
  
  -- Enhanced title bar with effects
  local titleH = 24
  Theme.drawGradientGlowRect(x, y, w, titleH, 8,
    Theme.colors.bg3, Theme.colors.bg2,
    Theme.colors.accent, Theme.effects.glowWeak * 1.2)
  
  -- Enhanced title text with subtle shadow
  love.graphics.setFont(Theme.fonts.medium)
  Theme.setColor(Theme.withAlpha(Theme.colors.bg0, 0.6))
  local font = love.graphics.getFont()
  local textWidth = font:getWidth(title or "Bounty")
  local textHeight = font:getHeight()
  love.graphics.print(title or "Bounty", x + (w - textWidth) / 2 + 1, y + (titleH - textHeight) / 2 + 1) -- Shadow
  Theme.setColor(Theme.colors.textHighlight)
  love.graphics.print(title or "Bounty", x + (w - textWidth) / 2, y + (titleH - textHeight) / 2)
  love.graphics.setFont(Theme.fonts.normal)
end

local function pointInRect(px, py, x, y, w, h)
  return px >= x and py >= y and px <= x + w and py <= y + h
end

-- Icon drawing functions
local function drawCreditIcon(x, y, size)
  size = size or 12
  local r = size * 0.4
  -- Credit coin: circle with 'C' symbol
  love.graphics.setColor(1.0, 0.85, 0.3, 0.9) -- Gold color
  love.graphics.circle("fill", x + r, y + r, r)
  love.graphics.setColor(0.8, 0.6, 0.1, 1.0)
  love.graphics.circle("line", x + r, y + r, r)
  -- 'C' symbol
  love.graphics.setColor(0.2, 0.2, 0.2, 1.0)
  love.graphics.setFont(love.graphics.getFont())
  local font = love.graphics.getFont()
  local fw = font:getWidth("C")
  local fh = font:getHeight()
  love.graphics.print("C", x + r - fw * 0.5, y + r - fh * 0.5)
end

-- remove XP icon; bounty rewards are GC only

-- Use Theme.drawCloseButton for consistent visuals

local function getBountyRect()
  local w, h = 280, 200 -- Larger panel to fit more info
  local sw, sh = Viewport.getDimensions()
  -- Default position: place just below minimap (which is 220x160 at top-right)
  local defaultX, defaultY = sw - w - 16, 16 + 160 + 12
  local x = Bounty.x or defaultX
  local y = Bounty.y or defaultY
  return x, y, w, h
end

local function getCloseButtonRect()
  local x, y, w, h = getBountyRect()
  return { x = x + w - 26, y = y + 2, w = 24, h = 24 }
end

local function getClaimButtonRect()
    local x, y, w, h = getBountyRect()
    local buttonW, buttonH = 120, 28
    local buttonX = x + (w - buttonW) / 2
    local buttonY = y + h - buttonH - 10
    return {x = buttonX, y = buttonY, w = buttonW, h = buttonH}
end

local function drawClaimButton(docked)
    if not docked then return end
    local rect = getClaimButtonRect()
    local mx, my = Viewport.getMousePosition()
    local hover = pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h)
    
    -- Use Theme functions for consistent button styling
    local buttonBg = hover and Theme.colors.primary or Theme.colors.bg2
    local buttonBorder = Theme.colors.border
    
    Theme.drawGradientGlowRect(rect.x, rect.y, rect.w, rect.h, 4, buttonBg, Theme.colors.bg1, Theme.colors.primary, Theme.effects.glowWeak * 0.1)
    Theme.drawEVEBorder(rect.x, rect.y, rect.w, rect.h, 4, buttonBorder, 6)
    
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("Claim Bounties", rect.x, rect.y + 6, rect.w, "center")
end

function Bounty.draw(state, docked)
  if not Bounty.visible then return end
  state = state or { total = 0, entries = {} }
  local x, y, w, h = getBountyRect()
  panel(x, y, w, h, "Bounty")
  
  -- Draw close button
  local closeRect = { x = x + w - 22, y = y + 2, w = 20, h = 20 }
  local mx, my = Viewport.getMousePosition()
  local closeHover = mx >= closeRect.x and mx <= closeRect.x + closeRect.w and my >= closeRect.y and my <= closeRect.y + closeRect.h
  Theme.drawCloseButton(closeRect, closeHover)
  Bounty.closeRect = closeRect
  Bounty.titleRect = { x = x, y = y, w = w, h = 24 }
  Bounty.titleRect = { x = x, y = y, w = w, h = 28 }
  
  -- Draw claim button if docked
  drawClaimButton(docked)
  
  love.graphics.push()
  local innerTop = y + 34
  local innerH = h - (34 + (docked and 40 or 10))
  love.graphics.setScissor(x, innerTop, w, innerH)
  love.graphics.translate(0, -Bounty.scrollY)
  
  local cx, cy = x + 10, y + 34
  
  -- Uncollected totals section with icons
  love.graphics.setColor(0.75, 0.85, 1, 0.9)
  love.graphics.print("Uncollected:", cx, cy)
  cy = cy + 20
  
  -- Credits row
  drawCreditIcon(cx + 5, cy, 16)
  love.graphics.setColor(1.0, 0.85, 0.3, 0.95)
  love.graphics.print(string.format("%d cr", state.uncollected or 0), cx + 25, cy + 2)
  
  cy = cy + 25
  love.graphics.setColor(0.75, 0.80, 0.95, 0.85)
  love.graphics.print("Recent kills:", cx, cy)
  cy = cy + 16
  
  local shown = 0
  if state.entries then
    for i = #state.entries, 1, -1 do
      local entry = state.entries[i]
      -- Enemy name
      love.graphics.setColor(0.92, 0.95, 1.00, 0.96)
      love.graphics.print(entry.name or "Unknown Enemy", cx, cy)
      cy = cy + 14
      
      -- Rewards on same line with icons
      drawCreditIcon(cx + 10, cy, 12)
      love.graphics.setColor(1.0, 0.85, 0.3, 0.95)
      love.graphics.print(string.format("+%d", entry.gc or 0), cx + 25, cy + 1)
      
      -- XP removed from bounty panel
      
      cy = cy + 18
      shown = shown + 1
      if shown >= 4 then break end
    end
  end
  
  if shown == 0 then
    love.graphics.setColor(0.55, 0.60, 0.75, 0.75)
    love.graphics.print("No recent kills", cx + 10, cy)
  end
  
  Bounty.contentHeight = cy - (y + 34)
  love.graphics.pop()
  love.graphics.setScissor()
  
  -- Scrollbar
  local innerTop = y + 34
  local innerH = h - (34 + (docked and 40 or 10))
  if Bounty.contentHeight > innerH then
    local scrollbarX = x + w - 10
    local scrollbarY = innerTop
    local scrollbarH = innerH
    local thumbH = math.max(24, scrollbarH * (innerH / Bounty.contentHeight))
    local trackRange = scrollbarH - thumbH
    local thumbY = scrollbarY + (trackRange > 0 and (trackRange * (Bounty.scrollY / (Bounty.contentHeight - innerH))) or 0)
    Theme.drawGradientGlowRect(scrollbarX, scrollbarY, 8, scrollbarH, 2, Theme.colors.bg0, Theme.colors.bg1, Theme.colors.border, 0)
    Theme.drawGradientGlowRect(scrollbarX, thumbY, 8, thumbH, 2, Theme.colors.accent, Theme.colors.bg3, Theme.colors.border, 0)
    Bounty._scrollbarTrack = { x = scrollbarX, y = scrollbarY, w = 8, h = scrollbarH }
    Bounty._scrollbarThumb = { x = scrollbarX, y = thumbY, w = 8, h = thumbH }
  else
    Bounty._scrollbarTrack = nil
    Bounty._scrollbarThumb = nil
  end
end

function Bounty.mousepressed(x, y, button, docked)
  if not Bounty.visible or button ~= 1 then return false, false end
  local bx, by, w, h = getBountyRect()
  local closeRect = { x = bx + w - 28, y = by + 6, w = 20, h = 20 }
  
  -- Scrollbar interactions
  if Bounty._scrollbarTrack and Bounty._scrollbarThumb then
    local tr = Bounty._scrollbarTrack
    local th = Bounty._scrollbarThumb
    if pointInRect(x, y, th.x, th.y, th.w, th.h) then
      Bounty.dragging = "scrollbar"
      Bounty.dragDY = y - th.y
      return true, false
    end
    if pointInRect(x, y, tr.x, tr.y, tr.w, tr.h) then
      local innerH = h - (34 + (docked and 40 or 10))
      local trackRange = tr.h - th.h
      local rel = math.max(0, math.min(trackRange, (y - tr.y) - th.h * 0.5))
      local frac = trackRange > 0 and (rel / trackRange) or 0
      local maxScroll = math.max(0, Bounty.contentHeight - innerH)
      Bounty.scrollY = math.max(0, math.min(maxScroll, frac * maxScroll))
      return true, false
    end
  end
  -- Close button
  if pointInRect(x, y, closeRect.x, closeRect.y, closeRect.w, closeRect.h) then
    Bounty.closeDown = true
    return true, false
  end
  -- Claim button
    if docked then
        local claimRect = getClaimButtonRect()
        if pointInRect(x, y, claimRect.x, claimRect.y, claimRect.w, claimRect.h) then
            Bounty.claimDown = true
            return true, false
        end
    end
  -- Panel drag
  local bx, by, bw, bh = getBountyRect()
  if pointInRect(x, y, bx, by, bw, bh) then
    Bounty.dragging = true
    Bounty.dragDX = bx - x
    Bounty.dragDY = by - y
    return true, false
  end
  return false, false
end

function Bounty.mousereleased(x, y, button, docked, claimBounty)
  if not Bounty.visible then return false, false end
  local consumed, shouldClose = false, false
  if button == 1 then
    if Bounty.dragging then
      Bounty.dragging = false
      consumed = true
    end
    if Bounty.closeDown then
      local bx, by, w, h = getBountyRect()
      local closeRect = { x = bx + w - 28, y = by + 6, w = 20, h = 20 }
      if pointInRect(x, y, closeRect.x, closeRect.y, closeRect.w, closeRect.h) then
        shouldClose = true
        Bounty.visible = false
      end
      Bounty.closeDown = false
      consumed = true
    end
    if docked and Bounty.claimDown then
        local claimRect = getClaimButtonRect()
        if pointInRect(x, y, claimRect.x, claimRect.y, claimRect.w, claimRect.h) then
            if claimBounty then claimBounty() end
        end
        Bounty.claimDown = false
        consumed = true
    end
  end
  return consumed, shouldClose
end

function Bounty.mousemoved(x, y, dx, dy)
  if Bounty.dragging == "scrollbar" then
    local bx, by, w, h = getBountyRect()
    local docked = false -- Assume not docked for simplicity
    local innerH = h - (34 + (docked and 40 or 10))
    local tr = Bounty._scrollbarTrack
    local th = Bounty._scrollbarThumb
    if tr and th then
      local trackRange = tr.h - th.h
      local newThumbY = math.max(tr.y, math.min(tr.y + trackRange, (y - Bounty.dragDY)))
      local rel = newThumbY - tr.y
      local frac = trackRange > 0 and (rel / trackRange) or 0
      local maxScroll = math.max(0, Bounty.contentHeight - innerH)
      Bounty.scrollY = math.max(0, math.min(maxScroll, frac * maxScroll))
    end
    return true
  elseif Bounty.dragging then
    Bounty.x = x + Bounty.dragDX
    Bounty.y = y + Bounty.dragDY
    return true
  end
  return false
end

function Bounty.toggle()
  Bounty.visible = not Bounty.visible
end

function Bounty.wheelmoved(x, y)
  if not Bounty.visible then return false end
  local bx, by, w, h = getBountyRect()
  local docked = false -- Assume not docked for simplicity
  local innerH = h - (34 + (docked and 40 or 10))
  local maxScroll = math.max(0, Bounty.contentHeight - innerH)
  Bounty.scrollY = math.max(0, math.min(maxScroll, Bounty.scrollY - y * 20))
  return true
end

function Bounty.isVisible()
  return Bounty.visible
end

return Bounty
