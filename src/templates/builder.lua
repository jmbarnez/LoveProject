local ShipTemplate = require("src.templates.ship")
local WorldObjectTemplate = require("src.templates.world_object")
local ProjectileTemplate = require("src.systems.projectile.projectile")
local StationTemplate = require("src.templates.station")

local Builder = {}

function Builder.buildShip(def, x, y, opts)
  if opts then
    for k, v in pairs(opts) do
      def[k] = v
    end
  end
  local angle = (opts and opts.angle) or 0
  local friendly = (opts and opts.friendly) or false
  return ShipTemplate.new(x, y, angle, friendly, def)
end

function Builder.buildWorldObject(def, x, y, opts)
  local angle = (opts and opts.angle) or 0
  local friendly = (opts and opts.friendly) or false
  return WorldObjectTemplate.new(x, y, angle, friendly, def)
end

function Builder.buildProjectile(def, x, y, angle, friendly, opts, world)
  -- Merge runtime options into the base definition to ensure all properties are passed
  if opts then
    for k, v in pairs(opts) do
      if k ~= "definition" then
        def[k] = v
      end
    end
  end
  return ProjectileTemplate.new(x, y, angle, friendly, def, world)
end

function Builder.buildStation(def, x, y, opts)
  return StationTemplate.new(x, y, def)
end

return Builder
