# Handoff — start here if you are new to this repository

**Read this if you are a new session, another Claude account, another AI tool, or a person.** It
assumes you know nothing about the earlier chats. Ten minutes here saves an hour of guessing.
`CLAUDE.md` holds the rules and [`COMBAT.md`](COMBAT.md) holds the live state. This page is the map
between them, written in plain words.

## Where things stand

**Update this block at the end of every package.** It is the first thing the next reader sees.

- **Last finished package:** C6.0c, the power atlas (docs and data, 0.66.1). The owner's
  powers pack (3,306 powers in 116 handler families, 127 character profiles) and full weapons
  list are kept whole in `docs/reference/originals/`, with slim copies beside them, and
  [`POWER_ATLAS.md`](POWER_ATLAS.md) sorts every family onto the mechanism that runs it and
  adds rows C8.10–C8.15. **Read it before building any mechanism or kit row.** Before it,
  C7.1c, the worn weapon on attacks. A worn piece lends the
  wearer's plain attack an `element` and `attack_tags` (`GearSet` writes them onto the
  `Combatant`; `Battle`'s ATTACK and `Hurtbox` read them), and a piece can take up more slots
  through `blocks` (two-handed = blocks the off hand). Before it, C7.1b, gear in a fight. A fighter's definition lists the gear it
  starts with (`CombatantDef.gear`). `GearSet.fit` gives a fighter its worn set in a battle
  (`BattleSetup`), in the field (`ActionHost`) and on a field enemy (`ActionEnemy`), and a
  party switch carries it. Starting pieces go on once and need not be in the bag; a foe's gear
  is never saved; a game names its slot list in `[combat] gear/rules`. Before it, C7.1a: a
  piece of gear is an upstream item plus a `GearDefinition` file, worn through `GearSet`, one
  piece per slot, saved in `Flags`. The owner's rule (2026-11-10): build mechanisms that
  combine, not every weapon; the idea list is `docs/reference/weapon_ideas.csv` and the
  mapping is `GEAR.md` § The mechanism catalogue.
- **C7.2 is done (0.67.0): rarity and drops.** A piece of gear names a `Rarity` tier
  (`data/rarities/`), which scales its stat changes and makes it rarer in rolled loot. A
  `LootTable` on an encounter or a fighter is rolled by `LootRoll` on a win or a field kill.
- **C7.3 is done (0.68.0): special gear.** A piece with a `kit` lends the wearer hero powers
  while worn. `PowerSet` holds several kits at once (own first, then gear's in slot order), a
  power can need a piece (`Power.requires_gear`), and a piece carries its own pool with a
  `max_<pool>` modifier. The incoming-hit hook is now `PowerGuard.incoming`.
- **C6.5d is done (0.69.0): transformations you can see.** A form's `look` (a `LookDef`: a
  tint, a size and a tag over the head) goes on the body while the form is held, through a
  `LookSwap` node on every field body that asks each frame; the battle screen and the HUD name
  the form.
- **C6.5e is done (0.70.0): a form's own commands.** While held, a form's `commands` stand in
  for the fighter's menu, its `replaces_attack` turns a battle's Attack into a skill, and its
  `aftermath` goes on when it ends by its own rules (used again, drained, timed out).
