local Content = require("src.content.content")
local TurretEffects = require("src.systems.turret.effects")
local Skills = require("src.core.skills")
local Log = require("src.core.log")
local BeamWeapons = require("src.systems.turret.beam_weapons")
local TargetUtils = require("src.core.target_utils")

local ProjectileWeapons = {}
local PLAYER_LOCK_ANGLE_TOLERANCE = math.rad(25)
local PLAYER_LOCK_HOLD_TOLERANCE_SCALE = 1.5
local LOCK_PROGRESS_DECAY_MULT = 2.0

local function buildProjectileMetadata(turret)
    if not turret or not turret.owner then
        return {}
    end

    local owner = turret.owner
    local metadata = {
        playerId = owner.remotePlayerId or owner.playerId or owner.id,
        shipId = owner.shipId or (owner.ship and owner.ship.id) or nil,
        turretSlot = turret.slot,
        turretId = turret.id,
        turretType = turret.kind or turret.type,
    }

    return metadata
end

-- Helper function to send weapon fire request to host
local function sendWeaponFireRequest(turret, sx, sy, angle, projectileId, damageConfig, additionalEffects)
    local NetworkSession = require("src.core.network.session")
    local networkManager = NetworkSession.getManager()
    
    if networkManager and networkManager:isMultiplayer() and not networkManager:isHost() then
        -- Client: send weapon fire request to host
        local metadata = buildProjectileMetadata(turret)
        local request = {
            type = "weapon_fire_request",
            turretId = turret.id or tostring(turret),
            position = { x = sx, y = sy },
            angle = angle,
            projectileId = projectileId,
            damageConfig = damageConfig,
            additionalEffects = additionalEffects,
            ownerId = turret.owner and turret.owner.id or nil,
            playerId = metadata.playerId,
            shipId = metadata.shipId,
            turretSlot = metadata.turretSlot,
            turretType = metadata.turretType,
        }
        
        -- Send via network manager
        if networkManager.sendWeaponFireRequest then
            local json = require("src.libs.json")
            networkManager:sendWeaponFireRequest(request)
        end
        return true
    end
    
    return false
end

local function isTargetValid(target, owner)
    if not target or target.dead or not target.components or not target.components.position then
        return false
    end

    if not owner then
        return true
    end

    return TargetUtils.isEnemyTarget(target, owner)
end

local function angleDiff(a, b)
    local diff = math.atan2(math.sin(a - b), math.cos(a - b))
    return math.abs(diff)
end

local function getTurretWorldPosition(turret)
    local Turret = require("src.systems.turret.core")
    return Turret.getTurretWorldPosition(turret)
end

local function findNearestEnemyTarget(turret, world, sx, sy, maxRangeSq)
    if not turret or not world or not world.get_entities_with_components then
        return nil
    end

    local owner = turret.owner
    if not owner or owner.dead or not owner.components then
        return nil
    end

    if not sx or not sy then
        sx, sy = getTurretWorldPosition(turret)
    end

    maxRangeSq = maxRangeSq or math.huge

    local nearestTarget
    local nearestDistSq = math.huge
    local entities = world:get_entities_with_components("position")
    for _, entity in ipairs(entities) do
        if entity ~= owner and isTargetValid(entity, owner) then
            local pos = entity.components.position
            local dx = pos.x - sx
            local dy = pos.y - sy
            local distSq = dx * dx + dy * dy
            if distSq <= maxRangeSq and distSq < nearestDistSq then
                nearestTarget = entity
                nearestDistSq = distSq
            end
        end
    end

    return nearestTarget
end

local function findLockCandidate(turret, world, sx, sy, aimAngle, angleTolerance, maxRangeSq)
    if not world or not world.get_entities_with_components then
        return nil
    end

    local owner = turret.owner
    if not owner then
        return nil
    end

    local bestTarget
    local bestScore = math.huge
    local entities = world:get_entities_with_components("position")

    for _, entity in ipairs(entities) do
        if entity ~= owner and isTargetValid(entity, owner) then
            local pos = entity.components.position
            local dx = pos.x - sx
            local dy = pos.y - sy
            local distSq = dx * dx + dy * dy
            if distSq <= maxRangeSq then
                local targetAngle = math.atan2(dy, dx)
                local diff = angleDiff(targetAngle, aimAngle)
                if diff <= angleTolerance then
                    local score = diff * 1000 + distSq
                    if score < bestScore then
                        bestScore = score
                        bestTarget = entity
                    end
                end
            end
        end
    end
    return bestTarget
