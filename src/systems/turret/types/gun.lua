local TurretRegistry = require("src.systems.turret.registry")
local ProjectileWeapons = require("src.systems.turret.projectile_weapons")

local handler = {
    kind = "gun",
    config = {
        requiresClip = true,
    },
}

function handler.update(turret, dt, target, locked, world)
    ProjectileWeapons.updateGunTurret(turret, dt, target, locked, world)
end

TurretRegistry.register("gun", handler)

return handler
