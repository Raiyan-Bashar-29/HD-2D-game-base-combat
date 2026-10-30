# Combat base — situation, phases and board

**Read this second, after `CLAUDE.md`.** This repository is the **combat** fork of the HD-2D base
([ADR-0008](decisions/ADR-0008-combat-is-in-scope.md)).

- **This file:** this repository's own state, phases and board.
- **[`CONTEXT.md`](CONTEXT.md), `ROADMAP.md`, `WORK_PACKAGES.md` and `DEVLOG.md`:** the upstream
  base's record, still true for every system inherited from it.

**Last updated:** 2026-10-30 · **C3.8 complete. Combat version 0.33.0** (`[combat] core/version`; the boot log prints it). **New here? Read [`HANDOFF.md`](HANDOFF.md) first.** Seeded from upstream `aaf281b` (base `5.16.2`), full history kept, `template` remote set. **C1, the shared core, and C2, turn-based, are complete.** C2.11 planned everything that is left as rows. C2.12 fixed the review's gaps, C2.13 gave every formula one skill path, C2.14 made statuses change behaviour: sleep, stun, silence, resistance, C2.15 added misses, counters and reflect, C2.16 added meters, stances and Boost, C2.17 added weakness and Break, C2.18 gave the battle menu categories, costs, reasons, stances and Boost, C2.19 added the readout: pools, statuses, weaknesses and a battle log, and C2.20 put all of it into the demo. **C2b is complete.** C3.1 opened the action formula with its inputs and physics layers, C3.2 made moves data and their timing a pure clock, C3.3 added the hitbox and hurtbox that land them, C3.4 let the player fight in the field, C3.5 added lock-on, C3.6 gave real-time enemies a brain, C3.7 a body that chases and swings in the running game, and C3.8 made defeat mean something on both sides. **The next row is C3.9, the field HUD.**
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

### C2b — Combat depth · **COMPLETE**

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

### C3 — Action formula · **in progress**

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

- **0.33.0** — C3.8. Defeat, rewards and respawn.
  - New `Rewards.give` (no battle needed; `grant` now calls it) and `ActionHost.reward`.
  - `ActionEnemy` gains `experience`, `loot`, `linger` and `remember_defeat`, announces the new
    `Events.field_enemy_defeated` once, and is removed after lingering.
  - New `DefeatRule` (REVIVE_IN_PLACE, RESPAWN_AT_ENTRY, RELOAD_SAVE), `ActionLoadout.defeat_rule`,
    and `FieldDefeat`, fitted to the player by `ActionHost.equip`.
  - Upstream's `director.gd`: a comment only, the `NO CALLER` note on `reload_current_area`.
- `0.32.0` — C3.7. The enemy's body.
  - New `ActionEnemy` (CharacterBody3D) and prefab `scenes/objects/action_enemy.tscn`: builds
    its fighting parts from `fighter`, senses, asks its `ActionDecider`, walks by navmesh or
    straight, swings, reels, backs away, walks home, stops when fallen.
- `0.31.0` — C3.6. An enemy's brain.
  - New `ActionBrain` and `ActionBrainEntry` (content): aggro, give-up, leash, attack range and
    cooldown, speed, wandering, retreat, and weighted moves with reach and hp conditions.
  - New `ActionDecider` (systems, pure): IDLE, WANDER, CHASE, ATTACK, RETREAT, RETURN,
    STAGGERED and DEFEATED, and `pick`.
- `0.30.0` — C3.5. Lock-on.
  - New `LockOn` (`toggle`, `cycle`, `refresh`, `candidates`, `direction`; `reach` 10 m,
    `leash` 1.3, `cone` 70 degrees), fitted by `ActionHost.equip`.
  - Hurtboxes join `Hurtbox.GROUP`; `ActionFighter` faces a held target.
  - New signal `lock_on_changed(who, target)`.
- `0.29.0` — C3.4. The player fights.
  - New `ActionLoadout` (a `CombatantDef` and a `MoveSet`), named by the new project setting
    `[combat] action/loadout` (empty: no field combat).
  - `ActionHost` fits the spawned player with `Vitals`, `StatusSet`, `Combatant`, a `Hurtbox`
    with a capsule, a `Hitbox` and an `ActionFighter`; `equip` and `configured` are public.
  - New `ActionFighter`: chain, dodge, hit-stun, knockback, field status ticks, the `&"action"`
    lock token, and the body's velocity while busy.
  - `MoveTimeline.press` now leads from a dodge's or skill's recovery into the first swing.
