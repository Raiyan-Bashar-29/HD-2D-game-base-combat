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

## 2026-10-29 — C1.1 · Gate the combat record and give it a version

**Did.** Added these:
- `[combat] core/version="0.1.0"` in `project.godot`;
- `src/core/util/combat_version.gd` (`CombatVersion.current()`);
- one boot log line, `combat 0.1.0`;
- `tests/unit/combat_record_test.gd`;
- a Releases list in `COMBAT.md`.

**Why.** C0.1 and C1.0 left two gaps open:
- a C row missing from the board was caught by nothing;
- the fork had no version of its own, so there was nothing to bump once code arrived.

**Connects.**
- **A sibling, not a widening.** The plan said to parameterise `TemplateVersion` and widen
  `record_shape_test.gd` and `version_test.gd`. All three are upstream files, and every line
  changed in one is a line a `git merge template/main` can conflict on. So the fork's gates live
  in files upstream does not have, and they ask upstream's questions of this fork's documents.
- **The banner is a separate line.** Upstream's banner stays byte-identical. The only upstream
  files touched are `log.gd` (three lines appended after the banner), `project.godot` (a new
  section after `[template]`) and `tests/test_runner.gd` (one `CASES` line).

**Verified.**
- Red first: the new case failed 4 times, on the undeclared version, `current()`, the missing
  banner, and `COMBAT.md` stating no version.
- After the fix, see the PR for the counts.

**Unblocks.** C1.2.

**Gaps.** None for this row.

## 2026-10-29 — C1.2 · Stats and ordered modifiers

**Did.**
- `src/content/combat/stat_modifier.gd`: a `StatModifier` Resource made of a stat, an op
  (`ADD`, `MULTIPLY` or `OVERRIDE`), a value and a source, plus `problems()`.
- `src/systems/combat/stat_sheet.gd`: a pure `StatSheet` with `set_base`, `base`, `add`,
  `remove_from(source)` and `value`.
- `tests/unit/stat_sheet_test.gd`, 14 assertions.
- Combat `0.2.0`.

**Why.** Every later row reads a stat: damage reads attack and defence, vitals read `max_hp`, and
statuses add modifiers. Nothing in the base had a modifier concept.

**Connects.**
- **The order is the formula: (base + every ADD) x every MULTIPLY, unless an OVERRIDE exists.**
  It is fixed, so equipment load order never changes a character. MULTIPLY stacks by product.
- **A modifier leaves by its source id, never by object identity.** That is the only kind of
  removal that survives a save, and it is how C1.5's statuses will clean up after themselves.
- **Stat names are free StringNames, `Attributes`' rule.** The base knows no stat names.
- **A sheet is never saved.** It is rebuilt from what is saved, so it cannot disagree with it.
- **Nothing upstream changed** apart from one `CASES` line.

**Verified.**
- Red first: with `value()` stubbed to return the base, 7 of the 14 failed.
- Restored: suite `2707 passed, 0 failed`.
- All seven checkers exit 0.

**Unblocks.** C1.3, vitals, whose maximum is a sheet's `max_<pool>`.

**Gaps.** No sheet is attached to a character yet. That is C1.6's `Combatant`.

## 2026-10-29 — C1.3 · Vitals

**Did.**
- `src/gameplay/combat/vitals.gd`: a `Vitals` component, found by `of(who)`. It has `key`,
  `maximum`, `current`, `change`, `set_to`, `is_defeated` and `revive`. A `restore_all` was written and removed: `check_methods.gd` failed it, because nothing called it yet.
- Three signals in a new combat section at the end of `events.gd`: `vitals_changed`,
  `combatant_defeated` and `combatant_revived`.
- `tests/unit/vitals_test.gd`, 21 assertions.
- Combat `0.3.0`.

**Why.** Every formula needs a number that falls and a moment it reaches zero.

**Connects.**
- **The current value is stored in `Flags` as `vital/<who>/<pool>`, `Attributes`' rule.** That
  gives saving, new-game reset and gate-readability for free, and `save_system.gd` stays
  untouched.
- **The maximum is the C1.2 sheet's `max_<pool>`.** A sword or a curse changes it as a
  modifier.
- **An unset pool is full,** so nothing has to be written to start a character.
- **Defeat is an edge, fired once.** A heal cannot lift a defeated combatant; only `revive()`
  can. "A heal spell on a fallen ally does nothing" is a decision the base makes once, not one
  each formula re-decides.

**Verified.**
- Red first: with the "announce only real changes" and "defeated cannot be healed" guards
  removed, 7 failed.
- Restored: suite `2729 passed, 0 failed`. The save round-trip goes through
  `SaveSystem.save_to_slot` and `load_from_slot` under `SaveFixture`.

**Unblocks.** C1.4, the damage pipeline, whose result is applied through `Vitals.change`.

**Gaps.**
- Each `Vitals` holds its own sheet until C1.6's `Combatant` supplies a shared one.
- The signals are appended to an upstream file, so a later upstream append at the same place
  would conflict. Resolving it means keeping both blocks.

## 2026-10-29 — C1.4 · Damage pipeline

