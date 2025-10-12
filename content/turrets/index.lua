-- List of turret definition modules. Add new files and require them here.
return {
    -- Combat turrets
    require("content.turrets.basic_cannon"),
    require("content.turrets.railgun_turret"),
    require("content.turrets.low_power_laser"),
    require("content.turrets.missile_launcher_mk1"),
    -- Utility turrets
    require("content.turrets.mining_laser"),
    require("content.turrets.salvaging_laser"),
    require("content.turrets.healing_laser"),
}
