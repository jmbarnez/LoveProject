 --[[
    Core game loop module.

    This module stitches together the content pipeline, world simulation, and
    rendering subsystems. Love2D hands us the update/draw hooks in main.lua;
    here we translate those hooks into system updates, entity spawning, and
    high-level gameplay orchestration. Keeping the heavy lifting in this file
    makes it easier for future maintainers to reason about load order and
    lifecycle events.
]]

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
local Viewport = require("src.core.viewport")
local Theme = require("src.core.theme")

local SpaceStationSystem = require("src.systems.hub")
local MiningSystem = require("src.systems.mining")
local Pickups = require("src.systems.pickups")
local DestructionSystem = require("src.systems.destruction")
local InteractionSystem = require("src.systems.interaction")
local InputIntentSystem = require("src.systems.input_intents")
local EntityFactory = require("src.templates.entity_factory")
local LifetimeSystem = require("src.systems.lifetime")
local EngineTrailSystem = require("src.systems.engine_trail")
local WarpGateSystem = require("src.systems.warp_gate_system")
local SystemPipeline = require("src.core.system_pipeline")
local ECS = require("src.core.ecs")
local StatusBars = require("src.ui.hud.status_bars")
local SkillXpPopup = require("src.ui.hud.skill_xp_popup")
local HotbarSystem = require("src.systems.hotbar")

local Indicators = require("src.systems.render.indicators")
local QuestLogHUD = require("src.ui.hud.quest_log")
local QuestSystem = require("src.systems.quest_system")
local Events = require("src.core.events")
local StateManager = require("src.managers.state_manager")
local NodeMarket = require("src.systems.node_market")
local PortfolioManager = require("src.managers.portfolio")
local PlayerRef = require("src.core.player_ref")
local Log = require("src.core.log")
local Debug = require("src.core.debug")
local Constants = require("src.core.constants")
local NetworkManager = require("src.core.network.manager")
local NetworkSync = require("src.systems.network_sync")
local RemoteEnemySync = require("src.systems.remote_enemy_sync")

local Game = {}

-- Internal state
local world
local camera
local player
local hub -- Keep a reference to the hub for game logic
local clickMarkers = {}
local hoveredEntity = nil
local hoveredEntityType = nil
local collisionSystem
local windfieldManager
local refreshDockingState
local systemPipeline
local systemContext = {}
local ecsManager
local networkManager
local isMultiplayer = false
local isHost = false
local syncedWorldEntities = {}
local pendingWorldSnapshot = nil
local worldSyncHandlersRegistered = false

-- Expose network manager for external access
function Game.getNetworkManager()
    return networkManager
end

-- Set multiplayer mode (for F3 key)
function Game.setMultiplayerMode(multiplayer, host)
    isMultiplayer = multiplayer
    isHost = host
    Log.info("Game multiplayer mode set:", "multiplayer=" .. tostring(multiplayer), "host=" .. tostring(host))
end

-- Get multiplayer mode
function Game.isMultiplayer()
    return isMultiplayer
end

-- Get host mode
function Game.isHost()
    return isHost
end

-- Make world accessible
Game.world = world
Game.windfield = nil


--[[
    spawn_projectile

    Helper used by turrets and weapons to create projectiles. Most callers only
    know about simple concepts (angle, friendliness, optional overrides) so we
    centralize the translation into EntityFactory options here. This keeps the
    projectile templates flexible while avoiding duplicated glue code.
]]
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
        -- Movement overrides
        speedOverride = opts.speedOverride or opts.projectileSpeed,
        -- Visual overrides
        tracerWidth = opts.tracerWidth,
        coreRadius = opts.coreRadius,
        color = opts.color,
        impact = opts.impact,
        length = opts.length,
        -- Lifetime override (useful for beam pulses)
        timed_life = opts.timed_life,
        -- Attach runtime projectile effects (e.g., homing guidance)
        additionalEffects = opts.additionalEffects,
    }
    -- Tag the projectile's source so collision can ignore self-hit
    extra_config.source = opts.source
    
    local projectile = EntityFactory.create("projectile", projectile_id, x, y, extra_config)
    if projectile then
        world:addEntity(projectile)
    end
end

local function clearSyncedWorldEntities()
    if world then
        for _, entity in ipairs(syncedWorldEntities) do
            if entity then
                world:removeEntity(entity)
            end
        end
    end

    syncedWorldEntities = {}
    hub = nil
end

local function spawnEntityFromSnapshot(entry)
    if not entry or not entry.kind or not entry.id then
        return nil
    end

    local extra = {}
    if entry.extra then
        for key, value in pairs(entry.extra) do
            extra[key] = value
        end
    end

    if entry.angle ~= nil then
        extra.angle = entry.angle
    end

    if next(extra) == nil then
        extra = nil
    end

    return EntityFactory.create(entry.kind, entry.id, entry.x or 0, entry.y or 0, extra)
