# Novus - Space Mining & Combat Game

A 2D space exploration game built with LÖVE2D featuring mining, combat, trading, and ship customization in a procedurally generated universe.

## 🚀 Game Overview

**Novus** is a space simulation game where you pilot a ship through asteroid fields, mine resources, engage in combat with enemy drones, and trade at space stations. The game features:

- **Mining System**: Extract valuable ores from asteroids using specialized mining lasers
- **Combat**: Engage hostile drones and ships with various weapon systems
- **Ship Customization**: Equip different turrets, engines, and modules
- **Trading**: Buy and sell resources at space stations
- **Quest System**: Complete contracts and missions for rewards
- **Procedural Generation**: Explore dynamically generated asteroid fields and encounters
- **Skill Progression**: Level up your mining, gunnery, and other skills

## 🎮 How to Play

### Basic Controls
- **WASD** or **Arrow Keys**: Move your ship
- **Mouse**: Aim and fire weapons
- **Left Click**: Fire weapons / Interact with objects
- **Right Click**: Use secondary abilities
- **E**: Interact with stations and objects
- **Tab**: Open cargo
- **I**: Open skills menu
- **ESC**: Pause menu

### Gameplay Loop
1. **Start** by mining asteroids for basic resources (Tritanium, Palladium)
2. **Combat** enemy drones to gain experience and loot
3. **Visit stations** to trade resources, accept quests, and upgrade your ship
4. **Equip better weapons** and modules as you progress
5. **Complete quests** for rewards and reputation
6. **Explore** different sectors and discover new challenges

### Mining
- Use **Mining Lasers** to extract resources from asteroids
- Different asteroids yield different materials
- Higher mining skill = better efficiency and more resources

### Combat
- **Gun Turrets**: Rapid-fire kinetic weapons
- **Laser Turrets**: High-damage energy weapons  
- **Missile Launchers**: Homing projectiles with lock-on
- **Salvaging Lasers**: Extract materials from destroyed ships

### Ship Equipment
- **Turrets**: Primary weapons mounted on hardpoints
- **Engines**: Affect ship speed and maneuverability
- **Modules**: Provide various bonuses and abilities
- **Shields**: Protect against incoming damage

## 📦 Installation

### Prerequisites
- **LÖVE2D 11.x** - Download from [love2d.org](https://love2d.org)

### Quick Start (Windows)
1. Download and install LÖVE2D
2. Download this repository
3. Double-click `Novus.love` to run the game

### Manual Installation
1. **Download LÖVE2D**: Visit [love2d.org](https://love2d.org) and download for your platform
2. **Install LÖVE2D**: Follow the installation instructions
3. **Get the Game**: Clone this repository or download the source code
4. **Run the Game**:
   - **Command Line**: Navigate to the project folder and run `love .`
   - **Drag & Drop**: Drag the entire project folder onto the LÖVE2D executable
   - **Windows**: Double-click `Novus.love` if available

### Building from Source
```bash
# Clone the repository
git clone <repository-url>
cd LoveProject

# Run with LÖVE2D
love .
```

## 🏗️ Project Structure

```
├── assets/           # Game assets (fonts, sounds, music)
├── content/          # Game content definitions
│   ├── items/        # Item definitions and properties
│   ├── projectiles/  # Weapon projectile definitions
│   ├── ships/        # Ship designs and stats
│   ├── turrets/      # Weapon turret definitions
│   └── world_objects/ # Stations, asteroids, etc.
├── src/              # Source code
│   ├── components/   # ECS component definitions
│   ├── core/         # Core engine systems
│   ├── entities/     # Game entity implementations
│   ├── systems/      # Game logic systems
│   ├── templates/    # Entity creation templates
│   └── ui/           # User interface components
├── docs/             # Documentation
└── main.lua          # Game entry point
```

## 🎯 Game Features

### Current Version (0.35)
- **Turret Telemetry & Mining Polish**: Enhanced turret systems and mining mechanics
- **Persistent Equipment**: Ship equipment saves across sessions
- **Quest System**: Procedural contracts and mission tracking
- **Ship Customization**: Modular equipment and weapon systems
- **Combat AI**: Intelligent enemy behavior and targeting
- **Trading System**: Buy/sell resources at space stations

### Core Systems
- **ECS Architecture**: Entity-Component-System design for modular gameplay
- **Physics Engine**: Realistic ship movement and collision detection
- **Audio System**: Dynamic sound effects and music
- **UI Framework**: Modular interface system with tooltips and notifications
- **Save System**: Multiple save slots with auto-save functionality
- **Procedural Generation**: Dynamic content creation for replayability

## 🛠️ Development

### Code Entry Points
- **`main.lua`**: LÖVE2D callbacks and main game loop
- **`src/game.lua`**: Core game logic and system orchestration
- **`conf.lua`**: Window configuration and engine settings

### Key Systems
- **Content Pipeline**: Loads and validates game content from JSON/Lua files
- **Physics System**: Handles movement, collisions, and interactions
- **Render System**: Manages graphics and visual effects
- **AI System**: Controls enemy behavior and decision making
- **UI Manager**: Handles all user interface interactions

## 📋 Requirements

- **LÖVE2D 11.x**
- **Lua 5.1+** (included with LÖVE2D)
- **OpenGL 2.1+** or **OpenGL ES 2+**
- **OpenAL** (for audio)

## 🎵 Audio

The game includes:
- **Background Music**: Atmospheric space ambient tracks
- **Sound Effects**: Weapon fire, mining, UI interactions
- **Dynamic Audio**: 3D positional audio that follows the player

## 🐛 Troubleshooting

### Common Issues
- **Game won't start**: Ensure LÖVE2D 11.x is installed correctly
- **Audio issues**: Check OpenAL installation
- **Performance**: Try reducing graphics settings in the options menu
- **Save issues**: Check file permissions in the save directory

### Debug Mode
- Press **F1** to toggle debug information
- Press **F2** to show collision boundaries
- Press **F3** to display performance metrics

## 📄 License

This project is licensed under the MIT License. See `license.txt` for details.

## 🤝 Contributing

Contributions are welcome! Please read the documentation in the `docs/` folder for:
- Architecture guidelines
- Content creation guides
- UI development patterns
- System implementation details

## 📚 Documentation

- **`docs/ARCHITECTURE_GUIDE.md`**: System architecture overview
- **`docs/CONTENT_GUIDE.md`**: How to create new game content
- **`docs/UI_GUIDE.md`**: User interface development
- **`docs/SYSTEMS_GUIDE.md`**: Game system implementations

---

**Enjoy exploring the depths of space in Novus!** 🌌
