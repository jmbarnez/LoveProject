--[[
    UIManager

    Centralises all UI component lifecycles (open/close, layering, forwarding
    input). Rather than letting each panel talk to Love2D directly, we keep the
    routing logic here so features like z-ordering, modal focus, and shared
    styling remain consistent across the project.
]]

local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Registry = require("src.ui.core.registry")
local PanelRegistry = require("src.ui.panels.init")
-- SciFiCursor removed - using simple reticle

-- UI components
local Inventory = require("src.ui.inventory")
local DockedUI = require("src.ui.docked")
local EscapeMenu = require("src.ui.escape_menu")
local Notifications = require("src.ui.notifications")
local SkillsPanel = require("src.ui.skills")
local Map = require("src.ui.map")
local SettingsPanel = require("src.ui.settings_panel")
local Warp = require("src.ui.warp")
local DebugPanel = require("src.ui.debug_panel")
local Ship = require("src.ui.ship")
local RewardWheelPanel = require("src.ui.reward_wheel_panel")
local RepairPopup = require("src.ui.repair_popup")
local BeaconRepairPopup = require("src.ui.beacon_repair_popup")

-- Normalize potentially-broken modules (protect against empty/incomplete inventory module)
if type(Inventory) ~= "table" then
  Inventory = { visible = false }
  function Inventory.draw() end
  function Inventory.mousepressed() return false end
  function Inventory.mousereleased() return false end
  function Inventory.update() end
  function Inventory.keypressed() return false end
  function Inventory.textinput() return false end
  function Inventory.mousemoved() return false end
end

local Log = require("src.core.log")

local UIManager = {}
local panelRecords = {}
local componentFallbacks = {}

local DEFAULT_Z_INDEX = {
  inventory = 10,
  ship = 15,
  skills = 30,
  docked = 40,
  map = 50,
  warp = 60,
  escape = 100,
  settings = 110,
  repairPopup = 112,
  beaconRepair = 113,
  rewardWheel = 115,
  debug = 120,
}

-- Create warp instance
local warpInstance = Warp:new()
PanelRegistry.register({ id = "warp", module = warpInstance, defaultZ = DEFAULT_Z_INDEX.warp, useSelf = true })

-- Central UI state
UIManager.state = {
  inventory = { open = false, zIndex = DEFAULT_Z_INDEX.inventory },
  ship = { open = false, zIndex = DEFAULT_Z_INDEX.ship },
  skills = { open = false, zIndex = DEFAULT_Z_INDEX.skills },
  docked = { open = false, zIndex = DEFAULT_Z_INDEX.docked },
  map = { open = false, zIndex = DEFAULT_Z_INDEX.map },
  warp = { open = false, zIndex = DEFAULT_Z_INDEX.warp },
  escape = { open = false, zIndex = DEFAULT_Z_INDEX.escape, showingSaveSlots = false }, -- Escape menu should be on top
  settings = { open = false, zIndex = DEFAULT_Z_INDEX.settings }, -- Settings panel should be on top of escape
  repairPopup = { open = false, zIndex = DEFAULT_Z_INDEX.repairPopup },
  beaconRepair = { open = false, zIndex = DEFAULT_Z_INDEX.beaconRepair },
  rewardWheel = { open = false, zIndex = DEFAULT_Z_INDEX.rewardWheel }, -- Reward wheel panel
  debug = { open = false, zIndex = DEFAULT_Z_INDEX.debug } -- Debug panel should be on top of everything
}
UIManager.topZ = DEFAULT_Z_INDEX.debug

-- UI priorities for proper layering
UIManager.layerOrder = {
  "inventory",
  "ship",
  "skills",
  "docked",
  "map",
  "warp",
  "escape",
  "settings",
  "repairPopup",
  "beaconRepair",
  "rewardWheel",
  "debug"
}

local function bootstrapDynamicPanels()
  local existingOrder = {}
  for _, id in ipairs(UIManager.layerOrder) do
    existingOrder[id] = true
  end

  for _, record in ipairs(PanelRegistry.list()) do
    panelRecords[record.id] = record

    DEFAULT_Z_INDEX[record.id] = DEFAULT_Z_INDEX[record.id] or record.defaultZ or 0

    if not UIManager.state[record.id] then
      local isVisible = false
      if record.isVisible then
        local ok, visible = pcall(record.isVisible, record.module)
        if ok then
          isVisible = visible and true or false
        end
      elseif record.module and record.module.visible ~= nil then
        isVisible = record.module.visible == true
      end

      UIManager.state[record.id] = { open = isVisible, zIndex = DEFAULT_Z_INDEX[record.id] }
      if record.id == "escape" then
        UIManager.state[record.id].showingSaveSlots = false
      end
    end

    if not componentFallbacks[record.id] then
      local fallback = {
        module = record.module,
        useSelf = record.useSelf,
      }

      if record.onClose then
        fallback.onClose = function()
          record.onClose(record.module)
        end
      end

      if record.onOpen then
        fallback.onOpen = function()
          record.onOpen(record.module)
        end
      end

      componentFallbacks[record.id] = fallback
    else
      if not componentFallbacks[record.id].module then
        componentFallbacks[record.id].module = record.module
      end

      if not componentFallbacks[record.id].onClose and record.onClose then
        componentFallbacks[record.id].onClose = function()
          record.onClose(record.module)
        end
      end

      if not componentFallbacks[record.id].onOpen and record.onOpen then
        componentFallbacks[record.id].onOpen = function()
          record.onOpen(record.module)
        end
      end
    end

    if not existingOrder[record.id] then
      table.insert(UIManager.layerOrder, record.id)
      existingOrder[record.id] = true
    end
  end

  table.sort(UIManager.layerOrder, function(a, b)
    local za = DEFAULT_Z_INDEX[a] or 0
    local zb = DEFAULT_Z_INDEX[b] or 0
    if za == zb then
      return a < b
    end
    return za < zb
  end)
