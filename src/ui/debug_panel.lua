local DebugPanel = {}
local Viewport = require("src.core.viewport")
local Theme = require("src.core.theme")
local Window = require("src.ui.common.window")

-- Debug panel state
local stats = {
    fps = 0,
    mem = 0,
    drawTime = 0,
    updateTime = 0
}

function DebugPanel.init()
    DebugPanel.window = Window.new({
        title = "Debug Info",
        width = 150,
        height = 120,
        x = Viewport.getDimensions() - 160,
        y = 10,
        draggable = true,
        closable = true,
        resizable = true,
        drawContent = DebugPanel.drawContent,
        onClose = function()
            DebugPanel.visible = false
        end
    })
    DebugPanel.visible = false
end

-- Toggle debug panel visibility
function DebugPanel.toggle()
    if not DebugPanel.window then DebugPanel.init() end
    DebugPanel.visible = not DebugPanel.visible
    DebugPanel.window.visible = DebugPanel.visible
end

-- Query debug panel visibility
function DebugPanel.isVisible()
    return DebugPanel.visible
end

-- Update debug information
function DebugPanel.update(dt)
    if not DebugPanel.visible then return end
    
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
    if not DebugPanel.visible then return end
    if not DebugPanel.window then DebugPanel.init() end
    DebugPanel.window:draw()
end

function DebugPanel.drawContent(window, x, y, w, h)
    local font = Theme.fonts and Theme.fonts.small or love.graphics.getFont()
    local lineHeight = font:getHeight()
    local padding = 8
    local margin = 4

    local texts = {
        string.format("FPS: %d", stats.fps),
        string.format("Update: %.1fms", stats.updateTime),
        string.format("Draw: %.1fms", stats.drawTime),
        string.format("Mem: %.1fMB", stats.mem)
    }

    love.graphics.setFont(font)
    Theme.setColor(Theme.colors.text)

    for i, text in ipairs(texts) do
        local textY = y + padding + (i-1) * (lineHeight + margin)
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

function DebugPanel.mousepressed(x, y, button)
    if not DebugPanel.visible then return false end
    if not DebugPanel.window then return false end
    return DebugPanel.window:mousepressed(x, y, button)
end

function DebugPanel.mousereleased(x, y, button)
    if not DebugPanel.visible then return false end
    if not DebugPanel.window then return false end
    return DebugPanel.window:mousereleased(x, y, button)
end

function DebugPanel.mousemoved(x, y, dx, dy)
    if not DebugPanel.visible then return false end
    if not DebugPanel.window then return false end
    return DebugPanel.window:mousemoved(x, y, dx, dy)
end

-- Set rendering stats (call this after your main draw)
function DebugPanel.setRenderStats(drawTime)
    stats.drawTime = drawTime or stats.drawTime
end

return DebugPanel
