-- ====================================================================================
-- CONSTANTS.LUA - Centralized numerical values for the game
-- ====================================================================================
-- This file contains all magic numbers found throughout the codebase, organized into
-- logical categories with clear comments. All constants should be referenced from here
-- to ensure consistency and easy maintenance.
-- ====================================================================================

local Constants = {}

-- ====================================================================================
-- RESOLUTION AND DISPLAY CONSTANTS
-- ====================================================================================

Constants.RESOLUTION = {
    -- Default/base resolution values
    DEFAULT_WIDTH = 1920,
    DEFAULT_HEIGHT = 1080,

    -- Minimum window sizes for responsive design
    MIN_WINDOW_WIDTH_800PX = 600,
    MIN_WINDOW_HEIGHT_800PX = 400,
    MIN_WINDOW_WIDTH_1024PX = 800,
    MIN_WINDOW_HEIGHT_1024PX = 600,

    -- Fullscreen sizing ratios
    FULLSCREEN_RATIO_SMALL = 0.9,    -- 800x600 or smaller
    FULLSCREEN_RATIO_MEDIUM = 0.85,   -- 1024x768 or smaller
    FULLSCREEN_RATIO_LARGE = 0.8,     -- Larger displays

    -- Windowed mode sizing ratios
    WINDOWED_RATIO_SMALL = 0.95,      -- 800x600 or smaller
    WINDOWED_RATIO_MEDIUM = 0.9,      -- 1024x768 or smaller
    WINDOWED_RATIO_LARGE = 0.8,       -- Larger windows
}

Constants.UI = {
    -- Panel and window sizing
    PANEL_MIN_WIDTH = 600,
    PANEL_MIN_HEIGHT = 400,
    PANEL_MAX_WIDTH = 800,
    PANEL_MAX_HEIGHT = 600,

    -- Content padding and spacing
    CONTENT_PADDING = 20,
    BUTTON_HEIGHT = 28,
    BUTTON_SPACING = 10,
    DROPDOWN_WIDTH = 150,
    ITEM_HEIGHT = 40,
    SECTION_SPACING = 60,

    -- Scrollbar dimensions
    SCROLLBAR_WIDTH = 12,
    SCROLLBAR_MIN_THUMB_HEIGHT = 20,

    -- Tooltip configuration
    TOOLTIP_MAX_WIDTH = 500,
    TOOLTIP_MIN_WIDTH = 150,
    TOOLTIP_PADDING = 8,
    TOOLTIP_SCREEN_MARGIN_RATIO = 0.8,
    TOOLTIP_NAME_LINE_SPACING = 8,
    TOOLTIP_STAT_LINE_SPACING = 2,
    TOOLTIP_MODIFIER_HEADER_SPACING = 8,

    -- Dialog dimensions
    DIALOG_WIDTH = 400,
    DIALOG_HEIGHT = 250,
    DIALOG_BUTTON_WIDTH = 120,
    DIALOG_BUTTON_HEIGHT = 35,
    DIALOG_BUTTON_SPACING = 20,

    -- Inventory grid
    INVENTORY_SLOT_SIZE = 64,
    INVENTORY_SLOT_SPACING = 10,
    INVENTORY_GRID_SIZE = 3,  -- 3x3 grid
    INVENTORY_ICON_SIZE = 40,
    INVENTORY_ICON_SIZE_COMPACT = 48,

    -- Minimap dimensions
    MINIMAP_WIDTH = 220,
    MINIMAP_HEIGHT = 160,
    MINIMAP_PADDING = 16,
    MINIMAP_GRID_SIZE = 16,

    -- HUD dimensions
    HUD_BAR_WIDTH = 250,
    HUD_BAR_HEIGHT = 18,
    HUD_BAR_GAP = 4,
    HUD_ENERGY_SIZE = 120,
    HUD_STATUS_BAR_SCALE = 1.0,

    -- Font sizes (relative to base)
    FONT_SCALE_TINY = 0.7,
    FONT_SCALE_SMALL = 0.85,
    FONT_SCALE_MEDIUM = 1.0,
    FONT_SCALE_LARGE = 1.2,
    FONT_SCALE_TITLE = 1.5,

    -- Animation and timing
    PULSE_SPEED = 2,
    SHIMMER_SPEED = 50,
    ANIMATION_SPEED = 1.5,
    CRITICAL_FLASH_SPEED = 8,
    CRITICAL_THRESHOLD = 0.25,
}

-- ====================================================================================
-- WORLD AND GAME DIMENSIONS
-- ====================================================================================

