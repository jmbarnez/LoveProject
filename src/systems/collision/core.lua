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
    for _, e in pairs(world:get_entities_with_components("collidable", "position")) do
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

    -- Insert renderable-only entities (e.g., stations, planets, warp gates) for rendering culling
    -- These have no physics collisions but need broad-phase for visibility
    local Radius = require("src.systems.collision.radius")
    for _, e in pairs(world:get_entities_with_components("renderable", "position")) do
        if not e.components.collidable then  -- Only if no collidable component
            local visualR = Radius.computeVisualRadius(e)
            if visualR > 0 then
                local r = visualR  -- Use visual radius directly
                self.quadtree:insert({
                    x = e.components.position.x - r,
                    y = e.components.position.y - r,
                    width = r * 2,
                    height = r * 2,
                    entity = e
                })
            end
        end
    end

    -- Process all bullets/projectiles
    for _, b in ipairs(world:get_entities_with_components("bullet", "collidable", "position")) do
        local renderable = b.components.renderable
        if not renderable or not renderable.props then goto continue end

        local kind = renderable.props.kind
        if kind == "laser" or kind == "salvaging_laser" or kind == "mining_laser" then
            ProjectileCollision.handle_beam_collision(self, b, world, dt)
        else
            ProjectileCollision.handle_projectile_collision(self, b, world, dt)
        end
        ::continue::
    end

    -- Process entity-to-entity collisions (excluding item pickups)
    local collidable_entities = world:get_entities_with_components("collidable", "position")
    for _, entity in ipairs(collidable_entities) do
        -- Skip item pickups since they shouldn't cause physical collisions
        if not entity.components.item_pickup then
            EntityCollision.handleEntityCollisions(self, entity, world, dt)
        end
    end
end

return CollisionSystem
