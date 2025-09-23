# Configuration Validator

A comprehensive, extensible configuration validation system for Lua applications. This system provides robust validation for configuration files, user settings, and runtime parameters with helpful error messages and dependency checking.

## Features

- **Schema-based validation**: Define validation rules using flexible schemas
- **Type validation**: Built-in support for numbers, strings, booleans, tables
- **Range validation**: Validate numeric values within specified ranges
- **Required field validation**: Ensure critical fields are present
- **Dependency validation**: Validate relationships between configuration options
- **Custom validators**: Create custom validation functions for complex requirements
- **Extensible design**: Easy to add new validation rules and schemas
- **Helpful error messages**: Clear, descriptive error reporting
- **Warning system**: Non-critical issues reported as warnings

## Quick Start

```lua
local ConfigValidator = require("src.core.config_validator")

-- Basic validation
local settings = {
    graphics = {
        resolution = { width = 1920, height = 1080 },
        fullscreen = false,
        max_fps = 60
    }
}

local result = ConfigValidator.validateSettings(settings)

if result.isValid then
    print("Settings are valid!")
else
    print("Validation failed:")
    print(ConfigValidator.formatErrors(result))
end
```

## Core Concepts

### ValidationResult

The result of any validation operation. Contains:
- `isValid`: Boolean indicating if validation passed
- `errors`: Array of error objects with `field` and `message` properties
- `warnings`: Array of warning objects with `field` and `message` properties

### Schema

Defines validation rules for a configuration object. Use the fluent interface:

```lua
local schema = ConfigValidator.Schema.new()
    :field("name", "string")
    :field("age", "number"):range(0, 150)
    :field("email", "string"):required()
```

## Built-in Validators

### Type Validators

- `"number"`: Validates numeric values
- `"string"`: Validates string values
- `"boolean"`: Validates boolean values
- `"table"`: Validates table values

### Range Validators

```lua
ConfigValidator.number(min, max)  -- Validates number within range
ConfigValidator.positiveNumber()  -- Validates number >= 0
ConfigValidator.negativeNumber()  -- Validates number <= 0
ConfigValidator.percentage()      -- Validates number between 0 and 1
```

### Specialized Validators

```lua
ConfigValidator.resolution()      -- Validates {width, height} tables
ConfigValidator.color()           -- Validates color strings or RGB/RGBA tables
```

## Schema Definition

### Basic Field Definition

```lua
local schema = ConfigValidator.Schema.new()
    :field("fieldName", "validatorType")
    :field("anotherField", "number"):range(1, 100)
    :field("requiredField", "string"):required()
```

### Field Options

```lua
:range(min, max)           -- Numeric range validation
:oneOf({"option1", "option2"})  -- Enum validation
:dependsOn("field", value) -- Dependency validation
:required()                -- Mark field as required
```

### Dependencies

```lua
local schema = ConfigValidator.Schema.new()
    :field("enable_feature", "boolean")
    :field("feature_setting", "string"):oneOf({"low", "high"})
    :dependsOn("enable_feature", true)  -- Only validate if enable_feature is true
```

## Custom Validators

Create custom validation functions:

```lua
local function validatePlayerName(value, fieldName)
    if type(value) ~= "string" then
        return false, string.format("Field '%s' must be a string", fieldName)
    end

    if #value < 3 or #value > 20 then
        return false, string.format("Field '%s' must be 3-20 characters", fieldName)
    end

    return true, nil
end

local schema = ConfigValidator.Schema.new()
    :field("player_name", validatePlayerName)
```

## Predefined Schemas

The validator includes predefined schemas for common configurations:

### Settings Validation

```lua
-- Validate user settings
local result = ConfigValidator.validateSettings(userSettings)
```

### Configuration Validation

```lua
-- Validate game configuration
local result = ConfigValidator.validateConfig(gameConfig)
```

### Full Validation

```lua
-- Validate both settings and config
local result = ConfigValidator.validateAll(settings, config)
```

## Error Handling