end

local function getLockDuration(turret)
    if turret.lockOnDuration and turret.lockOnDuration > 0 then
        return turret.lockOnDuration
    end

    local owner = turret.owner
    if owner then
        local shipConfig = owner.ship or owner.config
        if shipConfig and shipConfig.targeting and shipConfig.targeting.lockTime and shipConfig.targeting.lockTime > 0 then
            turret.lockOnDuration = shipConfig.targeting.lockTime
            return turret.lockOnDuration
        end

        if owner.targeting and owner.targeting.lockTime and owner.targeting.lockTime > 0 then
            turret.lockOnDuration = owner.targeting.lockTime
            return turret.lockOnDuration
        end
    end

    turret.lockOnDuration = 1.5
    return turret.lockOnDuration
end

local function updatePlayerLockState(turret, dt, candidate, sx, sy, aimAngle, maxRangeSq)
    local lockDuration = math.max(getLockDuration(turret), 0.001)
    local currentTarget = turret.lockOnTarget

    if candidate and not isTargetValid(candidate, turret.owner) then
        candidate = nil
    end

    if not candidate and currentTarget and isTargetValid(currentTarget, turret.owner) then
        local pos = currentTarget.components.position
        local dx = pos.x - sx
        local dy = pos.y - sy
        local distSq = dx * dx + dy * dy
        if distSq <= maxRangeSq then
            local diff = angleDiff(math.atan2(dy, dx), aimAngle)
            local tolerance = (turret.lockOnAngleTolerance or PLAYER_LOCK_ANGLE_TOLERANCE) * PLAYER_LOCK_HOLD_TOLERANCE_SCALE
            if diff <= tolerance then
                candidate = currentTarget
            end
        end
    end

    if candidate then
        if candidate ~= currentTarget then
            turret.lockOnTarget = candidate
            turret.lockOnProgress = 0
            turret.isLockedOn = false
        end

        local progress = math.max(0, turret.lockOnProgress or 0)
        if turret.isLockedOn then
            turret.lockOnProgress = 1
        else
            progress = progress + dt / lockDuration
            if progress >= 1 then
                progress = 1
                turret.isLockedOn = true
            end
            turret.lockOnProgress = progress
        end
    else
        local progress = math.max(0, turret.lockOnProgress or 0)
        progress = progress - (dt / lockDuration) * LOCK_PROGRESS_DECAY_MULT
        if progress <= 0 then
            turret.lockOnProgress = 0
            turret.lockOnTarget = nil
            turret.isLockedOn = false
        else
            turret.lockOnProgress = progress
            turret.isLockedOn = false
        end
    end
end

local function computeMissileAim(turret, target)
    local sx, sy = getTurretWorldPosition(turret)
    local angle = 0

    if target and target.components and target.components.position then
        local tx = target.components.position.x
        local ty = target.components.position.y
        local dx = tx - sx
        local dy = ty - sy
        angle = math.atan2(dy, dx)
    elseif turret.owner and turret.owner.cursorWorldPos then
        local cursorX = turret.owner.cursorWorldPos.x
        local cursorY = turret.owner.cursorWorldPos.y
        local dx = cursorX - sx
        local dy = cursorY - sy
        angle = math.atan2(dy, dx)
    elseif turret.owner and turret.owner.components and turret.owner.components.position then
        angle = turret.owner.components.position.angle
    end

    return sx, sy, angle
end

