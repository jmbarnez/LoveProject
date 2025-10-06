local Util = require("src.core.util")
local Content = require("src.content.content")
local ProjectileWeapons = require("src.systems.turret.projectile_weapons")
local BeamWeapons = require("src.systems.turret.beam_weapons")
local UtilityBeams = require("src.systems.turret.utility_beams")
local TurretEffects = require("src.systems.turret.effects")

local Events = require("src.core.events")
local Log = require("src.core.log")
local Notifications = require("src.ui.notifications")
local Turret = {}
Turret.__index = Turret

function Turret.new(owner, params)
    local self = setmetatable({}, Turret)

    self.owner = owner
    self.kind = params.type

    -- Skill progression tag used when this turret deals the killing blow
    self.skillId = params.skillId
    if not self.skillId then
        if self.kind == 'gun' or self.kind == 'projectile' or self.kind == 'laser' or self.kind == 'missile' then
            self.skillId = "gunnery"
        end
    end

    -- Basic turret parameters
    self.damage_range = params.damage_range
    self.damagePerSecond = params.damagePerSecond
    self.cycle = params.cycle
    self.capCost = params.capCost
    self.energyPerSecond = params.energyPerSecond
    self.minResumeEnergy = params.minResumeEnergy
    self.resumeEnergyMultiplier = params.resumeEnergyMultiplier

    -- Targeting parameters
    self.optimal = params.optimal
    self.falloff = params.falloff

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
    self.tracer = params.tracer
    self.impact = params.impact
    self.spread = params.spread

    -- Weapon-specific parameters
    -- Handle both embedded projectile definitions and projectile ID strings
    if params.projectile and type(params.projectile) == "table" then
        -- Embedded projectile definition
        self.projectile = params.projectile
        self.projectileId = params.projectile.id
    else
        -- Legacy projectile ID string
        self.projectileId = params.projectile
    end
    self.projectileSpeed = params.projectileSpeed
    self.maxRange = params.maxRange

    -- Missile-specific parameters
    self.missileTurnRate = params.missileTurnRate

    -- Mining/salvaging parameters
    self.miningPower = params.miningPower
    self.miningCyclesPerResource = params.miningCyclesPerResource
    self.salvagePower = params.salvagePower
    self.beamDuration = params.beamDuration

    -- Secondary projectile support
    self.secondaryProjectile = params.secondaryProjectile
    self.secondaryProjectileSpeed = params.secondaryProjectileSpeed
    self.secondaryFireEvery = params.secondaryFireEvery

    -- Volley firing support
    self.volleyCount = params.volleyCount
    self.volleySpreadDeg = params.volleySpreadDeg


    -- Initialize state variables
    self.lastFireTime = 0
    self.currentTarget = nil
    self.firing = false
    self.cooldown = 0 -- Time remaining until next shot

    -- Firing mode: manual (hold to fire) or automatic (toggle to fire)
    self.fireMode = params.fireMode
    self.autoFire = false -- For automatic mode, tracks toggle state
    
    -- Initialize clip system
    self.clipSize = params.clipSize or 30
    self.currentClip = self.clipSize -- Start with full clip
    self.reloadTime = params.reloadTime or 3.0
    self.reloadTimer = 0 -- Time remaining for reload
    self.isReloading = false


    -- Track the turret's current aiming direction in world space so visuals,
    -- beams, and projectiles share the same muzzle origin.
    self.currentAimAngle = nil

    -- Set default tracer colors if not specified
    if (self.kind == 'gun' or self.kind == 'projectile' or not self.kind) and not self.tracer.color then
        self.tracer.color = {0.35, 0.70, 1.00, 1.0}
    end
    if self.kind == 'laser' then
        self.tracer.color = self.tracer.color
        self.tracer.width = self.tracer.width
        self.tracer.coreRadius = self.tracer.coreRadius
    elseif self.kind == 'mining_laser' then
        self.tracer.color = self.tracer.color
        self.tracer.width = self.tracer.width
        self.tracer.coreRadius = self.tracer.coreRadius
    elseif self.kind == 'salvaging_laser' then
        self.tracer.color = self.tracer.color
        self.tracer.width = self.tracer.width
        self.tracer.coreRadius = self.tracer.coreRadius
    elseif self.kind == 'missile' then
        self.tracer.color = self.tracer.color
    end

    return self
