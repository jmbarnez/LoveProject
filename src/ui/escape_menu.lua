local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local SettingsPanel = require("src.ui.settings_panel")
local SaveLoad = require("src.ui.save_load")
local StateManager = require("src.managers.state_manager")
local UIState = require("src.core.ui.state")
local Window = require("src.ui.common.window")
local UIButton = require("src.ui.common.button")

local EscapeMenu = {
    visible = false,
    exitButtonDown = false,
    settingsButtonDown = false,
    saveButtonDown = false,
    lanButtonDown = false,
    saveLoadPanel = nil,
    saveLoadPanelZ = nil,
    _floatingWindowZ = 180
}

local function nextFloatingZ()
    EscapeMenu._floatingWindowZ = (EscapeMenu._floatingWindowZ or 180) + 1
    return EscapeMenu._floatingWindowZ
end

local function pointIn(px, py, rx, ry, rw, rh)
    if type(px) ~= "number" or type(py) ~= "number" or type(rx) ~= "number" or type(ry) ~= "number" or type(rw) ~= "number" or type(rh) ~= "number" then
        return false
    end
    return px >= rx and py >= ry and px <= rx + rw and py <= ry + rh
end

-- Calculate preferred layout size based on content
local function getLayoutSize()
    local buttonH = Theme.getScaledSize(28)
    local buttonSpacing = Theme.getScaledSize(4)
    local totalButtons = 4

    local w = Theme.getScaledSize(200) -- Set a fixed width for the content area

    -- Calculate height without padding
    local totalHeight = (buttonH * totalButtons) + (buttonSpacing * (totalButtons - 1))
    local h = totalHeight

    return w, h
end

local function getLayout()
  -- Always compute layout in CONTENT coordinates so it matches drawContent()
  local buttonH = Theme.getScaledSize(28)
  local buttonSpacing = Theme.getScaledSize(4)

  local x, y, w, h
  if EscapeMenu.window and EscapeMenu.window.getContentBounds then
    local b = EscapeMenu.window:getContentBounds()
    x, y, w, h = b.x, b.y, b.w, b.h
  else
    -- Fallback before init: estimate centered content rect using chrome sizes
    local sw, sh = Viewport.getDimensions()
    local cw, ch = getLayoutSize()
    local border = Theme.getScaledSize(2)
    local titleBar = Theme.getScaledSize(24)
    local winW = cw + border * 2
    local winH = ch + titleBar + border
    local winX = (sw - winW) / 2
    local winY = (sh - winH) / 2
    x = winX + border
    y = winY + titleBar
    w, h = cw, ch
  end

    local buttonW = w  -- Full width
    local buttonX = x
    local startY = y
    local saveButtonY = startY
    local settingsButtonY = saveButtonY + buttonH + buttonSpacing
    local lanButtonY = settingsButtonY + buttonH + buttonSpacing
    local exitButtonY = lanButtonY + buttonH + buttonSpacing

    return x, y, w, h, buttonX, saveButtonY, settingsButtonY, lanButtonY, exitButtonY, buttonW, buttonH
end

function EscapeMenu.show()
    EscapeMenu.visible = true
    -- Ensure UIManager state sync
    local ok, UIManager = pcall(require, "src.core.ui_manager")
    if ok and UIManager and UIManager.state and UIManager.state.escape then
        UIManager.state.escape.open = true
    end
    if UIState and UIState.setShowingSaveSlots then
        UIState.setShowingSaveSlots(false)
    end
    -- Game continues running when escape menu is opened
end

function EscapeMenu.hide()
    EscapeMenu.visible = false
    -- Ensure UIManager state sync
    local ok, UIManager = pcall(require, "src.core.ui_manager")
    if ok and UIManager and UIManager.state and UIManager.state.escape then
        UIManager.state.escape.open = false
    end

    if UIState and UIState.setShowingSaveSlots then
        UIState.setShowingSaveSlots(false)
    end

    if EscapeMenu.saveLoadPanel then
        EscapeMenu.saveLoadPanel = nil
        EscapeMenu.saveLoadPanelZ = nil
    end

    -- Game continues running when escape menu is closed
