--[[
  Sound System for DarkOrbitLove
  Handles loading, caching, and playing of sound effects and music
]]

local Settings = require("src.core.settings")
local Log = require("src.core.log")
local Constants = require("src.core.constants")
local Config = require("src.content.config")
local Sound = {}
local SoundGenerator = require("src.core.sound_generator")

-- Internal storage
local sfx = {}        -- Sound effects cache
local music = {}      -- Music cache
local currentMusic = nil
local masterVolume = 1.0
local sfxVolume = 1.0
local musicVolume = 1.0

local function normalizeVolume(volume, fallback)
    local candidate = tonumber(volume)
    if candidate and candidate == candidate then -- guard against NaN
        return math.max(0, math.min(1, candidate))
    end

    local fallbackNumber = tonumber(fallback)
    if fallbackNumber and fallbackNumber == fallbackNumber then
        return math.max(0, math.min(1, fallbackNumber))
    end

    -- As a last resort default to a sane audible value
    return 1.0
end

-- Listener (camera/player) world position for distance-based attenuation
local listenerX, listenerY = nil, nil

-- Audio attenuation settings (can be overridden via Config.AUDIO)
local function getAudioConfig()
    local overrides = (Config and Config.AUDIO) or {}
    local defaults = Constants.AUDIO
    return {
        FULL_VOLUME_DISTANCE = overrides.FULL_VOLUME_DISTANCE or defaults.FULL_VOLUME_DISTANCE,
        HEARING_DISTANCE = overrides.HEARING_DISTANCE or defaults.HEARING_DISTANCE,
        MIN_VOLUME = overrides.MIN_VOLUME or defaults.MIN_VOLUME
    }
end

local function attenuateVolume(baseVolume, x, y)
    if not x or not y or not listenerX or not listenerY then return baseVolume end
    local dx, dy = x - listenerX, y - listenerY
    local d = math.sqrt(dx*dx + dy*dy)
    local A = getAudioConfig()
    if d >= A.HEARING_DISTANCE then return 0 end
    if d <= A.FULL_VOLUME_DISTANCE then return baseVolume end
    local t = 1 - (d - A.FULL_VOLUME_DISTANCE) / math.max(1e-6, (A.HEARING_DISTANCE - A.FULL_VOLUME_DISTANCE))
    local v = baseVolume * math.max(A.MIN_VOLUME, t)
    return v
end

function Sound.setListenerPosition(x, y)
    listenerX, listenerY = x, y
end

function Sound.applySettings()
    local audioSettings = Settings.getAudioSettings() or {}
    Sound.setMasterVolume(audioSettings.master_volume)
    Sound.setSFXVolume(audioSettings.sfx_volume)
    Sound.setMusicVolume(audioSettings.music_volume)
end

-- Helper to compute stereo pan (-1..1) from world X relative to listener
local function computePan(x)
    if not x or not listenerX then return 0 end
    local dx = x - listenerX
    -- Soft pan curve, clamp to [-1, 1]
    local pan = math.max(-1, math.min(1, dx / 800))
    return pan
end

-- Configuration
local soundPaths = {
    sfx = "content/sounds/sfx/",
    music = "content/sounds/music/"
}

-- Supported sound formats
local supportedFormats = {".ogg", ".wav", ".mp3"}

local SOUND_ALIAS_MAP = {
    ui_click = "button_click",
    ui_hover = "button_click",
    button_hover = "button_click",
    window_open = "button_click",
    window_close = "button_click",
    ui_error = "button_click",
    ore_collected = "item_pickup",
    dock = "loot_pickup",
    undock = "loot_pickup",
    engine_thrust = "shield_static",
    asteroid_shatter = "asteroid_pop",
}

-- Helper function to check if file exists
local function fileExists(path)
    local file = love.filesystem.getInfo(path)
    return file and file.type == "file"
end

-- Find sound file with supported extension
local function findSoundFile(basePath, name)
    for _, ext in ipairs(supportedFormats) do
        local fullPath = basePath .. name .. ext
        if fileExists(fullPath) then
            return fullPath
        end
    end
    return nil
end

local function resolveSoundName(name)
    local visited = {}
    local current = name
    while SOUND_ALIAS_MAP[current] do
        if visited[current] then
            break
        end
        visited[current] = true
        current = SOUND_ALIAS_MAP[current]
    end
    return current, current ~= name
end

