local function formatKey(k)
    local t = type(k)
    if t == "string" then
        -- If valid identifier, use plain form: key = value
        if k:match("^[A-Za-z_][A-Za-z0-9_]*$") then
            return k
        end
        -- Otherwise, quote the key: ["key-with-spaces"] = value
        return string.format("[%q]", k)
    elseif t == "number" then
        -- Numeric keys: [1] = value
        return string.format("[%s]", tostring(k))
    elseif t == "boolean" then
        return string.format("[%s]", tostring(k))
    else
        -- Fallback to quoted string of tostring(k)
        return string.format("[%q]", tostring(k))
    end
end

local function encodeTable(t, indent)
    indent = indent or 0
    local pad = string.rep("    ", indent)
    local s = "{\n"
    for k, v in pairs(t) do
        local keyPart = formatKey(k)
        s = s .. pad .. "    " .. keyPart .. " = "
        if type(v) == "table" then
            s = s .. encodeTable(v, indent + 1)
        elseif type(v) == "string" then
            s = s .. string.format("%q", v)
        else
            s = s .. tostring(v)
        end
        s = s .. ",\n"
    end
    s = s .. pad .. "}"
    return s
end

local function serialize(t)
    return "return " .. encodeTable(t, 0)
end

local Settings = {}

local Log = require("src.core.log")

local IconRenderer = require("src.content.icon_renderer")
local settings = {
  graphics = {
        resolution = {
            width = 1920,
            height = 1080,
        },
        fullscreen = false,
        fullscreen_type = "desktop",
        borderless = false,
        vsync = true,
        max_fps = 60,
        ui_scale = 1.0,
        font_scale = 1.0,
        helpers_enabled = true,
        -- Reticle customization
        reticle_style = 1,            -- 1..50 preset styles
        reticle_color = "accent",     -- legacy string (kept for fallback)
        reticle_color_rgb = nil,      -- custom color {r,g,b,a}
  },
    audio = {
        master_volume = 0.25,
        sfx_volume = 0.25,
        music_volume = 0.25,
    },
    keymap = {
        toggle_inventory = "tab",
        toggle_bounty = "b",
        toggle_skills = "p",
        toggle_map = "m",
        dock = "space",
        -- Combat actions
        dash = "lshift",
        hotbar_1 = "mouse1", -- LMB
        hotbar_2 = "mouse2", -- RMB
        hotbar_3 = "q",
        hotbar_4 = "e",
        hotbar_5 = "r",
    },
    hotbar = {
        items = {
            "turret_slot_1", -- LMB
            "shield",        -- RMB
            nil,              -- Q
            nil,              -- E
            nil,              -- R (new slot)
        }
    }
}

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
    local oldSettings = settings.graphics
    settings.graphics = newSettings

    -- Only change window mode if resolution or fullscreen settings changed
    if not oldSettings or
       oldSettings.resolution.width ~= newSettings.resolution.width or
       oldSettings.resolution.height ~= newSettings.resolution.height or
       (oldSettings.fullscreen ~= newSettings.fullscreen) or
       (oldSettings.fullscreen_type ~= newSettings.fullscreen_type) or
       (oldSettings.borderless ~= newSettings.borderless) or
       (oldSettings.vsync ~= newSettings.vsync) then

        -- Determine window mode settings based on display mode
        -- Use responsive minimum window sizes based on the chosen resolution
        local minWidth, minHeight
        if newSettings.resolution.width <= 800 then
            minWidth = math.max(600, newSettings.resolution.width)
        else
            minWidth = 800
        end

        if newSettings.resolution.height <= 600 then
            minHeight = math.max(400, newSettings.resolution.height)
        else
            minHeight = 600
        end

        print("Settings.applyGraphicsSettings - Using responsive minimum window size: " .. minWidth .. "x" .. minHeight)

        local windowSettings = {
            fullscreen = newSettings.fullscreen,
            fullscreentype = newSettings.fullscreen_type or "desktop",
            borderless = newSettings.borderless or false,
            vsync = newSettings.vsync,
            resizable = true,
            minwidth = minWidth,
            minheight = minHeight
        }

        -- If borderless windowed mode, ensure fullscreen is false
        if newSettings.borderless then
            windowSettings.fullscreen = false
            windowSettings.borderless = true
        end

        print("Settings.applyGraphicsSettings - Applying window mode:")
        print("  Resolution: " .. newSettings.resolution.width .. "x" .. newSettings.resolution.height)
        print("  Fullscreen: " .. tostring(windowSettings.fullscreen))
        print("  Fullscreen type: " .. (windowSettings.fullscreentype or "nil"))
        print("  Borderless: " .. tostring(windowSettings.borderless))
        print("  VSync: " .. tostring(windowSettings.vsync))

        love.window.setMode(
            newSettings.resolution.width,
            newSettings.resolution.height,
            windowSettings
        )

        print("Settings.applyGraphicsSettings - Window mode applied successfully")

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

function Settings.getKeymap()
    return settings.keymap
end

function Settings.setKeyBinding(action, key)
    settings.keymap[action] = key
end

function Settings.getHotbarSettings()
    return settings.hotbar
end

function Settings.setHotbarSettings(newSettings)
    settings.hotbar = newSettings
end

function Settings.save()
    print("Settings.save - Saving settings to file")
    local serializedSettings = serialize(settings)
    local success = love.filesystem.write("settings.lua", serializedSettings)
    if success then
        print("Settings.save - Settings saved successfully")
    else
        print("Settings.save - Failed to save settings")
    end
    return success
end

function Settings.load()
    if love.filesystem.getInfo("settings.lua") then
        print("Settings.load - Loading settings from file")
        local chunk, err = love.filesystem.load("settings.lua")
        if chunk then
            local success, loadedSettings = pcall(chunk)
            if success and loadedSettings then
                settings = loadedSettings
                print("Settings.load - Settings loaded successfully")
                print("Settings.load - Loaded fullscreen: " .. tostring(settings.graphics.fullscreen))
                print("Settings.load - Loaded fullscreen_type: " .. (settings.graphics.fullscreen_type or "nil"))
                print("Settings.load - Loaded resolution: " .. settings.graphics.resolution.width .. "x" .. settings.graphics.resolution.height)
                Log.info("Settings loaded successfully")
            else
                print("Settings.load - Failed to load settings: " .. tostring(loadedSettings))
                Log.warn("Failed to load settings: " .. tostring(loadedSettings))
            end
        else
            print("Settings.load - Failed to load settings file: " .. tostring(err))
            Log.warn("Failed to load settings file: " .. tostring(err))
        end
    else
        print("Settings.load - No settings file found, using defaults")
        print("Settings.load - Default fullscreen: " .. tostring(settings.graphics.fullscreen))
        print("Settings.load - Default resolution: " .. settings.graphics.resolution.width .. "x" .. settings.graphics.resolution.height)
    end
end

return Settings
