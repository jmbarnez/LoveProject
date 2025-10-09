local Drawing = {}

function Drawing.setup(Theme)
  function Theme.getButtonSize(size)
    size = size or "medium"
    local baseSize = Theme.buttonSizes[size] or Theme.buttonSizes.medium
    return {
      w = Theme.getScaledSize(baseSize.w),
      h = Theme.getScaledSize(baseSize.h),
    }
  end

  function Theme.drawButton(x, y, w, h, text, hover, t, options)
    options = options or {}
    local size = options.size or "medium"
    local color = options.color
    local down = options.down or false
    local font = options.font or "normal"
    local compact = options.compact or false
    local menuButton = options.menuButton or false

    if not w or not h then
      local buttonSize = Theme.getButtonSize(size)
      w = w or buttonSize.w
      h = h or buttonSize.h
    end

    w = Theme.getScaledSize(w)
    h = Theme.getScaledSize(h)

    local opts = {
      compact = compact,
      font = Theme.getFont(font),
      menuButton = menuButton,
    }

    Theme.drawStyledButton(x, y, w, h, text, hover, t, color, down, opts)

    return { x = x, y = y, w = w, h = h }
  end

  function Theme.drawMenuButton(x, y, w, h, text, hover, t, options)
    options = options or {}
    options.size = "menu"
    options.menuButton = true
    return Theme.drawButton(x, y, w, h, text, hover, t, options)
  end

  function Theme.drawCompactButton(x, y, w, h, text, hover, t, options)
    options = options or {}
    options.compact = true
    return Theme.drawButton(x, y, w, h, text, hover, t, options)
  end

  function Theme.drawStyledButton(x, y, w, h, text, hover, t, color, down, opts)
    if x == nil or y == nil or w == nil or h == nil then
      return
    end

    local t = t or love.timer.getTime()

    local baseColor = {0.1, 0.1, 0.1, 0.8}
    local borderColor = Theme.colors.accent
    local textColor = Theme.colors.text

    if color then
      baseColor = {color[1], color[2], color[3], 1.0}
      borderColor = {0, 0, 0, 1.0}
      textColor = {0, 0, 0, 1.0}
    end

    if hover then
      if color then
        baseColor = {color[1], color[2], color[3], 1.0}
        borderColor = {
          math.min(1.0, color[1] + 0.2),
          math.min(1.0, color[2] + 0.2),
          math.min(1.0, color[3] + 0.2),
          1.0,
        }
        textColor = {0, 0, 0, 1.0}
      else
        baseColor = {0.2, 0.2, 0.2, 0.9}
        borderColor = {
          math.min(1.0, borderColor[1] + 0.2),
          math.min(1.0, borderColor[2] + 0.2),
          math.min(1.0, borderColor[3] + 0.2),
          borderColor[4],
        }
        textColor = {
          math.min(1.0, textColor[1] + 0.1),
          math.min(1.0, textColor[2] + 0.1),
          math.min(1.0, textColor[3] + 0.1),
          textColor[4],
        }
      end

      if not color then
        local pulseOffset = math.sin(t * 8) * 0.1
        borderColor[4] = math.min(1.0, borderColor[4] + pulseOffset)
        textColor[4] = math.min(1.0, textColor[4] + pulseOffset)
      end

      local scale = 1.02
      local offsetX = (w * (scale - 1)) * 0.5
      local offsetY = (h * (scale - 1)) * 0.5
      x = x - offsetX
      y = y - offsetY
      w = w * scale
      h = h * scale
    end

    if down then
      baseColor = {
        baseColor[1] * 0.5,
        baseColor[2] * 0.5,
        baseColor[3] * 0.5,
        math.min(1.0, baseColor[4] * 1.2),
      }
      x = x + 1
      y = y + 1
    end

    Theme.setColor(baseColor)
    love.graphics.rectangle("fill", x, y, w, h)

    Theme.setColor(borderColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)

    local highlightColor = {
      math.min(1.0, borderColor[1] + 0.3),
      math.min(1.0, borderColor[2] + 0.3),
      math.min(1.0, borderColor[3] + 0.3),
      borderColor[4] * 0.5,
    }
    Theme.setColor(highlightColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 1, y + 1, w - 2, h - 2)

    local padX = 12
    local maxTextW = math.max(10, w - padX * 2)
    local fixedFont = opts and opts.font
    if fixedFont then
      local oldFont = love.graphics.getFont()
      love.graphics.setFont(fixedFont)
      local tw = fixedFont:getWidth(text or "")
      local th = fixedFont:getHeight()

      Theme.setColor(textColor)
      local textX = math.floor(x + (w - tw) * 0.5 + 0.5)
      local textY = math.floor(y + (h - th) * 0.5 + 0.5)
      love.graphics.print(text, textX, textY)
      if oldFont then love.graphics.setFont(oldFont) end
      return
    end

    local buttonFont = nil
    if opts and opts.menuButton then
      buttonFont = Theme.fonts and Theme.fonts.normal
    elseif opts and opts.compact then
      buttonFont = Theme.fonts and Theme.fonts.small
    end

    if not buttonFont then
      local candidates = {
        Theme.fonts and Theme.fonts.large,
        Theme.fonts and Theme.fonts.medium,
        Theme.fonts and Theme.fonts.normal,
        Theme.fonts and Theme.fonts.small,
        Theme.fonts and Theme.fonts.xsmall,
        love.graphics.getFont(),
      }

      if opts and opts.compact then
        candidates = {
          Theme.fonts and Theme.fonts.normal,
          Theme.fonts and Theme.fonts.small,
          Theme.fonts and Theme.fonts.xsmall,
          love.graphics.getFont(),
        }
      end

      local bestFont = nil
      for _, f in ipairs(candidates) do
        if f then
          local tw = f:getWidth(text or "")
          local fh = f:getHeight()
          if tw <= maxTextW and fh <= h - 6 then
            bestFont = f
            break
          end
        end
      end
      if not bestFont then
        for i = #candidates, 1, -1 do
          if candidates[i] then
            bestFont = candidates[i]
            break
          end
        end
      end
      buttonFont = bestFont
    end

    if not buttonFont then
      buttonFont = love.graphics.getFont() or Theme.fonts.normal or Theme.fonts.small
    end

    local oldFont = love.graphics.getFont()
    love.graphics.setFont(buttonFont)
    local tw = buttonFont:getWidth(text or "")
    local th = buttonFont:getHeight()
    local textX = math.floor(x + (w - tw) * 0.5 + 0.5)
    local textY = math.floor(y + (h - th) * 0.5 + 0.5)

    Theme.setColor(textColor)
    love.graphics.print(text, textX, textY)

    if oldFont then love.graphics.setFont(oldFont) end
  end

  function Theme.drawTextFit(text, x, y, maxWidth, align, baseFont, minScale, maxScale)
    align = align or 'left'
    baseFont = baseFont or (Theme.fonts and Theme.fonts.normal) or love.graphics.getFont()
    minScale = minScale or 0.75
    maxScale = maxScale or 1.5

    local oldFont = love.graphics.getFont()
    love.graphics.setFont(baseFont)
    local font = baseFont
    local textW = math.max(1, font:getWidth(text))
    local scale = math.max(minScale, math.min(maxScale, maxWidth / textW))

    local drawX = x
    if align == 'center' then
      drawX = x + (maxWidth - textW * scale) * 0.5
    elseif align == 'right' then
      drawX = x + (maxWidth - textW * scale)
    end

    love.graphics.push()
    love.graphics.translate(math.floor(drawX + 0.5), math.floor(y + 0.5))
    love.graphics.scale(scale, scale)
    love.graphics.print(text, 0, 0)
    love.graphics.pop()

    if oldFont then love.graphics.setFont(oldFont) end
    return scale
  end

  function Theme.drawVerticalGradient(x, y, w, h, topColor, bottomColor, steps)
    steps = steps or 20
    local r1, g1, b1, a1 = topColor[1], topColor[2], topColor[3], topColor[4] or 1
    local r2, g2, b2, a2 = bottomColor[1], bottomColor[2], bottomColor[3], bottomColor[4] or 1
    local dr, dg, db, da = (r2 - r1) / steps, (g2 - g1) / steps, (b2 - b1) / steps, (a2 - a1) / steps
    local stepH = h / steps
    for i = 0, steps - 1 do
      love.graphics.setColor(r1 + dr * i, g1 + dg * i, b1 + db * i, a1 + da * i)
      love.graphics.rectangle("fill", x, y + i * stepH, w, stepH + 1)
    end
  end

  function Theme.drawHorizontalGradient(x, y, w, h, leftColor, rightColor, steps)
    Theme.setColor(leftColor)
    love.graphics.rectangle("fill", x, y, w, h)
  end

  function Theme.drawCloseButton(rect, hover)
    local oldFont = love.graphics.getFont()
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or oldFont)
    Theme.setColor(hover and Theme.colors.danger or Theme.colors.textSecondary)
    local font = love.graphics.getFont()
    local textWidth = font:getWidth("×")
    local textHeight = font:getHeight()
    love.graphics.print("×",
      math.floor(rect.x + (rect.w - textWidth) / 2 + 0.5),
      math.floor(rect.y + (rect.h - textHeight) / 2 + 0.5))
    if oldFont then love.graphics.setFont(oldFont) end
  end

  function Theme.drawMaximizeButton(rect, hover, maximized)
    Theme.setColor(hover and Theme.colors.accent or Theme.colors.textSecondary)

    local centerX = rect.x + rect.w * 0.5
    local centerY = rect.y + rect.h * 0.5
    local size = math.min(rect.w, rect.h) * 0.4

    if maximized then
      love.graphics.setLineWidth(1.5)
      love.graphics.rectangle("line", centerX - size * 0.6, centerY - size * 0.6, size * 0.8, size * 0.8)
      love.graphics.rectangle("line", centerX - size * 0.2, centerY - size * 0.2, size * 0.8, size * 0.8)
    else
      love.graphics.setLineWidth(1.5)
      love.graphics.rectangle("line", centerX - size * 0.5, centerY - size * 0.5, size, size)
    end
  end

  function Theme.drawGradientGlowRect(x, y, w, h, radius, topColor, bottomColor, glowColor, glowIntensity, drawBorder)
    if x == nil or y == nil or w == nil or h == nil then
      return
    end

    if glowIntensity and glowIntensity > 0 then
      Theme.setColor(Theme.withAlpha(Theme.colors.shadow, glowIntensity * 0.4))
      love.graphics.rectangle("fill", math.floor(x + 1.5), math.floor(y + 1.5), w, h)
    end

    Theme.setColor(topColor)
    love.graphics.rectangle("fill", math.floor(x + 0.5), math.floor(y + 0.5), w, h)

    if drawBorder ~= false then
      Theme.setColor(Theme.colors.border)
      love.graphics.setLineWidth(1)
      love.graphics.rectangle("line", math.floor(x + 0.5), math.floor(y + 0.5), w, h)
    end
  end

  function Theme.drawEVEBorder(x, y, w, h, radius, borderColor, cornerSize)
    if x == nil or y == nil or w == nil or h == nil then
      return
    end

    Theme.setColor(borderColor)
    love.graphics.setLineWidth(1)

    x, y, w, h = math.floor(x + 0.5), math.floor(y + 0.5), w, h

    love.graphics.rectangle("line", x, y, w, h)
  end

  function Theme.drawDesignToken(x, y, size)
    local radius = size / 2
    local centerX = x + radius
    local centerY = y + radius

    Theme.setColor({0.6, 0.7, 1.0, 1.00})
    love.graphics.circle("fill", centerX, centerY, radius)
    Theme.setColor(Theme.colors.border)
    love.graphics.circle("line", centerX, centerY, radius)
    local oldFont = love.graphics.getFont()
    love.graphics.setFont(Theme.fonts and Theme.fonts.xsmall or oldFont)
    Theme.setColor(Theme.colors.bg0)
    local coinFont = love.graphics.getFont()
    love.graphics.print("C", math.floor(centerX - coinFont:getWidth("C") * 0.5 + 0.5), math.floor(centerY - coinFont:getHeight() * 0.5 + 0.5))
    if oldFont then love.graphics.setFont(oldFont) end
  end

  function Theme.drawCurrencyToken(x, y, size)
    Theme.drawDesignToken(x, y, size)
  end

  function Theme.drawXPIcon(x, y, size)
    local radius = size / 2
    local centerX = x + radius
    local centerY = y + radius

    Theme.setColor({0.7, 0.5, 0.9, 1.00})
    love.graphics.circle("fill", centerX, centerY, radius)
    Theme.setColor(Theme.colors.border)
    love.graphics.circle("line", centerX, centerY, radius)
    local oldFont = love.graphics.getFont()
    love.graphics.setFont(Theme.fonts and Theme.fonts.xsmall or oldFont)
    Theme.setColor(Theme.colors.text)
    local xpFont = love.graphics.getFont()
    love.graphics.print("XP", math.floor(centerX - xpFont:getWidth("XP") * 0.5 + 0.5), math.floor(centerY - xpFont:getHeight() * 0.5 + 0.5))
    if oldFont then love.graphics.setFont(oldFont) end
  end

  function Theme.drawEVEProgressBar(x, y, w, h, progress, bgColor, fillColor, glowColor, time)
    progress = math.max(0, math.min(1, progress))

    Theme.setColor(Theme.withAlpha(Theme.colors.shadow, 0.2))
    love.graphics.rectangle("fill", x + 1, y + 1, w, h)

    Theme.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h)

    if progress > 0 then
      local fillW = math.floor((w - 4) * progress)
      Theme.setColor(fillColor)
      love.graphics.rectangle("fill", x + 2, y + 2, fillW, h - 4)

      if fillW > 4 then
        Theme.setColor(Theme.withAlpha(Theme.colors.highlight, 0.3))
        love.graphics.rectangle("fill", x + 3, y + 3, math.min(fillW - 4, fillW), 2)
      end
    end

    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle("line", x, y, w, h)
  end

  function Theme.drawModernBar(x, y, w, h, progress, color)
    progress = math.max(0, math.min(1, progress))

    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", math.floor(x + 0.5), math.floor(y + 0.5), w, h)

    local innerW = w - 2
    local fillW = math.floor(innerW * progress)

    if fillW > 0 then
      local gx, gy, gw, gh = math.floor(x + 1.5), math.floor(y + 1.5), fillW, h - 2
      Theme.setColor(color)
      love.graphics.rectangle("fill", gx, gy, gw, gh)

      Theme.setColor(Theme.withAlpha(Theme.colors.highlight, 0.6))
      love.graphics.rectangle("fill", gx, gy, gw, 1)
    end

    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", math.floor(x + 0.5), math.floor(y + 0.5), w, h)
  end

  function Theme.drawSciFiBar(x, y, w, h, progress, color)
    progress = math.max(0, math.min(1, progress))
    local cut = h / 2

    local bgShape = {
      x, y + cut,
      x + cut, y,
      x + w, y,
      x + w, y + h - cut,
      x + w - cut, y + h,
      x, y + h,
    }

    Theme.setColor(Theme.colors.bg1)
    love.graphics.polygon("fill", bgShape)

    Theme.setColor(Theme.withAlpha(Theme.colors.bg0, 0.5))
    love.graphics.polygon("fill", bgShape)

    if progress > 0 then
      local fillW = math.floor(w * progress)
      local fillShape = {}

      if fillW >= w then
        fillShape = bgShape
      else
        if fillW <= cut then
          fillShape = {
            x, y + cut,
            x + cut, y,
            x + fillW, y,
            x + fillW, y + (cut - fillW),
            x, y + cut,
          }
        elseif fillW > cut and fillW <= w - cut then
          fillShape = {
            x, y + cut,
            x + cut, y,
            x + fillW, y,
            x + fillW, y + h,
            x, y + h,
          }
        else
          local cutProgress = math.min(fillW - (w - cut), cut)
          fillShape = {
            x, y + cut,
            x + cut, y,
            x + w, y,
            x + w, y + h - cut,
            x + w - cut, y + h,
            x + cutProgress, y + h,
            x, y + h,
          }
        end
      end

      Theme.setColor(color)
      love.graphics.polygon("fill", fillShape)

      Theme.setColor(Theme.withAlpha(color, 0.2))
      love.graphics.polygon("fill", fillShape)
    end

    Theme.setColor(Theme.colors.border)
    love.graphics.polygon("line", bgShape)
  end

  function Theme.drawSimpleBar(x, y, w, h, progress, color)
    progress = math.max(0, math.min(1, progress))

    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", math.floor(x + 0.5), math.floor(y + 0.5), w, h)

    if progress > 0 then
      local fillW = math.floor((w - 2) * progress)
      Theme.setColor(color)
      love.graphics.rectangle("fill", math.floor(x + 1.5), math.floor(y + 1.5), fillW, h - 2)
    end

    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", math.floor(x + 0.5), math.floor(y + 0.5), w, h)
  end

  function Theme.drawSciFiFrame(x, y, w, h)
    local border = Theme.colors.border

    Theme.setColor(border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
  end
end

return Drawing
