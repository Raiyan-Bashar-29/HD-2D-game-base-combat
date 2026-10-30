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

## 2026-10-29 — C1.6 · Factions, targeting and `Combatant`

**Did.**
- `src/content/combat/faction_table.gd`: `FactionTable`, with `is_hostile`, `allows(filter, …)`
  and the `Target` enum (SELF, ALLY, ENEMY, ANY).
- `src/gameplay/combat/combatant.gd`: a `Combatant` component with `combatant_id`, `faction`,
  `formula`, `factions`, `damage_pool`, a shared `sheet`, `of`, `can_target`, `hit` and
  `receive`.
- `Events.combatant_damaged(who, by, amount, critical)`.
- `tests/unit/combatant_test.gd`, 24 assertions.
- Merged upstream `5.16.4` (T7.1, CI actions off Node 20). No conflict.
- Combat `0.6.0`.

**Why.** C1.2 to C1.5 built the parts; this row is what makes an actor combat-capable. Every
formula from C2 on talks to a `Combatant`, not to its parts.

**Connects.**
- **One sheet.** `Combatant._ready` hands its sheet and id to its `Vitals` and `StatusSet`
  siblings. A status that raises `max_hp` then raises the maximum `Vitals` clamps to, and every
  signal names the same `who`. This closes C1.3's and C1.5's "until C1.6" gaps.
- **The attacker's formula resolves; the defender only applies.** A skill's formula belongs to
  the one using it, and a preview resolved with the same seed shows exactly what lands.
- **Factions need no table for the common case:** the same faction is allied and different
  factions are hostile. A table lists exceptions, so a game with three factions at war needs
  nothing authored at all.
- **ALLY includes the user, ENEMY never does.** A party-wide heal reaches its caster, and
  "hit every enemy" can never hit yourself, even in a faction that fights itself.

**Verified.**
- Red first: with the sheet unshared and `receive` applying nothing, 5 failed. Restored.
- Suite `2808 passed, 0 failed`. Boot `0 warnings, 0 errors`, printing `combat 0.6.0`. All seven
  checkers exit 0.

**Unblocks.** C1.7, the training dummy, which closes phase C1.

**Gaps.**
- A status tick is still a raw pool change. Routing it through a formula would need a
  `Combatant` for the tick's source, which a poison applied by a trap does not have. That is a
  C2/C3 decision, made when a formula needs it.
- `Combatant` sets its siblings' ids but not `StatusSet.save_id`. An author still gives each
  combatant's `StatusSet` its own, Inventory's rule.

## 2026-10-29 — C1.7 · A training dummy you can hit

**Did.**
- `StrikeTarget` (`src/gameplay/interactables/strike_target.gd`): an `Interactable` whose
  `Combatant` child takes one resolved hit when used. It toasts the result by key, with
  `{amount}`, `{left}` and `{max}`, uses a separate key on a critical, refuses a defeated target,
  or revives it when `revive_when_defeated` is set.
- `Combatant.base_stats`, which copies the authored base values into the sheet on ready, and
  `Combatant.resolving_formula()`, now shared by `hit` and the strike.
- `scenes/objects/strike_target.tscn`, a generic prefab: a wooden post, a reach sphere, a body,
  `Vitals` and `Combatant`.
- The courtyard's `TrainingDummy`, an instance of the prefab with 30 hp and 20 defence. It
  revives, and has three strings.
- `strike_target_test.gd` (14). § Make something you can hit in `AUTHORING.md`.
- Combat `0.7.0`.

**Why.** C1.1 to C1.6 were proven only by fixtures. This row runs the core inside the game: an
area, the interaction sensor, the toast.

**Connects.**
- **The interactor's `Combatant` resolves**, the same as `Combatant.hit`. One with none, like
  the template's player, strikes with an empty sheet through the target's own formula. So the
  dummy works now, and C2/C3 only have to give the player a `Combatant`.
- **The dummy's HP is a flag**, `vital/training_dummy/hp`, so it is saved and reset like any
  other.

**Verified.**
- Red first: with `perform` stubbed, 9 failed. Restored.
- Suite `2823 passed, 0 failed`. Boot `0 warnings, 0 errors`. All seven checkers exit 0.
- Stripped run, done locally exactly as CI does: `2745 passed, 0 failed, 25 skipped`, and all
  six checkers it runs exit 0.
- Windowed capture under `xvfb-run`: the post renders in the courtyard, and after one strike the
  toast reads "Thwack. 7 damage, 23 of 30 left." That is 8 power against 20 defence (6.67), then
  crit and variance.

**Unblocks.** Phase C2, starting with its planning row C2.0. **Phase C1 is closed.**

**Gaps.**
- **One change from the plan.** The row said "data and a scene only", but no existing
  interactable could hit anything, so one `src/` class was added. It is generic, and nothing
  under `src/` names the dummy, so the boundary rule holds.
- The prompt verb is `USE`. A `STRIKE` verb would edit upstream's `GameEnums`, which this fork
  avoids, so a game that wants one adds it.
- The dummy's body is not in `navmesh_source`. It stands clear of the keeper's routes; an author
  placing a target on a walked path adds the group.
- The courtyard edit is one appended instance plus one `ext_resource`. It is the fork's only
  change to an upstream scene, and a merge that touches the courtyard may conflict there.

## 2026-10-29 — C2.0 · Plan the turn-based formula

**Did.** Wrote C2's nine rows (C2.1 to C2.9) onto the board in `COMBAT.md`, and a short
"Settled by C2.0" list under § C2. This row is documents only, so the combat version is
unchanged at `0.7.0`.

**Why.** Each phase opens by planning against the code, as C1.0 did. Rows guessed from intent
are rows that get renumbered.

