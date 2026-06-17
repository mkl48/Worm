local Players           = game:GetService("Players")
local Workspace          = game:GetService("Workspace")
local CollectionService  = game:GetService("CollectionService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local DataStoreService   = game:GetService("DataStoreService")

local Worm = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Worm")
    or ReplicatedStorage:WaitForChild("Worm")
Worm = require(Worm)

local FIGHTER_TAG        = "WormFighter"
local SWORD_NAME         = "Classic Sword"
local ATTACK_RANGE       = 6
local ATTACK_DAMAGE      = 12
local ATTACK_COOLDOWN    = 1
local APPROACH_SPEED     = 1
local RESPAWN_DELAY      = 2
local DECISION_INTERVAL  = 0.2
local FIGHTER_MAX_HEALTH = 100
local TARGET_MAX_HEALTH  = 100
local SAVE_KEY           = "Fighter_v1"
local SAVE_EVERY_ROUNDS  = 25

local Dummy          = Workspace:WaitForChild("Dummy")
local DummyHumanoid  = Dummy:WaitForChild("Humanoid")
local DummyRoot      = Dummy:WaitForChild("HumanoidRootPart")
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

-- Picks the nearest live player to fight; falls back to the practice
-- dummy when no player is around to train against.
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
                    humanoid = humanoid,
                    root     = root,
                    model    = character,
                    isPlayer = true,
                }, dist
            end
        end
    end

    if closest then
        return closest
    end

    return { humanoid = DummyHumanoid, root = DummyRoot, model = Dummy, isPlayer = false }
end

-- Plays the swing and resolves the hit locally -- the Attack remote only
-- replicates the animation/sound, it doesn't tell us whether we connected.
local function tryAttack(fighter, target)
    local now = os.clock()
    if now - fighter.lastAttackTime < ATTACK_COOLDOWN then
        return false
    end
    fighter.lastAttackTime = now
    fireSwing(fighter)

    local distance = (fighter.root.Position - target.root.Position).Magnitude
    if distance <= ATTACK_RANGE and target.humanoid.Health > 0 then
        target.humanoid:TakeDamage(ATTACK_DAMAGE)
        return true
    end
    return false
end

local function moveToward(fighter, point)
    local offset = Vector3.new(point.X - fighter.root.Position.X, 0, point.Z - fighter.root.Position.Z)
    if offset.Magnitude > 0.1 then
        fighter.humanoid:Move(offset.Unit * APPROACH_SPEED)
    end
end

local ACTION_LABELS = { "attack", "approach", "retreat", "reset" }

local ACTION_HANDLERS = {
    attack = function(fighter, target)
        fighter.humanoid:Move(Vector3.new())
        fighter.lastAttackOutcome = tryAttack(fighter, target) and "hit" or "whiff"
    end,
    approach = function(fighter, target)
        moveToward(fighter, target.root.Position)
    end,
    retreat = function(fighter, target)
        moveToward(fighter, 2 * fighter.root.Position - target.root.Position)
    end,
    reset = function(fighter, _target)
        fighter.humanoid:Move(Vector3.new())
    end,
}

local CombatStore = DataStoreService:GetDataStore("WormCombatAI")

local function loadCombatAI()
    local ok, data = pcall(function()
        return CombatStore:GetAsync(SAVE_KEY)
    end)
    if ok and data then
        print("CombatAI -- restored trained profile from DataStore")
        return Worm.load(data)
    end
    return nil
end

local CombatAI = loadCombatAI() or Worm.build(Worm.QLEARN, {
    states  = 5,
    actions = #ACTION_LABELS,
    gamma         = 0.95,
    epsilon       = 0.9,
    epsilon_decay = 0.997,
    epsilon_min   = 0.05,
    memory        = 5000,
    batch         = 64,
    schema = {
        hp            = { range = { 0, FIGHTER_MAX_HEALTH } },
        target_hp     = { range = { 0, TARGET_MAX_HEALTH  } },
        distance      = { range = { 0, 60                 } },
        on_cooldown   = { range = { 0, 1                  } },
        facing_target = { range = { 0, 1                  } },
    }
})

