-- Collision System Constants
-- Centralized constants for collision physics and behavior

local CollisionConstants = {}

-- Physics Constants
CollisionConstants.DEFAULT_RESTITUTION = 0.25
CollisionConstants.HULL_RESTITUTION = 0.28
CollisionConstants.SHIELD_RESTITUTION = 0.88
CollisionConstants.ASTEROID_RESTITUTION = 0.12
CollisionConstants.STATION_RESTITUTION = 0.18
CollisionConstants.WRECKAGE_RESTITUTION = 0.10
CollisionConstants.PLANET_RESTITUTION = 0.05

-- Debris Push Constants
CollisionConstants.DEBRIS_BASE_TRANSFER = 1.2
CollisionConstants.DEBRIS_OVERLAP_FACTOR_MAX = 1.0
CollisionConstants.DEBRIS_OVERLAP_DIVISOR = 2.0
CollisionConstants.DEBRIS_SPEED_FACTOR_MAX = 2.5
CollisionConstants.DEBRIS_SPEED_DIVISOR = 30.0
CollisionConstants.DEBRIS_MASS_FACTOR_MAX = 2.0
CollisionConstants.DEBRIS_MASS_DIVISOR = 1.5
CollisionConstants.DEBRIS_PLAYER_RESISTANCE = 0.05
CollisionConstants.DEBRIS_ANGULAR_TRANSFER = 0.3
CollisionConstants.DEBRIS_ANGULAR_SCALE = 0.01

-- Projectile Query Constants
CollisionConstants.PROJECTILE_QUERY_MULTIPLIER = 1.5
CollisionConstants.PROJECTILE_MAX_QUERY_EXPANSION = 50.0

-- Collision Effect Constants
CollisionConstants.COLLISION_EFFECT_COOLDOWN = 0.1
CollisionConstants.ASTEROID_SOUND_THRESHOLD = 50.0
CollisionConstants.ASTEROID_SOUND_COOLDOWN = 0.5
CollisionConstants.ASTEROID_SOUND_VOLUME_MAX = 0.8
CollisionConstants.ASTEROID_SOUND_VOLUME_MIN = 0.1
CollisionConstants.ASTEROID_SOUND_SCALE = 200.0

-- Push Distance Constants
CollisionConstants.POLYGON_PUSH_STATION = 0.3
CollisionConstants.POLYGON_PUSH_NORMAL = 0.2
CollisionConstants.CIRCLE_PUSH_STATION = 0.25
CollisionConstants.CIRCLE_PUSH_NORMAL = 0.15
CollisionConstants.MIN_STATION_PUSH = 1.0

-- Validation Constants
CollisionConstants.MIN_COLLISION_DISTANCE_FACTOR = 0.8
CollisionConstants.MIN_NORMAL_MAGNITUDE = 0.1
CollisionConstants.DEFAULT_NORMAL_X = 1.0
CollisionConstants.DEFAULT_NORMAL_Y = 0.0

return CollisionConstants
