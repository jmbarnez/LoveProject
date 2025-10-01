# Novus - Space Trading & Combat Game

A Love2D-based space trading and combat game inspired by DarkOrbit, featuring ship customization, quests, mining, trading, and multiplayer capabilities.

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Core Systems](#core-systems)
4. [Content System](#content-system)
5. [UI System](#ui-system)
6. [File Structure](#file-structure)
7. [Getting Started](#getting-started)
8. [Development Guide](#development-guide)

## Project Overview

**Novus** is a 2D space game built with Love2D (Lua) featuring:

- **Space Combat**: Ship-to-ship combat with various weapons and projectiles
- **Trading System**: Buy/sell items, ships, and equipment
- **Mining**: Extract resources from asteroids
- **Quest System**: Procedural and scripted missions
- **Ship Customization**: Equip different turrets and modules
- **Multiplayer**: Basic multiplayer support
- **Trading Nodes**: Stock market simulation with technical analysis
- **Sector Warping**: Travel between different galactic sectors

### Key Features

- **Entity-Component System**: Modular entity architecture
- **Procedural Content**: Auto-discovery of content files
- **Real-time Combat**: Physics-based movement and collision
- **Persistent World**: Save/load game state
- **Modular UI**: Tabbed interface with multiple panels
- **Sound System**: Music and SFX with distance-based attenuation

## Architecture

### Core Architecture Pattern

The game follows an **Entity-Component-System (ECS)** pattern with some variations:

- **Entities**: Game objects (ships, projectiles, stations, etc.)
- **Components**: Data containers (position, health, renderable, etc.)
- **Systems**: Logic processors that operate on entities with specific components

### Main Entry Points

- **`main.lua`**: Love2D entry point, handles screen transitions and main loop
- **`src/game.lua`**: Core game logic, system orchestration, and world management
- **`conf.lua`**: Love2D configuration (window settings, etc.)

### Key Architectural Components

#### 1. Entity Factory System
- **Location**: `src/templates/entity_factory.lua`
- **Purpose**: Universal entity creation from content definitions
- **Supports**: Ships, projectiles, world objects, stations, warp gates

#### 2. Content System
- **Location**: `src/content/`
- **Purpose**: Auto-discovery and loading of game content
- **Features**: Validation, normalization, icon generation

#### 3. World Management
- **Location**: `src/core/world.lua`
- **Purpose**: Entity storage, spatial queries, background rendering
- **Features**: Quadtree for collision detection, parallax starfield

#### 4. System Orchestration
- **Location**: `src/systems/`
- **Purpose**: Game logic systems (AI, physics, rendering, etc.)
- **Pattern**: Each system operates on entities with specific components

## Core Systems

### Game Loop Systems (in order)

1. **Input System** (`src/systems/player.lua`)
   - Processes player input
   - Handles movement, combat, UI interactions

2. **AI System** (`src/systems/ai.lua`)
   - Enemy ship behavior
   - State machines (idle, hunting, retreating)
   - Target acquisition and combat logic

3. **Physics System** (`src/systems/physics.lua`)
   - Movement and velocity updates
   - Thruster effects and engine trails

4. **Collision System** (`src/systems/collision/`)
   - Entity-to-entity collisions
   - Projectile hits and damage application
   - Spatial queries using quadtree

5. **Destruction System** (`src/systems/destruction.lua`)
   - Handles entity death
   - Spawns wreckage and loot
   - Triggers death events

6. **Spawning System** (`src/systems/spawning.lua`)
   - Enemy spawn management
   - Safe zone enforcement
   - Difficulty scaling

7. **Mining System** (`src/systems/mining.lua`)
   - Asteroid mining mechanics
   - Resource extraction
   - Mining progression

8. **Pickup System** (`src/systems/pickups.lua`)
   - Item collection
   - Magnetic pickup effects
   - Inventory management

9. **Quest System** (`src/systems/quest_system.lua`)
   - Quest tracking and completion
   - Event-based progress updates
   - Reward distribution

10. **Render System** (`src/systems/render/`)
    - Entity rendering
    - UI overlay
    - Special effects

### Supporting Systems

- **Sound System** (`src/core/sound.lua`): Audio management with distance attenuation
- **Event System** (`src/core/events.lua`): Decoupled event communication
- **State Manager** (`src/managers/state_manager.lua`): Save/load functionality
- **Multiplayer** (`src/core/multiplayer.lua`): Network synchronization
- **Node Market** (`src/systems/node_market.lua`): Trading node simulation

## Content System

### Content Structure

The game uses a **file-based content system** with auto-discovery:

```
content/
├── items/          # Equipment, resources, modules
├── ships/          # Ship definitions
├── turrets/        # Weapon systems
├── projectiles/    # Ammunition types
├── world_objects/  # Stations, asteroids, planets
└── sounds/         # Audio files
```

### Content Loading Process

1. **Discovery** (`src/content/design_loader.lua`): Scans content directories
2. **Validation** (`src/content/validator.lua`): Ensures content integrity
3. **Normalization** (`src/content/normalizer.lua`): Standardizes data format
4. **Icon Generation** (`src/content/icon_renderer.lua`): Creates UI icons
5. **Storage** (`src/content/content.lua`): Caches loaded content

### Adding New Content

1. **Create Definition File**: Add `.lua` file in appropriate content directory
2. **Define Structure**: Follow existing patterns for your content type
3. **Auto-Discovery**: Content will be automatically loaded on game start
4. **Validation**: Ensure your content passes validation rules

### Content Types

#### Items
- **Equipment**: Shields, engines, weapons
- **Resources**: Ores, materials, currency
- **Modules**: Upgrade components

#### Ships
- **Player Ships**: Different starting vessels
- **Enemy Ships**: Various AI-controlled threats
- **NPC Ships**: Freighters, traders

#### Turrets
- **Weapons**: Guns, lasers, missiles
- **Mining Tools**: Mining lasers, salvaging equipment
- **Special**: Repair beams, shield generators

## UI System

### UI Architecture

The UI system uses a **modular panel approach**:

- **UIManager** (`src/core/ui_manager.lua`): Central UI coordination
- **Individual Panels**: Self-contained UI components
- **Theme System** (`src/core/theme.lua`): Consistent styling

#### UI Sizing Source of Truth
- All UI spacing and control sizes are defined in `Theme.ui` (`src/core/theme.lua`).
- Tokens: `titleBarHeight`, `borderWidth`, `contentPadding`, `buttonHeight`, `buttonSpacing`, `menuButtonPaddingX`.
- Windows, panels, and common widgets read these tokens instead of hardcoded values.

### Main UI Panels

#### 1. Start Screen (`src/ui/start_screen.lua`)
- Game launcher
- Multiplayer menu
- Settings access
- Save/load slots

#### 2. Docked Interface (`src/ui/docked.lua`)
- **Shop Tab**: Buy/sell items and ships
- **Ship Tab**: Equipment and customization
- **Quests Tab**: Mission management
- **Nodes Tab**: Trading node interface

#### 3. HUD (`src/ui/hud/`)
- **Status Bars**: Health, energy, shields
- **Minimap**: World overview
- **Quest Log**: Active mission display
- **Hotbar**: Quick actions

#### 4. Specialized Panels
- **Inventory** (`src/ui/inventory.lua`): Item management
- **Settings** (`src/ui/settings_panel.lua`): Game configuration
- **Warp** (`src/ui/warp.lua`): Sector navigation
- **Debug** (`src/ui/debug_panel.lua`): Development tools

#### Modal Behavior and Input
- When modal UI (escape menu, settings, map) is open, input is consumed by UI.
- `PlayerSystem` additionally gates gameplay controls via `UIManager.isModalActive()`.

### UI Interaction Patterns

- **Modal Windows**: Full-screen overlays (docked, settings)
- **Tooltips**: Context-sensitive help
- **Drag & Drop**: Equipment management
- **Context Menus**: Right-click actions

## File Structure

```
LoveProject/
├── main.lua                    # Entry point
├── conf.lua                    # Love2D configuration
├── src/                        # Source code
│   ├── core/                   # Core systems (camera, events, input, etc.)
│   ├── components/             # ECS components (ai, health, position, etc.)
│   ├── entities/               # Entity implementations (player, remote_player, etc.)
│   ├── systems/                # Game systems (ai, collision, mining, etc.)
│   ├── templates/              # Entity templates (ship, projectile, etc.)
│   ├── ui/                     # User interface panels and components
│   ├── content/                # Content management (loader, validator, etc.)
│   ├── effects/                # Visual effects
│   ├── libs/                   # Third-party libraries
│   ├── managers/               # High-level managers (state, portfolio)
│   ├── shaders/                # GLSL shaders
│   └── tools/                  # Development tools
├── content/                    # Game content
│   ├── items/                  # Item definitions
│   ├── ships/                  # Ship definitions
│   ├── turrets/                # Weapon definitions
│   ├── projectiles/            # Projectile definitions
│   ├── world_objects/          # World object definitions
│   └── sounds/                 # Audio files
└── assets/                     # Static assets
    └── fonts/                  # Font files
```

## Getting Started

### Prerequisites

- **Love2D 11.x**: Download from [love2d.org](https://love2d.org)
- **Lua 5.1**: Included with Love2D

### Running the Game

1. **Install Love2D** on your system
2. **Navigate** to the project directory
3. **Run**: `love .` (or drag folder onto Love2D executable)

### Building Distribution

- **Windows**: Use `build_love.bat` to create `.love` file
- **Distribution**: Package with Love2D executable for standalone

## Development Guide

### Adding New Features

#### 1. New Entity Type
1. Create template in `src/templates/`
2. Add to `entity_factory.lua`
3. Create content definitions in `content/`
4. Add rendering support in `src/systems/render/`

#### 2. New Game System
1. Create system file in `src/systems/`
2. Add update call in `src/game.lua`
3. Implement component interactions
4. Add UI integration if needed

#### 3. New UI Panel
1. Create panel file in `src/ui/`
2. Register with `UIManager`
3. Add navigation/input handling
4. Follow theme system for styling

### Debugging

- **Debug Panel**: Press F1 for debug information
- **Console Logging**: Use `Log` module for output
- **Entity Inspection**: Debug panel shows entity details
- **Performance**: Debug panel shows frame timing

### Code Style Guidelines

- **Lua Conventions**: Follow standard Lua style
- **Module Pattern**: Use `local Module = {}` pattern
- **Error Handling**: Use `pcall` for risky operations
- **Documentation**: Comment complex logic
- **Naming**: Use descriptive, consistent names

### Common Patterns

#### Entity Creation
```lua
local entity = EntityFactory.create("ship", "ship_id", x, y, extraConfig)
world:addEntity(entity)
```

#### System Update
```lua
function MySystem.update(dt, world)
    for _, entity in ipairs(world:get_entities_with_components("my_component")) do
        -- Process entity
    end
end
```

#### Event Handling
```lua
Events.on(Events.GAME_EVENTS.MY_EVENT, function(data)
    -- Handle event
end)
```

### Performance Considerations

- **Quadtree**: Used for spatial queries and collision detection
- **Entity Cleanup**: Dead entities are removed each frame
- **Icon Caching**: Generated icons are cached for performance
- **LOD System**: Distance-based rendering optimizations
- **Batch Operations**: Group similar operations together

---

This documentation provides a comprehensive guide to navigating and extending the Novus codebase. For specific implementation details, refer to the individual source files and their inline documentation.
