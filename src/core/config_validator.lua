local Log = require("src.core.log")

local ConfigValidator = {}

-- Validation result structure
local ValidationResult = {}
ValidationResult.__index = ValidationResult

function ValidationResult.new()
    local self = setmetatable({}, ValidationResult)
    self.isValid = true
    self.errors = {}
    self.warnings = {}
    return self
end

function ValidationResult:addError(field, message)
    self.isValid = false
    table.insert(self.errors, { field = field, message = message })
end

function ValidationResult:addWarning(field, message)
    table.insert(self.warnings, { field = field, message = message })
end

function ValidationResult:merge(other)
    self.isValid = self.isValid and other.isValid
    for _, error in ipairs(other.errors) do
        table.insert(self.errors, error)
    end
    for _, warning in ipairs(other.warnings) do
        table.insert(self.warnings, warning)
    end
end

-- Core validation functions
local function validateRequired(value, fieldName)
    if value == nil then
        return false, string.format("Field '%s' is required but is missing", fieldName)
    end
    return true, nil
end

local function validateType(value, expectedType, fieldName)
    if type(value) ~= expectedType then
        return false, string.format("Field '%s' must be of type %s, got %s", fieldName, expectedType, type(value))
    end
    return true, nil
end

local function validateNumber(value, fieldName)
    local success, typeError = validateType(value, "number", fieldName)
    if not success then
        return false, typeError
    end
    return true, nil
end

local function validateRange(value, min, max, fieldName)
    local success, numError = validateNumber(value, fieldName)
    if not success then
        return false, numError
    end

    if value < min or value > max then
        return false, string.format("Field '%s' must be between %s and %s, got %s", fieldName, min, max, value)
    end
    return true, nil
end

local function validateBoolean(value, fieldName)
    local success, typeError = validateType(value, "boolean", fieldName)
    if not success then
        return false, typeError
    end
    return true, nil
end

local function validateString(value, fieldName)
    local success, typeError = validateType(value, "string", fieldName)
    if not success then
        return false, typeError
    end
    return true, nil
end

local function validateTable(value, fieldName)
    local success, typeError = validateType(value, "table", fieldName)
    if not success then
        return false, typeError
    end
    return true, nil
end

local function validateOneOf(value, options, fieldName)
    for _, option in ipairs(options) do
        if value == option then
            return true, nil
        end
    end
    return false, string.format("Field '%s' must be one of: %s, got %s",
        fieldName, table.concat(options, ", "), tostring(value))
end

local function validateDependency(condition, fieldName, dependencyField, dependencyValue)
    if condition then
        return true, nil
    end
    return false, string.format("Field '%s' requires '%s' to be %s",
        fieldName, dependencyField, tostring(dependencyValue))
end

-- Schema definition structure
local Schema = {}
Schema.__index = Schema

function Schema.new()
    local self = setmetatable({}, Schema)
    self.fields = {}
    return self
end

function Schema:field(name, validator, options)
    self.fields[name] = {
        validator = validator,
        options = options or {}
    }
    return self
end

