# Adding assertions to a template you did not write

Rung 4 of the ladder is a headless test suite with the real autoloads live. It is not a
conventional Godot test setup, and five of its rules will cost you an hour each if you meet them
by discovering them. They are all here.

```bash
G=/c/Rai/softwares/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
"$G" --headless res://tests/test_runner.tscn --quit-after 400
```

Exit 0 if every assertion passes, 1 otherwise. In a full checkout the last line reads
`=== 2678 passed, 0 failed, 0 skipped ===`; in a stripped template it reads
`=== 2601 passed, 0 failed, 25 skipped ===`, and the difference is entirely skips that say so.
**Re-measure this rather than quoting it** — the number moves with every package, and
`docs_test.gd` and `doc_counts_test.gd` compute their plans from the documents, so editing a
document can move it too.

**And that warning was not enough, which is worth one line here because this file is where you
would look.** Those two numbers sat at `2302` / `2226` through T5.31 and T5.32 and were wrong by
the time you could read them — the close-out checklist named `CLAUDE.md` and `ARCHITECTURE.md` for
the suite size and not this file, so two consecutive rows updated those two and left these. The
stale pair even disagreed with the rest of the repository: their difference was 76 while the board
recorded a stripped gap of 74 for eight straight runs. T5.33 fixed both numbers and added this file
to the checklist. Re-measuring is still the instruction; a hedge in prose is not a gate.

---

## The five things that are not obvious

### 1. The suite is a SCENE, entered positionally. Never `--script`.

`res://tests/test_runner.tscn`, given as a positional argument. Under
`--headless --script foo.gd` the autoload *nodes* are created but the autoload *identifiers*
(`Log`, `Flags`, `Events`) fail to compile — `Compile Error: Identifier not found: Log`. So no
test that touches a system can be a `--script` tool, and the same is true of
`--headless --check-only --script` on any file mentioning an autoload: that error is expected
there and means nothing.

### 2. `TestCase.run()` is SYNCHRONOUS. No assertion can await a frame or press a key.

The runner calls `run()`; it does not await it. So nothing in a test can wait for a physics step,
a threaded load, a tween, or an input event — an `InputEvent` pushed inside `run()` never reaches
the frame that would deliver it.

What the suite does instead:

- **Drive the seam directly.** Interactions go through `attempt()`, a climb through
  `climb_step(delta)` in a bounded loop. If a system only works via `_physics_process`, the thing
  to assert is the pure function underneath it.
- **Extract the pure part.** The wetness dry-out is a plain `RefCounted` with no node in it
  precisely so its behaviour over time is assertable rather than photographable.
- **For a real frame, a temporary probe.** Add one to `src/systems/debug/` — `dev_capture.gd` is
  where they go — run it windowed with real `InputEventAction`s, read the log, quote it in
  `DEVLOG.md`, and then **remove it**. This is the approved substitute and it has a worked example
  in `DEVLOG.md` for every package that needed one. `git diff src/systems/debug/` must be empty
  when you are done.

Multi-frame scenarios that recur — twenty area round trips, a whole NPC day — live as *runs* in
`dev_probes.gd`, not as assertions.

### 3. Every case declares a `plan(n)`, maintained by hand.

The first statement of `run()`:

```gdscript
func run() -> void:
    plan(14)
    _the_first_block()
    _the_second_block()
```

Add an assertion, bump the number. A stale plan fails loudly with both numbers and the case name,
so it is self-correcting friction rather than a trap.

**Why bookkeeping nobody likes, and why nothing cheaper works.** A GDScript runtime error aborts
**only the innermost frame** — probed: a null dereference three frames deep printed its
`SCRIPT ERROR`, and both the calling function and `_ready()` above it ran to completion. So the
runner sees a case that returned normally, and a completion sentinel at the end of `run()` cannot
work either, because it is reached. Nothing the runner can inspect afterwards differs, **except
that the assertions after the crash never ran.** A count is the only thing that sees that, and the
same line catches three more silent passes: an early `return`, a block commented out, and a case
that asserts nothing at all. This is TAP's `1..N`, for TAP's reason.

A crashing case exited 0 for the life of this project before the plan existed. That invalidated
every green result it had.

**A plan may be computed, and should be when the count depends on content.**
`transitions_test.gd` declares
`plan(FIXED_ASSERTIONS + (SKIPS_WITHOUT_AREAS if _areas.is_empty() else with_areas))`, so
authoring an area does not mean editing a number, and a checkout with no areas at all still
declares a figure it can meet. Compute it from something you gathered *before* the assertions
run.