**Connects.** What was read, and what it decided:
- **`ui_root.gd`'s pause table.** `WorldRoot` is pausable under any modal screen. So a battle
  is a modal layer over the frozen field, not an area. It returns exactly, with no save, no
  reload and no `Director` change, and `Director`'s MUST NOT line stands.
- **`director.gd`.** It must not know what is inside an area. That confirms the battle is not
  routed through it.
- **The layer rule.** Anything holding a `Combatant` is gameplay. So the battle runtime goes
  in gameplay (C2.4), and the scheduler, which orders ids by a number, goes in systems (C2.1,
  C2.2).
- **`flag_query.gd`.** It is the one condition reader, a closed set. `BattleBrain` (C2.5) reuses
  it and adds a single pool-fraction test, not an expression language.
- **`Inventory.of(who).add`.** It is the loot seam (C2.8).
- **Party and enemies are data.** A battle builds its own `Combatant`s from definitions
  (C2.6). That is why the template's player still needs none.

**Verified.** Suite `2824 passed, 0 failed`; all seven checkers exit 0.
`combat_record_test` holds the new C ids against the board.

**Unblocks.** C2.1, the turn scheduler.

**Gaps.**
- Whether the battle screen draws 3D combatants through a `SubViewport` or uses 2D placeholders
  is C2.7's call, made against a capture.
- The CTB delay formula's constants (C2.2) are a template default, to be tuned in C2.9's
  playtest.

## 2026-10-29 — C2.1 · `TurnScheduler` and speed-sorted rounds

**Did.**
- `src/systems/combat/turn_scheduler.gd`:
  - the base class holds the roster (`join`, `leave`, `has`, `speed_of`);
  - its subclass gives the order through `next()` and `preview(n)`.
- `round_scheduler.gd`, the template default: rounds run fastest first, with ties going to
  whoever joined first, and `round_number()` counts them.
- `turn_scheduler_test.gd` (12).
- Combat `0.8.0`.

**Why.** The scheduler is the swap point C2.0 named. Rounds against CTB is the main way
turn-based games differ, so it is built first and kept apart from everything else.

**Connects.**
- **It orders ids by a number and nothing else.** That keeps it in systems: it holds no
  `Combatant`, so the layer rule holds when C2.4's battle (gameplay) feeds it speeds.
- **It is a `Resource`, as `DamageFormula` is.** So C2.6's encounter can choose one in data.
  Its roster is runtime state, and the battle takes a `duplicate()`.
- **The order needs no randomness.** Ties are settled by join order. A game wanting random tie
  breaks jitters the speed it passes in.
- **A round is ordered when it starts.** A newcomer, or a speed changed by a status, counts
  from the next round. Anyone who leaves is skipped. `preview` walks the same queue, so the
  turn-order strip (C2.7) can never disagree with the battle.

**Verified.**
- Red first: with `next` stubbed, 11 failed. Restored.
- Suite `2837 passed, 0 failed`. Boot `0 warnings, 0 errors`, printing `combat 0.8.0`. All seven checkers exit 0.

**Unblocks.** C2.2, the CTB queue. It reuses the base's roster and must pass the same order
contract.

**Gaps.** `preview` in a round scheduler assumes nobody joins or leaves before the previewed
turns happen. That is fine for a strip that is redrawn on every turn.

## 2026-10-29 — C2.2 · A CTB queue, the second scheduler

**Did.**
- `src/systems/combat/ctb_scheduler.gd`:
  - each actor waits `delay / speed` ticks between turns;
  - whoever's wait runs out first acts, every other wait drops by the same amount, and the
    actor's own wait starts again;
  - `delay_by(id, ticks)` pushes an actor back, `wait_of(id)` reads its wait, and `delay` is
    exported.
- `ctb_scheduler_test.gd` (15).
- Combat `0.9.0`.

**Why.** C2.0 named the scheduler as the swap point. A second, genuinely different order is what
proves that claim.

**Connects.**
- **The order contract runs unchanged against both `RoundScheduler` and `CtbScheduler`:** an
  empty roster has no turn, the fastest acts first, `preview` agrees with `next`, and a leaver
  never acts again. C2.4's battle may assume only those, so either scheduler drops in.
- **The same tie rule as rounds:** whoever joined first. Neither scheduler ever draws a random
  number.
- **A tick is an ordering unit, not time.** C4's real-time gauge is a different scheduler built
  from the same base, not this one run against a clock.
- **`delay_by` is the seam for "slow" and for heavy skills.** C2.3's skills can name a delay,
  and C2.4 applies it.

**Verified.**
- Red first: with `next` stubbed, 6 failed. Restored.
- Suite `2853 passed, 0 failed`. Boot `0 warnings, 0 errors`, printing `combat 0.9.0`. All seven
  checkers exit 0.

**Unblocks.** C2.3, skills and commands as data.

**Gaps.** A speed change mid-wait keeps the running wait, and only the next wait uses the new
speed. A haste that should take effect at once can use `delay_by` with a negative number; a
rescale-on-change rule waits until a game asks for one.

## 2026-10-29 — C2.3 · Skills and commands as data

**Did.**
- `src/content/combat/skill.gd`, `ContentEntry` content: a cost pool and amount, a
  `FactionTable.Target` filter, a ONE or ALL scope, power, an element, statuses and their
  chance, and a CTB `delay`. Its `problems()` catches:
  - no name;
  - a negative cost, or a cost with no pool;
  - a skill that does nothing;
  - a heal aimed at enemies;
  - an empty status slot.
- `battle_command.gd`: ATTACK, SKILL, ITEM, DEFEND or FLEE. SKILL and ITEM carry a `Skill`, and
  ITEM also carries an `item_id`.