end

local function isTextInputFocused()
  for id, record in pairs(panelRecords) do
    local state = UIManager.state[id]
    if state and state.open and record.captureTextInput then
      local ok, captured = pcall(record.captureTextInput, record.module)
      if ok and captured then
        return true
      end
    end
  end

  return false
end

function UIManager.isTextInputActive()
  return isTextInputFocused()
end

-- Modal state - when true, blocks input to lower layers
UIManager.modalActive = false
UIManager.modalComponent = nil

local unpack = table.unpack or unpack

--[[
    componentFallbacks

    Provides default handlers for built-in UI panels. If a module fails to
    load, these fallbacks keep the manager stable so the rest of the UI can
    continue functioning (particularly useful in development when a panel might
    be mid-refactor).
]]
componentFallbacks = {
  inventory = {
    module = Inventory,
    onClose = function()
      UIManager.close("inventory")
    end,
  },
  ship = {
    module = Ship,
    onClose = function()
      UIManager.close("ship")
    end,
    useSelf = true,
  },
  docked = {
    module = DockedUI,
    onClose = function()
      local player = DockedUI.player
      if player then
        local PlayerSystem = require("src.systems.player")
        PlayerSystem.undock(player)
      else
        UIManager.close("docked")
      end
    end,
  },
  skills = {
    module = SkillsPanel,
    onClose = function()
      UIManager.close("skills")
    end,
  },
  map = { module = Map },
  warp = { module = warpInstance, useSelf = true },
  escape = {
    module = EscapeMenu,
    onClose = function()
      UIManager.close("escape")
    end,
  },
  settings = { module = SettingsPanel },
  rewardWheel = { module = RewardWheelPanel },
  beaconRepair = { module = BeaconRepairPopup },
  debug = { module = DebugPanel },
}

local EMPTY_ARGS = {}

bootstrapDynamicPanels()

for component, defaultZ in pairs(DEFAULT_Z_INDEX) do
  if defaultZ > UIManager.topZ then
    UIManager.topZ = defaultZ
  end
end

--[[
    callComponentMethod

    Looks up a UI component and executes the requested method, preferring the
    version registered at runtime via Registry but falling back to the static
    definitions above. This indirection is the heart of the dependency
    injection used by the UI layer.
]]
local function callComponentMethod(componentId, methodName, registeredArgs, fallbackArgs)
  local argsForRegistered = registeredArgs or EMPTY_ARGS
  local argsForFallback = fallbackArgs or argsForRegistered

  local registered = Registry.get(componentId)
  if registered then
    local fn = registered[methodName]
    if type(fn) == "function" then
      -- Try calling as plain function first (most registered closures expect this).
      -- If that errors (some components expect the registered table as first arg),
      -- fall back to calling with the registered table as 'self'. Use pcall to
      -- avoid crashing the UI loop.
      local ok, r1, r2, r3 = pcall(function() return fn(unpack(argsForRegistered)) end)
      if ok then
        return r1, r2, r3, "registered"
      end
      -- Fallback: attempt method-style call
      ok, r1, r2, r3 = pcall(function() return fn(registered, unpack(argsForRegistered)) end)
      if ok then
        return r1, r2, r3, "registered"
      end
      -- Both attempts failed; continue to fallback handlers
    end
  end

  local fallback = componentFallbacks[componentId]
  if not fallback then
    return false
  end

  local target = fallback.module
  if not target then
    return false
  end

  local fn = target[methodName]
  if type(fn) ~= "function" then
    return false
  end

  if fallback.useSelf then
    local r1, r2, r3 = fn(target, unpack(argsForFallback))
    return r1, r2, r3, "fallback"
  end

  local r1, r2, r3 = fn(unpack(argsForFallback))
  return r1, r2, r3, "fallback"
end


