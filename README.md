# Novus - Space Trading & Combat Game

A Love2D-based space trading and combat game inspired by DarkOrbit, featuring ship customization, quests, mining, trading, and multiplayer capabilities.

## Quick Start

### Prerequisites
- **Love2D 11.x**: Download from [love2d.org](https://love2d.org)
- **Lua 5.1**: Included with Love2D

### Running the Game
1. Install Love2D on your system
2. Navigate to the project directory
3. Run: `love .` (or drag folder onto Love2D executable)

### Building Distribution
- **Windows**: Use `build_love.bat` to create `.love` file
- **Distribution**: Package with Love2D executable for standalone

## Game Features

- **Space Combat**: Ship-to-ship combat with various weapons and projectiles
- **Trading System**: Buy/sell items, ships, and equipment
- **Mining**: Extract resources from asteroids
- **Quest System**: Procedural and scripted missions
- **Ship Customization**: Equip different turrets and modules
- **Multiplayer**: Basic multiplayer support
- **Trading Nodes**: Stock market simulation with technical analysis
- **Sector Warping**: Travel between different galactic sectors

## Documentation

This project includes comprehensive documentation to help you understand and extend the codebase:

### 📚 Main Documentation
- **[PROJECT_DOCUMENTATION.md](PROJECT_DOCUMENTATION.md)** - Complete project overview and navigation guide
- **[ARCHITECTURE_GUIDE.md](ARCHITECTURE_GUIDE.md)** - Technical architecture and ECS system details
- **[SYSTEMS_GUIDE.md](SYSTEMS_GUIDE.md)** - Detailed information about all game systems
- **[CONTENT_GUIDE.md](CONTENT_GUIDE.md)** - How to create and manage game content
- **[UI_GUIDE.md](UI_GUIDE.md)** - User interface system and component development

### 🎮 Game Controls

#### Movement
- **WASD** or **Arrow Keys**: Move ship
- **Right Click**: Set move destination
- **Space**: Boost (sustained thrust with energy cost)

#### Combat
- **Left Click**: Target and fire weapons
- **Q/E/R**: Hotbar actions (1-5)
- **Shift**: Shield ability (damage reduction)

#### Interface
- **Tab**: Toggle inventory
- **M**: Toggle minimap
- **F1**: Debug panel
- **Escape**: Main menu

#### Docked Interface
- **Shop Tab**: Buy/sell items and ships
- **Ship Tab**: Equipment and customization
- **Quests Tab**: Mission management
- **Nodes Tab**: Trading interface

## Project Structure

```
LoveProject/
├── main.lua                    # Entry point
├── conf.lua                    # Love2D configuration
├── src/                        # Source code
│   ├── core/                   # Core systems
│   ├── components/             # ECS components
│   ├── entities/               # Entity implementations
│   ├── systems/                # Game systems
│   ├── templates/              # Entity templates
│   ├── ui/                     # User interface
│   └── content/                # Content management
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

## Architecture Overview

The game uses a **hybrid Entity-Component-System (ECS)** pattern:

- **Entities**: Game objects (ships, projectiles, stations, etc.)
- **Components**: Data containers (position, health, renderable, etc.)
- **Systems**: Logic processors that operate on entities with specific components

### Key Systems

1. **Physics System**: Movement and velocity updates
2. **Collision System**: Entity-to-entity collisions and damage
3. **AI System**: Enemy ship behavior and decision making
4. **Rendering System**: Visual output and effects
5. **UI System**: User interface and interaction
6. **Content System**: Auto-discovery and loading of game content

## Development

### Adding New Content

1. Create content definition file in appropriate `content/` directory
2. Follow existing patterns for your content type
3. Content will be automatically loaded on game start

### Adding New Features

1. Create system file in `src/systems/`
2. Add update call in `src/game.lua`
3. Implement component interactions
4. Add UI integration if needed

### Debugging

- **Debug Panel**: Press F1 for debug information
- **Console Logging**: Use `Log` module for output
- **Entity Inspection**: Debug panel shows entity details
- **Performance**: Debug panel shows frame timing

## Content System

The game uses a file-based content system with automatic discovery:

- **Items**: Equipment, resources, modules
- **Ships**: Player and AI-controlled vessels
- **Turrets**: Weapon systems
- **Projectiles**: Ammunition types
- **World Objects**: Stations, asteroids, planets

Content is defined in Lua files and automatically loaded with validation and normalization.

## Multiplayer

Basic multiplayer support is included with:
- Player synchronization
- Event broadcasting
- Connection management
- State reconciliation

## Performance

The game includes several performance optimizations:
- Quadtree for spatial queries and collision detection
- Entity cleanup and memory management
- Icon caching for UI elements
- Distance-based rendering optimizations

## Contributing

1. Follow the existing code style and patterns
2. Add documentation for new features
3. Test changes thoroughly
4. Use the debug panel for development

## License

See `license.txt` for license information.

## Credits

- **Love2D**: Game engine
- **Press Start 2P**: Font by codeman38
- **Audio**: Various sound effects and music

---

For detailed information about the codebase, refer to the comprehensive documentation files listed above.