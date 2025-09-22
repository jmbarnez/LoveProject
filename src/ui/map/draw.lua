local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Transform = require("src.ui.map.transform")

local Draw = {}

function Draw.getMapBounds()
  local sw, sh = Viewport.getDimensions()
  local margin = 40
  return margin, margin, sw - 2 * margin, sh - 2 * margin
end

return Draw


