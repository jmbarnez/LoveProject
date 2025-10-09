local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local UIUtils = require("src.ui.common.utils")
local Events = require("src.core.events")
local Skills = require("src.core.skills")

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
        currentProgress = 0,
        segments = {},
        activeSegment = nil,
        speed = 6,
        displayLevel = 1,
        targetLevel = 1,
        segmentTimer = 0
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

local function computeSkillSnapshot(skillId, totalXp, maxLevel, fallbackLevel)
    local skillDef = Skills.definitions and Skills.definitions[skillId]
    if not skillDef then
        local level = fallbackLevel or 1
        return {
            level = level,
            progress = 0,
            xpInLevel = 0,
            xpToNext = 0
        }
    end

    local cap = math.min(maxLevel or math.huge, skillDef.maxLevel or math.huge)
    local level = math.min(cap, math.max(1, fallbackLevel or 1))
    local xpTotal = math.max(0, totalXp or 0)

    while level > 1 do
        local threshold = Skills.getXpForLevel(skillId, level)
        if xpTotal >= threshold then
            break
        end
        level = level - 1
    end

    -- Walk levels using the same logic as the skill system to avoid drift.
    while level < cap do
        local xpForNext = Skills.getXpForLevel(skillId, level + 1)
        if xpTotal < xpForNext then
            break
        end
        level = level + 1
    end

    local previousTotal = 0
    if level > 1 then
        previousTotal = Skills.getXpForLevel(skillId, level - 1)
    end

    local xpInLevel = xpTotal - previousTotal
    local xpToNext = 0
    if level < cap then
        local currentTotal = Skills.getXpForLevel(skillId, level)
        local nextTotal = Skills.getXpForLevel(skillId, level + 1)
        xpToNext = math.max(0, nextTotal - currentTotal)
    end

    local progress = 0
    if xpToNext <= 0 then
        progress = level >= cap and 1 or 0
    else
        progress = clamp01(xpInLevel / xpToNext)
    end

    return {
        level = level,
        progress = progress,
        xpInLevel = xpInLevel,
        xpToNext = xpToNext
    }
end

local function clearAnimation()
    ExperienceNotification.animation.segments = {}
    ExperienceNotification.animation.activeSegment = nil
    ExperienceNotification.animation.segmentTimer = 0
end

local function enqueueSegment(targetProgress, options)
    local segment = {
        target = clamp01(targetProgress or 0),
        speed = options and options.speed,
        hold = options and options.hold,
        onStart = options and options.onStart,
        onComplete = options and options.onComplete
    }
    table.insert(ExperienceNotification.animation.segments, segment)
end

local function beginNextSegment()
    local anim = ExperienceNotification.animation
    if anim.activeSegment or #anim.segments == 0 then
        return
    end

    anim.activeSegment = table.remove(anim.segments, 1)
    anim.segmentTimer = 0

    if anim.activeSegment.onStart then
        anim.activeSegment.onStart()
    end
end