**A skip counts as the outcomes it stands in for**, so the plan is the same number with or without
demo content in the checkout.

### 4. The plan is not enough on its own — and the second mechanism is why.

A crash in a *leaf helper with nothing asserted after it* meets its plan exactly and reports a
clean pass. Measured, with the plan already in place: a planted `nothing.get_child_count()`
produced `2/2` and exit 0.

`tests/framework/error_watch.gd` is the only thing in the engine that sees it — an `OS.add_logger`
`Logger` counting `ERROR_TYPE_SCRIPT`, read per case so the failure names the case that crashed.
You do not have to do anything to get this; you have to know it exists, because **it fails a case
that raises an engine script error even if every assertion passed.** Only `ERROR_TYPE_SCRIPT`
fails; `push_error` arrives as `ERROR_TYPE_ERROR` and is counted and reported but not fatal, since
several cases assert refusals and bad input on purpose.

### 5. A case must be listed in the runner, or it never runs.

Add your file's path to `CASES` in `tests/test_runner.gd`. `_manifest_is_complete()` scans
`tests/unit/` and fails on a file that exists and is not listed — a suite file nobody listed is
never run and every rung stays green, which is the same failure shape as a file that does not
parse, one layer up.

**And the layer up is covered too, since T4.4 — but it was not, and this document is what found
it.** A case that IS listed and does not compile used to be skipped in silence: `load()` returns
a `GDScript` that is not null and cannot be instantiated, so `_run_case` walked into
`script.new()`, whose failure is a runtime error, and rule 3's own reasoning applies to the
runner as much as to a case — it aborts only that frame. The loop moved on, and the suite
reported `1608 passed, 0 failed` and **exit 0** with a whole case never run. Two guards close it
now: `can_instantiate()` before the call, naming the file, and a run-level check that any engine
script error nothing attributed to a named case fails the run. The second is the general one,
because the next hole in that wall will not be a parse error.

---

## Writing a case

```gdscript
extends TestCase
## What this file covers, and what it deliberately does not.
##
## OWNS: ...
## MUST NOT: ...

func run() -> void:
    plan(1)
    _a_named_block()


## One behaviour per function, named as the sentence it proves.
func _a_named_block() -> void:
    var bag := Inventory.new()
    equal("a new bag holds nothing", bag.distinct_count(), 0)
    bag.free()
```

**`TestCase` hands you five things and no content**: `plan`, `equal`, `skip`, `build` and
`attach`. There is no fixture member, no `inventory`, and no system pre-wired for you — a case
constructs or `build`s whatever it is asserting about, and frees it. An earlier version of the
example above read `inventory.count()`, which is wrong twice over: nothing declares `inventory`,
and `Inventory` has `distinct_count()`, `total_count()` and `count_of(id)` but no `count()`. It
was copied verbatim while performing this document and produced two parse errors.

- **`equal(label, actual, expected)` is the only assertion**, deliberately: a suite with eight
  helpers spends its time debating which to use. Floats go through
  `equal(label, is_equal_approx(a, b), true)`.
- **`skip(label, why, stands_for)`** where a block genuinely asserts something about *authored
  content* that a stripped template does not have. A skip is printed and counted; silence would
  let a stripped run look identical to a full one while covering a third less.
- **`build(scene_path)` then set exported properties then `attach(node)`**, in that order.
  `Interactable` forwards `object_id` to its `PersistentState` child in `_enter_tree`, which runs
  on `add_child` — anything set afterwards is too late and the object silently stops persisting. A
  one-step `spawn()` helper hid exactly that bug the first time the framework was written.
- **Free what you build.** Anything alive at exit prints a wall of leaked-RID errors, and that
  noise is how a real error gets lost.
- The case's own file is subject to `check_budgets` — 250 code lines, 40 per function. Split the
  file rather than raising a budget.

## A test builds its own content

**A test that names demo content is testing the demo.** `tools/check_boundary.gd` scans
`tests/unit/` and `tests/framework/` as well as `src/`, and it derives the forbidden names from
`scenes/areas/` and the ids in `data/`, so this is a gate, not a habit.

`tests/framework/fixtures.gd` is the seam, and its rule is one line: **in memory when a system is
HANDED content, on disk when a system LOOKS IT UP BY ID.**

