# Combat base — situation, phases and board

**Read this second, after `CLAUDE.md`.** This repository is the **combat** fork of the HD-2D base
([ADR-0008](decisions/ADR-0008-combat-is-in-scope.md)).

- **This file:** this repository's own state, phases and board.
- **[`CONTEXT.md`](CONTEXT.md), `ROADMAP.md`, `WORK_PACKAGES.md` and `DEVLOG.md`:** the upstream
  base's record, still true for every system inherited from it.

**Last updated:** 2026-10-29 · **C2.11 complete. Combat version 0.16.2** (`[combat] core/version`; the boot log prints it). **New here? Read [`HANDOFF.md`](HANDOFF.md) first.** Seeded from upstream `aaf281b` (base `5.16.2`), full history kept, `template` remote set. **C1, the shared core, and C2, turn-based, are complete.** C2.11 planned everything that is left as rows: C2b (combat depth), C3 (action), C4 (hybrid) and C5 (mix and harden). **The next row is C2.12, fixes found in review.**
full history kept, `template` remote set; upstream `5.16.3` merged in cleanly the same day. **The shared core is complete and proven in the game: a training dummy in the courtyard takes a resolved hit and toasts it. Phase C2, the turn-based formula, is planned as rows C2.1 to C2.9, C2.1 and C2.2 shipped two interchangeable turn schedulers, rounds and CTB, C2.3 made skills and commands data, C2.4's `Battle` runs a whole fight with no frames, C2.5's `BattleAi` plays a side from data, C2.6 builds a battle from an encounter, C2.7 draws it as a screen over the frozen field, C2.8 rewards a win and grows the party, and C2.9 puts a playable fight in the courtyard. **The turn-based formula is complete. The next row is C3.0, which plans the action formula.**

## How the two repositories relate

```
HD-2D-game-base-non-combat-   (upstream: git remote "template")
        │  git merge template/main        docs/UPGRADING.md, unchanged
        ▼
HD-2D-game-base-combat        (this repository)
        │  same mechanism
        ▼
a game, which picks one formula or several
```

**Flow of changes between the two repositories:**

- **Upstream fixes come down** through `git fetch template && git merge template/main`, then the
  ladder.
- **Combat code never goes up.**
- **A seam combat needs goes up first**, but only if a non-combat game could use it too (for
  example, a time-scale seam or an input-context stack). It lands as a row on upstream's board,
  then gets merged down.

## Phases

Each phase opens with a planning row (`Cn.0`, the way T6.0 worked), which writes its own rows here.

### C0 — Fork and re-scope · **COMPLETE**

### C1 — Shared combat core (both formulas use it) · **COMPLETE**

`src/content/combat/` holds the data and `src/systems/combat/` the systems. A game swaps
formulas through data, never through `src/`.

- `StatBlock`:
  - base values, plus modifiers (add, multiply, override) in a defined order;
  - derived stats.
- `Vitals`:
  - HP and any number of named pools;
  - signals on change, on zero and on revive.
- Damage pipeline:
  - `DamageRequest` → resolver stages (attack, defence, element, crit, variance) →
    `DamageResult`;
  - each stage is a resource.
- `StatusEffect`:
  - duration in **turns or seconds**, which is what lets every formula share it;
  - tick, stacking rule, modifiers.
- Factions and target filters (self, ally, enemy, all).
- `Combatant` component: makes any existing actor combat-capable by composition.
- Signals in `events.gd`, each with an emitter (`check_signals.gd`).
- A save section, with a version bump.
- Widen `record_shape_test.gd` to gate C ids (ADR-0008, the honest limit).
- Add the `combat/version` key.
- **Proof:** fixture-only tests, plus one demo training dummy.

### C2 — Turn-based formula · **COMPLETE**

- Field encounter trigger and the `Encounter` resource.
- A battle scene, entered and left through the existing Director, returning to the exact field
  state.
- A pluggable `TurnScheduler`:
  - speed-sorted rounds as the default;
  - a CTB/ATB queue as the second implementation;
  - this is the formula-swap point.
- `BattleCommand` resources (attack, skill, item, defend, flee); skills are data.
- `BattleBrain`: weighted actions behind `FlagQuery`-style conditions.
- Battle UI: commands, target select and a turn-order strip, keyed strings, T6 input prompts.
- EXP and level curve, loot into the existing `Inventory`, and a saved `Party` roster.
- **Proof:** one demo encounter, and a whole battle driven headlessly from fixtures.

**Settled by C2.0, read against the code:**

