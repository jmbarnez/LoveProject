--[[
  Sound Configuration for DarkOrbitLove
  Define all sound effects and music for the game
]]

return {
  -- Sound Effects
  sfx = {
    -- Weapon sounds
    laser_fire = "laser_fire",
    missile_launch = "missile_launch", 
    gun_fire = "gun_fire",
    
    -- Impact sounds
    shield_hit = "shield_hit",
    shield_static = "shield_static",
    hull_hit = "hull_hit",
    explosion = "explosion",
    
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
    -- Weapon events
    weapon_laser_fire = {type = "sfx", sound = "laser_fire", volume = 0.7},
    weapon_missile_fire = {type = "sfx", sound = "missile_launch", volume = 0.8},
    weapon_gun_fire = {type = "sfx", sound = "gun_fire", volume = 0.6},
    
    -- Impact events  
    impact_shield = {type = "sfx", sound = "shield_hit", volume = 0.5},
    shield_bounce = {type = "sfx", sound = "shield_static", volume = 0.6},
    impact_hull = {type = "sfx", sound = "hull_hit", volume = 0.6},
    ship_explosion = {type = "sfx", sound = "explosion", volume = 0.9},
    
    -- Ship events
    thruster_activate = {type = "sfx", sound = "engine_thrust", volume = 0.3},
    ship_destroyed = {type = "sfx", sound = "ship_destroyed", volume = 0.8},
    
    -- Mining events
    mining_start = {type = "sfx", sound = "mining_laser", volume = 0.4},
    ore_mined = {type = "sfx", sound = "ore_collected", volume = 0.5},
    
    -- Station events
    station_dock = {type = "sfx", sound = "dock", volume = 0.6},
    station_undock = {type = "sfx", sound = "undock", volume = 0.6},
    
    -- Pickup events
    loot_collected = {type = "sfx", sound = "loot_pickup", volume = 0.5},
    
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
