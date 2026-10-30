# Handoff — start here if you are new to this repository

**Read this if you are a new session, another Claude account, another AI tool, or a person.** It
assumes you know nothing about the earlier chats. Ten minutes here saves an hour of guessing.
`CLAUDE.md` holds the rules and [`COMBAT.md`](COMBAT.md) holds the live state. This page is the map
between them, written in plain words.

## Where things stand

**Update this block at the end of every package.** It is the first thing the next reader sees.

- **Last finished package:** C4.5, the field-command demo: the Wanderer has two ATB bars, and
  F in the lantern hall casts Ember (Magic) or Salve. `AUTHORING.md` § The hybrid lists every
  field.
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
- **Next package:** **C4.6**, pressure and stagger: C2.17's Break and C3's poise, timed in
  seconds (PRESSURED, then STAGGERED, with damage taken raised).
- **Then, in order:**
  1. **The rest of C4, the FF7-Remake-style hybrid (C4.7–C4.10).**
  2. **C5, mixing formulas, hardening and 1.0.0 (C5.1–C5.7).**

  Every row's detail is on the board. The facts the plan rests on are in `COMBAT.md` § C2b,
  "Settled by C2.11".
- **Known gaps:** each package's "Gaps" list in `COMBAT_DEVLOG.md`, newest last.

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
| `src/systems/combat/` | **Pure maths, no nodes:** the combat clock (how fast the fight runs), the ATB gauge, the move timeline (which phase a real-time move is in), the action decider (what a real-time enemy does next), the stat sheet (base value plus modifiers), the damage formula and its stages (hit or miss, attack against defence, element, vulnerability, critical hit, variance), the request and result of one hit, and the turn schedulers (rounds, and CTB). |
| `src/gameplay/combat/` | **Things living in the game:** `Vitals` (HP and other pools, saved through `Flags`), `Meters` (pools that refill each turn or fill when hit), `Weakness` (shields and Break), `StatusSet` (the buffs and ailments on one fighter), `Combatant` (makes a node fightable), `Hitbox` and `Hurtbox` (real-time hits), `ActionFighter` (a body that swings and dodges), `LockOn`, `ActionEnemy` (a real-time enemy's body) and `ActionHost` (fits the player out as a fighter, and grants field rewards), `FieldDefeat` (what the player's fall means), `AtbMeter` (the ATB gauge on a field fighter), `FieldCommands` (using a skill or item mid-fight), `Battle` (the referee of one turn-based fight), `BattleAi`, `BattleSetup` (builds fighters from data), `Party` and `Rewards`. |
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