### Formatting Errors

```lua
local formatted = ConfigValidator.formatErrors(result)
print(formatted)  -- Human-readable error messages
```

### Logging Errors

```lua
ConfigValidator.logErrors(result)  -- Logs to your logging system
```

## Extending the System

### Adding New Schemas

```lua
-- Add to the schemas table
ConfigValidator.schemas.myCustom = Schema.new()
    :field("custom_field", "string")
    :field("custom_number", "number"):range(0, 100)
```

### Creating New Validator Types

```lua
function ConfigValidator.email()
    return function(value, fieldName)
        if type(value) ~= "string" then
            return false, string.format("Field '%s' must be a string", fieldName)
        end

        if not value:match("@") then
            return false, string.format("Field '%s' must be a valid email", fieldName)
        end

        return true, nil
    end
end
```

## Integration Examples

### Loading and Validating Settings

```lua
local Settings = require("src.core.settings")
local ConfigValidator = require("src.core.config_validator")

local function loadAndValidateSettings()
    Settings.load()  -- Load from file

    local settings = {
        graphics = Settings.getGraphicsSettings(),
        audio = Settings.getAudioSettings(),
        keymap = Settings.getKeymap(),
        hotbar = Settings.getHotbarSettings()
    }

    local result = ConfigValidator.validateSettings(settings)

    if not result.isValid then
        ConfigValidator.logErrors(result)
        -- Handle validation failure (use defaults, show UI, etc.)
        return false
    end

    return true
end
```

### Validating Configuration at Startup

```lua
local Config = require("src.content.config")
local ConfigValidator = require("src.core.config_validator")

local function validateGameConfig()
    local result = ConfigValidator.validateConfig(Config)

    if not result.isValid then
        print("Configuration validation failed!")
        print(ConfigValidator.formatErrors(result))

        -- Optionally exit or use fallback configuration
        return false
    end

    if #result.warnings > 0 then
        print("Configuration warnings:")
        print(ConfigValidator.formatErrors(result))
    end

    return true
end
```

### Runtime Configuration Updates

```lua
local function updateSettings(newSettings)
    local result = ConfigValidator.validateSettings(newSettings)

    if result.isValid then
        Settings.applySettings(newSettings.graphics, newSettings.audio)
        return true
    else
        print("Invalid settings provided:")
        print(ConfigValidator.formatErrors(result))
        return false
    end
end
```

## Best Practices

1. **Validate early**: Run validation when loading configuration files
2. **Provide fallbacks**: Have default values for invalid configurations
3. **Log warnings**: Use warnings for non-critical issues that don't prevent operation
4. **User-friendly errors**: Show clear messages to users when validation fails
5. **Modular schemas**: Break complex configurations into smaller, focused schemas
6. **Test validators**: Use the test suite to verify your validation logic

## Testing

Run the test suite to verify the validator works correctly:

```lua
local TestSuite = require("src.core.config_validator_test")
local suite = TestSuite.new()
suite:run()
```

## API Reference

### ConfigValidator

- `validateSettings(settings)`: Validate user settings
- `validateConfig(config)`: Validate game configuration
- `validateAll(settings, config)`: Validate both settings and config
- `formatErrors(result)`: Format validation results as readable text
- `logErrors(result)`: Log validation results using the logging system

### Schema

- `Schema.new()`: Create a new schema
- `field(name, validator, options)`: Add a field to the schema
- `required()`: Mark the last field as required
- `range(min, max)`: Set numeric range for the last field
- `oneOf(options)`: Set allowed values for the last field
- `dependsOn(field, value)`: Set dependency for the last field
- `validate(data, context)`: Validate data against the schema

### ValidationResult

- `isValid`: Boolean validation status
- `errors`: Array of error objects
- `warnings`: Array of warning objects
- `addError(field, message)`: Add an error
- `addWarning(field, message)`: Add a warning
- `merge(other)`: Merge with another result

## License

This configuration validator is part of the game project and follows the same licensing terms.