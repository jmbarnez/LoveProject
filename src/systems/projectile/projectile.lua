local Log = require("src.core.log")
local Position = require("src.components.position")
-- Velocity component removed - handled by Windfield physics
local Renderable = require("src.components.renderable")
local Collidable = require("src.components.collidable")
local Damage = require("src.components.damage")
local TimedLife = require("src.components.timed_life")
local Hull = require("src.components.hull")
local Shield = require("src.components.shield")
local Energy = require("src.components.energy")
local WindfieldPhysics = require("src.components.windfield_physics")
local ProjectileComponents = require("src.components.projectile.registry")
local EventDispatcher = require("src.systems.projectile.event_dispatcher")
local EffectManager = require("src.systems.projectile.effect_manager")
local BehaviorManager = require("src.systems.projectile.behavior_manager")
local RendererFactory = require("src.systems.projectile.renderer_factory")
local PluginRegistry = require("src.systems.projectile.plugin_registry")

require("src.systems.projectile.effects.init")
require("src.systems.projectile.plugins.init")
require("src.systems.projectile.behaviors.init")
require("src.systems.projectile.renderers.init")

local Projectile = {}
Projectile.__index = Projectile
local ProjectileEvents = EventDispatcher.EVENTS

local function merge_options(base, overrides)
    if type(base) ~= "table" then
        base = {}
    end

    if type(overrides) ~= "table" then
        return base
    end

    local merged = {}
    for key, value in pairs(base) do
        merged[key] = value
    end

    for key, value in pairs(overrides) do
        if value ~= nil then
            merged[key] = value
        elseif merged[key] == nil then
            merged[key] = value
        end
    end

    return merged
end

function Projectile:addComponent(name, config, options)
    if type(name) ~= "string" or name == "" then
        return nil, false
    end

    options = options or {}
    local force = options.force or options.overwrite
    local existing = self.components[name]

    if existing and not force then
        local sourceLabel = options.source and (" (" .. tostring(options.source) .. ")") or ""
        Log.warn(string.format("Projectile component '%s'%s already exists; skipping attachment", name, sourceLabel))
        return existing, false
    end

    local component, err = ProjectileComponents.create(name, config or {}, {
        projectile = self,
        options = options,
    })

    if not component then
        local sourceLabel = options.source and (" from " .. tostring(options.source)) or ""
        Log.warn(err or string.format("Unable to create projectile component '%s'%s", name, sourceLabel))
        return nil, false
    end

    self.components[name] = component
    return component, true
end

