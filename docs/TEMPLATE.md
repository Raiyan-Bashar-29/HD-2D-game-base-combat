# This is a template, not a game

**Read this before `ROADMAP.md` or `WORK_PACKAGES.md`.** It reframes both, and several older
lines in the other documents were written before it and have not all been corrected yet.

## The reframing, in the owner's words

> We're not making the entire game, rather the **formula** that we'll use in many games — kinda
> like how we use formulas to solve a problem. The game is our problem, which can vary. The
> formulas stay constant and we mix-match/use based on what we need. That's the base of the
> game, or the barebones **skeleton**.

So: **the product is the systems and the seams between them.** The courtyard, the garden-keeper
and the rose key are not the product. They are the *proof that a system works*, and they are
deletable.

This was decided on 2026-08-26, after WP-07. Everything built before it is still correct — the
architecture was already formula-shaped — but the *planning documents* were not, and are being
corrected package by package.

## What this changes

| Before | Now |
|---|---|
| "a skeleton with a home for every system **the finished game** will need" | there is no *the* game; there are many |
| Exit criteria: "the player can rest **on the bench**" | "a `RestPoint` skips the clock and the environment re-samples" |
| Phase 3 "thirty minutes that represent the finished game" | out of scope — that is a *consuming game's* phase |
| **Depth before breadth** — "no second region until the first is genuinely good" | **RETRACTED.** Breadth of systems, one shallow proof each. See below. |
| Success = a good game | Success = a second, different game can be started without editing `src/` — and can still receive a later fix to the base, which is [`UPGRADING.md`](UPGRADING.md) |

### The retraction of "depth before breadth"

`ROADMAP.md` used to state, as doctrine and as "the single lesson from eleven shallow regions":

> Depth before breadth. No second region until the first one is genuinely good.

**That rule is retracted with the same weight the no-combat retraction has.** It is the correct
rule for one game and the wrong rule for a formula library, and it directly contradicted
`WORK_PACKAGES.md`'s own definition of the skeleton — *"every system has a working minimal
implementation plus one piece of placeholder content proving it."*

Left in place it would keep steering packages toward deepening the courtyard. If you find
yourself about to add polish to demo content, that is the retracted rule winning an argument it
should not be in.

**The replacement:** breadth of systems, one shallow proof each.

## Engine vs demo — the boundary

### The rule

> **No file under `src/` may name demo content.**

Not an area id, not an item id, not a conversation id, not an NPC id. This rule exists because
`src/core/boot/game_root.gd` once carried `const FIRST_AREA := &"courtyard"` — engine code in the
layer that is supposed to know nothing about the game — and it passed eight verification rungs, a
budget checker, a content checker, 900 assertions and an adversarial review, **because no rule
forbade it.**

That is the failure mode this project exists to prevent: not wasted effort, but an unguarded
boundary that accumulates silently.

### What is what

| Path | Kind | On starting a new game |
|---|---|---|
| `src/` | **Engine.** All of it. | Keep. Never edit to start a game. |
| `scenes/objects/`, `scenes/characters/`, `scenes/boot/` | **Engine.** Reusable prefabs. | Keep. |
| **your own code root** — `game/`, or scripts beside your areas | **Yours.** Tier 2 subclasses and anything else your game needs | Keep yours. **The base ships none, and none of the seven checkers scans it** — see below |
| `tools/`, `tests/framework/` | **Engine.** | Keep. |
| `data/**` | **Demo.** Every `.tres`. | Delete, and author your own in the same folders. |
| `scenes/areas/**` | **Demo.** | Delete, and author your own. |
| `localization/strings.csv` | **Mixed.** `verb.*`, `refusal.*`, `ui.*`, `notify.*`, `weather.*`, `time.*`, `item.category.*` are engine; `object.*`, `item.*`, `talk.*`, `action.*`, `area.*` and `quest.*` are demo — the six `check_boundary.gd` derives its CONTENT_NAMESPACES from, which is the list that fails a build. | Prune the demo half. |
| `tests/unit/` | **Engine**, as of T1.3. Cases build what they need from `tests/framework/`, and the blocks that genuinely assert things about a game skip themselves and say so. | Keep. |
| `project.godot` | **Mixed, and the one place a demo id belongs.** `[game] world/first_area` names the starting area; `[template] base/version` is the BASE's own version and is not a game's to touch. | Rename the four `application/config/*` fields and point `first_area` at your own. Leave `base/version` alone — [`UPGRADING.md`](UPGRADING.md) § 1. |

**YOUR CODE ROOT IS YOURS AND THE LADDER DOES NOT WATCH IT, WHICH T5.30 MEASURED RATHER THAN
ASSUMED.** The base ships no game code root and names none, so pick one — `game/` at the top level
is the obvious choice. Then know what you are and are not getting: **all seven checkers scanned a
fork carrying three Tier 2 subclasses and passed, including over a planted raw player-facing string
literal and a planted public method with no caller.** `check_strings.gd`, `check_methods.gd`,
`check_budgets.gd`, `check_layers.gd` and `check_boundary.gd` all scan `src/`, `tests/` and
`tools/` — not your root.

