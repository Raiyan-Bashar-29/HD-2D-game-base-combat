# Combat base — situation, phases and board

**Read this second, after `CLAUDE.md`.** This repository is the **combat** fork of the HD-2D base
([ADR-0008](decisions/ADR-0008-combat-is-in-scope.md)).

- **This file:** this repository's own state, phases and board.
- **[`CONTEXT.md`](CONTEXT.md), `ROADMAP.md`, `WORK_PACKAGES.md` and `DEVLOG.md`:** the upstream
  base's record, still true for every system inherited from it.

**Last updated:** 2026-10-29 · **C1.5 complete. Combat version 0.5.0** (`[combat] core/version`; the boot log prints it). Seeded from upstream `aaf281b` (base `5.16.2`),
full history kept, `template` remote set; upstream `5.16.3` merged in cleanly the same day. **The shared core has stats, vitals, the damage pipeline and statuses. The next row is C1.6, factions, targeting and `Combatant`.**

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

### C1 — Shared combat core (both formulas use it)

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

### C2 — Turn-based formula

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

- **0.5.0** — C1.5. Statuses: `StatusEffect` content (`data/statuses/`, id `status/<name>`)
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
| C1.6 | Factions, targeting and `Combatant` | TODO, next. Faction hostility (content); target filters SELF / ALLY / ENEMY / ANY; a `Combatant` component tying sheet, vitals, statuses and faction to a `combatant_id`; `receive(request)` resolves, applies and emits `Events.combatant_damaged`. Tests: hostility, filters, a request through to defeat |
| C1.7 | Demo proof: a training dummy | TODO. Data and a scene only, nothing under `src/` names it. Interacting deals one resolved hit and shows the result; a windowed capture; the stripped run still passes; a short "combat core" note in `AUTHORING.md` |

**Rules for the rows:** the same as upstream's board (`WORK_PACKAGES.md` § The rules), unchanged:

- one package at a time;
- about 8 files or 500 lines at most;
- the full ladder plus all seven checkers;
- a package is done only when merged.

**One addition:** a row that changes code ends with `git fetch template && git merge template/main`.
That merge either says "Already up to date", or it gets merged and the ladder is re-run, so the
upgrade path is tested every phase.