- `0.28.0` — C3.3. Hitbox and hurtbox.
  - New `Hitbox` (strikes each hurtbox once per swing; `fit`, `sweep`, `strike`) and `Hurtbox`
    (`take`: refuses allies, itself and the fallen; i-frames are a dodge; resolves through
    `Combatant.hit` or `SkillUse.apply`; poise; knockback).
  - New `Weakness.wear(target, points)`; `ActionMove.poise` is an int.
  - New signals `attack_dodged` and `knockback_requested`.
- `0.27.0` — C3.2. Moves as data, timing as pure code.
  - New `ActionMove` (startup, active, recovery, chain window, i-frames, power, element, hits,
    poise, knockback, hitbox size and offset, travel speed, an optional `Skill`) and `MoveSet`
    (an attack chain, a dodge, skill slots), each with `problems()`.
  - New `MoveTimeline`, stepped by `dt`: phases entered per step, chain window, buffered
    presses, dodge-cancel of recovery, i-frames, a swing counter.
- `0.26.0` — C3.1. Combat input and layers.
  - New `CombatActions` (`combat_attack` K / pad X, `combat_dodge` Space / right trigger,
    `combat_lock_on` Q / left trigger, `combat_lock_cycle` R / right stick) and `install()`.
  - New `CombatLayers`: layer 11 `hitbox`, layer 12 `hurtbox`, named in `project.godot`.
  - New `ActionHost` node under GameRoot, which installs the actions at boot.
  - What a consuming game must do: nothing, unless it already uses K, Q, R, Space, pad X, the
    right stick click or a trigger. Then it moves one of them (`combat_input_test.gd` names
    the clash).
- `0.25.0` — C2.20. The depth, played, which closes C2b.
  - `start_<pool>`: a stat giving the fraction of its maximum an unset pool starts at
    (`Vitals`). Without one, a pool still starts full.
  - Battle's DEFEND status has a name (`ui.battle.status.defend`).
  - Demo data: eight new skills, four statuses, a Magic and a Special menu, Boost and a limit
    gauge on the Wanderer, and wisps weak to fire and blades.
  - What a consuming game must do: nothing. A game that keeps the demo gets a longer fight
    (wisps have 60 hp, not 22). A game that strips it deletes the new `combat.*` rows with the
    rest.
- `0.24.0` — C2.19. The battle readout.
  - `StatusEffect.name_key`; `StatusSet.held()`.
  - New `BattleLog` (`start`, `stop`, `status_name`, `lines`); `BattleScreen.battle_log`.
  - Each fighter's line shows every pool it has, its statuses and its revealed weaknesses.
    Fifteen new `ui.battle.*` strings.
  - What a consuming game must do: nothing. Give statuses a `name_key` to name them; without
    one the readout shows the last part of the id.
- `0.23.0` — C2.18. A battle menu with depth.
  - `BattleCommand.category`; new `BattleMenu` (`top_level`, `in_category`, `refusal`).
  - `BattleScreen`: submenus, costs on rows, greyed rows with a reason, stance On/Off, a Boost
    selector. Eleven new `ui.battle.*` strings.
  - What a consuming game must do: nothing. A command with no `category` stays on the first
    menu. A skill row now shows its cost, and an unaffordable one is greyed out instead of
    refused after a press.
- `0.22.0` — C2.17. Weakness and Break.
  - New `Weakness` (`strike`, `recover`, `revealed`, `keys_of`, `broken_status`) and
    `VulnerabilityStage` (in `DamageFormula.standard()`, after element).
  - `Combatant.weak_to`, `attack_tags` and `kind`; `CombatantDef.weak_to` and `attack_tags`,
    copied by `BattleSetup`.
  - New signals `weakness_revealed` and `combatant_broken`.
  - What a consuming game must do: nothing. With no `weak_to`, `max_shield` or `damage_taken`,
    nothing changes. A custom formula `.tres` gains the Break damage bonus only if it lists a
    `VulnerabilityStage`.
- `0.21.0` — C2.16. Meters, stances and Boost.
  - New `Meters`: `regen_<pool>` stats refill a pool each turn, and `fill_on_hit_<pool>` stats
    fill it from damage taken. `StatSheet.mentioned(prefix)`.
  - `Skill.toggle_status` (a stance), `boost_power` and `boost_hits`; `SkillUse.stance_on`, and
    `SkillUse.apply` takes a `boost`.
  - `Battle.act(command, targets, boost = 0)`, `can_boost`, `boost_pool`, `boost_max` and
    `attack_boost_hits`.
  - What a consuming game must do: nothing. With no `regen_*`, `fill_on_hit_*` or `max_bp`
    stats, nothing moves on its own and nobody can boost.
