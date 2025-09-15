local Theme = {}
local Viewport = require("src.core.viewport")
local Sound = require("src.core.sound")

-- ===== MODERN DARK SLEEK THEME =====
-- A contemporary dark UI theme with sleek modern design
-- Clean flat surfaces, subtle shadows, and sophisticated color palette
-- Professional gaming aesthetic with modern UX principles


-- === SCI-FI DARK THEME WITH CYAN ACCENTS ===
Theme.colors = {
  -- Sci-fi dark primaries
  primary = {0.05, 0.08, 0.1, 1.00},       -- Deep space blue
  primaryBright = {0.1, 0.15, 0.2, 1.00},  -- Lighter space blue
  primaryDark = {0.02, 0.04, 0.06, 1.00},  -- Very deep space blue
  primaryDim = {0.01, 0.02, 0.03, 0.80},   -- Near black

  -- Sci-fi accent colors (cyan focus)
  accent = {0.0, 0.8, 0.8, 1.00},        -- Bright cyan
  accentGold = {0.85, 0.65, 0.25, 1.00},   -- Elegant gold
  accentTeal = {0.25, 0.75, 0.80, 1.00},   -- Cyan accent
  accentPink = {0.90, 0.40, 0.70, 1.00},   -- Magenta accent

  -- Status colors (modern palette)
  success = {0.25, 0.85, 0.35, 1.00},      -- Fresh green
  warning = {0.95, 0.70, 0.20, 1.00},      -- Warm amber
  danger = {0.95, 0.35, 0.35, 1.00},       -- Clean red
  info = {0.35, 0.65, 0.95, 1.00},         -- Soft blue

  -- Modern background layers (subtle gradients)
  bg0 = {0.02, 0.02, 0.03, 0.98},          -- Deep space black
  bg1 = {0.08, 0.08, 0.10, 1.00},          -- Primary surface
  bg2 = {0.12, 0.12, 0.15, 1.00},          -- Secondary surface
  bg3 = {0.18, 0.18, 0.22, 1.00},          -- Tertiary surface
  bg4 = {0.25, 0.25, 0.30, 1.00},          -- Quaternary surface

  -- Modern window chrome
  windowBg = {0.06, 0.06, 0.08, 0.95},     -- Glass-like background
  titleBar = {0.10, 0.12, 0.16, 1.00},     -- Subtle title bar
  titleBarAccent = {0.20, 0.25, 0.35, 1.00}, -- Soft accent

  -- Modern borders (subtle, not harsh)
  border = {0.20, 0.20, 0.25, 0.60},       -- Soft border
  borderBright = {0.35, 0.35, 0.45, 0.80}, -- Highlight border
  borderGlow = {0.30, 0.50, 0.90, 0.20},   -- Subtle glow
  outline = {0.15, 0.15, 0.20, 0.80},      -- Soft outline

  -- Modern typography
  text = {0.95, 0.95, 0.98, 1.00},         -- Pure white text
  textSecondary = {0.75, 0.75, 0.80, 1.00}, -- Light grey
  textTertiary = {0.55, 0.55, 0.60, 1.00}, -- Medium grey
  textDisabled = {0.40, 0.40, 0.45, 0.60}, -- Disabled text
  textHighlight = {0.95, 0.95, 1.00, 1.00}, -- Bright highlight

  -- Modern status colors
  shield = {0.25, 0.70, 0.95, 1.00},       -- Electric blue
  armor = {0.95, 0.60, 0.25, 1.00},        -- Warm orange
  hull = {0.95, 0.30, 0.35, 1.00},         -- Clean red
  capacitor = {0.95, 0.90, 0.25, 1.00},    -- Bright yellow
  damage = {0.95, 0.80, 0.30, 0.80},      -- Bright yellow-orange for damage flash

  -- Modern effects (subtle and sophisticated)
  glow = {0.30, 0.50, 0.90, 0.15},         -- Soft blue glow
  glowStrong = {0.30, 0.50, 0.90, 0.25},   -- Enhanced glow
  shadow = {0.00, 0.00, 0.00, 0.40},       -- Soft shadow
  highlight = {1.00, 1.00, 1.00, 0.08},    -- Subtle highlight

  -- Modern interaction states
  selection = {0.30, 0.50, 0.90, 0.30},    -- Soft selection
  focus = {0.30, 0.50, 0.90, 0.50},        -- Clear focus
  hover = {0.20, 0.20, 0.25, 0.60},        -- Subtle hover

  -- Modern transparency
  transparent = {0.00, 0.00, 0.00, 0.00},
  overlay = {0.00, 0.00, 0.00, 0.60},
}

