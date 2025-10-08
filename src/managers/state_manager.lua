local Events = require("src.core.events")
local Log = require("src.core.log")
local PortfolioManager = require("src.managers.portfolio")
local PlayerHotbar = require("src.systems.player.hotbar")

local StateManager = {}

-- Configuration
local SAVE_VERSION = "1.0.0"
-- Use the proper Love2D save directory
local SAVE_DIRECTORY = "saves/"
local AUTO_SAVE_INTERVAL = 30 -- seconds
local MAX_SAVE_SLOTS = 10
local AUTO_SAVE_SLOT = "autosave"

-- Internal state
local autoSaveTimer = 0
local currentPlayer = nil
local currentWorld = nil
local saveEnabled = true

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

local function serializeEquipment(player)
  if not player or not player.components then return nil end

  local equipment = player.components.equipment
  if not equipment then return nil end

  local state = { grid = {}, layout = equipment.layout and safeCopy(equipment.layout) or nil }

  if equipment.grid then
    for index, slot in ipairs(equipment.grid) do
      local slotState = {
        slot = slot.slot or index,
        id = slot.id,
        type = slot.type,
        baseType = slot.baseType,
        enabled = slot.enabled or false,
        hotbarSlot = slot.hotbarSlot,
      }

      if slot.type == "turret" and slot.module then
        slotState.turret = {
          baseId = slot.module.baseId,
          fireMode = slot.module.fireMode,
          autoFire = slot.module.autoFire,
          cooldown = slot.module.cooldown,
          heat = slot.module.heat,
          source = slot.module._sourceData and safeCopy(slot.module._sourceData) or nil,
        }
      end

      table.insert(state.grid, slotState)
    end
  end

  if equipment.turrets and #equipment.turrets > 0 then
    state.turrets = {}
    for _, turret in ipairs(equipment.turrets) do
      table.insert(state.turrets, {
        slot = turret.slot,
        id = turret.id,
        enabled = turret.enabled or false,
      })
    end
  end

  return state
end

local function restoreEquipment(player, equipmentState)
  if not player or not equipmentState then return end
  if not player.components or not player.components.equipment then return end

  local equipment = player.components.equipment
  local grid = equipment.grid or {}

  for _, slot in ipairs(grid) do
    slot.id = nil
    slot.module = nil
    slot.enabled = false
    slot.type = slot.baseType or nil
    slot.hotbarSlot = nil
  end

  local Content = require("src.content.content")
  local Util = require("src.core.util")
  local Turret = require("src.systems.turret.core")

  for _, savedSlot in ipairs(equipmentState.grid or {}) do
    local slotIndex = savedSlot.slot and tonumber(savedSlot.slot) or nil
    local slot = slotIndex and grid[slotIndex] or nil
    if slot then
      slot.id = savedSlot.id
      slot.type = savedSlot.type or slot.type or slot.baseType
      slot.baseType = slot.baseType or savedSlot.baseType
      slot.enabled = not not savedSlot.enabled
      slot.hotbarSlot = savedSlot.hotbarSlot

      if savedSlot.id then
        if slot.type == "turret" then
          local source = savedSlot.turret and savedSlot.turret.source and Util.deepCopy(savedSlot.turret.source) or nil
          local turretDef = source or Content.getTurret(savedSlot.id)
          if turretDef then
            local params = Util.deepCopy(turretDef)
            local turretInstance = Turret.new(player, params)
            turretInstance.id = savedSlot.id
            turretInstance.slot = slotIndex
            turretInstance.baseId = (savedSlot.turret and savedSlot.turret.baseId) or params.baseId or params.id or savedSlot.id
            turretInstance._sourceData = source or Util.deepCopy(turretDef)
            if savedSlot.turret then
              if savedSlot.turret.fireMode then turretInstance.fireMode = savedSlot.turret.fireMode end
              turretInstance.autoFire = not not savedSlot.turret.autoFire
              if savedSlot.turret.cooldown then turretInstance.cooldown = savedSlot.turret.cooldown end
              if savedSlot.turret.heat then turretInstance.heat = savedSlot.turret.heat end
            end
            slot.module = turretInstance
          else
            Log.warn("StateManager: Missing turret definition for", savedSlot.id)
          end
        else
          local moduleItem = Content.getItem(savedSlot.id)
          if moduleItem then
            slot.module = moduleItem
          else
            Log.warn("StateManager: Missing module definition for", savedSlot.id)
          end
        end
      end
    end
  end

  if equipmentState.turrets and equipment.turrets then
    equipment.turrets = {}
    for _, saved in ipairs(equipmentState.turrets) do
      table.insert(equipment.turrets, {
        slot = saved.slot,
        id = saved.id,
        enabled = saved.enabled,
      })
    end
  end

  if equipmentState.layout then
    equipment.layout = equipmentState.layout
  end

  if player.updateShieldHP then
    player:updateShieldHP()
  end
  PlayerHotbar.populate(player)
end

-- Get current player
function StateManager.getCurrentPlayer()
  return currentPlayer
