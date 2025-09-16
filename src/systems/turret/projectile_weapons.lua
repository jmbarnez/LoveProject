local Content = require("src.content.content")
local HeatManager = require("src.systems.turret.heat_manager")
local Targeting = require("src.systems.turret.targeting")
local TurretEffects = require("src.systems.turret.effects")

local ProjectileWeapons = {}

-- Handle gun turret firing (bullets, shells, etc.)
function ProjectileWeapons.updateGunTurret(turret, dt, target, locked, world)
    if locked or not HeatManager.canFire(turret) then
        return
    end

    -- Manual shooting - fire in the direction the player is facing
    local angle = turret.owner.components.position.angle or 0
    local projSpeed = turret.projectileSpeed or 2400

    -- Apply spread based on turret accuracy
    local spreadFactor = turret.spread and turret.spread.minDeg or 0.1
    local spreadAngle = (math.random() - 0.5) * math.rad(spreadFactor)
    angle = angle + spreadAngle

    -- Create projectile
    local projectileId = turret.projectileId or "gun_bullet"
    local projectileTemplate = Content.getProjectile(projectileId)

    if projectileTemplate then
        local sx = turret.owner.components.position.x
        local sy = turret.owner.components.position.y
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
                } or {min = 1, max = 2}
            })
        end

        -- Add heat and play effects
        HeatManager.addHeat(turret, turret.heatPerShot or 10)
        TurretEffects.playFiringSound(turret)
    end
end

-- Handle missile turret firing (homing projectiles)
function ProjectileWeapons.updateMissileTurret(turret, dt, target, locked, world)
    if locked or not HeatManager.canFire(turret) then
        return
    end

    -- For missiles, use locked target if available, otherwise fire straight ahead
    local angle = turret.owner.components.position.angle or 0
    local projSpeed = turret.projectileSpeed or 800

    -- Check for locked target
    local missileTarget = nil
    if turret.owner and turret.owner.getLockedTarget then
        local lockedTarget = turret.owner:getLockedTarget()
        if lockedTarget then
            missileTarget = lockedTarget
            -- Aim towards locked target
            local dx = lockedTarget.components.position.x - turret.owner.components.position.x
            local dy = lockedTarget.components.position.y - turret.owner.components.position.y
            angle = math.atan2(dy, dx)
        end
    end

    -- Create missile projectile
    local projectileId = turret.projectileId or "missile"
    local projectileTemplate = Content.getProjectile(projectileId)

    if projectileTemplate then
        local sx = turret.owner.components.position.x
        local sy = turret.owner.components.position.y
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
                turnRate = turret.missileTurnRate or 0,
                target = missileTarget,
                homing = true
            })
        end

        -- Handle secondary projectiles (e.g., rocket clusters)
        if turret.secondaryProjectile then
            ProjectileWeapons.fireSecondaryProjectile(turret, target, angle, world)
        end

        -- Add heat and play effects
        HeatManager.addHeat(turret, turret.heatPerShot or 15)
        TurretEffects.playFiringSound(turret)
    end
end

-- Fire secondary projectiles (for multi-stage weapons)
function ProjectileWeapons.fireSecondaryProjectile(turret, target, primaryAngle, world)
    if not turret.secondaryProjectile then return end

    local dx = target.components.position.x - turret.owner.components.position.x
    local dy = target.components.position.y - turret.owner.components.position.y
    local dist = math.sqrt(dx * dx + dy * dy)

    -- Secondary projectiles often have different characteristics
    local secondarySpeed = turret.secondaryProjectile.speed or 400
    local leadTime = dist / secondarySpeed
    local angle = math.atan2(dy, dx)

    -- Create secondary projectile
    local sx = turret.owner.components.position.x
    local sy = turret.owner.components.position.y
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