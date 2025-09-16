-- Refactored rendering system with modular components
local PlayerRenderer = require("src.systems.render.player_renderer")
local EntityRenderers = require("src.systems.render.entity_renderers")
local TargetEffects = require("src.systems.render.target_effects")
local ShieldEffects = require("src.systems.render.shield_effects")
local ShieldImpactEffects = require("src.systems.render.shield_impact_effects")

local RenderSystem = {}

function RenderSystem.draw(world, camera, player, clickMarkers, hoveredEntity, hoveredEntityType)

    -- Draw all non-player renderable entities
    if EntityRenderers and EntityRenderers.draw then
        EntityRenderers.draw(world, camera, player)
    end

    -- Draw player
    if player and PlayerRenderer and PlayerRenderer.render then
        PlayerRenderer.render(player, player)  -- entity, playerRef
    end

    -- Draw special effects
    if TargetEffects and TargetEffects.draw then
        TargetEffects.draw(world, camera, player)
    end
    if ShieldEffects and ShieldEffects.draw then
        ShieldEffects.draw(world, camera)
    end
    if ShieldImpactEffects and ShieldImpactEffects.draw then
        ShieldImpactEffects.draw(world)
    end

    -- Draw click markers
    if clickMarkers then
        for _, marker in ipairs(clickMarkers) do
            love.graphics.setColor(1, 1, 1, 1 - (marker.t / marker.dur))  -- Fade out
            love.graphics.circle("fill", marker.x, marker.y, 5)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    -- Draw hovered entity highlight
    if hoveredEntity and hoveredEntityType then
        -- Simple outline, assuming position component
        if hoveredEntity.components and hoveredEntity.components.position then
            local pos = hoveredEntity.components.position
            local rad = hoveredEntity.components.renderable and hoveredEntity.components.renderable.radius or 20
            love.graphics.setColor(1, 1, 0, 0.5)  -- Yellow highlight
            love.graphics.circle("line", pos.x, pos.y, rad)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end

end

return RenderSystem