- `skill_db.gd`, the shape of `StatusDb`.
- `skill_test.gd` (14).
- Combat `0.10.0`.

**Why.** C2.0's rule is that skills are data. The battle (C2.4) is the only code that runs them,
so a fire spell, a heal and a poison dart differ only in numbers.

**Connects.**
- **Content only.** `Skill` reads `FactionTable` and `StatusEffect`, both content, so the layer
  rule holds. The formula is named by the user's `Combatant`, not by the skill.
- **An item is a skill plus what it spends.** A potion and a heal spell share every field, and
  `Inventory` (upstream) stays the item's owner.
- **`delay` feeds C2.2's `CtbScheduler.delay_by`.** A round scheduler ignores it.
- **The content check without touching upstream.** `skill_test.gd` asserts that `SkillDb` and
  `StatusDb` report nothing over the real `data/`. That closes C1.5's "`check_content` does not
  scan statuses" gap, and passes trivially in the stripped run.

**Verified.**
- Red first: with both `problems()` stubbed, 8 failed. Restored.
- Suite `2868 passed, 0 failed`. Boot `0 warnings, 0 errors`, printing `combat 0.10.0`. All
  seven checkers exit 0.

**Unblocks.** C2.4, the battle runtime, which reads these.

**Gaps.**
- A skill's `name_key` is checked for presence only, not against the CSV. Upstream's checker
  does that for its own content. The combat equivalent arrives with the first shipped skill
  (C2.9), as a CSV-key assertion in `skill_test.gd`.
- Commands have no catalogue. They live inline in a combatant definition (C2.6), and their
  problems are reported through it.

## 2026-10-29 — C2.4 · The battle runtime

**Did.**
- `src/gameplay/combat/battle.gd`. It holds two sides of `Combatant`s, a scheduler (a duplicate,
  `RoundScheduler` by default) and a seeded rng.
  - Turn flow: `start()`, then `next_turn()`, `current()`, `act(command, targets)`, `outcome()`,
    plus `targets_for(command)`.
  - The commands are ATTACK, SKILL, ITEM, DEFEND and FLEE.
- `Events.battle_started(enemy_ids)` and `battle_ended(outcome)`.
- `battle_test.gd` (20).
- Combat `0.11.0`.

**Why.** C2.1 to C2.3 built the order and the data. This is the one piece of code that runs
them, and it is what C2.5's AI, C2.7's screen and C2.9's demo all drive.

**Connects.**
- **Calls only, no `_process`** (C2.0). A whole fight in the test runs in one frame.
- **The commands use C1:**
  - a hit is `Combatant.hit`, through the actor's own formula;
  - a cost and a heal go through `Vitals.change`;
  - a status goes through `StatusSet.apply`;
  - a target goes through `Combatant.can_target`.
- **Statuses tick on the actor's own turn.** So a one-turn DEFEND lasts exactly until the
  defender acts again, and a poison that defeats someone skips their turn.
- **The scheduler only hears `join` and `leave`.** So it stays swappable. A skill's `delay`
  reaches it only when it is a `CtbScheduler`.
- **ITEM spends from an `Inventory` the caller hands in.** Without one, ITEM is refused.
  C2.8 wires the player's.
- **The bus carries the outcome as an int,** because `events.gd` lives in core, below gameplay.

**Verified.**
- Red first: with `act` stubbed, 12 failed. Restored.
- Suite `2889 passed, 0 failed`. Boot `0 warnings, 0 errors`, printing `combat 0.11.0`. All
  seven checkers exit 0.

**Unblocks.** C2.5, `BattleBrain`, which picks an enemy's command and targets from
`targets_for`.

**Gaps.**
- DEFEND's status is built in code with the id `status/defend`, so a save made mid-battle could
  not rebuild it. Battles do not save mid-fight, and a game wanting a different guard sets
  `defend_status`.
- A heal on an ALL scope heals everyone the filter allows, the user included (ALLY includes
  self, C1.6). That is the usual meaning, and it is noted here in case it surprises.

## 2026-10-29 — C2.5 · `BattleBrain`, the enemy AI

**Did.**
- `src/content/combat/brain_entry.gd`. An entry is a command and a weight, plus:
  - a target rule: FIRST, RANDOM, LOWEST_HP or SELF;
  - a `FlagQuery` condition (`condition_flag` / `_test` / `_value`);
  - an own-pool condition (`below_pool` under `below_fraction`).
- `battle_brain.gd`: a list of entries, with `problems()`.
- `src/gameplay/combat/battle_ai.gd`: `BattleAi.take_turn(battle, brain)`.
- `battle_ai_test.gd` (10).
- Combat `0.12.0`.

**Why.** A battle needs someone to play the other side. Keeping that as data is what lets an
author write "heal below half, burn things once the bridge falls" with no code.

**Connects.**
- **The conditions reuse `FlagQuery.passes`**, the same closed set dialogue and quests read. The
  only addition is the pool fraction, which a flag cannot express. That holds the C2.0 rule of
  no expression language.
- **It acts only through `Battle.act`.** Candidates come from `Battle.targets_for`, and an
  unaffordable cost rules an entry out before the draw. So the AI can never do anything a player
  could not.
- **Every draw is the battle's own seeded rng.** A seeded fight replays its choices exactly, and
  the test asserts that.
- **The same call serves enemies now,** auto-battle for the party in C5, and the hybrid's
  uncontrolled allies in C4.

**Verified.**
- Red first: with the weighted choice disabled, 3 failed. Restored.
- Suite `2900 passed, 0 failed`. Boot `0 warnings, 0 errors`, printing `combat 0.12.0`. All
  seven checkers exit 0.

