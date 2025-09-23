local Log = require("src.core.log")

local EngineTrail = {}
EngineTrail.__index = EngineTrail

function EngineTrail.new(config)
    local self = setmetatable({}, EngineTrail)
    
    config = config or {}
    
    -- Component properties
    self.colors = {
        color1 = config.color1 or {0.0, 0.0, 1.0, 1.0},      -- Primary blue
        color2 = config.color2 or {0.0, 0.0, 0.5, 0.5}       -- Secondary blue
    }
    self.size = config.size or 1.0
    self.offset = config.offset or 15  -- Distance behind ship to emit particles
    self.intensity = config.intensity or 1.0
    self.isThrusting = false
    self.lastPosition = { x = 0, y = 0, angle = 0 }
    
    -- Create particle texture
    local particleImg = love.graphics.newCanvas(8, 8)
    love.graphics.setCanvas(particleImg)
    love.graphics.clear(1, 1, 1, 1)  -- White square that we'll tint
    love.graphics.setCanvas()
    
    -- Create particle system
    self.particleSystem = love.graphics.newParticleSystem(particleImg, 500)
    
    -- Configure particle system properties
    self:setupParticleSystem()
    
    self.particleSystem:start()
    
    Log.debug("EngineTrail component created with size:", self.size)
    
    return self
end

function EngineTrail:setupParticleSystem()
    local ps = self.particleSystem
    
    -- Particle behavior - more minimal settings
    ps:setParticleLifetime(1.0, 1.5)  -- Shorter lifetime
    ps:setEmissionRate(0)  -- Start off; controlled by thrust state
    ps:setSizeVariation(0.1)  -- Less size variation
    ps:setLinearDamping(2, 4)  -- More damping for quicker fade
    ps:setSpread(math.pi * 0.03)  -- Tighter spread
    ps:setSpeed(20, 40)  -- Slower, more subtle particles
    ps:setLinearAcceleration(-5, -3, 5, 3)  -- Less acceleration
    
    -- Use provided primary color for particles (supports enemy red) - more subtle
    local c1 = self.colors.color1 or {1, 1, 1, 1}
    local r, g, b, a = c1[1] or 1, c1[2] or 1, c1[3] or 1, c1[4] or 1
    ps:setColors(
        r, g, b, a * 0.6,  -- Much more subtle opacity
        r, g, b, a * 0.4,
        r, g, b, a * 0.2,
        r, g, b, a * 0.1
    )
    
    -- Set size progression - much smaller particles
    ps:setSizes(
        self.size * 0.3,  -- Start smaller
        self.size * 1.5,  -- Peak smaller
        self.size * 0.8,  -- End smaller
        self.size * 0.1   -- Final very small
    )
end

function EngineTrail:updateThrustState(isThrusting, intensity)
    -- Fixed intensity and look regardless of thrust amount; only emission toggles
    self.isThrusting = isThrusting or false
    self.intensity = 1.0

    -- Stable emission rate: on/off only - much lower rate for minimal effect
    local emissionRate = self.isThrusting and 80 or 0  -- Reduced from 200 to 80
    self.particleSystem:setEmissionRate(emissionRate)

    
    -- Fixed particle properties (no dynamic changes) - more minimal
    self.particleSystem:setSpeed(24, 48)  -- Reduced speed
    self.particleSystem:setSizes(
        self.size * 0.2,  -- Smaller particles
        self.size * 0.8,
        self.size * 0.4,
        self.size * 0.05  -- Much smaller end particles
    )
    self.particleSystem:setLinearAcceleration(-3, -2, 3, 2)  -- Reduced acceleration
end

function EngineTrail:updatePosition(x, y, angle)
    self.lastPosition.x = x
    self.lastPosition.y = y  
    self.lastPosition.angle = angle
    
    -- Position the emitter behind the ship
    local offsetX = -math.cos(angle) * self.offset
    local offsetY = -math.sin(angle) * self.offset
    
    -- Set emission direction opposite to ship's angle
    self.particleSystem:setDirection(angle + math.pi)
    self.particleSystem:moveTo(x + offsetX, y + offsetY)
end

function EngineTrail:update(dt)
    self.particleSystem:update(dt)
end

function EngineTrail:draw()
    -- Additive blending for glow under ship sprites
    love.graphics.setBlendMode("add", "alphamultiply")
    love.graphics.draw(self.particleSystem)
    love.graphics.setBlendMode("alpha")
end

function EngineTrail:destroy()
    if self.particleSystem then
        self.particleSystem:stop()
    end
end

return EngineTrail