-- Initialize UI Manager
function UIManager.init()
  bootstrapDynamicPanels()
  -- Initialize all UI components
  if Inventory.init then Inventory.init() end
  if DockedUI.init then DockedUI.init() end
  if EscapeMenu.init then EscapeMenu.init() end
  if SkillsPanel.init then SkillsPanel.init() end
  if warpInstance.init then warpInstance:init() end
  if DebugPanel.init then DebugPanel.init() end
  if RewardWheelPanel.init then RewardWheelPanel.init() end
  if Ship.init then Ship.init() end
  if Map.init then Map.init() end
  -- Register components in the UI registry once
  if not UIManager._registryInitialized then
    Registry.register({
      id = "inventory",
      isVisible = function() return UIManager.state.inventory.open end,
      getZ = function() return (UIManager.state.inventory and UIManager.state.inventory.zIndex) or 0 end,
      getRect = function() return Inventory and Inventory.getRect and Inventory.getRect() or nil end,
    })
    Registry.register({
      id = "ship",
      isVisible = function()
        return UIManager.state.ship.open
      end,
      getZ = function() return (UIManager.state.ship and UIManager.state.ship.zIndex) or 0 end,
      keypressed = function(key, scancode, isrepeat, player)
        return Ship and Ship.keypressed and Ship.keypressed(key, scancode, isrepeat, player)
      end,
      getRect = function()
        local win = Ship.window
        if win then
          return { x = win.x, y = win.y, w = win.width, h = win.height }
        end
        return nil
      end,
    })
    Registry.register({
      id = "docked",
      isVisible = function() return UIManager.state.docked.open end,
      getZ = function() return (UIManager.state.docked and UIManager.state.docked.zIndex) or 0 end,
      getRect = function()
        local sw, sh = Viewport.getDimensions()
        return { x = 0, y = 0, w = sw, h = sh }
      end,
    })
    Registry.register({
      id = "skills",
      isVisible = function() return UIManager.state.skills.open end,
      getZ = function() return (UIManager.state.skills and UIManager.state.skills.zIndex) or 0 end,
      getRect = function()
        local win = SkillsPanel and SkillsPanel.window
        if win then return { x = win.x, y = win.y, w = win.width, h = win.height } end
        return nil
      end,
    })
    Registry.register({
      id = "map",
      isVisible = function() return UIManager.state.map.open end,
      getZ = function() return (UIManager.state.map and UIManager.state.map.zIndex) or 0 end,
      getRect = function()
        local win = Map and Map.window
        if win then return { x = win.x, y = win.y, w = win.width, h = win.height } end
        return nil
      end,
    })
    Registry.register({
      id = "warp",
      isVisible = function() return UIManager.state.warp.open end,
      getZ = function() return (UIManager.state.warp and UIManager.state.warp.zIndex) or 0 end,
      getRect = function() return nil end,
    })
    Registry.register({
      id = "escape",
      isVisible = function() return UIManager.state.escape.open end,
      getZ = function() return (UIManager.state.escape and UIManager.state.escape.zIndex) or 0 end,
      getRect = function()
        local win = EscapeMenu and EscapeMenu.window
        if win then return { x = win.x, y = win.y, w = win.width, h = win.height } end
        return nil
      end,
    })
    Registry.register({
      id = "settings",
      isVisible = function()
        return (UIManager.state.settings and UIManager.state.settings.open) or false
      end,
      getZ = function() return (UIManager.state.settings and UIManager.state.settings.zIndex) or 0 end,
      getRect = function()
        local SettingsPanel = require("src.ui.settings_panel")
        local win = SettingsPanel and SettingsPanel.window
        if win then return { x = win.x, y = win.y, w = win.width, h = win.height } end
        return nil
      end,
    })
    Registry.register({
      id = "rewardWheel",
      isVisible = function()
        return (UIManager.state.rewardWheel and UIManager.state.rewardWheel.open) or false
      end,
      getZ = function() return (UIManager.state.rewardWheel and UIManager.state.rewardWheel.zIndex) or 0 end,
      getRect = function()
        local RewardWheelPanel = require("src.ui.reward_wheel_panel")
        local win = RewardWheelPanel and RewardWheelPanel.window
        if win then return { x = win.x, y = win.y, w = win.width, h = win.height } end
        return nil
      end,
    })
    Registry.register({
      id = "debug",
      isVisible = function() return UIManager.state.debug.open end,
      getZ = function() return (UIManager.state.debug and UIManager.state.debug.zIndex) or 0 end,
      getRect = function()
        local win = DebugPanel and DebugPanel.window
        if win then return { x = win.x, y = win.y, w = win.width, h = win.height } end
        return nil
      end,
    })
    UIManager._registryInitialized = true
  end

  for id, record in pairs(panelRecords) do
    if not Registry.get(id) then
      Registry.register({
        id = id,
        isVisible = function()
          return UIManager.state[id] and UIManager.state[id].open or false
        end,
        getZ = function()
          return (UIManager.state[id] and UIManager.state[id].zIndex) or (DEFAULT_Z_INDEX[id] or 0)
        end,
        getRect = function()
          if record.getRect then
            local ok, rect = pcall(record.getRect, record.module)
            if ok then
              return rect
            end
          end

          local module = record.module
          if not module then
            return nil
          end

          local getter = module.getRect
          if type(getter) ~= "function" then
            return nil
          end

          local ok, rect
          if record.useSelf then
            ok, rect = pcall(getter, module)
          else
            ok, rect = pcall(getter)
          end

          if ok then
            return rect
          end

          return nil
        end,
      })
    end
  end
end

function UIManager.resize(w, h)
  if Inventory.init then Inventory.init() end
  -- No explicit resize on equipment; rect computed each draw
  if DockedUI.init then DockedUI.init() end
  if EscapeMenu.init then EscapeMenu.init() end
  if SkillsPanel.init then SkillsPanel.init() end
  if Theme and Theme.loadFonts then Theme.loadFonts() end
end

