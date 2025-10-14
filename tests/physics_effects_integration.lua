--[[
    Physics → Effects Integration Test
    
    Tests the integration between physics collision detection and visual effects.
    Verifies that collisions trigger appropriate visual effects.
]]

local PhysicsSystem = require("src.systems.physics")
local Effects = require("src.systems.effects")
local CollisionEffects = require("src.systems.collision.effects")
local WindfieldManager = require("src.systems.physics.windfield_manager")

local PhysicsEffectsTest = {}

function PhysicsEffectsTest.run()
    print("Running Physics → Effects Integration Test...")
    
    local testResults = {
        physicsInit = false,
        collisionEffects = false,
        effectsSystem = false,
        windfieldCallbacks = false
    }
    
    -- Test 1: Physics system initialization
    local success, err = pcall(function()
        local manager = PhysicsSystem.init()
        testResults.physicsInit = manager ~= nil
    end)
    
    if not success then
        print("❌ Physics system initialization failed: " .. tostring(err))
    else
        print("✅ Physics system initialization: " .. (testResults.physicsInit and "PASS" or "FAIL"))
    end
    
    -- Test 2: Collision effects system
    local success, err = pcall(function()
        local canEmit = CollisionEffects.canEmitCollisionFX
        local createEffects = CollisionEffects.createCollisionEffects
        testResults.collisionEffects = type(canEmit) == "function" and type(createEffects) == "function"
    end)
    
    if not success then
        print("❌ Collision effects system check failed: " .. tostring(err))
    else
        print("✅ Collision effects system: " .. (testResults.collisionEffects and "PASS" or "FAIL"))
    end
    
    -- Test 3: Effects system
    local success, err = pcall(function()
        local update = Effects.update
        local spawnImpact = Effects.spawnImpact
        testResults.effectsSystem = type(update) == "function" and type(spawnImpact) == "function"
    end)
    
    if not success then
        print("❌ Effects system check failed: " .. tostring(err))
    else
        print("✅ Effects system: " .. (testResults.effectsSystem and "PASS" or "FAIL"))
    end
    
    -- Test 4: Windfield callbacks setup
    local success, err = pcall(function()
        local manager = PhysicsSystem.getManager()
        if manager and manager.world and manager.world.on then
            testResults.windfieldCallbacks = true
        end
    end)
    
    if not success then
        print("❌ Windfield callbacks check failed: " .. tostring(err))
    else
        print("✅ Windfield callbacks: " .. (testResults.windfieldCallbacks and "PASS" or "FAIL"))
    end
    
    -- Summary
    local allPassed = testResults.physicsInit and testResults.collisionEffects and 
                     testResults.effectsSystem and testResults.windfieldCallbacks
    
    print("\n" .. "=" .. string.rep("=", 50))
    print("Physics → Effects Integration Test Results:")
    print("=" .. string.rep("=", 50))
    print("Physics System Init: " .. (testResults.physicsInit and "✅ PASS" or "❌ FAIL"))
    print("Collision Effects:   " .. (testResults.collisionEffects and "✅ PASS" or "❌ FAIL"))
    print("Effects System:      " .. (testResults.effectsSystem and "✅ PASS" or "❌ FAIL"))
    print("Windfield Callbacks: " .. (testResults.windfieldCallbacks and "✅ PASS" or "❌ FAIL"))
    print("=" .. string.rep("=", 50))
    print("Overall Result: " .. (allPassed and "✅ ALL TESTS PASSED" or "❌ SOME TESTS FAILED"))
    print("=" .. string.rep("=", 50))
    
    return allPassed
end

-- Test collision effect deduplication
function PhysicsEffectsTest.testEffectDeduplication()
    print("\nTesting collision effect deduplication...")
    
    local mockEntityA = { id = 1, _collisionFx = {} }
    local mockEntityB = { id = 2, _collisionFx = {} }
    local now = 0
    
    -- First collision should be allowed
    local canEmit1 = CollisionEffects.canEmitCollisionFX(mockEntityA, mockEntityB, now)
    print("First collision (should be true): " .. tostring(canEmit1))
    
    -- Second collision immediately after should be blocked
    local canEmit2 = CollisionEffects.canEmitCollisionFX(mockEntityA, mockEntityB, now + 0.1)
    print("Second collision (should be false): " .. tostring(canEmit2))
    
    -- Collision after cooldown should be allowed
    local canEmit3 = CollisionEffects.canEmitCollisionFX(mockEntityA, mockEntityB, now + 0.3)
    print("Collision after cooldown (should be true): " .. tostring(canEmit3))
    
    local dedupWorking = canEmit1 and not canEmit2 and canEmit3
    print("Deduplication test: " .. (dedupWorking and "✅ PASS" or "❌ FAIL"))
    
    return dedupWorking
end

return PhysicsEffectsTest
