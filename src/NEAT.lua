local Activations = require(script.Parent.Activations)
local Promise      = require(script.Parent.Promise)
local Util         = require(script.Parent.Util)

local toVector        = Util.toVector
local normalizeSchema = Util.normalizeSchema
local topologicalSort = Util.topologicalSort

local NEAT = {}
NEAT.__index = NEAT

local function newGenome()
    return { nodes = {}, connections = {}, fitness = 0, species_id = nil }
end

function NEAT.new(config)
    local self = setmetatable({}, NEAT)

    self._config      = config
    self._innovation   = 0
    self._innovations  = {}
    self._generation    = 0
    self._champion       = nil
    self._species         = {}
    self._population       = {}

    for _ = 1, config.population do
        table.insert(self._population, self:_createInitialGenome())
    end

    return self
end

function NEAT:_createInitialGenome()
    local genome = newGenome()

    for i = 1, self._config.inputs do
        genome.nodes[i] = { type = "input", id = i }
    end

    local outputStart = self._config.inputs + 1
    for o = 1, self._config.outputs do
        local id = outputStart + o - 1
        genome.nodes[id] = { type = "output", id = id }
    end

    for i = 1, self._config.inputs do
        for o = 1, self._config.outputs do
            local outId = outputStart + o - 1
            local innov = self:_getInnovation(i, outId)
            genome.connections[innov] = {
                in_        = i,
                out        = outId,
                weight     = (math.random() * 2 - 1) * 2,
                enabled    = true,
                innovation = innov,
            }
        end
    end

    return genome
end

function NEAT:_cloneGenome(genome)
    local clone = newGenome()
    clone.fitness = genome.fitness

    for id, node in pairs(genome.nodes) do
        clone.nodes[id] = { type = node.type, id = node.id }
    end
    for innov, conn in pairs(genome.connections) do
        clone.connections[innov] = {
            in_        = conn.in_,
            out        = conn.out,
            weight     = conn.weight,
            enabled    = conn.enabled,
            innovation = conn.innovation,
        }
    end

    return clone
end

function NEAT:_getInnovation(inNode, outNode)
    local key = inNode .. "_" .. outNode
    if not self._innovations[key] then
        self._innovation += 1
        self._innovations[key] = self._innovation
    end
    return self._innovations[key]
end

