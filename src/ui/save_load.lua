local Window = require("src.ui.common.window")
local SaveSlots = require("src.ui.save_slots")

local SaveLoad = {}

local function point_in_rect(px, py, rect)
    if not rect then return false end
    return px >= rect.x and px <= rect.x + rect.w and
        py >= rect.y and py <= rect.y + rect.h
end

function SaveLoad:new(options)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.onClose = options and options.onClose

    o.saveSlots = SaveSlots:new({
        onClose = o.onClose,
        disableSave = options and options.disableSave or false
    })

    local preferredW, preferredH = o.saveSlots:getPreferredSize()
    -- Add padding so the window chrome does not clip the content area
    local windowW = math.max(420, preferredW + 40)
    local windowH = math.max(540, preferredH + 60)

    o.window = Window.new({
        title = "Save & Load Game",
        width = windowW,
        height = windowH,
        useLoadPanelTheme = false,
        closable = true,
        draggable = true,
        resizable = false,
        onClose = function()
            -- Ensure window visibility cleared and call provided onClose
            o.window.visible = false
            if o.onClose then
                o.onClose()
            end
        end,
        drawContent = function(window, x, y, w, h) o.saveSlots:draw(x, y, w, h) end
    })
    return o
end

function SaveLoad:show()
    if self.window then self.window:show() end
end

function SaveLoad:hide()
    if self.window then self.window:hide() end
end

function SaveLoad:toggle()
    if self.window then self.window:toggle() end
end

function SaveLoad:mousepressed(mx, my, button)
    if not self.window or not self.window.visible then
        return false
    end

    if self.window:mousepressed(mx, my, button) then
        return true
    end

    local content = self.window:getContentBounds()
    if point_in_rect(mx, my, content) then
        return self.saveSlots:mousepressed(mx, my, button)
    end

    return false
end

function SaveLoad:textinput(text)
    if not self.window or not self.window.visible then
        return false
    end

    return self.saveSlots:textinput(text)
end

function SaveLoad:keypressed(key)
    if not self.window or not self.window.visible then
        return false
    end

    if self.saveSlots:keypressed(key) then
        return true
    end

    if key == "escape" then
        if self.window then
            self.window:hide()
            return true
        elseif self.onClose then
            self.onClose()
            return true
        end
    end
    return false
end

function SaveLoad:mousereleased(mx, my, button)
    if not self.window or not self.window.visible then
        return false
    end

    return self.window:mousereleased(mx, my, button)
end

function SaveLoad:mousemoved(mx, my, dx, dy)
    if not self.window or not self.window.visible then
        return false
    end

    return self.window:mousemoved(mx, my, dx, dy)
end

return SaveLoad