function ExperienceNotification.onXpGain(payload)
    if not payload then return end

    ExperienceNotification.state.skillName = payload.skillName or payload.skillId or "Unknown Skill"
    ExperienceNotification.state.level = payload.level or 1
    ExperienceNotification.state.maxLevel = payload.maxLevel or ExperienceNotification.state.maxLevel or ExperienceNotification.state.level
    ExperienceNotification.state.progress = clamp01(payload.progress or 0)
    ExperienceNotification.state.xpInLevel = payload.xpInLevel or 0
    ExperienceNotification.state.xpToNext = payload.xpToNext or 0
    ExperienceNotification.state.xpGained = payload.xpGained or 0
    ExperienceNotification.state.leveledUp = payload.leveledUp or false

    local skillId = payload.skillId or payload.skillName
    local totalXp = payload.totalXp or 0
    local xpGained = payload.xpGained or 0
    local previousSnapshot = computeSkillSnapshot(
        skillId,
        totalXp - xpGained,
        ExperienceNotification.state.maxLevel,
        ExperienceNotification.state.level - (payload.leveledUp and 1 or 0)
    )

    local finalSnapshot = computeSkillSnapshot(
        skillId,
        totalXp,
        ExperienceNotification.state.maxLevel,
        ExperienceNotification.state.level
    )

    ExperienceNotification.state.level = finalSnapshot.level or ExperienceNotification.state.level
    ExperienceNotification.state.progress = clamp01(finalSnapshot.progress or ExperienceNotification.state.progress)
    ExperienceNotification.state.xpInLevel = finalSnapshot.xpInLevel or ExperienceNotification.state.xpInLevel
    ExperienceNotification.state.xpToNext = finalSnapshot.xpToNext or ExperienceNotification.state.xpToNext

    local previousLevel = previousSnapshot.level or 1
    local targetLevel = ExperienceNotification.state.level
    local leveledUp = targetLevel > previousLevel
    ExperienceNotification.state.leveledUp = leveledUp

    ExperienceNotification.animation.currentProgress = clamp01(previousSnapshot.progress or 0)
    ExperienceNotification.animation.targetLevel = targetLevel
    ExperienceNotification.animation.displayLevel = math.floor(math.max(1, math.min(targetLevel, previousSnapshot.level or targetLevel)))

    clearAnimation()

    local anim = ExperienceNotification.animation
    local finalProgress = ExperienceNotification.state.progress or 0
    local levelsRemaining = math.max(0, (anim.targetLevel or 1) - (anim.displayLevel or 1))
    local fillSpeed = anim.speed or 6

    if levelsRemaining > 0 then
        local firstLevel = true

        while levelsRemaining > 0 do
            local segmentOptions = {
                speed = fillSpeed,
                hold = 0.12,
                onComplete = function()
                    anim.displayLevel = anim.displayLevel + 1
                    anim.currentProgress = 0
                end
            }

            if not firstLevel then
                segmentOptions.onStart = function()
                    anim.currentProgress = 0
                end
            end

            enqueueSegment(1, segmentOptions)

            firstLevel = false
            levelsRemaining = levelsRemaining - 1
        end

        finalProgress = clamp01(finalProgress)
        if finalProgress > 0 then
            enqueueSegment(finalProgress, {
                speed = fillSpeed,
                onStart = function()
                    anim.currentProgress = 0
                end,
                onComplete = function()
                    anim.currentProgress = finalProgress
                end
            })
        else
            anim.currentProgress = 0
        end
    else
        finalProgress = clamp01(finalProgress)
        if math.abs((anim.currentProgress or 0) - finalProgress) < 0.001 then
            anim.currentProgress = finalProgress
        else
            enqueueSegment(finalProgress, { speed = fillSpeed })
        end
    end

    if #anim.segments == 0 then
        anim.currentProgress = finalProgress
        anim.displayLevel = anim.targetLevel
    end

    -- Show level up notification in the normal notification system
    if leveledUp then
        local Notifications = require("src.ui.notifications")
        local levelUpText = string.format(
            "%s leveled up to level %d!",
            payload.skillName or payload.skillId,
            ExperienceNotification.state.level or payload.level or 1
        )
        Notifications.add(levelUpText, "success")
    end

    ExperienceNotification.visible = true
    ExperienceNotification.alpha = 1
    ExperienceNotification.scale = 0
    ExperienceNotification.slideY = -20
    ExperienceNotification.timer = 0
    ExperienceNotification.animationTime = 0

    beginNextSegment()
end

