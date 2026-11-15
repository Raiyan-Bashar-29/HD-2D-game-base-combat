# Power cookbook: building new powers for the main character

**Read [`MECHANICS_GUIDE.md`](MECHANICS_GUIDE.md) first.** That guide explains how the parts
work. This one is the practical half: you have a power in mind, and this page tells you which
parts build it and which fields to set. Section 3 is a complete example kit made only from
recipes on this page. It was loaded and played in the engine (section 6 shows how), so you can
copy it as a starting point.

**The one idea to keep:** a power is `skill` + `move` + `mechanism` + rules.
- The **skill** lands at once, on whoever is aimed at: cost, damage, heals, statuses.
- The **move** plays in real time: wind-up, a hitbox, travel, i-frames, sounds.
- The **mechanism** is the one thing neither can do: a stance, a shield, a rain of blades.
- The **rules** are on the `Power`: `cooldown`, `requires_statuses`, `consumes_statuses`,
  `requires_pool` + `requires_fraction`, `active_hours`, `scaling`, `once_per_battle`.

Most powers need only one or two of the first three. Arima and Eto's specials are a skill that
pays, plus a move that hits.

**Contents:** 1. Pick the parts · 2. Recipes · 3. The example kit · 4. Putting a kit in the
game · 5. When no recipe fits: a new mechanism · 6. Checking it works · 7. The main
character's planned powers

---

## 1. Pick the parts

| I want a power that... | Use | Recipe |
|---|---|---|
| hits hard up close, with an animation | a cost-only SELF skill + a move | R1 |
| dashes into the foe | R1 with `travel_speed` | R2 |
| is also an escape | R1 with `iframes_from/to` | R3 |
| throws the foe up for a combo | R1 with `launch` (and `cancel_on_hit`) | R4 |
| grabs and throws | a move with a `throw_move` | R5 |
| fires one projectile | a move with a SHOT event | R6 |
| fires many projectiles | the `barrage` mechanism | R7 |
| leaves a trap | the `plant` mechanism | R8 |
| hits whoever I aim at, with no animation (a spell) | an ENEMY skill with `power`, no move | R9 |
| buffs me, debuffs a foe, heals, poisons | a skill with `statuses` / `effects` | R10 |
| switches fighting style, each with its own combo and specials | a `form` cycle | R11 |
| transforms, costs a meter while active, leaves me tired | a `form` with drain + `aftermath` | R12 |
| needs a meter that fills by fighting | a `GaugeRule` + two stat bonuses | R13 |
| is a super, only when the meter is full | the `finisher` mechanism | R14 |
| blocks or softens hits | the `barrier` mechanism | R15 |
| parries and strikes back | a timed barrier + a COUNTER status | R16 |
| teleports | the `blink` mechanism | R17 |
| makes an area that rules everyone inside | the `battlefield` mechanism | R18 |
| is stronger at night, or when nearly dead | `active_hours` / `scaling` | R19 |
| is set up by two other powers (a combination) | `requires_statuses` + `consumes_statuses` | R20 |
| makes me untouchable for a while | a status with `invincible` | R21 |
| controls a foe's mind, gives allies power, resets cooldowns | `command`, `grant`, `refresh` | R22 |

## 2. Recipes

Each recipe is the smallest set of fields that makes it work. Numbers in a `.tres` enum are
positions: `Skill.target` is 0 SELF, 1 ALLY, 2 ENEMY (the default), 3 ANY; `StatModifier.op`
is 0 ADD, 1 MULTIPLY, 2 OVERRIDE; `StatusEffect.unit` is 0 TURNS, 1 SECONDS. You can also set
every field in the Godot inspector: open the kit `.tres`, expand `powers`, and edit.

### R1 · A strike special (the Arima and Eto shape)

```
[ext_resource type="Script" path="res://src/content/combat/powers/power.gd" id="power"]
[ext_resource type="Script" path="res://src/content/combat/skill.gd" id="skill"]
[ext_resource type="Script" path="res://src/content/combat/action_move.gd" id="move"]
[ext_resource type="Script" path="res://src/content/combat/status_effect.gd" id="status"]

[sub_resource type="Resource" id="focus"]
script = ExtResource("status")
id = &"status/hero_focus"
name_key = "combat.status.hero_focus.name"
unit = 1
duration = 2.0

[sub_resource type="Resource" id="pay"]
script = ExtResource("skill")
id = &"skill/hero_cut"
name_key = "combat.power.hero_cut.name"
cost_pool = &"spirit"
cost = 20
target = 0
statuses = Array[ExtResource("status")]([SubResource("focus")])

[sub_resource type="Resource" id="cut_move"]
script = ExtResource("move")
id = &"move/hero_cut"
startup = 0.2
active = 0.15
recovery = 0.4
power = 28.0
poise = 3
knockback = 2.0
hitbox_size = Vector3(1.6, 1.2, 2.0)
hitbox_offset = Vector3(0, 0.6, -1.2)

[sub_resource type="Resource" id="cut"]
script = ExtResource("power")
power_id = &"power/hero_cut"
name_key = "combat.power.hero_cut.name"
skill = SubResource("pay")
move = SubResource("cut_move")
cooldown = 4.0
```

