local Interactions = {}

function Interactions.setup(Theme, Sound)
  function Theme.handleButtonClick(button, x, y, callback, playSound)
    if not button._rect then return false end

    local isClicked = x >= button._rect.x and
                     x <= button._rect.x + button._rect.w and
                     y >= button._rect.y and
                     y <= button._rect.y + button._rect.h

    if isClicked then
      if playSound ~= false then
        Sound.playSFX("button_click")
      end
      if type(callback) == "function" then
        callback()
      end
    end

    return isClicked
  end
end

return Interactions
