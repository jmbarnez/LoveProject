local TurretRegistry = require("src.systems.turret.registry")
local UtilityBeams = require("src.systems.turret.utility_beams")

local handler = {
    kind = "plasma_torch",
    config = {
        requiresClip = false,
        skipEnergyCheck = true,
    },
}

function handler.update(turret, dt, target, locked, world)
    return UtilityBeams.updatePlasmaTorch(turret, dt, target, locked, world)
end

handler.updateIdle = handler.update

TurretRegistry.register("plasma_torch", handler)

return handler
