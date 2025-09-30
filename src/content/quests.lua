local quests = {
  {
    id = "destroy_drones",
    title = "Drone Menace",
    description = "Destroy 5 basic drones.",
    objective = { type = "kill", target = "basic_drone", count = 5 },
    reward = { gc = 1000, xp = 100 }
  }
}

return quests