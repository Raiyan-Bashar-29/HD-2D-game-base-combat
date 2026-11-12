# Gear, battlefields and transformations: the design (C7.0)

**Read this before building any C7 row, C6.5d, C6.9a–d or C6.26.** It is the design the owner
asked for on 2026-11-10 in three messages. Nothing here is built yet; each part names the board
row that builds it. The hero powers it leans on are in [`POWERS.md`](POWERS.md).

**What the owner asked for, in plain words:**

1. The heroes' signature weapons inside the game (Arima's IXA and Owl, Gilgamesh's Ea), the
   best-known fictional armours, and the systems under them: gear, gear types, special gear,
   rarity and crafting.
2. The Owl quinque done properly: it throws projectiles, and what it leaves behind can be set
   off from a distance into big spikes.
3. IXA's modes done properly.
4. Ea "shatters reality": a reusable mechanic for abilities that change the battleground or
   take the fight somewhere else (domain expansions, reality marbles, marble phantasms), with
   every variation of buff, debuff, damage and duration as data.
5. Transformations: a change of form that changes abilities and stats, and updates the menu,
   the screen, the sheet and the sprite. Code now with dummy looks; the sprites come later.
6. A survey of the combat mechanics popular games and stories use, so the missing ones can be
   built.

## The rules in one screen

- **Everything is data.** A new weapon, armour, rarity, recipe, battlefield or transformation is
  a `.tres` file and CSV rows. Code under `src/` never names one.
- **Real names for now** (IXA, Ea, Berserker Armor), in `data/` and `localization/strings.csv`
  only. § Renaming lists where each name lives.
- **Gear builds on what exists.** An item of gear is still an upstream `ItemDefinition` in the
  bag. Its stats are `StatModifier`s on the `StatSheet`. Its powers are a `PowerKit`. Its modes
  are forms (M5). Nothing gets a second system.
- **Both formulas.** Every part works in a turn-based battle and in the field, as the powers do.
  Durations are in turns in a battle and in seconds in the field.
- **Art is deferred.** A look is a colour and a size on the placeholder sprite until the owner
  adds sprites.
- **One row at a time**, about 8 files or fewer, red first, with the full ladder.

## Part 1 · Gear

### What upstream already gives

| Part | Where | What it does | Gap for combat gear |
|---|---|---|---|
| `ItemDefinition` | `src/content/items/` | An item: id, name key, category, stack size, `equip_slot` | No stats, no rarity |
| `Inventory` | `src/gameplay/character/` | Counts of items, saved | None: gear lives here |
| `Equipment` | `src/gameplay/character/` | What a carrier holds ready, as `Flags` `equip/<wearer>/<item>` | Its slots are upstream's enum `EquipSlot { NONE, LIGHT, TOOL, GARMENT, TRINKET }`, with no weapon or armour slot on purpose |
| `Rewards.give` | `src/gameplay/combat/` | Gives a list of item ids as loot | No drop chances |

**Decision: gear gets its own worn-set component, `GearSet`, in the fork.** Upstream's
`EquipSlot` is an upstream file with a "no weapon slot" rule, and the fork may not edit it. So:

- A piece of gear is an `ItemDefinition` (so the bag, saves, pickups and gates all work) **plus**
  a `GearDefinition` naming that item. An item with no `GearDefinition` is not gear.
- `GearSet` is `Equipment`'s twin and follows the same three rules: the slots live in `Flags`
  (`gear/<wearer>/<item id>`, so they are saved for free), the item stays in the bag while
  worn, and losing the item takes it off.
- Upstream's `Equipment` keeps doing what it does (a lantern, a tool). The two do not touch.

### The shapes (content, `src/content/combat/gear/`)

**`GearDefinition`** (one per piece, `data/gear/<name>.tres`):

