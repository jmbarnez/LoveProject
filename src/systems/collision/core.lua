local Quadtree = require("src.core.quadtree")
local Radius = require("src.systems.collision.radius")
local EntityCollision = require("src.systems.collision.entity_collision")
local ProjectileCollision = require("src.systems.collision.projectile_collision")
local WindfieldWorld = require("src.core.windfield_world")

local CollisionSystem = {}

-- Cache for expensive radius calculations
local radiusCache = {}
local visualRadiusCache = {}
local cacheCounter = 0

-- Cached radius calculation to avoid expensive recalculations
local function getCachedEffectiveRadius(entity)
    local entityId = entity.id or tostring(entity):gsub("table: ", "")
    local cacheKey = entityId .. "_" .. (entity._radiusCacheVersion or 0)

    -- Check if we have a cached value
    if radiusCache[cacheKey] then
        return radiusCache[cacheKey]
    end

    -- Calculate and cache the radius
    local radius = Radius.calculateEffectiveRadius(entity)
    radiusCache[cacheKey] = radius

    -- Periodic cleanup to prevent memory leaks
    cacheCounter = cacheCounter + 1
    if cacheCounter > 1000 then
        cacheCounter = 0
        -- Clear old entries
        local newCache = {}
        local count = 0
        for k, v in pairs(radiusCache) do
            if count < 500 then
                newCache[k] = v
                count = count + 1
            end
        end
        radiusCache = newCache
    end

    return radius
end

-- Cached visual radius calculation
local function getCachedVisualRadius(entity)
    local entityId = entity.id or tostring(entity):gsub("table: ", "")
    local cacheKey = entityId .. "_visual_" .. (entity._visualRadiusCacheVersion or 0)

    if visualRadiusCache[cacheKey] then
        return visualRadiusCache[cacheKey]
    end

    local radius = Radius.computeVisualRadius(entity)
    visualRadiusCache[cacheKey] = radius
    return radius
end

function CollisionSystem:new(worldBounds)
    local self = setmetatable({}, {__index = self})
    self.quadtree = Quadtree.new(worldBounds, 4)
    self.windfield = WindfieldWorld.new({
        gravityX = 0,
        gravityY = 0,
        allowSleep = true,
        debugFlag = "collision",
    })
    self.lastWindfieldContacts = {}
    return self
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
    self.quadtree:clear()

    if self.windfield then
        self.windfield:beginSync()
    end

    -- Insert all collidable entities into the quadtree
    for _, e in pairs(world:get_entities_with_components("collidable", "position")) do
        -- Use cached effective radius (accounts for active shields) for broad-phase
        local r = getCachedEffectiveRadius(e)
        self.quadtree:insert({
            x = e.components.position.x - r,
            y = e.components.position.y - r,
            width = r * 2,
            height = r * 2,
            entity = e
        })

        if self.windfield then
            local pos = e.components.position
            local physics = e.components.physics
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

            local collider = self.windfield:syncCircle(e, pos.x, pos.y, r, {
                bodyType = determine_body_type(e),
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
    end

    -- Insert renderable-only entities (e.g., stations, planets, warp gates) for rendering culling
    -- These have no physics collisions but need broad-phase for visibility
    for _, e in pairs(world:get_entities_with_components("renderable", "position")) do
        if not e.components.collidable then  -- Only if no collidable component
            local visualR = getCachedVisualRadius(e)
            if visualR > 0 then
                local r = visualR  -- Use cached visual radius directly
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

    if self.windfield then
        self.windfield:endSync()
        self.windfield:update(dt)
        self.lastWindfieldContacts = self.windfield:drainContacts()
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
