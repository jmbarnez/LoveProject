local Collector = {}

-- Configurable parameters (could be moved to Config later)
local ATTRACT_RADIUS = 600
local CAPTURE_RADIUS = 28
local BASE_PULL = 220 -- units/sec pull speed at zero distance

local currentTargetId = nil

local function dist(x1,y1,x2,y2)
  local dx,dy = x2-x1,y2-y1
  return math.sqrt(dx*dx+dy*dy), dx, dy
end

-- Adds items in a loot container to player inventory and empties the container
local function collectContainer(player, container)
  if not container or not container.items then return end
  local Cargo = require("src.core.cargo")
  for _, stack in ipairs(container.items) do
    if stack and stack.id and stack.qty then
      Cargo.add(player, stack.id, stack.qty)
    end
  end
  -- Empty the container; ContainerSystem will clean it up
  container.items = {}
  if container.components and container.components.lootContainer then
    container.components.lootContainer.items = {}
  end
  container.dead = true
end

function Collector.update(dt, world, player)
  if not world or not player or not player.components or not player.components.position then return end
  local px = player.components.position.x
  local py = player.components.position.y

  -- Select target: keep current if valid; otherwise find nearest within radius
  local containers = world:get_entities_with_components("lootContainer", "position")
  local target = nil
  for _, c in ipairs(containers) do
    if not c.dead then
      if currentTargetId and c.id == currentTargetId then
        target = c; break
      end
    end
  end
  if not target then
    local bestD = math.huge
    for _, c in ipairs(containers) do
      if not c.dead then
        local cx = c.components.position.x
        local cy = c.components.position.y
        local d = dist(cx, cy, px, py)
        if d <= ATTRACT_RADIUS and d < bestD then
          bestD = d
          target = c
        end
      end
    end
    currentTargetId = target and target.id or nil
  end

  if target then
    local cx = target.components.position.x
    local cy = target.components.position.y
    local d, dx, dy = dist(cx, cy, px, py)
    if d <= CAPTURE_RADIUS then
      collectContainer(player, target)
      currentTargetId = nil
    else
      local dirx, diry = dx / math.max(1e-6, d), dy / math.max(1e-6, d)
      local speed = BASE_PULL * (0.3 + 0.7 * (d / ATTRACT_RADIUS))
      target.components.position.x = cx + dirx * speed * dt
      target.components.position.y = cy + diry * speed * dt
    end
  end
end

return Collector
