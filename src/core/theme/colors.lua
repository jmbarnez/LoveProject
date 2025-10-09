local Colors = {
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

return Colors
