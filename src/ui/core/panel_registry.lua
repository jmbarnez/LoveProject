local ModuleRegistry = require("src.core.module_registry")

local PANEL_TAG = "ui.panel"

local PanelRegistry = {}

local registrations = {}

local function ensureModule(record)
    if record.module then
        return record.module
    end

    if record.loader then
        local module = record.loader()
        record.module = module
        ModuleRegistry.set(record.registryName, module)
        return module
    end

    return nil
end

function PanelRegistry.register(options)
    assert(options and type(options.id) == "string" and options.id ~= "", "Panel registration requires an id")

    local registryName = options.registryName or ("ui.panel." .. options.id)

    if registrations[options.id] then
        local existing = registrations[options.id]

        if options.module then
            existing.module = options.module
            ModuleRegistry.set(existing.registryName, options.module, {
                tags = { PANEL_TAG },
                metadata = {
                    id = existing.id,
                    defaultZ = options.defaultZ or existing.defaultZ,
                    modal = options.modal == nil and existing.modal or options.modal,
                    captureTextInput = options.captureTextInput or existing.captureTextInput,
                },
            })
        end

        existing.defaultZ = options.defaultZ or existing.defaultZ
        if options.modal ~= nil then
            existing.modal = options.modal == true
        end

        existing.captureTextInput = options.captureTextInput or existing.captureTextInput
        existing.isVisible = options.isVisible or existing.isVisible
        existing.setVisible = options.setVisible or existing.setVisible
        existing.getRect = options.getRect or existing.getRect
        existing.draw = options.draw or existing.draw
        existing.update = options.update or existing.update
        existing.mousepressed = options.mousepressed or existing.mousepressed
        existing.mousereleased = options.mousereleased or existing.mousereleased
        existing.mousemoved = options.mousemoved or existing.mousemoved
        existing.wheelmoved = options.wheelmoved or existing.wheelmoved
        existing.keypressed = options.keypressed or existing.keypressed
        existing.keyreleased = options.keyreleased or existing.keyreleased
        existing.textinput = options.textinput or existing.textinput
        existing.useSelf = options.useSelf == nil and existing.useSelf or options.useSelf
        existing.onClose = options.onClose or existing.onClose
        existing.onOpen = options.onOpen or existing.onOpen

        return existing
    end

    local record = {
        id = options.id,
        loader = options.loader,
        module = options.module,
        registryName = registryName,
        defaultZ = options.defaultZ or 0,
        modal = options.modal == true,
        captureTextInput = options.captureTextInput,
        isVisible = options.isVisible,
        setVisible = options.setVisible,
        getRect = options.getRect,
        draw = options.draw,
        update = options.update,
        mousepressed = options.mousepressed,
        mousereleased = options.mousereleased,
        mousemoved = options.mousemoved,
        wheelmoved = options.wheelmoved,
        keypressed = options.keypressed,
        keyreleased = options.keyreleased,
        textinput = options.textinput,
        useSelf = options.useSelf == true,
        onClose = options.onClose,
        onOpen = options.onOpen,
    }

    registrations[options.id] = record

    ModuleRegistry.register(registryName, function()
        return ensureModule(record)
    end, {
        tags = { PANEL_TAG },
        metadata = {
            id = record.id,
            defaultZ = record.defaultZ,
            modal = record.modal,
            captureTextInput = record.captureTextInput,
        },
    })

    if record.module and options.metadata then
        ModuleRegistry.set(registryName, record.module, {
            tags = { PANEL_TAG },
            metadata = options.metadata,
        })
    end

    return record
end

function PanelRegistry.list()
    local entries = {}

    for id, record in pairs(registrations) do
        ensureModule(record)
        table.insert(entries, record)
    end

    table.sort(entries, function(a, b)
        local za = a.defaultZ or 0
        local zb = b.defaultZ or 0
        if za == zb then
            return a.id < b.id
        end
        return za < zb
    end)

    return entries
end

function PanelRegistry.get(id)
    local record = registrations[id]
    if not record then
        return nil
    end

    ensureModule(record)
    return record
end

function PanelRegistry.isRegistered(id)
    return registrations[id] ~= nil
end

function PanelRegistry.clear()
    for key in pairs(registrations) do
        registrations[key] = nil
    end
end

return PanelRegistry
