local Pickups = {}
local Cargo = require("src.core.cargo")

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
  local id = pickup.itemId or (pickup.components and pickup.components.renderable and pickup.components.renderable.props and pickup.components.renderable.props.itemId) or "stones"
  local qty = pickup.qty or (pickup.components and pickup.components.renderable and pickup.components.renderable.props and pickup.components.renderable.props.qty) or 1
  Cargo.add(player, id, qty)
  pickup.dead = true
  currentTargetId = nil
end

function Pickups.update(dt, world, player)
  if not player or not player.components or not player.components.position then return end
  local px, py = player.components.position.x, player.components.position.y

  -- Resolve / keep target
  local target
  for _, e in ipairs(world:getEntitiesWithComponents("item_pickup", "position")) do
    if not e.dead and e.id == currentTargetId then target = e break end
  end
  if not target then
    local bestD = math.huge
    for _, e in ipairs(world:getEntitiesWithComponents("item_pickup", "position")) do
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
    else
      local dirx, diry = dx / math.max(1e-6, d), dy / math.max(1e-6, d)
      local speed = BASE_PULL * (0.3 + 0.7 * (d / ATTRACT_RADIUS))
      target.components.position.x = ex + dirx * speed * dt
      target.components.position.y = ey + diry * speed * dt
    end
  end
end

return Pickups