- The skill is SELF, so the power is never refused for "nobody in reach"; it only pays and
  gives a short buff (a skill must do something, so it needs a status).
- `power` on the move is the damage before the formula: `(power + attack) × 100 / (100 +
  defence)`, then element, crit and variance.
- `poise` breaks the foe's guard; `knockback` is metres pushed.
- In a turn-based battle this power only buffs (guide § 13, trap 1). For a power that must
  hit in battles too, use R9 instead, or give it both halves knowingly.

### R2 · A dash strike

R1, plus `travel_speed = 18.0` on the move. The fighter moves forward at that speed during
ACTIVE only, so the distance is `travel_speed × active` (18 × 0.15 = 2.7 m). Lock-on turns the
fighter to its target first, so the dash aims itself.

### R3 · A strike that is also an escape

R1, plus `iframes_from` and `iframes_to` on the move, in seconds from the move's start. Eto's
Air Strike is untouchable from 0.48 to 0.68 s. Cover the wind-up (`iframes_from = 0.0`) for a
"cannot be interrupted" special, or put the stretch late for a strike that ends in a vanish.
`perfect_window` (the first part of the i-frames) makes a dodge inside it a perfect dodge, which
gauges (`on_perfect_dodge`) and passives (DODGE) can reward.

### R4 · A launcher

R1, plus `launch = 0.6` (seconds the victim hangs in the air) and `cancel_on_hit = true` (the
next chain swing may start the moment it lands). Hits on a fighter already in the air keep it
up a little longer each time (`Juggle`), so the basic chain becomes an air combo.

### R5 · A grab and throw

A move whose `throw_move` is another striking move. When the grab lands and the victim flinches,
the victim is held and the throw plays at once. The throw itself must strike and must not
grab again (`ActionMove.problems`).

### R6 · One projectile

A SHOT event on the move: `kind = 2`, `at` (when it leaves), `shot` (a move used as the
projectile: its `power`, `hitbox_size`, and `active` = how long it flies), `amount` (speed in
m/s) and `offset` (where it starts, forward is −z). Arima's thrown IXA is a candidate; the
converter does not make shots yet.

### R7 · Many projectiles (a barrage)

```
[ext_resource type="Script" path="res://src/content/combat/powers/power.gd" id="power"]
[ext_resource type="Script" path="res://src/content/combat/action_move.gd" id="move"]
[ext_resource type="Script" path="res://src/content/combat/powers/mechanisms/barrage_mechanism.gd" id="barrage"]

[sub_resource type="Resource" id="blade_shot"]
script = ExtResource("move")
id = &"move/hero_blade_shot"
startup = 0.0
active = 1.5
recovery = 0.0
power = 6.0
hitbox_size = Vector3(0.5, 0.5, 0.8)

[sub_resource type="Resource" id="rain"]
script = ExtResource("barrage")
pattern = 0
count = 6
interval = 0.1
speed = 16.0
turn_rate = 4.0
shots = Array[ExtResource("move")]([SubResource("blade_shot")])

[sub_resource type="Resource" id="storm"]
script = ExtResource("power")
power_id = &"power/hero_storm"
name_key = "combat.power.hero_storm.name"
mechanism = SubResource("rain")
cooldown = 8.0
```

- `pattern`: 0 a ring behind the user (Gate of Babylon), 1 a ring around the target, 2 rain
  from above, 3 a line (a beam is a line with speed 0, `pierce` and a long box), 4 from the
  ground.
- `turn_rate` above 0 makes shots home in; `pierce` lets one pass through several foes.
- Several `shots` are played in turn (big, small, big). `elements` gives each shot a random
  element from the list.
- With no skill the power costs nothing and needs nobody in reach. Give it a cost-only skill
  (R1) to make it cost a gauge. In a battle it lands `count` hits on random foes.

### R8 · A trap

