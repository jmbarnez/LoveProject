local EngineTrailSystem = {}

function EngineTrailSystem.update(dt, world)
	if not world then return end
	local player
	if world.getPlayer then
		player = world:getPlayer()
	else
		player = nil
	end
	if not player or not player.components then return end
	local trail = player.components.engine_trail
	local phys = player.components.physics
	local pos = player.components.position
	if not trail or not phys or not pos then return end
	-- Prefer player-controlled thruster state (set by PlayerSystem), fall back to physics body
	local thrusterState = (player.thrusterState and type(player.thrusterState) == "table" and player.thrusterState)
		or (phys.getThrusterState and phys:getThrusterState())
		or { isThrusting = false }
	-- Combine inputs into an overall intensity
	local intensity = (thrusterState.forward or 0)
		+ (thrusterState.boost or 0)
		+ ((thrusterState.strafeLeft or 0) + (thrusterState.strafeRight or 0)) * 0.5
		+ (thrusterState.reverse or 0) * 0.5
	local isThrusting = thrusterState.isThrusting or (intensity > 0)
	trail:updateThrustState(isThrusting, math.max(0.2, intensity))
	trail:updatePosition(pos.x, pos.y, pos.angle or 0)
	trail:update(dt)
end

return EngineTrailSystem