-- Update UI Manager state
function UIManager.update(dt, player)
  -- Sync with legacy UI state variables
  UIManager.state.inventory.open = Inventory.visible or false
  UIManager.state.ship.open = Ship.visible or false
  UIManager.state.docked.open = DockedUI.isVisible()
  UIManager.state.escape.open = EscapeMenu.visible or false
  UIManager.state.escape.showingSaveSlots = EscapeMenu.showSaveSlots or false
  UIManager.state.skills.open = SkillsPanel.visible or false
  UIManager.state.map.open = Map.isVisible()
  UIManager.state.warp.open = warpInstance.visible or false
  UIManager.state.settings.open = SettingsPanel.visible or false
  UIManager.state.rewardWheel.open = RewardWheelPanel.visible or false
  UIManager.state.beaconRepair.open = BeaconRepairPopup.visible or false
  UIManager.state.debug.open = DebugPanel.isVisible()
  
  -- Update modal state - block camera movement when ANY UI is open
  UIManager.modalActive = UIManager.state.escape.open or UIManager.state.warp.open or UIManager.state.ship.open or SettingsPanel.visible or
                         UIManager.state.inventory.open or UIManager.state.docked.open or 
                         UIManager.state.skills.open or UIManager.state.map.open or UIManager.state.rewardWheel.open or UIManager.state.beaconRepair.open or UIManager.state.debug.open
  if SettingsPanel.visible then
    UIManager.modalComponent = "settings"
  elseif UIManager.state.escape.open and UIManager.state.escape.showingSaveSlots then
    UIManager.modalComponent = "escape_save_slots"
  elseif UIManager.state.escape.open then
    UIManager.modalComponent = "escape"
  elseif UIManager.state.ship.open then
    UIManager.modalComponent = "ship"
  elseif UIManager.state.warp.open then
    UIManager.modalComponent = "warp"
  elseif UIManager.state.beaconRepair.open then
    UIManager.modalComponent = "beaconRepair"
  else
    UIManager.modalComponent = nil
  end

  -- Update individual components
  if Ship.update then Ship.update(dt) end
  if Notifications.update then Notifications.update(dt) end
  if SkillsPanel.update then SkillsPanel.update(dt) end
  if Inventory.update then Inventory.update(dt) end
  if DockedUI.update then DockedUI.update(dt) end
  if EscapeMenu.update then EscapeMenu.update(dt) end
  if Map.update then Map.update(dt, player) end

  -- Update cursor animations
  local UICursor = require("src.ui.hud.cursor")
  if UICursor.update then UICursor.update(dt) end
  if warpInstance.update then warpInstance:update(dt) end
  if RewardWheelPanel.update then RewardWheelPanel.update(dt) end
  if RepairPopup.update then RepairPopup.update(dt) end
  if BeaconRepairPopup.update then BeaconRepairPopup.update(dt) end
  if DebugPanel.update then DebugPanel.update(dt) end
  
  -- Update HUD notifications
  local ExperienceNotification = require("src.ui.hud.experience_notification")
  if ExperienceNotification.update then ExperienceNotification.update(dt) end
end

-- Returns true if the mouse is currently over any visible UI component
function UIManager.isMouseOverUI()
  local Viewport = require("src.core.viewport")
  local mx, my = Viewport.getMousePosition()
  -- Registry-driven hit testing for windows/panels
  for _, comp in ipairs(Registry.visibleSortedDescending()) do
    local r = comp.getRect and comp.getRect()
    if r and mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
      return true
    end
    -- Fullscreen components like docked should always count as UI
    if comp.id == "docked" then return true end
    if comp.id == "escape" and UIManager.state.escape.showingSaveSlots then return true end
  end

  -- Hotbar
  local Hotbar = require("src.ui.hud.hotbar")


  return false
end

