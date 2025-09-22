local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local AuroraTitle = require("src.shaders.aurora_title")
local Window = require("src.ui.common.window")

local Bounty = {
  visible = false,
  scrollY = 0,
  contentHeight = 0,
  auroraShader = nil,
}

function Bounty.init()
    Bounty.window = Window.new({
        title = "Bounty",
        width = 280,
        height = 200,
        minWidth = 200,
        minHeight = 150,
        draggable = true,
        closable = true,
        drawContent = Bounty.drawContent,
        onClose = function()
            Bounty.visible = false
        end
    })
end

function Bounty.getRect()
    if not Bounty.window then return nil end
    return { x = Bounty.window.x, y = Bounty.window.y, w = Bounty.window.width, h = Bounty.window.height }
end

local function pointInRect(px, py, x, y, w, h)
  -- Handle nil values gracefully
  if px == nil or py == nil or x == nil or y == nil or w == nil or h == nil then
    return false
  end
  return px >= x and py >= y and px <= x + w and py <= y + h
end

-- Icon drawing functions
local function drawCreditIcon(x, y, size)
  size = size or 12
  local r = size * 0.4
  -- Credit coin: circle with 'C' symbol
  love.graphics.setColor(1.0, 0.85, 0.3, 0.9) -- Gold color
  love.graphics.circle("fill", x + r, y + r, r)
  love.graphics.setColor(0.8, 0.6, 0.1, 1.0)
  love.graphics.circle("line", x + r, y + r, r)
  -- 'C' symbol
  love.graphics.setColor(0.2, 0.2, 0.2, 1.0)
  love.graphics.setFont(love.graphics.getFont())
  local font = love.graphics.getFont()
  local fw = font:getWidth("C")
  local fh = font:getHeight()
  love.graphics.print("C", x + r - fw * 0.5, y + r - fh * 0.5)
end

-- remove XP icon; bounty rewards are GC only

-- Use Theme.drawCloseButton for consistent visuals


local function getClaimButtonRect()
    if not Bounty.window then return nil end
    local x, y, w, h = Bounty.window.x, Bounty.window.y, Bounty.window.width, Bounty.window.height
    local buttonW = 120
    local buttonH = (Theme.ui and Theme.ui.buttonHeight) or 28
    local buttonX = x + (w - buttonW) / 2
    local buttonY = y + h - buttonH - ((Theme.ui and Theme.ui.contentPadding) or 10)
    return {x = buttonX, y = buttonY, w = buttonW, h = buttonH}
end

local function drawClaimButton(docked)
    if not docked then return end
    local rect = getClaimButtonRect()
    local mx, my = Viewport.getMousePosition()
    local hover = pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h)
    
    -- Use Theme functions for consistent button styling
    local buttonBg = hover and Theme.colors.primary or Theme.colors.bg2
    local buttonBorder = Theme.colors.border

    -- Use very subtle glow for mostly transparent buttons
    Theme.drawGradientGlowRect(rect.x, rect.y, rect.w, rect.h, 4, buttonBg, Theme.colors.bg1, Theme.colors.primary, Theme.effects.glowWeak * 0.05)
    Theme.drawEVEBorder(rect.x, rect.y, rect.w, rect.h, 4, buttonBorder, 6)
    
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("Claim Bounties", rect.x, rect.y + 6, rect.w, "center")
end

function Bounty.draw(state, docked)
    if not Bounty.visible then return end
    if not Bounty.window then Bounty.init() end
    Bounty.window.visible = Bounty.visible
    Bounty.window:draw()
end

function Bounty.drawContent(window, x, y, w, h)
    local state = state or { total = 0, entries = {} }
    local docked = docked or false

    -- Draw claim button if docked
    drawClaimButton(docked)

    love.graphics.push()
    local innerTop = y
    local innerH = h - (docked and 40 or ((Theme.ui and Theme.ui.contentPadding) or 10))
    love.graphics.setScissor(x, innerTop, w, innerH)
    love.graphics.translate(0, -Bounty.scrollY)

    local pad = (Theme.ui and Theme.ui.contentPadding) or 10
    local cx, cy = x + pad, y + pad

    -- Uncollected totals section with icons
    love.graphics.setColor(0.75, 0.85, 1, 0.9)
    love.graphics.print("Uncollected:", cx, cy)
    cy = cy + 20

    -- Credits row
    drawCreditIcon(cx + 5, cy, 16)
    love.graphics.setColor(1.0, 0.85, 0.3, 0.95)
    love.graphics.print(string.format("%d cr", state.uncollected or 0), cx + 25, cy + 2)

    cy = cy + 25
    love.graphics.setColor(0.75, 0.80, 0.95, 0.85)
    love.graphics.print("Recent kills:", cx, cy)
    cy = cy + 16

    local shown = 0
    if state.entries then
        for i = #state.entries, 1, -1 do
            local entry = state.entries[i]
            -- Enemy name
            love.graphics.setColor(0.92, 0.95, 1.00, 0.96)
            love.graphics.print(entry.name or "Unknown Enemy", cx, cy)
            cy = cy + 14

            -- Rewards on same line with icons
            drawCreditIcon(cx + 10, cy, 12)
            love.graphics.setColor(1.0, 0.85, 0.3, 0.95)
            love.graphics.print(string.format("+%d", entry.gc or 0), cx + 25, cy + 1)

            cy = cy + 18
            shown = shown + 1
            if shown >= 4 then break end
        end
    end

    if shown == 0 then
        love.graphics.setColor(0.55, 0.60, 0.75, 0.75)
        love.graphics.print("No recent kills", cx + 10, cy)
    end

    Bounty.contentHeight = cy - y
    love.graphics.pop()
    love.graphics.setScissor()

    -- Scrollbar
    if Bounty.contentHeight > innerH then
        local scrollbarX = x + w - ((Theme.ui and Theme.ui.contentPadding) or 10)
        local scrollbarY = innerTop
        local scrollbarH = innerH
        local thumbH = math.max(24, scrollbarH * (innerH / Bounty.contentHeight))
        local trackRange = scrollbarH - thumbH
        local thumbY = scrollbarY + (trackRange > 0 and (trackRange * (Bounty.scrollY / (Bounty.contentHeight - innerH))) or 0)
        Theme.drawGradientGlowRect(scrollbarX, scrollbarY, 8, scrollbarH, 2, Theme.colors.bg0, Theme.colors.bg1, Theme.colors.border, 0)
        Theme.drawGradientGlowRect(scrollbarX, thumbY, 8, thumbH, 2, Theme.colors.accent, Theme.colors.bg3, Theme.colors.border, 0)
        Bounty._scrollbarTrack = { x = scrollbarX, y = scrollbarY, w = 8, h = scrollbarH }
        Bounty._scrollbarThumb = { x = scrollbarX, y = thumbY, w = 8, h = thumbH }
    else
        Bounty._scrollbarTrack = nil
        Bounty._scrollbarThumb = nil
    end
