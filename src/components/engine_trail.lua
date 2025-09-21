local Log = require("src.core.log")

local EngineTrail = {}
EngineTrail.__index = EngineTrail

function EngineTrail.new(config)
    local self = setmetatable({}, EngineTrail)
    
    config = config or {}
    
    -- Component properties
    self.colors = {
        color1 = config.color1 or {0.0, 1.0, 1.0, 1.0},      -- Primary cyan
        color2 = config.color2 or {0.2, 0.8, 1.0, 0.5}       -- Secondary cyan  
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
    
    -- Particle behavior
    ps:setParticleLifetime(1.4, 2.0)
    ps:setEmissionRate(0)  -- Start with emission off
    ps:setSizeVariation(0.2)
    ps:setLinearDamping(1, 2)
    ps:setSpread(math.pi * 0.05)
    ps:setSpeed(30, 70)
    ps:setLinearAcceleration(-10, -5, 10, 5)
    
    -- Fixed cyan color with constant alpha (no fade variation)
    local c1 = self.colors.color1
    local r, g, b = c1[1], c1[2], c1[3]
    ps:setColors(
        r, g, b, 0.8,
        r, g, b, 0.8,
        r, g, b, 0.8,
        r, g, b, 0.8
    )
    
    -- Set size progression
    ps:setSizes(
        self.size * 0.1,
        self.size * 0.5,
        self.size * 0.3,
        self.size * 0.05
    )
end

function EngineTrail:updateThrustState(isThrusting, intensity)
    -- Fixed intensity and look regardless of thrust amount; only emission toggles
    self.isThrusting = isThrusting or false
    self.intensity = 1.0
    
    -- Stable emission rate: on/off only
    local emissionRate = self.isThrusting and 140 or 0
    self.particleSystem:setEmissionRate(emissionRate)
    
    -- Fixed particle properties (no dynamic changes)
    self.particleSystem:setSpeed(48, 84)
    self.particleSystem:setSizes(
        self.size * 0.2,
        self.size * 1.0,
        self.size * 0.5,
        self.size * 0.1
    )
    self.particleSystem:setLinearAcceleration(-10, -5, 10, 5)
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
    -- Apply additive blending for glow effect
    love.graphics.setBlendMode("add", "premultiplied")
    
    -- Draw particle system in world space
    love.graphics.draw(self.particleSystem)
    
    -- Reset blend mode
    love.graphics.setBlendMode("alpha")
end

function EngineTrail:destroy()
    if self.particleSystem then
        self.particleSystem:stop()
    end
end

return EngineTrail
