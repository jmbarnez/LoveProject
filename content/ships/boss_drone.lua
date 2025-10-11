-- Boss Drone: heavier drone that sprays 4-shot cone volleys
return {
  id = "boss_drone",
  name = "MILA",
  class = "Drone",
  description = "Heavily armed drone that mixes cone blasts, short-range lasers, and homing rockets.",

  ai = {
    intelligenceLevel = "STANDARD",
    aggressiveType = "hostile",
    detectionRange = 2000,  -- Detection range for boss Mila
  },

  visuals = {
    size = 1.2, -- larger boss drone size
    hullColor = {0.56, 0.16, 0.46, 1.0},
    panelColor = {0.42, 0.12, 0.48, 1.0},
    accentColor = {1.0, 0.45, 0.82, 0.95},
    engineColor = {1.0, 0.35, 0.75},
    shapes = {
      -- Central hexagonal core with magenta plating
      { type = "polygon", mode = "fill", color = {0.56, 0.16, 0.46, 1.0}, points = { 0,-14,  -12,-7,  -12,7,  0,14,  12,7,  12,-7 } },
      { type = "polygon", mode = "fill", color = {0.84, 0.32, 0.72, 0.55}, points = { 0,-10,  -8,-5,  -8,5,  0,10,  8,5,  8,-5 } },

      -- Symmetrical engine mounts (4 points around center, larger)
      { type = "rectangle", mode = "fill", color = {0.42, 0.12, 0.48, 1.0}, x = -14, y = -4, w = 4, h = 8 },
      { type = "rectangle", mode = "fill", color = {0.42, 0.12, 0.48, 1.0}, x = 10, y = -4, w = 4, h = 8 },
      { type = "rectangle", mode = "fill", color = {0.42, 0.12, 0.48, 1.0}, x = -4, y = -14, w = 8, h = 4 },
      { type = "rectangle", mode = "fill", color = {0.42, 0.12, 0.48, 1.0}, x = -4, y = 10, w = 8, h = 4 },
      { type = "rectangle", mode = "fill", color = {0.78, 0.28, 0.68, 0.85}, x = -12, y = -2, w = 3, h = 4 },
      { type = "rectangle", mode = "fill", color = {0.78, 0.28, 0.68, 0.85}, x = 11, y = -2, w = 3, h = 4 },
      { type = "rectangle", mode = "fill", color = {0.78, 0.28, 0.68, 0.85}, x = -2, y = -12, w = 4, h = 3 },
      { type = "rectangle", mode = "fill", color = {0.78, 0.28, 0.68, 0.85}, x = -2, y = 11, w = 4, h = 3 },

      -- Engine glow effects (positioned at engine mounts, more intense)
      { type = "circle", mode = "fill", color = {1.0, 0.45, 0.85, 0.95}, x = -12, y = 0, r = 2.8 },
      { type = "circle", mode = "fill", color = {1.0, 0.45, 0.85, 0.95}, x = 12, y = 0, r = 2.8 },
      { type = "circle", mode = "fill", color = {1.0, 0.35, 0.80, 0.9}, x = 0, y = -12, r = 2.8 },
      { type = "circle", mode = "fill", color = {1.0, 0.35, 0.80, 0.9}, x = 0, y = 12, r = 2.8 },

      -- Central sensor array (larger for boss)
      { type = "circle", mode = "fill", color = {0.96, 0.52, 0.88, 0.55}, x = 0, y = 0, r = 6.5 },
      { type = "circle", mode = "line", color = {1.0, 0.7, 0.95, 0.8}, x = 0, y = 0, r = 8.5, lineWidth = 1.5 },

      -- Symmetrical sensor nodes (larger and more prominent)
      { type = "circle", mode = "fill", color = {0.98, 0.65, 0.92, 0.7}, x = 0, y = -8, r = 2.2 },
      { type = "circle", mode = "fill", color = {0.98, 0.65, 0.92, 0.7}, x = 0, y = 8, r = 2.2 },
      { type = "circle", mode = "fill", color = {0.98, 0.65, 0.92, 0.7}, x = -8, y = 0, r = 2.2 },
      { type = "circle", mode = "fill", color = {0.98, 0.65, 0.92, 0.7}, x = 8, y = 0, r = 2.2 },

      -- Outer hull outline (heavier for boss)
      { type = "polygon", mode = "line", color = {0.32, 0.05, 0.35, 0.95}, points = { 0,-14,  -12,-7,  -12,7,  0,14,  12,7,  12,-7 } },
    }
  },

  engine = {
    mass = 260,
    accel = 380,
    maxSpeed = 260,
  },

  hull = {
    hp = 200,
    shield = 250, -- Increased shield for boss
    cap = 0, -- No energy system for basic enemies
  },

  hardpoints = {
    {
      turret = "railgun_turret",
    },
    {
      turret = "low_power_laser",
    },
    {
      turret = "missile_launcher_mk1",
    }
  },

  xpReward = 100,
  cargo = { capacity = 50, volumeLimit = 25.0 }, -- 25 m^3 cargo hold for boss drone
  equipmentSlots = 2, -- Two shield slots for boss
  equipmentLayout = {
    { slot = 1, type = "shield", label = "Primary Shield Generator" },
    { slot = 2, type = "shield", label = "Backup Shield Generator" },
  },

  collidable = {
    shape = "polygon",
    vertices = {
      0, -14,  -- Top
      -12, -7, -- Top-left
      -12, 7,  -- Bottom-left
      0, 14,   -- Bottom
      12, 7,   -- Bottom-right
      12, -7,  -- Top-right
    }
  },

  enemy = {
    isBoss = true,
    sizeMultiplier = 5.0,
    physicsRadiusMultiplier = 5.0,
    energyRegen = 40,
    turretBehavior = {
      fireMode = "automatic",
      autoFire = true,
    },
  },

  loot = {
    drops = {
      { id = "reward_crate_key", min = 1, max = 1, chance = 1.0 }, -- Guaranteed drop from MILA
      { id = "scraps", min = 3, max = 6, chance = 0.8 },
      { id = "broken_circuitry", min = 2, max = 4, chance = 0.6 },
      { id = "ore_tritanium", min = 2, max = 5, chance = 0.5 },
      { id = "ore_palladium", min = 1, max = 3, chance = 0.3 },
      { id = "railgun_turret", chance = 0.15 },
      { id = "low_power_laser", chance = 0.12 },
      { id = "missile_launcher_mk1", chance = 0.08 },
    }
  },

  -- Mark as enemy for red engine trails
  isEnemy = true
}
