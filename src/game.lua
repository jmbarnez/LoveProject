
local Util = require("src.core.util")
local Config = require("src.content.config")
local Camera = require("src.core.camera")
local World = require("src.core.world")
local Player = require("src.entities.player")
local UI = require("src.core.ui")
local UIManager = require("src.core.ui_manager")
local Content = require("src.content.content")
local Input = require("src.core.input")
local Effects = require("src.systems.effects")
local CollisionSystem = require("src.systems.collision.core")
local SpawningSystem = require("src.systems.spawning")
local RepairSystem = require("src.systems.repair_system")
local PhysicsSystem = require("src.systems.physics")
local RenderSystem = require("src.systems.render")
local AISystem = require("src.systems.ai")
local PlayerSystem = require("src.systems.player")
local Sound = require("src.core.sound")
local BoundarySystem = require("src.systems.boundary_system")

local SpaceStationSystem = require("src.systems.hub")
local MiningSystem = require("src.systems.mining")
local Pickups = require("src.systems.pickups")
local DestructionSystem = require("src.systems.destruction")
local EntityFactory = require("src.templates.entity_factory")
local StatusBars = require("src.ui.hud.status_bars")
local HotbarSystem = require("src.systems.hotbar")

local Indicators = require("src.systems.render.indicators")
local QuestLog = require("src.ui.hud.quest_log")
local Multiplayer = require("src.core.multiplayer")
local QuestSystem = require("src.systems.quest_system")
local Events = require("src.core.events")
local StateManager = require("src.managers.state_manager")
local NodeMarket = require("src.systems.node_market")
local PortfolioManager = require("src.managers.portfolio")
local PlayerRef = require("src.core.player_ref")
local Log = require("src.core.log")

local Game = {}

-- Internal state
local world
local camera
local player
local hub -- Keep a reference to the hub for game logic
local clickMarkers = {}
local bounty = { uncollected = 0, entries = {} }
local hoveredEntity = nil
local hoveredEntityType = nil
local collisionSystem


-- Projectile spawner using the EntityFactory
local function spawn_projectile(x, y, angle, friendly, opts)
    local projectile_id = (opts and opts.projectile) or "gun_bullet"
    opts = opts or {}
    -- Pass through extended projectile options to the factory/template
    local extra_config = {
        angle = angle,
        friendly = friendly,
        damage = opts.damage,
        -- Explicit projectile visual kind override (e.g., 'salvaging_laser')
        kind = opts.kind,
        -- Movement/Guidance overrides
        speed_override = opts.speedOverride or opts.projectileSpeed,
        homing_strength = opts.homingStrength,
        target = opts.target or opts.guaranteedTarget,
        guaranteed_hit = opts.guaranteedHit,
        guaranteed_target = opts.guaranteedTarget,
        -- Visual overrides
        tracer_width = opts.tracerWidth,
        core_radius = opts.coreRadius,
        color = opts.color,
        impact = opts.impact,
        length = opts.length,
        -- Lifetime override (useful for beam pulses)
        timed_life = opts.timed_life,
    }
    -- Tag the projectile's source so collision can ignore self-hit
    extra_config.source = opts.source
    
    local projectile = EntityFactory.create("projectile", projectile_id, x, y, extra_config)
  -- (Debug removed) spawnProjectile call tracing removed for clean build
    if projectile then
        world:addEntity(projectile)
  -- (Debug removed) post-addEntity logging removed for clean build
    end
end

-- All legacy update functions are being removed.
-- Their logic will be handled by dedicated systems in the future.

