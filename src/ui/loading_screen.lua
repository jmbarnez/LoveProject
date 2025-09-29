local LoadingScreen = {}
LoadingScreen.__index = LoadingScreen

local Theme = require("src.core.theme")
local Log = require("src.core.log")

-- Shared cached font reference so we avoid recreating fonts every frame
LoadingScreen.titleFont = nil

function LoadingScreen.new()
    local self = setmetatable({}, LoadingScreen)
    
    self.isVisible = false
    self.progress = 0
    self.currentTask = "Initializing..."
    self.tasks = {}
    self.currentTaskIndex = 1
    self.animationTime = 0
    self.pulsePhase = 0
    
    -- Loading animation properties
    self.spinnerAngle = 0
    self.spinnerSpeed = 3.0
    self.pulseSpeed = 2.0

    -- Prefer theme fonts, but fall back to a cached dedicated font
    self.titleFont = Theme.fonts and Theme.fonts.title or LoadingScreen.titleFont
    if not self.titleFont then
        LoadingScreen.titleFont = love.graphics.newFont(24)
        LoadingScreen.titleFont:setFilter("nearest", "nearest", 1)
        self.titleFont = LoadingScreen.titleFont
        Log.debug("LoadingScreen", "Initialized fallback loading screen title font")
    end

    return self
end

function LoadingScreen:show(tasks, autoAdvance)
    self.isVisible = true
    self.progress = 0
    self.tasks = tasks or {}
    self.currentTaskIndex = 1
    self.animationTime = 0
    self.pulsePhase = 0
    self.spinnerAngle = 0
    self.autoAdvance = autoAdvance or false
    self.isComplete = false
    
    if #self.tasks > 0 then
        self.currentTask = self.tasks[1]
    end
end

function LoadingScreen:hide()
    self.isVisible = false
end

function LoadingScreen:setProgress(progress, task)
    self.progress = math.max(0, math.min(1, progress))
    if task then
        self.currentTask = task
    end
end

function LoadingScreen:setComplete()
    self.isComplete = true
    self.progress = 1.0
    if self.onComplete then
        self.onComplete()
        self.onComplete = nil
    end
end

function LoadingScreen:nextTask()
    self.currentTaskIndex = self.currentTaskIndex + 1
    if self.currentTaskIndex <= #self.tasks then
        self.currentTask = self.tasks[self.currentTaskIndex]
    end
end

function LoadingScreen:update(dt)
    if not self.isVisible then return end
    
    self.animationTime = self.animationTime + dt
    self.spinnerAngle = self.spinnerAngle + self.spinnerSpeed * dt
    self.pulsePhase = self.pulsePhase + self.pulseSpeed * dt
    
    -- No auto-advance - progress is controlled by real loading operations
end

function LoadingScreen:draw()
    if not self.isVisible then return end

    local vw, vh = love.graphics.getDimensions()
    local centerX, centerY = vw / 2, vh / 2
    
    -- Black background
    love.graphics.setColor(0, 0, 0, 1.0)
    love.graphics.rectangle("fill", 0, 0, vw, vh)
    
    -- "Loading..." text
    local textColor = {0.95, 0.95, 1.0, 1.0}
    love.graphics.setColor(textColor)
    local titleFont = Theme.fonts and Theme.fonts.title or self.titleFont
    if not titleFont then
        -- Lazily initialize fallback font if Theme fonts load after construction
        if not LoadingScreen.titleFont then
            LoadingScreen.titleFont = love.graphics.newFont(24)
            LoadingScreen.titleFont:setFilter("nearest", "nearest", 1)
            Log.debug("LoadingScreen", "Initialized fallback loading screen title font")
        end
        self.titleFont = LoadingScreen.titleFont
        titleFont = self.titleFont
    elseif titleFont ~= self.titleFont then
        -- Theme fonts may have been loaded after construction; update cached reference
        self.titleFont = titleFont
    end
    love.graphics.setFont(titleFont)
    local title = "Loading..."
    local titleW = titleFont:getWidth(title)
    love.graphics.print(title, centerX - titleW / 2, centerY - 50)
    
    -- Aurora loading bar
    local barW, barH = 400, 8
    local barX, barY = centerX - barW / 2, centerY + 20
    
    -- Progress bar background (dark)
    love.graphics.setColor(0.1, 0.1, 0.2, 1.0)
    love.graphics.rectangle("fill", barX, barY, barW, barH)
    
    -- Aurora effect - animated gradient
    local fillW = barW * self.progress
    if fillW > 0 then
        -- Create aurora effect with multiple colors
        local segments = 20
        local segmentW = fillW / segments
        
        for i = 0, segments - 1 do
            local x = barX + i * segmentW
            local segmentProgress = (i / segments) + (self.animationTime * 0.5) % 1
            local segmentProgress2 = (i / segments) + (self.animationTime * 0.3) % 1
            
            -- Aurora colors - cyan to purple gradient
            local r = 0.2 + 0.6 * math.sin(segmentProgress * math.pi * 2)
            local g = 0.4 + 0.4 * math.sin(segmentProgress * math.pi * 2 + math.pi / 3)
            local b = 0.8 + 0.2 * math.sin(segmentProgress * math.pi * 2 + math.pi * 2 / 3)
            local a = 0.7 + 0.3 * math.sin(segmentProgress2 * math.pi * 4)
            
            love.graphics.setColor(r, g, b, a)
            love.graphics.rectangle("fill", x, barY, segmentW, barH)
        end
        
        -- Add glow effect
        love.graphics.setColor(0.3, 0.7, 0.9, 0.3)
        love.graphics.rectangle("fill", barX, barY - 1, fillW, barH + 2)
        love.graphics.rectangle("fill", barX, barY, fillW, barH)
    end
    
    -- Progress bar border
    love.graphics.setColor(0.3, 0.5, 0.8, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX, barY, barW, barH)
end

return LoadingScreen
