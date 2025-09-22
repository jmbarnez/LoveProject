local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local SettingsPanel = require("src.ui.settings_panel")
local SaveSlots = require("src.ui.save_slots")
local StateManager = require("src.managers.state_manager")
local Window = require("src.ui.common.window")
local UIButton = require("src.ui.common.button")
local Registry = require("src.ui.core.registry")

local EscapeMenu = {
    visible = false,
    exitButtonDown = false,
    settingsButtonDown = false,
    saveButtonDown = false,
    showSaveSlots = false,
    saveSlotMode = "save",
    saveSlotsUI = nil
}

-- Save slots component for UI registry
local SaveSlotsComponent = {
    id = "escape_save_slots",
    zIndex = 105, -- Above escape menu but below settings

    isVisible = function()
        return EscapeMenu.showSaveSlots and EscapeMenu.saveSlotsUI and EscapeMenu.visible
    end,

    getZ = function()
        return 105 -- Above escape menu but below settings
    end,

    getRect = function()
        if not (EscapeMenu.showSaveSlots and EscapeMenu.saveSlotsUI) then return nil end
        local sw, sh = Viewport.getDimensions()

        -- Defensive check to ensure saveSlotsUI is valid
        if not EscapeMenu.saveSlotsUI or not EscapeMenu.saveSlotsUI.getPreferredSize then
            return nil
        end

        local success, w, h = pcall(EscapeMenu.saveSlotsUI.getPreferredSize, EscapeMenu.saveSlotsUI)
        if not success or type(w) ~= "number" or type(h) ~= "number" then return nil end
        local contentW, contentH = w, h

        local x = (sw - contentW) / 2
        local y = (sh - contentH) / 2
        return { x = x, y = y, w = contentW, h = contentH }
    end,

    draw = function(ctx)
        if not (EscapeMenu.showSaveSlots and EscapeMenu.saveSlotsUI) then return end
        local sw, sh = Viewport.getDimensions()

        -- Defensive check to ensure saveSlotsUI is valid
        if not EscapeMenu.saveSlotsUI or not EscapeMenu.saveSlotsUI.getPreferredSize then
            return
        end

        local success, w, h = pcall(EscapeMenu.saveSlotsUI.getPreferredSize, EscapeMenu.saveSlotsUI)
        if not success or type(w) ~= "number" or type(h) ~= "number" then return end
        local contentW, contentH = w, h

        local x = (sw - contentW) / 2
        local y = (sh - contentH) / 2
        EscapeMenu.saveSlotsUI:draw(x, y, contentW, contentH)
    end,

    mousepressed = function(x, y, button, ctx)
        if not (EscapeMenu.showSaveSlots and EscapeMenu.saveSlotsUI) then return false end
        if type(x) ~= "number" or type(y) ~= "number" then return false end
        local sw, sh = Viewport.getDimensions()

        if not EscapeMenu.saveSlotsUI or not EscapeMenu.saveSlotsUI.getPreferredSize then
            return false
        end

        local success, w, h = pcall(EscapeMenu.saveSlotsUI.getPreferredSize, EscapeMenu.saveSlotsUI)
        if not success or type(w) ~= "number" or type(h) ~= "number" then return false end
        local contentW, contentH = w, h

        local saveSlotsX = (sw - contentW) / 2
        local saveSlotsY = (sh - contentH) / 2

        -- Check if click is within save slots UI bounds
        if x >= saveSlotsX and x <= saveSlotsX + contentW and y >= saveSlotsY and y <= saveSlotsY + contentH then
            -- Additional safety check before calling mousepressed
            if EscapeMenu.saveSlotsUI and EscapeMenu.saveSlotsUI.mousepressed then
                local result = EscapeMenu.saveSlotsUI:mousepressed(x, y, button, saveSlotsX, saveSlotsY, contentW, contentH)
                if result == "saved" or result == "loaded" or result == "deleted" then
                    -- Save/load operation completed, return to escape menu
                    EscapeMenu.showSaveSlots = false
                    if _G.UIManager and _G.UIManager.state and _G.UIManager.state.escape then
                        _G.UIManager.state.escape.showingSaveSlots = false
                    end
                    -- Unregister the component since we're closing it
                    Registry.unregister("escape_save_slots")
                end
                return true
            end
        end
        return false
    end,

    mousereleased = function(x, y, button, ctx)
        if not (EscapeMenu.showSaveSlots and EscapeMenu.saveSlotsUI) then return false end
        if type(x) ~= "number" or type(y) ~= "number" then return false end
        local sw, sh = Viewport.getDimensions()

        if not EscapeMenu.saveSlotsUI or not EscapeMenu.saveSlotsUI.getPreferredSize then
            return false
        end

        local success, w, h = pcall(EscapeMenu.saveSlotsUI.getPreferredSize, EscapeMenu.saveSlotsUI)
        if not success or type(w) ~= "number" or type(h) ~= "number" then return false end
        local contentW, contentH = w, h

        local saveSlotsX = (sw - contentW) / 2
        local saveSlotsY = (sh - contentH) / 2

        -- Check if click is within save slots UI bounds
        if x >= saveSlotsX and x <= saveSlotsX + contentW and y >= saveSlotsY and y <= saveSlotsY + contentH then
            if EscapeMenu.saveSlotsUI and EscapeMenu.saveSlotsUI.mousereleased then
                return EscapeMenu.saveSlotsUI:mousereleased(x, y, button, saveSlotsX, saveSlotsY, contentW, contentH)
            end
            return true
        end
        return false
    end,

    mousemoved = function(x, y, dx, dy, ctx)
        if not (EscapeMenu.showSaveSlots and EscapeMenu.saveSlotsUI) then return false end
        if type(x) ~= "number" or type(y) ~= "number" then return false end
        local sw, sh = Viewport.getDimensions()

        if not EscapeMenu.saveSlotsUI or not EscapeMenu.saveSlotsUI.getPreferredSize then
            return false
        end

        local success, w, h = pcall(EscapeMenu.saveSlotsUI.getPreferredSize, EscapeMenu.saveSlotsUI)
        if not success or type(w) ~= "number" or type(h) ~= "number" then
            return false
        end
        local contentW, contentH = w, h

        local saveSlotsX = (sw - contentW) / 2
        local saveSlotsY = (sh - contentH) / 2

        if x >= saveSlotsX and x <= saveSlotsX + contentW and y >= saveSlotsY and y <= saveSlotsY + contentH then
            if EscapeMenu.saveSlotsUI and EscapeMenu.saveSlotsUI.mousemoved then
                return EscapeMenu.saveSlotsUI:mousemoved(x, y, dx, dy, saveSlotsX, saveSlotsY, contentW, contentH)
            end
            return true
        end
        return false
    end,

    keypressed = function(key, scancode, isrepeat, ctx)
        if not (EscapeMenu.showSaveSlots and EscapeMenu.saveSlotsUI) then return false end
        if key == "escape" then
            EscapeMenu.showSaveSlots = false
            if _G.UIManager and _G.UIManager.state and _G.UIManager.state.escape then
                _G.UIManager.state.escape.showingSaveSlots = false
            end
            -- Unregister the component since we're closing it
            Registry.unregister("escape_save_slots")
            return true
        end
        if EscapeMenu.saveSlotsUI and EscapeMenu.saveSlotsUI.keypressed then
            return EscapeMenu.saveSlotsUI:keypressed(key, scancode, isrepeat)
        end
        return false
    end,

    textinput = function(text)
        if not (EscapeMenu.showSaveSlots and EscapeMenu.saveSlotsUI) then return false end
        if EscapeMenu.saveSlotsUI and EscapeMenu.saveSlotsUI.textinput then
            return EscapeMenu.saveSlotsUI:textinput(text)
        end
        return false
    end
}

