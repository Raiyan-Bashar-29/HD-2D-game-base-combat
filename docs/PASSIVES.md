# Passives, armours and kakujas — the design (phase C9)

**Read this before any C9 row.** It is the design that rows C9.1 onward build, written by C9.0
(documents only) on 2026-11-13 at the owner's request:

> make all the abilities that exist as separate passives and then put those under specific
> gears and armours … Last Cloudia follows a great procedure for passive skills … so we can
> just give characters and gears those that are needed, along with main stats and main skills
> … make code for all the kakujas and an armour version of all kakujas too … armours like
> Guts' Berserker armour, the Akame ga Kill armours … HP drain for a buff, insane stat buffs,
> all sorts of combinations, so I can reuse code for armours by changing values.

**The owner's two answers (2026-11-13):** the passive library is built before crafting (C7.6),
and a character has both fixed passives and free passive slots with a skill-cost budget.

**The reference** is in [`reference/mechanics_encyclopedia/`](reference/mechanics_encyclopedia/):
21 games, 248 mechanic rows, 60 boss rows, 20 coding templates. It is a curated snapshot, not
a full database. Its Last Cloudia rows are systems and a few named skills; the 80-row names
file has names only, with no effects. So the catalogue below is built from the mechanic
families, and no line claims to copy a game's exact numbers.

**Marks.** *(source)* means the source work or the reference says it. *(reading)* means it is
my reading of how to turn it into rules. *(to confirm)* means I am not sure the source says
it, and the row that builds it checks.

**Contents:** the rules in one screen · what the engine already runs · the passive (the
shapes) · the catalogue · the loadout · armour functions · the armour table · the kakujas ·
board rows · Renaming.

## The rules in one screen

1. **One ability, one file.** A passive is a `PassiveSkill` file at
   `data/passives/<name>.tres`. A character's kit, a piece of gear, a set tier, a gem and an
   upgrade level each LIST the passives they give. Nothing copies a passive's rules.
2. **A passive is data: when, if, what.** WHEN is an event (a hit lands, the battle starts).
   IF is a list of conditions (below half HP, the target is a dragon). WHAT is a list of
   effects (heal, give a status, hit again). Every number is a field, so a new passive is a
   new file with other numbers.
3. **Use what is there first.** An always-on stat change, a regen, a drain, a counter, a
   reflect and a resistance already work through `StatusEffect` and need no new code. The new
   code is only the event-and-effect part.
4. **It works in all three formulas.** Every event has a meaning in a turn-based battle and in
   the field. A passive that works in only one is not accepted.
5. **Enemies can hold passives too**, through the same lists.
6. **An armour is a piece of gear whose kit and passives do the work.** There is no
   armour-only code. A drawback (HP drain, cannot be healed, cannot be taken off) is a passive
   too, so a strong armour is strong passives plus drawback passives.
7. **A kakuja is a form, and its armour version is a piece.** Both list passives from the same
   library. The armour version gives a smaller, safer share.
8. **No code names a game's passive, armour or kakuja.** Names live in `data/`, the CSV and
   these documents.

## What the engine already runs

These need no new code. A passive file wraps them (C9.3).

| The idea | Runs today through |
|---|---|
| A flat or percentage stat boost | `StatusEffect.modifiers` (`StatModifier` ADD, MULTIPLY, OVERRIDE) |
| Damage dealt or taken up or down | The stats `damage_dealt` and `damage_taken` |
| Resistance to an element, an ailment or a battlefield | `resist_<element>`, `resist_<status>`, `resist_field_<kind>` |
| No flinch, no knock-back | `knockback_taken`, `poise_taken` |
| A skill costs less | `cost_mult_<pool>` |
| Regen, or a drain, each second or turn | `StatusEffect.tick_pool`, `tick_change`, `tick_interval` |
| Counter-attack, reflect | `StatusEffect.reactions` (COUNTER, REFLECT), `reaction_chance` |
| Never miss; hits carry a tag | `grants_sure_hit`, `grants_hit_tags` |
| A gauge that fills on hits, kills, dodges, time | `GaugeRule` in a kit (`on_hit_dealt`, `on_kill`, …), with `levels` giving a status |
| A power stronger at low HP, at night, against a tagged target | `PowerScaling` |
| A transformation with a draining pool | `FormMechanism` (C6.5) |
| A barrier that absorbs, reduces or nullifies | `BarrierMechanism` (C6.8) |
| A piece that cannot come off | `GearDefinition.cursed` (C7.4a) |
| A set bonus, a gem, an upgrade level | C7.4b, C7.4c, C7.5 |

What is missing is the reference's template R001, "an event checks its listeners": a passive
that WAITS for something and then DOES something once. That is C9.1 and C9.2.

## The passive (the shapes)

All under `src/content/combat/passives/`. *(reading, from templates R001, R003, R014, R018,
R019 and R020 of the reference.)*

**`PassiveSkill`** (one per passive, `data/passives/<name>.tres`, id `passive/<name>`, found by
`PassiveDb`):

