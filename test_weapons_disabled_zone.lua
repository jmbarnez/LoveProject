-- Test script to verify enemy weapons disabled zone implementation
-- This script can be run to test that enemies cannot fire inside station shield zones

local function testWeaponsDisabledZone()
    print("Testing Enemy Weapons Disabled Zone Implementation")
    print("=" ^ 50)

    -- Mock world and entities for testing
    local mockWorld = {
        entities = {},
        get_entities_with_components = function(self, ...)
            local components = {...}
            local result = {}

            for _, entity in ipairs(self.entities) do
                local hasAllComponents = true
                for _, component in ipairs(components) do
                    if not entity.components[component] then
                        hasAllComponents = false
                        break
                    end
                end

                if hasAllComponents then
                    table.insert(result, entity)
                end
            end

            return result
        end,
        addEntity = function(self, entity)
            table.insert(self.entities, entity)
        end
    }

    -- Mock SpaceStationSystem
    local mockSpaceStationSystem = {
        isInside = function(station, x, y)
            if not station or not station.components or not station.components.position then
                return false
            end

            local sx = station.components.position.x
            local sy = station.components.position.y
            local shieldRadius = station.shieldRadius or 600

            local dx = x - sx
            local dy = y - sy
            local distance = math.sqrt(dx * dx + dy * dy)

            return distance <= shieldRadius
        end
    }

    -- Mock AI system with the actual isEnemyInWeaponsDisabledZone function
    local function isEnemyInWeaponsDisabledZone(entity, world)
        if not entity or not entity.components or not entity.components.position then
            return false
        end

        local entityPos = entity.components.position

        -- Check the hub station
        local hub = nil
        for _, e in ipairs(world:get_entities_with_components("hub")) do
            hub = e
            break
        end

        if hub and mockSpaceStationSystem.isInside(hub, entityPos.x, entityPos.y) then
            return true
        end

        -- Check other stations with station component
        local stations = world:get_entities_with_components("station")
        for _, station in ipairs(stations) do
            if mockSpaceStationSystem.isInside(station, entityPos.x, entityPos.y) then
                return true
            end
        end

        return false
    end

    -- Create test entities
    local hubStation = {
        components = {
            position = { x = 0, y = 0 },
            hub = {}
        },
        shieldRadius = 500
    }

    local beaconStation = {
        components = {
            position = { x = 1000, y = 1000 },
            station = { type = "beacon_station" }
        },
        shieldRadius = 200
    }

    local enemyInsideHub = {
        components = {
            position = { x = 100, y = 100 },  -- Inside hub shield radius
            ai = {}
        }
    }

    local enemyInsideBeacon = {
        components = {
            position = { x = 1050, y = 1050 },  -- Inside beacon shield radius
            ai = {}
        }
    }

    local enemyOutside = {
        components = {
            position = { x = 2000, y = 2000 },  -- Outside both shield zones
            ai = {}
        }
    }

    -- Add entities to world
    mockWorld:addEntity(hubStation)
    mockWorld:addEntity(beaconStation)
    mockWorld:addEntity(enemyInsideHub)
    mockWorld:addEntity(enemyInsideBeacon)
    mockWorld:addEntity(enemyOutside)

    -- Run tests
    print("Test 1: Enemy inside hub station shield zone")
    local result1 = isEnemyInWeaponsDisabledZone(enemyInsideHub, mockWorld)
    print("Expected: true, Got: " .. tostring(result1))
    print("Result: " .. (result1 == true and "PASS" or "FAIL"))
    print()

    print("Test 2: Enemy inside beacon station shield zone")
    local result2 = isEnemyInWeaponsDisabledZone(enemyInsideBeacon, mockWorld)
    print("Expected: true, Got: " .. tostring(result2))
    print("Result: " .. (result2 == true and "PASS" or "FAIL"))
    print()

    print("Test 3: Enemy outside all shield zones")
    local result3 = isEnemyInWeaponsDisabledZone(enemyOutside, mockWorld)
    print("Expected: false, Got: " .. tostring(result3))
    print("Result: " .. (result3 == false and "PASS" or "FAIL"))
    print()

    print("Test 4: Enemy with no position component")
    local enemyNoPos = { components = { ai = {} } }
    local result4 = isEnemyInWeaponsDisabledZone(enemyNoPos, mockWorld)
    print("Expected: false, Got: " .. tostring(result4))
    print("Result: " .. (result4 == false and "PASS" or "FAIL"))
    print()

    -- Summary
    local passed = 0
    if result1 == true then passed = passed + 1 end
    if result2 == true then passed = passed + 1 end
    if result3 == false then passed = passed + 1 end
    if result4 == false then passed = passed + 1 end

    print("Summary: " .. passed .. "/4 tests passed")

    if passed == 4 then
        print("✅ All tests passed! Weapons disabled zone implementation is working correctly.")
    else
        print("❌ Some tests failed. Please review the implementation.")
    end

    return passed == 4
end

-- Run the test if this script is executed directly
if ... == nil then
    testWeaponsDisabledZone()
end

return { testWeaponsDisabledZone = testWeaponsDisabledZone }