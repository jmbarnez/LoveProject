local ProceduralGen = {}

function ProceduralGen.generateTurretStats(baseTurret, tier)
  local newTurret = {}
  for k, v in pairs(baseTurret) do
    newTurret[k] = v
  end

  if newTurret.damage_range then
    local min = newTurret.damage_range.min
    local max = newTurret.damage_range.max
    newTurret.damage = math.random(min, max)
  end

  return newTurret
end

return ProceduralGen