| Field | Meaning |
|---|---|
| `name_key`, `desc_key` | Its name and one line of what it does |
| `cost` | Skill cost: what it takes from a character's loadout budget (§ The loadout). 0 for one that is never chosen freely |
| `held` | A `StatusEffect` the holder has for as long as the passive is held: the always-on part (stat changes, regen, drain, counter) |
| `triggers` | A list of `PassiveTrigger`s: the waits-then-does part |
| `gauges` | `GaugeRule`s, as a kit has |
| `group`, `rank` | Passives sharing a `group` do not add up: the highest `rank` held wins (two copies of "attack up", one large and one small) |
| `tags` | For filters and screens: `offence`, `defence`, `drawback`, `kakuja` and so on |

**`PassiveTrigger`:**

| Field | Meaning |
|---|---|
| `event` | When it wakes (the table below) |
| `chance` | 0 to 1; rolled with the fight's own random numbers |
| `conditions` | A list of `PassiveCondition`s; all must hold |
| `effects` | A list of `PassiveEffect`s, run in order |
| `cooldown` | Seconds in the field, turns in a battle, before it can wake again |
| `limit` | How many times per battle (per area in the field). 0 means no limit |

**Events** (each with its meaning in a battle and in the field):

| Event | Wakes when |
|---|---|
| `FIGHT_START` | A battle begins; in the field, when the holder enters an area or a fight starts near it |
| `FIGHT_WON` | A battle is won; in the field, the last foe near the holder falls ("wave end") |
| `TURN_START` | The holder's turn begins; in the field, every `interval` seconds |
| `HIT_DEALT`, `HIT_TAKEN` | A hit by, or on, the holder lands (after the damage is known) |
| `CRIT_DEALT` | A hit by the holder was critical |
| `KILL` | A foe falls to the holder |
| `ALLY_DEFEATED` | An ally of the holder falls |
| `DODGE`, `GUARD` | The holder dodges; a barrier or a guard of the holder absorbs a hit |
| `HP_BELOW`, `HP_ABOVE` | The holder's HP share crosses a line (`threshold` on the trigger); once per crossing |
| `LETHAL_HIT` | A hit would take the holder to 0 HP (before it does) |
| `SKILL_USED` | The holder uses a skill or a power (a `tag` filter narrows it) |
| `STATUS_GAINED` | A status with a named tag lands on the holder |
| `FORM_ENTERED`, `FORM_LEFT` | A transformation of the holder starts or ends |

**`PassiveCondition`** (one check, with `kind` and its fields; `negate` flips it):

| Kind | True when |
|---|---|
| `HP_SHARE` | The holder's HP share is within `min` to `max` |
| `POOL_SHARE` | The holder's `pool` is within `min` to `max` full |
| `HOLDS_TAG`, `TARGET_HOLDS_TAG` | The holder, or the other fighter in the event, holds a status tagged `tag` |
| `TARGET_KIND` | The other fighter's definition carries `tag` (a species: dragon, ghoul, undead). The "killer" check |
| `HIT_TAG`, `HIT_ELEMENT` | The hit in the event carries `tag`, or is of `element` |
| `WEARING` | The holder wears the piece or the gear type `tag` |
| `ALONE`, `ALLIES_STANDING` | The holder is the last one standing; at least `min` allies stand |
| `FORMULA` | The fight is turn-based, action or hybrid |
| `HOUR` | The clock is within `min` to `max` hours |

**`PassiveEffect`** (one action, with `kind`, a `target` and its fields):

| Kind | Does |
|---|---|
| `POOL_FLAT`, `POOL_SHARE` | Changes `pool` by an amount, or by a share of its maximum |
| `POOL_FROM_DAMAGE` | Changes `pool` by a share of the damage in the event (life steal, MP from hits) |
| `GIVE_STATUS` | Gives a `StatusEffect` (a timed buff, an ailment), with `stacks`; with `per_element`, the one listed for the hit's element |
| `CURE` | Takes off statuses tagged `tag` |
| `EXTRA_HIT` | Lands a `Skill` on the target at `power_scale` (a pursuit hit, a second weapon) |
| `SURVIVE` | In `LETHAL_HIT` only: the holder is left at `leave_hp` and the hit is spent |
| `SCALE_HIT` | In `HIT_DEALT` or `HIT_TAKEN` only, before the damage is applied: multiplies it (a guard proc, a killer bonus, a crit bonus) |
| `BREAK_PIECE` | Takes off and removes the piece that gave the passive (a trump card that costs the armour) |
| `COOLDOWN_CUT` | Shortens the holder's power cooldowns by an amount or a share |

`target` is SELF, OTHER (the other fighter in the event), ALLIES or FOES.

**Who holds what.** Every source hands its passives to one runner on the fighter,
`PassiveSet` (gameplay), each under its own source name, exactly as `PowerSet.lend` holds kits:

| Source | Listed on | Held under |
|---|---|---|
| The character | `CombatantDef.passives` | `own` |
| A kit, a form | `PowerKit.passive_skills`; a form's status | `kit/<kit id>` |
| A piece of gear | `GearDefinition.passives` (the field C7.3 dropped comes back with this meaning) | `gear/<item id>` |
| A set tier, a gem, an upgrade level | `GearSetTier`, `GemDefinition`, `UpgradeLevel` | `set/…`, `gems`, `upgrades` |
| The loadout | Chosen by the player (§ The loadout) | `loadout` |

`PassiveSet` listens to the fight's events once, asks each held trigger, and applies the
`group` rule. `PowerKit.passives` (plain statuses) stays as it is.

