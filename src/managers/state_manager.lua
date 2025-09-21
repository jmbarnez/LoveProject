local Events = require("src.core.events")
local Log = require("src.core.log")
local PortfolioManager = require("src.managers.portfolio")

local StateManager = {}

-- Configuration
local SAVE_VERSION = "1.0.0"
local SAVE_DIRECTORY = "saves/"
local AUTO_SAVE_INTERVAL = 30 -- seconds
local MAX_SAVE_SLOTS = 10
local AUTO_SAVE_SLOT = "autosave"

-- Internal state
local autoSaveTimer = 0
local currentPlayer = nil
local currentWorld = nil
local saveEnabled = true

-- Initialize the state manager
function StateManager.init(player, world)
  currentPlayer = player
  currentWorld = world
  
  -- Ensure save directory exists
  if not love.filesystem.getInfo(SAVE_DIRECTORY) then
    love.filesystem.createDirectory(SAVE_DIRECTORY)
  end
  
  Log.info("State Manager initialized")
end

-- Safely copy primitive values, avoiding circular references
local function safeCopy(value, depth)
  depth = depth or 0
  if depth > 10 then return nil end -- Prevent deep recursion
  
  local valueType = type(value)
  if valueType == "table" then
    local copy = {}
    for k, v in pairs(value) do
      -- Skip certain keys that might cause circular references
      if k ~= "parent" and k ~= "world" and k ~= "entity" and k ~= "body" and k ~= "turret" then
        local keyType = type(k)
        local valType = type(v)
        
        -- Only copy primitive keys and values, or shallow table values
        if (keyType == "string" or keyType == "number") and 
           (valType == "string" or valType == "number" or valType == "boolean" or 
            (valType == "table" and depth < 3)) then
          copy[k] = safeCopy(v, depth + 1)
        end
      end
    end
    return copy
  elseif valueType == "string" or valueType == "number" or valueType == "boolean" then
    return value
  else
    return nil -- Skip functions, userdata, etc.
  end
end

-- Get current game state for saving
local function getGameState()
  if not currentPlayer or not currentWorld then
    Log.warn("Cannot get game state - player or world not initialized")
    return nil
  end
  
  local state = {
    version = SAVE_VERSION,
    timestamp = os.time(),
    realTime = os.date("%Y-%m-%d %H:%M:%S"),
    
    -- Player data (safely copied to avoid circular references)
    player = {
      position = currentPlayer.components and currentPlayer.components.position and {
        x = currentPlayer.components.position.x,
        y = currentPlayer.components.position.y,
        angle = currentPlayer.components.position.angle or 0
      } or {x = 0, y = 0, angle = 0},
      
      -- Core stats
      level = currentPlayer.level or 1,
      xp = currentPlayer.xp or 0,
      gc = currentPlayer.gc or 0,
      
      -- Health/shields
      health = currentPlayer.components and currentPlayer.components.health and {
        hp = currentPlayer.components.health.hp or 100,
        maxHp = currentPlayer.components.health.maxHP or 100,
        shield = currentPlayer.components.health.shield or 0,
        maxShield = currentPlayer.components.health.maxShield or 0
      } or {hp = 100, maxHp = 100, shield = 0, maxShield = 0},
      
      -- Inventory (safe copy)
      inventory = safeCopy(currentPlayer.inventory) or {},
      
      -- Quest progress (safe copy)
      active_quests = safeCopy(currentPlayer.active_quests) or {},
      quest_progress = safeCopy(currentPlayer.quest_progress) or {},
      quest_start_times = safeCopy(currentPlayer.quest_start_times) or {},
      
      -- Ship configuration
      shipId = currentPlayer.shipId or "starter_frigate_basic",
      
      -- Status flags
      docked = currentPlayer.docked or false
    },
    
    -- World data (simplified to avoid circular references)
    world = {
      width = currentWorld.width or 15000,
      height = currentWorld.height or 15000
    },
    
    -- Game progression
    gameStats = {
      playTime = love.timer.getTime(), -- Total session time
      enemiesKilled = currentPlayer.enemiesKilled or 0,
      creditsEarned = currentPlayer.creditsEarned or 0
    },
    
    -- Player's crypto portfolio
    portfolio = PortfolioManager.serialize()
  }
  
  -- Skip world entity saving for now to avoid circular references
  -- This can be added back later with more careful entity serialization
  
  return state
end

