-- Entity-specific renderers
local RenderUtils = require("src.systems.render.utils")
local EnemyStatusBars = require("src.ui.hud.enemy_status_bars")
local Config = require("src.content.config")
local PlayerRenderer = require("src.systems.render.player_renderer")
local Log = require("src.core.log")

local EntityRenderers = {}

-- Remote player renderer (uses player renderer with blue tint)
function EntityRenderers.remote_player(entity, player)
    -- Use the player renderer with remote player modifications
    PlayerRenderer.render(entity)
    
    -- Add visual feedback for remote player
    local size = (entity.components.renderable.props and entity.components.renderable.props.visuals and entity.components.renderable.props.visuals.size) or 1.0
    local S = RenderUtils.createScaler(size)
    
    -- Blue identification overlay
    RenderUtils.setColor({0.3, 0.6, 1.0, 0.15})
    love.graphics.circle("fill", 0, 0, S(30))
    
    -- Boost/warp effect removed
    
    -- Player ID text above the ship
    if entity.playerId then
        local shortId = entity.playerId:sub(-4) -- Last 4 characters
        RenderUtils.setColor({0.7, 0.9, 1.0, 0.9})
        love.graphics.printf(shortId, -25, -40, 50, "center")
        
        -- Connection quality indicator
        local timeSinceUpdate = love.timer.getTime() - (entity.lastNetworkUpdate or 0)
        local pingColor = {0.2, 1.0, 0.2} -- Green for good
        if timeSinceUpdate > 0.1 then pingColor = {1.0, 1.0, 0.2} end -- Yellow for moderate
        if timeSinceUpdate > 0.2 then pingColor = {1.0, 0.2, 0.2} end -- Red for poor
        
        RenderUtils.setColor({pingColor[1], pingColor[2], pingColor[3], 0.6})
        love.graphics.circle("fill", 15, -35, 2)
    end
    
    -- Health bar for remote player
    if entity.components.health then
        local health = entity.components.health.current or 100
        local maxHealth = entity.components.health.max or 100
        local healthPercent = health / maxHealth
        
        if healthPercent < 1.0 then -- Only show if damaged
            local barWidth = S(40)
            local barHeight = S(4)
            local barX = -barWidth / 2
            local barY = S(25)
            
            -- Background
            RenderUtils.setColor({0.2, 0.2, 0.2, 0.8})
            love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
            
            -- Health bar
            local healthColor = {1.0, healthPercent, 0.0} -- Red to yellow to green
            RenderUtils.setColor({healthColor[1], healthColor[2], healthColor[3], 0.9})
            love.graphics.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight)
            
            -- Border
            RenderUtils.setColor({0.8, 0.8, 0.8, 0.6})
            love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
        end
    end
end

-- Enemy renderer
function EntityRenderers.enemy(entity, player)
    local props = entity.components.renderable.props or {}
    local v = props.visuals or {}
    local size = v.size or 1.0
    local S = RenderUtils.createScaler(size)

    local drewBody = false
    if type(v.shapes) == "table" and #v.shapes > 0 then
        for _, shape in ipairs(v.shapes) do
            RenderUtils.drawShape(shape, S)
        end
        drewBody = true
    end

    if not drewBody then
        -- Fallback default drawing
        RenderUtils.setColor({0.35, 0.37, 0.40, 1.0})
        love.graphics.circle("fill", 0, 0, S(10))
        RenderUtils.setColor({0.18, 0.20, 0.22, 1.0})
        love.graphics.circle("line", 0, 0, S(10))
        RenderUtils.setColor({1.0, 0.3, 0.25, 0.85})
        love.graphics.circle("fill", S(3), 0, S(3.2))
    end

    -- Mini shield and health bars (screen-aligned) above enemy
    EnemyStatusBars.drawMiniBars(entity)
end

