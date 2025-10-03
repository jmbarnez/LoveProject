return {
  id = "ore_palladium",
  name = "Palladium Ore",
  type = "material",
  rarity = "Rare",
  tier = 2,
  stack = 9999,
  value = 25,
  price = 35, -- Shop price based on market sell price
  mass = 1.8,       -- kg per unit
  volume = 0.5,     -- m^3 per unit
  market = { buy = 20, sell = 30, volatility = 0.12 },
  tags = { "ore", "precious", "catalyst" },
  description = "A rare, silvery-white metal used in advanced electronics and catalytic converters.",
  flavor = "Palladium's catalytic properties make it invaluable for starship systems.",
  icon = {
    size = 32,
    shapes = {
      -- Main rock shape
      { type = "polygon", mode = "fill", color = {0.8, 0.8, 0.9, 1}, points = {6, 16, 10, 8, 22, 6, 28, 14, 24, 26, 12, 28} },
      -- Facets
      { type = "polygon", mode = "fill", color = {0.9, 0.9, 1.0, 1}, points = {10, 8, 16, 10, 22, 6} },
      { type = "polygon", mode = "fill", color = {0.7, 0.7, 0.8, 1}, points = {6, 16, 12, 28, 16, 20} },
      { type = "polygon", mode = "fill", color = {0.75, 0.75, 0.85, 1}, points = {28, 14, 22, 6, 16, 10, 24, 26} },
      -- Shine
      { type = "line", mode = "line", color = {1, 1, 1, 0.8}, points = {12, 10, 18, 8}, width = 1.5 },
    }
  },
}
