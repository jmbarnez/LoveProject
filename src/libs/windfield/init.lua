local wf = {}

-- Lua 5.1 compatibility: unpack is global, not table.unpack
local unpack = unpack or table.unpack

local has_love_physics = type(love) == "table" and love.physics and love.physics.newWorld

local Collider = {}
Collider.__index = Collider

local function safe_call(target, method, ...)
    if target and target[method] then
        return target[method](target, ...)
    end
end

local function new_stub_body(x, y, body_type)
    local body = {
        _type = body_type or "dynamic",
        _x = x or 0,
        _y = y or 0,
        _angle = 0,
        _vx = 0,
        _vy = 0,
        _av = 0,
        _mass = 1,
        _fixedRotation = false,
        _allowSleep = true,
    }

    function body:setType(t) self._type = t end
    function body:getType() return self._type end
    function body:setPosition(x, y) self._x, self._y = x, y end
    function body:getPosition() return self._x, self._y end
    function body:setAngle(a) self._angle = a end
    function body:getAngle() return self._angle end
    function body:setLinearVelocity(vx, vy) self._vx, self._vy = vx or 0, vy or 0 end
    function body:getLinearVelocity() return self._vx, self._vy end
    function body:setAngularVelocity(av) self._av = av or 0 end
    function body:getAngularVelocity() return self._av end
    function body:applyLinearImpulse(ix, iy)
        self._vx = self._vx + (ix or 0)
        self._vy = self._vy + (iy or 0)
    end
    function body:applyForce(fx, fy)
        self._vx = self._vx + (fx or 0)
        self._vy = self._vy + (fy or 0)
    end
    function body:setMass(m) self._mass = m end
    function body:getMass() return self._mass end
    function body:setFixedRotation(flag) self._fixedRotation = flag end
    function body:isFixedRotation() return self._fixedRotation end
    function body:setSleepingAllowed(flag) self._allowSleep = flag end
    function body:isSleepingAllowed() return self._allowSleep end
    function body:isDestroyed() return self._destroyed end
    function body:destroy() self._destroyed = true end
    function body:getWorld() return nil end

    return body
end

local function new_stub_shape(kind, ...)
    local shape = { _kind = kind }
    local args = { ... }
    if kind == "circle" then
        shape._radius = args[1] or 1
        function shape:getRadius() return self._radius end
        function shape:setRadius(r) self._radius = r end
    elseif kind == "rectangle" then
        shape._width = args[1] or 1
        shape._height = args[2] or 1
        function shape:getPoints()
            local w, h = self._width / 2, self._height / 2
            return -w, -h, w, -h, w, h, -w, h
        end
        function shape:getWidth() return self._width end
        function shape:getHeight() return self._height end
    elseif kind == "polygon" then
        shape._points = args
        function shape:getPoints() return unpack(self._points) end
    end
    return shape
end

local function new_stub_fixture(body, shape)
    local fixture = {
        _body = body,
        _shape = shape,
        _sensor = false,
        _restitution = 0,
        _friction = 0.2,
        _category = nil,
        _mask = nil,
    }

    function fixture:getBody() return self._body end
    function fixture:getShape() return self._shape end
    function fixture:setUserData(data) self._userData = data end
    function fixture:getUserData() return self._userData end
    function fixture:setRestitution(val) self._restitution = val end
    function fixture:getRestitution() return self._restitution end
    function fixture:setFriction(val) self._friction = val end
    function fixture:getFriction() return self._friction end
    function fixture:setSensor(flag) self._sensor = flag end
    function fixture:isSensor() return self._sensor end
    function fixture:setCategory(...) self._category = { ... } end
    function fixture:getCategory() return self._category end
    function fixture:setMask(...) self._mask = { ... } end
    function fixture:getMask() return self._mask end
    function fixture:destroy() self._destroyed = true end

    return fixture
end

local function collider_new(world, body, shape, fixture, collider_type)
    local collider = {
        _world = world,
        body = body,
        shape = shape,
        fixture = fixture,
        _type = collider_type,
        _collisionClass = "default",
        _userData = nil,
        _destroyed = false,
    }
    return setmetatable(collider, Collider)
end

function Collider:getBody()
    return self.body
end

function Collider:getType()
    return self._type
end

function Collider:destroy()
    if self._destroyed then return end
    if self.fixture then safe_call(self.fixture, "destroy") end
    if self.body and not (has_love_physics and self.body.isDestroyed and self.body:isDestroyed()) then
        safe_call(self.body, "destroy")
    end
    self._destroyed = true
end

function Collider:isDestroyed()
    return self._destroyed
end

function Collider:setType(body_type)
    safe_call(self.body, "setType", body_type)
end

function Collider:getCollisionClass()
    return self._collisionClass
end

function Collider:setCollisionClass(name)
    self._collisionClass = name
end

function Collider:setUserData(data)
    self._userData = data
    safe_call(self.fixture, "setUserData", data)
end

