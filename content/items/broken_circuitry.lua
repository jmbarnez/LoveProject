return {
  id = "broken_circuitry",
  name = "Broken Circuitry",
  type = "material",
  rarity = "Common",
  stack = 9999,
  value = 8,        -- GC
  price = 12,       -- GC - Shop price based on market sell price
  mass = 0.3,       -- kg
  volume = 0.2,     -- u³
  market = { buy = 8, sell = 10, volatility = 0.15 },
  tags = { "material", "salvage", "electronic", "trade" },
  description = "Damaged electronic components salvaged from destroyed ships. Still useful for basic repairs and crafting.",
  flavor = "Even broken circuits can be repurposed.",
  icon = {
    size = 32,
    shapes = {
      -- Circuit board base
      { type = "rectangle", mode = "fill", color = {0.1, 0.1, 0.15, 1}, x = 4, y = 4, w = 24, h = 24, rx = 2 },
      -- Circuit traces (broken)
      { type = "rectangle", mode = "fill", color = {0.2, 0.8, 0.2, 0.8}, x = 6, y = 8, w = 8, h = 1 },
      { type = "rectangle", mode = "fill", color = {0.2, 0.8, 0.2, 0.8}, x = 16, y = 12, w = 6, h = 1 },
      { type = "rectangle", mode = "fill", color = {0.2, 0.8, 0.2, 0.8}, x = 8, y = 16, w = 4, h = 1 },
      { type = "rectangle", mode = "fill", color = {0.2, 0.8, 0.2, 0.8}, x = 18, y = 20, w = 6, h = 1 },
      -- Broken traces (red)
      { type = "rectangle", mode = "fill", color = {0.8, 0.2, 0.2, 0.8}, x = 14, y = 8, w = 2, h = 1 },
      { type = "rectangle", mode = "fill", color = {0.8, 0.2, 0.2, 0.8}, x = 12, y = 16, w = 3, h = 1 },
      -- Circuit components
      { type = "circle", mode = "fill", color = {0.3, 0.3, 0.4, 1}, x = 10, y = 10, r = 1.5 },
      { type = "circle", mode = "fill", color = {0.3, 0.3, 0.4, 1}, x = 20, y = 14, r = 1.5 },
      { type = "circle", mode = "fill", color = {0.3, 0.3, 0.4, 1}, x = 12, y = 22, r = 1.5 },
      -- Cracks
      { type = "line", mode = "line", color = {0.4, 0.4, 0.4, 0.8}, x1 = 8, y1 = 6, x2 = 24, y2 = 18, width = 1 },
    }
  },
}
