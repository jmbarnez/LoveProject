--[[
  Sound Configuration for DarkOrbitLove
  Define all sound effects and music for the game. Asset files now live in assets/sounds/.
]]

return {
  -- Sound Effects
  sfx = {
    -- Weapon sounds - specific to each weapon type
    railgun_turret_fire = "railgun_turret_fire",
    low_power_laser_fire = "low_power_laser_fire", 
    missile_launcher_fire = "missile_launcher_fire",
    
    -- Legacy weapon sounds (for compatibility)
    laser_fire = "laser_fire",
    missile_launch = "missile_launch", 
    gun_fire = "gun_fire",
    
    -- Impact sounds - specific collision types
    shield_hit_light = "shield_hit_light",
    shield_hit_heavy = "shield_hit_heavy",
    shield_static = "shield_static",
    hull_hit_light = "hull_hit_light",
    hull_hit_heavy = "hull_hit_heavy",
    hull_hit_critical = "hull_hit_critical",
    asteroid_hit_light = "asteroid_hit_light",
    asteroid_hit_heavy = "asteroid_hit_heavy",
    rock_impact = "rock_impact",
    explosion = "explosion",
    
    -- Legacy impact sounds (for compatibility)
    shield_hit = "shield_hit",
    hull_hit = "hull_hit",
    
    -- Ship sounds
    engine_thrust = "engine_thrust",
    ship_destroyed = "ship_destroyed",
    
    -- UI sounds
    ui_click = "ui_click",
    ui_hover = "ui_hover",
    ui_error = "ui_error",
    
    -- Mining sounds
    mining_laser = "mining_laser",
    ore_collected = "ore_collected",
    
    -- Station sounds
    dock = "dock",
    undock = "undock",
    
    -- Pickup sounds
    loot_pickup = "loot_pickup",
    asteroid_shatter = "asteroid_shatter",
    asteroid_pop = "asteroid_pop",
  },
  
  -- Music
  music = {
    menu = "adrift",
    space_ambient = "adrift", 
    combat = "adrift",
    station = "adrift",
  },
  
  -- Event Sound Mappings
  events = {
    -- Specific weapon events
    weapon_railgun_turret_fire = {type = "sfx", sound = "railgun_turret_fire", volume = 0.5},
    weapon_low_power_laser_fire = {type = "sfx", sound = "low_power_laser_fire", volume = 0.3},
    weapon_missile_launcher_fire = {type = "sfx", sound = "missile_launcher_fire", volume = 0.8},
    
    -- Legacy weapon events (for compatibility)
    weapon_laser_fire = {type = "sfx", sound = "laser_fire", volume = 0.3},
    weapon_missile_fire = {type = "sfx", sound = "missile_launch", volume = 0.8},
    weapon_gun_fire = {type = "sfx", sound = "gun_fire", volume = 0.25},
    weapon_mining_laser = {type = "sfx", sound = "mining_laser", volume = 0.2},
    weapon_salvaging_laser = {type = "sfx", sound = "mining_laser", volume = 0.2},
    
    -- Impact events - specific collision types
    impact_shield_light = {type = "sfx", sound = "shield_hit_light", volume = 0.4},
    impact_shield_heavy = {type = "sfx", sound = "shield_hit_heavy", volume = 0.7},
    shield_bounce = {type = "sfx", sound = "shield_static", volume = 0.6},
    impact_hull_light = {type = "sfx", sound = "hull_hit_light", volume = 0.5},
    impact_hull_heavy = {type = "sfx", sound = "hull_hit_heavy", volume = 0.8},
    impact_hull_critical = {type = "sfx", sound = "hull_hit_critical", volume = 1.0},
    impact_asteroid_light = {type = "sfx", sound = "asteroid_hit_light", volume = 0.3},
    impact_asteroid_heavy = {type = "sfx", sound = "asteroid_hit_heavy", volume = 0.6},
    impact_rock = {type = "sfx", sound = "rock_impact", volume = 0.5},
    ship_explosion = {type = "sfx", sound = "explosion", volume = 0.4},
    
    -- Legacy impact events (for compatibility)
    impact_shield = {type = "sfx", sound = "shield_hit", volume = 0.5},
    impact_hull = {type = "sfx", sound = "hull_hit", volume = 0.6},
    
    -- Ship events
    thruster_activate = {type = "sfx", sound = "engine_thrust", volume = 0.3},
    ship_destroyed = {type = "sfx", sound = "ship_destroyed", volume = 0.9},
    
    -- Mining events
    mining_start = {type = "sfx", sound = "mining_laser", volume = 0.2},
    ore_mined = {type = "sfx", sound = "ore_collected", volume = 0.5},
    
    -- Station events
    station_dock = {type = "sfx", sound = "dock", volume = 0.6},
    station_undock = {type = "sfx", sound = "undock", volume = 0.6},
    
    -- Pickup events
    loot_collected = {type = "sfx", sound = "loot_pickup", volume = 0.5},
    xp_collected = {type = "sfx", sound = "loot_pickup", volume = 0.55, pitch = 1.1},
    asteroid_shatter = {type = "sfx", sound = "asteroid_shatter", volume = 0.65},
    asteroid_pop = {type = "sfx", sound = "asteroid_pop", volume = 1.0},
    
    -- UI events
    ui_button_click = {type = "sfx", sound = "ui_click", volume = 0.3},
    ui_button_hover = {type = "sfx", sound = "ui_hover", volume = 0.2},
    ui_error_sound = {type = "sfx", sound = "ui_error", volume = 0.4},
    enemy_lock_on = {type = "sfx", sound = "lock_on", volume = 0.6},
    
    -- Music events
    game_start = {type = "music", sound = "adrift", fadeIn = true},
    enter_combat = {type = "music", sound = "adrift"},
    enter_station = {type = "music", sound = "adrift"},
    return_to_space = {type = "music", sound = "adrift"},
  }
}