Constants.WORLD = {
    WIDTH = 30000,
    HEIGHT = 30000,

    -- Star field configuration
    STAR_LAYER_COUNT = 2,
    STAR_PARALLAX_FAR = 0.040,
    STAR_PARALLAX_VERY_FAR = 0.015,
    STAR_SIZE_MIN = 0.14,
    STAR_SIZE_MAX = 0.40,
    STAR_TWINKLE_SPEED_MIN = 0.35,
    STAR_TWINKLE_SPEED_MAX = 0.55,
    STAR_ALPHA_MIN = 0.06,
    STAR_ALPHA_MAX = 0.12,
    STAR_DENSITY_SCALE = 1.0,  -- Multiplier for star density based on resolution

    -- Nebula configuration
    NEBULA_BLOB_COUNT_BASE = 8,
    NEBULA_BLOB_COUNT_SCALE = 6,
    NEBULA_BASE_SIZE_MIN = 0.20,
    NEBULA_BASE_SIZE_MAX = 0.30,
    NEBULA_SUB_CLOUD_COUNT_MIN = 8,
    NEBULA_SUB_CLOUD_COUNT_MAX = 12,
    NEBULA_WISP_COUNT_MIN = 4,
    NEBULA_WISP_COUNT_MAX = 7,
    NEBULA_WISP_SEGMENTS_MIN = 12,
    NEBULA_WISP_SEGMENTS_MAX = 20,

    -- Background update frequency
    BACKGROUND_UPDATE_FREQUENCY = 5,  -- Update every N frames
    TWINKLE_UPDATE_FREQUENCY = 3,     -- Update twinkling every N frames
}

-- ====================================================================================
-- GAME BALANCE VALUES
-- ====================================================================================

Constants.COMBAT = {
    -- Alignment and targeting
    ALIGN_LOCK_DEGREES = 10,
    ALIGN_RANGE_BONUS = 1.2,

    -- Boost mechanics
    BOOST_THRUST_MULTIPLIER = 1.5,
    BOOST_ENERGY_DRAIN_PER_SECOND = 100,

    -- Shield ability
    SHIELD_CHANNEL_SLOWDOWN = 0.5,
    SHIELD_DAMAGE_REDUCTION = 0.5,
    SHIELD_DURATION = 3.0,
    SHIELD_COOLDOWN = 5.0,
    SHIELD_ENERGY_COST = 50,

    -- HUD visibility
    ENEMY_BAR_VISIBLE_TIME = 2.5,
}

Constants.SPAWNING = {
    MARGIN = 75,
    STATION_BUFFER = 300,
    MIN_PLAYER_DISTANCE = 150,
    INTERVAL_MIN = 2.0,
    INTERVAL_MAX = 4.0,
    MAX_ENEMIES = 36,
}

Constants.PROJECTILES = {
    -- Missile settings
    MISSILE_EXPLODE_RADIUS = 48,
    MISSILE_LIFETIME = 3.5,

    -- Laser settings
    LASER_MAX_LENGTH = 1500,
    LASER_DEFAULT_DISTANCE = 1500,
    LASER_LIFETIME = 0.06,

    -- Bullet settings
    BULLET_HIT_BUFFER = 1.5,
    BULLET_TRACER_SPEED = 4800,
}

Constants.STATION = {
    WEAPONS_DISABLE_DURATION = 5.0,
}

Constants.PLAYER = {
    STARTING_CREDITS = 10000,
    STARTING_SHIELD_MODULES = 1,
    SHIELD_EQUIPMENT_SLOT = 4,
}

Constants.QUESTS = {
    STATION_SLOTS = 3,
    REFRESH_COOLDOWN_MINUTES = 15,
    REFRESH_COOLDOWN_SECONDS = 900,  -- 15 * 60
}

Constants.AUDIO = {
    FULL_VOLUME_DISTANCE = 300,
    HEARING_DISTANCE = 1400,
    MIN_VOLUME = 0.0,
}

-- ====================================================================================
-- RENDERING AND VISUAL CONSTANTS
-- ====================================================================================

Constants.RENDER = {
    -- Effects
    GLOW_WEAK = 0.1,
    GLOW_MEDIUM = 0.2,
    GLOW_STRONG = 0.3,
    GLOW_INTENSE = 0.4,

    -- Alpha values
    ALPHA_TRANSPARENT = 0.2,
    ALPHA_SEMI_TRANSPARENT = 0.4,
    ALPHA_MOSTLY_OPAQUE = 0.7,
    ALPHA_OPAQUE = 0.9,
    ALPHA_FULL = 1.0,

    -- Border radius values
    BORDER_RADIUS_SMALL = 2,
    BORDER_RADIUS_MEDIUM = 4,
    BORDER_RADIUS_LARGE = 6,
    BORDER_RADIUS_XLARGE = 8,

    -- Particle effects
    PARTICLE_COUNT_EXPLOSION = 5,
    PARTICLE_COUNT_SPARKS = 3,
    PARTICLE_LIFETIME = 0.7,
    SPARK_LIFETIME = 0.5,

    -- Debug rendering
    DEBUG_DRAW_BOUNDS = false,
    DEBUG_FAST_SHIP = false,
}