**Unblocks.** C2.6, encounters and combatant definitions. A definition carries the brain.

**Gaps.** The pool condition supports "below" only. "Above", and conditions on a target's state
(for example "finish off whoever is weakest"), are LOWEST_HP's job today. A richer test waits
for a game that needs one.

## 2026-10-29 — C2.6 · Encounters and the field trigger

**Did.**
- `src/content/combat/combatant_def.gd`: an id, a name key, a faction, base stats, commands and
  a brain. Party and enemies share it.
- `encounter.gd`: the enemies, a ROUNDS or CTB turn order, `can_flee`, `flee_chance` and a music
  id.
- `encounter_db.gd`.
- `src/gameplay/combat/battle_setup.gd`: `build` and `release`.
- `src/gameplay/interactables/encounter_point.gd`.
- `Events.encounter_requested(encounter_id)`.
- `Battle.brains` and `brain_of`.
- `encounter_test.gd` (17).
- Combat `0.13.0`.

**Why.** A battle needs fighters built from data, and the field needs a way to ask for one.
This is the seam between the two.

**Connects.**
- **One definition for both sides** (C2.0). `BattleSetup` turns each one into C1.6's node shape
  (`Vitals`, `StatusSet`, `Combatant`) under a holder the caller owns.
- **Enemies leave no trace.** Their `vital/` flags are erased on build and on release, so a save
  after a fight never carries an enemy's hp. The party's are kept, so hp carries between fights.
- **The layer rule shaped two fields.** An encounter names its turn order as an enum, and a
  definition names no formula, because both of those are systems types and content may not
  depend on systems. `BattleSetup` (gameplay) maps the enum, and a fighter uses the standard
  formula.
- **`EncounterPoint` asks; it never builds.** C2.7's battle host answers
  `encounter_requested`, so a game's own trigger (a zone, a cutscene, a timer) emits the same
  signal and needs nothing else.
- **Fixed on the way:** `StatusDb`, `SkillDb` and `EncounterDb` now treat a missing directory as
  no content. C1.5 on had the suite logging an engine `Couldn't open directory` error for each,
  and so did the stripped run.

**Verified.**
- Red first, each stub run on its own: the enemy flag reset stubbed failed 2; the duplicate
  suffix stubbed failed 1. Run together they masked each other down to 1, so they were split.
  Restored.
- Suite `2918 passed, 0 failed`, and the only directory error left is upstream's deliberate one.
  Boot `0 warnings, 0 errors`, printing `combat 0.13.0`. All seven checkers exit 0.

**Unblocks.** C2.7, the battle screen: it hosts `encounter_requested`, builds with
`BattleSetup`, and drives turns with `BattleAi` for brains and the menu for the rest.

**Gaps.**
- `music` is stored but nothing plays it yet. C2.7's host does.
- A fighter's formula cannot be chosen in data. A game sets it on the built `Combatant`. A
  content-side formula reference waits for a game that needs a non-standard one per enemy.

## 2026-10-29 — C2.7 · The battle screen

**Did.**
- `src/ui/combat/battle_screen.gd`, a `MenuScreen`. It shows:
  - every fighter's hp line, and a "Next:" line from the scheduler's `preview`;
  - the player's menu: the definition's commands, or Attack / Defend / Flee;
  - target select with Back, for a command that needs one target;
  - a refusal line when a command cannot be done;
  - the outcome, with one Continue row.
- `battle_host.gd`. It answers `Events.encounter_requested`, builds the battle with
  `BattleSetup` under itself, and opens the screen.
- One `BattleHost` node in `game_root.tscn` beside `ScreenKeys`. That is one appended node and
  one `ext_resource`.
- `Battle.defs`, which `BattleSetup` fills, for names and menus.
- Twelve `ui.battle.*` strings.
- `battle_screen_test.gd` (16).
- Combat `0.14.0`.

**Why.** C2.0's decision was that a battle is a modal layer over the frozen field. This is that
layer, and the first time a person can play a fight.

**Connects.**
- **Modal and pausing** (`pauses_world`), so `UiRoot` freezes `WorldRoot`. The capture shows the
  courtyard dimmed and still behind the menu. Cancel cannot leave (`closes_on_cancel` false), so
  FLEE is the only way out.
- **The screen holds no rule.** It calls `next_turn`, `act` and `BattleAi.take_turn`, and redraws
  from the battle after every command. So the screen and the headless battle test cannot
  disagree.
- **Fighters need the tree.** Their sheet and pools are wired in `_ready`. Built under an
  unopened screen, a fighter's `Vitals` answered for the default owner, and the enemy-flag erase
  would have erased the PLAYER's hp. The host builds them under itself, and `BattleSetup` now
  logs an error for a holder outside the tree.
- **Closing releases the fighters** (`_closed`, then `BattleSetup.release`), so no enemy flag
  outlives the screen.

**Verified.**
- Red first: with the screen not playing enemy turns, the first run hung in the test's "attack
  until it ends" loop. The loop is now bounded to 20. Rerun, 4 failed. Restored.
- Suite `2935 passed, 0 failed`. Boot `0 warnings, 0 errors` with the host in the root, printing `combat 0.14.0`. All
  seven checkers exit 0.
- Windowed capture under `xvfb-run`, with a throwaway driver (not committed) that builds a 2v2
  fight and plays one attack. The menu draws over the dimmed, paused courtyard: four hp lines,
  the turn order and Attack / Defend / Flee.

**Unblocks.** C2.8: rewards, levels, and the `Party` roster that replaces `BattleHost.party`.

**Gaps.**
- `Encounter.music` is still not played. C2.9's demo wires it, with the field's music restored
  after.
