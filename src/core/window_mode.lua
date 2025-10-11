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

    if not graphicsSettings then
        if Log and Log.warn then
            Log.warn("WindowMode.apply - Missing graphics settings")
        end
        return false, "invalid graphics settings"
    end

    -- Use resolution from settings if available, otherwise get current window dimensions
    local width, height
    if graphicsSettings.resolution and graphicsSettings.resolution.width and graphicsSettings.resolution.height then
        width = graphicsSettings.resolution.width
        height = graphicsSettings.resolution.height
    else
        -- Get current window dimensions or use native desktop resolution
        width, height = love.window.getMode()
        if not width or not height then
            -- Get native desktop resolution
            local desktopWidth, desktopHeight = love.window.getDesktopDimensions()
            if desktopWidth and desktopHeight then
                width = desktopWidth
                height = desktopHeight
            else
                -- Fallback to common resolution
                width = 1920
                height = 1080
            end
        end
    end

    local minWidth, minHeight = computeMinimumDimensions(width, height)

    Log.debug("WindowMode.apply - Using minimum window size: " .. minWidth .. "x" .. minHeight)

    -- Determine display mode based on display_mode setting
    local displayMode = graphicsSettings.display_mode or "fullscreen"
    local isFullscreen = false
    local isBorderless = false
    local fullscreenType = "desktop"
    
    if displayMode == "fullscreen" then
        isFullscreen = true
        isBorderless = false
        fullscreenType = "desktop"
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

    -- Try to use updateMode for immediate changes, fallback to setMode
    local ok, err
    if love.window.updateMode then
        ok, err = pcall(love.window.updateMode, width, height, windowSettings)
        if not ok then
            Log.debug("WindowMode.apply - updateMode failed, falling back to setMode")
            ok, err = pcall(love.window.setMode, width, height, windowSettings)
        end
    else
        ok, err = pcall(love.window.setMode, width, height, windowSettings)
    end

    if not ok then
        if Log and Log.warn then
            Log.warn("WindowMode.apply - Failed to apply window mode: " .. tostring(err))
        end
        return false, err
    end

    -- Immediately sync viewport with new resolution
    local Viewport = require("src.core.viewport")
    if Viewport and Viewport.resize then
        Viewport.resize(width, height)
        -- Ensure viewport stays within bounds
        if Viewport.ensureBounds then
            Viewport.ensureBounds()
        end
    end

    Log.debug("WindowMode.apply - Window mode applied successfully")
    return true
end

return WindowMode
