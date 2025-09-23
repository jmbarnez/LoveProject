-- main.lua
-- Entry point for the game. Initializes modules, handles the main loop, and manages screen transitions
local Game = require("src.game")
local Start = require("src.ui.start_screen")
local Input = require("src.core.input")
local Viewport = require("src.core.viewport")
local SettingsPanel = require("src.ui.settings_panel")
local Settings = require("src.core.settings")
local Sound = require("src.core.sound")
local Effects = require("src.systems.effects")
local DebugPanel = require("src.ui.debug_panel")
local Constants = require("src.core.constants")

local UIManager
local screen = "start"
local startScreen

local minFrameTime = 1/Constants.TIMING.FPS_60
local lastFrameTime = 0

love = love or {}
function love.setScreen(newScreen)
  screen = newScreen
  if newScreen == "start" then
    startScreen = Start.new()
    love.mouse.setVisible(true)
    Sound.playMusic("adrift")
  elseif newScreen == "game" then
    if not UIManager then
      UIManager = require("src.core.ui_manager")
    end
  end
  -- Update the input module with the new state
  Input.init_love_callbacks({
    screen = screen,
    startScreen = startScreen,
    UIManager = UIManager,
    setScreen = love.setScreen
  })
end

function updateFPSLimit()
  local graphicsSettings = Settings.getGraphicsSettings()
  minFrameTime = (graphicsSettings.max_fps and graphicsSettings.max_fps > 0) and (1 / graphicsSettings.max_fps) or 0
end

function love.applyGraphicsSettings()
    local graphicsSettings = Settings.getGraphicsSettings()
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
            minheight = Constants.RESOLUTION.MIN_WINDOW_HEIGHT_1024PX
        }
    )
    Viewport.init(graphicsSettings.resolution.width, graphicsSettings.resolution.height)
    updateFPSLimit()
end

function love.load()
  math.randomseed(os.time())
  Settings.load()
  Sound.applySettings()
  
  -- Enable debug logging with a whitelist that includes our debug messages
  local Log = require("src.core.log")
  Log.setLevel("debug")
  -- Temporarily disable whitelist to see all debug logs
  Log.setDebugWhitelist(nil)  -- This will show all debug logs
  Log.info("Debug logging enabled - showing all debug messages")
  Log.info("Debug logging enabled with whitelist")
  -- Disable INFO level messages during debugging to avoid overlay clutter
  Log.setInfoEnabled(false)
  -- One-time dump of the active keymap so we can see what's bound to hotbar_X
  local Settings = require("src.core.settings")
  local km = Settings.getKeymap() or {}
  for k, v in pairs(km) do
    Log.debug("KeymapDump " .. tostring(k), tostring(v))
  end
  -- Ensure hotbar keyboard bindings exist for 3..5 (Q,E,R). If user settings
  -- mistakenly remapped them to mouse buttons, fix at runtime so keyboard hotkeys work.
  local defaults = { hotbar_3 = "q", hotbar_4 = "e", hotbar_5 = "r" }
  for k, dv in pairs(defaults) do
    if km[k] ~= dv then
      Log.debug("KeymapReset", k, "was", tostring(km[k]), "reset to", dv)
      Settings.setKeyBinding(k, dv)
      km[k] = dv
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

  -- Initialize the input module with the main state
  Input.init_love_callbacks({
    screen = screen,
    startScreen = startScreen,
    UIManager = UIManager,
    setScreen = love.setScreen
  })
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
  Input.love_keypressed(key, scancode, isrepeat)
end

function love.keyreleased(key, scancode)
  -- Let debug panel handle key releases
  if DebugPanel.keyreleased and DebugPanel.keyreleased(key) then
    return
  end

  -- Handle other input through the Input module
  Input.love_keyreleased(key, scancode)
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
  if DebugPanel.textinput and DebugPanel.textinput(text) then
    return
  end
  
  -- Pass to input module
  if Input.love_textinput then
    Input.love_textinput(text)
  end
end
