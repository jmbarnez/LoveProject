-- Configuration Validator Usage Examples
-- This file demonstrates how to use the configuration validation system

local ConfigValidator = require("src.core.config_validator")
local Config = require("src.content.config")
local Settings = require("src.core.settings")

-- Example 1: Basic validation of settings
local function exampleBasicValidation()
    print("=== Basic Settings Validation ===")

    -- Load current settings (this would normally come from your settings system)
    local currentSettings = Settings.getGraphicsSettings()

    -- Validate the settings
    local result = ConfigValidator.validateSettings(currentSettings)

    -- Check if validation passed
    if result.isValid then
        print("✓ Settings validation passed!")
    else
        print("✗ Settings validation failed:")
        print(ConfigValidator.formatErrors(result))
    end

    -- Log errors using the built-in logger
    ConfigValidator.logErrors(result)
end

-- Example 2: Validation with custom schema
local function exampleCustomSchema()
    print("\n=== Custom Schema Validation ===")

    -- Create a custom schema for game-specific settings
    local customSchema = ConfigValidator.Schema.new()
        :field("difficulty", "string"):oneOf({"easy", "normal", "hard", "expert"})
        :field("auto_save", "boolean")
        :field("max_save_slots", "number"):range(1, 10)
        :field("tutorial_enabled", "boolean")

    -- Sample data to validate
    local gameSettings = {
        difficulty = "expert",
        auto_save = true,
        max_save_slots = 5,
        tutorial_enabled = false
    }

    local result = customSchema:validate(gameSettings, "game")

    if result.isValid then
        print("✓ Custom schema validation passed!")
    else
        print("✗ Custom schema validation failed:")
        print(ConfigValidator.formatErrors(result))
    end
end

-- Example 3: Validation with dependencies
local function exampleDependencyValidation()
    print("\n=== Dependency Validation ===")

    -- Create a schema with dependencies
    local schemaWithDeps = ConfigValidator.Schema.new()
        :field("enable_advanced_graphics", "boolean")
        :field("shadow_quality", "string"):oneOf({"low", "medium", "high", "ultra"})
        :dependsOn("enable_advanced_graphics", true)
        :field("antialiasing", "number"):range(0, 8)
        :dependsOn("enable_advanced_graphics", true)

    -- Test case 1: Dependencies satisfied
    local validSettings = {
        enable_advanced_graphics = true,
        shadow_quality = "high",
        antialiasing = 4
    }

    local result1 = schemaWithDeps:validate(validSettings, "graphics")
    print("Valid settings result:", result1.isValid and "PASS" or "FAIL")

    -- Test case 2: Dependencies not satisfied
    local invalidSettings = {
        enable_advanced_graphics = false,
        shadow_quality = "high",  -- This should fail because advanced graphics is disabled
        antialiasing = 4          -- This should also fail
    }

    local result2 = schemaWithDeps:validate(invalidSettings, "graphics")
    print("Invalid settings result:", result2.isValid and "PASS" or "FAIL")
    if not result2.isValid then
        print("Errors:")
        for _, error in ipairs(result2.errors) do
            print("  - " .. error.message)
        end
    end
end

-- Example 4: Full configuration validation
local function exampleFullValidation()
    print("\n=== Full Configuration Validation ===")

    -- Validate both settings and config
    local settings = {
        graphics = Settings.getGraphicsSettings(),
        audio = Settings.getAudioSettings(),
        keymap = Settings.getKeymap(),
        hotbar = Settings.getHotbarSettings()
    }

    local result = ConfigValidator.validateAll(settings, Config)

    if result.isValid then
        print("✓ All configuration validation passed!")
    else
        print("✗ Configuration validation failed:")
        print(ConfigValidator.formatErrors(result))
    end

    -- Log detailed results
    ConfigValidator.logErrors(result)
end

