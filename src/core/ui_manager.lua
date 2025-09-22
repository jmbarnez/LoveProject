local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Registry = require("src.ui.core.registry")

-- UI components
local Inventory = require("src.ui.inventory")
local Bounty = require("src.ui.bounty")
local DockedUI = require("src.ui.docked")
local EscapeMenu = require("src.ui.escape_menu")
local Notifications = require("src.ui.notifications")
local SkillsPanel = require("src.ui.skills")
local Map = require("src.ui.map")
local SettingsPanel = require("src.ui.settings_panel")
local Warp = require("src.ui.warp")
local DebugPanel = require("src.ui.debug_panel")

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

-- Create warp instance
local warpInstance = Warp:new()

-- Central UI state
UIManager.state = {
  inventory = { open = false, zIndex = 10 },
  bounty = { open = false, zIndex = 20 },
  skills = { open = false, zIndex = 30 },
  docked = { open = false, zIndex = 40 },
  map = { open = false, zIndex = 50 },
  warp = { open = false, zIndex = 60 },
  escape = { open = false, zIndex = 100, showingSaveSlots = false }, -- Escape menu should be on top
  settings = { open = false, zIndex = 110 }, -- Settings panel should be on top of escape
  debug = { open = false, zIndex = 120 } -- Debug panel should be on top of everything
}
UIManager.topZ = 120

-- UI priorities for proper layering
UIManager.layerOrder = {
  "inventory",
  "bounty",
  "skills",
  "docked",
  "map",
  "warp",
  "escape",
  "settings",
  "debug"
}

-- Modal state - when true, blocks input to lower layers
UIManager.modalActive = false
UIManager.modalComponent = nil

-- Initialize UI Manager
function UIManager.init()
  -- Initialize all UI components
  if Inventory.init then Inventory.init() end
  if DockedUI.init then DockedUI.init() end
  if EscapeMenu.init then EscapeMenu.init() end
  if SkillsPanel.init then SkillsPanel.init() end
  if warpInstance.init then warpInstance:init() end
  if DebugPanel.init then DebugPanel.init() end
  -- Register components in the UI registry once
  if not UIManager._registryInitialized then
    Registry.register({
      id = "inventory",
      isVisible = function() return UIManager.state.inventory.open or (Inventory and Inventory.visible) end,
      getZ = function() return (UIManager.state.inventory and UIManager.state.inventory.zIndex) or 0 end,
      getRect = function() return Inventory and Inventory.getRect and Inventory.getRect() or nil end,
    })
    Registry.register({
      id = "bounty",
      isVisible = function() return UIManager.state.bounty.open or (Bounty and Bounty.visible) end,
      getZ = function() return (UIManager.state.bounty and UIManager.state.bounty.zIndex) or 0 end,
      getRect = function() return Bounty.getRect and Bounty.getRect() or nil end,
    })
    Registry.register({
      id = "docked",
      isVisible = function() return UIManager.state.docked.open or (DockedUI and DockedUI.isVisible and DockedUI.isVisible()) end,
      getZ = function() return (UIManager.state.docked and UIManager.state.docked.zIndex) or 0 end,
      getRect = function()
        local sw, sh = Viewport.getDimensions()
        return { x = 0, y = 0, w = sw, h = sh }
      end,
    })
    Registry.register({
      id = "skills",
      isVisible = function() return UIManager.state.skills.open or (SkillsPanel and SkillsPanel.visible) end,
      getZ = function() return (UIManager.state.skills and UIManager.state.skills.zIndex) or 0 end,
      getRect = function()
        local win = SkillsPanel and SkillsPanel.window
        if win then return { x = win.x, y = win.y, w = win.width, h = win.height } end
        return nil
      end,
    })
    Registry.register({
      id = "map",
      isVisible = function() return UIManager.state.map.open or (Map and Map.isVisible and Map.isVisible()) end,
      getZ = function() return (UIManager.state.map and UIManager.state.map.zIndex) or 0 end,
      getRect = function()
        local win = Map and Map.window
        if win then return { x = win.x, y = win.y, w = win.width, h = win.height } end
        return nil
      end,
    })
    Registry.register({
      id = "warp",
      isVisible = function() return UIManager.state.warp.open or (warpInstance and warpInstance.visible) end,
      getZ = function() return (UIManager.state.warp and UIManager.state.warp.zIndex) or 0 end,
      getRect = function() return nil end,
    })
    Registry.register({
      id = "escape",
      isVisible = function() return UIManager.state.escape.open or (EscapeMenu and EscapeMenu.isVisible and EscapeMenu.isVisible()) end,
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
        local SettingsPanel = require("src.ui.settings_panel")
        return (UIManager.state.settings and UIManager.state.settings.open) or (SettingsPanel and SettingsPanel.visible)
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
      id = "debug",
      isVisible = function() return DebugPanel.isVisible() end,
      getZ = function() return (UIManager.state.debug and UIManager.state.debug.zIndex) or 0 end,
      getRect = function()
        local win = DebugPanel and DebugPanel.window
        if win then return { x = win.x, y = win.y, w = win.width, h = win.height } end
        return nil
      end,
    })
    UIManager._registryInitialized = true
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
  UIManager.state.bounty.open = Bounty.visible or false
  UIManager.state.docked.open = DockedUI.isVisible()
  UIManager.state.escape.open = EscapeMenu.visible or false
  UIManager.state.escape.showingSaveSlots = EscapeMenu.showSaveSlots or false
  UIManager.state.skills.open = SkillsPanel.visible or false
  UIManager.state.map.open = Map.isVisible()
  UIManager.state.warp.open = warpInstance.visible or false
  UIManager.state.settings.open = SettingsPanel.visible or false
  UIManager.state.debug.open = DebugPanel.isVisible()
  
  -- Update modal state
  UIManager.modalActive = UIManager.state.escape.open or UIManager.state.map.open or UIManager.state.warp.open or SettingsPanel.visible
  if SettingsPanel.visible then
    UIManager.modalComponent = "settings"
  elseif UIManager.state.escape.open and UIManager.state.escape.showingSaveSlots then
    UIManager.modalComponent = "escape_save_slots"
  elseif UIManager.state.escape.open then
    UIManager.modalComponent = "escape"
  elseif UIManager.state.map.open then
    UIManager.modalComponent = "map"
  elseif UIManager.state.warp.open then
    UIManager.modalComponent = "warp"
  else
    UIManager.modalComponent = nil
  end

  -- Update individual components
  if Notifications.update then Notifications.update(dt) end
  if SkillsPanel.update then SkillsPanel.update(dt) end
  if Inventory.update then Inventory.update(dt) end
  if DockedUI.update then DockedUI.update(dt, player) end
  if EscapeMenu.update then EscapeMenu.update(dt) end
  if Map.update then Map.update(dt, player) end
  if warpInstance.update then warpInstance:update(dt) end
  if DebugPanel.update then DebugPanel.update(dt) end
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
  if Hotbar.getRect and Hotbar.getRect() then
    local r = Hotbar.getRect()
    if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then return true end
  end

  local HotbarSelection = require("src.ui.hud.hotbar_selection")
  if HotbarSelection.visible then
    return true
  end

  return false