local function pointIn(px, py, rx, ry, rw, rh)
    if type(px) ~= "number" or type(py) ~= "number" or type(rx) ~= "number" or type(ry) ~= "number" or type(rw) ~= "number" or type(rh) ~= "number" then
        return false
    end
    return px >= rx and py >= ry and px <= rx + rw and py <= ry + rh
end

-- Calculate preferred layout size based on content
local function getLayoutSize()
    local font = love.graphics.getFont() or Theme.fonts.normal
    local buttonH = (Theme.ui and Theme.ui.buttonHeight) or 28
    local buttonSpacing = (Theme.ui and Theme.ui.buttonSpacing) or 4
    local totalButtons = 3
    local buttonPadding = (Theme.ui and Theme.ui.contentPadding) or 15  -- Consistent padding like other panels

    -- Calculate width based on longest button text
    local buttonTexts = {"Save", "Settings", "Exit to Menu"}
    local maxTextWidth = 0
    for _, text in ipairs(buttonTexts) do
        local textW = font:getWidth(text)
        if textW > maxTextWidth then
            maxTextWidth = textW
        end
    end

    -- Add padding for button content and spacing (consistent with drawContent)
  local buttonW = maxTextWidth + 20 -- 10px padding on each side
  -- Return CONTENT width. The window chrome (borders/titlebar) is added in init()
  local w = buttonW + buttonPadding * 2

    -- Calculate height with consistent padding
  local totalHeight = buttonPadding + (buttonH * totalButtons) + (buttonSpacing * (totalButtons - 1)) + buttonPadding
  -- Return CONTENT height. The window chrome (borders/titlebar) is added in init()
  local h = totalHeight

    return w, h
