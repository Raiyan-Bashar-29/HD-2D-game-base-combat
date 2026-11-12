# The power atlas: the owner's power list, sorted onto mechanisms

**Written by C6.0c, 2026-11-11.** On 2026-11-10 the owner gave this project a list of **3,306
fictional powers** (2,104 named ones and 1,202 general types), each with a description and a
proposed "coding logic", plus researched move lists for 127 characters. This page sorts all of
it onto the mechanisms this fork builds, so that each kind of power is **coded once** and a
character is then a data file that combines them.

Read [`POWERS.md`](POWERS.md) first for the framework (`PowerKit`, `Power`, the mechanisms
M1–M14) and [`GEAR.md`](GEAR.md) for gear, battlefields (M4), M15 `plant` and transformations.

## The rules in one screen

- **The owner's rule (2026-11-10): build mechanisms, not every power.** The list routes its
  3,306 powers through **116 handler families**. A family is one reusable piece of code. Many
  families are the same mechanism with different numbers, so the 116 come down to the fifteen
  mechanisms already designed, the parts already built, and **six new board rows** (below).
- **The list's own warnings, kept:** its pseudocode is a proposal, not canon and not code that
  runs; a missing number (damage, range, cooldown) is unknown, not zero, and is ours to choose
  as game balance; a power *type* ("Fire Manipulation") is a category, not a character's move;
  never give a character every power of its universe, only the ones its own profile lists.
- **Real names stay in data and docs**, never under `src/` or `tests/` (`check_boundary`).
- **A kit row cites this page:** when a character's kit is built (rows C6.14 onward), read its
  profile in `reference/power_pack/characters/`, find each move's family in
  `reference/power_atlas.csv`, and use the mechanism this page names for that family.

## Where the list lives

| File | What it is |
|---|---|
| [`reference/originals/Fictional_Powers_Execution_Logic_Claude_Pack.zip`](reference/originals/Fictional_Powers_Execution_Logic_Claude_Pack.zip) | **The whole pack, exactly as the owner gave it** (4.9 MB; 45 MB unpacked). Everything else here is cut from it |
| [`reference/originals/fictional_weapons_multiverse_with_image_links.csv`](reference/originals/fictional_weapons_multiverse_with_image_links.csv) | The owner's full weapons list, with its image columns (`reference/weapon_ideas.csv` is the slim copy) |
| [`reference/power_atlas.csv`](reference/power_atlas.csv) | One row per power, 3,306 rows: id, name, universe or category, kind, owner (and how sure), handler family, delivery, a one-line summary |
| [`reference/power_handlers.csv`](reference/power_handlers.csv) | One row per handler family, 116 rows: how many powers, its title, its proposed steps, three examples |
| [`reference/power_pack/`](reference/power_pack/) | The pack's three guide pages, and every character profile (`characters/<Name>.json`) |
| [`reference/README.md`](reference/README.md) | How to unpack the zip and what is inside |

## The pack's engine contract, and what already answers it

The pack describes the services a power engine needs. Most exist here under another name.

| The pack's name | Here | State |
|---|---|---|
| `AbilityDefinition` | `Power` (in a `PowerKit`), `Skill`, `PowerMechanism` | Built (C6.1) |
| `AbilityRunner` (validate, pay, wind up, effect, recover) | `PowerUse.refusal` and `use`; `SkillUse`; `MoveTimeline` for wind-up and recovery | Built |
| `CharacterDefinition`, `CharacterRuntime` | `CombatantDef`; `Combatant` + `Vitals` + `StatusSet` + `PowerSet` | Built |
| `HitResolver` (factions, defences, hit once) | `Hurtbox` (once per swing), `Combatant.can_target`, `Combatant.receive` with the guard hook, `DamageFormula` | Built |
| `StatusController` | `StatusSet` | Built |
| `TransformStateMachine` | `FormMechanism` + `FormRun` | Built; the look is C6.5d |
| `EventBus` (before and after a hit) | `Events`; the one guard hook in `Combatant.receive` (`PowerGuard.incoming`) | Built |
| `EffectTransaction` (pay once, never twice) | `PowerUse.use` refuses before it pays; single-player, so no network retries | Built |
| `OwnedEntityRegistry` (summons that know their owner) | Nothing yet | **New, C8.10** |
| `TemporalBuffer` (a record of the past) | Nothing yet | **New, C8.11** |

