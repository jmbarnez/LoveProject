local Util = require("src.core.util")
local Turret = require("src.systems.turret.core")
local Content = require("src.content.content")
local PhysicsComponent = require("src.components.physics")
local Position = require("src.components.position")
local Renderable = require("src.components.renderable")
local Collidable = require("src.components.collidable")
local Health = require("src.components.health")
local AI = require("src.components.ai")
local EngineTrail = require("src.components.engine_trail")
local PhysicsComponent = require("src.components.physics")

local Enemy = {}
Enemy.__index = Enemy

function Enemy.new(x, y, options)
  local self = setmetatable({}, Enemy)
  options = options or {}
  
  -- Initialize physics component (lighter mass for nimbleness)
  local physics = PhysicsComponent.new({ mass = 150, x = x, y = y })
  physics.body.radius = 10
  self.sig = 80
  
  -- AI behavior properties with intelligence level
  local intelligenceLevel = options.intelligenceLevel or "STANDARD"
  local aggressiveType = options.aggressiveType or "aggressive"  -- Default to aggressive for enemies
  self.aggro = false
  self.moveTarget = nil
  self.combatState = "patrol" -- patrol, engage, retreat, orbit
  self.wasAttacked = false
  
  -- Hardcoded enemy type
  self.name = "Scout Drone"
  -- No legacy hp fields; use components.health
  self.bounty = 8
  self.xpReward = 10
  -- No legacy shield fields; use components.health
  
  -- Shared turret system: basic drones use laser for testing
  local turretId = "laser_mk1"
  local tDef = (Content.getTurret and Content.getTurret(turretId))
  if tDef then
    tDef = Util.copy(tDef)
    tDef.capCost = 0 -- Drones don't use energy
    tDef.cycle = 3.0 -- Slower firing rate for enemies
    tDef.fireMode = "automatic" -- Enemy turrets should fire automatically
  end
  self.turret = Turret.new(self, tDef or {
    type = "laser",
    optimal = 380, falloff = 260,
    cycle = 4.5, capCost = 0,
    fireMode = "automatic"  -- Enemy turrets should fire automatically
  })
  -- Behavior ranges
  local opt = self.turret.optimal or 380
  local fall = self.turret.falloff or 250
  self.aggroRange = opt + fall + 200 -- a bit further than turret range
  self.wanderDir = math.random() * math.pi * 2
  self.wanderTimer = 1 + math.random() * 2
  self.dead = false
  -- Simple loot table (placeholder items)
  self.lootTable = {
    { id = "ore_tritanium", min = 1, max = 3, chance = 0.7 },
    { id = "ore_palladium", min = 1, max = 2, chance = 0.35 },
  }
  
  -- Visual definition for Scout Drone
  self.visuals = {
    size = 0.8,
    shapes = {
      { type = "circle", mode = "fill", color = {0.42, 0.45, 0.50, 1.0}, x = 0, y = 0, r = 10 },
      { type = "circle", mode = "line", color = {0.20, 0.22, 0.26, 0.9}, x = 0, y = 0, r = 10 },
      { type = "circle", mode = "fill", color = {1.0, 0.35, 0.25, 0.9}, x = 3, y = 0, r = 3.2 },
      { type = "rect", mode = "fill", color = {0.32, 0.35, 0.39, 1.0}, x = -6, y = -12, w = 18, h = 4, rx = 1 },
      { type = "rect", mode = "fill", color = {0.32, 0.35, 0.39, 1.0}, x = -6, y = 8,  w = 18, h = 4, rx = 1 },
      { type = "rect", mode = "fill", color = {0.28, 0.30, 0.34, 1.0}, x = 8, y = -1, w = 8, h = 2, rx = 1 },
      { type = "circle", mode = "fill", color = {1.0, 0.25, 0.2, 0.8}, x = -6, y = -10, r = 1.5 },
      { type = "circle", mode = "fill", color = {1.0, 0.25, 0.2, 0.8}, x = -6, y = 10,  r = 1.5 },
    }
  }
  
  -- ECS components (for systems and standardized access)
  self.components = {
    position   = Position.new({ x = x, y = y, angle = 0 }),
    collidable = Collidable.new({ radius = physics.body.radius }),
    health     = Health.new({ hp = 5, maxHP = 5, shield = 3, maxShield = 3 }),
    physics    = physics,
    renderable = Renderable.new("enemy", { visuals = self.visuals }),
    ai         = AI.new({
      intelligenceLevel = intelligenceLevel,
      aggressiveType = aggressiveType,
      range = self.aggroRange or 600,
      spawnPos = {x = x, y = y},  -- Set spawn position for patrolling
      patrolCenter = {x = x, y = y}  -- Patrol around spawn location
    }),
    equipment  = { turrets = {} },
    engine_trail = EngineTrail.new({
        size = 0.8,
        offset = 12,
        color1 = {1.0, 0.2, 0.1, 1.0},  -- Red primary
        color2 = {1.0, 0.2, 0.1, 0.5}   -- Red secondary
    }),  -- Red thrusters for AI
  }

  -- Provide turret via components.equipment for consistency when inspected by systems
  table.insert(self.components.equipment.turrets, { id = "laser_mk1", turret = self.turret, enabled = true, slot = 1 })

  return self
