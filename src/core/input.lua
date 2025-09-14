--[[
  Input handling module for the game.
  Manages keyboard and mouse input, UI interactions, and game state changes.
]]
local Settings = require("src.core.settings")
local Events = require("src.core.events")
local Viewport = require("src.core.viewport")
local Notifications = require("src.ui.notifications")
local SkillsPanel = require("src.ui.skills")
local EscapeMenu = require("src.ui.escape_menu")
local Map = require("src.ui.map")
local SettingsPanel = require("src.ui.settings_panel")
local Util = require("src.core.util")
local Log = require("src.core.log")

local Input = {}

-- Game state references (will be tables with the actual values)
local gameState = {}
-- State passed from main.lua
local mainState = {}

-- Mouse button state tracking
local mouseState = {
  rightButtonDown = false,
  leftButtonDown = false
}

-- Safe inventory require helper
local function getInventoryModule()
  local ok, inv = pcall(require, "src.ui.inventory")
  if not ok or type(inv) ~= "table" then
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
  return inv
end

-- Input handling functions
local function handleInput()
    if not gameState.camera or not gameState.camera.screenToWorld then
        return { aimx = 0, aimy = 0 } -- Default values if camera isn't ready
    end

    local mx, my = Viewport.getMousePosition()
    local wx, wy = gameState.camera:screenToWorld(mx, my)
    
    local leftClick = mouseState.leftButtonDown
    
    return { 
        aimx = wx, 
        aimy = wy,
        leftClick = leftClick
    }
end

function Input.update(dt)
    if Map and Map.update then
        Map.update(dt, gameState.player)
    end
    
    if (mainState.UIManager and mainState.UIManager.isOpen("inventory")) or
        (mainState.UIManager and mainState.UIManager.isOpen("bounty")) or
        (SkillsPanel and SkillsPanel.isVisible and SkillsPanel.isVisible()) or
        (Map and Map.isVisible and Map.isVisible()) then
        return
    end
end

-- This is the existing game-logic keypressed
function Input.keypressed(key)
    if SettingsPanel.isBinding() then return end
  Log.debug("Input.keypressed", key)
    local keymap = Settings.getKeymap()

    if Map and Map.keypressed and Map.keypressed(key, gameState and gameState.world) then return end

    local DockedUI = require("src.ui.docked")
    if DockedUI.isVisible() then
        local consumed, shouldClose = DockedUI.keypressed(key)
        if shouldClose and gameState.player then gameState.player:undock() end
        if consumed then return end
    end

    if key == "escape" then
        -- Only open escape menu if player exists and is not docked
        if gameState.player and not DockedUI.isVisible() then
            EscapeMenu.toggle()
        end
        return -- Always consume escape key, whether we open menu or not
    end

    if EscapeMenu.keypressed(key) then return end

    if mainState.UIManager.isOpen("inventory") then
        local Inventory = getInventoryModule()
        if Inventory.keypressed and Inventory.keypressed(key) then return end
    end
    if key == keymap.toggle_inventory then mainState.UIManager.toggle("inventory") end
    if key == keymap.toggle_bounty then mainState.UIManager.toggle("bounty") end
    if key == keymap.toggle_skills then SkillsPanel.toggle() end
    if key == keymap.toggle_map then Map.toggle(gameState and gameState.world) end
    if key == keymap.dock or key == "space" then
        -- Space key priority: warp gate > dock > container
        if gameState.player and gameState.world then
            -- Check if player is near warp gate
            local allWarpGates = gameState.world:getEntitiesWithComponents("warp_gate")
            for _, warpGate in ipairs(allWarpGates) do
                if warpGate.canInteractWith and warpGate:canInteractWith(gameState.player) then
                    -- Open warp UI directly
                    mainState.UIManager.open("warp")
                    return
                end
            end
            
            -- Check if player can dock
            if gameState.player.canDock then
                Events.emit(Events.GAME_EVENTS.DOCK_REQUESTED)
                return
            end
            
            -- Check for nearby containers
            local px, py = gameState.player.components.position.x, gameState.player.components.position.y
            for _, container in ipairs(gameState.world:getEntitiesWithComponents("lootContainer")) do
                local cx = container.components.position.x
                local cy = container.components.position.y
                local r = (container.components.collidable and container.components.collidable.radius) or 35
                if Util.distance(px, py, cx, cy) <= math.max(100, r) then
                    require("src.ui.loot_container_window").open(container.components.lootContainer, gameState.player, gameState.camera)
                    return
                end
            end
        end
    end

    -- Handle repair key (R key)
    if key == "r" then
        -- Check if player is near a repairable beacon station
        if gameState.player and gameState.world then
            local RepairSystem = require("src.systems.repair_system")
            local allStations = gameState.world:getEntitiesWithComponents("repairable")

            for _, station in ipairs(allStations) do
                if station.components.repairable and station.components.repairable.broken then
                    local dx = station.components.position.x - gameState.player.components.position.x
                    local dy = station.components.position.y - gameState.player.components.position.y
                    local distance = math.sqrt(dx * dx + dy * dy)

                    if distance <= 200 then -- Same range as tooltip
                        local success = RepairSystem.tryRepair(station, gameState.player)
                        if success then
                            Notifications.add("Beacon station repaired successfully!", "success")
                        else
                            Notifications.add("Insufficient materials for repair", "error")
                        end
                        return -- Only repair one station per key press
                    end
                end
            end
        end
    end


    local Hotbar = require("src.systems.hotbar")
    Log.debug("Input.keypressed: forwarding to Hotbar", key)
    Hotbar.keypressed(key, gameState.player)

    if key == "f11" then
        local fs = love.window.getFullscreen()
        love.window.setFullscreen(not fs, "desktop")
    end
