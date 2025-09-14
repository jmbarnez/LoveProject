local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Util = require("src.core.util")

local HackMinigame = {
    visible = false,
    keyFragments = {},
    targetKey = "",
    playerKey = "",
    currentFragmentIndex = 1,
    difficulty = 1,
    timer = 0,
    maxTime = 20,
    success = false,
    failed = false,
    animTime = 0,
    sparkles = {},
    glitchEffect = 0,

    -- Callbacks
    onSuccess = nil,
    onFailure = nil,

    -- Visual effects
    fragmentSize = 60,
    keyLength = 8,
}


function HackMinigame.show(difficulty, onSuccess, onFailure)
    HackMinigame.visible = true
    HackMinigame.difficulty = math.max(1, math.min(5, difficulty or 1))
    HackMinigame.onSuccess = onSuccess
    HackMinigame.onFailure = onFailure

    HackMinigame.success = false
    HackMinigame.failed = false
    HackMinigame.timer = 0
    HackMinigame.maxTime = 18 + (HackMinigame.difficulty * 3) -- More time for harder puzzles
    HackMinigame.animTime = 0
    HackMinigame.currentFragmentIndex = 1
    HackMinigame.playerKey = ""
    HackMinigame.sparkles = {}
    HackMinigame.glitchEffect = 0

    HackMinigame.generatePuzzle()
end

function HackMinigame.hide()
    HackMinigame.visible = false
    HackMinigame.keyFragments = {}
    HackMinigame.targetKey = ""
    HackMinigame.playerKey = ""
    HackMinigame.sparkles = {}
end

function HackMinigame.generatePuzzle()
    HackMinigame.keyFragments = {}
    HackMinigame.targetKey = ""
    HackMinigame.playerKey = ""

    -- Generate target encryption key
    local keyChars = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"}
    HackMinigame.keyLength = 6 + HackMinigame.difficulty -- 7-11 character key

    for i = 1, HackMinigame.keyLength do
        HackMinigame.targetKey = HackMinigame.targetKey .. keyChars[math.random(#keyChars)]
    end

    -- Create encrypted fragments with patterns
    local fragmentCount = 4 + HackMinigame.difficulty -- 5-9 fragments to choose from
    local correctFragmentCount = math.min(HackMinigame.keyLength, 4 + math.floor(HackMinigame.difficulty / 2))

    -- Generate all fragments (correct + decoy)
    for i = 1, fragmentCount do
        local fragment = {}

        if i <= correctFragmentCount then
            -- Correct fragment - contains actual key piece
            local startPos = math.floor((i - 1) * HackMinigame.keyLength / correctFragmentCount) + 1
            local endPos = math.floor(i * HackMinigame.keyLength / correctFragmentCount)

            fragment.isCorrect = true
            fragment.keyPiece = HackMinigame.targetKey:sub(startPos, endPos)
            fragment.position = i
            fragment.pattern = HackMinigame.generatePattern(fragment.keyPiece, true)
        else
            -- Decoy fragment - looks similar but wrong
            fragment.isCorrect = false
            fragment.keyPiece = ""
            for j = 1, math.random(2, 4) do
                fragment.keyPiece = fragment.keyPiece .. keyChars[math.random(#keyChars)]
            end
            fragment.pattern = HackMinigame.generatePattern(fragment.keyPiece, false)
        end

        fragment.id = i
        fragment.x = 0 -- Will be set during draw
        fragment.y = 0
        fragment.selected = false
        fragment.glowing = false

        table.insert(HackMinigame.keyFragments, fragment)
    end

    -- Shuffle fragments
    for i = #HackMinigame.keyFragments, 2, -1 do
        local j = math.random(i)
        HackMinigame.keyFragments[i], HackMinigame.keyFragments[j] = HackMinigame.keyFragments[j], HackMinigame.keyFragments[i]
    end
end

function HackMinigame.generatePattern(keyPiece, isCorrect)
    -- Generate a visual pattern that represents the key fragment
    local pattern = {}

    for i = 1, #keyPiece do
        local char = keyPiece:sub(i, i)
        local value = tonumber(char, 16) or 0

        -- Create visual pattern based on hex value
        table.insert(pattern, {
            char = char,
            intensity = value / 15, -- 0-1 range
            color = isCorrect and {0.2, 1.0, 0.4} or {1.0, 0.6, 0.2}, -- Green for correct, orange for decoy
            bars = {}
        })

        -- Generate mini bar chart for each character
        for j = 1, 4 do
            table.insert(pattern[i].bars, (value % (j + 1)) / j * 0.8 + 0.2)
        end
    end

    return pattern
end

function HackMinigame.update(dt)
    if not HackMinigame.visible then return end

    HackMinigame.animTime = HackMinigame.animTime + dt

    -- Update timer
    if not HackMinigame.success and not HackMinigame.failed then
        HackMinigame.timer = HackMinigame.timer + dt
        if HackMinigame.timer >= HackMinigame.maxTime then
            HackMinigame.failed = true
            if HackMinigame.onFailure then
                HackMinigame.onFailure("Decryption timeout!")
            end
        end
    end

    -- Update sparkle effects
    for i = #HackMinigame.sparkles, 1, -1 do
        local sparkle = HackMinigame.sparkles[i]
        sparkle.life = sparkle.life - dt
        sparkle.y = sparkle.y - dt * 30
        sparkle.x = sparkle.x + math.sin(sparkle.life * 10) * 20 * dt
        if sparkle.life <= 0 then
            table.remove(HackMinigame.sparkles, i)
        end
    end

    -- Update glitch effects
    HackMinigame.glitchEffect = math.max(0, HackMinigame.glitchEffect - dt * 3)

    -- Update fragment glowing effect
    for i, fragment in ipairs(HackMinigame.keyFragments) do
        if fragment.selected then
            fragment.glowing = math.sin(HackMinigame.animTime * 12) * 0.3 + 0.7
        else
            fragment.glowing = math.sin(HackMinigame.animTime * 4 + i) * 0.1 + 0.9
        end
    end
end

function HackMinigame.draw()
    if not HackMinigame.visible then return end

    local sw, sh = Viewport.getDimensions()
    local panelW, panelH = 600, 500
    local panelX = (sw - panelW) / 2
    local panelY = (sh - panelH) / 2

    -- Background overlay
    Theme.setColor({0, 0, 0, 0.8})
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- Main panel
    Theme.drawGradientGlowRect(panelX, panelY, panelW, panelH, 8,
        Theme.colors.bg1, Theme.colors.bg0, Theme.colors.accent, Theme.effects.glowStrong)

    -- Title
    love.graphics.setFont(Theme.fonts.large or love.graphics.getFont())
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.printf("ENCRYPTED WALLET DECRYPTION", panelX, panelY + 20, panelW, "center")

    -- Instructions
    love.graphics.setFont(Theme.fonts.small or love.graphics.getFont())
    Theme.setColor(Theme.colors.textSecondary)
    local instruction = HackMinigame.success and "DECRYPTION COMPLETE!" or
                       HackMinigame.failed and "SECURITY LOCKOUT ACTIVATED!" or
                       "Decrypt the access key: Select the correct cipher fragments in order"
    love.graphics.printf(instruction, panelX, panelY + 55, panelW, "center")

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