function NEAT:_compatibility(g1, g2)
    local matching, disjoint, excess = 0, 0, 0
    local weightDiff = 0
    local maxInnov1, maxInnov2 = 0, 0

    for innov in pairs(g1.connections) do
        if innov > maxInnov1 then maxInnov1 = innov end
    end
    for innov in pairs(g2.connections) do
        if innov > maxInnov2 then maxInnov2 = innov end
    end

    local maxShared = math.min(maxInnov1, maxInnov2)

    for innov, conn in pairs(g1.connections) do
        if g2.connections[innov] then
            matching  += 1
            weightDiff += math.abs(conn.weight - g2.connections[innov].weight)
        elseif innov <= maxShared then
            disjoint += 1
        else
            excess += 1
        end
    end

    for innov in pairs(g2.connections) do
        if not g1.connections[innov] then
            if innov <= maxShared then
                disjoint += 1
            else
                excess += 1
            end
        end
    end

    local N    = math.max(#g1.connections, #g2.connections, 1)
    local avgW = matching > 0 and weightDiff / matching or 0

    return (1.0 * excess / N) + (1.0 * disjoint / N) + (0.4 * avgW)
end

function NEAT:_crossover(g1, g2)
    local fitter   = g1.fitness >= g2.fitness and g1 or g2
    local weaker   = fitter == g1 and g2 or g1
    local child    = newGenome()

    for id, node in pairs(fitter.nodes) do
        child.nodes[id] = { type = node.type, id = node.id }
    end

    for innov, conn in pairs(fitter.connections) do
        if weaker.connections[innov] and math.random() < 0.5 then
            child.connections[innov] = {
                in_        = conn.in_,
                out        = conn.out,
                weight     = weaker.connections[innov].weight,
                enabled    = conn.enabled and weaker.connections[innov].enabled,
                innovation = innov,
            }
        else
            child.connections[innov] = {
                in_        = conn.in_,
                out        = conn.out,
                weight     = conn.weight,
                enabled    = conn.enabled,
                innovation = innov,
            }
        end
    end

    return child
end

function NEAT:_mutateWeights(genome)
    for _, conn in pairs(genome.connections) do
        if math.random() < self._config.weight_mutation then
            if math.random() < self._config.weight_perturb then
                conn.weight += (math.random() * 2 - 1) * 0.5
            else
                conn.weight = (math.random() * 2 - 1) * 2
            end
        end
    end
end

function NEAT:_mutateAddConnection(genome)
    local nodeIds = {}
    for id in pairs(genome.nodes) do table.insert(nodeIds, id) end
    local inNode  = nodeIds[math.random(#nodeIds)]
    local outNode = nodeIds[math.random(#nodeIds)]
    if inNode == outNode then return end

    local innov = self:_getInnovation(inNode, outNode)
    if genome.connections[innov] then return end

    genome.connections[innov] = {
        in_        = inNode,
        out        = outNode,
        weight     = (math.random() * 2 - 1) * 2,
        enabled    = true,
        innovation = innov,
    }
end

function NEAT:_mutateAddNode(genome)
    local connList = {}
    for _, c in pairs(genome.connections) do
        if c.enabled then table.insert(connList, c) end
    end
    if #connList == 0 then return end

    local conn    = connList[math.random(#connList)]
    conn.enabled  = false

    local newId   = #genome.nodes + 1
    genome.nodes[newId] = { type = "hidden", id = newId }

    local innov1 = self:_getInnovation(conn.in_, newId)
    local innov2 = self:_getInnovation(newId, conn.out)

    genome.connections[innov1] = {
        in_ = conn.in_, out = newId,
        weight = 1, enabled = true, innovation = innov1,
    }
    genome.connections[innov2] = {
        in_ = newId, out = conn.out,
        weight = conn.weight, enabled = true, innovation = innov2,
    }
end

function NEAT:_genomeForward(genome, input)
    local values = {}
    for i, v in ipairs(input) do
        values[i] = v
    end

    local outputStart = #input + 1
    local outputEnd   = outputStart + self._config.outputs - 1

    local sortedConns = topologicalSort(genome)

    for _, conn in ipairs(sortedConns) do
        if conn.enabled then
            values[conn.out] = (values[conn.out] or 0) + values[conn.in_] * conn.weight
        end
    end

    local result = {}
    for i = outputStart, outputEnd do
        result[i - outputStart + 1] = Activations.sigmoid(values[i] or 0)
    end
    return result
end

function NEAT:_speciate()
    local species = {}
    for _, genome in ipairs(self._population) do
        local placed = false
        for _, sp in ipairs(species) do
            if self:_compatibility(genome, sp.representative) < self._config.species_threshold then
                table.insert(sp.members, genome)
                genome.species_id = sp.id
                placed = true
                break
            end
        end
        if not placed then
            local id = #species + 1
            table.insert(species, { id = id, representative = genome, members = { genome } })
            genome.species_id = id
        end
    end
    self._species = species
end

function NEAT:_fitnessShare()
    for _, sp in ipairs(self._species) do
        local total = 0
        for _, g in ipairs(sp.members) do
            total += g.fitness
        end
        sp.avgFitness = total / #sp.members
    end
end

function NEAT:_findChampion()
    local best = self._population[1]
    for _, g in ipairs(self._population) do
        if g.fitness > best.fitness then
            best = g
        end
    end
    return best
end

function NEAT:_reproduce()
    local totalAvg = 0
    for _, sp in ipairs(self._species) do
        totalAvg += sp.avgFitness
    end
    if totalAvg <= 0 then totalAvg = 1 end

    local popSize       = self._config.population
    local newPopulation = {}

    if self._champion then
        table.insert(newPopulation, self:_cloneGenome(self._champion))
    end

    for _, sp in ipairs(self._species) do
        local share          = sp.avgFitness / totalAvg
        local offspringCount = math.max(1, math.floor(share * popSize))

        for _ = 1, offspringCount do
            if #newPopulation >= popSize then break end

            local parent1 = sp.members[math.random(#sp.members)]
            local parent2 = sp.members[math.random(#sp.members)]
            local child

            if #sp.members > 1 and math.random() < self._config.crossover_rate then
                child = self:_crossover(parent1, parent2)
            else
                child = self:_cloneGenome(parent1)
            end

            if math.random() < self._config.mutation_rate then
                self:_mutateWeights(child)
                if math.random() < 0.05 then
                    self:_mutateAddConnection(child)
                end
                if math.random() < 0.03 then
                    self:_mutateAddNode(child)
                end
            end

            child.fitness = 0
            table.insert(newPopulation, child)
        end
    end

    while #newPopulation < popSize do
        local parent = self._population[math.random(#self._population)]
        table.insert(newPopulation, self:_cloneGenome(parent))
    end

    while #newPopulation > popSize do
        table.remove(newPopulation)
    end

    self._population = newPopulation
end

function NEAT:_lesson(data, profile)
    local gens      = data.generations or 1
    local evaluate  = data.evaluate
    local on_evolve = data.on_evolve

    local best

    for g = 1, gens do
        for _, genome in ipairs(self._population) do
            local genomeProfile = self:_wrapGenome(genome, profile)
            genome.fitness = evaluate(genomeProfile)
        end

        self:_speciate()
        self:_fitnessShare()

        best = self:_findChampion()
        self._champion = best

        if on_evolve then
            on_evolve(self._generation, {
                fitness = best.fitness,
                genome  = self:_wrapGenome(best, profile),
            })
        end

        self:_reproduce()
        self._generation += 1
    end

    return self:_wrapGenome(best, profile)
end

function NEAT:_wrapGenome(genome, profile)
    return {
        infer = function(_, input)
            local prepared = input
            if profile._interpreter then
                prepared = profile._interpreter(input)
            end
            if profile._config.schema then
                prepared = normalizeSchema(prepared, profile._config.schema)
            end
            local vec = toVector(prepared)
            return Promise.resolve(self:_genomeForward(genome, vec))
        end,
        export = function()
            return { genome = genome, config = profile._config }
        end,
        fitness = genome.fitness,
    }
end

function NEAT:_forward(vec)
    assert(self._champion, "Worm: no champion yet -- run lesson() first")
    return self:_genomeForward(self._champion, vec)
end

function NEAT:evolve(profile)
    return Promise.new(function(resolve)
        self:_speciate()
        self:_fitnessShare()
        self:_reproduce()
        self._generation += 1
        resolve({
            generation    = self._generation,
            best_fitness  = self._champion and self._champion.fitness or 0,
            species_count = #self._species,
        })
    end)
end

function NEAT:champion(profile)
    assert(self._champion, "Worm: no champion yet -- run lesson() first")
    return self:_wrapGenome(self._champion, profile)
end

function NEAT:_exportWeights()
    if self._config.persist then
        return {
            neat_population = self._population,
            innovation      = self._innovation,
            innovations     = self._innovations,
            generation      = self._generation,
            champion        = self._champion,
        }
    else
        return {
            champion   = self._champion,
            generation = self._generation,
        }
    end
end

function NEAT:_importWeights(data)
    self._champion   = data.champion
    self._generation = data.generation or 0
    if data.neat_population then
        self._population = data.neat_population
    end
    if data.innovation then
        self._innovation  = data.innovation
        self._innovations = data.innovations or {}
    end
end

function NEAT:_reset()
    self._innovation  = 0
    self._innovations = {}
    self._generation  = 0
    self._champion     = nil
    self._species       = {}
    self._population     = {}
    for _ = 1, self._config.population do
        table.insert(self._population, self:_createInitialGenome())
    end
end

return NEAT
