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
	-- No stations spawn automatically - player must build them
	-- This creates the "empty space" survival experience
	Debug.info("game", "No stations spawned - player must build their own")
	return nil
end

local function createWorldObjects(world)
    do
        -- Spawn planet at random position with safe distance from stations
        local worldSize = 30000
        local margin = 2000
        local px = math.random(margin, worldSize - margin)
        local py = math.random(margin, worldSize - margin)
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
    
    -- Cache stations for spawn exclusion checks
    local stations = world:get_entities_with_components("station") or {}
    local function isSafeFromStations(x, y)
        for _, s in ipairs(stations) do
            local sp = s.components and s.components.position
            if sp then
                local dx = x - sp.x
                local dy = y - sp.y
                local distSq = dx * dx + dy * dy
                -- Prefer explicit noSpawnRadius, fall back to shieldRadius, then radius
                local protectionRadius = s.noSpawnRadius or s.shieldRadius or s.radius or 0
                -- Add a small extra buffer so crates don't visually touch station edges
                local buffer = 150
                local required = protectionRadius + buffer
                if required > 0 and distSq < (required * required) then
                    return false
                end
            end
        end
        return true
    end

    for i = 1, 8 do
        local validPosition = false
        local attempts = 0

        while not validPosition and attempts < maxAttempts do
            local x = math.random(margin, worldSize - margin)
            local y = math.random(margin, worldSize - margin)

            validPosition = true
            -- Reject positions that are inside station protection/no-spawn radii
            if not isSafeFromStations(x, y) then
                validPosition = false
            end
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

    updateProgress(0.6, "Preparing empty space...")
    local hub = nil  -- No hub station - player starts in empty space
    if not NetworkSession.isMultiplayer() or NetworkSession.isHost() then
        createStations(world)  -- This now does nothing, just logs
    end
    NetworkSession.setContext({ hub = hub })

    updateProgress(0.7, "Creating world objects...")
    if not NetworkSession.isMultiplayer() or NetworkSession.isHost() then
        createWorldObjects(world)
    end

    return world, camera, hub, ecsManager
end

return WorldBuilder
