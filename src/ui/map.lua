--[[
  Map UI
  
  Clean, self-contained map system using modular components.
  Handles both full map and minimap rendering through shared systems.
]]

local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Window = require("src.ui.common.window")
local Discovery = require("src.systems.discovery")
local MapEntities = require("src.systems.map_entities")
local MapRenderer = require("src.systems.map_renderer")
local Sound = require("src.core.sound")

local Map = {
    visible = false,
    dragging = false,
    dragStartX = 0,
    dragStartY = 0,
    dragOffsetX = 0,
    dragOffsetY = 0,
    scale = 1.0,
    dragSpeed = 2.0,
    minScale = 0.1,
    maxScale = 3.0,
    centerX = 0,
    centerY = 0,
    gridSize = 1000,
    showGrid = true,
    showEntities = true,
    showTrails = false,
    filterEnemies = true,
    filterAsteroids = true,
    filterWrecks = true,
    filterStations = true,
    lastPlayerPos = { x = 0, y = 0 },
    playerTrail = {},
    maxTrailLength = 100,
    window = nil,
    contentPadding = 12,
    _contentBounds = nil,
    _mapBounds = nil,
    _drawPlayer = nil,
    _drawWorld = nil,
    _hasCenteredOnPlayer = false,
}

local function ensureWindow()
    if Map.window then
        return Map.window
    end

    Map.window = Window.new({
        title = "Galaxy Map",
        width = 960,
        height = 720,
        minWidth = 640,
        minHeight = 480,
        resizable = true,
        maximizable = true,
        drawContent = function(_, x, y, w, h)
            Map.drawContent(x, y, w, h)
        end,
        onClose = function()
            Map.visible = false
            Map.dragging = false
            Map._drawPlayer = nil
            Map._drawWorld = nil
            Map._mapBounds = nil
            Map._contentBounds = nil
            Sound.triggerEvent('ui_button_click')
        end,
    })

    return Map.window
end

function Map.init()
    ensureWindow()
end

function Map.isVisible()
    return Map.visible == true
end

function Map.show()
    local window = ensureWindow()
    Map.visible = true
    window:show()

    if not Map._hasCenteredOnPlayer then
        Map.centerX = Map.lastPlayerPos.x or Map.centerX
        Map.centerY = Map.lastPlayerPos.y or Map.centerY
        Map._hasCenteredOnPlayer = true
    end

    Sound.playSFX("ui_click")
end

function Map.hide()
    Map.visible = false
    if Map.window and Map.window.visible then
        Map.window:hide()
    end
end

function Map.toggle()
    if Map.visible then
        Map.hide()
    else
        Map.show()
    end
end

local function pointIn(px, py, r)
    if px == nil or py == nil or r == nil or r.x == nil or r.y == nil or r.w == nil or r.h == nil then
        return false
    end
    return px >= r.x and py >= r.y and px <= r.x + r.w and py <= r.y + r.h
end

local function getMapBounds()
    if Map._mapBounds then
        return Map._mapBounds.x, Map._mapBounds.y, Map._mapBounds.w, Map._mapBounds.h
    end

    if Map.window then
        local content = Map.window:getContentBounds()
        if content then
            local pad = Map.contentPadding or 0
            local mapX = content.x + pad
            local mapY = content.y + pad
            local mapW = math.max(0, content.w - pad * 2)
            local mapH = math.max(0, content.h - pad * 2)
            return mapX, mapY, mapW, mapH
        end
    end

    local sw, sh = Viewport.getDimensions()
    local mapW, mapH = sw * 0.8, sh * 0.8
    local mapX, mapY = (sw - mapW) / 2, (sh - mapH) / 2
    return mapX, mapY, mapW, mapH
end

local function getMapState()
    return {
        centerX = Map.centerX,
        centerY = Map.centerY,
        scale = Map.scale,
        dragOffsetX = Map.dragOffsetX or 0,
        dragOffsetY = Map.dragOffsetY or 0,
        gridSize = Map.gridSize,
        showGrid = Map.showGrid,
        showEntities = Map.showEntities,
        showTrails = Map.showTrails,
        filterEnemies = Map.filterEnemies,
        filterAsteroids = Map.filterAsteroids,
        filterWrecks = Map.filterWrecks,
        filterStations = Map.filterStations,
    }
end

function Map.update(dt, player)
    if not player or not player.components or not player.components.position then
        return
    end

    local pos = player.components.position
    Map.lastPlayerPos.x = pos.x
    Map.lastPlayerPos.y = pos.y

    local State = require("src.game.state")
    local world = State.world
    Map._drawWorld = world
    Discovery.update(player, world)

    if Map.showTrails then
        table.insert(Map.playerTrail, { x = pos.x, y = pos.y, time = love.timer.getTime() })
        if #Map.playerTrail > Map.maxTrailLength then
            table.remove(Map.playerTrail, 1)
        end
    end