end

-- This is the new LÖVE callback handler
function Input.love_keypressed(key)
  if SettingsPanel.keypressed(key) then return end
  if key == "f11" then
    local fs = love.window.getFullscreen()
    love.window.setFullscreen(not fs, "desktop")
    return
  end
  if mainState.screen == "start" then
    if mainState.startScreen and mainState.startScreen.keypressed and mainState.startScreen:keypressed(key) then
      return
    end
  elseif mainState.screen == "game" then
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
    
    if key == "tab" then
      mainState.UIManager.toggle("inventory")
      return
    end
    if mainState.UIManager and mainState.UIManager.keypressed(key) then
      return
    end
    Input.keypressed(key)
  end
end

function Input.love_mousepressed(x, y, button)
  local Game = require("src.game")
  if mainState.screen == "start" then
    local vx, vy = Viewport.toVirtual(x, y)
    local start = mainState.startScreen:mousepressed(vx, vy, button)
    if start == true then
      Game.load()
      love.mouse.setVisible(false)
      mainState.UIManager = require("src.core.ui_manager")
      mainState.setScreen("game")
      return
    elseif start == "loadGame" then
      local selectedSlot = mainState.startScreen.loadSlotsUI and mainState.startScreen.loadSlotsUI.selectedSlot
      Game.load()
      mainState.UIManager = require("src.core.ui_manager")
      love.mouse.setVisible(false)
      if selectedSlot then
        local StateManager = require("src.managers.state_manager")
        local slotName = "slot" .. selectedSlot
        local success = StateManager.loadGame(slotName)
        Notifications.add(success and ("Game loaded from Slot " .. selectedSlot) or "Failed to load game", success and "info" or "error")
      end
      mainState.setScreen("game")
      return
    end
  else
    local vx, vy = Viewport.toVirtual(x, y)
    if mainState.UIManager and mainState.UIManager.mousepressed(vx, vy, button) then
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
    local vx, vy = Viewport.toVirtual(x, y)
    if mainState.UIManager then
      mainState.UIManager.mousereleased(vx, vy, button)
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
    local vx, vy = Viewport.toVirtual(x, y)
    local s = Viewport.getScale()
    if mainState.UIManager and mainState.UIManager.mousemoved(vx, vy, dx / s, dy / s, istouch) then
      return
    end
    Input.mousemoved(vx, vy, dx / s, dy / s, istouch)
  end