-- ====================================================================================
-- ANIMATION AND TIMING CONSTANTS
-- ====================================================================================

Constants.TIMING = {
    -- Frame rate limits
    FPS_UNLIMITED = 0,
    FPS_30 = 30,
    FPS_60 = 60,
    FPS_120 = 120,
    FPS_144 = 144,
    FPS_240 = 240,

    -- Animation curves and easing
    EASING_SPEED_SLOW = 0.02,
    EASING_SPEED_MEDIUM = 0.05,
    EASING_SPEED_FAST = 0.1,

    -- UI animation timing
    UI_ANIMATION_DURATION = 0.2,
    UI_FADE_DURATION = 0.15,
    UI_SLIDE_DURATION = 0.3,

    -- Game state timing
    AUTOSAVE_INTERVAL = 300,  -- 5 minutes
    SAVE_SLOT_COUNT = 3,
}

-- ====================================================================================
-- FILE SYSTEM AND SAVE CONSTANTS
-- ====================================================================================

Constants.FILES = {
    -- Save file settings
    MAX_SAVE_NAME_LENGTH = 30,
    SAVE_BACKUP_COUNT = 5,

    -- Configuration
    SETTINGS_FILE = "settings.lua",
    CONFIG_FILE = "config.lua",

    -- Asset paths
    FONTS_PATH = "assets/fonts/",
    SOUNDS_PATH = "content/sounds/",
    SHADERS_PATH = "src/shaders/",
}

-- ====================================================================================
-- MATH AND PHYSICS CONSTANTS
-- ====================================================================================

Constants.MATH = {
    -- Trigonometric precision
    DEG_TO_RAD = math.pi / 180,
    RAD_TO_DEG = 180 / math.pi,

    -- Floating point precision
    EPSILON = 1e-10,
    FLOAT_COMPARE_THRESHOLD = 1e-6,

    -- Interpolation factors
    LERP_SMOOTH = 0.1,
    LERP_FAST = 0.2,
    LERP_INSTANT = 0.5,

    -- Random number generation
    RANDOM_SEED_DEFAULT = 12345,
}

-- ====================================================================================
-- COLOR PALETTE CONSTANTS
-- ====================================================================================

Constants.COLORS = {
    -- RGB color components (0-1 range)
    RGB_RED = {1.0, 0.0, 0.0},
    RGB_GREEN = {0.0, 1.0, 0.0},
    RGB_BLUE = {0.0, 0.0, 1.0},
    RGB_WHITE = {1.0, 1.0, 1.0},
    RGB_BLACK = {0.0, 0.0, 0.0},
    RGB_GRAY = {0.5, 0.5, 0.5},

    -- Alpha transparency values
    ALPHA_NONE = 0.0,
    ALPHA_QUARTER = 0.25,
    ALPHA_HALF = 0.5,
    ALPHA_THREE_QUARTER = 0.75,
    ALPHA_FULL = 1.0,
}

-- ====================================================================================
-- UTILITY FUNCTIONS FOR ACCESSING CONSTANTS
-- ====================================================================================

-- Get a constant value by path (e.g., "WORLD.WIDTH" or {"WORLD", "WIDTH"})
function Constants.get(path)
    if type(path) == "string" then
        local keys = {}
        for key in path:gmatch("[^.]+") do
            table.insert(keys, key)
        end
        path = keys
    end

    local current = Constants
    for _, key in ipairs(path) do
        if type(current) ~= "table" or current[key] == nil then
            error("Constant not found: " .. table.concat(path, "."))
        end
        current = current[key]
    end

    return current
end

-- Check if a constant exists
function Constants.exists(path)
    local success, _ = pcall(Constants.get, path)
    return success
end

-- Get all constants in a category
function Constants.getCategory(category)
    return Constants[category] or {}
end

-- Get all available categories
function Constants.getCategories()
    local categories = {}
    for key, value in pairs(Constants) do
        if type(value) == "table" and key ~= "_G" and key ~= "_VERSION" then
            table.insert(categories, key)
        end
    end
    table.sort(categories)
    return categories
end

return Constants