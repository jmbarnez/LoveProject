-- Entity-specific renderers
local RenderUtils = require("src.systems.render.utils")
local util = require("src.core.util")
local EnemyStatusBars = require("src.ui.hud.enemy_status_bars")
local ResourceNodeBars = require("src.ui.hud.resource_node_bars")
local Config = require("src.content.config")
local PlayerRenderer = require("src.systems.render.player_renderer")
local Log = require("src.core.log")
local Content = require("src.content.content")
local DebugPanel = require("src.ui.debug_panel")
local Viewport = require("src.core.viewport")

local EntityRenderers = {}

-- Cached renderer functions for better performance
local cachedRenderers = {}
local rendererCounter = 0

-- This ensures that even when zoomed out all the way, important entities like stations remain visible

-- Cache entity renderer type to avoid repeated component checks
local function getEntityRendererType(entity)
    -- Use a simple counter-based caching system
    if not entity._rendererType then
        if entity.isRemotePlayer then
            entity._rendererType = 'remote_player'
        elseif entity.components.ai then
            entity._rendererType = 'enemy'
        elseif entity.components.warp_gate then
            entity._rendererType = 'warp_gate'
        elseif entity.components.mineable then
            entity._rendererType = 'asteroid'
        elseif entity.isItemPickup or entity.components.item_pickup then
            entity._rendererType = 'item_pickup'
        elseif entity.components.xp_pickup then
            entity._rendererType = 'xp_pickup'
        elseif entity.components.wreckage then
            entity._rendererType = 'wreckage'
        elseif entity.components.lootable and entity.isWreckage then
            entity._rendererType = 'wreckage'
        elseif entity.components.bullet then
            entity._rendererType = 'bullet'
        elseif entity.isStation then
            entity._rendererType = 'station'
        elseif entity.type == "world_object" and entity.subtype == "planet_massive" then
            entity._rendererType = 'planet'
        elseif entity.type == "world_object" and entity.subtype == "reward_crate" then
            entity._rendererType = 'reward_crate'
        elseif entity.components.lootable then
            entity._rendererType = 'lootContainer'
        else
            entity._rendererType = 'fallback'
        end

        -- Reset cache periodically to handle dynamic entity changes
        rendererCounter = rendererCounter + 1
        if rendererCounter > 10000 then
            rendererCounter = 0
            -- Clear all cached types to refresh
            for _, e in pairs(entity) do
                if type(e) == 'table' and e._rendererType then
                    e._rendererType = nil
                end
            end
            -- Actually clear the renderer cache to prevent memory leak
            cachedRenderers = {}
        end
    end
    return entity._rendererType
end

-- Enemy renderer
function EntityRenderers.enemy(entity, player)
    local props = entity.components.renderable.props or {}
    local v = props.visuals or {}
    local size = v.size or 1.0
    local S = RenderUtils.createScaler(size)

    -- Engine trails are drawn from the main renderer in world space

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

    -- Draw detection radius overlay (debug only)
    if entity.components.ai and entity.components.ai.state ~= "dead" and DebugPanel.isVisible() then
        local ai = entity.components.ai
        local detectionRange = ai.detectionRange or 0
        if detectionRange > 0 then
            local engaged = (ai.state == "hunting")
            local primaryColor = engaged and {1.0, 0.35, 0.1, 0.55} or {1.0, 0.85, 0.05, 0.35}
            RenderUtils.setColor(primaryColor)
            love.graphics.setLineWidth(engaged and 1.6 or 1.2)
            love.graphics.circle("line", 0, 0, detectionRange)
            RenderUtils.setColor({primaryColor[1], primaryColor[2], primaryColor[3], 0.18})
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", 0, 0, detectionRange * 0.5)
        end
    end

end

