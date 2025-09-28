local Theme = require("src.core.theme")
local StateManager = require("src.managers.state_manager")
local Window = require("src.ui.common.window")
local SaveSlots = require("src.ui.save_slots")

local SaveLoad = {}

function SaveLoad:new(options)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.onClose = options and options.onClose

    o.saveSlots = SaveSlots:new({
        onClose = o.onClose
    })

    o.window = Window.new({
        title = "Save & Load Game",
        width = 400,
        height = 500,
        useLoadPanelTheme = true,
        closable = true,
        onClose = function()
            if o.onClose then
                o.onClose()
            end
        end,
        drawContent = function(window, x, y, w, h) o.saveSlots:draw(x, y, w, h) end
    })
    return o
end

function SaveLoad:mousepressed(player, mx, my, button, w, h)
    return self.saveSlots:mousepressed(mx, my, button)
end

function SaveLoad:textinput(text)
    return self.saveSlots:textinput(text)
end

function SaveLoad:keypressed(key)
    if self.saveSlots:keypressed(key) then
        return true
    end

    if key == "escape" then
        if self.onClose then
            self.onClose()
            return true
        end
    end
    return false
end

return SaveLoad