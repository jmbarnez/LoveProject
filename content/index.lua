-- Central index for content. Extend by adding to sub-indexes.
local ContentIndex = {
  items = require("content.items.index"),
  ships = require("content.ships.index"),
}

return ContentIndex

