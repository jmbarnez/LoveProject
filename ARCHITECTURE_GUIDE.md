# Architecture Guide - Novus Space Game

This document provides detailed information about the technical architecture of the Novus space game, focusing on how different systems interact and how to extend the codebase.

## Table of Contents

1. [Entity-Component System](#entity-component-system)
2. [Core Systems Architecture](#core-systems-architecture)
3. [Content Pipeline](#content-pipeline)
4. [Rendering Pipeline](#rendering-pipeline)
5. [Event System](#event-system)
6. [UI Architecture and Input](#ui-architecture-and-input)
7. [Memory Management](#memory-management)
8. [Performance Considerations](#performance-considerations)

## Entity-Component System

### Overview

The game uses a **hybrid ECS pattern** where:
- **Entities** are tables with an `id` and `components` table
- **Components** are data containers attached to entities
- **Systems** process entities based on their component composition

### Entity Structure

```lua
entity = {
    id = 123,                    -- Unique identifier
    components = {
        position = { x = 100, y = 200 },
        velocity = { x = 50, y = 0 },
        health = { hp = 100, maxHp = 100 },
        renderable = { ... }
    },
    -- Additional entity-specific data
    isPlayer = true,
    shipId = "starter_frigate_basic"
}
```

### Core Components

#### Position Component (`src/components/position.lua`)
```lua
{
    x = number,    -- World X coordinate
    y = number     -- World Y coordinate
}
```

#### Velocity Component (`src/components/velocity.lua`)
```lua
{
    x = number,    -- X velocity (units/second)
    y = number     -- Y velocity (units/second)
}
```

#### Health Component (`src/components/health.lua`)
```lua
{
    hp = number,           -- Current health points
    maxHp = number,        -- Maximum health points
    energy = number,       -- Current energy
    maxEnergy = number,    -- Maximum energy
    shieldHp = number,     -- Current shield health
    maxShieldHp = number   -- Maximum shield health
}
```

#### Physics Component (`src/components/physics.lua`)
```lua
{
    body = {
        mass = number,           -- Entity mass
        radius = number,         -- Collision radius
        skipThrusterForce = boolean  -- Skip physics force (player control)
    }
}
```

#### Renderable Component (`src/components/renderable.lua`)
```lua
{
    props = {
        visuals = {
            kind = string,       -- Visual type (ship, projectile, etc.)
            size = number,       -- Scale multiplier
            color = {r, g, b, a} -- Tint color
        }
    }
}
```

#### AI Component (`src/components/ai.lua`)
```lua
{
    state = string,        -- Current AI state (idle, hunting, retreating)
    target = entity,       -- Current target entity
    aggroRange = number,   -- Detection range
    lastSeenTarget = {x, y} -- Last known target position
}
```

### Entity Factory Pattern

The `EntityFactory` (`src/templates/entity_factory.lua`) provides a unified way to create entities:

```lua
-- Create a ship
local ship = EntityFactory.create("ship", "ship_id", x, y, extraConfig)

-- Create an enemy
local enemy = EntityFactory.createEnemy("enemy_id", x, y)

-- Create a projectile
local projectile = EntityFactory.create("projectile", "bullet_id", x, y, {
    angle = angle,
    friendly = true,
    damage = 25
})
```

## Core Systems Architecture

### System Update Order

The game systems are updated in a specific order each frame:

```lua
-- In src/game.lua Game.update()
1. Input.update(dt)                    -- Process input
2. PlayerSystem.update(dt, ...)        -- Player logic
3. AISystem.update(dt, ...)            -- Enemy AI
4. PhysicsSystem.update(dt, ...)       -- Physics simulation
5. BoundarySystem.update(world)        -- World boundaries
6. collisionSystem:update(world, dt)   -- Collision detection
7. DestructionSystem.update(world, ...) -- Handle deaths
8. SpawningSystem.update(dt, ...)      -- Spawn new entities
9. MiningSystem.update(dt, ...)        -- Mining mechanics
10. Pickups.update(dt, ...)            -- Item collection
11. Effects.update(dt)                 -- Visual effects
12. QuestSystem.update(player)         -- Quest processing
13. camera:update(dt)                  -- Camera movement
14. world:update(dt)                   -- Entity cleanup
```

### System Communication

Systems communicate through:

1. **Direct Entity Access**: Systems query entities by component type
2. **Event System**: Decoupled communication via events
3. **Shared State**: Global game state (world, player, etc.)

#### Entity Querying

```lua
-- Get all entities with specific components
local entities = world:get_entities_with_components("ai", "position", "velocity")

-- Get entities in spatial region
local entities = world:getEntitiesInRect({x, y, width, height})
```

#### Event Communication

```lua
-- Emit event
Events.emit(Events.GAME_EVENTS.ENTITY_DESTROYED, {
    entity = entity,
    killer = killer
})

-- Listen for event
Events.on(Events.GAME_EVENTS.ENTITY_DESTROYED, function(data)
    -- Handle entity destruction
end)
```

## Content Pipeline

### Content Discovery

The content system automatically discovers and loads game content:

1. **File Scanning** (`src/content/design_loader.lua`):
   - Scans `content/` directories
   - Finds `.lua` files (excluding `index.lua`)
   - Loads each file as a module

2. **Validation** (`src/content/validator.lua`):
   - Ensures required fields are present
   - Validates data types and ranges
   - Reports validation errors

3. **Normalization** (`src/content/normalizer.lua`):
   - Converts content to canonical format
   - Fills in default values
   - Ensures consistency across content types

4. **Icon Generation** (`src/content/icon_renderer.lua`):
   - Renders procedural icons from shape definitions
   - Caches generated icons
   - Handles different icon sizes

### Content Structure

#### Item Definition```lua
-- content/items/example_item.lua
return {
    id = "example_item",
    name = "Example Item",
    description = "A sample item",
    category = "equipment",
    value = 100,
    icon = {
        shapes = {
            {type = "circle", color = {1, 0, 0}, radius = 0.4}
        }
    }
}```

#### Ship Definition
```lua
-- content/ships/example_ship.lua
return {
    id = "example_ship",
    name = "Example Ship",
    mass = 500,
    engine = {
        thrust = 200,
        turnRate = 2.0,
        mass = 100
    },
    turrets = {
        {slot = 1, turret = "basic_gun"},
        {slot = 2, turret = "laser_mk1"}
    },
    visuals = {
        kind = "ship",
        size = 1.0,
        color = {0.8, 0.8, 1.0}
    }
}
```

## Rendering Pipeline

### Render Order

The rendering system draws entities in a specific order:

1. **Background**: Starfield, nebula, planets
2. **World Objects**: Stations, asteroids, warp gates
3. **Entities**: Ships, projectiles, effects
4. **Player**: Player ship (always on top)
5. **UI Overlay**: HUD, panels, tooltips
6. **Effects**: Particle effects, explosions
7. **Debug**: Debug information (if enabled)

### Render System Architecture

#### Main Render System (`src/systems/render.lua`)
- Coordinates all rendering
- Manages render order
- Handles camera transformations

#### Entity Renderers (`src/systems/render/entity_renderers.lua`)
- Renders different entity types
- Handles visual effects
- Manages sprite batching

#### Player Renderer (`src/systems/render/player_renderer.lua`)
- Specialized player rendering
- Handles player-specific effects
- Manages targeting reticle

### Camera System

The camera system (`src/core/camera.lua`) provides:

- **Smooth Following**: Interpolated camera movement
- **Viewport Management**: Screen space calculations
- **Zoom Control**: Scale management
- **Bounds Checking**: Prevent camera from going out of world

```lua
-- Camera usage
camera:setTarget(player)           -- Follow entity
camera:apply()                     -- Apply transformations
camera:reset()                     -- Reset transformations
```

## Event System

### Event Architecture

The event system (`src/core/events.lua`) provides:

- **Decoupled Communication**: Systems don't need direct references
- **Event Queuing**: Events are processed at the end of each frame
- **Type Safety**: Events have defined data structures
- **Debug Support**: Event logging and debugging

### Event Types

#### Game Events (`src/core/events.lua`)
```lua
GAME_EVENTS = {
    ENTITY_DESTROYED = "entity_destroyed",
    PLAYER_DAMAGED = "player_damaged",
    ITEM_PICKED_UP = "item_picked_up",
    QUEST_STARTED = "quest_started",
    QUEST_COMPLETED = "quest_completed"
}
```

## UI Architecture and Input

### Source of Truth for UI Sizing
All UI layout/sizing is driven by `Theme.ui` (in `src/core/theme.lua`):

```
Theme.ui = {
  titleBarHeight, borderWidth, contentPadding,
  buttonHeight, buttonSpacing, menuButtonPaddingX,
}
```

Windows, common widgets, and panels should read from `Theme.ui` instead of hardcoding numbers.

### Modal Input Flow
- `UIManager` routes input to visible components with z-ordering.
- When Escape menu or other modal UI is open, input is consumed at the UI layer, and `PlayerSystem` also gates gameplay controls using `UIManager.isModalActive()`.
- Mouse wheel events are consumed by UI when modals are active.

Relevant code paths:
- UI routing: `src/core/ui_manager.lua` (mouse/key/text/wheel)
- Global gameplay gate: `src/systems/player.lua` (checks modalActive)
- Escape menu consumption: `src/ui/escape_menu.lua`

#### Event Data Structures
```lua
-- Entity destroyed event
{
    entity = entity,        -- The destroyed entity
    killer = entity,        -- Entity that caused destruction
    position = {x, y}       -- Destruction position
}

-- Player damaged event
{
    entity = player,        -- Player entity
    damage = number,        -- Damage amount
    source = entity         -- Damage source
}
```

### Event Usage Patterns

#### Emitting Events
```lua
-- Emit event immediately
Events.emit(Events.GAME_EVENTS.ENTITY_DESTROYED, eventData)

-- Queue event for end of frame
Events.queue(Events.GAME_EVENTS.ENTITY_DESTROYED, eventData)
```

#### Listening for Events
```lua
-- One-time listener
Events.once(Events.GAME_EVENTS.QUEST_COMPLETED, function(data)
    -- Handle quest completion
end)

-- Persistent listener
Events.on(Events.GAME_EVENTS.PLAYER_DAMAGED, function(data)
    -- Handle player damage
end)

-- Remove listener
Events.off(Events.GAME_EVENTS.PLAYER_DAMAGED, handler)
```

## Memory Management

### Entity Lifecycle

1. **Creation**: Via `EntityFactory.create()`
2. **Registration**: Added to world via `world:addEntity()`
3. **Update**: Processed by systems each frame
4. **Destruction**: Marked as dead, removed from world
5. **Cleanup**: Garbage collected by Lua

### Memory Optimization

- **Entity Pooling**: Reuse entity objects when possible
- **Component Caching**: Cache frequently accessed components
- **Spatial Indexing**: Use quadtree for efficient spatial queries
- **Icon Caching**: Cache generated icons to avoid regeneration

### Garbage Collection

The game uses Lua's automatic garbage collection with some optimizations:

- **Explicit Cleanup**: Remove references when entities are destroyed
- **Batch Operations**: Group similar operations to reduce GC pressure
- **Object Reuse**: Reuse tables and objects when possible

## Performance Considerations

### Frame Rate Management

- **Target FPS**: 60 FPS with configurable limit
- **Frame Time Limiting**: Sleep to maintain consistent frame rate
- **Delta Time**: All updates use delta time for frame-rate independence

### Spatial Optimization

- **Quadtree**: Used for collision detection and spatial queries
- **Viewport Culling**: Only render entities within camera view
- **Distance Culling**: Skip rendering for distant entities

### Rendering Optimization

- **Sprite Batching**: Group similar sprites for efficient rendering
- **Canvas Caching**: Cache complex rendered content
- **LOD System**: Use different detail levels based on distance

### System Optimization

- **Component Filtering**: Only process entities with required components
- **System Ordering**: Optimize system update order for efficiency
- **Event Batching**: Process events in batches to reduce overhead

### Profiling and Debugging

- **Debug Panel**: Real-time performance metrics (F1)
- **Frame Timing**: Track update and render times
- **Entity Counts**: Monitor active entity counts
- **Memory Usage**: Track memory allocation patterns

---

This architecture guide provides the technical foundation for understanding and extending the Novus codebase. For implementation details, refer to the specific source files and their inline documentation.