-- Apply loaded state to game
local function applyGameState(state, player, world)
  if not state or not player or not world then
    Log.error("Invalid state or game objects for loading")
    return false
  end
  
  -- Validate save version
  if state.version ~= SAVE_VERSION then
    Log.warn("Save file version mismatch. Expected", SAVE_VERSION, "got", state.version)
    -- Could add migration logic here in the future
  end
  
  local playerData = state.player
  if not playerData then
    Log.error("No player data in save file")
    return false
  end
  
  -- Restore player position
  if playerData.position then
    player.components.position.x = playerData.position.x
    player.components.position.y = playerData.position.y
    player.components.position.angle = playerData.position.angle or 0
    
    -- Update physics body if it exists
    if player.components.physics and player.components.physics.body then
      player.components.physics.body.x = playerData.position.x
      player.components.physics.body.y = playerData.position.y
      player.components.physics.body.angle = playerData.position.angle or 0
    end
  end
  
  -- Restore core stats
  player.level = playerData.level or 1
  player.xp = playerData.xp or 0
  player.gc = playerData.gc or 0
  
  -- Restore health
  if playerData.health and player.components.health then
    player.components.health.hp = playerData.health.hp
    player.components.health.maxHP = playerData.health.maxHp
    player.components.health.shield = playerData.health.shield
    player.components.health.maxShield = playerData.health.maxShield
  end
  
  -- Restore inventory
  player.inventory = playerData.inventory or {}
  
  -- Restore quest progress
  player.active_quests = playerData.active_quests or {}
  player.quest_progress = playerData.quest_progress or {}
  player.quest_start_times = playerData.quest_start_times or {}
  
  -- Restore status flags
  -- Restore portfolio
  if state.portfolio then
    PortfolioManager.init(state.portfolio)
  end
  player.docked = playerData.docked or false
  
  -- TODO: Restore world entities (asteroids, wreckage, etc.)
  -- This would require more complex entity recreation logic
  
  Log.info("Game state loaded successfully from", state.realTime)
  
  -- Emit load event
  Events.emit("game_loaded", {
    state = state,
    player = player,
    loadTime = state.realTime
  })
  
  return true
end

-- Create game objects from save state
local function createGameFromSave(state)
  if not state then
    Log.error("No state provided for game creation")
    return false
  end

  -- Create player from save data
  local playerData = state.player
  if not playerData then
    Log.error("No player data in save file")
    return false
  end

  -- Create basic player entity
  local EntityFactory = require("src.templates.entity_factory")
  local player = EntityFactory.createPlayer(playerData.shipId or "starter_frigate_basic", 0, 0)
  if not player then
    Log.error("Failed to create player entity")
    return false
  end
  player.level = playerData.level or 1
  player.xp = playerData.xp or 0
  player.gc = playerData.gc or 0
  player.inventory = playerData.inventory or {}
  player.active_quests = playerData.active_quests or {}
  player.quest_progress = playerData.quest_progress or {}
  player.quest_start_times = playerData.quest_start_times or {}
  player.docked = playerData.docked or false

  -- Set position
  if playerData.position then
    player.components.position.x = playerData.position.x
    player.components.position.y = playerData.position.y
    player.components.position.angle = playerData.position.angle or 0
  end

  -- Set health
  if playerData.health then
    if player.components.health then
      player.components.health.hp = playerData.health.hp
      player.components.health.maxHP = playerData.health.maxHp
      player.components.health.shield = playerData.health.shield
      player.components.health.maxShield = playerData.health.maxShield
    end
  end

  -- Create world
  local World = require("src.core.world")
  local worldData = state.world or {}
  local world = World.new(worldData.width or 15000, worldData.height or 15000)

  -- Initialize StateManager with the created player and world
  StateManager.init(player, world)

  -- Apply remaining state data
  local success = applyGameState(state, player, world)

  if success then
    Log.info("Game created from save data successfully")
    return true
  else
    Log.error("Failed to create game from save data")
    return false
  end
end

-- Save game to slot
function StateManager.saveGame(slotName, description)
  if not saveEnabled then
    Log.warn("Saving is currently disabled")
    return false
  end
  
  slotName = slotName or "quicksave"
  
  local state = getGameState()
  if not state then
    Log.error("Failed to get game state for saving")
    return false
  end
  
  -- Add save metadata
  state.metadata = {
    slotName = slotName,
    description = description or ("Save " .. os.date("%Y-%m-%d %H:%M:%S")),
    playerLevel = state.player.level,
    playerCredits = state.player.gc,
    playTime = state.gameStats.playTime
  }
  
  local filename = SAVE_DIRECTORY .. slotName .. ".json"
  
  -- Serialize to JSON
  local json = require("src.libs.json")
  local saveData = json.encode(state)
  
  -- Write to file
  local success, error = love.filesystem.write(filename, saveData)
  
  if success then
    Log.info("Game saved to slot:", slotName)
    
    -- Emit save event
    Events.emit("game_saved", {
      slotName = slotName,
      description = state.metadata.description,
      state = state
    })
    
    return true
  else
    Log.error("Failed to save game:", error)
    return false
  end
