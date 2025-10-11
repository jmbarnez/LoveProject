local Effects = require("src.systems.effects")
local Events = require("src.core.events")
local Config = require("src.content.config")
local StationShields = require("src.systems.collision.station_shields")
local Radius = require("src.systems.collision.radius")

local CollisionEffects = {}

-- Debug flag to help identify collision effect issues
local DEBUG_COLLISION_EFFECTS = true

local function debugLog(message)
    if DEBUG_COLLISION_EFFECTS then
        print("[CollisionEffects] " .. tostring(message))
    end
end

-- Find the closest point on a polygon to a given direction
function CollisionEffects.findClosestPointOnPolygon(centerX, centerY, dirX, dirY, vertices, angle)
    if not vertices or #vertices < 6 then
        -- Fallback to center if no valid vertices
        return { x = centerX, y = centerY }
    end
    
    local Geometry = require("src.systems.collision.geometry")
    
    -- Transform polygon vertices to world coordinates
    local worldVertices = Geometry.transformPolygon(centerX, centerY, angle, vertices)
    if not worldVertices then
        return { x = centerX, y = centerY }
    end
    
    local closestPoint = { x = centerX, y = centerY }
    local closestDistance = math.huge
    
    -- Check each edge of the polygon
    for i = 1, #worldVertices, 2 do
        local nextI = i + 2
        if nextI > #worldVertices then nextI = 1 end
        
        local x1, y1 = worldVertices[i], worldVertices[i + 1]
        local x2, y2 = worldVertices[nextI], worldVertices[nextI + 1]
        
        -- Find the closest point on this edge to the direction vector
        local edgeDx = x2 - x1
        local edgeDy = y2 - y1
        local edgeLength = math.sqrt(edgeDx * edgeDx + edgeDy * edgeDy)
        
        if edgeLength > 0 then
            -- Project the direction vector onto the edge
            local t = ((dirX * edgeDx + dirY * edgeDy) / (edgeLength * edgeLength))
            t = math.max(0, math.min(1, t)) -- Clamp to edge bounds
            
            local pointX = x1 + t * edgeDx
            local pointY = y1 + t * edgeDy
            
            -- Calculate distance from center to this point
            local dx = pointX - centerX
            local dy = pointY - centerY
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance < closestDistance then
                closestDistance = distance
                closestPoint = { x = pointX, y = pointY }
            end
        end
    end
    
    return closestPoint
end

-- Find the extreme point of a polygon in a given world-space direction
-- Note: vertices should already be in world space (transformed)
function CollisionEffects.findSupportPoint(vertices, dirX, dirY)
    if not vertices or #vertices < 6 then
        return nil
    end

    local bestDot = -math.huge
    local bestX, bestY = nil, nil

    for i = 1, #vertices, 2 do
        local x, y = vertices[i], vertices[i + 1]
        if x and y then
            local dot = x * dirX + y * dirY
            if dot > bestDot then
                bestDot = dot
                bestX, bestY = x, y
            end
        end
    end

    if bestX and bestY then
        return { x = bestX, y = bestY }
    end

    return nil
end

-- Check if entity is a player with active shields
local function get_health(entity)
    if not entity or not entity.components then
        return nil
    end
    return entity.components.health
end

function CollisionEffects.isPlayerShieldActive(entity)
    if not entity then return false end

    local isPlayer = entity.isPlayer or entity.isRemotePlayer or (entity.components and entity.components.player ~= nil)
    if not isPlayer then
        return false
    end

    if entity.shieldChannel then
        return true
    end

    local health = get_health(entity)
    return health and (health.shield or 0) > 0 or false
end

function CollisionEffects.hasShield(entity)
    if not entity then return false end

    if StationShields.hasActiveShield(entity) then
        return true
    end

    if entity.shieldChannel then
        return true
    end

    local health = get_health(entity)
    return health and (health.shield or 0) > 0 or false
end

-- Simple cooldown for repeated collision FX between the same pair to prevent spam
local COLLISION_FX_COOLDOWN = (Config and Config.EFFECTS and Config.EFFECTS.COLLISION_FX_COOLDOWN) or 0.25 -- seconds

