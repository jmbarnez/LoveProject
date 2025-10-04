local Theme = {}
local Sound = require("src.core.sound")

-- ===== DARK CYAN/LAVENDER SPACE THEME =====
-- Ultra-dark space aesthetic with cyan primary accents and lavender highlights
-- Deep void backgrounds with electric cyan highlights and ethereal lavender undertones
-- Mysterious sci-fi gaming theme with stellar contrast and depth


-- === DARK CYAN/LAVENDER SPACE THEME ===
Theme.colors = {
  -- Pure black space primaries
  primary = {0.0, 0.0, 0.0, 1.00},         -- Pure black
  primaryBright = {0.0, 0.0, 0.0, 1.00},   -- Pure black
  primaryDark = {0.0, 0.0, 0.0, 1.00},     -- Pure black
  primaryDim = {0.0, 0.0, 0.0, 1.00},      -- Pure black

  -- Single monochrome accent color
  accent = {0.7, 0.7, 0.7, 1.00},          -- Medium gray (single accent)
  accentGold = {0.7, 0.7, 0.7, 1.00},      -- Same as accent
  accentTeal = {0.7, 0.7, 0.7, 1.00},      -- Same as accent
  accentPink = {0.7, 0.7, 0.7, 1.00},      -- Same as accent

  -- Space-themed status colors
  success = {0.3, 0.9, 0.6, 1.00},         -- Cyan-tinted green
  warning = {0.9, 0.6, 0.4, 1.00},         -- Lavender-tinted amber
  danger = {0.9, 0.3, 0.5, 1.00},          -- Magenta red
  info = {0.0, 1.0, 1.0, 1.00},            -- Cyan

  -- Pure black backgrounds
  bg0 = {0.0, 0.0, 0.0, 1.00},             -- Pure black
  bg1 = {0.0, 0.0, 0.0, 1.00},             -- Pure black
  bg2 = {0.0, 0.0, 0.0, 1.00},             -- Pure black
  bg3 = {0.0, 0.0, 0.0, 1.00},             -- Pure black
  bg4 = {0.0, 0.0, 0.0, 1.00},             -- Pure black

  -- Pure black UI chrome
  windowBg = {0.0, 0.0, 0.0, 1.00},        -- Pure black
  titleBar = {0.0, 0.0, 0.0, 1.00},        -- Pure black
  titleBarAccent = {0.7, 0.7, 0.7, 1.00},  -- Gray accent

  -- Unified border color
  border = {0.7, 0.7, 0.7, 0.8},           -- Single gray border color
  borderBright = {0.7, 0.7, 0.7, 0.8},     -- Same as border
  borderGlow = {0.7, 0.7, 0.7, 0.8},       -- Same as border
  outline = {0.5, 0.7, 0.9, 0.8},          -- Same as border

  -- Starfield typography
  text = {0.95, 0.95, 1.00, 1.00},         -- Pure white stars
  textSecondary = {0.8, 0.85, 0.95, 1.00}, -- Cyan-tinted grey
  textTertiary = {0.6, 0.65, 0.75, 1.00},  -- Medium cyan-grey
  textDisabled = {0.3, 0.35, 0.45, 0.7},   -- Disabled cyan-grey
  textHighlight = {0.9, 0.95, 1.00, 1.00}, -- Bright starlight
  textStatus = {1.0, 1.0, 1.0, 1.00},      -- Pure white for status bars

  -- Dark space status indicators
  shield = {0.5, 0.7, 0.9, 1.00},          -- Cyan shield
  armor = {0.7, 0.5, 0.8, 1.00},           -- Lavender armor
  hull = {0.9, 0.4, 0.6, 1.00},            -- Magenta hull
  capacitor = {0.8, 0.9, 1.0, 1.00},       -- Cyan energy
  damage = {0.9, 0.6, 0.9, 0.9},           -- Lavender damage flash

  -- Dark nebula effects
  glow = {0.5, 0.7, 0.9, 0.3},             -- Cyan nebula glow
  glowStrong = {0.5, 0.7, 0.9, 0.5},       -- Strong cyan glow
  shadow = {0.0, 0.0, 0.0, 0.8},           -- Pure black shadow
  highlight = {0.8, 0.9, 1.0, 0.2},        -- Cyan highlight

  -- Dark space interaction states
  selection = {0.5, 0.7, 0.9, 0.5},        -- Cyan selection
  focus = {0.5, 0.7, 0.9, 0.7},            -- Cyan focus
  hover = {0.06, 0.08, 0.12, 1.00},        -- Dark cyan hover

  -- Dark space transparency
  transparent = {0.00, 0.00, 0.00, 0.00},
  overlay = {0.00, 0.00, 0.00, 0.0},

  -- Rarity colors
  rarity = {
    Common = {0.7, 0.7, 0.7, 1.0},      -- Gray
    Uncommon = {0.3, 0.9, 0.4, 1.0},    -- Green
    Rare = {0.4, 0.6, 1.0, 1.0},        -- Blue
    Epic = {0.8, 0.4, 0.9, 1.0},        -- Purple
    Legendary = {0.9, 0.6, 0.2, 1.0},   -- Orange
  },
}