- `0.20.0` — C2.15. Hit or miss, counters and reflect.
  - `AccuracyStage` (first in `DamageFormula.standard()`), `DamageResult.missed`,
    `DamageRequest.sure_hit`, `Skill.sure_hit` and `Skill.tags`.
  - `StatusEffect.Reaction` (COUNTER, REFLECT), `reactions`, `reaction_chance`, `reflect_tag`;
    `StatusSet.reactor`; `SkillUse.counter`.
  - New signals `attack_missed`, `countered` and `skill_reflected`.
  - What a consuming game must do: nothing. With no `evasion` stat anywhere, accuracy draws no
    random number, so every seeded fight replays as before. A custom formula `.tres` gains
    misses only if it lists an `AccuracyStage`.
- `0.19.0` — C2.14. Statuses that change behaviour.
  - `StatusEffect.blocks` (SKIP_TURN, NO_SKILLS, NO_ITEMS, NO_FLEE) and `breaks_on_hit`.
  - `StatusSet.blocker` and `wake`.
  - Resistance through `resist_<tag>` stats; `apply` takes an optional rng.
  - `Battle.allows`, and sleepers lose their turns.
  - Two new bus signals, `status_resisted` and `turn_skipped`.

  A game does: nothing.
- `0.18.0` — C2.13. One shared skill path.
  - `SkillEffect` content (DAMAGE, HEAL, RESTORE, DRAIN, CURE, DISPEL, REVIVE).
  - `Skill.hits`, `Skill.effects` and `Skill.revives()`.
  - `StatusEffect.tags` and `StatusSet.cure_tagged`.
  - `SkillUse` (`affordable`, `pay`, `apply`), which `Battle` now calls.
  - A reviving skill targets only the fallen, and the revived rejoin the turn order.

  A game does: nothing; existing skills behave the same.
- `0.17.0` — C2.12. Fixes found in review.
  - **Breaking for data:** `Encounter.music` is an `AudioStream`, not an id. `BattleHost` plays it,
    then restores the area's music.
  - `StatusSet.DEFAULT_SAVE_ID` and `rename_save`. `Combatant` renames a default save id to
    `statuses/<id>`.
  - `combat_content_test.gd` gates the combat data's translation keys.

  A game does: re-set any `music` it had typed as an id, which nothing played before.
