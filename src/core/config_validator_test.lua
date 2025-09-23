-- Configuration Validator Test Suite
-- This file contains tests to verify the configuration validation system works correctly

local ConfigValidator = require("src.core.config_validator")
local Config = require("src.content.config")
local Settings = require("src.core.settings")

local TestSuite = {}
TestSuite.__index = TestSuite

function TestSuite.new()
    local self = setmetatable({}, TestSuite)
    self.tests = {}
    self.passed = 0
    self.failed = 0
    return self
end

function TestSuite:addTest(name, testFunc)
    table.insert(self.tests, { name = name, func = testFunc })
end

function TestSuite:run()
    print("Running Configuration Validator Tests")
    print("=====================================\n")

    for _, test in ipairs(self.tests) do
        print(string.format("Running test: %s", test.name))

        local success, errorMsg = pcall(test.func)
        if success then
            print("  ✓ PASSED")
            self.passed = self.passed + 1
        else
            print(string.format("  ✗ FAILED: %s", errorMsg))
            self.failed = self.failed + 1
        end
        print()
    end

    print(string.format("Test Results: %d passed, %d failed", self.passed, self.failed))
end

-- Test functions
local function testBasicValidation()
    local result = ConfigValidator.validateSettings({
        graphics = {
            resolution = { width = 1920, height = 1080 },
            fullscreen = false,
            vsync = true
        },
        audio = {
            master_volume = 0.5,
            sfx_volume = 0.7,
            music_volume = 0.3
        }
    })

    assert(result.isValid, "Basic validation should pass for valid settings")
end

