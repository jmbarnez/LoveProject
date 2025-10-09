local ScreenEffects = {}

function ScreenEffects.setup(Theme)
  Theme.screenEffects = {
    flash = { color = {1, 1, 1, 0}, duration = 0, timer = 0 },
    zoom = { scale = 1, duration = 0, timer = 0 },
  }

  function Theme.flashScreen(color, duration)
    Theme.screenEffects.flash.color = color or {1, 1, 1, 1}
    Theme.screenEffects.flash.duration = duration or 0.2
    Theme.screenEffects.flash.timer = 0
  end

  function Theme.zoomScreen(scale, duration)
    Theme.screenEffects.zoom.scale = scale or Theme.effects.zoomIntensity
    Theme.screenEffects.zoom.duration = duration or 0.1
    Theme.screenEffects.zoom.timer = 0
  end

  function Theme.updateScreenEffects(dt)
    if Theme.screenEffects.flash.timer < Theme.screenEffects.flash.duration then
      Theme.screenEffects.flash.timer = Theme.screenEffects.flash.timer + dt
      if Theme.screenEffects.flash.timer >= Theme.screenEffects.flash.duration then
        Theme.screenEffects.flash.color[4] = 0
      end
    end

    if Theme.screenEffects.zoom.timer < Theme.screenEffects.zoom.duration then
      Theme.screenEffects.zoom.timer = Theme.screenEffects.zoom.timer + dt
      if Theme.screenEffects.zoom.timer >= Theme.screenEffects.zoom.duration then
        Theme.screenEffects.zoom.scale = 1
      end
    end
  end

  function Theme.getScreenFlashAlpha()
    if Theme.screenEffects.flash.timer < Theme.screenEffects.flash.duration then
      local progress = Theme.screenEffects.flash.timer / Theme.screenEffects.flash.duration
      return (1 - progress) * Theme.screenEffects.flash.color[4]
    end
    return 0
  end

  function Theme.getScreenZoomScale()
    if Theme.screenEffects.zoom.timer < Theme.screenEffects.zoom.duration then
      local progress = Theme.screenEffects.zoom.timer / Theme.screenEffects.zoom.duration
      return 1 + (Theme.screenEffects.zoom.scale - 1) * progress
    end
    return 1
  end
end

return ScreenEffects