- Hp is text, not bars, and there is no damage pop-up or animation. Those are a game's styling,
  or C5 hardening.
- `UiRoot` closes a screen deferred, so the test closes through the stack after checking that
  Continue asked to close.

## 2026-10-29 — C2.8 · Rewards, levels and the party

**Did.**
- `src/content/combat/level_curve.gd`: experience to reach level L is `base * (L-1)^exponent`,
  with a max level and per-level `growth` deltas.
- `CombatantDef.level_curve`, and `Encounter.experience` and `loot`.
- `src/gameplay/combat/party.gd`: `active`, `arrange`, `level_of`, `experience_of`, `gain` and
  `at_level`, all over `Flags`.
- `rewards.gd`: `Rewards.grant`, plus its summary.
- `Battle.encounter`.
- `BattleSetup.release` revives a fallen member at 1 hp.
- `BattleHost`: `party` is renamed `roster`, and a battle is built from `Party.active` at each
  member's level, with the player's `Inventory`.
- `BattleScreen` draws the reward lines.
- Four strings.
- `party_rewards_test.gd` (18).
- Combat `0.15.0`.

**Why.** A won fight should leave something behind, and the plan's "saved Party roster" closes
C2.6's gap of a party that was only a list on a node.

**Connects.**
- **No new save section.** The line-up, levels and experience are flags (`party/active`,
  `level/<id>`, `exp/<id>`), the same rule as `Attributes`, `Vitals` and `Equipment`. They are
  saved, reset by a new game, and readable from a gate or a dialogue line. The test saves to
  slot 3, clears and loads.
- **Levels are base stats, not modifiers.** `at_level` grows a copy of the definition, so
  equipment and statuses still layer on top through C1.2's modifiers.
- **Loot goes through `Inventory.add`,** all or nothing per item. What does not fit is reported on
  the screen, never silently dropped.
- **ITEM commands now spend from the player's bag.** That closes C2.4's gap.
- **A fallen member stands back up at 1 hp on release.** Without that, a lost fight would start
  the next one already lost. It is a template default until C5's defeat flow.
- **The layer checker earned its keep.** It flagged `@export_group("Rewards")` in content as
  naming the gameplay class `Rewards`. The group is now "On win".

**Verified.**
- Red first: with `Party.gain` stubbed, 5 failed. Restored.
- Suite `2954 passed, 0 failed`. Boot `0 warnings, 0 errors`, printing `combat 0.15.0`. All
  seven checkers exit 0.

**Unblocks.** C2.9, the demo encounter, which closes phase C2.

**Gaps.**
- Experience is the encounter's full amount for each standing member, not split. That is a
  template default; a game wanting a split changes `Rewards.grant`.
- Nothing yet shows a member's level outside the battle, such as a party screen. That is a
  game's UI.
- A level-up raises the maximum, but current hp is not topped up, so it stays where it was.
  Some games heal on a level-up; this one does not by default.

## 2026-10-29 — C2.9 · Demo proof: one turn-based encounter

**Did.**
- `src/content/combat/party_roster.gd`.
- `BattleHost.roster_from(path)`, and the `[combat] party/roster` project setting.
- `scenes/objects/encounter_point.tscn`, a placeholder bush.
- Demo data:
  - `data/party/roster.tres`: the Wanderer (Attack, Ember, Defend, Flee) and the Keeper (the
    basic menu), both with a level curve;
  - `data/skills/ember.tres`: fire, 3 mp, hits all enemies;
  - `data/encounters/thorn_wisps.tres`: two Thorn Wisps, weak to fire, each with a brain mixing
    RANDOM and LOWEST_HP attacks. Win for 30 experience and a Chipped Stone.
- The courtyard's `WispNest`.
- Five strings.
- `AUTHORING.md` § Add an encounter and a party.
- Two `battle_screen_test.gd` assertions for `roster_from`.
- Combat `0.16.0`.

**Why.** C2.0's proof clause: one demo encounter, played from the field and back. With it, every
turn-based row has run in the game, not only in fixtures. **Phase C2 is closed.**

**Connects.** All of C2 meets in one fight:
- `EncounterPoint` asks for the encounter, and `BattleHost` builds it:
  - the party comes from `Party.active` at each member's level;
  - the enemies come from the encounter;
  - the scheduler (rounds) and the brains come from data.
- `BattleScreen` drives the turns. Enemies play through `BattleAi` between the player's turns.
- `Rewards` levels both members and puts the stone in the bag.
- Release erases the wisps' flags, and the field resumes exactly where it was.

The party is a file named by a project setting, `GameConfig`'s first-area pattern, so the
composition root names no content.

**Verified.**
- Suite `2957 passed, 0 failed`. Boot `0 warnings, 0 errors`, printing `combat 0.16.0`. All
  seven checkers exit 0.
- A load check of the three data files: no problems, and the roster has 2 members and 4
  commands.
- Two windowed captures under `xvfb-run`, using a throwaway driver (not committed) that
  interacts with the thicket and attacks until the fight ends:
  - before Continue: the reward lines over the frozen courtyard ("Wanderer reached level 2!",
    "Keeper reached level 2!", "Found Chipped Stone."), with the world paused;
  - after Continue: the live courtyard and the thicket bush, with the world unpaused, the
    stone in the bag, and the Wanderer at level 2 with 30 exp.
  - The first driver stalled because it was itself pausable, which is a nice proof that the
    battle really freezes the world. It was rerun with `PROCESS_MODE_ALWAYS`.
- Stripped run, done locally exactly as CI does it: no compile errors, `2880 passed, 0 failed,
  25 skipped`, and all six checkers it runs exit 0. The battle host finds no roster file, and so no party.

