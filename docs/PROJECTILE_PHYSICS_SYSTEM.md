# Projectile Physics System

## Overview

The projectile physics system has been completely restructured to eliminate bouncing issues through modular, dedicated components with proper projectile categorization.

## Architecture

### Core Components

1. **ProjectileCategories** (`src/systems/projectile/categories.lua`)
   - Defines projectile categories and their properties
   - Replaces generic "bullet" terminology with proper categorization
   - Manages collision classes and physics configurations

2. **ProjectilePhysics** (`src/systems/physics/projectile_physics.lua`)
   - Handles projectile-specific physics configuration
   - Uses category-based physics settings
   - Ensures zero restitution and friction

3. **ProjectileCollisionHandler** (`src/systems/collision/projectile_collision_handler.lua`)
   - Dedicated collision detection and response for projectiles
   - Immediate velocity stopping on collision
   - Damage application and effect creation

4. **WindfieldManager** (Updated)
   - Modified collision callbacks to handle projectiles first
   - Uses projectile categories for collision classes
   - Zero restitution enforcement at collider creation

## Key Features

### Anti-Bounce Measures

1. **Collider Creation**: Zero restitution and friction set immediately
2. **Contact Handling**: Contacts disabled immediately on collision
3. **Velocity Control**: Projectile velocity stopped instantly on impact
4. **Fixture Safety**: Underlying Box2D fixtures forced to zero restitution

### Modular Design

- **Single Responsibility**: Each component handles one aspect
- **Separation of Concerns**: Physics, collision, and effects are separate
- **Clean Interfaces**: Simple, focused APIs
- **No Fallbacks**: Direct, purpose-built solutions

## Flow

1. **Projectile Creation** → `Projectile.new()` with `windfield_physics` component
2. **Physics Addition** → `EntityPhysics.addEntity()` → `WindfieldManager.addEntity()`
3. **Collision Detection** → Windfield `beginContact` callback
4. **Projectile Handling** → `ProjectileCollisionHandler.handle()`
5. **Physics Stop** → Immediate velocity zeroing and contact disabling
6. **Damage/Effects** → Collision effects and damage application
7. **Cleanup** → Projectile marked as dead

## Configuration

### Projectile Physics Settings

```lua
local PROJECTILE_PHYSICS = {
    restitution = 0.0,    -- No bouncing
    friction = 0.0,       -- No friction
    fixedRotation = true, -- No rotation
    bodyType = "dynamic"  -- Physics body
}
```

### Projectile Categories

- **Kinetic** (`kinetic_projectile`) - Physical projectiles with mass and momentum
  - Types: bullet, slug, cannonball, railgun_slug
  - Physics: Fixed rotation, zero restitution

- **Explosive** (`explosive_projectile`) - Missiles and rockets with explosive payloads
  - Types: missile, rocket, torpedo, bomb
  - Physics: Can tumble, zero restitution

- **Energy** (`energy_projectile`) - Energy-based projectiles and beams
  - Types: laser, plasma, ion, beam
  - Physics: Fixed rotation, zero restitution

- **Utility** (`utility_projectile`) - Mining, salvaging, and healing projectiles
  - Types: mining_laser, salvaging_laser, healing_laser
  - Physics: Fixed rotation, zero restitution

## Benefits

1. **No Bouncing**: Projectiles stop immediately on collision
2. **Proper Categorization**: Clear projectile types instead of generic "bullet"
3. **Modular**: Easy to extend and modify
4. **Performance**: Dedicated systems reduce overhead
5. **Maintainable**: Clear separation of concerns
6. **Extensible**: Easy to add new projectile categories
4. **Fast**: Direct collision handling
5. **Reliable**: Multiple layers of protection

## Usage

The system works automatically once projectiles are created with the `windfield_physics` component. No additional configuration is required.

## Files Modified

- `src/systems/physics/windfield_manager.lua` - Updated collision callbacks
- `src/systems/projectile/projectile.lua` - Simplified physics addition
- `src/systems/collision/handlers/projectile_collision.lua` - Deprecated
- `src/systems/collision/physics/physics_resolution.lua` - Projectile checks added

## Files Created

- `src/systems/physics/projectile_physics.lua` - Projectile physics controller
- `src/systems/collision/projectile_collision_handler.lua` - Collision handler
- `docs/PROJECTILE_PHYSICS_SYSTEM.md` - This documentation
