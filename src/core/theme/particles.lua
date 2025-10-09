local Particles = {}

function Particles.setup(Theme)
  Theme.particles = {
    active = {},
    nextId = 1,
  }

  function Theme.createParticle(x, y, color, velocityX, velocityY, size, lifetime)
    local id = Theme.particles.nextId
    Theme.particles.nextId = Theme.particles.nextId + 1

    local particle = {
      x = x,
      y = y,
      vx = velocityX or (math.random() * 2 - 1) * Theme.effects.particleSpeed.max,
      vy = velocityY or (math.random() * 2 - 1) * Theme.effects.particleSpeed.max,
      color = color or {1, 1, 1, 1},
      size = size or math.random(Theme.effects.particleSize.min, Theme.effects.particleSize.max),
      lifetime = lifetime or math.random(Theme.effects.particleLifetime.min, Theme.effects.particleLifetime.max),
      age = 0,
      active = true,
    }

    Theme.particles.active[id] = particle
    return id
  end

  function Theme.updateParticles(dt)
    for id, particle in pairs(Theme.particles.active) do
      particle.age = particle.age + dt
      if particle.age >= particle.lifetime then
        particle.active = false
        Theme.particles.active[id] = nil
      else
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt

        local fadeProgress = particle.age / particle.lifetime
        particle.color[4] = (1 - fadeProgress) * particle.color[4]
      end
    end
  end

  function Theme.drawParticles()
    for _, particle in pairs(Theme.particles.active) do
      Theme.setColor(particle.color)
      love.graphics.circle("fill", particle.x, particle.y, particle.size)
    end
  end
end

return Particles
