# Mechanics guide: how a power works, from the data to the hit

**Who this is for:** you, later, wanting to build new powers for the main character. This
guide explains how the parts work and which code runs them. Its twin,
[`POWER_COOKBOOK.md`](POWER_COOKBOOK.md), is the hands-on half: "I want this power; build it
like this", with a complete example kit that has been loaded and used in the engine.

Every claim here was read from the code on 2026-11-15 (combat 0.129.0). Files are named, not
line numbers, because lines move. Where the code and this page ever disagree, the code wins;
each file's own `##` header is the next thing to read.

**Contents:**
1. The parts, in one table
2. How a kit gets onto a fighter
3. Life of a power in the field, step by step
4. Life of a power in a turn-based battle
5. How a hit becomes damage
6. Moves: the timeline, chains, i-frames and events
7. Statuses and stat modifiers
8. Gauges
9. Forms (stances, transformations, weapon modes)
10. The other mechanisms, and the hook each one uses
11. Passives
12. Arima and Eto, taken apart
13. Traps found while writing this
14. Where to look when something does not work

---

## 1. The parts, in one table

Content classes are **data only** (`src/content/combat/...`). Gameplay classes **run** that data
(`src/gameplay/combat/...`). The rule that keeps this tidy: data never runs itself, and code
never names a character.

| Part | Data class (what you author) | Runs it | What it is |
|---|---|---|---|
| Kit | `PowerKit` (`src/content/combat/powers/power_kit.gd`) | `PowerSet` | One character's whole set: powers, passives, stat bonuses, gauges |
| Power | `Power` (`powers/power.gd`) | `PowerUse` | One button: a skill + an optional move + an optional mechanism + rules (cooldown, needs) |
| Skill | `Skill` (`skill.gd`) | `SkillUse` | What lands: cost, target, power, element, statuses, effects. Shared with every formula |
| Move | `ActionMove` (`action_move.gd`) | `MoveTimeline`, `Hitbox`, `Hurtbox` | Real-time timing and a hitbox: startup, active, recovery, i-frames, events |
| Move set | `MoveSet` (`move_set.gd`) | `ActionFighter` | A fighter's basic `attack_chain` and `dodge` |
| Mechanism | `PowerMechanism` subclasses (`powers/mechanisms/`) | a `PowerExecutor` subclass (`gameplay/combat/powers/mechanisms/*_run.gd`) | The one thing a skill cannot do: a form, a barrier, a barrage, a domain... |
| Status | `StatusEffect` (`status_effect.gd`) | `StatusSet` | A timed (or endless) state: stat changes, ticks, blocks, reactions, special flags |
| Stat change | `StatModifier` (`stat_modifier.gd`) | `StatSheet` | ADD, MULTIPLY or OVERRIDE one named stat, removed by its `source` |
| Gauge rule | `GaugeRule` (`powers/gauge_rule.gd`) | `KitGauges` | How a pool (a "meter") fills and drains |
| Scaling | `PowerScaling` (`powers/power_scaling.gd`) | `PowerUse.scaled_skill` | "Stronger when hp is low", "longer at night" |
| Passive | `PassiveSkill` (`passives/passive_skill.gd`) | `PassiveSet` | An always-on status, plus triggers ("on a kill, heal") |
| Look | `LookDef` (`look_def.gd`) | `LookSwap` | A tint, size, label, or a whole sprite set while a form is held |
| Fighter | `CombatantDef` (`combatant_def.gd`) inside an `ActionLoadout` (`action_loadout.gd`) | `ActionHost`, `BattleSetup` | Who the hero is: stats, `power_kit`, art, basic moves |

The player's fighter is chosen in `project.godot`: `[combat] action/loadout` points at a
loadout file. Arima is `data/action/arima_loadout.tres`; Eto is
`data/action/yoshimura_eto_loadout.tres`.

## 2. How a kit gets onto a fighter

