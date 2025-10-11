local Config = {}

function Config.setup(Theme)
  Theme.buttonSizes = {
    tiny = { w = 60, h = 20 },
    small = { w = 80, h = 24 },
    medium = { w = 120, h = 32 },
    large = { w = 200, h = 40 },
    menu = { w = 260, h = 40 },
    square = { w = 32, h = 32 },
  }

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
    flashIntensity = 0.3,
    zoomIntensity = 1.05,
  }

  Theme.explorer = {
    contentBg = Theme.colors.bg0,
  }
end

return Config
