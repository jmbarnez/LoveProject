local Effects = require("src.systems.effects")
local Wreckage = require("src.entities.wreckage")
local ItemPickup = require("src.entities.item_pickup")
local Events = require("src.core.events")
local Content = require("src.content.content")
local ProceduralGen = require("src.core.procedural_gen")
local Util = require("src.core.util")
local Skills = require("src.core.skills")
local TurretScaling = require("src.systems.turret.scaling")

local DestructionSystem = {}

local Log = require("src.core.log")
local Debug = require("src.core.debug")

local function rollLoot(drops, enemyLevel)
  local items = {}
  if type(drops) ~= 'table' then return items end
  for _, d in ipairs(drops) do
    local chance = d.chance or 1.0
    if math.random() <= chance then
      local baseItem = Content.getTurret(d.id)
      if baseItem then
        for i = 1, (d.count or 1) do
          -- Use new scaling system for enemy-dropped turrets
          local turret = TurretScaling.generateLeveledTurret(baseItem, enemyLevel or 1)
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
  
  -- First try to find by renderable type
  for _, ent in pairs(world:getEntities()) do
    local r = ent.components and ent.components.renderable
    if r then
      if r.type == "station" then
        return ent
      end
    end
  end
  
  -- Fallback: look for entities with station-like properties
  for _, ent in pairs(world:getEntities()) do
    if ent.components and ent.components.position and ent.components.renderable then
      local r = ent.components.renderable
      if r.props and r.props.visuals and ent.radius then
        return ent
      end
    end
  end
  
  Debug.warn("destruction", "No hub station found in world")
  return nil
end

local function restorePlayerPhysicsTuning(player, body)
  if not body or not player then
    return
  end

  local engine = player.ship and player.ship.engine
  if engine then
    local mass = engine.mass or body.mass
    if mass then
      body.mass = mass
    end

    local accelMultiplier = (engine.accel or 500) / 500
    local baseThrust = (mass or 500) * 50
    body.thrusterPower = body.thrusterPower or {}
    body.thrusterPower.main = baseThrust * accelMultiplier * 1.2
    body.thrusterPower.lateral = baseThrust * accelMultiplier * 0.4
    body.thrusterPower.rotational = baseThrust * accelMultiplier * 0.3

    body.maxSpeed = engine.maxSpeed or body.maxSpeed
    body.dragCoefficient = engine.dragCoefficient or 1.0
  end

  local collidable = player.components and player.components.collidable
  if collidable and collidable.radius then
    body.radius = collidable.radius
  end
end

local function dropPlayerLoot(world, player, x, y)
  local cargo = player.components and player.components.cargo
  if not cargo then return end
  local byId = {}
  cargo:iterate(function(slot, entry)
    if entry.meta then
      -- drop each modded stack individually
      byId[slot] = { id = entry.id, qty = entry.qty, meta = entry.meta }
    else
      byId[entry.id] = (byId[entry.id] or 0) + (entry.qty or 0)
    end
  end)
  local items = {}
  for key, value in pairs(byId) do
    if type(value) == "table" and value.meta then
      table.insert(items, { id = value.id, qty = value.qty, meta = value.meta })
    else
      table.insert(items, { id = key, qty = value })
    end
  end
  for _, item in ipairs(items) do
    if item.id and item.qty and item.qty > 0 then
      local angle = math.random() * math.pi * 2
      local dist = math.random(10, 30)
      local px = x + math.cos(angle) * dist
      local py = y + math.sin(angle) * dist
      local pickup = ItemPickup.new(px, py, item.id, item.qty)
      world:addEntity(pickup)
    end
  end
end