end

function Enemy:hit(dmg)
  local h = self.components and self.components.health
  if h then
    local s = math.min((h.shield or 0), dmg or 0)
    h.shield = math.max(0, (h.shield or 0) - s)
    local rem = (dmg or 0) - s
    if rem > 0 then
      h.hp = math.max(0, (h.hp or 0) - rem)
      if (h.hp or 0) <= 0 then self.dead = true end
    end
  end
  -- Taking damage triggers aggro and marks as attacked for neutral AIs
  if not self.aggro then self.aggro = true end
  self.wasAttacked = true
  if self.components.ai then
    self.components.ai.wasAttacked = true
  end
end

function Enemy:onTargeted()
  self.aggro = true
end

function Enemy:update(dt, player, shoot)
    -- Update physics and sync position
    if self.components.physics and self.components.physics.update then
      self.components.physics:update(dt)
    end
    local b = self.components.physics.body
    local pos = self.components.position
    pos.x, pos.y, pos.angle = b.x, b.y, b.angle
    
    local ppos = player.components and player.components.position or {x=0,y=0}
    local dx, dy = ppos.x - pos.x, ppos.y - pos.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local optimalRange = self.turret.optimal or 380
    local maxRange = optimalRange + (self.turret.falloff or 250)
    
    -- Range-focused AI behavior - keep player in effective attack range
    local h = self.components and self.components.health
    local retreat = (h and h.maxHP and ((h.hp or 0) / math.max(1, h.maxHP)) < 0.4) or false
    local idealRange = optimalRange * 0.85  -- Slightly closer than optimal for better accuracy
    local tooClose = idealRange * 0.6      -- Back away if player gets too close
    local tooFar = maxRange * 0.9         -- Chase if player gets too far
    
    if retreat then
        self.combatState = "retreat"
    elseif self.aggro or dist < (self.aggroRange or (maxRange + 200)) then
        if dist < tooClose then
            self.combatState = "backoff"  -- Back away to maintain range
        elseif dist > tooFar then
            self.combatState = "engage"   -- Close distance to effective range
        else
            self.combatState = "maintain" -- Stay at current range and strafe
        end
    else
        self.combatState = "patrol"
    end
    
    -- Range-control movement behaviors
    if self.combatState == "retreat" then
        -- Fast retreat directly away from player
        local retreatX = pos.x - dx * 3
        local retreatY = pos.y - dy * 3
        self:setMoveTarget(retreatX, retreatY, 450)
        
    elseif self.combatState == "backoff" then
        -- Back away to ideal range while still facing player
        local dirX, dirY = dx / dist, dy / dist
        local backoffX = ppos.x - dirX * idealRange * 1.2
        local backoffY = ppos.y - dirY * idealRange * 1.2
        self:setMoveTarget(backoffX, backoffY, 380)
        
    elseif self.combatState == "engage" then
        -- Move to ideal attack range
        local dirX, dirY = dx / dist, dy / dist
        local engageX = ppos.x - dirX * idealRange
        local engageY = ppos.y - dirY * idealRange
        self:setMoveTarget(engageX, engageY, 400)
        
    elseif self.combatState == "maintain" then
        -- Strafe around player at current range to avoid being a sitting duck
        self.wanderTimer = (self.wanderTimer or 0) - dt
        if self.wanderTimer <= 0 then
            -- Pick a strafe direction (perpendicular to player direction)
            local perpAngle = math.atan2(dy, dx) + math.pi * 0.5 * (math.random() > 0.5 and 1 or -1)
            local strafeDistance = 150 + math.random() * 100
            local strafeX = pos.x + math.cos(perpAngle) * strafeDistance
            local strafeY = pos.y + math.sin(perpAngle) * strafeDistance
            
            -- Adjust strafe target to maintain distance from player
            local strafeDir = math.sqrt((strafeX - ppos.x)^2 + (strafeY - ppos.y)^2)
            if strafeDir > 0 then
                local scale = idealRange / strafeDir
                strafeX = ppos.x + (strafeX - ppos.x) * scale
                strafeY = ppos.y + (strafeY - ppos.y) * scale
            end
            
            self:setMoveTarget(strafeX, strafeY, 320)
            self.wanderTimer = 0.8 + math.random() * 1.2  -- More frequent movement updates
        end
        
    else -- patrol
        -- Wander around looking for player
        self.wanderTimer = (self.wanderTimer or 0) - dt
        if self.wanderTimer <= 0 then
            local wanderX = pos.x + (math.random() - 0.5) * 300
            local wanderY = pos.y + (math.random() - 0.5) * 300
            self:setMoveTarget(wanderX, wanderY, 250)
            self.wanderTimer = 2 + math.random() * 3
        end
    end
    
    -- Execute arcade movement (same as player)
    self:updateArcadeMovement(dt)
    
    -- Aggressive combat logic - shoot whenever possible in effective range
    local canShoot = false
    
    if self.combatState ~= "patrol" and dist <= maxRange and dist >= 40 then
        -- Check if we're facing the player well enough to shoot
        local angleToPlayer = math.atan2(dy, dx)
        local angleDiff = angleToPlayer - pos.angle
        while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
        while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end
        
        -- More lenient firing angle - can shoot if roughly facing the player
        canShoot = math.abs(angleDiff) < math.pi * 0.6
        
        -- Don't shoot while retreating unless facing player
        if self.combatState == "retreat" then
            canShoot = canShoot and math.abs(angleDiff) < math.pi * 0.3
        end
    end
    
    self.turret:update(dt, player, canShoot, function(x, y, angle, friendly, kind, damage, dist2, style, target, weaponDef)
        shoot(x, y, angle, false, kind, damage, dist2, style, target, weaponDef)
    end)
