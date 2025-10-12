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

-- Surface friction functionality has been removed

-- Helper function to push an entity with momentum preservation
function PhysicsResolution.pushEntity(entity, pushX, pushY, normalX, normalY, dt, restitution)
    restitution = restitution or 0.25 -- default hull bounce if unspecified
    local physics = entity.components.physics
    if physics and physics.body then
        local body = physics.body
        body.x = (body.x or entity.components.position.x) + pushX
        body.y = (body.y or entity.components.position.y) + pushY

        local vx = body.vx or 0
        local vy = body.vy or 0
        local vn = vx * normalX + vy * normalY
        if vn < 0 then
            -- Apply restitution for natural bouncing
            local delta = -(1 + restitution) * vn
            body.vx = vx + delta * normalX
            body.vy = vy + delta * normalY
            
            -- Only apply minimum velocity boost for high restitution objects (shields)
            if restitution > 0.8 then
                local newVn = body.vx * normalX + body.vy * normalY
                local minOut = 40 -- Reduced from 60 for more realistic physics
                if newVn < minOut then
                    local add = (minOut - newVn)
                    body.vx = body.vx + add * normalX
                    body.vy = body.vy + add * normalY
                end
            end
        end
    else
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
                
                -- Only apply minimum velocity boost for high restitution objects (shields)
                if restitution > 0.8 then
                    local newVn = vel.x * normalX + vel.y * normalY
                    local minOut = 40 -- Reduced from 60 for more realistic physics
                    if newVn < minOut then
                        local add = (minOut - newVn)
                        vel.x = vel.x + add * normalX
                        vel.y = vel.y + add * normalY
                    end
                end
            end
        end
    end
end

-- Collision damage system has been removed for simplified physics

-- Get restitution values for entities
function PhysicsResolution.getRestitution(entity1, entity2)
    local StationShields = require("src.systems.collision.station_shields")
    
    local HULL_REST = getCombatValue("HULL_RESTITUTION") or 0.28
    local SHIELD_REST = getCombatValue("SHIELD_RESTITUTION") or 0.88
    local e1Rest = StationShields.hasActiveShield(entity1) and SHIELD_REST or HULL_REST
    local e2Rest = StationShields.hasActiveShield(entity2) and SHIELD_REST or HULL_REST
    
    return e1Rest, e2Rest
end

return PhysicsResolution
