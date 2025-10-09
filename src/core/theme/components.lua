local Components = {}

function Components.setup(Theme)
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
      maxWidth = 350,
      minWidth = 200,
      padding = 12,
      screenMarginRatio = 0.8,
      nameLineSpacing = 6,
      statLineSpacing = 4,
      modifierHeaderSpacing = 6,
    },
  }

  Theme.turretSlotColors = {
    {0.7, 0.7, 0.7, 1.00},    -- Slot 1: medium gray (primary)
    {0.8, 0.8, 0.8, 1.00},    -- Slot 2: light gray (highlights)
    {0.6, 0.6, 0.6, 1.00},    -- Slot 3: dark gray (secondary)
    {0.5, 0.5, 0.5, 1.00},    -- Slot 4: darker gray (accents)
  }
end

return Components