-- === FONTS ===
-- UI font definitions (Love2D default font at standardized sizes)
Theme.fonts = {
  normal = love.graphics.newFont("assets/fonts/PressStart2P-Regular.ttf", 10),
  medium = love.graphics.newFont("assets/fonts/PressStart2P-Regular.ttf", 12),
  large = love.graphics.newFont("assets/fonts/PressStart2P-Regular.ttf", 14),
  small = love.graphics.newFont("assets/fonts/PressStart2P-Regular.ttf", 8),
  xsmall = love.graphics.newFont("assets/fonts/PressStart2P-Regular.ttf", 6),
  title = love.graphics.newFont("assets/fonts/PressStart2P-Regular.ttf", 16),
  monospace = love.graphics.newFont("assets/fonts/PressStart2P-Regular.ttf", 10),
}

function Theme.loadFonts()
  -- Get font scale (separate from UI scale)
  local fontScale = (Viewport.getFontScale() or 1.0) * (Viewport.getUIScale() or 1.0)

  -- Scale font sizes based on font scale
  Theme.fonts = {
    normal = love.graphics.newFont("assets/fonts/PressStart2P-Regular.ttf", math.floor(10 * fontScale + 0.5)),
    medium = love.graphics.newFont("assets/fonts/PressStart2P-Regular.ttf", math.floor(12 * fontScale + 0.5)),
    large = love.graphics.newFont("assets/fonts/PressStart2P-Regular.ttf", math.floor(14 * fontScale + 0.5)),
    small = love.graphics.newFont("assets/fonts/PressStart2P-Regular.ttf", math.floor(8 * fontScale + 0.5)),
    xsmall = love.graphics.newFont("assets/fonts/PressStart2P-Regular.ttf", math.floor(6 * fontScale + 0.5)),
    title = love.graphics.newFont("assets/fonts/PressStart2P-Regular.ttf", math.floor(16 * fontScale + 0.5)),
    monospace = love.graphics.newFont("assets/fonts/PressStart2P-Regular.ttf", math.floor(10 * fontScale + 0.5)),
  }
  love.graphics.setFont(Theme.fonts.normal)
end

-- Draw text scaled to fit a maximum width, centered or aligned
-- Returns the scale used
function Theme.drawTextFit(text, x, y, maxWidth, align, baseFont, minScale, maxScale)
  align = align or 'left'
  baseFont = baseFont or (Theme.fonts and Theme.fonts.normal) or love.graphics.getFont()
  minScale = minScale or 0.75
  maxScale = maxScale or 1.5

  local oldFont = love.graphics.getFont()
  love.graphics.setFont(baseFont)
  local font = baseFont
  local textW = math.max(1, font:getWidth(text))
  local scale = math.max(minScale, math.min(maxScale, maxWidth / textW))

  local drawX = x
  if align == 'center' then
    drawX = x + (maxWidth - textW * scale) * 0.5
  elseif align == 'right' then
    drawX = x + (maxWidth - textW * scale)
  end

  love.graphics.push()
  love.graphics.translate(math.floor(drawX + 0.5), math.floor(y + 0.5))
  love.graphics.scale(scale, scale)
  love.graphics.print(text, 0, 0)
  love.graphics.pop()

  if oldFont then love.graphics.setFont(oldFont) end
  return scale
end

-- === SEMANTIC COLOR MAPPINGS ===
-- Map semantic meanings to specific colors for consistency
Theme.semantic = {
  -- Button states
  buttonDefault = Theme.colors.bg2,
  buttonHover = Theme.colors.bg3,
  buttonActive = Theme.colors.bg4,
  buttonBorder = Theme.colors.border,

  -- Status bar colors
  statusHull = Theme.colors.hull,
  statusShield = Theme.colors.shield,
  statusCapacitor = Theme.colors.capacitor,

  -- Modern Status bar colors
  modernStatusHull = Theme.colors.danger,
  modernStatusShield = Theme.colors.info,
  modernStatusCapacitor = Theme.colors.warning,
  modernStatusCritical = Theme.colors.danger,
  modernStatusDamage = Theme.colors.damage,
  modernStatusXP = {0.6, 0.4, 0.8, 1.00},

  -- Text colors
  textPrimary = Theme.colors.text,
  textSecondary = Theme.colors.textSecondary,
  textDisabled = Theme.colors.textDisabled,
}

