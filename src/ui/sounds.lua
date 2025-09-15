local Sound = require("src.core.sound")
local Settings = require("src.core.settings")

local UISounds = {}

-- Sound effect names (these should match your sound files in content/sounds/sfx/)
UISounds.SOUNDS = {
    BUTTON_CLICK = "button_click",
    BUTTON_HOVER = "button_hover",
    WINDOW_OPEN = "window_open",
    WINDOW_CLOSE = "window_close"
}

-- Load all UI sounds
function UISounds.load()
    -- Preload all UI sounds
    for _, soundName in pairs(UISounds.SOUNDS) do
        Sound.loadSFX(soundName)
    end
end

-- Play a UI sound with optional volume scale (0.0 to 1.0)
function UISounds.play(soundName, volumeScale)
    if not soundName then return end
    
    -- Get the audio settings
    local audioSettings = Settings.getAudioSettings()
    if not audioSettings.ui_sounds_enabled then return end
    
    -- Play the sound with proper volume scaling
    local volume = (audioSettings.ui_sounds_volume or 1.0) * (volumeScale or 1.0)
    Sound.playSFX(soundName, nil, volume, nil, nil, nil, "ui")
end

-- Shortcut for button click sound
function UISounds.playButtonClick()
    UISounds.play(UISounds.SOUNDS.BUTTON_CLICK)
end

-- Shortcut for button hover sound
function UISounds.playButtonHover()
    UISounds.play(UISounds.SOUNDS.BUTTON_HOVER)
end

-- Initialize the UI sounds when this module is required
UISounds.load()

return UISounds
