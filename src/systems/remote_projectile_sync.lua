--[[
    Remote Projectile Synchronization System
    Handles synchronization of projectile entities from host to clients when
    host-authoritative projectile combat is enabled.
]]

local Events = require("src.core.events")
local Log = require("src.core.log")
local Settings = require("src.core.settings")
local NetworkManager = require("src.core.network.manager")
local Util = require("src.core.util")
local DynamicLight = require("src.components.dynamic_light")

local RemoteProjectileSync = {}

local remoteProjectiles = {}
local lastProjectileSnapshot = nil
local projectileSendAccumulator = 0
local PROJECTILE_SEND_INTERVAL = 1 / 30  -- 30 Hz for projectile updates (higher than enemies due to faster movement)

function RemoteProjectileSync.reset()
    remoteProjectiles = {}
    lastProjectileSnapshot = nil
    projectileSendAccumulator = 0
end

local function copyColor(color)
    if type(color) ~= "table" then
        return nil
    end

    return {
        tonumber(color[1]) or 1,
        tonumber(color[2]) or 1,
        tonumber(color[3]) or 1,
        tonumber(color[4]) or 1,
    }
end

local function sanitiseRenderableProps(props)
    if type(props) ~= "table" then
        return nil
    end

    local sanitised = {}

    if props.kind ~= nil then sanitised.kind = tostring(props.kind) end
    if props.length ~= nil then sanitised.length = tonumber(props.length) or 0 end
    if props.maxLength ~= nil then sanitised.maxLength = tonumber(props.maxLength) or 0 end
    if props.tracerWidth ~= nil then sanitised.tracerWidth = tonumber(props.tracerWidth) or 0 end
    if props.coreRadius ~= nil then sanitised.coreRadius = tonumber(props.coreRadius) or 0 end
    if props.angle ~= nil then sanitised.angle = tonumber(props.angle) or 0 end

    local color = copyColor(props.color)
    if color then sanitised.color = color end

    if next(sanitised) then
        return sanitised
    end

    return nil
end

local function sanitiseDamageData(damage)
    if not damage then
        return nil
    end

    local function toNumber(value)
        if value == nil then
            return nil
        end
        local number = tonumber(value)
        return number or value
    end

    -- Allow callers to pass either the raw damage table or the damage component
    local raw = damage
    -- Check if this looks like a damage component wrapper (has value but no min/max/dps/skill)
    if type(damage) == "table" and damage.value ~= nil and damage.min == nil and damage.max == nil and damage.damagePerSecond == nil and damage.skill == nil then
        raw = damage.value
    end

    if type(raw) ~= "table" then
        local numeric = tonumber(raw)
        if numeric then
            return {
                min = numeric,
                max = numeric,
                value = numeric,
            }
        end
        return nil
    end

    local sanitised = {}

    sanitised.min = toNumber(raw.min or raw[1])
    sanitised.max = toNumber(raw.max or raw[2])
    sanitised.value = toNumber(raw.value)
    sanitised.damagePerSecond = toNumber(raw.damagePerSecond or raw.dps)
    sanitised.skill = raw.skill

    if sanitised.min == nil and sanitised.value ~= nil then
        sanitised.min = sanitised.value
    end
    if sanitised.max == nil and sanitised.value ~= nil then
        sanitised.max = sanitised.value
    end
    if sanitised.value == nil and sanitised.min ~= nil and sanitised.max ~= nil and sanitised.min == sanitised.max then
        sanitised.value = sanitised.min
    end

    if sanitised.min == nil and sanitised.max == nil and sanitised.value == nil and sanitised.damagePerSecond == nil and sanitised.skill == nil then
        return nil
    end

    return sanitised
end