Two of those are a **relief** and should stay that way: `check_boundary.gd` exists to prove the
ENGINE does not know your content exists, and your own code is entitled to name your own ids, so
pointing that gate at your root would fail you for doing the right thing. The rest are a **choice
you now have to make deliberately** — whether your game inherits the base's discipline or writes
its own. Nothing decides it for you, and nobody had noticed the question until a fork was made.

`data/` and `scenes/areas/` being demo is not a coupling — they are the **content roots a game
fills**, and the registries scanning them is a convention the template defines. A new game puts
its own items in `data/items/` and its own areas in `scenes/areas/`.

**The full checklist is [`NEW_GAME.md`](NEW_GAME.md)**, and its claims were run against a
stripped copy rather than written from intent.

### The gate

`tools/check_boundary.gd` enforces the rule as of T1.2, 2026-08-26, and since T1.3 it scans
`tests/framework/` and `tests/unit/` as well as `src/`. It **derives** the forbidden
names rather than listing them — every folder under `scenes/areas/`, the `id` of every `.tres`
under `data/`, and each id's last segment — so it cannot go stale when content is added, and it
fails on any of them appearing in a CODE line under `src/`.

**Comments are exempt, code is not**, and that line was drawn deliberately. A `##` line saying
`data/items/rose_key.tres must declare id = &"item/rose_key"` is teaching by example; it changes
no behaviour, and forbidding it would push the documentation into abstraction nobody can follow.
A `const FIRST_AREA := &"courtyard"` changes behaviour. That is the whole difference.

**One directory is exempt: `src/systems/debug/`.** Those three files exist to drive the demo —
`--give=item/rose_key` stages a photograph, a probe that travelled to an abstract area would
verify nothing. The exemption rests on a precondition the same tool checks: their argument
parsing is behind `OS.is_debug_build()`, so they are unreachable in a shipped build. The names
they use are counted and printed, never silently skipped.

What the gate cannot see is stated in its own header: a name assembled at runtime, a demo name
that exists in neither `data/` nor `scenes/areas/` (a waypoint marker, a node name inside an area
scene), and anything outside `src/**/*.gd`.

### Known gaps in the boundary, as of 2026-08-26

None in the boundary itself. The last one closed with T1.3.

**Closed by T1.3:** the test suite was welded to the demo — about a third of its assertions named
demo content, so deleting `data/` would have deleted rung 4 of the ladder. `tests/framework/`
now builds the content a case needs, `tests/unit/` is inside the boundary gate, and a stripped
checkout runs the whole suite: `861 passed, 0 failed, 12 skipped`, with every skip named and
counted so a stripped run cannot look identical to a full one.

**Closed by T1.2:** `game_root.gd`/`director.gd` naming the first area (now the project setting
`[game] world/first_area`, read through `GameConfig`); `log.gd` baking in `Gulistan` (now
`application/config/name`); nothing enforcing the rule (now `tools/check_boundary.gd`); and the
debug nodes answering `--give=`, `--standing=` and `--goto=` in a release build.

## Optional modules

"Mix-match based on what we need" implies some systems are opt-in. `SYSTEMS_INVENTORY.md` will
grow an **OPTIONAL** status for these. Crafting is the clearest case: it is a genre choice, not a
requirement of every game built on this base.

## The constraint that is now scoped — see ADR-0007

**There is no combat, and as a *template* rule that forecloses combat for every game built on this
base.** That was decided for one game. It is recorded here because it is now a much larger
commitment than it was, and nobody had said so out loud.

The same class of question applies to a few other decisions made for one game's constraints and
now imposed on all of them — most notably "a conversation is not saved". What was missing was the
distinction between a **template default** and a **game choice**.

**[`ADR-0007`](decisions/ADR-0007-template-default-vs-game-choice.md) draws it, and draws it three
ways rather than two:**

| Kind | A game… | Test |
|---|---|---|
| **TEMPLATE RULE** | cannot override it; wanting to is a fork | no seam exists, and a checker enforces it where the rule is mechanical |
| **TEMPLATE DEFAULT** | replaces the value through a seam, touching no `src/` file | **a seam exists** |
| **GAME CHOICE** | builds it in its own code root, on the base's signals and flags | the base builds nothing |

**The test that separates a default from a rule is whether a seam exists** — a "default" a game
cannot replace without editing `src/` is a rule that has not admitted it. No combat is a RULE, and
so are the layer rule and the demo-name boundary, both of which have checkers. Time is a DEFAULT.
A chapter sequencer and an economy are GAME CHOICES, and the ADR says why.

**The kind is now stated wherever a choice is recorded**, which is what stops the drift this
section was written to warn about: "no combat" grew from one game's constraint into every game's
foreclosure with no document marking the moment.

## Read next

`docs/ROADMAP.md` for the phases · `docs/WORK_PACKAGES.md` for the board · `docs/CONTEXT.md` for
where things stand right now.
