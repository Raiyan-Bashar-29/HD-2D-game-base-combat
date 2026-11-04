# Hero powers — research, mechanisms and the plan (phase C6)

**Read this before any C6 row.** It is the design that rows C6.1 onward build, written by C6.0
(documents only) on 2026-11-03 at the owner's request:

> add special powers for the main character … for starters Gilgamesh (Fate), Kishou Arima (Tokyo
> Ghoul), Satoru Gojo (Jujutsu Kaisen), Escanor (Seven Deadly Sins), Lelouch (Code Geass), Yhwach
> "The Almighty" and his other powers (Bleach), the Barnabas and Odin Eikon (Final Fantasy XVI),
> Vergil and Dante (Devil May Cry) … the list will grow, so organize it so we can add more later.

**Contents:** the rules in one screen · Renaming · the framework · the thirteen shared mechanisms
· one section per character · the build order (board rows) · Sources.

## The rules in one screen

1. **A character is a kit, and a kit is data.** `data/powers/<kit>.tres` holds one `PowerKit`.
   Adding a character means adding one data file and its CSV rows. **No existing kit, and no file
   under `src/`, changes when a character is added**, unless the new character needs a mechanism
   nobody has yet. Then you add one mechanism (two files) and one registry line.
2. **Every power is built from parts that already exist.** A `Power` wraps a `Skill` (cost,
   power, element, statuses, effects: C2.3–C2.17), an optional `ActionMove` (real-time timing and
   hitbox: C3.2), and an optional `PowerMechanism` for the one thing a skill cannot already do.
3. **A mechanism is written once and shared.** Thirteen mechanisms cover all nine characters.
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

C6.1a built the content classes below except `GaugeRule`, which C6.4 builds with the gauges
that read it. C6.1b built the gameplay classes; their executors have only `use`, `tick` and
`end` so far, and each later row adds the hook its seam needs (`intercept_incoming` with C6.6).
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
| `Power` | `power_id`, `name_key`, `desc_key`, `skill: Skill`, `move: ActionMove` (optional; the field's timing and hitbox), `mechanism: PowerMechanism` (optional), `cooldown` (seconds in the field, turns in battle), `requires_statuses`, `consumes_statuses`, `requires_pool` and `requires_fraction`, `active_hours: Vector2` (a `Clock` window; `(0, 24)` is always), `scaling: Array[PowerScaling]`, `passive: bool` | The cost is the skill's own `cost_pool` and `cost`, so a gauge power such as Zantetsuken costs its gauge pool through the path every skill already uses |
| `PowerScaling` | `source`: USER_HP_FRACTION, USER_MISSING_HP, POOL_FRACTION (a `pool`), CLOCK_CURVE (a `Curve` over 0–24 h), TARGET_HAS_TAG (a `tag`); `affects`: POWER, DURATION, HITS, COUNT; `curve` or `factor` | Pure: `multiplier(context) -> float`. It covers Sunshine, The One's "more HP, more damage", and Enkidu's divinity bonus with no mechanism at all |
| `GaugeRule` | `pool`, and an amount per event: `on_hit_dealt`, `on_hit_taken`, `on_dodge`, `on_perfect_dodge`, `per_idle_second`, `per_moving_second`, `on_miss`, `on_ally_defeated`, `on_kill`, `on_new_move` (a different move from the last one, as a style rank counts), `per_second` | The generalisation of C4.2's `AtbRules` to any pool. A negative amount drains |
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
  (`PowerSlots`). The HUD shows each slot's cooldown (C6.3b) and every kit gauge (C6.4).

## The thirteen shared mechanisms

**Battle** means the turn-based formula (`Battle`). **Field** means the action and hybrid
formulas (`ActionFighter`, `CombatClock`).

| # | Mechanism (`kind`) | What it is | Battle | Field | Used by |
|---|---|---|---|---|---|
| M1 | `barrage` | Many projectiles from portals or a pattern | `skill.hits` hits, each at a random or a fixed target, each with its own element drawn from a list | `count` projectiles from a `pattern` (RING_BEHIND_USER, RING_AROUND_TARGET, RAIN, LINE, FROM_GROUND), every `interval` s, with `speed` and `homing`. New `Projectile` node: a moving `Hitbox` | Gate of Babylon, Heilig Pfeil, Summoned Swords, Judgment Cut, Narukami, IXA remote spikes, Gunslinger, Cruel Sun, Barnabas's blades |
| M2 | `finisher` | A charged, gated big hit | A "charging" status for `charge_turns`, released on the next turn; a strong hit cancels it if `breaks_on_hit` | Hold to charge (`charge_time`), release; optional time-stop flourish (`CombatClock` at 0 for `flourish` s); power from `POOL_FRACTION` scaling | Enuma Elish, Zantetsuken, Judgment Cut End, Hollow Purple 200%, Pride Flare, Divine Sword, Royal Release, Sankt Bogen |
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
| M13 | `counter_stance` | Hold a stance and answer a hit | A status with the COUNTER reaction (C2.15) at chance 1 for one turn | Hold to keep the stance (pool upkeep); a hit received becomes a counter move, and a perfect press is a parry | Gungnir, Royal Guard's Release timing, Arima's counters |

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
| Concentration (passive) | M6 `gauge` `concentration`: +8 per idle second, +4 per walking second, +25 per perfect dodge, −15 per running second, −30 per hit taken, −10 per miss. `levels` at 33/66/100 give +10/+20/+35% damage and range | — |
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
| C6.6 | M3 `barrier` and the incoming guard in `Combatant.receive`; M13 `counter_stance` | C6.1 |
| C6.7 | M1 `barrage` and the `Projectile` node | C6.2 |
| C6.8 | M2 `finisher` (charge, hold, flourish) | C6.4 |
| C6.9 | M4 `domain` (including clash and pull) | C6.6 |
| C6.10 | M7 `foresight` | C6.6 |
| C6.11 | M8 `command` and M12 `grant` | C6.2 |
| C6.12 | M9 `blink` and M11 `sacrifice` | C6.2 |
| C6.13 | M10 `clone` | C6.5 |
| C6.14–C6.22 | One kit each: Gojo, Gilgamesh, Escanor, Arima, Lelouch, Yhwach, Odin and Barnabas (with the boss), Vergil, Dante. Each is data, CSV rows, a content test case, a probe and a windowed capture | their mechanisms |
| C6.23 | Choosing a kit: a debug command `power_kit <id>`, a loadout default, and `AUTHORING.md` § Powers with "add a new character in five steps" | C6.2 |

### Adding a character later, in five steps (C6.23 writes the full how-to)

1. Read the mechanism table. Most powers are a `Skill` plus one of M1–M13.
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
