local RenderUtils = require("src.systems.render.utils")

local function render(entity, player)
    local props = entity.components.renderable.props or {}
    local v = props.visuals or {}
    local size = v.size or 1.0
    local S = RenderUtils.createScaler(size)

    -- Draw the turret shapes from content definition
    if type(v.shapes) == "table" and #v.shapes > 0 then
        for _, shape in ipairs(v.shapes) do
            -- Check if this is a turret barrel that should rotate
            if shape.turret or shape.type == "rectangle" and (shape.y or 0) < 0 then
                -- This is likely the turret barrel - it will rotate with the entity
                -- The entity's angle is already applied by the dispatcher
                RenderUtils.drawShape(shape, S)
            else
                -- This is the base/platform - draw normally
                RenderUtils.drawShape(shape, S)
            end
        end
    else
        -- Simple fallback turret design
        RenderUtils.setColor({0.2, 0.8, 1.0, 0.8})
        love.graphics.circle("fill", 0, 0, S(16))
        love.graphics.setColor({0.0, 1.0, 1.0, 1.0})
        love.graphics.setLineWidth(S(2))
        love.graphics.circle("line", 0, 0, S(16))
        love.graphics.setLineWidth(1)
        
        -- Simple barrel pointing right (will rotate with entity)
        love.graphics.setColor({0.1, 0.6, 0.9, 0.9})
        love.graphics.rectangle("fill", S(8), S(-2), S(16), S(4))
        love.graphics.setColor({0.0, 1.0, 1.0, 1.0})
        love.graphics.setLineWidth(S(1))
        love.graphics.rectangle("line", S(8), S(-2), S(16), S(4))
        love.graphics.setLineWidth(1)
    end
end

return render
