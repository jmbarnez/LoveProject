return {
  id = "starter_frigate_basic",
  name = "Starter Drone",
  class = "Drone",

  -- Icon: hexagonal drone core with symmetrical engine mounts
  icon = {
    size = 32,
    shapes = {
      -- Central hexagonal core (scaled for icon size)
      { type = "polygon", mode = "fill", color = {0.24,0.26,0.32,1}, points = { 16,8,  10,12,  10,20,  16,24,  22,20,  22,12 } },
      -- Engine mounts (scaled)
      { type = "rect", mode = "fill", color = {0.18,0.20,0.26,1}, x = 6, y = 12, w = 2, h = 4 },
      { type = "rect", mode = "fill", color = {0.18,0.20,0.26,1}, x = 24, y = 12, w = 2, h = 4 },
      { type = "rect", mode = "fill", color = {0.18,0.20,0.26,1}, x = 12, y = 6, w = 4, h = 2 },
      { type = "rect", mode = "fill", color = {0.18,0.20,0.26,1}, x = 12, y = 24, w = 4, h = 2 },
      -- Engine glow (scaled)
      { type = "circle", mode = "fill", color = {0.0,1.0,1.0,0.9}, x = 8, y = 16, r = 1 },
      { type = "circle", mode = "fill", color = {0.2,0.8,1.0,0.9}, x = 24, y = 16, r = 1 },
      -- Central sensor
      { type = "circle", mode = "fill", color = {0.15, 0.95, 0.85, 0.25}, x = 16, y = 16, r = 3 },
      -- Small turret on top (scaled for icon)
      { type = "rect", mode = "fill", color = {0.22,0.24,0.30,1.0}, x = 15, y = 8, w = 2, h = 8, turret = true },
      { type = "circle", mode = "fill", color = {0.35,0.75,1.0,0.9}, x = 16, y = 6, r = 2, turret = true },
      -- Outline
      { type = "polygon", mode = "line", color = {0.35,0.75,1.0,0.9}, points = { 16,8,  10,12,  10,20,  16,24,  22,20,  22,12 } }
    }
  },

  -- Basic drone stats
  hull = { hp = 10, shield = 5, cap = 110 },
  -- Slower, more skill-based handling: lower accel/speed, a bit more drag
  engine = { accel = 900, maxSpeed = 450, drag = 0.985, mass = 400 },
  sig = 110,
  cargo = { capacity = 120 },
  equipmentSlots = 3,
  equipmentLayout = {
    { slot = 1, type = "turret", label = "Port Turret" },
    { slot = 2, type = "turret", label = "Starboard Turret" },
    { slot = 3, type = "shield", label = "Shield Generator" },
  },
  targeting = { lockTime = 2.0 },
  description = "A compact starter drone with hexagonal core and symmetrical multi-directional engines.",

  visuals = {
    size = 1.2, -- drone-like proportions
    hullColor = {0.24, 0.26, 0.32, 1.0},
    panelColor = {0.20, 0.22, 0.28, 1.0},
    accentColor = {0.0, 1.0, 1.0, 0.9},
    engineColor = {0.0, 0.0, 1.0},
    shapes = {
      -- Central hexagonal core (drone-like)
      { type = "polygon", mode = "fill", color = {0.24,0.26,0.32,1.0}, points = { 0,-15,  -13,-8,  -13,8,  0,15,  13,8,  13,-8 } },

      -- Symmetrical engine mounts (4 points around center)
      { type = "rectangle", mode = "fill", color = {0.18,0.20,0.26,1.0}, x = -15, y = -4, w = 4, h = 8 },
      { type = "rectangle", mode = "fill", color = {0.18,0.20,0.26,1.0}, x = 11, y = -4, w = 4, h = 8 },
      { type = "rectangle", mode = "fill", color = {0.18,0.20,0.26,1.0}, x = -4, y = -15, w = 8, h = 4 },
      { type = "rectangle", mode = "fill", color = {0.18,0.20,0.26,1.0}, x = -4, y = 11, w = 8, h = 4 },

      -- Engine glow effects (positioned at engine mounts)
      { type = "circle", mode = "fill", color = {0.0,1.0,1.0,0.9}, x = -13, y = 0, r = 2 },
      { type = "circle", mode = "fill", color = {0.2,0.8,1.0,0.9}, x = 13, y = 0, r = 2 },
      { type = "circle", mode = "fill", color = {0.0,1.0,1.0,0.9}, x = 0, y = -13, r = 2 },
      { type = "circle", mode = "fill", color = {0.2,0.8,1.0,0.9}, x = 0, y = 13, r = 2 },

      -- Central sensor array (replaces cockpit)
      { type = "circle", mode = "fill", color = {0.15, 0.95, 0.85, 0.25}, x = 0, y = 0, r = 6 },

      -- Symmetrical sensor nodes
      { type = "circle", mode = "fill", color = {0.25, 0.75, 0.95, 0.4}, x = 0, y = -10, r = 2 },
      { type = "circle", mode = "fill", color = {0.25, 0.75, 0.95, 0.4}, x = 0, y = 10, r = 2 },
      { type = "circle", mode = "fill", color = {0.25, 0.75, 0.95, 0.4}, x = -10, y = 0, r = 2 },
      { type = "circle", mode = "fill", color = {0.25, 0.75, 0.95, 0.4}, x = 10, y = 0, r = 2 },

      -- Small turret on top that rotates to track cursor
      { type = "rectangle", mode = "fill", color = {0.22,0.24,0.30,1.0}, x = -2, y = -20, w = 4, h = 20, turret = true, turretPivot = { x = 0, y = 0 } },
      { type = "circle", mode = "fill", color = {0.35,0.75,1.0,0.9}, x = 0, y = -22, r = 3, turret = true, turretPivot = { x = 0, y = 0 } },

      -- Outer hull outline
      { type = "polygon", mode = "line", color = {0.35,0.75,1.0,0.9}, points = { 0,-15,  -13,-8,  -13,8,  0,15,  13,8,  13,-8 } },
    }
  },

  -- Optional polygon collision shape (more accurate than circle)
  collisionShape = "polygon",
  collisionVertices = { 0,-15,  -13,-8,  -13,8,  0,15,  13,8,  13,-8 },  -- Hexagonal drone outline
}
