# ADR-0008 — Combat is in scope for this repository, and only this one

**Status:** Accepted, 2026-10-29. Applies to `HD-2D-game-base-combat` only.

## Context

This repository began as a full copy of `HD-2D-game-base-non-combat-` at `aaf281b` (base
`5.16.2`), history and all. In that repository **no combat is a TEMPLATE RULE**
([ADR-0007](ADR-0007-template-default-vs-game-choice.md)), and the ADR says what wanting combat
means: *"Wanting to is a fork of the template, not a game."*

This repository is that fork. The owner wants a second base holding the combat formulas, each as
a reusable building block:

- turn-based;
- action (real-time, in the field);
- a hybrid of the two (semi-real-time, an ATB gauge spent from a command menu while the action
  keeps running, as in the FF7 Remake).

The aim is still a base and not a game.

## Decision

- **In this repository, combat is in scope.** The no-combat TEMPLATE RULE does not apply here.
  Every other line of ADR-0007 still applies.
- **Everything else is unchanged and stays a TEMPLATE RULE here too:**
  - the layer rule (`check_layers.gd`);
  - no file under `src/` or `tests/` may name demo content (`check_boundary.gd`);
  - art is deferred;
  - static typing;
  - no player-facing literals;
  - one package at a time;
  - nothing is done until the engine has run it.
- **The non-combat repository stays upstream.** It is this repository's `template` remote. Its
  fixes arrive through `git merge template/main`, exactly as
  [`UPGRADING.md`](../UPGRADING.md) describes for any fork. **Combat code never goes upstream.**
  A seam goes upstream only if a non-combat game could use it too, and it lands there first, as
  a row on that repository's board.
- **Combat is three formulas on one shared core**, which also makes each a choice of default
  for a game:
  - **C1 core:** stats, vitals, damage pipeline, statuses, factions, a combatant component.
  - **C2 turn-based:** encounter, battle scene, a pluggable turn scheduler, commands, battle AI.
  - **C3 action:** hitboxes, an attack state machine, enemy behaviour on `NpcBrain`.
  - **C4 hybrid:** built only from C2 and C3 parts. That is the test that each of them is a
    real formula.
  - **C5:** mix-and-match and hardening.

  Which formula a game uses is a **TEMPLATE DEFAULT** with a seam, never a rule.
- **This repository's own records live in their own files**, so that a merge from upstream does
  not conflict on every package:
  - [`COMBAT.md`](../COMBAT.md) is the situation, the phases and the board;
  - [`COMBAT_DEVLOG.md`](../COMBAT_DEVLOG.md) is the log.

  Upstream's `CONTEXT.md`, `ROADMAP.md`, `WORK_PACKAGES.md` and `DEVLOG.md` are left as
  upstream's record. Edits to them are kept to a pointer line.

## Why

- **A fork, not a branch.** ADR-0007's test for a rule is whether a seam exists. No seam can
  turn combat on in a repository whose checkers and docs forbid it. A long-lived branch would
  mean two contradictory `main`s in one place.
- **History kept, upstream linked.** `UPGRADING.md` was performed against a real fork. Starting
  this repository from the same history is what makes that procedure apply here, unchanged.
- **Separate record files.** Both repositories appending to the end of `DEVLOG.md` would
  conflict on every upstream merge. Separate files cost one pointer each and conflict never.

## The honest limit

- **`tests/unit/record_shape_test.gd` does not gate this repository's package ids yet.** It
  matches `T` and `WP` ids in `DEVLOG.md`, so C-rows in `COMBAT_DEVLOG.md` are not
  cross-checked against the board. Widening it is a code change, and belongs to the first
  package that changes code (C1), not to this documents-only one.
- **No `combat/version` key exists yet.** It is added with the first code that is released.