- **A battle is a modal layer over the paused field, not an area.**
  - Opening a modal screen already sets `get_tree().paused`, and `WorldRoot` is pausable
    (`ui_root.gd`'s table).
  - So the field is frozen exactly where it was, and closing the battle returns to it with no
    save, no reload and no `Director` change.
  - `Director` keeps its "MUST NOT know what is inside an area" line.
- **The battle never runs on `_process`.** It advances only when called (`act`, `next_turn`),
  so pausing cannot stop it, and a test drives a whole battle with no frames.
- **The battle runtime is gameplay, the scheduler is systems.** A battle holds `Combatant`
  nodes, which are gameplay. A scheduler only orders ids by a speed number, so it stays pure
  and swappable, under `src/systems/combat/`.
- **Party members and enemies are data, not field nodes.**
  - A battle builds its own `Combatant`s from definitions, so the template's player needs no
    `Combatant`.
  - The field player and the battle party are joined only by the `Party` roster's ids.

### C2b — Combat depth · **in progress**

Added by C2.11 at the owner's request: "skills, spells, magic, special moves, toggling, back to a
normal attack, buffs, debuffs, everything that happens in combat". It is built for turn-based
first, and every piece is shaped so C3 and C4 reuse it rather than copy it.

- **One way to use a skill:**
  - `SkillUse` is shared by the battle, the field and the hybrid;
  - it adds cure, dispel, revive, restore, drain and multi-hit effects.
- **Statuses that change behaviour:**
  - tags (buff, debuff, ailment);
  - skip a turn (stun, sleep), silence and no items;
  - wake on hit;
  - resistance and immunity.
- **Accuracy and evasion** (a miss), **counters** and **reflect**.
- **Meters, all one rule** (a pool that regenerates or fills on hit):
  - MP regen;
  - Octopath-style Boost;
  - a limit gauge for special moves;
  - toggled stances.
- **Weakness and Break:**
  - one shield system;
  - C3's poise and C4's pressure are the same code.
- **The battle menu:**
  - categories (Skills, Magic, Items, Special);
  - costs, greyed-out choices with their reason, On/Off for toggles, and a Boost selector;
  - statuses on each fighter, and a battle log.

**Settled by C2.11, read against the code** (three read-only passes over the player, NPCs, input,
time, HUD and settings):

- **The player is not edited.**
  - `PlayerController` polls input in `_physics_process` and freezes through `InputLock` tokens.
  - A child node processes after its parent, so it can drive `velocity` for a dodge or
    knockback while it holds an `&"action"` token.
  - The combat nodes are attached at runtime, on `player_spawned`, from a loadout named in
    `[combat]`, so `player.tscn` stays upstream's.
- **Input and layers:**
  - Combat actions are defined by a fork-side `CombatActions`, so `actions.gd` is untouched.
  - The free pad buttons are X, R3 and both triggers.
  - Physics layers 11 and 12 become `hitbox` and `hurtbox`; layers 11 to 32 are free.
  - Rebinding these needs an upstream seam (`Actions.extend`). That is C5.3, and it is
    combat-neutral.
- **Action enemies:**
  - `NpcBrain` is schedule-driven and cannot be extended, so an action enemy is its own script.
  - It reuses `NavigationAgent3D` and the static `NpcBrain.reachable_point`.
- **Time:**
  - Pausing is all or nothing, and `Engine.time_scale` is unused.
  - The hybrid's slow-down is a combat-only `CombatClock` scale that only combat nodes read.
  - The command menu is a `pauses_world=false` overlay, `DialogueScreen`'s precedent.
- **Tests never await frames.** Every timed system has a pure core stepped by `dt`, and
  overlap is driven by emitting `area_entered` by hand.
- **Settings:** a player-facing combat setting needs upstream's `Settings.DEFAULTS`, so it waits
  for C5.3. Until then, project settings.

### C3 — Action formula

- Hitbox/hurtbox components feeding the same C1 damage pipeline.
- Player attack state machine:
  - attack chain, dodge with i-frames, stagger, knockback;
  - wired in through a new input context.
- Enemy behaviour on `NpcBrain`:
  - chase, attack, retreat;
  - navigation reused, including the T6.15 reachability clamp.
- Lock-on, behind a setting.
- Defeat and respawn: a template default with a seam.
- Field HUD.
- **Proof:** one demo enemy, and fixture hitbox tests.

### C4 — Hybrid formula (semi-real-time, FF7 Remake-style)

Built **only** from C2 and C3 parts.

- Real-time movement and basic attacks, from C3.
- An ATB gauge per combatant:
  - fills with time, and with landed hits, guards or dodges;
  - the fill rules are data.
- Spending ATB opens C2's command menu:
  - skills and items are the same `BattleCommand`s;
  - time slows or stops while the menu is open, through a `TimeScale` seam;
  - wait mode or active mode is a setting.
- Party switching. A member not under control runs a C2 `BattleBrain`.
- Pressure and stagger, defined as C1 modifiers.
- **Variants proved by one fixture config each, with no new system:**
  - CTB/ATB menu battles;
  - pause-and-play tactics;
  - timed-hit turn-based.
- **Proof:** one demo hybrid encounter, and ATB and time scale driven by a stepped clock.

### C5 — Mix-and-match and hardening

- Several formulas in one game, chosen per encounter, for example action in the field and
  turn-based for bosses.
- Per-game default: `[combat] mode`.
- Robustness:
  - pause and save around battle;
  - controller support;
  - accessibility: difficulty multiplier, auto-battle.
- Docs:
  - `AUTHORING.md` combat sections;
  - `NEW_GAME.md` "choose your combat";
  - a `combat/version` 1.0.0 entry.
- A playtest pass.

### Game choices: the base builds none of these

Classes, job systems, crafting, a bestiary and difficulty tuning. **Art stays deferred.**

## Releases

Each row that changes code bumps `[combat] core/version`, with the same promise upstream's
`CHANGELOG.md` makes. **A bold version in this file is a claim about the CURRENT one** and
`combat_record_test.gd` holds it to that; every other spelling is a record of what was.

- **0.16.2** — C2.11. A patch, documents only: the plan for C2b to C5, read against the code. A game does: nothing.
- `0.16.1` — C2.10. A patch, with no behaviour change.
  - `docs/HANDOFF.md` and the root `AGENTS.md`, a start-here page for any session, account or
    tool.
  - IN PLAIN WORDS paragraphs and inline comments in `battle.gd`, `battle_screen.gd`,
    `status_set.gd` and `battle_setup.gd`.

  A game does: nothing.
- `0.16.0` — C2.9. The demo encounter, which closes C2.
  - `PartyRoster` content, named by the new `[combat] party/roster` setting. `BattleHost` loads
    it when its own `roster` is empty, and a missing file is no party.
  - The prefab `scenes/objects/encounter_point.tscn`.
  - Demo data: the thicket in the courtyard, two Thorn Wisps, the Wanderer and the Keeper, and
    the Ember skill.
  - `AUTHORING.md` § Add an encounter and a party.

  A game does: set `[combat] party/roster` to its own roster, or leave it pointing nowhere.
- `0.15.0` — C2.8. Rewards, levels and the party.
  - `LevelCurve`: a power curve, a max level, and per-level stat growth.
  - `CombatantDef.level_curve`; `Encounter.experience` and `loot`.
  - `Party`, entirely in `Flags`:
    - `party/active` and `party/reserve`, plus `level/<id>` and `exp/<id>`;
    - `active(roster)` defaults to the whole roster;
    - also `arrange`, `gain` and `at_level`.
  - `Rewards.grant`: on WON only, experience to every standing member and loot into the
    inventory, with anything that does not fit reported.
  - `BattleHost.party` is renamed `roster`. Battles build the line-up at its level and spend
    ITEMs from the player's inventory. The screen draws the reward lines.
  - `BattleSetup.release` stands a fallen member back up at 1 hp.

  A game does: rename `BattleHost.party` to `roster` if it set one.
- `0.14.0` — C2.7. The battle screen.
  - `BattleScreen` (ui), a modal `MenuScreen` over the frozen field, shows:
    - each fighter's hp, and the turn order from `preview`;
    - the player's menu: the definition's commands, or Attack / Defend / Flee;
    - target select, with Back;
    - a line when a command is refused.

    Enemies play through `BattleAi` between the player's turns. Cancel cannot leave; the
    outcome screen has one Continue row. Closing it releases the fighters.
  - `BattleHost` (ui, added under `UILayer` in `game_root.tscn`) answers
    `encounter_requested`. Fighters are built under it, because they need the tree.
  - `Battle.defs`.
  - Twelve `ui.battle.*` strings.

  A game does: nothing; it may fill `BattleHost.party` until C2.8.
- `0.13.0` — C2.6. Encounters.
  - `CombatantDef`: one shape for party and enemies, with an id, name, faction, base stats,
    commands and a brain.
  - `Encounter` (`data/encounters/`, id `encounter/<name>`): enemies, ROUNDS or CTB, and flee
    rules. `EncounterDb` finds it.
  - `BattleSetup.build(encounter, party, holder)` and `release(battle)`. Two of one enemy become
    `<id>_1` and `<id>_2`. Enemies start full and their flags are erased afterwards; the party
    keeps its hp.
  - `Battle.brains` and `brain_of`.
  - The field interactable `EncounterPoint` and `Events.encounter_requested(id)`.
  - A missing combat data directory is now "no content", not an engine error.

  A game does: nothing; it may author encounters.
- `0.12.0` — C2.5. Enemy AI as data.
  - `BattleBrain` holds weighted `BrainEntry`s. Each entry has:
    - a command and a weight;
    - a target rule: FIRST, RANDOM, LOWEST_HP or SELF;
    - an optional `FlagQuery` condition, and an optional own-pool-below-a-fraction condition.
  - `BattleAi.take_turn(battle, brain)` (gameplay) draws among the allowed entries, using the
    battle's seeded rng. It acts only through `Battle.act`. When nothing is allowed it attacks,
    or failing that defends.

  A game does: nothing.
- `0.11.0` — C2.4. `Battle` (gameplay) is the turn-based runtime:
  - you call `next_turn()`, then `act(command, targets)`, then read `outcome()`;
  - `targets_for(command)` lists who a command may be aimed at;
  - ATTACK, SKILL (cost, ONE or ALL, a hit or a heal, statuses, CTB delay), ITEM (also spends an
    inventory item), DEFEND (one turn of +100 defence) and FLEE (`can_flee`, `flee_chance`);
  - statuses tick on each actor's own turn, and the fallen leave the queue;
  - the outcomes are WON, LOST and FLED.

  Two bus signals: `battle_started(enemy_ids)` and `battle_ended(outcome)`. A game does:
  nothing.
- `0.10.0` — C2.3. Combat content:
  - `Skill` (`data/skills/`, id `skill/<name>`): a cost, a target filter, a ONE or ALL scope,
    power (negative heals), an element, statuses with a chance, and a CTB `delay`.
  - `BattleCommand`: ATTACK, SKILL, ITEM, DEFEND or FLEE, carrying a skill and, for an item, an
    `item_id`.
  - `SkillDb`.
  - `skill_test.gd` checks every skill and status under `data/`.

  A game does: nothing; it may author skills.
- `0.9.0` — C2.2. `CtbScheduler`, the second `TurnScheduler`. Each actor waits
  `delay / speed` ticks, so a fast one can act twice per slow turn. `delay_by(id, ticks)` pushes
  an actor back, and `wait_of(id)` reads its wait. Ties go to whoever joined first, and speed 0
  never acts. A game does: nothing; it may choose CTB in data.
- `0.8.0` — C2.1. `TurnScheduler` (systems), the turn-based swap point: a roster of ids and
  speeds, plus `next()` and a `preview(n)` that agrees with it. Its default, `RoundScheduler`,
  runs rounds fastest first, with ties going to whoever joined first. A newcomer waits for the
  next round, and anyone who leaves is skipped. A game does: nothing.
- `0.7.0` — C1.7. `StrikeTarget` (gameplay): an interactable whose `Combatant` child takes
  one resolved hit when used, toasts `{amount}`, `{left}` and `{max}`, and can stand back up.
  `Combatant.base_stats` authors a sheet's base values on the scene, and
  `Combatant.resolving_formula()` names the formula its hits use. The generic prefab
  `scenes/objects/strike_target.tscn`, and the demo's training dummy in the courtyard. A game
  does: nothing; it may place strike targets.
- `0.6.0` — C1.6. `FactionTable` (content): hostility, by default the same faction allied and
  different ones hostile, with listed exceptions; target filters SELF / ALLY / ENEMY / ANY.
  `Combatant` (gameplay): an id, a faction, one sheet shared with its `Vitals` and `StatusSet`
  siblings, `hit` (the attacker's formula resolves) and `receive`. `Events.combatant_damaged`.
  Also carries upstream `5.16.4`. A game does: nothing.
- `0.5.0` — C1.5. Statuses: `StatusEffect` content (`data/statuses/`, id `status/<name>`)
  lasting TURNS or SECONDS, stacking REFRESH, STACK or IGNORE, with modifiers and an optional
  pool tick; `StatusDb` finds them; a `StatusSet` component holds them, is ticked by whoever owns
  the clock, and saves its own section. Two new bus signals. A game does: nothing, it may author
  statuses.
- `0.4.0` — C1.4. The damage pipeline: a `DamageFormula` resource is an ordered list of
  `DamageStage`s, resolved purely from a `DamageRequest` (two sheets, a power, an element) and a
  seeded `RandomNumberGenerator` into a new `DamageResult`. Shipped stages: attack against
  diminishing defence, element resistance (`resist_<element>`, above 1 absorbs), crit and
  variance; `DamageFormula.standard()` lists them in that order. A game does: nothing, it may
  author its own formula as a `.tres`.
- `0.3.0` — C1.3. `Vitals`: named pools whose current value is the flag `vital/<who>/<pool>`
  and whose maximum is the sheet's `max_<pool>`; an unset pool is full; defeat is an edge, fired
  once; only `revive()` lifts a defeated combatant. Three new bus signals. A game does: nothing.
- `0.2.0` — C1.2. `StatModifier` (content) and `StatSheet` (systems): a stat's value is
  (base + every ADD) x every MULTIPLY, unless an OVERRIDE exists, in which case the latest one
  is the value; modifiers leave by source. A game does: nothing, it may start authoring
  modifiers.
- `0.1.0` — C1.1. The version exists. A game does: nothing.

## Board

| # | Package | Status |
|---|---|---|
| C0.1 | Fork and re-scope | **DONE**: seeded from upstream `aaf281b` with history, `template` remote, ADR-0008, this file, `COMBAT_DEVLOG.md`, pointer lines in `CLAUDE.md` / `README.md` / `CONTEXT.md`. Ladder green. |
| C1.0 | Plan the shared core: write C1's rows here | **DONE**, documents only. The rows below were read against the code, not guessed: components are a `Node` child found by a static `of(who)` type lookup (`inventory.gd`, `equipment.gd`); per-actor saved numbers live in `Flags` under a namespaced key (`Attributes`, `Standing`), which gives save, new-game reset and `flag_changed` for free; content is a `ContentEntry` with `problems()`; `save_system.gd` is at 179 of its 180-line budget, so nothing here edits it; **no modifier system exists anywhere yet**. |
| C1.1 | Gate the combat record and give it a version | **DONE**, combat `0.1.0`. New `combat_record_test.gd` (upstream's tests untouched, so merges never conflict on them): every C id in the log has a row here, the version is declared and printed at boot, and every bold semver in this file is it. `CombatVersion` is a sibling of `TemplateVersion`, not a parameter on it, for the same reason. Red first, 4 failed. Was planned as: `record_shape_test.gd` reads `COMBAT_DEVLOG.md` too, with C ids checked against this file. `[combat] core/version="0.1.0"`; `TemplateVersion` gains `of(setting)` so the base's reading is unchanged; the boot banner prints `combat 0.1.0`; `version_test` covers it |
| C1.2 | Stats and ordered modifiers | **DONE**, combat `0.2.0`. `src/content/combat/stat_modifier.gd`, `src/systems/combat/stat_sheet.gd`, `stat_sheet_test.gd` (14). The order is fixed: (base + ADD) x MULTIPLY, OVERRIDE wins and the latest one wins; MULTIPLY stacks by product. A sheet is pure and never saved, because what it is built from is. Red first: `value()` ignoring modifiers failed 7. Was planned as: `StatModifier` (content: stat, op ADD / MULTIPLY / OVERRIDE, value, source) and a pure `StatSheet` (systems): base plus modifiers, applied in that fixed order, removable by source. Stat names are free `StringName`s, Attributes' rule. Tests: order, removal by source, override wins |
| C1.3 | Vitals | **DONE**, combat `0.3.0`. `src/gameplay/combat/vitals.gd`; `Events.vitals_changed`, `combatant_defeated`, `combatant_revived` in a combat section appended to `events.gd`; `vitals_test.gd` (21). An unset pool is full; defeat fires once; a heal cannot lift a defeated combatant, only `revive()` can. Red first: the change and revive guards removed, 7 failed. Was planned as: `Vitals` component: named pools (hp, mp, …), current values in `Flags` at `vital/<who>/<pool>`, the maximum read from the sheet's `max_<pool>`. `Events.vitals_changed` and `Events.combatant_defeated`, fired once at zero; `revive`. Tests: clamp, defeat once, save round-trip |
| C1.4 | Damage pipeline | **DONE**, combat `0.4.0`. `src/systems/combat/`: `damage_request.gd`, `damage_result.gd`, `damage_stage.gd`, `damage_formula.gd` (the ordered list, and `resolve`), and four stages, `attack_defence_stage.gd`, `element_stage.gd`, `crit_stage.gd`, `variance_stage.gd`; `damage_formula_test.gd` (23). All in systems, not content, because a stage reads a `StatSheet`. Defence is diminishing (`softness / (softness + defence)`), so no hit is ever zero by defence alone; resistance above 1 absorbs and the result goes negative; the crit and variance stages always draw once, so a seeded fight replays. No separate `DamageResolver`: the formula resolves itself. Red first: `resolve` ignoring its stages failed 11. Ten code files against the board's "about 8": eight are one-class files under 40 lines each. Was planned as: `DamageRequest` and `DamageResult`, and `DamageStage` resources applied in order by a pure, seeded `DamageResolver`. Shipped stages: attack against defence, element affinity, crit, variance. A game changes the formula by listing different stages in data. Tests: each stage, the order, determinism under a seed |
| C1.5 | Status effects | **DONE**, combat `0.5.0`. `src/content/combat/status_effect.gd` and `status_db.gd`, `src/gameplay/combat/status_set.gd`, `Events.status_applied` / `status_expired`, `status_set_test.gd` (27). A set never ticks itself, so pause and slow-motion need nothing here. Modifiers are authored without a source and stamped with the status id, so expiry, cure, a new game and a load remove exactly them. A long `tick_seconds` step never ticks past expiry. A duration of zero lasts until cured. The save section stores ids, time left and stacks, and rebuilds modifiers from `StatusDb`. **One change from the plan:** the tick is a pool change, not a `DamageRequest`, because content may not depend on systems; a tick through a formula is C1.6's. Red first: with ticks and clean-up stubbed, 6 failed. Was planned as: `StatusEffect` content: duration in TURNS **or** SECONDS, which is what lets every formula share it; stacking rule REFRESH / STACK / IGNORE; modifiers; an optional tick. A `StatusSet` component with `tick_turn()` / `tick_seconds()`; expiry removes its modifiers by source. Its own save section, registered without editing `save_system.gd`. Tests: both units, the three stacking rules, clean expiry |
| C1.6 | Factions, targeting and `Combatant` | **DONE**, combat `0.6.0`. `src/content/combat/faction_table.gd`, `src/gameplay/combat/combatant.gd`, `Events.combatant_damaged`, `combatant_test.gd` (24). No table is needed for the common rule (same faction allied, different hostile); a table lists exceptions as `a:b`, symmetric. ALLY includes the user, so a party heal reaches its caster; ENEMY never does. `Combatant` hands its sheet and id to its siblings on ready, so a status's modifier and `Vitals`' maximum read one sheet. **The attacker's formula resolves**, and the defender only applies the result, so a preview and the real hit agree. A defeated combatant receives nothing. Red first: with the sheet unshared and `receive` applying nothing, 5 failed. Upstream `5.16.4` (T7.1) merged in with no conflict. Was planned as: Faction hostility (content); target filters SELF / ALLY / ENEMY / ANY; a `Combatant` component tying sheet, vitals, statuses and faction to a `combatant_id`; `receive(request)` resolves, applies and emits `Events.combatant_damaged`. Tests: hostility, filters, a request through to defeat |
| C1.7 | Demo proof: a training dummy | **DONE**, combat `0.7.0`, and **phase C1 is closed**. `src/gameplay/interactables/strike_target.gd` (generic, it names no content), `Combatant.base_stats` and `resolving_formula()`, the prefab `scenes/objects/strike_target.tscn`, the courtyard's `TrainingDummy` (30 hp, 20 defence, revives) and its three strings, `strike_target_test.gd` (14), and § Make something you can hit in `AUTHORING.md`. An interactor without a `Combatant` (the template's player) strikes with `power` alone. Windowed capture: the toast reads "Thwack. 7 damage, 23 of 30 left." Stripped run: `2745 passed, 0 failed, 25 skipped`. Red first: with `perform` stubbed, 9 failed. **One change from the plan:** a `src/` class was needed after all, because no interactable could hit; it is generic, so the row's rule (nothing under `src/` names the dummy) holds |
| C2.0 | Plan the turn-based formula: write C2's rows here | **DONE**, documents only. The rows below were read against the code: `UiRoot` pauses `WorldRoot` under any modal screen, `Director` must not know an area's insides, `FlagQuery.passes` is the one condition reader, `Inventory.of(who).add` is the loot seam, and the layer rule puts anything holding a `Combatant` in gameplay. Decisions are in § C2, "Settled by C2.0" |
| C2.1 | `TurnScheduler` and speed-sorted rounds | **DONE**, combat `0.8.0`. `src/systems/combat/turn_scheduler.gd` (the base keeps the roster: `join`, `leave`, `has`, `speed_of`; a subclass gives the order through `next` and `preview`), `round_scheduler.gd` (the default, plus `round_number()`), `turn_scheduler_test.gd` (12). A round is ordered when it starts, so a speed change or a newcomer takes effect from the next round. It is a `Resource`, so an encounter can choose one in data, and a battle `duplicate()`s it. Red first: with `next` stubbed, 11 failed. Was planned as: `src/systems/combat/turn_scheduler.gd`, a pure base class: `join(id, speed)`, `leave(id)`, `next() -> StringName`, `preview(n)` for the turn-order strip. `round_scheduler.gd` is the default: each round orders everyone by speed, highest first, with ties broken by join order so a seed is never needed. Someone who leaves mid-round is skipped. Tests: order, ties, leaving mid-round, `preview` matching `next` |
| C2.2 | A CTB queue, the second scheduler | **DONE**, combat `0.9.0`. `src/systems/combat/ctb_scheduler.gd` (`delay` exported, `delay_by`, `wait_of`), `ctb_scheduler_test.gd` (15). **The order contract** (an empty roster has no turn, the fastest acts first, `preview` agrees with `next`, a leaver never acts again) runs unchanged against both schedulers, which proves the swap point. A speed change counts from the actor's next turn. Red first: with `next` stubbed, 6 failed. Was planned as: `ctb_scheduler.gd`: each actor waits `delay / speed` ticks, so a fast actor can act twice before a slow one. A `delay_by(id, ticks)` seam lets a heavy skill or a slow status push someone back. Tests: a 2× speed acting twice, `delay_by`, `preview`, and the same fixture battle running unchanged on both schedulers. **Proves the scheduler is the swap point** |
| C2.3 | Skills and commands as data | **DONE**, combat `0.10.0`. `src/content/combat/skill.gd`, `battle_command.gd`, `skill_db.gd`, `skill_test.gd` (14). Negative power heals and may not target ENEMY; zero power with no statuses is an error. An item is a skill plus the `item_id` it spends, so a potion and a heal spell share every field. `delay` is the CTB seam. **One change from the plan:** upstream's `check_content.gd` is not edited, because the fork keeps upstream files untouched. Instead, `skill_test.gd` asserts that `SkillDb` and `StatusDb` report no problems over the real `data/`, which closes C1.5's gap the same way and passes with no data in the stripped run. Red first: with both `problems()` stubbed, 8 failed. Was planned as: `src/content/combat/skill.gd`: a cost (pool and amount), a `FactionTable.Target` filter, a scope (ONE or ALL), power, element, and statuses applied with their chance. `battle_command.gd` holds the kind (ATTACK, SKILL, ITEM, DEFEND, FLEE) and the skill or item it uses. `skill_db.gd` over `data/skills/`, and `check_content` taught to scan both `data/skills/` and `data/statuses/`, which closes C1.5's gap. Tests: `problems()` for each, and a scan |
| C2.4 | The battle runtime | **DONE**, combat `0.11.0`. `src/gameplay/combat/battle.gd`, `Events.battle_started` / `battle_ended`, `battle_test.gd` (20). An illegal command changes nothing and keeps the turn. ATTACK is a power-0 hit, so the attack stat decides it. A heal is not resolved through defence. DEFEND is a code-built one-turn status, +100 defence by default and replaceable through `defend_status`. A failed flee spends the turn. The battle holds combatants without owning them. Red first: with `act` stubbed, 12 failed. Was planned as: `src/gameplay/combat/battle.gd`: sides of `Combatant`s, a scheduler, `current()`, and `act(command, targets) -> bool`, which checks the target filter, spends the cost, resolves through the actor's formula and applies statuses. DEFEND is a one-turn status, and `tick_turn` runs on each actor's own turn. Outcomes: WON, LOST, FLED. `Events.battle_started` / `battle_ended(outcome)`. Test: a whole fixture battle, start to WON, with a seeded rng and no frames |
| C2.5 | `BattleBrain`, the enemy AI | **DONE**, combat `0.12.0`. `src/content/combat/brain_entry.gd`, `battle_brain.gd`, `src/gameplay/combat/battle_ai.gd`, `battle_ai_test.gd` (10). Evaluation is gameplay, because the pool test reads `Vitals`; the brain itself is content, authored inline like commands. An entry it cannot afford, or with no legal target, is ruled out before the draw. Red first: with the weighted choice disabled, 3 failed. Was planned as: `src/content/combat/battle_brain.gd`: weighted entries, each with a command, a target rule (lowest hp, random, self) and an optional condition. Conditions use `FlagQuery`'s closed set, plus one test on the actor's own pool fraction. The pick is seeded. Tests: a weight of zero never fires, a condition gates, seeded determinism |
| C2.6 | Encounters and the field trigger | **DONE**, combat `0.13.0`. `src/content/combat/combatant_def.gd`, `encounter.gd`, `encounter_db.gd`, `src/gameplay/combat/battle_setup.gd`, `src/gameplay/interactables/encounter_point.gd`, `Events.encounter_requested`, `Battle.brains` / `brain_of`, `encounter_test.gd` (17). The turn order is an enum on the encounter, because content may not name a systems scheduler. A definition carries no formula, for the same reason; a built fighter uses the standard one. **The trigger is a small `Interactable` subclass, not a reuse of `TriggerVolume`.** A volume sets a flag, and turning a flag into a request would need a watcher with no other job. The combat data catalogues now skip a missing directory, which removes four engine errors the suite logged from C1.5 on. Red first: with the enemy flag reset stubbed, 2 failed; with the duplicate suffix stubbed, 1 failed. Was planned as: `src/content/combat/encounter.gd`: an enemy group (definitions plus count), `can_flee`, a music id, and rewards. `encounter_db.gd`. A `combatant_def.gd` holds an id, faction, base stats, skills and brain, and is used by both party and enemies. A field trigger raises `Events.encounter_requested(id)` through an existing `TriggerVolume` / interactable flag seam where one fits, with no new trigger class if possible. Tests: a request builds the right sides |
| C2.7 | The battle screen | **DONE**, combat `0.14.0`. `src/ui/combat/battle_screen.gd`, `battle_host.gd`, `Battle.defs`, the twelve `ui.battle.*` strings, one `BattleHost` node in `game_root.tscn`, `battle_screen_test.gd` (16). The windowed capture shows the menu over the dimmed, paused courtyard. **Two changes from the plan:** hp bars are text lines (`{name} HP {hp} / {max}`), the template's placeholder look, so a game styles them; and the screen redraws from the battle after each command rather than listening to `vitals_changed`, because one source of truth cannot disagree with itself. Fighters must be built under a node in the tree; `BattleSetup` now says so, and logs an error otherwise. Red first: with the screen not driving enemy turns, 4 failed (the first try hung in an unbounded test loop, which is now bounded). Was planned as: `src/ui/screens/battle_screen.gd`, a modal `UiScreen`: a command menu, target select, a turn-order strip from `preview`, and hp bars from `Events.vitals_changed`. All strings keyed, with T6 input prompts. Closing it returns to the frozen field. Windowed capture. Tests: open pauses the world, and a scripted battle through the screen ends and closes it |
| C2.8 | Rewards, levels and the party | **DONE**, combat `0.15.0`. `src/content/combat/level_curve.gd`, `src/gameplay/combat/party.gd`, `rewards.gd`, plus fields on `Encounter` and `CombatantDef`, wiring in `BattleHost`, `BattleScreen`, `BattleSetup` and `Battle.encounter`, four `ui.battle.*` strings, and `party_rewards_test.gd` (18). **One change from the plan:** the party has no save section of its own. Its line-up, levels and experience are `Flags`, `Attributes`' rule, so it is saved and reset by a new game for nothing; the test proves a save round trip. A fallen member standing at 1 hp is the template default until C5's defeat flow. The layer checker caught an `@export_group("Rewards")` string naming the new gameplay class from content, and the group was renamed. Red first: with `Party.gain` stubbed, 5 failed. Was planned as: `Party` roster (active and reserve ids, its own save section, `Inventory`'s pattern), a `LevelCurve` resource (exp to level, with stat growth as base-stat deltas), exp on WON, and loot through `Inventory.of(player).add`. Tests: the curve, level-up applied to base stats, loot landing, and a save round trip |
| C2.9 | Demo proof: one turn-based encounter | **DONE**, combat `0.16.0`, and **phase C2 is closed**. `src/content/combat/party_roster.gd`, `BattleHost.roster_from` and the `[combat] party/roster` setting, `scenes/objects/encounter_point.tscn`, `data/party/roster.tres`, `data/skills/ember.tres`, `data/encounters/thorn_wisps.tres`, the courtyard's `WispNest`, five strings, and `AUTHORING.md` § Add an encounter and a party. `battle_screen_test.gd` gained 2 assertions (18). Two windowed captures: the reward screen over the frozen courtyard, with both members reaching level 2 and the Chipped Stone found; then, after Continue, the live field with the thicket, unpaused. Stripped run: `2880 passed, 0 failed, 25 skipped`, and all six checkers it runs exit 0. **One change from the plan:** the party is a data file named by a project setting rather than a field on the `BattleHost` node, so `game_root.tscn` names no content and a stripped template has no party rather than a broken reference. Was planned as: Data and scenes: a fixture-free encounter in the courtyard and a two-member demo party. A full fight from the field and back, as a windowed capture. The stripped run passes. `AUTHORING.md` § Add an encounter. **Closes phase C2**, and C3.0 plans the action formula |
| C2.10 | Handoff for any reader, and plain comments | **DONE**, combat `0.16.1`, at the owner's request: "write so future sessions on other accounts, Claude or another AI, can read it and know what is happening, and comment the code so I know what is what". `docs/HANDOFF.md` is the start-here page. It has a "Where things stand" block that every package now updates, five lines on what this is, how to pick up the work, the ladder, a plain-words map of every combat folder, how one fight flows, the rules that bite, and the closing checklist. The root `AGENTS.md` points other AI tools at it, and `CLAUDE.md` gains one pointer line. IN PLAIN WORDS paragraphs and inline comments were added to the four largest combat files. Comments are not code lines, so no budget moved. **Standing rule from here on:** every package updates HANDOFF's state block and comments any line whose reason is not obvious |
| C2.11 | Plan C2b, C3, C4 and C5 as rows | **DONE**, documents only, combat `0.16.2`. Three read-only passes read the player controller, input, interaction, layers, the character kit, `NpcBrain`, navigation, pause, time, the HUD, settings, audio and test stepping against §§ C2b–C5. The facts are in § C2b, "Settled by C2.11". It writes every row below, and stands in for C3.0 |
| C2.12 | Fixes found in review | TODO, next. `combat_content_test.gd`: every `name_key` and `label_key` in the combat data is in `strings.csv`, and `EncounterDb.problems()` is empty over `data/`. `Encounter.music` becomes an `AudioStream`, which `BattleHost` plays and then restores the area's. `Combatant` gives its `StatusSet` the save id `statuses/<id>` when it was left at the default |
| C2.13 | One shared skill path, and more effects | TODO. Extract `Battle._use` into `src/gameplay/combat/skill_use.gd`, so the battle, the field and the hybrid share it. `Skill.hits` adds multi-hit. `SkillEffect` content: DAMAGE, HEAL, RESTORE, DRAIN, CURE, DISPEL and REVIVE. The old `power` still works. Tests: each kind, multi-hit, revive targeting |
| C2.14 | Statuses that change behaviour | TODO. `StatusEffect.tags`; `blocks` SKIP_TURN, NO_SKILLS, NO_ITEMS and NO_FLEE; `breaks_on_hit`; resistance through the `resist_<tag>` stat. `Battle` skips a blocked turn and refuses a blocked command. Tests: each block, waking on a hit, resistance |
| C2.15 | Hit or miss, counters and reflect | TODO. `AccuracyStage` (accuracy against evasion) sets `DamageResult.missed`, and a skill may be `sure_hit`. Status reactions COUNTER and REFLECT. A miss is announced. Tests under a seed |
| C2.16 | Meters: stances, Boost and limit specials | TODO. One rule: `regen_<pool>` each turn and `fill_on_hit_<pool>`, which gives MP regen, Boost points and a limit gauge. `Skill.toggle_status` is a stance, on and off. `BattleCommand.boost` spends points to multiply power or hits. Specials cost the limit pool. Tests for each |
| C2.17 | Weakness and Break | TODO. The `shield` pool and `CombatantDef.weak_to`, by element or skill tag. A weakness hit takes one shield point and reveals the weakness. At 0, BROKEN skips the next turn and raises damage taken through `VulnerabilityStage`. Reveals are kept in `Flags`. C3's poise and C4's pressure reuse this path |
| C2.18 | A battle menu with depth | TODO. `BattleCommand.category` gives the submenus. Costs are shown and greyed out with their reason. On/Off for toggles. A Boost selector. Statuses and known weaknesses on each fighter's line. A short battle log. Keyed strings, and tests through the screen. Windowed capture |
| C2.19 | Demo proof: the depth, played | TODO. Fire, Heal, Cure, Raise, a buff, a debuff, Sleep, a stance, a limit special and Boost on the demo party, plus a wisp weak to fire. Captures of the submenu and of a Break. The stripped run passes. `AUTHORING.md` § Skills and statuses. **Closes C2b** |
| C3.0 | Plan the action formula: write C3's rows here | **Folded into C2.11**, which read the code and wrote C3's rows below. It was planned as: documents only, as C1.0 and C2.0 were: read the player controller, `NpcBrain`, navigation and the input contexts against § C3, then write rows of ≤8 files each |
| C3.1 | Combat input and layers | TODO. `src/systems/input/combat_actions.gd`: `attack` (J / pad X), `dodge` (K / pad RT), `lock_on` (L / pad LT) and `lock_cycle` (`;` / pad R3), defined at boot with `actions.gd` untouched. `combat_layers.gd` holds layer 11 `hitbox` and layer 12 `hurtbox`, named in `project.godot`. Rebinding waits for C5.3 |
| C3.2 | Moves as data, timing as pure code | TODO. `ActionMove`: startup, active and recovery seconds; a chain window; power, element, hits and poise; knockback; the hitbox shape. It can wrap a `Skill`, so spells are cast in real time. `MoveSet`: a chain, a dodge with i-frames, and skill slots. `MoveTimeline` (systems, pure) is stepped by `dt`. Tests step it |
| C3.3 | Hitbox and hurtbox | TODO. `Hitbox` (Area3D) hits each target once per swing. `Hurtbox.take()` checks factions and i-frames, resolves through `SkillUse` or `Combatant.hit`, takes poise down the C2.17 path, and emits `Events.knockback_requested`. Tests emit `area_entered` by hand |
| C3.4 | The player fights | TODO. `ActionHost` attaches `Vitals`, `StatusSet`, `Combatant`, `Hurtbox` and `ActionFighter` to the player on `player_spawned`, from the `ActionLoadout` named by `[combat] action/loadout`; `player.tscn` is untouched. `ActionFighter` respects `is_input_locked()`, runs the chain, drives the dodge and knockback through an `&"action"` lock token, and ticks `StatusSet.tick_seconds`. Tests step `_physics_process` |
| C3.5 | Lock-on | TODO. `LockOn`: the nearest hostile hurtbox in range and in front; cycling; dropping on range or defeat; facing the target. `Events.lock_on_changed`. Tests with placed fixture nodes |
| C3.6 | Enemies that chase, attack and retreat | TODO. `ActionEnemy` (its own script and prefab) reuses `NavigationAgent3D` and `NpcBrain.reachable_point`. `ActionBrain` content: aggro, leash, range, retreat and weighted moves. `ActionDecider` (systems, pure) holds the state transitions, tested without physics |
| C3.7 | Defeat, rewards and respawn | TODO. `Rewards.grant` no longer needs a `Battle`, so a field kill rewards. A defeated enemy stays gone until re-entry. `DefeatRule` content (RELOAD_SAVE, RESPAWN_AT_ENTRY, REVIVE_IN_PLACE) and `FieldDefeat` for the player |
| C3.8 | Field HUD | TODO. `CombatHud` under UILayer: the player's pools and statuses, the locked target's hp, and the skill slots. Hidden with no fighter. Driven by events |
| C3.9 | Demo proof: an action fight | TODO. A loadout, and two action enemies in `lantern_hall`. Captures of a swing, a hit, a dodge and lock-on. The stripped run passes. `AUTHORING.md` § Action combat. **Closes C3** |
| C4.1 | `CombatClock` | TODO. A combat-only time scale (a static var, so no autoload), read by every C3 node and by field status ticking. 0 is pause-and-play |
| C4.2 | ATB gauge | TODO. `AtbGauge` (systems, pure): segments, filling over time and on hits, guards and dodges. The rules live in `AtbRules` content |
| C4.3 | Command overlay | TODO. A `pauses_world=false` screen with C2.18's categories, spending ATB through `SkillUse`. It slows `CombatClock` to `[combat] hybrid/slow`, where 0 is wait mode. Its key is chosen here, against the buttons still free |
| C4.4 | Pressure and stagger | TODO. C2.17's Break and C3's poise, timed in seconds: PRESSURED, then STAGGERED, with damage taken raised |
| C4.5 | A party in the field | TODO. Followers for the active party, and switching which member you control |
| C4.6 | Allies think in real time | TODO. `BattleAi` decoupled from `Battle` through a `BrainContext`. Allies move by `ActionBrain` and spend ATB on weighted commands |
| C4.7 | Variants with no new system | TODO. One fixture test each: an ATB-menu battle, pause-and-play, and timed hits through a pure `TimedWindow` |
| C4.8 | Demo proof: a hybrid fight | TODO. One hybrid encounter, captures, and AUTHORING. **Closes C4** |
| C5.1 | Mixed formulas | TODO. `Encounter.mode` is TURN, ACTION or HYBRID. Touching an action enemy can start a turn-based fight |
| C5.2 | Saves around combat | TODO. Saving is refused while a battle screen is open. A field fight survives a save and load |
| C5.3 | Upstream seams | TODO. Rows on upstream's board first, then merged down: `Actions.extend` (rebindable extra actions), and a game-registered settings section for lock-on assist, wait/active mode, difficulty and auto-battle |
| C5.4 | Accessibility | TODO. A difficulty multiplier stage, auto-battle, hold-to-attack |
| C5.5 | Docs | TODO. `AUTHORING.md` combat chapters. `NEW_GAME.md` § Choose your combat, with the `combat.*` CSV prune |
| C5.6 | Playtest | TODO. `PLAYTEST.md`'s loop; each finding becomes a row |
| C5.7 | Release 1.0.0 | TODO. Release notes and a final strip test |

**Rules for the rows:** the same as upstream's board (`WORK_PACKAGES.md` § The rules), unchanged:

- one package at a time;
- about 8 files or 500 lines at most;
- the full ladder plus all seven checkers;
- a package is done only when merged.

**One addition:** a row that changes code ends with `git fetch template && git merge template/main`.
That merge either says "Already up to date", or it gets merged and the ladder is re-run, so the
upgrade path is tested every phase.
