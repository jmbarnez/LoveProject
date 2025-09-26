local DebugPanel = {}
local Viewport = require("src.core.viewport")
local Theme = require("src.core.theme")
local Window = require("src.ui.common.window")

-- Debug panel state
local stats = {
    fps = 0,
    mem = 0,
    drawTime = 0,
    updateTime = 0,
    aiCount = 0,
    nearestEnemyDist = nil,
    nearestEnemyRange = nil,
    playerInsideRange = false
}

function DebugPanel.init()
    local viewportWidth = 0
    viewportWidth = Viewport.getDimensions()
    local panelWidth = 190
    local panelHeight = 170
    local startX = math.max(10, (viewportWidth or panelWidth) - (panelWidth + 20))
    DebugPanel.window = Window.new({
        title = "Debug Info",
        width = panelWidth,
        height = panelHeight,
        x = startX,
        y = 10,
        useLoadPanelTheme = true,
        draggable = true,
        closable = true,
        resizable = false,
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

    local texts = {}
    texts[#texts + 1] = string.format("FPS: %d", stats.fps)
    texts[#texts + 1] = string.format("Update: %.1fms", stats.updateTime)
    texts[#texts + 1] = string.format("Draw: %.1fms", stats.drawTime)
    texts[#texts + 1] = string.format("Mem: %.1fMB", stats.mem)
    texts[#texts + 1] = ""
    texts[#texts + 1] = string.format("AI Count: %d", stats.aiCount or 0)
    if stats.nearestEnemyDist then
        texts[#texts + 1] = string.format("Nearest AI: %.0fu", stats.nearestEnemyDist)
    else
        texts[#texts + 1] = "Nearest AI: --"
    end
    if stats.nearestEnemyRange then
        local insideLabel = stats.playerInsideRange and "inside" or "outside"
        texts[#texts + 1] = string.format("Detect Rng: %.0fu (%s)", stats.nearestEnemyRange, insideLabel)
    else
        texts[#texts + 1] = "Detect Rng: --"
    end

    love.graphics.setFont(font)
    Theme.setColor(Theme.colors.text)
    for i, text in ipairs(texts) do
        local textY = y + padding + (i - 1) * (lineHeight + margin)
        if text ~= "" then
            love.graphics.print(text, x + padding, textY)
        end
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


function DebugPanel.setAIDebugInfo(aiCount, nearestDistance, detectionRange)
    stats.aiCount = aiCount or 0
    stats.nearestEnemyDist = nearestDistance
    stats.nearestEnemyRange = detectionRange
    if detectionRange and nearestDistance then
        stats.playerInsideRange = nearestDistance <= detectionRange
    else
        stats.playerInsideRange = false
    end
end
-- Set rendering stats (call this after your main draw)
function DebugPanel.setRenderStats(drawTime)
    stats.drawTime = drawTime or stats.drawTime
end

return DebugPanel
