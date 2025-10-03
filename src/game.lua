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

local SpaceStationSystem = require("src.systems.hub")
local MiningSystem = require("src.systems.mining")
local Pickups = require("src.systems.pickups")
local DestructionSystem = require("src.systems.destruction")
local InteractionSystem = require("src.systems.interaction")
local EntityFactory = require("src.templates.entity_factory")
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
local refreshDockingState

-- Make world accessible
Game.world = world


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


--[[
    Game.load

    Boots the playable world, reporting progress back to the optional loading
    screen overlay. The staged structure (content -> systems -> world ->
    entities) is intentionally linear so future systems have an obvious place
    to hook into without breaking save/load behaviour.
]]
function Game.load(fromSave, saveSlot, loadingScreen)
  Log.setInfoEnabled(true)
  
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
  camera = Camera.new()

  -- Step 6: Create stations
  updateProgress(0.6, "Creating stations...")
  hub = EntityFactory.create("station", "hub_station", 5000, 5000)
  if hub then
    world:addEntity(hub)
  else
    Debug.error("game", "Failed to create hub station")
    return false
  end

  -- Create an industrial furnace station northeast of the hub for ore processing logistics
  local furnace_station = EntityFactory.create("station", "ore_furnace_station", 7200, 7200)
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

  -- Step 7: Create world objects
  updateProgress(0.7, "Creating world objects...")
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
  
  -- Create 8 reward crates scattered around the world
  do
    local cratePositions = {
      {x = 3000, y = 3000},   -- Top-left quadrant
      {x = 8000, y = 2000},   -- Top-center
      {x = 12000, y = 3000},  -- Top-right quadrant
      {x = 2000, y = 8000},   -- Left-center
      {x = 10000, y = 8000},  -- Right-center
      {x = 3000, y = 12000},  -- Bottom-left quadrant
      {x = 8000, y = 13000},  -- Bottom-center
      {x = 12000, y = 12000}, -- Bottom-right quadrant
    }
    
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
  SpawningSystem.init(player, hub, world)
  PlayerSystem.init(world)
  collisionSystem = CollisionSystem:new({x = 0, y = 0, width = world.width, height = world.height})

  world:setQuadtree(collisionSystem.quadtree)

  if not fromSave then
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
    getBountyOpen = function() return UIManager.isOpen("bounty") end,
    setBountyOpen = function(value) if value then UIManager.open("bounty") else UIManager.close("bounty") end end,
    clickMarkers = clickMarkers,
    bounty = bounty,
    hoveredEntity = hoveredEntity,
    hoveredEntityType = hoveredEntityType
  })
  
  -- Initialize UI Manager
  UIManager.init()
  
  QuestLogHUD = QuestLogHUD or require("src.ui.hud.quest_log")
  
  -- Clear any existing event listeners to prevent conflicts
  Events.clear()
  
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
    player.canDock = data.canDock and true or false
    player.nearbyStation = data.station
  end)

  Events.on(Events.GAME_EVENTS.DOCK_REQUESTED, function()
    if tryCollectNearbyRewardCrate(player, world) then
      return
    end
    if not player.canDock then return end
    if player.docked then
      player:undock()
      return
    end
    local target = player.nearbyStation or hub
    if target then
      player:dock(target)
    end
  end)

  refreshDockingState = function()
    if not player or not world then return end
    local position = player.components and player.components.position
    if not position then return end

    if player.docked then
      if player.canDock or player.nearbyStation then
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
        local radius = station.radius or 100
        local dist = Util.distance(px, py, stationPos.x, stationPos.y)
        if dist <= radius and dist < nearestDist then
          nearestDist = dist
          nearestStation = station
        end
      end
    end

    local canDockNow = nearestStation ~= nil
    if canDockNow ~= (player.canDock or false) or nearestStation ~= player.nearbyStation then
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
  Events.on("game_saved", function(data)
    local Notifications = require("src.ui.notifications")
    Notifications.add("Game saved: " .. (data.description or "Unknown"), "action")
  end)
  
  Events.on("game_loaded", function(data)
    local Notifications = require("src.ui.notifications")
    Notifications.add("Game loaded: " .. (data.loadTime or "Unknown"), "info")
  end)
  
  Events.on("game_save_deleted", function(data)
    local Notifications = require("src.ui.notifications")
    Notifications.add("Save slot deleted: " .. (data.slotName or "Unknown"), "info")
  end)
  
  -- Initialize quest system with player reference and event listeners
  QuestSystem.init(player)
  
  -- Initialize state manager for save/load functionality
  StateManager.init(player, world)
  
  
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

  if StateManager and StateManager.reset then
    StateManager.reset()
  end

  if HotbarSystem and HotbarSystem.reset then
    HotbarSystem.reset()
  end

  PlayerRef.set(nil)

  Input.init({})

  world = nil
  Game.world = nil
  camera = nil
  player = nil
  hub = nil
  clickMarkers = {}
  bounty = { uncollected = 0, entries = {} }
  hoveredEntity = nil
  hoveredEntityType = nil
  collisionSystem = nil
  refreshDockingState = nil
