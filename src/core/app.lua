local Constants = require("src.core.constants")
local Log = require("src.core.log")
local Settings = require("src.core.settings")
local Input = require("src.core.input")
local Viewport = require("src.core.viewport")
local WindowMode = require("src.core.window_mode")
local Sound = require("src.core.sound")
local ModuleRegistry = require("src.core.module_registry")

local App = {}

-- =============================================================================
-- MODULE REGISTRATION
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
-- INTERNAL STATE
-- =============================================================================
local state = {
    screen = "start",
    startScreen = nil,
    loadingScreen = nil,
    UIManager = nil,
}

local inputContext = {
    setScreen = function(newScreen)
        App.setScreen(newScreen)
    end,
}

local startupProfile = {
    startTime = nil,
    milestones = {},
    lazyLoadTimes = {},
}

local minFrameTime = 1 / Constants.TIMING.FPS_60
local lastFrameTime = 0

-- =============================================================================
-- STARTUP PROFILING HELPERS
-- =============================================================================
local function recordMilestone(name)
    startupProfile.milestones[name] = love.timer.getTime()
    local elapsed = startupProfile.milestones[name] - (startupProfile.startTime or startupProfile.milestones[name])
    Log.debug(string.format("Startup milestone '%s': %.3fms", name, elapsed * 1000))
end

local function logStartupProfile()
    local totalTime = (love.timer.getTime() - startupProfile.startTime) * 1000
    Log.info(string.format("=== STARTUP PROFILE (Total: %.2fms) ===", totalTime))

    local prevTime = startupProfile.startTime
    for name, time in pairs(startupProfile.milestones) do
        local elapsed = (time - prevTime) * 1000
        Log.info(string.format("  %s: %.2fms", name, elapsed))
        prevTime = time
    end

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

-- =============================================================================
-- MODULE LOADING HELPERS
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

-- =============================================================================
-- INPUT CONFIGURATION
-- =============================================================================
local function syncInputContext()
    inputContext.screen = state.screen
    inputContext.startScreen = state.startScreen
    inputContext.UIManager = state.UIManager
    inputContext.loadingScreen = state.loadingScreen
    Input.init_love_callbacks(inputContext)
end

-- =============================================================================
-- GRAPHICS SETTINGS HELPERS
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

local function updateFPSLimit()
    local graphicsSettings = Settings.getGraphicsSettings()
    local maxFPS = graphicsSettings and graphicsSettings.max_fps
    if maxFPS and maxFPS > 0 then
        minFrameTime = 1 / maxFPS
    else
        minFrameTime = 0
    end
end

App.updateFPSLimit = updateFPSLimit
_G.updateFPSLimit = updateFPSLimit

function App.applyGraphicsSettings()
    local graphicsSettings = Settings.getGraphicsSettings()
    local resolution = graphicsSettings.resolution or {}
    local desiredWidth = resolution.width
    local desiredHeight = resolution.height

    local desiredMode = {
        width = desiredWidth,
        height = desiredHeight,
        fullscreen = graphicsSettings.fullscreen,
        fullscreenType = graphicsSettings.fullscreen_type or "desktop",
        borderless = graphicsSettings.borderless or false,
        vsync = normalizeVsync(graphicsSettings.vsync)
    }

    if desiredMode.borderless then
        desiredMode.fullscreen = false
    end

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

-- =============================================================================
-- GENERAL HELPERS
-- =============================================================================
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

local function initCoreSystems()
    local Debug = require("src.core.debug")
    Debug.init()
    recordMilestone("debug init")

    Log.setLevel("info")
    Log.clearDebugWhitelist()
    Log.setInfoEnabled(true)
    Log.info("Game Identity:", love.filesystem.getIdentity())
    Log.info("LÖVE Save Directory:", love.filesystem.getSaveDirectory())
    recordMilestone("logging setup")

    seedRandom()
    recordMilestone("random seed")

    Settings.load()
    recordMilestone("settings load")
end

local function initGraphicsAndAudio()
    App.applyGraphicsSettings()
    recordMilestone("graphics setup")

    Sound.applySettings()
    recordMilestone("audio setup")

    love.keyboard.setKeyRepeat(true)
    love.mouse.setRelativeMode(false)
    love.mouse.setVisible(false)
end

local function initUIAndInput()
    local Theme = getModule("Theme")
    Theme.init()
    Theme.loadFonts()
    recordMilestone("theme init")

    getModule("SettingsPanel").init()
    recordMilestone("settings panel init")

    state.loadingScreen = getModule("LoadingScreen").new()
    recordMilestone("loading screen init")

    state.startScreen = getModule("StartScreen").new()
    recordMilestone("start screen init")

    syncInputContext()
    recordMilestone("input setup")
end

local function initDefaultKeybindings()
    local km = Settings.getKeymap() or {}
    local defaults = { hotbar_3 = "q", hotbar_4 = "e", hotbar_5 = "r" }
    for key, defaultBinding in pairs(defaults) do
        if km[key] ~= defaultBinding then
            Settings.setKeyBinding(key, defaultBinding)
            km[key] = defaultBinding
        end
    end
end

-- =============================================================================
-- SCREEN MANAGEMENT
-- =============================================================================
function App.setScreen(newScreen)
    local previousScreen = state.screen
    if previousScreen == newScreen then
        return
    end

    state.screen = newScreen

    if newScreen == "start" then
        if previousScreen == "game" then
            local Game = getModule("Game")
            if Game and Game.unload then
                Game.unload()
            end
        end

        state.startScreen = getModule("StartScreen").new()
        love.mouse.setVisible(false)
        if love.mouse and love.mouse.setRelativeMode then
            love.mouse.setRelativeMode(false)
        end
        Sound.playMusic("adrift")
        ModuleRegistry.clear("UIManager")
        state.UIManager = nil
    elseif newScreen == "game" then
        state.UIManager = getModule("UIManager")
        if love.mouse and love.mouse.setVisible then
            love.mouse.setVisible(false)
        end
        Viewport.syncWithWindow()
    end

    syncInputContext()
