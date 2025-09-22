local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Util = require("src.core.util")
local Sectors = require("src.content.sectors")
local PortfolioManager = require("src.managers.portfolio")

local Warp = {}

function Warp:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self

    -- UI state
    o.visible = false
    o.selectedSector = nil
    o.hoveredSector = nil
    o.confirmingWarp = false

    -- Visual state
    o.gridSize = 120
    o.sectorSize = 80
    o.panelWidth = 350
    o.animTime = 0

    -- Layout calculations
    o.mapOffsetX = 0
    o.mapOffsetY = 0

    return o
end

-- Initialize warp system
function Warp:init()
    -- Initialize portfolio manager if needed
    if PortfolioManager and PortfolioManager.init then
        PortfolioManager.init()
    end
end

-- Show/hide the warp interface
function Warp:show()
    self.visible = true
    self.selectedSector = nil
    self.confirmingWarp = false
end

function Warp:hide()
    self.visible = false
    self.selectedSector = nil
    self.confirmingWarp = false
end

function Warp:toggle()
    if self.visible then
        self:hide()
    else
        self:show()
    end
end

-- Update warp system
function Warp:update(dt)
    if not self.visible then return end
    self.animTime = self.animTime + dt
end

-- Draw the warp interface
function Warp:draw()
    if not self.visible then return end

    local sw, sh = Viewport.getDimensions()
    local margin = 50
    local totalW = sw - margin * 2
    local totalH = sh - margin * 2

    -- Main background
    Theme.drawGradientGlowRect(margin, margin, totalW, totalH, 8,
        Theme.colors.bg1, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowMedium)

    -- Title
    love.graphics.setFont(Theme.fonts.large)
    Theme.setColor(Theme.colors.textHighlight)
    local title = "GALACTIC WARP NETWORK"
    local titleW = love.graphics.getFont():getWidth(title)
    love.graphics.print(title, margin + (totalW - titleW) / 2, margin + 20)

    -- Calculate layout
    local headerH = 80
    local mapAreaW = totalW - self.panelWidth - 30
    local mapAreaH = totalH - headerH - 20
    local mapX = margin + 15
    local mapY = margin + headerH

    self:drawGalaxyMap(mapX, mapY, mapAreaW, mapAreaH)
    self:drawInfoPanel(mapX + mapAreaW + 15, mapY, self.panelWidth, mapAreaH)

    -- Draw confirmation dialog if needed
    if self.confirmingWarp and self.selectedSector then
        self:drawWarpConfirmation()
    end
end

-- Draw the galaxy map
function Warp:drawGalaxyMap(x, y, w, h)
    -- Map background
    Theme.drawGradientGlowRect(x, y, w, h, 6,
        Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)

    -- Calculate grid positioning
    local gridW = Sectors.gridWidth * self.gridSize
    local gridH = Sectors.gridHeight * self.gridSize
    local startX = x + (w - gridW) / 2 + self.mapOffsetX
    local startY = y + (h - gridH) / 2 + self.mapOffsetY

    -- Draw grid lines
    love.graphics.setLineWidth(1)
    Theme.setColor(Theme.withAlpha(Theme.colors.bg3, 0.3))
    for i = 0, Sectors.gridWidth do
        local lineX = startX + i * self.gridSize
        love.graphics.line(lineX, startY, lineX, startY + gridH)
    end
    for j = 0, Sectors.gridHeight do
        local lineY = startY + j * self.gridSize
        love.graphics.line(startX, lineY, startX + gridW, lineY)
    end

    -- Draw sectors
    self._sectorButtons = {}
    for _, sector in ipairs(Sectors.data) do
        local sectorX = startX + (sector.x - 1) * self.gridSize + (self.gridSize - self.sectorSize) / 2
        local sectorY = startY + (sector.y - 1) * self.gridSize + (self.gridSize - self.sectorSize) / 2

        self:drawSector(sector, sectorX, sectorY, self.sectorSize)

        -- Store button area for click detection
        table.insert(self._sectorButtons, {
            x = sectorX, y = sectorY, w = self.sectorSize, h = self.sectorSize,
            sector = sector
        })
    end

    -- Draw connections between unlocked adjacent sectors
    self:drawSectorConnections(startX, startY)
end

