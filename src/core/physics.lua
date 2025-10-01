local Physics = {}

-- Realistic space physics constants - True Newtonian mechanics
Physics.constants = {
    -- Balanced space drag (solar wind, cosmic dust, etc.)
    -- Applied to ALL moving objects for consistency
    -- 0.9999 = 0.01% per frame = 0.6% per second = balanced gameplay drag
    SPACE_DRAG_COEFFICIENT = 0.9999,
    -- Ship mass affects acceleration (in tons)
    defaultMass = 500,
    -- Thruster efficiency
    thrusterEfficiency = 0.8,
    -- Light angular damping for stability (minimal space friction on rotation)
    angularDamping = 0.999,
    -- Minimum velocity threshold (only stop truly microscopic values to prevent floating point errors)
    minVelocity = 0.001,
    -- Maximum velocity cap
    maxVelocity = 5000,
    -- Braking thruster power (percentage of main thrust)
    brakingPower = 1.2
}

-- Geometry utility functions
function Physics.closestPointOnSeg(px, py, x1, y1, x2, y2)
  local vx, vy = x2 - x1, y2 - y1
  local wx, wy = px - x1, py - y1
  local c1 = vx * wx + vy * wy
  if c1 <= 0 then return x1, y1, 0 end
  local c2 = vx * vx + vy * vy
  if c2 <= c1 then return x2, y2, 1 end
  local t = c1 / c2
  return x1 + t * vx, y1 + t * vy, t
end

function Physics.segCircleHit(x1, y1, x2, y2, cx, cy, r)
  local qx, qy, t = Physics.closestPointOnSeg(cx, cy, x1, y1, x2, y2)
  local dx, dy = qx - cx, qy - cy
  if dx * dx + dy * dy <= r * r then return true, qx, qy, t end
  return false
end

-- Physics body structure
local PhysicsBody = {}
PhysicsBody.__index = PhysicsBody

function PhysicsBody.new(mass, x, y)
    local self = setmetatable({}, PhysicsBody)

    -- Position
    self.x = x or 0
    self.y = y or 0

    -- Linear motion
    self.vx = 0  -- velocity x
    self.vy = 0  -- velocity y
    self.ax = 0  -- acceleration x
    self.ay = 0  -- acceleration y

    -- Angular motion
    self.angle = 0     -- current rotation
    self.angularVel = 0 -- rotational velocity
    self.torque = 0    -- rotational acceleration

    -- Properties
    self.mass = mass or Physics.constants.defaultMass
    self.radius = 20   -- collision radius
    self.dragCoefficient = Physics.constants.SPACE_DRAG_COEFFICIENT

    -- Forces (reset each frame)
    self.forces = {}

    -- Thruster state
    self.thrusters = {
        forward = false,
        backward = false,
        left = false,
        right = false,
        rotateLeft = false,
        rotateRight = false,
        brake = false
    }

    -- Thruster power (can be upgraded) - Enhanced for Space Quadcopter movement
    self.thrusterPower = {
        main = 600000,     -- omnidirectional thrust (balanced for all directions)
        lateral = 600000,  -- equal power for all directions in quadcopter style
        rotational = 300000 -- high torque for quick aiming
    }

    -- Optional boost multiplier controlled by gameplay code
    self.boostFactor = 1.0

    -- Skip thruster force application (for direct control modes like player)
    self.skipThrusterForce = false

    return self
end

-- Apply a force to the body
function PhysicsBody:applyForce(fx, fy, dt)
    if not dt then dt = 1/60 end -- assume 60 FPS if no dt provided

    -- F = ma, so a = F/m
    local ax = fx / self.mass
    local ay = fy / self.mass

    -- Accumulate acceleration
    self.ax = self.ax + ax
    self.ay = self.ay + ay
end

-- Apply torque (rotational force)
function PhysicsBody:applyTorque(torque, dt)
    if not dt then dt = 1/60 end

    -- Angular acceleration = torque / moment of inertia
    -- Simplified: moment of inertia = mass * radius^2
    local momentOfInertia = self.mass * self.radius * self.radius
    local angularAccel = torque / momentOfInertia

    self.torque = self.torque + angularAccel
end

