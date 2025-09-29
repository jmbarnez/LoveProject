-- main.lua
-- Entry point for the game. Initializes modules, handles the main loop, and manages screen transitions
local Game = require("src.game")
local Start = require("src.ui.start_screen")
local Input = require("src.core.input")
local Viewport = require("src.core.viewport")
local SettingsPanel = require("src.ui.settings_panel")
local Settings = require("src.core.settings")
local Sound = require("src.core.sound")
local DebugPanel = require("src.ui.debug_panel")
local Constants = require("src.core.constants")
local LoadingScreen = require("src.ui.loading_screen")

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
local loadingScreen = LoadingScreen.new()

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
    screen = newScreen

    if newScreen == "start" then
        startScreen = Start.new()
        love.mouse.setVisible(true)
        Sound.playMusic("adrift")
    elseif newScreen == "game" and not UIManager then
        UIManager = require("src.core.ui_manager")
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

local function applyWindowMode(graphicsSettings)
    local ok, err = pcall(function()
        love.window.setMode(
            graphicsSettings.resolution.width,
            graphicsSettings.resolution.height,
            {
                fullscreen = graphicsSettings.fullscreen,
                fullscreentype = graphicsSettings.fullscreen_type,
                borderless = graphicsSettings.borderless,
                vsync = graphicsSettings.vsync,
                resizable = true,
                minwidth = Constants.RESOLUTION.MIN_WINDOW_WIDTH_1024PX,
                minheight = Constants.RESOLUTION.MIN_WINDOW_HEIGHT_1024PX,
            }
        )
    end)

    if not ok then
        local Log = require("src.core.log")
        Log.warn("Failed to apply window mode: " .. tostring(err))
    end
end

function love.applyGraphicsSettings()
    local graphicsSettings = Settings.getGraphicsSettings()
    applyWindowMode(graphicsSettings)
    Viewport.init(graphicsSettings.resolution.width, graphicsSettings.resolution.height)
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

function love.load()
    local Log = require("src.core.log")
    Log.setLevel("info")
    Log.setInfoEnabled(true) -- Ensure info-level logs are emitted during startup
    Log.clearDebugWhitelist()
    Log.info("Game Identity:", love.filesystem.getIdentity())
    Log.info("LÖVE Save Directory:", love.filesystem.getSaveDirectory())
    seedRandom()
    Settings.load()
    Sound.applySettings()

    local SettingsModule = require("src.core.settings")
    local km = SettingsModule.getKeymap() or {}
    local defaults = { hotbar_3 = "q", hotbar_4 = "e", hotbar_5 = "r" }
    for key, defaultBinding in pairs(defaults) do
        if km[key] ~= defaultBinding then
            SettingsModule.setKeyBinding(key, defaultBinding)
            km[key] = defaultBinding
        end
    end

    love.applyGraphicsSettings()

    love.mouse.setRelativeMode(false)
    local Theme = require("src.core.theme")
    Theme.init()
    Theme.loadFonts()
    SettingsPanel.init()
    startScreen = Start.new()
    Sound.playMusic("adrift")

    configureInput()
end

function love.resize(w, h)
  Viewport.resize(w, h)
  if screen == "start" and startScreen and startScreen.resize then
    startScreen:resize(w, h)
  elseif screen == "game" then
    if UIManager and UIManager.resize then UIManager.resize(w, h) end
    if Game and Game.resize then Game.resize(w,h) end
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
  
  -- Update debug panel
  DebugPanel.update(dt)
  
  -- Update loading screen
  loadingScreen:update(dt)
  
  if screen == "start" then
    if startScreen and startScreen.update then
      startScreen:update(dt)
    end
  elseif screen == "game" then
    Game.update(dt)
  end
end

function love.draw()
  local drawStart = love.timer.getTime()
  
  Viewport.begin()
  love.graphics.setFont(require("src.core.theme").fonts.normal)
  if screen == "start" then
    startScreen:draw()
  else
    Game.draw()
  end
  Viewport.finish()
  
  -- Draw loading screen on top of everything
  loadingScreen:draw()
  
  -- Calculate and set draw time (in ms)
  local drawTime = (love.timer.getTime() - drawStart) * 1000
  DebugPanel.setRenderStats(drawTime)
  
  -- Debug panel is now drawn by the UIManager
end

-- Handle debug panel input first, then delegate to Input module
function love.keypressed(key, scancode, isrepeat)
  -- Let debug panel handle F1 and its own input
  if DebugPanel.keypressed(key) then
    return
  end

  -- Handle other input through the Input module
  Input.love_keypressed(key)
end

function love.keyreleased(key, scancode)
  -- Let debug panel handle key releases
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
  -- Let debug panel handle text input first
  if DebugPanel.textinput and DebugPanel.textinput() then
    return
  end
  
  -- Pass to input module
  if Input.love_textinput then
    Input.love_textinput(text)
  end
end