**The pack's test list is this fork's test rule for every mechanism row:** a fighter that does
not hold the power cannot use it and pays nothing; targets, factions, immunity and resistance
are checked; an interrupt, a defeat or leaving the area cleans up everything the power made;
multi-hit, reflect and pierce follow the power's own flags; a save and load neither doubles nor
loses a summon or a form; two effects at once resolve in a fixed order.

## The 116 families, sorted

**State** reads: BUILT (works today, with the row that built it), PLANNED (a board row already
covers it), NEW (a row added by this page), OUT (story or non-combat; nothing to build in a
fight). "Powers" is how many of the 3,306 the family holds.

### Strikes and shots

| Family | Powers | In plain words | What runs it here | State | Examples |
|---|---|---|---|---|---|
| `melee_hitbox` | 178 | A swing that hurts only during its active frames, once per target | `ActionMove` + `MoveTimeline` + `Hitbox`/`Hurtbox`; in a battle a `Skill` | BUILT (C3.2–C3.4) | Tsubame Gaeshi; Bites the Dust; Tusk ACT 4 — Infinite Rotation |
| `projectile` | 129 | One moving shot that hits what it meets | M1 `barrage` with `count` 1, the `Projectile` node | BUILT C6.7 | Gura Gura no Mi; The X-Axis; Spirit Bomb / Genki Dama |
| `explosion_aoe` | 77 | A burst that hits everyone in a radius | A `Skill` with scope ALL; in the field a sphere `Hitbox` on `ActionMove` | BUILT; the delayed kind is M15 `plant` (BUILT C6.26) | Mafuba / Evil Containment Wave; Explosion; Adolla Burst |
| `magic_cast` | 45 | A spell: pay, wind up, effect | `Skill` + `SkillUse`; `Power` for cooldowns and conditions | BUILT (C2.13, C6.1) | Byakugan; Rinnegan; Shinsu Baang |
| `beam_hitscan` | 31 | An instant line that hits everything along it | M1 `barrage` pattern LINE with `speed` 0 (a line `Hitbox` for one frame) | BUILT C6.7 | Excalibur; Cero; 100-Type Guanyin Bodhisattva |
| `volley_projectiles` | 12 | A fan, volley or rain of shots | M1 `barrage` patterns | BUILT C6.7 | Highwind Limit; Lion Heart; Oblivion |
| `skill_performance` | 10 | Change combo timing and cancel windows | `ActionMove` chain windows; a form's own `attack_chain` | BUILT; launch and juggle are C8.8 | Dual Casting; Jeahbongchim; Vivi's Double Black |
| `charge_stat_burst` | 2 | Charge up, then act much stronger | M2 `finisher` (charge) or a timed status | PLANNED C6.8 | Geomancy; Geomancy |
| `ukaku_projectiles` | 1 | A shard volley from a manifested weapon that stays out after firing | M1 `barrage` used inside a form (M5) | BUILT C6.7 | Ukaku Kagune |
| `world_rending_burst` | 1 | One huge directed discharge that breaks battlefields | M2 `finisher` with `broken_by_tags` on battlefields (Ea) | PLANNED C6.8, C6.9c | Ea — Enuma Elish |
| `charge_mount` | 1 | Ride something and ram | A form (M5) whose attack chain is a travelling move | BUILT as parts (C6.5b) | Bellerophon |
| `tail_kagune` | 1 | A body weapon that both strikes and guards | A form (M5) with its own moves plus M3 `barrier` REDUCE | BUILT as parts (C6.5, C6.6a) | Bikaku Kagune |

### Guards

