--[[
  Procedural Sound Generator for DarkOrbitLove
  Generates sound effects programmatically using Love2D's SoundData
]]

local SoundGenerator = {}
local Log = require("src.core.log")
local Util = require("src.core.util")

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

-- Generate a laser zap sound (combat laser) - Proper sci-fi laser beam
function SoundGenerator.generateLaserZap(duration, frequency, sampleRate)
    duration = duration or 0.55  -- Longer sustain for deep resonance
    frequency = frequency or 200  -- Very low base pitch for heavy rumble
    sampleRate = sampleRate or 22050

    local sampleCount = math.floor(duration * sampleRate)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)

    for i = 0, sampleCount - 1 do
        local t = i / sampleCount

        local baseFreq = frequency * (1 + 0.1 * math.sin(t * 4 * math.pi))
        local phase = t * baseFreq * 2 * math.pi

        local sample = math.sin(phase) * 0.45
        sample = sample + 0.5 * math.sin(phase * 0.4) -- sub bass swell
        sample = sample + 0.14 * math.sin(phase * 1.4)
        sample = sample + 0.06 * math.sin(phase * 2.1)

        local rumbleNoise = noise() * 0.3 * math.exp(-t * 2.8)
        sample = sample + rumbleNoise * math.sin(t * 110 * 2 * math.pi)

        local spark = 0.03 * math.sin(t * 650 * 2 * math.pi) * math.exp(-t * 5)
        sample = sample + spark

        if t < 0.22 then
            local surge = (1 - t * 4.5) * 0.25
            sample = sample + noise() * surge * math.sin(t * 210 * 2 * math.pi)
        end

        local attack = math.min(1.0, t * 9)
        local sustain = 1.0
        local decay = math.exp(-(t - 0.45) * 4.5)
        local envelope = attack * (t < 0.45 and sustain or decay)

        sample = sample * envelope
        sample = sample * (1 + 0.06 * math.sin(t * 8 * math.pi))

        sample = Util.clamp(sample * 0.28, -1, 1)
        soundData:setSample(i, sample)
    end

    return soundData
end

-- Generate gun turret sound (rapid-fire projectile weapon)
function SoundGenerator.generateGunFire(duration, frequency, sampleRate)
    duration = duration or 0.15  -- Very short burst
    frequency = frequency or 400  -- Lower frequency for gun-like sound
    sampleRate = sampleRate or 22050

    local sampleCount = math.floor(duration * sampleRate)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)

    for i = 0, sampleCount - 1 do
        local t = i / sampleCount

        -- Main gun blast - lower frequency with sharp attack
        local baseFreq = frequency * (1 + 0.3 * math.sin(t * 6 * math.pi))
        local phase = t * baseFreq * 2 * math.pi
        
        local sample = math.sin(phase) * 0.6
        
        -- Add harmonics for gun-like character - much softer
        sample = sample + 0.2 * math.sin(phase * 2)  -- Reduced second harmonic
        sample = sample + 0.1 * math.sin(phase * 3)  -- Reduced third harmonic
        
        -- Gun barrel "crack" - much softer high-frequency component
        local crackFreq = 1000 + 200 * math.sin(t * 6 * math.pi)
        sample = sample + 0.15 * math.sin(t * crackFreq * 2 * math.pi) * math.exp(-t * 5)
        
        -- Explosive "pop" at the beginning - much gentler gunpowder ignition
        if t < 0.05 then
            local popIntensity = (1 - t * 20) * 0.25
            sample = sample + noise() * popIntensity * math.sin(t * 500 * 2 * math.pi)
        end
        
        -- Gun barrel resonance - metallic ring
        local barrelRing = 0.2 * math.sin(t * 300 * 2 * math.pi) * math.exp(-t * 2)
        sample = sample + barrelRing
        
        -- Sharp attack envelope - very quick attack and decay
        local attack = math.min(1.0, t * 25)  -- Very sharp attack
        local decay = math.exp(-t * 12)  -- Quick decay
        local envelope = attack * decay
        
        sample = sample * envelope
        
        -- Add slight mechanical vibration
        sample = sample * (1 + 0.05 * math.sin(t * 50 * math.pi))
        
        -- Clamp and convert to 16-bit - much quieter
        sample = Util.clamp(sample * 0.25, -1, 1)
        soundData:setSample(i, sample)
    end

    return soundData