function ProjectileWeapons.updateMissileLockState(turret, dt, target, world)
    if not turret or turret.kind ~= "missile" then
        return
    end

    turret.lockOnProgress = turret.lockOnProgress or 0
    turret.isLockedOn = turret.isLockedOn or false

    local sx, sy, aimAngle = computeMissileAim(turret, target)
    turret.currentAimAngle = aimAngle

    local maxRangeSq = math.huge
    if turret.maxRange and turret.maxRange > 0 then
        maxRangeSq = turret.maxRange * turret.maxRange
    end

    local owner = turret.owner
    if owner and owner.isPlayer then
        local tolerance = turret.lockOnAngleTolerance or PLAYER_LOCK_ANGLE_TOLERANCE
        local candidate = findLockCandidate(turret, world, sx, sy, aimAngle, tolerance, maxRangeSq)
        updatePlayerLockState(turret, dt, candidate, sx, sy, aimAngle, maxRangeSq)
    else
        if target and isTargetValid(target, owner) then
            turret.lockOnTarget = target
        else
            turret.lockOnTarget = findNearestEnemyTarget(turret, world, sx, sy, maxRangeSq)
        end

        if turret.lockOnTarget then
            turret.lockOnProgress = 1
            turret.isLockedOn = true
        else
            turret.lockOnProgress = 0
            turret.isLockedOn = false
        end
    end
end

-- Handle gun turret firing (bullets, shells, etc.)
function ProjectileWeapons.updateGunTurret(turret, dt, target, locked, world)
    if locked or not turret:canFire() then
        return
    end


    -- Get turret world position first for accurate aiming
    local Turret = require("src.systems.turret.core")
    local sx, sy = Turret.getTurretWorldPosition(turret)

    -- Aim at target if available, otherwise use cursor or ship facing
    local angle = 0
    if target and target.components and target.components.position then
        -- For automatic firing (AI), aim from turret position to target
        local tx = target.components.position.x
        local ty = target.components.position.y
        local dx = tx - sx
        local dy = ty - sy
        angle = math.atan2(dy, dx)
    elseif turret.owner.cursorWorldPos then
        -- For manual firing, use the cursor direction from turret position
        local cursorX, cursorY = turret.owner.cursorWorldPos.x, turret.owner.cursorWorldPos.y
        local dx = cursorX - sx
        local dy = cursorY - sy
        angle = math.atan2(dy, dx)
    else
        -- Fallback to ship facing if no target or cursor available
        angle = turret.owner.components.position.angle
    end
    -- Get projectile speed from embedded definition or fallback to turret setting
    local projSpeed = 2400 -- Default fallback
    if turret.projectile and type(turret.projectile) == "table" and turret.projectile.physics then
        projSpeed = turret.projectile.physics.speed
    elseif turret.projectileSpeed then
        projSpeed = turret.projectileSpeed
    end

    -- Store the current aim so muzzle calculations can align with turret visuals.
    turret.currentAimAngle = angle

    -- Handle volley firing for turrets that support it
    local volleyCount = turret.volleyCount
    local volleySpreadDeg = turret.volleySpreadDeg
    local friendly = turret.owner.isPlayer or false

    for i = 1, volleyCount do
        -- Calculate spread angle for this projectile in the volley
        local spreadFactor = turret.spread.minDeg
        local volleyAngle = 0

        if volleyCount > 1 then
            -- Distribute projectiles evenly across the volley spread
            local spreadPerProjectile = volleySpreadDeg / (volleyCount - 1)
            volleyAngle = math.rad((i - 1) * spreadPerProjectile - volleySpreadDeg / 2)
        end

        -- Apply additional random spread
        local randomSpread = (math.random() - 0.5) * math.rad(spreadFactor)
        local finalAngle = angle + volleyAngle + randomSpread

        -- Create projectile using embedded definition or fallback to Content
        local projectileTemplate = nil
        local projectileId = turret.projectileId or "gun_bullet"  -- Define projectileId here so it's always available

        if turret.projectile and type(turret.projectile) == "table" then
            -- Use embedded projectile definition
            projectileTemplate = turret.projectile
        else
            -- Fallback to separate projectile file
            projectileTemplate = Content.getProjectile(projectileId)
        end

        if projectileTemplate then
            -- Get turret world position instead of ship center
            local Turret = require("src.systems.turret.core")
            local sx, sy = Turret.getTurretWorldPosition(turret)
            local vx = math.cos(finalAngle) * projSpeed
            local vy = math.sin(finalAngle) * projSpeed

            local damageConfig
            if turret.damage_range then
                damageConfig = {
                    min = turret.damage_range.min,
                    max = turret.damage_range.max,
                    skill = turret.skillId
                }
            else
                damageConfig = { min = 1, max = 2, skill = turret.skillId }
            end

            -- Try to send weapon fire request first (for clients)
            local requestSent = sendWeaponFireRequest(turret, sx, sy, finalAngle, projectileId, damageConfig, nil)

            -- If not a client or request failed, spawn projectile directly (for host)
            if not requestSent and world and world.spawn_projectile then
                local metadata = buildProjectileMetadata(turret)
                world.spawn_projectile(sx, sy, finalAngle, friendly, {
                    projectile = projectileId,
                    vx = vx,
                    vy = vy,
                    source = turret.owner,
                    damage = damageConfig,
                    sourcePlayerId = metadata.playerId,
                    sourceShipId = metadata.shipId,
                    sourceTurretSlot = metadata.turretSlot,
                    sourceTurretId = metadata.turretId,
                    sourceTurretType = metadata.turretType,
                })
            end
        end
    end

    -- Handle secondary projectiles (e.g., missiles alongside main fire)
    if turret.secondaryProjectile and turret.secondaryFireEvery then
        -- Check if it's time to fire secondary projectile
        turret.secondaryFireCounter = turret.secondaryFireCounter + 1
        if turret.secondaryFireCounter >= turret.secondaryFireEvery then
            turret.secondaryFireCounter = 0
            ProjectileWeapons.fireSecondaryProjectile(turret, target, angle, world)
        end
    end

    -- Consume ammo and check for reload (only for gun turrets)
    if turret.kind == "gun" and turret.clipSize and turret.clipSize > 0 then
        turret.currentClip = math.max(0, turret.currentClip - 1)
        if turret.currentClip <= 0 then
            turret:startReload()
        end
    end
    
    -- Add heat and play effects (only once per volley, not per projectile)
    TurretEffects.playFiringSound(turret)
    
    -- Set cooldown after firing
    turret.cooldown = turret.cycle or 1.0