**The order inside one hit** *(reading, from template R004)*: the hit is rolled; `SCALE_HIT`
effects of the attacker, then of the defender, change the damage; barriers absorb;
`LETHAL_HIT` is asked; HP changes; then `HIT_DEALT`, `HIT_TAKEN`, `CRIT_DEALT` and `KILL` wake.
A passive's own `EXTRA_HIT` wakes no `HIT_DEALT` passive, so two passives cannot feed each
other forever.

### As built (C9.1, 0.89.0)

- The four content files are in `src/content/combat/passives/`; the runner is
  `src/gameplay/combat/passives/passive_set.gd`, with `passive_effects.gd` beside it.
- Built so far: `held`, `triggers`, `cost`, `tags`; the seven events FIGHT_START, FIGHT_WON,
  TURN_START, HIT_DEALT, HIT_TAKEN, KILL, ALLY_DEFEATED; the effects POOL_FLAT, POOL_SHARE,
  POOL_FROM_DAMAGE, GIVE_STATUS, CURE. The only source is `CombatantDef.passives` (held under
  `own`); `hold(source, list)` and `release(source)` are ready for kits and gear (C9.3).
- A trigger also has `interval`: in the field, the seconds that stand for one turn.
- A cooldown counts down as the holder's turn begins, before that turn's triggers, so a
  cooldown of 2 wakes every second turn.
- FIGHT_WON wakes when the last standing foe of the holder falls. In the field, only fighters
  within 20 metres (`PassiveEffects.NEAR`) count as its allies and foes.
- A pool effect changes the pool directly, not as a hit, so it wakes no other passive.
- A fallen holder's passives do nothing.
- Not built yet: `gauges`, and the effects and events of C9.2b.

### As built (C9.2a, 0.90.0)

- `PassiveCondition` kinds: POOL_SHARE (HP_SHARE is this with pool `hp`), HOLDS_TAG,
  TARGET_HOLDS_TAG, TARGET_TRAIT (the design's TARGET_KIND; a fighter's species are
  `CombatantDef.traits`), WEARING, ALONE, ALLIES_STANDING (`count`), IN_FIELD (the design's
  FORMULA; negate it for a turn-based battle), HOUR (`low` above `high` crosses midnight).
  `PassiveConditions.all` answers them. HIT_TAG and HIT_ELEMENT wait for C9.2b.
- A trigger kept asleep by a condition spends neither its cooldown nor its limit.
- New events: CRIT_DEALT (after HIT_DEALT), DODGE (i-frames, field only), GUARD (a hit stopped
  whole by a barrier or a perfect block), HP_BELOW and HP_ABOVE (`threshold`, once per
  crossing), STATUS_GAINED (`tag`, empty for any status).
- A status given by one of the set's own effects wakes no STATUS_GAINED.
- `group` and `rank`: `PassiveSet.passives()` returns only the highest rank of each group; the
  lower one's held status comes off and returns when the higher one is released.
- A field body's set sleeps from `battle_started` to `battle_ended` (or the next area).
- Not built yet (C9.2b): SCALE_HIT, SURVIVE with LETHAL_HIT, EXTRA_HIT, COOLDOWN_CUT,
  BREAK_PIECE, SKILL_USED, FORM_ENTERED, FORM_LEFT.

### As built (C9.2b, 0.91.0)

- `PassiveHits` (gameplay) sits in `Combatant.receive`. `scale` runs before the barriers,
  `lethal` after them and before the HP changes. The hit landing is `PassiveHits.now`.
- An EARLY trigger wakes before the hit lands and not after: every LETHAL_HIT trigger, and any
  HIT_DEALT, CRIT_DEALT or HIT_TAKEN trigger holding a SCALE_HIT effect. All its effects run
  then; the damage they see is the hit's amount so far.
- SCALE_HIT multiplies the hit by `amount`. Order: the attacker's HIT_DEALT, its CRIT_DEALT,
  then the target's HIT_TAKEN.
- SURVIVE (LETHAL_HIT only) cuts the hit so the holder is left at `leave` HP (default 1). Give
  the trigger a `limit` for "once per battle".
- EXTRA_HIT lands `skill` (its power times `amount`, its element, tags and sure-hit) on each
  target as a real hit by the holder. It wakes none of the holder's own HIT_DEALT or
  CRIT_DEALT triggers; the target's HIT_TAKEN triggers do wake.
