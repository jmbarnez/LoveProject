local Quadtree = require("src.core.quadtree")
local Radius = require("src.systems.collision.radius")
local EntityCollision = require("src.systems.collision.entity_collision")
local ProjectileCollision = require("src.systems.collision.projectile_collision")

local CollisionSystem = {}

function CollisionSystem:new(worldBounds)
    local self = setmetatable({}, {__index = self})
    self.quadtree = Quadtree.new(worldBounds, 4)
    return self
end

function CollisionSystem:update(world, dt)
    self.quadtree:clear()

    -- Insert all collidable entities into the quadtree
    for _, e in pairs(world:getEntitiesWithComponents("collidable", "position")) do
        -- Use effective radius (accounts for active shields) for broad-phase
        local r = Radius.calculateEffectiveRadius(e)
        self.quadtree:insert({
            x = e.components.position.x - r,
            y = e.components.position.y - r,
            width = r * 2,
            height = r * 2,
            entity = e
        })
    end

    -- Process all bullets/projectiles
    for _, b in ipairs(world:getEntitiesWithComponents("bullet", "collidable", "position")) do
        local renderable = b.components.renderable
        if not renderable or not renderable.props then goto continue end

        local kind = renderable.props.kind
        if kind == "laser" or kind == "salvaging_laser" or kind == "mining_laser" then
            ProjectileCollision.handleBeamCollision(self, b, world, dt)
        else
            ProjectileCollision.handleProjectileCollision(self, b, world, dt)
        end
        ::continue::
    end

    -- Process entity-to-entity collisions (including ships, stations, asteroids, etc.)
    local collidableEntities = world:getEntitiesWithComponents("collidable", "position")
    for _, entity in ipairs(collidableEntities) do
        EntityCollision.handleEntityCollisions(self, entity, world, dt)
    end
end

return CollisionSystem