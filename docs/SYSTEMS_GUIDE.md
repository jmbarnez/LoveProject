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

### Boundary System (`src/systems/boundary_system.lua`)
* Keeps entities inside the configured world rectangle.
* Handles bounce/clamp behavior for stray physics bodies.

### Destruction System (`src/systems/destruction.lua`)
* Processes `entity.dead` flags, spawns wreckage/pickups, and dispatches destruction events.
* Notifies bounty tracking and quest systems about kills.

## Gameplay Systems

### Player System (`src/systems/player.lua`)
* Reads input state (via `Input.getInputState`) to drive acceleration, boost, braking, and strafing.
* Manages dash cooldowns, shield channel slow, thruster state for VFX, and warp readiness.
* Coordinates with `HotbarSystem` for manual weapon control and listens to player death/respawn events.

### AI System (`src/systems/ai.lua`)
* Implements behavior states (idle, hunting, retreating) with configurable aggression.
* Uses world queries for target acquisition and pathing.
* Fires projectiles via `world.spawn_projectile` when in range.

### Spawning System (`src/systems/spawning.lua`)
* Controls enemy wave timers, hub safe zones, and spawn radii.
* Scales difficulty based on elapsed time and player state.

### Mining System (`src/systems/mining.lua`)
* Drives mining beams, channel durations, and ore payouts from asteroids.
* Works with content-defined mining stats and turret metadata.

### Pickups System (`src/systems/pickups.lua`)
* Finds nearby loot and applies magnetic attraction toward the player.
* Collects pickups when within range and dispatches reward notifications.

### Interaction System (`src/systems/interaction.lua`)
* Provides context prompts for docking, warp gates, repair beacons, and loot.
* Queues interactions to avoid conflicts with UI state and pauses player control when necessary.

### Repair System (`src/systems/repair_system.lua`)
* Lets the player repair damaged stations using carried resources.
* Emits notifications and updates station state on success/failure.

### Hub/Station System (`src/systems/hub.lua`)
* Tracks player proximity to stations and toggles the docked UI state.
* Handles station cooldowns, services, and beacon states.

### Quest System (`src/systems/quest_system.lua`)
* Loads quest definitions from `content/quests`.
* Updates objective counters, awards rewards, and feeds the HUD quest log.

### Node Market (`src/systems/node_market.lua`)
* Simulates candlestick data, random trend shifts, and trade volume.
* Processes buy/sell orders from the node UI, updating the player's portfolio via `portfolio.lua`.
* Maintains history caps to control memory usage.

### Warp Gate System (`src/systems/warp_gate_system.lua`)
* Tracks gate charge timers, unlock conditions, and travel requests.
* Coordinates with the warp UI to display available destinations.

## Rendering & Effects

### Render System (`src/systems/render.lua`)
* Draws entities based on `renderable` components, including ships, projectiles, and world objects.
* Delegates to specialized renderers (`src/systems/render/entity_renderers.lua`, indicators, HUD helpers).

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

### HUD Systems (`src/ui/hud/`)
* `StatusBars`, `SkillXpPopup`, `QuestLogHUD`, and indicator modules render gameplay feedback overlays.
* `HotbarSystem` integrates with HUD widgets to display weapon cooldowns and manual fire state.

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

When adding or modifying systems:

- Keep their responsibilities narrow and operate on explicit components.
- Insert update calls in `src/game.lua` near related systems to maintain deterministic ordering.
- Emit events for cross-cutting concerns instead of requiring systems directly.
- Document new interactions in this guide to aid future maintainers.
