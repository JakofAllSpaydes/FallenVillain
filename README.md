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

World content (the globe's terrain shell, altar, clouds and later the town) is built in Studio and lives in the place file, not in this repo. Save the place after world edits. The planet's radius and center are config (`src/shared/Planets/Planet1.luau`); the terrain shell is regenerated from them, never dragged.

If Studio stops reflecting code changes, check that `rojo serve` is still pushing (it has silently stalled on the OneDrive folder before): restart it and click **Connect** again.

## Controls (desktop)

| Input | On ground | In air |
| --- | --- | --- |
| Mouse | Look | Look; glide turns toward where you look |
| WASD | Walk | Glide: W/S pitch, A/D turn |
| Space tap | Hop | Dive |
| Space hold | Under 1 s: a higher hop. Past 1 s: charge a Burst (higher the longer you hold) | Dive at the crosshair; release to swoop. Also pre-charges the next hop |
| Hold left click, release | Punch: a lunge that lifts into a hop; aimed steeply at the ground, a rocket jump | Punch: turns all your speed toward the crosshair and adds to it; aimed steeply at a surface, a rocket jump |

Both charges have no time limit and step up in tiers, shown by rings above your head (Space) and beside the crosshair (LMB). In the air, speed never drops on its own: dives keep accelerating and punches add to whatever speed you have. Walls bounce you; dives land and slide, and only bounce off the ground if a punch is held.

The world is a globe (radius 5,000): gravity points at its center and level flight follows the curve, so a long charged punch circles the planet.

Movement tech (bunny hop, pre-charge, dive slide, dive boost, swoop skim, rocket jump, jump punch, orbit) is described in [SPEC §15](docs/SPEC.md#15-decisions-made-during-implementation).

## Status

Milestones 1 (movement core), 2 (burst and arc) and 3a (the globe) are done. Milestone 3b, the polish pass, is in progress: character animation (stock Roblox clips plus FALL poses: jump-charge squat, punch wind-back, dive, swoop, hang, slide), a camera that zooms in as either charge builds, speed-driven FOV, shake, speed lines and heat, speed-scaled touchdown impacts (hitstop, flash, rings, crater, debris, dust wall) and an aesthetics pass with the game's own VFX textures. The plan is in [SPEC §14](docs/SPEC.md#14-build-plan-for-claude-code), and every change made in review is in §15.

Animation targets R15 with R6 fallbacks. VFX textures (vignette, glow, ring, cracks, speed lines, streak) are uploaded image assets referenced from `Tuning.Vfx`; sounds are still engine placeholders.

## Studio test tools

- **F2**: tuning panel. Every value in `Tuning.luau` as a slider; "Print changes" writes edited values to Output for pasting back; buttons drop you from 300/1,000/3,000 studs and set Power.
- **F3**: hides or shows the controls and tech cheat sheet (bottom-left). It shows in every build, including published test places, while `Dev.ShowControlsHud` is on; in Studio it adds a live state/speed/height/energy readout.
- `Dev.ChargeSpeed` multiplies how fast every hold charges (2 while testing); `Dev.TraceMovement` prints state transitions and bounces to Output in Studio.