| Family | Powers | In plain words | What runs it here | State | Examples |
|---|---|---|---|---|---|
| `barrier_shield` | 197 | Stop, soften or bounce what reaches you | M3 `barrier` (NULLIFY, REDUCE, timed block), REFLECT and COUNTER statuses | BUILT (C6.6a–b, C2.15) | Avalon; Rho Aias; Made in Heaven |
| `spatial_barrier` | 38 | A wall in space that blocks passage or hits | M3 `barrier` with scope ALLIES; a solid wall is a construct | BUILT in part; NEW C8.14 for walls | The Hand; Kamui; Gravity Magic |
| `magic_counter` | 19 | Answer or cancel a spell | REFLECT status; M13 `counter_stance` | BUILT in part; PLANNED C6.6d | Anti-Magic; No Longer Human; Disturb Magic |
| `survival_trait` | 15 | Ignore a hazard (no air, heat, poison) | `resist_<tag>` stats and immunity at 1 | BUILT (C2.14) | Pain Suppression; Breath Independence; Sleep Independence |
| `asymptotic_barrier` | 1 | A layer nothing reaches unless it carries the right tag | M3 `barrier` NULLIFY with `bypass_tags` | BUILT (C6.6a) | Limitless — Infinity |

### Forms and the body

| Family | Powers | In plain words | What runs it here | State | Examples |
|---|---|---|---|---|---|
| `transform_form` | 116 | Become another form with its own stats, moves and look | M5 `form`; the look swap is `LookDef` | BUILT (C6.5a–c); look PLANNED C6.5d | Hobi Hobi no Mi; Eight Gates; Shikai |
| `buff_modifier` | 107 | Raise stats for a while | `StatusEffect` with `StatModifier`s | BUILT (C1.5) | Conqueror's Haki; Nen Enhancement; Terpsichora |
| `passive_physiology` | 49 | An always-on trait | `PowerKit.passives` and `stat_bonuses` | BUILT (C6.1) | The Miracle; Ultra Instinct; Shinsu Reinforcement |
| `body_material` | 46 | Turn the body into fire, steel, rubber | A form (M5) holding resist and `absorb_elements` (M3) | BUILT as parts | Sticky Fingers; Stone Free; Armament Haki |
| `growth_progression` | 37 | Get stronger over time or by fighting | `LevelCurve` and `Party.gain`; M6 `gauge` within a fight | BUILT (C2, C6.4) | Devil Fruit Awakening; Ito Ito no Mi; Fairy Law |
| `regeneration` | 26 | Heal steadily, even from bad wounds | `regen_hp` stat or a status tick | BUILT (C2.16) | Rinkaku Kagune; Beast Beneath the Moonlight; C.C. — Code Immortality |
| `evolve_skill` | 24 | A skill that upgrades into a better one | `Power.requires_upgrade`, `UpgradeTrack` | PLANNED C7.5 | Nen Specialization; Emperor Time; One For All |
| `companion_form` | 8 | A stand or avatar that fights beside its owner | An owned fighter (below) linked to its owner's hp | NEW C8.10 | Dark Shadow; Tyranid Shadow in the Warp; Force Projection |
| `age_modifier` | 2 | Make a target older or younger | A status with stat modifiers | BUILT as a status; the story side is OUT | Age Acceleration; Age Regression |
| `element_type_swap` | 2 | Change a fighter's element for a while | A status changing `resist_<element>`; worn gear's `element` | BUILT as parts (C7.1c) | Protean; Protean |
| `kakuja_transform` | 1 | A heavy form with its own body and big attacks | M5 `form` with a look and battle commands | PLANNED C6.5d | Kakuja |
| `distributed_body_parts` | 1 | Hands or parts that act at a distance | Owned things with their own hitboxes | NEW C8.10 | Hana Hana no Mi |

### Fields, places and space

