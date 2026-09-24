# Project working agreement

- The owner is the sole developer and has requested direct development on `main`.
  Do not create feature branches or PRs unless the owner asks for them.
- Preserve the loot/economy direction in `docs/design-v0.2.md`; combat and UI
  are superseded by the owner-approved pivot in `docs/card-combat-v0.3.md`; document the
  distinction between prototype features and the full design. Fog exploration and
  camp economy follow `docs/exploration-economy-v0.4.md`.
- Use Godot 4.5.2 / GDScript. Run `scripts/ci_check.py` for gameplay changes and
  updater tests for launcher changes. Keep source and generated builds separate.
- Main builds may publish only after checks pass. Updates must preserve saves,
  validate downloads before activation, and retain an offline playable version.
