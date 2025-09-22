local Theme = require("src.core.theme")

local ScrollArea = {}

-- Minimal scroll area helper (no layout): manages scrollY and draws track/thumb.
-- Returns updated scrollY and internal geometry useful for interaction.
function ScrollArea.draw(x, y, w, h, contentHeight, scrollY)
  scrollY = scrollY or 0
  local maxScroll = math.max(0, (contentHeight or 0) - h)
  if maxScroll <= 0 then
    return 0, { maxScroll = 0 }
  end
  local thumbH = math.max(20, h * (h / (contentHeight)))
  local trackW = 8
  local pad = (Theme.ui and Theme.ui.contentPadding) or 4
  local trackX = x + w - trackW - pad
  local trackY = y
  local trackH = h
  local range = trackH - thumbH
  local t = (range > 0) and ((scrollY / maxScroll) * range) or 0
  local thumbX, thumbY = trackX, trackY + t
  Theme.drawGradientGlowRect(trackX, trackY, trackW, trackH, 2, Theme.colors.bg0, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak * 0.1)
  Theme.drawGradientGlowRect(thumbX, thumbY, trackW, thumbH, 2, Theme.colors.accent, Theme.colors.bg3, Theme.colors.border, Theme.effects.glowWeak * 0.2)
  return math.max(0, math.min(maxScroll, scrollY)), {
    track = { x = trackX, y = trackY, w = trackW, h = trackH },
    thumb = { x = thumbX, y = thumbY, w = trackW, h = thumbH },
    maxScroll = maxScroll,
  }
end

return ScrollArea


