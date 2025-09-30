local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local UIUtils = require("src.ui.common.utils")
local Events = require("src.core.events")

local ExperienceNotification = {
    visible = false,
    alpha = 0,
    timer = 0,
    holdDuration = 3.0,
    fadeDuration = 1.5,
    scale = 0,
    slideY = 0,
    animationTime = 0,
    state = {
        skillName = "",
        level = 1,
        maxLevel = 1,
        progress = 0,
        xpInLevel = 0,
        xpToNext = 0,
        xpGained = 0,
        leveledUp = false
    }
}

local subscribed = false

local function clamp01(value)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function subscribe()
    if subscribed then
        return
    end

    if Events and Events.on and Events.GAME_EVENTS and Events.GAME_EVENTS.SKILL_XP_GAINED then
        Events.on(Events.GAME_EVENTS.SKILL_XP_GAINED, function(payload)
            ExperienceNotification.onXpGain(payload)
        end)
        subscribed = true
    end
end

function ExperienceNotification.resubscribe()
    subscribed = false
    subscribe()
end

function ExperienceNotification.onXpGain(payload)
    if not payload then return end

    ExperienceNotification.state.skillName = payload.skillName or payload.skillId or "Unknown Skill"
    ExperienceNotification.state.level = payload.level or 1
    ExperienceNotification.state.maxLevel = payload.maxLevel or ExperienceNotification.state.level
    ExperienceNotification.state.progress = clamp01(payload.progress or 0)
    ExperienceNotification.state.xpInLevel = payload.xpInLevel or 0
    ExperienceNotification.state.xpToNext = payload.xpToNext or 0
    ExperienceNotification.state.xpGained = payload.xpGained or 0
    ExperienceNotification.state.leveledUp = payload.leveledUp or false

    -- Show level up notification in the normal notification system
    if payload.leveledUp then
        local Notifications = require("src.ui.notifications")
        local levelUpText = string.format("%s leveled up to level %d!", payload.skillName or payload.skillId, payload.level or 1)
        Notifications.add(levelUpText, "success")
    end

    ExperienceNotification.visible = true
    ExperienceNotification.alpha = 1
    ExperienceNotification.scale = 0
    ExperienceNotification.slideY = -30
    ExperienceNotification.timer = 0
    ExperienceNotification.animationTime = 0
end

function ExperienceNotification.update(dt)
    if ExperienceNotification.visible then
        ExperienceNotification.timer = ExperienceNotification.timer + dt
        ExperienceNotification.animationTime = ExperienceNotification.animationTime + dt

        -- Animation phases
        local totalDuration = ExperienceNotification.holdDuration + ExperienceNotification.fadeDuration
        local animTime = ExperienceNotification.timer

        -- Scale and slide in animation (first 0.4 seconds)
        if animTime <= 0.4 then
            local t = animTime / 0.4
            ExperienceNotification.scale = 1 - math.pow(1 - t, 3) -- Ease out cubic
            ExperienceNotification.slideY = -30 * (1 - t) -- Slide from above
        else
            ExperienceNotification.scale = 1
            ExperienceNotification.slideY = 0
        end

        -- Hold phase
        if animTime <= ExperienceNotification.holdDuration then
            ExperienceNotification.alpha = 1
        else
            -- Fade out phase
            local fadeTime = animTime - ExperienceNotification.holdDuration
            if ExperienceNotification.fadeDuration > 0 then
                ExperienceNotification.alpha = math.max(0, 1 - (fadeTime / ExperienceNotification.fadeDuration))
            else
                ExperienceNotification.alpha = 0
            end

            if ExperienceNotification.alpha <= 0 then
                ExperienceNotification.visible = false
                ExperienceNotification.alpha = 0
                ExperienceNotification.scale = 0
                ExperienceNotification.slideY = 0
            end
        end
    end
end

local function formatXp(value)
    if math.abs(value - math.floor(value + 0.5)) < 0.05 then
        return tostring(math.floor(value + 0.5))
    end
    return string.format("%.1f", value)
