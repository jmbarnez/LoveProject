local EntityFactory = require("src.templates.entity_factory")
local Content = require("src.content.content")
local TargetUtils = require("src.core.target_utils")

local NetworkWeaponHandler = {}

local DEFAULT_PROJECTILE_DAMAGE_MIN = 1
local DEFAULT_PROJECTILE_DAMAGE_MAX = 60
local DEFAULT_BEAM_DPS = 40
local DEFAULT_BEAM_LENGTH = 1600
local MAX_BEAM_LENGTH = 3000

local function sanitiseNumber(value, fallback, minValue, maxValue)
    local number = tonumber(value)
    if not number or number ~= number then
        number = fallback
    end
    if minValue ~= nil then
        number = math.max(minValue, number)
    end
    if maxValue ~= nil then
        number = math.min(maxValue, number)
    end
    return number
end

local function normaliseTurretId(turretId)
    if type(turretId) == "table" then
        return turretId.id or turretId.turretId or turretId.type
    end
    return turretId
end

local function resolveTurretData(player, request)
    local turretInstance = nil
    if player and player.getTurretInSlot and request and request.turretSlot then
        turretInstance = player:getTurretInSlot(request.turretSlot)
    end

    local turretId = request and normaliseTurretId(request.turretId)
    local turretDef = nil
    if type(turretId) == "string" then
        turretDef = Content.getTurret(turretId)
    end

    return turretInstance, turretDef, turretId
end

local function buildDamageConfig(turretInstance, turretDef)
    local minDamage
    local maxDamage
    local skillId

    if turretInstance and turretInstance.damage_range then
        minDamage = turretInstance.damage_range.min
        maxDamage = turretInstance.damage_range.max
        skillId = turretInstance.skillId
    elseif turretDef and turretDef.damage_range then
        minDamage = turretDef.damage_range.min
        maxDamage = turretDef.damage_range.max
        skillId = turretDef.skillId
    end

    if not minDamage or not maxDamage then
        local dps
        local cycle = 1
        if turretInstance and turretInstance.damagePerSecond then
            dps = turretInstance.damagePerSecond
            cycle = turretInstance.cycle or 1
            skillId = skillId or turretInstance.skillId
        elseif turretDef and turretDef.damagePerSecond then
            dps = turretDef.damagePerSecond
            cycle = turretDef.cycle or 1
            skillId = skillId or turretDef.skillId
        end

        if dps then
            local approx = math.max(0, dps * math.max(0.1, cycle))
            minDamage = approx * 0.75
            maxDamage = approx * 1.25
        end
    end

    minDamage = sanitiseNumber(minDamage, DEFAULT_PROJECTILE_DAMAGE_MIN, 0, DEFAULT_PROJECTILE_DAMAGE_MAX)
    maxDamage = sanitiseNumber(maxDamage, DEFAULT_PROJECTILE_DAMAGE_MAX, minDamage, DEFAULT_PROJECTILE_DAMAGE_MAX)

    local damageConfig = {
        min = minDamage,
        max = maxDamage,
    }
    if skillId then
        damageConfig.skill = skillId
    end

    return damageConfig
end

local function buildBeamDamagePerSecond(turretInstance, turretDef)
    local dps
    if turretInstance and turretInstance.damagePerSecond then
        dps = turretInstance.damagePerSecond
    elseif turretDef and turretDef.damagePerSecond then
        dps = turretDef.damagePerSecond
    elseif turretInstance and turretInstance.damage_range then
        dps = (turretInstance.damage_range.min + turretInstance.damage_range.max) * 0.5
    elseif turretDef and turretDef.damage_range then
        dps = (turretDef.damage_range.min + turretDef.damage_range.max) * 0.5
    end

    return sanitiseNumber(dps, DEFAULT_BEAM_DPS, 0, DEFAULT_BEAM_DPS)
end

