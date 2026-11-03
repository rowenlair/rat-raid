# Rat Raid

2 rats vs. 2 homeowners. The rats steal food and drag it back to their den. The homeowners net them, zap them, shoot them and trap them.

## Open it
1. Double-click **`Rat Raid.rbxlx`**. It opens in Roblox Studio.
2. **File → Save to Roblox As…** and name it "Rat Raid". It's now a real cloud project.
3. *(Optional, so coins save in Studio)* Go to **Game Settings → Security → Enable Studio Access to API Services**.

## Test it
- **Solo:** press **Play**. With one player you can pick a side in the lobby ("I want to play as") and the round still runs.
- **Real 2v2:** go to **Test tab → Clients and Servers → 4 Players → Start**.
- `MIN_PLAYERS` is 1 in Studio and 2 in live servers (`ReplicatedStorage.Shared.Config`).

## Controls
| | Rat | Homeowner |
|---|---|---|
| Move/jump | WASD / Space | WASD / Space (first person) |
| Main action | **E** to grab food | **Click** with the equipped tool (1–4) |
| Ability | **Q** | **Q** |
| Other | **G** to drop food | |

## Where things live
| Place in Studio | What it is |
|---|---|
| `ReplicatedStorage.Shared.Config` | **All balance numbers**: timers, quota, lives, weapon damage, rewards |
| `ReplicatedStorage.Shared.Classes / Perks / ShopItems / Foods` | Data tables. Add a class or perk here |
| `ServerScriptService.Server.Services.*` | Round, Food, Combat, Cage, Ability, Shop, Data, Character |
| `StarterPlayerScripts.Client.Controllers.UI` | All UI (comic style), built in code |
| `Workspace.Map` | House, furniture, `FoodSpawns`, `RatDen.DenZone`, `Cage`, `Spawns`, `Lobby` |

**Map rules the scripts rely on:** keep these names if you rebuild the house:
`Map.FoodSpawns` (any invisible parts), `Map.RatDen.DenZone`, `Map.Cage.CageSpot` + `CageExit`, `Map.Spawns.RatSpawn` + `HomeSpawn`. Rats are about 1.8 studs tall and jump about 5 studs, so keep rat holes ≥3 studs tall and climbing steps ≤4.5 studs.

## Replacing placeholder art
- **Furniture:** delete parts in `Map.Furniture` and drop in Creator Store models. **Before keeping any free model, search inside it for `Script`s and delete them.** Free models are the #1 source of backdoors.
- **Rat character:** edit `Character.applyRatLook` in `Services/Character.lua`. Today it shrinks the avatar and adds ears, a nose and a tail. Swap in your own rat rig there.
- **Tools:** the builders in `Services/Combat.lua` (`builders.Net`, etc.) make the tool look. Replace them with cloned models from `ServerStorage`.

## Working in code (optional, recommended)
This project is a [Rojo](https://rojo.space) project. Edit `src/` in VS Code and run `rojo serve` with the Rojo Studio plugin to live-sync. Run `python3 tools/build_map.py` to regenerate the house, and `rojo build -o "Rat Raid.rbxlx"` to rebuild the place file.