end

local function getLayout()
  -- Always compute layout in CONTENT coordinates so it matches drawContent()
  local buttonH = 28
  local buttonSpacing = 4
  local buttonPadding = 15

  local x, y, w, h
  if EscapeMenu.window and EscapeMenu.window.getContentBounds then
    local b = EscapeMenu.window:getContentBounds()
    x, y, w, h = b.x, b.y, b.w, b.h
  else
    -- Fallback before init: estimate centered content rect using chrome sizes
    local sw, sh = Viewport.getDimensions()
    local cw, ch = getLayoutSize()
    local border, titleBar = ((Theme.ui and Theme.ui.borderWidth) or 2), ((Theme.ui and Theme.ui.titleBarHeight) or 24)
    local winW = cw + border * 2
    local winH = ch + titleBar + border
    local winX = (sw - winW) / 2
    local winY = (sh - winH) / 2
    x = winX + border
    y = winY + titleBar
    w, h = cw, ch
  end

    local buttonW = w - buttonPadding * 2  -- Account for consistent padding
    local buttonX = x + buttonPadding
    local startY = y + buttonPadding
    local saveButtonY = startY
    local settingsButtonY = saveButtonY + buttonH + buttonSpacing
    local exitButtonY = settingsButtonY + buttonH + buttonSpacing

    return x, y, w, h, buttonX, saveButtonY, settingsButtonY, exitButtonY, buttonW, buttonH
end

function EscapeMenu.show()
    EscapeMenu.visible = true
    if not EscapeMenu.saveSlotsUI then
        EscapeMenu.saveSlotsUI = SaveSlots:new()
    end

    -- Game continues running when escape menu is opened
end

function EscapeMenu.hide()
    EscapeMenu.visible = false

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
    local border, titleBar = ((Theme.ui and Theme.ui.borderWidth) or 2), ((Theme.ui and Theme.ui.titleBarHeight) or 24)
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
        closable = true,
        draggable = true,
        resizable = false,
        drawContent = EscapeMenu.drawContent,
        onClose = function()
            EscapeMenu.hide()
        end
    })
end

