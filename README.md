Dark Orbit Clone (Prototype) — LÖVE (Lua)

A lightweight, single‑player prototype inspired by DarkOrbit built with the LÖVE 2D engine. Includes smooth ship movement, mouse aiming, shooting, simple enemy AI, parallax starfield, and a minimalist HUD with a minimap.

Run
- Install LÖVE 11.x from https://love2d.org
- From this folder, run: `love .`

Controls
- Move: Right click to set a move destination
- Target: Left click an enemy to lock
- Turret: Auto‑fires when locked and in range
- Quit: `Esc`

Structure
- `main.lua`: Entry point delegating to `src/game.lua`
- `src/game.lua`: Core game state, loop, and orchestration
- `conf.lua`: Window and app config
- `src/player.lua`: Player ship logic
- `src/enemy.lua`: Simple enemy AI and behavior
- `src/bullet.lua`: Projectiles
- `src/world.lua`: World bounds and parallax starfield
- `src/camera.lua`: Smooth following camera
- `src/ui.lua`: HUD and minimap
- `src/util.lua`: Math helpers and collision

Next Steps
- Add loot crates and resources
- Add abilities (rockets, EMP, repair)
- Improve AI behaviors and factions
- Add sectors, gates, and missions
- Multiplayer (love-enet) or external server later

Notes
- This is a prototype for fast iteration. Physics, balance, and visuals are intentionally simple and easy to extend.
