--[[
  Input handling module for the game.
  Manages keyboard and mouse input, UI interactions, and game state changes.
]]
local ActionMap = require("src.core.action_map")
local Events = require("src.core.events")
local Viewport = require("src.core.viewport")
local Notifications = require("src.ui.notifications")
local Log = require("src.core.log")
local Map = require("src.ui.map")
local SettingsPanel = require("src.ui.settings_panel")
local SkillsPanel = require("src.ui.skills")
local Util = require("src.core.util")
local Hotbar = require("src.systems.hotbar")
local RepairSystem = require("src.systems.repair_system")
local UI = require("src.ui.hud.root")
local NetworkSession = require("src.core.network.session")

local Input = {}

local function dispatch_settings_panel_event(event_name, ...)
  if not SettingsPanel.visible then
    return false
  end

  local handler = SettingsPanel[event_name]
  if type(handler) ~= "function" then
    return false
  end

  return handler(...)
end

-- Game state references (will be tables with the actual values)
local gameState = {}
-- State passed from main.lua
local mainState = {}

-- Mouse button state tracking
local mouseState = {
  rightButtonDown = false,
  leftButtonDown = false
}

-- Safe cargo require helper
local function getCargoModule()
  local ok, cargo = pcall(require, "src.ui.cargo")
  if not ok or type(cargo) ~= "table" then
    return {
      visible = false,
      init = function() end,
      draw = function() end,
      mousepressed = function() return false, false end,
      mousereleased = function() return false, false end,
      mousemoved = function() return false end,
      keypressed = function() return false end,
      textinput = function() return false end,
      getRect = function() return nil end,
    }
  end
  return cargo
end

local function isUiTextInputFocused()
    if mainState.screen ~= "game" then
        return false
    end

    local uiManager = mainState.UIManager
    if not uiManager or type(uiManager.isTextInputActive) ~= "function" then
        local ok, manager = pcall(require, "src.core.ui_manager")
        if not ok then
            return false
        end
        uiManager = manager
    end

    local ok, captured = pcall(uiManager.isTextInputActive)
    if ok then
        return captured and true or false
    end

    return false
end

-- Input handling functions
local function handleInput()
    if not gameState.camera or not gameState.camera.screenToWorld then
        return { aimx = 0, aimy = 0 } -- Default values if camera isn't ready
    end

    -- Get raw mouse coordinates and convert to virtual coordinates
    -- The camera system works in virtual space, not raw screen space
    local mx, my = love.mouse.getPosition()

    -- Handle case where mouse position might be invalid
    if mx == nil or my == nil or mx ~= mx or my ~= my then -- Check for NaN
        return { aimx = 0, aimy = 0, leftClick = mouseState.leftButtonDown }
    end

    -- Convert from actual screen coordinates to virtual coordinates
    local vx, vy = Viewport.toVirtual(mx, my)
    local wx, wy = gameState.camera:screenToWorld(vx, vy)

    -- Handle case where world coordinates might be invalid
    if wx == nil or wy == nil or wx ~= wx or wy ~= wy then -- Check for NaN
        return { aimx = 0, aimy = 0, leftClick = mouseState.leftButtonDown }
    end

    local leftClick = mouseState.leftButtonDown

    return {
        aimx = wx,
        aimy = wy,
        leftClick = leftClick
    }
end