function EscapeMenu.draw()
    if not EscapeMenu.visible then return end
    if not EscapeMenu.window then EscapeMenu.init() end

    -- Blur background only when save slots are not visible
    if not EscapeMenu.showSaveSlots then
        if not EscapeMenu.blurCanvas then
            local w, h = Viewport.getDimensions()
            EscapeMenu.blurCanvas = love.graphics.newCanvas(w, h)
        end
        love.graphics.setCanvas({EscapeMenu.blurCanvas, stencil = true})
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(Viewport.getCanvas(), 0, 0)
        love.graphics.setCanvas(Viewport.getCanvas())
        love.graphics.setShader(Theme.shaders.ui_blur)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.draw(EscapeMenu.blurCanvas, 0, 0)
        love.graphics.setShader()
    end

    -- Hide escape menu window when save slots are active (modal behavior)
    EscapeMenu.window.visible = EscapeMenu.visible and not EscapeMenu.showSaveSlots
    if EscapeMenu.window.visible then
        EscapeMenu.window:draw()
    end

    -- Register save slots component if needed
    if EscapeMenu.showSaveSlots and not Registry.get("escape_save_slots") then
        Registry.register(SaveSlotsComponent)
    elseif not EscapeMenu.showSaveSlots and Registry.get("escape_save_slots") then
        Registry.unregister("escape_save_slots")
    end
end

function EscapeMenu.drawContent(window, x, y, w, h)
    local mx, my = Viewport.getMousePosition()
    local t = love.timer.getTime()

    -- Use consistent font handling like other panels
    local font = Theme.fonts and (Theme.fonts.small or Theme.fonts.normal) or love.graphics.getFont()
    love.graphics.setFont(font)

    -- Calculate button dimensions consistently
    local buttonH = (Theme.ui and Theme.ui.buttonHeight) or 28
    local buttonSpacing = (Theme.ui and Theme.ui.buttonSpacing) or 4
    local buttonPadding = (Theme.ui and Theme.ui.contentPadding) or 15
    local buttonH = (Theme.ui and Theme.ui.buttonHeight) or 28
    local buttonSpacing = (Theme.ui and Theme.ui.buttonSpacing) or 4
    local buttonPadding = (Theme.ui and Theme.ui.contentPadding) or 15
    local buttonW = w - buttonPadding * 2
    local buttonX = x + buttonPadding
    local startY = y + buttonPadding

    -- Calculate button positions
    local saveButtonY = startY
    local settingsButtonY = saveButtonY + buttonH + buttonSpacing
    local exitButtonY = settingsButtonY + buttonH + buttonSpacing

    -- Save Game button
    local saveHover = pointIn(mx, my, buttonX, saveButtonY, buttonW, buttonH)
    Theme.drawStyledButton(buttonX, saveButtonY, buttonW, buttonH, "Save", saveHover, t, nil, EscapeMenu.saveButtonDown, { menuButton = true })

    -- Settings button
    local settingsHover = pointIn(mx, my, buttonX, settingsButtonY, buttonW, buttonH)
    Theme.drawStyledButton(buttonX, settingsButtonY, buttonW, buttonH, "Settings", settingsHover, t, nil, EscapeMenu.settingsButtonDown, { menuButton = true })

    -- Exit to Main Menu button
    local exitHover = pointIn(mx, my, buttonX, exitButtonY, buttonW, buttonH)
    Theme.drawStyledButton(buttonX, exitButtonY, buttonW, buttonH, "Exit to Menu", exitHover, t, nil, EscapeMenu.exitButtonDown, { menuButton = true })
end