| Family | Powers | In plain words | What runs it here | State | Examples |
|---|---|---|---|---|---|
| `construct_matter` | 311 | Make or shape matter: walls, weapons, objects | Things placed in the arena that block, hurt or can be thrown | NEW C8.14, on M15 `plant` (C6.26) and C8.9 | C-Moon; Magu Magu no Mi; Wood Release |
| `persistent_field` | 126 | A zone that keeps acting on whoever is inside | M4 battlefield: statuses, ticks, pull | PLANNED C6.9a–b | Weather Report; Self-Embodiment of Perfection; Deadly Sentencing |
| `materialized_art` | 36 | A drawing or idea made real | A construct or an owned fighter | NEW C8.14, C8.10 | Ichimonji; Arthur — Plasma Excalibur; The Matchless Poet |
| `craft_creation` | 25 | Make items | `Recipe` and `Crafting` | PLANNED C7.6 | Killer Queen — Bomb Transmutation; Nen Transmutation; Godspeed |
| `terrain_control` | 19 | Reshape the ground | M4 battlefield effects; things in the arena | PLANNED C6.9, C8.9 | Chidori; Creation; Ultrahand |
| `make_energy` | 17 | Make and store energy | A pool with `regen_<pool>`; M6 `gauge` | BUILT (C2.16, C6.4) | Goro Goro no Mi; Third Generation Pyrokinesis; Nezuko — Exploding Blood |
| `pocket_space` | 15 | Take the fight into a closed world with its own rules | M4 battlefield `closed`, `moves_fight`, `PlaceLook` | PLANNED C6.9c–d | Unlimited Void; Imaginary Space; Eternity Devil |
| `gravity_well_prison` | 2 | Pull everything in and hold it | M4 battlefield `pull` plus a hold status | PLANNED C6.9b | Six Paths: Planetary Devastation |
| `terrain_cast_random` | 1 | A spell that depends on where you stand | `PowerScaling` reading the area or battlefield tag | NEW C8.15 (a scaling source) | Geomancy |
| `impassable_prison` | 1 | A cage nobody leaves | M4 battlefield `closed`; NO_FLEE | PLANNED C6.9c | Forcecage |
| `restricted_chain_grapple` | 1 | Bind one target; it cannot act or use powers | A status with SKIP_TURN and NO_SKILLS | BUILT (C2.14) | Chain Jail |
| `gravity_nullifier` | 1 | A field that also switches others' powers off | M4 battlefield plus the power seal | NEW C8.13 (seal) | Yami Yami no Mi |
| `imagined_construct` | 1 | Anything imagined, while concentration holds | A construct with upkeep, ended when the maker is hit | NEW C8.14 | The Visionary |
| `matter_fabrication` | 1 | Build an item from a blueprint and materials | `Recipe` and `Crafting` | PLANNED C7.6 | Creation |
| `material_decay_spread` | 1 | A touch that rots and spreads | A status with a tick that spreads to neighbours | NEW C8.15 (spreading status) | Decay |
| `material_stasis` | 1 | Lock a thing so it cannot change | A status granting immunity and SKIP_TURN | BUILT as a status | Unchange |

### Movement

| Family | Powers | In plain words | What runs it here | State | Examples |
|---|---|---|---|---|---|
| `mobility` | 76 | Dash, fly, leap | The dodge move; M9 `blink` FORWARD and UP | BUILT in part; PLANNED C6.12 | Pika Pika no Mi; Star Magic; Accelerator — Vector Control |
| `teleport` | 41 | Appear somewhere else | M9 `blink` | PLANNED C6.12 | Flying Thunder God; Instant Transmission; Teleport |
| `stealth_visibility` | 35 | Be unseen | A status foes cannot target or lock on to, broken by acting | NEW C8.12 | Invisible Providence; Unseen Hands; Stealth |
| `dimensional_transit` | 28 | Step through another space | M9 `blink` with i-frames; a battlefield that moves the fight | PLANNED C6.12, C6.9d | D4C; Escape Instant Dungeon; Fixed Immortal Travel |
| `portal_link` | 23 | Two linked doors | A pair of placed things that move whoever enters | NEW C8.14 | Gate of Babylon; Hide and Seek; Spatial Magic |
| `teleport_swap` | 3 | Two fighters trade places at once | M9 `blink` with `to` SWAP | PLANNED C6.12 (add SWAP to its row) | Boogie Woogie; Ope Ope no Mi — Shambles |
| `owned_shadow_swap` | 1 | Trade places with your own summon | M9 `blink` SWAP with an owned fighter | NEW C8.10 after C6.12 | Shadow Exchange |
| `void_movement` | 1 | Vanish, and erase what you pass through | M9 `blink` whose path is a hitbox | PLANNED C6.12 (path hit) | Cream |

### Time

