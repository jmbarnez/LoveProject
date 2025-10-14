local EngineTrail = {}
EngineTrail.__index = EngineTrail

function EngineTrail.new(config)
    local self = setmetatable({}, EngineTrail)
    
    config = config or {}
    
    -- Trail properties
    self.colors = {
        color1 = config.color1 or {0.0, 0.0, 1.0, 1.0},
        color2 = config.color2 or {0.0, 0.0, 0.5, 0.5}
    }
    self.size = config.size or 1.0
    self.offset = config.offset or 15
    self.intensity = 0
    self.isThrusting = false
    
    -- Create particle texture with a simple white circle
    local particleImg = love.graphics.newCanvas(8, 8)
    love.graphics.setCanvas(particleImg)
    love.graphics.clear()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 4, 4, 3)
    love.graphics.setCanvas()
    
    -- Create particle system
    self.particleSystem = love.graphics.newParticleSystem(particleImg, 500)
    self:setupParticleSystem()
    self.particleSystem:start()
    
    return self
end

function EngineTrail:setupParticleSystem()
    local ps = self.particleSystem
    
    -- Particle lifetime and emission
    ps:setParticleLifetime(1.0, 1.5)
    ps:setEmissionRate(0)
    ps:setSizeVariation(0.1)
    ps:setLinearDamping(2, 4)
    ps:setSpread(math.pi * 0.03)
    ps:setSpeed(20, 40)
    ps:setLinearAcceleration(-5, -3, 5, 3)
    
    -- Set colors
    local c1 = self.colors.color1
    local c2 = self.colors.color2
    ps:setColors(c1[1], c1[2], c1[3], c1[4], c2[1], c2[2], c2[3], c2[4])
end

function EngineTrail:updateThrustState(thrusting, intensity)
    self.isThrusting = thrusting
    self.intensity = intensity or 0
    
    if thrusting then
        -- Set emission rate based on intensity
        local emissionRate = 50 * self.intensity * self.size
        self.particleSystem:setEmissionRate(emissionRate)
    else
        self.particleSystem:setEmissionRate(0)
    end
end

function EngineTrail:updatePosition(x, y, angle)
    -- Calculate trail position behind ship
    local trailX = x - math.cos(angle) * self.offset
    local trailY = y - math.sin(angle) * self.offset
    
    -- Set particle system position
    self.particleSystem:setPosition(trailX, trailY)
    
    -- Set particle direction opposite to ship movement
    local particleAngle = angle + math.pi
    self.particleSystem:setDirection(particleAngle)
end

function EngineTrail:update(dt)
    self.particleSystem:update(dt)
end

function EngineTrail:draw()
    if self.isThrusting then
        love.graphics.draw(self.particleSystem)
    end
end

return EngineTrail