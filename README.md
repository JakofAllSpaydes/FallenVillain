# FALL

Roblox supervillain game about launching to the edge of the sky and falling back down like a meteor. Full design: [docs/SPEC.md](docs/SPEC.md).

## Setup

1. Install [Aftman](https://github.com/LPGhatguy/aftman), then from the repo root:
   ```
   aftman install
   ```
2. Install the Rojo plugin in Studio (`rojo plugin install`, or from the Roblox Creator Store).
3. Start the sync server:
   ```
   rojo serve
   ```
4. In Studio, open a baseplate, open the Rojo plugin, click **Connect** (localhost:34872).

Build a place file without Studio: `rojo build -o FALL.rbxl`

## Layout

| Path | Studio location |
| --- | --- |
| `src/shared` | `ReplicatedStorage.Shared` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` |
| `src/server` | `ServerScriptService.Server` |

World content (the disc, altar and later the town) is built in Studio and lives in the place file, not in this repo. Save the place after world edits.

## Controls (desktop)

| Input | On ground | In air |
| --- | --- | --- |
| Mouse | Look | Look; glide turns toward where you look |
| WASD | Walk | Glide: W/S pitch, A/D turn |
| Space tap | Hop | Dive |
| Space hold | Under 1 s: a higher hop. Past 1 s: charge a Burst (higher the longer you hold) | Dive at the crosshair; release to swoop. Also pre-charges the next hop |
| Hold left click, release | Punch: a lunge that lifts into a hop; aimed steeply at the ground, a rocket jump | Punch: turns all your speed toward the crosshair and adds to it; aimed steeply at a surface, a rocket jump |

Both charges have no time limit and step up in tiers, shown by rings above your head (Space) and beside the crosshair (LMB). In the air, speed never drops on its own: dives keep accelerating and punches add to whatever speed you have. Walls and the ground bounce you.

Movement tech (bunny hop, pre-charge, dive bounce, dive boost, swoop skim and slide, rocket jump, jump punch) is described in [SPEC §15](docs/SPEC.md#15-decisions-made-during-implementation).

## Status

Milestones 1 (movement core) and 2 (burst and arc) are done. Next is milestone 3, a polish pass on movement and punching. The plan is in [SPEC §14](docs/SPEC.md#14-build-plan-for-claude-code), and every change made in review is in §15.

## Studio test tools

- **F2**: tuning panel. Every value in `Tuning.luau` as a slider; "Print changes" writes edited values to Output for pasting back; buttons drop you from 300/1,000/3,000 studs and set Power.
- **F3**: hides or shows the controls and tech cheat sheet (bottom-left). It shows in every build, including published test places, while `Dev.ShowControlsHud` is on; in Studio it adds a live state/speed/height/energy readout.