| Field | Meaning |
|---|---|
| `item_id` | The `ItemDefinition` this is (`item/ixa`) |
| `slot` | Where it is worn: a `StringName` from the slot list below |
| `type` | A `GearType` (below) |
| `rarity` | A `Rarity` id (`rarity/legendary`) |
| `modifiers` | `StatModifier`s while worn (`attack` +12, `resist_fire` +0.2) |
| `element` | What the wearer's plain ATTACK counts as (a weapon) |
| `attack_tags` | Tags the wearer's attacks carry (`sword`, `quinque`), for weaknesses |
| `moves` | A `MoveSet` played in the field while worn (a weapon's swing chain) |
| `kit` | A `PowerKit` granted while worn: special gear (§ Special gear) |
| `passives` | Dropped in C7.3: give the piece a `kit` and list them in the kit's `passives` |
| `wearers` | Combatant ids that may wear it; empty means anyone |
| `needs_level`, `needs_stats` | Requirements to wear it |
| `set_id` | The set it belongs to (§ Sets) |
| `sockets` | How many gems it holds (§ Sockets) |
| `max_upgrade`, `upgrade` | The upgrade track (§ Upgrading) |
| `blocks` | Slots the piece takes up besides its own. A two-handed weapon is `blocks = [offhand]` (built in C7.1c; the design first called this `two_handed`) |
| `cursed` | Cannot be taken off in the ordinary way |

**Slots** are data, a list on one `GearRules` resource (`[combat] gear/rules`), so a game
changes them without code. The default:

| Slot | Holds |
|---|---|
| `weapon` | The main weapon |
| `offhand` | A shield, a second weapon, a focus |
| `head`, `body`, `hands`, `feet` | Armour pieces |
| `accessory_1`, `accessory_2` | Rings, charms, cloaks |
| `relic` | One special slot for signature gear that is neither weapon nor armour |

**`GearType`** (`data/gear_types/<name>.tres`) is the kind of thing a piece is. It carries the
defaults every piece of that type shares, so a sword does not repeat them:

| Field | Meaning |
|---|---|
| `id`, `name_key` | `gear_type/lance`, its name |
| `family` | WEAPON, ARMOUR, ACCESSORY or SPECIAL |
| `slots` | The slots it may go in |
| `attack_tags` | Tags every piece of this type adds (`pierce` for a lance) |
| `moves` | The default field chain for this type |
| `weight` | LIGHT, MEDIUM or HEAVY armour, as modifiers (`speed`, `evasion`) |
| `element`, `blocks` | The defaults for every piece of the type |

The default types the demo ships:

- **Weapons:** sword, greatsword, katana, dagger, lance, spear, axe, hammer, bow, gun, staff,
  tome, gauntlets, scythe, whip, chain.
- **Armour:** helm, hat, plate, mail, robe, gauntlets, bracers, greaves, boots, shield.
- **Accessories:** ring, amulet, charm, cloak, belt.
- **Special families**, each a `GearType` like any other, with a mechanism behind it:
  quinque (Tokyo Ghoul), noble phantasm (Type-Moon), devil arm (Devil May Cry), sacred treasure
  (Seven Deadly Sins), cursed tool (Jujutsu Kaisen), spirit weapon (Bleach), relic armour.

### Worn gear in a fight (`GearSet`, `src/gameplay/combat/gear/`)

- `GearSet.of(body)`, `wear(item_id)`, `take_off(item_id)`, `worn(slot)`, `can_wear(item_id)`
  with a reason (wrong wearer, level too low, cursed piece in the slot).
- On wear, the piece's modifiers go on the wearer's `StatSheet` with the source
  `gear/<item id>`, and come off by that source. This is how a status's modifiers work.
- `Combatant` reads the worn weapon for its attack element and tags, on top of its own.
- `PowerSet.moves_over` (the hook forms use) also asks the worn weapon for its chain, so a
  weapon changes the swing and a form on top of it still wins.
- `BattleSetup` and `ActionHost` build a `GearSet` for a fighter whose `CombatantDef` lists
  `gear` (its starting pieces). An enemy can wear gear the same way, and drop it.
- A party switch carries the `GearSet` with the body's other parts (`FieldParty._identity`).

**As built (C7.1b).** `GearSet.fit(body, def, keep)` is the one way a fight gives a fighter its
worn set. The rules:

- **Starting pieces go on once.** `CombatantDef.gear` lists item ids. The first time a party
  member is built, they are worn and the flag `gear_started/<wearer id>` is set. After that
  the player's choices stand: a piece taken off stays off. A new game clears the flag, so they
  go on again.
- **A starting piece is the fighter's own.** It need not be in the bag (`GearSet.innate`), so
  a party member keeps its sword whoever carries the bag. A piece from the bag still comes
  off when the item leaves the bag.
- **A foe leaves no trace.** A set built with `keep` false remembers what it wears itself and
  writes no flag. A foe with no starting gear gets no set at all.
- **A party member's battle copy wears what its field body wears,** because both read the
  same flags.
- **The slot list** is the `GearRules` file named in `[combat] gear/rules`; with no setting,
  the nine defaults.

**As built (C7.1c): what a worn piece lends, and pieces that take two slots.**

- **Element and tags.** `element` and `attack_tags` sit on `GearType` and `GearDefinition`. A
  piece's own element wins over its type's; the tags of both are joined.
- **Who lends.** Every worn piece, read in the slot list's order, so the weapon comes first.
  The first piece with an element decides it. `GearSet` writes the result onto the wearer's
  `Combatant` (`lent_element`, `lent_tags`) after every change, a load included.
- **Who borrows.** Only the plain attack: `Battle`'s ATTACK and a field move with no skill.
  They ask `Combatant.strike_element(own)` and `strike_tags()`. A move that names its own
  element keeps it. A skill or a power keeps its own element and tags.
- **What it does.** The hit has that element, so resistances and absorbing barriers apply,
  and the element and tags count against the target's weaknesses (shield, pressure, Break).
- **`blocks`.** A list of slots a piece takes up besides the one it is worn in. Putting the
  piece on empties those slots; putting a piece into one of them takes the blocker off. A
  two-handed sword is `blocks = [offhand]`. A file that blocks its own slot is a problem.

Still to come: the weapon's own attack chain (C7.3b). A foe drops what it wears when its `loot_table` lists the piece (C7.2).

### Rarity (`Rarity`, `data/rarities/<name>.tres`)

| Field | Meaning |
|---|---|
| `id`, `name_key` | `rarity/epic`, "Epic" |
| `rank` | Order, 0 upward |
| `color` | Shown on the name everywhere |
| `stat_scale` | Multiplies the piece's modifiers (1.0, 1.15, 1.3 …) |
| `affixes` | How many random extra modifiers a dropped piece rolls |
| `sockets` | Extra sockets |
| `drop_weight` | How often it drops |
| `max_upgrade` | Upgrade cap for this rarity |

The default tiers: Common, Uncommon, Rare, Epic, Legendary, Mythic and **Signature** (one of a
kind, never dropped at random, never dismantled: IXA, Ea).

**Drops.** `LootTable` (content): entries of item id, weight, count range and a condition
(`Flags` key), plus `rolls`. `Encounter.loot` stays as the guaranteed list; a new
`Encounter.loot_table` and `CombatantDef.loot_table` add the rolled part through
`Rewards.give`, with the seeded `rng`.

**As built (C7.2, combat 0.67.0).**

- **A tier is a file**, `data/rarities/<name>.tres`, id `rarity/<name>`, found through
  `RarityDb`. Seven sample tiers ship, as `tier_common.tres` and so on (the `tier_` prefix
  keeps a plain word like "common" from counting as a demo name in `check_boundary`) (Common 1.0, Uncommon 1.15, Rare 1.3, Epic 1.5,
  Legendary 1.75, Mythic 2.0, and Signature with `drop_weight` 0). No code names a tier; a
  game edits, adds or deletes the files.
- **A piece names its tier** in `GearDefinition.rarity`. Empty means plain.
- **`stat_scale` is live.** `GearDefinition.all_modifiers()` returns every stat change at the
  tier's size: an added amount is multiplied, a multiplier keeps its distance from 1
  multiplied (x1.2 at scale 1.5 is x1.3), an override is left alone.
- **`drop_weight` is live.** In a rolled table, a gear line's weight is multiplied by its
  tier's `drop_weight`. 0 means the piece is never rolled; a guaranteed `loot` list still
  gives it.
- **`color`, `affixes`, `sockets` and `max_upgrade` are declared and not yet read:** the gear
  screen (C7.5), affixes (C7.2b) and sockets and upgrading (C7.4) read them.
- **A `LootTable`** has `rolls` and `entries`. Each `LootEntry` has `item_id` (empty means
  "nothing this time"), `weight`, `min_count` to `max_count`, and `needs_flag` (the line is in
  the table only while that flag is true).
- **`LootRoll.roll(table, rng)`** draws one line per roll by weight and returns one item id per
  item. It uses the `rng` it is handed, so a seeded fight drops the same things.
- **Where tables go:** `Encounter.loot_table` (rolled on a win), `CombatantDef.loot_table`
  (rolled on a win for each enemy of the encounter, and by a field enemy when it falls, added
  to its own `loot`). `Rewards.grant` gives the guaranteed list first, then the encounter's
  roll, then each enemy's.
- **Not built here:** a luck stat on the weights, and money drops (C7.6 brings money).

**Affixes.** An `Affix` is a named extra modifier with a range ("of Embers": `fire_power`
+5 to +10 %). A rolled piece's affixes are saved in `Flags` under the piece's instance key.
Unique pieces (max stack 1) can roll; stacked pieces cannot. Built last (C7.2b), because it
needs per-instance state.

### Special gear: gear that grants powers

A piece with a `kit` gives its powers while worn. This is how every signature weapon works.

- **`PowerSet` holds more than one kit** (today it holds one). Each kit is equipped under a
  source: the character's own (`kit/<id>`) and one per worn piece (`gear/<item id>`). Powers,
  passives, gauges and stat bonuses of every kit are live; quick slots list the character's
  kit first, then gear kits in slot order.
- **A weapon's modes are forms.** IXA's lance and shield are `FormMechanism`s in IXA's kit, in
  one `exclusive_group`, so the mode keys, the mode's own quick slots and saving all come from
  C6.5 with no new code.
- **A power can need a piece:** `Power.requires_gear` (an item id or a `GearType` id). Yamato's
  Judgment Cut needs a katana in hand.
- **Charges.** A piece can carry a pool (`max_<pool>` in its modifiers), so a weapon has its own
  ammunition or heat (Owl's Rc cells, Ea's wind-up).

**As built (C7.3, combat 0.68.0).**

- `GearDefinition.kit` is a `PowerKit`. While the piece is worn, the wearer has the kit's
  powers, passives, gauges and stat bonuses. `problems()` checks the kit with the piece.
- `PowerSet` holds the fighter's own kit (`kit`, put on with `equip`) and any number of lent
  kits (`lend`). `kits()` lists them, own first; `powers()` is every power in menu order;
  `status(id)` finds a passive or a form's status in any of them. Each kit goes on and comes
  off alone, so the other kits' cooldowns, forms and passives carry on.
- `GearSet` hands the worn pieces' kits to the wearer's `PowerSet` after every change, in the
  slot list's order. A kit that stays worn is left alone. A fighter with no powers of its own
  gets a `PowerSet` the first time a piece lends one.
- **The sources.** A lent kit's stat bonuses sit on the sheet under `gear_kit/<item id>`. The
  piece's own stat changes stay under `gear/<item id>`. (The design above said `gear/<item id>`
  for both; they are kept apart so taking one off cannot remove the other.)
