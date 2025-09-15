-- Warp Gate System: Manages warp gates in the world
local EntityFactory = require("src.templates.entity_factory")

local WarpGateSystem = {}

-- Create a basic warp gate at the specified location
function WarpGateSystem.createWarpGate(world, x, y, config)
    config = config or {}

    -- Default warp gate configuration
    local warpGateConfig = {
        name = config.name or "Warp Gate",
        interactionRange = config.interactionRange or 500,
        isActive = config.isActive ~= false,
        activationCost = config.activationCost or 0,
        requiresPower = config.requiresPower or false,
        powerLevel = config.powerLevel or 100,
        maxPowerLevel = config.maxPowerLevel or 100,
        rotationSpeed = config.rotationSpeed or 0.5,
        angle = config.angle or 0
    }

    -- Create the warp gate entity
    local warpGate = EntityFactory.create("warp_gate", "basic_warp_gate", x, y, warpGateConfig)

    if warpGate and world then
        world:addEntity(warpGate)
        print("Warp gate created at", x, y)
        return warpGate
    end

    return nil
end

-- Create a powered warp gate (requires energy to function)
function WarpGateSystem.createPoweredWarpGate(world, x, y, config)
    config = config or {}
    config.requiresPower = true
    config.powerLevel = config.powerLevel or 50
    config.activationCost = config.activationCost or 25
    config.name = config.name or "Powered Warp Gate"

    return WarpGateSystem.createWarpGate(world, x, y, config)
end

-- Create a premium warp gate (costs credits to use)
function WarpGateSystem.createPremiumWarpGate(world, x, y, config)
    config = config or {}
    config.activationCost = config.activationCost or 100
    config.name = config.name or "Premium Warp Gate"

    return WarpGateSystem.createWarpGate(world, x, y, config)
end

-- Update all warp gates in the world
function WarpGateSystem.updateWarpGates(world, dt)
    if not world then return end

    local warpGates = world:getEntitiesWithComponents("warp_gate")
    for _, warpGate in ipairs(warpGates) do
        if warpGate.update then
            warpGate:update(dt)
        end
    end
end

-- Get all warp gates near a position
function WarpGateSystem.getWarpGatesNear(world, x, y, range)
    if not world then return {} end

    range = range or 500
    local nearbyGates = {}
    local warpGates = world:getEntitiesWithComponents("warp_gate")

    for _, warpGate in ipairs(warpGates) do
        if warpGate.components.position then
            local gx, gy = warpGate.components.position.x, warpGate.components.position.y
            local distance = math.sqrt((gx - x)^2 + (gy - y)^2)
            if distance <= range then
                table.insert(nearbyGates, {gate = warpGate, distance = distance})
            end
        end
    end

    -- Sort by distance
    table.sort(nearbyGates, function(a, b) return a.distance < b.distance end)

    local gates = {}
    for _, entry in ipairs(nearbyGates) do
        table.insert(gates, entry.gate)
    end

    return gates
end

-- Find the closest warp gate to a position
function WarpGateSystem.getClosestWarpGate(world, x, y, maxRange)
    local gates = WarpGateSystem.getWarpGatesNear(world, x, y, maxRange or 1000)
    return gates[1] or nil
end

-- Activate all warp gates in the world
function WarpGateSystem.activateAllWarpGates(world)
    if not world then return 0 end

    local count = 0
    local warpGates = world:getEntitiesWithComponents("warp_gate")

    for _, warpGate in ipairs(warpGates) do
        if warpGate.setActive then
            warpGate:setActive(true)
            count = count + 1
        end
    end

    return count
end

-- Deactivate all warp gates in the world
function WarpGateSystem.deactivateAllWarpGates(world)
    if not world then return 0 end

    local count = 0
    local warpGates = world:getEntitiesWithComponents("warp_gate")

    for _, warpGate in ipairs(warpGates) do
        if warpGate.setActive then
            warpGate:setActive(false)
            count = count + 1
        end
    end

    return count
end

-- Demo function to create some warp gates for testing
function WarpGateSystem.createDemoWarpGates(world)
    if not world then return end

    -- Create a basic warp gate in the top left corner
    WarpGateSystem.createWarpGate(world, -800, 600, {
        name = "Central Warp Gate"
    })

    -- Create a powered warp gate
    WarpGateSystem.createPoweredWarpGate(world, -300, 150, {
        name = "Station Alpha Gate",
        powerLevel = 75
    })

    -- Create a premium warp gate
    WarpGateSystem.createPremiumWarpGate(world, 400, -250, {
        name = "Commercial Gate",
        activationCost = 50
    })

    print("Demo warp gates created!")
end

return WarpGateSystem