function EscapeMenu.mousepressed(x, y, button)
    if not EscapeMenu.visible then return false, false end
    if not EscapeMenu.window then return true, false end

    -- If save slots are active, don't handle escape menu clicks
    if EscapeMenu.showSaveSlots then
        -- Register save slots component if needed
        if not Registry.get("escape_save_slots") then
            Registry.register(SaveSlotsComponent)
        end
        return true, false
    end

    if EscapeMenu.window:mousepressed(x, y, button) then
        -- If the close button was clicked, the window will hide itself. Keep state in sync.
        if not EscapeMenu.window.visible then
            EscapeMenu.hide()
            return true, true
        end
        return true, false
    end

    -- Register save slots component if needed
    if not Registry.get("escape_save_slots") then
        Registry.register(SaveSlotsComponent)
    end

    local _, _, _, _, buttonX, saveButtonY, settingsButtonY, exitButtonY, buttonW, buttonH = getLayout()

    -- Create button objects for Theme.handleButtonClick
    local buttons = {
        {name = "save", y = saveButtonY, action = function() EscapeMenu.saveButtonDown = true end},
        {name = "settings", y = settingsButtonY, action = function() EscapeMenu.settingsButtonDown = true end},
        {name = "exit", y = exitButtonY, action = function() EscapeMenu.exitButtonDown = true end}
    }

    -- Check all buttons
    for _, btn in ipairs(buttons) do
        local buttonRect = {x = buttonX, y = btn.y, w = buttonW, h = buttonH}
        if pointIn(x, y, buttonRect.x, buttonRect.y, buttonRect.w, buttonRect.h) then
            btn.action()
            return true, false
        end
    end

    return true, false
end

function EscapeMenu.mousereleased(x, y, button)
    if not EscapeMenu.visible then return false, false end
    if not EscapeMenu.window then return true, false end

    -- If save slots are active, don't handle escape menu clicks
    if EscapeMenu.showSaveSlots then
        return true, false
    end

    if EscapeMenu.window:mousereleased(x, y, button) then
        return true, false
    end

    if SettingsPanel.visible then
        return SettingsPanel.mousereleased(x, y, button)
    end

    local menuX, menuY, menuW, menuH, buttonX, saveButtonY, settingsButtonY, exitButtonY, buttonW, buttonH = getLayout()

    if button == 1 then
        -- Save Game button
        if EscapeMenu.saveButtonDown then
            EscapeMenu.saveButtonDown = false
            if pointIn(x, y, buttonX, saveButtonY, buttonW, buttonH) then
                EscapeMenu.saveSlotMode = "save"
                if EscapeMenu.saveSlotsUI then
                    EscapeMenu.saveSlotsUI:setMode("save")
                end
                EscapeMenu.showSaveSlots = true
                -- Notify UIManager that we're showing save slots
                if _G.UIManager and _G.UIManager.state and _G.UIManager.state.escape then
                    _G.UIManager.state.escape.showingSaveSlots = true
                end
                return true, false
            end
        end

        -- Settings button
        if EscapeMenu.settingsButtonDown then
            EscapeMenu.settingsButtonDown = false
            if pointIn(x, y, buttonX, settingsButtonY, buttonW, buttonH) then
                -- Ensure settings is on top of escape
                SettingsPanel.toggle()
                if _G.UIManager and _G.UIManager.open then
                    _G.UIManager.open("settings")
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
    if not EscapeMenu.window then return true end

    -- If save slots are active, consume movement
    if EscapeMenu.showSaveSlots then
        return true
    end

    if EscapeMenu.window:mousemoved(x, y, dx, dy) then
        return true
    end
    return true
end

function EscapeMenu.keypressed(key)
    if not EscapeMenu.visible then return false end
    
    if SettingsPanel.visible then
        if key == "escape" then
            SettingsPanel.toggle()
            -- Prevent the escape menu from closing immediately
            return true
        end
        return SettingsPanel.keypressed(key)
    end
    

    if key == "escape" then
        EscapeMenu.hide()
        return true
    end
    
    return true -- Consume all keypresses when menu is visible
end

function EscapeMenu.textinput(text)
    if not EscapeMenu.visible then return false end
    
    if SettingsPanel.visible then
        return false -- Let settings panel handle its own text input
    end
    
    
    return true -- Consume all text input when menu is visible
end

return EscapeMenu
