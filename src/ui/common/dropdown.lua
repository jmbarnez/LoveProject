local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")

local Dropdown = {}
Dropdown.__index = Dropdown

-- Keep track of all dropdown instances so we can query global state
Dropdown._instances = setmetatable({}, { __mode = "k" })

-- Constants for consistent styling
local DROPDOWN_WIDTH = 150
local OPTION_HEIGHT = 24
local DROPDOWN_PADDING = 5
local ARROW_SIZE = 8

function Dropdown.new(config)
    local self = setmetatable({}, Dropdown)

    config = config or {}

    -- Required parameters
    self.x = config.x or 0
    self.y = config.y or 0
    self.options = config.options or {}
    self.selectedIndex = config.selectedIndex or 1
    self.onSelect = config.onSelect or function(index, option) end

    -- Optional parameters
    self.width = config.width or DROPDOWN_WIDTH
    self.optionHeight = config.optionHeight or OPTION_HEIGHT
    self.placeholder = config.placeholder or "Select..."
    self.disabled = config.disabled or false

    -- Internal state
    self.open = false
    self.hoveredOption = nil
    self.dropdownHeight = #self.options * self.optionHeight + (DROPDOWN_PADDING * 2)

    -- Cached rectangles for mouse interaction
    self._buttonRect = nil
    self._optionRects = nil

    -- Register instance for global queries (weak table avoids leaks)
    Dropdown._instances[self] = true

    return self
end

function Dropdown:setOpen(isOpen)
    if self.open == isOpen then return end

    self.open = isOpen and true or false

    if not self.open then
        self.hoveredOption = nil
    end
end

function Dropdown.isAnyOpen()
    for instance in pairs(Dropdown._instances) do
        if instance.open then
            return true
        end
    end
    return false
end

function Dropdown:draw()
    local mx, my = Viewport.getMousePosition()
    if not mx or not my then return end

    -- Draw the main button
    self:drawButton(mx, my)

    -- Draw dropdown options if open
    if self.open then
        self:drawOptions(mx, my)
    end
end

function Dropdown:drawButtonOnly(mx, my)
    -- Draw only the button (for z-ordering when other dropdowns are open)
    if not mx or not my then return end
    self:drawButton(mx, my)
end

function Dropdown:drawOptionsOnly(mx, my)
    -- Draw only the options (for z-ordering when this dropdown is open)
    if self.open then
        if not mx or not my then return end
        self:drawOptions(mx, my)
    end
end

function Dropdown:drawButton(mx, my)
    local buttonHover = self:isPointInButton(mx, my) and not self.disabled

    -- No hover sounds - only click sounds for better UX

    -- Button background with transparent base and accent color hover glow
    local buttonColor = self.disabled and {0, 0, 0, 0.3} or
                       (buttonHover and {Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], 0.2} or {0, 0, 0, 0})
    local buttonGlow = self.disabled and Theme.effects.glowWeak * 0.1 or
                      (buttonHover and Theme.effects.glowStrong or Theme.effects.glowWeak * 0.2)

    Theme.drawGradientGlowRect(self.x, self.y, self.width, self.optionHeight,
        2, buttonColor, Theme.colors.bg1, Theme.colors.border, buttonGlow)

    -- Button text
    local displayText = self:getDisplayText()
    local textColor = self.disabled and Theme.colors.textDisabled or
                     (buttonHover and Theme.colors.textHighlight or Theme.colors.text)

    Theme.setColor(textColor)
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    local textW = love.graphics.getFont():getWidth(displayText)
    local textX = self.x + 8
    local textY = self.y + (self.optionHeight - love.graphics.getFont():getHeight()) / 2
    love.graphics.print(displayText, textX, textY)

    -- Dropdown arrow
    local arrowColor = self.disabled and Theme.colors.textDisabled or
                      (buttonHover and Theme.colors.accent or Theme.colors.textSecondary)
    Theme.setColor(arrowColor)

    local arrowX = self.x + self.width - ARROW_SIZE - 8
    local arrowY = self.y + (self.optionHeight - ARROW_SIZE) / 2
    love.graphics.polygon("fill",
        arrowX, arrowY,
        arrowX + ARROW_SIZE, arrowY,
        arrowX + ARROW_SIZE/2, arrowY + ARROW_SIZE)

    -- Cache button rectangle for mouse interaction
    self._buttonRect = { x = self.x, y = self.y, w = self.width, h = self.optionHeight }
end

