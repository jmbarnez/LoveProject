return {
  id = "starter_frigate_basic",
  name = "Starter Frigate",
  class = "Frigate",

  -- Icon: sleeker frigate silhouette (triangular nose + winglets)
  icon = {
    size = 32,
    shapes = {
      -- Central hull (diamond/arrow)
      { type = "polygon", mode = "fill", color = {0.24,0.26,0.32,1}, points = { 6,16,  14,10,  22,16,  14,22 } },
      -- Nose spear
      { type = "polygon", mode = "fill", color = {0.30,0.32,0.38,1}, points = { 20,16,  26,14,  26,18 } },
      -- Winglets
      { type = "polygon", mode = "fill", color = {0.20,0.22,0.28,1}, points = { 10,12,  6,10,  8,14 } },
      { type = "polygon", mode = "fill", color = {0.20,0.22,0.28,1}, points = { 10,20,  8,18,  6,22 } },
      -- Engine glow dots
      { type = "circle", mode = "fill", color = {0.0,1.0,1.0,0.9}, x = 8, y = 14, r = 1 },
      { type = "circle", mode = "fill", color = {0.2,0.8,1.0,0.9}, x = 8, y = 18, r = 1 },
      -- Outline
      { type = "polygon", mode = "line", color = {0.35,0.75,1.0,0.9}, points = { 6,16,  14,10,  22,16,  14,22 } }
    }
  },

  -- Basic frigate stats
  hull = { hp = 10, shield = 5, cap = 110 },
  -- Slower, more skill-based handling: lower accel/speed, a bit more drag
  engine = { accel = 900, maxSpeed = 450, drag = 0.985, mass = 400 },
  sig = 110,
  cargo = { capacity = 120 },
  targeting = { lockTime = 2.0 },
  description = "A robust starter frigate with a simple square hull design and dual engines.",

  visuals = {
    size = 1.2, -- half previous size for sleeker feel
    hullColor = {0.24, 0.26, 0.32, 1.0},
    panelColor = {0.20, 0.22, 0.28, 1.0},
    accentColor = {0.0, 1.0, 1.0, 0.9},
    engineColor = {0.0, 1.0, 1.0},
    shapes = {
      -- Arrow hull (faces +X): diamond core
      { type = "polygon", mode = "fill", color = {0.24,0.26,0.32,1.0}, points = { -18,0,  6,-12,  24,0,  6,12 } },

      -- Nose spear/panel
      { type = "polygon", mode = "fill", color = {0.30,0.32,0.38,1.0}, points = { 18,0,  30,-4,  30,4 } },

      -- Winglets
      { type = "polygon", mode = "fill", color = {0.20,0.22,0.28,1.0}, points = { 0,-10,  -12,-16,  -6,-6 } },
      { type = "polygon", mode = "fill", color = {0.20,0.22,0.28,1.0}, points = { 0,10,   -6,6,     -12,16 } },

      -- Engine pods (rear, left/right)
      { type = "rectangle", mode = "fill", color = {0.18,0.20,0.26,1.0}, x = -20, y = -6, w = 6, h = 5 },
      { type = "rectangle", mode = "fill", color = {0.18,0.20,0.26,1.0}, x = -20, y = 1,  w = 6, h = 5 },
      -- Warm engine glow (matches warp streak colors)
      { type = "circle", mode = "fill", color = {0.0,1.0,1.0,0.9}, x = -18, y = -4, r = 2 },
      { type = "circle", mode = "fill", color = {0.2,0.8,1.0,0.9}, x = -18, y = 3,  r = 2 },

      -- Cockpit
      { type = "circle", mode = "fill", color = {0.15, 0.95, 0.85, 0.25}, x = 4, y = 0, r = 4 },

      -- Turret hardpoint plate (tracks cursor via renderer turret flag)
      { type = "rectangle", mode = "fill", color = {0.22,0.24,0.30,1.0}, x = 8, y = -3, w = 10, h = 6, turret = true },

      -- Outline of main hull
      { type = "polygon", mode = "line", color = {0.35,0.75,1.0,0.9}, points = { -18,0,  6,-12,  24,0,  6,12 } },
    }
  },

  hardpoints = {
    { turret = "basic_gun" },          -- Slot 1: basic weapon
    { turret = "mining_laser" },       -- Slot 2: starter mining laser
    { turret = "salvaging_laser" },    -- Slot 3: starter salvaging laser
  },

  -- Optional polygon collision shape (more accurate than circle)
  collisionShape = "polygon",
  collisionVertices = { -18,0,  6,-12,  24,0,  6,12 },  -- Arrow hull outline
}