-- Draw all UI components in proper order
function UIManager.draw(player, world, enemies, hub, wreckage, lootDrops)

  -- Keep a reference for input routing needing player context
  UIManager._player = player
  -- Baseline font to avoid leakage from components/tooltips
  local Theme = require("src.core.theme")
  local oldFont = love.graphics.getFont()
  if Theme and Theme.fonts and Theme.fonts.normal then
    love.graphics.setFont(Theme.fonts.normal)
  end
  -- Draw components via registry (lowest to highest z-index), draw escape last
  local sortedLayers = {}
  for _, comp in ipairs(Registry.visibleSortedAscending()) do
    if comp.id ~= "escape" and comp.id ~= "settings" and comp.id ~= "debug" and comp.id ~= "escape_save_slots" then
      table.insert(sortedLayers, { name = comp.id, zIndex = (comp.getZ and comp.getZ()) or 0 })
    end
  end

  -- Draw each component
  for _, layer in ipairs(sortedLayers) do
    local component = layer.name

    -- Get the registered component
    local registeredComponent = Registry.get(component)

    -- Handle registered components dynamically
    if registeredComponent and registeredComponent.draw then
      registeredComponent:draw(UIManager._player)
    else
      -- Fallback to hardcoded component drawing
      if component == "inventory" then
        Inventory.draw()
      elseif component == "docked" then
        DockedUI.draw(player)
    elseif component == "ship" then
      local shipUI = Ship.ensure()
      local window = shipUI and shipUI.window
      if window then
        window.visible = Ship.visible
          window:draw()
          if Ship.visible and shipUI.drawDropdownOptions then
            shipUI:drawDropdownOptions()
          end
      end
      elseif component == "skills" then
        SkillsPanel.draw()
      elseif component == "map" then
        local asteroids = world and world:get_entities_with_components("mineable") or {}
        local wrecks = world and world:get_entities_with_components("wreckage") or {}
        local stations = {}

        -- Collect all stations from world
        if world then
          local world_stations = world:get_entities_with_components("station") or {}
          for _, station in ipairs(world_stations) do
            table.insert(stations, station)
          end
        end

        -- Add hub if provided separately
        if hub then
          table.insert(stations, hub)
        end

        Map.draw(player, world, enemies, asteroids, wrecks, stations, lootDrops)
      elseif component == "warp" then
        warpInstance:draw()
      elseif component == "beaconRepair" then
        if BeaconRepairPopup.window then
          BeaconRepairPopup.window.visible = BeaconRepairPopup.visible
          BeaconRepairPopup.window:draw()
        end
      elseif component == "rewardWheel" then
        if RewardWheelPanel.window then
          RewardWheelPanel.window.visible = RewardWheelPanel.visible
          RewardWheelPanel.window:draw()
        end
      end
    end
  end

  -- Draw escape menu first
  if UIManager.state.escape.open then
    EscapeMenu.draw()
  end
  
  -- Draw registered floating components (like save panel) on top of escape menu
  for _, comp in ipairs(Registry.visibleSortedAscending()) do
    if comp.id == "save_load_panel" and comp.draw then
      comp:draw()
    end
  end
  
  -- Draw save slots on top of escape menu if active (legacy support)
  if UIManager.state.escape.open and UIManager.state.escape.showingSaveSlots then
    local comp = Registry.get("escape_save_slots")
    if comp and comp.draw then comp.draw() end
  end
  
  if SettingsPanel.visible then
    SettingsPanel.draw()
  end
  if DebugPanel.isVisible() then
    DebugPanel.draw()
  end
  
  -- Draw tooltips for the topmost active window only
  local topComponent = nil
  local highestZIndex = 0
  for _, layer in ipairs(sortedLayers) do
    if layer.zIndex > highestZIndex then
      highestZIndex = layer.zIndex
      topComponent = layer.name
    end
  end

  -- Note: Tooltip drawing is now handled by individual UI components

  Notifications.draw()

  -- Draw tooltips on top of everything (highest priority)
  local TooltipManager = require("src.ui.tooltip_manager")
  TooltipManager.draw()

  -- Draw UI cursor when in game mode (always visible over gameplay UI)
  local UICursor = require("src.ui.hud.cursor")
  UICursor.setVisible(true)
  UICursor.applySettings()
  UICursor.draw()

  -- Restore prior font to prevent persistent size changes across frames
  if oldFont then love.graphics.setFont(oldFont) end
end


-- Toggle UI component visibility
function UIManager.toggle(component)
  -- Determine current open state robustly (consult underlying component where possible)
  local function componentIsOpen(comp)
    if comp == "ship" then
      local Ship = require("src.ui.ship")
      return Ship and Ship.visible or false
    end
    if UIManager.state[comp] then
      return UIManager.state[comp].open
    end
    return false
  end

  if component == "ship" then
    Log.info("UIManager.toggle: ship.open = " .. tostring(componentIsOpen("ship")))
  end

  if UIManager.state[component] then
    local wasOpen = componentIsOpen(component)
    if wasOpen then
      UIManager.close(component)
    else
      UIManager.open(component)
    end
    return not wasOpen
  end
  return false
end

-- Open UI component
function UIManager.open(component)
  Log.info("UIManager.open called for component: " .. component)
  if UIManager.state[component] then
    UIManager.topZ = UIManager.topZ + 1
    UIManager.state[component].zIndex = UIManager.topZ
    UIManager.state[component].open = true
    
    -- Sync with legacy UI systems
    if component == "inventory" then
      Inventory.visible = true
    elseif component == "ship" then
      Ship.visible = true
      Ship.show()
    elseif component == "docked" then
      DockedUI.visible = true
    elseif component == "escape" then
      EscapeMenu.show()
      -- Reset save slots state when opening escape menu
      UIManager.state.escape.showingSaveSlots = false
    elseif component == "skills" then
      SkillsPanel.visible = true
    elseif component == "map" then
      Map.show()
    elseif component == "warp" then
      warpInstance:show()
    end

    -- Handle special cases
    if component == "docked" then
      UIManager.closeAll({"docked", "escape"}) -- Close other modals
    elseif component == "escape" then
      UIManager.closeAll({"docked", "escape"}) -- Close other modals
    end

    local fallback = componentFallbacks[component]
    if fallback and fallback.onOpen then
      fallback.onOpen()
    end
  end
end

