local ContentLoader = {}

local Log = require("src.core.log")
local Content = require("src.content.content")

function ContentLoader.loadWithProgress(loadingScreen, callback)
    loadingScreen:show({"Loading content...", "Loading world...", "Initializing systems...", "Finalizing..."}, false)
    
    -- Track loading progress
    local progress = 0
    local totalSteps = 4
    
    local function updateProgress(step, description)
        progress = step / totalSteps
        loadingScreen:setProgress(progress, description)
    end
    
    -- Step 1: Load content
    updateProgress(1, "Loading content...")
    Content.load()
    
    -- Step 2: Load world (this happens in Game.load)
    updateProgress(2, "Loading world...")
    
    -- Step 3: Initialize systems (this happens in Game.load)
    updateProgress(3, "Initializing systems...")
    
    -- Step 4: Complete
    updateProgress(4, "Finalizing...")
    loadingScreen:setComplete()
    
    if callback then callback(true) end
end

return ContentLoader
