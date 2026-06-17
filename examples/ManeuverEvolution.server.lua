-- ManeuverEvolution
-- Run this once (or whenever you want to re-evolve) to discover a
-- maneuver-selection policy via NEAT. Real-time physical sword fights are
-- far too slow to evaluate thousands of genomes against, so this runs the
-- fights through a fast abstract combat simulator -- same move stats as
-- WeaponSystem, but plain numbers instead of real Workspace instances.
--
-- The result is an ordinary Worm Profile (it has a champion genome and
-- labels matching WeaponSystem's move names), so it drops straight into
-- an Ensemble as an inference-only "tech" stance, and gets saved to
-- DataStore so CombatAI doesn't need to re-evolve it on every server boot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")

local Worm = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Worm")
    or ReplicatedStorage:WaitForChild("Worm")
Worm = require(Worm)

local WeaponSystem = require(ReplicatedStorage:WaitForChild("WeaponSystem"))

local MOVE_NAMES   = WeaponSystem.moveNames()
local POPULATION   = 100
local GENERATIONS  = 40
local TICKS        = 60
local TICK_DT      = 0.2
local SAVE_KEY     = "NEATChampion_v1"

local NEATStore = DataStoreService:GetDataStore("WormNEATTech")

local function freshState()
    return {
        hp = 100, stamina = 100, combo = 0,
        cooldowns = {}, lastHitAt = -1e9,
        parryUntil = -1e9, invulnUntil = -1e9, staggeredUntil = -1e9,
    }
end

local function canUse(state, moveName, now)
    local move = WeaponSystem.moveInfo(moveName)
    if not move then
        return false
    end
    if now < state.staggeredUntil then
        return false
    end
    if (state.cooldowns[moveName] or 0) > now then
        return false
    end
    if state.stamina < move.stamina then
        return false
    end
    return true
end

-- Mirrors WeaponSystem:use()'s resolution logic numerically -- same move
-- stats, no real Instances, so the evolved policy stays meaningful once
-- it's later run against the real thing.
local function applyMove(attacker, defender, moveName, now, distance)
    local move = WeaponSystem.moveInfo(moveName)
    attacker.stamina = attacker.stamina - move.stamina
    attacker.cooldowns[moveName] = now + move.cooldown

    if moveName == "parry" then
        attacker.parryUntil = now + move.active
        return distance
    end
    if moveName == "dodge_roll" then
        attacker.invulnUntil = now + move.active
        return math.min(20, distance + 6)
    end
    if moveName == "backstep" then
        return math.min(20, distance + 5)
    end
    if moveName == "feint" then
        return distance
    end

    local newDistance = distance
    if move.dash then
        newDistance = math.max(0, distance - 10)
    end

    if newDistance > move.range then
        attacker.combo = 0
        return newDistance
    end
    if now < defender.invulnUntil then
        attacker.combo = 0
        return newDistance
    end
    if move.parryable and now < defender.parryUntil then
        attacker.staggeredUntil = now + 0.6
        attacker.combo = 0
        return newDistance
    end

    if move.combo and now - attacker.lastHitAt <= 1.2 then
        attacker.combo = attacker.combo + 1
    else
        attacker.combo = move.combo and 1 or 0
    end
    attacker.lastHitAt = now

    local damage = move.damage * (1 + 0.15 * math.min(attacker.combo, 5))
    defender.hp = math.max(0, defender.hp - damage)

    if move.breaks_combo then
        attacker.combo = 0
    end

    return newDistance
end

-- A simple scripted sparring partner: closes distance, attacks in range,
-- occasionally parries -- just skilled enough to make evolution meaningful.
local function opponentMove(state, distance, now)
    if distance > 6 then
        if canUse(state, "dash_attack", now) then
            return "dash_attack"
        end
        return nil
    end
    if math.random() < 0.15 and canUse(state, "parry", now) then
        return "parry"
    end
    if math.random() < 0.2 and canUse(state, "heavy_attack", now) then
        return "heavy_attack"
    end
    if canUse(state, "light_attack", now) then
        return "light_attack"
    end
    return nil
end

local function evaluate(genome)
    local self_ = freshState()
    local enemy = freshState()
    local distance = 20
    local now = 0
    local bestCombo = 0

    for _ = 1, TICKS do
        now = now + TICK_DT
        self_.stamina = math.min(100, self_.stamina + 15 * TICK_DT)
        enemy.stamina = math.min(100, enemy.stamina + 15 * TICK_DT)

        local input = {
            hp            = self_.hp,
            enemy_hp      = enemy.hp,
            distance      = distance,
            stamina       = self_.stamina,
            enemy_stamina = enemy.stamina,
            combo         = self_.combo,
        }

        -- Promise.resolve()'d values settle synchronously (confirmed in
        -- the vendored Promise -- an already-resolved promise's :next()
        -- fires immediately, not deferred), so moveIndex is safe to read
        -- right after this call.
        local moveIndex = 1
        genome:infer(input):next(function(output)
            local maxIdx, maxVal = 1, output[1]
            for i = 2, #output do
                if output[i] > maxVal then
                    maxIdx, maxVal = i, output[i]
                end
            end
            moveIndex = maxIdx
        end)

        local moveName = MOVE_NAMES[moveIndex]
        if canUse(self_, moveName, now) then
            distance = applyMove(self_, enemy, moveName, now, distance)
            bestCombo = math.max(bestCombo, self_.combo)
        end

        local oppMove = opponentMove(enemy, distance, now)
        if oppMove and canUse(enemy, oppMove, now) then
            distance = applyMove(enemy, self_, oppMove, now, distance)
        end

        if self_.hp <= 0 or enemy.hp <= 0 then
            break
        end
    end

    return (100 - enemy.hp) - (100 - self_.hp) + bestCombo * 2
end

local Population = Worm.build(Worm.NEAT, {
    inputs     = 6,
    outputs    = #MOVE_NAMES,
    population = POPULATION,
    persist    = false,
})

Population:labels(MOVE_NAMES)

print(("ManeuverEvolution -- evolving %d generations of %d genomes..."):format(GENERATIONS, POPULATION))

for gen = 1, GENERATIONS do
    Population:lesson({
        evaluate    = evaluate,
        generations = 1,
        on_evolve   = function(g, best)
            if g % 10 == 0 then
                print(("ManeuverEvolution -- gen %d best fitness %.1f"):format(g, best.fitness))
            end
        end,
    })
    task.wait()
end

print("ManeuverEvolution -- done, saving champion to DataStore")

Population:export()
    :next(function(data)
        local ok, err = pcall(function()
            NEATStore:SetAsync(SAVE_KEY, data)
        end)
        if ok then
            print("ManeuverEvolution -- champion saved")
        else
            warn("ManeuverEvolution -- save failed --", err)
        end
    end)
    :toss(function(err)
        warn("ManeuverEvolution -- export failed --", err)
    end)
