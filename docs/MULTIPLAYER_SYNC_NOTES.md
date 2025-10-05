# Multiplayer Synchronisation Notes

This document outlines the current networking capabilities in Novus and the additional work required to synchronise AI enemies and richer player state (health, shields, energy) between peers.

## Current Capabilities

* **Player snapshots contain only transform data.** `NetworkSync.update` publishes the local player's position and velocity each frame, while remote proxies are spawned and updated from the incoming snapshots. No combat stats are serialised. 【F:src/systems/network_sync.lua†L66-L139】【F:src/systems/network_sync.lua†L153-L204】
* **The server sanitises state down to transforms.** When the host ingests a snapshot it keeps only the numeric position/velocity values; any extra fields are discarded. 【F:src/core/network/server.lua†L32-L67】
* **World snapshots replicate static scenery.** The host builds a world snapshot that includes stations and interactable world objects, but it deliberately skips dynamic combatants (enemies, projectiles, loot). 【F:src/game.lua†L213-L242】
* **Simulation still runs locally on every peer.** AI, physics, and combat systems execute client-side, though the host suppresses enemy spawning to avoid divergent waves. 【F:src/game.lua†L348-L399】

These constraints mean the current netcode is suitable for "ambient" co-presence (seeing other pilots move) but not combat synchronisation.

## Syncing Player Health/Shields

Adding health/shield/energy synchronisation is a contained change because those values already live on the `health` component for both players and enemies. 【F:src/entities/player.lua†L110-L157】【F:src/systems/player.lua†L422-L437】 The main tasks are:

1. **Extend the client snapshot.** Include `health = { hp, maxHP, shield, maxShield, energy, maxEnergy }` when `NetworkSync.update` sends the local state. 【F:src/systems/network_sync.lua†L153-L186】
2. **Relax the server sanitiser.** Update `sanitiseState`/`sanitiseSnapshot` so these additional fields survive transit and are validated. 【F:src/core/network/server.lua†L32-L67】
3. **Apply incoming stats.** When `ensureRemoteEntity` spawns a remote player, push the received health values into the proxy entity so HUD elements and targeting can read accurate data. 【F:src/systems/network_sync.lua†L88-L137】
4. **Surface to UI (optional).** Remote health could power nameplates or squad panels; this involves updating HUD systems to render shields/HP for remote players using the replicated component. 【F:src/ui/hud/hud_status_bars.lua†L428-L480】

Complexity: **Low-to-medium.** The data already exists; the work is wiring it through the network layer and ensuring UI consumers tolerate missing fields for legacy sessions.

## Syncing Enemy State

Synchronising enemies is significantly more involved because those entities are currently local to each peer.

1. **Choose an authority.** Today AI steering and combat run everywhere. Moving to host-authoritative combat means clients should stop running AI (`AISystem.update`) and instead accept enemy transforms/damage from the host. Alternatively, clients could stay predictive but must reconcile with host corrections.
2. **Serialise enemies.** Extend `buildWorldSnapshotFromWorld` (and possibly a high-frequency delta stream) to include active enemy entities: their type, transform, velocity, health, and relevant AI state (target, behaviour flags). 【F:src/game.lua†L213-L242】
3. **Broadcast deltas.** Full snapshots will not scale for moment-to-moment combat. Introduce periodic enemy update messages (similar to player snapshots) from the host, containing only entities that moved or took damage since the last tick. This likely lives beside `NetworkSync.update`.
4. **Apply host updates.** Clients need a mirror system to spawn/despawn enemy proxies, drive their physics from networked transforms, and apply replicated health/shield values so local collisions and VFX respond correctly. Use the same component interfaces enemies already expose (`components.health`, `components.position`). 【F:src/templates/enemy.lua†L39-L59】
5. **Route damage through the network.** Collision and turret systems currently mutate health directly when they detect hits. 【F:src/systems/collision/effects.lua†L88-L189】【F:src/systems/turret/beam_weapons.lua†L185-L209】 For host authority, only the host should resolve hits; clients need to send "fire" or "hit" intents and wait for the replicated health update to animate damage.
6. **Handle spawning and death.** The host already owns spawning (`SpawningSystem.update` runs only on the host). 【F:src/game.lua†L358-L377】 Extend the existing world snapshot or dedicated messages to notify clients about new enemy spawns and deaths so their local worlds stay in sync.

Complexity: **High.** Beyond serialising more data, enemy sync requires architectural changes to make the host authoritative over combat resolution. Expect to touch AI, collision, turret, and effect systems so they can operate in a "network client" mode without double-applying damage or spawning duplicate projectiles.

## Recommended Phasing

1. **Player stats first** – ensures co-op players see consistent health/shields without altering combat authority.
2. **Host authoritative combat toggle** – gate new behaviour behind a feature flag so the existing solo experience stays stable while multiplayer combat matures.
3. **Incremental enemy replication** – start with transform sync, then layer in damage events, then projectiles/abilities.
4. **Client prediction/lag handling** – once the basic replication works, add smoothing and reconciliation to hide latency spikes.

Documenting these steps and landing them incrementally will minimise regression risk while bringing multiplayer combat online.