end

function Map.draw(player, world)
    if not Map.visible or not player then
        return
    end

    local window = ensureWindow()
    local State = require("src.game.state")
    local activeWorld = world or Map._drawWorld or State.world
    if not activeWorld then
        return
    end

    Map._drawPlayer = player
    Map._drawWorld = activeWorld
    Map._mapBounds = nil

    window.visible = true
    window:draw()
end

function Map.drawContent(x, y, w, h)
    Map._contentBounds = { x = x, y = y, w = w, h = h }

    local pad = Map.contentPadding or 0
    local mapX = x + pad
    local mapY = y + pad
    local mapW = math.max(0, w - pad * 2)
    local mapH = math.max(0, h - pad * 2)

    Map._mapBounds = { x = mapX, y = mapY, w = mapW, h = mapH }

    local player = Map._drawPlayer
    local world = Map._drawWorld
    if not player or not world then
        return
    end

    local mapState = getMapState()
    local viewport = {
        type = "full_map",
        mapX = mapX,
        mapY = mapY,
        mapW = mapW,
        mapH = mapH,
        mapState = mapState,
        showGrid = Map.showGrid,
        gridSize = Map.gridSize,
    }

    local filters = {
        stations = Map.filterStations,
        enemies = Map.filterEnemies,
        asteroids = Map.filterAsteroids,
        wrecks = Map.filterWrecks,
        warp_gates = true,
        remote_players = true,
    }

    local entities = MapEntities.getVisibleEntities(world, Discovery, filters)

    MapRenderer.drawFullMap(player, world, entities, Discovery, viewport)
    Map.drawUI(mapX, mapY, mapW, mapH)
end

function Map.drawUI(mapX, mapY, mapW, mapH)
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", mapX, mapY, mapW, mapH)

    local controlX = mapX + 18
    local controlY = mapY + 22
    local oldFont = love.graphics.getFont()
    local smallFont = Theme.getFont("small") -- Use small instead of xsmall for better readability
    local lineHeight = 16
    local panelWidth = 210
    local textPad = 12
    local topPad = 14
    local bottomPad = 14
    
    -- Legend entries (display-only)
    local legend = {
        { label = "Player", color = Theme.colors.accent },
        { label = "Stations", color = Theme.colors.textSecondary },
        { label = "Enemies", color = Theme.colors.danger },
        { label = "Asteroids", color = Theme.colors.textTertiary },
        { label = "Wrecks", color = Theme.colors.warning },
        { label = "Warp Gates", color = Theme.colors.info },
        { label = "Remote Players", color = Theme.colors.success },
    }

    local infoLines = 4 + #legend -- scale + legend title + items + help lines (2)
    local panelHeight = topPad + bottomPad + infoLines * lineHeight

    Theme.setColor(Theme.colors.bg2)
    love.graphics.rectangle("fill", controlX - textPad, controlY - topPad, panelWidth, panelHeight)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle("line", controlX - textPad, controlY - topPad, panelWidth, panelHeight)

    Theme.setFont("small")

    Theme.setColor(Theme.colors.text)
    Theme.drawTextFit(string.format("Scale: %.2fx", Map.scale), controlX, controlY, panelWidth - textPad * 2, 'left', smallFont, 0.5, 1.2)
    controlY = controlY + lineHeight

    -- Legend title
    Theme.setColor(Theme.colors.textSecondary)
    Theme.drawTextFit("Legend", controlX, controlY, panelWidth - textPad * 2, 'left', smallFont, 0.5, 1.2)
    controlY = controlY + lineHeight

    -- Legend items with colored squares
    for _, item in ipairs(legend) do
        local boxSize = 8
        Theme.setColor(item.color)
        love.graphics.rectangle("fill", controlX, controlY + math.floor((lineHeight - boxSize) * 0.5), boxSize, boxSize)
        Theme.setColor(Theme.colors.border)
        love.graphics.rectangle("line", controlX, controlY + math.floor((lineHeight - boxSize) * 0.5), boxSize, boxSize)
        Theme.setColor(Theme.colors.text)
        Theme.drawTextFit(item.label, controlX + boxSize + 6, controlY, panelWidth - textPad * 2 - (boxSize + 6), 'left', smallFont, 0.5, 1.2)
        controlY = controlY + lineHeight
    end

    -- Guidance lines
    Theme.setColor(Theme.colors.text)
    Theme.drawTextFit("Drag: Left Mouse", controlX, controlY, panelWidth - textPad * 2, 'left', smallFont, 0.5, 1.2)
    controlY = controlY + lineHeight
    Theme.drawTextFit("Zoom: Mouse Wheel", controlX, controlY, panelWidth - textPad * 2, 'left', smallFont, 0.5, 1.2)


    if oldFont then love.graphics.setFont(oldFont) end
