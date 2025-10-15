--[[
    Windfield Physics Component
    
    Replaces the custom physics component with Windfield integration.
    Handles physics body creation and management for entities.
]]

local WindfieldPhysics = {}
WindfieldPhysics.__index = WindfieldPhysics

function WindfieldPhysics.new(values)
    values = values or {}
    local instance = setmetatable({}, WindfieldPhysics)
    
    -- Store physics properties
    instance.mass = values.mass ~= nil and values.mass or 1000
    instance.restitution = values.restitution ~= nil and values.restitution or 0.25
    instance.friction = values.friction ~= nil and values.friction or 0.2
    instance.fixedRotation = values.fixedRotation or false
    instance.bodyType = values.bodyType or "dynamic"
    
    -- Collider type and dimensions
    instance.colliderType = values.colliderType or "circle"
    instance.radius = values.radius ~= nil and values.radius or 20
    instance.width = values.width ~= nil and values.width or 40
    instance.height = values.height ~= nil and values.height or 40
    instance.vertices = values.vertices or {}
    
    -- Position
    instance.x = values.x or 0
    instance.y = values.y or 0
    
    -- Legacy compatibility
    instance.rotation = 0
    instance.rotSpeed = 0
    
    -- Thruster state (for ships)
    instance.thrusterState = {
        forward = 0,
        reverse = 0,
        strafeLeft = 0,
        strafeRight = 0,
        boost = 0,
        brake = 0,
        isThrusting = false
    }
    
    return instance
end

function WindfieldPhysics:update(dt)
    -- This component doesn't directly update physics
    -- The WindfieldManager handles all physics updates
    -- This is kept for compatibility with existing systems
end

function WindfieldPhysics:applyForce(fx, fy, dt)
    -- This will be handled by the WindfieldManager
    -- Keep for compatibility
end

function WindfieldPhysics:setThruster(thruster, active)
    if self.thrusterState then
        if active then
            if thruster == 'forward' then
                self.thrusterState.forward = 1.0
            elseif thruster == 'backward' then
                self.thrusterState.reverse = 0.7
            elseif thruster == 'left' then
                self.thrusterState.strafeLeft = 0.8
            elseif thruster == 'right' then
                self.thrusterState.strafeRight = 0.8
            elseif thruster == 'boost' then
                self.thrusterState.boost = 1.0
            elseif thruster == 'brake' then
                self.thrusterState.brake = 1.0
            end
            self.thrusterState.isThrusting = true
        else
            if thruster == 'forward' then
                self.thrusterState.forward = 0
            elseif thruster == 'backward' then
                self.thrusterState.reverse = 0
            elseif thruster == 'left' then
                self.thrusterState.strafeLeft = 0
            elseif thruster == 'right' then
                self.thrusterState.strafeRight = 0
            elseif thruster == 'boost' then
                self.thrusterState.boost = 0
            elseif thruster == 'brake' then
                self.thrusterState.brake = 0
            end
            
            -- Check if any thrusters are still active
            local anyActive = false
            for k, v in pairs(self.thrusterState) do
                if k ~= 'isThrusting' and v > 0 then
                    anyActive = true
                    break
                end
            end
            self.thrusterState.isThrusting = anyActive
        end
    end
end

function WindfieldPhysics:getThrusterState()
    return self.thrusterState or {
        forward = 0,
        reverse = 0,
        strafeLeft = 0,
        strafeRight = 0,
        boost = 0,
        brake = 0,
        isThrusting = false
    }
end

function WindfieldPhysics:getOptions()
    local options = {
        mass = self.mass,
        restitution = self.restitution,
        friction = self.friction,
        fixedRotation = self.fixedRotation,
        bodyType = self.bodyType,
        radius = self.radius,
        width = self.width,
        height = self.height,
        vertices = self.vertices,
    }
    
    return options
end

return WindfieldPhysics
