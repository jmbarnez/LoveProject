local Quadtree = require("src.core.quadtree")
local EntityCollision = require("src.systems.collision.entity_collision")
local WindfieldWorld = require("src.core.windfield_world")
local RadiusCache = require("src.systems.collision.helpers.radius_cache")

--- CollisionSystem orchestrates broad-phase queries, delegates collision
--- resolution to specialised handlers, and keeps the physics world in sync
--- with entity state.
local CollisionSystem = {}
CollisionSystem.__index = CollisionSystem

function CollisionSystem:new(worldBounds)
    local instance = setmetatable({
        quadtree = Quadtree.new(worldBounds, 4),
        windfield = WindfieldWorld.new({
            gravityX = 0,
            gravityY = 0,
            allowSleep = true,
            debugFlag = "collision",
        }),
        lastWindfieldContacts = {},
        radius_cache = RadiusCache.new(),
    }, CollisionSystem)

    return instance
end

function CollisionSystem:getWindfield()
    return self.windfield
end

function CollisionSystem:getWindfieldContacts()
    return self.lastWindfieldContacts
end

local function determine_body_type(entity)
    if not entity or not entity.components then return "static" end
    if entity.components.physics and entity.components.physics.body then
        return "dynamic"
    end
    if entity.components.bullet then
        return "kinematic"
    end
    return "static"
end

function CollisionSystem:update(world, dt)
    self:refreshBroadphase(world)
    self:syncWindfield(world, dt)
    self:processProjectiles(world, dt)
    self:processEntities(world, dt)
end

function CollisionSystem:refreshBroadphase(world)
    self.quadtree:clear()

    if self.windfield then
        self.windfield:beginSync()
    end

    for _, entity in pairs(world:get_entities_with_components("collidable", "position")) do
        local radius = self.radius_cache:getEffectiveRadius(entity)
        self.quadtree:insert({
            x = entity.components.position.x - radius,
            y = entity.components.position.y - radius,
            width = radius * 2,
            height = radius * 2,
            entity = entity,
        })

        if self.windfield then
            self:syncWindfieldBody(entity, radius)
        end
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

function CollisionSystem:syncWindfieldBody(entity, radius)
    if not self.windfield then
        return
    end

    local pos = entity.components.position
    local physics = entity.components.physics
    local physics_body = physics and physics.body or nil
    local sync_angle = pos.angle

    if physics_body then
        local body_x, body_y
        if physics_body.getPosition then
            body_x, body_y = physics_body:getPosition()
        else
            body_x = physics_body.x
            body_y = physics_body.y
        end

        if body_x ~= nil and body_y ~= nil then
            pos.x = body_x
            pos.y = body_y
        end

        if physics_body.getAngle then
            sync_angle = physics_body:getAngle()
        elseif physics_body.angle ~= nil then
            sync_angle = physics_body.angle
        end

        if sync_angle ~= nil then
            pos.angle = sync_angle
        end
    end

    local collider = self.windfield:syncCircle(entity, pos.x, pos.y, radius, {
        bodyType = determine_body_type(entity),
        angle = sync_angle,
    })

    if collider and physics_body then
        local vx, vy
        if physics_body.getLinearVelocity then
            vx, vy = physics_body:getLinearVelocity()
        else
            vx = physics_body.vx
            vy = physics_body.vy
        end

        if vx ~= nil and vy ~= nil then
            collider:setLinearVelocity(vx, vy)
        end
    end
end

function CollisionSystem:syncWindfield(world, dt)
    if not self.windfield then
        return
    end

    self.windfield:endSync()
    self.windfield:update(dt)
    self.lastWindfieldContacts = self.windfield:drainContacts()
end

function CollisionSystem:processProjectiles(world, dt)
    -- Projectiles now use unified collision system via processEntities
    -- This function is kept for compatibility but no longer processes projectiles separately
end

function CollisionSystem:processEntities(world, dt)
    for _, entity in ipairs(world:get_entities_with_components("collidable", "position")) do
        if not entity.components.item_pickup then
            -- Store world reference on entity for projectile collision handling
            entity._world = world
            EntityCollision.handleEntityCollisions(self, entity, world, dt)
        end
    end
end

return CollisionSystem
