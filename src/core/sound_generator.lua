--[[
  Procedural Sound Generator for DarkOrbitLove
  Generates sound effects programmatically using Love2D's SoundData
]]

local SoundGenerator = {}
local Log = require("src.core.log")

-- Helper function to clamp values
local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- Generate white noise
local function noise()
    return (math.random() * 2 - 1)
end

-- Simple low-pass filter
local function lowpass(input, cutoff, sampleRate)
    local rc = 1.0 / (cutoff * 2 * math.pi)
    local dt = 1.0 / sampleRate
    local alpha = dt / (rc + dt)
    return alpha * input
end

-- Simple high-pass filter (one-pole)
local function highpass(prevOut, input, cutoff, sampleRate)
    local rc = 1.0 / (cutoff * 2 * math.pi)
    local dt = 1.0 / sampleRate
    local alpha = rc / (rc + dt)
    return alpha * (prevOut + input - (prevOut or 0))
end

-- Generate a laser zap sound
function SoundGenerator.generateLaserZap(duration, frequency, sampleRate)
    duration = duration or 0.3
    frequency = frequency or 800
    sampleRate = sampleRate or 22050
    
    local sampleCount = math.floor(duration * sampleRate)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)
    
    local phase = 0
    local phaseIncrement = frequency / sampleRate * 2 * math.pi
    local envelope = 1.0
    local envelopeDecay = 1.0 / sampleCount
    
    for i = 0, sampleCount - 1 do
        local t = i / sampleCount
        
        -- Base sine wave with frequency modulation
        local freqMod = frequency * (1 - t * 0.7) -- Frequency drops over time
        phaseIncrement = freqMod / sampleRate * 2 * math.pi
        phase = phase + phaseIncrement
        
        local sample = math.sin(phase)
        
        -- Add some harmonics for richness
        sample = sample + 0.3 * math.sin(phase * 2)
        sample = sample + 0.1 * math.sin(phase * 3)
        
        -- Add slight noise for texture
        sample = sample + noise() * 0.05
        
        -- Envelope (quick attack, exponential decay)
        envelope = math.exp(-t * 8)
        sample = sample * envelope
        
        -- Clamp and convert to 16-bit
        sample = clamp(sample * 0.3, -1, 1)
        soundData:setSample(i, sample)
    end
    
    return soundData
end

-- Generate shield hit sound (energy shield impact with harmonic resonance)
function SoundGenerator.generateShieldHit(duration, sampleRate)
    duration = duration or 0.25
    sampleRate = sampleRate or 22050
    
    local sampleCount = math.floor(duration * sampleRate)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)
    
    for i = 0, sampleCount - 1 do
        local t = i / sampleCount
        
        -- Energy shield resonance - multiple harmonic frequencies
        local baseFreq = 600
        local harmonic1 = math.sin(t * baseFreq * 2 * math.pi) * 0.4
        local harmonic2 = math.sin(t * baseFreq * 1.5 * 2 * math.pi) * 0.25
        local harmonic3 = math.sin(t * baseFreq * 3 * 2 * math.pi) * 0.15
        
        -- Energy discharge shimmer - high frequency modulation
        local shimmer = math.sin(t * 1800 * 2 * math.pi) * 0.2 * math.exp(-t * 8)
        
        -- Electric arc crackle - filtered noise bursts
        local crackleIntensity = math.exp(-t * 12) * (0.5 + 0.5 * math.sin(t * 40 * math.pi))
        local crackle = noise() * 0.3 * crackleIntensity
        
        -- Energy field distortion - sweeping frequency
        local sweepFreq = baseFreq * (1 + t * 0.8) -- Rising frequency sweep
        local energySweep = math.sin(t * sweepFreq * 2 * math.pi) * 0.2
        
        -- Combine all elements
        local sample = harmonic1 + harmonic2 + harmonic3 + shimmer + crackle + energySweep
        
        -- Energy shield envelope - sharp attack, resonant sustain, gradual decay
        local envelope = math.exp(-t * 6) * (1 + 0.3 * math.sin(t * 15 * math.pi))
        sample = sample * envelope
        
        -- Add subtle electromagnetic interference
        sample = sample + noise() * 0.05 * envelope
        
        sample = clamp(sample * 0.5, -1, 1)
        soundData:setSample(i, sample)
    end
    
    return soundData
end

-- Generate shield static crackle for bouncy shield collisions
function SoundGenerator.generateShieldStatic(duration, sampleRate)
    duration = duration or 0.14
    sampleRate = sampleRate or 22050

    local sampleCount = math.floor(duration * sampleRate)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)

    local last = 0
    for i = 0, sampleCount - 1 do
        local t = i / sampleCount
        -- Burst-gated white noise with slight high-pass for crisp static
        local gate = (math.random() < 0.4) and 1 or 0
        local n = noise() * 0.8 * gate
        -- Quick attack, quick decay envelope
        local env = math.min(1, t * 20) * math.exp(-t * 16)
        -- Add faint tonal zap underneath
        local zap = math.sin(t * 1400 * 2 * math.pi) * 0.12 * env
        local s = n * env + zap
        -- Subtle high-pass to reduce boominess
        last = 0.9 * last + 0.1 * s
        s = s - last * 0.2
        s = clamp(s * 0.9, -1, 1)
        soundData:setSample(i, s)
    end

    return soundData
end

