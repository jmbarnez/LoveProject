# Content Guide - Novus Space Game

This document provides information about the content system and how to create new content.

## Table of Contents

1. [Content System Overview](#content-system-overview)
2. [Content Types](#content-types)
3. [Content Creation](#content-creation)
4. [Best Practices](#best-practices)

## Content System Overview

The content system uses a **file-based approach** with automatic discovery and loading. Content is defined in Lua files within the `content/` directory and is automatically loaded when the game starts.

### Key Features

- **Auto-Discovery**: Automatically finds and loads content files
- **Validation**: Ensures content integrity and consistency
- **Normalization**: Converts content to canonical format
- **Icon Generation**: Creates procedural icons from shape definitions

### Content Directory Structure

```
content/
├── items/              # Equipment, resources, modules
├── ships/              # Ship definitions
├── turrets/            # Weapon systems (with embedded projectiles)
├── projectiles/        # Legacy projectile files (mostly unused)
├── world_objects/      # Stations, asteroids, planets
└── sounds/             # Audio files and definitions
```

## Content Types

### 1. Ships (`content/ships/`)

Ships are player and AI-controlled vessels.

**Key Properties:**
- `id`: Unique identifier
- `name`: Display name
- `hull`: Health and shield values
- `engine`: Movement properties
- `equipmentLayout`: Module slot definitions
- `visuals`: Visual appearance

### 2. Turrets (`content/turrets/`)

**Streamlined Turret System**: The game now uses only **5 core turrets** with embedded projectiles:

- **Combat Laser** - Hitscan beam weapon for close-mid range
- **Gun Turret** - Projectile weapon firing kinetic slugs  
- **Missile Launcher** - Heavy rocket launcher with explosion damage
- **Mining Laser** - Utility weapon for mining asteroids
- **Salvaging Laser** - Utility weapon for salvaging wreckage

**Key Properties:**
- `id`: Unique identifier
- `type`: Weapon type (gun, laser, missile, mining_laser, salvaging_laser)
- `projectile`: Embedded projectile definition
- `damage_range`: Min/max damage values
- `cycle`: Firing rate
- `optimal`/`falloff`: Range parameters
- `maxHeat`/`heatPerShot`: Overheating system

**Embedded Projectiles**: Each turret contains its own projectile definition, eliminating the need for separate projectile files.

### 3. Items (`content/items/`)

Items are equipment, resources, and modules.

**Key Properties:**
- `id`: Unique identifier
- `name`: Display name
- `module`: Module type and properties
- `price`: Cost in credits

### 4. World Objects (`content/world_objects/`)

Stations, asteroids, and other interactive objects.

**Key Properties:**
- `id`: Unique identifier
- `name`: Display name
- `visuals`: Visual appearance
- `components`: Interactive properties (mineable, dockable, etc.)

## Content Creation

### Creating a New Turret

1. Create a new `.lua` file in `content/turrets/`
2. Define the turret structure with embedded projectile
3. Include all required properties (id, name, type, projectile, stats)
4. Add visual effects and icon definition

### Creating a New Ship

1. Create a new `.lua` file in `content/ships/`
2. Define ship properties (hull, engine, visuals)
3. Set up equipment layout for module slots
4. Add visual shapes and icon definition

### Creating a New Item

1. Create a new `.lua` file in `content/items/`
2. Define item properties (id, name, module type)
3. Set price and other attributes
4. Add icon definition

## Best Practices

### Content Organization

- Keep content files focused and single-purpose
- Use descriptive, consistent naming conventions
- Group related content in appropriate directories

### Embedded Projectiles

- Always include projectile definition within turret files
- Use consistent projectile property structure
- Keep projectile definitions simple and focused

### Visual Design

- Use procedural icon generation for consistency
- Keep visual shapes simple and recognizable
- Use consistent color schemes across content types

### Performance

- Minimize complex calculations in content definitions
- Use efficient data structures
- Avoid redundant or duplicate content

## Key System Changes

**No Targeting Systems**: All weapons fire in the shot direction only - no homing, guidance, or targeting systems.

**Streamlined Design**: Only 5 core turrets instead of 30+ variants, making the system much easier to manage.

**Faster Rockets**: Missiles have acceleration making them faster than bullets over time, but they fly in shot direction only.