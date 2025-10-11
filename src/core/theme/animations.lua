local Animations = {}

function Animations.setup(Theme)
  Theme.animations = {
    active = {},
    nextId = 1,
  }

  function Theme.easeOut(t)
    return 1 - math.pow(1 - t, 3)
  end

  function Theme.easeIn(t)
    return t * t * t
  end

  function Theme.easeInOut(t)
    if t < 0.5 then
      return 4 * t * t * t
    else
      return 1 - math.pow(-2 * t + 2, 3) / 2
    end
  end

  function Theme.animateValue(start, target, duration, easing, callback)
    local id = Theme.animations.nextId
    Theme.animations.nextId = Theme.animations.nextId + 1

    local animation = {
      start = start,
      target = target,
      duration = duration,
      easing = easing or Theme.easeInOut,
      callback = callback,
      startTime = love.timer.getTime(),
      completed = false,
    }

    Theme.animations.active[id] = animation
    return id
  end

  function Theme.updateAnimations(dt)
    local currentTime = love.timer.getTime()

    for id, animation in pairs(Theme.animations.active) do
      local elapsed = currentTime - animation.startTime
      local progress = math.min(elapsed / animation.duration, 1)

      if progress >= 1 then
        if animation.callback then
          animation.callback(animation.target)
        end
        Theme.animations.active[id] = nil
      else
        local easedProgress = animation.easing(progress)
        local currentValue = animation.start + (animation.target - animation.start) * easedProgress

        if animation.callback then
          animation.callback(currentValue)
        end
      end
    end
  end
end

return Animations
