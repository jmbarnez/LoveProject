local Quadtree = require("src.core.quadtree")
local EntityCollision = require("src.systems.collision.entity_collision")
local RadiusCache = require("src.systems.collision.helpers.radius_cache")
local PhysicsSystem = require("src.systems.physics")
local Log = require("src.core.log")

--- CollisionSystem orchestrates broad-phase queries, delegates collision
--- resolution to specialised handlers, and keeps the physics world in sync
--- with entity state.
local CollisionSystem = {}
CollisionSystem.__index = CollisionSystem

function CollisionSystem:new(worldBounds)
    local instance = setmetatable({
        quadtree = Quadtree.new(worldBounds, 4),
        radius_cache = RadiusCache.new(),
    }, CollisionSystem)

    return instance
end


local function determine_body_type(entity)
    if not entity or not entity.components then return "static" end
    
    -- Check Windfield physics first
    if entity.components.windfield_physics then
        return "dynamic"
    end
    
    -- Check legacy physics
    if entity.components.physics and entity.components.physics.body then
        return "dynamic"
    end
    
    if entity.components.bullet then
        return "kinematic"
    end
    
    -- Special case for reward crates - they should be dynamic if they have physics component
    if entity.subtype == "reward_crate" and (entity.components.windfield_physics or entity.components.physics) then
        return "dynamic"
    end
    
    return "static"
end

function CollisionSystem:update(world, dt)
    -- Windfield handles all physics and collision detection
    -- We only need to manage entity lifecycle and broad-phase queries
    self:refreshBroadphase(world)
    self:processProjectiles(world, dt)
    self:processEntities(world, dt)
end

function CollisionSystem:refreshBroadphase(world)
    self.quadtree:clear()

    for _, entity in pairs(world:get_entities_with_components("collidable", "position")) do
        local radius = self.radius_cache:getEffectiveRadius(entity)
        self.quadtree:insert({
            x = entity.components.position.x - radius,
            y = entity.components.position.y - radius,
            width = radius * 2,
            height = radius * 2,
            entity = entity,
        })
    end

    for _, entity in pairs(world:get_entities_with_components("renderable", "position")) do
        if not entity.components.collidable then
            local visualRadius = self.radius_cache:getVisualRadius(entity)
            if visualRadius > 0 then
                self.quadtree:insert({
                    x = entity.components.position.x - visualRadius,
                    y = entity.components.position.y - visualRadius,
                    width = visualRadius * 2,
                    height = visualRadius * 2,
                    entity = entity,
                })
            end
        end
    end
end


function CollisionSystem:processProjectiles(world, dt)
    -- Projectiles now use unified collision system via processEntities
    -- This function is kept for compatibility but no longer processes projectiles separately
end

function CollisionSystem:processEntities(world, dt)
    -- Windfield handles collision detection automatically
    -- We only need to handle special cases and entity lifecycle
    for _, entity in ipairs(world:get_entities_with_components("collidable", "position")) do
        if not entity.components.item_pickup and not entity.components.bullet then
            -- Store world reference on entity for projectile collision handling
            entity._world = world
            
            -- Add entity to physics system if not already added
            -- Skip projectiles as they are handled by the projectile system
            if not entity._physicsAdded then
                Log.debug("collision", "Adding entity to physics system via collision system: %s", entity.id or "unknown")
                local result = PhysicsSystem.addEntity(entity)
                entity._physicsAdded = true
                Log.debug("collision", "Physics system result: %s", result and "success" or "failed")
            end
        end
    end
end

return CollisionSystem