-- Massive planet renderer (decorative background body)
function EntityRenderers.planet(entity, player)
    local props = entity.components.renderable.props or {}
    local v = props.visuals or {}
    local size = v.size or 1.0
    local S = RenderUtils.createScaler(size)

    -- Visual parameters
    local R = (v.radius or (entity.components.collidable and entity.components.collidable.radius) or 600)
    local baseColor = v.baseColor or {0.10, 0.12, 0.18, 1.0}
    local accentColor = v.accentColor or {0.18, 0.22, 0.32, 1.0}
    local atmosphereColor = v.atmosphereColor or {0.35, 0.75, 1.0, 0.14}
    local showAtmosphere = (v.atmosphere ~= false)
    local highlightColor = v.highlightColor or {1.0, 0.95, 0.85, 0.10}
    local lightDir = v.lightDir or (math.pi * 1.25) -- radians; light from top-left by default

    -- Ring parameters (optional)
    local ringInner = v.ringInner or (R * 1.25)
    local ringOuter = v.ringOuter or (R * 1.8)
    local ringTilt = v.ringTilt or (math.rad(25))
    local ringFlatten = v.ringFlatten or 0.35 -- 1.0 = circle, <1 = thinner ellipse
    local ringColor = v.ringColor or {0.75, 0.70, 0.60, 0.28}
    local ringEdgeColor = v.ringEdgeColor or {0.95, 0.90, 0.80, 0.38}
    local ringLayers = v.ringLayers or 10

    -- Draw ring first so it appears behind the planet body
    if ringOuter and ringInner and ringOuter > ringInner then
        love.graphics.push()
        love.graphics.rotate(ringTilt)
        for i = 0, ringLayers - 1 do
            local t = i / math.max(1, (ringLayers - 1))
            local rr = ringInner + (ringOuter - ringInner) * t
            local a = (ringColor[4] or 0.28) * (0.6 + 0.4 * (1 - math.abs(0.5 - t) * 2))
            love.graphics.setColor(ringColor[1], ringColor[2], ringColor[3], a)
            love.graphics.ellipse('line', 0, 0, S(rr), S(rr * ringFlatten))
        end
        -- Subtle brighter edge
        love.graphics.setColor(ringEdgeColor)
        love.graphics.ellipse('line', 0, 0, S(ringOuter), S(ringOuter * ringFlatten))
        love.graphics.pop()
    end

    -- Body base
    RenderUtils.setColor(baseColor)
    love.graphics.circle('fill', 0, 0, S(R))

    -- Subtle bands/accents to add depth
    RenderUtils.setColor({accentColor[1], accentColor[2], accentColor[3], (accentColor[4] or 1) * 0.6})
    for i = -2, 2 do
        local ry = S(R * (0.72 + i * 0.06))
        local alpha = 0.05 + (0.03 * (2 - math.abs(i)))
        love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], alpha)
        love.graphics.ellipse('fill', 0, 0, S(R * 0.96), ry)
    end

    -- Day-night terminator shading: layered offset circles opposing lightDir
    local layers = 16
    for i = 1, layers do
        local t = i / layers
        local off = S(R * 0.28 * t)
        local ox = -math.cos(lightDir) * off
        local oy = -math.sin(lightDir) * off
        local a = 0.04 * (1.0 - t)
        love.graphics.setColor(0, 0, 0, a)
        love.graphics.circle('fill', ox, oy, S(R * (1.0 - 0.01 * i)))
    end

    -- Highlight rim on the lit side
    do
        local rimR = S(R * 0.98)
        local w = math.max(2, S(R * 0.03))
        local hx = math.cos(lightDir) * S(R * 0.02)
        local hy = math.sin(lightDir) * S(R * 0.02)
        love.graphics.setLineWidth(w)
        love.graphics.setColor(highlightColor)
        love.graphics.circle('line', hx, hy, rimR)
        love.graphics.setLineWidth(1)
    end

    -- Atmosphere glow (optional)
    if showAtmosphere and (atmosphereColor[4] or 0) > 0 then
        local gLayers = 5
        for i = 1, gLayers do
            local t = i / gLayers
            local rr = S(R * (1.02 + t * 0.06))
            local a = (atmosphereColor[4] or 0.14) * (1.1 - t)
            love.graphics.setColor(atmosphereColor[1], atmosphereColor[2], atmosphereColor[3], a)
            love.graphics.circle('line', 0, 0, rr)
        end
    end
end

