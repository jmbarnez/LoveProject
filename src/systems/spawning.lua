local EntityFactory = require("src.templates.entity_factory")
local Constants = require("src.core.constants")
local Config = require("src.content.config")
local Log = require("src.core.log")

local SpawningSystem = {}

local enemySpawnTimer = 0
local bossSpawnTimer = 0
local asteroidSpawnTimer = 0

local spawnOverrides = Config.SPAWN or {}
local spawnConstants = Constants.SPAWNING

local function getSpawnValue(key)
  local value = spawnOverrides[key]
  if value ~= nil then return value end
  return spawnConstants[key]
end

local maxEnemies = getSpawnValue("MAX_ENEMIES") or 36 -- Significantly increased for relentless pressure
local maxBosses = 3   -- Hard cap on boss drones
local maxAsteroids = 15
local maxClusters = 5  -- Maximum number of asteroid clusters
local clusterRadius = 200  -- Radius around cluster center
local clusterMinAsteroids = 2  -- Minimum asteroids per cluster
local clusterMaxAsteroids = 6  -- Maximum asteroids per cluster

local asteroidVariants = {
  { id = "asteroid_small", weight = 3 },
  { id = "asteroid_medium", weight = 4 },
  { id = "asteroid_large", weight = 2 },
}

-- Gray shade variations for asteroids
local grayShades = {
  {0.25, 0.25, 0.25, 1.0},  -- Dark gray
  {0.35, 0.35, 0.35, 1.0},  -- Medium-dark gray
  {0.45, 0.45, 0.45, 1.0},  -- Medium gray
  {0.55, 0.55, 0.55, 1.0},  -- Light gray
  {0.65, 0.65, 0.65, 1.0},  -- Very light gray
}

local function pickAsteroidId()
  local totalWeight = 0
  for _, variant in ipairs(asteroidVariants) do
    totalWeight = totalWeight + (variant.weight or 1)
  end

  local roll = math.random() * totalWeight
  for _, variant in ipairs(asteroidVariants) do
    roll = roll - (variant.weight or 1)
    if roll <= 0 then
      return variant.id
    end
  end

  return asteroidVariants[1] and asteroidVariants[1].id or "asteroid_medium"
end