local function sanitiseProjectileSnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return {}
    end

    local sanitised = {}
    for _, projectile in ipairs(snapshot) do
        if type(projectile) == "table" and projectile.id and projectile.type then
            local sanitisedProjectile = {
                id = tostring(projectile.id),
                type = tostring(projectile.type),
                position = {
                    x = tonumber(projectile.position and projectile.position.x) or 0,
                    y = tonumber(projectile.position and projectile.position.y) or 0,
                    angle = tonumber(projectile.position and projectile.position.angle) or 0
                },
                velocity = {
                    x = tonumber(projectile.velocity and projectile.velocity.x) or 0,
                    y = tonumber(projectile.velocity and projectile.velocity.y) or 0
                },
                friendly = projectile.friendly or false,
                sourceId = projectile.sourceId or nil,
                damage = projectile.damage or nil,
                kind = (projectile.kind and tostring(projectile.kind)) or ((projectile.renderableProps and projectile.renderableProps.kind) and tostring(projectile.renderableProps.kind)) or "bullet",
                timed_life = projectile.timed_life or nil,
                sourcePlayerId = projectile.sourcePlayerId or projectile.source_player_id or nil,
                sourceShipId = projectile.sourceShipId or projectile.source_ship_id or nil,
                sourceTurretSlot = tonumber(projectile.sourceTurretSlot or projectile.source_turret_slot) or nil,
                sourceTurretId = projectile.sourceTurretId or projectile.source_turret_id or nil,
                sourceTurretType = projectile.sourceTurretType or projectile.source_turret_type or nil,
            }

            -- Include damage data if available
            local damageData = sanitiseDamageData(projectile.damage)
            if damageData then
                -- Normalise numeric fields where possible while preserving metadata
                if damageData.min ~= nil then damageData.min = tonumber(damageData.min) or damageData.min end
                if damageData.max ~= nil then damageData.max = tonumber(damageData.max) or damageData.max end
                if damageData.value ~= nil then damageData.value = tonumber(damageData.value) or damageData.value end
                if damageData.damagePerSecond ~= nil then
                    damageData.damagePerSecond = tonumber(damageData.damagePerSecond) or damageData.damagePerSecond
                end
                sanitisedProjectile.damage = damageData
            end

            -- Include timed life data if available
            if projectile.timed_life then
                sanitisedProjectile.timed_life = {
                    duration = tonumber(projectile.timed_life.duration) or 2.0,
                    elapsed = tonumber(projectile.timed_life.elapsed) or 0
                }
            end

            local renderableProps = sanitiseRenderableProps(projectile.renderableProps)
            if renderableProps then
                sanitisedProjectile.renderableProps = renderableProps
            end

            if projectile.impact and type(projectile.impact) == "table" then
                sanitisedProjectile.impact = Util.deepCopy(projectile.impact)
            end

            if projectile.dynamicLight then
                local dyn = projectile.dynamicLight
                sanitisedProjectile.dynamicLight = {
                    color = copyColor(dyn.color) or dyn.color,
                    radius = tonumber(dyn.radius) or dyn.radius,
                    intensity = tonumber(dyn.intensity) or dyn.intensity,
                    offset = dyn.offset and {
                        x = tonumber(dyn.offset.x) or dyn.offset.x or 0,
                        y = tonumber(dyn.offset.y) or dyn.offset.y or 0,
                    } or nil,
                    pulse = dyn.pulse and Util.deepCopy(dyn.pulse) or nil,
                }
            end

            table.insert(sanitised, sanitisedProjectile)
        end
    end

    return sanitised
end

