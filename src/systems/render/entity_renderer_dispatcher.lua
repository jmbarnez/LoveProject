local RenderUtils = require("src.systems.render.utils")
local Viewport = require("src.core.viewport")

local Dispatcher = {}

-- Cached renderer functions for better performance
local cachedRenderers = {}
local rendererCounter = 0
local trackedEntities = setmetatable({}, { __mode = "k" })

local rendererModules = {
    remote_player = "src.systems.render.entities.remote_player",
    enemy = "src.systems.render.entities.enemy",
    warp_gate = "src.systems.render.entities.warp_gate",
    asteroid = "src.systems.render.entities.asteroid",
    item_pickup = "src.systems.render.entities.item_pickup",
    xp_pickup = "src.systems.render.entities.xp_pickup",
    wreckage = "src.systems.render.entities.wreckage",
    bullet = "src.systems.render.entities.bullet",
    wave = "src.systems.render.entities.wave",
    station = "src.systems.render.entities.station",
    planet = "src.systems.render.entities.planet",
    reward_crate = "src.systems.render.entities.reward_crate",
    lootContainer = "src.systems.render.entities.loot_container",
    stationary_turret = "src.systems.render.entities.stationary_turret",
}

local function fallbackRenderer(entity, player)
    local props = entity.components.renderable.props or {}
    local v = props.visuals or {}
    local size = v.size or 1.0
    local S = RenderUtils.createScaler(size)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 0, 0, S(10))
end

-- Cache entity renderer type to avoid repeated component checks
local function getRendererType(entity)
    if not entity._rendererType then
        if entity.isRemotePlayer then
            entity._rendererType = "remote_player"
        elseif entity.components.ai then
            entity._rendererType = "enemy"
        elseif entity.components.warp_gate then
            entity._rendererType = "warp_gate"
        elseif entity.components.mineable then
            entity._rendererType = "asteroid"
        elseif entity.isItemPickup or entity.components.item_pickup then
            entity._rendererType = "item_pickup"
        elseif entity.components.xp_pickup then
            entity._rendererType = "xp_pickup"
        elseif entity.components.wreckage then
            entity._rendererType = "wreckage"
        elseif entity.components.lootable and entity.isWreckage then
            entity._rendererType = "wreckage"
        elseif entity.components.bullet then
            -- Check if it's a wave projectile
            local renderable = entity.components.renderable
            if renderable and renderable.type == "wave" then
                entity._rendererType = "wave"
            else
                entity._rendererType = "bullet"
            end
        elseif entity.isStation then
            entity._rendererType = "station"
        elseif entity.isTurret or entity.type == "stationary_turret" or entity.aiType == "turret" then
            entity._rendererType = "stationary_turret"
        elseif entity.type == "world_object" and entity.subtype == "planet_massive" then
            entity._rendererType = "planet"
        elseif entity.type == "world_object" and entity.subtype == "reward_crate" then
            entity._rendererType = "reward_crate"
        elseif entity.components.lootable then
            entity._rendererType = "lootContainer"
        else
            entity._rendererType = "fallback"
        end

        trackedEntities[entity] = true
        rendererCounter = rendererCounter + 1
        if rendererCounter > 10000 then
            rendererCounter = 0
            for tracked in pairs(trackedEntities) do
                tracked._rendererType = nil
                trackedEntities[tracked] = nil
            end
            cachedRenderers = {}
        end
    end

    return entity._rendererType
end

local function getRendererByType(rendererType)
    -- Handle legacy "turret" renderer type
    if rendererType == "turret" then
        rendererType = "stationary_turret"
    end
    
    local renderer = cachedRenderers[rendererType]
    if renderer then
        return renderer
    end

    local modulePath = rendererModules[rendererType]
    if modulePath then
        local success, result = pcall(require, modulePath)
        if success then
            renderer = result
        else
            print("ERROR: Failed to load renderer module:", modulePath, "Error:", result)
            renderer = fallbackRenderer
        end
    else
        print("WARNING: No module path found for renderer type:", rendererType)
        renderer = fallbackRenderer
    end

    cachedRenderers[rendererType] = renderer
    return renderer
