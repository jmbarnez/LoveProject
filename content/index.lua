-- Central index for content. Extend by adding to sub-indexes.
local ContentIndex = {
  items = require("content.items.index"),
  ships = require("content.ships.index"),
  world_objects = require("content.world_objects.index"),
}

return ContentIndex

