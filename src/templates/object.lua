-- Generic world object template (ECS-compatible)
local Position = require("src.components.position")
local Collidable = require("src.components.collidable")
local Hull = require("src.components.hull")
local Shield = require("src.components.shield")
local Energy = require("src.components.energy")

local Object = {}
Object.__index = Object

function Object.new(props)
  local self = setmetatable({}, Object)
  local x = props.x or 0
  local y = props.y or 0
  local r = props.radius or 8
  local hp = props.hp or 1
  local maxHP = props.maxHP or hp

  self.components = {
    position = Position.new({ x = x, y = y, angle = 0 }),
    collidable = Collidable.new({ radius = r }),
    hull = Hull.new({ hp = hp, maxHP = maxHP }),
    shield = Shield.new({ shield = 0, maxShield = 0 }),
    energy = Energy.new({ energy = 0, maxEnergy = 0 })
  }
  self.dead = false

  -- Back-compat legacy fields (position+radius only)
  self.x, self.y = x, y
  self.radius = r
  return self
end

function Object:hit(dmg)
  local hull = self.components and self.components.hull
  local shield = self.components and self.components.shield
  if hull then
    local damage = dmg or 0
    local shieldBefore = shield and (shield.shield or 0) or 0
    local shieldAbsorbed = math.min(shieldBefore, damage)
    if shield then
      shield.shield = math.max(0, shieldBefore - shieldAbsorbed)
    end
    local remainingDamage = damage - shieldAbsorbed
    if remainingDamage > 0 then
      hull.hp = math.max(0, (hull.hp or 0) - remainingDamage)
    end
    if (hull.hp or 0) <= 0 then self.dead = true end
  end
end

function Object:update(dt)
  -- no-op by default
end

function Object:draw()
  local x = (self.components and self.components.position and self.components.position.x) or self.x or 0
  local y = (self.components and self.components.position and self.components.position.y) or self.y or 0
  local r = (self.components and self.components.collidable and self.components.collidable.radius) or self.radius or 8
  love.graphics.setColor(0.7, 0.7, 0.9)
  love.graphics.circle("line", x, y, r)
end

return Object
