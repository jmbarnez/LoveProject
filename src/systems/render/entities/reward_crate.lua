local RenderUtils = require("src.systems.render.utils")

local function render(entity, player)
    local props = entity.components.renderable.props or {}
    local size = props.size or 1.0
    local S = RenderUtils.createScaler(size)
    local radius = props.radius or 25

    -- Ring effects removed for cleaner appearance

    -- Main crate body
    love.graphics.setColor(0.18, 0.2, 0.28, 1.0)
    love.graphics.rectangle('fill', S(-20), S(-15), S(40), S(30), S(4), S(4))

    -- Crate border
    love.graphics.setColor(0.42, 0.46, 0.68, 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', S(-20), S(-15), S(40), S(30), S(4), S(4))

    -- Lock mechanism
    love.graphics.setColor(0.26, 0.3, 0.46, 1.0)
    love.graphics.rectangle('fill', S(-15), S(-5), S(30), S(10))

    -- Golden lock
    love.graphics.setColor(0.95, 0.8, 0.3, 1.0)
    love.graphics.rectangle('fill', S(-5), S(-10), S(10), S(20))


    -- Lock highlight
    love.graphics.setColor(0.98, 0.9, 0.55, 1.0)
    love.graphics.rectangle('fill', S(-5), S(-5), S(10), S(10))

    -- Lock center
    love.graphics.setColor(0.9, 0.6, 0.2, 1.0)
    love.graphics.circle('fill', 0, S(5), S(3))

    love.graphics.setLineWidth(1)
end

return render
