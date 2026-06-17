local Players           = game:GetService("Players")
local Workspace          = game:GetService("Workspace")
local CollectionService  = game:GetService("CollectionService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local DataStoreService   = game:GetService("DataStoreService")

local Worm = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Worm")
    or ReplicatedStorage:WaitForChild("Worm")
Worm = require(Worm)

local WeaponSystem = require(ReplicatedStorage:WaitForChild("WeaponSystem"))

local FIGHTER_TAG        = "WormFighter"
local GHOST_TAG          = "WormGhost"
local SWORD_NAME         = "Classic Sword"
local RESPAWN_DELAY      = 2
local DECISION_INTERVAL  = 0.2
local FIGHTER_MAX_HEALTH = 100
local TARGET_MAX_HEALTH  = 100
local DEFAULT_STAMINA    = 50 -- assumed for targets with no WeaponSystem (players, the dummy)
local OPPONENT_EMA_ALPHA = 0.15
local SAVE_KEY           = "Ensemble_v1"
local NEAT_SAVE_KEY      = "NEATChampion_v1"
local SAVE_EVERY_ROUNDS  = 25
local CHECKPOINT_EVERY   = 50
local GHOST_REFRESH_SECS = 90
local LEAGUE_KEEP        = 8

local MOVE_NAMES       = WeaponSystem.moveNames() -- light_attack, heavy_attack, dash_attack, parry, dodge_roll, backstep, feint
local MOVEMENT_ACTIONS = { "approach", "retreat", "circle_strafe" }

local ACTION_LABELS = {}
for _, name in ipairs(MOVE_NAMES) do
    table.insert(ACTION_LABELS, name)
end
for _, name in ipairs(MOVEMENT_ACTIONS) do
    table.insert(ACTION_LABELS, name)
end

local STANCE_NAMES = { "aggressive", "defensive", "neutral" }
local TRAINABLE_STANCES = { aggressive = true, defensive = true, neutral = true }

local Dummy            = Workspace:WaitForChild("Dummy")
local DummyHumanoid    = Dummy:WaitForChild("Humanoid")
local DummyRoot        = Dummy:WaitForChild("HumanoidRootPart")
local dummySpawnCFrame = DummyRoot.CFrame

-- Letting the dummy actually ragdoll on death would leave it unable to
-- take further hits even after its Health is reset -- this keeps the
-- practice target reusable indefinitely.
DummyHumanoid.BreakJointsOnDeath = false

local function getSword(model)
    local tool = model:FindFirstChild(SWORD_NAME)
    if tool then
        return tool
    end

    local template = Dummy:FindFirstChild(SWORD_NAME) or ReplicatedStorage:FindFirstChild(SWORD_NAME)
    assert(template, "CombatAI -- couldn't find a '" .. SWORD_NAME .. "' tool to clone for " .. model.Name)

    tool = template:Clone()
    tool.Parent = model
    return tool
end

local function fireSwing(fighter)
    local attack = fighter.attack
    if attack:IsA("RemoteEvent") then
        attack:FireAllClients()
    elseif attack:IsA("BindableEvent") then
        attack:Fire()
    end
end

local fighters = {}

-- Targets the nearest live player; failing that, the nearest other
-- fighter or sparring ghost (this is what makes self-play happen when
-- no player is around); failing that, the practice dummy.
local function findTarget(fighter)
    local closest, closestDist = nil, math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local humanoid   = character and character:FindFirstChildOfClass("Humanoid")
        local root        = character and character:FindFirstChild("HumanoidRootPart")

        if humanoid and root and humanoid.Health > 0 then
            local dist = (fighter.root.Position - root.Position).Magnitude
            if dist < closestDist then
                closest, closestDist = {
                    humanoid = humanoid, root = root, model = character, isPlayer = true,
                }, dist
            end
        end
    end

    if closest then
        return closest
    end

    for _, other in ipairs(fighters) do
        if other ~= fighter and not other.destroyed and other.humanoid.Health > 0 then
            local dist = (fighter.root.Position - other.root.Position).Magnitude
            if dist < closestDist then
                closest, closestDist = {
                    humanoid = other.humanoid, root = other.root, model = other.model,
                    isPlayer = false, weaponSystem = other.weapon,
                }, dist
            end
        end
    end

    if closest then
        return closest
    end

    return { humanoid = DummyHumanoid, root = DummyRoot, model = Dummy, isPlayer = false }
end

local function moveToward(fighter, point)
    local offset = Vector3.new(point.X - fighter.root.Position.X, 0, point.Z - fighter.root.Position.Z)
    if offset.Magnitude > 0.1 then
        fighter.humanoid:Move(offset.Unit)
    end
end

local MOVEMENT_HANDLERS = {
    approach = function(fighter, target)
        moveToward(fighter, target.root.Position)
    end,
    retreat = function(fighter, target)
        moveToward(fighter, 2 * fighter.root.Position - target.root.Position)
    end,
    -- Strafes perpendicular to the line between fighter and target --
    -- flanking instead of a straight chase or a straight retreat.
    circle_strafe = function(fighter, target)
        local toTarget = target.root.Position - fighter.root.Position
        if toTarget.Magnitude < 0.1 then
            return
        end
        local lateral = Vector3.new(-toTarget.Unit.Z, 0, toTarget.Unit.X)
        moveToward(fighter, fighter.root.Position + lateral * 8)
    end,
}

local MOVE_SET = {}
for _, name in ipairs(MOVE_NAMES) do
    MOVE_SET[name] = true
end

local function performAction(fighter, target, actionName)
    if MOVEMENT_HANDLERS[actionName] then
        fighter.humanoid:Move(Vector3.new())
        MOVEMENT_HANDLERS[actionName](fighter, target)
        return
    end

    if MOVE_SET[actionName] then
        fighter.humanoid:Move(Vector3.new())
        fighter.weapon:use(actionName, {
            humanoid     = target.humanoid,
            root         = target.root,
            weaponSystem = target.weaponSystem,
        }, function()
            fireSwing(fighter)
        end)
    end
end

--------------------------------------------------------------------------
-- Reward shaping -- each stance gets its own personality through different
-- weights on the same vocabulary of events.
--------------------------------------------------------------------------

local AGGRESSIVE_REWARDS = {
    kill = 6, combo_hit = 4, hit_landed = 3, parried_attacker = 1, feint_baited = 1,
    approach_success = 0.6, flank_success = 0.3, idle = -0.1,
    whiffed = -0.3, got_parried = -1, took_damage = -0.6, died = -5,
}
local DEFENSIVE_REWARDS = {
    kill = 5, combo_hit = 2, hit_landed = 1.5, parried_attacker = 4, feint_baited = 3,
    approach_success = 0.2, flank_success = 0.8, idle = 0.1,
    whiffed = -0.2, got_parried = -2, took_damage = -2, died = -7,
}
local NEUTRAL_REWARDS = {
    kill = 6, combo_hit = 3, hit_landed = 2, parried_attacker = 2.5, feint_baited = 1.5,
    approach_success = 0.4, flank_success = 0.6, idle = 0,
    whiffed = -0.4, got_parried = -1.5, took_damage = -1, died = -6,
}
local STANCE_REWARDS = {
    aggressive = AGGRESSIVE_REWARDS,
    defensive  = DEFENSIVE_REWARDS,
    neutral    = NEUTRAL_REWARDS,
}

local SCHEMA = {
    hp                       = { range = { 0, FIGHTER_MAX_HEALTH } },
    target_hp                = { range = { 0, TARGET_MAX_HEALTH  } },
    distance                 = { range = { 0, 60                 } },
    stamina                  = { range = { 0, 100                } },
    target_stamina           = { range = { 0, 100                } },
    combo                    = { range = { 0, 5                  } },
    facing_target            = { range = { -1, 1                 } },
    opponent_aggression      = { range = { 0, 1                  } },
    opponent_approach_trend  = { range = { -10, 10                } },
}

local function buildMemberProfile()
    return Worm.build(Worm.QLEARN, {
        states  = 9,
        actions = #ACTION_LABELS,
        gamma         = 0.95,
        epsilon       = 0.9,
        epsilon_decay = 0.997,
        epsilon_min   = 0.05,
        memory        = 5000,
        batch         = 64,
        schema = SCHEMA,
    })
end

local function buildSelectorProfile()
    return Worm.build(Worm.QLEARN, {
        states  = 9,
        actions = #STANCE_NAMES,
        gamma         = 0.97,
        epsilon       = 0.6,
        epsilon_decay = 0.998,
        epsilon_min   = 0.05,
        memory        = 3000,
        batch         = 32,
        schema = SCHEMA,
    })
end

local EnsembleStore = DataStoreService:GetDataStore("WormCombatEnsemble")
local NEATStore      = DataStoreService:GetDataStore("WormNEATTech")

local function loadTechProfile()
    local ok, data = pcall(function()
        return NEATStore:GetAsync(NEAT_SAVE_KEY)
    end)
    if ok and data then
        print("CombatAI -- loaded evolved NEAT tech stance")
        return Worm.load(data)
    end
    return nil
end

local function freshEnsembleMembers()
    local members = {}
    for _, stance in ipairs(STANCE_NAMES) do
        local member = buildMemberProfile()
        member:labels(ACTION_LABELS)
        member:rewards(STANCE_REWARDS[stance])
        members[stance] = member
    end

    local techProfile = loadTechProfile()
    if techProfile then
        members.tech = techProfile
    end

    local selector = buildSelectorProfile()
    local stanceLabels = { "aggressive", "defensive", "neutral" }
    if techProfile then
        table.insert(stanceLabels, "tech")
    end
    selector:labels(stanceLabels)
    selector:rewards(NEUTRAL_REWARDS)

    return selector, members
end

-- Each saved member/selector is a complete Profile:export() blob, so
-- Worm.load() reconstructs it fully (weights, labels, grade weights) --
-- no need to hand-roll a partial :import() that would have to remember
-- every field export() happened to include.
local function loadEnsemble()
    local ok, data = pcall(function()
        return EnsembleStore:GetAsync(SAVE_KEY)
    end)
    if not (ok and data) then
        return nil
    end

    local selector = Worm.load(data.selector)
    local members  = {}
    for stance, stanceData in pairs(data.members) do
        members[stance] = Worm.load(stanceData)
    end

    local techProfile = loadTechProfile()
    if techProfile then
        members.tech = techProfile
    end

    print("CombatAI -- restored trained ensemble from DataStore")
    return Worm.Ensemble.new({ selector = selector, members = members, default = "neutral" }), selector, members
end

local liveEnsemble, liveSelector, liveMembers = loadEnsemble()
if not liveEnsemble then
    liveSelector, liveMembers = freshEnsembleMembers()
    liveEnsemble = Worm.Ensemble.new({ selector = liveSelector, members = liveMembers, default = "neutral" })
end

local leagues = {
    selector   = Worm.League.new(liveSelector, { keep = LEAGUE_KEEP }),
    aggressive = Worm.League.new(liveMembers.aggressive, { keep = LEAGUE_KEEP }),
    defensive  = Worm.League.new(liveMembers.defensive, { keep = LEAGUE_KEEP }),
    neutral    = Worm.League.new(liveMembers.neutral, { keep = LEAGUE_KEEP }),
}

local function checkpointEnsemble()
    for _, league in pairs(leagues) do
        league:checkpoint()
    end
end

-- export() resolves synchronously in this Promise implementation (an
-- already-settled promise's :next() fires immediately, not deferred),
-- so these all complete in plain sequential order -- no need to count
-- completions to know when every piece has been collected.
local function saveEnsemble()
    local selectorData
    local exportFailed = false

    liveSelector:export()
        :next(function(data) selectorData = data end)
        :toss(function(err)
            warn("CombatAI export --", err)
            exportFailed = true
        end)

    local memberData = {}
    for stance, member in pairs(liveMembers) do
        if stance ~= "tech" then
            member:export()
                :next(function(data) memberData[stance] = data end)
                :toss(function(err)
                    warn("CombatAI export --", err)
                    exportFailed = true
                end)
        end
    end

    if exportFailed or not selectorData then
        return
    end

    local ok, err = pcall(function()
        EnsembleStore:SetAsync(SAVE_KEY, { selector = selectorData, members = memberData })
    end)
    if not ok then
        warn("CombatAI save --", err)
    end
end

-- Builds a frozen Ensemble from a League snapshot, used as a sparring
-- ghost's brain -- a past version of the AI, not a mirror of its
-- current self, so fighting it actually teaches something.
local function buildGhostEnsemble()
    local selectorData = leagues.selector:sample()
    if not selectorData then
        return nil
    end

    local ghostSelector = Worm.load(selectorData)
    local ghostMembers  = {}
    for _, stance in ipairs(STANCE_NAMES) do
        local data = leagues[stance]:sample()
        if data then
            ghostMembers[stance] = Worm.load(data)
        end
    end
    if liveMembers.tech then
        ghostMembers.tech = liveMembers.tech
    end

    return Worm.Ensemble.new({ selector = ghostSelector, members = ghostMembers, default = "neutral" })
end

local function captureRaw(fighter, target)
    local distance  = (fighter.root.Position - target.root.Position).Magnitude
    local look      = fighter.root.CFrame.LookVector
    local toTarget  = target.root.Position - fighter.root.Position
    local facing    = toTarget.Magnitude > 0 and look:Dot(toTarget.Unit) or 0

    return {
        hp                      = fighter.humanoid.Health,
        target_hp               = target.humanoid.Health,
        distance                = distance,
        stamina                 = fighter.weapon.stamina,
        target_stamina          = target.weaponSystem and target.weaponSystem.stamina or DEFAULT_STAMINA,
        combo                   = fighter.weapon.combo,
        facing_target            = facing,
        opponent_aggression       = fighter.oppAggressionEMA,
        opponent_approach_trend    = fighter.oppApproachEMA,
    }
end

-- An approximation -- it conflates "the opponent closed distance" with
-- "I closed distance", since isolating each party's contribution would
-- need tracking the target's own past positions too. Good enough as a
-- coarse read on how hot the fight is.
local function updateOpponentModel(fighter, raw)
    local tookDamage = raw.hp < fighter.prevFighterHP and 1 or 0
    fighter.oppAggressionEMA = fighter.oppAggressionEMA * (1 - OPPONENT_EMA_ALPHA) + tookDamage * OPPONENT_EMA_ALPHA

    if fighter.prevDistance then
        local closingRate = (fighter.prevDistance - raw.distance) / DECISION_INTERVAL
        fighter.oppApproachEMA = fighter.oppApproachEMA * (1 - OPPONENT_EMA_ALPHA) + closingRate * OPPONENT_EMA_ALPHA
    end
    fighter.prevDistance = raw.distance
end

-- Attack moves resolve after a windup delay (see WeaponSystem), so the
-- outcome of an action often isn't known until partway into the *next*
-- decision tick. lastOutcome bridges that gap: WeaponSystem's callbacks
-- set it whenever a swing resolves, and resolveReward consumes it once.
local function resolveReward(fighter, raw)
    if raw.target_hp <= 0 and fighter.prevTargetHP > 0 then
        return "kill"
    end
    if raw.hp <= 0 and fighter.prevFighterHP > 0 then
        return "died"
    end

    local outcome = fighter.lastOutcome
    fighter.lastOutcome = nil
    if outcome then
        return outcome
    end

    if raw.hp < fighter.prevFighterHP then
        return "took_damage"
    end
    if fighter.prevActionName == "approach" and raw.distance <= 6 then
        return "approach_success"
    end
    if fighter.prevActionName == "circle_strafe" and raw.facing_target > 0.5 then
        return "flank_success"
    end
    return "idle"
end

--------------------------------------------------------------------------
-- Turn scheduling -- serializes lesson()/infer() calls per-Ensemble so
-- two fighters sharing the live brain can't race on a member's internal
-- _lastAction.
--------------------------------------------------------------------------

local turnQueues = setmetatable({}, { __mode = "k" })

local function queueFor(ensemble)
    local q = turnQueues[ensemble]
    if not q then
        q = { jobs = {}, busy = false }
        turnQueues[ensemble] = q
    end
    return q
end

local function runNext(q)
    if q.busy then
        return
    end
    local job = table.remove(q.jobs, 1)
    if not job then
        return
    end
    q.busy = true
    job(function()
        q.busy = false
        runNext(q)
    end)
end

local function enqueueTurn(ensemble, job)
    local q = queueFor(ensemble)
    table.insert(q.jobs, job)
    runNext(q)
end

local globalRoundCount = 0

local function attachWeaponCallbacks(fighter)
    local weapon = fighter.weapon

    weapon.onHitLanded = function(_moveName, _target, _damage, comboLevel)
        fighter.lastOutcome = comboLevel >= 2 and "combo_hit" or "hit_landed"
    end
    weapon.onWhiff = function(_moveName)
        fighter.lastOutcome = "whiffed"
    end
    weapon.onHitTaken = function(moveName, _attackerWeapon, _damage)
        fighter.lastOutcome = moveName == "parried" and "got_parried" or "took_damage"
    end
    weapon.onParried = function(_attackerWeapon)
        fighter.lastOutcome = "parried_attacker"
    end
    weapon.onFeintBaited = function()
        fighter.lastOutcome = "feint_baited"
    end
end

-- Health hitting 0 breaks the rig's joints -- resetting Health alone
-- leaves a ragdoll that never moves again, so a real respawn replaces
-- the whole model from a pristine clone taken before any damage.
local function respawnFighter(fighter)
    if fighter.destroyed then
        return
    end

    local fresh = fighter.template:Clone()
    fresh.Name = fighter.model.Name
    fresh:PivotTo(fighter.spawnCFrame)
    fresh.Parent = Workspace

    fighter.model:Destroy()

    fighter.model    = fresh
    fighter.humanoid = fresh:WaitForChild("Humanoid")
    fighter.root     = fresh:WaitForChild("HumanoidRootPart")
    fighter.sword    = getSword(fresh)
    fighter.attack   = fighter.sword:WaitForChild("Attack")
    fighter.humanoid:EquipTool(fighter.sword)

    fighter.weapon = WeaponSystem.new(fresh)
    attachWeaponCallbacks(fighter)

    fighter.target            = findTarget(fighter)
    fighter.prevRaw           = nil
    fighter.prevActionIndex   = nil
    fighter.prevActionName    = nil
    fighter.prevStance        = nil
    fighter.prevSelectorIndex = nil
    fighter.currentActionName = "reset"
    fighter.prevFighterHP     = fighter.humanoid.Health
    fighter.prevTargetHP      = fighter.target.humanoid.Health
    fighter.prevDistance      = nil
    fighter.oppAggressionEMA  = 0
    fighter.oppApproachEMA    = 0
    fighter.lastOutcome       = nil
    fighter.roundOver         = false
    fighter.roundCount       += 1

    if not fighter.target.isPlayer and fighter.target.model == Dummy and DummyHumanoid.Health <= 0 then
        DummyHumanoid.Health = DummyHumanoid.MaxHealth
        DummyRoot.CFrame     = dummySpawnCFrame
    end

    if not fighter.isGhost then
        globalRoundCount += 1
        if globalRoundCount % SAVE_EVERY_ROUNDS == 0 then
            saveEnsemble()
        end
        if globalRoundCount % CHECKPOINT_EVERY == 0 then
            checkpointEnsemble()
        end
    end
end

local function scheduleRespawn(fighter)
    fighter.roundOver = true
    task.delay(RESPAWN_DELAY, function()
        respawnFighter(fighter)
    end)
end

local function reacquireTarget(fighter)
    fighter.target             = findTarget(fighter)
    fighter.prevRaw            = nil
    fighter.prevActionIndex    = nil
    fighter.prevActionName     = nil
    fighter.prevStance         = nil
    fighter.prevSelectorIndex  = nil
    fighter.currentActionName  = "reset"
    fighter.prevFighterHP      = fighter.humanoid.Health
    fighter.prevTargetHP       = fighter.target.humanoid.Health
    fighter.prevDistance       = nil
    fighter.roundOver          = false
end

local function takeTurn(fighter, done)
    local target = fighter.target
    if not target.root.Parent or not target.humanoid.Parent then
        fighter.roundOver = true
        task.delay(RESPAWN_DELAY, function()
            reacquireTarget(fighter)
        end)
        done()
        return
    end

    local raw = captureRaw(fighter, target)
    updateOpponentModel(fighter, raw)

    local isOver = raw.hp <= 0 or raw.target_hp <= 0

    local function decide()
        fighter.ensemble:infer(raw)
            :next(function(result)
                local stance = result.stance
                local member = fighter.ensemble:member(stance)

                fighter.currentActionName = result.action
                performAction(fighter, target, result.action)

                fighter.prevRaw           = raw
                fighter.prevStance        = stance
                fighter.prevActionName    = result.action
                fighter.prevActionIndex   = member._impl and member._impl._lastAction or nil
                fighter.prevSelectorIndex = fighter.ensemble:selector()._impl._lastAction
                fighter.prevFighterHP     = raw.hp
                fighter.prevTargetHP      = raw.target_hp

                done()
            end)
            :toss(function(err)
                warn("CombatAI infer --", err)
                done()
            end)
    end

    if not fighter.trainable then
        if isOver then
            scheduleRespawn(fighter)
            done()
        else
            decide()
        end
        return
    end

    if fighter.prevRaw and fighter.prevStance then
        local reward = resolveReward(fighter, raw)
        local member = fighter.ensemble:member(fighter.prevStance)

        local function afterMemberLesson()
            fighter.ensemble:selectorLesson({
                state  = fighter.prevRaw,
                action = fighter.prevSelectorIndex,
                next   = raw,
                reward = reward,
                done   = isOver,
            })
                :next(function()
                    if isOver then
                        scheduleRespawn(fighter)
                        done()
                    else
                        decide()
                    end
                end)
                :toss(function(err)
                    warn("CombatAI selector lesson --", err)
                    if isOver then
                        scheduleRespawn(fighter)
                        done()
                    else
                        decide()
                    end
                end)
        end

        if TRAINABLE_STANCES[fighter.prevStance] and fighter.prevActionIndex then
            fighter.ensemble:lesson(fighter.prevStance, {
                state  = fighter.prevRaw,
                action = fighter.prevActionIndex,
                next   = raw,
                reward = reward,
                done   = isOver,
            })
                :next(afterMemberLesson)
                :toss(function(err)
                    warn("CombatAI member lesson --", err)
                    afterMemberLesson()
                end)
        else
            afterMemberLesson()
        end
    elseif isOver then
        scheduleRespawn(fighter)
        done()
    else
        decide()
    end
end

local function startFighterLoops(fighter)
    -- Fast loop: keeps movement tracking the target smoothly every frame,
    -- and regenerates stamina every frame regardless of decision cadence.
    task.spawn(function()
        while not fighter.destroyed do
            local dt = task.wait()
            fighter.weapon:update(dt)

            if not fighter.roundOver then
                local target = fighter.target
                if target.root.Parent then
                    local handler = MOVEMENT_HANDLERS[fighter.currentActionName]
                    if handler then
                        handler(fighter, target)
                    end
                end
            end
        end
    end)

    -- Slow loop: deciding a new action every single frame is what made
    -- the original version jitter -- this lets the fast loop above track
    -- the target smoothly between decisions.
    task.spawn(function()
        while not fighter.destroyed do
            if not fighter.roundOver then
                enqueueTurn(fighter.ensemble, function(done)
                    takeTurn(fighter, done)
                end)
            end
            task.wait(DECISION_INTERVAL)
        end
    end)
end

local function registerFighter(model, isGhost)
    local humanoid = model:WaitForChild("Humanoid")
    local root      = model:WaitForChild("HumanoidRootPart")

    local fighter = {
        model              = model,
        humanoid           = humanoid,
        root               = root,
        template           = model:Clone(), -- pristine snapshot, taken before equipping the sword
        spawnCFrame        = root.CFrame,
        currentActionName  = "reset",
        prevRaw            = nil,
        prevStance         = nil,
        prevActionIndex    = nil,
        prevSelectorIndex  = nil,
        prevActionName     = nil,
        prevFighterHP      = humanoid.Health,
        prevTargetHP       = nil,
        prevDistance       = nil,
        oppAggressionEMA   = 0,
        oppApproachEMA     = 0,
        lastOutcome        = nil,
        roundOver          = false,
        roundCount         = 0,
        destroyed          = false,
        isGhost            = isGhost or false,
        trainable          = not isGhost,
        -- Falls back to the live ensemble (inference-only, since
        -- trainable is already false above) when the League doesn't
        -- have a snapshot yet to build a real ghost brain from.
        ensemble           = (isGhost and buildGhostEnsemble()) or liveEnsemble,
    }

    fighter.sword  = getSword(model)
    fighter.attack = fighter.sword:WaitForChild("Attack")
    humanoid:EquipTool(fighter.sword)

    fighter.weapon = WeaponSystem.new(model)
    attachWeaponCallbacks(fighter)

    fighter.target       = findTarget(fighter)
    fighter.prevTargetHP = fighter.target.humanoid.Health

    table.insert(fighters, fighter)
    startFighterLoops(fighter)

    return fighter
end

for _, model in ipairs(CollectionService:GetTagged(FIGHTER_TAG)) do
    registerFighter(model, false)
end

if #fighters == 0 then
    local fallback = Workspace:FindFirstChild("Fighter")
    if fallback then
        CollectionService:AddTag(fallback, FIGHTER_TAG)
        registerFighter(fallback, false)
    end
end

CollectionService:GetInstanceAddedSignal(FIGHTER_TAG):Connect(function(model)
    if model:IsDescendantOf(Workspace) then
        registerFighter(model, false)
    end
end)

CollectionService:GetInstanceRemovedSignal(FIGHTER_TAG):Connect(function(model)
    for _, fighter in ipairs(fighters) do
        if fighter.model == model then
            fighter.destroyed = true
        end
    end
end)

-- One persistent sparring ghost, refreshed periodically from the League
-- so it always represents some past version of the brain rather than a
-- frozen-forever opponent.
local ghostFighter = nil

local function pickGhostTemplate()
    for _, f in ipairs(fighters) do
        if not f.isGhost and not f.destroyed then
            return f.template
        end
    end
    return Workspace:FindFirstChild("Fighter")
end

local function refreshGhost()
    local template = pickGhostTemplate()
    if not template then
        return
    end

    if ghostFighter then
        ghostFighter.destroyed = true
        ghostFighter.model:Destroy()
    end

    local ghostModel = template:Clone()
    ghostModel.Name = "Fighter_Ghost"
    ghostModel.Parent = Workspace
    CollectionService:AddTag(ghostModel, GHOST_TAG)

    ghostFighter = registerFighter(ghostModel, true)
end

task.spawn(function()
    while true do
        if leagues.selector:size() > 0 then
            refreshGhost()
        end
        task.wait(GHOST_REFRESH_SECS)
    end
end)

game:BindToClose(function()
    saveEnsemble()
    task.wait(2)
end)
