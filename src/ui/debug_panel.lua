local DebugPanel = {}
local Viewport = require("src.core.viewport")
local Theme = require("src.core.theme")

-- Debug panel state
local visible = false
local stats = {
    fps = 0,
    mem = 0,
    drawTime = 0,
    updateTime = 0
}

-- Panel style
local style = {
    padding = 8,
    margin = 4,
    fontSize = 10,
    bgColor = {0, 0, 0, 0.7},
    textColor = {1, 1, 1, 1},
    accentColor = {0.4, 0.8, 1.0, 1.0}
}

-- Toggle debug panel visibility
function DebugPanel.toggle()
    visible = not visible
end

-- Query debug panel visibility
function DebugPanel.isVisible()
    return visible
end

-- Update debug information
function DebugPanel.update(dt)
    if not visible then return end
    
    -- Update FPS counter
    stats.fps = love.timer.getFPS()
    
    -- Update memory usage (in MB)
    stats.mem = collectgarbage("count") / 1024
    
    -- Get frame timing information if available
    if love.timer.getDelta then
        stats.updateTime = love.timer.getDelta() * 1000  -- Convert to ms
    end
end

-- Draw the debug panel
function DebugPanel.draw()
    if not visible then return end
    
    local w, h = Viewport.getDimensions()
    local font = love.graphics.newFont(style.fontSize)
    local lineHeight = font:getHeight()
    local padding = style.padding
    local margin = style.margin
    
    -- Calculate text widths for alignment
    local texts = {
        string.format("FPS: %d", stats.fps),
        string.format("Update: %.1fms", stats.updateTime),
        string.format("Draw: %.1fms", stats.drawTime),
        string.format("Mem: %.1fMB", stats.mem)
    }
    
    -- Find the widest text for panel width
    local maxWidth = 0
    for _, text in ipairs(texts) do
        local width = font:getWidth(text)
        if width > maxWidth then
            maxWidth = width
        end
    end
    
    local panelWidth = maxWidth + padding * 2
    local panelHeight = #texts * (lineHeight + margin) + padding * 2 - margin
    local x = w - panelWidth - 10  -- 10px from right edge
    local y = 10  -- 10px from top
    
    -- Draw panel background with subtle border
    love.graphics.setColor(style.bgColor)
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight, 3)
    love.graphics.setColor(style.accentColor)
    love.graphics.rectangle("line", x, y, panelWidth, panelHeight, 3)
    
    -- Draw debug info
    love.graphics.setFont(font)
    for i, text in ipairs(texts) do
        local textY = y + padding + (i-1) * (lineHeight + margin)
        love.graphics.setColor(style.textColor)
        love.graphics.print(text, x + padding, textY)
    end
end

-- Handle keyboard input for the debug panel
function DebugPanel.keypressed(key)
    if key == "f1" then
        DebugPanel.toggle()
        return true
    end
    return false
end

-- Empty textinput handler (needed to prevent input from reaching the game)
function DebugPanel.textinput()
    return false
end

-- Set rendering stats (call this after your main draw)
function DebugPanel.setRenderStats(drawTime)
    stats.drawTime = drawTime or stats.drawTime
end

return DebugPanel