end

function Map.mousepressed(x, y, button)
    if not Map.visible then
        return false
    end

    local window = Map.window
    if window and window:mousepressed(x, y, button) then
        return true
    end

    local mapX, mapY, mapW, mapH = getMapBounds()
    if not pointIn(x, y, { x = mapX, y = mapY, w = mapW, h = mapH }) then
        return false
    end

    if button == 1 then
        Map.dragging = true
        Map.dragStartX = x
        Map.dragStartY = y
        Map.dragOffsetX = Map.centerX
        Map.dragOffsetY = Map.centerY
        return true
    end

    return false
end

function Map.mousemoved(x, y, dx, dy)
    if not Map.visible then
        return false
    end

    -- Prioritize map dragging so window hover/resize can't swallow movement
    if Map.dragging then
        local world = Map._drawWorld
        if not world then
            return false
        end

        local scale = Map.scale
        local speed = Map.dragSpeed or 1.0
        local newCenterX = Map.dragOffsetX - (x - Map.dragStartX) * (speed / scale)
        local newCenterY = Map.dragOffsetY - (y - Map.dragStartY) * (speed / scale)

        local worldWidth = world.width or Map.centerX
        local worldHeight = world.height or Map.centerY
        Map.centerX = math.max(0, math.min(worldWidth, newCenterX))
        Map.centerY = math.max(0, math.min(worldHeight, newCenterY))

        return true
    end

    -- Not dragging: allow the window to handle movement (resize/drag/title bar)
    local window = Map.window
    if window and window:mousemoved(x, y, dx, dy) then
        return true
    end

    return false
end

function Map.mousereleased(x, y, button)
    if not Map.visible then
        return false
    end

    local window = Map.window
    if window and window:mousereleased(x, y, button) then
        return true
    end

    if button == 1 and Map.dragging then
        Map.dragging = false
        return true
    end

    return false
end

function Map.wheelmoved(x, y)
    if not Map.visible then
        return false
    end

    local mapX, mapY, mapW, mapH = getMapBounds()
    local mx, my = Viewport.getMousePosition()
    if not pointIn(mx, my, { x = mapX, y = mapY, w = mapW, h = mapH }) then
        return false
    end

    local oldScale = Map.scale
    Map.scale = math.max(Map.minScale, math.min(Map.maxScale, Map.scale * (1 + y * 0.1)))

    if Map.scale ~= oldScale then
        local world = Map._drawWorld
        if world then
            local worldWidth = world.width or Map.centerX
            local worldHeight = world.height or Map.centerY
            local mouseWorldX = Map.centerX + (mx - mapX - mapW / 2) / oldScale
            local mouseWorldY = Map.centerY + (my - mapY - mapH / 2) / oldScale

            Map.centerX = mouseWorldX - (mx - mapX - mapW / 2) / Map.scale
            Map.centerY = mouseWorldY - (my - mapY - mapH / 2) / Map.scale

            Map.centerX = math.max(0, math.min(worldWidth, Map.centerX))
            Map.centerY = math.max(0, math.min(worldHeight, Map.centerY))
        end
        return true
    end

    return false
end

function Map.keypressed(key)
    if not Map.visible then
        return false
    end

    if key == "g" then
        Map.showGrid = not Map.showGrid
        Sound.playSFX("ui_click")
        return true
    elseif key == "t" then
        Map.showTrails = not Map.showTrails
        Sound.playSFX("ui_click")
        return true
    elseif key == "s" then
        Map.filterStations = not Map.filterStations
        Sound.playSFX("ui_click")
        return true
    elseif key == "e" then
        Map.filterEnemies = not Map.filterEnemies
        Sound.playSFX("ui_click")
        return true
    elseif key == "a" then
        Map.filterAsteroids = not Map.filterAsteroids
        Sound.playSFX("ui_click")
        return true
    elseif key == "w" then
        Map.filterWrecks = not Map.filterWrecks
        Sound.playSFX("ui_click")
        return true
    end

    return false
end

-- Expose discovery functions for minimap
function Map.ensureDiscovery(world)
    Discovery.init(world)
end

function Map.isDiscovered(wx, wy)
    return Discovery.isDiscovered(wx, wy)
end

function Map.getDiscovery()
    return Discovery
end

function Map.revealAt(wx, wy, radius)
    Discovery.revealAt(wx, wy, radius)
end

function Map.getDiscoveryForSave()
    return Discovery.serialize()
end

function Map.setDiscoveryFromSave(data)
    local world = require("src.core.world")
    Discovery.deserialize(data, world)
end

return Map
