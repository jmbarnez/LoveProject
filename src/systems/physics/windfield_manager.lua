--[[
    Windfield Physics Manager
    
    Centralized physics system using Windfield for all physics simulation.
    Handles collision classes, world management, and entity synchronization.
]]

local wf = require("src.libs.windfield")
local Radius = require("src.systems.collision.radius")
local Log = require("src.core.log")

local WindfieldManager = {}
WindfieldManager.__index = WindfieldManager

-- Physics constants
local PHYSICS_CONSTANTS = {
    GRAVITY_X = 0,
    GRAVITY_Y = 0,
    ALLOW_SLEEP = true,
    SPACE_DRAG = 0.99995,
    MIN_VELOCITY = 0.001,
    MAX_VELOCITY = 5000,
}

-- Collision classes
local COLLISION_CLASSES = {
    { name = "player", options = { ignores = {} } },
    { name = "asteroid", options = { ignores = {} } },
    { name = "projectile", options = { ignores = { "projectile" } } },
    { name = "station", options = { ignores = {} } },
    { name = "wreckage", options = { ignores = {} } },
    { name = "pickup", options = { ignores = {} } },
    { name = "sensor", options = { ignores = { "sensor" } } },
}

function WindfieldManager.new()
    local self = setmetatable({}, WindfieldManager)
    
    -- Create physics world
    self.world = wf.newWorld(PHYSICS_CONSTANTS.GRAVITY_X, PHYSICS_CONSTANTS.GRAVITY_Y, PHYSICS_CONSTANTS.ALLOW_SLEEP)
    
    -- Set up collision classes
    for _, class in ipairs(COLLISION_CLASSES) do
        self.world:addCollisionClass(class.name, class.options)
    end
    
    -- Set up collision callbacks
    self:setupCollisionCallbacks()
    
    -- Entity tracking
    self.entities = {} -- entity -> collider mapping
    self.colliders = {} -- collider -> entity mapping
    
    Log.info("physics", "Windfield physics manager initialized")
    
    return self
end

function WindfieldManager:setupCollisionCallbacks()
    -- Asteroid vs Asteroid collisions
    self.world:on("beginContact", function(colliderA, colliderB, contact)
        local entityA = self.colliders[colliderA]
        local entityB = self.colliders[colliderB]
        
        if not entityA or not entityB then 
            Log.debug("physics", "Collision detected but missing entities: entityA=%s, entityB=%s", 
                     entityA and "present" or "nil", entityB and "present" or "nil")
            return 
        end
        
        local classA = colliderA:getCollisionClass()
        local classB = colliderB:getCollisionClass()
        
        Log.debug("physics", "Collision detected: %s vs %s (entities: %s vs %s)", 
                 classA, classB, entityA.id or "unknown", entityB.id or "unknown")
        
        -- Handle asteroid collisions
        if classA == "asteroid" and classB == "asteroid" then
            self:handleAsteroidCollision(entityA, entityB, contact)
        end
        
        -- Handle projectile collisions
        if classA == "projectile" or classB == "projectile" then
            self:handleProjectileCollision(entityA, entityB, contact)
        end
        
        -- Handle player collisions
        if classA == "player" or classB == "player" then
            self:handlePlayerCollision(entityA, entityB, contact)
        end
    end)
end

function WindfieldManager:handleAsteroidCollision(entityA, entityB, contact)
    -- Asteroids will bounce naturally with Windfield physics
    -- We can add custom effects here if needed
    Log.debug("physics", "Asteroid collision: %s vs %s", entityA.subtype or "unknown", entityB.subtype or "unknown")
end

function WindfieldManager:handleProjectileCollision(entityA, entityB, contact)
    -- Handle projectile hits
    local projectile = entityA.components.bullet and entityA or entityB
    local target = entityA.components.bullet and entityB or entityA
    
    Log.debug("physics", "Projectile collision detected: projectile=%s, target=%s", 
             projectile and projectile.id or "nil", target and target.id or "nil")
    
    if projectile and target then
        -- Check if this collision should be ignored (e.g., projectile hitting its source)
        local ProjectileCollision = require("src.systems.collision.handlers.projectile_collision")
        local source = projectile.components.bullet and projectile.components.bullet.source
        
        if ProjectileCollision.shouldIgnoreTarget(projectile, target, source) then
            return -- Ignore this collision
        end
        
        -- Trigger projectile hit logic
        ProjectileCollision.handleProjectileCollision(projectile, target, 1/60, nil)
    end
