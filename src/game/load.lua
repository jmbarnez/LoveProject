
local State = require("src.game.state")
local Pipeline = require("src.game.pipeline")
local WorldBuilder = require("src.game.load.world_builder")
local PlayerSpawn = require("src.game.load.player_spawn")
local EventSetup = require("src.game.load.event_setup")

local Content = require("src.content.content")
local HotbarSystem = require("src.systems.hotbar")
local NodeMarket = require("src.systems.node_market")
local PortfolioManager = require("src.managers.portfolio")
local NetworkSession = require("src.core.network.session")
local Constants = require("src.core.constants")
local Log = require("src.core.log")
local Sound = require("src.core.sound")
local PlayerRef = require("src.core.player_ref")
local SpawningSystem = require("src.systems.spawning")
local CollisionSystem = require("src.systems.collision.core")
local Input = require("src.core.input")
local UIManager = require("src.core.ui_manager")
local QuestLogHUD = require("src.ui.hud.quest_log")
local Events = require("src.core.events")
local QuestSystem = require("src.systems.quest_system")
local StateManager = require("src.managers.state_manager")

local Load = {}

function Load.load(Game, fromSave, saveSlot, loadingScreen, multiplayer, isHost)
  Log.setInfoEnabled(true)

  local world
  local camera
  local player
  local hub
  local clickMarkers = {}
  local hoveredEntity = nil
  local hoveredEntityType = nil
  local collisionSystem
  local windfieldManager
  local refreshDockingState
  local ecsManager
  local networkManager

  local pendingConnection = nil
  if multiplayer and not isHost then
    local pending = _G.PENDING_MULTIPLAYER_CONNECTION
    if pending and pending.connecting then
      pendingConnection = { address = pending.address, port = pending.port, username = pending.username }
    else
      return false, "No pending connection details found."
    end
  end

  local sessionOk, sessionError = NetworkSession.load({
    multiplayer = multiplayer or false,
    isHost = isHost or false,
    pendingConnection = pendingConnection,
  })
  if not sessionOk then
    return false, sessionError
  end

  networkManager = NetworkSession.getManager()
  if multiplayer and not isHost then
    _G.PENDING_MULTIPLAYER_CONNECTION = nil
  end

  local function updateProgress(step, description)
    if loadingScreen then
      loadingScreen:setProgress(step, description)
    end
  end

  updateProgress(0.1, "Loading content...")
  Content.load()

  updateProgress(0.2, "Initializing systems...")
  HotbarSystem.load()
  NodeMarket.init()
  PortfolioManager.init()

  updateProgress(0.25, "Initializing network...")
  networkManager = NetworkSession.getManager()

  updateProgress(0.3, "Setting up input...")
  if love and love.mouse and love.mouse.setVisible then love.mouse.setVisible(false) end

  updateProgress(0.4, "Loading sounds...")
  local soundConfig = require("content.sounds.sounds")
  for event, config in pairs(soundConfig.events) do
    if config.type == "sfx" then
      Sound.attachSFX(event, config.sound, {volume = config.volume, pitch = config.pitch})
    elseif config.type == "music" then
      Sound.attachMusic(event, config.sound, {fadeIn = config.fadeIn})
    end
  end

  local builtWorld, builtCamera, builtHub, builtEcsManager, worldError = WorldBuilder.build(Game, updateProgress)
  if not builtWorld then
    return false, worldError or "Failed to create world"
  end
  world = builtWorld
  camera = builtCamera
  hub = builtHub
  ecsManager = builtEcsManager

  updateProgress(0.8, "Creating warp gate...")

  updateProgress(0.9, "Spawning player...")
  local spawnedPlayer, playerError = PlayerSpawn.spawn(fromSave, saveSlot, world, hub)
  if not spawnedPlayer then
    return false, playerError
  end
  player = spawnedPlayer

  if player then
    world:addEntity(player)
    HotbarSystem.populateFromPlayer(player)
    PlayerRef.set(player)
    NetworkSession.setContext({ player = player })
  else
    return false, "Failed to create player"
  end

  camera:setTarget(player)
  if not NetworkSession.isMultiplayer() or NetworkSession.isHost() then
    SpawningSystem.init(player, hub, world)
  end

  collisionSystem = CollisionSystem:new({x = 0, y = 0, width = world.width, height = world.height})
  windfieldManager = collisionSystem and collisionSystem:getWindfield()
  Game.windfield = windfieldManager
  world:setQuadtree(collisionSystem.quadtree)

  if not fromSave then
    local Notifications = require("src.ui.notifications")
    Notifications.clear()

    player:setGC(Constants.PLAYER.STARTING_CREDITS or 10000)
    local Skills = require("src.core.skills")
    Skills.reset()
  end

  local pos = player.components and player.components.position
  if pos then
    Sound.setListenerPosition(pos.x, pos.y)
  end

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

  UIManager.init()
  QuestLogHUD = QuestLogHUD or require("src.ui.hud.quest_log")

  Events.clear()
  NetworkSession.resetEventHandlers()
  NetworkSession.setupEventHandlers()

  local ExperienceNotification = require("src.ui.hud.experience_notification")
  ExperienceNotification.resubscribe()

  refreshDockingState = EventSetup.register(player, world, hub)

  QuestSystem.init(player)
  StateManager.init(player, world)

  State.systemPipeline = Pipeline.build()

  updateProgress(1.0, "Complete!")
  if loadingScreen then
    loadingScreen:setComplete()
  end

  State.world = world
  State.camera = camera
  State.player = player
  State.hub = hub
  State.clickMarkers = clickMarkers
  State.hoveredEntity = hoveredEntity
  State.hoveredEntityType = hoveredEntityType
  State.collisionSystem = collisionSystem
  State.windfieldManager = windfieldManager
  State.refreshDockingState = refreshDockingState
  State.ecsManager = ecsManager
  State.networkManager = networkManager
  State.systemContext = {}

  Game.world = world
  Game.windfield = windfieldManager

  return true
end

return Load