-- Restoring grade_resolved through import() already brings these back;
-- calling rewards() again is harmless and keeps a fresh build in sync.
CombatAI:rewards({
    kill             = 5,
    hit_landed       = 2,
    approach_success = 0.5,
    idle             = 0,
    whiffed          = -0.5,
    took_damage      = -1,
    died             = -5,
})

local function saveCombatAI()
    CombatAI:export()
        :next(function(data)
            local ok, err = pcall(function()
                CombatStore:SetAsync(SAVE_KEY, data)
            end)
            if not ok then
                warn("CombatAI save --", err)
            end
        end)
        :toss(function(err)
            warn("CombatAI export --", err)
        end)
end

local function captureRaw(fighter, target)
    local distance  = (fighter.root.Position - target.root.Position).Magnitude
    local look      = fighter.root.CFrame.LookVector
    local toTarget  = (target.root.Position - fighter.root.Position)
    local facing    = toTarget.Magnitude > 0 and look:Dot(toTarget.Unit) or 0

    return {
        hp            = fighter.humanoid.Health,
        target_hp     = target.humanoid.Health,
        distance      = distance,
        on_cooldown   = (os.clock() - fighter.lastAttackTime < ATTACK_COOLDOWN) and 1 or 0,
        facing_target = facing > 0 and 1 or 0,
    }
end

local function resolveReward(fighter, raw)
    if raw.target_hp <= 0 and fighter.prevTargetHP > 0 then
        return "kill"
    end
    if raw.hp <= 0 and fighter.prevFighterHP > 0 then
        return "died"
    end
    if fighter.prevActionName == "attack" then
        return fighter.lastAttackOutcome == "hit" and "hit_landed" or "whiffed"
    end
    if raw.hp < fighter.prevFighterHP then
        return "took_damage"
    end
    if fighter.prevActionName == "approach" and raw.distance <= ATTACK_RANGE then
        return "approach_success"
    end
    return "idle"
end

-- All fighters share one QLearner, so two fighters deciding at once
-- would race on its internal _lastAction -- this serializes each
-- fighter's lesson+infer step so only one is ever in flight.
local turnQueue = {}
local turnBusy  = false

local function runNextTurn()
    if turnBusy then
        return
    end
    local job = table.remove(turnQueue, 1)
    if not job then
        return
    end
    turnBusy = true
    job(function()
        turnBusy = false
        runNextTurn()
    end)
end

local function enqueueTurn(job)
    table.insert(turnQueue, job)
    runNextTurn()
end

local globalRoundCount = 0

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

    fighter.target            = findTarget(fighter)
    fighter.prevRaw           = nil
    fighter.prevActionIndex   = nil
    fighter.prevActionName    = nil
    fighter.currentActionName = "reset"
    fighter.prevFighterHP     = fighter.humanoid.Health
    fighter.prevTargetHP      = fighter.target.humanoid.Health
    fighter.lastAttackTime    = 0
    fighter.lastAttackOutcome = nil
    fighter.roundOver         = false
    fighter.roundCount       += 1

    if not fighter.target.isPlayer and fighter.target.model == Dummy and DummyHumanoid.Health <= 0 then
        DummyHumanoid.Health = DummyHumanoid.MaxHealth
        DummyRoot.CFrame     = dummySpawnCFrame
    end

    globalRoundCount += 1
    if globalRoundCount % SAVE_EVERY_ROUNDS == 0 then
        saveCombatAI()
    end
end

local function scheduleRespawn(fighter)
    fighter.roundOver = true
    task.delay(RESPAWN_DELAY, function()
        respawnFighter(fighter)
    end)
end

