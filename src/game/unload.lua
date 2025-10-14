local State = require("src.game.state")

local UIManager = require("src.core.ui_manager")
local Events = require("src.core.events")
local NetworkSession = require("src.core.network.session")
local StateManager = require("src.managers.state_manager")
local HotbarSystem = require("src.systems.hotbar")
local PlayerRef = require("src.core.player_ref")
local Input = require("src.core.input")

local Unload = {}

function Unload.unload(Game)
    if UIManager and UIManager.reset then
        UIManager.reset()
    end

    Events.clear()
    NetworkSession.teardown()

    if StateManager and StateManager.reset then
        StateManager.reset()
    end

    if HotbarSystem and HotbarSystem.reset then
        HotbarSystem.reset()
    end

    PlayerRef.set(nil)

    local okRepairPopup, repairPopup = pcall(require, "src.ui.repair_popup")
    if okRepairPopup and repairPopup and repairPopup.hide then
        repairPopup.hide()
    end

    local world = State.world
    if world then
    end

    if State.windfieldManager and State.windfieldManager.destroy then
        State.windfieldManager:destroy()
    end

    Input.init({})

    Game.world = nil
    Game.windfield = nil

    State.reset()
end

return Unload
