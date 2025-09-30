local Hotspots = require("src.components.hotspots")

local Mineable = {}
Mineable.__index = Mineable

function Mineable.new(values)
    local instance = setmetatable({}, Mineable)
    instance.resourceType = values.resourceType or "stone"
    instance.resources = values.resources or 100
    instance.maxResources = values.resources or 100
    -- Overall mining durability (seconds at miningPower=1); quick for now
    local durability = values.durability or 5.0
    instance.durability = durability
    instance.maxDurability = values.maxDurability or durability
    -- Mining progression fields
    instance.mineProgress = 0
    -- Per-cycle duration (seconds)
    instance.mineCycleTime = values.extractionCycle or values.mineCycleTime or 1.0
    -- Number of cycles is determined by the turret; stored at runtime as activeCyclesPerResource
    instance.cycleCount = 0
    instance.activeCyclesPerResource = values.activeCyclesPerResource -- optional; typically set by startMining
    -- Optional flag if systems prefer to mark on the component
    instance.isBeingMined = false
    
    -- Hotspot system for enhanced mining
    instance.hotspots = Hotspots.new({
        maxHotspots = values.maxHotspots or 3,
        hotspotRadius = values.hotspotRadius or 15,
        hotspotDamageMultiplier = values.hotspotDamageMultiplier or 2.0,
        hotspotLifetime = values.hotspotLifetime or 8.0,
        hotspotSpawnChance = values.hotspotSpawnChance or 0.3,
        hotspotSpawnInterval = values.hotspotSpawnInterval or 2.0
    })
    
    return instance
end

return Mineable
