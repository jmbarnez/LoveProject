local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")

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
  bounty = { open = false, zIndex = 15 },
  docked = { open = false, zIndex = 30 },
  escape = { open = false, zIndex = 100, showingSaveSlots = false }, -- Escape menu should be on top
  skills = { open = false, zIndex = 35 },
  map = { open = false, zIndex = 90 }, -- Map should be high priority but below escape
  warp = { open = false, zIndex = 95 }, -- Warp should be high priority but below escape
  settings = { open = false, zIndex = 110 } -- Settings panel should be on top of escape
}
UIManager.topZ = 110

-- UI priorities for proper layering
UIManager.layerOrder = {
  "inventory",
  "bounty",
  "skills",
  "docked",
  "map",
  "warp",
  "escape",
  "settings"
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
end

function UIManager.resize(w, h)
  if Inventory.init then Inventory.init() end
  -- No explicit resize on equipment; rect computed each draw
  if DockedUI.init then DockedUI.init() end
  if EscapeMenu.init then EscapeMenu.init() end
  if SkillsPanel.init then SkillsPanel.init() end
end

-- Update UI Manager state
function UIManager.update(dt, player)
  -- Sync with legacy UI state variables
  UIManager.state.inventory.open = Inventory.visible or false
  UIManager.state.bounty.open = Bounty.visible or false
  UIManager.state.docked.open = DockedUI.isVisible()
  UIManager.state.escape.open = EscapeMenu.visible or false
  UIManager.state.skills.open = SkillsPanel.visible or false
  UIManager.state.map.open = Map.isVisible()
  UIManager.state.warp.open = warpInstance.visible or false
  UIManager.state.settings.open = SettingsPanel.visible or false
  
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
end

-- Returns true if the mouse is currently over any visible UI component
function UIManager.isMouseOverUI()
  local Viewport = require("src.core.viewport")
  local mx, my = Viewport.getMousePosition()

  -- If any full-screen/modal UI is open, consider cursor over UI
  if UIManager.state.escape.open or UIManager.state.map.open or UIManager.state.warp.open or UIManager.state.docked.open then
    return true
  end
  -- Also consider save slots as modal UI
  if UIManager.state.escape.open and UIManager.state.escape.showingSaveSlots then
    return true
  end
  if UIManager.state.bounty.open or UIManager.state.skills.open then
    return true
  end
  local SettingsPanel = require("src.ui.settings_panel")
  if SettingsPanel.visible then return true end

  -- Inventory window
  local Inventory = require("src.ui.inventory")
  if Inventory.visible and Inventory.getRect then
    local r = Inventory.getRect()
    if r and mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then return true end
  end

  -- Warp interface window

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
  -- Keep a reference for input routing needing player context
  UIManager._player = player
  -- Baseline font to avoid leakage from components/tooltips
  local Theme = require("src.core.theme")
  local oldFont = love.graphics.getFont()
  if Theme and Theme.fonts and Theme.fonts.normal then
    love.graphics.setFont(Theme.fonts.normal)
  end
  -- Draw components in layer order (lowest to highest z-index)
  local sortedLayers = {}
  for _, component in ipairs(UIManager.layerOrder) do
    if UIManager.state[component].open then
      table.insert(sortedLayers, {
        name = component,
        zIndex = UIManager.state[component].zIndex
      })
    end
  end
  
  -- Sort by z-index
  table.sort(sortedLayers, function(a, b) return a.zIndex < b.zIndex end)
  
  -- Draw each component
  for _, layer in ipairs(sortedLayers) do
    local component = layer.name
    
    if component == "inventory" then
      Inventory.draw(player)
    elseif component == "bounty" then
      Bounty.draw(bounty, player.docked)
    elseif component == "docked" then
      if DockedUI.setBounty then DockedUI.setBounty(bounty) end
      DockedUI.draw(player)
    elseif component == "escape" then
      EscapeMenu.draw()
    elseif component == "settings" then
      SettingsPanel.draw()
    elseif component == "skills" then
      SkillsPanel.draw()
    elseif component == "map" then
      local asteroids = world and world:get_entities_with_components("mineable") or {}
      local wrecks = world and world:get_entities_with_components("wreckage") or {}
      local stations = {}

      -- Collect all stations from world
      if world then
        local world_stations = world:get_entities_with_components("station") or {}
        for _, station in ipairs(worldStations) do
          table.insert(stations, station)
        end
      end

      -- Add hub if provided separately
      if hub then
        table.insert(stations, hub)
      end

      -- Get remote players (multiplayer)
      local Multiplayer = require("src.core.multiplayer")
      local remotePlayers = Multiplayer.getRemotePlayers and Multiplayer.getRemotePlayers() or {}

      Map.draw(player, world, enemies, asteroids, wrecks, stations, lootDrops, remotePlayers)
    elseif component == "warp" then
      warpInstance:draw()
    end
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

  -- Restore prior font to prevent persistent size changes across frames
  if oldFont then love.graphics.setFont(oldFont) end
end

-- Draw modal overlay to dim background
function UIManager.drawOverlay()
    if UIManager.modalActive or SettingsPanel.visible then
        local sw, sh = Viewport.getDimensions()
        Theme.setColor(Theme.colors.overlay)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    end
    -- Also draw overlay for save slots
    if UIManager.state.escape.open and UIManager.state.escape.showingSaveSlots then
        local sw, sh = Viewport.getDimensions()
        Theme.setColor(Theme.colors.overlay)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    end
end

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
  -- Build list of open components with z-index for proper top-first routing
  local openLayers = {}
  for _, component in ipairs(UIManager.layerOrder) do
    if UIManager.state[component].open then
      table.insert(openLayers, { name = component, z = UIManager.state[component].zIndex })
    end
  end

  -- Sort by z-index descending (topmost first)
  table.sort(openLayers, function(a, b) return (a.z or 0) > (b.z or 0) end)

  -- Helper to get a component rect for hit-testing
  local function getComponentRect(name)
    if name == "inventory" and Inventory.getRect then
      return Inventory.getRect()
    elseif name == "docked" then
      -- Fullscreen docked UI
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
        UIManager.topZ = UIManager.topZ + 1
        UIManager.state[layer.name].zIndex = UIManager.topZ
        break
      end
    end
  end

  -- Re-sort after raising
  for _, layer in ipairs(openLayers) do
    layer.z = UIManager.state[layer.name].zIndex
  end
  table.sort(openLayers, function(a, b) return (a.z or 0) > (b.z or 0) end)

  -- Route input to components from top to bottom
  for _, layer in ipairs(openLayers) do
    local component = layer.name
    local handled = false
    local shouldClose = false

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
    elseif component == "escape_save_slots" and EscapeMenu.mousepressed then
      -- Handle save slots input through escape menu
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
      if component == "inventory" and Inventory.mousereleased then
        Inventory.mousereleased(x, y, button, UIManager._player)
      elseif component == "bounty" and Bounty.mousereleased then
        Bounty.mousereleased(x, y, button)
      elseif component == "docked" and DockedUI.mousereleased then
        DockedUI.mousereleased(x, y, button)
      elseif component == "escape" and EscapeMenu.mousereleased then
        EscapeMenu.mousereleased(x, y, button)
      elseif component == "escape_save_slots" and EscapeMenu.mousereleased then
        -- Handle save slots mouse release through escape menu
        EscapeMenu.mousereleased(x, y, button)
      elseif component == "skills" and SkillsPanel.mousereleased then
        SkillsPanel.mousereleased(x, y, button)
      end
    end
  end
  if SettingsPanel.visible and SettingsPanel.mousereleased then
    SettingsPanel.mousereleased(x, y, button)
  end
end

function UIManager.mousemoved(x, y, dx, dy)
  if SettingsPanel.visible and SettingsPanel.mousemoved then
    if SettingsPanel.mousemoved(x, y, dx, dy) then return true end
  end
  for _, component in ipairs(UIManager.layerOrder) do
    if UIManager.state[component].open then
      if component == "docked" and DockedUI.mousemoved then
        if DockedUI.mousemoved(x, y, dx, dy) then return true end
      elseif component == "warp" and warpInstance.mousemoved then
        if warpInstance:mousemoved(x, y, dx, dy) then return true end
      elseif component == "escape_save_slots" then
        -- Save slots UI doesn't need mouse move handling, but we need to consume the event
        return true
      end
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
      elseif component == "escape_save_slots" and EscapeMenu.keypressed then
        -- Handle save slots keyboard input through escape menu
        handled = EscapeMenu.keypressed(key, scancode, isrepeat)
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
      if component == "inventory" and Inventory.textinput then
        if Inventory.textinput(text) then return true end
      elseif component == "docked" and DockedUI.textinput then
        if DockedUI.textinput(text) then return true end
      elseif component == "escape" and EscapeMenu.textinput then
        if EscapeMenu.textinput(text) then return true end
      elseif component == "escape_save_slots" and EscapeMenu.textinput then
        -- Handle save slots text input through escape menu
        if EscapeMenu.textinput(text) then return true end
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
      elseif component == "escape_save_slots" and EscapeMenu.keyreleased then
        -- Handle save slots key release through escape menu
        handled = EscapeMenu.keyreleased(key, scancode)
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
