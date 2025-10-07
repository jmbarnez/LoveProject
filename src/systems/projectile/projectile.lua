local Position = require("src.components.position")
local Velocity = require("src.components.velocity")
local Renderable = require("src.components.renderable")
local Collidable = require("src.components.collidable")
local Damage = require("src.components.damage")
local TimedLife = require("src.components.timed_life")
local EventDispatcher = require("src.systems.projectile.event_dispatcher")
local EffectManager = require("src.systems.projectile.effect_manager")
local BehaviorManager = require("src.systems.projectile.behavior_manager")
local RendererFactory = require("src.systems.projectile.renderer_factory")
local PluginRegistry = require("src.systems.projectile.plugin_registry")
local State = require("src.game.state")

require("src.systems.projectile.effects.init")
require("src.systems.projectile.plugins.init")
require("src.systems.projectile.behaviors.init")
require("src.systems.projectile.renderers.init")

local Projectile = {}
Projectile.__index = Projectile
local ProjectileEvents = EventDispatcher.EVENTS

function Projectile.new(x, y, angle, friendly, config)
    local self = setmetatable({}, Projectile)
    self.tag = "bullet" -- Keep tag for compatibility with some legacy checks

    -- Set projectile type for network synchronization
    self.projectileType = config.id or "gun_bullet"

    local speed = config.speedOverride or (config.physics and config.physics.speed) or 700
    local vx = math.cos(angle) * speed
    local vy = math.sin(angle) * speed

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
        },
        position = Position.new({ x = x, y = y, angle = angle }),
        velocity = Velocity.new({ x = vx, y = vy }),
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


    local function attach_custom_components(definitions)
        if type(definitions) ~= "table" then return end

        if #definitions > 0 then
            for _, descriptor in ipairs(definitions) do
                if type(descriptor) == "table" then
                    local name = descriptor.name
                    local component = descriptor.component or descriptor.instance or descriptor.value
                    if type(name) == "string" and component ~= nil then
                        self.components[name] = component
                    end
                end
            end
        else
            for name, component in pairs(definitions) do
                if type(name) == "string" then
                    self.components[name] = component
                end
            end
        end
    end

    attach_custom_components(config.components)


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
        for _, component in ipairs(config.components) do
            if component.name and component.value then
                -- Create effect definition from component
                local effectDef = {
                    type = component.name,
                    value = component.value
                }
                effectManager:addEffect(effectDef)
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
        world = State.world,
    })

    return self
end

return Projectile
