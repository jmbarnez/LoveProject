local Config = require("src.content.config")

local StationShields = {}

function StationShields.isStation(e)
  return (e and (e.tag == 'station' or (e.components and e.components.station))) or false
end

function StationShields.isFriendly(e)
  if not e then return false end
  if e.isPlayer or (e.components and e.components.player) then return true end
  if e.isFreighter or e.isFriendly then return true end
  if e.components and e.components.collidable and e.components.collidable.friendly then return true end
  return false
end

function StationShields.shouldIgnoreEntityCollision(a, b)
  if StationShields.isStation(a) and StationShields.isFriendly(b) then return true end
  if StationShields.isStation(b) and StationShields.isFriendly(a) then return true end
  return false
end

function StationShields.hasActiveShield(entity)
    -- Check for active shield component/state
    if entity.components and entity.components.health then
        local health = entity.components.health
        if health.shield and health.shield > 0 then
            return true
        end
    end

    -- Check for active shield ability (player)
    if entity.shieldChannel then
        return true
    end

    -- Check for shield renderer state (might indicate active shields)
    if entity.components and entity.components.renderable and entity.components.renderable.shield then
        return true
    end

    return false
end

function StationShields.checkStationSafeZone(bullet, target)
    local isPlayer = target.isPlayer or (target.components.player ~= nil)
    local isEnemyBullet = not ((bullet.components and bullet.components.collidable and bullet.components.collidable.friendly) or false)
    return isPlayer and (target.weaponsDisabled or false) and isEnemyBullet
end

function StationShields.handleStationShieldCollision(entity1, entity2)
    -- Special case: Instant death for enemies colliding with station shield bubbles
    local stationEntity = nil
    local enemyEntity = nil
    if StationShields.isStation(entity1) and StationShields.hasActiveShield(entity1) and entity2.isEnemy then
        stationEntity = entity1
        enemyEntity = entity2
    elseif StationShields.isStation(entity2) and StationShields.hasActiveShield(entity2) and entity1.isEnemy then
        stationEntity = entity2
        enemyEntity = entity1
    end

    -- Only apply instant death if hitting the shield bubble, not the station structure
    if enemyEntity and stationEntity then
        -- Calculate if the collision point is at shield radius distance
        local dx = enemyEntity.components.position.x - stationEntity.components.position.x
        local dy = enemyEntity.components.position.y - stationEntity.components.position.y
        local distSq = dx * dx + dy * dy
        local shieldRadius = stationEntity.shieldRadius or 200 -- Default shield radius if not set
        
        -- If collision is at shield perimeter (with some tolerance)
        if math.abs(math.sqrt(distSq) - shieldRadius) < 20 then
            -- Kill the enemy instantly
            enemyEntity.dead = true
            enemyEntity._killedBy = "station_shield"
            enemyEntity._finalDamage = enemyEntity.components.health.hp -- Mark as instant death
            -- Mark that this entity was killed by an unfriendly station to prevent drops
            enemyEntity._killedByUnfriendlyStation = true
            return true -- Indicates special handling occurred
        end
    end

    return false -- No special handling needed
end

return StationShields