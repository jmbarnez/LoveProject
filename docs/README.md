# Novus Project

This project is a LÖVE2D game, featuring an ECS-like architecture with a clear separation of concerns for content definitions, core engine functionalities, game systems, and a modular UI.

## Table of Contents

*   [Project Structure](#project-structure)
*   [Getting Started](#getting-started)
    *   [Prerequisites](#prerequisites)
    *   [Installation](#installation)
    *   [Running the Application](#running-the-application)
*   [Code Entry Point](#code-entry-point)
*   [Dependencies](#dependencies)
*   [License](#license)

## Project Structure

The project is organized into several key directories:

*   `assets/`: Contains game assets such as fonts, sounds, and potentially images (though not explicitly listed, it's a common pattern).
*   `content/`: Defines game content, including items, projectiles, ships, sounds, turrets, and world objects. This directory is crucial for configuring game entities and their properties.
*   `src/`: The core source code of the application, further divided into:
    *   `src/components/`: Data-only tables that define properties of entities (e.g., `health.lua`, `physics.lua`).
    *   `src/content/`: Modules for loading, validating, and managing game content (e.g., `content.lua`, `design_loader.lua`).
    *   `src/core/`: Core engine functionalities such as camera, events, input, physics, UI management, and utility functions.
    *   `src/entities/`: Definitions for various game entities like the player, remote players, and item pickups.
    *   `src/libs/`: External or utility libraries, such as `json.lua`.
    *   `src/managers/`: Modules for managing game states or portfolios (e.g., `portfolio.lua`, `state_manager.lua`).
    *   `src/systems/`: Contains the game logic that operates on entities with specific components (e.g., `ai.lua`, `physics.lua`, `render.lua`, `turret/`). This directory is further subdivided for collision, rendering, and turret systems.
    *   `src/templates/`: Blueprints or factories for creating various game objects (e.g., `ship.lua`, `projectile.lua`).
    *   `src/ui/`: Modules for the user interface, including various screens (start, escape, settings), HUD elements, and common UI components.

## Getting Started

To get the Novus project up and running, follow these steps:

### Prerequisites

*   **LÖVE2D 11.x**: The game is built using the LÖVE2D framework. You will need version 11.x installed on your system.

### Installation

1.  **Download LÖVE2D**: Visit the official LÖVE2D website at [love2d.org](https://love2d.org) and download the appropriate installer for your operating system.
2.  **Install LÖVE2D**: Follow the installation instructions provided on the LÖVE2D website.
3.  **Clone the Repository**: Obtain the project files by cloning the repository or downloading the source code.

### Running the Application

1.  **Navigate to the Project Root**: Open your terminal or command prompt and navigate to the root directory of the Novus project (e.g., `cd c:/Users/JBCry/Desktop/LoveProject`).
2.  **Execute LÖVE2D**: Run the game using one of the following methods:
    *   **Command Line**: Type `love .` and press Enter.
    *   **Drag and Drop**: Drag the entire project folder onto the LÖVE2D executable.

## Code Entry Point

The application's primary entry point is `main.lua`.

*   **`conf.lua`**: This file is loaded first by the LÖVE2D engine to configure basic window settings (title, resolution, fullscreen, VSync).
*   **`main.lua`**: Defines the core LÖVE2D callback functions (`love.load()`, `love.update(dt)`, `love.draw()`). It orchestrates the overall application flow, handling screen transitions between the "start" screen (`src.ui.start_screen`) and the "game" screen (`src.game`). It also initializes global settings, sound, input, and the UI theme.
*   **`src/game.lua`**: This module is loaded by `main.lua` when the application transitions to the "game" screen. It handles extensive game-specific initialization, including loading game content, initializing various game systems, creating the game world and entities, and setting up in-game event listeners.

## Dependencies

The project primarily relies on the LÖVE2D framework. Additionally, it includes a self-contained Lua JSON parsing library:

*   **`src/libs/json.lua`**: A local Lua module for JSON serialization and deserialization, included directly within the project.

## License

This project is licensed under the MIT License. See the `license.txt` file for more details.