end

function EscapeMenu.isVisible()
    return EscapeMenu.visible
end

function EscapeMenu.toggle()
    EscapeMenu.visible = not EscapeMenu.visible
end

function EscapeMenu.init()
    local contentW, contentH = getLayoutSize()
    -- Add chrome (borders/titlebar) so content fits without being scissored
    local border = Theme.getScaledSize(2)
    local titleBar = Theme.getScaledSize(24)
    local windowW = contentW + border * 2
    local windowH = contentH + titleBar + border

    -- Get screen dimensions for positioning
    local sw, sh = Viewport.getDimensions()
    local windowX = math.floor((sw - windowW) * 0.5)
    local windowY = math.floor((sh - windowH) * 0.5)

    -- Ensure window doesn't go off-screen
    windowX = math.max(0, math.min(sw - windowW, windowX))
    windowY = math.max(0, math.min(sh - windowH, windowY))

    EscapeMenu.window = Window.new({
        title = "Menu",
        x = windowX,
        y = windowY,
        width = windowW,
        height = windowH,
        useLoadPanelTheme = true,
        closable = true,
        draggable = true,
        resizable = false,
        drawContent = EscapeMenu.drawContent,
        onClose = function()
            EscapeMenu.hide()
            -- Play close sound
            local Sound = require("src.core.sound")
            Sound.triggerEvent('ui_button_click')
        end
    })
end

function EscapeMenu.draw()
    if not EscapeMenu.visible then return end
    if not EscapeMenu.window then EscapeMenu.init() end

    -- Draw escape menu window
    EscapeMenu.window.visible = EscapeMenu.visible
    if EscapeMenu.window.visible then
        EscapeMenu.window:draw()
    end

    -- Draw save/load panel if it exists
    if EscapeMenu.saveLoadPanel and EscapeMenu.saveLoadPanel.window then
        EscapeMenu.saveLoadPanel.window:draw()
    end
end

function EscapeMenu.drawContent(window, x, y, w, h)
    local mx, my = Viewport.getMousePosition()
    local t = love.timer.getTime()

    -- Use unified font system
    Theme.setFont("normal")

    -- Use the same layout calculation as mousepressed for consistency
    local _, _, _, _, buttonX, saveButtonY, settingsButtonY, lanButtonY, exitButtonY, buttonW, buttonH = getLayout()

    -- Save Game button
    local saveHover = pointIn(mx, my, buttonX, saveButtonY, buttonW, buttonH)
    Theme.drawMenuButton(buttonX, saveButtonY, buttonW, buttonH, "Save", saveHover, t, { down = EscapeMenu.saveButtonDown })

    -- Settings button
    local settingsHover = pointIn(mx, my, buttonX, settingsButtonY, buttonW, buttonH)
    Theme.drawMenuButton(buttonX, settingsButtonY, buttonW, buttonH, "Settings", settingsHover, t, { down = EscapeMenu.settingsButtonDown })

    -- LAN button
    local lanHover = pointIn(mx, my, buttonX, lanButtonY, buttonW, buttonH)
    Theme.drawMenuButton(buttonX, lanButtonY, buttonW, buttonH, "Open to LAN", lanHover, t, { down = EscapeMenu.lanButtonDown })

    -- Exit to Main Menu button
    local exitHover = pointIn(mx, my, buttonX, exitButtonY, buttonW, buttonH)
    Theme.drawMenuButton(buttonX, exitButtonY, buttonW, buttonH, "Exit to Menu", exitHover, t, { down = EscapeMenu.exitButtonDown })
end

