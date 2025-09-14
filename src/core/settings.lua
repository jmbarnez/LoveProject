local function serialize(t)
    local s = "return {\n"
    for k, v in pairs(t) do
        s = s .. "    " .. k .. " = "
        if type(v) == "table" then
            s = s .. serialize(v)
        elseif type(v) == "string" then
            s = s .. string.format("%q", v)
        else
            s = s .. tostring(v)
        end
        s = s .. ",\n"
    end
    s = s .. "}"
    return s
end

local Settings = {}

local Log = require("src.core.log")

local settings = {
  graphics = {
        resolution = {
            width = 1920,
            height = 1080,
        },
        fullscreen = false,
        fullscreen_type = "desktop",
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
    settings.graphics = newSettings
    love.window.setMode(
        newSettings.resolution.width,
        newSettings.resolution.height,
        {
            fullscreen = newSettings.fullscreen,
            fullscreentype = newSettings.fullscreen_type,
            vsync = newSettings.vsync,
            resizable = true,
            minwidth = 1024,
            minheight = 576,
        }
    )
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
    local serializedSettings = serialize(settings)
    love.filesystem.write("settings.lua", serializedSettings)
end

function Settings.load()
    local ok, fileContent = pcall(love.filesystem.read, "settings.lua")
    if not ok then
        if Log and Log.warn then Log.warn("Settings.load: failed to read settings.lua") end
        return
    end
    if not fileContent or #fileContent == 0 then
        return
    end

    local func, err = loadstring(fileContent)
    if not func then
        if Log and Log.error then Log.error("Settings.load: invalid settings.lua:", tostring(err)) end
        return
    end

    local ok2, loadedSettings = pcall(func)
    if not ok2 then
        if Log and Log.error then Log.error("Settings.load: executing settings.lua failed:", tostring(loadedSettings)) end
        return
    end
    if type(loadedSettings) ~= "table" then
        if Log and Log.error then Log.error("Settings.load: settings.lua did not return a table") end
        return
    end

    -- Deep merge loaded settings into default settings
    for k, v in pairs(loadedSettings) do
        if type(v) == "table" and type(settings[k]) == "table" then
            for k2, v2 in pairs(v) do
                if settings[k] then
                    settings[k][k2] = v2
                end
            end
        else
            settings[k] = v
        end
    end
end

return Settings