function ExperienceNotification.update(dt)
    if ExperienceNotification.visible then
        ExperienceNotification.timer = ExperienceNotification.timer + dt
        ExperienceNotification.animationTime = ExperienceNotification.animationTime + dt

        -- Progress bar animation
        local anim = ExperienceNotification.animation
        anim.segmentTimer = anim.segmentTimer + dt

        if not anim.activeSegment and #anim.segments > 0 then
            beginNextSegment()
        end

        local segment = anim.activeSegment
        if segment then
            if segment.waiting and segment.waiting > 0 then
                segment.waiting = segment.waiting - dt
                if segment.waiting <= 0 then
                    if segment.onComplete then
                        segment.onComplete()
                    end
                    anim.activeSegment = nil
                    beginNextSegment()
                end
            else
                local target = segment.target or anim.currentProgress
                local diff = target - anim.currentProgress
                local speed = segment.speed or anim.speed or 6

                if math.abs(diff) <= 0.0001 then
                    anim.currentProgress = target
                else
                    anim.currentProgress = anim.currentProgress + diff * math.min(1, speed * dt)
                end

                anim.currentProgress = clamp01(anim.currentProgress)

                if math.abs(target - anim.currentProgress) <= 0.002 then
                    anim.currentProgress = target
                    local holdDuration = segment.hold or 0
                    if holdDuration > 0 then
                        segment.waiting = holdDuration
                    else
                        if segment.onComplete then
                            segment.onComplete()
                        end
                        anim.activeSegment = nil
                        beginNextSegment()
                    end
                end
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
        
        -- Check if we're in a level-up animation
        local isLevelingUp = ExperienceNotification.state.leveledUp or 
                            (ExperienceNotification.animation.targetLevel and 
                             ExperienceNotification.animation.displayLevel and 
                             ExperienceNotification.animation.targetLevel > ExperienceNotification.animation.displayLevel)
        
        -- Use different colors for level-up animation
        local fillColor
        if isLevelingUp then
            -- Bright success color for level-ups
            fillColor = Theme.withAlpha(Theme.colors.success, 0.9 * alpha)
        else
            -- Normal accent color
            fillColor = Theme.withAlpha(Theme.colors.accent, 0.9 * alpha)
        end
        Theme.setColor(fillColor)
        love.graphics.rectangle("fill", x, y, fillW, h, 4, 4)
        
        -- Enhanced highlight for level-ups
        local highlightColor
        if isLevelingUp then
            -- Bright highlight for level-ups
            highlightColor = Theme.withAlpha(Theme.colors.success, 0.5 * alpha)
        else
            -- Subtle highlight for normal progress
            highlightColor = Theme.withAlpha(Theme.colors.accent, 0.3 * alpha)
        end
        Theme.setColor(highlightColor)
        love.graphics.rectangle("fill", x, y, fillW, 2, 4, 4)
    end
    
    -- Enhanced border for level-ups
    local borderColor
    if ExperienceNotification.state.leveledUp then
        borderColor = Theme.withAlpha(Theme.colors.success, 0.8 * alpha)
    else
        borderColor = Theme.withAlpha(Theme.colors.borderBright, 0.6 * alpha)
    end
    Theme.setColor(borderColor)
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
    local displayLevel = ExperienceNotification.animation.displayLevel or ExperienceNotification.state.level
    local targetLevel = ExperienceNotification.animation.targetLevel or displayLevel
    
    -- Update display level during animation to show live level progression
    if ExperienceNotification.animation.activeSegment and ExperienceNotification.animation.activeSegment.onComplete then
        -- During level-up animation, show the current display level
        displayLevel = ExperienceNotification.animation.displayLevel
    elseif ExperienceNotification.animation.activeSegment == nil and #ExperienceNotification.animation.segments == 0 then
        -- Animation complete, show final level
        displayLevel = targetLevel
    end

    local levelLabel = tostring(displayLevel)
    -- Show level progression during animation
    if targetLevel and targetLevel > displayLevel then
        levelLabel = string.format("%s → %s", displayLevel, targetLevel)
    elseif ExperienceNotification.state.leveledUp and displayLevel == targetLevel then
        -- Just leveled up, show the new level with emphasis
        levelLabel = string.format("%s!", displayLevel)
    end

    local title = string.format("%s Lv.%s", ExperienceNotification.state.skillName, levelLabel)
    local shouldHighlight = ExperienceNotification.state.leveledUp or (targetLevel and targetLevel > displayLevel)
    local titleColor = shouldHighlight and Theme.colors.success or Theme.colors.text
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