-- Remote player renderer (for multiplayer)
function EntityRenderers.remote_player(entity, player)
    local props = entity.components.renderable.props or {}
    local v = props.visuals or {}
    local size = v.size or 1.0
    local S = RenderUtils.createScaler(size)

    -- Draw ship with a distinct color scheme for remote players
    local drewBody = false
    if type(v.shapes) == "table" and #v.shapes > 0 then
        -- Modify colors to make remote players distinct
        for _, shape in ipairs(v.shapes) do
            local originalColor = shape.color
            if originalColor and type(originalColor) == "table" then
                -- Tint the shape with a greenish color to indicate it's a remote player
                local tintedColor = {
                    math.min(1, originalColor[1] * 0.7 + 0.3), -- More green
                    math.min(1, originalColor[2] * 0.8 + 0.2), -- More green
                    math.min(1, originalColor[3] * 0.6 + 0.4), -- Less blue
                    originalColor[4] or 1
                }
                shape.color = tintedColor
            end
            RenderUtils.drawShape(shape, S)
            -- Restore original color
            if originalColor then
                shape.color = originalColor
            end
        end
        drewBody = true
    end

    if not drewBody then
        -- Fallback default drawing with green tint
        RenderUtils.setColor({0.2, 0.6, 0.3, 1.0}) -- Green tint
        love.graphics.circle("fill", 0, 0, S(10))
        RenderUtils.setColor({0.1, 0.4, 0.2, 1.0}) -- Darker green outline
        love.graphics.circle("line", 0, 0, S(10))
        RenderUtils.setColor({0.4, 0.8, 0.5, 0.85}) -- Light green accent
        love.graphics.circle("fill", S(3), 0, S(3.2))
    end

    -- Draw player name above remote player
    if entity.playerName then
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(entity.playerName)
        local textHeight = font:getHeight()
        
        -- Background for text
        RenderUtils.setColor({0, 0, 0, 0.7})
        love.graphics.rectangle("fill", -textWidth/2 - 2, -S(20) - textHeight - 2, textWidth + 4, textHeight + 4)
        
        -- Text
        RenderUtils.setColor({0.8, 1.0, 0.8, 1.0})
        love.graphics.print(entity.playerName, -textWidth/2, -S(20) - textHeight)
    end

    -- Draw mini health bar for remote players
    if entity.components and entity.components.health then
        local health = entity.components.health
        local hpPercent = health.hp / health.maxHP
        local barWidth = S(20)
        local barHeight = S(3)
        local barY = -S(15)
        
        -- Background
        RenderUtils.setColor({0.2, 0.2, 0.2, 0.8})
        love.graphics.rectangle("fill", -barWidth/2, barY, barWidth, barHeight)
        
        -- Health bar
        local healthColor = hpPercent > 0.5 and {0.2, 0.8, 0.2, 1.0} or 
                           hpPercent > 0.25 and {0.8, 0.8, 0.2, 1.0} or 
                           {0.8, 0.2, 0.2, 1.0}
        RenderUtils.setColor(healthColor)
        love.graphics.rectangle("fill", -barWidth/2, barY, barWidth * hpPercent, barHeight)
        
        -- Border
        RenderUtils.setColor({1, 1, 1, 0.5})
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", -barWidth/2, barY, barWidth, barHeight)
    end
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
            local baseAlpha = (type(ringColor) == "table" and ringColor[4]) or 0.28
            local a = baseAlpha * (0.6 + 0.4 * (1 - math.abs(0.5 - t) * 2))
            love.graphics.setColor(ringColor[1], ringColor[2], ringColor[3], a)
            love.graphics.ellipse('line', 0, 0, S(rr), S(rr * ringFlatten))
        end
        -- Subtle brighter edge
        love.graphics.setColor(ringEdgeColor[1], ringEdgeColor[2], ringEdgeColor[3], ringEdgeColor[4])
        love.graphics.ellipse('line', 0, 0, S(ringOuter), S(ringOuter * ringFlatten))
        love.graphics.pop()
    end

    -- Body base
    RenderUtils.setColor(baseColor)
    love.graphics.circle('fill', 0, 0, S(R))

    -- Subtle bands/accents to add depth
    local accentAlpha = (type(accentColor) == "table" and accentColor[4]) or 1.0
    RenderUtils.setColor({accentColor[1], accentColor[2], accentColor[3], accentAlpha * 0.6})
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
    local atmosphereAlpha = (type(atmosphereColor) == "table" and atmosphereColor[4]) or 0.14
    if showAtmosphere and atmosphereAlpha > 0 then
        local gLayers = 5
        for i = 1, gLayers do
            local t = i / gLayers
            local rr = S(R * (1.02 + t * 0.06))
            local a = atmosphereAlpha * (1.1 - t)
            love.graphics.setColor(atmosphereColor[1], atmosphereColor[2], atmosphereColor[3], a)
            love.graphics.circle('line', 0, 0, rr)
        end
    end
