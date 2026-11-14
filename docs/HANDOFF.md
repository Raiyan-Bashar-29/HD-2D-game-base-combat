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
- **C6.5f is done (0.71.0): once per battle.** `Power.once_per_battle` refuses a power after
  one use until the next battle, or the next area in the field (`OnceLedger` on `PowerSet.once`).
  The form's name on a party sheet waits for C7.7, the gear screen.
- **C6.6c is done (0.72.0): perfect dodge and no flinch.** A dodge's `perfect_window` makes a
  hit dodged early a perfect dodge (`Events.perfect_dodge`, `GaugeRule.on_perfect_dodge`); the
  `knockback_taken` stat scales a push, and −1 means no push and no flinch.
- **C6.6d is done (0.73.0): the counter stance.** A COUNTER status may name a `counter_move`:
  in the field the holder swings it at whoever hit it, without flinching; in a battle the
  counter strikes with its numbers. On a timed-block barrier, that is a parry.
- **C6.7 is done (0.74.0): the barrage.** A `BarrageMechanism` fires shots from a pattern,
  each a `Projectile` (a moving `Hitbox`) flying an `ActionMove`; homing, pierce, sizes, a drawn
  element, and a speed-0 line for a beam. In a battle its hits land at once on random foes.
- **C6.26 is done (0.75.0): the plant.** A `PlantMechanism` leaves `Planted` nodes (still
  hitboxes) that go off on a second use, a foe coming near, a timer or a foe beside them being
  hit; a barrage's misses can stay in the ground. In a battle a plant is a mark on a foe.
- **C6.8 is done (0.76.0): the finisher.** A `FinisherMechanism` charges (seconds in the field,
  turns in a battle, holding a `charging` status that a hit can break), stops the field fight
  for a `flourish` (the `Flourish` node), then lands one big `strike`, scaled by the power's
  POWER and HITS rules (a gauge through POOL_FRACTION, emptied by `drain_pool`).
- **C6.9a is done (0.77.0): the battlefield core.** A `BattlefieldMechanism` is a form whose
  status marks it standing; each of its `BattlefieldEffect`s gives one group (the caster, its
  side, the other side, everyone, everyone but the caster) modifiers and statuses while they
  are inside, around the caster (`radius`) or the whole fight, for `seconds` or `turns` or
  until ended, with the form's drain as upkeep. New stat `damage_dealt`.
- **C6.9b is done (0.78.0): battlefield damage and movement.** Each effect can use a skill on
  its group as a fighter comes in (`on_enter`), as it leaves (`on_exit`) and on a clock
  (`tick`, every `tick_seconds` or `tick_turns`, growing by `tick_grows`); `pull` and `push`
  move the group in the field; `immune_tags` and the stat `resist_field_<name>` keep fighters
  out. Batch 2 (C6.8, C6.9a, C6.9b) is complete and goes up as one PR.
- **C6.9d is done (0.80.0): clashes and `closed`.** `BattlefieldClash` judges a battlefield that is about to rise against each standing one in its `layer`, on its clock, that overlaps it; the newer one's `clash` rule decides, with `refinement` (scaled by `refinement_stat`) for strength. `BattlefieldWall` holds fighters at a closed field's edge each tick. Battle `closed` changes nothing yet (no edge until C6.9e).
- **C6.9c is done (0.79.0): battlefields against each other, the hit side.** A battlefield's
  `sure_hit` and `hit_tags` are flags its caster holds while it stands, read by `Combatant.hit`
  (`HitFlags`); `cancelled_by` leaves a target to a roll; `broken_by_tags` ends the battlefield
  on a landed field hit (a battle attack does not break it yet).
- **Next: C9.8, research on fighting-game character files** (documents only), then C7.6, C9.7, C9.9e. C9.6d is done: all thirteen kakujas are kits and armours. To add another converted character, follow `docs/POWERS.md` § From a M.U.G.E.N character to a playable fighter. To play as Arima, set `[combat] action/loadout` to `res://data/action/arima_loadout.tres`.
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

**Merging while the Actions quota is used up (owner, 2026-11-13):** until the monthly quota resets, a batch PR is merged WITHOUT waiting for CI. The full ladder is run locally first (import, boot, the suite, all seven checkers, the stripped run), and the PR body says so. When the quota is back, green CI is required again.

**One PR at the end (owner, 2026-11-13):** while the Actions quota is out, no batch PRs. Every finished package is pushed to the working branch (free), and ONE PR is opened when the remaining board rows are finished, or sooner if the owner asks. The local ladder stays the gate for every package. Focus is code: keep document updates short.

- **One package at a time, all the way to done:** tested and verified locally, committed, and
  pushed.
- **Pull requests come in batches (owner, 2026-11-11, to save the GitHub Actions quota):**
  the ladder runs on pull requests and on `main` only, so a push to a working branch costs
  nothing. Push each finished package at once (the container is temporary), but open the draft
  PR only when a batch is complete: about three packages, or sooner when a group of rows closes.
  Merge it on green CI. Between packages of one batch, keep working on the same branch (merge
  `template/main` in); restart from `origin/main` only after the batch's PR has merged.
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
7. Commit and push (a working branch runs no CI). Open a pull request when the batch is
   complete (§ Working rhythm), wait for green CI, then merge.
