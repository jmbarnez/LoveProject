# Systems Guide - Novus Space Game

This guide describes the gameplay and support systems that power Novus. Use it as a reference when extending functionality or debugging interactions between subsystems.

## Table of Contents

1. [System Overview](#system-overview)
2. [Frame Update Order](#frame-update-order)
3. [Core Simulation Systems](#core-simulation-systems)
4. [Gameplay Systems](#gameplay-systems)
5. [Rendering & Effects](#rendering--effects)
6. [UI & Input Systems](#ui--input-systems)
7. [Support Services](#support-services)
8. [System Interactions](#system-interactions)

## System Overview

Systems consume entities, services, and content to drive the game loop. They are grouped broadly as:

- **Core Simulation** – Physics, collisions, boundaries, destruction.
- **Gameplay** – Player control, AI, spawning, mining, pickups, quests, economy, warp gates.
- **Rendering & Effects** – Visual presentation of the world and transient effects.
- **UI & Input** – HUD panels, modal windows, action maps, and input dispatch.
- **Support Services** – State management, audio, events, portfolios, and utilities that other systems rely on.

## Frame Update Order

`src/game.lua` orchestrates systems every frame in the following order (after early UI updates and pause checks):

1. **PlayerSystem.update** – Processes movement, dash/boost, turret firing, and warp readiness for the player entity.
2. **Sound Listener Update** – Positions the listener at the player for positional SFX.
3. **AISystem.update** – Advances enemy behavior states, targeting, and attack logic.
4. **PhysicsSystem.update** – Integrates velocities and applies thruster forces.
5. **ProjectileLifecycle.update** – Expires timed projectiles and capped-range ordnance.
6. **BoundarySystem.update** – Prevents entities leaving world bounds.
7. **CollisionSystem:update** – Detects entity/projectile collisions and applies damage/shields.
8. **DestructionSystem.update** – Handles entity death, loot spawning, and cleanup hooks.
9. **SpawningSystem.update** – Spawns enemy waves and enforces safe zones around stations.
10. **RepairSystem.update** – Allows repair beacon interactions near damaged stations.
11. **SpaceStationSystem.update** – Maintains docking state, station services, and hub timers.
12. **MiningSystem.update** – Progresses mining beams and awards ore.
13. **Pickups.update** – Applies magnetic collection to nearby loot crates and rewards.
14. **InteractionSystem.update** – Manages context prompts (dock, warp, interact) and handles queued actions.
15. **EngineTrailSystem.update** – Updates engine trail emitters from player thruster state.
16. **Effects.update** – Advances transient visual effects.
17. **QuestSystem.update** – Tracks quest objectives, completion, and rewards.
18. **NodeMarket.update** – Simulates node price movement and processes queued orders.
19. **WarpGateSystem.updateWarpGates** – Handles warp gate charge timers and unlocks.
20. **camera:update** – Follows the player and applies shake/zoom.
21. **world:update** – Removes dead entities and performs end-of-frame cleanup.
22. **StateManager.update** – Advances autosave timers and writes saves when necessary.
23. **refreshDockingState** – Re-evaluates docking eligibility for stations near the player.
24. **Events.processQueue** – Flushes queued events for deferred processing.
25. **HotbarSystem.update** – Updates ability cooldowns, manual turret firing, and UI bindings.

UI elements (`StatusBars`, `SkillXpPopup`, `Theme` animations) are updated before the player system runs, and rendering occurs later via `RenderSystem.draw` and UI manager draw calls.

## Core Simulation Systems

### Physics System (`src/systems/physics.lua`)
* Integrates positions using accumulated forces and velocities.
* Supports thruster forces, drag, and clamps for maximum speed.
* Requires `position`, `velocity`, and optional `physics` components.

### Collision System (`src/systems/collision/`)
* Uses quadtree-assisted broad-phase queries when available.
* Resolves entity/entity, projectile/entity, and radius-based interactions.
* Applies damage, shields, and triggers collision callbacks (loot spawning, death events).
* Emits projectile lifecycle events enriched with world context so behaviors can react (bounces, splits, homing updates).

### Projectile Framework (`src/templates/projectile.lua`)
* Projectiles are assembled from modular components, effects, and behaviors.
* `BehaviorManager` consumes the `behaviors` list on a projectile definition and wires handlers for spawn/update/hit/expire events (e.g., homing, bouncing, splitting, area denial fields).
* `RendererFactory` maps high-level `renderer` keys to specialized visual styles (energy, kinetic, missile, beam, area field) while keeping legacy `renderable` data compatible.
* Event payloads now include the owning `world` and `keepAlive` flags so behaviors can modify collision results (prevent destruction on bounce, defer removal until area effects resolve).
* `dynamic_light` and `particle_emitter` projectile effects attach light halos and bespoke particle bursts without bespoke systems.

### Boundary System (`src/systems/boundary_system.lua`)
* Keeps entities inside the configured world rectangle.
* Handles bounce/clamp behavior for stray physics bodies.

### Destruction System (`src/systems/destruction.lua`)
* Processes `entity.dead` flags, spawns wreckage/pickups, and dispatches destruction events.
* Emits kill events for quest systems and rewards experience gains.

## Gameplay Systems

### Player System (`src/systems/player.lua`)
* Reads input state (via `Input.getInputState`) to drive acceleration, boost, braking, and strafing.
* Manages dash cooldowns, shield channel slow, thruster state for VFX, and warp readiness.
* Coordinates with `HotbarSystem` for manual weapon control and listens to player death/respawn events.

### AI System (`src/systems/ai.lua`)
* Implements behavior states (idle, hunting, retreating) with configurable aggression.
* Uses world queries for target acquisition and pathing.
* Fires projectiles via `world.spawn_projectile` when in range.

### Turret Progression (`src/systems/turret/`)
* `modifier_system.lua` applies design-time modifiers (overcharged coils, precision barrels, capacitor banks) when a turret is instantiated, changing damage, spread, cycle time, and energy usage.
* `upgrade_system.lua` tracks per-turret experience via projectile hits and applies level-based bonuses (damage, rate of fire, improved homing) according to thresholds defined in turret content.
* Turret instances expose `modifiers` for UI display and `upgradeEntry` for progression state.
* Core modules (`core.lua`, projectile/beam specializations, `heat_manager.lua`) coordinate firing logic, overheating, and shared visual/audio hooks.
* Combat weapons fire directionally (cursor or ship facing) with embedded projectile definitions per turret archetype to avoid duplicated template wiring.

### Spawning System (`src/systems/spawning.lua`)
* Controls enemy wave timers, hub safe zones, and spawn radii.
* Scales difficulty based on elapsed time and player state.
* Enforces minimum spawn distance from the player, respects station safe zones, and caps simultaneous enemy counts per tier.

### Mining System (`src/systems/mining.lua`)
* Drives mining beams, channel durations, and ore payouts from asteroids.
* Works with content-defined mining stats and turret metadata.
* Tracks per-asteroid progress, validates required mining tools, and spawns collectible resource crates on completion.

### Pickups System (`src/systems/pickups.lua`)
* Finds nearby loot and applies magnetic attraction toward the player.
* Collects pickups when within range and dispatches reward notifications.
* Supports magnetic auto-collection, manual interaction prompts for special loot, and pickup FX/audio hooks.

### Interaction System (`src/systems/interaction.lua`)
* Provides context prompts for docking, warp gates, repair beacons, and loot.
* Queues interactions to avoid conflicts with UI state and pauses player control when necessary.

### Repair System (`src/systems/repair_system.lua`)
* Lets the player repair damaged stations using carried resources.
* Emits notifications and updates station state on success/failure.
* Calculates repair costs/time and applies module/state updates once work completes.

### Hub/Station System (`src/systems/hub.lua`)
* Tracks player proximity to stations and toggles the docked UI state.
* Handles station cooldowns, services, and beacon states.

### Quest System (`src/systems/quest_system.lua`)
* Loads quest definitions from `content/quests`.
* Updates objective counters, awards rewards, and feeds the HUD quest log.
* Supports kill, mining, delivery, and exploration quest templates using event-driven progress hooks.

### Node Market (`src/systems/node_market.lua`)
* Simulates candlestick data, random trend shifts, and trade volume.
* Processes buy/sell orders from the node UI, updating the player's portfolio via `portfolio.lua`.
* Maintains history caps to control memory usage.
* Streams price updates and technical indicators while broadcasting portfolio events to UI widgets.

### Warp Gate System (`src/systems/warp_gate_system.lua`)
* Tracks gate charge timers, unlock conditions, and travel requests.
* Coordinates with the warp UI to display available destinations.

## Rendering & Effects

### Render System (`src/systems/render.lua`)
* Draws entities based on `renderable` components, including ships, projectiles, and world objects.
* Delegates to specialized renderers (`src/systems/render/entity_renderers.lua`, indicators, HUD helpers).

### Entity Renderers (`src/systems/render/entity_renderers.lua`)
* Provides modular draw handlers for specific entity classes (ships, stations, asteroids, loot).
* Keeps renderer selection data-driven so new templates can supply their `render_type` without modifying the main render loop.
* Supports helper decorators (selection rings, docking outlines, shield arcs) that compose with base renderers.

### Player Renderer (`src/systems/render/player_renderer.lua`)
* Handles player-specific visuals, including thruster animation, shield effects, and damage feedback.
* Synchronizes with `EngineTrailSystem` and status overlays to keep exhaust, shield pulsing, and HUD cues in lock-step.
* Exposes hooks for cosmetics (ship skins, decals) without branching the shared entity renderer logic.

### Effects System (`src/systems/effects.lua`)
* Manages transient particle systems and hit effects.
* Works closely with mining lasers, explosions, and environmental feedback.

### Engine Trail System (`src/systems/engine_trail.lua`)
* Spawns and updates engine trail sprites tied to thruster state from the player and certain AI ships.

## UI & Input Systems

### Input (`src/core/input.lua`)
* Bridges Love callbacks (`love.keypressed`, `love.mousepressed`, etc.) with in-game state.
* Uses `ActionMap` (`src/core/action_map.lua`) for configurable hotkeys (inventory, ship, map, repair beacon, fullscreen toggle).
* Manages screen transitions between the start menu and in-game UI.

### UIManager (`src/core/ui_manager.lua`)
* Registers and orchestrates UI components (inventory, docked panels, map, warp, escape menu, debug panel, etc.).
* Maintains modal state (`isModalActive`) to pause gameplay input when overlays are open.
* Routes input events to the top-most visible component using a registry/priority system.

### Docked Interface (`src/ui/docked.lua`)
* Drives the station services menu, including ship management, trade, and crafting panels.
* Coordinates with `HubSystem`/`SpaceStationSystem` to transition between docked and undocked UI states.
* Exposes callbacks so gameplay systems (repairs, quests) can register contextual actions without duplicating UI glue.

### HUD Systems (`src/ui/hud/`)
* `StatusBars`, `SkillXpPopup`, `QuestLogHUD`, and indicator modules render gameplay feedback overlays.
* `HotbarSystem` integrates with HUD widgets to display weapon cooldowns and manual fire state.

### Inventory System (`src/ui/inventory.lua`)
* Presents cargo, equipment slots, and loot details using the shared UI theme tokens.
* Listens to pickup and quest events to refresh item lists and highlight new rewards.
* Integrates drag-and-drop logic with the action map so keyboard shortcuts (equip, jettison) stay in sync.

## Support Services

### Events (`src/core/events.lua`)
* Provides synchronous and queued event dispatch for decoupled communication.
* Systems queue work (e.g., loot collected, quests updated) for later processing in `Events.processQueue`.

### State Manager (`src/managers/state_manager.lua`)
* Serializes/deserializes game state, manages autosave intervals, and exposes quick save/load helpers (F5/F9).

### Portfolio Manager (`src/managers/portfolio.lua`)
* Tracks player funds, holdings, and transaction history for the node market.
* Integrates with the node UI to refresh balances and enforce trade rules.

### Sound System (`src/core/sound.lua`)
* Registers SFX/music from `content/sounds` and attaches them to gameplay events.
* Updates listener position each frame for positional audio.

### Multiplayer System (`src/core/multiplayer.lua`)
* Handles peer discovery, connection management, and event replication for cooperative sessions.
* Performs state reconciliation so late joiners and lagged clients converge on the authoritative world snapshot.
* Relies on the event bus to broadcast gameplay updates without hard-coding cross-system dependencies.

### Action Map (`src/core/action_map.lua`)
* Centralizes keyboard shortcuts and contextual actions used across gameplay and UI modules.
* Registers actions with descriptors (`name`, `getKeys`, `callback`, optional `enabled`/`priority`) so behaviors remain declarative.
* Integrates with `Settings` to resolve default and user-rebound keys, ensuring UI hints and input dispatch stay aligned.

### Theme & Settings (`src/core/theme.lua`, `src/core/settings.lua`)
* Supplies fonts, colors, and spacing tokens for UI components.
* Stores keybindings and graphics options exposed via the settings panel.

## System Interactions

```mermaid
graph TD
    Input --> Player
    Player --> Physics
    Player --> Interaction
    Player --> EngineTrail
    AI --> Physics
    AI --> Collision
    Physics --> Collision
    Collision --> Destruction
    Destruction --> Effects
    Destruction --> Pickups
    Pickups --> InventoryUI
    Mining --> Pickups
    Spawning --> AI
    Quest --> UI
    NodeMarket --> Portfolio
    Portfolio --> NodesUI
    WarpGate --> UI
    UIManager --> Hotbar
```

### Update Flow

```mermaid
graph TD
    A[Input System] --> B[Player System]
    B --> C[AI System]
    C --> D[Physics System]
    D --> E[Collision System]
    E --> F[Destruction System]
    F --> G[Spawning System]
    G --> H[Mining System]
    H --> I[Pickup System]
    I --> J[Quest System]
    J --> K[Render System]
    K --> L[UI System]
```

### Event Flow

```mermaid
graph LR
    A[Collision System] --> B[ENTITY_DESTROYED]
    B --> C[Destruction System]
    C --> D[LOOT_SPAWNED]
    D --> E[Pickup System]

    F[Player System] --> G[PLAYER_DAMAGED]
    G --> H[UI System]

    I[Quest System] --> J[QUEST_COMPLETED]
    J --> K[Player System]
```

### Data Dependencies

- **World State** – Shared canonical data structure consumed by simulation and rendering systems.
- **Player Entity** – Referenced by most gameplay systems for targeting, camera, and audio listener updates.
- **Event System** – Backbone for decoupled communication and deferred work processing.
- **Content System** – Supplies templates, stats, and quest definitions that systems hydrate at runtime.

### Performance Considerations

- **System Order** – Keep update order optimized for data locality and deterministic results.
- **Entity Filtering** – Process only relevant entities/components per system to minimize iteration costs.
- **Spatial Indexing** – Use quadtree/partition helpers for collision queries and proximity checks.
- **Event Batching** – Batch event processing where possible to reduce redundant work each frame.

When adding or modifying systems:

- Keep their responsibilities narrow and operate on explicit components.
- Insert update calls in `src/game.lua` near related systems to maintain deterministic ordering.
- Emit events for cross-cutting concerns instead of requiring systems directly.
- Document new interactions in this guide to aid future maintainers.
