local State = {
    world = nil,
    camera = nil,
    player = nil,
    hub = nil,
    clickMarkers = {},
    hoveredEntity = nil,
    hoveredEntityType = nil,
    collisionSystem = nil,
    windfieldManager = nil,
    refreshDockingState = nil,
    systemPipeline = nil,
    systemContext = {},
    ecsManager = nil,
    networkManager = nil,
}

function State.reset()
    State.world = nil
    State.camera = nil
    State.player = nil
    State.hub = nil
    State.clickMarkers = {}
    State.hoveredEntity = nil
    State.hoveredEntityType = nil
    State.collisionSystem = nil
    State.windfieldManager = nil
    State.refreshDockingState = nil
    State.systemPipeline = nil
    State.systemContext = {}
    State.ecsManager = nil
    State.networkManager = nil
end

return State