end

-- Reward crate renderer
function EntityRenderers.reward_crate(entity, player)
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

-- Item pickup renderer (simple small icon with name and amount label)
function EntityRenderers.item_pickup(entity, player)
    local props = entity.components.renderable.props or {}
    local itemId = props.itemId or "ore_tritanium"
    local qty = props.qty or 1
    local s = (props.sizeScale or 0.7) * 1.2  -- Slightly smaller than original (reduced from 1.5 to 1.2)

    -- Fetch item or turret definition for correct model
    local itemDef = Content.getItem(itemId) or Content.getTurret(itemId)
    local Theme = require("src.core.theme")
    local oldFont = love.graphics.getFont()
    if Theme.fonts and Theme.fonts.small then
        love.graphics.setFont(Theme.fonts.small)
    end

    -- Ensure consistent white color for no tint during movement
    love.graphics.setColor(1.0, 1.0, 1.0, 1.0)

    if itemDef and itemDef.icon then
        -- Render small icon
        local icon = itemDef.icon
        local iconW, iconH = icon:getDimensions()
        local scale = s * 0.18  -- Larger icon size for better visibility (increased from 0.12 to 0.18)
        local drawW = iconW * scale
        local drawH = iconH * scale
        love.graphics.draw(icon, -drawW/2, -drawH/2, 0, scale, scale)

        -- Label below: name and qty (smaller and crisper)
        local label = (itemDef.name or itemId) .. " x" .. qty
        local font = love.graphics.getFont()
        local textW = font:getWidth(label)
        local textH = font:getHeight()
        -- Scale down the text to fit better with smaller items
        local textScale = 0.6
        local scaledTextW = textW * textScale
        local scaledTextH = textH * textScale
        love.graphics.push()
        love.graphics.scale(textScale, textScale)
        -- Center the label under the icon (accounting for scaling)
        love.graphics.print(label, -textW/2, (drawH/2 + 2)/textScale)
        love.graphics.pop()
    else
        -- Fallback: simple circle with generic label
        local size = 2 * s
        love.graphics.setColor(0.7, 0.7, 0.8, 1.0)
        love.graphics.circle('fill', 0, 0, size)
        love.graphics.setColor(0.4, 0.4, 0.5, 1.0)
        love.graphics.setLineWidth(1)
        love.graphics.circle('line', 0, 0, size)

        -- Generic label (smaller and crisper)
        local label = "Item x" .. qty
        local font = love.graphics.getFont()
        local textW = font:getWidth(label)
        local textH = font:getHeight()
        love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
        -- Scale down the text to fit better with smaller items
        local textScale = 0.6
        love.graphics.push()
        love.graphics.scale(textScale, textScale)
        -- Center the label under the circle (accounting for scaling)
        love.graphics.print(label, -textW/2, (size + 2)/textScale)
        love.graphics.pop()
    end

    if oldFont then
        love.graphics.setFont(oldFont)
    end
end

