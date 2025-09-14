return {
  id = "stones",
  name = "Raw Stones",
  type = "material",
  rarity = "Common",
  tier = 1,
  stack = 9999,
  value = 2,
  price = 3, -- Shop price based on market sell price
  mass = 2.0,       -- kg per unit
  volume = 1.0,     -- m^3 per unit
  market = { buy = 1, sell = 3, volatility = 0.05 },
  tags = { "raw", "mining", "construction" },
  description = "Rough stones extracted from asteroids. Basic construction material.",
  flavor = "Foundation of all great structures.",
  icon = {
    size = 32,
    shapes = {
      -- Main rock shape
      { type = "polygon", mode = "fill", color = {0.5, 0.5, 0.5, 1}, points = {8, 14, 14, 8, 24, 12, 22, 26, 12, 24} },
      -- Shadow
      { type = "polygon", mode = "fill", color = {0.4, 0.4, 0.4, 1}, points = {8, 14, 12, 24, 16, 22} },
      -- Highlight
      { type = "polygon", mode = "fill", color = {0.6, 0.6, 0.6, 1}, points = {14, 8, 24, 12, 20, 10} },
    }
  },
}