function Dropdown:drawOptions(mx, my)
    -- Get current scissor rectangle to respect parent clipping
    local currentScissor = {love.graphics.getScissor()}

    -- Check if dropdown would go off-screen and flip upwards if needed
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local dropdownY = self.y + self.optionHeight + 2

    -- If dropdown would go off the bottom of the screen, flip it upwards
    if dropdownY + self.dropdownHeight > screenH then
        dropdownY = self.y - self.dropdownHeight - 2
    end

    -- Ensure dropdown doesn't go off the top of the screen
    if dropdownY < 0 then
        dropdownY = 0
    end

    -- Check if dropdown would go off the right edge of the screen
    if self.x + self.width > screenW then
        self.x = screenW - self.width
    end

    -- Ensure dropdown doesn't go off the left edge of the screen
    if self.x < 0 then
        self.x = 0
    end

    -- Calculate dropdown bounds
    local dropdownX = self.x
    local dropdownY = dropdownY
    local dropdownW = self.width
    local dropdownH = self.dropdownHeight

    -- If there's a current scissor rectangle, intersect with it to stay within parent bounds
    if currentScissor[1] then
        local parentX, parentY, parentW, parentH = currentScissor[1], currentScissor[2], currentScissor[3], currentScissor[4]

        -- Calculate intersection of dropdown with parent scissor
        local intersectX = math.max(dropdownX, parentX)
        local intersectY = math.max(dropdownY, parentY)
        local intersectRight = math.min(dropdownX + dropdownW, parentX + parentW)
        local intersectBottom = math.min(dropdownY + dropdownH, parentY + parentH)

        -- If there's no intersection, don't draw anything
        if intersectX >= intersectRight or intersectY >= intersectBottom then
            return
        end

        -- Set new scissor to the intersection
        love.graphics.setScissor(intersectX, intersectY, intersectRight - intersectX, intersectBottom - intersectY)
    end

    -- Dropdown background
    Theme.drawGradientGlowRect(dropdownX, dropdownY, dropdownW, dropdownH,
        2, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak * 0.2)

    -- Draw each option
    self._optionRects = {}
    for i, option in ipairs(self.options) do
        local optionY = dropdownY + DROPDOWN_PADDING + (i - 1) * self.optionHeight
        local optionRect = { x = dropdownX, y = optionY, w = dropdownW, h = self.optionHeight }

        -- Store the dropdown position for mouse interaction
        self._dropdownY = dropdownY

        -- Check if option is visible within current scissor
        local optionVisible = true
        if currentScissor[1] then
            local parentX, parentY, parentW, parentH = currentScissor[1], currentScissor[2], currentScissor[3], currentScissor[4]
            local optionBottom = optionY + self.optionHeight
            if optionY >= parentY + parentH or optionBottom <= parentY or
               dropdownX >= parentX + parentW or dropdownX + dropdownW <= parentX then
                optionVisible = false
            end
        end

        if optionVisible then
            -- Option background and hover effect
            local isHovered = self.hoveredOption == i
            local isSelected = i == self.selectedIndex

            -- No hover sounds - only click sounds for better UX

            if isSelected then
                -- Selected option gets distinct background
                Theme.drawGradientGlowRect(optionRect.x + 2, optionRect.y, optionRect.w - 4, optionRect.h,
                    1, Theme.colors.accent, Theme.colors.accentGold, Theme.colors.border, Theme.effects.glowWeak * 0.3)
            elseif isHovered then
                -- Hovered option gets subtle highlight
                Theme.drawGradientGlowRect(optionRect.x + 2, optionRect.y, optionRect.w - 4, optionRect.h,
                    1, Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak * 0.2)
            end

            -- Option text
            local textColor
            if isSelected then
                textColor = Theme.colors.textHighlight -- White text on colored background
            elseif isHovered then
                textColor = Theme.colors.accent -- Accent color for hover
            else
                textColor = Theme.colors.text
            end

            Theme.setColor(textColor)
            love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
            local textX = dropdownX + 8
            local textY = optionY + (self.optionHeight - love.graphics.getFont():getHeight()) / 2
            love.graphics.print(option, textX, textY)

            -- Selection indicator for selected option
            if isSelected then
                Theme.setColor(Theme.colors.textHighlight)
                local checkX = dropdownX + dropdownW - 16
                love.graphics.polygon("fill",
                    checkX - 4, textY + 2,
                    checkX + 4, textY + 2,
                    checkX, textY + 6)
            end
        end

        table.insert(self._optionRects, optionRect)
    end

    -- Restore the original scissor rectangle
    if currentScissor[1] then
        love.graphics.setScissor(currentScissor[1], currentScissor[2], currentScissor[3], currentScissor[4])
    end
end

function Dropdown:getDisplayText()
    if self.selectedIndex and self.options[self.selectedIndex] then
        return self.options[self.selectedIndex]
    end
    return self.placeholder
end

function Dropdown:isPointInButton(mx, my)
    return self._buttonRect and
           mx and my and
           mx >= self._buttonRect.x and mx <= self._buttonRect.x + self._buttonRect.w and
           my >= self._buttonRect.y and my <= self._buttonRect.y + self._buttonRect.h
end

