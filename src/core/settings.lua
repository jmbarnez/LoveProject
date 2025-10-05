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
            width = 1600,
            height = 900,
        },
        fullscreen = false,
        fullscreen_type = "desktop",
        borderless = false,
        vsync = true,
        max_fps = Constants.TIMING.FPS_60,
        font_scale = 1.0,
        show_fps = false,
        -- Reticle customization
        reticle_style = 1,            -- 1..50 preset styles
        reticle_color = "cyan",       -- bright blue reticle by default
        reticle_color_rgb = nil,      -- custom color {r,g,b,a}
        -- UI cursor customization
        ui_cursor_color = "accent",   -- legacy string (kept for fallback)
        ui_cursor_color_rgb = nil,    -- custom color {r,g,b,a}
  },
    audio = {
        master_volume = 0.25,
        sfx_volume = 0.25,
        music_volume = 0.25,
    },
    keymap = {
        toggle_inventory = { primary = "tab" },
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
    local oldSettings = Util.deepCopy(settings.graphics)
    settings.graphics = newSettings

    -- Only change window mode if resolution or fullscreen settings changed
    if not oldSettings or
       oldSettings.resolution.width ~= newSettings.resolution.width or
       oldSettings.resolution.height ~= newSettings.resolution.height or
       (oldSettings.fullscreen ~= newSettings.fullscreen) or
       (oldSettings.fullscreen_type ~= newSettings.fullscreen_type) or
       (oldSettings.borderless ~= newSettings.borderless) or
       (oldSettings.vsync ~= newSettings.vsync) then

        local success, err = WindowMode.apply(newSettings)
        if not success then
            if Log and Log.warn then
                Log.warn("Settings.applyGraphicsSettings - Failed to apply window mode: " .. tostring(err))
            end
            settings.graphics = oldSettings
            if Log and Log.warn then
                Log.warn("Settings.applyGraphicsSettings - Rolling back to previous graphics settings")
            end
            return
        end

        IconRenderer.clearCache()
        local Content = require("src.content.content")
        Content.rebuildIcons()

        -- Trigger a resize event to update UI elements
        local success, err = pcall(function()
            if love.handlers and love.handlers.resize then
                love.handlers.resize(newSettings.resolution.width, newSettings.resolution.height)
            end
        end)
        if not success and Log and Log.warn then
            Log.warn("Failed to trigger resize event: " .. tostring(err))
        end
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
        Log.error("Settings.save - Failed to save settings to " .. filename .. ": " .. tostring(err))
    else
        Log.info("Settings.save - Settings saved successfully.")
    end

    return success
end

function Settings.load()
    local filename = "settings.json"
    if not love.filesystem.getInfo(filename) then
        Log.info("Settings.load - No settings file found, using defaults.")
        -- First time running, save the defaults
        Settings.save()
        return
    end

    local data, size = love.filesystem.read(filename)
    if not data then
        Log.error("Settings.load - Could not read settings file: " .. filename)
        return
    end
    
    local json = require("src.libs.json")
    local ok, loadedSettings = pcall(json.decode, data)

    if not ok then
        Log.error("Settings.load - Failed to parse settings.json: " .. tostring(loadedSettings))
        return
    end

    -- Deep merge loaded settings over defaults to ensure new defaults are applied
    -- while preserving user's existing settings.
    local function deepMerge(defaults, custom)
        local new = {}
        for k, v in pairs(defaults) do
            if type(v) == "table" and custom and custom[k] and type(custom[k]) == "table" then
                new[k] = deepMerge(v, custom[k])
            else
                new[k] = (custom and custom[k]) or v
            end
        end
        return new
    end
    
    settings = deepMerge(defaultSettings, loadedSettings)
    Log.info("Settings.load - Settings loaded successfully from " .. filename)
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
