# Rat Raid: Game Plan

*A 2v2 asymmetric chaos game: two tiny rats raid a suburban house while two homeowners try to stop them.*
*Inspired by Who's Your Daddy?! and Bathe the Baby (small vs. big, slapstick, a cluttered house full of stuff).*

---

## Part 1: Plan v1 (first draft)

### Core loop
1. **Lobby (intermission, 20s).** Players choose a side preference, class and perk, and can visit the shop.
2. **Match (5 min).** 2 rats vs. 2 homeowners in the house.
3. **Results.** A winner screen, currency payouts, then back to the lobby.

### Win conditions
- **Rats win** if they deliver the food quota (e.g. 100 food points) to the Rat Den.
- **Homeowners win** if the rats run out of lives or the timer expires.

### Rats
- Tiny (about 1/3 scale), fast, and able to jump high. Third-person camera.
- Pick up one food item at a time. Carrying food slows you down; heavier food slows you more.
- Bring food back to the **Rat Den** (a hole in the baseboard that leads to a burrow outside).
- Abilities depend on class.

### Homeowners
- Normal size, first-person camera (like the dad in the trailer).
- **Net:** short range; *captures* a rat (it goes to a cage).
- **Electric flyswatter:** melee zap that damages and briefly stuns.
- **Gun:** ranged pellet gun.
- **Mousetraps:** placeable; snap and kill a rat on touch.

### Classes (3 per side)
| Side | Class | Identity |
|---|---|---|
| Rat | Scout | Fastest, low carry |
| Rat | Hauler | Carries heavy food with less slowdown |
| Rat | Trickster | Smoke bomb ability |
| Homeowner | Exterminator | More traps |
| Homeowner | Dad | Faster net |
| Homeowner | Hunter | Better gun |

### Perks
Passive bonuses, one equipped per side. Examples: Light Paws, Iron Stomach, Keen Ears, Bulk Traps.

### Economy
- **Homeowners earn Coins:** per capture plus a time bonus (earlier capture = more), per kill, and a win bonus.
- **Rats earn Crumbs:** per food point delivered, plus a win bonus.
- **Shop:** class unlocks, perks, consumable gadgets.
- Saved with DataStores.

### Map
A suburban house: kitchen, living room, dining room, hallway, bedroom, backyard with a picket fence, and a pool. Food is spread around the kitchen and dining areas.

### Tech
Rojo project → `.rbxlx`. Server-authoritative. Modules for config, rounds, combat, food, shop and data.

---

## Part 2: Review: what's wrong with v1

1. **Scope is too large for a first build.** The aim should be a playable *vertical slice*: every system works end to end with placeholder art. Multiple maps, cosmetics, co-op carrying and mobile polish come later.
2. **A hitscan gun would dominate tiny rats.** Rats are small, but a fast hitscan gun still trivializes the game. → Make it a **slow pellet gun with limited ammo** (refills by buying ammo packs), and make it deal moderate damage instead of one-shotting.
3. **Capture vs. kill isn't balanced.** The brief stresses *capturing* rats and paying for it with a time bonus. If killing pays the same, nobody nets. → **Capture pays the most** (base plus a time bonus). Kills pay less. Traps pay the least because they're passive.
4. **"Lives run out" alone is too slow and not dramatic.** → **Shared rat lives (5)** *plus* a **cage-rescue mechanic**: a netted rat goes into a cage on the kitchen counter, and its teammate can touch the cage to free it. If **both rats are caged at once**, the homeowners win instantly. A caged rat that isn't rescued within 30s is "exterminated" and costs a life. This creates tense rescue moments, like the trailer's chaos.
5. **Abilities need a consistent input.** → Every class gets one **active ability on the `Q` key**, with a cooldown shown in the HUD. Rats: Scout = Dash, Hauler = Stampede (knockback-immune and faster for 3s), Trickster = Smoke Bomb. Homeowners: Exterminator = Trap Toss (instant trap at range), Dad = Shout (stuns nearby rats), Hunter = Rat Sense (highlights rats for 4s).
6. **Testing with fewer than 4 players.** Without this, it's impossible to test alone. → `Config.MIN_PLAYERS` defaults to 1 in Studio and 2 live. With 1 player you choose your side. The round still runs, and Studio's *Test → Clients and Servers (4 players)* works for real 2v2 tests.
7. **Character scaling.** Hand-rolled scaling is fragile. → Use `Model:ScaleTo(0.35)` on spawn and add placeholder ears and a tail. Later, swap in a custom rat model through the same function (`CharacterService.applyRatLook`).
8. **Perks shouldn't be passive text only.** Each perk is a data entry with numeric modifiers the server reads (e.g. `trapTriggerDelay`, `extraTraps`). Adding a perk then means editing data, not logic.
9. **Shop clarity.** There are two currencies, each spent only on its own side's items. Purchases are validated on the server. Consumables (ammo pack, smoke bomb refill, energy cheese) last one round. Unlocks (classes, perks) are permanent.
10. **DataStore in Studio.** It fails unless API access is enabled. → Fall back to an in-memory profile with a warning, so the game never breaks.
11. **Food readability.** → Food sits on a glowing highlight. Carried food shows above the rat's head. The den has a big sign and a beam. When a rat dies, its food drops where it fell.
12. **Lobby flow.** Picking classes before teams are known is confusing. → Pick a **side preference** in the lobby. The server balances teams, then each player gets a 10s **class/perk select** screen showing only their side.