1. The game builds the player and calls `ActionHost.equip(body, loadout)`. It reads
   `loadout.fighter.power_kit` and puts a `PowerSet` node under the body, beside `Combatant`,
   `Vitals` (the pools: hp, mp, gauges) and `StatusSet`.
2. `PowerSet.equip(kit)` calls `_put_on(kit, kit.kit_id)`, which does four things:
   - each `stat_bonuses` entry goes on the fighter's `StatSheet`, with the kit id as its
     source. **This is how a gauge gets its size:** `max_<pool>` = 100 makes a 100-point pool,
     and `start_<pool>` = 0 makes it start empty;
   - `passives` (statuses) are put on, and `passive_skills` are lent through `PassiveLending`;
   - the gauges are rebuilt (`_regauge`, into a `KitGauges`);
   - for every power that has a `mechanism`, `PowerMechanisms.make(mechanism)` looks up the
     mechanism's `kind()` in its table and creates one executor. The executor lives as long as
     the kit is on, and holds that mechanism's running state on this fighter.
3. Taking the kit off (`unequip`) removes exactly those parts, found by the kit id as source.

**Why the source matters:** every stat change carries a source id. Removal is "remove everything
from source X", never "remove this object", so it survives saves and never removes someone
else's buff.

## 3. Life of a power in the field, step by step

Say Eto is in her kagune stance and the player presses **2** (Air Strike).

1. **Input.** `ActionFighter._physics_process` sees `combat_power_2` pressed
   (`CombatActions.SLOTS`) and calls `press_slot(1)`.
2. **Can she act?** `press_slot` refuses while stunned, fallen, or held by a menu or dialogue.
3. **Which power is in slot 2?** `PowerSlots.powers(me)` lists the kit's powers that are not
   passive, in kit order, **skipping any power that needs a status the kit itself grants (a
   form) that is not held now.** So each stance has its own four slots. That is why Eto's slot 2
   is Air Strike in kagune and Air Fall in kakuja.
4. **The press.** `PowerSlots.press` wraps the power in a `BattleCommand` and calls
   `FieldCommands.use`.
5. **The refusal checks.** `FieldCommands.refusal` asks `PowerUse.refusal`, which checks, in
   this order: passive → not equipped → once per battle spent → cooldown → active hours → gear
   → upgrade → required statuses → required pool fraction → a silence (NO_SKILLS) → can the
   skill's cost be paid. Then, if the power has a skill, is there anyone to aim at within 8 m
   (`FieldCommands.REACH`)? Any "no" stops everything here and changes nothing.
6. **Aiming.** `FieldCommands.targets`: a SELF skill aims at the user; an ENEMY skill at the
   locked-on foe, else the nearest foe in reach; an ALL skill at everyone in reach.
7. **Using it.** `PowerUse.use`:
   1. `SkillUse.pay` takes the cost from `cost_pool` (Air Strike: 17 `kagune`). The
      `cost_mult_<pool>` stat can make it cheaper. Paying also tells the gauges (`spent`).
   2. `SkillUse.apply` lands the skill **now**, on the aimed targets, through a copy changed by
      the power's `scaling` (`scaled_skill`). For Air Strike that is only the 2-second
      "resolve" buff on herself.
   3. The executor's `use` runs, if the power has a mechanism.
   4. The cooldown starts (`PowerSet.start_cooldown`), a once-per-battle power is marked
      spent, every running mechanism hears `power_used`, and `consumes_statuses` are cured.
8. **The move.** Back in `press_slot`: if the power has a `move`, `timeline.start(move)` plays it
   on the fighter's own clock, **replacing whatever swing was running.**
9. **Every frame after** (`ActionFighter.drive`): statuses tick in seconds, the timeline steps
   through STARTUP → ACTIVE → RECOVERY, the hitbox is fitted to the move and turned to face,
   and while ACTIVE the hitbox sweeps. Each hurtbox it touches is struck **once per swing**
   (section 5). During `travel_speed` the fighter lunges forward. During i-frames, hits on her
   pass through.

