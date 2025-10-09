local Utilities = {}

function Utilities.setup(Theme)
  function Theme.setColor(color)
    if color then
      if type(color) == "table" and #color >= 3 then
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1.0)
      elseif type(color) == "table" and #color >= 1 then
        love.graphics.setColor(color[1], color[1], color[1], color[2] or 1.0)
      end
    end
  end

  function Theme.withAlpha(color, alpha)
    return {color[1], color[2], color[3], alpha}
  end

  function Theme.blend(color1, color2, factor)
    factor = math.max(0, math.min(1, factor))
    return {
      color1[1] + (color2[1] - color1[1]) * factor,
      color1[2] + (color2[2] - color1[2]) * factor,
      color1[3] + (color2[3] - color1[3]) * factor,
      (color1[4] or 1) + ((color2[4] or 1) - (color1[4] or 1)) * factor,
    }
  end

  function Theme.pulseColor(baseColor, pulseColor, time, speed)
    speed = speed or 2.0
    local intensity = (math.sin(time * speed) * 0.5 + 0.5)
    return Theme.blend(baseColor, pulseColor, intensity * 0.3)
  end

  function Theme.shimmerColor(baseColor, time, intensity)
    intensity = intensity or 0.2
    local shimmer = math.sin(time * 3) * intensity
    return {
      math.min(1, baseColor[1] + shimmer),
      math.min(1, baseColor[2] + shimmer),
      math.min(1, baseColor[3] + shimmer),
      baseColor[4] or 1,
    }
  end
end

return Utilities