local function transitionToGame(opts)
    opts = opts or {}
    local fromSave = opts.fromSave == true
    local saveSlot = opts.slot
    local multiplayer = opts.multiplayer == true
    local isHost = opts.isHost == true
    local loadingScreen = mainState.loadingScreen
    local Game = require("src.game")

    if not multiplayer then
        if _G.PENDING_MULTIPLAYER_CONNECTION then
            _G.PENDING_MULTIPLAYER_CONNECTION = nil
        end

        if NetworkSession.getManager then
            local existingManager = NetworkSession.getManager()
            if existingManager and existingManager:isMultiplayer() then
                existingManager:leaveGame()
            end
        end

        NetworkSession.setMode(false, false)
    end

    local function handleMultiplayerJoinFailure(message)
        if _G.PENDING_MULTIPLAYER_CONNECTION then
            _G.PENDING_MULTIPLAYER_CONNECTION = nil
        end

        if mainState.startScreen and mainState.startScreen.onJoinFailed then
            mainState.startScreen:onJoinFailed(message)
        end
    end

    if loadingScreen then
        local loadingText = multiplayer and (isHost and "Starting multiplayer server..." or "Joining multiplayer game...") or "Loading..."
        loadingScreen:show({loadingText}, false)
    end

    local function performLoad()
        if fromSave then
            if saveSlot == "autosave" then
                return Game.load(true, "autosave", loadingScreen, multiplayer, isHost)
            end
            return Game.load(true, saveSlot, loadingScreen, multiplayer, isHost)
        end

        return Game.load(false, nil, loadingScreen, multiplayer, isHost)
    end

    local success, result, detail = pcall(performLoad)

    if loadingScreen then
        loadingScreen:hide()
    end

    -- Check if Game.load() succeeded
    if not success then
        Log.error("Game.load() failed with error:", result)
        local errorMessage = "Failed to load game: " .. tostring(result)
        Notifications.add(errorMessage, "error")
        if multiplayer and not isHost then
            handleMultiplayerJoinFailure(result or "Failed to connect to server. Please check the address and try again.")
        end
        return false
    elseif result == false then
        local failureMessage = detail
        if not failureMessage then
            if multiplayer and not isHost then
                failureMessage = "Failed to connect to server"
            else
                failureMessage = "Failed to load game"
            end
        end

        Log.error("Game.load() returned false", failureMessage)
        Notifications.add(failureMessage, "error")
        if multiplayer and not isHost then
            handleMultiplayerJoinFailure(failureMessage)
        end
        return false
    end

    mainState.UIManager = require("src.core.ui_manager")
    
    -- Force viewport sync BEFORE screen transition to prevent flicker
    local Viewport = require("src.core.viewport")
    Viewport.syncWithWindow()
    
    -- Keep system cursor hidden in gameplay; UI draws its own reticle
    mainState.setScreen("game")

    return true
end

local function handleStartScreenResult(result)
    -- nil/false: not handled by start screen
    if result == nil or result == false then
        return false
    end

    -- true: handled by start screen, but DO NOT transition (used for generic handling)
    if result == true then
        return true
    elseif result == "loadGame" then
        local loadedSlot = mainState.startScreen and mainState.startScreen.loadedSlot
        if loadedSlot then
            transitionToGame({ fromSave = true, slot = loadedSlot })
        else
            Log.error("No loaded slot information available")
            Notifications.add("No save slot selected", "warning")
        end
        return true
    elseif result == "hostGame" then
        transitionToGame({ fromSave = false, multiplayer = true, isHost = true })
        return true
    elseif result == "joinGame" then
        if not transitionToGame({ fromSave = false, multiplayer = true, isHost = false }) then
            Notifications.add("Connection failed", "error")
            if mainState.setScreen then mainState.setScreen("start") end
        end
        return true
    elseif result == "newGame" then
        transitionToGame({ fromSave = false, multiplayer = false, isHost = false })
        return true
    end

    -- Any other non-false value: treat as handled, but do not transition
    return true
end

function Input.update(dt)
    if Map and Map.update then
        Map.update(dt, gameState.player)
    end
    
    if mainState.UIManager then
        if mainState.UIManager.isOpen("cargo")
            or mainState.UIManager.isOpen("skills")
            or mainState.UIManager.isOpen("escape")
            or mainState.UIManager.isModalActive() then
            return
        end
    end
end

-- This is the existing game-logic keypressed
function Input.keypressed(key)

    if isUiTextInputFocused() then
        return
    end

    local context = {
        key = key,
        player = gameState.player,
        world = gameState.world,
        UIManager = mainState.UIManager,
        Events = Events,
        notifications = Notifications,
        util = Util,
        repairSystem = RepairSystem,
    }

    local handled = ActionMap.dispatch(key, context)
    if handled then
        return
    end

    Hotbar.keypressed(key, gameState.player)
end

-- This is the new LÖVE callback handler
function Input.love_keypressed(key)
  if SettingsPanel.keypressed(key) then return true end
  if mainState.screen == "start" then
    if mainState.startScreen and mainState.startScreen.keypressed then
      local startResult = mainState.startScreen:keypressed(key)
      if handleStartScreenResult(startResult) then
        return
      end
    end
  elseif mainState.screen == "game" then
    if key == "escape" then
      if mainState.UIManager then
        -- Let UIManager handle escape key (includes the new input router system)
        if mainState.UIManager.keypressed(key) then
          return
        end
      end
    end
    if key == "f5" then
      local StateManager = require("src.managers.state_manager")
      local success = StateManager.quickSave()
      Notifications.add(success and "Quick save completed" or "Quick save failed", success and "success" or "error")
      return
    elseif key == "f9" then
      local StateManager = require("src.managers.state_manager")
      local success = StateManager.quickLoad()
      Notifications.add(success and "Quick load completed" or "Quick load failed", success and "info" or "error")
      return
    end

    -- Previously input was blocked when a modal UI was active; allow the
    -- UIManager to receive keypresses so toggle hotkeys (e.g. 'g' for ship)
    -- continue to work even while a modal (like the ship window) is open.

    if mainState.UIManager and mainState.UIManager.isTextInputActive and mainState.UIManager:isTextInputActive() then
        return
    end
    local textInputFocused = isUiTextInputFocused()
    if mainState.UIManager and mainState.UIManager.keypressed(key) then
      return
    end
    if textInputFocused and isUiTextInputFocused() then
      return
    end
    Input.keypressed(key)
  end