end

local function drawAuroraProgressBar(x, y, w, h, progress, alpha, animationTime)
    -- Background with subtle gradient
    local bgColor = Theme.withAlpha(Theme.colors.bg0, 0.9 * alpha)
    Theme.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)

    if progress > 0 then
        local fillW = math.floor(w * progress)
        
        -- Enhanced aurora effect with more segments for smoother gradient
        local segments = 40
        local segmentW = fillW / segments
        
        for i = 0, segments - 1 do
            local segmentX = x + i * segmentW
            local segmentProgress = (i / segments) + (animationTime * 0.8) % 1
            local segmentProgress2 = (i / segments) + (animationTime * 0.5) % 1
            local segmentProgress3 = (i / segments) + (animationTime * 1.2) % 1
            
            -- Enhanced aurora colors - more vibrant cyan to magenta gradient
            local wave1 = math.sin(segmentProgress * math.pi * 2) * 0.5 + 0.5
            local wave2 = math.sin(segmentProgress * math.pi * 4 + math.pi / 3) * 0.3 + 0.7
            local mixv = math.max(0, math.min(1, 0.3 + wave1 * 0.4 + wave2 * 0.3))
            
            -- Aurora palette (cyan -> magenta) like the loading screen
            local c1 = {0.00, 0.85, 0.90}  -- Cyan
            local c2 = {0.65, 0.30, 0.95}  -- Magenta
            local r = c1[1] + (c2[1] - c1[1]) * mixv
            local g = c1[2] + (c2[2] - c1[2]) * mixv
            local b = c1[3] + (c2[3] - c1[3]) * mixv
            
            -- Add shimmer effect
            local shimmer = 0.15 * math.sin(segmentProgress3 * math.pi * 6)
            r = r + shimmer
            g = g + shimmer * 0.8
            b = b + shimmer * 0.6
            
            -- Alpha with pulsing effect
            local pulse = 0.8 + 0.2 * math.sin(segmentProgress2 * math.pi * 3)
            local a = pulse * alpha
            
            love.graphics.setColor(r, g, b, a)
            love.graphics.rectangle("fill", segmentX, y, segmentW, h, 8, 8)
        end
        
        -- Enhanced glow effect with multiple layers
        love.graphics.setColor(0.0, 0.85, 0.90, 0.3 * alpha)
        love.graphics.rectangle("fill", x - 3, y - 3, fillW + 6, h + 6, 8, 8)
        
        love.graphics.setColor(0.65, 0.30, 0.95, 0.2 * alpha)
        love.graphics.rectangle("fill", x - 1, y - 1, fillW + 2, h + 2, 8, 8)
        
        -- Main fill
        love.graphics.setColor(0.0, 0.85, 0.90, 0.8 * alpha)
        love.graphics.rectangle("fill", x, y, fillW, h, 8, 8)
        
        -- Enhanced shimmer effect - moving light sweep
        local shimmerOffset = (animationTime * 120) % (fillW + 40)
        if fillW > 20 then
            local shimmerX = x + shimmerOffset - 20
            local shimmerW = 40
            if shimmerX + shimmerW > x + fillW then
                shimmerW = x + fillW - shimmerX
            end
            if shimmerX < x then
                shimmerX = x
                shimmerW = shimmerW - (x - shimmerX)
            end
            if shimmerW > 0 then
                -- Gradient shimmer from white to cyan
                local shimmerSegments = 8
                local shimmerSegmentW = shimmerW / shimmerSegments
                for i = 0, shimmerSegments - 1 do
                    local shimmerSegmentX = shimmerX + i * shimmerSegmentW
                    local shimmerProgress = i / shimmerSegments
                    local shimmerAlpha = (1 - shimmerProgress) * 0.8 * alpha
                    love.graphics.setColor(1, 1, 1, shimmerAlpha)
                    love.graphics.rectangle("fill", shimmerSegmentX, y, shimmerSegmentW, h, 8, 8)
                end
            end
        end
    end
    
    -- Enhanced border with gradient
    love.graphics.setColor(0.0, 0.85, 0.90, 0.6 * alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 8, 8)
    
    -- Inner highlight
    love.graphics.setColor(0.0, 0.85, 0.90, 0.3 * alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 1, y + 1, w - 2, h - 2, 6, 6)