-- === MINIMAL EFFECT SETTINGS ===
-- Reduced effects for classic Windows look
Theme.effects = {
  glowWeak = 0.05,
  glowSubtle = 0.10,
  glowMedium = 0.15,
  glowStrong = 0.20,
  glowBright = 0.25,
}

-- Explorer/content theme (used by some UI windows)
Theme.explorer = {
  contentBg = Theme.colors.bg0,
}

-- === UTILITY FUNCTIONS ===
-- Core theme utility functions

function Theme.setColor(color)
  if color and #color >= 3 then
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1.0)
  end
end

function Theme.withAlpha(color, alpha)
  return {color[1], color[2], color[3], alpha}
end

function Theme.blend(color1, color2, factor)
  factor = math.max(0, math.min(1, factor))
  return {
    color1[1] + (color2[1] - color1[1]) * factor,
    color1[2] + (color2[2] - color1[2]) * factor,
    color1[3] + (color2[3] - color1[3]) * factor,
    (color1[4] or 1) + ((color2[4] or 1) - (color1[4] or 1)) * factor
  }
end

function Theme.pulseColor(baseColor, pulseColor, time, speed)
  speed = speed or 2.0
  local intensity = (math.sin(time * speed) * 0.5 + 0.5)
  return Theme.blend(baseColor, pulseColor, intensity * 0.3)
end

function Theme.shimmerColor(baseColor, time, intensity)
  intensity = intensity or 0.2
  local shimmer = math.sin(time * 3) * intensity
  return {
    math.min(1, baseColor[1] + shimmer),
    math.min(1, baseColor[2] + shimmer),
    math.min(1, baseColor[3] + shimmer),
    baseColor[4] or 1
  }
end

function Theme.drawVerticalGradient(x, y, w, h, topColor, bottomColor, steps)
  steps = steps or 20
  local r1, g1, b1, a1 = topColor[1], topColor[2], topColor[3], topColor[4] or 1
  local r2, g2, b2, a2 = bottomColor[1], bottomColor[2], bottomColor[3], bottomColor[4] or 1
  local dr, dg, db, da = (r2 - r1) / steps, (g2 - g1) / steps, (b2 - b1) / steps, (a2 - a1) / steps
  local stepH = h / steps
  for i = 0, steps - 1 do
    love.graphics.setColor(r1 + dr * i, g1 + dg * i, b1 + db * i, a1 + da * i)
    love.graphics.rectangle("fill", x, y + i * stepH, w, stepH + 1) -- +1 to avoid gaps
  end
end

function Theme.drawHorizontalGradient(x, y, w, h, leftColor, rightColor, steps)
  -- Use solid color instead of gradient - use the left color as the solid color
  Theme.setColor(leftColor)
  love.graphics.rectangle("fill", x, y, w, h)
end

function Theme.drawCloseButton(rect, hover)
  Theme.drawGradientGlowRect(rect.x, rect.y, rect.w, rect.h, 4,
    hover and Theme.colors.danger or Theme.colors.bg2,
    Theme.colors.bg1, Theme.colors.border, hover and Theme.effects.glowMedium or Theme.effects.glowWeak)

  local oldFont = love.graphics.getFont()
  love.graphics.setFont(Theme.fonts and Theme.fonts.small or oldFont)
  Theme.setColor(hover and Theme.colors.textHighlight or Theme.colors.textSecondary)
  local font = love.graphics.getFont()
  local textWidth = font:getWidth("×")
  local textHeight = font:getHeight()
  love.graphics.print("×", math.floor(rect.x + (rect.w - textWidth) / 2), math.floor(rect.y + (rect.h - textHeight) / 2))
  if oldFont then love.graphics.setFont(oldFont) end
end

function Theme.drawGradientGlowRect(x, y, w, h, radius, topColor, bottomColor, glowColor, glowIntensity)
  -- Hard corners for classic Windows style
  local cornerRadius = 0

  -- Draw subtle shadow for depth
  if glowIntensity and glowIntensity > 0 then
    Theme.setColor(Theme.withAlpha(Theme.colors.shadow, glowIntensity * 0.3))
    love.graphics.rectangle("fill", x + 2, y + 2, w, h)
  end

  -- Main surface with subtle gradient
  Theme.setColor(topColor)
  love.graphics.rectangle("fill", x, y, w, h)

  -- Subtle border for definition
  Theme.setColor(Theme.colors.border)
  love.graphics.rectangle("line", x, y, w, h)
