local ConstructionSystem = {}
local Content = require("src.content.content")
local EntityFactory = require("src.templates.entity_factory")
local Events = require("src.core.events")
local Log = require("src.core.log")

local constructionState = {
    mode = false, -- true when in construction mode
    selectedItem = nil, -- currently selected construction item
    ghostEntity = nil, -- preview entity
    validPlacement = false,
    placementX = 0,
    placementY = 0,
    building = false, -- true when actively building
    buildProgress = 0, -- 0 to 1
    buildStartTime = 0,
    buildDuration = 0,
    ghostLocked = false -- true when ghost is locked in place during building
}

function ConstructionSystem.init()
    -- Initialize construction system
    Log.info("Construction system initialized")
end

function ConstructionSystem.update(dt, context)
    local player = context.player
    local world = context.world
    local input = context.input
    local camera = context.camera
    
    if not player or not world then return end
    
    -- Handle building progress
    if constructionState.building then
        ConstructionSystem.updateBuildingProgress(dt, player, world)
    end
    
    -- Handle construction mode
    if constructionState.mode then
        ConstructionSystem.updateConstructionMode(dt, player, world, input, camera)
    end
end

function ConstructionSystem.updateConstructionMode(dt, player, world, input, camera)
    if not constructionState.selectedItem then return end

    -- Don't update placement position if ghost is locked (building in progress)
    if not constructionState.ghostLocked then
        -- Safety check for input parameter
        if not input then
            Log.warn("Input parameter is nil in updateConstructionMode")
            return
        end

        -- Get mouse position in world coordinates
        local Viewport = require("src.core.viewport")
        local mx, my = Viewport.getMousePosition()
        local sw, sh = Viewport.getDimensions()

        if camera then
            -- Convert screen coordinates to world coordinates using camera's screenToWorld function
            constructionState.placementX, constructionState.placementY = camera:screenToWorld(mx, my)
        else
            constructionState.placementX = mx
            constructionState.placementY = my
        end

        -- Check if placement is valid
        constructionState.validPlacement = ConstructionSystem.isValidPlacement(
            constructionState.placementX,
            constructionState.placementY,
            world,
            player
        )

        -- Debug: Force valid placement to true
        constructionState.validPlacement = true
    end

    -- Update ghost entity (only if not locked)
    if not constructionState.ghostLocked then
        ConstructionSystem.updateGhost()
    end
end

function ConstructionSystem.isValidPlacement(x, y, world, player)
    -- Allow placement anywhere - no restrictions
    return true
end

function ConstructionSystem.updateGhost()
    if not constructionState.selectedItem then return end
    
    -- Create or update ghost entity
    if not constructionState.ghostEntity then
        constructionState.ghostEntity = ConstructionSystem.createGhostEntity()
    end
    
    if constructionState.ghostEntity and constructionState.ghostEntity.components then
        constructionState.ghostEntity.components.position.x = constructionState.placementX
        constructionState.ghostEntity.components.position.y = constructionState.placementY
    end
end

function ConstructionSystem.createGhostEntity()
    local ghost = {
        id = "ghost_" .. (constructionState.selectedItem or "turret"),
        isGhost = true,
        components = {
            position = {
                x = constructionState.placementX,
                y = constructionState.placementY,
                angle = 0
            },
            renderable = {
                visible = true,
                layer = "ghost"
            }
        }
    }
    
    return ghost
end

function ConstructionSystem.placeItem(player, world)
    if not constructionState.selectedItem then return end

    -- Safety check - should not be building when this is called due to action map logic
    if constructionState.building then
        Log.warn("placeItem called while already building - this should not happen")
        return
    end

    -- Check if player has required resources
    if not ConstructionSystem.hasRequiredResources(player, constructionState.selectedItem) then
        Log.warn("Insufficient resources for construction")
        return
    end

    -- Start building process at current placement location
    constructionState.building = true
    constructionState.buildProgress = 0
    constructionState.buildStartTime = love.timer.getTime()

    -- Get build duration from item definition
    local itemDef = Content.getWorldObject(constructionState.selectedItem)
    constructionState.buildDuration = (itemDef and itemDef.construction and itemDef.construction.buildTime) or 3.0

    -- Lock the ghost entity in place - don't update its position anymore
    constructionState.ghostLocked = true

    Log.info("Started building " .. constructionState.selectedItem .. " at (" .. constructionState.placementX .. ", " .. constructionState.placementY .. ")")
