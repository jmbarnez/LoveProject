local Settings = {}

local Log = require("src.core.log")
local Constants = require("src.core.constants")
local Util = require("src.core.util")
local WindowMode = require("src.core.window_mode")

local IconRenderer = require("src.content.icon_renderer")
local defaultSettings = {} -- Will be populated with the initial settings
local settings = {
  graphics = {
        resolution = {
            width = 1920,
            height = 1080,
        },
        fullscreen = true,
        fullscreen_type = "desktop",
        borderless = false,
        vsync = true,
        max_fps = Constants.TIMING.FPS_60,
        font_scale = 1.0,
        show_fps = false,
        -- Crosshair customization
        crosshair_style = 1,            -- 1..50 preset styles
        crosshair_color = "cyan",       -- bright blue crosshair by default
        crosshair_color_rgb = {0.0, 1.0, 1.0, 1.0}, -- cyan {r,g,b,a}
  },
    audio = {
        master_volume = 0.25,
        sfx_volume = 0.25,
        music_volume = 0.25,
    },
    keymap = {
        toggle_cargo = { primary = "tab" },
        toggle_ship = { primary = "g" },
        toggle_skills = { primary = "p" },
        toggle_map = { primary = "m" },
        repair_beacon = { primary = "r" },
        -- Combat actions
        dash = { primary = "lshift" },
        hotbar_1 = { primary = "mouse1" }, -- LMB
        hotbar_2 = { primary = "mouse2" }, -- RMB
        hotbar_3 = { primary = "q" },
        hotbar_4 = { primary = "e" },
        hotbar_5 = { primary = "r" },
        hotbar_6 = { primary = "t" },
        hotbar_7 = { primary = "f" },
    },
    hotbar = {
        items = {
            "turret_slot_1", -- LMB
            "shield",        -- RMB
            nil,              -- Q
            nil,              -- E
            nil,              -- R
            nil,              -- T
            nil,              -- F
        }
    },
    networking = {
        host_authoritative_enemies = false,  -- Feature flag for host-authoritative enemy combat (disabled until fully implemented)
        host_authoritative_projectiles = false  -- Feature flag for host-authoritative projectile combat (disabled until fully implemented)
    }
}

local function detectNativeResolution()
    if not love or not love.window then return nil end

    local displayIndex = 1
    if love.window.getDisplay then
        local ok, currentDisplay = pcall(love.window.getDisplay)
        if ok and type(currentDisplay) == "number" and currentDisplay >= 1 then
            displayIndex = currentDisplay
        end
    end

    if love.window.getDesktopDimensions then
        local ok, width, height = pcall(love.window.getDesktopDimensions, displayIndex)
        if ok and type(width) == "number" and type(height) == "number" and width > 0 and height > 0 then
            return width, height
        end
    end

    if love.window.getMode then
        local ok, width, height = pcall(love.window.getMode)
        if ok and type(width) == "number" and type(height) == "number" and width > 0 and height > 0 then
            return width, height
        end
    end

    return nil
end

do
    local nativeWidth, nativeHeight = detectNativeResolution()
    if nativeWidth and nativeHeight then
        settings.graphics.resolution.width = nativeWidth
        settings.graphics.resolution.height = nativeHeight
    end
end

defaultSettings = Util.deepCopy(settings)

function Settings.getGraphicsSettings()
    return settings.graphics
end

function Settings.getAvailableResolutions()
    if not love.window then
        return { { width = settings.graphics.resolution.width, height = settings.graphics.resolution.height } }
    end

    local resolutions = love.window.getFullscreenModes()
    local uniqueResolutions = {}
    local seen = {}
    for i = #resolutions, 1, -1 do
        local res = resolutions[i]
        local key = res.width .. "x" .. res.height
        if not seen[key] then
            table.insert(uniqueResolutions, res)
            seen[key] = true
        end
    end
    table.sort(uniqueResolutions, function(a, b)
        if a.width == b.width then
            return a.height < b.height
        end
        return a.width < b.width
    end)
    return uniqueResolutions
end

function Settings.applyGraphicsSettings(newSettings)
    if type(newSettings) ~= "table" then
        return
    end

    local oldSettings = Util.deepCopy(settings.graphics)

    local function mergeTables(base, overrides)
        local result = Util.deepCopy(base or {})

        if type(overrides) ~= "table" then
            return result
        end

        for key, value in pairs(overrides) do
            if type(value) == "table" then
                local baseValue = result[key]
                if type(baseValue) == "table" then
                    result[key] = mergeTables(baseValue, value)
                else
                    result[key] = mergeTables({}, value)
                end
            else
                result[key] = value
            end
        end

        return result
    end

    local defaults = defaultSettings and defaultSettings.graphics or {}
    local base = oldSettings or defaults
    local sanitized = mergeTables(base, newSettings)

    if type(sanitized.resolution) ~= "table" then
        sanitized.resolution = Util.deepCopy(base.resolution or defaults.resolution or {})
    end

    sanitized.resolution.width = tonumber(sanitized.resolution.width) or
        (base.resolution and base.resolution.width) or
        (defaults.resolution and defaults.resolution.width) or
        Constants.RESOLUTION.DEFAULT_WIDTH

    sanitized.resolution.height = tonumber(sanitized.resolution.height) or
        (base.resolution and base.resolution.height) or
        (defaults.resolution and defaults.resolution.height) or
        Constants.RESOLUTION.DEFAULT_HEIGHT

    settings.graphics = sanitized

    -- Only change window mode if resolution or fullscreen settings changed
    local oldResolution = oldSettings and oldSettings.resolution or {}
    if not oldSettings or
       (oldResolution.width ~= sanitized.resolution.width) or
       (oldResolution.height ~= sanitized.resolution.height) or
       ((oldSettings.fullscreen or false) ~= (sanitized.fullscreen or false)) or
       ((oldSettings.fullscreen_type) ~= (sanitized.fullscreen_type)) or
       ((oldSettings.borderless or false) ~= (sanitized.borderless or false)) or
       (oldSettings.vsync ~= sanitized.vsync) then

        local success, err = WindowMode.apply(sanitized)
        if not success then
            settings.graphics = oldSettings
            return
        end

        IconRenderer.clearCache()
        local Content = require("src.content.content")
        Content.rebuildIcons()

        -- Trigger a resize event to update UI elements
        pcall(function()
            if love.handlers and love.handlers.resize then
                love.handlers.resize(sanitized.resolution.width, sanitized.resolution.height)
            elseif love.resize then
                love.resize(sanitized.resolution.width, sanitized.resolution.height)
            end
        end)
    end

    -- Update FPS limit in main.lua if the function exists
    if _G.updateFPSLimit then
        _G.updateFPSLimit()
    end
