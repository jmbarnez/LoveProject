-- Renderer Type Registry
-- Data-driven system for determining entity renderer types based on entity properties
-- Replaces the complex if-elseif chain in entity_renderer_dispatcher.lua
--
-- USAGE:
--   local rendererType = RendererTypeRegistry.getTypeForEntity(entity)
--
-- EXTENDING:
--   -- Add a custom renderer type
--   RendererTypeRegistry.register(
--       function(entity) return entity.isMyCustomEntity end,
--       "my_custom_renderer",
--       10  -- priority (lower = higher priority)
--   )
--
-- DEBUGGING:
--   RendererTypeRegistry.debugEntity(entity)  -- prints detailed debug info

local RendererTypeRegistry = {}

-- Registry table with priority-ordered checks (first match wins)
-- Each entry contains:
--   check: function(entity) -> boolean (returns true if this entity matches this type)
--   type: string (the renderer type name)
--   priority: number (lower numbers = higher priority, optional, defaults to order in array)
local registry = {
    -- High priority checks (specific entity flags)
    {
        check = function(entity)
            return entity.isRemotePlayer == true
        end,
        type = "remote_player",
        priority = 1
    },
    
    -- Component-based checks
    {
        check = function(entity)
            return entity.components and entity.components.warp_gate ~= nil
        end,
        type = "warp_gate",
        priority = 2
    },
    
    {
        check = function(entity)
            return entity.components and entity.components.mineable ~= nil
        end,
        type = "asteroid",
        priority = 3
    },
    
    {
        check = function(entity)
            return entity.isItemPickup == true or (entity.components and entity.components.item_pickup ~= nil)
        end,
        type = "item_pickup",
        priority = 4
    },
    
    {
        check = function(entity)
            return entity.components and entity.components.xp_pickup ~= nil
        end,
        type = "xp_pickup",
        priority = 5
    },
    
    {
        check = function(entity)
            return entity.components and entity.components.wreckage ~= nil
        end,
        type = "wreckage",
        priority = 6
    },
    
    {
        check = function(entity)
            return entity.components and entity.components.lootable ~= nil and entity.isWreckage == true
        end,
        type = "wreckage",
        priority = 7
    },
    
    -- Projectile checks (with special wave projectile handling)
    {
        check = function(entity)
            if entity.components and entity.components.projectile then
                local renderable = entity.components.renderable
                return renderable and renderable.type == "wave"
            end
            return false
        end,
        type = "wave",
        priority = 8
    },
    
    {
        check = function(entity)
            return entity.components and entity.components.projectile ~= nil
        end,
        type = "bullet",
        priority = 9
    },
    
    -- Entity type and tag checks
    {
        check = function(entity)
            return entity.isStation == true
        end,
        type = "station",
        priority = 10
    },
    
    {
        check = function(entity)
            return entity.isTurret == true or entity.type == "stationary_turret" or entity.aiType == "turret"
        end,
        type = "stationary_turret",
        priority = 11
    },
    
    {
        check = function(entity)
            return entity.type == "world_object" and entity.subtype == "planet_massive"
        end,
        type = "planet",
        priority = 12
    },
    
    {
        check = function(entity)
            return entity.type == "world_object" and entity.subtype == "reward_crate"
        end,
        type = "reward_crate",
        priority = 13
    },
    
    {
        check = function(entity)
            if not (entity and entity.components) then
                return false
            end

            -- Live enemies often carry loot definitions; keep rendering them as ships until they are gone.
            if entity.components.ai and not entity.dead then
                return false
            end

            return entity.components.lootable ~= nil
        end,
        type = "lootContainer",
        priority = 14
    },
    
    -- AI component check (enemy) - lower priority to catch remaining entities
    {
        check = function(entity)
            return entity.components and entity.components.ai ~= nil
        end,
        type = "enemy",
        priority = 15
    }
}

-- Sort registry by priority to ensure correct order
table.sort(registry, function(a, b)
    return (a.priority or 999) < (b.priority or 999)
end)

-- Get the renderer type for an entity
function RendererTypeRegistry.getTypeForEntity(entity)
    if not entity then
        return "fallback"
    end
    
    -- Check each registry entry in priority order
    for _, entry in ipairs(registry) do
        if entry.check(entity) then
            return entry.type
        end
    end
    
    -- Fallback if no matches found
    return "fallback"
end

-- Register a new renderer type check
-- checkFunction: function(entity) -> boolean
-- rendererType: string (the renderer type name)
-- priority: number (optional, defaults to 100)
function RendererTypeRegistry.register(checkFunction, rendererType, priority)
    if type(checkFunction) ~= "function" then
        error("RendererTypeRegistry.register: checkFunction must be a function")
    end
    
    if type(rendererType) ~= "string" or rendererType == "" then
        error("RendererTypeRegistry.register: rendererType must be a non-empty string")
    end
    
    priority = priority or 100
    
    -- Add to registry
    table.insert(registry, {
        check = checkFunction,
        type = rendererType,
        priority = priority
    })
    
    -- Re-sort by priority
    table.sort(registry, function(a, b)
        return (a.priority or 999) < (b.priority or 999)
    end)
end

-- Get all registered renderer types (for debugging/inspection)
function RendererTypeRegistry.getRegisteredTypes()
    local types = {}
    for _, entry in ipairs(registry) do
        table.insert(types, {
            type = entry.type,
            priority = entry.priority or 999
        })
    end
    return types
end

-- Clear all custom registrations (reset to defaults)
function RendererTypeRegistry.clearCustomRegistrations()
    -- Keep only the first 15 entries (the default ones)
    while #registry > 15 do
        table.remove(registry)
    end
    
    -- Re-sort
    table.sort(registry, function(a, b)
        return (a.priority or 999) < (b.priority or 999)
    end)
end

-- Debug function to test entity against all checks
function RendererTypeRegistry.debugEntity(entity)
    print("=== Entity Renderer Type Debug ===")
    print("Entity properties:")
    print("  isRemotePlayer:", entity.isRemotePlayer)
    print("  isItemPickup:", entity.isItemPickup)
    print("  isStation:", entity.isStation)
    print("  isTurret:", entity.isTurret)
    print("  isWreckage:", entity.isWreckage)
    print("  type:", entity.type)
    print("  subtype:", entity.subtype)
    print("  aiType:", entity.aiType)
    print("  components:")
    if entity.components then
        for name, _ in pairs(entity.components) do
            print("    " .. name .. ": true")
        end
    end
    
    print("\nRegistry checks (in priority order):")
    for i, entry in ipairs(registry) do
        local matches = entry.check(entity)
        print(string.format("  %d. %s (priority %d): %s", 
            i, entry.type, entry.priority or 999, matches and "MATCH" or "no match"))
    end
    
    local result = RendererTypeRegistry.getTypeForEntity(entity)
    print("\nFinal result:", result)
    print("================================")
    
    return result
end

return RendererTypeRegistry
