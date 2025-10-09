local State = require("src.game.state")

local RenderSystem = require("src.systems.render")
local Effects = require("src.systems.effects")
local UI = require("src.ui.hud.root")
local UIManager = require("src.core.ui_manager")
local Theme = require("src.core.theme")
local NetworkSync = require("src.systems.network_sync")
local InteractionSystem = require("src.systems.interaction")
local QuestLogHUD = require("src.ui.hud.quest_log")
local Viewport = require("src.core.viewport")
local Indicators = require("src.systems.render.indicators")
local PostProcessing = require("src.systems.post_processing")

local Draw = {}

function Draw.draw(Game)
    local world = State.world
    local camera = State.camera
    local player = State.player
    local hub = State.hub

    if not world or not camera then
        return
    end

    local flashAlpha = Theme.getScreenFlashAlpha()
    local zoomScale = Theme.getScreenZoomScale()

    camera:apply(0, 0, zoomScale)

    world:drawBackground(camera)
    if DEBUG_DRAW_BOUNDS then world:drawBounds() end

    RenderSystem.draw(world, camera, player, State.clickMarkers, State.hoveredEntity, State.hoveredEntityType)
    Effects.draw()
    
    -- Draw construction system
    local ConstructionSystem = require("src.systems.construction")
    ConstructionSystem.draw()
    
    camera:reset()

    UI.drawHelpers(player, world, hub, camera)

    local remotePlayerEntities = NetworkSync.getRemotePlayers()
    local remotePlayerSnapshots = NetworkSync.getRemotePlayerSnapshots()
    UI.drawHUD(player, world, world:get_entities_with_components("ai"), hub, world:get_entities_with_components("wreckage"), {}, camera, remotePlayerEntities, remotePlayerSnapshots)

    InteractionSystem.draw(player, camera)
    QuestLogHUD.draw(player)

    if UIManager.isOpen("escape") then
        local viewportWidth, viewportHeight = Viewport.getDimensions()

        if Game.blurCanvas then
            local canvasWidth, canvasHeight = Game.blurCanvas:getDimensions()
            if canvasWidth ~= viewportWidth or canvasHeight ~= viewportHeight then
                if Game.blurCanvas.release then
                    Game.blurCanvas:release()
                end
                Game.blurCanvas = nil
            end
        end

        if not Game.blurCanvas then
            Game.blurCanvas = love.graphics.newCanvas(viewportWidth, viewportHeight)
        end

        local currentCanvas = love.graphics.getCanvas()
        local okBlur, errBlur = xpcall(function()
            love.graphics.setCanvas({ Game.blurCanvas, stencil = true })
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(Viewport.getCanvas(), 0, 0)
        end, debug.traceback)
        love.graphics.setCanvas(currentCanvas)

        if not okBlur then
            local Log = require("src.core.log")
            if Log and Log.warn then
                Log.warn("UI blur render failed: " .. tostring(errBlur))
            end
        else
            love.graphics.setShader(Theme.shaders.ui_blur)
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.draw(Game.blurCanvas, 0, 0)
            love.graphics.setShader()
        end

        UIManager.draw(player, world, world:get_entities_with_components("ai"), hub, world:get_entities_with_components("wreckage"), {}, {})
    else
        UIManager.draw(player, world, world:get_entities_with_components("ai"), hub, world:get_entities_with_components("wreckage"), {}, {})
    end

    Theme.drawParticles()
    if flashAlpha > 0 then
        Theme.setColor({1, 1, 1, flashAlpha})
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end

    Indicators.drawTargetingBorder(world)
end

return Draw
