local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local UIUtils = require("src.ui.common.utils")
local Events = require("src.core.events")

local ExperienceNotification = {
    visible = false,
    alpha = 0,
    timer = 0,
    holdDuration = 2.0,
    fadeDuration = 0.8,
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
    },
    animation = {
        targetProgress = 0,
        currentProgress = 0,
        animating = false
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

    -- Start progress bar animation
    ExperienceNotification.animation.targetProgress = ExperienceNotification.state.progress
    ExperienceNotification.animation.animating = true

    -- Show level up notification in the normal notification system
    if payload.leveledUp then
        local Notifications = require("src.ui.notifications")
        local levelUpText = string.format("%s leveled up to level %d!", payload.skillName or payload.skillId, payload.level or 1)
        Notifications.add(levelUpText, "success")
    end

    ExperienceNotification.visible = true
    ExperienceNotification.alpha = 1
    ExperienceNotification.scale = 0
    ExperienceNotification.slideY = -20
    ExperienceNotification.timer = 0
    ExperienceNotification.animationTime = 0
end

function ExperienceNotification.update(dt)
    if ExperienceNotification.visible then
        ExperienceNotification.timer = ExperienceNotification.timer + dt
        ExperienceNotification.animationTime = ExperienceNotification.animationTime + dt

        -- Progress bar animation
        if ExperienceNotification.animation.animating then
            local target = ExperienceNotification.animation.targetProgress
            local current = ExperienceNotification.animation.currentProgress
            local diff = target - current
            
            if math.abs(diff) < 0.001 then
                ExperienceNotification.animation.currentProgress = target
                ExperienceNotification.animation.animating = false
            else
                -- Smooth animation with easing
                local speed = 3.0 -- Animation speed
                ExperienceNotification.animation.currentProgress = current + diff * speed * dt
            end
        end

        -- Animation phases
        local totalDuration = ExperienceNotification.holdDuration + ExperienceNotification.fadeDuration
        local animTime = ExperienceNotification.timer

        -- Scale and slide in animation (first 0.25 seconds)
        if animTime <= 0.25 then
            local t = animTime / 0.25
            ExperienceNotification.scale = 1 - math.pow(1 - t, 4) -- Ease out quartic for snappier feel
            ExperienceNotification.slideY = -20 * (1 - t) -- Slide from above
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

local function drawCompactProgressBar(x, y, w, h, progress, alpha)
    -- Clean background
    local bgColor = Theme.withAlpha(Theme.colors.bg0, 0.8 * alpha)
    Theme.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)

    if progress > 0 then
        local fillW = math.floor(w * progress)
        
        -- Simple gradient fill
        local fillColor = Theme.withAlpha(Theme.colors.accent, 0.9 * alpha)
        Theme.setColor(fillColor)
        love.graphics.rectangle("fill", x, y, fillW, h, 4, 4)
        
        -- Subtle highlight
        local highlightColor = Theme.withAlpha(Theme.colors.accent, 0.3 * alpha)
        Theme.setColor(highlightColor)
        love.graphics.rectangle("fill", x, y, fillW, 2, 4, 4)
    end
    
    -- Clean border
    Theme.setColor(Theme.withAlpha(Theme.colors.borderBright, 0.6 * alpha))
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)
end

function ExperienceNotification.draw()
    if not ExperienceNotification.visible or ExperienceNotification.alpha <= 0 then
        return
    end

    local sw, sh = Viewport.getDimensions()

    local width = math.min(320, sw - 32)
    local height = 56
    local x = (sw - width) / 2  -- Center horizontally
    local y = 16 + ExperienceNotification.slideY  -- Top center with slide animation

    local alpha = ExperienceNotification.alpha
    local scale = ExperienceNotification.scale

    -- Apply scaling and positioning
    love.graphics.push()
    love.graphics.translate(x + width * 0.5, y + height * 0.5)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-width * 0.5, -height * 0.5)

    -- Sleek background with subtle glow
    local bgTop = Theme.withAlpha(Theme.colors.bg2, 0.92 * alpha)
    local bgBottom = Theme.withAlpha(Theme.colors.bg1, 0.92 * alpha)
    local glow = Theme.withAlpha(Theme.colors.accent, 0.3 * alpha)

    Theme.drawGradientGlowRect(0, 0, width, height, 6, bgTop, bgBottom, glow, Theme.effects.glowWeak * alpha)
    Theme.drawEVEBorder(0, 0, width, height, 6, Theme.withAlpha(Theme.colors.borderBright, alpha), 2)

    local oldFont = love.graphics.getFont()
    if Theme.fonts and Theme.fonts.medium then
        love.graphics.setFont(Theme.fonts.medium)
    end

    -- Compact title and XP gain on same line
    local title = ExperienceNotification.state.skillName .. " Lv." .. ExperienceNotification.state.level
    local titleColor = ExperienceNotification.state.leveledUp and Theme.colors.success or Theme.colors.text
    Theme.setColor(Theme.withAlpha(titleColor, alpha))
    love.graphics.print(title, 16, 12)

    -- XP gain text (right aligned)
    local xpGainText = string.format("+%s", formatXp(ExperienceNotification.state.xpGained))
    if Theme.fonts and Theme.fonts.small then
        love.graphics.setFont(Theme.fonts.small)
    end

    local xpGainMetrics = UIUtils.getCachedTextMetrics(xpGainText, love.graphics.getFont())
    Theme.setColor(Theme.withAlpha(Theme.colors.accent, alpha))
    love.graphics.print(xpGainText, width - xpGainMetrics.width - 16, 14)

    -- Compact progress bar
    local barX = 16
    local barY = height - 20
    local barW = width - 32
    local barH = 8

    drawCompactProgressBar(barX, barY, barW, barH, ExperienceNotification.animation.currentProgress, alpha)

    -- No text under progress bar for cleaner look

    if oldFont then
        love.graphics.setFont(oldFont)
    end

    love.graphics.pop()
end

subscribe()

return ExperienceNotification