end

function Bounty.mousepressed(x, y, button, docked)
    if not Bounty.visible or button ~= 1 then return false, false end
    if not Bounty.window then Bounty.init() end

    if Bounty.window:mousepressed(x, y, button) then
        return true, false
    end

    -- Scrollbar interactions
    if Bounty._scrollbarTrack and Bounty._scrollbarThumb then
        local tr = Bounty._scrollbarTrack
        local th = Bounty._scrollbarThumb
        if pointInRect(x, y, th.x, th.y, th.w, th.h) then
            Bounty.dragging = "scrollbar"
            Bounty.dragDY = y - th.y
            return true, false
        end
        if pointInRect(x, y, tr.x, tr.y, tr.w, tr.h) then
            local innerH = Bounty.window.height - (Bounty.window.titleBarHeight + (docked and 40 or 10))
            local trackRange = tr.h - th.h
            local rel = math.max(0, math.min(trackRange, (y - tr.y) - th.h * 0.5))
            local frac = trackRange > 0 and (rel / trackRange) or 0
            local maxScroll = math.max(0, Bounty.contentHeight - innerH)
            Bounty.scrollY = math.max(0, math.min(maxScroll, frac * maxScroll))
            return true, false
        end
    end

    -- Claim button
    if docked then
        local claimRect = getClaimButtonRect()
        if pointInRect(x, y, claimRect.x, claimRect.y, claimRect.w, claimRect.h) then
            Bounty.claimDown = true
            return true, false
        end
    end

    return false, false
end

function Bounty.mousereleased(x, y, button, docked, claimBounty)
    if not Bounty.visible then return false, false end
    if not Bounty.window then return false, false end

    if Bounty.window:mousereleased(x, y, button) then
        return true, false
    end

    local consumed, shouldClose = false, false
    if button == 1 then
        if Bounty.dragging then
            Bounty.dragging = false
            consumed = true
        end
        if docked and Bounty.claimDown then
            local claimRect = getClaimButtonRect()
            if pointInRect(x, y, claimRect.x, claimRect.y, claimRect.w, claimRect.h) then
                if claimBounty then claimBounty() end
            end
            Bounty.claimDown = false
            consumed = true
        end
    end
    return consumed, shouldClose
end

function Bounty.mousemoved(x, y, dx, dy)
    if not Bounty.window then return false end
    if Bounty.window:mousemoved(x, y, dx, dy) then
        return true
    end

    if Bounty.dragging == "scrollbar" then
        local docked = false -- Assume not docked for simplicity
        local innerH = Bounty.window.height - (Bounty.window.titleBarHeight + (docked and 40 or 10))
        local tr = Bounty._scrollbarTrack
        local th = Bounty._scrollbarThumb
        if tr and th then
            local trackRange = tr.h - th.h
            local newThumbY = math.max(tr.y, math.min(tr.y + trackRange, (y - Bounty.dragDY)))
            local rel = newThumbY - tr.y
            local frac = trackRange > 0 and (rel / trackRange) or 0
            local maxScroll = math.max(0, Bounty.contentHeight - innerH)
            Bounty.scrollY = math.max(0, math.min(maxScroll, frac * maxScroll))
        end
        return true
    end
    return false
end

function Bounty.toggle()
  Bounty.visible = not Bounty.visible
end

function Bounty.wheelmoved(x, y, dx, dy)
    if not Bounty.visible then return false end
    if not Bounty.window then return false end
    if not Bounty.window:containsPoint(x, y) then return false end

    local docked = false -- Assume not docked for simplicity
    local innerH = Bounty.window.height - (Bounty.window.titleBarHeight + (docked and 40 or 10))
    local maxScroll = math.max(0, Bounty.contentHeight - innerH)
    Bounty.scrollY = math.max(0, math.min(maxScroll, Bounty.scrollY - dy * 20))
    return true
end

function Bounty.isVisible()
  return Bounty.visible
end

return Bounty
