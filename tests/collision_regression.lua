package.path = package.path .. ';./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;./src/?/?/init.lua'

_G.love = {
    timer = {
        getTime = function() return 0 end,
    }
}

local function stub_module(name, value)
    package.loaded[name] = value
end

stub_module('src.content.config', {
    COMBAT = {
        HULL_RESTITUTION = 0.28,
        SHIELD_RESTITUTION = 0.88,
    },
    BULLET = {
        HIT_BUFFER = 1.5,
    },
})

stub_module('src.core.constants', {
    COMBAT = {
        HULL_RESTITUTION = 0.28,
        SHIELD_RESTITUTION = 0.88,
    }
})

stub_module('src.core.log', {
    debug = function() end,
    warn = function() end,
})

stub_module('src.core.physics', {
    segCircleHit = function(x1, y1, x2, y2, cx, cy, r)
        local dx = x2 - x1
        local dy = y2 - y1
        local fx = x1 - cx
        local fy = y1 - cy
        local a = dx * dx + dy * dy
        local b = 2 * (fx * dx + fy * dy)
        local c = fx * fx + fy * fy - r * r
        local discriminant = b * b - 4 * a * c
        if discriminant < 0 then
            return false
        end
        discriminant = math.sqrt(discriminant)
        local t1 = (-b - discriminant) / (2 * a)
        local t2 = (-b + discriminant) / (2 * a)
        local t = nil
        if t1 >= 0 and t1 <= 1 then t = t1 end
        if not t and t2 >= 0 and t2 <= 1 then t = t2 end
        if not t then return false end
        local hx = x1 + dx * t
        local hy = y1 + dy * t
        return true, hx, hy
    end,
})

stub_module('src.systems.collision.geometry', {
    transformPolygon = function(x, y, angle, verts) return verts end,
    polygonPolygonMTV = function() return false end,
    polygonCircleMTV = function() return false end,
    segPolygonHit = function() return false end,
    calculateShieldHitPoint = function() return false end,
})

stub_module('src.systems.collision.radius', {
    calculateEffectiveRadius = function(entity)
        local collidable = entity.components and entity.components.collidable
        return (collidable and collidable.radius) or 0
    end,
    computeVisualRadius = function(entity)
        local renderable = entity.components and entity.components.renderable
        return (renderable and renderable.radius) or 0
    end,
    getShieldRadius = function(entity)
        return ((entity.components and entity.components.collidable) and entity.components.collidable.radius) or 0
    end,
    getHullRadius = function(entity)
        local collidable = entity.components and entity.components.collidable
        return (collidable and collidable.radius) or 0
    end,
})

local stationShieldsStub = {
    hasActiveShield = function(entity)
        local health = entity.components and entity.components.health
        return health and (health.shield or 0) > 0
    end,
    isStation = function(entity)
        return entity.tag == 'station'
    end,
    shouldIgnoreEntityCollision = function() return false end,
    checkStationSafeZone = function() return false end,
    handleStationShieldCollision = function() return false end,
}
stub_module('src.systems.collision.station_shields', stationShieldsStub)

local collisionEffectsLog = {
    damage = {},
    collisions = 0,
}

stub_module('src.systems.collision.effects', {
    hasShield = function(entity)
        local health = entity.components and entity.components.health
        return health and (health.shield or 0) > 0
    end,
    applyDamage = function(entity, amount)
        local health = entity.components and entity.components.health
        if not health then return false end
        if health.shield and health.shield > 0 then
            health.shield = math.max(0, health.shield - amount)
            return true
        end
        health.hp = (health.hp or 0) - amount
        table.insert(collisionEffectsLog.damage, amount)
        return false
    end,
    canEmitCollisionFX = function() return true end,
    createCollisionEffects = function()
        collisionEffectsLog.collisions = collisionEffectsLog.collisions + 1
    end,
})

local effectsLog = {
    impacts = 0,
    sonic = 0,
}

