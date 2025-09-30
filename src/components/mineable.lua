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
    instance._wasBeingMined = false
    -- Mining hotspot configuration
    instance.hotspotRadius = values.hotspotRadius -- initialized later using entity radius if absent
    instance.hotspotRadiusScale = values.hotspotRadiusScale or 0.28

    local hotspotDamage = values.hotspotDamage or 8
    local damageMultiplier = values.hotspotDamageMultiplier or 1.8
    instance.hotspotBurstDamage = values.hotspotBurstDamage or (hotspotDamage * damageMultiplier)
    instance.hotspotBonusResources = values.hotspotBonusResources or 2

    -- Hotspot system for enhanced mining
    instance.hotspots = Hotspots.new({
        maxHotspots = values.maxHotspots or 3,
        hotspotRadius = values.hotspotRadius or 15,
        hotspotLifetime = values.hotspotLifetime or 6.0,
        hotspotSpawnChance = values.hotspotSpawnChance or 0.4,
        hotspotSpawnInterval = values.hotspotSpawnInterval or 2.0,
        hotspotSpawnJitter = values.hotspotSpawnJitter or 0.8,
        hotspotBonusResources = instance.hotspotBonusResources,
        hotspotBurstDamage = instance.hotspotBurstDamage
    })

    return instance
end

return Mineable
