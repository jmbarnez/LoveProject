local TurretRegistry = require("src.systems.turret.registry")
local ProjectileWeapons = require("src.systems.turret.projectile_weapons")

local handler = {
    kind = "missile",
    config = {
        requiresClip = false,
    },
}

function handler.preUpdate(turret, dt, target, locked, world)
    ProjectileWeapons.updateMissileLockState(turret, dt, target, world)
end

function handler.update(turret, dt, target, locked, world)
    ProjectileWeapons.updateMissileTurret(turret, dt, target, locked, world)
end

TurretRegistry.register("missile", handler)

return handler
