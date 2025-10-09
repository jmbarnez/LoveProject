local Effects = require("src.systems.effects")
local Events = require("src.core.events")
local Config = require("src.content.config")
local StationShields = require("src.systems.collision.station_shields")
local Radius = require("src.systems.collision.radius")

local CollisionEffects = {}

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
function CollisionEffects.createCollisionEffects(entity1, entity2, e1x, e1y, e2x, e2y, nx, ny, e1Radius, e2Radius)
    if not Effects then return end

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
    local e1CollisionX, e1CollisionY, e2CollisionX, e2CollisionY

    -- Check if entities have polygon collision shapes for more precise collision points
    local e1Collidable = entity1.components and entity1.components.collidable
    local e2Collidable = entity2.components and entity2.components.collidable

    if e1Collidable and e1Collidable.shape == "polygon" and e1Collidable.vertices then
        -- For polygon shapes, find the closest point on the polygon to the collision normal
        local closestPoint = CollisionEffects.findClosestPointOnPolygon(e1x, e1y, nx, ny, e1Collidable.vertices, entity1.components.position.angle or 0)
        e1CollisionX, e1CollisionY = closestPoint.x, closestPoint.y
    elseif e1Radius and e1Radius > 0 then
        -- Use the collision normal to position the FX at the surface of the entity
        e1CollisionX = e1x + nx * e1Radius
        e1CollisionY = e1y + ny * e1Radius
    else
        -- Fallback to midpoint if radius information is unavailable
        e1CollisionX = (e1x + e2x) * 0.5
        e1CollisionY = (e1y + e2y) * 0.5
    end

    if e2Collidable and e2Collidable.shape == "polygon" and e2Collidable.vertices then
        -- For polygon shapes, find the closest point on the polygon to the collision normal
        local closestPoint = CollisionEffects.findClosestPointOnPolygon(e2x, e2y, -nx, -ny, e2Collidable.vertices, entity2.components.position.angle or 0)
        e2CollisionX, e2CollisionY = closestPoint.x, closestPoint.y
    elseif e2Radius and e2Radius > 0 then
        -- Use the opposite direction of the normal for the second entity
        e2CollisionX = e2x - nx * e2Radius
        e2CollisionY = e2y - ny * e2Radius
    else
        e2CollisionX = (e1x + e2x) * 0.5
        e2CollisionY = (e1y + e2y) * 0.5
    end

    -- Determine if each entity has shields active
    local e1HasShield = CollisionEffects.hasShield(entity1)
    local e2HasShield = CollisionEffects.hasShield(entity2)

    -- Create appropriate impact effects for entity1
    if e1HasShield then
        -- Shield impact effect
        if Effects.spawnImpact then
            local impactAngle = math.atan2(e1CollisionY - e1y, e1CollisionX - e1x)
            Effects.spawnImpact('shield', e1x, e1y, e1Radius, e1CollisionX, e1CollisionY, impactAngle, nil, 'collision', entity1)
        elseif Effects.createImpactEffect then
            Effects.createImpactEffect(e1CollisionX, e1CollisionY, "shield_collision")
        end
    else
        -- Hull impact effect
        if Effects.spawnImpact then
            local impactAngle = math.atan2(e1CollisionY - e1y, e1CollisionX - e1x)
            Effects.spawnImpact('hull', e1x, e1y, e1Radius, e1CollisionX, e1CollisionY, impactAngle, nil, 'collision', entity1)
        elseif Effects.createImpactEffect then
            Effects.createImpactEffect(e1CollisionX, e1CollisionY, "hull_collision")
        end
    end

    -- Create appropriate impact effects for entity2
    if e2HasShield then
        -- Shield impact effect
        if Effects.spawnImpact then
            local impactAngle = math.atan2(e2CollisionY - e2y, e2CollisionX - e2x)
            Effects.spawnImpact('shield', e2x, e2y, e2Radius, e2CollisionX, e2CollisionY, impactAngle, nil, 'collision', entity2)
        elseif Effects.createImpactEffect then
            Effects.createImpactEffect(e2CollisionX, e2CollisionY, "shield_collision")
        end
    else
        -- Hull impact effect
        if Effects.spawnImpact then
            local impactAngle = math.atan2(e2CollisionY - e2y, e2CollisionX - e2x)
            Effects.spawnImpact('hull', e2x, e2y, e2Radius, e2CollisionX, e2CollisionY, impactAngle, nil, 'collision', entity2)
        elseif Effects.createImpactEffect then
            Effects.createImpactEffect(e2CollisionX, e2CollisionY, "hull_collision")
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

return CollisionEffects
