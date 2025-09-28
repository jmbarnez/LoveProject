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
        return string.format("[%d]", k)
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

    -- First pass: handle array-like entries (numeric indices)
    local maxIndex = 0
    for k in pairs(t) do
        if type(k) == "number" then
            maxIndex = math.max(maxIndex, k)
        end
    end

    -- Add array-like entries
    for i = 1, maxIndex do
        local v = t[i]
        if v == nil then
            s = s .. pad .. "    nil,\n"
        else
            s = s .. pad .. "    "
            if type(v) == "table" then
                s = s .. encodeTable(v, indent + 1)
            elseif type(v) == "string" then
                s = s .. string.format("%q", v)
            else
                s = s .. tostring(v)
            end
            s = s .. ",\n"
        end
    end

    -- Second pass: handle non-array entries (string keys, boolean keys, etc.)
    for k, v in pairs(t) do
        if type(k) ~= "number" or k < 1 or k > maxIndex or math.floor(k) ~= k then
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
    end

    s = s .. pad .. "}"
    return s
end

local function serialize(t)
    return "return " .. encodeTable(t, 0)
end

local Settings = {}

local Log = require("src.core.log")
local Constants = require("src.core.constants")

local IconRenderer = require("src.content.icon_renderer")
local settings = {
  graphics = {
        resolution = {
            width = Constants.RESOLUTION.DEFAULT_WIDTH,
            height = Constants.RESOLUTION.DEFAULT_HEIGHT,
        },
        fullscreen = false,
        fullscreen_type = "desktop",
        borderless = false,
        vsync = true,
        max_fps = Constants.TIMING.FPS_60,
        ui_scale = 1.0,
        font_scale = 1.0,
        helpers_enabled = true,
        -- Reticle customization
        reticle_style = 1,            -- 1..50 preset styles
        reticle_color = "accent",     -- legacy string (kept for fallback)
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
        toggle_bounty = { primary = "b" },
        toggle_skills = { primary = "p" },
        toggle_map = { primary = "m" },
        dock = { primary = "space" },
        repair_beacon = { primary = "r" },
        -- Combat actions
        dash = { primary = "lshift" },
        hotbar_1 = { primary = "mouse1" }, -- LMB
        hotbar_2 = { primary = "mouse2" }, -- RMB
        hotbar_3 = { primary = "q" },
        hotbar_4 = { primary = "e" },
        hotbar_5 = { primary = "r" },
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
        if newSettings.resolution.width <= Constants.RESOLUTION.MIN_WINDOW_WIDTH_800PX then
            minWidth = math.max(Constants.RESOLUTION.MIN_WINDOW_WIDTH_800PX, newSettings.resolution.width)
        else
            minWidth = Constants.RESOLUTION.MIN_WINDOW_WIDTH_1024PX
        end

        if newSettings.resolution.height <= Constants.RESOLUTION.MIN_WINDOW_HEIGHT_800PX then
            minHeight = math.max(Constants.RESOLUTION.MIN_WINDOW_HEIGHT_800PX, newSettings.resolution.height)
        else
            minHeight = Constants.RESOLUTION.MIN_WINDOW_HEIGHT_1024PX
        end

        Log.debug("Settings.applyGraphicsSettings - Using responsive minimum window size: " .. minWidth .. "x" .. minHeight)

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

        Log.debug("Settings.applyGraphicsSettings - Applying window mode:")
        Log.debug("  Resolution: " .. newSettings.resolution.width .. "x" .. newSettings.resolution.height)
        Log.debug("  Fullscreen: " .. tostring(windowSettings.fullscreen))
        Log.debug("  Fullscreen type: " .. (windowSettings.fullscreentype or "nil"))
        Log.debug("  Borderless: " .. tostring(windowSettings.borderless))
        Log.debug("  VSync: " .. tostring(windowSettings.vsync))

        love.window.setMode(
            newSettings.resolution.width,
            newSettings.resolution.height,
            windowSettings
        )

        Log.debug("Settings.applyGraphicsSettings - Window mode applied successfully")

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
    -- Settings saving is disabled - don't save to filesystem
    Log.debug("Settings.save - Settings saving disabled, using defaults only")
    return true
end

function Settings.load()
    -- Always use default settings - don't load from filesystem
    Log.debug("Settings.load - Using default settings (saving/loading disabled)")
    Log.debug("Settings.load - Default fullscreen: " .. tostring(settings.graphics.fullscreen))
    Log.debug("Settings.load - Default resolution: " .. settings.graphics.resolution.width .. "x" .. settings.graphics.resolution.height)
end

return Settings