| Family | Powers | In plain words | What runs it here | State | Examples |
|---|---|---|---|---|---|
| `temporal_rate` | 31 | Speed up or slow down | `time_rate` per fighter; `speed` in a battle | NEW C8.11 | Epitaph; Shinra — Adolla-Linked Speed; Flawless |
| `temporal_loop` | 14 | Replay a stretch of the story | A save and reload is the game's own loop | OUT (story, not combat) | Return by Death; The Flash — Speed Force; Cosmic Treadmill |
| `temporal_stop` | 7 | Stop time for others | `CombatClock` at 0 with the user exempt | NEW C8.11 | Star Platinum — Time Stop; Homura — Time Stop; Time Stop |
| `temporal_rewind` | 6 | Put things back as they were | A time record: positions, hp and statuses each tick, restored on demand | NEW C8.11 | Rewind; Time Magic |
| `temporal_skip` | 3 | Skip a slice of time | The user acts while others' clocks jump | NEW C8.11 | Time-Skip |
| `personal_state_rewind` | 2 | Put yourself back a few seconds | The time record, one fighter | NEW C8.11 | Ekko: Chronobreak; Tracer: Recall |
| `personal_time_stop` | 1 | Stop chosen fighters only | A per-fighter `time_rate` stat read beside `CombatClock` | NEW C8.11 | The World — Time Stop |
| `time_erasure` | 1 | See what is coming, then erase that slice | M7 `foresight` DODGE plus a skip | PLANNED C6.10, NEW C8.11 | King Crimson — Time Erasure |
| `object_motion_rewind` | 1 | Run an object's path backwards | The time record on a placed thing or projectile | NEW C8.11 | Recall |
| `return_anchor` | 1 | Mark a point and come back to it | The time record with one saved point | NEW C8.11 | Phoenix: Run It Back |

### Summons and copies

| Family | Powers | In plain words | What runs it here | State | Examples |
|---|---|---|---|---|---|
| `summon_entities` | 107 | Call fighters that fight for you | An owned-fighter list: each summon knows its owner and power, and leaves with it | NEW C8.10 (field); battle side C8.3 | Ten Shadows Technique; Divine General Mahoraga — Adaptation; Dragon of the Darkness Flame |
| `clone_actor` | 15 | A double of yourself | M10 `clone` | PLANNED C6.13 | Shadow Clone Technique; Fusion Dance; Potara Fusion |
| `autonomous_support` | 8 | A helper that reacts on its own | An owned fighter with an `ActionBrain`/`BattleBrain` | NEW C8.10 | Raphael, Lord of Wisdom; Ciel; Gambits |
| `animal_control` | 4 | Tame or command beasts | M8 `command` OBEY limited by tag | PLANNED C6.11 | Puff!; Bend Will; Animalism |
| `copy_previous_action` | 2 | Repeat the last move used | M10 `clone` battle reading (act twice); the last command remembered | PLANNED C6.13 | Mimic; Mimic (Gogo) |
| `corpse_to_summon` | 1 | Raise a fallen foe as your soldier, kept in a roster | Owned fighters plus a saved roster in `Flags` | NEW C8.10 | Shadow Extraction |
| `life_from_object` | 1 | Turn an object into a creature | An owned fighter spawned from a placed thing | NEW C8.10 | Gold Experience — Life Creation |

### Mind, control and powers themselves

