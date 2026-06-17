local Serializer = {}

function Serializer.packSnapshots(snapshots, order)
    local packed = {}
    for _, name in ipairs(order) do
        table.insert(packed, { name = name, weights = snapshots[name] })
    end
    return packed
end

function Serializer.unpackSnapshots(packed)
    local snapshots = {}
    local order     = {}
    for _, entry in ipairs(packed) do
        snapshots[entry.name] = entry.weights
        table.insert(order, entry.name)
    end
    return snapshots, order
end

function Serializer.deepClone(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[Serializer.deepClone(k)] = Serializer.deepClone(v)
    end
    return copy
end

return Serializer