end

function Settings.getAudioSettings()
    return settings.audio
end

function Settings.applyAudioSettings(newSettings)
    settings.audio = newSettings
    -- You might need to call a function in your sound manager to apply these settings
    local Sound = require("src.core.sound")
    if Sound and Sound.applySettings then
        Sound.applySettings()
    end
end

function Settings.applySettings(graphicsSettings, audioSettings)
    if graphicsSettings then
        Settings.applyGraphicsSettings(graphicsSettings)
    end
    if audioSettings then
        Settings.applyAudioSettings(audioSettings)
    end
end

local function ensureBindingTable(action)
    local binding = settings.keymap[action]
    if binding == nil then
        binding = {}
        settings.keymap[action] = binding
    elseif type(binding) ~= "table" then
        binding = { primary = binding }
        settings.keymap[action] = binding
    end
    return binding
end

local function flattenKeymap()
    local flattened = {}
    for action, binding in pairs(settings.keymap) do
        if type(binding) == "table" then
            flattened[action] = binding.primary
        else
            flattened[action] = binding
        end
    end
    return flattened
end

function Settings.getKeymap()
    return flattenKeymap()
end

function Settings.getBinding(action)
    local binding = settings.keymap[action]
    if binding == nil then
        return nil
    end
    if type(binding) ~= "table" then
        binding = { primary = binding }
        settings.keymap[action] = binding
    end
    return binding
end

function Settings.getBindingValue(action, slot)
    local binding = Settings.getBinding(action)
    if not binding then return nil end
    local key = slot or "primary"
    return binding[key]
end

function Settings.setKeyBinding(action, key, slot)
    local binding = ensureBindingTable(action)
    binding[slot or "primary"] = key
end

function Settings.getHotbarSettings()
    return settings.hotbar
end

function Settings.setHotbarSettings(newSettings)
    settings.hotbar = newSettings
end

function Settings.save()
    local filename = "settings.json"
    local json = require("src.libs.json")
    local data = json.encode(settings)
    local success, err = love.filesystem.write(filename, data)

    if not success then
    else
    end

    return success
end

function Settings.load()
    local filename = "settings.json"
    if not love.filesystem.getInfo(filename) then
        -- First time running, save the defaults
        Settings.save()
        return
    end

    local data, size = love.filesystem.read(filename)
    if not data then
        return
    end
    
    local json = require("src.libs.json")
    local ok, loadedSettings = pcall(json.decode, data)

    if not ok then
        return
    end

    -- Deep merge loaded settings over defaults to ensure new defaults are applied
    -- while preserving user's existing settings for known keys only. Unknown/deprecated
    -- keys from the saved settings are intentionally dropped.
    local function deepMerge(defaults, custom)
        if type(defaults) ~= "table" then
            if custom ~= nil then
                return Util.deepCopy(custom)
            end
            return defaults
        end

        local result = {}
        local customTable = type(custom) == "table" and custom or nil

        for key, value in pairs(defaults) do
            local override = customTable and customTable[key] or nil
            if type(value) == "table" then
                if type(override) == "table" then
                    result[key] = deepMerge(value, override)
                elseif override ~= nil then
                    result[key] = Util.deepCopy(override)
                else
                    result[key] = deepMerge(value, nil)
                end
            else
                if override ~= nil then
                    result[key] = override
                else
                    result[key] = value
                end
            end
        end

        return result
    end
    
    settings = deepMerge(defaultSettings, loadedSettings)
end

function Settings.getDefaultSettings()
    return Util.deepCopy(defaultSettings)
end

function Settings.getDefaultGraphicsSettings()
    return Util.deepCopy(defaultSettings.graphics)
end

function Settings.getDefaultAudioSettings()
    return Util.deepCopy(defaultSettings.audio)
end

function Settings.getDefaultKeymap()
    return Util.deepCopy(defaultSettings.keymap)
end

function Settings.getNetworkingSettings()
    return settings.networking
end

function Settings.setNetworkingSettings(newSettings)
    settings.networking = newSettings
end

function Settings.getDefaultNetworkingSettings()
    return Util.deepCopy(defaultSettings.networking)
end

return Settings
