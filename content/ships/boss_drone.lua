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
    size = 1.0, -- base size; enemy factory scales by 1.5
    shapes = {
      { type = "circle", mode = "fill", color = {0.35, 0.38, 0.44, 1.0}, x = 0, y = 0, r = 12 },
      { type = "circle", mode = "line", color = {0.18, 0.20, 0.25, 0.95}, x = 0, y = 0, r = 12 },
      { type = "rect", mode = "fill", color = {0.85, 0.45, 0.20, 0.9}, x = 6, y = -2, w = 10, h = 4, rx = 1 },
      { type = "rect", mode = "fill", color = {0.30, 0.32, 0.36, 1.0}, x = -8, y = -14, w = 20, h = 6, rx = 1 },
      { type = "rect", mode = "fill", color = {0.30, 0.32, 0.36, 1.0}, x = -8, y = 8,  w = 20, h = 6, rx = 1 },
      { type = "circle", mode = "fill", color = {1.0, 0.3, 0.15, 0.85}, x = -6, y = -10, r = 2 },
      { type = "circle", mode = "fill", color = {1.0, 0.3, 0.15, 0.85}, x = -6, y = 10,  r = 2 },
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
  }
}
