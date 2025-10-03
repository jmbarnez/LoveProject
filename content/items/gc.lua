return {
  id = "gc",
  name = "Galactic Credits",
  type = "currency",
  rarity = "Common",
  tier = 1,
  stack = 999999,
  value = 1,
  price = 1,
  mass = 0.0,
  volume = 0.0,
  tags = { "currency", "credits", "money" },
  description = "The standard currency used throughout the galaxy for trade and commerce.",
  flavor = "Trusted by traders across the stars.",
  icon = {
    size = 32,
    shapes = {
      -- Main coin body
      { type = "circle", mode = "fill", color = {0.6, 0.7, 1.0, 1.0}, x = 16, y = 16, r = 12 },
      -- Inner circle
      { type = "circle", mode = "fill", color = {0.8, 0.9, 1.0, 1.0}, x = 16, y = 16, r = 8 },
      -- Border
      { type = "circle", mode = "line", color = {0.4, 0.5, 0.8, 1.0}, x = 16, y = 16, r = 12, width = 2 },
      -- "C" for Credits
      { type = "text", mode = "fill", color = {0.2, 0.3, 0.6, 1.0}, x = 16, y = 16, text = "C", size = 16, align = "center" },
      -- Shine effect
      { type = "circle", mode = "fill", color = {1.0, 1.0, 1.0, 0.6}, x = 12, y = 12, r = 3 },
    }
  },
}