function EntityRenderers.xp_pickup(entity, player)
    local props = entity.components.renderable.props or {}
    local Theme = require("src.core.theme")
    local time = love.timer.getTime()
    entity._pulseOffset = entity._pulseOffset or math.random() * math.pi * 2

    local baseRadius = 9 * (props.sizeScale or 1.0)
    local pulse = 0.75 + 0.25 * math.sin(time * 4 + entity._pulseOffset)
    local glowRadius = baseRadius * (1.4 + 0.2 * math.sin(time * 3.2 + entity._pulseOffset * 0.5))

    local xpColor = Theme.semantic and Theme.semantic.modernStatusXP or {0.45, 0.75, 1.0, 1.0}
    local glowColor = {xpColor[1], xpColor[2], xpColor[3], 0.35}

    love.graphics.setColor(glowColor)
    love.graphics.circle("fill", 0, 0, glowRadius)

    love.graphics.setColor(xpColor[1], xpColor[2], xpColor[3], 0.85)
    love.graphics.circle("fill", 0, 0, baseRadius * pulse)

    love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", 0, 0, baseRadius * (0.85 + 0.15 * pulse))

    local oldFont = love.graphics.getFont()
    if Theme.fonts and Theme.fonts.small then
        love.graphics.setFont(Theme.fonts.small)
    end

    local font = love.graphics.getFont()
    local label = "XP"
    local labelW = font:getWidth(label)
    local labelH = font:getHeight()
    love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
    love.graphics.print(label, -labelW * 0.5, -labelH * 0.5)

    if oldFont then
        love.graphics.setFont(oldFont)
    end
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
        
        -- Unpack the nested vertex table for Love2D's polygon function
        local flatVertices = {}
        for _, vertex in ipairs(vertices) do
            table.insert(flatVertices, vertex[1])
            table.insert(flatVertices, vertex[2])
        end

        RenderUtils.setColor(fillColor)
        love.graphics.polygon("fill", flatVertices)

        RenderUtils.setColor(outlineColor)
        love.graphics.polygon("line", flatVertices)
        
        -- Draw mining hotspots as half circles sticking out from asteroid edge
        if entity.components.mineable and entity.components.mineable.hotspots then
            local hotspots = entity.components.mineable.hotspots:getHotspots()
            local asteroidRadius = entity.components.collidable and entity.components.collidable.radius or 30

            for _, hotspot in ipairs(hotspots) do
                if hotspot.active then
                    -- Calculate pulsing effect
                    local pulse = 0.8 + 0.2 * math.sin(hotspot.pulsePhase)
                    local alpha = (hotspot.lifetime / hotspot.maxLifetime) * pulse

                    -- Calculate angle from asteroid center to hotspot
                    local dx = hotspot.x - entity.components.position.x
                    local dy = hotspot.y - entity.components.position.y
                    local angle = math.atan2(dy, dx)

                    -- Calculate half circle parameters based on stored hotspot position
                    local halfCircleRadius = hotspot.radius * pulse
                    local baseDistance = math.sqrt(dx * dx + dy * dy)
                    local desiredDistance = asteroidRadius + halfCircleRadius * 0.35
                    local distance = baseDistance
                    if distance <= 0 then
                        distance = desiredDistance
                    else
                        distance = math.max(distance, desiredDistance)
                    end

                    local halfCircleX = math.cos(angle) * distance
                    local halfCircleY = math.sin(angle) * distance

                    -- Draw half circle as a filled arc with vivid yellow glow
                    local glowColor = {1.0, 0.95, 0.35, alpha * 0.55}
                    RenderUtils.setColor(glowColor)
                    love.graphics.arc("fill", halfCircleX, halfCircleY, halfCircleRadius,
                                   angle - math.pi/2, angle + math.pi/2, 32)

                    -- Draw half circle border with a brighter rim
                    local borderColor = {1.0, 0.9, 0.2, alpha}
                    RenderUtils.setColor(borderColor)
                    love.graphics.setLineWidth(2)
                    love.graphics.arc("line", halfCircleX, halfCircleY, halfCircleRadius,
                                    angle - math.pi/2, angle + math.pi/2, 32)
                    love.graphics.setLineWidth(1)

                    -- Draw inner core as smaller half circle to sell the heat
                    local coreColor = {1.0, 0.98, 0.55, alpha * 0.85}
                    RenderUtils.setColor(coreColor)
                    local coreRadius = halfCircleRadius * 0.42
                    love.graphics.arc("fill", halfCircleX, halfCircleY, coreRadius,
                                   angle - math.pi/2, angle + math.pi/2, 32)
                end
            end
        end
       
        -- No hover glow ring; visible effects only when laser is cutting

        ResourceNodeBars.drawMiningBar(entity, {
            isHovered = isHovered,
        })
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
        
        -- Station outline only (glass panel effect removed)
        RenderUtils.setColor({0.85, 0.88, 0.90, 1.0})
        love.graphics.setLineWidth(S(2))
        love.graphics.circle("line", 0, 0, stationRadius)
        love.graphics.setLineWidth(1)
    end

    -- Weapons disabled ring removed for better immersion
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
                local baseAlpha = (type(s.color) == "table" and s.color[4]) or 1
                local a = baseAlpha * alpha
                RenderUtils.setColor(s.color, a)
                love.graphics.polygon(s.mode or 'fill', s.points)
            elseif (s.type == 'rect' or s.type == 'rectangle') then
                local baseAlpha = (type(s.color) == "table" and s.color[4]) or 1
                local a = baseAlpha * alpha
                RenderUtils.setColor(s.color, a)
                love.graphics.rectangle(s.mode or 'fill', s.x or -4, s.y or -4, s.w or 8, s.h or 8, s.rx or 1, s.ry or s.rx or 1)
            elseif s.type == 'circle' then
                local baseAlpha = (type(s.color) == "table" and s.color[4]) or 1
                local a = baseAlpha * alpha
                RenderUtils.setColor(s.color, a)
                love.graphics.circle(s.mode or 'fill', s.x or 0, s.y or 0, s.r or 3)
            elseif s.type == 'line' and s.points then
                local baseAlpha = (type(s.color) == "table" and s.color[4]) or 1
                local a = baseAlpha * alpha
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
    
    ResourceNodeBars.drawSalvageBar(entity, {
        isHovered = isHovered,
    })
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

    if kind == 'laser' or kind == 'salvaging_laser' or kind == 'mining_laser' then
        -- Draw along +X in local space; outer renderer applies rotation.
        local len = props.length or props.maxLength or 800
        local baseColor, baseWidth
        
        -- Type-specific colors for charged pulse system
        if kind == 'salvaging_laser' then
            baseColor = util.copy(props.color or {0.2, 1.0, 0.3, 0.8}) -- Green
            baseWidth = props.tracerWidth or 2.0
        elseif kind == 'mining_laser' then
            baseColor = util.copy(props.color or {1.0, 0.7, 0.2, 0.8}) -- Orange
            baseWidth = props.tracerWidth or 2.0
        else
            baseColor = util.copy(props.color or {0.3, 0.7, 1.0, 0.8}) -- Blue (combat)
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
        local r, g, b, baseAlpha = util.unpack_color(baseColor)

        if elapsed <= buildupTime then
            -- BUILDUP PHASE: Energy charging
            phase = "buildup"
            phaseProgress = elapsed / buildupTime
            local intensity = phaseProgress * phaseProgress -- Quadratic buildup
            alpha = baseAlpha * (0.3 + 0.7 * intensity)
            coreW = baseWidth * (0.1 + 0.4 * intensity) -- Thinner beam
            glowW = coreW + 3 * intensity -- Less glow
        elseif elapsed <= buildupTime + flashTime then
            -- FLASH PHASE: Intense beam release
            phase = "flash"
            phaseProgress = (elapsed - buildupTime) / flashTime
            alpha = baseAlpha * (2.0 + 0.5 * math.sin(phaseProgress * math.pi * 8)) -- Flickering intensity
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
            RenderUtils.setColor(baseColor, alpha * 0.3)
            love.graphics.line(0, 0, len * phaseProgress, 0)
            
            -- Energy particles building up along beam path
            for i = 1, math.floor(8 * phaseProgress) do
                local px = (len * phaseProgress) * (i / 8) + math.sin(time * 12 + i) * 3
                local py = math.cos(time * 10 + i * 2) * (3 * phaseProgress)
                RenderUtils.setColor(baseColor, alpha * 0.9)
                love.graphics.circle("fill", px, py, 1.5 + phaseProgress * 0.5)
            end
            
            -- Charging glow at muzzle
            RenderUtils.setColor(baseColor, alpha * 0.6)
            love.graphics.circle("fill", 0, 0, 2 + 4 * phaseProgress)
            
        else
            -- FLASH: Massive intense beam discharge
            -- Outer glow
            love.graphics.setLineWidth(glowW)
            RenderUtils.setColor(baseColor, alpha * 0.5)
            love.graphics.line(0, 0, len, 0)
            
            -- Core beam - brighter and wider
            love.graphics.setLineWidth(coreW)
            RenderUtils.setColor({math.min(1, r + 0.4), math.min(1, g + 0.4), math.min(1, b + 0.4), alpha})
            love.graphics.line(0, 0, len, 0)
            
            -- Intense muzzle flash
            RenderUtils.setColor({math.min(1, r + 0.5), math.min(1, g + 0.5), math.min(1, b + 0.5), alpha * 0.8})
            love.graphics.circle("fill", 0, 0, 6 + math.sin(phaseProgress * math.pi * 20) * 2)
            
            -- Energy burst particles
            for i = 1, 6 do
                local burstAngle = (i / 6) * math.pi * 2 + phaseProgress * math.pi
                local burstDist = 8 + math.sin(phaseProgress * math.pi * 15 + i) * 3
                local bx = math.cos(burstAngle) * burstDist
                local by = math.sin(burstAngle) * burstDist
                RenderUtils.setColor(baseColor, alpha * 0.7)
                love.graphics.circle("fill", bx, by, 1 + math.sin(phaseProgress * math.pi * 10 + i) * 0.5)
            end
        end

        love.graphics.setLineWidth(1)
        if love.graphics.setLineStyle then love.graphics.setLineStyle('rough') end
    else
        local color = props.color or {0.35, 0.70, 1.00, 1.0}
        local radius = props.radius or 1
        
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

