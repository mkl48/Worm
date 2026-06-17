local Grade      = require(script.Parent.Grade)
local Serializer = require(script.Parent.Serializer)
local Promise     = require(script.Parent.Promise)
local Util        = require(script.Parent.Util)

local toVector       = Util.toVector
local normalizeSchema = Util.normalizeSchema

local VERSION = "0.1.0-beta"

local Profile = {}
Profile.__index = Profile

function Profile.new(wormType, config, impl)
    local self = setmetatable({}, Profile)

    self._type           = wormType
    self._config         = config
    self._interpreter    = nil
    self._labels         = {}
    self._label_map      = {}
    self._label_inv      = {}
    self._grade_config   = nil
    self._grade_weights  = {}
    self._snapshots      = {}
    self._snapshot_order = {}
    self._impl           = impl

    return self
end

function Profile:infer(input)
    return Promise.new(function(resolve, reject)
        local prepared = input
        if self._interpreter then
            local ok, result = pcall(self._interpreter, input)
            if not ok then reject(result) return end
            prepared = result
        end

        if self._config.schema then
            local ok, normalized = pcall(normalizeSchema, prepared, self._config.schema)
            if not ok then reject(normalized) return end
            prepared = normalized
        end

        local vec = toVector(prepared)
        local ok, output = pcall(self._impl._forward, self._impl, vec)
        if not ok then reject(output) return end

        if next(self._label_inv) then
            local maxIdx, maxVal = 1, output[1]
            for i = 2, #output do
                if output[i] > maxVal then
                    maxIdx = i
                    maxVal = output[i]
                end
            end
            resolve(self._label_inv[maxIdx])
        else
            resolve(output)
        end
    end)
end

function Profile:lesson(data)
    return Promise.new(function(resolve, reject)
        local ok, result = pcall(self._impl._lesson, self._impl, data, self)
        if not ok then reject(result) return end
        resolve(result)
    end)
end

function Profile:interpret(fn)
    assert(type(fn) == "function", "Worm: interpret() expects a function")
    self._interpreter = fn
end

function Profile:labels(list)
    for i, label in ipairs(list) do
        if not self._label_map[label] then
            self._label_map[label] = i
            self._label_inv[i]     = label
            table.insert(self._labels, label)
        end
    end
end

function Profile:grade(config)
    self._grade_config  = config
    self._grade_weights = Grade.resolve(config)
end

function Profile:grades()
    return table.clone(self._grade_weights)
end

function Profile:rewards(map)
    self._grade_weights = table.clone(map)
end

function Profile:export()
    return Promise.new(function(resolve, reject)
        local ok, weights = pcall(self._impl._exportWeights, self._impl)
        if not ok then reject(weights) return end

        local data = {
            _worm_type      = self._type,
            _worm_ver       = VERSION,
            config          = self._config,
            weights         = weights,
            labels          = table.clone(self._labels),
            label_map       = table.clone(self._label_map),
            grade_config    = self._grade_config,
            grade_resolved  = self._grade_weights,
            snapshots       = Serializer.packSnapshots(self._snapshots, self._snapshot_order),
        }

        resolve(data)
    end)
end

function Profile:import(data)
    return Promise.new(function(resolve, reject)
        local ok, err = pcall(function()
            self._impl:_importWeights(data.weights)
            self._labels        = data.labels or {}
            self._label_map     = data.label_map or {}
            self._grade_config  = data.grade_config
            self._grade_weights = data.grade_resolved or {}
            if data.snapshots then
                self._snapshots, self._snapshot_order =
                    Serializer.unpackSnapshots(data.snapshots)
            end
            for i, label in ipairs(self._labels) do
                self._label_inv[i] = label
            end
        end)
        if not ok then reject(err) return end
        resolve()
    end)
end

function Profile:reset()
    self._impl:_reset()
end

function Profile:tag(name)
    local ok, weights = pcall(self._impl._exportWeights, self._impl)
    if not ok then return end
    self._snapshots[name] = weights
    table.insert(self._snapshot_order, name)
end

function Profile:rollback(name)
    local snap = self._snapshots[name]
    assert(snap, "Worm: no snapshot tagged '" .. name .. "'")
    self._impl:_importWeights(snap)
end

function Profile:history()
    return table.clone(self._snapshot_order)
end

function Profile:type()
    return self._type
end

function Profile:evolve()
    assert(self._impl.evolve, "Worm: evolve() is only available on NEAT profiles")
    return self._impl:evolve(self)
end

function Profile:champion()
    assert(self._impl.champion, "Worm: champion() is only available on NEAT profiles")
    return self._impl:champion(self)
end

Profile.VERSION = VERSION

return Profile
