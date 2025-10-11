-- Sectors data for the warp system
-- Each sector represents a different area of the galaxy with unique properties

local Sectors = {}

-- Define sector types with different characteristics
Sectors.types = {
    core = {
        name = "Core Worlds",
        color = {0.2, 0.8, 0.9},
        description = "Heavily populated systems with advanced infrastructure",
        difficulty = 1,
        resources = {"credits", "technology", "information"}
    },
    frontier = {
        name = "Frontier",
        color = {0.9, 0.6, 0.2},
        description = "Expanding colonies on the edge of known space",
        difficulty = 2,
        resources = {"minerals", "energy", "rare_metals"}
    },
    neutral = {
        name = "Neutral Zone",
        color = {0.7, 0.7, 0.7},
        description = "Contested space between major factions",
        difficulty = 3,
        resources = {"salvage", "weapons", "intel"}
    },
    pirate = {
        name = "Pirate Territories",
        color = {0.9, 0.2, 0.2},
        description = "Lawless regions controlled by pirate clans",
        difficulty = 4,
        resources = {"contraband", "black_market_goods", "bounties"}
    },
    unknown = {
        name = "Uncharted Space",
        color = {0.5, 0.2, 0.8},
        description = "Mysterious regions with ancient secrets",
        difficulty = 5,
        resources = {"artifacts", "exotic_matter", "anomalies"}
    }
}

-- Define the galaxy sectors in a grid layout
Sectors.data = {
    -- Row 1 (Top)
    {id = "alpha_centauri", name = "Alpha Centauri", type = "core", x = 1, y = 1, unlocked = true},
    {id = "vega_system", name = "Vega System", type = "core", x = 2, y = 1, unlocked = true},
    {id = "sirius_cluster", name = "Sirius Cluster", type = "frontier", x = 3, y = 1, unlocked = false},
    {id = "wolf_359", name = "Wolf 359", type = "neutral", x = 4, y = 1, unlocked = false},

    -- Row 2
    {id = "sol_system", name = "Sol System", type = "core", x = 1, y = 2, unlocked = true, isHome = true},
    {id = "barnards_star", name = "Barnard's Star", type = "frontier", x = 2, y = 2, unlocked = true},
    {id = "ross_128", name = "Ross 128", type = "neutral", x = 3, y = 2, unlocked = false},
    {id = "gliese_581", name = "Gliese 581", type = "pirate", x = 4, y = 2, unlocked = false},

    -- Row 3
    {id = "proxima_b", name = "Proxima Centauri", type = "frontier", x = 1, y = 3, unlocked = true},
    {id = "kepler_442", name = "Kepler-442", type = "unknown", x = 2, y = 3, unlocked = false},
    {id = "trappist_1", name = "TRAPPIST-1", type = "frontier", x = 3, y = 3, unlocked = false},
    {id = "lhs_1140", name = "LHS 1140", type = "pirate", x = 4, y = 3, unlocked = false},

    -- Row 4 (Bottom)
    {id = "tau_ceti", name = "Tau Ceti", type = "neutral", x = 1, y = 4, unlocked = false},
    {id = "kapteyn", name = "Kapteyn's Star", type = "unknown", x = 2, y = 4, unlocked = false},
    {id = "hd_40307", name = "HD 40307", type = "pirate", x = 3, y = 4, unlocked = false},
    {id = "gj_667c", name = "Gliese 667C", type = "unknown", x = 4, y = 4, unlocked = false}
}

-- Current player location
Sectors.currentSector = "sol_system"

-- Grid dimensions
Sectors.gridWidth = 4
Sectors.gridHeight = 4

-- Warp costs (in GC - Galactic Credits)
Sectors.warpCosts = {
    adjacent = 100,    -- Adjacent sectors
    distant = 250,     -- 2+ sectors away
    unknown = 500      -- Unknown/uncharted sectors
}

-- Function to get sector by ID
function Sectors.getSectorById(id)
    for _, sector in ipairs(Sectors.data) do
        if sector.id == id then
            return sector
        end
    end
    return nil
end

-- Function to get current sector
function Sectors.getCurrentSector()
    return Sectors.getSectorById(Sectors.currentSector)
end

-- Function to get sector type info
function Sectors.getSectorType(typeName)
    return Sectors.types[typeName]
end

-- Function to calculate warp cost between sectors
function Sectors.calculateWarpCost(fromId, toId)
    local fromSector = Sectors.getSectorById(fromId)
    local toSector = Sectors.getSectorById(toId)

    if not fromSector or not toSector then return 0 end

    local distance = math.abs(fromSector.x - toSector.x) + math.abs(fromSector.y - toSector.y)

    if Sectors.types[toSector.type].name == "Uncharted Space" then
        return Sectors.warpCosts.unknown
    elseif distance == 1 then
        return Sectors.warpCosts.adjacent
    else
        return Sectors.warpCosts.distant
    end
end

-- Function to check if player can warp to a sector
function Sectors.canWarpTo(sectorId)
    local sector = Sectors.getSectorById(sectorId)
    if not sector then return false, "Sector not found" end

    if not sector.unlocked then
        return false, "Sector not unlocked"
    end

    if sector.id == Sectors.currentSector then
        return false, "Already in this sector"
    end

    -- Check if player has enough credits (this would integrate with the portfolio manager)
    local cost = Sectors.calculateWarpCost(Sectors.currentSector, sectorId)
    -- For now, assume player can afford it - this will be checked in the UI

    return true, "Can warp"
end

-- Function to unlock a sector
function Sectors.unlockSector(sectorId)
    local sector = Sectors.getSectorById(sectorId)
    if sector then
        sector.unlocked = true
        return true
    end
    return false
end

-- Function to warp to a sector
function Sectors.warpTo(sectorId)
    local canWarp, reason = Sectors.canWarpTo(sectorId)
    if not canWarp then
        return false, reason
    end

    Sectors.currentSector = sectorId
    return true, "Warp successful"
end

-- Function to get adjacent unlocked sectors
function Sectors.getAdjacentSectors(sectorId)
    local sector = Sectors.getSectorById(sectorId or Sectors.currentSector)
    if not sector then return {} end

    local adjacent = {}
    for _, other in ipairs(Sectors.data) do
        local distance = math.abs(sector.x - other.x) + math.abs(sector.y - other.y)
        if distance == 1 and other.unlocked and other.id ~= sector.id then
            table.insert(adjacent, other)
        end
    end
    return adjacent
end

return Sectors