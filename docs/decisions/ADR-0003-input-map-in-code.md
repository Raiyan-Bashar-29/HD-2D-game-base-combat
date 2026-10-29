# ADR-0003 — Input actions are declared in code, not in `project.godot`

**Status:** Accepted, 2026-08-23

## Context
Godot stores input actions in `project.godot`, serialising each binding as an
`Object(InputEventKey, "resource_local_to_scene":false, ..., "physical_keycode":87, ...)`
blob with every property spelled out.

## Decision
Actions are declared in `src/systems/input/actions.gd`, registered via `InputMap` at startup,
with name constants exposed for gameplay code to reference.

## Why
1. Those serialised blobs are unreadable in a diff and painful to hand-edit.
2. Constants mean a typo in an action name is a **parse error**, not a control that silently
   does nothing. `Actions.INTERACT` cannot be misspelled; `"interakt"` can.
3. The same declaration list feeds the future rebinding UI and the button-glyph lookup, so
   there is one source of truth rather than three.
4. `physical_keycode` is used throughout, so WASD stays physically in place on AZERTY and
   Dvorak keyboards.

## Costs, accepted
**The editor's Project Settings > Input Map panel will look empty,** because the actions do
not exist until the game runs. Anyone opening that panel expecting to see bindings will be
briefly confused. Godot's built-in `ui_*` actions still work, so editor UI navigation is
unaffected.

## Revisit if
A designer rather than a programmer needs to edit bindings without running the game.
