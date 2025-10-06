local TurretRegistry = require("src.systems.turret.registry")
local UtilityBeams = require("src.systems.turret.utility_beams")
local TurretEffects = require("src.systems.turret.effects")

local handler = {
    kind = "salvaging_laser",
    config = {
        requiresClip = false,
        skipEnergyCheck = true,
    },
}

function handler.update(turret, dt, target, locked, world)
    return UtilityBeams.updateSalvagingLaser(turret, dt, target, locked, world)
end

handler.updateIdle = handler.update

function handler.cancelFiring(turret)
    if turret.salvagingSoundActive or turret.salvagingSoundInstance then
        TurretEffects.stopSalvagingSound(turret)
    end
end

TurretRegistry.register("salvaging_laser", handler)

return handler
