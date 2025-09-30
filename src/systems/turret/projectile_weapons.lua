local Content = require("src.content.content")
local HeatManager = require("src.systems.turret.heat_manager")
local Targeting = require("src.systems.turret.targeting")
local TurretEffects = require("src.systems.turret.effects")

local ProjectileWeapons = {}

-- Handle gun turret firing (bullets, shells, etc.)
function ProjectileWeapons.updateGunTurret(turret, dt, target, locked, world)
    if locked or not turret:canFire() then
        return
    end

    -- Get turret world position first for accurate aiming
    local Turret = require("src.systems.turret.core")
    local sx, sy = Turret.getTurretWorldPosition(turret)

    -- Manual shooting - fire in the direction of the cursor from turret position
    local angle = 0
    if turret.owner.cursorWorldPos then
        local cursorX, cursorY = turret.owner.cursorWorldPos.x, turret.owner.cursorWorldPos.y
        local dx = cursorX - sx
        local dy = cursorY - sy
        angle = math.atan2(dy, dx)
    else
        -- Fallback to ship facing if cursor position not available
        angle = turret.owner.components.position.angle or 0
    end
    -- Get projectile speed from embedded definition or fallback to turret setting
    local projSpeed = 2400 -- Default fallback
    if turret.projectile and type(turret.projectile) == "table" and turret.projectile.physics then
        projSpeed = turret.projectile.physics.speed or 2400
    elseif turret.projectileSpeed then
        projSpeed = turret.projectileSpeed
    end

    -- Store the current aim so muzzle calculations can align with turret visuals.
    turret.currentAimAngle = angle

    -- Handle volley firing for turrets that support it
    local volleyCount = turret.volleyCount or 1
    local volleySpreadDeg = turret.volleySpreadDeg or 0

    for i = 1, volleyCount do
        -- Calculate spread angle for this projectile in the volley
        local spreadFactor = turret.spread and turret.spread.minDeg or 0.1
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
        if turret.projectile and type(turret.projectile) == "table" then
            -- Use embedded projectile definition
            projectileTemplate = turret.projectile
        else
            -- Fallback to separate projectile file
            local projectileId = turret.projectileId or "gun_bullet"
            projectileTemplate = Content.getProjectile(projectileId)
        end

        if projectileTemplate then
            -- Get turret world position instead of ship center
            local Turret = require("src.systems.turret.core")
            local sx, sy = Turret.getTurretWorldPosition(turret)
            local vx = math.cos(finalAngle) * projSpeed
            local vy = math.sin(finalAngle) * projSpeed

            -- Use world's spawn_projectile function to avoid circular dependency
            if world and world.spawn_projectile then
                world.spawn_projectile(sx, sy, finalAngle, turret.owner.isPlayer or turret.owner.isFriendly, {
                    projectile = projectileId,
                    vx = vx,
                    vy = vy,
                    source = turret.owner,
                    damage = turret.damage_range and {
                        min = turret.damage_range.min,
                        max = turret.damage_range.max
                    } or {min = 1, max = 2}
                })
            end
        end
    end

    -- Handle secondary projectiles (e.g., missiles alongside main fire)
    if turret.secondaryProjectile and turret.secondaryFireEvery then
        -- Check if it's time to fire secondary projectile
        turret.secondaryFireCounter = (turret.secondaryFireCounter or 0) + 1
        if turret.secondaryFireCounter >= turret.secondaryFireEvery then
            turret.secondaryFireCounter = 0
            ProjectileWeapons.fireSecondaryProjectile(turret, target, angle, world)
        end
    end

    -- Add heat and play effects (only once per volley, not per projectile)
    HeatManager.addHeat(turret, turret.heatPerShot or 10)
    TurretEffects.playFiringSound(turret)
end

