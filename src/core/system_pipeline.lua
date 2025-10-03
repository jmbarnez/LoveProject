local SystemPipeline = {}
SystemPipeline.__index = SystemPipeline

function SystemPipeline.new(steps)
  return setmetatable({ steps = steps or {} }, SystemPipeline)
end

function SystemPipeline:update(context)
  if not self.steps then return end
  for _, step in ipairs(self.steps) do
    step(context)
  end
end

function SystemPipeline:setSteps(steps)
  self.steps = steps or {}
end

return SystemPipeline
