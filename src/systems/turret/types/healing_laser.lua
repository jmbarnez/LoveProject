local TurretRegistry = require("src.systems.turret.registry")
local UtilityBeams = require("src.systems.turret.utility_beams")
local TurretEffects = require("src.systems.turret.effects")

local handler = {
    kind = "healing_laser",
    config = {
        requiresClip = false,
    },
}

function handler.update(turret, dt, target, locked, world)
    return UtilityBeams.updateHealingLaser(turret, dt, target, locked, world)
end

handler.updateIdle = handler.update

function handler.cancelFiring(turret)
    if turret.healingSoundActive or turret.healingSoundInstance then
        TurretEffects.stopHealingSound(turret)
    end
end

TurretRegistry.register("healing_laser", handler)

return handler