end

-- Validate save file structure
function StateManager.validateSaveFile(saveData)
  if not saveData or type(saveData) ~= "table" then
    return false, "Save data is not a valid table"
  end

  -- Check required top-level fields
  local requiredFields = {"version", "player", "metadata", "timestamp"}
  for _, field in ipairs(requiredFields) do
    if not saveData[field] then
      return false, "Missing required field: " .. field
    end
  end

  -- Validate version
  if type(saveData.version) ~= "string" then
    return false, "Version field must be a string"
  end

  -- Validate player data
  if not saveData.player or type(saveData.player) ~= "table" then
    return false, "Player data is missing or invalid"
  end

  -- Validate metadata
  if not saveData.metadata or type(saveData.metadata) ~= "table" then
    return false, "Metadata is missing or invalid"
  end

  -- Check for critical player data
  local player = saveData.player
  if not player or type(player) ~= "table" then
    return false, "Player data is missing or invalid"
  end

  -- Check for essential player fields (the save format uses a flat structure, not components)
  if not player.position or type(player.position) ~= "table" then
    return false, "Player position data is missing"
  end
  
  if not player.position.x or not player.position.y then
    return false, "Player position coordinates are missing"
  end

  -- Validate timestamp
  if type(saveData.timestamp) ~= "number" or saveData.timestamp <= 0 then
    return false, "Timestamp is invalid"
  end

  return true
end

-- Initialize the state manager
function StateManager.init(player, world)
  currentPlayer = player
  currentWorld = world
  autoSaveTimer = 0

  -- Ensure save directory exists
  if not love.filesystem.getInfo(SAVE_DIRECTORY) then
    Log.info("StateManager: Creating save directory at '" .. SAVE_DIRECTORY .. "'")
    local success, msg = love.filesystem.createDirectory(SAVE_DIRECTORY)
    if not success then
        Log.error("StateManager: FAILED to create save directory. Reason: " .. (msg or "unknown"))
    else
        Log.info("StateManager: Save directory created successfully.")
    end
  else
    Log.info("StateManager: Save directory already exists at '" .. SAVE_DIRECTORY .. "'")
  end
  
  Log.debug("State Manager initialized")
end

