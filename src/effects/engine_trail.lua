-- DEPRECATED: This standalone effect class has been replaced by the engine_trail component.
-- Use src/components/engine_trail.lua for new implementations.

local Log = require("src.core.log")
local EngineTrail = {}
EngineTrail.__index = EngineTrail

function EngineTrail.new(x, y, color1, color2, size)
    Log.debug("EngineTrail: Creating new engine trail at", x, y)
    Log.debug("  - Color1:", color1[1], color1[2], color1[3])
    Log.debug("  - Color2:", color2[1], color2[2], color2[3])
    Log.debug("  - Size:", size)
    
    local self = setmetatable({}, EngineTrail)
    self.debugId = string.format("EngineTrail_%f", love.timer.getTime() % 1000)
    Log.debug("  - Created with ID:", self.debugId)
    
    -- Create a small canvas for particles (safely restore previous canvas)
    local particleImg = love.graphics.newCanvas(8, 8)
    local prevCanvas = love.graphics.getCanvas()
    local okCanvas = xpcall(function()
        love.graphics.setCanvas(particleImg)
        love.graphics.clear(1, 1, 1, 1)  -- White square that we'll tint
    end, debug.traceback)
    love.graphics.setCanvas(prevCanvas)
    if not okCanvas then
        Log.warn("EngineTrail(effect): failed to initialize particle texture")
    end
    
    -- Create particle system with more particles for better visibility
    self.ps = love.graphics.newParticleSystem(particleImg, 500)
    
    -- Particle appearance - more subtle settings
    self.ps:setParticleLifetime(2.0, 3.0)
    self.ps:setEmissionRate(100)
    self.ps:setSizeVariation(0.2)
    self.ps:setLinearDamping(1, 2)
    self.ps:setSpread(math.pi * 0.05)
    self.ps:setSpeed(20, 50)
    self.ps:setLinearAcceleration(-10, -5, 10, 5)
    
    -- Set colors with better blending
    self.ps:setColors(
        color1[1], color1[2], color1[3], 0.8,
        color1[1] * 0.8, color1[2] * 0.8, color1[3] * 0.8, 0.5,
        color2[1], color2[2], color2[3], 0.3,
        color2[1] * 0.5, color2[2] * 0.5, color2[3] * 0.5, 0.0
    )
    
    -- Set sizes with more variation
    self.ps:setSizes(
        size * 0.1,
        size * 0.5,
        size * 0.3,
        size * 0.05
    )
    
    -- Position and rotation
    self.x = x or 0
    self.y = y or 0
    self.angle = 0
    self.active = true
    
    -- Configure particle emission
    self.ps:setEmissionRate(0)  -- Start with emission off
    self.ps:start()
    
    -- Debug info
    Log.debug(string.format("%s: Created at (%.1f, %.1f)", self.debugId, self.x, self.y))
    
    return self
end

function EngineTrail:update(dt, x, y, angle, isThrusting, intensity)
    
    -- Update position and angle
    self.x = x or self.x or 0
    self.y = y or self.y or 0
    self.angle = angle or self.angle or 0
    
    isThrusting = isThrusting or false
    
    -- Set a constant emission rate when thrusting
    local emissionRate = isThrusting and 100 or 0
    self.ps:setEmissionRate(emissionRate)
    
    -- Use constant values for particle properties
    local size = 1.0
    local speed = 40
    
    self.ps:setParticleLifetime(2.0, 3.0)
    self.ps:setSpeed(speed * 0.8, speed * 1.2)
    self.ps:setSpread(math.pi * 0.05)
    self.ps:setSizes(
        size * 0.2,
        size * 1.0,
        size * 0.5,
        size * 0.1
    )
    self.ps:setLinearAcceleration(
        -20, -10,
        20, 10
    )
    
    -- Position the emitter slightly behind the ship
    local offset = 15
    local offsetX = -math.cos(self.angle) * offset
    local offsetY = -math.sin(self.angle) * offset
    
    -- Set the emission direction to be opposite the ship's angle
    self.ps:setDirection(self.angle + math.pi)

    -- Update particle system position and step
    self.ps:moveTo(self.x + offsetX, self.y + offsetY)
    self.ps:update(dt)
    
    -- Debug visualization
    if DEBUG then
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.circle("line", self.x + offsetX, self.y + offsetY, 5)
        love.graphics.setColor(1, 1, 1, 1)
    end
    
    -- Debug logging
    if DEBUG then
        Log.debug(string.format("%s: Pos(%.1f, %.1f), Angle: %.2f, Emit: %.1f, Int: %.2f, Thrust: %s", 
            self.debugId, self.x, self.y, self.angle, emissionRate, intensity, tostring(isThrusting)))
    end
end

function EngineTrail:draw()
    
    if not self.active then 
        Log.debug(self.debugId, "Not drawing - not active")
        return 
    end
    
    Log.debug(string.format("%s: Drawing at (%.2f, %.2f), angle: %.2f", 
        self.debugId, self.x, self.y, self.angle))
    
    -- Apply additive blending for better glow effect
    love.graphics.setBlendMode("add", "premultiplied")
    
    -- Draw the particle system directly in world space
    love.graphics.draw(self.ps)
    
    -- Reset blend mode
    love.graphics.setBlendMode("alpha")
end

function EngineTrail:destroy()
    self.active = false
    self.ps:stop()
end

return EngineTrail