stub_module('src.systems.effects', {
    spawnImpact = function()
        effectsLog.impacts = effectsLog.impacts + 1
    end,
    spawnSonicBoom = function()
        effectsLog.sonic = effectsLog.sonic + 1
    end,
})

stub_module('src.systems.projectile.event_dispatcher', {
    EVENTS = { HIT = 'hit' },
})

stub_module('src.systems.turret.upgrade_system', {
    onProjectileHit = function() end,
})

stub_module('src.core.windfield_world', {
    new = function()
        return {
            beginSync = function() end,
            syncCircle = function()
                return { setLinearVelocity = function() end }
            end,
            endSync = function() end,
            update = function() end,
            drainContacts = function() return {} end,
        }
    end
})

local function make_world(entities)
    local world = { entities = entities }
    function world:get_entities_with_components(...)
        local required = {...}
        local results = {}
        for _, entity in ipairs(self.entities) do
            local ok = true
            for _, component in ipairs(required) do
                if not (entity.components and entity.components[component]) then
                    ok = false
                    break
                end
            end
            if ok then
                table.insert(results, entity)
            end
        end
        return results
    end
    function world:get_entities_in_radius(x, y, radius)
        local results = {}
        for _, entity in ipairs(self.entities) do
            local pos = entity.components and entity.components.position
            if pos then
                local dx = pos.x - x
                local dy = pos.y - y
                if math.sqrt(dx * dx + dy * dy) <= radius then
                    table.insert(results, entity)
                end
            end
        end
        return results
    end
    function world:addEntity(entity)
        table.insert(self.entities, entity)
    end
    return world
end

local CollisionSystem = require('src.systems.collision.core')

local function assert_true(condition, message)
    if not condition then
        error(message or 'assertion failed')
    end
end

local function reset_logs()
    collisionEffectsLog.damage = {}
    collisionEffectsLog.collisions = 0
    effectsLog.impacts = 0
    effectsLog.sonic = 0
end

local function test_projectile_hits_entity()
    reset_logs()
    local source = { components = {} }
    local projectile = {
        components = {
            position = { x = -5, y = 0 },
            velocity = { x = 10, y = 0 },
            renderable = { props = { kind = 'projectile' } },
            collidable = { radius = 1 },
            bullet = { source = source, slot = 1 },
            damage = { value = 4 },
            projectile_events = {
                dispatcher = {
                    emitted = {},
                    emit = function(self, event, payload)
                        table.insert(self.emitted, { event = event, payload = payload })
                    end,
                }
            },
        },
    }

    local target = {
        components = {
            position = { x = 0, y = 0 },
            collidable = { radius = 6 },
            health = { hp = 20, shield = 0 },
        },
    }

    local world = make_world({ projectile, target })
    local system = CollisionSystem:new({ x = -100, y = -100, width = 200, height = 200 })
    system:update(world, 0.1)

    assert_true(projectile.dead, 'projectile should be flagged dead after collision')
    assert_true(target.components.health.hp == 16, 'damage should reduce target hp by 4')
    local dispatcher = projectile.components.projectile_events.dispatcher
    assert_true(#dispatcher.emitted == 1 and dispatcher.emitted[1].event == 'hit', 'projectile hit event expected')
    assert_true(effectsLog.impacts > 0, 'impact effect should be spawned')
end

local function test_entity_collision_emits_fx()
    reset_logs()
    local shipA = {
        components = {
            position = { x = 0, y = 0 },
            collidable = { radius = 10 },
        },
    }
    local shipB = {
        components = {
            position = { x = 5, y = 0 },
            collidable = { radius = 10 },
        },
    }

    local world = make_world({ shipA, shipB })
    local system = CollisionSystem:new({ x = -100, y = -100, width = 200, height = 200 })
    system:update(world, 0.1)

    assert_true(collisionEffectsLog.collisions > 0, 'entity collisions should trigger collision effects')
end

local tests = {
    test_projectile_hits_entity,
    test_entity_collision_emits_fx,
}

for index, test in ipairs(tests) do
    test()
    print(string.format('ok %d - %s', index, debug.getinfo(test).name or 'collision test'))
end