end

function Game.update(dt)
    Input.update(dt)
    UIManager.update(dt, player)
    StatusBars.update(dt, player, world)
    SkillXpPopup.update(dt)
    local input = Input.getInputState()

    -- Check if game should be paused (escape menu or other modal UIs)
    local shouldPause = false
    if UIManager then
        shouldPause = UIManager.isOpen("escape") or UIManager.isModalActive()
    end
    
    if shouldPause then
        -- Only update UI, skip all game logic including camera
        return
    end

    -- Update UI effects systems
    local Theme = require("src.core.theme")
    Theme.updateAnimations(dt)
    Theme.updateParticles(dt)
    Theme.updateScreenEffects(dt)

    -- Update all systems
    PlayerSystem.update(dt, player, input, world, hub)
    do
        -- Update audio listener to follow the player for attenuation/pan
        local pos = player and player.components and player.components.position
        if pos then
        Sound.setListenerPosition(pos.x, pos.y)
        end
    end
    AISystem.update(dt, world, spawn_projectile)
    -- Update physics and collisions first so any damage/death flags set by collisions
    -- are visible to the destruction system in the same frame.
    PhysicsSystem.update(dt, world:getEntities())
    -- Update projectile lifecycle (timed life and max range expiration)
    local ProjectileLifecycle = require("src.systems.projectile_lifecycle")
    ProjectileLifecycle.update(dt, world)
    BoundarySystem.update(world)
    collisionSystem:update(world, dt)
    -- Process deaths: spawn effects, wreckage, loot before cleanup
    local gameState = { bounty = bounty }
    DestructionSystem.update(world, gameState, hub)
    SpawningSystem.update(dt, player, hub, world)
    RepairSystem.update(dt, player, world)
    SpaceStationSystem.update(dt, hub)
    -- Mining progression (per-cycle, per-asteroid)
    MiningSystem.update(dt, world, player)
    -- Magnetic item pickup system
    Pickups.update(dt, world, player)
    -- Interaction system
    InteractionSystem.update(dt, player, world)

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

    -- Docking proximity check (supports multiple stations)
    if refreshDockingState then
        refreshDockingState()
    end

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

end

function Game.resize(w, h)
    if world then
        world:resize(w, h)
    end
end

function Game.draw()
    local Theme = require("src.core.theme")
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

    -- *** This is the crucial fix ***
    -- The hub is now passed to the RenderSystem so it can be drawn.
    -- World and gameplay
    RenderSystem.draw(world, camera, player, clickMarkers, hoveredEntity, hoveredEntityType)

    Effects.draw()

    camera:reset()

    -- Draw helpers above game world but below UI
    UI.drawHelpers(player, world, hub, camera)

    -- Apply blur if escape menu is open
    if UIManager.isOpen("escape") then
        if not Game.blurCanvas then
            local w, h = Viewport.getDimensions()
            Game.blurCanvas = love.graphics.newCanvas(w, h)
        end
        love.graphics.setCanvas({Game.blurCanvas, stencil = true})
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(Viewport.getCanvas(), 0, 0)
        love.graphics.setCanvas(Viewport.getCanvas())
        love.graphics.setShader(Theme.shaders.ui_blur)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.draw(Game.blurCanvas, 0, 0)
        love.graphics.setShader()
    end

    -- Non-modal HUD (reticle, status bars, minimap, hotbar)
    UI.drawHUD(player, world, world:get_entities_with_components("ai"), hub, world:get_entities_with_components("wreckage"), {}, camera, {})
    
    -- Draw interaction prompts
    InteractionSystem.draw(player)

    -- UI overlay (windows/menus) via UIManager
    QuestLogHUD.draw(player)
    UIManager.draw(player, world, world:get_entities_with_components("ai"), hub, world:get_entities_with_components("wreckage"), {}, bounty)

    -- UI particles and flashes (top-most)
    Theme.drawParticles()
    if flashAlpha > 0 then
      Theme.setColor({1, 1, 1, flashAlpha})
      love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end

    Indicators.drawTargetingBorder(world)
end

return Game