end

-- =============================================================================
-- ERROR HANDLING HELPERS
-- =============================================================================
local errorState = {
    lastError = nil,
    errorCount = 0,
    recoveryAttempts = 0,
    maxRecoveryAttempts = 3,
}

local function handleDrawError(err)
    errorState.lastError = err
    errorState.errorCount = errorState.errorCount + 1

    Log.error("Draw error #" .. errorState.errorCount .. ": " .. tostring(err))

    if errorState.errorCount <= errorState.maxRecoveryAttempts then
        errorState.recoveryAttempts = errorState.recoveryAttempts + 1
        Log.info("Attempting draw recovery (attempt " .. errorState.recoveryAttempts .. ")")

        love.graphics.reset()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setBackgroundColor(0, 0, 0, 1)

        if pcall(Viewport.finish) then
            Log.debug("Viewport reset successful")
        end

        return true
    end

    Log.error("Max recovery attempts reached, propagating error")
    return false
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

-- =============================================================================
-- LOVE CALLBACKS
-- =============================================================================
function App.load()
    startupProfile.startTime = love.timer.getTime()
    recordMilestone("love.load start")

    initCoreSystems()
    initDefaultKeybindings()
    initGraphicsAndAudio()
    initUIAndInput()

    Sound.playMusic("adrift")
    recordMilestone("music start")

    logStartupProfile()
    recordMilestone("startup complete")
end

function App.resize(w, h)
    Viewport.resize(w, h)
    if state.screen == "start" and state.startScreen and state.startScreen.resize then
        state.startScreen:resize(w, h)
    elseif state.screen == "game" then
        if state.UIManager and state.UIManager.resize then state.UIManager.resize(w, h) end
        local Game = getModule("Game")
        if Game and Game.resize then Game.resize(w, h) end
    end
end

function App.update(dt)
    if minFrameTime > 0 then
        local currentTime = love.timer.getTime()
        local frameTime = currentTime - lastFrameTime
        if frameTime < minFrameTime then
            love.timer.sleep(minFrameTime - frameTime)
        end
        lastFrameTime = love.timer.getTime()
    end

    getModule("DebugPanel").update(dt)

    if state.loadingScreen and state.loadingScreen.update then
        state.loadingScreen:update(dt)
    end

    if state.screen == "start" then
        if state.startScreen and state.startScreen.update then
            state.startScreen:update(dt)
        end
    elseif state.screen == "game" then
        getModule("Game").update(dt)
    end
end

function App.draw()
    local drawStart = love.timer.getTime()
    local viewportActive = false

    if safeDraw(function()
        Viewport.begin()
        viewportActive = true
    end, "viewport begin") then
        safeDraw(function()
            local Theme = getModule("Theme")
            if Theme and Theme.fonts and Theme.fonts.normal then
                love.graphics.setFont(Theme.fonts.normal)
            end
            if state.screen == "start" then
                if state.startScreen and state.startScreen.draw then
                    state.startScreen:draw()
                end
            else
                getModule("Game").draw()
            end
        end, "main draw")
    end

    if viewportActive then
        safeDraw(function()
            Viewport.finish()
        end, "viewport finish")
    end

    if state.loadingScreen and state.loadingScreen.draw then
        safeDraw(function()
            state.loadingScreen:draw()
        end, "loading screen")
    end

    if state.screen == "game" then
        safeDraw(function()
            local graphicsSettings = Settings.getGraphicsSettings()
            if graphicsSettings and graphicsSettings.show_fps then
                local fps = love.timer.getFPS()
                local Theme = getModule("Theme")
                local oldFont = love.graphics.getFont()
                if Theme.fonts and Theme.fonts.small then
                    love.graphics.setFont(Theme.fonts.small)
                end
                if Theme.setColor and Theme.colors and Theme.colors.text then
                    Theme.setColor(Theme.colors.text)
                end
                love.graphics.print("FPS: " .. fps, 10, 10)
                love.graphics.setFont(oldFont)
            end
        end, "fps counter")
    end

    local drawTime = (love.timer.getTime() - drawStart) * 1000
    safeDraw(function()
        getModule("DebugPanel").setRenderStats(drawTime)
    end, "debug panel stats")
end

function App.keypressed(key, scancode, isrepeat)
    if getModule("DebugPanel").keypressed(key) then
        return
    end

    Input.love_keypressed(key)
end

function App.keyreleased(key, scancode)
    local DebugPanel = getModule("DebugPanel")
    if DebugPanel.keyreleased and DebugPanel.keyreleased(key) then
        return
    end

    Input.love_keyreleased(key)
end

function App.mousepressed(x, y, button)
    Input.love_mousepressed(x, y, button)
end

function App.mousereleased(...)
    Input.love_mousereleased(...)
end

function App.mousemoved(...)
    Input.love_mousemoved(...)
end

function App.wheelmoved(...)
    Input.love_wheelmoved(...)
end

function App.textinput(text)
    local DebugPanel = getModule("DebugPanel")
    if DebugPanel.textinput and DebugPanel.textinput(text) then
        return
    end

    if Input.love_textinput then
        Input.love_textinput(text)
    end
end

local function installLoveExtensions()
    love = love or {}
    love.setScreen = App.setScreen
    love.applyGraphicsSettings = App.applyGraphicsSettings
end

installLoveExtensions()

return App