- `Power.requires_gear` is an item id (that piece) or a gear type's id (any piece of that
  kind). `GearSet.wearing(body, id)` answers it. Not worn: `PowerUse.Reason.GEAR`, shown as
  "needs gear it is not wearing" (`ui.battle.reason.needs_gear`).
- **Charges** need no code: a `max_<pool>` modifier on the piece gives the wearer that pool
  while it is worn, and a power's skill spends it through `cost_pool`.
- **`passives` on a piece was dropped.** A piece's kit already has `passives`, so a second
  list would be the same thing twice.
- **Rules for authors.** Two kits on one fighter must not share a power id or a passive's
  status id; the set tells kits apart by those ids.
- **Not built here:** the weapon's own swing chain (`moves`, C7.3b). A form of a gear kit held
  at save time is found again on load only if the piece is still worn when the save is read.

### Sets, sockets, upgrading

- **Sets.** `GearSetBonus` (content): `set_id`, and thresholds (2 pieces: modifiers; 4 pieces: a
  status or a kit). `GearSet` counts worn pieces per `set_id` and holds the bonuses under the
  source `set/<id>`.
- **Sockets.** A gem is an item with a `GemDefinition` (modifiers, or an element for the
  weapon). `GearSet.socket(piece, gem)`; the gem is used up, and a remover item gives it back.
- **Upgrading.** `UpgradeTrack` (content): per level, the cost (items and money) and the gain
  (a scale on the piece's modifiers, and at named levels a new modifier, a socket or an
  unlocked power in its kit, through `Power.requires_upgrade`). The level is saved per piece.
- **Awakening.** At the track's cap, a recipe may turn the piece into another piece (Yukimura
  1/3 into a finished blade). It is a recipe whose input is the capped piece.

### Crafting

**`Recipe`** (`data/recipes/<name>.tres`):

| Field | Meaning |
|---|---|
| `id`, `name_key` | `recipe/steel_lance` |
| `inputs` | Item id → count |
| `output`, `count` | What it makes |
| `station` | Where: `forge`, `quinque_lab`, `treasury`, or empty for anywhere |
| `needs_flag` | Known only once a `Flags` key is set (a found blueprint) |
| `cost` | Money, if the game has it |
| `rarity_chances` | Optional: a chance to come out a tier higher |
| `kind` | CRAFT, UPGRADE, AWAKEN, DISMANTLE or TRANSMUTE (materials into better ones) |

`Crafting` (gameplay, static): `known(inventory)`, `can_make(recipe, inventory)` with a
reason, `make(recipe, inventory, rng)`. A `CraftStation` interactable opens the craft screen
for its `station`. **Dismantling** gives back part of a piece's recipe, by rarity. A quinque
recipe takes a "kakuhou" material that a named foe drops, which is how the Owl is made.

### Screens

- **Gear screen** (from the pause menu): each party member's slots, the bag's pieces for the
  chosen slot, and a compare panel (each stat with its change in green or red, the granted
  powers, the set progress). Names are drawn in their rarity colour.
- **Craft screen** (from a station): known recipes, what is missing, the result compared with
  what is worn.
- **In a fight:** the field HUD and the battle screen show the weapon's name beside the
  fighter, and the current mode (form) of the weapon.

## Part 2 · The signature weapons

Sources are in § Sources. Where the source is thin, the game reading is my choice and is marked
**(reading)**.

### IXA (Arima) · `item/ixa`, type quinque, slot `weapon`, Signature

**Source.** A koukaku quinque, rated around S+. It is a lance on a gun-sword grip with a spiked
pommel, able to drive through a ghoul's body and to stretch its reach. In its defensive mode it
opens into a wide shield, like petals, that has held against the kagune of many strong ghouls;
the One-Eyed Owl once broke that shield and damaged the weapon. Its remote activation strikes
from under the ground at a distance, and Arima has used it to keep up a barrage while fighting
with a second quinque. Kaneki destroyed it.

| Mode or power | Built from | Numbers (first pass) |
|---|---|---|
| **Lance mode** (default) | M5 `form`, group `ixa`. A long thrust chain from the weapon's `moves`; `attack_tags [pierce, quinque]` | poise ×2, reach 2.4 m |
| Extend | A move with a long, thin hitbox and forward travel; in a battle a skill that hits the front foe and the one behind it **(reading)** | 6 MP, 3 s |
| **Shield mode** | M5 `form`, group `ixa`, with M3 `barrier` TIMED_BLOCK then REDUCE ×0.4, `scope` ALLIES behind it | upkeep 2 MP/s or 4 MP/turn |
| Shield durability | The barrier's `cost_pool` is the weapon's own pool `ixa_guard`; at 0 the shield breaks and the mode is locked for a while (a status that blocks the form) | 60 points, back after 12 s or 3 turns |
| **Remote activation** | M15 `plant` (below), FROM_GROUND under the locked target; usable in either mode and while another weapon is in hand | 8 MP, 5 s |
| Remote barrage | The same power held: a spike every 0.4 s along the target's path; in a battle 3 hits | 3 MP per spike |
| Mine | M15 `plant` with `trigger` PROXIMITY: IXA left in the ground strikes whoever steps near **(reading; one source calls it landmine-like)** | 10 MP, one at a time |
| Broken IXA | When the weapon's pool `ixa_guard` is broken three times in a fight, the piece's modifiers halve until repaired at a station **(reading)** | — |

### Owl (Arima) · `item/owl`, type quinque, slot `weapon`, Signature

**Source.** The only known SSS-rated quinque, an ukaku type, made from the kakuhou torn from
the One-Eyed Owl while the ghoul still lived. It has a long handle and a large jagged blade,
and three modes: **Blade**, **Firing** and **Trap**. As an ukaku it shoots concentrated Rc-cell
projectiles of various sizes. Arima can release and switch it off, then switch it back on from
somewhere else, so it works as a hidden trap that lets him strike from the foe's side. It cut
through Kaneki's kakuja. Kaneki destroyed it, and Arima fought on with what was left.