-- Item pickup renderer (small stone icon surrogate)
function EntityRenderers.item_pickup(entity, player)
    local props = entity.components.renderable.props or {}
    local s = (props.sizeScale or 0.7) * 1.0
    local wob = math.sin(love.timer.getTime() * 6 + (entity.id or 0)) * 1.2
    local size = 6 * s
    -- Core rock
    love.graphics.setColor(0.55, 0.55, 0.55, 0.95)
    love.graphics.polygon('fill', -size, -size*0.2, -size*0.2, -size*0.8, size, -size*0.2, size*0.6, size*0.8, -size*0.6, size*0.6)
    -- Outline
    love.graphics.setColor(0.25, 0.25, 0.25, 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.polygon('line', -size, -size*0.2, -size*0.2, -size*0.8, size, -size*0.2, size*0.6, size*0.8, -size*0.6, size*0.6)
    -- Tiny wobble highlight
    love.graphics.setColor(0.72, 0.72, 0.72, 0.7)
    love.graphics.circle('fill', -size*0.2 + wob*0.1, -size*0.4 + wob*0.1, 1.2*s)
end

-- Asteroid renderer
function EntityRenderers.asteroid(entity, player)
    local props = entity.components.renderable.props or {}
    local v = props.visuals or {}
    local colors = v.colors or {}
    local vertices = props.vertices
    
    -- Check if this asteroid is being hovered (cursor within range and has resources)
    local isHovered = false
    local canMine = false
    if player and entity.components and entity.components.mineable then
        local m = entity.components.mineable
        if (m.resources or 0) > 0 then
            canMine = true
            -- Check if cursor is hovering over this asteroid
            if player.cursorWorldPos then
                local ax, ay = entity.components.position.x, entity.components.position.y
                local cx, cy = player.cursorWorldPos.x, player.cursorWorldPos.y
                local dx, dy = cx - ax, cy - ay
                local dist = math.sqrt(dx*dx + dy*dy)
                local hoverRadius = (entity.components.collidable and entity.components.collidable.radius or 30) + 10
                isHovered = (dist <= hoverRadius)
            end
        end
    end
    
    if vertices and #vertices > 0 then
        -- Get color from content based on asteroid size/type
        local fillColor = colors[props.size] or colors.medium or {0.4, 0.4, 0.45, 1.0}
        local outlineColor = colors.outline or {0.2, 0.2, 0.2, 1.0}
        
        -- No hover-based color changes; rely on active beam effects only
        
        RenderUtils.setColor(fillColor)
        
        -- Unpack the nested vertex table for Love2D's polygon function
        local flatVertices = {}
        for _, vertex in ipairs(vertices) do
            table.insert(flatVertices, vertex[1])
            table.insert(flatVertices, vertex[2])
        end
        
        love.graphics.polygon("fill", flatVertices)
        RenderUtils.setColor(outlineColor)
        love.graphics.polygon("line", flatVertices)
        
        -- No hover glow ring; visible effects only when laser is cutting

        -- Draw break-line cracks indicating overall mining progress
        local m = entity.components and entity.components.mineable
        if m then
            -- Use durability-based progress for cracks visibility
            local dTotal = math.max(0.001, m.durability or 5.0)
            local dProg = math.max(0, m._durabilityProgress or 0)
            local progress = math.max(0, math.min(1, dProg / dTotal))
            if progress > 0 then
                local r = (entity.components and entity.components.collidable and entity.components.collidable.radius) or 30
                local cracks = math.floor(1 + progress * 4)
                local baseAlpha = 0.2 + 0.6 * progress
                love.graphics.setLineWidth(0.8 + progress * 0.7)
                
                -- Generate procedural crack patterns that grow from center outward
                for i=1,cracks do
                    -- Use entity id as base seed for consistency across frames
                    local baseSeed = (entity.id or 0) * 73 + i * 127
                    
                    -- All cracks start from the exact center (impact point)
                    local sx, sy = 0, 0
                    
                    -- Generate main crack direction with random angle
                    local mainAngle = ((baseSeed % 360) / 360) * math.pi * 2
                    -- Cracks reach the edge by 70% progress, ensuring they hit the edge before destruction
                    local minLength = r * 0.5 * math.min(1, progress / 0.7) -- Reach edge at 70% progress
                    local maxLength = r * 0.9 * math.min(1, progress / 0.7) -- Almost to edge at 70%
                    local mainLength = minLength + ((baseSeed % 47) / 47) * (maxLength - minLength)
                    
                    -- Create natural zigzag path from center to edge
                    local segments = 3 + math.floor(progress * 2) -- More segments as damage increases
                    local segmentLength = mainLength / segments
                    local currentX, currentY = sx, sy
                    local currentAngle = mainAngle
                    
                    -- Draw main crack with mining laser color (golden/orange)
                    local crackAlpha = baseAlpha * (0.8 + ((baseSeed % 13) / 13) * 0.2)
                    love.graphics.setColor(1.0, 0.8, 0.2, crackAlpha)
                    
                    for seg = 1, segments do
                        -- Add random deviation to each segment
                        local deviation = ((baseSeed * seg % 61) - 30) * 0.3 / 180 * math.pi
                        currentAngle = currentAngle + deviation
                        
                        local nextX = currentX + math.cos(currentAngle) * segmentLength
                        local nextY = currentY + math.sin(currentAngle) * segmentLength
                        
                        love.graphics.line(currentX, currentY, nextX, nextY)
                        
                        -- Add random branches from this segment (less frequent for cleaner look)
                        if progress > 0.5 and seg > 1 and ((baseSeed * seg) % 100) < (progress * 20) then
                            local branchSeed = baseSeed * seg * 17
                            local branchAngle = currentAngle + (((branchSeed % 121) - 60) * 1.5 / 180 * math.pi)
                            local branchLength = segmentLength * (0.4 + ((branchSeed % 19) / 19) * 0.6)
                            
                            local branchX = currentX + math.cos(branchAngle) * branchLength
                            local branchY = currentY + math.sin(branchAngle) * branchLength
                            
                            love.graphics.setColor(1.0, 0.8, 0.2, crackAlpha * 0.7)
                            love.graphics.line(currentX, currentY, branchX, branchY)
                            
                            -- Occasional sub-branches
                            if progress > 0.6 and ((branchSeed % 100) < 25) then
                                local subAngle = branchAngle + (((branchSeed % 31) - 15) * 2 / 180 * math.pi)
                                local subLength = branchLength * 0.5
                                local subX = branchX + math.cos(subAngle) * subLength
                                local subY = branchY + math.sin(subAngle) * subLength
                                
                                love.graphics.setColor(1.0, 0.8, 0.2, crackAlpha * 0.5)
                                love.graphics.line(branchX, branchY, subX, subY)
                            end
                        end
                        
                        currentX, currentY = nextX, nextY
                        love.graphics.setColor(1.0, 0.8, 0.2, crackAlpha) -- Reset color for main crack
                    end
                end
                love.graphics.setLineWidth(1)
            end
        end
    end
end

-- Simple clean station renderer
function EntityRenderers.station(entity, player)
    local props = entity.components.renderable.props or {}
    local v = props.visuals or {}
    local size = v.size or 1.0
    local S = RenderUtils.createScaler(size)
    
    -- Calculate actual station bounds
    local stationRadius = 0
    
    if type(v.shapes) == "table" and #v.shapes > 0 then
        -- Draw the detailed shapes from content definition
        for _, shape in ipairs(v.shapes) do
            RenderUtils.drawShape(shape, S)
            
            -- Calculate bounds for each shape
            if shape.type == "circle" then
                local shapeRadius = S(shape.r) + math.sqrt((shape.x or 0)^2 + (shape.y or 0)^2)
                stationRadius = math.max(stationRadius, shapeRadius)
            elseif shape.type == "rectangle" then
                local x, y, w, h = S(shape.x or 0), S(shape.y or 0), S(shape.w or 0), S(shape.h or 0)
                local corners = {
                    math.sqrt((x)^2 + (y)^2),
                    math.sqrt((x + w)^2 + (y)^2),
                    math.sqrt((x)^2 + (y + h)^2),
                    math.sqrt((x + w)^2 + (y + h)^2)
                }
                for _, corner in ipairs(corners) do
                    stationRadius = math.max(stationRadius, corner)
                end
            end
        end
    else
        -- Simple fallback station design
        local R = entity.radius or 200
        stationRadius = S(R * 0.8)
        
        -- Main station body
        RenderUtils.setColor({0.85, 0.88, 0.90, 0.2})
        love.graphics.circle("fill", 0, 0, stationRadius)
        
        -- Inner core
        RenderUtils.setColor({0.92, 0.94, 0.96, 0.4})
        love.graphics.circle("fill", 0, 0, S(R * 0.3))
        
        -- Station outline
        RenderUtils.setColor({0.85, 0.88, 0.90, 0.8})
        love.graphics.setLineWidth(S(2))
        love.graphics.circle("line", 0, 0, stationRadius)
        love.graphics.setLineWidth(1)
    end

    -- Show weapon disable ring only when player is inside the actual ring bounds
    if player and entity.components and entity.components.position then
        local stationPos = entity.components.position
        local playerPos = player.components and player.components.position
        
        if playerPos then
            local dx = playerPos.x - stationPos.x
            local dy = playerPos.y - stationPos.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            -- Calculate the ring radius first - use shield radius
            local ringRadius = entity.shieldRadius or 600
            
            -- Show ring when player is approaching or inside the station zone
            if distance <= ringRadius * 1.5 then  -- Show when within 1.5x the radius
                local alpha = distance <= ringRadius and 0.6 or 0.3  -- Brighter when inside
                love.graphics.setColor(1.0, 0.5, 0.0, alpha)
                love.graphics.setLineWidth(3)
                love.graphics.circle('line', 0, 0, ringRadius)
                love.graphics.setLineWidth(1)
            end
        end
    end
end

-- Wreckage renderer
function EntityRenderers.wreckage(entity, player)
    local props = entity.components.renderable.props or {}
    local ttl = (entity.components.timed_life and entity.components.timed_life.timer) or 1
    local alpha = math.max(0.2, math.min(1.0, ttl / 2.0))
    local frags = props.fragments
    
    -- Check if this wreckage is being hovered (cursor within range and can salvage)
    local isHovered = false
    local canSalvage = false
    if player and entity then
        local canSalvageCheck = (entity.canBeSalvaged and entity:canBeSalvaged())
          or (entity.salvageAmount and entity.salvageAmount > 0)
          or (entity.components and entity.components.lootable and #entity.components.lootable.drops > 0)
        if canSalvageCheck then
            canSalvage = true
            -- Check if cursor is hovering over this wreckage
            if player.cursorWorldPos then
                local wx, wy = entity.components.position.x, entity.components.position.y
                local cx, cy = player.cursorWorldPos.x, player.cursorWorldPos.y
                local dx, dy = cx - wx, cy - wy
                local dist = math.sqrt(dx*dx + dy*dy)
                local hoverRadius = (entity.components.collidable and entity.components.collidable.radius or 20) + 8
                isHovered = (dist <= hoverRadius)
            end
        end
    end
    
    if type(frags) == "table" and #frags > 0 then
        for _, s in ipairs(frags) do
            if s.type == 'polygon' and s.points then
                local a = ((type(s.color)=="table" and (s.color[4] or 1)) or 1) * alpha
                RenderUtils.setColor(s.color, a)
                love.graphics.polygon(s.mode or 'fill', s.points)
            elseif (s.type == 'rect' or s.type == 'rectangle') then
                local a = ((type(s.color)=="table" and (s.color[4] or 1)) or 1) * alpha
                RenderUtils.setColor(s.color, a)
                love.graphics.rectangle(s.mode or 'fill', s.x or -4, s.y or -4, s.w or 8, s.h or 8, s.rx or 1, s.ry or s.rx or 1)
            elseif s.type == 'circle' then
                local a = ((type(s.color)=="table" and (s.color[4] or 1)) or 1) * alpha
                RenderUtils.setColor(s.color, a)
                love.graphics.circle(s.mode or 'fill', s.x or 0, s.y or 0, s.r or 3)
            elseif s.type == 'line' and s.points then
                local a = ((type(s.color)=="table" and (s.color[4] or 1)) or 1) * alpha
                RenderUtils.setColor(s.color, a)
                love.graphics.line(s.points)
            end
        end
    else
        local size = (props.size or 1.0) * 6
        love.graphics.setColor(0.42, 0.45, 0.50, 0.7 * alpha)
        love.graphics.rectangle('fill', -size/2, -size/2, size, size, 2, 2)
        love.graphics.setColor(0.20, 0.22, 0.26, 0.6 * alpha)
        love.graphics.rectangle('line', -size/2, -size/2, size, size, 2, 2)
    end
    
    -- Remove hover glow for wreckage to match new system
    if false and isHovered and canSalvage then
        if type(frags) == "table" and #frags > 0 then
            -- Draw glow outline following the actual fragment shapes
            for _, s in ipairs(frags) do
                if s.type == 'polygon' and s.points then
                    -- Outer glow
                    RenderUtils.setColor({0.2, 1.0, 0.3, 0.3})
                    love.graphics.setLineWidth(4)
                    love.graphics.polygon("line", s.points)
                    -- Inner glow
                    RenderUtils.setColor({0.2, 1.0, 0.3, 0.15})
                    love.graphics.setLineWidth(2)
                    love.graphics.polygon("line", s.points)
                elseif (s.type == 'rect' or s.type == 'rectangle') then
                    -- Rectangle glow
                    RenderUtils.setColor({0.2, 1.0, 0.3, 0.3})
                    love.graphics.setLineWidth(3)
                    love.graphics.rectangle("line", s.x or -4, s.y or -4, s.w or 8, s.h or 8, s.rx or 1, s.ry or s.rx or 1)
                elseif s.type == 'circle' then
                    -- Circle glow
                    RenderUtils.setColor({0.2, 1.0, 0.3, 0.3})
                    love.graphics.setLineWidth(3)
                    love.graphics.circle("line", s.x or 0, s.y or 0, (s.r or 3) + 2)
                end
            end
        else
            -- Fallback for wreckage without fragments - use rectangle glow
            local size = (props.size or 1.0) * 6
            RenderUtils.setColor({0.2, 1.0, 0.3, 0.3})
            love.graphics.setLineWidth(3)
            love.graphics.rectangle('line', -size/2 - 2, -size/2 - 2, size + 4, size + 4, 3, 3)
        end
        love.graphics.setLineWidth(1)
    end
end

-- Bullet/projectile renderer
function EntityRenderers.bullet(entity, player)
    local props = entity.components.renderable.props or {}
    local kind = props.kind
    -- (Debug removed) render-time projectile logging was removed for clean build

    if kind == 'laser' or kind == 'salvaging_laser' or kind == 'mining_laser' then
        -- Draw along +X in local space; outer renderer applies rotation.
        local len = props.length or props.maxLength or 800
        local baseColor, baseWidth
        
        -- Type-specific colors for charged pulse system
        if kind == 'salvaging_laser' then
            baseColor = props.color or {0.2, 1.0, 0.3, 0.8} -- Green
            baseWidth = props.tracerWidth or 2.0
        elseif kind == 'mining_laser' then
            baseColor = props.color or {1.0, 0.7, 0.2, 0.8} -- Orange
            baseWidth = props.tracerWidth or 2.0
        else
            baseColor = props.color or {0.3, 0.7, 1.0, 0.8} -- Blue (combat)
            baseWidth = props.tracerWidth or 1.5
        end
        
        -- Charged pulse effect system: buildup + flash then disappear
        local tl = entity.components.timed_life
        local totalLife = (tl and tl.life) or 0.15
        local timeLeft = (tl and tl.timer) or totalLife
        local elapsed = totalLife - timeLeft
        
        -- Phase timing
        local buildupTime = 0.1
        local flashTime = 0.05
        
        local phase, phaseProgress, alpha, coreW, glowW
        
        if elapsed <= buildupTime then
            -- BUILDUP PHASE: Energy charging
            phase = "buildup"
            phaseProgress = elapsed / buildupTime
            local intensity = phaseProgress * phaseProgress -- Quadratic buildup
            alpha = (baseColor[4] or 1) * (0.3 + 0.7 * intensity)
            coreW = baseWidth * (0.1 + 0.4 * intensity) -- Thinner beam
            glowW = coreW + 3 * intensity -- Less glow
        elseif elapsed <= buildupTime + flashTime then
            -- FLASH PHASE: Intense beam release
            phase = "flash"
            phaseProgress = (elapsed - buildupTime) / flashTime
            alpha = (baseColor[4] or 1) * (2.0 + 0.5 * math.sin(phaseProgress * math.pi * 8)) -- Flickering intensity
            coreW = baseWidth * (0.8 + 0.3 * math.sin(phaseProgress * math.pi * 12)) -- Thinner core
            glowW = coreW + 4 + 2 * math.sin(phaseProgress * math.pi * 6) -- Less glow
        else
            -- POST-FLASH: Immediate disappear (render nothing)
            phase = "done"
            alpha = 0
            coreW = 0
            glowW = 0
        end

        if love.graphics.setLineStyle then love.graphics.setLineStyle('smooth') end

        -- Skip rendering if laser is done
        if phase == "done" then
            return
        end
        
        -- Charged pulse rendering: buildup + intense flash
        local time = love.timer.getTime()
        
        if phase == "buildup" then
            -- BUILDUP: Growing energy effect with particles
            love.graphics.setLineWidth(glowW)
            RenderUtils.setColor({baseColor[1], baseColor[2], baseColor[3], alpha * 0.3})
            love.graphics.line(0, 0, len * phaseProgress, 0)
            
            -- Energy particles building up along beam path
            for i = 1, math.floor(8 * phaseProgress) do
                local px = (len * phaseProgress) * (i / 8) + math.sin(time * 12 + i) * 3
                local py = math.cos(time * 10 + i * 2) * (3 * phaseProgress)
                love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], alpha * 0.9)
                love.graphics.circle("fill", px, py, 1.5 + phaseProgress * 0.5)
            end
            
            -- Charging glow at muzzle
            RenderUtils.setColor({baseColor[1], baseColor[2], baseColor[3], alpha * 0.6})
            love.graphics.circle("fill", 0, 0, 2 + 4 * phaseProgress)
            
        else
            -- FLASH: Massive intense beam discharge
            -- Outer glow
            love.graphics.setLineWidth(glowW)
            RenderUtils.setColor({baseColor[1], baseColor[2], baseColor[3], alpha * 0.5})
            love.graphics.line(0, 0, len, 0)
            
            -- Core beam - brighter and wider
            love.graphics.setLineWidth(coreW)
            RenderUtils.setColor({math.min(1, baseColor[1] + 0.4), math.min(1, baseColor[2] + 0.4), math.min(1, baseColor[3] + 0.4), alpha})
            love.graphics.line(0, 0, len, 0)
            
            -- Intense muzzle flash
            RenderUtils.setColor({math.min(1, baseColor[1] + 0.5), math.min(1, baseColor[2] + 0.5), math.min(1, baseColor[3] + 0.5), alpha * 0.8})
            love.graphics.circle("fill", 0, 0, 6 + math.sin(phaseProgress * math.pi * 20) * 2)
            
            -- Energy burst particles
            for i = 1, 6 do
                local burstAngle = (i / 6) * math.pi * 2 + phaseProgress * math.pi
                local burstDist = 8 + math.sin(phaseProgress * math.pi * 15 + i) * 3
                local bx = math.cos(burstAngle) * burstDist
                local by = math.sin(burstAngle) * burstDist
                love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], alpha * 0.7)
                love.graphics.circle("fill", bx, by, 1 + math.sin(phaseProgress * math.pi * 10 + i) * 0.5)
            end
        end

        love.graphics.setLineWidth(1)
        if love.graphics.setLineStyle then love.graphics.setLineStyle('rough') end
    else
        local color = props.color or {1, 1, 1, 1}
        local radius = props.radius or 2
        
        RenderUtils.setColor(color)
        love.graphics.circle("fill", 0, 0, radius)
    end
