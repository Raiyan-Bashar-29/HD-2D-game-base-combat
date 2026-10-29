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