end

function Theme.drawEVEBorder(x, y, w, h, radius, borderColor, cornerSize)
  -- Hard corners for classic Windows style
  local cornerRadius = 0
  Theme.setColor(borderColor)
  love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
end

function Theme.drawDesignToken(x, y, size)
    local radius = size / 2
    local centerX = x + radius
    local centerY = y + radius

    -- A more fitting design for the currency token
    Theme.setColor(Theme.colors.accentGold)
    love.graphics.circle("fill", centerX, centerY, radius)
    Theme.setColor(Theme.colors.border)
    love.graphics.circle("line", centerX, centerY, radius)
    local oldFont = love.graphics.getFont()
    love.graphics.setFont(Theme.fonts and Theme.fonts.xsmall or oldFont)
    Theme.setColor(Theme.colors.bg0)
    local coinFont = love.graphics.getFont()
    love.graphics.print("C", math.floor(centerX - coinFont:getWidth("C") * 0.5 + 0.5), math.floor(centerY - coinFont:getHeight() * 0.5 + 0.5))
    if oldFont then love.graphics.setFont(oldFont) end
end

function Theme.drawCurrencyToken(x, y, size)
    Theme.drawDesignToken(x, y, size)
end
function Theme.drawXPIcon(x, y, size)
    local radius = size / 2
    local centerX = x + radius
    local centerY = y + radius

    Theme.setColor({0.6, 0.4, 0.8, 1.00})
    love.graphics.circle("fill", centerX, centerY, radius)
    Theme.setColor(Theme.colors.border)
    love.graphics.circle("line", centerX, centerY, radius)
    local oldFont = love.graphics.getFont()
    love.graphics.setFont(Theme.fonts and Theme.fonts.xsmall or oldFont)
    Theme.setColor(Theme.colors.text)
    local xpFont = love.graphics.getFont()
    love.graphics.print("XP", math.floor(centerX - xpFont:getWidth("XP") * 0.5 + 0.5), math.floor(centerY - xpFont:getHeight() * 0.5 + 0.5))
    if oldFont then love.graphics.setFont(oldFont) end
end

function Theme.drawEVEProgressBar(x, y, w, h, progress, bgColor, fillColor, glowColor, time)
  progress = math.max(0, math.min(1, progress))
  local cornerRadius = 0

  -- Modern background with subtle shadow
  Theme.setColor(Theme.withAlpha(Theme.colors.shadow, 0.2))
  love.graphics.rectangle("fill", x + 1, y + 1, w, h)

  -- Main background
  Theme.setColor(bgColor)
  love.graphics.rectangle("fill", x, y, w, h)

  -- Progress fill with modern styling
  if progress > 0 then
    local fillW = math.floor((w - 4) * progress)
    Theme.setColor(fillColor)
    love.graphics.rectangle("fill", x + 2, y + 2, fillW, h - 4)

    -- Subtle inner highlight for depth
    if fillW > 4 then
      Theme.setColor(Theme.withAlpha(Theme.colors.highlight, 0.3))
      love.graphics.rectangle("fill", x + 3, y + 3, math.min(fillW - 4, fillW), 2)
    end
  end

  -- Modern border
  Theme.setColor(Theme.colors.border)
  love.graphics.rectangle("line", x, y, w, h)
end

function Theme.drawModernBar(x, y, w, h, progress, color)
    progress = math.max(0, math.min(1, progress))
    local cornerRadius = 4

    -- Background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", x, y, w, h, cornerRadius)

    -- Inner shadow for depth
    Theme.setColor(Theme.withAlpha(Theme.colors.bg0, 0.5))
    love.graphics.rectangle("fill", x + 1, y + 1, w - 2, h - 2, cornerRadius)

    -- Compute inner fill width once and avoid drawing colored fill/glow when zero
    local innerW = w - 4
    local fillW = math.floor(innerW * progress)

    -- Progress fill (only if at least 1px wide)
    if fillW > 0 then
        local gx, gy, gw, gh = x + 2, y + 2, fillW, h - 4

        -- Main fill with gradient
        local topColor = Theme.blend(color, {1,1,1,1}, 0.2)
        local bottomColor = color
        Theme.drawVerticalGradient(gx, gy, gw, gh, topColor, bottomColor)

        -- Highlight
        if gw > 0 then
            Theme.setColor(Theme.withAlpha(Theme.colors.highlight, 0.5))
            love.graphics.rectangle("fill", gx, gy, gw, 2, cornerRadius)
        end

        -- Glow
        Theme.setColor(Theme.withAlpha(color, 0.2))
        love.graphics.rectangle("fill", gx - 2, gy - 2, gw + 4, gh + 4, cornerRadius + 2)
    end

    -- Border
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle("line", x, y, w, h, cornerRadius)
end

