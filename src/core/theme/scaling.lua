local Scaling = {}

function Scaling.setup(Theme)
  function Theme.getUIScale()
    -- Get current UI scale with fallback
    local Viewport = require("src.core.viewport")
    return Viewport.getUIScale() or 1.0
  end

  function Theme.getScaledSize(baseSize)
    -- Get scaled size with proper rounding
    return math.floor(baseSize * Theme.getUIScale() + 0.5)
  end

  function Theme.getScaledRect(baseRect)
    -- Get scaled rectangle
    return {
      x = Theme.getScaledSize(baseRect.x),
      y = Theme.getScaledSize(baseRect.y),
      w = Theme.getScaledSize(baseRect.w),
      h = Theme.getScaledSize(baseRect.h),
    }
  end
end

return Scaling