| Your system | Fixture |
|---|---|
| receives an `ItemDefinition` / `PathAction` (a `Pickup`, a `PathActionPoint`) | build it in memory with `FixtureContent` and set it on the node. No files, no global state |
| looks content up by id (`Inventory.add(id)`, `DialogueRunner.begin(id)`, an `NpcBrain` reading a schedule, `QuestTracker` reading a quest, `WorldMap` reading an area def) | `Fixtures.activate()` — it writes `.tres` files under `Fixtures.root()`, this run's own scratch directory, and points all five registries' `content_dir` there |

The five registries scan a directory (ADR-0006) and cache statically, so an in-memory
`ItemDefinition` is **invisible** to `Inventory.add(id)`. A test-only injection method on each
registry was rejected: a backdoor in engine code that exists for the suite and nothing else is
worse than a temp folder, and going out through `ResourceSaver` and back through the real scan
proves the `.tres` authoring round trip as a side effect.

`user://` and not a folder under `res://`, because writing into `res://data/` would mutate the
content root `NEW_GAME.md` tells a game to delete, and a crashed run would leave stray files that
`check_content` then fails on.

The runner calls `Fixtures.deactivate()` after **every** case, including ones that never
activated — a case that crashed half way through its fixtures would otherwise hand the next one a
redirected content root and never say so.

**A case that writes, deletes or saves through ANY path calls `SaveFixture.activate()` first.**
That is `save_to_slot`, `delete_slot`, and anything that reaches them: a save screen row, an
`Autosave.request()`. It points `SaveSystem.save_dir` at `SaveFixture.root()`, emptied, and the
runner points it back after every case. **If you forget, the suite fails** (T6.12):
`<case> used the save store without SaveFixture.activate(): saved slot N in
user://test_runs/<pid>/saves_unclaimed`. Before every case the runner parks the store in that
second scratch directory, `SaveFixture.unclaimed()`, so the forgetful case never reaches the real
`user://saves`. It then fails any case that saved, or loaded a real file, while parked. Until
T6.9, fourteen cases saved without activating: a full run destroyed every real slot and the
autosave, and the suite stayed at 0 failed. **Two things the check does not hear:** a file you
write by hand and delete without ever loading it, and `has_slot`/`slot_info` reads. Parking still
keeps both away from real saves, but call `activate()` anyway: every case in the run parks in the
same directory, and your case should own its store.

**Settings need nothing from a case, and that is the difference.** Since T6.11 the runner points
`Settings.file_path` at `SaveFixture.settings_path()`, once, before the
first case, so any `Settings.set_value` or `reset_to_defaults()` writes there. Until then every
green run saved the developer's real `user://settings.cfg`, and `reset_to_defaults()` saved it as
zero bytes. It is not per case because five cases write settings, most on their first line, and a
per-case switch is exactly the one a new case forgets. **The file is still READ from the real
path at boot**, before the runner exists, which is why the runner also pins the locale. **Key
bindings are the same since T6.13:** the runner points `KeyBindings.file_path` at the run's own
copy, because `options_test` resets its bindings, and the reset deleted the real `input.cfg`.

**Everything a run writes is under its own directory, `RunScratch.root()`**, which is
`user://test_runs/<pid>`, since T6.13. Every worktree on a machine shares one `user://`, so a fixed
scratch name is one that a second suite, started a moment later in another worktree, empties
under you. If your case needs a scratch directory or file of its own, name it
`RunScratch.path("<name>")`, never `user://<name>`, and add it to the list in
`run_scratch_test.gd`, which asserts every listed path is inside the run's directory. The runner
removes the directory when the run ends; you do not have to clean up after a crash.

**`Fixtures.activate()` returns `false` if it could not write the fixture root**, so the shape is
`equal("the fixture content is on disk", Fixtures.activate(), true)` — **assert it, do not skip on
it.** An unchecked call leaves every lookup below it pointed at whatever content root the checkout
happens to have.

**This document used to say `if not Fixtures.activate(): skip(...); return`, and that was the
weaker of the two shapes shipped.** T5.28 settled it in favour of asserting, because a fixture root
that cannot be written turns a skipped case into a case that silently tests nothing — the same
"passes because it found nothing" failure T5.27 had just guarded the seven checkers against, and
`CHANGELOG.md` has called worse than no gate since `4.3.1`. A skip also reports GREEN, so the one
condition the check exists to catch would be the one condition nobody sees. Asserting fails loudly
and names the reason. **14 of 16 call sites discard the return entirely**; they are not a defect
this row fixes, and the honest state is recorded rather than implied.

