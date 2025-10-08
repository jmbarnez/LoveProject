local ProjectileHandler = require("src.systems.collision.handlers.projectile")
local BeamHandler = require("src.systems.collision.handlers.beam")
local ProjectileUtils = require("src.systems.collision.helpers.projectile_utils")

--- ProjectileCollision keeps the legacy entry-points used by CollisionSystem
--- while delegating to purpose-built handlers for beam and projectile
--- interactions.
local ProjectileCollision = {
    utils = ProjectileUtils,
}

function ProjectileCollision.handle_projectile_collision(collision_system, bullet, world, dt)
    ProjectileHandler.process(collision_system, bullet, world, dt)
end

function ProjectileCollision.handle_beam_collision(collision_system, beam, world, dt)
    BeamHandler.process(collision_system, beam, world, dt)
end

return ProjectileCollision
