--[[
    Windfield Physics Manager
    
    Centralized physics system using Windfield for all physics simulation.
    Handles collision classes, world management, and entity synchronization.
    
    COLLISION DETECTION OWNERSHIP:
    - This system owns ALL collision detection via Windfield callbacks
    - Legacy quadtree collision detection is disabled
    - All collision effects are triggered from here
    - Entity lifecycle managed by CollisionSystem (quadtree for broad-phase only)
    
    FIXED ROTATION PROTECTION:
    - Ships have fixedRotation = true and never rotate
    - Angular velocity is blocked for fixed rotation entities
    - Position syncing ensures ships maintain angle = 0
    - Safety checks prevent any accidental rotation
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
    { name = "reward_crate", options = { ignores = {} } },
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
    -- Unified collision handling for all entity types
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
        
        -- Additional debug for projectile collisions
        if classA == "projectile" or classB == "projectile" then
            local projectile = entityA.components.bullet and entityA or entityB
            local target = entityA.components.bullet and entityB or entityA
            Log.debug("physics", "Projectile collision: projectile=%s (class=%s), target=%s (class=%s)", 
                     projectile and projectile.id or "nil", classA == "projectile" and classA or classB,
                     target and target.id or "nil", classA == "projectile" and classB or classA)
        end
        
        -- Handle all collision types through unified system
        self:handleCollision(entityA, entityB, contact, classA, classB)
    end)
end

function WindfieldManager:handleCollision(entityA, entityB, contact, classA, classB)
    -- Unified collision handling for all entity types
    -- Windfield handles physics resolution automatically, we handle game logic
    
    -- Check for collision grace periods
    if entityA._collisionGrace and entityA._collisionGrace > 0 then
        return
    end
    if entityB._collisionGrace and entityB._collisionGrace > 0 then
        return
    end
    
    -- Skip friendly vs station shield collisions (allow friendlies inside station bubble)
    local StationShields = require("src.systems.collision.station_shields")
    if StationShields.shouldIgnoreEntityCollision(entityA, entityB) then
        return
    end
    
    -- Ignore collisions between the player and warp gates (stations now have physical hulls)
    local eIsPlayer = entityA.isPlayer or (entityA.components and entityA.components.player)
    local oIsPlayer = entityB.isPlayer or (entityB.components and entityB.components.player)
    local eIsWarpGate = entityA.tag == "warp_gate"
    local oIsWarpGate = entityB.tag == "warp_gate"
    if (eIsPlayer and oIsWarpGate) or (oIsPlayer and eIsWarpGate) then
        return
    end
    
    -- Handle projectile collisions first (they have special logic)
    if classA == "projectile" or classB == "projectile" then
        self:handleProjectileCollision(entityA, entityB, contact)
        return
    end
    
    -- Handle all other entity collisions
    self:handleEntityCollision(entityA, entityB, contact, classA, classB)
end

function WindfieldManager:handleEntityCollision(entityA, entityB, contact, classA, classB)
    -- Handle non-projectile entity collisions
    -- Get collision points for effects
    local posA = entityA.components.position
    local posB = entityB.components.position
    
    if not posA or not posB then
        return
    end
    
    -- Calculate collision normal from contact
    local worldManifold = contact:getWorldManifold()
    local points = worldManifold:getPoints()
    local normal = worldManifold:getNormal()
    
    local hitX, hitY = posA.x, posA.y
    if #points > 0 then
        hitX, hitY = points[1].x, points[1].y
    end
    
    -- Create collision effects
    local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
    local CollisionEffects = require("src.systems.collision.effects")
    if CollisionEffects.canEmitCollisionFX(entityA, entityB, now) then
        local Radius = require("src.systems.collision.radius")
        local radiusA = Radius.getHullRadius(entityA) or 20
        local radiusB = Radius.getHullRadius(entityB) or 20
        
        CollisionEffects.createCollisionEffects(entityA, entityB, 
                                               posA.x, posA.y, posB.x, posB.y,
                                               normal.x, normal.y, radiusA, radiusB, nil, nil)
    end
    
    -- Handle specific collision types
    if classA == "asteroid" and classB == "asteroid" then
        self:handleAsteroidCollision(entityA, entityB, contact)
    elseif classA == "player" or classB == "player" then
        self:handlePlayerCollision(entityA, entityB, contact)
    end
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
        
        -- Get precise hit position from contact
        local worldManifold = contact:getWorldManifold()
        local points = worldManifold:getPoints()
        local hitX, hitY = projectile.components.position.x, projectile.components.position.y
        if #points > 0 then
            hitX, hitY = points[1].x, points[1].y
        end
        
        -- Create collision effects using precise hit position
        local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
        local CollisionEffects = require("src.systems.collision.effects")
        if CollisionEffects.canEmitCollisionFX(projectile, target, now) then
            local Radius = require("src.systems.collision.radius")
            local targetRadius = Radius.getHullRadius(target) or 20
            local bulletRadius = Radius.getHullRadius(projectile) or 2
            
            CollisionEffects.createCollisionEffects(projectile, target, hitX, hitY, hitX, hitY, 0, 0, bulletRadius, targetRadius, nil, nil)
        end
        
        -- Trigger projectile hit logic with precise hit position
        ProjectileCollision.handleProjectileCollision(projectile, target, 1/60, nil, hitX, hitY)

        -- Destroy projectile collider immediately to prevent post-hit bounce
        local projectileCollider = self.entities[projectile]
        if projectileCollider and not projectileCollider:isDestroyed() then
            projectileCollider:setLinearVelocity(0, 0)
            projectileCollider:destroy()
        end
        if projectileCollider then
            self.colliders[projectileCollider] = nil
        end
        self.entities[projectile] = nil
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
        -- Only use windfield_physics vertices if no vertices were already set by the calling system
        if not options.vertices or #options.vertices == 0 then
            options.vertices = physics.vertices
        end
    end
    
    -- Ensure we use the entity's actual position
    if not x or not y then
        x = pos.x
        y = pos.y
    end
    
    
    local collider = nil
    local collisionClass = self:determineCollisionClass(entity)
    
    -- Debug: Log collision class assignment
    Log.debug("physics", "Entity %s assigned collision class: %s", 
             entity.id or "unknown", collisionClass)
    
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

    if collider.setPosition then
        collider:setPosition(x, y)
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
        
        -- Only apply angular velocity if the entity is not fixed rotation
        if not options.fixedRotation then
            collider:setAngularVelocity(angular)
        else
            -- Ships and other fixed rotation entities never rotate
            collider:setAngularVelocity(0)
        end
        
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
    else
        -- For entities without initial velocity (like player ships), ensure they start with zero velocity
        -- This prevents any default velocity from Windfield from causing movement hitches
        collider:setLinearVelocity(0, 0)
        collider:setAngularVelocity(0)
    end
    
    -- Track entity
    self.entities[entity] = collider
    self.colliders[collider] = entity
    
    -- For fixed rotation entities, ensure the angle is set correctly
    if options.fixedRotation then
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
    elseif entity.components.interactable and entity.components.interactable.requiresKey == "reward_crate_key" then
        return "reward_crate"
    elseif entity.subtype == "reward_crate" then
        return "reward_crate"
    elseif entity.components.enemy or entity.isEnemy then
        return "player" -- Enemy ships use the same collision class as player ships
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
    -- Apply space drag to all dynamic bodies EXCEPT ships
    for entity, collider in pairs(self.entities) do
        if not collider:isDestroyed() then
            -- Skip ships - they handle their own velocity through thruster forces
            local isShip = entity.isPlayer or (entity.components and entity.components.player)
            if not isShip then
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
            
            -- Ensure fixed rotation entities never have angular velocity
            if entity.components.windfield_physics and entity.components.windfield_physics.fixedRotation then
                local angularVel = collider:getAngularVelocity()
                if angularVel ~= 0 then
                    collider:setAngularVelocity(0)
                end
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
            
            -- Check if this is a ship (player or AI)
            local isShip = entity.isPlayer or (entity.components and entity.components.player)
            
            if isShip then
                -- For ships, only sync position if they have velocity (are actually moving)
                local vx, vy = collider:getLinearVelocity()
                local speed = math.sqrt(vx * vx + vy * vy)
                
                if speed > 0.1 then
                    entity.components.position.x = x
                    entity.components.position.y = y
                end
                -- Ships always have angle 0 (fixed rotation)
                entity.components.position.angle = 0
            else
                -- For non-ships, always sync position
                entity.components.position.x = x
                entity.components.position.y = y
                
                -- Only sync angle if the entity is not fixed rotation
                local isFixedRotation = false
                if entity.components.windfield_physics and entity.components.windfield_physics.fixedRotation then
                    isFixedRotation = true
                end
                
                if not isFixedRotation then
                    entity.components.position.angle = angle
                else
                    entity.components.position.angle = 0
                end
            end
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

function WindfieldManager:applyAngularImpulse(entity, impulse)
    -- Prevent angular impulse on fixed rotation entities (like ships)
    if entity.components.windfield_physics and entity.components.windfield_physics.fixedRotation then
        Log.debug("physics", "Blocked angular impulse on fixed rotation entity")
        return
    end
    
    local collider = self.entities[entity]
    if collider and not collider:isDestroyed() then
        collider:applyAngularImpulse(impulse)
        Log.debug("physics", "Applied angular impulse to entity: %.2f", impulse)
    else
        Log.warn("physics", "Cannot apply angular impulse: collider not found or destroyed")
    end
end

function WindfieldManager:setAngularVelocity(entity, velocity)
    -- Prevent angular velocity on fixed rotation entities (like ships)
    if entity.components.windfield_physics and entity.components.windfield_physics.fixedRotation then
        Log.debug("physics", "Blocked angular velocity on fixed rotation entity")
        return
    end
    
    local collider = self.entities[entity]
    if collider and not collider:isDestroyed() then
        collider:setAngularVelocity(velocity)
        Log.debug("physics", "Set angular velocity for entity: %.2f", velocity)
    else
        Log.warn("physics", "Cannot set angular velocity: collider not found or destroyed")
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

function WindfieldManager:raycast(x1, y1, x2, y2, opts)
    opts = opts or {}

    local dx = (x2 or 0) - (x1 or 0)
    local dy = (y2 or 0) - (y1 or 0)
    local lengthSq = dx * dx + dy * dy
    if lengthSq <= 0 then
        return nil
    end

    local segmentLength = math.sqrt(lengthSq)

    local ignoreSet = {}
    local function addIgnore(value)
        if not value then
            return
        end
        local valueType = type(value)
        if valueType == "table" then
            -- Accept both array-style and map-style tables
            for key, v in pairs(value) do
                if type(key) == "number" then
                    ignoreSet[v] = true
                else
                    ignoreSet[key] = true
                end
            end
        else
            ignoreSet[value] = true
        end
    end

    addIgnore(opts.ignore)
    addIgnore(opts.ignoreEntity)
    addIgnore(opts.ignoreEntities)
    addIgnore(opts.exclude)
    addIgnore(opts.excludeEntity)
    addIgnore(opts.excludeEntities)

    local includeDead = opts.includeDead == true
    local includeSensors = opts.includeSensors == true

    local bestFraction
    local bestResult

    for entity, collider in pairs(self.entities) do
        repeat
            if not collider or collider:isDestroyed() then
                break
            end

            if ignoreSet[entity] then
                break
            end

            if not includeDead and entity.dead then
                break
            end

            if opts.filter and not opts.filter(entity, collider) then
                break
            end

            if not includeSensors then
                local fixture = collider.fixture
                if fixture and fixture.isSensor and fixture:isSensor() then
                    break
                end
            end

            local cx, cy = collider:getPosition()
            if not cx or not cy then
                break
            end

            local radius = Radius.getHullRadius(entity) or 20
            if not radius or radius <= 0 then
                break
            end

            local fx = x1 - cx
            local fy = y1 - cy

            local a = lengthSq
            local b = 2 * (fx * dx + fy * dy)
            local c = fx * fx + fy * fy - radius * radius

            local discriminant = b * b - 4 * a * c
            if discriminant < 0 then
                break
            end

            local sqrtDisc = math.sqrt(discriminant)
            local denom = 2 * a

            local function consider(t)
                if t and t >= 0 and t <= 1 then
                    if not bestFraction or t < bestFraction then
                        local hitX = x1 + dx * t
                        local hitY = y1 + dy * t
                        bestFraction = t
                        bestResult = {
                            entity = entity,
                            collider = collider,
                            x = hitX,
                            y = hitY,
                            fraction = t,
                            distance = segmentLength * t,
                            collisionClass = collider:getCollisionClass(),
                        }
                    end
                end
            end

            consider((-b - sqrtDisc) / denom)
            consider((-b + sqrtDisc) / denom)
        until true
    end

    return bestResult
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
