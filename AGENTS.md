# Project working agreement

- The owner is the sole developer and has requested direct development on `main`.
  Do not create feature branches or PRs unless the owner asks for them.
- Preserve the accepted game direction in `docs/design-v0.2.md`; document the
  distinction between prototype features and the full design.
- Use Godot 4.5.2 / GDScript. Run `scripts/ci_check.py` for gameplay changes and
  updater tests for launcher changes. Keep source and generated builds separate.
- Main builds may publish only after checks pass. Updates must preserve saves,
  validate downloads before activation, and retain an offline playable version.