-- Close UI component
function UIManager.close(component)
  Log.info("UIManager.close called for component: " .. component)
  if UIManager.state[component] then
    UIManager.state[component].open = false
    
    -- Sync with legacy UI systems
    if component == "inventory" then
      Inventory.visible = false
      if Inventory.clearSearchFocus then Inventory.clearSearchFocus() end
      -- Clear any active tooltips when inventory closes
      local TooltipManager = require("src.ui.tooltip_manager")
      TooltipManager.clearTooltip()
    elseif component == "ship" then
      Ship.visible = false
      Ship.hide()
    elseif component == "docked" then
      DockedUI.visible = false
      if DockedUI.hide then DockedUI.hide() end
    elseif component == "escape" then
      EscapeMenu.hide()
      -- Also reset save slots state when closing escape menu
      if UIManager.state.escape.showingSaveSlots then
        UIManager.state.escape.showingSaveSlots = false
      end
    elseif component == "skills" then
      SkillsPanel.visible = false
    elseif component == "map" then
      Map.hide()
    elseif component == "warp" then
      warpInstance:hide()
    end

    local fallback = componentFallbacks[component]
    if fallback and fallback.onClose then
      fallback.onClose()
    end
  end
end

-- Close all UI components except specified ones
function UIManager.closeAll(except)
  except = except or {}
  local exceptSet = {}
  for _, comp in ipairs(except) do
    exceptSet[comp] = true
  end

  for component, _ in pairs(UIManager.state) do
    if not exceptSet[component] then
      UIManager.close(component)
    end
  end
end

function UIManager.reset()
  UIManager.closeAll()
  UIManager.modalActive = false
  UIManager.modalComponent = nil
  UIManager.topZ = DEFAULT_Z_INDEX.debug
  for component, defaultZ in pairs(DEFAULT_Z_INDEX) do
    if UIManager.state[component] then
      UIManager.state[component].zIndex = defaultZ
      if UIManager.state[component].open then
        UIManager.state[component].open = false
      end
    end
  end
  if UIManager.state.escape then
    UIManager.state.escape.showingSaveSlots = false
  end
end

-- Check if a UI component is open
function UIManager.isOpen(component)
  return UIManager.state[component] and UIManager.state[component].open or false
end

-- Check if any modal UI is open
function UIManager.isModalActive()
  return UIManager.modalActive
end

-- Get the active modal component
function UIManager.getModalComponent()
  return UIManager.modalComponent
end

-- Handle mouse input for UI components
function UIManager.mousepressed(x, y, button)
  -- Build list of visible components from registry (topmost first)
  local openLayers = {}
  for _, comp in ipairs(Registry.visibleSortedDescending()) do
    table.insert(openLayers, { name = comp.id, z = (comp.getZ and comp.getZ()) or 0, getRect = comp.getRect })
  end

  -- Helper to get a component rect for hit-testing
  local function getComponentRect(name)
    for _, layer in ipairs(openLayers) do
      if layer.name == name and layer.getRect then
        return layer.getRect()
      end
    end
    if name == "inventory" and Inventory.getRect then
      return Inventory.getRect()
    end
    if name == "docked" then
      local Viewport = require("src.core.viewport")
      local sw, sh = Viewport.getDimensions()
      return { x = 0, y = 0, w = sw, h = sh }
    end
    return nil
  end

  -- Click-to-front behavior (Windows-like):
  -- If clicking inside the inventory window, always bring it to front even if a fullscreen docked UI exists.
  local invRect = getComponentRect("inventory")
  local raised = false
  if invRect and x >= invRect.x and x <= invRect.x + invRect.w and y >= invRect.y and y <= invRect.y + invRect.h then
    UIManager.topZ = UIManager.topZ + 1
    UIManager.state["inventory"].zIndex = UIManager.topZ
    raised = true
  end
  if not raised then
    -- Otherwise, raise the topmost component under the cursor
    for _, layer in ipairs(openLayers) do
      local r = getComponentRect(layer.name)
      if r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
        if UIManager.state[layer.name] then
          UIManager.topZ = UIManager.topZ + 1
          UIManager.state[layer.name].zIndex = UIManager.topZ
        end
        break
      end
    end
  end

  -- Re-sort after raising
  for _, layer in ipairs(openLayers) do
    layer.z = (UIManager.state[layer.name] and UIManager.state[layer.name].zIndex) or 0
  end
  table.sort(openLayers, function(a, b) return (a.z or 0) > (b.z or 0) end)

  -- Route input to components from top to bottom
  for _, layer in ipairs(openLayers) do
    local component = layer.name
    local registeredComponent = Registry.get(component)
    local handled, shouldClose, _, source = callComponentMethod(
      component,
      "mousepressed",
      { x, y, button, UIManager._player },
      { x, y, button, UIManager._player }
    )

    if source == "fallback" and shouldClose then
      local fallback = componentFallbacks[component]
      if fallback and fallback.onClose then
        fallback.onClose()
      end
    end

    if handled then
      -- Track the component that captured the mouse so we can ensure
      -- mousereleased/mousemoved are routed to it even if z-order changes during drag.
      UIManager._capturedComponent = component
      UIManager._capturedRegistered = registeredComponent
      -- Capture direct handler functions for best fidelity (survives registry changes)
      local handlers = {}
      if registeredComponent then
        handlers.mousemoved = registeredComponent.mousemoved
        handlers.mousereleased = registeredComponent.mousereleased
      else
        local fb = componentFallbacks[component]
        if fb and fb.module then
          handlers.mousemoved = fb.module.mousemoved
          handlers.mousereleased = fb.module.mousereleased
        end
      end
      UIManager._capturedHandlers = handlers
      -- If a floating registered component handled the click, consume it
      -- and do not allow further propagation so underlying UI doesn't
      -- receive the same click (prevents leakage past modal windows).
      return true
    end
  end

  return false