end

-- Set movement target for arcade-style movement
function Enemy:setMoveTarget(x, y, maxSpeed)
    self.moveTarget = {x = x, y = y, maxSpeed = maxSpeed or 350}
end

-- Arcade-style movement implementation (similar to player)
function Enemy:updateArcadeMovement(dt)
    if self.moveTarget then
        local pos = self.components.position
        local b = self.components.physics.body
        local dx, dy = self.moveTarget.x - pos.x, self.moveTarget.y - pos.y
        local dist = math.sqrt(dx*dx + dy*dy)

        if dist < 20 then
            -- Arrived at target
            self.moveTarget = nil
            b.vx = b.vx * 0.9  -- Quick stop
            b.vy = b.vy * 0.9
        else
            -- Fast, snappy turning
            local targetAngle = math.atan2(dy, dx)
            local angleDiff = targetAngle - pos.angle

            -- Normalize angle difference
            while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
            while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end

            -- Very fast turning for enemies (even faster than player)
            if math.abs(angleDiff) > 0.05 then
                local turnSpeed = 12.0 * dt -- Faster than player
                if math.abs(angleDiff) < turnSpeed then
                    b.angle = targetAngle
                else
                    b.angle = b.angle + (angleDiff > 0 and turnSpeed or -turnSpeed)
                end
            end

            -- Direct velocity control
            local maxSpeed = self.moveTarget.maxSpeed or 350
            if dist < 100 then
                maxSpeed = maxSpeed * 0.7  -- Slow down when approaching
            end

            local dirX, dirY = dx / dist, dy / dist
            local currentSpeed = b:getSpeed()
            
            -- Quick acceleration
            if currentSpeed < maxSpeed then
                local accelRate = 1500 * dt -- Faster acceleration than player
                local newVx = b.vx + dirX * accelRate
                local newVy = b.vy + dirY * accelRate
                
                -- Cap the speed
                local newSpeed = math.sqrt(newVx*newVx + newVy*newVy)
                if newSpeed > maxSpeed then
                    local scale = maxSpeed / newSpeed
                    newVx, newVy = newVx * scale, newVy * scale
                end
                
                b.vx = newVx
                b.vy = newVy
            end
        end
    else
        -- Natural deceleration when no target
        local b = self.components.physics.body
        b.vx = b.vx * 0.95
        b.vy = b.vy * 0.95
    end
end

-- Rendering handled by central RenderSystem using components.renderable

return Enemy
