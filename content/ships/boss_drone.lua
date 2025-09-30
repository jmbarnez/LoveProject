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
    cap = 0, -- No energy system for basic enemies
  },

  hardpoints = {
    { 
      turret = {
        id = "all_direction_gun",
        type = "gun",
        name = "All-Direction Gun",
        description = "Fires projectiles in all directions simultaneously.",
        price = 0,
        module = { type = "turret" },
        icon = {
          size = 32,
          shapes = {
            -- Central core
            { type = "circle", mode = "fill", color = {0.15, 0.15, 0.20, 1}, x = 16, y = 16, r = 8 },
            -- 8 directional barrels
            { type = "rectangle", mode = "fill", color = {0.25, 0.25, 0.30, 1}, x = 14, y = 2, w = 4, h = 8, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.25, 0.25, 0.30, 1}, x = 20, y = 2, w = 4, h = 8, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.25, 0.25, 0.30, 1}, x = 2, y = 14, w = 8, h = 4, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.25, 0.25, 0.30, 1}, x = 22, y = 14, w = 8, h = 4, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.25, 0.25, 0.30, 1}, x = 14, y = 22, w = 4, h = 8, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.25, 0.25, 0.30, 1}, x = 20, y = 22, w = 4, h = 8, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.25, 0.25, 0.30, 1}, x = 2, y = 20, w = 8, h = 4, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.25, 0.25, 0.30, 1}, x = 22, y = 20, w = 8, h = 4, rx = 2 },
            -- Central glow
            { type = "circle", mode = "fill", color = {0.8, 0.4, 0.2, 0.8}, x = 16, y = 16, r = 4 },
          }
        },
        spread = { minDeg = 0.0, maxDeg = 0.0, decay = 800 },
        
        -- Embedded projectile definition
        projectile = {
          id = "all_direction_bullet",
          name = "All-Direction Bullet",
          class = "Projectile",
          physics = {
            speed = 3600,
            drag = 0,
          },
          renderable = {
            type = "bullet",
            props = {
              kind = "bullet",
              radius = 2.5,
              color = {1.0, 0.2, 0.1, 1.0}, -- Red projectiles
            }
          },
          damage = {
            value = 2.0,
          },
          timed_life = {
            duration = 2.0,
          }
        },
        
        -- Visual effects
        tracer = { color = {1.0, 0.2, 0.1, 1.0}, width = 1.5, coreRadius = 2 }, -- Red tracer
        impact = {
          shield = { spanDeg = 80, color1 = {0.8, 0.4, 0.2, 0.6}, color2 = {1.0, 0.6, 0.3, 0.4} },
          hull = { spark = {1.0, 0.5, 0.1, 0.7}, ring = {1.0, 0.3, 0.0, 0.5} },
        },
        optimal = 600, falloff = 400,
        damage_range = { min = 1.5, max = 2.5 },
        cycle = 2.0, capCost = 0, -- No energy cost for basic enemies
        projectileSpeed = 3600,
        maxRange = 1500,
        -- Overheating parameters
        maxHeat = 80,
        heatPerShot = 12,
        cooldownRate = 20,
        overheatCooldown = 3.0,
        heatCycleMult = 0.8,
        heatEnergyMult = 1.2,

        -- Firing mode: "manual" or "automatic"
        fireMode = "automatic",
        
        -- All-direction firing: 8 projectiles in all directions
        volleyCount = 8,
        volleySpreadDeg = 45, -- 360/8 = 45 degrees between each shot
      }
    },
    { 
      turret = {
        id = "boss_missile_launcher",
        type = "missile",
        name = "Boss Missile Launcher",
        description = "Fires homing missiles at the player every 6 seconds.",
        price = 0,
        module = { type = "turret" },
        icon = {
          size = 32,
          shapes = {
            -- Missile launcher base
            { type = "rectangle", mode = "fill", color = {0.20, 0.20, 0.25, 1}, x = 8, y = 12, w = 16, h = 8, rx = 2 },
            -- Missile tubes
            { type = "rectangle", mode = "fill", color = {0.30, 0.30, 0.35, 1}, x = 10, y = 14, w = 3, h = 4, rx = 1 },
            { type = "rectangle", mode = "fill", color = {0.30, 0.30, 0.35, 1}, x = 19, y = 14, w = 3, h = 4, rx = 1 },
            -- Missile tips
            { type = "polygon", mode = "fill", color = {0.8, 0.2, 0.1, 1}, points = {11.5, 10, 13.5, 10, 12.5, 14} },
            { type = "polygon", mode = "fill", color = {0.8, 0.2, 0.1, 1}, points = {20.5, 10, 22.5, 10, 21.5, 14} },
            -- Targeting reticle
            { type = "circle", mode = "line", color = {0.8, 0.4, 0.2, 0.8}, x = 16, y = 16, r = 6, lineWidth = 1 },
            { type = "circle", mode = "line", color = {0.8, 0.4, 0.2, 0.6}, x = 16, y = 16, r = 3, lineWidth = 1 },
          }
        },
        spread = { minDeg = 0.0, maxDeg = 0.0, decay = 1000 },
        
        -- Embedded projectile definition
        projectile = {
          id = "boss_missile",
          name = "Boss Missile",
          class = "Projectile",
          physics = {
            speed = 1200,
            drag = 0.1,
          },
          renderable = {
            type = "bullet",
            props = {
              kind = "missile",
              radius = 3.0,
              color = {1.0, 0.1, 0.1, 1.0}, -- Bright red missile
            }
          },
          damage = {
            value = 8.0,
          },
          timed_life = {
            duration = 8.0,
          }
        },
        
        -- Visual effects
        tracer = { color = {1.0, 0.1, 0.1, 1.0}, width = 2, coreRadius = 3 }, -- Bright red trail
        impact = {
          shield = { spanDeg = 90, color1 = {0.8, 0.2, 0.1, 0.7}, color2 = {1.0, 0.4, 0.2, 0.5} },
          hull = { spark = {1.0, 0.6, 0.2, 0.8}, ring = {1.0, 0.3, 0.0, 0.6} },
        },
        optimal = 1000, falloff = 500,
        damage_range = { min = 6, max = 10 },
        cycle = 6.0, capCost = 0, -- No energy cost for basic enemies
        projectileSpeed = 1200,
        maxRange = 2000,
        -- Missile-specific parameters
        homingStrength = 0.9,
        missileTurnRate = 3.0,
        lockOnTime = 1.0,
        -- Overheating parameters
        maxHeat = 60,
        heatPerShot = 20,
        cooldownRate = 15,
        overheatCooldown = 4.0,
        heatCycleMult = 0.9,
        heatEnergyMult = 1.1,

        -- Firing mode: "manual" or "automatic"
        fireMode = "automatic",
      }
    }
  },

  bounty = 60,
  xpReward = 100,

  enemy = {
    isBoss = true,
    sizeMultiplier = 5.0,
    collidableRadiusMultiplier = 5.0,
    physicsRadiusMultiplier = 5.0,
    energyRegen = 40,
    turretBehavior = {
      fireMode = "automatic",
      autoFire = true,
    },
  },

  loot = {
    drops = {
      { id = "ore_tritanium", min = 3, max = 6, chance = 0.9 },
      { id = "basic_gun", chance = 0.6 },
    }
  },

  -- Mark as enemy for red engine trails
  isEnemy = true
}