-- Warp Gate renderer - Realistic toroidal portal design
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

    -- Realistic warp gate parameters
    local outerRingRx = 500  -- Toroidal outer ring width
    local outerRingRy = 120  -- Toroidal outer ring height (flattened)
    local innerPortalRx = 300
    local innerPortalRy = 80
    local coreRadius = 150
    local supportThickness = 8
    local emitterSize = 25

    -- Central energy vortex parameters
    local vortexLayers = 5
    local vortexSpiralArms = 4

    love.graphics.push()
    love.graphics.translate(0, 0)
    love.graphics.rotate(rotation * 0.5)  -- Slow overall rotation

    if isActive then
        -- Outer structural toroidal ring (segmented for realism)
        local ringSegments = 24
        love.graphics.setLineWidth(5 * glowIntensity)
        for i = 0, ringSegments - 1 do
            local angle1 = (i / ringSegments) * math.pi * 2
            local angle2 = ((i + 1) / ringSegments) * math.pi * 2
            local midAngle = (angle1 + angle2) / 2
            local x1 = math.cos(angle1) * outerRingRx
            local y1 = math.sin(angle1) * outerRingRy
            local x2 = math.cos(angle2) * outerRingRx
            local y2 = math.sin(angle2) * outerRingRy
            local glow = 0.3 + glowIntensity * 0.7
            RenderUtils.setColor({0.25, 0.25, 0.35, glow})
            love.graphics.line(x1, y1, x2, y2)
        end

        -- Structural arches/supports
        local archCount = 8
        for i = 0, archCount - 1 do
            local angle = (i / archCount) * math.pi * 2
            local archAngle = angle + math.pi / 2  -- Perpendicular to ring
            local supportLength = outerRingRx * 0.8
            local sx1 = math.cos(angle) * outerRingRx * 0.9
            local sy1 = math.sin(angle) * outerRingRy * 0.9
            local sx2 = sx1 + math.cos(archAngle) * supportLength
            local sy2 = sy1 + math.sin(archAngle) * supportLength
            RenderUtils.setColor({0.4, 0.4, 0.5, 0.8 + glowIntensity * 0.2})
            love.graphics.setLineWidth(supportThickness)
            love.graphics.line(sx1, sy1, sx2, sy2)
        end

        -- Inner energy portal ring with distortion
        love.graphics.setLineWidth(3 * glowIntensity)
        RenderUtils.setColor({0.2, 0.8, 1.0, 0.6 + glowIntensity * 0.4})
        love.graphics.ellipse("line", 0, 0, innerPortalRx, innerPortalRy)

        -- Central energy core (glowing sphere)
        RenderUtils.setColor({0.1, 0.6, 1.0, 0.5 + glowIntensity * 0.5})
        love.graphics.circle("fill", 0, 0, coreRadius * 0.6)
        RenderUtils.setColor({0.3, 0.8, 1.0, 0.8 + glowIntensity * 0.2})
        love.graphics.circle("line", 0, 0, coreRadius * 0.6, coreRadius * 0.6, 32, 0, 0, false)

        -- Energy vortex (spiraling arms)
        love.graphics.push()
        love.graphics.rotate(rotation * 2)  -- Faster vortex rotation
        for arm = 1, vortexSpiralArms do
            local armOffset = (arm / vortexSpiralArms) * math.pi * 2
            for layer = 1, vortexLayers do
                local layerT = layer / vortexLayers
                local spiralRadius = coreRadius * layerT * 1.5
                local spiralAngle = armOffset + layerT * math.pi * 4 + rotation * 3  -- Spiral twist
                local ex = math.cos(spiralAngle) * spiralRadius
                local ey = math.sin(spiralAngle) * spiralRadius
                local alpha = (1 - layerT) * (0.4 + glowIntensity * 0.6)
                RenderUtils.setColor({0.4, 0.9, 1.0, alpha})
                love.graphics.circle("line", ex, ey, 5 * layerT, 5 * layerT, 8)
            end
        end
        love.graphics.pop()

        -- Rotating emitters on the ring
        local emitterPositions = {
            {x = outerRingRx * 0.8, y = 0},
            {x = -outerRingRx * 0.8, y = 0},
            {x = 0, y = outerRingRy * 0.8},
            {x = 0, y = -outerRingRy * 0.8}
        }
        for _, pos in ipairs(emitterPositions) do
            love.graphics.push()
            love.graphics.translate(pos.x, pos.y)
            love.graphics.rotate(rotation * 1.5)  -- Emitters rotate independently
            RenderUtils.setColor({1.0, 1.0, 0.5, 0.9 * glowIntensity})
            love.graphics.circle("fill", 0, 0, emitterSize)
            -- Emitter glow
            RenderUtils.setColor({1.0, 1.0, 0.5, 0.4 * glowIntensity})
            love.graphics.circle("fill", 0, 0, emitterSize * 1.5)
            love.graphics.pop()
        end

        -- Distortion field (subtle grid lines for space warp effect)
        if glowIntensity > 0.5 then
            love.graphics.setLineWidth(1)
            local gridSize = 20
            for i = -4, 4 do
                local offset = rotation * 10 + i * math.pi / 2
                local gx = math.cos(offset) * innerPortalRx * 1.2
                local gy = math.sin(offset) * innerPortalRy * 1.2
                RenderUtils.setColor({0.1, 0.4, 0.8, 0.2 * glowIntensity})
                love.graphics.line(-gx, -gy, gx, gy)
            end
        end

    else
        -- Inactive state: faded structural ring
        love.graphics.setLineWidth(2)
        RenderUtils.setColor({0.2, 0.2, 0.3, 0.4})
        love.graphics.ellipse("line", 0, 0, outerRingRx, outerRingRy)

        -- Inactive core
        RenderUtils.setColor({0.1, 0.1, 0.2, 0.3})
        love.graphics.circle("fill", 0, 0, coreRadius * 0.4)
    end

    love.graphics.pop()

    -- Enhanced particles for energy field
    if isActive and visual.particles then
        for _, particle in ipairs(visual.particles) do
            if particle.alpha > 0 then
                -- Particle as small energy sparks
                local px = particle.x + math.cos(rotation + particle.x) * 10
                local py = particle.y + math.sin(rotation + particle.y) * 10
                RenderUtils.setColor({0.8, 1.0, 1.0, particle.alpha * glowIntensity})
                love.graphics.circle("fill", px, py, particle.size * glowIntensity)
            end
        end
    end

    -- Power level indicator (if applicable)
    if entity.components.warp_gate and entity.components.warp_gate.requiresPower then
        local powerPercent = powerLevel / maxPowerLevel
        local barWidth = 80
        local barHeight = 6
        local barY = outerRingRx + 30

        -- Background
        RenderUtils.setColor({0.1, 0.1, 0.1, 0.8})
        love.graphics.rectangle("fill", -barWidth/2, barY, barWidth, barHeight, 2, 2)

        -- Power bar
        local powerColor = powerPercent > 0.3 and {0.2, 1.0, 0.2} or {1.0, 0.2, 0.2}
        RenderUtils.setColor({powerColor, powerColor, powerColor, 0.9})
        love.graphics.rectangle("fill", -barWidth/2, barY, barWidth * powerPercent, barHeight, 2, 2)

        -- Border
        RenderUtils.setColor({0.5, 0.5, 0.5, 0.6})
        love.graphics.rectangle("line", -barWidth/2, barY, barWidth, barHeight, 2, 2)
    end

    -- Restore graphics state
    love.graphics.setColor(r, g, b, a)
    love.graphics.setLineWidth(lineWidth)