end

function Input.love_wheelmoved(dx, dy)
  if mainState.screen == "game" then
    if SettingsPanel.visible then
        SettingsPanel.wheelmoved(dx, dy)
    else
        Input.wheelmoved(dx, dy)
    end
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
    if mainState.UIManager.isOpen("inventory") then
        local Inventory = getInventoryModule()
        if Inventory.textinput and Inventory.textinput(text) then
            return
        end
    end
end

function Input.mousepressed(x, y, button)
    local wx, wy
    if gameState.camera and gameState.camera.screenToWorld then
        wx, wy = gameState.camera:screenToWorld(x, y)
        for _, container in ipairs(gameState.world:getEntitiesWithComponents("lootContainer")) do
            local r = (container.components.collidable and container.components.collidable.radius) or 35
            if Util.distance(wx, wy, container.components.position.x, container.components.position.y) <= r then
                if Util.distance(gameState.player.components.position.x, gameState.player.components.position.y, container.components.position.x, container.components.position.y) <= 100 then
                    require("src.ui.loot_container_window").open(container.components.lootContainer, gameState.player, gameState.camera)
                else
                    Notifications.info("Move closer to open container")
                end
                return
            end
        end
    end
    if Map and Map.mousepressed then
        local consumed, shouldClose = Map.mousepressed(x, y, button)
        if shouldClose then Map.hide() return end
        if consumed then return end
    end
    
    local consumed, shouldClose = EscapeMenu.mousepressed(x, y, button)
    if shouldClose then EscapeMenu.hide() return end
    if consumed then return end
    
    local DockedUI = require("src.ui.docked")
    if DockedUI.isVisible() then
        local consumed, shouldClose = DockedUI.mousepressed(x, y, button)
        if shouldClose and gameState.player then gameState.player:undock() end
        if consumed then return end
    end
    
    local LootContainerWindow = require("src.ui.loot_container_window")
    if LootContainerWindow.isOpen() and LootContainerWindow.mousepressed(x, y, button) then return end

    if SkillsPanel.isVisible() then
        local consumed, shouldClose = SkillsPanel.mousepressed(x, y, button)
        if shouldClose then SkillsPanel.visible = false end
        if consumed then return end
    end

    if mainState.UIManager.isOpen("bounty") then
        local Bounty = require("src.ui.bounty")
        local consumed, shouldClose = Bounty.mousepressed(x, y, button, gameState.player.docked)
        if shouldClose then mainState.UIManager.close("bounty") end
        if consumed then return end
    end

    if mainState.UIManager.isOpen("inventory") then
        local Inventory = getInventoryModule()
        local consumed, shouldClose = Inventory.mousepressed(x, y, button)
        if shouldClose then mainState.UIManager.close("inventory") end
        if consumed then return end
    end
    if require("src.ui.hud.hotbar").mousepressed(gameState.player, x, y, button) then return end

    require("src.systems.hotbar").mousepressed(x, y, button, gameState.player)

    if button == 2 then
        mouseState.rightButtonDown = true
    elseif button == 1 then
        mouseState.leftButtonDown = true
    end
end