function Theme.drawSciFiBar(x, y, w, h, progress, color)
    progress = math.max(0, math.min(1, progress))
    local cut = h / 2 -- The size of the angular cut

    -- Define the vertices for the bar's shape
    local bgShape = {
        x, y + cut,
        x + cut, y,
        x + w, y,
        x + w, y + h - cut,
        x + w - cut, y + h,
        x, y + h
    }

    -- Background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.polygon("fill", bgShape)

    -- Inner shadow for depth
    Theme.setColor(Theme.withAlpha(Theme.colors.bg0, 0.5))
    love.graphics.polygon("fill", bgShape)

    -- Progress fill
    if progress > 0 then
        local fillW = math.floor(w * progress)

        -- Define the vertices for the fill shape, properly clipped to follow the angled contour
        local fillShape = {}

        if fillW >= w then
            -- Full fill - use the entire background shape
            fillShape = bgShape
        else
            -- Partial fill - construct polygon that follows the contour
            if fillW <= cut then
                -- Only the left cut section is partially filled
                -- Intersect along the left diagonal from (x, y+cut) to (x+cut, y)
                -- At horizontal extent fillW, the vertical point on the diagonal is y + (cut - fillW)
                fillShape = {
                    x, y + cut,
                    x + cut, y,
                    x + fillW, y,
                    x + fillW, y + (cut - fillW),
                    x, y + cut -- Close the shape
                }
            elseif fillW > cut and fillW <= w - cut then
                -- The bar is filled past the left cut and into the rectangular middle
                fillShape = {
                    x, y + cut,
                    x + cut, y,
                    x + fillW, y,
                    x + fillW, y + h,
                    x, y + h
                }
            else -- fillW > w - cut
                -- The bar is filled into the right cut section
                -- Calculate how far into the right cut we are, clamped to prevent overflow
                local cutProgress = math.min(fillW - (w - cut), cut)
                fillShape = {
                    x, y + cut,
                    x + cut, y,
                    x + w, y,
                    x + w, y + h - cut,
                    x + w - cut, y + h,
                    x + cutProgress, y + h, -- Properly clamped to stay within bounds
                    x, y + h
                }
            end
        end

        -- Main fill
        Theme.setColor(color)
        love.graphics.polygon("fill", fillShape)

        -- Glow effect
        Theme.setColor(Theme.withAlpha(color, 0.2))
        love.graphics.polygon("fill", fillShape)
    end

    -- Border
    Theme.setColor(Theme.colors.border)
    love.graphics.polygon("line", bgShape)
end

function Theme.drawSimpleBar(x, y, w, h, progress, color)
    progress = math.max(0, math.min(1, progress))

    -- Background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", x, y, w, h)

    -- Inner shadow for minimal depth
    Theme.setColor(Theme.withAlpha(Theme.colors.bg0, 0.3))
    love.graphics.rectangle("fill", x + 1, y + 1, w - 2, h - 2)

    -- Progress fill
    if progress > 0 then
        local fillW = math.floor((w - 2) * progress)
        Theme.setColor(color)
        love.graphics.rectangle("fill", x + 1, y + 1, fillW, h - 2)
    end

    -- Simple border
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle("line", x, y, w, h)
end


