# Architecture Guide - Novus Space Game

This guide explains the technical architecture behind Novus, focusing on how the simulation, UI, and services collaborate. Use it to understand load order, data flow, and extension points before making substantial changes.

## Table of Contents

1. [Entity-Component Pattern](#entity-component-pattern)
2. [Core Modules & Responsibilities](#core-modules--responsibilities)
3. [Game Loop Flow](#game-loop-flow)
4. [Content Pipeline](#content-pipeline)
5. [Rendering Pipeline](#rendering-pipeline)
6. [Event & Messaging System](#event--messaging-system)
7. [UI Architecture and Input](#ui-architecture-and-input)
8. [Persistence & Save System](#persistence--save-system)
9. [Performance Considerations](#performance-considerations)

## Entity-Component Pattern

### Overview

Novus uses a hybrid entity-component approach:

- **Entities** – Lua tables with an `id`, `components`, and optional runtime state (e.g., `docked`, `dead`).
- **Components** – Plain tables providing typed data (position, velocity, health, ai, cargo, renderable, etc.).
- **Systems** – Modules that iterate over entities with certain components to mutate state or trigger events.

### Example Entity Structure

```lua
local entity = {
  id = "player",
  components = {
    position = { x = 5000, y = 5000 },
    velocity = { x = 0, y = 0 },
    physics = { body = { mass = 500, radius = 42 } },
    health = { hp = 1200, maxHp = 1200, shieldHp = 400, maxShieldHp = 400 },
    ai = nil,
    renderable = { props = { visuals = { kind = "ship", size = 1.0 } } },
  },
  docked = false,
  thrusterState = {},
}
```

### Entity Factory Pattern

`src/templates/entity_factory.lua` centralizes creation of entities. Factories read content definitions, attach necessary components, and wire runtime helpers (e.g., attack callbacks for turrets, loot tables for wreckage).

## Core Modules & Responsibilities

| Module | Responsibility |
| --- | --- |
| `src/game.lua` | Orchestrates loading, world creation, system update order, and draw pipeline. |
| `src/core/world.lua` | Stores entities, supports quadtree queries, background rendering, and cleanup. |
| `src/core/ui_manager.lua` | Registers UI components, routes input, and manages modal layering. |
| `src/core/input.lua` | Bridges Love callbacks to gameplay state, action map dispatch, and screen transitions. |
| `src/core/events.lua` | Provides synchronous and queued event dispatch. |
| `src/managers/state_manager.lua` | Serializes/deserializes game state, autosave timers, quick save/load. |
| `src/managers/portfolio.lua` | Tracks node market holdings/funds and executes trades. |
| `src/core/sound.lua` | Loads SFX/music, updates listener position, and plays events. |
| `src/core/theme.lua` | Supplies fonts, colors, spacing tokens, and shader references for UI components. |

### Module Registration & Lazy Loading

`src/core/module_registry.lua` centralizes lazy-loaded dependencies so the entry point no longer needs to manage bespoke caches.

- **Registration** – Startup code (currently `main.lua`) calls `ModuleRegistry.registerMany` with name/function pairs. Each
  loader returns the module table when first invoked.
- **Resolution** – `ModuleRegistry.get("ModuleName")` loads the dependency on first access, memoizes it, and optionally
  reports the load duration back to the caller for profiling.
- **Maintenance** – Use `ModuleRegistry.clear(name)` to invalidate a cached module when it should be rebuilt (e.g., forcing a
  fresh `UIManager`). Tests or hot-reload helpers can inject doubles with `ModuleRegistry.set`.

This keeps the boot script lean, provides a single location for future module wiring, and makes adding new lazily loaded systems
as simple as appending another registration entry.

## Game Loop Flow

The runtime loop is coordinated by `src/game.lua`.

### High-Level Sequence

1. `main.lua` sets up logging, theme, sound, start screen, and Love callbacks.
2. On game start, `Game.load` performs:
   1. Content loading/validation.
   2. System initialization (hotbar, node market, portfolio manager).
   3. World creation, hub/furnace station spawning, player instantiation.
   4. UI initialization and camera setup.
3. Every frame, `Game.update(dt)` executes:
   1. Input update + UI pause check.
   2. Theme animation updates (`Theme.updateAnimations`, `Theme.updateParticles`, etc.).
   3. Player, AI, physics, boundary, collision, destruction, spawning, repair, station, mining, pickups, interaction, engine trail, effects, quests, node market, warp gate systems.
   4. Camera/world cleanup, autosave update, docking refresh, event processing, hotbar update.
4. `Game.draw()` renders the world, effects, helpers, HUD, UI overlays, and indicators.

Refer to `docs/SYSTEMS_GUIDE.md` for the detailed system order and responsibilities.

## Content Pipeline

1. **Discovery** – `src/content/design_loader.lua` locates Lua files under `content/`.
2. **Validation** – `src/content/validator.lua` ensures required fields are present and within valid ranges.
3. **Normalization** – `src/content/normalizer.lua` applies defaults, resolves nested projectile data in turrets, and harmonizes numeric values.
4. **Icon Rendering** – `src/content/icon_renderer.lua` produces procedural icons consumed by UI elements.
5. **Runtime Access** – `src/content/content.lua` exposes getters for ships, items, turrets, world objects, quests, sounds, and config tables. Systems and UI modules query this registry during runtime.

The loader is invoked in `Game.load` before any systems or entities are created, ensuring content is ready when factories run.

## Rendering Pipeline

1. **Camera Setup** – `camera:apply()` applies translation, shake, and zoom derived from `Theme` feedback.
2. **Background** – `world:drawBackground` renders parallax layers and sector art.
3. **Entity Rendering** – `RenderSystem.draw` delegates to specialized renderers for ships, projectiles, effects, and indicators.
4. **Effects Layer** – `Effects.draw` renders transient visual systems (explosions, mining beams, engine trails).
5. **Helpers** – `UI.drawHelpers` draws context markers (warp prompts, interaction outlines) between world and UI layers.
6. **HUD & UI** – `UIManager.draw` and HUD modules render panels, hotbars, quest logs, and modal windows.
7. **Screen Effects** – `Theme.drawParticles` and flash overlays render last to ensure post-processing is visible.

The draw order preserves world context beneath HUD elements while allowing modal UI to occlude the scene when required.

## Event & Messaging System

`src/core/events.lua` exposes:

- `Events.on(event, handler)` – Register listeners.
- `Events.emit(event, data)` – Immediate dispatch.
- `Events.queue(event, data)` – Deferred dispatch processed during `Events.processQueue()` in the update loop.

Systems use events for cross-cutting concerns (loot collection, quest updates, UI refreshes) to avoid hard dependencies.

## UI Architecture and Input

### Input Handling

- `main.lua` routes Love callbacks into `src/core/input.lua`.
- `Input.init_love_callbacks` stores the current screen, UI manager, and loading screen references.
- `Input.love_keypressed` handles escape/menu flow, quick save/load (F5/F9), and delegates to `UIManager.keypressed` or `Input.keypressed` depending on screen state.
- `ActionMap` centralizes configurable hotkeys (cargo, ship, map, repair beacon, fullscreen toggle).

### UI Manager

- Maintains component registry with z-ordering.
- Keeps modal awareness so gameplay input pauses when windows are open (`UIManager.isModalActive`).
- Routes mouse/keyboard events to the active component using capture logic to avoid double-handling.
- Integrates the debug panel (`F1`) and settings panel so they can consume events even when other UI is present.

### HUD Integration

HUD modules (`src/ui/hud/`) are updated before the player system and drawn after the world. They access the player entity and world to display health bars, quest logs, minimaps, and targeting indicators. The hotbar integrates with `HotbarSystem` to show turret cooldowns and manual fire state.

## Persistence & Save System

`src/managers/state_manager.lua` provides:

- Autosave timers triggered during `Game.update` (configurable intervals).
- Quick save (F5) / quick load (F9) helpers wired through `Input.love_keypressed`.
- Slot management for manual saves accessible via the start screen load UI and escape menu.
- Serialization hooks for world entities, player state, portfolio data, and quest progress.

Saves are stored under the LÖVE save directory (`love.filesystem.getSaveDirectory()`). The manager handles version compatibility checks before loading older saves.

## Performance Considerations

- **Delta Time Smoothing** – `main.lua` enforces a minimum frame time based on the configured FPS cap to keep physics stable.
- **Quadtree Usage** – Attach a quadtree to the world when introducing high entity counts to keep collision queries efficient.
- **Content Validation** – Invalid content definitions fail fast during load, preventing undefined behavior later in the game loop.
- **Effect Budgets** – Particle systems and engine trails should respect existing limits to avoid excessive draw calls.
- **Market Simulation** – `NodeMarket` limits candle history and order rates; maintain these guardrails when extending the economy to avoid memory spikes.
- **UI Draw Order** – Panels declare z-order via the registry. Keep overlays lightweight and avoid unnecessary canvas allocations to preserve frame rate.

For further subsystem detail, consult `docs/SYSTEMS_GUIDE.md`, `docs/PROJECT_DOCUMENTATION.md`, and in-code comments within each module.