end

local function applyWorldSnapshot(snapshot)
    if not snapshot or not world then
        Log.warn("applyWorldSnapshot: missing snapshot or world", snapshot ~= nil, world ~= nil)
        return
    end

    Log.info("applyWorldSnapshot: applying snapshot with", #(snapshot.entities or {}), "entities")
    clearSyncedWorldEntities()

    world.width = snapshot.width or world.width
    world.height = snapshot.height or world.height

    for _, entry in ipairs(snapshot.entities or {}) do
        local entity = spawnEntityFromSnapshot(entry)
        if entity then
            entity.isSyncedEntity = true  -- Mark as synced entity to prevent duplication
            world:addEntity(entity)
            if entry.kind == "station" and entry.id == "hub_station" then
                hub = entity
            end
            table.insert(syncedWorldEntities, entity)
        else
            Log.warn("Failed to spawn world entity from snapshot", tostring(entry.kind), tostring(entry.id))
        end
    end
end

local function queueWorldSnapshot(snapshot)
    if not snapshot then
        return
    end

    if not world then
        pendingWorldSnapshot = Util.deepCopy(snapshot)
        return
    end

    applyWorldSnapshot(snapshot)
    pendingWorldSnapshot = nil
end

local function buildWorldSnapshotFromWorld()
    if not world then
        return nil
    end

    local snapshot = {
        width = world.width or 0,
        height = world.height or 0,
        entities = {}
    }

    for _, entity in pairs(world:getEntities()) do
        local components = entity.components or {}
        local position = components.position

        -- Only include entities that are not players, not remote players, and not already synced entities
        if position and not entity.isPlayer and not entity.isRemotePlayer and not entity.isSyncedEntity then
            local entry = nil

            if entity.isStation or components.station then
                local station = components.station or {}
                entry = {
                    kind = "station",
                    id = station.type or "station",
                    x = position.x or 0,
                    y = position.y or 0
                }
            elseif entity.type == "world_object" or components.mineable or components.interactable then
                local subtype = entity.subtype or (components.renderable and components.renderable.type) or "world_object"
                entry = {
                    kind = "world_object",
                    id = subtype,
                    x = position.x or 0,
                    y = position.y or 0
                }
            end

            if entry then
                if position.angle ~= nil then
                    entry.angle = position.angle
                end

                snapshot.entities[#snapshot.entities + 1] = entry
            end
        end
    end

    return snapshot
end

local function broadcastHostWorldSnapshot(peer)
    if not networkManager or not networkManager:isHost() then
        return
    end

    local snapshot = buildWorldSnapshotFromWorld()
    if not snapshot then
        return
    end

    networkManager:updateWorldSnapshot(snapshot, peer)
end

local function registerWorldSyncEventHandlers()
    if worldSyncHandlersRegistered then
        return
    end

    Events.on("NETWORK_WORLD_SNAPSHOT", function(data)
        if isHost then
            return
        end

        local snapshot = data and data.snapshot or nil
        if not snapshot then
            return
        end

        queueWorldSnapshot(snapshot)
    end)

    Events.on("NETWORK_DISCONNECTED", function()
        if isHost then
            return
        end

        clearSyncedWorldEntities()
        pendingWorldSnapshot = nil
    end)

    Events.on("NETWORK_SERVER_STOPPED", function()
        if isHost then
            return
        end

        clearSyncedWorldEntities()
        pendingWorldSnapshot = nil
    end)

    Events.on("NETWORK_SERVER_STARTED", function()
        if not isHost or not world then
            return
        end

        broadcastHostWorldSnapshot()
    end)

    Events.on("NETWORK_ENEMY_UPDATE", function(data)
        if isHost then
            return
        end

        local enemies = data and data.enemies or nil
        if not enemies then
            return
        end

        -- Apply enemy snapshot (RemoteEnemySync.applyEnemySnapshot already sanitizes internally)
        RemoteEnemySync.applyEnemySnapshot(enemies, world)
    end)

    worldSyncHandlersRegistered = true
end

registerWorldSyncEventHandlers()

local function tryCollectNearbyRewardCrate(playerEntity, activeWorld)
  if not playerEntity or not activeWorld then return false end
  if playerEntity.docked then return false end
  if not playerEntity.components or not playerEntity.components.position then return false end

  if not Pickups or not Pickups.findNearestPickup then return false end

  local pickup = Pickups.findNearestPickup(activeWorld, playerEntity, "reward_crate", 280)
  if not pickup or pickup.dead then return false end

  local result = Pickups.collectPickup(playerEntity, pickup)
  if not result then return false end

  Pickups.notifySingleResult(result)
  return true
end

local function createSystemPipeline()
  local steps = {
    function(ctx)
      InputIntentSystem.update(ctx.dt, ctx.player, UIManager)
    end,
    function(ctx)
      PlayerSystem.update(ctx.dt, ctx.player, ctx.input, ctx.world, ctx.hub)
    end,
    function(ctx)
      local pos = ctx.player and ctx.player.components and ctx.player.components.position
      if pos then
        Sound.setListenerPosition(pos.x, pos.y)
      end
    end,
    function(ctx)
      AISystem.update(ctx.dt, ctx.world, spawn_projectile)
    end,
    function(ctx)
      PhysicsSystem.update(ctx.dt, ctx.world:getEntities())
    end,
    function(ctx)
      if ecsManager then
        ecsManager:update(ctx.dt, ctx)
      end
    end,
    function(ctx)
      BoundarySystem.update(ctx.world)
    end,
    function(ctx)
      if ctx.collisionSystem then
        ctx.collisionSystem:update(ctx.world, ctx.dt)
      end
    end,
    function(ctx)
      DestructionSystem.update(ctx.world, ctx.gameState, ctx.hub)
    end,
    function(ctx)
      -- Only run spawning system in single-player mode
      -- When hosting, we want to sync the existing world, not spawn new entities
      if not isMultiplayer then
        SpawningSystem.update(ctx.dt, ctx.player, ctx.hub, ctx.world)
      end
    end,
    function(ctx)
      RepairSystem.update(ctx.dt, ctx.player, ctx.world)
    end,
    function(ctx)
      SpaceStationSystem.update(ctx.dt, ctx.hub)
    end,
    function(ctx)
      MiningSystem.update(ctx.dt, ctx.world, ctx.player)
    end,
    function(ctx)
      Pickups.update(ctx.dt, ctx.world, ctx.player)
    end,
    function(ctx)
      InteractionSystem.update(ctx.dt, ctx.player, ctx.world)
    end,
    function(ctx)
      EngineTrailSystem.update(ctx.dt, ctx.world)
    end,
    function(ctx)
      Effects.update(ctx.dt)
    end,
    function(ctx)
      QuestSystem.update(ctx.player)
    end,
    function(ctx)
      NodeMarket.update(ctx.dt)
    end,
    function(ctx)
      WarpGateSystem.updateWarpGates(ctx.world, ctx.dt)
    end,
    function(ctx)
      if ctx.camera then
        ctx.camera:update(ctx.dt)
      end
    end,
    function(ctx)
      ctx.world:update(ctx.dt)
    end,
    function(ctx)
      StateManager.update(ctx.dt)
    end,
    function(ctx)
      if ctx.refreshDockingState then
        ctx.refreshDockingState()
      end
    end,
    function(ctx)
      Events.processQueue()
    end,
    function(ctx)
      HotbarSystem.update(ctx.dt)
    end,
    function(ctx)
      -- Clean up orphaned utility beam sounds
      local TurretEffects = require("src.systems.turret.effects")
      TurretEffects.cleanupOrphanedSounds()
    end,
    function(ctx)
      -- Update network manager if multiplayer
      if networkManager then
        networkManager:update(ctx.dt)
      end
    end,
    function(ctx)
      -- Update network synchronization if multiplayer
      if networkManager and networkManager:isMultiplayer() then
        NetworkSync.update(ctx.dt, ctx.player, ctx.world, networkManager)
        
        -- Update remote enemy synchronization
        if networkManager:isHost() then
          RemoteEnemySync.updateHost(ctx.dt, ctx.world, networkManager)
        else
          RemoteEnemySync.updateClient(ctx.dt, ctx.world, networkManager)
        end
      end
    end,
  }

  systemPipeline = SystemPipeline.new(steps)
end


--[[
    Game.load
    Game.load

    Boots the playable world, reporting progress back to the optional loading
    screen overlay. The staged structure (content -> systems -> world ->
    entities) is intentionally linear so future systems have an obvious place
    to hook into without breaking save/load behaviour.
]]
function Game.load(fromSave, saveSlot, loadingScreen, multiplayer, isHost)
  Log.setInfoEnabled(true)
  
  -- Set multiplayer state
  isMultiplayer = multiplayer or false
  isHost = isHost or false
  syncedWorldEntities = {}
  pendingWorldSnapshot = nil

  -- updateProgress provides a tiny abstraction so future steps can remain
  -- focused on logic rather than remembering to null-check the loading screen.
  local function updateProgress(step, description)
    if loadingScreen then
      loadingScreen:setProgress(step, description)
    end
  end
  
  -- Step 1: Load content
  updateProgress(0.1, "Loading content...")
  Content.load()
  
  -- Step 2: Initialize systems
  updateProgress(0.2, "Initializing systems...")
  HotbarSystem.load()
  NodeMarket.init()
  PortfolioManager.init()
  
  -- Initialize network manager (always available for F3 hosting)
  updateProgress(0.25, "Initializing network...")
  networkManager = NetworkManager.new()
  if isMultiplayer and isHost then
    networkManager:startHost()
  elseif isMultiplayer and not isHost then
    -- Client mode - attempt connection from start screen parameters
    if _G.PENDING_MULTIPLAYER_CONNECTION and _G.PENDING_MULTIPLAYER_CONNECTION.connecting then
      Log.info("Attempting connection to server from start screen parameters")
      Log.info("Connection details:", _G.PENDING_MULTIPLAYER_CONNECTION.address, _G.PENDING_MULTIPLAYER_CONNECTION.port)
      -- Attempt the connection to the server
      local connectionResult, connectionError = networkManager:joinGame(_G.PENDING_MULTIPLAYER_CONNECTION.address, _G.PENDING_MULTIPLAYER_CONNECTION.port)
      Log.info("Connection result:", connectionResult, connectionError)
      if connectionResult then
        Log.info("Successfully connected to server")
        -- Ensure the game knows it's in client mode
        Game.setMultiplayerMode(true, false)
        _G.PENDING_MULTIPLAYER_CONNECTION = nil -- Clear the pending connection
      else
        Log.error("Failed to connect to server - aborting game load", connectionError)
        -- Connection failed, don't load the game
        return false, connectionError
      end
    else
      Log.error("No pending connection found for client mode - aborting game load")
      -- No connection to attempt, don't load the game
      return false, "No pending connection details found."
    end
  end
  
  -- Step 3: Setup input
  updateProgress(0.3, "Setting up input...")
  -- Use custom reticle instead of system cursor in-game
  if love and love.mouse and love.mouse.setVisible then love.mouse.setVisible(false) end

  -- Step 4: Initialize sound system
  updateProgress(0.4, "Loading sounds...")
  local soundConfig = require("content.sounds.sounds")
  for event, config in pairs(soundConfig.events) do
    if config.type == "sfx" then
      Sound.attachSFX(event, config.sound, {volume = config.volume, pitch = config.pitch})
    elseif config.type == "music" then
      Sound.attachMusic(event, config.sound, {fadeIn = config.fadeIn})
    end
  end

  -- Step 5: Create world
  updateProgress(0.5, "Creating world...")
  world = World.new(Constants.WORLD.WIDTH, Constants.WORLD.HEIGHT)
  -- Add spawnProjectile function to world so turrets can spawn projectiles
  world.spawn_projectile = spawn_projectile
  -- Update the accessible world reference
  Game.world = world
  ecsManager = ECS.new()
  ecsManager:setWorld(world)
  world:setECSWorld(ecsManager)
  ecsManager:addSystem(LifetimeSystem.create())
  camera = Camera.new()

  -- Step 6: Create stations
  updateProgress(0.6, "Creating stations...")
  if not isMultiplayer or isHost then
    hub = EntityFactory.create("station", "hub_station", 5000, 5000)
    if hub then
      world:addEntity(hub)
    else
      Debug.error("game", "Failed to create hub station")
      return false
    end

    -- Create an industrial furnace station northeast of the hub for ore processing logistics
    local furnace_station = EntityFactory.create("station", "ore_furnace_station", 9500, 9500)
    if furnace_station then
      world:addEntity(furnace_station)
    else
      Debug.error("game", "Failed to create ore furnace station")
      return false
    end

    -- Create a beacon station to protect the top-left quadrant from enemy spawning
    -- Position it far enough from other stations to avoid weapon disable zone overlap
    local beacon_station = EntityFactory.create("station", "beacon_station", 2000, 2000)
    if beacon_station then
      world:addEntity(beacon_station)
    else
      Debug.error("game", "Failed to create beacon station")
      return false
    end
  else
    hub = nil
  end

  -- Step 7: Create world objects
  updateProgress(0.7, "Creating world objects...")
  if not isMultiplayer or isHost then
    -- Add a massive background planet at the world center
    do
      -- Place the planet at the center of the world (15000, 15000)
      local px = 15000
      local py = 15000
      local planet = EntityFactory.create("world_object", "planet_massive", px, py)
      if planet then
        world:addEntity(planet)
      else
        Debug.warn("game", "Failed to create planet")
      end
    end

    -- Create 8 reward crates at random locations in the sector
    do
      local worldSize = 30000 -- Approximate world size
      local margin = 2000 -- Keep crates away from edges
      local minDistance = 1000 -- Minimum distance between crates

      local cratePositions = {}
      local maxAttempts = 1000 -- Prevent infinite loops

      -- Generate 8 random positions with minimum distance between them
      for i = 1, 8 do
        local validPosition = false
        local attempts = 0

        while not validPosition and attempts < maxAttempts do
          local x = math.random(margin, worldSize - margin)
          local y = math.random(margin, worldSize - margin)

          -- Check if this position is far enough from existing crates
          validPosition = true
          for _, existingPos in ipairs(cratePositions) do
            local dx = x - existingPos.x
            local dy = y - existingPos.y
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance < minDistance then
              validPosition = false
              break
            end
          end

          if validPosition then
            table.insert(cratePositions, {x = x, y = y})
          end

          attempts = attempts + 1
        end

        -- If we couldn't find a valid position after max attempts, use a random one anyway
        if not validPosition then
          local x = math.random(margin, worldSize - margin)
          local y = math.random(margin, worldSize - margin)
          table.insert(cratePositions, {x = x, y = y})
          Debug.warn("game", "Could not find valid position for crate %d, using random position", i)
        end
      end

      for i, pos in ipairs(cratePositions) do
        local crate = EntityFactory.create("world_object", "reward_crate", pos.x, pos.y)
        if crate then
          world:addEntity(crate)
          Debug.info("game", "Created reward crate %d at (%d, %d)", i, pos.x, pos.y)
        else
          Debug.warn("game", "Failed to create reward crate %d", i)
        end
      end
    end
  end

  if isMultiplayer and not isHost and pendingWorldSnapshot then
    queueWorldSnapshot(pendingWorldSnapshot)
  end

  -- Step 8: Create warp gate (DISABLED)
  updateProgress(0.8, "Creating warp gate...")
  -- Warp gate creation disabled for now

  -- Step 9: Spawn the player
  updateProgress(0.9, "Spawning player...")
  local spawnSettings = Config.SPAWN or {}
  local spawn_margin = spawnSettings.STATION_BUFFER or Constants.SPAWNING.STATION_BUFFER

  -- Handle loading from save vs starting new game
  if fromSave and saveSlot then
    -- Load player from save data
    local StateManager = require("src.managers.state_manager")
    local slotName = (type(saveSlot) == "string") and saveSlot or ("slot" .. saveSlot)
    
    -- Use pcall for better error handling
    local success, error = pcall(StateManager.loadGame, slotName, true)
    if not success then
      Debug.error("game", "Save load failed with error: %s", tostring(error))
      -- Show user-friendly error message
      local Notifications = require("src.ui.notifications")
      Notifications.add("Save file corrupted or incompatible", "error")
      return false
    end
    
    if not error then -- StateManager.loadGame returns the loaded state or false
      Debug.error("game", "Failed to load game from %s", slotName)
      local Notifications = require("src.ui.notifications")
      Notifications.add("Save file not found or invalid", "error")
      return false
    end
    
    player = StateManager.getCurrentPlayer()
    if not player then
      Debug.error("game", "Failed to get player from save data")
      local Notifications = require("src.ui.notifications")
      Notifications.add("Save file missing player data", "error")
      return false
    end
  else
    -- Start new game - create player at random spawn location
    local angle = math.random() * math.pi * 2
    -- Spawn outside the station weapons-disable zone
    local weapon_disable_radius = hub and hub:getWeaponDisableRadius() or Constants.STATION.WEAPONS_DISABLE_DURATION * 200
    local spawn_dist = weapon_disable_radius * 1.2 -- Spawn 20% outside the weapon disable zone
    local px = (hub and hub.components and hub.components.position and hub.components.position.x or Constants.SPAWNING.MARGIN) + math.cos(angle) * spawn_dist
    local py = (hub and hub.components and hub.components.position and hub.components.position.y or Constants.SPAWNING.MARGIN) + math.sin(angle) * spawn_dist
    
    -- Check for collision with all stations to ensure we don't spawn inside one
    local attempts = 0
    local maxAttempts = 50
    local spawnValid = false
    
    while not spawnValid and attempts < maxAttempts do
      attempts = attempts + 1
      spawnValid = true
      
      -- Check collision with all stations
      local all_stations = world:get_entities_with_components("station")
      for _, station in ipairs(all_stations) do
        if station and station.components and station.components.position and station.components.collidable then
          local sx, sy = station.components.position.x, station.components.position.y
          local dx = px - sx
          local dy = py - sy
          local distance = math.sqrt(dx * dx + dy * dy)
          
          -- Check if player would spawn inside station collision area
          local stationRadius = 50 -- Default safe radius
          if station.components.collidable.radius then
            stationRadius = station.components.collidable.radius
          elseif station.radius then
            stationRadius = station.radius
          end
          
          -- Add some buffer to ensure we're not touching the station
          local safeDistance = stationRadius + 30
          
          if distance < safeDistance then
            spawnValid = false
            -- Try a new random position
            angle = math.random() * math.pi * 2
            px = (hub and hub.components and hub.components.position and hub.components.position.x or Constants.SPAWNING.MARGIN) + math.cos(angle) * spawn_dist
            py = (hub and hub.components and hub.components.position and hub.components.position.y or Constants.SPAWNING.MARGIN) + math.sin(angle) * spawn_dist
            break
          end
        end
      end
    end
    
    -- If we couldn't find a valid spawn after max attempts, use a fallback position
    if not spawnValid then
      px = Constants.SPAWNING.MARGIN
      py = Constants.SPAWNING.MARGIN
    end
    
    -- Start player with basic combat drone
    player = Player.new(px, py, "starter_frigate_basic")
  end
  if player then
    world:addEntity(player)
    HotbarSystem.populateFromPlayer(player)
    -- Set global player reference for UI systems
    PlayerRef.set(player)
  else
    Debug.error("game", "Failed to create player")
    return false
  end

  camera:setTarget(player)
  if not isMultiplayer or isHost then
    SpawningSystem.init(player, hub, world)
  end
  
  if isMultiplayer and isHost then
    broadcastHostWorldSnapshot()
  end

  collisionSystem = CollisionSystem:new({x = 0, y = 0, width = world.width, height = world.height})
  windfieldManager = collisionSystem and collisionSystem:getWindfield()
  Game.windfield = windfieldManager

  world:setQuadtree(collisionSystem.quadtree)

  if not fromSave then
    -- Clear any existing notifications when starting a new game
    local Notifications = require("src.ui.notifications")
    Notifications.clear()
    
    player:setGC(Constants.PLAYER.STARTING_CREDITS or 10000)
    -- Reset skills to level 1 with 0 XP for new games
    local Skills = require("src.core.skills")
    Skills.reset()
  end

  -- Initialize audio listener to player position for positional SFX
  do
    local pos = player.components and player.components.position
    if pos then
      Sound.setListenerPosition(pos.x, pos.y)
    end
  end
  
  -- Refresh inventory display
  local Inventory = require("src.ui.inventory")
  if Inventory.refresh then Inventory.refresh() end


  Input.init({
    camera = camera,
    player = player,
    world = world,
    getInventoryOpen = function() return UIManager.isOpen("inventory") end,
    setInventoryOpen = function(value) if value then UIManager.open("inventory") else UIManager.close("inventory") end end,
    clickMarkers = clickMarkers,
    hoveredEntity = hoveredEntity,
    hoveredEntityType = hoveredEntityType
  })
  
  -- Initialize UI Manager
  UIManager.init()
  
  QuestLogHUD = QuestLogHUD or require("src.ui.hud.quest_log")
  
  -- Clear any existing event listeners to prevent conflicts
  Events.clear()
  worldSyncHandlersRegistered = false

  -- Re-register network listeners that were cleared above
  if networkManager and networkManager.setupEventListeners then
    networkManager:setupEventListeners()
  end
  
  -- Re-register world sync event handlers after clearing events
  registerWorldSyncEventHandlers()

  -- Listen for when someone joins the host's game
  Events.on("NETWORK_PLAYER_JOINED", function(data)
    if not isMultiplayer and networkManager and networkManager:isHost() then
      Log.info("Someone joined the host game, switching to multiplayer mode")
      isMultiplayer = true
      -- The host is already running, just need to enable multiplayer mode
    end
    
    -- Send world snapshot to newly joined client
    if networkManager and networkManager:isHost() then
      broadcastHostWorldSnapshot(data.peer)
    end
  end)

  -- Re-subscribe experience notification to events after clearing
  local ExperienceNotification = require("src.ui.hud.experience_notification")
  ExperienceNotification.resubscribe()
  
  -- Set up event listeners for automatic sound effects
  Events.on(Events.GAME_EVENTS.PLAYER_DAMAGED, function(data)
    Sound.playSFX("hit")
  end)
  
  Events.on(Events.GAME_EVENTS.ENTITY_DESTROYED, function(data)
    Sound.playSFX("ship_destroyed")
  end)
  
  Events.on(Events.GAME_EVENTS.PLAYER_DIED, function(data)
    Sound.playSFX("player_death")
  end)

  Events.on(Events.GAME_EVENTS.CAN_DOCK, function(data)
    if not data then return end
    local docking = player.components and player.components.docking_status
    if docking then
      docking.can_dock = data.canDock and true or false
      docking.nearby_station = data.station
    end
  end)

  Events.on(Events.GAME_EVENTS.DOCK_REQUESTED, function()
    if tryCollectNearbyRewardCrate(player, world) then
      return
    end
    local docking = player.components and player.components.docking_status
    if not docking or not docking.can_dock then return end
    if docking.docked then
      PlayerSystem.undock(player)
      return
    end
    local target = docking.nearby_station or hub
    if target then
      PlayerSystem.dock(player, target)
    end
  end)
  -- Initialize player-specific event listeners after resetting the event bus
  PlayerSystem.init(world)

  refreshDockingState = function()
    if not player or not world then return end
    local position = player.components and player.components.position
    if not position then return end

    local docking = player.components and player.components.docking_status
    if not docking then return end

    if docking.docked then
      if docking.can_dock or docking.nearby_station then
        Events.emit(Events.GAME_EVENTS.CAN_DOCK, { canDock = false, station = nil })
      end
      return
    end

    local stations = {}
    local worldStations = world.get_entities_with_components and world:get_entities_with_components("station") or {}
    for _, station in ipairs(worldStations) do
      table.insert(stations, station)
    end
    if hub then
      local found = false
      for _, station in ipairs(stations) do
        if station == hub then
          found = true
          break
        end
      end
      if not found then
        table.insert(stations, hub)
      end
    end

    local px, py = position.x, position.y
    local nearestStation = nil
    local nearestDist = math.huge

    for _, station in ipairs(stations) do
      local stationPos = station.components and station.components.position
      if stationPos then
        -- Use weapon disabled radius for docking range to allow docking within the weapons disabled zone
        local radius = station.weaponDisableRadius or (station.radius or 100) * 1.5
        local dist = Util.distance(px, py, stationPos.x, stationPos.y)
        if dist <= radius and dist < nearestDist then
          nearestDist = dist
          nearestStation = station
        end
      end
    end

    local canDockNow = nearestStation ~= nil
    if canDockNow ~= (docking.can_dock or false) or nearestStation ~= docking.nearby_station then
      Events.emit(Events.GAME_EVENTS.CAN_DOCK, { canDock = canDockNow, station = nearestStation })
    end
  end

  refreshDockingState()


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
  
  -- Add event listeners for save/load notifications
  Events.on(Events.GAME_EVENTS.GAME_SAVED, function(data)
    local Notifications = require("src.ui.notifications")
    Notifications.add("Game saved: " .. (data.description or "Unknown"), "action")
  end)
  
  Events.on(Events.GAME_EVENTS.GAME_LOADED, function(data)
    local Notifications = require("src.ui.notifications")
    Notifications.add("Game loaded: " .. (data.loadTime or "Unknown"), "info")
  end)
  
  Events.on(Events.GAME_EVENTS.GAME_SAVE_DELETED, function(data)
    local Notifications = require("src.ui.notifications")
    Notifications.add("Save slot deleted: " .. (data.slotName or "Unknown"), "info")
  end)
  
  -- Initialize quest system with player reference and event listeners
  QuestSystem.init(player)
  
  -- Initialize state manager for save/load functionality
  StateManager.init(player, world)
  
  
  createSystemPipeline()

  -- Step 10: Complete
  updateProgress(1.0, "Complete!")
  if loadingScreen then
    loadingScreen:setComplete()
  end
  
  return true
end

function Game.unload()
  if UIManager and UIManager.reset then
    UIManager.reset()
  end

  Events.clear()
  worldSyncHandlersRegistered = false

  if StateManager and StateManager.reset then
    StateManager.reset()
  end

  if HotbarSystem and HotbarSystem.reset then
    HotbarSystem.reset()
  end

  PlayerRef.set(nil)

  local okRepairPopup, repairPopup = pcall(require, "src.ui.repair_popup")
  if okRepairPopup and repairPopup and repairPopup.hide then
    repairPopup.hide()
  end

  systemPipeline = nil
  systemContext = {}
  ecsManager = nil

  -- Clean up network manager
  if networkManager then
    networkManager:leaveGame()
    networkManager = nil
  end
  isMultiplayer = false
  isHost = false

  Input.init({})

  if world then
    world:setECSWorld(nil)
  end

  world = nil
  Game.world = nil
  camera = nil
  player = nil
  hub = nil
  clickMarkers = {}
  hoveredEntity = nil
  hoveredEntityType = nil
  if windfieldManager and windfieldManager.destroy then
    windfieldManager:destroy()
  end
  windfieldManager = nil
  Game.windfield = nil
  collisionSystem = nil
  refreshDockingState = nil
end

function Game.update(dt)
    Input.update(dt)
    UIManager.update(dt, player)
    StatusBars.update(dt, player, world)
    SkillXpPopup.update(dt)
    local input = Input.getInputState()

    -- Check if game should be paused (escape menu)
    local shouldPause = false
    if UIManager then
        shouldPause = UIManager.isOpen("escape")
    end
    
    if shouldPause then
        -- Only update UI, skip all game logic including camera
        return
    end

    -- Update UI effects systems
    Theme.updateAnimations(dt)
    Theme.updateParticles(dt)
    Theme.updateScreenEffects(dt)
    

    -- Update all systems via the scheduled pipeline
    if not world or not player then
        return
    end
    if not systemPipeline then
        createSystemPipeline()
    end
    if not systemPipeline then
        return
    end

    systemContext.dt = dt
    systemContext.player = player
    systemContext.input = input
    systemContext.world = world
    systemContext.hub = hub
    systemContext.camera = camera
    systemContext.collisionSystem = collisionSystem
    systemContext.windfield = windfieldManager
    if collisionSystem and collisionSystem.getWindfieldContacts then
        systemContext.windfieldContacts = collisionSystem:getWindfieldContacts()
    else
        systemContext.windfieldContacts = nil
    end
    systemContext.refreshDockingState = refreshDockingState
    systemContext.gameState = {}

    systemPipeline:update(systemContext)

    -- Expire click markers so they don't get stuck on screen.
    for i = #clickMarkers, 1, -1 do
        local m = clickMarkers[i]
        m.t = m.t + dt
        if m.t >= m.dur then
            table.remove(clickMarkers, i)
        end
    end

end

function Game.resize(w, h)
    if world then
        world:resize(w, h)
    end
end

function Game.draw()
    local shakeX, shakeY = 0, 0
    local flashAlpha = 0
    local zoomScale = 1.0

    shakeX, shakeY = Theme.getScreenShakeOffset()
    flashAlpha = Theme.getScreenFlashAlpha()
    zoomScale = Theme.getScreenZoomScale()

    -- Apply shake and zoom to camera
    camera:apply(shakeX, shakeY, zoomScale)

    world:drawBackground(camera)
    if DEBUG_DRAW_BOUNDS then world:drawBounds() end

    -- World and gameplay
    RenderSystem.draw(world, camera, player, clickMarkers, hoveredEntity, hoveredEntityType)

    Effects.draw()

    camera:reset()

    -- Draw helpers above game world but below UI
    UI.drawHelpers(player, world, hub, camera)

    -- Blur effect is now handled in main.lua after viewport is finished

    -- Non-modal HUD (reticle, status bars, minimap, hotbar)
    local remotePlayerEntities = NetworkSync.getRemotePlayers()
    local remotePlayerSnapshots = NetworkSync.getRemotePlayerSnapshots()
    UI.drawHUD(player, world, world:get_entities_with_components("ai"), hub, world:get_entities_with_components("wreckage"), {}, camera, remotePlayerEntities, remotePlayerSnapshots)
    
    -- Draw interaction prompts
    InteractionSystem.draw(player, camera)

    -- UI overlay (windows/menus) via UIManager
    QuestLogHUD.draw(player)
    
    -- Handle escape menu with blur effect
    if UIManager.isOpen("escape") then
        -- Apply blur to background only (everything drawn so far)
        if not Game.blurCanvas then
            local w, h = Viewport.getDimensions()
            Game.blurCanvas = love.graphics.newCanvas(w, h)
        end
        
        -- Save current canvas state and render to the blur canvas
        local currentCanvas = love.graphics.getCanvas()
        local okBlur, errBlur = xpcall(function()
            love.graphics.setCanvas({ Game.blurCanvas, stencil = true })
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(Viewport.getCanvas(), 0, 0)
        end, debug.traceback)
        -- Always restore previous canvas
        love.graphics.setCanvas(currentCanvas)
        
        if not okBlur then
            local Log = require("src.core.log")
            if Log and Log.warn then
                Log.warn("UI blur render failed: " .. tostring(errBlur))
            end
        else
            -- Apply blur shader to background
            love.graphics.setShader(Theme.shaders.ui_blur)
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.draw(Game.blurCanvas, 0, 0)
            love.graphics.setShader()
        end
        
        -- Draw escape menu on top of blurred background
        UIManager.draw(player, world, world:get_entities_with_components("ai"), hub, world:get_entities_with_components("wreckage"), {}, {})
    else
        -- Draw UI normally if escape menu is not open
        UIManager.draw(player, world, world:get_entities_with_components("ai"), hub, world:get_entities_with_components("wreckage"), {}, {})
    end

    -- UI particles and flashes (top-most)
    Theme.drawParticles()
    if flashAlpha > 0 then
      Theme.setColor({1, 1, 1, flashAlpha})
      love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end

    Indicators.drawTargetingBorder(world)
end

return Game


