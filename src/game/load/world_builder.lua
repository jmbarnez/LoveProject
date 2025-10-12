local World = require("src.core.world")
local Constants = require("src.core.constants")
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

local function createAsteroidBelt(world)
    -- Create a diagonal asteroid belt that cuts through the sector
    local worldSize = 30000
    local margin = 2000
    
    -- Belt parameters
    local beltStartX = margin
    local beltStartY = margin + math.random(0, worldSize - 2 * margin)
    local beltEndX = worldSize - margin
    local beltEndY = margin + math.random(0, worldSize - 2 * margin)
    
    -- Belt width and density
    local beltWidth = 800  -- Width of the belt
    local asteroidCount = 120  -- Number of asteroids in the belt
    local minSpacing = 200  -- Minimum distance between asteroids
    
    -- Calculate belt direction and perpendicular
    local beltDx = beltEndX - beltStartX
    local beltDy = beltEndY - beltStartY
    local beltLength = math.sqrt(beltDx * beltDx + beltDy * beltDy)
    local beltDirX = beltDx / beltLength
    local beltDirY = beltDy / beltLength
    local beltPerpX = -beltDirY  -- Perpendicular to belt direction
    local beltPerpY = beltDirX
    
    local asteroidPositions = {}
    local attempts = 0
    local maxAttempts = asteroidCount * 10
    
    -- Generate asteroid positions along the belt
    for i = 1, asteroidCount do
        local validPosition = false
        local attempts = 0
        
        while not validPosition and attempts < 50 do
            -- Random position along the belt
            local t = math.random()  -- 0 to 1 along the belt
            local centerX = beltStartX + t * beltDx
            local centerY = beltStartY + t * beltDy
            
            -- Random offset perpendicular to belt direction
            local perpOffset = (math.random() - 0.5) * beltWidth
            local x = centerX + perpOffset * beltPerpX
            local y = centerY + perpOffset * beltPerpY
            
            -- Clamp to world bounds
            x = math.max(margin, math.min(worldSize - margin, x))
            y = math.max(margin, math.min(worldSize - margin, y))
            
            validPosition = true
            
            -- Check spacing from other asteroids
            for _, pos in ipairs(asteroidPositions) do
                local dx = x - pos.x
                local dy = y - pos.y
                local distance = math.sqrt(dx * dx + dy * dy)
                if distance < minSpacing then
                    validPosition = false
                    break
                end
            end
            
            -- Check distance from stations
            local stations = world:get_entities_with_components("station") or {}
            for _, station in ipairs(stations) do
                local sp = station.components and station.components.position
                if sp then
                    local dx = x - sp.x
                    local dy = y - sp.y
                    local distSq = dx * dx + dy * dy
                    local protectionRadius = station.noSpawnRadius or station.shieldRadius or station.radius or 0
                    local buffer = 300
                    local required = protectionRadius + buffer
                    if required > 0 and distSq < (required * required) then
                        validPosition = false
                        break
                    end
                end
            end
            
            if validPosition then
                table.insert(asteroidPositions, {x = x, y = y})
            end
            
            attempts = attempts + 1
        end
        
        if not validPosition then
            -- Fallback: place asteroid at random position along belt
            local t = math.random()
            local centerX = beltStartX + t * beltDx
            local centerY = beltStartY + t * beltDy
            local perpOffset = (math.random() - 0.5) * beltWidth
            local x = centerX + perpOffset * beltPerpX
            local y = centerY + perpOffset * beltPerpY
            x = math.max(margin, math.min(worldSize - margin, x))
            y = math.max(margin, math.min(worldSize - margin, y))
            table.insert(asteroidPositions, {x = x, y = y})
        end
    end
    
    -- Create the asteroids
    for i, pos in ipairs(asteroidPositions) do
        local asteroidId = "asteroid_medium"  -- Default to medium
        if math.random() < 0.3 then
            asteroidId = "asteroid_large"
        elseif math.random() < 0.6 then
            asteroidId = "asteroid_small"
        end
        
        -- 20% chance for palladium variant
        if math.random() < 0.2 then
            if asteroidId == "asteroid_small" then
                asteroidId = "asteroid_small_palladium"
            elseif asteroidId == "asteroid_medium" then
                asteroidId = "asteroid_medium_palladium"
            elseif asteroidId == "asteroid_large" then
                asteroidId = "asteroid_large_palladium"
            end
        end
        
        local asteroid = EntityFactory.create("world_object", asteroidId, pos.x, pos.y)
        if asteroid then
            -- Apply gray coloring like other asteroids
            local grayShades = {
                {0.25, 0.25, 0.25, 1.0},  -- Dark gray
                {0.35, 0.35, 0.35, 1.0},  -- Medium-dark gray
                {0.45, 0.45, 0.45, 1.0},  -- Medium gray
                {0.55, 0.55, 0.55, 1.0},  -- Light gray
                {0.65, 0.65, 0.65, 1.0},  -- Very light gray
            }
            local grayShade = grayShades[math.random(1, #grayShades)]
            
            if asteroid.visuals and asteroid.visuals.colors then
                asteroid.visuals.colors.small = grayShade
                asteroid.visuals.colors.medium = {grayShade[1] * 0.9, grayShade[2] * 0.9, grayShade[3] * 0.9, grayShade[4]}
                asteroid.visuals.colors.large = {grayShade[1] * 0.8, grayShade[2] * 0.8, grayShade[3] * 0.8, grayShade[4]}
                asteroid.visuals.colors.outline = {grayShade[1] * 0.6, grayShade[2] * 0.6, grayShade[3] * 0.6, grayShade[4]}
            end
            
            -- Add physics body
            local Physics = require("src.components.physics")
            local radius = asteroid.components.collidable and asteroid.components.collidable.radius or 30
            local mass = radius * 2
            asteroid.components.physics = Physics.new({
                mass = mass,
                x = pos.x,
                y = pos.y
            })
            
            -- Add small random velocity
            local velX = (math.random() - 0.5) * 15
            local velY = (math.random() - 0.5) * 15
            asteroid.components.physics.body:setVelocity(velX, velY)
            
            world:addEntity(asteroid)
        end
    end
    
    Debug.info("game", "Created asteroid belt with %d asteroids", #asteroidPositions)
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
    
    -- Create the asteroid belt
    createAsteroidBelt(world)

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
            -- Debug physics component
            if crate.components and crate.components.physics then
                Debug.info("game", "Reward crate %d has physics component with mass %d", i, crate.components.physics.mass or 0)
            else
                Debug.warn("game", "Reward crate %d missing physics component!", i)
            end
        else
            Debug.warn("game", "Failed to create reward crate %d", i)
        end
    end
end

function WorldBuilder.build(Game, updateProgress)
    updateProgress(0.5, "Creating world...")
    local world = World.new(Constants.WORLD.WIDTH, Constants.WORLD.HEIGHT)
    world.spawn_projectile = function(x, y, angle, friendly, opts)
        return Projectiles.spawn(x, y, angle, friendly, opts, world)
    end
    Game.world = world
    NetworkSession.setContext({ world = world })


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

    return world, camera, hub
end

return WorldBuilder