- `0.16.2` — C2.11. A patch, documents only: the plan for C2b to C5, read against the code. A game does: nothing.
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
| C2.12 | Fixes found in review | **DONE**, combat `0.17.0`. New `combat_content_test.gd`: every `name_key` and `label_key` the combat data under `data/` names (skills, encounter enemies, roster members, their commands and those commands' skills) is a row in `strings.csv`, and `EncounterDb.problems()` is empty. It finds nothing in the stripped run. `Encounter.music` is now an `AudioStream`. `BattleHost` plays it when the screen opens and, when the screen leaves the tree, restores the live area's music through `BattleHost.area_music`. A `StatusSet` left at `StatusSet.DEFAULT_SAVE_ID` is renamed by its `Combatant` to `statuses/<id>` through the new `rename_save`. `combatant_test` gained 3 assertions and `battle_screen_test` gained 2. Red first: with the check stubbed, 1 failed; with the rename stubbed, 2 failed. A throwaway engine probe opened the demo fight with a stream and logged `Music -> <stream>` while open, then `Music -> (silence)` (the courtyard's own) after closing |
| C2.13 | One shared skill path, and more effects | **DONE**, combat `0.18.0`. New files:<ul><li>`src/content/combat/skill_effect.gd`: DAMAGE, HEAL, RESTORE, DRAIN, CURE, DISPEL and REVIVE, each with `problems()`.</li><li>`src/gameplay/combat/skill_use.gd`: `affordable`, `pay` and `apply`, which together are what a skill does, shared by every formula.</li><li>`skill_use_test.gd` (19).</li></ul>Other changes:<ul><li>`Skill` gains `hits`, `effects` and `revives()`. `problems()` now catches hits below 1 and a heal, restore or revive aimed at enemies.</li><li>`StatusEffect` gains `tags`, and `StatusSet` gains `cure_tagged`.</li><li>`Battle._use` now calls `SkillUse`. `targets_for` aims a reviving skill only at the fallen, and `_settle` puts the revived back into the turn order.</li></ul>Behaviour:<ul><li>Statuses roll once per target, not once per hit.</li><li>DRAIN gives back a share of the hp actually taken.</li><li>Negative `power` still heals, and `battle_test` passes unchanged.</li></ul>Red first: with the effects stubbed, 9 failed. **One change from the plan:** tags arrive here, because DISPEL needs them; C2.14 adds blocks and resistance on top |
| C2.14 | Statuses that change behaviour | **DONE**, combat `0.19.0`. `StatusEffect.Block` (SKIP_TURN, NO_SKILLS, NO_ITEMS, NO_FLEE), `blocks`, `breaks_on_hit` and `has_block`; `problems()` refuses a turn-skipper that never ends. `StatusSet.blocker(block)`, `wake()`, and resistance inside `apply(effect, rng)`: the strongest `resist_<tag>` stat on the holder's sheet, where 1 is immune and a fraction rolls. `Combatant.receive` wakes a sleeper on a hit that really hurt. `Battle.allows(command)` refuses blocked commands, and `act` honours it. `next_turn` skips a sleeper, deciding before the tick so a sleep of N turns costs exactly N, with a cap so a field where everyone sleeps returns null rather than looping. `BattleAi` never picks a blocked command. New `Events.status_resisted` and `Events.turn_skipped`. `SkillUse` passes its seeded rng to the resistance roll. `status_behaviour_test.gd` (16). Red first: with blocks and resistance stubbed, 10 failed |
| C2.15 | Hit or miss, counters and reflect | **DONE**, combat `0.20.0`. New `src/systems/combat/accuracy_stage.gd`: `base_accuracy` plus the attacker's `accuracy` minus the defender's `evasion`; a certain hit draws nothing, and a miss zeroes the amount and stops the later stages. `DamageResult.missed`, `DamageRequest.sure_hit`, `Skill.sure_hit` and `Skill.tags`; `Combatant.hit` takes `sure_hit`, and `receive` emits `attack_missed` instead of `combatant_damaged` on a miss. `StatusEffect.Reaction` (COUNTER, REFLECT), `reactions`, `reaction_chance` and `reflect_tag`, with `StatusSet.reactor`. `SkillUse.apply` bounces a skill carrying the reflect tag back to its user; `SkillUse.counter` strikes back after a plain ATTACK that landed, and `Battle` calls it. New `Events.attack_missed`, `countered` and `skill_reflected`. `hit_reaction_test.gd` (19). Red first: with the stage, the miss and both reactions stubbed, 14 failed. **One change from the plan:** a miss emits only `attack_missed`, not a 0 on `combatant_damaged`, so no listener has to tell a miss from a hit for 0 |
| C2.16 | Meters: stances, Boost and limit specials | **DONE**, combat `0.21.0`. New `src/gameplay/combat/meters.gd`: `regen_turn` adds each `regen_<pool>` stat to its pool, and `fill_on_hit` puts the `fill_on_hit_<pool>` fraction of damage taken into its pool; `StatSheet.mentioned(prefix)` finds them by name. `Battle.next_turn` regenerates the actor after the status tick and before the defeat check; `Combatant.receive` fills on damage. `Skill.toggle_status` makes a stance: on pays the cost, off is free, and it does nothing else (`problems()` says so); `SkillUse.stance_on`. Boost: `Battle.act(command, targets, boost)` with `can_boost`, `boost_pool` (`bp`), `boost_max` (3) and `attack_boost_hits` (1); a skill grows by `boost_power` per level and lands `boost_hits` more times. Points are spent only if the action happens. A limit special needs no code: a skill whose cost is the full `limit` pool. `meters_test.gd` (21). Red first: 11 failed. **Changes from the plan:** the boost level is an argument to `act`, not a field on `BattleCommand`, because a command is a shared menu slot and the level is chosen each turn; and Boost scales a skill's own power, not the whole hit. The SPECIAL menu category is C2.18's |
| C2.17 | Weakness and Break | **DONE**, combat `0.22.0`. New `src/gameplay/combat/weakness.gd`: `strike(target, keys)` reveals each matched weakness under `weakness/<kind>/<key>` in `Flags` and takes one point of the `shield` pool (`max_shield`); the last point applies `broken_status()` (one lost turn, `damage_taken` +0.5, replaceable through `Weakness.broken`) and emits `combatant_broken`; `recover` refills the shield once the break is over, and `Battle.next_turn` calls it after the tick. New `src/systems/combat/vulnerability_stage.gd` multiplies by 1 + `damage_taken`, in the standard formula after element. `Combatant.weak_to`, `attack_tags` and `kind`; `CombatantDef.weak_to` and `attack_tags`, which `BattleSetup` copies, with `kind` set to the definition id. Skill hits match the element and `Skill.tags`, and a plain ATTACK matches `attack_tags`; only landed hits count. `weakness_test.gd` (14). Red first: 7 failed. **One change from the plan:** a weakness lives on `Combatant` as well as `CombatantDef`, so a hand-built fighter (a test, C3's field enemy) has one too |
| C2.18 | A battle menu with depth | **DONE**, combat `0.23.0`. `BattleCommand.category` (a localization key). New `src/ui/combat/battle_menu.gd`: `top_level` (commands and category rows in authored order), `in_category`, and `refusal`, which gives the reason key from the same checks `Battle.act` makes (a status forbids it, not enough of a pool, none left, nothing to aim at, no escape, cannot be boosted). `BattleScreen` opens a submenu per category with Back, shows each skill's cost, greys out a refused row with its reason and no action, shows a stance as On or Off (a stance acts on its user at once), and gives a fighter with a Boost pool a Boost row that steps the level the next action spends; both reset after an action. `battle_menu_test.gd` (15); `battle_screen_test.gd` updated for greyed rows. Red first: with `refusal` stubbed, 16 failed. Windowed capture of the first menu and of a submenu. **Split from the plan:** the readout (statuses and weaknesses on each fighter's line, and the battle log) moved to a new C2.19 to keep this row inside one package; the demo is now C2.20 |
| C2.19 | The battle readout | **DONE**, combat `0.24.0`. `StatusEffect.name_key` and `StatusSet.held()`. Each fighter's line in `BattleScreen` shows hp, every other `max_*` pool it has (MP, BP, a limit gauge, its shield), its statuses by name in brackets, and "Weak:" with only the weaknesses `Weakness.revealed` says were found. New `src/ui/combat/battle_log.gd`: while the screen is open it listens on `combatant_damaged`, `attack_missed`, `status_resisted`, `turn_skipped`, `countered`, `skill_reflected`, `weakness_revealed`, `combatant_broken`, `combatant_defeated` and `status_applied`, keeps the newest 4 lines, and the screen draws them under the turn order; `stop()` on close disconnects every handler. `battle_readout_test.gd` (13). Red first: with the log not listening, 6 failed. Windowed capture |
| C2.20 | Demo proof: the depth, played | **DONE**, combat `0.25.0`. **Closes C2b.** New demo data: statuses `drowse` (sleep, breaks on hit), `guard_up` (buff), `weaken` (debuff) and `keen_edge` (a stance: +6 attack, -1 mp a turn); skills Salve (heal), Cleanse (dispel ailments), Rekindle (revive), Bulwark (buff), Blight (debuff), Lull (sleep), Keen Edge (stance) and Skyfall (a limit special, sure hit), and Ember gains `magic`, Boost and a Magic category. The Wanderer has Magic and Special menus, Boost (`start_bp`, `regen_bp`) and a limit gauge filled by damage; the Keeper has a healer's Magic menu and MP regen. The thorn wisps are weak to fire and blades with 2 shield points, 10% evasion, 60 hp, and may sing Lull. **One fix found by playing it:** an unset pool started full, so the limit gauge began at 100; `Vitals` now reads `start_<pool>` (two assertions in `meters_test.gd`, red first). Default DEFEND got a name. `combat_content_test.gd` now also checks status names, category keys, and that every skill and status is sound (red first: 14 missing strings). Several demo ids were renamed (`keen_edge`, `salve`, `drowse`, `rekindle`, `blight`) because `check_boundary` found `focus`, `mend`, `sleep`, `raise` and `hex` already used as words under `src/` and `tests/`. Windowed captures: the Wanderer's Magic menu, and a wisp broken by a second Ember. Stripped run green. `AUTHORING.md` § Skills, statuses and combat depth |
| C3.0 | Plan the action formula: write C3's rows here | **Folded into C2.11**, which read the code and wrote C3's rows below. It was planned as: documents only, as C1.0 and C2.0 were: read the player controller, `NpcBrain`, navigation and the input contexts against § C3, then write rows of ≤8 files each |
| C3.1 | Combat input and layers | **DONE**, combat `0.26.0`. New `src/systems/input/combat_actions.gd`: `combat_attack` (K, pad X), `combat_dodge` (Space, right trigger), `combat_lock_on` (Q, left trigger) and `combat_lock_cycle` (R, right stick click); `install()` defines each one not already in the InputMap, so it is idempotent and never overwrites. New `src/systems/combat/combat_layers.gd`: `HITBOX` (layer 11) and `HURTBOX` (layer 12) with their masks, named `hitbox` and `hurtbox` in `project.godot`. New `src/gameplay/combat/action_host.gd`, a node under GameRoot in `game_root.tscn` that installs the actions at boot; C3.4 grows it. `actions.gd` and `layers.gd` are untouched. `combat_input_test.gd` (12), including a check that no combat binding is any other action's. Red first: with `install()` stubbed, 5 failed. **Changes from the plan:** J is the journal's key, so attack is K and the other keys moved with it; the actions are prefixed `combat_` so they can never collide with an upstream action name; `ActionHost` arrives now rather than in C3.4, because something under GameRoot has to call `install()`. Rebinding waits for C5.3 |
| C3.2 | Moves as data, timing as pure code | **DONE**, combat `0.27.0`. New `src/content/combat/action_move.gd`: three phase times in seconds, `chain_after` (seconds into recovery when the next swing may start), `iframes_from`/`iframes_to` (seconds from the move's start), `power`, `element`, `hits`, `poise`, `knockback`, `hitbox_size` and `hitbox_offset` (forward is -z), `travel_speed` and an optional `skill`; `strikes()`, `length()`, `problems()`. New `src/content/combat/move_set.gd`: `attack_chain`, `dodge` (null means none), `skills`; `problems()` flags an empty chain and a dodge with no i-frames. New `src/systems/combat/move_timeline.gd` (pure RefCounted): `step(dt)` returns the phases entered, in order, so one long frame never skips a phase; `press(chain)` starts or continues the chain, buffering a press up to `buffer_window` (0.25 s) before the window and dropping an earlier one; `start(move)` plays a dodge or skill; `can_dodge()` is idle or recovery; `invulnerable()`; `cancel()`; `swing` counts moves started so a hitbox hits once per swing. `move_timeline_test.gd` (22). Red first: with `step` stubbed, 14 failed, one of them a real double report in `problems()`. **Changes from the plan:** the dodge is an `ActionMove` with i-frames and `travel_speed`, not a separate shape, so one clock times swings, rolls and casts; resolving a wrapped `Skill` belongs to C3.3's hitbox |
| C3.3 | Hitbox and hurtbox | **DONE**, combat `0.28.0`. New `src/gameplay/combat/hitbox.gd` (Area3D on layer 11, masking 12): `attacker` (the Combatant beside it), `timeline`, `rng`; `fit(move)` builds its BoxShape3D from the move's size and offset; `strike(hurtbox)` acts only while `timeline.is_hitting()` and once per hurtbox per swing, forgetting on a new swing or a new clock; `area_entered` calls it, and `sweep()` catches hurtboxes already inside when the swing goes live. New `src/gameplay/combat/hurtbox.gd` (Area3D on layer 12, not monitoring): `fighter()`, `timeline` for i-frames, `take(attacker, move, rng, from)` refuses itself, the faction filter (the skill's target, else ENEMY) and the fallen; in i-frames it emits `attack_dodged`; else a wrapped skill goes through `SkillUse.apply` and a plain move hits `hits` times through `Combatant.hit`, each landed hit calling `Weakness.strike` with the element and the attacker's `attack_tags`; if anything landed, `Weakness.wear(poise)` and `knockback_requested` (flat, away from `from`). `Weakness.strike` and the new `wear` share `_chip`. `ActionMove.poise` became an int (shield points). `hitbox_test.gd` (17). Red first: with `take` stubbed, 9 failed; then a real defect: a fresh clock restarts its swing count, so the hitbox now also forgets when its clock changes. **Changes from the plan:** a dodge is announced by its own signal, `attack_dodged`, not as a miss; COUNTER does not fire in real time yet (a gap) |
| C3.4 | The player fights | **DONE**, combat `0.29.0`. New `src/content/combat/action_loadout.gd` (`fighter`, `moves`, `problems()`), named by the new `[combat] action/loadout` (empty by default: no field combat). `ActionHost` listens on `player_spawned` and, deferred, calls `equip(body, loadout)`: `Vitals`, `StatusSet`, a `Combatant` from the definition, a `Hurtbox` with a 0.4 x 1.6 m capsule, a `Hitbox` and an `ActionFighter`; a body that already has a `Combatant` is left alone. New `src/gameplay/combat/action_fighter.gd`: `drive(delta, attack, dodge)` (called from `_physics_process` with the `CombatActions` just pressed) ticks `StatusSet.tick_seconds`, refuses while anything but its own `&"action"` token holds the player, runs the chain and the dodge (rolling the way the body moves, else the way it faces), fits, turns and sweeps the hitbox, and while busy holds the lock and owns the horizontal velocity: the knockback push, a move's `travel_speed`, or zero. A knockback cancels the swing and stuns for `stun_time` (0.25 s); a SKIP_TURN status counted in SECONDS stuns too, one counted in TURNS does not. `action_fighter_test.gd` (23) drives a real `player.tscn`. Red first: with moves stubbed, 8 failed. A headless probe of the real game (a temporary loadout, real `Input` presses) then showed the fitting at spawn, a 6 m/s roll, the lock, and a gap: an attack in a dodge's recovery was dropped, so `MoveTimeline.press` now leads from a dodge's or skill's recovery into the chain (+1 assertion in `move_timeline_test.gd`). **Changes from the plan:** the fighter, not the controller, owns the velocity while busy, through the existing lock; `drive` takes the buttons as arguments so tests need no `Input` |
| C3.5 | Lock-on | **DONE**, combat `0.30.0`. New `src/gameplay/combat/lock_on.gd`, a Node beside the fighter's `Combatant`, fitted by `ActionHost.equip`. `toggle(facing)` locks the nearest hostile (`Combatant.can_target` ENEMY), standing hurtbox within `reach` (10 m) and within `cone` (70 degrees) of the facing, or lets go; `cycle()` walks every hostile in reach nearest first, wrapping, behind included; `refresh()` drops a target that fell, left the tree or went past `reach * leash` (1.3); `candidates()`, `direction()`. Its `_physics_process` reads `combat_lock_on` and `combat_lock_cycle`. Every change emits the new `Events.lock_on_changed(who, target)`, `&""` for none. Targets are found through the new `Hurtbox.GROUP`, never physics. `ActionFighter` faces a held target, and stops turning to its velocity while locked. `lock_on_test.gd` (13) with placed fixture nodes. Red first: with the search stubbed, 11 failed. **Changes from the plan:** none |
| C3.6 | An enemy's brain: chase, attack and retreat as pure decisions | **DONE**, combat `0.31.0`. New `src/content/combat/action_brain.gd` (`aggro_radius` 6, `give_up_radius` 10, `leash_radius` 14, `attack_range` 1.6, `attack_cooldown` 1, `move_speed` 2.5, `wander_radius` 2 every `wander_every` 3 s, `retreat_below` and `retreat_distance`, `moves`; `problems()`) and `src/content/combat/action_brain_entry.gd` (`move`, `weight`, `reach` (0 means the brain's range), `min_reach`, `only_below`). New `src/systems/combat/action_decider.gd` (pure): `think(delta, target_distance, home_distance, hp_fraction, busy, stunned, defeated, rng)` returns IDLE, WANDER, CHASE, ATTACK, RETREAT, RETURN, STAGGERED or DEFEATED, checked in that priority, with `chosen` set on a new ATTACK; the cooldown starts when a move ENDS; RETURN ignores everyone until home; DEFEATED is final. `pick(distance, hp_fraction, rng)` draws by weight among the entries whose reach and hp conditions hold. `action_decider_test.gd` (21). Red first: with the choosing stubbed, 11 failed. **Changes from the plan:** the row was split, because the body, its prefab and its test would have taken it past 8 files: the brain and the decider are this row, the body is the new C3.7, and the rows after it moved down one. Any move whose reach covers the target may start an attack, so a lunge is used from afar; `attack_range` is the default reach and how near the body walks in |
| C3.7 | The enemy's body | **DONE**, combat `0.32.0`. New `src/gameplay/combat/action_enemy.gd` (CharacterBody3D on layer NPC, masking WORLD) and prefab `scenes/objects/action_enemy.tscn` (a capsule, the placeholder `CharacterVisual`, a `NavigationAgent3D` named Agent). Exports `fighter` (CombatantDef), `brain` (ActionBrain), `stun_time` (0.3 s). On ready it builds `Vitals`, `StatusSet`, a `Combatant` (id `<definition id>/<node name>`, kind the definition id), a `Hurtbox` with a capsule and a `Hitbox`, all sharing its `MoveTimeline`, with every pool full. `act(delta)` ticks statuses, senses `nearest_hostile()` (the faction table's ENEMY, standing, through `Hurtbox.GROUP`), home distance and hp, asks `decider.think`, and acts: CHASE walks in to 0.9 of `attack_range` then stands facing; ATTACK starts `chosen` facing the target and fits the hitbox; RETREAT backs away; RETURN walks home; WANDER walks half speed to a point near home (clamped by `NpcBrain.reachable_point`); STAGGERED cancels the move and takes the knockback push; DEFEATED stops. It walks the navmesh path through its agent when the area has a navmesh, straight when not. `_physics_process` adds gravity, `move_and_slide` and the sprite. `action_enemy_test.gd` (13). Red first: with the acting stubbed, 6 failed. **Real-game proof:** a headless probe placed one 4 m from the fitted player in the courtyard: it noticed, walked in through physics, attacked at 1.58 m, and its hitbox overlapped the player's hurtbox for real, 5 damage a swing (3 + 2), every ~1.6 s; a windowed capture shows it at the player's side. **Changes from the plan:** none |
| C3.8 | Defeat, rewards and respawn | **DONE**, combat `0.33.0`. `Rewards.give(experience, loot, members, inventory)` needs no `Battle`, and `grant` now collects the standing members and calls it. `ActionHost.reward(experience, loot, player, loadout)` gives a field kill's experience to the loadout's fighter, unless the player is down, and its loot to the player's `Inventory`; `ActionHost` grants it on the new `Events.field_enemy_defeated(who, experience, loot)`. `ActionEnemy` gains `experience`, `loot`, `linger` (1 s) and `remember_defeat`: the first think after it falls announces its defeat once and starts the linger clock, and then it is removed. Re-entering the area builds it afresh, because enemies live in the area scene; with `remember_defeat` the flag `field_defeated/<area>/<node name>` keeps it gone for good. New `src/content/combat/defeat_rule.gd` (`kind` REVIVE_IN_PLACE, RESPAWN_AT_ENTRY (the default) or RELOAD_SAVE, `revive_fraction` 0.5, `delay` 2 s) and `ActionLoadout.defeat_rule`. New `src/gameplay/combat/field_defeat.gd`, fitted by `equip`: on its fighter's defeat it holds the player with the `&"defeated"` lock; after `delay` it gets them up in place, or re-enters the area (or loads the latest save, falling back to re-entering) and gets them up only on `area_entered`, then lets go. `field_defeat_test.gd` (12). Red first: with `give`, `_fall` and `_carry_out` stubbed, 12 failed (8 new and 4 turn-based reward assertions, which proves `grant` routes through `give`). **A probe of the running game** fitted the player, killed a weak enemy with one real swing ("Field victory: 9 experience", the enemy removed), then let a strong one fell the player. It found a real defect: the player got up before the reload, among the same enemies, and fell again. Getting up now waits for `area_entered`. Run again: one fall, one re-entry, 15 hp, the enemy gone. **Upstream file touched:** `director.gd`, a comment only. Its `NO CALLER` note on `reload_current_area` became stale, so `check_methods` failed. **Changes from the plan:** no flag is needed for "gone until re-entry", because the area scene rebuilds its enemies; the flag is only for `remember_defeat`. 9 code files, one over the guide, kept as one row because the parts only prove each other together |
| C3.9 | Field HUD | TODO. `CombatHud` under UILayer: the player's pools and statuses, the locked target's hp, and the skill slots. Hidden with no fighter. Driven by events |
| C3.10 | Demo proof: an action fight | TODO. A loadout, and two action enemies in `lantern_hall`. Captures of a swing, a hit, a dodge and lock-on. The stripped run passes. `AUTHORING.md` § Action combat. **Closes C3** |
| C4.1 | `CombatClock` | TODO. A combat-only time scale (a static var, so no autoload), read by every C3 node and by field status ticking. 0 is pause-and-play |
| C4.2 | ATB gauge | TODO. `AtbGauge` (systems, pure): segments, filling over time and on hits, guards and dodges. The rules live in `AtbRules` content |
| C4.3 | Command overlay | TODO. A `pauses_world=false` screen with C2.18's categories (`BattleMenu`), spending ATB through `SkillUse`. It slows `CombatClock` to `[combat] hybrid/slow`, where 0 is wait mode. Its key is chosen here, against the buttons still free |
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