function Collider:getUserData()
    return self._userData
end

function Collider:setLinearVelocity(vx, vy)
    safe_call(self.body, "setLinearVelocity", vx, vy)
end

function Collider:getLinearVelocity()
    if self.body and self.body.getLinearVelocity then
        return self.body:getLinearVelocity()
    end
    return 0, 0
end

function Collider:applyLinearImpulse(ix, iy)
    safe_call(self.body, "applyLinearImpulse", ix, iy)
end

function Collider:applyForce(fx, fy)
    safe_call(self.body, "applyForce", fx, fy)
end

function Collider:getPosition()
    if self.body and self.body.getPosition then
        return self.body:getPosition()
    end
    return 0, 0
end

function Collider:setPosition(x, y)
    safe_call(self.body, "setPosition", x, y)
end

function Collider:getAngle()
    if self.body and self.body.getAngle then
        return self.body:getAngle()
    end
    return 0
end

function Collider:setAngle(angle)
    safe_call(self.body, "setAngle", angle)
end

function Collider:setAngularVelocity(av)
    safe_call(self.body, "setAngularVelocity", av)
end

function Collider:getAngularVelocity()
    if self.body and self.body.getAngularVelocity then
        return self.body:getAngularVelocity()
    end
    return 0
end

function Collider:setFixedRotation(flag)
    safe_call(self.body, "setFixedRotation", flag)
end

function Collider:setSleepingAllowed(flag)
    safe_call(self.body, "setSleepingAllowed", flag)
end

function Collider:setRestitution(value)
    safe_call(self.fixture, "setRestitution", value)
end

function Collider:setFriction(value)
    safe_call(self.fixture, "setFriction", value)
end

function Collider:setSensor(flag)
    safe_call(self.fixture, "setSensor", flag)
end

function Collider:setCategory(...)
    safe_call(self.fixture, "setCategory", ...)
end

function Collider:setMask(...)
    safe_call(self.fixture, "setMask", ...)
end

function Collider:getRadius()
    if self._type == "circle" then
        if self.shape and self.shape.getRadius then
            return self.shape:getRadius()
        end
        return self._radius or 0
    end
    return nil
end

function Collider:setRadius(radius)
    if self._type ~= "circle" then return end
    if self.shape and self.shape.setRadius then
        self.shape:setRadius(radius)
    end
    self._radius = radius
end

function Collider:getDimensions()
    if self._type == "rectangle" then
        if self.shape and self.shape.getWidth then
            return self.shape:getWidth(), self.shape:getHeight()
        end
        return self._width or 0, self._height or 0
    end
    return nil, nil
end

function Collider:setDimensions(width, height)
    if self._type ~= "rectangle" then return end
    self._width = width
    self._height = height
    if not has_love_physics and self.shape then
        self.shape = new_stub_shape("rectangle", width, height)
    end
end

local World = {}
World.__index = World

local function setup_callbacks(world)
    if not has_love_physics then return end
    world._fixtureToCollider = world._fixtureToCollider or {}

    local function translate_fixture(fixture)
        return world._fixtureToCollider and world._fixtureToCollider[fixture]
    end

    local function callback_adapter(event)
        return function(fixtureA, fixtureB, contact)
            local colliderA = translate_fixture(fixtureA)
            local colliderB = translate_fixture(fixtureB)
            if colliderA and colliderB then
                world:_emit(event, colliderA, colliderB, contact)
            end
        end
    end

    world._love_world:setCallbacks(
        callback_adapter("beginContact"),
        callback_adapter("endContact"),
        callback_adapter("preSolve"),
        callback_adapter("postSolve")
    )
end

local function world_new(gravityX, gravityY, allowSleep)
    local love_world
    if has_love_physics then
        love_world = love.physics.newWorld(gravityX or 0, gravityY or 0, allowSleep == nil and true or allowSleep)
    end

    local self = setmetatable({
        _love_world = love_world,
        _colliders = {},
        _collisionClasses = {},
        _callbacks = {
            beginContact = {},
            endContact = {},
            preSolve = {},
            postSolve = {},
        },
        _fixtureToCollider = {},
    }, World)

    setup_callbacks(self)
    return self
end

function World:_trackCollider(collider, fixture)
    table.insert(self._colliders, collider)
    if fixture then
        self._fixtureToCollider[fixture] = collider
    end
end

function World:_emit(event, colliderA, colliderB, contact)
    local listeners = self._callbacks[event]
    if not listeners then return end
    for _, cb in ipairs(listeners) do
        local ok, err = pcall(cb, colliderA, colliderB, contact)
        if not ok then
            print("[windfield] callback error: " .. tostring(err))
        end
    end
end

function World:on(event, callback)
    if self._callbacks[event] then
        table.insert(self._callbacks[event], callback)
    end
end

function World:addCollisionClass(name, opts)
    self._collisionClasses[name] = opts or {}
end