function CollisionEffects.canEmitCollisionFX(a, b, now)
  if not a or not b or not a.id or not b.id then return true end
  
  -- Check if entities belong to the same logical group
  local areInSameGroup = false
  if a.station_id and b.station_id and a.station_id == b.station_id then
    areInSameGroup = true
  elseif a.parent_station and b.parent_station and a.parent_station == b.parent_station then
    areInSameGroup = true
  elseif a.tag == "station" and b.parent_station == a then
    areInSameGroup = true
  elseif b.tag == "station" and a.parent_station == b then
    areInSameGroup = true
  elseif a.components and a.components.station and b.components and b.components.station and a.station == b.station then
    areInSameGroup = true
  elseif a.ship_id and b.ship_id and a.ship_id == b.ship_id then
    areInSameGroup = true
  elseif a.asteroid_id and b.asteroid_id and a.asteroid_id == b.asteroid_id then
    areInSameGroup = true
  elseif a.wreckage_id and b.wreckage_id and a.wreckage_id == b.wreckage_id then
    areInSameGroup = true
  elseif a.enemy_id and b.enemy_id and a.enemy_id == b.enemy_id then
    areInSameGroup = true
  elseif a.hub_id and b.hub_id and a.hub_id == b.hub_id then
    areInSameGroup = true
  elseif a.warp_gate_id and b.warp_gate_id and a.warp_gate_id == b.warp_gate_id then
    areInSameGroup = true
  elseif a.beacon_id and b.beacon_id and a.beacon_id == b.beacon_id then
    areInSameGroup = true
  elseif a.ore_furnace_id and b.ore_furnace_id and a.ore_furnace_id == b.ore_furnace_id then
    areInSameGroup = true
  elseif a.holographic_turret_id and b.holographic_turret_id and a.holographic_turret_id == b.holographic_turret_id then
    areInSameGroup = true
  elseif a.reward_crate_id and b.reward_crate_id and a.reward_crate_id == b.reward_crate_id then
    areInSameGroup = true
  elseif a.planet_id and b.planet_id and a.planet_id == b.planet_id then
    areInSameGroup = true
  end
  
  -- For entities in the same group, use group-based cooldown
  if areInSameGroup then
    local groupKey = math.min(a.id, b.id) .. "_" .. math.max(a.id, b.id)
    a._groupCollisionFX = a._groupCollisionFX or {}
    local lastGroupCollision = a._groupCollisionFX[groupKey] or 0
    
    if (now - lastGroupCollision) >= COLLISION_FX_COOLDOWN then
      a._groupCollisionFX[groupKey] = now
      return true
    end
    return false
  end
  
  -- For entities not in the same group, use individual entity cooldown
  a._collisionFx = a._collisionFx or {}
  b._collisionFx = b._collisionFx or {}
  local t = a._collisionFx[b.id] or 0
  if (now - t) >= COLLISION_FX_COOLDOWN then
    a._collisionFx[b.id] = now
    b._collisionFx[a.id] = now
    return true
  end
  return false
end

