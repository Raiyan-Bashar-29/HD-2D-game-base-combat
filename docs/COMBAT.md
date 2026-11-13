# Combat base — situation, phases and board

**Read this second, after `CLAUDE.md`.** This repository is the **combat** fork of the HD-2D base
([ADR-0008](decisions/ADR-0008-combat-is-in-scope.md)).

- **This file:** this repository's own state, phases and board.
- **[`CONTEXT.md`](CONTEXT.md), `ROADMAP.md`, `WORK_PACKAGES.md` and `DEVLOG.md`:** the upstream
  base's record, still true for every system inherited from it.

**Last updated:** 2026-11-13 · **C9.5b complete: a piece that breaks, and adapting resistance. The passive effect `BREAK_PIECE` (`GearBreak`), the event `SKILL_DONE`, and a `GIVE_STATUS` that picks its status by the element of the hit (`per_element`). Combat `0.97.0`. Next: C9.5c, the berserk status and upgrade levels won by fights.**
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
  - Rebinding these needed an upstream seam. Upstream T7.3 (`5.18.0`) added
    `Actions.add_rebindable`, and C5.3a uses it.
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
  for C5.3b (after upstream T7.4). Until then, project settings.

### C3 — Action formula · **complete** (C3.1–C3.10)

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

### C4 — Hybrid formula (semi-real-time, FF7 Remake-style) · **complete**

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

### C5 — Mix-and-match and hardening · **in progress**

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

### C6 — Hero powers · **planned** (C6.0 done)

- **The design is [`POWERS.md`](POWERS.md):** the research, the framework, the fourteen shared
  mechanisms and one section per character.
- **The owner's request (2026-11-03):** special powers for the main character, starting from
  Gilgamesh, Kishou Arima, Satoru Gojo, Escanor, Lelouch, Yhwach, the Barnabas and Odin Eikon,
  Vergil and Dante, with more characters to come.
- **The rule that shapes it:** a character is a data file (`data/powers/<kit>.tres`). Adding
  one changes no existing kit and no code, unless it needs a mechanism nobody has yet.
- **Real names for now, by the owner's decision.** They live only in data and the CSV, never
  under `src/`. See `POWERS.md` § Renaming.
- **Proof:** each kit row ends in a probe and a windowed capture of its powers in the lantern
  hall.

### Game choices: the base builds none of these

Classes, job systems, a bestiary and difficulty tuning. **Art stays deferred.**

### C7 — Gear · **designed** (the owner's request, 2026-11-10)

- **The request, three messages:** the heroes' signature weapons inside the game (Arima's IXA
  and Owl, Gilgamesh's Ea, the best-known fictional armours) with gear, gear types, special
  gear, rarity and crafting under them; abilities that change the battleground or move the
  fight elsewhere; transformations that change abilities, stats and the look; and a survey of
  the mechanics popular games use.
- **The design is [`docs/GEAR.md`](GEAR.md)** (C7.0). Gear is an upstream `ItemDefinition`
  plus a `GearDefinition`, worn through a fork `GearSet`; a signature weapon grants a
  `PowerKit` and its modes are forms.
- **It also widened phase C6:** the domain row is now four battlefield rows (C6.9a–d), and
  there are two new rows, C6.5d (transformations with a look) and C6.26 (M15 `plant`).
- **Real names for now**, as for the powers, in data and the CSV only.

### C8 — Mechanics from the survey · **planned**

`GEAR.md` § Part 5 compares this base with what well-known games do. What is missing became
rows C8.1 to C8.9. Each is designed in its own row, red first.

## Releases

Each row that changes code bumps `[combat] core/version`, with the same promise upstream's
`CHANGELOG.md` makes. **A bold version in this file is a claim about the CURRENT one** and
`combat_record_test.gd` holds it to that; every other spelling is a record of what was.

