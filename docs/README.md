# Novus Project

Novus is a single-player LÖVE 11.x game that mixes space combat, mining, and a procedurally-driven economy. The codebase is organized around a lightweight entity-component architecture with modular systems for gameplay, UI, and content pipelines.

## Table of Contents

* [Project Structure](#project-structure)
* [Getting Started](#getting-started)
  * [Prerequisites](#prerequisites)
  * [Installation](#installation)
  * [Running the Application](#running-the-application)
* [Code Entry Point](#code-entry-point)
* [Dependencies](#dependencies)
* [License](#license)
* [AI Collaboration Guide](#ai-collaboration-guide)

## Project Structure

Key directories and files in the repository:

* `main.lua`: Boots the start screen, configures global systems, and hands the update/draw loop to `src/game.lua` when a session starts.
* `conf.lua`: LÖVE bootstrap settings such as window size, vsync, and save identity.
* `assets/`: Currently stores shipped fonts. Drop additional art/audio here when packaging.
* `content/`: Author-defined game data (ships, turrets, items, projectiles, world objects, sound definitions). The runtime loader (`src/content/content.lua`) discovers and validates this tree during boot.
* `src/`: Gameplay and engine code broken into focused subdirectories:
  * `components/`: Data tables that describe entity state (health, physics, ai, etc.).
  * `content/`: Content ingestion pipeline (`design_loader`, `validator`, `normalizer`, quest/sector generators).
  * `core/`: Foundational services (camera, events, input, world simulation, theme, UI manager, audio, utilities).
  * `effects/`: Runtime-only visual effects such as engine trails.
  * `entities/`: Blueprints for complex entities (player, wreckage, stations) that stitch components together.
  * `libs/`: Embedded third-party helpers like `json.lua`.
  * `managers/`: Persistent state coordinators including the save system (`state_manager.lua`) and market portfolio manager.
  * `shaders/`: GLSL snippets used by the UI and special effects (e.g., aurora title shader).
  * `systems/`: Gameplay processors (AI, physics, collision, spawning, mining, repair, node market, quest progression, rendering, etc.).
  * `templates/`: Entity factory implementations that instantiate ships, projectiles, stations, and pickups.
  * `ui/`: Start screen, HUD, docked interfaces, modal panels, and shared UI widgets.

## Getting Started

### Prerequisites

* **LÖVE 11.x**: Download the matching runtime for your platform from [love2d.org](https://love2d.org).

### Installation

1. **Install LÖVE** following the official instructions for your OS.
2. **Clone or download** this repository.
3. (Optional) **Install git-lfs** if you intend to version large binary assets in `assets/`.

### Running the Application

1. Open a terminal and change into the repository root.
2. Launch the game with `love .`, or drag the folder onto the LÖVE executable on Windows/macOS.
3. To package a distributable build on Windows, run `build_love.bat` to generate a `.love` archive that can be bundled with the official runtime.

## Code Entry Point

* **`conf.lua`**: Loaded first by LÖVE to configure the window, identity, audio mix, and minimum resolution.
* **`main.lua`**: Initializes debug/logging, the theme, sound settings, and the start screen. It routes Love callbacks (`love.load`, `love.update`, `love.draw`, input handlers) to the appropriate modules and transitions into the game screen once a session begins.
* **`src/game.lua`**: Owns the simulation lifecycle. It loads content, builds the world, creates stations and the player, and coordinates the per-frame system update/draw order (player input, AI, physics, collisions, spawning, mining, pickups, quests, economy, rendering, and UI hand-off).

## Dependencies

The project targets **LÖVE 11.x** and ships with any remaining Lua helpers in-repo. No external package manager is required.

* `src/libs/json.lua`: Embedded JSON encoder/decoder used by save/load routines and content tooling.

## License

Novus is distributed under the MIT License. Refer to `license.txt` for the full terms.

## AI Collaboration Guide

Automated contributors should review the [AI Agent Contribution Guide](./AI_AGENT_GUIDE.md) before submitting work. It documents instruction-discovery requirements, planning expectations, validation steps, and communication standards for this repository.