`PlantMechanism`: `where` (0 at the target, 1 at the user, 2 ahead by `distance`, 3 where a
barrage's shots fell), `count` and `spread`, an `eruption` move (the blast), and a `trigger`:
0 REMOTE (goes off the next time a power in `set_off_by` is used; `chain_delay` ripples
them), 1 PROXIMITY (a foe within `radius`), 2 TIMER (`seconds`; `turns` in a battle), 3 ON_HIT.
`lifetime` and `max_standing` keep the field tidy.

### R9 · A spell that hits whoever is aimed at

A power with only a skill: `target = 2` (ENEMY, the default), `power` above 0, `element`, maybe
`hits` (a flurry) or `scope = 1` (everyone in reach). It lands at once on the locked-on foe or
the nearest within 8 m, and works the same in a turn-based battle. Add `sure_hit = true` for a
spell that cannot miss, and `tags` (`magic`) for barriers and reflects to read.

### R10 · Buffs, debuffs, heals, poison

All of these are a skill's `statuses` or `effects`:

```
[ext_resource type="Script" path="res://src/content/combat/status_effect.gd" id="status"]
[ext_resource type="Script" path="res://src/content/combat/stat_modifier.gd" id="mod"]

[sub_resource type="Resource" id="half_def"]
script = ExtResource("mod")
stat = &"defence"
op = 1
value = 0.5

[sub_resource type="Resource" id="armour_break"]
script = ExtResource("status")
id = &"status/hero_armour_break"
name_key = "combat.status.hero_armour_break.name"
unit = 1
duration = 6.0
modifiers = Array[ExtResource("mod")]([SubResource("half_def")])
tags = Array[StringName]([&"debuff"])

[sub_resource type="Resource" id="bleed"]
script = ExtResource("status")
id = &"status/hero_bleed"
name_key = "combat.status.hero_bleed.name"
unit = 1
duration = 5.0
tick_pool = &"hp"
tick_change = -4
tick_interval = 1.0
tags = Array[StringName]([&"debuff"])
```

- A buff on yourself: a SELF skill whose status has modifiers (attack ×1.3).
- A debuff: an ENEMY skill with the status above, `status_chance` below 1 to make it a roll.
- A heal: `target = 1` (ALLY) and negative `power`, or a HEAL `effects` entry.
- Poison or bleed: a status with a negative `tick_change`; a regen is positive.
- A field status counts in SECONDS (`unit = 1`); one meant for battles counts in TURNS. A
  status in the wrong unit never runs out in the other formula.
- Stack it with `stacking = 1` and `max_stacks` (each stack adds the modifiers and the tick
  again).

### R11 · A style switch (the stance cycle)

One power with a `FormMechanism` whose `cycle` lists the styles. Each style is a
`FormMechanism` with its own `status` (tagged `form`, duration 0), `attack_chain`, optional
`dodge`, `look` and `name_key`. Give the cycle an `exclusive_group`. Then every special of a
style names that style's status in `requires_statuses`, and the quick slots swap with the style.
The example kit in section 3 has one; Arima's and Eto's slot 1 is exactly this.

### R12 · A transformation that costs and tires

A plain form (no cycle): its `status` holds the boosts (attack ×1.5, `knockback_taken` −1 for
super armour), `drain_pool` + `drain_per_second` spends the meter while it is held, and it ends
when the pool is empty. `requires_pool` + `requires_fraction` on the power demand enough meter
to enter. `aftermath` is a status put on when it ends by its own rules ("exhausted": defence
×0.7 for 5 s). `passive_skills` on the form lend passives only while transformed (put Eto's
`kakuja_regen` here, not on the kit). `look` changes the tint or the whole sprite set
(`LookDef.art`).

### R13 · A meter

Two stat bonuses on the kit (`max_<pool>` = the size, `start_<pool>` = 0 to start empty) and
one `GaugeRule` naming the same pool. Fill it with any of `on_hit_dealt`, `on_hit_taken`,
`on_perfect_dodge`, `on_kill`, `per_second`, `on_new_move` (rewards varied combos); drain it
with a negative number. `levels` turns thresholds into statuses (rank 1, 2, 3). The example
kit has one.

### R14 · A super that needs a full meter

```
[ext_resource type="Script" path="res://src/content/combat/powers/power.gd" id="power"]
[ext_resource type="Script" path="res://src/content/combat/action_move.gd" id="move"]
[ext_resource type="Script" path="res://src/content/combat/powers/mechanisms/finisher_mechanism.gd" id="finisher"]

[sub_resource type="Resource" id="verdict_strike"]
script = ExtResource("move")
id = &"move/hero_verdict"
startup = 0.0
active = 0.2
recovery = 0.3
power = 120.0
poise = 10
knockback = 4.0
hitbox_size = Vector3(4, 2, 4)

[sub_resource type="Resource" id="verdict_mech"]
script = ExtResource("finisher")
strike = SubResource("verdict_strike")
charge_time = 0.5
flourish = 0.6
reach = 10.0
drain_pool = &"spirit"

[sub_resource type="Resource" id="verdict"]
script = ExtResource("power")
power_id = &"power/hero_verdict"
name_key = "combat.power.hero_verdict.name"
mechanism = SubResource("verdict_mech")
cooldown = 2.0
requires_pool = &"spirit"
requires_fraction = 1.0
```

`charge_time` is the wind-up, `flourish` freezes the fight for that many real seconds (the
cinematic moment), then `strike` lands on the aimed foe, or on every foe within `reach` with
`all_foes = true`. `drain_pool` empties the meter. In a battle it charges for `charge_turns`
and lands at the start of the user's turn; a `charging` status with `breaks_on_hit` (or
`break_damage`) lets a foe knock the charge out of you.