**The key idea:** a field power has two halves that do not know about each other. The **skill**
lands at once on whoever was aimed at (costs, buffs, instant damage). The **move** plays
afterwards and hits whatever its box touches. A converted M.U.G.E.N special puts all its damage
in the move and uses the skill only to pay and buff. A hand-built spell can do the opposite: a
damaging skill and no move.

## 4. Life of a power in a turn-based battle

1. The battle menu (`PowerMenu`) lists the kit's powers, greyed out with the `PowerUse` reason
   in words when refused.
2. Choosing one makes a POWER `BattleCommand`. `Battle._power` aims it like its skill and calls
   **the same `PowerUse.use`**.
3. Cooldowns count in turns: `Battle` calls `PowerSet.tick_turn()` at the start of the holder's
   turn. Statuses count their own unit (TURNS statuses tick per turn).
4. **The move is never played in a battle.** Nothing in `battle.gd` reads `power.move`. Only the
   skill and the mechanism act. Each mechanism has its own battle meaning (the table in
   [`POWERS.md`](POWERS.md) § The fourteen shared mechanisms): a barrage is `count` hits on
   random foes, a finisher charges for `charge_turns`, a form is a toggle status plus a swapped
   command menu.

See trap 1 in section 13 for what this means for converted fighters.

## 5. How a hit becomes damage

Two roads lead to the same place.

**Road A: a move's hitbox** (`Hitbox.strike` → `Hurtbox.take`):
1. `Hurtbox.take` refuses a hit on yourself, on an ally (by `FactionTable`), or on someone
   already down.
2. If the target's own timeline is in **i-frames**, the hit is dodged:
   `Events.attack_dodged`, plus `Events.perfect_dodge` inside the `perfect_window`. Gauges and
   passives listen to both.
3. Otherwise `_resolve`: a move that carries a `skill` lands it through `SkillUse.apply`; a
   plain move calls `attacker.hit(target, move.power * boost, element)` once per `hits`. Every
   landed plain hit chips a matching weakness (`Weakness.strike`).
4. If it landed: `poise` wears the target's shield (Break), a counter stance may answer, an
   `interrupts` move stops a wind-up, `knockback` pushes (scaled by 1 + the target's
   `knockback_taken`; −1 means never flinch), and `launch` lifts it into a juggle.

**Road B: a skill** (`SkillUse.apply`): per target, `power` through `_hit`, then each
`effects` entry, `hits` times over, then each status rolled once at `status_chance`. A REFLECT
status on the target can bounce a skill carrying its `reflect_tag`.

**Both end in `Combatant.hit` → `Combatant.receive`:**
1. `Combatant.hit` builds a `DamageRequest` from both stat sheets and runs the attacker's
   `DamageFormula`. The standard formula is six stages, in order:
   `AccuracyStage` (can miss, unless `sure_hit`) → `AttackDefenceStage`
   (`(power + attack) × 100 / (100 + defence)`) → `ElementStage` → `VulnerabilityStage` →
   `CritStage` → `VarianceStage`. A miss stops the stages.
2. `Foresight.rewrite` may turn a miss into a hit or a hit into a miss (foresight mechanism).
3. `receive` → `_land`, in this order:
   - `PassiveHits.scale`: attacker's then defender's passives may scale it;
   - `HitGuard.stops`: an `invincible` status (unless `pierced_by`) stops it;
   - else `PowerGuard.incoming`: **every running mechanism of the target, and of its allies,
     sees the hit first (`intercept_incoming`)**. This is where barriers work;
   - a hit stopped whole is `attack_blocked` and changes nothing;
   - overshield soaks, `PassiveHits.lethal` may let the fighter survive, a `ledger` status
     banks it;
   - finally `Vitals.change(damage_pool, -total)`, a sleeper wakes, `fill_on_hit_<pool>`
     meters fill, and `Events.combatant_damaged` is announced. Gauges hear it from there.

