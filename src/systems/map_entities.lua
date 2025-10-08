--[[
  Map Entities Filtering System
  
  Handles filtering and organizing entities for map rendering.
  Provides clean separation between entity data and rendering logic.
]]

local MapEntities = {}

-- Default filter settings
MapEntities.defaultFilters = {
  stations = true,
  enemies = true,
  asteroids = true,
  wrecks = true,
  loot = true,
  warp_gates = true,
  remote_players = true
}

-- Filter entities by discovery state (disabled - no fog of war)
function MapEntities.filterByDiscovery(entities, discovery)
  -- Return all entities since fog of war is disabled
  return entities or {}
end

-- Filter entities by type and other criteria
function MapEntities.filterByType(entities, entityType, filters)
  if not entities then return {} end
  if not filters or filters[entityType] == false then return {} end
  
  local filtered = {}
  for _, entity in ipairs(entities) do
    if not entity.dead then
      table.insert(filtered, entity)
    end
  end
  return filtered
end

-- Get all visible entities for a world
function MapEntities.getVisibleEntities(world, discovery, filters)
  filters = filters or MapEntities.defaultFilters
  local entities = {}
  
  -- Stations
  if filters.stations then
    local stations = world:get_entities_with_components("station") or {}
    stations = MapEntities.filterByDiscovery(stations, discovery)
    for _, station in ipairs(stations) do
      table.insert(entities, { entity = station, type = "station" })
    end
  end
  
  -- Warp gates
  if filters.warp_gates then
    local warp_gates = world:get_entities_with_components("warp_gate") or {}
    warp_gates = MapEntities.filterByDiscovery(warp_gates, discovery)
    for _, gate in ipairs(warp_gates) do
      table.insert(entities, { entity = gate, type = "warp_gate" })
    end
  end
  
  -- Asteroids
  if filters.asteroids then
    local asteroids = world:get_entities_with_components("mineable") or {}
    asteroids = MapEntities.filterByDiscovery(asteroids, discovery)
    for _, asteroid in ipairs(asteroids) do
      table.insert(entities, { entity = asteroid, type = "asteroid" })
    end
  end
  
  -- Wrecks
  if filters.wrecks then
    local wrecks = world:get_entities_with_components("wreckage") or {}
    wrecks = MapEntities.filterByDiscovery(wrecks, discovery)
    for _, wreck in ipairs(wrecks) do
      table.insert(entities, { entity = wreck, type = "wreck" })
    end
  end
  
  -- Enemies
  if filters.enemies then
    local enemies = world:get_entities_with_components("ai") or {}
    enemies = MapEntities.filterByDiscovery(enemies, discovery)
    for _, enemy in ipairs(enemies) do
      table.insert(entities, { entity = enemy, type = "enemy" })
    end
  end
  
  return entities
end

-- Get entities for minimap (simplified)
function MapEntities.getMinimapEntities(world, discovery, additionalEntities)
  additionalEntities = additionalEntities or {}
  local entities = {}
  
  -- Add world entities
  local worldEntities = MapEntities.getVisibleEntities(world, discovery, MapEntities.defaultFilters)
  for _, item in ipairs(worldEntities) do
    table.insert(entities, item)
  end
  
  -- Add additional entities (loot drops, remote players, etc.)
  if additionalEntities.lootDrops then
    for _, drop in ipairs(additionalEntities.lootDrops) do
      table.insert(entities, { 
        entity = { components = { position = { x = drop.x, y = drop.y } } }, 
        type = "loot" 
      })
    end
  end
  
  if additionalEntities.remotePlayers then
    for id, remotePlayer in pairs(additionalEntities.remotePlayers) do
      local pos = remotePlayer and remotePlayer.components and remotePlayer.components.position
      if pos then
        table.insert(entities, { 
          entity = remotePlayer, 
          type = "remote_player",
          id = remotePlayer.remotePlayerId or id
        })
      end
    end
  end
  
  if additionalEntities.remotePlayerSnapshots then
    for id, snapshot in pairs(additionalEntities.remotePlayerSnapshots) do
      local pos = snapshot and (snapshot.position or (snapshot.data and snapshot.data.position))
      if pos then
        table.insert(entities, { 
          entity = { components = { position = pos } }, 
          type = "remote_player",
          id = snapshot.playerId or id
        })
      end
    end
  end
  
  return entities
end

-- Check if an entity should be visible based on filters
function MapEntities.isEntityVisible(entity, entityType, filters)
  if not entity or not filters then return true end
  if entity.dead then return false end
  return filters[entityType] ~= false
end

return MapEntities
