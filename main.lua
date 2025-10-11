-- main.lua
-- Entry point for the game. Initializes modules, handles the main loop, and manages screen transitions

-- =============================================================================
-- CORE MODULES - Always loaded at startup (critical dependencies)
-- =============================================================================
local Constants = require("src.core.constants")
local Log = require("src.core.log")
local Settings = require("src.core.settings")
local Input = require("src.core.input")
local Viewport = require("src.core.viewport")
local WindowMode = require("src.core.window_mode")
local Sound = require("src.core.sound")
local ModuleRegistry = require("src.core.module_registry")

-- =============================================================================
-- LAZY-LOADED MODULES - Loaded on demand to reduce startup time
-- =============================================================================
ModuleRegistry.registerMany({
    Game = function() return require("src.game") end,
    StartScreen = function() return require("src.ui.start_screen") end,
    SettingsPanel = function() return require("src.ui.settings_panel") end,
    DebugPanel = function() return require("src.ui.debug_panel") end,
    LoadingScreen = function() return require("src.ui.loading_screen") end,
    UIManager = function() return require("src.core.ui_manager") end,
    Theme = function() return require("src.core.theme") end,
})

-- =============================================================================
-- PERFORMANCE PROFILING - Track startup and runtime performance
-- =============================================================================
local startupProfile = {
    startTime = nil,
    milestones = {},
    lazyLoadTimes = {}
}

local function recordMilestone(name)
    startupProfile.milestones[name] = love.timer.getTime()
    local elapsed = startupProfile.milestones[name] - (startupProfile.startTime or startupProfile.milestones[name])
    Log.debug(string.format("Startup milestone '%s': %.3fms", name, elapsed * 1000))
end

-- =============================================================================
-- LAZY LOADING HELPER - Load modules on first access with profiling
-- =============================================================================
local function getModule(name)
    local module = ModuleRegistry.get(name, function(loadTime)
        if not loadTime then
            return
        end

        startupProfile.lazyLoadTimes[name] = loadTime
        Log.debug(string.format("Lazy-loaded module '%s': %.3fms", name, loadTime))
    end)

    return module
end

local function logStartupProfile()
    local totalTime = (love.timer.getTime() - startupProfile.startTime) * 1000
    Log.info(string.format("=== STARTUP PROFILE (Total: %.2fms) ===", totalTime))

    -- Log milestones
    local prevTime = startupProfile.startTime
    for name, time in pairs(startupProfile.milestones) do
        local elapsed = (time - prevTime) * 1000
        Log.info(string.format("  %s: %.2fms", name, elapsed))
        prevTime = time
    end

    -- Log lazy loading times
    local totalLazyTime = 0
    for name, time in pairs(startupProfile.lazyLoadTimes) do
        totalLazyTime = totalLazyTime + time
        Log.info(string.format("  Lazy load %s: %.2fms", name, time))
    end

    if totalLazyTime > 0 then
        Log.info(string.format("  Total lazy load time: %.2fms (%.1f%% of startup)",
            totalLazyTime, (totalLazyTime / totalTime) * 100))
    end
end

--[[
    The main module is responsible for orchestrating high-level state changes
    between the start menu, the async loading overlay, and the in-game UI
    manager. It wires Love2D callbacks so that lower-level systems can focus on
    their specific domains (input, rendering, UI, etc.) while keeping the
    transition logic in one place.
]]

local UIManager
local screen = "start"
local startScreen
local loadingScreen

local minFrameTime = 1 / Constants.TIMING.FPS_60
local lastFrameTime = 0

--[[
    configureInput

    Rebuilds the input callback bindings whenever the active screen changes.
    This keeps the Input module decoupled from the main Love2D callbacks while
    still giving it the necessary context (current screen, UI references, and
    the loading overlay).
]]
local function configureInput()
    Input.init_love_callbacks({
        screen = screen,
        startScreen = startScreen,
        UIManager = UIManager,
        setScreen = love.setScreen,
        loadingScreen = loadingScreen,
    })
end

