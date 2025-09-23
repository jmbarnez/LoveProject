local Config = {}

-- Global gameplay/config constants
Config.MAX_ENEMIES = 12

Config.WORLD = {
  WIDTH = 30000,
  HEIGHT = 30000,
}

Config.SPAWN = {
  MARGIN = 75,             -- keep spawns away from world edges (scaled for smaller world)
  STATION_BUFFER = 5000,   -- safe zone radius around all stations (no enemy spawns)
  PLAYER_SPAWN_BUFFER = 100, -- buffer for spawning player near the station
  MIN_PLAYER_DIST = 150,   -- min distance from player for new enemy spawns (scaled for smaller world)
  INTERVAL_MIN = 2.0,      -- seconds
  INTERVAL_MAX = 4.0,      -- seconds

  -- Custom no-spawn zones (areas where enemies should never spawn)
  -- Note: Now handled by beacon stations with custom no_spawn_radius property
  NO_SPAWN_ZONES = {
  }
}

Config.MISSILE = {
  EXPLODE_RADIUS = 48,
  LIFE = 3.5,
}

Config.LASER = {
  MAX_LENGTH = 1500,
  DEFAULT_DIST = 1500,
  LIFE = 0.06,
}

Config.BULLET = {
  HIT_BUFFER = 1.5,
  TRACER_SPEED = 4800,
}

-- Player combat tuning
Config.COMBAT = {
  -- Alignment lock: player must face target within this cone to allow firing
  ALIGN_LOCK_DEG = 10,        -- degrees
  ALIGN_RANGE_BONUS = 1.2,    -- allow a bit beyond optimal range when well aligned

  -- Boost: sustained thrust multiplier with energy drain (replaces dash)
  BOOST_THRUST_MULT = 1.5,   -- thrust multiplier while boosting
  BOOST_ENERGY_DRAIN = 100,    -- energy per second while boosting

  -- Shield active ability: 50% damage reduction with duration/cooldown system
  SHIELD_CHANNEL_SLOW = 0.5,    -- movement/thrust multiplier while active
  SHIELD_DAMAGE_REDUCTION = 0.5, -- 50% damage reduction when active
  SHIELD_DURATION = 3.0,        -- duration in seconds
  SHIELD_COOLDOWN = 5.0,        -- cooldown in seconds
  SHIELD_ENERGY_COST = 50,      -- energy cost per activation

  -- HUD visibility windows
  ENEMY_BAR_VIS_TIME = 2.5,   -- seconds after player damage

  -- No parry/directional multipliers in simple manual mode
}

Config.HUB = {
  WEAPONS_DISABLE_DURATION = 5.0,  -- seconds weapons stay disabled after leaving hub range
}

-- Quest system settings
Config.QUESTS = {
  STATION_SLOTS = 3,                 -- number of procedural quest slots at stations
  REFRESH_AFTER_TURNIN_SEC = 15 * 60 -- 15 minutes cooldown after turn-in
}

Config.DEBUG = {
  FAST_SHIP = false,
  DRAW_BOUNDS = false,
}

-- Render options
Config.RENDER = {
  SHOW_THRUSTER_EFFECTS = false, -- Hide ship directional thruster VFX
}

-- Audio behavior
Config.AUDIO = {
  -- Within this distance (world units), play SFX at full event volume
  FULL_VOLUME_DISTANCE = 300,
  -- Beyond this distance, SFX are inaudible
  HEARING_DISTANCE = 1400,
  -- Minimum volume multiplier when attenuated (0 = hard cutoff)
  MIN_VOLUME = 0.0,
}

return Config