-- Apply thruster forces based on thruster state
function PhysicsBody:updateThrusters(dt)
    local boost = self.boostFactor or 1.0
    local thrust = self.thrusterPower.main * Physics.constants.thrusterEfficiency * boost
    local lateralThrust = self.thrusterPower.lateral * Physics.constants.thrusterEfficiency * boost

    -- Initialize thruster state for visual effects
    self.thrusterState = self.thrusterState or {
        forward = 0,
        reverse = 0,
        strafeLeft = 0,
        strafeRight = 0,
        boost = 0,
        brake = 0,
        isThrusting = false
    }
    
    -- Reset thruster state
    for k, _ in pairs(self.thrusterState) do
        if k ~= 'isThrusting' then
            self.thrusterState[k] = 0
        end
    end
    self.thrusterState.isThrusting = false

    -- Main thrusters (forward/backward)
    if self.thrusters.forward then
        if not self.skipThrusterForce then
            local fx = math.cos(self.angle) * thrust
            local fy = math.sin(self.angle) * thrust
            self:applyForce(fx, fy, dt)
        end
        self.thrusterState.forward = 1.0
        self.thrusterState.isThrusting = true
    end

    if self.thrusters.backward then
        if not self.skipThrusterForce then
            local fx = -math.cos(self.angle) * thrust * 0.5 -- reverse thrust is weaker
            local fy = -math.sin(self.angle) * thrust * 0.5
            self:applyForce(fx, fy, dt)
        end
        self.thrusterState.reverse = 0.7
        self.thrusterState.isThrusting = true
    end

    -- Lateral thrusters (strafing)
    if self.thrusters.left then
        if not self.skipThrusterForce then
            local fx = -math.sin(self.angle) * lateralThrust
            local fy = math.cos(self.angle) * lateralThrust
            self:applyForce(fx, fy, dt)
        end
        self.thrusterState.strafeLeft = 0.8
        self.thrusterState.isThrusting = true
    end

    if self.thrusters.right then
        if not self.skipThrusterForce then
            local fx = math.sin(self.angle) * lateralThrust
            local fy = -math.cos(self.angle) * lateralThrust
            self:applyForce(fx, fy, dt)
        end
        self.thrusterState.strafeRight = 0.8
        self.thrusterState.isThrusting = true
    end

    -- Handle boost
    if boost > 1.0 then
        self.thrusterState.boost = boost - 1.0
        self.thrusterState.isThrusting = true
    end
    
    -- Braking thrusters (omnidirectional RCS to oppose current motion)
    if self.thrusters.brake then
        local currentSpeed = math.sqrt(self.vx * self.vx + self.vy * self.vy)
        if currentSpeed > 0.1 then -- Only brake if moving
            if not self.skipThrusterForce then
                local brakingThrust = thrust * Physics.constants.brakingPower
                -- Apply force opposite to current velocity vector
                local brakeForceX = -(self.vx / currentSpeed) * brakingThrust
                local brakeForceY = -(self.vy / currentSpeed) * brakingThrust
                self:applyForce(brakeForceX, brakeForceY, dt)
            end
            self.thrusterState.brake = 1.0
            self.thrusterState.isThrusting = true
        end
    end
end