-- === UI TOKENS (Source of truth for sizes/spacing) ===
Theme.ui = {
  titleBarHeight = 24,     -- Height of window title bars
  borderWidth = 2,         -- Standard window border width
  contentPadding = 15,     -- Default padding inside windows/panels
  buttonHeight = 28,       -- Default button height
  buttonSpacing = 4,       -- Spacing between stacked buttons
  menuButtonPaddingX = 12, -- Horizontal padding for button text
}

-- === FONTS ===
-- Modern, clean font for crisp UI rendering
-- Using a system font that scales cleanly at all sizes
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
    xsmall = 7,
    small = 9,
    normal = 11,
    medium = 13,
    large = 15,
    title = 17,
    monospace = 9
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

  -- Space Status bar colors
  modernStatusHull = Theme.colors.danger,
  modernStatusShield = Theme.colors.shield,
  modernStatusCapacitor = Theme.colors.capacitor,
  modernStatusCritical = Theme.colors.danger,
  modernStatusDamage = Theme.colors.damage,
  modernStatusXP = {0.6, 0.4, 0.9, 1.00}, -- Lavender XP

  -- Text colors
  textPrimary = Theme.colors.text,
  textSecondary = Theme.colors.textSecondary,
  textDisabled = Theme.colors.textDisabled,
}

-- === CRISP EFFECT SETTINGS ===
-- Sharp, clean effects for modern UI
Theme.effects = {
  glowWeak = 0.08,
  glowSubtle = 0.15,
  glowMedium = 0.25,
  glowStrong = 0.35,
  glowBright = 0.45,

  -- Animation timings
  transitionFast = 0.15,
  transitionNormal = 0.3,
  transitionSlow = 0.6,

  -- Particle system settings
  particleSize = { min = 1, max = 3 },
  particleSpeed = { min = 20, max = 80 },
  particleLifetime = { min = 0.5, max = 1.5 },

  -- Screen effects
  screenShake = { intensity = 3, duration = 0.2 },
  flashIntensity = 0.3,
  zoomIntensity = 1.05,
}

-- Explorer/content theme (used by some UI windows)
Theme.explorer = {
  contentBg = Theme.colors.bg0,
}

-- === UTILITY FUNCTIONS ===
-- Core theme utility functions

function Theme.setColor(color)
  if color then
    if type(color) == "table" and #color >= 3 then
      love.graphics.setColor(color[1], color[2], color[3], color[4] or 1.0)
    elseif type(color) == "table" and #color >= 1 then
      -- Handle single-value tables or other formats
      love.graphics.setColor(color[1], color[1], color[1], color[2] or 1.0)
    end
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

-- === ANIMATION SYSTEM ===
Theme.animations = {
  -- Store active animations
  active = {},
  nextId = 1,
}

-- Easing functions for smooth animations
function Theme.easeOut(t)
  return 1 - math.pow(1 - t, 3)
end

function Theme.easeIn(t)
  return t * t * t
end

function Theme.easeInOut(t)
  if t < 0.5 then
    return 4 * t * t * t
  else
    return 1 - math.pow(-2 * t + 2, 3) / 2
  end
