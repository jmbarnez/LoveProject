--[[
    Gravity System
    
    Applies gravitational forces from massive objects (planets, stations) to all entities.
    Uses Newton's law of universal gravitation: F = G * m1 * m2 / r^2
]]

local GravitySystem = {}
local CorePhysics = require("src.core.physics")

-- Cache for gravity sources to avoid repeated lookups
local gravitySources = {}
local lastUpdateTime = 0
local UPDATE_FREQUENCY = 0.1 -- Update gravity sources every 0.1 seconds

-- Find all objects that can exert gravity
local function updateGravitySources(world)
    local currentTime = love.timer.getTime()
    if currentTime - lastUpdateTime < UPDATE_FREQUENCY then
        return -- Skip update if too recent
    end
    
    gravitySources = {}
    local entities = world:getEntities()
    
    for id, entity in pairs(entities) do
        if entity.components and entity.components.position then
            local pos = entity.components.position
            local mass = 0
            local name = "Unknown"
            
            -- Determine mass based on entity type
            if entity.components.physics and entity.components.physics.body then
                mass = entity.components.physics.body.mass or 0
            elseif entity.components.physics then
                mass = entity.components.physics.mass or 0
            end
            
            -- Check for massive objects (planets, stations)
            if entity.components.renderable and entity.components.renderable.props then
                local props = entity.components.renderable.props
                if props.visuals and props.visuals.radius then
                    -- This is likely a planet or massive object
                    local radius = props.visuals.radius
                    if radius > 100 then -- Only large objects exert significant gravity
                        mass = radius * 10 -- Scale mass based on visual radius
                        name = entity.name or "Massive Object"
                    end
                end
            end
            
            -- Stations and hubs also have gravity
            if entity.components.station or entity.components.hub then
                mass = 1000 -- Stations have significant mass
                name = entity.name or "Station"
            end
            
            -- Only add if it has significant mass
            if mass > 100 then
                table.insert(gravitySources, {
                    x = pos.x,
                    y = pos.y,
                    mass = mass,
                    name = name,
                    id = id
                })
            end
        end
    end
    
    lastUpdateTime = currentTime
end

-- Calculate gravitational force between two objects
local function calculateGravityForce(obj1, obj2, mass1, mass2, distance)
    if distance < 1 then return 0, 0 end -- Avoid division by zero
    
    local force = CorePhysics.constants.GRAVITATIONAL_CONSTANT * mass1 * mass2 / (distance * distance)
    
    -- Apply minimum force threshold
    if force < CorePhysics.constants.MIN_GRAVITY_FORCE then
        return 0, 0
    end
    
    -- Calculate direction vector
    local dx = obj2.x - obj1.x
    local dy = obj2.y - obj1.y
    local dirX = dx / distance
    local dirY = dy / distance
    
    return force * dirX, force * dirY
end

-- Apply gravity to a single entity
local function applyGravityToEntity(entity, dt)
    if not entity.components or not entity.components.position then
        return
    end
    
    local pos = entity.components.position
    local mass = 0
    
    -- Get entity mass
    if entity.components.physics and entity.components.physics.body then
        mass = entity.components.physics.body.mass or 0
    elseif entity.components.physics then
        mass = entity.components.physics.mass or 0
    end
    
    if mass <= 0 then return end -- Skip if no mass
    
    local totalForceX, totalForceY = 0, 0
    
    -- Calculate gravity from all sources
    for _, source in ipairs(gravitySources) do
        local dx = source.x - pos.x
        local dy = source.y - pos.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        -- Skip if too far away
        if distance > CorePhysics.constants.MAX_GRAVITY_DISTANCE then
            goto continue
        end
        
        -- Calculate gravitational force
        local forceX, forceY = calculateGravityForce(
            {x = pos.x, y = pos.y},
            {x = source.x, y = source.y},
            mass,
            source.mass,
            distance
        )
        
        totalForceX = totalForceX + forceX
        totalForceY = totalForceY + forceY
        
        ::continue::
    end
    
    -- Apply gravity force to entity
    if totalForceX ~= 0 or totalForceY ~= 0 then
        if entity.components.physics and entity.components.physics.body then
            -- Physics body entity
            entity.components.physics.body:applyForce(totalForceX, totalForceY, dt)
        elseif entity.components.velocity then
            -- Velocity-based entity
            local accelX = totalForceX / mass
            local accelY = totalForceY / mass
            entity.components.velocity.x = (entity.components.velocity.x or 0) + accelX * dt
            entity.components.velocity.y = (entity.components.velocity.y or 0) + accelY * dt
        end
    end
end

-- Main gravity system update
function GravitySystem.update(dt, world)
    -- Update gravity sources
    updateGravitySources(world)
    
    -- Skip if no gravity sources
    if #gravitySources == 0 then
        return
    end
    
    -- Apply gravity to all entities
    local entities = world:getEntities()
    for id, entity in pairs(entities) do
        -- Skip gravity sources themselves
        local isGravitySource = false
        for _, source in ipairs(gravitySources) do
            if source.id == id then
                isGravitySource = true
                break
            end
        end
        
        if not isGravitySource then
            applyGravityToEntity(entity, dt)
        end
    end
end

-- Get gravity sources for debugging
function GravitySystem.getGravitySources()
    return gravitySources
end

-- Draw gravity field visualization (debug mode)
function GravitySystem.drawDebug(camera)
    if not DEBUG_GRAVITY then return end
    
    local Theme = require("src.core.theme")
    local Viewport = require("src.core.viewport")
    
    -- Get camera bounds
    local x, y, w, h = camera:getBounds()
    local sw, sh = Viewport.getDimensions()
    
    -- Draw gravity sources
    for _, source in ipairs(gravitySources) do
        -- Only draw if source is visible
        if source.x >= x - 100 and source.x <= x + w + 100 and 
           source.y >= y - 100 and source.y <= y + h + 100 then
            -- Draw gravity source
            Theme.setColor(Theme.withAlpha({1, 1, 0, 1}, 0.3))
            love.graphics.circle("fill", source.x - x + sw/2, source.y - y + sh/2, 20)
            
            -- Draw gravity field lines
            local steps = 8
            for i = 0, steps - 1 do
                local angle = (i / steps) * math.pi * 2
                local startRadius = 50
                local endRadius = CorePhysics.constants.MAX_GRAVITY_DISTANCE
                
                local startX = source.x + math.cos(angle) * startRadius
                local startY = source.y + math.sin(angle) * startRadius
                local endX = source.x + math.cos(angle) * endRadius
                local endY = source.y + math.sin(angle) * endRadius
                
                -- Convert to screen coordinates
                local sx1 = startX - x + sw/2
                local sy1 = startY - y + sh/2
                local sx2 = endX - x + sw/2
                local sy2 = endY - y + sh/2
                
                Theme.setColor(Theme.withAlpha({1, 1, 0, 1}, 0.1))
                love.graphics.line(sx1, sy1, sx2, sy2)
            end
        end
    end
end

return GravitySystem