| Mode or power | Built from | Numbers (first pass) |
|---|---|---|
| **Blade mode** (default) | M5 `form`, group `owl`. A wide, fast chain; `attack_tags [slash, quinque]`; cuts guards: its hits carry `bypass` for REDUCE barriers **(reading, from cutting the kakuja)** | attack +30 |
| **Firing mode** | M5 `form`, group `owl`. The attack button fires: M1 `barrage` LINE, sizes from a list (small fast shards, a large slow bolt on a held press) | 2 `rc` per shard, 8 per bolt |
| Shard storm | M1 `barrage` RAIN over an area. **Every shard that misses stays in the ground as a planted shard** (M15) | 14 `rc`, 8 s |
| **Trap mode: remote activation** | M15 `plant`, `trigger` REMOTE: one press turns every planted shard into a tall spike, each hitting what stands on or beside it. More shards, more spikes | 6 MP, 2 s |
| Leave the blade | M15 `plant` of the weapon itself: the wearer drops Owl (and may draw IXA); on the remote press it erupts where it lies, and a M9 `blink` brings the wearer to it **(reading of "appears at the foe's side")** | 12 MP, 15 s |
| `rc` gauge | A weapon pool, `max_rc` 100, +4 per blade hit, +2 per second | — |
| Remains of Owl | When the weapon breaks it becomes `item/owl_remains`: blade mode only, attack halved, usable to the end of the fight | — |

### Ea, the Sword of Rupture (Gilgamesh) · `item/ea`, type noble phantasm, slot `relic`, Signature

**Source.** The sword that "cleaves the world". Its attack, Enuma Elish, is an Anti-World
Noble Phantasm of rank EX; it is the attack's name that is called, not the weapon's. It
compresses and tears space, leaving a void that swallows what was there. It tore apart
Iskandar's Reality Marble and the army inside it, and reduced the plain to nothing. Avalon can
stop it. The Gate of Babylon can add to its power. It cannot be copied.

| Power | Built from | Numbers (first pass) |
|---|---|---|
| Wind-up | A weapon pool `rupture` (0–100): +10 per second or +34 per turn while Ea is drawn (a form, group `gilgamesh_hand`); the Gate's barrage adds +3 per hit | — |
| **Enuma Elish** | M2 `finisher` with the tags `anti_world` and `sure_hit`, element `rupture`, hitting every foe in the fight. **It breaks every battlefield in reach** (Part 3: `broken_by_tags`), and gains power for each one broken | all of `rupture`, 30 s |
| The rupture left behind | M4 `battlefield` "Torn Sky", cast by the finisher: the place's look changes to the void; everyone but the wearer takes rupture damage every 2 s or each turn and has defence −30 %; it ends after 10 s or 3 turns | — |
| Cannot be copied | The piece is Signature with `wearers [gilgamesh]`; M10 `clone` and M12 `grant` skip powers from a piece tagged `uncopyable` | — |
| What stops it | A barrier with `absorb_tags [anti_world]` (Avalon, below). Nothing else: `sure_hit` passes NULLIFY and dodges | — |

### The other heroes' weapons (each a piece that grants part of the kit in `POWERS.md`)

| Piece | Hero | Type | What wearing it gives |
|---|---|---|---|
| Narukami | Arima | quinque | The homing lightning barrage, and the lightning redirect |
| Yukimura 1/3 | Arima | quinque | A fast 5-hit chain; awakens through the upgrade track |
| Gate of Babylon (key) | Gilgamesh | noble phantasm | The barrage; a `relic` |
| Enkidu | Gilgamesh | noble phantasm | The binding chain |
| Rhitta | Escanor | sacred treasure | Stores sun power (a pool) and releases it; too heavy for anyone else (`wearers`) |
| Yamato | Vergil | devil arm | Judgment Cut and the dimension slash; `requires_gear` for the katana powers |
| Rebellion, Ebony & Ivory | Dante | devil arm | The sword chain and the guns; styles stay on the character |
| Zantetsuken, Gungnir | Odin | eikon arm | The gauge finisher and the counter spear |
| Sankt Bogen | Yhwach | spirit weapon | The arrow barrage |
| Isliid's three swords, Roland's blade | Isliid, Roland | relic weapons | Their form cycles |

When a hero's kit and their weapon both exist, the powers that are the weapon's move to the
weapon's kit, so another character holding the weapon gets them and the hero without it does
not. Each kit row (C6.14 onward) decides its split.

### The armours

| Piece | From | Slot | The idea as game rules |
|---|---|---|---|
| Berserker Armor | Berserk | `body`, set of 3, cursed | A transformation (Part 4): attack ×1.6, no flinch (`knockback_taken` −1), pain ignored (`damage_taken` −20 %), but it drains HP each second or turn, the wearer cannot be given orders from the menu while it rages (auto-battle brain), and it cannot be taken off mid-fight |
| Avalon | Fate | `relic` | Strong HP regen; a barrier that absorbs `anti_world` hits and NULLIFIES for one turn or 3 s on use |
| Golden Armor of the King | Fate | `body` | High defence, `resist_ailment` +0.5 |
| Kavacha and Kundala | Fate / Mahabharata | `body` | Damage taken ×0.1; can be given up (destroyed) for one use of a god-slaying spear |
| Gold Cloth | Saint Seiya | set of 5 | A set bonus per piece; the full set unlocks a "seventh sense" transformation |
| Heaven's Wheel, Flame Empress, Adamantine (Requip) | Fairy Tail | armours as forms | Each armour is a transformation the wearer swaps to mid-fight: a blade barrage, fire resistance, a great shield |
| Havel's Set | Dark Souls | set of 4, HEAVY | Huge defence and poise, slow, no dodge roll |
| Daedric Armor | The Elder Scrolls | set of 5 | The top craftable tier: a recipe needing a rare heart material |
| Mjolnir Armor | Halo | `body` | A recharging energy shield: a second HP pool that refills when not hit for 4 s |
| Mark-series suit | Iron Man | set, transformation | Flight (`blink` UP), a beam finisher from a charge pool |
| Varia Suit | Metroid | `body` | Immunity to heat battlefields (`resist_field_heat` 1) |
| Susanoo | Naruto | a transformation, no item | An armour of energy: a barrier and giant-blade moves while a pool drains |

## Part 3 · Battlefields (M4, widened)

**In plain words:** a battlefield is a rule laid over the fight for a while. It can change how
the place looks, move the fighters somewhere else, help one side, hurt the other, and deal
damage on a clock. Domain expansions, reality marbles, marble phantasms, bounded fields, auras,
weather magic and terrain are all the same thing with different data.

**Source rules worth keeping:**

- **Domain Expansion (Jujutsu Kaisen).** A barrier closes around the fighters and the caster's
  technique cannot miss inside it. Two domains at once clash, and the more refined one wins.
  It can be answered with a Simple Domain, which cancels only the sure-hit and is hard to hold.
  A barrierless domain (Malevolent Shrine) has no wall, so it reaches further and can be walked
  out of. It is costly, and the caster's technique is burnt out for a while afterwards.
- **Reality Marble (Type-Moon).** The caster's inner world replaces the real one and brings
  everyone inside (Unlimited Blade Works' field of swords, Ionioi Hetairoi's desert and army).
  The World pushes back, so it costs mana every moment it stands. Another marble can overwrite
  it. An Anti-World attack (Ea) destroys it.
- **Marble Phantasm (Tsukihime).** Nature itself is reshaped as the caster wishes; only
  natural things can be changed, and nobody is moved anywhere.

### The shapes

**`BattlefieldMechanism`** (content, extends `FormMechanism`, `kind() -> &"battlefield"`). It is
a form because it has the same life: used to raise it, a status on the caster while it stands,
a drain as upkeep, ended by use, by a cure, by the status running out, or by the pool running
dry. What it adds:

| Field | Meaning | Examples |
|---|---|---|
| **Where** | | |
| `shape` | WHOLE_FIGHT, SPHERE (`radius`, centred on the caster or the target), FOLLOWS_CASTER (an aura), LINE or ZONE (a patch of ground) | A domain is SPHERE; an aura is FOLLOWS_CASTER |
| `closed` | True: nobody inside can leave and nobody outside can enter or aim in (a barrier). False: it can be walked out of | Unlimited Void closed; Malevolent Shrine open |
| `moves_fight` | The fighters inside are taken to another place until it ends; the rest of the fight waits outside | A reality marble; a boss's arena |
| `place` | A `PlaceLook` id: what the ground, sky and light become (Part 4's dummy rule: a tint and a name until art exists) | "Torn Sky", "Field of Swords" |
| `weather` | An upstream `Weather` state to hold while it stands | A marble phantasm: storm |
| **Who and what** | | |
| `effects` | A list of `BattlefieldEffect`s, below | |
| `sure_hit` | The caster's side cannot miss inside, and their hits carry the tag `domain` | Domain expansion |
| `hit_tags` | Extra tags the caster's hits carry inside (to pass a named barrier) | `domain` passes Infinity |
| `caster_kit` | A `PowerKit` the caster holds only while it stands | UBW: the sword barrage |
| `summons` | Fighters that join the caster's side while it stands | Ionioi Hetairoi's army |
| **How long** | | |
| `seconds`, `turns` | How long it stands in the field and in a battle. 0 means until ended | 0.2 s; 5 turns; infinite |
| (inherited) drain | `drain_pool` with a rate per second, per turn or per action: the upkeep | Mana while a marble stands |
| `ends_when` | Extra endings: CASTER_FALLS (default), CASTER_HIT (count), CASTER_LEAVES, ALL_FOES_LEFT | |
| `aftermath` | A status put on the caster when it ends | Burnout: NO_SKILLS for 2 turns |
| **Against other battlefields** | | |
| `refinement` | A number; scaled by a stat if named | |
| `clash` | What happens when two overlap: STRONGER_WINS (the weaker ends; equal means both), BOTH_END, OVERWRITE (the newer replaces the older), BOTH_STAND (terrain under a domain) | |
| `layer` | Battlefields in different layers never clash (TERRAIN, WEATHER, DOMAIN) | |
| `broken_by_tags` | A hit with one of these tags ends it at once | `anti_world` |
| `cancelled_by` | A status on a fighter that removes only the sure-hit for them | Simple Domain |

**`BattlefieldEffect`** (content): one rule for one group.

| Field | Meaning |
|---|---|
| `who` | CASTER, CASTER_SIDE, OTHER_SIDE, EVERYONE, EVERYONE_BUT_CASTER, or fighters with a tag |
| `modifiers` | `StatModifier`s while inside: `attack`, `defence`, `damage_dealt`, `damage_taken`, `speed`, `regen_<pool>`, `cost_mult_<pool>`, `resist_<tag>`, `cooldown_rate` |
| `statuses` | Statuses held while inside, removed on leaving (a buff, a debuff, SKIP_TURN for Unlimited Void) |
| `on_enter` | `SkillEffect`s once, when it rises or when a fighter walks in (instant damage, a dispel) |
| `on_exit` | `SkillEffect`s when it ends or the fighter leaves |
| `tick` | `SkillEffect`s on a clock: damage, healing, a pool drained or filled, a status stacked |
| `tick_seconds` | The field clock: every N seconds |
| `tick_turns` | The battle clock: every N of the fighter's own turns (1 is every turn) |
| `tick_grows` | Each tick is this much stronger than the last (a domain that closes in) |
| `pull`, `push` | Field: drawn toward or away from the centre each second |
| `immune_tags` | Fighters with these tags, or the stat `resist_field_<id>` at 1, are untouched |

Damage "at once" is `on_enter`. Damage "over time" is `tick` with `tick_seconds`. Damage "per
turn" is `tick` with `tick_turns`. Damage "per N seconds" is the same `tick_seconds` with a
bigger N. A duration is `seconds` and `turns`, or 0 for infinite.

**New stats this needs:** `damage_dealt` (a stage in the formula beside `damage_taken`), and
`resist_field_<id>`.

### How the examples come out

| Battlefield | Data |
|---|---|
| Unlimited Void (Gojo) | SPHERE, closed, `sure_hit`; OTHER_SIDE: SKIP_TURN status; 0.2 s to 5 s or 2 turns; aftermath burnout |
| Malevolent Shrine (Sukuna) | SPHERE with a big radius, open, `sure_hit`; EVERYONE_BUT_CASTER: slash damage every 0.5 s or each turn; high refinement |
| Unlimited Blade Works | `moves_fight`, place "Field of Swords", `caster_kit` the sword barrage, mana drain per second; OVERWRITE; broken by `anti_world` |
| Ionioi Hetairoi | `moves_fight`, `summons` the army, ends when the summons fall below half **(reading)** |
| Torn Sky (after Enuma Elish) | WHOLE_FIGHT, EVERYONE_BUT_CASTER: rupture tick and defence −30 %; 10 s or 3 turns |
| Escanor's heat | FOLLOWS_CASTER, open; EVERYONE_BUT_CASTER: fire tick scaled by the clock; infinite at noon |
| A marble phantasm | WHOLE_FIGHT, `weather` storm, layer WEATHER; lightning `tick` on a random foe |
| Burning ground, a healing circle | ZONE, layer TERRAIN, BOTH_STAND; a tick for whoever stands in it |
| Simple Domain | A status with `cancelled_by` meaning; upkeep per second, breaks when hit |

### The runtime (`src/gameplay/combat/powers/mechanisms/battlefield_run.gd` and a `Battlefields` helper)

- One list of standing battlefields per fight. A battle keeps it on the `Battle`; the field
  keeps it in a group of `BattlefieldZone` nodes (an `Area3D` for SPHERE and ZONE).
- Raising one: check clashes by `layer`, apply `on_enter`, hold the statuses and modifiers
  under the source `field/<power id>`.
- Each second or turn: run the ticks, the pull, the upkeep, the count-down.
- Ending one: remove everything by its source, run `on_exit`, apply `aftermath`, restore the
  place.
- `Combatant.hit` asks it for `sure_hit` and `hit_tags`; `Combatant.receive` tells it about a
  hit with a breaking tag.
- `Events.battlefield_raised(by, power_id)` and `battlefield_ended(by, power_id, why)`; the
  battle log and the HUD show its name and time left.

## The planted strike (M15 `plant`, new)

**In plain words:** something is left in the ground now and goes off later. The Owl's shards,
IXA's remote activation and mine, a time bomb, a rune trap and a delayed spell are all this.

**`PlantMechanism`** (content, `kind() -> &"plant"`):

| Field | Meaning |
|---|---|
| `where` | AT_TARGET, UNDER_TARGET, AT_USER, AHEAD (`distance`), or WHERE_PROJECTILES_LAND (a barrage's misses) |
| `count`, `max_standing` | How many one use plants, and the most that may stand |
| `trigger` | REMOTE (a second press of the same power, or a named power), PROXIMITY (`radius`), TIMER (`seconds` or `turns`), ON_HIT (when the planted thing is struck) |
| `eruption` | The `ActionMove` or `Skill` each plant performs when it goes off (a tall spike: a vertical hitbox, launch) |
| `chain_delay` | Seconds between one plant going off and the next, so a line ripples |
| `lifetime` | A plant not set off is lost after this |
| `visible_to_foes` | A hidden trap or a marked one |
| `recall` | The user may blink to a plant when it goes off |

- **Field:** a `Planted` node at a point, with a marker; on its trigger it plays its eruption
  through a `Hitbox`.
- **Battle:** a plant is a mark on a foe (a status with no effect of its own). The remote use
  hits every marked foe, harder per mark; PROXIMITY goes off when the marked foe next attacks;
  TIMER goes off after N turns.

## Part 4 · Transformations

**In plain words:** a transformation is a form (M5, built) that the player can see. Today a
form already changes stats (its status's modifiers), the field's moves, and which powers fill
the quick slots. Three things are missing, and C6.5d adds them:

| Missing | What is added |
|---|---|
| **The look** | `FormMechanism.look`: a `LookDef` id. While the form is held, the fighter is drawn with that look |
| **The battle's commands** | `FormMechanism.commands`: the command list the battle menu and the field menu offer while in the form (empty keeps the fighter's own). `FormMechanism.replaces_attack`: the skill the plain ATTACK command becomes |
| **The name and the sheet** | `FormMechanism.name_key`: shown beside the fighter's name on the battle screen, the HUD, the party sheet and the status screen ("Dante · Devil Trigger"); the stat sheet shows the form's changes in colour |

**`LookDef`** (content, `data/looks/<name>.tres`): `id`, `tint`, `scale`, `label` (a short
tag drawn over the placeholder), and the art slots filled later: `sprite_frames`, `portrait`,
`aura_scene`. **Until art exists a look is a tint, a size and a label**, so every
transformation is visible now and the owner only drops sprites in. `Events.look_changed(who,
look)`; a small `LookSwap` node beside the `Combatant` applies it to the body's
`CharacterVisual` in the field and to the fighter's row and portrait on the battle screen.

**The kinds of transformation popular games use, and how each is authored:**

| Kind | Seen in | Authored as |
|---|---|---|
| A gauge super mode: fill a meter, transform, it drains | Devil Trigger, Trance (FF9), Limit Form, Rage of the Gods, Super Saiyan games | A form needing `requires_pool` at a fraction, with `drain_per_second` and `drain_per_turn` |
| A once-per-battle power-up | Mega Evolution, Terastallization | A form whose power has a cooldown longer than the fight (`once_per_battle`) |
| A timed giant form | Dynamax, Susanoo, an Eikon | A form with a timed status (3 turns), `scale` on the look, its own commands |
| A stance or style swap, free and often | Dante's styles, Vergil's weapons, Xenoblade stances | Forms in one `exclusive_group`, no cost |
| A job or class change mid-fight | FF X-2 dresspheres, Bravely Default jobs, Requip | A cycle or group of forms, each with its own `commands`, look and stats |
| A persona or summon swap | Persona, FF10 aeons | A form that swaps `commands`, weaknesses (`weak_to` through the status) and the look |
| A phase change at low HP | Boss second forms, Barnabas into Odin | The brain uses the form power when HP falls below a fraction; `revert` false |
| A berserk form the player loses control of | Berserker Armor, Trance in some games | A form whose status sets the fighter to auto-battle |
| A fusion of two fighters | Fusion (Dragon Ball), Chrono Trigger's dual forms | A form that needs an ally (`requires_ally`), removes them from the line while held, and adds their stats |
| A form with a price | Bankai burnout, Gear Fourth | `aftermath`: a status when the form ends |
| A layered form (a form on a form) | Sin Devil Trigger on Devil Trigger, Super Saiyan 2 | A form that `requires_statuses` the lower form, in another group |
| A permanent evolution | Awakenings in gacha games | An upgrade track on the character, not a form |

New small fields these need: `once_per_battle` on `Power`; `aftermath` and `requires_ally` on
`FormMechanism`; a `control` setting on `StatusEffect` (PLAYER or AUTO).

**As built (C6.5d, combat 0.69.0): the look and the name.** `LookDef`
(`src/content/combat/look_def.gd`) holds `look_id`, `tint`, `scale` and `label_key`; the art
slots wait for the row that first reads them. `FormMechanism.look` names a `LookDef` directly
(a `.tres` under `data/looks/` is dragged in; no database), and `FormMechanism.name_key` is the
form's name; `look_at(stage)` and `name_at(stage)` give a cycle stage's own, else the cycle's.
`LookSwap` (`src/gameplay/combat/powers/look_swap.gd`), added to every field body by
`ActionHost.fit_identity`, asks each physics frame which form is held (`FormRun.held`) and only
when the answer changes tints the `CharacterVisual`'s sprite, scales the visual and shows a
`Label3D` tag over the head; with no form it puts the remembered tint and size back. There is no
`Events.look_changed`: asking makes every way a form ends (a cure, a timer, a drain, a load, a
new game, a party switch) show with no wiring. It stays with the body on a switch, so each body
shows the member now on it. With forms of two groups held, the first in kit order with a look
wins. The battle screen's `name_of` reads "Name · Form" (`ui.battle.form_title`) and the HUD's
line leads with the form. **Moved to C6.5e:** `commands`, `replaces_attack`, `aftermath`,
`once_per_battle`, and the name on the party sheet and status screen. A battle body has no
`CharacterVisual` yet, so in a battle only the name shows.

**As built (C6.5e, combat 0.70.0): the form's own commands.** `FormMechanism.commands` is the
menu offered while the form is held, in place of the fighter's own, in a battle and in the
field (`PowerMenu.with_powers` asks `FormRun.commands_of`; the hero powers still follow).
`replaces_attack` is the skill a battle's plain Attack becomes: `Battle` aims, pays and does
the Attack as that skill, statuses still treat it as an Attack, and the menu's Attack row takes
the skill's name. In the field the attack is a button, so a form's `attack_chain` does this
job. A cycle stage with none of its own uses the cycle's (`commands_at`, `attack_at`).
`aftermath` is a status put on when the form ends **by its own rules**: used again, its drain
running dry, or its timed status running out (`StatusSet.running_out` is true while a status
is taken off because its time ran out, which tells that from a cure). A rival of its group
replacing it is a switch, and a cure, a new game, a load or the kit coming off are no end, so
none of those gives it. The aftermath is listed in the form's `statuses()`, so a save keeps it.
**Moved to C6.5f:** `Power.once_per_battle` and the form's name on the party sheet and status
screen.

**As built (C6.5f, combat 0.71.0): once per battle.** `Power.once_per_battle` marks a power
usable once per battle; in the field, once per area. `PowerUse.use` writes it into the user's
`OnceLedger` (`PowerSet.once`), and `PowerUse.refusal` then answers ONCE ("once per battle" in
both menus) before any cooldown. A battle builds fresh `PowerSet`s, so each battle starts clean;
the field's set wipes the ledger on `Events.area_entered` (a new game and a load enter an area
too). Taking a kit off and on, or swapping the gear that lends it, does not wipe it. No party
sheet or status screen exists yet, so the form's name there moved to C7.7, the gear screen, the
first screen that lists each member; it reads `LookSwap.form_name_key(body)`.

## Part 5 · The mechanics survey

What combat systems in well-known games do, and where this base stands. **Have** means built
and merged. **Row** names the board row that builds it.

| Mechanic | Seen in | Status |
|---|---|---|
| Turn order by speed, and by a delay queue (CTB) | Final Fantasy X, Octopath | Have (C2) |
| ATB gauges, wait and active | Final Fantasy IV–IX, VII Remake | Have (C4) |
| Real-time action with combos, dodges and lock-on | Devil May Cry, Ys, Tales | Have (C3) |
| Symbol encounters, mixed formulas | Chrono Trigger, Persona | Have (C5.1) |
| Elements, weakness, shield break, stagger, pressure | Octopath, FF VII Remake, FF XIII | Have (C2.17, C4.6) |
| Buffs, debuffs, ailments, resistances, dispel, revive, drain | Everywhere | Have (C2.13–14) |
| Miss, crit, counter, reflect | Everywhere | Have (C2.15) |
| Boost points, limit gauge, stances | Octopath, Final Fantasy VII | Have (C2.16) |
| Timed hits and timed blocks | Super Mario RPG, Clair Obscur, Royal Guard | Have (C4.10, C6.6b) |
| Forms and styles | Devil May Cry | Have (C6.5) |
| Barriers | Infinity, Blut Vene | Have (C6.6a) |
| Perfect dodge with a reward | Bayonetta's Witch Time, FF XVI | Built (C6.6c): `perfect_window`, `Events.perfect_dodge`, a gauge's `on_perfect_dodge`; a slow-down reward can listen to the event |
| Counter stance and parry | Sekiro, Royal Guard | Built (C6.6d): a COUNTER status with a `counter_move` on a form or a timed-block barrier |
| Projectile barrages | Gate of Babylon | Built (C6.7) |
| Charged finishers | Zantetsuken | Row C6.8 |
| Planted and delayed strikes | Owl, time bombs, rune traps | Row C6.26 (new) |
| Battlefields: domains, terrain, weather, auras | JJK, Fate, Pokémon weather and terrain, Divinity's surfaces | Rows C6.9a–d (widened) |
| Foresight, command, blink, clone, sacrifice, grant, refresh | The kits in `POWERS.md` | Rows C6.10–C6.13 |
| Transformations with a look | The table above | Have: the look and name (C6.5d), commands, the Attack and the aftermath (C6.5e); once per battle (C6.5f); the name on the gear screen in row C7.7 |
| Gear, rarity, sets, sockets, upgrading, crafting | Diablo, Monster Hunter, Souls games | Rows C7.1–C7.9 |
| **An extra turn for hitting a weakness** | Press Turn (Shin Megami Tensei), One More (Persona) | Row C8.1 (new) |
| **Team attacks**: all-out attack, chain and link attacks, dual and triple techs | Persona, Xenoblade, Chrono Trigger | Row C8.2 (new) |
| **Follow-up and assist attacks** from a waiting ally | Honkai: Star Rail, Trails | Row C8.2 |
| **Summons** that fight beside or in place of the party | Final Fantasy, Persona | Row C8.3 (new); a battlefield's `summons` uses it |
| **Swapping party members mid-battle**, with a reserve line | Final Fantasy X, Octopath II | Row C8.3 |
| **Elemental reactions**: two elements on one target make a third effect | Genshin Impact, Divinity | Row C8.4 (new) |
| **Combos between powers** (prime and detonate) | Mass Effect, Hollow Purple | Have, as `requires_statuses` and `consumes_statuses` |
| **Rows and positions**: front and back, a grid, knock-back into hazards | Final Fantasy, Darkest Dungeon, tactics games | Row C8.5 (new) |
| **Aggro and taunt**: who the enemy picks | MMO-style RPGs, Xenoblade | Row C8.6 (new) |
| **A second health layer**: armour, overshield, guard gauge | Halo, Mass Effect, Sekiro posture | Row C8.6; the Mjolnir piece needs it |
| **Steal, scan, capture, mug** | Final Fantasy, Pokémon | Row C8.7 (new) |
| **Instant death, doom counters, petrify, charm, confusion** | Final Fantasy, Dragon Quest | Row C8.7; charm is M8 `command` |
| **Style rank and combo counter** rewards | Devil May Cry | Row C6.22 with Dante's kit (a gauge) |
| **Hit stop, slow motion, launch and juggle** | Character action games | Slow motion: have (`CombatClock`). Launch and juggle: row C8.8 (new) |
| **Quick-time prompts and button mashing** | God of War, Yakuza | Row C8.8, on `TimedWindow` |
| **Interrupts and cast bars**: stop an enemy's wind-up | FF XIV, Xenoblade | Row C8.8; a finisher's charge already breaks on a strong hit |
| **Environmental objects**: explosive barrels, things to throw | Divinity, Yakuza | Row C8.9 (new), on M15 `plant` |
| **Morale, fear, surrender, talk to the enemy** | Shin Megami Tensei, Undertale | Game choice; M8 `command` covers FORGET |
| **Classes, jobs, skill trees, a bestiary** | Many | Game choices, as before; forms cover an in-fight job change |

## The mechanism catalogue (the owner's rule, 2026-11-10)

**The rule: build mechanisms, not weapons.** The owner's words: write the code for the possible
powers, sorted, named and commented, so that weapons can be put together from them later. So a
weapon is never code. It is a data file that combines mechanisms, and the code rows build each
mechanism once. The armoury rows (C7.9, C7.10) make only a few sample weapons, as proof that
the parts combine.

**The idea list.** [`reference/weapon_ideas.csv`](reference/weapon_ideas.csv) is the owner's
list of 2,058 fictional weapons (name, franchise, mechanic group, one-line description). Read it
for ideas before searching the web. Its eleven mechanic groups map onto the mechanisms like this:

| Group in the list (count) | What such weapons do | Built from | Row |
|---|---|---|---|
| Energy / Tech (484) | Beams, blasts, satellite panels, charged shots | M1 `barrage` + `Projectile` (a beam is a LINE shot at speed 0); a charge is a gauge (C6.4) | C6.7, built |
| Elemental (396) | Fire, ice, lightning on the blade or as spells | Gear `element` and `attack_tags` (built, C7.1c); statuses; weakness and Break | C7.1c |
| Transformation (317) | A weapon with modes; a suitcase that opens into a weapon; armour that changes the wearer | M5 `form` with a look and its own moves; **deploy** below | C6.5, C6.5d |
| Projectile (236) | Thrown knives, arrows, volleys, returning throws | M1 `barrage`; M15 `plant` for ones that stay and trigger later | C6.7, C6.26 |
| Curse / Rule (235) | "It always hits", "cannot be healed", binding chains, contract breakers | `sure_hit`; statuses with `blocks`; DISPEL; M9 `command`; rule tags a barrier reads | C6.10 on, C8 |
| Soul / Death (163) | Instant death chance, poison, ignores toughness | A status chance; `bypass` tags through a barrier; `resist_<tag>` | built, C8 |
| Space / Reality (77) | Tears space, erases, rewrites the place | M4 battlefield; a finisher with `anti_world` | C6.8, C6.9a–d |
| Defense (70) | Shields, unbreakable blades, healing scabbards | M3 `barrier`, the timed block, regen stats on gear | built, C7.1 |
| Summon (56) | A giant, a beast, smoke soldiers that fight beside you | Battlefield `summons`; a follower body with a brain (C4.9) | C6.9d, C8 |
| Time (23) | Stop, slow, foresight, rewind | `CombatClock`; M10 foresight; M14 `refresh` | C6.11 on |

**Deploy (the quinque suitcase).** A carried weapon can start closed. Deploying it is entering
a form: the closed state has no moves of its own and a "case" look; the open state brings the
weapon's moves, its powers and its look. That is M5 with a look (C6.5d), so it needs no new
mechanism, only a `deploy` power on the piece's kit (C7.3) and, later, an opening animation.

## Board rows (the order to build in)

Gear first, as the owner asked, then the mechanisms the signature weapons need, then the
weapons themselves.

| Row | Builds | Needs |
|---|---|---|
| C7.1a | Gear as data, worn (built): `GearDefinition`, `GearType`, `GearRules`, `GearDb`, `GearSet`; modifiers on the wearer; saved in `Flags` | — |
| C7.1b | Gear in a fight (built): starting gear on a `CombatantDef`; `GearSet.fit` in `BattleSetup`, `ActionHost` and `ActionEnemy`; a party switch carries the `GearSet`; a foe's gear is not saved; the `[combat] gear/rules` setting | C7.1a |
| C7.1c | The worn weapon on attacks (built): `element` and `attack_tags` lent to the wearer's plain attack in both formulas; `blocks` for two-handed | C7.1b |
| C7.2 | **DONE.** Rarity and drops: `Rarity`, `LootTable`, rolled loot in `Rewards` | C7.1 |
| C7.3 | **DONE.** Special gear: `PowerSet` holds several kits; a piece's `kit`; `Power.requires_gear`; weapon pools | C7.1 |
| C7.3b | A weapon's own swing chain: `moves` on a piece and on a type | C7.3 |
| C6.5d | **DONE.** Transformations you can see: `LookDef`, `LookSwap`, a form's `look` and `name_key`; shown on the body, the battle screen and the HUD with dummy looks | C6.5 |
| C6.5e | **DONE.** A form's own commands: `commands`, `replaces_attack`, `aftermath` | C6.5d |
| C6.5f | **DONE.** `Power.once_per_battle` (the sheet name moved to C7.7) | C6.5e |
| C6.6c | **DONE.** Perfect dodge (`perfect_window`, `Events.perfect_dodge`, `on_perfect_dodge`) and `knockback_taken` | C6.6 |
| C6.6d | **DONE.** Counter stance: `StatusEffect.counter_move`, the field counter in `Hurtbox` | C6.6 |
| C6.7 | Barrage and the `Projectile` node, with sizes: DONE (0.74.0). "Where the misses land" moved to C6.26, which reads it | |
| C6.26 | M15 `plant`: `PlantMechanism`, the `Planted` node, the four triggers, the battle reading, and "where a barrage's misses land" | C6.7 |
| C6.8 | Finisher | |
| C6.9a | Battlefield, the core: `BattlefieldMechanism`, `BattlefieldEffect`, modifiers and statuses per group, durations in seconds, turns or infinite, upkeep, both formulas; `damage_dealt` | C6.6 |
| C6.9b | Battlefield damage and movement: `on_enter`, `on_exit`, ticks on both clocks, `tick_grows`, pull and push, immunity | C6.9a |
| C6.9c | Battlefields against each other: `sure_hit` and `hit_tags`, `closed`, layers, the four clash rules, `broken_by_tags`, `cancelled_by`, `aftermath` | C6.9b |
| C6.9d | The place: `PlaceLook`, `moves_fight`, `weather`, `caster_kit`, `summons`; the log and HUD readout | C6.9c, C6.5d |
| C7.4 | Sets, sockets and requirements: `GearSetBonus`, `GemDefinition` | C7.3 |
| C7.5 | Upgrading and awakening: `UpgradeTrack`, `Power.requires_upgrade` | C7.3 |
| C7.6 | Crafting, the logic: `Recipe`, `Crafting`, dismantle and transmute | C7.2 |
| C7.7 | The gear screen: slots, compare, rarity colours; weapon and mode on the HUD and battle screen; the form's name beside each member | C7.3 |
| C7.8 | The craft screen and `CraftStation` | C7.6, C7.7 |
| C7.2b | Affixes on dropped pieces (per-piece saved state) | C7.5 |
| C7.9 | The armoury, weapons: IXA, Owl, Ea and the other heroes' weapons as data, a probe and captures | C6.26, C6.9, C7.5 |
| C7.10 | The armoury, armours: the table above as data; `AUTHORING.md` § Gear, Battlefields and Transformations | C7.9, C8.6 |
| C8.1–C8.9 | The survey's new mechanics, one row each, in the order of the table | |
| C8.10–C8.15 | The power atlas's new mechanisms ([`POWER_ATLAS.md`](POWER_ATLAS.md)): owned fighters, time, unseen, copy and seal, constructs, late outcomes. Each after the row it stands on | C6.12, C6.9a, C7.3, C6.26 |

## Renaming

| Name | Lives in |
|---|---|
| A piece's name | `localization/strings.csv` (`item.<name>.name`), `data/items/<name>.tres`, `data/gear/<name>.tres` |
| A gear type, a rarity | `data/gear_types/`, `data/rarities/` and their CSV rows |
| A battlefield, a form, a look | The kit file in `data/powers/`, `data/looks/`, and their CSV rows |
| A recipe, a station | `data/recipes/` and CSV rows |

Renaming a `.tres` changes a saved id, as upstream's `Equipment` header explains: a worn piece
comes back in the bag, not lost.

## Sources

The fandom wikis (tokyoghoul, typemoon, jujutsu-kaisen `.fandom.com`) are not reachable from
this build session, so the facts above come from search summaries of them and of the pages
below. Details marked **(reading)** are the game's interpretation, not canon.

- IXA: tokyoghoul.fandom.com/wiki/IXA and /Chapter_139 (through search); vsbattles.fandom.com/wiki/Kishou_Arima; dandwiki.com/wiki/Weapons_(Tokyo_Ghoul_Supplement); echo-from-the-void.tumblr.com/post/144287832024 (the "landmine" reading).
- Owl: tokyoghoul.fandom.com/wiki/Owl_(Quinque) and /Kishou_Arima (through search); vsbattles.fandom.com/wiki/Kishou_Arima; daddyjim.ai/tokyo-ghoul/group/Owl-Quinque.
- Ea: zh.moegirl.org.cn (乖离剑); cbr.com/fate-gilgamesh-ea-sword-how-strong; giantbomb.com (Gilgamesh).
- Domain Expansion: sportskeeda.com (domain expansion, anti-domain techniques); escapistmagazine.com/jujutsu-kaisen-domain-expansions-explained; deltiasgaming.com.
- Reality Marble and Marble Phantasm: zh.moegirl.org.cn (无限剑制, 空想具现化); tvtropes.org (Fate/stay night).
- Transformations and combat systems: tvtropes.org/pmwiki/pmwiki.php/SuperMode/VideoGames; consolepulse.com (Mega Evolution); samurai-gamers.com (FF XVI limit break, FF VII Rebirth battle system); finalfantasy7remake.wiki.fextralife.com/Combat; blazblue.jp manual (Overdrive).