-- Pick a random gray shade for asteroid variation
local function pickGrayShade()
  return grayShades[math.random(1, #grayShades)]
end

-- Create an asteroid cluster at a given center point
local function createAsteroidCluster(centerX, centerY, hub, world)
  local asteroidCount = math.random(clusterMinAsteroids, clusterMaxAsteroids)
  local createdAsteroids = 0
  local attempts = 0
  local maxAttempts = asteroidCount * 10  -- Prevent infinite loops
  
  while createdAsteroids < asteroidCount and attempts < maxAttempts do
    attempts = attempts + 1
    
    -- Generate position within cluster radius
    local angle = math.random() * math.pi * 2
    local distance = math.random() * clusterRadius
    local x = centerX + math.cos(angle) * distance
    local y = centerY + math.sin(angle) * distance
    
    -- Check if position is valid
    if x >= 100 and x <= world.width - 100 and y >= 100 and y <= world.height - 100 then
      local asteroid_buffer = (getSpawnValue("STATION_BUFFER") or 300) * 0.5
      local ok_stations = true
      
      -- Check distance from stations
      if hub and hub.components and hub.components.position then
        local dx = x - hub.components.position.x
        local dy = y - hub.components.position.y
        local distance_squared = dx * dx + dy * dy
        local safe_distance_squared = asteroid_buffer * asteroid_buffer
        
        if distance_squared <= safe_distance_squared then
          ok_stations = false
        end
      end
      
      if ok_stations then
        local stations = world:get_entities_with_components("station")
        for _, station in ipairs(stations) do
          if station.components and station.components.position then
            local dx = x - station.components.position.x
            local dy = y - station.components.position.y
            local distance_squared = dx * dx + dy * dy
            local buffer = asteroid_buffer
            if station.noSpawnRadius and (not station.broken) then
              buffer = station.noSpawnRadius
            end
            local safe_distance_squared = buffer * buffer
            if distance_squared <= safe_distance_squared then
              ok_stations = false
              break
            end
          end
        end
      end
      
      -- Check distance from other asteroids
      local ok_others = true
      local existing_asteroids = world:get_entities_with_components("mineable")
      for _, ast in ipairs(existing_asteroids) do
        local dxa, dya = x - ast.components.position.x, y - ast.components.position.y
        local r = (ast.components.collidable and ast.components.collidable.radius) or 30
        local min_dist = r + 40  -- Reduced spacing for clustering
        if (dxa*dxa + dya*dya) <= (min_dist * min_dist) then
          ok_others = false
          break
        end
      end
      
      if ok_stations and ok_others then
        local asteroidId = pickAsteroidId()
        local asteroid = EntityFactory.create("world_object", asteroidId, x, y)
        if asteroid then
          -- Apply random gray shade
          local grayShade = pickGrayShade()
          if asteroid.visuals and asteroid.visuals.colors then
            asteroid.visuals.colors.small = grayShade
            asteroid.visuals.colors.medium = {grayShade[1] * 0.9, grayShade[2] * 0.9, grayShade[3] * 0.9, grayShade[4]}
            asteroid.visuals.colors.large = {grayShade[1] * 0.8, grayShade[2] * 0.8, grayShade[3] * 0.8, grayShade[4]}
            asteroid.visuals.colors.outline = {grayShade[1] * 0.6, grayShade[2] * 0.6, grayShade[3] * 0.6, grayShade[4]}
          end
          
          world:addEntity(asteroid)
          createdAsteroids = createdAsteroids + 1
        end
      end
    end
  end
  
  return createdAsteroids
end

-- Check if a position is within any custom no-spawn zones
local function isPositionInNoSpawnZone(x, y)
  local zones = spawnOverrides.NO_SPAWN_ZONES
  if zones then
    for _, zone in ipairs(zones) do
      local dx = x - zone.x
      local dy = y - zone.y
      local distanceSquared = dx * dx + dy * dy
      local radiusSquared = zone.radius * zone.radius

      if distanceSquared <= radiusSquared then
        return true -- Position is within a no-spawn zone
      end
    end
  end
  return false -- Position is not in any no-spawn zone
end

-- Check if a position is safe distance from all stations
local function isPositionSafeFromStations(x, y, world, hub)
  -- First check the hub directly (since it might not have the station component properly set)
  if hub and hub.components and hub.components.position then
    local dx = x - hub.components.position.x
    local dy = y - hub.components.position.y
    local distanceSquared = dx * dx + dy * dy
    local safeDistance = hub.shieldRadius or getSpawnValue("STATION_BUFFER") or 5000
    local safeDistanceSquared = safeDistance * safeDistance
    
    if distanceSquared <= safeDistanceSquared then
      return false -- Too close to hub station
    end
  end
  
  -- Also check any other stations with the station component
  local stations = world:get_entities_with_components("station")

  for _, station in ipairs(stations) do
    if station.components and station.components.position then
      local dx = x - station.components.position.x
      local dy = y - station.components.position.y
      local distanceSquared = dx * dx + dy * dy

      -- Use custom no-spawn radius for beacon stations (only if repaired), otherwise use default buffer
      local buffer = getSpawnValue("STATION_BUFFER") or 300

      -- For beacon stations, only apply large no-spawn radius if repaired
      if station.noSpawnRadius and (not station.broken) then
        buffer = station.noSpawnRadius
      end
      local safeDistanceSquared = buffer * buffer

      if distanceSquared <= safeDistanceSquared then
        return false -- Too close to a station
      end
    end
  end
  
  return true -- Safe from all stations
end

-- Debug log to verify enemy components
local function logEnemyComponents(enemy)
    if enemy and enemy.components then
        Log.debug("Enemy spawned:", enemy.id or enemy, enemy.components and enemy.components.ai)
    else
        Log.warn("Enemy missing components")
    end
end

-- Spawns a basic drone enemy
local function spawnEnemy(player, hub, world)
  local margin = getSpawnValue("MARGIN") or 300
  local x, y
  local attempts = 0
  repeat
    attempts = attempts + 1
    x = math.random(margin, world.width - margin)
    y = math.random(margin, world.height - margin)
    
    -- Check distance from all stations (including the hub)
    local okStations = isPositionSafeFromStations(x, y, world, hub)

    -- Check custom no-spawn zones
    local okNoSpawnZones = not isPositionInNoSpawnZone(x, y)
    
    local okPlayer = true
    local minPlayerDist = getSpawnValue("MIN_PLAYER_DIST") or 450  -- Reduced from 600 for closer spawns
    if player then
      local dxp, dyp = x - player.components.position.x, y - player.components.position.y
      okPlayer = (dxp*dxp + dyp*dyp) > (minPlayerDist * minPlayerDist)
    end
    local suppressDeathSpawn = world._suppressPlayerDeathSpawn
    local playerEntity = player
    local safeFromPlayerDeath = true
    if suppressDeathSpawn and playerEntity and playerEntity.components and playerEntity.components.position then
      local px = playerEntity.components.position.x
      local py = playerEntity.components.position.y
      local dx = x - px
      local dy = y - py
      local distSq = dx * dx + dy * dy
      safeFromPlayerDeath = distSq >= (minPlayerDist * minPlayerDist)
    end

  until (okStations and okPlayer and okNoSpawnZones and safeFromPlayerDeath) or attempts > 200

  if world._suppressPlayerDeathSpawn then
    world._suppressPlayerDeathSpawn = nil
  end

  -- Use the factory to create a basic drone.
  local enemyShip = EntityFactory.createEnemy("basic_drone", x, y)
  if enemyShip then
      world:addEntity(enemyShip)
      logEnemyComponents(enemyShip)
      
      if not (enemyShip.components and enemyShip.components.ai) then
          Log.error("Enemy spawned without AI component!")
      end
  end
end

-- Spawn a boss drone if under cap
local function spawnBoss(player, hub, world)
  -- Count existing bosses
  local count = 0
  for _, e in ipairs(world:get_entities_with_components("ai")) do
    if e.isBoss or e.shipId == 'boss_drone' then count = count + 1 end
  end
  if count >= maxBosses then return end

  local margin = getSpawnValue("MARGIN") or 300
  local x, y
  local attempts = 0
  repeat
    attempts = attempts + 1
    x = math.random(margin, world.width - margin)
    y = math.random(margin, world.height - margin)
    local okStations = isPositionSafeFromStations(x, y, world, hub)
    local okNoSpawnZones = not isPositionInNoSpawnZone(x, y)
    local okPlayer = true
    if player then
      local dxp, dyp = x - player.components.position.x, y - player.components.position.y
      local minP = getSpawnValue("MIN_PLAYER_DIST") or 600
      okPlayer = (dxp*dxp + dyp*dyp) > (minP * minP)
    end
  until (okStations and okPlayer and okNoSpawnZones) or attempts > 200

  local boss = EntityFactory.createEnemy("boss_drone", x, y)
  if boss then
    world:addEntity(boss)
  end
end

-- Spawns an asteroid
local function spawnAsteroid(hub, world)
  local margin = 100
  local x, y
  local attempts = 0
  local existing_asteroids = world:get_entities_with_components("mineable")
  repeat
    attempts = attempts + 1
    x = math.random(margin, world.width - margin)
    y = math.random(margin, world.height - margin)
    
    -- Check distance from all stations (asteroids can be closer than enemy safe zones)
  local asteroid_buffer = (getSpawnValue("STATION_BUFFER") or 300) * 0.5  -- Half buffer for asteroids
    local ok_stations = true
    
    -- First check the hub directly
    if hub and hub.components and hub.components.position then
      local dx = x - hub.components.position.x
      local dy = y - hub.components.position.y
      local distance_squared = dx * dx + dy * dy
      local safe_distance_squared = asteroid_buffer * asteroid_buffer
      
      if distance_squared <= safe_distance_squared then
        ok_stations = false
      end
    end
    
    -- Also check other stations
    if ok_stations then
      local stations = world:get_entities_with_components("station")
      for _, station in ipairs(stations) do
        if station.components and station.components.position then
          local dx = x - station.components.position.x
          local dy = y - station.components.position.y
          local distance_squared = dx * dx + dy * dy

          -- Use custom no-spawn radius for beacon stations (only if repaired), otherwise use asteroid buffer
          local buffer = asteroid_buffer

          -- For beacon stations, only apply large no-spawn radius if repaired
          if station.noSpawnRadius and (not station.broken) then
            buffer = station.noSpawnRadius
          end
          local safe_distance_squared = buffer * buffer

          if distance_squared <= safe_distance_squared then
            ok_stations = false
            break
          end
        end
      end
    end
    
    -- Legacy hub check for backward compatibility
    local ok_hub = true
    if hub then
      local dxh, dyh = x - hub.components.position.x, y - hub.components.position.y
      local min_hub = (hub.radius or 0) + 200
      ok_hub = (dxh*dxh + dyh*dyh) > (min_hub * min_hub)
    end
    
    local ok_others = true
    -- Check distance from other asteroids
    for _, ast in ipairs(existing_asteroids) do
      local dxa, dya = x - ast.components.position.x, y - ast.components.position.y
      local r = (ast.components.collidable and ast.components.collidable.radius) or 30
      local min_dist = r + 80
      if (dxa*dxa + dya*dya) <= (min_dist * min_dist) then
        ok_others = false
        break
      end
    end
  until (ok_stations and ok_hub and ok_others) or attempts > 200
  
  local asteroidId = pickAsteroidId()
  local asteroid = EntityFactory.create("world_object", asteroidId, x, y)
  if asteroid then
      -- Apply random gray shade
      local grayShade = pickGrayShade()
      if asteroid.visuals and asteroid.visuals.colors then
        asteroid.visuals.colors.small = grayShade
        asteroid.visuals.colors.medium = {grayShade[1] * 0.9, grayShade[2] * 0.9, grayShade[3] * 0.9, grayShade[4]}
        asteroid.visuals.colors.large = {grayShade[1] * 0.8, grayShade[2] * 0.8, grayShade[3] * 0.8, grayShade[4]}
        asteroid.visuals.colors.outline = {grayShade[1] * 0.6, grayShade[2] * 0.6, grayShade[3] * 0.6, grayShade[4]}
      end
      
      world:addEntity(asteroid)
  end
end

local function spawnInitialEntities(player, hub, world)
    -- Don't spawn any enemies at startup - only spawn when player is nearby or explicitly needed
    -- This prevents red engine trails from appearing immediately on startup

    -- Create one big cluster of 5-10 asteroids in the top-left corner
    local margin = 200  -- Distance from edge
    local centerX = margin + math.random(0, 100)  -- Top-left area
    local centerY = margin + math.random(0, 100)  -- Top-left area
    
    -- Create a larger cluster with 5-10 asteroids
    local clusterSize = 5 + math.random(0, 5)  -- 5-10 asteroids
    local clusterRadius = 150  -- Larger radius for the big cluster
    
    local asteroidsCreated = 0
    local attempts = 0
    local maxAttempts = clusterSize * 3  -- More attempts for the larger cluster
    
    while asteroidsCreated < clusterSize and attempts < maxAttempts do
        attempts = attempts + 1
        
        -- Generate position within cluster radius
        local angle = math.random() * math.pi * 2
        local distance = math.random() * clusterRadius
        local x = centerX + math.cos(angle) * distance
        local y = centerY + math.sin(angle) * distance
        
        -- Ensure position is within world bounds
        x = math.max(50, math.min(world.width - 50, x))
        y = math.max(50, math.min(world.height - 50, y))
        
        -- Check if position is safe from stations
        local asteroid_buffer = (getSpawnValue("STATION_BUFFER") or 300) * 0.5
        local ok_stations = true
        
        if hub and hub.components and hub.components.position then
            local dx = x - hub.components.position.x
            local dy = y - hub.components.position.y
            local distance_squared = dx * dx + dy * dy
            local safe_distance_squared = asteroid_buffer * asteroid_buffer
            
            if distance_squared <= safe_distance_squared then
                ok_stations = false
            end
        end
        
        if ok_stations then
            local stations = world:get_entities_with_components("station")
            for _, station in ipairs(stations) do
                if station.components and station.components.position then
                    local dx = x - station.components.position.x
                    local dy = y - station.components.position.y
                    local distance_squared = dx * dx + dy * dy
                    local buffer = asteroid_buffer
                    if station.noSpawnRadius and (not station.broken) then
                        buffer = station.noSpawnRadius
                    end
                    local safe_distance_squared = buffer * buffer
                    if distance_squared <= safe_distance_squared then
                        ok_stations = false
                        break
                    end
                end
            end
        end
        
        -- Check distance from other asteroids in the cluster
        local ok_others = true
        local existing_asteroids = world:get_entities_with_components("mineable")
        for _, ast in ipairs(existing_asteroids) do
            local dxa, dya = x - ast.components.position.x, y - ast.components.position.y
            local r = (ast.components.collidable and ast.components.collidable.radius) or 30
            local min_dist = r + 30  -- Tighter spacing for cluster
            if (dxa*dxa + dya*dya) <= (min_dist * min_dist) then
                ok_others = false
                break
            end
        end
        
        if ok_stations and ok_others then
            local asteroidId = pickAsteroidId()
            local asteroid = EntityFactory.create("world_object", asteroidId, x, y)
            if asteroid then
                -- Apply random gray shade
                local grayShade = pickGrayShade()
                if asteroid.visuals and asteroid.visuals.colors then
                    asteroid.visuals.colors.small = grayShade
                    asteroid.visuals.colors.medium = {grayShade[1] * 0.9, grayShade[2] * 0.9, grayShade[3] * 0.9, grayShade[4]}
                    asteroid.visuals.colors.large = {grayShade[1] * 0.8, grayShade[2] * 0.8, grayShade[3] * 0.8, grayShade[4]}
                    asteroid.visuals.colors.outline = {grayShade[1] * 0.6, grayShade[2] * 0.6, grayShade[3] * 0.6, grayShade[4]}
                end
                
                world:addEntity(asteroid)
                asteroidsCreated = asteroidsCreated + 1
            end
        end
    end

    -- Don't spawn bosses at startup either
  end

function SpawningSystem.init(player, hub, world)
  enemySpawnTimer = 0
  bossSpawnTimer = 0
  asteroidSpawnTimer = 0
  spawnInitialEntities(player, hub, world)
end

function SpawningSystem.update(dt, player, hub, world)
  local enemies = world:get_entities_with_components("ai")
  local asteroids = world:get_entities_with_components("mineable")

  enemySpawnTimer = enemySpawnTimer - dt

  -- More aggressive spawning when there are very few enemies (less than 4)
  if enemySpawnTimer <= 0 and #enemies < 12 then
    spawnEnemy(player, hub, world)
    -- More aggressive spawn rates - faster and more frequent
    local smin = getSpawnValue("INTERVAL_MIN") or 2.0
    local smax = getSpawnValue("INTERVAL_MAX") or 4.0
    enemySpawnTimer = smin + math.random() * (smax - smin)
  end

  -- Only spawn more enemies if we have very few (less than 8 instead of maxEnemies * 0.7)
  if #enemies < 24 and math.random() < 0.3 then
    spawnEnemy(player, hub, world)
  end

  -- Boss spawn logic: slow timer, cap at 3
  bossSpawnTimer = bossSpawnTimer - dt
  if bossSpawnTimer <= 0 then
    local boss_count = 0
    for _, e in ipairs(enemies) do
      if e.isBoss or e.shipId == 'boss_drone' then boss_count = boss_count + 1 end
    end
    if boss_count < maxBosses then
      spawnBoss(player, hub, world)
    end
    bossSpawnTimer = 12 + math.random() * 10 -- 12-22s between boss spawn attempts
  end

  asteroidSpawnTimer = asteroidSpawnTimer - dt
  if asteroidSpawnTimer <= 0 and #asteroids < maxAsteroids then
    -- 30% chance to spawn a new cluster, otherwise spawn individual asteroid
    if math.random() < 0.3 then
      local margin = 300
      local centerX = math.random(margin, world.width - margin)
      local centerY = math.random(margin, world.height - margin)
      
      -- Check if cluster center is safe
      local asteroid_buffer = (getSpawnValue("STATION_BUFFER") or 300) * 0.5
      local ok_stations = true
      
      if hub and hub.components and hub.components.position then
        local dx = centerX - hub.components.position.x
        local dy = centerY - hub.components.position.y
        local distance_squared = dx * dx + dy * dy
        local safe_distance_squared = (asteroid_buffer + clusterRadius) * (asteroid_buffer + clusterRadius)
        if distance_squared <= safe_distance_squared then
          ok_stations = false
        end
      end
      
      if ok_stations then
        local stations = world:get_entities_with_components("station")
        for _, station in ipairs(stations) do
          if station.components and station.components.position then
            local dx = centerX - station.components.position.x
            local dy = centerY - station.components.position.y
            local distance_squared = dx * dx + dy * dy
            local buffer = asteroid_buffer + clusterRadius
            if station.noSpawnRadius and (not station.broken) then
              buffer = station.noSpawnRadius
            end
            local safe_distance_squared = buffer * buffer
            if distance_squared <= safe_distance_squared then
              ok_stations = false
              break
            end
          end
        end
      end
      
      if ok_stations then
        createAsteroidCluster(centerX, centerY, hub, world)
      else
        spawnAsteroid(hub, world)
      end
    else
      spawnAsteroid(hub, world)
    end
    asteroidSpawnTimer = 15 -- spawn new asteroid/cluster every 15 seconds if below max
  end
end

return SpawningSystem