### R15 · A shield

`BarrierMechanism` is a form, so it is entered and left like one: give it a `status` (the guard
is up while held) and a drain for upkeep. `mode` 0 NULLIFY stops every hit, 1 REDUCE leaves
`factor` of it, 2 TIMED_BLOCK (R16). `cost_per_block` from `cost_pool` charges per hit
stopped; when it cannot be paid, the barrier comes down and the hit lands. `bypass_tags`
lists hit tags that pass through (`domain`, `sure_hit`). `absorb_elements` turns hits of
those elements into points in `store_pool`. `scope = 1` guards allies too. With no status and
no cycle, it is always up (a passive power).

### R16 · A parry that strikes back

A barrier with `mode = 2` (TIMED_BLOCK) and a `timing` (`TimedWindow`: `opens`, `closes`,
`perfect`): a hit inside the window, counted from raising the guard, takes 0 and costs nothing.
Give the guard's status the COUNTER reaction (`reactions = [0]`, `reaction_chance = 1.0`) and a
`counter_move`: a hit blocked or landed is answered with that move, swung at the attacker.

### R17 · A teleport

`BlinkMechanism`: `to` 0 TARGET, 1 BEHIND_TARGET, 2 FORWARD (`distance`), 3 UP (`height`),
4 SWAP (trade places). `cancels_recovery` lets the fighter act at once after landing;
`arrival` is a status put on when it lands (a short invincibility); `path_strike` hits
everything on the line travelled (`path_width`). In a battle, `sooner` moves the user's next
turn forward.

### R17b · Helpers that fight beside you (summons)

