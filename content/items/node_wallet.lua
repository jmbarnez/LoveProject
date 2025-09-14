return {
  id = "node_wallet",
  name = "Node Wallet",
  type = "consumable",
  rarity = "Uncommon",
  tier = 2,
  stack = 10,
  value = 50,
  price = 100,
  mass = 0.1,
  volume = 0.1,
  tags = { "crypto", "consumable", "node" },
  description = "A secured wallet containing access credentials for 1-3 random network nodes. Use to establish connections.",
  flavor = "Encrypted keys to the digital frontier.",
  consumable = true,
  icon = {
    size = 32,
    shapes = {
      -- Main wallet body
      { type = "rectangle", mode = "fill", color = {0.2, 0.3, 0.4, 1}, x = 6, y = 8, w = 20, h = 16 },
      -- Wallet border
      { type = "rectangle", mode = "line", color = {0.4, 0.6, 0.8, 1}, x = 6, y = 8, w = 20, h = 16, width = 2 },
      -- Digital circuit pattern
      { type = "line", mode = "line", color = {0.0, 0.8, 1.0, 1}, points = {8, 12, 12, 12, 12, 16, 16, 16}, width = 1 },
      { type = "line", mode = "line", color = {0.0, 0.8, 1.0, 1}, points = {20, 12, 24, 12, 24, 20, 20, 20}, width = 1 },
      -- Node connection dots
      { type = "circle", mode = "fill", color = {0.0, 1.0, 0.8, 1}, x = 10, y = 14, r = 1.5 },
      { type = "circle", mode = "fill", color = {0.0, 1.0, 0.8, 1}, x = 16, y = 18, r = 1.5 },
      { type = "circle", mode = "fill", color = {0.0, 1.0, 0.8, 1}, x = 22, y = 14, r = 1.5 },
    }
  },
}