end

function ExperienceNotification.draw()
    if not ExperienceNotification.visible or ExperienceNotification.alpha <= 0 then
        return
    end

    local sw, sh = Viewport.getDimensions()

    local width = math.min(400, sw - 40)
    local height = 80
    local x = (sw - width) / 2  -- Center horizontally
    local y = 20 + ExperienceNotification.slideY  -- Top center with slide animation

    local alpha = ExperienceNotification.alpha
    local scale = ExperienceNotification.scale

    -- Apply scaling and positioning
    love.graphics.push()
    love.graphics.translate(x + width * 0.5, y + height * 0.5)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-width * 0.5, -height * 0.5)

    -- Background with glow
    local bgTop = Theme.withAlpha(Theme.colors.bg2, 0.95 * alpha)
    local bgBottom = Theme.withAlpha(Theme.colors.bg1, 0.95 * alpha)
    local glow = Theme.withAlpha(Theme.colors.accent, 0.6 * alpha)

    Theme.drawGradientGlowRect(0, 0, width, height, 8, bgTop, bgBottom, glow, Theme.effects.glowStrong * alpha)
    Theme.drawEVEBorder(0, 0, width, height, 8, Theme.withAlpha(Theme.colors.borderBright, alpha), 3)

    local oldFont = love.graphics.getFont()
    if Theme.fonts and Theme.fonts.medium then
        love.graphics.setFont(Theme.fonts.medium)
    end

    -- Title text
    local title = ExperienceNotification.state.skillName .. " — Level " .. ExperienceNotification.state.level
    local titleColor = ExperienceNotification.state.leveledUp and Theme.colors.success or Theme.colors.text
    Theme.setColor(Theme.withAlpha(titleColor, alpha))
    love.graphics.print(title, 20, 16)

    -- XP gain text
    local xpGainText = string.format("+%s XP", formatXp(ExperienceNotification.state.xpGained))
    if Theme.fonts and Theme.fonts.small then
        love.graphics.setFont(Theme.fonts.small)
    end

    local xpGainMetrics = UIUtils.getCachedTextMetrics(xpGainText, love.graphics.getFont())
    Theme.setColor(Theme.withAlpha(Theme.colors.accent, alpha))
    love.graphics.print(xpGainText, width - xpGainMetrics.width - 20, 20)

    -- Aurora progress bar
    local barX = 20
    local barY = height - 32
    local barW = width - 40
    local barH = 16

    drawAuroraProgressBar(barX, barY, barW, barH, ExperienceNotification.state.progress, alpha, ExperienceNotification.animationTime)

    -- Progress text
    local infoText
    if ExperienceNotification.state.maxLevel and ExperienceNotification.state.level >= ExperienceNotification.state.maxLevel and ExperienceNotification.state.xpToNext <= 0 then
        infoText = "Max level reached"
    elseif ExperienceNotification.state.xpToNext > 0 then
        local xpInLevel = formatXp(ExperienceNotification.state.xpInLevel)
        local xpToNext = formatXp(ExperienceNotification.state.xpToNext)
        local percent = string.format("%.1f%%", ExperienceNotification.state.progress * 100)
        infoText = string.format("%s / %s XP (%s)", xpInLevel, xpToNext, percent)
    else
        infoText = string.format("Total XP: %s", formatXp(ExperienceNotification.state.xpInLevel))
    end

    Theme.setColor(Theme.withAlpha(Theme.colors.textSecondary or Theme.colors.text, alpha))
    love.graphics.print(infoText, barX, barY + barH + 6)

    if oldFont then
        love.graphics.setFont(oldFont)
    end

    love.graphics.pop()
end

subscribe()

return ExperienceNotification
