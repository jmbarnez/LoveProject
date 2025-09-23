-- Simple test script for the configuration validator
-- Run with: love test_config_validator.lua

local ConfigValidator = require("src.core.config_validator")
local Config = require("src.content.config")
local Settings = require("src.core.settings")

function love.load()
    print("Configuration Validator Test")
    print("============================")

    -- Test 1: Basic settings validation
    print("\nTest 1: Basic Settings Validation")
    local testSettings = {
        graphics = {
            resolution = { width = 1920, height = 1080 },
            fullscreen = false,
            vsync = true,
            max_fps = 60,
            ui_scale = 1.0
        },
        audio = {
            master_volume = 0.5,
            sfx_volume = 0.7,
            music_volume = 0.3
        }
    }

    local result1 = ConfigValidator.validateSettings(testSettings)
    print("Result: " .. (result1.isValid and "PASS" or "FAIL"))
    if not result1.isValid then
        print("Errors: " .. #result1.errors)
        for _, error in ipairs(result1.errors) do
            print("  - " .. error.message)
        end
    end

    -- Test 2: Invalid settings
    print("\nTest 2: Invalid Settings Detection")
    local invalidSettings = {
        graphics = {
            resolution = { width = 0, height = 1080 },  -- Invalid resolution
            max_fps = 500,  -- Out of range
            ui_scale = 5.0   -- Out of range
        }
    }

    local result2 = ConfigValidator.validateSettings(invalidSettings)
    print("Result: " .. (result2.isValid and "PASS" or "FAIL"))
    if not result2.isValid then
        print("Errors: " .. #result2.errors)
        for _, error in ipairs(result2.errors) do
            print("  - " .. error.message)
        end
    end

    -- Test 3: Config validation
    print("\nTest 3: Config Validation")
    local result3 = ConfigValidator.validateConfig(Config)
    print("Result: " .. (result3.isValid and "PASS" or "FAIL"))
    if not result3.isValid then
        print("Errors: " .. #result3.errors)
        for _, error in ipairs(result3.errors) do
            print("  - " .. error.message)
        end
    end

    -- Test 4: Full validation
    print("\nTest 4: Full Validation")
    local settings = Settings.getGraphicsSettings()
    local result4 = ConfigValidator.validateAll(settings, Config)
    print("Result: " .. (result4.isValid and "PASS" or "FAIL"))
    if not result4.isValid then
        print("Errors: " .. #result4.errors)
        for _, error in ipairs(result4.errors) do
            print("  - " .. error.message)
        end
    end

    -- Test 5: Custom schema
    print("\nTest 5: Custom Schema")
    local customSchema = ConfigValidator.Schema.new()
        :field("difficulty", "string"):oneOf({"easy", "normal", "hard"})
        :field("auto_save", "boolean")
        :field("max_save_slots", "number"):range(1, 10)

    local customData = {
        difficulty = "expert",  -- Invalid value
        auto_save = true,
        max_save_slots = 5
    }

    local result5 = customSchema:validate(customData, "custom")
    print("Result: " .. (result5.isValid and "PASS" or "FAIL"))
    if not result5.isValid then
        print("Errors: " .. #result5.errors)
        for _, error in ipairs(result5.errors) do
            print("  - " .. error.message)
        end
    end

    print("\n============================")
    print("Test completed! Check output above.")
end

function love.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Configuration Validator Test Complete", 10, 10)
    love.graphics.print("Check console output for detailed results", 10, 30)
    love.graphics.print("Press ESC to exit", 10, 50)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end