end

-- Generate a mining laser sound (industrial, looping, deep, quiet)
function SoundGenerator.generateMiningLaser(duration, frequency, sampleRate)
    duration = duration or 0.55  -- Loop segment for heavy hum
    frequency = frequency or 90
    sampleRate = sampleRate or 22050

    local sampleCount = math.floor(duration * sampleRate)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)

    for i = 0, sampleCount - 1 do
        local t = i / sampleCount

        local baseFreq = frequency
        local harmonic1 = math.sin(t * baseFreq * 2 * math.pi) * 0.35
        local harmonic2 = math.sin(t * baseFreq * 1.3 * 2 * math.pi) * 0.24
        local harmonic3 = math.sin(t * baseFreq * 1.7 * 2 * math.pi) * 0.14
        local harmonic4 = math.sin(t * baseFreq * 2.1 * 2 * math.pi) * 0.08

        local rumbleFreq = 22 + 6 * math.sin(t * 0.35 * 2 * math.pi)
        local rumble = math.sin(t * rumbleFreq * 2 * math.pi) * 0.36
        local subRumble = math.sin(t * 12 * 2 * math.pi) * 0.2

        local cuttingNoise = noise() * 0.18
        local cuttingFreq = 140 + 60 * math.sin(t * 1.1 * 2 * math.pi)
        local cuttingFiltered = cuttingNoise * (0.3 + 0.3 * math.sin(t * cuttingFreq * 2 * math.pi))

        local powerFluctuation = 1.0 + 0.05 * math.sin(t * 5 * 2 * math.pi) + 0.04 * math.sin(t * 11 * 2 * math.pi)

        local crackleIntensity = 0.1 + 0.06 * math.sin(t * 3 * 2 * math.pi)
        local crackle = noise() * 0.05 * crackleIntensity

        local sample = (harmonic1 + harmonic2 + harmonic3 + harmonic4 + rumble + subRumble + cuttingFiltered + crackle) * powerFluctuation

        local envelope = 0.93 + 0.07 * math.sin(t * 1.0 * 2 * math.pi)
        sample = sample * envelope

        sample = sample + noise() * 0.018 * envelope
        sample = Util.clamp(sample * 0.2, -1, 1)
        soundData:setSample(i, sample)
    end

    return soundData
end

-- Generate a salvaging laser sound (smooth, higher pitch)
function SoundGenerator.generateSalvagingLaser(duration, frequency, sampleRate)
    duration = duration or 0.5
    frequency = frequency or 260
    sampleRate = sampleRate or 22050

    local sampleCount = math.floor(duration * sampleRate)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)

    for i = 0, sampleCount - 1 do
        local t = i / sampleCount

        local modulation = 1 + 0.12 * math.sin(t * 10 * math.pi)
        local envelope = modulation * math.exp(-t * 4)

        local baseFreq = frequency * (1 - t * 0.3)
        local phase = t * baseFreq * 2 * math.pi

        local sample = math.sin(phase) * 0.42
        sample = sample + 0.28 * math.sin(phase * 0.6)
        sample = sample + 0.12 * math.sin(phase * 1.6)

        sample = sample + 0.05 * math.sin(t * 520 * 2 * math.pi) * math.exp(-t * 6)

        sample = sample * envelope

        sample = Util.clamp(sample * 0.24, -1, 1)
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
        
        sample = Util.clamp(sample * 0.5, -1, 1)
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
        s = Util.clamp(s * 0.9, -1, 1)
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
        
        sample = Util.clamp(sample * 0.5, -1, 1)
        soundData:setSample(i, sample)
    end
    
    return soundData
end

