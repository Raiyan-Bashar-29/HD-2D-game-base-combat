# Hero powers — research, mechanisms and the plan (phase C6)

**Read this before any C6 row.** It is the design that rows C6.1 onward build, written by C6.0
(documents only) on 2026-11-03 at the owner's request:

> add special powers for the main character … for starters Gilgamesh (Fate), Kishou Arima (Tokyo
> Ghoul), Satoru Gojo (Jujutsu Kaisen), Escanor (Seven Deadly Sins), Lelouch (Code Geass), Yhwach
> "The Almighty" and his other powers (Bleach), the Barnabas and Odin Eikon (Final Fantasy XVI),
> Vergil and Dante (Devil May Cry) … the list will grow, so organize it so we can add more later.

**C6.0b (2026-11-04) added two more,** at the owner's request: "Emperor Isliid, Beyond Fate and
Human Pinnacle (Grand Summoners), and Roland's many forms (The Last Cloudia)". Both are
characters with FORMS, so each is one kit whose forms are M5 `form`s in one exclusive group.
They needed one new mechanism (M14 `refresh`) and four small seams, each placed in the row that
builds the part it touches.

**The owner's power list (C6.0c, 2026-11-11):** 3,306 powers and 127 character profiles are in
`docs/reference/`, and [`POWER_ATLAS.md`](POWER_ATLAS.md) sorts each of their 116 handler
families onto a mechanism on this page, a part already built, or a new row (C8.10–C8.15). A
kit row reads its character's profile there as a second source.

**Contents:** the rules in one screen · Renaming · the framework · the fourteen shared mechanisms
· one section per character · the build order (board rows) · Sources.

## The rules in one screen

1. **A character is a kit, and a kit is data.** `data/powers/<kit>.tres` holds one `PowerKit`.
   Adding a character means adding one data file and its CSV rows. **No existing kit, and no file
   under `src/`, changes when a character is added**, unless the new character needs a mechanism
   nobody has yet. Then you add one mechanism (two files) and one registry line.
2. **Every power is built from parts that already exist.** A `Power` wraps a `Skill` (cost,
   power, element, statuses, effects: C2.3–C2.17), an optional `ActionMove` (real-time timing and
   hitbox: C3.2), and an optional `PowerMechanism` for the one thing a skill cannot already do.
3. **A mechanism is written once and shared.** Fourteen mechanisms cover all eleven characters.
   For example, the barrage covers Gate of Babylon, Heilig Pfeil, Summoned Swords, Narukami,
   Gunslinger and Barnabas's blades. A mechanism is never named after a character.
4. **Every power works in all three formulas.** Turn-based, action and hybrid each get a stated
   meaning for each mechanism in the "Battle" and "Field" columns below. No power works in only
   one of them.
5. **Enemies can use powers too.** A `BattleCommand` or a brain entry can name a power, so
   Barnabas is a boss with the same Odin kit the hero can equip.
6. **Real names, for now.** See Renaming.

## Renaming

The owner decided on 2026-11-03 to use the real names for now and rename them personally later.
Do not invent substitute names.

**Where a name lives,** so a rename touches only these:

| What | Where | Rename by |
|---|---|---|
| What the player reads ("Gate of Babylon") | `localization/strings.csv`, rows `power.<kit>.*` | editing the `en` (and `en_XA`) value. Nothing else changes |
| The kit and power ids (`kit/gilgamesh`, `power/gate_of_babylon`) | `data/powers/<kit>.tres` and anything that equips it (a loadout, a `CombatantDef`) | `grep -rn "gate_of_babylon" data/ localization/`, then rename the ids, the CSV keys and the file names together. The suite's content test fails on any you miss |
| Code | **nowhere.** `src/` and `tests/` never name a character or a power, and `tools/check_boundary.gd` keeps it that way | — |

## The framework (built by C6.1–C6.3)