`SummonMechanism`: `fighters` (one `CombatantDef` each) and `brains` (one `ActionBrain` each,
same order: its moves are what the helper swings), `spread` metres from the user, `lifetime`
seconds (0 = until sent away), `cap` (the most out at once; the oldest goes), and
`owner_status`, held while any is out. `untouchable` keeps every hit off them and every foe's
eye; `moves_each = 1` makes a summon that appears, does one move and goes. They leave when the user falls, the kit comes off or
the area is left. "Only while no helper is out" is `forbids_statuses = [<owner_status id>]` on
the other power. Helpers out in the field join a turn-based battle as guests on the party's side (C8.10d); using a summon during a battle is C8.10e. From a converted character,
list its helpers under `helpers` in the choices file and give the special `summons` (see
`tools/mugen/mugen_helpers.gd`; Eto's `eto_choices.json` is the example). To see them in a
capture, `--press=1,2` presses slots after the area lands.

### R18 · A domain

`BattlefieldMechanism`: `radius` and `seconds` (field) or `turns` (battle), and `effects`, each
a `BattlefieldEffect` saying `who` it touches (0 caster, 1 caster's side, 2 the other side, 3
everyone, 4 everyone but the caster) and what: `modifiers`, `statuses`, `on_enter`/`on_exit`
skills, a `tick` skill every `tick_seconds`, `pull` or `push`. `sure_hit = true` makes the
caster's hits inside unmissable, `hit_tags` tags them (`domain` passes barriers). Two domains
clash by `clash` and `refinement`. `place` and `weather` change how the area looks.

### R19 · Stronger by the situation

- Night only: `active_hours = Vector2(20, 4)` (wraps past midnight).
- Stronger as hp falls: a `PowerScaling` with `source = 1` (USER_MISSING_HP), `affects = 0`
  (POWER), `factor = 1.0`: ×1 at full hp, ×2 at none.
- Stronger with a fuller meter: `source = 2` (POOL_FRACTION) and `pool`.
- Longer on a marked foe: `source = 4` (TARGET_HAS_TAG), `tag`, `affects = 1` (DURATION).
- More shots: `affects = 3` (COUNT) on a barrage.
- By the hour: `source = 3` (CLOCK_CURVE) with a `curve`. Raise the curve's `max_value` above
  1, or it never goes past ×1.

Scaling works on a copy of the skill each time, so the kit's own numbers never change.

### R20 · A combination

Two primer powers each give a status (`status/primed_blue`, `status/primed_red`). The finisher
lists both in `requires_statuses` (it is refused until both are held) and in
`consumes_statuses` (using it takes them off). This is how Hollow Purple is planned.

### R21 · Untouchable for a while

A status with `invincible = true` and a short SECONDS duration: no hit touches the holder; each
is announced as blocked. `pierced_by` lists hit tags that still get through. Put it on a SELF
skill, a blink's `arrival`, or a form's status.

### R22 · Command, grant, refresh, sacrifice, foresight

- `command`: `order` 0 OBEY (the foe fights for you while the `status` lasts), 1 STOP, 2
  FORGET, 3 FALL; `reach` and `sight` (must be looking at it); `immune_tag` refuses.
- `grant`: `gifts` (statuses) or a whole `kit` lent to allies for `lasts`; `to_all` and
  `radius`; `with_user`.
- `refresh`: `fraction` of every remaining cooldown cut (0.5 halves), `pool` + `pool_gain`,
  and a `speed` status carrying `cooldown_rate`.
- `sacrifice`: takes `fraction` of each ally's hp (and `take_buffs`) to give the user `gain`.
- `foresight`: `rewrites` with `dodge` (turn a landing hit into a miss) or `force` (turn your
  miss into a hit), `observe`, `reveal`.

## 3. The example kit

A sword hero with two styles, a meter and a super, made only from the recipes above:

| Slot | Power | Recipe | Notes |
|---|---|---|---|
| 1 | Style Shift: blade ↔ storm | R11 | storm: attack ×1.25, defence ×0.8, a blue tint |
| 2 | Rising Cut (blade only) | R1 + R2 + R3 + R4 | 20 spirit, a lunge, i-frames, a launch |
| 2 | Storm of Blades (storm only) | R7 | six homing blades, 8 s cooldown |
| 3 | Iron Wall | R15 | halves hits; drains 4 spirit a second; needs 20% to raise |
| 4 | Final Verdict | R14 + R19 | full meter only; stronger the more hp is missing |
| — | the `spirit` meter | R13 | +5 hit dealt, +3 hit taken, +10 perfect dodge |

Copy it to `data/powers/<your_kit>.tres`, rename the ids and keys, and change the numbers.

<!-- example-kit:start -->
```
[gd_resource type="Resource" script_class="PowerKit" format=3]

[ext_resource type="Script" path="res://src/content/combat/powers/power_kit.gd" id="kit"]
[ext_resource type="Script" path="res://src/content/combat/powers/power.gd" id="power"]
[ext_resource type="Script" path="res://src/content/combat/skill.gd" id="skill"]
[ext_resource type="Script" path="res://src/content/combat/action_move.gd" id="move"]
[ext_resource type="Script" path="res://src/content/combat/status_effect.gd" id="status"]
[ext_resource type="Script" path="res://src/content/combat/stat_modifier.gd" id="mod"]
[ext_resource type="Script" path="res://src/content/combat/look_def.gd" id="look"]
[ext_resource type="Script" path="res://src/content/combat/powers/gauge_rule.gd" id="gauge"]
[ext_resource type="Script" path="res://src/content/combat/powers/power_scaling.gd" id="scaling"]
[ext_resource type="Script" path="res://src/content/combat/powers/mechanisms/form_mechanism.gd" id="form"]
[ext_resource type="Script" path="res://src/content/combat/powers/mechanisms/barrage_mechanism.gd" id="barrage"]
[ext_resource type="Script" path="res://src/content/combat/powers/mechanisms/barrier_mechanism.gd" id="barrier"]
[ext_resource type="Script" path="res://src/content/combat/powers/mechanisms/finisher_mechanism.gd" id="finisher"]

; ---- The meter (R13) ----

[sub_resource type="Resource" id="spirit_rule"]
script = ExtResource("gauge")
pool = &"spirit"
on_hit_dealt = 5.0
on_hit_taken = 3.0
on_perfect_dodge = 10.0

[sub_resource type="Resource" id="spirit_max"]
script = ExtResource("mod")
stat = &"max_spirit"
value = 100.0
source = &"kit/example_hero"

[sub_resource type="Resource" id="spirit_start"]
script = ExtResource("mod")
stat = &"start_spirit"
value = 0.0
source = &"kit/example_hero"

; ---- The two styles' basic chains ----

[sub_resource type="Resource" id="blade_1"]
script = ExtResource("move")
id = &"move/example_blade_1"
startup = 0.1
active = 0.1
recovery = 0.25
chain_after = 0.05
power = 10.0
hitbox_size = Vector3(1.4, 1.2, 1.6)
hitbox_offset = Vector3(0, 0.6, -1)

[sub_resource type="Resource" id="blade_2"]
script = ExtResource("move")
id = &"move/example_blade_2"
startup = 0.08
active = 0.1
recovery = 0.3
chain_after = 0.05
power = 12.0
knockback = 1.0
hitbox_size = Vector3(1.4, 1.2, 1.6)
hitbox_offset = Vector3(0, 0.6, -1)

[sub_resource type="Resource" id="storm_1"]
script = ExtResource("move")
id = &"move/example_storm_1"
startup = 0.15
active = 0.15
recovery = 0.3
chain_after = 0.1
power = 14.0
hits = 2
hitbox_size = Vector3(2.4, 1.2, 2.4)
hitbox_offset = Vector3(0, 0.6, -0.8)

; ---- The styles (R11) ----

[sub_resource type="Resource" id="blade_status"]
script = ExtResource("status")
id = &"status/form_example_blade"
name_key = "combat.form.example_blade.name"
duration = 0.0
tags = Array[StringName]([&"form"])

[sub_resource type="Resource" id="storm_attack"]
script = ExtResource("mod")
stat = &"attack"
op = 1
value = 1.25

[sub_resource type="Resource" id="storm_defence"]
script = ExtResource("mod")
stat = &"defence"
op = 1
value = 0.8

[sub_resource type="Resource" id="storm_status"]
script = ExtResource("status")
id = &"status/form_example_storm"
name_key = "combat.form.example_storm.name"
duration = 0.0
modifiers = Array[ExtResource("mod")]([SubResource("storm_attack"), SubResource("storm_defence")])
tags = Array[StringName]([&"form"])

[sub_resource type="Resource" id="storm_look"]
script = ExtResource("look")
look_id = &"look/example_storm"
tint = Color(0.6, 0.75, 1, 1)
label_key = "combat.form.example_storm.name"

[sub_resource type="Resource" id="blade_form"]
script = ExtResource("form")
status = SubResource("blade_status")
attack_chain = Array[ExtResource("move")]([SubResource("blade_1"), SubResource("blade_2")])
name_key = "combat.form.example_blade.name"

[sub_resource type="Resource" id="storm_form"]
script = ExtResource("form")
status = SubResource("storm_status")
attack_chain = Array[ExtResource("move")]([SubResource("storm_1")])
look = SubResource("storm_look")
name_key = "combat.form.example_storm.name"

[sub_resource type="Resource" id="style_cycle"]
script = ExtResource("form")
exclusive_group = &"example_style"
cycle = Array[ExtResource("form")]([SubResource("blade_form"), SubResource("storm_form")])

[sub_resource type="Resource" id="style_shift"]
script = ExtResource("power")
power_id = &"power/example_style_shift"
name_key = "combat.power.example_style_shift.name"
mechanism = SubResource("style_cycle")
cooldown = 1.0

; ---- Rising Cut (R1 + R2 + R3 + R4), blade only ----

[sub_resource type="Resource" id="focus"]
script = ExtResource("status")
id = &"status/example_focus"
name_key = "combat.status.example_focus.name"
unit = 1
duration = 2.0

[sub_resource type="Resource" id="rising_pay"]
script = ExtResource("skill")
id = &"skill/example_rising_cut"
name_key = "combat.power.example_rising_cut.name"
cost_pool = &"spirit"
cost = 20
target = 0
statuses = Array[ExtResource("status")]([SubResource("focus")])

[sub_resource type="Resource" id="rising_move"]
script = ExtResource("move")
id = &"move/example_rising_cut"
startup = 0.2
active = 0.15
recovery = 0.4
iframes_from = 0.0
iframes_to = 0.35
power = 28.0
poise = 3
knockback = 2.0
launch = 0.6
cancel_on_hit = true
hitbox_size = Vector3(1.6, 1.6, 2.0)
hitbox_offset = Vector3(0, 0.8, -1.2)
travel_speed = 12.0

[sub_resource type="Resource" id="rising_cut"]
script = ExtResource("power")
power_id = &"power/example_rising_cut"
name_key = "combat.power.example_rising_cut.name"
skill = SubResource("rising_pay")
move = SubResource("rising_move")
cooldown = 4.0
requires_statuses = Array[StringName]([&"status/form_example_blade"])

; ---- Storm of Blades (R7), storm only ----

[sub_resource type="Resource" id="blade_shot"]
script = ExtResource("move")
id = &"move/example_blade_shot"
startup = 0.0
active = 1.5
recovery = 0.0
power = 6.0
hitbox_size = Vector3(0.5, 0.5, 0.8)

[sub_resource type="Resource" id="storm_rain"]
script = ExtResource("barrage")
pattern = 0
count = 6
interval = 0.1
speed = 16.0
turn_rate = 4.0
shots = Array[ExtResource("move")]([SubResource("blade_shot")])

[sub_resource type="Resource" id="storm_of_blades"]
script = ExtResource("power")
power_id = &"power/example_storm_of_blades"
name_key = "combat.power.example_storm_of_blades.name"
mechanism = SubResource("storm_rain")
cooldown = 8.0
requires_statuses = Array[StringName]([&"status/form_example_storm"])

; ---- Iron Wall (R15) ----

[sub_resource type="Resource" id="wall_status"]
script = ExtResource("status")
id = &"status/example_iron_wall"
name_key = "combat.power.example_iron_wall.name"
duration = 0.0
tags = Array[StringName]([&"buff"])

[sub_resource type="Resource" id="wall"]
script = ExtResource("barrier")
mode = 1
factor = 0.5
status = SubResource("wall_status")
drain_pool = &"spirit"
drain_per_second = 4.0
drain_per_turn = 10.0

[sub_resource type="Resource" id="iron_wall"]
script = ExtResource("power")
power_id = &"power/example_iron_wall"
name_key = "combat.power.example_iron_wall.name"
mechanism = SubResource("wall")
cooldown = 2.0
requires_pool = &"spirit"
requires_fraction = 0.2

; ---- Final Verdict (R14 + R19) ----

[sub_resource type="Resource" id="verdict_strike"]
script = ExtResource("move")
id = &"move/example_final_verdict"
startup = 0.0
active = 0.2
recovery = 0.3
power = 120.0
poise = 10
knockback = 4.0
hitbox_size = Vector3(4, 2, 4)

[sub_resource type="Resource" id="verdict_mech"]
script = ExtResource("finisher")
strike = SubResource("verdict_strike")
charge_time = 0.5
flourish = 0.6
reach = 10.0
drain_pool = &"spirit"

[sub_resource type="Resource" id="desperate"]
script = ExtResource("scaling")
source = 1
affects = 0
factor = 1.0

[sub_resource type="Resource" id="final_verdict"]
script = ExtResource("power")
power_id = &"power/example_final_verdict"
name_key = "combat.power.example_final_verdict.name"
mechanism = SubResource("verdict_mech")
cooldown = 2.0
requires_pool = &"spirit"
requires_fraction = 1.0
scaling = Array[ExtResource("scaling")]([SubResource("desperate")])

; ---- The kit ----

[resource]
script = ExtResource("kit")
kit_id = &"kit/example_hero"
name_key = "combat.kit.example_hero.name"
powers = Array[ExtResource("power")]([SubResource("style_shift"), SubResource("rising_cut"), SubResource("storm_of_blades"), SubResource("iron_wall"), SubResource("final_verdict")])
stat_bonuses = Array[ExtResource("mod")]([SubResource("spirit_max"), SubResource("spirit_start")])
gauges = Array[ExtResource("gauge")]([SubResource("spirit_rule")])
```
<!-- example-kit:end -->

**Why the slots work out:** the kit lists five powers, and only four keys exist. Rising Cut
needs the blade status and Storm of Blades the storm status, and both are statuses this kit
grants, so only one of them takes a slot at a time: blade is Shift, Rising Cut, Iron Wall,
Final Verdict; storm is Shift, Storm of Blades, Iron Wall, Final Verdict. Before the first
press of 1 neither style is held, so the slots are Shift, Iron Wall and Final Verdict.

**Iron Wall is not in the style group,** so raising it never drops your style. Put it in
`example_style` and it would.

## 4. Putting a kit in the game

1. **The kit file:** `data/powers/<name>.tres`. Every id unique: `kit/<name>`,
   `power/<name>_<x>`, `move/<name>_<x>`, `status/<name>_<x>`, `skill/<name>_<x>`.
2. **The strings:** every `name_key` and `desc_key` in `localization/strings.csv` (quote any
   value that has a comma). `combat.kit.<name>.name`, `combat.power.<name>_<x>.name/.desc`,
   `combat.form.<name>_<x>.name`, `combat.status.<name>_<x>.name`.
3. **The fighter:** copy `data/action/arima_loadout.tres` to `data/action/<name>_loadout.tres`.
   Set its `CombatantDef`'s `combatant_id`, `name_key`, `base_stats` and `power_kit` (your
   kit), and its `MoveSet`'s `attack_chain` and `dodge` (the moves used before any style is
   chosen). Remove `art` if the hero has no sprite set yet; the placeholder look is used.