end

function EntityRenderers.draw(world, camera, player)
    local entities = world:get_entities_with_components("renderable", "position")
    -- Draw engine trails for all non-player entities first (world space)
    for _, entity in ipairs(entities) do
        if entity ~= player and entity.components and entity.components.engine_trail then
            entity.components.engine_trail:draw()
        end
    end

    -- Then draw entities themselves
    for _, entity in ipairs(entities) do
        if entity == player then goto continue end
        local pos = entity.components.position
        if not pos then goto continue end

        love.graphics.push()
        love.graphics.translate(pos.x, pos.y)
        love.graphics.rotate(pos.angle or 0)

        -- Use cached renderer type for better performance
        local rendererType = getEntityRendererType(entity)
        local renderer = cachedRenderers[rendererType]

        if renderer then
            renderer(entity, player)
        else
            -- Create renderer function once and cache it
            if rendererType == 'remote_player' then
                renderer = EntityRenderers.remote_player
            elseif rendererType == 'enemy' then
                renderer = EntityRenderers.enemy
            elseif rendererType == 'warp_gate' then
                renderer = EntityRenderers.warp_gate
            elseif rendererType == 'asteroid' then
                renderer = EntityRenderers.asteroid
            elseif rendererType == 'item_pickup' then
                renderer = EntityRenderers.item_pickup
            elseif rendererType == 'xp_pickup' then
                renderer = EntityRenderers.xp_pickup
            elseif rendererType == 'wreckage' then
                renderer = EntityRenderers.wreckage
            elseif rendererType == 'bullet' then
                renderer = EntityRenderers.bullet
            elseif rendererType == 'station' then
                renderer = EntityRenderers.station
            elseif rendererType == 'planet' then
                renderer = EntityRenderers.planet
            elseif rendererType == 'reward_crate' then
                renderer = EntityRenderers.reward_crate
            elseif rendererType == 'lootContainer' then
                renderer = EntityRenderers.lootContainer
            else
                renderer = function(e, p) -- Fallback renderer
                    local props = e.components.renderable.props or {}
                    local v = props.visuals or {}
                    local size = v.size or 1.0
                    local S = RenderUtils.createScaler(size)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.circle("fill", 0, 0, S(10))
                end
            end

            -- Cache the renderer function
            cachedRenderers[rendererType] = renderer
            -- Call the renderer
            renderer(entity, player)
        end

        love.graphics.pop()

        -- Draw turret heat bars in screen space
        if entity.components.ai and entity.components.equipment and entity.components.equipment.grid then
            local x, y = entity.components.position.x, entity.components.position.y
            local screenX, screenY = Viewport.toScreen(x, y)
            local turrets = {}
            for _, gridData in ipairs(entity.components.equipment.grid) do
                if gridData.type == "turret" and gridData.module then
                    table.insert(turrets, gridData.module)
                end
            end
            for i, turret in ipairs(turrets) do

            end
        end

        -- Draw enemy laser beams after pop, in world space
        if entity.components.ai and entity.components.equipment and entity.components.equipment.grid then
            for _, gridData in ipairs(entity.components.equipment.grid) do
                if gridData.type == "turret" and gridData.module and (gridData.module.kind == "laser" or gridData.module.kind == "mining_laser" or gridData.module.kind == "salvaging_laser") and gridData.module.beamActive then
                    local turret = gridData.module
                    local TurretEffects = require("src.systems.turret.effects")
                    -- Get turret world position for beam rendering
                    local Turret = require("src.systems.turret.core")
                    local turretX, turretY = Turret.getTurretWorldPosition(turret)
                    TurretEffects.renderBeam(turret, turretX, turretY, turret.beamEndX, turret.beamEndY, turret.beamTarget)
                    turret.beamActive = false
                end
            end
        end
        ::continue::
    end

end

return EntityRenderers