-- Generate explosion sound (enhanced for ship destruction sonic boom)
function SoundGenerator.generateExplosion(duration, sampleRate)
    duration = duration or 1.2  -- Slightly longer for sonic boom effect
    sampleRate = sampleRate or 22050

    local sampleCount = math.floor(duration * sampleRate)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)

    for i = 0, sampleCount - 1 do
        local t = i / sampleCount

        -- Sonic boom characteristics: sharp initial crack followed by rapid decay
        local sharpCrack = 0
        if t < 0.05 then  -- Very sharp initial spike (first 50ms)
            sharpCrack = noise() * 2 * (1 - t * 20)
        end

        -- Low-frequency boom that builds and decays
        local lowBoom = noise() * 1.5 * math.sin(t * math.pi * 2) * math.exp(-t * 4)

        -- Mid-frequency crackle
        local midCrackle = noise() * 0.8 * math.exp(-t * 6)

        -- High-frequency snap/whip
        local highSnap = noise() * 0.6 * math.exp(-t * 12) * math.sin(t * 200 * 2 * math.pi)

        local sample = sharpCrack + lowBoom + midCrackle + highSnap

        -- Add some tonal elements for metallic ship destruction feel
        sample = sample + 0.4 * math.sin(t * 80 * 2 * math.pi) * math.exp(-t * 5)  -- Metallic ring
        sample = sample + 0.2 * math.sin(t * 40 * 2 * math.pi) * math.exp(-t * 3)  -- Lower metallic tone

        -- Sharp attack envelope followed by rapid decay
        local attack = math.min(1.0, t * 20)  -- Quick attack
        local decay = math.exp(-t * 3)        -- Rapid decay
        local envelope = attack * decay
        sample = sample * envelope

        sample = Util.clamp(sample * 0.7, -1, 1)
        soundData:setSample(i, sample)
    end

    return soundData
end

-- Generate ship destruction sound (metallic destruction with electrical failure)
function SoundGenerator.generateShipDestruction(duration, sampleRate)
    duration = duration or 2.0  -- Longer for dramatic effect
    sampleRate = sampleRate or 22050

    local sampleCount = math.floor(duration * sampleRate)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)

    for i = 0, sampleCount - 1 do
        local t = i / sampleCount

        -- Initial structural failure - sharp metallic crack
        local structuralCrack = 0
        if t < 0.1 then
            structuralCrack = noise() * 1.5 * (1 - t * 10) * math.sin(t * 200 * 2 * math.pi)
        end

        -- Metallic tearing and bending
        local metallicTear = 0
        if t > 0.05 and t < 0.4 then
            local tearIntensity = math.exp(-(t - 0.05) * 8)
            metallicTear = noise() * 0.8 * tearIntensity * math.sin(t * 150 * 2 * math.pi)
        end

        -- Electrical system failure - buzzing and arcing
        local electricalFailure = 0
        if t > 0.1 and t < 0.6 then
            local elecIntensity = math.exp(-(t - 0.1) * 4)
            electricalFailure = noise() * 0.6 * elecIntensity * math.sin(t * 400 * 2 * math.pi)
        end

        -- Hull breach - whooshing air escape
        local hullBreach = 0
        if t > 0.2 and t < 0.8 then
            local breachIntensity = math.exp(-(t - 0.2) * 3)
            hullBreach = noise() * 0.4 * breachIntensity * math.sin(t * 80 * 2 * math.pi)
        end

        -- Final explosion - deep boom
        local finalBoom = 0
        if t > 0.5 then
            local boomIntensity = math.exp(-(t - 0.5) * 2)
            finalBoom = noise() * 1.2 * boomIntensity * math.sin(t * 60 * 2 * math.pi)
        end

        -- Metallic resonance - sustained ringing
        local metallicRing = 0
        if t > 0.3 then
            local ringIntensity = math.exp(-(t - 0.3) * 1.5)
            metallicRing = 0.3 * math.sin(t * 120 * 2 * math.pi) * ringIntensity
        end

        -- Combine all elements
        local sample = structuralCrack + metallicTear + electricalFailure + hullBreach + finalBoom + metallicRing

        -- Overall envelope - gradual build and decay
        local envelope = math.min(1.0, t * 5) * math.exp(-t * 1.2)
        sample = sample * envelope

        sample = Util.clamp(sample * 0.6, -1, 1)
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
        
        sample = Util.clamp(sample * 0.5, -1, 1)
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
        
        sample = Util.clamp(sample * 0.7, -1, 1)
        soundData:setSample(i, sample)
    end
    
    return soundData
