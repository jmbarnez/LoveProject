# Novus - Space Trading & Combat Game

A single-player LÖVE 11.x experience that blends top-down space combat, asteroid mining, node-based trading, and quest progression. The project uses a modular Lua codebase with distinct systems for simulation, UI, and content management.

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Core Systems](#core-systems)
4. [Content System](#content-system)
5. [UI System](#ui-system)
6. [File Structure](#file-structure)
7. [Getting Started](#getting-started)
8. [Development Guide](#development-guide)
9. [Debugging & Tooling](#debugging--tooling)
10. [AI Contributor Standards](#ai-contributor-standards)
11. [Performance Considerations](#performance-considerations)

## Project Overview

**Novus** drops the player into a persistent sector anchored by a central hub station. Core gameplay pillars include:

- **Space Combat** – Player-controlled ships fight AI enemies using configurable turrets and abilities.
- **Mining & Salvage** – Asteroids can be mined for ore; wreckage drops salvageable resources and loot.
- **Docking & Trade** – Stations expose shop, quest, and node-market tabs. Furnace stations convert ore into refined items or credits.
- **Procedural Economy** – The node market simulates multiple tickers with candlestick data, allowing buy/sell orders and portfolio tracking.
- **Quest Progression** – Generated and scripted quests drive objectives and rewards.
- **Warp Network** – Warp gates (and the warp UI) let the player travel to configured sectors once unlocked.

Multiplayer is not implemented; all systems run locally in a single-player loop.

## Architecture

### Entry Points

- **`conf.lua`** – Sets window defaults, vsync, and save identity before the engine loads the game.
- **`main.lua`** – Initializes logging, debugging, theme/fonts, sound settings, and the start screen. It forwards Love callbacks into the `Input` module and `src/game.lua` once a session begins.
- **`src/game.lua`** – Coordinates world creation, content loading, system initialization, and per-frame updates/draws. It also manages the central hub station, warp gates, and auto-save cadence.

### Entity-Component Style

Entities are Lua tables composed of component tables (position, physics, health, ai, cargo, etc.). Systems iterate over the world and mutate entities based on their components. Factories in `src/templates` standardize how ships, projectiles, stations, and pickups are created.

### Major Managers & Services

- **World (`src/core/world.lua`)** – Spatial registry with optional quadtree acceleration and background rendering hooks.
- **UI Manager (`src/core/ui_manager.lua`)** – Routes input, manages modal state, and draws registered panels.
- **State Manager (`src/managers/state_manager.lua`)** – Handles save/load, autosave timers, and migration hooks.
- **Portfolio Manager (`src/managers/portfolio.lua`)** – Tracks player market holdings and transaction history.

## Core Systems

The simulation loop in `src/game.lua` updates systems in a defined order each frame:

1. **Input** (`src/core/input.lua`) – Refreshes input state and early-outs if modal UI is active.
2. **UI Manager Update** (`UIManager.update`) – Drives UI animation and modal logic.
3. **Status/HUD Systems** – Updates HUD-specific effects (`StatusBars`, `SkillXpPopup`).
4. **Player System** (`src/systems/player.lua`) – Applies movement, combat, warp readiness, dash/boost, and thruster state.
5. **Audio Listener** – Follows the player for positional audio (`src/core/sound.lua`).
6. **AI System** (`src/systems/ai.lua`) – Runs enemy behavior trees, target selection, and combat responses.
7. **Physics System** (`src/systems/physics.lua`) – Integrates velocities, applies thruster forces, and updates physics bodies.
8. **Projectile Lifecycle** (`src/systems/projectile_lifecycle.lua`) – Handles ranged expiration and beam lifetimes.
9. **Boundary System** (`src/systems/boundary_system.lua`) – Keeps entities within the world bounds.
10. **Collision System** (`src/systems/collision/core.lua`) – Resolves entity/projectile collisions and applies damage.
11. **Destruction System** (`src/systems/destruction.lua`) – Cleans up dead entities, spawns wreckage/loot, and fires destruction events.
12. **Spawning System** (`src/systems/spawning.lua`) – Manages AI spawn waves, hub safety radii, and spawn timers.
13. **Repair System** (`src/systems/repair_system.lua`) – Allows repair beacon interactions near damaged stations.
14. **Hub/Station System** (`src/systems/hub.lua`) – Updates docking proximity and station services.
15. **Mining System** (`src/systems/mining.lua`) – Drives mining channel progress and ore yield.
16. **Pickups System** (`src/systems/pickups.lua`) – Applies magnetic attraction and resolves pickup collection.
17. **Interaction System** (`src/systems/interaction.lua`) – Handles context prompts (docking, warp, loot) and input gating.
18. **Engine Trail System** (`src/systems/engine_trail.lua`) – Updates thruster visuals based on player movement state.
19. **Effects System** (`src/systems/effects.lua`) – Manages transient visual effects (explosions, particles).
20. **Quest System** (`src/systems/quest_system.lua`) – Progresses active quests, updates UI, and awards rewards.
21. **Node Market** (`src/systems/node_market.lua`) – Simulates ticker prices, candles, and processes buy/sell orders.
22. **Warp Gate System** (`src/systems/warp_gate_system.lua`) – Tracks gate states and unlock logic.
23. **Camera & World Update** (`camera:update`, `world:update`) – Moves the camera and prunes dead entities.
24. **State Manager** (`StateManager.update`) – Advances autosave timers.
25. **Docking Check** – Updates docking eligibility for nearby stations.
26. **Events Queue** (`Events.processQueue`) – Flushes queued events to listeners.
27. **Hotbar System** (`src/systems/hotbar.lua`) – Updates ability/turret cooldown UI and manual firing state.

Rendering is handled by `RenderSystem.draw` and UI overlays executed via `UIManager.draw` and HUD helpers once the world is drawn.

## Content System

Game data lives under `content/` and is loaded on boot by `src/content/content.lua`. The pipeline:

1. **Discovery** – `src/content/design_loader.lua` crawls the content tree, indexing files for ships, items, turrets (with embedded projectiles), world objects, quests, and sounds.
2. **Validation** – `src/content/validator.lua` enforces schema requirements (required keys, value ranges, tag usage) to prevent runtime crashes.
3. **Normalization** – `src/content/normalizer.lua` applies defaults, expands shorthand definitions, and harmonizes numeric fields.
4. **Icon Rendering** – `src/content/icon_renderer.lua` generates procedural icons consumed by the UI.
5. **Runtime Registry** – `src/content/content.lua` exposes accessor APIs (`getShip`, `getItem`, etc.) for systems and UI panels.

Key content directories:

```
content/
├── items/           # Equipment, consumables, crafting resources
├── ships/           # Player and AI ship definitions
├── turrets/         # Turret definitions with embedded projectile data
├── projectiles/     # Legacy projectile overrides (still referenced by some systems)
├── world_objects/   # Stations, asteroids, and interactive scenery
├── sounds/          # Event-to-sound mappings consumed by the audio system
├── quests/          # Quest templates and generators (via quest_generator.lua)
└── version_log.json # Patch notes displayed on the start screen
```

## UI System

The UI layer combines HUD overlays with modal panels managed by `UIManager`.

> **Note:** The HUD root module lives at `src/ui/hud/root.lua`.

### Start Screen (`src/ui/start_screen.lua`)

- **Start Game** – Launches a new session.
- **Load Game** – Opens the save slot panel (`src/ui/save_load.lua`).
- **Settings** – Toggles the settings panel overlay (`src/ui/settings_panel.lua`).
- **Version Log** – Displays patch notes sourced from `content/version_log.json`.

### In-Game Panels

- **HUD (`src/ui/hud/`)** – Renders reticle, health/energy/shield bars, quest log, minimap, and hotbar.
- **Docked UI (`src/ui/docked.lua`)** – Tabbed station services (Shop, Quests, Node Market, Furnace handling, cargo interactions).
- **Cargo (`src/ui/cargo/panel.lua`)** – Item management with search and drag/drop.
- **Skills (`src/ui/skills.lua`)** – Shows skill levels and XP progress.
- **Nodes (`src/ui/nodes.lua`)** – Advanced trading UI with candlestick charts, technical indicators, and order placement.
- **Warp (`src/ui/warp.lua`)** – Displays available sectors and warp requirements.
- **Escape Menu (`src/ui/escape_menu.lua`)** – Save/load access, settings shortcut, and quit.
- **Debug Panel (`src/ui/debug_panel.lua`)** – F1-toggled overlay that surfaces FPS, timings, and AI proximity.

Modal panels signal `UIManager.isModalActive()` so gameplay input (movement, firing) can be paused while menus are open.

## File Structure

```
LoveProject/
├── assets/
│   └── fonts/
├── content/
│   ├── items/
│   ├── ships/
│   ├── turrets/
│   ├── projectiles/
│   ├── world_objects/
│   ├── sounds/
│   └── version_log.json
├── docs/
│   ├── ARCHITECTURE_GUIDE.md
│   ├── CONTENT_GUIDE.md
│   ├── PROJECT_DOCUMENTATION.md
│   ├── SYSTEMS_GUIDE.md
│   └── AI_AGENT_GUIDE.md
├── src/
│   ├── components/
│   ├── content/
│   ├── core/
│   ├── effects/
│   ├── entities/
│   ├── libs/
│   ├── managers/
│   ├── shaders/
│   ├── systems/
│   ├── templates/
│   └── ui/
├── main.lua
├── conf.lua
├── build_love.bat
└── love.exe / dlls (Windows runtime helpers for testing)
```

## Getting Started

1. **Install LÖVE 11.x** and ensure `love` is available on your PATH.
2. **Clone** the repository and open a terminal in the project root.
3. **Run** `love .` to launch the start screen.
4. **Package** (Windows): Run `build_love.bat` to create a `.love` archive for distribution alongside the LÖVE executable.

## Development Guide

### Adding a New Entity Type

1. Define a template in `src/templates/` (or extend `entity_factory.lua`).
2. Register content definitions under `content/` if the entity is data-driven.
3. Update relevant systems (rendering, AI, interaction) to recognize the new entity type.

### Adding a New System

1. Create the system module inside `src/systems/`.
2. Require and invoke it from the update loop in `src/game.lua` at the appropriate spot.
3. Expose any events or hooks via `src/core/events.lua` for decoupled communication.
4. Update documentation and manual test instructions.

### Extending the UI

1. Build the panel or widget under `src/ui/` and register it with `UIManager` (either via the registry or direct integration).
2. Respect the theme spacing tokens defined in `src/core/theme.lua`.
3. Use `UIManager.toggle`/`open`/`close` patterns to participate in modal flow.

### Content Updates

1. Add or modify files in `content/`.
2. Run the game to ensure the loader validates and surfaces the new data.
3. Update `docs/CONTENT_GUIDE.md` if new schema fields or workflows are introduced.

## Debugging & Tooling

- **F1** – Toggle the debug panel overlay.
- **F5 / F9** – Quick save / quick load via `StateManager`.
- **Version Log** – Accessible from the start screen for recent changes.
- **Logging** – Uses `src/core/log.lua` with levels controlled by `src/core/debug.lua`.
- **Manual Testing** – Launch the game (`love .`) and exercise scenarios (combat, docking, mining, trading) described in PR summaries.

## AI Contributor Standards

Automated contributors must:

- Follow the AI Agent Contribution Guide.
- Plan work before editing and surface risks or ambiguities.
- Validate builds or document why commands could not be executed.
- Update documentation when behavior changes affect gameplay or workflows.
- Provide detailed PR summaries including manual testing steps.

Refer to `docs/AI_AGENT_GUIDE.md` for the full checklist.

## Performance Considerations

- **Quadtree Queries** – `world:getEntitiesInBounds` uses the optional quadtree when attached; keep bounding boxes conservative to avoid missed collisions.
- **Entity Cleanup** – `world:update` prunes dead entities each frame; ensure systems mark `entity.dead = true` instead of removing directly.
- **Icon Caching** – Icon generation caches procedurally created images. When adding new icon shapes, ensure `icon_renderer` caches are invalidated appropriately.
- **Economy Simulation** – `NodeMarket` caps candle history and throttles order generation; maintain those limits to avoid runaway memory.
- **Shader Usage** – Shaders reside in `src/shaders/`; when adding new ones, guard against unsupported hardware by providing fallbacks.

For deeper architectural details, see `docs/ARCHITECTURE_GUIDE.md` and `docs/SYSTEMS_GUIDE.md`.
