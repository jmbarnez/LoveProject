local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")

local Notifications = {}

local notifications = {}
local maxNotifications = 5
local notificationLifetime = 5 -- seconds
local notificationFadeTime = 1 -- seconds

function Notifications.add(text, kind)
  -- Stacking logic
  local _, _, count, item = text:find("^+?(%d+) (.+)")
  if count and item and #notifications > 0 then
    local lastNotif = notifications[1]
    local _, _, lastCount, lastItem = lastNotif.text:find("^+?(%d+) (.+)")
    if lastItem == item then
      local newCount = (tonumber(lastCount) or 0) + (tonumber(count) or 0)
      lastNotif.text = "+" .. newCount .. " " .. item
      lastNotif.time = love.timer.getTime()
      lastNotif.alpha = 1
      return
    end
  end

  local notification = {
    text = text,
    kind = kind or "info",
    time = love.timer.getTime(),
    alpha = 1
  }
  table.insert(notifications, 1, notification)
  if #notifications > maxNotifications then
    table.remove(notifications, maxNotifications + 1)
  end
end

function Notifications.info(text)
  Notifications.add(text, "info")
end

function Notifications.action(text)
  Notifications.add(text, "action")
end

function Notifications.debug(text)
  -- In the new system, debug messages can be handled differently,
  -- for now, we can just log them or display them as info.
  Notifications.add(text, "debug")
end

function Notifications.update(dt)
  local currentTime = love.timer.getTime()
  for i = #notifications, 1, -1 do
    local notif = notifications[i]
    local age = currentTime - notif.time
    if age > notificationLifetime then
      table.remove(notifications, i)
    elseif age > notificationLifetime - notificationFadeTime then
      notif.alpha = 1 - (age - (notificationLifetime - notificationFadeTime)) / notificationFadeTime
    end
  end
end

function Notifications.draw()
  local sw, sh = Viewport.getDimensions()
  local startX = 10
  local startY = sh - 30
  local lineHeight = 20

  local oldFont = love.graphics.getFont()
  love.graphics.setFont(Theme.fonts.medium)

  for i, notif in ipairs(notifications) do
    local y = startY - (i - 1) * lineHeight
    local color
    if notif.kind == "action" then
      color = Theme.colors.success
    elseif notif.kind == "debug" then
      color = Theme.colors.info
    else
      color = Theme.colors.text
    end

    color = Theme.withAlpha(color, notif.alpha)
    Theme.setColor(color)
    love.graphics.print(notif.text, startX, y)
  end
  if oldFont then love.graphics.setFont(oldFont) end
end

return Notifications