4. **Play as it:** in `project.godot`, `[combat] action/loadout="res://data/action/<name>_loadout.tres"`.
   Or give the kit to a party member's or a boss's `CombatantDef.power_kit`; enemies use
   powers too.
5. **Check:** `godot --headless --import`, then
   `godot --headless --script tools/check_content.gd`. It runs every `problems()` and lists
   what is wrong, file by file. Then the full ladder before committing.

Real character names go only in `data/`, `localization/`, `assets/`, `docs/` and `tools/`,
never in `src/` or `tests/` (`tools/check_boundary.gd` fails the build).

## 5. When no recipe fits: a new mechanism

First check that it really needs code. Most "new" powers are a status flag, a scaling rule, or
two existing mechanisms on two powers. [`POWER_ATLAS.md`](POWER_ATLAS.md) sorts 116 families
of powers onto existing parts; look your idea up there.

If it does need code, it is two files and one line, and nothing else changes:

1. **The data:** `src/content/combat/powers/mechanisms/<thing>_mechanism.gd`,
   `class_name <Thing>Mechanism extends PowerMechanism`. Only typed `@export`s, plus
   `func kind() -> StringName: return &"<thing>"`, `problems(context)` for every bad value,
   and `statuses()` if it puts statuses on (so a save can find them). Copy
   `refresh_mechanism.gd`.
