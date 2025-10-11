local WindowMode = {}

local Log = require("src.core.log")
local Constants = require("src.core.constants")

local function computeMinimumDimensions(width, height)
    local minWidth
    if width <= Constants.RESOLUTION.MIN_WINDOW_WIDTH_800PX then
        minWidth = math.max(Constants.RESOLUTION.MIN_WINDOW_WIDTH_800PX, width)
    else
        minWidth = Constants.RESOLUTION.MIN_WINDOW_WIDTH_1024PX
    end

    local minHeight
    if height <= Constants.RESOLUTION.MIN_WINDOW_HEIGHT_800PX then
        minHeight = math.max(Constants.RESOLUTION.MIN_WINDOW_HEIGHT_800PX, height)
    else
        minHeight = Constants.RESOLUTION.MIN_WINDOW_HEIGHT_1024PX
    end

    return minWidth, minHeight
end

function WindowMode.apply(graphicsSettings)
    if not love or not love.window or not love.window.setMode then
        if Log and Log.warn then
            Log.warn("WindowMode.apply - love.window.setMode is unavailable")
        end
        return false, "love.window.setMode unavailable"
    end

    if not graphicsSettings or not graphicsSettings.resolution then
        if Log and Log.warn then
            Log.warn("WindowMode.apply - Missing graphics settings or resolution")
        end
        return false, "invalid graphics settings"
    end

    local width = graphicsSettings.resolution.width
    local height = graphicsSettings.resolution.height

    local minWidth, minHeight = computeMinimumDimensions(width, height)

    Log.debug("WindowMode.apply - Using minimum window size: " .. minWidth .. "x" .. minHeight)

    -- Determine display mode based on display_mode setting
    local displayMode = graphicsSettings.display_mode or "borderless_fullscreen"
    local isFullscreen = false
    local isBorderless = false
    local fullscreenType = "desktop"
    
    if displayMode == "borderless_fullscreen" then
        -- For borderless fullscreen, we want true fullscreen to respect resolution changes
        isFullscreen = true
        isBorderless = false
        fullscreenType = "desktop" -- Use desktop fullscreen to allow resolution changes
    elseif displayMode == "windowed" then
        isFullscreen = false
        isBorderless = false
    else
        -- Fallback to legacy settings for backward compatibility
        isFullscreen = graphicsSettings.fullscreen
        isBorderless = graphicsSettings.borderless or false
        fullscreenType = graphicsSettings.fullscreen_type or "desktop"
    end

    local windowSettings = {
        fullscreen = isFullscreen,
        fullscreentype = fullscreenType,
        borderless = isBorderless,
        vsync = graphicsSettings.vsync,
        resizable = not isFullscreen, -- Don't allow resizing in fullscreen
        minwidth = minWidth,
        minheight = minHeight,
    }

    Log.debug("WindowMode.apply - Applying window mode:")
    Log.debug("  Resolution: " .. width .. "x" .. height)
    Log.debug("  Display Mode: " .. displayMode)
    Log.debug("  Fullscreen: " .. tostring(windowSettings.fullscreen))
    Log.debug("  Fullscreen type: " .. (windowSettings.fullscreentype or "nil"))
    Log.debug("  Borderless: " .. tostring(windowSettings.borderless))
    Log.debug("  Resizable: " .. tostring(windowSettings.resizable))
    Log.debug("  VSync: " .. tostring(windowSettings.vsync))

    local ok, err = pcall(love.window.setMode, width, height, windowSettings)

    if not ok then
        if Log and Log.warn then
            Log.warn("WindowMode.apply - Failed to apply window mode: " .. tostring(err))
        end
        return false, err
    end

    Log.debug("WindowMode.apply - Window mode applied successfully")
    return true
end

return WindowMode
