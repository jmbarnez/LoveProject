local ProceduralGen = {}

-- Turret modifier definitions
ProceduralGen.modifiers = {
  damage = {
    { name = "Weak", mult = 0.7, desc = "Reduced damage output" },
    { name = "Standard", mult = 1.0, desc = "Standard damage output" },
    { name = "Powerful", mult = 1.3, desc = "Increased damage output" },
    { name = "Devastating", mult = 1.6, desc = "Significantly increased damage" }
  },
  cooldown = {
    { name = "Slow", mult = 1.4, desc = "Slower firing rate" },
    { name = "Standard", mult = 1.0, desc = "Standard firing rate" },
    { name = "Rapid", mult = 0.7, desc = "Faster firing rate" },
    { name = "Lightning", mult = 0.5, desc = "Very fast firing rate" }
  },
  heat = {
    { name = "Cool", mult = 0.6, desc = "Lower heat generation" },
    { name = "Standard", mult = 1.0, desc = "Standard heat generation" },
    { name = "Hot", mult = 1.4, desc = "Higher heat generation" },
    { name = "Overheating", mult = 1.8, desc = "Very high heat generation" }
  }
}

function ProceduralGen.generateTurretStats(baseTurret, tier)
  local newTurret = {}
  for k, v in pairs(baseTurret) do
    newTurret[k] = v
  end

  -- Initialize modifiers array
  newTurret.modifiers = {}

  -- Apply damage modifier
  if newTurret.damage_range then
    local min = newTurret.damage_range.min
    local max = newTurret.damage_range.max
    local baseDamage = math.random(min, max)

    -- Select random damage modifier
    local damageMod = ProceduralGen.modifiers.damage[math.random(1, #ProceduralGen.modifiers.damage)]
    newTurret.damage = math.floor(baseDamage * damageMod.mult)
    table.insert(newTurret.modifiers, {
      type = "damage",
      name = damageMod.name,
      mult = damageMod.mult,
      desc = damageMod.desc
    })
  end

  -- Apply cooldown modifier
  if newTurret.cycle then
    local cooldownMod = ProceduralGen.modifiers.cooldown[math.random(1, #ProceduralGen.modifiers.cooldown)]
    newTurret.cycle = newTurret.cycle * cooldownMod.mult
    table.insert(newTurret.modifiers, {
      type = "cooldown",
      name = cooldownMod.name,
      mult = cooldownMod.mult,
      desc = cooldownMod.desc
    })
  end

  -- Apply heat generation modifier
  if newTurret.heatPerShot then
    local heatMod = ProceduralGen.modifiers.heat[math.random(1, #ProceduralGen.modifiers.heat)]
    newTurret.heatPerShot = math.floor(newTurret.heatPerShot * heatMod.mult)
    table.insert(newTurret.modifiers, {
      type = "heat",
      name = heatMod.name,
      mult = heatMod.mult,
      desc = heatMod.desc
    })
  end

  -- Generate procedural name based on modifiers
  newTurret.proceduralName = ProceduralGen.generateProceduralName(baseTurret.name, newTurret.modifiers)

  return newTurret
end

function ProceduralGen.generateProceduralName(baseName, modifiers)
  local name = baseName

  -- Add modifier prefixes/suffixes
  for _, mod in ipairs(modifiers) do
    if mod.name ~= "Standard" then
      if mod.type == "damage" then
        if mod.name == "Weak" then name = "Feeble " .. name
        elseif mod.name == "Powerful" then name = "Heavy " .. name
        elseif mod.name == "Devastating" then name = "Brutal " .. name
        end
      elseif mod.type == "cooldown" then
        if mod.name == "Slow" then name = "Slow-Firing " .. name
        elseif mod.name == "Rapid" then name = "Rapid " .. name
        elseif mod.name == "Lightning" then name = "Lightning " .. name
        end
      elseif mod.type == "heat" then
        if mod.name == "Cool" then name = "Cool " .. name
        elseif mod.name == "Hot" then name = "Hot " .. name
        elseif mod.name == "Overheating" then name = "Volatile " .. name
        end
      end
    end
  end

  return name
end

return ProceduralGen
