local Util = {}

function Util.toVector(input)
    if type(input[1]) == "number" then
        return input
    end
    local vec = {}
    for _, v in pairs(input) do
        table.insert(vec, v)
    end
    return vec
end

function Util.normalizeSchema(input, schema)
    local vec = {}
    for field, def in pairs(schema) do
        local raw = input[field]
        assert(raw ~= nil, "Worm: schema field '" .. field .. "' missing from input")
        local min, max = def.range[1], def.range[2]
        local normalized = (raw - min) / (max - min)
        normalized = math.clamp(normalized, 0, 1)
        table.insert(vec, normalized)
    end
    return vec
end

function Util.topologicalSort(genome)
    local inDegree = {}
    local adj      = {}
    local nodes    = {}

    for id in pairs(genome.nodes) do
        inDegree[id] = 0
        adj[id]      = {}
        table.insert(nodes, id)
    end

    local conns = {}
    for _, conn in pairs(genome.connections) do
        if conn.enabled then
            table.insert(conns, conn)
            inDegree[conn.out] = (inDegree[conn.out] or 0) + 1
            table.insert(adj[conn.in_], conn)
        end
    end

    local queue = {}
    for id, deg in pairs(inDegree) do
        if deg == 0 then table.insert(queue, id) end
    end

    local sorted = {}
    local head   = 1
    while head <= #queue do
        local node = queue[head]
        head += 1
        for _, conn in ipairs(adj[node] or {}) do
            table.insert(sorted, conn)
            inDegree[conn.out] -= 1
            if inDegree[conn.out] == 0 then
                table.insert(queue, conn.out)
            end
        end
    end

    return sorted
end

return Util
