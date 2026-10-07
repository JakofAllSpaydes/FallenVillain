# FALL — agent notes

- Design spec: `docs/SPEC.md`. Build order and working rules are in §14; follow milestones in order.
- Rojo 7 project (`default.project.json`), Luau, tools pinned in `aftman.toml`.
- Every tunable number goes in `src/shared/Tuning.luau`, never inline.
- Every effect goes through `FeelTable`, never called directly from a movement state.
- Ask before cutting anything in spec §4.
- Format with `stylua src`.
