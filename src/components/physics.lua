local CorePhysics = require("src.core.physics")

local Physics = {}
Physics.__index = Physics

function Physics.new(values)
    local instance = setmetatable({}, Physics)
    
    -- Create a newton physics body for actual physics simulation
    instance.body = CorePhysics.createBody(
        values.mass or 1000, 
        values.x or 0, 
        values.y or 0
    )
    
    -- Legacy compatibility properties
    instance.rotation = values.rotation or 0
    instance.rotSpeed = values.rotSpeed or 0
    instance.mass = values.mass or 1000
    
    -- Copy thruster properties if provided
    if values.thrusterPower then
        instance.body.thrusterPower = values.thrusterPower
    end
    
    return instance
end

-- Delegate physics methods to the newton body
function Physics:update(dt)
    if self.body and self.body.update then
        self.body:update(dt)
        -- Sync legacy properties
        self.rotation = self.body.angle
        self.x = self.body.x
        self.y = self.body.y
    end
end

function Physics:applyForce(fx, fy, dt)
    if self.body then
        self.body:applyForce(fx, fy, dt)
    end
end

function Physics:setThruster(thruster, active)
    if self.body then
        self.body:setThruster(thruster, active)
    end
end

-- Get the current thruster state from the physics body
function Physics:getThrusterState()
    if self.body and self.body.thrusterState then
        return self.body.thrusterState
    end
    return {
        forward = 0,
        reverse = 0,
        strafeLeft = 0,
        strafeRight = 0,
        boost = 0,
        brake = 0,
        isThrusting = false
    }
end

return Physics