-- Create collision effects for both entities in a collision
function CollisionEffects.createCollisionEffects(entity1, entity2, e1x, e1y, e2x, e2y, nx, ny, e1Radius, e2Radius, shape1, shape2, disableSound)
    if not Effects then return end

    -- Validate input parameters
    if not entity1 or not entity2 or not e1x or not e1y or not e2x or not e2y then
        return
    end

    -- In physics simulation, we always use precise collision points
    local isPreciseHit = true
    
    -- Normal from entity1 towards entity2. Ensure it is normalized so the
    -- collision offsets behave predictably even when the MTV returns a
    -- scaled vector.
    local normalLength = math.sqrt((nx or 0) * (nx or 0) + (ny or 0) * (ny or 0))
    if normalLength > 1e-5 then
        nx, ny = nx / normalLength, ny / normalLength
    else
        nx, ny = 1, 0 -- Fallback direction when the normal is degenerate
    end

    -- Calculate collision points for each entity
    -- For more accurate collision points, especially with polygon shapes
    local e1Collidable = entity1.components and entity1.components.collidable
    local e2Collidable = entity2.components and entity2.components.collidable

    local midX = (e1x + e2x) * 0.5
    local midY = (e1y + e2y) * 0.5

    local function resolveCollisionPoint(entity, centerX, centerY, normalX, normalY, radius, collidable, shape)
        -- For polygon shapes, use the world-transformed vertices from the collision shape
        if shape and shape.type == "polygon" and shape.vertices then
            local support = CollisionEffects.findSupportPoint(shape.vertices, normalX, normalY)
            if support then
                return support.x, support.y
            end
        end

        -- For circular shapes, use the shape radius and center
        if shape and shape.type == "circle" then
            local shapeRadius = shape.radius or radius
            if shapeRadius and shapeRadius > 0 then
                return centerX + normalX * shapeRadius, centerY + normalY * shapeRadius
            end
        end

        -- Fallback: try to use collidable component data
        if collidable and collidable.shape == "polygon" and collidable.vertices then
            local angle = (entity.components and entity.components.position and entity.components.position.angle) or 0
            local closestPoint = CollisionEffects.findClosestPointOnPolygon(centerX, centerY, normalX, normalY, collidable.vertices, angle)
            if closestPoint then
                return closestPoint.x, closestPoint.y
            end
        end

        if collidable and collidable.shape == "circle" and collidable.radius then
            return centerX + normalX * collidable.radius, centerY + normalY * collidable.radius
        end

        -- Final fallback: use radius-based calculation
        if radius and radius > 0 then
            return centerX + normalX * radius, centerY + normalY * radius
        end

        return nil, nil
    end

    -- Calculate collision points more accurately using the collision normal and overlap
    local e1CollisionX, e1CollisionY, e2CollisionX, e2CollisionY
    
    if isPreciseHit then
        -- Use the precise hit position for both entities
        e1CollisionX, e1CollisionY = e1x, e1y
        e2CollisionX, e2CollisionY = e2x, e2y
    else
        -- Calculate collision points using normal collision detection
        e1CollisionX, e1CollisionY = resolveCollisionPoint(entity1, e1x, e1y, nx, ny, e1Radius, e1Collidable, shape1)
        if not e1CollisionX then
            -- Fallback: use midpoint between entities
            e1CollisionX, e1CollisionY = midX, midY
        end

        e2CollisionX, e2CollisionY = resolveCollisionPoint(entity2, e2x, e2y, -nx, -ny, e2Radius, e2Collidable, shape2)
        if not e2CollisionX then
            -- Fallback: use midpoint between entities
            e2CollisionX, e2CollisionY = midX, midY
        end
    end

    -- Additional validation: ensure collision points are reasonable
    local maxDistance = math.max(e1Radius or 0, e2Radius or 0) * 3
    local e1Distance = math.sqrt((e1CollisionX - e1x)^2 + (e1CollisionY - e1y)^2)
    local e2Distance = math.sqrt((e2CollisionX - e2x)^2 + (e2CollisionY - e2y)^2)
    
    if e1Distance > maxDistance then
        debugLog(string.format("Entity1 collision point too far: distance=%.2f, max=%.2f, using fallback", e1Distance, maxDistance))
        e1CollisionX, e1CollisionY = e1x + nx * (e1Radius or 10), e1y + ny * (e1Radius or 10)
    end
    
    if e2Distance > maxDistance then
        debugLog(string.format("Entity2 collision point too far: distance=%.2f, max=%.2f, using fallback", e2Distance, maxDistance))
        e2CollisionX, e2CollisionY = e2x - nx * (e2Radius or 10), e2y - ny * (e2Radius or 10)
    end

    debugLog(string.format("Collision effects: e1(%.1f,%.1f)->(%.1f,%.1f), e2(%.1f,%.1f)->(%.1f,%.1f), normal(%.2f,%.2f)", 
        e1x, e1y, e1CollisionX, e1CollisionY, e2x, e2y, e2CollisionX, e2CollisionY, nx, ny))

    -- Determine if each entity has shields active
    local e1HasShield = CollisionEffects.hasShield(entity1)
    local e2HasShield = CollisionEffects.hasShield(entity2)

    -- Only create impact effects for the target entity (not projectiles)
    -- Determine which entity is the target (non-projectile)
    local targetEntity, targetX, targetY, targetRadius, targetCollisionX, targetCollisionY, targetHasShield
    
    if entity1.components and entity1.components.bullet then
        -- Entity1 is a projectile, create effects for entity2
        targetEntity = entity2
        targetX = e2x
        targetY = e2y
        targetRadius = e2Radius
        targetCollisionX = e2CollisionX
        targetCollisionY = e2CollisionY
        targetHasShield = e2HasShield
    else
        -- Entity1 is the target, create effects for entity1
        targetEntity = entity1
        targetX = e1x
        targetY = e1y
        targetRadius = e1Radius
        targetCollisionX = e1CollisionX
        targetCollisionY = e1CollisionY
        targetHasShield = e1HasShield
    end
    
    -- Create impact effect only for the target entity
    if targetHasShield then
        -- Shield impact effect
        if Effects.spawnImpact then
            local impactAngle = math.atan2(targetCollisionY - targetY, targetCollisionX - targetX)
            Effects.spawnImpact('shield', targetX, targetY, targetRadius, targetCollisionX, targetCollisionY, impactAngle, nil, 'collision', targetEntity, disableSound)
        elseif Effects.createImpactEffect then
            Effects.createImpactEffect(targetCollisionX, targetCollisionY, "shield_collision")
        end
    else
        -- Hull impact effect
        if Effects.spawnImpact then
            local impactAngle = math.atan2(targetCollisionY - targetY, targetCollisionX - targetX)
            Effects.spawnImpact('hull', targetX, targetY, targetRadius, targetCollisionX, targetCollisionY, impactAngle, nil, 'collision', targetEntity, disableSound)
        elseif Effects.createImpactEffect then
            Effects.createImpactEffect(targetCollisionX, targetCollisionY, "hull_collision")
        end
    end
