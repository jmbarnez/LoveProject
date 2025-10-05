local Input = require("src.core.input")
local Viewport = require("src.core.viewport")
local Theme = require("src.core.theme")
local SaveLoad = require("src.ui.save_load")
local StateManager = require("src.managers.state_manager")
local World = require("src.core.world")
local AuroraTitle = require("src.shaders.aurora_title")
local Sound = require("src.core.sound")
local SettingsPanel = require("src.ui.settings_panel")
local UIButton = require("src.ui.common.button")
local Window = require("src.ui.common.window")
local Strings = require("src.core.strings")
local VersionLog = require("src.ui.version_log")
local NetworkManager = require("src.core.network.manager")
local Notifications = require("src.ui.notifications")

local Start = {}
Start.__index = Start

-- Function to draw an improved cog icon
local function drawCogIcon(centerX, centerY, radius)
    local segments = 8  -- Fewer segments for cleaner look
    local innerRadius = radius * 0.5
    local outerRadius = radius * 0.8
    local toothDepth = radius * 0.15
    local toothWidth = 0.3  -- Width of each tooth as fraction of segment
    
    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    
    -- Draw outer gear teeth
    for i = 0, segments - 1 do
        local angle1 = (i * 2 * math.pi) / segments
        local angle2 = angle1 + (toothWidth * math.pi / segments)
        local angle3 = angle1 + ((1 - toothWidth) * math.pi / segments)
        local angle4 = ((i + 1) * 2 * math.pi) / segments
        
        -- Tooth outer points
        local x1 = math.cos(angle1) * outerRadius
        local y1 = math.sin(angle1) * outerRadius
        local x2 = math.cos(angle2) * (outerRadius + toothDepth)
        local y2 = math.sin(angle2) * (outerRadius + toothDepth)
        local x3 = math.cos(angle3) * (outerRadius + toothDepth)
        local y3 = math.sin(angle3) * (outerRadius + toothDepth)
        local x4 = math.cos(angle4) * outerRadius
        local y4 = math.sin(angle4) * outerRadius
        
        -- Draw tooth
        love.graphics.polygon("fill", x1, y1, x2, y2, x3, y3, x4, y4)
    end
    
    -- Draw inner circle (gear body)
    love.graphics.circle("fill", 0, 0, innerRadius)
    
    -- Draw center hole
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.circle("fill", 0, 0, innerRadius * 0.4)
    
    love.graphics.pop()
end

-- Start screen input handler
local startScreenHandler = function(self, x, y, button)
  if button ~= 1 then return false end

  -- Load Game button click
  if Theme.handleButtonClick(self.loadButton, x, y, function()
    -- Explicitly refresh the save slots from disk before showing the UI
    if self.loadSlotsUI and self.loadSlotsUI.saveSlots and self.loadSlotsUI.saveSlots._ensureCache then
      self.loadSlotsUI.saveSlots:_ensureCache()
    end
    self.showLoadUI = true
  end) then
    return false -- don't start game, show load UI
  end

  -- Join Game button click
  if Theme.handleButtonClick(self.multiplayerButton, x, y, function()
    print("Join Game button clicked, opening UI")
    self.showJoinUI = true
    self.joinErrorMessage = nil
    self.joinWindow:show()
  end) then
    return false
  end

  if Theme.handleButtonClick(self.versionButton, x, y, function()
    VersionLog.toggle()
  end) then
    return false
  end

  if Theme.handleButtonClick(self.settingsButton, x, y, function()
    SettingsPanel.toggle()
  end) then
    return false
  end

  if Theme.handleButtonClick(self.exitButton, x, y, function()
    love.event.quit()
  end) then
    return false
  end


  -- Start button click
  if Theme.handleButtonClick(self.button, x, y, function()
    -- The actual start action is handled by returning true
  end) then
    return true -- signal start
  end

  return false
end

