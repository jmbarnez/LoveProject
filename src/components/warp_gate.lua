-- Warp Gate Component: Handles warp gate functionality and interaction
local ModelUtil = require("src.core.model_util")
local WarpGate = {}
WarpGate.__index = WarpGate

function WarpGate.new(config)
    local self = setmetatable({}, WarpGate)

    -- Basic warp gate properties
    self.name = config.name or "Warp Gate"
    if config.visuals then
        -- Set interaction range to be the visual radius of the gate
        self.interactionRange = ModelUtil.calculateModelWidth(config.visuals) / 2
    else
        self.interactionRange = config.interactionRange or 1500
    end
    self.isActive = config.isActive ~= false -- Default to true
    self.activationCost = config.activationCost or 0

    -- Visual properties
    self.glowIntensity = 0.5
    self.glowDirection = 1
    self.rotationSpeed = config.rotationSpeed or 0.5
    self.rotation = 0

    -- Particle system for visual effects
    self.particles = {
        enabled = true,
        count = 0,
        maxCount = 50,
        pool = {}
    }

    -- Sound effects (if available)
    self.sounds = {
        ambient = config.ambientSound or "warp_gate_ambient",
        activate = config.activateSound or "warp_gate_activate"
    }

    -- Power requirements
    self.requiresPower = config.requiresPower or false
    self.powerLevel = config.powerLevel or 100
    self.maxPowerLevel = config.maxPowerLevel or 100

    return self
end

-- Update the warp gate (animations, particles, etc.)
function WarpGate:update(dt)
    -- Update glow animation
    self.glowIntensity = self.glowIntensity + (self.glowDirection * dt * 0.8)
    if self.glowIntensity > 1.0 then
        self.glowIntensity = 1.0
        self.glowDirection = -1
    elseif self.glowIntensity < 0.3 then
        self.glowIntensity = 0.3
        self.glowDirection = 1
    end

    -- Update rotation
    self.rotation = self.rotation + (self.rotationSpeed * dt)
    if self.rotation > math.pi * 2 then
        self.rotation = self.rotation - (math.pi * 2)
    end

    -- Update particles
    self:updateParticles(dt)
end

-- Update particle system
function WarpGate:updateParticles(dt)
    if not self.particles.enabled or not self.isActive then return end

    -- Update existing particles
    for i = #self.particles.pool, 1, -1 do
        local particle = self.particles.pool[i]
        particle.life = particle.life - dt
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.alpha = particle.alpha - dt * 0.5

        if particle.life <= 0 or particle.alpha <= 0 then
            table.remove(self.particles.pool, i)
            self.particles.count = self.particles.count - 1
        end
    end

    -- Spawn new particles
    if self.particles.count < self.particles.maxCount then
        local particle = {
            x = (math.random() - 0.5) * 30,
            y = (math.random() - 0.5) * 30,
            vx = (math.random() - 0.5) * 20,
            vy = (math.random() - 0.5) * 20,
            life = math.random() * 2 + 1,
            alpha = 1.0,
            size = math.random() * 3 + 1
        }
        table.insert(self.particles.pool, particle)
        self.particles.count = self.particles.count + 1
    end
end

-- Check if player is within interaction range
function WarpGate:canInteract(player, gatePosition)
    if not self.isActive or not player or not gatePosition then
        return false
    end

    local playerPos = player.components and player.components.position
    if not playerPos then return false end

    local dx = gatePosition.x - playerPos.x
    local dy = gatePosition.y - playerPos.y
    local distance = math.sqrt(dx * dx + dy * dy)

    return distance <= self.interactionRange
end

-- Activate the warp gate (open warp interface)
function WarpGate:activate(player, gatePosition)
    -- Note: This method is kept for compatibility but activation is now handled directly in input
    -- The warp UI is opened directly when Space is pressed near a gate
    return true, "Warp interface opened"
end

-- Get interaction hint text
function WarpGate:getInteractionHint()
    if not self.isActive then
        return "Warp Gate (Inactive)", {1, 0.5, 0.5}
    end

    if self.requiresPower and self.powerLevel < 10 then
        return "Warp Gate (No Power)", {1, 0.5, 0.5}
    end

    -- Show the configured interaction key (defaults to space via Settings keymap.dock)
    local interactKey = "space"
    local ok, Settings = pcall(require, "src.core.settings")
    if ok and Settings and Settings.getKeymap then
        local km = Settings.getKeymap()
        if km and km.dock then interactKey = km.dock end
    end

    if self.activationCost > 0 then
        return string.format("Press %s to use Warp Gate (%d GC)", string.upper(interactKey), self.activationCost), {0.5, 1, 0.8}
    else
        return string.format("Press %s to use Warp Gate", string.upper(interactKey)), {0.5, 1, 0.8}
    end
end

-- Recharge power (if applicable)
function WarpGate:rechargePower(dt, rate)
    if not self.requiresPower then return end

    rate = rate or 5 -- Default recharge rate
    self.powerLevel = math.min(self.maxPowerLevel, self.powerLevel + rate * dt)
end

-- Set active state
function WarpGate:setActive(active)
    self.isActive = active
end

-- Get visual properties for rendering
function WarpGate:getVisualProperties()
    return {
        glowIntensity = self.glowIntensity,
        rotation = self.rotation,
        particles = self.particles.pool,
        isActive = self.isActive,
        powerLevel = self.powerLevel,
        maxPowerLevel = self.maxPowerLevel
    }
end

return WarpGate
