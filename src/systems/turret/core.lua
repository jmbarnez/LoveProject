local Util = require("src.core.util")
local ModifierSystem = require("src.systems.turret.modifier_system")
local UpgradeSystem = require("src.systems.turret.upgrade_system")
local Notifications = require("src.ui.notifications")
local Log = require("src.core.log")
local TurretRegistry = require("src.systems.turret.registry")

-- Ensure all built-in turret handlers are registered before instances are created.
require("src.systems.turret.types.projectile")
require("src.systems.turret.types.gun")
require("src.systems.turret.types.missile")
require("src.systems.turret.types.laser")
require("src.systems.turret.types.mining_laser")
require("src.systems.turret.types.salvaging_laser")
require("src.systems.turret.types.plasma_torch")
local Turret = {}
Turret.__index = Turret

local turretInstanceCounter = 0
local EMPTY_TABLE = {}


function Turret.new(owner, params)
    local self = setmetatable({}, Turret)

    self.owner = owner
    self.kind = params.type or params.kind
    turretInstanceCounter = turretInstanceCounter + 1
    self.templateId = params.id or params.turretId or (params.module and params.module.id)
    local uniqueBase = self.templateId or "turret"
    self.id = params.instanceId or string.format("%s_%d", uniqueBase, turretInstanceCounter)
    self.instanceId = self.id

    -- Skill progression tag used when this turret deals the killing blow
    self.skillId = params.skillId
    if not self.skillId then
        if self.kind == 'gun' or self.kind == 'projectile' or self.kind == 'laser' or self.kind == 'missile' or self.kind == 'plasma_torch' then
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
    self.tracer = params.tracer or {}
    self.impact = params.impact
    self.spread = params.spread
    if type(self.spread) ~= "table" then
        self.spread = { minDeg = 0, maxDeg = 0, decay = 0 }
    else
        self.spread.minDeg = self.spread.minDeg or 0
        self.spread.maxDeg = self.spread.maxDeg or self.spread.minDeg or 0
        self.spread.decay = self.spread.decay or 0
    end

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
    if type(params.volleyCount) == "number" and params.volleyCount >= 1 then
        self.volleyCount = params.volleyCount
    else
        self.volleyCount = 1
    end
    if type(params.volleySpreadDeg) == "number" then
        self.volleySpreadDeg = params.volleySpreadDeg
    else
        self.volleySpreadDeg = 0
    end

    self.secondaryFireCounter = 0


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

    self.modifierSystem = ModifierSystem.new(self, params.modifiers or {})
    self.modifiers = self.modifierSystem:getSummaries()
    if params.upgrades then
        self.upgradeEntry = UpgradeSystem.attach(self, params.upgrades)
    else
        self.upgradeEntry = nil
    end

    -- Set default tracer colors if not specified
    if self.kind == 'gun' or self.kind == 'projectile' or not self.kind then
        if not self.tracer.color then
            self.tracer.color = {0.35, 0.70, 1.00, 1.0}
        end
        self.tracer.width = self.tracer.width or 2
        self.tracer.coreRadius = self.tracer.coreRadius or 3
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
    elseif self.kind == 'plasma_torch' then
        self.tracer.color = self.tracer.color
        self.tracer.width = self.tracer.width
        self.tracer.coreRadius = self.tracer.coreRadius
    elseif self.kind == 'missile' then
        self.tracer.color = self.tracer.color
    end

    self:getHandler() -- Resolve the handler once so missing registrations surface early.

    return self
end