end

-- Animate a value from start to target over duration
function Theme.animateValue(start, target, duration, easing, callback)
  local id = Theme.animations.nextId
  Theme.animations.nextId = Theme.animations.nextId + 1

  local animation = {
    start = start,
    target = target,
    duration = duration,
    easing = easing or Theme.easeInOut,
    callback = callback,
    startTime = love.timer.getTime(),
    completed = false
  }

  Theme.animations.active[id] = animation
  return id
end

-- Update all active animations
function Theme.updateAnimations(dt)
  local currentTime = love.timer.getTime()

  for id, animation in pairs(Theme.animations.active) do
    local elapsed = currentTime - animation.startTime
    local progress = math.min(elapsed / animation.duration, 1)

    if progress >= 1 then
      -- Animation complete
      if animation.callback then
        animation.callback(animation.target)
      end
      Theme.animations.active[id] = nil
    else
      -- Update animation
      local easedProgress = animation.easing(progress)
      local currentValue = animation.start + (animation.target - animation.start) * easedProgress

      if animation.callback then
        animation.callback(currentValue)
      end
    end
  end
end

-- === PARTICLE SYSTEM ===
Theme.particles = {
  active = {},
  nextId = 1,
}

-- Create a particle at position with velocity
function Theme.createParticle(x, y, color, velocityX, velocityY, size, lifetime)
  local id = Theme.particles.nextId
  Theme.particles.nextId = Theme.particles.nextId + 1

  local particle = {
    x = x,
    y = y,
    vx = velocityX or (math.random() * 2 - 1) * Theme.effects.particleSpeed.max,
    vy = velocityY or (math.random() * 2 - 1) * Theme.effects.particleSpeed.max,
    color = color or {1, 1, 1, 1},
    size = size or math.random(Theme.effects.particleSize.min, Theme.effects.particleSize.max),
    lifetime = lifetime or math.random(Theme.effects.particleLifetime.min, Theme.effects.particleLifetime.max),
    age = 0,
    active = true
  }

  Theme.particles.active[id] = particle
  return id
end

-- Update all particles
function Theme.updateParticles(dt)
  for id, particle in pairs(Theme.particles.active) do
    particle.age = particle.age + dt
    if particle.age >= particle.lifetime then
      particle.active = false
      Theme.particles.active[id] = nil
    else
      -- Update position
      particle.x = particle.x + particle.vx * dt
      particle.y = particle.y + particle.vy * dt

      -- Fade out over time
      local fadeProgress = particle.age / particle.lifetime
      particle.color[4] = (1 - fadeProgress) * particle.color[4]
    end
  end
end

-- Draw all active particles
function Theme.drawParticles()
  for _, particle in pairs(Theme.particles.active) do
    Theme.setColor(particle.color)
    love.graphics.circle("fill", particle.x, particle.y, particle.size)
  end
end

-- === SCREEN EFFECTS ===
Theme.screenEffects = {
  shake = { intensity = 0, duration = 0, timer = 0 },
  flash = { color = {1, 1, 1, 0}, duration = 0, timer = 0 },
  zoom = { scale = 1, duration = 0, timer = 0 },
}

-- Add screen shake effect
function Theme.shakeScreen(intensity, duration)
  Theme.screenEffects.shake.intensity = intensity or Theme.effects.screenShake.intensity
  Theme.screenEffects.shake.duration = duration or Theme.effects.screenShake.duration
  Theme.screenEffects.shake.timer = 0
end

-- Add screen flash effect
function Theme.flashScreen(color, duration)
  Theme.screenEffects.flash.color = color or {1, 1, 1, 1}
  Theme.screenEffects.flash.duration = duration or 0.2
  Theme.screenEffects.flash.timer = 0
end

-- Add zoom effect
function Theme.zoomScreen(scale, duration)
  Theme.screenEffects.zoom.scale = scale or Theme.effects.zoomIntensity
  Theme.screenEffects.zoom.duration = duration or 0.1
  Theme.screenEffects.zoom.timer = 0
end

