local Constants = require("src.core.constants")

local Config = {}

Config.WORLD = Constants.WORLD

Config.SPAWN = setmetatable({
  -- Custom no-spawn zones (areas where enemies should never spawn)
  -- Note: Now handled by beacon stations with custom no_spawn_radius property
  NO_SPAWN_ZONES = {
  }
}, { __index = Constants.SPAWNING })

Config.MISSILE = {
  EXPLODE_RADIUS = 48,  -- u
  LIFE = 3.5,           -- s
}

Config.LASER = {
  MAX_LENGTH = 1500,    -- u
  DEFAULT_DIST = 1500,  -- u
  LIFE = 0.06,          -- s
}

Config.BULLET = {
  HIT_BUFFER = 0.0,     -- s
  TRACER_SPEED = 4800,  -- u/s
}

-- Player combat tuning
Config.COMBAT = Constants.COMBAT

Config.HUB = {
  WEAPONS_DISABLE_DURATION = Constants.STATION.WEAPONS_DISABLE_DURATION,
}

-- Quest system settings
Config.QUESTS = {
  STATION_SLOTS = 3,                 -- number of procedural quest slots at stations
  REFRESH_AFTER_TURNIN_SEC = 15 * 60 -- s - 15 minutes cooldown after turn-in
}

Config.DEBUG = {
  FAST_SHIP = false,
  DRAW_BOUNDS = false,
  COLLISION_EFFECTS = false,
  PROJECTILE_COLLISION = false,
  PLAYER_SYSTEM = false,
}

-- Render options
Config.RENDER = {
  SHOW_THRUSTER_EFFECTS = false, -- Hide ship directional thruster VFX
}

-- Audio behavior
Config.AUDIO = Constants.AUDIO

-- Dash system configuration
Config.DASH = {
    SPEED = 100,           -- Base dash speed (u/s) - much weaker
    COOLDOWN = 5.0,        -- Base cooldown in seconds
    ENERGY_COST = 75,      -- Base energy cost - very high
    IFRAMES = 0.15,        -- Base invincibility frames duration (s) - shorter
}

return Config
