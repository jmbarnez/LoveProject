local EntityFactory = require("src.templates.entity_factory")
local Config = require("src.content.config")
local Log = require("src.core.log")

local SpawningSystem = {}

local enemySpawnTimer = 0
local bossSpawnTimer = 0
local asteroidSpawnTimer = 0
local maxEnemies = 36 -- Significantly increased for relentless pressure
local maxBosses = 3   -- Hard cap on boss drones
local maxAsteroids = 15

-- Check if a position is within any custom no-spawn zones
local function isPositionInNoSpawnZone(x, y)
  if Config.SPAWN and Config.SPAWN.NO_SPAWN_ZONES then
    for _, zone in ipairs(Config.SPAWN.NO_SPAWN_ZONES) do
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
    local safeDistance = hub.shieldRadius or (Config.SPAWN and Config.SPAWN.STATION_BUFFER) or 5000
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
      local buffer = ((Config.SPAWN and Config.SPAWN.STATION_BUFFER) or 300)

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
  local margin = (Config.SPAWN and Config.SPAWN.MARGIN) or 300
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
    if player then
      local dxp, dyp = x - player.components.position.x, y - player.components.position.y
      local minP = (Config.SPAWN and Config.SPAWN.MIN_PLAYER_DIST) or 450  -- Reduced from 600 for closer spawns
      okPlayer = (dxp*dxp + dyp*dyp) > (minP * minP)
    end
    local suppressDeathSpawn = world._suppressPlayerDeathSpawn
    local playerEntity = getPlayer(world)
    local safeFromPlayerDeath = true
    if suppressDeathSpawn and playerEntity and playerEntity.components and playerEntity.components.position then
      local px = playerEntity.components.position.x
      local py = playerEntity.components.position.y
      local dx = x - px
      local dy = y - py
      local distSq = dx * dx + dy * dy
      safeFromPlayerDeath = distSq >= (minP * minP)
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

  local margin = (Config.SPAWN and Config.SPAWN.MARGIN) or 300
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
      local minP = (Config.SPAWN and Config.SPAWN.MIN_PLAYER_DIST) or 600
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
    local asteroid_buffer = ((Config.SPAWN and Config.SPAWN.STATION_BUFFER) or 300) * 0.5  -- Half buffer for asteroids
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
  
  -- For now, we only have one type of asteroid defined.
  -- This could be expanded to randomly select from different asteroid data files.
  local asteroid = EntityFactory.create("world_object", "asteroid_medium", x, y)
  if asteroid then
      world:addEntity(asteroid)
  end
end

local function spawnInitialEntities(player, hub, world)
    -- Don't spawn any enemies at startup - only spawn when player is nearby or explicitly needed
    -- This prevents red engine trails from appearing immediately on startup

    for i = 1, maxAsteroids do
        spawnAsteroid(hub, world)
    end

    -- Don't spawn bosses at startup either
  end

function SpawningSystem.init(player, hub, world)
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
    local smin = (Config.SPAWN and Config.SPAWN.INTERVAL_MIN) or 2.0
    local smax = (Config.SPAWN and Config.SPAWN.INTERVAL_MAX) or 4.0
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
    spawnAsteroid(hub, world)
    asteroidSpawnTimer = 10 -- spawn new asteroid every 10 seconds if below max
  end
end

return SpawningSystem