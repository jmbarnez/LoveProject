local Theme = require("src.core.theme")

local ScrollArea = {}

-- Minimal scroll area helper (no layout): manages scrollY and draws track/thumb.
-- Returns updated scrollY and internal geometry useful for interaction.
function ScrollArea.draw(x, y, w, h, contentHeight, scrollY, options)
  scrollY = scrollY or 0
  options = options or {}
  local maxScroll = math.max(0, (contentHeight or 0) - h)
  local pad = (Theme.ui and Theme.ui.contentPadding) or 4
  local trackW = 8
  local trackX = x + w - trackW - pad
  local trackY = y
  local trackH = h

  if maxScroll <= 0 then
    Theme.drawGradientGlowRect(trackX, trackY, trackW, trackH, 2, Theme.colors.bg0, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak * 0.1)
    return 0, {
      track = { x = trackX, y = trackY, w = trackW, h = trackH },
      thumb = nil,
      maxScroll = 0,
      dragging = false,
    }
  end

  local thumbH = math.max(20, h * (h / (contentHeight)))
  local range = trackH - thumbH
  local dragging = options.dragging or false
  local dragOffset = options.dragOffset or 0
  local mouseY = options.mouseY

  if dragging and mouseY then
    local newThumbY = math.max(trackY, math.min(trackY + range, mouseY - dragOffset))
    local t = (newThumbY - trackY) / (range > 0 and range or 1)
    scrollY = t * maxScroll
  end

  scrollY = math.max(0, math.min(maxScroll, scrollY))

  local t = (range > 0) and ((scrollY / maxScroll) * range) or 0
  local thumbX, thumbY = trackX, trackY + t

  Theme.drawGradientGlowRect(trackX, trackY, trackW, trackH, 2, Theme.colors.bg0, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak * 0.1)
  Theme.drawGradientGlowRect(thumbX, thumbY, trackW, thumbH, 2, Theme.colors.accent, Theme.colors.bg3, Theme.colors.border, Theme.effects.glowWeak * 0.2)

  return scrollY, {
    track = { x = trackX, y = trackY, w = trackW, h = trackH },
    thumb = { x = thumbX, y = thumbY, w = trackW, h = thumbH },
    maxScroll = maxScroll,
  }
end

return ScrollArea


