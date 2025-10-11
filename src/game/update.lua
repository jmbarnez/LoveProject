local State = require("src.game.state")
local Pipeline = require("src.game.pipeline")

local Input = require("src.core.input")
local UIManager = require("src.core.ui_manager")
local StatusBars = require("src.ui.hud.hud_status_bars")
local SkillXpPopup = require("src.ui.hud.skill_xp_popup")
local NetworkSession = require("src.core.network.session")
local Theme = require("src.core.theme")

local Update = {}

local function updateClickMarkers(dt, markers)
    for i = #markers, 1, -1 do
        local marker = markers[i]
        marker.t = marker.t + dt
        if marker.t >= marker.dur then
            table.remove(markers, i)
        end
    end
end

local function clearExpiredRemoteBeams(world)
    if not world then
        return
    end

    local entities = world:getEntities()
    local currentTime = love.timer and love.timer.getTime() or os.clock()
    for _, entity in pairs(entities) do
        if entity.isRemotePlayer then
            if entity.remoteBeamActive and entity.remoteBeamStartTime and (currentTime - entity.remoteBeamStartTime) > 0.5 then
                entity.remoteBeamActive = false
                entity.remoteBeamStartX = nil
                entity.remoteBeamStartY = nil
                entity.remoteBeamEndX = nil
                entity.remoteBeamEndY = nil
                entity.remoteBeamAngle = nil
                entity.remoteBeamLength = nil
                entity.remoteBeamStartTime = nil
            end

            if entity.remoteUtilityBeamActive and entity.remoteUtilityBeamStartTime and (currentTime - entity.remoteUtilityBeamStartTime) > 0.5 then
                entity.remoteUtilityBeamActive = false
                entity.remoteUtilityBeamType = nil
                entity.remoteUtilityBeamStartX = nil
                entity.remoteUtilityBeamStartY = nil
                entity.remoteUtilityBeamEndX = nil
                entity.remoteUtilityBeamEndY = nil
                entity.remoteUtilityBeamAngle = nil
                entity.remoteUtilityBeamLength = nil
                entity.remoteUtilityBeamStartTime = nil
            end
        end
    end
end

function Update.update(dt)
    local player = State.player
    local world = State.world

    Input.update(dt)
    UIManager.update(dt, player)
    StatusBars.update(dt, player, world)
    SkillXpPopup.update(dt)
    local input = Input.getInputState()

    NetworkSession.update(dt, {
        world = world,
        player = player,
        hub = State.hub,
    })

    if UIManager and UIManager.isOpen("escape") then
        return
    end

    Theme.updateAnimations(dt)
    Theme.updateParticles(dt)
    Theme.updateScreenEffects(dt)
    
    -- Update post-processing systems
    local PostProcessing = require("src.systems.post_processing")

    if not world or not player then
        return
    end

    if not State.systemPipeline then
        State.systemPipeline = Pipeline.build()
    end
    if not State.systemPipeline then
        return
    end

    local context = State.systemContext
    context.dt = dt
    context.player = player
    context.input = input
    context.world = world
    context.hub = State.hub
    context.camera = State.camera
    context.uiManager = UIManager
    context.collisionSystem = State.collisionSystem
    context.windfield = State.windfieldManager
    if State.collisionSystem and State.collisionSystem.getWindfieldContacts then
        context.windfieldContacts = State.collisionSystem:getWindfieldContacts()
    else
        context.windfieldContacts = nil
    end
    context.refreshDockingState = State.refreshDockingState
    context.gameState = {}
    
    -- Add missing dependencies that systems need
    context.clickMarkers = State.clickMarkers
    context.hoveredEntity = State.hoveredEntity
    context.hoveredEntityType = State.hoveredEntityType
    context.networkManager = State.networkManager

    State.systemPipeline:update(context)

    updateClickMarkers(dt, State.clickMarkers)
    clearExpiredRemoteBeams(world)
end

return Update
