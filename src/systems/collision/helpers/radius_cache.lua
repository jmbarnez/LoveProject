local Radius = require("src.systems.collision.radius")

--- RadiusCache centralises broad-phase radius lookups so CollisionSystem and its
--- handlers can share consistent values without repeating expensive radius
--- computations every frame.
local RadiusCache = {}
RadiusCache.__index = RadiusCache

local function entity_cache_key(entity, suffix)
    local entityId = entity.id or tostring(entity):gsub("table: ", "")
    local version = suffix == "visual" and (entity._visualRadiusCacheVersion or 0)
        or (entity._radiusCacheVersion or 0)
    return string.format("%s_%s_%s", entityId, suffix, version)
end

local function truncate_cache(store, limit)
    local kept, count = {}, 0
    for key, value in pairs(store) do
        if count >= limit then break end
        kept[key] = value
        count = count + 1
    end
    return kept
end

function RadiusCache.new()
    return setmetatable({
        effective = {},
        visual = {},
        counter = 0,
    }, RadiusCache)
end

function RadiusCache:getEffectiveRadius(entity)
    local key = entity_cache_key(entity, "effective")
    local cached = self.effective[key]
    if cached then
        return cached
    end

    local radius = Radius.calculateEffectiveRadius(entity)
    self.effective[key] = radius
    self.counter = self.counter + 1

    if self.counter > 1000 then
        self.counter = 0
        self.effective = truncate_cache(self.effective, 500)
    end

    return radius
end

function RadiusCache:getVisualRadius(entity)
    local key = entity_cache_key(entity, "visual")
    local cached = self.visual[key]
    if cached then
        return cached
    end

    local radius = Radius.computeVisualRadius(entity)
    self.visual[key] = radius
    self.counter = self.counter + 1

    if self.counter > 1000 then
        self.counter = 0
        self.visual = truncate_cache(self.visual, 500)
    end

    return radius
end

return RadiusCache