end

-- Handle mouse release for UI components
function UIManager.mousereleased(x, y, button)
  -- Route mouse release to visible registered components first (topmost first)
  -- Give explicit priority to the save/load floating panel to ensure
  -- its release handler runs (fixes stuck drag on that panel).
  local saveComp = Registry.get("save_load_panel")
  if saveComp and saveComp.mousereleased then
    local handled, shouldClose = callComponentMethod("save_load_panel", "mousereleased", { x, y, button, UIManager._player }, { x, y, button, UIManager._player })
    UIManager._capturedComponent = nil
    UIManager._capturedRegistered = nil
    UIManager._capturedHandlers = nil
    if shouldClose and componentFallbacks["save_load_panel"] and componentFallbacks["save_load_panel"].onClose then
      componentFallbacks["save_load_panel"].onClose()
    end
    if handled then
      return true
    end
    -- Fallback: ensure the underlying window receives the release (fix stuck drag)
    local ok, EscapeMenu = pcall(require, "src.ui.escape_menu")
    if ok and EscapeMenu and EscapeMenu.saveLoadPanel and EscapeMenu.saveLoadPanel.window then
      local w = EscapeMenu.saveLoadPanel.window
      if w and w.mousereleased and w:mousereleased(x, y, button) then
        return true
      end
    end
  end

  -- If a component captured the mouse on press, send release to it first
  if UIManager._capturedComponent then
    local id = UIManager._capturedComponent
    -- Prefer routing through callComponentMethod so registered vs fallback
    -- calling conventions are handled centrally.
    local handled, shouldClose = callComponentMethod(id, "mousereleased", { x, y, button, UIManager._player }, { x, y, button, UIManager._player })
    UIManager._capturedComponent = nil
    UIManager._capturedRegistered = nil
    UIManager._capturedHandlers = nil
    if shouldClose and componentFallbacks[id] and componentFallbacks[id].onClose then
      componentFallbacks[id].onClose()
    end
    if handled then
      return true
    end
  end

  for _, comp in ipairs(Registry.visibleSortedDescending()) do
    local id = comp.id
    if comp.mousereleased then
      local handled, shouldClose = callComponentMethod(id, "mousereleased", { x, y, button, UIManager._player }, { x, y, button, UIManager._player })
      if shouldClose and componentFallbacks[id] and componentFallbacks[id].onClose then
        componentFallbacks[id].onClose()
      end
      if handled then
        return true
      end
    end
  end

  -- Fallback: route to legacy layer-order components (for modules not registered)
  for _, component in ipairs(UIManager.layerOrder) do
    if UIManager.state[component].open then
      callComponentMethod(
        component,
        "mousereleased",
        { x, y, button, UIManager._player },
        { x, y, button, UIManager._player }
      )
    end
  end

  -- Also notify SettingsPanel and DebugPanel if present
  if SettingsPanel.visible and SettingsPanel.mousereleased then
    if SettingsPanel.mousereleased(x, y, button) then return true end
  end
  if DebugPanel.isVisible() and DebugPanel.mousereleased then
    if DebugPanel.mousereleased(x, y, button) then return true end
  end

  return false
end

function UIManager.mousemoved(x, y, dx, dy)
  -- Build list of visible components from registry (topmost first)
  -- If a component captured the mouse on press, route movement directly to it
  if UIManager._capturedComponent then
    local id = UIManager._capturedComponent
    local reg = UIManager._capturedRegistered or Registry.get(id)
    if reg and reg.mousemoved then
      local ok, handled = pcall(function() return reg.mousemoved(x, y, dx, dy) end)
      if ok and handled then
        return true
      end
    end
    -- fallthrough to normal routing if direct handler didn't handle it
  end
  local openLayers = {}
  for _, comp in ipairs(Registry.visibleSortedDescending()) do
    table.insert(openLayers, { name = comp.id, z = (comp.getZ and comp.getZ()) or 0 })
  end

  -- Route input to components from top to bottom
  for _, layer in ipairs(openLayers) do
    local component = layer.name
    local handled = false

    -- Get the registered component
    local registeredComponent = Registry.get(component)

    -- Handle registered components dynamically
    local handled = callComponentMethod(
      component,
      "mousemoved",
      { x, y, dx, dy },
      { x, y, dx, dy }
    )

    if handled then
      return true
    end
  end

  return false
end