C6.1a built the content classes below except `GaugeRule`, which C6.4a built with `KitGauges`,
the part of `PowerSet` that runs it (time, hits landed and taken, dodges, misses, `levels`,
`blocked_by_tags`, and `regen_<pool>` by the second in the field); C6.4b adds the other events. C6.1b built the gameplay classes; their executors have `use`, `tick`, `end` and (C6.5a)
`power_used`, which hears every power of the kit used, and each later row adds the hook its seam needs (`intercept_incoming` came with C6.6a).
C6.2a put kits into a turn-based battle. A fighter's kit is `CombatantDef.power_kit`, the one
kit field for both formulas (the field reads its loadout's `fighter`). In battle a cooldown counts
down at the start of each of the holder's turns, beside its statuses, asleep or not. C6.2b put
kits into the field: `ActionHost.fit_identity` equips the fighter's kit on the player and each
follower, a party switch carries the `PowerSet` (cooldowns and running mechanisms) with the
member, and `FieldCommands` uses a POWER with no ATB cost (a power has its cooldown). A kit's
passive is held again after a load or a new game, never twice. C6.2c put powers into both
menus through `PowerMenu` (`src/ui/combat/`): one Powers row from the kit, each refused power
greyed out with its `PowerUse.Reason` in words, and costs shown as `SkillUse.cost_of` says.

### Content (`src/content/combat/powers/`), data shapes only

| Class | Fields | Notes |
|---|---|---|
| `PowerKit` | `kit_id`, `name_key`, `desc_key`, `powers: Array[Power]`, `passives: Array[StatusEffect]` (held while equipped, duration 0), `stat_bonuses: Array[StatModifier]`, `gauges: Array[GaugeRule]` | `problems()` checks every part. One per character |
| `Power` | `power_id`, `name_key`, `desc_key`, `skill: Skill`, `move: ActionMove` (optional; the field's timing and hitbox), `mechanism: PowerMechanism` (optional), `cooldown` (seconds in the field, turns in battle), `requires_statuses`, `consumes_statuses`, `requires_pool` and `requires_fraction`, `active_hours: Vector2` (a `Clock` window; `(0, 24)` is always), `scaling: Array[PowerScaling]`, `passive: bool`, `once_per_battle: bool` (C6.5f: once per battle, once per area in the field) | The cost is the skill's own `cost_pool` and `cost`, so a gauge power such as Zantetsuken costs its gauge pool through the path every skill already uses |
| `PowerScaling` | `source`: USER_HP_FRACTION, USER_MISSING_HP, POOL_FRACTION (a `pool`), CLOCK_CURVE (a `Curve` over 0–24 h), TARGET_HAS_TAG (a `tag`); `affects`: POWER, DURATION, HITS, COUNT; `curve` or `factor` | Pure: `multiplier(context) -> float`. It covers Sunshine, The One's "more HP, more damage", and Enkidu's divinity bonus with no mechanism at all |
| `GaugeRule` | `pool`, and an amount per event: `on_hit_dealt`, `on_hit_taken`, `on_dodge`, `per_idle_second`, `per_moving_second`, `on_miss`, `per_second`, `per_turn` (C6.4a); `on_ally_defeated`, `on_kill`, `on_new_move` (a different move from the last one, as a style rank counts; the field only), `per_running_second` (added on top of `per_moving_second` while running), `spent_pool` and `on_spent` (points per point of `spent_pool` paid as a cost) (C6.4b); `on_perfect_dodge` (C6.6c: paid on top of `on_dodge` for a hit dodged in the dodge's `perfect_window`); `blocked_by_tags`; `levels` (points -> status) | The generalisation of C4.2's `AtbRules` to any pool. A negative amount drains |
| `PowerMechanism` | base: `kind: StringName` (read-only), `problems()`; each subclass holds only typed `@export`s | Data only. Its runtime twin lives in gameplay (below) |

### Gameplay (`src/gameplay/combat/powers/`)

| Class | Job |
|---|---|
| `PowerSet` (a `Node`, a child of the body like `Vitals`; `PowerSet.of(node)`) | Holds the equipped kit, cooldowns, the running state of each mechanism, and the gauges. It applies passives and stat bonuses on equip and removes them by source on unequip. It ticks on `CombatClock.scaled(delta)` in the field and on the holder's turn in battle |
| `PowerUse` (static, the twin of `FieldCommands` and `SkillUse`) | `refusal(user, power) -> String` (cooldown, hours, required statuses, pool fraction, the skill's own cost, status blocks), `targets(...)`, and `use(user, power, targets, rng) -> bool`: it pays, applies `scaling`, runs `SkillUse.apply`, then the mechanism's `use`, then starts the cooldown and consumes statuses |
| `PowerMechanisms` (static registry) | `kind -> executor script`. **Adding a mechanism adds one line here.** An executor implements any of: `use`, `tick`, `intercept_incoming(request) -> request or null`, `on_dealt(result)`, `on_event(name, data)`, `end` |
| One executor per mechanism (`mechanisms/barrage_run.gd`, …) | The behaviour, in both formulas |

### Seams in existing code (fork-owned files only)

- `ActionLoadout.power_kit` equips the field hero. `CombatantDef.power_kit` equips a battle
  fighter, whether a party member or a boss. `ActionHost.equip` and `BattleSetup` add the `PowerSet`.
- `BattleCommand.Kind.POWER` plus `power`. `Battle.act`, `FieldCommands` and both menus route a
  POWER through `PowerUse`. Powers show as a "Powers" category in the battle menu and the F
  overlay, greyed out with their reason.
- **The incoming-hit guard.** `Combatant.receive` asks `PowerSet.intercept_incoming` before it
  applies a result. This is how Infinity, Blut Vene, Royal Guard and The Almighty step in, and it
  is the only new hook in the damage path.
- **Four quick slots.** `combat_power_1` to `combat_power_4`, added through
  `Actions.add_rebindable` (C5.3a's path), so they are rebindable from day one. Built in C6.3a:
  the keys are 1 to 4 with no pad default (every pad button is taken), and slot N holds the
  kit's Nth power that is not a passive, in kit order, the same order as the Powers menu
  (`PowerSlots`). The HUD's slot line shows each slot's key, power and cost, or its cooldown
  counting down from `Events.power_cooldown_changed` (built in C6.3b); every kit gauge follows in C6.4.

## The fourteen shared mechanisms

**Widened by C7.0 ([`GEAR.md`](GEAR.md)):** M4 `domain` is designed in full there as the
`battlefield` (Part 3); a fifteenth mechanism, M15 `plant` (left in the ground, set off later),
is designed there too; and a form gains a look, a name and battle commands (Part 4). Arima's
Owl quinque, IXA's modes and Ea are in its Part 2, and they are worn as gear.

**Battle** means the turn-based formula (`Battle`). **Field** means the action and hybrid
formulas (`ActionFighter`, `CombatClock`).

| # | Mechanism (`kind`) | What it is | Battle | Field | Used by |
|---|---|---|---|---|---|
| M1 | `barrage` | Many projectiles from portals or a pattern | **Built (C6.7).** `count` hits at once, each on a standing foe picked at random; each shot uses its own numbers (its skill, or `hits` × `power`) and element, or one drawn from `elements` | **Built (C6.7).** `count` (times COUNT scaling) shots from a `pattern` (RING_BEHIND_USER, RING_AROUND_TARGET, RAIN, LINE, FROM_GROUND), every `interval` s, at `speed`, homing by `turn_rate`, `pierce` or not. Each shot is an `ActionMove` (`shots`, played in turn: the sizes) flown by a `Projectile`, a moving `Hitbox`. A beam is a LINE shot with speed 0, pierce and a long box | Gate of Babylon, Heilig Pfeil, Summoned Swords, Judgment Cut, Narukami, IXA remote spikes, Gunslinger, Cruel Sun, Barnabas's blades |
| M2 | `finisher` | A charged, gated big hit | **Built (C6.8).** A `charging` status held for `charge_turns`, the `strike` landing at the start of the user's turn once they pass (on the first standing foe, or every foe with `all_foes`); the status ending early (`breaks_on_hit`) or one hit of `break_damage` or more loses the charge | **Built (C6.8).** A charge of `charge_time` seconds, then the `flourish`: `CombatClock` at 0 for that many real seconds (the `Flourish` node), then the `strike` through the aimed foe's hurtbox, or every foe within `reach`; the power's POWER and HITS scaling are read as it lands (POOL_FRACTION for a gauge), then `drain_pool` is emptied. Hold-to-charge input is not built: a press starts the charge | Enuma Elish, Zantetsuken, Judgment Cut End, Hollow Purple 200%, Pride Flare, Divine Sword, Royal Release, Sankt Bogen |
| M3 | `barrier` | Stops or softens what reaches you | The same, through the guard | `mode`: NULLIFY, REDUCE (`factor`), TIMED_BLOCK (C4.10's `TimedWindow`: a perfect press takes 0); `upkeep` pool per second or turn, `cost_per_block`, `bypass_tags` (a `domain` or `sure_hit` gets through), `absorb_elements` stored into `store_pool`; `scope` SELF or ALLIES | Infinity, Blut Vene, Blut Vene Anhaben, IXA shield, Royal Guard, Rhitta's heat, Narukami's absorb |
| M4 | `domain` | An area that rules everyone inside | Statuses on all foes, or on all, for `turns`; the user's skills gain `sure_hit` and the `domain` tag; two domains clash and both end | A sphere of `radius` for `duration` s: statuses on entry, `tick` damage, `pull` toward the centre, bypass for the user; `affects_allies` | Unlimited Void, Escanor's heat aura, Blue's vortex, Vollständig's light |
| M5 | `form` | A stance, style or transformation | A toggle status (C2.16), and a command list swapped while in it | Swaps parts of the `MoveSet` (attack chain, dodge, skills) and holds a status; `drain` a pool per second or per action and end when empty; an `exclusive_group` (one form per group); `cycle` through a list | Dante's four styles, Devil Trigger, Sin Devil Trigger, Vergil's weapons, IXA lance and shield, Arm of Darkness, The One, Blut Vene and Arterie, Vollständig, Barnabas's Odin form |
| M6 | `gauge` | A pool that fills and drains by rule | The same events per turn | `GaugeRule`s on the kit (above); level statuses at thresholds (`levels`) | Concentration, the Zantetsuken gauge, the Devil Trigger and Sin gauges, the Royal gauge, the style rank, soul fragments |
| M7 | `foresight` | Seeing, and rewriting, the future | `rewrites` per battle: turn a landing hit into a miss (DODGE), or the user's miss into a hit (FORCE); `observe`: a skill that has hit the user once can never harm them again this fight; `reveal`: weaknesses shown on sight | The same, with `cooldown` s between rewrites; `reveal` on lock-on | The Almighty, Six Eyes, Sha Naqba Imuru, Arima's reading of a foe |
| M8 | `command` | Absolute orders to a foe | Orders: OBEY (fights on your side for `turns`), STOP (SKIP_TURN), FORGET (leaves the fight with no reward), FALL (defeated; foes with `immune_tag` refuse) | Needs sight (lock-on and facing within `range`); OBEY flips the foe's faction for `duration` s; FORGET returns it home | Geass |
| M9 | `blink` | Teleport and cancel | Acts sooner (a negative CTB delay) and gives evasion until the next turn | `to`: TARGET, BEHIND_TARGET, FORWARD (`distance`), UP; `cancels_recovery`; i-frames | Rift Slip, Trick, Air Trick, Trickster's dash, Gojo's teleport, Rhitta's recall |
| M10 | `clone` | A double who repeats your moves | The next `actions` actions happen twice at `power_fraction` | A ghost that replays the user's `MoveTimeline` `delay` s later with its own hitbox, for `lifetime` s | Doppelganger, Dancing Steel |
| M11 | `sacrifice` | Take from your own side to grow | Takes `fraction` of each ally's HP (and optionally their buffs) and gives it to the user, plus a status | The same, within `radius` | Auswählen |
| M12 | `grant` | Give a power to an ally | Applies a status, or equips a power, on an ally for `turns` | The same, in seconds | The Almighty's gift of a Schrift, Lelouch's tactics |
| M13 | `counter_stance` | Hold a stance and answer a hit | A status with the COUNTER reaction (C2.15) at chance 1 for one turn; the counter strikes with its `counter_move`'s numbers | Hold to keep the stance (pool upkeep); a hit received becomes a counter move, and a perfect press is a parry. **Built in C6.6d as data, with no class of its own:** a form or a TIMED_BLOCK barrier whose status carries COUNTER and `counter_move` | Gungnir, Royal Guard's Release timing, Arima's counters |
| M14 | `refresh` | Hurry your side's powers along (C6.0b) | Cuts each remaining cooldown of the user (`scope` SELF) or every ally (ALLIES) by `fraction` (0.5 halves it), rounded down in turns; optionally adds `pool_gain` to a named pool | The same in seconds, and an optional `speed` status (a `cooldown_rate` stat, read by `PowerSet`'s count-down) for `duration` s | Isliid's Super Arts (halves her cooldowns), Conquering Dark Bringer's ally speed-up |
| M15 | `plant` | Left in the ground now, set off later (`GEAR.md` § The planted strike) | **Built (C6.26).** A `mark` status on foes picked at random (or the foe a barrage shot missed); it goes off on the next use (REMOTE), after `turns`, when the foe deals damage (PROXIMITY) or is hit (ON_HIT), the `eruption` once per mark | **Built (C6.26).** `count` `Planted` nodes (still hitboxes) at the target, the user or ahead, `spread` apart; triggers REMOTE (with `set_off_by`, a `chain_delay` ripple), PROXIMITY, TIMER and ON_HIT; `lifetime`, `max_standing`; WHERE_PROJECTILES_LAND keeps a barrage's misses | The Owl's shards and trap mode, IXA's mine and remote activation, time bombs, rune traps |

**No mechanism needed** (framework or existing parts alone):

- binding: Enkidu is a skill with a SKIP_TURN status and `TARGET_HAS_TAG divine` scaling on
  duration;
- push and pull: Red is a move with high `knockback`, and Blue is a domain with `pull`;
- combinations: Hollow Purple `requires_statuses` "primed_blue" and "primed_red", which Blue and
  Red apply, and consumes them;
- time windows: The One's noon and The Almighty's daytime are `active_hours`;
- Black Flash: a `TimedWindow` with a perfect band;
- Six Eyes' efficiency: a passive with the new stat `cost_mult_<pool>`, read by `SkillUse.pay`
  (one line in C6.1).
- damage against a kind of foe (Isliid's swords against gods, humans or demons): `PowerScaling`
  `TARGET_HAS_TAG` on the power;
- **M5 `form` as built (C6.5a)**, the first built-in mechanism: `FormMechanism`
  (`src/content/combat/powers/mechanisms/`) holds `status`, `exclusive_group`, `cycle` (stages
  that are forms themselves; the group and drain are the cycle's), `advance_after` (power ids),
  `drain_pool`, `drain_per_second` (field) and `drain_per_turn` (battle); its executor is `FormRun`
  (`src/gameplay/combat/powers/mechanisms/`). A form IS its status: a cure or a timed form running
  out ends it with no wiring. **C6.5b:** in the field the form plays its own `attack_chain` and
  `dodge` in place of the fighter's (a cycle stage's own, falling back to the cycle's; empty or
  null keeps the fighter's), through the executor hook `moves(base)` and
  `PowerSet.moves_over`, for the player and for followers; `drain_per_action` drains for each
  move started (never a dodge; the player only, since followers do not report moves). **C6.5c:** `PowerMechanism.statuses()`
  lists what a mechanism puts on (a form: its stage statuses) and `PowerKit.status(id)` finds
  it, so a form held at save time loads again. **C6.5d:** a form's `look` (a `LookDef`: tint, size,
  a tag) and `name_key` are shown while it is held: `LookSwap` on the field body, "Name · Form"
  on the battle screen, and first on the HUD line (`GEAR.md` § Part 4). **C6.5e:** a form's
  `commands` stand in for the fighter's menu while it is held, its `replaces_attack` turns a
  battle's Attack into that skill, and its `aftermath` goes on when it ends by its own rules
  (used again, drained, timed out; not a rival, a cure or the kit coming off).
- **M3 `barrier`, as built (C6.6a):** `BarrierMechanism` EXTENDS `FormMechanism`, so "a form with
  a barrier" is one mechanism on one power: it is entered, left and grouped like a form, its
  status is held while it is up, and the form's drain is its upkeep. With no status and no
  cycle it is always up (put it on a passive power). Its executor `BarrierRun` answers the hook
  `intercept_incoming`, which `Combatant.receive` reaches through `PowerGuard.incoming`: the
  target's own kit first, then each ally's on the same clock. In order: a `bypass_tags` hit
  goes through; an `absorb_elements` hit is added to the guard's `store_pool` and takes nothing;
  `cost_per_block` of `cost_pool` is paid, or the barrier comes down and the hit lands; then
  NULLIFY or REDUCE (`factor`). A barrier that only absorbs is REDUCE with factor 1. A hit's
  tags are its skill's `tags`, plus `sure_hit`. A hit stopped whole is `blocked`: no shield
  chip, and from a plain move no poise and no push. **TIMED_BLOCK as built (C6.6b):** `timing` is a `TimedWindow` counted
  from the moment the guard goes up. A hit inside it takes 0, costs nothing and is stored in
  `store_pool`; a later one pays `cost_per_block` and leaves `factor`. In a battle a block is
  perfect until the guard's own next turn. A hit stopped whole emits `Events.attack_blocked`.
- a power that only works in one form: `requires_statuses [<form status>]`. **As built (C6.5c): the quick
  slots skip a power whose required status is one the kit grants and is not held, so each form
  has its own four slots.** A status from elsewhere does not hide the power; it shows its reason.

**Small seams the C6.0b characters add** (each is built inside the row named, not a new row):

| Seam | What | Built in |
|---|---|---|
| `GaugeRule.blocked_by_tags` | A rule that fills only while the holder has no status with these tags (Human Pinnacle's "+7/s while free of ailments") | C6.4 |
| `FormMechanism.advance_after` | A `cycle` form moves to the next entry after the named power is used (Isliid's fourth-slot sword rotation) | C6.5 |
| `knockback_taken` stat | Scales the push in `Hurtbox._push` (1 plus the stat); −1 means no push and so no flinch ("Will Not Flinch", Roland's super armor) | Built, C6.6c |
| `PowerScaling.Source.ALLIES_STANDING` | The fraction of the user's party still standing (Heroic Lord Roland's hits grow with living allies) | C6.25 |

## The characters

Costs and numbers are **starting values for tuning**, not canon. The source says what the
character does. The kit says how this base plays it. Every kit lists its gauges (pools: `max_<pool>`
comes from `stat_bonuses`) and passives.

### Gilgamesh (Fate) · `kit/gilgamesh`

**Source.**
- The King of Heroes owns the Gate of Babylon, his treasury of every treasure he ever took, the
  "prototypes" of later heroes' weapons. He opens it with a key and fires its contents from
  golden portals.
- Ea, the Sword of Rupture, and its attack Enuma Elish are activated by naming the attack, not
  the weapon.
- Enkidu, the Chains of Heaven, binds a target more tightly the more divinity it has, and is an
  ordinary sturdy chain against a mortal. It can be called from anywhere the Gate opens.
- Sha Naqba Imuru gives exceptional insight. He is famously arrogant, and holds back against
  anyone he thinks unworthy.

| Power | Mechanism and parts | Cost |
|---|---|---|
| Gate of Babylon | M1 `barrage`, RING_BEHIND_USER, 8 weapons (field) or 6 hits (battle). Each weapon draws its element from the treasury list (blade, fire, ice, lightning, holy), so it finds a weakness by chance. Hold for up to 24 (`COUNT` scaling on hold time) | 12 MP, 4 s |
| Enkidu, Chains of Heaven | Skill: SKIP_TURN "bound" status for 1 turn or 2 s, with `TARGET_HAS_TAG divine` DURATION ×3. No mechanism | 10 MP, 8 s |
| Enuma Elish | M2 `finisher`: charge 2 s or 1 turn, a line of ruin (power 9, all foes in a 3 m-wide line), "rupture" element | the whole `treasury` gauge (100), 30 s |
| Sha Naqba Imuru (passive) | M7 `foresight` with `reveal` only | — |
| Golden Rule (passive) | `regen_mp` +2 per turn or second; loot +1 roll | — |
| King's Arrogance (passive) | `PowerScaling USER_MISSING_HP`: power ×0.8 above 70% HP, ×1.2 below 30%. He only takes a foe seriously once hurt | — |

**Gauge.** `treasury` (0–100), +6 per barrage hit and +4 per hit taken.

### Kishou Arima (Tokyo Ghoul) · `kit/arima`

**Source.**
- The CCG's undefeated "Reaper", a special-class investigator with peerless swordsmanship who
  reads his opponents and ends fights quickly.
- **IXA:** a quinque with a lance mode and a shield mode, and a remote activation that strikes
  from a distance.
- **Narukami:** fires homing arcs of lightning, and has absorbed a lightning blast and sent it
  back.
- **Yukimura 1/3:** later passed down to Haise Sasaki.

| Power | Mechanism and parts | Cost |
|---|---|---|
| IXA: Lance | M5 `form` (group `ixa`): a long thrust chain, poise ×2 | free switch, 1 s |
| IXA: Shield | M5 `form` (group `ixa`) with M3 `barrier` REDUCE ×0.4 and TIMED_BLOCK (a perfect block takes 0) | upkeep 2 MP/s |
| IXA: Remote activation | M1 `barrage` FROM_GROUND at the target, 5 spikes in a line, lance mode only (`requires_statuses`) | 8 MP, 5 s |
| Narukami | M1 `barrage` RING_AROUND_TARGET, 4 homing lightning arcs | 10 MP, 6 s |
| Narukami: Redirect | M3 `barrier` `absorb_elements [lightning]` into `store_pool charge`, then M2 `finisher` spending `charge` (power per point) | the stored charge |
| Yukimura 1/3 | M5 `form` (group `ixa`): a fast 5-hit chain | free switch |
| The Reaper (passive) | COUNTER reaction 25%, crit +25% against STAGGERED or broken foes (`TARGET_HAS_TAG staggered`) | — |
| Reading (passive) | M7 `foresight`: the perfect-dodge window is ×1.5 (a `TimedWindow` widen) | — |

### Satoru Gojo (Jujutsu Kaisen) · `kit/gojo`

**Source.**
- **Six Eyes:** a perception of cursed energy, which makes his technique nearly free to run.
- **Limitless:** Infinity, a barrier that keeps any attack from reaching him. A domain's sure-hit,
  or Domain Amplification, gets through.
- **Lapse: Blue:** draws things in.
- **Reversal: Red:** blasts things away.
- **Hollow Purple:** Blue and Red combined; it erases what it touches.
- **Unlimited Void:** his domain, which floods its targets with infinite information until they
  cannot act.
- **Also:** Reverse Cursed Technique heals him, and Black Flash is a precisely timed strike.

| Power | Mechanism and parts | Cost |
|---|---|---|
| Infinity (toggle, on by default) | M3 `barrier` NULLIFY, `cost_per_block` 3 MP, `bypass_tags [domain, sure_hit]`; it drops if MP is empty | per block |
| Lapse: Blue | M4 `domain`: radius 4, 2 s, `pull` 6, a small hit tick; applies "primed_blue" for 5 s | 8 MP, 4 s |
| Reversal: Red | Move: knockback 12, power 3; applies "primed_red" for 5 s | 8 MP, 4 s |
| Hollow Purple | A line move, power 10, bypasses barriers; `requires_statuses [primed_blue, primed_red]` and consumes them | 20 MP |
| Hollow Purple 200% | M2 `finisher`, charge 3 s, power ×2 | 60 MP, 45 s |
| Unlimited Void | M4 `domain`: radius 8, 5 s or 2 turns, "overwhelmed" (SKIP_TURN) on every foe inside; Gojo's hits inside are `sure_hit`; it clashes with an enemy domain | the `domain` gauge (100), 60 s |
| Reverse Cursed Technique | Skill HEAL 40% over 4 s (a regen status) plus CURE `ailment` | 15 MP, 20 s |
| Black Flash | A move with a `TimedWindow`: a press inside the 0.05 s perfect band crits ×2.5 and fills 20 `domain` | — |
| Six Eyes (passive) | `cost_mult_mp` ×0.5; M7 `reveal` on lock-on | — |

**Gauge.** `domain` (0–100), +5 per hit dealt and +20 per Black Flash.

### Escanor (Seven Deadly Sins) · `kit/escanor`

**Source.**
- **Sunshine:** his power rises from dawn to noon and fades to nothing at night, when he is a
  timid, weak man.
- **The One:** at noon he becomes "The One" for about one minute, his peak.
- **Divine Axe Rhitta:** imbued with his heat, so its slashes burn. He can call it to his hand.
- **Cruel Sun:** a small sun that melts armour.
- **Pride Flare:** flares it to vaporise a lake.
- **Divine Sword Escanor:** all his power gathered into a sword of light.
- **His heat:** it harms friends who stand close.
- **The cost:** in the end, Sunshine burns his own body away.

| Power | Mechanism and parts | Cost |
|---|---|---|
| Sunshine (passive) | `PowerScaling CLOCK_CURVE` on POWER for every Escanor power, and on `attack` and `defence`: ×0.3 from 18:00 to 06:00, rising to ×2.0 at 11:59 | — |
| Heat aura (passive) | M4 `domain`, always on from 06:00 to 18:00 (`active_hours`), radius 2.5, fire tick 1 per second, `affects_allies` true (resist_fire protects) | — |
| Cruel Sun | M1 `barrage`, one slow large projectile, fire, "melted" status (defence −30%) | 12 MP, 6 s, 06:00–18:00 |
| Pride Flare | M2 `finisher`, AoE radius 6, fire, power from CLOCK_CURVE | 30 MP, 25 s, 09:00–15:00 |
| Rhitta, heed my will | M9 `blink` TARGET for the axe (a thrown arc that returns) | 4 s |
| Rhitta's heat | M3 `barrier` `absorb_elements [fire]`: fire heals him | — |
| The One | M5 `form`, 12:00–13:00 game time only, lasting 60 s of fight time: every stat ×1.5 on top of Sunshine, and unlocks Divine Sword | free, once per day (a flag per `Clock` day) |
| Divine Sword Escanor | M2 `finisher`, `requires_statuses [the_one]`, power 12; afterwards a "burned out" self-status (HP −20% and no Sunshine powers for 10 min game time) | 50% of max HP |

**Night.** Every power except Rhitta is refused outside its hours, with the reason "only under
the sun". This is a framework refusal, not code per kit.

### Lelouch vi Britannia (Code Geass) · `kit/lelouch`

**Source.**
- **Geass, the Power of Absolute Obedience:** works through direct eye contact, and a reflection
  counts.
- **Once per person:** each person can be commanded only once, but any number of orders may be
  given in that one look.
- **Range:** a fan wiki gives about 270 m.
- **The Geass Canceller:** lifts a Geass, after which the person can be commanded again.
- **Otherwise:** he is a strategist, physically weak, and wins by plans and orders.

| Power | Mechanism and parts | Cost |
|---|---|---|
| Geass: Obey me | M8 `command` OBEY: the foe fights for you for 3 turns or 15 s | 20 MP |
| Geass: Stop | M8 `command` STOP: 2 turns or 6 s | 10 MP |
| Geass: Forget | M8 `command` FORGET: it leaves the fight, with no reward | 10 MP |
| Geass: Fall | M8 `command` FALL: refused by `immune_tag boss` | 40 MP |
| Strategist | M12 `grant` to every ally: +20% attack and speed for 3 turns or 12 s | 15 MP, 20 s |
| Checkmate (passive) | A foe under an order takes +30% damage (`TARGET_HAS_TAG geassed`) | — |
| A weak body (passive) | `stat_bonuses`: `max_hp` ×0.7, `attack` ×0.6 | — |

**Once per person.** The `command` mechanism records `geass/<combatant_id>` in `Flags` after the
first look. Any later Geass on that foe is refused ("already obeys a Geass"). This is saved, so it
holds across fights. A combatant with the tag `geass_canceller` clears its own flag. This gives a
boss a counter, and a later story beat a lever.

### Yhwach (Bleach) · `kit/yhwach`

**Source.**
- **The Almighty:** sees the future and alters it, choosing which future becomes real. An ability
  it has seen can be understood, and can no longer harm him. It depends on his sight and belief,
  so an illusion fools it.
- **Night:** while he sleeps at night, the power passes to Haschwalth.
- **Auswählen:** takes the power and life of impure Quincy for his own.
- **His soul:** he grants powers (the Schrift) to his Sternritter, and the powers return to him
  when they die.
- **Combat:** Heilig Pfeil arrows from the Sankt Bogen, or a barrage from his fingertips. Blut
  Vene is defence and Blut Arterie is attack, through the blood vessels. Blut Vene Anhaben
  extends the Vene as a barrier around him. Quincy: Vollständig is his full release.

| Power | Mechanism and parts | Cost |
|---|---|---|
| The Almighty (passive) | M7 `foresight`: 2 `rewrites` per battle (DODGE or FORCE), `observe` on, from 06:00 to 18:00 only (`active_hours`) | — |
| Heilig Pfeil | M1 `barrage` RAIN, 12 holy arrows | 10 MP, 4 s |
| Sankt Bogen | M2 `finisher`, one great arrow, charge 1.5 s | 25 MP, 15 s |
| Blut Vene | M5 `form` (group `blut`) with M3 `barrier` REDUCE ×0.5 | upkeep 1 MP/s |
| Blut Arterie | M5 `form` (group `blut`): attack ×1.4. One Blut at a time, as in the source | upkeep 1 MP/s |
| Blut Vene Anhaben | M3 `barrier` REDUCE ×0.6, `scope ALLIES`, 3 turns or 10 s | 30 MP, 30 s |
| Auswählen | M11 `sacrifice`: 30% of each ally's HP and their buffs to Yhwach, plus "selected" (+30% all stats, 3 turns) | 30 s |
| Grant a Schrift | M12 `grant`: an ally gains a random letter buff (a list of statuses) | 20 MP, 30 s |
| Soul fragments (passive) | M6 `gauge` `on_ally_defeated` +1 stack of "fragment" (+10% all stats, up to 5) | — |
| Quincy: Vollständig | M5 `form`: flight (immune to ground `barrage` patterns), Heilig Pfeil ×2, drains `reishi` | the `reishi` gauge, which must be full |

**Gauge.** `reishi` (0–100), +4 per hit dealt and +2 per second (Quincy absorb reishi around them).

### Barnabas Tharmr and the Odin Eikon (Final Fantasy XVI) · `kit/odin`

**Source** (Clive's Odin abilities, and Barnabas as a boss).
- **Arm of Darkness:** Clive's sword becomes Odin's blade, and hits with it fill the Zantetsuken
  gauge. Holding the button looses Zantetsuken.
- **Gungnir:** summons the spear for a long string of slashes and thrusts. It is played here as a
  counter stance; the guides describe the effect only roughly.
- **Heaven's Cloud:** a lunge that repeats while it keeps landing.
- **Dancing Steel:** a second blade's flurry, which hits in the air, with a 20 s cooldown. It also
  fills the gauge faster.
- **Rift Slip:** recovers at once from any ability or action. It deals no damage.
- **Barnabas, the boss:** he summons a second blade and spins around the arena, slashes that leave
  lines of darkness which burst, and becomes Odin at about a third of his health.

| Power | Mechanism and parts | Cost |
|---|---|---|
| Arm of Darkness | M5 `form`: the Odin attack chain; its hits fill `zantetsuken` | free switch |
| Zantetsuken | M2 `finisher`, hold 1 s, power scales with `POOL_FRACTION zantetsuken`; at a full gauge, any non-boss foe under 25% HP falls | the whole `zantetsuken` gauge |
| Gungnir | M13 `counter_stance`, hold; a received hit becomes a 6-hit thrust flurry | 6 MP, 6 s |
| Heaven's Cloud | A lunge move that re-triggers while hits land (up to 4); +8 `zantetsuken` per hit | 6 MP, 8 s |
| Dancing Steel | M10 `clone` (a second blade, 3 s), +12 `zantetsuken` per hit | 10 MP, 20 s |
| Rift Slip | M9 `blink` with `cancels_recovery`, no damage | 2 s |
| Odin's descent (boss-only) | M5 `form` triggered by a brain condition (own HP ≤ 33%): Barnabas becomes Odin, with M1 `barrage` RING lines that burst after 0.8 s | — |

**Gauge.** `zantetsuken` (0–100), filled only by Arm of Darkness hits (`GaugeRule on_hit_dealt`,
`requires_statuses [arm_of_darkness]`).

### Vergil (Devil May Cry) · `kit/vergil`

**Source.**
- **Yamato:** Judgment Cut cuts space at range, and a fully charged one becomes Judgment Cut End,
  a vast finisher.
- **Summoned Swords:** Mirage Blades, fired, or summoned in formations for Devil Trigger gauge.
- **Concentration (DMC5):** a gauge that fills while he stands still, walks slowly or perfectly
  dodges, and drains when he runs, takes a hit or misses. A full gauge raises damage and range.
- **Trick:** he teleports. **Doppelganger:** a ghostly twin that copies his moves.
- **Sin Devil Trigger:** his full form. Vergil goes straight to it.

| Power | Mechanism and parts | Cost |
|---|---|---|
| Concentration (passive) | M6 `gauge` `concentration`: +8 per idle second, +4 per walking second, +25 per perfect dodge, −15 per running second (data: `per_moving_second` 4, `per_running_second` −19), −30 per hit taken, −10 per miss. `levels` at 33/66/100 give +10/+20/+35% damage and range | — |
| Judgment Cut | M1 `barrage`, 3 cuts at the locked target's position after 0.3 s | 6 MP, 2 s |
| Judgment Cut End | M2 `finisher`: `requires_fraction concentration 1.0` or `requires_statuses [sin_devil_trigger]`; a 1 s time-stop flourish, then every cut lands on all foes in 10 m | all `concentration`, 40 s |
| Summoned Swords | M1 `barrage` RING_BEHIND_USER (formations: Spiral orbiting the user as a shield, Storm, Blistering, Heavy Rain) | 4 MP each formation, 3 s |
| Trick | M9 `blink` BEHIND_TARGET or UP | 1 s |
| Yamato, Beowulf, Mirage Edge | M5 `form` cycle (group `weapon`): three attack chains | free |
| Doppelganger | M10 `clone`, delay 0.25 s, 8 s | 40 `devil` |
| Sin Devil Trigger | M5 `form`: attack ×1.6, HP regen, Judgment Cut End needs no Concentration, drains `devil` 8/s | `devil` full |

**Gauge.** `devil` (0–100), +3 per hit dealt and +2 per hit taken.

### Dante (Devil May Cry) · `kit/dante`

**Source.**
- **Four styles:**
  - Trickster: evasion and movement, with the most freedom in the air;
  - Swordmaster: melee;
  - Gunslinger: ranged;
  - Royal Guard: a well-timed guard takes no damage and fills the Royal gauge, which a Release
    spends on a counter.
- **Devil Trigger:** his demon form, which restores vitality and raises attack. A guard costs a
  bar of it, unless it is a Just Guard.
- **Sin Devil Trigger:** a separate gauge, charged by holding to pour the DT gauge into it (a fan
  wiki says at 100:85). It drains over time and per attack.
- **Weapons:** a whole arsenal, switched mid-combo.

| Power | Mechanism and parts | Cost |
|---|---|---|
| Trickster | M5 `form` cycle (group `style`): dodge becomes M9 `blink` FORWARD 4 m with longer i-frames | free |
| Swordmaster | M5 `form` (group `style`): an extra attack chain (Million Stab: a 12-hit move) | free |
| Gunslinger | M5 `form` (group `style`): the attack button fires M1 `barrage` LINE (Ebony and Ivory) | free |
| Royal Guard | M5 `form` (group `style`) with M3 `barrier` TIMED_BLOCK: a perfect block takes 0 and stores the damage into `royal`; a late block takes 30% and costs 10 `devil` | free |
| Royal Release | M2 `finisher` spending `royal` (power per point) | all `royal` |
| Devil Trigger | M5 `form`: attack ×1.3, HP regen 1%/s, drains `devil` 10/s | at least 30 `devil` |
| Sin Devil Trigger | M5 `form`, the strongest: attack ×1.8 and a new chain; charged by moving `devil` into `sin` at 100:85 (a hold power); drains `sin` 6/s and 2 per action | `sin` full |
| Style rank (passive) | M6 `gauge` `style`: +10 per hit with a different move from the last one, −20 per hit taken, −2/s. `levels` D to SSS raise `devil` gain ×1 to ×2 | — |

**Gauges.** `devil`, `sin`, `royal`, `style`.

### Isliid (Grand Summoners) · `kit/isliid`

**Source.** Isliid is the Emperor, a Light-element swordsman who carries three swords and has
several units in the game. The owner named three of them:
- **Emperor Isliid:** his three swords, **Sky Light**, **Terra Master** and **Dark Bringer**, are
  modes. Which sword he holds depends on his party slot, and in the fourth slot he cycles through
  them with every Arts. His True Arts (67000% Light) adds a bonus by sword: Sky Light raises
  allies' accuracy 30% and the True Arts' damage against Gods by 150%; Terra Master lowers the
  damage allies take by 20% and raises it against Humans; Dark Bringer raises allies' attack 50%
  and raises it against Demons.
- **"Beyond Fate":** the game's unit is **Isliid, Defier of Fate** (shown on the Isliid Ascendant
  page). Skill **Eisen Walzer**: 2000% Light, +20 Arts gauge, **Will Not Flinch** for 7 s. Arts
  **Weiss Furcht Drei**: 15000% Light, with the sword chosen as above. The Ascendant version's
  Arts, **Conquering Dark Bringer**, raises damage against Demons 180% and every ally's physical
  equipment cooldown speed 30% for 25 s.
- **Isliid, Human Pinnacle:** a support. His True Arts raises every ally's Arts gauge for 8–9 s
  and cuts enemies' damage resistance by 120% against Humans, Gods and Demons. His Super Arts
  halves his own remaining equipment cooldowns. His own gauge fills by 7 per second while no
  status ailment holds him.
- (The game also has Young Isliid, Awoken Emperor Isliid and Last Miracle Isliid. The owner did
  not name them; Last Miracle's True Arts, enemy damage resistance −50% and own super-critical
  rate +50% for 50 s, is the obvious fourth form if wanted.)

**The kit.** Three forms in the group `isliid_form`, a sword cycle in the group `sword`, and the
Arts gauge that every Arts and True Arts spends. In battle a "form" is a toggle status (C2.16);
in the field it also swaps the attack chain.

| Power | Mechanism and parts | Cost |
|---|---|---|
| Emperor (form) | M5 `form` (group `isliid_form`), the default: a three-sword attack chain | free switch |
| Defier of Fate (form) | M5 `form`: the Eisen Walzer chain, +10% critical rate | free switch |
| Human Pinnacle (form) | M5 `form`: support, `cost_mult_arts` −0.2; Arts gauge +7/s while free of ailments (`GaugeRule.blocked_by_tags [ailment]`) | free switch |
| Sky Light / Terra Master / Dark Bringer | M5 `form` `cycle` (group `sword`), each holding a status (`sky_light`, `terra_master`, `dark_bringer`); `advance_after` the True Arts, so each True Arts moves to the next sword | free |
| Eisen Walzer | A Light skill, 3 hits, +20 `arts`; applies **Will Not Flinch** to the user (`knockback_taken` −1, `poise_taken` −1) for 7 s or 1 turn; `requires_statuses [defier_of_fate]` | 6 MP, 13 s / 3 turns |
| Weiss Furcht Drei (Arts) | A heavy Light skill; `PowerScaling TARGET_HAS_TAG` divine, human or demon by the held sword (three data entries, each `requires_statuses` its sword) | 100 `arts` |
| True Arts: Sky Light | M2 `finisher`: a huge Light hit, ×2.5 against `divine`; allies' accuracy +30% for 15 s / 3 turns | 100 `true_arts` |
| True Arts: Terra Master | as above, ×2.5 against `human`; allies take 20% less damage | 100 `true_arts` |
| True Arts: Dark Bringer | as above, ×2.5 against `demon`; allies' attack +50% | 100 `true_arts` |
| Conquering Dark Bringer | A Light skill ×2.8 against `demon` (`requires_statuses [dark_bringer, defier_of_fate]`) plus M14 `refresh` ALLIES with a `cooldown_rate` +30% status for 25 s | 100 `arts` |
| Pinnacle True Arts | M12 `grant` to all allies: a status with `regen_arts` +10 (per turn in battle, C2.16; per second in the field, through C6.4's gauge tick) for 9 s (3 turns); every foe gets `damage_taken` +1.2 for 9 s; `requires_statuses [human_pinnacle]` | 100 `true_arts` |
| Super Arts | M14 `refresh` SELF, `fraction` 0.5 (halves every remaining cooldown); `requires_statuses [human_pinnacle]` | 100 `super_arts`, 60 s |

**Gauges.**
- `arts` (0–100): +5/s, +4 per hit dealt.
- `true_arts` (0–100): +1 per 3 `arts` spent (`spent_pool arts`, `on_spent 0.3334`).
- `super_arts` (0–100): +2 per hit dealt, Human Pinnacle only.

**Simplified on purpose.** The game picks the sword by party slot; here the player cycles it (or
it rotates after each True Arts), because a hero has no fixed slot. "Against Humans, Gods and
Demons" filters by the foe's tags; an untagged foe takes the plain hit.

### Roland (The Last Cloudia) · `kit/roland`

**Source.** Roland is a Light-element swordsman with several units:
- **Roland** (Descent of Heroes): a Light bruiser and healer, with a party-wide Charisma and
  super armor (he does not flinch).
- **Ascended Roland:** an upgraded version that tier lists recommend; the sources found give no
  details of its kit, so it is played as the base form, stronger.
- **Heroic Lord Roland** (third anniversary, April 2022): his trait **Heroic Lord** raises his
  Light damage and damage cap. Skill **Star Geyser** closes on a foe at once and launches it with
  a combo. Special **Glorious Finale** is a powerful Light combo on every foe. **Trance** boosts
  his skill damage and damage cap, more for more MP spent (at 500 MP or more: damage +100%). With
  only one sword equipped, a chance to add skill hits, by the number of allies standing.

**The kit.** Three forms in the group `roland_form`, and the limit gauge for the Special.

| Power | Mechanism and parts | Cost |
|---|---|---|
| Roland (form) | M5 `form`, the default: a sword chain; super armor (`knockback_taken` −1) | free switch |
| Ascended (form) | M5 `form`: the base form with attack and defence +15% | free switch |
| Heroic Lord (form) | M5 `form`: attack +30% (the source raises Light damage; every Roland power is Light, so attack is the same thing with no new stat); Star Geyser, Trance and Glorious Finale need it | free switch |
| Charisma | M4 `domain` around the user, `affects_allies`, radius 8 m: allies' attack and defence +10% while inside; no effect on foes; Roland and Ascended forms | 8 MP, 30 s |
| Healing Light | A heal skill on ALL allies | 10 MP, 10 s |
| Star Geyser | M9 `blink` TARGET, then a launching move (`knockback` UP, 4 hits); `PowerScaling ALLIES_STANDING` adds up to +2 hits; Heroic Lord only | 8 MP, 6 s |
| Trance | M5 `form`, `consumes` all MP (at least 100): skill damage +100%; `PowerScaling POOL_FRACTION mp` on DURATION (5 s to 20 s, 1 to 4 turns); Heroic Lord only | all MP |
| Glorious Finale | M2 `finisher`, scope ALL, 8 Light hits; Heroic Lord only | 100 `limit` |

**Gauge.** `limit` (0–100): +3 per hit dealt, +5 per hit taken (C2.16's `fill_on_hit_limit`
already gives the second; the first is a `GaugeRule`).

**Simplified on purpose.** "Only one sword equipped" becomes the Heroic Lord form itself: this
base has no dual-wield, so the form is the one sword. Trance's strength is fixed and its length
scales with the MP spent, because `PowerScaling` already scales a duration; scaling a status's
strength would be a new `Affects` value, which can come later if the tuning needs it. The damage
cap has no meaning here, because this base caps no damage.

## Build order (the board rows)

Each row is one package of about 8 files or fewer, red first, with the full ladder. The details
are on `COMBAT.md`'s board. Mechanism rows come before the kits that need them.

| Row | Builds | Needs |
|---|---|---|
| C6.1 | Framework content and logic: `PowerKit`, `Power`, `PowerScaling`, `GaugeRule` (shape only), `PowerMechanism`, `PowerSet`, `PowerUse`, `PowerMechanisms`; `cost_mult_<pool>` in `SkillUse.pay` | — |
| C6.2a–c | Equip in both formulas: `CombatantDef.power_kit`, `BattleCommand.Kind.POWER` and routing in `Battle` (a); the field's `PowerSet` and `FieldCommands` (b); the "Powers" category in both menus (c) | C6.1 |
| C6.3 | Quick slots and the HUD: four rebindable `combat_power_N` actions; the slot, cooldown and gauge readout | C6.2 |
| C6.4 | M6 `gauge` running: every `GaugeRule` event, `levels` | C6.1 |
| C6.5 | M5 `form` | C6.2 |
| C6.6 | M3 `barrier` and the incoming guard in `Combatant.receive` (C6.6a, built); the timed block (C6.6b, built); the perfect dodge and `knockback_taken` (C6.6c, built); M13 `counter_stance` (C6.6d, built as data) | C6.1 |
| C6.7 | M1 `barrage` and the `Projectile` node: DONE (0.74.0) | C6.2 |
| C6.8 | M2 `finisher` (charge, its break, flourish, power from a pool): DONE (0.76.0) | C6.4 |
| C6.9 | M4 `domain` (including clash and pull). The core, C6.9a: DONE (0.77.0) as the `battlefield` (`GEAR.md` § Part 3) | C6.6 |
| C6.10 | M7 `foresight` | C6.6 |
| C6.11 | M8 `command` and M12 `grant` | C6.2 |
| C6.12 | M9 `blink`, M11 `sacrifice` and M14 `refresh` (with the `cooldown_rate` stat) | C6.2 |
| C6.13 | M10 `clone` | C6.5 |
| C6.14–C6.22 | One kit each: Gojo, Gilgamesh, Escanor, Arima, Lelouch, Yhwach, Odin and Barnabas (with the boss), Vergil, Dante. Each is data, CSV rows, a content test case, a probe and a windowed capture | their mechanisms |
| C6.23 | Choosing a kit: a debug command `power_kit <id>`, a loadout default, and `AUTHORING.md` § Powers with "add a new character in five steps" | C6.2 |
| C6.24 | Kit: Isliid (C6.0b): three forms, the sword cycle, `arts`, `true_arts` and `super_arts` | C6.4, C6.5, C6.6, C6.8, C6.11, C6.12 |
| C6.25 | Kit: Roland (C6.0b): three forms, Charisma, Trance, Glorious Finale; `PowerScaling.Source.ALLIES_STANDING` | C6.4, C6.5, C6.8, C6.9, C6.12 |

### Adding a character later, in five steps (C6.23 writes the full how-to)

1. Read the mechanism table. Most powers are a `Skill` plus one of M1–M14.
2. Write `data/powers/<kit>.tres` with its powers, passives, gauges and stat bonuses.
3. Add the `power.<kit>.*` rows to `strings.csv`.
4. Only if no mechanism fits: add one content class and one executor, plus one line in
   `PowerMechanisms`, as its own board row, red first.
5. Equip it through a loadout or a `CombatantDef`. The content test walks every kit and fails on
   a missing key.

## Sources

The research ran on 2026-11-03. The fandom wikis themselves (`*.fandom.com`) are outside this
container's network allow-list, so the facts came from search results that quote or mirror them,
and from game guides. Where sources disagreed, the table above uses the common reading and says
so.

**Gilgamesh**
- [Fate Unlimited Codes/Gilgamesh (Mizuumi wiki)](https://wiki.gbl.gg/w/Fate_Unlimited_Codes/Gilgamesh)
- [Gilgamesh (Giant Bomb)](https://giantbomb.com/wiki/Characters/Gilgamesh_12856)
- [Sportskeeda: Gilgamesh's abilities](https://www.sportskeeda.com/anime/how-powerful-gilgamesh-fate-series-abilities-explored)

**Arima**
- [Kishou Arima (MyAnimeList)](https://myanimelist.net/character/111767)
- [Tokyo Ghoul wiki: Owl quinque file](https://tokyoghoul.fandom.com/wiki/File:Owl_Quinque_Firing_mode.png)

**Gojo**
- [TV Tropes: Satoru Gojo](https://www.tvtropes.org/pmwiki/pmwiki.php/Characters/JujutsuKaisenSatoruGojo)
- [How Does Gojo's Limitless Technique Work (Deltia's Gaming)](https://deltiasgaming.com/?p=140454)
- [Sportskeeda: chapter 225](https://sportskeeda.com/anime/jujutsu-kaisen-chapter-225-spoilers-raw-scans-sukuna-gojo-s-domains-clash-one-of-them-is-fatally-injured)

**Escanor**
- [All Worlds Alliance wiki: Sunshine](https://all-worlds-alliance.fandom.com/wiki/Sunshine_(Seven_Deadly_Sins)?oldid=6143)
- [Grand Cross wiki: "The One" Escanor](https://7dsgc.fandom.com/wiki/Blue_%22The_One%22_Escanor?oldid=7419)
- [Dexerto: Escanor](https://www.dexerto.com/wikis/seven-deadly-sins-origin/characters/escanor/)

**Lelouch**
- [Inconsistently Admirable wiki: Lelouch](https://inconsistently-admirable.fandom.com/wiki/Lelouch_vi_Britannia)
- [GoodNovel: the key powers of Lelouch's Geass](https://www.goodnovel.com/qa/key-powers-lelouch-geass)

**Yhwach**
- [Comic Vine: Yhwach](https://comicvine.gamespot.com/yhwach/4005-85518/)
- [Bleach Wiki: Heilig Pfeil](https://bleach.fandom.com/wiki/Heilig_Pfeil)
- [ONE Esports: Blut Vene and Blut Arterie](https://www.oneesports.gg/anime/what-is-blut-vene-blut-arterie-in-bleach/)
- [Soapcentral: The Almighty's true power](https://www.soapcentral.com/anime/bleach-what-the-almighty-s-true-power)
- [FandomWire: The Almighty explained](https://fandomwire.com/bleach-tybw-the-almighty-yhwach-schrift-explained/)

**Odin and Barnabas**
- [Samurai Gamers: Odin's abilities](https://samurai-gamers.com/final-fantasy-xvi-ff16/odin-eikon-guide/)
- [Arm of Darkness guide](https://samurai-gamers.com/final-fantasy-xvi-ff16/arm-of-darkness-ability-guide/)
- [Dancing Steel guide](https://samurai-gamers.com/final-fantasy-xvi-ff16/dancing-steel-ability-guide/)
- [mp1st: all abilities](https://mp1st.com/news/final-fantasy-16-all-abilities-eikonic-feats-and-ultimates-revealed)
- [Gfinity: abilities list](https://www.gfinityesports.com/article/final-fantasy-16-abilities-list)
- [Gamer Guides: the Barnabas boss](https://www.gamerguides.com/final-fantasy-xvi/guide/walkthrough/chapter-4/barnabas-boss-guide-in-final-fantasy-16)

**Vergil and Dante**
- [Siliconera: Matt Walker on Vergil (DMC5 SE)](https://www.siliconera.com/capcoms-matt-walker-talks-about-devil-may-cry-5-vergil-lady-and-trish-dmc5se/)
- [Samurai Gamers: DMC5 battle styles](https://samurai-gamers.com/devil-may-cry-5/recommended-battle-styles/)
- [Twinfinite: Sin Devil Trigger](https://twinfinite.net/guides/devil-may-cry-5-sin-devil-trigger-how-use/)
- [Devil May Cry wiki: Perfect Devil Trigger](https://devilmaycry.fandom.com/wiki/Perfect_Devil_Trigger)
- [BiliGame DMC5 wiki: Sin Devil Trigger](https://wiki.biligame.com/dmc5/Sin_Devil_Trigger)
- [GameSpot: Dante guide](https://www.gamespot.com/articles/devil-may-cry-5-dante-guide-tips-to-get-sss-rank-a/1100-6465533/)

**Isliid (C6.0b, 2026-11-04).** The wikis and `grandsummoners.info` are outside the allow-list,
so these came from search results quoting them.
- [Grand Summoners Wiki: Emperor Isliid](https://grandsummoners.fandom.com/wiki/Emperor_Isliid)
- [Grand Summoners Wiki: Awoken Emperor Isliid](https://grandsummoners.fandom.com/wiki/Awoken_Emperor_Isliid)
- [Grand Summoners Wiki: Isliid Ascendant (Defier of Fate)](https://grandsummoners.fandom.com/wiki/Isliid_Ascendant)
- [grandsummoners.info: Emperor Isliid](https://www.grandsummoners.info/units/Emperor%20Isliid)
- [grandsummoners.info: Isliid, Human Pinnacle](https://www.grandsummoners.info/units/Isliid,%20Human%20Pinnacle)
- [grandsummoners.info: Last Miracle Isliid](https://www.grandsummoners.info/units/Last%20Miracle%20Isliid)
- [Pocket Gamer: Grand Summoners tier list](https://www.pocketgamer.com/grand-summoners/tier-list)

**Roland (C6.0b).**
- [Last Cloudia Wiki: Roland](https://lastcloudia.fandom.com/wiki/Roland)
- [Last Cloudia Wiki: Heroic Lord Roland](https://lastcloudia.fandom.com/wiki/Heroic_Lord_Roland)
- [Last Cloudia: third anniversary and Heroic Lord Roland](https://lastcloudia.com/en/post/2927/)
- [Last Cloudia on X: Heroic Lord Roland](https://twitter.com/lastcloudiaen/status/1514120620979924992)
- [Driffle: Last Cloudia tier list (Ascended Roland)](https://driffle.com/blog/last-cloudia-tier-list/)

