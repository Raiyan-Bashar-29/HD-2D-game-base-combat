# Working on Project Gulistan

Read this before touching anything. It is short because the detail lives in `docs/`.

**Start with [`docs/CONTEXT.md`](docs/CONTEXT.md)** — one minute, and it tells you what exists,
what is broken right now, and what not to re-litigate. This file is the rules; that one is the
situation; [`docs/TEMPLATE.md`](docs/TEMPLATE.md) is the framing both assume.

**Which doc do I need?**

| If you are… | Read |
|---|---|
| starting any session | `docs/CONTEXT.md`, then your package on the board |
| confused about what this project IS | `docs/TEMPLATE.md` |
| picking the next package | `docs/WORK_PACKAGES.md` (the board) and `docs/ROADMAP.md` |
| surprised by the engine | the gotcha list in `docs/CONTEXT.md` — eighty-three, each cost an hour |
| wondering why a file is shaped that way | its own `##` header first, then `docs/ARCHITECTURE.md` and `docs/decisions/` |
| about to write a player-facing string | `localization/strings.csv`, and quote any value containing a comma |
| starting a new game on this base | `docs/NEW_GAME.md` |
| **pulling a later template fix into a game already forked from it** | **`docs/UPGRADING.md`**, then `docs/CHANGELOG.md` |

**Never read `docs/DEVLOG.md` whole** — it is over 9,000 lines and grows every session. Find the
entry you need by its `## date — WP-nn` header.

## What this is

**A reusable BASE TEMPLATE for HD-2D exploration games. Not one game.** Godot 4.7.2, GDScript.
Read [`docs/TEMPLATE.md`](docs/TEMPLATE.md) â it is short, and it reframes the roadmap and the
board, several of whose older lines predate it.

The product is the systems and the seams between them. The courtyard, the garden-keeper and the
rose key are the *proof that a system works*, and they are deletable. **No file under `src/` or
`tests/` may name demo content** — an area id, an item id, a conversation id, any of it. That is
not a convention: `tools/check_boundary.gd` fails the build — and since T5.4 it also fails a CSV
row translating content that is not there, and `check_layers.gd` fails a dependency pointing the
wrong way. One directory is exempt from both,
`src/systems/debug/`, and the exemption is justified in each tool's header. A test builds the
content it needs from `tests/framework/fixtures.gd`, and the suite passes with the demo deleted.
**[`docs/NEW_GAME.md`](docs/NEW_GAME.md)** is the strip-and-start checklist.

**THIS IS THE COMBAT FORK.** Combat is in scope here, and only here
([ADR-0008](docs/decisions/ADR-0008-combat-is-in-scope.md)). Upstream, the non-combat base at the
`template` remote, keeps no combat as a rule, and its fixes arrive by `git merge template/main`.
**Combat code never goes upstream.** This repository's state, phases and board are in
**[`docs/COMBAT.md`](docs/COMBAT.md)**, and its log is `docs/COMBAT_DEVLOG.md`. Read those before
upstream's `CONTEXT.md`. Every rule below still applies.

**Art is deferred.** Do not generate or request art. Every system must work on the procedural
placeholders in `assets/placeholder/`, indefinitely. `tools/gen_placeholders.gd` regenerates them.

## The engine

**Linux and cloud sessions (the default since 2026-10-16):** run `bash tools/cloud_setup.sh`
first. It installs the build CI pins and runs `--import`; then `G=godot`. Cloud sessions need not:
the SessionStart hook in `.claude/hooks/session-start.sh` runs it and exports `G`. Also read
[`.claude/agent-notes.md`](.claude/agent-notes.md), what earlier sessions learned about working
here, including the `xvfb-run` command that runs the windowed capture rung in a cloud session.

On the old Windows machine it was always the **console** executable; the plain one detaches and
prints nothing.

```
/c/Rai/softwares/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
```

It is the **standard build, not .NET** — C# is not available. Regenerate the offline API
reference with `--headless --doctool <dir>` and check property names there rather than from
memory; 4.7 is newer than most training data. Module classes (`GridMap`, `CSGBox3D`,
`FastNoiseLite`) live in `modules/*/doc_classes`, not `doc/classes`.

## Non-negotiables

1. **Nothing is done until the engine has run it.** Every completion claim cites a command and
   its result. This project exists because the previous one had 409 passing static checks and
   had never rendered a frame.
2. **Static typing is mandatory** — warnings are errors, so untyped code will not parse. Read
   untyped data through `DictRead`, never `int(value)` on a `Variant`.
3. **No player-facing string literals.** Localization keys from the first line.
4. **Respect the `MUST NOT` line** in every file header. When a change needs it broken, add a
   system instead of widening the boundary.
5. **Run all seven checkers before finishing** — `tools/check_budgets.gd`, `check_content.gd`,
   `check_boundary.gd`, `check_strings.gd`, `check_layers.gd`, `check_signals.gd`,
   `check_methods.gd`. Each must exit 0. The last three ask the question the first four never
   did: **does a declared thing have a consumer?** That is why the same defect arrived green
   eight times. `check_methods.gd` is the newest and the one you will meet: a public method
   nothing calls fails the build, and the exemption is the phrase `NO CALLER` in its own `##`
   block, with a reason beside it.
6. **Append to `docs/DEVLOG.md`** every session: did, why, connects, verified, unblocks, gaps.
7. **Indentation is tabs.** Author with spaces, then `unexpand -t 4 --first-only`.

## Verification, in order

**On a fresh clone, run `--headless --import` FIRST.** `class_name` globals live in the
gitignored `.godot/` cache; without it every script referencing `GameEnums` or `DictRead`
fails to parse and the autoloads never load.