end

function WindfieldManager:handlePlayerCollision(entityA, entityB, contact)
    -- Handle player collisions with other entities
    local player = entityA.isPlayer and entityA or entityB
    local other = entityA.isPlayer and entityB or entityA
    
    if player and other then
        Log.debug("physics", "Player collision with %s", other.subtype or "unknown")
        -- Add custom player collision logic here
    end
end

function WindfieldManager:addEntity(entity, colliderType, x, y, options)
    Log.debug("physics", "WindfieldManager:addEntity called for entity type: %s", entity.components and entity.components.bullet and "projectile" or "other")
    
    if not entity or not entity.components or not entity.components.position then
        Log.warn("physics", "Cannot add entity without position component")
        return nil
    end
    
    local pos = entity.components.position
    local x = x or pos.x
    local y = y or pos.y
    local options = options or {}
    
    -- If entity has windfield_physics component, use its properties
    if entity.components.windfield_physics then
        local physics = entity.components.windfield_physics
        colliderType = physics.colliderType or "circle"
        options.mass = physics.mass
        options.restitution = physics.restitution
        options.friction = physics.friction
        options.fixedRotation = physics.fixedRotation
        options.bodyType = physics.bodyType
        options.radius = physics.radius
        options.width = physics.width
        options.height = physics.height
        options.vertices = physics.vertices
    end
    
    -- Ensure we use the entity's actual position
    if not x or not y then
        x = pos.x
        y = pos.y
    end
    
    
    local collider = nil
    local collisionClass = self:determineCollisionClass(entity)
    
    if colliderType == "circle" then
        -- Use proper radius calculation based on visual boundaries
        local radius = options.radius or Radius.getHullRadius(entity) or 20
        collider = self.world:newCircleCollider(x, y, radius, options.bodyType or "dynamic")
        
    elseif colliderType == "rectangle" then
        local width = options.width or 40
        local height = options.height or 40
        collider = self.world:newRectangleCollider(x, y, width, height, options.bodyType or "dynamic")
    elseif colliderType == "polygon" then
        local vertices = options.vertices or {}
        if #vertices > 0 then
            collider = self.world:newPolygonCollider(vertices, options.bodyType or "dynamic")
        end
    end
    
    if not collider then
        Log.warn("physics", "Failed to create collider for entity")
        return nil
    end
    
    -- Configure collider
    collider:setCollisionClass(collisionClass)
    collider:setUserData(entity)
    
    -- Set physics properties
    if options.mass then
        collider:getBody():setMass(options.mass)
    end
    if options.restitution then
        collider:setRestitution(options.restitution)
    end
    if options.friction then
        collider:setFriction(options.friction)
    end
    if options.fixedRotation ~= nil then
        collider:setFixedRotation(options.fixedRotation)
    end
    
    -- Handle initial velocity for entities that have it (like wreckage)
    if entity._initialVelocity then
        local vx = entity._initialVelocity.x or 0
        local vy = entity._initialVelocity.y or 0
        local angular = entity._initialVelocity.angular or 0
        Log.debug("physics", "Found _initialVelocity: vx=%.2f, vy=%.2f", vx, vy)
        collider:setLinearVelocity(vx, vy)
        collider:setAngularVelocity(angular)
        
        -- Debug: Log velocity application
        if entity.components and entity.components.bullet then
            Log.debug("physics", "Applied initial velocity to projectile: vx=%.2f, vy=%.2f", vx, vy)
            -- Also log the actual velocity after setting it
            local actualVx, actualVy = collider:getLinearVelocity()
            Log.debug("physics", "Actual velocity after setting: vx=%.2f, vy=%.2f", actualVx, actualVy)
            
            -- Additional debug for left/right firing issue
            local angleDegrees = math.deg(math.atan2(vy, vx))
            local direction = vx > 0 and "RIGHT" or "LEFT"
            Log.debug("physics", "Physics direction: %s, Angle: %.2f° (%.2f rad), vx: %.2f, vy: %.2f", direction, angleDegrees, math.atan2(vy, vx), vx, vy)
        end
        
        entity._initialVelocity = nil -- Clear after use
    end
    
    -- Track entity
    self.entities[entity] = collider
    self.colliders[collider] = entity
    
    -- For fixed rotation entities, ensure the angle is set correctly
    if entity.components.windfield_physics and entity.components.windfield_physics.fixedRotation then
        collider:setAngle(0)
    end
    
    return collider