**So the damage numbers you control are:** the move's or skill's `power`, the attacker's
`attack` stat, the defender's `defence`, elements and weaknesses, crits, and anything that
multiplies those (statuses' modifiers, scaling, passives' SCALE_HIT).

## 6. Moves: the timeline, chains, i-frames and events

`MoveTimeline` (`src/systems/combat/move_timeline.gd`) is the clock of one fighter's moves.

- **Phases:** STARTUP (wind-up, nothing hits), ACTIVE (the hitbox is live; `travel_speed`
  moves the body), RECOVERY (follow-through). `length()` is all three added up.
- **Chains:** pressing attack starts the chain's first move; pressing again during the current
  move's recovery, from `chain_after` seconds in, starts the next. An early press (up to the
  buffer window) is remembered. `cancel_on_hit` opens the chain window as soon as the move
  lands.
- **Dodge:** allowed when idle or in recovery (`can_dodge`), never in a wind-up or a live swing.
- **i-frames:** `iframes_from`..`iframes_to` seconds after the move starts, the fighter cannot
  be hit. `perfect_window` is the first part of that stretch (a fighter's `perfect_window` stat
  widens it: ADD 0.5 = 1.5 times). `iframes2_from/to` is a second
  stretch. `armour_from/to` is "hits land but do not push".
- **One hit per target per swing:** `Hitbox` remembers whom this swing struck. `hits` > 1 on a
  plain move lands several times inside that one strike.
- **Events** (`MoveEvent`, `at` seconds into the move): SOUND, EFFECT (a picture), SHOT (sends a
  move flying as a projectile), SPEED (changes travel speed from now on), SHAKE (screen
  shake), PAUSE (hit pause). The converter fills SOUND, SHAKE and PAUSE from M.U.G.E.N.
- **Other move fields:** `poise` (Break damage), `knockback`, `launch`, `throw_move` (a grab),
  `prompt` (a timed press that multiplies power), `interrupts`, and `skill` (resolve the hit as
  this skill instead of `power`/`element`).

Timing numbers feel like this at 60 fps: 0.05 s is 3 frames, 0.1 s is 6, 0.25 s is 15.

## 7. Statuses and stat modifiers

A **status** (`StatusEffect`) is how almost everything lasting is expressed: a buff, a poison,
a form, a passive, a mark, a charge.

- `unit` TURNS or SECONDS, `duration` (0 or less = until cured), `stacking` (REFRESH, STACK
  up to `max_stacks`, IGNORE).
- `modifiers`: stat changes held while the status is held. You author them **without** a
  source; `StatusSet` stamps the status id on them.
- `tick_pool` + `tick_change` (+ `tick_interval` for SECONDS): a pool change per tick. A
  regen is `hp` +5; a drain is negative.
- `tags`: free labels (`buff`, `form`, `passive`...) that dispels, gauges' `blocked_by_tags`
  and scaling's TARGET_HAS_TAG read.
- `blocks` (SKIP_TURN, NO_SKILLS, NO_ITEMS, NO_FLEE), `breaks_on_hit` (sleep), `reactions`
  (COUNTER with an optional `counter_move`, REFLECT).
- Special flags, each a whole behaviour with no code to write: `invincible`, `grants_sure_hit`,
  `grants_hit_tags`, `takeover` (berserk), `fatal` (doom), `counts_as_fallen` (petrify),
  `unseen`, `late_power` (a delayed hit), `ledger`, `spread_reach` (contagion),
  `punish_status`, `obeys` (fights for whoever applied it).

A **stat modifier** names one stat by free name. The sheet applies ADD first, then MULTIPLY,
then OVERRIDE. Stats the code reads by name include `attack`, `defence`, `max_<pool>`,
`start_<pool>`, `cost_mult_<pool>` (−0.5 halves a pool's costs), `knockback_taken` (−1 = no
flinch), `cooldown_rate` (+0.3 = cooldowns 30% faster), `poise_taken`.

## 8. Gauges