-- Draw a single sector
function Warp:drawSector(sector, x, y, size)
    local sectorType = Sectors.getSectorType(sector.type)
    local isCurrent = sector.id == Sectors.currentSector
    local isSelected = self.selectedSector and self.selectedSector.id == sector.id
    local isHovered = self.hoveredSector and self.hoveredSector.id == sector.id

    -- Determine sector appearance
    local bgColor = Theme.colors.bg2
    local borderColor = Theme.colors.border
    local glowEffect = Theme.effects.glowWeak

    if not sector.unlocked then
        bgColor = Theme.colors.bg0
        borderColor = Theme.colors.textDisabled
    elseif isCurrent then
        bgColor = Theme.colors.success
        borderColor = Theme.colors.textHighlight
        glowEffect = Theme.effects.glowStrong
    elseif isSelected then
        bgColor = Theme.colors.primary
        borderColor = Theme.colors.accent
        glowEffect = Theme.effects.glowMedium
    elseif isHovered then
        bgColor = Theme.colors.bg3
        borderColor = Theme.colors.textHighlight
    end

    -- Draw sector background
    Theme.drawGradientGlowRect(x, y, size, size, 6, bgColor, Theme.colors.bg1, borderColor, glowEffect)

    -- Draw sector type indicator (colored circle)
    if sector.unlocked then
        local centerX = x + size / 2
        local centerY = y + size / 2
        local radius = 8

        Theme.setColor(sectorType.color)
        love.graphics.circle("fill", centerX, centerY, radius)
        Theme.setColor(Theme.colors.border)
        love.graphics.circle("line", centerX, centerY, radius)
    end

    -- Draw sector name
    love.graphics.setFont(Theme.fonts.small)
    local textColor = sector.unlocked and Theme.colors.text or Theme.colors.textDisabled
    if isCurrent then textColor = Theme.colors.textHighlight end

    Theme.setColor(textColor)
    love.graphics.printf(sector.name, x, y + size - 30, size, "center")

    -- Draw current location indicator
    if isCurrent then
        Theme.setColor(Theme.colors.textHighlight)
        love.graphics.setFont(Theme.fonts.small)
        love.graphics.printf("★ YOU ARE HERE", x, y + size - 15, size, "center")
    end

    -- Draw home indicator
    if sector.isHome then
        Theme.setColor(Theme.colors.positive)
        love.graphics.circle("line", x + size - 15, y + 15, 8)
        love.graphics.setFont(Theme.fonts.small)
        love.graphics.printf("⌂", x + size - 20, y + 8, 10, "center")
    end
end

-- Draw connections between adjacent unlocked sectors
function Warp:drawSectorConnections(startX, startY)
    love.graphics.setLineWidth(2)
    Theme.setColor(Theme.withAlpha(Theme.colors.accent, 0.4))

    for _, sector in ipairs(Sectors.data) do
        if sector.unlocked then
            local adjacent = Sectors.getAdjacentSectors(sector.id)
            for _, adjSector in ipairs(adjacent) do
                local x1 = startX + (sector.x - 1) * self.gridSize + self.gridSize / 2
                local y1 = startY + (sector.y - 1) * self.gridSize + self.gridSize / 2
                local x2 = startX + (adjSector.x - 1) * self.gridSize + self.gridSize / 2
                local y2 = startY + (adjSector.y - 1) * self.gridSize + self.gridSize / 2

                -- Only draw each connection once (avoid duplicates)
                if sector.id < adjSector.id then
                    love.graphics.line(x1, y1, x2, y2)
                end
            end
        end
    end
end

