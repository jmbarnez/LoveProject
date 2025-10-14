local EngineTrailSystem = {}

function EngineTrailSystem.update(dt, world)
	-- Update player engine trail
	local player = world:getPlayer()
	if player and player.components.engine_trail then
		local trail = player.components.engine_trail
		local pos = player.components.position
		
		-- Get thruster state from windfield physics component (more reliable)
		local thrusterState = nil
		if player.components.windfield_physics and player.components.windfield_physics.thrusterState then
			thrusterState = player.components.windfield_physics.thrusterState
		elseif player.components.player_state and player.components.player_state.thruster_state then
			thrusterState = player.components.player_state.thruster_state
		end
		
		if thrusterState then
			-- Calculate thrust intensity
			local intensity = (thrusterState.forward or 0) + (thrusterState.boost or 0) + 
				((thrusterState.strafeLeft or 0) + (thrusterState.strafeRight or 0)) * 0.5 + 
				(thrusterState.reverse or 0) * 0.5
			
			-- Update trail based on thrust
			if (thrusterState.isThrusting or false) and intensity > 0 then
				trail:updateThrustState(true, intensity)
			else
				trail:updateThrustState(false, 0)
			end
		else
			-- No thruster state available, turn off trail
			trail:updateThrustState(false, 0)
		end
		
		-- Update position and angle
		trail:updatePosition(pos.x, pos.y, pos.angle or 0)
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
				-- Use windfield manager for movement detection
				local EntityPhysics = require("src.systems.entity_physics")
				local windfieldManager = EntityPhysics.getManager()
				local collider = windfieldManager and windfieldManager.entities[entity]
				
				if collider and not collider:isDestroyed() then
					local vx, vy = collider:getLinearVelocity()
					local speed = math.sqrt(vx * vx + vy * vy)
					
					-- Show trails when moving
					if speed > 10 then
						local intensity = math.min(1.0, speed / 180)
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