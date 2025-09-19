local Skills = {}

-- Skill definitions with XP requirements
Skills.definitions = {
    mining = {
        id = "mining",
        name = "Mining",
        maxLevel = 99,
        xpPerLevel = function(level)
            if level <= 15 then return 10 * level
            elseif level <= 30 then return 100 + 20 * (level - 15)
            elseif level <= 45 then return 400 + 30 * (level - 30)
            elseif level <= 60 then return 850 + 40 * (level - 45)
            elseif level <= 75 then return 1450 + 50 * (level - 60)
            else return 2200 + 75 * (level - 75)
            end
        end
    },
    salvaging = {
        id = "salvaging",
        name = "Salvaging",
        maxLevel = 99,
        xpPerLevel = function(level)
            if level <= 15 then return 12 * level
            elseif level <= 30 then return 120 + 25 * (level - 15)
            elseif level <= 45 then return 470 + 35 * (level - 30)
            elseif level <= 60 then return 995 + 45 * (level - 45)
            elseif level <= 75 then return 1670 + 55 * (level - 60)
            else return 2520 + 80 * (level - 75)
            end
        end
    },
}

-- Player skills data structure
Skills.playerSkills = {
    mining = {
        level = 1,
        xp = 0,
        totalXp = 0
    },
    salvaging = {
        level = 1,
        xp = 0,
        totalXp = 0
    },
}

-- Calculate XP needed for next level
function Skills.getXpForLevel(skillId, level)
    local skill = Skills.definitions[skillId]
    if not skill then return 0 end

    local total = 0
    for i = 1, level do
        total = total + skill.xpPerLevel(i)
    end
    return total
end

-- Get current level for a skill
function Skills.getLevel(skillId)
    local skillData = Skills.playerSkills[skillId]
    return skillData and skillData.level or 1
end

-- Get current XP for a skill
function Skills.getXp(skillId)
    local skillData = Skills.playerSkills[skillId]
    return skillData and skillData.xp or 0
end

-- Get total XP for a skill
function Skills.getTotalXp(skillId)
    local skillData = Skills.playerSkills[skillId]
    return skillData and skillData.totalXp or 0
end

-- Get XP needed for next level
function Skills.getXpToNext(skillId)
    local skillData = Skills.playerSkills[skillId]
    if not skillData then return 0 end

    local nextLevelXp = Skills.getXpForLevel(skillId, skillData.level + 1)
    local currentTotalXp = Skills.getXpForLevel(skillId, skillData.level)
    return nextLevelXp - currentTotalXp
end

-- Get current progress to next level (0-1)
function Skills.getProgressToNext(skillId)
    local skillData = Skills.playerSkills[skillId]
    if not skillData then return 0 end

    local currentLevelXp = Skills.getXpForLevel(skillId, skillData.level)
    local nextLevelXp = Skills.getXpForLevel(skillId, skillData.level + 1)
    local currentXpInLevel = skillData.totalXp - currentLevelXp

    local xpNeeded = nextLevelXp - currentLevelXp
    return math.min(1, currentXpInLevel / xpNeeded)
end

-- Add XP to a skill
function Skills.addXp(skillId, amount)
    local skillData = Skills.playerSkills[skillId]
    if not skillData then return false end

    skillData.totalXp = skillData.totalXp + amount

    -- Calculate new level
    local newLevel = 1
    while newLevel < Skills.definitions[skillId].maxLevel do
        local xpNeeded = Skills.getXpForLevel(skillId, newLevel + 1)
        if skillData.totalXp < xpNeeded then
            break
        end
        newLevel = newLevel + 1
    end

    -- Update level if changed
    local leveledUp = false
    if newLevel > skillData.level then
        skillData.level = newLevel
        leveledUp = true
    end

    -- Update current level XP
    local currentLevelXp = Skills.getXpForLevel(skillId, skillData.level)
    skillData.xp = skillData.totalXp - currentLevelXp

    return leveledUp, newLevel
end



-- Get all skills data for UI
function Skills.getAllSkills()
    local skills = {}
    for skillId, skillDef in pairs(Skills.definitions) do
        local skillData = Skills.playerSkills[skillId]
        if skillData then
            table.insert(skills, {
                id = skillId,
                name = skillDef.name,
                description = skillDef.description,
                level = skillData.level,
                maxLevel = skillDef.maxLevel,
                xp = skillData.xp,
                totalXp = skillData.totalXp,
                xpToNext = Skills.getXpToNext(skillId),
                progress = Skills.getProgressToNext(skillId)
            })
        end
    end
    return skills
end

-- Load skills data (for save/load functionality)
function Skills.load(data)
    if data then
        Skills.playerSkills = data
    end
end

-- Save skills data
function Skills.save()
    return Skills.playerSkills
end

return Skills