local function create_fixture(world, body, shape, density)
    if has_love_physics then
        return love.physics.newFixture(body, shape, density or 1)
    end
    return new_stub_fixture(body, shape)
end

function World:newCircleCollider(x, y, radius, body_type)
    local body
    if has_love_physics then
        body = love.physics.newBody(self._love_world, x or 0, y or 0, body_type or "dynamic")
    else
        body = new_stub_body(x, y, body_type)
    end

    local shape
    if has_love_physics then
        shape = love.physics.newCircleShape(radius)
    else
        shape = new_stub_shape("circle", radius)
    end

    local fixture = create_fixture(self, body, shape, 1)
    local collider = collider_new(self, body, shape, fixture, "circle")
    collider:setRadius(radius)
    self:_trackCollider(collider, fixture)
    return collider
end

function World:newRectangleCollider(x, y, width, height, body_type)
    local body
    if has_love_physics then
        body = love.physics.newBody(self._love_world, x or 0, y or 0, body_type or "dynamic")
    else
        body = new_stub_body(x, y, body_type)
    end

    local shape
    if has_love_physics then
        shape = love.physics.newRectangleShape(width, height)
    else
        shape = new_stub_shape("rectangle", width, height)
    end

    local fixture = create_fixture(self, body, shape, 1)
    local collider = collider_new(self, body, shape, fixture, "rectangle")
    collider:setDimensions(width, height)
    self:_trackCollider(collider, fixture)
    return collider
end

function World:newPolygonCollider(vertices, body_type)
    local body
    if has_love_physics then
        body = love.physics.newBody(self._love_world, 0, 0, body_type or "static")
    else
        body = new_stub_body(0, 0, body_type)
    end

    local shape
    if has_love_physics then
        shape = love.physics.newPolygonShape(unpack(vertices))
    else
        shape = new_stub_shape("polygon", unpack(vertices))
    end

    local fixture = create_fixture(self, body, shape, 1)
    local collider = collider_new(self, body, shape, fixture, "polygon")
    collider._vertices = { unpack(vertices) }
    self:_trackCollider(collider, fixture)
    return collider
end

function World:queryCircleArea(x, y, radius, classes)
    local results = {}
    for _, collider in ipairs(self._colliders) do
        if not collider:isDestroyed() then
            local cx, cy = collider:getPosition()
            local cr = collider:getRadius() or 0
            local dx, dy = cx - x, cy - y
            local distance = math.sqrt(dx * dx + dy * dy)
            local passesClass = true
            if classes then
                passesClass = false
                if type(classes) == "string" then
                    classes = { classes }
                end
                local colliderClass = collider:getCollisionClass()
                for _, className in ipairs(classes) do
                    if className == colliderClass then
                        passesClass = true
                        break
                    end
                end
            end
            if passesClass and distance <= (radius + cr) then
                table.insert(results, collider)
            end
        end
    end
    return results
end

function World:queryRectangleArea(x, y, width, height, classes)
    local results = {}
    local left = x - width / 2
    local top = y - height / 2
    for _, collider in ipairs(self._colliders) do
        if not collider:isDestroyed() then
            local cx, cy = collider:getPosition()
            local passesClass = true
            if classes then
                passesClass = false
                if type(classes) == "string" then
                    classes = { classes }
                end
                local colliderClass = collider:getCollisionClass()
                for _, className in ipairs(classes) do
                    if className == colliderClass then
                        passesClass = true
                        break
                    end
                end
            end
            if passesClass and cx >= left and cx <= left + width and cy >= top and cy <= top + height then
                table.insert(results, collider)
            end
        end
    end
    return results
end

function World:remove(collider)
    if not collider then return end
    collider:destroy()
end

function World:clear()
    for _, collider in ipairs(self._colliders) do
        collider:destroy()
    end
    self._colliders = {}
    self._fixtureToCollider = {}
end

function World:update(dt)
    if has_love_physics and self._love_world then
        self._love_world:update(dt)
    end
end

function World:draw(drawCollider)
    for _, collider in ipairs(self._colliders) do
        if not collider:isDestroyed() then
            if drawCollider then
                drawCollider(collider)
            elseif love and love.graphics then
                local cx, cy = collider:getPosition()
                if collider:getType() == "circle" then
                    love.graphics.circle("line", cx, cy, collider:getRadius() or 0)
                elseif collider:getType() == "rectangle" then
                    local w, h = collider:getDimensions()
                    love.graphics.rectangle("line", cx - w / 2, cy - h / 2, w, h)
                end
            end
        end
    end
end

function World:getCollisionClasses()
    return self._collisionClasses
end

function World:getColliders()
    return self._colliders
end

function World:getLoveWorld()
    return self._love_world
end

function World:destroy()
    self:clear()
    if has_love_physics and self._love_world then
        self._love_world:destroy()
        self._love_world = nil
    end
end

function wf.newWorld(gravityX, gravityY, allowSleep)
    return world_new(gravityX, gravityY, allowSleep)
end

return wf
