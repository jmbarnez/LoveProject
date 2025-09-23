local Input = require("src.core.input")
local Viewport = require("src.core.viewport")
local Theme = require("src.core.theme")
local SaveSlots = require("src.ui.save_slots")
local StateManager = require("src.managers.state_manager")
local World = require("src.core.world")
local AuroraTitle = require("src.shaders.aurora_title")
local Sound = require("src.core.sound")
local SettingsPanel = require("src.ui.settings_panel")
local UIButton = require("src.ui.common.button")
local Strings = require("src.core.strings")

local Start = {}
Start.__index = Start

-- Start screen input handler
local startScreenHandler = function(self, x, y, button)
  if button ~= 1 then return false end

  -- Load Game button click
  if Theme.handleButtonClick(self.loadButton, x, y, function()
    self.showLoadUI = true
  end) then
    return false -- don't start game, show load UI
  end

  -- No exit button - use Escape key or Alt+F4 instead


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
  self.loadSlotsUI = SaveSlots:new()
  self.loadSlotsUI:setMode("load")
  self.showLoadUI = false
  -- Cache large title font (Press Start 2P)
  self.titleFont = love.graphics.newFont("assets/fonts/PressStart2P-Regular.ttf", 80)
  self.titleFont:setFilter('nearest', 'nearest', 1)
  -- Aurora title shader
  self.auroraShader = AuroraTitle.new()
  self.blurCanvas = love.graphics.newCanvas(self.w, self.h)

  -- Button effect states
  self.newGameScale = 1.0

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

   -- Update button effects
   local t = love.timer.getTime()

   -- Update button scales (pulsing)
   self.newGameScale = 0.95 + 0.05 * math.sin(t * 2)
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
  local s = uiScale()
  local bw, bh = self.button.w * s, self.button.h * s
  local totalButtonHeight = bh * 2 + 20 * s
  local startY = math.floor((h - totalButtonHeight) / 2)

  -- New Game button
  local bx = math.floor((w - bw) * 0.5)
  local by = startY
  local mx, my = Viewport.getMousePosition()
  local hover = mx >= bx and mx <= bx + bw and my >= by and my <= by + bh

  -- Draw NEW GAME button with scaling
  love.graphics.push()
  love.graphics.translate(bx + bw/2, by + bh/2)
  love.graphics.scale(self.newGameScale, self.newGameScale)
  love.graphics.translate(-bw/2, -bh/2)
  UIButton.drawRect(0, 0, bw, bh, Strings.getUI('new_game'), hover, t, { compact = true, menuButton = true })
  love.graphics.pop()

  -- Set button rect in world coordinates for click detection
  self.button._rect = { x = bx, y = by, w = bw * self.newGameScale, h = bh * self.newGameScale }

  -- Load Game button
  local lbx = bx
  local lby = by + bh + 20 * s
  local lhover = mx >= lbx and mx <= lbx + bw and my >= lby and my <= lby + bh

  -- Draw LOAD GAME button with scaling
  love.graphics.push()
  love.graphics.translate(lbx + bw/2, lby + bh/2)
  love.graphics.scale(self.newGameScale, self.newGameScale)
  love.graphics.translate(-bw/2, -bh/2)
  UIButton.drawRect(0, 0, bw, bh, Strings.getUI('load_game'), lhover, t, { compact = true, menuButton = true })
  love.graphics.pop()

  -- Set button rect in world coordinates for click detection
  self.loadButton._rect = { x = lbx, y = lby, w = bw * self.newGameScale, h = bh * self.newGameScale }


