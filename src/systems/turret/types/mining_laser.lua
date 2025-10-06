local TurretRegistry = require("src.systems.turret.registry")
local UtilityBeams = require("src.systems.turret.utility_beams")
local TurretEffects = require("src.systems.turret.effects")

local handler = {
    kind = "mining_laser",
    config = {
        requiresClip = false,
        skipEnergyCheck = true,
    },
}

function handler.update(turret, dt, target, locked, world)
    return UtilityBeams.updateMiningLaser(turret, dt, target, locked, world)
end

handler.updateIdle = handler.update

function handler.cancelFiring(turret)
    if turret.miningSoundActive or turret.miningSoundInstance then
        TurretEffects.stopMiningSound(turret)
    end
end

TurretRegistry.register("mining_laser", handler)

return handler