love = love or {}
function love.setScreen(newScreen)
    local previousScreen = screen
    if previousScreen == newScreen then
        return
    end

    screen = newScreen

    if newScreen == "start" then
        if previousScreen == "game" then
            local Game = getModule("Game")
            if Game and Game.unload then
                Game.unload()
            end
        end
        startScreen = getModule("StartScreen").new()
        love.mouse.setVisible(false)
        if love.mouse and love.mouse.setRelativeMode then
            love.mouse.setRelativeMode(false)
        end
        Sound.playMusic("adrift")
        ModuleRegistry.clear("UIManager")  -- Clear cached UIManager
    elseif newScreen == "game" then
        UIManager = getModule("UIManager")
        if love.mouse and love.mouse.setVisible then
            love.mouse.setVisible(false)
        end
        -- Force viewport sync when entering game mode to prevent flicker
        Viewport.syncWithWindow()
    end

    configureInput()
end

--[[
    Update the minimum frame time based on the user's graphics settings. The
    value is consumed inside love.update to throttle the main loop and provide
    a coarse frame limiter without pulling in an additional scheduler.
]]
function updateFPSLimit()
  local graphicsSettings = Settings.getGraphicsSettings()
  minFrameTime = (graphicsSettings.max_fps and graphicsSettings.max_fps > 0) and (1 / graphicsSettings.max_fps) or 0
end

-- =============================================================================
-- GRAPHICS SETTINGS MANAGEMENT - Simplified and more maintainable
-- =============================================================================

local function normalizeVsync(value)
    if value == nil then return nil end
    if type(value) == "number" then return value ~= 0 end
    if type(value) == "boolean" then return value end
    return value
end

local function getCurrentWindowMode()
    local ok, width, height, flags = pcall(love.window.getMode)
    if not ok then return nil end

    local mode = {
        width = width,
        height = height,
        fullscreen = false,
        fullscreenType = "desktop",
        borderless = false,
        vsync = nil
    }

    if type(flags) == "table" then
        mode.fullscreen = flags.fullscreen or false
        mode.fullscreenType = flags.fullscreentype or flags.fullscreenType or flags.fullscreen_type or "desktop"
        mode.borderless = flags.borderless or false
        mode.vsync = normalizeVsync(flags.vsync)
    elseif type(flags) == "boolean" then
        mode.fullscreen = flags
    end

    -- Borderless windows are never fullscreen
    if mode.borderless then
        mode.fullscreen = false
    end

    return mode
end

local function shouldUpdateWindowMode(desiredSettings, currentMode)
    if not currentMode then return true end

    return currentMode.width ~= desiredSettings.width or
           currentMode.height ~= desiredSettings.height or
           currentMode.fullscreen ~= desiredSettings.fullscreen or
           currentMode.fullscreenType ~= desiredSettings.fullscreenType or
           currentMode.borderless ~= desiredSettings.borderless or
           currentMode.vsync ~= desiredSettings.vsync
end

function love.applyGraphicsSettings()
    local graphicsSettings = Settings.getGraphicsSettings()
    local resolution = graphicsSettings.resolution or {}
    local desiredWidth = resolution.width
    local desiredHeight = resolution.height

    -- Build desired window mode configuration
    local desiredMode = {
        width = desiredWidth,
        height = desiredHeight,
        fullscreen = graphicsSettings.fullscreen,
        fullscreenType = graphicsSettings.fullscreen_type or "desktop",
        borderless = graphicsSettings.borderless or false,
        vsync = normalizeVsync(graphicsSettings.vsync)
    }

    -- Borderless windows override fullscreen setting
    if desiredMode.borderless then
        desiredMode.fullscreen = false
    end

    -- Check if we need to update the window mode
    local currentMode = getCurrentWindowMode()
    if shouldUpdateWindowMode(desiredMode, currentMode) then
        Log.info("Applying graphics settings: " .. desiredWidth .. "x" .. desiredHeight ..
                (desiredMode.fullscreen and " fullscreen" or " windowed"))

        local success = WindowMode.apply(graphicsSettings)
        if success and desiredWidth and desiredHeight then
            Viewport.init(desiredWidth, desiredHeight)
        end
    end

    updateFPSLimit()
end

local function seedRandom()
    if love.math and love.timer then
        local seed = love.timer.getTime() * 1000
        love.math.setRandomSeed(seed)
        love.math.random()
        love.math.random()
    else
        math.randomseed(os.time())
    end
