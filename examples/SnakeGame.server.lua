-- SnakeGame
-- A classic grid Snake game, fully self-contained -- it builds its own
-- floor, walls, and scoreboard at runtime, so the only prerequisite is
-- Worm itself under ReplicatedStorage.
--
-- Runs NUM_BOARDS independent boards in parallel, all training one
-- shared Worm QLearner -- more boards means more experience per second,
-- so it learns far faster wall-clock than a single board would.
--
-- Speed is live-tunable: change the TickInterval (and ResetDelay)
-- Attribute on Workspace.SnakeGame in the Properties panel while the
-- game is running -- no script edits or restarts needed.

local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")

local Worm = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Worm")
    or ReplicatedStorage:WaitForChild("Worm")
Worm = require(Worm)

local NUM_BOARDS              = 4
local GRID_SIZE                = 16
local CELL_SIZE                 = 4
local BOARD_GAP                  = 12
local FLOOR_Y                     = 0
local DEFAULT_TICK_INTERVAL        = 0.15
local DEFAULT_RESET_DELAY           = 1
local SAVE_KEY                       = "Snake_v1"
local SAVE_EVERY_EPISODES             = 20

-- Reward shaping -- a number is passed straight into lesson() instead
-- of a named event, so survival and food-seeking shaping can stack in
-- the same tick rather than competing for a single event slot.
local ATE_REWARD     = 25
local DIED_REWARD    = -20
local CLOSER_REWARD  = 0.3
local FARTHER_REWARD = -0.3
local SURVIVE_REWARD = 0.05 -- for not crashing into the wall or itself this tick

local HEAD_COLOR = Color3.fromRGB(60, 200, 90)
local BODY_COLOR = Color3.fromRGB(40, 150, 70)
local FOOD_COLOR = Color3.fromRGB(220, 60, 60)
local DEAD_COLOR = Color3.fromRGB(180, 40, 40)

local DIRS = {
    up    = { dx = 0,  dz = -1 },
    down  = { dx = 0,  dz = 1  },
    left  = { dx = -1, dz = 0  },
    right = { dx = 1,  dz = 0  },
}
local ACTION_LABELS = { "up", "down", "left", "right" }

local boardSize = GRID_SIZE * CELL_SIZE

--------------------------------------------------------------------------
-- World setup -- builds every board entirely from Instance.new(), no
-- prerequisites in the place beyond Worm being installed.
--------------------------------------------------------------------------

local function buildBoardWorld(parent, index, origin)
    local root = Instance.new("Folder")
    root.Name = "Board" .. index
    root.Parent = parent

    local floor = Instance.new("Part")
    floor.Name = "Floor"
    floor.Size = Vector3.new(boardSize, 1, boardSize)
    floor.Position = origin + Vector3.new(boardSize / 2, FLOOR_Y - 0.5, boardSize / 2)
    floor.Anchored = true
    floor.Color = Color3.fromRGB(40, 40, 45)
    floor.Parent = root

    local wallHeight = 3
    local wallThickness = 1
    local wallSpecs = {
        { size = Vector3.new(boardSize + 2, wallHeight, wallThickness), pos = Vector3.new(boardSize / 2, wallHeight / 2, -wallThickness / 2) },
        { size = Vector3.new(boardSize + 2, wallHeight, wallThickness), pos = Vector3.new(boardSize / 2, wallHeight / 2, boardSize + wallThickness / 2) },
        { size = Vector3.new(wallThickness, wallHeight, boardSize + 2), pos = Vector3.new(-wallThickness / 2, wallHeight / 2, boardSize / 2) },
        { size = Vector3.new(wallThickness, wallHeight, boardSize + 2), pos = Vector3.new(boardSize + wallThickness / 2, wallHeight / 2, boardSize / 2) },
    }
    for i, spec in ipairs(wallSpecs) do
        local wall = Instance.new("Part")
        wall.Name = "Wall" .. i
        wall.Size = spec.size
        wall.Position = origin + spec.pos
        wall.Anchored = true
        wall.Color = Color3.fromRGB(80, 80, 90)
        wall.Parent = root
    end

    local segmentsFolder = Instance.new("Folder")
    segmentsFolder.Name = "Segments"
    segmentsFolder.Parent = root

    local food = Instance.new("Part")
    food.Name = "Food"
    food.Shape = Enum.PartType.Ball
    food.Size = Vector3.new(CELL_SIZE * 0.6, CELL_SIZE * 0.6, CELL_SIZE * 0.6)
    food.Anchored = true
    food.CanCollide = false
    food.Color = FOOD_COLOR
    food.Parent = root

    local scoreboard = Instance.new("Part")
    scoreboard.Name = "Scoreboard"
    scoreboard.Size = Vector3.new(boardSize * 0.8, boardSize * 0.25, 0.5)
    scoreboard.Position = origin + Vector3.new(boardSize / 2, boardSize * 0.35, boardSize / 2)
    scoreboard.Anchored = true
    scoreboard.CanCollide = false
    scoreboard.Transparency = 1
    scoreboard.Parent = root

    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.LightInfluence = 0
    gui.Parent = scoreboard

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Code
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Text = "Score: 0  Best: 0  Episode: 0"
    label.Parent = gui

    return root, segmentsFolder, food, label