-- Handle missile turret firing (homing projectiles)
function ProjectileWeapons.updateMissileTurret(turret, dt, target, locked, world)
    if locked or not turret:canFire() then
        return
    end

    -- For missiles, use assigned target if available; otherwise fire straight ahead
    local angle = turret.owner.components.position.angle or 0
    
    -- Get projectile speed from embedded definition or fallback to turret setting
    local projSpeed = 800 -- Default fallback for missiles
    if turret.projectile and type(turret.projectile) == "table" and turret.projectile.physics then
        projSpeed = turret.projectile.physics.speed or 800
    elseif turret.projectileSpeed then
        projSpeed = turret.projectileSpeed
    end

    local missileTarget = nil
    local isHoming = false

    -- Check if we have a locked-on target
    if turret.isLockedOn and turret.lockOnTarget then
        missileTarget = turret.lockOnTarget
        isHoming = true
        local dx = turret.lockOnTarget.components.position.x - turret.owner.components.position.x
        local dy = turret.lockOnTarget.components.position.y - turret.owner.components.position.y
        angle = math.atan2(dy, dx)
    elseif target and target.components and target.components.position then
        -- Use provided target if no lock-on, but fire straight ahead (non-homing)
        local dx = target.components.position.x - turret.owner.components.position.x
        local dy = target.components.position.y - turret.owner.components.position.y
        angle = math.atan2(dy, dx)
    end

    turret.currentAimAngle = angle

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
        -- Get turret world position instead of ship center
        local Turret = require("src.systems.turret.core")
        local sx, sy = Turret.getTurretWorldPosition(turret)
        local vx = math.cos(angle) * projSpeed
        local vy = math.sin(angle) * projSpeed

        -- Use world's spawn_projectile function to avoid circular dependency
        if world and world.spawn_projectile then
            world.spawn_projectile(sx, sy, angle, turret.owner.isPlayer or turret.owner.isFriendly, {
                projectile = projectileId,
                vx = vx,
                vy = vy,
                source = turret.owner,
                damage = turret.damage_range and {
                    min = turret.damage_range.min,
                    max = turret.damage_range.max
                } or {min = 2, max = 4},
                target = missileTarget,
                homing = isHoming,
                homingStrength = isHoming and (turret.homingStrength or 0.8) or 0,
                missileTurnRate = isHoming and (turret.missileTurnRate or 4.5) or 0
            })
        end

        -- Handle secondary projectiles (e.g., rocket clusters)
        if turret.secondaryProjectile then
            ProjectileWeapons.fireSecondaryProjectile(turret, target, angle, world)
        end

        -- Add heat and play effects
        HeatManager.addHeat(turret, turret.heatPerShot or 15)
        TurretEffects.playFiringSound(turret)

        -- Reset lock-on after firing
        turret:resetLockOn()
    end
end

-- Fire secondary projectiles (for multi-stage weapons)
function ProjectileWeapons.fireSecondaryProjectile(turret, target, primaryAngle, world)
    if not turret.secondaryProjectile then return end

    local ownerPos = turret.owner.components.position
    local targetPos = target and target.components and target.components.position or nil
    local dx, dy = 0, 0
    local angle = primaryAngle or (ownerPos.angle or 0)

    if targetPos then
        dx = targetPos.x - ownerPos.x
        dy = targetPos.y - ownerPos.y
        angle = math.atan2(dy, dx)
    else
        dx = math.cos(angle)
        dy = math.sin(angle)
    end

    -- Secondary projectiles often have different characteristics
    local secondarySpeed = turret.secondaryProjectile.speed or 400

    turret.currentAimAngle = primaryAngle or angle

    -- Create secondary projectile
    -- Get turret world position instead of ship center
    local Turret = require("src.systems.turret.core")
    local sx, sy = Turret.getTurretWorldPosition(turret)
    local vx = math.cos(angle) * secondarySpeed
    local vy = math.sin(angle) * secondarySpeed

    local dmg = turret.damage_range and {
        min = turret.damage_range.min,
        max = turret.damage_range.max
    } or {min = 1, max = 2}

    -- Use world's spawn_projectile function to avoid circular dependency
    if world and world.spawn_projectile then
        world.spawn_projectile(sx, sy, angle, turret.owner.isPlayer or turret.owner.isFriendly, {
            projectile = turret.secondaryProjectile.id or "missile",
            vx = vx,
            vy = vy,
            source = turret.owner,
            damage = dmg,
            kind = 'missile'
        })
    end
end

-- Check if projectile weapon can fire
function ProjectileWeapons.canFire(turret, target)
    return HeatManager.canFire(turret) and
           Targeting.isValidTarget(turret, target) and
           (not turret.maxRange or Targeting.canEngageTarget(turret, target,
            math.sqrt((target.components.position.x - turret.owner.components.position.x)^2 +
                     (target.components.position.y - turret.owner.components.position.y)^2)))
end

return ProjectileWeapons