end

-- =============================================================================
-- INITIALIZATION SYSTEM - Optimized dependency order
-- =============================================================================

local function initCoreSystems()
    -- Initialize core systems that other systems depend on

    -- 1. Debug system (must be first for error reporting)
    local Debug = require("src.core.debug")
    Debug.init()
    recordMilestone("debug init")

    -- 2. Logging system
    Log.setLevel("info")
    Log.clearDebugWhitelist()
    Log.setInfoEnabled(true)
    Log.info("Game Identity:", love.filesystem.getIdentity())
    Log.info("LÖVE Save Directory:", love.filesystem.getSaveDirectory())
    recordMilestone("logging setup")

    -- 3. Random seeding (affects all random operations)
    seedRandom()
    recordMilestone("random seed")

    -- 4. Settings (needed by graphics, audio, input)
    Settings.load()
    recordMilestone("settings load")
end

local function initGraphicsAndAudio()
    -- Initialize graphics and audio systems

    -- Graphics settings (must be before window operations)
    love.applyGraphicsSettings()
    recordMilestone("graphics setup")

    -- Audio settings
    Sound.applySettings()
    recordMilestone("audio setup")

    -- Window input settings
    love.keyboard.setKeyRepeat(true)
    love.mouse.setRelativeMode(false)
    love.mouse.setVisible(false)  -- Hide cursor on start screen
end

local function initUIAndInput()
    -- Initialize UI systems and input handling

    -- Theme system (fonts needed by UI)
    local Theme = getModule("Theme")
    Theme.init()
    Theme.loadFonts()
    recordMilestone("theme init")

    -- Settings panel (depends on theme)
    getModule("SettingsPanel").init()
    recordMilestone("settings panel init")

    -- UI screens
    loadingScreen = getModule("LoadingScreen").new()
    recordMilestone("loading screen init")

    startScreen = getModule("StartScreen").new()
    recordMilestone("start screen init")

    -- Input system (depends on settings and screens)
    configureInput()
    recordMilestone("input setup")
end

local function initDefaultKeybindings()
    -- Initialize default keybindings if not set
    local km = Settings.getKeymap() or {}
    local defaults = { hotbar_3 = "q", hotbar_4 = "e", hotbar_5 = "r" }
    for key, defaultBinding in pairs(defaults) do
        if km[key] ~= defaultBinding then
            Settings.setKeyBinding(key, defaultBinding)
            km[key] = defaultBinding
        end
    end
end

function love.load()
    -- Start profiling
    startupProfile.startTime = love.timer.getTime()
    recordMilestone("love.load start")

    -- Initialize systems in dependency order
    initCoreSystems()
    initDefaultKeybindings()
    initGraphicsAndAudio()
    initUIAndInput()

    -- Start background music
    Sound.playMusic("adrift")
    recordMilestone("music start")

    -- Log startup profile
    logStartupProfile()
    recordMilestone("startup complete")
end

function love.resize(w, h)
  Viewport.resize(w, h)
  if screen == "start" and startScreen and startScreen.resize then
    startScreen:resize(w, h)
  elseif screen == "game" then
    if UIManager and UIManager.resize then UIManager.resize(w, h) end
    local Game = getModule("Game")
    if Game and Game.resize then Game.resize(w, h) end
  end
end

function love.update(dt)
  -- Apply the coarse frame limiter before updating any subsystems so the rest
  -- of the engine can assume the delta time stays within reasonable bounds.
  if minFrameTime > 0 then
    local currentTime = love.timer.getTime()
    local frameTime = currentTime - lastFrameTime
    if frameTime < minFrameTime then
      love.timer.sleep(minFrameTime - frameTime)
    end
    lastFrameTime = love.timer.getTime()
  end

  -- Update debug panel (lazy loaded)
  getModule("DebugPanel").update(dt)

  -- Update loading screen (lazy loaded)
  loadingScreen:update(dt)

  if screen == "start" then
    if startScreen and startScreen.update then
      startScreen:update(dt)
    end
  elseif screen == "game" then
    getModule("Game").update(dt)
  end
end

-- =============================================================================
-- ERROR HANDLING AND RECOVERY
-- =============================================================================