2. **The behaviour:** `src/gameplay/combat/powers/mechanisms/<thing>_run.gd`,
   `class_name <Thing>Run extends PowerExecutor`. Override only the hooks you need (guide
   § 10). Give it a meaning in BOTH formulas: `Combatant.real_time` tells you which one you
   are in. Copy `refresh_run.gd`.
3. **The registry:** one line in `PowerMechanisms.BUILT_IN`:
   `&"<thing>": "res://src/gameplay/combat/powers/mechanisms/<thing>_run.gd"`.
4. **The test:** `tests/unit/<thing>_test.gd`, building its own kit in code (never a real
   character), registered in the runner like its neighbours; `power_use_test.gd` and
   `barrage_test.gd` show the shape.
5. **The rules the checkers enforce:** a plain-words header with OWNS and MUST NOT; 250 lines a
   file and 40 a function; every public method has a caller; tabs; no player-facing text.
6. **The docs:** a row in [`POWERS.md`](POWERS.md)'s mechanism table and in guide § 10.

## 6. Checking it works

`check_content` proves the data is well formed. `tools/kit_probe/` proves it plays: it builds a
hero wearing the kit and a foe in front, fills the gauges, enters each style of the kit's style
cycle in turn, presses every other quick slot, and prints what each press did.

```
godot --headless res://tools/kit_probe/kit_probe.tscn -- --kit=res://data/powers/<your_kit>.tres
godot --headless res://tools/kit_probe/kit_probe.tscn -- --cookbook
```

