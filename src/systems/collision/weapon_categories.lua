-- Weapon Category Configuration
-- This module defines how different weapon types are categorized for damage calculations

local WeaponCategories = {}

-- Weapon category definitions
WeaponCategories.CATEGORIES = {
    energy = {
        name = "Energy",
        description = "Laser and beam weapons",
        patterns = {"laser", "beam", "plasma", "ion"},
        shieldMultiplier = 1.15,  -- 15% more damage to shields
        hullMultiplier = 0.5      -- 50% damage to hulls
    },
    kinetic = {
        name = "Kinetic", 
        description = "Cannon, gun, and railgun weapons",
        patterns = {"cannon", "gun", "railgun", "gauss", "slug", "bullet"},
        shieldMultiplier = 0.5,   -- 50% damage to shields
        hullMultiplier = 1.15     -- 15% more damage to hulls
    },
    explosive = {
        name = "Explosive",
        description = "Missile and rocket weapons", 
        patterns = {"missile", "rocket", "bomb", "torpedo", "grenade"},
        shieldMultiplier = 1.0,   -- Normal damage to shields
        hullMultiplier = 1.25     -- 25% more damage to hulls
    },
    utility = {
        name = "Utility",
        description = "Mining, salvaging, and healing weapons",
        patterns = {"mining", "salvaging", "healing", "repair", "utility"},
        shieldMultiplier = 0.3,   -- 30% damage to shields
        hullMultiplier = 0.3      -- 30% damage to hulls
    }
}

-- Default category for unknown weapons
WeaponCategories.DEFAULT_CATEGORY = "kinetic"

-- Determine weapon category from weapon type string
function WeaponCategories.getCategory(weaponType)
    if not weaponType or weaponType == "unknown" then
        return WeaponCategories.DEFAULT_CATEGORY
    end
    
    local lowerType = string.lower(weaponType)
    
    for categoryName, categoryData in pairs(WeaponCategories.CATEGORIES) do
        for _, pattern in ipairs(categoryData.patterns) do
            if lowerType:find(pattern) then
                return categoryName
            end
        end
    end
    
    return WeaponCategories.DEFAULT_CATEGORY
end

-- Get category data
function WeaponCategories.getCategoryData(categoryName)
    return WeaponCategories.CATEGORIES[categoryName] or WeaponCategories.CATEGORIES[WeaponCategories.DEFAULT_CATEGORY]
end

-- Add a new weapon pattern to an existing category
function WeaponCategories.addPattern(categoryName, pattern)
    local category = WeaponCategories.CATEGORIES[categoryName]
    if category then
        table.insert(category.patterns, pattern)
        return true
    end
    return false
end

-- Create a new weapon category
function WeaponCategories.createCategory(name, description, patterns, shieldMultiplier, hullMultiplier)
    WeaponCategories.CATEGORIES[name] = {
        name = name,
        description = description,
        patterns = patterns or {},
        shieldMultiplier = shieldMultiplier or 1.0,
        hullMultiplier = hullMultiplier or 1.0
    }
end

return WeaponCategories
