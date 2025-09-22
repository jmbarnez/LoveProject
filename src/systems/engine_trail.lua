local EngineTrailSystem = {}

function EngineTrailSystem.update(dt, world)
	if not world then return end

	-- Update player engine trails
	local player
	if world.getPlayer then
		player = world:getPlayer()
	else
		player = nil
	end
	if player and player.components then
		local trail = player.components.engine_trail
		local phys = player.components.physics
		local pos = player.components.position
		if trail and phys and pos then
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
	end

	-- Update AI entity engine trails (red thrusters for enemies)
	local aiEntities = world:get_entities_with_components("ai", "position")
	for _, entity in ipairs(aiEntities) do
		local trail = entity.components.engine_trail
		if trail then
			-- Check if AI is moving/thrusting
			
			local phys = entity.components.physics
			local pos = entity.components.position

			if phys and phys.body and pos then
				local speed = math.sqrt(phys.body.vx * phys.body.vx + phys.body.vy * phys.body.vy)
				local isThrusting = speed > 10  -- AI is thrusting if moving faster than 10 units/second

				-- Engine trail colors remain consistent regardless of entity type or theme
				-- Removed AI color changes to maintain uniform engine trail appearance

				-- Update thruster state based on movement
				local intensity = math.min(1.0, speed / 100)  -- Scale intensity based on speed
				trail:updateThrustState(isThrusting, math.max(0.2, intensity))

				if pos then
					trail:updatePosition(pos.x, pos.y, pos.angle or 0)
				end
				trail:update(dt)
			end
		end
	end
end

return EngineTrailSystem
