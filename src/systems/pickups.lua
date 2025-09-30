local Pickups = {}
local Events = require("src.core.events")
local Sound = require("src.core.sound")
local Notifications = require("src.ui.notifications")

local ATTRACT_RADIUS = 600  -- Increased from 400 to 600 for better item collection
local CAPTURE_RADIUS = 35  -- Increased to ensure items are collected when they get under the ship
local BASE_PULL = 180

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
  
  -- Show pickup notification
  local itemName = id == "stones" and "Raw Stones" or (id == "ore_tritanium" and "Tritanium Ore" or id)
  local notificationText = qty > 1 and ("+" .. qty .. " " .. itemName) or ("+" .. qty .. " " .. itemName)
  Notifications.action(notificationText)
  
  pickup.dead = true
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

  -- Make player ship magnetic - attract ALL nearby items
  local nearbyItems = {}
  for _, e in ipairs(world:get_entities_with_components("item_pickup", "position")) do
    if not e.dead then
      local ex, ey = e.components.position.x, e.components.position.y
      local d = dist(ex, ey, px, py)
      if d <= ATTRACT_RADIUS then
        table.insert(nearbyItems, {entity = e, distance = d})
      end
    end
  end

  -- Sort by distance (closest first)
  table.sort(nearbyItems, function(a, b) return a.distance < b.distance end)

  -- Process all nearby items
  for _, item in ipairs(nearbyItems) do
    local e = item.entity
    local ex, ey = e.components.position.x, e.components.position.y
    local d, dx, dy = dist(ex, ey, px, py)
    
    if d <= CAPTURE_RADIUS then
      -- Collect the item
      collect(player, e)
    else
      -- Pull the item towards the player
      local dirx, diry = dx / math.max(1e-6, d), dy / math.max(1e-6, d)
      local speed = BASE_PULL * (0.4 + 0.6 * (1 - d / ATTRACT_RADIUS)) -- Stronger pull when closer
      local vel = e.components.velocity
      vel.vx = vel.vx + dirx * speed * dt
      vel.vy = vel.vy + diry * speed * dt
    end
  end

  -- Clear tractor beam (no longer used)
  player.tractorBeam = nil
end

function Pickups.stopTractorBeam(player)
  -- No longer needed - player ship is always magnetic
  if player then
    player.tractorBeam = nil
  end
end

return Pickups
