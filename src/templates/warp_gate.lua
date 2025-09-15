-- Warp Gate Template: Creates interactive warp gate entities
local Position = require("src.components.position")
local Renderable = require("src.components.renderable")
local Collidable = require("src.components.collidable")
local WarpGate = require("src.components.warp_gate")

local WarpGateTemplate = {}
WarpGateTemplate.__index = WarpGateTemplate

function WarpGateTemplate.new(x, y, config)
    local self = setmetatable({}, WarpGateTemplate)

    -- Basic entity properties
    self.tag = "warp_gate"
    self.name = config.name or "Warp Gate"

    -- Determine visuals for this gate (from config or default design)
    local visuals = config.visuals or {
        {
            type = "circle",
            radius = 400,
            color = {0.2, 0.8, 1.0, 0.8},
            fill = false,
            line_width = 3
        },
        {
            type = "circle",
            radius = 300,
            color = {0.4, 0.9, 1.0, 0.6},
            fill = false,
            line_width = 2
        },
        {
            type = "circle",
            radius = 200,
            color = {0.6, 1.0, 1.0, 0.4},
            fill = true
        }
    }

    -- Compute interaction radius from the visual design (outermost ring)
    local designRadius = 0
    for _, shape in ipairs(visuals) do
        if shape.type == "circle" then
            designRadius = math.max(designRadius, shape.radius or shape.r or 0)
        elseif shape.type == "rectangle" then
            local w = shape.w or shape.width or 0
            local h = shape.h or shape.height or 0
            designRadius = math.max(designRadius, math.max(w, h) / 2)
        end
    end
    -- Effective interaction range prefers config only if explicitly provided; otherwise use design radius
    local effectiveRange = (type(config.interactionRange) == "number" and config.interactionRange) or designRadius

    -- Entity components
    self.components = {
        position = Position.new({ x = x, y = y, angle = config.angle or 0 }),
        -- Pass visuals and effective interaction range to component so it can compute correctly
        warp_gate = WarpGate.new((function()
            local cfg = {}
            for k, v in pairs(config) do cfg[k] = v end
            cfg.visuals = visuals
            cfg.interactionRange = effectiveRange
            return cfg
        end)())
    }

    -- Add renderable component for visual representation
    if config.renderable ~= false then
        local renderConfig = {
            type = "warp_gate",
            props = {
                visuals = visuals
            }
        }
        self.components.renderable = Renderable.new(renderConfig.type, renderConfig.props)
    end

    -- Add collision for interaction detection
    if config.collidable ~= false then
        local collisionConfig = {
            type = "circle",
            radius = effectiveRange,
            isSensor = true -- Non-blocking collision for interaction detection
        }
        self.components.collidable = Collidable.new(collisionConfig)
    end

    -- Add interaction component for tooltip/UI hints
    self.components.interactable = {
        range = effectiveRange,
        hint = function()
            return self.components.warp_gate:getInteractionHint()
        end,
        activate = function(player)
            -- Open the warp interface via UI manager
            local UIManager = require("src.core.ui_manager")
            UIManager.open("warp")
            return true
        end
    }

    return self
end

-- Update the warp gate
function WarpGateTemplate:update(dt)
    if self.components.warp_gate then
        self.components.warp_gate:update(dt)
    end

    -- Auto-recharge power if needed
    if self.components.warp_gate and self.components.warp_gate.requiresPower then
        self.components.warp_gate:rechargePower(dt, 2) -- Slow recharge rate
    end
end

-- Check if player can interact with this warp gate
function WarpGateTemplate:canInteractWith(player)
    if not self.components.warp_gate or not self.components.position then
        return false
    end

    return self.components.warp_gate:canInteract(player, self.components.position)
end

-- Activate the warp gate
function WarpGateTemplate:activate(player)
    if not self.components.warp_gate then
        return false, "Warp gate component not found"
    end

    return self.components.warp_gate:activate(player)
end

-- Get interaction hint for UI display
function WarpGateTemplate:getInteractionHint()
    if not self.components.warp_gate then
        return "Warp Gate (Error)", {1, 0, 0}
    end

    return self.components.warp_gate:getInteractionHint()
end

-- Set warp gate active state
function WarpGateTemplate:setActive(active)
    if self.components.warp_gate then
        self.components.warp_gate:setActive(active)
    end
end

-- Get visual properties for custom rendering
function WarpGateTemplate:getVisualProperties()
    if not self.components.warp_gate then
        return {}
    end

    return self.components.warp_gate:getVisualProperties()
end

return WarpGateTemplate