end

function ConstructionSystem.updateBuildingProgress(dt, player, world)
    if not constructionState.building then return end
    
    local currentTime = love.timer.getTime()
    local elapsed = currentTime - constructionState.buildStartTime
    constructionState.buildProgress = math.min(1.0, elapsed / constructionState.buildDuration)
    
    -- Check if building is complete
    if constructionState.buildProgress >= 1.0 then
        -- Create the actual entity
        local entity = ConstructionSystem.createConstructionEntity(
            constructionState.selectedItem,
            constructionState.placementX,
            constructionState.placementY
        )
        
        if entity then
            world:addEntity(entity)
            
            -- Deduct resources
            ConstructionSystem.deductResources(player, constructionState.selectedItem)
            
            Log.info("Completed building " .. constructionState.selectedItem)
        end
        
        -- Clear construction state
        ConstructionSystem.cancelConstruction()
    end
end

function ConstructionSystem.createConstructionEntity(itemType, x, y)
    if itemType == "holographic_turret" then
        local entity = EntityFactory.create("station", "holographic_turret", x, y)
        if entity and entity.components and entity.components.position then
            entity.id = "holographic_turret_" .. os.time() .. "_" .. math.random(1000, 9999)
            
            -- Equip the combat laser turret
            ConstructionSystem.equipTurret(entity, "combat_laser")
            
            return entity
        end
    end
    
    return nil
end

function ConstructionSystem.equipTurret(entity, turretType)
    if not entity or not entity.components then return end
    
    -- Get the turret definition
    local turretDef = Content.getTurret(turretType)
    if not turretDef then return end
    
    -- Initialize equipment component if it doesn't exist
    if not entity.components.equipment then
        entity.components.equipment = {
            grid = {}
        }
    end
    
    -- Create turret module
    local Turret = require("src.systems.turret.core")
    local turretModule = Turret.new(entity, {
        type = turretDef.type or turretType,
        damage_range = turretDef.damage_range or {20, 20},
        damagePerSecond = turretDef.damagePerSecond or 20,
        cycle = turretDef.cycle or 2.0,
        capCost = turretDef.capCost or 0,
        energyPerSecond = turretDef.energyPerSecond or 40,
        minResumeEnergy = turretDef.minResumeEnergy or 0,
        resumeEnergyMultiplier = turretDef.resumeEnergyMultiplier or 1.0,
        optimal = turretDef.optimal or 800,
        falloff = turretDef.falloff or 400,
        tracer = turretDef.tracer,
        sound = turretDef.sound or "laser_fire",
        muzzleFlash = turretDef.muzzleFlash or false,
        projectile = turretDef.projectile and turretDef.projectile.id or "combat_laser_beam",
        maxHeat = turretDef.maxHeat or 80,
        heatPerShot = turretDef.heatPerShot or 60,
        cooldownRate = turretDef.cooldownRate or 9,
        overheatCooldown = turretDef.overheatCooldown or 4.0,
        heatCycleMult = turretDef.heatCycleMult or 0.6,
        heatEnergyMult = turretDef.heatEnergyMult or 1.4,
        fireMode = turretDef.fireMode or "manual"
    })
    
    -- Add turret to equipment grid
    table.insert(entity.components.equipment.grid, {
        slot = 1,
        type = "turret",
        module = turretModule,
        id = turretType
    })
    
    -- Set up turret behavior for AI
    if entity.components.ai then
        entity.components.ai.turretBehavior = {
            fireMode = "automatic",
            autoFire = true,
            targetTypes = {"enemy", "hostile"}
        }
    end
    
    -- Set turret to automatic fire mode
    turretModule.fireMode = "automatic"
    turretModule.autoFire = true