function Game.load()
  Content.load()
  HotbarSystem.load()
  NodeMarket.init()
  PortfolioManager.init()
  -- Use custom reticle instead of system cursor in-game
  if love and love.mouse and love.mouse.setVisible then love.mouse.setVisible(false) end
  
  -- Initialize sound system
  local soundConfig = require("content.sounds.sounds")
  for event, config in pairs(soundConfig.events) do
    if config.type == "sfx" then
      Sound.attachSFX(event, config.sound, {volume = config.volume, pitch = config.pitch})
    elseif config.type == "music" then
      Sound.attachMusic(event, config.sound, {fadeIn = config.fadeIn})
    end
  end
  -- Log.info("Sound system initialized") -- muted at warn level
  
  -- Start ambient space music
  Sound.triggerEvent('game_start')
  
  world = World.new(Config.WORLD.WIDTH, Config.WORLD.HEIGHT)
  -- Add spawnProjectile function to world so turrets can spawn projectiles
  world.spawn_projectile = spawn_projectile
  camera = Camera.new()

  -- Create the main hub station in the top-left safe quadrant
  hub = EntityFactory.create("station", "hub_station", 5000, 5000)
  if hub then
    world:addEntity(hub)
  else
    Log.error("Failed to create hub station")
    return false
  end


  -- Create a beacon station to protect the top-left quadrant from enemy spawning
  local beacon_station = EntityFactory.create("station", "beacon_station", 7500, 7500)
  if beacon_station then
    world:addEntity(beacon_station)
  else
    Log.error("Failed to create beacon station")
    return false
  end

  -- Add a massive background planet at the world center
  do
    -- Place the planet at the center of the world (15000, 15000)
    local px = 15000
    local py = 15000
    local planet = EntityFactory.create("world_object", "planet_massive", px, py)
    if planet then
      world:addEntity(planet)
    else
      Log.warn("Failed to create planet")
    end
  end

  -- Create a single warp gate far from stations but within world bounds
  do
    -- Place warp gate in a clear area away from all stations
    -- Hub is at (5000, 5000), beacon at (7500, 7500)
    -- Place warp gate at (12000, 12000) - well away from stations but within 30000x30000 world
    local warp_gate = EntityFactory.create("warp_gate", "basic_warp_gate", 12000, 12000, {
        name = "Warp Gate",
        isActive = true,
        activationCost = 0,
        requiresPower = false
    })

    if warp_gate and world then
      world:addEntity(warp_gate)
    else
      Log.error("Failed to create warp gate")
      return false
    end
  end

  -- Spawn the player
  local spawn_margin = assert(Config.SPAWN and Config.SPAWN.HUB_BUFFER, "Config.SPAWN.HUB_BUFFER is required")
  local angle = math.random() * math.pi * 2
  -- Spawn within the hub weapons-disable zone
  local spawn_dist = (hub and (hub.shieldRadius or 600) or 600) - spawn_margin
  local px = (hub and hub.components and hub.components.position and hub.components.position.x or 500) + math.cos(angle) * spawn_dist
  local py = (hub and hub.components and hub.components.position and hub.components.position.y or 500) + math.sin(angle) * spawn_dist
  -- Start player with basic combat drone
  player = Player.new(px, py, "starter_frigate_basic")
  if player then
    world:addEntity(player)
    HotbarSystem.populateFromPlayer(player)
    -- Set global player reference for UI systems
    PlayerRef.set(player)
  else
    Log.error("Failed to create player")
    return false
  end

  camera:setTarget(player)
  SpawningSystem.init(player, hub, world)
  PlayerSystem.init(world)
  collisionSystem = CollisionSystem:new({x = 0, y = 0, width = world.width, height = world.height})

  world:setQuadtree(collisionSystem.quadtree)
  -- Initialize player with clean inventory and starting credits
  player:setGC(10000)
  
  -- Give player some basic shield modules to test the system
  if not player.inventory then
    player.inventory = {}
  end
  player.inventory["shield_module_basic"] = 2  -- Give 2 basic shield modules

  Input.init({
    camera = camera,
    player = player,
    world = world,
    getInventoryOpen = function() return UIManager.isOpen("inventory") end,
    setInventoryOpen = function(value) if value then UIManager.open("inventory") else UIManager.close("inventory") end end,
    getBountyOpen = function() return UIManager.isOpen("bounty") end,
    setBountyOpen = function(value) if value then UIManager.open("bounty") else UIManager.close("bounty") end end,
    clickMarkers = clickMarkers,
    bounty = bounty,
    hoveredEntity = hoveredEntity,
    hoveredEntityType = hoveredEntityType
  })
  
  -- Initialize UI Manager
  UIManager.init()
  
  -- Initialize multiplayer system
  Multiplayer.init(world, player)
  QuestLog = QuestLog:new()
  
  -- Set up event listeners for automatic sound effects
  Events.on(Events.GAME_EVENTS.PLAYER_DAMAGED, function(data)
    Sound.playSFX("hit")
  end)
  
  Events.on(Events.GAME_EVENTS.ENTITY_DESTROYED, function(data)
    Sound.playSFX("explosion")
  end)
  
  Events.on(Events.GAME_EVENTS.PLAYER_DIED, function(data)
    Sound.playSFX("player_death")
  end)

  Events.on(Events.GAME_EVENTS.CAN_DOCK, function(data)
    player.canDock = data.canDock
  end)
  
  Events.on(Events.GAME_EVENTS.DOCK_REQUESTED, function()
    if player.canDock then
      if player.docked then
        player:undock()
      else
        player:dock(hub)
      end
    end
  end)


  Events.on(Events.GAME_EVENTS.WARP_REQUESTED, function()
    if not player or not world then return end
    local gates = world:get_entities_with_components("warp_gate")
    for _, gate in ipairs(gates) do
      if gate.canInteractWith and gate:canInteractWith(player) then
        gate:activate(player)
        return
      end
    end
  end)
  
  -- Initialize quest system with player reference and event listeners
  QuestSystem.init(player)
  
  -- Initialize state manager for save/load functionality
  StateManager.init(player, world)
  
  -- Enable event debug logging temporarily
  -- Events.setDebug(true) -- Disabled to reduce console spam
