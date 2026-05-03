# Capture — Godot 4 Tactical CTF Game

## What This Is

A two-team, squad-based tactical capture-the-flag game built in **Godot 4.3** (GDScript throughout). Created for CodeMash 2025. The game is turn-based: teams of 5 characters alternate controlling their units on a procedurally generated 201×100 tile map. Core mechanics are movement via A* pathfinding, a 5-stance system that trades speed vs. visibility, and a per-team 3-state fog-of-war system.

**GitHub:** https://github.com/armstrongsp/capture-the-flag-mobile (public, master branch)

---

## Project Structure

```
capture/
├── project.godot              # Godot 4.3, Forward Plus, main scene = Scenes/world.tscn
├── Scenes/
│   ├── world.tscn / world.gd  # Main scene — game controller
│   ├── player.tscn / player.gd # Character prefab
│   ├── hud.tscn / hud.gd      # CanvasLayer UI
│   ├── flag.tscn / flag.gd    # Flag entity
│   └── camera_2d.tscn / camera_2d.gd  # Per-player camera
└── Scripts/
    ├── Globals.gd              # Autoloaded enums, constants, stance modifiers
    └── SignalBus.gd            # Autoloaded event bus
```

---

## Key Constants (Globals.gd)

| Constant | Value | Meaning |
|---|---|---|
| CELL_SIZE | 32 | Pixels per tile |
| UI_SCALE | 4 | HUD scaling |
| PlayersPerTeam | 5 | Characters per side |
| Max_Vision | 15 | Max cells of vision |
| Max_Movement | 500 | Max movement points per turn |
| Max_Strength | 100 | |
| Max_Stealth | 100 | |

**Stance enum** (in `Globals.Stance`): `Scouting`, `Walking`, `Running`, `Crawling`, `Prone`

**StanceMods dictionary** — multipliers per stance for `vision`, `movement` (cost), `visibility` (how visible the character is to enemies):

| Stance | Vision× | MoveCost× | Visibility× |
|---|---|---|---|
| Scouting | 0.8 | 1000 (stationary) | 1.0 |
| Walking | 1.0 | 1.0 | 1.0 |
| Running | 1.3 | 0.8 | 1.3 |
| Crawling | 2.0 | 2.0 | 0.7 |
| Prone | 5.0 | 5.0 | 0.3 |

---

## Map System

- **Dimensions:** 201 wide × 100 tall tiles
- **Center divider:** x=100.5 (x ≤ 100 = Team 1 side, x ≥ 101 = Team 2 side)
- **Layers (z-order):**
  - `Ground` (z=10) — base grass + centerline stripe
  - `GroundFeatures` (z=50) — trees, water, mountains, tall grass, fences
  - `FogOfWar2` (z=99) — grayed tiles (revealed/fogged state)
  - `FogOfWar` (z=100) — black tiles (blacked-out state)

### Terrain Types & Properties

| Terrain | Vision Reduce | Movement Cost | Notes |
|---|---|---|---|
| Grass (base) | 0 | 1 | Default |
| Tall Grass | 2 | 3 | |
| Trees (Forest) | 3 | 5 | |
| Water | 1 | 8 | |
| Mountain | -1 (grants +50% range) | 5 | Does not block LOS |
| Fence | — | 1000 (impassable) | Border walls |

**Terrain properties** are stored in tile custom_data and loaded into `map_vision_metadata[][]` and `map_movement_metadata[][]` arrays in world.gd at startup.

### Procedural Generation

`_generate_terrain_blobs()` in world.gd: places 12–140 blobs (count varies by type) of randomized radius with probability falloff from center. Blobs can cross the centerline. Fence tiles ring the full border.

---

## Player Characters (player.gd)

Each player is a `CharacterBody2D` with:
- `player_id` (1–10), `team_id` (1 or 2)
- Stats randomized 20–100% of max: `max_vision_range`, `max_movement_range`, `max_strength`, `max_stealth`
- `movement_points_remaining` — depletes as the player moves; resets each turn
- `stance` — current `Globals.Stance`, defaults to Running
- `visible_cells: BitMap` — the player's current vision footprint (recalculated on every move/stance change)

### Spawn Positions
- Team 1: x=95, evenly spaced y across map height (5 cells left of centerline)
- Team 2: x=105, same vertical spacing (5 cells right of centerline)

### Movement
1. Player selected → right-click destination
2. world.gd calls A* (`pathfinding: AStarGrid2D`) and hands path to player via `cur_path`
3. `_physics_process` interpolates 5px/frame toward each waypoint
4. On each cell change: deduct `movement_cost × stance_movement_modifier`, call `update_visible_cells()`, emit `player_moved`

### Vision (update_visible_cells)
- 180 rays cast in 2° increments (360° coverage)
- Each ray steps outward; vision budget depleted by tile's `Vision_Reduce`
- Mountains: if standing on mountain, effective range = `int(max_vision × 1.5)`; mountains do not reduce LOS when a ray passes through them
- Result stored in `visible_cells: BitMap`

