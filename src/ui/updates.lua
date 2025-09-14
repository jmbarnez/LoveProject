local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")

local Updates = {
  visible = false,
  dragging = false,
  dragDX = 0,
  dragDY = 0,
  x = nil,
  y = nil,
  closeDown = false,
}

local updateHistory = {
  {
    version = "The Mining Update",
    date = "Latest",
    changes = {
      "Added mining laser turrets for resource extraction",
      "New asteroid mining system with resource generation",
      "Enhanced UI with mining progress indicators",
      "Updated inventory system for resource management",
      "Improved targeting system for mining operations"
    }
  }
}

local function pointInRect(px, py, rx, ry, rw, rh)
  return px >= rx and py >= ry and px <= rx + rw and py <= ry + rh
end

local function panel(x, y, w, h, title)
  -- Hard corners for dark classic Windows style
  Theme.drawGradientGlowRect(x, y, w, h, 8, Theme.explorer.contentBg, Theme.colors.bg1, Theme.colors.accent, Theme.effects.glowWeak * 0.18)
  Theme.drawEVEBorder(x, y, w, h, 8, Theme.colors.border, 8)
  Theme.drawVerticalGradient(x, y, w, 28, Theme.components.window.titleBg, Theme.components.window.titleBg, 8)
  Theme.setColor(Theme.colors.text)
  love.graphics.print(title or "Update History", x + 10, y + 6)
end

-- drawCloseButton is provided by theme

local function getUpdatesRect()
  local w, h = 500, 500
  local sw, sh = Viewport.getDimensions()
  local defaultX, defaultY = (sw - w) * 0.5, (sh - h) * 0.5
  local x = Updates.x or defaultX
  local y = Updates.y or defaultY
  return x, y, w, h
end

local function getCloseButtonRect()
  local x, y, w, h = getUpdatesRect()
  return { x = x + w - 38, y = y + 2, w = 28, h = 28 }
end

-- Theme is required at top

function Updates.draw()
  if not Updates.visible then return end
  love.graphics.setFont(Theme.fonts.small)
  local x, y, w, h = getUpdatesRect()
  panel(x, y, w, h, "Update History")
  -- Draw close button
  local closeRect = getCloseButtonRect()
  local mx, my = Viewport.getMousePosition()
  local closeHover = pointInRect(mx, my, closeRect.x, closeRect.y, closeRect.w, closeRect.h)
  Theme.drawCloseButton(closeRect, closeHover)
  Updates.closeRect = closeRect
  Updates.titleRect = { x = x, y = y, w = w, h = 28 }

  local cx, cy = x + 16, y + 44

  -- Draw update history
  for i, update in ipairs(updateHistory) do
    -- Version header (retro gold accent)
    Theme.setColor(Theme.colors.accentGold)
    love.graphics.print(update.version .. " - " .. update.date, cx, cy)
    cy = cy + 20

    -- Changes list
    Theme.setColor(Theme.colors.text)
    for _, change in ipairs(update.changes) do
      love.graphics.print("• " .. change, cx + 8, cy)
      cy = cy + 16
    end

    cy = cy + 10
  end

  -- Credits Section
  cy = y + h - 120
  Theme.setColor(Theme.colors.text)
  love.graphics.print("Credits:", cx, cy)
  cy = cy + 20
  love.graphics.print("Song: Adrift", cx + 8, cy)
  cy = cy + 16
  love.graphics.print("Composer: Hayden Folker", cx + 8, cy)
  cy = cy + 16
  love.graphics.print("Website: https://soundcloud.com/hayden-folker", cx + 8, cy)
  cy = cy + 16
  love.graphics.print("Music powered by BreakingCopyright", cx + 8, cy)
end

function Updates.mousepressed(mx, my, button)
  if not Updates.visible then return false end
  if button ~= 1 then return false end

  local closeRect = getCloseButtonRect()
  -- Close button
  if pointInRect(mx, my, closeRect.x, closeRect.y, closeRect.w, closeRect.h) then
    Updates.closeDown = true
    return true
  end

  -- Panel drag
  local bx, by, bw, bh = getUpdatesRect()
  if pointInRect(mx, my, bx, by, bw, bh) then
    Updates.dragging = true
    Updates.dragDX = bx - mx
    Updates.dragDY = by - my
    return true
  end

  return false
end

function Updates.mousereleased(mx, my, button)
  if not Updates.visible then return false end
  local consumed, shouldClose = false, false
  if button == 1 then
    if Updates.dragging then
      Updates.dragging = false
      consumed = true
    end
    if Updates.closeDown then
      local closeRect = getCloseButtonRect()
      if pointInRect(mx, my, closeRect.x, closeRect.y, closeRect.w, closeRect.h) then
        shouldClose = true
      end
      Updates.closeDown = false
      consumed = true
    end
  end
  return consumed, shouldClose
end

function Updates.mousemoved(mx, my, dx, dy)
  if Updates.dragging then
    Updates.x = mx + Updates.dragDX
    Updates.y = my + Updates.dragDY
    return true
  end
  return false
end

return Updates
