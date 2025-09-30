local Log = require("src.core.log")

local Normalizer = {}

local function copy(t)
  local o = {}
  if type(t) ~= 'table' then return o end
  for k, v in pairs(t) do o[k] = v end
  return o
end

local function deepCopy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for k, v in pairs(value) do
    result[k] = deepCopy(v)
  end
  return result
end

-- Ensure visuals table exists with defaults
local function normVisuals(v)
  v = v or {}
  if type(v.size) ~= 'number' then v.size = 1.0 end
  return v
end

function Normalizer.normalizeShip(def)
  if type(def) ~= 'table' then return {} end
  local out = {}
  out.id = def.id
  out.name = def.name or def.id or "Unknown Ship"
  out.class = def.class or "Ship"
  out.description = def.description or def.desc or ""
  out.visuals = normVisuals(deepCopy(def.visuals))
  -- AI configuration passthrough
  if def.ai then
    out.ai = deepCopy(def.ai)
  end

  -- Hull
  out.hull = {
    hp = (def.hull and def.hull.hp) or def.hp or 100,
    shield = (def.hull and def.hull.shield) or def.shield or 0,
    cap = (def.hull and def.hull.cap) or def.cap or 0,
  }
  -- Engine
  out.engine = {
    mass = (def.engine and def.engine.mass) or def.mass or 1000,
    accel = (def.engine and def.engine.accel) or def.accel or 500,
    maxSpeed = (def.engine and def.engine.maxSpeed) or def.maxSpeed or 300,
    drag = (def.engine and def.engine.drag) or def.drag or 0.92,
  }
  -- Signature, cargo
  out.sig = def.sig or (def.collidable and def.collidable.signature) or 100
  out.cargo = def.cargo and deepCopy(def.cargo) or { capacity = 100 }
  out.equipmentSlots = def.equipmentSlots or def.equipment_slots or def.gridSlots
  if type(def.equipmentLayout) == 'table' then
    out.equipmentLayout = {}
    for i, slotDef in ipairs(def.equipmentLayout) do
      out.equipmentLayout[i] = deepCopy(slotDef)
    end
  end
  -- Hardpoints: accept direct hardpoints or simple turrets list
  if type(def.hardpoints) == 'table' then
    out.hardpoints = deepCopy(def.hardpoints)
  elseif type(def.turrets) == 'table' then
    out.hardpoints = {}
    for i, tid in ipairs(def.turrets) do out.hardpoints[i] = { turret = tid } end
  else
    out.hardpoints = {}
  end
  -- Loot settings passthrough
  if def.loot and type(def.loot.drops) == 'table' then
    out.loot = { drops = deepCopy(def.loot.drops) }
  end
  if def.enemy then
    out.enemy = deepCopy(def.enemy)
  end
  if def.variants then
    out.variants = deepCopy(def.variants)
  end
  if def.bounty ~= nil then out.bounty = def.bounty end
  if def.xpReward ~= nil then out.xpReward = def.xpReward end
  if def.energyRegen ~= nil or def.energy_regen ~= nil then
    out.energyRegen = def.energyRegen or def.energy_regen
  end
  if def.isEnemy ~= nil then out.isEnemy = def.isEnemy end
  if def.isBoss ~= nil then out.isBoss = def.isBoss end
  return out
end

function Normalizer.normalizeWorldObject(def)
  if type(def) ~= 'table' then return {} end
  local out = {}
  out.id = def.id
  out.name = def.name or def.id or "Object"
  -- Prefer visuals nested under renderable.props.visuals, fallback to top-level visuals
  local visualsSrc = def.visuals
  if not visualsSrc and def.renderable and def.renderable.props and def.renderable.props.visuals then
    visualsSrc = def.renderable.props.visuals
  end
  local visuals = normVisuals(copy(visualsSrc))
  out.visuals = visuals
  if def.renderable then
    out.renderable = { type = def.renderable.type or def.renderable[1] or "asteroid", props = copy(def.renderable.props or {}) }
    -- Ensure visuals are preserved/normalized on the renderable props
    out.renderable.props.visuals = visuals
  else
    out.renderable = { type = "asteroid", props = { visuals = visuals } }
  end
  local radius = (def.collidable and def.collidable.radius) or def.radius or 20
  out.collidable = { type = (def.collidable and def.collidable.type) or "circle", radius = radius }
  if def.mineable then
    local m = def.mineable
    out.mineable = {
      resources = m.resources or m.amount or 0,
      resourceType = m.resourceType or m.id or "stone",
      mineCycleTime = m.mineCycleTime or 1.0,
      durability = m.durability,
      maxDurability = m.maxDurability,
      extractionCycle = m.extractionCycle,
      activeCyclesPerResource = m.activeCyclesPerResource,
    }
  end

  -- Preserve beacon station repair system properties
  if def.repairable then
    out.repairable = def.repairable
  end
  if def.broken ~= nil then
    out.broken = def.broken
  end
  if def.repair_cost then
    out.repair_cost = copy(def.repair_cost)
  end
  if def.no_spawn_radius then
    out.no_spawn_radius = def.no_spawn_radius
  end

  return out
end

function Normalizer.normalizeProjectile(def)
  if type(def) ~= 'table' then return {} end
  local out = copy(def)
  -- Normalize renderable
  out.renderable = out.renderable or { type = "bullet", props = {} }
  out.renderable.type = out.renderable.type or "bullet"
  out.renderable.props = out.renderable.props or {}
  if def.kind and not out.renderable.props.kind then out.renderable.props.kind = def.kind end
  -- Normalize physics
  -- Increase default bullet speed for snappier feel (2x baseline)
  out.physics = out.physics or { speed = def.speed or 2400 }
  if not out.physics.speed then out.physics.speed = def.speed or 2400 end
  return out
end

function Normalizer.normalizeTurret(def)
  return def or {}
end

function Normalizer.normalizeItem(def)
  return def or {}
end

return Normalizer
