local Pickups = {}
local Sound = require("src.core.sound")
local Notifications = require("src.ui.notifications")
local Content = require("src.content.content")
local Effects = require("src.systems.effects")

local ATTRACT_RADIUS = 800  -- Increased from 600 to 800 for better item collection
local CAPTURE_RADIUS = 40  -- Increased to ensure items are collected when they get under the ship
local BASE_PULL = 540  -- Increased by 3x from 180 to 540

local function formatAmount(value)
  if math.abs(value - math.floor(value + 0.5)) < 0.05 then
    return tostring(math.floor(value + 0.5))
  end
  return string.format("%.1f", value)
end

local function gatherPickups(world, ...)
  local results = {}
  local sources = {
    world:get_entities_with_components("item_pickup", ...),
    world:get_entities_with_components("xp_pickup", ...)
  }

  for _, list in ipairs(sources) do
    if list then
      for _, entity in ipairs(list) do
        table.insert(results, entity)
      end
    end
  end

  return results
end

local function dist(x1,y1,x2,y2)
  local dx,dy = x2-x1,y2-y1
  return math.sqrt(dx*dx+dy*dy), dx, dy
end

local function collect(player, pickup)
  if not pickup or not player then return end

  local position = pickup.components and pickup.components.position
  local xpComponent = pickup.components and pickup.components.xp_pickup
  if xpComponent and player.addXP then
    local amount = xpComponent.amount or pickup.amount or 0
    if amount > 0 then
      player:addXP(amount)
      Sound.triggerEventAt("xp_collected", position and position.x, position and position.y)
      pickup.dead = true
      return { type = "xp", amount = amount }
    end
    pickup.dead = true
    return nil
  end

  local cargo = player.components and player.components.cargo
  if not cargo then return end

  local id = pickup.itemId or (pickup.components and pickup.components.renderable and pickup.components.renderable.props and pickup.components.renderable.props.itemId) or "ore_tritanium"
  local qty = pickup.qty or (pickup.components and pickup.components.renderable and pickup.components.renderable.props and pickup.components.renderable.props.qty) or 1
  cargo:add(id, qty)
  Sound.triggerEventAt("loot_collected", position and position.x or pickup.components.position.x, position and position.y or pickup.components.position.y)

  -- Use Content system for proper item name resolution
  local itemDef = Content.getItem(id)
  local itemName = (itemDef and itemDef.name) or id

  pickup.dead = true
  return { type = "item", id = id, name = itemName, qty = qty }
end

function Pickups.collectPickup(player, pickup)
  return collect(player, pickup)
end

local function resolveItemName(result)
  if not result or result.type ~= "item" then return nil end
  local name = result.name
  if not name or name == result.id then
    local def = Content.getItem(result.id)
    if def and def.name then
      name = def.name
    else
      -- Fallback to turret lookup for turret items
      local turretDef = Content.getTurret(result.id)
      if turretDef and turretDef.name then
        name = turretDef.name
      end
    end
  end
  return name or result.id
end

function Pickups.notifySingleResult(result)
  if not result then return end

  if result.type == "xp" then
    local amount = result.amount or 0
    if amount > 0 then
      Notifications.action("+" .. formatAmount(amount) .. " XP")
    end
    return
  end

  if result.type == "item" then
    local qty = result.qty or 0
    if qty <= 0 then return end
    local label = resolveItemName(result)
    Notifications.loot({ { label = label or "Item", quantity = qty } })
  end
end

local function extractItemId(entity)
  if not entity then return nil end
  if entity.itemId then return entity.itemId end
  if entity.components then
    if entity.components.item_pickup and entity.components.item_pickup.itemId then
      return entity.components.item_pickup.itemId
    end
    if entity.components.renderable and entity.components.renderable.props and entity.components.renderable.props.itemId then
      return entity.components.renderable.props.itemId
    end
  end
  return nil
end

function Pickups.findNearestPickup(world, player, itemId, maxDistance)
  if not world or not player or not player.components or not player.components.position then
    return nil, nil
  end

  local px = player.components.position.x
  local py = player.components.position.y
  local limit = maxDistance or math.huge

  local bestEntity
  local bestDist = math.huge
  local candidates = world.get_entities_with_components and world:get_entities_with_components("item_pickup", "position") or {}

  for _, entity in ipairs(candidates) do
    if entity and not entity.dead and entity.components and entity.components.position then
      local id = extractItemId(entity)
      if not itemId or id == itemId then
        local ex = entity.components.position.x
        local ey = entity.components.position.y
        local dx = ex - px
        local dy = ey - py
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist <= limit and dist < bestDist then
          bestDist = dist
          bestEntity = entity
        end
      end
    end
  end

  if bestEntity then
    return bestEntity, bestDist
  end

  return nil, nil
end

function Pickups.update(dt, world, player)
  if not player or not player.components or not player.components.position then return end
  local px, py = player.components.position.x, player.components.position.y
  local collectedItems = {}
  local totalXP = 0

  -- Update all pickups with velocity and drag
  for _, e in ipairs(gatherPickups(world, "position", "velocity")) do
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
  for _, e in ipairs(gatherPickups(world, "position")) do
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
      local result = collect(player, e)
      if result then
        if result.type == "xp" then
          totalXP = totalXP + result.amount
        elseif result.type == "item" then
          local key = result.id or result.name
          collectedItems[key] = collectedItems[key] or { name = result.name, qty = 0 }
          collectedItems[key].qty = collectedItems[key].qty + (result.qty or 0)
        end
      end
    else
      -- Pull the item towards the player with improved falloff
      local dirx, diry = dx / math.max(1e-6, d), dy / math.max(1e-6, d)
      
      -- Calculate distance-based falloff with smooth curve
      local distanceRatio = d / ATTRACT_RADIUS
      local falloffCurve = math.pow(1 - distanceRatio, 2) -- Quadratic falloff for smoother transition
      local minPull = 0.1 -- Minimum pull strength at max distance
      local maxPull = 1.0 -- Maximum pull strength at close distance
      
      -- Apply falloff curve with minimum threshold
      local pullStrength = math.max(minPull, maxPull * falloffCurve)
      local speed = BASE_PULL * pullStrength
      
      local vel = e.components.velocity
      vel.vx = vel.vx + dirx * speed * dt
      vel.vy = vel.vy + diry * speed * dt
      
      -- Add visual feedback for magnetic pull (occasional particles)
      if math.random() < 0.02 * pullStrength then -- More particles when pull is stronger
        local midX = (ex + px) * 0.5
        local midY = (ey + py) * 0.5
        Effects.add({
          type = 'spark',
          x = midX,
          y = midY,
          vx = dirx * 20,
          vy = diry * 20,
          t = 0,
          life = 0.3,
          color = {0.3, 0.7, 1.0, 0.6}, -- Blue magnetic effect
          size = 1
        })
      end
    end
  end

  -- Clear tractor beam (no longer used)
  player.tractorBeam = nil

  if totalXP > 0 then
    Notifications.action("+" .. formatAmount(totalXP) .. " XP")
  end

  local lootList = {}
  for _, data in pairs(collectedItems) do
    table.insert(lootList, { label = data.name, quantity = data.qty })
  end

  if #lootList > 0 then
    table.sort(lootList, function(a, b) return (a.label or "") < (b.label or "") end)
    Notifications.loot(lootList)
  end
end

function Pickups.stopTractorBeam(player)
  -- No longer needed - player ship is always magnetic
  if player then
    player.tractorBeam = nil
  end
end

return Pickups