function Turret:getHandler()
    local currentKind = self.kind
    if self._handlerKind ~= currentKind then
        self._handler = TurretRegistry.get(currentKind)
        self._handlerKind = currentKind

        if not self._handler and not self._missingHandlerLogged then
            Log.warn("Turret: No handler registered for kind", tostring(currentKind or "default"))
            self._missingHandlerLogged = true
        end
    end

    return self._handler
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

    local handler = self:getHandler()
    if handler and handler.preUpdate then
        handler.preUpdate(self, dt, target, locked, world)
    end

    if locked then
        self.firing = false
        self.currentTarget = nil
        self.beamActive = false
        if handler and handler.onLocked then
            handler.onLocked(self, dt, target, locked, world)
        end
        return
    end

    if self.cooldown > 0 then
        return
    end

    if not handler then
        return
    end

    local config = handler.config or EMPTY_TABLE

    local wantsToFire = (self.fireMode == "manual") or (self.fireMode == "automatic" and self.autoFire)

    if wantsToFire then
        -- Check clip requirements only when actually trying to fire
        if config.requiresClip and not self:canFire() then
            return
        end

        -- Check energy requirements only when actually trying to fire
        if not config.skipEnergyCheck
            and self.capCost and self.capCost > 0
            and self.owner and self.owner.components and self.owner.components.health
            and self.owner.isPlayer then
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

        if handler.update then
            handler.update(self, dt, target, locked, world)
        end
    elseif handler.updateIdle then
        handler.updateIdle(self, dt, target, locked, world)
    end

    -- Update last fire time (legacy compatibility)
    self.lastFireTime = love.timer and love.timer.getTime()
end

function Turret:cancelFiring()
    self.firing = false
    self.beamActive = false

    local handler = self:getHandler()
    if handler and handler.cancelFiring then
        handler.cancelFiring(self)
    end

    -- Don't reset cooldown here; let it finish its cycle
end

-- Legacy compatibility functions
function Turret:updateHeat(dt, locked)
    return true
end


function Turret:updateMiningLaser(dt, target, locked, world)
    local UtilityBeams = require("src.systems.turret.utility_beams")
    return UtilityBeams.updateMiningLaser(self, dt, target, locked, world)
end

function Turret:drawMiningBeam()
    if self.miningTarget and self.owner and self.owner.components and self.owner.components.position then
        local sx = self.owner.components.position.x
        local sy = self.owner.components.position.y
        local ex = self.miningTarget.components.position.x
        local ey = self.miningTarget.components.position.y
        local UtilityBeams = require("src.systems.turret.utility_beams")
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
    local UtilityBeams = require("src.systems.turret.utility_beams")
    return UtilityBeams.updateSalvagingLaser(self, dt, target, locked, world)
end

-- Check if turret can fire (cooldown and heat)
function Turret:canFire()
    local canFire = self.cooldown <= 0
    -- Check clip status if this turret type requires clips
    local handler = self:getHandler()
    local config = handler and handler.config or EMPTY_TABLE
    if config.requiresClip then
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

    -- Determine how much the turret is rotated relative to the ship by comparing the
    -- desired aim with the default muzzle orientation encoded in the ship visuals.
    local offsetX = muzzleX - pivotX
    local offsetY = muzzleY - pivotY
    local hasOffset = (offsetX ~= 0) or (offsetY ~= 0)
    local baseOrientation = 0
    if hasOffset then
        baseOrientation = math.atan2(offsetY, offsetX)
    end

    local aimAngle = turret.currentAimAngle
    if not aimAngle then
        -- Default to aiming straight along the turret's unrotated muzzle direction so the
        -- calculated world position matches the ship visuals even before explicit aiming
        -- data is provided.
        aimAngle = shipAngle + baseOrientation
    end

    local aimRelative = aimAngle - shipAngle
    local turretAngle = aimRelative - baseOrientation

    -- Rotate pivot into world space.
    local cosShip = math.cos(shipAngle)
    local sinShip = math.sin(shipAngle)
    local pivotWorldX = shipX + pivotX * cosShip - pivotY * sinShip
    local pivotWorldY = shipY + pivotX * sinShip + pivotY * cosShip

    -- Rotate muzzle offset by turret rotation, then by ship rotation.
    local cosTurret = math.cos(turretAngle)
    local sinTurret = math.sin(turretAngle)
    local rotatedOffsetX = offsetX * cosTurret - offsetY * sinTurret
    local rotatedOffsetY = offsetX * sinTurret + offsetY * cosTurret

    local muzzleWorldX = pivotWorldX + rotatedOffsetX * cosShip - rotatedOffsetY * sinShip
    local muzzleWorldY = pivotWorldY + rotatedOffsetX * sinShip + rotatedOffsetY * cosShip

    return muzzleWorldX, muzzleWorldY
end

return Turret