local function sanitiseAdditionalEffects(effects, turretInstance, turretDef)
    if type(effects) ~= "table" then
        return nil
    end

    local sanitised = {}
    for _, effect in ipairs(effects) do
        if type(effect) == "table" and effect.type == "homing" then
            local maxRange = DEFAULT_BEAM_LENGTH
            if turretInstance and turretInstance.maxRange then
                maxRange = turretInstance.maxRange
            elseif turretDef and turretDef.maxRange then
                maxRange = turretDef.maxRange
            end

            local turnRate
            if turretInstance and turretInstance.missileTurnRate then
                turnRate = turretInstance.missileTurnRate
            elseif turretDef and turretDef.missileTurnRate then
                turnRate = turretDef.missileTurnRate
            end

            local speed
            if turretInstance then
                if turretInstance.projectile and turretInstance.projectile.physics then
                    speed = turretInstance.projectile.physics.speed
                elseif turretInstance.projectileSpeed then
                    speed = turretInstance.projectileSpeed
                end
            end
            if not speed and turretDef and type(turretDef.projectile) == "table" and turretDef.projectile.physics then
                speed = turretDef.projectile.physics.speed
            end

            local sanitisedEffect = {
                type = "homing",
                turnRate = sanitiseNumber(effect.turnRate or turnRate, turnRate or 0, 0, (turnRate or 0) > 0 and turnRate or 5),
                maxRange = sanitiseNumber(effect.maxRange, maxRange, 0, maxRange),
                reacquireDelay = sanitiseNumber(effect.reacquireDelay, 0.1, 0, 5),
                speed = sanitiseNumber(effect.speed or speed, speed or 0, 0, speed or 1200),
            }

            sanitised[#sanitised + 1] = sanitisedEffect
        end
    end

    if #sanitised == 0 then
        return nil
    end

    return sanitised
end

local function applyAdditionalEffectContext(effects, turretInstance, turretDef, player, world)
    if type(effects) ~= "table" or #effects == 0 then
        return
    end

    if not world then
        return
    end

    for _, effect in ipairs(effects) do
        if type(effect) == "table" and effect.type == "homing" then
            effect.world = world

            if not effect.speed or effect.speed <= 0 then
                local speed
                if turretInstance then
                    if turretInstance.projectile and turretInstance.projectile.physics then
                        speed = turretInstance.projectile.physics.speed
                    elseif turretInstance.projectileSpeed then
                        speed = turretInstance.projectileSpeed
                    end
                end

                if not speed and turretDef and type(turretDef.projectile) == "table" and turretDef.projectile.physics then
                    speed = turretDef.projectile.physics.speed
                end

                effect.speed = speed or 1200
            end

            local target = turretInstance and turretInstance.lockOnTarget
            if target and TargetUtils.isEnemyTarget(target, player) then
                effect.target = target
            else
                effect.target = nil
            end
        end
    end
end

local function handleProjectileRequest(state, request, playerId, resolvePlayerEntity)
    local world = state.world
    if not world or not request then
        return
    end

    local player = resolvePlayerEntity(state, playerId)
    if not player then
        return
    end

    local turretInstance, turretDef, turretId = resolveTurretData(player, request)

    local projectileId = request.projectileId
    if turretInstance then
        projectileId = turretInstance.projectileId
            or (turretInstance.projectile and turretInstance.projectile.id)
            or projectileId
    elseif turretDef then
        if type(turretDef.projectile) == "table" then
            projectileId = turretDef.projectile.id or projectileId
        elseif type(turretDef.projectile) == "string" then
            projectileId = turretDef.projectile
        end
    end

    if not projectileId then
        return
    end

    local projectileKind = "bullet"
    if turretInstance and turretInstance.kind then
        projectileKind = turretInstance.kind
    elseif turretDef and turretDef.type then
        projectileKind = turretDef.type
    elseif request.kind then
        projectileKind = request.kind
    end

    local damageConfig = buildDamageConfig(turretInstance, turretDef)
    local additionalEffects = sanitiseAdditionalEffects(request.additionalEffects, turretInstance, turretDef)
    applyAdditionalEffectContext(additionalEffects, turretInstance, turretDef, player, world)

    local playerPos = player.components and player.components.position
    local startX = playerPos and playerPos.x or 0
    local startY = playerPos and playerPos.y or 0

    local angle = sanitiseNumber(request.angle, 0, -math.pi * 2, math.pi * 2)

    local sourcePlayerId = player.remotePlayerId or playerId
    local sourceShipId = player.shipId or (player.ship and player.ship.id)
    local sourceTurretSlot = request.turretSlot
    local sourceTurretType = turretInstance and turretInstance.kind or request.turretType

    local extraConfig = {
        angle = angle,
        friendly = true,
        damage = damageConfig,
        kind = projectileKind,
        additionalEffects = additionalEffects,
        source = player,
        sourcePlayerId = sourcePlayerId,
        sourceShipId = sourceShipId,
        sourceTurretSlot = sourceTurretSlot,
        sourceTurretId = turretId,
        sourceTurretType = sourceTurretType,
    }

    if turretInstance and turretInstance.impact and not additionalEffects then
        extraConfig.impact = turretInstance.impact
    end

    local projectile = EntityFactory.create(
        "projectile",
        projectileId,
        startX,
        startY,
        extraConfig,
        world
    )

    if projectile then
        world:addEntity(projectile)
    end
end

local function handleBeamRequest(state, request, playerId, resolvePlayerEntity)
    local world = state.world
    if not world or not request then
        return
    end

    local player = resolvePlayerEntity(state, playerId)
    if not player then
        return
    end

    local turretInstance, turretDef = resolveTurretData(player, request)

    local maxRange = DEFAULT_BEAM_LENGTH
    if turretInstance and turretInstance.maxRange then
        maxRange = turretInstance.maxRange
    elseif turretDef and turretDef.maxRange then
        maxRange = turretDef.maxRange
    end
    maxRange = math.min(maxRange, MAX_BEAM_LENGTH)

    local playerPos = player.components and player.components.position
    local startX = playerPos and playerPos.x or 0
    local startY = playerPos and playerPos.y or 0

    local angle = sanitiseNumber(request.angle, 0, -math.pi * 2, math.pi * 2)
    local beamLength = sanitiseNumber(request.beamLength, maxRange, 0, maxRange)

    local endX = startX + math.cos(angle) * beamLength
    local endY = startY + math.sin(angle) * beamLength

    player.remoteBeamActive = true
    player.remoteBeamStartX = startX
    player.remoteBeamStartY = startY
    player.remoteBeamEndX = endX
    player.remoteBeamEndY = endY
    player.remoteBeamAngle = angle
    player.remoteBeamLength = beamLength
    player.remoteBeamStartTime = love.timer and love.timer.getTime() or os.clock()

    local BeamWeapons = require("src.systems.turret.beam_weapons")
    local hitTarget, hitX, hitY = BeamWeapons.performLaserHitscan(startX, startY, endX, endY, { owner = player }, world)

    if hitTarget then
        local damagePerSecond = buildBeamDamagePerSecond(turretInstance, turretDef)
        local beamDuration = sanitiseNumber(request.deltaTime, 0.16, 0, 0.25)

        local damageAmount = damagePerSecond * beamDuration
        if damageAmount > 0 then
            local damageMeta
            if turretInstance and turretInstance.damage_range then
                damageMeta = {
                    min = turretInstance.damage_range.min,
                    max = turretInstance.damage_range.max,
                    value = damageAmount,
                    skill = turretInstance.skillId,
                    damagePerSecond = damagePerSecond
                }
            elseif turretDef and turretDef.damage_range then
                damageMeta = {
                    min = turretDef.damage_range.min,
                    max = turretDef.damage_range.max,
                    value = damageAmount,
                    skill = turretDef.skillId,
                    damagePerSecond = damagePerSecond
                }
            else
                damageMeta = { min = 1, max = 2, value = damageAmount, damagePerSecond = damagePerSecond }
            end
            local skillId = nil
            if turretInstance and turretInstance.skillId then
                skillId = turretInstance.skillId
            elseif turretDef and turretDef.skillId then
                skillId = turretDef.skillId
            end

            BeamWeapons.applyLaserDamage(hitTarget, damageAmount, player, skillId, damageMeta)
        end

        local TurretEffects = require("src.systems.turret.effects")
        TurretEffects.createImpactEffect({ owner = player }, hitX, hitY, hitTarget, "laser")
    end
end

local function handleUtilityBeamRequest(state, request, playerId, resolvePlayerEntity)
    local world = state.world
    if not world or not request then
        return
    end

    local player = resolvePlayerEntity(state, playerId)
    if not player then
        return
    end

    local beamLength = request.beamLength or 100
    local startX = request.position and request.position.x or 0
    local startY = request.position and request.position.y or 0
    local endX = startX + math.cos(request.angle or 0) * beamLength
    local endY = startY + math.sin(request.angle or 0) * beamLength

    player.remoteUtilityBeamActive = true
    player.remoteUtilityBeamType = request.beamType
    player.remoteUtilityBeamStartX = startX
    player.remoteUtilityBeamStartY = startY
    player.remoteUtilityBeamEndX = endX
    player.remoteUtilityBeamEndY = endY
    player.remoteUtilityBeamAngle = request.angle or 0
    player.remoteUtilityBeamLength = beamLength
    player.remoteUtilityBeamStartTime = love.timer and love.timer.getTime() or os.clock()
end

function NetworkWeaponHandler.handle(state, request, playerId, resolvePlayerEntity)
    if not request then
        return
    end

    if request.type == "beam_weapon_fire_request" then
        handleBeamRequest(state, request, playerId, resolvePlayerEntity)
    elseif request.type == "utility_beam_weapon_fire_request" then
        handleUtilityBeamRequest(state, request, playerId, resolvePlayerEntity)
    else
        handleProjectileRequest(state, request, playerId, resolvePlayerEntity)
    end
end

return NetworkWeaponHandler

