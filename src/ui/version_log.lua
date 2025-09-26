local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Strings = require("src.core.strings")
local ScrollArea = require("src.ui.common.scroll_area")
local Json = require("src.libs.json")

local VersionLog = {
    visible = false,
    window = nil,
    commits = nil,
    errorMessage = nil,
    loading = false,
    scrollY = 0,
    scrollGeom = nil,
    bounds = nil,
    closeDown = false,
    lastRefresh = nil,
    closing = false,
    fallbackPath = "content/version_log.json",
    layoutCache = {
        width = nil,
        count = 0,
        entries = {},
        totalHeight = 0,
    },
    scrollState = {
        dragging = false,
        dragOffset = 0,
    },
}

local REFRESH_INTERVAL = 60
local ENTRY_PADDING_Y = 12
local ENTRY_SPACING = 12

local function measureEntryWidth(text)
    local font = Theme.fonts.normal
    love.graphics.setFont(font)
    return font:getWidth(text)
end

local function loadFallbackCommits()
    if love and love.filesystem and love.filesystem.getInfo then
        if love.filesystem.getInfo(VersionLog.fallbackPath) then
            local ok, contents = pcall(love.filesystem.read, VersionLog.fallbackPath)
            if ok and contents then
                local success, data = pcall(Json.decode, contents)
                if success and type(data) == "table" then
                    return data, nil
                else
                    return nil, "fallback_invalid"
                end
            else
                return nil, "fallback_read_error"
            end
        end
    end
    return nil, "fallback_missing"
end

local function clampScroll()
    local maxScroll = (VersionLog.scrollGeom and VersionLog.scrollGeom.maxScroll) or 0
    if maxScroll <= 0 then
        VersionLog.scrollY = 0
        return
    end
    VersionLog.scrollY = math.max(0, math.min(maxScroll, VersionLog.scrollY))
end

local function pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

local function getRepoDir()
    if not love or not love.filesystem then return nil end
    if love.filesystem.getSourceBaseDirectory then
        local base = love.filesystem.getSourceBaseDirectory()
        if base and base ~= "" then
            return base
        end
    end
    if love.filesystem.getWorkingDirectory then
        local cwd = love.filesystem.getWorkingDirectory()
        if cwd and cwd ~= "" then
            return cwd
        end
    end
    return nil
end

local function buildGitCommand(limit)
    local gitArgs = string.format("git --no-pager log -n %d --pretty=format:%%h%%x1f%%s%%x1f%%cr", limit)
    local repoDir = getRepoDir()
    local isWindows = package.config and package.config:sub(1, 1) == "\\"

    if isWindows then
        if repoDir then
            return string.format('cmd /c "cd /d "%s" && %s"', repoDir, gitArgs)
        else
            return string.format('cmd /c "%s"', gitArgs)
        end
    else
        if repoDir then
            return string.format('cd "%s" && %s', repoDir, gitArgs)
        else
            return gitArgs
        end
    end
end

local function readGitCommits(limit)
    if not io or not io.popen then
        return nil, "io_popen_missing"
    end

    local command = buildGitCommand(limit)
    local ok, handle = pcall(io.popen, command)
    if not ok or not handle then
        return nil, "git_unavailable"
    end

    local output = handle:read("*a") or ""
    handle:close()

    if output == "" then
        return {}, nil
    end

    local commits = {}
    for line in string.gmatch(output, "[^\r\n]+") do
        local clean = line
        local hash, subject, relative = clean:match("([^\31]+)\31([^\31]+)\31(.+)")
        if not hash then
            hash, subject, relative = clean:match("([^\t]+)\t([^\t]+)\t(.+)")
        end
        if hash and subject and relative then
            commits[#commits + 1] = {
                hash = hash,
                subject = subject,
                relative = relative,
            }
        end
    end

    return commits, nil
end

