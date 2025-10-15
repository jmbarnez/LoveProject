--[[
    Projectile Categories
    
    Defines projectile categories and their properties.
    Replaces generic "bullet" terminology with proper categorization.
    
    SINGLE RESPONSIBILITY: Projectile categorization and classification
    MODULAR: Centralized category management
]]

local ProjectileCategories = {}

-- Projectile category definitions
ProjectileCategories.CATEGORIES = {
    kinetic = {
        name = "Kinetic",
        description = "Physical projectiles with mass and momentum",
        collisionClass = "kinetic_projectile",
        physics = {
            restitution = 0.0,
            friction = 0.0,
            fixedRotation = true,
            bodyType = "kinematic"
        },
        types = {"bullet", "slug", "cannonball", "railgun_slug"}
    },
    explosive = {
        name = "Explosive", 
        description = "Missiles and rockets with explosive payloads",
        collisionClass = "explosive_projectile",
        physics = {
            restitution = 0.0,
            friction = 0.0,
            fixedRotation = true, -- Keep missiles from tumbling for now
            bodyType = "kinematic"
        },
        types = {"missile", "rocket", "torpedo", "bomb"}
    },
    energy = {
        name = "Energy",
        description = "Energy-based projectiles and beams",
        collisionClass = "energy_projectile", 
        physics = {
            restitution = 0.0,
            friction = 0.0,
            fixedRotation = true,
            bodyType = "kinematic"
        },
        types = {"laser", "plasma", "ion", "beam"}
    },
    utility = {
        name = "Utility",
        description = "Mining, salvaging, and healing projectiles",
        collisionClass = "utility_projectile",
        physics = {
            restitution = 0.0,
            friction = 0.0,
            fixedRotation = true,
            bodyType = "kinematic"
        },
        types = {"mining_laser", "salvaging_laser", "healing_laser"}
    }
}

-- Default category for unknown projectiles
ProjectileCategories.DEFAULT_CATEGORY = "kinetic"

-- Determine projectile category from projectile kind/type
function ProjectileCategories.getCategory(projectileKind)
    if not projectileKind then
        return ProjectileCategories.DEFAULT_CATEGORY
    end
    
    local lowerKind = string.lower(projectileKind)
    
    for categoryName, categoryData in pairs(ProjectileCategories.CATEGORIES) do
        for _, projectileType in ipairs(categoryData.types) do
            if lowerKind:find(string.lower(projectileType)) then
                return categoryName
            end
        end
    end
    
    return ProjectileCategories.DEFAULT_CATEGORY
end

-- Get category data
function ProjectileCategories.getCategoryData(categoryName)
    return ProjectileCategories.CATEGORIES[categoryName] or ProjectileCategories.CATEGORIES[ProjectileCategories.DEFAULT_CATEGORY]
end

-- Get collision class for projectile
function ProjectileCategories.getCollisionClass(projectileKind)
    local category = ProjectileCategories.getCategory(projectileKind)
    local categoryData = ProjectileCategories.getCategoryData(category)
    return categoryData.collisionClass
end

-- Get physics configuration for projectile
function ProjectileCategories.getPhysicsConfig(projectileKind)
    local category = ProjectileCategories.getCategory(projectileKind)
    local categoryData = ProjectileCategories.getCategoryData(category)
    return categoryData.physics
end

-- Check if entity is a projectile
function ProjectileCategories.isProjectile(entity)
    return entity and entity.components and entity.components.projectile
end

-- Get projectile kind from entity
function ProjectileCategories.getProjectileKind(entity)
    if not ProjectileCategories.isProjectile(entity) then
        return nil
    end
    
    -- Check renderable props first
    if entity.components.renderable and entity.components.renderable.props then
        return entity.components.renderable.props.kind
    end
    
    -- Check projectile component
    if entity.components.projectile and entity.components.projectile.kind then
        return entity.components.projectile.kind
    end
    
    -- Check entity kind
    if entity.kind then
        return entity.kind
    end
    
    return "bullet" -- Default fallback
end

return ProjectileCategories
