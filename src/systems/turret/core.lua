local Util = require("src.core.util")
local Content = require("src.content.content")
local HeatManager = require("src.systems.turret.heat_manager")
local Targeting = require("src.systems.turret.targeting")
local ProjectileWeapons = require("src.systems.turret.projectile_weapons")
local BeamWeapons = require("src.systems.turret.beam_weapons")
local UtilityBeams = require("src.systems.turret.utility_beams")
local TurretEffects = require("src.systems.turret.effects")

local Events = require("src.core.events")
local Log = require("src.core.log")
local Turret = {}
Turret.__index = Turret

function Turret.new(owner, params)
    local self = setmetatable({}, Turret)

    self.owner = owner
    self.kind = params.type or params.kind or "gun"

    -- Basic turret parameters
    self.damage_range = params.damage_range or {min = 1, max = 2}
    self.cycle = params.cycle or 1.0
    self.capCost = params.capCost or 5

    -- Targeting parameters
    self.optimal = params.optimal or 800
    self.falloff = params.falloff or 400

    -- Firing facing tolerance: enemies must face target within this angle to fire
    -- (radians). Players/friendly turrets are not restricted by this.
    -- Turrets now ignore facing by default so AI can fire in any direction
    -- while maneuvering. Leave a hook for configs that explicitly want a
    -- tolerance by allowing params.fireFacingTolerance to override.
    if params.fireFacingTolerance then
        self.fireFacingTolerance = params.fireFacingTolerance
    else
        self.fireFacingTolerance = nil
    end

    -- Visual and audio parameters
    self.tracer = params.tracer or {}
    self.impact = params.impact or {}
    self.spread = params.spread or {minDeg = 0.1, maxDeg = 0.5, decay = 500}

    -- Weapon-specific parameters
    self.projectileId = params.projectile
    self.projectileSpeed = params.projectileSpeed or (
        (self.kind == 'laser' or self.kind == 'mining_laser' or self.kind == 'salvaging_laser') and 100000 or
        (self.kind == 'missile' and 800) or 2400
    )
    self.maxRange = params.maxRange or (self.kind == 'laser' and 1500 or nil)

    -- Missile-specific parameters
    self.missileTurnRate = params.missileTurnRate or 0

    -- Mining/salvaging parameters
    self.miningPower = params.miningPower or 2.5
    self.miningCyclesPerResource = params.miningCyclesPerResource or 4
    self.salvagePower = params.salvagePower or 3.0
    self.beamDuration = params.beamDuration or 0.08

    -- Secondary projectile support
    self.secondaryProjectile = params.secondaryProjectile
    self.secondaryProjectileSpeed = params.secondaryProjectileSpeed or 600
    self.secondaryFireEvery = params.secondaryFireEvery or 1

    -- Volley firing support
    self.volleyCount = params.volleyCount or 1
    self.volleySpreadDeg = params.volleySpreadDeg or 0

    -- Initialize heat management
    HeatManager.initializeHeat(self, params)

    -- Initialize state variables
    self.lastFireTime = 0
    self.currentTarget = nil
    self.firing = false
    self.cooldown = 0 -- Time remaining until next shot

    -- Firing mode: manual (hold to fire) or automatic (toggle to fire)
    self.fireMode = params.fireMode or "manual"
    self.autoFire = false -- For automatic mode, tracks toggle state

    -- Lock-on system for missiles
    self.lockOnTarget = nil -- Current target being locked onto
    self.lockOnStartTime = 0 -- When lock-on started
    self.lockOnDuration = params.lockOnDuration or 2.0 -- How long to hold aim for lock-on (seconds)
    self.isLockedOn = false -- Whether lock-on has been achieved
    self.lockOnProgress = 0 -- 0-1 progress toward lock acquisition

    -- Set default tracer colors if not specified
    if (self.kind == 'gun' or self.kind == 'projectile' or not self.kind) and not self.tracer.color then
        self.tracer.color = {0.35, 0.70, 1.00, 1.0}
    end
    if self.kind == 'laser' then
        self.tracer.color = self.tracer.color or {0.3, 0.7, 1.0, 0.8}
        self.tracer.width = self.tracer.width or 1.5
        self.tracer.coreRadius = self.tracer.coreRadius or 1
    elseif self.kind == 'mining_laser' then
        self.tracer.color = self.tracer.color or {1.0, 0.7, 0.2, 0.8}
        self.tracer.width = self.tracer.width or 2.0
        self.tracer.coreRadius = self.tracer.coreRadius or 2
    elseif self.kind == 'salvaging_laser' then
        self.tracer.color = self.tracer.color or {0.2, 1.0, 0.3, 0.8}
        self.tracer.width = self.tracer.width or 2.0
        self.tracer.coreRadius = self.tracer.coreRadius or 3
    elseif self.kind == 'missile' then
        self.tracer.color = self.tracer.color or {1.0, 0.5, 0.2, 1.0}
    end

    return self