-- Update screen effects
function Theme.updateScreenEffects(dt)
  -- Update shake
  if Theme.screenEffects.shake.timer < Theme.screenEffects.shake.duration then
    Theme.screenEffects.shake.timer = Theme.screenEffects.shake.timer + dt
    if Theme.screenEffects.shake.timer >= Theme.screenEffects.shake.duration then
      Theme.screenEffects.shake.intensity = 0
    end
  end

  -- Update flash
  if Theme.screenEffects.flash.timer < Theme.screenEffects.flash.duration then
    Theme.screenEffects.flash.timer = Theme.screenEffects.flash.timer + dt
    if Theme.screenEffects.flash.timer >= Theme.screenEffects.flash.duration then
      Theme.screenEffects.flash.color[4] = 0
    end
  end

  -- Update zoom
  if Theme.screenEffects.zoom.timer < Theme.screenEffects.zoom.duration then
    Theme.screenEffects.zoom.timer = Theme.screenEffects.zoom.timer + dt
    if Theme.screenEffects.zoom.timer >= Theme.screenEffects.zoom.duration then
      Theme.screenEffects.zoom.scale = 1
    end
  end
end

-- Get screen offset for shake effect
function Theme.getScreenShakeOffset()
  if Theme.screenEffects.shake.intensity > 0 and Theme.screenEffects.shake.timer < Theme.screenEffects.shake.duration then
    local progress = Theme.screenEffects.shake.timer / Theme.screenEffects.shake.duration
    local intensity = Theme.screenEffects.shake.intensity * (1 - progress)
    return math.random(-intensity, intensity), math.random(-intensity, intensity)
  end
  return 0, 0
end

-- Get screen flash alpha
function Theme.getScreenFlashAlpha()
  if Theme.screenEffects.flash.timer < Theme.screenEffects.flash.duration then
    local progress = Theme.screenEffects.flash.timer / Theme.screenEffects.flash.duration
    return (1 - progress) * Theme.screenEffects.flash.color[4]
  end
  return 0
end

-- Get screen zoom scale
function Theme.getScreenZoomScale()
  if Theme.screenEffects.zoom.timer < Theme.screenEffects.zoom.duration then
    local progress = Theme.screenEffects.zoom.timer / Theme.screenEffects.zoom.duration
    return 1 + (Theme.screenEffects.zoom.scale - 1) * progress
  end
  return 1
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
  -- Draw only the "×" symbol, no box background
  local oldFont = love.graphics.getFont()
  love.graphics.setFont(Theme.fonts and Theme.fonts.small or oldFont)
  Theme.setColor(hover and Theme.colors.danger or Theme.colors.textSecondary)
  local font = love.graphics.getFont()
  local textWidth = font:getWidth("×")
  local textHeight = font:getHeight()
  love.graphics.print("×",
    math.floor(rect.x + (rect.w - textWidth) / 2 + 0.5),
    math.floor(rect.y + (rect.h - textHeight) / 2 + 0.5))
  if oldFont then love.graphics.setFont(oldFont) end
end

function Theme.drawMaximizeButton(rect, hover, maximized)
  -- Draw maximize/restore icon using simple shapes
  Theme.setColor(hover and Theme.colors.accent or Theme.colors.textSecondary)
  
  local centerX = rect.x + rect.w * 0.5
  local centerY = rect.y + rect.h * 0.5
  local size = math.min(rect.w, rect.h) * 0.4
  
  if maximized then
    -- Restore icon: two overlapping squares
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", centerX - size * 0.6, centerY - size * 0.6, size * 0.8, size * 0.8)
    love.graphics.rectangle("line", centerX - size * 0.2, centerY - size * 0.2, size * 0.8, size * 0.8)
  else
    -- Maximize icon: single square
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", centerX - size * 0.5, centerY - size * 0.5, size, size)
  end
end

