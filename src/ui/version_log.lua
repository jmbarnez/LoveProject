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
    fallbackWriteError = nil,
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
local ENTRY_PADDING_Y = 16
local ENTRY_SPACING = 24
local BODY_PARAGRAPH_SPACING = 10
local BULLET_LINE_SPACING = 6
local TEXT_LEFT_MARGIN = 16
local TEXT_RIGHT_PADDING = 12
local BULLET_INDENT = 12
local SCROLL_TRACK_WIDTH = 8
local SCROLL_EXTRA_GAP = 8
local PATH_SEPARATOR = package.config and package.config:sub(1, 1) or "/"

local function getCommitGroupCount(data)
    if type(data) ~= "table" then
        return 0
    end
    local order = data.order
    if type(order) ~= "table" then
        return 0
    end
    return #order
end

local function hasCommitData(data)
    return getCommitGroupCount(data) > 0
end

local function measureEntryWidth(text)
    local font = Theme.fonts.normal
    love.graphics.setFont(font)
    return font:getWidth(text)
end

local function wrapText(font, text, width)
    if not text or text == "" then
        return { "" }
    end
    if width and width > 0 then
        local wraps = { font:getWrap(text, width) }
        local lines = wraps[1]
        if type(lines) == "table" and #lines > 0 then
            return lines
        end
    end
    return { text }
end

local function normalizeFallbackCommits(data)
    if type(data) ~= "table" then
        return nil, "fallback_invalid"
    end

    -- Already normalized data (grouped/order) can be returned directly.
    if data.grouped and data.order then
        return data, nil
    end

    local grouped = {}
    local order = {}

    local function collectBodyLines(value)
        local lines = {}
        if type(value) == "string" then
            for line in value:gmatch("[^\r\n]+") do
                if line:match("%S") then
                    table.insert(lines, line)
                end
            end
        elseif type(value) == "table" then
            for _, entry in ipairs(value) do
                if type(entry) == "string" and entry:match("%S") then
                    table.insert(lines, entry)
                end
            end
        end
        return lines
    end

    for index, entry in ipairs(data) do
        if type(entry) == "table" and (entry.subject or entry.version) then
            local bodyLines = {}
            if entry.details then
                local lines = collectBodyLines(entry.details)
                for _, line in ipairs(lines) do table.insert(bodyLines, line) end
            end
            if entry.body then
                local lines = collectBodyLines(entry.body)
                for _, line in ipairs(lines) do table.insert(bodyLines, line) end
            end
            if entry.notes then
                local lines = collectBodyLines(entry.notes)
                for _, line in ipairs(lines) do table.insert(bodyLines, line) end
            end

            local versionKey = entry.version or "Unreleased"
            if not grouped[versionKey] then
                grouped[versionKey] = {}
                table.insert(order, versionKey)
            end

            local commit = {
                hash = entry.hash or string.format("fallback_%d", index),
                short = entry.short or entry.relative or string.format("#%d", index),
                author = entry.author or "",
                date = entry.date or entry.relative or "",
                subject = entry.subject or string.format("Entry %d", index),
                bodyLines = bodyLines,
            }

            table.insert(grouped[versionKey], commit)
        end
    end

    if #order == 0 then
        return nil, "fallback_invalid"
    end

    return { grouped = grouped, order = order }, nil
end

