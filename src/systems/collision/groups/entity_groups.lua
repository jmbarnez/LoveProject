-- Entity Group Detection System
-- Handles detection of entity relationships and group membership

local EntityGroups = {}

-- Check if two entities belong to the same logical group (e.g., same station)
function EntityGroups.areInSameGroup(entity1, entity2)
    -- If both entities have a station_id, they belong to the same group if IDs match
    if entity1.station_id and entity2.station_id then
        return entity1.station_id == entity2.station_id
    end
    
    -- If both entities have a parent_station, they belong to the same group if parents match
    if entity1.parent_station and entity2.parent_station then
        return entity1.parent_station == entity2.parent_station
    end
    
    -- If one entity is a station and the other has that station as parent
    if entity1.tag == "station" and entity2.parent_station == entity1 then
        return true
    end
    if entity2.tag == "station" and entity1.parent_station == entity2 then
        return true
    end
    
    -- If both entities are station parts (have station component)
    if entity1.components and entity1.components.station and 
       entity2.components and entity2.components.station then
        -- Check if they have the same station reference
        return entity1.station == entity2.station
    end
    
    -- Check all other group types
    local groupTypes = {
        "ship_id", "asteroid_id", "wreckage_id", "enemy_id", 
        "hub_id", "warp_gate_id", "beacon_id", "ore_furnace_id",
        "holographic_turret_id", "reward_crate_id", "planet_id"
    }
    
    for _, groupType in ipairs(groupTypes) do
        if entity1[groupType] and entity2[groupType] then
            return entity1[groupType] == entity2[groupType]
        end
    end
    
    return false
end

-- Get the group identifier for an entity
function EntityGroups.getGroupId(entity)
    -- Priority order for group identification
    if entity.station_id then
        return "station_" .. tostring(entity.station_id)
    end
    if entity.parent_station then
        return "station_" .. tostring(entity.parent_station.id or entity.parent_station)
    end
    if entity.tag == "station" then
        return "station_" .. tostring(entity.id)
    end
    
    -- Check all other group types
    local groupTypes = {
        {key = "ship_id", prefix = "ship"},
        {key = "asteroid_id", prefix = "asteroid"},
        {key = "wreckage_id", prefix = "wreckage"},
        {key = "enemy_id", prefix = "enemy"},
        {key = "hub_id", prefix = "hub"},
        {key = "warp_gate_id", prefix = "warp_gate"},
        {key = "beacon_id", prefix = "beacon"},
        {key = "ore_furnace_id", prefix = "ore_furnace"},
        {key = "holographic_turret_id", prefix = "holographic_turret"},
        {key = "reward_crate_id", prefix = "reward_crate"},
        {key = "planet_id", prefix = "planet"}
    }
    
    for _, groupType in ipairs(groupTypes) do
        if entity[groupType.key] then
            return groupType.prefix .. "_" .. tostring(entity[groupType.key])
        end
    end
    
    -- Fallback to individual entity ID
    return "entity_" .. tostring(entity.id)
end

-- Function to establish entity group relationships
function EntityGroups.establishRelationship(entity, parentEntity, relationshipType)
    if not entity or not parentEntity then
        return false
    end
    
    local parentId = parentEntity.id or parentEntity
    if type(parentId) == "table" then
        parentId = parentId.id
    end
    
    if not parentId then
        return false
    end
    
    -- Set the appropriate group ID based on relationship type
    local relationshipMap = {
        station = "station_id",
        ship = "ship_id",
        asteroid = "asteroid_id",
        wreckage = "wreckage_id",
        enemy = "enemy_id",
        hub = "hub_id",
        warp_gate = "warp_gate_id",
        beacon = "beacon_id",
        ore_furnace = "ore_furnace_id",
        holographic_turret = "holographic_turret_id",
        reward_crate = "reward_crate_id",
        planet = "planet_id"
    }
    
    local groupKey = relationshipMap[relationshipType]
    if not groupKey then
        return false
    end
    
    entity[groupKey] = parentId
    if relationshipType == "station" then
        entity.parent_station = parentEntity
    end
    
    return true
end

return EntityGroups