local function genSkyStars(sw, sh, count)
  local stars = {}
  for i = 1, count do
    stars[i] = {
      x = math.random() * sw,
      y = math.random() * sh,
      s = 0.14 + math.random() * 0.22,
      a = 0.06 + math.random() * 0.06,
      tw = 0.35 + math.random() * 0.55,
      ph = math.random() * math.pi * 2,
    }
  end
  return stars
end

local function genScreenStars(sw, sh, count)
  local stars = {}
  for i = 1, count do
    stars[i] = { x = math.random() * sw, y = math.random() * sh, s = 0.28 + math.random() * 0.36 }
  end
  return stars
end

local function genComets(sw, sh, count)
  local comets = {}
  for i = 1, count do
    comets[i] = {
      x = math.random() * sw,
      y = -100 - math.random() * 200, -- Start higher above the screen
      vx = (math.random() - 0.5) * 0.8, -- Slower horizontal drift
      vy = 0.3 + math.random() * 0.7, -- Much slower downward movement
      size = 0.3 + math.random() * 0.4, -- Tiny size
      alpha = 0.2 + math.random() * 0.3, -- Much more faint
      trail = {},
      trailLength = 25 + math.random(15) -- Very long trails (25-40)
    }
  end
  return comets
end

local function genTwinkles(sw, sh, count)
  local twinkles = {}
  for i = 1, count do
    twinkles[i] = {
      x = math.random() * sw,
      y = math.random() * sh,
      baseSize = 0.8 + math.random() * 1.2,
      twinkleSpeed = 2.0 + math.random() * 3.0,
      phase = math.random() * math.pi * 2,
      alpha = 0.4 + math.random() * 0.4
    }
  end
  return twinkles
end

function Start.new()
  local self = setmetatable({}, Start)
  self.w, self.h = Viewport.getDimensions()
  local scale = (self.w * self.h) / (1920 * 1080)
  self.sky = genSkyStars(self.w, self.h, math.floor(300 * math.max(1, scale)))
  self.layers = {
    { p = 0.040, stars = genScreenStars(self.w, self.h, math.floor(120 * math.max(1, scale))) },
    { p = 0.015, stars = genScreenStars(self.w, self.h, math.floor(80  * math.max(1, scale))) },
  }
  self.comets = genComets(self.w, self.h, math.floor(2 * math.max(1, scale)))
  self.twinkles = genTwinkles(self.w, self.h, math.floor(50 * math.max(1, scale)))
  self.button = { x = 0, y = 0, w = 260, h = 40 }
  self.loadButton = { x = 0, y = 0, w = 260, h = 40 }
  self.multiplayerButton = { x = 0, y = 0, w = 260, h = 40 }
  self.versionButton = { x = 0, y = 0, w = 260, h = 40 }
  self.settingsButton = { x = 0, y = 0, w = 40, h = 40 }
  self.exitButton = { x = 0, y = 0, w = 40, h = 40 }
  
  -- Multiplayer UI state
  self.showJoinUI = false
  self.joinAddress = "localhost"
  self.joinPort = "7777"
  self.joinErrorMessage = nil
  -- Create a temporary network manager for the start screen
  self.networkManager = NetworkManager.new()
  
  -- Create join game window
  self.joinWindow = Window.new({
    title = "Join Multiplayer Game",
    width = 400,
    height = 250,
    visible = false,
    closable = true,
    draggable = true,
    resizable = false,
    useLoadPanelTheme = true,
    drawContent = function(window, x, y, w, h)
      self:drawJoinWindowContent(window, x, y, w, h)
    end,
    onClose = function()
      self.showJoinUI = false
      self.joinErrorMessage = nil
    end
  })
  self.versionWindow = Window.new({
    title = Strings.getUI("version_log_title"),
    width = 1000,
    height = 640,
    visible = false,
    closable = true,
    draggable = true,
    resizable = false,
    useLoadPanelTheme = true,
    drawContent = function(_, x, y, w, h)
      VersionLog.draw(x, y, w, h)
    end,
    onClose = function()
      VersionLog.close()
    end
  })
  VersionLog.showWindow(self.versionWindow)
  
  -- Initialize settings panel
  SettingsPanel.init()
  
  self.loadSlotsUI = SaveLoad:new({
    onClose = function()
      self.showLoadUI = false
    end,
    disableSave = true
  })
  self.showLoadUI = false
  self.loadedSlot = nil -- Store the slot that was loaded
  -- Cache large title font (Press Start 2P)
  self.titleFont = love.graphics.newFont("assets/fonts/PressStart2P-Regular.ttf", 80)
  self.titleFont:setFilter('nearest', 'nearest', 1)
  -- Aurora title shader
  self.auroraShader = AuroraTitle.new()

  return self
