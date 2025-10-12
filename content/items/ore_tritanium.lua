return {
  id = "ore_tritanium",
  name = "Tritanium Ore",
  type = "material",
  rarity = "Common",
  stack = 9999,
  value = 5,        -- GC
  price = 8,        -- GC - Shop price based on market buy price
  mass = 1.2,       -- kg per unit
  volume = 0.5,     -- u³ per unit
  market = { buy = 4, sell = 6, volatility = 0.08 },
  tags = { "ore", "industrial", "hull-alloy" },
  description = "A ubiquitous, resilient ore refined into tritanium alloys for hull plating and bulkheads.",
  flavor = "Unremarkable alone, indispensable in fleets.",
  icon = {
    size = 32,
    shapes = {
      -- Main rock shape
      { type = "polygon", mode = "fill", color = {0.5, 0.55, 0.6, 1}, points = {8, 10, 24, 8, 26, 22, 10, 24} },
      -- Darker facets
      { type = "polygon", mode = "fill", color = {0.4, 0.45, 0.5, 1}, points = {8, 10, 14, 14, 10, 24} },
      { type = "polygon", mode = "fill", color = {0.45, 0.5, 0.55, 1}, points = {24, 8, 18, 16, 26, 22} },
      -- Highlights
      { type = "line", mode = "line", color = {0.6, 0.65, 0.7, 1}, points = {8, 10, 24, 8}, width = 1 },
      { type = "line", mode = "line", color = {0.6, 0.65, 0.7, 1}, points = {10, 24, 26, 22}, width = 1 },
    }
  },
}
