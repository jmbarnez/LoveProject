-- Entity Factory: A universal utility for creating any entity type from data.
local Content = require("src.content.content")
local Normalizer = require("src.content.normalizer")
local Builder = require("src.templates.builder")
local Log = require("src.core.log")
local Util = require("src.core.util")
local TurretCore = require("src.systems.turret.core")

local function random_choice(options)
    if type(options) ~= "table" or #options == 0 then
        return nil
    end

    if love and love.math and love.math.random then
        return options[love.math.random(1, #options)]
    end

    return options[math.random(1, #options)]
end

-- A registry for entity blueprints/templates.
local entity_templates = {
    ship = require("src.templates.ship"),
    projectile = require("src.templates.projectile"),
    world_object = require("src.templates.world_object"),
    station = require("src.templates.station"),
    warp_gate = require("src.templates.warp_gate"),
}

local EntityFactory = {}

---
-- Creates a base entity instance from a template and a configuration.
-- This is the core, generic creation function.
---
function EntityFactory.create(entityType, entityId, x, y, extraConfig)
    local template = entity_templates[entityType]
    if not template then
        Log.warn("EntityFactory - No template for type", tostring(entityType))
        return nil
    end

    local config
    if entityType == "ship" then
        config = Content.getShip(entityId)
    elseif entityType == "projectile" then
        config = Content.getProjectile(entityId)
    elseif entityType == "world_object" or entityType == "station" then
        config = Content.getWorldObject(entityId)
    elseif entityType == "warp_gate" then
        -- Warp gates use their own config system
        config = extraConfig or {
            name = "Warp Gate",
            interactionRange = 150,
            isActive = true,
            activationCost = 0,
            requiresPower = false
        }
    end

    if not config then
        return nil
    end

    -- Deep copy the config to prevent shared data issues
    config = Util.deepCopy(config)

    -- The 'friendly' flag and angle are passed in the extraConfig for projectiles
    local friendly = (extraConfig and extraConfig.friendly) or false
    local angle = (extraConfig and extraConfig.angle) or 0

    -- Normalize to canonical schema
    if entityType == "ship" then
        config = Normalizer.normalizeShip(config)
    elseif entityType == "projectile" then
        config = Normalizer.normalizeProjectile(config)
    elseif entityType == "world_object" or entityType == "station" then
        config = Normalizer.normalizeWorldObject(config)
    elseif entityType == "warp_gate" then
        -- Warp gates don't need normalization as they use their own config
    end

    -- Merge extraConfig into normalized config (flags like isEnemy)
    if extraConfig then
        for k, v in pairs(extraConfig) do
            config[k] = v
        end
    end
    local entity
    if entityType == "ship" then
        entity = Builder.buildShip(config, x, y, { angle = angle, friendly = friendly })
    elseif entityType == "projectile" then
        entity = Builder.buildProjectile(config, x, y, angle, friendly, extraConfig)
    elseif entityType == "world_object" then
        entity = Builder.buildWorldObject(config, x, y, { angle = angle, friendly = friendly })
    elseif entityType == "station" then
        entity = Builder.buildStation(config, x, y, { angle = angle, friendly = friendly })
    else
        -- Fallback to template constructor
        entity = template.new(x, y, config)
    end

    return entity
end

---
-- Specialized creation functions for different ship roles.
---

-- Create a player ship
function EntityFactory.createPlayer(shipId, x, y)
  local config = {
    isPlayer = true,
    energyRegen = 20, -- units per second
    shipId = shipId,
  }
  return EntityFactory.create("ship", shipId, x, y, config)
end

-- Create an enemy ship
function EntityFactory.createEnemy(shipId, x, y)
    local shipConfig = Content.getShip(shipId)
    local enemySettings = {}
    if shipConfig and shipConfig.enemy then
        enemySettings = Util.deepCopy(shipConfig.enemy)
    end

    local config = {}
    if type(enemySettings.entity) == "table" then
        for k, v in pairs(enemySettings.entity) do
            config[k] = Util.deepCopy(v)
        end
    end

    config.isEnemy = true
    config.shipId = shipId -- Store ship ID for quest tracking

    if config.bounty == nil then
        config.bounty = enemySettings.bounty or (shipConfig and shipConfig.bounty) or 25
    end
    if config.xpReward == nil then
        config.xpReward = enemySettings.xpReward or (shipConfig and shipConfig.xpReward) or 50
    end
    if config.energyRegen == nil then
        config.energyRegen = enemySettings.energyRegen or (shipConfig and shipConfig.energyRegen) or 35
    end

    local enemy = EntityFactory.create("ship", shipId, x, y, config)
    if enemy and enemy.components then
        enemy.enemyConfig = Util.deepCopy(enemySettings)

        if type(enemySettings.entity) == "table" then
            for k, v in pairs(enemySettings.entity) do
                enemy[k] = Util.deepCopy(v)
            end
        end

        if enemySettings.isBoss ~= nil then
            enemy.isBoss = enemySettings.isBoss
        elseif shipConfig and shipConfig.isBoss ~= nil then
            enemy.isBoss = shipConfig.isBoss
        elseif shipId == 'boss_drone' then
            enemy.isBoss = true
        end

        local sizeMultiplier = enemySettings.sizeMultiplier or 1.0
        local collidableMultiplier = enemySettings.collidableRadiusMultiplier or sizeMultiplier
        local physicsMultiplier = enemySettings.physicsRadiusMultiplier or sizeMultiplier

        local rend = enemy.components.renderable
        if rend and rend.props and rend.props.visuals and sizeMultiplier ~= 1.0 then
            local visuals = rend.props.visuals
            visuals.size = (visuals.size or 1.0) * sizeMultiplier
        end
        if enemy.components.collidable and collidableMultiplier ~= 1.0 then
            local baseRadius = enemy.components.collidable.radius or 10
            enemy.components.collidable.radius = baseRadius * collidableMultiplier
        end
        if enemy.components.physics and enemy.components.physics.body and physicsMultiplier ~= 1.0 then
            local baseBodyRadius = enemy.components.physics.body.radius or 10
            enemy.components.physics.body.radius = baseBodyRadius * physicsMultiplier
        end

        enemy.shieldRadius = nil
        enemy._shieldRadiusVisualSize = nil

        local autoEquipTurrets = enemySettings.autoEquipTurrets
        if autoEquipTurrets == nil then autoEquipTurrets = true end

        if autoEquipTurrets then
            local hardpoints = shipConfig and shipConfig.hardpoints
            local equipment = enemy.components.equipment
            if hardpoints and equipment and equipment.grid then
                local turretBehavior = enemySettings.turretBehavior or {}
                local defaultFireMode = turretBehavior.fireMode or "automatic"
                local defaultAutoFire = turretBehavior.autoFire
                if defaultAutoFire == nil then
                    defaultAutoFire = true
                end

                local grid = equipment.grid
                local function getSlot(index)
                    if not grid[index] then
                        grid[index] = { slot = index, id = nil, module = nil, enabled = false, type = nil }
                    end
                    return grid[index]
                end

                local nextSlot = 1
                for _, hardpoint in ipairs(hardpoints) do
                    local turretId = hardpoint.turret or hardpoint.id
                    local turretDef = nil

                    if shipId == "basic_drone" and hardpoint.randomTurrets then
                        local randomId = random_choice(hardpoint.randomTurrets)
                        if randomId then
                            turretId = randomId
                        end
                    end

                    if type(turretId) == "table" then
                        turretDef = turretId
                        turretId = turretDef.id or ("embedded_turret_" .. nextSlot)
                    else
                        turretDef = Content.getTurret(turretId)
                    end

                    if turretDef then
                        local turretParams = Util.deepCopy(turretDef)
                        turretParams.fireMode = turretParams.fireMode or defaultFireMode
                        local turretInstance = TurretCore.new(enemy, turretParams)

                        turretInstance.fireMode = turretInstance.fireMode or defaultFireMode
                        if turretInstance.fireMode == "automatic" then
                            if defaultAutoFire ~= nil then
                                turretInstance.autoFire = defaultAutoFire
                            elseif turretInstance.autoFire == nil then
                                turretInstance.autoFire = true
                            end
                        elseif defaultAutoFire ~= nil then
                            turretInstance.autoFire = defaultAutoFire
                        end

                        local slotIndex = hardpoint.slot or nextSlot
                        local slot = getSlot(slotIndex)
                        slot.id = turretId
                        slot.module = turretInstance
                        slot.enabled = true
                        slot.type = "turret"

                        nextSlot = math.max(nextSlot, slotIndex + 1)
                    else
                        Log.warn("EntityFactory - Missing turret definition for", tostring(turretId))
                    end
                end
            end
        end
    end
    return enemy
end

-- Create an NPC/freighter ship
function EntityFactory.createFreighter(shipId, x, y)
    local shipConfig = Content.getShip(shipId)
    local config = {
        isFreighter = true,
        bounty = (shipConfig and shipConfig.bounty) or 100, -- Higher bounty for valuable cargo
        xpReward = (shipConfig and shipConfig.xpReward) or 200,
    }
    return EntityFactory.create("ship", shipId, x, y, config)
end

return EntityFactory