local function testInvalidRange()
    local result = ConfigValidator.validateSettings({
        graphics = {
            resolution = { width = 1920, height = 1080 },
            max_fps = 500,  -- Too high
            ui_scale = 5.0   -- Too high
        }
    })

    assert(not result.isValid, "Validation should fail for out-of-range values")
    assert(#result.errors >= 2, "Should have at least 2 errors for range violations")
end

local function testMissingRequiredField()
    local result = ConfigValidator.validateSettings({
        graphics = {
            -- Missing resolution field
            fullscreen = false
        }
    })

    assert(not result.isValid, "Validation should fail when required fields are missing")
    assert(#result.errors > 0, "Should have errors for missing required fields")
end

local function testInvalidType()
    local result = ConfigValidator.validateSettings({
        graphics = {
            resolution = { width = "1920", height = "1080" },  -- Strings instead of numbers
            fullscreen = "true"  -- String instead of boolean
        }
    })

    assert(not result.isValid, "Validation should fail for incorrect types")
    assert(#result.errors > 0, "Should have errors for type mismatches")
end

local function testDependencyValidation()
    local schema = ConfigValidator.Schema.new()
        :field("enable_feature", "boolean")
        :field("feature_setting", "string"):oneOf({"low", "high"})
        :dependsOn("enable_feature", true)

    -- Valid case: dependency satisfied
    local validResult = schema:validate({
        enable_feature = true,
        feature_setting = "high"
    })
    assert(validResult.isValid, "Validation should pass when dependencies are satisfied")

    -- Invalid case: dependency not satisfied
    local invalidResult = schema:validate({
        enable_feature = false,
        feature_setting = "high"  -- Should fail because feature is disabled
    })
    assert(not invalidResult.isValid, "Validation should fail when dependencies are not satisfied")
end

local function testCustomValidator()
    local function validateEvenNumber(value, fieldName)
        if type(value) ~= "number" then
            return false, string.format("Field '%s' must be a number", fieldName)
        end
        if value % 2 ~= 0 then
            return false, string.format("Field '%s' must be an even number", fieldName)
        end
        return true, nil
    end

    local schema = ConfigValidator.Schema.new()
        :field("even_number", validateEvenNumber)

    local validResult = schema:validate({ even_number = 42 })
    assert(validResult.isValid, "Custom validator should pass for valid values")

    local invalidResult = schema:validate({ even_number = 43 })
    assert(not invalidResult.isValid, "Custom validator should fail for invalid values")
end

local function testConfigValidation()
    local testConfig = {
        WORLD = {
            WIDTH = 30000,
            HEIGHT = 30000
        },
        SPAWN = {
            MARGIN = 75,
            INTERVAL_MIN = 2.0,
            INTERVAL_MAX = 4.0
        },
        COMBAT = {
            ALIGN_LOCK_DEG = 10,
            SHIELD_DURATION = 3.0,
            SHIELD_COOLDOWN = 5.0
        }
    }

    local result = ConfigValidator.validateConfig(testConfig)
    assert(result.isValid, "Config validation should pass for valid configuration")
end

local function testInvalidConfig()
    local testConfig = {
        WORLD = {
            WIDTH = -100,  -- Invalid negative width
            HEIGHT = 30000
        },
        COMBAT = {
            SHIELD_DURATION = 100,  -- Too long
            SHIELD_COOLDOWN = 200    -- Too long
        }
    }

    local result = ConfigValidator.validateConfig(testConfig)
    assert(not result.isValid, "Config validation should fail for invalid configuration")
    assert(#result.errors > 0, "Should have errors for invalid config values")
end

local function testResolutionValidator()
    local validator = ConfigValidator.resolution()

    -- Valid resolution
    local success, errorMsg = validator({ width = 1920, height = 1080 }, "test_resolution")
    assert(success, "Resolution validator should accept valid resolutions")

    -- Invalid resolution (missing fields)
    success, errorMsg = validator({ width = 1920 }, "test_resolution")
    assert(not success, "Resolution validator should reject incomplete resolutions")

    -- Invalid resolution (zero dimensions)
    success, errorMsg = validator({ width = 0, height = 1080 }, "test_resolution")
    assert(not success, "Resolution validator should reject zero dimensions")
end

local function testColorValidator()
    local validator = ConfigValidator.color()

    -- Valid string color
    local success, errorMsg = validator("red", "test_color")
    assert(success, "Color validator should accept valid color strings")

    -- Valid RGB table
    success, errorMsg = validator({ 1.0, 0.5, 0.0 }, "test_color")
    assert(success, "Color validator should accept valid RGB tables")

    -- Valid RGBA table
    success, errorMsg = validator({ 1.0, 0.5, 0.0, 0.8 }, "test_color")
    assert(success, "Color validator should accept valid RGBA tables")

    -- Invalid color table (wrong number of components)
    success, errorMsg = validator({ 1.0, 0.5 }, "test_color")
    assert(not success, "Color validator should reject invalid color tables")

    -- Invalid color table (out of range values)
    success, errorMsg = validator({ 1.5, 0.5, 0.0 }, "test_color")
    assert(not success, "Color validator should reject out-of-range color values")
end

local function testOneOfValidator()
    local schema = ConfigValidator.Schema.new()
        :field("difficulty", "string"):oneOf({"easy", "normal", "hard"})

    -- Valid value
    local validResult = schema:validate({ difficulty = "normal" })
    assert(validResult.isValid, "OneOf validator should accept valid values")

    -- Invalid value
    local invalidResult = schema:validate({ difficulty = "expert" })
    assert(not invalidResult.isValid, "OneOf validator should reject invalid values")
end

local function testFullValidation()
    local settings = Settings.getGraphicsSettings()
    local result = ConfigValidator.validateAll(settings, Config)

    -- This might fail if there are actual issues with the current config,
    -- but we're mainly testing that the validation runs without errors
    assert(result, "Full validation should return a result object")
    assert(type(result.isValid) == "boolean", "Result should have isValid boolean")
    assert(type(result.errors) == "table", "Result should have errors table")
    assert(type(result.warnings) == "table", "Result should have warnings table")
end

local function testErrorFormatting()
    local result = ConfigValidator.ValidationResult.new()
    result:addError("test_field", "This is a test error")
    result:addWarning("test_field2", "This is a test warning")

    local formatted = ConfigValidator.formatErrors(result)
    assert(type(formatted) == "string", "Error formatting should return a string")
    assert(string.find(formatted, "ERROR"), "Formatted errors should contain error messages")
    assert(string.find(formatted, "WARNING"), "Formatted errors should contain warning messages")
end

-- Create and run test suite
local function runTests()
    local suite = TestSuite.new()

    suite:addTest("Basic Validation", testBasicValidation)
    suite:addTest("Invalid Range Detection", testInvalidRange)
    suite:addTest("Missing Required Fields", testMissingRequiredField)
    suite:addTest("Invalid Type Detection", testInvalidType)
    suite:addTest("Dependency Validation", testDependencyValidation)
    suite:addTest("Custom Validator", testCustomValidator)
    suite:addTest("Config Validation", testConfigValidation)
    suite:addTest("Invalid Config Detection", testInvalidConfig)
    suite:addTest("Resolution Validator", testResolutionValidator)
    suite:addTest("Color Validator", testColorValidator)
    suite:addTest("OneOf Validator", testOneOfValidator)
    suite:addTest("Full Validation", testFullValidation)
    suite:addTest("Error Formatting", testErrorFormatting)

    suite:run()
end

return {
    runTests = runTests,
    TestSuite = TestSuite
}