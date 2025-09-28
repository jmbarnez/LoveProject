-- Boss Drone: heavier drone that sprays 4-shot cone volleys
return {
  id = "boss_drone",
  name = "Boss Drone",
  class = "Drone",
  description = "Heavily armed drone that fires a cone spray.",

  ai = {
    intelligenceLevel = "STANDARD",
    aggressiveType = "hostile",
  },

  visuals = {
    size = 1.2, -- larger boss drone size
    hullColor = {0.35, 0.38, 0.44, 1.0},
    panelColor = {0.30, 0.32, 0.36, 1.0},
    accentColor = {0.85, 0.45, 0.20, 0.9},
    engineColor = {1.0, 0.3, 0.15},
    shapes = {
      -- Central hexagonal core (larger for boss)
      { type = "polygon", mode = "fill", color = {0.35, 0.38, 0.44, 1.0}, points = { 0,-14,  -12,-7,  -12,7,  0,14,  12,7,  12,-7 } },

      -- Symmetrical engine mounts (4 points around center, larger)
      { type = "rectangle", mode = "fill", color = {0.30, 0.32, 0.36, 1.0}, x = -14, y = -4, w = 4, h = 8 },
      { type = "rectangle", mode = "fill", color = {0.30, 0.32, 0.36, 1.0}, x = 10, y = -4, w = 4, h = 8 },
      { type = "rectangle", mode = "fill", color = {0.30, 0.32, 0.36, 1.0}, x = -4, y = -14, w = 8, h = 4 },
      { type = "rectangle", mode = "fill", color = {0.30, 0.32, 0.36, 1.0}, x = -4, y = 10, w = 8, h = 4 },

      -- Engine glow effects (positioned at engine mounts, more intense)
      { type = "circle", mode = "fill", color = {0.85, 0.45, 0.20, 0.9}, x = -12, y = 0, r = 2.5 },
      { type = "circle", mode = "fill", color = {1.0, 0.3, 0.15, 0.85}, x = 12, y = 0, r = 2.5 },
      { type = "circle", mode = "fill", color = {0.85, 0.45, 0.20, 0.9}, x = 0, y = -12, r = 2.5 },
      { type = "circle", mode = "fill", color = {1.0, 0.3, 0.15, 0.85}, x = 0, y = 12, r = 2.5 },

      -- Central sensor array (larger for boss)
      { type = "circle", mode = "fill", color = {0.35, 0.65, 0.85, 0.5}, x = 0, y = 0, r = 6 },

      -- Symmetrical sensor nodes (larger and more prominent)
      { type = "circle", mode = "fill", color = {0.45, 0.75, 0.95, 0.6}, x = 0, y = -8, r = 2 },
      { type = "circle", mode = "fill", color = {0.45, 0.75, 0.95, 0.6}, x = 0, y = 8, r = 2 },
      { type = "circle", mode = "fill", color = {0.45, 0.75, 0.95, 0.6}, x = -8, y = 0, r = 2 },
      { type = "circle", mode = "fill", color = {0.45, 0.75, 0.95, 0.6}, x = 8, y = 0, r = 2 },

      -- Outer hull outline (heavier for boss)
      { type = "polygon", mode = "line", color = {0.18, 0.20, 0.25, 0.95}, points = { 0,-14,  -12,-7,  -12,7,  0,14,  12,7,  12,-7 } },
    }
  },

  engine = {
    mass = 260,
    accel = 380,
    maxSpeed = 260,
  },

  hull = {
    hp = 10,
    shield = 10,
    cap = 180,
  },

  hardpoints = {
    { turret = "boss_cone_gun" }
  },

  bounty = 60,
  xpReward = 100,

  loot = {
    drops = {
      { id = "ore_tritanium", min = 3, max = 6, chance = 0.9 },
      { id = "basic_gun", chance = 0.6 },
    }
  },

  -- Mark as enemy for red engine trails
  isEnemy = true
}