function Theme.drawGradientGlowRect(x, y, w, h, radius, topColor, bottomColor, glowColor, glowIntensity, drawBorder)
  -- Handle nil parameters gracefully
  if x == nil or y == nil or w == nil or h == nil then
    return
  end

  -- Clean, sharp corners
  local cornerRadius = 0

  -- Sharp shadow for depth (optional)
  if glowIntensity and glowIntensity > 0 then
    Theme.setColor(Theme.withAlpha(Theme.colors.shadow, glowIntensity * 0.4))
    love.graphics.rectangle("fill", math.floor(x + 1.5), math.floor(y + 1.5), w, h)
  end

  -- Main surface (flat, no gradient for crispness)
  Theme.setColor(topColor)
  love.graphics.rectangle("fill", math.floor(x + 0.5), math.floor(y + 0.5), w, h)

  -- Sharp border for definition (optional)
  if drawBorder ~= false then -- Default to true for backward compatibility
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", math.floor(x + 0.5), math.floor(y + 0.5), w, h)
  end
end

function Theme.drawEVEBorder(x, y, w, h, radius, borderColor, cornerSize)
  -- Handle nil parameters gracefully
  if x == nil or y == nil or w == nil or h == nil then
    return
  end

  Theme.setColor(borderColor)
  love.graphics.setLineWidth(1)

  x, y, w, h = math.floor(x + 0.5), math.floor(y + 0.5), w, h

  -- Simple rectangle border without corner pieces
  love.graphics.rectangle("line", x, y, w, h)
end

function Theme.drawDesignToken(x, y, size)
    local radius = size / 2
    local centerX = x + radius
    local centerY = y + radius

    -- Space-themed currency token
    Theme.setColor({0.6, 0.7, 1.0, 1.00}) -- Blue-tinted white
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

    Theme.setColor({0.7, 0.5, 0.9, 1.00}) -- Purple XP
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
    local cornerRadius = 0

    -- Clean background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", math.floor(x + 0.5), math.floor(y + 0.5), w, h, cornerRadius)

    -- Compute inner fill width
    local innerW = w - 2
    local fillW = math.floor(innerW * progress)

    -- Sharp progress fill (no gradients for crispness)
    if fillW > 0 then
        local gx, gy, gw, gh = math.floor(x + 1.5), math.floor(y + 1.5), fillW, h - 2

        -- Main fill (flat color for sharpness)
        Theme.setColor(color)
        love.graphics.rectangle("fill", gx, gy, gw, gh)

        -- Clean border highlight
        Theme.setColor(Theme.withAlpha(Theme.colors.highlight, 0.6))
        love.graphics.rectangle("fill", gx, gy, gw, 1)
    end

    -- Sharp border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", math.floor(x + 0.5), math.floor(y + 0.5), w, h, cornerRadius)
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

    -- Clean background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", math.floor(x + 0.5), math.floor(y + 0.5), w, h)

    -- Sharp progress fill
    if progress > 0 then
        local fillW = math.floor((w - 2) * progress)
        Theme.setColor(color)
        love.graphics.rectangle("fill", math.floor(x + 1.5), math.floor(y + 1.5), fillW, h - 2)
    end

    -- Sharp border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", math.floor(x + 0.5), math.floor(y + 0.5), w, h)
end


