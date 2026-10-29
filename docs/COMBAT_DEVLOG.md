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