function DestructionSystem.update(world, gameState, hub)
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

        -- Shared: explosion + wreckage (simple sonic boom for ship destruction)
        Effects.spawnSonicBoom(x, y, {
          color = {1.0, 0.6, 0.2, 0.7},  -- Orange/red for ship destruction
          sizeScale = sizeScale,         -- Standard size
          rStart = 10 * sizeScale,       -- Standard start size
          rSpan = 80 * sizeScale,        -- Standard ring width
          life = 0.8,                    -- Standard lifetime
        })
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
            -- Get enemy level for turret scaling
            local enemyLevel = 1
            if e.components and e.components.enemy_level then
              enemyLevel = e.components.enemy_level.level or 1
            end
            
            local items = rollLoot(dropsSource, enemyLevel)
            
            -- Store equipped turrets in wreckage for potential salvaging
            -- (No longer drop turrets directly as loot)
            
            if #items > 0 then
              -- Create item pickups for each item
              for _, item in ipairs(items) do
                if item.id and item.qty and item.qty > 0 then
                  -- Spawn at center with outward velocity for explosion spread
                  local angle = math.random() * math.pi * 2
                  local speed = (50 + math.random() * 50) * sizeScale  -- Lower speed than wreckage, not too far
                  local vx = math.cos(angle) * speed
                  local vy = math.sin(angle) * speed
                  
                  local pickup = ItemPickup.new(x, y, item.id, item.qty, 0.8, vx, vy, item.meta)
                  world:addEntity(pickup)
                end
              end
            end
          end

          -- Only spawn wreckage for enemies, not players
          if isEnemyShip then
            -- Collect equipped turrets for potential salvaging
            local equippedTurrets = {}
            if e.components and e.components.equipment and e.components.equipment.grid then
              local equipment = e.components.equipment
              for _, slot in ipairs(equipment.grid) do
                if slot.type == "turret" and slot.module and slot.module.templateId then
                  table.insert(equippedTurrets, {
                    id = slot.module.templateId,
                    qty = 1,
                    meta = slot.module -- Include the full turret module data with modifiers
                  })
                end
              end
            end
            
            local pieces = Wreckage.spawnFromEnemy({ x = x, y = y }, visuals, sizeScale, equippedTurrets)
            if type(pieces) == 'table' then
              for _, piece in ipairs(pieces) do world:addEntity(piece) end
            end
          end
        end

        if isEnemyShip then
          -- Only give rewards if not killed by unfriendly station
          if not e._killedByUnfriendlyStation then
            -- Enemy death: grant XP to the player and use configured loot table
            -- Grant XP to the player
            local players = world:get_entities_with_components("player")
            if players and #players > 0 and e.xpReward then
              players[1]:addXP(e.xpReward)
            end
            
            -- Boss reward key is now handled by loot table

            -- Grant relevant weapon skill XP if the player landed the killing blow
            local killer = e._killedBy
            if killer and (killer.isPlayer or (killer.components and killer.components.player)) then
              local finalDamage = e._finalDamage
              if type(finalDamage) == "table" and finalDamage.skill then
                local skillId = finalDamage.skill
                if Skills and Skills.addXp and Skills.definitions[skillId] then
                  local xpReward = e.xpReward or 0
                  local xpGain = xpReward > 0 and math.max(1, math.floor(xpReward * 0.5)) or 5
                  Skills.addXp(skillId, xpGain)
                end
              end
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
          -- Prevent multiple death processing in the same frame
          if e._destructionProcessed then
            goto skip_entity
          end

          -- Mark as processed immediately to prevent multiple processing in same frame
          e._destructionProcessed = true

          if e.isPlayer then
            Events.emit(Events.GAME_EVENTS.PLAYER_DIED, {player = e})
          end
          
          -- Player death: respawn just outside weapon disable ring (same as initial spawn)
          local px, py = x, y
          
          local hubStation = hub or findHubStation(world)
          
          if hubStation and hubStation.components and hubStation.components.position then
            local stationPos = hubStation.components.position
            -- Use same spawn logic as initial spawn - just outside weapon disable ring
            local angle = math.random() * math.pi * 2
            local weapon_disable_radius = hubStation:getWeaponDisableRadius() or Constants.STATION.WEAPONS_DISABLE_DURATION * 200
            local spawn_dist = weapon_disable_radius * 1.2 -- Spawn 20% outside the weapon disable zone
            px = stationPos.x + math.cos(angle) * spawn_dist
            py = stationPos.y + math.sin(angle) * spawn_dist
            
            -- Check for collision with all stations to ensure we don't respawn inside one
            local attempts = 0
            local maxAttempts = 20 -- Reduced from 50 to prevent long delays
            local spawnValid = false
            
            while not spawnValid and attempts < maxAttempts do
              attempts = attempts + 1
              spawnValid = true
              
              -- Check collision with all stations (with timeout protection)
              local all_stations = world:get_entities_with_components("station")
              local stationCheckStart = love.timer.getTime()
              local maxStationCheckTime = 0.005 -- 5ms max for station checking
              
              for i, station in ipairs(all_stations) do
                -- Timeout protection for station checking
                if love.timer.getTime() - stationCheckStart > maxStationCheckTime then
                  Log.warn("DestructionSystem - Station collision check timed out, using current position")
                  spawnValid = true
                  break
                end
                
                if station and station.components and station.components.position and station.components.collidable then
                  local sx, sy = station.components.position.x, station.components.position.y
                  local dx = px - sx
                  local dy = py - sy
                  local distance = math.sqrt(dx * dx + dy * dy)
                  
                  -- Check if player would respawn inside station collision area
                  local stationRadius = 50 -- Default safe radius
                  if station.components.collidable.radius then
                    stationRadius = station.components.collidable.radius
                  elseif station.radius then
                    stationRadius = station.radius
                  end
                  
                  -- Add some buffer to ensure we're not touching the station
                  local safeDistance = stationRadius + 30
                  
                  if distance < safeDistance then
                    spawnValid = false
                    -- Try a new random position
                    angle = math.random() * math.pi * 2
                    px = stationPos.x + math.cos(angle) * spawn_dist
                    py = stationPos.y + math.sin(angle) * spawn_dist
                    break
                  end
                end
              end
              
              -- Add small delay between attempts to prevent tight loop
              if not spawnValid and attempts < maxAttempts then
                local delayStart = love.timer.getTime()
                while love.timer.getTime() - delayStart < 0.001 do
                  -- 1ms delay
                end
              end
            end
            
            -- If we couldn't find a valid respawn after max attempts, use a fallback position
            if not spawnValid then
              px = stationPos.x + spawn_dist
              py = stationPos.y
            end
            
            -- Flag prevents spawn system from placing enemies near the player this frame
            world._suppressPlayerDeathSpawn = true
          else
            Debug.warn("destruction", "No hub station found, respawning at death location: %d, %d", px, py)
          end
          
          -- Restore player state (keep entity alive)
          e.components.position.x = px
          e.components.position.y = py
          e.components.position.angle = 0 -- Reset angle
          
          -- Handle Windfield physics
          if e.components.windfield_physics then
            local PhysicsSystem = require("src.systems.physics")
            local manager = PhysicsSystem.getManager()
            if manager then
              -- Remove existing collider
              manager:removeEntity(e)
              -- Recreate with new position
              e.components.windfield_physics.x = px
              e.components.windfield_physics.y = py
              manager:addEntity(e)
            end
          end
          
          
          -- Reset velocities and ensure the physics body matches the respawn location
          -- Handle Windfield physics velocity reset
          if e.components.windfield_physics then
            local PhysicsSystem = require("src.systems.physics")
            local manager = PhysicsSystem.getManager()
            if manager then
              local collider = manager:getCollider(e)
              if collider then
                collider:setLinearVelocity(0, 0)
                collider:setAngularVelocity(0)
                collider:setPosition(px, py)
                collider:setAngle(0)
              end
            end
          end
          
          
          -- Restore full health and shields
          if e.components.hull then
            e.components.hull.hp = e.components.hull.maxHP
          end
          if e.components.shield then
            e.components.shield.shield = e.components.shield.maxShield
          end

          if e.isPlayer then
            -- Deduct 100 credit death penalty (minimum 0 credits remaining)
            local deathCost = 100
            local currentCredits = 0
            
            -- Get current credit amount
            if e.components and e.components.progression then
              currentCredits = e.components.progression.gc or 0
            elseif e.gc then
              currentCredits = e.gc
            end
            
            -- Only deduct if player has enough credits
            if currentCredits >= deathCost then
              if e.spendGC then
                e:spendGC(deathCost)
              elseif e.components and e.components.progression and e.components.progression.spendGC then
                e.components.progression:spendGC(deathCost)
              end
            else
              -- Player doesn't have enough credits, set to 0
              if e.components and e.components.progression then
                e.components.progression.gc = 0
              elseif e.gc then
                e.gc = 0
              end
            end
            
            -- Ensure player is not docked after respawn (override any save data)
            e.docked = false
            e.weaponsDisabled = false
            e.frozen = false
            
            -- Force undock if player was docked
            if e.undock and type(e.undock) == "function" then
              e:undock()
            end
            
            Events.emit(Events.GAME_EVENTS.PLAYER_RESPAWN, {player = e})
            
            -- Mark player as no longer dead after successful respawn
            e.dead = false
            
            -- Reset destruction processed flag to allow future death processing
            e._destructionProcessed = false
            
            -- Recreate engine trail component if missing
            if not e.components.engine_trail then
              local EngineTrail = require("src.components.engine_trail")
              local ModelUtil = require("src.core.model_util")
              local shipConfig = e.ship or {}
              local visuals = e.visuals or {}
              
              -- Configure engine trail colors based on ship visuals
              local engineColors = {
                color1 = (visuals.engineColor and {visuals.engineColor[1], visuals.engineColor[2], visuals.engineColor[3], 0.8}) or {0.0, 0.0, 1.0, 0.8},
                color2 = (visuals.engineColor and {visuals.engineColor[1] * 0.5, visuals.engineColor[2] * 0.5, visuals.engineColor[3], 0.4}) or {0.0, 0.0, 0.5, 0.4},
                size = (visuals.size or 1.0) * 0.8,
                offset = ModelUtil.calculateModelWidth(shipConfig.visuals) * 0.3
              }
              
              e.components.engine_trail = EngineTrail.new(engineColors)
            end
            
            -- Ensure player is properly added to world if not already
            if world and world.addEntity then
              local alreadyInWorld = false
              for _, entity in ipairs(world:getEntities()) do
                if entity == e then
                  alreadyInWorld = true
                  break
                end
              end
              
              if not alreadyInWorld then
                world:addEntity(e)
              end
            end
          end
        end
      end
    end
    ::skip_entity::
    ::continue::
  end
end

return DestructionSystem
