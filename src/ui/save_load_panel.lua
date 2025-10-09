local SaveLoad = require("src.ui.save_load")
local UIState = require("src.core.ui.state")

local SaveLoadPanel = {}

SaveLoadPanel.visible = false
SaveLoadPanel.window = nil

function SaveLoadPanel.init()
    if SaveLoadPanel.window then return end
    
    SaveLoadPanel.window = SaveLoad:new({
        onClose = function()
            SaveLoadPanel.visible = false
            -- Update UIState
            if UIState and UIState.setShowingSaveSlots then
                UIState.setShowingSaveSlots(false)
            end
        end
    })
end

function SaveLoadPanel.show()
    if not SaveLoadPanel.window then
        SaveLoadPanel.init()
    end
    
    SaveLoadPanel.visible = true
    if SaveLoadPanel.window and SaveLoadPanel.window.window then
        SaveLoadPanel.window.window:show()
    end
    
    -- Update UIState
    if UIState and UIState.setShowingSaveSlots then
        UIState.setShowingSaveSlots(true)
    end
end

function SaveLoadPanel.hide()
    SaveLoadPanel.visible = false
    if SaveLoadPanel.window and SaveLoadPanel.window.window then
        SaveLoadPanel.window.window:hide()
    end
    
    -- Update UIState
    if UIState and UIState.setShowingSaveSlots then
        UIState.setShowingSaveSlots(false)
    end
end

function SaveLoadPanel.draw()
    if not SaveLoadPanel.visible or not SaveLoadPanel.window then return end
    
    if SaveLoadPanel.window.window then
        SaveLoadPanel.window.window:draw()
    end
end

function SaveLoadPanel.mousepressed(x, y, button)
    if not SaveLoadPanel.visible or not SaveLoadPanel.window then return false end
    
    return SaveLoadPanel.window:mousepressed(x, y, button)
end

function SaveLoadPanel.mousereleased(x, y, button)
    if not SaveLoadPanel.visible or not SaveLoadPanel.window then return false end
    
    return SaveLoadPanel.window:mousereleased(x, y, button)
end

function SaveLoadPanel.mousemoved(x, y, dx, dy)
    if not SaveLoadPanel.visible or not SaveLoadPanel.window then return false end
    
    return SaveLoadPanel.window:mousemoved(x, y, dx, dy)
end

function SaveLoadPanel.keypressed(key)
    if not SaveLoadPanel.visible or not SaveLoadPanel.window then return false end
    
    return SaveLoadPanel.window:keypressed(key)
end

function SaveLoadPanel.textinput(text)
    if not SaveLoadPanel.visible or not SaveLoadPanel.window then return false end
    
    return SaveLoadPanel.window:textinput(text)
end

return SaveLoadPanel