end

function Turret:update(dt, target, locked, world)
    -- Update heat management
    HeatManager.updateHeat(self, dt, locked)

    -- Update cooldown timer
    if self.cooldown > 0 then
        self.cooldown = math.max(0, self.cooldown - dt)
    end

    -- Update lock-on system for missiles
    if self.kind == "missile" then
        Turret.updateLockOn(self, dt, target, world)
    end

    -- Check if we can fire
    if locked then
        self.firing = false
        self.currentTarget = nil
        self.beamActive = false
        -- Preserve missile lock progress even when not firing so the player can pre-aim
        if self.kind ~= "missile" then
            self:resetLockOn()
        end
        return
    end

    -- Check firing timing (cooldown takes priority over old timing system)
    if self.cooldown > 0 then
        return
    end

    local effectiveCycle = HeatManager.getHeatModifiedCycle(self)

    -- For manual shooting, we fire in the direction the player is facing
    -- or towards a specific target for utility beams (mining/salvaging)
    -- Prevent enemy turrets from firing until the owner is facing the target
    -- Skip facing check for lasers since they aim directly at the target
    if self.fireFacingTolerance and self.kind ~= "laser" and target and self.owner and not (self.owner.isPlayer or self.owner.isFriendly) then
        if target.components and target.components.position and self.owner.components and self.owner.components.position then
            local tx = target.components.position.x
            local ty = target.components.position.y
            local ox = self.owner.components.position.x
            local oy = self.owner.components.position.y
            local desired = math.atan2(ty - oy, tx - ox)
            local current = self.owner.components.position.angle or 0
            local diff = desired - current
            -- Normalize to [-pi,pi]
            local nd = math.atan2(math.sin(diff), math.cos(diff))
            -- More forgiving facing tolerance for enemy ships to allow firing while orbiting
            local tolerance = self.fireFacingTolerance or (self.owner.isPlayer and math.pi / 6 or math.pi / 3)
            if math.abs(nd) > tolerance then
                -- Not facing yet; skip firing this update
                self.firing = false
                return
            end
        end
    end

    -- For manual mode, only fire if we're actively firing (button held)
    -- For automatic mode, fire if autoFire is enabled and cooldown allows
    if self.fireMode == "manual" or (self.fireMode == "automatic" and self.autoFire) then
        -- Route to appropriate weapon handler
        if self.kind == "gun" or self.kind == "projectile" or not self.kind then
            ProjectileWeapons.updateGunTurret(self, dt, target, locked, world)
        elseif self.kind == "missile" then
            ProjectileWeapons.updateMissileTurret(self, dt, target, locked, world)
        elseif self.kind == "laser" then
            BeamWeapons.updateLaserTurret(self, dt, target, locked, world)
        elseif self.kind == "mining_laser" then
            UtilityBeams.updateMiningLaser(self, dt, target, locked, world)
        elseif self.kind == "salvaging_laser" then
            UtilityBeams.updateSalvagingLaser(self, dt, target, locked, world)
        end

        -- Set cooldown for next shot
        self.cooldown = effectiveCycle
        Log.debug("Turret:update - Cooldown set to: " .. tostring(self.cooldown) .. " for turret: " .. tostring(self.id))
    end

    -- Update last fire time (legacy compatibility)
    self.lastFireTime = love.timer and love.timer.getTime() or 0
