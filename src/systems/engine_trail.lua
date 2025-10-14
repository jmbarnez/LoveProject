local EngineTrailSystem = {}

function EngineTrailSystem.update(dt, world)
	-- Update player engine trail
	local player = world:getPlayer()
	if player and player.components.engine_trail then
		local trail = player.components.engine_trail
		local pos = player.components.position
		local thrusterState = player.components.player_state.thruster_state
		
		-- Calculate thrust intensity
		local intensity = thrusterState.forward + thrusterState.boost + 
			(thrusterState.strafeLeft + thrusterState.strafeRight) * 0.5 + 
			thrusterState.reverse * 0.5
		
		-- Update trail based on thrust
		if thrusterState.isThrusting and intensity > 0 then
			trail:updateThrustState(true, intensity)
		else
			trail:updateThrustState(false, 0)
		end
		
		-- Update position and angle
		trail:updatePosition(pos.x, pos.y, pos.angle)
		trail:update(dt)
	end
	
	-- Update enemy engine trails
	for _, entity in ipairs(world:getEntities()) do
		if entity.components.engine_trail and entity.components.position then
			local trail = entity.components.engine_trail
			local pos = entity.components.position
			
			-- Skip remote players
			if entity.isRemotePlayer then
				trail:updatePosition(pos.x, pos.y, pos.angle or 0)
				trail:update(dt)
			else
				-- Use physics velocity for movement detection
				local manager = require("src.systems.entity_physics").getManager()
				local collider = manager:getCollider(entity)
				
				if collider then
					local vx, vy = collider:getLinearVelocity()
					local speed = math.sqrt(vx * vx + vy * vy)
					
					-- Show trails when moving
					if speed > 10 then
						local intensity = speed / 180
						trail:updateThrustState(true, intensity)
						
						-- Use movement direction for trail angle
						local angle = math.atan2(vy, vx)
						trail:updatePosition(pos.x, pos.y, angle)
					else
						trail:updateThrustState(false, 0)
						trail:updatePosition(pos.x, pos.y, pos.angle or 0)
					end
				else
					trail:updateThrustState(false, 0)
					trail:updatePosition(pos.x, pos.y, pos.angle or 0)
				end
				
				trail:update(dt)
			end
		end
	end
end

return EngineTrailSystem