end

-- Loot container renderer
function EntityRenderers.lootContainer(entity, player)
    local r = (entity.components.collidable and entity.components.collidable.radius) or 18
    
    -- Check if player is hovering and can interact
    local isHovered = false
    local canInteract = false
    local playerDistance = math.huge
    
    if player and player.cursorWorldPos and entity.components.position then
        local cx, cy = player.cursorWorldPos.x, player.cursorWorldPos.y
        local ex, ey = entity.components.position.x, entity.components.position.y
        local dx, dy = cx - ex, cy - ey
        local cursorDist = math.sqrt(dx*dx + dy*dy)
        isHovered = (cursorDist <= r)
        
        -- Check player distance for interaction
        if player.components and player.components.position then
            local px, py = player.components.position.x, player.components.position.y
            local pdx, pdy = px - ex, py - ey
            playerDistance = math.sqrt(pdx*pdx + pdy*pdy)
            canInteract = (playerDistance <= 100)
        end
    end
    
    love.graphics.push()
    love.graphics.rotate(0.785) -- 45 degrees

    -- Main body (brighter when hovered)
    local bodyColor = isHovered and {0.4, 0.4, 0.45} or {0.3, 0.3, 0.35}
    RenderUtils.setColor(bodyColor)
    love.graphics.rectangle("fill", -r, -r, r * 2, r * 2)

    -- Border (golden when hovered and can interact, blue when just hovered)
    local borderColor = {0.2, 0.2, 0.25}
    if isHovered then
        if canInteract then
            borderColor = {0.8, 0.6, 0.2} -- Gold when can interact
        else
            borderColor = {0.4, 0.6, 0.8} -- Blue when too far
        end
    end
    RenderUtils.setColor(borderColor)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", -r, -r, r * 2, r * 2)

    -- Metal plate effect
    RenderUtils.setColor({0.25, 0.25, 0.3})
    love.graphics.rectangle("line", -r + 3, -r + 3, r * 2 - 6, r * 2 - 6)
    
    -- Corner rivets
    RenderUtils.setColor({0.1, 0.1, 0.15})
    love.graphics.circle("fill", -r + 4, -r + 4, 2)
    love.graphics.circle("fill", r - 4, -r + 4, 2)
    love.graphics.circle("fill", -r + 4, r - 4, 2)
    love.graphics.circle("fill", r - 4, r - 4, 2)

    love.graphics.pop()
    love.graphics.setLineWidth(1)
    
    -- Add glow effect when hovered
    if isHovered then
        local glowColor = canInteract and {0.8, 0.6, 0.2, 0.3} or {0.4, 0.6, 0.8, 0.3}
        RenderUtils.setColor(glowColor)
        love.graphics.circle("fill", 0, 0, r + 8)
        
        -- Outer glow ring
        local ringColor = canInteract and {0.8, 0.6, 0.2, 0.5} or {0.4, 0.6, 0.8, 0.5}
        RenderUtils.setColor(ringColor)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", 0, 0, r + 6)
        love.graphics.setLineWidth(1)
    end
    
    -- Helper text above the container
    if isHovered then
        local text = canInteract and "Click to open" or string.format("Move closer (%.0fm)", playerDistance - 100)
        local textColor = canInteract and {0.9, 0.7, 0.3, 1.0} or {0.6, 0.8, 1.0, 1.0}
        
        -- Set small font if available
        local oldFont = love.graphics.getFont()
        local Theme = require("src.core.theme")
        if Theme.fonts and Theme.fonts.small then 
            love.graphics.setFont(Theme.fonts.small) 
        end
        
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(text)
        local textHeight = font:getHeight()
        local textX = -textWidth / 2
        local textY = -r - textHeight - 10
        
        -- Text background
        RenderUtils.setColor({0, 0, 0, 0.7})
        love.graphics.rectangle("fill", textX - 4, textY - 2, textWidth + 8, textHeight + 4, 2, 2)
        
        -- Text
        RenderUtils.setColor(textColor)
        love.graphics.print(text, textX, textY)
        
        if oldFont then love.graphics.setFont(oldFont) end
    end
