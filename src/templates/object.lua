-- Generic world object template (ECS-compatible)
local Position = require("src.components.position")
local Collidable = require("src.components.collidable")
local Health = require("src.components.health")

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
    health = Health.new({ hp = hp, maxHP = maxHP })
  }
  self.dead = false

  -- Back-compat legacy fields (position+radius only)
  self.x, self.y = x, y
  self.radius = r
  return self
end

function Object:hit(dmg)
  local h = self.components and self.components.health
  if h then
    local damage = dmg or 0
    local shieldBefore = h.shield or 0
    local shieldAbsorbed = math.min(shieldBefore, damage)
    h.shield = math.max(0, shieldBefore - shieldAbsorbed)
    local remainingDamage = damage - shieldAbsorbed
    if remainingDamage > 0 then
      h.hp = math.max(0, (h.hp or 0) - remainingDamage)
    end
    if (h.hp or 0) <= 0 then self.dead = true end
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
