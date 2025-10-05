local World = require("src.core.world")
local Constants = require("src.core.constants")
local ECS = require("src.core.ecs")
local LifetimeSystem = require("src.systems.lifetime")
local Camera = require("src.core.camera")
local EntityFactory = require("src.templates.entity_factory")
local Debug = require("src.core.debug")
local NetworkSession = require("src.core.network.session")
local Projectiles = require("src.game.projectiles")

local WorldBuilder = {}

local function createStations(world)
    local hub = EntityFactory.create("station", "hub_station", 5000, 5000)
    if not hub then
        Debug.error("game", "Failed to create hub station")
        return nil, "Failed to create hub station"
    end
    world:addEntity(hub)

    local furnace = EntityFactory.create("station", "ore_furnace_station", 9500, 9500)
    if not furnace then
        Debug.error("game", "Failed to create ore furnace station")
        return nil, "Failed to create ore furnace station"
    end
    world:addEntity(furnace)

    local beacon = EntityFactory.create("station", "beacon_station", 2000, 2000)
    if not beacon then
        Debug.error("game", "Failed to create beacon station")
        return nil, "Failed to create beacon station"
    end
    world:addEntity(beacon)

    return hub
end

local function createWorldObjects(world)
    do
        local px = 15000
        local py = 15000
        local planet = EntityFactory.create("world_object", "planet_massive", px, py)
        if planet then
            world:addEntity(planet)
        else
            Debug.warn("game", "Failed to create planet")
        end
    end

    local worldSize = 30000
    local margin = 2000
    local minDistance = 1000
    local cratePositions = {}
    local maxAttempts = 1000

    for i = 1, 8 do
        local validPosition = false
        local attempts = 0

        while not validPosition and attempts < maxAttempts do
            local x = math.random(margin, worldSize - margin)
            local y = math.random(margin, worldSize - margin)

            validPosition = true
            for _, existingPos in ipairs(cratePositions) do
                local dx = x - existingPos.x
                local dy = y - existingPos.y
                local distance = math.sqrt(dx * dx + dy * dy)
                if distance < minDistance then
                    validPosition = false
                    break
                end
            end

            if validPosition then
                table.insert(cratePositions, {x = x, y = y})
            end

            attempts = attempts + 1
        end

        if not validPosition then
            local x = math.random(margin, worldSize - margin)
            local y = math.random(margin, worldSize - margin)
            table.insert(cratePositions, {x = x, y = y})
            Debug.warn("game", "Could not find valid position for crate %d, using random position", i)
        end
    end

    for i, pos in ipairs(cratePositions) do
        local crate = EntityFactory.create("world_object", "reward_crate", pos.x, pos.y)
        if crate then
            world:addEntity(crate)
            Debug.info("game", "Created reward crate %d at (%d, %d)", i, pos.x, pos.y)
        else
            Debug.warn("game", "Failed to create reward crate %d", i)
        end
    end
end

function WorldBuilder.build(Game, updateProgress)
    updateProgress(0.5, "Creating world...")
    local world = World.new(Constants.WORLD.WIDTH, Constants.WORLD.HEIGHT)
    world.spawn_projectile = Projectiles.spawn
    Game.world = world
    NetworkSession.setContext({ world = world })

    local ecsManager = ECS.new()
    ecsManager:setWorld(world)
    world:setECSWorld(ecsManager)
    ecsManager:addSystem(LifetimeSystem.create())

    local camera = Camera.new()

    updateProgress(0.6, "Creating stations...")
    local hub
    if not NetworkSession.isMultiplayer() or NetworkSession.isHost() then
        local createdHub, errorMessage = createStations(world)
        if not createdHub then
            return nil, nil, nil, nil, errorMessage
        end
        hub = createdHub
    end
    NetworkSession.setContext({ hub = hub })

    updateProgress(0.7, "Creating world objects...")
    if not NetworkSession.isMultiplayer() or NetworkSession.isHost() then
        createWorldObjects(world)
    end

    return world, camera, hub, ecsManager
end

return WorldBuilder
