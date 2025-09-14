-- Projectile Template: The master blueprint for all projectiles.
local Position = require("src.components.position")
local Velocity = require("src.components.velocity")
local Renderable = require("src.components.renderable")
local Collidable = require("src.components.collidable")
local Damage = require("src.components.damage")
local TimedLife = require("src.components.timed_life")
local Log = require("src.core.log")

local Projectile = {}
Projectile.__index = Projectile

local function createProjectilePhysics(entity, args)
    -- Lightweight guidance/kinematics controller for projectiles.
    -- Adjusts velocity (aiming, homing, speed hold). Does not write x/y.
    local comp = {}
    comp.update = function(self, dt)
        -- Beams/lasers are instantaneous traces, skip guidance
        if args.kind == 'laser' then return end
        local pos = entity.components.position
        local vel = entity.components.velocity or { x = 0, y = 0 }
        -- Use the projectile's actual configured speed (passed from template)
        local speed = math.max(1, args.speed)

        -- Maintain constant speed (simple normalization)
        local cvx, cvy = vel.x or 0, vel.y or 0
        local cmag = math.sqrt(cvx*cvx + cvy*cvy)
        if cmag > 1e-6 then
            cvx, cvy = (cvx / cmag) * speed, (cvy / cmag) * speed
        else
            -- Initialize if zero
            cvx, cvy = math.cos(pos.angle or 0) * speed, math.sin(pos.angle or 0) * speed
        end

        -- Guaranteed hit guidance (higher priority than missile homing)
        if args.guaranteedHit and args.guaranteedTarget and not args.guaranteedTarget.dead then
            local tx = (args.guaranteedTarget.components and args.guaranteedTarget.components.position and args.guaranteedTarget.components.position.x) or nil
            local ty = (args.guaranteedTarget.components and args.guaranteedTarget.components.position and args.guaranteedTarget.components.position.y) or nil
            if tx and ty and pos and pos.x and pos.y then
                -- Get target velocity for prediction
                local tvx = (args.guaranteedTarget.components and args.guaranteedTarget.components.velocity and args.guaranteedTarget.components.velocity.x)
                    or (args.guaranteedTarget.components and args.guaranteedTarget.components.physics and args.guaranteedTarget.components.physics.body and args.guaranteedTarget.components.physics.body.vx)
                    or 0
                local tvy = (args.guaranteedTarget.components and args.guaranteedTarget.components.velocity and args.guaranteedTarget.components.velocity.y)
                    or (args.guaranteedTarget.components and args.guaranteedTarget.components.physics and args.guaranteedTarget.components.physics.body and args.guaranteedTarget.components.physics.body.vy)
                    or 0
                
                -- Calculate intercept point accounting for target movement
                local dx, dy = tx - pos.x, ty - pos.y
                local dist = math.max(1, math.sqrt(dx*dx + dy*dy))
                local tLead = dist / speed
                local px, py = tx + tvx * tLead, ty + tvy * tLead
                
                -- Steer directly toward intercept point with high turn rate
                local ddx, ddy = px - pos.x, py - pos.y
                local desiredAngle = math.atan2(ddy, ddx)
                local curAngle = math.atan2(cvy, cvx)
                local diff = (desiredAngle - curAngle + math.pi) % (2*math.pi) - math.pi
                local maxTurn = 10.0 * dt -- Very high turn rate for guaranteed hits
                if diff > maxTurn then diff = maxTurn elseif diff < -maxTurn then diff = -maxTurn end
                local newAngle = curAngle + diff
                cvx, cvy = math.cos(newAngle) * speed, math.sin(newAngle) * speed
            end
        -- Homing guidance for missiles
        elseif args.kind == 'missile' and (args.turnRate or 0) > 0 and args.target and not args.target.dead then
            local tx = (args.target.components and args.target.components.position and args.target.components.position.x) or nil
            local ty = (args.target.components and args.target.components.position and args.target.components.position.y) or nil
            if tx and ty and pos and pos.x and pos.y then
                local tvx = (args.target.components and args.target.components.velocity and args.target.components.velocity.x)
                    or (args.target.components and args.target.components.physics and args.target.components.physics.body and args.target.components.physics.body.vx)
                    or 0
                local tvy = (args.target.components and args.target.components.velocity and args.target.components.velocity.y)
                    or (args.target.components and args.target.components.physics and args.target.components.physics.body and args.target.components.physics.body.vy)
                    or 0
                local dx, dy = tx - pos.x, ty - pos.y
                local dist = math.max(1, math.sqrt(dx*dx + dy*dy))
                -- Lead prediction: time ~ distance / missile speed
                local tLead = dist / speed
                local px, py = tx + tvx * tLead, ty + tvy * tLead
                local ddx, ddy = px - pos.x, py - pos.y
                local desiredAngle = math.atan2(ddy, ddx)
                local curAngle = math.atan2(cvy, cvx)
                local diff = (desiredAngle - curAngle + math.pi) % (2*math.pi) - math.pi
                local maxTurn = (args.turnRate or 0) * dt
                if diff > maxTurn then diff = maxTurn elseif diff < -maxTurn then diff = -maxTurn end
                local newAngle = curAngle + diff
                cvx, cvy = math.cos(newAngle) * speed, math.sin(newAngle) * speed
            end
        end

        entity.components.velocity.x = cvx
        entity.components.velocity.y = cvy
    end
    return comp