### Visual Feedback
- `SelectedBox` (green sprite) shown when selected + has movement remaining
- `OutOfMovementBox` (red sprite) shown when selected but out of movement
- `AnimatedSprite2D` plays stance animation (Crawling, Prone, Running, Scouting, Walking — 12 frames each, frog sprites)

---

## Fog-of-War System (world.gd)

Two separate fog state grids: `fog_state_team1[][]` and `fog_state_team2[][]`.

**Three states per cell:**
- **State 1** — Blacked out (black tile on FogOfWar layer)
- **State 2** — Revealed/fogged (grayed tile on FogOfWar2 layer; enemy units hidden)
- **State 3** — Fully visible (no fog tile; shows everything including enemies)

**Rules:**
- Game start: Team 1's own side (x ≤ 100) starts at State 2; enemy side (x > 100) starts at State 1. Reversed for Team 2.
- Visibility from player bitmaps promotes cells to State 3.
- On turn switch: all State 3 cells downgrade to State 2 for the outgoing team.
- Cells never go from State 2 back to State 1.
- Each team's own flag is always visible (State 3) regardless of fog.

**Rendering** (`update_fog_layer()`): iterates all cells, sets/erases tiles on FogOfWar and FogOfWar2 based on the active team's fog state array.

---

## Turn System (world.gd)

- `active_team` (1 or 2); Team 1 starts
- Players on the inactive team cannot be selected
- `end_turn()`: switches `active_team`, resets movement points for new team's players, deselects all, emits `turn_changed(team_id)`
- Auto-end: after every move, `_check_auto_end_turn()` checks if all active team players have 0 movement — if so, calls `end_turn()` automatically
- HUD "End Turn" button also calls `end_turn()` early

---

## Flags (flag.gd)

- Each team gets 1 flag: Team 1 = red `ColorRect`, Team 2 = blue `ColorRect`
- Spawned randomly in the outer 25% of the map on their team's side (x < 25 for Team 1, x > 175 for Team 2)
- Always visible to the owning team via fog state override in `update_fog_layer()`
- Capture mechanic not yet implemented

---

## HUD (hud.gd)

- Stat bars (0–1 float): Movement, Vision, Strength, Stealth
- 5 stance buttons; clicking emits `player_set_stance`
- `Stance_Selected` indicator sprite moves to highlight active stance
- "Save Map" / "Load Map" buttons emit `map_save` / `map_load` signals
- "End Turn" button emits `turn_end` signal
- `TurnLabel` displays "Team X's Turn"

---

## Signal Bus (SignalBus.gd) — Autoloaded

| Signal | Args | Purpose |
|---|---|---|
| `player_selected` | `player_id: int` | Character clicked |
| `player_moved` | `pos: Vector2` | Player position updated |
| `player_stats_updated` | `vision, movement, strength, stealth: float` | HUD bar update (0–1) |
| `player_set_stance` | `stance: Globals.Stance` | HUD → player stance change |
| `map_save` | — | Trigger save |
| `map_load` | `filename: String` | Trigger load |
| `turn_end` | — | HUD end-turn button |
| `turn_changed` | `team_id: int` | New active team |

---

## Save / Load

`map_data_save()` / `map_data_load()` in world.gd serialize to encrypted JSON via `FileAccess.open_encrypted_with_pass()`. Saves: tile layout, all player stats/positions/states, flag positions, both teams' fog state arrays.

---

## Camera (camera_2d.gd)

Embedded inside each player scene. Activated when that player is selected (`make_active_camera()`). Scroll wheel zooms (1×–10×); middle-mouse drags to pan.

---

## Remaining Work (ToDo.txt)

**Not yet defined/implemented:**
- Conflict mechanic (combat when players meet)
- Screen overlay UI improvements
- Auto-end turn (done) but full turn flow polish
- Enemy AI
- Seeing enemy team players through fog (State 3 detection)
- Sounds and background music
- Improved level generation aesthetics

**Completed (marked x in ToDo.txt):**
- Border fences, pathfinding, proper tiles, player images/animations
- Centerline, stances with vision modifiers, stance button UI
- Turn-taking with team indicator
- Second team with mirrored spawn
- Flags per team, fog-of-war per team (3 states)

---

## Architecture Notes

- **Signal bus pattern**: all cross-scene communication goes through `SignalBus` (autoloaded). Never call methods directly across scenes.
- **Autoloads**: `Globals` and `SignalBus` are both registered as autoloads in project.godot.
- **Grid coordinate convention**: tile positions use `Vector2i`; world pixel positions use `Vector2`. Convert with `map_to_local()` / `local_to_map()` on the TileMapLayer.
- **Physics layers**: Layer 1 = "Physical" (collisions), Layer 2 = "Vision" (LOS).
- **Input actions**: `select` (left mouse), `zoomin` / `zoomout` (wheel), `camera_pan` (middle mouse).