end

-- Handle missile turret firing (directional projectiles)
function ProjectileWeapons.updateMissileTurret(turret, dt, target, locked, world)
    if locked or not turret:canFire() then
        return
    end

    local owner = turret.owner
    local sx, sy, angle = computeMissileAim(turret, target)
    turret.currentAimAngle = angle

    local isPlayer = owner and owner.isPlayer

    if isPlayer then
        if not turret.isLockedOn or not isTargetValid(turret.lockOnTarget, owner) then
            turret.cooldownOverride = 0
            return
        end
        target = turret.lockOnTarget
    else
        local maxRangeSq = math.huge
        if turret.maxRange and turret.maxRange > 0 then
            maxRangeSq = turret.maxRange * turret.maxRange
        end

        if not target or not isTargetValid(target, owner) then
            target = findNearestEnemyTarget(turret, world, sx, sy, maxRangeSq)
        end

        if target then
            turret.lockOnTarget = target
            turret.lockOnProgress = 1
            turret.isLockedOn = true
        else
            turret.cooldownOverride = 0
            return
        end
    end

    if not target or not target.components or not target.components.position then
        turret.cooldownOverride = 0
        return
    end

    -- Get projectile speed from embedded definition or fallback to turret setting
    local projSpeed = 1200 -- Increased default speed for rockets (faster than bullets)
    if turret.projectile and type(turret.projectile) == "table" and turret.projectile.physics then
        projSpeed = turret.projectile.physics.speed
    elseif turret.projectileSpeed then
        projSpeed = turret.projectileSpeed
    end

    -- Create missile projectile using embedded definition or fallback to Content
    local projectileTemplate = nil
    local projectileId = turret.projectileId or "missile"
    if turret.projectile and type(turret.projectile) == "table" then
        -- Use embedded projectile definition
        projectileTemplate = turret.projectile
    else
        -- Fallback to separate projectile file
        projectileTemplate = Content.getProjectile(projectileId)
    end

    if projectileTemplate then
        local vx = math.cos(angle) * projSpeed
        local vy = math.sin(angle) * projSpeed

        local damageConfig
        if turret.damage_range then
            damageConfig = {
                min = turret.damage_range.min,
                max = turret.damage_range.max,
                skill = turret.skillId
            }
        else
            damageConfig = { min = 2, max = 4, skill = turret.skillId }
        end

        local additionalEffects = {
            {
                type = "homing",
                world = world,
                target = target,
                turnRate = turret.missileTurnRate,
                maxRange = turret.maxRange,
                speed = projSpeed,
                reacquireDelay = 0.1,
            }
        }

        local friendly = turret.owner.isPlayer or false

        -- Try to send weapon fire request first (for clients)
        local requestSent = sendWeaponFireRequest(turret, sx, sy, angle, projectileId, damageConfig, additionalEffects)

        -- If not a client or request failed, spawn projectile directly (for host)
        if not requestSent and world and world.spawn_projectile then
            local metadata = buildProjectileMetadata(turret)
            world.spawn_projectile(sx, sy, angle, friendly, {
                projectile = projectileId,
                vx = vx,
                vy = vy,
                source = turret.owner,
                damage = damageConfig,
                additionalEffects = additionalEffects,
                sourcePlayerId = metadata.playerId,
                sourceShipId = metadata.shipId,
                sourceTurretSlot = metadata.turretSlot,
                sourceTurretId = metadata.turretId,
                sourceTurretType = metadata.turretType,
            })
        end

        -- Handle secondary projectiles (e.g., rocket clusters)
        if turret.secondaryProjectile then
            ProjectileWeapons.fireSecondaryProjectile(turret, target, angle, world)
        end

        -- Consume ammo and check for reload (only for gun turrets)
        if turret.kind == "gun" and turret.clipSize and turret.clipSize > 0 then
            turret.currentClip = math.max(0, turret.currentClip - 1)
            if turret.currentClip <= 0 then
                turret:startReload()
            end
        end
        
        -- Add heat and play effects
        TurretEffects.playFiringSound(turret)
        
        -- Set cooldown after firing
        turret.cooldown = turret.cycle or 1.0
    end
