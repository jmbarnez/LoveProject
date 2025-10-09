local Content = require("src.content.content")
local Dropdown = require("src.ui.common.dropdown")
local InventoryUI = require("src.ui.inventory")
local ShipUtils = require("src.ui.ship.utils")

local Dropdowns = {}

function Dropdowns.refresh(state, player)
    if not player then return end
    local equipment = player.components and player.components.equipment
    if not equipment or not equipment.grid then return end

    state.slotDropdowns = state.slotDropdowns or {}
    state.removeButtons = state.removeButtons or {}
    state.hotbarButtons = state.hotbarButtons or {}

    for i, slotData in ipairs(equipment.grid) do
        local slotIndex = i
        local options = {}
        local actions = {}

        local fittedName = nil
        if slotData and slotData.module then
            if slotData.type == "turret" then
                local baseId = (slotData.module and (slotData.module.baseId or slotData.module.id)) or slotData.id
                local tdef = baseId and Content.getTurret(baseId) or nil
                fittedName = (tdef and tdef.name) or ShipUtils.resolveModuleDisplayName(slotData.module) or baseId or "Fitted"
            else
                local mod = slotData.module
                local idef = (slotData.id and Content.getItem(slotData.id)) or nil
                fittedName = (mod and mod.name) or (idef and idef.name) or slotData.id or "Fitted"
            end
        end

        if fittedName then
            table.insert(options, fittedName)
            actions[#options] = { kind = "keep" }
        else
            table.insert(options, "None")
            actions[#options] = { kind = "keep" }
        end

        if player.components and player.components.cargo then
            player:iterCargo(function(_, entry)
                local stackQty = entry.qty or 0
                if stackQty > 0 then
                    local itemDef = Content.getItem(entry.id)
                    local turretDef = Content.getTurret(entry.id)
                    local def = itemDef or turretDef
                    if def then
                        local allowed = false
                        local slotType = ShipUtils.resolveSlotType(slotData)
                        if slotType == "turret" then
                            allowed = turretDef ~= nil
                        elseif slotType == "shield" then
                            if itemDef and itemDef.module and itemDef.module.type == "shield" then
                                allowed = true
                            elseif turretDef and turretDef.module and turretDef.module.type == "shield" then
                                allowed = true
                            end
                        else
                            if itemDef and itemDef.module then
                                allowed = true
                            elseif turretDef and turretDef.module then
                                allowed = true
                            end
                        end

                        if allowed then
                            local label = def.name or tostring(entry.id)
                            if stackQty > 1 then
                                label = string.format("%s (x%d)", label, stackQty)
                            end
                            table.insert(options, label)
                            actions[#options] = { kind = "equip", id = entry.id }
                        end
                    end
                end
            end)
        end

        local selectedIndex = 1

        local function handleSelection(index)
            local action = actions[index]
            if not action then return end

            if action.kind == "equip" then
                player:equipModule(slotIndex, action.id, action.turretData)
            elseif action.kind == "unequip" then
                player:unequipModule(slotIndex)
            end

            if state.slotDropdowns[i] then
                state.slotDropdowns[i]:setSelectedIndex(index)
            end

            if InventoryUI and InventoryUI.refresh then
                InventoryUI.refresh()
            end

            Dropdowns.refresh(state, player)
        end

        if not state.slotDropdowns[i] then
            state.slotDropdowns[i] = Dropdown.new({
                options = options,
                selectedIndex = selectedIndex,
                width = 200,
                optionHeight = 24,
                onSelect = handleSelection
            })
        else
            state.slotDropdowns[i]:setOptions(options)
            state.slotDropdowns[i].onSelect = handleSelection
            state.slotDropdowns[i]:setSelectedIndex(selectedIndex)
        end

        state.slotDropdowns[i]._actions = actions
        state.removeButtons[i] = state.removeButtons[i] or { hover = false }
        state.hotbarButtons[i] = state.hotbarButtons[i] or {}
        local hotbarValue = slotData and slotData.hotbarSlot or 0
        state.hotbarButtons[i].value = hotbarValue or 0
        local baseSlotType = ShipUtils.resolveSlotType(slotData)
        state.hotbarButtons[i].enabled = baseSlotType == "turret" and slotData and slotData.module
        state.hotbarButtons[i].rect = nil
    end
end

return Dropdowns