end

function Turret:update(dt, target, locked, world)

    -- Update cooldown timer
    if self.cooldown > 0 then
        self.cooldown = math.max(0, self.cooldown - dt)
    end
    
    -- Update reload timer
    if self.isReloading then
        self.reloadTimer = math.max(0, self.reloadTimer - dt)
        if self.reloadTimer <= 0 then
            self.isReloading = false
            self.currentClip = self.clipSize
        end
    end


    if self.kind == "missile" then
        ProjectileWeapons.updateMissileLockState(self, dt, target, world)
    end

    -- Check if we can fire
    if locked then
        self.firing = false
        self.currentTarget = nil
        self.beamActive = false
        return
    end

    -- Check firing timing (cooldown takes priority over old timing system)
    if self.cooldown > 0 then
        return
    end

    local effectiveCycle = self.cycle

    -- No facing direction restrictions - enemies can shoot in any direction

    -- For manual mode, only fire if we're actively firing (button held)
    -- For automatic mode, fire if autoFire is enabled and cooldown allows
    if self.fireMode == "manual" or (self.fireMode == "automatic" and self.autoFire) then
        -- Prevent triggering cooldown while a weapon is still reloading
        if self.kind == "gun" and not self:canFire() then
            return
        end
        
        -- Check if we have enough energy to fire (skip for utility beams as they handle their own energy)
        -- Skip energy checks for enemies - they ignore energy usage
        if self.capCost and self.capCost > 0 and self.owner and self.owner.components and self.owner.components.health and self.owner.isPlayer then
            local currentEnergy = self.owner.components.health.energy or 0
            if currentEnergy < self.capCost then
                -- Show notification for insufficient energy (only for player) with spam protection
                local currentTime = love.timer.getTime()
                local lastEnergyNotification = self._lastEnergyNotification or 0
                local energyNotificationCooldown = 2.0 -- 2 seconds between notifications
                
                if currentTime - lastEnergyNotification > energyNotificationCooldown then
                    Notifications.add("Insufficient energy to fire weapon!", "warning")
                    self._lastEnergyNotification = currentTime
                end
                return -- Not enough energy to fire
            end
        end
        
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
    else
        -- Handle weapons that need to be updated even when not firing (for sound management)
        if self.kind == "mining_laser" then
            UtilityBeams.updateMiningLaser(self, dt, target, locked, world)
        elseif self.kind == "salvaging_laser" then
            UtilityBeams.updateSalvagingLaser(self, dt, target, locked, world)
        end

        -- Don't set cooldown when not firing - cooldown should only be set when actually firing
        -- The cooldown will be set by the weapon handlers when they actually fire
    end

    -- Update last fire time (legacy compatibility)
    self.lastFireTime = love.timer and love.timer.getTime()
end

function Turret:cancelFiring()
    self.firing = false
    self.beamActive = false
    
    -- Stop utility beam sounds when firing is cancelled
    if self.kind == "mining_laser" then
        if self.miningSoundActive or self.miningSoundInstance then
            local TurretEffects = require("src.systems.turret.effects")
            TurretEffects.stopMiningSound(self)
        end
    elseif self.kind == "salvaging_laser" then
        if self.salvagingSoundActive or self.salvagingSoundInstance then
            local TurretEffects = require("src.systems.turret.effects")
            TurretEffects.stopSalvagingSound(self)
        end
    end
    
    -- Don't reset cooldown here; let it finish its cycle
end

-- Legacy compatibility functions
function Turret:updateHeat(dt, locked)
    return true
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
    local canFire = self.cooldown <= 0
    -- Only check clip status for gun turrets
    if self.kind == "gun" then
        canFire = canFire and not self.isReloading and self.currentClip > 0
    end
    return canFire
end

-- Start reloading if not already reloading and clip is empty
function Turret:startReload()
    if not self.isReloading and self.currentClip < self.clipSize then
        self.isReloading = true
        self.reloadTimer = self.reloadTime
        self.firing = false -- Stop firing when reloading
    end
end