local errorState = {
    lastError = nil,
    errorCount = 0,
    recoveryAttempts = 0,
    maxRecoveryAttempts = 3
}

local function handleDrawError(err)
    errorState.lastError = err
    errorState.errorCount = errorState.errorCount + 1

    Log.error("Draw error #" .. errorState.errorCount .. ": " .. tostring(err))

    -- Attempt recovery for non-critical errors
    if errorState.errorCount <= errorState.maxRecoveryAttempts then
        errorState.recoveryAttempts = errorState.recoveryAttempts + 1
        Log.info("Attempting draw recovery (attempt " .. errorState.recoveryAttempts .. ")")

        -- Clear potentially corrupted graphics state
        love.graphics.reset()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setBackgroundColor(0, 0, 0, 1)

        -- Try to reset viewport if it was active
        if pcall(Viewport.finish) then
            Log.debug("Viewport reset successful")
        end

        return true -- Recovery attempted
    end

    Log.error("Max recovery attempts reached, propagating error")
    return false -- No more recovery attempts
end

local function safeDraw(operation, description)
    local ok, err = xpcall(operation, debug.traceback)
    if not ok then
        Log.error("Safe draw operation failed (" .. description .. "): " .. tostring(err))
        if not handleDrawError(err) then
            error("Critical draw error: " .. tostring(err))
        end
        return false
    end
    return true
end

function love.draw()
    local drawStart = love.timer.getTime()
    local viewportActive = false

    -- Safe viewport begin
    if safeDraw(function()
        Viewport.begin()
        viewportActive = true
    end, "viewport begin") then

        -- Safe main drawing operations
        safeDraw(function()
            love.graphics.setFont(getModule("Theme").fonts.normal)
            if screen == "start" then
                startScreen:draw()
            else
                getModule("Game").draw()
            end
        end, "main draw")
    end

    -- Safe viewport finish
    if viewportActive then
        safeDraw(function()
            Viewport.finish()
        end, "viewport finish")
    end

    -- Draw loading screen on top of everything
    safeDraw(function()
        loadingScreen:draw()
    end, "loading screen")

    -- Draw FPS counter if enabled
    if screen == "game" then
        safeDraw(function()
            local graphicsSettings = Settings.getGraphicsSettings()
            if graphicsSettings and graphicsSettings.show_fps then
                local fps = love.timer.getFPS()
                local Theme = getModule("Theme")
                local oldFont = love.graphics.getFont()
                love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
                Theme.setColor(Theme.colors.text)
                love.graphics.print("FPS: " .. fps, 10, 10)
                love.graphics.setFont(oldFont)
            end
        end, "fps counter")
    end

    -- Update debug panel render stats
    local drawTime = (love.timer.getTime() - drawStart) * 1000
    safeDraw(function()
        getModule("DebugPanel").setRenderStats(drawTime)
    end, "debug panel stats")
end

-- Handle debug panel input first, then delegate to Input module
function love.keypressed(key, scancode, isrepeat)
  -- Let debug panel handle F1 and its own input (lazy loaded)
  if getModule("DebugPanel").keypressed(key) then
    return
  end

  -- Handle other input through the Input module
  Input.love_keypressed(key)
end

function love.keyreleased(key, scancode)
  -- Let debug panel handle key releases (lazy loaded)
  local DebugPanel = getModule("DebugPanel")
  if DebugPanel.keyreleased and DebugPanel.keyreleased(key) then
    return
  end

  -- Handle other input through the Input module
  Input.love_keyreleased(key)
end

function love.mousepressed(x, y, button)
  Input.love_mousepressed(x, y, button)
end

function love.mousereleased(...)
  Input.love_mousereleased(...)
end

function love.mousemoved(...)
  Input.love_mousemoved(...)
end

function love.wheelmoved(...)
  Input.love_wheelmoved(...)
end

function love.textinput(text)
  -- Let debug panel handle text input first (lazy loaded)
  local DebugPanel = getModule("DebugPanel")
  if DebugPanel.textinput and DebugPanel.textinput(text) then
    return
  end

  -- Pass to input module
  if Input.love_textinput then
    Input.love_textinput(text)
  end
end