end

-- Clear cache function to handle module renames
local function clearRendererCache()
    cachedRenderers = {}
    for tracked in pairs(trackedEntities) do
        tracked._rendererType = nil
        trackedEntities[tracked] = nil
    end
end

function Dispatcher.getRendererType(entity)
    return getRendererType(entity)
end

function Dispatcher.getEntityRenderer(entity)
    local rendererType = getRendererType(entity)
    return getRendererByType(rendererType), rendererType
end

function Dispatcher.clearCache()
    clearRendererCache()
end

-- Define render layer priorities (lower numbers render first/behind)
local RENDER_LAYERS = {
    planet = 0,
    asteroid = 1,
    wreckage = 2,
    station = 3,
    warp_gate = 4,
    enemy = 5,
    bullet = 6,
    wave = 6, -- Same layer as bullets
    item_pickup = 7,
    xp_pickup = 8,
    reward_crate = 9,
    lootContainer = 10,
    stationary_turret = 11,
    remote_player = 12,
}

-- Get render layer for an entity
local function getRenderLayer(entity)
    local rendererType = getRendererType(entity)
    return RENDER_LAYERS[rendererType] or 50 -- Default to high layer if unknown
end

function Dispatcher.draw(world, camera, player)
    local entities = world:get_entities_with_components("renderable", "position")
    
    -- Sort entities by render layer to ensure proper z-ordering
    table.sort(entities, function(a, b)
        if a == player then return false end -- Player always renders last
        if b == player then return true end
        return getRenderLayer(a) < getRenderLayer(b)
    end)
    
    -- Draw engine trails for all non-player entities first (world space)
    for _, entity in ipairs(entities) do
        if entity ~= player and entity.components and entity.components.engine_trail then
            entity.components.engine_trail:draw()
        end
    end

    -- Then draw entities themselves in sorted order
    for _, entity in ipairs(entities) do
        if entity == player then goto continue end
        local pos = entity.components.position
        if not pos then goto continue end

        love.graphics.push()
        love.graphics.translate(pos.x, pos.y)
        love.graphics.rotate(pos.angle or 0)

        local renderer = getRendererByType(getRendererType(entity))
        renderer(entity, player)

        love.graphics.pop()

        -- Draw health bars for all entities with health components
        if entity.components.health then
            local EnemyStatusBars = require("src.ui.hud.enemy_status_bars")
            EnemyStatusBars.drawMiniBars(entity)
        end

        -- Draw turret heat bars in screen space
        if entity.components.ai and entity.components.equipment and entity.components.equipment.grid then
            local x, y = entity.components.position.x, entity.components.position.y
            local screenX, screenY = Viewport.toScreen(x, y)
            local turrets = {}
            for _, gridData in ipairs(entity.components.equipment.grid) do
                if gridData.type == "turret" and gridData.module then
                    table.insert(turrets, gridData.module)
                end
            end
            for i, turret in ipairs(turrets) do
                -- Placeholder retained for future heat bar rendering logic
            end
        end

        -- Draw enemy laser beams after pop, in world space
        if entity.components.ai and entity.components.equipment and entity.components.equipment.grid then
            for _, gridData in ipairs(entity.components.equipment.grid) do
                if gridData.type == "turret" and gridData.module and (gridData.module.kind == "laser" or gridData.module.kind == "mining_laser" or gridData.module.kind == "salvaging_laser") and gridData.module.beamActive then
                    local turret = gridData.module
                    local TurretEffects = require("src.systems.turret.effects")
                    local Turret = require("src.systems.turret.core")
                    local turretX, turretY = Turret.getTurretWorldPosition(turret)
                    TurretEffects.renderBeam(turret, turretX, turretY, turret.beamEndX, turret.beamEndY, turret.beamTarget)
                    turret.beamActive = false
                end
            end
        end
        ::continue::
    end
end

return Dispatcher
