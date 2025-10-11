local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Dropdown = require("src.ui.common.dropdown")
local Strings = require("src.core.strings")
local Settings = require("src.core.settings")
local Log = require("src.core.log")

local GraphicsPanel = {}

local currentSettings

local vsyncTypes = {Strings.getUI("off"), Strings.getUI("on")}
local fpsLimitTypes = {Strings.getUI("unlimited"), "30", "60", "120", "144", "240"}
local windowModeTypes = {"Windowed", "Fullscreen"}
local resolutionTypes = {"1280x720", "1366x768", "1440x900", "1600x900", "1920x1080", "Native"}

local vsyncDropdown
local fpsLimitDropdown
local windowModeDropdown
local resolutionDropdown

local function cloneSettings(src)
    if not src then return {} end
    local copy = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            copy[k] = cloneSettings(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function replaceTableContents(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then return end

    for key in pairs(target) do
        target[key] = nil
    end

    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = cloneSettings(value)
        else
            target[key] = value
        end
    end
end

local function applyGraphicsPreview()
    if not currentSettings then return end

    local ok, err = pcall(function()
        Settings.applyGraphicsSettings(cloneSettings(currentSettings))
    end)

    if not ok then
        if Log and Log.warn then
            Log.warn("GraphicsPanel.applyGraphicsPreview - Failed to apply preview: " .. tostring(err))
        end
        return
    end

    local applied = Settings.getGraphicsSettings()
    if applied then
        replaceTableContents(currentSettings, applied)
    end

    if vsyncDropdown and fpsLimitDropdown and windowModeDropdown and resolutionDropdown then
        -- Ensure dropdown selections reflect any sanitized values from the engine
        vsyncDropdown:setSelectedIndex(currentSettings.vsync and 2 or 1)

        local fpsToIndex = {
            [0] = 1,
            [30] = 2,
            [60] = 3,
            [120] = 4,
            [144] = 5,
            [240] = 6
        }
        local fpsIndex = fpsToIndex[currentSettings.max_fps or 60] or 3
        fpsLimitDropdown:setSelectedIndex(fpsIndex)
        currentSettings.max_fps_index = fpsIndex
        
        -- Set window mode dropdown
        local windowModeToIndex = {
            ["windowed"] = 1,
            ["fullscreen"] = 2
        }
        local windowModeIndex = windowModeToIndex[currentSettings.display_mode or "fullscreen"] or 2
        windowModeDropdown:setSelectedIndex(windowModeIndex)
        
        -- Set resolution dropdown
        local resolution = currentSettings.resolution or {}
        local width = resolution.width or 1920
        local height = resolution.height or 1080
        local resolutionToIndex = {
            [1280] = 1,  -- 1280x720
            [1366] = 2,  -- 1366x768
            [1440] = 3,  -- 1440x900
            [1600] = 4,  -- 1600x900
            [1920] = 5,  -- 1920x1080
        }
        local resolutionIndex = resolutionToIndex[width] or 6 -- Default to Native
        resolutionDropdown:setSelectedIndex(resolutionIndex)
    end
end


local function ensureDropdowns()
    if not vsyncDropdown then
        vsyncDropdown = Dropdown.new({
            x = 0,
            y = 0,
            options = vsyncTypes,
            selectedIndex = 1,
            onSelect = function(index)
                if currentSettings then
                    currentSettings.vsync = (index == 2)
                    applyGraphicsPreview()
                end
            end
        })
    end

    if not fpsLimitDropdown then
        fpsLimitDropdown = Dropdown.new({
            x = 0,
            y = 0,
            options = fpsLimitTypes,
            selectedIndex = 3,
            onSelect = function(index)
                if not currentSettings then return end
                local fpsMap = {
                    [1] = 0,
                    [2] = 30,
                    [3] = 60,
                    [4] = 120,
                    [5] = 144,
                    [6] = 240
                }
                currentSettings.max_fps_index = index
                currentSettings.max_fps = fpsMap[index] or 60
                applyGraphicsPreview()
            end
        })
    end

    if not windowModeDropdown then
        windowModeDropdown = Dropdown.new({
            x = 0,
            y = 0,
            options = windowModeTypes,
            selectedIndex = 2,
            onSelect = function(index)
                if not currentSettings then return end
                local windowModeMap = {
                    [1] = "windowed",
                    [2] = "fullscreen"
                }
                currentSettings.display_mode = windowModeMap[index] or "fullscreen"
                applyGraphicsPreview()
            end
        })
    end

    if not resolutionDropdown then
        resolutionDropdown = Dropdown.new({
            x = 0,
            y = 0,
            options = resolutionTypes,
            selectedIndex = 6, -- Default to Native
            onSelect = function(index)
                if not currentSettings then return end
                local resolutionMap = {
                    [1] = {width = 1280, height = 720},   -- 1280x720
                    [2] = {width = 1366, height = 768},   -- 1366x768
                    [3] = {width = 1440, height = 900},   -- 1440x900
                    [4] = {width = 1600, height = 900},   -- 1600x900
                    [5] = {width = 1920, height = 1080},  -- 1920x1080
                    [6] = "native"  -- Native resolution
                }
                
                if resolutionMap[index] == "native" then
                    -- Use native desktop resolution
                    local desktopWidth, desktopHeight = love.window.getDesktopDimensions()
                    if desktopWidth and desktopHeight then
                        currentSettings.resolution = {width = desktopWidth, height = desktopHeight}
                    end
                else
                    currentSettings.resolution = resolutionMap[index] or {width = 1920, height = 1080}
                end
                applyGraphicsPreview()
                
                -- Force immediate UI update after resolution change
                local UIManager = require("src.core.ui_manager")
                if UIManager and UIManager.resize then
                    local w, h = love.graphics.getDimensions()
                    UIManager.resize(w, h)
                end
            end
        })
    end
end

local function refreshDropdowns()
    if not currentSettings then return end
    ensureDropdowns()

    vsyncDropdown:setSelectedIndex(currentSettings.vsync and 2 or 1)

    local fpsToIndex = {
        [0] = 1,
        [30] = 2,
        [60] = 3,
        [120] = 4,
        [144] = 5,
        [240] = 6
    }
    local idx = fpsToIndex[currentSettings.max_fps or 60] or 3
    currentSettings.max_fps_index = idx
    fpsLimitDropdown:setSelectedIndex(idx)
    
    -- Set window mode dropdown
    local windowModeToIndex = {
        ["windowed"] = 1,
        ["fullscreen"] = 2
    }
    local windowModeIndex = windowModeToIndex[currentSettings.display_mode or "fullscreen"] or 2
    windowModeDropdown:setSelectedIndex(windowModeIndex)
    
    -- Set resolution dropdown
    local resolution = currentSettings.resolution or {}
    local width = resolution.width or 1920
    local height = resolution.height or 1080
    local resolutionToIndex = {
        [1280] = 1,  -- 1280x720
        [1366] = 2,  -- 1366x768
        [1440] = 3,  -- 1440x900
        [1600] = 4,  -- 1600x900
        [1920] = 5,  -- 1920x1080
    }
    local resolutionIndex = resolutionToIndex[width] or 6 -- Default to Native
    resolutionDropdown:setSelectedIndex(resolutionIndex)
end



function GraphicsPanel.init()
    ensureDropdowns()
end

function GraphicsPanel.setSettings(settings)
    currentSettings = settings
    refreshDropdowns()
end

function GraphicsPanel.draw(layout)
    ensureDropdowns()

    local yOffset = layout.yOffset
    local labelX = layout.labelX
    local valueX = layout.valueX
    local itemHeight = layout.itemHeight

    -- Clear cached interactive regions before redrawing
    layout.showFPSCheckbox = nil

    Theme.setColor(Theme.colors.accent)
    love.graphics.setFont(Theme.fonts and (Theme.fonts.normal or Theme.fonts.small) or love.graphics.getFont())
    love.graphics.print("Graphics Settings", labelX, yOffset)
    love.graphics.setFont(layout.settingsFont)
    yOffset = yOffset + 30

    Theme.setColor(Theme.colors.text)
    love.graphics.print((Strings.getUI("vsync") or "VSync") .. ":", labelX, yOffset)
    vsyncDropdown:setPosition(valueX, yOffset - 2 - layout.scrollY)
    yOffset = yOffset + itemHeight

    Theme.setColor(Theme.colors.text)
    love.graphics.print((Strings.getUI("max_fps") or "Max FPS") .. ":", labelX, yOffset)
    fpsLimitDropdown:setPosition(valueX, yOffset - 2 - layout.scrollY)
    yOffset = yOffset + itemHeight

    Theme.setColor(Theme.colors.text)
    love.graphics.print("Window Mode:", labelX, yOffset)
    windowModeDropdown:setPosition(valueX, yOffset - 2 - layout.scrollY)
    yOffset = yOffset + itemHeight

    Theme.setColor(Theme.colors.text)
    love.graphics.print("Resolution:", labelX, yOffset)
    resolutionDropdown:setPosition(valueX, yOffset - 2 - layout.scrollY)
    yOffset = yOffset + itemHeight

    Theme.setColor(Theme.colors.text)
    love.graphics.print("Show FPS:", labelX, yOffset)
    local checkboxX = valueX
    local checkboxY = yOffset - 2 - layout.scrollY
    local checkboxSize = 16
    local hover = layout.mx >= checkboxX and layout.mx <= checkboxX + checkboxSize and layout.scrolledMouseY >= checkboxY and layout.scrolledMouseY <= checkboxY + checkboxSize
    Theme.drawStyledButton(checkboxX, checkboxY, checkboxSize, checkboxSize, currentSettings.show_fps and "✓" or "", hover, love.timer.getTime(), nil, false, { compact = true })
    -- Store the checkbox position (without scroll offset) so interaction code can reuse it
    layout.showFPSCheckbox = {
        x = checkboxX,
        y = yOffset - 2,
        size = checkboxSize
    }
    yOffset = yOffset + itemHeight

    layout.yOffset = yOffset
    return yOffset
end

function GraphicsPanel.drawOverlays()
    -- No overlays needed for simplified graphics panel
end

function GraphicsPanel.drawForeground(mx, my)
    if vsyncDropdown then
        vsyncDropdown:drawButtonOnly(mx, my)
    end
    if fpsLimitDropdown then
        fpsLimitDropdown:drawButtonOnly(mx, my)
    end
    if windowModeDropdown then
        windowModeDropdown:drawButtonOnly(mx, my)
    end
    if resolutionDropdown then
        resolutionDropdown:drawButtonOnly(mx, my)
    end

    if vsyncDropdown then
        vsyncDropdown:drawOptionsOnly(mx, my)
    end
    if fpsLimitDropdown then
        fpsLimitDropdown:drawOptionsOnly(mx, my)
    end
    if windowModeDropdown then
        windowModeDropdown:drawOptionsOnly(mx, my)
    end
    if resolutionDropdown then
        resolutionDropdown:drawOptionsOnly(mx, my)
    end
end

function GraphicsPanel.mousepressed(raw_x, raw_y, button, layout)
    if button ~= 1 then return false end

    -- Check if any of our dropdowns handled the click
    if vsyncDropdown and vsyncDropdown:mousepressed(raw_x, raw_y, button) then return true end
    if fpsLimitDropdown and fpsLimitDropdown:mousepressed(raw_x, raw_y, button) then return true end
    if windowModeDropdown and windowModeDropdown:mousepressed(raw_x, raw_y, button) then return true end
    if resolutionDropdown and resolutionDropdown:mousepressed(raw_x, raw_y, button) then return true end

    -- Check if FPS checkbox was clicked
    if currentSettings and layout and layout.showFPSCheckbox then
        local scrolledMouseY = raw_y + layout.scrollY
        local checkbox = layout.showFPSCheckbox

        if raw_x >= checkbox.x and raw_x <= checkbox.x + checkbox.size and
           scrolledMouseY >= checkbox.y and scrolledMouseY <= checkbox.y + checkbox.size then
            currentSettings.show_fps = not currentSettings.show_fps
            applyGraphicsPreview()
            return true
        end
    end

    return false
end

function GraphicsPanel.mousemoved(x, y)
    if Dropdown.isAnyOpen() then
        if vsyncDropdown then vsyncDropdown:mousemoved(x, y) end
        if fpsLimitDropdown then fpsLimitDropdown:mousemoved(x, y) end
        if windowModeDropdown then windowModeDropdown:mousemoved(x, y) end
        if resolutionDropdown then resolutionDropdown:mousemoved(x, y) end
        return
    end

    if vsyncDropdown then vsyncDropdown:mousemoved(x, y) end
    if fpsLimitDropdown then fpsLimitDropdown:mousemoved(x, y) end
    if windowModeDropdown then windowModeDropdown:mousemoved(x, y) end
    if resolutionDropdown then resolutionDropdown:mousemoved(x, y) end
end

function GraphicsPanel.mousereleased()
    -- No special handling needed for simplified panel
end

function GraphicsPanel.getContentHeight(baseY, itemHeight)
    local yOffset = baseY
    yOffset = yOffset + 30 -- section label
    yOffset = yOffset + itemHeight -- vsync
    yOffset = yOffset + itemHeight -- fps
    yOffset = yOffset + itemHeight -- window mode
    yOffset = yOffset + itemHeight -- resolution
    yOffset = yOffset + itemHeight -- show fps
    return yOffset
end


GraphicsPanel.refreshDropdowns = refreshDropdowns

return GraphicsPanel