-- Get clip status for UI display
function Turret:getClipStatus()
    return {
        current = self.currentClip,
        max = self.clipSize,
        isReloading = self.isReloading,
        reloadProgress = self.isReloading and (1.0 - (self.reloadTimer / self.reloadTime)) or 1.0
    }
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


-- Calculate the world position of a turret based on ship position, rotation, and turret pivot
function Turret.getTurretWorldPosition(turret)
    if not turret or not turret.owner or not turret.owner.components or not turret.owner.components.position then
        return 0, 0
    end

    local shipX = turret.owner.components.position.x
    local shipY = turret.owner.components.position.y
    local shipAngle = turret.owner.components.position.angle

    -- Determine the local pivot and muzzle points from the ship's visuals.
    local pivotX, pivotY = 0, 0
    local muzzleX, muzzleY = 0, 0
    local pivotFound = false
    local muzzleFound = false
    local maxDistanceSq = -math.huge

    local visuals = turret.owner.ship and turret.owner.ship.visuals
    if visuals then
        if visuals.turretPivot then
            pivotX = visuals.turretPivot.x
            pivotY = visuals.turretPivot.y
            pivotFound = true
        end

        if visuals.shapes then
            for _, shape in ipairs(visuals.shapes) do
                if shape.turret then
                    if not pivotFound then
                        if type(shape.turretPivot) == "table" then
                            pivotX = shape.turretPivot.x
                            pivotY = shape.turretPivot.y
                            pivotFound = true
                        elseif shape.turretPivotX or shape.turretPivotY then
                            pivotX = shape.turretPivotX
                            pivotY = shape.turretPivotY
                            pivotFound = true
                        end
                    end

                    local candidateX, candidateY = nil, nil

                    if shape.type == "circle" then
                        candidateX = shape.x
                        candidateY = shape.y
                    elseif shape.type == "rectangle" then
                        candidateX = shape.x + shape.w / 2
                        candidateY = shape.y + shape.h / 2
                    elseif shape.type == "polygon" and shape.points then
                        local sumX, sumY = 0, 0
                        local count = 0
                        for i = 1, #shape.points, 2 do
                            sumX = sumX + shape.points[i]
                            sumY = sumY + shape.points[i + 1]
                            count = count + 1
                        end
                        if count > 0 then
                            candidateX = sumX / count
                            candidateY = sumY / count
                        end
                    end

                    if candidateX and candidateY then
                        local dx = candidateX - pivotX
                        local dy = candidateY - pivotY
                        local distSq = dx * dx + dy * dy
                        if distSq > maxDistanceSq then
                            muzzleX = candidateX
                            muzzleY = candidateY
                            maxDistanceSq = distSq
                            muzzleFound = true
                        end
                    end
                end
            end
        end
    end

    if not pivotFound then
        pivotX, pivotY = 0, 0
    end

    if not muzzleFound then
        muzzleX, muzzleY = pivotX, pivotY
    end

    -- Determine how much the turret is rotated relative to the ship.
    local aimAngle = turret.currentAimAngle
    if not aimAngle then
        aimAngle = shipAngle - math.pi / 2
    end
    local turretAngle = aimAngle - shipAngle + math.pi / 2

    -- Rotate pivot into world space.
    local cosShip = math.cos(shipAngle)
    local sinShip = math.sin(shipAngle)
    local pivotWorldX = shipX + pivotX * cosShip - pivotY * sinShip
    local pivotWorldY = shipY + pivotX * sinShip + pivotY * cosShip

    -- Rotate muzzle offset by turret rotation, then by ship rotation.
    local offsetX = muzzleX - pivotX
    local offsetY = muzzleY - pivotY
    local cosTurret = math.cos(turretAngle)
    local sinTurret = math.sin(turretAngle)
    local rotatedOffsetX = offsetX * cosTurret - offsetY * sinTurret
    local rotatedOffsetY = offsetX * sinTurret + offsetY * cosTurret

    local muzzleWorldX = pivotWorldX + rotatedOffsetX * cosShip - rotatedOffsetY * sinShip
    local muzzleWorldY = pivotWorldY + rotatedOffsetX * sinShip + rotatedOffsetY * cosShip

    return muzzleWorldX, muzzleWorldY
end

return Turret
