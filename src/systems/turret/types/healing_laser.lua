local TurretRegistry = require("src.systems.turret.registry")
local UtilityBeams = require("src.systems.turret.utility_beams")

local handler = {
    kind = "healing_laser",
    update = function(turret, dt, target, locked, world)
        UtilityBeams.updateHealingLaser(turret, dt, target, locked, world)
    end,
    fire = function(turret, dt, target, locked, world)
        UtilityBeams.updateHealingLaser(turret, dt, target, locked, world)
    end
}

TurretRegistry.register("healing_laser", handler)