local function loadFallbackCommits()
    local file = love and love.filesystem
    if file and file.getInfo and file.getInfo(VersionLog.fallbackPath) then
        local ok, contents = pcall(file.read, VersionLog.fallbackPath)
        if ok and contents then
            local success, data = pcall(Json.decode, contents)
            if success then
                return normalizeFallbackCommits(data)
            end
            return nil, "fallback_invalid"
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
    local gitArgs = string.format("git --no-pager log -n %d --date=short --pretty=format:%%H%%x1f%%h%%x1f%%an%%x1f%%ad%%x1f%%s%%x1f%%b%%x1e", limit)
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

    local grouped = {}
    local order = {}
    local function getVersionForSubject(subject)
        if not subject then return "Unreleased" end
        local tag = subject:match("^%s*v?(%d+%.%d+)")
        if not tag then
            if subject:lower():find("bump version" ) or subject:lower():find("release") then
                tag = subject
            end
        end
        return tag or "Unreleased"
    end

    for entry in (output .. "\30"):gmatch("(.-)\30") do
        if entry and entry ~= "" then
            local hash, shortHash, author, date, subject, body = entry:match("([^\31]*)\31([^\31]*)\31([^\31]*)\31([^\31]*)\31([^\31]*)\31(.*)")
            if hash and subject then
                body = body or ""
                body = body:gsub("\r", "")
                local bodyLines = {}
                for line in (body .. "\n"):gmatch("(.-)\n") do
                    if line:match("%S") then
                        table.insert(bodyLines, line)
                    end
                end

                local versionKey = getVersionForSubject(subject)
                if not grouped[versionKey] then
                    grouped[versionKey] = {}
                    table.insert(order, 1, versionKey)
                end
                table.insert(grouped[versionKey], {
                    hash = hash,
                    short = shortHash or hash:sub(1, 7),
                    author = author or "",
                    date = date or "",
                    subject = subject,
                    bodyLines = bodyLines,
                })
            end
        end
    end

    return { grouped = grouped, order = order }, nil
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

    local commits, err = loadFallbackCommits()
    if not hasCommitData(commits) then
        VersionLog.commits = {}
        VersionLog.errorMessage = err or "fallback_missing"
    else
        VersionLog.commits = commits
        VersionLog.scrollY = 0
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
    local listW = math.max(0, panelW - listInset * 2)
    local listH = panelH - listInset * 2

    if listW <= 0 or listH <= 0 then
        return
    end

    local totalContentHeight = VersionLog.layoutCache.totalHeight
    local commitGroupCount = getCommitGroupCount(VersionLog.commits)
    if not totalContentHeight or VersionLog.layoutCache.width ~= listW or VersionLog.layoutCache.count ~= commitGroupCount then
        VersionLog.layoutCache.width = listW
        local commitData = VersionLog.commits
        VersionLog.layoutCache.count = commitGroupCount
        VersionLog.layoutCache.entries = {}
        totalContentHeight = 0
        if commitData and commitData.order then
            local font = Theme.fonts.small or love.graphics.getFont()
            local lineHeight = font:getHeight()
            love.graphics.setFont(font)
            local reservedTrackSpace = SCROLL_TRACK_WIDTH + SCROLL_EXTRA_GAP
            local textAreaWidth = math.max(0, listW - reservedTrackSpace)
            local textColumnWidth = math.max(0, textAreaWidth - TEXT_LEFT_MARGIN - TEXT_RIGHT_PADDING)
            local bodyColumnWidth = math.max(0, textColumnWidth - BULLET_INDENT)
            for _, versionKey in ipairs(commitData.order) do
                local commits = commitData.grouped[versionKey]
                if commits then
                    local versionHeader = versionKey
                    local headerHeight = lineHeight + ENTRY_PADDING_Y * 2
                    totalContentHeight = totalContentHeight + headerHeight + ENTRY_SPACING
                    table.insert(VersionLog.layoutCache.entries, {
                        kind = "version",
                        text = versionHeader,
                        height = headerHeight,
                    })

                    for _, commit in ipairs(commits) do
                        local headerText = commit.subject or ""
                        local headerLines = wrapText(font, headerText, textColumnWidth)

                        local metaLines = {}
                        if (commit.date and commit.date ~= "") or (commit.author and commit.author ~= "") then
                            local parts = {}
                            if commit.date and commit.date ~= "" then table.insert(parts, commit.date) end
                            if commit.author and commit.author ~= "" then table.insert(parts, commit.author) end
                            local metaText = table.concat(parts, " • ")
                            metaLines = wrapText(font, metaText, textColumnWidth)
                        end

                        local sections = {}
                        if commit.bodyLines and #commit.bodyLines > 0 then
                            local current = {}
                            for _, line in ipairs(commit.bodyLines) do
                                if line:match("%S") then
                                    table.insert(current, line)
                                elseif #current > 0 then
                                    table.insert(sections, current)
                                    current = {}
                                end
                            end
                            if #current > 0 then
                                table.insert(sections, current)
                            end
                        end

                        local bodyWraps = {}
                        for _, paragraph in ipairs(sections) do
                            local wraps = {}
                            for _, line in ipairs(paragraph) do
                                local wrapLines = wrapText(font, line, bodyColumnWidth)
                                table.insert(wraps, wrapLines)
                            end
                            table.insert(bodyWraps, wraps)
                        end

                        local commitHeaderHeight = #headerLines * lineHeight
                        local metaHeight = (#metaLines > 0 and (#metaLines * lineHeight + BODY_PARAGRAPH_SPACING * 0.5)) or 0
                        local bodyHeight = (#bodyWraps > 0) and BODY_PARAGRAPH_SPACING or 0
                        for _, paragraph in ipairs(bodyWraps) do
                            for _, wrapLines in ipairs(paragraph) do
                                bodyHeight = bodyHeight + (#wrapLines * lineHeight)
                            end
                            bodyHeight = bodyHeight + BODY_PARAGRAPH_SPACING
                        end
                        if bodyHeight > 0 then
                            bodyHeight = bodyHeight - BODY_PARAGRAPH_SPACING
                        end

                        local entryHeight = ENTRY_PADDING_Y * 2 + commitHeaderHeight + metaHeight
                        if bodyHeight > 0 then
                            entryHeight = entryHeight + BODY_PARAGRAPH_SPACING + bodyHeight
                        end

                        totalContentHeight = totalContentHeight + entryHeight + ENTRY_SPACING
                        table.insert(VersionLog.layoutCache.entries, {
                            kind = "commit",
                            commit = commit,
                            headerLines = headerLines,
                            metaLines = metaLines,
                            bodyWraps = bodyWraps,
                            height = entryHeight,
                            textWidth = textColumnWidth,
                            bodyWidth = bodyColumnWidth,
                        })
                    end
                end
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
    local entryFont = Theme.fonts.small or love.graphics.getFont()
    love.graphics.setFont(entryFont)

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
    elseif not hasCommitData(VersionLog.commits) then
        love.graphics.setFont(Theme.fonts.small)
        drawStatusMessage(listX, listY, listW - 16, Strings.getUI("version_log_empty"))
        love.graphics.setFont(Theme.fonts.normal)
    else
        local font = entryFont
        local lineHeight = font:getHeight()
        love.graphics.setFont(font)
        local rowY = listY - VersionLog.scrollY
        local trackWidth = (VersionLog.scrollGeom.track and VersionLog.scrollGeom.track.w) or SCROLL_TRACK_WIDTH
        local reservedTrackSpace = trackWidth + SCROLL_EXTRA_GAP
        local textAreaWidth = math.max(0, listW - reservedTrackSpace)
        local textX = listX + TEXT_LEFT_MARGIN
        local textWidth = math.max(0, textAreaWidth - TEXT_LEFT_MARGIN - TEXT_RIGHT_PADDING)

        for _, entry in ipairs(VersionLog.layoutCache.entries) do
            local entryTop = rowY
            local entryBottom = rowY + entry.height
            if entryBottom >= listY - ENTRY_SPACING and entryTop <= listY + listH + ENTRY_SPACING then
                if entry.kind == "version" then
                    local headerLines = wrapText(font, entry.text, textWidth)
                    Theme.setColor(Theme.colors.accentGold or Theme.colors.accent)
                    local cursorY = entryTop + ENTRY_PADDING_Y
                    for _, line in ipairs(headerLines) do
                        love.graphics.print(line, textX, cursorY)
                        cursorY = cursorY + lineHeight
                    end
                elseif entry.kind == "commit" then
                    local commit = entry.commit
                    local cursorY = entryTop + ENTRY_PADDING_Y
                    Theme.setColor(Theme.colors.accent)
                    for _, line in ipairs(entry.headerLines) do
                        love.graphics.print(line, textX, cursorY)
                        cursorY = cursorY + lineHeight
                    end

                    if entry.metaLines and #entry.metaLines > 0 then
                        cursorY = cursorY + BODY_PARAGRAPH_SPACING * 0.5
                        Theme.setColor(Theme.colors.textSecondary)
                        for _, line in ipairs(entry.metaLines) do
                            love.graphics.print(line, textX, cursorY)
                            cursorY = cursorY + lineHeight
                        end
                    end

                    if entry.bodyWraps and #entry.bodyWraps > 0 then
                        cursorY = cursorY + BODY_PARAGRAPH_SPACING
                        Theme.setColor(Theme.colors.text)
                        local bulletIndent = BULLET_INDENT
                        for paragraphIndex, paragraph in ipairs(entry.bodyWraps) do
                            for _, wrapLines in ipairs(paragraph) do
                                for _, line in ipairs(wrapLines) do
                                    love.graphics.print("•", textX, cursorY)
                                    love.graphics.print(line, textX + bulletIndent, cursorY)
                                    cursorY = cursorY + lineHeight + BULLET_LINE_SPACING
                                end
                            end
                            if paragraphIndex < #entry.bodyWraps then
                                cursorY = cursorY + BODY_PARAGRAPH_SPACING
                            end
                        end
                    end

                    Theme.setColor(Theme.colors.border)
                    love.graphics.setLineWidth(1)
                    local ruleRight = textX + math.max(0, textAreaWidth - TEXT_RIGHT_PADDING)
                    if ruleRight > textX then
                        love.graphics.line(textX - 4, cursorY + 4, ruleRight, cursorY + 4)
                    end
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

