# Combat devlog

This repository's own log, kept apart from upstream's `DEVLOG.md` so that merging upstream never
conflicts on it (ADR-0008). New entries go at the bottom, under `## date — Cn.m · title`.

## 2026-10-29 — C0.1 · Fork and re-scope

**Did.** Seeded this repository from `HD-2D-game-base-non-combat-` `main` at `aaf281b` (base
`5.16.2`), keeping its full history, 223 commits:

- added the upstream as the `template` remote;
- merged this repository's GitHub-created initial commit with `--allow-unrelated-histories`;
- resolved its one conflict (`README.md`) to the template's text, then edited that text.

Wrote:

- [ADR-0008](decisions/ADR-0008-combat-is-in-scope.md), which scopes combat in for this
  repository only;
- [`COMBAT.md`](COMBAT.md): situation, phases C0–C5, board;
- this log;
- pointer lines in `CLAUDE.md`, `README.md` and `CONTEXT.md`.

No file under `src/`, `tests/` or `tools/` changed.

**Why.**

- In upstream, no combat is a TEMPLATE RULE, and ADR-0007 names the way out: a fork. The owner
  chose a linked separate repository over a branch.
- Formulas: turn-based, action, and a semi-real-time hybrid like the FF7 Remake.

**Connects.**

- `UPGRADING.md` already describes, and was performed for, exactly this relationship. This
  repository is a fork that keeps the template as a remote.
- Upstream's records stay upstream's. This repository's live in `COMBAT.md` and here, so the
  merge only conflicts on the three pointer lines.

**Verified.** See this package's PR for the ladder run. Import, boot, suite and all seven checkers
were run on the seeded tree.

**Unblocks.** C1.0, planning the shared combat core.

**Gaps.**

- `record_shape_test.gd` does not gate C ids yet, and no `combat/version` key exists. Both
  belong to C1, the first package that changes code.
- ~~The upgrade path is merged "Already up to date" today.~~ **Tested for real the same day.**
  Upstream shipped `5.16.3` (T7.0, `docs/PLAYTEST.md`), and `git merge template/main` into
  this branch auto-merged 9 files with **no conflict**, including `CONTEXT.md`, where this
  fork's pointer sits above the lines upstream changed. Ladder after the merge: import clean,
  boot `0 warnings, 0 errors`, suite `2683 passed, 0 failed`, all seven checkers exit 0.

## 2026-10-29 — C1.0 · Plan the shared combat core

**Did.** Wrote C1's rows, C1.1 to C1.7, onto `COMBAT.md`'s board, after reading the code each
row will build on.

**Why.** C1 is the core that every combat formula uses: turn-based, action and the hybrid. Its
seams have to be the base's own, or C2 to C4 inherit a second way of doing everything.

**Connects.** These reuse decisions are recorded so no row re-derives them:
- **Components** are a `Node` child found by a static `of(who)` type lookup, as in
  `Inventory` and `Equipment`. That is the shape for `Vitals`, `StatusSet` and `Combatant`.
- **Per-actor numbers live in `Flags`**, as `Attributes` and `Standing` do. That gives save,
  new-game reset and `flag_changed` for free, so `Vitals` uses it.
- **`save_system.gd` stays untouched.** It is at 179 of its 180-line budget, so `StatusSet`
  registers a section the way `Inventory` does.
- **Each signal is declared by the row that emits it**, because `check_signals.gd` fails a
  declaration with no emitter.
- **No modifier system exists yet.** C1.2 is new ground, and `Attributes.multiplier` is the only
  precedent.

**Verified.** Documents only. Import, the suite and all seven checkers were run; see the PR.

**Unblocks.** C1.1.

**Gaps.**
- C1.1 is what makes this log's headings gated. Until it lands, a C row missing from the board
  is caught by nothing.