function StateManager.reset()
  currentPlayer = nil
  currentWorld = nil
  autoSaveTimer = 0
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
        maxShield = currentPlayer.components.health.maxShield or 0,
        energy = currentPlayer.components.health.energy or 0,
        maxEnergy = currentPlayer.components.health.maxEnergy or 0
      } or {hp = 100, maxHp = 100, shield = 0, maxShield = 0, energy = 0, maxEnergy = 0},

      -- Inventory (safe copy)
      cargo = currentPlayer.components and currentPlayer.components.cargo and currentPlayer.components.cargo:serialize() or nil,

      -- Quest progress (safe copy)
      active_quests = safeCopy(currentPlayer.active_quests) or {},
      quest_progress = safeCopy(currentPlayer.quest_progress) or {},
      quest_start_times = safeCopy(currentPlayer.quest_start_times) or {},

      -- Ship configuration
      shipId = currentPlayer.shipId or "starter_frigate_basic",
      equipment = serializeEquipment(currentPlayer),

      -- Status flags
      docked = currentPlayer.docked or false,
      progression = currentPlayer.components and currentPlayer.components.progression and currentPlayer.components.progression:serialize() or nil,
      questLog = currentPlayer.components and currentPlayer.components.questLog and currentPlayer.components.questLog:serialize() or nil,
    },
    
    -- World data (simplified to avoid circular references)
    world = {
      width = currentWorld.width or 15000,
      height = currentWorld.height or 15000,
      discovery = nil -- Fog of war disabled
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
    if playerData.health.energy ~= nil then
      player.components.health.energy = playerData.health.energy
    end
    if playerData.health.maxEnergy ~= nil then
      player.components.health.maxEnergy = playerData.health.maxEnergy
    end
  end

  if player.components and player.components.cargo then
    if playerData.cargo then
      player.components.cargo = require("src.components.cargo").deserialize(playerData.cargo)
    elseif playerData.inventory then
      for id, qty in pairs(playerData.inventory) do
        if type(qty) == "number" then
          player.components.cargo:add(id, qty)
        elseif type(qty) == "table" then
          player.components.cargo:add(id, 1, qty)
        end
      end
    end
  end
  
  -- Restore quest progress
  player.active_quests = playerData.active_quests or {}
  player.quest_progress = playerData.quest_progress or {}
  player.quest_start_times = playerData.quest_start_times or {}

  if playerData.equipment then
    restoreEquipment(player, playerData.equipment)
  end

  -- Restore status flags
  -- Restore portfolio
  if state.portfolio then
    PortfolioManager.init(state.portfolio, { force = true })
  end
  local docking = player.components and player.components.docking_status
  if docking then
    docking.docked = playerData.docked or false
  end
  
  if currentPlayer.components and currentPlayer.components.progression and state.player.progression then
    currentPlayer.components.progression = require("src.components.progression").deserialize(state.player.progression)
  end
  if currentPlayer.components and currentPlayer.components.questLog and state.player.questLog then
    currentPlayer.components.questLog = require("src.components.quest_log").deserialize(state.player.questLog)
  end

  -- Fog of war disabled - no discovery data to restore

  -- TODO: Restore world entities (asteroids, wreckage, etc.)
  -- This would require more complex entity recreation logic
  
  Log.debug("Game state loaded successfully from", state.realTime)
  
  -- Emit load event
  Events.emit(Events.GAME_EVENTS.GAME_LOADED, {
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

  -- Create player entity using the proper Player constructor
  local Player = require("src.entities.player")
  local player = Player.new(0, 0, playerData.shipId or "starter_frigate_basic")
  if not player then
    Log.error("Failed to create player entity")
    return false
  end
  player.level = playerData.level or 1
  player.xp = playerData.xp or 0
  player.gc = playerData.gc or 0
  if player.components and player.components.cargo then
    if playerData.cargo then
      player.components.cargo = require("src.components.cargo").deserialize(playerData.cargo)
    elseif playerData.inventory then
      for id, qty in pairs(playerData.inventory) do
        if type(qty) == "number" then
          player.components.cargo:add(id, qty)
        elseif type(qty) == "table" then
          player.components.cargo:add(id, 1, qty)
        end
      end
    end
  end
  player.active_quests = playerData.active_quests or {}
  player.quest_progress = playerData.quest_progress or {}
  player.quest_start_times = playerData.quest_start_times or {}
  local docking = player.components and player.components.docking_status
  if docking then
    docking.docked = playerData.docked or false
  end

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
      if playerData.health.energy ~= nil then
        player.components.health.energy = playerData.health.energy
      end
      if playerData.health.maxEnergy ~= nil then
        player.components.health.maxEnergy = playerData.health.maxEnergy
      end
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
    Log.debug("Game created from save data successfully")
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

  if not saveData or saveData == "" then
    Log.error("StateManager: Failed to save game because JSON encoding resulted in empty data.")
    return nil
  end
  
  Log.info("StateManager: Attempting to write save file to '" .. filename .. "'")
  
  -- Write to file
  local success, error = love.filesystem.write(filename, saveData)
  
  if success then
    Log.debug("Game saved to slot:", slotName)
    -- Debug: confirm file info after write
    local info = love.filesystem.getInfo(filename)
    if info then
      Log.debug("Save file written:", filename, "size:", info.size, "modtime:", info.modtime)
    else
      Log.warn("Save file write succeeded but getInfo returned nil for", filename)
    end
    
    -- Emit save event
    Events.emit(Events.GAME_EVENTS.GAME_SAVED, {
      slotName = slotName,
      description = state.metadata.description,
      state = state
    })
    
    return state
  else
    Log.error("Failed to save game:", error)
    return nil
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

  -- Validate save file structure
  local valid, error = StateManager.validateSaveFile(state)
  if not valid then
    Log.error("Save file validation failed:", error)
    return false
  end

  -- Ensure content is loaded before creating entities
  local Content = require("src.content.content")
  if not Content.byId.ship or not next(Content.byId.ship) then
    Log.debug("Loading content before creating game from save")
    Content.load()
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
    Log.debug("Game loaded from slot:", slotName)
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
  
  Log.info("StateManager: Checking for save files...")
  
  if #files == 0 then
    Log.info("StateManager: No files found in save directory.")
  end

  for _, file in ipairs(files) do
    if file:match("%.json$") then
      local slotName = file:gsub("%.json$", "")
      local filename = SAVE_DIRECTORY .. file
      
      -- Try to read save metadata
      local saveData, size = love.filesystem.read(filename)
      if saveData then
        Log.info("StateManager: Found file: " .. filename .. " (size: " .. (size or 0) .. "). Validating...")
        local json = require("src.libs.json")
        local success, state = pcall(json.decode, saveData)
        
        if success and state.metadata then
          Log.info("StateManager: -> VALID. Adding '" .. slotName .. "' to list.")
          table.insert(slots, {
            name = slotName,
            description = state.metadata.description,
            timestamp = state.timestamp,
            realTime = state.realTime,
            playerLevel = state.metadata.playerLevel,
            playerCredits = state.metadata.playerCredits,
            playTime = state.metadata.playTime
          })
        else
            Log.warn("StateManager: -> INVALID. Could not parse JSON or find metadata in " .. filename)
        end
      else
        Log.warn("StateManager: Found file, but could not read contents: " .. filename)
      end
    end
  end
  
  Log.info("StateManager: Found " .. #slots .. " valid save slots.")
  
  -- Sort by timestamp (newest first)
  table.sort(slots, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
  
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
    Log.debug("Deleted save slot:", slotName)
    
    Events.emit(Events.GAME_EVENTS.GAME_SAVE_DELETED, {
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
    Log.debug("Saving disabled")
  else
    Log.debug("Saving enabled")
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