**Did.**
- In `src/systems/combat/`: `DamageRequest` (two sheets, a power, an element), `DamageResult`
  (amount, critical, element, the stages that ran, `total()`), `DamageStage` (the base) and
  `DamageFormula` (an ordered `stages` list, `resolve(request, rng)` and `standard()`).
- Four shipped stages: `AttackDefenceStage`, `ElementStage`, `CritStage`, `VarianceStage`.
- `tests/unit/damage_formula_test.gd`, 23 assertions.
- Combat `0.4.0`.

**Why.** Every formula, turn-based, action and hybrid, resolves a hit. If each one did its own
arithmetic, "a fire sword does more to ice enemies" would be written three times.

**Connects.**
- **The formula is data.** A `DamageFormula` is a resource whose stages are a list, so a game
  swaps the formula in a `.tres` and never edits `src/`. That is the swap point C1 promised.
- **No separate `DamageResolver`.** The plan had one, but a resolver with no state of its own
  is just the formula's own method. One class fewer, and the same seam.
- **Pure and seeded.** Stages draw only from the `rng` they are handed, and crit and variance
  always draw exactly once. So whether a hit was critical never shifts later numbers, and a
  seeded fight replays exactly. That is what C2's headless battles will rely on.
- **Diminishing defence by default:** `softness / (softness + defence)`, so defence never makes
  a hit zero and nothing needs a "minimum 1" patch.
- **Resistance is a stat** (`resist_<element>`), so C1.5's statuses change it as modifiers.
  Above 1 it absorbs: the result goes negative, and the pipeline does not clamp it away.
- **In systems, not content,** because a stage reads a `StatSheet`, and content may not depend
  on systems.

**Verified.**
- Red first: with `resolve` skipping its stages, 11 failed.
- Restored: suite `2752 passed, 0 failed`, boot `0 warnings, 0 errors` printing `combat 0.4.0`,
  all seven checkers exit 0. `git merge template/main`: already up to date.

**Unblocks.** C1.5, status effects. Their modifiers feed the sheets this pipeline reads.

**Gaps.**
- Nothing applies a result to a `Vitals` yet. That is C1.6's `Combatant.receive`.
- Ten code files, over the board's "about 8". Eight of them are one-class files under 40 lines,
  and splitting the row would have shipped a formula with no stages.

## 2026-10-29 — C1.5 · Status effects

**Did.**
- `src/content/combat/status_effect.gd`: a `StatusEffect` `ContentEntry`:
  - a unit, TURNS or SECONDS, and a duration;
  - a stacking rule, REFRESH, STACK (up to `max_stacks`) or IGNORE;
  - modifiers;
  - an optional tick (`tick_pool`, `tick_change`, `tick_interval`);
  - `problems()`.
- `src/content/combat/status_db.gd`: `StatusDb`, `ItemDb`'s shape, reading `data/statuses/`.
- `src/gameplay/combat/status_set.gd`: a `StatusSet` component with `apply`, `stacks`,
  `remaining`, `cure`, `tick_turn` and `tick_seconds`, and its own save section.
- `Events.status_applied` and `status_expired`.
- `tests/unit/status_set_test.gd`, 27 assertions.
- Combat `0.5.0`.

**Why.** Every formula has statuses: poison, haste, stagger, pressure (C4 is defined as C1
modifiers). Duration in TURNS or SECONDS is the one switch that lets a turn-based and a
real-time formula share the same status file.

**Connects.**
- **A set never ticks itself.** The formula owns the clock: a battle's turn end, an action
  scene's `_physics_process`, the hybrid's scaled time. So C4's slowed menu and C5's pause need
  nothing here.
- **Modifiers leave by source, the C1.2 rule.** An author leaves the source blank, and the set
  stamps each modifier with the status id. Expiry, cure, a new game and a load then remove
  exactly what the status added.
- **Its own save section, `Inventory`'s pattern.** `save_system.gd` is untouched. The section
  stores ids, time left and stacks, never the sheet. A status whose `.tres` has gone is dropped
  with a warning, because nothing could know what it changed.
- **One change from the plan:** the tick is a pool change, not a `DamageRequest`. Content cannot
  depend on systems, and most games' poison ignores defence anyway. A tick resolved through a
  formula belongs to C1.6, where a `Combatant` holds both.

**Verified.**
- Red first, with the tick and the modifier clean-up stubbed: 6 failed. One of them is the save
  test, whose rebuild doubled the modifiers. Restored.
- Suite `2781 passed, 0 failed`. Boot `0 warnings, 0 errors`, printing `combat 0.5.0`. All seven
  checkers exit 0.
- The suite's 19 `Parse JSON failed` lines are on `main` too. They come from the corrupt-save
  cases, which feed it bad JSON on purpose.

**Unblocks.** C1.6, `Combatant`, which gives `Vitals` and `StatusSet` one shared sheet.

**Gaps.**
- Statuses have no `name_key` yet. Nothing shows one until C2's battle UI, which adds it.
- `check_content.gd` does not scan `data/statuses/`. Widening it means editing an upstream
  tool; until then `StatusDb.problems()` holds the errors, and `StatusSet.apply` refuses a broken status.