A gauge is an ordinary pool, like hp. The kit makes it with two stat bonuses (`max_kagune`
100, `start_kagune` 0) and one `GaugeRule` naming the pool and what moves it:

- per event: `on_hit_dealt`, `on_hit_taken`, `on_dodge`, `on_perfect_dodge`, `on_miss`,
  `on_kill`, `on_ally_defeated`, `on_new_move` (style rank), `on_spent` per point of
  `spent_pool` paid;
- per time: `per_second`, `per_turn`, `per_idle_second`, `per_moving_second`,
  `per_running_second`;
- negative numbers drain; fractions carry over until they make a whole point;
- `blocked_by_tags`: the rule does nothing while the holder has a status with one of these
  tags;
- `levels`: points → status. The status of the highest level reached is held ("rank 3 at 75
  points").

`KitGauges` (`src/gameplay/combat/powers/kit_gauges.gd`) runs the rules; `PowerSet` feeds it
time, hits, dodges, kills, moves and spending. A power spends the gauge through its skill's
`cost_pool` and `cost`, and can demand it be full enough with `requires_pool` +
`requires_fraction`. The HUD shows every kit gauge ("KAGUNE 0 / 100").

## 9. Forms (stances, transformations, weapon modes)

A form is the mechanism both Arima and Eto are built around. Data: `FormMechanism`. Runs:
`FormRun`.

- **A form IS its status.** Entering puts `status` on; leaving takes it off. `FormRun` reads
  "am I in this form?" back from the statuses every time (`_sync`), so a cure, a dispel or a
  timed status running out ends the form with no extra wiring, and a save keeps it.
- **Toggle:** a plain form is entered by using its power and left by using it again.
- **Cycle:** `cycle` lists stages, each a form of its own (own status, own chain, own look).
  Each use moves to the next stage and wraps round. Arima's quinque switch and Eto's Kakuja
  Shift are cycles.
- **`exclusive_group`:** entering a form leaves every other form of the same group.
- **What a form changes:** its status's `modifiers` (Eto's kakuja: attack ×1.2), its
  `attack_chain` and `dodge` in the field (handed over through the executor hook `moves`,
  read by `ActionFighter.current_moves`), its `look`, its `name_key`, its battle `commands`
  and `replaces_attack`, and its `passive_skills` (lent only while held).
- **Costs:** the power's `requires_pool`/`requires_fraction` to enter; `drain_pool` with
  `drain_per_second`, `drain_per_turn` or `drain_per_action` while held; the form ends at an
  empty pool. `aftermath` is a status put on when it ends by its own rules (the price of a
  transformation).
- **Per-form slots:** a power with `requires_statuses` = [a form status of this kit] only takes
  a quick slot while that form is held (section 3, step 3).

## 10. The other mechanisms, and the hook each one uses

Every executor extends `PowerExecutor` and overrides only the hooks it needs. Knowing the hooks
tells you what a new mechanism could do:

| Hook | Called by | When |
|---|---|---|
| `use` | `PowerUse.use` | the power was used, after its skill landed |
| `tick` | `PowerSet._count_down` | time passed: seconds in the field, 1 per battle turn |
| `power_used` | `PowerSet.used` | any power of the kit was used |
| `moves` | `PowerSet.moves_over` | the field asks which chain and dodge to play |
| `moved` | `PowerSet.moved` | the fighter started a move (not the dodge) |
| `intercept_incoming` | `PowerGuard.incoming` ← `Combatant.receive` | a hit is about to land on the holder or an ally |
| `projectile_landed` | `BarrageRun` | a barrage shot ended without striking |
| `end` | `PowerSet.unequip` | the kit came off |

The built-in mechanisms (the table that maps them is `PowerMechanisms.BUILT_IN`):

