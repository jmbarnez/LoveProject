local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Strings = require("src.core.strings")

local Notifications = {}

local notifications = {}
local maxNotifications = 5
local notificationLifetime = 5 -- seconds
local notificationFadeTime = 1 -- seconds

local lootKind = "loot"

local accentColors = {
  info = Theme.colors.textSecondary,
  action = Theme.colors.success,
  success = Theme.colors.success,
  debug = Theme.colors.info,
  loot = Theme.colors.accent,
  warning = Theme.colors.warning,
  error = Theme.colors.danger
}

local function normalizeLootItems(items)
  local normalized = {}
  for _, item in ipairs(items or {}) do
    local qty = tonumber(item.quantity or item.qty or item.count or 0) or 0
    if qty > 0 then
      table.insert(normalized, {
        label = item.label or item.name or item.id or item.key or "",
        quantity = qty,
        icon = item.icon
      })
    end
  end
  table.sort(normalized, function(a, b)
    return (a.label or "") < (b.label or "")
  end)
  return normalized
end

local function tryStackCount(notification)
  if not notification.text or #notifications == 0 then
    return false
  end

  local _, _, count, item = notification.text:find("^+?(%d+) (.+)")
  if not count or not item then
    return false
  end

  local lastNotif = notifications[1]
  if not lastNotif or not lastNotif.text then
    return false
  end

  local _, _, lastCount, lastItem = lastNotif.text:find("^+?(%d+) (.+)")
  if lastItem ~= item then
    return false
  end

  local newCount = (tonumber(lastCount) or 0) + (tonumber(count) or 0)
  lastNotif.text = "+" .. newCount .. " " .. item
  lastNotif.message = lastNotif.text
  lastNotif.time = love.timer.getTime()
  lastNotif.alpha = 1
  return true
end

local function mergeLoot(notification)
  if not notification.items or #notification.items == 0 or #notifications == 0 then
    return false
  end

  local lastNotif = notifications[1]
  if not lastNotif or not lastNotif.items then
    return false
  end

  if (notification.stackKey or lootKind) ~= (lastNotif.stackKey or lootKind) then
    return false
  end

  local index = {}
  for _, item in ipairs(lastNotif.items) do
    local key = (item.label or ""):lower()
    index[key] = item
  end

  for _, item in ipairs(notification.items) do
    local key = (item.label or ""):lower()
    if index[key] then
      index[key].quantity = (index[key].quantity or 0) + (item.quantity or 0)
    else
      local copy = {
        label = item.label,
        quantity = item.quantity,
        icon = item.icon
      }
      table.insert(lastNotif.items, copy)
      index[key] = copy
    end
  end

  table.sort(lastNotif.items, function(a, b)
    return (a.label or "") < (b.label or "")
  end)

  lastNotif.time = love.timer.getTime()
  lastNotif.alpha = 1
  return true
end

local function buildNotification(payload, kind)
  local notification = {
    kind = kind or "info",
    time = love.timer.getTime(),
    alpha = 1
  }

  if type(payload) == "table" then
    notification.kind = payload.kind or notification.kind
    notification.text = payload.text
    notification.title = payload.title
    notification.message = payload.message
    notification.items = normalizeLootItems(payload.items)
    notification.stackKey = payload.stackKey
  else
    notification.text = tostring(payload)
    notification.message = notification.text
  end

  if notification.kind == lootKind and (not notification.title or notification.title == "") then
    local lootTitle = Strings.getNotification and Strings.getNotification("items_collected") or "Items Collected"
    if lootTitle == "items_collected" then
      lootTitle = "Items Collected"
    end
    notification.title = lootTitle
  end

  return notification
end

function Notifications.add(text, kind)
  local notification = buildNotification(text, kind)

  if notification.items and #notification.items > 0 then
    notification.kind = notification.kind or lootKind
    notification.stackKey = notification.stackKey or lootKind
    if mergeLoot(notification) then
      return
    end
  elseif tryStackCount(notification) then
    return
  end

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

function Notifications.loot(items, opts)
  local normalized = normalizeLootItems(items)
  if #normalized == 0 then
    return
  end

  local payload = {
    kind = lootKind,
    title = opts and opts.title,
    message = opts and opts.message,
    items = normalized,
    stackKey = opts and opts.stackKey or lootKind
  }

  if not payload.title or payload.title == "" then
    local lootTitle = Strings.getNotification and Strings.getNotification("items_collected") or "Items Collected"
    if lootTitle == "items_collected" then
      lootTitle = "Items Collected"
    end
    payload.title = lootTitle
  end

  if opts and opts.text then
    payload.text = opts.text
  end

  Notifications.add(payload, lootKind)
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

