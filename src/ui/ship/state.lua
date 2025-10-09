local ShipState = {
    current = nil
}

local function create_state()
    return {
        slotRects = {},
        slotDropdowns = {},
        removeButtons = {},
        hotbarButtons = {},
        hoverTimers = {},
        hoverDelay = 0.3,
        window = nil,
        statsScroll = 0,
        slotScroll = 0,
        statsViewRect = nil,
        slotViewRect = nil,
        activeContentBounds = nil,
        visible = false,
    }
end

function ShipState.ensure()
    if not ShipState.current then
        ShipState.current = create_state()
    end
    return ShipState.current
end

function ShipState.prepareForShow(state)
    state.statsScroll = 0
    state.slotScroll = 0
    state.activeContentBounds = nil
    state.visible = true
end

function ShipState.markHidden(state)
    state.visible = false
    state.activeContentBounds = nil
end

return ShipState
