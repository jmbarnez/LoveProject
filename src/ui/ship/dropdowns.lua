local Content = require("src.content.content")
local Dropdown = require("src.ui.common.dropdown")
local CargoUI = require("src.ui.cargo")
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
                            
                            -- Check if this is a turret with level restrictions
                            local turretLevel = 1
                            if def.level then
                                turretLevel = def.level
                            elseif entry.meta and entry.meta.level then
                                turretLevel = entry.meta.level
                            end
                            
                            local playerLevel = 1
                            if player.components and player.components.progression then
                                playerLevel = player.components.progression.level or 1
                            end
                            
                            local isLevelRestricted = turretLevel > playerLevel
                            
                            
                            if stackQty > 1 then
                                label = string.format("%s (x%d)", label, stackQty)
                            end
                            
                            if isLevelRestricted then
                                label = string.format("%s - Requires Level %d", label, turretLevel)
                            end
                            
                            table.insert(options, label)
                            actions[#options] = { 
                                kind = "equip", 
                                id = entry.id, 
                                turretData = entry.meta,
                                levelRestricted = isLevelRestricted
                            }
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
                -- Check if this is a level-restricted turret
                if action.levelRestricted then
                    local Notifications = require("src.ui.notifications")
                    if Notifications and Notifications.add then
                        local turretLevel = 1
                        if action.turretData and action.turretData.level then
                            turretLevel = action.turretData.level
                        end
                        Notifications.add("Cannot equip level " .. turretLevel .. " turret. You need to be level " .. turretLevel .. " or higher.", "warning")
                    end
                    -- Don't change the dropdown selection, keep it on the current selection
                    return false -- Don't equip the turret and don't update selection
                end
                local success = player:equipModule(slotIndex, action.id, action.turretData)
                if success and state.slotDropdowns[i] then
                    state.slotDropdowns[i]:setSelectedIndex(index)
                end
                return success
            elseif action.kind == "unequip" then
                local success = player:unequipModule(slotIndex)
                if success and state.slotDropdowns[i] then
                    state.slotDropdowns[i]:setSelectedIndex(index)
                end
                return success
            end
            
            -- Handle other actions (like "keep")
            if action.kind == "keep" then
                return true -- Allow selection to update for "keep" actions
            end

            if CargoUI and CargoUI.refresh then
                CargoUI.refresh()
            end

            Dropdowns.refresh(state, player)
            return true -- Default to allowing selection update
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
