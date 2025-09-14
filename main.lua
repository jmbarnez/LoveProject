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

local UIManager
local screen = "start"
local startScreen

local minFrameTime = 1/60
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

function love.load()
  math.randomseed(os.time())
  Settings.load()
  Sound.applySettings()
  -- During debugging enable verbose output so Log.debug() calls are visible
  local Log = require("src.core.log")
  Log.setLevel("debug")
  -- Only allow debug lines from our input/hotbar checks to reduce noise
  Log.setDebugWhitelist({"Input.keypressed", "Input.keypressed:", "Hotbar.keypressed", "Hotbar key compare", "Hotbar:", "KeymapDump", "KeymapReset"})
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
  local graphicsSettings = Settings.getGraphicsSettings()
  Viewport.init(graphicsSettings.resolution.width, graphicsSettings.resolution.height)
  updateFPSLimit()
  love.mouse.setRelativeMode(false)
  require("src.core.theme").loadFonts()
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
  
  if screen == "start" then
    if startScreen and startScreen.update then
      startScreen:update(dt)
    end
  elseif screen == "game" then
    Game.update(dt)
  end
end

function love.draw()
  Viewport.begin()
  love.graphics.setFont(require("src.core.theme").fonts.normal)
  if screen == "start" then
    startScreen:draw()
  else
    Game.draw()
  end
  Effects.draw()
  Viewport.finish()
end

-- Delegate all input handling to the Input module
function love.keypressed(...)
  Input.love_keypressed(...)
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

function love.textinput(...)
  Input.love_textinput(...)
end