local function getAccentColor(notif)
  return accentColors[notif.kind] or Theme.colors.text
end

local function measureNotification(notif, fonts, padding)
  local height = padding * 2
  local hasTitle = notif.title and notif.title ~= ""
  local hasMessage = notif.message and notif.message ~= "" and (not hasTitle or notif.message ~= notif.title)
  local hasItems = notif.items and #notif.items > 0

  if hasTitle then
    height = height + fonts.title:getHeight()
  end

  if hasMessage then
    if hasTitle then
      height = height + 6
    end
    height = height + fonts.body:getHeight()
  end

  if hasItems then
    if hasTitle or hasMessage then
      height = height + 6
    end
    height = height + (#notif.items * (fonts.item:getHeight() + 4))
  end

  if not hasTitle and not hasMessage and not hasItems and notif.text then
    height = height + fonts.body:getHeight()
  end

  return height
end

local function drawLootItems(notif, x, y, fonts, alpha)
  local itemFont = fonts.item
  love.graphics.setFont(itemFont)
  local lineHeight = itemFont:getHeight() + 4
  local textColor = Theme.withAlpha(Theme.colors.textSecondary, alpha)
  local bulletColor = Theme.withAlpha(Theme.colors.accent, alpha)

  for index, item in ipairs(notif.items) do
    local lineY = y + (index - 1) * lineHeight
    Theme.setColor(bulletColor)
    love.graphics.circle("fill", x + 4, lineY + itemFont:getHeight() * 0.5, 2)

    Theme.setColor(textColor)
    local label = item.label or ""
    local qty = item.quantity and (" x" .. tostring(item.quantity)) or ""
    love.graphics.print(label .. qty, x + 10, lineY)
  end
end

function Notifications.draw()
  local sw, sh = Viewport.getDimensions()
  local padding = 12
  local spacing = 8
  local cardWidth = math.min(360, sw * 0.35)
  local startX = 20
  local cursorY = sh - spacing

  local oldFont = love.graphics.getFont()
  local fonts = {
    title = Theme.fonts.medium,
    body = Theme.fonts.normal,
    item = Theme.fonts.small
  }

  for _, notif in ipairs(notifications) do
    local cardHeight = measureNotification(notif, fonts, padding)
    local cardY = cursorY - cardHeight
    cursorY = cardY - spacing

    local alpha = notif.alpha or 1
    local accent = Theme.withAlpha(getAccentColor(notif), alpha)
    local bgColor = Theme.withAlpha(Theme.colors.bg2, alpha * 0.9)
    local borderColor = Theme.withAlpha(getAccentColor(notif), alpha * 0.5)

    Theme.setColor(bgColor)
    love.graphics.rectangle("fill", startX, cardY, cardWidth, cardHeight, 6, 6)

    Theme.setColor(borderColor)
    love.graphics.rectangle("line", startX, cardY, cardWidth, cardHeight, 6, 6)

    Theme.setColor(accent)
    love.graphics.rectangle("fill", startX, cardY, 4, cardHeight, 6, 6)

    local textX = startX + padding + 4
    local textY = cardY + padding

    if notif.title and notif.title ~= "" then
      love.graphics.setFont(fonts.title)
      Theme.setColor(Theme.withAlpha(Theme.colors.text, alpha))
      love.graphics.print(notif.title, textX, textY)
      textY = textY + fonts.title:getHeight() + 6
    end

    local hasMessage = notif.message and notif.message ~= "" and (not notif.title or notif.message ~= notif.title)
    if hasMessage then
      love.graphics.setFont(fonts.body)
      Theme.setColor(Theme.withAlpha(Theme.colors.text, alpha))
      love.graphics.print(notif.message, textX, textY)
      textY = textY + fonts.body:getHeight() + 6
    elseif not notif.title and notif.text then
      love.graphics.setFont(fonts.body)
      Theme.setColor(Theme.withAlpha(Theme.colors.text, alpha))
      love.graphics.print(notif.text, textX, textY)
      textY = textY + fonts.body:getHeight() + 6
    end

    if notif.items and #notif.items > 0 then
      drawLootItems(notif, textX, textY, fonts, alpha)
    end
  end

  if oldFont then love.graphics.setFont(oldFont) end
end

return Notifications
