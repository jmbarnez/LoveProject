local Viewport = {}

local Log = require("src.core.log")
local Constants = require("src.core.constants")
local Settings = require("src.core.settings")
local Theme = require("src.core.theme")

-- Default virtual resolution (16:9)
local vw, vh = Constants.RESOLUTION.DEFAULT_WIDTH, Constants.RESOLUTION.DEFAULT_HEIGHT
local winW, winH = Constants.RESOLUTION.DEFAULT_WIDTH, Constants.RESOLUTION.DEFAULT_HEIGHT
local scale = 1
local ox, oy = 0, 0
local canvas

local function ensureCanvas()
    if not canvas or canvas:getWidth() ~= vw or canvas:getHeight() ~= vh then
        canvas = love.graphics.newCanvas(vw, vh)
        canvas:setFilter("nearest", "nearest", 1)
    end
end

function Viewport.init(virtualW, virtualH)
    vw = virtualW or vw or Constants.RESOLUTION.DEFAULT_WIDTH
    vh = virtualH or vh or Constants.RESOLUTION.DEFAULT_HEIGHT
    ensureCanvas()
    Viewport.resize(love.graphics.getWidth(), love.graphics.getHeight())
end

function Viewport.resize(w, h)
    -- Handle invalid dimensions gracefully
    if not w or not h or w <= 0 or h <= 0 then
        if Log and Log.warn then
            Log.warn("Invalid viewport dimensions: " .. tostring(w) .. "x" .. tostring(h))
        end
        return
    end

    winW, winH = w, h

    -- Ensure virtual dimensions are valid
    if not vw or not vh or vw <= 0 or vh <= 0 then
        vw = Constants.RESOLUTION.DEFAULT_WIDTH
        vh = Constants.RESOLUTION.DEFAULT_HEIGHT
    end

    -- Calculate viewport scale without UI scale affecting it
    local sx = w / vw
    local sy = h / vh
    scale = math.min(sx, sy)

    -- Ensure scale is valid
    if scale <= 0 or scale == math.huge then
        scale = 1
    end

    local sw = math.floor(vw * scale + 0.5)
    local sh = math.floor(vh * scale + 0.5)
    ox = math.floor((w - sw) / 2)
    oy = math.floor((h - sh) / 2)

    -- Ensure offsets are valid
    if ox ~= ox or oy ~= oy then -- Check for NaN
        ox, oy = 0, 0
    end

    -- Reload fonts to ensure they're the right size for the new resolution
    local success, err = pcall(function()
        if Theme and Theme.loadFonts then
            Theme.loadFonts()
        end
    end)
    if not success and Log and Log.warn then
        Log.warn("Failed to reload fonts on resize: " .. tostring(err))
    end
end

function Viewport.begin()
    ensureCanvas()
    love.graphics.push('all')
    -- Enable stencil writes while rendering to the virtual canvas
    love.graphics.setCanvas({ canvas, stencil = true })
    -- Do not clear here; let game decide its clear color
end

function Viewport.finish()
  love.graphics.setCanvas()
  -- The backbuffer is no longer cleared to prevent rendering issues.
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas, ox, oy, 0, scale, scale)
  love.graphics.pop()
end

function Viewport.toVirtual(x, y)
  -- Ensure we have valid numbers before doing arithmetic
  if x == nil or y == nil then
    return 0, 0
  end

  -- Use default values if variables are nil (defensive programming)
  local currentScale = scale or 1
  local currentOx = ox or 0
  local currentOy = oy or 0

  -- Ensure scale is not zero to avoid division by zero
  if currentScale == 0 then
    return 0, 0
  end

  return (x - currentOx) / currentScale, (y - currentOy) / currentScale
end

function Viewport.toScreen(x, y)
  -- Use default values if variables are nil (defensive programming)
  local currentScale = scale or 1
  local currentOx = ox or 0
  local currentOy = oy or 0

  return x * currentScale + currentOx, y * currentScale + currentOy
end

function Viewport.getMousePosition()
  local mx, my = love.mouse.getPosition()
  -- Handle case where mouse position might be nil
  if mx == nil or my == nil then
    return 0, 0
  end

  -- Ensure Viewport is properly initialized before converting coordinates
  -- Use default values if variables are nil (defensive programming)
  local currentScale = scale or 1
  local currentOx = ox or 0
  local currentOy = oy or 0

  if currentScale == 0 then
    return 0, 0
  end

  return Viewport.toVirtual(mx, my)
end

function Viewport.getScale()
  -- Use default value if scale is nil (defensive programming)
  return scale or 1
end

function Viewport.getOffset()
  -- Use default values if variables are nil (defensive programming)
  local currentOx = ox or 0
  local currentOy = oy or 0
  return currentOx, currentOy
end

function Viewport.getDimensions()
  -- Use default values if variables are nil (defensive programming)
  local currentVw = vw or Constants.RESOLUTION.DEFAULT_WIDTH
  local currentVh = vh or Constants.RESOLUTION.DEFAULT_HEIGHT
  return currentVw, currentVh
end

function Viewport.getUIScale()
  local graphicsSettings = Settings.getGraphicsSettings()
  return graphicsSettings.ui_scale or 1.0
end

function Viewport.getFontScale()
  local graphicsSettings = Settings.getGraphicsSettings()
  return graphicsSettings.font_scale or 1.0
end

function Viewport.isInsideScreen(x, y)
  return x >= ox and y >= oy and x <= ox + vw * scale and y <= oy + vh * scale
end

function Viewport.getCanvas()
    return canvas
end

return Viewport
