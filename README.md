<div align="center">
    
**Adaptive neural intelligence for Roblox games.**

[![Version](https://img.shields.io/badge/VERSION-0.1.0--beta-6C3EF4?style=for-the-badge)](https://github.com/NotKisoMomo/Worm)
[![License](https://img.shields.io/badge/LICENSE-MIT-6C3EF4?style=for-the-badge)](https://github.com/NotKisoMomo/Worm/blob/main/LICENSE)
[![Roblox](https://img.shields.io/badge/ROBLOX-Luau-6C3EF4?style=for-the-badge)](https://github.com/NotKisoMomo/Worm)
[![Wiki](https://img.shields.io/badge/DOCS-Wiki-6C3EF4?style=for-the-badge)](https://github.com/NotKisoMomo/Worm/wiki)

</div>

---

Worm is a neural networking library for Roblox -- MLP classifiers, Q-learning combat agents, spatial filters, and NEAT evolution, all under a single unified profile API. No ML background required. Teach your NPCs through labeled examples and relative grading, then let them adapt in real time.

---

## Why Worm

| Feature | Manual NPC Logic | Worm |
|---|---|---|
| Combat decision making | Hardcoded if/else trees | Q-learning agent -- adapts per fight |
| NPC behavior tuning | Tweaking numbers by hand | `grade()` -- relative importance, no raw weights |
| Input preparation | Manual normalization every call | `interpret()` middleware -- raw in, vector out |
| Teaching the AI | Backprop math | `lesson()` -- labeled scenario tables |
| NPC evolution | Static forever | NEAT population -- improves between rounds |
| Serialization | Custom save logic | `export()` / `import()` -- plain table, DataStore ready |
| Async | Blocking or unstructured | Promise-backed -- `:next()` / `:toss()` |

---

## Install

### Wally (recommended)

Add to your `wally.toml`:

```toml
[dependencies]
Worm = "ker/worm@0.1.0"
```

Then run:

```sh
wally install
```

Require from anywhere -- server or client:

```lua
local Worm = require(game.ReplicatedStorage.Packages.Worm)
```

### Manual

Copy the `src` folder into `ReplicatedStorage` or `ServerScriptService` (renaming it to `Worm`), depending on your execution model.

```lua
local Worm = require(game.ReplicatedStorage.Worm)
```

---

## Quick Start

```lua
local Worm = require(game.ReplicatedStorage.Worm)

local npc = Worm.build(Worm.MLP, {
    inputs = 3,
    outputs = 3,
    schema = {
        hp       = { range = { 0, 100 } },
        distance = { range = { 0, 500 } },
        aggro    = { range = { 0, 10 } },
    }
})

npc:labels({ "flee", "patrol", "attack" })

npc:lesson({
    { input = { hp = 10,  distance = 50,  aggro = 9 }, label = "flee"   },
    { input = { hp = 80,  distance = 20,  aggro = 8 }, label = "attack" },
    { input = { hp = 100, distance = 300, aggro = 1 }, label = "patrol" },
})

npc:infer({ hp = 25, distance = 40, aggro = 7 })
    :next(function(decision)
        print(decision) -- "flee"
    end)
    :toss(function(err)
        warn("Worm --", err)
    end)
```

---

## Wiki

| Page | Description |
|---|---|
| [Home](https://github.com/NotKisoMomo/Worm/wiki) | Overview and module structure |
| [Getting Started](https://github.com/NotKisoMomo/Worm/wiki/Getting-Started) | Installation and first profile |
| [Core Concepts](https://github.com/NotKisoMomo/Worm/wiki/Core-Concepts) | Profiles, middleware, grading, promises |
| [API Reference](https://github.com/NotKisoMomo/Worm/wiki/API-Reference) | Full method surface |
| [Algorithms](https://github.com/NotKisoMomo/Worm/wiki/Algorithms) | MLP, QLearner, CSF, NEAT -- when to use each |
| [Patterns](https://github.com/NotKisoMomo/Worm/wiki/Patterns) | Combat NPC, zone separation, evolving populations |
| [Serialization](https://github.com/NotKisoMomo/Worm/wiki/Serialization) | Export, import, Keep integration |
| [Migration](https://github.com/NotKisoMomo/Worm/wiki/Migration) | Version upgrade guide |

---

<div align="center">

Built by Plinko Labs

</div>
