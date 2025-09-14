--[[
  Sound Export Tool
  Generates and saves procedural sounds to .wav files
  Run this once to create actual sound files
]]

local SoundGenerator = require("src.core.sound_generator")

local function exportSounds()
    -- Create sounds directory if it doesn't exist
    love.filesystem.createDirectory("exported_sounds")
    
    print("Generating and exporting sounds...")
    
    -- Generate different laser sounds
    local laserShort = SoundGenerator.generateLaserZap(0.15, 400, 22050)
    local laserMedium = SoundGenerator.generateLaserZap(0.3, 800, 22050) 
    local laserLong = SoundGenerator.generateLaserZap(0.4, 1000, 22050)
    
    -- Generate impact sounds
    local shieldHit = SoundGenerator.generateShieldHit(0.15, 22050)
    local hullHit = SoundGenerator.generateHullHit(0.3, 22050)
    
    -- Generate explosion
    local explosion = SoundGenerator.generateExplosion(1.2, 22050)
    
    -- Generate missile launch
    local missile = SoundGenerator.generateMissileLaunch(0.8, 22050)
    
    -- Export as .wav files (Love2D can export SoundData as .wav)
    local sounds = {
        {"gun_fire.wav", laserShort},
        {"laser_fire.wav", laserMedium},
        {"laser_heavy.wav", laserLong},
        {"shield_hit.wav", shieldHit},
        {"hull_hit.wav", hullHit},
        {"explosion.wav", explosion},
        {"missile_launch.wav", missile}
    }
    
    for _, soundPair in ipairs(sounds) do
        local filename, soundData = soundPair[1], soundPair[2]
        local success = pcall(function()
            soundData:encode("wav", "exported_sounds/" .. filename)
        end)
        
        if success then
            print("Exported: " .. filename)
        else
            print("Failed to export: " .. filename)
        end
    end
    
    print("Sound export complete! Check the 'exported_sounds' folder.")
    print("Copy these files to 'content/sounds/sfx/' to use them in game.")
end

-- Run the export
exportSounds()