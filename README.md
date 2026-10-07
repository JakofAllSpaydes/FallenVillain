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
| Space hold | Charge a Burst (charge full) or a higher hop | Dive at the crosshair; release to swoop |
| Hold left click, release | Punch; rocket jump with the crosshair on the ground | Rocket jump near a surface, else dash at the crosshair |

Movement tech (bunny hop, dive-slide, swoop skim, rocket jump, jump punch) is described in [SPEC §15](docs/SPEC.md#15-decisions-made-during-implementation).

## Studio test tools

- **F2**: tuning panel. Every value in `Tuning.luau` as a slider; "Print changes" writes edited values to Output for pasting back; buttons drop you from 300/1,000/3,000 studs, refill the Burst charge, and set Power.
- **F3**: hides or shows the controls and tech cheat sheet (bottom-left). It shows in every build, including published test places, while `Dev.ShowControlsHud` is on; in Studio it adds a live state/speed/height/energy readout.
