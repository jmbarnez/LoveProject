local Fonts = {}

function Fonts.setup(Theme)
  local defaultFont = love.graphics.newFont(12)

  Theme.fonts = {
    normal = defaultFont,
    medium = love.graphics.newFont(16),
    large = love.graphics.newFont(18),
    small = love.graphics.newFont(12),
    xsmall = love.graphics.newFont(10),
    title = love.graphics.newFont(20),
    monospace = love.graphics.newFont("assets/fonts/PressStart2P-Regular.ttf", 12),
  }

  function Theme.loadFonts()
    -- Lazy load viewport to avoid circular dependency
    local Viewport = require("src.core.viewport")

    -- Get font scale (separate from UI scale)
    local fontScale = (Viewport.getFontScale() or 1.0) * (Viewport.getUIScale() or 1.0)
    local fontPath = "assets/fonts/PressStart2P-Regular.ttf"
    local fontSizes = {
      xsmall = 6,    -- Smaller for compact UI elements
      small = 8,     -- Smaller for buttons and compact text
      normal = 10,   -- Reduced for better button text fit
      medium = 12,   -- Reduced for better UI text fit
      large = 14,    -- Reduced for better UI text fit
      title = 16,    -- Reduced for better UI text fit
      monospace = 8  -- Smaller for compact UI elements
    }

    -- Initialize fonts table if it doesn't exist
    Theme.fonts = Theme.fonts or {}

    -- Create or update each font with crisp filtering
    for name, size in pairs(fontSizes) do
      local scaledSize = math.max(8, math.floor(size * fontScale + 0.5))
      if not Theme.fonts[name] or Theme.fonts[name]:getHeight() ~= scaledSize then
        if name == "monospace" then
          Theme.fonts[name] = love.graphics.newFont(fontPath, scaledSize)
        else
          Theme.fonts[name] = love.graphics.newFont(fontPath, scaledSize)
        end
        -- Use nearest neighbor filtering for maximum crispness
        Theme.fonts[name]:setFilter('nearest', 'nearest', 1)
      end
    end

    -- Set default font
    love.graphics.setFont(Theme.fonts.normal)
    return Theme.fonts
  end

  function Theme.getFont(size)
    -- Unified font getter with consistent fallback
    size = size or "normal"
    if Theme.fonts and Theme.fonts[size] then
      return Theme.fonts[size]
    end
    return love.graphics.getFont()
  end

  function Theme.setFont(size)
    -- Unified font setter
    local font = Theme.getFont(size)
    love.graphics.setFont(font)
    return font
  end

  function Theme.withFont(size, callback)
    -- Temporarily set font, execute callback, then restore
    local oldFont = love.graphics.getFont()
    Theme.setFont(size)
    local result = callback()
    love.graphics.setFont(oldFont)
    return result
  end
end

return Fonts