-- No exit button - users can use Escape key or Alt+F4 to exit


  
  -- Draw load UI on top of everything else
  if self.showLoadUI then
    
    -- Draw load slots UI with dynamic sizing
    local contentW, contentH = 600, 500
    if self.loadSlotsUI and self.loadSlotsUI.getPreferredSize then
      contentW, contentH = self.loadSlotsUI:getPreferredSize()
    end
    local framePaddingX, framePaddingY = 20, 60
    local loadW, loadH = contentW + framePaddingX, contentH + framePaddingY
    local loadX = (w - loadW) / 2
    local loadY = (h - loadH) / 2
    
    -- Background
    -- Frosted glass effect (blur)
    -- Frosted glass effect (blur)
    love.graphics.setCanvas({self.blurCanvas, stencil = true})
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(Viewport.getCanvas(), 0, 0)
    love.graphics.setCanvas(Viewport.getCanvas())
    love.graphics.setShader(Theme.shaders.ui_blur)
    love.graphics.setColor(1, 1, 1, 0.8) -- Control blur intensity
    love.graphics.draw(self.blurCanvas, 0, 0)
    love.graphics.setShader()

    -- Sci-fi frame
    Theme.drawSciFiFrame(loadX, loadY, loadW, loadH)
    
    -- Back button
    local backButtonW, backButtonH = 80, 30
    local backButtonX, backButtonY = loadX + 10, loadY + 10
    local mx, my = Viewport.getMousePosition()
    local backHover = mx >= backButtonX and mx <= backButtonX + backButtonW and my >= backButtonY and my <= backButtonY + backButtonH
    self.backButtonRect = UIButton.drawRect(backButtonX, backButtonY, backButtonW, backButtonH, Strings.getUI("back_button"), backHover, love.timer.getTime(), { menuButton = true })
    
    -- Load slots content
    if self.loadSlotsUI then
      self.loadSlotsUI:draw(loadX + 10, loadY + 50, loadW - 20, loadH - 60)
    end
  end

  SettingsPanel.draw()
  
  -- Version number in bottom right
  Theme.setColor(Theme.colors.textSecondary)
  local versionText = Strings.getUI("version")
  local font = love.graphics.getFont()
  local textWidth = font:getWidth(versionText)
  love.graphics.print(versionText, w - textWidth - 16, h - 20)
end

function Start:mousepressed(x, y, button)
  -- Check load UI first (highest priority)
  if self.showLoadUI then
    local w, h = self.w, self.h
    local loadW, loadH = 600, 500
    local loadX = (w - loadW) / 2
    local loadY = (h - loadH) / 2
    
    -- Check back button using Theme.handleButtonClick for consistent behavior
    if Theme.handleButtonClick({ _rect = self.backButtonRect }, x, y, function()
      self.showLoadUI = false
    end) then
      return false
    end
    
    -- Handle load slots UI clicks
    if self.loadSlotsUI then
      local result = self.loadSlotsUI:mousepressed(x, y, button, loadX + 10, loadY + 50, loadW - 20, loadH - 60)
      if result == "loaded" then
        -- Game was loaded, signal to main.lua to start the game
        self.showLoadUI = false
        return "loadGame"
      elseif result == "loadSelected" then
        -- Player selected a slot to load, signal to main.lua to start the game
        self.showLoadUI = false
        return "loadGame"
      elseif result == "deleted" then
        -- File was deleted, just refresh the interface
        return false
      elseif result then
        return false
      end
    end
    
    -- Consume all clicks when load UI is open
    return false
  end
  
  
  if SettingsPanel.mousepressed(x, y, button) then
    return false
  end

  return startScreenHandler(self, x, y, button)
end

function Start:mousereleased(x, y, button)
  SettingsPanel.mousereleased(x, y, button)
end

function Start:mousemoved(x, y, dx, dy)
  SettingsPanel.mousemoved(x, y, dx, dy)
end

function Start:wheelmoved(x, y, dx, dy)
  if SettingsPanel.visible then
    return SettingsPanel.wheelmoved(x, y, dx, dy)
  end
  return false
end

function Start:keypressed(key)
    -- Handle ESC key to exit game
    if key == "escape" then
        love.event.quit()
        return true
    end

    -- Handle load UI key presses
    if self.showLoadUI then
        return true -- Consume all key presses when load UI is open
    end


    if SettingsPanel.keypressed(key) then
      return true
    end
    return false
end

function Start:textinput(text)
    return false
end

return Start