Add `--wall` to stand a wall between the hero and the foe: every press must then show
"foe took 0", and the hero's furthest z must stay above the wall's (-0.75). Add `--ledge` to end
the floor 1 m in front of the hero, with the foe over the drop: a lunge must stop at the edge
(z no lower than about -0.6, y 0). Arima, Eto and the example hero pass both (C9.12).

`--cookbook` tries the example kit in section 3, read straight from this page. Its output on
2026-11-15:

```
KIT kit/example_hero  problems: []
== style switch: true
slot 2 power/example_rising_cut: used, foe took 35, spirit 85/100
slot 3 power/example_iron_wall: used, foe took 0, spirit 91/100
slot 4 power/example_final_verdict: used, foe took 135, spirit 0/100
== style switch: true
slot 2 power/example_storm_of_blades: used, foe took 107, spirit 100/100
slot 3 power/example_iron_wall: used, foe took 0, spirit 91/100
slot 4 power/example_final_verdict: used, foe took 127, spirit 0/100
```

Reading it: Rising Cut paid 20 and won 5 back on its hit; Iron Wall deals nothing (it is a
shield: a probe hit of 40 took 48 without it and 26 behind it, and it drained about 4 spirit a
second); Final Verdict emptied the meter. A refused press prints its `PowerUse.Reason`
(COOLDOWN, STATUS, POOL, COST...). "foe took 0" on a power that should hit means its hitbox
never met the foe 1.5 m ahead: check `hitbox_size`, `hitbox_offset` and `active`.

For anything the tool does not cover (a barrier's effect, a status landing, a foe hitting
back), write a throwaway probe scene the same way: `tools/kit_probe/kit_probe.gd` is the
pattern (a floor, `CombatActions.install()`, `ActionHost.equip`, a dummy foe, then
`ActionFighter.press_slot` and `await get_tree().physics_frame`). A scene, not a `--script`:
a `--script` run cannot see the autoloads. When it shows something worth keeping, turn it into
assertions in `tests/unit/`.

## 7. The main character's planned powers

[`POWERS.md`](POWERS.md) § The characters designs each planned character in full. Which
recipes each one leans on:

| Character | Recipes |
|---|---|
| Gilgamesh | R7 (Gate of Babylon), R14 (Enuma Elish), R10 + R19 (Enkidu binds the divine longer) |
| Arima | R11 (quinques), R1–R4 (specials), R15 (IXA shield), R16 (counters), R22 foresight (reading) |
| Gojo | R15 (Infinity), R18 (Unlimited Void), R17 (teleport), R20 (Hollow Purple), R14 |
| Escanor | R19 (stronger toward noon), R12 (The One), R18 (heat aura) |
| Lelouch | R22 command (Geass), R22 grant (tactics) |
| Yhwach | R22 foresight (The Almighty), R15 (Blut Vene), R7 (Heilig Pfeil), R22 grant and sacrifice |
| Barnabas and Odin | R12 (the Eikon), R14 (Zantetsuken on its own meter, R13), R7 (blades) |
| Vergil | R7 (Summoned Swords), R12 (Devil Trigger), R17 (trick), R14 (Judgment Cut End) |
| Dante | R11 (four styles), R13 (style rank via `on_new_move`), R12 (Devil Trigger), R16 (Royal Guard) |
| Isliid | R11 with `advance_after`, R22 refresh (Super Arts) |
| Roland | R11 (forms), R12, `knockback_taken` −1 (super armour) |
| Eto | R11 (kakuja), R1–R3 (specials); her summons wait for owned fighters (C8.10) |

A new hero of your own design: list what each power should feel like, find each feeling in
the table in section 1, and build the kit in the order of section 3: meter, styles, specials,
defence, super.