end

function Input.love_keyreleased(key)
  if mainState.screen == "start" then
    if mainState.startScreen and mainState.startScreen.keyreleased and mainState.startScreen:keyreleased(key) then
      return
    end
  elseif mainState.screen == "game" then
    if mainState.UIManager and mainState.UIManager.keyreleased and mainState.UIManager.keyreleased(key) then
      return
    end
    -- Forward to hotbar system for manual mode turrets
    Hotbar.keyreleased(key, gameState.player)
  end
end

function Input.love_mousepressed(x, y, button)
  if mainState.screen == "start" then
    local vx, vy = Viewport.toVirtual(x, y)
    local start = mainState.startScreen:mousepressed(vx, vy, button)
    if handleStartScreenResult(start) then
      return
    end
  else
    -- Convert screen coords to virtual coords so UI hit-testing matches rendering
    local vx, vy = Viewport.toVirtual(x, y)

    if dispatch_settings_panel_event("mousepressed", vx, vy, button) then
      return
    end

    -- Use the active modal component to block input
    if mainState.UIManager and mainState.UIManager.mousepressed(vx, vy, button) then
      return
    end

    if UI.handleHelperMousePressed and UI.handleHelperMousePressed(vx, vy, button, gameState.player) then
      return
    end

    Input.mousepressed(vx, vy, button)
  end
end

function Input.love_mousereleased(x, y, button)
  if mainState.screen == "start" and mainState.startScreen.mousereleased then
    local vx, vy = Viewport.toVirtual(x, y)
    mainState.startScreen:mousereleased(vx, vy, button)
  elseif mainState.screen == "game" then
    -- Convert screen coords to virtual coords
    local vx, vy = Viewport.toVirtual(x, y)

    if dispatch_settings_panel_event("mousereleased", vx, vy, button) then
      return
    end
    -- Use the active modal component to block input
    if mainState.UIManager and mainState.UIManager.mousereleased(vx, vy, button) then
      return
    end
    Input.mousereleased(vx, vy, button)
  end
end

function Input.love_mousemoved(x, y, dx, dy, istouch)
  if mainState.screen == "start" and mainState.startScreen.mousemoved then
    local vx, vy = Viewport.toVirtual(x, y)
    local s = Viewport.getScale()
    mainState.startScreen:mousemoved(vx, vy, dx / s, dy / s, istouch)
  elseif mainState.screen == "game" then
    -- Convert screen coords to virtual coords and scale deltas
    local vx, vy = Viewport.toVirtual(x, y)
    local s = Viewport.getScale()

    if dispatch_settings_panel_event("mousemoved", vx, vy, dx / s, dy / s) then
      return
    end

    if mainState.UIManager and mainState.UIManager.mousemoved(vx, vy, dx / s, dy / s) then
      return
    end
    Input.mousemoved(vx, vy, dx / s, dy / s, istouch)
  end
end

function Input.love_wheelmoved(dx, dy)
  if mainState.screen == "start" then
    if mainState.startScreen and mainState.startScreen.wheelmoved then
      local mx, my = love.mouse.getPosition()
      local vx, vy = Viewport.toVirtual(mx, my)
      if mainState.startScreen:wheelmoved(vx, vy, dx, dy) then
        return
      end
    end
    return
  end

  if mainState.screen == "game" then
    local mx, my = love.mouse.getPosition()
    local vx, vy = Viewport.toVirtual(mx, my)

    if dispatch_settings_panel_event("wheelmoved", vx, vy, dx, dy) then
      return
    end
    if mainState.UIManager and mainState.UIManager.wheelmoved and mainState.UIManager.wheelmoved(vx, vy, dx, dy) then
      return
    end
    Input.wheelmoved(dx, dy)
  end
end

function Input.love_textinput(text)
  if mainState.screen == "start" then
    if mainState.startScreen and mainState.startScreen.textinput and mainState.startScreen:textinput(text) then
      return
    end
  elseif mainState.screen == "game" then
    if mainState.UIManager and mainState.UIManager.textinput(text) then
      return
    end
    Input.textinput(text)
  end
end


function Input.textinput(text)
    if mainState.UIManager.isOpen("cargo") then
        local CargoUI = getCargoModule()
        if CargoUI.textinput and CargoUI.textinput(text) then
            return
        end
    end
end