end

function Turret:cancelFiring()
    self.firing = false
    self.beamActive = false
    -- Don't reset cooldown here; let it finish its cycle
end

-- Legacy compatibility functions
function Turret:updateHeat(dt, locked)
    return HeatManager.updateHeat(self, dt, locked)
end

function Turret:getHeatFactor()
    return HeatManager.getHeatFactor(self)
end

function Turret:getHeatModifiedCycle()
    return HeatManager.getHeatModifiedCycle(self)
end

function Turret:getHeatModifiedEnergyCost()
    return HeatManager.getHeatModifiedEnergyCost(self)
end

function Turret:drawHeatIndicator(x, y, size)
    return HeatManager.drawHeatIndicator(self, x, y, size)
end

function Turret:updateMiningLaser(dt, target, locked, world)
    return UtilityBeams.updateMiningLaser(self, dt, target, locked, world)
end

function Turret:drawMiningBeam()
    if self.miningTarget and self.owner and self.owner.components and self.owner.components.position then
        local sx = self.owner.components.position.x
        local sy = self.owner.components.position.y
        local ex = self.miningTarget.components.position.x
        local ey = self.miningTarget.components.position.y
        UtilityBeams.drawMiningBeam(self, sx, sy, ex, ey)
    end
end

function Turret:drawLaserBeam()
    if self.beamActive and self.beamStartX and self.beamStartY and self.beamEndX and self.beamEndY then
        -- Clear beam data after rendering
        self.beamActive = false
    end
end

function Turret:updateSalvagingLaser(dt, target, locked, world)
    return UtilityBeams.updateSalvagingLaser(self, dt, target, locked, world)
end

-- Check if turret can fire (cooldown and heat)
function Turret:canFire()
    return self.cooldown <= 0 and HeatManager.canFire(self)
end

-- Static function to get turret by slot (legacy compatibility)
function Turret.getTurretBySlot(player, slot)
    if not player or not player.components or not player.components.equipment or not player.components.equipment.grid then
        return nil
    end

    local gridData = player.components.equipment.grid[slot]
    if gridData and gridData.type == "turret" then
        return gridData.module
    end

    return nil
end

-- Reset lock-on state
function Turret:resetLockOn()
    self.lockOnTarget = nil
    self.lockOnStartTime = 0
    self.isLockedOn = false
    self.lockOnProgress = 0
end

-- Update lock-on system
function Turret.updateLockOn(turret, dt, target, world)
    -- If no target provided, reset lock-on
    if not target or not target.components or not target.components.position then
        turret:resetLockOn()
        return
    end

    -- Check if we're still aiming at the same target
    local ownerPos = turret.owner.components.position
    local targetPos = target.components.position

    -- Calculate angle to target
    local dx = targetPos.x - ownerPos.x
    local dy = targetPos.y - ownerPos.y
    local targetAngle = math.atan2(dy, dx)

    -- Check if player cursor is roughly aligned with target (within tolerance)
    local playerAngle = ownerPos.angle or 0
    local angleDiff = math.abs(targetAngle - playerAngle)
    -- Normalize to [0, π]
    if angleDiff > math.pi then
        angleDiff = 2 * math.pi - angleDiff
    end

    local lockOnTolerance = math.pi / 6 -- 30 degrees tolerance

    if angleDiff <= lockOnTolerance then
        -- We're aiming at the target, start/update lock-on
        if not turret.lockOnTarget or turret.lockOnTarget ~= target then
            -- New target, start lock-on timer
            turret.lockOnTarget = target
            turret.lockOnStartTime = love.timer.getTime()
            turret.isLockedOn = false
        else
            -- Same target, check if lock-on duration has been met
            local currentTime = love.timer.getTime()
            if currentTime - turret.lockOnStartTime >= turret.lockOnDuration then
                turret.isLockedOn = true
            end
        end
    else
        -- Not aiming at target, reset lock-on
        turret:resetLockOn()
    end
end

return Turret
