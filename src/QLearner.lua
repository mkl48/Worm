local MLP  = require(script.Parent.MLP)
local Util = require(script.Parent.Util)

local toVector        = Util.toVector
local normalizeSchema = Util.normalizeSchema

local QLearner = {}
QLearner.__index = QLearner

local function netConfig(config)
    return {
        inputs            = config.states,
        outputs           = config.actions,
        hidden            = config.hidden or { 24, 24 },
        activation        = config.activation or "relu",
        output_activation = "linear",
        optimizer         = config.optimizer,
        lr                = config.lr,
    }
end

function QLearner.new(config)
    local self = setmetatable({}, QLearner)

    self._config       = config
    self._online        = MLP.new(netConfig(config))
    self._target        = MLP.new(netConfig(config))
    self._target:_importWeights(self._online:_exportWeights())

    self._buffer        = table.create(config.memory, nil)
    self._bufferHead     = 0
    self._bufferSize     = 0
    self._epsilon        = config.epsilon
    self._updateEvery    = 50
    self._lessonCount    = 0
    self._lastAction     = nil

    return self
end

function QLearner:_forward(stateVec)
    if math.random() < self._epsilon then
        local action = math.random(1, self._config.actions)
        local dummy  = table.create(self._config.actions, 0)
        dummy[action] = 1
        self._lastAction = action
        return dummy
    else
        local qvals = self._online:_forward(stateVec)
        local maxIdx, maxVal = 1, qvals[1]
        for i = 2, #qvals do
            if qvals[i] > maxVal then
                maxIdx = i
                maxVal = qvals[i]
            end
        end
        self._lastAction = maxIdx
        return qvals
    end
end

function QLearner:_remember(state, action, reward, next, done)
    self._bufferHead = (self._bufferHead % self._config.memory) + 1
    self._buffer[self._bufferHead] = {
        state  = state,
        action = action,
        reward = reward,
        next   = next,
        done   = done,
    }
    self._bufferSize = math.min(self._bufferSize + 1, self._config.memory)
end

function QLearner:_lesson(data, profile)
    local state  = data.state
    local action = data.action
    local next   = data.next
    local done   = data.done

    local reward = data.reward
    if type(reward) == "string" then
        reward = profile._grade_weights[reward]
        assert(reward, "Worm: reward event '" .. data.reward .. "' not found in grade weights")
    end

    if profile._interpreter then
        state = profile._interpreter(state)
        next  = profile._interpreter(next)
    end
    if profile._config.schema then
        state = normalizeSchema(state, profile._config.schema)
        next  = normalizeSchema(next, profile._config.schema)
    end
    state = toVector(state)
    next  = toVector(next)

    self:_remember(state, action, reward, next, done)
    self._lessonCount += 1

    if self._bufferSize < self._config.batch then
        return 0
    end

    local loss = self:_replay(profile)

    self._epsilon = math.max(
        self._config.epsilon_min,
        self._epsilon * self._config.epsilon_decay
    )

    if self._lessonCount % self._updateEvery == 0 then
        self:_syncTarget()
    end

    return loss
end

function QLearner:_replay(profile)
    local batch  = {}
    local taken  = {}
    local bSize  = self._config.batch

    while #batch < bSize do
        local idx = math.random(1, self._bufferSize)
        if not taken[idx] then
            taken[idx] = true
            table.insert(batch, self._buffer[idx])
        end
    end

    local totalLoss = 0

    for _, exp in ipairs(batch) do
        local currentQ = self._online:_forward(exp.state)
        local nextQ    = self._target:_forward(exp.next)

        local maxNextQ = 0
        for _, v in ipairs(nextQ) do
            if v > maxNextQ then maxNextQ = v end
        end

        local targetQ = table.clone(currentQ)
        if exp.done then
            targetQ[exp.action] = exp.reward
        else
            targetQ[exp.action] = exp.reward + self._config.gamma * maxNextQ
        end

        self._online:_forward(exp.state)
        totalLoss += self._online:_backward(targetQ)
    end

    return totalLoss / bSize
end

function QLearner:_syncTarget()
    local weights = self._online:_exportWeights()
    self._target:_importWeights(weights)
end

function QLearner:_exportWeights()
    return {
        online       = self._online:_exportWeights(),
        target       = self._target:_exportWeights(),
        epsilon      = self._epsilon,
        lesson_count = self._lessonCount,
    }
end

function QLearner:_importWeights(data)
    self._online:_importWeights(data.online)
    self._target:_importWeights(data.target)
    self._epsilon     = data.epsilon
    self._lessonCount = data.lesson_count
end

function QLearner:_reset()
    self._online       = MLP.new(netConfig(self._config))
    self._target       = MLP.new(netConfig(self._config))
    self._target:_importWeights(self._online:_exportWeights())
    self._buffer       = table.create(self._config.memory, nil)
    self._bufferHead   = 0
    self._bufferSize   = 0
    self._epsilon      = self._config.epsilon
    self._lessonCount  = 0
end

return QLearner