function Schema:required()
    self.fields[#self.fields].required = true
    return self
end

function Schema:range(min, max)
    self.fields[#self.fields].min = min
    self.fields[#self.fields].max = max
    return self
end

function Schema:oneOf(options)
    self.fields[#self.fields].options = options
    return self
end

function Schema:dependsOn(field, value)
    self.fields[#self.fields].dependency = { field = field, value = value }
    return self
end

function Schema:validate(data, context)
    local result = ValidationResult.new()
    context = context or ""

    for fieldName, fieldSchema in pairs(self.fields) do
        local fullFieldName = context .. (context ~= "" and "." or "") .. fieldName
        local value = data[fieldName]

        -- Check required fields
        if fieldSchema.required then
            local success, errorMsg = validateRequired(value, fullFieldName)
            if not success then
                result:addError(fullFieldName, errorMsg)
                goto continue
            end
        end

        -- Skip validation if field is not present and not required
        if value == nil then
            goto continue
        end

        -- Check dependencies
        if fieldSchema.dependency then
            local depField = fieldSchema.dependency.field
            local depValue = fieldSchema.dependency.value
            local depFieldValue = data[depField]
            local success, errorMsg = validateDependency(
                depFieldValue == depValue, fullFieldName, depField, depValue
            )
            if not success then
                result:addError(fullFieldName, errorMsg)
            end
        end

        -- Apply field-specific validation
        local validator = fieldSchema.validator
        local success, errorMsg

        if validator == "number" then
            success, errorMsg = validateNumber(value, fullFieldName)
            if fieldSchema.min and fieldSchema.max then
                if success then
                    success, errorMsg = validateRange(value, fieldSchema.min, fieldSchema.max, fullFieldName)
                end
            end
        elseif validator == "boolean" then
            success, errorMsg = validateBoolean(value, fullFieldName)
        elseif validator == "string" then
            success, errorMsg = validateString(value, fullFieldName)
            if fieldSchema.options and success then
                success, errorMsg = validateOneOf(value, fieldSchema.options, fullFieldName)
            end
        elseif validator == "table" then
            success, errorMsg = validateTable(value, fullFieldName)
        elseif type(validator) == "function" then
            success, errorMsg = validator(value, fullFieldName)
        else
            -- Unknown validator type
            result:addWarning(fullFieldName, "Unknown validator type: " .. tostring(validator))
            success = true
        end

        if not success then
            result:addError(fullFieldName, errorMsg)
        end

        ::continue::
    end

    return result
end

-- Schema builders for common patterns
function ConfigValidator.number(min, max)
    return function(value, fieldName)
        local success, errorMsg = validateNumber(value, fieldName)
        if not success then return false, errorMsg end
        if min and max then
            return validateRange(value, min, max, fieldName)
        end
        return true, nil
    end
end

function ConfigValidator.positiveNumber()
    return ConfigValidator.number(0, nil)
end

function ConfigValidator.negativeNumber()
    return ConfigValidator.number(nil, 0)
end

function ConfigValidator.percentage()
    return ConfigValidator.number(0, 1)
end

function ConfigValidator.resolution()
    return function(value, fieldName)
        local success, errorMsg = validateTable(value, fieldName)
        if not success then return false, errorMsg end

        local width = value.width
        local height = value.height

        success, errorMsg = validateRequired(width, fieldName .. ".width")
        if not success then return false, errorMsg end

        success, errorMsg = validateRequired(height, fieldName .. ".height")
        if not success then return false, errorMsg end

        success, errorMsg = validateNumber(width, fieldName .. ".width")
        if not success then return false, errorMsg end

        success, errorMsg = validateNumber(height, fieldName .. ".height")
        if not success then return false, errorMsg end

        if width <= 0 or height <= 0 then
            return false, string.format("Resolution %dx%d must have positive dimensions", width, height)
        end

        return true, nil
    end
end

function ConfigValidator.color()
    return function(value, fieldName)
        if type(value) == "string" then
            return validateString(value, fieldName)
        elseif type(value) == "table" then
            if #value == 3 or #value == 4 then
                for i, component in ipairs(value) do
                    local success, errorMsg = validateRange(component, 0, 1, fieldName .. "[" .. i .. "]")
                    if not success then return false, errorMsg end
                end
                return true, nil
            else
                return false, string.format("Color table must have 3 or 4 components, got %d", #value)
            end
        else
            return false, string.format("Color must be string or table, got %s", type(value))
        end
    end
end

function ConfigValidator.keyBinding()
    return function(value, fieldName)
        if type(value) == "string" then
            return true, nil
        elseif type(value) == "table" then
            local primary = value.primary
            if type(primary) ~= "string" then
                return false, string.format("Field '%s.primary' must be a string", fieldName)
            end
            return true, nil
        end
        return false, string.format("Field '%s' must be a string or table, got %s", fieldName, type(value))
    end
end

-- Predefined schemas for common configurations
ConfigValidator.schemas = {}

-- Graphics settings schema
ConfigValidator.schemas.graphics = Schema.new()
    :field("resolution", ConfigValidator.resolution())
    :field("fullscreen", "boolean")
    :field("fullscreen_type", "string"):oneOf({"desktop", "exclusive"})
    :field("borderless", "boolean")
    :field("vsync", "boolean")
    :field("max_fps", "number"):range(30, 300)
    :field("ui_scale", "number"):range(0.5, 3.0)
    :field("font_scale", "number"):range(0.5, 3.0)
    :field("helpers_enabled", "boolean")
    :field("reticle_style", "number"):range(1, 50)
    :field("reticle_color", "string")
    :field("reticle_color_rgb", ConfigValidator.color())
    :field("ui_cursor_color", "string")
    :field("ui_cursor_color_rgb", ConfigValidator.color())

-- Audio settings schema
ConfigValidator.schemas.audio = Schema.new()
    :field("master_volume", "number"):range(0, 1)
    :field("sfx_volume", "number"):range(0, 1)
    :field("music_volume", "number"):range(0, 1)

-- Keymap schema
ConfigValidator.schemas.keymap = Schema.new()
    :field("toggle_inventory", ConfigValidator.keyBinding())
    :field("toggle_bounty", ConfigValidator.keyBinding())
    :field("toggle_skills", ConfigValidator.keyBinding())
    :field("toggle_map", ConfigValidator.keyBinding())
    :field("dock", ConfigValidator.keyBinding())
    :field("dash", ConfigValidator.keyBinding())
    :field("hotbar_1", ConfigValidator.keyBinding())
    :field("hotbar_2", ConfigValidator.keyBinding())
    :field("hotbar_3", ConfigValidator.keyBinding())
    :field("hotbar_4", ConfigValidator.keyBinding())
    :field("hotbar_5", ConfigValidator.keyBinding())
    :field("repair_beacon", ConfigValidator.keyBinding())

-- Hotbar schema
ConfigValidator.schemas.hotbar = Schema.new()
    :field("items", "table")

-- Config validation schemas
ConfigValidator.schemas.config = {}

-- World configuration schema
ConfigValidator.schemas.config.world = Schema.new()
    :field("WIDTH", "number"):range(1000, 100000)
    :field("HEIGHT", "number"):range(1000, 100000)

-- Spawn configuration schema
ConfigValidator.schemas.config.spawn = Schema.new()
    :field("MARGIN", "number"):range(0, 1000)
    :field("STATION_BUFFER", "number"):range(0, 5000)
    :field("MIN_PLAYER_DIST", "number"):range(0, 1000)
    :field("INTERVAL_MIN", "number"):range(0.1, 60)
    :field("INTERVAL_MAX", "number"):range(0.1, 60)
    :field("NO_SPAWN_ZONES", "table")

-- Combat configuration schema
ConfigValidator.schemas.config.combat = Schema.new()
    :field("ALIGN_LOCK_DEG", "number"):range(0, 180)
    :field("ALIGN_RANGE_BONUS", "number"):range(0.1, 5.0)
    :field("BOOST_THRUST_MULT", "number"):range(0.1, 10.0)
    :field("BOOST_ENERGY_DRAIN", "number"):range(0, 1000)
    :field("SHIELD_CHANNEL_SLOW", "number"):range(0.1, 1.0)
    :field("SHIELD_DAMAGE_REDUCTION", "number"):range(0, 1.0)
    :field("SHIELD_DURATION", "number"):range(0.1, 30)
    :field("SHIELD_COOLDOWN", "number"):range(0.1, 60)
    :field("SHIELD_ENERGY_COST", "number"):range(0, 500)
    :field("ENEMY_BAR_VIS_TIME", "number"):range(0.1, 10)

-- Audio configuration schema
ConfigValidator.schemas.config.audio = Schema.new()
    :field("FULL_VOLUME_DISTANCE", "number"):range(1, 10000)
    :field("HEARING_DISTANCE", "number"):range(1, 10000)
    :field("MIN_VOLUME", "number"):range(0, 1)

-- Main validation functions
function ConfigValidator.validateSettings(settings)
    local result = ValidationResult.new()

    -- Validate graphics settings
    if settings.graphics then
        local graphicsResult = ConfigValidator.schemas.graphics:validate(settings.graphics, "graphics")
        result:merge(graphicsResult)
    end

    -- Validate audio settings
    if settings.audio then
        local audioResult = ConfigValidator.schemas.audio:validate(settings.audio, "audio")
        result:merge(audioResult)
    end

    -- Validate keymap settings
    if settings.keymap then
        local keymapResult = ConfigValidator.schemas.keymap:validate(settings.keymap, "keymap")
        result:merge(keymapResult)
    end

    -- Validate hotbar settings
    if settings.hotbar then
        local hotbarResult = ConfigValidator.schemas.hotbar:validate(settings.hotbar, "hotbar")
        result:merge(hotbarResult)
    end

    return result
end

function ConfigValidator.validateConfig(config)
    local result = ValidationResult.new()

    -- Validate world settings
    if config.WORLD then
        local worldResult = ConfigValidator.schemas.config.world:validate(config.WORLD, "WORLD")
        result:merge(worldResult)
    end

    -- Validate spawn settings
    if config.SPAWN then
        local spawnResult = ConfigValidator.schemas.config.spawn:validate(config.SPAWN, "SPAWN")
        result:merge(spawnResult)
    end

    -- Validate combat settings
    if config.COMBAT then
        local combatResult = ConfigValidator.schemas.config.combat:validate(config.COMBAT, "COMBAT")
        result:merge(combatResult)
    end

    -- Validate audio settings
    if config.AUDIO then
        local audioResult = ConfigValidator.schemas.config.audio:validate(config.AUDIO, "AUDIO")
        result:merge(audioResult)
    end

    -- Validate other numeric fields with basic range checks
    local numericFields = {
        MAX_ENEMIES = {min = 1, max = 100},
        MISSILE = {
            EXPLODE_RADIUS = {min = 1, max = 1000},
            LIFE = {min = 0.1, max = 60}
        },
        LASER = {
            MAX_LENGTH = {min = 1, max = 10000},
            DEFAULT_DIST = {min = 1, max = 10000},
            LIFE = {min = 0.01, max = 10}
        },
        BULLET = {
            HIT_BUFFER = {min = 0.1, max = 10},
            TRACER_SPEED = {min = 1, max = 10000}
        },
        DASH = {
            SPEED = {min = 1, max = 5000},
            IFRAMES = {min = 0.01, max = 5},
            COOLDOWN = {min = 0.01, max = 10},
            ENERGY_COST = {min = 0, max = 1000}
        },
        STATION = {
            WEAPONS_DISABLE_DURATION = {min = 0.1, max = 30}
        },
        QUESTS = {
            STATION_SLOTS = {min = 1, max = 20},
            REFRESH_AFTER_TURNIN_SEC = {min = 1, max = 3600}
        }
    }

    for field, range in pairs(numericFields) do
        if type(range) == "table" and range.min and range.max then
            if config[field] then
                local success, errorMsg = validateRange(config[field], range.min, range.max, field)
                if not success then
                    result:addError(field, errorMsg)
                end
            end
        elseif type(range) == "table" then
            for subfield, subrange in pairs(range) do
                if config[field] and config[field][subfield] then
                    local success, errorMsg = validateRange(
                        config[field][subfield],
                        subrange.min,
                        subrange.max,
                        field .. "." .. subfield
                    )
                    if not success then
                        result:addError(field .. "." .. subfield, errorMsg)
                    end
                end
            end
        end
    end

    -- Validate boolean fields
    local booleanFields = {
        "DEBUG", {
            FAST_SHIP = true,
            DRAW_BOUNDS = true
        },
        "RENDER", {
            SHOW_THRUSTER_EFFECTS = true
        }
    }

    for i = 1, #booleanFields, 2 do
        local section = booleanFields[i]
        local fields = booleanFields[i + 1]

        if type(fields) == "table" then
            for field, _ in pairs(fields) do
                if config[section] and config[section][field] ~= nil then
                    local success, errorMsg = validateBoolean(config[section][field], section .. "." .. field)
                    if not success then
                        result:addError(section .. "." .. field, errorMsg)
                    end
                end
            end
        else
            if config[section] ~= nil then
                local success, errorMsg = validateBoolean(config[section], section)
                if not success then
                    result:addError(section, errorMsg)
                end
            end
        end
    end

    return result
end

function ConfigValidator.validateAll(settings, config)
    local result = ValidationResult.new()

    if settings then
        local settingsResult = ConfigValidator.validateSettings(settings)
        result:merge(settingsResult)
    end

    if config then
        local configResult = ConfigValidator.validateConfig(config)
        result:merge(configResult)
    end

    return result
end

-- Utility functions for error reporting
function ConfigValidator.formatErrors(result)
    if result.isValid then
        return "Configuration is valid"
    end

    local messages = {}

    for _, error in ipairs(result.errors) do
        table.insert(messages, "ERROR: " .. error.message)
    end

    for _, warning in ipairs(result.warnings) do
        table.insert(messages, "WARNING: " .. warning.message)
    end

    return table.concat(messages, "\n")
end

function ConfigValidator.logErrors(result)
    if not result.isValid then
        Log.error("Configuration validation failed:")
        for _, error in ipairs(result.errors) do
            Log.error("  " .. error.message)
        end
    end

    if #result.warnings > 0 then
        Log.warn("Configuration warnings:")
        for _, warning in ipairs(result.warnings) do
            Log.warn("  " .. warning.message)
        end
    end
end

ConfigValidator.Schema = Schema

return ConfigValidator