**And after any `git checkout` that touches an asset, run it again.** That cache holds
IMPORTED ASSETS as well as `class_name` globals, and it is gitignored — so a branch switch
leaves the other branch's texture imported and rung 4 fails on a mismatch that exists in
neither branch. Gotcha 53: a rung-4 failure straight after a checkout is a cache question
before it is a code question.

```bash
G=/c/Rai/softwares/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
"$G" --headless --check-only --script <file>   # type gate; filter "Identifier not found: <Autoload>"
"$G" --headless --import                       # scenes and resources
"$G" --headless --quit-after 30                # must end "0 warnings, 0 errors"
"$G" --headless res://tests/test_runner.tscn --quit-after 400   # 2,681 assertions, exit 1 on fail
"$G" --headless --script tools/check_budgets.gd
"$G" --headless --script tools/check_content.gd    # ids, duplicate object_ids, CSV keys
"$G" --headless --script tools/check_boundary.gd   # no file under src/ or tests/ names demo content
"$G" --headless --script tools/check_strings.gd    # no player-facing literal; every *_KEY exists
"$G" --headless --script tools/check_layers.gd     # core -> content -> systems -> gameplay -> ui
"$G" --headless --script tools/check_signals.gd    # every declared signal has an emitter
"$G" --headless --script tools/check_methods.gd    # every public method under src/ has a caller
"$G" --resolution 960x540 --quit-after 90 -- --new-game --shot=<path> --shot-frame=70 --time=18:40 --freeze-time # saves go to user://dev_saves
```

**Gotchas that will cost you an hour each:**
- Autoload identifiers (`Log`, `Events`, …) do **not** resolve under `--check-only`. That
  error is expected; rungs 2 and 3 are the real compile check.
- `--headless` uses a dummy rasteriser and shades **nothing**. Visual claims require the
  windowed capture. A day/night system once ran, logged correct times, reported no errors, and
  lit nothing at all — because an `@export` reference was unwired.
- Anything `.new()`d and not freed spews `RID allocations were leaked at exit`.

## Where things go

`src/` is layered and dependencies point **downward only**:
`core` → `content` → `systems` → `gameplay` → `ui`. `core` knows nothing about the game, and
`content` is data shapes only, so anything may read it.

Ten autoloads, each owning one concern: `Log`, `Events`, `Actions`, `Settings`, `SaveSystem`,
`Flags`, `Clock`, `Weather`, `Audio`, `Director`. **Adding one requires an ADR.** There is no
`GameManager` and never will be.

`src/core/events/events.gd` declares every cross-system signal and is the connection map —
read it first to understand how anything is wired.

## One package per chat

A chat context window is the binding constraint on this project, so work is sliced into
packages that each fit in one. **[`docs/WORK_PACKAGES.md`](docs/WORK_PACKAGES.md) is the board.**

**Opening a chat:** read this file and `docs/CONTEXT.md`, then find your package and read **its
file manifest and nothing else**. Do not read the whole `src/` tree, the audit reports, or other
packages files.

**Closing a chat:** the package is not done until the full ladder is green, new behaviour has
assertions, `SYSTEMS_INVENTORY.md` / `ROADMAP.md` / `DEVLOG.md` / `CONTEXT.md` are updated, the
board marks it done, it is committed, pushed AND MERGED, and only then is the chip for the next
package created, so the handoff is automatic. The full checklist is in the board.

**One package at a time.** Never two chats, two worktrees or two open package PRs at once: the
next chat starts from `origin/main` after this one's PR is merged, and a defect found on the way
becomes a board row, not a chip. Phase T6 ran five in parallel and paid for it in renumbered
rows, repeated merges of `main`, and one package (T6.13) that existed only to stop two worktrees
wiping each other's saves. The rule and its reasons are at the top of the board.

No package exceeds about 8 files or 500 new code lines. Over that, split it and add a row -
same reasoning as the file budgets: a package that outgrows one chat gets half-finished.

## Read next — which document answers which question

| You want to | Read |
|---|---|
| know what to work on now | [`docs/WORK_PACKAGES.md`](docs/WORK_PACKAGES.md) — the board |
| know where things stand | [`docs/CONTEXT.md`](docs/CONTEXT.md) — state, settled decisions, eighty-three gotchas |
| understand why this is a template and not a game | [`docs/TEMPLATE.md`](docs/TEMPLATE.md) |
| **add an area, an NPC, a conversation, an item, an object, a quest, equipment, a place on the world map** | **[`docs/AUTHORING.md`](docs/AUTHORING.md)** |
| **make art that drops into this** | **[`docs/ART_CONTRACT.md`](docs/ART_CONTRACT.md)** |
| **add assertions to the suite** | **[`docs/TESTING.md`](docs/TESTING.md)** |
| know what may be subclassed and what is internal | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — § The extension surface |
| start a new game on this base | [`docs/NEW_GAME.md`](docs/NEW_GAME.md) |
| **receive a later fix to the base in a game already forked from it** | **[`docs/UPGRADING.md`](docs/UPGRADING.md)** — performed against a real fork, not written from intent |
| know what a version bump will do to your game | [`docs/CHANGELOG.md`](docs/CHANGELOG.md) — one entry per version, each ending in what a consuming game must do |
| know how a system is built | the file header. `src/core/events/events.gd` is the connection map |

Also: `docs/SYSTEMS_INVENTORY.md` · `docs/ROADMAP.md` · `docs/DEVLOG.md` · `docs/CONVENTIONS.md` ·
`docs/decisions/`