end

-- Generate a cavernous asteroid shatter with explosive depth
function SoundGenerator.generateAsteroidPop(duration, sampleRate)
    duration = duration or 0.65
    sampleRate = sampleRate or 22050

    local sampleCount = math.floor(duration * sampleRate)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)

    for i = 0, sampleCount - 1 do
        local t = i / sampleCount

        local shock = 0
        if t < 0.1 then
            local shockIntensity = (1 - t * 10) * 2.6
            shock = noise() * shockIntensity * math.sin(t * 600 * 2 * math.pi)
        end

        local lowFracture = 0
        if t < 0.28 then
            local fractureIntensity = math.exp(-t * 6.2) * 1.6
            lowFracture = math.sin(t * 30 * 2 * math.pi) * fractureIntensity
        end

        local slabTear = 0
        if t > 0.03 and t < 0.32 then
            local tearIntensity = math.exp(-(t - 0.03) * 7.2) * 0.95
            slabTear = noise() * tearIntensity * math.sin(t * 150 * 2 * math.pi)
        end

        local crystalShimmer = 0
        if t > 0.06 and t < 0.36 then
            local shimmerIntensity = math.exp(-(t - 0.06) * 10.5) * 0.48
            crystalShimmer = noise() * shimmerIntensity * math.sin(t * 520 * 2 * math.pi)
        end

        local debrisRoll = 0
        if t > 0.12 and t < 0.5 then
            local rollIntensity = math.exp(-(t - 0.12) * 4.3) * 0.65
            debrisRoll = noise() * rollIntensity * math.sin(t * 95 * 2 * math.pi)
        end

        local subRumble = math.sin(t * 18 * 2 * math.pi) * math.exp(-t * 3.4) * 0.75

        local sample = shock + lowFracture + slabTear + crystalShimmer + debrisRoll + subRumble

        local attack = math.min(1.0, t * 22)
        local sustain = 1.0
        local decay = math.exp(-(t - 0.12) * 3.6)
        local envelope = attack * (t < 0.12 and sustain or decay)

        sample = sample * envelope
        sample = sample * (1 + 0.08 * math.sin(t * 9 * math.pi))

        sample = Util.clamp(sample * 1.5, -1, 1)
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
        elseif soundType == "gun_fire" then
            soundData = SoundGenerator.generateGunFire(...)
        elseif soundType == "mining_laser" then
            soundData = SoundGenerator.generateMiningLaser(...)
        elseif soundType == "salvaging_laser" then
            soundData = SoundGenerator.generateSalvagingLaser(...)
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
        elseif soundType == "asteroid_pop" then
            soundData = SoundGenerator.generateAsteroidPop(...)
        elseif soundType == "ship_destruction" then
            soundData = SoundGenerator.generateShipDestruction(...)
        else
            return nil
        end
        
        local source = love.audio.newSource(soundData, "static")
        -- Set mining laser to loop for continuous operation
        if soundType == "mining_laser" then
            source:setLooping(true)
        end
        soundCache[key] = source
        Log.debug("Generated procedural sound:", key)
    end
    
    return soundCache[key]
end

-- Generate all basic game sounds
function SoundGenerator.generateBasicGameSounds()
    -- Generate laser variants (deep rumbling)
    SoundGenerator.getCachedSound("laser", 0.45, 220)
    SoundGenerator.getCachedSound("laser", 0.55, 200)
    SoundGenerator.getCachedSound("laser", 0.65, 180)

    -- Generate specialized laser sounds
    SoundGenerator.getCachedSound("mining_laser", 0.55, 90)
    SoundGenerator.getCachedSound("salvaging_laser", 0.5, 260)

    -- Generate impact sounds
    SoundGenerator.getCachedSound("shield_hit", 0.15)
    SoundGenerator.getCachedSound("hull_hit", 0.3)
    SoundGenerator.getCachedSound("shield_static", 0.14)

    -- Generate explosion
    SoundGenerator.getCachedSound("explosion", 1.2)

    -- Generate missile launch
    SoundGenerator.getCachedSound("missile", 0.8)

    Log.debug("Generated all basic game sounds")
end

return SoundGenerator
