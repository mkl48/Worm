local Grade = {}

local POLARITY_BASE = {
    ["+critical"] =  4.0,
    ["+high"]     =  2.0,
    ["+medium"]   =  1.0,
    ["+low"]      =  0.4,
    ["-low"]      = -0.4,
    ["-medium"]   = -1.0,
    ["-high"]     = -2.0,
    ["-critical"] = -4.0,
}

local MARGIN = {
    large  = 2.0,
    medium = 1.0,
    small  = 0.5,
}

function Grade.resolve(config)
    local weights = {}

    if config.style == "ordinal" then
        local values = {}
        for _, v in pairs(config.events) do table.insert(values, v) end
        table.sort(values)
        local min, max = values[1], values[#values]
        local range    = max - min

        for event, v in pairs(config.events) do
            if range == 0 then
                weights[event] = 0
            else
                weights[event] = ((v - min) / range) * 8 - 4
            end
        end

    elseif config.style == "polarity" then
        for event, polarity in pairs(config.events) do
            weights[event] = POLARITY_BASE[polarity]
            assert(weights[event], "Worm: unknown polarity value '" .. polarity .. "'")
        end

    elseif config.style == "pairs" then
        local scores = {}
        for _, pair in ipairs(config.events) do
            scores[pair.better] = (scores[pair.better] or 0) + MARGIN[pair.margin]
            scores[pair.worse]  = (scores[pair.worse]  or 0) - MARGIN[pair.margin]
        end
        local vals = {}
        for _, v in pairs(scores) do table.insert(vals, v) end
        table.sort(vals)
        local min, max = vals[1], vals[#vals]
        local range    = max - min
        for event, v in pairs(scores) do
            weights[event] = range == 0 and 0 or ((v - min) / range) * 8 - 4
        end
    end

    if config.pin then
        for pinnedEvent, pinnedVal in pairs(config.pin) do
            local currentVal = weights[pinnedEvent]
            assert(currentVal, "Worm: pin target '" .. pinnedEvent .. "' not in events")
            if currentVal ~= 0 then
                local scale = pinnedVal / currentVal
                for event in pairs(weights) do
                    weights[event] *= scale
                end
            end
        end
    end

    return weights
end

return Grade
