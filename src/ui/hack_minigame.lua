local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Util = require("src.core.util")

local HackMinigame = {
    visible = false,
    nodes = {},
    connections = {},
    targetPath = {},
    playerPath = {},
    difficulty = 1,
    timer = 0,
    maxTime = 15,
    success = false,
    failed = false,
    animTime = 0,
    gridSize = 5, -- 5x5 grid
    nodeSize = 40,
    keyLength = 6, -- Default key length
    playerKey = "", -- Player's current key input
    keyFragments = {}, -- Key fragments to select from
    sparkles = {}, -- Visual effects
    fragmentSize = 60, -- Size of key fragment buttons
    
    -- Callbacks
    onSuccess = nil,
    onFailure = nil,
}

-- Generate a new puzzle
function HackMinigame.generatePuzzle()
    HackMinigame.nodes = {}
    HackMinigame.connections = {}
    HackMinigame.targetPath = {}
    HackMinigame.playerPath = {}
    HackMinigame.playerKey = ""
    HackMinigame.keyFragments = {}
    HackMinigame.sparkles = {}
    
    -- Generate a random target key (6 hex digits)
    local chars = "0123456789ABCDEF"
    HackMinigame.targetKey = ""
    for i = 1, HackMinigame.keyLength do
        HackMinigame.targetKey = HackMinigame.targetKey .. string.char(string.byte("0") + math.random(0, 15))
    end
    
    -- Generate key fragments (correct ones and decoys)
    local numFragments = 12
    local correctPositions = {}
    
    -- Add correct fragments
    for i = 1, HackMinigame.keyLength do
        local pos = math.random(1, numFragments)
        while correctPositions[pos] do
            pos = math.random(1, numFragments)
        end
        correctPositions[pos] = true
        
        table.insert(HackMinigame.keyFragments, {
            keyPiece = string.sub(HackMinigame.targetKey, i, i),
            position = i,
            isCorrect = true,
            selected = false,
            x = 0,
            y = 0
        })
    end
    
    -- Add decoy fragments
    for i = 1, numFragments - HackMinigame.keyLength do
        table.insert(HackMinigame.keyFragments, {
            keyPiece = string.char(string.byte("0") + math.random(0, 15)),
            position = 0,
            isCorrect = false,
            selected = false,
            x = 0,
            y = 0
        })
    end
    
    -- Shuffle the fragments
    for i = #HackMinigame.keyFragments, 2, -1 do
        local j = math.random(i)
        HackMinigame.keyFragments[i], HackMinigame.keyFragments[j] = HackMinigame.keyFragments[j], HackMinigame.keyFragments[i]
    end
    
    -- Create nodes in a grid
    for y = 1, HackMinigame.gridSize do
        for x = 1, HackMinigame.gridSize do
            table.insert(HackMinigame.nodes, {
                x = x,
                y = y,
                value = string.format("%X", math.random(0, 15)), -- Hex digit
                active = false,
                inPath = false
            })
        end
    end
    
    -- Generate a random path of 4-6 nodes
    local pathLength = 4 + math.random(3)
    local startNode = HackMinigame.getNode(1, math.random(1, HackMinigame.gridSize))
    local currentNode = startNode
    
    table.insert(HackMinigame.targetPath, {x = currentNode.x, y = currentNode.y})
    
    for i = 2, pathLength do
        local possibleMoves = {}
        local x, y = currentNode.x, currentNode.y
        
        -- Find all valid adjacent nodes
        for _, dir in ipairs({{0,1}, {1,0}, {0,-1}, {-1,0}}) do
            local nx, ny = x + dir[1], y + dir[2]
            if nx >= 1 and nx <= HackMinigame.gridSize and 
               ny >= 1 and ny <= HackMinigame.gridSize then
                local alreadyInPath = false
                for _, p in ipairs(HackMinigame.targetPath) do
                    if p.x == nx and p.y == ny then
                        alreadyInPath = true
                        break
                    end
                end
                if not alreadyInPath then
                    table.insert(possibleMoves, {x = nx, y = ny})
                end
            end
        end
        
        if #possibleMoves == 0 then break end -- No valid moves
        
        -- Choose random move
        local nextMove = possibleMoves[math.random(#possibleMoves)]
        table.insert(HackMinigame.targetPath, {x = nextMove.x, y = nextMove.y})
        currentNode = HackMinigame.getNode(nextMove.x, nextMove.y)
    end
    
    -- Mark nodes in path
    for _, pos in ipairs(HackMinigame.targetPath) do
        local node = HackMinigame.getNode(pos.x, pos.y)
        if node then node.inPath = true end
    end
end

-- Helper to get node at grid position
function HackMinigame.getNode(x, y)
    for _, node in ipairs(HackMinigame.nodes) do
        if node.x == x and node.y == y then
            return node
        end
    end
    return nil
end

-- Show the minigame
function HackMinigame.show(difficulty, onSuccess, onFailure)
    HackMinigame.visible = true
    HackMinigame.difficulty = math.max(1, math.min(5, difficulty or 1))
    HackMinigame.onSuccess = onSuccess
    HackMinigame.onFailure = onFailure
    HackMinigame.success = false
    HackMinigame.failed = false
    HackMinigame.timer = 0
    HackMinigame.maxTime = 15 - (HackMinigame.difficulty * 1.5) -- Less time for higher difficulty
    HackMinigame.animTime = 0
    HackMinigame.playerKey = ""
    HackMinigame.sparkles = {}
    
    -- Initialize key fragments and target key
    HackMinigame.generatePuzzle()
    
    -- Make sure keyFragments is initialized
    HackMinigame.keyFragments = HackMinigame.keyFragments or {}
    HackMinigame.keyLength = HackMinigame.keyLength or 6
end

-- Hide the minigame
function HackMinigame.hide()
    HackMinigame.visible = false
end

-- Update game state
function HackMinigame.update(dt)
    if not HackMinigame.visible or HackMinigame.success or HackMinigame.failed then return end
    
    HackMinigame.animTime = HackMinigame.animTime + dt
    HackMinigame.timer = HackMinigame.timer + dt
    
    -- Check for timeout
    if HackMinigame.timer >= HackMinigame.maxTime then
        HackMinigame.failed = true
        if HackMinigame.onFailure then
            HackMinigame.onFailure("Connection lost!")
        end
    end
end

-- Draw the minigame
function HackMinigame.draw()
    if not HackMinigame.visible then return end
    
    local sw, sh = Viewport.getDimensions()
    local panelW, panelH = 400, 450
    local panelX = (sw - panelW) / 2
    local panelY = (sh - panelH) / 2
    
    -- Background overlay
    Theme.setColor({0, 0, 0, 0.8})
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    
    -- Main panel
    Theme.drawGradientGlowRect(panelX, panelY, panelW, panelH, 8,
        Theme.colors.bg1, Theme.colors.bg0, Theme.colors.accent, Theme.effects.glowStrong)
    
    -- Title
    love.graphics.setFont(Theme.fonts.medium or love.graphics.getFont())
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.printf("SYSTEM BYPASS", panelX, panelY + 15, panelW, "center")
    
    -- Timer
    local timeLeft = math.max(0, HackMinigame.maxTime - HackMinigame.timer)
    local timeColor = timeLeft < 5 and {1, 0.2, 0.2} or {1, 1, 1}
    Theme.setColor(timeColor)
    love.graphics.printf(string.format("TIME: %.1fs", timeLeft), panelX, panelY + 50, panelW, "center")
    
    -- Draw grid background
    local gridSize = HackMinigame.gridSize * (HackMinigame.nodeSize + 10) + 10
    local gridX = panelX + (panelW - gridSize) / 2
    local gridY = panelY + 100
    
    Theme.setColor(Theme.colors.bg2)
    love.graphics.rectangle("fill", gridX, gridY, gridSize, gridSize, 4)
    
    -- Draw connections
    for i = 1, #HackMinigame.playerPath - 1 do
        local node1 = HackMinigame.getNode(HackMinigame.playerPath[i].x, HackMinigame.playerPath[i].y)
        local node2 = HackMinigame.getNode(HackMinigame.playerPath[i+1].x, HackMinigame.playerPath[i+1].y)
        
        if node1 and node2 then
            local x1 = gridX + (node1.x - 0.5) * (HackMinigame.nodeSize + 10) + 5
            local y1 = gridY + (node1.y - 0.5) * (HackMinigame.nodeSize + 10) + 5
            local x2 = gridX + (node2.x - 0.5) * (HackMinigame.nodeSize + 10) + 5
            local y2 = gridY + (node2.y - 0.5) * (HackMinigame.nodeSize + 10) + 5
            
            -- Draw connection line with glow
            local progress = (HackMinigame.animTime * 2) % 1
            local midX = x1 + (x2 - x1) * progress
            local midY = y1 + (y2 - y1) * progress
            
            Theme.setColor(Theme.colors.accent)
            love.graphics.setLineWidth(2)
            love.graphics.line(x1, y1, x2, y2)
            
            -- Draw moving dot
            Theme.setColor(Theme.colors.highlight)
            love.graphics.circle("fill", midX, midY, 3)
        end
    end
    
    -- Timer bar
    local timerBarW = panelW - 40
    local timerBarH = 8
    local timerBarX = panelX + 20
    local timerBarY = panelY + 80

    Theme.setColor(Theme.colors.bg3)
    love.graphics.rectangle("fill", timerBarX, timerBarY, timerBarW, timerBarH)

    local timerProgress = 1 - (HackMinigame.timer / HackMinigame.maxTime)
    local timerColor = timerProgress > 0.3 and Theme.colors.accent or Theme.colors.danger
    Theme.setColor(timerColor)
    love.graphics.rectangle("fill", timerBarX, timerBarY, timerBarW * timerProgress, timerBarH)

    -- Show target key pattern (obscured)
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.setFont(Theme.fonts.small or love.graphics.getFont())
    love.graphics.printf("TARGET KEY: " .. string.rep("?", HackMinigame.keyLength), panelX, panelY + 100, panelW, "center")

    -- Show reconstructed key so far
    if #HackMinigame.playerKey > 0 then
        Theme.setColor(Theme.colors.accent)
        love.graphics.printf("DECRYPTED: " .. HackMinigame.playerKey .. string.rep("?", HackMinigame.keyLength - #HackMinigame.playerKey), panelX, panelY + 120, panelW, "center")
    end

    -- Game area for key fragments
    local gameAreaX = panelX + 30
    local gameAreaY = panelY + 150
    local gameAreaW = panelW - 60
    local gameAreaH = panelH - 200

    -- Calculate fragment positions
    local fragmentsPerRow = math.min(4, #HackMinigame.keyFragments)
    local rows = math.ceil(#HackMinigame.keyFragments / fragmentsPerRow)
    local fragmentSpacing = gameAreaW / fragmentsPerRow
    local rowSpacing = gameAreaH / rows

    -- Draw key fragments
    HackMinigame.keyFragments = HackMinigame.keyFragments or {}
    for i, fragment in ipairs(HackMinigame.keyFragments) do
        local col = ((i - 1) % fragmentsPerRow)
        local row = math.floor((i - 1) / fragmentsPerRow)

        local x = gameAreaX + col * fragmentSpacing + fragmentSpacing / 2
        local y = gameAreaY + row * rowSpacing + rowSpacing / 2

        fragment.x = x
        fragment.y = y

        -- Fragment background with glow
        local bgColor = fragment.selected and Theme.colors.success or Theme.colors.bg2
        local glowAmount = fragment.glowing or 1
        local bgAlpha = bgColor[4] or 1

        Theme.setColor({bgColor[1], bgColor[2], bgColor[3], bgAlpha * glowAmount})
        love.graphics.rectangle("fill", x - HackMinigame.fragmentSize/2, y - HackMinigame.fragmentSize/2,
                               HackMinigame.fragmentSize, HackMinigame.fragmentSize, 4)

        -- Fragment border
        local borderColor = fragment.isCorrect and {0.2, 1.0, 0.4, 0.8} or {1.0, 0.6, 0.2, 0.8}
        if fragment.selected then
            borderColor = Theme.colors.success
        end

        Theme.setColor(borderColor)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x - HackMinigame.fragmentSize/2, y - HackMinigame.fragmentSize/2,
                               HackMinigame.fragmentSize, HackMinigame.fragmentSize, 4)

        -- Draw pattern visualization
        if fragment.pattern then
            for j, patternChar in ipairs(fragment.pattern) do
                local charX = x - HackMinigame.fragmentSize/2 + 8 + (j-1) * 10
                local charY = y - 15

                -- Character
                love.graphics.setFont(Theme.fonts.small or love.graphics.getFont())
                Theme.setColor(patternChar.color)
                love.graphics.print(patternChar.char, charX, charY)

                -- Mini bar chart under character
                for k, barHeight in ipairs(patternChar.bars) do
                    local barX = charX + k
                    local barY = charY + 15
                    local barH = barHeight * 12

                    Theme.setColor({patternChar.color[1], patternChar.color[2], patternChar.color[3], patternChar.intensity})
                    love.graphics.rectangle("fill", barX, barY - barH, 1, barH)
                end
            end
        end

        -- Fragment ID for debugging (small)
        Theme.setColor(Theme.colors.textTertiary)
        love.graphics.setFont(Theme.fonts.tiny or Theme.fonts.small or love.graphics.getFont())
        love.graphics.print(fragment.keyPiece, x - 20, y + 20)
    end

    -- Draw sparkles
    for _, sparkle in ipairs(HackMinigame.sparkles) do
        local alpha = sparkle.life / sparkle.maxLife
        Theme.setColor({1, 1, 1, alpha})
        love.graphics.circle("fill", sparkle.x, sparkle.y, 2 * alpha)
    end

    -- Progress indicator
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.setFont(Theme.fonts.small or love.graphics.getFont())
    local correctFragments = 0
    for _, fragment in ipairs(HackMinigame.keyFragments) do
        if fragment.selected and fragment.isCorrect then
            correctFragments = correctFragments + 1
        end
    end
    local progressText = string.format("Key Progress: %d/%d fragments", #HackMinigame.playerKey, HackMinigame.keyLength)
    love.graphics.print(progressText, panelX + 20, panelY + panelH - 40)

    -- Success/failure message
    if HackMinigame.success or HackMinigame.failed then
        Theme.setColor(HackMinigame.success and Theme.colors.success or Theme.colors.danger)
        love.graphics.setFont(Theme.fonts.large or love.graphics.getFont())
        local message = HackMinigame.success and "ACCESS GRANTED!" or "DECRYPTION FAILED!"
        love.graphics.printf(message, panelX, panelY + panelH/2 - 20, panelW, "center")
    end
end

function HackMinigame.mousepressed(x, y, button)
    if not HackMinigame.visible or HackMinigame.success or HackMinigame.failed then
        return false
    end

    if button == 1 then
        -- Check fragment clicks
        HackMinigame.keyFragments = HackMinigame.keyFragments or {}
        for i, fragment in ipairs(HackMinigame.keyFragments) do
            if fragment.x and fragment.y then
                local hitX = fragment.x - HackMinigame.fragmentSize/2
                local hitY = fragment.y - HackMinigame.fragmentSize/2
                local hitW = HackMinigame.fragmentSize
                local hitH = HackMinigame.fragmentSize

                if x >= hitX and x <= hitX + hitW and y >= hitY and y <= hitY + hitH then
                    if not fragment.selected then
                        -- Fragment clicked - check if it's correct
                        if fragment.isCorrect then
                            -- Correct fragment selected
                            fragment.selected = true
                            HackMinigame.playerKey = HackMinigame.playerKey .. fragment.keyPiece
                            HackMinigame.glitchEffect = 0.5

                            -- Add sparkle effect
                            for j = 1, 12 do
                                table.insert(HackMinigame.sparkles, {
                                    x = fragment.x + math.random(-30, 30),
                                    y = fragment.y + math.random(-30, 30),
                                    life = 1.5,
                                    maxLife = 1.5
                                })
                            end

                            -- Check if puzzle is complete
                            if #HackMinigame.playerKey >= HackMinigame.keyLength then
                                -- Check if the reconstructed key matches the target
                                local sortedFragments = {}
                                for _, frag in ipairs(HackMinigame.keyFragments) do
                                    if frag.selected and frag.isCorrect then
                                        table.insert(sortedFragments, {position = frag.position, keyPiece = frag.keyPiece})
                                    end
                                end

                                -- Sort by position
                                table.sort(sortedFragments, function(a, b) return a.position < b.position end)

                                -- Reconstruct the key in order
                                local reconstructedKey = ""
                                for _, frag in ipairs(sortedFragments) do
                                    reconstructedKey = reconstructedKey .. frag.keyPiece
                                end

                                if reconstructedKey == HackMinigame.targetKey then
                                    HackMinigame.success = true
                                    if HackMinigame.onSuccess then
                                        HackMinigame.onSuccess()
                                    end
                                else
                                    HackMinigame.failed = true
                                    if HackMinigame.onFailure then
                                        HackMinigame.onFailure("Invalid key sequence!")
                                    end
                                end
                            end
                        else
                            -- Wrong fragment clicked
                            fragment.selected = true
                            HackMinigame.glitchEffect = 1.0
                            HackMinigame.failed = true
                            if HackMinigame.onFailure then
                                HackMinigame.onFailure("Decoy fragment triggered security lockdown!")
                            end
                        end
                    end

                    return true
                end
            end
        end
    end

    return true -- Consume all clicks when visible
end

function HackMinigame.keypressed(key)
    if not HackMinigame.visible then return false end

    if key == "escape" or (key == "space" and (HackMinigame.success or HackMinigame.failed)) then
        HackMinigame.hide()
        return true
    end

    return true
end

return HackMinigame