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
