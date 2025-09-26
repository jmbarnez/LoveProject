local Pickups = {}
local Events = require("src.core.events")
local Sound = require("src.core.sound")

local ATTRACT_RADIUS = 600
local CAPTURE_RADIUS = 28
local BASE_PULL = 240

local currentTargetId = nil

local function dist(x1,y1,x2,y2)
  local dx,dy = x2-x1,y2-y1
  return math.sqrt(dx*dx+dy*dy), dx, dy
end

local function collect(player, pickup)
  if not pickup or not player then return end
  local cargo = player.components and player.components.cargo
  if not cargo then return end
  local id = pickup.itemId or (pickup.components and pickup.components.renderable and pickup.components.renderable.props and pickup.components.renderable.props.itemId) or "stones"
  local qty = pickup.qty or (pickup.components and pickup.components.renderable and pickup.components.renderable.props and pickup.components.renderable.props.qty) or 1
  cargo:add(id, qty)
  Sound.triggerEventAt("loot_collected", pickup.components.position.x, pickup.components.position.y)
  pickup.dead = true
  currentTargetId = nil
end

function Pickups.update(dt, world, player)
  if not player or not player.components or not player.components.position then return end
  local px, py = player.components.position.x, player.components.position.y

  -- Update all pickups with velocity and drag
  for _, e in ipairs(world:get_entities_with_components("item_pickup", "position", "velocity")) do
    if not e.dead then
      local vel = e.components.velocity
      local pos = e.components.position
      -- Apply velocity
      pos.x = pos.x + vel.vx * dt
      pos.y = pos.y + vel.vy * dt
      -- Light drag
      vel.vx = vel.vx * 0.98
      vel.vy = vel.vy * 0.98
    end
  end

  -- Resolve / keep target
  local target
  for _, e in ipairs(world:get_entities_with_components("item_pickup", "position")) do
    if not e.dead and e.id == currentTargetId then target = e break end
  end
  if not target then
    local bestD = math.huge
    for _, e in ipairs(world:get_entities_with_components("item_pickup", "position")) do
      if not e.dead then
        local ex, ey = e.components.position.x, e.components.position.y
        local d = dist(ex, ey, px, py)
        if d <= ATTRACT_RADIUS and d < bestD then
          bestD = d
          target = e
        end
      end
    end
    currentTargetId = target and target.id or nil
  end

  if target then
    local ex, ey = target.components.position.x, target.components.position.y
    local d, dx, dy = dist(ex, ey, px, py)
    if d <= CAPTURE_RADIUS then
      collect(player, target)
      player.tractorBeam = nil
    else
      local dirx, diry = dx / math.max(1e-6, d), dy / math.max(1e-6, d)
      local speed = BASE_PULL * (0.3 + 0.7 * (d / ATTRACT_RADIUS))
      local vel = target.components.velocity
      vel.vx = vel.vx + dirx * speed * dt
      vel.vy = vel.vy + diry * speed * dt
      player.tractorBeam = {targetX = ex, targetY = ey}
    end
  else
    player.tractorBeam = nil
  end
end

function Pickups.stopTractorBeam(player)
  currentTargetId = nil
  if player then
    player.tractorBeam = nil
  end
end

return Pickups
