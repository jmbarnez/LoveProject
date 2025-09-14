function love.conf(t)
  t.identity = "dark_orbit_clone"
  t.version = "11.4"
  t.console = true
  t.window.title = "Novus"
  -- Higher resolution for crisp UI and text
  t.window.width = 1920
  t.window.height = 1080
  t.window.resizable = true
  t.window.fullscreen = false
  t.window.fullscreentype = "desktop"
  t.window.vsync = 1
  t.window.msaa = 2
  -- Reasonable minimums to keep UI usable when resizing
  t.window.minwidth = 1024
  t.window.minheight = 576
  -- Re-enable VSync for 60fps cap
  t.window.vsync = 1
end