end

function WindfieldManager:determineCollisionClass(entity)
    if not entity or not entity.components then
        return "default"
    end
    
    if entity.isPlayer or entity.components.player then
        return "player"
    elseif entity.components.bullet then
        return "projectile"
    elseif entity.components.mineable then
        return "asteroid"
    elseif entity.components.station then
        return "station"
    elseif entity.components.wreckage then
        return "wreckage"
    elseif entity.components.item_pickup or entity.components.xp_pickup then
        return "pickup"
    end
    
    return "default"
end

function WindfieldManager:removeEntity(entity)
    local collider = self.entities[entity]
    if collider then
        collider:destroy()
        self.entities[entity] = nil
        self.colliders[collider] = nil
    end
end

function WindfieldManager:update(dt)
    -- Apply space drag to all dynamic bodies
    for entity, collider in pairs(self.entities) do
        if not collider:isDestroyed() then
            local vx, vy = collider:getLinearVelocity()
            if vx ~= 0 or vy ~= 0 then
                -- Apply space drag
                vx = vx * PHYSICS_CONSTANTS.SPACE_DRAG
                vy = vy * PHYSICS_CONSTANTS.SPACE_DRAG
                
                -- Stop very slow movement
                local speed = math.sqrt(vx * vx + vy * vy)
                if speed < PHYSICS_CONSTANTS.MIN_VELOCITY then
                    vx, vy = 0, 0
                end
                
                -- Cap maximum velocity
                if speed > PHYSICS_CONSTANTS.MAX_VELOCITY then
                    local ratio = PHYSICS_CONSTANTS.MAX_VELOCITY / speed
                    vx = vx * ratio
                    vy = vy * ratio
                end
                
                collider:setLinearVelocity(vx, vy)
            end
        end
    end
    
    -- Update physics world
    self.world:update(dt)
    
    -- Sync positions back to entities
    self:syncPositions()
end

function WindfieldManager:syncPositions()
    for entity, collider in pairs(self.entities) do
        if not collider:isDestroyed() and entity.components and entity.components.position then
            local x, y = collider:getPosition()
            local angle = collider:getAngle()
            
            entity.components.position.x = x
            entity.components.position.y = y
            
            -- Only sync angle if the entity is not fixed rotation
            if entity.components.windfield_physics and not entity.components.windfield_physics.fixedRotation then
                entity.components.position.angle = angle
            end
            -- For fixed rotation entities (like ships), keep their angle at 0
        end
    end
end

function WindfieldManager:applyForce(entity, fx, fy)
    local collider = self.entities[entity]
    if collider and not collider:isDestroyed() then
        collider:applyForce(fx, fy)
        Log.debug("physics", "Applied force to entity: fx=%.2f, fy=%.2f", fx, fy)
    else
        Log.warn("physics", "Cannot apply force: collider not found or destroyed")
    end
end

function WindfieldManager:applyImpulse(entity, ix, iy)
    local collider = self.entities[entity]
    if collider and not collider:isDestroyed() then
        collider:applyLinearImpulse(ix, iy)
    end
end

function WindfieldManager:setVelocity(entity, vx, vy)
    local collider = self.entities[entity]
    if collider and not collider:isDestroyed() then
        collider:setLinearVelocity(vx, vy)
    end
end

function WindfieldManager:getVelocity(entity)
    local collider = self.entities[entity]
    if collider and not collider:isDestroyed() then
        return collider:getLinearVelocity()
    end
    return 0, 0
end

function WindfieldManager:getPosition(entity)
    local collider = self.entities[entity]
    if collider and not collider:isDestroyed() then
        return collider:getPosition()
    end
    return 0, 0
end

function WindfieldManager:getAngle(entity)
    local collider = self.entities[entity]
    if collider and not collider:isDestroyed() then
        return collider:getAngle()
    end
    return 0
end

function WindfieldManager:getCollider(entity)
    return self.entities[entity]
end

function WindfieldManager:destroy()
    if self.world then
        self.world:destroy()
        self.world = nil
    end
    self.entities = {}
    self.colliders = {}
end

return WindfieldManager
