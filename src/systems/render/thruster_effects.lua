-- Thruster visual effects rendering
local RenderUtils = require("src.systems.render.utils")
local ThrusterEffects = {}

-- Calculate which thrusters should be active based on movement
local function calculateActiveThruster(thrustX, thrustY)
  local activeThrusters = {}
  local threshold = 0.3 -- Minimum component strength to activate thruster
  
  -- Check for diagonal movement first - if both X and Y components are significant, use diagonal thruster
  if math.abs(thrustX) > threshold and math.abs(thrustY) > threshold then
    local diagonalIntensity = math.sqrt(thrustX*thrustX + thrustY*thrustY) -- Combined intensity
    if thrustX > 0 and thrustY > 0 then
      table.insert(activeThrusters, {index = 4, intensity = diagonalIntensity}) -- Bottom-right
    elseif thrustX > 0 and thrustY < 0 then
      table.insert(activeThrusters, {index = 2, intensity = diagonalIntensity}) -- Top-right
    elseif thrustX < 0 and thrustY > 0 then
      table.insert(activeThrusters, {index = 6, intensity = diagonalIntensity}) -- Bottom-left
    elseif thrustX < 0 and thrustY < 0 then
      table.insert(activeThrusters, {index = 8, intensity = diagonalIntensity}) -- Top-left
    end
  -- If not diagonal, use single directional thruster
  elseif math.abs(thrustX) > math.abs(thrustY) then
    -- Horizontal movement dominates
    if thrustX > 0 then
      table.insert(activeThrusters, {index = 3, intensity = math.abs(thrustX)}) -- Right thruster
    else
      table.insert(activeThrusters, {index = 7, intensity = math.abs(thrustX)}) -- Left thruster
    end
  elseif math.abs(thrustY) > threshold then
    -- Vertical movement dominates
    if thrustY > 0 then
      table.insert(activeThrusters, {index = 5, intensity = math.abs(thrustY)}) -- Bottom thruster
    else
      table.insert(activeThrusters, {index = 1, intensity = math.abs(thrustY)}) -- Top thruster
    end
  end
  
  return activeThrusters
end