-- Generate hull hit sound (metallic clang)
function SoundGenerator.generateHullHit(duration, sampleRate)
    duration = duration or 0.4
    sampleRate = sampleRate or 22050
    
    local sampleCount = math.floor(duration * sampleRate)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)
    
    local frequencies = {200, 350, 600, 1200} -- Metallic resonance frequencies
    
    for i = 0, sampleCount - 1 do
        local t = i / sampleCount
        local sample = 0
        
        -- Multiple resonant frequencies for metallic sound
        for _, freq in ipairs(frequencies) do
            local phase = t * freq * 2 * math.pi
            local amplitude = math.exp(-t * (freq / 100)) -- Higher frequencies decay faster
            sample = sample + math.sin(phase) * amplitude * 0.25
        end
        
        -- Add impact noise
        sample = sample + noise() * 0.1 * math.exp(-t * 10)
        
        -- Overall envelope
        local envelope = math.exp(-t * 5)
        sample = sample * envelope
        
        sample = clamp(sample * 0.5, -1, 1)
        soundData:setSample(i, sample)
    end
    
    return soundData
end

-- Generate explosion sound
function SoundGenerator.generateExplosion(duration, sampleRate)
    duration = duration or 1.0
    sampleRate = sampleRate or 22050
    
    local sampleCount = math.floor(duration * sampleRate)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)
    
    for i = 0, sampleCount - 1 do
        local t = i / sampleCount
        
        -- Explosion starts with low-frequency boom
        local lowRumble = noise() * (1 - t)
        local midCrackle = noise() * 0.5 * math.exp(-t * 3)
        local highHiss = noise() * 0.3 * math.exp(-t * 8)
        
        local sample = lowRumble + midCrackle + highHiss
        
        -- Add some tonal elements
        sample = sample + 0.3 * math.sin(t * 60 * 2 * math.pi) * math.exp(-t * 4)
        sample = sample + 0.2 * math.sin(t * 30 * 2 * math.pi) * math.exp(-t * 2)
        
        -- Envelope with longer decay
        local envelope = math.exp(-t * 2)
        sample = sample * envelope
        
        sample = clamp(sample * 0.6, -1, 1)
        soundData:setSample(i, sample)
    end
    
    return soundData
end

-- Generate missile launch sound
function SoundGenerator.generateMissileLaunch(duration, sampleRate)
    duration = duration or 0.8
    sampleRate = sampleRate or 22050
    
    local sampleCount = math.floor(duration * sampleRate)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)
    
    for i = 0, sampleCount - 1 do
        local t = i / sampleCount
        
        -- Whoosh sound with pitch modulation
        local baseFreq = 100 * (1 + t * 2) -- Rising pitch
        local phase = t * baseFreq * 2 * math.pi
        
        local sample = math.sin(phase) * 0.4
        
        -- Add noise for thrust
        sample = sample + noise() * 0.3 * (1 - t * 0.5)
        
        -- Add some harmonics
        sample = sample + 0.2 * math.sin(phase * 1.5)
        sample = sample + 0.1 * math.sin(phase * 0.7)
        
        -- Envelope with sustain
        local envelope = math.min(1, t * 10) * math.exp(-t * 1.5)
        sample = sample * envelope
        
        sample = clamp(sample * 0.5, -1, 1)
        soundData:setSample(i, sample)
    end
    
    return soundData
end

function SoundGenerator.generateLockOn(duration, sampleRate)
    duration = duration or 0.15
    sampleRate = sampleRate or 22050
    
    local sampleCount = math.floor(duration * sampleRate)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)
    
    local freq = 1200
    
    for i = 0, sampleCount - 1 do
        local t = i / sampleCount
        
        local phase = t * freq * 2 * math.pi
        local sample = math.sin(phase) * 0.5
        
        local envelope = math.exp(-t * 20)
        sample = sample * envelope
        
        sample = clamp(sample * 0.7, -1, 1)
        soundData:setSample(i, sample)
    end
    
    return soundData
end

-- Cache for generated sounds
local soundCache = {}

-- Generate and cache a sound
function SoundGenerator.getCachedSound(soundType, ...)
    local key = soundType .. table.concat({...}, "_")
    
    if not soundCache[key] then
        local soundData
        if soundType == "laser" then
            soundData = SoundGenerator.generateLaserZap(...)
        elseif soundType == "shield_hit" then
            soundData = SoundGenerator.generateShieldHit(...)
        elseif soundType == "hull_hit" then
            soundData = SoundGenerator.generateHullHit(...)
        elseif soundType == "explosion" then
            soundData = SoundGenerator.generateExplosion(...)
        elseif soundType == "missile" then
            soundData = SoundGenerator.generateMissileLaunch(...)
        elseif soundType == "lock_on" then
            soundData = SoundGenerator.generateLockOn(...)
        elseif soundType == "shield_static" then
            soundData = SoundGenerator.generateShieldStatic(...)
        else
            return nil
        end
        
        soundCache[key] = love.audio.newSource(soundData, "static")
        Log.info("Generated procedural sound:", key)
    end
    
    return soundCache[key]
end

-- Generate all basic game sounds
function SoundGenerator.generateBasicGameSounds()
    -- Generate laser variants
    SoundGenerator.getCachedSound("laser", 0.2, 1000) -- Short, high-pitch
    SoundGenerator.getCachedSound("laser", 0.3, 800)  -- Medium
    SoundGenerator.getCachedSound("laser", 0.4, 600)  -- Long, low-pitch
    
    -- Generate impact sounds
    SoundGenerator.getCachedSound("shield_hit", 0.15)
    SoundGenerator.getCachedSound("hull_hit", 0.3)
    SoundGenerator.getCachedSound("shield_static", 0.14)
    
    -- Generate explosion
    SoundGenerator.getCachedSound("explosion", 1.2)
    
    -- Generate missile launch
    SoundGenerator.getCachedSound("missile", 0.8)
    
    Log.info("Generated all basic game sounds")
end

return SoundGenerator