-- Load a sound effect
function Sound.loadSFX(name, path)
    if sfx[name] then return sfx[name] end

    local resolvedName, aliased = name, false
    if not path then
        resolvedName, aliased = resolveSoundName(name)
        if aliased and sfx[resolvedName] then
            sfx[name] = sfx[resolvedName]
            return sfx[name]
        end
    end

    local soundPath = path or findSoundFile(soundPaths.sfx, resolvedName)
    if soundPath then
        local success, source = pcall(love.audio.newSource, soundPath, "static")
        if success then
            sfx[resolvedName] = source
            sfx[name] = source
            if aliased then
                Log.debug("Loaded SFX alias:", name, "->", resolvedName, "from", soundPath)
            else
                Log.debug("Loaded SFX:", name, "from", soundPath)
            end
            return source
        else
            Log.error("Error loading sound effect", name, ":", source)
        end
    end

    -- Try procedural generation as fallback
    local proceduralSound = nil
    local targetName = resolvedName
    if targetName == "railgun_turret_fire" then
        proceduralSound = SoundGenerator.generateKineticTurretFire()
    elseif targetName == "low_power_laser_fire" then
        proceduralSound = SoundGenerator.generateLowPowerLaserFire()
    elseif targetName == "missile_launcher_fire" then
        proceduralSound = SoundGenerator.generateMissileLauncherFire()
    -- Collision sounds
    elseif targetName == "shield_hit_light" then
        proceduralSound = SoundGenerator.generateShieldHitLight()
    elseif targetName == "shield_hit_heavy" then
        proceduralSound = SoundGenerator.generateShieldHitHeavy()
    elseif targetName == "hull_hit_light" then
        proceduralSound = SoundGenerator.generateHullHitLight()
    elseif targetName == "hull_hit_heavy" then
        proceduralSound = SoundGenerator.generateHullHitHeavy()
    elseif targetName == "hull_hit_critical" then
        proceduralSound = SoundGenerator.generateHullHitCritical()
    elseif targetName == "asteroid_hit_light" then
        proceduralSound = SoundGenerator.generateAsteroidHitLight()
    elseif targetName == "asteroid_hit_heavy" then
        proceduralSound = SoundGenerator.generateAsteroidHitHeavy()
    elseif targetName == "rock_impact" then
        proceduralSound = SoundGenerator.generateRockImpact()
    elseif targetName == "laser_fire" then
        proceduralSound = SoundGenerator.getCachedSound("laser", 0.55, 200) -- Combat laser: deep, bass-heavy blast
    elseif targetName == "mining_laser" then
        proceduralSound = SoundGenerator.getCachedSound("mining_laser", 0.55, 90) -- Mining laser: looping sub-bass rumble
    elseif targetName == "salvaging_laser" then
        proceduralSound = SoundGenerator.getCachedSound("salvaging_laser", 0.5, 260) -- Salvaging laser: warm low-mid sweep
    elseif targetName == "shield_hit" then
        proceduralSound = SoundGenerator.getCachedSound("shield_hit", 0.15)
    elseif targetName == "hull_hit" then
        proceduralSound = SoundGenerator.getCachedSound("hull_hit", 0.3)
    elseif targetName == "explosion" then
        proceduralSound = SoundGenerator.getCachedSound("explosion", 1.2)
    elseif targetName == "missile_launch" then
        proceduralSound = SoundGenerator.getCachedSound("missile", 0.8)
    elseif targetName == "gun_fire" then
        proceduralSound = SoundGenerator.getCachedSound("gun_fire", 0.15, 400) -- Dedicated gun fire sound
    elseif targetName == "shield_static" then
        proceduralSound = SoundGenerator.getCachedSound("shield_static", 0.14)
    elseif targetName == "asteroid_pop" then
        proceduralSound = SoundGenerator.getCachedSound("asteroid_pop", 0.65)
    elseif targetName == "ship_destroyed" then
        proceduralSound = SoundGenerator.getCachedSound("ship_destruction", 2.0)
    end

    if proceduralSound then
        sfx[targetName] = proceduralSound
        sfx[name] = proceduralSound
        if aliased then
            Log.debug("Generated procedural SFX alias:", name, "->", targetName)
        else
            Log.debug("Generated procedural SFX:", name)
        end
        return proceduralSound
    end

    Log.warn("Sound effect not found and no procedural fallback:", name)
    return nil
end

-- Load music
function Sound.loadMusic(name, path)
    if music[name] then return music[name] end
    
    local soundPath = path or findSoundFile(soundPaths.music, name)
    if not soundPath then
        Log.warn("Music not found:", name)
        return nil
    end
    
    local success, source = pcall(love.audio.newSource, soundPath, "stream")
    if not success then
        Log.error("Error loading music:", name, ":", source)
        return nil
    end
    
    source:setLooping(true)
    music[name] = source
    Log.debug("Loaded Music:", name, "from", soundPath)
    return source
end

-- Play sound effect
function Sound.playSFX(name, volume, pitch, path)
    local sound = sfx[name] or Sound.loadSFX(name, path)
    if not sound then return false end
    
    -- Clone the source for multiple simultaneous plays
    local instance = sound:clone()
    instance:setVolume((volume or 1.0) * sfxVolume * masterVolume)
    if pitch then instance:setPitch(pitch) end
    
    love.audio.play(instance)
    return instance
