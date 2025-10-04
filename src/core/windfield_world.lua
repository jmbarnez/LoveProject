local wf = require("src.libs.windfield")
local Debug = require("src.core.debug")

local WindfieldWorld = {}
WindfieldWorld.__index = WindfieldWorld

local function default_classes()
    return {
        { name = "default" },
        { name = "projectile", options = { ignores = { "projectile" } } },
        { name = "sensor", options = { ignores = { "sensor" } } },
    }
end

function WindfieldWorld.new(opts)
    opts = opts or {}
    local self = setmetatable({}, WindfieldWorld)
    self.world = wf.newWorld(opts.gravityX or 0, opts.gravityY or 0, opts.allowSleep)
    self.colliders = {}
    self.seen = {}
    self.pendingContacts = {}
    self.debugFlag = opts.debugFlag or "collision"
    self.collisionClasses = {}

    local classes = opts.collisionClasses or default_classes()
    self:setCollisionClasses(classes)
    self:_configureCallbacks()

    return self
end

function WindfieldWorld:_configureCallbacks()
    if not self.world or not self.world.on then
        return
    end

    local function enqueue(kind, colliderA, colliderB, contact)
        table.insert(self.pendingContacts, {
            kind = kind,
            a = colliderA,
            b = colliderB,
            contact = contact,
        })
    end

    self.world:on("beginContact", function(a, b, contact)
        enqueue("begin", a, b, contact)
    end)
    self.world:on("endContact", function(a, b, contact)
        enqueue("end", a, b, contact)
    end)
end

function WindfieldWorld:setCollisionClasses(classDefs)
    if not self.world then return end
    for _, def in ipairs(classDefs or {}) do
        if def.name and not self.collisionClasses[def.name] then
            self.world:addCollisionClass(def.name, def.options or {})
            self.collisionClasses[def.name] = def.options or {}
        end
    end
end

function WindfieldWorld:getWorld()
    return self.world
end

function WindfieldWorld:beginSync()
    self.seen = {}
end

local function entity_key(entity)
    if not entity then return nil end
    return entity.id or entity
end

local function resolve_body_type(entity)
    if not entity or not entity.components then
        return "static"
    end
    local physics = entity.components.physics
    if physics and physics.body then
        return "dynamic"
    end
    return "static"
end

local function resolve_collision_class(entity, opts)
    if opts and opts.collisionClass then
        return opts.collisionClass
    end
    if not entity or not entity.components then
        return "default"
    end
    if entity.components.bullet then
        return "projectile"
    end
    local collidable = entity.components.collidable
    if collidable and collidable.isSensor then
        return "sensor"
    end
    return "default"
end

function WindfieldWorld:syncCircle(entity, x, y, radius, opts)
    local key = entity_key(entity)
    if not key then return nil end

    local entry = self.colliders[key]
    if not entry then
        local collider = self.world:newCircleCollider(x, y, radius, opts and opts.bodyType or resolve_body_type(entity))
        collider:setCollisionClass(resolve_collision_class(entity, opts))
        collider:setUserData(entity or key)
        if opts and opts.isSensor ~= nil then
            collider:setSensor(opts.isSensor)
        else
            local collidable = entity and entity.components and entity.components.collidable
            if collidable and collidable.isSensor ~= nil then
                collider:setSensor(collidable.isSensor)
            end
        end
        if opts and opts.fixedRotation ~= nil then
            collider:setFixedRotation(opts.fixedRotation)
        end
        entry = { collider = collider, entity = entity }
        self.colliders[key] = entry
    end

    local collider = entry.collider
    if collider then
        if radius then
            collider:setRadius(radius)
        end
        if x and y then
            collider:setPosition(x, y)
        end
        if opts and opts.angle then
            collider:setAngle(opts.angle)
        elseif entity and entity.components and entity.components.position and entity.components.position.angle then
            collider:setAngle(entity.components.position.angle)
        end
    end

    self.seen[key] = true
    return collider
end

function WindfieldWorld:syncFromPhysicsBody(entity, body)
    if not entity then return end
    local key = entity_key(entity)
    local entry = self.colliders[key]
    if not entry or not entry.collider then return end

    local collider = entry.collider
    if not collider then return end

    if body then
        if body.getPosition then
            local bx, by = body:getPosition()
            collider:setPosition(bx, by)
        elseif body.x and body.y then
            collider:setPosition(body.x, body.y)
        end

        if body.getAngle then
            collider:setAngle(body:getAngle())
        elseif body.angle then
            collider:setAngle(body.angle)
        end

        if body.getLinearVelocity then
            local vx, vy = body:getLinearVelocity()
            collider:setLinearVelocity(vx, vy)
        elseif body.vx and body.vy then
            collider:setLinearVelocity(body.vx, body.vy)
        end
    end
end

function WindfieldWorld:endSync()
    for key, entry in pairs(self.colliders) do
        if not self.seen[key] then
            if entry.collider and entry.collider.destroy then
                entry.collider:destroy()
            end
            self.colliders[key] = nil
        end
    end
end

function WindfieldWorld:update(dt)
    if self.world and self.world.update then
        self.world:update(dt)
    end
end

function WindfieldWorld:drainContacts()
    local contacts = self.pendingContacts
    self.pendingContacts = {}
    if Debug and Debug.isEnabled and Debug.debug and Debug.isEnabled(self.debugFlag) then
        for _, contact in ipairs(contacts) do
            local a = contact.a and contact.a:getUserData()
            local b = contact.b and contact.b:getUserData()
            Debug.debug(self.debugFlag, "windfield %s contact between %s and %s", contact.kind, tostring(a), tostring(b))
        end
    end
    return contacts
end

function WindfieldWorld:getCollider(entity)
    local key = entity_key(entity)
    local entry = key and self.colliders[key]
    return entry and entry.collider or nil
end

function WindfieldWorld:destroy()
    if self.world and self.world.destroy then
        self.world:destroy()
    end
    self.colliders = {}
    self.seen = {}
    self.pendingContacts = {}
end

return WindfieldWorld