**Unblocks.** C3.0, which plans the action formula.

**Gaps.**
- `NEW_GAME.md`'s prune removes `object.` rows but not `combat.` ones. A combat game strips its
  `combat.*` demo rows by hand. That is written in AUTHORING.md; teaching upstream's prune about
  `combat.` would be an upstream edit, so it is left out.
- `Encounter.music` is still not played. Upstream's `AudioDirector.play_music` takes a stream,
  not an id, so wiring it needs a music catalogue. That is a C5 row.
- The demo party is not the template's player; the field character fights as the "Wanderer". A
  game that wants its field actor in the party gives the roster member the player's id.

## 2026-10-29 — C2.10 · A handoff page for any reader, and plain comments in the battle code

**Did.**
- `docs/HANDOFF.md`, new. It is the start-here page for any session, other Claude account, other
  AI tool or person. It holds:
  - a "Where things stand" block, to be updated by every package;
  - what the repository is, in five lines;
  - how to pick up the work, and the ladder as one copyable block;
  - a plain-words table of every combat folder;
  - the six steps of one turn-based fight, from the field to the field again;
  - the rules that bite, and the closing checklist.
- The root `AGENTS.md`, new: the file other AI coding tools look for. It points at HANDOFF,
  `CLAUDE.md` and `COMBAT.md`.
- `CLAUDE.md` gains one pointer sentence in its combat-fork paragraph.
- IN PLAIN WORDS paragraphs, plus inline `#` comments on the lines whose reason is not obvious,
  in the four largest combat files: `battle.gd`, `battle_screen.gd`, `status_set.gd` and
  `battle_setup.gd`.
- Combat `0.16.1`, a patch: no behaviour changed.

**Why.** The owner asked for it, so that work can resume from a different account or tool, and
so the owner can read the code later. The project's records were complete but written for a
reader who already knew the project's voice. HANDOFF is the plain-words way in.

**Connects.** HANDOFF links `CLAUDE.md`, `COMBAT.md`, `COMBAT_DEVLOG.md`, `CONTEXT.md`'s gotchas,
`.claude/agent-notes.md` and the CI workflow. It duplicates none of them, and the state it holds
is one short block.

**Verified.** Suite `2959 passed, 0 failed`, two more than C2.9 because `docs_test` scans the new
page. Boot `0 warnings, 0 errors`, printing `combat 0.16.1`. All seven checkers exit 0.
`combat_record_test` holds the bold `0.16.1`.

**Unblocks.** C3.0. A future session can now start from `AGENTS.md` or HANDOFF alone.

**Gaps.**
- The smaller combat files keep their dense `##` headers without an IN PLAIN WORDS paragraph.
  The standing rule adds plain comments to a file whenever a package touches it, rather than
  rewriting every file in one package.
- HANDOFF's state block is prose that a person keeps current. Only the version it points at is
  machine-checked.

## 2026-10-29 — C2.11 · Plan everything that is left: C2b depth, C3 action, C4 hybrid, C5

**Did.** Documents only.
- `COMBAT.md` gains a new phase, **C2b — Combat depth**, with its "Settled by C2.11" facts.
- The board gains every row left:
  - C2.12 to C2.19;
  - C3.1 to C3.9;
  - C4.1 to C4.8;
  - C5.1 to C5.7.
- C3.0 is folded into this row.
- HANDOFF's state block names the order.
- Combat `0.16.2`.

**Why.**
- The owner asked for the next stages to be planned deeply before more work, for anything broken
  to be fixed, and for combat to hold "everything": skills, spells, specials, toggles, a way
  back to the normal attack, buffs and debuffs. The phases C3 to C5 existed only as outlines.
- What turn-based lacked for "everything" became C2b: cure, dispel, revive, drain, multi-hit,
  turn-blocking ailments, resistance, misses, counters, reflect, stances, Boost, limit specials,
  weakness and Break, and a categorised menu. It comes before C3, so action and hybrid inherit it.

**Connects.** Three read-only passes read the code each later row leans on:
- **Player and input:**
  - `PlayerController` polls in `_physics_process` and freezes on `InputLock` tokens;
  - `Actions` defines actions in code, with no context stack;
  - the free pad buttons are X, R3 and both triggers;
  - layers 11 to 32 are free.
- **NPCs:**
  - `NpcBrain` is schedule-driven and cannot be extended;
  - its static `reachable_point` is reusable.
- **Time, pause and HUD:**
  - all-or-nothing pause;
  - no `Engine.time_scale`;
  - `DialogueScreen`'s `pauses_world=false` precedent;
  - Label HUD widgets on events.
- **Audio:** `play_music` takes a stream, with no catalogue.
- **Tests:** none await a frame.

Each fact shaped a row. Combat nodes are attached at runtime, so `player.tscn` stays upstream's.
`CombatActions` is fork-side, so `actions.gd` stays upstream's. The hybrid's slow-down is a
combat-only clock. The rebinding and settings seams go upstream first, at C5.3.

**Verified.** Import, boot, suite and all seven checkers pass. `combat_record_test` gates every
C id in this log against the board, and the bold `0.16.2`.

**Unblocks.** C2.12.

**Found while planning, and made rows:**
- the combat data's translation keys are not checked against the CSV;
- `Encounter.music` is never played;
- a `StatusSet` left at the default save id collides.

All three are C2.12.

**Gaps.** The C4 and C5 rows are outlines at the same depth as C2's were before C2.0. Each
phase's first row re-reads them against the code as it stands then.

## 2026-10-29 — C2.12 · Fixes found in review