function EscapeMenu.mousepressed(x, y, button)
    if not EscapeMenu.visible then return false, false end
    -- If a floating save/load panel exists and the click is inside it,
    -- route to the save/load panel and always consume the click so it
    -- does not fall through to the EscapeMenu buttons behind it.
    if EscapeMenu.saveLoadPanel and EscapeMenu.saveLoadPanel.window then
        local w = EscapeMenu.saveLoadPanel.window
        if pointIn(x, y, w.x, w.y, w.width, w.height) then
            -- Ensure the save/load instance gets the event and bring it to front
            local handled = false
            if EscapeMenu.saveLoadPanel and EscapeMenu.saveLoadPanel.mousepressed then
                handled = EscapeMenu.saveLoadPanel:mousepressed(x, y, button)
            end
            EscapeMenu.saveLoadPanelZ = nextFloatingZ()
            return true, false
        end
    end

    -- Handle window interaction (drag, close)
    if EscapeMenu.window and EscapeMenu.window:mousepressed(x, y, button) then
        if not EscapeMenu.window.visible then
            EscapeMenu.hide()
            return true, true -- Window closed
        end
        return true, false -- Click was on window chrome
    end

    -- Handle buttons inside the escape menu content area
    local _, _, _, _, buttonX, saveButtonY, settingsButtonY, lanButtonY, exitButtonY, buttonW, buttonH = getLayout()

    local buttons = {
        {name = "save", y = saveButtonY, action = function() EscapeMenu.saveButtonDown = true end},
        {name = "settings", y = settingsButtonY, action = function() EscapeMenu.settingsButtonDown = true end},
        {name = "lan", y = lanButtonY, action = function() EscapeMenu.lanButtonDown = true end},
        {name = "exit", y = exitButtonY, action = function() EscapeMenu.exitButtonDown = true end}
    }

    for _, btn in ipairs(buttons) do
        local buttonRect = {x = buttonX, y = btn.y, w = buttonW, h = buttonH}
        if pointIn(x, y, buttonRect.x, buttonRect.y, buttonRect.w, buttonRect.h) then
            btn.action()
            return true, false
        end
    end

    -- If click is inside the window but not on a button, consume it
    if EscapeMenu.window and EscapeMenu.window:containsPoint(x, y) then
        return true, false
    end

    return false, false
end

