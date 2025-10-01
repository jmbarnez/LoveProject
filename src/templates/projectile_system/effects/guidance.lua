local EffectRegistry = require("src.templates.projectile_system.effect_registry")

local function create_guidance_component(projectile, args)
    local component = {}

    function component:update(dt)
        if args.kind == 'laser' then return end

        local pos = projectile.components.position
        local vel = projectile.components.velocity or { x = 0, y = 0 }
        local speed = math.max(1, args.speed or math.sqrt((vel.x or 0)^2 + (vel.y or 0)^2))

        local cvx, cvy = vel.x or 0, vel.y or 0
        local cmag = math.sqrt(cvx * cvx + cvy * cvy)
        if cmag > 1e-6 then
            cvx, cvy = (cvx / cmag) * speed, (cvy / cmag) * speed
        else
            local angle = (pos and pos.angle) or 0
            cvx, cvy = math.cos(angle) * speed, math.sin(angle) * speed
        end

        if args.guaranteedHit and args.guaranteedTarget and not args.guaranteedTarget.dead then
            local target = args.guaranteedTarget
            local tx = target.components and target.components.position and target.components.position.x
            local ty = target.components and target.components.position and target.components.position.y
            if tx and ty and pos and pos.x and pos.y then
                local tvx = (target.components and target.components.velocity and target.components.velocity.x)
                    or (target.components and target.components.physics and target.components.physics.body and target.components.physics.body.vx)
                    or 0
                local tvy = (target.components and target.components.velocity and target.components.velocity.y)
                    or (target.components and target.components.physics and target.components.physics.body and target.components.physics.body.vy)
                    or 0

                local dx, dy = tx - pos.x, ty - pos.y
                local dist = math.max(1, math.sqrt(dx * dx + dy * dy))
                local tLead = dist / speed
                local px, py = tx + tvx * tLead, ty + tvy * tLead

                local ddx, ddy = px - pos.x, py - pos.y
                local desiredAngle = math.atan2(ddy, ddx)
                local curAngle = math.atan2(cvy, cvx)
                local diff = (desiredAngle - curAngle + math.pi) % (2 * math.pi) - math.pi
                local maxTurn = 10.0 * dt
                if diff > maxTurn then diff = maxTurn elseif diff < -maxTurn then diff = -maxTurn end
                local newAngle = curAngle + diff
                cvx, cvy = math.cos(newAngle) * speed, math.sin(newAngle) * speed
            end
        elseif args.target and not args.target.dead and args.homingStrength and args.homingStrength > 0 then
            local target = args.target
            local tx = target.components and target.components.position and target.components.position.x
            local ty = target.components and target.components.position and target.components.position.y
            if tx and ty and pos and pos.x and pos.y then
                local tvx = (target.components and target.components.velocity and target.components.velocity.x)
                    or (target.components and target.components.physics and target.components.physics.body and target.components.physics.body.vx)
                    or 0
                local tvy = (target.components and target.components.velocity and target.components.velocity.y)
                    or (target.components and target.components.physics and target.components.physics.body and target.components.physics.body.vy)
                    or 0

                local dx, dy = tx - pos.x, ty - pos.y
                local dist = math.max(1, math.sqrt(dx * dx + dy * dy))
                local tLead = dist / speed
                local px, py = tx + tvx * tLead, ty + tvy * tLead

                local ddx, ddy = px - pos.x, py - pos.y
                local desiredAngle = math.atan2(ddy, ddx)
                local curAngle = math.atan2(cvy, cvx)
                local diff = (desiredAngle - curAngle + math.pi) % (2 * math.pi) - math.pi
                local maxTurn = (args.missileTurnRate or 4.5) * dt
                if diff > maxTurn then diff = maxTurn elseif diff < -maxTurn then diff = -maxTurn end
                local newAngle = curAngle + diff
                cvx, cvy = math.cos(newAngle) * speed, math.sin(newAngle) * speed
            end
        end

        projectile.components.velocity.x = cvx
        projectile.components.velocity.y = cvy
    end

    return component
end

local function factory(context, config)
    local projectile = context.projectile
    local renderable = projectile.components.renderable
    local kind = config.kind
        or (renderable and renderable.props and renderable.props.kind)
        or 'bullet'

    local component = create_guidance_component(projectile, {
        kind = kind,
        speed = config.speed,
        homingStrength = config.homingStrength,
        target = config.target,
        guaranteedHit = config.guaranteedHit,
        guaranteedTarget = config.guaranteedTarget,
        missileTurnRate = config.missileTurnRate,
    })

    return {
        components = {
            {
                name = "physics",
                component = component,
                force = true,
            },
        },
    }
end

EffectRegistry.register("guidance", factory)

return true
