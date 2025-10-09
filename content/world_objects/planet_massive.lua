-- Massive decorative planet world object
return {
  id = "planet_massive",
  name = "Hyperion",
  class = "WorldObject",

  -- Decorative renderer; no gameplay interaction
  renderable = {
    type = "planet",
    props = {
      visuals = {
        size = 2.0,
        radius = 1000, -- draw radius in pixels
        baseColor = {0.35, 0.35, 0.35, 1.0},  -- Gray like asteroids
        accentColor = {0.25, 0.25, 0.25, 1.0},  -- Darker gray accent
        atmosphere = false, -- Disable atmospheric glow rings around the planet
        atmosphereColor = {0.45, 0.85, 1.00, 0.18},
        highlightColor = {1.0, 0.95, 0.85, 0.10},
        lightDir = math.pi * 1.25, -- top-left
        -- Ring visuals
        ringInner = 1350,
        ringOuter = 1900,
        ringTilt = math.rad(28),
        ringFlatten = 0.32,
        ringColor = {0.45, 0.45, 0.45, 0.26},  -- Gray ring
        ringEdgeColor = {0.55, 0.55, 0.55, 0.38},  -- Lighter gray ring edge
        ringLayers = 12,
      }
    }
  },

  -- No collidable component for decorative planets (no physics collisions)
}
