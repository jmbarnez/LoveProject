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

			-- Only show trails if there's actual thrust input or significant movement
			if isThrusting and intensity > 0.1 then  -- Require minimum thrust intensity
				trail:updateThrustState(true, math.max(0.3, intensity))
			else
				trail:updateThrustState(false, 0)
			end

			trail:updatePosition(pos.x, pos.y, pos.angle or 0)
			trail:update(dt)
		end
	end

	-- Update all entity engine trails
	local entitiesWithTrails = world:get_entities_with_components("position")
	for _, entity in ipairs(entitiesWithTrails) do
		local trail = entity.components.engine_trail
		if trail then
			local phys = entity.components.physics
			local pos = entity.components.position

			if phys and phys.body and pos then
				local speed = math.sqrt(phys.body.vx * phys.body.vx + phys.body.vy * phys.body.vy)
				-- Only show trails if ship is actually moving at a reasonable speed
				local isThrusting = speed > 10  -- Increased threshold to prevent idle trails

				-- Update thruster state based on movement - only if actively moving
				if isThrusting then
					local intensity = math.max(0.3, math.min(1.0, speed / 150))  -- Lower minimum intensity and higher speed threshold
					trail:updateThrustState(isThrusting, intensity)
				else
					trail:updateThrustState(false, 0)  -- Explicitly turn off trails when not moving
				end

				if pos then
					trail:updatePosition(pos.x, pos.y, pos.angle or 0)
				end
				trail:update(dt)
			end
		end
	end
end

return EngineTrailSystem