- **0.97.0** — C9.5b, a piece that breaks, and adapting resistance. New `GearBreak.giver`; `PassiveEffect.Kind.BREAK_PIECE` and `PassiveEffect.per_element`; `PassiveTrigger.Event.SKILL_DONE` (told by `SkillUse.apply` after the strikes, through `PassiveMoments.skill(user, tags, true)`). Nothing existing changes meaning; a game's data needs no change.
- 0.96.0 — C9.5a, the defences that need no power. New `HitGuard` (`stops`, `soak`, `hurt`, `pass_time`); fields `StatusEffect.invincible` and `pierced_by`; stats `mercy_time`, `max_overshield`, `overshield_regen`, `overshield_delay`, `healing_taken` (`Vitals.HEALING_STAT`); `Combatant.mercy_left`, `shield_wait`, `shield_carry`. `combatant_damaged` tells the whole hit, the overshield's share counted. A game need change nothing: a fighter with none of the stats plays as before.
- 0.95.0 — C9.4, the passive loadout. New `PassiveLoadout` (learned, chosen, budget, refusals, `practise`) and `PassiveLesson`; fields `GearDefinition.teaches`, `CombatantDef.passive_budget` and `passive_budget_per_level`, `Rewards.learned`; flags `passive_known/`, `passive_progress/`, `passive_slot/`; source `loadout`. `PassiveLending.give` is public. A game need change nothing: a fighter with no budget chooses none.
- 0.94.0 — C9.3b, the sample passive library. 22 `PassiveSkill` files in `data/passives/`, one per catalogue family; statuses `battle_fury` and `desperation`; CSV rows `combat.passive.<name>.name` and `.desc`. `tools/check_content.gd` fails a broken passive or a missing key. New `tests/unit/passive_library_test.gd` holds the whole library on one fighter. No code under `src/` changed.
- 0.93.0 — C9.3a, passives on kits and gear. New `PassiveLending` (gameplay) gives each source's `PassiveSkill` list to the fighter's `PassiveSet` under its own name: `own`, `kit/<source>`, `gear/<item id>`, `set/<set id>/<pieces>`, `gems`, `upgrades`. New fields: `PowerKit.passive_skills`, and `passives` on `GearDefinition`, `GearSetTier`, `GemDefinition` and `UpgradeLevel`. `PassiveSet.fit` became `PassiveLending.own`; a fighter with no passive of its own gets a set the first time a kit or a piece gives one. A game that called `PassiveSet.fit` renames the call; nothing else to do.
- 0.92.0 — C9.2c, passive skill and form events. New `PassiveMoments` (gameplay): `SkillUse.apply` and `PowerUse.use` tell it of each use (`SKILL_USED`, once per use, `tag` filter), and `FormRun` of a form going on or off (`FORM_ENTERED`, `FORM_LEFT`; a stage change is neither). `PassiveEffect` kind `COOLDOWN_CUT` with `share`, through the new `PowerSet.cut_cooldowns`. `PassiveSet.happened`. `tests/unit/passive_moments_test.gd`.
- 0.91.0 — C9.2b, passive hit effects. New `PassiveHits` (gameplay): `Combatant.receive` shows it each hit before the barriers (`scale`) and after them (`lethal`), and keeps the hit landing in `PassiveHits.now`. `PassiveEffect` kinds SCALE_HIT, SURVIVE, EXTRA_HIT (`leave`, `skill`); `PassiveTrigger` event LETHAL_HIT and `early()`; `PassiveCondition` kinds HIT_TAG, HIT_ELEMENT. A trigger never wakes inside itself. A game needs to do nothing.
- 0.90.0 — C9.2a, passive conditions and more events. New `PassiveCondition` (content) and `PassiveConditions` (gameplay); `PassiveTrigger.conditions`, `threshold`, `tag` and the events CRIT_DEALT, DODGE, GUARD, HP_BELOW, HP_ABOVE, STATUS_GAINED; `PassiveSkill.group` and `rank`; `CombatantDef.traits` and `Combatant.traits`. Fix: a field body's passives now sleep through a turn-based battle, where its battle copy (same id, same pools) answers. A game need do nothing.
- 0.89.0 — C9.1, passives, the core. New `PassiveSkill`, `PassiveTrigger`, `PassiveEffect`, `PassiveDb` (content) and `PassiveSet`, `PassiveEffects` (gameplay); `CombatantDef.passives`. Battles, the field party and field enemies fit the set; `Battle` hands it its random numbers and its turns; `StatusSet` finds a held status again on load. A game needs to do nothing: a definition with no passives is unchanged.
- 0.88.1 — C9.0, documents only. New `docs/PASSIVES.md` (the passive library, the loadout, armour functions, the armour table's new rows, the kakujas and their armour versions) and phase C9 on the board. The owner's mechanics encyclopedia and Last Cloudia names list are in `docs/reference/`. No code changed; a consuming game needs nothing.
- `0.88.0` — C7.5, upgrading and awakening. New content `UpgradeLevel` (`items`, `stat_bonus`, `modifiers`, `sockets`, `problems()`, `cost_problems()`) and `UpgradeTrack` (`levels`, `awaken_into`, `awaken_items`); `GearDefinition.upgrade`, `max_upgrade` and `upgrade_cap()`; `Rarity.max_upgrade` is now read; `Power.requires_upgrade`. New `GearUpgrades` (gameplay): `level`, `refusal`, `upgrade`, `awaken_refusal`, `awaken`, `extra_sockets`, `unlocks`, `apply`. `PowerUse.Reason.UPGRADE` (appended) and its words `ui.battle.reason.needs_upgrade`; `GearSockets.gems` counts the levels' sockets; `GearLending` calls `GearUpgrades.apply`. A game with no tracks needs nothing.
- `0.87.0` — C7.4c, gem sockets. New content `GemDefinition` (`item_id`, `modifiers`, `element`, `problems()`) and `GemDb` (`data/gems/`, `for_item`, `problems`, `rescan`); `GearDefinition.sockets` and `socket_count()` (its rarity's `sockets` add). New `GearSockets` (gameplay): `gems`, `socket_refusal`, `socket`, `removal_refusal`, `unsocket`, `remover_id`, `element_of`, `apply`; the project setting `combat/gear/gem_remover`. `GearLending` lends a gem's element and calls `GearSockets.apply`; `GearSet` re-lends after every bag change. A game with no gems needs nothing.
- `0.86.0` — C7.4b, gear sets. New content `GearSetBonus` (`set_id`, `tiers`, `has_kit()`, `problems()`) and `GearSetTier` (`pieces`, `modifiers`, `kit`); `GearDefinition.set_bonus` and `lends_kit()`, the set checked with the piece; `GearDb.set_ids()`. New `GearSetBonuses.apply`, called by `GearLending.lend`: it takes every set's stat changes off, counts the worn pieces per `set_id`, and gives each reached tier's stat changes (source `set/<set id>`) and kit (`set/<set id>/<pieces>`, lent through `PowerSet.lend` with the pieces' kits). Starting pieces whose set lends a kit get a `PowerSet` as the body is built.
- `0.85.0` — C7.4a, who may wear what. `GearDefinition.needs_level`, `needs_stats` (`Dictionary[StringName, float]`) and `cursed`, with `problems()` flagging a level below zero and an unnamed stat. `GearSet.refusal(item_id, into)` adds `LEVEL_TOO_LOW` (`Party.level_of`), `STATS_TOO_LOW` (the wearer's sheet) and `CURSED` (a cursed piece would have to come off for this one: the one in the slot asked for, one in a slot it blocks, or one blocking that slot). `take_off(item_id, force)` leaves a cursed piece on unless forced; a cursed piece may still move between its own slots, and losing the item takes it off. A starting piece skips the level and stat checks. `GearLending.lend` now writes what the worn pieces lend (moved out of `GearSet`, which was at its budget).
- `0.84.0` — C7.3b, a weapon's own swing chain. `GearType.moves` and `GearDefinition.moves` (`MoveSet`), with `GearDefinition.strike_moves()` (its own, else its type's) and both checked by `problems()`. `GearSet` writes the first worn piece's moves, in the slot list's order, into `Combatant.lent_moves`; `Combatant.field_moves(own)` builds the set played: the weapon's chain, its dodge or the fighter's own, and the fighter's own skills, kept until either side changes. `ActionFighter.current_moves` and `PartyFollower` hand it to `PowerSet.moves_over`, so a form's moves still go on top.
- `0.83.0` — C6.9g, the log and HUD. Three signals on `Events`: `battlefield_raised(who, power_id)` once a battlefield stands, `battlefield_lowered(who, power_id, broken)` as it comes down (`broken` when a hit, a lost clash or its caster's fall shattered it), and `battlefield_clashed(who, rival)` once per rival a rising battlefield clashes with. `BattleLog` writes "raises", "raises …: place", "fades", "shatters" and "clashes" lines; `CombatHud.field_text` shows each battlefield standing in the player's fight, with its place. `BattlefieldNews` (gameplay) finds a battlefield and its name keys for the readouts. `_effects_for` moved to `BattlefieldGroups` to keep `battlefield_run.gd` in its budget.
- `0.82.0` — C6.9f, the place. `PlaceLook` (content: `id`, `name_key`, `tint`) and four fields on `BattlefieldMechanism`: `place`, `moves_fight`, `has_weather`, `weather`. `BattlefieldStage` (gameplay) keeps the place look while the field stands, forces the weather and puts the old one back unless someone changed it meanwhile, and for `moves_fight` queues each fighter let in and, once the refresh is done, shifts the whole group (caster too) to a far pocket by one vector, so it keeps its shape; reach no longer matters for those, and the rest of the fight is out of reach. They go back where they stood on leaving or at the lower. In the field only: a battle has no distances. The pull and push moved to `BattlefieldWall.drift` to keep `battlefield_run.gd` in its budget; the wall, the pull and the push leave pocketed fighters alone.
- `0.81.0` — C6.9e, the first slice (the board split the row: this is the caster's kit; the place is C6.9f, the log and HUD C6.9g, `summons` C8.10). `caster_kit` on `BattlefieldMechanism`: a kit the caster holds only while the battlefield stands. `BattlefieldRun` holds it on at the raise and releases it at the lower, however the field ends; a clash loss never raises it. `PowerSet.hold_kit` and `release_kit` (under `field_kit/<power>`) put it on and take it off, and `kits()` lists it, so its powers show in menus. The gauge handlers moved to `PowerGaugeFeed` to keep `power_set.gd` within its budget.
- `0.80.0` — C6.9d. Clashes and `closed`: `layer`, `refinement`, `refinement_stat`, `clash` and `closed` on `BattlefieldMechanism`; `BattlefieldClash` (whether two overlapping battlefields in one layer and clock clash, and the four rules, judged by the newcomer when it rises); `BattlefieldWall` (a closed field holds fighters at its edge, a tick behind a shove); `BattlefieldRun` asks `allows` before a raise and keeps those inside in a closed field. In a battle `closed` changes nothing yet: there is no edge until summons (C6.9e).
- `0.79.0` — C6.9c. Battlefields against each other, the hit side: `sure_hit`, `hit_tags`, `broken_by_tags` and `cancelled_by` on `BattlefieldMechanism`; `StatusEffect.grants_sure_hit`, `grants_hit_tags` and `cancelled_by`; `HitFlags` (the attacker's granted flags, read by `Combatant.hit`); `BattlefieldRun.breaks` on each landed hit. Clashes and `closed` move to C6.9d.
- `0.78.0` — C6.9b. Battlefield damage and movement: `BattlefieldEffect.on_enter`,
  `on_exit`, `tick` with `tick_seconds`, `tick_turns` and `tick_grows`, `pull`, `push` and
  `immune_tags`; the stat `resist_field_<name>`; `SkillUse.apply`'s `strength`.
- `0.77.0` — C6.9a. The battlefield core: `BattlefieldMechanism`, `BattlefieldEffect`,
  `BattlefieldRun`, and the `damage_dealt` stat in `VulnerabilityStage`.
- `0.76.0` — C6.8. The finisher: `FinisherMechanism`, `FinisherRun` and the `Flourish`
  node.
- `0.75.0` — C6.26. The plant: `PlantMechanism`, `PlantRun`, the `Planted` node,
  `Projectile.landed`, the `projectile_landed` executor hook and `BarrageRun.strike_with`.
- `0.74.0` — C6.7. The barrage: `BarrageMechanism`, `BarrageRun`, the `Projectile` node,
  `PowerMechanism.aims_at_foes` and its branch in `Battle.targets_for`.
- `0.73.0` — C6.6d. The counter stance: `StatusEffect.counter_move`,
  `SkillUse.counter_stance` and `answer`, the counter in `Hurtbox.take`, the player facing whom it
  counters.
- `0.72.0` — C6.6c. Perfect dodge and no flinch: `ActionMove.perfect_window`,
  `MoveTimeline.perfectly`, `Events.perfect_dodge`, `GaugeRule.on_perfect_dodge`, and the
  `knockback_taken` stat scaling a push in `Hurtbox`.
- `0.71.0` — C6.5f. Once per battle: `Power.once_per_battle`, `OnceLedger` (`PowerSet.once`,
  wiped on `area_entered`), `PowerUse.Reason.ONCE` and its menu words `ui.battle.reason.once`.
- `0.70.0` — C6.5e. A form's own commands: `FormMechanism.commands`, `replaces_attack` and
  `aftermath` (with `commands_at`/`attack_at`), `FormRun.held_in`/`commands_of`/`attack_of`,
  `PowerMenu.with_powers` offering a form's menu, `Battle`'s Attack becoming the form's skill, and
  `StatusSet.running_out`.
- `0.69.0` — C6.5d. Transformations you can see: `LookDef` (tint, scale, a tag), a form's
  `look` and `name_key` with the cycle fallback (`look_at`, `name_at`), `LookSwap` on every field
  body, `FormRun.held`, and the form's name on the battle screen (`ui.battle.form_title`) and the
  HUD.
- `0.68.0` — C7.3. Special gear: a piece's `kit` lends the wearer hero powers while worn.
  `PowerSet` holds several kits at once (`lend`, `kits`, `powers`, `status`), the fighter's own
  first, then gear's in slot order; `Power.requires_gear` (a piece or a kind of piece) with the
  `GEAR` refusal and its menu words; a piece's own pool through a `max_<pool>` modifier. The
  incoming-hit hook moved to `PowerGuard.incoming`.
- `0.67.0` — C7.2. Rarity and drops: `Rarity` and `RarityDb` (`data/rarities/`),
  `GearDefinition.rarity` (the tier's `stat_scale` multiplies the piece's stat changes),
  `LootTable`, `LootEntry` and `LootRoll` (weights, count ranges, a flag condition, a
  "nothing" line, a rarity's `drop_weight`), `Encounter.loot_table` and
  `CombatantDef.loot_table`, rolled in `Rewards.grant` and by a falling `ActionEnemy`.
- `0.66.1` — C6.0c. The power atlas, docs and data only: the owner's powers pack and full
  weapons list under `docs/reference/originals/`, `power_atlas.csv` (3,306 powers),
  `power_handlers.csv` (116 families), every character profile, and `POWER_ATLAS.md`, which
  sorts each family onto a mechanism and adds rows C8.10–C8.15.
- `0.66.0` — C7.1c. The worn weapon on attacks: `element`, `attack_tags` and `blocks` on
  `GearType` and `GearDefinition`; `GearSet` lends the element and tags to its `Combatant`
  (`strike_element`, `strike_tags`), read by `Battle`'s ATTACK and by `Hurtbox`; a piece that
  blocks a slot empties it, and a piece put there takes the blocker off.
- `0.65.0` — C7.1b. Gear in a fight: `CombatantDef.gear` (starting pieces), `GearSet.fit` used
  by `BattleSetup`, `ActionHost` and `ActionEnemy`, the worn set carried on a party switch, a
  foe's gear kept out of saves, and the `[combat] gear/rules` setting.
- `0.64.0` — C7.1a. Gear as data, worn: `GearType`, `GearRules`, `GearDefinition`, `GearDb` and
  `GearSet` (wear, take off, one piece per slot, modifiers by source, saved in `Flags`, off when
  the item is lost). `docs/reference/weapon_ideas.csv`, the owner's weapon idea list, and the
  mechanism catalogue in `GEAR.md`. A consuming game does: nothing.
- `0.63.1` — C7.0. Documents only: `docs/GEAR.md`, the design for gear, battlefields, the
  planted strike and transformations, with a survey of combat mechanics. A game does: nothing.
  - Board: C7 is rows C7.1 to C7.10; C6.9 is four rows; new rows C6.5d, C6.26 and C8.1 to C8.9.
- `0.63.0` — C6.6b. The timed block, and `Events.attack_blocked`.
  - `BarrierMechanism.Mode.TIMED_BLOCK` with `timing` (a `TimedWindow`, which gains `inside`):
    a hit just after the guard goes up is stopped whole, free, and stored in `store_pool`; a
    later one pays `cost_per_block` and leaves `factor`.
  - A hit stopped whole emits `attack_blocked` and no longer `combatant_damaged` with 0; the
    battle log says "{name} blocks the attack." A game listening for 0-damage hits listens to
    the new signal. Otherwise a game does: nothing.
  - Board: C6.6 is now four rows (C6.6c perfect dodge and no flinch, C6.6d counter stance); new
    phase C7, gear, rows C7.0 to C7.6.
- `0.62.0` — C6.6a. The barrier (M3), and the guard hook in `Combatant.receive`.
  - `BarrierMechanism` (a `FormMechanism`) and `BarrierRun`; `PowerSet.guard` and the executor
    hook `intercept_incoming`; `DamageResult.tags` and `blocked`; `Combatant.hit` takes `tags`.
- `0.61.0` — C6.5c. A form's own quick slots, and forms survive a save.
  - `PowerMechanism.statuses()` (a form lists its own) and `PowerKit.status(id)`.
  - `PowerSet.passive_of` now finds a form's status too, so `StatusSet` loads it. Before this, a
    form held at save time was dropped on load.
  - `PowerSlots.powers` skips a power whose `requires_statuses` names a status the kit grants
    and the fighter does not hold.
  - New test `power_form_slots_test.gd`.
  - The fork's test list moved out of upstream's `tests/test_runner.gd` (251 of its 250 lines)
    into `tests/combat_cases.gd`; the runner runs upstream's cases, then these.
- `0.60.0` — C6.5b. A form plays its own moves.
  - Executor hooks `moves(base)` and `moved(move)`; `PowerSet.moves_over(base)`, in kit order,
    and `PowerSet.moved` now tells every running mechanism.
  - `FormMechanism.drain_per_action` and `moves_of(stage)`; `FormRun.moves` keeps the set it
    builds, so nothing is made each frame.
  - `ActionFighter.current_moves()`; a dodge is known by its swing, not by its move, so a form
    entered or left mid-roll cannot turn a roll into a lunge. `PartyFollower` swings the form's
    chain when its brain opens the member's own.
  - New test `power_form_moves_test.gd`.
- `0.59.0` — C6.5a. Forms: the first built-in mechanism.
  - `FormMechanism` (status, `exclusive_group`, `cycle`, `advance_after`, drains) and its
    executor `FormRun`, registered in `PowerMechanisms.BUILT_IN` as `form`.
  - Executor hook `power_used`, fed by `PowerSet.used` from `PowerUse.use`; `PowerSet.running()`.
  - New test `power_form_test.gd`.
- `0.58.0` — C6.4b. The other gauge events.
  - `GaugeRule` gains `on_kill`, `on_ally_defeated`, `on_new_move`, `per_running_second` (on top
    of `per_moving_second`), `spent_pool` and `on_spent`.
  - `PowerSet.moved` (from `ActionFighter`) and `PowerSet.spent` (from `SkillUse.pay`).
  - Every `Combatant` joins `Combatant.GROUP`; new `Combatant.find(tree, id)`.
- `0.57.0` — C6.4a. Kit gauges fill and drain.
  - New `GaugeRule` (content) and `PowerKit.gauges`; new `KitGauges`, run by `PowerSet`.
  - A rule's amounts: `per_second`, `per_turn`, `per_idle_second`, `per_moving_second`,
    `on_hit_dealt`, `on_hit_taken`, `on_dodge`, `on_miss`; `blocked_by_tags` pauses it; `levels`
    hold a status per threshold, whatever moved the pool. A `regen_<pool>` stat fills a gauge
    pool by the second in the field.
  - A consuming game does: nothing. Kits without `gauges` behave as before.
- `0.56.1` — C6.0b. Two more characters, documents only.
  - `POWERS.md` gains Isliid (Grand Summoners: Emperor, Defier of Fate and Human Pinnacle forms,
    three swords) and Roland (The Last Cloudia: base, Ascended and Heroic Lord forms), a
    fourteenth mechanism M14 `refresh`, and four seams placed in rows C6.4, C6.5, C6.6 and C6.25.
  - Board: new kit rows C6.24 (Isliid) and C6.25 (Roland); C6.4, C6.5, C6.6 and C6.12 widened.
- `0.56.0` — C6.3b. The HUD's slot line.
  - New `Events.power_cooldown_changed(who, power_id, left)`, emitted by `PowerSet` after a
    cooldown starts, ticks past a whole second or turn, ends, or goes with its kit.
  - `CombatHud` gains a slot line (`slot_text`): each slot's key, power, cost or refusal reason,
    redrawn by that signal; new key `ui.combat_hud.slot`. `CommandOverlay` redraws when a power
    comes off cooldown, closing C6.2c's stale-row gap. `power_hud_test` (14).
- `0.55.0` — C6.3a. Quick slots.
  - Four rebindable actions `combat_power_1` to `_4` on keys 1 to 4 (no pad default: every pad
    button is taken), labelled `ui.action.combat_power_N`.
  - New `PowerSlots` (gameplay): slot N is the kit's Nth non-passive power; `press` uses it
    through `FieldCommands` (no ATB). `ActionFighter.press_slot` reads the keys, refused while
    knocked back, staggered, fallen or held by a menu. `power_slots_test` (11).
- `0.54.0` — C6.2c. Hero powers in the menus.
  - New `PowerMenu` (ui): a kit's powers as one Powers category, and each `PowerUse.Reason` as
    words. `BattleMenu.refusal` asks it for a POWER; `CommandOverlay` maps `Reason.POWER`
    through it and shows no ATB bars on a power; `CommandHost` opens for a kit with no loadout
    commands; both screens show `SkillUse.cost_of`. Seven new `ui.battle.*` rows. A game does:
    nothing.
- `0.53.0` — C6.2b. Hero powers in the field.
  - `ActionHost.fit_identity` gives the player and each follower a `PowerSet` wearing the
    fighter's `power_kit`; `FieldParty` moves it on a switch; `FieldCommands` routes a POWER
    through `PowerUse` (new `Reason.POWER`, no ATB cost); `PowerSet.passive_of` lets a load find
    a kit passive; executors end only when freed. A game does: nothing.
- `0.52.0` — C6.2a. Hero powers in a turn-based battle.
  - `CombatantDef.power_kit`; `BattleCommand.Kind.POWER` (appended, so saved menus keep their
    kinds), `BattleCommand.power` and `for_power`; `BattleSetup` equips the kit; `Battle` aims,
    refuses and acts a POWER through `PowerUse`, and counts cooldowns at the start of the
    holder's turns. A game does: nothing; give a fighter a `power_kit` to use it.
- `0.51.0` — C6.1b. Hero powers: equip a kit, and use a power.
  - New `PowerSet`, `PowerUse`, `PowerMechanisms` and `PowerExecutor` under
    `src/gameplay/combat/powers/`. Nothing in the running game equips a kit yet (C6.2). A game
    does: nothing; a game with its own mechanism calls `PowerMechanisms.register(kind, script)`.
- `0.50.0` — C6.1a. Hero powers: the data shapes, and cheaper costs.
  - New `PowerKit`, `Power`, `PowerScaling` and `PowerMechanism` under
    `src/content/combat/powers/`; `SkillUse.cost_of` applies a `cost_mult_<pool>` stat to every
    skill's cost. A game does: nothing (no stat, no change).
- `0.49.1` — C6.0. Hero powers: research and design, documents only.
  - New `docs/POWERS.md`: nine characters' powers, the framework, thirteen shared mechanisms,
    and a kit per character. Board rows C6.1–C6.23. A game does: nothing.
- `0.49.0` — C5.3a. The combat controls can be rebound.
  - Merged upstream `5.18.0` (T7.3, `Actions.add_rebindable`) and `5.18.1` (its test counts a
    game's added actions; found here).
  - `CombatActions.install` adds its six actions through `Actions.add_rebindable`, so Options ->
    Controls lists attack, dodge, lock on, next foe, commands and switch member; a rebind is saved,
    a reset puts the default back, and a saved key wins at boot.
  - Six `ui.action.combat_*` label rows in `strings.csv`.
- `0.48.0` — C5.2. Saves around combat.
  - Merged upstream `5.17.0` (T7.2, `SaveSystem.blockers`), the combat-neutral seam this row
    asked for first.
  - New `CombatSaveGuard` (`src/gameplay/combat/combat_save_guard.gd`, under GameRoot): a save is
    refused, with a reason the save screen shows, during a turn-based battle and while the player
    lies defeated. The autosave skips quietly at those moments. Loading is never refused.
  - New `Weakness.built_in(id)`: `StatusSet` finds the code-built broken, pressured and
    staggered statuses on load, so a stagger survives a save instead of being dropped.
  - `FieldDefeat` stands a fallen fighter up on every area entry unless they are still lying out
    their rule's delay, which also rescues a save written at 0 hp by an older build.
  - **A consuming game must:** nothing. Two new `ui.combat_save.*` rows in `strings.csv`.
- `0.47.0` — C5.1. Mixed formulas: symbol encounters.
  - New `SymbolEncounter` node (`src/gameplay/combat/symbol_encounter.gd`). A child of an
    `ActionEnemy`, it asks for its turn-based `encounter_id` when the party touches it
    (`touch_radius`) or a party strike lands on it. A win fells the field body; a flee, a loss
    or an unanswered request leaves it quiet for `grace` seconds of fight time.
  - New `ActionBrain.chase_only`: an empty `moves` is then meant, not a problem.
  - Demo: a thorn wisp symbol in the courtyard, beside the talk-to wisp nest.
  - **A consuming game must:** nothing. A brain with no moves is still reported unless it sets
    `chase_only`.
- `0.46.0` — C4.11. The hybrid demo; closes C4. Data only, no code change.
  - The demo Keeper has a `brain` (Salve when below 60% hp, aimed at the most hurt; Bulwark)
    and a `field_brain` (its staff chain).
  - A new foe in the lantern hall, the Lantern Warden: 90 hp, 4 shield, weak to fire, a slow
    heavy slam. Ember pressures it; blows then stagger it.
  - The hall gains an invisible south edge, so a knocked-back foe cannot slide off the open
    floor.
  - **A consuming game must:** nothing; it is demo content.
- `0.45.0` — C4.10. Variants with no new system.
  - New `CtbScheduler.advance(ticks)`: feeds the CTB queue with time, which is a classic
    ATB battle. `next()` alone is still plain CTB.
  - New `TimedWindow` (systems, pure): a press inside the window multiplies a hit's power.
  - **A game must:** nothing. Both are opt-in.
- `0.44.0` — C4.9. Allies fight in the field.
  - New `ActionLoadout.field_brain` (an `ActionBrain`): a follower with one chases, swings and
    keeps a leash on its place in the line, driven by the enemies' `ActionDecider`. A brain move
    that opens the member's attack chain plays the whole chain.
  - New `Hurtbox.nearest_hostile(body)`, shared by enemies and followers.
  - A follower now reels from a knockback and has its own `Hitbox`.
  - **A game must:** nothing. A loadout with no `field_brain` behaves as before.
- `0.43.0` — C4.8. Allies think in real time.
  - New `BrainContext`, with `BattleBrainContext` (a `Battle`) and `FieldBrainContext` (the
    field, through `FieldCommands`). `BattleAi.decide(context, brain)` reads one brain against
    either; `take_turn` is unchanged for callers.
  - A `PartyFollower` uses its member's `CombatantDef.brain` every `think_every` seconds (1) of
    fight time while a foe is within reach: it spends ATB and mp on the skills and items it can
    pay for, aimed by the entry's rule (LOWEST_HP heals the most hurt ally).
  - `FieldCommands.candidates`, and `use` takes an optional aim among them.
  - A consuming game: nothing to do; give a companion's fighter a `brain` to have it act.
- `0.42.0` — C4.7. A party in the field.
  - `ActionLoadout.companions`: the loadouts of the members who walk with the lead. Those in
    `Party`'s active line-up spawn as `PartyFollower`s (`scenes/objects/party_follower.tscn`)
    and walk in a line behind the player.
  - The new `combat_switch` action (C, pad `PADDLE1`) hands the player's body to the next
    standing member: hp, statuses, the gauge, moves and commands go with the member, and the two
    bodies swap places (`FieldParty.switch`).
  - A field kill teaches every standing member. The command menu offers the controlled member's
    commands. `StatusSet` now registers its save on entering the tree.
  - Demo: the Keeper (`data/action/keeper_loadout.tres`) follows the Wanderer.
  - A consuming game: nothing to do; list companions on your loadout to bring a party.
- `0.41.0` — C4.6. Pressure and stagger.
  - A fighter in the field (`Combatant.real_time`, set by `ActionHost` and `ActionEnemy`) is
    PRESSURED by a weakness hit (double poise for 3 s) and STAGGERED by an empty shield (4 s
    still, +60% damage taken), then its shield refills. A battle still uses BROKEN.
  - Fixes field breaks: they applied the turn-counted BROKEN, which nothing in the field counted
    down, so a broken moth stayed broken, unshielded and +50% for good.
  - New `StatusSet.halts()`; the HUD target line lists the target's statuses.
  - A consuming game: nothing to do; to restyle, set `Weakness.pressured` or `staggered`.
- `0.40.0` — C4.5. The field-command demo.
  - The Wanderer's loadout gains ATB rules (two bars) and two field commands: Ember under Magic,
    Salve on the first menu. F now works in the demo.
  - `combat_content_test` reads a loadout's commands. `AUTHORING.md` § The hybrid.
  - A consuming game: nothing to do; its own loadout is untouched.
- `0.39.0` — C4.4. The command overlay: the screen.
  - New `CommandOverlay` (ui): a menu over the running field, in the battle menu's categories,
    with ATB and mp costs and greyed rows with the reason. Choosing calls `FieldCommands.use`.
    While it is open the fight runs at `[combat] hybrid/slow` (0.1).
  - New `CommandHost` under UILayer, and the `combat_command` action (F, pad `MISC1`).
  - The HUD shows ATB bars.
- `0.38.0` — C4.3. Field commands: the logic.
  - New `FieldCommands` (gameplay, static): `targets`, `refusal` (a `Reason`) and `use`. It
    spends ATB bars, then the cost or the item, then resolves through `SkillUse.apply`.
  - `Skill.atb_cost` (1 by default) and `ActionLoadout.commands`.
  - **A consuming game:** nothing to do. Existing skills cost one bar in the field.
- `0.37.0` — C4.2. The ATB gauge.
  - New `AtbRules` (content): bars, bar size, and points per second, per hit landed and per
    dodge. New `AtbGauge` (systems, pure): fill, gain, whole bars, spend.
  - New `AtbMeter` (gameplay), fitted by `ActionHost.equip` when `ActionLoadout.atb` is set. It
    fills on fight time and on `combatant_damaged` and `attack_dodged`, and emits the new
    `Events.atb_changed`.
  - **A consuming game:** nothing to do. A loadout without `atb` has no gauge.
- `0.36.0` — C4.1. `CombatClock`, the fight's own time scale.
  - `CombatClock.scale` (static; `set_scale`, `scaled`, `reset`) multiplies the frame time of
    `ActionFighter` and `ActionEnemy`, their statuses, their moves and their walking. 0 stops
    the fight; the day clock, the weather, the UI and the player's own walking carry on.
  - `ActionHost` resets it to 1 on every `area_entered`.
  - **A consuming game:** nothing to do. Whatever slows the fight must put it back.
- `0.35.0` — C3.10. The action demo, which closes C3.
  - A loadout for the Wanderer (`data/action/wanderer_loadout.tres`) is named by
    `[combat] action/loadout`, so the demo player fights in the field.
  - Two Ember Moths stand in `lantern_hall` and use the alternate placeholder sprite.
  - `ActionHost.configured()` treats a loadout path whose file is gone as "no field combat",
    logged at info. A game that deleted the demo keeps a clean boot.
  - `combat_content_test.gd` checks `data/action/`. `AUTHORING.md` § Action combat.
  - **A consuming game:** set `[combat] action/loadout` to your own loadout, or to `""`.
- `0.34.0` — C3.9. The field HUD.
  - New `CombatHud` (a Label under `UILayer` in `game_root.tscn`): the player's pools and
    statuses, and the locked target's name and hp, redrawn by events, hidden with no fighter.
  - New strings `ui.combat_hud.hp` and `ui.combat_hud.target`.
- `0.33.0` — C3.8. Defeat, rewards and respawn.
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
| C3.9 | Field HUD | **DONE**, combat `0.34.0`. New `src/ui/combat/combat_hud.gd` (`CombatHud`, a Label), added to `scenes/boot/game_root.tscn` under UILayer after HudClock (ext_resource `42_hud`, `load_steps` 25), drawn at the bottom left in the `HudText` theme role. `refresh()` shows nothing unless `subject` (default `Director.player`) has a `Combatant`; then line one is hp, every other `max_*` pool and the held statuses (reusing `ui.battle.pool` and `ui.battle.statuses`), and line two, while `target_id` is set, the locked target's name (the enemy definition's `name_key`, else its kind) and hp. It redraws on `vitals_changed`, `status_applied`, `status_expired`, `lock_on_changed`, `player_spawned` (deferred, because the fitting is) and `player_despawned`, and never polls. New strings `ui.combat_hud.hp` and `ui.combat_hud.target`. `combat_hud_test.gd` (8). Red first: with the drawing stubbed, 5 failed. **A windowed capture of the running game** (a temporary loadout, an enemy 3 m ahead, a real lock-on press) shows `HP 26 / 30   MP 12 / 12   [probe_poison]` over `probe_wisp   HP 13 / 20`. **Changes from the plan:** no skill-slot cooldowns, because none exist yet: skills on a button arrive with the hybrid's menu (C4.3), and the HUD grows a line then |
| C3.10 | Demo proof: an action fight | **DONE**, combat `0.35.0`. **Closes C3.** New demo data in `data/action/`: `wanderer_loadout.tres` (the Wanderer, hp 46, a three-swing blade chain of power 4, 5 and 7 whose finisher knocks back and wears 1 poise, and a roll with 0.3 s of i-frames and travel 6), `ember_moth.tres` (hp 40, attack 4, defence 2, shield 3, weak to blade) and `ember_moth_brain.tres` (aggro 5, one lunge of power 3). `[combat] action/loadout` names the loadout. Two `action_enemy.tscn` instances, `EmberMothA` and `EmberMothB`, under `lantern_hall`'s `Actors` (12 experience each; A drops a stone chip). The prefab now uses `character_alt.png`, so enemies stand apart from the player. `ActionHost.configured()` returns null at info level when the named file is gone, so the stripped template boots with 0 errors; a file that exists and is not a loadout is still an error. New string `combat.enemy.ember_moth.name`. `combat_content_test.gd` walks `data/action/` (problems and name keys); `action_fighter_test.gd` +1 (the missing-file case) and now sets the setting itself. Red first: with the moth's string missing, the content test failed, and the fighter test failed on the now-configured loadout. **A real-game probe** (the courtyard, the hall door, a real lock-on, attack and dodge presses) logged: lock on the first moth, a lunge dodged, the chain landing 13–18 a swing, both moths defeated with their rewards, and the player at full hp. **Windowed captures** of the dodge, a swing and the fight show the HUD's `Ember Moth   HP 7 / 40`. The stripped run (data and areas deleted, CSV pruned as CI does) boots clean, passes the suite and all seven checkers. `AUTHORING.md` § Action combat. **Tuning on the way:** the moth's first lunge (power 4, hp 30) took 7 a hit off a 46-hp player and died in two swings; power 3 and hp 40 make it three or four swings and 6 a hit. |
| C4.1 | `CombatClock` | **DONE**, combat `0.36.0`. New `src/systems/combat/combat_clock.gd`: a static `scale` (1 normal, 0 stopped), `set_scale` (never below 0), `scaled(delta)` and `reset()`. No autoload, so no ADR. `ActionFighter.drive` and `ActionEnemy.act` run on `scaled(delta)` (statuses, hit-stun, the decider, the linger clock and the move timeline), and the velocity each sets (a roll, a push, a walk) is multiplied by the scale. Gravity, the player's ordinary walking and `FieldDefeat`'s wait on the ground stay on real time, on purpose: at 0 a fallen player would otherwise lie there forever. `ActionHost` resets the scale on every `area_entered`, a safety net for a menu freed mid-slow. `combat_clock_test.gd` (15). Red first: with `scaled` ignoring the scale, 5 failed. **A real-game probe** froze the lantern-hall fight for 400 frames: the moth did not move and nobody was hit. At 1 again the moths closed in and struck. |
| C4.2 | ATB gauge | **DONE**, combat `0.37.0`. New `src/content/combat/atb_rules.gd` (`segments` 2, `segment_size` 100, `per_second` 4, `on_hit_dealt` 12, `on_dodge` 10, and `problems()`), `src/systems/combat/atb_gauge.gd` (pure: `fill(seconds)`, `gain(points)` capped from 0 to `capacity()`, `full_segments()`, `can_spend`, and `spend(bars)`, which keeps the part-filled bar, plus `fraction()`) and `src/gameplay/combat/atb_meter.gd` (a child of the fighter's body. It fills on `CombatClock` time and gains on `combatant_damaged` with itself as `by` and on `attack_dodged` with itself as `who`, but not while defeated. It emits the new `Events.atb_changed(who, value, segments)` only when a whole point or bar changes, and `spend(bars)` is for C4.3). `ActionLoadout.atb` (null means no gauge), and `ActionHost.equip` fits the meter. `atb_test.gd` (20). Red first: with `gain` stubbed, 14 failed. **A real-game probe** gave the Wanderer default rules in the lantern hall: about 4 a second, +10 for a dodged lunge, +12 for each of four hits, 81 points in six seconds. **Changes from the plan:** the HUD line and the demo loadout's rules move to C4.3, with the menu that spends the bars. There is no guard fill, because no guard move exists yet. One swing that hits two enemies counts as two hits. |
| C4.3 | Field commands: the logic | **DONE**, combat `0.38.0`. **The old C4.3 row, the command overlay, was split three ways along the layers** (logic, screen, demo), because it came to about 14 files, and the rows after it moved down by two. New `src/gameplay/combat/field_commands.gd` (`FieldCommands`, static). `targets(user, command)`: ONE goes to the locked foe, else the nearest in `REACH` (8 m); ALL goes to every one in reach, nearest first; SELF or ALLY goes to the user. A reviving skill aims only at the fallen. `refusal(user, command) -> Reason` checks, in order, the status blocks (NO_SKILLS or NO_ITEMS), the ATB bars (`AtbMeter`), the item in the bag or the mp, and a target (NONE, ATB, BLOCKED, COST, ITEM, TARGET). `use` spends the bars, pays the cost or takes the item, and calls `SkillUse.apply`. `Skill.atb_cost` (default 1, a negative is a problem). `ActionLoadout.commands`: each command's problems, and any kind but SKILL or ITEM is one. `field_commands_test.gd` (15). Red first: with `use` stubbed, 3 failed. **A real-game probe** gave the Wanderer ATB and Ember in the lantern hall, locked on, filled a bar and used it: Ember (all foes) hit both moths for 23 and 15, mp went 12 to 9, and the bar was spent, then refilled by 24 from the two landed hits. **Changes from the plan:** `refusal` returns a `Reason` enum, not a localization key. `BattleMenu` is `ui`, which gameplay may not name (`check_layers` caught it), so C4.4's menu turns a reason into words. Also fixed: `AUTHORING.md` named the wrong combat keys (L and `;`); the bindings are K, Space, Q and R. |
| C4.4 | Command overlay: the screen | **DONE**, combat `0.39.0`. The `combat_command` action on F and on the pad's `JOY_BUTTON_MISC1` (every standard pad button is someone's already; `combat_input_test` checks it clashes with nothing). New `src/ui/combat/command_overlay.gd` (`CommandOverlay`, a `MenuScreen` with `pauses_world=false` and `closes_on_cancel=true`): the top line is the ATB readout, then `BattleMenu.top_level` over the loadout's commands, a category opening its submenu with Back. Each row shows `{bars} ATB` and the mp cost, and a refused row is disabled with the reason: `reason_key` maps each `FieldCommands.Reason` to the battle menu's words, plus the new `ui.field_command.reason.atb`. Choosing calls `FieldCommands.use` and asks to close. It redraws when the bar count changes. `_opened` sets `CombatClock` to `[combat] hybrid/slow` (new, 0.1) and `_closed` resets it. New `src/ui/combat/command_host.gd` (`CommandHost`, under UILayer in `game_root.tscn`): the key opens the menu for a standing fighter with an `AtbMeter` and loadout commands when no screen is open, and closes it on a second press. `CombatHud` gains `ATB {bars} / {max}  {part}%` (`CombatHud.atb_text`, also the menu's top line), redrawn on `atb_changed`. `command_overlay_test.gd` (12), plus 2 input and 1 HUD assertions. Red first: with the clock slow and the use stubbed, 2 failed. **A real-game probe and a windowed capture** in the lantern hall, with a temporary Ember (Magic) and Salve on the loadout: F opened the menu, the clock read 0.1, Ember hit both moths (40 to 25 and 27), the menu closed and the clock read 1.0. **Changes from the plan:** the screen extends `MenuScreen`, which is a `UiScreen`, for its rows and focus. |
| C4.5 | Demo: field commands | **DONE**, combat `0.40.0`. `data/action/wanderer_loadout.tres` gains `atb` (default `AtbRules`, two bars of 100) and two SKILL commands: Ember (`combat.category.magic`) and Salve (first menu). `combat_content_test` walks a loadout's commands through a shared `_from_commands`. Red first: a missing category key on the loadout failed it. `AUTHORING.md` § The hybrid: ATB and field commands, and the stale line about `MoveSet.skills` fixed. **A real-game probe and windowed captures** with the shipped loadout: the gauge filled on its own, F opened the menu at clock 0.1, Magic then Ember hit both moths (40 to 24 and 25), 3 mp and one bar spent, the clock back at 1.0. The stripped run passes. |
| C4.6 | Pressure and stagger | **DONE**, combat `0.41.0`. `Combatant.real_time` (set by `ActionHost.equip` and `ActionEnemy`) makes `Weakness` choose by clock: a weakness hit applies `Weakness.pressured_status()` (SECONDS, 3 s, `poise_taken` +1, so `wear` doubles), an emptied shield applies `staggered_status()` (SECONDS, 4 s, SKIP_TURN, `damage_taken` +0.6, cures the pressure) instead of the turn-counted BROKEN, and `recover` waits on the status that suits the clock. Both field bodies call `Weakness.recover` each frame and stand still (dropping their swing) while the new `StatusSet.halts()`. The HUD target line lists statuses. **Fixes** field breaks that never ended. New `tests/unit/stagger_test.gd` (16), one more HUD assertion |
| C4.7 | A party in the field | **DONE**, combat `0.42.0`. `ActionLoadout.companions` (typed `Array[Resource]`: an array naming its own class leaked the script at exit; `problems()` reports an empty, self-naming or non-loadout entry). New `src/gameplay/combat/field_party.gd` (`FieldParty`: `members` filters by `Party.active`, `spawn` puts one `PartyFollower` per member on the leader's spot, `followers`, `lead`, and `switch`, which moves the four nodes that are a member (`Vitals`, `StatusSet`, `Combatant`, `AtbMeter`) between the two bodies, swaps their places, hands the fighter the new loadout, re-aims the hitbox, drops the lock and sends the handed-over member to the back of the line). New `src/gameplay/combat/party_follower.gd` and `scenes/objects/party_follower.tscn`: it ticks its statuses and stagger, walks to `spacing * slot` metres behind the leader (navmesh when there is one), stands still while fallen, staggered or at clock 0, and is set down on the leader's feet beyond `catch_up` (12 m, in 3D). `ActionHost.fit_identity` (split out of `equip`), followers spawned after the player is fitted, field rewards to every standing member. `ActionFighter.loadout`, and the `combat_switch` action on C and pad `PADDLE1`, read by the fighter when it is free. `CommandHost` offers the controlled member's commands. `StatusSet` registers its save in `_enter_tree`, so a moved set keeps saving. Demo: `data/action/keeper_loadout.tres` (the Keeper: a staff chain, a roll, ATB, Salve and Bulwark) as the Wanderer's companion. New `tests/unit/field_party_test.gd` (19), 2 input assertions. Red first: with `switch` stubbed, 8 failed. **A real-game probe** in the lantern hall found the follower falling through the world (it was spawned off the floor, and the flat catch-up never saw it), which became the spawn-on-the-leader and 3D catch-up fix; after it the Keeper trailed the Wanderer at about 1.5 m, C switched with the Wanderer's hp (41 of 46) staying with him, and the moths turned on the Keeper. A windowed capture shows the HUD at `HP 38 / 38  MP 14 / 14`. The stripped run passes |
| C4.8 | Allies think in real time | **DONE**, combat `0.43.0`. **The old row was split in two**: thinking (here) and moving and swinging (the new C4.9), because a follower driven by `ActionBrain` needs the chase, the hitbox and the move timeline on a second body, a package of its own; the rows after it moved down by one. New `src/gameplay/combat/brain_context.gd` (`BrainContext`: `actor`, `rng`, and `allows`, `targets_for`, `act` and `fallback`, each answering "no" in the base), `battle_brain_context.gd` (over `Battle`: its status blocks, DEFEND always, FLEE when `can_flee`, a skill when `SkillUse.affordable`; the fallback attacks the first foe or defends) and `field_brain_context.gd` (over `FieldCommands`: only SKILL and ITEM, allowed when `refusal` is NONE, no fallback, and `fighting()`, a standing foe in `REACH`). `BattleAi.decide(context, brain)` holds the weighted draw and the target rules, and an ALL skill takes every candidate; `take_turn(battle, brain)` wraps it, so `BattleScreen` and the turn-based tests are untouched. `FieldCommands.candidates` (everyone in reach the skill may aim at, nearest first; `targets` now picks from it) and `use(..., aim)`, refusing an aim outside the candidates. `PartyFollower.think()` reads the member's `CombatantDef.brain` through a `FieldBrainContext`, and `follow` calls it every `think_every` (1 s) of `CombatClock` time, never while fallen or staggered. New `tests/unit/ally_brain_test.gd` (14). Red first: with `think` stubbed, 5 failed. **A real-game probe** in the lantern hall gave the Keeper a one-entry brain (Salve, LOWEST_HP) and hurt the Wanderer to 21: about a second later the Keeper healed him to 39, spending 3 mp and one bar |
| C4.9 | Allies fight in the field | **DONE**, combat `0.44.0`. New `ActionLoadout.field_brain` (an `ActionBrain`; its problems are the loadout's). `PartyFollower` runs an `ActionDecider` on it each frame with its PLACE IN THE LINE as home, so the leash is measured from there and RETURN walks back to the leader wherever the leader went: CHASE walks in to `attack_range`, ATTACK plays the chosen move (one that is `moves.attack_chain[0]` presses the whole chain, swing after swing; any other plays alone) through the follower's own `Hitbox`, striking as whoever is the member now, RETREAT backs off, and IDLE, WANDER and RETURN keep its place. A knockback cancels the swing and pushes it (`stun_time`); a stagger or a fall drops the swing. A switch rebuilds the decider, so the lead handed back, with no field brain, only follows. `ActionEnemy.nearest_hostile` moved into `Hurtbox.nearest_hostile(body)`, shared. New `tests/unit/ally_fight_test.gd` (13). Red first: with `_fight` stubbed, 7 failed. **A real-game probe** gave the Keeper a field brain (its staff opener) in the lantern hall: it chased both moths, swung its two-hit chain, was staggered once, felled both (two field victories), then walked back into line |
| C4.10 | Variants with no new system | **DONE**, combat `0.45.0`. **ATB battle:** new `CtbScheduler.advance(ticks)` lowers every wait and names who is ready, consuming nothing; a host feeds it `CombatClock.scaled(delta) * ticks_per_second` and calls `Battle.next_turn()` when someone is ready, and the clock at 0 is wait mode. **Pause-and-play:** no code; the clock at 0 freezes a foe while a field command still lands at once. **Timed hits:** new `src/systems/combat/timed_window.gd` (`TimedWindow`: `opens`, `closes`, `bonus`, an optional `perfect` centre worth `perfect_bonus`; `multiplier(pressed_at)` and `problems`). New `tests/unit/variants_test.gd` (11). Red first: with `advance` and `multiplier` stubbed, 3 failed. No probe or capture: nothing is wired into the demo, which is C4.11 |
| C4.11 | Demo proof: a hybrid fight | **DONE**, combat `0.46.0`. **Closes C4.** Data only. The demo Keeper (`data/action/keeper_loadout.tres`) gets a `brain` (Salve below 60% hp at the most hurt, weight 4; Bulwark, weight 1) and a `field_brain` (its staff chain, aggro 5, leash 7). New `data/action/lantern_warden.tres` and `lantern_warden_brain.tres` (90 hp, shield 4, weak to fire, a 0.6 s slam), placed in the lantern hall with an invisible south edge (a knockback had pushed it off the open floor). Probe: the Keeper felled both moths, healed itself from 8 to 26 hp, and with Ember's pressure took the Warden's shield 4 → 0: STAGGERED for 4 s, then the shield refilled. Capture: the HUD reads `Lantern Warden HP 12 / 90 [Staggered]` |
| C5.1 | Mixed formulas | **DONE**, combat `0.47.0`. **Decided: no `Encounter.mode` and no `[combat] mode`**, since nothing would read them: which formula a fight uses is what the area places (an `ActionEnemy`: action, or hybrid with a loadout `atb`; an `ActionEnemy` with a `SymbolEncounter` child: turn-based on touch or on a party strike; an `EncounterPoint`: turn-based on talk). New `src/gameplay/combat/symbol_encounter.gd` (`encounter_id`, `touch_radius` 1.2, `grace` 3 s of fight time; WON drops the body to 0 hp so it falls its own way; FLED, LOST or an unanswered request give grace) and `ActionBrain.chase_only`. New `tests/unit/symbol_encounter_test.gd` (16). Red first: with `_challenge` stubbed, 9 failed. Demo: `ThornWispSymbol` in the courtyard (`data/action/thorn_wisp_symbol.tres`, `symbol_brain.tres`) opens `encounter/thorn_wisps`. Probe: the Keeper's strike opened the battle, the field stayed frozen, the win felled the wisp with 0 xp. An "ambush" (an encounter that spawns real-time foes) is left for a game that asks |
| C5.2 | Saves around combat | **DONE**, combat `0.48.0`. **Needed an upstream seam first**, the pattern C5.3 names: upstream T7.2 (`5.17.0`) added `SaveSystem.blockers`, and this row merged it down. New `src/gameplay/combat/combat_save_guard.gd` refuses a save during a battle (`ui.combat_save.in_battle`) and while the player lies defeated (`ui.combat_save.fallen`); the autosave skips. **Found while planning:** a save made while the player lay at 0 hp (from the pause menu, or the quit autosave) loaded into a soft-lock, since a load fires no defeat edge; `FieldDefeat` now stands a fallen fighter up on area entry. **Found by the test:** a stagger was dropped on load with a warning, because `Weakness` builds it in code; new `Weakness.built_in`. Pools, statuses with their seconds left, `remember_defeat` and revealed weaknesses were already saved (all through `Flags` or a status section); field enemies and ATB reset on load, as on re-entry. New `tests/unit/combat_save_test.gd` (18). Red first: 10 failed. Probe: in the courtyard battle the save returned `ERR_UNAVAILABLE` and the autosave `ERR_SKIP`; in the lantern hall the hp was back to the saved value straight after the load |
| C5.3a | Rebindable combat controls | **DONE**, combat `0.49.0`. **Upstream seam first:** T7.3 (`5.18.0`) added `Actions.add_rebindable`; this row merged it down. `CombatActions.install` now adds its six actions through it, so they are listed on the controls screen under six new `ui.action.combat_*` labels, rebind and save like the built-ins, are put back by Reset, and get the player's saved key at boot (`install` runs after `KeyBindings.load_all`, and adding re-applies it). **Found by the suite:** upstream's own `game_actions_test` counted the screen's rows from `REBINDABLE`, so it failed once this fork's actions were added; fixed upstream first as `5.18.1`. `combat_input_test.gd` grew to 25 assertions. Red first: 6 failed |
| C5.3c | Triggers on the controls screen | TODO, found by C5.3a's capture. Dodge and lock on sit on the pad triggers, an axis, and upstream's `KeyBindings` names and rebinds only pad buttons, so their pad column shows "—" and a trigger cannot be chosen there. They work in play. Upstream row first: name a trigger, and accept one when rebinding a pad slot |
| C5.3b | Combat settings | TODO. After upstream T7.4 (a game-registered settings section): lock-on assist, wait/active mode, difficulty and auto-battle as player settings |
| C5.4 | Accessibility | TODO. A difficulty multiplier stage, auto-battle, hold-to-attack |
| C5.5 | Docs | TODO. `AUTHORING.md` combat chapters. `NEW_GAME.md` § Choose your combat, with the `combat.*` CSV prune |
| C5.6 | Playtest | TODO. `PLAYTEST.md`'s loop; each finding becomes a row |
| C5.7 | Release 1.0.0 | TODO. Release notes and a final strip test |
| C5.8 | A fall safety net | TODO. Found in C4.11: a body knocked off a floor's open edge falls for ever. A kill height (a project setting) below which a field foe is defeated or set back at its home, and the player handled by their `DefeatRule`. A test drops a fixture fighter below it |
| C6.0 | Hero powers: research and design | **DONE**, documents only, combat `0.49.1`. New `docs/POWERS.md`: the nine characters' powers, from search results and game guides (the fandom wikis are outside this container's network allow-list), mapped to one framework (`PowerKit`, `Power`, `PowerScaling`, `GaugeRule`, `PowerMechanism`; `PowerSet`, `PowerUse`, `PowerMechanisms`) and thirteen shared mechanisms (barrage, finisher, barrier, domain, form, gauge, foresight, command, blink, clone, sacrifice, grant, counter stance). Every mechanism has a stated meaning in battle and in the field. Real names, in data and the CSV only |
| C6.0b | Two more characters: Isliid and Roland | **DONE**, documents only, combat `0.56.1`. At the owner's request: Isliid (Grand Summoners; Emperor, "Beyond Fate" (the game's Defier of Fate) and Human Pinnacle) and Roland (The Last Cloudia; base, Ascended, Heroic Lord), each one kit whose forms share an exclusive group. One new mechanism, M14 `refresh`, and four seams placed in C6.4, C6.5, C6.6 and C6.25. New rows C6.24 and C6.25 |
| C6.1a | Powers framework: content | **DONE**, combat `0.50.0`. Split from C6.1 by the 8-file rule. `PowerKit`, `Power` (`active_at` handles a window across midnight), `PowerScaling` (pure `multiplier(reading)`, factor or `Curve`), `PowerMechanism` (base: `kind`, `problems`) under `src/content/combat/powers/`; `SkillUse.cost_of` reads `cost_mult_<pool>` (ADD to 1, like `poise_taken`), used by `affordable` and `pay`. `power_content_test` (20). Found: a `Curve` clamps to its `max_value` (1 by default), documented on `PowerScaling.curve`. `GaugeRule` moved to C6.4, the row that reads it |
| C6.1b | Powers framework: gameplay | **DONE**, combat `0.51.0`. Under `src/gameplay/combat/powers/`: `PowerSet` (a body child: equip and unequip a kit's stat bonuses, re-sourced to the kit id, and passives; cooldowns in seconds of fight time for a `real_time` fighter, `tick_turn` in battle; one executor per mechanism), `PowerUse` (`refusal` with nine reasons, `targets` through `FieldCommands`, `use`, `scaled_skill` on a copy, `multiplier` for a mechanism's COUNT), `PowerMechanisms` (`BUILT_IN` table plus `register` for a game's own) and `PowerExecutor` (`use`, `tick`, `end`; later rows add their hooks). `power_use_test` (34) with a fake mechanism. `Battle` calling `tick_turn` came with C6.2a |
| C6.2a | Powers in a turn-based battle | **DONE**, combat `0.52.0`. Split from C6.2 (about 13 files) by the 8-file rule. `CombatantDef.power_kit` is the ONE kit field: the field reads `loadout.fighter.power_kit` (C6.2b), so there is no `ActionLoadout.power_kit`. `BattleCommand.Kind.POWER` (appended), `power`, `for_power` (carries the power's skill, so it aims like a skill); `BattleSetup` equips the kit on either side; `Battle.targets_for`, `allows` (a silence blocks it) and `act` route it through `PowerUse.use`; cooldowns tick at the START of the holder's turns, beside its statuses, so a sleeper's still count and "cooldown N" means usable again N turns later. `power_battle_test` (24) |
| C6.2b | Powers in the field | **DONE**, combat `0.53.0`. `ActionHost.fit_identity` adds a `PowerSet` wearing `loadout.fighter.power_kit` (player and followers); `FieldParty._identity` moves it on a switch, cooldowns included; `PowerSet` ends its executors when freed (`NOTIFICATION_PREDELETE`), not on `_exit_tree`, which a switch's reparent also fires; its header's turn line fixed; `FieldCommands` routes a POWER through `PowerUse` (new `Reason.POWER`; no ATB cost: a power has its cooldown; a mechanism-only power aims at nobody). **Bug fixed:** a kit passive lives only in its kit, so a load dropped it ("no longer exists") and a new game cleared it: `StatusSet._apply_save` now finds it through `PowerSet.passive_of`, and `PowerSet` holds its passives again on `game_started` and `game_loaded`, never twice. `power_field_test` (18) |
| C6.2c | Powers in the menus | **DONE**, combat `0.54.0`. New `PowerMenu` (`src/ui/combat/`): `commands` turns the equipped kit's non-passive powers into POWER commands under one `ui.battle.powers` category, `with_powers` appends them to a menu, `reason_key` turns a `PowerUse.Reason` into words (a cooldown in seconds for a `real_time` fighter, in turns in a battle; hours; a needed status; a pool too low; blocked; cost; not equipped), `reason_args` fills the blanks (`pool`, `left`). **Four defects fixed:** `BattleMenu.refusal` never asked `PowerUse` (a cooling power looked usable) and greyed a mechanism-only power "nothing to aim at"; `CommandOverlay` had no words for `Reason.POWER` (a refused power looked usable); the overlay printed ATB bars on a power, which costs none; both screens printed a skill's plain `cost`, not `SkillUse.cost_of`. `CommandHost` also opens for a fighter whose loadout has no commands but whose kit has powers (an ATB gauge is still needed). `power_menu_test` (18). Gap: the overlay redraws only when a bar fills, so a field cooldown's "ready in Ns" can go stale while it is open; C6.3's HUD shows live cooldowns |
| C6.3a | Quick slots | **DONE**, combat `0.55.0`. Split from C6.3 by the 8-file rule. Four `combat_power_N` actions through `Actions.add_rebindable` on keys 1 to 4, no pad default (every pad button is taken; a pad player binds them on Options -> Controls), labelled `ui.action.combat_power_N`. New `PowerSlots`: slot N is the kit's Nth non-passive power in kit order (the Powers menu's order; nothing new saved), `press` uses it through `FieldCommands`, so no ATB cost and the pure action formula gets powers too. `ActionFighter.press_slot`: works mid-swing, refused while knocked back, staggered, fallen or held by a menu or dialogue. `power_slots_test` (11) |
| C6.3b | The HUD's slot line | **DONE**, combat `0.56.0`. A new `Events.power_cooldown_changed(who, power_id, left)`, emitted by `PowerSet` only when the whole number left changes; the HUD's slot line (each slot's key, name and cost, or its reason, "ready in 3s"); the F overlay redraws on it when a power is ready again, closing C6.2c's stale-cooldown gap (not every second, which would pull focus to the first row; the HUD line stays in view and counts). `PowerSet` emits after storing the new value, so a listener reading `cooldown_left` sees it. `power_hud_test` (14) |
| C6.4a | Gauges (M6): the rules run | **DONE**, combat `0.57.0`. Split from C6.4 by the 8-file rule. `GaugeRule` (content: `pool`, `per_second`, `per_turn` (new: a battle turn), `per_idle_second`, `per_moving_second`, `on_hit_dealt`, `on_hit_taken`, `on_dodge`, `on_miss`, `blocked_by_tags`, `levels` as points -> status) and `PowerKit.gauges`; `KitGauges` (gameplay) moves each gauge pool in `Vitals`, carrying fractions to the next whole point; `PowerSet` feeds it time and the four events from `Events`, and moves each gauge's level status on every `vitals_changed` of its pool, so spending a gauge drops its level. A `regen_<pool>` stat fills a gauge pool by the second in the field (Pinnacle True Arts). A fallen fighter's gauges stand still. `power_gauge_test` (19) |
| C6.4b | Gauges (M6): the readout and the other events | **DONE**, combat `0.58.0`. Closes C6.4. `GaugeRule` gains `on_kill` (a remembered `combatant_defeated` id followed by this fighter's `combatant_damaged`), `on_ally_defeated` (through the new `Combatant.find`), `on_new_move` (`ActionFighter` reports each move but the dodge to `PowerSet.moved`; only one unlike the last counts; the field only), `spent_pool`/`on_spent` (`SkillUse.pay` tells `PowerSet.spent`), and `per_running_second`, added on top of the moving rate while the player's gait is RUN. The HUD readout needed no code: `CombatHud` already lists every `max_<pool>` pool and the held level status; the test proves it. `on_perfect_dodge` moved to C6.6 |
| C6.5a | Forms (M5): the form itself | **DONE**, combat `0.59.0`. Split from C6.5 by the 8-file rule. The first built-in mechanism: `FormMechanism` (content, `powers/mechanisms/`: `status`, `exclusive_group`, `cycle` of stages that are forms themselves, `advance_after`, `drain_pool` with `drain_per_second` and `drain_per_turn`; `attack_chain` and `dodge` declared for C6.5b) and `FormRun` (its executor, registered in `PowerMechanisms.BUILT_IN`). A form IS its status: the executor reads which stage is held back from the `StatusSet`, so a cure, a timed form running out, a new game or a load need no wiring. New executor hook `power_used`, fed by `PowerSet.used` from `PowerUse.use`; `PowerSet.running()` |
| C6.5b | Forms (M5): moves and drain per action | **DONE**, combat `0.60.0`. Split again by the 8-file rule. Executor hooks `moves(base)` and `moved(move)`; `PowerSet.moves_over(base)` threads the fighter's own `MoveSet` through each running mechanism in kit order, read by `ActionFighter.current_moves()` and `PartyFollower._swing`, so a form plays its own `attack_chain` and `dodge` (a cycle stage's own, else the cycle's: `FormMechanism.moves_of`); `drain_per_action` drains for each move started in the field, never a dodge. A dodge is now known by its swing number, not its move. Gap: a follower does not report its moves (as C6.4b's `on_new_move`), so its form drains per second only; a battle has no moves |
| C6.5c | Forms (M5): slots and saves | **DONE**, combat `0.61.0`. **C6.5 is complete.** `PowerMechanism.statuses()` (a form lists its stage statuses) and `PowerKit.status(id)` (a passive, or a mechanism's status); `PowerSet.passive_of` uses it, so a form held at save time is held again after a load (before, `StatusSet._apply_save` dropped it with a warning), and a new game ends it; `PowerSlots.powers` skips a power whose `requires_statuses` names a status the kit grants and is not held, so each form has its own four, on the HUD's slot line too. A power needing a status from elsewhere keeps its slot and its reason; the menus still list every power |
| C6.6a | Barrier (M3) and the incoming guard | **DONE**, combat `0.62.0`. C6.6 split in three by the 8-file rule. `Combatant.receive` hands each resolved hit to `PowerSet.guard` (its own kit's mechanisms first, then each ally's on the same clock), through the new executor hook `intercept_incoming`. `BarrierMechanism` extends `FormMechanism` (entered, left, grouped and kept up like a form; the form's drain is its upkeep; no status means always up) and adds `mode` NULLIFY or REDUCE (`factor`), `cost_pool` and `cost_per_block` (unpaid: it comes down and the hit lands), `bypass_tags`, `absorb_elements` into `store_pool`, and `scope` SELF or ALLIES. `DamageResult` gains `tags` (`Combatant.hit` takes them; `SkillUse` passes the skill's; `sure_hit` is added) and `blocked`: a hit stopped whole chips no shield and, from a plain move, gives no poise and no push |
| C6.6b | Timed block, and a blocked hit announced | **DONE**, combat `0.63.0`. `BarrierMechanism` mode TIMED_BLOCK with `timing`, C4.10's `TimedWindow` (new `inside`), counted from the moment the guard goes up (`BarrierRun._held`: seconds in the field; in a battle a block is perfect until the guard's own next turn). A perfect block takes 0, costs nothing and stores the hit in `store_pool`; a late one pays `cost_per_block` and leaves `factor`. Give the guard's status a short duration so each press raises it anew. New `Events.attack_blocked`: `Combatant.receive` emits it for a hit stopped whole, in place of `combatant_damaged` with 0, and the battle log writes "blocks the attack" |
| C6.5d | Transformations with a look | DONE (0.69.0). The look and the name: `LookDef` (a tint, a size and a tag until sprites exist), a form's `look` and `name_key` (a cycle stage falls back to the cycle's), `LookSwap` on every field body (asks each frame, so every way a form ends shows), and the form's name on the battle screen and the HUD (`GEAR.md` § Part 4) |
| C6.5e | A form's own commands | DONE (0.70.0). Split by the 8-file rule. `commands` (the battle and field menus offer them in place of the fighter's own while the form is held, through `PowerMenu.with_powers`), `replaces_attack` (a battle's Attack is done as that skill; the Attack row takes its name), `aftermath` (on when the form ends by its own rules: used again, drained, timed out; never by a rival, a cure or the kit coming off). A cycle stage falls back to the cycle's (`GEAR.md` § Part 4) |
| C6.5f | Once per battle | DONE (0.71.0). `Power.once_per_battle`: after its first use a power is refused with `PowerUse.Reason.ONCE` (menu: "once per battle") until the next battle, which builds a fresh `PowerSet`, or in the field until the next area (`OnceLedger`, wiped on `Events.area_entered`). Unequipping does not wipe it. The form's name on the party sheet moved to C7.7: no party or status screen exists yet |
| C6.6c | Perfect dodge, no flinch | DONE (0.72.0). `ActionMove.perfect_window`: a hit dodged in the first seconds of the i-frames is perfect (`MoveTimeline.perfectly`); `Hurtbox.take` sends `Events.perfect_dodge` after `attack_dodged`; `GaugeRule.on_perfect_dodge` pays on top of `on_dodge`. The `knockback_taken` stat scales the push in `Hurtbox._push` (1 plus the stat, never below 0); at −1 there is no push and no stun, so the player, enemies and followers, which flinch only on that push, all keep their swing. The field only: a battle has no dodge moves |
| C6.6d | Counter stance (M13) | DONE (0.73.0), closing C6.6. Built as data: a form (hold it, with the form's drain as upkeep) or a TIMED_BLOCK barrier (the parry) whose status carries COUNTER and the new `StatusEffect.counter_move`. Field: a hit that lands or is blocked starts the move on the holder's timeline (`Hurtbox`, asking `SkillUse.counter_stance`), with no push, not begun again while it plays; the player turns to face the attacker. Battle: the counter strikes with the move's numbers (`SkillUse.answer`: its skill, or `hits` × `power`); still only a plain ATTACK is countered. No move means the old plain hit |
| C6.7 | Barrage (M1) | DONE (0.74.0). `BarrageMechanism` (kind `barrage`): `pattern` RING_BEHIND_USER, RING_AROUND_TARGET, RAIN, LINE or FROM_GROUND; `count` (times COUNT scaling), `interval`, `speed`, `turn_rate` (homing), `radius`, `height`, `pierce`; `shots`, a list of `ActionMove`s played in turn (the sizes); `elements`, one drawn per shot. Field: `BarrageRun` fires the first shot at once and the rest over time, each a `Projectile` (a `Hitbox` with its own clock that waits through `startup`, flies through `active`, and is gone after its first strike unless it pierces). A LINE shot with speed 0, pierce and a long box is the beam (`beam_hitscan`). Battle: the power is offered every standing foe (`PowerMechanism.aims_at_foes`), and its hits land at once on foes picked at random. Where the misses land is C6.26's (built there) |
| C6.8 | Finisher (M2) | DONE (0.76.0). `FinisherMechanism` (kind `finisher`): `strike`, an `ActionMove`; `charge_time` (field seconds) and `charge_turns` (battle turns, landing at the start of the user's turn); `charging`, a status held meanwhile (duration 0); the charge is lost when that status ends early (`breaks_on_hit`), on one hit of `break_damage` or more, or when the user falls; `flourish`, real seconds the field fight stands still first (`Flourish`, `CombatClock` at 0, giving the old speed back even when freed early); `all_foes` with `reach`, else the aimed foe (the first standing one in a battle); the power's POWER and HITS scaling read as it lands, then `drain_pool` emptied. Hold-to-charge input, a line-shaped strike (use a beam barrage) and an execute below a threshold are not built (see the devlog) |
| C6.9a | Battlefield (M4), the core | DONE (0.77.0). `BattlefieldMechanism` (kind `battlefield`, a `FormMechanism`: its `status` marks it standing; never a cycle) with `effects`, `radius`, `seconds` and `turns`; `BattlefieldEffect` with `who` (CASTER, CASTER_SIDE, OTHER_SIDE, EVERYONE, EVERYONE_BUT_CASTER), `modifiers` and `statuses`. `BattlefieldRun` lets in every fighter on the caster's clock (real time in the field, turns in a battle) within reach on raising and on each tick, and takes what it put on off as they leave or as it ends (used again, drained, timed out, cured, kit off, caster fallen). `damage_dealt` on the attacker in `VulnerabilityStage`. **Not built:** a sphere left at a point or a ZONE (only around the caster), fighters chosen by tag, a status of the same id from elsewhere is cured with the field's, and a load restarts its clock |
| C6.9b | Battlefield damage and movement | DONE (0.78.0). `BattlefieldEffect` gains `on_enter`, `on_exit` and `tick` (each a `Skill` the caster uses on the group, free; its `target` and `scope` are not read), `tick_seconds`, `tick_turns` (the caster's turns), `tick_grows`, `pull`, `push` (field only, never past the caster) and `immune_tags` (a held status's tag); the stat `resist_field_<name>` keeps a fighter out of the whole battlefield. `SkillUse.apply` takes a `strength`. **Not built:** a tag gained while inside keeps what came in with it until it leaves (ticks and pull check it each time); `on_exit` lands when the caster falls too; the battle tick counts the caster's turns, not each fighter's own |
| C6.9c | Battlefields against each other, the hit side | DONE (0.79.0). `sure_hit`, `hit_tags`, `broken_by_tags` and `cancelled_by` on the mechanism, as status flags the caster holds while it stands (`StatusEffect.grants_sure_hit`, `grants_hit_tags`, `cancelled_by`). `Combatant.hit` reads them through `HitFlags`, so a field strike, a skill and a battle attack all get them. A barrier's `bypass_tags` reads the tags. **Not built:** a battle attack (not a skill) does not break a battlefield; only the field's `Hurtbox` does. The sure hit is checked by the tag, not by an accuracy roll |
| C6.9d | Clashes and `closed` | DONE (0.80.0). `layer` (TERRAIN, WEATHER, DOMAIN), `refinement` (scaled by `refinement_stat` when named), `clash` (STRONGER_WINS, BOTH_END, OVERWRITE, BOTH_STAND, judged by the newcomer), and `closed` (held at the field's edge; a battle has no edge until C6.9e). Clashes compare battlefields of the same clock only, and only when they overlap |
| C6.9e | The caster's kit | DONE (0.81.0). `caster_kit` on the mechanism: a kit the caster holds only while the battlefield stands. On at the raise, off at the lower, however it ends; a clash loss never raises it |
| C6.9f | The place | DONE (0.82.0). `PlaceLook` (a dummy tint and name until art), `moves_fight` (the fighters in reach, caster too, taken to a pocket until it ends; field only), `weather` (held while it stands, the old one put back). Gaps: nothing draws the look yet; the pocket is a far spot, not a scene; neither is saved, as the field is not. Summons are C8.10 |
| C6.9g | The log and HUD | DONE (0.83.0). `Events.battlefield_raised`, `battlefield_lowered` (`broken`) and `battlefield_clashed`; `BattleLog` lines for each, naming the battlefield and its place; the field HUD's battlefield line (`CombatHud.field_text`). Gaps: no art or sound; the field has no log, only the HUD line; a clash loser that never rose has a clash line but no "shatters" line |
| C6.10 | Foresight (M7) | TODO. Rewrites (a landing hit becomes a miss, the user's miss becomes a hit), observe-immunity per skill per fight, reveal weaknesses on sight |
| C6.11 | Command and grant (M8, M12) | TODO. OBEY (faction flip in both formulas), STOP, FORGET, FALL; sight and range; once per foe through `Flags`, cleared by `geass_canceller`; grant a status or power to an ally |
| C6.12 | Blink, sacrifice and refresh (M9, M11, M14) | TODO. Teleport to, behind or above a target, or forward; cancel recovery; a sooner turn in battle. Take HP and buffs from allies. Cut the user's or allies' cooldowns by a fraction, and a `cooldown_rate` stat `PowerSet` reads (C6.0b). Also `to` SWAP (two fighters trade places) and a blink whose path hits (`POWER_ATLAS.md`) |
| C6.13 | Clone (M10) | TODO. A ghost replaying the user's timeline after a delay; in battle the next actions happen twice |
| C6.14 | Kit: Gojo | TODO. `data/powers/gojo.tres`, `power.gojo.*` rows, a content test case, a probe and a capture (`POWERS.md` § Gojo) |
| C6.15 | Kit: Gilgamesh | TODO. As C6.14 (§ Gilgamesh) |
| C6.16 | Kit: Escanor | TODO. As C6.14 (§ Escanor); the probe sets `--time` noon and midnight |
| C6.17 | Kit: Arima | TODO. As C6.14 (§ Arima) |
| C6.18 | Kit: Lelouch | TODO. As C6.14 (§ Lelouch); the probe shows a second Geass on the same foe refused |
| C6.19 | Kit: Yhwach | TODO. As C6.14 (§ Yhwach) |
| C6.20 | Kit: Odin, and Barnabas the boss | TODO. As C6.14 (§ Odin), plus a Barnabas `CombatantDef` whose brain uses the same kit and becomes Odin at a third of his HP |
| C6.21 | Kit: Vergil | TODO. As C6.14 (§ Vergil) |
| C6.22 | Kit: Dante | TODO. As C6.14 (§ Dante) |
| C6.23 | Choosing a kit, and authoring | TODO. A debug `power_kit <id>` command, the demo loadout's default kit, `AUTHORING.md` § Powers, and "add a new character in five steps" |
| C6.24 | Kit: Isliid | TODO. As C6.14 (§ Isliid, added by C6.0b): three forms, the sword cycle, `arts`, `true_arts` and `super_arts` gauges. Needs C6.4, C6.5, C6.6, C6.8, C6.11, C6.12 |
| C6.25 | Kit: Roland | TODO. As C6.14 (§ Roland, added by C6.0b): three forms, Charisma, Trance, Glorious Finale, and `PowerScaling.Source.ALLIES_STANDING`. Needs C6.4, C6.5, C6.8, C6.9, C6.12. Also `PowerScaling.Source.ALLIES_FALLEN` (`POWER_ATLAS.md`) |
| C6.26 | Plant (M15) | DONE (0.75.0). `PlantMechanism` (kind `plant`): `where` AT_TARGET, AT_USER, AHEAD (`distance`) or WHERE_PROJECTILES_LAND; `count` (times COUNT scaling) spaced `spread` apart along the line from the user, `max_standing` (the oldest is lost); `trigger` REMOTE (the next use, or a power in `set_off_by`; a ripple `chain_delay` apart), PROXIMITY (`radius`), TIMER (`seconds`, or `turns` in a battle) or ON_HIT (a foe within `radius` is hit by anyone); `eruption`, an `ActionMove`; `lifetime`; `mark`, the battle's status. Field: each plant is a `Planted` node, a still `Hitbox` that waits, then plays its eruption. A barrage shot that ends without striking reports where (`Projectile.landed`, the executor hook `projectile_landed`), so the misses stay in the ground. Battle: a plant is the `mark` status on a foe, set off by the same triggers (PROXIMITY when the foe deals damage, ON_HIT when it is hit), the eruption once per mark (`BarrageRun.strike_with`); a barrage shot that misses marks its foe. `visible_to_foes` and `recall` wait for art and M9 `blink` (C6.12) |
| C6.0c | The power atlas | **DONE** (0.66.1). The owner's powers pack (3,306 powers, 116 handler families, 127 character profiles) and full weapons list kept under `docs/reference/`; `POWER_ATLAS.md` sorts every family onto a mechanism (built, planned, new or out of scope), maps the pack's engine contract onto what exists, and adds rows C8.10–C8.15. Small additions noted for C6.7 (LINE beam), C6.12 (SWAP, a path that hits) and C6.25 (`ALLIES_FALLEN`) |
| C7.0 | Gear: research and design | **DONE** (0.63.1). `docs/GEAR.md`: gear, rarity, special gear, sets, sockets, upgrading and crafting on upstream's items; IXA, Owl, Ea and the armours; battlefields (M4 widened); the planted strike (M15); transformations; the mechanics survey |
| C7.1a | Gear as data, worn | **DONE** (0.64.0). `GearType`, `GearRules` (the slot list), `GearDefinition` (an item plus what wearing it does), `GearDb` and `GearSet`: wear and take off, one piece per slot, a piece that fits two slots, wearers, modifiers on the stat sheet by source, saved in `Flags` as `gear/<wearer>/<item id>`, off when the item leaves the bag, back after a load |
| C7.1b | Gear in a fight | **DONE** (0.65.0). `CombatantDef.gear` lists a fighter's starting pieces by item id. `GearSet.fit(body, def, keep)` gives a fighter its worn set: `BattleSetup` (party kept, enemies not), `ActionHost.fit_identity` (the player and followers) and `ActionEnemy`. Starting pieces go on once (flag `gear_started/<id>`), so a piece the player took off stays off; a new game puts them on again. A starting piece is the fighter's own (`innate`): no bag needed. A set with `kept` off writes no flag, so a foe's gear is never in a save. `FieldParty` carries the set on a switch. The slot list comes from `[combat] gear/rules`. The row was split by the 8-file rule: the weapon's element, tags and two-handed are C7.1c |
| C7.1c | The worn weapon on attacks | **DONE** (0.66.0). `element` and `attack_tags` on `GearDefinition` and `GearType`. `GearSet` writes what the worn pieces lend onto the wearer's `Combatant` (`lent_element`, `lent_tags`), reading slots in the slot list's order so the weapon speaks first. `Battle`'s ATTACK and `Hurtbox` ask `strike_element` and `strike_tags`; a move with its own element keeps it, and a skill or a power is unchanged. Two-handed is the general `blocks` list (slots a piece takes up besides its own): putting the piece on empties them, and a piece put into a blocked slot takes the blocker off |
| C7.2 | Rarity and drops | **DONE** (0.67.0). `Rarity` tiers as data (`stat_scale` on the piece's stat changes, `drop_weight` in rolled loot; colour, affix, socket and upgrade fields declared for C7.5, C7.2b, C7.4), `RarityDb`, `GearDefinition.rarity`, `LootTable` and `LootEntry`, `LootRoll`; rolled loot in `Rewards.grant` and from `ActionEnemy`. Seven sample tiers in `data/rarities/` |
| C7.3 | Special gear | **DONE** (0.68.0). `GearDefinition.kit`; `PowerSet` holds several kits (`lend`, `kits`, `powers`, `status`), own kit first, then gear's in slot order, each kit put on and taken off alone so cooldowns and forms of the others carry on; `GearSet` hands the worn kits over after every change and gives a fighter with no powers a `PowerSet` when needed; `GearSet.wearing`, `Power.requires_gear`, `PowerUse.Reason.GEAR`, `ui.battle.reason.needs_gear`; a weapon's pool is a `max_<pool>` modifier (proved by a test); `PowerGuard` split out of `PowerSet` for the line budget. The design's `passives` field was dropped: a piece's kit already holds passives. |
| C7.3b | A weapon's own swing chain | DONE (0.84.0). `GearDefinition.moves` and `GearType.moves`, `strike_moves()`; `Combatant.lent_moves` written by `GearSet`, `Combatant.field_moves` played by `ActionFighter.current_moves` and `PartyFollower`, under a form's moves. Gaps: field enemies (`ActionEnemy`) pick moves by their brain, so a foe's weapon lends no chain; a battle's ATTACK has no chain; a follower's brain still names its own first swing to start the chain |
| C7.4a | Who may wear what | DONE (0.85.0). `needs_level`, `needs_stats`, `cursed` on `GearDefinition`; `GearSet` refusals `LEVEL_TOO_LOW`, `STATS_TOO_LOW`, `CURSED`; `take_off(item_id, force)`; `GearLending` holds the lending. Gaps: the checks run only when a piece goes on, so a level or stat that later drops leaves it worn; there is no remover item for a curse yet (a script forces `take_off`); no screen shows a refusal until C7.7 |
| C7.4b | Gear sets | DONE (0.86.0). `GearSetBonus` and `GearSetTier`; `GearDefinition.set_bonus`; `GearSetBonuses` gives the reached tiers' stat changes (`set/<set id>`) and kits (`set/<set id>/<pieces>`); a status at a tier is a kit passive. Gaps: no set name or tier list on a screen until C7.7; rarity does not scale a set's stat changes; two pieces of one set carrying different bonus files are not flagged (the first worn decides) |
| C7.4c | Sockets | DONE (0.87.0). `GemDefinition` and `GemDb`; `GearDefinition.sockets` and `socket_count()`; `GearSockets` socket and unsocket a gem (used up, given back, a remover from `[combat] gear/gem_remover`), saved as `socket/<piece>/<index>` flags; a worn piece's gems give stat changes (`gems`) and their element. Gaps: no screen until C7.7; rarity does not scale gems; no per-slot gem rule; two copies of one piece share sockets; a piece that leaves the bag keeps its gems recorded |
| C7.5 | Upgrading and awakening | DONE (0.88.0). `UpgradeTrack` of `UpgradeLevel`s on `GearDefinition.upgrade`; `upgrade_cap()` (piece's `max_upgrade`, else rarity's); `GearUpgrades` upgrades (paid from the bag), saved as `upgrade/<piece>` flags; a worn piece's levels give a share of its added amounts, their own stat changes (`upgrades`) and sockets; `Power.requires_upgrade` (`PowerUse.Reason.UPGRADE`); `awaken` at the cap into `awaken_into`. Gaps: no money cost (the base has no money); no screen until C7.7; per item, so two copies and a foe wearing the same item share the level; an awakened piece's gems stay recorded on the old item; the new piece is not put on |
| C7.6 | Crafting, the logic | TODO. After C9.4, by the owner's order (2026-11-13). `Recipe` (craft, upgrade, awaken, dismantle, transmute) and `Crafting` |
| C7.7 | The gear screen | TODO. Slots, compare, rarity colours; the weapon and its mode on the HUD and the battle screen; the form's name beside each member (`LookSwap.form_name_key`, moved from C6.5f) |
| C7.8 | The craft screen | TODO. The screen and the `CraftStation` interactable |
| C7.2b | Affixes | TODO. Random extra modifiers on a dropped piece, saved per piece. Needs C7.5 |
| C7.9 | The armoury: weapons | TODO. IXA, Owl, Ea and the other heroes' weapons as data, a probe and captures. Needs C6.26, C6.9, C7.5 |
| C7.10 | The armoury: armours | TODO. The armour table as data; `AUTHORING.md` § Gear, Battlefields and Transformations. Needs C7.9, C8.6, C9.5; also builds the armour table in `PASSIVES.md` |
| C8.1 | An extra turn for a weakness hit | TODO. Press Turn and One More, as a rule on the turn order |
| C8.2 | Team attacks | TODO. All-out, chain and dual techs; follow-up attacks from a waiting ally |
| C8.3 | Summons and the reserve line | TODO. Fighters that join mid-fight; swapping party members in a battle |
| C8.4 | Elemental reactions | TODO. Two elements on one target make a third effect, as data |
| C8.5 | Rows and positions | TODO. Front and back rows, knock-back between them |
| C8.6 | Aggro, taunt and a second health layer | TODO. Who a foe picks; an overshield pool that refills |
| C8.7 | Steal, scan, capture and the rarer ailments | TODO. Doom counters, petrify, instant death |
| C8.8 | Launch, juggle, prompts and interrupts | TODO. On `ActionMove` and `TimedWindow` |
| C8.9 | Things in the arena | TODO. Barrels and throwables, on M15 `plant` |
| C8.10 | Owned fighters (summons) | TODO. From `POWER_ATLAS.md`. A battlefield's `summons` lands here (moved from C6.9e in 0.81.0). A power makes a fighter on the caster's side with its own brain; it knows its owner and the power that made it; lifetime, cap, linked hp; leaves when the owner falls, the power ends or the area is left; a saved roster in `Flags`. Needs C6.12; the battle side joins C8.3 |
| C8.11 | Time: stop, rate and rewind | TODO. From `POWER_ATLAS.md`. A per-fighter `time_rate` stat beside `CombatClock` (the user of a time stop is exempt), and a time record of position, hp and statuses that puts one fighter or one saved point back. Needs C6.9a |
| C8.12 | Unseen | TODO. From `POWER_ATLAS.md`. A status foes cannot target or lock on to, ended by attacking or by an area hit; removed by a reveal |
| C8.13 | Copy, steal and seal | TODO. From `POWER_ATLAS.md`. Borrow a power seen or suffered (by source, timed or saved), take a foe's buffs, seal powers by sight or by field, a random power from a list. Needs C7.3 |
| C8.14 | Constructs | TODO. From `POWER_ATLAS.md`. Walls that block, a made weapon wielded for a while, linked doors; each with an owner and hp or a lifetime, and upkeep. Needs C6.26, C8.9 |
| C8.15 | Late and conditional outcomes | TODO. From `POWER_ATLAS.md`. A ledger status that holds hits and heals and settles once, a hit that lands later, one lethal hit turned into a revive, a status that spreads, a reaction to being targeted, a target filter by stat, scaling by the place |
| C9.0 | Design: passives, armours and kakujas | **DONE**, documents only, combat `0.88.1`. [`PASSIVES.md`](PASSIVES.md), at the owner's request; the mechanics encyclopedia in `docs/reference/mechanics_encyclopedia/` |
| C9.1 | Passives, the core | **DONE**, combat `0.89.0`. `PassiveSkill` (`held` status, `triggers`, `cost`, `tags`), `PassiveTrigger` (events FIGHT_START, FIGHT_WON, TURN_START, HIT_DEALT, HIT_TAKEN, KILL, ALLY_DEFEATED; `chance`, `cooldown`, `limit`, `interval`), `PassiveEffect` (POOL_FLAT, POOL_SHARE, POOL_FROM_DAMAGE, GIVE_STATUS, CURE on SELF, OTHER, ALLIES, FOES), `PassiveDb`, `PassiveSet` (`hold`, `release` by source), `PassiveEffects`; `CombatantDef.passives`. `tests/unit/passives_test.gd` |
| C9.2a | Passive conditions and more events | **DONE**, combat `0.90.0`. The first half of C9.2, split by the 8-file rule. `PassiveCondition` and `PassiveConditions`; the crit, dodge, guard, HP-line and status-gained events; `group` and `rank`; `traits` on a fighter. `tests/unit/passive_conditions_test.gd` |
| C9.2b | Passive hit effects | **DONE**, combat `0.91.0`. `PassiveHits` in the hit path; `SCALE_HIT` before the damage lands, `LETHAL_HIT` with `SURVIVE`, `EXTRA_HIT`; the conditions `HIT_TAG`, `HIT_ELEMENT`. `tests/unit/passive_hits_test.gd` |
| C9.2c | Passive skill and form events | **DONE**, combat `0.92.0`. `PassiveMoments`; `tests/unit/passive_moments_test.gd`. The events SKILL_USED (with a `tag` filter), FORM_ENTERED, FORM_LEFT; the effect `COOLDOWN_CUT`. `BREAK_PIECE` moves to C9.5, with the power that breaks its piece. Needs C9.2b |
| C9.3a | Passives on kits and gear | **DONE**, combat `0.93.0`. `PassiveLending`; `tests/unit/passive_lending_test.gd`. `PowerKit.passive_skills`, and `passives` on `GearDefinition`, `GearSetTier`, `GemDefinition`, `UpgradeLevel` |
| C9.3b | The sample passive library | **DONE**, combat `0.94.0`. 22 files in `data/passives/`; `check_content` section; `tests/unit/passive_library_test.gd` |
| C9.4 | The passive loadout | **DONE**, combat `0.95.0`. `PassiveLoadout`, `PassiveLesson`, `GearDefinition.teaches`, the budget on `CombatantDef`, `Rewards.learned`; `tests/unit/passive_loadout_test.gd`. Needed C9.3 |
| C9.5a | Defences that need no power | **DONE**, combat `0.96.0`. `HitGuard`: an `invincible` status (with `pierced_by`), mercy time after a hit, the overshield pool and its refill, and `healing_taken` in `Vitals.change`; in both formulas. `tests/unit/hit_guard_test.gd`. Split from C9.5 by the 8-file rule. Needed C9.2b |
| C9.5b | A piece that breaks, and adapting resistance | **DONE**, combat `0.97.0`. `BREAK_PIECE` breaks the worn piece that gave the passive (`GearBreak`); `SKILL_DONE` wakes after a skill's strikes, so a trump card lands before its piece breaks; `GIVE_STATUS` with `per_element` gives the status listed for the hit's element. `tests/unit/passive_break_test.gd`. Split again by the 8-file rule. Needs C9.5a |
| C9.5c | Berserk, and levels won by fights | TODO. A status that takes the commands away and picks targets by a brain; upgrade levels a piece wins by fights, not bought. Needs C9.5b |
| C9.6 | The kakujas | TODO. The shared kakuja passives, each kakuja as a form and as a quinque armour, as data, with a probe and captures. Needs C9.5c, C6.5d; C8.6 for the heavy ones |
| C9.7 | The loadout screen | TODO. With the gear screen. Needs C9.4, C7.7 |
| C9.8 | Research: fighting-game character files | TODO, documents only. At the owner's suggestion (2026-11-13): study how fan-made M.U.G.E.N-style characters (Jump Force Mugen and similar) write a character as states, triggers and controllers, and note the ideas worth having in `PASSIVES.md` and `POWERS.md`. The owner's rule (2026-11-13): their character logic may be downloaded, read and used as a guide, since only code is being made now; the logic is rewritten here in GDScript on this engine's parts. No sprite or sound from them enters this repository: the owner will draw the art or ask permission later |

**Rules for the rows:** the same as upstream's board (`WORK_PACKAGES.md` § The rules), unchanged:

- one package at a time;
- about 8 files or 500 lines at most;
- the full ladder plus all seven checkers;
- a package is done only when merged.

**One addition:** a row that changes code ends with `git fetch template && git merge template/main`.
That merge either says "Already up to date", or it gets merged and the ladder is re-run, so the
upgrade path is tested every phase.
