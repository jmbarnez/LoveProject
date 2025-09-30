local Events = {}
local Log = require("src.core.log")

-- Internal event registry
local listeners = {}
local eventQueue = {}
local processingQueue = false

-- Debug options
local DEBUG_EVENTS = false

local function debugLog(...)
  if DEBUG_EVENTS then
    print("[EVENTS]", ...)
  end
end

-- Register a callback for an event
-- Usage: Events.on("player_died", function(data) ... end)
function Events.on(eventName, callback)
  if type(eventName) ~= "string" then
    error("Event name must be a string")
  end
  if type(callback) ~= "function" then
    error("Callback must be a function")
  end
  
  if not listeners[eventName] then
    listeners[eventName] = {}
  end
  
  table.insert(listeners[eventName], callback)
  debugLog("Registered listener for:", eventName)
  
  -- Return unsubscribe function
  return function()
    Events.off(eventName, callback)
  end
end

-- Remove a specific callback for an event
function Events.off(eventName, callback)
  if not listeners[eventName] then return end
  
  for i = #listeners[eventName], 1, -1 do
    if listeners[eventName][i] == callback then
      table.remove(listeners[eventName], i)
      debugLog("Removed listener for:", eventName)
      break
    end
  end
  
  -- Clean up empty listener arrays
  if #listeners[eventName] == 0 then
    listeners[eventName] = nil
  end
end

-- Remove all listeners for an event
function Events.clear(eventName)
  if eventName then
    listeners[eventName] = nil
    debugLog("Cleared all listeners for:", eventName)
  else
    listeners = {}
    debugLog("Cleared all listeners")
  end
end

-- Emit an event immediately (synchronous)
-- Usage: Events.emit("player_died", {player = player, cause = "asteroid"})
function Events.emit(eventName, data)
  if not listeners[eventName] then 
    debugLog("No listeners for:", eventName)
    return 
  end
  
  debugLog("Emitting event:", eventName, data and "(with data)" or "(no data)")
  
  -- Create a copy of listeners to avoid issues if listeners modify the list
  local currentListeners = {}
  for i, listener in ipairs(listeners[eventName]) do
    currentListeners[i] = listener
  end
  
  for _, callback in ipairs(currentListeners) do
    local success, err = pcall(callback, data)
    if not success then
      Log.error("ERROR in event listener for '" .. eventName .. "':", err)
    end
  end
end

-- Queue an event to be processed later (asynchronous)
-- Useful to avoid issues when events are triggered during sensitive operations
function Events.queue(eventName, data)
  table.insert(eventQueue, {name = eventName, data = data})
  debugLog("Queued event:", eventName)
end

-- Process all queued events (call this once per frame)
function Events.processQueue()
  if processingQueue then return end -- Prevent recursion
  
  processingQueue = true
  local queuedEvents = eventQueue
  eventQueue = {}
  
  for _, event in ipairs(queuedEvents) do
    Events.emit(event.name, event.data)
  end
  
  processingQueue = false
end

-- One-time event listener (automatically unregisters after first trigger)
function Events.once(eventName, callback)
  local unsubscribe
  unsubscribe = Events.on(eventName, function(data)
    unsubscribe()
    callback(data)
  end)
  return unsubscribe
end

-- Emit event and wait for all listeners to respond (useful for validation)
-- Returns true if all listeners succeeded
function Events.emitSync(eventName, data)
  if not listeners[eventName] then return true end
  
  debugLog("Sync emitting event:", eventName)
  
  for _, callback in ipairs(listeners[eventName]) do
    local success, result = pcall(callback, data)
    if not success then
      Log.error("ERROR in sync event listener for '" .. eventName .. "':", result)
      return false
    end
    -- If listener returns false, cancel the operation
    if result == false then
      debugLog("Event cancelled by listener:", eventName)
      return false
    end
  end
  
  return true
end

-- Get debug information about current listeners
function Events.getDebugInfo()
  local info = {}
  for eventName, eventListeners in pairs(listeners) do
    info[eventName] = #eventListeners
  end
  return info
end

-- Enable/disable debug logging
function Events.setDebug(enabled)
  DEBUG_EVENTS = enabled
  if enabled then
    debugLog("Debug logging enabled")
  end
end

-- Common game events (for reference - you can emit any string)
Events.GAME_EVENTS = {
  -- Player events
  PLAYER_SPAWNED = "player_spawned",
  PLAYER_DIED = "player_died", 
  PLAYER_DAMAGED = "player_damaged",
  PLAYER_HEALED = "player_healed",
  PLAYER_DOCKED = "player_docked",
  PLAYER_UNDOCKED = "player_undocked",
  PLAYER_LEVEL_UP = "player_level_up",
  
  -- Combat events
  ENTITY_DAMAGED = "entity_damaged",
  ENTITY_DESTROYED = "entity_destroyed", 
  PROJECTILE_HIT = "projectile_hit",
  WEAPON_FIRED = "weapon_fired",
  
  -- Items/Economy
  ITEM_PICKED_UP = "item_picked_up",
  ITEM_USED = "item_used",
  CREDITS_CHANGED = "credits_changed",
  LOOT_DROPPED = "loot_dropped",
  
  -- Mining/Salvaging
  ASTEROID_MINED = "asteroid_mined",
  WRECKAGE_SALVAGED = "wreckage_salvaged",

  -- Skill progression
  SKILL_XP_GAINED = "skill_xp_gained",
  
  -- Quest system
  QUEST_STARTED = "quest_started",
  QUEST_COMPLETED = "quest_completed", 
  QUEST_UPDATED = "quest_updated",
  OBJECTIVE_COMPLETED = "objective_completed",
  
  -- UI events
  INVENTORY_OPENED = "inventory_opened",
  INVENTORY_CLOSED = "inventory_closed",
  SHOP_OPENED = "shop_opened",
  CAN_DOCK = "can_dock",
  CAN_WARP = "can_warp",
  DOCK_REQUESTED = "dock_requested",
  WARP_REQUESTED = "warp_requested",

  -- System events
  GAME_PAUSED = "game_paused",
  GAME_RESUMED = "game_resumed",
  LEVEL_LOADED = "level_loaded",
}

return Events