end

function Projectile.new(x, y, angle, friendly, config)
    local self = setmetatable({}, Projectile)
    self.tag = "bullet" -- Keep tag for compatibility with some legacy checks

    local speed = config.speedOverride or (config.physics and config.physics.speed) or 700
    local vx = math.cos(angle) * speed
    local vy = math.sin(angle) * speed

    self.components = {
        bullet = { 
            source = config.source, -- Track shooter to avoid self-hit
            impact = config.impact  -- Pass impact effects for collision visuals
        },
        position = Position.new({ x = x, y = y, angle = angle }),
        velocity = Velocity.new({ x = vx, y = vy }),
        collidable = (config.collidable and config.collidable.radius == 0) and nil or Collidable.new({
            radius = (config.collidable and config.collidable.radius) or (config.renderable and config.renderable.props and config.renderable.props.radius) or 2,
            friendly = friendly,
        }),
        renderable = Renderable.new(
            (config.renderable and config.renderable.type) or "bullet",
            (function()
                local props = (config.renderable and config.renderable.props) or {}
                -- Allow callers to override the visual kind (e.g., 'salvaging_laser')
                if config.kind then props.kind = config.kind end
                -- Override visuals if provided
                if config.tracerWidth then props.tracerWidth = config.tracerWidth end
                if config.coreRadius then props.coreRadius = config.coreRadius end
                if config.color then props.color = config.color end
                -- Default bullet color to blue if no color specified and not a laser
                local kind = props.kind or config.kind or 'bullet'
                if not props.color and kind ~= 'laser' and kind ~= 'salvaging_laser' then
                    props.color = {0.35, 0.7, 1.0, 1.0}
                end
                -- Override length/maxLength for all projectile types
                if config.length then props.length = config.length end
                if config.maxLength then props.maxLength = config.maxLength end
                -- Keep a copy of the intended max beam length for lasers (combat), mining, and salvaging beams
                if props.kind == "laser" or props.kind == "salvaging_laser" or props.kind == "mining_laser" then
                    props.maxLength = props.maxLength or props.length
                end
                -- For beam types (laser/mining/salvaging), ensure angle is set in props for collision system/rendering
                if props.kind == "laser" or props.kind == "salvaging_laser" or props.kind == "mining_laser" then
                    props.angle = angle
                end
                return props
            end)()
        ),
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

    -- (Debug removed) laser projectile visual props logging was removed for clean build

    -- Attach lightweight projectile physics for guidance/speed hold
    local kind = (self.components.renderable and self.components.renderable.props and self.components.renderable.props.kind) or 'bullet'
    self.components.physics = createProjectilePhysics(self, {
        kind = kind,
        speed = speed,
        homingStrength = config.homingStrength,
        turnRate = config.turnRate,
        target = config.target,
        guaranteedHit = config.guaranteedHit,
        guaranteedTarget = config.guaranteedTarget,
    })

    return self
end

return Projectile