end

function ConstructionSystem.hasRequiredResources(player, itemType)
    if itemType == "holographic_turret" then
        local health = player.components.health
        if not health then return false end
        
        return (health.energy or 0) >= 50
    end
    
    return false
end

function ConstructionSystem.deductResources(player, itemType)
    if itemType == "holographic_turret" then
        local health = player.components.health
        if health then
            health.energy = math.max(0, (health.energy or 0) - 50)
        end
    end
end

function ConstructionSystem.cancelConstruction()
    constructionState.mode = false
    constructionState.selectedItem = nil
    constructionState.building = false
    constructionState.buildProgress = 0
    constructionState.buildStartTime = 0
    constructionState.buildDuration = 0
    constructionState.ghostLocked = false
    ConstructionSystem.clearGhost()
end

function ConstructionSystem.clearGhost()
    constructionState.ghostEntity = nil
end

function ConstructionSystem.startConstruction(itemType)
    constructionState.mode = true
    constructionState.selectedItem = itemType
    constructionState.ghostEntity = nil
    constructionState.ghostLocked = false
    constructionState.building = false
end

function ConstructionSystem.isInConstructionMode()
    return constructionState.mode
end

function ConstructionSystem.isBuilding()
    return constructionState.building
end

function ConstructionSystem.getGhostEntity()
    return constructionState.ghostEntity
end

function ConstructionSystem.isValidPlacement()
    return constructionState.validPlacement
end

function ConstructionSystem.draw()
    if not constructionState.mode or not constructionState.ghostEntity then return end
    
    local Theme = require("src.core.theme")
    local x = constructionState.placementX
    local y = constructionState.placementY
    
    -- Draw ghost entity
    local color = constructionState.validPlacement and 
        {0.0, 1.0, 0.0, 0.5} or {1.0, 0.0, 0.0, 0.5}
    
    Theme.setColor(color)
    love.graphics.setLineWidth(2)
    
    -- Draw simple turret ghost
    local size = 32
    love.graphics.rectangle('line', x - size/2, y - size/2, size, size)
    love.graphics.circle('line', x, y, size/2)
    
    -- Draw barrel
    love.graphics.rectangle('line', x - 2, y - size/2 - 8, 4, 16)
    
    love.graphics.setLineWidth(1)
    
    -- Draw building progress if currently building
    if constructionState.building then
        ConstructionSystem.drawBuildingProgress(x, y)
    end
end

function ConstructionSystem.drawBuildingProgress(x, y)
    local Theme = require("src.core.theme")
    local progress = constructionState.buildProgress or 0

    -- Draw progress bar background (much bigger)
    local barWidth = 200
    local barHeight = 25
    local barX = x - barWidth / 2
    local barY = y - 60
    
    Theme.setColor({0.1, 0.1, 0.1, 0.8})
    love.graphics.rectangle('fill', barX, barY, barWidth, barHeight)
    
    -- Draw progress bar fill
    local fillWidth = barWidth * progress
    Theme.setColor({0.0, 1.0, 0.0, 0.8})
    love.graphics.rectangle('fill', barX, barY, fillWidth, barHeight)
    
    -- Draw progress bar border (thicker for bigger bar)
    Theme.setColor({1.0, 1.0, 1.0, 0.9})
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', barX, barY, barWidth, barHeight)

    -- Draw progress text (bigger font for bigger bar)
    local progressText = string.format("%.0f%%", progress * 100)
    local font = Theme.fonts and (Theme.fonts.medium or Theme.fonts.normal) or love.graphics.getFont()
    local oldFont = love.graphics.getFont()
    love.graphics.setFont(font)

    local textWidth = font:getWidth(progressText)
    local textX = x - textWidth / 2
    local textY = barY - 35

    Theme.setColor({1.0, 1.0, 1.0, 1.0})
    love.graphics.print(progressText, textX, textY)

    if oldFont then love.graphics.setFont(oldFont) end
end

return ConstructionSystem
