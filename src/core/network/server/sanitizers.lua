local Sanitizers = {}

local function clamp01(value)
    return math.max(0, math.min(1, tonumber(value) or 0))
end

function Sanitizers.sanitisePlayerState(state)
    if type(state) ~= "table" then
        return {
            position = { x = 0, y = 0, angle = 0 },
            velocity = { x = 0, y = 0 },
            durability = { hull = 100, maxHull = 100, shield = 0, maxShield = 0, energy = 0, maxEnergy = 0 },
            shieldChannel = false
        }
    end

    local position = state.position or {}
    local velocity = state.velocity or {}
    local durability = state.durability or {}
    local thrusterState = state.thrusterState or {}
    local timestamp = tonumber(state.timestamp)
    local updateInterval = tonumber(state.updateInterval)

    return {
        name = state.name,
        position = {
            x = tonumber(position.x) or 0,
            y = tonumber(position.y) or 0,
            angle = tonumber(position.angle) or 0
        },
        velocity = {
            x = tonumber(velocity.x) or 0,
            y = tonumber(velocity.y) or 0
        },
        durability = {
            hull = tonumber(durability.hull) or 100,
            maxHull = tonumber(durability.maxHull) or 100,
            shield = tonumber(durability.shield) or 0,
            maxShield = tonumber(durability.maxShield) or 0,
            energy = tonumber(durability.energy) or 0,
            maxEnergy = tonumber(durability.maxEnergy) or 0
        },
        shieldChannel = state.shieldChannel == true,
        thrusterState = {
            isThrusting = thrusterState.isThrusting == true,
            forward = clamp01(thrusterState.forward),
            reverse = clamp01(thrusterState.reverse),
            strafeLeft = clamp01(thrusterState.strafeLeft),
            strafeRight = clamp01(thrusterState.strafeRight),
            boost = clamp01(thrusterState.boost)
        },
        timestamp = timestamp,
        updateInterval = updateInterval
    }
end

local function sanitiseWorldExtras(extra)
    if type(extra) ~= "table" then
        return nil
    end

    local sanitised = {}
    for key, value in pairs(extra) do
        local valueType = type(value)
        if valueType == "number" or valueType == "string" or valueType == "boolean" then
            sanitised[key] = value
        end
    end

    if next(sanitised) then
        return sanitised
    end

    return nil
end

local function sanitiseWorldEntry(entry)
    if type(entry) ~= "table" then
        return nil
    end

    if not entry.kind or not entry.id then
        return nil
    end

    local x = tonumber(entry.x)
    local y = tonumber(entry.y)
    local angle = entry.angle

    if (not x or not y) and type(entry.position) == "table" then
        x = tonumber(entry.position.x) or x
        y = tonumber(entry.position.y) or y
        angle = angle ~= nil and angle or entry.position.angle
    end

    if not x or not y then
        return nil
    end

    local sanitised = {
        kind = tostring(entry.kind),
        id = tostring(entry.id),
        x = x,
        y = y
    }

    if angle ~= nil then
        sanitised.angle = tonumber(angle) or 0
    end

    local extra = sanitiseWorldExtras(entry.extra)
    if extra then
        sanitised.extra = extra
    end

    return sanitised
end