end

-- Load game from slot
function StateManager.loadGame(slotName, createNewGame)
  slotName = slotName or "quicksave"

  local filename = SAVE_DIRECTORY .. slotName .. ".json"

  -- Check if save file exists
  if not love.filesystem.getInfo(filename) then
    Log.warn("Save file not found:", filename)
    return false
  end

  -- Read save file
  local saveData, error = love.filesystem.read(filename)
  if not saveData then
    Log.error("Failed to read save file:", error)
    return false
  end

  -- Parse JSON
  local json = require("src.libs.json")
  local success, state = pcall(json.decode, saveData)

  if not success then
    Log.error("Failed to parse save file:", state)
    return false
  end

  -- If no current player/world exists, we need to create them from save data
  local loaded
  if not currentPlayer or not currentWorld or createNewGame then
    loaded = createGameFromSave(state)
  else
    -- Apply state to current game
    loaded = applyGameState(state, currentPlayer, currentWorld)
  end

  if loaded then
    Log.info("Game loaded from slot:", slotName)
    return true
  else
    Log.error("Failed to apply loaded state")
    return false
  end
end

-- Get list of available save slots
function StateManager.getSaveSlots()
  local slots = {}
  local files = love.filesystem.getDirectoryItems(SAVE_DIRECTORY)
  
  for _, file in ipairs(files) do
    if file:match("%.json$") then
      local slotName = file:gsub("%.json$", "")
      local filename = SAVE_DIRECTORY .. file
      
      -- Try to read save metadata
      local saveData = love.filesystem.read(filename)
      if saveData then
        local json = require("src.libs.json")
        local success, state = pcall(json.decode, saveData)
        
        if success and state.metadata then
          table.insert(slots, {
            name = slotName,
            description = state.metadata.description,
            timestamp = state.timestamp,
            realTime = state.realTime,
            playerLevel = state.metadata.playerLevel,
            playerCredits = state.metadata.playerCredits,
            playTime = state.metadata.playTime
          })
        end
      end
    end
  end
  
  -- Sort by timestamp (newest first)
  table.sort(slots, function(a, b) return a.timestamp > b.timestamp end)
  
  return slots
end

-- Delete save slot
function StateManager.deleteSave(slotName)
  local filename = SAVE_DIRECTORY .. slotName .. ".json"
  
  if not love.filesystem.getInfo(filename) then
    Log.warn("Save file not found:", filename)
    return false
  end
  
  local success = love.filesystem.remove(filename)
  if success then
    Log.info("Deleted save slot:", slotName)
    
    Events.emit("game_save_deleted", {
      slotName = slotName
    })
    
    return true
  else
    Log.error("Failed to delete save slot:", slotName)
    return false
  end
end

-- Auto-save functionality
function StateManager.update(dt)
  if not saveEnabled then return end
  
  autoSaveTimer = autoSaveTimer + dt
  
  if autoSaveTimer >= AUTO_SAVE_INTERVAL then
    autoSaveTimer = 0
    
    -- Only auto-save if player is not in combat or other critical situations
    if StateManager.canAutoSave() then
      StateManager.saveGame(AUTO_SAVE_SLOT, "Auto-save " .. os.date("%H:%M:%S"))
    end
  end
end

-- Check if auto-save is safe to perform
function StateManager.canAutoSave()
  if not currentPlayer then return false end
  
  -- Don't auto-save if player is dead
  if currentPlayer.dead then return false end
  
  -- Don't auto-save if player is in combat (has aggro)
  if currentPlayer.aggro then return false end
  
  -- Don't auto-save if player health is critically low (less than 10%)
  if currentPlayer.components.health then
    local healthPercent = currentPlayer.components.health.hp / currentPlayer.components.health.maxHP
    if healthPercent < 0.1 then return false end
  end
  
  -- Auto-save is safe
  return true
end

-- Manual quick save/load shortcuts
function StateManager.quickSave()
  return StateManager.saveGame("quicksave", "Quick save " .. os.date("%H:%M:%S"))
end

function StateManager.quickLoad()
  return StateManager.loadGame("quicksave")
end

-- Enable/disable saving (useful for critical sections)
function StateManager.setSaveEnabled(enabled)
  saveEnabled = enabled
  if not enabled then
    Log.info("Saving disabled")
  else
    Log.info("Saving enabled")
  end
end

-- Get save statistics
function StateManager.getStats()
  local slots = StateManager.getSaveSlots()
  return {
    totalSaves = #slots,
    lastSave = slots and slots.realTime or "Never",
    autoSaveEnabled = saveEnabled,
    nextAutoSave = AUTO_SAVE_INTERVAL - autoSaveTimer
  }
end

return StateManager