**Did.**
- New `tests/unit/combat_content_test.gd`:
  - it walks `data/skills`, `data/encounters` and `data/party`;
  - it collects every translation key the data names: skill names, fighter names, command
    labels, and the skills those commands use;
  - it asserts each key is a row in `strings.csv`;
  - it also asserts that `EncounterDb.problems()` is empty;
  - a made-up key must not be found, which proves the lookup can fail.
- `Encounter.music` changed from an unused id to an `AudioStream`. `BattleHost` plays it when the
  battle screen opens. When the screen leaves the tree, it restores the live area's music, which
  the new static `BattleHost.area_music(root)` finds by a breadth-first walk to the first
  `AreaRoot`.
- `StatusSet.DEFAULT_SAVE_ID` and `StatusSet.rename_save(new_id)`, which unregisters the old save
  section and registers the new one. `Combatant._ready` renames a set still at the default to
  `statuses/<combatant_id>`. An id an author chose is kept, and so is the player's own default.
- `AUTHORING.md` § Add an encounter documents `music`.
- Combat `0.17.0`. It is a minor version because `Encounter.music` changed type.

**Why.** The three gaps the C2.11 review found:
- **Translation keys:** a typo in a data file's translation key would have shown a raw key on
  screen, and nothing would have caught it. The fork leaves upstream's `check_content.gd` alone,
  so this is a test.
- **Music:** the encounter's music field existed and was documented, but nothing played it.
- **Save ids:** two fighters built by hand and left at the default save id shared one save
  section, so one's statuses overwrote the other's.

**Verified.**
- Suite: `2973 passed, 0 failed`. Stripped run, done locally the way CI does it: `2892 passed, 0 failed, 25 skipped`, and all seven checkers exit 0.
- Boot: `0 warnings, 0 errors`.
- All seven checkers exit 0.
- **Red first:**
  - with the key check stubbed to always pass, 1 assertion failed;
  - with `Combatant`'s rename disabled, 2 failed.
- **The engine ran it:** a throwaway probe, not committed, booted the real game, opened the demo
  fight with a stream on its encounter, and closed it. The log read:
  - `Music -> <the probe's stream>` while the fight was open, with the
    world paused;
  - `Music -> (silence)` after closing, which is the courtyard's own (it has no music), with the
    world unpaused.

**Unblocks.** C2.13.

**Gaps.**
- No demo encounter has music, because the template ships no audio assets and art and audio are
  deferred. The path is proven by the probe and by `area_music`'s two assertions.
- Statuses still have no `name_key`, so this test checks none. C2.14 adds tags, and C2.18 shows
  statuses on screen; whichever row first shows a status name adds its key and widens this test.

## 2026-10-29 — C2.13 · One shared skill path, and more effects

**Did.**
- `SkillEffect` (content) lists what a skill does beyond its `power`:
  - DAMAGE: through the formula;
  - HEAL and RESTORE: straight to a pool;
  - DRAIN: a hit, with a share of the hp actually taken going back to the user;
  - CURE: one status, by id;
  - DISPEL: every status with a tag;
  - REVIVE: a fraction of max hp.

  Each effect validates itself.
- `Skill` gains:
  - `hits`, which repeats the whole strike;
  - `effects`;
  - `revives()`.

  Its `problems()` catches hits below 1, and any helping effect aimed at enemies.
- `StatusEffect.tags` and `StatusSet.cure_tagged(tag)`.
- `SkillUse` (gameplay) has three static functions: `affordable`, `pay` and `apply`.
  `Battle._use` now calls them. Checking a target, spending an item and the CTB delay stay with
  the battle, because each formula has its own rules for those.
- `Battle.targets_for` aims a reviving skill only at the fallen. `_settle` puts the revived back
  into the turn order.
- Plain-English comments throughout, and an IN PLAIN WORDS block in each new file.
- Combat `0.18.0`.

**Why.** It is the first C2b row. The owner asked for "everything that happens in combat". Cure,
dispel, revive, MP restore, drain and multi-hit were missing, and the skill logic lived inside
`Battle`, where C3's real-time fighter and C4's hybrid could not reach it. Now there is one path,
so a fire spell does the same thing in all three formulas.

**Decisions.**
- **Statuses roll once per target, not once per hit**, so a three-hit flurry is not three
  poison rolls.
- **DRAIN measures the hp really lost**, so draining an almost-dead foe gives back little.
- **A revive targets only the fallen**, and a plain heal only the standing. That way a menu or
  an AI never wastes a revive or heals a corpse. `Vitals` already refuses a heal on the fallen.
- **`tags` arrived here instead of C2.14**, because DISPEL needs them.

**Verified.**
- Suite: `2993 passed, 0 failed`. The old `battle_test` passes unchanged, which proves the
  extraction kept its behaviour.
- Boot: `0 warnings, 0 errors`.
- All seven checkers exit 0.
- Red first: with effect handling stubbed, 9 assertions failed.

**Unblocks.** C2.14, which adds blocks and resistance on top of `tags`, then C3.2, whose moves can
wrap a skill.

**Gaps.**
- The battle menu does not yet show effects, hits or a reviving skill's fallen targets in any
  special way. That is C2.18.
- No demo skill uses an effect yet. That is C2.19.
- `AUTHORING.md` gains its skills and statuses section in C2.19, with every field at once.

## 2026-10-30 — C2.14 · Statuses that change behaviour

**Did.**
- `StatusEffect` gains:
  - `Block`: SKIP_TURN, NO_SKILLS, NO_ITEMS and NO_FLEE;
  - `blocks`;
  - `breaks_on_hit`;
  - `has_block`.

  `problems()` refuses a turn-skipping status with no duration and no wake-on-hit, which could
  never end.