- **Next: C6.5f, once per battle and the form on the party sheet.** The build order is
  the table at the foot of `GEAR.md`: C6.5f, C6.6c, C6.6d, C6.7, C6.26, C6.8, C6.9a–d, then the rest of C7.
  The fandom wikis were not reachable when C7.0 was written; if they are now, check the
  "(reading)" lines in `GEAR.md` § Part 2 against them.
  **A new combat test is listed in `tests/combat_cases.gd`** (since C6.5c), not in upstream's
  `tests/test_runner.gd`, whose own list had reached its line budget.
  Before it, C6.5b, a form plays its own moves: while held, its `attack_chain`
  and `dodge` replace the fighter's own in the field (`PowerSet.moves_over`, read by
  `ActionFighter.current_moves()` and the follower's swing), a cycle stage plays its own or the
  cycle's, and `drain_per_action` drains for each move started.
  Before it, C6.5a, forms, the first built-in mechanism (M5 `form`): a form's
  power enters it (its status is held) and leaves it; one form per `exclusive_group`; a `cycle`
  moves on with each use and after a power in `advance_after`; a drain by the second (field) or
  turn (battle) ends it at an empty pool. `FormMechanism` and `FormRun` live in
  `powers/mechanisms/` under content and gameplay.
  Before it, C6.4b, the other gauge events: a `GaugeRule` also moves on a kill
  of the holder's own, an ally falling, a move unlike the last (the field), points of another pool
  spent as a cost (`spent_pool`, `on_spent`), and a running second on top of a moving one. The HUD
  already shows a gauge and its level. **C6.4 is complete.**
  Before it, C6.4a, kit gauges run: a kit's `GaugeRule`s (`PowerKit.gauges`)
  move its gauge pools by the second, the battle turn, standing still or moving, and for each hit
  landed or taken, dodge and miss, through a `KitGauges` that `PowerSet` feeds; a status tag can
  pause a rule (`blocked_by_tags`), and each gauge's level status follows its pool.
  Before it, C6.0b, documents only: two more characters for the main character,
  Isliid (Grand Summoners; Emperor, Defier of Fate, Human Pinnacle forms and three swords) and
  Roland (The Last Cloudia; base, Ascended and Heroic Lord forms), in `POWERS.md`, with a
  fourteenth mechanism (`refresh`) and kit rows C6.24 and C6.25.
  Before it, C6.3b, the HUD's slot line: `CombatHud` shows each quick slot's
  key, power and cost, or "ready in 3s" counting down, from a new
  `Events.power_cooldown_changed` that `PowerSet` emits when the whole seconds or turns left
  change; the F menu redraws when a power is ready again.
  Before it, C6.3a, quick slots: keys 1 to 4 (rebindable, no pad default) use
  the kit's first four non-passive powers in the field through `PowerSlots` and
  `ActionFighter.press_slot`, with no menu and no ATB.
  Before it, C6.2c, hero powers in the menus: the battle menu and the F
  overlay list a fighter's powers under one Powers row (`PowerMenu`), a refused power greyed out
  with its reason in words, and every cost as the fighter really pays it.
  Before it, C6.2b, hero powers in the field: the player and each follower
  wear their fighter's `power_kit`, a party switch carries it with the member, a POWER
  command goes through `FieldCommands` with no ATB cost, and a kit's passive survives a load.
  Before it, C6.2a, hero powers in a turn-based battle: a fighter whose
  `CombatantDef.power_kit` is set has the kit equipped when the battle builds it, and a POWER
  `BattleCommand` uses a power through `PowerUse`, its cooldown counted in the holder's turns.
  Before it, C6.1b built the gameplay side in `src/gameplay/combat/powers/`: `PowerSet` (equips a kit on a body, counts cooldowns, runs
  mechanisms), `PowerUse` (why a power is refused, who it aims at, scaling, using it),
  `PowerMechanisms` (which executor runs which mechanism) and `PowerExecutor` (the base every
  mechanism's code extends). C6.1a's data shapes are in `src/content/combat/powers/`. The design
  is [`POWERS.md`](POWERS.md).
- **Combat version:** see `[combat] core/version` in `project.godot`, and the bold version in
  `COMBAT.md` § Releases. A test keeps the two equal.
- **What works today:**
  - the shared combat core (C1): stats, HP and other pools, the damage formula, statuses,
    factions;
  - the whole turn-based formula (C2): a courtyard encounter you can walk up to and fight, with
    rewards and levels at the end;
  - C2b, combat depth (complete): one shared skill path (cure, dispel, revive, drain,
    multi-hit), sleep, stun and silence, resistance, misses, counters, reflect, meters,
    stances, Boost, weakness, Break, a battle menu with categories, and a readout with a
    battle log. `AUTHORING.md` § Skills, statuses and combat depth lists every field.
  - C3, the action formula (complete): real-time moves as data, hitboxes, the player's
    chain and roll, lock-on, enemies that chase and lunge, field defeat and rewards, and a HUD.
    `AUTHORING.md` § Action combat lists every field.
  - C4, the hybrid (complete): the fight's own clock, ATB, a command menu over the running
    fight, pressure and stagger, a party in the field that thinks and fights, and three variants.
    `AUTHORING.md` § The hybrid lists every field.
  - C5.3a: the six combat controls are rebindable from Options -> Controls (upstream
    `Actions.add_rebindable`, 5.18.0).
- **Next package:** **C6.4b**, the HUD's gauge readout and the gauge events that need new wiring (kill, ally defeated, a new move, spending; `COMBAT.md` board). Then the C6 rows in board order: the mechanisms, then one kit per character (eleven now, Isliid and Roland last).
- **Then, in order** (unless the owner reorders):
  1. **C5.3b–C5.7:** upstream T7.4 (a game settings section) and the combat settings on it,
     accessibility, docs, a playtest, 1.0.0.
  2. **C5.3c:** pad triggers on the controls screen (upstream first).
  3. **C5.8:** a fall safety net (found in C4.11).

  Every row's detail is on the board. The facts the plan rests on are in `COMBAT.md` § C2b,
  "Settled by C2.11".
- **Known gaps:** each package's "Gaps" list in `COMBAT_DEVLOG.md`, newest last.

## Working rhythm (the owner's standing preference)

- **One package at a time, all the way to done:** tested, committed, pushed, and the PR merged
  on green.
- **Then stop and report,** ending the report with **"Good time to /compact now."**
- The owner runs `/compact`. In Claude Code, a `PostCompact` hook in the owner's user settings
  wakes the session, and the next package starts without anyone typing "continue". With no
  hook, wait for the owner's go-ahead.
- **Never schedule timers or routines to resume work.**
- **Pick the recommended option without asking,** and fix what needs fixing on the way.
- **The owner asked (2026-11-03) for this rhythm to hold everywhere,** so it is written here, in
  the owner's user memory, and in upstream's `.claude/agent-notes.md`.

## What this repository is, in five lines

1. It is a **base template** for HD-2D games in Godot 4.7.2 with GDScript. It is the systems for a
   game, not a game.
2. It is the **combat fork** of a non-combat base. The non-combat repository is the git remote
   called `template`, and its fixes arrive by `git merge template/main`. Combat code never goes
   back up ([ADR-0008](decisions/ADR-0008-combat-is-in-scope.md)).
3. It will hold **three combat formulas** a game can pick from: turn-based (done), action (done), and a
   hybrid of both.
4. The courtyard, the training dummy, the thicket encounter and the two party members are **demo
   content**. They prove a system works and a real game deletes them. Code under `src/` and
   `tests/` may never name them, and a checker enforces that.
5. **Art is deferred.** Everything runs on generated placeholder art.

## How to pick up the work

1. **Get the engine.** A Claude Code cloud session does this for you, through
   `.claude/hooks/session-start.sh`. Anywhere else on Linux, run `bash tools/cloud_setup.sh`, then
   use `godot` wherever the docs say `"$G"`.
2. **Read three things, in this order.**
   - `CLAUDE.md`: the rules.
   - `COMBAT.md`: the phases, the board and the releases. The first row not marked **DONE** is
     your package.
   - That row's text: its file list is all you need to open.
3. **Work one package at a time, and finish it before starting the next.** This is the owner's
   standing rule: never build several half-working things at once. Branch from `origin/main`, then:
   - make it red first: write the test, watch it fail, then make it pass;
   - update the docs;
   - open a pull request;
   - merge when CI is green.

   The next package starts from the merged `main`. Never run two packages at once.
4. **Before you start, bring upstream in:**
   `git fetch template main && git merge template/main`. It is usually already up to date.

## The commands that prove a change works

Run these from the repository root. All of them must pass before anything is called done.

```bash
G=godot
$G --headless --import                                   # build the import cache first
$G --headless --quit-after 30                            # boot: must end "0 warnings, 0 errors"
$G --headless res://tests/test_runner.tscn --quit-after 400   # the suite: exit 0, prints "N passed, 0 failed"
for c in budgets content boundary strings layers signals methods; do
  $G --headless --script tools/check_$c.gd || echo "FAILED: $c"
done
```

To see the game in a cloud container, which has no screen, use `xvfb-run` to take a screenshot.
The exact command is in `.claude/agent-notes.md`. Headless mode draws nothing, so a visual claim
needs a capture.

CI (`.github/workflows/ladder.yml`) runs the same ladder twice: once on the full checkout, and once
with the demo content deleted. Both must be green to merge.

## Where the combat code lives

The layers point one way only: `core` → `content` → `systems` → `gameplay` → `ui`. A file may use
anything to its left and nothing to its right.

| Folder | What is in it, in plain words |
|---|---|
| `src/content/combat/` | **Data shapes** that designers fill in as `.tres` files: a stat modifier, a status effect, a skill, a battle command, a real-time move, move set and loadout, the ATB rules, an enemy's action brain, a defeat rule, an enemy or party-member definition, an encounter, an AI brain, a level curve, a party roster, and the faction table. Each has `problems()`, which lists what is wrong with it. |
| `src/systems/input/combat_actions.gd` | The action-combat inputs (attack, dodge, lock on), installed at boot by `ActionHost` because upstream's `Actions` may not be edited. |
| `src/systems/combat/` | **Pure maths, no nodes:** the combat clock (how fast the fight runs), the ATB gauge, the move timeline (which phase a real-time move is in), the action decider (what a real-time enemy does next), the stat sheet (base value plus modifiers), the damage formula and its stages (hit or miss, attack against defence, element, vulnerability, critical hit, variance), the request and result of one hit, and the turn schedulers (rounds, and CTB, which `advance` can feed with time for an ATB battle), and `TimedWindow` (a timed hit's power multiplier). |
| `src/gameplay/combat/` | **Things living in the game:** `CombatSaveGuard` (refuses a save mid-battle or while the player lies fallen), `SymbolEncounter` (a field foe that opens a turn-based battle on touch or on a strike), `Vitals` (HP and other pools, saved through `Flags`), `Meters` (pools that refill each turn or fill when hit), `Weakness` (shields and Break), `FieldParty` and `PartyFollower` (the party in the field, switching who you control, and a follower that thinks and fights), `BrainContext`, `BattleBrainContext` and `FieldBrainContext` (what a brain may do in a battle or in the field), `StatusSet` (the buffs and ailments on one fighter), `Combatant` (makes a node fightable), `Hitbox` and `Hurtbox` (real-time hits; `Hurtbox.nearest_hostile` finds a body's nearest foe), `ActionFighter` (a body that swings and dodges), `LockOn`, `ActionEnemy` (a real-time enemy's body) and `ActionHost` (fits the player out as a fighter, and grants field rewards), `FieldDefeat` (what the player's fall means), `AtbMeter` (the ATB gauge on a field fighter), `FieldCommands` (using a skill or item mid-fight), `Battle` (the referee of one turn-based fight), `BattleAi`, `BattleSetup` (builds fighters from data), `Party` and `Rewards`. In `powers/`: `PowerSet` (the hero powers a body has equipped, and their cooldowns), `PowerUse` (refusing, aiming, scaling and using a power), `PowerMechanisms` and `PowerExecutor` (which code runs a power's mechanism). |
| `src/gameplay/interactables/` | `StrikeTarget` (something you hit by interacting, such as the training dummy) and `EncounterPoint` (something that starts a fight). |
| `src/ui/combat/` | `CombatHud` (the field readout), `BattleScreen` (the battle menu), `BattleMenu` (what the menu offers, and why a row is greyed out), `BattleLog` (the running commentary), `BattleHost` (opens the screen when an encounter is requested), `CommandOverlay` (the hybrid's command menu over the running fight) and `CommandHost` (opens it on the command key). |
| `src/core/events/events.gd` | Every cross-system signal, including the combat ones at the bottom. Read it to see how things connect. |
| `tests/unit/*_test.gd` | One test file per system. They build their own made-up content, so they pass with the demo deleted. |
| `data/` | Demo content: skills, statuses, encounters, the party roster, and the action loadout and enemies in `data/action/`. |

**Every `.gd` file starts with a `##` header** that says what it is, its rules, what it **OWNS**,
and what it **MUST NOT** do. The larger files also carry an **IN PLAIN WORDS** paragraph. Read the
header before the code.

## How one turn-based fight flows

1. The player interacts with an `EncounterPoint` in the field. It emits
   `Events.encounter_requested(id)`.
2. `BattleHost` hears it, loads the encounter and the party roster, and calls `BattleSetup.build`.
3. `BattleSetup` makes one node per fighter, holding `Vitals`, `StatusSet` and `Combatant`, then
   picks the turn order and starts a `Battle`.
4. `BattleScreen` opens over the field and pauses it. Enemy turns play through `BattleAi`. On a
   party member's turn, the menu waits for the player, and the chosen command goes to
   `Battle.act`.
5. `Battle.act` checks the command is legal, pays its cost, and hits through `Combatant.hit`. The
   hit uses the damage formula, then `Vitals` loses HP.
6. When one side is down, `Rewards.grant` gives experience and loot. Continue closes the screen,
   `BattleSetup.release` frees the fighters, and the field unpauses exactly where it was.

## Rules that will bite you

- **Static typing is mandatory, and a warning is an error.** Untyped code does not run.
- **Indent with tabs.**
- **No player-facing text in code.** Text goes in `localization/strings.csv` and code uses its key.
  Quote any value that contains a comma.
- **A public method nothing calls fails `check_methods`.** Either call it, or add `NO CALLER`
  with a reason in its `##` comment.
- **A declared signal with no emitter fails `check_signals`.**
- **A test's `plan(n)` must equal its exact number of `equal()` calls.**
- **To make a test fail on purpose**, stub with `if true or <condition>:`, never a bare
  `return`, which is an unreachable-code error.
- **Do not edit upstream's files when you can avoid it.** Every edit there is a future merge
  conflict. Combat records go in `COMBAT.md` and `COMBAT_DEVLOG.md`, not upstream's `DEVLOG.md`
  or `WORK_PACKAGES.md`.
- **Each package bumps `[combat] core/version`:**
  - minor for new behaviour;
  - patch for comments or docs;
  - change it in `project.godot` and in `COMBAT.md`'s bold release line together.
- More engine traps are in `CONTEXT.md` (the numbered gotcha list) and `.claude/agent-notes.md`.

## Closing a package (the checklist)

1. The ladder above is green: import, boot, suite and all seven checkers.
2. New behaviour has test assertions, written red first.
3. The `COMBAT.md` board row is marked **DONE**, with what shipped and any change from the plan.
   The release line is bumped and the "Last updated" line is current.
4. `COMBAT_DEVLOG.md` has a new entry headed `## <date> — Cn.m · <title>`, with what was done, why,
   how it was verified, what it unblocks, and its gaps.
5. **This page's "Where things stand" block is updated.**
6. New code has plain comments wherever the reason is not obvious from the line itself.
7. Commit, push, open a pull request, wait for green CI, then merge. Only then start the next
   row.
