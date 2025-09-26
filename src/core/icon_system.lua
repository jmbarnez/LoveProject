-- Unified Icon System
-- Draws any definition-based icon via the declarative icon renderer

local Theme = require("src.core.theme")
local Content = require("src.content.content")
local IconRenderer = require("src.content.icon_renderer")

local IconSystem = {}

local function resolveById(id)
    if not id or type(id) ~= "string" or id == "" then return nil end
    return Content.getItem(id)
        or Content.getTurret(id)
        or Content.getShip(id)
        or Content.getWorldObject(id)
end

local function resolveDefinition(subject)
    if not subject then return nil end

    if type(subject) == "string" then
        return resolveById(subject)
    end

    local idCandidates = {
        subject.id,
        subject.baseId,
        subject.moduleId,
        subject.itemId,
        subject.turretId,
        subject.weaponId,
        subject.defId,
        subject.blueprintId,
    }

    for _, candidate in ipairs(idCandidates) do
        local canonical = resolveById(candidate)
        if canonical then return canonical end
    end

    local nestedCandidates = {
        subject.turret and subject.turret._sourceData,
        subject._sourceData,
        subject.def,
        subject.module,
        subject.moduleDef,
        subject.definition,
        subject.blueprint,
        subject.template,
        subject.source,
        subject.base,
    }

    for _, nested in ipairs(nestedCandidates) do
        local canonical = resolveDefinition(nested)
        if canonical then return canonical end
    end

    return subject
end

local function renderDeclarativeIcon(iconDef, id)
    if not iconDef or type(iconDef) ~= "table" then return nil end
    if not iconDef.shapes then return nil end
    local targetSize = iconDef.size or 128
    return IconRenderer.renderIcon(iconDef, targetSize, id)
end

local function ensureIcon(def)
    if not def then return nil end

    if def.icon and type(def.icon) == "userdata" then
        return def.icon
    end

    if def.iconImage and type(def.iconImage) == "userdata" then
        return def.iconImage
    end

    if def.icon and type(def.icon) == "table" and def.icon.shapes then
        def.iconDef = def.iconDef or def.icon
        def.icon = renderDeclarativeIcon(def.icon, def.id)
        return def.icon
    end

    if def.iconDef and type(def.iconDef) == "table" and def.iconDef.shapes then
        def.icon = renderDeclarativeIcon(def.iconDef, def.id)
        return def.icon
    end

    if def.iconImage and type(def.iconImage) == "table" and def.iconImage.type == "Image" then
        return def.iconImage
    end

    if def.iconPath then
        local image = Content.getImage(def.iconPath)
        if image then
            def.icon = image
            def.iconImage = image
            return def.iconImage
        end
    end

    if def.icon and type(def.icon) == "string" then
        local image = Content.getImage(def.icon)
        if image then
            def.icon = image
            def.iconImage = image
            return def.iconImage
        end
    end

    return nil
end

function IconSystem.getIcon(subject)
    local def = resolveDefinition(subject)
    local icon = ensureIcon(def)
    return icon, def
end

local function drawImage(icon, x, y, size, alpha)
    local oldColor = {love.graphics.getColor()}
    love.graphics.setColor(1, 1, 1, alpha)
    local iw, ih = icon:getWidth(), icon:getHeight()
    local scale = math.min(size / iw, size / ih)
    local drawW = iw * scale
    local drawH = ih * scale
    local dx = x + (size - drawW) * 0.5
    local dy = y + (size - drawH) * 0.5
    love.graphics.draw(icon, dx, dy, 0, scale, scale)
    love.graphics.setColor(oldColor)
end

local function drawPlaceholder(x, y, size, alpha)
    local oldColor = {love.graphics.getColor()}
    Theme.setColor(Theme.withAlpha(Theme.colors.bg2, alpha))
    love.graphics.rectangle('fill', x, y, size, size)
    Theme.setColor(Theme.withAlpha(Theme.colors.text, alpha))
    love.graphics.rectangle('line', x, y, size, size)
    love.graphics.setColor(oldColor)
end

function IconSystem.tryDrawIcon(subject, x, y, size, alpha)
    size = size or 64
    alpha = alpha or 1.0

    local icon = IconSystem.getIcon(subject)
    if icon then
        drawImage(icon, x, y, size, alpha)
        return true
    end

    return false
end

function IconSystem.drawIcon(subject, x, y, size, alpha)
    size = size or 64
    alpha = alpha or 1.0

    if type(subject) == "table" and subject[1] ~= nil and subject.id == nil then
        return IconSystem.drawIconAny(subject, x, y, size, alpha)
    end

    if IconSystem.tryDrawIcon(subject, x, y, size, alpha) then
        return true
    end

    drawPlaceholder(x, y, size, alpha)
    return false
end

local function normalizeSubjects(subjects, ...)
    if select("#", ...) > 0 then
        local list = {}
        list[#list + 1] = subjects
        for i = 1, select("#", ...) do
            list[#list + 1] = select(i, ...)
        end
        return list
    end

    if type(subjects) == "table" then
        if subjects[1] ~= nil and subjects.id == nil then
            return subjects
        end
        local list = {}
        for _, value in pairs(subjects) do
            list[#list + 1] = value
        end
        return list
    end

    return { subjects }
end

function IconSystem.drawIconAny(subjects, x, y, size, alpha, ...)
    size = size or 64
    alpha = alpha or 1.0

    local candidates = normalizeSubjects(subjects, ...)
    if type(candidates) == "table" and candidates[1] ~= nil then
        for _, candidate in ipairs(candidates) do
            if candidate ~= nil and IconSystem.tryDrawIcon(candidate, x, y, size, alpha) then
                return true
            end
        end
    else
        if IconSystem.tryDrawIcon(candidates, x, y, size, alpha) then
            return true
        end
    end

    drawPlaceholder(x, y, size, alpha)
    return false
end

function IconSystem.invalidateCache()
    for _, bucket in pairs(Content.byId) do
        for _, def in pairs(bucket) do
            if def.iconImage then
                def.iconImage = nil
            end
            if def.icon and type(def.icon) == "userdata" then
                -- keep existing userdata references
            elseif def.icon and type(def.icon) ~= "userdata" then
                def.icon = nil
            end
        end
    end
    if IconRenderer.clearCache then
        IconRenderer.clearCache()
    end
end

return IconSystem