---

## Part 3: Final plan (revised): this is what gets built

### Round flow
`Lobby (20s, needs MIN_PLAYERS)` → `Team assignment` → `Class & perk select (10s)` → `Match (5:00)` → `Results (8s)` → Lobby.

### Win conditions
| Rats win | Homeowners win |
|---|---|
| Deliver **100 food points** to the den | Rat team runs out of **5 shared lives** |
| | **Both rats caged** at the same time |
| | **Timer hits 0** |

### Rat rules
- 100 HP, 0.35 scale, WalkSpeed 22, JumpPower 45.
- Press **E** near food to pick it up and **G** to drop it. Walk into the den to deliver.
- Carrying slows you by a factor based on the food's weight.
- Death costs 1 shared life and you respawn at the den after 6s. Your food drops where you died.
- Netted → caged. A teammate touches the cage to rescue. Unrescued for 30s → 1 life lost and respawn.

### Homeowner weapons
| Tool | Effect | Notes |
|---|---|---|
| Net | Capture (cage) | 8-stud range, 1.2s cooldown |
| Electric Flyswatter | 40 dmg + 1.5s stun | 7-stud range, 0.8s cooldown |
| Pellet Gun | 25 dmg | 0.9s cooldown, 12 ammo/round, raycast |
| Mousetrap | Instant kill on touch | 3 per round (+class/perk), place in front of you |

### Food
| Food | Points | Weight (slowdown) |
|---|---|---|
| Crumb Cookie | 5 | 0.05 |
| Cheese Wedge | 10 | 0.15 |
| Bread Loaf | 15 | 0.25 |
| Apple | 10 | 0.15 |
| Pizza Slice | 20 | 0.30 |
| Whole Cake | 40 | 0.55 |

### Classes
| Side | Class | Stats | Q ability | Cost |
|---|---|---|---|---|
| Rat | Scout | Speed +4 | Dash | Free |
| Rat | Hauler | Weight penalty −50% | Stampede | 150 Crumbs |
| Rat | Trickster | +10 HP | Smoke Bomb | 250 Crumbs |
| Home | Dad | Net cooldown −30% | Shout (stun radius) | Free |
| Home | Exterminator | +2 traps | Trap Toss | 150 Coins |
| Home | Hunter | +6 ammo, gun +5 dmg | Rat Sense | 250 Coins |

### Perks (one equipped per side, bought permanently)
**Rat:** Light Paws (traps take 0.6s to snap, so you can escape), Iron Stomach (regenerate 2 HP/s while carrying), Quick Feet (+2 speed), Lockpick (rescue happens 2× faster from range, and the cage timeout becomes 45s).
**Homeowner:** Bulk Traps (+2 traps), Steady Hands (+4 gun ammo), Long Reach (+3 net range), Marathon (+3 speed).

### Economy
- **Coins (homeowners):** capture = 50 + time bonus (`floor(secondsRemaining / 3)`, up to +100); kill = 25; trap kill = 15; win = 100; participation = 20.
- **Crumbs (rats):** 1 Crumb per food point delivered × 2; rescue = 20; win = 100; participation = 20.
- **Shop consumables (one round):** Ammo Pack (+6 ammo, 40 Coins), Extra Trap (+1 trap, 30 Coins), Energy Cheese (+3 speed this round, 40 Crumbs), Thick Fur (+25 max HP this round, 60 Crumbs).

### Architecture (Rojo)
```
src/
  shared/      (ReplicatedStorage.Shared)  Config, Classes, Perks, ShopItems, Foods, Remotes
  server/      (ServerScriptService.Server) Main + services: Data, Round, Character, Combat, Food, Shop, Cage, Ability
  client/      (StarterPlayerScripts.Client) Main + controllers: UI, Input, Camera, Effects
map/           generated Workspace.Map (house, furniture, food spawns, den, cage, spawns)
```
- Every action goes to the server through RemoteEvents. The server validates range, cooldown, team and ammo.
- Data-driven configs, so balancing means editing a table.

### Art direction (from the trailer)
- Bright, saturated, toy-like suburban house: blue walls, warm wood floors, a checkerboard kitchen, a picket fence, and a pool.
- Comic-book UI: a heavy outlined font (Luckiest Guy / FredokaOne), yellow highlight words, and a blue sunburst title screen.
- Homeowners use first person and rats use third person, matching the trailer's camera split.

### Modeling strategy (recommendation)
1. **Now (included):** placeholder primitives built from Parts. These are fully playable and easy to swap.
2. **Furniture and props → Creator Store**, filtered to verified creators. Always check inserted models for hidden `Script`s (a common source of backdoors) before keeping them.
3. **Rat character and key food → make your own** (Blender → FBX → Avatar Importer or MeshPart) or commission them. The rat is the game's identity, and store rats rarely match well.
4. **Homeowners:** use standard player avatars, the way Who's Your Daddy uses the dad character.

### Milestones
1. ✅ Vertical slice (this build): every system working with placeholder art.
2. Art pass: real house furniture, rat model, sounds, VFX.
3. Balance pass with 4-player playtests.
4. Content: second map (restaurant/garage), cosmetics, co-op heavy-food carry, a daily quest.
5. Launch: thumbnails, game icon, a Game Pass for cosmetics only (no pay-to-win).