| Family | Powers | In plain words | What runs it here | State | Examples |
|---|---|---|---|---|---|
| `status_ailment` | 117 | Poison, burn, petrify, slow, root | `StatusEffect` ticks, blocks and modifiers | BUILT (C1.5, C2.14); C8.7 for the rest | Gáe Bolg; Mystic Eyes of Petrification; Enkidu — Chains of Heaven |
| `mental_status` | 106 | Fear, charm, confusion, sleep | `StatusEffect` blocks and tags | BUILT (C2.14); the rarer ailments C8.7 | Tsukuyomi; Kyōka Suigetsu — Complete Hypnosis; Sakanade |
| `possession` | 32 | Take over a body | M8 `command` OBEY | PLANNED C6.11 | God Hand; Shadow Possession Technique; Mind Body Switch Technique |
| `social_control` | 23 | Orders, authority, persuasion | M8 `command` | PLANNED C6.11 | Brainwashing; Lelouch — Absolute Obedience; Demon Negotiation |
| `copy_ability` | 17 | Use a power you saw | `PowerSet` holding a borrowed power by source | NEW C8.13 (needs C7.3's kits by source) | Copy; Forced Spirit Fission; Bookmark |
| `power_ownership` | 14 | Give, take or lock who may use a power | M12 `grant`; the seal and steal | PLANNED C6.11; NEW C8.13 | All For One; Beelzebuth, Lord of Gluttony; Rogue — Power Absorption |
| `random_move_dispatch` | 3 | Use a random power | A power that picks from a list with the seeded rng | NEW C8.13 | Metronome; Astrologian's Arcana; Metronome |
| `steal_stat_stages_attack` | 2 | Take a foe's buffs, then strike | A `SkillEffect` that moves buff-tagged statuses | NEW C8.13 | Spectral Thief; Spectral Thief |
| `power_suppression_gaze` | 1 | Switch off powers of whoever you look at | A seal status (NO_SKILLS for powers) needing sight | NEW C8.13 | Erasure |
| `learn_enemy_skill` | 1 | Learn a foe's skill by being hit with it | The same, saved in `Flags` | NEW C8.13 | Blue Magic |
| `effect_theft` | 1 | Steal a property and carry it | Take a status or buff from a target | NEW C8.13 | Soft & Wet — Plunder |
| `absorb_analyze_store` | 1 | Eat, analyse and keep | Absorb (M3) plus copy | NEW C8.13 | Predator |
| `spell_cost_permission` | 1 | Pay a different cost | `cost_mult_<pool>`; a status changing the cost pool | BUILT in part (C6.1a) | Omniscience |
| `rule_slots` | 1 | Name a rule and it holds, a few at a time | Authored statuses with a slot cap | NEW C8.15 | New Order |

### Life, death and exchange

| Family | Powers | In plain words | What runs it here | State | Examples |
|---|---|---|---|---|---|
| `soul_interaction` | 96 | Hurt or hold the soul, past normal defence | An element or tag that barriers do not stop (`bypass_tags`) | BUILT as parts | Crazy Diamond — Restoration; Idle Transfiguration; Cursed Spirit Manipulation |
| `heal` | 78 | Restore health | `SkillEffect` HEAL and RESTORE | BUILT (C2.13) | Idle Death Gamble; Thou Shalt Not Die; Spirit Exorcism |
| `drain_exchange` | 59 | Take from one, give to another | `SkillEffect` DRAIN; M11 `sacrifice` | BUILT; PLANNED C6.12 | Vasavi Shakti; World Tree Magic; Black Trigger |
| `resurrection` | 15 | Bring back the fallen | `SkillEffect` REVIVE | BUILT (C2.13) | Bonfire Resurrection; Dragon's Heritage; Nekros / Shadows of the Dead |
| `countdown_rule` | 11 | A countdown that ends in a set result | Doom counter | PLANNED C8.7 | Scenario; Doom; Dana's Wisdom |
| `revive_anchor` | 9 | Do not die while a condition holds | A status that turns a lethal hit into a revive, once | NEW C8.15 | Spring Autumn Cicada; Clove: Not Dead Yet; Determination Reset |
| `death_condition` | 5 | A mark that kills when its condition is met | Doom counter, instant death with `immune_tag` | PLANNED C8.7 | Crime and Punishment; SCP-049 Lethal Touch; The Lich: Extinction Wish |
| `conditional_instant_defeat` | 2 | Defeat outright if a condition holds | M8 `command` FALL; C8.7 | PLANNED C6.11, C8.7 | The End; Zanmato |
| `fainted_ally_power` | 2 | Stronger for each fallen ally | `PowerScaling` source (as ALLIES_STANDING, reversed) | PLANNED C6.25 (add ALLIES_FALLEN) | Last Respects; Last Respects |
| `damage_heal_escrow` | 1 | Hold all damage and healing, settle once at the end | A ledger status in `Combatant.receive`'s guard hook | NEW C8.15 | Oracle: False Promise |
| `delayed_resolution` | 1 | The hit lands later | The same ledger; M15 `plant` TIMER | NEW C8.15; C6.26 | Octavia / Mallet |

### Fate, rules and knowledge

| Family | Powers | In plain words | What runs it here | State | Examples |
|---|---|---|---|---|---|
| `information_sensor` | 180 | See, sense, scan | M7 `reveal`; scan | PLANNED C6.10, C8.7 | Mystic Eyes of Death Perception; Heaven's Door; Six Eyes |
| `conditional_rule` | 78 | Works only if a condition holds | `Power.requires_statuses`, `requires_pool`, `active_hours`, `PowerScaling` | BUILT (C6.1) | Rule Breaker; Star Rage; Black Flash |
| `fate_outcome` | 56 | Luck, fate, forced results | M7 `foresight` rewrites; crit and accuracy stats | PLANNED C6.10 | D4C — Love Train; Izanagi; The Balance |
| `concept_rule` | 37 | An authored rule about an idea | Authored statuses and battlefield rules; never free-form | PLANNED C6.9; else OUT | Unlimited Blade Works; Ionioi Hetairoi; Hakai |
| `data_control` | 23 | Read or change records | Scan | PLANNED C8.7; else OUT | X-Antibody; Yggdrasill / Digital World Governance; Whack |
| `story_rule` | 22 | True because the story says so | `Flags` and dialogue | OUT (story) | Bohemian Rhapsody; The Fourth Wall; Fable / Story Power |
| `special_noncombat` | 21 | Useful outside a fight | Upstream's interactables and world state | OUT (not combat) | King's Reputation; Life-Force Expenditure; Steal |
| `cosmic_vague` | 17 | Vast, undefined power | Nothing to build until it is given a rule | OUT | Dragon Break; Pattern Screamers; Death of the Endless |
| `language_interface` | 12 | Translate, speak to anything | Dialogue | OUT (not combat) | Professor X — Telepathy; Jean Grey — Phoenix Force; Telepathy |
| `wish_authoring` | 6 | A wish granted | A list of authored outcomes | OUT (story) | Miracle Invoker; Wish; Prismo's Wish |
| `future_perception_choice` | 1 | See futures and pick one | M7 `foresight` | PLANNED C6.10 | The Almighty |
| `causal_rejection` | 1 | Your action never happened | M7 `foresight` DODGE with no limit, as a boss rule | PLANNED C6.10 | Gold Experience Requiem — Return to Zero |
| `pursuit_triggered_calamity` | 1 | Harm comes to whoever chases you | A reaction status keyed to being targeted | NEW C8.15 | Wonder of U — Calamity |
| `math_target_selection` | 1 | Hit everyone whose number fits | A `Skill` target filter by stat | NEW C8.15 (target filter) | Arithmeticks / Calculator |

### Gear, items and resources

| Family | Powers | In plain words | What runs it here | State | Examples |
|---|---|---|---|---|---|
| `resource_system` | 29 | A pool that pays for powers | `Vitals` pools, `regen_<pool>`, M6 `gauge` | BUILT | Rasengan; Particle Style; Truth-Seeking Balls |
| `equipment_special` | 25 | A weapon with its own power | Special gear: a piece's `kit` | PLANNED C7.3 | Crazy Slots; Quinque; Owl |
| `equipment_inventory` | 23 | Carry and swap gear | `Inventory`, `GearSet` | BUILT (C7.1) | Requip — The Knight; Djinn Equip; Create Greater Item |
| `enchant_object` | 11 | Add an effect to an item | Sockets, affixes | PLANNED C7.4, C7.2b | Soru Soru no Mi; Strand Unravel; Reverse Lashing |
| `magic_prep` | 11 | A rune or potion prepared now, used later | M15 `plant` with a trigger; items | BUILT C6.26 | Light Glyph; Ice Glyph; Compound Glyph Spell |
| `held_item_attack_type` | 2 | The attack's type comes from what is held | A worn piece lends `element` and `attack_tags` | BUILT (C7.1c) | Judgment; Judgment |
| `equipment_spell_stat_binding` | 1 | Bind stocked spells to stats | Sockets with counted gems | PLANNED C7.4 | Junction |

## What the sorting says

| State | Families | Powers |
|---|---|---|
| Built, or built from parts | 34 | 1666 |
| Planned on an existing row | 40 | 920 |
| New row from this page | 36 | 628 |
| Out of scope | 6 | 92 |
| **All** | **116** | **3306** |

(A family counted as built may still name a planned row for one part of it; the table counts
by the first word of its State.)

## The six new rows

Each is one mechanism, data-driven, in both formulas, at most eight files.

| Row | Mechanism | Covers these families | In plain words |
|---|---|---|---|
| C8.10 | **Owned fighters** (`summon`) | `summon_entities`, `companion_form`, `autonomous_support`, `corpse_to_summon`, `life_from_object`, `distributed_body_parts`, `owned_shadow_swap`, part of `materialized_art` | A power makes a fighter that fights on the caster's side with its own brain. Each one knows its owner and the power that made it, has a lifetime and a cap, shares or does not share hp with its owner, and leaves when the owner falls, the power ends or the area is left. A roster (a raised army) is saved in `Flags`. The battle side joins C8.3 |
| C8.11 | **Time** (`time`) | `temporal_stop`, `personal_time_stop`, `temporal_rate`, `temporal_skip`, `time_erasure`, `temporal_rewind`, `personal_state_rewind`, `object_motion_rewind`, `return_anchor` | Two parts. A per-fighter `time_rate` stat beside `CombatClock` (0 stops one fighter, 2 doubles it; the user of a time stop is exempt). And a time record: each fighter's position, hp and statuses kept for the last few seconds or turns, so a power can put one fighter (or one saved point) back. Never restores items or experience |
| C8.12 | **Unseen** (`stealth`) | `stealth_visibility` | A status that foes cannot target or lock on to; it ends when the holder attacks or is hit by an area. A `reveal` (M7) removes it |
| C8.13 | **Copy, steal and seal** (`borrow`) | `copy_ability`, `learn_enemy_skill`, `effect_theft`, `steal_stat_stages_attack`, `absorb_analyze_store`, `random_move_dispatch`, `power_suppression_gaze`, `gravity_nullifier`, part of `power_ownership` | Borrow a power seen or suffered (held in the `PowerSet` by source, for a while or saved); take a foe's buffs; seal a foe's powers by sight or by field; use a random power from a list. Needs C7.3 (several kits by source) |
| C8.14 | **Constructs** (`construct`) | `construct_matter`, `materialized_art`, `imagined_construct`, `portal_link`, walls from `spatial_barrier` | Things a power puts in the arena: a wall that blocks, a made weapon to wield for a while, a pair of linked doors. Each has hp or a lifetime and an owner, and upkeep can end it when its maker is hit. Built on M15 `plant` (C6.26) and C8.9 |
| C8.15 | **Late and conditional outcomes** (`ledger`) | `damage_heal_escrow`, `delayed_resolution`, `revive_anchor`, `rule_slots`, `pursuit_triggered_calamity`, `material_decay_spread`, `math_target_selection`, `terrain_cast_random` | A ledger status that holds every hit and heal on a fighter and settles once at the end; a hit that lands later; a status that turns one lethal hit into a revive; a status that spreads to neighbours; a reaction to being targeted; a target filter by stat; scaling by the place |

Small additions to rows that already exist: C6.7 gains the LINE beam (`beam_hitscan`); C6.12
gains SWAP and a path that hits (`teleport_swap`, `void_movement`); C6.25 gains
`PowerScaling.Source.ALLIES_FALLEN` (`fainted_ally_power`).

**Order.** These six come after the rows they stand on: C8.12 and C8.15 any time after C6.6;
C8.10 after C6.12; C8.11 after C6.9a; C8.13 after C7.3; C8.14 after C6.26. The order at the
foot of [`GEAR.md`](GEAR.md) lists them.

## The characters in the pack

127 profiles, in `reference/power_pack/characters/`. The heroes this fork is building that the
pack also covers: **Kishou Arima, Satoru Gojo, Gilgamesh, Escanor**. Their kit rows (C6.17,
C6.14, C6.15, C6.16) read the profile as a second source beside `POWERS.md`; where the two
differ, `POWERS.md`'s design stands and the difference is noted in the kit's devlog entry. Any
other profile (Eto, Kaneki, Sukuna, Sung Jinwoo, Cloud and the rest) is a ready source for a
new kit: one data file, plus at most one of the mechanisms above.

Many profiles are marked as needing a manual check. Treat those as a pointer to a character,
not as a finished move list.

## Renaming

Every name on this page and in `reference/` is a real name from its source, kept for the
owner's planning. None is in code. When a kit is made, its names go in `data/powers/` and the
CSV only, as [`POWERS.md`](POWERS.md) § Renaming says.