function VersionLog.refresh(force)
    if VersionLog.loading then
        return
    end

    local now = love.timer and love.timer.getTime and love.timer.getTime() or os.time()
    if not force and VersionLog.lastRefresh and now - VersionLog.lastRefresh < REFRESH_INTERVAL then
        return
    end

    VersionLog.loading = true
    VersionLog.errorMessage = nil

    local commits, err = readGitCommits(20)
    if (not commits or #commits == 0) then
        local fallback, fallbackErr = loadFallbackCommits()
        if fallback then
            commits = fallback
            err = nil
        else
            commits = commits or {}
            err = err or fallbackErr
        end
    end

    if commits then
        VersionLog.commits = commits
        VersionLog.scrollY = 0
    else
        VersionLog.commits = {}
        VersionLog.errorMessage = err or "unknown"
    end

    VersionLog.loading = false
    VersionLog.lastRefresh = now
end

function VersionLog.showWindow(window)
    VersionLog.window = window
end

function VersionLog.open()
    VersionLog.visible = true
    VersionLog.refresh(true)
    if VersionLog.window then
        VersionLog.window:show()
    end
end

function VersionLog.close()
    if VersionLog.closing then return end
    VersionLog.closing = true
    VersionLog.visible = false
    VersionLog.closeDown = false
    if VersionLog.window then
        VersionLog.window:hide()
    end
    VersionLog.closing = false
end

function VersionLog.toggle()
    if VersionLog.visible then
        VersionLog.close()
    else
        VersionLog.open()
    end
end

local function drawStatusMessage(x, y, w, message)
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.printf(message, x, y + ((VersionLog.scrollGeom and VersionLog.scrollGeom.viewH) or 0) * 0.5 - 12, w, "center")
end

function VersionLog.draw(x, y, w, h)
    if not VersionLog.visible then
        return
    end

    local padding = (Theme.ui and Theme.ui.contentPadding) or 16
    local panelX = x + padding
    local panelY = y + padding
    local panelW = math.max(0, w - padding * 2)
    local panelH = math.max(0, h - padding * 2)

    if panelW <= 0 or panelH <= 0 then
        return
    end

    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH)

    local listInset = 12
    local listX = panelX + listInset
    local listY = panelY + listInset
    local listW = panelW - listInset * 2
    local listH = panelH - listInset * 2

    if listW <= 0 or listH <= 0 then
        return
    end

    local totalContentHeight = VersionLog.layoutCache.totalHeight
    if not totalContentHeight or VersionLog.layoutCache.width ~= listW or VersionLog.layoutCache.count ~= (VersionLog.commits and #VersionLog.commits or 0) then
        VersionLog.layoutCache.width = listW
        VersionLog.layoutCache.count = VersionLog.commits and #VersionLog.commits or 0
        VersionLog.layoutCache.entries = {}
        totalContentHeight = 0
        if VersionLog.commits then
            local font = Theme.fonts.normal
            local lineHeight = font:getHeight()
            local availableWidth = listW - 24
            love.graphics.setFont(font)
            for _, commit in ipairs(VersionLog.commits) do
                local subject = commit.subject or ""
                local wrapText, lineList = font:getWrap(subject, availableWidth)
                lineList = lineList or {}
                local lineCount = #lineList
                if lineCount == 0 then lineCount = 1 end
                local entryHeight = ENTRY_PADDING_Y * 2 + lineHeight * lineCount + lineHeight -- include relative line
                totalContentHeight = totalContentHeight + entryHeight + ENTRY_SPACING
                table.insert(VersionLog.layoutCache.entries, {
                    lines = lineList,
                    height = entryHeight,
                    relative = commit.relative or "",
                    subject = subject,
                })
            end
            if totalContentHeight > 0 then
                totalContentHeight = totalContentHeight - ENTRY_SPACING
            end
        end
        VersionLog.layoutCache.totalHeight = totalContentHeight
    end

    local contentHeight = math.max(totalContentHeight, listH)

    local mx, my = Viewport.getMousePosition()
    local draggingThumb = VersionLog.scrollState and VersionLog.scrollState.dragging
    VersionLog.scrollY, VersionLog.scrollGeom = ScrollArea.draw(listX, listY, listW, listH, contentHeight, VersionLog.scrollY, {
        dragging = draggingThumb,
        dragOffset = VersionLog.scrollState and VersionLog.scrollState.dragOffset or 0,
        mouseY = my,
    })
    VersionLog.scrollState = VersionLog.scrollState or { dragging = false, dragOffset = 0 }
    VersionLog.scrollGeom.viewH = listH
    VersionLog.bounds = { x = listX, y = listY, w = listW, h = listH }
    clampScroll()

    love.graphics.setScissor(listX, listY, listW, listH)
    love.graphics.setFont(Theme.fonts.normal)

    if VersionLog.loading then
        love.graphics.setFont(Theme.fonts.small)
        drawStatusMessage(listX, listY, listW - 16, Strings.getUI("version_log_loading"))
        love.graphics.setFont(Theme.fonts.normal)
    elseif VersionLog.errorMessage == "io_popen_missing" or VersionLog.errorMessage == "git_unavailable" then
        love.graphics.setFont(Theme.fonts.small)
        drawStatusMessage(listX, listY, listW - 16, Strings.getUI("version_log_git_missing"))
        love.graphics.setFont(Theme.fonts.normal)
    elseif VersionLog.errorMessage == "fallback_missing" or VersionLog.errorMessage == "fallback_read_error" or VersionLog.errorMessage == "fallback_invalid" then
        love.graphics.setFont(Theme.fonts.small)
        drawStatusMessage(listX, listY, listW - 16, Strings.getUI("version_log_fallback_missing"))
        love.graphics.setFont(Theme.fonts.normal)
    elseif VersionLog.errorMessage then
        love.graphics.setFont(Theme.fonts.small)
        drawStatusMessage(listX, listY, listW - 16, Strings.getUI("version_log_error"))
        love.graphics.setFont(Theme.fonts.normal)
    elseif not VersionLog.commits or #VersionLog.commits == 0 then
        love.graphics.setFont(Theme.fonts.small)
        drawStatusMessage(listX, listY, listW - 16, Strings.getUI("version_log_empty"))
        love.graphics.setFont(Theme.fonts.normal)
    else
        local font = Theme.fonts.normal
        local lineHeight = font:getHeight()
        love.graphics.setFont(font)
        local rowY = listY - VersionLog.scrollY
        local rightInset = VersionLog.scrollGeom.track and (VersionLog.scrollGeom.track.w + 8) or 0
        -- Leave space for the scrollbar track if present
        local panelWidth = math.max(0, listW - rightInset)
        local textX = listX + 16

        for _, entry in ipairs(VersionLog.layoutCache.entries) do
            local entryTop = rowY
            local entryBottom = rowY + entry.height
            if entryBottom >= listY - ENTRY_SPACING and entryTop <= listY + listH + ENTRY_SPACING then
                Theme.setColor(Theme.colors.textSecondary)
                love.graphics.print(entry.relative, textX, entryTop + ENTRY_PADDING_Y)

                Theme.setColor(Theme.colors.text)
                local subjectY = entryTop + ENTRY_PADDING_Y + lineHeight
                for _, line in ipairs(entry.lines) do
                    love.graphics.print(line, textX, subjectY)
                    subjectY = subjectY + lineHeight
                end
            end
            rowY = rowY + entry.height + ENTRY_SPACING
        end
    end

    love.graphics.setScissor()
end

function VersionLog.mousepressed(mx, my, button)
    if not VersionLog.visible then
        return false
    end

    VersionLog.scrollState = VersionLog.scrollState or { dragging = false, dragOffset = 0 }

    if VersionLog.window and VersionLog.window:mousepressed(mx, my, button) then
        return true
    end

    if button == 1 and VersionLog.scrollGeom and VersionLog.scrollGeom.thumb then
        local thumb = VersionLog.scrollGeom.thumb
        if pointInRect(mx, my, thumb.x, thumb.y, thumb.w, thumb.h) then
            VersionLog.scrollState.dragging = true
            VersionLog.scrollState.dragOffset = my - thumb.y
            return true
        elseif pointInRect(mx, my, VersionLog.scrollGeom.track.x, VersionLog.scrollGeom.track.y, VersionLog.scrollGeom.track.w, VersionLog.scrollGeom.track.h) then
            local track = VersionLog.scrollGeom.track
            local thumbHeight = VersionLog.scrollGeom.thumb.h
            local clampedY = math.max(track.y, math.min(track.y + track.h - thumbHeight, my - thumbHeight * 0.5))
            local t = (clampedY - track.y) / (track.h - thumbHeight)
            VersionLog.scrollY = t * (VersionLog.scrollGeom.maxScroll or 0)
            clampScroll()
            VersionLog.scrollState.dragging = true
            VersionLog.scrollState.dragOffset = my - clampedY
            return true
        end
    end

    return false
end

function VersionLog.mousereleased(mx, my, button)
    if not VersionLog.visible then
        return false
    end
    local windowHandled = VersionLog.window and VersionLog.window:mousereleased(mx, my, button)

    if button == 1 and VersionLog.scrollState then
        local wasDragging = VersionLog.scrollState.dragging
        VersionLog.scrollState.dragging = false
        VersionLog.scrollState.dragOffset = 0
        if wasDragging then
            return true
        end
    end

    return windowHandled or false
end

function VersionLog.mousemoved(mx, my, dx, dy)
    if not VersionLog.visible then
        return false
    end
    if VersionLog.window and VersionLog.window:mousemoved(mx, my, dx, dy) then
        return true
    end

    if VersionLog.scrollState and VersionLog.scrollState.dragging and VersionLog.scrollGeom and VersionLog.scrollGeom.track then
        local track = VersionLog.scrollGeom.track
        local thumb = VersionLog.scrollGeom.thumb
        if not thumb then return false end

        local range = track.h - thumb.h
        if range <= 0 then return false end

        local newThumbY = math.max(track.y, math.min(track.y + range, my - VersionLog.scrollState.dragOffset))
        local t = (newThumbY - track.y) / range
        VersionLog.scrollY = t * (VersionLog.scrollGeom.maxScroll or 0)
        clampScroll()
        VersionLog.scrollState.dragging = true
        return true
    end

    return false
end

function VersionLog.wheelmoved(x, y, dx, dy)
    if not VersionLog.visible then
        return false
    end

    if not VersionLog.scrollGeom then
        return false
    end
    if VersionLog.scrollState and VersionLog.scrollState.dragging then
        return false
    end
    if VersionLog.bounds then
        if not pointInRect(x, y, VersionLog.bounds.x, VersionLog.bounds.y, VersionLog.bounds.w, VersionLog.bounds.h) then
            return false
        end
    end
    if dy ~= 0 then
        VersionLog.scrollY = VersionLog.scrollY - dy * 32
        clampScroll()
        return true
    end
    return false
end

function VersionLog.keypressed(key)
    if not VersionLog.visible then
        return false
    end
    if VersionLog.window and VersionLog.window:keypressed(key) then
        return true
    end
    if key == "r" or key == "R" then
        VersionLog.refresh(true)
        return true
    end
    if key == "escape" then
        VersionLog.close()
        return true
    end
    return false
end

function VersionLog.update(dt)
    if VersionLog.window and VersionLog.window.update then
        VersionLog.window:update(dt)
    end
end

return VersionLog