end

local configRoot = Workspace:FindFirstChild("SnakeGame")
if configRoot then
    configRoot:Destroy()
end
configRoot = Instance.new("Folder")
configRoot.Name = "SnakeGame"
configRoot:SetAttribute("TickInterval", DEFAULT_TICK_INTERVAL)
configRoot:SetAttribute("ResetDelay", DEFAULT_RESET_DELAY)
configRoot.Parent = Workspace

local function getTickInterval()
    return configRoot:GetAttribute("TickInterval") or DEFAULT_TICK_INTERVAL
end

local function getResetDelay()
    return configRoot:GetAttribute("ResetDelay") or DEFAULT_RESET_DELAY
end

local function cellToWorld(origin, gx, gz)
    return origin + Vector3.new((gx - 0.5) * CELL_SIZE, FLOOR_Y + CELL_SIZE / 2, (gz - 0.5) * CELL_SIZE)
end

local function inBounds(gx, gz)
    return gx >= 1 and gx <= GRID_SIZE and gz >= 1 and gz <= GRID_SIZE
end

--------------------------------------------------------------------------
-- Shared AI -- danger/direction/food flags in 4 absolute directions,
-- one of up/down/left/right out. Every board feeds and trains this
-- same profile, so more boards means more experience per second.
--------------------------------------------------------------------------

local SCHEMA = {}
for _, name in ipairs({
    "danger_up", "danger_down", "danger_left", "danger_right",
    "dir_up", "dir_down", "dir_left", "dir_right",
    "food_up", "food_down", "food_left", "food_right",
}) do
    SCHEMA[name] = { range = { 0, 1 } }
end

local SnakeStore = DataStoreService:GetDataStore("WormSnakeAI")

local function loadSnakeAI()
    local ok, data = pcall(function()
        return SnakeStore:GetAsync(SAVE_KEY)
    end)
    if ok and data then
        print("SnakeGame -- restored trained AI from DataStore")
        return Worm.load(data)
    end
    return nil
end

local SnakeAI = loadSnakeAI() or Worm.build(Worm.QLEARN, {
    states  = 12,
    actions = #ACTION_LABELS,
    gamma         = 0.9,
    epsilon       = 1.0,
    epsilon_decay = 0.998,
    epsilon_min   = 0.02,
    memory        = 8000,
    batch         = 64,
    schema = SCHEMA,
})

SnakeAI:labels(ACTION_LABELS)

local function saveSnakeAI()
    SnakeAI:export()
        :next(function(data)
            local ok, err = pcall(function()
                SnakeStore:SetAsync(SAVE_KEY, data)
            end)
            if not ok then
                warn("SnakeGame save --", err)
            end
        end)
        :toss(function(err)
            warn("SnakeGame export --", err)
        end)
end

local function manhattan(gx1, gz1, gx2, gz2)
    return math.abs(gx1 - gx2) + math.abs(gz1 - gz2)
end

