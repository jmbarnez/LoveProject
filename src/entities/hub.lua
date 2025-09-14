local Util = require("src.core.util")

local Hub = {}
Hub.__index = Hub

function Hub.new(x, y, opts)
  opts = opts or {}
  local self = setmetatable({}, Hub)
  self.x, self.y = x, y
  self.radius = opts.radius or 1200
  self.core = opts.core or 64
  self.regenHP = opts.regenHP or 8      -- hp per second
  self.regenShield = opts.regenShield or 0
  self.regenEnergy = opts.regenEnergy or 0
  -- Station structure parameters
  self.stationLayers = 4  -- concentric layers of station structure
  -- Rotation parameters
  self.rotation = 0
  self.rotationSpeed = 0.3  -- radians per second
  -- Prebaked canvas for static rendering
  self.canvas, self.cw, self.ch = nil, 0, 0
  return self
end

function Hub:contains(px, py)
  return Util.distance(px, py, self.x, self.y) <= self.radius
end

return Hub
