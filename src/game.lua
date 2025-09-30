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
    Log.error("Failed to create hub station")
    return false
  end

  -- Create an industrial furnace station northeast of the hub for ore processing logistics
  local furnace_station = EntityFactory.create("station", "ore_furnace_station", 7200, 7200)
  if furnace_station then
    world:addEntity(furnace_station)
  else
    Log.error("Failed to create ore furnace station")
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
      Log.warn("Failed to create planet")
    end
  end

  -- Step 8: Create warp gate
  updateProgress(0.8, "Creating warp gate...")
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
      Log.error("Save load failed with error:", error)
      -- Show user-friendly error message
      local Notifications = require("src.ui.notifications")
      Notifications.add("Save file corrupted or incompatible", "error")
      return false
    end
    
    if not error then -- StateManager.loadGame returns the loaded state or false
      Log.error("Failed to load game from " .. slotName)
      local Notifications = require("src.ui.notifications")
      Notifications.add("Save file not found or invalid", "error")
      return false
    end
    
    player = StateManager.getCurrentPlayer()
    if not player then
      Log.error("Failed to get player from save data")
      local Notifications = require("src.ui.notifications")
      Notifications.add("Save file missing player data", "error")
      return false
    end
  else
    -- Start new game - create player at random spawn location
    local angle = math.random() * math.pi * 2
    -- Spawn within the station weapons-disable zone
    local spawn_dist = (hub and hub:getWeaponDisableRadius() or Constants.STATION.WEAPONS_DISABLE_DURATION * 200) * 0.5
    local px = (hub and hub.components and hub.components.position and hub.components.position.x or Constants.SPAWNING.MARGIN) + math.cos(angle) * spawn_dist
    local py = (hub and hub.components and hub.components.position and hub.components.position.y or Constants.SPAWNING.MARGIN) + math.sin(angle) * spawn_dist
    -- Start player with basic combat drone
    player = Player.new(px, py, "starter_frigate_basic")
  end
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

  -- Initial docking state check to ensure canDock is properly set
  if hub and player and player.components and player.components.position then
    local playerPos = player.components.position
    local hubPos = hub.components and hub.components.position
    if hubPos then
      local distance = Util.distance(playerPos.x, playerPos.y, hubPos.x, hubPos.y)
      local dockRadius = hub.radius or 100
      player.canDock = distance <= dockRadius
      Log.debug("Initial docking check: distance=", distance, "dockRadius=", dockRadius, "canDock=", player.canDock)
    end
  end


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
  
  -- Enable event debug logging temporarily
  -- Events.setDebug(true) -- Disabled to reduce console spam
  
  -- Step 10: Complete
  updateProgress(1.0, "Complete!")
  if loadingScreen then
    loadingScreen:setComplete()
  end
  
  return true
end

function Game.update(dt)
    Input.update(dt)
    UIManager.update(dt, player)
    StatusBars.update(dt, player)
    SkillXpPopup.update(dt)
    local input = Input.getInputState()

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

    -- Docking proximity check
    if player and hub and hub.components and hub.components.position then
        local playerPos = player.components.position
        local hubPos = hub.components.position
        local distance = Util.distance(playerPos.x, playerPos.y, hubPos.x, hubPos.y)
        
        -- Use the station's base radius for docking.
        local dockRadius = hub.radius or 100 -- Fallback, but should be defined on the station template.
        
        local canDockNow = distance <= dockRadius
        
        -- Check if docking state has changed
        if canDockNow ~= player.canDock then
            player.canDock = canDockNow
            Events.emit(Events.GAME_EVENTS.CAN_DOCK, { canDock = canDockNow })
        end
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
    
    -- Selection box removed (manual combat)

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
