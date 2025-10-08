# Projectile Component Registry

Projectile effects and behaviors attach gameplay state to projectiles through a central registry located at `src/components/projectile/registry.lua`. Each entry exposes a constructor that receives the component configuration and contextual information from `Projectile:addComponent`.

## Built-in Components

| Name | Module | Description |
| ---- | ------ | ----------- |
| `dynamic_light` | `src/components/projectile/dynamic_light.lua` | Wraps the shared `DynamicLight` component so effects can request projectile lights with configuration-only descriptors. |
| `bouncing` | `src/components/projectile/bouncing.lua` | Tracks remaining bounce count for behaviors that reflect projectiles off collision normals. |

## Adding New Components

1. Create a constructor module under `src/components/projectile/` that returns a function accepting `(config, context)` and returning the component instance.
2. Register the constructor in `src/components/projectile/registry.lua` (or via `ProjectileComponentRegistry.register`).
3. Reference the component by name from projectile definitions, effects, or behaviors using a descriptor of the form:
   ```lua
   {
       name = "my_component",
       config = { -- component-specific options },
       overwrite = true, -- optional, forces replacement of existing component
   }
   ```
4. Avoid injecting raw component tables; `Projectile:addComponent` will reject unknown names to keep the registry authoritative.

Unknown component names logged by the projectile system should be treated as build failures—register the constructor before shipping.