end

-- Draw all UI components in proper order
function UIManager.draw(player, world, enemies, hub, wreckage, lootDrops, bounty)
  -- Overlay drawing removed as per user request

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
        Inventory.draw(player)
      elseif component == "bounty" then
        Bounty.draw(bounty, player.docked)
      elseif component == "docked" then
        if DockedUI.setBounty then DockedUI.setBounty(bounty) end
        DockedUI.draw(player)
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

        Map.draw(player, world, enemies, asteroids, wrecks, stations, lootDrops, {})
      elseif component == "warp" then
        warpInstance:draw()
      end
    end
  end

  -- Draw escape and settings last, with settings on top of escape
  if UIManager.state.escape.open then
    EscapeMenu.draw()
  end
  -- Draw save slots on top of escape menu if active
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

  -- Draw UI cursor when mouse is over UI elements (on top of all UI)
  local overUI = false
  for _, comp in ipairs(Registry.visibleSortedDescending()) do
    local r = comp.getRect and comp.getRect()
    if r then
      local mx, my = love.mouse.getPosition()
      if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
        overUI = true
        break
      end
    end
  end

  if overUI then
    local mx, my = love.mouse.getPosition()
    local Theme = require("src.core.theme")
    local Settings = require("src.core.settings")

    -- Get UI cursor color (similar to reticle)
    local g = Settings.getGraphicsSettings()
    local uiCursorColor
    if g and g.ui_cursor_color_rgb and type(g.ui_cursor_color_rgb) == 'table' then
      uiCursorColor = { g.ui_cursor_color_rgb[1] or 1, g.ui_cursor_color_rgb[2] or 1, g.ui_cursor_color_rgb[3] or 1, g.ui_cursor_color_rgb[4] or 1 }
    else
      uiCursorColor = Theme.colors.accent
    end

    Theme.setColor(uiCursorColor)
    love.graphics.polygon("fill", mx, my, mx + 12, my + 12, mx, my + 15)
    Theme.setColor(Theme.colors.text)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", mx, my, mx + 12, my + 12, mx, my + 15)
  end

  -- Restore prior font to prevent persistent size changes across frames
  if oldFont then love.graphics.setFont(oldFont) end