-- Draw the information panel
function Warp:drawInfoPanel(x, y, w, h)
    -- Panel background
    Theme.drawGradientGlowRect(x, y, w, h, 6,
        Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)

    local currentSector = Sectors.getCurrentSector()
    local funds = PortfolioManager and PortfolioManager.getAvailableFunds and PortfolioManager.getAvailableFunds() or 1000

    -- Current location info
    local yPos = y + 20
    love.graphics.setFont(Theme.fonts.medium)
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.print("CURRENT LOCATION", x + 15, yPos)

    yPos = yPos + 30
    love.graphics.setFont(Theme.fonts.small)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf(currentSector.name, x + 15, yPos, w - 30, "left")

    local currentType = Sectors.getSectorType(currentSector.type)
    yPos = yPos + 20
    Theme.setColor(currentType.color)
    love.graphics.printf(currentType.name, x + 15, yPos, w - 30, "left")

    yPos = yPos + 25
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.printf(currentType.description, x + 15, yPos, w - 30, "left")

    -- Available funds
    yPos = yPos + 60
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.setFont(Theme.fonts.medium)
    love.graphics.print("AVAILABLE FUNDS", x + 15, yPos)

    yPos = yPos + 25
    love.graphics.setFont(Theme.fonts.small)
    Theme.setColor(Theme.colors.positive)
    love.graphics.print(string.format("%.0f GC", funds), x + 15, yPos)

    -- Selected sector info
    if self.selectedSector then
        yPos = yPos + 50
        self:drawSelectedSectorInfo(x + 15, yPos, w - 30)
    else
        yPos = yPos + 80
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.setFont(Theme.fonts.small)
        love.graphics.printf("Select a sector to view warp information", x + 15, yPos, w - 30, "center")
    end

    -- Instructions
    yPos = h + y - 80
    Theme.setColor(Theme.colors.textDisabled)
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.printf("Click sectors to select\nDouble-click to initiate warp\nESC to close", x + 15, yPos, w - 30, "center")
end

-- Draw selected sector information
function Warp:drawSelectedSectorInfo(x, y, w)
    local sector = self.selectedSector
    local sectorType = Sectors.getSectorType(sector.type)
    local warpCost = Sectors.calculateWarpCost(Sectors.currentSector, sector.id)
    local canWarp, reason = Sectors.canWarpTo(sector.id)

    -- Selected sector title
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.setFont(Theme.fonts.medium)
    love.graphics.print("SELECTED SECTOR", x, y)

    y = y + 30
    love.graphics.setFont(Theme.fonts.small)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf(sector.name, x, y, w, "left")

    y = y + 20
    Theme.setColor(sectorType.color)
    love.graphics.printf(sectorType.name, x, y, w, "left")

    y = y + 25
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.printf(sectorType.description, x, y, w, "left")

    -- Warp cost
    y = y + 40
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.print("WARP COST", x, y)

    y = y + 20
    local costColor = warpCost > (PortfolioManager and PortfolioManager.getAvailableFunds and PortfolioManager.getAvailableFunds() or 1000) and Theme.colors.danger or Theme.colors.text
    Theme.setColor(costColor)
    love.graphics.print(string.format("%d GC", warpCost), x, y)

    -- Warp button
    y = y + 40
    local buttonW = w
    local buttonH = 35

    local buttonEnabled = canWarp and (warpCost <= (PortfolioManager and PortfolioManager.getAvailableFunds and PortfolioManager.getAvailableFunds() or 1000))
    local buttonColor = buttonEnabled and Theme.colors.primary or Theme.colors.bg2
    local textColor = buttonEnabled and Theme.colors.textHighlight or Theme.colors.textDisabled

    Theme.drawGradientGlowRect(x, y, buttonW, buttonH, 4,
        buttonColor, Theme.colors.bg1,
        buttonEnabled and Theme.colors.accent or Theme.colors.border,
        Theme.effects.glowWeak)

    Theme.setColor(textColor)
    love.graphics.setFont(Theme.fonts.medium)
    local buttonText = buttonEnabled and "INITIATE WARP" or (reason or "CANNOT WARP")
    love.graphics.printf(buttonText, x, y + 8, buttonW, "center")

    -- Store button for click detection
    self._warpButton = buttonEnabled and {x = x, y = y, w = buttonW, h = buttonH} or nil
end

