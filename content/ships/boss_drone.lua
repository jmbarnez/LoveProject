-- Boss Drone: heavier drone that sprays 4-shot cone volleys
return {
  id = "boss_drone",
  name = "MILA",
  class = "Drone",
  description = "Heavily armed drone that mixes cone blasts, short-range lasers, and homing rockets.",

  ai = {
    intelligenceLevel = "STANDARD",
    aggressiveType = "hostile",
    detectionRange = 4000,  -- Higher detection range for boss Mila
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
    hp = 20,
    shield = 10,
    cap = 0, -- No energy system for basic enemies
  },

  hardpoints = {
    {
      turret = "boss_cone_gun",
    },
    {
      turret = {
        id = "boss_close_laser",
        type = "laser",
        name = "Radiant Cutter",
        description = "Sweeps a piercing beam across nearby targets.",
        price = 0,
        module = { type = "turret" },
        icon = {
          size = 32,
          shapes = {
            { type = "rectangle", mode = "fill", color = {0.36, 0.10, 0.40, 1.0}, x = 10, y = 10, w = 12, h = 14, rx = 2 },
            { type = "polygon", mode = "fill", color = {0.88, 0.32, 0.78, 0.85}, points = { 16,4,  20,12,  16,8,  12,12 } },
            { type = "circle", mode = "fill", color = {1.0, 0.55, 0.95, 0.9}, x = 16, y = 18, r = 5 },
            { type = "circle", mode = "line", color = {1.0, 0.75, 0.98, 0.8}, x = 16, y = 18, r = 8, lineWidth = 1.4 },
          }
        },
        spread = { minDeg = 0.0, maxDeg = 0.0, decay = 900 },

        projectile = {
          id = "boss_close_laser_beam",
          name = "Radiant Cutter Beam",
          class = "Projectile",
          physics = {
            speed = 0,
            drag = 0,
          },
          renderable = {
            type = "bullet",
            props = {
              kind = "laser",
              length = 950,
              tracerWidth = 6,
              color = {1.0, 0.55, 0.95, 0.95},
            }
          },
          collidable = {
            radius = 4,
          },
          damage = {
            min = 4,
            max = 6,
          },
          timed_life = {
            duration = 0.18,
          },
          charged_pulse = {
            buildup_time = 0.1,
            flash_time = 0.08,
          }
        },

        tracer = { color = {1.0, 0.55, 0.95, 0.9}, width = 4, coreRadius = 3 },
        impact = {
          shield = { spanDeg = 85, color1 = {1.0, 0.55, 0.95, 0.6}, color2 = {0.95, 0.35, 0.85, 0.45} },
          hull = { spark = {1.0, 0.45, 0.85, 0.7}, ring = {0.9, 0.25, 0.65, 0.5} },
        },
        optimal = 650,
        falloff = 350,
        damage_range = { min = 4, max = 6 },
        cycle = 1.1,
        capCost = 0,
        projectileSpeed = 0,
        maxRange = 1100,
        maxHeat = 100,
        heatPerShot = 16,
        cooldownRate = 26,
        overheatCooldown = 3.0,
        heatCycleMult = 0.8,
        heatEnergyMult = 1.1,
        fireMode = "automatic",
      }
    },
    {
      turret = {
        id = "boss_homing_rocket_launcher",
        type = "missile",
        name = "Homing Rocket Battery",
        description = "Launches guided rockets that relentlessly track targets.",
        price = 0,
        module = { type = "turret" },
        icon = {
          size = 32,
          shapes = {
            { type = "rectangle", mode = "fill", color = {0.28, 0.26, 0.34, 1.0}, x = 9, y = 12, w = 14, h = 10, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.62, 0.60, 0.70, 0.9}, x = 11, y = 10, w = 10, h = 14, rx = 1 },
            { type = "polygon", mode = "fill", color = {1.0, 0.45, 0.25, 0.95}, points = {16, 4, 20, 12, 16, 9, 12, 12} },
            { type = "circle", mode = "fill", color = {1.0, 0.7, 0.3, 0.9}, x = 16, y = 6, r = 3 },
          }
        },
        spread = { minDeg = 0.0, maxDeg = 0.0, decay = 800 },

        projectile = {
          id = "boss_homing_rocket",
          name = "Homing Rocket",
          class = "Projectile",
          physics = {
            speed = 1100,
            drag = 0.08,
          },
          renderable = {
            type = "bullet",
            props = {
              kind = "missile",
              length = 38,
              tracerWidth = 3,
              color = {1.0, 0.65, 0.25, 1.0},
            }
          },
          collidable = {
            radius = 6,
          },
          damage = {
            min = 12,
            max = 16,
          },
          timed_life = {
            duration = 7.0,
          },
          explosion = {
            radius = 75,
            damage = 10,
          }
        },

        tracer = { color = {1.0, 0.65, 0.25, 1.0}, width = 3, coreRadius = 2 },
        impact = {
          shield = { spanDeg = 120, color1 = {1.0, 0.6, 0.3, 0.8}, color2 = {1.0, 0.35, 0.1, 0.6} },
          hull = { spark = {1.0, 0.55, 0.2, 0.9}, ring = {1.0, 0.4, 0.1, 0.7} },
        },
        optimal = 2800,
        falloff = 900,
        damage_range = { min = 12, max = 16 },
        cycle = 3.5,
        capCost = 0,
        projectileSpeed = 1100,
        maxRange = 3800,
        maxHeat = 70,
        heatPerShot = 14,
        cooldownRate = 14,
        overheatCooldown = 2.5,
        heatCycleMult = 0.9,
        heatEnergyMult = 1.0,
        homingStrength = 0.85,
        missileTurnRate = 4.2,
        fireMode = "automatic",
        volleyCount = 1,
        volleySpreadDeg = 0,
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
      { id = "reward_crate", min = 1, max = 1, chance = 1.0 },
      { id = "ore_tritanium", min = 3, max = 6, chance = 0.9 },
      { id = "basic_gun", chance = 0.6 },
    }
  },

  -- Mark as enemy for red engine trails
  isEnemy = true
}