**The ids themselves are consts in `tests/framework/fixture_content.gd`, and a case names them
from there** — `FixtureContent.STACK_ITEM`, `FixtureContent.QUEST`, `FixtureContent.PLACE_A`.
Never retype the string: the consts are the list, and they are what keeps a case out of
`check_boundary`'s way.

Everything in `FixtureContent` is abstract on purpose: `item/fixture_unique`, `fixture_post_a`.
If a name in there ever describes a place, that is the demo growing back.

### Asserting something about content that may not exist

`Fixtures.has_demo_content()` answers whether this checkout still has a game in it, and
`Fixtures.area_ids()` **discovers** the areas rather than listing them — so a contract holds for
area three the day it appears, and for none at all in a stripped template. That is the shape to
copy: scan, then either assert per item found or `skip` with the count.

---

## Proving a gate

**A gate that never fails has never been tested.** Every checker and every regression assertion
added since T1.2 is proved by planting the violation it exists to catch, watching it exit 1,
removing it, watching it exit 0 — with both outputs quoted in `DEVLOG.md`. It costs two minutes
and it is the only thing separating a gate from a reassuring printout.

Plant the *real* failure, not a convenient one: the assertion that fails when you break the
assertion is not evidence.

**Assert the CLASSIFIER, not the tree.** A plant is a one-off; what rots afterwards is the four
or five lines inside the tool that decide whether a reference is an emit or a connect, whether a
path is core or ui, whether a line is a declaration. Those are static, pure and take strings, so
they belong in `tests/unit/gates_test.gd` where they run forever. **Never assert a violation
COUNT** — that is a property of today's tree, not a contract.

**And expect the gate to fail on its own test.** A text gate scans `tests/` too, so a case that
quotes the pattern it exists to catch is a violation of it — `check_methods.gd` went red on
`gates_test.gd` the first time that file wrote out an opaque dispatch sample. The gate was right.
Split the sample so no single line is the thing, and say in the file why it is split; exempting
the test is how a gate stops meaning anything. That is gotcha 69.

### The seven checkers, and what each refuses

| Rung | Tool | Refuses |
|---|---|---|
| 5 | `check_budgets.gd` | a file over its line budget, a function over 40 |
| 6 | `check_content.gd` | a bad id, a duplicate `object_id`, a missing CSV key |
| 7 | `check_boundary.gd` | a file under `src/` or `tests/` naming demo content |
| 8 | `check_strings.gd` | a player-facing literal, a `*_KEY` with no row |
| 9 | `check_layers.gd` | an upward reference across `core -> content -> systems -> gameplay -> ui` |
| 10 | `check_signals.gd` | a signal in the registry that nothing emits — exemption `NO EMITTER` |
| 11 | `check_methods.gd` | a public method under `src/` whose name appears nowhere else — exemption `NO CALLER` |

The last three ask one question the first four never did: **does a declared thing have a
consumer?** Both exemption phrases live in the declaration's own `##` block rather than in a list
inside the tool, and **a stale exemption fails too**, because that is how a gate rots into
decoration.

## What the suite cannot see

Stated so nobody reads a green run as more than it is:

- **Anything visual.** `--headless` uses a dummy rasteriser and shades nothing. Lighting, sprite
  cells, legibility — windowed capture, and look at the PNG.
- **Anything needing a frame.** See rule 2.
- **An exported build.** A test running under `res://` cannot test a build it is not running in;
  `export_test.gd` asserts `is_exported() == false` rather than leaving that blindness implied.
  The export proof is a run of the executable with both sides' numbers quoted.
- **`0 warnings, 0 errors` from the boot rung is not a compile check.** It counts the game's own
  `Log` calls. Grep `--headless --import` for `SCRIPT ERROR` and `Parse Error` instead.

## Read next

[`AUTHORING.md`](AUTHORING.md) · [`ARCHITECTURE.md`](ARCHITECTURE.md#the-extension-surface) ·
[`CONTEXT.md`](CONTEXT.md) — the eighty-three gotchas, several of which are the long form of the rules
above · `tests/framework/test_case.gd` and `tests/test_runner.gd`, whose headers carry the
reasoning in full.
