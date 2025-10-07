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
	-- Choose a random cluster center inside world bounds with a generous margin
	local worldW, worldH = Constants.WORLD.WIDTH, Constants.WORLD.HEIGHT
	local margin = math.max(2000, (Constants.SPAWNING and Constants.SPAWNING.STATION_BUFFER) or 0)
	local cx = math.random(margin, worldW - margin)
	local cy = math.random(margin, worldH - margin)

	-- Place hub at cluster center
	local hub = EntityFactory.create("station", "hub_station", cx, cy)
	if not hub then
		Debug.error("game", "Failed to create hub station")
		return nil, "Failed to create hub station"
	end
	world:addEntity(hub)

	-- Distribute other stations around the center with spread similar to current feel
	local baseAngle = math.random() * math.pi * 2
	local function polarOffset(angle, radius)
		return cx + math.cos(angle) * radius, cy + math.sin(angle) * radius
	end

	-- Furnace station
	local r1 = 1800 + math.random() * 2200  -- ~2k-4k spread from center
	local a1 = baseAngle
	local fx, fy = polarOffset(a1, r1)
	-- Clamp to bounds if extremely close to edges (rare due to margin)
	fx = math.max(margin, math.min(worldW - margin, fx))
	fy = math.max(margin, math.min(worldH - margin, fy))
	local furnace = EntityFactory.create("station", "ore_furnace_station", fx, fy)
	if not furnace then
		Debug.error("game", "Failed to create ore furnace station")
		return nil, "Failed to create ore furnace station"
	end
	world:addEntity(furnace)

	-- Beacon station
	local r2 = 1800 + math.random() * 2200
	local a2 = baseAngle + (2 * math.pi / 3) -- space them apart
	local bx, by = polarOffset(a2, r2)
	bx = math.max(margin, math.min(worldW - margin, bx))
	by = math.max(margin, math.min(worldH - margin, by))
	local beacon = EntityFactory.create("station", "beacon_station", bx, by)
	if not beacon then
		Debug.error("game", "Failed to create beacon station")
		return nil, "Failed to create beacon station"
	end
	world:addEntity(beacon)

	return hub
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