local function buildProjectileSnapshotFromWorld(world)
    if not world then
        return {}
    end

    local snapshot = {}
    -- Get all entities with projectile components (bullets, missiles, etc.)
    local entities = world:get_entities_with_components("bullet", "position")
    
    Log.debug("Host scanning for projectiles, found", #entities, "entities with bullet component")

    for _, entity in ipairs(entities) do
        -- Only include projectile entities
        if entity.components and entity.components.projectile then
            local position = entity.components.position
            local velocity = entity.components.velocity
            local damage = entity.components.damage
            local timed_life = entity.components.timed_life

            -- Convert source entity to player ID for network transmission
            local sourceId = nil
            local source = entity.components.projectile.source
            if source then
                if source.isPlayer and source.id then
                    sourceId = source.id
                    Log.debug("Host: Projectile", entity.id, "source is local player", sourceId)
                elseif source.remotePlayerId then
                    sourceId = source.remotePlayerId
                    Log.debug("Host: Projectile", entity.id, "source is remote player", sourceId)
                elseif source.id then
                    sourceId = source.id
                    Log.debug("Host: Projectile", entity.id, "source is entity", sourceId)
                end
            else
                Log.debug("Host: Projectile", entity.id, "has no source")
            end

            local renderable = entity.components.renderable
            local renderableProps = renderable and renderable.props or nil
            local projectileKind = nil
            if renderableProps and renderableProps.kind then
                projectileKind = renderableProps.kind
            elseif entity.kind then
                projectileKind = entity.kind
            end

            local renderableSnapshot = nil
            if renderableProps then
                renderableSnapshot = {
                    kind = renderableProps.kind,
                    length = renderableProps.length,
                    maxLength = renderableProps.maxLength,
                    tracerWidth = renderableProps.tracerWidth,
                    coreRadius = renderableProps.coreRadius,
                    angle = renderableProps.angle,
                }

                local color = renderableProps.color
                if color then
                    renderableSnapshot.color = copyColor(color)
                end
            end

            local impact = entity.components.projectile and entity.components.projectile.impact
            local projectileMeta = entity.components.projectile or {}

            local sourcePlayerId = projectileMeta.sourcePlayerId
            if not sourcePlayerId and source then
                sourcePlayerId = source.remotePlayerId or source.playerId or source.id
            end

            local sourceShipId = projectileMeta.sourceShipId or (source and (source.shipId or (source.ship and source.ship.id)))

            local projectileData = {
                id = entity.id or tostring(entity),
                type = entity.projectileType or "gun_bullet",
                position = {
                    x = position.x or 0,
                    y = position.y or 0,
                    angle = position.angle or 0
                },
                velocity = {
                    x = velocity and velocity.x or 0,
                    y = velocity and velocity.y or 0
                },
                friendly = entity.friendly or false,
                sourceId = sourceId,
                kind = projectileKind,
                renderableProps = renderableSnapshot,
                impact = impact and Util.deepCopy(impact) or nil,
                sourcePlayerId = sourcePlayerId,
                sourceShipId = sourceShipId,
                sourceTurretSlot = bulletMeta.slot,
                sourceTurretId = bulletMeta.turretId,
                sourceTurretType = bulletMeta.turretType,
            }

            -- Include damage data
            local damageData = sanitiseDamageData(damage)
            if damageData then
                projectileData.damage = damageData
            end

            -- Include timed life data
            if timed_life then
                projectileData.timed_life = {
                    duration = timed_life.duration or 2.0,
                    elapsed = timed_life.elapsed or 0
                }
            end

            local dynamicLight = entity.components.dynamic_light
            if dynamicLight then
                projectileData.dynamicLight = {
                    color = copyColor(dynamicLight.color),
                    radius = tonumber(dynamicLight.radius) or dynamicLight.radius,
                    intensity = tonumber(dynamicLight.intensity) or dynamicLight.intensity,
                    offset = dynamicLight.offset and {
                        x = tonumber(dynamicLight.offset.x) or dynamicLight.offset.x or 0,
                        y = tonumber(dynamicLight.offset.y) or dynamicLight.offset.y or 0,
                    } or nil,
                    pulse = dynamicLight.pulse and Util.deepCopy(dynamicLight.pulse) or nil,
                }
            end

            table.insert(snapshot, projectileData)
        end
    end

    return snapshot
end

local function ensureRemoteProjectile(projectileId, projectileData, world)
    if not world then
        return nil
    end

    local entity = remoteProjectiles[projectileId]
    if entity then
        return entity
    end

    -- Create a new remote projectile entity
    local EntityFactory = require("src.templates.entity_factory")
    local x = projectileData.position and projectileData.position.x or 0
    local y = projectileData.position and projectileData.position.y or 0
    local angle = projectileData.position and projectileData.position.angle or 0

    -- Use the projectile type from the data, fallback to gun_bullet
    local projectileType = projectileData.type or "gun_bullet"
    
    -- Resolve sourceId to actual player entity
    local source = nil
    if projectileData.sourceId then
        Log.debug("Resolving sourceId", projectileData.sourceId, "for projectile", projectileId)
        -- Try to find the player entity by ID
        local Game = require("src.game")
        local world = Game.world
        if world then
            -- First try to find local player
            local player = world:getPlayer()
            if player and player.id == projectileData.sourceId then
                source = player
                Log.debug("Found local player as source for projectile", projectileId)
            else
                -- Try to find remote player
                local NetworkSync = require("src.systems.network_sync")
                local remotePlayers = NetworkSync.getRemotePlayers()
                for _, remotePlayer in pairs(remotePlayers) do
                    if remotePlayer.id == projectileData.sourceId or remotePlayer.remotePlayerId == projectileData.sourceId then
                        source = remotePlayer
                        Log.debug("Found remote player as source for projectile", projectileId)
                        break
                    end
                end
            end
        end
    else
        Log.debug("No sourceId provided for projectile", projectileId)
    end

    -- Create projectile with proper configuration
    local extra_config = {
        angle = angle,
        friendly = projectileData.friendly or false,
        damage = projectileData.damage and Util.deepCopy(projectileData.damage) or nil,
        kind = projectileData.kind,
        timed_life = projectileData.timed_life,
        source = source,
        impact = projectileData.impact and Util.deepCopy(projectileData.impact) or nil,
        sourcePlayerId = projectileData.sourcePlayerId,
        sourceShipId = projectileData.sourceShipId,
        sourceTurretSlot = projectileData.sourceTurretSlot,
        sourceTurretId = projectileData.sourceTurretId,
        sourceTurretType = projectileData.sourceTurretType,
    }

    if projectileData.renderableProps then
        extra_config.tracerWidth = projectileData.renderableProps.tracerWidth
        extra_config.coreRadius = projectileData.renderableProps.coreRadius
        extra_config.color = projectileData.renderableProps.color and Util.deepCopy(projectileData.renderableProps.color) or nil
        extra_config.length = projectileData.renderableProps.length
        extra_config.maxLength = projectileData.renderableProps.maxLength
        -- Preserve explicit kind overrides if present in renderable props
        if not extra_config.kind and projectileData.renderableProps.kind then
            extra_config.kind = projectileData.renderableProps.kind
        end
    end

    entity = EntityFactory.create("projectile", projectileType, x, y, extra_config)

    if not entity then
        Log.error("Failed to spawn remote projectile entity", projectileId, "of type", projectileType)
        return nil
    end

    if projectileData.dynamicLight then
        entity.components = entity.components or {}
        entity.components.dynamic_light = DynamicLight.new(projectileData.dynamicLight)
    end

    entity.isRemoteProjectile = true
    entity.remoteProjectileId = projectileId
    entity.projectileType = projectileType

    world:addEntity(entity)
    remoteProjectiles[projectileId] = entity

    return entity
end

local function updateProjectileFromSnapshot(entity, projectileData)
    if not entity or not projectileData then
        return
    end

    -- Update position
    if entity.components and entity.components.position and projectileData.position then
        entity.components.position.x = projectileData.position.x
        entity.components.position.y = projectileData.position.y
        entity.components.position.angle = projectileData.position.angle
    end

    -- Update velocity
    if entity.components and entity.components.velocity and projectileData.velocity then
        entity.components.velocity.x = projectileData.velocity.x
        entity.components.velocity.y = projectileData.velocity.y
    end

    -- Update damage
    if entity.components and entity.components.damage and projectileData.damage then
        local damageComponent = entity.components.damage
        local damageData = projectileData.damage
        
        -- Set the numeric damage value (prefer .value, fallback to .min or first element)
        damageComponent.value = damageData.value or damageData.min or (type(damageData) == "table" and damageData[1]) or 1
        
        -- Set additional damage properties
        damageComponent.min = damageData.min
        damageComponent.max = damageData.max
        damageComponent.skill = damageData.skill
        damageComponent.damagePerSecond = damageData.damagePerSecond
    end

    -- Update timed life
    if entity.components and entity.components.timed_life and projectileData.timed_life then
        entity.components.timed_life.duration = projectileData.timed_life.duration
        entity.components.timed_life.elapsed = projectileData.timed_life.elapsed
    end

    if entity.components then
        if projectileData.dynamicLight then
            local existing = entity.components.dynamic_light
            if existing then
                existing.color = projectileData.dynamicLight.color or existing.color
                existing.radius = projectileData.dynamicLight.radius or existing.radius
                existing.intensity = projectileData.dynamicLight.intensity or existing.intensity
                existing.offset = projectileData.dynamicLight.offset or existing.offset
                existing.pulse = projectileData.dynamicLight.pulse or existing.pulse
            else
                entity.components.dynamic_light = DynamicLight.new(projectileData.dynamicLight)
            end
        elseif entity.components.dynamic_light then
            entity.components.dynamic_light = nil
        end
    end

    -- Update impact configuration for consistent collision FX
    if entity.components and entity.components.projectile and projectileData.impact then
        entity.components.projectile.impact = Util.deepCopy(projectileData.impact)
    end
    
    if entity.components and entity.components.projectile then
        local projectile = entity.components.projectile
        if projectileData.sourceTurretSlot ~= nil then
            projectile.slot = projectileData.sourceTurretSlot
        end
        if projectileData.sourceTurretId ~= nil then
            projectile.turretId = projectileData.sourceTurretId
        end
        if projectileData.sourceTurretType ~= nil then
            projectile.turretType = projectileData.sourceTurretType
        end
        if projectileData.sourcePlayerId ~= nil then
            bullet.sourcePlayerId = projectileData.sourcePlayerId
        end
        if projectileData.sourceShipId ~= nil then
            bullet.sourceShipId = projectileData.sourceShipId
        end
    end

    -- Update renderable properties (beam length, colors, etc.)
    if entity.components and entity.components.renderable and projectileData.renderableProps then
        local props = entity.components.renderable.props or {}

        if projectileData.renderableProps.kind ~= nil then
            props.kind = projectileData.renderableProps.kind
        end
        if projectileData.renderableProps.length ~= nil then
            props.length = projectileData.renderableProps.length
        end
        if projectileData.renderableProps.maxLength ~= nil then
            props.maxLength = projectileData.renderableProps.maxLength
        end
        if projectileData.renderableProps.tracerWidth ~= nil then
            props.tracerWidth = projectileData.renderableProps.tracerWidth
        end
        if projectileData.renderableProps.coreRadius ~= nil then
            props.coreRadius = projectileData.renderableProps.coreRadius
        end
        if projectileData.renderableProps.angle ~= nil then
            props.angle = projectileData.renderableProps.angle
        end
        if projectileData.renderableProps.color then
            props.color = Util.deepCopy(projectileData.renderableProps.color)
        end

        entity.components.renderable.props = props
    end

    -- Update physics body
    if entity.components then
        -- Handle Windfield physics
        if entity.components.windfield_physics then
            local PhysicsSystem = require("src.systems.physics")
            local manager = PhysicsSystem.getManager()
            if manager then
                local collider = manager:getCollider(entity)
                if collider then
                    collider:setPosition(projectileData.position.x, projectileData.position.y)
                    collider:setLinearVelocity(projectileData.velocity.x, projectileData.velocity.y)
                end
            end
        -- Handle legacy physics
        elseif entity.components.physics and entity.components.physics.body then
            local body = entity.components.physics.body
            if body.setPosition then
                body:setPosition(projectileData.position.x, projectileData.position.y)
            else
                body.x = projectileData.position.x
                body.y = projectileData.position.y
            end
            if body.setVelocity then
                body:setVelocity(projectileData.velocity.x, projectileData.velocity.y)
            else
                body.vx = projectileData.velocity.x
                body.vy = projectileData.velocity.y
            end
            body.angle = projectileData.position.angle
        end
    end
end

local function removeRemoteProjectile(world, projectileId)
    local entity = remoteProjectiles[projectileId]
    if not entity then
        return
    end

    if world then
        world:removeEntity(entity)
    end

    remoteProjectiles[projectileId] = nil
end

-- Host-side: Send projectile updates to clients
function RemoteProjectileSync.updateHost(dt, world, networkManager)
    if not networkManager or not networkManager:isHost() then
        return
    end

    local networkingSettings = Settings.getNetworkingSettings()
    if not networkingSettings or not networkingSettings.host_authoritative_projectiles then
        return
    end

    projectileSendAccumulator = projectileSendAccumulator + (dt or 0)

    if projectileSendAccumulator >= PROJECTILE_SEND_INTERVAL then
        local snapshot = buildProjectileSnapshotFromWorld(world)
        local sanitised = sanitiseProjectileSnapshot(snapshot)
        
        -- Always send updates when there are projectiles, or when clearing projectiles
        local shouldSend = false
        
        if #sanitised > 0 then
            -- Send if we have projectiles (always send for now to ensure sync)
            shouldSend = true
        elseif #sanitised == 0 and lastProjectileSnapshot and #lastProjectileSnapshot > 0 then
            -- Send empty snapshot to clear projectiles on clients
            shouldSend = true
        end
        
        if shouldSend then
            -- Send projectile update to all clients
            if networkManager.sendProjectileUpdate then
                Log.debug("Host -> projectile snapshot, count=", #sanitised)
                networkManager:sendProjectileUpdate(sanitised)
            end
            
            lastProjectileSnapshot = sanitised
        end
        
        projectileSendAccumulator = 0
    end
end

-- Client-side: Receive and apply projectile updates from host
function RemoteProjectileSync.updateClient(dt, world, networkManager)
    if not networkManager or networkManager:isHost() then
        return
    end

    local networkingSettings = Settings.getNetworkingSettings()
    if not networkingSettings or not networkingSettings.host_authoritative_projectiles then
        return
    end

    -- Client-side processing is handled via the NETWORK_PROJECTILE_UPDATE event
    -- in game.lua, which calls RemoteProjectileSync.applyProjectileSnapshot
    -- This function is kept for future client-side prediction/interpolation
end

function RemoteProjectileSync.applyProjectileSnapshot(snapshot, world)
    if not snapshot or not world then
        return
    end

    Log.debug("Client <- projectile snapshot, entries=", #snapshot)
    local sanitised = sanitiseProjectileSnapshot(snapshot)
    local currentProjectileIds = {}

    -- Update existing projectiles and track which ones we've seen
    for _, projectileData in ipairs(sanitised) do
        currentProjectileIds[projectileData.id] = true
        
        local entity = ensureRemoteProjectile(projectileData.id, projectileData, world)
        if entity then
            updateProjectileFromSnapshot(entity, projectileData)
        end
    end

    -- Remove projectiles that are no longer in the snapshot
    for projectileId, entity in pairs(remoteProjectiles) do
        if not currentProjectileIds[projectileId] then
            removeRemoteProjectile(world, projectileId)
        end
    end
end

function RemoteProjectileSync.getRemoteProjectiles()
    return remoteProjectiles
end

-- Event handlers
Events.on("NETWORK_DISCONNECTED", function()
    RemoteProjectileSync.reset()
end)

Events.on("NETWORK_SERVER_STOPPED", function()
    RemoteProjectileSync.reset()
end)

return RemoteProjectileSync