end

-- The drawOverlay function was removed as per user instruction to not dim the screen.

-- Toggle UI component visibility
function UIManager.toggle(component)
  if UIManager.state[component] then
    local wasOpen = UIManager.state[component].open
    UIManager.close(component)
    if not wasOpen then
      UIManager.open(component)
    end
    Log.info("UI toggle", component, "->", not wasOpen)
    return not wasOpen
  end
  return false
end

-- Open UI component
function UIManager.open(component)
  if UIManager.state[component] then
    UIManager.topZ = UIManager.topZ + 1
    UIManager.state[component].zIndex = UIManager.topZ
    UIManager.state[component].open = true
    
    -- Sync with legacy UI systems
    if component == "inventory" then
      Inventory.visible = true
    elseif component == "bounty" then
      Bounty.visible = true
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
  end
end

-- Close UI component
function UIManager.close(component)
  if UIManager.state[component] then
    UIManager.state[component].open = false
    
    -- Sync with legacy UI systems
    if component == "inventory" then
      Inventory.visible = false
    elseif component == "bounty" then
      Bounty.visible = false
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
    local handled = false
    local shouldClose = false

    -- Get the registered component
    local registeredComponent = Registry.get(component)

    -- Handle registered components dynamically
    if registeredComponent and registeredComponent.mousepressed then
      handled = registeredComponent:mousepressed(x, y, button, UIManager._player)
      -- For registered components, we don't handle closing here as they manage their own lifecycle
    else
      -- Fallback to hardcoded component handling
      if component == "inventory" and Inventory.mousepressed then
        handled, shouldClose = Inventory.mousepressed(x, y, button, UIManager._player)
        if shouldClose then
          UIManager.close("inventory")
        end
      elseif component == "bounty" and Bounty.mousepressed then
        handled, shouldClose = Bounty.mousepressed(x, y, button)
        if shouldClose then
          UIManager.close("bounty")
        end
      elseif component == "docked" and DockedUI.mousepressed then
        handled, shouldClose = DockedUI.mousepressed(x, y, button)
        if shouldClose then
          local player = DockedUI.player
          if player and player.undock then
            player:undock()
          end
        end
      elseif component == "escape" and EscapeMenu.mousepressed then
        handled, shouldClose = EscapeMenu.mousepressed(x, y, button)
        if shouldClose then
          UIManager.close("escape")
        end
      elseif component == "skills" and SkillsPanel.mousepressed then
        handled, shouldClose = SkillsPanel.mousepressed(x, y, button)
        if shouldClose then
          UIManager.close("skills")
        end
      elseif component == "settings" and SettingsPanel.mousepressed then
        handled = SettingsPanel.mousepressed(x, y, button)
      elseif component == "warp" and warpInstance.mousepressed then
        handled = warpInstance:mousepressed(x, y, button)
      elseif component == "debug" and DebugPanel.mousepressed then
        handled = DebugPanel.mousepressed(x, y, button)
      end
    end

    if handled then
      return true
    end
  end

  return false
end

-- Handle mouse release for UI components
function UIManager.mousereleased(x, y, button)
  -- Give both Equipment panels priority so drops are handled before Inventory clears drags
  if UIManager.state.docked.open and DockedUI and DockedUI.equipment and DockedUI.activeTab == "Ship" and DockedUI.equipment.mousereleased then
    DockedUI.equipment:mousereleased(DockedUI.player, x, y, button)
  end
  -- Process all open components for mouse release
  for _, component in ipairs(UIManager.layerOrder) do
    if UIManager.state[component].open then
      -- Get the registered component
      local registeredComponent = Registry.get(component)

      -- Handle registered components dynamically
      if registeredComponent and registeredComponent.mousereleased then
        registeredComponent:mousereleased(x, y, button, UIManager._player)
      else
        -- Fallback to hardcoded component handling
        if component == "inventory" and Inventory.mousereleased then
          Inventory.mousereleased(x, y, button, UIManager._player)
        elseif component == "bounty" and Bounty.mousereleased then
          Bounty.mousereleased(x, y, button)
        elseif component == "docked" and DockedUI.mousereleased then
          DockedUI.mousereleased(x, y, button)
        elseif component == "escape" and EscapeMenu.mousereleased then
          EscapeMenu.mousereleased(x, y, button)
        elseif component == "skills" and SkillsPanel.mousereleased then
          SkillsPanel.mousereleased(x, y, button)
        end
      end
    end
  end
  if SettingsPanel.visible and SettingsPanel.mousereleased then
    SettingsPanel.mousereleased(x, y, button)
  end
  if DebugPanel.isVisible() and DebugPanel.mousereleased then
    DebugPanel.mousereleased(x, y, button)
  end
