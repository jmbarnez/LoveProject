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

local vsyncDropdown
local fpsLimitDropdown

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

    if vsyncDropdown and fpsLimitDropdown then
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

    if vsyncDropdown then
        vsyncDropdown:drawOptionsOnly(mx, my)
    end
    if fpsLimitDropdown then
        fpsLimitDropdown:drawOptionsOnly(mx, my)
    end
end

function GraphicsPanel.mousepressed(raw_x, raw_y, button)
    if button ~= 1 then return false end

    -- Check if any of our dropdowns handled the click
    if vsyncDropdown and vsyncDropdown:mousepressed(raw_x, raw_y, button) then return true end
    if fpsLimitDropdown and fpsLimitDropdown:mousepressed(raw_x, raw_y, button) then return true end

    return false
end

function GraphicsPanel.mousemoved(x, y)
    if Dropdown.isAnyOpen() then
        if vsyncDropdown then vsyncDropdown:mousemoved(x, y) end
        if fpsLimitDropdown then fpsLimitDropdown:mousemoved(x, y) end
        return
    end

    if vsyncDropdown then vsyncDropdown:mousemoved(x, y) end
    if fpsLimitDropdown then fpsLimitDropdown:mousemoved(x, y) end
end

function GraphicsPanel.mousereleased()
    -- No special handling needed for simplified panel
end

function GraphicsPanel.getContentHeight(baseY, itemHeight)
    local yOffset = baseY
    yOffset = yOffset + 30 -- section label
    yOffset = yOffset + itemHeight -- vsync
    yOffset = yOffset + itemHeight -- fps
    return yOffset
end

GraphicsPanel.refreshDropdowns = refreshDropdowns

return GraphicsPanel
