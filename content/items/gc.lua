return {
  id = "gc",
  name = "Galactic Credits",
  type = "currency",
  rarity = "Common",
  stack = 999999,
  value = 1,
  mass = 0.0,
  volume = 0.0,
  tags = { "currency", "credits", "money" },
  description = "The standard currency used throughout the galaxy for trade and commerce.",
  flavor = "Trusted by traders across the stars.",
  icon = {
    size = 32,
    shapes = {
      -- Main coin body (matches drawDesignToken exactly)
      { type = "circle", mode = "fill", color = {0.6, 0.7, 1.0, 1.0}, x = 16, y = 16, r = 12 },
      -- Border (matches drawDesignToken exactly)
      { type = "circle", mode = "line", color = {0.7, 0.7, 0.7, 0.8}, x = 16, y = 16, r = 12, width = 1 },
      -- "C" for Credits (matches drawDesignToken exactly - dark background color)
      { type = "text", mode = "fill", color = {0.0, 0.0, 0.0, 1.0}, x = 16, y = 16, text = "C", size = 16, align = "center" },
    }
  },
}