-- Draw individual thruster flame
local function drawThrusterFlame(pos, intensity, time, size)
  local S = function(x) return x * size end
  local baseIntensity = intensity
  local pulse = 0.85 + 0.15 * math.sin(time * 15 + pos.index * 0.5)
  local flicker = 0.9 + 0.1 * math.sin(time * 25 + pos.index * 1.2)
  local finalIntensity = math.min(1.0, baseIntensity * 1.2)
  local alpha = math.max(0.4, finalIntensity) * pulse * flicker
  
  -- Calculate flame length and direction based on thruster position
  local flameLength = S(20 + finalIntensity * 15)
  local flameWidth = S(8 + finalIntensity * 10)
  local coreWidth = S(4 + finalIntensity * 6)
  
  -- Determine flame direction (away from ship center)
  local flameX = pos.x == 0 and 0 or (pos.x > 0 and 1 or -1)
  local flameY = pos.y == 0 and 0 or (pos.y > 0 and 1 or -1)
  
  -- Normalize flame direction for diagonals
  local flameMag = math.sqrt(flameX*flameX + flameY*flameY)
  if flameMag > 0 then
    flameX = flameX / flameMag
    flameY = flameY / flameMag
  end
  
  -- Multiple flame layers for depth and realism
  love.graphics.push()
  love.graphics.translate(S(pos.x), S(pos.y))
  
  -- Outer plasma glow (largest, most transparent)
  love.graphics.setColor(0.1, 0.6, 1.0, alpha * 0.3)
  love.graphics.ellipse("fill", flameX * flameLength * 0.8, flameY * flameLength * 0.8, 
                       flameWidth * 1.5, flameWidth * 0.8)
  
  -- Main flame body (bright blue-white core)
  love.graphics.setColor(0.3, 0.8, 1.0, alpha * 0.8)
  love.graphics.ellipse("fill", flameX * flameLength * 0.6, flameY * flameLength * 0.6, 
                       flameWidth, flameWidth * 0.6)
  
  -- Inner core (hot white center)
  love.graphics.setColor(0.8, 0.9, 1.0, alpha)
  love.graphics.ellipse("fill", flameX * flameLength * 0.4, flameY * flameLength * 0.4, 
                       coreWidth, coreWidth * 0.5)
  
  -- Hot center point
  love.graphics.setColor(1.0, 1.0, 1.0, alpha * 1.2)
  love.graphics.circle("fill", flameX * flameLength * 0.2, flameY * flameLength * 0.2, S(2))
  
  -- Thruster nozzle glow at ship surface
  love.graphics.setColor(0.4, 0.7, 1.0, alpha * 0.6)
  love.graphics.circle("fill", 0, 0, S(3 + finalIntensity * 2))
  love.graphics.setColor(0.6, 0.9, 1.0, alpha * 0.4)
  love.graphics.circle("line", 0, 0, S(5 + finalIntensity * 3))
  
  -- Particle trail effect
  for i = 1, math.floor(3 + finalIntensity * 4) do
    local particleTime = time * 8 + pos.index + i * 0.8
    local particleProgress = (particleTime % 1.0)
    local px = flameX * flameLength * (0.3 + particleProgress * 0.4)
    local py = flameY * flameLength * (0.3 + particleProgress * 0.4)
    local spread = S(2) * math.sin(particleTime * 2)
    px = px + spread * (math.sin(particleTime * 3) * 0.5)
    py = py + spread * (math.cos(particleTime * 2.5) * 0.5)
    local particleAlpha = alpha * (1 - particleProgress) * 0.6
    love.graphics.setColor(0.6, 0.8, 1.0, particleAlpha)
    love.graphics.circle("fill", px, py, S(1 + finalIntensity))
  end
  
  love.graphics.pop()
end

-- Main thruster drawing function
function ThrusterEffects.drawThrusters(thrusters, size, entity)
  local time = love.timer.getTime()
  
  -- Get actual movement velocity from physics body
  local vx, vy = 0, 0
  local movementMagnitude = 0
  
  if entity and entity.components and entity.components.physics and entity.components.physics.body then
    local body = entity.components.physics.body
    vx, vy = body.vx, body.vy
    movementMagnitude = math.sqrt(vx * vx + vy * vy)
  end

  -- Show thrusters if moving (lower threshold for visibility)
  if movementMagnitude > 1 then -- Much lower threshold
    -- Normalize movement vector
    local moveX = vx / movementMagnitude
    local moveY = vy / movementMagnitude
    
    -- Calculate thrust direction (opposite to movement)
    local thrustX = -moveX
    local thrustY = -moveY
    
    -- Determine which single thruster to fire based on movement direction
    local activeThrusters = calculateActiveThruster(thrustX, thrustY)
    
    -- Thruster positions
    local thrusterPositions = {
      {x = 0, y = -25, index = 1},     -- 1: Top
      {x = 25, y = -25, index = 2},    -- 2: Top Right  
      {x = 25, y = 0, index = 3},      -- 3: Right
      {x = 25, y = 25, index = 4},     -- 4: Bottom Right
      {x = 0, y = 25, index = 5},      -- 5: Bottom
      {x = -25, y = 25, index = 6},    -- 6: Bottom Left
      {x = -25, y = 0, index = 7},     -- 7: Left
      {x = -25, y = -25, index = 8},   -- 8: Top Left
    }
    
    -- Draw all active thrusters with individual intensity
    for _, thruster in ipairs(activeThrusters) do
      local pos = thrusterPositions[thruster.index]
      drawThrusterFlame(pos, thruster.intensity, time, size)
    end
  end
end

return ThrusterEffects