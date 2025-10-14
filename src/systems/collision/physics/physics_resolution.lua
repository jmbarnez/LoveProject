-- Physics Resolution System
-- Handles mass, momentum calculations and physics-based collision resolution

local Constants = require("src.core.constants")
local Config = require("src.content.config")

local PhysicsResolution = {}

local combatOverrides = Config.COMBAT or {}
local combatConstants = Constants.COMBAT

local function getCombatValue(key)
    local value = combatOverrides[key]
    if value ~= nil then return value end
    return combatConstants[key]
end

-- Helper function to get entity mass for momentum calculations
function PhysicsResolution.getEntityMass(entity)
    -- Check Windfield physics first
    if entity.components.windfield_physics then
        return entity.components.windfield_physics.mass or 1000
    end
    
    -- Check legacy physics
    local physics = entity.components.physics
    if physics and physics.body then
        return physics.body.mass or 1000
    end
    -- Fallback mass based on entity type
    if entity.components.mineable then
        return 2000 -- Asteroids are heavy
    elseif entity.tag == "station" then
        return 10000 -- Stations are very heavy
    else
        return 1000 -- Default ship mass
    end
end


-- Helper function to push an entity with momentum preservation
function PhysicsResolution.pushEntity(entity, pushX, pushY, normalX, normalY, dt, restitution)
    restitution = restitution or 0.25 -- default hull bounce if unspecified
    
    -- Handle Windfield physics
    if entity.components.windfield_physics then
        local PhysicsSystem = require("src.systems.physics")
        local manager = PhysicsSystem.getManager()
        if manager then
            local collider = manager:getCollider(entity)
            if collider and not collider:isDestroyed() then
                local oldX, oldY = collider:getPosition()
                collider:setPosition(oldX + pushX, oldY + pushY)
            end
        end
        return
    end
    
    -- Handle legacy physics
    local physics = entity.components.physics
    if physics and physics.body then
        local body = physics.body
        local oldX = body.x or entity.components.position.x
        local oldY = body.y or entity.components.position.y
        
        body.x = oldX + pushX
        body.y = oldY + pushY
        
        -- Sync physics body position with entity position
        if entity.components.position then
            entity.components.position.x = body.x
            entity.components.position.y = body.y
        end
        

        local vx = body.vx or 0
        local vy = body.vy or 0
        local vn = vx * normalX + vy * normalY
        if vn < 0 then
            -- Apply restitution for natural bouncing
            local delta = -(1 + restitution) * vn
            body.vx = vx + delta * normalX
            body.vy = vy + delta * normalY
        end
        
        -- Sync velocity with entity velocity component if it exists
        if entity.components.velocity then
            entity.components.velocity.x = body.vx
            entity.components.velocity.y = body.vy
        end
        
        -- Ensure physics body velocity is properly maintained
        -- This is critical for entities that only have physics bodies (like asteroids)
        if not entity.components.velocity then
            -- For entities without velocity components, ensure the physics body
            -- maintains its velocity for proper movement
            body.vx = body.vx or 0
            body.vy = body.vy or 0
        end
    else
        -- For entities without physics components, update position directly
        -- but this should be avoided - entities should have WindField physics
        entity.components.position.x = entity.components.position.x + pushX
        entity.components.position.y = entity.components.position.y + pushY

        local vel = entity.components.velocity
        if vel then
            local vx = vel.x or 0
            local vy = vel.y or 0
            local vn = vx * normalX + vy * normalY
            if vn < 0 then
                -- Apply restitution for natural bouncing
                local delta = -(1 + restitution) * vn
                vel.x = vx + delta * normalX
                vel.y = vy + delta * normalY
            end
        end
    end
end


-- Get restitution values for entities based on surface type
function PhysicsResolution.getRestitution(entity1, entity2)
    local StationShields = require("src.systems.collision.station_shields")
    local Constants = require("src.systems.collision.constants")
    
    -- Base restitution values for different surface types
    local HULL_REST = getCombatValue("HULL_RESTITUTION") or Constants.HULL_RESTITUTION
    local SHIELD_REST = getCombatValue("SHIELD_RESTITUTION") or Constants.SHIELD_RESTITUTION
    local ASTEROID_REST = Constants.ASTEROID_RESTITUTION
    local STATION_REST = Constants.STATION_RESTITUTION
    local WRECKAGE_REST = Constants.WRECKAGE_RESTITUTION
    local PLANET_REST = Constants.PLANET_RESTITUTION
    local PROJECTILE_REST = Constants.PROJECTILE_RESTITUTION
    
    -- Determine surface type for entity1
    local e1Rest = HULL_REST
    if entity1.components and entity1.components.bullet then
        e1Rest = PROJECTILE_REST  -- Projectiles don't bounce
    elseif StationShields.hasActiveShield(entity1) then
        e1Rest = SHIELD_REST
    elseif entity1.components and entity1.components.mineable then
        e1Rest = ASTEROID_REST
    elseif entity1.tag == "station" or (entity1.components and entity1.components.station) then
        e1Rest = STATION_REST
    elseif entity1.components and entity1.components.wreckage then
        e1Rest = WRECKAGE_REST
    elseif entity1.type == "world_object" and entity1.subtype == "planet_massive" then
        e1Rest = PLANET_REST
    end
    
    -- Determine surface type for entity2
    local e2Rest = HULL_REST
    if entity2.components and entity2.components.bullet then
        e2Rest = PROJECTILE_REST  -- Projectiles don't bounce
    elseif StationShields.hasActiveShield(entity2) then
        e2Rest = SHIELD_REST
    elseif entity2.components and entity2.components.mineable then
        e2Rest = ASTEROID_REST
    elseif entity2.tag == "station" or (entity2.components and entity2.components.station) then
        e2Rest = STATION_REST
    elseif entity2.components and entity2.components.wreckage then
        e2Rest = WRECKAGE_REST
    elseif entity2.type == "world_object" and entity2.subtype == "planet_massive" then
        e2Rest = PLANET_REST
    end
    
    -- Force zero restitution if either entity is a projectile
    if (entity1.components and entity1.components.bullet) or (entity2.components and entity2.components.bullet) then
        return 0.0, 0.0
    end
    
    return e1Rest, e2Rest
end

return PhysicsResolution
