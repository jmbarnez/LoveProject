package.path = package.path .. ';src/?.lua;src/?/init.lua;src/?/?.lua'

local love = love or {}
love.timer = love.timer or {
    getTime = function()
        return 0
    end
}

local TurretSystem = require("src.systems.turret.system")
local UpgradeSystem = require("src.systems.turret.upgrade_system")
local TurretRegistry = require("src.systems.turret.registry")

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or "expected values to match") .. string.format(" (expected %s, got %s)", tostring(expected), tostring(actual)), 2)
    end
end

local function assert_true(value, message)
    if not value then
        error(message or "expected condition to be true", 2)
    end
end

local function create_owner()
    return {
        components = {
            position = { x = 0, y = 0, angle = 0 },
            health = { energy = 100, maxEnergy = 100 }
        },
        isPlayer = false
    }
end

local tests = {}

tests[#tests + 1] = {
    name = "spawn applies modifiers",
    fn = function()
        local owner = create_owner()
        local turret = TurretSystem.spawn(owner, {
            id = "unit_test_turret",
            type = "laser",
            damage_range = { min = 10, max = 20 },
            modifiers = {
                { id = "overcharged_coils", damageMultiplier = 2.0, energyMultiplier = 1.0 }
            }
        })

        assert_equal(math.floor(turret.damage_range.min + 0.5), 20, "modifier should scale min damage")
        assert_equal(math.floor(turret.damage_range.max + 0.5), 40, "modifier should scale max damage")
        assert_true(turret.modifierSystem ~= nil, "modifier system should be attached")
        assert_true(#(turret.modifiers or {}) > 0, "modifier summaries should exist")

        TurretSystem.teardown(turret)
    end
}

tests[#tests + 1] = {
    name = "upgrades attach and detach",
    fn = function()
        local owner = create_owner()
        local turret = TurretSystem.spawn(owner, {
            id = "upgrade_test_turret",
            type = "laser",
            damage_range = { min = 5, max = 5 },
            upgrades = {
                startLevel = 1,
                thresholds = { 10 },
                bonuses = {
                    [1] = { damageMultiplier = 2 }
                }
            }
        })

        assert_equal(turret.damage_range.min, 10, "upgrade bonus should be applied on spawn")
        local entry = UpgradeSystem.getEntry(turret.id)
        assert_true(entry ~= nil, "upgrade entry should be registered")

        TurretSystem.teardown(turret)
        assert_true(UpgradeSystem.getEntry(turret.id) == nil, "upgrade entry should be removed on teardown")
    end
}

tests[#tests + 1] = {
    name = "fire dispatches to handler",
    fn = function()
        local owner = create_owner()

        TurretRegistry.register("unit_test_handler", {
            fire = function(turret, dt)
                turret._firedWith = dt
            end
        })

        TurretRegistry.register("unit_test_update_handler", {
            update = function(turret, dt)
                turret._updatedWith = dt
            end
        })

        local turretWithFire = TurretSystem.spawn(owner, {
            id = "handler_fire_turret",
            type = "unit_test_handler",
            damage_range = { min = 1, max = 1 }
        })

        local turretWithUpdate = TurretSystem.spawn(owner, {
            id = "handler_update_turret",
            type = "unit_test_update_handler",
            damage_range = { min = 1, max = 1 }
        })

        TurretSystem.fire(turretWithFire, 0.25)
        TurretSystem.fire(turretWithUpdate, 0.5)

        assert_equal(turretWithFire._firedWith, 0.25, "fire handler should receive dt")
        assert_equal(turretWithUpdate._updatedWith, 0.5, "update handler should run when fire callback missing")

        TurretSystem.teardown(turretWithFire)
        TurretSystem.teardown(turretWithUpdate)
    end
}

local passed = 0
for _, test in ipairs(tests) do
    test.fn()
    passed = passed + 1
    print(string.format("ok - %s", test.name))
end

print(string.format("All %d turret system tests passed", passed))