- A trigger never wakes inside itself, so two counters answer each other once and stop.
- HIT_TAG and HIT_ELEMENT (the element's name goes in `tag`) read the hit landing.
- A heal and a hit on oneself are not scaled and are never lethal.
- Not built yet: SKILL_USED, FORM_ENTERED, FORM_LEFT, COOLDOWN_CUT (C9.2c); BREAK_PIECE (C9.5).

### As built (C9.2c, 0.92.0)

- `PassiveMoments` (gameplay) carries the moments no signal does. `SkillUse.apply` and
  `PowerUse.use` call `skill`; a `FormRun` calls `form`.
- SKILL_USED wakes once per use, before the skill lands. `tag`, when set, must be one of the
  skill's tags. A power with no skill has no tags. A counter, a reflect and a passive's own
  EXTRA_HIT are not uses.
- FORM_ENTERED and FORM_LEFT wake when the holder goes into or out of a form. A change of
  stage in a cycle is neither. A form taken off from outside (a cure) is heard when the form
  is next read (its next tick or use).
- COOLDOWN_CUT: each power cooldown of the target loses `share` of what is left, then `amount`
  (turns or seconds), through `PowerSet.cut_cooldowns`. On SKILL_USED it runs before the used
  power's own cooldown starts, so it shortens the others, not that one.
- BREAK_PIECE came in C9.5b.

### As built (C9.3a, 0.93.0)

- `PassiveLending` (gameplay) is the one place a source gives its list. The source names:
  `own`, `kit/<the kit's source>` (the fighter's own kit is `kit/<kit id>`, one lent by a piece
  `kit/gear_kit/<item id>`), `gear/<item id>`, `set/<set id>/<pieces>`, `gems`, `upgrades`.
- `PowerSet` gives a kit's `passive_skills` when the kit goes on and takes them back when it
  comes off. `GearLending` calls `PassiveLending.gear` after every change to what is worn.
- A fighter with no passive has no `PassiveSet`; the first source with one makes it.
- A refresh of the gear keeps each trigger's cooldown and count.
- A gem that gives only a passive is sound.
- Not built yet: the sample files (C9.3b); a form stage has no passive list of its own (use a
  FORM_ENTERED trigger, or the form's status); the `loadout` source (C9.4).

### As built (C9.3b, 0.94.0)

- `data/passives/` has 22 sample files, one per row of the catalogue below: `strength_up`,
  `ailment_ward`, `regen`, `counter`, `thrift`, `opening_guard`, `victory_rest`, `life_steal`,
  `weakening_blows`, `reaper`, `avenging_spirit`, `adversity`, `full_vigour`, `dragon_killer`,
  `vital_aim`, `steady_guard` (with its two riders), `iron_will`, `flame_saber`, `last_stand`,
  `night_owl`, `clear_mind`, `skill_haste`.
- A held status is written inside its passive's file, with the id `status/passive_<name>`. A
  timed status a passive gives is its own file in `data/statuses/` (`battle_fury`, `desperation`).
- "Last stand" and "day or night" are a `TURN_START` trigger with an `ALONE` or `HOUR`
  condition giving a short buff each turn, because a held status has no condition.
- `tools/check_content.gd` fails a broken passive, and one whose name or description is not
  in the CSV. `tests/unit/passive_library_test.gd` holds the whole library on one fighter.

### As built (C9.4, 0.95.0)

- `PassiveLoadout` (gameplay, static) owns what is learned and chosen. `teach`, `knows`,
  `known`; `choose`, `drop`, `chosen`; `budget(def)`, `spent(who)`; `refusal` and
  `refusal_key`; `practise(who)` and `progress`.
- The chosen passives are held under the source `loadout`. `PassiveLending.gear` refits them
  for a saved fighter, so they are on when the fighter is built, after a load, and gone after
  a new game.
- `GearDefinition.teaches` is a list of `PassiveLesson` (`passive`, `fights`). `Rewards.give`
  calls `practise` for each rewarded member, after a battle and after a field kill, and
  `Rewards.learned` says what was learned. A taught passive must be a file `PassiveDb` finds.
- Refusals in order: no such passive, not learned, already chosen, same group (any source),
  over budget. A level never goes down, so a refit does not check the budget again.
- The screen (C9.7, built): press L in the field. `LoadoutScreen` lists chosen and learned
  passives, lessons in progress and what is held from gear and powers. No demo gear teaches anything, because the demo has no gear.

### As built (C9.5a, 0.96.0)

- `HitGuard` (gameplay, static) stands in `Combatant.receive` before the barriers.
- Invincible: a status with `invincible` on. A hit is announced as blocked; a hit carrying one
  of the status's `pierced_by` tags goes through. Heals and status ticks still land.
- Mercy time: the stat `mercy_time` (seconds in the field, the fighter's own turns in a
  battle). After a hit that took something, hits do nothing for that long.
- Overshield: the stat `max_overshield` makes the pool `overshield`. A hit empties it first.
  It refills by `overshield_regen` a second (or turn) once `overshield_delay` has passed
  with no hit. This is the "recharging second health layer" row; aggro and taunt are `Aggro` (C8.6, done).
- `healing_taken`: `Vitals.change` multiplies a rise of the defeat pool by 1 plus the stat,
  so -1 is "cannot be healed". `set_to` and `revive` are not scaled.
- Not built yet: no HUD bar for the overshield; an invincible fighter can still be given a
  status; the three clocks are not saved.

### As built (C9.5b, 0.97.0)

- `BREAK_PIECE`: `GearBreak.giver` finds the source of the effect. A worn piece (`gear/<item
  id>`) comes off, cursed or not, and leaves the bag and a foe's starting gear. Any other
  source breaks nothing.
- `SKILL_DONE`: `SKILL_USED`'s twin, told after the skill's strikes, with the same `tag`
  filter. A trump card is a tagged skill of the piece's kit, and a passive on the piece:
  `SKILL_DONE` (that tag) → `BREAK_PIECE`.
- Adapting: a `GIVE_STATUS` with `per_element` filled gives the status listed for the element
  of the hit landing now. `HIT_TAKEN` → that effect is "adapts to what hit it".
- Not built yet: a power with no skill tells no `SKILL_DONE`; the gems in a broken piece are
  lost with it; nothing on screen says a piece broke.

### As built (C9.5c, 0.98.0)

- Berserk is a status with `takeover` set to a `BattleBrain`. While held, that brain plays
  the holder. A brain with no entries attacks the first foe.
- In a battle, `Battle.brain_of` returns it first, for a party member and a foe alike, so the
  player gets no menu on that turn.
- In the field, the player's fighter swings without stopping, cannot dodge and can use no
  command; a party follower thinks with the brain.
- "Takes the wearer over at the top" is a gauge level whose status is such a status.
- Not built yet: a field enemy (`ActionEnemy`) is not taken over; the brain aims as its
  entries say, so berserk does not turn the holder on its allies; the player still walks.

### As built (C9.5d, 0.99.0)

- `UpgradeLevel.fights`: above 0, the level is won by that many won fights while the piece is
  worn, and cannot be bought (`GearUpgrades.refusal` says `EARNED`). A level has `items` or
  `fights`, never both.
- `GearUpgrades.practise(who)` counts one won fight for every such piece `who` wears, in
  `Flags` under `upgrade_fights/<piece item id>`. At the number the piece goes up and the
  count starts again. `Rewards.give` calls it, and `Rewards.upgraded` lists what went up.
- Not built: a screen line for the count or for a piece that went up.

### As built (C9.6a, 0.100.0)

- `FormMechanism.passive_skills`: the passives held while the form is held. A cycle stage
  with none lends the cycle's (`passives_at`).
- `FormRun` lends them under `form/<power id>` (`PassiveLending.form`) before the holder's
  passives hear FORM_ENTERED, and takes them back after FORM_LEFT. Every way a form ends
  gives them back: used again, drained dry, cured from outside, the kit coming off.
- The shared kakuja passives are files in `data/passives/`: `kakuja_shell` (damage taken
  -25%, no flinch), `kakuja_regen` (5 HP a turn), `kakuja_hunger` (a kill refills a quarter
  of the `rc` pool), `frenzy` (attack x1.3, the fighter attacks on its own) and
  `quinque_feed` (lose 2 HP a turn).
- Not built: limb regrowth; the kakuja forms and armours themselves (C9.6b).

### As built (C9.6b, 0.101.0)

- `PowerKitDb` loads every kit in `data/powers/` and checks it. The file `<name>.tres` must
  declare `kit_id` `kit/<name>`, and a form's `drain_pool` must be given by the kit
  (`max_<pool>` in `stat_bonuses`).
- Four kakujas. Each kit gives `max_rc` 100 and one power, a form in the group `kakuja` that
  needs a tenth of the pool to enter and drains 10 RC a turn (2 a second in the field):

  | Kit | The form | Passives lent |
  |---|---|---|
  | `kakuja_centipede` | A cycle. Half: attack x1.15, speed +2. Complete: attack x1.5, speed +3 | Half: `kakuja_regen`, `centipede_bite`, `frenzy`. Complete: `kakuja_shell`, `kakuja_regen`, `kakuja_hunger`, `centipede_bite` |
  | `kakuja_arata` | Defence x1.5 | `kakuja_shell`, `kakuja_regen`, `kakuja_hunger` |
  | `kakuja_jason` | Attack x1.4 (x1.82 with the frenzy) | `kakuja_regen`, `frenzy` |
  | `kakuja_noro` | Max HP x1.3 | `kakuja_regen`, `noro_regrowth` (15 HP a turn), `kakuja_hunger` |

- Four armours (`data/gear/quinque_<name>.tres`, types `quinque_armour` on `body` and
  `quinque_gauntlet` on `hands`), each with `quinque_feed`: Centipede (speed +2, attack x1.1,
  `centipede_bite`), Arata (damage taken -15%, no flinch, defence x1.2), Jason (a gauntlet,
  attack x1.25), Noro (`kakuja_regen` only).
- New passives `centipede_bite` (a hit has a 30% chance of `status/venom`: 3 HP a turn for 3
  turns) and `noro_regrowth`.
- Not built: no fighter in the demo has these kits; the Jason gauntlet has no frenzy risk;
  the other nine kakujas (C9.6c, C9.6d).

### As built (C9.6c, 0.102.0)

Data only. Each kit has `max_rc` 100 and a form in the group `kakuja`, as in C9.6b.

- `kakuja_owl`: defence x1.25, attack x1.2; shell, regen, hunger. `owl_shards`: 6 shots from
  behind the user, usable only in the form (`requires_statuses`), cooldown 2.
- `kakuja_one_eyed_owl`: max HP x1.3, attack x1.3, speed -2, size 1.6, drain 12 a turn; shell,
  regen, `great_regen` (new: 8 HP a turn), hunger. `one_eyed_owl_storm`: 10 shots as rain.
- `kakuja_towl`: attack x1.3, speed +3; regen, hunger. `towl_blast`: 3 heavy homing bolts.
- `kakuja_amon`: attack x1.35, speed -1, drain 15 a turn; regen, frenzy. Attack becomes the
  skill `amon_crush` (power 16, a delay of 2) through `replaces_attack`.
- Armours: `quinque_owl`, `quinque_one_eyed_owl` and `quinque_towl` each lend a kit of the
  same name with one ranged power on a cooldown and no pool; `quinque_amon` gives attack x1.3
  and speed -1. All carry `quinque_feed`.
- Not built: T-Owl's half stage (a cycle's two statuses cannot both gate one power); the
  Owls' blade arms as field chains; a larger feed for the Amon armour.

## The catalogue

Each row is a FAMILY: one file shape, many files with other numbers. "Today" means it needs
only C9.3's wrapper. The examples in brackets are where the idea is best known.

| Family | When · if · what | Built by |
|---|---|---|
| Stat boost (Strength Up, HP Up) | Always: `held.modifiers` | Today |
| Resistance (Curse Resistance, fire ward) | Always: `resist_…` | Today |
| Regen, drain | Always: `held.tick_…` | Today |
| Counter, reflect | Always: `held.reactions` | Today |
| Cost cut, never miss, hit tag | Always: `cost_mult_…`, `grants_…` | Today |
| Opening buff (Auto Brave, Fast Brave) | `FIGHT_START` → `GIVE_STATUS` SELF | C9.1 |
| Wave-end recovery (the Ale skills) | `FIGHT_WON` → `POOL_SHARE` | C9.1 |
| MP or HP from hits (Goddess Kiss, life steal) | `HIT_DEALT`, chance → `POOL_FROM_DAMAGE` | C9.1 |
| On-hit ailment (Curse Research) | `HIT_DEALT`, chance → `GIVE_STATUS` OTHER | C9.1 |
| On-kill gain | `KILL` → `POOL_…` or `GIVE_STATUS` | C9.1 |
| Avenger | `ALLY_DEFEATED` → `GIVE_STATUS` SELF | C9.1 |
| Adversity (stronger when hurt) | `HP_BELOW` → `GIVE_STATUS`; `HP_ABOVE` → `CURE` | C9.2 |
| Full-HP bonus | `HP_SHARE` 1 to 1 on a `SCALE_HIT` | C9.2 |
| Killer (dragon killer, ghoul killer) | `HIT_DEALT`, `TARGET_KIND` → `SCALE_HIT` | C9.2 |
| Critical damage up (Aim: Vitals) | `CRIT_DEALT` → `SCALE_HIT` | C9.2 |
| Guard proc (Guard), with its riders (Heal Guard, Guard Charge) | `HIT_TAKEN`, chance → `SCALE_HIT`; `GUARD` → `POOL_…`, `COOLDOWN_CUT` | C9.2 |
| Guts (survive a lethal hit) | `LETHAL_HIT`, `limit` 1 → `SURVIVE` | C9.2 |
| Pursuit hit (Flame Saber, Dual Wield) | `HIT_DEALT` → `EXTRA_HIT` | C9.2 |
| Last stand | `ALONE` on a held buff | C9.2 |
| Day or night passive | `HOUR` on a held buff | C9.2 |
| Cleanse on turn | `TURN_START` → `CURE` | C9.1 |
| Skill haste (Haste as a passive) | `SKILL_USED` or `FIGHT_START` → `COOLDOWN_CUT` | C9.2 |

## The loadout

*(reading, from the reference's Last Cloudia rows: Skill Cost, Ark learnable skill, Ark
trait.)*

- **Fixed passives** come with the character, its kit, its form and its gear. The player does
  not choose them, and they cost nothing.
- **Free passives** are chosen by the player from the ones the character has LEARNED, into the
  character's loadout, as long as their `cost`s add up to no more than the character's
  budget. `CombatantDef.passive_budget` is the starting budget, and
  `passive_budget_per_level` grows it with the party level.
- **Learning.** A piece of gear, or any item, can TEACH passives: `GearDefinition.teaches`
  lists them with the number of won battles (or defeated field foes) needed while it is worn.
  Once learned, the passive stays learned when the piece comes off. This is the "ark teaches a
  skill" idea, and it gives old gear a reason to be worn. A quest or a pickup can also teach
  one outright.
- **Saved as flags**, as worn gear is: `passive_known/<who>/<passive>`,
  `passive_progress/<who>/<piece>/<passive>` and `passive_slot/<who>/<passive>`.
- **A piece's own passives** (`GearDefinition.passives`) are separate from what it teaches:
  they work only while it is worn, as an ark's trait does.
- **Refusals**, each with words for the screen: not learned, over budget, already held from
  another source in the same `group`.

## Armour functions

Each is a passive, or a few passives together. An armour's file lists them and sets the
numbers. *(All reading, unless marked.)*

| Function | Made of | Built by |
|---|---|---|
| Big stat buff | Stat boost passives | Today |
| HP drain for a buff | A held status: stat boosts and a `tick` that takes HP | Today |
| Drain that grows the longer it is worn | `TURN_START` → `GIVE_STATUS` stacks of a drain status | C9.1 |
| Pain ignored, no flinch | `damage_taken`, `knockback_taken`, `poise_taken` | Today |
| Cannot be healed | A new stat, `healing_taken`, read where a heal lands | C9.5 |
| Cannot be taken off | `cursed` | Today |
| Berserk: the wearer attacks on its own | A status that blocks commands and picks a target by a brain | C9.5 |
| Rage: stronger each time it is hit | `HIT_TAKEN` → `GIVE_STATUS` stacks | C9.1 |
| A recharging second health layer | An overshield pool that refills when not hit for a while | C9.5a (done) |
| Damage cut to a share | `damage_taken` MULTIPLY | Today |
| Breaks to save the wearer once | `LETHAL_HIT` → `SURVIVE`, `BREAK_PIECE` | C9.2 |
| A trump card that costs the armour | A power on the piece's kit whose use ends in `BREAK_PIECE` | C9.5 |
| Evolving: stronger as the fight goes on | A `GaugeRule` with `levels`, each a stronger status | Today |
| Evolving for good | The upgrade track (C7.5), with levels won by fights and not bought | C9.5 |
| Takes the wearer over at the top | A gauge level whose status is the berserk status | C9.5 |
| Invisibility | The unseen status | C8.12 |
| Flight | M9 `blink` UP, a form's moves | C6.12 |
| An armour that is a transformation | A piece whose kit is a `FormMechanism` (Requip, Incursio's summon) | Today |
| Immunity to a battlefield | `resist_field_<kind>` | Today |
| Adapts to what hit it | `HIT_TAKEN` → `GIVE_STATUS` of `resist_<element of the hit>` | C9.5 |
| Regeneration, limb regrowth | Regen, plus `LETHAL_HIT` → `SURVIVE` with a limit | C9.2 |
| Weapons out of the armour | The piece's kit powers, a barrage | Today |

## The armour table (added to `GEAR.md`'s)

`GEAR.md` § The armours keeps its twelve rows. These join them, and C7.10 builds them all as
data after C9.

| Piece | From | Slot | As rules |
|---|---|---|---|
| Incursio | Akame ga Kill | `body`, form | A summoned armour (a form). Invisibility for a short time *(source)*. It EVOLVES to fit its wearer *(source)*: evolving for good. Its last evolutions eat the wearer *(source)*: a drain that grows, and at the top the piece cannot come off |
| Grand Chariot | Akame ga Kill | `body`, form | Made after Incursio, steadier *(source)*. Flight *(source)*, a diving kick finisher, no evolution, no drawback |
| Lionelle | Akame ga Kill | `relic` (a belt), form | A beast form: big physical stats, sharp senses (sees the unseen), strong regen *(source)* |
| Adramelech | Akame ga Kill | `hands` | Lightning gauntlets: a lightning barrage and a stored-charge finisher *(source)*. A pool that hits charge |
| Murasame's trump card | Akame ga Kill | on the weapon | The wielder cuts herself for a huge buff at a lasting cost *(source)*: HP drain for a buff, once per battle |
| Susanoo's Magatama | Akame ga Kill | on a fighter | Three uses in a life *(source)*: a `limit` saved across battles (a flag), each a strong timed form |
| Arata proto | Tokyo Ghoul | `body`, cursed while on | A quinque armour that feeds on its wearer *(source)*: big stats, HP drain |
| Arata proto II, Arata Joker | Tokyo Ghoul | `body` | Later builds: the same buff with a smaller drain *(source: later versions are safer; the numbers are reading)*, a blade arm, auto-guard (a guard proc) |
| Quinque armour, general | Tokyo Ghoul | `body` | Each kakuja below has one. See the next section |

## The kakujas

**From the source.** A kakuja is an armoured kagune grown by a ghoul who eats other ghouls. It
covers the body, makes new weapons, and hits far harder. A HALF-kakuja is unfinished: stronger
still than a kagune, but the user loses control. A kakuja can be made into a quinque, and
Arata, taken from Arata Kirishima, was made into ARMOUR that feeds on the investigator who
wears it.

**As rules.** Each kakuja is three things from one library:

1. **The form** (M5 `form`, on the character's kit, C6.5): its look, its moves, its powers,
   and its passives, while a pool drains.
2. **The half form**, where the source has one: the same passives at smaller numbers, plus the
   drawback passive `frenzy` (berserk: the user attacks on its own, C9.5).
3. **The armour version** (a quinque armour, a `body` piece, C9.6): a share of the same
   passives at about half the numbers, no moves of its own, and a drain on the wearer in
   place of the frenzy. *(Reading: only Arata is an armour in the source. The owner asked for
   one of each.)*

Shared kakuja passives, in the library once: `kakuja_shell` (damage taken down, no flinch),
`kakuja_regen` (regen, and limb regrowth), `kakuja_hunger` (the pool drains; refilled by
kills), `frenzy`, `quinque_feed` (the armour's HP drain).

| Kakuja | User | Its own part as rules | Armour version |
|---|---|---|---|
| Centipede | Ken Kaneki | Half first *(source)*: long centipede tails, a fast multi-hit chain, a poison-like bite (an on-hit ailment). Later complete, with no frenzy | Light: speed and chain hits, small drain |
| One-Eyed Owl | Eto Yoshimura | Huge body *(source)*: a second, larger hitbox form, shard barrage (M2), blade arms, great regen | Heavy: the barrage and the shell, slow |
| Owl (the Non-Killing Owl) | Yoshimura | Blade arms and a shard barrage, smaller than Eto's *(source)* | Balanced: shell and one ranged power. The quinque side is already `item/owl` in `GEAR.md` |
| Arata | Arata Kirishima | Full-body armour, strong shell *(source)* | The Arata proto row above: the one from the source |
| Jason | Yakumo Oomori | Half *(source)*: one armoured arm and a mask, strong grabs, frenzy | A gauntlet (`hands`): big attack, frenzy risk as a rage stack |
| T-Owl | Seidou Takizawa | Half at first *(source)*, later held; ranged blasts and wild speed | Light and ranged: a bolt power, medium drain |
| Amon's | Koutarou Amon | Half, uncontrolled when it shows *(source)*; heavy single hits | Heavy: big attack, slow, larger drain |
| Tatara's | Tatara | Fire *(source)*: an element on every hit and a burning battlefield around him | Fire ward and fire hits (`resist_fire`, lent element) |
| Noro's | Noro | A huge mouthed tail and regrowth past any wound *(source)* | Regen only: the strongest `kakuja_regen`, no attack bonus |
| Roma's | Roma Hoito | Giant body *(source)*; grabs and swallows | Heavy: HP and shell |
| Donato's | Donato Porpora | Cross-shaped kagune and far-reaching copies of himself *(source)*: owned fighters (C8.10) | A relic: one clone power |
| Furuta's | Kichimura Washuu-Furuta | Many-shaped, late *(reading: shown in his last fight; built as a balanced form with a two-shape barrage)* | Balanced |
| Mutsuki's | Tooru Mutsuki | Late in the story *(reading: a full kakuja is not clearly shown; built as a half form, at the owner's ask for one each)*; knives stay the main weapon | Light: on-hit ailments |
| Dragon | Ken Kaneki (and Rize) | Not worn: a battlefield-sized body *(source)*. It is a boss arena (a battlefield, Part 3 of `GEAR.md`), not a form | None |

The row that builds each one (C9.6) reads the source again for the *(to confirm)* lines, and
may add kakujas this table misses; the table is a list in data, so adding one is a file.

## Board rows (the order to build in)

Each row is one task within the 8-file rule. C9.1 to C9.4 come BEFORE C7.6, by the owner's
answer.

| Row | What | Needs |
|---|---|---|
| C9.0 | This design (documents only) | DONE (0.88.1) |
| C9.1 | Passives, the core: `PassiveSkill`, `PassiveTrigger`, `PassiveEffect` (the pool, status and cure effects), `PassiveDb`, `PassiveSet` listening to `FIGHT_START`, `FIGHT_WON`, `TURN_START`, `HIT_DEALT`, `HIT_TAKEN`, `KILL`, `ALLY_DEFEATED`; `CombatantDef.passives`; chance, cooldown, limit | C6.4 |
| C9.2 | Conditions and the hit effects: `PassiveCondition`, the events `CRIT_DEALT`, `DODGE`, `GUARD`, `HP_BELOW`, `HP_ABOVE`, `LETHAL_HIT`, `SKILL_USED`, `STATUS_GAINED`, the form events; `SCALE_HIT`, `SURVIVE`, `EXTRA_HIT`, `COOLDOWN_CUT`, `BREAK_PIECE`; `group` and `rank`. Split if it passes 8 files | C9.1 |
| C9.3 | Passives on kits and gear: `PowerKit.passive_skills`, `GearDefinition.passives`, and the same list on `GearSetTier`, `GemDefinition` and `UpgradeLevel`; the sample library in `data/passives/` (one file per catalogue family) with CSV rows | C9.2 |
| C9.4 | The loadout: budget, learned passives, `GearDefinition.teaches`, progress from won fights, the refusals, saved as flags | C9.3 |
| C9.5a | DONE (0.96.0): `HitGuard`, the invincible status, mercy time, the overshield, `healing_taken` | C9.2 |
| C9.5b | DONE (0.97.0): `BREAK_PIECE` (`GearBreak`), `SKILL_DONE`, `per_element` on `GIVE_STATUS` | C9.5a |
| C9.5c | DONE (0.98.0): the berserk status (`StatusEffect.takeover`) | C9.5b |
| C9.5d | DONE (0.99.0): upgrade levels won by fights (`UpgradeLevel.fights`) | C7.5 |
| C9.6a | DONE (0.100.0): a form's own passives (`FormMechanism.passive_skills`), and the shared kakuja passives as data | C9.5, C6.5d |
| C9.6b | DONE (0.101.0): `PowerKitDb`, and Centipede, Arata, Jason and Noro as kits and quinque armours | C9.6a |
| C9.6c | DONE (0.102.0): Owl, One-Eyed Owl, T-Owl and Amon as kits and quinque armours | C9.6b |
| C9.6d | Tatara, Roma, Donato, Furuta and Mutsuki as kits and quinque armours | C9.6c, C8.6, C8.10 |
| C9.7 | The loadout screen, with the gear screen | C9.4, C7.7 |

C7.10 (the armoury: armours) now also needs C9.5, and builds this page's armour table with
`GEAR.md`'s.

## From fighting-game character files (C9.8)

The study is in `docs/POWERS.md` § What fighting-game character files teach us. For passives
it found nothing new to build: their always-on states (-1, -2, -3) do what a passive's
triggers do here, and their per-character variables are our statuses and pools. One idea
touches passives: super armour as a stretch on a move (row C8.16) would sit beside the
`kakuja_shell` no-flinch passive, which is armour all the time.

## Renaming

As everywhere here: a game renames a passive, an armour or a kakuja by changing its CSV row and
its file's name. No code names one, and `check_boundary` fails a file under `src/` or `tests/`
that does.