| `kind` | Data class | What it does, in one line | Main hooks |
|---|---|---|---|
| `form` | `FormMechanism` | stance, cycle, transformation (section 9) | use, tick, moves, moved, power_used |
| `barrier` | `BarrierMechanism` (extends form) | NULLIFY, REDUCE by `factor`, or TIMED_BLOCK hits; upkeep is the form's drain | intercept_incoming |
| `barrage` | `BarrageMechanism` | `count` shots (`shots` moves) from a `pattern`, every `interval`, homing by `turn_rate` | use, tick |
| `plant` | `PlantMechanism` | traps left behind, set off REMOTE, PROXIMITY, TIMER or ON_HIT | use, tick, projectile_landed |
| `finisher` | `FinisherMechanism` | charge, a frozen flourish, then the big `strike`; can empty a gauge | use, tick |
| `battlefield` | `BattlefieldMechanism` | a domain, terrain or weather: `effects` on who stands in `radius` | use, tick |
| `blink` | `BlinkMechanism` | teleport TARGET, BEHIND_TARGET, FORWARD, UP or SWAP; optional `path_strike` | use |
| `sacrifice` | `SacrificeMechanism` | take a `fraction` of allies' hp (and buffs) to grow | use |
| `refresh` | `RefreshMechanism` | cut cooldowns, fill a pool, a speed status | use |
| `foresight` | `ForesightMechanism` | rewrite hits (`dodge`, `force`), `observe`, `reveal` | use, and `Foresight.rewrite` in `Combatant.hit` |
| `command` | `CommandMechanism` | OBEY, STOP, FORGET or FALL a foe in sight | use |
| `grant` | `GrantMechanism` | give allies statuses or lend them a whole kit for `lasts` | use, tick |
| (a stat) | `time_rate` | `FighterTime`: a fighter runs at 1 + it (0 stopped, 0.5 half); a time stop is a status with ADD -1 (SECONDS) on every fighter but the user, a haste ADD +0.5. Statuses still count on the fight's clock | — |
| `rewind` | `RewindMechanism` | the user's place and hp go back to `back` seconds ago (a battle: turns, hp only); never raises the fallen | use, tick |
| (a status) | `StatusEffect.seals` | each entry a power id or a `Power.tags` label; while held, those powers are refused (SEALED) | — |
| `copy` | `CopyMechanism` | remembers the last power another fighter used (`suffered_only`: used on the user) and lends it for `lasts` | use, tick, end |
| `steal` | `StealMechanism` | the targets' statuses tagged `tag` move to the user, at most `most` | use |
| `random` | `RandomMechanism` | each use runs one of `powers` (skill and mechanism), free | use, tick, moved, end |
| `construct` | `ConstructMechanism` | a solid wall (`ArenaThing.solid`) `distance` in front: stops bodies, swings and shots, breakable (`hp`); `lifetime`, `cap`, `upkeep` points/s of `upkeep_pool`; field only | use, tick, end |
| `wield` | `WieldMechanism` | lends `moves`, `element` and `bonuses` for `lasts` (s or turns), then restores what was there | use, tick, end |
| `doors` | `DoorsMechanism` | two `LinkedDoor`s `ahead` of the user; a body stepping into one comes out of the other `exit` m out; the user's side only unless `anyone`; `lifetime` | use, tick, end |
| `clone` | `CloneMechanism` | a `CloneGhost` walks the user's path `delay` s behind and replays each move (not the dodge) at `power_fraction`, for `lifetime` s; cannot be hit; in a battle the next `actions` turns hurt twice (the second at `power_fraction`) | use, moved, end |
| `summon` | `SummonMechanism` | `fighters` (each with its `brains` entry) appear beside the user, on its side, as `OwnedFighter`s; `lifetime`, `cap`, `owner_status`, `untouchable`, `moves_each`, `linked_hp` (a share of their hurt is the user's), `saved` (the count survives an area change or a load); in a battle they join its sides for `turns` of the user's turns | use, tick, end |

A summon is an `ActionEnemy` whose side is its owner's and whose home is its owner, so it
follows and fights with no new brain. Pair `owner_status` with another power's
`forbids_statuses` for "only while no helper is out", or `requires_statuses` for "only while
one is".

The counter stance (M13) has no class: it is a form or a timed barrier whose status has the
COUNTER reaction and a `counter_move`.

**The smallest executor to copy** when you write a new one is `refresh_run.gd` (one `use`, no
state). The registry line is one entry in `PowerMechanisms.BUILT_IN`. The cookbook's last
section lists every step.

## 11. Passives

A `PassiveSkill` (`data/passives/<name>.tres`) has two halves:
- `held`: a status held for as long as the passive is (duration 0). Eto's `kakuja_regen` is a
  status that ticks `hp` +5.
- `triggers`: each waits for an `Event` (FIGHT_START, HIT_DEALT, HIT_TAKEN, KILL, DODGE,
  HP_BELOW, FORM_ENTERED, SKILL_USED, ...), checks `conditions` (POOL_SHARE, HOLDS_TAG,
  TARGET_HOLDS_TAG, WEARING, ALONE, ...) and a `chance`, then does `effects` (POOL_FLAT,
  POOL_SHARE, POOL_FROM_DAMAGE, GIVE_STATUS, CURE, SCALE_HIT, SURVIVE, EXTRA_HIT, COOLDOWN_CUT,
  BREAK_PIECE) on SELF, OTHER, ALLIES or FOES. `cooldown`, `limit` and `interval` pace it.

A passive can be held three ways: listed on the fighter (`CombatantDef.passives`), on the kit
(`PowerKit.passive_skills`, held always while the kit is on), or on a form
(`FormMechanism.passive_skills`, held only in that form). Choose by when it should apply.
The full library is in [`PASSIVES.md`](PASSIVES.md).

## 12. Arima and Eto, taken apart

Both were made by the converter (`tools/mugen_build.gd`) from a choices file, so they share one
shape. Learn this shape and you can build most melee heroes:

```
kit
├── stat_bonuses: max_<gauge> = 100, start_<gauge> = 0
├── gauges: one GaugeRule (+N on a hit dealt, +M on a hit taken)
├── passive_skills: picked from data/passives/
└── powers (kit order = slot order)
    ├── slot 1: the stance switch — a FormMechanism cycle, cooldown 1 s
    │     stage A: status/form_<name>_<a> (+ modifiers), attack_chain A, look A
    │     stage B: status/form_<name>_<b> (+ modifiers), attack_chain B, look B (a tint)
    ├── specials of stance A: requires_statuses [form A]
    │     skill: SELF, cost from the gauge, the shared 2 s "resolve" buff (defence ×1.2)
    │     move: the M.U.G.E.N state's timing, hitbox, i-frames, sounds, shakes
    └── specials of stance B: requires_statuses [form B], built the same way
```

| | Arima (`data/powers/arima.tres`) | Eto (`data/powers/yoshimura_eto.tres`) |
|---|---|---|
| Gauge | `focus` | `kagune` (+4 hit dealt, +3 hit taken) |
| Slot 1 | quinque switch: IXA ↔ Owl | Kakuja Shift: kagune ↔ kakuja (attack ×1.2, tint) |
| Stance A specials | IXA Throw, Narukami Pincer, Narukami Squad | Air Strike (17), Bronze Tree (17) |
| Stance B specials | Owl Slash, Owl Flower, Owl Call | Air Fall (25, 8 s), One-Eyed Owl (7) |
| Passives | `reaper`, `counter` | `kakuja_regen`, `kakuja_hunger`, `night_owl` |

What each piece teaches, so you can reuse it:
- **The stance cycle** = how to give a hero two (or more) fighting styles, each with its own
  basic combo, look and set of specials, on one key.
- **`requires_statuses` on a form status** = how to swap the whole slot bar per style.
- **The gauge + `cost_pool`** = a meter that fills by fighting and pays for specials.
- **The cost-only SELF skill** = how a power pays without needing a target in reach.
- **The move's i-frames** (Eto's 500: 0.48–0.68 s; 2600: 0–1.75 s) = a special that is also
  an escape.
