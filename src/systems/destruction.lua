local Effects = require("src.systems.effects")
local Wreckage = require("src.entities.wreckage")
local ItemPickup = require("src.entities.item_pickup")
local Events = require("src.core.events")
local Content = require("src.content.content")
local ProceduralGen = require("src.core.procedural_gen")
local Util = require("src.core.util")

local DestructionSystem = {}

-- Add bounty rewards to uncollected bounties
local function addBountyReward(gameState, enemy, enemyName)
  if not gameState or not gameState.bounty then return end
  
  local bountyValue = enemy.bounty or 0
  local xpValue = enemy.xpReward or 0
  
  if bountyValue > 0 or xpValue > 0 then
    gameState.bounty.uncollected = (gameState.bounty.uncollected or 0) + bountyValue
    
    -- Add entry to recent kills
    if not gameState.bounty.entries then
      gameState.bounty.entries = {}
    end
    
    table.insert(gameState.bounty.entries, {
      name = enemyName or "Unknown Enemy",
      gc = bountyValue,
      timestamp = love.timer.getTime()
    })
    
    -- Keep only last 10 entries
    while #gameState.bounty.entries > 10 do
      table.remove(gameState.bounty.entries, 1)
    end
  end
end

local function rollLoot(drops)
  local items = {}
  if type(drops) ~= 'table' then return items end
  for _, d in ipairs(drops) do
    local chance = d.chance or 1.0
    if math.random() <= chance then
      local baseItem = Content.getTurret(d.id)
      if baseItem then
        for i = 1, (d.count or 1) do
          local turret = ProceduralGen.generateTurretStats(baseItem, 1)
          turret.qty = 1
          table.insert(items, turret)
        end
      else
        local count = d.min or 1
        if d.max and d.max > d.min then
          count = math.random(d.min, d.max)
        end
        table.insert(items, { id = d.id, qty = count })
      end
    end
  end
  return items
end

local function findHubStation(world)
  for _, ent in pairs(world:getEntities()) do
    local r = ent.components and ent.components.renderable
    if r and (r.type == "station" or (r.props and r.props.visuals and ent.radius)) then
      return ent
    end
  end
  return nil
end

local function dropPlayerLoot(world, player, x, y)
  -- Collect inventory items (map id->qty) and equipped turrets into a flat array
  local byId = {}
  if player.inventory then
    for id, qty in pairs(player.inventory) do
      if qty and qty > 0 then byId[id] = (byId[id] or 0) + qty end
    end
  end
  -- Equipped turrets become items as well
  local eq = player.components and player.components.equipment
  if eq and eq.turrets then
    for _, t in ipairs(eq.turrets) do
      if t and t.id then
        byId[t.id] = (byId[t.id] or 0) + 1
      end
    end
  end
  if next(byId) == nil then return end
  local items = {}
  for id, qty in pairs(byId) do table.insert(items, { id = id, qty = qty }) end
  -- Create item pickups for each item
  for _, item in ipairs(items) do
    if item.id and item.qty and item.qty > 0 then
      -- Add some random offset to spread out the items
      local angle = math.random() * math.pi * 2
      local dist = math.random(10, 30)
      local px = x + math.cos(angle) * dist
      local py = y + math.sin(angle) * dist
      
      local pickup = ItemPickup.new(px, py, item.id, item.qty)
      world:addEntity(pickup)
    end
  end
end

