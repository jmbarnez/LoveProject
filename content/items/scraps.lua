return {
  id = "scraps",
  name = "Scraps",
  type = "material",
  rarity = "Common",
  tier = 1,
  stack = 9999,
  value = 5,
  price = 7, -- Shop price based on market sell price
  mass = 0.8,
  volume = 0.5,
  market = { buy = 4, sell = 6, volatility = 0.2 },
  tags = { "material", "salvage", "trade" },
  description = "A collection of salvaged materials, useful for basic crafting and repairs.",
  flavor = "One ship's trash is another's treasure.",
  icon = {
    size = 32,
    shapes = {
      -- Jagged piece 1
      { type = "polygon", mode = "fill", color = {0.6, 0.6, 0.65, 1}, points = {8, 12, 18, 8, 22, 18, 12, 20} },
      -- Jagged piece 2
      { type = "polygon", mode = "fill", color = {0.5, 0.5, 0.55, 1}, points = {14, 16, 26, 14, 24, 26, 18, 28} },
      -- Rust/dirt
      { type = "polygon", mode = "fill", color = {0.7, 0.5, 0.3, 0.6}, points = {18, 8, 20, 12, 22, 18} },
      { type = "circle", mode = "fill", color = {0.7, 0.5, 0.3, 0.6}, x = 16, y = 24, r = 3 },
    }
  },
}
