local quests = {
  {
    id = "destroy_drones",
    title = "Drone Menace",
    description = "Destroy 5 basic drones.",
    objective = { type = "kill", target = "basic_drone", count = 5 },
    reward = { gc = 1000, xp = 100 }
  },
  {
    id = "mine_stones",
    title = "Rock Collector",
    description = "Mine 10 Tritanium Ore.",
    objective = { type = "mine", target = "ore_tritanium", count = 10 },
    reward = { gc = 500, xp = 50 }
  }
}

return quests