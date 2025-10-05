local Effects = require("src.systems.effects")
local Events = require("src.core.events")
local Config = require("src.content.config")
local StationShields = require("src.systems.collision.station_shields")
local Radius = require("src.systems.collision.radius")

local CollisionEffects = {}

-- Check if entity is a player with active shields
local function get_health(entity)
    if not entity or not entity.components then
        return nil
    end
    return entity.components.health
end

function CollisionEffects.isPlayerShieldActive(entity)
    if not entity then return false end

    local isPlayer = entity.isPlayer or (entity.components and entity.components.player ~= nil)
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

    -- Calculate collision points for each entity
    local e1CollisionX = e1x - nx * e1Radius
    local e1CollisionY = e1y - ny * e1Radius
    local e2CollisionX = e2x + nx * e2Radius
    local e2CollisionY = e2y + ny * e2Radius

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
    if entity.isPlayer and (entity.iFrames or 0) > 0 then
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
    
    -- Debug logging for shield collision detection
    if entity.isPlayer or entity.isRemotePlayer then
        Log.info("CollisionEffects.applyDamage: Player shield data - shield:", shieldBefore, "maxShield:", health.maxShield, "hadShield:", hadShield)
    end
    
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

    if shieldDamage > 0 then
        Effects.addDamageNumber(entity.components.position.x, entity.components.position.y, math.floor(shieldDamage), "shield")
    end

    local newShield = math.max(0, shieldBefore - shieldDamage)
    if newShield ~= shieldBefore then
        health.shield = newShield
        Radius.invalidateCache(entity)
    else
        health.shield = newShield
    end

    if remainingDamage > 0 then
        Effects.addDamageNumber(entity.components.position.x, entity.components.position.y, math.floor(remainingDamage), "hull")
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
    -- Mark recently damaged by player for enemy HUD bars
    if source and (source.isPlayer or (source.components and source.components.player ~= nil)) then
        entity._hudDamageTime = love.timer.getTime()
    end

    if entity.isPlayer then
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