end

function Game.update(dt)
    Input.update(dt)
    UIManager.update(dt, player)
    StatusBars.update(dt, player)
    local input = Input.getInputState()
    
    -- Update multiplayer system
    Multiplayer.update(dt)
    
    -- Update all systems
    PlayerSystem.update(dt, player, input, world, hub)
    AISystem.update(dt, world, spawn_projectile)
    -- Update physics and collisions first so any damage/death flags set by collisions
    -- are visible to the destruction system in the same frame.
    PhysicsSystem.update(dt, world:getEntities())
    BoundarySystem.update(world)
    collisionSystem:update(world, dt)
    -- Process deaths: spawn effects, wreckage, loot before cleanup
    local gameState = { bounty = bounty }
    DestructionSystem.update(world, gameState)
    SpawningSystem.update(dt, player, hub, world)
    RepairSystem.update(dt, player, world)
    SpaceStationSystem.update(dt, hub)
    -- Mining progression (per-cycle, per-asteroid)
    MiningSystem.update(dt, world, player)
    -- Magnetic item pickup system
    Pickups.update(dt, world, player)

    -- Update engine trail after physics so thruster state is preserved
    local EngineTrailSystem = require("src.systems.engine_trail")
    EngineTrailSystem.update(dt, world)

    Effects.update(dt)
    QuestSystem.update(player)
    NodeMarket.update(dt)

    -- Update warp gates
    local WarpGateSystem = require("src.systems.warp_gate_system")
    WarpGateSystem.updateWarpGates(world, dt)

    camera:update(dt)
    world:update(dt) -- This handles dead entity cleanup
    
    -- Update state manager (handles auto-saving)
    StateManager.update(dt)
    
    -- Process queued events each frame
    Events.processQueue()

    HotbarSystem.update(dt)

    -- Expire click markers so they don't get stuck on screen.
    for i = #clickMarkers, 1, -1 do
        local m = clickMarkers[i]
        m.t = m.t + dt
        if m.t >= m.dur then
            table.remove(clickMarkers, i)
        end
    end

    -- Debug: enemies list can be noisy; suppress in normal play
    -- local enemies = world:getEntitiesWithComponents("ai")
    -- Log.debug("Enemies in world:", enemies)
end

function Game.resize(w, h)
    if world then
        world:resize(w, h)
    end
end

function Game.draw()
    world:drawBackground(camera)
    camera:apply()
    if DEBUG_DRAW_BOUNDS then world:drawBounds() end
    
    -- *** This is the crucial fix ***
    -- The hub is now passed to the RenderSystem so it can be drawn.
    RenderSystem.draw(world, camera, player, clickMarkers, hoveredEntity, hoveredEntityType)
    
    Effects.draw()
    
    camera:reset()
    
    -- Draw UI overlay before HUD
    UIManager.drawOverlay()
    
    UI.drawHUD(player, world, world:get_entities_with_components("ai"), hub, world:get_entities_with_components("wreckage"), {}, camera, Multiplayer.getRemotePlayers())
    
    -- Selection box removed (manual combat)

    -- Draw all UI components through UIManager
    QuestLog:draw(player)
    UIManager.draw(player, world, world:get_entities_with_components("ai"), hub, world:get_entities_with_components("wreckage"), {}, bounty)
    
    Indicators.drawTargetingBorder(world)
end

return Game
