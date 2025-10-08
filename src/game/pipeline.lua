local InputIntentSystem = require("src.systems.input_intents")
local PlayerSystem = require("src.systems.player")
local Sound = require("src.core.sound")
local AISystem = require("src.systems.ai")
local PhysicsSystem = require("src.systems.physics")
local BoundarySystem = require("src.systems.boundary_system")
local DestructionSystem = require("src.systems.destruction")
local SpawningSystem = require("src.systems.spawning")
local RepairSystem = require("src.systems.repair_system")
local SpaceStationSystem = require("src.systems.hub")
local MiningSystem = require("src.systems.mining")
local Pickups = require("src.systems.pickups")
local InteractionSystem = require("src.systems.interaction")
local EngineTrailSystem = require("src.systems.engine_trail")
local Effects = require("src.systems.effects")
local QuestSystem = require("src.systems.quest_system")
local NodeMarket = require("src.systems.node_market")
local WarpGateSystem = require("src.systems.warp_gate_system")
local SystemPipeline = require("src.core.system_pipeline")
local Events = require("src.core.events")
local HotbarSystem = require("src.systems.hotbar")
local NetworkSession = require("src.core.network.session")
local NetworkSync = require("src.systems.network_sync")
local RemoteEnemySync = require("src.systems.remote_enemy_sync")
local RemoteProjectileSync = require("src.systems.remote_projectile_sync")

local Projectiles = require("src.game.projectiles")
local State = require("src.game.state")

local Pipeline = {}

local function update_listener_position(player)
    if not player or not player.components then
        return
    end

    local pos = player.components.position
    if pos then
        Sound.setListenerPosition(pos.x, pos.y)
    end
end

local function update_ecs(dt, context)
    if not State.ecsManager then
        return
    end

    State.ecsManager:update(dt, context)
end

local function update_collision_system(world, dt)
    local collisionSystem = State.collisionSystem
    if collisionSystem then
        collisionSystem:update(world, dt)
    end
end

local function update_network(dt, player, world)
    local manager = State.networkManager
    if not (manager and manager:isMultiplayer()) then
        return
    end

    NetworkSync.update(dt, player, world, manager)

    if manager:isHost() then
        RemoteEnemySync.updateHost(dt, world, manager)
        RemoteProjectileSync.updateHost(dt, world, manager)
    else
        RemoteEnemySync.updateClient(dt, world, manager)
        RemoteProjectileSync.updateClient(dt, world, manager)
    end
end

function Pipeline.build()
    local steps = {
        function(ctx)
            InputIntentSystem.update(ctx.dt, ctx.player, ctx.uiManager)
        end,
        function(ctx)
            PlayerSystem.update(ctx.dt, ctx.player, ctx.input, ctx.world, ctx.hub)
        end,
        function(ctx)
            update_listener_position(ctx.player)
        end,
        function(ctx)
            AISystem.update(ctx.dt, ctx.world, Projectiles.spawn)
        end,
        function(ctx)
            PhysicsSystem.update(ctx.dt, ctx.world:getEntities(), ctx.world)
        end,
        function(ctx)
            update_ecs(ctx.dt, ctx)
        end,
        function(ctx)
            BoundarySystem.update(ctx.world)
        end,
        function(ctx)
            update_collision_system(ctx.world, ctx.dt)
        end,
        function(ctx)
            DestructionSystem.update(ctx.world, ctx.gameState, ctx.hub)
        end,
        function(ctx)
            if not NetworkSession.isMultiplayer() then
                SpawningSystem.update(ctx.dt, ctx.player, ctx.hub, ctx.world)
            end
        end,
        function(ctx)
            RepairSystem.update(ctx.dt, ctx.player, ctx.world)
        end,
        function(ctx)
            SpaceStationSystem.update(ctx.dt, ctx.hub)
        end,
        function(ctx)
            MiningSystem.update(ctx.dt, ctx.world, ctx.player)
        end,
        function(ctx)
            Pickups.update(ctx.dt, ctx.world, ctx.player)
        end,
        function(ctx)
            InteractionSystem.update(ctx.dt, ctx.player, ctx.world)
        end,
        function(ctx)
            EngineTrailSystem.update(ctx.dt, ctx.world)
        end,
        function(ctx)
            Effects.update(ctx.dt)
        end,
        function(ctx)
            QuestSystem.update(ctx.player)
        end,
        function(ctx)
            NodeMarket.update(ctx.dt)
        end,
        function(ctx)
            WarpGateSystem.updateWarpGates(ctx.world, ctx.dt)
        end,
        function(ctx)
            if ctx.camera then
                ctx.camera:update(ctx.dt)
            end
        end,
        function(ctx)
            ctx.world:update(ctx.dt)
        end,
        function(ctx)
            local StateManager = require("src.managers.state_manager")
            StateManager.update(ctx.dt)
        end,
        function(ctx)
            if ctx.refreshDockingState then
                ctx.refreshDockingState()
            end
        end,
        function(ctx)
            Events.processQueue()
        end,
        function(ctx)
            HotbarSystem.update(ctx.dt)
        end,
        function(ctx)
            local TurretSystem = require("src.systems.turret.system")
            TurretSystem.cleanupEffects()
        end,
        function(ctx)
            local ConstructionSystem = require("src.systems.construction")
            ConstructionSystem.update(ctx.dt, ctx)
        end,
        function(ctx)
            update_network(ctx.dt, ctx.player, ctx.world)
        end,
    }

    return SystemPipeline.new(steps)
end

return Pipeline
