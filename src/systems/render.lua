-- Refactored rendering system with modular components
local PlayerRenderer = require("src.systems.render.player_renderer")
local EntityRenderers = require("src.systems.render.entity_renderers")
local TargetEffects = require("src.systems.render.target_effects")
local ShieldEffects = require("src.systems.render.shield_effects")
local ShieldImpactEffects = require("src.systems.render.shield_impact_effects")
local Effects = require("src.systems.effects")


-- Entity renderer lookup table
local renderers = {
    player = PlayerRenderer.render,
    remote_player = EntityRenderers.remote_player,
    enemy = EntityRenderers.enemy,
    asteroid = EntityRenderers.asteroid,
    planet = EntityRenderers.planet,
    station = EntityRenderers.station,
    wreckage = EntityRenderers.wreckage,
    bullet = EntityRenderers.bullet,
    lootContainer = EntityRenderers.lootContainer,
    item_pickup = EntityRenderers.item_pickup,
    ["warp_gate"] = EntityRenderers.warp_gate
}

local RenderSystem = {}
local Log = require("src.core.log")


function RenderSystem.draw(entities, player, clickMarkers, hoveredEntity, hoveredEntityType)
    -- Draw UI effects first
    TargetEffects.drawClickMarkers(clickMarkers)
    -- Target-based effects removed (manual combat)

    -- Pass 1: draw background bodies (planets) first so they sit behind everything
    for _, entity in pairs(entities) do
        if entity.components and entity.components.position and entity.components.renderable then
            local renderable = entity.components.renderable
            if renderable.type == 'planet' then
                local pos = entity.components.position
                local renderer = renderers[renderable.type]
                if renderer then
                    love.graphics.push()
                    love.graphics.translate(pos.x, pos.y)
                    love.graphics.rotate(pos.angle or 0)
                    renderer(entity, player)
                    love.graphics.pop()
                end
            end
        end
    end

    -- Pass 2a: draw laser beams first (under ships)
    for _, entity in pairs(entities) do
        if entity.components and entity.components.position and entity.components.renderable then
            local pos = entity.components.position
            local renderable = entity.components.renderable
            if renderable.type == 'bullet' and renderable.props and 
               (renderable.props.kind == 'laser' or renderable.props.kind == 'mining_laser' or renderable.props.kind == 'salvaging_laser') then
                local renderer = renderers[renderable.type]
                if renderer then
                    love.graphics.push()
                    love.graphics.translate(pos.x, pos.y)
                    love.graphics.rotate(pos.angle or 0)
                    renderer(entity, player)  -- Pass player to renderer
                    love.graphics.pop()
                end
            end
        end
    end

    -- Pass 2b: draw all other non-planet, non-laser entities
    for _, entity in pairs(entities) do
        if entity.components and entity.components.position and entity.components.renderable then
            local pos = entity.components.position
            local renderable = entity.components.renderable
            -- Skip planets (drawn in pass 1) and laser beams (drawn in pass 2a)
            if renderable.type ~= 'planet' and not (renderable.type == 'bullet' and renderable.props and 
               (renderable.props.kind == 'laser' or renderable.props.kind == 'mining_laser' or renderable.props.kind == 'salvaging_laser')) then
                local renderer = renderers[renderable.type]
                if renderer then
                    love.graphics.push()
                    love.graphics.translate(pos.x, pos.y)
                    love.graphics.rotate(pos.angle or 0)
                    renderer(entity, player)  -- Pass player to renderer
                    love.graphics.pop()
                else
                    -- Log missing renderers at warn level
                    if renderable.type ~= "remote_player" then
                        Log.warn("No renderer found for type:", tostring(renderable.type))
                    else
                        Log.warn("No renderer found for remote_player!")
                    end
                end
            end
        end
    end

    -- Draw additional effects
    TargetEffects.drawHoverHighlight(hoveredEntity, hoveredEntityType)
    TargetEffects.drawTurretBeams(player, entities)
    -- Draw lock-on targeting indicators for missile launchers
    if player and player.lockOnState and player:hasMissileLauncher() then
        TargetEffects.drawLockOnIndicators(player)
    end

    -- Draw station shield bubble
    for _, entity in pairs(entities) do
        if entity.tag == "station" then
            love.graphics.push()
            love.graphics.translate(entity.components.position.x, entity.components.position.y)
            ShieldEffects.drawShieldBubble(entity)
            love.graphics.pop()
        end
    end

    -- Draw shield impact effects (with proper camera transform)
    ShieldImpactEffects.draw()
end

return RenderSystem
