-- Post-Processing System
-- Manages bloom, motion blur, color grading, and other screen effects

local PostProcessing = {}
local Viewport = require("src.core.viewport")
local Theme = require("src.core.theme")

-- Post-processing settings
local settings = {
    bloom = {
        enabled = true,
        threshold = 0.8,
        intensity = 0.5,
        blurRadius = 2.0
    },
    motionBlur = {
        enabled = false,
        blurAmount = 0.1,
        velocity = {0, 0}
    },
    colorGrading = {
        enabled = true,
        contrast = 1.1,
        brightness = 0.05,
        saturation = 1.2,
        colorTint = {1.0, 0.95, 1.0}, -- Slight blue tint
        gamma = 1.0
    },
    vignette = {
        enabled = true,
        intensity = 0.3,
        radius = 0.8
    }
}

-- Shaders
local bloomShader = nil
local motionBlurShader = nil
local colorGradingShader = nil
local vignetteShader = nil

-- Render targets
local mainCanvas = nil
local bloomCanvas = nil
local tempCanvas = nil

-- Initialize post-processing system
function PostProcessing.init()
    -- Create vignette shader
    vignetteShader = love.graphics.newShader([[
        extern number intensity;
        extern number radius;
        
        vec4 effect(vec4 color, Image tex, vec2 texCoord, vec2 screenCoord)
        {
            vec2 center = vec2(0.5, 0.5);
            float dist = distance(texCoord, center);
            float vignette = 1.0 - smoothstep(radius, 1.0, dist) * intensity;
            return color * vignette;
        }
    ]])
    
    -- Create render targets
    local w, h = Viewport.getDimensions()
    mainCanvas = love.graphics.newCanvas(w, h)
    bloomCanvas = love.graphics.newCanvas(w, h)
    tempCanvas = love.graphics.newCanvas(w, h)
end

-- Get main canvas for rendering
function PostProcessing.getMainCanvas()
    return mainCanvas
end

-- Apply post-processing effects
function PostProcessing.apply(sourceCanvas)
    if not sourceCanvas then return end
    
    local w, h = Viewport.getDimensions()
    local processedCanvas = sourceCanvas
    
    -- Apply bloom
    if settings.bloom.enabled and bloomShader then
        love.graphics.setCanvas(bloomCanvas)
        love.graphics.clear()
        
        local ok, err = pcall(function()
            bloomShader:send("threshold", settings.bloom.threshold)
            bloomShader:send("intensity", settings.bloom.intensity)
            bloomShader:send("blurRadius", settings.bloom.blurRadius)
            bloomShader:send("screenSize", {w, h})
        end)
        
        if not ok then
            local Log = require("src.core.log")
            Log.warn("Bloom shader send error:", err)
            goto skip_bloom
        end
        
        love.graphics.setShader(bloomShader)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(processedCanvas, 0, 0)
        love.graphics.setShader()
        
        -- Combine bloom with original
        love.graphics.setCanvas(tempCanvas)
        love.graphics.clear()
        love.graphics.setBlendMode("alpha")
        love.graphics.draw(processedCanvas, 0, 0)
        love.graphics.setBlendMode("add")
        love.graphics.draw(bloomCanvas, 0, 0)
        love.graphics.setBlendMode("alpha")
        
        ::skip_bloom::
        processedCanvas = tempCanvas
    end
    
    -- Apply motion blur
    if settings.motionBlur.enabled and motionBlurShader then
        love.graphics.setCanvas(tempCanvas)
        love.graphics.clear()
        
        local ok, err = pcall(function()
            motionBlurShader:send("blurAmount", settings.motionBlur.blurAmount)
            motionBlurShader:send("velocity", {settings.motionBlur.velocity[1], settings.motionBlur.velocity[2]})
        end)
        
        if not ok then
            local Log = require("src.core.log")
            Log.warn("Motion blur shader send error:", err)
            goto skip_motion_blur
        end
        
        love.graphics.setShader(motionBlurShader)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(processedCanvas, 0, 0)
        love.graphics.setShader()
        
        ::skip_motion_blur::
        processedCanvas = tempCanvas
    end
    
    -- Apply color grading
    if settings.colorGrading.enabled and colorGradingShader then
        love.graphics.setCanvas(tempCanvas)
        love.graphics.clear()
        
        local ok, err = pcall(function()
            colorGradingShader:send("contrast", settings.colorGrading.contrast)
            colorGradingShader:send("brightness", settings.colorGrading.brightness)
            colorGradingShader:send("saturation", settings.colorGrading.saturation)
            colorGradingShader:send("gamma", settings.colorGrading.gamma)
            colorGradingShader:send("colorTint", {settings.colorGrading.colorTint[1], settings.colorGrading.colorTint[2], settings.colorGrading.colorTint[3]})
        end)
        
        if not ok then
            local Log = require("src.core.log")
            Log.warn("Color grading shader send error:", err)
            goto skip_color_grading
        end
        
        love.graphics.setShader(colorGradingShader)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(processedCanvas, 0, 0)
        love.graphics.setShader()
        
        ::skip_color_grading::
        processedCanvas = tempCanvas
    end
    
    -- Apply vignette
    if settings.vignette.enabled and vignetteShader then
        love.graphics.setCanvas(tempCanvas)
        love.graphics.clear()
        
        local ok, err = pcall(function()
            vignetteShader:send("intensity", settings.vignette.intensity)
            vignetteShader:send("radius", settings.vignette.radius)
        end)
        
        if not ok then
            local Log = require("src.core.log")
            Log.warn("Vignette shader send error:", err)
            goto skip_vignette
        end
        
        love.graphics.setShader(vignetteShader)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(processedCanvas, 0, 0)
        love.graphics.setShader()
        
        ::skip_vignette::
        processedCanvas = tempCanvas
    end
    
    -- Draw final result
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(processedCanvas, 0, 0)
end

-- Settings functions
function PostProcessing.setBloomEnabled(enabled)
    settings.bloom.enabled = enabled
end

function PostProcessing.updateBloomSettings(threshold, intensity, blurRadius)
    settings.bloom.threshold = threshold
    settings.bloom.intensity = intensity
    settings.bloom.blurRadius = blurRadius
end

function PostProcessing.setMotionBlurEnabled(enabled)
    settings.motionBlur.enabled = enabled
end

function PostProcessing.updateMotionBlurSettings(blurAmount, velocity)
    settings.motionBlur.blurAmount = blurAmount
    settings.motionBlur.velocity = velocity
end

function PostProcessing.setColorGradingEnabled(enabled)
    settings.colorGrading.enabled = enabled
end

function PostProcessing.updateColorGradingSettings(contrast, brightness, saturation, colorTint, gamma)
    settings.colorGrading.contrast = contrast
    settings.colorGrading.brightness = brightness
    settings.colorGrading.saturation = saturation
    settings.colorGrading.colorTint = colorTint
    settings.colorGrading.gamma = gamma
end

function PostProcessing.setVignetteEnabled(enabled)
    settings.vignette.enabled = enabled
end

function PostProcessing.updateVignetteSettings(intensity, radius)
    settings.vignette.intensity = intensity
    settings.vignette.radius = radius
end

-- Get settings
function PostProcessing.getSettings()
    return settings
end

return PostProcessing