-- Optional opts: { compact=true } to use smaller text
function Theme.drawStyledButton(x, y, w, h, text, hover, t, color, down, opts)
  -- Handle nil parameters gracefully
  if x == nil or y == nil or w == nil or h == nil then
    return
  end

  local t = t or love.timer.getTime()
  
  -- No hover sounds - only click sounds for better UX
  
  -- Transparent background with accent border/text
  local baseColor = {0, 0, 0, 0} -- Fully transparent background
  local borderColor = Theme.colors.accent -- Accent border
  local textColor = Theme.colors.accent -- Accent text
  
  -- Use custom color if provided (for special buttons like Apply/Reset)
  if color then
    baseColor = {color[1], color[2], color[3], 1.0} -- Fully opaque custom color
    borderColor = {0, 0, 0, 1.0} -- Black border for custom colors
    textColor = {0, 0, 0, 1.0} -- Black text for custom colors
  end
  
  -- Hover effects
  if hover then
    if color then
      -- For custom colors, use brighter versions for hover effects
      baseColor = {color[1], color[2], color[3], 1.0} -- Fully opaque custom color on hover
      borderColor = {
        math.min(1.0, color[1] + 0.2), -- Brighter custom color border
        math.min(1.0, color[2] + 0.2),
        math.min(1.0, color[3] + 0.2),
        1.0
      }
      textColor = {0, 0, 0, 1.0} -- Keep black text for visibility
    else
      -- Add subtle background tint on hover for visibility
      baseColor = {Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], 0.2}
      
      -- Make border and text brighter on hover
      borderColor = {
        math.min(1.0, borderColor[1] + 0.3),
        math.min(1.0, borderColor[2] + 0.3), 
        math.min(1.0, borderColor[3] + 0.3),
        borderColor[4]
      }
      textColor = {
        math.min(1.0, textColor[1] + 0.3),
        math.min(1.0, textColor[2] + 0.3), 
        math.min(1.0, textColor[3] + 0.3),
        textColor[4]
      }
    end
    
    -- Add subtle pulsing effect (only for non-custom colored buttons)
    if not color then
      local pulseOffset = math.sin(t * 8) * 0.1
      borderColor[4] = math.min(1.0, borderColor[4] + pulseOffset)
      textColor[4] = math.min(1.0, textColor[4] + pulseOffset)
    end
    
    -- Slight scale effect
    local scale = 1.02
    local offsetX = (w * (scale - 1)) * 0.5
    local offsetY = (h * (scale - 1)) * 0.5
    x = x - offsetX
    y = y - offsetY
    w = w * scale
    h = h * scale
  end

  -- If pressed down, make it darker
  if down then
    baseColor = {
      baseColor[1] * 0.7,
      baseColor[2] * 0.7,
      baseColor[3] * 0.7,
      math.min(1.0, baseColor[4] * 1.5) -- Make it more opaque when pressed
    }
  end
  
  -- Draw button background
  Theme.setColor(baseColor)
  love.graphics.rectangle("fill", x, y, w, h)
  
  -- Draw accent border
  Theme.setColor(borderColor)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h)

  -- If a fixed font is provided via opts, use it for consistent sizing
  local padX = 12
  local maxTextW = math.max(10, w - padX * 2)
  local fixedFont = opts and opts.font
  if fixedFont then
    local oldFont = love.graphics.getFont()
    love.graphics.setFont(fixedFont)
    local tw = fixedFont:getWidth(text or "")
    local th = fixedFont:getHeight()

    Theme.setColor(textColor)
    local textX = math.floor(x + (w - tw) * 0.5 + 0.5)
    local textY = math.floor(y + (h - th) * 0.5 + 0.5)
    love.graphics.print(text, textX, textY)
    if oldFont then love.graphics.setFont(oldFont) end
    return
  end

  -- Use consistent font sizing for menu buttons
  local buttonFont = nil

  -- For menu buttons (start screen, escape menu), use consistent normal font size
  if opts and opts.menuButton then
    buttonFont = Theme.fonts and Theme.fonts.normal
  elseif opts and opts.compact then
    -- For other compact buttons, prefer smaller fonts but maintain consistency
    buttonFont = Theme.fonts and Theme.fonts.small
  end

  -- Fallback to choosing best fit if no specific font was requested
  if not buttonFont then
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
        local tw = f:getWidth(text or "")
        local fh = f:getHeight()
        if tw <= maxTextW and fh <= h - 6 then
          bestFont = f
          break
        end
      end
    end
    if not bestFont then
      -- Fallback to smallest available to avoid overflow
      for i = #candidates, 1, -1 do
        if candidates[i] then
          bestFont = candidates[i]
          break
        end
      end
    end
    buttonFont = bestFont
  end

  -- Safety check
  if not buttonFont then
    buttonFont = love.graphics.getFont() or Theme.fonts.normal or Theme.fonts.small
  end

  local oldFont = love.graphics.getFont()
  love.graphics.setFont(buttonFont)
  local tw = buttonFont:getWidth(text or "")
  local th = buttonFont:getHeight()
  local textX = math.floor(x + (w - tw) * 0.5 + 0.5)
  local textY = math.floor(y + (h - th) * 0.5 + 0.5)

  -- Draw text in accent color
  Theme.setColor(textColor)
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

