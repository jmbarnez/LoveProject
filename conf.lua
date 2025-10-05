function love.conf(t)
  t.identity = "dark_orbit_clone"
  t.version = "11.4"
  t.console = true

  -- Window configuration
  t.window.title = "Novus"
  -- Default resolution, will be overridden by settings
  t.window.width = 1600
  t.window.height = 900
  t.window.resizable = true
  t.window.fullscreen = false
  t.window.fullscreentype = "desktop"  -- Modern fullscreen mode
  t.window.vsync = true  -- Modern boolean value
  -- Reasonable minimums to keep UI usable when resizing
  t.window.minwidth = 1024
  t.window.minheight = 576

  -- Modern display settings
  t.window.highdpi = true      -- Enable high DPI support
  t.window.usedpiscale = true  -- Use DPI scaling
  t.window.borderless = false  -- Ensure window has borders
  t.window.display = 1         -- Use primary display

  -- Audio configuration
  t.audio.mixwithsystem = true  -- Allow mixing with system audio

  -- Module configuration for better performance
  t.modules.audio = true
  t.modules.data = true
  t.modules.event = true
  t.modules.font = true
  t.modules.graphics = true
  t.modules.image = true
  t.modules.joystick = true
  t.modules.keyboard = true
  t.modules.math = true
  t.modules.mouse = true
  t.modules.physics = true
  t.modules.sound = true
  t.modules.system = true
  t.modules.thread = true
  t.modules.timer = true
  t.modules.touch = false  -- Disable touch (not needed for desktop)
  t.modules.video = false  -- Disable video (not needed)
  t.modules.window = true
end