function Dropdown:isPointInOption(mx, my, optionIndex)
    if not self._optionRects or not self._optionRects[optionIndex] then
        return false
    end
    local rect = self._optionRects[optionIndex]
    
    -- Basic bounds check
    if not (mx and my and mx >= rect.x and mx <= rect.x + rect.w and my >= rect.y and my <= rect.y + rect.h) then
        return false
    end
    
    -- Additional check: ensure the option is actually visible (not clipped by scissor)
    local currentScissor = {love.graphics.getScissor()}
    if currentScissor[1] then
        local parentX, parentY, parentW, parentH = currentScissor[1], currentScissor[2], currentScissor[3], currentScissor[4]
        
        -- Check if the option rectangle intersects with the scissor rectangle
        local intersectX = math.max(rect.x, parentX)
        local intersectY = math.max(rect.y, parentY)
        local intersectRight = math.min(rect.x + rect.w, parentX + parentW)
        local intersectBottom = math.min(rect.y + rect.h, parentY + parentH)
        
        -- If there's no intersection, the option is not visible
        if intersectX >= intersectRight or intersectY >= intersectBottom then
            return false
        end
        
        -- Check if the mouse point is within the visible portion
        if mx < intersectX or mx > intersectRight or my < intersectY or my > intersectBottom then
            return false
        end
    end
    
    return true
end

function Dropdown:mousepressed(mx, my, button)
    if self.disabled or not mx or not my then return false end

    -- Check if click is on the button
    if self:isPointInButton(mx, my) then
        self:setOpen(not self.open)
        return true
    end

    -- If dropdown is open, check option clicks
    if self.open then
        -- Get current scissor rectangle to check if click is within visible bounds
        local currentScissor = {love.graphics.getScissor()}
        local isWithinBounds = true

        if currentScissor[1] then
            local parentX, parentY, parentW, parentH = currentScissor[1], currentScissor[2], currentScissor[3], currentScissor[4]
            local dropdownX = self.x
            local dropdownY = self._dropdownY or (self.y + self.optionHeight + 2)
            local dropdownW = self.width
            local dropdownH = self.dropdownHeight

            -- Check if dropdown is visible within current scissor
            local intersectX = math.max(dropdownX, parentX)
            local intersectY = math.max(dropdownY, parentY)
            local intersectRight = math.min(dropdownX + dropdownW, parentX + parentW)
            local intersectBottom = math.min(dropdownY + dropdownH, parentY + parentH)

            if intersectX >= intersectRight or intersectY >= intersectBottom then
                isWithinBounds = false
            end
        end

        if isWithinBounds then
            for i, option in ipairs(self.options) do
                if self:isPointInOption(mx, my, i) then
                    self.selectedIndex = i
                    self:setOpen(false)
                    self.onSelect(i, option)
                    return true
                end
            end

            -- Click outside options but still in dropdown area - don't close, just return true to indicate we handled it
            local dropdownY = self._dropdownY or (self.y + self.optionHeight + 2)
            if mx >= self.x and mx <= self.x + self.width and
               my >= dropdownY and my <= dropdownY + self.dropdownHeight then
                return true
            end
        end

        -- Click outside dropdown area - close the dropdown and don't consume the click
        self:setOpen(false)
        return false
    end

    return false
end

function Dropdown:mousemoved(mx, my)
    if self.disabled or not mx or not my then return false end

    -- Update hover state
    self.hoveredOption = nil

    if self.open then
        -- Get current scissor rectangle to check if mouse is within visible bounds
        local currentScissor = {love.graphics.getScissor()}
        local isWithinBounds = true

        if currentScissor[1] then
            local parentX, parentY, parentW, parentH = currentScissor[1], currentScissor[2], currentScissor[3], currentScissor[4]
            local dropdownX = self.x
            local dropdownY = self._dropdownY or (self.y + self.optionHeight + 2)
            local dropdownW = self.width
            local dropdownH = self.dropdownHeight

            -- Check if mouse is within the visible portion of the dropdown
            local intersectX = math.max(dropdownX, parentX)
            local intersectY = math.max(dropdownY, parentY)
            local intersectRight = math.min(dropdownX + dropdownW, parentX + parentW)
            local intersectBottom = math.min(dropdownY + dropdownH, parentY + parentH)

            if intersectX >= intersectRight or intersectY >= intersectBottom then
                isWithinBounds = false
            else
                -- Check if mouse is within the intersection bounds
                if not mx or not my or mx < intersectX or mx > intersectRight or my < intersectY or my > intersectBottom then
                    isWithinBounds = false
                end
            end
        end

        if isWithinBounds then
            -- Check if mouse is over any option
            for i in ipairs(self.options) do
                if self:isPointInOption(mx, my, i) then
                    self.hoveredOption = i
                    break
                end
            end
            
            -- If no option is hovered but mouse is still within dropdown bounds,
            -- don't reset hoveredOption to nil - keep the dropdown open
        end
        
        -- Don't close dropdown on mouse movement - only on clicks outside
    end

    return false
end

function Dropdown:setOptions(options)
    self.options = options or {}
    self.dropdownHeight = #self.options * self.optionHeight + (DROPDOWN_PADDING * 2)
    self.selectedIndex = math.max(1, math.min(self.selectedIndex or 1, #self.options))
end

function Dropdown:setSelectedIndex(index)
    self.selectedIndex = math.max(1, math.min(index or 1, #self.options))
end

function Dropdown:getSelectedOption()
    return self.options[self.selectedIndex]
end

function Dropdown:setPosition(x, y)
    self.x = x or self.x
    self.y = y or self.y
end

function Dropdown:setDisabled(disabled)
    self.disabled = disabled or false
end

return Dropdown