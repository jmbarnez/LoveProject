local Log = require("src.core.log")
local Normalizer = require("src.content.normalizer")

local Validator = {}

local function requireField(tbl, field, ctx)
  if tbl[field] == nil then
    Log.warn("Missing field", field, "in", ctx or "def")
    return false
  end
  return true
end

function Validator.ship(def)
  local n = Normalizer.normalizeShip(def)
  local ok = true
  ok = requireField(n, 'id', 'ship') and ok
  ok = requireField(n, 'hull', 'ship') and ok
  ok = requireField(n.hull, 'hp', 'ship.hull') and ok
  ok = requireField(n, 'engine', 'ship') and ok
  ok = requireField(n.engine, 'mass', 'ship.engine') and ok
  ok = requireField(n, 'visuals', 'ship') and ok
  if n.collidable and n.collidable.radius and n.collidable.radius <= 0 then
    Log.warn('Invalid collidable.radius for ship', n.id)
  end
  return ok
end

function Validator.worldObject(def)
  local n = Normalizer.normalizeWorldObject(def)
  local ok = true
  ok = requireField(n, 'id', 'worldObject') and ok
  ok = requireField(n, 'collidable', 'worldObject') and ok
  ok = requireField(n.collidable, 'radius', 'worldObject.collidable') and ok
  return ok
end

function Validator.projectile(def)
  local n = Normalizer.normalizeProjectile(def)
  local ok = true
  ok = requireField(n, 'id', 'projectile') and ok
  ok = requireField(n, 'physics', 'projectile') and ok
  ok = requireField(n.physics, 'speed', 'projectile.physics') and ok
  return ok
end

function Validator.turret(def)
  if type(def) ~= 'table' then return false end
  if def.id == nil then Log.warn('Missing id in turret def') end
  return true
end

function Validator.item(def)
  if type(def) ~= 'table' then return false end
  if def.id == nil then Log.warn('Missing id in item def') end
  return true
end

return Validator