-- Draw warp confirmation dialog
function Warp:drawWarpConfirmation()
    local sw, sh = Viewport.getDimensions()
    local dialogW = 400
    local dialogH = 250
    local dialogX = (sw - dialogW) / 2
    local dialogY = (sh - dialogH) / 2


    -- Dialog background
    Theme.drawGradientGlowRect(dialogX, dialogY, dialogW, dialogH, 8,
        Theme.colors.bg1, Theme.colors.bg0, Theme.colors.accent, Theme.effects.glowStrong)

    -- Dialog content
    local yPos = dialogY + 30
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.setFont(Theme.fonts.large)
    love.graphics.printf("CONFIRM WARP", dialogX, yPos, dialogW, "center")

    yPos = yPos + 50
    Theme.setColor(Theme.colors.text)
    love.graphics.setFont(Theme.fonts.small)
    local confirmText = string.format("Warp to %s?\n\nCost: %d GC",
        self.selectedSector.name,
        Sectors.calculateWarpCost(Sectors.currentSector, self.selectedSector.id))
    love.graphics.printf(confirmText, dialogX + 20, yPos, dialogW - 40, "center")

    -- Buttons
    yPos = dialogY + dialogH - 70
    local buttonW = 120
    local buttonH = 35
    local spacing = 20
    local totalButtonW = buttonW * 2 + spacing
    local buttonStartX = dialogX + (dialogW - totalButtonW) / 2

    -- Cancel button
    Theme.drawGradientGlowRect(buttonStartX, yPos, buttonW, buttonH, 4,
        Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("CANCEL", buttonStartX, yPos + 8, buttonW, "center")
    self._cancelButton = {x = buttonStartX, y = yPos, w = buttonW, h = buttonH}

    -- Confirm button
    local confirmX = buttonStartX + buttonW + spacing
    Theme.drawGradientGlowRect(confirmX, yPos, buttonW, buttonH, 4,
        Theme.colors.primary, Theme.colors.bg1, Theme.colors.accent, Theme.effects.glowMedium)
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.printf("WARP", confirmX, yPos + 8, buttonW, "center")
    self._confirmButton = {x = confirmX, y = yPos, w = buttonW, h = buttonH}
end

-- Handle mouse input
function Warp:mousepressed(x, y, button)
    if not self.visible then return false end
    if button ~= 1 then return false end

    -- Handle confirmation dialog
    if self.confirmingWarp then
        if self._cancelButton and Util.rectContains(x, y, self._cancelButton.x, self._cancelButton.y, self._cancelButton.w, self._cancelButton.h) then
            self.confirmingWarp = false
            return true
        end
        if self._confirmButton and Util.rectContains(x, y, self._confirmButton.x, self._confirmButton.y, self._confirmButton.w, self._confirmButton.h) then
            self:executeWarp()
            return true
        end
        return true -- Block input when dialog is open
    end

    -- Handle sector selection
    if self._sectorButtons then
        for _, button in ipairs(self._sectorButtons) do
            if Util.rectContains(x, y, button.x, button.y, button.w, button.h) then
                if button.sector.unlocked then
                    -- Double-click to warp
                    if self.selectedSector and self.selectedSector.id == button.sector.id then
                        if Sectors.canWarpTo(button.sector.id) then
                            self.confirmingWarp = true
                        end
                    else
                        self.selectedSector = button.sector
                    end
                end
                return true
            end
        end
    end

    -- Handle warp button
    if self._warpButton and Util.rectContains(x, y, self._warpButton.x, self._warpButton.y, self._warpButton.w, self._warpButton.h) then
        self.confirmingWarp = true
        return true
    end

    return true -- Block input when warp interface is open
end

-- Handle mouse movement for hover effects
function Warp:mousemoved(x, y, dx, dy)
    if not self.visible then return false end

    self.hoveredSector = nil
    if self._sectorButtons then
        for _, button in ipairs(self._sectorButtons) do
            if Util.rectContains(x, y, button.x, button.y, button.w, button.h) then
                if button.sector.unlocked then
                    self.hoveredSector = button.sector
                end
                break
            end
        end
    end

    return false
end

-- Handle keyboard input
function Warp:keypressed(key)
    if not self.visible then return false end

    if key == "escape" then
        if self.confirmingWarp then
            self.confirmingWarp = false
        else
            self:hide()
        end
        return true
    end

    return false
end

-- Execute the warp
function Warp:executeWarp()
    if not self.selectedSector then return end

    local cost = Sectors.calculateWarpCost(Sectors.currentSector, self.selectedSector.id)

    -- Check funds and execute warp
    if PortfolioManager and PortfolioManager.spendFunds then
        if PortfolioManager.getAvailableFunds() >= cost then
            PortfolioManager.spendFunds(cost)
            Sectors.warpTo(self.selectedSector.id)

            -- Close warp interface
            self:hide()

            print(string.format("Warped to %s for %d GC", self.selectedSector.name, cost))
            return true
        else
            print("Insufficient funds for warp")
            return false
        end
    else
        -- If portfolio manager not available, just execute warp
        Sectors.warpTo(self.selectedSector.id)
        self:hide()
        print(string.format("Warped to %s", self.selectedSector.name))
        return true
    end
end

return Warp