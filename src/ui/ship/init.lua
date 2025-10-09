--[[
    Ship UI Main Orchestrator
    
    Coordinates all Ship UI modules and provides the main interface.
    Integrates with the panel registry system.
]]

local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Content = require("src.content.content")
local Turret = require("src.systems.turret.core")
local InventoryUI = require("src.ui.inventory")
local IconSystem = require("src.core.icon_system")
local Tooltip = require("src.ui.tooltip")
local Log = require("src.core.log")
local Dropdown = require("src.ui.common.dropdown")
local PlayerRef = require("src.core.player_ref")
local HotbarSystem = require("src.systems.hotbar")
local Notifications = require("src.ui.notifications")
local HotbarUI = require("src.ui.hud.hotbar")
local Window = require("src.ui.common.window")

-- Import all Ship UI modules
local ShipState = require("src.ui.ship.state")
local EquipmentGrid = require("src.ui.ship.equipment_grid")
local TurretManager = require("src.ui.ship.turret_manager")
local HotbarPreview = require("src.ui.ship.hotbar_preview")
local ShipInputHandler = require("src.ui.ship.input_handler")

local Ship = {}

function Ship:new()
    local o = {}
    setmetatable(o, Ship)
    Ship.__index = Ship
    
    -- Initialize state
    o.state = ShipState.new()
    
    -- Initialize window
    o.window = Window.new({
        title = "Ship Management",
        width = 800,
        height = 600,
        minWidth = 600,
        minHeight = 400,
        resizable = true
    })
    
    -- Initialize visibility
    o.visible = false
    
    return o
end

function Ship:show()
    self.visible = true
    self.window:show()
    
    -- Update state from player
    self:updateFromPlayer()
end

function Ship:hide()
    self.visible = false
    self.window:hide()
end

function Ship:isVisible()
    return self.visible
end

function Ship:draw()
    if not self.visible then return end
    
    local x, y = self.window.x, self.window.y
    local w, h = self.window.width, self.window.height
    
    -- Draw window
    self.window:draw()
    
    -- Draw equipment grid
    local gridY = y + 60
    local gridH = h - 200
    EquipmentGrid.draw(self, x + 12, gridY, w - 24, gridH)
    
    -- Draw turret manager
    local turretY = y + gridY + gridH + 20
    local turretH = 120
    TurretManager.draw(self, x + 12, turretY, w - 24, turretH)
    
    -- Draw hotbar preview
    local hotbarY = y + turretY + turretH + 20
    local hotbarH = 80
    HotbarPreview.draw(self, x + 12, hotbarY, w - 24, hotbarH)
    
    -- Draw context menu
    self:drawContextMenu()
end

function Ship:drawContextMenu()
    local contextMenu = self.state:getContextMenu()
    if not contextMenu or not contextMenu.visible then return end
    
    local x = contextMenu.x
    local y = contextMenu.y
    local w = 150
    local h = #contextMenu.options * 24 + 8
    
    -- Context menu background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Context menu border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Context menu options
    for i, option in ipairs(contextMenu.options) do
        local optionY = y + 4 + (i - 1) * 24
        local optionH = 24
        
        -- Option background
        Theme.setColor(Theme.colors.bg2)
        love.graphics.rectangle("fill", x + 2, optionY, w - 4, optionH)
        
        -- Option text
        Theme.setColor(Theme.colors.text)
        Theme.setFont("small")
        love.graphics.print(option.text, x + 8, optionY + 6)
    end
end

function Ship:update(dt)
    if not self.visible then return end
    
    -- Update state from player
    self:updateFromPlayer()
    
    -- Update hotbar preview
    if self.state:getPlayer() then
        HotbarPreview.buildHotbarPreview(self, self.state:getPlayer())
    end
end

function Ship:updateFromPlayer()
    local player = PlayerRef.get()
    if player then
        self.state:setPlayer(player)
        self.state:updateFromPlayer()
        
        -- Update turret manager
        TurretManager.updateTurretsFromPlayer(self)
    end
end

function Ship:mousepressed(x, y, button)
    if not self.visible then return false end
    
    return ShipInputHandler.mousepressed(self, x, y, button)
end

function Ship:mousereleased(x, y, button)
    if not self.visible then return false end
    
    return ShipInputHandler.mousereleased(self, x, y, button)
end

function Ship:mousemoved(x, y, dx, dy)
    if not self.visible then return false end
    
    return ShipInputHandler.mousemoved(self, x, y, dx, dy)
end

function Ship:keypressed(key)
    if not self.visible then return false end
    
    return ShipInputHandler.keypressed(self, key)
end

function Ship:textinput(text)
    if not self.visible then return false end
    
    return ShipInputHandler.textinput(self, text)
end

function Ship:resize(w, h)
    if self.window then
        self.window:resize(w, h)
    end
end

-- Backward compatibility methods
function Ship:ensure()
    return self
end

function Ship:drawDropdownOptions()
    -- Handle dropdown rendering if needed
end

return Ship
