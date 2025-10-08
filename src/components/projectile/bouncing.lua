return function(config)
    config = config or {}

    local maxBounces = config.maxBounces or config.bounces or config.remaining or 1
    maxBounces = tonumber(maxBounces) or 1
    if maxBounces < 0 then
        maxBounces = 0
    end

    return {
        remaining = maxBounces,
        maxBounces = maxBounces,
    }
end