local function normalize_component_definitions(definitions)
    if type(definitions) ~= "table" then
        return {}
    end

    local normalized = {}

    if #definitions > 0 then
        for _, descriptor in ipairs(definitions) do
            if type(descriptor) == "table" then
                normalized[#normalized + 1] = descriptor
            end
        end
    else
        for name, config in pairs(definitions) do
            normalized[#normalized + 1] = {
                name = name,
                config = config,
            }
        end
    end

    return normalized
end

function Projectile:applyComponentDefinitions(definitions, options)
    local normalized = normalize_component_definitions(definitions)
    if #normalized == 0 then
        return
    end

    for _, descriptor in ipairs(normalized) do
        local name = descriptor.name or descriptor.type or descriptor.id
        if type(name) ~= "string" then
            Log.warn("Encountered projectile component descriptor without a valid name")
        elseif descriptor.component or descriptor.instance then
            Log.warn(string.format("Direct projectile component injection for '%s' is no longer supported; register a constructor", name))
        else
            local config = descriptor.config
            if config == nil then
                if descriptor.value ~= nil then
                    if type(descriptor.value) == "table" then
                        config = descriptor.value
                    else
                        config = { value = descriptor.value }
                    end
                elseif descriptor.options ~= nil then
                    config = descriptor.options
                elseif descriptor.args ~= nil then
                    config = descriptor.args
                elseif descriptor.data ~= nil then
                    config = descriptor.data
                end
            end

            local mergedOptions = merge_options(options, {
                force = descriptor.force or descriptor.overwrite,
            })
            mergedOptions = merge_options(mergedOptions, {
                source = mergedOptions and mergedOptions.source or descriptor.source,
            })

            self:addComponent(name, config, mergedOptions)
        end
    end
end

function Projectile.new(x, y, angle, friendly, config)
    local self = setmetatable({}, Projectile)
    self.tag = "bullet" -- Keep tag for compatibility with some legacy checks

    -- Set projectile type for network synchronization
    self.projectileType = config.id or "gun_bullet"

    -- Use provided velocity if available, otherwise calculate from speed and angle
    local vx, vy
    if config.vx and config.vy then
        -- Use the velocity provided by the turret system
        vx = config.vx
        vy = config.vy
        Log.debug("projectile", "Using provided velocity: vx=%.2f, vy=%.2f, angle=%.2f", vx, vy, angle)
    else
        -- Calculate velocity from speed and angle
        local speed = config.speedOverride or (config.physics and config.physics.speed) or 700
        -- Ensure proper direction calculation for Windfield physics
        vx = math.cos(angle) * speed
        vy = math.sin(angle) * speed
        Log.debug("projectile", "Calculated velocity: vx=%.2f, vy=%.2f, angle=%.2f, speed=%.2f", vx, vy, angle, speed)
    end

    self.components = {
        bullet = {
            source = config.source, -- Track shooter to avoid self-hit
            impact = config.impact,  -- Pass impact effects for collision visuals
            slot = config.sourceTurretSlot,
            turretId = config.sourceTurretId,
            turretType = config.sourceTurretType,
            sourcePlayerId = config.sourcePlayerId,
            sourceShipId = config.sourceShipId,
            targetX = config.targetX, -- Target position for bomb-type projectiles
            targetY = config.targetY,
            targetAngle = config.targetAngle,
            kind = config.kind, -- Store projectile kind for collision detection
            speed = config.speedOverride or (config.physics and config.physics.speed) or 700, -- Store the calculated speed for physics system
        },
        position = Position.new({ x = x, y = y, angle = angle }),
        -- Velocity is now handled by Windfield physics system
        collidable = (config.collidable and config.collidable.radius == 0) and nil or Collidable.new({
            radius = (config.collidable and config.collidable.radius) or (config.renderable and config.renderable.props and config.renderable.props.radius) or 2,
            friendly = friendly,
        }),
        renderable = (function()
            local renderableDef = config.renderable or { type = "bullet", props = {} }
            local overrides = { kind = config.kind, props = {} }
            if config.tracerWidth then overrides.props.tracerWidth = config.tracerWidth end
            if config.coreRadius then overrides.props.coreRadius = config.coreRadius end
            if config.color then overrides.props.color = config.color end
            if config.length then overrides.props.length = config.length end
            if config.maxLength then overrides.props.maxLength = config.maxLength end

            local created = RendererFactory.extend(renderableDef, overrides)
            local props = created.props or {}
            local kind = props.kind or config.kind or 'bullet'
            if not props.color and kind ~= 'laser' and kind ~= 'salvaging_laser' and kind ~= 'mining_laser' then
                props.color = {0.35, 0.7, 1.0, 1.0}
            end
            if kind == "laser" or kind == "salvaging_laser" or kind == "mining_laser" then
                props.angle = angle
                props.maxLength = props.maxLength or props.length
            end
            created.props = props
            return Renderable.new(created.type or "bullet", created.props)
        end)(),
        -- Create Damage component for projectiles. Allow lasers to have damage if provided in config.
        damage = (function()
            local hasDamage = config.damage ~= nil
            if hasDamage then
                local dmgValue = config.damage or 1
                return Damage.new(dmgValue)
            end
            return nil
        end)(),
        timed_life = TimedLife.new(
            (config.timed_life and config.timed_life.duration) or 2.0
        ),
        -- Add Windfield physics component for projectiles
        windfield_physics = WindfieldPhysics.new({
            x = x,
            y = y,
            mass = (function()
                local kind = config.kind or 'bullet'
                if kind == "missile" then return 5
                elseif kind == "laser" or kind == "mining_laser" or kind == "salvaging_laser" then return 0.1
                else return 1 end
            end)(),
            colliderType = "circle",
            bodyType = "dynamic",
            restitution = 0.1,
            friction = 0.0,
            fixedRotation = true,  -- Projectiles don't rotate
            radius = (config.collidable and config.collidable.radius) or (config.renderable and config.renderable.props and config.renderable.props.radius) or 2,
        }),
        -- Add health component only for rockets/missiles
        health = (function()
            local kind = config.kind or 'bullet'
            
            -- Only rockets and missiles get health components
            if kind == "rocket" or kind == "missile" then
                return {
                    hull = Hull.new({
                        hp = 5,
                        maxHP = 5
                    }),
                    shield = Shield.new({
                        shield = 0,
                        maxShield = 0
                    }),
                    energy = Energy.new({
                        energy = 0,
                        maxEnergy = 0
                    })
                }
            end
            
            return nil -- No health component for other projectiles
        end)(),
        -- Add max range tracking
        max_range = (function()
            if config.maxRange and config.maxRange > 0 then
                return {
                    maxDistance = config.maxRange,
                    traveledDistance = 0,
                    startX = x,
                    startY = y,
                    kind = config.kind or 'bullet'
                }
            end
            return nil
        end)(),
    }


    self:applyComponentDefinitions(config.components, { source = "config" })


    local dispatcher = EventDispatcher.new()
    self.event_dispatcher = dispatcher
    self.components.projectile_events = dispatcher:asComponent()

    local effectManager = EffectManager.new(self, dispatcher)
    self.effect_manager = effectManager

    function self:addEffect(effectDefinition)
        return effectManager:addEffect(effectDefinition)
    end


    local pluginContext = {
        projectile = self,
        config = config,
        dispatcher = dispatcher,
        events = dispatcher,
        manager = effectManager,
        addEffect = function(effectDefinition)
            return effectManager:addEffect(effectDefinition)
        end,
    }

    PluginRegistry.apply("default", pluginContext)

    if config.plugin then
        PluginRegistry.apply(config.plugin, pluginContext)
    end

    if config.kind and config.kind ~= config.plugin then
        PluginRegistry.apply(config.kind, pluginContext)
    end

    effectManager:loadConfig(config.effects or {})
    effectManager:loadConfig(config.additionalEffects or {})
    
    -- Load effects from components field (for embedded effects like bomb_explosion)
    if config.components then
        local normalizedComponents = normalize_component_definitions(config.components)
        for _, component in ipairs(normalizedComponents) do
            local effectConfig = component.value or component.effect_config
            if component.effect and effectConfig then
                effectManager:addEffect({
                    type = component.effect,
                    config = effectConfig,
                })
            elseif component.name and component.value then
                effectManager:addEffect({
                    type = component.name,
                    value = component.value,
                })
            end
        end
    end

    local behaviorManager = BehaviorManager.new(self, dispatcher)
    self.behavior_manager = behaviorManager
    self.components.projectile_behavior = behaviorManager:asComponent()

    behaviorManager:loadConfig(config.behaviors or config.behavior or {})

    -- Set up ignore targets for collision detection
    if config.ignoreTargets then
        self._behaviorIgnoreTargets = config.ignoreTargets
    end

    dispatcher:emit(ProjectileEvents.SPAWN, {
        projectile = self,
        config = config,
        world = world,
    })

    -- Set initial damage time so health bars show briefly when projectiles are created
    if love and love.timer and love.timer.getTime then
        self._hudDamageTime = love.timer.getTime()
    else
        self._hudDamageTime = os.clock()
    end

    -- Store initial velocity for Windfield physics system BEFORE adding to physics
    self._initialVelocity = {
        x = vx,
        y = vy,
        angular = 0
    }
    Log.debug("projectile", "Set _initialVelocity: vx=%.2f, vy=%.2f", vx, vy)

    -- Debug: Log projectile velocity
    local Log = require("src.core.log")
    Log.debug("projectile", "Projectile created with velocity: vx=%.2f, vy=%.2f, angle=%.2f", vx, vy, angle)

    -- Add projectile to physics system
    local PhysicsSystem = require("src.systems.physics")
    PhysicsSystem.addEntity(self)

    return self
end

return Projectile
