local love = rawget(_G, 'love') or {}
love.math = love.math or { random = math.random }
love.timer = love.timer or { getTime = function() return 0 end }

local dummyParticleSystem = {}
dummyParticleSystem.setParticleLifetime = function() end
dummyParticleSystem.setEmissionRate = function() end
dummyParticleSystem.setSizeVariation = function() end
dummyParticleSystem.setLinearDamping = function() end
dummyParticleSystem.setSpread = function() end
dummyParticleSystem.setSpeed = function() end
dummyParticleSystem.setLinearAcceleration = function() end
dummyParticleSystem.setColors = function() end
dummyParticleSystem.setSizes = function() end
dummyParticleSystem.start = function() end
dummyParticleSystem.setDirection = function() end
dummyParticleSystem.moveTo = function() end
dummyParticleSystem.update = function() end

love.graphics = love.graphics or {}
love.graphics.newCanvas = function() return {} end
love.graphics.getCanvas = function() return {} end
love.graphics.setCanvas = function() end
love.graphics.clear = function() end
love.graphics.newParticleSystem = function() return setmetatable({}, { __index = dummyParticleSystem }) end
love.graphics.setBlendMode = function() end
love.graphics.draw = function() end

_G.love = love

local Collidable = require("src.components.collidable")
local Health = require("src.components.health")
local Equipment = require("src.components.equipment")
local Velocity = require("src.components.velocity")
local Lootable = require("src.components.lootable")
local PlayerComponent = require("src.components.player")
local StationComponent = require("src.components.station")
local Interactable = require("src.components.interactable")

local Content = require("src.content.content")
local Normalizer = require("src.content.normalizer")

local testShipDef = {
    id = "test_ship",
    name = "Test Ship",
    visuals = {
        size = 1,
        shapes = {
            { type = "circle", x = 0, r = 20 },
        }
    },
    hull = { hp = 50, shield = 10, cap = 40 },
    engine = { mass = 200, accel = 400, maxSpeed = 250 },
    cargo = { capacity = 75, volumeLimit = 120 },
    equipmentSlots = 2,
    equipmentLayout = {
        { slot = 1, type = "weapon", label = "Alpha" },
        { slot = 2, type = "utility", label = "Beta" },
    },
    loot = { drops = { { id = "ore", min = 1, max = 3 } } },
}

local testWorldObjectDef = {
    id = "test_asteroid",
    name = "Training Asteroid",
    renderable = { type = "asteroid", props = {} },
    collidable = { radius = 30 },
    interactable = { range = 60, prompt = "Mine" },
}

local testStationDef = {
    id = "hub_station",
    name = "Hub",
    visuals = { size = 2, shapes = { { type = "circle", x = 0, r = 100 } } },
    station_services = { trade = true },
    description = "Central hub",
    collidable = { radius = 150 },
}

function Content.getShip(id)
    if id == testShipDef.id then
        return testShipDef
    end
    return nil
end

function Content.getWorldObject(id)
    if id == testWorldObjectDef.id then
        return testWorldObjectDef
    elseif id == testStationDef.id then
        return testStationDef
    end
    return nil
end

function Normalizer.normalizeShip(def) return def end
function Normalizer.normalizeWorldObject(def) return def end
function Normalizer.normalizeProjectile(def) return def end

local EntityFactory = require("src.templates.entity_factory")

local function assert_metatable(value, expected, name)
    assert(value ~= nil, name .. " component missing")
    assert(getmetatable(value) == expected, name .. " component should be constructed")
end

local function test_ship_factory()
    local ship = EntityFactory.create("ship", testShipDef.id, 100, 200, { isPlayer = true })
    assert(ship, "ship should be created")

    assert_metatable(ship.components.collidable, Collidable, "collidable")
    assert_metatable(ship.components.health, Health, "health")
    assert_metatable(ship.components.equipment, Equipment, "equipment")
    assert_metatable(ship.components.velocity, Velocity, "velocity")
    assert_metatable(ship.components.lootable, Lootable, "lootable")
    assert_metatable(ship.components.player, PlayerComponent, "player")

    assert(#ship.components.equipment.grid == 2, "equipment grid slots should be initialized")
end

local function test_world_object_factory()
    local worldObject = EntityFactory.create("world_object", testWorldObjectDef.id, 0, 0)
    assert(worldObject, "world object should be created")

    assert_metatable(worldObject.components.collidable, Collidable, "world object collidable")
    assert_metatable(worldObject.components.interactable, Interactable, "world object interactable")
end

local function test_station_factory()
    local station = EntityFactory.create("station", testStationDef.id, 0, 0)
    assert(station, "station should be created")

    assert_metatable(station.components.station, StationComponent, "station metadata")
    assert_metatable(station.components.collidable, Collidable, "station collidable")
end

local tests = {
    { name = "ship_factory_constructs_components", fn = test_ship_factory },
    { name = "world_object_factory_constructs_components", fn = test_world_object_factory },
    { name = "station_factory_constructs_components", fn = test_station_factory },
}

local failures = {}
for _, case in ipairs(tests) do
    local ok, err = pcall(case.fn)
    if ok then
        print("PASS\t" .. case.name)
    else
        print("FAIL\t" .. case.name .. "\t" .. tostring(err))
        table.insert(failures, case.name .. ": " .. tostring(err))
    end
end

if #failures > 0 then
    error(table.concat(failures, "\n"))
end