function Input.mousepressed(x, y, button)
    -- If UI is under cursor or modal is active, don't process game clicks
    if mainState.UIManager and mainState.UIManager.isMouseOverUI and mainState.UIManager.isMouseOverUI() then
        return
    end
    local wx, wy
    if gameState.camera and gameState.camera.screenToWorld then
        wx, wy = gameState.camera:screenToWorld(x, y)
    end
    -- UI interactions are handled earlier via UIManager in love_* callbacks

    -- Interaction system mouse handling
    if gameState.player then
        local InteractionSystem = require("src.systems.interaction")
        if InteractionSystem.mousepressed(x, y, button, gameState.player, gameState.camera) then
            return
        end
    end

    -- Process mouse clicks through action map first
    local context = {
        key = button == 1 and "mouse1" or "mouse2",
        player = gameState.player,
        world = gameState.world,
        UIManager = mainState.UIManager,
        Events = Events,
        notifications = Notifications,
        util = Util,
        repairSystem = RepairSystem,
    }
    
    local handled = ActionMap.dispatch(context.key, context)
    if handled then
        return
    end

    -- Hotbar mouse interactions (fallback)
    if button == 1 then
        Hotbar.keypressed("mouse1", gameState.player)
    elseif button == 2 then
        Hotbar.keypressed("mouse2", gameState.player)
    end

    if button == 2 then
        mouseState.rightButtonDown = true
    elseif button == 1 then
        mouseState.leftButtonDown = true
    end
end

function Input.mousereleased(x, y, button)
    -- UI interactions are handled earlier via UIManager in love_* callbacks
    
    if button == 1 then
        Hotbar.keyreleased("mouse1", gameState.player)
    elseif button == 2 then
        Hotbar.keyreleased("mouse2", gameState.player)
    end

    if button == 1 then
        mouseState.leftButtonDown = false
    elseif button == 2 then
        mouseState.rightButtonDown = false
    end

    
    if SkillsPanel.isVisible() then
        local consumed, shouldClose = SkillsPanel.mousereleased(x, y, button)
        if shouldClose then SkillsPanel.visible = false end
        if consumed then return end
    end

end

function Input.mousemoved(x, y, dx, dy, istouch)
    -- If UI is under cursor or modal is active, do not process game hover
    if mainState.UIManager and mainState.UIManager.isMouseOverUI and mainState.UIManager.isMouseOverUI() then
        return
    end

    if not gameState.camera or not gameState.camera.screenToWorld then return end
    local wx, wy = gameState.camera:screenToWorld(x, y)

    local best, bestDist, hoverType = nil, 99999, nil

    -- Start with mineable entities first
    for _, a in ipairs(gameState.world:get_entities_with_components("mineable")) do
        local d = Util.distance(wx, wy, a.components.position.x, a.components.position.y)
        if d < (((a.components.collidable and a.components.collidable.radius) or 20) * 1.5) and d < bestDist then
            best, bestDist, hoverType = a, d, "neutral"
        end
    end

    if not best then
        for _, w in ipairs(gameState.world:get_entities_with_components("wreckage")) do
            if w.components and w.components.position then
                local d = Util.distance(wx, wy, w.components.position.x, w.components.position.y)
                if d < ((w.components.collidable and w.components.collidable.radius) or 25) and d < bestDist then
                    best, bestDist, hoverType = w, d, "neutral"
                end
            end
        end
    end

    if not best then
        for _, e in ipairs(gameState.world:get_entities_with_components("ai")) do
            local d = Util.distance(wx, wy, e.components.position.x, e.components.position.y)
            if d < (((e.components.collidable and e.components.collidable.radius) or 10) * 1.5) and d < bestDist then
                best, bestDist, hoverType = e, d, "enemy"
            end
        end
    end

    gameState.hoveredEntity = best
    gameState.hoveredEntityType = hoverType
end

function Input.wheelmoved(dx, dy)
    -- Handle mouse wheel events for the game
    if not gameState or not gameState.camera then return false end
    
    -- Block camera zoom when UI is open
    if mainState.UIManager and mainState.UIManager.isModalActive and mainState.UIManager:isModalActive() then
        return false
    end
    
    -- Map/wheel events are handled in love_wheelmoved via dedicated calls
    
    -- Default behavior: smooth zoom the camera
    if dy ~= 0 then
        if dy > 0 then
            gameState.camera:zoomIn()
        else
            gameState.camera:zoomOut()
        end
        return true
    end
    
    return false
end

function Input.init(state)
    gameState = state
end

function Input.init_love_callbacks(state)
    mainState = state
end

function Input.getInputState()
    return handleInput()
end

function Input.getMouseState()
    return {
        rightButtonDown = mouseState.rightButtonDown,
        leftButtonDown = mouseState.leftButtonDown
    }
end

return Input
