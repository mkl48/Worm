local Promise = require(script.Parent.Promise)

-- A meta-controller over a set of named Profiles ("stances"/sub-policies).
-- A selector Profile decides which member handles the current input; the
-- chosen member then makes the actual decision. Members can be any Profile
-- type -- an MLP, a QLearner, even a NEAT champion -- since they all share
-- the same Profile API.
local Ensemble = {}
Ensemble.__index = Ensemble

function Ensemble.new(config)
    local self = setmetatable({}, Ensemble)

    self._selector = config.selector
    self._members  = config.members
    self._default  = config.default

    return self
end

function Ensemble:infer(input)
    return Promise.new(function(resolve, reject)
        self._selector:infer(input)
            :next(function(stance)
                local member = self._members[stance]
                if not member and self._default then
                    stance = self._default
                    member = self._members[stance]
                end
                assert(member, "Worm.Ensemble -- no member registered for stance '" .. tostring(stance) .. "'")

                member:infer(input)
                    :next(function(action)
                        resolve({ stance = stance, action = action })
                    end)
                    :toss(reject)
            end)
            :toss(reject)
    end)
end

function Ensemble:lesson(stance, data)
    local member = self._members[stance]
    assert(member, "Worm.Ensemble -- no member registered for stance '" .. tostring(stance) .. "'")
    return member:lesson(data)
end

function Ensemble:selectorLesson(data)
    return self._selector:lesson(data)
end

function Ensemble:member(stance)
    return self._members[stance]
end

function Ensemble:selector()
    return self._selector
end

function Ensemble:stances()
    local names = {}
    for stance in pairs(self._members) do
        table.insert(names, stance)
    end
    return names
end

return Ensemble
