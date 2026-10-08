# FALL — agent notes

- Design spec: `docs/SPEC.md`. Build order and working rules are in §14; follow milestones in order. §15 records decisions made during reviews and overrides earlier sections where they disagree; add to it when a review changes the design.
- Rojo 7 project (`default.project.json`), Luau, tools pinned in `aftman.toml`.
- Every tunable number goes in `src/shared/Tuning.luau`, never inline. Levels, circles and the power multiplier are `shared/Progression.luau` over `Tuning.Progression`; the server owns XP and levels (`server/PlayerData.luau`) and clients read them as Player attributes. Joint poses live in `Tuning.Poses` (skipped by the F2 panel); texture asset ids in `Tuning.Vfx`.
- Every effect goes through `FeelTable`, never called directly from a movement state. Event-driven effects are FeelTable entries (`Feel/Juice.luau` documents the keys, including `curve`, `bySpeed` and `minHeld`); anything that follows live speed or charge every frame goes in `Feel/Drivers.luau` and writes a driven layer.
- Character animation is `Feel/Anim.luau`: stock Roblox clips for locomotion plus pose offsets composed into each joint's `Transform` (the rig's joints are `AnimationConstraint`s on current rigs; `C0` is read-only there). R15 first, R6 fallback. Never touch the Humanoid's default Animate script elsewhere.
- Juice must be industry-standard, not placeholder-grade: soft textures over primitives, rings over filled discs, trauma shake with rotation, eased kicks. VFX textures are generated and uploaded as image assets (see spec §15 milestone 3b); regenerate and re-upload rather than approximate with parts.
- Ask before cutting anything in spec §4.
- Format with `stylua src`.

## Workflow

- Code lives in `src/` and syncs via Rojo. The globe shell, altar, clouds and the prefab **templates** (`ServerStorage.Prefabs`) are built **in Studio through the Roblox Studio MCP**; the place file is the source of truth for them. Prefab **placement** is generated at server start by `src/server/WorldGen.luau` from a per-server seed (spec §15 milestone 4), never hand-placed.
- Rojo only manages `ReplicatedStorage.Shared`, `ServerScriptService.Server` and `StarterPlayerScripts.Client`. Do not add `$path` entries for Workspace or prefab folders, or Rojo will overwrite Studio-built content.
- Before any playtest through the Studio MCP, confirm Rojo has synced (read a changed script's `Source` in Studio). `rojo serve` has silently stalled on this OneDrive folder before; if it has, restart it and ask the user to click Connect.
- The world is a globe (spec §15 milestone 3a): the surface is an analytic sphere (`shared/Globe.luau`), never a collider; every ground query goes through `Globe.raycast`; "up" is `ctx.Up`, never world Y; characters don't physically collide with anything. The visible terrain shell is generated from `Planet.Radius`/`Center` in Studio, not dragged.
- Destructible templates are Models with the `Destructible` tag and a `Prefab` attribute naming their `Destructibles.Catalog` entry, pivot at the base, Y up; their parts are their chunks (anchored, `CanQuery` on, `CanCollide` off). Build them in Studio; WorldGen clones them under `workspace.World.Destructibles`.
- Stop at the end of each milestone for review in Studio. Don't take screenshots or videos; when something needs visual or feel verification, ask the user to check it in Studio.
- Touch devices get `Movement/TouchControls.luau` (thumbstick, drag-look, JUMP, PUNCH and BLAST buttons), which feeds the same `Input` snapshot as the keyboard. New inputs need a touch mapping there and a `TOUCH_KEYS` entry in the cheat sheet. Test the layout with Studio's device emulator.
- Keep the tester cheat sheet current: every new *input* gets a row in `SECTIONS` in `src/client/UI/ControlsHud.luau` in the same change (keycap or action chips plus a label of one or two words, no numbers). Tricks stay a short list of two or three (review decisions at milestones 5 and 6); don't add every mechanic. Tap and hold on one button share a row ("TAP / HOLD").

## Performance rules

- Anchored by default. Destructibles stay anchored until broken (spec §5).
- Turn off `CanTouch`, `CanQuery` and `CastShadow` on parts that don't need them (decor, small debris, chunks).
- MeshParts use `CollisionFidelity = Box` (or `Hull` when shape matters) and `RenderFidelity = Automatic`. Avoid unions and CSG.
- Keep part counts low: prefer one MeshPart over many primitives. Group prefabs as Models with a `PrimaryPart` and set `ModelStreamingMode` deliberately (`Persistent` only for shell, halo, altar, rings).
- Pool everything spawned at runtime (chunks, decals, particles, beams); never `Instance.new` in a hot path. Client-only effects live under `workspace.CurrentCamera` so they don't replicate.
- Respect the per-client budgets in spec §4.12 and §12, and drop quality on mobile (spec §11).
- No per-frame `FindFirstChild`/`GetDescendants`/`GetPartBoundsInRadius` over large sets without spatial filtering; cache references and use `OverlapParams` filters.
- Remotes: batch and rate-limit (spec §13). Never send per-frame remotes.
