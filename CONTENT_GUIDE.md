# Content Guide - Novus Space Game

This document provides comprehensive information about the content system, how to create new content, and how the content pipeline works.

## Table of Contents

1. [Content System Overview](#content-system-overview)
2. [Content Types](#content-types)
3. [Content Creation](#content-creation)
4. [Content Pipeline](#content-pipeline)
5. [Content Validation](#content-validation)
6. [Icon System](#icon-system)
7. [Content Examples](#content-examples)
8. [Best Practices](#best-practices)

## Content System Overview

The content system uses a **file-based approach** with automatic discovery and loading. Content is defined in Lua files within the `content/` directory and is automatically loaded when the game starts.

### Key Features

- **Auto-Discovery**: Automatically finds and loads content files
- **Validation**: Ensures content integrity and consistency
- **Normalization**: Converts content to canonical format
- **Icon Generation**: Creates procedural icons from shape definitions
- **Hot Reloading**: Content can be reloaded during development

### Content Directory Structure

```
content/
├── items/              # Equipment, resources, modules
│   ├── index.lua       # Item registry
│   ├── stones.lua      # Mining resources
│   ├── scraps.lua      # Salvage materials
│   └── shield_module_basic.lua
├── ships/              # Ship definitions
│   ├── index.lua       # Ship registry
│   ├── starter_frigate_basic.lua
│   ├── basic_drone.lua
│   └── boss_drone.lua
├── turrets/            # Weapon systems
│   ├── basic_gun.lua
│   ├── laser_mk1.lua
│   ├── rocket_mk1.lua
│   └── mining_laser.lua
├── projectiles/        # Ammunition types
│   ├── gun_bullet.lua
│   ├── laser_beam.lua
│   ├── missile.lua
│   └── giant_bullet.lua
├── world_objects/      # Stations, asteroids, planets
│   ├── asteroid_medium.lua
│   ├── hub_station.lua
│   ├── beacon_station.lua
│   └── planet_massive.lua
└── sounds/             # Audio files
    ├── music/
    └── sfx/
```

## Content Types

### 1. Items (`content/items/`)

Items are equipment, resources, and modules that can be collected, traded, or equipped.

#### Item Structure
```lua
return {
    id = "item_id",                    -- Unique identifier
    name = "Item Name",                -- Display name
    description = "Item description",   -- Tooltip text
    category = "equipment",            -- Item category
    value = 100,                       -- Base value in credits
    stackable = true,                  -- Can be stacked
    maxStack = 100,                    -- Maximum stack size
    icon = {                           -- Icon definition
        shapes = {
            {type = "circle", color = {1, 0, 0}, radius = 0.4}
        }
    },
    -- Equipment-specific properties
    equipment = {
        slot = "shield",               -- Equipment slot
        stats = {                      -- Stat bonuses
            shieldHp = 50,
            energyRegen = 5
        }
    }
}
```

#### Item Categories
- **equipment**: Shields, engines, weapons
- **resource**: Ores, materials, currency
- **module**: Upgrade components
- **consumable**: One-time use items

### 2. Ships (`content/ships/`)

Ships are player and AI-controlled vessels with various capabilities.

#### Ship Structure
```lua
return {
    id = "ship_id",                    -- Unique identifier
    name = "Ship Name",                -- Display name
    description = "Ship description",  -- Tooltip text
    mass = 500,                        -- Ship mass
    engine = {                         -- Engine properties
        thrust = 200,                  -- Thrust force
        turnRate = 2.0,                -- Turn rate (rad/s)
        mass = 100                     -- Engine mass
    },
    turrets = {                        -- Turret slots
        {slot = 1, turret = "basic_gun"},
        {slot = 2, turret = "laser_mk1"}
    },
    visuals = {                        -- Visual properties
        kind = "ship",                 -- Visual type
        size = 1.0,                    -- Scale multiplier
        color = {0.8, 0.8, 1.0}       -- Tint color
    },
    icon = {                           -- Icon definition
        shapes = {
            {type = "polygon", color = {0.5, 0.5, 1.0}, 
             points = {{-0.5, -0.3}, {0.5, 0}, {-0.5, 0.3}}}
        }
    }
}
```

### 3. Turrets (`content/turrets/`)

Turrets are weapon systems that can be equipped on ships.

#### Turret Structure
```lua
return {
    id = "turret_id",                  -- Unique identifier
    name = "Turret Name",              -- Display name
    description = "Turret description", -- Tooltip text
    projectile = "gun_bullet",         -- Projectile type
    fireRate = 2.0,                    -- Shots per second
    range = 400,                       -- Maximum range
    energyCost = 10,                   -- Energy cost per shot
    damage = 25,                       -- Base damage
    accuracy = 0.9,                    -- Hit chance (0-1)
    visuals = {                        -- Visual properties
        kind = "turret",               -- Visual type
        size = 0.8,                    -- Scale multiplier
        color = {1.0, 0.8, 0.2}       -- Tint color
    },
    icon = {                           -- Icon definition
        shapes = {
            {type = "rect", color = {0.8, 0.6, 0.2}, 
             width = 0.6, height = 0.3}
        }
    }
}
```

### 4. Projectiles (`content/projectiles/`)

Projectiles are ammunition types fired by turrets.

#### Projectile Structure
```lua
return {
    id = "projectile_id",              -- Unique identifier
    name = "Projectile Name",          -- Display name
    speed = 800,                       -- Movement speed
    lifetime = 3.0,                    -- Time to live (seconds)
    damage = 25,                       -- Damage on hit
    pierce = false,                    -- Can pierce through enemies
    homing = false,                    -- Homing behavior
    homingStrength = 0.0,              -- Homing strength (0-1)
    visuals = {                        -- Visual properties
        kind = "projectile",           -- Visual type
        size = 0.3,                    -- Scale multiplier
        color = {1.0, 1.0, 0.0}       -- Tint color
    }
}
```

### 5. World Objects (`content/world_objects/`)

World objects are static entities like stations, asteroids, and planets.

#### World Object Structure
```lua
return {
    id = "object_id",                  -- Unique identifier
    name = "Object Name",              -- Display name
    description = "Object description", -- Tooltip text
    mass = 1000,                       -- Object mass
    radius = 50,                       -- Collision radius
    repairable = true,                 -- Can be repaired
    mineable = false,                  -- Can be mined
    lootable = true,                   -- Can drop loot
    visuals = {                        -- Visual properties
        kind = "station",              -- Visual type
        size = 2.0,                    -- Scale multiplier
        color = {0.2, 0.8, 0.2}       -- Tint color
    },
    icon = {                           -- Icon definition
        shapes = {
            {type = "circle", color = {0.2, 0.8, 0.2}, radius = 0.5}
        }
    }
}
```

## Content Creation

### Step 1: Create Content File

1. Navigate to the appropriate content directory
2. Create a new `.lua` file with a descriptive name
3. Use the content structure template for your content type

### Step 2: Define Content Properties

1. Set the `id` field (must be unique)
2. Add required properties for your content type
3. Define visual properties and icon
4. Add any special behaviors or stats

### Step 3: Test Content

1. Start the game to load the new content
2. Check the debug panel for any validation errors
3. Test the content in-game to ensure it works correctly

### Example: Creating a New Weapon

```lua
-- content/turrets/plasma_cannon.lua
return {
    id = "plasma_cannon",
    name = "Plasma Cannon",
    description = "A powerful energy weapon that fires plasma bolts",
    projectile = "plasma_bolt",
    fireRate = 1.5,
    range = 600,
    energyCost = 25,
    damage = 40,
    accuracy = 0.85,
    visuals = {
        kind = "turret",
        size = 1.2,
        color = {0.8, 0.2, 1.0}
    },
    icon = {
        shapes = {
            {type = "circle", color = {0.8, 0.2, 1.0}, radius = 0.4},
            {type = "rect", color = {0.6, 0.1, 0.8}, width = 0.3, height = 0.6}
        }
    }
}
```

## Content Pipeline

### 1. Discovery Phase (`src/content/design_loader.lua`)

The content loader scans the `content/` directories and discovers all `.lua` files:

```lua
-- Scans content/items/ for item definitions
local items = list_modules("content/items", "content.items")

-- Scans content/ships/ for ship definitions
local ships = list_modules("content/ships", "content.ships")
```

### 2. Loading Phase (`src/content/content.lua`)

Each content file is loaded and processed:

```lua
-- Load item definition
local def = require_strict(modName)

-- Validate content
Validator.item(def)

-- Create item object
local item = Item.fromDef(def)
```

### 3. Validation Phase (`src/content/validator.lua`)

Content is validated to ensure integrity:

```lua
function Validator.item(def)
    assert(def.id, "Item must have id")
    assert(def.name, "Item must have name")
    assert(def.category, "Item must have category")
    -- ... more validation
end
```

### 4. Normalization Phase (`src/content/normalizer.lua`)

Content is normalized to canonical format:

```lua
function Normalizer.normalizeShip(def)
    local normalized = {
        id = def.id,
        name = def.name or def.id,
        mass = def.mass or 500,
        engine = def.engine or {thrust = 100, turnRate = 1.0},
        -- ... fill in defaults
    }
    return normalized
end
```

### 5. Icon Generation Phase (`src/content/icon_renderer.lua`)

Procedural icons are generated from shape definitions:

```lua
function IconRenderer.renderIcon(iconDef, size, id)
    local canvas = love.graphics.newCanvas(size, size)
    love.graphics.setCanvas(canvas)
    
    -- Render shapes
    for _, shape in ipairs(iconDef.shapes) do
        renderShape(shape, size)
    end
    
    love.graphics.setCanvas()
    return canvas
end
```

## Content Validation

### Validation Rules

Each content type has specific validation rules:

#### Item Validation
- Must have `id`, `name`, `category`
- `value` must be a positive number
- `icon` must have valid shape definitions

#### Ship Validation
- Must have `id`, `name`
- `mass` must be positive
- `engine` must have `thrust` and `turnRate`
- `turrets` must be valid turret references

#### Turret Validation
- Must have `id`, `name`, `projectile`
- `fireRate` must be positive
- `range` must be positive
- `damage` must be non-negative

### Validation Errors

Validation errors are logged and displayed in the debug panel:

```lua
-- Example validation error
Log.error("Item validation failed: missing required field 'category'")
```

## Icon System

### Icon Definition Format

Icons are defined using a shape-based system:

```lua
icon = {
    shapes = {
        {
            type = "circle",           -- Shape type
            color = {1, 0, 0},         -- RGB color (0-1)
            radius = 0.4,              -- Radius (0-1)
            x = 0, y = 0               -- Position (0-1)
        },
        {
            type = "rect",             -- Rectangle
            color = {0, 1, 0},
            width = 0.6, height = 0.3,
            x = 0, y = 0
        },
        {
            type = "polygon",          -- Custom polygon
            color = {0, 0, 1},
            points = {{-0.5, -0.3}, {0.5, 0}, {-0.5, 0.3}}
        }
    }
}
```

### Supported Shape Types

- **circle**: Circular shapes
- **rect**: Rectangular shapes
- **polygon**: Custom polygonal shapes
- **line**: Line segments

### Icon Caching

Generated icons are cached for performance:

```lua
-- Icons are cached by size and content
local cacheKey = size .. "_" .. contentId
if iconCache[cacheKey] then
    return iconCache[cacheKey]
end
```

## Content Examples

### Example 1: Mining Resource

```lua
-- content/items/tritanium_ore.lua
return {
    id = "tritanium_ore",
    name = "Tritanium Ore",
    description = "A rare metal used in advanced ship construction",
    category = "resource",
    value = 150,
    stackable = true,
    maxStack = 50,
    icon = {
        shapes = {
            {type = "circle", color = {0.8, 0.8, 0.2}, radius = 0.4},
            {type = "rect", color = {0.6, 0.6, 0.1}, width = 0.2, height = 0.6}
        }
    }
}
```

### Example 2: Combat Ship

```lua
-- content/ships/assault_frigate.lua
return {
    id = "assault_frigate",
    name = "Assault Frigate",
    description = "A heavily armed warship designed for combat",
    mass = 800,
    engine = {
        thrust = 300,
        turnRate = 1.5,
        mass = 150
    },
    turrets = {
        {slot = 1, turret = "plasma_cannon"},
        {slot = 2, turret = "rocket_mk1"},
        {slot = 3, turret = "laser_mk1"}
    },
    visuals = {
        kind = "ship",
        size = 1.2,
        color = {0.8, 0.2, 0.2}
    },
    icon = {
        shapes = {
            {type = "polygon", color = {0.8, 0.2, 0.2}, 
             points = {{-0.6, -0.4}, {0.6, 0}, {-0.6, 0.4}}},
            {type = "rect", color = {0.6, 0.1, 0.1}, width = 0.3, height = 0.8}
        }
    }
}
```

### Example 3: Station

```lua
-- content/world_objects/trading_post.lua
return {
    id = "trading_post",
    name = "Trading Post",
    description = "A commercial station offering goods and services",
    mass = 2000,
    radius = 80,
    repairable = true,
    mineable = false,
    lootable = false,
    visuals = {
        kind = "station",
        size = 1.5,
        color = {0.2, 0.8, 0.8}
    },
    icon = {
        shapes = {
            {type = "circle", color = {0.2, 0.8, 0.8}, radius = 0.5},
            {type = "rect", color = {0.1, 0.6, 0.6}, width = 0.8, height = 0.3}
        }
    }
}
```

## Best Practices

### 1. Naming Conventions

- Use descriptive, consistent names
- Use snake_case for IDs
- Use proper capitalization for display names
- Include version numbers for variants (e.g., `laser_mk2`)

### 2. Content Organization

- Group related content in the same directory
- Use consistent file naming
- Include comprehensive descriptions
- Add comments for complex properties

### 3. Icon Design

- Keep icons simple and recognizable
- Use consistent color schemes
- Ensure icons work at different sizes
- Test icons in the game UI

### 4. Performance Considerations

- Minimize complex shape definitions
- Use appropriate icon sizes
- Avoid excessive content files
- Test content loading performance

### 5. Content Balance

- Ensure content is balanced for gameplay
- Test content in different scenarios
- Consider progression and difficulty curves
- Gather feedback from playtesting

---

This content guide provides comprehensive information about creating and managing game content. For specific implementation details, refer to the content system source files and existing content examples.