- **`travel_speed` on the move** = a lunge that closes distance.

## 13. Traps found while writing this

1. **Converted specials do no damage in a turn-based battle.** Their damage is in the `move`,
   and a battle never plays moves (section 4). There, Air Strike only buffs Eto. This breaks
   rule 4 in `POWERS.md` ("every power works in all three formulas"). Don't fix it by giving
   the skill ENEMY power: in the field the skill lands at once AND the move's hitbox hits
   again, so the special would hit twice. The fix needs a rule ("in a battle, a power whose
   skill has no power strikes with its move's numbers"), and it is on the follow-up list.
2. **A kit's `passive_skills` are held in every stance.** Eto's `kakuja_regen` heals her in her
   human stance too. A passive meant for one form belongs on that form's `passive_skills`.
3. **A skill must do something** (`Skill.problems`): a cost-only skill needs at least a status.
   That is why the converter adds the shared "resolve" buff (C9.10).
4. **An ENEMY-target power is refused with nobody within 8 m**, even if its move would have
   reached further. Use a SELF skill when the move does the hitting.
5. **Before the first stance press, a cycle form is off.** The fighter plays the loadout's own
   chain, and every power that needs a form status is hidden from the slots.
6. **A `Curve` tops out at 1** unless you raise its `max_value`. A CLOCK_CURVE scaling above
   ×1 silently does nothing otherwise.
7. **A status that skips turns (SKIP_TURN) with no duration** is refused by `problems()`,
   because it would stall a battle forever.
8. **Walls stop hits, but only walls on `WORLD` or `SIGHT_BLOCKER`** (C9.12, `CombatSight`).
   Before a hit lands, a ray runs from 0.8 m above the attacker's feet (or from the shot or the
   blast itself) to 0.8 m above the target's feet. Anything on those two layers in between
   blocks the hit: a wall, a closed gate, a thin fence. Anything lower than 0.8 m (a step, a low
   crate) does not. To let hits through something you can see through (bars, glass), put it on
   another layer. The same check:
   - stops a shot at the wall, where it reports `landed`;
   - stops a blink short of the wall, and cancels a swap across one;
   - makes a move-event shot start on the near side of the wall;
   - keeps a field command, or a power that finds its own foe, from aiming at anyone behind
     one.
   A barrage that spawns its shots around the target (in a ring, or from the sky) can still
   spawn them past a wall; they hit if nothing stands between the spawn point and the foe.