-- Update physics simulation
function PhysicsBody:update(dt)
    -- Apply thruster forces
    self:updateThrusters(dt)

    -- Update linear motion
    -- v = v + a * dt (Newton's Second Law: acceleration changes velocity)
    self.vx = self.vx + self.ax * dt
    self.vy = self.vy + self.ay * dt
    
    -- Apply minimal space drag (solar wind, cosmic dust, etc.)
    -- Objects will very slowly decelerate over time
    if self.dragCoefficient and self.dragCoefficient < 1.0 then
        self.vx = self.vx * self.dragCoefficient
        self.vy = self.vy * self.dragCoefficient
    end

    -- Update position
    -- x = x + v * dt
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    -- Update angular motion
    self.angularVel = self.angularVel + self.torque * dt
    self.angle = self.angle + self.angularVel * dt

    -- Normalize angle to prevent accumulation issues
    self.angle = self.angle % (2 * math.pi)
    if self.angle > math.pi then
        self.angle = self.angle - 2 * math.pi
    elseif self.angle < -math.pi then
        self.angle = self.angle + 2 * math.pi
    end

    -- Apply angular damping (space has some rotational friction)
    self.angularVel = self.angularVel * Physics.constants.angularDamping

    -- Cap maximum velocity
    local speed = math.sqrt(self.vx * self.vx + self.vy * self.vy)
    -- Use ship-specific max speed if available, otherwise use global constant
    local maxSpeed = self.maxSpeed or Physics.constants.maxVelocity
    if speed > maxSpeed then
        local ratio = maxSpeed / speed
        self.vx = self.vx * ratio
        self.vy = self.vy * ratio
    end

    -- Stop very slow movement (prevents tiny drift)
    if speed < Physics.constants.minVelocity then
        self.vx = 0
        self.vy = 0
    end

    -- Reset accelerations for next frame
    self.ax = 0
    self.ay = 0
    self.torque = 0
end

-- Get current velocity
function PhysicsBody:getVelocity()
    return self.vx, self.vy
end

-- Get current speed
function PhysicsBody:getSpeed()
    return math.sqrt(self.vx * self.vx + self.vy * self.vy)
end

-- Set velocity directly (for initial conditions or special effects)
function PhysicsBody:setVelocity(vx, vy)
    self.vx = vx
    self.vy = vy
end

-- Explicitly set position (for compatibility with systems that reposition bodies directly)
function PhysicsBody:setPosition(x, y)
    if x ~= nil then
        self.x = x
    end
    if y ~= nil then
        self.y = y
    end
end

-- Apply impulse (instant change in momentum)
function PhysicsBody:applyImpulse(ix, iy)
    self.vx = self.vx + ix / self.mass
    self.vy = self.vy + iy / self.mass
end

-- Collision with another physics body
function PhysicsBody:collideWith(other, restitution)
    restitution = restitution or 0.8 -- bounciness (0 = inelastic, 1 = elastic)

    -- Calculate collision normal
    local dx = other.x - self.x
    local dy = other.y - self.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance == 0 then return end -- avoid division by zero

    local nx = dx / distance
    local ny = dy / distance

    -- Relative velocity
    local rvx = other.vx - self.vx
    local rvy = other.vy - self.vy

    -- Relative velocity along collision normal
    local velAlongNormal = rvx * nx + rvy * ny

    -- Don't resolve if velocities are separating
    if velAlongNormal > 0 then return end

    -- Calculate restitution
    local impulse = -(1 + restitution) * velAlongNormal
    impulse = impulse / (1 / self.mass + 1 / other.mass)

    -- Apply impulse
    local impulseX = impulse * nx
    local impulseY = impulse * ny

    self.vx = self.vx - impulseX / self.mass
    self.vy = self.vy - impulseY / self.mass

    other.vx = other.vx + impulseX / other.mass
    other.vy = other.vy + impulseY / other.mass

    -- Separate objects to prevent sticking
    local overlap = self.radius + other.radius - distance
    if overlap > 0 then
        local separationX = nx * overlap * 0.5
        local separationY = ny * overlap * 0.5

        self.x = self.x - separationX
        self.y = self.y - separationY

        other.x = other.x + separationX
        other.y = other.y + separationY
    end
end

-- Reset thruster states
function PhysicsBody:resetThrusters()
    for key, _ in pairs(self.thrusters) do
        self.thrusters[key] = false
    end
    
    -- Also reset the thruster state
    if self.thrusterState then
        for k, _ in pairs(self.thrusterState) do
            if k ~= 'isThrusting' then
                self.thrusterState[k] = 0
            end
        end
        self.thrusterState.isThrusting = false
    end
end

-- Set thruster state
function PhysicsBody:setThruster(thruster, active)
    if self.thrusters[thruster] ~= nil then
        self.thrusters[thruster] = active

        -- Map generic thruster names to specific ones used in thrusterState
        local thrusterMap = {
            forward = 'forward',
            backward = 'reverse',
            left = 'strafeLeft',
            right = 'strafeRight',
            boost = 'boost',
            brake = 'brake'
        }

        -- Update the thruster state if this is a known thruster
        local stateKey = thrusterMap[thruster]
        if stateKey then
            -- Initialize thrusterState if it doesn't exist
            self.thrusterState = self.thrusterState or {
                forward = 0,
                reverse = 0,
                strafeLeft = 0,
                strafeRight = 0,
                boost = 0,
                brake = 0,
                isThrusting = false
            }

            -- Update the specific thruster state
            if active then
                -- Set default values based on thruster type
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
                -- Only reset if not already set by another thruster
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
end

-- Check if the body is destroyed (compatibility with Love2D physics)
-- Custom physics bodies are never destroyed, so always return false
function PhysicsBody:isDestroyed()
    return false
end

-- Factory function
function Physics.createBody(mass, x, y)
    return PhysicsBody.new(mass, x, y)
end

return Physics