end

-- Fire secondary projectiles (for multi-stage weapons)
function ProjectileWeapons.fireSecondaryProjectile(turret, target, primaryAngle, world)
    if not turret.secondaryProjectile then return end

    local ownerPos = turret.owner.components.position
    local targetPos = target and target.components and target.components.position
    local dx, dy = 0, 0
    local angle = primaryAngle

    if targetPos then
        dx = targetPos.x - ownerPos.x
        dy = targetPos.y - ownerPos.y
        angle = math.atan2(dy, dx)
    else
        dx = math.cos(angle)
        dy = math.sin(angle)
    end

    -- Secondary projectiles often have different characteristics
    local secondarySpeed = turret.secondaryProjectile.speed

    turret.currentAimAngle = primaryAngle

    -- Create secondary projectile
    -- Get turret world position instead of ship center
    local Turret = require("src.systems.turret.core")
    local sx, sy = Turret.getTurretWorldPosition(turret)
    local vx = math.cos(angle) * secondarySpeed
    local vy = math.sin(angle) * secondarySpeed

    local dmg
    if turret.damage_range then
        dmg = {
            min = turret.damage_range.min,
            max = turret.damage_range.max,
            skill = turret.skillId
        }
    else
        dmg = { min = 1, max = 2, skill = turret.skillId }
    end

    local friendly = turret.owner.isPlayer or false

    -- Try to send weapon fire request first (for clients)
    local requestSent = sendWeaponFireRequest(turret, sx, sy, angle, turret.secondaryProjectile.id, dmg, nil)

    -- If not a client or request failed, spawn projectile directly (for host)
    if not requestSent and world and world.spawn_projectile then
        local metadata = buildProjectileMetadata(turret)
        world.spawn_projectile(sx, sy, angle, friendly, {
            projectile = turret.secondaryProjectile.id,
            vx = vx,
            vy = vy,
            source = turret.owner,
            damage = dmg,
            kind = 'missile',
            sourcePlayerId = metadata.playerId,
            sourceShipId = metadata.shipId,
            sourceTurretSlot = metadata.turretSlot,
            sourceTurretId = metadata.turretId,
            sourceTurretType = metadata.turretType,
        })
    end
end

-- Check if projectile weapon can fire
function ProjectileWeapons.canFire(turret, target)
    return turret:canFire()
end

return ProjectileWeapons
