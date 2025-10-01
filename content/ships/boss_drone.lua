-- Boss Drone: heavier drone that sprays 4-shot cone volleys
return {
  id = "boss_drone",
  name = "MILA",
  class = "Drone",
  description = "Heavily armed drone that fires a cone spray.",

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
      turret = {
        id = "boss_prism_laser",
        type = "laser",
        name = "Prism Burst Array",
        description = "Fires sweeping prisms of pink laser energy in a wide arc.",
        price = 0,
        module = { type = "turret" },
        icon = {
          size = 32,
          shapes = {
            { type = "circle", mode = "fill", color = {0.45, 0.08, 0.45, 1.0}, x = 16, y = 16, r = 7 },
            { type = "circle", mode = "fill", color = {0.9, 0.3, 0.8, 0.85}, x = 16, y = 16, r = 4 },
            { type = "polygon", mode = "fill", color = {1.0, 0.4, 0.85, 0.8}, points = { 16,4,  28,12,  16,20,  4,12 } },
            { type = "circle", mode = "line", color = {1.0, 0.65, 0.95, 0.9}, x = 16, y = 16, r = 12, lineWidth = 1.5 },
          }
        },
        spread = { minDeg = 0.0, maxDeg = 0.0, decay = 900 },

        projectile = {
          id = "boss_prism_beam",
          name = "Prism Beam",
          class = "Projectile",
          physics = {
            speed = 0,
            drag = 0,
          },
          renderable = {
            type = "bullet",
            props = {
              kind = "laser",
              length = 1400,
              tracerWidth = 6,
              color = {1.0, 0.45, 0.85, 0.95},
            }
          },
          collidable = {
            radius = 4,
          },
          damage = {
            min = 6,
            max = 9,
          },
          timed_life = {
            duration = 0.18,
          },
          charged_pulse = {
            buildup_time = 0.12,
            flash_time = 0.09,
          }
        },

        tracer = { color = {1.0, 0.45, 0.85, 0.95}, width = 4, coreRadius = 3 },
        impact = {
          shield = { spanDeg = 80, color1 = {0.95, 0.55, 0.95, 0.6}, color2 = {1.0, 0.35, 0.8, 0.45} },
          hull = { spark = {1.0, 0.4, 0.8, 0.7}, ring = {0.9, 0.2, 0.6, 0.5} },
        },
        optimal = 1000, falloff = 500,
        damage_range = { min = 6, max = 9 },
        cycle = 1.6, capCost = 0,
        projectileSpeed = 0,
        maxRange = 1500,
        maxHeat = 110,
        heatPerShot = 18,
        cooldownRate = 28,
        overheatCooldown = 3.0,
        heatCycleMult = 0.75,
        heatEnergyMult = 1.1,
        fireMode = "automatic",
        volleyCount = 4,
        volleySpreadDeg = 18,
      }
    },
    {
      turret = {
        id = "boss_luminary_lance",
        type = "laser",
        name = "Luminary Lance",
        description = "Charges and unleashes a focused pink beam at long range.",
        price = 0,
        module = { type = "turret" },
        icon = {
          size = 32,
          shapes = {
            { type = "rectangle", mode = "fill", color = {0.4, 0.08, 0.42, 1.0}, x = 12, y = 8, w = 8, h = 16, rx = 3 },
            { type = "rectangle", mode = "fill", color = {0.85, 0.28, 0.78, 0.9}, x = 14, y = 6, w = 4, h = 20, rx = 2 },
            { type = "polygon", mode = "fill", color = {1.0, 0.5, 0.9, 0.9}, points = { 16,4,  20,10,  16,6,  12,10 } },
            { type = "circle", mode = "line", color = {1.0, 0.7, 0.95, 0.7}, x = 16, y = 16, r = 10, lineWidth = 1.5 },
          }
        },
        spread = { minDeg = 0.0, maxDeg = 0.0, decay = 1000 },

        projectile = {
          id = "boss_luminary_beam",
          name = "Luminary Beam",
          class = "Projectile",
          physics = {
            speed = 0,
            drag = 0,
          },
          renderable = {
            type = "bullet",
            props = {
              kind = "laser",
              length = 1800,
              tracerWidth = 8,
              color = {1.0, 0.5, 0.9, 0.95},
            }
          },
          collidable = {
            radius = 5,
          },
          damage = {
            min = 1,
            max = 1,
          },
          timed_life = {
            duration = 0.22,
          },
          charged_pulse = {
            buildup_time = 0.2,
            flash_time = 0.12,
          }
        },

        tracer = { color = {1.0, 0.5, 0.9, 1.0}, width = 5, coreRadius = 4 },
        impact = {
          shield = { spanDeg = 110, color1 = {0.9, 0.35, 0.85, 0.7}, color2 = {1.0, 0.6, 0.95, 0.5} },
          hull = { spark = {1.0, 0.45, 0.85, 0.8}, ring = {0.85, 0.25, 0.7, 0.6} },
        },
        optimal = 1400, falloff = 400,
        damage_range = { min = 1, max = 1 },
        cycle = 5.0, capCost = 0,
        projectileSpeed = 0,
        maxRange = 2000,
        maxHeat = 80,
        heatPerShot = 26,
        cooldownRate = 20,
        overheatCooldown = 4.2,
        heatCycleMult = 0.85,
        heatEnergyMult = 1.05,
        fireMode = "automatic",
        volleyCount = 1,
        volleySpreadDeg = 0,
      }
    },
    {
      turret = {
        id = "boss_rocket_launcher",
        type = "missile",
        name = "Heavy Rocket Launcher",
        description = "Fires powerful explosive rockets at long range.",
        price = 0,
        module = { type = "turret" },
        icon = {
          size = 32,
          shapes = {
            { type = "rectangle", mode = "fill", color = {0.3, 0.3, 0.3, 1.0}, x = 8, y = 12, w = 16, h = 8, rx = 2 },
            { type = "rectangle", mode = "fill", color = {0.6, 0.6, 0.6, 0.9}, x = 10, y = 10, w = 12, h = 12, rx = 1 },
            { type = "circle", mode = "fill", color = {1.0, 0.4, 0.2, 0.9}, x = 16, y = 6, r = 3 },
            { type = "polygon", mode = "fill", color = {0.8, 0.8, 0.8, 0.8}, points = { 16,2,  18,6,  16,4,  14,6 } },
          }
        },
        spread = { minDeg = 0.0, maxDeg = 0.0, decay = 800 },

        projectile = {
          id = "boss_heavy_rocket",
          name = "Heavy Rocket",
          class = "Projectile",
          physics = {
            speed = 1200,
            drag = 0.1,
          },
          renderable = {
            type = "bullet",
            props = {
              kind = "missile",
              length = 40,
              tracerWidth = 3,
              color = {1.0, 0.6, 0.2, 1.0},
            }
          },
          collidable = {
            radius = 6,
          },
          damage = {
            min = 15,
            max = 20,
          },
          timed_life = {
            duration = 8.0,
          },
          explosion = {
            radius = 80,
            damage = 12
          }
        },

        tracer = { color = {1.0, 0.6, 0.2, 1.0}, width = 3, coreRadius = 2 },
        impact = {
          shield = { spanDeg = 120, color1 = {1.0, 0.5, 0.3, 0.8}, color2 = {1.0, 0.3, 0.1, 0.6} },
          hull = { spark = {1.0, 0.6, 0.2, 0.9}, ring = {1.0, 0.4, 0.1, 0.7} },
        },
        optimal = 3000, falloff = 1000,
        damage_range = { min = 15, max = 20 },
        cycle = 4.0, capCost = 0,
        projectileSpeed = 1200,
        maxRange = 4000,
        maxHeat = 60,
        heatPerShot = 15,
        cooldownRate = 12,
        overheatCooldown = 2.5,
        heatCycleMult = 0.9,
        heatEnergyMult = 1.0,
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
