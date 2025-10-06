local TurretRegistry = require("src.systems.turret.registry")
local ProjectileWeapons = require("src.systems.turret.projectile_weapons")

local handler = {
    kind = "projectile",
    config = {
        requiresClip = false,
    },
}

function handler.update(turret, dt, target, locked, world)
    ProjectileWeapons.updateGunTurret(turret, dt, target, locked, world)
end

TurretRegistry.register("projectile", handler)
TurretRegistry.register(nil, handler)

return handler