end

function UIManager.mousemoved(x, y, dx, dy)
  -- Build list of visible components from registry (topmost first)
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
    if registeredComponent and registeredComponent.mousemoved then
      handled = registeredComponent:mousemoved(x, y, dx, dy, UIManager._player)
    else
      -- Fallback to hardcoded component handling
      if component == "inventory" and Inventory.mousemoved then
        handled = Inventory.mousemoved(x, y, dx, dy)
      elseif component == "bounty" and Bounty.mousemoved then
        handled = Bounty.mousemoved(x, y, dx, dy)
      elseif component == "docked" and DockedUI.mousemoved then
        handled = DockedUI.mousemoved(x, y, dx, dy)
      elseif component == "escape" and EscapeMenu.mousemoved then
        handled = EscapeMenu.mousemoved(x, y, dx, dy)
      elseif component == "skills" and SkillsPanel.mousemoved then
        handled = SkillsPanel.mousemoved(x, y, dx, dy)
      elseif component == "settings" and SettingsPanel.mousemoved then
        handled = SettingsPanel.mousemoved(x, y, dx, dy)
      elseif component == "map" and Map.mousemoved then
        handled = Map.mousemoved(x, y, dx, dy)
      elseif component == "warp" and warpInstance.mousemoved then
        handled = warpInstance:mousemoved(x, y, dx, dy)
      elseif component == "debug" and DebugPanel.mousemoved then
        handled = DebugPanel.mousemoved(x, y, dx, dy)
      end
    end

    if handled then
      return true
    end
  end

  return false
end

function UIManager.wheelmoved(x, y)
  if SettingsPanel.visible and SettingsPanel.wheelmoved then
    if SettingsPanel.wheelmoved(x, y) then return true end
  end
  if Bounty.visible and Bounty.wheelmoved then
    if Bounty.wheelmoved(x, y) then return true end
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
  -- Check for global hotkeys first
  if key == "escape" then
    -- Priority order: escape menu > docked UI > other modals

    -- Check escape menu is open, let it handle the keypress internally.
    -- This allows it to close the settings panel without closing itself.
    if UIManager.state.escape.open and EscapeMenu.keypressed(key, scancode, isrepeat) then
      return true
    end

    -- If docked UI is open, let it handle escape key (it will close/undock)
    if UIManager.state.docked.open then
      local handled, shouldClose = DockedUI.keypressed(key, scancode, isrepeat)
      if shouldClose then
        -- Trigger undocking via player
        local player = DockedUI.player
        if player and player.undock then
          player:undock()
        end
      end
      return true
    end

    if UIManager.isModalActive() then
      -- Close other active modals if escape menu isn't handling it
      if UIManager.modalComponent and UIManager.modalComponent ~= "settings" then
        UIManager.close(UIManager.modalComponent)
      end
    else
      -- Open escape menu
      UIManager.toggle("escape")
    end
    return true
  elseif key == "i" then
    UIManager.toggle("inventory")
    return true
  end

  -- Also accept TAB as inventory toggle at UI manager level so tab works regardless
  if key == "tab" then
    UIManager.toggle("inventory")
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
          handled = Inventory.keypressed(key, scancode, isrepeat)
        elseif component == "bounty" and Bounty.keypressed then
          handled = Bounty.keypressed(key, scancode, isrepeat)
        elseif component == "docked" and DockedUI.keypressed then
          handled = DockedUI.keypressed(key, scancode, isrepeat)
        elseif component == "map" and Map.keypressed then
          handled = Map.keypressed(key, scancode, isrepeat)
        elseif component == "warp" and warpInstance.keypressed then
          handled = warpInstance:keypressed(key, scancode, isrepeat)
        elseif component == "escape" and EscapeMenu.keypressed then
          handled = EscapeMenu.keypressed(key, scancode, isrepeat)
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
        elseif component == "bounty" and Bounty.keyreleased then
          handled = Bounty.keyreleased(key, scancode)
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