function UIManager.wheelmoved(x, y, dx, dy)
  -- Handle case where dy might be nil
  if dy == nil then
    return false
  end

  if SettingsPanel.visible and SettingsPanel.wheelmoved then
    local mx, my = love.mouse.getPosition()
    if SettingsPanel.wheelmoved(mx, my, dx, dy) then return true end
  end
  if Ship.visible and Ship.wheelmoved then
    if Ship.wheelmoved(x, y, dx, dy) then return true end
  end
  local versionLogModule = Registry.get("version_log") or UIManager.versionLog
  if not versionLogModule then
    local ok, module = pcall(require, "src.ui.version_log")
    if ok then
      UIManager.versionLog = module
      versionLogModule = module
    end
  end
  if versionLogModule and versionLogModule.visible and versionLogModule.wheelmoved then
    local mx, my = love.mouse.getPosition()
    if versionLogModule.wheelmoved(mx, my, dx, dy) then return true end
  end
  
  -- Route wheel to visible UI components (topmost first)
  do
    local mx, my = love.mouse.getPosition()
    for _, comp in ipairs(Registry.visibleSortedDescending()) do
      local id = comp.id
      -- Special case: map expects (mouseX, wheelDeltaY)
      if id == "map" then
        local handled = callComponentMethod("map", "wheelmoved", { mx, dy }, { mx, dy })
        if handled then return true end
      else
        -- Generic convention: (mx, my, dx, dy)
        local handled = callComponentMethod(id, "wheelmoved", { mx, my, dx, dy }, { mx, my, dx, dy })
        if handled then return true end
      end
    end
  end
  -- Save slots UI doesn't need wheel handling, but we need to consume the event if it's active
  if UIManager.state.escape.open and UIManager.state.escape.showingSaveSlots then
    return true
  end
  -- If escape menu is open, consume the wheel to block gameplay scrolling
  if UIManager.state.escape.open then
    return true
  end
  return false
end

-- Handle keyboard input for UI components
function UIManager.keypressed(key, scancode, isrepeat)
  local textInputFocused = isTextInputFocused()

  -- Check for global hotkeys first
  if key == "escape" then
    -- Skip escape handling - it's now handled by input.lua
    return false
  end

  -- Let the action map handle configured hotkeys (toggles etc.) so bindings in Settings take precedence
  local ActionMap = require("src.core.action_map")
  local ok, handled
  local context = {
    key = key,
    player = UIManager._player,
    UIManager = UIManager,
    Events = require("src.core.events"),
    notifications = Notifications,
    util = require("src.core.util")
  }
  ok, handled = pcall(function()
    return ActionMap.dispatch(key, context)
  end)
  if ok and handled then
    return true
  end
  
  -- Route to active components
  for _, component in ipairs(UIManager.layerOrder) do
    if UIManager.state[component].open then
      local handled = false

      -- Get the registered component
      local registeredComponent = Registry.get(component)

      -- Handle registered components dynamically
      if registeredComponent and registeredComponent.keypressed then
        handled = registeredComponent:keypressed(key, scancode, isrepeat, UIManager._player)
      else
        -- Fallback to hardcoded component handling
        if component == "inventory" and Inventory.keypressed then
          handled = Inventory.keypressed(key)
        elseif component == "docked" and DockedUI.keypressed then
          handled = DockedUI.keypressed(key, scancode, isrepeat, UIManager._player)
        elseif component == "ship" and Ship.keypressed then
          handled = Ship.keypressed(key)
        elseif component == "map" and Map.keypressed then
          handled = Map.keypressed(key, world)
        elseif component == "warp" and warpInstance.keypressed then
          handled = warpInstance:keypressed(key, scancode, isrepeat)
        elseif component == "escape" and EscapeMenu.keypressed then
          handled = EscapeMenu.keypressed(key)
        end
      end

      if handled then
        return true
      end
    end
  end
  
  return false
end

-- Handle text input for UI components
function UIManager.textinput(text)
  for _, component in ipairs(UIManager.layerOrder) do
    if UIManager.state[component].open then
      -- Get the registered component
      local registeredComponent = Registry.get(component)

      -- Handle registered components dynamically
      if registeredComponent and registeredComponent.textinput then
        if registeredComponent:textinput(text) then return true end
      else
        -- Fallback to hardcoded component handling
        if component == "inventory" and Inventory.textinput then
          if Inventory.textinput(text) then return true end
        elseif component == "docked" and DockedUI.textinput then
          if DockedUI.textinput(text) then return true end
        elseif component == "escape" and EscapeMenu.textinput then
          if EscapeMenu.textinput(text) then return true end
        end
      end
    end
  end
  return false
end

-- Handle keyboard release for UI components
function UIManager.keyreleased(key, scancode)
  -- Route to active components
  for _, component in ipairs(UIManager.layerOrder) do
    if UIManager.state[component].open then
      local handled = false

      -- Get the registered component
      local registeredComponent = Registry.get(component)

      -- Handle registered components dynamically
      if registeredComponent and registeredComponent.keyreleased then
        handled = registeredComponent:keyreleased(key, scancode)
      else
        -- Fallback to hardcoded component handling
        if component == "inventory" and Inventory.keyreleased then
          handled = Inventory.keyreleased(key, scancode)
        elseif component == "docked" and DockedUI.keyreleased then
          handled = DockedUI.keyreleased(key, scancode)
        elseif component == "map" and Map.keyreleased then
          handled = Map.keyreleased(key, scancode)
        elseif component == "warp" and warpInstance.keyreleased then
          handled = warpInstance:keyreleased(key, scancode)
        elseif component == "escape" and EscapeMenu.keyreleased then
          handled = EscapeMenu.keyreleased(key, scancode)
        end
      end

      if handled then
        return true
      end
    end
  end

  return false
end

-- Get warp instance (for external access)
function UIManager.getWarpInstance()
  return warpInstance
end

return UIManager