end

-- Warp Gate renderer - Unique hexagonal portal design
function EntityRenderers.warp_gate(entity, player)
    local warpGate = entity.components.warp_gate
    local visual = warpGate and warpGate:getVisualProperties() or {}

    local isActive = visual.isActive ~= false
    local glowIntensity = visual.glowIntensity or 0.5
    local rotation = visual.rotation or 0
    local powerLevel = visual.powerLevel or 100
    local maxPowerLevel = visual.maxPowerLevel or 100

    -- Save current graphics state
    local r, g, b, a = love.graphics.getColor()
    local lineWidth = love.graphics.getLineWidth()

    -- Unique hexagonal portal design
    -- Derive radii from the gate's actual interaction range so visuals match gameplay
    local baseR = (entity.components and entity.components.warp_gate and entity.components.warp_gate.interactionRange) or 500
    local outerRadius = baseR
    local middleRadius = math.max(50, math.floor(baseR * 0.7))
    local innerRadius = math.max(30, math.floor(baseR * 0.4))

    -- Create hexagon vertices
    local function createHexagon(radius, offsetAngle)
        local vertices = {}
        for i = 0, 5 do
            local angle = (i / 6) * math.pi * 2 + (offsetAngle or 0)
            table.insert(vertices, math.cos(angle) * radius)
            table.insert(vertices, math.sin(angle) * radius)
        end
        return vertices
    end

    love.graphics.push()
    love.graphics.rotate(rotation * 0.3)

    -- Outer hexagonal frame (structural)
    local outerHex = createHexagon(outerRadius, 0)
    if isActive then
        -- Glowing outer frame
        RenderUtils.setColor({0.1, 0.5, 1.0, 0.8 + glowIntensity * 0.2})
        love.graphics.setLineWidth(6)
        love.graphics.polygon("line", outerHex)

        -- Inner glow effect
        RenderUtils.setColor({0.3, 0.7, 1.0, 0.4 + glowIntensity * 0.3})
        love.graphics.setLineWidth(3)
        love.graphics.polygon("line", outerHex)

        -- Corner nodes/connectors
        for i = 0, 5 do
            local angle = (i / 6) * math.pi * 2
            local x = math.cos(angle) * outerRadius
            local y = math.sin(angle) * outerRadius

            -- Pulsing corner nodes
            local nodeAlpha = 0.6 + glowIntensity * 0.4
            RenderUtils.setColor({0.5, 0.9, 1.0, nodeAlpha})
            love.graphics.circle("fill", x, y, 4)

            -- Node glow
            RenderUtils.setColor({0.7, 1.0, 1.0, nodeAlpha * 0.5})
            love.graphics.circle("fill", x, y, 6)
        end
    else
        -- Inactive outer frame
        RenderUtils.setColor({0.3, 0.3, 0.3, 0.6})
        love.graphics.setLineWidth(4)
        love.graphics.polygon("line", outerHex)
    end

    love.graphics.pop()

    -- Middle rotating energy ring
    love.graphics.push()
    love.graphics.rotate(-rotation * 0.8) -- Faster counter-rotation

    local middleHex = createHexagon(middleRadius, math.pi / 6) -- Offset by 30 degrees

    if isActive then
        -- Energy field hexagon
        RenderUtils.setColor({0.4, 0.8, 1.0, 0.5 + glowIntensity * 0.3})
        love.graphics.setLineWidth(3)
        love.graphics.polygon("line", middleHex)

        -- Energy traces between vertices
        RenderUtils.setColor({0.6, 1.0, 1.0, 0.3 + glowIntensity * 0.4})
        love.graphics.setLineWidth(1)
        for i = 0, 5 do
            local angle1 = (i / 6) * math.pi * 2 + math.pi / 6
            local angle2 = ((i + 2) / 6) * math.pi * 2 + math.pi / 6 -- Skip one vertex
            local x1 = math.cos(angle1) * middleRadius
            local y1 = math.sin(angle1) * middleRadius
            local x2 = math.cos(angle2) * middleRadius
            local y2 = math.sin(angle2) * middleRadius
            love.graphics.line(x1, y1, x2, y2)
        end
    end

    love.graphics.pop()

    -- Inner warp core - diamond/star shape
    love.graphics.push()
    love.graphics.rotate(rotation * 1.2) -- Fast rotation

    if isActive then
        -- Core diamond/star
        local coreColor = {0.7, 0.95, 1.0}
        local coreAlpha = 0.6 + glowIntensity * 0.4

        -- Create diamond shape
        local diamond = {
            0, -innerRadius,
            innerRadius * 0.7, 0,
            0, innerRadius,
            -innerRadius * 0.7, 0
        }

        -- Filled diamond core
        RenderUtils.setColor({coreColor[1], coreColor[2], coreColor[3], coreAlpha * 0.4})
        love.graphics.polygon("fill", diamond)

        -- Diamond outline
        RenderUtils.setColor({coreColor[1], coreColor[2], coreColor[3], coreAlpha})
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", diamond)

        -- Central star burst
        RenderUtils.setColor({1.0, 1.0, 1.0, coreAlpha * 0.9})
        love.graphics.setLineWidth(1)
        for i = 0, 7 do
            local angle = (i / 8) * math.pi * 2
            local x = math.cos(angle) * (innerRadius * 0.4)
            local y = math.sin(angle) * (innerRadius * 0.4)
            love.graphics.line(0, 0, x, y)
        end

        -- Central bright core
        RenderUtils.setColor({1.0, 1.0, 1.0, coreAlpha})
        love.graphics.circle("fill", 0, 0, 3)
    else
        -- Inactive core
        RenderUtils.setColor({0.2, 0.2, 0.2, 0.6})
        love.graphics.circle("fill", 0, 0, innerRadius)
        RenderUtils.setColor({0.1, 0.1, 0.1, 0.8})
        love.graphics.circle("line", 0, 0, innerRadius)
    end

    love.graphics.pop()

    -- Unique warp effect particles
    if isActive and visual.particles then
        for _, particle in ipairs(visual.particles) do
            if particle.alpha > 0 then
                -- Hexagonal particle shapes instead of circles
                local size = particle.size
                local particleHex = createHexagon(size, rotation)

                -- Translate to particle position
                love.graphics.push()
                love.graphics.translate(particle.x, particle.y)

                RenderUtils.setColor({0.8, 1.0, 1.0, particle.alpha * 0.6})
                love.graphics.setLineWidth(1)
                love.graphics.polygon("line", particleHex)

                love.graphics.pop()
            end
        end
    end

    -- Iconic warp symbol overlay (when active)
    if isActive then
        local symbolAlpha = 0.3 + glowIntensity * 0.3
        RenderUtils.setColor({0.9, 1.0, 1.0, symbolAlpha})
        love.graphics.setLineWidth(2)

        -- Draw warp "W" symbol
        local symbolSize = 8
        love.graphics.line(-symbolSize, -symbolSize/2, -symbolSize/2, symbolSize/2)
        love.graphics.line(-symbolSize/2, symbolSize/2, 0, -symbolSize/2)
        love.graphics.line(0, -symbolSize/2, symbolSize/2, symbolSize/2)
        love.graphics.line(symbolSize/2, symbolSize/2, symbolSize, -symbolSize/2)
    end

    -- Power level indicator (if applicable)
    if entity.components.warp_gate and entity.components.warp_gate.requiresPower then
        local powerPercent = powerLevel / maxPowerLevel
        local barWidth = 60
        local barHeight = 4
        local barY = outerRadius + 15

        -- Background
        RenderUtils.setColor({0.2, 0.2, 0.2, 0.8})
        love.graphics.rectangle("fill", -barWidth/2, barY, barWidth, barHeight)

        -- Power bar with hexagonal ends
        local powerColor = powerPercent > 0.3 and {0.2, 1.0, 0.2} or {1.0, 0.2, 0.2}
        RenderUtils.setColor({powerColor[1], powerColor[2], powerColor[3], 0.9})
        love.graphics.rectangle("fill", -barWidth/2, barY, barWidth * powerPercent, barHeight)

        -- Hexagonal power indicators at ends
        love.graphics.push()
        love.graphics.translate(-barWidth/2 - 8, barY + barHeight/2)
        local miniHex = createHexagon(3, 0)
        love.graphics.polygon("fill", miniHex)
        love.graphics.pop()

        love.graphics.push()
        love.graphics.translate(barWidth/2 + 8, barY + barHeight/2)
        love.graphics.polygon("fill", miniHex)
        love.graphics.pop()
    end

    -- Interaction hint is now handled by the UI system to respect helper settings

    -- Restore graphics state
    love.graphics.setColor(r, g, b, a)
    love.graphics.setLineWidth(lineWidth)
end

return EntityRenderers