-- Optional opts: { compact=true } to use smaller text
function Theme.drawStyledButton(x, y, w, h, text, hover, t, color, down, opts)
  local pulseColor = {0, 0, 0, 0.05} -- More transparent black border
  local glowIntensity = hover and Theme.effects.glowMedium * 0.7 or Theme.effects.glowWeak * 0.7

  -- Create transparent versions of the colors
  local bg3 = {Theme.colors.bg3[1], Theme.colors.bg3[2], Theme.colors.bg3[3], 0.7}
  local bg2 = {Theme.colors.bg2[1], Theme.colors.bg2[2], Theme.colors.bg2[3], 0.5}
  local bg4 = {Theme.colors.bg4[1], Theme.colors.bg4[2], Theme.colors.bg4[3], 0.8}
  
  local topColor = color or (hover and bg3 or bg2)
  if down then
    topColor = bg4
  end

  Theme.drawGradientGlowRect(x, y, w, h, 10,
    topColor,
    Theme.colors.bg1, pulseColor, glowIntensity)

  Theme.drawEVEBorder(x, y, w, h, 10, pulseColor, 12)

  -- Choose the largest prebuilt font that fits to keep text crisp
  local padX = 12
  local maxTextW = math.max(10, w - padX * 2)
  local candidates = {
    Theme.fonts and Theme.fonts.large,
    Theme.fonts and Theme.fonts.medium,
    Theme.fonts and Theme.fonts.normal,
    Theme.fonts and Theme.fonts.small,
    Theme.fonts and Theme.fonts.xsmall,
    love.graphics.getFont(),
  }

  if opts and opts.compact then
    -- Prefer smaller fonts for compact buttons
    candidates = {
      Theme.fonts and Theme.fonts.normal,
      Theme.fonts and Theme.fonts.small,
      Theme.fonts and Theme.fonts.xsmall,
      love.graphics.getFont(),
    }
  end

  local bestFont = nil
  for _, f in ipairs(candidates) do
    if f then
      local tw = f:getWidth(text)
      if tw <= maxTextW and f:getHeight() <= h - 6 then
        bestFont = f
        break
      end
    end
  end
  if not bestFont then
    -- Fallback to smallest available to avoid overflow
    bestFont = candidates[#candidates]
  end

  local oldFont = love.graphics.getFont()
  love.graphics.setFont(bestFont)
  local tw = bestFont:getWidth(text)
  local th = bestFont:getHeight()
  local textX = math.floor(x + (w - tw) * 0.5 + 0.5)
  local textY = math.floor(y + (h - th) * 0.5 + 0.5)

  -- Shadow with reduced opacity
  local shadowColor = {Theme.colors.shadow[1], Theme.colors.shadow[2], Theme.colors.shadow[3], Theme.colors.shadow[4] * 0.7}
  Theme.setColor(shadowColor)
  love.graphics.print(text, textX, textY + 1)

  -- Semi-transparent white text
  Theme.setColor({1, 1, 1, 0.9}) -- 90% opacity white
  love.graphics.print(text, textX, textY)

  -- Restore font
  if oldFont then love.graphics.setFont(oldFont) end
end

-- Handle button clicks with sound
-- Returns true if the button was clicked, false otherwise
function Theme.handleButtonClick(button, x, y, callback, playSound)
  if not button._rect then return false end
  
  local isClicked = x >= button._rect.x and 
                   x <= button._rect.x + button._rect.w and 
                   y >= button._rect.y and 
                   y <= button._rect.y + button._rect.h
  
  if isClicked then
    if playSound ~= false then -- Default to playing sound unless explicitly set to false
      Sound.playSFX("button_click")
    end
    if type(callback) == "function" then
      callback()
    end
  end
  
  return isClicked
end

-- === MODERN SLEEK COMPONENT PRESETS ===
Theme.components = {
  -- Modern sleek window
  window = {
    bg = Theme.colors.windowBg,
    border = Theme.colors.border,
    shadow = Theme.colors.shadow,
    titleBg = Theme.colors.titleBar,
    titleText = Theme.colors.text,
    titleAccent = Theme.colors.titleBarAccent,
    glowIntensity = Theme.effects.glowWeak,
  },

  -- Modern sleek buttons
  button = {
    bg = Theme.colors.bg2,
    bgHover = Theme.colors.bg3,
    bgActive = Theme.colors.bg4,
    border = Theme.colors.border,
    borderHover = Theme.colors.borderBright,
    borderActive = Theme.colors.accent,
    text = Theme.colors.text,
    textHover = Theme.colors.textHighlight,
    glow = Theme.colors.glow,
    glowIntensity = Theme.effects.glowSubtle,
  },
}

-- Modern sleek colors for turret slots
Theme.turretSlotColors = {
  {0.30, 0.50, 0.90, 1.00}, -- Slot 1: modern blue
  {0.25, 0.85, 0.35, 1.00}, -- Slot 2: fresh green
  {0.95, 0.35, 0.35, 1.00}, -- Slot 3: clean red
  {0.95, 0.70, 0.20, 1.00}, -- Slot 4: warm amber
}

return Theme
