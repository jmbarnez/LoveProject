local TurretRegistry = require("src.systems.turret.registry")
local BeamWeapons = require("src.systems.turret.beam_weapons")

local handler = {
    kind = "laser",
    config = {
        requiresClip = false,
    },
}

function handler.update(turret, dt, target, locked, world)
    BeamWeapons.updateLaserTurret(turret, dt, target, locked, world)
end

TurretRegistry.register("laser", handler)

return handler