end

function CollisionEffects.applyDamage(entity, damageValue, source)
    if not entity.components.health then return false end

    local health = entity.components.health
    -- Player invulnerability during dash
    if (entity.isPlayer or entity.isRemotePlayer) and (entity.iFrames or 0) > 0 then
        return (health.shield or 0) > 0
    end

    -- Handle damage value - could be a number or a table with min/max
    local incoming = damageValue
    if type(damageValue) == "table" then
        if damageValue.min and damageValue.max then
            incoming = math.random(damageValue.min, damageValue.max)
        elseif damageValue.value then
            incoming = damageValue.value
        else
            incoming = damageValue[1] or 1 -- fallback
        end
    end
    
    -- Validate damage value
    if not incoming or incoming <= 0 then
        return false -- No damage to apply
    end

    -- Apply global enemy damage multiplier (x2)
    if source and (source.isEnemy or (source.components and source.components.ai)) then
        incoming = incoming * 2
    end

    -- Check weapon type for damage modifiers
    local isLaserWeapon = false
    local isGunWeapon = false
    if source and source.components and source.components.bullet then
        local bullet = source.components.bullet
        if bullet.kind then
            if bullet.kind == "laser" or bullet.kind == "mining_laser" or bullet.kind == "salvaging_laser" then
                isLaserWeapon = true
            elseif bullet.kind == "bullet" then
                isGunWeapon = true
            end
        end
    end

    local hadShield = (health.shield or 0) > 0
    local shieldBefore = health.shield or 0
    
    -- Apply weapon-specific damage modifiers
    local shieldDamage, remainingDamage
    if isLaserWeapon then
        -- Laser weapons: 15% more damage to shields, half damage to hulls
        shieldDamage = math.min(shieldBefore, incoming * 1.15) -- 15% more damage to shields
        remainingDamage = incoming - (shieldDamage / 1.15) -- Convert back to original damage for hull calculation
        if remainingDamage > 0 then
            remainingDamage = remainingDamage * 0.5 -- Half damage to hull
        end
    elseif isGunWeapon then
        -- Gun weapons: half damage to shields, 15% more damage to hulls
        shieldDamage = math.min(shieldBefore, incoming * 0.5) -- Half damage to shields
        remainingDamage = incoming - (shieldDamage * 2) -- Convert back to original damage for hull calculation
        if remainingDamage > 0 then
            remainingDamage = remainingDamage * 1.15 -- 15% more damage to hull
        end
    else
        -- Normal damage calculation for other weapons
        shieldDamage = math.min(shieldBefore, incoming)
        remainingDamage = incoming - shieldDamage
    end

    local newShield = math.max(0, shieldBefore - shieldDamage)
    if newShield ~= shieldBefore then
        health.shield = newShield
        Radius.invalidateCache(entity)
    else
        health.shield = newShield
    end

    if remainingDamage > 0 then
        health.hp = math.max(0, (health.hp or 0) - remainingDamage)
    end

    -- Emit damage event
    local eventData = {
        entity = entity,
        damage = incoming,
        shieldDamage = shieldDamage,
        hullDamage = remainingDamage,
        hadShield = hadShield or (shieldDamage > 0),
        source = source
    }
    -- Mark recently damaged for overhead bars
    if shieldDamage > 0 or remainingDamage > 0 then
        if love and love.timer and love.timer.getTime then
            entity._hudDamageTime = love.timer.getTime()
        else
            entity._hudDamageTime = os.clock()
        end
    end

    if entity.isPlayer or entity.isRemotePlayer then
        Events.emit(Events.GAME_EVENTS.PLAYER_DAMAGED, eventData)
    else
        Events.emit(Events.GAME_EVENTS.ENTITY_DAMAGED, eventData)
    end

    if (health.hp or 0) <= 0 then
        -- Mark as dead and stash context for DestructionSystem to handle uniformly
        entity.dead = true
        entity._killedBy = source
        entity._finalDamage = damageValue
        
        -- Track weapon type for XP rewards
        if source and source.components and source.components.equipment then
            -- Find the turret that fired this projectile
            local bullet = source.components.bullet
            if bullet and bullet.slot then
                local turret = source:getTurretInSlot(bullet.slot)
                if turret and turret.type then
                    entity._killedByWeaponType = turret.type
                end
            end
        elseif source and source.type then
            -- Direct turret damage (beam weapons)
            entity._killedByWeaponType = source.type
        end
        
        -- Do NOT emit destruction here; DestructionSystem will emit exactly once
    end

    return hadShield or (shieldDamage > 0)
end

-- Function to enable/disable debug logging
function CollisionEffects.setDebugEnabled(enabled)
    DEBUG_COLLISION_EFFECTS = enabled
end

return CollisionEffects
