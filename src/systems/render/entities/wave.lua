local RenderUtils = require("src.systems.render.utils")

local function render(entity, player)
    local props = entity.components.renderable.props or {}
    
    -- Get projectile lifetime for expansion effect
    local tl = entity.components.timed_life
    local totalLife = (tl and tl.life) or 2.0
    local timeLeft = (tl and tl.timer) or totalLife
    local elapsed = totalLife - timeLeft
    local progress = elapsed / totalLife -- 0 to 1
    
    -- Arc parameters
    local baseArcAngle = math.pi * 0.3 -- 54 degrees base arc
    local maxArcAngle = math.pi * 1.4 -- 252 degrees max arc (really wide!)
    local segments = 16
    local baseRadius = 15
    local maxRadius = 60
    
    -- Calculate expanding radius
    local currentRadius = baseRadius + (maxRadius - baseRadius) * progress
    
    -- Calculate expanding arc angle (spreads apart much faster)
    local currentArcAngle = baseArcAngle + (maxArcAngle - baseArcAngle) * (progress * progress * progress) -- Cubic growth for much faster spread
    
    -- Gray color with fade
    local grayAlpha = 0.8 * (1.0 - progress * 0.5) -- Fade to 40% opacity
    local grayColor = {0.5, 0.5, 0.5, grayAlpha}
    
    love.graphics.push()
    
    -- Draw clean arc line without connecting endpoints
    love.graphics.setLineWidth(3)
    RenderUtils.setColor(grayColor)
    
    -- Draw arc as individual line segments to avoid connecting line
    local angleStep = currentArcAngle / segments
    local startAngle = -currentArcAngle/2
    
    for i = 0, segments - 1 do
        local angle1 = startAngle + i * angleStep
        local angle2 = startAngle + (i + 1) * angleStep
        
        local x1 = math.cos(angle1) * currentRadius
        local y1 = math.sin(angle1) * currentRadius
        local x2 = math.cos(angle2) * currentRadius
        local y2 = math.sin(angle2) * currentRadius
        
        love.graphics.line(x1, y1, x2, y2)
    end
    
    love.graphics.pop()
    love.graphics.setLineWidth(1)
end

return render
