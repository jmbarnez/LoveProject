local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")

local TextInput = {}

-- Simple single-line text input (no IME). State carries: { text, active }
-- Returns rect and optionally updates state.text when drawing caret.
function TextInput.draw(x, y, w, h, state, placeholder)
  state = state or { text = "", active = false }
  local mx, my = Viewport.getMousePosition()
  local hover = mx >= x and mx <= x + w and my >= y and my <= y + h
  local borderColor = state.active and Theme.colors.accent or Theme.colors.border
  Theme.drawGradientGlowRect(x, y, w, h, 3, Theme.colors.bg0, Theme.colors.bg1, borderColor, Theme.effects.glowWeak)
  local txt = (state.text and #state.text > 0) and state.text or (placeholder or "")
  Theme.setColor((state.text and #state.text > 0) and Theme.colors.text or Theme.colors.textDisabled)
  local oldFont = love.graphics.getFont()
  love.graphics.setFont(Theme.fonts and Theme.fonts.small or oldFont)
  local padX = (Theme.ui and Theme.ui.menuButtonPaddingX) or 6
  love.graphics.print(txt, x + padX, y + (h - (love.graphics.getFont():getHeight())) * 0.5)
  if state.active and math.fmod(love.timer.getTime(), 1) > 0.5 then
    local fw = love.graphics.getFont():getWidth(state.text or "")
    Theme.setColor(Theme.colors.text)
    love.graphics.rectangle("fill", x + padX + fw + 1, y + 4, 2, h - 8)
  end
  if oldFont then love.graphics.setFont(oldFont) end
  return { x = x, y = y, w = w, h = h }, hover
end

return TextInput


