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

The globe's terrain shell, altar and clouds, and the destructible prefab templates (`ServerStorage.Prefabs`), are built in Studio and live in the place file, not in this repo. Save the place after editing them. The planet's radius and center are config (`src/shared/Planets/Planet1.luau`); the terrain shell is regenerated from them, never dragged. Everything on the surface is generated at server start by `src/server/WorldGen.luau` from a per-server seed (printed to Output; `Dev.WorldSeed` fixes it): towns, hamlets, forests, groves, cliffs, landmarks and thousands of loose trees and rocks.

If Studio stops reflecting code changes, check that `rojo serve` is still pushing (it has silently stalled on the OneDrive folder before): restart it and click **Connect** again.

## Controls (desktop)

| Input | On ground | In air |
| --- | --- | --- |
| Mouse | Look | Look; glide turns toward where you look |
| WASD | Walk | Glide: W/S pitch, A/D turn |
| Space tap | Hop | Dive |
| Space hold | Under 1 s: a higher hop. Past 1 s: charge a Burst (higher the longer you hold) | Dive at the crosshair; release to swoop. Also pre-charges the next hop |
| Hold left click, release | Punch: a lunge that lifts into a hop; aimed steeply at the ground, a rocket jump that also pounds the ground | Punch: turns all your speed toward the crosshair and adds to it; aimed steeply at a surface, a rocket jump |

Both charges have no time limit and step up in tiers, shown by rings above your head (Space) and beside the crosshair (LMB); the Burst charge builds in the air too, so a long dive hold lands straight into a big launch. In the air, speed never drops on its own: dives keep accelerating and punches add to whatever speed you have. Walls bounce you; dives land and slide, and only bounce off the ground if a punch is held.

The world is a globe (radius 5,000): gravity points at its center and level flight follows the curve, so a long charged punch circles the planet.

**Destruction.** Everything on the surface breaks. Damage is speed: a contact does `speed / 25` hits, times 2.5 while punching and health decides, so a glide clears trees, a tap punch houses, a charged punch towers, and a ten-second punch anything in its path. A dive into the ground or a structure smashes a radius that grows with speed, breaking in a wave from the centre; a punch fired into the ground pounds it harder the closer you are. Breaking through costs speed in proportion to how close the object came to stopping you. Cash pays per object with altitude and combo multipliers; the combo is kept alive by movement tech and Burst releases, not by holding anything. Rings, chunks, toasts, the combo banner and haptics are all FeelTable entries in `Tuning.luau`.

Movement tech is described in [SPEC §15](docs/SPEC.md#15-decisions-made-during-implementation). Touch devices get a thumbstick, drag-to-look and JUMP and PUNCH buttons.

## Status

Milestones 1 (movement core), 2 (burst and arc), 3 (the globe, then animation, charge camera, speed and touchdown juice) and 4 (the core loop: destructibles, the generated world, server-authoritative damage and payout, cash and combo) are done. Milestone 5, destruction polish, is in progress: the arcade feedback layer (combo banner with tier names, break toasts, floating numbers), the flying punch pose, speed-scaled impact frames, the first polish pass from an independent review (big breaks, impact silence, camera roll, musical combo, chunk flash, car pops), haptics, and the landmark prefabs. The plan is in [SPEC §14](docs/SPEC.md#14-build-plan-for-claude-code), and every change made in review is in §15.

Animation targets R15 with R6 fallbacks. VFX textures (vignette, glow, ring, cracks, speed lines, streak) are uploaded image assets referenced from `Tuning.Vfx`; sounds are still engine placeholders; prefabs are primitives.

## Studio test tools

- **F2**: tuning panel. Every value in `Tuning.luau` as a slider; "Print changes" writes edited values to Output for pasting back; buttons drop you from 300/1,000/3,000 studs and set Power.
- **F3**: hides or shows the controls and tricks cheat sheet (bottom-left; top-left and foldable on touch). It shows in every build, including published test places, while `Dev.ShowControlsHud` is on; in Studio it adds a live state/speed/height/energy readout.
- **F4**: a test smash under the player at `Dev.TestSmashSpeed`.
- `Dev.ChargeSpeed` multiplies how fast every hold charges (2 while testing); `Dev.TraceMovement` prints state transitions, bounces and every destructible contact to Output in Studio, and the server warns when it rejects a contact.
