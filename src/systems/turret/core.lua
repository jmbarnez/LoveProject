local Util = require("src.core.util")
local Notifications = require("src.ui.notifications")
local Log = require("src.core.log")
local TurretRegistry = require("src.systems.turret.registry")

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

    -- Overheating system parameters (only for laser turrets)
    self.heatLevel = 0                    -- Current heat (0-100)
    self.maxHeat = params.maxHeat or 100  -- Overheat threshold
    self.heatGeneration = params.heatGeneration or 5  -- Heat per second while firing
    self.coolingRate = params.coolingRate or 3        -- Heat lost per second when not firing
    self.overheatPenalty = params.overheatPenalty or 10  -- Seconds of forced cooldown when overheated
    self.isOverheated = false             -- Overheated state
    self.overheatTimer = 0                -- Timer for overheat penalty
    
    -- Check if this is a laser turret (only laser turrets can overheat)
    self.isLaserTurret = self.type == "laser" or 
                        self.type == "mining_laser" or 
                        self.type == "healing_laser" or 
                        self.type == "salvaging_laser"

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

    self.modifierSystem = nil
    self.modifiers = {}
    self.upgradeEntry = nil

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

    -- Update overheating system (only for laser turrets)
    if self.isLaserTurret then
        if self.isOverheated then
            self.overheatTimer = math.max(0, self.overheatTimer - dt)
            if self.overheatTimer <= 0 then
                self.isOverheated = false
                self.heatLevel = 0  -- Reset heat when coming out of overheat
            end
        else
            -- Heat management when not overheated
            if self.firing then
                -- Generate heat while firing (per second for beam weapons)
                self.heatLevel = math.min(self.maxHeat, self.heatLevel + self.heatGeneration * dt)
                
                -- Check for overheat
                if self.heatLevel >= self.maxHeat then
                    self.isOverheated = true
                    self.overheatTimer = self.overheatPenalty
                    self.firing = false  -- Stop firing when overheated
                    self.beamActive = false
                    
                    -- Show overheat notification for player
                    if self.owner and self.owner.isPlayer then
                        Notifications.add("Weapon overheated! Cooling down...", "warning")
                    end
                end
            else
                -- Cool down when not firing
                self.heatLevel = math.max(0, self.heatLevel - self.coolingRate * dt)
            end
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

    -- Check if weapon is overheated (only for laser turrets)
    if self.isLaserTurret and self.isOverheated then
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

        -- Heat management is handled in the main update loop above
        -- No additional energy checks needed

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

-- Check if turret can fire (cooldown, heat, and clips)
function Turret:canFire()
    local canFire = self.cooldown <= 0 and not self.isOverheated
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

-- Generate heat when firing (for laser turrets only)
function Turret:generateHeat()
    if self.isLaserTurret and not self.isOverheated then
        self.heatLevel = math.min(self.maxHeat, self.heatLevel + self.heatGeneration)
        
        -- Check for overheat
        if self.heatLevel >= self.maxHeat then
            self.isOverheated = true
            self.overheatTimer = self.overheatPenalty
            self.firing = false  -- Stop firing when overheated
            self.beamActive = false
            
            -- Show overheat notification for player
            if self.owner and self.owner.isPlayer then
                Notifications.add("Weapon overheated! Cooling down...", "warning")
            end
        end
    end
end

-- Get heat status for UI display (only for laser turrets)
function Turret:getHeatStatus()
    if not self.isLaserTurret then
        return {
            heatLevel = 0,
            maxHeat = 100,
            isOverheated = false,
            overheatProgress = 0.0,
            heatPercentage = 0
        }
    end
    
    return {
        heatLevel = self.heatLevel,
        maxHeat = self.maxHeat,
        isOverheated = self.isOverheated,
        overheatProgress = self.isOverheated and (1.0 - (self.overheatTimer / self.overheatPenalty)) or 0.0,
        heatPercentage = (self.heatLevel / self.maxHeat) * 100
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
                        -- For circles, use the center as the muzzle tip
                        candidateX = shape.x
                        candidateY = shape.y
                    elseif shape.type == "rectangle" then
                        -- For rectangles, find the tip (farthest point from pivot in the direction of the rectangle)
                        local rectCenterX = shape.x + shape.w / 2
                        local rectCenterY = shape.y + shape.h / 2
                        local rectAngle = math.atan2(rectCenterY - pivotY, rectCenterX - pivotX)
                        
                        -- Calculate the tip position (farthest point in the direction of the rectangle)
                        local halfWidth = shape.w / 2
                        local halfHeight = shape.h / 2
                        local tipDistance = math.sqrt(halfWidth * halfWidth + halfHeight * halfHeight)
                        candidateX = rectCenterX + math.cos(rectAngle) * tipDistance
                        candidateY = rectCenterY + math.sin(rectAngle) * tipDistance
                    elseif shape.type == "polygon" and shape.points then
                        -- For polygons, find the farthest point from the pivot
                        local farthestX, farthestY = nil, nil
                        local maxDistSq = -1
                        
                        for i = 1, #shape.points, 2 do
                            local px = shape.points[i]
                            local py = shape.points[i + 1]
                            local dx = px - pivotX
                            local dy = py - pivotY
                            local distSq = dx * dx + dy * dy
                            
                            if distSq > maxDistSq then
                                maxDistSq = distSq
                                farthestX = px
                                farthestY = py
                            end
                        end
                        
                        candidateX = farthestX
                        candidateY = farthestY
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
