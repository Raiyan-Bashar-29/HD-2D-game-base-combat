# A Visual Guide to RPG/Gacha Combat Mechanics

## 1. The universal ability pipeline

Think of an ability as an instruction card describing **when** an effect is allowed to happen and **what** it changes.

```text
EVENT (player clicks skill / turn starts / boss HP drops)
  |
  v
CONDITION (have MP? cooldown ready? is target valid?)
  | if false -> do nothing
  v
PAY COST (MP, Arts, SP, cards, cooldown, HP)
  |
  v
SELECT TARGET (self, ally, nearest enemy, all enemies, tile)
  |
  v
RESOLVE EFFECTS (damage, shield, buff, debuff, summon)
  |
  v
RUN POST-EVENT PASSIVES (counterattack, on-hit poison, Arts gain)
  |
  v
SCHEDULE REMOVAL (when status duration / HP / stacks / phase ends)
```

EXAMPLE: A skill has 20 MP cost, 10 second cooldown, shoots 3 lightning bolts, and applies a 4-second stun with 30% probability. The system first checks MP and cooldown; next it takes 20 MP; for each bolt it picks a target and resolves damage; then it rolls the stun application and stores an expiry timer. It does not invent extra targets.

## 2. Active skill vs passive vs buff vs debuff

- **Active skill**: something the player or AI chooses to execute. It has a cast event and often a cost.
- **Passive**: listens for an event, such as `onAllyHit`, and automatically does something *if a condition is true*.
- **Buff**: temporary beneficial state (Shield, Attack Up, HP Regen). May be produced by active skills or passives.
- **Debuff**: temporary harmful state (Burn, Poison, Silence, Defense Down). Application may fail due to resistance and immunity.
- **Boss mechanic**: a subsystem or scripted event often tied to HP thresholds, time, or player objectives.

The same action may contain all four: **an active attack** applies **a debuff**, which triggers **a passive**, while also crossing **a boss HP threshold**.

## 3. Bosses are state machines, not just very high-HP enemies

```text
PHASE ONE --(HP threshold)--> PHASE TWO
     |                         |
     |                         +-- Trigger hazard / spawn add / attack
     |
     +--(HP becomes 0, extra bar exists)--> REVIVE / PHASE CHANGE
     |
     +--(HP becomes 0, final attack queued)--> FINAL MOVE --> DEATH
```

**Named examples** (check individual source links): Emperor's Blade casts Dominion hazards on the grid; Grand Summoners has final-attack and condition-gated bosses; Aventurine's gamble has a dice contest; Hod accumulates crowd-control toward an opening; Granblue V2 previews omens with cancellation objectives.

## 4. Why similar-looking Break systems are not the same

| Game | What depletes? | What follows? |
| --- | --- | --- |
| Last Cloudia | Boss Break gauge | Short high-damage opening with reduced defense |
| Honkai: Star Rail | Elemental Toughness from matching weakness | Delayed damage/status effects with enemy action disruption |
| Octopath Traveler CotC | Shield points, often via hit counts at weakness | A multi-turn vulnerability window |
| Grand Summoners | Break gauge / separate Break contributors | Boss-specific opening and sometimes unique state changes |
| Blue Archive Hod | CC accumulation / groggy | Damage opportunity with raid-specific raid bars |

A program can reuse `BreakMeter` as an interface, but *not* a single shared formula for every game.

## 5. Stacking: the hidden rule that breaks naive game engines

Consider two characters providing `Arts regeneration +3/sec`.

**Additive**: +6/sec. **Unique / exclusive**: only +3/sec. **Highest only**: keep the stronger one. **Refresh**: reset timer without doubling. **Independent**: store two buff instances with independent expiries.

Grand Summoners explicitly has Arts-generation stacking groups; a production game engine needs a `stackGroup` and `stackPolicy` field per effect.

## 6. Practical database table design

An expandable, relational setup would have:

```text
Game(game_id, name)
Entity(entity_id, game_id, name, kind)
Ability(ability_id, entity_id, name, ability_layer, cost_kind, cost, cooldown)
Effect(effect_id, ability_id, effect_kind, scale, target_rule, duration)
Trigger(trigger_id, ability_id, event, condition)
Status(status_id, name, stacking_policy, stacking_group)
BossPhase(phase_id, entity_id, hp_start, hp_end)
BossEvent(event_id, phase_id, trigger, telegraph, effect, cancel_condition)
Reference(reference_id, url, accessed_at, confidence)
```

This v1 CSV is a **human-readable intermediate** format; it is not yet a lossless relational dump of all character-level game content.

## 7. How to translate a row into runnable logic

Example: Arknights operator skill charges 1 SP per attack.

```python
class Skill:
    def __init__(self, needed_sp):
        self.sp = 0
        self.needed_sp = needed_sp

    def on_normal_attack(self):
        self.sp = min(self.needed_sp, self.sp + 1)

    def can_cast(self):
        return self.sp == self.needed_sp

    def cast(self):
        if not self.can_cast():
            return False
        self.sp = 0  # optional: some operator skills have different reset/charges
        return True
```

Trace: start at SP=0, after 1st hit SP=1, after required hit count SP=needed, player can activate; activation resets SP in this illustrative variant. This is *not* Arknights source code, nor the universal SP scheme for every operator.

## 8. What to research next to make it exhaustive

For every game: (1) authoritative unit roster + version, (2) every skill ID and level, (3) exact effect formulas and target rules, (4) stack group and update rules, (5) every boss encounter + phase requirements, (6) patch version and source URLs, (7) deterministic reproducible simulations. Separate game server/datamined data from community interpretation; obtain permissions for any copyrighted bulk reuse. The current package covers representative mechanics and supports gradual verification, but is explicitly not all content.