-- Example 5: Creating custom validators
local function exampleCustomValidators()
    print("\n=== Custom Validator Functions ===")

    -- Custom validator for player names
    local function validatePlayerName(value, fieldName)
        if type(value) ~= "string" then
            return false, string.format("Field '%s' must be a string", fieldName)
        end

        if #value < 3 then
            return false, string.format("Field '%s' must be at least 3 characters long", fieldName)
        end

        if #value > 20 then
            return false, string.format("Field '%s' must be no more than 20 characters long", fieldName)
        end

        -- Check for valid characters (letters, numbers, spaces, underscores)
        if not value:match("^[a-zA-Z0-9_ ]+$") then
            return false, string.format("Field '%s' contains invalid characters", fieldName)
        end

        return true, nil
    end

    -- Custom validator for coordinates
    local function validateCoordinates(value, fieldName)
        if type(value) ~= "table" then
            return false, string.format("Field '%s' must be a table", fieldName)
        end

        if value.x == nil or value.y == nil then
            return false, string.format("Field '%s' must have x and y properties", fieldName)
        end

        local success, errorMsg = ConfigValidator.validateNumber(value.x, fieldName .. ".x")
        if not success then return false, errorMsg end

        success, errorMsg = ConfigValidator.validateNumber(value.y, fieldName .. ".y")
        if not success then return false, errorMsg end

        return true, nil
    end

    -- Use custom validators in a schema
    local playerSchema = ConfigValidator.Schema.new()
        :field("name", validatePlayerName)
        :field("position", validateCoordinates)
        :field("level", "number"):range(1, 100)
        :field("health", "number"):range(0, 1000)

    -- Test the custom validators
    local playerData = {
        name = "Player123",
        position = { x = 100, y = 200 },
        level = 25,
        health = 750
    }

    local result = playerSchema:validate(playerData, "player")

    if result.isValid then
        print("✓ Custom validators passed!")
    else
        print("✗ Custom validators failed:")
        for _, error in ipairs(result.errors) do
            print("  - " .. error.message)
        end
    end
end

-- Example 6: Extending existing schemas
local function exampleSchemaExtension()
    print("\n=== Schema Extension ===")

    -- Start with the base graphics schema
    local extendedGraphicsSchema = ConfigValidator.schemas.graphics

    -- Add custom fields to the existing schema
    extendedGraphicsSchema:field("custom_resolution_scale", "number"):range(0.5, 2.0)
    extendedGraphicsSchema:field("enable_post_processing", "boolean")
    extendedGraphicsSchema:field("post_process_quality", "string"):oneOf({"low", "medium", "high"})
        :dependsOn("enable_post_processing", true)

    -- Test the extended schema
    local extendedSettings = {
        resolution = { width = 1920, height = 1080 },
        fullscreen = false,
        custom_resolution_scale = 1.5,
        enable_post_processing = true,
        post_process_quality = "high"
    }

    local result = extendedGraphicsSchema:validate(extendedSettings, "extended_graphics")

    if result.isValid then
        print("✓ Extended schema validation passed!")
    else
        print("✗ Extended schema validation failed:")
        for _, error in ipairs(result.errors) do
            print("  - " .. error.message)
        end
    end
end

-- Example 7: Batch validation with error collection
local function exampleBatchValidation()
    print("\n=== Batch Validation ===")

    -- Simulate multiple configuration sources
    local configs = {
        main = Config,
        user_settings = {
            graphics = Settings.getGraphicsSettings(),
            audio = Settings.getAudioSettings()
        },
        mod_settings = {
            custom_difficulty = "insane",
            enable_mods = true
        }
    }

    local allResults = ConfigValidator.ValidationResult.new()

    -- Validate each configuration source
    for name, config in pairs(configs) do
        print(string.format("Validating %s configuration...", name))

        local result
        if name == "main" then
            result = ConfigValidator.validateConfig(config)
        else
            result = ConfigValidator.validateSettings(config)
        end

        if not result.isValid then
            print(string.format("  ✗ %s validation failed", name))
            for _, error in ipairs(result.errors) do
                print(string.format("    - %s", error.message))
            end
        else
            print(string.format("  ✓ %s validation passed", name))
        end

        allResults:merge(result)
    end

    print(string.format("\nOverall validation result: %s", allResults.isValid and "PASS" or "FAIL"))
    if not allResults.isValid then
        print("Total errors:", #allResults.errors)
        print("Total warnings:", #allResults.warnings)
    end
end

-- Run all examples
local function runAllExamples()
    print("Configuration Validator Examples")
    print("================================\n")

    exampleBasicValidation()
    exampleCustomSchema()
    exampleDependencyValidation()
    exampleFullValidation()
    exampleCustomValidators()
    exampleSchemaExtension()
    exampleBatchValidation()

    print("\n=== Examples Complete ===")
    print("Check the output above to see how the configuration validator works!")
end

-- Export examples for use in other files
return {
    runAllExamples = runAllExamples,
    exampleBasicValidation = exampleBasicValidation,
    exampleCustomSchema = exampleCustomSchema,
    exampleDependencyValidation = exampleDependencyValidation,
    exampleFullValidation = exampleFullValidation,
    exampleCustomValidators = exampleCustomValidators,
    exampleSchemaExtension = exampleSchemaExtension,
    exampleBatchValidation = exampleBatchValidation
}