local function resolveReward(ate, died, prevDist, newDist)
    if died then
        return DIED_REWARD
    end
    if ate then
        return ATE_REWARD
    end

    local shaping = 0
    if newDist < prevDist then
        shaping = CLOSER_REWARD
    elseif newDist > prevDist then
        shaping = FARTHER_REWARD
    end

    return SURVIVE_REWARD + shaping
end

--------------------------------------------------------------------------
-- Per-board state + logic
--------------------------------------------------------------------------

local boards = {}
local globalEpisodeCount = 0

local function makeSegmentPart(board)
    local part = Instance.new("Part")
    part.Size = Vector3.new(CELL_SIZE * 0.9, CELL_SIZE * 0.9, CELL_SIZE * 0.9)
    part.Anchored = true
    part.CanCollide = false
    part.Parent = board.segmentsFolder
    return part
end

local function isOccupiedBySnake(board, gx, gz, excludeTail)
    local segs = board.snake.segments
    local limit = excludeTail and (#segs - 1) or #segs
    for i = 1, limit do
        local s = segs[i]
        if s.gx == gx and s.gz == gz then
            return true
        end
    end
    return false
end

local function spawnFood(board)
    local attempts = 0
    repeat
        board.food.gx = math.random(1, GRID_SIZE)
        board.food.gz = math.random(1, GRID_SIZE)
        attempts = attempts + 1
    until not isOccupiedBySnake(board, board.food.gx, board.food.gz, false) or attempts > 200

    board.foodPart.Position = cellToWorld(board.origin, board.food.gx, board.food.gz)
end

local function recolorSegments(board)
    for i, segment in ipairs(board.snake.segments) do
        segment.part.Color = (i == 1) and HEAD_COLOR or BODY_COLOR
    end
end

local function updateScoreboard(board)
    board.scoreLabel.Text = ("Score: %d  Best: %d  Episode: %d"):format(board.score, board.bestScore, board.episode)
end

local function resetEpisode(board)
    for _, segment in ipairs(board.snake.segments) do
        segment.part:Destroy()
    end

    board.snake.dir = "right"
    board.snake.segments = {}

    local startGx, startGz = math.floor(GRID_SIZE / 2), math.floor(GRID_SIZE / 2)
    for i = 0, 2 do
        local gx = startGx - i
        local part = makeSegmentPart(board)
        part.Position = cellToWorld(board.origin, gx, startGz)
        table.insert(board.snake.segments, { gx = gx, gz = startGz, part = part })
    end
    recolorSegments(board)

    spawnFood(board)

    board.score = 0
    board.episode = board.episode + 1
    updateScoreboard(board)
end

local function buildState(board)
    local head = board.snake.segments[1]
    local food = board.food

    local function danger(dx, dz)
        local gx, gz = head.gx + dx, head.gz + dz
        if not inBounds(gx, gz) then
            return 1
        end
        if isOccupiedBySnake(board, gx, gz, true) then
            return 1
        end
        return 0
    end

    return {
        danger_up    = danger(DIRS.up.dx, DIRS.up.dz),
        danger_down  = danger(DIRS.down.dx, DIRS.down.dz),
        danger_left  = danger(DIRS.left.dx, DIRS.left.dz),
        danger_right = danger(DIRS.right.dx, DIRS.right.dz),
        dir_up       = board.snake.dir == "up" and 1 or 0,
        dir_down     = board.snake.dir == "down" and 1 or 0,
        dir_left     = board.snake.dir == "left" and 1 or 0,
        dir_right    = board.snake.dir == "right" and 1 or 0,
        food_up      = food.gz < head.gz and 1 or 0,
        food_down    = food.gz > head.gz and 1 or 0,
        food_left    = food.gx < head.gx and 1 or 0,
        food_right   = food.gx > head.gx and 1 or 0,
    }
end

local function applyDeath(board)
    board.episodeOver = true
    for _, segment in ipairs(board.snake.segments) do
        segment.part.Color = DEAD_COLOR
    end

    if board.score > board.bestScore then
        board.bestScore = board.score
    end
    updateScoreboard(board)

    task.delay(getResetDelay(), function()
        resetEpisode(board)
        board.prevState, board.prevActionIndex = nil, nil
        board.episodeOver = false

        globalEpisodeCount = globalEpisodeCount + 1
        if globalEpisodeCount % SAVE_EVERY_EPISODES == 0 then
            saveSnakeAI()
        end
    end)
end

--------------------------------------------------------------------------
-- All boards share one QLearner, so two boards deciding at once would
-- race on its internal _lastAction -- this serializes each board's
-- lesson+infer step so only one is ever in flight.
--------------------------------------------------------------------------

local turnQueue = {}
local turnBusy = false

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

local function step(board, done)
    local head = board.snake.segments[1]
    local prevDist = manhattan(head.gx, head.gz, board.food.gx, board.food.gz)
    local state = buildState(board)

    SnakeAI:infer(state)
        :next(function()
            -- QLearner resolves the actual epsilon-greedy/argmax choice
            -- internally; pull it back out so lesson() trains the index
            -- it really picked, not a label round-tripped through text.
            local actionIndex = SnakeAI._impl._lastAction
            local direction    = ACTION_LABELS[actionIndex]
            local delta          = DIRS[direction]

            local newGx, newGz = head.gx + delta.dx, head.gz + delta.dz
            local ate  = newGx == board.food.gx and newGz == board.food.gz
            local died = not inBounds(newGx, newGz) or isOccupiedBySnake(board, newGx, newGz, not ate)

            -- Computed before spawnFood() below moves the food -- ate/died
            -- both short-circuit resolveReward before newDist is read, but
            -- it should still mean "distance to the food that mattered".
            local newDist = manhattan(newGx, newGz, board.food.gx, board.food.gz)
            local reward  = resolveReward(ate, died, prevDist, newDist)

            if not died then
                board.snake.dir = direction
                if ate then
                    local part = makeSegmentPart(board)
                    part.Position = cellToWorld(board.origin, newGx, newGz)
                    table.insert(board.snake.segments, 1, { gx = newGx, gz = newGz, part = part })
                    board.score = board.score + 1
                    spawnFood(board)
                else
                    local tail = table.remove(board.snake.segments)
                    tail.gx, tail.gz = newGx, newGz
                    tail.part.Position = cellToWorld(board.origin, newGx, newGz)
                    table.insert(board.snake.segments, 1, tail)
                end
                recolorSegments(board)
                updateScoreboard(board)
            end

            if board.prevState and board.prevActionIndex then
                SnakeAI:lesson({
                    state  = board.prevState,
                    action = board.prevActionIndex,
                    next   = state,
                    reward = reward,
                    done   = died,
                })
            end

            if died then
                applyDeath(board)
                board.prevState, board.prevActionIndex = nil, nil
            else
                board.prevState, board.prevActionIndex = state, actionIndex
            end

            done()
        end)
        :toss(function(err)
            warn("SnakeGame infer --", err)
            done()
        end)
end

local function createBoard(index, origin)
    local root, segmentsFolder, foodPart, scoreLabel = buildBoardWorld(configRoot, index, origin)

    local board = {
        origin         = origin,
        root           = root,
        segmentsFolder = segmentsFolder,
        foodPart       = foodPart,
        scoreLabel     = scoreLabel,
        snake          = { dir = "right", segments = {} },
        food           = { gx = 1, gz = 1 },
        score          = 0,
        bestScore      = 0,
        episode        = 0,
        prevState      = nil,
        prevActionIndex = nil,
        episodeOver    = false,
    }

    resetEpisode(board)
    table.insert(boards, board)

    task.spawn(function()
        while true do
            if not board.episodeOver then
                enqueueTurn(function(done)
                    step(board, done)
                end)
            end
            task.wait(getTickInterval())
        end
    end)

    return board
end

for i = 1, NUM_BOARDS do
    local origin = Vector3.new((i - 1) * (boardSize + BOARD_GAP), 0, 0)
    createBoard(i, origin)
end

print(("SnakeGame -- %d board(s) training in parallel. Change Workspace.SnakeGame's TickInterval/ResetDelay Attributes to retune speed live."):format(NUM_BOARDS))

game:BindToClose(function()
    saveSnakeAI()
    task.wait(2)
end)
