local Log = require("src.core.log")
local PlayerRef = require("src.core.player_ref")
local State = require("src.ui.ship.state")
local WindowController = require("src.ui.ship.window")
local Draw = require("src.ui.ship.draw")
local Dropdowns = require("src.ui.ship.dropdowns")
local Events = require("src.ui.ship.events")

local Ship = {}
Ship.visible = false

function Ship.debugTurrets()
    -- No-op placeholder retained for potential debug hooks
end

local function ensure_state()
    local state = State.ensure()
    WindowController.ensure(state, function(currentState, _, x, y, w, h)
        local player = PlayerRef.get()
        Draw.render(currentState, player, x, y, w, h)
        Draw.drawDropdownOptions(currentState)
    end)
    return state
end

function Ship.ensure()
    return ensure_state()
end

function Ship.show()
    Log.info("Ship.show called")
    local state = ensure_state()
    State.prepareForShow(state)
    Ship.visible = true

    if state.window then
        WindowController.centerIfHidden(state)
        WindowController.show(state)
    end

    local player = PlayerRef.get()
    if player then
        Dropdowns.refresh(state, player)
    end

    return true
end

function Ship.hide()
    Log.info("Ship.hide called")
    local state = State.ensure()
    if not state.window then
        Ship.visible = false
        State.markHidden(state)
        return false
    end

    WindowController.hide(state)
    Ship.visible = false
    State.markHidden(state)
    return false
end

function Ship.toggle()
    if Ship.visible then
        return Ship.hide()
    else
        return Ship.show()
    end
end

function Ship:getWindow()
    local state = ensure_state()
    return state.window
end

function Ship:getInstance()
    return ensure_state()
end

function Ship:updateDropdowns(player)
    local state = ensure_state()
    Dropdowns.refresh(state, player or PlayerRef.get())
end

function Ship:draw(player, x, y, w, h)
    local state = ensure_state()
    player = player or PlayerRef.get()
    Draw.render(state, player, x, y, w, h)
end

function Ship:drawDropdownOptions()
    local state = ensure_state()
    Draw.drawDropdownOptions(state)
end

local function allowInteraction(state)
    if Ship.visible and state.window and state.window.visible then
        return true
    end
    return state.activeContentBounds ~= nil
end

function Ship:mousepressed(x, y, button, player)
    local state = ensure_state()
    if not allowInteraction(state) then
        return false, false
    end

    player = player or PlayerRef.get()
    return Events.mousepressed(state, x, y, button, player)
end

function Ship:mousereleased(x, y, button, player)
    local state = ensure_state()
    if not allowInteraction(state) then
        return false, false
    end

    player = player or PlayerRef.get()
    return Events.mousereleased(state, x, y, button)
end

function Ship:mousemoved(x, y, dx, dy, player)
    local state = ensure_state()
    if not allowInteraction(state) then
        return false
    end

    player = player or PlayerRef.get()
    return Events.mousemoved(state, x, y, dx, dy)
end

function Ship:wheelmoved(x, y, dx, dy)
    local state = ensure_state()
    if not allowInteraction(state) then
        return false
    end

    return Events.wheelmoved(state, x, y, dx, dy)
end

function Ship.keypressed(key)
    if key == "f9" then
        Ship.debugTurrets()
        return true
    end
    return false
end

function Ship:update(dt)
    -- Placeholder for future update logic
end

return Ship