function DestructionSystem.update(world, gameState)
  -- Scan for newly dead SHIPS (AI enemies and player only)
  for id, e in pairs(world:getEntities()) do
    if e and e.dead and not e._destructionProcessed and e.components then
      -- Only process ships: enemies (have AI) or the player. Ignore bullets, asteroids, FX, etc.
      local isEnemyShip = (e.components.ai ~= nil)
      local isPlayerShip = (e.isPlayer or e.components.player) ~= nil
      if not (isEnemyShip or isPlayerShip) then
        goto continue
      end
      local pos = e.components.position
      local col = e.components.collidable
      if pos then
        local x, y = pos.x, pos.y
        local shipRadius = (col and col.radius) or 15
        local sizeScale = math.max(0.3, math.min(2.0, shipRadius / 15))

        -- Shared: explosion + wreckage
        Effects.spawnSonicBoom(x, y, { color = {1.0, 0.75, 0.25, 0.5}, sizeScale = sizeScale })
        local visuals = (e.components.renderable and e.components.renderable.props and e.components.renderable.props.visuals) or nil
        
        -- Don't create drops if killed by unfriendly station
        if not e._killedByUnfriendlyStation then
          -- Loot may be defined either in components.lootable (new ECS) or as a legacy
          -- template field `lootTable` on the entity. Handle both cases.
          local dropsSource = nil
          if e.components and e.components.lootable and e.components.lootable.drops then
            dropsSource = e.components.lootable.drops
          elseif e.lootTable then
            dropsSource = e.lootTable
          end
          if dropsSource then
            local items = rollLoot(dropsSource)
            if #items > 0 then
              -- Create item pickups for each item
              for _, item in ipairs(items) do
                if item.id and item.qty and item.qty > 0 then
                  -- Add some random offset to spread out the items
                  local angle = math.random() * math.pi * 2
                  local dist = math.random(10, 30) * sizeScale
                  local px = x + math.cos(angle) * dist
                  local py = y + math.sin(angle) * dist
                  
                  local pickup = ItemPickup.new(px, py, item.id, item.qty)
                  world:addEntity(pickup)
                end
              end
            end
          end

          local pieces = Wreckage.spawnFromEnemy({ x = x, y = y }, visuals, sizeScale)
          if type(pieces) == 'table' then
            for _, piece in ipairs(pieces) do world:addEntity(piece) end
          end
        end

        if isEnemyShip then
          -- Only give rewards if not killed by unfriendly station
          if not e._killedByUnfriendlyStation then
            -- Enemy death: add bounty rewards and use configured loot table
            local enemyName = e.name or "Unknown Enemy"
            addBountyReward(gameState, e, enemyName)
            
            -- Grant XP to the player
            local players = world:getEntitiesWithComponents("player")
            if players and #players > 0 and e.xpReward then
              players[1]:addXP(e.xpReward)
            end
          end

          -- Emit entity destroyed event for quest system and SFX once
          Events.emit(Events.GAME_EVENTS.ENTITY_DESTROYED, {
            entity = e,
            entityId = e.id,
            killedBy = e._killedBy,
            finalDamage = e._finalDamage
          })
          e._destructionProcessed = true
        elseif isPlayerShip then
          -- Prevent multiple death processing
          if e._destructionProcessed then
            e.dead = false -- Reset death flag to prevent getting stuck
            goto skip_entity
          end
          
          -- Player death: respawn at the station
          -- dropPlayerLoot(world, e, x, y)
          -- e.inventory = {}

          -- Find station and respawn near it
          local hub = findHubStation(world)
          local spawn_margin = 48
          local px, py = x, y
          if hub and hub.components and hub.components.position then
            local angle = math.random() * math.pi * 2
            local spawnDist = (hub.radius or ((hub.components.collidable and hub.components.collidable.radius) or 600)) - spawn_margin
            px = hub.components.position.x + math.cos(angle) * spawnDist
            py = hub.components.position.y + math.sin(angle) * spawnDist
          end
          
          -- Restore player state (keep entity alive)
          e.dead = false -- No longer dead
          e.components.position.x = px
          e.components.position.y = py
          if e.components.physics and e.components.physics.body and e.components.physics.body:isDestroyed() == false then
            e.components.physics.body:setLinearVelocity(0, 0)
            e.components.physics.body:setAngularVelocity(0)
          end
          if e.components.health then
            e.components.health.hp = e.components.health.maxHP
            e.components.health.shield = e.components.health.maxShield
          end
          e._destructionProcessed = true
        end
      end
      e._destructionProcessed = true
    end
    ::skip_entity::
    ::continue::
  end
end

return DestructionSystem