-- The target left or despawned, but the fighter itself is fine -- just
-- pick a new target instead of destroying/recloning a perfectly alive model.
local function reacquireTarget(fighter)
    fighter.target             = findTarget(fighter)
    fighter.prevRaw            = nil
    fighter.prevActionIndex    = nil
    fighter.prevActionName     = nil
    fighter.currentActionName  = "reset"
    fighter.prevFighterHP      = fighter.humanoid.Health
    fighter.prevTargetHP       = fighter.target.humanoid.Health
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

    local function decide()
        CombatAI:infer(raw)
            :next(function()
                -- QLearner resolves the actual epsilon-greedy/argmax choice
                -- internally; pull it back out so lesson() trains the index
                -- it really picked, not a label round-tripped through text.
                local actionIndex = CombatAI._impl._lastAction
                local actionName  = ACTION_LABELS[actionIndex]

                fighter.currentActionName = actionName
                ACTION_HANDLERS[actionName](fighter, target)

                fighter.prevRaw         = raw
                fighter.prevActionIndex = actionIndex
                fighter.prevActionName  = actionName
                fighter.prevFighterHP   = raw.hp
                fighter.prevTargetHP    = raw.target_hp

                done()
            end)
            :toss(function(err)
                warn("CombatAI infer --", err)
                done()
            end)
    end

    local isOver = raw.hp <= 0 or raw.target_hp <= 0

    if fighter.prevRaw and fighter.prevActionIndex then
        CombatAI:lesson({
            state  = fighter.prevRaw,
            action = fighter.prevActionIndex,
            next   = raw,
            reward = resolveReward(fighter, raw),
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
                warn("CombatAI lesson --", err)
                if isOver then
                    scheduleRespawn(fighter)
                    done()
                else
                    decide()
                end
            end)
    elseif isOver then
        scheduleRespawn(fighter)
        done()
    else
        decide()
    end
end

local function startFighterLoops(fighter)
    -- Fast loop: keeps movement tracking the target smoothly every frame.
    task.spawn(function()
        while not fighter.destroyed do
            if not fighter.roundOver then
                local target = fighter.target
                if target.root.Parent then
                    if fighter.currentActionName == "approach" then
                        moveToward(fighter, target.root.Position)
                    elseif fighter.currentActionName == "retreat" then
                        moveToward(fighter, 2 * fighter.root.Position - target.root.Position)
                    end
                end
            end
            task.wait()
        end
    end)

    -- Slow loop: this is what was causing the jitter -- deciding a new
    -- action every single frame made the humanoid flip directions 60
    -- times a second. Deciding every DECISION_INTERVAL instead lets the
    -- fast loop above track the target smoothly in between.
    task.spawn(function()
        while not fighter.destroyed do
            if not fighter.roundOver then
                enqueueTurn(function(done)
                    takeTurn(fighter, done)
                end)
            end
            task.wait(DECISION_INTERVAL)
        end
    end)
end

local fighters = {}

local function registerFighter(model)
    local humanoid = model:WaitForChild("Humanoid")
    local root      = model:WaitForChild("HumanoidRootPart")

    local fighter = {
        model              = model,
        humanoid           = humanoid,
        root               = root,
        template           = model:Clone(), -- pristine snapshot, taken before equipping the sword
        spawnCFrame        = root.CFrame,
        lastAttackTime     = 0,
        lastAttackOutcome  = nil,
        currentActionName  = "reset",
        prevRaw            = nil,
        prevActionIndex    = nil,
        prevActionName     = nil,
        prevFighterHP      = humanoid.Health,
        prevTargetHP       = nil,
        roundOver          = false,
        roundCount         = 0,
        destroyed          = false,
    }

    fighter.sword  = getSword(model)
    fighter.attack = fighter.sword:WaitForChild("Attack")
    humanoid:EquipTool(fighter.sword)

    fighter.target       = findTarget(fighter)
    fighter.prevTargetHP = fighter.target.humanoid.Health

    table.insert(fighters, fighter)
    startFighterLoops(fighter)

    return fighter
end

for _, model in ipairs(CollectionService:GetTagged(FIGHTER_TAG)) do
    registerFighter(model)
end

if #fighters == 0 then
    local fallback = Workspace:FindFirstChild("Fighter")
    if fallback then
        CollectionService:AddTag(fallback, FIGHTER_TAG)
        registerFighter(fallback)
    end
end

CollectionService:GetInstanceAddedSignal(FIGHTER_TAG):Connect(function(model)
    if model:IsDescendantOf(Workspace) then
        registerFighter(model)
    end
end)

CollectionService:GetInstanceRemovedSignal(FIGHTER_TAG):Connect(function(model)
    for _, fighter in ipairs(fighters) do
        if fighter.model == model then
            fighter.destroyed = true
        end
    end
end)

game:BindToClose(function()
    saveCombatAI()
    task.wait(2)
end)