end

-- Play a positional SFX (attenuated based on distance to listener)
function Sound.playSFXAt(name, x, y, volume, pitch, path)
    local base = volume or 1.0
    local vol = attenuateVolume(base, x, y)
    if vol <= 0 then return false end
    local sound = sfx[name] or Sound.loadSFX(name, path)
    if not sound then return false end
    local instance = sound:clone()
    instance:setVolume(vol * sfxVolume * masterVolume)
    if pitch then instance:setPitch(pitch) end
    -- Panning based on X position
    local pan = computePan(x)
    if instance.setPosition then
        -- If using 3D sources in future
        instance:setPosition(pan, 0, 0)
    elseif instance.setStereoPan then
        instance:setStereoPan(pan)
    end
    love.audio.play(instance)
    return instance
end

-- Play music
function Sound.playMusic(name, fadeIn, path)
    local sound = music[name] or Sound.loadMusic(name, path)
    if not sound then return false end
    
    -- If this is already the current music and it's playing, don't restart it
    if currentMusic == sound and sound:isPlaying() then
        return true
    end
    
    -- Stop current music if different
    if currentMusic and currentMusic ~= sound then
        currentMusic:stop()
    end
    
    currentMusic = sound
    sound:setVolume(musicVolume * masterVolume)
    
    if fadeIn then
        sound:setVolume(0)
        love.audio.play(sound)
        -- TODO: Implement fade-in tween
    else
        love.audio.play(sound)
    end
    
    return true
end

-- Stop music
function Sound.stopMusic(fadeOut)
    if currentMusic then
        if fadeOut then
            -- TODO: Implement fade-out tween
            currentMusic:stop()
        else
            currentMusic:stop()
        end
        currentMusic = nil
    end
end

-- Pause/Resume music
function Sound.pauseMusic()
    if currentMusic then
        currentMusic:pause()
    end
end

function Sound.resumeMusic()
    if currentMusic then
        love.audio.play(currentMusic)
    end
end

-- Volume controls
function Sound.setMasterVolume(volume)
    masterVolume = normalizeVolume(volume, masterVolume)
    if currentMusic then
        currentMusic:setVolume(musicVolume * masterVolume)
    end
end

function Sound.setSFXVolume(volume)
    sfxVolume = normalizeVolume(volume, sfxVolume)
end

function Sound.setMusicVolume(volume)
    musicVolume = normalizeVolume(volume, musicVolume)
    if currentMusic then
        currentMusic:setVolume(musicVolume * masterVolume)
    end
end

function Sound.getMasterVolume() return masterVolume end
function Sound.getSFXVolume() return sfxVolume end
function Sound.getMusicVolume() return musicVolume end

-- Batch loading functions
function Sound.loadSFXBatch(sounds)
    for name, path in pairs(sounds) do
        Sound.loadSFX(name, path)
    end
end

function Sound.loadMusicBatch(songs)
    for name, path in pairs(songs) do
        Sound.loadMusic(name, path)
    end
end

-- Event-based sound attachment system
local soundEvents = {}

function Sound.attachSFX(event, soundName, options)
    options = options or {}
    soundEvents[event] = {
        type = "sfx",
        sound = soundName,
        volume = options.volume or 1.0,
        pitch = options.pitch,
        path = options.path
    }
end

function Sound.attachMusic(event, musicName, options)
    options = options or {}
    soundEvents[event] = {
        type = "music",
        sound = musicName,
        fadeIn = options.fadeIn,
        path = options.path
    }
end

function Sound.triggerEvent(event, ...)
    local soundEvent = soundEvents[event]
    if not soundEvent then return false end
    local args = {...}
    local x, y = nil, nil
    if type(args[1]) == 'number' and type(args[2]) == 'number' then
        x, y = args[1], args[2]
    end

    if soundEvent.type == "sfx" then
        if x and y then
            return Sound.playSFXAt(soundEvent.sound, x, y, soundEvent.volume, soundEvent.pitch, soundEvent.path)
        end
        return Sound.playSFX(soundEvent.sound, soundEvent.volume, soundEvent.pitch, soundEvent.path)
    elseif soundEvent.type == "music" then
        return Sound.playMusic(soundEvent.sound, soundEvent.fadeIn, soundEvent.path)
    end
    
    return false
end

function Sound.triggerEventAt(event, x, y)
    return Sound.triggerEvent(event, x, y)
end

-- Cleanup
function Sound.cleanup()
    for _, source in pairs(sfx) do
        source:stop()
        source:release()
    end
    for _, source in pairs(music) do
        source:stop()
        source:release()
    end
    sfx = {}
    music = {}
    currentMusic = nil
end

return Sound