function Input.mousereleased(x, y, button)
    if Map and Map.mousereleased and Map.mousereleased(x, y, button) then return end
    
    local consumed, shouldClose = EscapeMenu.mousereleased(x, y, button)
    if shouldClose then EscapeMenu.hide() return end
    if consumed then return end
    
    local DockedUI = require("src.ui.docked")
    if DockedUI.isVisible() then
        local consumed, shouldClose = DockedUI.mousereleased(x, y, button)
        if shouldClose and gameState.player then gameState.player:undock() end
        if consumed then return end
    end
    
    if require("src.ui.loot_container_window").isOpen() and require("src.ui.loot_container_window").mousereleased(x, y, button) then return end
    
    if button == 1 then
        mouseState.leftButtonDown = false
    elseif button == 2 then
        mouseState.rightButtonDown = false
    end

    require("src.systems.hotbar").mousereleased(button, gameState.player)
    
    if SkillsPanel.isVisible() then
        local consumed, shouldClose = SkillsPanel.mousereleased(x, y, button)
        if shouldClose then SkillsPanel.visible = false end
        if consumed then return end
    end

    if mainState.UIManager.isOpen("bounty") then
        local Bounty = require("src.ui.bounty")
        local consumed, shouldClose = Bounty.mousereleased(x, y, button, gameState.player.docked, function()
            gameState.player:addGC(gameState.bounty.uncollected or 0)
            gameState.bounty.uncollected = 0
        end)
        if shouldClose then mainState.UIManager.close("bounty") end
        if consumed then return end
    end

    if mainState.UIManager.isOpen("inventory") then
        local Inventory = getInventoryModule()
        local consumed, shouldClose = Inventory.mousereleased(x, y, button, gameState.player)
        if shouldClose then mainState.UIManager.close("inventory") end
        if consumed then return end
    end
end

function Input.mousemoved(x, y, dx, dy, istouch)
    if Map and Map.mousemoved and Map.mousemoved(x, y, dx, dy, gameState and gameState.world) then return end
    
    local DockedUI = require("src.ui.docked")
    if DockedUI.isVisible() and DockedUI.mousemoved(x, y, dx, dy) then return end
    
    if require("src.ui.loot_container_window").isOpen() and require("src.ui.loot_container_window").mousemoved(x, y, dx, dy) then return end
    if SkillsPanel.isVisible() and SkillsPanel.mousemoved(x, y, dx, dy) then return end

    if mainState.UIManager.isOpen("inventory") and getInventoryModule().mousemoved(x, y, dx, dy) then return end
    if mainState.UIManager.isOpen("bounty") and require("src.ui.bounty").mousemoved(x, y, dx, dy) then return end

    if not gameState.camera or not gameState.camera.screenToWorld then return end
    local wx, wy = gameState.camera:screenToWorld(x, y)

    local best, bestDist, hoverType = nil, 99999, nil

    for _, container in ipairs(gameState.world:getEntitiesWithComponents("lootContainer")) do
        local d = Util.distance(wx, wy, container.components.position.x, container.components.position.y)
        if d < ((container.components.collidable and container.components.collidable.radius) or 35) and d < bestDist then
            best, bestDist, hoverType = container, d, "lootContainer"
        end
    end

    if not best then
        for _, a in ipairs(gameState.world:getEntitiesWithComponents("mineable")) do
            local d = Util.distance(wx, wy, a.components.position.x, a.components.position.y)
            if d < (((a.components.collidable and a.components.collidable.radius) or 20) * 1.5) and d < bestDist then
                best, bestDist, hoverType = a, d, "neutral"
            end
        end
    end

    if not best then
        for _, w in ipairs(gameState.world:getEntitiesWithComponents("wreckage")) do
            if w.components and w.components.position then
                local d = Util.distance(wx, wy, w.components.position.x, w.components.position.y)
                if d < ((w.components.collidable and w.components.collidable.radius) or 25) and d < bestDist then
                    best, bestDist, hoverType = w, d, "neutral"
                end
            end
        end
    end

    if not best then
        for _, e in ipairs(gameState.world:getEntitiesWithComponents("ai")) do
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
    if SettingsPanel and SettingsPanel.visible and SettingsPanel.wheelmoved and SettingsPanel.wheelmoved(dx, dy) then return end
    if Map and Map.wheelmoved and Map.wheelmoved(dx, dy, gameState and gameState.world) then return end
    local DockedUI = require("src.ui.docked")
    if DockedUI and DockedUI.isVisible and DockedUI.isVisible() and DockedUI.wheelmoved and DockedUI.wheelmoved(dx, dy) then return end
    
    if dy == 0 then return end
    local mx, my = Viewport.getMousePosition()
    gameState.camera:zoomAtFactor((dy > 0) and 1.1 or 1/1.1, mx, my)
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