end

function Start:resize(w, h)
  self.w, self.h = Viewport.getDimensions()
  local scale = (self.w * self.h) / (1920 * 1080)
  self.sky = genSkyStars(self.w, self.h, math.floor(300 * math.max(1, scale)))
  self.layers[1].stars = genScreenStars(self.w, self.h, math.floor(120 * math.max(1, scale)))
  self.layers[2].stars = genScreenStars(self.w, self.h, math.floor(80  * math.max(1, scale)))
  self.comets = genComets(self.w, self.h, math.floor(2 * math.max(1, scale)))
  self.twinkles = genTwinkles(self.w, self.h, math.floor(50 * math.max(1, scale)))
end

local function uiScale()
  local vw, vh = Viewport.getDimensions()
  return math.min(vw / 1920, vh / 1080)
end

function Start:update(dt)
   SettingsPanel.update(dt)
   self.networkManager:update(dt)
   Notifications.update(dt)
end

function Start:draw()
  local w, h = self.w, self.h
  local t = love.timer.getTime()

  -- Enhanced space background with theme colors
  Theme.setColor(Theme.colors.bg0)
  love.graphics.rectangle('fill', 0, 0, w, h)

  -- Draw Title
  local titleFont = self.titleFont
  love.graphics.setFont(titleFont)
  local titleText = Strings.getUI("game_title")
  local textWidth = titleFont:getWidth(titleText)
  local titleX = (w - textWidth) / 2
  local titleY = h * 0.2

  -- Subtle shadow for readability
  love.graphics.setShader()
  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.printf(titleText, titleX + 2, titleY + 2, textWidth, "center")

  -- Aurora shader fill (fallback to static gradient if shader unavailable)
  if self.auroraShader then
    self.auroraShader:send("time", t)
    love.graphics.setShader(self.auroraShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(titleText, titleX, titleY, textWidth, "center")
    love.graphics.setShader()
  else
    local pulse = (math.sin(t * 2) + 1) / 2
    local r = 0 + (0.65 - 0.00) * pulse
    local g = 0.85 + (0.30 - 0.85) * pulse
    local b = 0.90 + (0.95 - 0.90) * pulse
    love.graphics.setColor(r, g, b, 1)
    love.graphics.printf(titleText, titleX, titleY, textWidth, "center")
  end
  -- Use smaller theme font for menu items
  love.graphics.setFont(Theme.fonts and (Theme.fonts.small or Theme.fonts.normal) or love.graphics.getFont())

  -- Animated star field with theme integration
  for i = 1, #self.sky do
    local s = self.sky[i]
    local alpha = s.a + 0.04 * math.sin(t * s.tw + s.ph)
    local starColor = Theme.blend(Theme.colors.text, Theme.colors.accent, math.random() * 0.3)
    Theme.setColor(Theme.withAlpha(starColor, math.max(0, alpha)))
    love.graphics.circle('fill', math.floor(s.x)+0.5, math.floor(s.y)+0.5, s.s)
  end

  -- Enhanced parallax stars with color variation
  for li = 1, #self.layers do
    local layer = self.layers[li]
    local p = layer.p
    local ox = (t * 4 * p) % w
    local oy = (t * 2 * p) % h
    local alpha = math.min(0.4, 0.15 + 2.0 * p)
    local layerColor = li == 1 and Theme.colors.accent or Theme.colors.primary
    Theme.setColor(Theme.withAlpha(layerColor, alpha))
    for i = 1, #layer.stars do
      local s = layer.stars[i]
      local sx = s.x + ox
      local sy = s.y + oy
      if sx >= w then sx = sx - w end
      if sy >= h then sy = sy - h end
      if sx < 0 then sx = sx + w end
      if sy < 0 then sy = sy + h end
      love.graphics.circle('fill', math.floor(sx)+0.5, math.floor(sy)+0.5, s.s)
    end
  end

  -- Draw twinkling stars
  for i = 1, #self.twinkles do
    local tw = self.twinkles[i]
    local twinkleAlpha = tw.alpha * (0.3 + 0.7 * (math.sin(t * tw.twinkleSpeed + tw.phase) * 0.5 + 0.5))
    local twinkleSize = tw.baseSize * (0.8 + 0.4 * (math.sin(t * tw.twinkleSpeed * 0.5 + tw.phase) * 0.5 + 0.5))
    Theme.setColor(Theme.withAlpha(Theme.colors.text, twinkleAlpha))
    love.graphics.circle('fill', math.floor(tw.x)+0.5, math.floor(tw.y)+0.5, twinkleSize)
  end

  -- Draw comets with trails
  for i = 1, #self.comets do
    local comet = self.comets[i]

    -- Update comet position
    comet.x = comet.x + comet.vx
    comet.y = comet.y + comet.vy

    -- Reset comet when it goes off screen
    if comet.y > h + 100 then
      -- Reset to top with random horizontal position
      comet.x = math.random() * w
      comet.y = -50 - math.random() * 100
      -- Slight velocity variation for varying distances
      comet.vx = (math.random() - 0.5) * 0.4
      comet.vy = 0.8 + math.random() * 1.2
      -- Clear trail for clean restart
      comet.trail = {}
    end

    -- Horizontal wrapping for slight drift
    if comet.x > w + 50 then comet.x = -50 end
    if comet.x < -50 then comet.x = w + 50 end

    -- Update trail
    table.insert(comet.trail, 1, {x = comet.x, y = comet.y})
    if #comet.trail > comet.trailLength then
      table.remove(comet.trail)
    end

    -- Draw comet trail
    for j = 1, #comet.trail do
      local trailPos = comet.trail[j]
      local trailAlpha = comet.alpha * (j / #comet.trail) * 0.8
      local trailSize = comet.size * (0.3 + 0.7 * (j / #comet.trail))
      Theme.setColor(Theme.withAlpha(Theme.colors.accent, trailAlpha))
      love.graphics.circle('fill', math.floor(trailPos.x)+0.5, math.floor(trailPos.y)+0.5, trailSize)
    end

    -- Draw comet head
    Theme.setColor(Theme.withAlpha(Theme.colors.accent, comet.alpha))
    love.graphics.circle('fill', math.floor(comet.x)+0.5, math.floor(comet.y)+0.5, comet.size)

    -- Draw comet core (brighter center)
    Theme.setColor(Theme.withAlpha({1, 1, 1, 1}, comet.alpha * 0.9))
    love.graphics.circle('fill', math.floor(comet.x)+0.5, math.floor(comet.y)+0.5, comet.size * 0.4)
  end

  -- Enhanced main button with sci-fi styling
  local s = uiScale()
  local bw, bh = self.button.w * s, self.button.h * s
  local totalButtonHeight = bh * 4 + 40 * s -- 4 buttons now
  local startY = math.floor((h - totalButtonHeight) / 2)

  local bx = math.floor((w - bw) * 0.5)
  local by = startY
  local mx, my = Viewport.getMousePosition()
  local hover = mx >= bx and mx <= bx + bw and my >= by and my <= by + bh
  UIButton.drawRect(bx, by, bw, bh, "New Game", hover, t, { compact = true, menuButton = true })
  self.button._rect = { x = bx, y = by, w = bw, h = bh }

  local lbx = bx
  local lby = by + bh + 20 * s
  local lhover = mx >= lbx and mx <= lbx + bw and my >= lby and my <= lby + bh
  UIButton.drawRect(lbx, lby, bw, bh, "Load Game", lhover, t, { compact = true, menuButton = true })
  self.loadButton._rect = { x = lbx, y = lby, w = bw, h = bh }

  -- Join Multiplayer button
  local mbx = bx
  local mby = lby + bh + 20 * s
  local mhover = mx >= mbx and mx <= mbx + bw and my >= mby and my <= mby + bh
  UIButton.drawRect(mbx, mby, bw, bh, "Join Game", mhover, t, { compact = true, menuButton = true })
  self.multiplayerButton._rect = { x = mbx, y = mby, w = bw, h = bh }

  local versionText = Strings.getUI('version') or ""
  local baseFont = Theme.fonts and Theme.fonts.normal or love.graphics.getFont()
  local versionWidth = baseFont:getWidth(versionText)
  local versionButtonPadding = 20 * s
  local vbw = math.max(160 * s, versionWidth + versionButtonPadding)
  local vbh = bh
  local vbx = math.floor((w - vbw) * 0.5)
  local vby = math.floor(h - vbh - 40 * s)

  local vhover = mx >= vbx and mx <= vbx + vbw and my >= vby and my <= vby + vbh

  -- Use proper button system for version button
  UIButton.drawRect(vbx, vby, vbw, vbh, versionText, vhover, t, { 
    compact = true,
    color = {0, 0, 0, 0.3} -- Semi-transparent background
  })

  self.versionButton._rect = { x = vbx, y = vby, w = vbw, h = vbh }

  -- Settings button in top right (smaller)
  local settingsButtonSize = 32 * s
  local settingsButtonX = w - settingsButtonSize - 20 * s
  local settingsButtonY = 20 * s
  local settingsHover = mx >= settingsButtonX and mx <= settingsButtonX + settingsButtonSize and my >= settingsButtonY and my <= settingsButtonY + settingsButtonSize

  -- Use proper button system for settings button
  UIButton.drawRect(settingsButtonX, settingsButtonY, settingsButtonSize, settingsButtonSize, "", settingsHover, t, { 
    compact = true,
    color = {0, 0, 0, 0.3} -- Semi-transparent background
  })
  
  -- Draw cog icon on top of button
  Theme.setColor(settingsHover and {0.9, 0.9, 0.9, 1.0} or {0.7, 0.7, 0.7, 1.0})
  drawCogIcon(settingsButtonX + settingsButtonSize/2, settingsButtonY + settingsButtonSize/2, settingsButtonSize * 0.35)

  self.settingsButton._rect = { x = settingsButtonX, y = settingsButtonY, w = settingsButtonSize, h = settingsButtonSize }

  -- Exit button in top left (red X)
  local exitButtonSize = 32 * s
  local exitButtonX = 20 * s
  local exitButtonY = 20 * s
  local exitHover = mx >= exitButtonX and mx <= exitButtonX + exitButtonSize and my >= exitButtonY and my <= exitButtonY + exitButtonSize

  -- Use proper button system for exit button with red color
  local exitColor = exitHover and {1.0, 0.3, 0.3, 1.0} or {0.8, 0.2, 0.2, 1.0}
  UIButton.drawRect(exitButtonX, exitButtonY, exitButtonSize, exitButtonSize, "", exitHover, t, { 
    compact = true,
    color = exitColor
  })
  
  -- Draw X symbol on top of button
  Theme.setColor({1, 1, 1, 1})
  love.graphics.setLineWidth(3)
  local centerX = exitButtonX + exitButtonSize / 2
  local centerY = exitButtonY + exitButtonSize / 2
  local crossSize = exitButtonSize * 0.3
  love.graphics.line(centerX - crossSize, centerY - crossSize, centerX + crossSize, centerY + crossSize)
  love.graphics.line(centerX + crossSize, centerY - crossSize, centerX - crossSize, centerY + crossSize)

  self.exitButton._rect = { x = exitButtonX, y = exitButtonY, w = exitButtonSize, h = exitButtonSize }
  
  -- Draw join game window
  if self.showJoinUI and self.joinWindow then
    self.joinWindow:draw()
  end

  -- Draw load UI on top of everything else
  if self.showLoadUI and self.loadSlotsUI then
    -- Center the save/load panel on screen
    local sw, sh = Viewport.getDimensions()
    if self.loadSlotsUI.window then
      self.loadSlotsUI.window.x = math.floor((sw - self.loadSlotsUI.window.width) * 0.5)
      self.loadSlotsUI.window.y = math.floor((sh - self.loadSlotsUI.window.height) * 0.5)
      self.loadSlotsUI.window:show()
      self.loadSlotsUI.window:draw()
    end
  end

  SettingsPanel.draw()
  if VersionLog.visible then
    self.versionWindow:draw()
  end
  
  -- Draw notifications on top of everything else
  Notifications.draw()
  
  -- Version number in bottom right
end

function Start:drawJoinWindowContent(window, x, y, w, h)
  local s = uiScale()
  local padding = 20 * s
  
  -- Address input
  local inputY = y + 40 * s
  local inputW = 200 * s
  local inputH = 30 * s
  local inputX = x + (w - inputW) / 2
  
  -- Address label
  love.graphics.setFont(Theme.fonts.normal)
  Theme.setColor(Theme.colors.text)
  love.graphics.print("Server Address:", x + padding, inputY - 20 * s)
  
  -- Address input box
  Theme.setColor(Theme.colors.bg0)
  love.graphics.rectangle("fill", inputX, inputY, inputW, inputH)
  Theme.setColor(Theme.colors.border)
  love.graphics.rectangle("line", inputX, inputY, inputW, inputH)
  
  -- Address text
  Theme.setColor(Theme.colors.text)
  love.graphics.print(self.joinAddress, inputX + 5 * s, inputY + 5 * s)
  
  -- Port input
  local portY = inputY + 50 * s
  local portW = 100 * s
  local portH = 30 * s
  local portX = x + (w - portW) / 2
  
  -- Port label
  love.graphics.print("Port:", x + padding, portY - 20 * s)
  
  -- Port input box
  Theme.setColor(Theme.colors.bg0)
  love.graphics.rectangle("fill", portX, portY, portW, portH)
  Theme.setColor(Theme.colors.border)
  love.graphics.rectangle("line", portX, portY, portW, portH)
  
  -- Port text
  Theme.setColor(Theme.colors.text)
  love.graphics.print(self.joinPort, portX + 5 * s, portY + 5 * s)

  if self.joinErrorMessage then
    Theme.setColor(Theme.colors.danger)
    local messageY = portY + portH + 10 * s
    love.graphics.printf(self.joinErrorMessage, x + padding, messageY, w - padding * 2, "center")
  end

  -- Buttons
  local buttonW = 80 * s
  local buttonH = 30 * s
  local buttonYOffset = self.joinErrorMessage and 80 * s or 50 * s
  local buttonY = portY + buttonYOffset
  local joinX = x + (w - buttonW * 2 - 20 * s) / 2
  local cancelX = joinX + buttonW + 20 * s
  
  local mx, my = Viewport.getMousePosition()
  local joinHover = mx >= joinX and mx <= joinX + buttonW and my >= buttonY and my <= buttonY + buttonH
  local cancelHover = mx >= cancelX and mx <= cancelX + buttonW and my >= buttonY and my <= buttonY + buttonH
  
  -- Join button
  local isConnecting = _G.PENDING_MULTIPLAYER_CONNECTION and _G.PENDING_MULTIPLAYER_CONNECTION.connecting
  local buttonText = isConnecting and "Connecting..." or "Join"
  
  UIButton.drawRect(joinX, buttonY, buttonW, buttonH, buttonText, joinHover, love.timer.getTime(), { 
    compact = true,
    color = isConnecting and Theme.colors.bg2 or nil
  })
  
  -- Cancel button
  UIButton.drawRect(cancelX, buttonY, buttonW, buttonH, "Cancel", cancelHover, love.timer.getTime(), { 
    compact = true 
  })
  
  -- Store button positions for click handling
  self.joinButton = { x = joinX, y = buttonY, w = buttonW, h = buttonH }
  self.cancelButton = { x = cancelX, y = buttonY, w = buttonW, h = buttonH }
end

function Start:mousepressed(x, y, button)
  -- Check multiplayer UI first (highest priority)
  if self.showJoinUI and self.joinWindow then
    -- Handle window interactions first
    if self.joinWindow:mousepressed(x, y, button) then
      return false
    end
    
    -- Handle custom button clicks within the window
    if self.joinButton and x >= self.joinButton.x and x <= self.joinButton.x + self.joinButton.w and
       y >= self.joinButton.y and y <= self.joinButton.y + self.joinButton.h then
      -- Check if already connecting
      if _G.PENDING_MULTIPLAYER_CONNECTION and _G.PENDING_MULTIPLAYER_CONNECTION.connecting then
        print("Already connecting, please wait...")
        return false
      end
      
      -- Join button clicked
      print("Join button clicked at", x, y)
      local port = tonumber(self.joinPort) or 7777
      print("Attempting to join game at", self.joinAddress, port)

      self.joinErrorMessage = nil

      -- Store connection info globally for Game.load to use
      _G.PENDING_MULTIPLAYER_CONNECTION = {
        address = self.joinAddress,
        port = port,
        connected = false, -- Will be set to true when connection is confirmed
        connecting = true
      }

      -- Close UI and trigger game transition immediately
      -- Let the global network manager handle the actual connection
      self.showJoinUI = false
      self.joinWindow:hide()
      _G.TRIGGER_JOIN_GAME = true
      return false
    elseif self.cancelButton and x >= self.cancelButton.x and x <= self.cancelButton.x + self.cancelButton.w and
           y >= self.cancelButton.y and y <= self.cancelButton.y + self.cancelButton.h then
      -- Cancel button clicked
      print("Cancel button clicked")
      self.showJoinUI = false
      self.joinErrorMessage = nil
      self.joinWindow:hide()
      _G.PENDING_MULTIPLAYER_CONNECTION = nil
      return false
    end
    return false -- Consume all clicks when multiplayer UI is open
  end

  -- Check load UI second
  if self.showLoadUI and self.loadSlotsUI then
    -- Handle SaveLoad panel interactions
    if self.loadSlotsUI.window and self.loadSlotsUI.window:mousepressed(x, y, button) then
      if not self.loadSlotsUI.window.visible then
        -- Panel was closed
        self.showLoadUI = false
        return false
      end
      return false -- Click was handled by the panel; do not start game
    end

    -- Handle content area clicks
    local loadResult = self.loadSlotsUI:mousepressed(x, y, button)
    if loadResult then
      if loadResult == "loaded" then
        -- Game was successfully loaded, close the load UI and start the game
        self.showLoadUI = false
        -- Get the selected slot name and extract slot number
        local selectedSlotName = self.loadSlotsUI.saveSlots:getSelectedSlotName()
        if selectedSlotName then
          local slotNumber = selectedSlotName:match("slot(%d+)")
          if slotNumber then
            self.loadedSlot = tonumber(slotNumber)
            return "loadGame" -- Signal to load the game
          end
        end
        return true -- Fallback to start new game
      elseif loadResult == "autosaveLoaded" then
        -- Auto-save was successfully loaded, close the load UI and start the game
        self.showLoadUI = false
        self.loadedSlot = "autosave" -- Special marker for autosave
        return "loadGame" -- Signal to load the game
      end
      return false -- Click was handled by the panel; do not start game
    end

    -- Consume all clicks when load UI is open
    return false
  end
  
  
  if SettingsPanel.mousepressed(x, y, button) then
    return false
  end

  if VersionLog.visible then
    if self.versionWindow:mousepressed(x, y, button) then
      return false
    end
    if VersionLog.mousepressed(x, y, button) then
      return false
    end
  end

  return startScreenHandler(self, x, y, button)
end

function Start:mousereleased(x, y, button)
  if self.showJoinUI and self.joinWindow then
    self.joinWindow:mousereleased(x, y, button)
  end
  if self.showLoadUI and self.loadSlotsUI and self.loadSlotsUI.window then
    self.loadSlotsUI.window:mousereleased(x, y, button)
  end
  SettingsPanel.mousereleased(x, y, button)
  if VersionLog.visible then
    self.versionWindow:mousereleased(x, y, button)
    VersionLog.mousereleased(x, y, button)
  end
end

function Start:mousemoved(x, y, dx, dy)
  if self.showJoinUI and self.joinWindow then
    self.joinWindow:mousemoved(x, y, dx, dy)
  end
  if self.showLoadUI and self.loadSlotsUI and self.loadSlotsUI.window then
    self.loadSlotsUI.window:mousemoved(x, y, dx, dy)
  end
  SettingsPanel.mousemoved(x, y, dx, dy)
  if VersionLog.visible then
    self.versionWindow:mousemoved(x, y, dx, dy)
    VersionLog.mousemoved(x, y, dx, dy)
  end
end

function Start:wheelmoved(x, y, dx, dy)
  if SettingsPanel.visible and SettingsPanel.wheelmoved(x, y, dx, dy) then
    return true
  end

  if VersionLog.visible then
    local windowWheel = self.versionWindow and self.versionWindow.wheelmoved
    if windowWheel and windowWheel(self.versionWindow, x, y, dx, dy) then
      return true
    end
    if VersionLog.wheelmoved(x, y, dx, dy) then
      return true
    end
  end

  return false
end

function Start:onJoinFailed(message)
  if self.networkManager then
    self.networkManager:leaveGame()
  end
  if type(message) ~= "string" then
    message = message and tostring(message) or nil
  end
  self.joinErrorMessage = message or "Failed to connect to server."
  self.showJoinUI = true
  if self.joinWindow then
    self.joinWindow:show()
  end
end

function Start:keypressed(key)
    -- Handle ESC key to exit game
    if key == "escape" then
        love.event.quit()
        return true
    end

    -- Test notifications with number keys
    if key == "1" then
        Notifications.info("This is an info notification from the start screen!")
        return true
    elseif key == "2" then
        Notifications.action("This is an action notification from the start screen!")
        return true
    elseif key == "3" then
        Notifications.add("This is a success notification!", "success")
        return true
    elseif key == "4" then
        Notifications.add("This is a warning notification!", "warning")
        return true
    elseif key == "5" then
        Notifications.add("This is an error notification!", "error")
        return true
    end

    -- Handle load UI key presses
    if self.showLoadUI and self.loadSlotsUI then
        if self.loadSlotsUI:keypressed(key) then
            return true
        end
        return true -- Consume all key presses when load UI is open
    end


    if SettingsPanel.keypressed(key) then
      return true
    end
  if VersionLog.visible and VersionLog.keypressed(key) then
    return true
  end
    return false
end

function Start:textinput(text)
    if self.showLoadUI and self.loadSlotsUI then
        return self.loadSlotsUI:textinput(text)
    end
    return false
end

return Start