9. **A fighter's own lunge or roll stops at a ledge** (no floor within 1.2 m below, 0.6 m
   ahead). A knockback does not stop there: being knocked off an edge is allowed, and
   `FallNet` deals with the fall.

## 14. Where to look when something does not work

| Symptom | Look at |
|---|---|
| The key does nothing | `PowerUse.refusal` returns a `Reason`; the HUD shows it. In a probe, print `PowerUse.refusal(me, power)` |
| The power is not on any key | `PowerSlots.powers` — is it the 5th or later power, or does it need a form you are not in? |
| The move plays but never hits | `hitbox_size` and `hitbox_offset` (forward is −z), `active` > 0, the foe within the box, and no wall between (trap 8) |
| It hits but for little | the formula in section 5: the target's `defence`, weaknesses, the attacker's `attack` |
| A form does not change the combo | the stage's `attack_chain`; `ActionFighter.current_moves` → `PowerSet.moves_over` |
| A gauge never fills | the kit's `max_<pool>` bonus exists, and the `GaugeRule.pool` name matches exactly |
| A buff never ends | `duration` 0 means forever; `unit` must match the formula's time |
| Anything at all | `godot --headless --script tools/check_content.gd` lists every `problems()` in every file |

To see what a kit really does, run `tools/kit_probe/` (cookbook § 6): it presses every slot
in every style against a dummy foe and prints the damage, the gauges and every refusal.
Measured on 2026-11-15, every special of Eto and Arima lands except Arima's Narukami Pincer
(0 damage: its lightning is a M.U.G.E.N helper the converter does not fly yet).