function Sanitizers.sanitiseWorldSnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return nil
    end

    local width = tonumber(snapshot.width)
    local height = tonumber(snapshot.height)

    local sanitised = {
        entities = {}
    }

    if width ~= nil then
        sanitised.width = width
    end

    if height ~= nil then
        sanitised.height = height
    end

    if type(snapshot.entities) == "table" then
        for _, entry in ipairs(snapshot.entities) do
            local sanitisedEntry = sanitiseWorldEntry(entry)
            if sanitisedEntry then
                sanitised.entities[#sanitised.entities + 1] = sanitisedEntry
            end
        end
    end

    return sanitised
end

local function sanitiseAiTarget(target)
    if target == nil then
        return nil
    end

    local targetId = nil
    local targetType = nil

    if type(target) == "table" then
        if target.isPlayer and target.id then
            targetId = tostring(target.id)
            targetType = "player"
        elseif target.isRemotePlayer and target.remotePlayerId then
            targetId = tostring(target.remotePlayerId)
            targetType = "remote_player"
        elseif target.remoteEnemyId then
            targetId = tostring(target.remoteEnemyId)
            targetType = "enemy"
        elseif target.id then
            targetId = tostring(target.id)
            if type(target.type) == "string" then
                targetType = target.type
            end
        end
    elseif type(target) == "number" or type(target) == "string" then
        targetId = tostring(target)
    end

    if not targetId then
        return nil
    end

    local sanitised = { id = targetId }
    if targetType then
        sanitised.type = targetType
    end

    return sanitised
end

function Sanitizers.sanitiseEnemySnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return {}
    end

    local sanitised = {}
    for _, enemy in ipairs(snapshot) do
        if type(enemy) == "table" and enemy.id and enemy.type then
            local sanitisedEnemy = {
                id = tostring(enemy.id),
                type = tostring(enemy.type),
                position = {
                    x = tonumber(enemy.position and enemy.position.x) or 0,
                    y = tonumber(enemy.position and enemy.position.y) or 0,
                    angle = tonumber(enemy.position and enemy.position.angle) or 0
                },
                velocity = {
                    x = tonumber(enemy.velocity and enemy.velocity.x) or 0,
                    y = tonumber(enemy.velocity and enemy.velocity.y) or 0
                }
            }

            if enemy.durability or enemy.hull then
                local durability = enemy.durability or enemy.hull
                sanitisedEnemy.durability = {
                    hull = tonumber(durability.hull) or 100,
                    maxHull = tonumber(durability.maxHull) or 100,
                    shield = tonumber(durability.shield) or 0,
                    maxShield = tonumber(durability.maxShield) or 0,
                    energy = tonumber(durability.energy) or 0,
                    maxEnergy = tonumber(durability.maxEnergy) or 0
                }
            end

            if enemy.ai then
                local aiState = {
                    state = tostring(enemy.ai.state) or "patrolling"
                }

                local target = sanitiseAiTarget(enemy.ai.target)
                if target then
                    aiState.target = target
                end

                sanitisedEnemy.ai = aiState
            end

            sanitised[#sanitised + 1] = sanitisedEnemy
        end
    end

    return sanitised
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

    if type(damage) ~= "table" then
        local numeric = tonumber(damage)
        if numeric then
            return {
                min = numeric,
                max = numeric,
                value = numeric
            }
        end
        return nil
    end

    local sanitised = {}

    sanitised.min = toNumber(damage.min or damage[1])
    sanitised.max = toNumber(damage.max or damage[2])
    sanitised.value = toNumber(damage.value)
    sanitised.damagePerSecond = toNumber(damage.damagePerSecond or damage.dps)
    sanitised.skill = damage.skill

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

function Sanitizers.sanitiseProjectileSnapshot(snapshot)
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
                kind = projectile.kind or "bullet",
                timed_life = projectile.timed_life or nil
            }

            local damageData = sanitiseDamageData(projectile.damage)
            if damageData then
                if damageData.min ~= nil then damageData.min = tonumber(damageData.min) or damageData.min end
                if damageData.max ~= nil then damageData.max = tonumber(damageData.max) or damageData.max end
                if damageData.value ~= nil then damageData.value = tonumber(damageData.value) or damageData.value end
                if damageData.damagePerSecond ~= nil then
                    damageData.damagePerSecond = tonumber(damageData.damagePerSecond) or damageData.damagePerSecond
                end
                sanitisedProjectile.damage = damageData
            end

            if projectile.timed_life then
                sanitisedProjectile.timed_life = {
                    duration = tonumber(projectile.timed_life.duration) or 2.0,
                    elapsed = tonumber(projectile.timed_life.elapsed) or 0
                }
            end

            sanitised[#sanitised + 1] = sanitisedProjectile
        end
    end

    return sanitised
end

return Sanitizers