function EscapeMenu.mousereleased(x, y, button)
    if not EscapeMenu.visible then return false, false end
    
    -- Handle save/load panel input first
    if EscapeMenu.saveLoadPanel and EscapeMenu.saveLoadPanel.window then
        local w = EscapeMenu.saveLoadPanel.window
        if pointIn(x, y, w.x, w.y, w.width, w.height) then
            if EscapeMenu.saveLoadPanel and EscapeMenu.saveLoadPanel.mousereleased then
                return EscapeMenu.saveLoadPanel:mousereleased(x, y, button)
            end
            return true, false
        end
    end
    
    if not EscapeMenu.window then return true, false end

    if EscapeMenu.window:mousereleased(x, y, button) then
        return true, false
    end

    if SettingsPanel.visible then
        return SettingsPanel.mousereleased(x, y, button)
    end

    local menuX, menuY, menuW, menuH, buttonX, saveButtonY, settingsButtonY, lanButtonY, exitButtonY, buttonW, buttonH = getLayout()

    if button == 1 then
        -- Save Game button
        if EscapeMenu.saveButtonDown then
            EscapeMenu.saveButtonDown = false
            if pointIn(x, y, buttonX, saveButtonY, buttonW, buttonH) then
                if EscapeMenu.saveLoadPanel then
                    return true, false
                end

                EscapeMenu.saveLoadPanel = SaveLoad:new({
                    onClose = function()
                        EscapeMenu.saveLoadPanel = nil
                        EscapeMenu.saveLoadPanelZ = nil
                        if UIState and UIState.setShowingSaveSlots then
                            UIState.setShowingSaveSlots(false)
                        end
                    end
                })

                EscapeMenu.saveLoadPanelZ = nextFloatingZ()

                -- Make the window visible and ensure it's centered
                if EscapeMenu.saveLoadPanel and EscapeMenu.saveLoadPanel.window then
                    local sw, sh = Viewport.getDimensions()
                    EscapeMenu.saveLoadPanel.window.x = math.floor((sw - EscapeMenu.saveLoadPanel.window.width) * 0.5)
                    EscapeMenu.saveLoadPanel.window.y = math.floor((sh - EscapeMenu.saveLoadPanel.window.height) * 0.5)
                    EscapeMenu.saveLoadPanel.window:show()
                end

                if UIState and UIState.setShowingSaveSlots then
                    UIState.setShowingSaveSlots(true)
                end

                -- Save/load panel is now handled as a floating window
                -- The window handles its own input and drawing
                return true, false
            end
        end

        -- Settings button
        if EscapeMenu.settingsButtonDown then
            EscapeMenu.settingsButtonDown = false
            if pointIn(x, y, buttonX, settingsButtonY, buttonW, buttonH) then
                -- Open settings panel via UIManager (it will be on top of escape menu)
                local UIManager = require("src.core.ui_manager")
                if UIManager and UIManager.open then
                    UIManager.open("settings")
                end
                return true, false
            end
        end

        -- LAN button
        if EscapeMenu.lanButtonDown then
            EscapeMenu.lanButtonDown = false
            if pointIn(x, y, buttonX, lanButtonY, buttonW, buttonH) then
                -- Play button click sound
                local Sound = require("src.core.sound")
                Sound.triggerEvent('ui_button_click')
                
                -- Toggle LAN hosting
                local Game = require("src.game")
                local Notifications = require("src.ui.notifications")
                
                local success, result = Game.toggleLanHosting()
                if not success then
                    if result == "no_network" then
                        Notifications.add("Network manager not available", "error")
                    else
                        Notifications.add("Failed to start multiplayer server", "error")
                    end
                else
                    if result == "lan_opened" then
                        Notifications.add("Opened current world to LAN players", "success")
                    elseif result == "lan_closed" then
                        Notifications.add("Stopped hosting multiplayer game", "info")
                    else
                        Notifications.add("Left multiplayer game", "info")
                    end
                end
                return true, false
            end
        end

        -- Exit to Main Menu button
        if EscapeMenu.exitButtonDown then
            EscapeMenu.exitButtonDown = false
            if pointIn(x, y, buttonX, exitButtonY, buttonW, buttonH) then
                love.setScreen("start")
                return true, false
            end
        end
    end

    -- Consume all clicks when menu is visible
    return true, false
end

function EscapeMenu.mousemoved(x, y, dx, dy)
    if not EscapeMenu.visible then return false end
    
    -- Handle save/load panel input first
    if EscapeMenu.saveLoadPanel and EscapeMenu.saveLoadPanel.window then
        local w = EscapeMenu.saveLoadPanel.window
        if pointIn(x, y, w.x, w.y, w.width, w.height) then
            if EscapeMenu.saveLoadPanel and EscapeMenu.saveLoadPanel.mousemoved then
                return EscapeMenu.saveLoadPanel:mousemoved(x, y, dx, dy)
            end
            return true
        end
    end
    
    if not EscapeMenu.window then return true end

    if EscapeMenu.window:mousemoved(x, y, dx, dy) then
        return true
    end
    return true
end

function EscapeMenu.keypressed(key)
    if not EscapeMenu.visible then return false end
    
    -- Handle save/load panel input first
    if EscapeMenu.saveLoadPanel and EscapeMenu.saveLoadPanel.keypressed then
        return EscapeMenu.saveLoadPanel:keypressed(key)
    end
    
    -- Let the input router handle escape key globally
    -- This function now only handles non-escape keys
    
    if SettingsPanel.visible then
        return SettingsPanel.keypressed(key)
    end
    
    return true -- Consume all non-escape keypresses when menu is visible
end

function EscapeMenu.textinput(text)
    if not EscapeMenu.visible then return false end
    
    -- Handle save/load panel input first
    if EscapeMenu.saveLoadPanel and EscapeMenu.saveLoadPanel.textinput then
        return EscapeMenu.saveLoadPanel:textinput(text)
    end
    
    if SettingsPanel.visible then
        return false -- Let settings panel handle its own text input
    end
    
    return true -- Consume all text input when menu is visible
end

return EscapeMenu
