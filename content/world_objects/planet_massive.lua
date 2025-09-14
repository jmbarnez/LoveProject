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
        baseColor = {0.18, 0.26, 0.38, 1.0},
        accentColor = {0.26, 0.34, 0.50, 1.0},
        atmosphere = false, -- Disable atmospheric glow rings around the planet
        atmosphereColor = {0.45, 0.85, 1.00, 0.18},
        highlightColor = {1.0, 0.95, 0.85, 0.10},
        lightDir = math.pi * 1.25, -- top-left
        -- Ring visuals
        ringInner = 1350,
        ringOuter = 1900,
        ringTilt = math.rad(28),
        ringFlatten = 0.32,
        ringColor = {0.80, 0.76, 0.68, 0.26},
        ringEdgeColor = {0.95, 0.92, 0.85, 0.38},
        ringLayers = 12,
      }
    }
  },

  -- Keep the collider tiny so it doesn't affect gameplay collisions
  collidable = {
    radius = 1,
  },
}