-- === SPACE COMPONENT PRESETS ===
Theme.components = {
  -- Deep space window
  window = {
    bg = Theme.colors.windowBg,
    border = Theme.colors.border,
    shadow = Theme.colors.shadow,
    titleBg = Theme.colors.titleBar,
    titleText = Theme.colors.text,
    titleAccent = Theme.colors.titleBarAccent,
    glowIntensity = Theme.effects.glowWeak,
  },

  -- Space-themed buttons
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

  -- Tooltip configuration
  tooltip = {
    maxWidth = 350,           -- Wider tooltips to show more content
    minWidth = 200,           -- Minimum width for readability
    padding = 12,             -- Comfortable padding around text
    screenMarginRatio = 0.8,  -- Use more screen space for tooltips
    nameLineSpacing = 6,      -- Better spacing after item name
    statLineSpacing = 4,      -- Better spacing between stats
    modifierHeaderSpacing = 6, -- Better space before modifier section
  },
}


-- Dark space-themed turret slot colors (monochrome theme)
Theme.turretSlotColors = {
  {0.7, 0.7, 0.7, 1.00},    -- Slot 1: medium gray (primary)
  {0.8, 0.8, 0.8, 1.00},    -- Slot 2: light gray (highlights)
  {0.6, 0.6, 0.6, 1.00},    -- Slot 3: dark gray (secondary)
  {0.5, 0.5, 0.5, 1.00},    -- Slot 4: darker gray (accents)
}

-- === USAGE EXAMPLES ===
-- Theme.createParticle(x, y, color, velocityX, velocityY, size, lifetime)
-- Example: Theme.createParticle(100, 100, {1, 0.8, 0.2, 1}, 0, -50, 2, 1.0)
--
-- Theme.shakeScreen(intensity, duration)
-- Example: Theme.shakeScreen(5, 0.3) -- Strong shake for 0.3 seconds
--
-- Theme.flashScreen(color, duration)
-- Example: Theme.flashScreen({0.9, 0.7, 0.2, 0.3}, 0.2) -- Gold flash
--
-- Theme.zoomScreen(scale, duration)
-- Example: Theme.zoomScreen(1.1, 0.1) -- Quick zoom in
--
-- Theme.animateValue(start, target, duration, easing, callback)
-- Example: Theme.animateValue(0, 100, 1.0, Theme.easeInOut, function(v) print(v) end)

function Theme.drawSciFiFrame(x, y, w, h)
    local border = Theme.colors.border

    -- Simple border without colored corner details
    Theme.setColor(border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
end

Theme.shaders = {}

function Theme.init()
    -- Frosted glass shader for UI backgrounds
    Theme.shaders.ui_blur = love.graphics.newShader[[
        extern number blur_amount;
        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
            vec4 sum = vec4(0.0);
            float blur = blur_amount / love_ScreenSize.x;
            sum += Texel(tex, vec2(texture_coords.x - 4.0 * blur, texture_coords.y)) * 0.05;
            sum += Texel(tex, vec2(texture_coords.x - 3.0 * blur, texture_coords.y)) * 0.09;
            sum += Texel(tex, vec2(texture_coords.x - 2.0 * blur, texture_coords.y)) * 0.12;
            sum += Texel(tex, vec2(texture_coords.x - 1.0 * blur, texture_coords.y)) * 0.15;
            sum += Texel(tex, vec2(texture_coords.x, texture_coords.y)) * 0.16;
            sum += Texel(tex, vec2(texture_coords.x + 1.0 * blur, texture_coords.y)) * 0.15;
            sum += Texel(tex, vec2(texture_coords.x + 2.0 * blur, texture_coords.y)) * 0.12;
            sum += Texel(tex, vec2(texture_coords.x + 3.0 * blur, texture_coords.y)) * 0.09;
            sum += Texel(tex, vec2(texture_coords.x + 4.0 * blur, texture_coords.y)) * 0.05;
            return sum;
        }
    ]]
    Theme.shaders.ui_blur:send("blur_amount", 2.0)
end

return Theme