- `StatusSet` gains:
  - `blocker(block)`, which returns the first held status carrying that block;
  - `wake()`, which ends every status that breaks on a hit;
  - resistance inside `apply(effect, rng = null)`. The holder's sheet is read for
    `resist_<tag>` across the status's tags. The strongest one counts: 1 or more is immune,
    and a fraction rolls.
- `Combatant.receive` calls `wake()` when a hit actually lowered the pool.
- `Battle`:
  - `allows(command)` refuses SKILL, ITEM or FLEE while a status blocks it, and `act` checks it;
  - `next_turn` makes a sleeper lose the turn, with a cap on consecutive lost turns.
- `BattleAi` never picks a blocked command, so a silenced caster falls back to attacking.
- `SkillUse` hands its seeded rng to the resistance roll, so seeded fights replay exactly.
- New bus signals: `status_resisted` and `turn_skipped`. Both have emitters, and both are meant
  for C2.18's battle log.
- Combat `0.19.0`.

**Decisions.**
- **A sleep is checked before its tick.** A sleep of duration N therefore costs exactly N turns:
  the tick on the last lost turn is the one that wears it off. Checking after the tick would
  make a 1-turn sleep cost nothing.
- **ATTACK and DEFEND are never blocked**, so a fighter always has something legal to do and the
  AI's fallback always works.
- **Consecutive lost turns are capped at 64 times the number of fighters.** A field where
  everyone sleeps "until hit" ends `next_turn` with null instead of hanging the game.
- **Resistance is per tag, not per status.** A game gives a boss `resist_ailment = 1`, and it is
  immune to every ailment at once.

**Verified.**
- Suite: `3010 passed, 0 failed`.
- Boot: `0 warnings, 0 errors`.
- All seven checkers exit 0.
- Red first: with `blocker` and the resistance stubbed, 10 assertions failed.

**Unblocks.** C2.15, then C2.18, whose menu greys out what `allows` refuses and whose log reads
the two new signals.

**Gaps.**
- A sleep is not broken by a status tick (a poison), only by a hit. Most games agree; a game that
  disagrees can call `wake()` from its own listener.
- A capped battle (everyone asleep for good) returns null from `next_turn` while the outcome is
  still ONGOING. The screen shows no menu then. Validation makes this unreachable with sound
  data.

## 2026-10-30 — C2.15 · Hit or miss, counters and reflect

**Did.**
- New `src/systems/combat/accuracy_stage.gd`. The chance to land is `base_accuracy` (1) plus
  the attacker's `accuracy` stat, minus the defender's `evasion` stat. A miss sets
  `DamageResult.missed` and zeroes the amount. `DamageFormula.resolve` then stops, so no later
  stage can turn the zero back into damage.
- `DamageFormula.standard()` lists it first, so the standard formula is now five stages.
- `DamageRequest.sure_hit` and `Skill.sure_hit` let a hit skip the roll. `Combatant.hit` takes
  `sure_hit`, and `SkillUse` passes the skill's own value for power, DAMAGE and DRAIN.
- `Combatant.receive` on a miss changes nothing, wakes nobody, and emits `attack_missed`.
- `Skill.tags`: free labels. `magic` is what a reflect bounces by default.
- `StatusEffect` gains:
  - `Reaction`: COUNTER and REFLECT;
  - `reactions`;
  - `reaction_chance`;
  - `reflect_tag`;
  - `has_reaction`.

  `problems()` refuses a REFLECT with no tag. `StatusSet.reactor(reaction)` returns the first
  held status carrying a reaction.
- `SkillUse.apply` checks each aimed target for a reflect. A bounced skill, statuses and all,
  lands on its user.
- `SkillUse.counter(attacker, defender, landed, rng)` makes the defender strike back with a plain
  hit. `Battle` calls it after an ATTACK.
- New signals `attack_missed`, `countered` and `skill_reflected`.
- New `tests/unit/hit_reaction_test.gd` (19).
- Combat `0.20.0`.

**Why.** Misses, counters and reflect are on the owner's "everything in combat" list. All three
answer the same question: what happens around a hit.

**Decisions.**
- **A certain hit draws no random number.** With no evasion anywhere, the chance is 1 and the
  stage returns at once, so every seeded test and fight from before this row replays unchanged.
  This is why no older assertion moved, except the count of stages in the standard formula.
  Below 1, it always draws once, the crit stage's rule.
- **A miss is its own signal**, not a 0 on `combatant_damaged`. A floating number or a log line
  never has to tell "missed" from "hit for 0". This is a change from the plan.
- **Counters answer only a plain ATTACK that landed**, from a defender who is standing and
  neither asleep nor stunned. A counter is itself a plain hit, so it can miss too, and it is
  never countered back.
- **Reflect works by tag and never bounces twice.** A bounced skill lands on its user even if the
  user also reflects, so two mirrors cannot ping-pong. A skill aimed at its own user, or at a
  fallen target, never bounces.
- **A reaction at chance 1 draws nothing**, for the same replay reason.
- **Counter lives in `SkillUse`, not `Battle`**, so C3's hurtbox can call the same function.

**Verified.**
- Suite: `3030 passed, 0 failed`.
- Boot: `0 warnings, 0 errors`.
- All seven checkers exit 0.
- Red first: with the stage, the miss and both reactions stubbed, 14 assertions failed.

**Unblocks.** C2.16 (meters), and C2.18's battle log, which reads the three new signals.

**Gaps.**
- A counter uses the defender's plain attack only. A counter with a skill (a "counter-magic") is
  not built; a game can listen to `countered` and act.
- No demo content uses evasion, counter or reflect yet. C2.19 adds that.
- `BattleAi` does not avoid casting magic into a reflecting target. A smarter brain can check
  `StatusSet.reactor`.
