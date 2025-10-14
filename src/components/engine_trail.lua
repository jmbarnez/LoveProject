local Log = require("src.core.log")
local Util = require("src.core.util")

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
    self.offset = config.offset or 15  -- Distance behind the ship to emit particles
    local initialIntensity = Util.clamp01(config.intensity or 0)
    self.intensity = initialIntensity
    self.currentIntensity = initialIntensity
    self.targetIntensity = initialIntensity
    self.isThrusting = false
    self.lastPosition = { x = 0, y = 0, angle = 0 }

    -- Create particle texture (safely restore previous canvas)
    local particleImg = love.graphics.newCanvas(8, 8)
    local prevCanvas = love.graphics.getCanvas()
    local okCanvas = xpcall(function()
        love.graphics.setCanvas(particleImg)
        love.graphics.clear()  -- White square that we'll tint
    end, debug.traceback)
    love.graphics.setCanvas(prevCanvas)
    if not okCanvas then
        Log.warn("EngineTrail: failed to initialize particle texture")
    end

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

    ps:setParticleLifetime(1.0, 1.5)
    ps:setEmissionRate(0)
    ps:setSizeVariation(0.1)
    ps:setLinearDamping(2, 4)
    ps:setSpread(math.pi * 0.03)
    ps:setSpeed(20, 40)
    ps:setLinearAcceleration(-5, -3, 5, 3)

    local c1 = self.colors.color1 or {1, 1, 1, 1}
    local r, g, b, a = c1[1] or 1, c1[2] or 1, c1[3] or 1, c1[4] or 1
    ps:setColors(
        r, g, b, a * 0.6,
        r, g, b, a * 0.4,
        r, g, b, a * 0.2,
        r, g, b, a * 0.1
    )

    ps:setSizes(
        self.size * 0.3,
        self.size * 1.5,
        self.size * 0.8,
        self.size * 0.1
    )
end

function EngineTrail:updateThrustState(isThrusting, intensity)
    local target = 0

    if isThrusting then
        target = Util.clamp01(intensity or 0)
    end

    self.targetIntensity = target

    local blend = isThrusting and 0.25 or 0.12
    self.currentIntensity = self.currentIntensity + (target - self.currentIntensity) * blend

    if not isThrusting and self.currentIntensity < 0.02 then
        self.currentIntensity = 0
    end

    self.intensity = self.currentIntensity
    self.isThrusting = isThrusting or self.currentIntensity > 0

    if self.currentIntensity <= 0 then
        self.particleSystem:setEmissionRate(0)
        return
    end

    local amount = self.currentIntensity

    local emissionRate = 40 + 160 * amount
    self.particleSystem:setEmissionRate(emissionRate)

    local minSpeed, maxSpeed = 20, 120
    local startSpeed = minSpeed + (maxSpeed - minSpeed) * (amount * 0.5)
    local endSpeed = minSpeed + (maxSpeed - minSpeed) * amount
    self.particleSystem:setSpeed(startSpeed, endSpeed)

    local baseSize = self.size
    self.particleSystem:setSizes(
        baseSize * (0.12 + 0.18 * amount),
        baseSize * (0.5 + 0.7 * amount),
        baseSize * (0.25 + 0.35 * amount),
        baseSize * (0.05 + 0.05 * amount)
    )

    local accel = 2 + 8 * amount
    self.particleSystem:setLinearAcceleration(-accel, -accel * 0.66, accel, accel * 0.66)
end

function EngineTrail:updatePosition(x, y, angle)
    self.lastPosition.x = x
    self.lastPosition.y = y
    self.lastPosition.angle = angle

    local emissionAngle = angle + math.pi
    local offsetX = math.cos(emissionAngle) * self.offset
    local offsetY = math.sin(emissionAngle) * self.offset

    self.particleSystem:setDirection(emissionAngle)
    self.particleSystem:moveTo(x + offsetX, y + offsetY)
end

function EngineTrail:update(dt)
    self.particleSystem:update(dt)
end

function EngineTrail:draw()
    love.graphics.setBlendMode("add")
    love.graphics.draw(self.particleSystem)
    love.graphics.setBlendMode("alpha")
end

function EngineTrail:destroy()
    if self.particleSystem then
        self.particleSystem:stop()
    end
end

return EngineTrail
