# Development Log

Append-only. Newest entry at the top. One entry per working session.

**Entry template**

```
## YYYY-MM-DD — Title
**Did:**       what changed, concretely
**Why:**       the reason, so a future reader does not undo it
**Connects:**  how the new pieces wire into what already existed
**Verified:**  the exact command run, and its result. No claim without one
**Unblocks:**  what is now possible that was not before
**Known gaps:** what is deliberately still missing
```

---

## 2026-08-31 — T3.3 · A count is a flag, published downward

**Did:** made `condition_flag = &"bag/player/item/rose_petal"`, `condition_test = 4`,
`condition_value = 3` an authorable quest step, and touched **no file in `src/content/quest/` or
`src/systems/quest/` to add the capability**. `Inventory` gained a `carrier_id` and a `_publish()`
that mirrors every count into `Flags` as `bag/<carrier_id>/<item id>`; `Flags` gained
`declare_derived(prefix)` / `is_derived(flag)` and skips those keys in `_collect_save`;
`src/core/state/bag_keys.gd` (new, 28 code lines) is the one place that shape is built and parsed;
`FlagQuery.progress()` answers `(have, need)`; `QuestTracker.step_progress()` passes it through so
`JournalScreen` can draw `— Gather three rose petals.   2 / 3` from `ui.journal.progress` without
reading a flag; and `tools/check_content.gd` now VALIDATES bag-keyed step conditions. Demo: one
third step on `keepers_errand`, one more petal in the courtyard chest, 3 CSV rows. Fixed a latent
defect the design could not tolerate — a new game did not empty the bag.

**Why:** WP-09 costed both candidate designs and closed neither. The second — a `systems` tracker
reading a `gameplay` inventory — is not a design, it is the layer rule being broken, and WP-08 had
already refused exactly that over a `reward_item` field. So the choice was the first (mirror the
counts into `Flags`) or nothing, and the whole question was whether its stated cost — the same
number saved twice, by two participants, in two formats — is real. **It is not, and `flags.gd`'s
own header is why:** *"anything recomputable... if it can be derived, derive it."* A count mirrored
from the bag is recomputable by definition. Declared derived, it is readable, announced on
`flag_changed` and visible to `FlagQuery`, and absent from the save file — so
`Inventory.SAVE_VERSION` did not move, `Flags`'s format did not change, and there is no migration.

The inversion is the package. A tracker reading a bag points UP; a bag publishing a flag points
DOWN. Same capability, and the quest system never learns what an inventory is — sixth
namespace-over-`Flags` after `PersistentState`, `Standing`, `Equipment`, `WorldMap` and
`Attributes`, and the first whose value is a NUMBER rather than a truth.

`BagKeys` is its own file for a compile reason rather than a tidiness one. `Equipment.PREFIX` lives
on `Equipment`, and that could not work here: `check_content` runs under `--headless --script` where
autoload identifiers do not resolve, so naming `Inventory.PREFIX` would not COMPILE. The parser
earns its keep on one line — **an item id contains a slash**, so the carrier is the first segment
after the prefix and the item id is everything left; splitting on the last slash answers
`rose_petal`, which `ItemDb` would then fail to find, and a validator that fails on valid content is
worse than none.

**Connects:** nothing that writes a count had to change. A `Pickup`, an `ItemContainer`, `--give=`
and a restored save all go through `Inventory.add`, so all four advance a counted step already —
WP-08's seam used a third time after `Equipment`. `JournalScreen` keeps its MUST NOT ("read a
flag"): non-negotiable #4 says add a system rather than widen a boundary, so the question is asked
where the comparison table already lives and the tracker passes the answer along.

**THE UNCOMPLETE DECISION, STATED OUT LOUD — and no new decision was needed.** A step reopens when
a count falls; a completed quest does not. That is WP-08's asymmetry, and `quest_tracker.gd`'s own
header names *this exact case*: *"A step may test AT_LEAST 3 on a counter; if something later
decrements it, a finished quest would reopen."* What this package contributes is the first real test
of it — against a bag that actually decrements, rather than a flag written by hand. Two adjacent
behaviours also asserted: a count already satisfied when the quest starts passes its step at once (a
step is never "reached"), and a fourth petal does not un-finish a step needing three, because the
test is `AT_LEAST` and not `EQUALS`.

**Verified:**

```
$ "$G" --headless --import 2>&1 | grep -Ei 'SCRIPT ERROR|Parse Error'
(no output)
$ "$G" --headless --quit-after 120
15:02:43 [INFO ] [boot     ] Session ended after 1.4s — 0 warnings, 0 errors
$ "$G" --headless res://tests/test_runner.tscn --quit-after 400
15:04:02 [INFO ] [test     ] === 1468 passed, 0 failed, 0 skipped ===          exit 0
$ "$G" --headless --script tools/check_budgets.gd
127 files, 10869 code lines, 0 warnings, 0 violations                          PASS
$ "$G" --headless --script tools/check_content.gd
  quests: 1
     quest/keepers_errand   3 steps, starts on met/gardener is_true
        unlock              done when area/courtyard/gate_unlocked is_true
        dais                done when area/courtyard/dais_entered is_true
        petals              done when bag/player/item/rose_petal at_least 3
                                                                               PASS
$ "$G" --headless --script tools/check_boundary.gd
  demo names derived: 16 — [... "item/rose_petal", "rose_petal", "quest/keepers_errand" ...]
  engine scripts scanned: 121                                                  PASS
```

**STRIPPED TEMPLATE, run locally** — `data/` and `scenes/areas/` moved aside, which is step one of
`docs/NEW_GAME.md`: **`1400 passed, 0 failed, 19 skipped`**, exit 0 (was 1334/19), with
`item definitions: 0`, `quests: 0`, `demo names derived: 0` and both checkers exit 0. **The skip
count did not move**, which is the claim worth making: all 66 new assertions are fixtures all the
way down and every one of them runs in a checkout with no game in it. A new skip would have had to
be named and counted.

**THE NEW GATE PROVED RED, THEN GREEN — all three branches, each the real failure shape**
(gotcha 23). Planted in `data/quests/keepers_errand.tres`, one at a time, reverted after each:

```
$ perl -pi -e 's{item/rose_petal}{item/rose_petals}' data/quests/keepers_errand.tres
        petals              done when bag/player/item/rose_petals at_least 3
  !! quest/keepers_errand/petals counts 'item/rose_petals', which no item .tres declares
FAIL — 1 content violation(s)                                                  exit 1
$ (reverted)                                                                   exit 0

$ perl -pi -e 's{^condition_value = 3$}{condition_value = 0}' ...
  !! quest/keepers_errand/petals asks for 0 of 'item/rose_petal'; a count below one is
     always satisfied
FAIL — 1 content violation(s)                                                  exit 1

$ perl -pi -e 's{^condition_test = 4$}{condition_test = 1}' ...
  !! quest/keepers_errand/petals tests an item count with is_true, which is not a count
FAIL — 1 content violation(s)                                                  exit 1
$ (reverted)                                                                   exit 0
```

Validating THIS namespace is not a contradiction of WP-08's "print the flags, do not judge them".
`bag/<carrier>/<item id>` differs in the one way that matters: it has exactly **one writer**, and
half the key is an item id the tool can look up. The carrier is deliberately NOT validated — a
`carrier_id` is an `@export` on a node in a scene this tool does not open, and a game may put a bag
on an NPC or a stash. Same line `_all_waypoint_names` draws.

**AND THE SUITE'S OWN EXIT 1, ON THE INVARIANT RATHER THAN ON A BROKEN ASSERTION.** The
load-bearing invariant is that every path which moves a count republishes, so `_publish()` was
deleted from `remove()` — the way it would really be lost:

```
=== 1460 passed, 9 failed, 0 skipped ===                                       exit 1
FAILED: spending two republishes one — expected 1, got 3
FAILED: item_count_test raised 1 engine script error(s): ["Invalid access to property or key
  'step_id' on a base object of type 'Nil'. at res://tests/unit/item_count_test.gd:185"]
```

The second line is `error_watch.gd` catching the downstream consequence: a quest wrongly completed,
so `current_step` answered null. Restored: `1468 passed, 0 failed`, exit 0.

**ONE LATENT DEFECT, FOUND BECAUSE THE DESIGN COULD NOT TOLERATE IT.** `Director.start_new_game()`
clears the flags, resets the playtime and emits `game_started`; nothing was listening on behalf of
`Inventory`, so **the previous run's items carried into a fresh game.** Unreachable in practice (the
boot goes to the main menu with an empty bag) and invisible to every gate, because nothing asserted
it. It surfaced only here, because the flags are cleared and `_counts` is not, so the mirror and the
truth disagree from the first frame of a new game. `Inventory` now clears on `game_started` and
republishes on `game_loaded` — the second because `Flags._apply_save` wipes the store and the
derived keys are deliberately not in the file it restores from, so **the answer must not depend on
save-participant order**, and `game_loaded` fires once after every section is applied.

**And that made `--give=` need the area wait — gotcha 32 for the FOURTH time** after `--open-menu`,
`--flag` and `--open-inventory`: items staged during argument parsing are now thrown away by the new
game a frame later. Given that wait, `--give` and `--equip` would leave `_wait_for_area` on the same
frame and be ordered by chance (gotcha 35), so `--equip` waits one frame more — an ordering rather
than a race, and **verified both ways round on the command line**:

```
### give BEFORE equip on the line
[test] --give item/brass_lantern x1: true
[test] --equip item/brass_lantern: true (flag equip/player/item/brass_lantern)
### equip BEFORE give on the line
[test] --give item/brass_lantern x1: true
[test] --equip item/brass_lantern: true (flag equip/player/item/brass_lantern)
```

**TWO WINDOWED CAPTURES, LOOKED AT AND READ rather than glanced at** (gotcha 28). Both
`--new-game --open-menu=journal --shot-frame=110 --quit-after 130 --time=12:00 --freeze-time`, so
they differ by exactly one petal:

- `--give=item/rose_petal:2` → `Journal / Underway / The Keeper's Errand / — Gather three rose
  petals.   2 / 3`, the *New errand* toast up, `Day 1 | 12:00 | Midday` in the HUD, the courtyard
  visible and stopped behind the dim panel. The tally is a **checkable prediction**, not a
  screenshot that merely looks fine: two given, three required.
- `--give=item/rose_petal:3` → same camera, same hour: `Settled / The Keeper's Errand / — Nothing
  left to do.`

The staging log is the other half of the reading, because it shows the objective walking forward
through steps the demo already had:

```
[test ] --new-game requested 'courtyard'
[test ] --give item/rose_petal x2: true
[quest] quest/keepers_errand: started [&"quest/keepers_errand"]
[quest] quest/keepers_errand: advanced [&"quest/keepers_errand", &"unlock"]
[quest] quest/keepers_errand: advanced [&"quest/keepers_errand", &"dais"]
[quest] quest/keepers_errand: advanced [&"quest/keepers_errand", &"petals"]
[test ] --open-menu journal pushed: true
[boot ] Session ended after 2.7s — 0 warnings, 0 errors
```

and with three petals the same run reads `quest/keepers_errand: completed`.

**NO TEMPORARY PROBE WAS NEEDED AND NONE WAS LEFT** (gotcha 15). This package touches no input path
and no audio path — `J` was proved by WP-08's probe and `ScreenKeys` was not touched.
`git diff src/systems/debug/` carries only the `--give` wait, the `--equip` frame gap and their
header lines.

**A REGRESSION GATE ON THE LAYER RULE, and it is the most important block in the new case.** The
exit criterion was that a count must work WITHOUT the quest system knowing what an inventory is, and
nothing else in the suite could fail if that stopped being true — the behaviour would be identical
and the layer rule would be gone. So `item_count_test.gd` text-scans `quest_tracker.gd` and
`quest_step.gd` for `Inventory`, `ItemDb.` and `BagKeys`, `journal_screen.gd` for `Flags.`, and
asserts that exactly ONE file under `src/` builds a bag key. **The first version of that block was
wrong in an instructive way:** a raw scan failed on both files, because both HEADERS explain at
length why an `Inventory` is not reachable from them — the gate fired on the paragraph documenting
the rule it enforces. `check_boundary` had already drawn this line: **comments are exempt, code is
not.** The block strips comment lines first.

**Unblocks:** "bring me N of these" for any game built on this base, with no code — and the same
shape whenever a lower layer holds something an upper one must observe: publish downward into a
declared derived prefix rather than reaching upward. A gathering quest, a delivery quest, a
"collect the five seals" chapter gate and a `DialogueChoice` conditioned on carrying enough of
something are all authorable today, none of them touching `src/`.

**Known gaps:**
- **A step still cannot TAKE the items.** A completed quest emits `quest_completed` and stops —
  WP-08's layer reason holds unchanged. A game listens, or puts an `ItemContainer` in front of the
  NPC.
- **`AT_MOST` draws no tally**, on purpose: it is a ceiling, and "2 / 3" under *keep it below three*
  tells the player to gather more of the one thing they must not. `EQUALS` counts; nothing authored
  uses it.
- **The carrier is not validated by any gate**, stated in `check_content`'s own comment.
- No sixth catalogue: a count needs no resource, no registry and no save section, which is
  `Attributes`' argument used a second time.
- No objective marker on the map, no quest-item marker in the satchel, no count in a tooltip.
- Branching quests, a failure state, timed quests, item instances and a journal detail pane are all
  still deferred, unchanged.
- Combat is still not a thing, and a count of arrows would not change that.

**CI green, run 33529911105, job logs read rather than the tick** (gotcha 26 — the tick is not the
evidence). Full checkout **1468 passed, 0 failed, 0 skipped**, `item definitions: 4`, `quests: 1`.
Stripped template **1400 passed, 0 failed, 19 skipped**, `item definitions: 0`, `quests: 0`. All
three checkers PASS in both jobs, and **the skip count is the same 19 the previous run reported** —
a new skip would have had to be named and counted, and there is none, because the counted step is
proved against a fixture quest and a fixture item that a stripped checkout still writes to
`user://`. The push run (33529829466) and the pull-request run (33529893285) are green as well.

**Commit `292dd44` on `claude/t3-3-item-count`, PR #21**, stacked onto `claude/t3-1-registry` (#20)
rather than `main`, matching the rest of the chain.

---

## 2026-08-30 — T3.1 · One scan, five typed façades

**Did.** Collapsed five copies of the same scan-and-validate into one function, on
`claude/t3-1-registry` branched from `claude/wp-09b-attributes`. Two new engine files:
`src/content/content_entry.gd` (5 code lines) is the base every catalogued `.tres` now extends —
an `@export var id` and a `problems()`, and nothing else; `src/content/content_scan.gd` (39) holds
`into()`, which walks a content root, loads each `.tres`, checks it is the right class, checks its
`id` against its file name, refuses a duplicate, appends the resource's own `problems()` and puts
it in **the caller's dictionary**, plus `resource_paths()` and `_normalise()` moved verbatim from
`ItemDb`. The five registries lost `_register()` entirely and are now typed façades: content root,
typed cache, typed accessor, and a two-line `_ensure_loaded()`. `ItemDefinition`, `Conversation`,
`NpcSchedule`, `Quest` and `AreaDef` each changed one line — `extends Resource` to
`extends ContentEntry` — and dropped their own `@export var id`. `ItemDb.resource_paths()` became
`ContentScan.resource_paths()` at nine call sites with no alias left behind. New case
`tests/unit/content_scan_test.gd` (153 code lines, 47 assertions), listed in `CASES`.

**Why.** WP-08 reconsidered this refactor at the fourth copy and **kept** the copy, on reasoning
that has not been overturned: GDScript has no generics, so a base holding the CACHE could only
store `Resource` and hand it back untyped, and every accessor would become a cast at the call site
— against non-negotiable #2. WP-11 made it the fifth copy and changed only the arithmetic. Both
were right about the wrong half. **The duplication was never in the cache.** A scan needs exactly
two things from a resource — its `id` and its `problems()` — so the base belongs on the
**resource**, and the shared part is a **function** that fills a dictionary the caller owns and
types. `ItemDb._by_id` is still `Dictionary[StringName, ItemDefinition]`, `ItemDb.definition()`
still returns `ItemDefinition`, and grep finds no new cast anywhere. Measured, in code lines as
`check_budgets` counts them: five registries **290 → 187**, plus 44 shared, so **290 against 231**.
The −59 is the least interesting number; what matters is that `_register()` was 17 lines
duplicated five ways, and a bug in the id check, the duplicate check, the type check or the
`.remap` handling is now one fix.

`ContentEntry` is not tidiness. `project.godot` sets `unsafe_property_access` and
`unsafe_method_access` to **error**, so a shared scan reading `resource.id` or calling
`resource.problems()` through a `Resource` does not compile at all. The base is what makes the
shared scan legal, and its `MUST NOT` says a field belongs there only when the SCAN uses it.

**Connects.** Nothing above `src/content/` changed. `Inventory`, `DialogueRunner`, `NpcBrain`,
`QuestTracker`, `WorldMap`, `Speaker` and `check_content.gd` all call the same accessors on the
same class names and got the same answers. `tests/framework/fixtures.gd` — the seam every case
depends on — still redirects five separate `content_dir` variables and still calls five separate
`rescan()`s, because that is the only shape that works (see the gotcha below). The
`.tres` format is untouched: the demo's files declare `id` exactly as before, now satisfying the
base's export instead of the subclass's, and `check_content` loads all of them unchanged.

**Verified.**

```
G=/c/Rai/softwares/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
"$G" --headless --import                        # zero SCRIPT ERROR / Parse Error
"$G" --headless --quit-after 120                # Session ended after 1.2s — 0 warnings, 0 errors
"$G" --headless res://tests/test_runner.tscn --quit-after 400
                                                # === 1402 passed, 0 failed, 0 skipped ===
"$G" --headless --script tools/check_budgets.gd # 125 files, 10506 code lines, 0 warnings, 0 violations — PASS
"$G" --headless --script tools/check_content.gd # PASS
"$G" --headless --script tools/check_boundary.gd# PASS, 119 engine scripts scanned
```

1355 → 1402, +47, none lost.

**The stripped template, run locally, because it is the load-bearing rung for this package.**
`data/` and `scenes/areas/` moved aside, `--import`, then the suite: **`1334 passed, 0 failed, 19
skipped`** against 1287/19 before — +47, the same 19 skips, so every new assertion runs with no
authored content on disk. `check_content` exit 0 and `check_boundary` exit 0 on the stripped
checkout, which is the thing that proves **an empty content root is still not an error**. Both
directories restored and the full run re-confirmed at 1402.

**The gates were proved failing (gotcha 23).** Two real violations planted in `data/items/` —
`planted_mismatch.tres`, a copy of a real definition carrying `id = &"item/mismatched"`, and
`planted_broken.tres`, one line of prose:

```
  !! res://data/items/planted_broken.tres is not an ItemDefinition
  !! res://data/items/planted_mismatch.tres declares id 'item/mismatched' but its file name requires 'item/planted_mismatch'
FAIL — 2 content violation(s)
check_content exit code = 1
```

Both removed:

```
PASS
check_content exit code = 0
```

The suite's own exit 1 needed no planting: the first run of the new case failed for real (below),
`=== 1401 passed, 1 failed, 0 skipped ===`, and the runner exited 1.

**NEW GOTCHA 37, and it decided the whole design.** The obvious refactor is
`ItemDb extends ContentDb` with `_by_id`, `_loaded` and `content_dir` as `static var`s on the base.
Probed under 4.7.2 with two throwaway subclasses bumping a base counter:

```
A.shared=3 B.shared=3 Base.shared=3
```

**A base-class `static var` is ONE storage shared by every subclass.** Five registries inheriting
it would have shared one cache and one `content_dir`, so `Fixtures.activate()` would have pointed
all five at a single folder and four catalogues would have come back empty — with every accessor
still typed and the class diagram still looking right. That is why the shared part is a function
and each façade keeps its own three statics. The same probe confirmed the three other facts the
design rests on: `is_instance_of(res, ItemDefinition)` discriminates correctly with a `class_name`
passed as a `Script`; `Script.get_global_name()` returns `ItemDefinition`; and a
`Dictionary[StringName, ItemDefinition]` passed through an untyped `Dictionary` parameter keeps
its value type (`is_typed_value() == true`) and is filled by reference — which is the mechanism
that keeps every accessor typed. The probe scripts were deleted; `git diff` shows no
`tools/_probe/`.

**The one thing the new test got wrong first, and it is a suite-wide lesson.** The case writes a
sound `AreaDef`, scans, then writes a *different* `AreaDef` over the same path and scans again to
prove a resource's own `problems()` reach the caller. It reported `expected 1, got 0`:
**`ResourceLoader` caches by path**, so the second scan was handed the first resource. One failing
assertion was the only trace. The fix is a second id rather than a second write, and anything in
the suite that expects a re-authored file to be re-read needs a new path.

**What the 47 assertions are for.** A refactor's real assertions are the existing ones staying
green, and those did. The new ones exist for the failure mode a *shared* scan has and five copies
did not: it can go on working for four catalogues and quietly stop reporting a bad file for the
fifth. So `content_scan_test.gd` drives `into()` directly for every branch it has — empty root,
absent root, sound file, id mismatch naming both values, a resource of the wrong type, a
`.tres`/`.res` duplicate, an empty prefix (`AreaDb`'s shape, which no other registry exercises),
and a resource whose own `problems()` must propagate — and then plants the same violation in all
five fixture roots at once and names **each registry by hand**. It also asserts one bad file costs
the catalogue exactly that file, and that every `content_dir` goes back to its own constant after
`Fixtures.deactivate()`.

**A windowed capture, although there should have been nothing to see.**
`--resolution 960x540 --quit-after 90 -- --new-game --shot-frame=70 --time=12:00`: the courtyard at
midday with the player, the keeper, the sign, the pickup, the HUD clock and the
`Read Weathered Notice` prompt — indistinguishable from WP-09b's, which is the point. The boot
readout still names every catalogue and its resolved paths — `items: 4`, `dialogue: 1`,
`schedules: 1`, `quests: 1`, `areas: 2` — and the session ended `0 warnings, 0 errors`. **If a
screen had changed, the refactor had leaked.** No temporary probe was needed: this package touches
no input path and no audio path, and `src/systems/debug/` carries exactly one deliberate line, the
`resource_paths` rename in `catalogue_report.gd`.

**The acceptance test was `docs/AUTHORING.md`, and not one word of it changed.** It names `ItemDb`
once, describes the scan, the folders and the id-equals-filename rule, and every sentence in it is
still true. `docs/TESTING.md` needed one number.

**Unblocks.** A sixth catalogue is now a 36-line façade rather than a sixth copy of the scan — and
that cuts both ways, which `content_scan.gd`'s header says: WP-09b deliberately did *not* add one
for attributes, and cheapness is not a reason to. Any improvement to the scan — recursion into
subdirectories, a better duplicate diagnostic, a different `.remap` case — is now one edit that
five catalogues and both content gates inherit at once.

**Known gaps.** No sixth catalogue, no hot-reload or file-watcher on the content roots, no content
editor, no async or threaded scanning, no cache outliving a session, and no change to what a
`.tres` may contain — all deferred deliberately, because a consuming game must not be able to tell
this package happened. `ContentScan` does not recurse into subdirectories; neither did any of the
five copies, and nobody has asked. `ContentEntry` holds `id` and `problems()` and nothing else, on
purpose: `name_key` is on four of the five content types but not on `NpcSchedule`, and a field the
scan does not read has no business on the base. The five façades are still five files — the two
`content_dir` lines and the three-line `has()`/`count()`/`problems()` are duplicated by shape, and
they are not worth removing, because each of them names a type.

**Files: 20**, which exceeds the board's "about 8". Two new files, five registries rewritten, five
resource classes changed by one `extends` line, one new test case, and eleven single-identifier
renames the compiler would have caught. New code is negative. The rule's reasoning — a package
that outgrows one chat gets half-finished — was never in danger, and the count is said out loud
rather than quietly exceeded.


**CI green, run 33267916883, job logs read rather than the tick** (gotcha 26 — the run listing
lags and the tick is not the evidence). Full checkout: **`1402 passed, 0 failed, 0 skipped`**,
`125 files, 10506 code lines, 0 warnings, 0 violations`. **Stripped template — the load-bearing
job for this package, because it is the only rung that proves an empty content root is still not
an error: `1334 passed, 0 failed, 19 skipped`**, against `1287 passed, 0 failed, 19 skipped`
before. Same nineteen skips, forty-seven more assertions, and `check_content` and
`check_boundary` PASS on a checkout with `data/` and `scenes/areas/` deleted. All rungs green in
both jobs, and the workflow was not touched.

**Commit `767fbe3` on `claude/t3-1-registry`, PR #20**, stacked onto
`claude/wp-09b-attributes` (#19) rather than `main`, matching the rest of the chain.

---

## 2026-08-29 — WP-09b · Attributes, and the ground under your feet

**Did.** The two thirds of WP-09 that were split out for having no consumer, on
`claude/wp-09b-attributes` branched from `claude/wp-11-worldmap`. `Attributes`
(`src/gameplay/character/attributes.gd`, 21 code lines) is a namespace over `Flags` —
`attr/<who>/<name>`, an integer number of steps clamped to ±4 — with no resource, no registry and
no save section. `GroundSurface` (`src/gameplay/world/ground_surface.gd`, 26) resolves a node to
the `metadata/surface` on it or on its nearest tagged ancestor. `Footsteps`
(`src/gameplay/character/footsteps.gd`, 115) is a component under a body that probes downward,
takes a step every 1.7 metres and generates the sound from the surface's NAME. `PlayerController`
gained `character_id`, the const `PACE`, and a public `current_speed()` that scales every gait by
the attribute. Content: three `metadata/surface` tags in `courtyard.tscn`, one in
`lantern_hall.tscn`, a `Footsteps` node in `player.tscn`. 56 new assertions in
`tests/unit/character_depth_test.gd` and a new `AUTHORING.md` section.

**Why.** The row's own instruction was "decide FIRST what reads one", and it was the right one:
17 of the 23 settings have no consumer, and WP-09 found `Gate.locked_key` and
`PathAction.refusal_key` declared, validated by a content gate and read by nothing for six
packages. So this ships with exactly ONE consumer and two structural defences against that number
growing quietly. There is no registry and no enum of attribute names — any StringName is an
attribute the moment something writes it, which meets ADR-0006's no-code-per-thing test without a
sixth directory scan (`area_db.gd`'s header warns against one). And **an attribute's name is a
const on its CONSUMER**, `PlayerController.PACE`, never on the container: an attribute nobody reads
therefore has nowhere to be written down, and `attributes.gd` cannot accumulate a table of good
intentions. That is the whole design — a rule about where a name lives, not a mechanism.

A value is a STEP rather than the number: a flag holding `4.7` would be a walk speed authored into
a save file and the tuned `walk_speed = 3.2` would stop being the truth. Clamped for `Standing`'s
reason — a repeatable action must not farm a number that later gates content.

A surface is metadata rather than a component (a node per floor tile), a group (one flat namespace
shared with `navmesh_source`, where a typo becomes a second surface silently) or an enum — **a
list of surface names in `src/` is engine code naming demo content, which `check_boundary` fails
the build over.** Inheriting from the nearest tagged ancestor is what makes it cheap: the courtyard
tags `Terrain` once and overrides the two floors that differ. The step's timbre is DERIVED from the
name for the same boundary reason: a table would be the same violation, and it would mean a game
authoring `sand` gets silence until someone edits `src/`. Art is deferred and audio is art, so the
burst is generated the way `AmbienceBed` generates its rain, and `stream_for()` is the one function
a game with real recordings replaces.

**Connects.** `attr/<who>/<name>` is the FIFTH use of namespace-over-`Flags` after
`PersistentState`'s `obj/<area>/<object>/<field>`, `Standing`'s `standing/<who>`, `Equipment`'s
`equip/<wearer>/<item>` and `WorldMap`'s `map/<area>` — WP-11 said the next thing needing saved
per-thing state should reach for it before reaching for a save section, and it did, first. The same
three consequences follow and all three are asserted: already saved with no register, version or
migration; already cleared by a new game; already announced on `flag_changed`, so a quest step or a
dialogue condition can test an attribute with no code at all. It needed no new staging flag either
— `--flag=attr/player/pace:4` already exists, already waits for the area (gotcha 32) and already
goes through `_settle_stable` (gotcha 35), so `dev_stage.gd` stayed at 247 of its 250 lines and did
not have to split. `Footsteps` is a component found under a body, the shape `Inventory` and
`Equipment` already have; it plays through its own `AudioStreamPlayer3D` rather than through
`Audio`, which is what `audio_director.gd`'s header asks for in the words "a footstep playing after
the character is gone". No new signal, no new autoload, no new registry, no new CSV row.

**Verified.**

```
"$G" --headless --import                     # grepped for SCRIPT ERROR / Parse Error: zero
"$G" --headless --quit-after 120             # Session ended after 1.3s — 0 warnings, 0 errors
"$G" --headless res://tests/test_runner.tscn --quit-after 400
                                             # === 1355 passed, 0 failed, 0 skipped ===
"$G" --headless --script tools/check_budgets.gd   # 122 files, 10416 code lines, 0 violations — PASS
"$G" --headless --script tools/check_content.gd   # PASS
"$G" --headless --script tools/check_boundary.gd  # PASS, 116 engine scripts scanned
```

**The windowed probe, which is the only thing that can see either criterion.** Neither claim is
visual, so no capture reads it, and `TestCase.run()` is synchronous, so no assertion reaches it.
Run windowed with a temporary `--footsteps` probe in `dev_probes.gd`, since removed —
`git diff src/systems/debug/` is empty:

```
PROBE audible=true driver=WASAPI
PROBE at (4.0, 0.2, 4.0)    grounded=true surface='grass' brightness=0.733 decay=2.13 playing=true steps=1
PROBE at (0.0, 0.6, -2.0)   grounded=true surface='wood'  brightness=0.841 decay=4.68 playing=true steps=2
PROBE at (-8.5, 3.4, -2.5)  grounded=true surface='stone' brightness=0.550 decay=3.02 playing=true steps=3
PROBE pace=0 speed=3.200 moved=2.861 m in 60 frames, steps=4
PROBE pace=4 speed=4.800 moved=4.687 m in 60 frames, steps=7
```

Three surfaces, correct: grass and wood from their own tags and **stone INHERITED from `Terrain`**,
which is the walk up the tree working in a real area rather than in a fixture. Then the attribute
criterion, driven by real `MOVE_UP` input over the same 60 physics frames: 2.861 m at `pace=0`
against 4.687 m at `pace=4`, and 4 steps against 7, because a faster walk fills a stride sooner.

**A DEFECT THE PROBE FOUND AND NOTHING ELSE COULD HAVE, AND IT IS GOTCHA 2 WITH A SPEAKER ON IT.**
The first run of that probe reported `playing=true` on all three surfaces with every rung green —
and grass came back at brightness 0.452 against stone's 0.446, which is *the same sound*. The cause
is that **`String.hash()` mixes its low bits weakly**: `"grass"` hashes to 260508453 and `"stone"`
to 274826446, wildly different numbers whose last three digits are 453 and 446, so `hash() % 1000`
clusters short names of similar length — `"wood"` and `"sand"` differ by 159027 in a number of
2.09 billion. A second axis was added first and did not save it (3.65 against 3.71, the same
coincidence twice); the real fix is an avalanche in `_spread`, one multiply and two shifts, which
moves the pair to 796 and 572. Both axes were kept: two independent dimensions make the remaining
odds small. **The regression assertion demands a MARGIN, not mere inequality**, because inequality
is exactly what the broken version passed. New gotcha 36.

**A windowed capture, LOOKED AT.** `build/shots/wp09b_courtyard.png`, the courtyard at 12:00 after
the metadata edits, confirming that the three tagged materials are the three the player actually
walks on and that nothing in the scene moved: grass underfoot, the wood dais with the keeper beside
it, stone pillars and back wall.

**Proved red, then green — three times, each with the real failure shape (gotcha 23).**

1. `const HOME_GROUND := &"courtyard"` planted in `footsteps.gd` — `check_boundary` exits 1 with
   `res://src/gameplay/character/footsteps.gd:54 names demo content 'courtyard' (from
   res://data/areas/courtyard.tres)`; reverted, exit 0.
2. The consumer broken the way it would really break — `current_speed()` made to return the gait
   speed and ignore the attribute, which is *precisely* the declared-and-unread failure this
   package exists to avoid. The suite exits 1: `1352 passed, 3 failed`, first failure
   `FAILED: a raised pace is measurably faster — expected true, got false`. Reverted,
   `1355 passed, 0 failed`, exit 0.
3. The inheritance walk stopped after one node — the break that silently loses the demo's third
   surface. Exits 1 with `FAILED: an untagged body inherits from the root — expected fixture_hard,
   got `; reverted, exit 0.

**Unblocks.** Anything that wants to react to what is underfoot: a dust puff, a splash, a slower
crossing, a track left in snow — `Footsteps.current_surface()` is the query, and it is a query
rather than a signal because nothing needs one yet. Anything that wants to change a character:
a conversation, a trigger volume, a rest point or a quest consequence can write
`attr/<who>/<name>` today with no code, and a quest step can test one. And a second attribute
costs nothing to name — only the line that reads it.

**Known gaps.**
- **No footstep particles**, which the inventory row asked for beside the audio. A puff is a
  listener on the surface a step was taken on and is a package for whoever wants one.
- **Exactly one attribute has a consumer, and that is the rule rather than an omission.**
  `attr/player/patience` is writable today and nothing will do anything with it. Naming an
  attribute is free; READING one is a line of engine code, and `AUTHORING.md` says so out loud.
- No character sheet screen, no attribute that gates an interaction, no equipment that modifies
  one, and no surface that costs anything to cross — a slow surface is a `PlayerController`
  change and belongs with whoever wants the mechanic.
- **`Footsteps` polls its parent's velocity rather than being told.** Cheap and correct for one
  body; a hundred characters each raycasting every frame is not measured, and the probe pattern
  (`--npc-storm`) is where that question belongs if it ever matters.
- A surface name is a public identifier the way an item id is: renaming `grass` to `lawn` changes
  the sound every step in that area makes. Stated rather than hidden, and the same price
  `Equipment` pays for an item id.

**CI green, run 33266184919, job logs read rather than the tick** (gotcha 26 — the run listing lags
and the tick is not the evidence). Full checkout: **1355 passed, 0 failed, 0 skipped**. Stripped
template: **1287 passed, 0 failed, 19 skipped** — the same 19 skips as before, because
`character_depth_test.gd` names no demo content and therefore runs in full against a stripped
checkout, which is the point of building both surfaces out of `fixture_` names. All three checkers
PASS in both jobs.

**Commit `da126d9` on `claude/wp-09b-attributes`, PR #19**, stacked onto `claude/wp-11-worldmap`
(#18) rather than `main`, matching the rest of the chain.


## 2026-08-29 — WP-11 · World map and fast travel

**Did.** A world map, discovery and fast travel, on `claude/wp-11-worldmap` branched from
`claude/wp-09-character`. Five new files: `src/content/world/area_def.gd`,
`src/content/world/area_db.gd`, `src/systems/world_map/world_map.gd`,
`src/ui/screens/map_screen.gd`, `tests/unit/world_map_test.gd`. Two authored `AreaDef`s in
`data/areas/`, six CSV rows, one new palette colour, and a `WorldMap` node under `GameRoot`.

**Why this package over the three alternatives.** T3.1 (the generic registry), T3.3 (an
item-count quest step) and WP-09b (attributes and surfaces) are all real and all narrower, and
each improves something that already works. The world map was the last system in the catalogue
with NO PROOF AT ALL, which is the reason WP-08 went first and the same reason this went now:
`TEMPLATE.md`'s replacement for the retracted "depth before breadth" is breadth of systems with
one shallow proof each. Two areas is what the demo has and two areas is what this was proved on.

**Why it is a flag and not a store.** WP-09's section said to copy `Equipment`'s shape for
discovery, and it copied cleanly. A known area is `map/<area id>` in `Flags` — the FOURTH use of
the namespace-over-`Flags` convention after `PersistentState`'s `obj/<area>/<object>/<field>`,
`Standing`'s `standing/<who>` and `Equipment`'s `equip/<wearer>/<item>`. Three independent
systems on one convention is now a pattern rather than a coincidence. The consequences are
`Equipment`'s three, verbatim: it is already saved (no `SaveSystem.register`, no version, no
migration, and a new game clears it for free), anything that writes the key reveals a place with
no code, and `flag_changed` already announces it. So "discovery persists across a save and a
reload, including from the far side of an area that is no longer loaded" needed no code at all:
the flag never lived in the area.

**Connects.** `WorldMap` listens to `Events.area_entered` (Director) and `Events.game_started`,
writes `Flags`, and emits `Events.area_discovered` and `Events.area_change_requested` — the same
signal `AreaDoor` emits, so `Director` still owns every transition and its guard, and nothing
else calls `change_area()`. `MapScreen` reads `AreaDb` and `WorldMap` and is bound to `M` in
`ScreenKeys`, which is where that file's own header predicted the map key would land. `AreaDb` is
the fifth directory-scan registry (ADR-0006) and is reported by `CatalogueReport` and redirected
by `Fixtures` like the other four. Nothing already in the tree was modified to make discovery
work: a `DialogueChoice` effect, a `TriggerVolume` or a `Lever` writing `map/<id>` reveals a
place, and a `Gate` with `requires_flag = &"map/<id>"` is a road that opens once you know where
it goes.

**Verified.**

```
"$G" --headless --import                            # zero SCRIPT ERROR / Parse Error lines
"$G" --headless --quit-after 120                    # 0 warnings, 0 errors
"$G" --headless res://tests/test_runner.tscn --quit-after 400
"$G" --headless --script tools/check_budgets.gd     # 118 files, 10,115 code lines, exit 0
"$G" --headless --script tools/check_content.gd     # exit 0, "mapped areas: 2"
"$G" --headless --script tools/check_boundary.gd    # exit 0, 16 demo names derived
```

Suite: `=== 1298 passed, 0 failed, 0 skipped ===`, exit 0 (1224 before; 59 in the new case, 2 in
`export_test` for the fifth catalogue line, 4 in `art_contract_test` for two screens added to
`STYLED_SCREENS`, and 9 that `docs_test.gd` computed for itself from the new worked example in
`AUTHORING.md` — expected, not a regression). Boot log carries
`[content] areas: 2 found in res://data/areas -> [...courtyard.tres, ...lantern_hall.tres]` and
`[map] World map ready over 2 mapped area(s)`.

A stripped template — `data/` and `scenes/areas/` deleted by hand, the way the CI job does it —
ran `=== 1230 passed, 0 failed, 19 skipped ===`, exit 0, with `check_budgets`, `check_content` and
`check_boundary` all exit 0 and `mapped areas: 0`. `world_map_test` reported `49/49` there and
named its one skip: *"the authored map agrees with the authored areas (no areas in scenes/areas)"*.

**Proved red, then green — three times, each with the real failure shape (gotcha 23).**

1. `data/areas/lantern_hall.tres` `name_key` misspelled by one letter:

```
  !! lantern_hall name_key 'area.lantern_hall.nam' is not in the CSV
FAIL — 1 content violation(s)
exit=1
```

   reverted: `reverted exit=0`.

2. The load-bearing invariant broken the way it would really break — `discover()` made to keep a
   `Dictionary` instead of writing the flag, which is the "second truth" a discovery store would
   have been:

```
FAIL and the whole of that is one flag — expected true, got false
FAIL somewhere else is not — expected false, got true
FAIL only the one place — expected 1, got 2
FAIL exactly one discovery was announced — expected 1, got 0
FAIL somewhere never found is refused — expected false, got true
FAIL no request escaped any of them — expected 0, got 1
FAIL discover it before saving — expected true, got false
FAIL scrambled — expected false, got true
=== 1288 passed, 10 failed, 0 skipped ===
FAILED: world_map_test raised 1 engine script error(s): ["Out of bounds get index '0'
  (on base: 'Array[StringName]') at res://tests/unit/world_map_test.gd:151"]
FAILED: world_map_test planned 59 outcomes and produced 57 — a crash, an early return or a
  stale plan
exit=1
```

   All three framework mechanisms fired on one break — the assertions, `ErrorWatch`, and the
   plan. Reverted: `=== 1298 passed, 0 failed, 0 skipped ===`, exit 0.

3. `const HOME := &"courtyard"` planted in `map_screen.gd`:

```
  !! res://src/ui/screens/map_screen.gd:33 names demo content 'courtyard'
     (from res://data/areas/courtyard.tres)
FAIL — 1 boundary violation(s)
exit=1
```

   reverted: `reverted exit=0`. Note the source it cites: the gate now derives area ids from
   `data/areas/` as well as from the `scenes/areas/` folder names.

**The input path, proved by a temporary probe and then removed** (gotcha 15). Added to
`dev_capture.gd` as `--probe-map`, run windowed with real `InputEventAction`s:

```
[test] PROBE after M: top=map depth=1
[test] PROBE focus='@Button@27' text='Lantern Hall'
[test] PROBE after M again: top=NOTHING depth=0
[map ] Travelling to 'lantern_hall' (spawn 'from_courtyard')
[test] PROBE after Enter: area=lantern_hall depth=0
```

So `M` opens the map, focus lands on the only travellable marker, `M` closes it again, and Enter
on that marker really travels — landing on the spawn the `.tres` authored, not the one the door
uses. `depth=0` afterwards is `ScreenKeys` unwinding the stack on `area_change_requested`, which
is why `MapScreen` deliberately does not close itself. `git diff src/systems/debug/dev_capture.gd`
is empty.

**Three windowed captures, LOOKED AT and READ** (gotcha 28 — a map with the wrong area marked
still looks like a map, so the shot has to be discriminating). All at 960x540, `--new-game`,
`--shot-frame=100`, `--time=12:00 --freeze-time`, `--quit-after 120` (220 for the third).

1. `--open-menu=map` — a large WHITE dot low on the plate reading *"Rose Courtyard · you are
   here"*, and a small GREY dot above it reading *"???"*. Two states, drawn differently, in one
   shot.
2. `--flag=map/lantern_hall:true --open-menu=map` — same camera, same hour, ONE FLAG different:
   the grey `???` is a GOLD dot reading *"Lantern Hall"* with the focus ring on it, and the
   courtyard marker is unchanged. The seam photographed.
3. `--goto=lantern_hall --open-menu=map` — the two states SWAPPED: Lantern Hall white and *"you
   are here"*, Rose Courtyard gold and selectable, over the hall's warm interior instead of the
   courtyard's daylight. That is the far-side claim and the proof of travel in one frame.

**A staging race the third capture found, and gotcha 21's shape fixed it.** `--goto` and
`--open-menu` both begin by awaiting the first area, so they leave that wait on the same frame: if
the menu opened first, the travel `--goto` was about to request unwound it, and the capture was of
nothing with every rung green. A fixed number of extra frames only moves the race.
`dev_stage._settle_stable(frames)` demands twenty CONSECUTIVE settled frames and resets its count
the moment a transition starts, so it cannot be satisfied early. Fourth staging flag to need a
wait after `--open-menu`, `--flag` and `--open-inventory`, and the first to need a persistent one.

**Two gaps in earlier packages, closed in passing, both one line.** `journal_screen.gd` was never
added to `art_contract_test.gd`'s `STYLED_SCREENS`, whose own comment says "a sixth screen belongs
on this list" — so the gate that stops a colour being written down again could not see the journal
at all. Both it and `map_screen.gd` are listed now, +4 assertions. And `docs/NEW_GAME.md` never
listed `data/quests/` among the content roots; it now lists that and `data/areas/`.

**One new palette entry, the first since T2.1 wrote the file.** An undiscovered marker has to be
visible and clearly lesser, and `dim` is a translucent black that would have drawn nothing against
the plate. `UiPalette/colors/muted` in `ui_theme.tres`, read by name. That is the T2.1 seam
working as advertised: one file, one line. The `Button` styleboxes were left unpopulated for the
fourth package running — the map's markers are legible against the shipped dark palette, so this
screen did not force the decision either.

**CI green**, run 33262997072, read from the job logs rather than the tick: full checkout
`=== 1298 passed, 0 failed, 0 skipped ===` with `mapped areas: 2`, stripped template
`=== 1230 passed, 0 failed, 19 skipped ===` with `mapped areas: 0`. Both match the local runs.

**Unblocks.** Objective markers on the map: `Events.quest_advanced` has had an emitter since
WP-08 and `MapScreen` already redraws on facts, so that is a listener and one more marker state
rather than new state. A `Gate` or a `QuestStep` gating on having FOUND somewhere works today with
no code. And a region map for a game with thirty areas needs thirty `.tres` files and no code,
which is ADR-0006's test applied to a fifth catalogue.

**Gaps.**
- **A departure-side travel point** — a kiosk you must stand at — was not built. It is a
  restriction on a mechanism rather than the mechanism, it needs content the demo does not have,
  and it would be one interactable emitting the request the map screen already emits. That is a
  game's policy, not the template's.
- **`AreaDb` is the fifth copy of the same thirty lines**, and T3.1's arithmetic is worse for it.
  Not re-argued here: WP-08 costed the refactor and the board carries the row. `area_db.gd`'s
  header states the changed number rather than repeating the reasoning.
- **The map draws nothing but dots.** No fog of war, no zoom or pan, no terrain, no objective
  markers, no travel cost and no travel time. Art is deferred indefinitely, so a `ColorRect` per
  place is what this template ships and a consuming game brings its own plate.
- **An area whose `.tres` is renamed loses its place in an existing save**, because the flag key
  contains the area id. Same price `Equipment` pays for an item id, stated rather than hidden.
- The `Button` styleboxes, still.

## 2026-08-27 — WP-09 · Character depth: equipment, and two @exports nothing had ever read

**Did:** the equipment third of WP-09, and split the other two thirds onto the board as `09b`.

The row asked for three systems in one package — an attribute container, surface-aware footsteps,
and equipment that changes traversal. That is three sets of content, three test files and three
captures, well past the board's own "8 files or 500 new code lines, over that split it and add a
row". So it was split, and the third with a CONSUMER was built: traversal already has a class that
gates on a flag, so equipment had somewhere to be proved the day it existed.

**`Equipment` owns no dictionary.** A slot is a flag:

```
equip/<wearer_id>/<item id>          equip/player/item/brass_lantern
```

`PersistentState`'s `obj/<area>/<object>/<field>` and `Standing`'s `standing/<who>`, applied a
third time. `ItemDefinition` gains one field, `equip_slot`, a `GameEnums.EquipSlot` ordinal with
NONE first so every `.tres` authored before it stays valid unedited. `Equipment.of(who)` resolves
the component off the interactor the interaction contract already hands over, exactly as
`Inventory.of(who)` does, so an NPC or a stash can have one.

**Why:** three things fall out of the flag shape, and together they are the whole argument against
a `Dictionary[EquipSlot, StringName]` plus a save section.

1. **It is already saved.** No `SaveSystem.register`, no save version, no migration — and a new
   game clears it for free, because `Director.start_new_game()` clears flags.
2. **A gate can require it with NO CODE.** A `Gate.requires_flag` pointing at one of those keys
   gates traversal on a held lantern, and `Gate` was not touched. Neither was `QuestStep`, nor
   `DialogueChoice`, nor `ClimbPoint`. This is the second system to ride WP-08's seam, which is
   the first evidence it generalises rather than fitting one case.
3. **It is announced already.** `flag_changed` fires, so `QuestTracker` re-derives and a dialogue
   condition re-evaluates without anything learning that equipment exists.

The cost, stated: the key contains an item id, so an item id is now a public identifier the way an
`object_id` is. Renaming an item's `.tres` brings it back stowed — the item survives, because
`Inventory` deliberately keeps counts whose definition has vanished.

**THE ITEM STAYS IN THE BAG WHILE IT IS HELD.** Moving it out would make equipment a second place
items live: `Inventory.count_of()` would begin lying and `Gate.requires_item` would refuse a key
that is in the player's hand. So equipping is purely a flag, and the price is that losing the item
has to stow it — `_revalidate`, bound to `inventory_changed` rather than to `item_lost`, because
that is the one signal every path emits, a restored save included.

**Two @exports that had been declared, validated and read by nothing.** Found while looking for
where an equip-gated gate tells the player it needs a light. `Gate.locked_key` (WP-01) and
`PathAction.refusal_key` (WP-07) were both set by authored content, both checked by
`check_content`, and both DEAD: `interact_prompt.gd` computed `refusal.<reason>` from the enum and
never asked the object. `PathAction.refusal_key`'s own comment claimed it was "shown for the
LOW_STANDING refusal". Gotcha 2's shape exactly — a message that is merely WRONG looks the same as
a message that is right, so eight rungs, both CI jobs and 1,149 assertions were green over it for
two packages. `interaction_refused` now carries a `message_key` alongside `args`, for the same
reason `args` travels there rather than being asked of the target, and
`Interactable.refusal_key(who, reason)` is the override. Empty means "compute it from the reason".

**Connects:** `Equipment` sits beside `Inventory` under the player and writes through `Flags`, so
it reaches `SaveSystem` and `flag_changed` with no wiring of its own. `InventoryScreen` binds the
component in `for_carrier(who)` and Enter on a row calls `Equipment.toggle` — the first time
pressing an inventory row has done anything; its comment said "use and tooltips are WP-09 and
beyond". `Gate` reads the flag through the `requires_flag` it already had. `--equip=` joins
`--give=` in `dev_stage.gd`. Nothing above `gameplay` learned a new name except the one signal.

**Verified:**

```
$ "$G" --headless --import 2>&1 | grep -cEi "SCRIPT ERROR|Parse Error"
0
$ "$G" --headless --quit-after 120
22:35:42 [INFO ] [boot     ] Session ended after 1.4s — 0 warnings, 0 errors
$ "$G" --headless res://tests/test_runner.tscn --quit-after 400
22:38:16 [DEBUG] [test     ] --- equipment_test: 70/70 ---
22:38:16 [DEBUG] [test     ] --- docs_test: 90/90 ---
22:38:16 [INFO ] [test     ] === 1224 passed, 0 failed, 0 skipped ===   (exit 0)
$ "$G" --headless --script tools/check_budgets.gd    -> exit 0
    ok   src/gameplay/character/equipment.gd      82 / 250
    ok   src/ui/screens/inventory_screen.gd      123 / 250
    ok   src/systems/debug/dev_stage.gd          235 / 250
    ok   tests/unit/equipment_test.gd            146 / 250
$ "$G" --headless --script tools/check_content.gd    -> exit 0
       item/brass_lantern     TOOL         max_stack=1
$ "$G" --headless --script tools/check_boundary.gd   -> exit 0
    demo names derived: 16 — [..., "item/brass_lantern", "brass_lantern", ...]
```

1149 → **1224**: 70 in the new case, and 5 that `docs_test.gd` computed from the new worked `.tres`
example in `AUTHORING.md`.

**BOTH GATES PROVED RED, THEN GREEN, with the real failure shape (gotcha 23).**

(1) The authored gate's `locked_key`, misspelled by one letter in `courtyard.tscn`:

```
$ "$G" --headless --script tools/check_content.gd
  !! res://scenes/areas/courtyard/courtyard.tscn:369 localization key 'object.gate.arch.lockd' is not in the CSV
FAIL — 1 content violation(s)
PLANTED content exit 1
REVERTED content exit 0
```

(2) The load-bearing invariant broken the way it would really break — `equip()` made to remove the
item from the bag, which is the shortcut a later reader would reach for:

```
PLANTED suite exit 1
22:31:19 [INFO ] [test] === 1201 passed, 18 failed, 0 skipped ===
22:31:19 [ERROR] [test] FAILED: it is still carried — expected true, got false
22:31:19 [ERROR] [test] FAILED: toggle holds it — expected true, got false
REVERTED suite exit 0
22:31:27 [INFO ] [test] === 1219 passed, 0 failed, 0 skipped ===
```

**THE INPUT PATH WAS PROVED BY A TEMPORARY PROBE, AND THE PROBE WAS REMOVED** (gotcha 15 —
`TestCase.run()` is synchronous, so no assertion can press a key, and "Enter on a satchel row
equips it" is an input path). Added to `dev_stage.gd`, run windowed, quoted here verbatim, deleted:

```
$ "$G" --resolution 960x540 --quit-after 140 -- --new-game --give=item/brass_lantern \
       --probe-equip-row --time=12:00 --freeze-time
22:34:40 [INFO ] [test     ] PROBE focus='@Button@26' held=[]
22:34:40 [INFO ] [equipment] player equipped 'item/brass_lantern'
22:34:40 [INFO ] [test     ] PROBE after press 1: held=[&"item/brass_lantern"]
22:34:40 [INFO ] [equipment] player stowed 'item/brass_lantern'
22:34:40 [INFO ] [test     ] PROBE after press 2: held=[]
```

`git diff src/systems/debug/` afterwards carries only `--equip` and the `--open-inventory` wait.

**THREE WINDOWED CAPTURES, LOOKED AT AND READ.** All at `--time=12:00 --freeze-time` with
`--new-game --shot-frame=70` (or 160 where an interaction had to land first), because no ordinary
run enters an area (gotcha 31) and a propless corner at 18:40 renders near-black.

1. `--give=item/brass_lantern,item/rose_petal:2 --equip=item/brass_lantern --open-inventory` —
   the satchel over a live courtyard reading `Brass Lantern  x1   [in hand]` under *Tools* and, two
   rows down, `Rose Petal  x2` with NO marker under *Materials*. **The unmarked row is the point**:
   a marker glued onto every row would photograph identically on one item, which is gotcha 28's
   lesson — a capture of something that merely looks fine is not evidence.
2. `--give=item/brass_lantern --stand-by=ShadowedArch --interact=1` — the arch refusing with
   *"It is pitch dark beyond the arch, and you have no light in hand."* That is `locked_key`, on
   screen for the first time since it was declared; the generic line would have read "It will not
   budge. Something holds it shut." The lantern is in the bag throughout, so carrying is visibly
   not the same as holding.
3. The same line plus `--equip=item/brass_lantern` — same camera, same hour, same position, one
   flag different: the blocker slab that stood beside the player in (2) is GONE, and
   *"Lantern raised, the dark under the arch gives way."* is up.

**TWO DEFECTS THE CAPTURE FOUND AND NO GATE COULD.**

1. **The satchel screen redrew only on `inventory_changed`.** Capture 1 came back reading
   `Brass Lantern x1` with no marker while the log said `player equipped 'item/brass_lantern'` —
   the screen was right about the bag and silently wrong about the hand. `_on_row_pressed` calling
   `refresh()` itself is not enough, because a press is not the only way equipment moves: staging
   equips from the command line and `_revalidate` stows an item the moment it leaves the bag. It
   now listens to `equipment_changed` as well, which is the signal's whole reason for existing.
2. **`--open-inventory` did not wait for the area**, so with `--new-game` it drew over the title
   screen and the arriving transition unwound it. Third flag to need that wait after `--open-menu`
   and `--flag` — gotcha 32's family, and `dev_stage.gd` now says any flag that puts something on
   screen needs it.

**ONE ENGINE SURPRISE, and it is going on the gotcha list.** `Array[StringName].sort()` DOES NOT
SORT ALPHABETICALLY — it orders by the StringName's internal handle. `equipped_ids()` returned the
two fixture ids reversed, and the only trace was one failing assertion:

```
FAILED: the ids come back sorted — expected item/fixture_held_two,item/fixture_worn,
                                        got item/fixture_worn,item/fixture_held_two
```

`Inventory.ids()` already sorted through `String` with a `sort_custom`, and its comment is why this
took a minute rather than an hour. `equipped_ids()` does the same now.

**Unblocks:** "hold a light to enter the dark" as a quest step, a dialogue condition or a climb
requirement, all with no code. `09b` (attributes, surfaces) has a worked example of the
namespace-over-`Flags` shape to copy. Any future per-carrier state that must be saved and
announced has a third precedent rather than a second.

**Gaps:**
- **A quest step still cannot read an ITEM COUNT, and equipment did not make it cheaper.** Being
  HELD is a fact about one item, which is exactly what a flag is. A COUNT is not, and both ways to
  expose one cost something real: an `Inventory` mirroring `count/<item>` into `Flags` writes every
  carried item into the flag section as well as its own, and a `QuestStep` reading the bag directly
  puts `gameplay/Inventory` inside a `systems` tracker against the layer rule. Now **T3.3** on the
  board with both options costed, rather than a sentence repeated in three documents.
- **Attributes and surface-aware footsteps are not done** — `09b`, with the reasons in its section.
  The one worth repeating: a footstep is the single claim this ladder cannot see at all. Not
  visual, so no capture reads it; not synchronous, so no assertion reaches it; and headless the
  audio driver is `Dummy` and every `play()` leaks.
- No equipment SCREEN, and no stat effect from equipment — nothing reads a stat yet.
- The `Button` styleboxes in `ui_theme.tres` are still unpopulated. The satchel did not force the
  decision: its rows are legible against the shipped dark palette. Third package to leave them,
  and each time for the same stated reason rather than by omission.
- `Gate.stays_open` defaults true, so an equip-gated gate that has opened once stays open even
  once the lantern is stowed. Correct for "you needed a light to get in"; a gate that re-checks
  every time is a different object, and nothing has asked for one.

**CI green, run 33095187525, and the JOB LOGS were read rather than the tick.** Full checkout
**1224 passed, 0 failed, 0 skipped** with `quests: 1` in `check_content`; stripped template
**1169 passed, 0 failed, 16 skipped** — the equipment case runs in BOTH jobs, because it is
fixtures all the way down and skips nothing, which is the point of `tests/framework`. All three
checkers PASS in both. The push run (33095176524) and the pull-request run (33095253385) are green
as well.

**Commit `1b3d799` on `claude/wp-09-character`, PR #17**, stacked onto `claude/wp-08-quests` (#16)
rather than `main`, matching the rest of the chain.


## 2026-08-26 — Resequencing: the export proof jumps the queue, and one contradiction is settled

**Did:** no code. Three planning corrections, all found by reading the docs against each other
rather than against the engine.

1. **New package T2.0 — the export proof**, at the FRONT of Phase T2, ahead of T2.1. It has its
   own section on the board with a manifest and exit criteria, so the row is a real fallback
   handoff and not a title.
2. **Settled a direct contradiction between two documents.** `SYSTEMS_INVENTORY.md` marked export
   presets `LATER`; `ROADMAP.md`'s Phase T3 called the export proof *"the one genuinely blocking
   item from WP-15"*. Both had been true in writing for as long as the T-phases have existed.
   Settled in favour of **blocking**, and the inventory row now says so and records that it was
   changed.
3. **WP-10 (crafting and gathering) marked OPTIONAL** on the board. `TEMPLATE.md` already said it
   should be — *"crafting is the clearest case: a genre choice, not a requirement of every game"* —
   and the row still said `TODO`. The note and the row now agree.

Also swept two smaller drifts in `CONTEXT.md`: it carried a stale `**Next package:**` line per
package, two of them stranded and contradicting each other (T1.4 and T1.2), and it described the
board as "fifteen packages" from before the T-phases were added.

**Why:** the asymmetry decides the order. The export proof is cheap to run — one preset, one
export, one count — and if it FAILS the fix is architectural, a revision to ADR-0006 touching how
all content is found. Every package built before it would then have been built on an assumption
known to be false. T2.1 by contrast fails locally, inside `CharacterVisual` and a `Theme`. Cheap
test, architectural blast radius, so it goes first.

The underlying risk is a familiar shape: the three registries find items, conversations and
schedules by DIRECTORY SCAN (ADR-0006), and nothing in any scene references those `.tres` files —
the registry discovers them at runtime. Godot's exporter walks *dependencies*. If it therefore
omits them, an exported build has an empty inventory, dialogue that will not start and NPCs that
stand still, **while every ladder rung, both CI jobs, `check_content` and 911 assertions stay
green** — because they all run from `res://` in the editor, where the files are plainly there.
That is "409 passing checks and never rendered a frame" reproduced at the last possible moment,
and T1.4's CI cannot see it either.

**Connects:** T1.4 made completion claims checkable by a third party. This is the first thing that
CI provably cannot check, which is why it needs a package rather than a gate.

**Verified:** docs only — no `.gd`, `.tscn` or `.tres` touched. Ladder re-run anyway, because a
docs-only claim is still a claim:
`--headless --import` exit 0 with zero `SCRIPT ERROR` / `Parse Error` lines · boot
`0 warnings, 0 errors` · `911 passed, 0 failed, 0 skipped`, exit 0 · `check_budgets`,
`check_content`, `check_boundary` all exit 0 · CI green.

One claim in the new T2.0 section was **wrong when first written and corrected before commit**: it
said `export_presets.cfg` is gitignored by the `*.cfg` conventions. It is not — `.gitignore` names
only `override.cfg`, checked with `git check-ignore -v`, which reports it as not ignored. The
section now says so. Worth recording because it is exactly the kind of plausible-sounding detail
that a later session would have trusted.

**Unblocks:** T2.0 as the next chat, with a written manifest. T2.1's chip was replaced rather than
left pending, so the board and the handoff agree.

**Known gaps:** the `## Plan — where this is going` section of `CONTEXT.md` is still stale — it
names WP-07 as next and cites 460 assertions when there are 911. Left alone deliberately: it is a
narrative section, rewriting it is not this pass's job, and a partial rewrite would be worse than
an obviously old one. Whoever closes T2.0 should replace it wholesale.

---
## 2026-08-26 — T1.4: the ladder stops being seven commands a human remembers

**Did:** `.github/workflows/ladder.yml` and `.github/actions/setup-godot/action.yml`. Six of the
seven rungs now run on every push, every pull request and on manual dispatch, in two jobs:

- **Ladder (full checkout)** — rung 2 import, rung 3 boot, rung 4 suite, then `check_budgets`,
  `check_content`, `check_boundary`, each its own step so a failure names itself.
- **Ladder (stripped template)** — `rm -rf data scenes/areas`, then the same rungs minus the boot.

The composite action downloads `Godot_v4.7.2-stable_linux.x86_64.zip`, verifies it against a
SHA512 **pinned as a literal in the workflow**, installs it, and asserts
`godot --version` is exactly `4.7.2.stable.official.ed1daf0bf` before any rung depends on it.
Standard build, never mono. Nothing in `src/` changed, and the one line touched in `tests/` was
reverted to its original value.

**Why:** the ladder was seven commands a human types in order, remembering to grep rung 2. That
held for eleven packages, and it is not a system. It could not have been automated before T1.3:
until then rung 4 reported success on a case that crashed, and a green badge over a suite that
cannot fail is worth *less* than no badge, because it is believed.

**Four decisions, and the reasoning is in the workflow file's own comments:**

1. **`.godot/` is NOT cached, the engine archive is.** The cache would be exactly the artefact
   whose absence causes the fresh-clone parse failures, which is the temptation. It is refused
   because a restored `.godot/` can resolve a `class_name` this commit deleted, or hand a `.tres`
   an importer for a file that changed shape — "CI is green and a fresh clone is broken" is the
   precise failure this package exists to prevent, and there is no correctness-preserving cache
   key short of the whole tree. The engine zip is immutable and keyed by version, so it cannot go
   stale. Cache the fixed thing, never the derived one. Cost of the decision: an import per run,
   measured at 8 seconds.
2. **Rung 1 (`--check-only`) is not automatable and is absent.** Autoload identifiers do not
   resolve under it and that error is EXPECTED (gotcha 1); a machine cannot tell it from a real
   one. Rung 2 is the compile check and is where zero tolerance lives.
3. **The boot rung asserts only its last `Session ended` line**, not the whole log. Gotcha 13:
   quitting mid-load prints spurious `Parse Error` lines *after* a clean report, so a whole-log
   grep here would be a flake generator. Frame count is 300, not the local 120 — `--quit-after`
   counts frames, a headless frame costs milliseconds, and a shared runner has no reason to be
   handed a tighter margin than it needs.
4. **The windowed capture rung is stated as impossible, not dropped.** `--headless` shades
   nothing (gotcha 2) and a runner has no GPU, so any capture it produced would be exactly the
   evidence that gotcha calls worthless. Anything with a visual consequence still needs a human.

**Connects:** nothing in `src/` or `tests/` was changed to accommodate CI — which was the stated
tripwire for this package, and it never fired. The workflow calls the same six commands
`docs/CONTEXT.md` already listed, so the local ladder and CI cannot diverge without one of them
going red. The stripped job turns T1.3's by-hand claim into a mechanism.

**Verified:**

*The gate goes RED.* One assertion in `tests/unit/core_test.gd:23` changed to expect `6` where
`DictRead.get_int` returns `5`, pushed as commit `ad6e225`. Run
[32989608134](https://github.com/Raiyan-Bashar-29/HD-2D-game-base-non-combat-/actions/runs/32989608134)
— `completed/failure`. **Failing step: `Rung 4 - test suite`, in BOTH jobs.** Its output:

```
=== 910 passed, 1 failed, 0 skipped ===
FAILED: dict_read int — expected 6, got 5
##[error]Process completed with exit code 1.
```

Rungs 2 and 3 passed, correctly: a wrong expected value is not a parse error. Rungs 5, 6 and 7
were skipped. The stripped job failed the same way at `860 passed, 1 failed, 12 skipped`.

*And GREEN again.* Assertion restored, commit `272053f`, run
[32989771404](https://github.com/Raiyan-Bashar-29/HD-2D-game-base-non-combat-/actions/runs/32989771404)
— `completed/success`, both jobs:

```
godot.zip: OK
No SCRIPT ERROR / Parse Error lines: every script compiled.
Session ended after 2.1s — 0 warnings, 0 errors
=== 911 passed, 0 failed, 0 skipped ===          (full checkout)
=== 861 passed, 0 failed, 12 skipped ===         (stripped) — named skips: 8
98 files, 8100 code lines, 0 warnings, 0 violations
```

The stripped numbers reproduce T1.3's hand-run result exactly.

*Local ladder, after all CI work, on the final tree:*

```
--headless --import                                  exit 0, 0 SCRIPT ERROR / Parse Error lines
--headless --quit-after 120                          Session ended after 1.3s — 0 warnings, 0 errors
--headless res://tests/test_runner.tscn --quit-after 400   exit 0, 911 passed, 0 failed, 0 skipped
--headless --script tools/check_budgets.gd           exit 0
--headless --script tools/check_content.gd           exit 0
--headless --script tools/check_boundary.gd          exit 0
```

*The stripped run was also measured locally before CI existed*, by moving `data/` and
`scenes/areas/` aside: `861 passed, 0 failed, 12 skipped`, true exit code 0, all three checkers
exit 0, then restored with `git status` clean. That is what the stripped job was written against.

**Three things this cost an hour each, and two are new gotchas:**

1. **GitHub runs every `run:` block as `bash -e {0}`, so `set -uo pipefail` inside a step does
   NOT turn errexit off.** The first red run reported nothing but `Process completed with exit
   code 1` — the step died on the failing `godot` line, before the line that prints which
   assertion failed. The artefact had the answer and the step did not, which is a step that fails
   without saying why. Every rung that needs to survive its own command's failure now captures
   the status with `|| status=$?`, which is exempt from errexit. Fixed in the same package that
   introduced it, and the fix is proved by the quoted red run above.
2. **Verifying a shell fragment interactively with `( ... )` inside an `&&` chain silently
   disables `set -e`.** While checking rung 4 before pushing, the fragment reported exit 0 on a
   deliberately failing suite, which looked exactly like the workflow being broken. It was not:
   run as a real script file — which is how Actions runs it — the same fragment exits 1.
   Measured both ways. A workflow fragment must be tested as a FILE, never inline.
3. **`gh`'s run listing lagged several minutes and led to a wrong diagnosis.** `actions/runs`
   reported `total_count: 0` for four minutes after a push whose run had already been created and
   completed. On that evidence CI looked disabled, and the repo was made public to rule out a
   private-minutes limit — which was unnecessary; the runs that had already passed were pushed
   while it was private. The repo was returned to private and pushes still trigger. Push-event
   delivery on this repo ran up to **25 minutes** behind at times, which is why
   `workflow_dispatch` is now a trigger: a gate with exactly one way to be invoked has a single
   point of failure. A manual run also gets its own `concurrency` group, keyed on its run id,
   because a dispatch mid-verification was cancelled by the very push it was verifying and a
   cancelled run reports neither pass nor fail.

**Unblocks:** every later package. A completion claim is now checkable by a third party instead
of trusted, which is the precondition for a consumer trusting this template at all. T2.1 can
refactor the art seams knowing that breaking a system will be visible without anyone remembering
to run anything.

**Known gaps:**
- **The windowed capture rung has no automation and cannot have one** on a GPU-less runner. Every
  visual claim still rests on a human looking at a PNG. This is stated in the workflow, not
  hidden.
- **No branch protection.** The gate reports; nothing stops a red branch being merged. That is a
  repository setting, not a file in this repo, and it is the natural follow-on.
- **No status badge in `README.md`,** deliberately: a badge on a private repo renders as "unknown"
  to anyone who can see the README, which is worse than no badge.
- **The stripped job does not prune the demo half of `localization/strings.csv`.** `NEW_GAME.md`
  says a game should; pruning it mechanically here would only be the job testing its own regex.
- Push-event delivery latency is outside this repo's control. `workflow_dispatch` is the
  mitigation, not a fix.

---

## 2026-08-26 — T1.3: the suite stops testing the demo, and stops passing when it crashes

**Did:**

Two jobs, and each turned out to rest on a fact nobody had checked.

**1. Fixtures.** A test asserting `item/rose_key` was testing the demo, not the item system.

- `tests/framework/fixture_content.gd` — new. Builds the content a case needs: three items (one
  unique key item, one that stacks to a limit, one spare so a sort order has something to be an
  order OF), a conversation whose graph exercises every rule the runner has, a two-block
  timetable, and a path action that can refuse, fail AND succeed. Every name is abstract —
  `fixture/unique`, not a key to a rose garden.
- `tests/framework/fixtures.gd` — new. Where that content lives, and the switch onto it.
  **The decision, and it is split deliberately along one line: does the system under test
  RECEIVE the content, or LOOK IT UP BY ID?** A `Pickup` is handed an `ItemDefinition` and a
  `PathActionPoint` a `PathAction`, so those fixtures are built in memory and set on the node —
  no file, no global state. But `Inventory.add(id)` asks `ItemDb`, `DialogueRunner.begin(id)`
  asks `DialogueDb` and `NpcBrain` asks `ScheduleDb`, and those three find content **by
  directory scan** (ADR-0006) and cache it statically, so an in-memory resource is invisible to
  them. The choice there was a test-only injection method on each registry — engine code
  carrying a backdoor that exists for the suite and nothing else — or a real directory the real
  scan really reads. It writes `.tres` files to `user://test_fixtures/` and points the registry
  there. **That buys something beyond unwelding the suite:** the fixtures go out through
  `ResourceSaver` and come back through the registry's own scan, so the suite now proves the
  authoring round trip a consuming game depends on and that nothing tested before.
- `ItemDb` / `DialogueDb` / `ScheduleDb` gained `static var content_dir`, defaulting to the
  `res://data/...` const it replaces in the scan. A content ROOT rather than a constant.
- Migrated: `items_test`, `pickups_test`, `screens_test`, `dialogue_test`, `npc_test`,
  `path_actions_test`, `transitions_test`, plus label keys in `traversal_test` and
  `interaction_test`. Two patterns replaced naming: **discovery** (`transitions_test` and
  `npc_test` now scan `scenes/areas/` instead of listing two ids, so area three is covered the
  day it appears) and **aggregation** (one assertion over every authored action instead of two
  named `.tres` files).
- Blocks that genuinely assert things about the demo — the authored catalogue matches the disk,
  every authored item name has a CSV row, every authored waypoint exists in some authored area —
  are gated on the demo existing and `skip()`ped when it does not. **A skip stands in for the
  assertions it replaces**, so the plan is the same number either way and a stripped run reports
  exactly what it gave up rather than looking identical to a full one.

**2. Framework hardening.** `ROADMAP.md` had carried this since T1.1: a deliberately crashing
case exited 0, which invalidated every green result the project had.

- `TestCase.plan(n)` — TAP's `1..N`, for TAP's reason. The runner fails a case whose outcomes do
  not equal its plan, a case that declares no plan, and a case that plans zero.
- `tests/framework/error_watch.gd` — new. An `OS.add_logger` `Logger` counting
  `ERROR_TYPE_SCRIPT`, read per case so a failure names the case that crashed.
- `test_runner.gd` — scans `tests/unit/` and fails on a `.gd` file that exists and is not in
  `CASES`; arms the exit code to 1 on its first line and only clears it at the end; calls
  `Fixtures.deactivate()` after every case, not only the ones that switched; and prints the
  skip total.
- `tools/check_boundary.gd` now scans `tests/framework/` and `tests/unit/` as well as `src/`.
  The suite was exempt because unwelding it was this package's own job; now that the fixtures
  exist, scanning it is what stops the welding growing back one convenient literal at a time.

**Why:**

Deleting `data/` and `scenes/areas/` is step one of `docs/NEW_GAME.md`. T1.2 proved every other
rung survives it. Rung 4 did not, so the ladder that makes this a template was one `rm -rf` away
from being three quarters of a ladder.

And a suite that cannot fail is not a gate. Gotcha 23 says a gate that never fails has never
been tested; this is the same sentence pointed at the test suite itself.

**Connects:**

`Fixtures` reads the same `content_dir` the game and `tools/check_content.gd` read, so there is
one scan path, not a production one and a test one. `Fixtures.area_ids()` is the discovery
`transitions_test` and `npc_test` now share. `ErrorWatch` sits beside the tally rather than
inside it — it counts, the runner decides.

**Verified:**

Two things this package learned by measuring, both of which changed the design:

*A GDScript runtime error aborts ONLY the innermost frame.* Probed with a null dereference three
frames deep:

```
PROBE about to crash
SCRIPT ERROR: Cannot call method 'get_child_count' on a null value.
PROBE reached end of _outer after crash
PROBE reached end of _ready after crash
EXIT=0
```

`_inner` aborted; `_outer` and `_ready` both ran to completion. That is why the runner cannot see
a crash, and why a completion sentinel at the end of `run()` would not have worked. It also means
`get_tree().quit(1)` then `quit(0)` exits 0 — last call wins — which is what makes arming the
exit code safe.

*The plan alone was not enough, and this was measured rather than assumed.* With the plan in
place, a crash planted in a leaf helper with no assertion after it:

```
--- zz_probe_test: 2/2 ---
=== 913 passed, 0 failed, 0 skipped ===
EXIT=0
```

Hence `ErrorWatch`. Same probe, after:

```
zz_probe_test raised 1 engine script error(s): ["Cannot call method 'get_child_count' on a null
value. at res://tests/unit/zz_probe_test.gd:13 in _crash()"]
--- zz_probe_test: 2/2 ---
=== 913 passed, 1 failed, 0 skipped ===
EXIT=1
```

Note the `2/2`: the two mechanisms are complementary, not redundant.

All four silent-pass modes planted, each exiting 1, each removed:

| Planted | Result |
|---|---|
| a crash in a leaf helper | `raised 1 engine script error(s)` — exit 1 |
| a failing assertion | `FAILED: this one fails on purpose — expected 2, got 1` — exit 1 |
| an early return | `planned 3 outcomes and produced 1` — exit 1 |
| no plan at all | `declared no plan, so a crash in it would be invisible` — exit 1 |
| a suite file not in CASES | `exists but is not listed in CASES, so it never runs` — exit 1 |

**THE STRIP.** `data/` and `scenes/areas/` moved aside, whole ladder re-run:

```
=== 861 passed, 0 failed, 12 skipped ===
EXIT=0
SKIPPED: items_test: the authored catalogue is sound (no content in data/items) — 3 assertion(s) not run
SKIPPED: items_test: authored item names are translated (no content in data/items) — 1 assertion(s) not run
SKIPPED: transitions_test: every area has the required shape (no areas in scenes/areas) — 1 assertion(s) not run
SKIPPED: transitions_test: sheltering and the clock agree (no areas in scenes/areas) — 1 assertion(s) not run
SKIPPED: transitions_test: flag prefixes do not collide (no areas in scenes/areas) — 1 assertion(s) not run
SKIPPED: dialogue_test: the authored conversations are sound (no content in data/dialogue) — 2 assertion(s) not run
SKIPPED: npc_test: authored waypoints exist in an authored area (no areas or no schedules) — 1 assertion(s) not run
SKIPPED: path_actions_test: the authored actions are sound (no content in res://data/actions) — 2 assertion(s) not run
12 assertion(s) were skipped: this run covers less than a full one
check_content exit=0 · check_boundary exit=0 · check_budgets exit=0
Session ended after 1.3s — 0 warnings, 0 errors
```

Twelve assertions of 911, not a third: the migration turned per-item and per-waypoint loops into
one assertion over the whole set, so what a stripped run loses is smaller than what the demo used
to be named in. Restored, and `git status` showed no change to any file under `data/` or
`scenes/areas/`.

The widened boundary gate proved the same way: `&"item/rose_key"` planted in `items_test.gd` gave
`res://tests/unit/items_test.gd:16 names demo content 'item/rose_key'`, `FAIL — 2 boundary
violation(s)`, exit 1; removed, exit 0.

Full ladder on the restored checkout:

```
--headless --import                          # no SCRIPT ERROR, no Parse Error
--headless --quit-after 120                  # Session ended after 1.2s — 0 warnings, 0 errors
res://tests/test_runner.tscn --quit-after 400 # === 911 passed, 0 failed, 0 skipped === exit 0
tools/check_budgets.gd   PASS  exit 0
tools/check_content.gd         exit 0
tools/check_boundary.gd  PASS  exit 0 — 93 scripts over src/ and tests/
```

**A BUG THIS FOUND, and it is the fourth native-name collision in this project.**
**`ItemDb.reload()` had never called our function.** `Script` declares `reload()`, and `ItemDb`
as an identifier IS the GDScript object, so `ItemDb.reload()` dispatched to `Script.reload()` —
which reloads the script and resets its static variables. Behaviour coincided exactly with what
our `reload()` was written to do (clear the cache, rescan on next access), so nothing ever broke
and no test could see it. It surfaced only when `content_dir` was added: assigning it stuck, and
then `reload()` silently reset it to the default. Proved by putting a print in `_ensure_loaded()`
and watching `ItemDb.reload()` not reach it. All three registries now expose `rescan()`; every
call site — `tools/check_content.gd` included, so the validator's reload was a script reload too
— was updated. After `Area3D.priority`, `class_name Container` and `DictRead.get_name`, this is
the fourth. Gotcha 17 says check every name against the API dump, *static functions included*,
and it was right again.

**Unblocks:**

T1.4 (CI) — the ladder is now worth automating, because every rung of it can fail. A consuming
game can delete the demo on day one and keep rung 4. And `tests/unit/` is now a place a new
system's assertions can go without acquiring a dependency on the courtyard.

**Known gaps:**

- **The plan is a number a human maintains.** Add an assertion and the run fails until the number
  is bumped. That is TAP's trade and it is self-correcting — a stale plan fails loudly, naming
  the case and both numbers — but it is friction, and the first thing to reconsider if it starts
  getting in the way.
- **`ErrorWatch` counts only `ERROR_TYPE_SCRIPT`.** `push_error` from a deliberate negative-path
  test arrives as `ERROR_TYPE_ERROR` and would make the gate unusable within a day, so those are
  counted separately and not failed on. A real engine error of that type therefore still passes.
- **A cached `.tres` survives an edit.** `ResourceLoader` caches by path, so a case that edits a
  loaded resource must edit it back; `rescan()` hands back the same instance. `dialogue_test` does
  restore everything it touches, and its comment now says so honestly rather than claiming the
  reload is the reset.
- **`user://test_fixtures/` is left on disk** after a run. Harmless — the next `activate()`
  overwrites it and the default content root is restored either way — but nothing cleans it up.
- Assertions moved 921 → 911. The drop is aggregation, not lost coverage: named per-item and
  per-waypoint assertions became set-level ones that also cover content added later.

---

## 2026-08-26 — T1.2: the engine/demo boundary becomes a gate, and four leaks close

**Did:**

The boundary rule existed only as prose in `TEMPLATE.md`. It is now mechanical.

- `tools/check_boundary.gd` — new gate, rung 6 of the ladder. **FAILS if any file under `src/`
  names demo content.** The forbidden names are **derived, never listed**: every folder under
  `scenes/areas/`, the `id` of every `.tres` under `data/`, and each id's last segment, so
  `schedule/keeper` also forbids the bare `keeper`. Twelve names today, and it cannot go stale
  when content is added.
- `src/core/util/game_config.gd` — new. `GameConfig`, a pure reader of the `[game]` section of
  `project.godot`: `first_area()`, `first_spawn()`, `game_name()`, `game_slug()`. Depends on
  nothing.
- `project.godot` — new `[game]` section: `world/first_area="courtyard"`,
  `world/first_spawn="default"`.
- `src/systems/scene_director/director.gd` — `const FIRST_AREA := &"courtyard"` **deleted**.
  `start_new_game()` reads `GameConfig.first_area()` and refuses, before clearing anything, when
  it is empty.
- `src/core/log/log.gd` — the literal `Gulistan` gone from both the boot banner and the log file
  name; both now come from `application/config/name` through `GameConfig`.
- `src/systems/debug/{dev_capture,dev_probes,dev_stage}.gd` — argument parsing is now behind
  `OS.is_debug_build()`. Only the F12 hotkey was gated before.
- `src/systems/debug/dev_capture.gd` — **restored a missing `_settled()`**; see the bug below.
- `src/content/{items/item_db,dialogue/dialogue_db,npc/schedule_db}.gd` — "no items / no
  conversations / no schedules found" is **no longer a problem**. See the second bug below.
- `docs/NEW_GAME.md` — new. The strip-and-start checklist.
- `tests/unit/core_test.gd` — 11 assertions on `GameConfig`, comparing against `ProjectSettings`
  rather than against a literal, because a test asserting `first_area() == "courtyard"` would
  rebuild the leak it exists to prove is gone.

**Why:**

`TEMPLATE.md` already recorded the failure mode: `game_root.gd` once carried
`const FIRST_AREA := &"courtyard"` and it passed eight verification rungs, a budget checker, a
content checker, 900 assertions and an adversarial review, **because no rule forbade it.** A rule
only a human enforces is the rule that let that through.

**Three decisions worth writing down:**

1. **Comments are exempt; code is not.** Mechanically: a line whose first non-whitespace character
   is `#` is not scanned — the same definition `check_budgets.gd` uses. A `##` line saying
   `data/items/rose_key.tres must declare id = &"item/rose_key"` is *teaching by example*: it
   changes no behaviour, it is how the file-name-is-the-id rule is explained, and forbidding it
   would push the documentation into abstraction nobody can follow. A `const` changes behaviour.
   That is the whole difference. A **trailing** comment on a code line IS scanned, which is
   stricter than the rule needs — stricter is the safe direction for a gate.

   **What it cannot see, stated so nobody mistakes green for proof:** a name assembled at runtime
   (`"item/" + kind`); a demo name that appears in neither `data/` nor `scenes/areas/` — a
   waypoint marker like `north_arch`, a node name inside an area scene, a flag namespace invented
   in code; and anything outside `src/**/*.gd`, so the prefabs in `scenes/objects/` are unscanned.
   The exempt-directory count is *printed*, not swallowed.

2. **`src/systems/debug/` is exempt, and the exemption has a precondition the tool checks.**
   Those three files exist to drive the demo: `--give=item/rose_key` stages a photograph, and a
   probe that travelled to an abstract area would verify nothing. They are the development
   harness, not the engine. But an exemption granted to code a *player* could drive would be
   worthless, so `_check_debug_gate()` fails if any debug script defining `_parse_arguments()`
   loses its `OS.is_debug_build()` guard. The exemption and the condition it rests on live in one
   file. Fourteen demo names sit inside it today, counted and printed.

3. **The first area is a project setting, not an `@export`.** An `@export` on
   `scenes/boot/game_root.tscn` was the alternative and was rejected: `TEMPLATE.md` classifies
   `scenes/boot/` as engine, so that would have moved the leak rather than closed it.
   `project.godot` is already the one file a new game must edit, and the gate deliberately does
   not scan it.

**Connects:**

`Log` now depends on `GameConfig` — the first dependency the logger has ever had, and its header
says so. It is safe because `GameConfig` reads `ProjectSettings` and nothing else, so the
"everything may depend on Log; Log depends on nothing" invariant degrades to one edge that cannot
cycle. `Director.start_new_game()` is still the one place that knows what a new game is; it just
no longer knows *which* game. `dev_stage.gd`'s `--new-game` reports `GameConfig.first_area()`
instead of `Director.FIRST_AREA`.

The gate became its own tool rather than living in `check_content.gd`, which is where the brief
put it: the combined file came out at **252 of the 250 allowed code lines** and `check_budgets.gd`
refused it. The seam was already in the reasoning — `check_content.gd` validates that the *demo*
is well formed, `check_boundary.gd` validates that the *engine* does not know the demo exists —
and the new tool loads nothing, so it keeps working when the content it scans for has been
deleted, which is exactly the state a new game starts in. Fourth time the budget checker has
exposed a split that was already there.

**Two bugs found, neither by a static gate:**

1. **`dev_capture.gd` had failed to parse since the WP-13 merge, and the ladder said nothing.**
   The merge added `await _settled()` in `_soak_and_dry` without the function, so the whole file
   was dead — F12, `--shot`, `--time`, `--freeze-time` and `--weather` had all been broken for a
   package. Found by `--headless --import`, which prints
   `Parse Error: Function "_settled()" not found in base self`. **The boot rung still printed
   `0 warnings, 0 errors`**, because `Log` counts `Log.error` calls and an engine parse error is
   neither. New gotcha in `CONTEXT.md`. Fixed by adding the five-line `_settled()`, the third
   copy, for the reason already written in `dev_stage.gd`.

2. **A stripped template failed its own content gate on the first command of `NEW_GAME.md`.**
   `ItemDb`, `DialogueDb` and `ScheduleDb` each reported "no X found in ..." as a problem, so
   deleting `data/**` — step one of starting a new game — turned `check_content.gd` red. An empty
   folder is the *legal starting state* of a base template; a file that is present and does not
   load is the real error, and `_register` already reports that per file. Whether a game needs
   items is that game's question, not this base's. Removed from all three. Found by actually
   performing the checklist rather than writing it.

**Verified:**

Baseline before starting: 910 assertions.

Full ladder, on the restored demo:

```
$ "$G" --headless --import                                  # 0 SCRIPT ERROR / Parse Error lines
$ "$G" --headless --quit-after 120
17:45:31 [INFO ] [boot] Session ended after 1.2s - 0 warnings, 0 errors
$ "$G" --headless res://tests/test_runner.tscn --quit-after 400
17:45:42 [INFO ] [test] === 921 passed, 0 failed ===          exit 0
$ "$G" --headless --script tools/check_budgets.gd
95 files, 7742 code lines, 0 warnings, 0 violations   PASS    exit 0
$ "$G" --headless --script tools/check_content.gd     PASS    exit 0
$ "$G" --headless --script tools/check_boundary.gd    PASS    exit 0
```

**The gate bites.** Planted `const PLANTED_VIOLATION: StringName = &"courtyard"` at the end of
`src/core/util/layers.gd`:

```
$ "$G" --headless --script tools/check_boundary.gd
  !! res://src/core/util/layers.gd:32 names demo content 'courtyard' (from res://scenes/areas/courtyard)
FAIL - 1 boundary violation(s)                              exit 1
```

Removed it, restored the file from a copy, `git diff --stat` empty:

```
$ "$G" --headless --script tools/check_boundary.gd
PASS                                                        exit 0
```

**The debug-gate precondition bites too.** Deleted the `OS.is_debug_build()` guard from
`dev_probes.gd`:

```
  !! res://src/systems/debug/dev_probes.gd parses command-line arguments with no OS.is_debug_build() guard
FAIL - 1 boundary violation(s)                              exit 1
```

Restored, `PASS`.

**A deliberately broken assertion still exits 1.** Flipped `slug is not empty` to expect `false`:

```
17:41:05 [ERROR] [test] FAILED: slug is not empty - expected false, got true
=== 920 passed, 1 failed ===                                exit 1
```

**`NEW_GAME.md` was performed, not imagined.** Deleted every `.tres` under `data/`, both area
folders, pruned the CSV from 189 rows to 147, and set `world/first_area=""`:

```
  localization keys: 146
  item definitions: 0 - conversations: 0 - schedules: 0 - path actions: 0 - scenes scanned: 14
PASS                                                     (check_content,  exit 0)
  demo names derived: 0 - []
  src scripts scanned: 74 (res://src/systems/debug/ is exempt)
PASS                                                     (check_boundary, exit 0)
PASS                                                     (check_budgets,  exit 0)
17:44:28 [INFO ] [boot] Session ended after 1.2s - 0 warnings, 0 errors
$ "$G" --headless --quit-after 60 -- --new-game
17:44:41 [ERROR] [world] No first area - set game/world/first_area in project.godot
```

Everything restored afterwards; `git status` shows `data/`, `scenes/areas/` and `strings.csv`
unmodified.

**Windowed capture**, which is also the proof that `dev_capture.gd` parses again — `--shot`,
`--time` and `--freeze-time` could not have taken effect otherwise:

```
$ "$G" --resolution 960x540 --quit-after 90 -- --new-game --shot=<path> --shot-frame=70 \
      --time=18:40 --freeze-time
17:41:21 [INFO ] [test] --new-game requested 'courtyard'
17:41:21 [INFO ] [area] Area 'courtyard' ready (2 spawns, 9 interactables, 3 waypoints)
```

Looked at the PNG: the setting-driven first area, at dusk, with the clock readout reading
`Day 1 | 18:40 | Dusk` and an interaction prompt up. The boot banner now reads
`Project Gulistan 0.0.1 | Godot 4.7.2-stable (official) | headless | debug=true`, and the log file
is `project_gulistan_2026-08-26T17-36-20.log` — both from `project.godot`, neither from a literal.

**Unblocks:**

T1.3 (test fixtures). The boundary is now a gate rather than a promise, so the one remaining weld
— a third of the assertions naming demo content — is the last thing standing between the template
and a demo that can actually be deleted. T2.2 (consumer documentation) has its spine in
`NEW_GAME.md`.

**Gaps:**

- **The suite still cannot survive the demo being deleted.** Everything else on the ladder can;
  T1.2 ran it. T1.3.
- The gate reads text. It cannot see a computed id, a waypoint name, or anything outside
  `src/**/*.gd`. Written into the tool header so a green run is not mistaken for a proof.
- **A deliberately CRASHING test case has still not been proved to exit 1** — only a failing
  assertion has. Different path, still unhardened, still T1.3.
- The debug surface's release gate is verified by a text scan for `OS.is_debug_build()`, not by
  running a release export. An actual export run belongs with T1.4 or WP-15.
- `ui.menu.title` holds the game's *name* in a `ui.*` key — an engine key with a game-specific
  value. Called out in `NEW_GAME.md` rather than restructured; a `[game]`-driven title would mean
  the menu reading a project setting for a player-facing string, which is a bigger decision.

---

## 2026-08-26 — WP-07: path actions, and the difference between a refusal and a failure

**Did:**

The signature mechanic. Non-combat verbs you perform on a person, with a standing that gates
them and that they move.

- `src/content/npc/path_action.gd` — `PathAction`. Verb, label, a standing floor to be offered
  at all, a standing line to succeed at, and what it writes and says either way.
- `src/gameplay/interactables/path_action_point.gd` — `PathActionPoint`, an `Interactable`.
  One node per action.
- `src/gameplay/character/standing.gd` — `Standing`. A namespace over `Flags`, and nothing more.
- `data/actions/keeper_scrutinise.tres`, `keeper_barter.tres`, `scenes/objects/path_action.tscn`.
- Five new `InteractVerb`s and `RefusalReason.LOW_STANDING`.
- `tools/check_content.gd` validates every `.tres` in `data/actions`.
- `tests/unit/path_actions_test.gd` — 51 new assertions. 555 -> 606.
- `dev_probes.gd` split again, into itself plus `dev_stage.gd`.

**Why:**

**A refusal and a failure are different things, and keeping them apart is the whole design.**
A refusal happens BEFORE anything: the player is told why and nothing changes. A failure happens
AFTER committing: the action ran, it did not work, and it cost standing. An action that could
only refuse would be a lock with extra steps. An action that could only fail would give the
player no way to read the situation before spending. The interesting middle is where Octopath's
Inquire lives, and it needs both — so barter has three bands: refused below 1, committed and
failing at 1, committed and succeeding at 2.

**No dice.** `success_standing` is a threshold, not a probability. A random path action makes
the player save-scum, and a save-scummed mechanic is experienced as a slot machine rather than
as a relationship. If randomness is ever wanted it goes behind that one field and every
authored `.tres` stays valid.

**One node per action, and no menu.** An NPC offering three actions is three overlapping
`Interactable`s, which the sensor already ranks and Tab-cycles between — the exact case its
header describes. A path-action menu would be a second selection mechanism competing with the
first, with its own focus handling and its own screen, to solve a problem already solved.

**`once` applies to SUCCESS only.** A single early failure must not lock the player out of an
action forever with no way back, which is what `once` on any outcome would do. Asserted.

**Standing is a namespace over `Flags`, not a store.** It is exactly the kind of fact `Flags`
exists to hold: already saved, already announced, already dumpable. A second store would be a
second truth for one integer per person. It is keyed `standing/<who>` and NOT through
`PersistentState`, because that namespaces per area — right for a chest, wrong for a person:
the keeper who dislikes you in the courtyard must still dislike you in the hall.

**No fourth registry.** Unlike items, conversations and schedules, nothing ever looks a path
action up by id — it is only reached through the NPC that offers it, exactly as a chest reaches
its `ItemDefinition`s. So the note in `schedule_db.gd` about three being a pattern and four
being a problem does not fire, and no registry was written.

**One defect found, in WP-06's code:**

**The unreachable guard believed a single frame.** The keeper reported "cannot reach 'dais'" in
windowed runs and never in headless ones. A `NavigationAgent3D` recomputes its path
asynchronously, so the frame after a target moves — which for a WANDER activity is every few
seconds — it legitimately has no path yet and answers "unreachable" to a question it has not
finished thinking about. The guard now requires the answer to hold for thirty consecutive
physics frames, and a new target clears the accumulated evidence. Three windowed runs clean
where one in two failed before. This is the second time this guard has been wrong in the same
direction, which is itself the lesson: a question asked of an asynchronous system needs both a
delay before asking and a persistence test on the answer.

**Connections:**

`PathActionPoint` -> `Standing` -> `Flags` -> the save. `Interactable.attempt()` gives it the
refusal path and the interactor for free, so `requires_item` asks whoever is interacting rather
than a global inventory. `Events.notify_requested` carries the outcome line. The keeper's two
actions sit beside its `Speaker` on the same NPC, so one person now offers a conversation and
two verbs, selected between with the cycle key.

**Verified:**

```
--headless --import                                   clean
--headless --quit-after 120                           0 warnings, 0 errors
--headless res://tests/test_runner.tscn                606 passed, 0 failed, exit 0
--headless --script tools/check_budgets.gd            78 files, 6012 lines, 0 violations
--headless --script tools/check_content.gd            PASS, incl. 2 path actions
--headless --quit-after 2400 -- --round-trips=20      nodes 142 -> 142 (+0), memory +2 KiB
--headless --quit-after 5000 -- --npc-day             dais at 12:00, bench at 20:00
```

The content gate was proved by pointing an action's `failure_key` at a row that does not exist
and watching it fail, then restoring it.

**Three captures, examined, one per band**, taken with `--standing=keeper:N --stand-by=Keeper
--cycle=1 --interact=1`:

- **0 — refused.** `They do not know you well enough. (0 of 1)`. Standing unchanged at 0.
- **1 — committed and failed.** `They look at the basket, then at you, and move it to their
  other arm.` Standing 1 -> 0. The prompt still reads Barter, because a failed action stays
  on offer.
- **2 — committed and succeeded.** `They part with a handful of petals, and almost smile.`
  Standing 2 -> 3, and **the prompt has changed to "Observe — The Keeper's Hands"**, because
  barter is now `once`-done and the sensor has fallen back to the other action. The design
  visible in a photograph.

The first attempt at these three captures produced three identical images: all three outcomes
show the same prompt until the button is pressed, and the shutter was 250 frames after the
refusal message had already expired. The `--interact` flag and a corrected `--shot-frame` are
what made them different.

**Unblocks:**

WP-08's quests, which need a mechanic whose outcome is worth tracking, and WP-09's character
depth, where a skill would gate an action exactly as standing does now.

**Known gaps:**

Five verbs are declared and two are authored; `INQUIRE`, `GUIDE` and `SOOTHE` have keys and no
content. There is no UI listing what a person offers — you discover their actions by standing
next to them and cycling, which is honest for a skeleton and thin for a game. Standing is a
single number per person with no factions or groups behind it. Nothing decays. And an action
cannot yet give an item, only set a flag: `Inventory.add` from a path action is one field away
but nothing needed it yet.

## 2026-08-26 — WP-06: NPCs that keep a timetable, and eight defects an audit found

**Did:**

A navmesh baked from the geometry that is actually present, an NPC that walks to a named place
because the clock says so, and a schedule authored as data.

- `src/content/npc/` — `ScheduleEntry`, `NpcSchedule`, `ScheduleDb`. The third registry, and
  deliberately identical to the first two.
- `src/gameplay/character/npc_brain.gd` — `NpcBrain`. Reads a schedule for a waypoint NAME,
  resolves it against the area's `Waypoints/` node, hands the position to a `NavigationAgent3D`.
- `AreaRoot` bakes its own navmesh at load, behind the curtain, and reports the polygon count.
- `scenes/characters/npc.tscn` — reuses `CharacterVisual` unchanged, and carries a `Speaker`
  child, so an NPC is a conversation partner with no new code at all.
- `data/schedules/keeper.tres`, two `Waypoints/` nodes, `GameEnums.NpcActivity`.
- `dev_capture.gd` split into itself plus `dev_probes.gd`; `--npc-day`, `--npc-storm`,
  `--npc-settle` added.
- `tests/unit/npc_test.gd` — 74 new assertions, plus 17 more covering the fixes below.
  460 -> 555.

**Why:**

**A schedule names a waypoint, not a position.** Coordinates would be authored against one
area's geometry, silently wrong the moment a bench moved, and unusable by a second NPC. A name
resolves at runtime, so moving the marker moves everyone who goes there.

**There is no `until_hour`.** An entry runs until the next one begins and the last wraps past
midnight, so a day is always completely covered and two entries cannot disagree about who owns
14:00. `entry_for_hour` falls back to the LAST entry when the hour precedes every block, which
is what makes a night shift work — asserted for all twenty-four hours.

**The navmesh is baked at load, not checked in.** A committed `NavigationMesh` goes stale the
moment someone moves a wall, and a stale navmesh fails silently. Baking from the geometry that
is present cannot disagree with it, and the cost is paid behind the same black curtain that
already hides the shader warm-up.

**Arrival is the agent's answer, not a distance check.** `is_navigation_finished()` accounts for
a target that is unreachable; a hand-rolled `distance < 0.5` reports "not there yet" forever when
a waypoint ends up inside a wall.

**Three defects found while building it, each by running the engine:**

1. **The navmesh baked EMPTY and said nothing.** `SOURCE_GEOMETRY_ROOT_NODE_CHILDREN` parses the
   children of the `NavigationRegion3D`, which has none — the terrain is a sibling. An empty
   navmesh means every NPC concludes it has already arrived, everywhere, and an empty bake takes
   0ms, so "baked in 0ms" is exactly what the failure looks like. Now group-sourced, and the
   log line reports the POLYGON COUNT and errors at zero.
2. **The navmesh bridged a step the body cannot climb.** `agent_max_climb` was 0.55 and the dais
   is 0.4 high, so the bake connected the ground to the dais top — but `move_and_slide()` has no
   step-up at all, so the NPC walked into the riser and stopped while the agent insisted it had
   not arrived, with no error anywhere. This game has no jumping and authored vertical movement,
   so the climb limit is now BELOW anything the body cannot manage and waypoints sit on the
   ground.
3. **My own reachability guard fired before the navigation map had synchronised**, and acted on
   the answer: an unsynchronised map reports everything unreachable, and the guard then parked
   the NPC at `get_final_position()`, which is the origin. It now waits for a decision and for a
   non-empty path before believing the answer.

**Eight more defects, from an independent adversarial review of WP-01 to WP-05.** Reviewing code
that has already passed every gate is worth doing, and this is the evidence:

1. **A hard soft-lock in dialogue.** `advance()` asked `_node.has_choices()` — the AUTHORED array
   — while the screen drew `available_choices()`. A node whose every choice fails its condition
   therefore rendered a box with no buttons that would not advance, could not be escaped
   (`closes_on_cancel` is false for a conversation, on purpose) and held the player's and the
   sensor's `&"dialogue"` tokens forever. Killing the process was the only way out. `advance()`
   now reads the filtered list and falls through, which ends the conversation and returns
   control — the same recoverable behaviour a dangling link already had.
2. **A non-`Node3D` area root left the curtain black permanently.** That failure path returned
   without lifting the fade, with the previous area already freed and `current_area_id` empty, so
   not even `reload_current_area()` could recover. Every failure path now goes through
   `_abandon()`, which lifts the curtain on the way out.
3. **A failed load left "Loading" pinned over the game for the rest of the session**, because the
   indicator hid only on `area_entered`. It now hides when the curtain lifts, which every path
   out of a transition does.
4. **A refused transition left a save's position override armed for the NEXT one.** Load a save
   whose area was renamed, then walk through any door, and the player is placed at coordinates
   authored for a different area — inside geometry, or outside the level. Cleared on every path
   that does not place the player.
5. **The loading readout could never appear during the boot load** — the one load, on a cold
   cache, that most needs it — because it showed only on `area_unloading`, which the first load
   does not emit. Progress now shows it as well as updating it.
6. **Nothing closed screens on an area change; `UiRoot.close_all()` was dead code** called only by
   tests. Travel does not lock the player, so a conversation opened during the 0.35s fade-out
   kept running over the newly loaded area with its speaker already freed. Same shape as WP-04's
   prompt-survives-an-area-change bug, one layer up. `UiRoot` now unwinds on `area_unloading`.
7. **Choice buttons and `choose(index)` indexed two different lists.** A dialogue box deliberately
   leaves the world running, so a flag written while it is open can hide an option and shift
   every index between the frame a button was built and the frame it was pressed — and the player
   takes a branch they did not pick, firing its effect. The UI now calls `take(choice)` with the
   object it actually drew, and a choice that has left the offer is REFUSED rather than resolved
   to a neighbour.
8. **`InteractionSensor._on_availability_changed` swapped `_current` without resetting the hold**,
   so a 1.5s hold on a slow chest carried over to an adjacent object that became available
   mid-hold and fired it on the next physics frame.

Findings 1, 6 and 7 have assertions. 2 to 5 are single-branch fixes in `Director` and the
indicator whose failure paths need a broken area scene to reach, which is a fixture this suite
has no way to build; they are covered by reading and by the boot run, and that is stated here
rather than implied.

**Connections:**

`Clock` -> `hour_passed` -> `NpcBrain.decide_for_hour`. `ScheduleDb` supplies the waypoint name;
`AreaRoot`'s `Waypoints/` node supplies the position; `NavigationRegion3D` supplies the path.
`PersistentState` stores the waypoint, so an NPC's whereabouts ride the save machinery that
already exists — keyed `obj/<area>/<npc>/waypoint`, so two NPCs cannot overwrite each other and
a second area cannot overwrite the first. The NPC's `Speaker` child emits
`Events.dialogue_requested` exactly as the standalone one did.

**Verified:**

```
--headless --import                                   clean
--headless --quit-after 120                           0 warnings, 0 errors
--headless res://tests/test_runner.tscn                555 passed, 0 failed, exit 0
  with one assertion deliberately broken               554 passed, 1 failed, exit 1
--headless --script tools/check_budgets.gd            73 files, 5638 lines, 0 violations
--headless --script tools/check_content.gd            PASS, incl. 1 schedule
--headless --quit-after 2400 -- --round-trips=20      nodes 135 -> 135 (+0), memory +9 KiB
```

**A whole day**, `--npc-day`, which is how the schedule criterion is measured — no assertion can
drive a navmesh, because `TestCase.run()` is synchronous and pathing needs physics frames:

```
06:00  Keeper   wants gate_post  WANDER   0.00m away  arrived
09:00  Keeper   wants gate_post  WANDER   0.00m away  arrived
12:00  Keeper   wants dais       WANDER   0.47m away  arrived
15:00  Keeper   wants dais       WANDER   0.47m away  arrived
20:00  Keeper   wants bench      SLEEP    0.48m away  arrived
23:00  Keeper   wants bench      SLEEP    0.48m away  arrived
02:00  Keeper   wants bench      SLEEP    0.48m away  arrived
```

02:00 resolving to the bench is the midnight wrap working: the keeper's day starts at 06:00, so
the small hours belong to the previous evening's block rather than to the morning's.

**Thirty NPCs**, `--npc-storm=30`: `16.598 ms/frame with 1 NPC, 16.675 with 31 (+0.077)`. The
floor is the 60Hz physics tick, and thirty more NPCs move it by less than a tenth of a
millisecond. Both numbers are printed rather than asserted against a threshold, because a
threshold picked on this machine would mean nothing on another.

**Two captures, examined.** At 12:30 the keeper stands at its dais post offering "Speak — The
Garden-Keeper"; at 21:30 it has walked to the bench and is lit by the west lantern. The first
attempt had it standing inside the player, because the dais waypoint was 1.3m from the spawn
marker; moved, and re-shot.

**Unblocks:**

WP-07's path actions, which need an NPC to act on, and WP-08's quests, which need one to talk to
across a schedule. `CharacterVisual` is now proven shared between the player and NPCs unchanged,
which was the claim in its header and is now a fact.

**Known gaps:**

An NPC cannot travel between areas — a schedule names a waypoint and the waypoint must be in the
area the NPC is standing in, so a keeper who goes indoors at night is not expressible yet.
`check_content.gd` pools waypoint names across all areas for exactly this reason, and says so:
it can catch a name that exists nowhere, not an NPC in the wrong area for its schedule. Wander is
a random offset on a timer, not a behaviour tree, and level-of-detail for offscreen NPCs is
deferred as the manifest says. NPCs do not collide with the player or with each other, which
keeps them from getting stuck and lets them overlap. And the navmesh is rebaked on every area
entry; at 25-42ms for these two areas that is invisible behind the curtain, but a large area will
eventually want a checked-in bake plus a staleness check rather than an unconditional rebake.

## 2026-08-26 — WP-13: weather you can see, and the leak the Dummy audio driver leaves behind

**Did:**

`Weather` had published a kind, a blend and an intensity since Phase 0, and the only thing
that had ever read them was one fog-density multiplier. It is now visible.

- `src/systems/weather/wetness_model.gd` — `WetnessModel`. A pure `RefCounted`: one 0..1 that
  rises over eight seconds of rain and falls back over twenty-six. No node, no material, no
  autoload.
- `src/gameplay/world/precipitation.gd` — `Precipitation`. One `GPUParticles3D` per kind that
  builds its own mesh, process material, draw material and — for snow — its own soft flake
  texture from a radial `GradientTexture2D`. Nothing authored, nothing loaded.
- `src/gameplay/world/weather_visuals.gd` — `WeatherVisuals`. The listener that was missing.
  One node per area; it owns the `MIX` table that says what each kind looks like, follows the
  player, cross-fades across a blend, steps the wetness and sets the ambience levels.
- `src/gameplay/world/surface_wetness.gd` — `SurfaceWetness`. Darkens and clearcoats an
  area's materials as they soak, on private duplicates.
- `src/systems/audio/ambience_bed.gd` — `AmbienceBed`, reachable as `Audio.beds`. Named
  layers, each at its own level, on procedurally generated filtered noise.
- `dev_capture.gd` gains `--wet=<0..1>` and `--dry-for=<seconds>`.
- Nine localization keys: `weather.*` per kind, plus `notify.weather.turns`.
- `tests/unit/presentation_test.gd` — 47 new assertions. 460 -> 507.

**Why:**

*Why the wetness model is a separate pure object.* Everything else about the weather can be
computed from Weather's state in one frame. Drying cannot — "it stopped raining forty seconds
ago" is memory, and memory is the part that drifts. Gotcha 10 says `TestCase.run()` is
synchronous, so a node that only dries in `_process` could never be asserted on; a
`RefCounted` can be stepped a thousand simulated seconds inside one test.

*Why nothing is authored.* Art is deferred indefinitely. A rain texture would be a dependency
this project has refused to take on, so the mesh is a quad and the flake is a gradient. It
also means the three emitters cannot drift apart in an inspector.

*Why `Precipitation` is told a weight instead of reading Weather.* An emitter that polled the
weather would be a second place the rules live, and the two would disagree the first time a
cross-fade was half done. Same split as Weather and EnvironmentDriver, one level down.

*Why `SurfaceWetness` duplicates its materials.* The terrain materials are sub-resources of
the area scene, and a sub-resource is shared across every instantiation of it. Writing
roughness onto one would leave the courtyard wet after an unload and reload on a clear day —
and would follow the player into any other area using the same material.

*Why a clearcoat and not just darkening.* The first captures came back reading as "in shadow"
rather than "wet". A low roughness only shows where the sun's mirror angle points, and on a
flat courtyard under a fixed camera it mostly does not. A clearcoat is literally a thin smooth
film over the surface; it reflects the sky, which is visible from any angle.

**Connects:**

`WeatherVisuals` reads `Weather.current/target/blend/intensity/is_wet/sheltered` and writes to
`Precipitation`, `SurfaceWetness` and `Audio.beds`. Nothing flows the other way — `Weather`
still MUST NOT render, and gained no line. The toast goes out on `Events.notify_requested`
like every other announcement, so `Weather` still does not know a screen exists. `AreaRoot`
already set `Weather.sheltered` for interiors and that now genuinely stops the rain.

**Verified:**

- `--headless --import` — exit 0, clean. Run twice; the first pass is where the five new
  `class_name` globals get registered, and every parse error before it was gotcha 1.
- `--headless --quit-after 120` — `Session ended after 1.0s — 0 warnings, 0 errors`, exit 0.
- `--headless res://tests/test_runner.tscn --quit-after 150` — **507 passed, 0 failed**,
  exit 0, no leaked instances.
- A deliberately broken assertion in `presentation_test.gd` → `506 passed, 1 failed`, exit 1,
  naming the assertion and its line. Reverted.
- `--headless --script tools/check_budgets.gd` — 73 files, 5,625 code lines, 0 warnings,
  0 violations, exit 0.
- `--headless --script tools/check_content.gd` — 92 localization keys, PASS, exit 0.
- **Seven windowed captures, every one opened and looked at**, all at
  `--resolution 960x540 --time=13:00 --freeze-time --shot-frame=40`:
  - `CLEAR` — bright green grass, warm orange dais, cream walls, no particles.
  - `RAIN --wet=1.0` — fine pale streaks across the whole frame, everything greyer, ground
    visibly darkened.
  - `STORM --wet=1.0` — markedly denser rain than `RAIN`, pale wind motes blowing through it,
    darker again. Unmistakably a third image and not a brighter second one.
  - `SNOW` — soft round flakes at varied sizes and depths, ground still dry, which is right:
    `is_wet()` is RAIN and STORM only.
  - The dry-out, three frames, all `CLEAR` so the ONLY variable is the wetness:
    `--wet=1.0` / `--wet=1.0 --dry-for=13` / `--wet=1.0 --dry-for=40`, logged as wetness
    `1.000` / `0.500` / `0.000`. Dark olive grass and dull walls -> a midpoint -> bright green
    grass and cream walls indistinguishable from the plain `CLEAR` capture. Indistinguishable
    by eye, not byte-identical: the two PNGs hash differently, as two renders of one frame
    do. That drying restores the *exact* authored albedo and roughness is proved by an
    assertion instead, which is the right tool for an exactness claim.
  - `STORM --goto=lantern_hall` — not one drop indoors, interior lighting untouched.

**One real bug and one engine trap, both found by running it:**

1. **`SurfaceWetness` was driven before it had collected anything.** `WeatherVisuals` sits
   under `Environment` and the wetness node under `Terrain`, so the driver's `_ready` ran
   first and called `apply()` at an empty list. Because `apply()` skips a value that has not
   moved, arriving in an area mid-downpour would have shown a dry courtyard until the wetness
   happened to change — and it does not change once it has reached its target. Now `apply()`
   records what was wanted and `_ready` paints it after collecting. Found by reading the boot
   log's line ordering, not by a failing assertion.
2. **Every `play()` against the Dummy audio driver leaks.** The test suite started reporting
   `6 ObjectDB instances were leaked at exit`: one `AudioStreamPlaybackWAV` per `play()` call
   — four — plus the two generated streams they held. The AudioServer releases a stopped
   playback on the NEXT MIX, and `--headless` quits before there is one. Stopping the players
   and nulling their streams in `_exit_tree` does nothing, because the server owns the
   playbacks, not the players. `AmbienceBed.is_audible()` now checks
   `AudioServer.get_driver_name()` — measured as `Dummy` headless and `WASAPI` windowed, not
   assumed — and skips playback it could not be heard through anyway. The levels are the real
   state and are what the assertions read.

**Unblocks:**

Footstep surfaces, which need to know the ground is wet and now can, from the same
`Weather.is_wet()` the visuals key off. Any area that wants weather needs one node and no
code. A fourth and fiftieth weather kind need a row in `MIX` and a CSV line, and the suite
fails if either is missing.

**Known gaps:**

`dev_capture.gd` is at 238 of its 250 code lines and is the next file to need splitting —
WP-14 owns it. The ambience is two layers of filtered noise, not sound design; there is still
no real audio in the project. Rain does not collide, so it falls through the terrace roof and
the arch — `ParticleProcessMaterial.collision_mode` is the seam and it was left off because it
costs a depth pass for a placeholder scene. Nothing splashes where a drop lands. Wetness is
per area and not saved, so walking out of a downpour into the hall and back resets the soak;
that is a `SaveSystem.register` away if it ever matters. This package added 562 code lines
against the board's ~500 guideline: 434 production (406 in five new files, 4 in
`audio_director.gd`, 24 in `dev_capture.gd`) and 128 of test.

## 2026-08-26 — WP-12: the menus, and the game stops booting into an area

**Did:**

Five menus, on the screen stack WP-02 built and never had a real consumer for.

- `src/ui/screens/menu_screen.gd` — `MenuScreen`. A titled column of focusable rows: panel,
  title, scroller, hint, and `add_row` / `add_note` / `refresh` / `focus_first` / `depart` /
  `push`. Written once, so the five menus below are 43 to 150 code lines each.
- `src/ui/screens/main_menu_screen.gd` — new game, continue, load, settings, controls, quit.
- `src/ui/screens/pause_menu_screen.gd` — resume, save, load, settings, controls, main menu,
  quit, over a status line naming the area and the playtime.
- `src/ui/screens/settings_screen.gd` — all 23 rows in `Settings.DEFAULTS`, **generated from
  the dictionary**, with bools, named enums, choice lists, percentages and multipliers, plus a
  reset row. Press a row or push left/right on it.
- `src/ui/screens/save_screen.gd` — the six slots with their headers, in either direction.
- `src/ui/screens/rebind_screen.gd` — every `Actions.REBINDABLE`, its key and its pad button.
- `src/systems/input/key_bindings.gd` — `KeyBindings`. Overrides in `user://input.cfg`, stored
  as integer codes. `Actions` gained `reset_bindings()` and one `KeyBindings.load_all()` call.
- `Director.start_new_game()` and `SaveSystem.latest_slot()`.
- `Events.main_menu_requested` and `Events.quit_requested`.
- `ScreenKeys` gained the pause binding, `menu_for()`, and `unwind()`.
- **`GameRoot` no longer requests an area.** It emits `main_menu_requested` and lifts the
  curtain. `FIRST_AREA` moved to `Director`, where area knowledge already lives.
- 86 CSV rows. `tests/unit/menus_test.gd` and `tests/unit/options_test.gd`: 257 new
  assertions, 460 -> 717.

**Why:**

`Settings` had declared 23 rows since Phase 0 with nothing reading seventeen of them, and the
board's own note said they existed "so the settings screen has something to bind to". So the
settings screen is **generated from `DEFAULTS`** rather than hand-listed: adding a setting is
one line in `settings.gd` and one CSV row, and there is no second list to fall out of step with
the first. The cost is that every row label is a computed key no text scan can find, which is
why `options_test.gd` loops `DEFAULTS` and asserts each one translates — the same trick the
prompt's verb keys use.

Rebinding lives in its own file because `Actions` owns the action NAMES and their DEFAULTS,
which is ADR-0003's whole point, while what one player has since changed belongs to their
machine like `Settings` does. Folding it in would also have taken `actions.gd` from 83 code
lines to 148 of its 150 — the shape of a file about to be given an exemption.

`MenuScreen` exists because the five menus differ only in what their rows say. That is also the
whole of "playable on a gamepad": a `VBoxContainer` of `Button`s already answers `ui_up`,
`ui_down` and `ui_accept`, so no screen in this package contains a cursor, a selected index, or
a direction-key handler.

**Connects:**

Nothing new was added to make the menus work. `pauses_world` and `UiRoot` do the pause; the
player takes its own `&"ui"` token on `Events.ui_mode_changed`; `is_gameplay_input_allowed()`
stays the one truth and no boolean joined it. No autoload was added.

The one genuinely new wire is that **`ScreenKeys` now closes the stack on
`area_change_requested`**, so no screen ever calls `close_all()` on the stack it is standing on.
That is what lets a menu row start a new game or restore a save and simply stop: the transition
it asked for is what dismisses it. It also fixes a latent bug nobody had hit — the inventory
open when a door fired would have survived the transition.

`GameRoot` is `core` and may not name a `ui` class, so the boot path is a bus signal, exactly
like `dialogue_requested`. The pause menu's "Main Menu" row uses the same one.

**Verified:**

```
G=/c/Rai/softwares/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
"$G" --headless --import                                       # exit 0, no errors
"$G" --headless --quit-after 120                               # 0 warnings, 0 errors
"$G" --headless res://tests/test_runner.tscn --quit-after 250  # 717 passed, 0 failed
"$G" --headless --script tools/check_budgets.gd                # 76 files, 0 violations
"$G" --headless --script tools/check_content.gd                # PASS, 167 keys
"$G" --headless --quit-after 400 -- --new-game --cross-area-save   # WP-04 still holds
```

A deliberately broken assertion in `options_test.gd` reported
`FAILED: nothing is listening yet` and exited **1**.

Four windowed captures at 1280x720, each one actually looked at:
`--shot=... --shot-frame=40 --freeze-time` for the main menu, and
`--new-game --open-menu=pause` / `pause,settings` / `pause,controls` for the rest.

**A REAL-INPUT PROBE, added to `dev_capture.gd`, run windowed, read, and removed.** Gotcha 15:
`TestCase.run()` is synchronous, so no assertion can press a key. The probe fed real
`InputEventAction`s and a real `InputEventKey`, pressing AND releasing each in separate frames
because a `Button` acts on release. Its log, verbatim:

```
PROBE start: depth 0, gameplay allowed true
PROBE pause key -> top 'pause', depth 1, tree paused true
PROBE down x2 + accept -> top 'settings', depth 2
PROBE focused row 'video/bloom' = Off
PROBE ui_right -> 'video/bloom' = On
PROBE escape -> top 'pause', depth 1
PROBE controls open, first row: Move forward  —  W  /  Joypad Button 11 (D-pad Up)
PROBE row pressed, listening on 'move_up'
PROBE after K: listening '', row: Move forward  —  K  /  Joypad Button 11 (D-pad Up)
PROBE reset, row back to: Move forward  —  W  /  Joypad Button 11 (D-pad Up)
```

That line about the pad button surviving a keyboard rebind is the point of the whole
`KeyBindings` design, and it is the only place it is visible.

**Three bugs the engine caught that no static gate could:**

1. **A menu backed out of had no focused row, and a gamepad then did nothing at all.** Focus
   follows a sub-screen when one opens and does not come back on its own. The probe found it:
   the rebind half of the run could not reach the controls screen, because `ui_down` and
   `ui_accept` had nothing to act on. `UiScreen._opened` is documented as "each time the screen
   reaches the top of the stack" and `UiRoot` only ever called it once — so `_close` now
   notifies the screen it revealed, which is what that docstring always promised.
2. **Two translucent screens stacked let the lower one print through the upper one.** A capture
   showed the pause menu's status line running through the settings screen's first heading.
   Every screen dims rather than blanks on purpose, so `UiRoot._settle` now hides a covered
   screen along with disabling it — stack business, derived in one place.
3. **`InputEventJoypadButton.as_text()` prints every console's name for a button** — "Joypad
   Button 2 (Left Action, Sony Square, Xbox X, Nintendo Y)" — sixty characters that ran off the
   side of the controls screen and grew a horizontal scrollbar under it. `KeyBindings` now keeps
   the first name only, and no menu scrolls sideways.

**Unblocks:**

WP-08's journal and WP-11's map are `MenuScreen` subclasses and a row in `ScreenKeys.menu_for`.
WP-14's debug console has a screen contract to sit on. WP-15's accessibility pass has somewhere
to put its options, and every one of them already has a row.

**Known gaps:**

- **Thirteen settings still have no runtime consumer.** They can now all be seen and changed
  and they persist, but bloom, shadows, tilt-shift, camera shake, reduce-motion, high-contrast
  prompts, subtitles, hold-to-confirm, text scale, render scale, autosave and
  show-interact-hints are read by nothing yet. That is WP-13 and WP-15 work, not menu work.
  Ten do have consumers: the five volumes, `text_speed`, `run_is_toggle`, and the three video
  rows `Settings._apply_display` acts on.
- **The language row cycles one locale, because one locale is loaded.** Changing it stores the
  value and nothing calls `TranslationServer.set_locale`. Phase 2's runtime-language criterion
  is still open.
- **Rebinding does not warn about a duplicate.** Binding K to two actions is accepted silently.
- **`Actions.JUMP` is listed on the controls screen and this game has no jumping.** The action
  exists, so the screen shows it; pruning `REBINDABLE` is an ADR-0003 decision, not a menu one.
- **"Main Menu" does not unload the area.** It leaves it loaded behind an opaque, world-stopping
  screen, and the next New Game or Continue replaces it through the ordinary guarded transition.
  Deliberate: freeing it from under a menu would empty `Director.current_area_id`, so the next
  transition would believe it was the session's first and skip its fade-out.
- **This package is over the board's size guidance**: 11 files and roughly 700 new code lines
  against "about 8 files or 500". It was landed whole rather than split because the five menus
  share one base and one CSV block, and a half-landed menu set is a game with no way back to
  the main menu. Reported here rather than rounded down.

---

## 2026-08-26 — WP-05: dialogue, and a comma that had been eating text since WP-01

**Did:**

The largest unproven system. A conversation format, a runner, and the first screen in this game
that does not stop the world.

- `src/content/dialogue/` — `DialogueChoice`, `DialogueNode`, `Conversation`, `DialogueDb`.
  Data only; none of them touches an autoload, so `tools/check_content.gd` can still load them
  under `--script`.
- `src/systems/dialogue/dialogue_runner.gd` — `DialogueRunner`. Picks the next node, tests
  conditions, applies effects, announces lines. A component, not an autoload.
- `src/ui/screens/dialogue_screen.gd` — `DialogueScreen`. `pauses_world = false`,
  `closes_on_cancel = false`, typewriter reveal, focusable choices.
- `src/gameplay/interactables/speaker.gd` — `Speaker`. Names a conversation id and emits.
- `Events.dialogue_requested`, `GameEnums.FlagTest`, `GameEnums.FlagWrite`.
- `data/dialogue/gardener.tres` — five nodes, four choices, one branch on a flag.
- `tests/unit/dialogue_test.gd` — 46 new assertions. 414 -> 460.
- `tools/check_content.gd` now validates conversations, and catches unquoted CSV commas.

**Why:**

**A closed set of comparisons, not an expression language.** `FlagTest` has six values and
`FlagWrite` has five. The moment a conversation can contain an expression it needs a parser,
error reporting and a sandbox, and the authored `.tres` stops being reviewable in a diff. When
six comparisons are genuinely not enough, the honest move is a seventh, not a grammar.

**Nodes are an ordered array and the runner falls through.** The entry point is the first node
whose condition passes, not `nodes[0]`, and a skipped node falls through to the next in authored
order. That makes the commonest shape in the game — "if we have met, greet me differently" — two
nodes in sequence with no wiring at all. Lookup by id still exists for `next_node` and
`target_node`, but order is what a writer edits and an array is what diffs cleanly.

**Effects fire on arrival, not departure**, so a node has the same consequence however it was
reached. That is why a choice carries a condition but no effect.

**A failing choice is omitted, not shown disabled** — the opposite of how a locked gate behaves,
deliberately. A gate you cannot open teaches you there is something to come back for; a reply
you cannot give teaches you only that the writer thought of it. `choose(index)` therefore
indexes what is on screen, not the authored array, and there is an assertion for exactly that
because indexing the wrong one silently takes the wrong branch.

**`Speaker` goes through the bus.** It is in the gameplay layer and a dialogue box is in the ui
layer, and dependencies here point downward only. The first draft of this file reached for
`UiRoot` and `DialogueScreen` directly; that is a layer violation, so it now emits
`Events.dialogue_requested` and stops, exactly as `AreaDoor` emits `area_change_requested`
rather than loading an area itself. `ScreenKeys` listens, because it is already the one place a
thing becomes a screen.

**A conversation is not saved, and that is a decision.** Persisting a position means writing a
node id into the save file, which makes every node id in every `.tres` a permanent public
identifier: rename one and old saves load into a position that no longer exists. So the save
section exists, is always empty, and logs a warning naming the conversation it discarded. A save
taken mid-conversation reloads with the conversation over and control returned — recoverable and
obvious, where the alternative fails silently, later, in someone else's save file. That is the
"or explicitly refuses to be saved mid-conversation" half of the exit criterion, chosen on
purpose over the other half.

**A defect from WP-01, found by a capture:**

`object.lever.gate.on` read `The lever gives with a heavy clack. Somewhere north, iron shifts.`
with no quotes, so the CSV parser cut it at the comma and the lever's toast had said
`Somewhere north` for three packages. Nothing caught it: the key still resolved, `tr()` still
returned a string, and the line quietly lost its second half. `talk.gardener.menu` had the same
fault, which is how it surfaced — the first dialogue capture showed `Well? Ask` where the line
reads `Well? Ask, or do not.` Both rows are quoted now, and `check_content.gd` fails any row
that parses to more than two columns. Proved by adding a bad row and watching the gate bite.

**Connections:**

`Speaker` -> `Events.dialogue_requested` -> `ScreenKeys` -> `UiRoot.open(DialogueScreen)` ->
`DialogueRunner.begin()`. The runner emits `Events.dialogue_started`, which
`PlayerController` and `InteractionSensor` have listened for since Phase 0 — each takes its own
`&"dialogue"` token, so nothing in this package locks anybody. `DialogueDb` reuses
`ItemDb.resource_paths()` rather than copying it, so the export-time `.remap` handling has one
implementation. Conditions read `Flags`; effects write `Flags`; nothing else in the package
touches either. `gameplay/text_speed` gets its first consumer since it was declared.

**Verified:**

```
--headless --import                                   clean
--headless --quit-after 120                           0 warnings, 0 errors
--headless res://tests/test_runner.tscn                460 passed, 0 failed, exit 0
  with one assertion deliberately broken               459 passed, 1 failed, exit 1
--headless --script tools/check_budgets.gd            67 files, 5063 lines, 0 violations
--headless --script tools/check_content.gd            PASS, incl. 1 conversation, 83 keys
```

**Captured and looked at**, three times. The first showed the truncated line and the third of
three choices clipped off the bottom edge — the box is bottom-anchored, so anything that does
not fit is simply gone, and it was sized from the common case instead of the worst one. Height
went 260 -> 380 and the CSV rows were quoted. The third capture shows the full line, all three
choices, the first focused, and the courtyard still lit and running above the box.

**The real input path**, proved with a temporary probe per gotcha 15 and then removed:

```
TEMP target=Gardener locked=false
TEMP after INTERACT: depth=1 node=greet_first locked=true suspended=true
TEMP world paused=false clock ticking=true
TEMP after advance: node=menu choices=3
TEMP focus=Who are you?
TEMP after choosing: node=who met=true
TEMP after end: depth=0 locked=false suspended=false
```

`world paused=false, clock ticking=true` is the line that matters: this is the first screen to
exercise the OVERLAY path `UiRoot` has had since WP-02, and it is the first proof that the
distinction between OVERLAY and MODAL was worth building two packages early.

One probe artifact worth recording: a synthetic `ui_accept` press alone never fires a `Button`,
because `BaseButton` acts on RELEASE by default. The probe has to send both. That is a fact
about probes, not a defect.

**Unblocks:**

WP-06's NPCs, which need something to say before they are worth animating, and WP-08's quests,
which need a conversation that can set a flag. `Speaker` is already the shape an NPC's talk
component will take. The overlay path is now walked by something real, so WP-12's menus can
assume it works.

**Known gaps:**

One condition and one effect per node. The seam is `_apply_effect` in the runner plus one field
becoming an array, and no authored `.tres` is invalidated by that change — but it is a real
limit and a conversation that wants "set two flags" cannot say so today. No portraits: the
format has a `speaker_key` and no portrait field, because art is deferred and a field nothing
reads is a guess. No barks, no auto-advance, no history log, no skip-all. The reveal speed is
one setting and one constant; a per-line pause or emphasis would need markup the format does not
have. And a conversation still cannot be entered from anything but a `Speaker` — a trigger
volume that starts a conversation would work today by emitting the same signal, but nothing
does it yet.

## 2026-08-26 — WP-04: a second area, and three bugs only a second area could find

**Did:**

`Director` has swapped two areas. It was written, guarded and logged in Phase 0 and had never
actually done the thing it exists for.

- `scenes/areas/lantern_hall/lantern_hall.tscn` — an interior. `sheltered = true`,
  `follow_clock = false`, its own lanterns, open toward the camera.
- `src/gameplay/interactables/area_door.gd` — `AreaDoor`, the one object that asks to travel.
  It emits `Events.area_change_requested` and does nothing else.
- `src/ui/hud/loading_indicator.gd` — the only thing in the game drawn ABOVE `ScreenFade`.
- `Events.area_load_progress(area_id, ratio)`, emitted from the load loop that was already
  collecting the number and throwing it away.
- `Director.WARM_UP_FRAMES` — the curtain is held three frames after the area enters the tree,
  so shader compilation happens behind black.
- `EnvironmentDriver` gained an Interior group.
- `dev_capture.gd` gained `--round-trips=<n>`, `--cross-area-save` and `--goto=<area>`.
- `tests/unit/transitions_test.gd` — 44 new assertions. 370 -> 414.

**Why:**

**A door names an id and nothing else.** It does not load, fade, or place the player. Every
transition goes through one guarded path, and a door that ran its own would be the start of a
second, unguarded one — which is how two doors firing at once leaves two areas in the tree.

**The loading indicator is the one exception to gotcha 12.** `ScreenFade` must be the last child
of `UILayer` so the curtain covers every screen. The indicator has to be legible *while* the
curtain is up, so it is the single node placed after it. Child order is draw order, and that
ordering is the whole mechanism.

**Twenty round trips is a RUN, not an assertion.** `TestCase.run()` is synchronous and a threaded
load needs frames. So the criterion is measured by `--round-trips=20`, which also fires a second
travel request in the same frame each way, so the re-entrancy guard is exercised forty times.

**Three real defects, none of which any earlier package could have exposed:**

1. **`DictRead.get_name()` never worked.** `Resource` declares `resource_name` with the getter
   `get_name`, and a GDScript *is* a Resource, so the static call dispatched to the native
   zero-argument method and threw at runtime — while compiling perfectly. The one caller was
   `Director._apply_save`, which meant **loading a save had never restored the area**. It looked
   fine for three packages because with one area you always reloaded into the area you were
   already in. Renamed `get_string_name`. Same family as `Area3D.priority` and
   `class_name Container`, and the third time this project has been bitten by it.

2. **A freed object compares EQUAL to `null` in Godot 4.** `InteractionSensor` pruned its
   candidate list but never validated `_current`, so after an area unloaded it held a dangling
   reference — and `best != _current` reported "unchanged", so nothing was re-announced and the
   prompt kept offering an Iron Lever in an area that no longer existed. The obvious guard,
   `if _current != null`, does not fire for a dangling reference. `_announced_id: int` now
   carries the identity, because an int survives the object it names. A freed instance also
   cannot be *passed* to a parameter typed `Interactable` — the argument type check itself
   fails — so the liveness check takes no argument and reads the field in place.

3. **`follow_clock = false` did not mean "do not use the clock".** It only stopped the driver
   *updating*; `_ready()` still called `_apply_now()` once, so the first interior ever built
   inherited whatever hour it was entered at and had its sun hidden below the horizon. Entered
   at 02:30 it was pitch black; entered at noon it was fine. From the same scene file. An
   interior now has its own authored ambient, fog and background, applied once, and the outdoor
   path never touches its sun.

**Connections:**

`AreaDoor` -> `Events.area_change_requested` -> `Director` -> `area_unloading` /
`area_load_progress` / `area_entered` -> `LoadingIndicator` and `ScreenFade`. `AreaRoot` still
configures weather and audio on entry; `EnvironmentDriver` reads `Clock` outdoors and nothing
indoors. `TriggerVolume`, built in WP-01 for exactly this, is still available as a walk-through
entry and is deliberately not used yet — the hall is entered deliberately, through a door.

**Verified:**

```
--headless --import                                   clean
--headless --quit-after 120                           0 warnings, 0 errors
--headless res://tests/test_runner.tscn                414 passed, 0 failed, exit 0
  with one assertion deliberately broken               413 passed, 1 failed, exit 1
--headless --script tools/check_budgets.gd            59 files, 4441 lines, 0 violations
--headless --script tools/check_content.gd            PASS
```

**Twenty round trips**, `--round-trips=20`:

```
--round-trips 20 from 'courtyard': 120 nodes, 31417 KiB
  trip 1/20: 120 nodes, 31331 KiB    ...    trip 20/20: 120 nodes, 31332 KiB
--round-trips done: nodes 120 -> 120 (+0), memory 31417 -> 31404 KiB (-12)
```

Node count is exactly flat across all twenty. Memory moves by 12 KiB, downward, which is noise.
The forty warnings are the forty second-requests the guard refused, two per trip — the
"two transitions in one frame are refused" criterion, exercised rather than asserted.

**World state on both sides**, `--cross-area-save`:

```
hall coffer emptied: true
saved in 'lantern_hall': OK
wiped: carrying 0, coffer emptied=false        <- deliberately destroyed before reloading
loaded: OK
after reload: area='lantern_hall', carrying 3
coffer still empty: true
```

Saved in the hall and reloaded from the courtyard, deliberately: a save taken where the reload
already is cannot tell "the area was restored" from "the area never changed", which is exactly
how the broken `get_name` hid for three packages. The wipe matters for the same reason — without
it, a value nobody cleared passes for a value that was restored.

**Both areas captured and looked at.** The hall took four attempts, and each one was a real
defect rather than a tweak: pitch black (bug 3), then a full frame of wall because the camera
sits fourteen units back and the room was closed on the camera side, then the door slab
occluding the room from the foreground, then correct. The stale "Use Iron Lever" prompt was
visible in every one of those captures and is what led to bug 2.

**Unblocks:**

WP-05's dialogue and WP-06's NPCs now have somewhere other than the courtyard to be, and WP-11's
fast travel has a real destination to travel to. More importantly the transition path is no
longer theoretical: anything that needs to happen across an area boundary can now be tested
against something that actually crosses one.

**Known gaps:**

`Director` still does not cancel its threaded load on shutdown, which is gotcha 13 and remains
WP-14's. `UiRoot` does not close its screens on `area_unloading`; it cannot currently matter,
because travel requires gameplay input and a modal screen suspends it, but a load triggered from
a save menu in WP-12 will need it. The loading indicator shows a percentage only once the loader
reports one, which for a small area is never — both areas here load in under a frame, so the
"Loading" word is what is actually seen. Interior lighting is four exported values applied once;
a room that wants light that changes has no mechanism yet, and should get one when something
actually needs it.

## 2026-08-26 — WP-03: the HUD clock and the inventory screen

**Did:**

The screen stack got its first real occupants. A HUD clock readout, an inventory screen that
renders what the player is actually carrying, the one node that binds `I` to it, twenty-two
new localization rows, and a new test case file. `StubScreen` is gone.

- `src/ui/hud/hud_clock.gd` — a `Label` on `Events.minute_passed` showing day, time and the
  localized phase name. Pausable on purpose: behind an open menu no in-game minute passes, so
  a clock that kept ticking would be lying.
- `src/ui/screens/inventory_screen.gd` — a `UiScreen`. Reads `Inventory.ids()`, emits a
  heading wherever the category changes, and a focusable row per item. Rebuilds on
  `Events.inventory_changed`, connected only while it is open.
- `src/ui/root/screen_keys.gd` — `ScreenKeys`. The whole action-to-screen table, which today
  has one row. `PROCESS_MODE_ALWAYS`, so the key that opened a screen also closes it.
- `tests/unit/screens_test.gd` — 61 new assertions. 294 -> 355.
- `dev_capture.gd` traded `--open-screen` for `--give=<list>` and `--open-inventory`, so a
  capture shows real rows produced by the real `Inventory.add()`.

**Why:**

**The HUD is a layer, not a class.** The obvious move was a `Hud` node owning the clock, the
prompt and the toasts. It was rejected: those three already exist as independent siblings under
`UILayer`, each subscribing to the one signal it draws, and a parent whose only job is to
forward signals to them adds a hop and a place for the fourth readout to accumulate. The HUD is
the set of nodes on that layer.

**The carrier is injected, not looked up.** `InventoryScreen.for_carrier(who)` mirrors the
interaction contract's `attempt(who)`. The same screen shows an NPC's satchel or a stash
without knowing that `Director` or a player exists, and a test hands it a bare `Node` with an
`Inventory` child.

**The screen holds no rules, and no pause.** It declares `pauses_world` and renders. It never
touches `get_tree().paused`, never locks the player, and never asks whether another screen is
open. Nothing in WP-02 had to be widened to make that work, which is the result WP-02 was
scheduled to produce.

**A screen declares its flags in `_init`, not `_build`.** Found while repointing `ui_test.gd`:
`_build` runs from `_ready`, i.e. *after* a caller has set a flag, so `StubScreen` setting
`pauses_world = true` there silently discarded the overlay test's `pauses_world = false`. The
overlay case had been passing vacuously since WP-02 — it asserted "the world stays paused" of a
screen that was, unknown to it, still a modal. `InventoryScreen` sets identity in `_init`, the
test now asserts the override survives `_ready`, and it fails if that regresses.

**Rows are `Button`s, and that is the whole of the focus work.** A `VBoxContainer` of focusable
children already answers `ui_up` and `ui_down`, which are bound to arrows, the d-pad and the
left stick. Pressing a row does nothing yet; tooltips and use are later packages.

**Connections:**

`Clock` -> `minute_passed` -> the HUD. `Inventory` -> `inventory_changed` -> the screen.
`Actions.INVENTORY` -> `ScreenKeys` -> `UiRoot.open()`. `UiRoot` -> `ui_mode_changed` -> the
player's and the sensor's own `&"ui"` tokens, unchanged from WP-02. `ItemDb` supplies
`name_key` and `category`; the screen never reads a `.tres`.

**Verified:**

```
--headless --import                                   clean
--headless --quit-after 120                           0 warnings, 0 errors
--headless res://tests/test_runner.tscn                355 passed, 0 failed, exit 0
  with one assertion deliberately broken               354 passed, 1 failed, exit 1
--headless --script tools/check_budgets.gd            56 files, 4152 lines, 0 violations
--headless --script tools/check_content.gd            PASS
--resolution 960x540 -- --shot=... --open-inventory   looked at, twice: 18:40 and 12:20
```

Two windowed captures were opened and examined, not merely produced. Both show the rows grouped
under "Key Items" and "Materials" with localized names and counts, the focus ring on the first
row, "Escape to close" at the foot, the clock top right, and the courtyard still drawn and
stopped behind the panel. The first capture was at `DIM` alpha 0.88 and the world behind it was
nearly invisible; lowered to 0.78 and re-shot at midday, where the dais and the character read
clearly through it.

Headless cannot see any of that, and it also cannot press a key: `TestCase.run()` is
synchronous, so no assertion can span the frames an input event needs. So the input path was
proved by a **temporary probe** added to `dev_capture.gd`, run windowed, and then removed. It
fed real `InputEventAction`s into the live tree and logged the result:

```
TEMP pressed inventory      -> Mode -> MODAL, Opened 'inventory' at depth 1
TEMP after I: depth=1, gameplay=false, player locked=true
TEMP focus after open: Rose Key  x1
TEMP focus after ui_down: Rose Petal  x7
TEMP focus after 2x ui_down: Chipped Stone  x2
TEMP focus after ui_up: Rose Petal  x7
TEMP pressed cancel         -> Mode -> GAMEPLAY, Closed 'inventory', depth now 0
TEMP after Escape: depth=0, gameplay=true, locked=false
TEMP toggle twice: depth=0
```

**Unblocks:**

Every remaining screen. The pause menu, the journal, the map and the settings screen are now
each a `UiScreen` subclass plus a row in `ScreenKeys`, with no new pause, no new boolean and no
new signal. WP-05's dialogue box is the first `pauses_world = false` occupant, and the overlay
assertion above is now a real guard for it rather than a vacuous one.

**Known gaps:**

A row does nothing when pressed — there is no use, no tooltip, no sorting and no drag-and-drop,
all deferred by the package. The screen rebuilds every row on any change, which is fine for a
few dozen entries and would not be for a few hundred. `refresh()` frees the old rows with
`queue_free()`, so within a single frame the freed children are still present; the test skips
`is_queued_for_deletion()` children and any future reader must too. The HUD clock is drawn
beneath the screens, so an open inventory dims it — legible, and arguably right, but it is a
choice rather than an accident. Still no hard-coded-string audit tool: the enum-built keys
(`verb.*`, `refusal.*`, `item.category.*`, `time.phase.*`) are each covered by a loop in the
suite, and everything else is caught only by review.

## 2026-08-26 — WP-02: the screen stack, pause semantics and a token input lock

**Did:**

- `src/core/util/input_lock.gd` — `InputLock`, a set of named holds. `lock(&"dialogue")`,
  `release(&"dialogue")`, `is_locked()`, `holders()`. Twenty-one code lines.
- `src/ui/root/ui_root.gd` — `UiRoot`, the screen stack. `open()` / `close_top()` /
  `close_all()`, `is_gameplay_input_allowed()` as the single truth, and the whole pause table
  written down in its header. Found by group, not by path: `UiRoot.find(node)`.
- `src/ui/screens/ui_screen.gd` — `UiScreen`, the contract every screen satisfies. A screen
  declares `pauses_world` and `closes_on_cancel` and then renders. It never touches
  `get_tree().paused`, never locks the player, never frees itself.
- `src/ui/screens/stub_screen.gd` — scaffolding, marked for deletion once two real screens
  exist. It exists so this package could be verified without WP-03.
- `GameEnums.UiMode { GAMEPLAY, OVERLAY, MODAL }` and `Events.ui_mode_changed(mode)`, emitted
  by UiRoot and by nothing else.
- **Deleted `PlayerController.set_input_locked(bool)`.** Its four callers now hold named
  tokens: `&"dialogue"`, `&"climb"`, `&"ui"`.
- `InteractionSensor` grew its own `InputLock` and now knows an open screen exists at all,
  which it previously did not. `InteractPrompt` hides itself while the mode is not GAMEPLAY.
- Four nodes opted out of pause in their own `_ready()`: `Audio`, `Director`,
  `NotificationToast`, `DevCapture`. `ScreenFade` already had.
- `scenes/boot/game_root.tscn` gained `UiRoot`, and `ScreenFade` moved to be the LAST child
  of `UILayer` — a curtain that does not cover the screens is not a curtain.
- `--open-screen` on `dev_capture.gd`, so the capture can photograph a paused world.
- `tests/unit/ui_test.gd`, 79 assertions. Suite is 215 -> 294.

**Why:**

Nothing in this project had a home for modal UI. The only hand-over mechanism was one boolean
behind `set_input_locked(bool)`, and WP-01 gave it a second caller, which is when a boolean
stops working: dialogue locks the player, a climb starts and finishes inside the conversation,
the climb's own `set_input_locked(false)` clears the dialogue's hold, and the player strolls
away mid-sentence. Nothing errors. Nothing logs. It reads as a physics bug.

A count would fail the other way — lock twice, release once, and the lock is stranded with
nothing to point at. Named tokens are idempotent, so a doubled `dialogue_started` is free, and
`holders()` can name whoever is still holding when something does go wrong.

The stack had to come before any screen, which is why this is WP-02 and the inventory screen
is WP-03. Build a screen first and you get one boolean per screen, forever, each owned by a
different file and each able to clear the others.

**On pause, deliberately:** this does set `get_tree().paused`, but which nodes that actually
stops was decided node by node, and the table lives in `ui_root.gd`'s header. Clock and
Weather stop, because in-game time must not pass behind a menu. Audio does not, because the
score cutting out is the one thing every player notices — and note it is the autoload itself
that needed the opt-out, since the cross-fade tweens are created on it. Director does not,
because a transition in flight would otherwise strand the game on black. Each of those is set
in the owning node's own `_ready()`, never from UiRoot: a central pause that reaches into ten
nodes is the god object all over again.

**Connects:**

UiRoot announces `ui_mode_changed`; `PlayerController`, `InteractionSensor` and
`InteractPrompt` listen. UiRoot does not know the player exists, and the player does not know
which screen opened — it takes one `&"ui"` token and gives it back. The player and the sensor
hold *separate* locks, because the sensor lives in `src/systems/` and the controller in
`src/gameplay/`, and reaching upward across that line is what the layer rule forbids.

**Verified:**

```
G=/c/Rai/softwares/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
"$G" --headless --import                                        # clean
"$G" --headless --quit-after 30                                 # "0 warnings, 0 errors", x3, zero ERROR/WARNING lines
"$G" --headless res://tests/test_runner.tscn --quit-after 150   # 294 passed, 0 failed, exit 0
"$G" --headless --script tools/check_budgets.gd                 # 53 files, 3879 lines, 0 violations, exit 0
"$G" --headless --script tools/check_content.gd                 # PASS, exit 0
```

A deliberately inverted assertion (`get_tree().paused` expected `false`) gave
`293 passed, 1 failed` and **exit 1**, then was restored.

Windowed captures at 960x540, `--time=18:40 --freeze-time`:

- without a screen: the lit courtyard, the player, and `Use Iron Lever` on the prompt.
- `--open-screen`, frame 45: the stub screen centred and correctly sized over the world, the
  world still drawn behind it through the 0.82-alpha panel, **and the interaction prompt
  gone** — which is the prompt's new `ui_mode_changed` handler, visible in a photograph.
- `--open-screen`, frame 16: the fade curtain still partly up **over** the screen text. By
  frame 45 it has fully lifted. So the fade both draws above the screens and keeps tweening
  while the tree is paused, which is the pause table proving itself.

A throwaway probe scene (deleted afterwards) drove the live tree with a real injected
`InputEventAction`, because the suite is synchronous and cannot await a frame:

```
stack found: true              opened: true
depth 1, paused true, gameplay allowed false, player holders [&"ui"]
injected CANCEL
depth 0, paused false, gameplay allowed true, player holders []
```

The pause table is asserted, not merely documented: `ui_test.gd` opens a modal and reads
`can_process()` off `Clock`, `Weather`, `Audio`, `Director`, the stack, the screen and the
player. That confirmed empirically what would otherwise have been a guess about Godot's
default process mode for autoloads — they are pausable, so `Audio` genuinely needed the line.

**Unblocks:**

Every screen in the game. WP-03 (HUD and inventory screen) is now a `UiScreen` subclass with
content in it and nothing else — no new pause, no new boolean, no new signal.

**Known gaps:**

- Pre-existing, found while re-running the ladder and reproduced at baseline: `--quit-after
  30` does not reliably finish the threaded area load on a cold cache, and quitting mid-load
  prints spurious `courtyard.tscn` parse errors and leaked RIDs AFTER the run has already
  logged `0 warnings, 0 errors`. Documented as gotcha 13; the boot rung is now `--quit-after
  120` in `CLAUDE.md` and `CONTEXT.md`. The real fix is for `Director` to cancel its load on
  shutdown, which belongs in WP-14.
- No audio assets exist, so "music keeps playing" is verified as `Audio.can_process() == true`
  under pause, not by ear. That is the strongest claim available until there is an `.ogg`.
- Nothing gives a screen keyboard focus yet, so controller and keyboard navigation within a
  screen is unbuilt. It belongs with the first screen that has something to focus (WP-03).
- `Actions.PAUSE` and `Actions.CANCEL` share Escape and both merely close the top screen.
  Nothing *opens* a screen from gameplay input yet, deliberately — the pause menu is WP-12.
- `StubScreen` is scaffolding. Delete it when two real screens exist.

---

## 2026-08-26 — WP-01: triggers, resting and authored climbing

**Did:**

Three new interactables, the clock call they needed, and a climb state on the player body.

- `TriggerVolume` — an `Area3D` on `Layers.TRIGGER`, once-or-repeat, persisted by `object_id`.
  It sets a world flag and emits `Events.trigger_fired`, and that is all it does.
- `RestPoint` — the `SIT` verb, skipping to a target hour, with an optional `night_only` gate
  that refuses with `WRONG_TIME`.
- `Clock.skip_to_hour(hour)` — routed through `set_time`, returning the minutes skipped.
- `ClimbPoint` plus `can_climb` / `begin_climb` / `climb_step` on `PlayerController`.
- Prefabs in `scenes/objects/`, a stone terrace and all three objects placed in the courtyard,
  four CSV rows, `RefusalReason.NOT_GROUNDED`, and `--skip-to-hour=` on the dev capture.
- `tests/unit/traversal_test.gd`, 50 assertions. The suite is now 215.

**Why:**

The `Triggers/` node, `Layers.TRIGGER` and the inventory rows for sittables and climbables had
all existed since Phase 0 with nothing populating them. Three specific reasons shaped the code:

- **A trigger must not name its consequence.** `@export var door_to_open` is the same trap the
  lever avoids: the second time two things must react to one crossing, the coupling has to be
  undone. It sets a flag and announces itself; anything may watch either.
- **A time skip is one event, not a fast-forward.** Sleeping eight hours through
  `advance_minutes` emits 480 `minute_passed` signals, and any listener doing real work per
  minute does it 480 times in one frame. `skip_to_hour` is a single `set_time`.
- **`NOT_GROUNDED` is a new refusal reason, not a silent no.** A climb refused mid-air with no
  explanation is indistinguishable from a broken button, and this project's whole position on
  refusal is that the player should be told why.

**Connects:**

`ClimbPoint` asks the mover `can_climb()` and calls `begin_climb()` — it never writes a
position itself, so `PlayerController`'s boundary holds and interaction stays out of it.
`RestPoint` calls `Clock`, and everything downstream of the clock — the environment driver,
and later NPC schedules — reacts without knowing a bench exists. `TriggerVolume` reuses
`PersistentState` unchanged; it is not an `Interactable`, because nobody presses it.

**Verified:**

- `--headless --import` — clean.
- `--headless --quit-after 30` — **0 warnings, 0 errors**.
- `--headless res://tests/test_runner.tscn --quit-after 150` — **215 passed, 0 failed**,
  exit 0. A deliberately broken assertion gave 211/1 and exit 1.
- `--headless --script tools/check_budgets.gd` — 48 files, 3500 code lines, 0 violations,
  exit 0.
- `--headless --script tools/check_content.gd` — PASS, exit 0.
- Two windowed captures at 960x540 from the same `--time=06:30 --freeze-time` start, the
  second adding `--skip-to-hour=20`: warm dawn with south-cast shadows becomes cool night
  with both lantern pools lit. **The lighting genuinely changed**, which is the thing headless
  cannot tell you.
- A third capture with the spawn temporarily moved beside the terrace shows the ladder flush
  to the stone face and the prompt reading "Climb Trellis Ladder"; a fourth, from the top
  marker, shows the body standing on the terrace with the same prompt still offered, so the
  descent is reachable. Spawn restored afterwards.

**Two real bugs the engine caught, neither visible in the source:**

1. **The climb oscillated on its corner forever.** The path deliberately turns at the top —
   up-then-over ascending, over-then-down descending — because a straight line from the foot
   of a ladder to the ledge above passes *through* the ledge, and a climb that writes
   `global_position` has no collision left to stop it. But without a latch, the frame after
   arriving at the waypoint steps off towards the target, the next frame sees the body is no
   longer at the waypoint and steers back. 600 test steps, no convergence. Fixed with
   `_climb_turned`.
2. **The dais trigger toasted at spawn, from three metres away.** A spawning player exists at
   the area origin for one frame before `Director` places them on the spawn marker, so a
   trigger anywhere near that origin fires on load, every load. `TriggerVolume` now arms two
   physics frames late. Verified in both directions: no spawn toast now, and with the trigger
   temporarily moved onto the spawn point it still fires through `body_entered` under real
   physics, with the flag landing under its `object_id`.

**Unblocks:**

`Clock.skip_to_hour` is what NPC schedules (WP-06) need to be testable — a schedule you have
to wait twenty real minutes to observe is not one you will ever debug. Trigger volumes give
area transitions (WP-04) their entry mechanism, and give quests (WP-08) a way to fire a step
from a place rather than from an object.

**Known gaps:**

The unit test drives `fire()` directly and asserts the wiring (layer, mask, one `body_entered`
connection); the physical entry path is proven by the windowed run, not by the suite, because
`TestCase.run()` is synchronous and cannot wait on a physics frame. For the same reason the
*grounded* half of the climb refusal is asserted only in its negative direction — a body that
has never called `move_and_slide` is mid-air by definition, which is exactly the case worth
testing. The arm delay means anything still standing inside a volume when it arms is treated
as having entered; that is deliberate, and correct for a save reloaded inside a region.
`RestPoint` has no `PersistentState` because it has nothing to remember.


## 2026-08-25 — Work sliced into one-chat packages, and a roadmap to skeleton-complete

**Did:**

No gameplay code. Added `docs/WORK_PACKAGES.md`: fifteen packages from here to
skeleton-complete, in dependency order, each sized to one chat and each naming the exact files
that chat should read. Wired it into all four entry points — `CLAUDE.md`, `README.md`,
`docs/CONTEXT.md` and `docs/ROADMAP.md` — and put the per-chat open/close protocol in
`CLAUDE.md`, since that is the file a new session reads automatically.

**Why:**

A chat context window is the binding constraint on this project. This session hit usage limits
three times, and twice a delegated fan-out died mid-flight after burning several hundred
thousand tokens. Work has to be sliced so one chat finishes one coherent part.

The structure was already fine — `src/core` is 590 code lines, `src/systems` 725,
`src/gameplay` 867, `src/ui` 117 — and the downward-only layer rule means a package never has
to read upward. **The missing piece was not structure, it was a manifest.** A new session had
no way to know which subset to load, so it loaded too much. Every package now carries an
explicit file list, which is the load-bearing part of the whole document.

Also settled what "skeleton complete" means, because the phrase was doing a lot of unexamined
work: every system on the inventory has a working minimal implementation plus one piece of
placeholder content proving it. That is the standard items were held to — three throwaway
`.tres` files proved the pattern and the fiftieth item needs no code. After that point,
everything remaining is content.

**Connects:**

The board is the executable version of `ROADMAP.md`, and that file now says so, so the two
cannot silently drift. Dependency order is recorded with reasons rather than left implicit —
UI foundation before any screen, because a screen built first forces an ad-hoc pause and a
boolean per screen; dialogue before quests and path actions, because both are driven by it;
world map after a second area exists, because it is meaningless with one.

WP-15 carries a specific obligation: it must settle ADR-0006's open question. Items are found
by scanning a directory, verified in the editor and headless only, and the export preset must
export *all* resources or the catalogue ships empty.

**Decisions taken with the owner:** all four optional systems are IN the skeleton — path
actions, traversal equipment, world map and fast travel, crafting and gathering. Nothing on
the inventory is cut. Narrative systems are built against placeholder story; the real story is
content, supplied later.

**Verified:**

Docs-only, so the ladder is a regression check rather than a proof: boot `0 warnings, 0
errors`, tests 165 passed / 0 failed, `check_content` PASS. Every entry point references the
board.

**Unblocks:**

WP-01, triggers and traversal, in a fresh chat: trigger volumes (the folder, the collision
layer and the inventory row all exist and nothing populates them), a rest point with
`Clock.skip_to_hour`, and climb points — the authored vertical movement that "no jumping"
implies.

**Known gaps:**

Packages 02 through 15 are specified at goal-plus-manifest depth, not to WP-01's detail. That
is deliberate: writing detailed plans for work fourteen chats away is exactly the speculative
architecture this project keeps deleting. Each gets its detail when it comes up.

---

## 2026-08-25 — Items, inventory, pickups and chests: the demo loop closes

**Did:**

Planned this one properly before writing anything, because the last two attempts at
delegating research both died on usage limits. Two Explore agents mined the three surviving
audit reports and verified the existing seams; one design agent produced an implementation
plan; the whole thing was settled with the owner before line one. That paid for itself twice
over, below.

Shipped in two commits. First, prerequisites (`dd90da0`):

- **Layer order corrected.** The declared order put `content` *above* `gameplay`, but a
  `Pickup` must reference an `ItemDefinition` — an upward dependency failing ADR-0001's own
  test. Content is data, not a consumer: `core -> content -> systems -> gameplay -> ui`.
  Recorded as an ADR-0001 amendment rather than quietly fixed.
- **Signal payloads.** `notify_requested` had no substitution slot, so a toast could not say
  "Taken: Rose Key", and `interaction_refused` could not name the missing item. Both now carry
  a `Dictionary`; both had zero emitters, so it was free then and expensive later.
- **Per-section save versions.** `register()` takes a version, sections store as
  `{"v": n, "data": {…}}`, and appliers migrate themselves. One envelope version would have
  forced `_migrate` to understand every section — the god object via the back door.
- **`Flags` hands out deep copies** from `get_dict`/`get_array`. Godot passes Dictionaries by
  reference, so returning the stored object let a caller mutate world state without
  `set_flag`, meaning `flag_changed` never fired.
- **Test suite split** into `tests/framework/test_case.gd` plus `tests/unit/*.gd`, because the
  runner was at 184 of its 250 lines and the item cases would not fit. Raising the budget is
  the exemption the checker's own header forbids.

Then the feature:

- **`ItemDefinition`** — the project's first `Resource`. Four fields: `id`, `name_key`,
  `category`, `max_stack`. Five more were cut (`icon`, `description_key`, `value`, `tags`,
  `world_scene`) because nothing displays or reads them and adding one later edits one script
  while leaving every `.tres` valid.
- **`ItemDb`** — a static class, not an autoload, that scans `data/items`. ADR-0006.
- **`Inventory`** — a component on the player, with `can_accept()` as the single capacity seam.
- **`Pickup`**, **`ItemContainer`**, and `Gate.requires_item`.
- **`tools/check_content.gd`** — duplicate object ids, id/filename mismatches, localization keys
  missing from the CSV, and `ItemDefinition` files filed outside `data/items`.
- Courtyard content: a rose key on the dais, a wicker chest, an east gate that wants the key.

**Why:**

Items had to be next because they were the last missing piece of the Phase 1 loop *and* the
project's first typed `Resource`. `ARCHITECTURE.md` has claimed since day one that "adding the
fiftieth item must not touch a single line of code", and that claim had never been exercised —
the audit called it unrunnable rather than untested. It is now tested by a case that counts the
`.tres` files on disk instead of hard-coding three, so adding a fourth item keeps it passing.

Two design points worth keeping. **The inventory is not an autoload**: interactables are already
handed the interactor by `attempt(who)`, so `Inventory.of(who)` needs no global and works for an
NPC or a stash, whereas a global would hard-code "one bag in the universe" into every
interactable in the game. **The lever and the gate still know nothing about each other** — one
publishes a flag, the other reads one, and now a third thing can demand a carried item instead.

**Connects:**

Persistence added *zero* new machinery. `PersistentState.store(&"taken", true)` writes
`obj/<area>/<object>/taken` into `Flags`, which is already a tested save participant, so a
pickup that is gone stays gone because `flags` is applied before the area is even requested.
That is the whole return on ADR-0005. `Pickup` deliberately does not free itself — the sensor
may hold a reference inside the very call that took the item — it goes unavailable,
unmonitorable and invisible instead.

**Verified:**

- Type gate clean on every new script; `--import` clean.
- Boot: courtyard with **6 interactables**, `0 warnings, 0 errors`.
- Tests: **165 passed, 0 failed**, exit 0, no leaked instances. A deliberately broken
  assertion exits 1.
- `check_budgets`: 44 files, 3,202 code lines, **0 violations**.
- `check_content`: PASS — and proven to fail. A scratch copy with a mismatched item id, a
  duplicate `object_id`, a misspelled localization key and a stray definition produced four
  precise `file:line` violations and exit 1.
- Visual capture at 10:15 shows the placeholder-marker key on the dais and the chest, both
  casting shadows, with the localized prompt reading "Read  Weathered Notice".

**Two things the planning caught that would have cost real time:**

1. **`class_name Container` does not compile.** `Container` is a native Godot class (the
   `Control` base), so it would have cascaded into every subclass as "could not resolve class" —
   the same trap as `Area3D.priority`. Verified against the engine's own class list, and the
   chest is `ItemContainer`.
2. **Resource-typed `@export` from a hand-authored `.tscn` works** with no `node_paths` header,
   unlike Node-typed ones. Probed before authoring any prefab against the assumption.

And one bug the refactor caught in its own new helper: a one-step `spawn()` added nodes to the
tree before the caller could set `object_id`, which `Interactable` forwards in `_enter_tree` —
so it arrived too late and persistence silently died. Split into `build()` and `attach()` so the
ordering lives in the API rather than a comment.

**Unblocks:**

Trigger volumes and a rest point, then the screen stack that the inventory UI needs. Phase 1's
remaining exit criteria are now the walk-and-face check and a real save/quit/relaunch.

**Known gaps:**

**The export path is unproven** and this matters: items are found by scanning a directory,
verified in the editor and headless only. There is no export preset, and it must export *all*
resources or the catalogue ships empty — written up in ADR-0006 rather than left as a surprise.
No trigger volumes yet, no screen of any kind, no item instances (deferred until something has
durability), no equipment. The sprite sheet layout is still two hardcoded constants. Only one
area exists, so the transition code has still never swapped two.

---

## 2026-08-24 — Object identity, and the interaction loop end to end

**Did:**

- **ADR-0005: authored object identity.** Every persistent object carries a `PersistentState`
  child with an `object_id`, unique within its area. State is written through `Flags` under
  `obj/<area_id>/<object_id>/<field>`. Rejected node-path identity, which is free but couples
  identity to scene structure: renaming a node silently orphans its state, the chest refills,
  and nothing errors. Rejected generated UUIDs as unreadable in a save file and in a diff.
  No new autoload — `Flags` is already a generic store and already a tested save participant.
- **`Interactable`**, a deliberately shallow base class over `Area3D`. Subclasses override
  `refusal()` and `perform()`; detection, ranking, prompts, refusal messaging, one-shot
  handling and hold-to-confirm are all handled once. Chose a base class over a duck-typed
  component because warnings-as-errors forbids calling a method on an untyped value, so a
  component would need a cast at every call site.
- **`InteractionSensor`** on the player. Ranks candidates by authored priority, then
  proximity, then how squarely the player faces the target, with ties broken by node name so
  physics callback order cannot reshuffle the prompt between frames. Tab cycles overlapping
  targets. Hold-to-confirm is supported and drawn as a progress bar.
- **Three interactables:** `Readable` (signs), `Lever` (toggles a persistent flag), `Gate`
  (refuses with a reason until a flag is set, then opens and stays open).
- **Localized UI:** `InteractPrompt` and `NotificationToast`, plus `localization/strings.csv`
  with 28 keys wired through `tr()`. This closes the "zero `tr()` calls" audit finding —
  there is now no code path by which raw player-facing text reaches the screen.
- Placed a notice, a lever and a north gate in the courtyard as instanced prefabs from
  `scenes/objects/`.

**Why:**

The audit named object identity as the thing blocking everything else, because interaction,
items, containers and doors all persist state through it, and retrofitting it means touching
every scene. It had to be decided before content existed.

The lever deliberately does not know what it opens. The tempting design is
`@export var door_to_open`, which couples every lever to one consequence; the second time a
lever needs to do two things, the coupling has to be undone. The lever owns a flag and
anything may watch it, so one lever can gate five things without knowing they exist.

Refusal is a first-class result rather than a hidden prompt. Hiding the prompt on a locked
gate is cheaper but worse: the player cannot tell a locked door from scenery, so they never
learn there is something to come back for.

**Connects:**

`PersistentState` walks up to the enclosing `AreaRoot` for its namespace, so an id only has to
be unique within one area file. `Interactable` forwards `object_id` to that child in
`_enter_tree`, which runs top-down before any child `_ready`, so an instanced prefab sets its
identity with one root-level property override instead of a child-node edit that hand-authored
`.tscn` files cannot express robustly. Interaction input is read by the sensor, not by
`PlayerController`, because the controller's own MUST NOT line forbids it knowing about
interaction; the comment claiming "one of only two scripts allowed to read input" was corrected.

**Verified:**

- Type gate clean on all eight new scripts.
- `--headless --import` clean; boot loads the courtyard with 3 interactables,
  **0 warnings, 0 errors**.
- Test suite **74 passed, 0 failed**, exit 0. The new cases drive the whole loop with no
  simulated keypress: the gate is offered and refuses with LOCKED, the lever publishes its
  flag, the same gate then opens, its state lands at `obj/global/t_gate/open`, and after the
  node is freed and re-instantiated it is *still open* — which is what an area reload does.
  Clearing one object's state leaves unrelated flags intact.
- `check_budgets.gd` — 32 files, 2,485 code lines, 0 violations. It caught one of these very
  test functions at 42 lines against the 40 limit; the function was split rather than the
  budget raised.
- Visual capture at 09:30 shows the prompt reading "Read  Weathered Notice", both words
  resolved through the translation table.

**Unblocks:**

Items and inventory, which is the last big piece of the demo loop, and which will be the first
typed `Resource` content class — the thing that finally tests the "adding the fiftieth item
touches no code" claim.

**Known gaps:**

Still zero typed `Resource` content classes. No duplicate-`object_id` detection, so two objects
sharing an id inside one area would silently share state; a content validator scanning scenes
would catch it. No hard-coded-string audit, so the localization rule is enforced by discipline
rather than mechanically. Trigger volumes still have a folder, a collision layer and no system.
The gate opens but leads nowhere, because there is only one area.

Two engine traps cost time and are now recorded in `CONTEXT.md`: `Area3D` already defines
`priority`, and redefining it is a parse error that cascades into every subclass as "could not
resolve class"; and `set_anchors_preset()` leaves offsets at zero, producing a zero-size
Control whose text spills off the screen.

---

## 2026-08-24 — Audit: four defects fixed, and rung 4 of the ladder made real

**Did:**

Audited the Phase 0 skeleton, fixed every confirmed defect, and built the test suite.

- **Toggle-run did nothing.** `_is_running()` polled `Input.is_action_just_pressed` and is
  called twice per frame (from `_current_speed()` and `_update_state()`), so the toggle
  flipped twice and netted to zero. Polling moved into `_poll_run_toggle()`, called once at
  the top of `_physics_process`, and `_is_running()` is now a pure query.
- **A missing area left the screen permanently black.** `ScreenFade` starts opaque and only
  `Director` lifts it, so the early-return in `game_root.gd` stranded the player. It now logs
  an error naming the expected path and requests the fade-in regardless.
- **`player_yaw` was saved and never read.** Written to every save since the first commit,
  read nowhere, so facing was silently lost on load. Restored via `_yaw_override`.
- **A fresh clone did not run at all.** Proved by cloning the repo to a scratch directory:
  `class_name` globals live in `.godot/global_script_class_cache.cfg`, which is generated and
  correctly gitignored, so `events.gd` could not resolve `GameEnums`, the `Events` autoload
  failed to instantiate, and the console filled with parse errors that look like broken code.
  One `--headless --import` fixes it. Now documented in `README.md`, `CLAUDE.md` and
  `docs/CONTEXT.md`.
- **The silent fallback that hid a bug is now loud.** `EnvironmentDriver`'s sibling discovery
  reported at `Log.debug`; it is a `Log.warn` now, so an unwired scene reference cannot hide
  behind a working-looking day/night cycle again. Also added the canonical
  `node_paths=PackedStringArray(...)` header to the `EnvironmentDriver` node in
  `courtyard.tscn`, which is the documented serialization for node-typed exports.
- **Built `tests/test_runner.gd` + `.tscn`:** 55 assertions over `DictRead` coercion, `Flags`
  including no-op-set silence, `Clock` hour/day rollover and midnight-crossing arithmetic,
  `Weather` force and shelter, and a full save round-trip.
- Added `docs/CONTEXT.md`, a one-minute state snapshot for a new session, linked from the top
  of `CLAUDE.md` and the first row of the README table.

**Why:**

Two of the four Veilbound failure modes had already reappeared in miniature, in this project,
at 1/600th scale. `ROADMAP.md` marked "a save participant can register, and the save envelope
round-trips" as a met Phase 0 exit criterion when only the registration had ever been observed,
as a log line — the save path had never once executed. That is precisely the
409-passing-checks pathology. The criterion is now genuinely true, and the roadmap records
that it was wrongly claimed a day earlier rather than quietly correcting itself.

**Connects:**

Rung 4 had to become a **scene** entered positionally, not the `--script` tool the
architecture document specified. Under `--headless --script` the autoload *nodes* are created
but the autoload *identifiers* fail to compile (`Compile Error: Identifier not found: Log`),
so no test touching a system could ever have run that way. The documented command could not
have worked; it is corrected in `ARCHITECTURE.md`, `README.md`, `CLAUDE.md` and `CONTEXT.md`.

**Verified:**

- Type gate clean on all four edited scripts.
- `--headless --import` clean.
- `--headless --quit-after 60` — loads the courtyard, `0 warnings, 0 errors`.
- `--headless res://tests/test_runner.tscn --quit-after 150` — **55 passed, 0 failed**, exit 0.
  A deliberately broken assertion was confirmed to produce exit 1, so the gate genuinely fails.
- `tools/check_budgets.gd` — 24 files, 2,026 code lines, 0 violations, exit 0.

**Unblocks:**

Interaction, items and world objects can now be built against a suite that will catch a
regression in save, time or flags, rather than against a boot log.

**Known gaps:**

Still zero typed `Resource` content classes and zero `tr()` calls, so the "adding the
fiftieth item touches no code" test in `ARCHITECTURE.md` cannot yet be run even once, and the
no-hard-coded-strings rule has a document but no mechanism. No stable-object-ID scheme, which
blocks object persistence and is the next thing to decide. Trigger volumes have a folder, a
collision layer and no system. The audit that found this was itself incomplete — three of five
dimensions landed before the run hit a weekly usage limit; correctness and Godot-API review
were done by hand instead, and the surviving reports are in the scratchpad, not the repo.

---

## 2026-08-23 — Phase 0 foundation, and a lit courtyard with a character in it

**Did:**

Created the project from an empty folder.

- **Structure:** 80 directories in five code layers (`core`, `systems`, `gameplay`,
  `content`, `ui`), plus `scenes`, `data`, `assets`, `localization`, `tests`, `tools`, `docs`.
  Git initialised on `main`. `.gitignore` and `.gitattributes` written, including a note that
  `*.uid` and `*.import` files **must** be committed.
- **Engine config** (`project.godot`): Forward+, MSAA 4x, TAA deliberately off, debanding on,
  occlusion culling on, gravity 24, ten named collision layers, editor folder colours, and
  GDScript warnings-as-errors.
- **Ten autoloads:** `Log`, `Events`, `Actions`, `Settings`, `SaveSystem`, `Flags`, `Clock`,
  `Weather`, `Audio`, `Director`.
- **Utilities:** `Layers`, `GameEnums`, `DictRead`.
- **Gameplay:** `HD2DCameraRig`, `CharacterVisual`, `PlayerController`, `EnvironmentDriver`,
  `AreaRoot`, screen fade, game root.
- **Tools:** procedural placeholder art generator, and `DevCapture` for screenshots and
  command-line control of time and weather.
- **Content:** the `courtyard` area and the player scene.
- **Docs:** this log, `ARCHITECTURE.md`, `SYSTEMS_INVENTORY.md`, `ROADMAP.md`,
  `CONVENTIONS.md`, and decision records.

**Why:**

The previous project died of four things, all recorded in its own debt register: god objects
(`main.gd` at 3,983 lines), code that passed 409 static checks while never once running in a
real engine frame, 200 hard-coded strings, and eleven regions of breadth with no proven
slice. Every structural decision here targets one of those. The two strongest levers are
warnings-as-errors, which makes untyped and unsafe code fail to parse at all, and the
verification ladder, which makes "it runs" a command rather than an opinion.

**Connects:**

`Log` and `Events` sit at the bottom and depend on nothing, so everything may use them.
`Events` is the single declared home for every cross-system signal, which makes it the
connection map — reading that one file shows how the game is wired. `SaveSystem` knows
nothing about game content: systems register a pair of callables, so adding a saveable system
never edits the save code. `Clock` publishes time and refuses to interpret it;
`EnvironmentDriver` consumes it and turns it into light. `Director` owns every area
transition behind one guarded path so two doors cannot fire at once. `GameRoot` spawns the
player once and `Director` repositions them per area, so walking out and back in cannot lose
state.

**Verified:**

- `--headless --import` — clean, no errors.
- `--headless --quit-after 30` — boots, loads the courtyard, spawns the player, exits 0 with
  **0 warnings and 0 errors**.
- Parse and type gate over all 18 scripts — every one clean under warnings-as-errors.
- Deliberately broken script → exit 1 naming the file and line, so the gate genuinely fails.
- Visual capture at 06:50, 12:30, 18:40 and 22:00, plus a forced storm. Dawn shows warm low
  light and long raked shadows; night shows cold ambient with two warm lantern pools and the
  character lit by them. **The character sprite casts a real shadow**, which confirms
  `ALPHA_CUT_DISCARD` is behaving as intended.

**Two real bugs found and fixed by that visual pass**, neither of which any static check
would have caught:

1. The character was invisible. `centered = false` with a negative Y offset pushed the sprite
   1.68 m below the ground. Now centred and lifted by half a cell height, derived from the
   texture rather than hard-coded.
2. Every hour of the day rendered identically. `EnvironmentDriver`'s `sun` and `moon`
   `@export` references were never wired in the area scene, so the driver held `null` and the
   directional light stayed frozen at its default energy forever. Wired explicitly, **and**
   the driver now discovers its own siblings by name and logs a warning when it has to — so
   the same silent failure cannot recur.

The second one is the whole argument for rung 5 of the ladder. A day/night system that
compiles, runs, logs correct times, reports no errors, and lights nothing.

**Unblocks:**

The interaction, item and object systems, which are the next milestone. They have somewhere
to live (`Interactables/` in every area), a way to be found (`Layers.INTERACT_MASK`), a way to
announce themselves (four interaction signals already declared in `Events`), a way to persist
(`Flags` plus the area's `flag_key()` namespace), and a way to be seen (placeholder art plus
capture).

**Known gaps:**

No test runner yet, so rung 4 of the ladder is unused. No audio
assets, so every audio path is written but unexercised. Weather publishes state but nothing
renders rain. Only one area exists, so the transition code has never actually swapped two
areas. Input actions do not appear in the editor's Input Map panel, which is a known accepted
trade-off.

---

## 2026-08-26 — T2.0 · The export proof

**Did.** Built the first export this project has ever had, ran it, and found out whether an
exported build finds content that nothing references. It does. Also found a second, unrelated
export-only defect while looking, and gated it.

- `export_presets.cfg` — one Windows Desktop preset, committed. `export_filter="all_resources"`,
  and the file's header carries the measurement rather than a preference.
- `src/systems/debug/catalogue_report.gd` — reports each catalogue's count, root and resolved
  paths at boot, behind `OS.is_debug_build()`. Fifth root node in `scenes/boot/game_root.tscn`.
- `tools/check_content.gd` — `_check_editable_instances()`, 189 → 237 of 250 code lines.
- `tests/unit/export_test.gd` — 19 assertions, registered in `test_runner.gd`. 911 → 930.
- `scenes/areas/courtyard/courtyard.tscn` — the missing `[editable path="Actors/Keeper"]`.
- `docs/NEW_GAME.md` § 7 Export; ADR-0006's honest limit closed; inventory, roadmap and board.

**Why.** The three registries find items, conversations and schedules by DIRECTORY SCAN
(ADR-0006), so most of `data/**` is nobody's dependency, and Godot's exporter walks dependencies.
If it omitted them every catalogue would ship empty and NOTHING here could see it — every ladder
rung, both CI jobs, `check_content` and 911 assertions run from `res://` in the editor. Cheap to
test, architectural to fix, so it was sequenced ahead of T2.1 by risk.

**Connects.** `CatalogueReport` asks the same three registries the game asks, so it cannot report
a number the game does not have. It joins `dev_capture`/`dev_probes`/`dev_stage` in the one
directory `check_boundary` exempts, and it needs no exemption of its own: a count readout names no
demo content. The new gate lives beside `check_content`'s other scene checks because it is a
statement about whether the DEMO is well formed, not about whether the engine knows the demo
exists — the same seam that split `check_boundary` out in T1.2.

**Verified.**

```
--headless --import                             0 SCRIPT ERROR / Parse Error
--headless --quit-after 120                     Session ended after 1.3s - 0 warnings, 0 errors
--headless res://tests/test_runner.tscn         930 passed, 0 failed, 0 skipped   exit 0
--headless --script tools/check_budgets.gd      exit 0  (check_content 237/250)
--headless --script tools/check_content.gd      PASS    exit 0  (16 scenes)
--headless --script tools/check_boundary.gd     PASS    exit 0  (95 scripts, 14 exempted)
stripped (data/ + scenes/areas/ moved aside)    880 passed, 0 failed, 12 skipped  exit 0
```

The export itself, and the numbers from both sides:

```
--headless --export-debug "Windows Desktop" .../build/windows/game.exe    exit 0

editor    origin: template=false editor=true debug=true exe=Godot_v4.7.2-stable_win64.exe
          items: 3 found in res://data/items -> [rose_key.tres, rose_petal.tres, stone_chip.tres]
          dialogue: 1 found in res://data/dialogue -> [gardener.tres]
          schedules: 1 found in res://data/schedules -> [keeper.tres]

exported  origin: template=true editor=false debug=true exe=game.exe
          items: 3 found in res://data/items -> [rose_key.tres, rose_petal.tres, stone_chip.tres]
          dialogue: 1 found in res://data/dialogue -> [gardener.tres]
          schedules: 1 found in res://data/schedules -> [keeper.tres]
          Session ended after 1.3s - 0 warnings, 0 errors
```

(Paths abbreviated to their file names here; the real lines carry the full `res://data/...` path,
which is the point — a partial ship is worse than an empty one and only the paths show it.)

Run from a scratch directory holding only `game.exe`, `game.console.exe` and `game.pck` — no
`project.godot`, no loose `data/`. The exported build also USED the content:
`--give=item/rose_key,item/rose_petal:3` logged `+1 item/rose_key` and `+3 item/rose_petal`, so the
definitions loaded through the pack's `.remap` indirection rather than merely being counted.

Both new gates proved RED before green (gotcha 23):

```
[editable] line deleted     !! courtyard.tscn:337 overrides 'Actors/Keeper/PersistentState'
                               inside the instance 'Actors/Keeper' with no
                               [editable path="Actors/Keeper"] - the override is DROPPED in an
                               exported build       (+3 more)   FAIL - 4 content violation(s)

REQUIRED_FILTER = "scenes"  FAIL the preset ships every resource, not only dependencies
                            - expected scenes, got all_resources               exit 1
```

And the readout itself was proved to fail, which is the part no gate can do —
`exclude_filter="data/*"` exported and booted cleanly to the main menu:

```
items: 0 found in res://data/items -> []
[WARN] items catalogue is EMPTY in an exported build - check export_filter   (x3)
Session ended after 1.5s - 3 warnings, 0 errors
```

**The four measured facts.** `export_filter="all_resources"` stores all seven `data/**` resources;
`export_filter="scenes"` stores **zero**. `ResourceLoader.list_directory()` works through the pack
— it returns the `.tres` path for a stored `.tres.remap`, which is the first evidence ADR-0006's
choice of the undocumented method was right. `include_filter="*.tres"` is the plausible wrong fix:
the include filter is for NON-resource files and changes nothing. And a narrowed `export_filter`
fails LOUDLY, not silently — it also strips the `class_name` scripts nobody depends on
(`GameConfig`, `GameEnums`, `DictRead`, `KeyBindings`) and the build dies at boot on parse errors.
The silent version needs an *exclude* filter, which is why the readout warns rather than only
reporting.

**The second defect, which is why running this early paid for itself.** The exported build printed
three lines the editor never did: `Keeper has a PersistentState with no object_id`, `Talk has no
label_key`, `Talk names no conversation`. `courtyard.tscn` overrode those properties on nodes
INSIDE its instanced `npc.tscn` with no `[editable path="Actors/Keeper"]`. The text loader applies
such overrides; the export's `.tscn` → binary `.scn` conversion DROPS them. So the demo's NPC
shipped with no identity, no prompt and no conversation, and its schedule never ran — while every
rung, both CI jobs and 930 assertions stayed green throughout. Stale `index=` values were the first
hypothesis and were ruled out by correcting them (4,5,6,7 → 3,4,5,6) and re-exporting: no change,
same three lines. Adding the marker fixed it completely, including
`obj/courtyard/keeper/waypoint = dais` reappearing in the log.

**Setup, recorded because it is not obvious.** No export template was installed. They come only in
`Godot_v4.7.2-stable_export_templates.tpz` (1.28 GB); the four Windows x86_64 files plus
`version.txt` were extracted into `%APPDATA%/Godot/export_templates/4.7.2.stable/`.
`--export-pack` needs no template at all and is enough to see WHICH files ship; only a real
template proves they are FOUND at runtime, which is the actual question.

**Unblocks.** T2.1 (art contract seams) can now be built on a content pipeline proven end to end
rather than assumed. Every package after this one inherits a working preset and a boot-time readout
that makes a content regression visible in the one place it was previously invisible.

**Gaps.**
- **No CI export rung.** A GPU-less runner has no platform template. Same honesty as T1.4's stance
  on the windowed capture: stated as impossible, not quietly dropped.
- **Windows only.** Other platforms each need their own template and are a consuming game's call.
- **The readout is debug-only, by design.** A release export prints nothing, so verifying a release
  build's content would need a different mechanism. Nothing needs it yet; noted so the absence is a
  decision rather than an oversight.
- **The `[editable]` gate reads text.** Same limit as `check_boundary`: a scene assembled at
  runtime, or an override written by a tool, is invisible to it.
- **`tools/check_content.gd` is at 237 of 250 code lines.** The next check added to it will not
  fit, and the seam is already visible: the scene checks are a different question from the
  content-registry checks.

**CI green**, run [32995130430](https://github.com/Raiyan-Bashar-29/HD-2D-game-base-non-combat-/actions/runs/32995130430), both jobs: `930 passed, 0 failed, 0 skipped` full and `880 passed, 0 failed, 12 skipped` stripped — the hand-run numbers exactly.

---

## 2026-08-27 — T2.1 · Art contract seams

**Did.** Moved the two things that made "a second, visually different game starts from this
without editing `src/`" false: the sprite sheet's dimensions, and the UI's look. Both are now
authored data, and both were proved by swapping something and looking at the result.

- `src/content/art/sprite_sheet_layout.gd` — new, 34 code lines. `facings`, `frames`,
  `animations`, `cell_size`, `idle_row`, `walk_row`, plus `sheet_rows()`, `sheet_size()`,
  `sector_radians()`, `column_for_angle()`, `animation_for()`, `frame_index()`, `problems()`.
- `src/gameplay/character/character_visual.gd` — `FACING_COUNT`, `FRAME_COUNT`, the literal
  `TAU / 8.0` and `_cell_height()` all gone; a `layout` `@export` in their place, and every
  dependent number read from it. 95 → 107 code lines.
- `assets/placeholder/character_layout.tres` — the old constants, moved out unchanged: 8x4, 32x48.
- `assets/placeholder/character_alt_layout.tres` + `character_alt.png` — 4 facings, 3 frames in
  2 blocks, 24x40. Disagrees with the default on every number, which is the point.
- `assets/theme/ui_theme.tres` — new, wired as `gui/theme/custom`. Nine type variations carrying
  font sizes, a `UiPalette` of four colours, a `UiMetrics` of six insets.
- The five styled files — `menu_screen.gd`, `dialogue_screen.gd`, `inventory_screen.gd`,
  `hud_clock.gd`, `loading_indicator.gd` — now hold no colour and no font size of their own.
- `tools/gen_placeholders.gd` — `_build_alt_sheet()`, 95 → 129 code lines.
- `tests/unit/art_contract_test.gd` — 83 assertions. Suite 930 → **1013**.
- `scenes/characters/player.tscn`, `npc.tscn` — the layout wired; inventory, roadmap, board.

**Why.** `FACING_COUNT = 8` and `FRAME_COUNT = 4` were constants in `CharacterVisual`, and the
sector maths was a **separate literal `TAU / 8.0`** that had to agree with them by hand. Two
places holding one number, and a game with a four-facing sheet would have needed a code edit —
the one thing a template must never ask for. There was no animation-row offset either, so
idle-versus-walk was not unimplemented but *structurally impossible*: one cycle, nowhere to put a
second. Meanwhile the UI look was constants in five screen files with the accent colour written
out three times in two slightly different values, so a restyle was five edits that would drift and
a consuming game had nowhere to put its own look but a fork of the screens.

**Connects.** The layout lives in `src/content/` because it is a data shape, so anything may read
it, and like `item_definition.gd` it touches no autoload — `tools/` loads content classes under
`--script`, where autoload identifiers do not resolve, so one `Log` call there would break a build
gate. `SpriteSheetLayout` was checked against the API dump first (`AudioBusLayout` is the only
near-miss; `Resource` declares none of the six field names) — the fifth time this project has
gone looking after `Area3D.priority`, `class_name Container`, `DictRead.get_name` and
`ItemDb.reload()`. The theme goes through `gui/theme/custom` rather than being handed to
`UiRoot`, so it reaches the HUD too — which is drawn *under* `UiRoot` and would otherwise have
been missed. Assertions for the pure functions, a capture for the picture: the same division
`export_test.gd` drew in T2.0 when it asserted its own blindness rather than implying it.

**A FACING IS NOT A COLUMN, and the obvious implementation re-creates the bug.** Mapping
`GameEnums.Facing` down onto `layout.facings` — `int(facing) * facings / 8` — puts the number 8
back in the code in a second place, exactly where it was. So the two are quantised *separately
from the same angle*: `_facing` from `GameEnums.Facing.size()`, because eight is how many
directions the **game** reasons about, and `_column` from `layout.facings`, because that is how
many the **art** distinguishes. Neither reads a literal, and when `facings == 8` they agree by
construction — which is why nothing about the existing sheet moved.

**THE PALETTE IS NOT COPIED INTO THE VARIATIONS, and that is the whole design.** A `Theme` has no
variables, so a colour repeated into nine variations is nine places to change and "one Theme edit
restyles every screen" would be false. The variations carry only `font_size`, the one thing that
genuinely differs by role; the screens read the four colours and six insets by name. It costs a
`get_theme_color` call per screen and buys the criterion outright.

**Three values were deliberately UNIFIED, and this is the package's only visual change.** The
dialogue box's dim was `0.03, 0.02, 0.05, 0.72` against the inventory's `0.04, 0.03, 0.06, 0.78`;
its speaker tint `0.90, 0.78, 0.55` against the others' `0.86, 0.74, 0.52`; its hint 16pt against
18. Nobody chose those differences — they are duplication, and preserving them would have meant
palette entries that exist to keep a typo. Two column separations moved 2px and 4px likewise.

**Verified.** Both criteria are visual claims and neither is an assertion.

```
--headless --import                       exit 0, ZERO SCRIPT ERROR / Parse Error lines
--headless --quit-after 120               Session ended after 1.3s — 0 warnings, 0 errors
tests/test_runner.tscn --quit-after 400   1013 passed, 0 failed, 0 skipped   exit 0
tools/check_budgets.gd                    exit 0
tools/check_content.gd                    exit 0   (still 237/250; nothing added to it)
tools/check_boundary.gd                   exit 0
--resolution 960x540 ... --time=18:40     looked at; unchanged from before the refactor
```

*Criterion 1 — a sheet with a different cell and frame count, no code changed.* Two `ExtResource`
paths in `player.tscn` repointed at the alt pair, nothing else, reverted after. The probe and the
picture agree exactly:

```
default, standing   frame=0/32   size_px=(256.0, 192.0)
alt,     standing   frame=0/24   size_px=(96.0, 240.0)
alt,     walking    frame=19/24  size_px=(96.0, 240.0)
```

`frame=19` decodes to row 4, i.e. block 1 (walk), frame 1, column 3. The zoomed capture shows the
orange walk-block body, **four** pips down the left edge, **two** along the foot, no eyes, and
legs offset — block 1, frame 1, column 3. `(1*3 + 1) * 4 + 3 = 19`. Standing, the same crop showed
the green idle body with one pip each way and eyes. The NPC beside the player kept the 8x4 sheet
throughout, which is the incidental proof that a layout is per-node and not global.

*Criterion 2 — one `Theme` change restyles every screen.* Six lines of `ui_theme.tres` and no
other file: `text` white → near-black, `accent` gold → deep red, `dim`/`solid` near-black →
parchment, `margin` 64 → 120, `TitleText` 40 → 56. Captures before and after of the main menu and
of the inventory screen over a frozen world. Both restyled completely; the HUD clock followed
without being mentioned. Reverted.

*Both new gates proved RED before green (gotcha 23).* Putting
`add_theme_font_size_override(&"font_size", 22)` back in `hud_clock.gd` — the exact regression the
gate exists for — gave `FAILED: hud_clock.gd writes down no font size — expected 0, got 1`, exit 1.
Changing `frames = 3` to `4` in the alt layout gave `FAILED: the alt layout is 3 frames in 2
blocks — expected [3, 2], got [4, 2]` plus `FAILED: the two layouts disagree on the frame count`,
exit 1. Both reverted, both green.

**A temporary probe, added and removed as gotcha 15 prescribes.** `CharacterVisual.describe()`
had existed with no caller since Phase 0, so no run had ever printed which cell was drawn. A
`_temporary_t21_probe()` in `dev_capture.gd` logged it at the shutter and a `_temporary_t21_walk()`
pressed `move_left` twelve frames before the shot — an assertion cannot press a key and
`TestCase.run()` never reaches a frame. Both quoted above, both removed;
`git diff src/systems/debug/dev_capture.gd` is empty.

**EVERY CELL OF THE ALT SHEET IS SELF-LABELLING, because gotcha 2 has a sharper form here.** A
day/night system that lights nothing is at least obviously wrong on screen. A character drawn from
the *wrong cell* still looks like a character — upright, lit, facing *some* direction. So the
capture cannot be judged, it has to be read, and each cell carries `column + 1` pips down its left
edge and `frame + 1` along its foot with a different tint per animation block. That is what made
`frame=19` a checkable prediction rather than a number to take on trust.

**Unblocks.** T2.2 can now document an art contract that exists rather than describing intent —
`ART_CONTRACT.md` is `SpriteSheetLayout`'s header plus the theme's, and both were written to be
read by a consuming game. A game with four-direction art, or a six-frame cycle, or a separate idle
needs no engine change. And the environment post-stack, the shared materials and the per-area
camera exports left below all now have a worked precedent for the shape they should take.

**Gaps.**
- **The theme does not set the `Button` styleboxes**, so `MenuRow` and `ChoiceRow` still draw
  Godot's default dark panel. The parchment capture showed it plainly: every row stayed
  dark-on-light while the rest of the screen restyled. The seam is right and in the same file
  (`MenuRow/styles/normal`), it is simply unpopulated — and a consuming game with a light palette
  hits it immediately, which makes it T2.2's business to say so at minimum.
- **Five of the roadmap's nine T2.1 items are left**, in its own order, because the package hit
  its file budget: shared materials, the environment post-stack as `@export`s, per-area camera
  exports, the texture import defaults and the Git LFS lines. Half-doing five seams is worse than
  finishing two.
- **The texture import defaults have a reason beyond budget.** `[importer_defaults]` is an
  undocumented editor-managed section — absent from `--headless --doctool` — so it cannot be
  checked against the API dump the way this project requires, and hand-authoring an undocumented
  format is exactly the kind of change that looks applied and does nothing. The per-file values
  already committed are correct for pixel art. One latent hazard worth naming for whoever picks it
  up: every `.import` carries `detect_3d/compress_to=1`, and these sheets *are* used in 3D, so a
  re-import could switch them to VRAM compression and put block artefacts through pixel art.
- **The Git LFS lines stay commented, deliberately.** The `.gitattributes` comment is right: LFS
  pointers for a 2 KB placeholder are pure overhead, and enabling them would put the CI checkout
  on a dependency it does not currently have. Enable when real art arrives, which is what it says.
- **`animations` is authored, not inferred.** A layout claiming more blocks than the sheet has is
  caught by `problems()` only when a texture is supplied, which `CharacterVisual` does and a bare
  `.tres` review does not.

**CI green**, run [32998836688](https://github.com/Raiyan-Bashar-29/HD-2D-game-base-non-combat-/actions/runs/32998836688), both jobs: `1013 passed, 0 failed, 0 skipped` full and
`963 passed, 0 failed, 12 skipped` stripped — 880 + 83, reproducing T2.0's stripped number exactly.
All 83 new assertions run in a stripped template, because the case names `assets/` and never `data/`.

## 2026-08-27 — T2.2 · Consumer documentation

**Did.** Wrote the four documents a consuming game needs, and then closed Phase T2's last exit
criterion by *performing* it rather than claiming it.

- `docs/AUTHORING.md` — new. Task-first: add an area, an interactable object, an item, a
  conversation, an NPC. The ten required children of an area root, a complete minimal area
  written out in full, the navmesh settings that will otherwise strand an NPC, the
  `[editable path=...]` trap, the localization rules, the debug flags that drive the game, and a
  table of what each gate catches.
- `docs/ART_CONTRACT.md` — new. The sheet grid (facings across, frames down, grouped into
  animation blocks), the declared-not-derived cell size, the `Sprite3D` settings and what they
  demand of the art, the import settings and the `detect_3d/compress_to` hazard, the theme's
  three-way split, and the `Button` stylebox gap stated plainly.
- `docs/TESTING.md` — new. The five rules of this suite that each cost an hour: it is a scene,
  `run()` is synchronous, every case declares a plan, the plan is provably not enough on its own,
  and an unlisted case never runs. Plus the fixture rule and how to prove a gate.
- `docs/ARCHITECTURE.md` — a new § **The extension surface**, three tiers. Also corrected: the
  area diagram listed eight children and was missing `Navigation/` and `Waypoints/`; two "known
  limitations" had been false since T2.0 and WP-13.
- `tests/unit/docs_test.gd` — new, 68 outcomes, computed. Suite 1013 → **1081**.
- `CLAUDE.md` — the flat "Read next" list becomes a doc-router table. `docs/CONTEXT.md` — same.
- `docs/SYSTEMS_INVENTORY.md` — two new rows, and the area-root row corrected to ten children.

**Why.** Everything this template can do was documented in **file headers**. They are excellent,
and they are the wrong shape for a consumer: a header is found by already knowing which file to
open. Nothing started from "I want to add an area" and ended at a working area, and the extension
surface — which classes a game may subclass and which are the engine's own business — did not
exist anywhere at all, which is the thing most likely to be got wrong by someone moving fast.

**Connects.** T1.2 wrote `NEW_GAME.md` (what to delete); this is what to write afterwards. T2.1
wrote two headers deliberately aimed at a consuming game, `sprite_sheet_layout.gd` and
`ui_theme.tres`; `ART_CONTRACT.md` is their consumer-facing form and carries the one gap T2.1
left. `TESTING.md` is T1.3's two crash mechanisms and the fixture rule, written for someone who
was not there.

**Verified.** The criterion was PERFORMED. A new area, a new NPC with a schedule and a new
four-node conversation were authored from `AUTHORING.md` alone — nothing copied from an existing
area, and `src/` not consulted while writing them. Full ladder green with the new content in:
import exit 0 with zero `SCRIPT ERROR` / `Parse Error`, boot `0 warnings, 0 errors`,
`1101 passed, 0 failed, 0 skipped`, all three checkers exit 0 — `check_content` including the
`[editable]` gate. The capture was looked at: the NPC stands in the new area with the dialogue box
open on its first-meeting line, speaker name resolved. Then the content was **deleted** — it was a
test of the documents, not new demo content, and `TEMPLATE.md` is explicit that the demo does not
get deepened. Final ladder after deletion: `1081 passed, 0 failed, 0 skipped`, everything else
green, and the demo courtyard capture at 18:40 unchanged.

**Six defects the walkthrough found**, each fixed:

1. The documented capture command never leaves the main menu. `--shot` alone photographs the
   title screen — the first PNG produced in this package is the menu. `--new-game` is required,
   and no document mentioned the debug harness flags at all. Now a table of eight.
2. The gate table claimed the boot rung catches "an unresolvable first area". It does not:
   `--headless --quit-after 120` stops at the menu, loads no area, and still reports
   `0 warnings, 0 errors`. Gotcha 22's family — a rung reporting clean about work it never did.
3. `--stand-by=` takes a NODE NAME, not an `object_id`, and the id is what the document had just
   told the author to set. `--stand-by found no node called 'ferryman_talk'`.
4. The NPC placement example omitted its own `[ext_resource]` line, so it could not be used as
   written.
5. The navmesh example implied a healthy bake is a big number. A flat floor bakes **2** polygons.
6. The suggested capture hour, 18:40, renders a propless new area very nearly black — which looks
   exactly like a lighting bug.

Two things it confirmed rather than corrected: an override on a node inside an instance needs no
`index=` (the name resolves it — the stale indices in the courtyard really were the red herring
T2.0 called them), and one `[editable path=...]` covers both overridden children of one instance.

**The gate was proved red twice, once by accident and once on purpose (gotcha 23).**

Accidentally, on its first run — and this is why `DEVLOG.md` is now exempt from the path scan:

```
FAILED: DEVLOG.md names res://tests/unit/zz_probe_test.gd, which exists — expected true, got false
```

That path is a temporary probe T1.3 created to prove the runner fails on a crash, quoted by name
and then correctly deleted. A history necessarily names files it removed on purpose. Everything a
reader is meant to *follow* is still scanned.

Deliberately, with two planted violations — renaming `walk_row` in `ART_CONTRACT.md`'s worked
layout, and repointing one script path in `AUTHORING.md` at a file that does not exist:

```
=== 1074 passed, 6 failed, 0 skipped ===
FAILED: AUTHORING.md names res://src/content/items/item_definition_moved.gd, which exists — expected true, got false
FAILED: ART_CONTRACT.md documents sprite_sheet_layout.gd.walk_row_renamed — expected true, got false
FAILED: AUTHORING.md documents item_definition_moved.gd.id — expected true, got false
FAILED: AUTHORING.md documents item_definition_moved.gd.name_key — expected true, got false
FAILED: AUTHORING.md documents item_definition_moved.gd.category — expected true, got false
```

Exit 1. Both reverted: `1081 passed, 0 failed, 0 skipped`, exit 0.

**Why a test for prose at all, and what it deliberately does not do.** Most of this package is not
assertable and a test that restated the prose would be worse than none. But two things in a
consumer document are facts about this repository and both rot in silence: a `res://` path that no
longer resolves, and a field name in a worked example that was renamed. Both are found by a
reader, once, following the document into a dead end and concluding the template is broken. The
class-to-property mapping is read out of each fenced block's own script `ext_resource` lines
rather than from a list in the test, so there is no second list to go stale. Paths under the
content roots are skipped when absent, because a stripped template has deleted exactly the files
`docs/` teaches by example with.

**The `Button` stylebox gap was left unfixed, on purpose.** One addition to `ui_theme.tres`, no
code, and tempting. But a stylebox has to be *designed*, and the only palette to design against is
the placeholder one — so it would be a decision shipped as a default, from the package whose job
is to describe the template honestly rather than change it. Stated instead in the three places a
consumer reaches: `ART_CONTRACT.md`, `ARCHITECTURE.md`'s limitations, `CONTEXT.md`. The menu
capture taken during the walkthrough shows it: every row drawing Godot's default dark panel.

**Unblocks.** Phase T2 is complete — all four exit criteria ticked. A consuming game can now strip
the template (`NEW_GAME.md`), author content (`AUTHORING.md`), bring art (`ART_CONTRACT.md`), keep
the suite honest (`TESTING.md`) and know what it may extend (`ARCHITECTURE.md`).

**Gaps.** The documents cover authoring, art and testing; they do **not** cover saving, settings,
audio or the flag namespace, because a consuming game does not author those. Whether that stays
true is a question for the first real game. `docs_test.gd` checks that documented paths and fields
*exist*; it cannot check that a documented *sentence* is true — the walkthrough is the only thing
that does, and it has to be redone by hand whenever the authoring surface changes. Nothing yet
describes how a game already forked from this base receives a later fix to it; that is Phase T4.
And the five T2.1 leftovers are still open — shared materials, the environment post-stack and
camera framing as `@export`s, the texture import defaults, the LFS lines — now documented as open
seams rather than silently absent.

**CI, both jobs, run 33086307621.** Full checkout: `1081 passed, 0 failed, 0 skipped`. Stripped
template: `1027 passed, 0 failed, 16 skipped` — up from T1.3's twelve, and the four new skips are
exactly the doc-named paths under the content roots, which a stripped checkout has correctly
deleted. `check_budgets`, `check_content` and `check_boundary` PASS in both. That the same
documents pass in a template with no game in it is a better proof of the skip design than the
assertion for it would have been.

---

## 2026-08-27 — WP-08 · Quests

**Did.** Built the quest system: two content `Resource`s, the fourth directory-scan registry, a
tracker that turns flag changes into progress, a journal screen on `J`, one placeholder quest, and
49 new assertions. Extracted the `FlagTest` evaluator into `FlagQuery` so a dialogue condition and a
quest step share one implementation. Split `tools/check_content.gd`, which had 13 lines of budget
left. Phase T3's first package.

**Why.** Quests were the one system in the catalogue with **no proof at all**, and Phase T2's
replacement for the retracted "depth before breadth" is breadth of systems, one shallow proof each.
Everything a quest needs already existed and nothing joined it up.

**The decision the package turns on: a step names a FLAG CONDITION, never a callback.** Same closed
set of six comparisons a dialogue condition uses. Two consequences, and both are the point:

1. **A quest is authored data.** Adding the fiftieth touches no code, which is ADR-0006's test.
2. **Nothing has to know quests exist.** The placeholder quest is built entirely out of flags the
   demo was already writing: a conversation effect (`met/gardener`) starts it, the courtyard lever
   (`area/courtyard/gate_unlocked`) advances it, the dais trigger volume
   (`area/courtyard/dais_entered`) completes it. **None of those three files was touched.** That is
   the trigger-volume rule — a trigger never names its consequence — applied to narrative state.

**Derived, except for two latches.** `flags.gd`'s own header says derive what can be derived, and
almost all of this is: the current objective is the first step whose test fails, asked live every
time a flag moves. Two things genuinely cannot be derived. That a quest **started** — its start
condition is a flag, and clearing that flag must not un-give a quest carried for three hours. That
a quest **completed** — a step may test `AT_LEAST 3` on a counter, and a later decrement must not
reopen a finished quest. Those two are the whole save section, held as **two lists of quest ids**;
never an enum ordinal, which is the ADR-0005 rule this project has already been bitten by. The
current objective is deliberately NOT latched, so clearing the flag behind objective two on an
active quest brings objective two back. Both halves are asserted — a latch nothing tests is
indistinguishable from a cache.

**A completed quest grants nothing.** It emits `Events.quest_completed` and stops. A `reward_item`
field would put `Inventory` and a player — both `gameplay` — inside a `systems` tracker, and `src/`
points downward only. Anything that wants to hand over an item listens to the signal; anything that
wants to gate a conversation tests the flag the last step tested, with no code at all.

**FlagQuery was extracted rather than copied.** `DialogueRunner._passes` was the only evaluator of
`FlagTest`; a quest step asks the identical question with the identical meaning, and a second copy
of a rule eventually disagrees with the first — the failure would surface as a quest that will not
complete for a flag a conversation is perfectly happy with. Same reasoning that makes a weather
emitter be TOLD its weight rather than read `Weather`, and a theme colour live once rather than per
variation. `quests_test.gd` fails if the table grows back in either file, which is the gate
`art_contract_test.gd` established for sheet dimensions.

**The fourth registry came due on a note `schedule_db.gd` left, and it was reconsidered rather than
ignored.** That header said "three is a pattern, four is a problem — if a fourth registry appears,
that is the moment to reconsider." Reconsidered; verdict: keep the copy. GDScript has no generics,
so a shared base could only cache `Resource` and hand it back untyped, making `definition()`,
`conversation()`, `schedule()` and `quest()` a cast at every call site — and static typing is
non-negotiable #2, not a preference. What IS genuinely shared already is shared: `QuestDb` calls
`ItemDb.resource_paths()` rather than copying the `.remap` handling. The refactor that would pay is
a base holding the cache plus a thin typed façade each, which touches four registries and four
areas of the suite. It is **T3.1 on the board** with the reasoning, not a shrug.

**`check_content.gd` split, and the seam was already in the reasoning.** 237 of 250, and the quest
checks did not fit. `tools/content_scenes.gd` takes the scene *text* scans (duplicate `object_id`,
`_key` literals, the `[editable]` marker) — they need no class registered and keep working on a
scene that is broken for an unrelated reason; what stayed asks the *registries* what they loaded.
Still one command and one CI rung: it is a `RefCounted` the entry point instantiates, not a second
`SceneTree` tool. 237 → 178 + 102. Fifth split the budget checker has exposed.

**The quest checks print the flags rather than validating them.** A flag can be written from a
scene, a conversation, a path action or another quest, and the writer that matters most is a runtime
one — `PersistentState` builds `obj/<area>/<object>/<field>` at load. A checker that failed on any
flag with no findable writer would be wrong most times it fired, and a partial check that looks
complete is exactly what this project exists to prevent. So they go where a reviewer reads them:

```
  quests: 1
     quest/keepers_errand   2 steps, starts on met/gardener is_true
        unlock              done when area/courtyard/gate_unlocked is_true
        dais                done when area/courtyard/dais_entered is_true
```

**Connects.** `Events.quest_started` / `quest_advanced` / `quest_completed` were declared in Phase 0
and had no emitter and no listener until now; the tracker emits all three and the journal listens to
all three. `Flags` gains its first derived consumer. `SaveSystem` gains a fifth participant.
`ScreenKeys` gains the journal binding its own header predicted would land there rather than in a
file of its own. `CatalogueReport` gains the fourth row it said a fourth registry would cost.
`Fixtures` gains the fourth redirect. `Actions.JOURNAL` had existed unbound since Phase 0.

### Verified

**Ladder, all green.** `--headless --import` exit 0, **zero** `SCRIPT ERROR` / `Parse Error` lines
(gotcha 22 — the boot rung cannot see those). Boot `--quit-after 120`: `0 warnings, 0 errors`, with
`quests: 1 found in res://data/quests -> ["res://data/quests/keepers_errand.tres"]` and
`Quest tracker ready over 1 quest(s)`. Suite: **1149 passed, 0 failed, 0 skipped**, exit 0 (1081 →
1149: 49 in `quests_test.gd`, 2 in `export_test.gd` for the fourth catalogue line, and 17 more that
`docs_test.gd` COMPUTED from the new worked quest example in `AUTHORING.md` — the docs gate
covering its own new content, which is what a computed plan is for). `check_budgets`,
`check_content` and `check_boundary` all exit 0.

`check_boundary` now derives `quest/keepers_errand` and `keepers_errand` among its 14 demo names and
finds neither in any of the 104 engine scripts it scans:

```
  demo names derived: 14 — ["courtyard", "lantern_hall", "talk/gardener", "gardener",
  "item/rose_key", "rose_key", "item/rose_petal", "rose_petal", "item/stone_chip", "stone_chip",
  "quest/keepers_errand", "keepers_errand", "schedule/keeper", "keeper"]
  engine scripts scanned: 104 ... PASS
```

**GATE ONE PROVED RED, THEN GREEN (gotcha 23).** The real authoring mistake, not a convenient one:
one letter added to a step's `summary_key` in the authored quest.

```
  quests: 1
     quest/keepers_errand   2 steps, starts on met/gardener is_true
        dais                done when area/courtyard/dais_entered is_true
  !! quest/keepers_errand/dais summary_key 'quest.keepers_errand.step.daiss' is not in the CSV
FAIL — 1 content violation(s)
PLANTED exit=1
```

Reverted:

```
PASS
REVERTED exit=0
```

**GATE TWO PROVED RED, THEN GREEN.** The failure `FlagQuery` exists to prevent: a second copy of the
comparison table appended to `dialogue_runner.gd`.

```
FAIL and it no longer carries its own copy of the comparison table — expected false, got true
=== 1148 passed, 1 failed, 0 skipped ===
PLANTED exit=1
```

Reverted:

```
=== 1149 passed, 0 failed, 0 skipped ===
REVERTED exit=0
```

**ONE DEFECT, FOUND BY THE CAPTURE AND BY NO GATE.** `--flag=` set its flag during argument parsing,
and `--new-game` **clears every flag** — so the first capture photographed a journal with no quest
in it, and the run reported `0 warnings, 0 errors` throughout. The log is what shows it: the
`--flag` line lands *before* `Quest tracker ready`, and no `quest/keepers_errand: started` line
follows.

```
21:47:01 [INFO ] [test  ] --flag met/gardener = true by command line
21:47:01 [INFO ] [quest ] Quest tracker ready over 1 quest(s)
21:47:01 [INFO ] [test  ] --new-game requested 'courtyard'
21:47:02 [INFO ] [test  ] --open-menu journal pushed: true
```

`_force_flag` now waits for the area the way `_open_menu` does, and the same run reads:

```
21:47:50 [INFO ] [quest ] quest/keepers_errand: started [&"quest/keepers_errand"]
21:47:50 [INFO ] [quest ] quest/keepers_errand: advanced [&"quest/keepers_errand", &"unlock"]
21:47:50 [INFO ] [test  ] --flag met/gardener = true by command line
21:47:50 [INFO ] [test  ] --open-menu journal pushed: true
```

This is gotcha 31's family: not a rung blind to an error, but staging that ran before the thing it
was staging for. Worth knowing for any future `--` flag that poses state a `--new-game` resets.

**THE INPUT PATH, PROVED BY A TEMPORARY PROBE, THEN REMOVED** (gotcha 15 — `TestCase.run()` is
synchronous, so no assertion can press a key). Added to `dev_stage.gd`, run windowed with real
`InputEventAction`s, and deleted; `git diff src/systems/debug/` shows only the `--flag` addition.
The probe, verbatim:

```gdscript
## TEMPORARY WP-08 PROBE. Removed before the package closed; quoted verbatim in DEVLOG.md.
func _probe_journal_key() -> void:
	await _wait_for_area()
	for _i: int in 40:
		await get_tree().physics_frame
	var stack: UiRoot = UiRoot.find(self)
	Log.info("test", "PROBE before: depth=%d top=%s" % [
		stack.depth(), stack.top().screen_id if stack.top() != null else &"NONE"])
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = Actions.JOURNAL
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().physics_frame
	Log.info("test", "PROBE after press: depth=%d top=%s" % [
		stack.depth(), stack.top().screen_id if stack.top() != null else &"NONE"])
```

Its output, from `--resolution 960x540 --quit-after 200 -- --new-game --flag=met/gardener:true
--probe-journal-key --time=12:00 --freeze-time`:

```
PROBE before: depth=0 top=NONE
PROBE after press: depth=1 top=journal
PROBE after second press: depth=0 top=NONE
0 warnings, 0 errors
```

So `J` opens the journal and `J` closes it, through `_unhandled_input` and the real action, and the
toggle only fires while the journal is itself on top.

**TWO WINDOWED CAPTURES, LOOKED AT.** Both at midday, `--new-game --shot-frame=70 --quit-after 90`,
because no ordinary run enters an area (gotcha 31) and a new capture at 18:40 renders near-black.

1. `--flag=met/gardener:true --open-menu=journal` — the journal over a live courtyard: **Journal /
   Underway / The Keeper's Errand / — Unlock the north gate.** with the **New errand: The Keeper's
   Errand** toast at the top and *Escape to close* at the foot. The world, the player and the keeper
   are visible through the translucent dim, which is how the capture shows the screen stopped the
   world rather than replaced it.
2. All three flags — the same screen reading **Settled / The Keeper's Errand / — Nothing left to
   do.** A third run at `--shot-frame=300 --quit-after 340` catches the second toast in the queue,
   **The Keeper's Errand is settled**, since the *New errand* toast holds the first three seconds.

**The `Button` styleboxes were left unpopulated, deliberately, and the captures are why the claim is
checkable.** The journal's rows draw Godot's default dark panel — visible in both PNGs as the wide
bordered bars. Legible against the shipped dark palette, so the journal did not force the decision,
and T2.2's reasoning for not shipping a guessed stylebox holds. Stated, not silently skipped.

### Unblocks

WP-11's map markers (a marker is a listener on `quest_advanced`, which now has an emitter), WP-09's
plot gating (a chapter is a quest start condition), and any consuming game's main narrative spine.
T3.1, the registry refactor, is now scoped by an actual fourth copy rather than by anticipation.

### Gaps

- **A QUEST STEP CANNOT READ AN ITEM COUNT, and the original exit criterion "completed by an item
  handover" is therefore NOT met.** `Inventory` keeps counts, not flags. This is the honest cost of
  "a step is a flag condition", and the seam is a `Pickup` or `ItemContainer` that writes a flag —
  a template change, recorded in `ARCHITECTURE.md`'s limitations and in `AUTHORING.md` § Add a
  quest so an author hits the note before the wall, rather than routing around it under `src/`.
- No branching, no failure state, no timed quests, no rewards beyond a flag, and no sorting,
  filtering or detail pane in the journal. One shallow proof; `TEMPLATE.md` is explicit that the
  demo does not get deepened.
- `quest_advanced` fires on the frame a quest starts as well, because the first objective becoming
  current IS an advance and a marker needs to hear it. Only the TOAST is suppressed there. Correct,
  and worth knowing before writing a listener that assumes the two are exclusive.
- The tracker is a node in the boot scene, so a game that replaces `game_root.tscn` loses quests
  silently. `CatalogueReport` sits there on the same terms and neither is asserted to be present.

**CI green, run 33091433887, job logs read rather than the tick** (gotcha 26 — the run listing lags
and the tick is not the evidence). Full checkout: **1149 passed, 0 failed, 0 skipped**, with
`quests: 1` in `check_content`. Stripped template: **1094 passed, 0 failed, 16 skipped**, with
`quests: 0` — an empty quest folder is not an error, which is T1.2's finding holding for the fourth
registry the day it was added. All three checkers PASS in both jobs, and the skip is named rather
than silent:

```
SKIPPED: quests_test: authored quests validate (this checkout has no quests in data/quests)
  — 0 assertion(s) not run
```

Zero rather than one because `quests_test.gd`'s plan is COMPUTED from the number of authored quests
(`transitions_test.gd`'s shape, sanctioned in `docs/TESTING.md`), so a stripped run's plan is
already smaller by exactly that assertion — the skip is there to SAY it gave one up, not to pad a
count. The push run (33091433975) and the pull-request run (33091486449) are green as well.

**Commit `a00ddda` on `claude/wp-08-quests`, PR #16**, stacked onto `claude/t2-2-consumer-docs`
(#15) rather than `main`, matching the rest of the chain.

---

## 2026-09-01 — T3.2 · The five art-contract seams T2.1 left

**Did.** Closed the five items T2.1 deferred. Four built — a shared material library, the
environment post stack as `@export`s, per-area camera framing actually used, and the texture
importer defaults — and one, Git LFS, refused in writing with the reason and the turn-on steps.
Then removed the four surplus mentions: each of the five now appears in exactly one document,
`ART_CONTRACT.md`, and the historical package sections say "closed by T3.2" instead of restating a
state that has moved.

**Why.** Two reasons, and the second is the one that made this a package rather than a chore.

The first is the obvious one: `ART_CONTRACT.md` told an artist that an area's materials and an
area's camera are authored per area and that this "works and duplicates", which is a template
saying out loud that it has an unfinished seam.

The second: these five were named in `CONTEXT.md`, `ROADMAP.md`, `WORK_PACKAGES.md`,
`ARCHITECTURE.md` and `ART_CONTRACT.md`. **A backlog item mentioned in five places is not tracked
five times. It is tracked zero times and described five times, and the descriptions drift.** The
proof that they had drifted is seam 3 below: four documents agreed the per-area camera seam did not
exist, and it had existed since the rig was written. Nobody had opened the file in six packages.

### 1. Shared materials — built, and the defect was already in the tree

`assets/materials/wood.tres`, an `ExtResource` in both area scenes. The two demo areas each carried
a **byte-identical** `StandardMaterial3D` called `m_wood` — `wood.png`, `texture_filter = 0`,
`uv1_scale = Vector3(2, 2, 1)` — and no file could see the other.

A library of **one**, deliberately. The other five materials across the two areas are not
duplicates: the courtyard tiles stone at `(3, 3)`, the hall floors it at `(8, 8)` and walls it at
`(6, 2)`. **A tiling rate is a property of the surface it is stretched over, not of the substance**,
so hoisting those would produce a shared file with a per-area override on every user — the
duplication with an extra indirection, and a palette instead of a seam. Nothing under `src/` knows
`assets/materials/` exists: a shared material is a scene-authoring convention, not a system, so no
registry, no id, no directory scan, no sixth catalogue.

What already made this safe and was not planned for it: `SurfaceWetness` duplicates every material
before darkening it (WP-13). Without that, rain in the courtyard would have left the hall's plinth
wet on the far side of an area change — the exact failure a shared sub-resource invites.

### 2. The environment post stack — twenty exports at the values T2.1 shipped

`_build_post_stack()` held twenty literals; they are now twenty `@export`s on `EnvironmentDriver`
in two groups, at exactly the numbers they had, so nothing renders differently. The point of the
seam is that a game can reach them.

Per **area**, not per project, and not a resource. The driver already lives in the area scene and
its `Interior` group already varies that way. A `.tres` "environment look" was considered and
dropped: a `SpriteSheetLayout` is shared between nodes in one scene, a post stack is one per area,
so the resource adds a class, a folder and a wiring step to reach the same set of numbers.

What stayed in code: the tonemapper, the fog mode, the glow blend mode, `AMBIENT_SOURCE_COLOR` and
`BG_SKY`. Those are the STRUCTURE the rest of the file assumes rather than numbers an area tunes —
`_apply_now` writes `ambient_light_color` every frame, which only means anything if the source is a
colour. The four expensive effects (`ssao`, `sdfgi`, `ssil`, `ssr`) ARE exports despite being
`false` everywhere, because **a value a consuming game cannot reach is not a seam, it is an
opinion.** The day/night `KEYFRAMES` table is untouched and no seam is claimed for it: a curve is
not a look setting.

`environment_driver.gd`: 183 → 205 code lines of 250.

### 3. Per-area camera framing — the seam already existed and four documents were wrong

`HD2DCameraRig` has carried `distance`, `pitch_degrees`, `yaw_degrees`, `fov`, `height_offset`,
`follow_lag`, `frame_bias` and the whole depth-of-field group as `@export`s since it was written,
and its header has said "duplicate it and change the numbers" the whole time. **What was missing
was an area using them.** Both demo areas took every default, so the claim had never been run.

So this cost an authored value and a capture. The interior now frames at `distance = 9.5,
fov = 36.0, height_offset = 0.95` against the outdoor `14.0 / 27.0 / 1.15`, because a room reads
better close, and one run logs both:

```
[camera   ] Rig ready: fov 27.0, distance 14.0, pitch -32.0
[camera   ] Rig ready: fov 36.0, distance 9.5, pitch -32.0
```

`hd2d_camera_rig.gd` was not touched.

### 4. The texture import defaults — gotcha 30 was right about the rule and wrong about the answer

T2.1 stopped here because `[importer_defaults]` is undocumented and absent from `--doctool`, and
this project checks every name against the API dump before typing it. The rule holds. The
conclusion did not, because **a measurement was available and outranks a dump** — non-negotiable #1
says the engine decides.

The probe, run in `res://tmp_probe/` and since removed. `grass.png` was copied to `probe.png` and
imported with stock defaults:

```
compress/mode=0
mipmaps/generate=false
process/fix_alpha_border=true
detect_3d/compress_to=1
```

Then this went into `project.godot`, `probe.png.import` was DELETED, and `--headless --import` ran
again:

```
[importer_defaults]

texture={
"detect_3d/compress_to": 0,
"mipmaps/generate": true
}
```

```
--- after .import ---
compress/mode=0
mipmaps/generate=true
detect_3d/compress_to=0
```

**Both values moved.** So the section works, the key is the IMPORTER's name (`texture`), the value
is a Dictionary of param paths, and it applies to a FRESH import only — an existing `.import` keeps
its own params, which is why all eight committed ones had to be edited as well. A second probe
confirmed it is readable at runtime, which is what makes it assertable:

```
type=27 value={ "detect_3d/compress_to": 0, "mipmaps/generate": true }
has=true
```

`mipmaps/generate` was only the **control value** — its stock default is the opposite of what was
written, which is the only thing that proves the section applied rather than the value happening to
already be right. It was removed afterwards. **Exactly one value is set in the end**,
`detect_3d/compress_to = 0`: the editor's "this texture was used in 3D, switch it to VRAM
compression" rewrite, which matters because every character sheet in an HD-2D game IS used in 3D
through `Sprite3D`. The other three values `ART_CONTRACT.md` had recommended turned out to be
Godot's own defaults, measured on the untouched probe, so writing them down would have been
ceremony that later reads as a decision.

New gotcha 39 records the whole thing, and gotcha 30 now says it was reversed and keeps its general
lesson: *"I cannot check this the usual way" is a reason to find another check, not a reason to
stop.*

### 5. Git LFS — refused, and the deciding reason had never been written down

Two reasons were already on record: pointers for a 2 KB procedural placeholder are pure overhead,
and enabling them puts the CI checkout on a dependency it does not declare (`actions/checkout`
needs `lfs: true`, and without it every PNG arrives as a text pointer and the import fails). The
third is the one that decides it: **this template cannot verify the change it would be making.**
Proving LFS works needs an LFS-enabled remote and a CI run against real binaries, neither of which
exists while art is deferred, and a configuration nobody can test is exactly the change that looks
applied and does nothing.

`ART_CONTRACT.md` now carries the refusal plus the three steps to turn it on. `.gitattributes`
keeps the commented line and stops restating the reason — it was the fifth mention.

### Connects

`assets/materials/` is the third `assets/` seam after `placeholder/` and `theme/`, and the first
that area scenes reach directly. The post-stack exports sit beside the `Interior` group WP-04
added, for the same per-area reason. The importer defaults sit beside `gui/theme/custom` in
`project.godot` as the second project-level art seam. Nothing new was added to `src/`, no autoload,
no registry, no signal, no save section, and `check_boundary` still derives 16 demo names and finds
none of them.

### Verified

**Ladder.** `--headless --import` with zero `SCRIPT ERROR` / `Parse Error` lines; boot
`0 warnings, 0 errors`; suite `=== 1515 passed, 0 failed, 0 skipped ===` exit 0; `check_budgets`
**128 files, 11,119 code lines, 0 warnings, 0 violations**; `check_content` PASS; `check_boundary`
PASS.

**Six gates proved RED with the real violation, then green (gotcha 23).**

Duplicate materials re-inlined into both areas:
```
=== 1512 passed, 1 failed, 2 skipped ===
FAILED: no two areas declare the same material inline (1 duplicated) — expected 0, got 1
```
(The two skips are correct and worth noting: with the shared file used by nobody, the
"more than one user" block skips and stands in for its two outcomes.)

`_environment.glow_intensity = 0.9` and `camera.fov = 27.0` put back:
```
=== 1513 passed, 2 failed, 0 skipped ===
FAILED: the driver writes down no environment number — expected 0, got 1
FAILED: the rig writes down no camera or depth-of-field number — expected 0, got 1
```

The importer default set to `1` and one `.import` flipped back:
```
=== 1513 passed, 2 failed, 0 skipped ===
FAILED: the default disables the 3D re-import to VRAM compression — expected 0, got 1
FAILED: every committed texture .import disables 3D detection: ["res://assets/placeholder/character_placeholder.png.import"] — expected 0, got 1
```

The `glow_intensity` default moved to `0.8`:
```
FAILED: glow_intensity is an @export at the value T2.1 shipped — expected [0.9, true], got [0.8, true]
```

**And the one that did not fail, which is the finding.** The hall's three framing lines deleted:
```
=== 1514 passed, 1 failed, 0 skipped ===   ← the moved default only. The framing gate PASSED.
```
`_an_area_really_uses_the_framing_seam` scanned every line of the area scene, and
**`WeatherVisuals` also exports `height_offset`** — the courtyard's weather node carries
`height_offset = 5.0`, so the assertion matched a node with nothing to do with the camera and
reported green with the seam unused. Two classes, one property name; gotcha 17's family moved out
of GDScript and into scene text, and now gotcha 40. Fixed by walking `[node ...]` blocks and
reading only those whose `script` ExtResource resolves to the rig, buffering each block and judging
it at the end rather than switching on the `script` line as it goes by, because a property authored
above `script` is legal `.tscn`. Re-planted afterwards:
```
FAILED: at least one camera rig in an area authors its own framing — expected true, got false
```
All reverted: `=== 1515 passed, 0 failed, 0 skipped ===`, exit 0.

**Six windowed captures, LOOKED AT and READ.** All `--resolution 960x540 -- --new-game
--time=12:00 --freeze-time`, midday rather than dusk (gotcha 31), with the interior needing
`--goto=lantern_hall --shot-frame=95 --quit-after 110` because no ordinary run enters an area.

1. courtyard baseline — grass, grey pillars, the wooden dais tan.
2. interior baseline — tan tiled floor, the wooden plinth brown at the right. Player sprite about
   78 px tall.
3. and 4. after ONE line added to `assets/materials/wood.tres`,
   `albedo_color = Color(0.85, 0.15, 0.55, 1)`: the courtyard's dais **and** the hall's plinth are
   both magenta, and nothing else in either frame moved. Two areas changed by one file that neither
   of them contains. Reverted.
5. after ONE line added to `courtyard.tscn`'s driver node, `volumetric_fog_density = 0.06`: the
   same frame hazed to the horizon, colours washed, the sky wall gone milky. Reverted.
6. against 2: the same interior at the same hour with the player sprite at roughly 130 px against
   78 and the floor grid visibly larger — a closer, wider lens. Kept.

**The `.import` change was photographed, not assumed.** All six captures were taken AFTER the eight
`.import` files moved to `detect_3d/compress_to=0` and the project re-imported. The character
sprites are crisp, hard-edged and free of block artefacts, and `compress/mode=0` still reads `0` in
all eight files. This was the check the package's exit criteria singled out, because a compression
change is the one edit that passes every rung and ruins the picture.

**Probes, added and removed.** `res://tmp_probe/` held `probe.png`, `pp.gd` and `probe_setting.gd`
for the import measurement. All three are gone, `git status` is clean of them, and nothing was added
to `src/systems/debug/` at any point — `git diff src/systems/debug/` is empty, because this
package's claims are a `.import` file and six pictures rather than a runtime behaviour.

### Unblocks

A consuming game can now re-tune its whole look — materials, post stack, camera, texture import —
without opening `src/`, which was Phase T2's goal and the last place it was still false.

### Gaps

- The day/night `KEYFRAMES` table is still a `const`. A curve, not a look setting, and no document
  has ever listed it as a seam — say so before building it, not after.
- The `Button` styleboxes are left for the **fourth** time. A stylebox has to be designed, and the
  only palette to design against is the placeholder one, so populating them ships a decision as a
  default. This package had `ui_theme.tres` in scope and still declined, which is the point at
  which "left again" should read as settled rather than pending.
- One shared material, not five. ONE piece of placeholder content per system, and four of the other
  five would have been wrong to share anyway.
- Git LFS, refused above.
- No `check_content` or `check_boundary` branch covers `assets/materials/` — the assertions in
  `tests/unit/area_look_test.gd` do it instead, and they are the right place, but a third area that
  inlines a copy of a material only ONE other area shares is not caught by anything.

**Suite total correction, stated rather than absorbed.** The gate proofs above were all run at
`1515`, before the documents were written. `docs_test.gd` COMPUTES its plan from `docs/` and
`CLAUDE.md`, so the two new `res://` paths this package's documentation names moved the total to
**`=== 1517 passed, 0 failed, 0 skipped ===`**, which is the number the ladder now reports. The
same gate caught a real defect in that documentation on the way: gotcha 39 originally quoted the
throwaway probe folder by its `res://` path, and the path no longer exists because the probe was
removed — `FAILED: CONTEXT.md names res://tmp_probe/, which exists — expected true, got false`.

**Stripped template, run locally** — `1445 passed, 0 failed, **23** skipped` (was `1400 / 19`),
`check_content` and `check_boundary` both exit 0, `demo names derived: 0`. **The skip count moved
and the four new ones are named, because a skip nobody names is a stripped run pretending to be a
full one.** All four are `area_look_test`, all three of its content-dependent blocks, and every one
is correctly a claim about content rather than about the engine:

- `a shared material is used by more than one area — this checkout has 0 area(s) naming it`
  (stands for 2 outcomes: the user count, and that each user really depends on the file)
- `no two areas declare the same material inline — this checkout has 0 area(s)`
- `an area authors its own camera framing — this checkout has no areas`

The arithmetic closes exactly: of the case's 47 outcomes, 4 skip and 43 run, and the remaining +2
on the passed count is `docs_test` picking up the two new `res://` paths the documentation names —
both under `assets/`, which a stripped checkout keeps.

**CI green, run 33535503432, job logs read rather than the tick** (gotcha 26). Full checkout
`1517 passed, 0 failed, 0 skipped`, `item definitions: 4`, `quests: 1`; stripped template
`1445 passed, 0 failed, 23 skipped`, `item definitions: 0`, `demo names derived: 0`. Both jobs
report `128 files, 11119 code lines, 0 warnings, 0 violations` and all three checkers PASS.
Commit `d20fbc1` on `claude/t3-2-art-seams`, PR #22, stacked onto `claude/t3-3-item-count` (#21).

**One claim in this entry was overstated on the first pass and is corrected here rather than left.**
The package section originally said the acceptance test was "`grep` finds each of the five once".
It does not, and it should not: each seam is still named in a package section, a settled decision,
a `SYSTEMS_INVENTORY.md` row and — for two of them — a gotcha. That is this project's standard
record shape for finished work. What IS in exactly one place is the **current state** of each seam,
the thing a reader would act on, and that place is `ART_CONTRACT.md`. The four stale claims are
deleted: `ARCHITECTURE.md`'s "no shared material library" bullet, `CONTEXT.md`'s "Not built" line,
`ROADMAP.md`'s recitation inside the T2.1 entry, and `.gitattributes` restating the LFS reason.
The problem was never the number of mentions; it was five documents each independently describing
PENDING work, where none of them is the one that gets corrected.

---

## 2026-09-01 — WP-14 · Dev tools and hardening (the hardening half)

**Did.** Re-framed and split the row in the commit that took it; fixed `Director`'s threaded-load
shutdown; added `tools/check_strings.gd` as a fourth checker and rung 8; added
`tests/unit/smoke_test.gd`; strengthened CI's rung 3 from a last-line read to a whole-log grep;
raised `director.gd`'s line budget from 180 to 190 with the reasoning written down.

**Why the row changed, in both directions, and neither quietly.**

WP-14 asked for "a smoke test that drives **the whole demo** through public APIs". Built to the
letter that puts `courtyard`, `keeper` and `rose_key` into a permanent ladder gate — which is the
coupling `tools/check_boundary.gd` exists to prevent, arriving through the back door of a test.
`check_boundary` has scanned `tests/unit/` since T1.3, so it would in fact have failed the build;
the row was asking for something the project already forbids. T1.3 spent a whole package unwelding
the suite from the demo, and "end to end" is exactly the phrase that would have grown it back.
`smoke_test.gd` composes its session from `tests/framework/fixtures.gd`, names no content, and its
one game-shaped block asserts that `GameConfig.first_area()` RESOLVES — never what it is called —
and skips, counted, in a stripped checkout.

The row also named four things, which is over the 8-file limit, so the row's own title was the
seam: the two gates shipped as WP-14, and the debug console and performance overlay became
**WP-14b** rather than four half-finished things.

**And a third correction, which was not asked for.** "End to end" cannot mean a playthrough here at
all: `TestCase.run()` is synchronous, so no assertion can await a frame, a threaded load or a
keypress. The smoke test is the CHAIN — a run begins and empties the bag, a flag starts a quest,
items publish counts, a counted objective notices, an item is picked up and put in hand, time
skips, and the session is saved, wiped and restored with the quest still settled. Each seam has its
own case; this asserts they COMPOSE.

**The `Director` fix, and what the defect was really costing.**

Reproduced first, at five frame counts, `--headless --quit-after N -- --new-game` for
N = 8, 12, 16, 20, 25. Every one printed 1-2 `Parse Error` lines for files that parse perfectly —

```
23:23:19 [INFO ] [boot     ] Session ended after 0.2s — 0 warnings, 0 errors
ERROR: res://assets/materials/wood.tres:35 - Parse Error: .
ERROR: res://scenes/areas/courtyard/courtyard.tscn:30 - Parse Error: .
WARNING: 16 ObjectDB instances were leaked at exit
```

plus leaked RIDs and 10-19 leaked ObjectDB instances, all *after* the clean report. **Gotcha 22
with the polarity reversed:** not an error a rung cannot see, but a FALSE error poisoning the
`Parse Error` grep that rung 2 uses as this project's compile check.

**The finding is what that had bought.** CI's rung 3 read only the LAST LINE of its boot log, and
its comment said why: a whole-log grep "would be a flake generator". So the most load-bearing check
on the ladder was switched off on that rung — deliberately, correctly, and for as long as the
defect lived. Nobody weakens a gate for no reason; they weaken it because something real is making
it lie. That is now **gotcha 41**, and the practical form is: a scope-limiting comment on a check
is a defect report in disguise.

Two things measured rather than assumed, because the dump does not document them (gotcha 39's
precedent). **There is no cancel:** `--doctool` gives ResourceLoader `load_threaded_request`,
`load_threaded_get_status` and `load_threaded_get` and nothing that abandons a request — so the
only clean end is to wait, and `load_threaded_get()` blocking was measured at **196686us, 169287us
and 118221us**, returning non-null. **The hook:** with a load in flight, `NOTIFICATION_EXIT_TREE`
arrives *before* the session's own closing log line, `NOTIFICATION_PREDELETE` after it, and
`NOTIFICATION_WM_CLOSE_REQUEST` never — headless has no window. Probe output:

```
PROBE exit_tree loading=res://scenes/areas/courtyard/courtyard.tscn
23:24:41 [INFO ] [boot     ] Session ended after 0.7s — 0 warnings, 0 errors
PROBE predelete loading=res://scenes/areas/courtyard/courtyard.tscn
```

After the fix, all five frame counts: **exit 0, parse/script errors 0, RID leaks 0, ObjectDB leaks
0.** The probe was temporary and is gone; `git diff src/systems/debug/` is empty.

**The boot timeout dropped, but NOT for the reason the row gave, and that is the honest account.**
Gotcha 13 said 120 frames were needed because the boot raced a threaded load. Gotcha 31 says a
plain boot stops at the MAIN MENU and enters no area — so it was never racing anything, and gotcha
13 had been wrong since WP-12 added the menu. **The control:** `--quit-after 30` and
`--quit-after 120` produce byte-identical logs, 29 lines each, both `0 warnings, 0 errors` — and
both were already clean *before* the fix. So 30 is justified by the measurement, not by the fix.
The fix's real dividend is rung 3's whole-log grep. Gotcha 13 is rewritten to say both halves.

**The string audit, and the refusal it respects.**

`check_content.gd` had already turned down a general hard-coded-string audit in writing —
*"telling a player-facing literal from a log message or a flag key needs semantics a text scan does
not have, and a partial tool that looks complete is how 409 passing checks happened."* That is
right, so `check_strings.gd` never classifies a literal. Both rules sit at a **sink** or a
**declaration**, where the semantics are structural: the right-hand side of a
`.text`/`.tooltip_text`/`.placeholder_text`/`.title` assignment either goes through `tr()` or holds
no literal at all, and every `*_KEY` const under `src/` names a real CSV row. Property names
verified against `--doctool`, and matched with a trailing `" = "` so `text_direction` and
`text_overrun_behavior` are not swept in.

**The key rule closed a hole that was measurably live.** 71 key declarations, and nothing had ever
checked one: `check_content` validates keys authored in `.tres`, and `items_test.gd`'s enum loop
covers only the computed `verb.*` / `refusal.*` families. With `notify.item_takne` planted — one
transposition in the toast shown by every pickup and every chest:

```
--- check_content:   PASS   exit 0
--- check_boundary:  PASS   exit 0
--- suite:           === 1517 passed, 0 failed, 0 skipped ===   exit 0
```

Every existing gate green over a bug that would have printed `notify.item_takne` on screen forever,
because `tr()` returning its own argument is not an error. That is this project's founding failure
mode, still live at 1,517 assertions.

**Verified — every gate planted red, then green (gotcha 23).**

- Sink rule, `label.text = "No items"` in `inventory_screen.gd:228`:
  `!! res://src/ui/screens/inventory_screen.gd:228 assigns a literal to .text with no tr(): "No items"`
  → `FAIL — 1 string violation(s)`, exit **1**. Removed → `PASS`, exit 0.
- Key rule, `pickup.gd:24`:
  `!! res://src/gameplay/interactables/pickup.gd:24 TAKEN_KEY = 'notify.item_takne' has no row in res://localization/strings.csv`
  → exit **1**. Removed → `PASS`, exit 0.
- Smoke test, `Inventory`'s `game_started` subscription deleted — the real way a new game would
  stop emptying the bag: four assertions red, cascading down the chain,
  `1539 passed, 1 failed`, exit **1**. Restored → `1540 passed, 0 failed`, exit 0.

**The plant that mattered most found a defect in the new TEST, not in the code.** The smoke test's
save/load block carried a comment claiming it asserted the save-participant ORDER — T3.3's
invariant that a derived count must be republished on `game_loaded`, because `Flags._apply_save`
wipes the store from underneath it. Deleting that subscription, which is exactly how the invariant
would really be lost, left the assertion **GREEN**: the test's own wipe happens to let
`_apply_save` publish for itself, so the ordering never came into play. The assertion was true and
the comment above it was not, and no failure could ever have shown the difference. The comment now
states the weaker, true claim and points at `item_count_test.gd`, which did go red on that plant
(`FAIL game_loaded republishes it — expected 3, got 0`). This is T3.2's framing gate in a second
costume and is now **gotcha 42**.

**Verified — the ladder.**

`--headless --import` exit 0, **zero** `SCRIPT ERROR` / `Parse Error`. Boot at the new
`--quit-after 30`: `Session ended after 0.8s — 0 warnings, 0 errors`. Suite:
**1543 passed, 0 failed, 0 skipped**, exit 0. `check_budgets` PASS
(**130 files, 11,338 code lines, 0 warnings, 0 violations**), `check_content` PASS,
`check_boundary` PASS, `check_strings` PASS (216 CSV rows, 93 engine scripts, 19 sinks, 71 key
declarations, 1 pattern reported).

**Stripped template:** **1469 passed, 0 failed, 25 skipped** (was 1445/0/23), all four checkers
exit 0. The one new skip is named — `smoke_test: a game in this checkout can be started (no content
— this is a stripped template) — 2 assertion(s) not run` — and the arithmetic reconciles exactly:
1494 outcomes against 1468, so +26 = 23 from `smoke_test.gd` + 3 from `docs_test.gd`'s computed
plan. `check_strings` reports byte-identical numbers stripped and full, which is the result to
want: both its rules are about `src/` and `localization/`, which the strip does not touch.

**No windowed capture, and that is a claim not made rather than a step skipped.** A shutdown drain,
a text scanner and a synchronous test have no pixels. Photographing any of them would be theatre.

**The budget was raised rather than a file split, and it is the first time.** `director.gd`'s
override is 180 — a self-imposed tightening 70 below the 250 default. The drain took it 176 → 187.
`check_budgets.gd` offers "split the file, or justify a new budget", and splitting was wrong: the
drain must sit with the code that owns the loader thread, and `Director`'s header is an argument
for *one owner, one guarded path*. Raised to 190, justified at the override and in
`ARCHITECTURE.md` § Line budgets. **190 is not above the default** — over 250 still means split.
The restructure that came with it stands on its own: `_load_area_scene` sets and clears `_in_flight`
in one place and delegates polling to `_await_load`, so the invariant `_exit_tree()` depends on
reads off one function rather than four exit paths.

**Connects.** `Director` ↔ the ladder's compile check ↔ CI rung 3. `check_strings` sits beside
`check_content` and `check_boundary` as the fourth pure-text gate, and like them loads nothing, so
it keeps working in a checkout with no game in it. `smoke_test.gd` composes WP-08's quests, WP-09's
equipment, T3.3's published counts and `SaveSystem` without any of them learning about each other.

**Unblocks.** WP-14b — the debug console and the performance overlay — with three decisions already
made in its row: reuse `dev_stage.gd`'s existing argument parsing rather than writing a second
parser, keep both behind `OS.is_debug_build()` because that guard is what the boundary exemption
rests on, and make the console a `UiScreen` with `pauses_world` while the overlay is a
`CanvasLayer` beside the HUD.

**Gaps, stated rather than implied.** The sink rule cannot see a literal reaching a sink through a
variable, a sink outside `src/*.gd` (a `.tscn` authoring `text = "Play"` is unscanned), a literal
handed to `draw_string()`, or whether the key `tr()` got was the RIGHT key — its header says so.
The suite still cannot enter an area, so the smoke test is a composed session and not a played one.
No CI export rung and no branch protection, both unchanged. **WP-15's remnant should probably be
CLOSED rather than built** — credits name a team a template does not have, and an accessibility
pass over placeholder art is a pass over something designed to be replaced; the reasoning is in its
board section, recorded rather than acted on, because retiring a row is the owner's call.

**CI green, run 33541171263, job logs read rather than the tick (gotcha 26).** Full checkout
`=== 1543 passed, 0 failed, 0 skipped ===`; stripped template
`=== 1469 passed, 0 failed, 25 skipped ===` — both identical to the local numbers. Rung 8 ran in
both jobs and reported the same 93 engine scripts and 71 key declarations, which is why it runs on
the stripped tree at all. Rung 3's new whole-log grep printed `Parse Error lines in boot.log: 0`,
a line that could not have existed before this package. The run took 36 seconds; per gotcha 26 that
is a cached engine, not a skip — the rung logs show 1,543 assertions executed.

**Commit** `975ff4b` on `claude/wp-14-hardening`, PR #23, stacked onto `claude/t3-2-art-seams`
(#22) rather than `main`, matching the chain.


## 2026-09-02 — WP-14b · Dev tools: the debug console and the performance overlay

**Branch:** `claude/wp-14b-dev-tools`, off `claude/wp-14-hardening`. **Phase T3 closes here.**

### Did

A debug console on F1 (`goto`, `flag`, `time`, `give`) and a performance overlay on F3 (frame
time, fps, process time, draw calls, node count, orphan count). The half WP-14 split off rather
than half-finish four things.

Four new files and seven edited:

- `src/systems/debug/dev_commands.gd` — the four verbs, ONE body each.
- `src/ui/screens/debug_console_screen.gd` — a `UiScreen` declaring `pauses_world`.
- `src/ui/hud/perf_overlay.gd` — a `CanvasLayer` at layer 101 that never enters the stack.
- `tests/unit/dev_tools_test.gd` — 30 assertions.
- `dev_stage.gd` (three verbs delegate; new `--console=` staging flag), `dev_capture.gd`
  (`--time=` delegates), `screen_keys.gd` (`toggle_console`, the `menu_for` entry, the armed
  line), `actions.gd` (`DEBUG_PERF` on F3), `game_root.tscn`, `strings.csv`, `test_runner.gd`.

### Why

**The console lives under `src/ui/`, and the argument that settled it is not the obvious one.**
The board asked whether it could, with the test being whether any part wants a hard-coded area or
item id. None does. But the reason to *prefer* `src/ui/` is stronger than the permission:
`src/systems/debug/` is EXEMPT from `check_boundary.gd`, so filing the console there would have
bought it an exemption it does not need and switched off the gate that ought to be watching it.
Under `src/ui/screens/` it is policed like the journal and the map, and it passes.

**One parser, taken at its strongest.** The row said reuse the four commands. So `DevCommands`
holds the bodies and both argument parsers call them — `time 18:40` in the console is
`--time=18:40` on the command line, argument for argument. Each verb returns its report rather
than logging it: a staging flag wants that line in the log, a console wants it on screen.

**Console pauses, overlay does not — one decision made twice.** Both answer *should the world be
stopped?* Typing at a running clock photographs a moving target; a frame time is worthless unless
frames are still happening.

### Verified

**The ladder.**

```
--headless --import                    exit 0, SCRIPT ERROR / Parse Error lines: 0
--headless --quit-after 30             Session ended after 0.8s — 0 warnings, 0 errors
test_runner.tscn --quit-after 400      === 1574 passed, 0 failed, 0 skipped ===   exit 0
tools/check_budgets.gd                 134 files, 11659 code lines, 0 warnings, 0 violations · PASS
tools/check_content.gd                 PASS
tools/check_boundary.gd                PASS · 127 engine scripts · 14 exempt demo names · 5 debug scripts gated
tools/check_strings.gd                 PASS · 218 CSV rows · 96 scripts · 24 sinks · 73 keys · 1 pattern
```

**Stripped template**, `--headless --path <copy>` with `.git`, `.godot`, `data/` and
`scenes/areas/` removed: **1500 passed, 0 failed, 25 skipped** (was 1469/0/25), all four checkers
exit 0, import clean. **No new skip** — the +31 is `dev_tools_test.gd` plus `docs_test.gd`'s one
computed assertion, and all 30 of the former run stripped, because a console and an overlay are
engine.

**`dev_stage.gd` was at exactly 250/250 before this package.** Measured by stashing the branch and
re-running the checker:

```
  ok   src/systems/debug/dev_stage.gd                        250 /  250
130 files, 11338 code lines, 0 warnings, 0 violations
```

After extracting the verbs and adding `--console=`: `247 / 250`. The sixth staging flag could not
have been added without the reuse the board asked for.

**Seven plants, each red with the REAL violation then green again (gotcha 23).**

1. Guard deleted from `ScreenKeys.toggle_console`, the explaining comment LEFT IN PLACE →
   `FAILED: screen_keys.gd gates on 'if not OS.is_debug_build():' — expected true, got false`,
   `1572 passed, 1 failed`, exit 1. Restored → `1573 passed, 0 failed`, exit 0.
2. `and OS.is_debug_build()` deleted from `ScreenKeys.menu_for` →
   `FAILED: screen_keys.gd gates on 'DebugConsoleScreen.SCREEN_ID and OS.is_debug_build()'`, exit 1.
3. Guard deleted from `PerfOverlay._ready` →
   `FAILED: perf_overlay.gd gates on 'if not OS.is_debug_build():'`, exit 1.
4. Transcript trim removed → `FAILED: the transcript is bounded — expected 12, got 42`, exit 1.
5. Empty-line guard removed → `FAILED: so the transcript did not grow — expected 2, got 4`, exit 1.
6. `flag`'s malformed-argument refusal removed → two failures, including
   `FAILED: and wrote nothing — expected false, got true`, exit 1.
7. `ui.debug.console.title` → `ui.debug.consloe.title`:
   `!! res://src/ui/screens/debug_console_screen.gd:31 TITLE_KEY = 'ui.debug.consloe.title' has no
   row in res://localization/strings.csv`, `FAIL — 1 string violation(s)`, exit **1** — while
   `check_content` exit 0, `check_boundary` exit 0, and **1573 assertions passed**. WP-14's
   finding reproduced on this package's own keys.

**Plant 3 is the one worth the section, and it changed the CODE rather than the test (gotcha
43).** The first version of the gate assertion scanned each file for the bare
`OS.is_debug_build()` and would have passed over a deleted guard in two independent ways:

- `screen_keys.gd` documents its gate in a `##` block, so the scan read its own explanation back.
  Fixed by skipping comment lines, as `check_boundary.gd` and `check_strings.gd` both do.
- `perf_overlay.gd` carried `if not OS.is_debug_build():` **twice**, in `_ready` and in `_input`.
  Deleting the real one in `_ready` left the assertion green on the other. The fix was in the
  code: `_input` and `toggle()` now ask `_label == null`, which is the same question and stricter,
  because a release build never builds the label. One place decides; the anchor is unique.

**Absent from a release export — MEASURED, with a control.** Two real exports built and run, log
files compared:

```
--export-debug   build/dbg/game.console.exe --quit-after 60
  00:35:04 [INFO ] [ui       ] Debug console armed on debug_console
  00:35:04 [INFO ] [ui       ] Performance overlay armed on debug_perf
  00:35:05 [INFO ] [boot     ] Session ended after 1.1s — 0 warnings, 0 errors
  armed lines: 2

--export-release build/rel/game.exe --quit-after 60
  00:35:18 [INFO ] [boot     ] Game root ready
  00:35:19 [INFO ] [boot     ] Session ended after 1.1s — 0 warnings, 0 errors
  armed lines: 0
```

The debug export is the control. Without it, two absent lines would prove only that nothing was
logged. Gotcha 39's shape.

**The temporary input probe (gotcha 15), in `dev_probes.gd`, quoted here and then removed.**
`git diff src/systems/debug/dev_probes.gd` is empty.

```
PROBE stack depth before F1: 0
PROBE F1 opened: true, depth 1, world paused true
PROBE LineEdit found: true, has focus true
PROBE enter ran it: clock 04:15, transcript 2 line(s), box now ''
PROBE F1 again closed it: depth 0, world paused false
PROBE overlay before F3: visible false
PROBE F3 -> visible true | 35.71 ms/frame  28 fps  188.11 ms process  97 draw calls  169 nodes  0 orphans
PROBE 90 frames later          | 16.70 ms/frame  54 fps  17.56 ms process  96 draw calls  169 nodes  0 orphans
PROBE F3 again -> visible false
```

The overlay's own criterion is "a frame time that visibly changes": the load spike reads 35.71 ms
at 28 fps and ninety frames later the same overlay reads 16.70 ms at 54 fps. The probe also
settled a question the dump does not answer — a 4.3+ `LineEdit` distinguishes having focus from
being in EDIT mode, and `has focus true` with the enter actually taking is what proves
`grab_focus()` plus `edit()` is the right pair rather than `grab_focus()` alone.

**Three windowed captures, LOOKED AT and READ (gotcha 28).** Written to `build/shots/`, which is
gitignored, so they are described rather than committed — as every previous package's are.

1. `wp14b_console.png` — `--new-game --time=12:00 --freeze-time
   --console="time 18:40;flag map/somewhere:true;give item/rose_petal:2" --shot-frame=120`.
   Title `Debug console` top-left; six gold transcript lines bottom-left, echo and answer for each
   command; the input line showing the four verbs as its placeholder; the courtyard visible
   through the dim panel, so the world is stopped rather than gone. **The checkable prediction:
   the run asked for noon and the HUD reads `Day 1 | 18:40 | Dusk` over a dusk-lit scene.** The
   console really moved the clock, and the readout and the lighting agree.
2. `wp14b_console_goto.png` — `--console="goto lantern_hall"`. The interior, at its own T3.2
   framing, with the toast `Lantern Hall is added to your map` and no console, because travel
   unwinds the stack through `ScreenKeys`. The log:
   `Entered 'courtyard'` … `--console 'goto lantern_hall' -> goto requested 'lantern_hall'` …
   `Entered 'lantern_hall'`.
3. `wp14b_overlay.png` — `16.67 ms/frame  60 fps  17.72 ms process  98 draw calls  169 nodes
   0 orphans`, top-left in gold, over a live courtyard with the NPC visibly at a different post
   than in capture 1 — which is the point of it not being a screen.

**Capture 3's first attempt came back with no overlay in it, and it was NOT a defect.** The
shutter frame landed before F3. Diagnosed by probing rather than guessed at:

```
PROBE overlay label: true rect=[P: (32.0, 24.0), S: (1888.0, 40.0)] vis=true text='31.25 ms/frame …'
PROBE overlay colour=(0.86, 0.74, 0.52, 1.0) size=18 clockcolour=(0.86, 0.74, 0.52, 1.0)
```

Right rect, right visibility, right gold, right text. Nothing was wrong with the drawing and the
timing was the whole story. Widening the probe's visible window from 90 to 400 frames fixed the
capture.

**One API fact worth recording:** `CanvasLayer` is not a `Control` and has NO theme lookup, and a
`Control` outside the tree cannot resolve `gui/theme/custom` either — so the overlay's label asks
for its own colour AFTER `add_child`, and there is a comment saying so. Every `Performance`
monitor name used was checked against `--headless --doctool`: `TIME_PROCESS`,
`RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `OBJECT_NODE_COUNT`, `OBJECT_ORPHAN_NODE_COUNT`, plus
`Engine.get_frames_per_second()` (returns `float`).

**And the GDScript compiler refused one assertion outright**, which is a better outcome than the
assertion: `overlay is UiScreen` on a `PerfOverlay` is a *Parse Error* — `Expression is of type
"PerfOverlay" so it can't be of type "UiScreen"`. The claim is kept in the case that owns it, via
a `Node` local, with the reason in a comment.

### Connects

- `DevCommands` sits under `dev_stage.gd` and `dev_capture.gd`, so the staging vocabulary and the
  console vocabulary cannot drift.
- The console joins `ScreenKeys`' table beside the pause menu, inventory, journal and map, and
  `menu_for` beside the journal and the map — so `--open-menu=console` works, gated.
- The overlay joins `game_root.tscn` as a sibling of `UILayer`, not a child of it.
- `--console=` is the sixth staging flag to need `_settle_stable` (gotcha 35), after
  `--open-menu`, `--flag`, `--open-inventory`, `--give` and `--equip`.

### Unblocks

Phase T3 is CLOSED. Every system has one proof.

### Gaps

- **WP-15's remnant is a DECISION and it is the owner's**, surfaced on the board rather than
  taken: close the row (recommended) or build credits and an accessibility pass. WP-14b found
  nothing that changes WP-14's reasoning and one thing that sharpens it — the console and the
  overlay are the last two engine surfaces a consuming game does *not* restyle, because a player
  never sees either.
- No command history, autocomplete or flag watch list; no command mutates content on disk; no
  graph on the overlay. All deferred by the row, with reasons on the board.
- `Actions.DEBUG_FREECAM` on F2 is still declared and still bound to nothing. It predates this
  package; inventing a free camera is not a dev-tools row's job.
- The `Button` styleboxes, for the sixth package running. The console draws no `Button` at all.
- Still no branch protection and still no CI export rung, both unchanged.

**Count arithmetic, stated rather than absorbed.** 1,543 → **1,574**: +30 from
`dev_tools_test.gd` and +1 from `docs_test.gd`, which computes its plan from the documents and
gained one `res://` path to resolve when these sections named
`src/systems/debug/dev_commands.gd`. Every plant above was run before the documents were written
and so quotes 1573; the two totals differ by that one computed assertion and nothing else.

**Commit** `22e0046` on `claude/wp-14b-dev-tools`, stacked onto `claude/wp-14-hardening` (#23)
rather than `main`, matching the chain.

**CI green, run 33546328207, JOB LOGS read rather than the tick** (gotcha 26). Full checkout
**1574 passed, 0 failed, 0 skipped**; stripped template **1500 passed, 0 failed, 25 skipped** —
both identical to the local numbers. `check_budgets` reported **134 files, 11,659 code lines, 0
warnings, 0 violations** in BOTH jobs, and rung 8 reported identical figures in both (218 CSV rows,
96 engine scripts, 73 key declarations), which is the point of running it on a stripped tree.
Rung 3's whole-log grep printed `Parse Error lines in boot.log: 0`. All seven rungs present in the
full job and all six in the stripped one. The run took 38 seconds, and per gotcha 26 that is a
cached engine rather than evidence of a skip: the rung logs show 1,574 assertions actually
executed.

## 2026-09-02 — T4.1 · Template v1.0: the version, and the upgrade note

**Did.** Closed WP-15's remnant on the owner's decision, then built the first package of Phase T4:
the template now states its own version, and `docs/UPGRADING.md` describes — from a performance,
not from intent — how a game already forked from this base receives a later fix.

- `project.godot` gained a `[template]` section with `base/version="1.0.0"`.
- `src/core/util/template_version.gd` (new, 43 code lines) reads it: `current()`, `major()`,
  `minor()`, `patch()`, `is_semver()`, `same_major_as()`, `compare_to()`.
- `src/core/log/log.gd`'s boot banner gained one field, `base <version>`.
- `docs/UPGRADING.md` (new) and `docs/CHANGELOG.md` (new).
- `tests/unit/version_test.gd` (new, 27 assertions), registered in `CASES`.
- `tests/unit/smoke_test.gd`: one line changed, and it is a real defect fix — see below.
- `docs/NEW_GAME.md`, `docs/TEMPLATE.md`, `CLAUDE.md` cross-linked and corrected.

**Why.** The roadmap's Phase T4 named two deliverables and the second was the one that mattered:
nothing described how a fork receives a later fix, which is the one question a reusable base has to
answer and this one did not.

The version could not go in `application/config/version`, and the reason was already sitting in
`NEW_GAME.md` § 4: **it tells a fork to reset that field to `0.0.1` on day one.** After exactly one
fork it records the game's version and nothing anywhere remembers which base the game came from.
Two facts, two settings. It is a project setting rather than a `const` under `src/` because reading
a `const` means opening engine code, and the premise of the boundary is that a consuming game does
not read `src/`. `TemplateVersion` is a separate file from `GameConfig` because `GameConfig`'s
header says it owns "the values a game author writes once" and this is the one value a game author
must never write.

**Connects.** `Log` previously allowed itself exactly one dependency, `GameConfig`; this adds a
second of the same kind — a pure reader of `project.godot` that depends on nothing — and the header
says so rather than letting the claim quietly go stale. `docs/CHANGELOG.md` is tied to the setting
by assertion, so the two cannot drift. `NEW_GAME.md` is the sibling document and now says
`[template] base/version` is the one `project.godot` field a fork must not touch.

**Verified.** Local ladder, all green:

```
--headless --import                     (zero SCRIPT ERROR / Parse Error lines)
--headless --quit-after 30              Project Gulistan 0.0.1 | base 1.0.0 | Godot 4.7.2-stable (official) | headless | debug=true
                                        Session ended after 0.7s — 0 warnings, 0 errors
res://tests/test_runner.tscn            === 1601 passed, 0 failed, 0 skipped ===     (baseline was 1574)
check_budgets.gd    136 files, 11771 code lines, 0 warnings, 0 violations — PASS
check_content.gd    exit=0     check_boundary.gd  exit=0     check_strings.gd  exit=0
```

Stripped template (tree copied without `.git`/`.godot`/`build`, `rm -rf data scenes/areas`, run
with `--path`): `=== 1527 passed, 0 failed, 25 skipped ===`, all four checkers exit 0. That is
1500 + this package's 27, and **the skip count is unchanged at 25 — no new skip**.

**THE FIVE PLANTS (gotcha 23), each proved red with the real violation, then green.**

1. Banner loses its base-version fragment:
   `FAIL the boot banner names the base version exactly once — expected 1, got 0` · `1600 passed,
   1 failed` · exit 1. Restored: `1601 passed, 0 failed`.
2. **The same fragment written TWICE** — a decoy `var _decoy: String = "| base %s |"` added above
   the real banner: `FAIL ... expected 1, got 2`. This is gotcha 43 applied as a rule rather than
   recalled as a story, and it is why the assertion counts occurrences instead of asking
   `contains()`.
3. Changelog heading bumped to `## 1.0.1` with the setting left at 1.0.0:
   `FAIL its newest entry is the declared version — expected 1.0.0, got 1.0.1`.
4. `base/version="1.0"` in `project.godot`: three failures —
   `FAIL current() is the declared value — expected 1.0, got 0.0.0`,
   `FAIL the declared value is three integers — expected true, got false`,
   `FAIL newer than 0.0.1 — expected true, got false`. The fallback is what makes an unparseable
   version read as the OLDEST rather than as garbage.
5. `world/first_area="nowhere"` with the demo's areas present:
   `FAIL and its scene really exists — expected true, got false`. This one exists to prove that
   the `smoke_test.gd` fix below LOOSENED nothing.

**THE UPGRADE NOTE WAS PERFORMED, NOT WRITTEN.** Every output in `UPGRADING.md` § 7 came out of
real repositories under `C:/Users/Lenovo/AppData/Local/Temp/gup` (a short path — the session
scratchpad is deep enough that `git checkout` failed with `Filename too long` on
`docs/decisions/ADR-0001-...md`, which is worth knowing):

1. `base` — a clone of this branch, branch renamed `main`, tagged `v1.0.0`.
2. `game` — a clone of `base` with `origin` renamed to `template`, then stripped by following
   `NEW_GAME.md` § 1–4 literally: `data/**` and `scenes/areas/**` deleted, the CSV pruned from
   219 rows to 173 by the document's own `awk` line, `application/config/name` and
   `description` renamed to *Marsh Lantern*, `[game] world/first_area="fen"`, `ui.menu.title`
   changed. Then it authored one item of its own, `data/items/lantern_wick.tres`.
3. A synthetic **1.1.0** landed on `base` with one change per risk class: a new static function in
   `src/core/util/game_config.gd`; one engine CSV row; `application/config/features` edited (three
   lines from a field the fork had renamed); a new DEMO item; `base/version` bumped.
4. `git merge template/main` in the fork:

```
Auto-merging localization/strings.csv
CONFLICT (content): Merge conflict in localization/strings.csv
Auto-merging project.godot
Automatic merge failed; fix conflicts and then commit the result.
```

The conflict, verbatim, and it is the whole shape of the CSV problem — both sides append at the
end of the file:

```
<<<<<<< HEAD
item.lantern_wick.name,Lantern wick
=======
ui.pause.resume,Resume
item.lamp_oil.name,Lamp oil
>>>>>>> template/main
```

`project.godot` auto-merged and put every line on the correct side —
`config/name="Marsh Lantern"` and `world/first_area="fen"` kept, `config/features` and
`base/version="1.1.0"` taken. The `src/` change merged with no conflict at all.

**And the merge brought the template's demo item back.** `data/items/lamp_oil.tres` arrived as a
new file with **no conflict and therefore no warning**, because `data/` is a directory both sides
own files in. It is in no other document and it is now § 7 of the note.

**THEN THE FORK'S RUNG 4 WENT RED, AND IT WAS A REAL TEMPLATE DEFECT — gotcha 44.**

```
=== 1539 passed, 1 failed, 12 skipped ===
  FAIL and its scene really exists — expected true, got false
```

Nothing to do with the merge. `smoke_test.gd`'s first-area block gated on
`Fixtures.has_demo_content()` — *"any content at all"*, which flips true on the first `.tres` of
any kind — while asserting about **areas**. Both extremes are fine, so every run this repository
has ever made was green; the failure lives only in the gap, and a real game is in that gap for as
long as it takes to author its first area. That is exactly the window `NEW_GAME.md` walks an author
through while claiming the ladder stays green. **A block must gate on the same question it
asserts**, and `Fixtures.area_ids()` already was that question. Fixed, and plant 5 above is what
proves the fix did not loosen the gate.

5. That fix landed on `base` as a synthetic **1.1.1** and was merged into the fork the way a real
   patch would be — `Merge made by the 'ort' strategy.`, no conflict — after which the fork ran its
   own ladder:

```
Marsh Lantern 0.0.1 | base 1.1.1 | Godot 4.7.2-stable (official) | headless | debug=true
Session ended after 0.6s — 0 warnings, 0 errors
=== 1538 passed, 0 failed, 14 skipped ===
check_budgets exit=0  check_content exit=0  check_boundary exit=0  check_strings exit=0
```

Fourteen skips rather than the stripped template's twenty-five: the fork has one item and no areas,
so the cases that ask about areas say so and are counted.

**No visual and no input surface, stated rather than skipped.** Nothing here draws a pixel or reads
a key, so there is no windowed capture and no temporary probe. The boot banner is the one new
runtime output, it is a log line, and it is quoted above. `git diff src/systems/debug/` is clean.

**Unblocks.** Phase T4's two engineering criteria are ticked. What remains is a release tag, which
is a release action and the owner's to take — `v1.0.0` exists only in the throwaway proof
repositories. Beyond that the board has no blocking row: WP-15 is closed, WP-10 is optional, and
the next package is a genuine choice rather than a queue.

**Gaps.** The note cannot promise a clean merge and says so; git decides that from a diff the
template cannot see. It cannot promise content compatibility across a MAJOR, save survival, or
anything at all for a fork that edited `src/` — and that last one is the boundary rule collecting
its bill, stated once and honestly. The proof used synthetic version numbers because the real
template has released one version; the merges and their output are real, the release numbers are
scaffolding, and `UPGRADING.md` says so in its own preamble rather than letting a reader assume
otherwise. The `Button` styleboxes are still deliberately left, for the seventh package running.

**CI, run `33595460507`, dispatched on the branch and read from the JOB LOGS rather than the tick
(gotcha 26).** `Ladder (full checkout)`: `=== 1601 passed, 0 failed, 0 skipped ===`, every rung
`PASS`. `Ladder (stripped template)`: `=== 1527 passed, 0 failed, 25 skipped ===`, every rung
`PASS`. The runner's own boot lines read
`Project Gulistan 0.0.1 | base 1.0.0 | Godot 4.7.2-stable (official) | headless | debug=true`,
which is the new banner field proved on a machine that is not this one. PR #25, stacked on
`claude/wp-14b-dev-tools`.

## 2026-09-02 — T4.2 · A second worked example, authored from `AUTHORING.md` alone

**Did.** Performed `AUTHORING.md` end to end as a consuming author would, authoring an orchard
area with a warden NPC, a schedule, a four-node conversation, two items (one equippable), a sign,
a chest, a pickup, an equip-gated arch, a world-map def and a two-step quest whose first step
counts items — **from the document alone, with `src/` never opened while writing**. Recorded every
place the document did not say enough instead of patching it from knowledge. Then deleted the
content, the way T2.2 did, because it is a test of the documents rather than new demo content.
Fixed the five defects that walk found: two in the template, three in the prose.

**Why.** T2.2 performed the area, NPC and conversation sections and found six defects. Everything
the document has gained since — the world map, surfaces and attributes, equipment and the gate
that reads it, quests, counted steps, the `obj/` writers — had been written and never walked.
Gotcha 44 is the argument: the states a consuming game passes through are exactly the states this
repository never sits in.

**Connects.** `tools/check_boundary.gd` (whole-word matching), `src/systems/debug/dev_stage.gd`
(`_stand_by` settles), `tests/unit/core_test.gd` (fixture-namespaced literals),
`tests/unit/dev_tools_test.gd` (+6 assertions), `docs/AUTHORING.md` (five corrections).

**The five defects.**

1. § Add an area ends at a RED rung 4 — it never names `data/areas/<id>.tres`, and § Put an area
   on the world map called that state "legitimate for a cupboard", which the suite disagrees with.
2. `check_boundary` matched SUBSTRINGS: an item called `pear` failed on `menus_test.gd`'s "and
   Load has appeared under it". Fixed to whole-word; the two genuine hits left were an engine
   test's throwaway `"apple"`/`"pear"` dictionary keys, now `fixture_`-namespaced.
3. `--stand-by` always resolved in the DEPARTURE area, so no object in an authored area could be
   photographed. Fixed with `_settle_stable(SETTLE_FRAMES)`.
4. The quest writers table named no `obj/` field. `obj/orchard/bramble_way/opened` (the field is
   `open`) passed `check_content`, drew its objective and could never finish.
5. § Tag the ground you walk on cannot be verified by any command at all.

**Verified.**

Import exit 0, zero `SCRIPT ERROR` / `Parse Error`. Boot `Session ended after 0.5s — 0 warnings,
0 errors`. Suite `=== 1607 passed, 0 failed, 0 skipped ===` (1601 + 6). `check_content`,
`check_boundary`, `check_budgets`, `check_strings` all exit 0. Stripped template
`=== 1533 passed, 0 failed, 25 skipped ===` — 1527 + 6, no new skip.

*The area section's own commands, followed exactly, with only the scene and the CSV row:*

```
=== 1621 passed, 4 failed, 0 skipped ===
FAILED: every authored area is on the map — expected 3, got 2
FAILED: orchard has an AreaDef — expected true, got false
FAILED: orchard name keys agree — expected true, got false
FAILED: orchard arrival spawn exists — expected true, got false
```

*The boundary gate, on an item called `pear`, before the fix:*

```
  !! res://tests/unit/core_test.gd:74 names demo content 'pear' (from res://data/items/pear.tres)
  !! res://tests/unit/core_test.gd:77 names demo content 'pear' (from res://data/items/pear.tres)
  !! res://tests/unit/menus_test.gd:112 names demo content 'pear' (from res://data/items/pear.tres)
FAIL — 3 boundary violation(s)
```

`menus_test.gd:112` is `equal("and Load has appeared under it", rows[2], ...)`.

*`--stand-by` measured with a control, before the fix — all three `--new-game --goto=orchard`:*

```
--stand-by=GateNotice (a COURTYARD node) -> --stand-by beside 'GateNotice', sensor has 'NOTHING'
--stand-by=Warden     (an ORCHARD node)  -> ERROR --stand-by found no node called 'Warden'
--stand-by=BrambleWay (an ORCHARD node)  -> ERROR --stand-by found no node called 'BrambleWay'
```

and in every one of the three the `--stand-by` line printed BEFORE `--goto arrived in 'orchard'`.
After the fix, the same three, with the polarity correctly inverted:

```
--goto arrived in 'orchard'
--stand-by beside 'BrambleWay', sensor has 'BrambleWay'
--goto arrived in 'orchard'
--stand-by beside 'Warden', sensor has 'Talk'
--goto arrived in 'orchard'
ERROR: [test] --stand-by found no node called 'GateNotice'
```

*The `obj/` field, read out of a run — the document named none and `opened` was the guess:*

```
12:04:00 [INFO ] [test     ] --interact on 'BrambleWay'
12:04:00 [DEBUG] [flags    ] obj/orchard/bramble_way/open = true
```

**Planted, then removed (gotcha 23).**

*Plant 1 — the settle call deleted from `_stand_by`, the real failure shape:*

```
FAIL func _stand_by settles rather than only waiting for an area — expected true, got false
=== 1632 passed, 1 failed, 0 skipped ===   exit 1
```

The other two `_settle_stable(SETTLE_FRAMES)` calls were still in the file, so a whole-file scan
would have stayed GREEN — which is why the scan is function-scoped (gotcha 43). Restored:
`=== 1633 passed, 0 failed, 0 skipped ===`, exit 0.

*Plant 2 — a WHOLE-WORD violation on a permanent demo id, to show the fix did not blunt the gate:*

```
!! res://tests/unit/core_test.gd:39 names demo content 'rose_key' (from res://data/items/rose_key.tres)
FAIL — 5 boundary violation(s)   exit 1
```

*Plant 3 and its CONTROL — `"the rose_keys hung by the door"`, a longer word containing an id:*

```
with the WHOLE-WORD matcher (new):   PASS                       exit 0
with the OLD substring matcher:      FAIL — 4 boundary violation(s)   exit 1
  !! core_test.gd:39  names demo content 'rose_key'   <- from "rose_keys"
  !! menus_test.gd:112 names demo content 'pear'      <- from "appeared"
```

A fix that makes a gate accept MORE has to show it still refuses, so plant 2 and plant 3 are one
pair. Both use permanent demo ids, so they are repeatable now the walkthrough content is deleted.

**Captures, LOOKED AT and READ (gotcha 28).** Five, all windowed at 960x540, `--time=12:00
--freeze-time`. `orchard.png` — the new area entered by `--goto`, toast "The Orchard is added to
your map", HUD `Day 1 | 12:00 | Midday`, the warden drawn. `journal.png` — `The Windfall` and
`— Gather three pears.   2 / 3`, posed with `--give=item/pear:2`. `map.png` — "The Orchard · you
are here" in white at the authored `(0.61, 0.24)`, measured on the plate at 0.61/0.24; "Rose
Courtyard" gold; the hall a grey `???`. `talk.png` — the dialogue box, speaker `Warden`, the
first-meeting line mid-typewriter, whose effect wrote `met/warden` and started the quest.
`refused_goto.png` — the authored arch refusing with the authored line, "The brambles are thick,
and your hands are bare.", **reached by `--goto`, which is the capture that was impossible before
the fix**.

**Unblocks.** Nothing was blocked. Phase T4's third criterion — a release tag — remains open and
remains the owner's; asked on 2026-09-02, the answer was *not yet, merge the stack first*.

**Gaps.** No `check_content` rule for `obj/` flags: it would need each prefab class's field
constant, which is a list in a tool naming engine internals that `check_boundary` cannot keep
honest — the field table plus "read it out of a run" is the cheaper truth. The world-map assertion
was NOT weakened to match the prose; the prose was the thing written from intent. And § Tag the
ground still has no command, because there is none to give: no debug flag walks the player.

**CI green, run `33599084960`, JOB LOGS read rather than the tick (gotcha 26).** Full checkout
`=== 1607 passed, 0 failed, 0 skipped ===`; stripped template `=== 1533 passed, 0 failed, 25
skipped ===`. `check_content`, `check_boundary`, `check_budgets` and `check_strings` all PASS in
both jobs. Committed as `4f5f753`, PR #26, stacked onto `claude/wp-t4-version-upgrade`.

---

## 2026-09-03 — T4.3 · `NEW_GAME.md` performed, and the release tag taken

**Did.** Landed the whole PR stack on `main`, tagged `v1.0.0`, then performed `docs/NEW_GAME.md`
end to end as a consuming fork and fixed the two defects doing so exposed. Bumped the template to
`1.0.1`.

**The tag first, because it was the owner's decision and it was still blocked.** Phase T4's third
exit criterion had been put to the owner on 2026-09-02 and refused — *not yet, merge the stack
first* — because `origin/main` was at `d0bf153`. It still was. All 26 PRs were open and zero were
merged, so the refusal's reason had not expired. What HAD changed is that the stack turned out to
be one linear chain: `git merge-base --is-ancestor` confirmed every one of the 25 ancestor
branches was contained in T4.2's tip, 71 commits ahead of `main`. So retargeting #26 to `main` and
merging it landed all of them at once (`648bac1`), and only then was `v1.0.0` a tag that names a
tree actually declaring `base/version="1.0.0"`. Put back to the owner with that answer in hand,
and authorised. Six PRs auto-closed as merged; the other 19 could not be retargeted — GitHub
refuses with *"There are no new commits between base branch 'main' and head branch"* — so they
were closed with a comment rather than left stale. They read **Closed**, not Merged; their commits
are all in `main`.

**Why perform the document at all.** Three documents had been walked before this (T2.2, T4.1,
T4.2) and every single one found a defect that reading would not have. `NEW_GAME.md` is the one a
fork reads FIRST and had never been walked as its own document. A fresh `git clone` from GitHub
into `C:/Users/Lenovo/AppData/Local/Temp/gup` — short path, because a clone into the session
scratchpad fails with `Filename too long` — then sections 1 to 4 followed literally, with `src/`
never opened while performing.

**DEFECT 1, and it is the TEMPLATE.** `tests/unit/core_test.gd:154` asserted
`equal("a template with a game in it names one", configured != "", true)` — UNCONDITIONALLY.
Three things in the repository already said that was wrong: the case's own name, which is
conditional; the comment eight lines below it in the same function, *"An UNSET first area is a
real state — a template nobody has put a game in yet"*; and `NEW_GAME.md` section 4, *"An empty
setting is a legal state."* The file's own header MUST NOT line forbids it too — "must not know
about gameplay or content" — and whether a game is configured is a claim about the project, not
about `GameConfig`. Gotcha 46's shape, one function lower down.

It was green in the full template (`first_area="courtyard"`) and green in the stripped template
(which deletes `data/` and `scenes/areas/` but never touches `project.godot`, so the field stays
`"courtyard"`). It was red **only** in a fork that had done what the document says: `1537 passed,
1 failed, 20 skipped`, exit 1, `FAILED: a template with a game in it names one — expected true,
got false`. That is the third instance of gotcha 44/45's family and the second in a TEST.

The control that settles what it was really asserting: setting `first_area="tideglass_field"` — an
area that does not exist — made the suite go `1538 passed, 0 failed`. It demanded a non-empty
STRING, so it passed for content that was not there and failed for the honest empty state.

Removed rather than made conditional, because `smoke_test.gd` already makes the claim properly:
gated on `Fixtures.area_ids()`, and stronger, since it also requires the named area to resolve.
`plan(50)` became `plan(49)`, and the docstring now says why it must not come back.

**DEFECT 2: section 3's prune list never learned about quests.** The prefix list — `area. talk.
action. object. item.` — was written at T1.2, before quests existed (WP-08), and was never
extended. So a fork that followed the document exactly kept five rows of pure demo content in its
own `localization/strings.csv`: `quest.keepers_errand.*`, including *"The Keeper's Errand"* and
*"three rose petals"*. Every one of the four checkers exited 0 and the whole suite was green,
because **no gate reads `localization/` for demo content at all** — `check_boundary` guards
`src/`, `tests/framework/` and `tests/unit/`, and a leftover row is nobody's error: it is a
translation for content that was deleted, so nothing loads it and nothing complains. Verified that
every `quest.*` key is demo and that the engine's own quest strings live under `notify.quest.*`,
which the prune correctly keeps. The list now includes `quest.`, and the section carries a third
trap saying no gate checks this file, with a grep to run afterwards.

**Three prose defects, re-measured rather than inherited.** The `awk` comment claimed "keeps 147
of 189 rows"; the file is 219 rows and the corrected `awk` keeps 168. Section 6's quoted checker
output was from T1.2 and had drifted — it lacked the `quests: 0` line entirely and said `src
scripts scanned: 74` where the tool now prints `engine scripts scanned: 129, over src/ and
["res://tests/framework", "res://tests/unit"]`. And the intro said "rename four fields in
`project.godot`" where section 4's table lists five.

**A fourth, which is the one that would have wasted an afternoon.** Section 6 asserts that
starting a game with no `first_area` logs a specific error, but gave no command for it. The
natural invocation, `--headless --new-game`, prints nothing at all and ends `0 warnings, 0 errors`
— Godot swallows the flag without a `--` separator, so the run stops at the main menu having
started nothing. `--quit-after` counting FRAMES makes it worse: below about 120 the run ends at
the menu before the flag fires, which looks identical. Two ways to get a green run that verified
nothing. The corrected command is `"$G" --headless --quit-after 180 -- --new-game`, and it
reproduces the documented line verbatim, including *changes nothing*.

**Verified.** Local ladder on the final tree: import 0 script/parse errors; boot `Session ended
after 0.8s — 0 warnings, 0 errors`; suite `=== 1608 passed, 0 failed, 0 skipped ===`, exit 0;
`check_budgets`, `check_content`, `check_boundary`, `check_strings` all exit 0.

**The suite total moved and it was predicted.** 1607 to 1608: minus the one assertion removed,
plus two, because `docs_test` computes its plan from the docs and section 6's corrected checker
output introduces `res://tests/framework` and `res://tests/unit` as newly-named paths.

**Planted, both directions (gotcha 23), and the fix that accepts MORE has a control.** The defect
itself was the plant, found in a real fork rather than manufactured. Removing an assertion widens
what the suite accepts, so the control is the one that matters: copying an area back into the fork
with `first_area` still empty turned it red again — `FAILED: the configured first area is set` and
`FAILED: and its scene really exists`, exit 1, both from `smoke_test.gd`. A game WITH areas and an
unset first area is still caught, and caught by the assertion that names the right thing. (That
plant also produced five incidental failures, from copying an area without its `AreaDef` or its
CSV rows — which is `world_map_test` doing exactly what T4.2 refused to weaken.) For the CSV: the
old `awk` leaves 5 demo rows, the corrected one leaves 0, and the new trap-3 grep returns nothing.

**Measured, on the final tree, because the document quotes both.** A fork that has followed
sections 1 to 4 with `first_area` empty: `=== 1539 passed, 0 failed, 20 skipped ===`, exit 0 —
twenty assertions across fifteen named cases. The stripped-template variant CI runs, which deletes
the `data/` folders outright instead of emptying them: `=== 1534 passed, 0 failed, 25 skipped ===`,
all four checkers exit 0. Both are green and the counts differ because section 1 tells a fork to
KEEP the content roots. The banner line the document quotes was copied from the fork's own run,
not composed.

**Version bumped to 1.0.1, and the tag for it NOT taken.** T4.1's precedent decides this: stating
a version is engineering and is assertable, taking a tag is a release action and is the owner's.
Leaving `main` saying `1.0.0` after changing it would have made one version name two different
trees, which is the rot `version_test.gd` exists to prevent. `docs/CHANGELOG.md` gains a `## 1.0.1`
PATCH entry whose *a consuming game does* line is the actionable one: a fork made at 1.0.0 that
followed `NEW_GAME.md` should grep its CSV for `quest.` and delete what it finds.

**Unblocks.** Phase T4 is COMPLETE — all three exit criteria ticked, the third by the owner's
decision this session. Nothing is blocked; the next package is a genuine choice again, and
`docs/TESTING.md` is now the only document never performed.

**Gaps.** No gate reads `localization/` for demo content, and this package did not add one: it
would have to know which prefixes are engine, which is a list in a tool naming content
conventions, and the same objection that refused a `check_content` rule for `obj/` flags at T4.2
applies. The document's own trap-3 grep is the cheaper truth, and unlike a gate it is aimed at the
person actually holding the fork. The 19 superseded PRs read Closed rather than Merged, which is
GitHub's limitation, not a record problem — every commit is on `main` and reachable from `v1.0.0`.

**CI green, run `33785871834`, JOB LOGS read rather than the tick (gotcha 26).** Full checkout
`=== 1608 passed, 0 failed, 0 skipped ===`; stripped template `=== 1534 passed, 0 failed, 25
skipped ===`, the 25 skips unchanged from T4.2. `check_budgets`, `check_content`, `check_boundary`
and `check_strings` all PASS in both jobs. Committed as `4ec29fb` on
`claude/t4-3-new-game-perform`, PR #27 — targeting `main` directly, because the stack it would
have been stacked onto is now merged.

**PR #27 merged and `v1.0.1` tagged, 2026-09-03.** Merge commit `a291691`; `main` verified to
carry `base/version="1.0.1"` and a matching `## 1.0.1` heading before the tag was cut. Asked for
separately from the bump and authorised, which is T4.1's precedent held to: the bump ships with the
package, the tag is a release action and is the owner's. Two tags now stand and each names the tree
that declares it — `v1.0.0` on `648bac1`, `v1.0.1` on `a291691`. The claims in `CONTEXT.md`,
`SYSTEMS_INVENTORY.md` and the board that said the 1.0.1 tag had NOT been taken were corrected in
the same breath, because a state file that is stale about a release is the drift this project
polices.

## 2026-09-04 — T4.4 · `TESTING.md` performed, the last document never walked

**Did.** Performed `docs/TESTING.md` as a consumer adding assertions to a suite they did not
write, from the document alone. Found and fixed one defect in the TEMPLATE — the test runner
silently skipped a listed case that did not parse, at exit 0 — plus three in the prose. Kept one
of the new assertions because it covers something genuinely missing, deleted the throwaway, added
a gate over a number three documents disagreed about, and bumped the template to `1.0.2`.

**Why perform the document at all.** Four had been walked before this — T2.2 (`AUTHORING.md`'s
first half), T4.1 (`UPGRADING.md`), T4.2 (the rest of `AUTHORING.md`), T4.3 (`NEW_GAME.md`) — and
every single one found a defect reading would not have; two of the four were defects in the
template rather than the prose. `TESTING.md` was the last one never walked. The mechanism is not
negotiable and it is the whole method: do what the document says a consumer does, from the
document alone, and treat a wall as a FINDING rather than as a reason to go and read the code.
`src/` and the existing test files stayed shut while performing; the only framework files opened
were the ones the document itself points at, and each time it had to be opened is recorded below
as a gap in the document.

**The first run found the template defect, and found it by accident, which is the point.** Step
one was to copy the document's own worked example verbatim into `tests/unit/inventory_order_test.gd`
and register it in `CASES`, as rule 5 says. The example does not compile. The suite's answer:

```
SCRIPT ERROR: Parse Error: Identifier "inventory" not declared in the current scope.
   at: GDScript::reload (tests/unit/inventory_order_test.gd:14)
SCRIPT ERROR: Parse Error: The method "count()" is not present on the inferred type "Variant"
   (but may be present on a subtype). (Warning treated as error.)
ERROR: Failed to load script "tests/unit/inventory_order_test.gd" with error "Parse error".
SCRIPT ERROR: Invalid call. Nonexistent function 'new' in base 'GDScript'.
=== 1608 passed, 0 failed, 0 skipped ===
```

Exit 0. `0 failed`, `0 skipped`, a whole case never run, and a last line byte-identical to one
from a checkout where the file does not exist. (The `res://` prefix is stripped from those two
lines here only in the board's copy of them, where `docs_test.gd` would fail on a deleted path;
`DEVLOG.md` is exempt from that scan, so the engine's lines stand as printed except for the
prefix being retained — see the gap note below.)

**The chain is three facts this project already knew, meeting where nobody looked.** `load()` on
a script with a parse error returns a `GDScript` that is **not `null`** and cannot be instantiated.
`_run_case` tested only for `null`, so it walked into `script.new()`. And the failure of that call
is a GDScript runtime error, which **gotcha 24 established aborts only the innermost frame** — so
`_run_case` itself aborted, the `does not extend TestCase` failure two lines below was never
reached, and the `for` loop in `_ready` carried on to the next case. The sharpest part:
`tests/framework/error_watch.gd`, T1.3's SECOND mechanism, built precisely because the plan had
been measured and found insufficient, **had counted the error the whole time.**
`_no_script_errors` is read per case from *inside* `_run_case`, after `run()` returns, so an error
raised on the way IN is tallied by the watch and read by nobody. Three correct mechanisms, all
silent: the plan never ran, the manifest was satisfied because the file WAS listed, and the watch
was never asked.

**Two guards, and the second is the general one.** `script.can_instantiate()` before instantiating
— checked against the API dump first (gotcha 17), `Script.can_instantiate() -> bool`, present in
`doc/classes/Script.xml` — which records a failure naming the file. And
`_no_unattributed_errors()`, run once after the loop, failing on any engine script error that no
named case accounted for. The second exists because the next hole in that wall will not be a parse
error, and because gotcha 24's reasoning applies to the RUNNER as much as to the cases: the code
that judges whether a frame aborted is written in the same language and aborts the same way, so
the backstop had to be a separate check rather than a better per-case one.

**Planted, both directions (gotcha 23), and then caught a real mistake unprompted.** The plant is
a parse error appended to `version_test.gd`, a case with nothing else wrong with it:

```
res://tests/unit/version_test.gd is listed but does not parse, so it never ran
FAILED: 2 engine script error(s) were raised outside any case: ["Parse Error: Identifier
  ... not declared in the current scope. at res://tests/unit/version_test.gd:123 in
  GDScript::reload()", ...]
=== 1591 passed, 2 failed, 0 skipped ===
```

Exit 1, both guards firing independently, file and line named, the parse errors quoted verbatim.
Removed, and the control is exit 0 at `=== 1624 passed, 0 failed, 0 skipped ===`. Better evidence
than the plant arrived by accident later in the same package: writing `doc_counts_test.gd`, a
backslash was eaten in transit and produced `Invalid escape in string. at
res://tests/unit/doc_counts_test.gd:29` — and the new guard reported it, by file and line, on a
genuine mistake, where the old runner would have carried on green and left a case that never ran.

**The document's one worked example was wrong twice over.**
`equal("an empty inventory holds nothing", inventory.count(), 0)` is the only assertion example in
`TESTING.md`. **Nothing declares `inventory`** — `TestCase` provides `plan`, `equal`, `skip`,
`build` and `attach` and no content at all, which the document nowhere stated. **And `Inventory`
has no `count()`**; it has `distinct_count()`, `total_count()` and `count_of(id)`. So a consumer's
first act on this document is a compile failure, and until this package a *green suite* hid it.
The replacement was written and then RUN as a real case before being put into the document —
non-negotiable #1 aimed at prose, which is gotcha 47's rule.

**Three documents, three different answers to a countable question.** `CLAUDE.md` said forty-four
in two places, `CONTEXT.md` said forty-eight, `TESTING.md` said forty-three, over a list of
forty-eight entries. Each was true when written and none was updated. `tests/unit/doc_counts_test.gd`
counts the entries in `CONTEXT.md`'s gotcha section, asserts they run 1..N with no gap or repeat,
spells the number, and requires every document stating it to state that one. It is **its own file
rather than three checks inside `docs_test.gd`**, whose MUST NOT line forbids asserting anything
about what the documents SAY — non-negotiable #4 says add a system rather than widen a boundary.
Planted twice: a fiftieth gotcha with no count updated fails all four claim sites at once
(`expected fifty, got forty-nine`), which is the rot that actually happened; `CLAUDE.md` alone
drifted back to forty-four fails exactly one, naming the file. Both exit 1, both restored, control
exit 0. **The gate had a hole of its own on the first pass and it was gotcha 43's shape** — the
section heading is the PRIMARY statement of the count and was being swallowed by the section it
opens, so the gate would have passed while the list's own title was wrong. It is kept as a claim
now, and the heading is one of the four sites the plant fails.

**The gate's first run also failed on a FALSE positive, and narrowing it is the finding.** Gotcha
35's own prose says a staging wait requires "twenty CONSECUTIVE settled frames" — a tens-word on a
line that mentions gotchas, read as a claim about the list's length. The count is never quoted
inside the list, so the scan now skips the section's body and keeps only its heading. Only
tens-words are looked for at all, so "gotcha 22's family, one level up" cannot be mistaken for a
count either.

**The assertion that was KEPT, and why.** The throwaway case was deleted — it was a test of the
document. `tests/unit/bag_mirror_test.gd` was kept, because it covers something genuinely missing:
`Inventory.add` carries a comment saying `_publish()` runs BEFORE either signal, "so nothing woken
by one reads a flag that still says the old number", `remove` has the identical ordering and no
comment, and **nothing asserted it on either path.** A listener reacting to `item_gained` by
reading `bag/<carrier>/<item>` would have read the previous count, with an off-by-one in whatever
it drew as the only trace. Ten assertions. Planted on both sides: `_publish()` after
`Events.item_lost.emit` gives `FAIL the flag already read the REMAINDER inside item_lost —
expected 3, got 5`; after `Events.item_gained.emit` gives `expected 5, got -1`. **Nothing else in
the suite failed on either plant** — 1616/2 and 1617/1 — which is the proof the invariant was
uncovered rather than covered twice. `git diff src/` is empty; both plants were fully restored.

**One of the ten caught the author rather than the code**, and it is worth the line: the first
version expected `0` from the row of a stack spent to nothing and got `-1`, because `_publish`
ERASES rather than zeroes — deliberately, on `Equipment.unequip`'s reasoning, and its own comment
says so. The code was right and the assertion was wrong. The final version asserts the erase
explicitly and tallies the emissions, because otherwise an absent row and a handler that never ran
are the same reading. The plan caught a miscount in the same file on the way:
`bag_mirror_test planned 9 outcomes and produced 10 — a crash, an early return or a stale plan`,
which is rule 3 doing exactly what it promises.

**Verified.** Local ladder on the final tree. Rung 2 `--headless --import` greps to **zero**
`SCRIPT ERROR` / `Parse Error`. Rung 3 `--headless --quit-after 30` ends
`0 warnings, 0 errors`. Rung 4 is `=== 1625 passed, 0 failed, 0 skipped ===`, exit 0. All four
checkers exit 0, and all four exit 0 against the stripped tree as well. Budgets: `test_runner.gd`
138/250, `bag_mirror_test.gd` 58/250, `doc_counts_test.gd` 91/250.

**The suite total moved twice and both moves were predicted.** 1,608 to 1,624 is ten assertions
from `bag_mirror_test.gd` plus six from `doc_counts_test.gd`. Then 1,624 to 1,625, because
`docs_test.gd` COMPUTES its plan from the documents and the board's new section names one more
`res://` path — the same mechanism that moved T4.3's total by one, arriving from the other
direction. **And it caught a real mistake in this package's own prose:** the board first quoted
the engine's `res://tests/unit/inventory_order_test.gd` lines verbatim, and since that throwaway
was deleted, `FAIL WORK_PACKAGES.md names res://tests/unit/inventory_order_test.gd, which exists
— expected true, got false`. `DEVLOG.md` is exempt from that scan for precisely this reason and
the board is not, so the prefix is stripped in the board's copy with a note saying why.

**Measured, not inherited, because the document quotes both figures.** Stripped template — the
tree copied without `.git`/`.godot`/`build`, then `data/` and `scenes/areas/` removed — reports
`=== 1551 passed, 0 failed, 25 skipped ===`, exit 0, up seventeen by the same arithmetic, and **the
25 skips are unchanged**: neither new case adds one, since `Fixtures.activate()` works in a
stripped checkout and the documents are still there. So there is no new skip to name. All four
checkers exit 0 with `--path`. `TESTING.md`'s stated total had said 1,574 and is now both figures,
with an instruction to re-measure rather than quote.

**No capture and no probe, deliberately.** This package changes no rendering, no input path and no
engine file — `git diff src/` is empty and `git diff src/systems/debug/` is clean. A windowed
capture would photograph something it did not touch, which is ceremony that later reads as
evidence.

**Version bumped to 1.0.2, and the tag for it ASKED FOR AND DECLINED.** T4.1's precedent working
rather than suspended — the bump ships with the package and the tag is a separate request the
owner answers. `v1.0.0` and `v1.0.1` were each asked for that way and granted; this one was
declined on 2026-09-04, so `main` declares `1.0.2` with no tag naming it.
`docs/CHANGELOG.md` gains a `## 1.0.2` entry whose *a consuming game does* line is honest about
the one visible consequence — a game whose suite holds a case that does not compile will see rung
4 fail where it previously passed, and that is the bug being fixed rather than a new restriction,
because the case was never running.

**Unblocks.** Nothing, and that is the state of the board: Phase T4 closed at T4.3 and this
package adds no exit criterion. All five consumer documents have now been PERFORMED. The next
package is a genuine choice rather than a queue — WP-10 crafting, still OPTIONAL and blocking
nothing, or nothing at all, which is a defensible answer for a base that has answered every
question it set out to. That is the owner's call and it is being put to them rather than taken.

**Gaps.** The document still does not tell a consumer how to obtain the system under test — it now
says `TestCase` hands you nothing, which is the honest half, but a case asserting about
`Inventory`, `Equipment` or `QuestTracker` has to discover from engine code that they are
components reached by `Inventory.of(who)` and constructed with `.new()`. That is arguably
`AUTHORING.md`'s or `ARCHITECTURE.md`'s job rather than this document's, and it was left rather
than guessed at. `FixtureContent`'s function surface is still undocumented beyond the pointer
added here; a case needing a fixture shape the six existing items do not cover must read that
file. And `doc_counts_test.gd` guards exactly one number, on purpose — its MUST NOT line refuses a
second unrelated one, because a count with no countable thing behind it belongs in review. The
suite total quoted in `TESTING.md` is such a number and is deliberately left ungated, with an
instruction to re-measure instead.

**CI green, runs `33840155182` and `33840636717` — the second on the final commit `91e2054`, because the closing doc commits change the suite total by changing what `docs_test.gd` computes its plan from. Job logs read rather than the tick (gotcha 26).** Both jobs report
`success`. Full checkout `=== 1625 passed, 0 failed, 0 skipped ===`; stripped template
`=== 1551 passed, 0 failed, 25 skipped ===` — byte-identical to the local measurements, and the
25 skips unchanged from T4.3. All four checkers pass in both jobs. The only `error:` strings
anywhere in the log are the workflow's own `::error::` echo lines for the failure path it did not
take, plus the expected "couldn't open directory" notices for the content roots in the tree
where that content is deliberately deleted.

## 2026-09-04 — T5.1 · The skeleton's four open exit criteria, closed by proving them

**Did.** Closed the last four unticked exit criteria in `docs/ROADMAP.md` — three in Phase 1 and
one in Phase 2 — by PROVING each rather than ticking it. One of the four turned out to be a
genuinely missing FEATURE rather than an unproved one. Phase 2 is COMPLETE and **every criterion
in the roadmap is now ticked**. Template bumped to `1.1.0`.

**Why this package exists at all, having just declared the base done.** T4.4 closed the board on
the owner's instruction, and the very next question was whether the skeleton was actually
finished. Reading the roadmap rather than the summary answered no: **Phase 1 read COMPLETE while
carrying three unticked exit criteria, and Phase 2 read IN PROGRESS with one.** Nobody had lied —
each criterion was ticked as it was proved, and the three awkward ones were left. That is the
drift this project polices everywhere else, sitting in the one file that says whether the project
is finished. The owner reopened the board to close them.

**THE ONE THAT WAS A MISSING FEATURE: the locale setting was wired to nothing.** Phase 2's
"switch language at runtime and see every visible string change" could not pass, and no amount of
care would have found it by reading `settings_screen.gd`, which does exactly the right thing —
it cycles `TranslationServer.get_loaded_locales()` and stores the choice through
`Settings.set_value`. `Settings` then announces `setting_changed` and **nothing anywhere calls
`TranslationServer.set_locale`.** Grepped to be sure: the only hits were the settings screen
reading the loaded list. So the language could be chosen, was persisted, survived a relaunch, and
changed nothing. Fifth instance of this project's most expensive shape — declared, validated, and
read by nothing — after `Gate.locked_key`, `PathAction.refusal_key`, `ItemDb.reload` and
`HD2DCameraRig`'s framing exports.

**And there was nothing to switch TO, which is why the wiring alone would not have closed it.**
`localization/strings.csv` had one locale column. `get_loaded_locales()` returned `["en"]` —
measured, not assumed — so the settings screen's locale stepper had been cycling a list of one for
as long as it had existed. `tools/gen_pseudolocale.gd` generates an `en_XA` column, wrapping each
English value as `[~~English~~]`. That is the same argument that generates placeholder ART instead
of shipping art: the stand-in exists so the SYSTEM can be verified before the content is, and a
real second language is 218 rows the template has no business inventing.

**`Settings` applies it, on `_apply_display`'s reasoning rather than by analogy.** That function's
comment already said why it exists — *"nothing else owns the window"* — and the identical sentence
is true of `TranslationServer`. A consumer would have to be a system, and "the language" is not
one: every screen reads it and none owns it. Deliberately NOT skipped under headless, which is the
one way it differs from the display: a translation has no window in it, so the suite asserts
against `tr()` rather than trusting a screenshot.

**`check_content.gd`'s CSV rule had to be generalised, and the generalisation is better.** It
failed any row parsing to more than TWO columns — the rule that catches WP-01's unquoted comma —
so the second language would have failed the gate that exists to protect the first. It now compares
against the HEADER width, and demands equality rather than a maximum so a half-added locale filling
only some rows is caught as well. Planted with the original bug: unquoting WP-01's own row gives
`object.lever.gate.on has 4 column(s) where the header has 3, so an unquoted comma has cut its text
off at "The lever gives with a heavy clack. Somewhere north"`, exit 1. Restored, exit 0. The same
defect, still caught, one column wider. `store_csv_line` does the quoting in the generator for
exactly this reason — writing the CSV by hand is how that bug comes back.

**A CAPTURE FLAG THAT PERSISTS BROKE THE SUITE IN FOUR UNRELATED CASES, and that is gotcha 50.**
`--locale=` goes through `Settings.set_value` on purpose, because a flag that set
`TranslationServer` directly would photograph a path no player can take. `set_value` calls
`save()`. So the `en_XA` capture left the setting on disk, and the next suite run failed in
`items_test` and `screens_test` with `expected fixture.fixture_stack.name x3, got
[~~fixture.fixture_stack.name x3~~]` — four failures, in files this package never touched, from a
screenshot taken ten minutes earlier. `test_runner.gd` now pins the language for the same reason
it already pins `Clock.paused`, and reads the fallback from `ProjectSettings` rather than
hard-coding English so a consuming game whose default is not English gets a deterministic suite
too.

**The eight-direction criterion needed assertions, not a screenshot, and gotcha 28 is why.**
`art_contract_test.gd` proves the LAYOUT's quantisation for all eight sectors, but its MUST NOT
line forbids asserting what a character looks like, and `character_depth_test.gd` owns attributes
and surfaces — so nothing connected a direction of TRAVEL to a column. `tests/unit/facing_test.gd`
is that connection, 21 assertions. **Every one is camera-yaw independent on purpose:**
`_screen_angle` subtracts the active camera's yaw so "towards the camera" is the front pose
whatever angle an area frames from, which is a feature and which makes "north-east is column 3"
true for one camera only. So what is asserted is what holds for every camera — the eight
directions stay DISTINCT, and one sector of turn advances the facing by exactly one.

**Planted twice, and the second plant is the one that justifies the design.** Swapping the axes in
`_screen_angle` (`atan2(y, x)` for `atan2(x, y)`, the actual slip) gives
`a sector of turn from 0 advances the facing by one — expected 1, got 7` on all eight — **and the
distinctness and column-agreement assertions still PASS under it**, because a mirrored character is
still eight distinct poses consistently drawn. Only the turn-direction assertion sees it, which is
gotcha 28 in assertion form. Deleting the standing-still guard gives
`a direction shorter than the guard does not turn the character — expected 0, got 2`. Both exit 1;
control `facing_test: 21/21`, exit 0.

**Then the walk-through itself, because the criterion says "walk".** A temporary `--face-all` probe
drove the LIVE player through all eight directions in the courtyard and reported
`facing=N column=N` for N in 0..7 against the real camera rig, with frame numbers logged so the
shutter could be aimed — sector 3 spans frames 123-162, so a capture at 140 is a checkable
prediction rather than a guess. Read at 1920x1080: the courtyard at midday, HUD `Day 1 | 12:00 |
Midday`, the prompt drawn, and the player drawn from BEHIND, which is what sector 3 (north-east)
should look like. Probe removed; `git diff src/systems/debug/` is clean.

**THE SAVE CRITERION NEEDED TWO PROCESSES, and the existing probe could not have closed it.**
`--cross-area-save` saves and reloads IN PROCESS, which cannot tell a value read back from disk
from one that was never cleared — and "quit and relaunch" is precisely the case where nothing is
left in memory to be right by accident. `--save-state=<slot>` and `--load-state=<slot>` are that
pair. Run one posed a state nothing like a fresh game and saved it; a fresh process reported it
back:

```
run 1  --save-state before: area='lantern_hall' at=0.00,-4.20 day=3 time=21:45 weather=4 carrying=1
run 2  --load-state at boot: area=''            at=0.00,0.00  day=1 time=06:00 weather=0 carrying=0
run 2  --load-state after:   area='lantern_hall' at=0.00,-4.20 day=3 time=21:45 weather=4 carrying=1
```

The middle line is the CONTROL and it is the point: at boot the fresh process has none of it.
**The weather is deliberately STORM (4) rather than CLEAR**, because CLEAR is the boot default and
a clear day saved and read back as a clear day proves nothing — the first version of this probe
made exactly that mistake and reported `weather=0` on both sides, which looked like a pass.

**The 30-second session had simply never been run.** The boot rung is 30 FRAMES at the main menu
(gotcha 31), so the criterion was measuring nothing. A windowed 33.6-second session that entered
the courtyard, baked its navmesh (92 polygons), opened the satchel, cycled the sensor and
interacted twice ended `0 warnings, 0 errors` with **zero** `SCRIPT ERROR`, `Parse Error` or
leaked-RID lines in 53 log lines. An idle 30 seconds passed too, but a session where nothing
happens is not a play session and was not accepted as one.

**`save` and `load` joined the console**, because the criterion needed a save from the command line
and the settled decision is that the console and the command line are one implementation. Six
verbs now. Slots are zero-based, matching `SaveSystem` and the save screen — renumbering them for
friendliness would make `save 1` and menu slot 1 two different files. `dev_stage.gd` could not
host the flag: it is at **248 of its 250 code lines**, so the pair went to `dev_probes.gd`, which
owns scripted scenarios and already had `--cross-area-save`.

**The verb-count assertion caught the new verbs, which is it working rather than being in the
way** — `there are four verbs — expected 4, got 6`. It gained a companion that cannot rot: every
verb in `VERBS` must dispatch to something. Planted with a seventh verb declared and not wired,
and **the dispatch assertion fails independently of the count**, which is the case a dutifully
bumped number would have hidden.

**Along the way, the walk cycle was measured because the owner asked whether it animates.** It
does. Pressing the real movement action and reading the Sprite3D cell being DRAWN — not a private
counter — gives cells `6 -> 14 -> 22 -> 30` for column 6 (west), which is frames 0 to 3:
`4.04m over 60 frames, 8 cell changes` walking against `1.50m, 4 cell changes` sneaking, and
`standing still: drawn cell 6`, frame 0, the neutral pose. Two complete cycles per second walking
and one sneaking, which matches `walk_fps 8.0 * clampf(speed / 3.2, 0.35, 2.0)` exactly. **The
first attempt measured nothing** and is worth recording: driving `update_from_velocity` from a
probe proves nothing, because `PlayerController._physics_process` overwrites the visual from its
own velocity every frame. **And `run` is a TOGGLE, not a hold** — `Input.action_press(RUN)`
toggles it, so the first comparison had "running" covering 0.75m against walking's 2.30m, having
toggled off and then walked into the dais. Sneak is a hold. That is gotcha 51.

**Verified.** Rung 2 greps to zero `SCRIPT ERROR` / `Parse Error`. Rung 3 ends
`0 warnings, 0 errors`. Rung 4 is `=== 1653 passed, 0 failed, 0 skipped ===`, exit 0 — up 28 from
1,625: 21 from `facing_test.gd`, 6 from `core_test.gd`'s locale block and 1 from the new dispatch
assertion. All four checkers exit 0. Stripped template `=== 1579 passed, 0 failed, 25 skipped ===`,
exit 0, up 28 by the same arithmetic with **the 25 skips unchanged** — no new skip to name, since
`localization/` survives a strip and the locale block needs no demo content. All four checkers exit
0 with `--path`.

**Version bumped to 1.1.0 — MINOR, not PATCH, and the tag not taken.** The base gained something a
game may ignore, which is the CHANGELOG's own definition of MINOR. The `## 1.1.0` entry's *a
consuming game does* line is the actionable one: `strings.csv` will conflict (it always does), and
after resolving it a game either reruns `gen_pseudolocale.gd` or deletes the `en_XA` entry from
`project.godot` and drops the column — nothing under `src/` names it.

**Unblocks.** The skeleton is now complete in the sense the roadmap uses: **every exit criterion in
every phase is ticked, and each was proved rather than asserted.** The owner has since reframed
what the base is FOR — reusable character infrastructure that future games inherit by swapping
assets — and that reframing names the next package precisely. See gaps.

**Gaps, and the first is the next package.** **`SpriteSheetLayout.animation_for(moving: bool)`
takes a BOOLEAN**, so a sheet can only carry idle and walk blocks: run and sneak replay the walk
row faster and nothing else. Meanwhile `GameEnums.MoveState` has ten values, and
`Events.player_state_changed(state)` is declared AND emitted by `PlayerController` and **listened
to by nothing** — grep finds the declaration and the emit and no subscriber. So the animation block
should be chosen by `MoveState`, not by a bool, and then a sheet carries separate idle / walk / run
/ sneak / climb blocks and every future character gets them by asset swap with no code. That is the
sixth instance of declared-validated-and-read-by-nothing in this project, and it is the seam the
owner's reframing actually needs. Also open: no idle VARIANTS (a second idle block chosen by time
or at random), no turn-in-place, and the shipped placeholder declares `animations = 1` with
`idle_row = walk_row = 0`, so it has no separate idle at all — the alt sheet proves two blocks
work, the default one does not use them. And `--locale=` persisting is correct but sharp: anything
else that stages through a persisted setting will need the runner pin that gotcha 50 describes.

**CI green, run `33847717732`, job logs read rather than the tick (gotcha 26).** Both jobs report
`success`. Full checkout `=== 1653 passed, 0 failed, 0 skipped ===`; stripped template
`=== 1579 passed, 0 failed, 25 skipped ===` — byte-identical to the local measurements, and the 25
skips unchanged from T4.4.

## 2026-09-04 — T5.2 · An animation block per GAIT

**Did.** Made the animation block a function of `GameEnums.MoveState` rather than of a boolean, so
a sprite sheet can carry a separate cycle per gait and a character's movement styles come from its
art instead of its code. Added `run_row` / `sneak_row` / `climb_row` to `SpriteSheetLayout`, wired
the state through `CharacterVisual` from both the player and the NPC brain, gave the placeholder
sheet three readable blocks, and opened **Phase T5** on the roadmap. Template `1.2.0`.

**Why, and it is the owner's framing rather than mine.** T5.1 closed the last roadmap criteria, and
the owner then said what the base is FOR: reusable character infrastructure that future games
inherit by swapping assets — several idle formats, several movement styles — so a new game starts
from something working rather than going in blind. Asked what that needed, the answer was one seam,
and it was already half-built.

**THE SEAM WAS A BOOLEAN, AND THE INFORMATION IT NEEDED HAD NO LISTENER.**
`SpriteSheetLayout.animation_for(moving: bool)` — so a sheet could hold an idle cycle and a walk
cycle and that was the ceiling; run and sneak replayed the walk block faster and there was nowhere
to name a third. Meanwhile `GameEnums.MoveState` has had ten values since WP-01, and
`Events.player_state_changed(state)` is declared AND emitted by `PlayerController` — and **grep
found no subscriber at all.** So the sprite's own state was computed every frame, announced on the
bus every time it changed, and thrown away. **Sixth instance** of this project's characteristic
defect after `Gate.locked_key`, `PathAction.refusal_key`, `ItemDb.reload`, `HD2DCameraRig`'s
framing exports and T5.1's locale: not broken code, but correct code with no consumer. Worth
stating as a general suspicion — **a field validated by a checker and read by nothing is this
project's most reliable place to find a missing feature.**

**`-1` MEANS "REPLAY THE WALK BLOCK", AND THE DEFAULT IS THE WHOLE COMPATIBILITY STORY.** Row 0 is
a real row — normally the idle block — so defaulting the three new rows to `0` would have drawn a
STANDING character for anything running, on every sheet in every consuming game that had not been
updated. `-1` is the only value that can mean "I have not drawn this". The assertions are ordered
to match: the fallback is asserted before the feature, because the thing that must not break is
that a two-block sheet keeps drawing exactly what it drew. States with no gait of their own fall to
IDLE rather than to walk — no jumping and no swimming here, and `BUSY`/`LOCKED` mean something else
is driving, which looks like standing rather than walking on the spot.

**The visual is TOLD its state and does not listen.** A subscription to `player_state_changed`
would have been one line and wrong: every NPC draws through the same `CharacterVisual`, so all of
them would animate to the PLAYER's gait. The parameter defaults to `WALK` so an un-updated caller
behaves as before. `NpcBrain` passes `WALK` or `IDLE` from whether it is stepping and gets no
`MoveState` field of its own, which would be a second state machine to keep in step with the brain.
**The signal still has no listener, and that is correct** — the visual is pushed to, and a listener
would be a second route to the same fact.

**A one-frame lag that had been latent since WP-01.** `_update_state(wish)` ran AFTER
`visual.update_from_velocity`, so the sprite drew last frame's state. Invisible while nothing read
the state; a flicker on the first frame of every gait change the moment something did. Reordered.

**Planted twice (gotcha 23).** Removing the `>= 0` check gives
`gait 2 with no row of its own inherits the walk block — expected 1, got 0` — the exact regression
a consuming game would hit. Dropping `run_row` from `problems()` gives
`and it is a reported problem, not a silent clamp — expected true, got false`. Both exit 1; control
green.

**AND THE T4.4 GUARD EARNED ITS KEEP TWO PACKAGES LATER, unprompted.** Changing the signature broke
`art_contract_test.gd`, and rung 4 said
`res://tests/unit/art_contract_test.gd is listed but does not parse, so it never ran`, with all six
parse errors quoted by file and line. Before T4.4 that would have been `0 failed`, exit 0, with one
case silently skipped — which is exactly the false green that guard was built for, met by accident
rather than by a plant.

**Proved three ways, because the claim is visual and the failure mode is plausible.** 19
assertions; the ASSET measured by sampling its own pixels (256×576, block torsos reading
`(0.298, 0.447, 0.620)` blue, `(0.239, 0.518, 0.439)` green, `(0.620, 0.337, 0.298)` rust); and the
RUNTIME read off `sprite.frame` in the live courtyard — `idle: state=0 cell=0 block=0`,
`walk: state=1 cell=38 block=1`, `run: state=2 cell=78 block=2`, each cycling inside its own block.

**Three captures, and the walk one is the money shot.** The placeholder sheet gained a cloth tint
per block and a forward lean on the run, on the alt sheet's reasoning (gotcha 28) — a running
figure drawn from the walk block is still a person mid-stride, so the BLOCK has to be readable
rather than judged. **The player is in green and the keeper NPC standing beside them is in blue, in
the same frame, from the same sheet.** Two characters, two blocks. The run capture shows rust
against the NPC's blue.

**GETTING THOSE THREE CAPTURES COST AN HOUR AND IS GOTCHA 52.** `--shot-frame` aims at a frame
NUMBER, and the same number is a different moment every run: measured across runs of the identical
command, the player was grounded in its area at process frame **17** in one run and **115** in
another, because the area load is threaded. Three failures came out of that one fact. A shot aimed
early enough to catch a gait landed before the area existed, and a PNG of empty sky with a working
HUD reads as a rendering bug. A shot aimed late enough to be safe caught a character that had
walked clean out of the area — x went 0 to -16.8 by frame 115 at run speed. And an oscillation
added to keep it in frame introduced a one-frame window where velocity is zero between releasing
one direction and pressing the other, in which the visual correctly reports IDLE — so a walk
capture came back showing the idle block, and the honest reading of that was "the feature does not
work". What settled it was **asking the asset instead of the renderer**: one pixel sample of the
PNG proved the three tints existed, after which the remaining problem was obviously timing.

**A false alarm worth recording, because it looked like a serious bug for several minutes.** The
first gait probe reported the player at `y=-0.30` falling to `y=-20.54` with `is_on_floor()` false
throughout — "the player falls through the world". It was the probe: it awaited `_settled()` without
the `while Director.current_area_id == &""` wait that every other probe in that file opens with, so
it was measuring the body at the area origin BEFORE `Director` placed it on its spawn marker.
Gotcha 9 seen from a probe that arrived too early. With the wait, `grounded after 0 frame(s) at
y=0.00`.

**Verified.** Rung 2 zero `SCRIPT ERROR` / `Parse Error`; rung 3 `0 warnings, 0 errors`; rung 4
`=== 1676 passed, 0 failed, 0 skipped ===`, exit 0; stripped `1602 passed, 0 failed, 25 skipped`,
its 25 skips unchanged; all four checkers exit 0 in both trees. Budgets: `sprite_sheet_layout.gd`
34 → 62 of 250,
`character_visual.gd` 107 → 110, `gen_placeholders.gd` 129 → 143, `npc_brain.gd` 171 → 172.

**Version 1.2.0, MINOR, untagged.** The base gained something a game may ignore. The *a consuming
game does* line: nothing changes unless you want the gaits, but a game using the shipped
placeholder now has a 256×576 three-block sheet rather than 256×192 with one.

**Unblocks.** Phase T5's first two exit criteria are ticked: movement styles come from the sheet,
and the same seam serves NPCs with no NPC-specific animation code.

**Gaps, and all three are now roadmap criteria rather than notes.** **More than one idle** — the
block seam exists and what is missing is the chooser, which is the smallest remaining piece of
"characters feel alive". **A turn in place** — changing facing while stationary snaps between
columns. **A wholesale character swap, photographed** — the alt sheet proves the GRID swaps and
nothing yet proves the GAITS do, which is the T2.1-standard proof this row did not attempt. Also
still true: `Actions.DEBUG_FREECAM` is bound to nothing, and the default placeholder now has three
blocks but the ALT sheet still has two, so a sheet with a different cell size AND a full gait set
does not yet exist anywhere.

---

## 2026-09-04 — T5.3 · Delivering the gaits that were already declared

**Did:** an audit of the whole base, then fixed the two defects it found in the function T5.2 had
just touched. **`MoveState.CLIMB` never reached `CharacterVisual` at all.**
`PlayerController._physics_process` opens with `if _climbing: climb_step(delta); return`, so the
one line that hands a state to the visual (line 124) is unreachable for the whole duration of a
climb, and `climb_step` touched the visual only after `_enter_state(IDLE)`. There are exactly
three callers of `update_from_velocity` in the project — those two and `npc_brain.gd:108`, which
passes `WALK` or `IDLE` — so **nothing could ever pass CLIMB.** `SpriteSheetLayout.climb_row` was
exported, defaulted to -1, range-limited, matched in `animation_for`, counted by
`distinct_gaits()`, validated by `problems()` and asserted by `art_contract_test.gd`, and was
**impossible to draw.** `climb_step` now derives a velocity from the move it just applied and
drives the visual on both legs of the climb (`_drive_visual`), and `update_from_velocity` treats a
climb as moving even when the horizontal component is zero — which it always is on a ladder.
Second defect, same function: the `else` branch pinned `_frame = 0` whenever horizontal speed was
zero, so **no idle block had ever advanced a single cell.** Three of the shipped sheet's four idle
cells were undrawable. An idle block that DIFFERS from the walk block now advances at a new
`idle_fps` export (3.0, slower than a walk on purpose); a sheet whose idle *is* its walk block
still holds cell 0, because that is every sheet authored before T2.1 and animating it would be
walking on the spot. `_rate_for`, `_advance` and `_idle_animates` split out of what would
otherwise have been one function over the 40-line budget. New `tests/unit/gaits_test.gd`
(12 assertions) plus 6 in `traversal_test.gd`. Corrected four false docstrings in `events.gd` and
four stale document claims; added **gotcha 54**.

**Why:** because a ticked exit criterion was false, and on a project whose spine is "nothing is
done until the engine has run it" that outranks new work. The roadmap said "idle, walk, run, sneak
and climb each addressable" and climb reached nothing. The reason it survived is worth more than
the fix: **both ends of the seam were asserted and the wire between them was not.**
`traversal_test.gd:132` asserted `_mover.state == CLIMB` — the controller's own field.
`art_contract_test.gd:267` asserted `animation_for(CLIMB)` — a pure function on a fixture. Two
green assertions that between them look like coverage of the path, over a path that did not exist.
And it was invisible in the demo: the shipped sheet leaves `climb_row` at -1, so the fallback drew
the walk block and looked correct. The first observer would have been the first consuming game to
draw a climb cycle — exactly the audience Phase T5 exists to serve, which is what makes it worth a
row rather than a footnote. The idle defect is the same shape from the other side: "more than one
idle" was on the exit criteria while ONE idle had never animated, so the criterion as written
would have added a second static pose and left a held pose.

**Connects:** `PlayerController.climb_step` ↔ `CharacterVisual.update_from_velocity` ↔
`SpriteSheetLayout.animation_for` — the seam T5.2 built, now with its middle joined up and
asserted. Whether a standing character breathes is decided by the SHEET
(`animation_for(IDLE) != animation_for(WALK)`), which is the same fallback reasoning as
`run_row = -1`: the data answers, no flag is added, and no sheet authored earlier changes
behaviour. `idle_fps` sits beside `walk_fps` as a per-character export, so a game tunes a
character's idle without touching code. Nothing was added to `GameEnums`, `Events` or the layout
resource; the fix is entirely in the two files that were already wrong.

**Verified:**
- `--headless --import` → exit 0, **zero** `SCRIPT ERROR` / `Parse Error` lines.
- `--headless --quit-after 30` → `Session ended after 0.4s — 0 warnings, 0 errors`, exit 0.
- **The gate was proved by planting the real defect, not by watching it pass.** With the fix
  reverted (`git checkout --` on the two `src/` files, tests kept):
  `=== 1688 passed, 6 failed, 0 skipped ===`, **exit 1**, naming
  `a climb draws the climb block — expected 1, got 0` (twice, once per direction of the climb),
  `and its cycle actually advanced — expected true, got false` (twice),
  `and its cycle advances over a second — expected true, got false`, and
  `a distinct idle block advances while standing still — expected true, got false`.
  Fix restored: `=== 1694 passed, 0 failed, 0 skipped ===`, exit 0.
- `check_budgets.gd`, `check_content.gd`, `check_boundary.gd`, `check_strings.gd` → all exit 0.
- `traversal_test`'s `plan()` caught the stale count before I did: `56/50`, exit 1, *"planned 50
  outcomes and produced 56 — a crash, an early return or a stale plan"*. That mechanism works.
- **CI green on `0b6ca1e`, PR #32** — all four jobs pass. Full checkout
  `=== 1694 passed, 0 failed, 0 skipped ===`; **stripped template
  `=== 1620 passed, 0 failed, 25 skipped ===`**, which is the number that matters for a new test
  file: `gaits_test.gd` builds its own fixture layout and names no demo content, so all 18 new
  assertions survive the strip. Before this row the stripped run was `1602 passed, 25 skipped`.
- **Windowed capture** at 960x540, `--new-game --time=18:40 --freeze-time`: the courtyard renders
  with both characters lit, depth-sorted and casting shadows, the HUD reading
  `Day 1 | 18:40 | Dusk` and the prompt offering the notice. `0 warnings, 0 errors`, exit 0. Not a
  proof of the climb cycle — that needs a staged climb no dev flag can set up — but it is the
  regression check that matters after changing sprite code.

**Unblocks:** a consuming game can now author a climb cycle and see it. The first T5 exit
criterion is honest. `_advance` and `_rate_for` are the hooks a second idle block would use, so the
remaining "more than one idle" is now a chooser on top of working machinery rather than a rewrite.

**Known gaps:** deliberately not fixed here, because each is a different package and one of them is
a seam decision rather than a defect.
- **`face_direction()` still has only test callers**, so nothing changes facing while stationary at
  all — the "turn in place" criterion assumes a snap that does not happen. WHO may ask for a turn
  (the player facing an interaction target? an NPC facing the player in dialogue?) is a seam
  decision and was left to the owner rather than picked silently.
- **`HD2DCameraRig.set_dof_enabled()` has no caller** while the options screen offers
  `video/depth_of_field`. Documented in `SYSTEMS_INVENTORY.md` rather than fixed.
- **12 of 23 settings have no consumer** (the documented figure was 17, stale by five). Five are
  `accessibility/*`, which a game cannot wire without editing `src/`, and all twelve are drawn to
  the player. That is the settings package.
- **Music ducking is entirely dead** — `stop_music`, `duck` and `unduck` have no callers anywhere;
  the only `duck` hit in the repository is the phrase "duck-typed" in a comment. The natural home
  is `DialogueRunner`.
- **`Actions.JUMP` is in `REBINDABLE`**, so the rebind screen draws a Jump row for a feature the
  template states it does not have; `CAM_ZOOM_IN`/`OUT` and `DEBUG_FREECAM` are also polled by
  nothing. And `KeyBindings.rebind()` gates on `InputMap.has_action` rather than
  `Actions.REBINDABLE`, so an override installed outside the rebindable set cannot be reset —
  `reset_bindings()` re-declares only the four rebindable groups.
- **`Settings.reset_to_defaults()` never calls `_apply_locale()`**, so Reset writes `locale = "en"`
  and leaves the UI in the old language. One missing line, left with the settings package.
- **No gate enforces the layer direction, knows the signal registry's shape, or reads
  `localization/` for demo content.** The last is gotcha 48 and is measurable: 59 of 218 CSV rows
  are demo namespace, and T4.3 already recorded a fork shipping them green. These three are the
  enforcement holes that let this class of defect keep arriving through a green ladder, and a
  registry-liveness assertion would have caught `item_used` and `debug_command` on day one.
- **No windowed capture was taken for this row.** The fix is proved by decoding `sprite.frame`
  through the whole path, which is stronger than a screenshot for this defect (gotcha 28: a sprite
  drawn from the wrong cell is still a person), but the T2.1-standard photograph of a climb cycle
  belongs to the wholesale-character-swap criterion and is not claimed here.

## 2026-09-05 — T5.4 · The three missing enforcement gates

**Did.** Built the three gates the T5.3 audit named, wired both new ones into CI as their own
steps, and fixed the one real violation the layer gate found on its first run.

The audit's structural finding was that this project has gates for content, budgets, strings and
the demo boundary, and **not one of them asks whether a declared thing has a consumer** — which
is why "correct code with no consumer" has now been found seven times, every time through a fully
green ladder. Three gates close it, and each was proved red by planting a real violation and green
by removing it. Every result below is a measured exit code, not a claim.

**1. `tools/check_signals.gd` — signal liveness.** Every `signal` in the registry must have at
least one emitter. On its first run it named `debug_command`: declared, typed, documented, and
never emitted anywhere. `item_used` passed, because its doc block already said so in words.

The escape hatch is a phrase — `NO EMITTER` — written in the signal's own `##` block rather than
a list inside the tool, so the next reader of the declaration sees the decision without opening
anything, and a signal that carries the phrase AND has an emitter fails too, because a stale
exemption is how a gate rots into decoration. `debug_command`'s block now carries it and says why.

**The method trap is the reason this is not a grep.** Three quest signals are dispatched
INDIRECTLY, as first-class `Signal` values handed to a helper that calls `fact.emit.callv(args)`.
Measured control: a grep for `quest_started.emit` returns **0** sites, and the same for
`quest_advanced` and `quest_completed` — so a naive scan reports three false positives on a
correct registry. The gate resolves a bare `Events.<name>` by what its FILE does with a
`Signal`-typed identifier: `.emit` on one makes the file an emitter, `.connect` makes it a
listener, neither makes the reference count as nothing, which is the conservative direction
(it can only over-report, never miss). Result: **88 emit references over 40 of 42 signals**,
the other two exempt and both explaining themselves.

It also checks its OWN preconditions rather than assuming them: zero `[connection]` blocks in any
`.tscn` and zero `emit_signal(` string calls, either of which would let a signal be wired without
the text this tool searches for. Same shape as `check_boundary.gd`'s debug-gate precondition.

| Plant | Result |
|---|---|
| a new `signal planted_fact(value: int)` nobody emits | `!! planted_fact is declared and never emitted`, **exit 1** |
| `NO EMITTER` added to `hour_passed`, which has two | `!! hour_passed is marked 'NO EMITTER' and has 2 — the exemption is stale`, **exit 1** |
| an `emit_signal("flag_changed", ...)` call in the quest tracker | `!! ...calls emit_signal() by name — this gate cannot see that`, **exit 1** |
| all three removed | **exit 0** |

**2. `tools/check_layers.gd` — layer direction. THE TREE WAS NOT CLEAN.** The package brief said
it was, and the first run said otherwise: **55 upward references, exit 1.** `ARCHITECTURE.md:24`
states `core -> content -> systems -> gameplay -> ui, downward only` and gives the test —
*could you delete the layer above and still compile?* — and nothing had ever run it.

Forty-two of the fifty-five were `src/systems/debug/`, which is the development harness and
already carries exactly this exemption in `check_boundary.gd`, for the same reason and on the same
precondition: those files exist to drive every layer from outside, there is no layer above `ui` to
put them in, and their argument parsing is behind `OS.is_debug_build()`. Exemption granted,
counted and reported — **49 exempted references today**, so it cannot quietly grow.

**The other thirteen were real.** `src/systems/interaction/interaction_sensor.gd` was typed on
`Interactable`, which is `gameplay`. Delete `gameplay/` and `systems/` does not compile — the
document's own test, failed. And the file was in the wrong layer to begin with: its second line
says *"Lives as a child of the player"*, and `ARCHITECTURE.md` defines `gameplay/` as *things that
exist in the world — player, camera, areas, interactables* and `systems/` as *game-agnostic
services*. A player component is not a service. Moved to `src/gameplay/interaction/`, one
`ext_resource` path updated in `scenes/characters/player.tscn`, and the reference became downward
and legal with no exemption. **This is the eighth instance of the characteristic defect in a new
guise: not a declaration with no consumer, but a RULE with no gate** — the same shape as
`const FIRST_AREA := &"courtyard"` sitting in `core` before T1.2. It is gotcha 55.

The gate sees two kinds of coupling, because there are two: a `class_name` global, and a
`res://src/<layer>/` path literal, which is how `preload()` couples without naming a class. Both
planted separately, in `src/core/state/flags.gd`:

| Plant | Result |
|---|---|
| `var screen: UiScreen = null` | `!! ...(core) names UiScreen, which is ui`, **exit 1** |
| a `load()` of a `res://src/ui/screens/` path | **exit 1** |
| both removed | **exit 0** |

Nothing is listed that can be derived. Layers come from the path, `class_name` symbols from the
files that declare them, and the autoloads from `project.godot`'s `[autoload]` block — which is
what makes "the five autoloads under `src/systems/` are globals, so `gameplay` and `ui` may call
them" automatic rather than a carve-out somebody has to maintain: they are layer 2, so those
calls are already downward.

**3. `localization/` demo content, folded into `check_boundary.gd`** — which already derives the
forbidden-name set this needs, and was at 127 of its 250 lines. Gotcha 48 closed: `check_content`
and `check_strings` both open the CSV and both ask only whether a key a script names has a row.
Neither asks the opposite question, whether a ROW names content that exists.

**The two halves are deliberately asymmetric, and the header says why.** Presence is REPORTED:
the template legitimately ships its own demo rows, so failing on their existence would fail this
repository forever, and a gate switched off where it lives is decoration. Measured, and the
audit's figure of 59 corrected: **218 rows, of which 51 are content namespace** — `object` 24,
`talk` 10, `action` 6, `quest` 5, `item` 4, `area` 2. The audit counted 59 by including the eight
`item.category.*` rows, which are an enum's worth of labels and engine, not content.

What FAILS is the ORPHAN — a row naming content that is not there. That is the actual T4.3 defect,
it is wrong in the template and wrong in every game built on it, and it is the exact state a
half-finished prune leaves behind. Only the four namespaces whose second segment IS a content id
are gated (`area`, `item`, `talk`, `quest`); `object.` and `action.` cannot be, because an
object's label key is authored freely and its `object_id` is a different string, and the header
says so rather than letting a green run be read as more than it is.

| Plant | Result |
|---|---|
| delete the quest resource, keep its rows — literally T4.3's fork | five `!! ...translates quest 'keepers_errand', which exists in neither data/ nor scenes/areas/`, **exit 1** |
| restored | **exit 0** |

**The stripped CI job now prunes the CSV, and its old comment was wrong.** It said a mechanical
prune "would only be this job testing its own regex" — true while nothing could judge the result,
false now. The job runs `NEW_GAME.md`'s `awk` verbatim and rung 7 independently derives what
content exists from the tree, so the two sides come from different places: the document's list of
namespaces, and the actual `data/` directory. **T4.3's defect is now closed end to end** — if a
namespace ever goes missing from that prune list again, the stripped job goes red. Measured:
strip alone → **exit 1**; strip then prune → **exit 0**, `167 rows, of which 0 are content
namespace`.

**Why.** Seven instances of the same defect through seven green ladders is not seven mistakes, it
is one missing question. Each gate here asks it in a different place.

**Connects.** `check_boundary.gd` gained the localization half and lends `names_whole_word` to the
layer gate, so both spell "names this identifier" the same way. `check_signals.gd` deliberately
does NOT borrow it — it spells its own alphabet out, because a gate that depends on another gate
loading has a way to be silently switched off. `tests/unit/gates_test.gd` asserts the three
classifiers (33 assertions), and its last four assert that CI names every one of the six checkers
as its own step — the assertion that would have caught a gate written, committed and never wired,
which is this package's own failure mode applied to itself.

**Verified.**

```
--headless --import                                        exit 0, 0 SCRIPT ERROR / Parse Error
--headless --quit-after 30                                 0 warnings, 0 errors
--headless res://tests/test_runner.tscn --quit-after 400   === 1728 passed, 0 failed, 0 skipped ===, exit 0
tools/check_budgets.gd    exit 0   143 files, 12762 code lines, 0 violations
tools/check_content.gd    exit 0
tools/check_boundary.gd   exit 0   218 rows, 51 content namespace
tools/check_strings.gd    exit 0
tools/check_layers.gd     exit 0   88 symbols over 97 scripts, 49 exempted references
tools/check_signals.gd    exit 0   42 signals declared, 88 emit references over 40
--resolution 960x540 --quit-after 90 -- --new-game --shot=... --time=18:40 --freeze-time
                          courtyard at dusk, lit, "Read Weathered Notice" prompt on screen
```

The windowed capture is not decoration here: `player.tscn` changed, and the prompt in the frame is
the moved sensor doing its job. Gotcha 2 — headless shades nothing, so the move had to be
photographed and not merely compiled. Suite: 1,694 → 1,728 (+34): 33 from `gates_test.gd`, and one from `doc_counts_test.gd`, which counts the gotcha list and every document restating its length — gotcha 55 made that 55 in four places.

Budgets after: `check_boundary.gd` 172/250, `check_layers.gd` 140/250, `check_signals.gd` 142/250,
`gates_test.gd` 73/250. Nothing near a limit, nothing split to make a number.

**Unblocks.** Candidate B (the settings package) is next and is the largest remaining consumer
gap: **12 of 23 settings have no consumer**, five of them `accessibility/*` that a game cannot
wire without editing `src/`. The gates built here do not catch it — a setting is data read through
`DictRead`, not a declared symbol — which is worth saying plainly rather than assuming three gates
covered the class.

**Gaps, stated rather than left to be rediscovered.**
- **The consumer question is now asked of signals and of CSV rows, and of nothing else.** Settings,
  `@export` properties, enum values and public methods are all still declarable-and-dead. The
  audio director's `stop_music`/`duck`/`unduck` and `set_dof_enabled()` remain uncalled and no
  gate says so.
- **`object.` and `action.` CSV rows are reported and not gated**, because nothing derives their
  ids. A fork can still ship a demo `object.*` row for an object it deleted.
- **The layer gate scans `src/` only.** `tests/` legitimately reaches everywhere, and `.tscn`
  files reference scripts by path and are not read for direction.
- **The debug exemption is now granted twice**, by `check_boundary.gd` and by `check_layers.gd`,
  on the same precondition. Only the first of them fails if that precondition is removed.
- **No ADR was written.** Two new tools and a file moved one directory is not an architecture
  decision — the layer rule was already decided in `ARCHITECTURE.md` and ADR-0001; this package
  only made it enforceable.

## 2026-09-05 — T5.5 · The twelve settings with no consumer

**Did.** Gave nine of the twelve a real consumer, **removed the other three**, and fixed the four
one-line defects the T5.3 audit folded into this row. The result is that **every one of the
twenty remaining settings is read by something**, and a new assertion refuses a twenty-first
that is not.

**Nine wired, and where each landed was decided by who OWNS the thing that has to change:**

| Setting | Consumer | Why there and nowhere else |
|---|---|---|
| `video/resolution_scale` | `Settings._apply_render_scale` | `scaling_3d_scale` is a property of the VIEWPORT and no system owns the viewport |
| `video/shadows` | `Settings._apply_shadows` | see below — this one is the interesting placement |
| `video/bloom` | `EnvironmentDriver` | the `Environment` is that node's and nothing else may touch it |
| `video/depth_of_field` | `HD2DCameraRig._on_setting_changed` | `set_dof_enabled()`'s first ever caller |
| `gameplay/show_interact_hints` | `InteractPrompt._redraw` | a preference about the prompt, applied by the prompt |
| `accessibility/text_scale` | new `UiAccessibility` under `UILayer` | the project theme every screen draws from |
| `accessibility/high_contrast_prompts` | `InteractPrompt._apply_contrast` | the outline is a property of that Label |
| `accessibility/reduce_motion` | `DialogueScreen._on_line_changed` | the typewriter is this template's one piece of animated text |
| `accessibility/hold_to_confirm` | `InteractionSensor.hold_needed` | what an interaction costs in input is that component's business |

**`video/shadows` IS THE PLACEMENT WORTH READING, because the reasoning that put bloom in
`EnvironmentDriver` points the other way here.** Bloom is one property of one `Environment` that
one node owns. Shadows are cast by **lights an area author placed** — the courtyard has four, and
`scenes/areas/*.tscn` carry eight `shadow_enabled = true` between them — and **no node owns the set
of them.** A driver that walks the tree collecting lights would be wrong for every light added
after it was written, which is the god object ADR-0001 refuses. So it is applied at the ATLAS:
`Viewport.positional_shadow_atlas_size = 0` and
`RenderingServer.directional_shadow_atlas_set_size(0, true)`, and then **every light in the world
casts nothing, whoever placed it and whenever.** A game that adds a hundred lights gets the
setting for free and writes no code. That is the actual test of a template seam, and it is why
this belongs beside `_apply_display` rather than in a listener invented to hold it.

**And `accessibility/text_scale` is why five of the twelve were a TEMPLATE defect rather than a
missing feature of a game.** The thing that has to change for a text-size preference is the
project theme — `assets/theme/ui_theme.tres`, wired as `gui/theme/custom`, holding nine
`font_sizes` — and every screen that draws from it is under `src/ui/`. A consuming game therefore
**could not** honour that setting without editing `src/`, which is the exact failure this template
exists to prevent. `UiAccessibility` scales the theme's font sizes from a CACHED base, never from
the live value: multiplying the current size compounds and rounds on the way, so walking the row
to 1.5 and on to 2.0 would not land where going straight to 2.0 does. `Window.content_scale_factor`
is the one-line alternative and it is wrong — it magnifies the HUD's layout and the dialogue
frame's margins too, so a player who asked for bigger text gets less of the world.

**Three settings REMOVED, and this is a decision rather than a shortcut.** `gameplay/camera_shake`,
`gameplay/autosave` and `accessibility/subtitles` have no machinery in this template to reach:
there is no screen shake anywhere (`grep shake src/` returns two hits, both the setting itself),
there is no autosave and `SaveSystem` has no notion of the slot a run belongs to, and nothing is
voiced. Wiring them would have meant inventing three features inside a row about connecting
existing ones. **A row drawn to the player that cannot do anything is worse than a dead constant,
because the player is the one who finds out** — so they are gone from `DEFAULTS` and from the CSV,
which is all it takes, because `settings_screen.gd` is generated from `DEFAULTS` and needed no
edit. Each comes back in one line plus one CSV row the day its feature exists, and the reason each
was removed is written where the next reader will be standing: in the `DEFAULTS` block itself.
Screen shake and autosave are now candidate rows.

**The four folded-in fixes.**
- **`reset_to_defaults()` never called `_apply_locale()`.** One line, and a live bug: Reset wrote
  `locale = "en"` and left the UI in the old language. Invisible to every other rung, because the
  file on disk was correct — only the screen could tell.
- **`set_dof_enabled()` had no caller.** It has one, and the rig now remembers what the area author
  authored (`_authored_dof`), so the setting is the player's VETO rather than a blanket yes: a rig
  that ships with DOF off stays off however the setting moves.
- **`Actions.JUMP` is gone entirely** — the const, the Space/pad binding, the `REBINDABLE` entry
  and the `ui.action.jump` CSV row. It was drawn as a rebinding row for a verb
  `player_controller.gd`'s header says three times over this template does not have, and nothing
  polled it. `GameEnums.MoveState.JUMP` is a different symbol and stays: an enum value a game may
  drive is not an input action this one binds.
- **`KeyBindings.rebind()` now gates on `Actions.REBINDABLE`.** It gated on `InputMap.has_action`,
  so `debug_console` or `cam_zoom_in` could be overridden and written to `input.cfg` — and
  `reset_bindings()` re-declares only the four rebindable groups, so nothing put the erased default
  back and `forget_all()` was the only way out of a file the player cannot see. This spends that
  file's MUST NOT line in exactly one expression, and the header says so: the alternative was a
  second copy of the rebindable list, and two lists that drift is the defect this project keeps
  finding.

**Why. And the gate question, answered deliberately rather than by reflex.**

T5.4 added three gates that each ask *does a declared thing have a consumer?* — and its own
closing note said they do not catch this class, because a setting is a string key read through
`DictRead`, not a `class_name`, a `signal` or a CSV row. So the question had to be asked somewhere
new. **It is asked as an assertion, not a seventh checker, and the reason is what the two places
can REACH.** A `check_*` tool reads text off disk and would have to reconstruct the key list by
parsing `settings.gd`; a test has `Settings.DEFAULTS` as the engine actually loaded it. Where the
subject of a rule is available at RUNTIME, the assertion is the truer place — and T5.4's three
went to `tools/` for the mirror reason: which layer a path is in, and what a `.tscn` contains, no
running game can see. CI runs the suite as its own step, so the coverage is identical either way.
This is not "a gate would be too much work"; it is that the ladder already has six tools reading
text and this fact is not a text fact.

**WRITING THAT ASSERTION FOUND A THIRD WAY TO BE A CONSUMER THAT I HAD NOT ALLOWED FOR, AND THE
FIRST VERSION FAILED ON NINE CORRECT SETTINGS.** The obvious rule — *some file other than
`settings.gd` and `settings_screen.gd` names this key* — reported `video/vsync`, `audio/music` and
seven more as dead. Both exclusions were wrong in different directions:
- **`audio_director.gd` consumes by SECTION.** It handles `section == "audio"` and then builds each
  key as `"audio/%s" % bus_name.to_lower()`, so the five volume keys **appear nowhere as literals**
  and no scan can ever find them. Same computed-key situation as the settings screen's own row
  labels and the prompt's verb keys, and handled the way this project already handles those.
- **`settings.gd` genuinely IS the consumer for five of them**, and its header has said why since
  WP-01: nothing else owns the window, the viewport or the shadow atlas. For that file alone one
  mention is not enough — the `DEFAULTS` declaration is a mention — so two are required, and the
  second has to be an application.

`settings_screen.gd` is never a consumer, and that exclusion is the whole point: it names nine
keys in its ranges and choices and it is generated FROM `DEFAULTS`. It is the thing that made
twelve dead settings visible to the player in the first place. Counting it would make the
assertion pass on the exact state it exists to forbid. Whole-line comments are stripped in every
file, because a scan a `##` block can satisfy is a scan a stale comment can keep green.

**Connects.** Every consumer names its key as a `const` on ITSELF — `HD2DCameraRig.DOF_SETTING`,
`EnvironmentDriver.BLOOM_SETTING`, `InteractPrompt.HINTS_SETTING` / `CONTRAST_SETTING`,
`DialogueScreen.REDUCE_MOTION`, `InteractionSensor.HOLD_TO_CONFIRM`, `UiAccessibility.TEXT_SCALE`.
That is `PlayerController.PACE`'s convention applied to settings, and it is what makes the scan
decidable rather than a heuristic: a setting nobody reads then has nowhere to be written down.
Nothing was added to `Events` or `GameEnums`, no autoload was added, and `settings.gd` ends at
144 of its 150-line override — the two new appliers fit because the row also removed three keys.
`InteractionSensor.hold_needed()` is one function rather than two reads of the setting, so the
progress the prompt draws and the threshold that fires cannot disagree.

**Verified.** Every line is a measured exit code.

```
--headless --import                                        exit 0, 0 SCRIPT ERROR / Parse Error
--headless --quit-after 30                                 Session ended after 0.6s — 0 warnings, 0 errors
--headless res://tests/test_runner.tscn --quit-after 400   === 1782 passed, 0 failed, 0 skipped ===, exit 0
tools/check_budgets.gd    exit 0   146 files, 13101 code lines, 0 violations
tools/check_content.gd    exit 0
tools/check_boundary.gd   exit 0   214 rows, 51 content namespace
tools/check_strings.gd    exit 0
tools/check_layers.gd     exit 0   89 symbols over 98 scripts
tools/check_signals.gd    exit 0   42 signals declared, 88 emit references over 40
```

Suite 1,728 → 1,782. That is +64 from `settings_consumers_test.gd` and −10 from `options_test.gd`,
whose `plan()` caught the three removed settings before I did — the mechanism working exactly as
T1.3 intended.

**Two of this project's own gates caught this row's mistakes rather than its code, which is what
they are for.** `options_test.gd`'s `plan()` went `146 → 147` the moment `Actions.JUMP` came back
as a plant, and reported the three removed settings as `156 planned, 146 produced` before I had
noticed the count moved. And T5.4's `doc_counts_test.gd` failed the board with
*"WORK_PACKAGES.md spells the gotcha count — expected fifty-six, got twenty-three"*: the summary
row I wrote says both "gotcha 56" and "twelve of twenty-three settings" on one line, and a spelled
tens-number on a line mentioning gotchas is that gate's definition of a claim. Written as `12 of
23` it is a record rather than a claim, which is the convention that file's header sets out. A
number gate written two rows ago, catching prose written today, on its author.

**CI GREEN ON `31fea16`, PR #34** — all four jobs pass. Full checkout
`=== 1782 passed, 0 failed, 0 skipped ===`; **stripped template
`=== 1708 passed, 0 failed, 25 skipped ===`**, and that is the number that matters for a new test
file: T5.4 left the stripped run at 1,654, so **all 64 of this row's assertions survive the strip**
and the 10 lost from `options_test.gd` are lost there too. `settings_consumers_test.gd` derives
everything it needs from `Settings.DEFAULTS`, `ThemeDB` and the tree, and names no demo content —
which `check_boundary.gd` confirms independently: stripped, `163 rows, of which 0 are content
namespace`.

**EVERY FIX WAS PROVED BY PLANTING THE DEFECT, WATCHING IT FAIL, AND REMOVING IT.** Eight plants,
each a real reversion rather than a broken assertion:

| Plant | Result |
|---|---|
| `reset_to_defaults` loses `_apply_locale()` | `AND TranslationServer went with it — expected true, got false`; `landing on the default — expected en, got en_XA`. **1780 passed, 2 failed, exit 1** |
| the camera rig stops listening, so `set_dof_enabled` loses its caller again | `and the setting turns it off without touching the area scene — expected false, got true`. **exit 1** |
| `rebind()` gates on `InputMap.has_action` again | `so rebinding it is refused — expected false, got true` and `nothing was written for it`. **exit 1** |
| `Actions.JUMP` comes back, with its CSV row | five failures across three files, including `options_test planned 146 and produced 147`. **exit 1** |
| the hold floor is dropped from `hold_needed()` | `and needs the floor when the player asked for one — expected true, got false`. **exit 1** |
| a NEW setting is declared, translated and drawn, and nothing reads it | `something consumes 'video/planted_knob' — expected true, got false`. **exit 1** |
| an EXISTING consumer stops reading its key (`BLOOM_SETTING` retyped) | `something consumes 'video/bloom' — expected true, got false`. **exit 1** |
| `text_scale` scales from the LIVE size instead of the authored one | `lands on the same number, so it does not compound — expected 80, got 240`. **exit 1** |
| all removed | **`1782 passed, 0 failed`, exit 0** |

The last two plants are the pair that matters: the headline assertion catches a dead setting
arriving from either direction — a key added with no reader, and a reader that stops reading.

**AND THE NINTH PLANT FOUND A DEFECT IN THIS PACKAGE'S OWN WORK, WHICH IS GOTCHA 56.** Mindful of
gotcha 54, `settings_consumers_test.gd` asserted not only that `UiAccessibility` works but that the
running game instances one — the wire, not just the two ends. The first version read
`game_root.tscn` as TEXT and required the script path and `parent="UILayer"` to both appear.
**Then the node was deleted as a plant and the suite stayed green: `1782 passed, 0 failed`,
byte-identical.** A `[ext_resource]` line survives the removal of every node that used it, and
eight other nodes carry that parent, so the assertion was really checking that the file still
mentioned a script somewhere. Rewritten against `PackedScene.get_state()`, where a script is a
PROPERTY of a node and the node either exists or does not: replanted, `expected ./UILayer, got `,
exit 1. **Writing the wire assertion was not the hard part; writing one that can fail was.**

**Windowed captures, LOOKED AT — six settings, each pair differing by exactly one line in
`user://settings.cfg` and nothing else.** Gotcha 2: `--headless` shades nothing, and five of the
nine wired settings change the picture.

- **`accessibility/text_scale` 1.0 against 2.0**, settings screen open over the courtyard at dusk.
  Every font doubles at once — the title, all sixteen rows, the section headings, the hint line
  AND the HUD clock in the corner, which is a different node on a different layer. One setting,
  one shared theme, no screen edited. 20.9% of pixels differ.
- **`video/shadows` on against off**, noon. Every cast shadow in the frame is gone: the two
  characters' contact shadows, the plinth's, the lantern post's, and the walls' on the ground at
  both edges. Those come from lights authored in `courtyard.tscn`, which is the point — the atlas
  covers what no driver enumerates. 97.6% of pixels differ, worst delta 1.859.
- **`video/depth_of_field` on against off**, noon, and this one needed measuring before it could be
  photographed. The first crop I chose showed no difference at all, because the crate sits inside
  the in-focus band — `distance - near_start` is 9m. A per-block diff located the busiest 60×60
  region at (360, 0) and the zoom there is unambiguous: with DOF on the far grass and the distant
  wall edge are heavily blurred, with it off they are pin-sharp with individual pixels visible.
  21.2% of pixels differ, worst delta 0.894. **`set_dof_enabled()`'s first ever caller, seen.**
- **`video/bloom` on against off**, 21:00 so the lit surfaces matter. The glow bleeding off the
  crate's magenta faces and the wall panel is gone and the frame reads flatter and crisper.
  99.9% of pixels differ, worst delta 0.267 — a global change of small magnitude, which is what
  glow is.
- **`video/resolution_scale` 1.0 against 0.5**, noon. At 1.0 the ground texture and the character's
  edges are crisp with distinct pixels; at 0.5 the same crop is a soft upscale. 76.6% differ.
- **`gameplay/show_interact_hints` on against off** and **`accessibility/high_contrast_prompts` off
  against on**, both on the courtyard's `Read Weathered Notice`. The first removes the prompt and
  leaves the HUD clock, which is the boundary the code claims. The second is the one number in
  this package that was **chosen by photograph rather than by taste: three values were captured.**
  At 6 pixels the outline swamped the glyphs of an 18px font and the crop was HARDER to read than
  the plain prompt — the opposite of what the setting is for. At 2 it was invisible against the
  courtyard's bright grass. At 4 the halo separates the text from the ground and the letterforms
  survive. The measurement is recorded on the const.
- **The regression capture**, `--new-game --time=18:40 --freeze-time` at 960x540 with defaults:
  courtyard at dusk, both characters lit, depth-sorted and casting shadows, HUD reading
  `Day 1 | 18:40 | Dusk`, prompt on screen, `0 warnings, 0 errors`, exit 0.

**Unblocks.** A consuming game inherits nine working settings, five of them accessibility, without
editing `src/` — which was the actual defect. The `accessibility/*` set is now a worked example of
where such a setting goes: `text_scale` shows the theme seam, `hold_to_confirm` shows a floor under
an author's per-object value, `reduce_motion` shows a motion being skipped rather than slowed.
`UiAccessibility` is the home for a sixth accessibility setting a game adds.

**Gaps, stated rather than left to be rediscovered.**
- **Three settings were removed rather than wired, and each is a real feature a game will want.**
  Screen shake, autosave and subtitles are candidate rows now, and autosave is the largest of the
  three because it needs a slot policy before it needs a trigger — `SaveSystem` has no notion of
  the slot a run belongs to, and picking one is a design decision, not a wiring.
- **`accessibility/reduce_motion` has ONE consumer and there are two more motions it should own.**
  `ScreenFade` and the camera's `follow_lag` are both motion and both ignore it. One consumer is
  enough to make the setting honest; it is not enough to make the preference complete.
- **The consumer question is now asked of signals, CSV rows and settings, and of nothing else.**
  `@export` properties, enum values and public methods are all still declarable-and-dead. The
  audio director's `stop_music`/`duck`/`unduck` remain uncalled and no gate or assertion says so —
  that is candidate E, untouched.
- **`_apply_shadows` restores the atlas to 2048, which is the engine's default spelled out here
  rather than remembered from the viewport.** A game that authored a different atlas size in
  `project.godot` would have it replaced by that constant the first time a player toggles shadows.
  Reading the authored value at boot the way `HD2DCameraRig` reads `_authored_dof` would fix it and
  costs two lines this file does not have — it is at 144 of 150.
- **`hold_to_confirm` and `reduce_motion` are proved by assertion, not by photograph.** Both are
  behavioural: a hold has no still frame, and an instant reveal photographs identically to a
  finished one. The hold assertion drives the real `_current` path rather than a pure function on
  the side, which is the strongest available proof short of a scripted key press.
- **No ADR.** One node under `UILayer`, four settings applied where the thing they change already
  lives, and one input list read instead of copied. No autoload, no new layer, no new seam
  concept — `ARCHITECTURE.md` already says the owning system reacts, and this row only made that
  true for nine more settings.

## 2026-09-05 — T5.6 · A wholesale character swap, photographed

**Did.** Gave the alt placeholder sheet a complete gait set — five blocks where it had two —
pointed the player at it, drove it through idle, walk, run, sneak and climb through the real
input path, and photographed every one. **No file under `src/` changed for the swap**, which is
the claim the row exists to test, and the swap itself is two `ExtResource` paths in
`scenes/characters/player.tscn`. New `tests/unit/character_swap_test.gd` (14 assertions), a new
`src/systems/debug/dev_gait_shots.gd` that owns the shutter for a gait, and four gotchas —
three of them defects this row created and one it inherited from the capture standard.

**Why this row and not the other two.** It was Phase T5's last unmet exit criterion and the only
one of the three that is a PROOF rather than a feature. The phase claims a future game inherits
working characters and changes only assets, and until today the repository held a sheet with a
different GRID (`character_alt.png`, 4 facings, 24x40, two blocks) and a sheet with GAITS
(`character_placeholder.png`, 8 facings, 32x48, three blocks) and **never one with both** — so
the claim had been demonstrated in halves and never end to end. T5.3's own DEVLOG says this row
"would have caught T5.3's defect if it had included a climb", and that is exactly the shape of
the evidence below: `MoveState.CLIMB` was exported, validated and asserted for two rows while
being undrawable, and a swap sheet with a climb block would have photographed the absence.

**THE CONTROL IS THE STRONGEST THING IN THIS ROW, and it took one extra run.** The same probe,
the same code, the same courtyard, the same five gaits — with the DEFAULT sheet on the player
instead of the alt one:

| gait | alt sheet (96x600, 60 cells) | default sheet (256x576, 96 cells) |
|---|---|---|
| IDLE | `frame=0` -> block 0, column 0, cell 0 | `frame=24` -> block 0, column 0, cell 3 |
| WALK | `frame=21` -> block 1, column 1, cell 2 | `frame=42` -> block 1, column 2, cell 1 |
| RUN | `frame=29` -> block 2, column 1, cell 1 | `frame=82` -> block 2, column 2, cell 2 |
| SNEAK | `frame=41` -> **block 3**, column 1, cell 1 | `frame=42` -> **block 1**, the walk block |
| CLIMB | `frame=57` -> **block 4**, column 1, cell 2 | `frame=50` -> **block 1**, the walk block |

Five distinct blocks against three-with-a-fallback, from one unchanged codebase. The right-hand
column is also the first measurement anywhere of the `-1` fallback chain running in the live
game rather than in an assertion: a sheet that does not draw a sneak plays its walk block, which
is what every sheet authored before T5.2 must keep doing.

**Photographed, and the photographs are COUNTED rather than judged.** Each alt cell now carries
three pip tallies — `column + 1` down the left edge, `frame + 1` across the foot, and, new here,
`block + 1` down the right edge in white. Without the third, the block would have been the one
thing in a gait capture that had to be inferred from a tint, which is precisely the judgement
gotcha 28 says a capture cannot be trusted to make. Five zoomed captures in
`user://shots/gaits/`, each x5 nearest-neighbour, and each agrees with the decoded number: the
sneak shot is purple, crouched, **four** white pips, two yellow left pips, two foot pips —
block 3, column 1, cell 1, which is `frame=41` exactly. `courtyard_control.png` is the ordinary
dusk capture with the swap reverted, and shows the demo unchanged.

**FOUR DEFECTS, AND THREE OF THEM WERE MINE. Each was invisible in every rung that does not open
a window.**

1. **The run block bled into the cell below it.** `_plot` in the generator clips to the IMAGE and
   not to the cell, so a four-pixel overreach at a hip height of 28 put the trailing boot's last
   row at y=40 — one row into the next block's cell, drawing a stray foot above its head. The
   assertion written for it caught it on its first run: `expected [], got [8, 9]`.
2. **The foot tally could not be read in the game.** The sprite is anchored by its feet, so its
   last rows meet the ground plane and are occluded by it. The tally was correct, the sheet was
   correct, and the photograph showed one pip where the decoded frame said three. Moved from
   `y - 3` to `y - 7`. **A capture standard failing, not a drawing failing.**
3. **The number and the picture came from different frames.** `sprite.frame` was read BEFORE the
   `RenderingServer.frame_post_draw` await, so a physics step separated the measurement from the
   image — two honest readings of two different moments, which reads exactly like the sheet being
   wrong. This is the one that cost the most, because it presents as a content bug.
4. **`unproject_position` answers in the viewport's LOGICAL size.** The project scales content
   from 1920x1080, so at `--resolution 960x540` every unprojected point came back at twice its
   place in the captured image and the first five zoom crops were photographs of grass.

**Connects.** `tools/gen_placeholders.gd` -> `character_alt.png` -> `character_alt_layout.tres`
-> `CharacterVisual.layout`, and nothing between them is code this row wrote. The five blocks are
addressed by `SpriteSheetLayout.animation_for` exactly as T5.2 built it and reached by
`PlayerController` exactly as T5.3 fixed it; the alt layout is now **the only layout in the
project that leaves no gait at -1**, so it is also the only one that exercises the whole of
`_row_for` without a fallback. `dev_gait_shots.gd` is the fourth debug file and owns the one
thing the other three cannot: WHEN to open the shutter for a gait. It waits until the character
is in the gait rather than aiming at a frame number, which is gotcha 52 answered rather than
survived.

**Verified.**
- `--headless --import` -> exit 0 (run first; gotcha 53).
- `--headless --quit-after 30` -> `Session ended after 0.6s — 0 warnings, 0 errors`, exit 0.
- `--headless res://tests/test_runner.tscn` -> `=== 1798 passed, 0 failed, 0 skipped ===`,
  exit 0. 1,782 -> 1,798 — 14 from `character_swap_test.gd` and 2 that `doc_counts_test`
  derives from this row's own prose, since it counts every document line that spells the gotcha
  total and this row added four gotchas.
- **Both new gates proved by planting, and BOTH exit codes are here.**
  Plant 1, the cell bleed — hip height back to 28, regenerated, reimported:
  `=== 1794 passed, 2 failed ===`, **exit 1**, naming
  `and no cell bleeds into the one below it — expected [], got [8, 9]` and
  `the sneak block draws a lower figure than the walk block — expected true, got false`.
  Plant 2, T5.3's own defect re-created — `climb_row = -1` in the alt layout:
  `=== 1794 passed, 2 failed ===`, **exit 1**, naming
  `the alt layout names a row for every gait — expected [2, 3, 4], got [2, 3, -1]` and
  `so no alt gait falls back to the walk block — expected 5, got 4`. **That is the row's own
  claim made good: this sheet would have caught T5.3.** Control after removing both plants:
  `=== 1796 passed, 0 failed ===`, exit 0. (The plants were run before this row's documentation
  was written, so their totals are two lower than the final one — `doc_counts_test` derives two
  of its assertions from prose that did not exist yet.)
- **All six checkers exit 0** — `check_budgets`, `check_content`, `check_boundary`,
  `check_strings`, `check_layers`, `check_signals`. `check_budgets` refused
  `art_contract_test.gd` at `254 / 250` first, which is the seam it always finds: the swap
  assertions were a case of their own and are now `character_swap_test.gd`.
- **Windowed capture, which for this row is the whole point** (gotcha 2): eleven PNGs in
  `user://shots/gaits/` — five gaits as a full frame plus an x5 crop on the alt sheet, five more
  on the default sheet under `default/`, and the dusk control. `0 warnings, 0 errors` per run.
- Budgets: `gen_placeholders.gd` 141 -> 171, `art_contract_test.gd` 196 -> 190,
  `character_swap_test.gd` 79 (new), `dev_gait_shots.gd` 75 (new).

**Unblocks.** **Phase T5's third exit criterion is met, and the phase is closable at the owner's
word rather than by me** — the two remaining boxes are a second idle block and a turn in place,
and the turn is explicitly the owner's seam decision. A consuming game now has a worked example
of the swap it is promised, with both halves in one sheet, and can re-take the proof itself with
one command.

**Gaps, stated rather than left to be rediscovered.**
- **`--gait-shots` presses one direction and photographs one column.** Every capture in this row
  is column 0 or column 1. The facing quantisation is `facing_test.gd`'s subject and is asserted
  rather than photographed, which is the right division, but nothing has ever photographed all
  four alt columns in one run.
- **The swap was performed and reverted, on T2.1's precedent.** `scenes/characters/player.tscn`
  ships pointing at the default sheet, so the demo's look is unchanged and the swap lives in the
  captures and in `ART_CONTRACT.md` rather than in the tree. Pointing the keeper NPC at the alt
  sheet permanently was considered and declined: an NPC only ever passes WALK or IDLE, so it
  would demonstrate the GRID swap the shipped tree already documents and none of the gait set.
- **The two `reduce_motion` consumers T5.5 left are still missing** — `ScreenFade` and
  `HD2DCameraRig.follow_lag` — and `_apply_shadows` still restores the atlas to a `2048` const
  rather than to the authored value. **Deliberately skipped, and not because they are hard.**
  Both are candidate I and a two-line fix respectively, and neither touches a sprite sheet, a
  layout or a capture; folding them in would have put three unrelated diffs in the one row whose
  headline claim is *no file under `src/` changed*. Candidate I should take both.
- **One run in ten printed `1 errors` with no `[ERROR]` line in the captured output**, and it did
  not reproduce across four subsequent runs of the identical command. Recorded rather than
  claimed as clean: it was not chased, and it is the only unexplained thing in this row.

**CI green on `f44e71b`, PR #35** — all four jobs pass. Full checkout
`=== 1798 passed, 0 failed, 0 skipped ===`; **stripped template
`=== 1724 passed, 0 failed, 25 skipped ===`**, up from 1,708, which is the number that matters
for a new test file: `character_swap_test.gd` asserts only the base's own placeholder sheet and
names no demo content, so all 14 of its assertions survive the strip. The 25 skips are unchanged.

**Captures are not committed, on this project's standing practice** — no row in the repository's
history has ever committed a screenshot, and 5.8MB of PNG per row inside `res://` would also be
texture-imported on every fresh clone. The record is the decoded numbers quoted above plus a
permanent tool that re-takes the whole run in one command, which is strictly better than a PNG:
a committed image proves what one tree once looked like, and `--gait-shots` proves what this one
looks like now.

## 2026-09-05 — T5.7 · `reduce_motion` finished, plus the shadow atlas

**Did.** Gave `accessibility/reduce_motion` its two missing consumers, and replaced the shadow
atlas const with the size the project actually authored. Candidate I, both halves diagnosed by
T5.5, written down as gaps, and deliberately skipped by T5.6. One of them was not the defect it
had been filed as. New `src/core/state/shadow_atlas.gd` (21 code lines), new
`tests/unit/settings_effects_test.gd` (a split, forced by a budget), one new gotcha, and one
finding that belongs to the owner rather than to this row.

**The three motions.** The setting had one consumer and has three. Each names the key as a `const`
on itself — `DialogueScreen.REDUCE_MOTION`, `ScreenFade.REDUCE_MOTION`, `HD2DCameraRig.REDUCE_MOTION` —
which is the convention that makes `_is_consumed` decidable rather than a heuristic, and a new
assertion requires all three to agree with the declaration in `DEFAULTS`.

| Motion | Consumer | Effect |
|---|---|---|
| animated TEXT | `DialogueScreen._on_line_changed` | the line arrives whole (T5.5) |
| the screen FADE | `ScreenFade._on_fade_requested` | cuts, exactly as `seconds <= 0.0` already did |
| the CAMERA | `HD2DCameraRig._apply_reduce_motion` | `follow_lag` -> 0, so the camera stops sliding after a stopped character |

**THE CUT IS NOT A FASTER FADE**, and that is a decision rather than an economy: halving a duration
is still animation, and a preference that only makes motion briefer has not honoured the request.
`DialogueScreen` chose the same way for the same reason a row earlier, and its header says so.

**THE CAMERA TAKES `_authored_dof`'s VETO SHAPE, which is the half worth reading.** `_authored_lag`
is read at `_ready` before the setting is folded in, so a rig an area author shipped rigid stays
rigid however the setting moves: the setting may REMOVE smoothing an author authored and may never
ADD smoothing they refused. Assigned to `follow_lag` rather than clamped at the read site, because
a second "effective lag" variable beside the exported one is two numbers that can disagree.

**AND THE SHADOW HALF WAS A LIVE DEFECT IN THIS REPOSITORY, NOT THE PORTABILITY WORRY IT WAS FILED
AS.** T5.5 recorded it as *a game that authored a different atlas size would have it replaced the
first time a player toggles shadows.* Measured on a real display server:

```
                       boot     off      back on
with the 2048 const    2048     0        2048
with ShadowAtlas       4096     0        4096
```

The engine's default positional atlas is **4096**, and `_apply_display()` runs at `_ready` — so
this repository booted **every windowed session at half the shadow resolution the project
authored**, before a player touched anything. Two things hid it for two rows, and the second is
the transferable one. The OFF half is the half a wrong constant cannot break, and off is the only
half T5.5 photographed. And `_apply_display()` returns early when
`DisplayServer.get_name() == "headless"`, so **no rung below the windowed capture executes that
code at all** — the suite could not have caught it however many assertions were aimed at the
setting. That is **gotcha 61**.

**WHERE IT WENT, WHICH THE ROW WAS ASKED TO DECIDE.** `settings.gd` was at 144 of its 150-line
override and the fix needs STATE. So it is `ShadowAtlas`, a `RefCounted` in `core` owning one
property of the renderer and knowing nothing about `video/shadows`, and **`settings.gd` came DOWN
to 139** because two consts and four lines of body left with it. A const could not have been right
there at all: the number is a project setting a consuming game is invited to change, so the only
correct value is the one read back before the first zeroing. It is `RefCounted`, so nothing leaks
at exit.

**WHY. And what the verification found out about ITSELF.** The row was told to think about what a
still frame can prove before promising one, on T5.5's honest limit — *an instant reveal
photographs identically to a finished one.* That limit holds for the fade and **fails for the
camera**, and noticing why is the most useful thing this row produced. A fade CONVERGES. A camera
following a moving character never does: `follow_lag` sets a steady trailing distance that
persists for as long as the character keeps walking, so there is a picture to take after all.

**Connects.** `ShadowAtlas` sits beside `settings.gd` in `core/state/` and is the second thing in
this project to remember an authored value before folding a preference in; `HD2DCameraRig` is the
first, and now does it twice. `ScreenFade` gained a setting read and no listener — it reads per
request rather than caching at `_ready`, because the choice is made fresh each time the shutter is
asked for and there is nothing to un-apply. Nothing was added to `Events` or `GameEnums`, no
autoload was added, no ADR was needed, and `check_layers` is unchanged at `core -> ... -> ui`.

**Verified.** Every line is a measured exit code.

```
--headless --import                                        exit 0 (run first; gotcha 53)
--headless --quit-after 30                                 Session ended after 0.8s — 0 warnings, 0 errors
--headless res://tests/test_runner.tscn --quit-after 400   === 1821 passed, 0 failed, 0 skipped ===, exit 0
tools/check_budgets.gd    exit 0   150 files, 13417 code lines, 0 violations
tools/check_content.gd    exit 0
tools/check_boundary.gd   exit 0   214 rows, 51 content namespace
tools/check_strings.gd    exit 0
tools/check_layers.gd     exit 0   90 symbols over 100 scripts
tools/check_signals.gd    exit 0   42 signals declared, 91 emit references over 40
```

Suite 1,798 -> 1,821. `settings.gd` 144 -> 139, `hd2d_camera_rig.gd` 93 -> 102, `screen_fade.gd`
17 -> 18, `shadow_atlas.gd` 21 (new).

**EVERY NEW GATE PROVED BY PLANTING THE DEFECT, WATCHING IT FAIL, REMOVING IT AND WATCHING IT
PASS. Four plants, and BOTH exit codes are here.** Each is a real reversion rather than a broken
assertion, and all four were re-run AFTER the file split so the numbers below are the final ones.

| Plant | Result |
|---|---|
| `ScreenFade` ignores the setting again (`if seconds <= 0.0:`) | `and with reduce motion on the identical request has already landed — expected true, got false`. **1820 passed, 1 failed, exit 1** |
| the rig stops zeroing `follow_lag` (`follow_lag = _authored_lag`) | `the setting zeroes the smoothing — expected true, got false` and `and the same step now lands the camera exactly on the target, with no drift left — expected true, got false`. **1819 passed, 2 failed, exit 1** |
| `ShadowAtlas` restores a `2048` const again | **`and turning them back on restores what the project authored, not a constant — expected 4096, got 2048`** and `so this viewport gets ITS size back and not the root's — expected 1024, got 2048`. **1819 passed, 2 failed, exit 1** |
| the `ScreenFade` NODE is deleted from `game_root.tscn`, `[ext_resource]` left in place | `and the running game has a fade, under UILayer — expected ./UILayer, got `. **1820 passed, 1 failed, exit 1** |
| all removed | **`1821 passed, 0 failed`, exit 0** |

**The fourth plant is gotcha 56 re-proved on a second node, and it was written that way on
purpose.** `grep` still found `2_fade` in the file after the node was gone — the `[ext_resource]`
line outlives every node that used it — so a text search would have stayed byte-identically green.
Read through `PackedScene.get_state()`, a script is a PROPERTY of a node and the node either
exists or does not. T5.5 discovered this the hard way on `UiAccessibility`; this row assumed it
and planted to confirm the assumption, which is the cheaper order.

**Windowed captures, LOOKED AT.** Gotcha 2, and this row has one claim that a still frame CAN
carry and one it cannot.

- **The camera, `reduce_motion` off against on**, two `--gait-shots` runs at noon differing by one
  line of `user://settings.cfg` and nothing else. In the run frame the whole world is translated
  **42 px**: a brute-force offset search over a static band (rows 340-450, no HUD and no
  character) puts the residual at **0.0268 at -42 px** against **0.0975 at zero**, a 3.6x drop, so
  it is a RIGID SHIFT of the scene rather than a lighting or content difference. Every static
  landmark agrees — the pillar edge, the platform edge, the crate and the low wall move together
  while the character stays put. **This is the camera lagging behind a running character,
  photographed.**
- **The shadow atlas, on a real display server**, driven through `Settings.set_value` rather than
  through `_apply_shadows`, because the public path is the half `--headless` cannot reach:
  `4096 -> 0 -> 4096` with the fix and `2048 -> 0 -> 2048` without it. The probe was temporary and
  is not committed; the assertions are the permanent record.
- **The regression capture**, `--new-game --time=18:40 --freeze-time` at 960x540 with defaults:
  courtyard at dusk, both characters lit, depth-sorted and casting shadows, HUD reading
  `Day 1 | 18:40 | Dusk`, prompt on screen, `0 warnings, 0 errors`, exit 0. The demo is unchanged.
- **The fade is NOT photographed and the reason is recorded rather than left as an omission.** A
  cut and a finished dissolve are the same picture. What separates them is the frames between, so
  it is proved by driving `Events.screen_fade_requested` — the node's only input — inside a
  synchronous `run()`, where a tween has not advanced when the next line reads `color.a`.

**`settings_consumers_test.gd` hit 269 of its 250 and split, which is the same seam T5.6 hit on
`art_contract_test.gd`.** The split is by QUESTION rather than by size: that file asks *is this key
reached, and is its consumer wired into the running game* — a reachability question answered
against `Settings.DEFAULTS` and `SceneState`. `settings_effects_test.gd` asks *and does the effect
actually happen*, answered by driving the real path and reading the number that comes back. The two
fail differently and are worth failing separately, which is exactly the pair of defects this row
found: a key can be read by a consumer that does the wrong thing with it.

**Unblocks.** Candidate H (screen shake) has its pattern written down: `_authored_lag` beside
`_authored_dof`, and `reduce_motion` reaching the shake in the same row rather than after it. A
consuming game that authors its own shadow atlas size in `project.godot` now keeps it. And
`settings_effects_test.gd` is the home for the next setting whose EFFECT needs proving, which
`settings_consumers_test.gd` was starting to become by default.

**Gaps, stated rather than left to be rediscovered.**
- **THE OWNER LOOKED AT THE GAME MID-ROW AND FOUND SOMETHING NO EXIT CRITERION ASKS ABOUT.**
  Sideways movement "just slides to the side", and it does. `character_placeholder.png` draws ONE
  POSE EIGHT TIMES: measured, facing 4 — the back view, 180 degrees from facing 0 — differs by
  **0.5%** of a 1,536-pixel cell, and no facing differs from another by more than 4%; the walk
  cycle itself is 1.6-5.8%. **The code is correct** — `_aim` quantises the facing
  (`facing_test.gd`) and `update_from_velocity` advances the cycle (`gaits_test.gd`, T5.3) — the
  sheet has nothing different to draw. That is gotcha 54's shape one level up: the facing
  machinery is asserted at both ends and has been invisible in every capture ever taken, T5.2's,
  T5.3's and T5.6's included, and **nobody noticed until somebody played it.** Candidate J. It
  lives entirely in `tools/gen_placeholders.gd` and the two placeholder PNGs, touches no `src/`
  file and needs no art-contract change.
- **`reduce_motion` is complete for the motions that EXIST, which is not the same as complete.**
  Screen shake is candidate H and does not exist yet; when it does, the setting has to reach it in
  the same row rather than in a fourth one, or this is a gap again.
- **The fade's cut is proved by assertion and cannot be photographed**, and the first plant only
  failed ONE of the three fade assertions — with the setting ignored, the alpha happens to sit at
  the target of the following to-black request, so "in both directions" stayed green. One
  assertion is enough to fail the run, but the pair is weaker than it reads.
- **`Settings._apply_shadows` is driven directly by the suite**, because `_apply_display()` returns
  early under `--headless` and the public path from `set_value` cannot reach the atlas there at
  all. What the assertions prove is the wire from the autoload to `ShadowAtlas` and the number
  that comes back; the full public path is proved only by the windowed probe above, which is not
  committed. A permanent debug flag that sets a setting and prints the applied value would close
  that, and no row has needed one badly enough yet.
- **No ADR.** One `RefCounted` in `core`, two settings applied where the thing they change already
  lives. No autoload, no new layer, no new seam concept.

## 2026-09-05 — T5.8 · A placeholder sheet whose facings are distinguishable

**Did.** Rewrote the character half of `tools/gen_placeholders.gd` so that both placeholder sheets
draw a DIFFERENT FIGURE for every facing, regenerated both PNGs, added
`tests/unit/sheet_facings_test.gd` (8 assertions) and a `--facing-shots=<dir>` pass on the
existing capture tool, and photographed the same character walking north, east, south and west —
which nothing in this repository had ever done. Candidate J, and the only row on the board that
came from the owner playing the game rather than from an audit. **No file under `src/` changed
except the debug capture tool**, and no layout, no `.import` and no cell dimension moved.

**Why. The owner said sideways movement "just slides to the side", and it did.**
`character_placeholder.png` drew **one pose eight times**. Measured as the fraction of differing
pixels in a cell, walk block, over the figure band (four columns ignored down each edge):

| pair | before | after |
|---|---|---|
| default sheet, least alike facings | **0.0000** — facings 2 and 3 byte-identical | 0.0747 |
| default sheet, front against back | 0.0070 — the two eyes and nothing else | 0.3213 |
| default sheet, most alike facings ever got | 0.0347 | 0.4627 |
| alt sheet, least alike facings | **0.0000** — three columns differed only by the pip tally | 0.2188 |
| alt sheet, most alike facings ever got | 0.0125 | 0.4813 |

**THE CODE WAS NEVER WRONG, WHICH IS THE WHOLE POINT.** `_aim` quantises the direction into a
facing and a column, `facing_test.gd` asserts it, `art_contract_test.gd` asserts the layout's
sector maths, `update_from_velocity` advances the cycle and `gaits_test.gd` asserts that. Every
one of those was green and correct. The SHEET had nothing different to draw, so the facing system
was invisible in every capture ever taken — T5.2's, T5.3's and T5.6's included — and nobody found
out until somebody played it. **That is gotcha 62**: gotcha 54 with the unwired middle made of
pixels rather than of code, and harder to see, because no rung reads a placeholder's pixels and a
sheet that looks like people passes every glance a capture gets.

**IT IS NOT A RETRACTION OF "ART IS DEFERRED", and `ART_CONTRACT.md` was checked before starting
rather than argued with afterwards.** That document's own framing is that the placeholders exist
so every visual system can be verified rather than written blind, and it ends the placeholder
section with *"Regenerate both sheets with `tools/gen_placeholders.gd`"*. A placeholder that
cannot show a system working is not doing the job the document gives it. Nothing about the art
CONTRACT changed: same facings, same frames, same blocks, same cells, same two `.tres` files.

**Five poses and a mirror.** Front, three-quarter, side, three-quarter back, back — the torso
narrows and steps forward as the figure turns, the legs close into a front-to-back stride, the
hair wraps further round the head, the eyes go 2, 2, 1, 0, 0, a profile grows a nose past the edge
of the face and hides its far arm, and a back is drawn in its own shadow. Facings 5-7 are 1-3
**flipped**, which is what makes east differ from west by a whole asymmetric figure rather than by
which shoulder a flash sits on. The four-facing sheet gets three of the same five poses.

**AND A CELL IS NOW DRAWN INTO A CELL-SIZED IMAGE AND BLITTED**, which the mirror needed and which
pays for itself twice: `_plot`'s bounds check becomes a check against the CELL, so **gotcha 57 is
now structurally impossible rather than asserted**. `character_swap_test`'s bleed assertion is
kept — it guards anything that goes back to drawing straight into the sheet — but it can no longer
fail from this generator.

**Connects.** `tools/gen_placeholders.gd` -> both PNGs -> `SpriteSheetLayout` -> `CharacterVisual`
-> the column `_aim` picked, and nothing between them is code this row touched. `_draw_head` is
shared by both sheets because both need the same five answers from it at two sizes.
`--facing-shots` went onto `dev_gait_shots.gd` rather than into a fifth debug file: it is the same
shutter problem with the other axis substituted, and everything it needs — `SETTLE_FRAMES`,
`HOLD_FRAMES`, the post-draw await of gotcha 59, the logical-size crop of gotcha 60 — was already
there and would have been copied verbatim. What a split would have bought is a more accurate file
NAME, which is not worth four duplicated gotchas. `_shoot`, `_wait_for_player` and `_hold` are the
extraction that made the second pass six lines long.

**Verified.** Every line is a measured exit code.

```
--headless --import                                        exit 0 (run first; gotcha 53)
--headless --quit-after 30                                 Session ended after 0.7s — 0 warnings, 0 errors
--headless res://tests/test_runner.tscn --quit-after 400   === 1829 passed, 0 failed, 0 skipped ===, exit 0
tools/check_budgets.gd    exit 0   151 files, 13595 code lines, 0 violations
tools/check_content.gd    exit 0
tools/check_boundary.gd   exit 0   214 rows, 51 content namespace
tools/check_strings.gd    exit 0
tools/check_layers.gd     exit 0   90 symbols over 100 scripts
tools/check_signals.gd    exit 0   91 emit references over 40 signals
```

Suite 1,821 -> 1,829. Budgets: `gen_placeholders.gd` 171 -> **230 of 250**,
`dev_gait_shots.gd` 75 -> 109, `sheet_facings_test.gd` 82 (new).

**THE GATE PROVED BY PLANTING THE DEFECT, AND BOTH EXIT CODES ARE HERE.** The plant is the real
reversion rather than a broken assertion: `FACING_TURN` back to all zeros and `FACING_MIRROR` back
to all false in both tables, which is exactly the sheet this row replaced.

| Run | Result |
|---|---|
| planted — one pose per facing, both sheets regenerated and re-imported | `the default sheet draws its least alike pair of facings 0.0% apart, over the 5.0% floor — expected true, got false`, plus five more. **`=== 1823 passed, 6 failed ===`, exit 1** |
| plant removed, both sheets regenerated and re-imported | **`=== 1829 passed, 0 failed ===`, exit 0** |

**THE FLOOR WAS PICKED BY MEASUREMENT, NOT BY TASTE**, on T5.5's precedent for the prompt outline
width. 0.05 is above the largest difference EITHER old sheet could reach between any two facings
(0.0347) and below the smallest either new one reaches (0.0747), so it separates the two states
with margin on both sides rather than sitting wherever a guess landed.

**WINDOWED CAPTURE, WHICH FOR THIS ROW IS THE PROOF** (gotcha 2), and it is the capture T5.6
recorded as its own gap: every picture this project had ever taken was of column 0 or column 1.
`--resolution 960x540 --quit-after 600 -- --new-game --time=13:00 --freeze-time
--facing-shots=user://shots/facings`, `0 warnings, 0 errors`:

| key held | decoded | the picture |
|---|---|---|
| north | `frame=44` -> block 1, **column 4**, cell 1 | a head of hair, no face, cloth in its own shadow |
| east | `frame=58` -> block 1, **column 2**, cell 3 | right profile: one eye, a nose past the face, one arm, one leg column |
| south | `frame=48` -> block 1, **column 0**, cell 2 | square on: two eyes, both arms, both legs |
| west | `frame=38` -> block 1, **column 6**, cell 0 | the same profile mirrored |

Read together, which is the standard: the number says which cell, the picture says it reached a
screen and that the cell is a different pose. **On the sheet this replaces the four pictures would
have been indistinguishable and all four numbers would have been just as right.** The dusk
regression capture (`--time=18:40 --freeze-time`) is unchanged apart from the figures: courtyard,
both characters lit and depth-sorted and casting shadows, HUD reading `Day 1 | 18:40 | Dusk`,
prompt on screen, `0 warnings, 0 errors`.

**Gotcha 63 came out of writing this, and both halves are the same lesson.** A colour written into
an `Image` is not the colour that comes back. On the WRITE side, `FORMAT_RGBA8` quantises `0.68`
to `173/255 = 0.6784`, so the pass that repaints "every SKIN pixel" as hair matched nothing under
`is_equal_approx` and the first regeneration drew five bald heads. On the READ side, **the
imported texture is not the PNG**: `process/fix_alpha_border=true` rewrites the RGB of TRANSPARENT
pixels across the whole image, so the alt sheet's pip tallies bleed into the transparent margin of
the cell next door and the mirror assertion failed over pixels `ALPHA_CUT_DISCARD` throws away
before drawing. The fix is not a bigger margin: it is to say which pixels are VISIBLE before
saying whether they agree.

**Unblocks.** **A turn in place — candidate C, the owner's seam decision — is now worth animating.**
It was not before: turning a character that draws the same picture in all eight directions changes
nothing on screen, so the seam question would have bought a feature nobody could see. That is not
a vote for building it; the question of WHO may ask for a turn is still the owner's, and three
rows have now declined to answer it silently. It is a note that the argument against it just went
away. **Phase T5's two remaining boxes are untouched by this row** — it is about the SHEET, not
the blocks — and the phase is still closable at the owner's word.

**Gaps, stated rather than left to be rediscovered.**
- **`gen_placeholders.gd` is at 230 of its 250 and is the next file in the tree to split.** The
  seam is already visible: the two character sheets are one concern and the four flat textures
  (grid, noise, marker) are another, and the second has not changed since Phase 0. This row did
  not split it, because a split plus a rewrite in one diff makes the rewrite unreviewable — but
  the next row that adds anything to a character sheet has to.
- **The DEFAULT sheet still carries no pip tallies**, so a facing capture on it is read by POSE
  and not counted. That is deliberate — the tallies exist on the alt sheet because that sheet is
  the swap demonstration, and putting them on the sheet the demo ships would put them in every
  screenshot this project takes. It does mean the four captures above are judged in the one way
  gotcha 28 warns about, with the decoded column beside them as the check. A sheet whose facings
  are genuinely distinct makes that judgement safe in a way it was not last week, which is the
  argument, but it is an argument and not a tally.
- **Nothing asserts that the pose matches the DIRECTION.** The suite now requires the eight cells
  to be eight different pictures and requires the mirror halves to be real mirrors; it does not
  and cannot require that column 2 is a profile facing screen-RIGHT rather than left. That is a
  judgement about art, it belongs to a person looking at the four captures above, and inventing a
  pixel test for "this looks like it faces right" would be a rule with no owner.
- **The alt sheet's back column now wears a darkened tint**, which is a second thing a reader
  could confuse with the block tint. The block tally settles it exactly and
  `character_swap_test.gd` samples column 0, so no assertion moved — but a capture of column 2
  read at a glance is one shade off its block colour, and that is worth knowing before it costs
  somebody an hour.
- **Captures are not committed**, on this project's standing practice. The record is the decoded
  numbers above plus a permanent flag that re-takes the whole run in one command.

**CI green on `30c8304`, PR #37** — all four jobs pass. Full checkout
`=== 1829 passed, 0 failed, 0 skipped ===`; **stripped template
`=== 1755 passed, 0 failed, 25 skipped ===`**, which is the number that matters for a new test
file: `sheet_facings_test.gd` asserts only the base's own placeholder sheets and names no demo
content, so all 8 of its assertions survive the strip. The 25 skips are unchanged.

## 2026-09-05 — T5.9 · Screen shake, and the setting that scales it

**Did.** Built the screen shake `HD2DCameraRig` never had, brought `gameplay/camera_shake` back
to `Settings.DEFAULTS` as its scale, and made `accessibility/reduce_motion` reach it **in the same
row rather than in a fourth one**, which is the obligation T5.7 wrote down as its own gap. New
signal `Events.camera_shake_requested`, one opt-in export on `Gate`, one `--shake=` flag on
`dev_capture.gd`, 15 new assertions across the two settings test files, one new gotcha. No
autoload, no ADR, no new class, no save version.

**Why this row and not a fourth `reduce_motion` row later.** T5.5 removed `gameplay/camera_shake`
rather than fake it — there was no `shake` identifier anywhere under `src/`, so honouring the key
would have meant inventing a feature inside a row about connecting existing ones. T5.7 then
finished `reduce_motion` for the three motions that EXISTED and said plainly that this was not the
same as finished: *when a shake exists, the setting has to reach it in the same row, or this is a
gap again.* Both halves are here, and **this is the first of the three settings 2.0.0 removed to
come back with the feature it was waiting for** — which is the whole argument for removing them
instead of leaving inert rows on the options screen.

**Where the shake went, and why nothing new was built to hold it.** On `HD2DCameraRig`, which
already owns placement and smoothing and now owns three preferences. It went from 102 to 138 of
its 250, so the `ShadowAtlas` question T5.7 had to answer — *where does this live when the file is
full* — did not arise. A `CameraShake` `RefCounted` was considered and refused: the offset is
applied to a camera this node already places, in a function this node already calls every physics
frame, and a class to hold four floats would have been a seam invented to look like T5.7's.

| Piece | Where | Note |
|---|---|---|
| the motion | `HD2DCameraRig._offset_by_shake` | a decaying sine along the camera's OWN axes, after `look_at` |
| the ask | `Events.camera_shake_requested(strength, seconds)` | `_requested`, many askers by design |
| the asker | `Gate.perform` when `open_shake > 0.0` | **defaults to 0.0**, so nothing shakes until an author says so |
| the author's number | `shake_metres` on the rig | 0.35 m at full strength |
| the player's veto | `gameplay/camera_shake`, 0..1 | folded INTO `shake_metres`, never kept beside it |
| the accessibility veto | `accessibility/reduce_motion` | **removes it outright**, does not scale it |

**THE PATTERN WAS COPIED AND NOT REINVENTED**, which the row was told to do. `_authored_shake` is
read at `_ready` beside `_authored_dof` and `_authored_lag` — the third authored value this one
node remembers — and the scale is assigned into `shake_metres` rather than clamped at the read
site, on T5.7's exact reasoning: a second "effective amplitude" variable beside the exported one
is two numbers that can disagree. So **a rig an area author shipped at `shake_metres = 0.0` never
shakes, whoever asks and whatever the player prefers**, and the setting can only ever take motion
away. `SHAKE_SETTING` is a `const` on the consumer, which is what keeps
`settings_consumers_test._is_consumed` decidable rather than heuristic.

**AND `reduce_motion` CUTS RATHER THAN SCALES**, which is a decision and the third time this
project has made it. `DialogueScreen` refused a faster typewriter and `ScreenFade` refused a
shorter dissolve for the same reason: a preference that only makes motion smaller has not honoured
the request. A quieter shake is still a shake.

**WHO MAY ASK — the seam question this row was told to decide and record.** The ask is on the bus,
with the `_requested` suffix and many askers by design, exactly as `notify_requested` is: the
thing that just happened knows how hard it hit and knows nothing about a camera, and the rig knows
how far it may move and nothing about gates. The template's own asker is **`Gate`**, because a
heavy leaf grinding open is the one impact a game with no combat actually has, and because it is
AUTHORED rather than decided in code — `open_shake` is per gate and defaults to silent, so a
garden gate and a portcullis are the same class with different numbers. The demo courtyard's
`NorthGate` sets `0.7`, in a `.tscn` and not under `src/`. `check_signals.gd` is satisfied by a
real emitter rather than by a test one.

**A DECAYING SINE, NOT NOISE, AND THAT IS THE REASON THIS ROW COULD BE PHOTOGRAPHED AT ALL.**
Random jitter is what most engines reach for and it cannot be verified: two runs of a random shake
differ, so no assertion can say the camera moved by the right amount and no two captures can be
compared. A sine is periodic and reproducible, which is what made "exactly half as far" an
assertable claim in the suite AND a measurable one in a photograph.

**Connects.** `Gate.perform` -> `Events.camera_shake_requested` -> `HD2DCameraRig.shake` ->
`_offset_by_shake` inside the `_place` this rig already ran every physics frame. Nothing holds a
reference to the camera to knock it, which is why the ask is on the bus and not a method somebody
has to find the rig to call — and an area whose scene has no rig simply has no listener, which is
correct rather than broken. The offset is applied AFTER `look_at`, along the camera's own basis,
so it is a screen-space slide that leaves the aim alone; displacing the focus point instead would
swing the whole world and read as a lurch. `dev_capture.gd` gained `--shake=`, which emits the
same signal a gate emits and touches no camera itself, so what it photographs is the feature.

**Verified.** Every line is a measured exit code.

```
--headless --import                                        exit 0 (run first; gotcha 53)
--headless --quit-after 30                                 Session ended after 0.8s — 0 warnings, 0 errors
--headless res://tests/test_runner.tscn --quit-after 400   === 1848 passed, 0 failed, 0 skipped ===, exit 0
tools/check_budgets.gd    exit 0   151 files, 13728 code lines, 0 violations
tools/check_content.gd    exit 0
tools/check_boundary.gd   exit 0   215 rows, 51 content namespace
tools/check_strings.gd    exit 0
tools/check_layers.gd     exit 0   90 symbols over 100 scripts
tools/check_signals.gd    exit 0   43 signals declared, 93 emit references over 41
```

Suite 1,829 -> 1,848. `hd2d_camera_rig.gd` 102 -> 138, `settings.gd` 139 -> 140, `gate.gd`
52 -> 56, `dev_capture.gd` 106 -> 122, `events.gd` 44 -> 45, `settings_effects_test.gd`
92 -> 161, `settings_consumers_test.gd` 182 -> 188.

**PROVED BY PLANTING THE REVERSION, WATCHING IT FAIL, REMOVING IT AND WATCHING IT PASS. BOTH exit
codes for both plants.** Each is a real reversion of this row's own work rather than a broken
assertion.

| Plant | Result |
|---|---|
| `_apply_shake_scale` ignores both settings (`shake_metres = _authored_shake`) — the state before this row | `halving the setting halves the amplitude`, `and the identical request moves the camera exactly half as far…`, `reduce motion removes the shake outright…`, `so the same request moves the camera not at all`. **1844 passed, 4 failed, exit 1** |
| the rig stops connecting to `Events.camera_shake_requested` — the wire, with both ends left intact | `and a rig in the tree is listening for a shake request — expected true, got false`. **1847 passed, 1 failed, exit 1** |
| both removed | **1848 passed, 0 failed, exit 0** |

**The second plant is gotcha 54 aimed at deliberately.** With the `connect` line gone, `Gate` still
emits, the rig still has a working `shake()`, `check_signals.gd` still passes and every
amplitude assertion in `settings_effects_test.gd` stays green — because they all call `shake()`
directly. Only the connection assertion notices, and it exists for exactly that reason.

**WINDOWED CAPTURES, LOOKED AT, AND THIS ROW GOT MORE OUT OF A STILL FRAME THAN IT EXPECTED TO.**
Gotcha 2 and gotcha 61: `_apply_display()` returns early under `--headless`, and `--headless`
shades nothing, so a picture is the only place some of this is visible at all. The row was told to
think about what a still frame can prove before promising one. **A shake is periodic, so one frame
of it is a DISPLACEMENT**, and T5.7's brute-force offset search measures it against a control.

Five runs of one command at `--resolution 960x540 --shot-frame=70 --time=13:00 --freeze-time
--shake=1.0`, differing only by `user://settings.cfg`, each `0 warnings, 0 errors`. The camera's
world position now goes in the capture log beside the picture, on this project's standing rule
that a number and a photograph are read together:

| run | camera x | best rigid offset vs the control | residual there | residual at zero |
|---|---|---|---|---|
| no `--shake` at all (the control) | **0.000000** | — | — | — |
| `camera_shake = 1.0` | **0.302357** | **(+14, −12) px** | **0.0173** | 0.0513 |
| `camera_shake = 0.5` | **0.151178** | **(+8, −6) px** | **0.0125** | 0.0402 |
| `camera_shake = 0.0` | **0.000000** | (0, 0) | 0.0004 | 0.0004 |
| `reduce_motion = true` | **0.000000** | (0, 0) | 0.0001 | 0.0001 |

**0.151178 is 0.302357 halved to six figures, and the PICTURES halve too** — (+8, −6) against
(+14, −12). The setting is a scale on a real display server, in the running game, through the
signal a gate emits, and not only in an assertion. The two zero rows are the controls that make
the other two mean something: with the setting at zero and with `reduce_motion` on, the frame is
the control frame to within 0.0004 and 0.0001 — **a shake was requested and the picture did not
move at all.**

**Looked at, not merely measured**: the whole world — the pillar, the platform edge, the low wall,
the crate, both characters — is displaced up and to the right against the control, **while the HUD
`Day 1 | 13:00 | Midday` and the prompt `Read Weathered Notice` sit at identical pixels.** That is
the difference between a camera shake and a screen shake, and it is the half no number in the log
could have told me. The dusk regression capture (`--time=18:40 --freeze-time`) is unchanged:
courtyard at dusk, both characters lit, depth-sorted and casting shadows, HUD reading
`Day 1 | 18:40 | Dusk`, prompt on screen, camera at rest, `0 warnings, 0 errors`.

**Gotcha 64 came out of reconciling those two columns**, and it is the one thing here that will
cost the next person an hour. The focal-plane maths says 0.302 m at 14 m through a 27-degree lens
should move the image about **24 px**; the best rigid fit says **14**. Neither is wrong. A camera
TRANSLATION parallaxes — near geometry shifts further than far — so no single offset fits the
whole frame and a least-residual search returns a depth-weighted average. The claim the search
carries is the RATIO (0.0513 -> 0.0173, a 3.0x fall) plus a control at the same offset, not the
pixel count. The metres in the log are the measurement.

**WHICH HALF IS PROVED BY WHICH, stated rather than left as an omission**, because T5.5 and T5.7
both had to. Proved by ASSERTION: that the amplitude is the author's and the scale is the
player's, that `reduce_motion` zeroes it, that a rig authored still stays still, that a shake
decays to nothing by itself, that a zero-strength request is refused, and that a rig in the tree
is subscribed to the bus. Proved by PHOTOGRAPH: that any of it reaches a screen at all, that the
displacement is of the WORLD and not the UI, and that the scale is linear in the picture and not
only in the number. Neither set can stand alone and both are here.

**Unblocks.** Nothing was left half-applied by this row, which is the point of it: there is no
fourth `reduce_motion` package to write, and `accessibility/reduce_motion` now reaches every
motion this template draws — the typewriter, the fade, the camera's follow lag and the shake.
`Events.camera_shake_requested` is the hook a consuming game's own impacts emit on, with no code
under `src/` to change. Two of 2.0.0's three removed settings are still out: `gameplay/autosave`
is candidate G and still needs a slot POLICY before it needs a trigger, and
`accessibility/subtitles` still has nothing voiced to caption.

**Gaps, stated rather than left to be rediscovered.**
- **NOTHING SHAKES IN THE DEMO WITHOUT WALKING TO THE GATE.** The only asker under `src/` is
  `Gate`, and the demo's north gate needs the lever thrown and the rose key carried, so the shake
  is not on the path a boot capture takes. That is why `--shake=` exists on `dev_capture.gd` and
  why the pictures above were taken with it. The FLAG emits the real signal, so what it
  photographs is the real feature — but the GATE's own emit is proved by reading the four lines
  in `perform()` and by `check_signals.gd`, not by a capture of a gate opening. A probe that
  unlocks the gate, hands over the key and photographs the frame after would close it, and it is
  a `dev_probes.gd` row rather than part of this one.
- **`shake_hz` is not asserted, only the amplitude is.** Every assertion here fires a fresh
  request and takes exactly one step, so all of them measure the same instant of the wave — which
  is what makes them comparable, and also means a frequency changed to 3 Hz would keep every one
  of them green. The photographs would notice; nothing automated would.
- **The demo's `open_shake = 0.7` is a taste judgement.** 0.7 of 0.35 m reads as a heavy stone
  leaf at this framing to one person looking at one capture. It is authored data in a `.tscn`, so
  changing it costs nothing and no assertion depends on it.
- **A second shake landing on a first REPLACES it rather than summing.** That is deliberate —
  summing lets anything repeatable drive the camera arbitrarily far off the world — but it means
  two impacts a frame apart read as one, and a game that wants layered rumble will want an
  additive path. It is four lines in `shake()` and no seam moves.
- **No ADR.** One signal, one method and two exports on a node that already owned the camera. No
  autoload, no new layer, no new seam concept.

## 2026-09-05 — T5.10 · Autosave, and the slot policy it needed first

**Did.** Gave the base an autosave, brought `gameplay/autosave` back to `Settings.DEFAULTS` as the
player's veto over it, and answered the design question this row was actually about — **the SLOT,
not the trigger.** New `Autosave` node under `GameRoot`, one new slot on `SaveSystem`, two new
consts, one new public method, five new CSV rows, 50 new assertions across three test files, one
new gotcha. No new signal, no autoload, no ADR, **and no save-format change** — `SCHEMA_VERSION`
is still 1 and slots 0..5 still mean exactly what they meant, which is what makes this 2.5.0 and
not 3.0.0.

**Why this row.** T5.5 removed three settings rather than fake them, and said plainly why each:
there was no shake, there was no autosave and `SaveSystem` had no notion of the slot a run belongs
to, and nothing is voiced. T5.9 brought the first one back **with** its feature, which was the
whole argument for removing them instead of leaving inert rows on the options screen. This is the
second and the larger of the two that were left. Only `accessibility/subtitles` is still out, and
it still has nothing to caption.

**THE SLOT WAS THE QUESTION, AND THE ANSWER IS A DEDICATED ONE PAST THE MANUAL SIX.**
`SaveSystem.AUTOSAVE_SLOT` is `MAX_SLOTS`, written to `user://saves/autosave.json` — a name rather
than a number, because `slot_07.json` beside six `slot_NN.json` files reads as a seventh manual
slot to anyone who opens the folder, which is what it is not. Two alternatives were considered and
both are worse:

| Candidate | Why not |
|---|---|
| rotate through the manual slots | an autosave can then destroy a save the player made on purpose, which is the one thing an autosave must never do |
| reserve slot 5 of the six | same objection, **plus** it changes what slot 5 MEANS in every save file already on disk — a MAJOR bump, paid for nothing |
| **one past the six** | no manual list can reach it, because every manual list iterates `MAX_SLOTS` and simply never counts that high. No filter to remember, no existing save touched |

**AND THE READ RANGE IS DELIBERATELY NOT THE WRITE RANGE.** `latest_slot()` now iterates
`AUTOSAVE_SLOT + 1` and the save screen's writing half still iterates `MAX_SLOTS`. That asymmetry
IS the policy: **writing is manual-only, reading is everything.** An autosave the player cannot
come back to is not an autosave, so Continue resumes it and the load list offers it as a row of its
own — while the save list, built over the identical files, cannot name it. Both halves are asserted
against the same on-disk state in `menus_test.gd`, so the only thing that can produce different
lists is the direction each faces.

**WHERE THE POLICY LIVES, AND THE ONE JOB `SaveSystem` DID NOT GET.** `Autosave` is a node under
`GameRoot`, in `src/systems/autosave/`. It is not in `SaveSystem`, whose header has said since
WP-01 that it knows nothing about game content — "not while the world is mid-transition" is a fact
about the running game, and putting it there would be the second job that file explicitly refuses.
It is not an autoload either, because an autoload needs an ADR and this is a node with two
connections and one decision, which is exactly what `UiAccessibility` is and where T5.5 put that.
And **it is not in `game_root.gd`**, which is the part worth reading: that file carried a comment
since WP-00 saying *"Autosave on quit goes here once there is a save slot policy"*, and `events.gd`
says on `quit_requested` that an autosave policy will only ever need adding in one place. Both
turned out to be true in a better way than they meant — `Autosave` listens for `game_ending` like
any other participant, so the policy needed adding in **no** place under that roof, and
`game_root.gd` still does only the four things its header allows. The comment is gone.

**THREE REFUSALS, EACH A REAL FAILURE MODE.** The player's veto (`gameplay/autosave`, which can
only ever take an occasion away and never add one); a transition in flight; and no run in
progress — that last one because quitting from the main menu on a cold boot would otherwise write
an autosave of nothing over the autosave of a real run, which is the same destruction the slot
policy exists to prevent.

**GOTCHA 65 CAME OUT OF THE TRANSITION GUARD, AND IT IS THE THING IN THIS ROW THAT WILL COST THE
NEXT PERSON AN HOUR.** `SYSTEMS_INVENTORY.md` item 6 has asked since WP-00 for "never autosaving
during a transition", and `Director.is_transitioning()` is obviously the guard. But
`_run_transition` emits `area_entered` and clears `_transitioning` **two statements later** — which
is correct, because that signal's contract is "the area is in the tree and the player is placed"
and the transition is not formally over until the curtain has been asked to lift. So a handler that
read the guard on the spot would have been refused on **every single arrival**, and the feature
would never have fired once. Nothing would have been red: no error, no warning, both ends of the
wire correct, the guard behaving exactly as specified, and a feature that does nothing. That is
gotcha 54's family with the unwired middle made of **ordering**. The fix is one
`await get_tree().process_frame` before the guard, and the assertion that pins it emits
`area_entered` inside a synchronous `run()` — where no frame ever comes — and requires that
**nothing was written**.

**Connects.** `Events.game_ending` (GameRoot, one statement before `quit()`, so the window's close
button is covered by the same path) and `Events.area_entered` (Director) -> `Autosave.request()`
-> `SaveSystem.save_to_slot(AUTOSAVE_SLOT)` -> `Events.notify_requested` -> the toast that already
existed. Nothing was added to `Events`, and that is the point: both occasions are facts already on
the bus, and `notify_requested` is the indicator item 6 asks for, already built. `AUTOSAVE_SETTING`
is a `const` on the consumer, which is what keeps `settings_consumers_test._is_consumed` decidable
rather than heuristic. `request()` is public so a consuming game's own occasion — a chapter break,
a bed slept in — is one call and no edit to `src/`.

**Verified.** Every line is a measured exit code.

```
--headless --import                                        exit 0 (run first; gotcha 53)
--headless --quit-after 30                                 Session ended after 0.6s — 0 warnings, 0 errors
--headless res://tests/test_runner.tscn --quit-after 400   === 1898 passed, 0 failed, 0 skipped ===, exit 0
tools/check_budgets.gd    exit 0   152 files, 13884 code lines, 0 violations
tools/check_content.gd    exit 0
tools/check_boundary.gd   exit 0
tools/check_strings.gd    exit 0
tools/check_layers.gd     exit 0   91 symbols over 101 scripts
tools/check_signals.gd    exit 0
```

Suite 1,848 -> 1,898. `save_system.gd` 160 -> 172 of its 180, `save_screen.gd` 57 -> 68,
`settings.gd` 140 -> 141, `autosave.gd` is new, and `game_root.gd` stayed at 26 of its 60 because
nothing was added to it.

**THE LAYER GATE CAUGHT THIS ROW'S OWN PROSE, ON ITS AUTHOR, MINUTES AFTER IT WAS WRITTEN.**
`check_layers.gd` failed with *"res://src/core/state/settings.gd:58 (core) names Autosave, which is
systems"* — and line 58 was a **trailing comment** on the new `DEFAULTS` row reading
`# a veto on Autosave's own occasions`. Whole-line `##` comments are stripped by that tool and
trailing ones are not, which is the same decision `settings_consumers_test._code_only` documents
for the mirror reason: removing a trailing comment would mean deciding whether the `#` sits inside
a string literal. The gate is right either way — a `core` file should not be teaching its reader to
reach for a `systems` class by name — and the fix was to say "the policy" instead. A gate written
two phases ago, reading a comment written today.

**PROVED BY PLANTING THE REVERSION, WATCHING IT FAIL, REMOVING IT AND WATCHING IT PASS. BOTH exit
codes for all four plants.** Each is a real reversion of this row's own work, not a broken
assertion.

| Plant | Result |
|---|---|
| the area handler calls `request()` synchronously — the shape gotcha 65 is about | `and an arrival does not write inside the emit, because the transition is not over yet — expected false, got true`. **1897 passed, 1 failed, exit 1** |
| `AUTOSAVE_SLOT = MAX_SLOTS - 1` — the autosave reserves a manual slot, the design this row rejected | `the autosave slot is outside the manual range`, `manual slot 5 is not the autosave`, `no slot the save screen offers lands on that same file`, `the autosave is now pressable, not a note — expected 2, got 3`. **1893 passed, 5 failed, exit 1** |
| `latest_slot()` iterates `MAX_SLOTS` again — Continue cannot see the autosave | `and Continue sees it, because an autosave nobody can come back to is not one — expected 6, got -1`. **1897 passed, 1 failed, exit 1** |
| the transition guard is deleted from `request()` | `and mid-transition it refuses — expected 45, got 0`, `so a world that exists in neither area is never written`, `with nothing on disk to show for it`. **1895 passed, 3 failed, exit 1** |
| all four removed | **1898 passed, 0 failed, exit 0** |

**A SAVE IS A FILE, SO MOST OF THIS ROW IS GENUINELY PROVABLE IN THE SUITE — which T5.7's and
T5.9's camera work was not, and saying so plainly beats promising a photograph that adds nothing.**
There is a real artefact on disk to assert against rather than a picture to be looked at. The
strongest assertion here is the policy's own promise, driven end to end: write an autosave, then
write into **all six** slots the save screen offers, and the autosave file is still present and its
header still `equal` to the Dictionary read before — the same save, unmoved. The three refusals are
each proved by the **absence of a file** as well as by the return code, because a policy that
returned `ERR_SKIP` and wrote anyway would pass half of it, and that pair of ways to be wrong is
exactly what T5.7 found.

**WHAT THE CAPTURE CARRIES IS THE INDICATOR, WHICH IS THE HALF NO ASSERTION CAN SHOW.** The row was
told to think about what a still frame can prove before promising one, and the answer here is not
"nothing": `SYSTEMS_INVENTORY.md` item 6 asks for an autosave INDICATOR, and an indicator is by
definition a thing the player is shown. Two windowed runs of the standing regression command
(`--resolution 960x540 --new-game --shot-frame=70 --time=18:40 --freeze-time`), differing only by
one line in `user://settings.cfg`, each `0 warnings, 0 errors`:

| run | log | `user://saves/` afterwards | the frame |
|---|---|---|---|
| defaults | `[save] Slot 6 written (6 sections)` | **`autosave.json`** | **`Autosaved.` on the toast**, HUD `Day 1 \| 18:40 \| Dusk`, prompt `Read Weathered Notice` |
| `autosave=false` | nothing | **empty** | identical frame, **no toast** |

**The saves directory is the decisive column and the photograph is the one that matters**, and they
are read together on this project's standing rule. Looked at rather than only measured: the world,
the HUD clock and the interaction prompt sit at identical pixels between the two, and the only
thing that differs is one line of white text at the top of the frame — the autosave happening in
the real running game, through the real signal, on arrival in the first area of a new run, with the
player's veto measured on disk rather than in an assertion. Measured for the record, the toast band
`y[16..36]` differs at **1.266%** against a floor of **0.401%** and **0.286%** in two world bands of
the same pair; the pixel count is corroboration and the file on disk is the measurement, which is
gotcha 64's discipline applied to a different kind of picture.

**THE STANDING REGRESSION CAPTURE NOW CARRIES A TOAST**, and that is a deliberate change to a
reference image this project has taken at every phase since WP-05. `--new-game` enters an area,
which is an autosave occasion, so the dusk frame at `--shot-frame=70` has `Autosaved.` on it. That
is the feature working rather than a regression, and it is written down here so the next person
comparing against an older capture does not spend an hour on it.

**Unblocks.** A consuming game inherits an autosave with a slot policy it does not have to design,
and adds its own occasions with one call to `request()` and no edit under `src/`. `SaveSystem` now
has the notion of a slot a run belongs to that T5.5 said it lacked, so anything else that wants to
save without the player asking has somewhere to put it. Two of the three settings 2.0.0 removed
have come back with their features, so the argument for removing them rather than shipping inert
rows is now made twice.

**Gaps, stated rather than left to be rediscovered.**
- **THE AUTOSAVE IS WRITTEN AND NEVER SHOWN TO BE LOADED IN A CAPTURE.** `load_from_slot` is the
  same call the load list already makes for any slot, and the load list's autosave row is asserted,
  but no probe boots, autosaves, quits, relaunches and continues into it. That is a `dev_probes.gd`
  row — the same shape as T5.9's gate-opening gap — and it is the only claim in this row that rests
  on "it is the same code path" rather than on a measurement.
- **The quit-path toast is emitted and never seen.** One code path with one honest note beat a
  branch that exists only to suppress a label nobody can read, but it does mean the `game_ending`
  occasion is proved by assertion and by the log line and never by a photograph. A capture of it
  would be a photograph of a closing window.
- **Two occasions is a judgement, not a derivation.** Quit and area arrival are the two this
  template can see; a game with chapters, beds or checkpoints will want more, and `request()` is
  public precisely so it needs no edit here. Nothing asserts that these two are the RIGHT two,
  because nothing could.
- **There is no "are you sure" on quitting with unsaved progress**, which is `SYSTEMS_INVENTORY.md`
  item 7 and is now half-obsolete: with the autosave on by default there is less unsaved progress
  to warn about, and with it off there is exactly as much as before. Item 7's other half — the
  overwrite confirmation on a manual save — is untouched.
- **A second autosave landing while the first is in flight is refused by `_busy`, not queued.** That
  is `save_to_slot`'s existing behaviour and it is correct for the two occasions here, which are a
  frame or a session apart; a game that autosaves on a fast-firing occasion would see refusals in
  the log rather than saves, and the log line says so.
- **No ADR.** One node, two connections, one decision, and a slot number on the file that already
  owns slot numbers. No autoload, no new signal, no new layer, no new seam concept.

**CI GREEN ON `0e99c86`, PR #39** — both jobs pass. Full checkout
`=== 1898 passed, 0 failed, 0 skipped ===`; **stripped template
`=== 1824 passed, 0 failed, 25 skipped ===`**, and that is the number that matters here: T5.9 left
the stripped run at 1,774, so **all 50 of this row's assertions survive the demo strip**. Nothing
added by this package names demo content — the autosave assertions stand a run up with
`&"fixture_area"`, because the policy asks whether a run EXISTS and never which area it is in, and
`check_boundary.gd` confirms that independently.

## 2026-09-05 — T5.11 · Music ducking, built — and the alias beside it deleted

**Did.** Gave `AudioDirector.duck()` and `unduck()` the consumer they never had, fixed what they
did when called, and **deleted `stop_music()`**, which is why this is 3.0.0 and not 2.6.0. New
`DialogueDuck` node under `GameRoot`, one new public method and four new consts on the mixer, one
helper moved into `TestCase`, 37 new assertions in a new case, one new gotcha. **No new signal, no
new setting, no autoload, no ADR, and no CSV row** — this row added nothing a player can see on the
options screen and nothing a translator has to translate.

**THE ROW WAS "BUILD IT OR DELETE IT", AND THE ANSWER IS BOTH, SPLIT ON A CLEAN LINE.** T5.5 faced
the same choice about twelve settings and removed three of them, with a reason each time: there was
nothing for `true` to mean. The line that decided this row is the same one:

| Method | Verdict | Why |
|---|---|---|
| `duck()` / `unduck()` | **built** | The occasion already existed. `Events.dialogue_started` and `dialogue_finished` have been on the bus since Phase 0 with one emitter each, and lowering music under dialogue is what ducking IS. Wiring it cost one node and no new signal — the same shape T5.10 used for the autosave |
| `stop_music()` | **deleted** | Two lines of alias over `play_music(null, fade)`, with no caller in three phases and no occasion in this template that `play_music(null)` does not already serve — `area_root.gd` takes exactly that path whenever an area has no music, so the surviving spelling is the tested one. Two ways to say one thing in a file with a hard 150-line budget is a cost with nothing on the other side of it |

Deleting a public method is a MAJOR bump, and it is worth saying that the bump was NOT a reason to
keep it. A version number is free; the `CHANGELOG` entry names the replacement, the fix at a call
site is one line, and this repository has taken a MAJOR for an honest removal before (2.0.0, three
settings).

**AND THE FEATURE WAS NOT MERELY UNCALLED — IT WAS WRONG, WHICH ONLY WIRING IT COULD REVEAL.**
`duck()` tweened the buses to an **absolute** −8 dB. That is not a duck; it is "set the music to
−8 dB". `audio/music` defaults to 0.8, which is −1.9 dB, so at the default it ducked by six. Against
a player who had moved that slider to 0.25 — −12 dB — **the same call made the music four decibels
LOUDER every time somebody spoke.** One method, opposite effects, chosen by a slider on the options
screen. So `target_db(bus)` is now the file's answer to "where should this bus be right now": the
level the player's own setting puts it at, plus whatever duck is in force, and a bus the player
muted stays muted because nothing here may raise a level set to zero. This is the eighth instance
of declared-and-dead teaching the same lesson from a new angle: **code with no consumer is not
merely unused, it is unverified**, and three phases of green ladders had no opinion about it.

**THREE MORE THINGS THE WIRING FOUND, EACH SMALL AND EACH REAL.**
- **A settings change lifted the duck.** `_apply_all_volumes` re-applies every bus on any `audio/*`
  change, so a slider moved mid-conversation put the music straight back to full. It goes through
  `target_db` now; `_duck_db` is held as STATE and not only as a tween target for exactly this.
- **Two ducks raced.** Each call created a fresh tween and never cancelled the last, so a
  duck immediately followed by an unduck resolved to whichever finished later. `_move_buses` kills
  the previous fades first.
- **A positive "duck" would have worked.** It is clamped at zero: no caller gets to make the music
  louder than the player asked through a door named `duck`.

**THE COUNT IS THE DESIGN DECISION, AND IT IS WHY THIS IS A NODE AND NOT A `connect` LINE IN THE
MIXER.** The brief warned that a `duck()` one caller uses and an `unduck()` nobody balances is worse
than either, and the way that happens is not carelessness — it is two conversations overlapping. An
NPC talking to another NPC while the player reads a sign emits `dialogue_started` twice and
`dialogue_finished` twice, and a plain pair lifts the music on the FIRST ending, underneath a
conversation still running. Nothing would be red: both handlers correct, both signals correct,
music back at full volume over dialogue. So `DialogueDuck` counts, ducks on the first hold and
releases after the last, floors the count at zero so a stray end cannot strand the music down, and
publishes `held()` so the balance is assertable as a COUNT and not only as a decibel.

**WHERE IT LIVES, AND THE JOB `AudioDirector` DID NOT GET.** `DialogueDuck` is a node under
`GameRoot`, in `src/systems/audio/`. It is not a second `connect` inside `audio_director.gd`, on
T5.10's reasoning exactly: `SaveSystem` owns the save format and `Autosave` owns the occasion to
write one; the mixer owns how far down a duck goes and this owns what makes it happen. That seam is
what lets a consuming game delete ONE NODE from `game_root.tscn` to have no ducking under dialogue,
or add a node beside it for a cutscene, with no edit under `src/`. It is not an autoload — that
needs an ADR, and this is a node with two connections and one decision, which is what
`UiAccessibility` and `Autosave` already are.

**NO NEW SETTING, DELIBERATELY, AND THE ROW WAS TOLD TO CHECK BEFORE ADDING ONE.** T5.9's
`gameplay/camera_shake` and T5.10's `gameplay/autosave` were both settings version 2.0.0 had
REMOVED and owed a return; nothing is owed here. A duck is a mix decision rather than a comfort
hazard — `accessibility/reduce_motion` is about motion and there is none — and the player already
owns the outcome twice over, through `audio/music` and `audio/ambience`, both of which the duck is
now measured FROM rather than against. Inventing `audio/dialogue_duck` would have put a row on the
options screen that nobody asked for, in two languages, to switch off eight decibels.

**GOTCHA 66 IS HOW A FADE IS PROVED IN A SYNCHRONOUS TEST, AND IT RETIRES AN "HONEST LIMIT" T5.7
WROTE DOWN.** `run()` is synchronous, no idle frame ever arrives, and a tween left alone never
moves — so a finished fade and an instant cut read identically, and T5.7 recorded that as something
assertions simply could not reach. They can: `SceneTree.get_processed_tweens()` hands back the
tweens and `Tween.custom_step(delta)` advances one by hand. Snapshot the list BEFORE the call under
test and step only what is new, so the case moves nothing it does not own. That turns three claims
into measurements — the bus has NOT moved yet, half the fade is half the drop, and the whole fade
lands exactly on target — and plant 2 below is a duck rewritten as a cut, which fails all three.

**Connects.** `Events.dialogue_started` / `dialogue_finished` (DialogueRunner, one emitter each) ->
`DialogueDuck` -> `Audio.duck()` / `Audio.unduck()` -> `AudioServer` bus volumes. `Events` gained
nothing. `_apply_all_volumes` now reads `target_db`, so the volume settings and the duck compose
instead of fighting. `TestCase.parent_of_script(scene, script)` is `settings_consumers_test.gd`'s
private `SceneState` walk, moved out on its SECOND caller the way `FlagQuery` moved out of
`dialogue_runner.gd` — that file's three call sites now go through it and nothing was copied.

**Verified.** Every line is a measured exit code.

```
--headless --import                                        exit 0 (run first; gotcha 53)
--headless --quit-after 30                                 Session ended after 0.6s — 0 warnings, 0 errors
--headless res://tests/test_runner.tscn --quit-after 400   === 1935 passed, 0 failed, 0 skipped ===, exit 0
tools/check_budgets.gd    exit 0   154 files, 14076 code lines, 0 violations
tools/check_content.gd    exit 0
tools/check_boundary.gd   exit 0   219 rows, 51 content namespace
tools/check_strings.gd    exit 0
tools/check_layers.gd     exit 0   92 symbols over 102 scripts
tools/check_signals.gd    exit 0   43 declared, 100 emit references over 41
--resolution 960x540 --quit-after 90 -- --new-game --shot=... --time=18:40 --freeze-time
                          0 warnings, 0 errors; the standing dusk frame, unchanged
```

Suite 1,898 -> 1,935. `audio_director.gd` 105 -> 118 of its 150, `dialogue_duck.gd` is new at 16,
`test_case.gd` 41 -> 52, `settings_consumers_test.gd` 211 -> 200 because the walk left it.

**PROVED BY PLANTING THE REVERSION, WATCHING IT FAIL, REMOVING IT AND WATCHING IT PASS. BOTH exit
codes for all five plants.** Each is a real reversion of this row's own work, and each names a way
this feature could have been shipped looking correct.

| Plant | Result |
|---|---|
| `target_db` returns the offset ABSOLUTELY — the behaviour `duck()` actually had | `a quieter setting carries the ducked level down with it`, `AND THE DUCK IS STILL DOWNWARD, which an absolute target was not`, `moving the slider mid-duck lands on the DUCKED level`. **1932 passed, 3 failed, exit 1** |
| `_move_buses` sets the bus before tweening — a cut wearing a fade's clothes | `the bus has NOT moved yet, because a duck is a fade and not a cut`, `half the fade is half the drop`, `and it comes back up over time too`. **1932 passed, 3 failed, exit 1** |
| the count is dropped: duck on every start, unduck on every finish | `a second conversation holds it too — expected 2, got 1`, `and one of them ending releases only its own hold`, `SO THE MUSIC IS STILL DOWN, with somebody still talking`. **1932 passed, 3 failed, exit 1** |
| the `DialogueDuck` node is deleted from `game_root.tscn` — gotcha 54, aimed | `the running game has a DialogueDuck under the root — expected ., got `. **1934 passed, 1 failed, exit 1.** The `[ext_resource]` line was still in the file, which is gotcha 56 measured rather than restated |
| `_apply_all_volumes` reads `_db_for_bus` again — a slider lifts the duck | `moving the slider mid-duck lands on the DUCKED level`, `and not on the un-ducked one`. **1933 passed, 2 failed, exit 1** |
| all five removed | **1935 passed, 0 failed, exit 0** |

**WHICH HALF IS PROVED BY ASSERTION, AND WHICH IS NOT PROVED AT ALL.** A bus volume in dB is a
number the audio server hands back **even under the dummy driver**, so unlike T5.7's and T5.9's
camera work, essentially all of this is a measurement here rather than a photograph: the level, the
relativity, the timing, the balance, and the wire from a real `DialogueRunner.begin()` through the
real signal to the real mixer. **A windowed run adds nothing to it** — a still frame cannot show a
decibel, and there is no dialogue in the standing capture to duck under. The capture was taken
anyway, because `game_root.tscn` and an autoload changed, and it is a regression check and nothing
more: the dusk courtyard, the `Autosaved.` toast T5.10 added, `Day 1 | 18:40 | Dusk` and
`Read Weathered Notice`, all unchanged, 0 warnings and 0 errors. **What is genuinely unproved is
whether any of it can be HEARD, and nothing in this repository can prove that**, because there is
no audio in the project at all — art is deferred, so the buses have always carried silence. That is
why the inventory row stays `PART`.

**THE FOURTH CONSUMER GATE WAS CONSIDERED AND DELIBERATELY NOT BUILT, which the row asked to be
told either way.** T5.4 built three gates for the "declared and read by nothing" class — signals,
CSV rows — and T5.5 asked it of settings in the suite; T5.5 then wrote down that **public methods
are still declarable-and-dead and nothing says so**, which is how this row's subject survived three
phases. A gate for it is not the same size as those three. A method is called by name on a variable
whose static type a text scan does not know, through `Callable` and `.bind`, from `.tscn` property
values, from `tools/` and from `tests/` — and "has a caller in the suite" is not the same question
as "has a caller in the game", which is the distinction that matters and the one a scan cannot
make. It would need an exemption phrase like `check_signals.gd`'s `NO EMITTER` and a large,
argued exemption list on day one, and a gate that starts out mostly exemptions is decoration. **It
is a package, not a paragraph, and it is on the board as candidate K.** Saying so is the point:
this row closed the instance and not the class, and the next instance will again be found by
reading.

**Unblocks.** A consuming game inherits ducking it does not have to write and can remove with one
node, and a `duck()` whose argument means the same thing at every volume the player might choose.
`AudioDirector` now has no public method without a consumer, which is a thing that can be said of
exactly one file in this repository and was true of none before. `TestCase.parent_of_script` makes
"is this node really in the running game's scene" a one-line question for every case that comes
after, which is the assertion gotcha 54 keeps asking for.

**Gaps, stated rather than left to be rediscovered.**
- **Nothing here has been heard.** There is no audio in the project, so every claim in this row is
  about a number on a bus. When the first `.ogg` lands, the thing to check by ear is whether −8 dB
  and 0.4 s are the right two numbers; they are consts on the mixer precisely so that is one edit.
- **The duck is proved in the suite and never in a running session.** A `dev_probes.gd` probe that
  walks the demo's garden-keeper, opens the conversation and logs the Music bus in dB would close
  it, and it belongs with the two probes already wanted — T5.9's gate shake and T5.10's
  autosave-and-continue. It is the same row, now with three reasons.
- **One occasion is a judgement, not a derivation.** Dialogue is the occasion this template can
  see. A cutscene, a codec call or a boss door are all `Audio.duck()` from somewhere else, and
  nothing asserts that dialogue is the RIGHT one, because nothing could.
- **`held()` counts conversations, not speakers.** A game that emits `dialogue_started` per LINE
  rather than per conversation would duck once and never release until the last line — correct
  behaviour for a wrong emitter, and the signal's own comment says which it is.
- **The ducked bus set is a const, not a policy.** `DUCKED_BUSES` is Music and Ambience. A game
  with a separate Voice bus would add it to `BUSES` and would want it OUT of `DUCKED_BUSES`, and
  nothing enforces that pairing.
- **No ADR.** One node, two connections, one decision, and a method on the file that already owns
  bus decibels. No autoload, no new signal, no new layer, no new seam concept.

## 2026-09-06 — T5.12 · Two capture gaps closed, and the third argued away

**Did.** Built `src/systems/debug/dev_scenario_shots.gd`, the fifth debug file, and wired its node
into `game_root.tscn`. Three flags: `--gate-shot=<dir>` opens the demo's north gate by pressing the
interact key and photographs the shake it asks for; `--autosave-write` and
`--autosave-continue=<dir>` are a two-process pair that writes an autosave from a real arrival and
reads it back by pressing the real Continue row. **T5.11's probe was NOT built, and the reason is
below rather than in a gaps list.** 12 new assertions across two existing cases, two plants, one
new gotcha. No new signal, no new setting, no autoload, no ADR, no CSV row. Version **3.1.0** —
MINOR, argued below.

**THREE ROWS DEFERRED THE SAME WORK, WHICH IS THE SIGNAL, AND THE FIRST JOB WAS TO ASK WHETHER ALL
THREE DESERVED IT.** They did not.

| Gap | Verdict | Why |
|---|---|---|
| T5.9 — the gate's own shake | **built** | `--shake=` emits the signal a gate emits, so it photographs the RIG. Nothing had ever shown a gate doing it, and `Gate.perform()`'s emit was proved by reading four lines |
| T5.10 — the autosave read back | **built** | The row's own words: the only claim resting on "it is the same code path". An in-process reload cannot tell a value read off disk from one never cleared |
| T5.11 — the music duck logged in dB | **NOT built** | It buys nothing. Gotcha 66 already retired the limit that made it look necessary, the duck is measured end to end in the suite through a real `DialogueRunner`, and — the point the gap itself makes — **a still frame cannot show a decibel**, so its whole output would be a log line. This package's own standard is that a probe producing only a log line has not closed a capture gap |

The strongest remaining argument for the third probe was a pause hazard: a `Tween` on a node that
pauses does not advance, and `custom_step()` bypasses pausing entirely, so the suite would be blind
to it — gotcha 54's shape exactly. **It was checked and it does not exist.** `AudioDirector` is
`PROCESS_MODE_ALWAYS` with a comment naming that hazard by name, and `DialogueScreen` sets
`pauses_world = false`, so the tree is not paused during a conversation in the first place. Two
independent reasons, either sufficient. **Two well-built probes beat three, and this is the second
row running to conclude that a listed item was listed rather than justified.**

**THE GATE SHAKE, AND THE PROBE FOUND TWO DEFECTS IN ITSELF BEFORE IT FOUND ANYTHING ELSE.** Both
were silent, both produced a green run, and both are the reason a probe is written and then RUN.

**Defect 1: standing beside a thing does not select it.** The first run teleported the player to
the courtyard's gate lever and pressed interact, and the log says the sensor was holding
`KeeperBarter` — the garden-keeper's barter action, two metres away, inside the sensor's 2.4 m
reach. A real object was really interacted with and really refused (`LOW_STANDING`), so nothing was
red. The lever was never thrown, the gate refused with `LOCKED`, and the picture was of a shut
gate. **The fix is what a player does about the same problem**: press the cycle key until the
sensor is holding the thing the probe named, capped at six tries, which is `--cycle=`'s reason for
existing on `dev_stage.gd`.

**Defect 2: `rest` sampled twenty frames after a teleport is not rest.** `follow_lag` is
exponential, so the rig approaches the player and never arrives, and the probe's first "shake" was
**0.428401 m rising monotonically to 0.428789 and stopping** — the smoothing tail of a gate that
had not opened, read as a shake. A decaying oscillation and an asymptotic approach are both
"the camera moved", and only the SHAPE of the trace tells them apart. `_camera_still()` now waits
for per-frame movement under 10 µm before the control shot is taken; it reports **53 frames**, and
53 frames is itself the measurement of how wrong twenty was.

**With both fixed, the trace is unmistakable:**

```
  selected 'GateLever' after 2 cycles, refusal 0
  [flags   ] area/courtyard/gate_unlocked = true
  selected 'NorthGate' after 0 cycles, refusal 0
  camera parked after 53 frames
--gate-shot camera parked at (0.000007, 8.56887, 3.572726), gate refusal 0
  [interact] NorthGate opened
  frame  0: camera 0.115811 m from rest      frame 13: camera 0.084386 m from rest
  frame  1: camera 0.118365 m from rest      frame 14: camera 0.000050 m from rest
  frame  2: camera 0.154743 m from rest      frame 20: camera 0.020390 m from rest
  frame  3: camera 0.000049 m from rest      frame 24: camera 0.014071 m from rest
  frame  4: camera 0.140668 m from rest      frame 25: camera 0.000050 m from rest
--gate-shot peak 0.154743 m on frame 2, camera now 0.000050 m from rest
```

**Frames 3 and 14 are the signature, not noise.** `_offset_by_shake` slides along x by
`sin(wave)` and along y by `cos(wave * 0.5) * 0.5`, so both components vanish together only where
`wave ≈ π` — a two-frequency formula leaving a fingerprint that a random jitter could not. The
decay reaches the parking floor by frame 25 of a 0.6 s (≈36 frame) shake, which is amplitude
falling under the noise floor before the timer expires, exactly as a linear decay on a small
amplitude should.

**THE CONTROL IS THE SAME COMMAND WITH ONE LINE OF `settings.cfg` CHANGED**, which is T5.9's
method and the only way to say the shake and not the scene is what moved:

| `gameplay/camera_shake` | peak displacement | gate |
|---|---|---|
| 1.0 (default) | **0.154743 m** | `NorthGate opened` |
| 0.0 | **0.000050 m** | `NorthGate opened` |

Three thousand to one, with the gate opening in both runs. And the run is REPRODUCIBLE to the
micrometre — 0.154743 m twice, forty minutes apart — because the shake is a sine and not noise,
which is the property T5.9 chose it for and this is the first thing to depend on it.

**WHAT THE PICTURES CARRY THAT NO ASSERTION CAN.** `gate_shake.png` is the whole world slid up and
left with **the HUD clock and the toast exactly where the control put them** — a camera-space
slide, not a world transform, which is a claim about the rendered frame and nothing else can make
it. The stone leaf that fills the middle of `gate_closed.png` is simply gone, and `gate_open.png`
is framed identically to the control with the leaf missing. Three pictures: shut, displaced,
settled. **And the metres are the measurement — gotcha 64's discipline — with the images as
corroboration**, because a rigid-offset search on a translating camera under-reports and would
disagree with the number.

**THE AUTOSAVE PAIR, AND IT IS TWO PROCESSES FOR `--save-state`'s REASON.** An in-process reload
cannot tell a value written to disk and read back from one that was simply never cleared. What
this pair adds to the pair that already existed is **the occasion and the door**: the write is
performed by `Events.area_entered` and never by the probe, and the read is performed by pressing
the main menu's own Continue row. Every save on disk was deleted first, so `autosave.json` was the
only file either process could have been talking about.

```
A  --autosave-write posed:       area='courtyard'     at=0.00,3.00  day=4 time=22:15 weather=4 carrying=1
A  [save] Slot 6 written (6 sections)          <- by area_entered, on arrival in the hall
A  --autosave-write file present: true, latest slot 6
A  --autosave-write before quit: area='lantern_hall' at=0.00,-4.20 day=4 time=22:15 weather=4 carrying=1
   ---- process ends ----
B  --autosave-continue at boot:  area=''             at=0.00,0.00  day=1 time=06:00 weather=0 carrying=0
B  --autosave-continue latest slot is 6, autosave slot is 6
B  --autosave-continue pressed the 'Continue — Slot 7' row
B  [world] Transition (none) -> lantern_hall (spawn '')
B  [save ] Slot 6 loaded (v1, 2s played)
B  --autosave-continue after:    area='lantern_hall' at=0.00,-4.20 day=4 time=22:15 weather=4 carrying=1
```

**The last line and the fourth are identical, and the sixth is what makes that mean anything** —
a fresh process holding day 1, 06:00, clear weather, an empty bag and no area at all. Five values
came back off disk and every one of them was posed to differ from the boot value, `STORM` for the
reason `--save-state` gives: the control has to differ or it proves nothing.

**`autosave_continued.png` carries what the report cannot.** The HUD reads **Day 4 | 22:15 |
Night**, the hall is lit for night rather than for the midday a boot would have given it, the
player is standing at the courtyard door, and the toast says **"Autosaved."** — the arrival that
this Continue produced firing the autosave occasion again, correct and visible. A restored
`Clock.hour` is a number in a log; a courtyard at night is a photograph, and it is the one that
says the value reached a renderer. `autosave_menu.png` is the other half: the Continue row exists
on a menu this process built from a file, and a first-run menu has no such row.

**A FINDING THE CAPTURE PRODUCED AND THIS ROW DID NOT FIX.** The row reads **"Continue — Slot
7"**. T5.10 chose `autosave.json` over `slot_07.json` precisely so the autosave would not read as a
seventh manual slot, and the FILE does not — but `MainMenuScreen._fill` formats every Continue row
with `{"slot": latest + 1}` and the label says Slot 7 anyway. It is a one-line wording question on
a UI string, it changes no behaviour, and it belongs to whoever owns that screen's copy rather than
to a probe package. Recorded here because a picture is how anyone was ever going to notice.

**TWELVE ASSERTIONS, AND NEITHER GROUP IS ABOUT THE PROBES' OWN BEHAVIOUR.** A probe is verified by
running it; what the suite can hold is the two facts the probes lean on.

- **`interaction_test.gd` +6 — the gate's own ask.** T5.9 asserted everything on the rig side and
  left the emitter to a code read, because "the only way to make a gate emit is to open one" — but
  `perform()` is the method the sensor calls and a test can call it too. A gate with an authored
  `open_shake` asks for exactly that amplitude and for `Gate.SHAKE_SECONDS`; **a gate left at the
  default zero opens and asks for nothing**, which is the half that matters, because a bare `emit`
  with no `if` keeps every other assertion in the group green. `HEAVY_SHAKE` is 0.6 and not the
  demo's 0.7, which would tie the case to content `check_boundary.gd` forbids it to name.
- **`dev_tools_test.gd` +6 — every debug script that reads the command line has a node.** A debug
  file with no node in `game_root.tscn` is not a broken tool, it is an ABSENT one: no `_ready`, no
  argument parsing, every documented flag silently ignored, and nothing red anywhere — the file
  parses, the budget checker counts it, `check_boundary.gd` finds its release gate, and the run
  prints the log of a game nobody asked to do anything. **T5.12 is the row that could have suffered
  it**, the fifth file having been written, typed and green a full minute before its node existed.
  The scan is over the DIRECTORY, so a sixth file is covered the day it is written.

**Both plants were real reversions, and both exit codes are here.**

| Plant | Reversion | Result |
|---|---|---|
| 1 | deleted `if open_shake > 0.0:` from `Gate.perform()`, leaving the emit | **exit 1** — `1946 passed, 1 failed`; `FAILED: a silent gate asked for nothing — expected 0, got 1` |
| 1 control | restored | **exit 0** — `1947 passed, 0 failed, 0 skipped` |
| 2 | deleted the `DevScenarioShots` node from `game_root.tscn` | **exit 1** — `1946 passed, 1 failed`; `FAILED: dev_scenario_shots.gd has a node in game_root.tscn — expected ., got ` |
| 2 control | restored | **exit 0** — `1947 passed, 0 failed, 0 skipped` |

**WHY A FIFTH FILE AND NOT A FLAG ON `dev_probes.gd`.** The budget forced the question and the
answer was already there, which is the third time that has happened to this directory.
`dev_probes.gd` is at 205 of its 250 and `dev_stage.gd` at 248, so neither could hold a probe that
drives a scenario AND owns a shutter. But the seam is real: `dev_probes.gd` prints a NUMBER,
`dev_capture.gd` shoots at a FRAME NUMBER, and neither can photograph a moment that exists for six
tenths of a second and only after a scripted sequence has produced it. That is the question
`dev_gait_shots.gd` already asks about a walk cycle, which is why the shutter here takes that
file's shape — `frame_post_draw` before reading the image, gotcha 59 — rather than a new one. The
new file is 198 of its 250.

**THE PEAK IS FOUND, NOT GUESSED, WHICH IS THIS FILE'S ANSWER TO GOTCHA 52.** `--shake=` runs for
8 seconds instead of `Gate`'s 0.6 precisely so a `--shot-frame` cannot miss it, and that trick is
unavailable when the gate decides the duration. So `_sample_shake` keeps the IMAGE of the largest
displacement rather than a frame number: the number in the log and the picture on disk come from
one frame by construction, and no guess is involved at either end.

**VERSION 3.1.0, MINOR, AND THE ARGUMENT FOR PATCH LOSES ON ONE LINE.** Nothing under `src/`
outside `src/systems/debug/` changed, which is the stated PATCH condition — but `game_root.tscn`
gained a node, and that is a file a consuming game has and has to merge. PATCH promises nothing a
game wrote is affected; a node it must take is something it has to do. MINOR, and the `CHANGELOG`
entry is three lines of scene text and a sentence saying that is the whole obligation.

**Why.** Three consecutive rows closing with the same admission is not three gaps, it is one, and a
capture gap that three packages agreed to defer will be deferred by the fourth. The deeper reason
is the one this project was founded on: **the previous project had 409 passing static checks and
had never rendered a frame.** An assertion that a signal is emitted and an assertion that a rig
consumes it are two green facts either side of a wire — gotcha 54 — and the only thing that reads
the wire is a photograph of a gate being opened by a key press.

**Connects.** `Gate.perform()` → `Events.camera_shake_requested` → `HD2DCameraRig.shake` (T5.9);
`Director.area_entered` → `Autosave.request()` → `SaveSystem.AUTOSAVE_SLOT` (T5.10);
`MainMenuScreen._on_continue` → `SaveSystem.load_from_slot` → `Director`. Nothing new was added to
any of them — this row is a reader of three existing chains and an author of none.

**Verified.** `--headless --import`; boot `0 warnings, 0 errors`; suite **1,935 → 1,947 passed, 0
failed, 0 skipped**, exit 0; six checkers each exit 0 (`budgets` 155 files / 14,324 code lines / 0
violations, `content`, `boundary`, `strings`, `layers`, `signals`); two plants at exit 1 with their
controls at exit 0, quoted above. Windowed: `--gate-shot` twice at 0.154743 m and its
`camera_shake=0` control at 0.000050 m; the autosave pair across two processes; the standing dusk
capture re-taken unchanged as a regression check.

**Unblocks.** Nothing was blocked on this. It removes three deferrals from three closed rows and
gives the next person who touches `Gate`, `Autosave` or `MainMenuScreen` a one-command way to see
the feature happen rather than to read that it does.

**Gaps, stated rather than left to be rediscovered.**
- **`--gate-shot` names two demo nodes by string and stops if they are absent.** `GateLever` and
  `NorthGate` are `find_child` names, so a fork that deletes the courtyard gets
  `could not select 'GateLever' in 6 cycles` and no pictures. That is the debug directory's
  exemption working as designed and it is in the `CHANGELOG`, but it does mean the flag is the
  first thing in `src/` a fork has to re-point rather than delete.
- **The peak is the largest SAMPLED displacement, not the largest displacement.** Physics runs at
  60 Hz and the shake at 18 Hz, so the frames land at arbitrary phases of the wave and 0.154743 m
  is a floor under the true peak, not the peak. That is harmless for a ratio against a control at
  0.000050 m and would be wrong to quote as the amplitude — which is `shake_metres × open_shake`,
  a number the suite already owns.
- **`shake_hz` is still not asserted**, which T5.9 said and this row does not change. The probe
  would notice a frequency change, because the trace's zero crossings would move; nothing
  automated reads that trace.
- **The Continue row says "Slot 7"** — recorded above, not fixed, and not this package's file.
- **The autosave pair is two commands a human runs in order**, with nothing enforcing the order or
  the gap between them. Run B against no autosave logs `found no Continue row on the main menu` and
  stops, which is a clear failure, but it is not the same thing as a harness.
- **Nothing here is in CI**, and cannot be: both probes need a display server, which is the one
  rung a GPU-less runner has never been able to do.
- **The autosave pair's clock is exact to the minute and not below it.** Run B does not pass
  `--freeze-time`, so `Clock` runs while the world settles and a re-run showed `time=22:16` where
  the transcript above says `22:15`. That is the clock working, and it is why the reports are
  compared as five values rather than as a byte-identical string; freezing run B would have made
  the comparison exact and would also have photographed a game with its clock stopped, which is
  not what a Continue gives a player.
- **No ADR.** One file, one node, three flags, no new signal, no new layer, no new seam concept.

**PR #41, on `ed9421b`**, based on `claude/t5-11-music-duck` (#40). The two windowed rungs are not
in CI and cannot be — both probes need a display server, which is the one rung a GPU-less runner
has never been able to do, and it is the rung this row exists for.

**CI GREEN ON `f2c46e4`, PR #41, MERGEABLE / CLEAN** — both jobs pass. Full checkout
`=== 1947 passed, 0 failed, 0 skipped ===`; **stripped template
`=== 1873 passed, 0 failed, 25 skipped ===`**, and that is the number worth reading: T5.11 left the
stripped run at 1,861, so **all 12 of this row's assertions survive the demo strip.** That was the
one thing about them worth checking, because `interaction_test.gd`'s new case builds a real
`Gate` — it builds it from `scenes/objects/`, which is template geometry rather than demo content,
and configures `open_shake` itself with a `HEAVY_SHAKE` of 0.6 rather than reading the courtyard's
authored 0.7. `check_boundary.gd` says the same thing independently.

**`f2c46e4` IS A MERGE**, of the base's `f7d57cd` — the owner's answer to candidate C's seam
question, which landed on `claude/t5-11-music-duck` after this branch was cut. One conflict, in
`WORK_PACKAGES.md`, and both sides were right about different things: this branch inserted the
T5.12 section immediately above the candidate heading and the base rewrote that heading. Both kept.
`CONTEXT.md` auto-merged and its top block was amended in the merge commit, because it had been
written while C was still an open question and said so.

## 2026-09-06 — T5.13 · A public-method liveness gate, the fourth consumer question

**Did.** Built `tools/check_methods.gd`, rung 11 of the ladder and the seventh checker. It fails
when a public method declared at column 0 under `src/` has its name written nowhere else in the
repository. Acted on all twelve of its first-run findings: **two deleted, one wired, nine
exempted**, each exemption argued in a sentence beside the declaration. Added 23 assertions to
`tests/unit/gates_test.gd`, wired the checker into both jobs in `.github/workflows/ladder.yml`,
and bumped the base to **4.0.0**.

**Why.** T5.4 built three gates for the "declared and read by nothing" class and T5.5 asked the
question of the settings in the suite. A public method was the one member of that class with no
enforcement — which is how `AudioDirector.duck()` survived three phases uncalled and, when finally
wired at T5.11, turned out to be **wrong as well as unused**: it ducked to an absolute −8 dB, so
against a player who had moved `audio/music` to 0.25 the same call made the music four decibels
LOUDER every time somebody spoke. Code with no consumer is not merely unused, it is unverified,
and eight instances have now said so.

### The design question was which methods it is asked of, and it was the whole package

T5.11 wrote down why this cannot be `check_signals.gd` with the subject changed: a method is
called by name on a variable whose static type a scan does not know, through `Callable` and
`.bind`, from `.tscn` property values, from `tools/` and from `tests/`. **All of that is true and
none of it matters**, because the gate does not try to RESOLVE a call. It asks the narrowest
question a text scan can answer soundly — *did anybody write this name down at all*, on any
non-comment line, in `.gd`, `.tscn` or `.tres`. A `Callable(o, "alpha")` writes `alpha`. A `.bind`
writes it. A scene property writes it. An unqualified inherited call — `set_available(false)` in a
subclass — writes it, and that form is the one an earlier draft of this tool got wrong: it
searched for `.name` and reported `perform`, `add_row`, `push` and `request_close` as dead, all
four of them called with no receiver at all.

**What the gate cannot answer is left unasked rather than faked.** "Has a caller in the suite" is
not "has a caller in the game", and the distinction is real here: **86 of the 314 public methods
are reached only from `tests/` or `tools/`.** Failing on those would mean 86 exemptions on day
one, and a gate that starts out mostly exemptions is decoration — worse, it would be answered with
a fake caller in `src/`, which is a defect the gate would then certify as green. So it is REPORTED
on every run and never failed, which is `check_signals.gd`'s asymmetry for a signal with no
listener, with the subject changed. The count is printed so it cannot quietly grow.

**Which direction it errs in, stated rather than discovered later.** A local variable, a parameter
or another class's method sharing a name keeps a dead method looking alive; 37 names are declared
in more than one file and are treated as one. **The gate under-reports and cannot over-report**,
which is the right way round for something that fails a build: a green run is not a proof that
everything public is live, and a red run is always real.

### The first run, verbatim

```
Method check — every public method under src/ is called by something
==============================================================================
  public methods declared: 316 over 103 files
  preconditions: 157 scripts checked for a name built at runtime
  !! has_choices() is declared and called by nothing — ["res://src/content/dialogue/dialogue_node.gd"] (say 'NO CALLER' in its ## block if that is deliberate)
  !! is_equippable() is declared and called by nothing — ["res://src/content/items/item_definition.gd"] (...)
  !! trace() is declared and called by nothing — ["res://src/core/log/log.gd"] (...)
  !! get_flag() is declared and called by nothing — ["res://src/core/state/flags.gd"] (...)
  !! current_surface() is declared and called by nothing — ["res://src/gameplay/character/footsteps.gd"] (...)
  !! steps_taken() is declared and called by nothing — ["res://src/gameplay/character/footsteps.gd"] (...)
  !! current_activity() is declared and called by nothing — ["res://src/gameplay/character/npc_brain.gd"] (...)
  !! has_been_read() is declared and called by nothing — ["res://src/gameplay/interactables/readable.gd"] (...)
  !! fetch_int() is declared and called by nothing — ["res://src/gameplay/objects/persistent_state.gd"] (...)
  !! fetch_dict() is declared and called by nothing — ["res://src/gameplay/objects/persistent_state.gd"] (...)
  !! fetch_float() is declared and called by nothing — ["res://src/gameplay/objects/persistent_state.gd"] (...)
  !! reload_current_area() is declared and called by nothing — ["res://src/systems/scene_director/director.gd"] (...)
  exempted by 'NO CALLER' in their own ## block: 0
  names declared in more than one file, treated as one: 37
  reached only from tests/ or tools/ (reported, not failed): 86
==============================================================================
FAIL — 12 method violation(s)
```

**Twelve of 316, so 3.8% — real and bounded, which is what the row asked to be told either way.**

### Would it have caught the thing it exists for

Yes, and this is a fact about a commit rather than an opinion. At `7a162ca`, the merge base before
T5.11:

```
$ git grep -n -w -e duck -e unduck -e stop_music 7a162ca -- src tests tools scenes
src/gameplay/interactables/interactable.gd:9:## calling a method on an untyped value. A duck-typed component would need casts at every call
src/systems/audio/audio_director.gd:77:func stop_music(fade: float = DEFAULT_FADE) -> void:
src/systems/audio/audio_director.gd:95:func duck(amount_db: float = -8.0, seconds: float = 0.4) -> void:
src/systems/audio/audio_director.gd:104:## Undo duck() by re-reading the settings, so it cannot drift out of sync with the mixer.
src/systems/audio/audio_director.gd:105:func unduck(seconds: float = 0.6) -> void:
```

Five hits for three method names: three declaration headers and two comment lines, one of which is
the word "duck-typed" in an unrelated file. The tool drops comments and declaration headers before
counting, so all three would have been reported on the day each landed.

### The twelve verdicts, and every exemption argued rather than granted

| Method | Verdict | Why |
|---|---|---|
| `DialogueNode.has_choices()` | **deleted** | Two lines of alias over `not choices.is_empty()`. `DialogueRunner` and `DialogueScreen` each write `available_choices().is_empty()` and neither ever went through it. `stop_music()`'s shape and `stop_music()`'s verdict |
| `ItemDefinition.is_equippable()` | **deleted** | Its doc block said "an `Equipment` component and a UI row both ask this rather than each comparing against NONE themselves". **Neither ever did.** `Equipment.can_equip()` compares through `slot_of()`, which is strictly better because it also answers NONE for an id with no definition at all |
| `NpcBrain.current_activity()` | **wired** | `activity_name()` indexed the private `_activity` beside it. It now reads the accessor, so one fewer place knows how the enum is stored |
| `Log.trace()` | exempt | One rung of a five-rung level ladder that `min_level` can select. Deleting the bottom of a ladder because the demo does not reach it is the wrong cut |
| `Flags.get_flag()` | exempt | The untyped hatch. Every type this template stores has a typed accessor that is better; it survives for the type the template did not anticipate, and the typed accessors cannot be widened to a type they cannot check. The neighbouring comment read "use these rather than get_flag", which is deprecation of a method with no replacement; it now names it as the hatch |
| `Footsteps.current_surface()` | exempt | Its doc said **"Read by the probe"** and no probe in this repository has ever read it. The line is corrected and the real reason kept: it is what a dust puff or a footprint decal reads on the frame it spawns |
| `Footsteps.steps_taken()` | exempt | The same pair: a distance achievement, a tutorial firing on the tenth step, a debug overlay — none of the three is here |
| `Readable.has_been_read()` | exempt | The write side is `perform()` four lines above; the read side belongs to a consuming game's quest condition or dialogue gate. `Gate.is_open()` is the same shape one layer over |
| `PersistentState.fetch_int()` / `fetch_dict()` / `fetch_float()` | exempt | One decision, three methods. `fetch_bool` and `fetch_string` are used, and a typed family with holes is worse than none: the game storing a counter on an object would reach past `PersistentState` to `Flags` and lose the per-object key prefix that is the whole point |
| `Director.reload_current_area()` | exempt, and it was the close call | Three lines that any caller could write as `Events.area_change_requested.emit(current_area_id, &"")`, which is `stop_music()`'s argument exactly. It stays because it names an OCCASION rather than duplicating a spelling — it is the only caller that has to read `current_area_id` off the Director to know where "here" is. Recorded because the reasoning is thinner than the other eight |

**Nine exemptions out of twelve is close to the line the row drew, and worth being explicit
about.** The claim is not that the day-one yield is large. It is that (a) every exemption is a
sentence somebody had to write next to the declaration, and two of them corrected a false claim
that had been sitting in the file unchallenged; (b) a stale exemption fails, so none of the nine
can rot into permission; and (c) the gate is permanent — the next `duck()` fails the build on the
day it lands rather than three phases later.

### The precondition, and the one thing this gate cannot see

A name **built** at runtime — `o.call("fetch_" + kind)` — is invisible to a text scan, and a green
run would then say nothing at all about that method. So the tool fails on any line that both
dispatches (`call(`, `callv(`, `call_deferred(`, `Callable(`, `has_method(`) and builds a string.
There are none today: every dispatch site in the repository is a call on a `Callable` made where
its method name is written out. That is `check_boundary.gd`'s debug-gate precondition in this
file's terms — the gate fails the day its own reasoning stops holding.

**It fired on this row's own test file first**, which had written the opaque sample out whole on
one line while asserting the classifier that detects it. The gate was right and the test was the
violation; the sample is now split across two constants so no single line is a dispatch site, and
the file says why. **That is gotcha 69**, and it waits for every gate whose evidence is a line of
text: `check_strings.gd` and `check_boundary.gd` both scan `tests/` and would both fail a case
that quoted a real violation in order to assert against it.

### Assertions

**+24, suite 1,947 -> 1,970**, all in `tests/unit/gates_test.gd`, and all on the CLASSIFIERS
rather than on today's tree — the file's own standing rule, because a plant is a one-off and what
rots afterwards is the four lines that decide what a declaration is.

- **What counts as a declaration** (5): column 0 only, `static` included, an indented line is not
  one, a `var` is not one, and a private name is still a declaration with the caller dropping it.
- **What counts as a reference** (4): whole word, so `alphabet` and `my_alpha` do not keep `alpha`
  alive, and two sites count twice.
- **The two kinds of line thrown away first** (3), each a real defect in a draft: a doc comment
  mentioning a method is not a caller, a declaration header is not a caller, a call in a body is.
- **The precondition classifier** (4): a dispatch site is recognised, an ordinary call is not,
  concatenation is what makes a dispatch site opaque, and a line with only the first half is not.
- **The exemption phrase** (5): non-empty, uppercase so prose cannot grant one by accident, not
  the same phrase as the signal gate's, carried by at least one method, and **every use of it in
  the whole engine tree sits in a comment** — a phrase in live code would exempt a method nobody
  meant to exempt.
- **The ladder** (2 more, 14 in total): CI names `tools/check_methods.gd` as its own step and the
  file exists. This is the assertion that would catch a gate written, committed and never wired,
  which is the defect the whole package is about applied to the package itself.

### Verified

| Rung | Result |
|---|---|
| `--headless --import` | clean |
| `--headless --quit-after 30` | `Session ended after 0.6s — 0 warnings, 0 errors` |
| `--headless res://tests/test_runner.tscn --quit-after 400` | **1970 passed, 0 failed, 0 skipped** |
| windowed capture, `--time=18:40 --freeze-time` | unchanged from T5.12, `0 warnings, 0 errors` |
| `check_budgets.gd` | exit 0 |
| `check_content.gd` | exit 0 |
| `check_boundary.gd` | exit 0 |
| `check_strings.gd` | exit 0 |
| `check_layers.gd` | exit 0 |
| `check_signals.gd` | exit 0 |
| `check_methods.gd` | exit 0 — 314 methods, 9 exempted, 37 shared names, 86 suite-only |

**Three plants, each a real reversion, each exit 1, control exit 0.**

| Plant | Output | Exit |
|---|---|---|
| `DialogueNode.has_choices()` restored | `!! has_choices() is declared and called by nothing — ["res://src/content/dialogue/dialogue_node.gd"]` | **1** |
| `NO CALLER` written above `Flags.get_bool()`, which has callers — a STALE exemption | `!! get_bool() is marked 'NO CALLER' and has 49 reference(s) — the exemption is stale` | **1** |
| `PersistentState.fetch_int()` rewritten to dispatch on a built name | `!! res://src/gameplay/objects/persistent_state.gd dispatches by a BUILT name — this gate cannot see that` | **1** |
| all three removed | `PASS` | **0** |

**The windowed capture was taken as a REGRESSION CHECK and nothing more, and saying which it is
matters.** Nothing this row changed can move a pixel: the two deleted methods had no caller, and
the wired one returns the value the line beside it already read. The standing dusk capture is
unchanged — `Day 1 | 18:40 | Dusk`, the `Autosaved.` toast, `Read Weathered Notice`, the keeper on
the dais — at `0 warnings, 0 errors`, camera at `(0.0, 8.56925, 14.87248)`. It proves the game
still boots and renders, which is the whole claim being made for it.

**4.0.0 — a MAJOR bump, and the version discipline question the row asked.** A new tool under
`tools/` that changes nothing under `src/` would be a PATCH: a consuming game inherits no
obligation from a checker it can decline to run. **But two public methods are gone**, and that is
a MAJOR bump by the rule 3.0.0 set for `stop_music()`. The `CHANGELOG.md` entry names the exact
replacement for each — `not node.choices.is_empty()` and
`Equipment.slot_of(id) != GameEnums.EquipSlot.NONE` — the way that entry did.

**Unblocks.** The fourth and last member of the "declared and read by nothing" class is enforced,
so the next instance fails a build instead of being found by reading. A consuming game gets a tool
that will say something on its own tree, which is larger than this one. And nine methods that were
silently unused are now nine methods whose reason for existing is written down beside them, which
is the part that survives after the tool.

**Gaps, stated rather than left to be rediscovered.**
- **86 methods are still unanswered.** The gate cannot tell a template seam from a method kept
  alive only by its own test, and that is the class `duck()` belonged to right up until it was
  built-or-deleted. A suite-only method is where the next one will be, and this gate will not find
  it. What would: a run of the game with a call recorder, which is a package of its own.
- **37 shared names are one name.** `perform` is declared on eleven files and any single call
  keeps all eleven green. A dead `perform()` override on one subclass is invisible here.
- **It cannot see a method called only from an exported build**, because it never runs one.
- **`Director.reload_current_area()` is exempt on the thinnest reasoning of the nine**, and it is
  the one to revisit if a debug console command ever wants it or a row ever needs three lines back.
- **No ADR.** One tool, one exemption phrase copied from an existing gate, and no new autoload,
  signal, layer or seam concept.

## 2026-09-06 — T5.14 · A turn in place, and the seam decision was the package

**Did.** Put candidate C's question to the owner with four answers and their costs, built the one
they chose, and photographed it. `Events.turn_requested(character: Node3D, towards: Vector3)` is a
new signal; `CharacterVisual` listens and answers only for the character the request names;
`InteractionSensor` asks for the player when a target is selected while they are STILL or when
they come to rest with one selected; `Speaker` asks for the character it hangs under, if there is
one, towards whoever spoke. New `tests/unit/turn_test.gd` (13 assertions), a `--turn-shots=<dir>`
pass on `dev_gait_shots.gd`, and **4.1.0** — a MINOR bump, because every character a consuming
game already has gains the behaviour and nothing it wrote has to move.

**Why the row began with a question, and why that was the right shape.** `face_direction()` has
been correct, statically typed, asserted by `facing_test.gd` and reached only from `tests/` since
the day it was written — one of the 86 suite-only methods T5.13's gate reports. Nothing was wrong
with the code. What was missing was an OCCASION, and T5.3, T5.5 and T5.6 each declined to invent
one silently because WHO may ask for a turn is a design decision. The four options put to the
owner were: the sensor alone, `Speaker`/`NpcBrain` alone, both through a bus signal, or deletion
on `stop_music()`'s precedent.

**THE OWNER ANSWERED BOTH, AND THE REASON SETTLED THE SEAM RATHER THAN JUST PICKING FROM THE
LIST.** The case they described — *"sometimes some NPCs will notice the player and stop us and come
nearby to talk"* — **has no interactable in it at all.** No asker living inside the interaction
path can serve it, which rules out a method call from `InteractionSensor` and rules out one from
`Speaker`, and leaves the bus. That is the whole argument for the third option, and it came from
the owner's use case rather than from a preference for signals: the seam is drawn where a THIRD
asker costs nothing.

**THE EXPENSIVE-LOOKING PART DID NOT EXIST, AND SAYING SO WAS A CORRECTION.** The question put to
the owner priced option 2 as needing a hold flag, on the reasoning that `NpcBrain._physics_process`
pushes a velocity into the visual every frame and would undo the turn on the next one. It does push
one — but `update_from_velocity` calls `_aim` only when `speed > 0.05`, so a standing character
keeps whatever facing it was last given. No hold flag, no timer, no `dialogue_finished` listener to
undo anything, and an NPC still looking at you when the box closes for free. That is asserted
directly, because the day it stops being true an NPC will snap back one frame after you speak to it
and nothing else in the suite would notice.

**WHY THE LISTENER IS IN `CharacterVisual` AND NOT IN THE TWO DRIVERS.** `PlayerController` and
`NpcBrain` are the two things that drive a visual, so honouring the request in each of them is the
obvious placement — and it is two copies of one implementation, kept in step by hand, for a class
that already exists to be the one answer to "what does this character look like". Putting it in the
visual makes it one function. The objection is that file's own comment on `_state`, which forbids
listening to `Events.player_state_changed`, and the distinction is exact and now written on
`_on_turn_requested`: that signal is about THE PLAYER, so a class every NPC also uses must not hear
it, while `turn_requested` NAMES the character it is for. The filter is `character == self or
character.is_ancestor_of(self)` — an ancestor rather than the parent exactly, so a game may hang
its visual under an offset node.

**`Speaker` GREW AND ITS HEADER SENTENCE SURVIVED, WHICH IS WORTH THE THREE LINES IT COST TO
CHECK.** "It names a conversation id and nothing else" is still true of the DATA it carries: no
second export, no second id, and the fiftieth speaker is still a `.tscn` override with no code. What
it gained is that it may hang under a `CharacterBody3D` — the ENGINE's word, not this game's. It
does not know the body has a brain, a schedule, a visual or a sprite, `NpcBrain` is not named
anywhere in it, and a `Speaker` on a plaque finds no character above it and asks for nothing.

**Connects.** `InteractionSensor` / `Speaker` -> `Events.turn_requested` -> every `CharacterVisual`
-> `face_direction` -> `_aim` -> `_apply_frame`, which is the path `facing_test.gd` has asserted
from the far end since Phase 1 and which nothing in the game had ever entered. `Speaker.perform`
already received the player as `who`, so the NPC half needed no new argument anywhere. The stillness
gate's constant is `0.05`, deliberately the same number `update_from_velocity` uses, because two
files disagreeing by a hundredth about what "moving" means is a turn asked for and silently undone
on the very next frame.

**Verified.** Every line is a measured exit code.

```
--headless --import                                        exit 0 (run first; gotcha 53)
--headless --quit-after 30                                 Session ended after 0.6s — 0 warnings, 0 errors
--headless res://tests/test_runner.tscn --quit-after 400   === 1983 passed, 0 failed, 0 skipped ===, exit 0
tools/check_budgets.gd    exit 0   157 files, 0 violations
tools/check_content.gd    exit 0
tools/check_boundary.gd   exit 0
tools/check_strings.gd    exit 0
tools/check_layers.gd     exit 0
tools/check_signals.gd    exit 0   turn_requested has two emitters
tools/check_methods.gd    exit 0   86 reached only from tests/ or tools/ (reported, not failed)
```

Suite 1,970 -> 1,983. Budgets: `character_visual.gd` 131/250, `interaction_sensor.gd` 173/250,
`speaker.gd` 32/250, `events.gd` 46/150, `turn_test.gd` 107/250 (new).

**THREE PLANTS, EACH THE REAL REVERSION, AND BOTH EXIT CODES FOR EVERY ONE.**

| Plant | Result |
|---|---|
| the listener never connected in `_ready` | `a turn request turns the character it names — expected 5, got 0`. **`=== 1982 passed, 1 failed ===`, exit 1** |
| `_draws` returns `character != null`, so a courtyard turns as one man | `and leaves every character it does not name exactly where it was — expected 0, got 5`. **`=== 1982 passed, 1 failed ===`, exit 1** |
| the stillness gate deleted from `_turn_to_target` | `and a target that takes the prompt MID-WALK asks for nothing either — expected 1, got 2`, plus one more. **`=== 1981 passed, 2 failed ===`, exit 1** |
| all three removed | **`=== 1983 passed, 0 failed ===`, exit 0** |

**AND THE THIRD PLANT PASSED THE FIRST TIME, WHICH IS GOTCHA 70.** The stillness gate was deleted —
the real line, the whole point of it — and the suite came back **`1982 passed, 0 failed`, exit 0**.
The case as first written walked the player with the SAME target selected throughout, and in that
sequence the surviving `just_stopped` term already implies stillness, so removing the test changed
nothing measurable. The gate exists for a target that CHANGES mid-walk — a player crossing a
courtyard past a row of objects — and that frame simply was not in the case. With a second
interactable that takes the prompt while the player is moving, the same plant fails twice. **The
answer to a plant that passes is a harder case, never a weaker claim**, and a green plant is the
only way to find out that an assertion was decoration.

**WINDOWED CAPTURE, WHICH FOR THIS ROW IS THE PROOF** (gotcha 2 — `--headless` shades nothing, and
gotcha 28 — a sprite drawn from the wrong cell is still a person, so the number alone will not do
either). `--resolution 960x540 --quit-after 300 -- --new-game --time=13:00 --freeze-time
--turn-shots=user://shots/turn`, `0 warnings, 0 errors`:

| shot | decoded | |
|---|---|---|
| `turn_before` | `frame=19` -> block 0, **column 3**, cell 2 | the figure faces away and to the right; the ear patch and the sash sit on its right side |
| `turn_control` | `frame=19` -> block 0, **column 3**, cell 2 | the same shutter gap again with NO turn asked for |
| `turn_after` | `frame=29` -> block 0, **column 5**, cell 3 | the ear patch and the sash have moved to its left side — the mirrored facing, a genuinely different figure |

**`the idle cycle alone moves 0.1838 of the crop, the turn moves 0.7666`.** The control is not
decoration: this sheet's idle block animates and the renderer has its own frame-to-frame noise, so
two shots one shutter apart already differ by 18% of the crop with nothing happening at all. The
turn is four times that floor, and the decoded column moved two sectors. Columns 3 and 5 happen to
be a mirrored pair on this sheet (T5.8's `FACING_MIRROR`), which is why the difference reads as the
figure turning through profile rather than front-to-back.

**Unblocks.** A consuming game gets the behaviour on every character it already has, with no export
to set and no scene to touch, and gets a seam for its own askers: a cutscene, a quest step, a
trigger volume or an NPC that walks over to you all emit the same signal. The last of the seam
decisions the board was holding for the owner is answered, so nothing on it is now blocked.

**Known gaps.**
- **THE GATE'S 86 DID NOT MOVE, AND THE GATE IS RIGHT.** `face_direction()` is still counted
  suite-only, because `check_methods.gd` files a reference inside the declaring file under `self`
  rather than `src`, and its only caller is `_on_turn_requested` one function below it. The wire is
  a signal connection, which no text scan can follow. **The fix is not to restructure the code**:
  moving the listener into `PlayerController` and `NpcBrain` would satisfy the counter by
  duplicating one implementation into two files, which is exactly the fake caller T5.13 refused. It
  is the sharpest illustration yet of why answering the 86 needs a call recorder on a real run.
- **The capture asks on the bus rather than walking the player at an object.** What needed
  photographing is the LISTENER end — that a request becomes a different figure on a screen — and
  the two askers' occasions are staged exactly and cheaply in the suite. A probe that walked the
  player at an authored object would photograph the courtyard's furniture placement as much as the
  turn. Stated in the tool's own header rather than left for a reader to notice.
- **A turn is a SNAP, not an animation.** The character changes column in one frame. Interpolating
  through the intervening facings is a different feature, wants `accessibility/reduce_motion` in the
  row with it, and is not what the roadmap line asked for.
- **`Speaker` does not turn the PLAYER towards the NPC** when a conversation begins. The sensor
  usually has already done it, because the player is standing still and the speaker is the selected
  target — but a conversation opened by a trigger volume rather than by a button press would leave
  the player facing wherever they stopped. One more emit would fix it and no occasion in the
  template needs it yet.
- **It did not split `tools/gen_placeholders.gd`**, still at 230 of its 250 and still next.
- **It did not fix the "Continue — Slot 7" wording** T5.12 found in `MainMenuScreen._fill`.
- **No ADR.** One signal on an existing bus, declared in `events.gd` with its own `##` block, and
  no new autoload, layer or seam concept.

## 2026-09-06 — T5.15 · The `Button` styleboxes, and the word that made them buildable

**Did.** Gave `MenuRow` and `ChoiceRow` all five of their states — `normal`, `hover`, `pressed`,
`disabled` and `focus` — plus the `_mirrored` and `hover_pressed` spellings, and the font colours
that were half the same defect. Candidate F, the last row on the board, and **the oldest declared
limitation in the project**: stated in `ART_CONTRACT.md`, `ARCHITECTURE.md` and `CONTEXT.md` since
T2.2, and deliberately left by four packages since. New `src/ui/root/ui_row_styles.gd` (91 code
lines), new `tests/unit/row_styles_test.gd` (62 outcomes), one new palette token, two new metrics,
one new gotcha, and one wording fix recorded as its own line rather than folded in.

**THE FOUR REFUSALS WERE RIGHT AND THIS ROW DOES NOT OVERRULE THEM.** Every one gave the same
reason: *a stylebox has to be designed, and the only palette to design against is the placeholder
one, so populating it would ship a decision as a default.* That is true, and it is why the answer
is not five authored `StyleBoxFlat` sub-resources in `ui_theme.tres`. **Nothing in
`ui_row_styles.gd` designs a colour. It designs the RELATIONSHIP between the five states**, and
takes every colour from the palette the theme already declares, at boot, into the two variations
that draw a Button. It is `UiAccessibility`'s sibling in every respect: that one owns the project
theme's font SIZES and this one owns its Button STYLES, neither knows which screens exist, and
both are one node under `UILayer` that a game may delete.

| State | Is | Why |
|---|---|---|
| `normal` | `surface` | the one new palette entry |
| `hover` | `surface` toward `text` | **directional** — see below |
| `pressed` | `surface` toward `accent` | a press is an ACT and wants a hue rather than another shade |
| `disabled` | `surface` at 35% alpha | the same row faded, not a different row |
| `focus` | an `accent` ring, **no centre** | composes with whichever of the other four is underneath |

**`hover` IS `surface` MOVED TOWARD `text`, AND THAT ONE WORD IS THE PACKAGE.** The stated defect
has two halves — *invisible against the shipped dark palette* and *immediately wrong against a
light one* — and a hard-coded lighten closes the first and leaves the second exactly where it was.
Moving toward the text colour lightens a dark row and darkens a light one from the same
expression, so the fix survives a palette this base does not ship. Measured on the real path:
**0.1490 -> 0.3020 on the shipped palette, 0.8902 -> 0.7529 on parchment.** `focus` is the state
that matters most and the one most likely to be forgotten, because a mouse user never sees it:
`MenuScreen`'s header says controller navigation is free because a VBoxContainer of Buttons
already answers `ui_up` and `ui_down`, and that is true only for as long as the player can tell
WHICH row answered.

**ONE PALETTE TOKEN WAS ADDED, AND ADDING IT SILENTLY WOULD HAVE BEEN THE INVENTION THE FOUR
REFUSALS WERE ABOUT.** There was no existing token for a button surface and the three near
candidates each fail for a stated reason: `dim` and `solid` are the panel a row sits ON, so a row
drawn in either vanishes into it, and `muted` already means "present but lesser" — a whole menu
drawn in it would say every row is half-earned. So `UiPalette/colors/surface`, argued in the
`.tres` comment beside it, and **the other four states derived from it rather than authored beside
it**, because a theme resource has no variables and five hand-picked surfaces are five things a
consuming game has to re-pick instead of one.

**FONT COLOURS WERE HALF THE LIGHT-PALETTE DEFECT ON THEIR OWN**, and would have been missed by a
package that thought about styleboxes only. `MenuRow` set no `font_color`, so a Button took the
fallback theme's near-white — legible on this palette, invisible on a pale ground whatever the
boxes do. The `states_light_before` capture shows it: white text on grey slabs on parchment.

**WHAT IT DOES TO A GAME THAT SHIPPED ITS OWN THEME — the question a MINOR bump has to answer.**
Two refusals, both asserted. A variation that already declares `styles/normal` is left completely
alone, because a game that authored its own rows has already made this decision and silently
replacing it would be a MAJOR bump wearing a MINOR number. A palette with no `surface` entry is
left alone entirely with one `WARN` line, because there is nothing to derive from. Deleting the
node from `game_root.tscn` is the third way out and restores 4.1.0 exactly. **4.2.0 and not a
PATCH** on `game_root.tscn` gaining a node a consuming game has to merge — T5.12's rule, applied
unchanged.

**Connects.** `UiRowStyles` sits beside `UiAccessibility` under `UILayer` and mutates the same
shared `Theme`; both are static-where-it-counts so the suite can drive the arithmetic without
leaving the project theme changed for every assertion that runs after. Nothing was added to
`Events` or `GameEnums`, no autoload was added, no ADR was needed, no screen file changed for the
styling, and `check_layers` is unchanged at `core -> ... -> ui`. The five states are written under
the engine's own theme item names, which is why nothing here needs a mapping table or an enum.

**Verified.** Every line is a measured exit code.

```
--headless --import                                        exit 0 (run first; gotcha 53)
--headless --quit-after 30                                 Session ended after 0.6s — 0 warnings, 0 errors
                                                           and one line: Row styles -> 2 variation(s)
--headless res://tests/test_runner.tscn --quit-after 400   === 2051 passed, 0 failed, 0 skipped ===, exit 0
tools/check_budgets.gd    exit 0   159 files, 14974 code lines, 0 warnings, 0 violations
tools/check_content.gd    exit 0
tools/check_boundary.gd   exit 0   219 rows, 51 content namespace
tools/check_strings.gd    exit 0   CSV rows loaded: 219
tools/check_layers.gd     exit 0   93 symbols over 104 scripts
tools/check_signals.gd    exit 0   44 signals declared, 107 emit references over 42
tools/check_methods.gd    exit 0   316 public methods over 104 files, 86 suite-only (reported)
```

Suite 1,983 -> 2,051: +62 from `row_styles_test.gd` and +6 from `menus_test.gd`.

**EVERY CHANGE PROVED BY PLANTING THE DEFECT, WATCHING IT FAIL, REMOVING IT AND WATCHING IT PASS.
Five plants, each a real reversion, and BOTH exit codes are here.**

| Plant | Result |
|---|---|
| `hover` lightens by a fixed amount (`surface.lightened(HOVER_LIFT)`) instead of moving toward `text` | `on a parchment palette, the same expression DARKENS it — expected true, got false`, `and it moves about as far either way`, `the box a light-palette menu draws is darker on hover than at rest`. **2042 passed, 3 failed, exit 1** |
| the `has_stylebox(NORMAL, variation)` guard is dropped, so a game's own rows are overwritten | `only the variation that authored nothing is styled — expected 1, got 2`, `and the game's own box is still the one there`, `with nothing added around it`, `a second run finds them authored and leaves them — expected 0, got 2`. **2041 passed, 4 failed, exit 1** |
| the focus box fills its centre (`draw_center` left true) | `the focus box draws no centre — expected false, got true`. **2044 passed, 1 failed, exit 1** |
| the `UiRowStyles` NODE is deleted from `game_root.tscn`, `[ext_resource]` left in place | `the running game has a row styler, under UILayer — expected ./UILayer, got `. **2044 passed, 1 failed, exit 1** |
| the Continue row numbers the autosave again | `Continue names the autosave — expected Continue — Autosave, got Continue — Slot 7` and `and never as a slot number — expected false, got true`. **2049 passed, 2 failed, exit 1** |
| all removed | **`2051 passed, 0 failed`, exit 0** |

**THE FIRST PLANT IS THE ONE THIS ROW EXISTS TO HAVE MADE, AND IT IS GOTCHA 70 READ THE OTHER WAY
ROUND.** `surface.lightened(0.18)` is not a broken assertion or an obvious sabotage — it is the
implementation this row would most plausibly have shipped, it looks identical on this project's
own palette, and **it passes every dark-palette assertion in the file.** Only the parchment cases
fail. That is the whole argument for asserting a palette this repository does not ship: gotcha 70
says a plant that passes is evidence about the test, and the converse is that a test which only
ever sees one palette cannot tell a directional rule from a constant. The fourth plant is gotcha
56 re-proved on a third node — `grep` still found `21_rows` in the scene file after the node was
gone, so a text scan would have stayed byte-identically green.

**Windowed captures, LOOKED AT.** Gotcha 2: `--headless` shades nothing, and this is a visual
claim end to end.

- **The main menu, before and after, same command, 960x540.** Before: six rows in the engine's
  fallback panel, each **0.0745,0.0706,0.0824** against a **0.0392,0.0314,0.0588** solid panel —
  a summed channel separation of **0.0981**, which is the "invisible" in the limitation, measured.
  After: **0.1490,0.1412,0.1882**, separation **0.3490**, a **3.6x** difference. **61,998 pixels
  of 518,400 differ over the whole frame and 61,998 of 157,440 differ inside the row band —
  identical counts, so every changed pixel is inside the rows and not one is outside them.**
- **All five states at once, before and after.** A still frame of the real menu can only ever show
  `normal` and `focus`, so a temporary probe scene put one row in each state — `disabled`,
  toggle-`pressed`, a real hover, and a focused row — and photographed them. Before, from the
  engine fallback: `0.0745 / 0.1490 / 0.0157 / 0.0549`, and **`pressed` at 0.0157 is DARKER than
  the 0.0392 panel behind it**, so a pressed row was a hole rather than a highlight. After:
  `0.1490 / 0.3020 / 0.4196,0.3686,0.3137 / 0.0784`, with the focus ring measured at
  **0.8588,0.7412,0.5216 — the palette's `accent` exactly.**
- **The whole thing again on a LIGHT palette**, because "immediately wrong against a light one" is
  half the stated defect and could not be photographed on the shipped one. Six palette lines
  changed in `ui_theme.tres`, no code, no other edit. Before: dark grey slabs at **0.4431** on a
  **0.9608** parchment ground, white text on them, and the focus row indistinguishable from the
  rest. After: **0.8902** rows, **0.7529** on hover — *darker*, from the identical expression that
  lightens on the dark palette — ink-dark text, and a rust focus ring. The main menu was shot on
  that palette too and reads correctly end to end. The palette edit was reverted; the assertions
  in `row_styles_test.gd` are the permanent record, and the probe scene is not committed.
- **The regression capture**, `--new-game --time=18:40 --freeze-time` at 960x540 with defaults:
  courtyard at dusk, both characters lit, depth-sorted and casting shadows, HUD reading
  `Day 1 | 18:40 | Dusk`, prompt on screen, `0 warnings, 0 errors`, exit 0. The demo is unchanged.
- **The final menu capture** shows `Continue — Autosave` where the before shot said
  `Continue — Slot 7`. That pair is NOT the pixel-difference pair quoted above: the wording fix
  landed after those two shots, and both of them say "Slot 7".

**GOTCHA 71 COST THE HOUR AND IS THE MOST TRANSFERABLE THING HERE.** The state probe pointed the
mouse at a row's `get_global_rect().get_center()` and the row never hovered — `canvas_items`
stretch keeps the logical size at 1920x1080 while the window is 960x540, so every rect a Control
reports is exactly twice the coordinate an `InputEventMouseMotion` needs, and `Input.warp_mouse`
fails identically. **The capture came back with the hover row byte-identical to the normal one**,
which is a perfectly plausible picture of a hover style that is merely subtle, and it would have
been recorded as one had the sampler not printed `vs previous row 0.0000`. `Button.is_hovered()`
returned false and `get_draw_mode()` stayed 0 the whole time. Ask the button, never the pixels.

**The Continue wording, fixed as its own line and not folded into the theme work.** T5.10 gave the
autosave a NAMED file rather than a seventh number precisely so nobody would read it as a seventh
manual slot, and the main menu's Continue row then printed "Continue — Slot 7" — the same reading
arriving by the one route a file name cannot close. `ui.menu.continue_autosave` and a three-line
`_continue_text` on `MainMenuScreen`; the slot is still what is LOADED and only the label changed.
Writing the assertion for it turned up a real property of `latest_slot()` worth knowing: two saves
written in the same second tie on `saved_utc`, and the loop keeps the first it met, so the test
has to delete the manual slot before the autosave is unambiguously the latest.

**Unblocks.** `ART_CONTRACT.md`'s known-gap section is gone and replaced by the derivation table,
so a game choosing a light look now changes six palette lines instead of discovering the rows
ignored them. `ARCHITECTURE.md`'s limitation bullet is rewritten rather than deleted, because
what remains true is that **the base still has no LOOK** — `surface` is a placeholder like every
other colour in that palette, and what 4.2.0 removed is not the need to choose one but the
possibility of choosing one and finding the rows had not followed.

**Gaps, stated rather than left.**
- **`ChoiceRow` is styled and not photographed.** The states probe drew `MenuRow`, and the
  assertions cover both variations identically; a dialogue capture would add a picture of the same
  five boxes under a different font size.
- **`tools/gen_placeholders.gd` is still at 230 of its 250** and is still the next file to split.
  Nine rows now.
- **`check_methods.gd` still reports 86** reached only from `tests/` or `tools/`, and this row's
  three new public methods did not move it. Answering the 86 needs a call recorder on a real run,
  which is a package of its own and is not on the board yet.
- **The candidate board is now empty.** C through K are all closed.

---

## 2026-09-07 — T5.16 · Quest chaining, and the guard that discarded what it was warned about

**Did.** Two things, and the first was not a package. **Landed the sixteen-package T5 stack on
`main`**: PR #44 was retargeted from `claude/t5-14-face-target` to `main` and merged as
`16e8bfd` — a clean fast-forward of 31 commits, 115 files, `+13243/-593`, carrying T4.4 and T5.1
through T5.15. `main` had not moved since 2026-09-03 and still declared `1.0.1` while the work
declared `4.2.0`. Then **fixed a correctness defect in `QuestTracker`** found by auditing the
base rather than by any rung, bumped to `4.2.1`, and added `tests/unit/quest_chain_test.gd`.

**Why (the landing).** `CONTEXT.md` records the 26-PR stack of T4.3 as history and says *"stop
stacking"*; it had recurred at 16, three days later. Every PR was CI-green and `origin/main` was
an ancestor of the tip with `rev-list tip..main` = 0, so the whole thing was one fast-forward and
the cost of landing it was zero — while the cost of not landing it was that every doc a new
session is told to trust described a base four days and fifteen versions stale.

**Why (the defect).** `evaluate()` guarded re-entrancy by RETURNING. A listener on
`quest_completed` that writes the next chapter's start flag — **the case the guard's own comment
names** — landed back in `evaluate()` mid-pass and was discarded. That is harmless only if the
running pass still reaches the newly-startable quest, and whether it does depends on where that
quest sits in `QuestDb.all()`, which is `ContentScan` insertion order and is not sorted. So a
chapter that begins when the previous one ends started, or silently did not, according to
filenames — and on two machines with different directory listings, differently.

**Connects.** `Flags.set_flag` emits `flag_changed` synchronously (`flags.gd:47`);
`_on_flag_changed` calls `evaluate()` synchronously; `quest_completed` is emitted from
`_evaluate_one` INSIDE the loop. Those three facts are the whole mechanism, and each was read
rather than assumed. The fix is a pending bit drained by the outer pass, with the pass limit
`QuestDb.count() + 2` — derived from the catalogue rather than picked, so it cannot go stale at a
game's sixtieth quest, on the same reasoning that derives the facing sectors from the facing count.

**Verified.** Ladder green on the fix: `--import` 0 `SCRIPT ERROR`/`Parse Error` lines; boot
`0 warnings, 0 errors`; suite **`2059 passed, 0 failed, 0 skipped`** with `quest_chain_test 8/8`;
all seven checkers exit 0. **PROVED RED WITH THE REAL FAILURE SHAPE (gotcha 23).** Planting the
original bare `return` back: exit 1, `2058 passed, 1 failed`, and the failure is
`FAIL the dependent scanned BEFORE its trigger started anyway — expected 1, got 0` while *"the
trigger completed"* and *"the listener fired once"* both still pass — which is the mechanism, not
a symptom. **Exactly 1 of 8 failed**, and that is the load-bearing detail: the benign scan order
passes while the defect is live, so the two order blocks are demonstrably not testing the same
thing. Control restored: exit 0.

**On the landing, verified rather than assumed.** `main` re-run after the merge:
`2051 passed, 0 failed, 0 skipped`, all seven checkers exit 0, CI green on both commits, zero
open PRs. Three of the sixteen PRs auto-closed as **Merged** (#29-#31, whose base was already
`main`); the other twelve hit the identical GitHub refusal T4.3 documented — *"There are no new
commits between base branch 'main' and head branch"* — which was TESTED on #32 rather than
assumed, so they read **Closed** with a comment pointing at #44.

**One stranded commit was deliberately NOT restored.** Three commits on `t5-11`/`t5-12` were not
in the tip, all docs-only. `3eb8e59` (T5.12's CI record) was cherry-picked, conflicting across
548 lines because T5.13-T5.15 had been appended since; resolved by hand, placing the block at the
end of T5.12's entry rather than taking either side. **`f7d57cd` was abandoned on purpose**: it
recorded the owner's turn-in-place answer as *"the NPC half lives on `NpcBrain`"*, and T5.14
shipped it via `Events.turn_requested` with `Speaker` as the asker. Restoring it would have put a
false statement into the *"do not re-litigate"* list, which is the worst place in the repository
for one. Confirmed absent from `main` before deciding.

**A trap worth recording for anyone resolving a DEVLOG conflict.**
`grep '^<<<<<<<' docs/DEVLOG.md` finds **documented example** conflict markers at line 4648 — the
`UPGRADING.md` CSV walkthrough quotes a real merge, including its markers. They are content.
Locate the genuine conflict by the marker that names the commit being applied.

**Also.** `main` now has **branch protection** requiring both `Ladder` jobs, force-pushes and
deletions blocked, admins deliberately NOT enforced so a solo owner keeps an emergency direct
push. It needed the repository to be public — both the protection and the rulesets APIs return
`403 Upgrade to GitHub Pro or make this repository public` on a free private plan — which was the
owner's decision, taken explicitly. This retires `CONTEXT.md`'s *"Not built: branch protection"*
line, which was a plan limitation rather than an oversight the whole time.

**`CONTEXT.md`'s header block was compacted from 494 lines to 35.** It had accumulated the full
narrative of T5.9 to T5.15 in a file whose second paragraph says *"Keep it short"*. Every line of
it is duplicated in this file's own per-package entries (15 of them for T5) and in the board's 12
detail sections, both checked before deleting. The compacted shape matches what the header looked
like before the stack — a short block plus one parenthetical naming the previous package.

**Unblocks.** Authored quest chains, which is the normal shape of a game with more than a handful
of quests, and which is what the flag-condition design was always supposed to make free. Also
unblocks building on `main` again at all.

**Gaps.**
- **The drain's pass bound is UNASSERTED, and the case says so out loud.** No listener this
  template can construct reaches it: a flag-written-per-flag listener recurses through the signal
  before the drain is re-entered, and a quest completes at most once, so a chain always settles.
  The bound exists so a consuming game's listener cannot hang the game. This is
  `export_test.gd`'s honesty applied to a loop bound — asserting it would have needed a probe
  that fabricates a condition the system cannot reach, which proves the probe and not the code.
- **The re-entrant call inherits the OUTER pass's `announce`.** A re-entrant call always wants
  `announce = true`, and during a save re-seed (`evaluate(false)`) it is silently downgraded.
  That is correct for the only caller that passes false — a restore must not toast progress made
  an hour ago — but it is a coincidence of there being one such caller, not a designed rule.
- **`ROADMAP.md` is untouched.** No exit criterion covers a defect fix, and inventing one to have
  something to tick would be the ticking-without-proving this project spent T5.1 undoing.
- **Not a gate.** Nothing stops the next re-entrancy guard being written as a bare `return`;
  gotcha 72 states the tell (ask whether the caller wanted a RETRY or wanted to be REFUSED) and
  that is prose, not enforcement. A gate would have to understand intent.

**CI GREEN ON `4d101b2`, PR #45, MERGEABLE / CLEAN** — both jobs pass. Full checkout
`=== 2059 passed, 0 failed, 0 skipped ===`; **stripped template
`=== 1985 passed, 0 failed, 25 skipped ===`**, and that is the number worth reading: T5.15 left
the stripped run at 1,977, so **all 8 of this row's assertions survive the demo strip.** They
were always going to — `quest_chain_test.gd` is fixtures all the way down and names no authored
content — but the whole point of quoting the stripped number is that "always going to" is a
prediction and this is the measurement. First package to land through branch protection, which
required both jobs before the merge button was live.

---

## 2026-09-07 — T5.17 · Reconciling the record with what the gates now do

**Did.** Six documentation defects, all found by the same audit that produced T5.16, all of them
prose disagreeing with shipped behaviour rather than anything broken. No code changed.

1. **`CONTEXT.md`'s "Not built" list still said the `Button` styleboxes were unbuilt** — three
   hundred lines below its own header announcing that T5.15 built them. The file's second
   paragraph says *"When it drifts from reality, fix it in the same commit as the change"*, and
   this is what happens when a package updates the top of the file and not the middle.
2. **`quest.` was missing from the prefix tables in `TEMPLATE.md` and `AUTHORING.md`.** T4.3 added
   it to `NEW_GAME.md` only, and `AUTHORING.md` routes the reader to `TEMPLATE.md` as canonical —
   so the canonical copy was the wrong one. Both now name all six content prefixes and say they
   are exactly what `check_boundary.gd` derives `CONTENT_NAMESPACES` from, which is the sentence
   that stops the two rotting apart again: the gate fails if they disagree.
3. **`keys.*` was listed as an engine prefix in three documents and has ZERO rows in the CSV.**
   The rebinding labels are `ui.action.*`. A keep-list naming content that does not exist is the
   same decay as a prune-list missing content that does — gotcha 48 in the other direction.
4. **`TEMPLATE.md` promised an `OPTIONAL` status in `SYSTEMS_INVENTORY.md` that never arrived.**
   Promised 2026-08-26, absent from the status key and from every row for eleven packages, while
   crafting was marked OPTIONAL only on the board. The status now exists and `Harvestables` — the
   one row WP-10 would fill — carries it instead of `TODO`, which is the difference between "not
   started" and "not this base's business".
5. **`AUTHORING.md`'s gate table described THREE of seven checkers.** Its command block ran four
   and its table explained three; `check_layers`, `check_signals` and `check_methods` did not
   appear anywhere in the document a consumer is told to author from, though all three fail their
   build. The block now runs seven and the table explains seven, each with the phrase that grants
   its exemption (`NO EMITTER`, `NO CALLER`) since that is the thing an author needs and cannot
   guess.
6. **`check_boundary`'s row did not mention its localization half**, added at T5.4 — the half
   that turns an unfinished prune into a build error instead of a silent ship, which is precisely
   the thing `NEW_GAME.md`'s reader most needs to know is now guarded.

**Why this is its own row and not folded into T5.16.** T5.16 is a behaviour change with a plant
and a control; this is prose with no assertions of its own. Mixing them would have put six
unverifiable edits inside a commit whose whole claim is that one specific thing was measured.
Same reasoning that splits a test file by QUESTION.

**Verified.** Suite `2059 passed, 0 failed, 0 skipped`; all seven checkers exit 0; `--import`
clean; boot `0 warnings, 0 errors`. **`docs_test.gd` earned its keep during T5.16 and is why
item 5 was findable at all**: it failed on `TESTING.md` spelling the gotcha count as
seventy-one, which is T4.4's *"three documents gave three different gotcha counts"* now gated.
It cannot gate items 1 to 4 or 6 — those are claims, not paths — which is stated here rather
than implied.

**Gaps.**
- **Nothing gates a prose claim, and nothing can.** `docs_test.gd` validates `res://` paths and
  worked-example field names. Five of these six defects were invisible to it and would have been
  invisible to any tool: a sentence saying a thing is unbuilt is well-formed whether or not it is
  true. The expiry story is a reader, which is the same answer T4.3 reached for the prune list.
- **The audit's remaining findings are on the board as candidates**, not fixed here: the
  template-default vs game-choice taxonomy, a narrative-staging seam, time above one day, the
  save loader's untested refusal branches, and the scene-level interaction test.

---

## 2026-09-07 — T5.18 · The save loader's refusals, and a path nothing can enter

**Did.** Added `tests/unit/save_recovery_test.gd` (17 assertions), corrected the Save system row
in `SYSTEMS_INVENTORY.md`, and bumped to `4.3.0`. **`save_system.gd` is byte-identical to `main`**
— `git diff` on it is empty. Also took four tags: `v2.0.0`, `v3.0.0`, `v4.0.0`, `v4.2.1`.

**Why.** Chosen over the taxonomy row, the narrative-staging seam and the interaction test, and
the reasoning is worth keeping because it inverted the plan's own ranking. The plan ranked the
taxonomy first because it decides the scope of three other rows, which is still true. It lost on
one point: **prose cannot be proved by running the engine**, and non-negotiable #1 is that nothing
is done until the engine has run it. The save loader won on four counts nothing else combines: a
false DONE in the record, the only candidate that can lose a player's data, provable by running,
and independent of the unanswered taxonomy question.

**What was actually unasserted.** `core_test.gd` owns the round trip and covered exactly one
refusal — an empty slot. A grep for `ERR_FILE_CORRUPT` across `tests/` returned NOTHING, and no
test anywhere had written a malformed save file. Six branches were carried by review: a file that
is not JSON, a missing `version`, a save from a newer build, a non-Dictionary section, a section
predating per-section versioning, and a section absent altogether.

**THE DISTINCTION THE CASE EXISTS TO PIN, and it is a policy rather than a detail.** A corrupt
ENVELOPE is refused outright; a corrupt SECTION is logged and skipped while the rest of the save
loads. That is the difference between a player losing a setting and a player losing forty hours,
and it was implemented correctly and asserted nowhere — so nothing stopped a later change
collapsing the two. Three blocks assert the skip side, and each asserts BOTH that the load returned
`OK` and that the applier was never called, because those are different claims and only the second
one answers "was the bad section skipped".

**Connects.** `_migrate` is called only from `load_from_slot`, and only when
`version != SCHEMA_VERSION`. It then refuses `from_version <= 0` and `from_version > SCHEMA_VERSION`.
**At `SCHEMA_VERSION == 1` no integer satisfies all three of not-one, above-zero and at-most-one**,
so the success path cannot be entered by any file a player can have. The `"Migrated save from v%d
to v%d"` line has never printed and cannot. That is not a defect — there are no migrations at v1,
and the comment telling a future author where to add one is correct. The defect was the RECORD:
`SYSTEMS_INVENTORY.md` said migration was DONE, which reads as *exercised* and meant *written*.
Eighth appearance of declared-and-not-reached, and the first where the thing unreached is a
control-flow path rather than a field, a signal or a method.

**AND IT EXPIRES BY ITSELF, which is the half worth copying.** The case asserts the version
boundary exhaustively — `-1`, `0`, `2` refused, `1` loads — and then PINS `SCHEMA_VERSION` to 1. A
v2 schema gives `_migrate` its first reachable success case and simultaneously makes that
exhaustive block incomplete, so the suite fails with *"SCHEMA_VERSION is still 1, so _migrate has
no reachable success path"* at exactly the moment a migration test first becomes possible. Same
shape as `check_signals.gd` failing a `NO EMITTER` exemption that acquires an emitter: the
exemption cannot rot because gaining what it excuses is itself the failure.

**Verified.** `--import` clean; boot `0 warnings, 0 errors`; suite **`2076 passed, 0 failed, 0
skipped`** with `save_recovery_test 17/17`; all seven checkers exit 0.

**PROVED RED TWICE, IN OPPOSITE DIRECTIONS (gotcha 23, and gotcha 42's reason for bothering).**
These assert EXISTING behaviour and passed first run, which proves nothing on its own.
(1) The `from_version > SCHEMA_VERSION` guard deleted from `_migrate`: exit 1, `2074 passed, 2
failed` — *"a save from a newer build is refused — expected 16, got 0"* AND *"one past the schema
is refused"*, so the exhaustiveness block caught it independently of the block written for it.
(2) The non-Dictionary section's `continue` changed to `return ERR_FILE_CORRUPT`: exit 1, `2075
passed, 1 failed` — *"a section that is not a Dictionary does not fail the load — expected 0, got
16"*. **The opposite sign is the point**: a case that had confused refuse-the-file with
skip-the-section would pass one plant and fail the other. Control after restoring: `2076 passed, 0
failed`, and `git diff src/core/save/save_system.gd` empty.

**The tags, and why four.** The base declared `4.2.1` while the newest tag was `v1.0.1`, three
MAJOR bumps back — and a MAJOR is precisely what `UPGRADING.md` tells a consuming game it must
read before merging. Tagging only the tip would leave those three reachable solely by grepping
history; now `git diff v3.0.0..v4.0.0` shows a fork what broke. Each tag was verified against
T4.3's condition before being cut: `git show <commit>:project.godot` must declare the version the
tag claims. All four did, and all four are ancestors of `main`.

**Unblocks.** Any change to the save format, which now has a regression net under its failure
modes rather than only under its happy path.

**Gaps.**
- **`SAVE_DIR` is a `const` with no redirect**, so this case writes a real slot in the developer's
  own `user://saves` and deletes it on every path, exactly as `core_test.gd` does. It is on the
  candidate list now; `save_system.gd` has 14 lines of budget left, so it is small.
- **A write that fails mid-flight is still unasserted.** `_write_atomic`'s error branch needs a
  read-only directory or a full disk, which no assertion can arrange portably. Named rather than
  implied, on `export_test.gd`'s precedent.
- **`slot_info()` parses the WHOLE save file**, and `latest_slot()` does it for all six slots on
  every menu build. Found in the same audit, untouched here because it is a performance change to
  a file with 14 lines of headroom and belongs in its own row.
- **No windowed capture.** Nothing in this package is visual: every claim is a return code or a
  call count, and the honest ladder for it ends at the suite.

**CI GREEN ON `6defa01`, PR #47, MERGEABLE / CLEAN** — both jobs pass. Full checkout
`=== 2076 passed, 0 failed, 0 skipped ===`; **stripped template
`=== 2002 passed, 0 failed, 25 skipped ===`**, and that is the number worth reading: T5.17 left
the stripped run at 1,985, so **all 17 of this row's assertions survive the demo strip.** They
were always going to — the case names no content and writes its own save files — but the reason
this project quotes the stripped number is that "always going to" is a prediction and this is the
measurement.

**One follow-up commit, and it is a small instance of the thing this row is about.** The case
header read *"five more refusal branches and both of `_migrate`'s"*, which sums to SEVEN under one
reading while this entry, the board and the PR all say six. Both counts are defensible — code
branches in `load_from_slot` against test scenarios — and that is exactly why the sentence was
wrong to carry a number at all: two documents disagreeing on one is the defect T4.4 found in the
gotcha counts, arriving in a file written the same day. It now names the set rather than counting
it, which cannot drift. `6defa01`.

## 2026-09-08 — T5.19 · Reconciling the record, and gating the part of it that is not prose

**Did.** Corrected twelve places where the record disagreed with the repository, added
`tests/unit/record_shape_test.gd` (63 assertions), and gave `version_test.gd` a third fact
(3 assertions). No production code changed — `src/` and `tools/` are byte-identical. Version
`4.3.0` → `4.3.1`, a PATCH.

**Why.** The session opened on a stale chip: it handed over candidate C ("a turn in place") as
unbuilt, with a seam decision stated as settled. Candidate C had already shipped as T5.14 — and
with a DIFFERENT seam than the chip described, because the owner's reasoning had moved on. The
whole 16-PR stack had merged, plus T5.16–T5.18, and there was nothing to build. What the check
turned up instead was that the RECORD had drifted in twelve places, one package after T5.17
existed to reconcile exactly that.

**The twelve.** `CONTEXT.md` — the file `CLAUDE.md` orders every session to read FIRST — stated
template version `2.4.0`, two majors late; said the version "stays UNTAGGED at `1.1.0`"; still
listed branch protection under "Not built" after T5.16 turned it on (verified against the GitHub
API: `Ladder (full checkout)` and `Ladder (stripped template)`, strict); said the suite had 1,798
assertions; said CI ran "seven of the eight rungs" when the ladder is twelve and CI runs ten; and
carried a **"THE NEXT PACKAGE"** paragraph describing `animation_for(moving: bool)` — T5.2's work,
long shipped. `ARCHITECTURE.md` said 1,728 assertions, 348 behind, and **"Rung 9 is the important
one"** about the visual capture, which is rung 12; the numbers shifted when checkers were inserted
and the prose did not follow. `ROADMAP.md` said "Two boxes remain" when T5.14 had ticked one, and
Phase T2's header carried no COMPLETE marker though every criterion under it is `[x]`.
`ROADMAP.md` and `SYSTEMS_INVENTORY.md` both said "86 of the 314" where `check_methods.gd` now
prints 316. `SYSTEMS_INVENTORY.md` had T5.15's `Row styles` row at **LINE 1, above the document's
own `# Systems Inventory` title** — and it was the row's ONLY copy, so `UiRowStyles` was absent
from the table it belonged in. T5.17 had **no row on the board at all**, against the board's own
closing rule 6.

**Why a gate and not a third reconcile.** T5.17's recorded gap says *"Nothing gates a prose claim,
and nothing can."* That is right about prose and wrong about two of these twelve. A file either
opens with its own title or it does not; a package either has a row or it does not. Neither
question has a reading or a tone, which is exactly why they are assertable when the sentences
around them are not. Structure is a third kind of fact, after "what a document claims exists"
(`docs_test.gd`) and "a count" (`doc_counts_test.gd`).

**Connects.** Three document gates now exist and each owns one kind of fact, because each has a
different thing behind it. Neither existing file could host this: `docs_test.gd`'s MUST NOT line
forbids asserting anything about what the documents SAY, and `doc_counts_test.gd`'s forbids
growing a second number. `CLAUDE.md` rule 4 says add a system rather than widen a boundary, so
`record_shape_test.gd` is a third case with its own. The version check went to `version_test.gd`
instead of a new file because that file's OWNS line already reads "the template's own version
**and the places that repeat it**" — `CONTEXT.md` is such a place, so this is the boundary
working rather than being widened.

**The convention that makes a version assertable** is `doc_counts_test.gd`'s, moved from a count
to a version: a **bold** semver in `CONTEXT.md` is a claim about the CURRENT version, and every
other spelling — a backticked tag, a bare number in a sentence about what an earlier package
bumped — is a record of what WAS true. There is no exception list to rot. `CONTEXT.md` had exactly
one bold semver when the rule was written; the second version claim was re-spelled to match so
that both are covered.

**Verified.** `--import` exit 0; boot `0 warnings, 0 errors`; suite **2,076 → 2,143**, 0 failed,
0 skipped, exit 0; all seven checkers exit 0. No windowed capture: nothing here is visual.

**Three plants, each the real reversion.**

| Plant | Result |
|---|---|
| The `Row styles` row put back above the title | **exit 1** — `FAIL SYSTEMS_INVENTORY.md opens with its title — expected true, got false` |
| The T5.17 board row deleted | **exit 1** — `FAIL T5.17 has a row on the board — expected true, got false` |
| `CONTEXT.md`'s bold version set back to `4.3.0` | **exit 1** — `FAIL CONTEXT.md states the declared version — expected 4.3.1, got 4.3.0` |
| Control, all three reverted | **exit 0** — 2,142 passed, which is the total BEFORE this entry existed: the log is what the board check reads, so writing T5.19 down added its own assertion and the final figure is 2,143 |

**GOTCHA 70 CAUGHT ME, ON THE GATE BUILT TO CATCH DRIFT.** Plant 3 passed the first time, exit 0.
Not because the assertion was weak but because the `sed` addressed line 143 and the version claim
was on 144, so the plant changed nothing and I nearly recorded a green run as evidence. A plant
that passes is evidence about the PLANT before it is evidence about the code — the same shape
T5.14 hit and wrote down, met again two packages later by someone who had read the entry.

**Unblocks.** A future package can trust `CONTEXT.md`'s stated version and the board's
completeness without re-deriving either.

**Gaps.**

- **The assertion count and the method count were corrected but NOT gated, and this is a real
  limit rather than an omission.** A case cannot know the suite's own final total while the suite
  is still running — the number does not exist until after the last case — and re-deriving the
  method count inside a test would duplicate `check_methods.gd`'s scan and then rot separately
  from it. Both need a CHECKER that runs the thing and reads its output, which is a rung-12 change
  and its own row. Until then those two numbers are review's problem, and they drifted by 348 and
  by 2 respectively in five packages.
- **Nothing gates the CURRENCY of a narrative.** The "THE NEXT PACKAGE" paragraph was the most
  misleading of the twelve — it sent a reader to redo shipped work — and no tool can know a
  paragraph has stopped being true. T5.17's sentence stands for exactly this case.
- **`record_shape_test.gd` fails on a fork that DELETES `docs/`**, on its "the log records
  packages to check" precondition. That is deliberate and matches `docs_test.gd` and
  `doc_counts_test.gd`, which have always behaved that way: a doc gate that passes because it
  found nothing to check is worse than no gate. The CHANGELOG entry says so in the fork's own
  terms.
- **`src/systems/debug/dev_stage.gd` is at 248 of its 250 code lines** — two lines of headroom,
  measured with `check_budgets.gd`'s own rule. The docs have called `tools/gen_placeholders.gd`
  (230, twenty spare) "the next file to split" for ten packages while the actually urgent file
  went unnamed. `CONTEXT.md` now names both in the right order. Neither was split here: doing it
  inside a documentation package would blow the one-package-per-chat rule.
- **The board's index table still skips T5.8–T5.15**, which exist only inside the candidate table.
  The new gate asserts a package is FINDABLE on the board, not that it has an index row, because
  "findable" is the property that matters and a stricter rule would have failed eight packages
  that are genuinely recorded.

## 2026-09-09 — T5.20 · Splitting the staging surface, and the gate that makes a split safe

**Did.** Moved the five staging flags that push a screen out of `src/systems/debug/dev_stage.gd`
into a new sixth debug file, `src/systems/debug/dev_screens.gd`: `--open-inventory`, `--talk=`,
`--talk-advance=`, `--open-menu=` and `--console=`, with the `_talk_advance` field and the
`_settled` / `_wait_for_area` / `_settle_stable` helpers they need. Added the `DevScreens` node to
`scenes/boot/game_root.tscn` immediately after `DevStage`. Bumped the base to `5.0.0`. Added one
gate to `tests/unit/dev_tools_test.gd` and repaired another that the move would have broken.

**Why.** `dev_stage.gd` stood at **248 of its 250** allowed code lines, so the next change to it
would have failed rung 5. Two lines is not headroom.

**The docs were pointing at the wrong file, for ten rows.** `CONTEXT.md` and the candidate list
had called `tools/gen_placeholders.gd` "the next file to split" since WP-14. It is at 230 of 250 —
**twenty** lines spare. T5.19 measured every file with `check_budgets.gd`'s own counting rule and
found `dev_stage.gd` was the one actually against the wall. That is the measurement earning its
keep: ten packages of prose had accumulated a recommendation nobody had checked with a tool.

**The seam was chosen by QUESTION, because that is what this family's precedent does.** The debug
surface has split three times already and every split cut along a question, never down the middle
of a file. `dev_capture.gd:46` records that it and `dev_probes.gd` "were one file until it hit 310
of its 250 allowed code lines", `dev_stage.gd:9` that "the budget checker refused it twice, at 310
and then at 320", and `dev_gait_shots.gd` **declined** a fourth split on the grounds that it would
have bought "a more accurate FILE NAME, which is not worth four duplicated gotchas". So the
question here had to be a real one, and it is: `dev_stage.gd` answers *what is TRUE in the world* —
where the player stands, what is in the bag, what is in hand, what a flag says, who thinks what of
them — and `dev_screens.gd` answers *what is DRAWN OVER it*. Every flag that moved ends in a
`UiRoot.open()`; not one that stayed does.

**And the seam is a dependency fact, which is what distinguishes it from a filing preference.**
Those five flags were the only staging in the file that named the `ui` layer at all — `UiRoot`,
`ScreenKeys`, `InventoryScreen`, `DialogueScreen`, `DebugConsoleScreen`. What is left reaches
`Director`, `Flags`, `Standing`, `Equipment` and the interaction sensor and now names no screen
anywhere: `grep` for those five symbols in `dev_stage.gd` returns one header comment and no code.
The upward references that `check_layers.gd` exempts this directory for are now in one file
instead of spread across two.

**One dividend worth naming.** Gotcha 35's rule — any staging flag that puts something on SCREEN
waits for a SETTLED area, not merely for an area — was stated in a header shared with eleven flags
that do not draw, which is exactly how `--stand-by` went four packages without following it (T4.2,
and it made every object in an authored area unphotographable). In `dev_screens.gd` that rule is
the file's whole subject, so a seventh screen flag inherits it by being in the right place rather
than by somebody remembering.

**Verified.** `--headless --import` first, per gotcha 53, and again after the A/B checkout below.

- `--check-only` on all three changed scripts: the only errors are `Identifier not found` for
  `Director` and `Flags`, which is the expected autoload behaviour CLAUDE.md documents.
- `--headless --quit-after 30`: *"Session ended after 0.6s — 0 warnings, 0 errors"*.
- Suite: **2,143 → 2,148 passed, 0 failed, 0 skipped**; `dev_tools_test` 43 → 46.
  **Five, not the three this package wrote**, and the other two are computed plans doing their
  job rather than a miscount: `record_shape_test` gained one for T5.20's own DEVLOG heading
  needing a board row, and `docs_test` gained one for `dev_screens.gd` — a new `res://` path the
  documents now name, which that case checks actually exists. Both are exactly the "adding a
  document or a package should not mean editing a number" design those two files state.
- All seven checkers exit 0. `dev_stage.gd` **175 / 250**, `dev_screens.gd` **102 / 250**.
  163 files, 15,274 code lines, 0 warnings, 0 violations.

**THE EVIDENCE FOR A REFACTOR IS THAT BEHAVIOUR DID NOT CHANGE, and `check_budgets.gd` exiting 0
proves only the line count.** Five invocations were logged before the split and re-run after it,
and the staging output is byte-identical in all five — `diff` reports no difference:

```
--new-game --give=item/rose_key,item/rose_petal:3 --open-inventory
--new-game --goto=lantern_hall --open-menu=map
--new-game --talk=talk/gardener --talk-advance=2
--new-game --console="time 18:40;flag met/someone:true"
--new-game --give=item/brass_lantern --equip=item/brass_lantern --flag=count/lit:3 \
    --standing=keeper:40 --npc-settle=30
```

The first two are the ones that matter, because they are the CROSS-FILE orderings: `--give` fills
the bag that `--open-inventory` photographs, and `--goto` races the `--open-menu` that
`_settle_stable` exists to protect. Both still log the same thing in the same order.

**A sixth pair was run for the one deliberate difference.** `dev_screens.gd` reads `_fresh_game`
in a pre-pass — `arguments.has("--new-game")` — where `dev_stage.gd` sets it in the dispatch loop.
Those are equivalent because every reader awaits at least one frame before reading it, by which
point the loop has finished; but "equivalent by reasoning" is what this project distrusts, so it
was measured. `--open-inventory --new-game` and `--open-menu=pause,settings --new-game`, both with
the screen flag typed BEFORE `--new-game`, were captured against the pre-split code by committing
the work and checking out `origin/claude/t5-19-record-gate` over it. Identical.

**Planted, in both directions.**

1. **The new gate.** Left an `--open-menu=` branch behind in `dev_stage.gd`'s parser, which is
   precisely the defect a split like this produces: `FAIL the only flag two debug nodes both read
   is the one that is meant to be — expected ["--new-game"], got ["--new-game", "--open-menu="]`.
   Exit 1 against an exit-0 control. **This is the failure mode nothing else would have caught** —
   both files parse, both budgets pass, both nodes exist, `check_methods` is happy, and one
   `--open-menu=map` simply dispatches twice. Gotcha 2's family in the shape a split makes.
2. **The repaired gate.** `SETTLE_SITES` in `dev_tools_test.gd` scanned three function signatures
   against one hard-coded `STAGE_PATH`, and two of those three functions moved. Pointing
   `_console`'s row back at `dev_stage.gd` fails TWO assertions — "is present" first, then the
   settle guard — because `_function_body` returns `""` for a function that is not in the file.
   So the list could not have rotted silently, and the row now carries its own path, the same
   shape `GATE_SITES` above it already used. **The first draft of that comment claimed a bare list
   "would have gone GREEN", and the plant proved it goes RED**; the comment was corrected to say
   what actually happens rather than what read well.

**Also fixed, in passing.** An orphaned `##` block in `dev_stage.gd` — *"Spawn a crowd and
measure..."* — documented a function deleted in an earlier split and attached to nothing at all.
Costs no budget, since comments do not count, and misleads every reader. Removed. Also gave
`_distance_to_intent` the two blank lines every other function has; it had been butted directly
against `_press_interact`'s last line.

**Connects.** Third split in this family and the second to be forced by the checker rather than
chosen. `dev_commands.gd` (WP-14b) was the first, and its inventory row records that
`dev_stage.gd` "had been sitting at exactly 250/250 code lines" then too — so this file has now
hit its ceiling twice, which is a fact about how much staging a demo needs.

**Unblocks.** `dev_stage.gd` has 75 lines of headroom and `dev_screens.gd` 148, so a new staging
flag no longer needs a package of its own to make room for it.

**AND ONE WINDOWED CAPTURE, BECAUSE THE SPLIT PUT THE SHUTTER AND THE STATE IN DIFFERENT NODES.**
The log proves both `_parse_arguments` bodies ran; it cannot prove the screen reached a screen,
and gotcha 2 is that `--headless` shades nothing. So the cross-file case was photographed:

```
--resolution 960x540 --quit-after 120 -- --new-game \
    --give=item/rose_key,item/rose_petal:3 --open-inventory \
    --shot=<path> --shot-frame=100 --time=18:40 --freeze-time
```

*"Captured 960x540 … camera at (0.0, 8.498142, 14.66422)"*, `0 warnings, 0 errors`, and the image
shows the Satchel open over a lit courtyard at 18:40 Dusk with **Rose Key x1** under Key Items and
**Rose Petal x3** under Materials. Two nodes, one frame: `DevStage` filled the bag and `DevScreens`
drew the screen that lists it. That is the claim the log could not make.

**Gaps.**
- **`--stand-by`, `--cycle` and `--interact` were not re-run**, because the demo node names they
  need were not to hand and the flags did not move. They share `_wait_for_area` and
  `_settle_stable` with what did move, and those helpers are byte-identical in both files.
- **The tightest file is now `src/systems/scene_director/director.gd` at 187 of 190** — three
  lines, and on an override WP-14 already raised once. That is a smaller margin than the one this
  package existed to fix, but it is not the same problem: raising an override is a decision about
  whether a concern deserves more room, and splitting a scene director is not a mechanical move.
  `CONTEXT.md` now names it first and says so. `gen_placeholders.gd` stays on the list at 230.

## 2026-09-09 — T5.21 · A scene-level interaction test, and the defect it found

**Did.** Wrote `tests/unit/selection_test.gd` — 24 assertions on `InteractionSensor`'s selection,
driven with real geometry — and fixed the tie-break defect it found on its first run. Extracted
`InteractionSensor.cycle()` as a public method so the override could be asserted at all. Bumped
the base to `5.1.0`. Recorded gotcha 73.

**AND REBASED, WHICH IS HALF OF WHAT THIS ENTRY RECORDS.** The package was authored against `main`
while T5.19 and T5.20 were both open, so it first shipped as `4.4.0` on a tree that contained
neither. It now sits on top of both as `5.1.0`, a MINOR over T5.20's `5.0.0`. **Not one line of
its production or test code moved in the rebase** — all five conflicts were record: `CONTEXT.md`,
`CHANGELOG.md`, this file, the board, and `project.godot`'s version. What DID have to change is
every number the package stated, because each was measured against `main`: the suite delta was
`2,076 → 2,100` and is `2,148 → 2,173`, and `check_budgets` read `162 files, 15344 code lines` and
reads `164 files, 15457`.

**The delta is 25 for a file of 24 assertions, and the extra one is not a miscount.**
`record_shape_test.gd` computes its plan as `docs + packages + 2` and asserts every package the
log records has a row on the board; adding T5.21 to this file adds one package, so it adds one
assertion. `version_test.gd` plans `28 + <bold semvers in CONTEXT.md>` and stayed at 30, because
both bold semvers were rewritten rather than added to. A package that touches the record can
therefore grow the total by more than the cases it writes, and the arithmetic has to be shown
rather than asserted.

**The lesson is cheap to state and was expensive to skip: run `gh pr list --state open` before
branching.** A stack is invisible from `main` — nothing in a clean checkout of `main` says that
two packages are in flight above it, and the cost of finding out late was this reconcile.

**Why.** `interaction_test.gd`'s MUST NOT line has read since WP-02 that the sensor's ranking
*"needs real geometry and belongs in a scene-level test"*. That was an accurate note about a test
nobody wrote, and four phases went by. The consequence was that the rule every interactable rests
on — the one the sensor's own header calls the actual problem it solves, because *"detection is
trivial; selection is not"* — had no assertion anywhere in a suite of 2,148, and that `Speaker`
and `Readable`, two of the eleven prefabs `AUTHORING.md` tells a consuming game to place, had no
scene-level assertions of any kind. `CONTEXT.md`'s own next-package list called this the strongest
remaining row, in its words *"a false-confidence gap that a run can close."* It was.

**Gotcha 54's shape at the top of the interaction stack.** `interaction_test.gd` proves what an
object does once it is chosen; `turn_test.gd` proves the turn once it is. Between them sat the
decision neither one makes, with a green assertion on either side — which is exactly the
configuration gotcha 54 warns reads as coverage of the whole path.

**THE DEFECT — GOTCHA 73.** `_select()` broke a scoring tie with `a.name < b.name`, under a
comment promising *"ties are broken by node name so the order is stable frame to frame rather than
dependent on physics callback order."* `Node.name` is a `StringName`, and `<` on two of those
compares their **interned addresses, not their text.** Measured both ways in one run, same pair:

```
TIE StringName Z<A=true A<Z=false | String Z<A=false A<Z=true
```

So ties were ordered by whichever name the engine interned first — script and scene load order.
**The comment was not wrong, only half true, and that is why it survived eight rungs.** An
interned address does not move while the node lives, so the order genuinely was stable within a
run and the flicker the comment worried about never happened. What was false is that it was ever
the NAME: an author numbering two overlapping objects `sign_a` and `sign_b` to choose between them
was ignored, and because intern order is load order the same two objects could tie differently
when reached another way. 2,148 assertions were green over it because the demo has no two
interactables at an exact tie. Fixed with one cast, `String(a.name) < String(b.name)`.

**And the first probe said the language was innocent.** A standalone `--script` probe made two
nodes, compared their names, printed alphabetical order — so the failing assertion looked like a
broken fixture, and I was one step from recording "StringName compares alphabetically" as a
finding. It agreed by coincidence: with only those two names interned, their addresses happened to
fall in alphabetical order. Re-measured inside the suite, both comparisons side by side, and they
disagreed. **This is gotcha 70 turned around** — there a plant PASSED and was evidence about the
plant; here a probe passed and was evidence about the probe. The tell is identical in both: a
result contradicting a measurement taken somewhere else is a question about the two contexts
before it is an answer about the code. A probe of an ORDERING has to run in the context whose
order is in question, because the property belongs to the process, not to the two values.

**`cycle()`, and why the test could not press Tab.** The cycle lived inline in `_handle_input`
behind `Input.is_action_just_pressed`. Two facts, measured rather than assumed, with a throwaway
case in `CASES` that was then removed:

- `Input.parse_input_event` is **buffered** until a main-loop flush that never comes mid-run — the
  action reads back `pressed=false` immediately after the call, so a faked press does nothing;
- `Input.action_press` **does** land, but the process-frame counter never advances inside one
  `_ready()`, so the action then reads `is_action_just_pressed() == true` for the **rest of the
  run**. `turn_test.gd` also drives a sensor with more than one candidate, so that stuck key would
  have cycled its selection and corrupted a case I did not write.

So the override was genuinely unassertable through input, which is why the note in
`interaction_test.gd` had survived. It is now a public `cycle()` returning false when there is
nowhere to go — `_handle_input` calls it on the keypress, so `check_methods.gd` is satisfied by a
real game caller and not by an exemption. Same reasoning that already made `is_suspended()`
public, in that method's own words: so a test can assert the hand-over without faking input. The
**binding** is still proved windowed by `dev_stage.gd --cycle`, and that limit is named in the
file rather than left implied.

**Connects.** `interaction_test.gd` (its MUST NOT line now points here instead of asking for it);
`turn_test.gd`, whose hand-driven sensor is the precedent this file follows and whose stillness
gate is deliberately not re-asserted; `InteractionSensor._select`/`cycle`; `Readable` and
`Speaker`; `AUTHORING.md`'s prefab list; gotchas 8, 54, 56, 70 and now 73.

**Verified.** Twelve rungs, seven checkers, all exit 0.

- `--headless --import` → exit 0, run first and again after the source edits (gotcha 53).
- `--check-only` on both changed files → only `Identifier not found: Events`, which is gotcha 1.
- `--headless --quit-after 30` → `Session ended after 0.5s — 0 warnings, 0 errors`.
- Suite → **`2173 passed, 0 failed, 0 skipped`**, exit 0. Was `2148 passed, 0 failed` on the
  branch this sits on, and `2076` on `main`, where the package was first written.
- `check_budgets` (`164 files, 15457 code lines, 0 warnings, 0 violations`), `check_content`,
  `check_boundary`, `check_strings`, `check_layers`, `check_signals`, `check_methods` → all
  exit 0. `interaction_sensor.gd` is 173 → 177 of its 250; `selection_test.gd` is 178.
- Windowed capture at `960x540`, `--time=18:40 --freeze-time` → `0 warnings, 0 errors`, and the
  prompt in frame reads a real selection at dusk. Not load-bearing; nothing here is visual.

**The plants — five, each failing a DIFFERENT set**, which is what says they are not one assertion
five times. Every one confirmed to have genuinely modified the source before its run was trusted,
per gotcha 70, and every one reverted to `2173 passed, 0 failed` with the file byte-identical:

| Plant | Exit | Failed |
|---|---|---|
| tie-break reverted to `a.name < b.name` (the real defect) | **1** | 3 |
| authored-priority term deleted from `_score` | **1** | 1 |
| facing term deleted from `_score` | **1** | 1 |
| `_select` returns `ranked[0]`, ignoring the cycle offset | **1** | 4 |
| `cycle()`'s lone-candidate guard removed | **1** | 1 |
| **none — the shipped tree** | **0** | 0 |

**The tie-break plant was re-run after the rebase**, because a plant verified against one base is
evidence about that base. On this tree it fails the same three assertions and exits 1 —
*"the earlier name wins a dead tie — expected true, got false"*, *"and not the one that was handed
over first — expected false, got true"*, and *"it is the same object on the next frame, which is
what stable means"* — and the restored file returns `2173 passed, 0 failed` while being
byte-identical to `HEAD`. The other four plants stand on their original run; the source they
target did not move in the rebase.
The priority plant fails only *"an authored priority takes the prompt from a nearer object"* and
not its partner, which is correct: the partner asserts the nearer object wins once the priority is
gone, and with the term deleted that is still true. The cycle-offset plant fails 4 including the
prefab-order assertion and **not** *"cycling past the end comes back round to the first"* — also
correct, because `ranked[0]` and the wrap coincide. Both are cases where the plant fails less than
it might and the reason is the assertion being specific rather than weak.

**Unblocks.** The remaining rows on `CONTEXT.md`'s list are unchanged; this one is off it, and the
list is now four rows shorter than the audit left it. A redirectable `SAVE_DIR` is the next
cheapest honest slice and now has the strongest claim, since the taxonomy row above it is prose
and cannot be proved by running the engine — the same reasoning that put T5.18 and this row ahead
of it twice.

**Gaps, named rather than left implied.**
- **`ROADMAP.md` records T5.15 and then T5.21, and nothing between.** T5.16 through T5.20 have
  board rows and DEVLOG entries but no roadmap entry, so this package's own entry landed where
  T5.16's should be. That predates this row and belongs to whoever reconciles the record next —
  `record_shape_test.gd` gates board rows against the log, and deliberately does not gate the
  roadmap, so nothing goes red over it. Naming it here is the only thing that keeps it findable.

- **The Tab BINDING is not in the suite and cannot be**, for the two measured input facts above.
  `cycle()` is asserted; that Tab reaches it is proved windowed only.
- **`_score`'s weights are not asserted as numbers**, deliberately. The assertions are about which
  object wins, not about `priority_weight` being 100.0 — a consuming game may retune all three
  `@export`s, and a case pinning them would fail a game that did nothing wrong.
- **Physics detection is still bypassed.** Candidates arrive by emitting `area_entered`, as in
  `turn_test.gd`; that the collision shapes actually overlap at those distances is a separate
  claim, and `dev_probes.gd --stand-by` is what exercises it.
- **`Readable.has_been_read()` remains `NO CALLER`** by design, and this package did not change
  that — the read side belongs to a consuming game.
- **Nine other prefabs still have no scene-level assertions.** This row covered the two the
  `CONTEXT.md` line named; `Gate`, `Lever`, `Chest`, `Pickup`, `AreaDoor`, `RestPoint`,
  `ClimbPoint`, `TriggerVolume` and `PathAction` are reached by `interaction_test.gd` and others
  through direct calls, which is a weaker claim than this file makes about the two it covers.

**CI ON THE REBASED BRANCH, recorded rather than assumed.** Run
[`34282187912`](https://github.com/Raiyan-Bashar-29/HD-2D-game-base-non-combat-/actions/runs/34282187912),
both jobs green on PR #50 now that it targets T5.20's branch at `5.1.0`:

- **Ladder (full checkout)** — `2173 passed, 0 failed, 0 skipped`, matching the local run exactly.
- **Ladder (stripped template)** — `2099 passed, 0 failed, 25 skipped`. The file survives the
  deletion `docs/NEW_GAME.md` tells a consuming game to perform on day one: the two prefabs it
  instances, `sign.tscn` and `speaker.tscn`, are template objects rather than demo content — the
  same distinction `interaction_test.gd` already relies on for `gate.tscn` and `lever.tscn` — and
  the conversation the `Speaker` names comes from `FixtureContent`, not from `data/`. **The gate
  that actually proves that is `check_boundary.gd`, which passes**, not the stripped total: CI logs
  at INFO and the per-case `--- selection_test: 24/24 ---` line is DEBUG, so the stripped job's
  totals alone do not isolate this file's contribution. The pre-rebase record claimed they did,
  which was one inference too far, and the claim is narrowed here rather than restated.

**The pre-rebase CI run was [`34262856018`](https://github.com/Raiyan-Bashar-29/HD-2D-game-base-non-combat-/actions/runs/34262856018)**
— `2100` full, `2026` stripped, green on `main` at `4.4.0`. It is kept because it is what the
package was first accepted on, and labelled because it no longer describes this tree.

## 2026-09-09 — T5.22 · A redirectable `SAVE_DIR`

**Did.** Turned `SaveSystem.SAVE_DIR` from a `const` into `const DEFAULT_SAVE_DIR` plus a settable
`var save_dir`, added `tests/framework/save_fixture.gd` on `fixtures.gd`'s shape, wired
`SaveFixture.deactivate()` into `test_runner.gd`'s unconditional per-case teardown, pointed
`save_recovery_test.gd` and `core_test.gd`'s round trip at the scratch directory, and wrote
`tests/unit/save_dir_test.gd` — 18 assertions on where the store writes. `5.2.0`, a MINOR.

**Why.** `fixtures.gd` repoints five content roots under `user://test_fixtures` so a run reads
fixture content instead of the game's. The save store was the sixth root and the only one left
out, because its directory was a `const` with no redirect. So two cases wrote real slots into
whatever `user://saves` resolves to on the machine running the suite: `save_recovery_test.gd`,
whose entire purpose is writing MALFORMED save files, and `core_test.gd`'s round trip.

T5.18 recorded this and left it, correctly — it was a seam, not a defect. Both cases delete what
they write on every path including the failing ones. **But "it cleans up after itself" is not the
same as "it was never there."** The run that fails to clean up is by definition the run that
crashed, which is exactly the run you least want leaving a corrupt `slot_00.json` where a person's
real game reads it. And the slot numbers the suite picks — `MAX_SLOTS - 1`, and a slot of its own
— are slot numbers a player may have filled.

**The budget was checked before the row was started, not after.** `save_system.gd` carries an
OVERRIDE of 180 rather than the 250 default and stood at **166**. CONTEXT's claim of 14 spare was
verified with `check_budgets.gd` first, because the row's own justification was that it is
"genuinely small" and a design that did not fit would have been a signal — `check_budgets.gd`'s
header forbids raising an override to make a violation go away. The redirect cost six lines: the
file is now **172 of 180**.

**Public rather than test-only, and that was a decision.** The alternative was a test-only
injection point on `SaveSystem`. `fixtures.gd`'s own header already argues that case and refuses
it — engine code carrying a backdoor that exists for the suite and for nothing else — and the
same seam is one a game legitimately wants: a portable build writing its saves beside its
executable rather than into `user://`. So the property is public, documented as such, and its
setter calls `_ensure_dir()` so that assigning creates the directory. `_ready()` calls the same
helper, so boot and redirect share one path instead of two that can drift.

**Connects.** `tests/framework/fixtures.gd` — this is that file's discipline applied to the sixth
root, including the reason its `deactivate()` is unconditional, quoted rather than reinvented.
`save_recovery_test.gd` and `core_test.gd` are the two consumers. T5.18 named the seam.

**Verified.**

| Rung | Result |
|---|---|
| `--headless --check-only` on the three changed/new scripts | only `Identifier not found: Log` / `SaveSystem`, the documented autoload gotcha |
| `--headless --import` | exit 0 |
| `--headless --quit-after 30` | `0 warnings, 0 errors` |
| suite | **2,192 passed, 0 failed, 0 skipped**, exit 0 |
| `check_budgets` | 166 files, 15,552 code lines, 0 violations — `save_system.gd` 172 / 180 |
| `check_content` `check_boundary` `check_strings` `check_layers` `check_signals` `check_methods` | each exit 0 |
| windowed capture, 960x540, 18:40 frozen | rendered, `0 warnings, 0 errors` |

**Plants.**

| Plant | Fails | Exit |
|---|---|---|
| control | 0 of 2,192 | **0** |
| `slot_path` alone back to the constant | 17 | **1** |
| every use of `save_dir` back to the constant — the full reversion | 4 | **1** |
| `SaveFixture.deactivate()` removed from `test_runner.gd` | 3 | **1** |

**AND THE FIRST VERSION OF THE LOAD-BEARING CASE PASSED THE FULL REVERSION.** The assertion was
that the stand-in directory's file is byte-for-byte what it was before the redirected write. With
every use of `save_dir` reverted to the constant — an edit confirmed applied by diffing the
source, so not gotcha 70 — that assertion PASSED. Both writes landed on the same path inside the
same second, and the only fields that vary between two saves are `saved_utc`, which is
second-resolution, and `playtime_seconds`, which `snappedf` rounds to a tenth. The overwrite was
byte-identical to what it overwrote. The two saves now carry different markers through the probe's
section, and the case asserts the earlier file still carries the first and does NOT carry the
second; the same plant fails 4. **Gotcha 74**, recorded — gotcha 70 says a plant that passes is
evidence about the plant, and 74 is the next turn: a plant that passes against an edit you have
confirmed applied is evidence about the CASE.

The first plant is recorded because it is instructive rather than good. Reverting only `slot_path`
makes the write FAIL rather than land in the wrong place — `_write_atomic` still opens the
redirected directory, so the rename has nowhere to go — which is a louder and different failure
from the one this row is about. It is kept in the table so the full reversion's four failures are
read as the honest number.

**Unblocks.** Nothing was blocked on this. The suite no longer touches `user://saves` at all,
which was verified directly: the real directory was emptied before a run and held zero files
after it.

**Gaps.**
- **`slot_info()` still parses the WHOLE save file**, and `latest_slot()` does it for six slots on
  every menu build. T5.18 named this and left it; so does this row, for the same reason — it is a
  performance change to a file with eight lines of budget spare, and it deserves its own.
- **`save_dir` is not saved or restored across runs.** A game that repoints it must do so before
  `SaveSystem` is asked for anything, and nothing enforces that ordering. Documented in the
  property's own comment, not gated — a gate would have to know what a game's boot order is.
- **The windowed capture proves nothing about this row.** It was run and is green, but every claim
  here is a path, a return code or a file's contents. Recorded so the ladder is not read as
  stronger evidence than it is.

**CI, recorded rather than assumed.** Run
[`34286344135`](https://github.com/Raiyan-Bashar-29/HD-2D-game-base-non-combat-/actions/runs/34286344135),
both jobs green on PR #53:

- **Ladder (full checkout)** — `2192 passed, 0 failed, 0 skipped`, matching the local run exactly.
- **Ladder (stripped template)** — `2118 passed, 0 failed, 25 skipped`, the standing baseline. The
  file survives the deletion `docs/NEW_GAME.md` tells a consuming game to perform on day one, and
  it should: nothing in `save_dir_test.gd` or `save_fixture.gd` names authored content, which is
  what `check_boundary.gd` passing actually gates. The stripped total alone would not isolate this
  file's contribution — CI logs at INFO and the per-case line is DEBUG — so the boundary checker is
  the claim and the total is not.

**The package is numbered T5.22 rather than T5.21**, and the reason belongs in the record. A
parallel session took T5.21 for the scene-level interaction test while this row was in flight, and
the two sessions also produced competing PRs carrying the same tree: both had independently
renumbered that test to `5.1.0`, and `src/`, `tests/` and `project.godot` were byte-identical
between them, so the duplicate was closed and the branch with the richer documentation kept. The
transferable half is the same one T5.21's own DEVLOG entry drew from the other direction: **a
stack is invisible from `main`**, so run `gh pr list --state open` before branching, and prefer
one package in flight at a time.

---

## 2026-09-09 — T5.23 · A second idle block, and the chooser that was the actual package

**Did:**
- `src/content/art/sprite_sheet_layout.gd` gained `idle_break_row` (-1 = none) and
  `idle_break_after` (0.0 = none), plus `has_idle_break()`, `idle_break_animation()` and a
  `_idle_break_problems()` helper split out of `problems()`. 62 -> 86 code lines.
- `src/gameplay/character/character_visual.gd` gained `_dwell` and `_breaking`, a `_stand(delta)`
  that absorbed the old non-moving branch, and `_advance` now RETURNS whether the cycle wrapped.
  131 -> 151.
- `tools/gen_placeholders.gd`: `ANIMATIONS` 3 -> 4, an `IDLE_BREAK_BLOCK`, a fourth tint and
  swing, and a `BREAK_ARM_LIFT` applied on the block's late cells only. 230 -> 234.
- `assets/placeholder/character_layout.tres`: `animations = 4`, `idle_break_row = 3`,
  `idle_break_after = 3.0`. `character_placeholder.png` regenerated at 16 rows.
  `character_alt_layout.tres` deliberately UNCHANGED.
- `src/systems/debug/dev_gait_shots.gd` gained a fourth pass, `--idle-shots=<dir>`. 142 -> 197.
- `tests/unit/idle_break_test.gd`, 26 assertions, registered in `test_runner.gd`.
- Version 5.2.0 -> 5.3.0 in `project.godot`, `CHANGELOG.md` and both bold semvers in
  `CONTEXT.md`. Board row, `SYSTEMS_INVENTORY.md`, `ROADMAP.md` and `ART_CONTRACT.md` updated.

**Why.** The last unticked Phase T5 exit criterion, and the one thing worth carrying out of it is
that **the criterion did not name the work**. It read "more than one idle", which sounds like a
missing BLOCK — and the block was never missing. `SpriteSheetLayout` has been able to address 32
animations since T2.1 and `frame_index` could draw any of them, so a sheet could always have
carried a second idle. What was missing is that every block in this template is selected by a
`GameEnums.MoveState`, and standing still is ONE state, so nothing would ever ask for a second
one. The gap was a chooser, and a chooser is a seam decision — which is the same shape T5.14 found
in "a turn in place", the other long-open box in this phase. Two of the phase's last three boxes
were seam decisions wearing the clothes of animation work.

**The chooser is dwell time, with its threshold on the SHEET, and the argument is the two MUST NOT
lines rather than taste.** The candidates were dwell, weather, a schedule and an area tag. The
last three each need an autoload — `Weather`, `Clock`, `Flags` — and `sprite_sheet_layout.gd` may
not touch one at all (`tools/` loads content classes under `--script`, where autoload identifiers
do not resolve, so a single `Log` call there breaks a build gate), while `character_visual.gd` is
forbidden from the other side: it is TOLD a velocity and a state, and it draws. Dwell is the one
trigger derivable from what the visual is ALREADY handed every frame, so it is the only one of the
four that needs no new dependency anywhere. **And nothing is given up by choosing it**: a game
that wants a rain idle or a night idle pushes a MoveState, or swaps the layout resource, and
neither needs a line of base code. That is written into the field's own doc block so the next
session does not re-litigate it.

**Both fields or neither, and `problems()` says so.** A row with no delay is a block nothing ever
plays; a delay with no row is a timer that fires nothing; a break pointing at `idle_row` is a
no-op that looks configured. All three are gotcha 38's shape — in range, kept by the loader,
plausible on screen, and the authored block never once shown — so all three are reported.
`has_idle_break()` requires both halves for a concrete reason and not for symmetry: its one
consumer compares a dwell against `idle_break_after`, so a row with a threshold of zero would
break on the very first frame the character stood still.

**`_advance` returns a bool now, and that is the smallest change that carries a real decision.** A
break plays ONCE, so something has to notice the end of it, and the only code that knows is the
loop that wrapped the frame. Every other caller discards the answer, which `project.godot` permits
deliberately — `return_value_discarded` is the single warning in the static-enforcement block set
to 0 rather than 2, and this is the first place in the project that uses that latitude.

**The break outranks `_idle_animates()` rather than nesting inside it**, and getting that the
other way round would have been the quiet bug: a sheet may legally have `idle_row == walk_row`,
which every sheet authored before T2.1 does, and a game that gives such a sheet a fidget still
wants the fidget. So the break is tested first and the held pose is what happens only when there
is neither a distinct idle nor a break running.

**Connects.** `SpriteSheetLayout` -> `CharacterVisual` -> `Sprite3D.frame`, the same path T5.2 and
T5.3 built, with one branch added at the point where "not moving" was previously a two-way
choice. No signal, no autoload, no new dependency in either direction — `check_layers.gd` sees
nothing new, and `check_methods.gd` finds a caller for both new public methods inside
`character_visual.gd`. `dev_gait_shots.gd` gained a fourth flag rather than a fifth debug file,
which keeps `dev_tools_test.gd`'s "every debug script that reads the command line has a node"
count at 6 and its shared-flag set at exactly `--new-game`.

**Verified.**
- `--headless --import` before anything, and again after the sheet was regenerated (gotcha 53 —
  a sprite sheet IS an asset, and this row changed the texture's size).
- `--headless --check-only --script` on all four changed `.gd` files. `character_visual.gd`
  reports `Identifier not found: Events` at its `turn_requested.connect` line, which is the
  documented expected failure; the other three are clean.
- `--headless --quit-after 30` -> `Session ended after 0.6s — 0 warnings, 0 errors`.
- `--headless res://tests/test_runner.tscn --quit-after 400` -> `2221 passed, 0 failed,
  0 skipped`, exit 0. **The delta is +29 on 2,192, and it is +26 +2 +1 rather than one
  number** — measured by running the suite once with the docs reverted and once with them
  in place, rather than predicted:
  - **+26** is `idle_break_test.gd`'s own plan.
  - **+2** is `docs_test.gd`, 117 -> 119. Its plan is `paths + fields + 2`, and adding
    `idle_break_row` and `idle_break_after` to `ART_CONTRACT.md`'s worked example makes
    that file assert both fields exist on the class. Worth knowing before writing a doc:
    **a worked example in `docs/` is gated, so extending one grows the suite.** The first
    version of this entry predicted +27 and was wrong by exactly these two.
  - **+1** is `record_shape_test.gd`, 67 -> 68. Its plan is `docs + packages + 2` and this
    entry's own heading is the new package.
  - **+0** from `version_test.gd`, which stayed at 30: its plan is
    `28 + <bold semvers in CONTEXT.md>`, and both semvers were rewritten in place rather
    than added to. `doc_counts_test.gd` also stayed at 6.
- All seven checkers exit 0: `check_budgets`, `check_content`, `check_boundary`, `check_strings`,
  `check_layers`, `check_signals`, `check_methods`.
- **The windowed capture, because `--headless` shades nothing.**
  `--resolution 960x540 --quit-after 900 -- --new-game --idle-shots=<dir> --freeze-time
  --time=18:40`. Note `--quit-after` is FRAMES: the first attempt used 90, which is 1.5s, and the
  pass needs eight seconds. Blocks seen, sampled six times a second:
  `0x12, 3x8, 0x18, 3x8, 0x2`. **The break ran 8 samples = 1.33s, which is 4 cells at 3fps
  exactly, and the gap between the two breaks was 18 samples = 3.0s — the authored
  `idle_break_after`, measured from the END of the previous break.** That is the restart decision
  confirmed windowed and independently of the suite. Crops: `idle_block_0_early` vs
  `idle_block_0_late` differ by 0.0949 of the crop, `idle_block_3_early` vs `idle_block_3_late` by
  0.1406, and `idle_block_0_early` vs `idle_block_3_early` by **0.6184** — four to six times
  either block's own internal cycle.

**Seven plants, seven different failure sets**, which is what says they are not one assertion
seven times: the break never starting fails 4; the break looping instead of ending fails 2; moving
not cancelling fails 2; the dwell reset moved to the break's START instead of its end fails 2;
`idle_break_animation()` falling back to row 0 instead of the idle block fails 1;
`has_idle_break()` dropping its delay half fails 1; and the three half-configured `problems()`
branches removed fails 3.

**GOTCHA 75 — A NEW ASSERTION PASSED ITS OWN PLANT, BY COINCIDENCE OF ITS OWN TIMING.** The
"interrupted standing does not accumulate into a break" case originally stood for `DWELL - 0.3`,
took one walking frame, then stood `DWELL - 0.3` again — 3.4s in total. Under the plant that never
resets the dwell on movement, the break duly STARTED 0.3s into the second stand, and then finished
1.33s later, still inside that stand — so the case read the idle block and passed, over the exact
defect it was written for. Gotcha 70's family, and the second time in two packages that a plant
came back green for a reason that was not innocence (T5.22's was byte-identical files written in
the same second). **The fix is timing, not logic**: the second stand is now `DWELL - 1.0`, short
enough that a wrongly-started break is still on screen when the block is read, and the plant now
fails 2 assertions instead of 1. The generalisable rule is narrower than "plant everything": an
assertion about a TRANSIENT state has to be read while that state would still be showing, and a
transient whose duration is derived from other data — here 4 cells at 3fps — needs that duration
written down where the case can see it. `BREAK_SECONDS` in that file is derived from `FRAMES` and
the default `idle_fps` for the same reason, after a first draft typed 2.0 and failed for arithmetic
rather than for a defect.

**Unblocks.** Nothing was waiting on this. It closes Phase T5's last exit criterion, so the phase
has no unticked box left.

**Gaps.**
- **`docs/ROADMAP.md` still records T5.15 and then T5.21, with nothing for T5.16 through T5.20.**
  T5.21 recorded this and it is still true; this entry adds T5.23 to that file without closing the
  run of five. Nothing gates the roadmap's completeness so nothing is red. `CONTEXT.md`'s
  next-package list now names reconciling it as the strongest row, which is a promotion from the
  footnote it was.
- **The arm lift is verified numerically and only partly visually.** The capture caught the player
  at column 2, a side view, and `_character_cell` draws no far arm on a side view — so the raised
  arm changes the outline on the front and three-quarter facings and is a same-silhouette
  recolour on the profile. The 0.1406-vs-0.0949 figures say the break's cycle moves more of the
  crop than the idle's even on that facing, but a facing-by-facing check of the lift was not run.
  `--gait-shots` and `--facing-shots` exist and would answer it in one run if it ever matters.
- **`NpcBrain` still passes only WALK or IDLE**, which T5.2 recorded, so every NPC in the demo is
  eligible for a break and no NPC exercises a gait beyond walking. The break itself is exercised
  by the player.
- **No test asserts the placeholder sheet's fourth block is visually distinct from its first.**
  `sheet_facings_test.gd` measures cell-to-cell difference for FACINGS; the equivalent question
  for BLOCKS is answered only by the windowed capture's three numbers, which are read by a person
  rather than gated. That is a real candidate row, and it is the same shape as the gap T5.8 closed
  one axis over.

---

## 2026-09-09 — T5.24 · The roadmap's missing run, and whether completeness should be gated

**Did.** Added one assertion per recorded package to `tests/unit/record_shape_test.gd` — every
package the DEVLOG records must be findable in `docs/ROADMAP.md`, exactly as it has had to be
findable in `docs/WORK_PACKAGES.md` since T5.19 — and then reconciled the six packages it found
missing: package-log rows for **T5.16, T5.17, T5.18, T5.19 and T5.20**, and a Phase 2 Done line
for **WP-07**, plus one for this row itself. Marked Phase T5's roadmap header **COMPLETE**, which
T5.23 earned and did not take. Added gotchas **75 and 76** to `CONTEXT.md`'s list and moved the
four documents that quote its length from seventy-four to seventy-six. Version `5.3.0` → `5.3.1`,
a PATCH. **No production code changed** — `git diff` on `src/` and `tools/` is empty; the only
non-documentation edit is `project.godot`'s `[template] base/version`.

**Why.** `ROADMAP.md`'s Phase T5 package log ran T5.15 and then jumped to T5.21. Five delivered
packages — each with a DEVLOG entry, a board row and a version bump of its own — had no trace at
all in the file `CLAUDE.md` sends a reader to for *where things stand*. T5.21 recorded the gap.
T5.23 recorded it again and promoted it to the top of `CONTEXT.md`'s next-package list. Neither
closed it, and **nothing was red, because nothing counted the rows** — the same structural cause
T5.4 wrote down for seven packages of the same defect, one level up from code.

**THE ROW WAS TWO THINGS AND THE SECOND IS THE ONE THAT MATTERED.** Writing five entries is
bookkeeping. The question worth answering was whether roadmap completeness should be *gated* the
way `record_shape_test.gd` already gates two other structural facts.

**The answer is yes, and T5.19 is the precedent rather than an analogy.** That row exists
precisely because a third manual reconcile was the wrong answer, and its argument for gating
structure transfers here with nothing changed: a file either opens with its own title or it does
not; a package either has a row or it does not; neither question has a reading, an interpretation
or a tone, *which is exactly why they are assertable when the sentences around them are not.*
"A package the DEVLOG records has no entry in `ROADMAP.md`" is that same shape and the same file's
business — so it went in beside the board check rather than into a fourth case. That is
`CLAUDE.md` rule 4 satisfied without widening anything: `record_shape_test.gd`'s OWNS line already
read "every package the log records has a row on the board", and this extends the SET of records
checked, not the KIND of fact.

**THE COUNTER-ARGUMENT WAS REAL, AND IT IS ANSWERED BY THE SHAPE OF THE CHECK RATHER THAN
OVERRULED.** The roadmap's package log genuinely is selective in a way the board is not. The board
has one shape — a row per package. The roadmap has three and uses all of them: a package-log row
under a phase, a tick beside an exit criterion, or a parenthesis in a phase's Done list. **T5.14
is only ever the second of those** — it has no package-log row anywhere and is nonetheless
recorded at length beside the criterion it closed. A gate demanding a package-log row would have
failed a package that is thoroughly recorded, and would have been wrong to.

So the assertion is `roadmap.contains(id)` — **findability, which is the identical choice T5.19
made one function above for the board**, and for the reason it wrote down there: *"the new gate
asserts a package is FINDABLE on the board, not that it has an index row, because 'findable' is
the property that matters and a stricter rule would have failed eight packages that are genuinely
recorded."* The roadmap may record a package in whichever of its three shapes fits. It may not
omit one entirely. That distinction is the whole of what is now enforced.

**AND T5.16 HAD DECLINED TO TOUCH THE ROADMAP IN WRITING**, which is the strongest-looking
objection of all because it is a considered refusal by a package rather than an oversight: *"No
exit criterion covers a defect fix, and inventing one to have something to tick would be the
ticking-without-proving this project spent T5.1 undoing."* **That is right about the CRITERIA list
and says nothing about the package LOG**, which is a different list in the same file answering a
different question — where a package sits in the plan, not whether a phase may close. Separating
the two is what makes this assertable rather than a matter of editorial taste, and it is why
T5.16's fix here is a log row and emphatically **not** a new criterion.

**Connects.** Three document gates existed and each owned one kind of fact; this adds a second
record to the third of them rather than a fourth gate. `docs_test.gd` owns what a document claims
EXISTS and its MUST NOT line forbids asserting what prose SAYS; `doc_counts_test.gd` owns one
number and forbids growing a second; `record_shape_test.gd` owns STRUCTURE. Neither of the first
two could have hosted this and both say so in their own headers. The MUST NOT line gained one
clause — that the gate may not require a package to be recorded in any PARTICULAR shape — because
the three-shapes fact is the thing a future author is most likely to try to tighten, and it is the
thing that would break T5.14.

**Verified.**

- `--headless --import`: exit 0, per gotcha 53 and before every engine command below.
- `--headless --check-only tests/unit/record_shape_test.gd`: clean.
- `--headless --quit-after 30`: *"Session ended after 0.6s — 0 warnings, 0 errors"*.
- Suite: **2,221 → 2,274 passed, 0 failed, 0 skipped**, exit 0.
- All seven checkers exit 0.
- **No windowed capture.** Nothing here is a visual claim — same as T5.17 and T5.19.


**AND `doc_counts_test.gd` FAILED ME ONCE ON ITS OWN CONVENTION, WHICH IS THE GATE WORKING.** The
board note explaining gotcha 75 wrote *"four claims of seventy-four"* — a SPELLED tens-number on a
line mentioning gotchas, which that case's header defines as a CLAIM about the list's current
length rather than a record of what it used to say. So the suite reported
`FAIL WORK_PACKAGES.md spells the gotcha count — expected seventy-six, got seventy-four` and the
plan grew from 6 to 7, a fifth document having started making a claim. Digits fixed it, in three
places. **That convention is stated in the case's own header and both `CONTEXT.md` and `ROADMAP.md`
failed it the first time it ran**, so this is the third time — not a new gotcha, and the reason it
is here is that a package writing ABOUT the count is the likeliest kind to trip it.
**THE DELTA IS +53 AND EVERY ONE OF THEM IS A COMPUTED PLAN DOING ITS JOB.** Not one is a case
this row wrote, and the arithmetic was measured against a reverted tree rather than predicted,
per the method T5.23's miss established:

| Case | Plan | Before | After | Why |
|---|---|---|---|---|
| `record_shape_test` | `docs + packages * 2 + 2` | 68 | 121 | The multiplier changed from 1 to 2 — **+51** for the roadmap check over 51 existing packages — and **+2** because this entry's own DEVLOG heading makes a 52nd, which now costs two assertions rather than one |
| `docs_test` | `paths + fields + 2` | 119 | 119 | Unchanged, and this was checked rather than assumed: its `PATH_PATTERN` is `res://[A-Za-z0-9_./-]*` and every path named in this row's new prose is bare (`tests/unit/quest_chain_test.gd`), so it adds no scanned path. T5.23's +2 surprise was exactly this case, in the other direction |
| `version_test` | `28 + <bold semvers in CONTEXT.md>` | 30 | 30 | Both bold semvers were rewritten in place `5.3.0` → `5.3.1`, not added to |
| `doc_counts_test` | `claims + 2` | 6 | 6 | Unchanged **despite two gotchas being added**, which is that gate working rather than missing something: its plan counts the DOCUMENTS that state the length, not the entries, and the same four documents state it. All four were moved from seventy-four to seventy-six in the same commit, which is the only reason it stayed green |

**THE PLANT IS THE LIVE REPOSITORY, WHICH IS THE STRONGEST FORM AVAILABLE AND THE ONE FORM THE
LAST TWO GOTCHAS CANNOT REACH.** The assertion was written and run before a single document was
edited. Gotcha 74 was a plant that passed because two files were byte-identical, and gotcha 75 a
brand-new assertion that passed its own plant by coincidence of timing — both are failure modes of
a *fabricated* condition. Nothing was fabricated here, so the red run cannot have failed for a
fabrication's reason:

```
=== 2266 passed, 6 failed, 0 skipped ===    exit 1
FAIL WP-07 is findable in the roadmap — expected true, got false
FAIL T5.16 is findable in the roadmap — expected true, got false
FAIL T5.17 is findable in the roadmap — expected true, got false
FAIL T5.18 is findable in the roadmap — expected true, got false
FAIL T5.19 is findable in the roadmap — expected true, got false
FAIL T5.20 is findable in the roadmap — expected true, got false
```

**SIX, NOT FIVE — AND THE SIXTH IS THE ARGUMENT FOR THE WHOLE ROW.** **WP-07, path actions**, is
the signature non-combat mechanic: `PathAction`, `PathActionPoint`, `Standing`, five `InteractVerb`
values, `RefusalReason.LOW_STANDING`, and the refusal-versus-failure design that the whole
interaction stack rests on. **It has been missing from `ROADMAP.md` since 2026-08-26**, and neither
T5.21's recording of this gap nor T5.23's named it — both read the file and counted five. That is
the case for a gate over a third reverse-count, delivered as a measurement rather than as a
prediction, and it is the answer to anyone who reads this row as bookkeeping.

**AND THE FOLLOW-UP PLANTS FOUND THE GATE'S LIMIT TWICE OVER, WHICH IS GOTCHA 76.** "It went
green" is a claim about the fix and not about the assertion, so both directions were checked — and
the first two attempts to plant it **passed**, each for a reason worth having in writing.

Deleting T5.19's entire package-log row left the suite green at 2,274. The gate was working exactly
as written: two other rows in `ROADMAP.md` mention T5.19 while saying something else — one
crediting its measurement, one its argument — and `roadmap.contains("T5.19")` is true of either.
Re-planted on T5.18, which the file named exactly once before this row started, it **passed again**
— because **this row's own new entry names all five packages it reconciled**, in the course of
explaining what was missing, so deleting T5.18's row left T5.18 findable inside the sentence
describing its absence. **A row that records a gap is a cross-reference to every id in the gap**,
and a reconcile package therefore invalidates its own plants as it works.

The weakness is inherent to findability and is the price of the property being worth having: the
alternative is a gate on recording SHAPE, which would fail T5.14. So the plants moved to ids the
file names exactly once, counted with `grep -o -- "$id" docs/ROADMAP.md | wc -l` on the finished
tree rather than the starting one:

| Plant | Result |
|---|---|
| The live repository, assertion added, no document touched | **exit 1** — `2266 passed, 6 failed`, one per missing package, each named |
| T5.19's whole package-log row deleted, everything else reconciled | **exit 0, GREEN** — gotcha 76's first half: two incidental mentions elsewhere satisfy `contains` |
| T5.18's row deleted, everything else reconciled | **exit 0, GREEN** — gotcha 76's second half: this row's own entry names T5.18 while describing its absence |
| WP-07's Phase 2 Done line deleted, before this row had a log row of its own | **exit 1, 2 failed** — `WP-07` **and `T5.24`**, which is how the row discovered its own only trace was an aside inside the line it had just written. Fixed by giving it a real log row |
| T5.13's package-log row deleted — its sole mention, on the finished tree | **exit 1** — `FAIL T5.13 is findable in the roadmap`, **exactly 1 of 2,274** |
| WP-05's Phase 2 Done-list parenthesis deleted — its sole mention | **exit 1** — `FAIL WP-05 is findable in the roadmap`, exactly 1, and from a DIFFERENT recording shape, which is what proves the check is indifferent to shape |
| T5.20's package-log row deleted AND its cross-reference in this row's entry removed | **exit 1** — `FAIL T5.20 is findable in the roadmap`, exactly 1: the two-edit form of the plant the middle row above could not make |
| Control, fully reconciled | **exit 0** — 2,274 passed |

**Exactly 1 failure on each of the last three is the load-bearing detail**, not the exit code. It
says the six failures in the first row are six independent facts rather than one assertion
reported six times.

**Unblocks.** A session can trust that a package named in the DEVLOG is findable in both the board
and the roadmap without grepping for it, which is what makes "read your package and nothing else"
workable. And the two remaining known record gaps are now the two that genuinely cannot be gated,
which is a shorter and more honest list than "the roadmap is behind".

**Gaps.**

- **THE GATE CANNOT TELL A RECORD FROM AN INCIDENTAL MENTION, and that is gotcha 76 rather than
  a defect to fix here.** `contains` is satisfied by another row's passing reference, so a package
  whose only trace in `ROADMAP.md` is somebody else's sentence about it passes. The alternative is
  a gate on recording SHAPE, which fails T5.14 for being recorded beside its criterion — so the
  weaker check is the correct one and its limit is written down instead of engineered away. The
  operational consequence is the plant rule, not the gate: count an id's mentions before planting
  on it, and count again after your own edits.
- **Gotcha 75 was named in T5.23's DEVLOG entry and never added to the list**, so the list held 74
  entries while the record referred to a 75th. Both 75 and 76 are entries now and the four
  documents that quote the count say seventy-six. **`doc_counts_test.gd` could not catch this** and
  its header is honest about why: it owns the agreement between the list's LENGTH and the documents
  that state it, so 74 entries and four claims of seventy-four was internally consistent. A gate on
  "every gotcha number a DEVLOG entry cites exists in the list" is a different question — a
  cross-reference rather than a count — and would need its own case and its own argument.
- **The roadmap's T5.22 row sits AFTER its T5.23 row, and it was left there.** The gate's MUST NOT
  line forbids asserting the ORDER of anything, for the reason T5.19 gave — order is an editorial
  judgement — and reordering a hundred-line block inside a package about completeness would be
  churn wearing a fix's clothes. Named rather than left for a reader to trip over.
- **NOTHING GATES WHETHER A RECORD IS TRUE, only that it exists**, and this is a hard limit rather
  than an omission. A roadmap row saying a package did the opposite of what it did passes. That is
  T5.17's sentence about prose, standing exactly where it stood, and T5.1 — a phase reading
  COMPLETE while carrying three unticked criteria — is what it looks like when the judgement half
  goes wrong. Review's problem, permanently.
- **The board's own detail sections are still ungated and one was wrong.** This file's heading for
  the scene-level interaction test read `## T5.20 ·` over T5.21's content; fixed in passing, and
  the gate could not have seen it because `contains("T5.20")` succeeds elsewhere in the file. A
  gate on "every package with a detail section has the right heading" is a different question from
  findability and would need to parse the sections, not the file. Not attempted, and T5.23 has no
  detail section at all, which the same hypothetical gate would have to decide about.
- **The assertion count and the method count are still not gated**, unchanged from T5.19's
  statement of the same limit: a case cannot know the suite's own final total while the suite is
  running. This entry's own "2,274" is review's problem like every one before it.
- **`src/systems/scene_director/director.gd` is still at 187 of its 190**, three lines from the
  wall, on an override WP-14 already raised once. Untouched here — a documentation package is the
  wrong place to spend a decision — and it remains the tightest file in the repository.

## 2026-09-09 — T5.25 · The gate that could not fail, and the numbers nothing was measuring

**THE ROW EXISTED BECAUSE THE PREVIOUS ROW'S OWN ENTRY HAD ALREADY SEEN HALF OF IT AND NOT
CONNECTED IT.** T5.24's entry, one section above this one, records that the board's detail heading
for the scene-level interaction test read `## T5.20 ·` over T5.21's content and that "the gate
could not have seen it because `contains("T5.20")` succeeds elsewhere in the file". That sentence
is the defect. It was written about a HEADING the gate does not check, and the same property
applies to the assertion the gate does check: `String.contains` is a substring test, so for any id
that is a prefix of a longer id the question being asked is not "is this package recorded" but "is
some package whose id begins with these characters recorded".

Four ids in this repository are such prefixes, and they are the four *oldest* in each family:

| id | satisfied by | deleting its every genuine trace left the suite |
|---|---|---|
| `T5.1` | `T5.10`–`T5.19` | GREEN |
| `T5.2` | `T5.20`–`T5.24` | GREEN |
| `WP-09` | `WP-09b` | GREEN |
| `WP-14` | `WP-14b` | GREEN |

**WHY THIS IS A DIFFERENT DEFECT FROM GOTCHA 76 AND NOT AN INSTANCE OF IT.** 76 says findability
is satisfied by an incidental cross-reference — another row's sentence about a package counts as a
trace. That is a judgement about what "recorded" ought to mean, and the gate's MUST NOT line
declines to make it on purpose. This is not a judgement at all: the assertion was comparing
against **a string that is not the id**. No tightening of what counts as a trace would have found
it, and the two endanger different sets — 76 applies to any package, this applied to exactly four,
whose rows sit furthest up the file and whose disappearance a reader is least likely to notice.
Filing it under 76 would have lost that.

**THE FIX IS ONE WORD BOUNDARY PER CALL SITE.** `_is_recorded_in(text, id)` builds
`\b<id with . escaped>\b` and searches. The dot is escaped because an unescaped one matches any
character, which would let `T5x1` satisfy `T5.1` — the same class of defect mirrored.
`\bWP-09\b` does not match `WP-09b` because digit-to-letter is not a word boundary, which is the
property the whole fix rests on. `record_shape_test.gd` +3 code lines; **no new assertion and no
changed plan** — the two functions assert exactly what they asserted before.

### THE LIVE REPOSITORY IS NOT THE PLANT THIS TIME, AND SAYING SO IS THE METHOD

T5.24's strongest claim was that its plant was the repository itself — the assertion was written,
run, and failed on six real packages before a document was edited, which is the one plant shape
gotchas 74 and 75 cannot reach. **That shape is unavailable here, and it was checked before the
change was written rather than discovered afterwards.** Extracting all 52 package ids with the
gate's own `HEADING_PATTERN` and testing `\b<id>\b` against both documents: zero failures in
`ROADMAP.md`, zero in `WORK_PACKAGES.md`. The tree is green before the change and green after it.

A gate that is green on both sides of its own fix is precisely the shape gotcha 70 warns about, so
the row needs a deletion — and it needs the comparison run, which is the part that is easy to skip:

| run | gate | plant | result |
|---|---|---|---|
| A | word boundary | none | `=== 2274 passed, 0 failed, 0 skipped ===`, exit 0 |
| B | word boundary | `T5.2`'s 7 roadmap traces renamed to `T5.99` | `=== 2273 passed, 1 failed, 0 skipped ===`, exit 1 |
| C | **the original `contains()`** | **the same plant** | `=== 2274 passed, 0 failed, 0 skipped ===`, **exit 0** |

B's single failure, verbatim:

```
FAIL T5.2 is findable in the roadmap — expected true, got false
FAILED: T5.2 is findable in the roadmap — expected true, got false
```

**C IS THE RUN THAT CARRIES THE ROW.** A and B together are also consistent with a gate that was
already working correctly and simply had nothing wrong with it; only C shows the old check was
blind to the identical deletion. Without C the change is untested by construction, and the row
would be a refactor asserted by its author rather than a fix proved by a measurement.

**ONE failure rather than several is B's second result.** The plant renamed the id in `ROADMAP.md`
only, so the board half still passed — which is what says the two functions are independent and
not one assertion counted twice. The plant is a rename rather than a row deletion deliberately:
deleting the log row leaves the other six mentions, and gotcha 76 means the assertion would then
pass for the wrong reason and prove nothing about this defect — which is gotcha 76's own second
rule, "plant a record gate on an id the document names exactly once", applied by counting first:
`grep -cE '\bT5\.2\b' docs/ROADMAP.md` returned 7, so a deletion plant was refused and a rename
used instead.

**GOTCHA 77**, and it is filed separately from 76 on purpose, for the reason above: a substring
test on an id is satisfied by a longer sibling id, so the assertion reads a string that is not the
id — and the ids it cannot see are the low-numbered, oldest ones, whose rows sit furthest up a
file and whose absence a reader is least likely to notice. **The check is weakest exactly where
review is weakest.** Its second half is the methodological one: when a fix makes nothing newly
red, the OLD code against the NEW plant is the evidence, and two runs are not enough. The list is
77 entries and the four documents that quote its length say seventy-seven —
`CONTEXT.md`'s section heading, `TESTING.md`, and `CLAUDE.md` in two places.
`doc_counts_test.gd`'s plan is `claims + 2` and is unchanged at 6, the claims having been
rewritten in place rather than added to.

### THE SECOND HALF WAS THE RECORD, MEASURED RATHER THAN RE-READ

T5.17 and T5.19 both reconciled the record by reading the documents. The numbers below were wrong
in a way reading cannot catch, because a document quoting a stale number is internally consistent.
Every replacement came off a run recorded here:

| file | claimed | measured | how stale |
|---|---|---|---|
| `README.md:80` | `555 assertions` | 2,276 | since before `2.0.0` — off by ~1,700 |
| `CLAUDE.md:22` | DEVLOG "over 5,400 lines" | 8,986 | ~60% |
| `CLAUDE.md:98` | `# 2,173 assertions` | 2,276 | three version bumps |
| `docs/ARCHITECTURE.md:250` | `2,173 assertions` in the rung table | 2,276 | three |
| `docs/CONTEXT.md:180` | `166 files, 15,552 code lines` | `167 files, 15,793` | taken before T5.23 added a file |
| `docs/TESTING.md:13-14` | `1625` full / `1551` stripped | `2276` full / `2202` stripped | ~650 |

Measurement commands and their output, all on `4.7.2.stable.official.ed1daf0bf`, the version CI
pins:

```
$ "$G" --headless --script tools/check_budgets.gd
167 files, 15790 code lines, 0 warnings, 0 violations      # on main, before this row
167 files, 15793 code lines, 0 warnings, 0 violations      # with this row's +3 code lines
$ wc -l docs/DEVLOG.md
8986 docs/DEVLOG.md                                        # before this entry
```

**`docs/TESTING.md` IS THE ONE NUMBER THIS ENTRY DOES NOT CARRY**, and deliberately. It quotes a
full total AND a stripped-template total, and the stripped one is only produced by CI's
`Ladder (stripped template)` job. The historical gap between the two has been a constant 74 in
every recorded run, so predicting 2,202 would have been easy and would have been **exactly this
package's own sin** — a number written from another number instead of from a run. Both figures go
in with the CI record, in the commit that records it.

**AND TWO SELF-CONTRADICTIONS IN `CONTEXT.md`**, which `CLAUDE.md:5` orders every session to read
FIRST, both of them fourteen lines or fewer apart:

- `:142` "Phase T5's second-idle box is the one that still stands open" against `:156` "**Phase T5
  has no unticked exit criterion** — T5.23 took the last one". T5.23 closed it; the earlier
  sentence was never updated when the later one was written.
- `:144` "**So the base is 5.0.0-complete**" against `:153` "**The version is** **5.3.1**".
  **`version_test.gd` could not see this**, and the reason is the recurring one: that gate asserts
  a **bold** semver in `CONTEXT.md` equals `project.godot`'s, and `5.0.0-complete` is unbolded. An
  ungated shape sitting beside a gated one is T5.19's lesson, not a new kind of defect. The
  sentence now names the PHASE rather than a version, because a version is not a completeness
  state and pinning one there is what made it rot in the first place.

Both bold semvers were rewritten in place, `5.3.1` → `5.3.2`, so `version_test.gd`'s plan
`28 + stated.size()` is unchanged at 30.

**AND THE GATE CAUGHT THIS ROW DOING THE THING THIS ROW IS ABOUT**, which is worth recording
rather than quietly fixing. The first full run after the documents were written came back
`=== 2276 passed, 1 failed ===`, exit 1: `FAIL CONTEXT.md states the declared version — expected
5.3.2, got 5.3.1`. The cause was this entry's own narrative — the headline paragraph quotes the
contradiction it fixed, and wrote the historical version as **bold** `5.3.1`, which is precisely
the shape `version_test.gd` reads as a live claim. **The convention this repository already has
is that bold is a claim and plain is a record**, the same distinction `doc_counts_test.gd` draws
between a spelled count and a digit, and a package writing ABOUT a version contradiction is the
most likely place to break it. Unbolded, and the run went green at 2,276. The gate T5.19 wrote
found a defect in the row that was auditing the gates — one run after this row's own plant proved
a different gate had been blind.

### ALSO IN THIS ROW

- **`ROADMAP.md`'s T5.22 log row was the only one in the file with no date and a non-conforming
  header, and it sat AFTER T5.23's row.** Both facts were self-declared in T5.24's entry and both
  were left there. Reformatted to the file's shape and moved above T5.23, and its
  `tests/unit/save_dir_test.gd` / 18 assertions added — a detail every other row in the run states
  and that row omitted.
- **T5.24's entry claimed the five absent packages each had "a version bump of its own".** T5.17
  changed no code and left the tree at `4.2.1`; its own board row says so. Narrowed to four.
- **The nine `**Commit:**` lines for T5.16–T5.24 are written.** Five packages have a detail
  section and took the line there in the convention T4.3 set; T5.17, T5.19, T5.20 and T5.23 have a
  board row only and took it inline. T5.20's is the one that needed care: `ddad201` on
  `claude/t5-20-dev-stage-split` reached `main` not through its own PR #49 — which targeted
  T5.19's branch — but through PR #51 from `land/t5-20-dev-stage-split`, and the row now says so.

### WHAT IS STILL NOT GATED, EACH WITH THE MEASUREMENT OR REASON BEHIND IT

- **The `**Commit:**` lines.** Counted before deciding: **15 of 52** packages carried one. A gate
  would fail 37 historical rows, and scoping it to "T5.16 onward" is the rotting exception list
  `HEADING_PATTERN`'s own header refuses to become. Backfilling 37 rows of commit archaeology is a
  row of its own, if it is worth one at all. Recorded as a gap rather than gated or hidden.
- **The suite's assertion total.** Unchanged from T5.19's and T5.24's statement of the same limit:
  a case cannot know the suite's final total while the suite is running. This entry's `2,276` is
  review's problem like every one before it.
- **Branch names.** `CONVENTIONS.md` now carries the pattern and the load-bearing sentence — the
  branch name is not authoritative, the in-tree record is. Deliberately ungated: a branch is cut
  before the work is understood, and renaming one mid-stack moves the base of every PR above it.
  That is not hypothetical here — `claude/t5-21-save-dir` carries T5.22 and
  `claude/t5-20-selection-test` carries T5.21, and both were left named as they are on purpose.
- **The board's detail-section headings**, still, and the hypothetical gate T5.24 described is now
  slightly cheaper to write than it was, since `_is_recorded_in` exists — but it still has to
  parse sections rather than the file, and it still has to decide about the four packages in this
  run that have no detail section. Not attempted.
- **`src/systems/scene_director/director.gd` is still at 187 of its 190**, untouched for the third
  documentation row running, and still the tightest file in the repository.

### THIS ROW IS 13 FILES AGAINST A STATED LIMIT OF ABOUT 8, AND THAT IS THE ROW'S SHAPE

`CLAUDE.md:144` and the board both say no package exceeds about 8 files or 500 new code lines.
This one touches 13 and is over on the first count — T5.24 was 10 and said so, and this is worth
the same sentence rather than passing quietly. **The second count is what the limit is protecting
and it is nowhere near it: 24 inserted lines in one file, of which 3 are code** and 21 are the
comment explaining why. `src/` and `tools/` are byte-identical.

The file count IS the package. Six documents each quoted one stale number, and a reconcile that
fixes five of six is the failure mode T5.19 and T5.17 both demonstrated — the sixth is then quoted
by the next session as though it were current. There is no smaller cut that leaves the record
consistent: dropping `README.md` leaves the worst number in the repository (555 against 2,276) in
the most-read file, and dropping `ARCHITECTURE.md` leaves a rung table describing a suite three
versions old. The four record files — `ROADMAP.md`, `WORK_PACKAGES.md`, `DEVLOG.md`,
`CHANGELOG.md` — plus `CONTEXT.md` and `project.godot` are the six every package touches, so the
row is really "one gate file, six stale-number files, and the standing six".

### THE STACK THIS ROW FOLLOWS, RECORDED BECAUSE IT COST THREE EXTRA STEPS

T5.22, T5.23 and T5.24 were a three-deep stack of PRs — #53 → #54 → #55, each based on the one
below — and landing them was not three merges. **GitHub retargets a stacked PR only when its base
branch is DELETED**, and these branches were kept, so after #53 merged, #54's base was still
`claude/t5-21-save-dir` and merging it would have landed the work in that branch rather than in
`main`. Each of #54 and #55 needed `gh pr edit --base main`, and branch protection then required
`gh pr update-branch` and a fresh green run — `29f4134` and `6112938` are those two merges of
`main` into the branch. Both jobs passed on both. Worth writing down because the failure mode is
silent: the merge succeeds and the work is simply not on `main`.

**AND MERGING #54 WITHOUT #55 WOULD HAVE PUT A SELF-CONTRADICTING RECORD ON `main` WITH NOTHING
RED TO SAY SO**, which is why they were landed back to back rather than one per session. At
`24a84dd`, T5.23's tree named `GOTCHA 75` in three documents while the gotcha list held 74
entries, stated `2,192` where its own text said `2,221`, and closed a `*(Previously: …)*`
parenthesis mid-sentence leaving the remainder dangling. All three were repaired by T5.24, none of
them is visible to `doc_counts_test.gd` — which compares the SPELLED count and treats a digit
reference as a record rather than a claim — and `main` sat in that state for the minutes between
the two merges.

**CI GREEN — RUN [`34317589462`], BOTH JOBS, AND THE STRIPPED COUNT THIS ENTRY REFUSED TO
PREDICT.** Job logs read rather than the tick, per gotcha 26.

| job | result | last line |
|---|---|---|
| `Ladder (full checkout)` | success | `=== 2276 passed, 0 failed, 0 skipped ===` |
| `Ladder (stripped template)` | success | `=== 2202 passed, 0 failed, 25 skipped ===` |

The full figure is byte-identical to the local measurement. `docs/TESTING.md:13-14` now carries
both, which is the pair this row deliberately left out of its first commit.

**AND THE PREDICTION WOULD HAVE BEEN RIGHT, WHICH CHANGES NOTHING.** 2,276 − 2,202 = **74**, the
same gap as every recorded run before it — including the `1625`/`1551` pair that had been sitting
in `TESTING.md` since before `2.0.0`, whose difference is also 74. Writing 2,202 from that
constant would have produced the correct number by a method that cannot be trusted, and a package
whose entire subject is numbers written from other numbers is the last place to use it. The
distinction is worth keeping precisely because the shortcut works most of the time: a stale
`TESTING.md` was internally consistent for four versions for the same reason.

The constant itself is now a measurement worth stating rather than a coincidence noticed twice:
**the stripped template has reported exactly 74 fewer assertions and 25 named skips in every run
recorded in this file.** Nothing gates it — `ladder.yml` asserts only that the named-skip count is
non-zero, so a stripped run can be told from a full one, never that the arithmetic holds. That is
a candidate row and not this one, and it needs the two jobs to compare outputs, which they
currently cannot: they are independent and nothing reads both.

## 2026-09-09 — T5.26 · The ladder's own gate could not see an unwired checker

**THE ROW IS THE PREVIOUS ROW'S METHOD TURNED ON A DIFFERENT GATE.** T5.25 asked what
`record_shape_test.gd`'s assertions were actually comparing and found they were comparing the
wrong string. This asks the same question of `gates_test.gd`, whose header states its purpose in
its own words: *"the assertion that would have caught a gate written, committed, and never wired —
which is the defect the whole package is about, applied to the package itself."*

**It could catch neither shape of that.**

| shape of "never wired" | why it passed | now |
|---|---|---|
| an eighth `tools/check_*.gd` never added to the ladder | `LADDER` was a const of seven and nothing asserted it named ALL of them | the list is derived from `tools/` |
| a checker named in the workflow only by a `#` comment | `workflow.contains(checker)` is true of a comment, and this workflow's comments name every checker on purpose | invocations counted: a non-comment line carrying the path AND `--script` |
| a checker in the full job, absent from the stripped one | `contains` returns one bool for a whole file and cannot express "in both" | the count must equal `JOBS.size()` |

### THE COMPARISON RUN, WHICH IS THE ROW'S WHOLE EVIDENCE

The tightened assertions are green on the live tree — seven checkers, each invoked twice, list
complete — so a run before and a run after prove nothing on their own. Same position T5.25 was in
and the same answer: plant it, then run the OLD code against the SAME plant.

The plant is both `run:` lines for `check_signals` commented out. The checker then runs in
**neither job**, while its name is still in the file twice, as comments:

```
invocation lines left: 0
the name still appears in the file this many times: 2
```

| run | gate | plant | result |
|---|---|---|---|
| A | invocation count | none | `=== 2285 passed, 0 failed, 0 skipped ===`, exit 0 |
| B | invocation count | both `check_signals` steps commented out | `=== 2284 passed, 1 failed, 0 skipped ===`, exit 1 |
| C | **the original `contains()`** | **the same plant** | `=== 2276 passed, 0 failed, 0 skipped ===`, **exit 0** |

B's failure, verbatim:

```
FAIL every job invokes tools/check_signals.gd, once each — expected 2, got 0
```

**C IS THE RUN THAT CARRIES THE ROW.** A checker running in neither job of the ladder, and the
ladder's own gate — the one case whose entire subject is a gate nobody runs — reported green at
exit 0. A and B alone are equally consistent with a gate that had nothing wrong with it.

**THE THREE RUNS READ 2,285 AND THE FINISHED TREE READS 2,287, AND THE TWO NUMBERS ARE BOTH
RIGHT.** They were measured before this entry existed. Writing it added a `## <date> — T5.25`-shaped
heading for T5.26, `record_shape_test.gd` derives its package list from those headings, and its
plan is `_docs.size() + _packages.size() * 2 + 2` — so one new package id is **+2 assertions**, one
for the board row and one for the roadmap row. `WORK_PACKAGES.md` warns that a closing doc commit
can move the total for exactly this reason; here it moved it by two, predictably, and the CI record
is read off the final commit rather than this one. The plant deltas are unaffected: B removed one
assertion from a 2,285 baseline, C fell to 2,276 because the reverted case carries `plan(56)`.

### TWO FURTHER PLANTS, EACH A DIFFERENT FAILURE, EXACTLY ONE EACH

- **The stripped job's step alone removed** — `expected 2, got 1`. This is the shape that matters
  most in practice: a full-job-only checker looks wired to anyone reading the first half of the
  workflow, and the stripped job is the half that proves the template stands up with no game
  present. `contains` could not express this at all, which is why the count is per-job rather
  than per-file.
- **An eighth checker written and unlisted**, `tools/check_planted.gd` —
  `FAIL tools/check_planted.gd is listed in LADDER, so it is checked at all — expected true, got
  false`. That run reported `=== 2285 passed, 1 failed ===`, i.e. **2,286 total: the plan grew by
  one on its own**, which is the computed plan proving itself in passing rather than by argument.

### THE THREE DECISIONS, EACH WITH THE PRECEDENT RATHER THAN THE PREFERENCE

**The list is derived, not typed.** `test_runner.gd` has scanned `tests/unit` for files missing
from `CASES` since T2.2 and fails on `"%s exists but is not listed in CASES, so it never runs"`.
This is that pattern, and the argument is `check_boundary.gd`'s: a list of what to check rots, and
it rots invisibly precisely where the list is the only thing between a gate and irrelevance.

**The count is compared to `JOBS.size()`, and the job names are asserted too.** A constant
compared against reality is only as good as the constant, so `JOBS` being `["ladder", "stripped"]`
is not enough — each is asserted present as a job declaration, so a renamed or deleted job fails
by name instead of quietly making every count below it a fiction. That is `dev_tools_test.gd`'s
`owners.size() > 20` guard against a silently-empty extractor, applied to a const.

**The plan is computed** — `42 + JOBS.size() + LADDER.size() * 2 + on_disk.size()` — for
`record_shape_test.gd`'s reason: wiring an eighth checker should not mean editing a number, and a
number that must be edited gets edited to whatever the run reported. It held first time: the run
came back `2285 passed, 0 failed` with no plan mismatch, and plant 3 adjusted by itself.

### AND THE INVENTORY HAD TWO ROWS WHOSE LAST TWO CELLS RENDERED AS NOTHING

Found while adding this row's own entry to `SYSTEMS_INVENTORY.md`, and it is T5.15's defect in a
different shape — content present in the file and invisible in the rendered document.

The table at `SYSTEMS_INVENTORY.md:162` is `| System | Purpose | Status |`, three columns. Two
rows carried **five**: `Localization` and `Record shape gate`. Markdown drops cells past the
header count, so both rows' `Reads` and `MUST NOT` content — the record-shape gate's MUST NOT line
among it — was in the file and in no reader's view. Both rewritten to three columns with the extra
cells folded into Purpose as `**Reads:**` and `**Must not:**`, losing nothing.

**AND `gates_test.gd` HAD NO ROW IN THAT FILE AT ALL**, which is T5.19's `Row styles` defect a
second time: the case that guards the seven checkers was itself missing from the table of what
exists. It has one now.

**I reproduced the five-column defect myself, in the row I was adding, minutes after finding it** —
copying the neighbour's shape rather than the header's. That is the strongest argument available
for gating it, and it is NOT gated here, for a reason that was measured rather than assumed:

**A CORRECT COLUMN-COUNT CHECKER IS SUBTLER THAN IT LOOKS, AND MY FIRST THREE ATTEMPTS WERE ALL
WRONG.** A naive count over the repository flagged four candidates. Three were **false positives**:
- `WORK_PACKAGES.md:87` and `:92` — GFM makes the **trailing pipe optional**, and those two rows
  omit it. Four cells, not the flagged three; correct as written.
- `DEVLOG.md:6817` — a cell containing `Day 1 \| 18:40 \| Dusk`, i.e. **escaped pipes**, which a
  splitter must not treat as delimiters.
Only the two `SYSTEMS_INVENTORY.md` rows were real. A gate that shipped any of those three false
positives would fail the build on correct documents, which is worse than the defect: this project's
own rule is that a gate has to be right about what it reads, and gotcha 77 and 78 are both
instances of it being wrong. **So the column-count gate is a row of its own with its own plants —
optional trailing pipe, escaped pipe, a genuinely short row, a genuinely long one** — and not a
function bolted onto this one. Recorded rather than left as a note in a chat.

### ALSO IN THIS ROW

- **T5.25's `**Commit:**` line shipped without its SHA.** It read `**Commit:** on
  `claude/t5-25-record-reconcile`, targeting `main`.` — written before the commit existed, which
  is the one ordering the board's closing checklist cannot avoid, since item 6 asks for a commit
  that the act of satisfying item 6 creates. Filled in as `03a097c` plus `7dc5f63` for the CI
  record, and the ordering problem is named in the line itself so the next row does not rediscover
  it.

### WHAT THIS ROW DID NOT TAKE, ALL FOUND IN THE SAME AUDIT

Four claims still have no mechanism behind them. They are `ladder.yml` and seven tools, which is a
different file set and a different plant for each, so they are their own rows rather than this one
growing to twenty files:

- **Rungs 5–11 read only the exit code.** No `SCRIPT ERROR` grep, no log artifact — the artifact
  upload lists `import.log`, `boot.log` and `tests.log` only. **Gotcha 24, this project's founding
  observation, is that a GDScript runtime error aborts the innermost frame and no more**, so a
  crash inside a checker's per-file loop can leave files unscanned, let the loop finish, and still
  reach `print("PASS"); quit(0)`. Rung 4 has `ErrorWatch` for exactly this shape. Rungs 5–11 have
  no equivalent, and this is the largest remaining hole in the ladder.
- **`ladder.yml:363-373` asserts in prose that the two jobs "must report exactly the same
  numbers".** They are independent jobs and nothing compares their output. The claim has been true
  every time it was checked by hand and is enforced by nothing.
- **No checker asserts its own scan was non-empty — 0 of 7**, each printing its scanned count and
  none refusing a zero. `CHANGELOG.md` states the rule for doc gates in as many words: *"A doc
  gate that passes because it found nothing to check is worse than no gate."* It was never applied
  to the tools.
- **`Fixtures.activate()` is called unchecked at 14 of 16 sites**, against the shape
  `TESTING.md:193-195` writes out: `if not Fixtures.activate(): skip(...); return`. The two that
  handle it do so differently — `bag_mirror_test.gd:47` skips, `audio_duck_test.gd:180` asserts
  the return is `true`, which is arguably the better of the two and is not what the document says.
  The document and the code should agree before either is gated.

Still ungated with the reason recorded rather than as an oversight, unchanged from T5.25: the
suite's own assertion total (a case cannot know it while the suite runs), the board's `**Commit:**`
lines (15 of 52, so a gate fails 37 historical rows), the board's detail-section headings, and
branch names.

**`src/systems/scene_director/director.gd` is still at 187 of its 190**, untouched for the fourth
row running.

**CI GREEN — RUN [`34329245652`], BOTH JOBS.** Job logs read rather than the tick, per gotcha 26.

| job | result | last line |
|---|---|---|
| `Ladder (full checkout)` | success | `=== 2287 passed, 0 failed, 0 skipped ===` |
| `Ladder (stripped template)` | success | `=== 2213 passed, 0 failed, 25 skipped ===` |

Full is byte-identical to the local measurement. `docs/TESTING.md:13-14` carries both.

**The stripped gap is 74 for the fourth recorded run running** — 2,287 − 2,213, the same constant
T5.25 measured rather than predicted and declined to write from arithmetic. It has now held across
`1625`/`1551`, `2276`/`2202` and this pair, which makes it a stable property of the strip rather
than a coincidence, and **still nothing enforces it**: `ladder.yml` asserts only that the
named-skip count is non-zero. That is one of the three claims T5.27 takes.

## 2026-09-09 — T5.27 · A checker can skip a file and still print PASS

**THE FIRST ROW IN THIS RUN WHOSE ENFORCEMENT IS NOT IN THE SUITE**, which is worth saying first
because it makes the assertion total the wrong measure of it. T5.25 and T5.26 both fixed an
assertion. This fixes `ladder.yml` and six tools, and the suite moves only by the two a new
DEVLOG heading adds to a computed plan.

### THE PREMISE WAS MEASURED WITH A THROWAWAY PROBE, AND THE FIRST PLANT SAID IT WAS FALSE

Rungs 5–11 were bare `run: godot --headless --script tools/check_*.gd`: exit code only, no log
grep, no artifact. Rungs 2, 3 and 4 all grep their logs, and rung 4 additionally carries
`ErrorWatch`. The question is whether the difference can hide anything.

**First attempt, and it was misleading.** Injecting a real runtime error into
`check_layers._scan_script` — an out-of-bounds index on a typed array, for one file only — gave:

```
SCRIPT ERROR lines: 1
exit=1
```

Exit 1, no `scripts scanned` line at all. The tool **died** rather than lying, so the exit code
had caught it and the premise looked false. Had that been the only evidence, this row would have
been dropped as unnecessary.

**The minimal probe is what settled it.** `tools/zz_probe.gd`, written and deleted in the same
session, doing nothing but the shape in question — a loop of three calling a function that indexes
an empty array on the second:

```gdscript
func _initialize() -> void:
	var seen: int = 0
	for i: int in [1, 2, 3]:
		seen += _per_item(i)
	print("  loop finished, items processed: %d of 3" % seen)
	print("PASS")
	quit(0)

func _per_item(i: int) -> int:
	if i == 2:
		var empty: Array[int] = []
		return empty[9]
	return 1
```

```
SCRIPT ERROR: Out of bounds get index '9' (on base: 'Array[int]')
  loop finished, items processed: 2 of 3
PASS
exit=0
```

**That is gotcha 24 in its exact working form**: the error aborts the innermost frame, the loop
finishes, **one item of three is silently unscanned**, and the script prints `PASS` and exits 0.
A checker in that state reports success over an incomplete scan and no rung can tell.

**Why the two runs differ, since it matters for the next person planting this.** The probe's error
is inside a function whose caller keeps looping. `_scan_script`'s failure took a path that ended
the script instead. **So the observable behaviour depends on where in the call graph the error
lands** — which means "the exit code caught it once" is not evidence that the exit code catches
it, and a single plant on real code can point either way. Gotcha 75's family: a plant that fails
for the wrong reason misleads exactly as much as one that passes.

### THE FIX, AND WHY IT DOES NOT DISTURB T5.26'S GATE

All fourteen checker steps — seven per job — now capture output to `check_<name>.log`, print it so
the CI log still reads the same, and force `status=1` if that log carries `SCRIPT ERROR` or
`Parse Error` even when the checker exited 0. The seven logs join `import.log`, `boot.log` and
`tests.log` in the artifact upload, in both jobs.

The steps kept `godot --headless --script tools/check_<name>.gd` on a single line on purpose.
T5.26's assertion counts INVOCATIONS — a non-comment line carrying the script path and `--script`
— and requires exactly `JOBS.size()` of them. Verified after the rewrite: 2 per checker, all
seven. **A shared runner script would have been better engineering and was rejected for that
reason**: `run: tools/ci/run_checker.sh tools/check_x.gd` drops `--script` from the line and would
have forced a change to the gate written one row earlier, trading one duplication for a weakened
assertion.

### SIX CHECKERS COULD PASS ON A SCAN OF NOTHING

| run | tool | scan root | result |
|---|---|---|---|
| control | `check_layers` | `res://src` | `scripts scanned: 105`, `PASS`, exit 0 |
| plant | `check_layers`, guarded | `res://localization` | `scripts scanned: 0`, `FAIL — nothing was scanned, so this gate could only ever pass`, **exit 1** |
| comparison | `check_layers`, **unmodified** | `res://localization` | `scripts scanned: 0`, **`PASS`, exit 0** |

**The comparison run is the row**, as it was for T5.25 and T5.26: the guard's own red run only
shows the guard fires, while the unmodified tool going green on the identical empty scan shows
what was wrong. 0 of 7 tools guarded this, while all seven printed their own scanned count — the
number was there to read and nothing read it.

The counter is incremented in each collector immediately after the `append`, not recomputed at the
end, so it cannot drift from the scan it describes. `check_budgets` uses a different collector
shape (`_collect(directory, into)` with a `DirAccess` cursor) and took the same one-line change.

**The rule was already written down and pointed at the wrong target.** `CHANGELOG.md` has said
since `4.3.1` that *"a doc gate that passes because it found nothing to check is worse than no
gate"* — about the DOC gates, and never turned on the tools that scan the engine.

### `check_content` IS EXEMPT, AND THAT EXEMPTION IS THE PART WORTH KEEPING

Its entire input is `data/` and `scenes/areas`, and the stripped-template job's second step is
`rm -rf data scenes/areas`. **A zero scan is a legitimate state for that checker and for no
other**, so guarding it would fail the stripped job for doing precisely what it exists to prove.
The other six read `src/`, `tests/`, `tools/` and `localization/`, none of which the strip
touches, so zero there is always a defect.

This is the first exemption in this run derived from **what the strip removes** rather than from
what a gate can judge, and it is the question to ask first next time: before guarding a count, ask
what the stripped template legitimately lacks. Recorded on the `Content validator` row rather than
left as an absence somebody later reads as an oversight.

### AND A COMMENT CLAIMED A CHECK NOTHING PERFORMED

`ladder.yml` carried, twice, that a stripped template **"must report exactly the same numbers"**.
The two jobs are independent, nothing compares their output, and the claim had been true every
time a person checked it by hand. Reworded to state what is enforced and what is not:

- **Enforced, and it is the failure mode that matters**: each checker must EXIT 0 in both jobs, so
  an engine string that stops resolving once the game is gone fails the stripped job rather than
  merely reporting a different count.
- **Not enforced**: the counts being equal. The mechanism needs each job to publish its counts and
  a third job to diff them, and that is now a candidate row in `ROADMAP.md` rather than a sentence
  in a comment.

The stripped gap has been exactly 74 across four recorded runs, which is what made the old comment
easy to believe.

### VERIFIED

Twelve rungs and seven checkers green on `4.7.2.stable.official.ed1daf0bf`. Boot `0 warnings, 0
errors`. Suite `=== 2291 passed, 0 failed, 0 skipped ===`, exit 0.

**THE SUITE MOVED +4 AND I HAD PREDICTED +2, WHICH IS WORTH THE PARAGRAPH.** Two were the new
DEVLOG heading through `record_shape_test.gd`'s `_docs.size() + _packages.size() * 2 + 2`, exactly
as expected. The other two were **`docs_test.gd` finding two new `res://` paths in this row's own
prose** — the plant table quotes `res://src` and `res://localization` as the scan roots, and that
case asserts every `res://` path the documents name resolves. Writing the evidence down added
assertions about the evidence. Four cases compute their plans from `docs/`, so **the assertion
delta of a documentation-heavy row is not predictable from the code change**, and every number in
this entry was read off a run for that reason rather than reasoned to. Fifth time in this run.
`check_budgets`: **167 files, 15,852 code lines, 0 warnings, 0 violations** — up 36 code lines from
15,816, all of it the guards and their headers. Scan counts after the change, for the record:
`check_boundary` 156 scripts, `check_strings` 105, `check_layers` 105, `check_content` 16 scenes.

### AND THE LOGS THIS ROW ADDED WERE NOT IGNORED, WHICH WAS ALREADY TRUE OF THREE OF THEM

Caught by asking what files this row leaves behind rather than by a gate, and it is a defect this
row WIDENED rather than introduced. `.gitignore` had no `*.log` pattern, and the workflow has been
writing `import.log`, `boot.log` and `tests.log` since T1.4 — so anyone running the ladder locally
the way CI does has always been left with untracked logs, and `git add -A` would have committed
them. This row takes that from three filenames to **ten**.

`*.log` added, with the reason beside it. Verified rather than assumed: writing
`check_layers.log` and running `git status --short --untracked-files=all` now reports only the
`.gitignore` change itself. **Nothing `.log` has ever been tracked** — `git ls-files | grep '\.log$'`
is empty — so the pattern cannot orphan a file the repository depends on, which is the one thing
worth checking before adding an ignore rule.

The suite is unaffected at 2,291: `docs_test.gd` reads `docs/` and `.gitignore` is not a document.

### GAPS

- **`Fixtures.activate()` is still unchecked at 14 of 16 sites** and this row deliberately did not
  touch it, because **the two sites that do handle it disagree and the document backs the weaker
  one.** `TESTING.md:193-195` writes `if not Fixtures.activate(): skip(...); return`, which
  `bag_mirror_test.gd:47` follows; `audio_duck_test.gd:180` instead asserts the return is `true`.
  The assert is arguably right and the document arguably wrong: a fixture root that cannot be
  written turns a skipped case into a silent no-op, which is the exact failure this row just
  guarded the tools against. **Deciding that is the owner's**, and the cost differs by an order of
  magnitude — assert loudly and one document changes, skip and fourteen files do. Left as a
  decision rather than settled in passing.
- **The cross-job count comparison** described above.
- Unchanged and still recorded rather than forgotten: the suite's own assertion total, the board's
  `**Commit:**` lines at 15 of 52, the board's detail-section headings, branch names, and the
  markdown column-count gate T5.26 declined on measurement.
- **This row is 18 files against a stated limit of about 8**, and over on that count for the third
  row running. New code lines: ~36, against a limit of 500. **Seven are the thing this row exists
  to change** — `ladder.yml` and six tools — **and eleven are the record**, which is the same
  arithmetic T5.25 and T5.26 recorded and by now the pattern rather than the exception. **If
  the 8-file guideline is meant to bind a documentation-heavy row, it needs rewriting; if it is
  meant to bind code, it should say so.** Named here because three rows in a row have quietly
  exceeded it.
- `src/systems/scene_director/director.gd` is still at 187 of its 190, untouched for the fifth row
  running.

## 2026-09-09 — T5.28 · A template rule, a template default and a game choice are three different things

**THE ROW THAT WAS RANKED FIRST FIVE TIMES AND NEVER TAKEN**, and the reason it kept losing is the
interesting part rather than an excuse. `docs/TEMPLATE.md` § *"The one constraint nobody has
scoped"* has said since 2026-08-26:

> The same class of question applies to a few other decisions made for one game's constraints and
> now imposed on all of them — most notably "a conversation is not saved". They may well be the
> right defaults. **What is missing is the distinction between a template default and a game
> choice, which no document currently draws.**

`docs/CONTEXT.md` carried it at the TOP of the candidate list and deferred it every time, always
for the same honest reason: *"its honest weakness is that it is prose and cannot be proved by
running the engine, which is why T5.18 was taken ahead of it."*

**That reason is true and it was never sufficient**, because the same paragraph also recorded what
the row was holding up: it *"DECIDES the two rows under it rather than guessing: whether a chapter
sequencer, a calendar and an economy are this base's business at all is one question asked three
times."* The narrative-staging row said *"Scope depends on the taxonomy row above."* The
time-above-one-day row said *"Also gated by the taxonomy question."*

**So deferring the cheap ungateable row kept the expensive gateable ones frozen.** Three candidate
rows were unscopable indefinitely for want of one distinction, and this project's standing rule
against inventing work meant none of them could honestly be started — a package needs a reason,
and the reason lived in the row nobody would take because it could not be gated. That is a
scheduling failure mode worth naming: **a row that gates others is not optional just because it is
prose, and its cheapness is not a reason to keep it at the top of the list unbuilt.**

### THE ANSWER IS THREE KINDS, NOT TWO, AND THAT IS WHY IT BECAME TRACTABLE

The document asked for a two-way distinction — default versus choice — and two is not enough to
hold the cases. "No combat" is not a default a game overrides; it is foreclosed. `world/first_area`
is also a decision the template made, and a game overrides it by editing one line of
`project.godot`. Calling both "a decision the template made" is exactly what loses the difference,
and it is why the two-way version had no traction for a year.

| Kind | A game… | Test | Recorded in |
|---|---|---|---|
| **TEMPLATE RULE** | cannot override it; wanting to is a fork of the template | no seam exists, plus a checker where the rule is mechanical | `TEMPLATE.md`, `CLAUDE.md` |
| **TEMPLATE DEFAULT** | replaces the value through a seam, touching no `src/` file | **a seam exists** | `AUTHORING.md`, `ART_CONTRACT.md`, `[game]` |
| **GAME CHOICE** | builds it in its own code root, on the base's signals and flags | the base builds nothing | `OPTIONAL`, or absent with a stated reason |

### THE TEST IS MECHANICAL, WHICH IS THE PART THAT MAKES THIS MORE THAN VOCABULARY

**Does a seam exist?** A "default" a game cannot replace without editing `src/` is not a default —
it is a rule that has not admitted it.

"Is this a default or a rule?" is a matter of tone. **"Can a game replace it without editing
`src/`?" is a fact about the repository**, and the answer is sometimes embarrassing, which is the
point. Applied to `src/core/boot/game_root.gd:28`:

```gdscript
const PLAYER_SCENE: String = "res://scenes/characters/player.tscn"
```

Engine code, in the `core` layer, naming the player prefab, with `GameConfig` exposing exactly two
keys (`game/world/first_area`, `game/world/first_spawn`) and no `player_scene` among them. **By the
test, the player prefab is a RULE pretending to be a DEFAULT** — a game whose protagonist has a
different shape must edit `src/`, which is precisely what `ARCHITECTURE.md` forbids: *"a game adds
content and resources; it does not add code under `src/`."* That is the next row, and the ADR is
what found it: the distinction earned its keep within an hour of existing.

### APPLIED, SO THE ADR DECIDES RATHER THAN DESCRIBES

- **RULES.** No combat — owner decision, affirmed repeatedly, and now stated as the *kind* of thing
  it is rather than as a preference. The layer rule and the demo-name boundary, both of which
  already have checkers (`check_layers.gd`, `check_boundary.gd`) — **which is what a rule looks
  like once it can be mechanised**, and is the strongest evidence the three kinds carve reality.
- **DEFAULT.** Time. `Clock`, `NpcSchedule` and `Weather` are already here, so a cycle above the
  day extends a system that is present rather than adding one. The base owns the facts — hour, day,
  phase, cycle position — and a game chooses the numbers.
- **GAME CHOICE.** A chapter sequencer: a `story/chapter` integer flag with `AT_LEAST` is already a
  complete chapter model for both authored condition surfaces, and both `DialogueNode` and
  `QuestStep` evaluate through the one `FlagQuery`, so a first-class `Chapter` resource would add a
  second way to express what one already expresses. An economy: currency, value and exchange are
  genre rather than structure, on the same footing as `Harvestables` (already `OPTIONAL`, WP-10),
  and `Inventory`, `Equipment` and `Interactable` are the seams one would be built on.

**Two candidate rows are closed by a REFUSAL rather than built, and writing the refusal down is the
whole point.** An unwritten refusal is rediscovered, ranked, deferred for want of a reason, and
ranked again. That is not a hypothetical: it is what happened to these three, three times.

### THE CUTSCENES ROW NEEDED A REASON, NOT A PACKAGE — AND A DRAFT OF THIS ROW GOT IT WRONG

`Cutscenes` was the only `TODO` in `SYSTEMS_INVENTORY.md` with a blank boundary column — the column
that file calls its most important.

**A draft of this plan proposed building the staging seam** (`PlayerController.walk_to`,
`NpcBrain.go_to`, `HD2DCameraRig.borrow`/`release`) **on the grounds that nine `cutscene` mentions
across eight files under `src/` were unpaid IOUs — "seven IOUs, no debtor" was its headline.** That
was a misreading, and it was caught by reading the lines in full rather than counting them:

| file | what it actually says |
|---|---|
| `dialogue_duck.gd:26` | "deletes nothing here — it calls `Audio.duck()` from its own occasion" |
| `surface_wetness.gd:21` | "keeping it out of here is what lets a cutscene soak one courtyard on demand" |
| `environment_driver.gd:10` | "forced by a cutscene, **without touching this file**" |
| `screen_fade.gd:6` | "a cutscene **can later ask for** the same fade" |
| `player_controller.gd:274` | the grounded rule deliberately NOT re-checked, so a cutscene may lift the player off a ledge |

**Every one is a receipt that the seam is already open**, not a debt that something is missing. They
say: this file will not need to change when a game wants a cutscene, because the game supplies the
occasion and calls the existing entry point. **Reading a comment as a debt is how a comment becomes
a work package**, and the count was wrong too — nine mentions across eight files, not seven.

The row therefore gets a boundary line and a stated reason: **GAME CHOICE, seam already open.** The
base ships no sequencer and no cutscene resource, because a step enum would grow `GameEnums` —
append-only, since ordinals are stored in `.tscn` files — for a shape every game would author
differently.

Two further reasons not to build it, both from the repository rather than from taste. It would ship
**four public methods whose only caller is the test written to justify them**, which is exactly what
`tools/check_methods.gd` exists to catch; that tool's header records `AudioDirector.duck()` sitting
uncalled for three phases and being **wrong** when finally wired, and states *"CODE WITH NO CONSUMER
IS NOT MERELY UNUSED, IT IS UNVERIFIED."* The template's own precedent runs the other way: T5.14
landed `Events.turn_requested` **with two real in-repo askers**. And the camera third is authorable
around for nothing: `HD2DCameraRig.camera` is a public `Camera3D`, the rig lives in the area scene,
and `scenes/areas/**` is game-owned — so **Godot's camera stack IS the borrow protocol**, and it
restores `follow_lag` by construction because nothing ever touched it.

### `Fixtures.activate()` IS ASSERTED, NOT SKIPPED — AND THE DOCUMENT WAS THE THING THAT WAS WRONG

`docs/TESTING.md:193-195` gave the shape as `if not Fixtures.activate(): skip(...); return`, which
`bag_mirror_test.gd:47` followed. `audio_duck_test.gd:180` instead asserted the return is `true`.
Two shipped shapes, disagreeing, with the document backing the weaker one.

**A skip reports GREEN.** So a fixture root that could not be written — the one condition the check
exists to catch — becomes the one condition nobody sees, and the ten assertions below it silently
test the developer's own content root instead of the fixtures. That is the same "passes because it
found nothing" failure T5.27 guarded the seven checkers against **one row earlier**, and
`CHANGELOG.md` has called it worse than no gate since `4.3.1`. The document changed; the code that
was already right did not.

**The plan gate caught the arithmetic before the suite could hide it:**

```
--- bag_mirror_test: 11/10 ---
bag_mirror_test planned 10 outcomes and produced 11 — a crash, an early return or a stale plan
=== 2292 passed, 1 failed, 0 skipped ===
```

An assertion is one outcome where a skip was a substitute for ten, so `plan(10)` became `plan(11)`
with the reason in a comment beside it. **14 of 16 call sites still discard the return**; converting
them is not this row and the honest state is recorded rather than implied.

### NO NEW GATE, AND SAYING SO IS PART OF THE ROW

`record_shape_test.gd` asserts every document opens with its own title and every package the log
records is findable in both the board and the roadmap; `docs_test.gd` asserts every `res://` path
any document names resolves. **An ADR is covered by both**, and it gains a package id that
`record_shape_test.gd` will now require in both files.

**Inventing a gate to have one is what T5.24 through T5.27 spent four rows learning not to do**, and
this row's subject is a distinction that is prose by nature. The structure is gated; the judgement
is review's, permanently, and that is the correct division rather than a gap.

### THE HONEST LIMIT, LEFT OPEN DELIBERATELY

**"A conversation is not saved" — the example `TEMPLATE.md` itself named — is classified but not
resolved.** By the seam test it is currently a TEMPLATE RULE: `dialogue_runner.gd` warns and refuses
on `_collect_save`, and a game wanting resumable conversations would have to edit `src/`. But its
stated reason is a good one — it keeps every dialogue node id private rather than promoting it to a
permanent save identifier — and whether the right answer is "rule, and say so" or "default, and add
the seam" is a judgement about a system this row is not otherwise touching. **Recorded so the next
reader finds a stated question rather than an unexamined absence**, which is the same fix this row
applied to `Cutscenes`.

### VERIFIED

Twelve rungs and seven checkers green on `4.7.2.stable.official.ed1daf0bf`. Boot `0 warnings, 0
errors`.

**CI GREEN — RUN [`34361451615`], BOTH JOBS.** Job logs read rather than the tick, per gotcha 26.

| job | result | last line |
|---|---|---|
| `Ladder (full checkout)` | success | `=== 2294 passed, 0 failed, 0 skipped ===` |
| `Ladder (stripped template)` | success | `=== 2220 passed, 0 failed, 25 skipped ===` |

Full is byte-identical to the local measurement. `docs/TESTING.md:13-14` carries both.

**The stripped gap is 74 for the fifth recorded run running** — 2,294 − 2,220. It has now held
across `1625`/`1551`, `2276`/`2202`, `2287`/`2213` and this pair, and it survived a row that added
an assertion to a case which uses fixtures rather than demo content. **Still nothing enforces it**:
`ladder.yml` asserts only that the named-skip count is non-zero, and the cross-job comparison
remains a recorded candidate rather than a mechanism.

## 2026-09-09 — T5.29 · The player prefab was a rule pretending to be a default

**ADR-0007 FOUND THIS WITHIN AN HOUR OF EXISTING, AND THAT IS THE ROW'S BEST ARGUMENT FOR ITSELF.**
T5.28 was a documentation row whose whole product was a distinction, and the standing objection to
it — five times over — was that it is prose and cannot be proved by running the engine. It cannot.
What it *can* do is find things, and the first thing it found is a defect no audit had caught: five
read-only audits over this repository, run the same day, all missed it. The critic arguing the base
was already finished found it while trying to prove nothing was left.

### THE DEFECT

`src/core/boot/game_root.gd:28`:

```gdscript
const PLAYER_SCENE: String = "res://scenes/characters/player.tscn"
```

Engine code, in the **`core`** layer — the layer whose entire promise is that it knows nothing
about the game — naming the prefab a consuming game replaces **first**. `GameConfig` exposed
exactly two `[game]` keys, `world/first_area` and `world/first_spawn`, with no `player_scene`
among them. `ARCHITECTURE.md` states the contract in as many words:

> a game adds content and resources; it does not add code under `src/`.

So a game whose protagonist has a different shape — a different rig, different components, a
different collision profile — **had no legal way to get one.** Its options were to edit `src/` or
to abandon the upgrade path.

**By ADR-0007's test this is a template RULE wearing a template DEFAULT's clothes.** The test is
one question, *does a seam exist?*, and it is a fact about the repository rather than a matter of
tone. The answer here was no, and nothing in the record said so — `NEW_GAME.md` § 2 listed the
player among prefabs to "Keep, and never edit", which reads as a default and functioned as a rule.

### THE COMPARISON RUN, WHICH IS WHAT MAKES IT A DEFECT RATHER THAN A PREFERENCE

Same plant both times: `[game] world/player_scene` pointed at a scene that does not exist, then
`--headless --quit-after 60`.

| run | code | result |
|---|---|---|
| control | new seam, real path | `Session ended after 2.9s — 0 warnings, 0 errors` |
| plant | new seam, missing path | `[ERROR] [boot] Player scene missing or invalid at res://scenes/characters/no_such_player.tscn` · **`0 warnings, 1 errors`** |
| comparison | **old `const`**, same missing path | `Session ended after 1.0s — 0 warnings, 0 errors` |

**THE COMPARISON IS THE ROW, AND THE PLANT ALONE WOULD HAVE BEEN THE WRONG EVIDENCE.** The plant
shows the error path works — which it always did; `Log.error("boot", …)` was already there. The old
run shows there was **no path at all**: the key a game would naturally set was read by nothing, so
a stated choice was discarded in silence and the template's own player spawned regardless. That is
the third row running where the old code against the new plant is the only run that says what was
broken, and it is becoming the house method rather than a trick.

**A note on how the comparison was obtained**, because it is worth not repeating: the work was set
aside with `git stash push -u`, which took the plant with it and left the tree at `main` — which
happened to be exactly the old-code state the comparison needed. Convenient here, and it also
means the restore brought the *planted* `project.godot` back, which had to be corrected by hand.
A WIP commit would have been the cleaner instrument.

### THE FALLBACK IS THE ONE ASYMMETRY, AND IT IS DELIBERATE

`world/first_area` has **no** fallback. `GameConfig`'s own header explains why: *"Empty is a real
answer — a template with no game in it yet — and `Director` reports it rather than loading nothing
and going quiet."*

`world/player_scene` **does** have one, because a game can never legitimately have no player. An
unset key must not mean `load("")` and a silently empty world, so it means the template's own
prefab. Stating the asymmetry in both places is what stops a later reader "fixing" one to match
the other.

**And the default may live in `src/` at all only because of a classification**: `scenes/characters/`
is **Engine** per `TEMPLATE.md`'s "What is what" table, so `GameConfig` naming that path is engine
naming engine. The `const` in `core` was not the same thing in a different place — `core` knows
nothing about the game *by contract*, and `game_root.gd` is `core`.

### WHAT DID NOT HAPPEN

**`game_root.gd` did not grow: 26 of its 60-line hard budget before and after.** That file's header
is unusually emphatic — `HARD BUDGET: 60 CODE LINES. READ THIS BEFORE ADDING ANYTHING`, and it
records that *"the previous project's equivalent file reached 3,983 lines, because a root node is
the most convenient place to put anything and every feature took the convenience."* This row moved
a path out and a local variable in. It added none of the four things that file is allowed to do.
`game_config.gd` went 26 → 32 of its 250.

**No new autoload, no ADR needed, no enum touched.** `GameEnums` is append-only because ordinals
live in `.tscn` files, and nothing here needed one.

### TWO STALE COUNTS FELL OUT OF IT

Neither is gated, and both are T5.25's class — a number in prose that nothing re-measures:

- **`GameConfig`'s own header** claimed it owned *"the **four** facts a game author writes once and
  never changes."*
- **`SYSTEMS_INVENTORY.md`** claimed *"the **four** values a consuming game sets in project.godot:
  first area, first spawn, name, slug."*

Five, now, in both. Worth noting that the file being edited was the one whose header held the wrong
count — a row that adds a fact to a list is the most likely row to leave the list's own count
behind, and the only defence is looking.

**And `NEW_GAME.md` § 2 gained the one exception to "Keep, and never edit to start a game."** The
section is right and stays right: a fork does not edit `scenes/characters/player.tscn`. It now
*points past* it, which is the instruction the section always implied and could not previously be
obeyed.

### VERIFIED

Twelve rungs and seven checkers green on `4.7.2.stable.official.ed1daf0bf`. Boot
`0 warnings, 0 errors`. Suite `=== 2300 passed, 0 failed, 0 skipped ===`, exit 0.
`check_budgets`: 167 files, 15,862 code lines, 0 violations.

**Suite 2,294 → 2,300, and I predicted +5.** Accounted per case: `core_test` 55 → 58 for the three
seam assertions, `record_shape_test` 129 → 131 for this entry's own package id, and **`docs_test`
121 → 122, which is the one I did not predict.** No new case and no new file — the existing
`_game_config()` block already had the exact shape this needed (read configured, assert, set null,
assert fallback, restore), so extending it was cheaper than a new case and keeps the seam's
assertions beside the two it is asymmetric with.

**AND `docs_test.gd` REFUSED THIS ROW TWICE FIRST, ON A RULE I DID NOT KNOW IT ENFORCED:**

```
FAIL CHANGELOG.md names res://scenes/characters/my_protagonist.tscn, which exists — expected true, got false
FAIL ROADMAP.md names res://scenes/characters/no_such_player.tscn, which exists — expected true, got false
```

**Every `res://` path a document names must RESOLVE.** So a document may not print an illustrative
path — my `CHANGELOG` example invented `my_protagonist.tscn` to show a fork what to write — and it
may not quote a plant path, which by definition must not exist. Both are now written without the
`res://` prefix, and the changelog's example shows the template's own real path with the swap
described in prose instead. `docs/DEVLOG.md` is exempt (`file_name != HISTORY`), which is why this
entry may quote the plant's output verbatim while the other three documents may not.

**That is the second time in three rows a gate has caught this row's own record rather than its
code** — T5.28's version gate caught a bold semver in its own narrative, and this is the same shape:
**a row that writes about paths and numbers is the row most likely to break the rules about paths
and numbers.** The +1 in `docs_test` is the same coin's other side: the corrected example is itself
a new `res://` occurrence to verify, so writing the fix moved the total.

### GAPS

- **The `**Commit:**` line shipped without its SHA for the fourth row running**, and at four it is
  evidence about the checklist rather than about four sessions: board item 6 asks for a commit that
  the act of satisfying item 6 creates. Filling in the previous row's line each time works and is
  what happened again here. **A checklist that cannot be satisfied in the order it is written
  should say so**, which is a one-line change to the board and not this row.
- **P2 is next and this row makes it cleaner.** Performing the extension surface from outside
  `src/` was always going to rediscover the player scene as its first finding; now it will not, and
  what it finds will be new. The predictions still standing for it: no document table has a row for
  game *code*, `ScreenKeys.menu_for()` is a closed `if`-chain over the eight template screens,
  `[game]` is still small and `GameConfig`'s MUST NOT forbids it becoming a settings store, and
  `scenes/boot/game_root.tscn` is Engine so a session-lived game service has nowhere to live.
- **`src/systems/scene_director/director.gd` is still at 187 of its 190**, sixth row running.

**CI GREEN — RUN [`34366063240`], BOTH JOBS.** Job logs read rather than the tick, per gotcha 26.

| job | result | last line |
|---|---|---|
| `Ladder (full checkout)` | success | `=== 2300 passed, 0 failed, 0 skipped ===` |
| `Ladder (stripped template)` | success | `=== 2226 passed, 0 failed, 25 skipped ===` |

Full is byte-identical to the local measurement. `docs/TESTING.md:13-14` carries both.

**The stripped gap is 74 for the SIXTH recorded run running**, and this row is the one that could
plausibly have moved it: the new `[game] world/player_scene` key is read on the boot path, and the
stripped job deletes `data/` and `scenes/areas/` but not `scenes/characters/`, so the fallback and
the key resolve identically in both jobs. It held. Still enforced by nothing — `ladder.yml` asserts
only that the named-skip count is non-zero, and the cross-job comparison is still a candidate row
rather than a mechanism.

## 2026-09-10 — T5.30 · Performing the extension surface, the one consumer document never walked

**`SYSTEMS_INVENTORY.md` listed four consumer documents and three of them had been performed.**
`AUTHORING.md` was walked at T2.2 and again at T4.2 and found eleven defects between them.
`TESTING.md` was walked at T4.4 and found a listed case that did not parse. `NEW_GAME.md` and
`UPGRADING.md` were each performed against real forks. **The extension surface — the table that
tells a consuming game what it may subclass — had never been walked by anyone.**

### THE VENUE IS THE METHOD, AND A DRAFT OF THIS ROW GOT IT WRONG

The plan for this row said "declare a game-owned code root, add it to the scan roots of the
checkers that should see it, then subclass three things from it". **That would have committed a
consuming game's proof into the template**, and made the base ship the very thing it tells a fork
to own.

The precedent settled it before it cost anything, and it is written down twice:

> Everything below was PERFORMED, not designed. **A stripped fork was made** … The versions 1.1.0
> and 1.1.1 below are SYNTHETIC. They exist only in **the throwaway repositories this document was
> performed against**. — `UPGRADING.md:12,17`

> the whole strip above was **performed against a fresh clone**. — `NEW_GAME.md:187`

**A performance happens OUTSIDE the template and only findings come back.** So: a throwaway clone
of the base at `5.4.0`, a `game/` root added in it, `Interactable`, `UiScreen` and `Inventory` each
subclassed there, the full ladder run, and **nothing from the fork committed here.** The fork is
gone.

### FINDING 1 — THREE ROWS NAMED A CLASS AND GAVE NO PATH

The Tier 2 table has six rows. The `Events` row names `src/core/events/events.gd`. The three rows
that tell a consumer to **subclass** something named `Interactable`, `UiScreen` and `Inventory` and
gave no path at all.

So `UiScreen` was looked for in `src/ui/root/`, which is where `UiRoot` lives and where a reader
would reasonably expect the screen contract to sit beside it. It is not there:

```
$ grep -rn 'class_name UiScreen' src/
src/ui/screens/ui_screen.gd:1:class_name UiScreen
```

**The only places in the repository that name that path are `DEVLOG.md` — which `CLAUDE.md`
forbids reading whole — and a "Read:" manifest for WP-12, an old package.** Every row now names its
file, and the `UiScreen` row says explicitly *not* `src/ui/root/`.

### FINDING 2 — THE OVERRIDE HOOKS WERE DESCRIBED AND NEVER NAMED

`ui_screen.gd`'s header describes three overrides in prose — *"Override to construct contents"*,
*"Override for work that must happen each time the screen reaches the top of the stack"*,
*"Override for work that must happen when the screen leaves the stack"* — and the Tier 2 table
mentioned only `_build`. Writing the subclass, the second hook was guessed as `_on_shown()`.

**`_on_shown()` compiles, parses, passes every rung, and never runs.** GDScript has no
`@override`, so a misnamed override is a silent no-op — the exact shape of defect this project
keeps finding, and here the document was the cause. The real names are `_build()`, `_opened()` and
`_closed()`, now in the table beside what each is for.

### FINDING 3 — ALL SEVEN CHECKERS PASS OVER A GAME CODE ROOT

The fork's `game/` root held three subclasses. All seven checkers exited 0. That alone proves
nothing — the code was fine. So it was planted:

```gdscript
## A PLANT: a raw player-facing string literal, which non-negotiable #3 forbids and
## check_strings.gd exists to catch. Also a public method nothing calls, which
## check_methods.gd exists to catch.
func announce() -> String:
	return "The bell tolls for thee"
```

```
  check_strings   exit=0  PASS
  check_methods   exit=0  PASS
  check_budgets   exit=0  PASS
  check_boundary  exit=0  PASS
  check_layers    exit=0  PASS
```

**One violation of non-negotiable #3 and one uncalled public method, and every gate built to catch
them passed.** They scan `src/`, `tests/` and `tools/`; a game's root is none of those. **A
consuming game inherits none of the ladder's discipline**, and the base never said so.

**Two of those gates should stay blind, and calling that a relief rather than a gap is the point.**
`check_boundary.gd` exists to prove *the engine* does not know the game's content exists — its own
header, line 10. A game's own code is entitled to name its own ids; that is what a game root is
FOR. Pointing that gate at it would fail an author for doing the right thing, and the draft plan
had proposed exactly that.

The other five are now **a stated choice**: a fork decides whether to point `check_strings`,
`check_methods` and `check_budgets` at its own root. Nothing decides it, nobody had noticed the
question, and nobody could have — it takes a fork to ask it.

### FINDING 4 — NO DOCUMENT HAD A ROW FOR GAME CODE

`TEMPLATE.md`'s "What is what", `NEW_GAME.md` § 2 "Keep, and never edit", and `UPGRADING.md` § 5
"The three classes of file" are the three tables that classify every path in the repository. **None
had a row for a game's own code**, while Tier 2 tells a game to `extends Interactable`. So a
consumer following the extension surface produced a file with no stated class, no stated merge
behaviour, and no stated home. Each table gained a row.

### FINDING 5 — A GAME'S OWN INPUT ACTION CANNOT BE PLAYER-REBINDABLE

A game may declare its own action with Godot's `InputMap.add_action()` and bind it in its own code.
It cannot make that action reboundable by the player: `KeyBindings.rebind()` refuses any action
absent from `Actions.REBINDABLE`, a `const Array[StringName]` in `src/`, and `rebind_screen.gd:71`
builds its rows by iterating the same const.

**And the constraint is CORRECT, which is why it is recorded rather than fixed.** From
`key_bindings.gd`'s own header:

> THE GATE IS `Actions.REBINDABLE`, NOT `InputMap.has_action`, AND THE DIFFERENCE WAS A BUG. Until
> T5.5 this asked only whether the action EXISTED, so `debug_console` or `cam_zoom_in` could be
> overridden and written to input.cfg — and then `reset_bindings()` re-declares only the four
> rebindable groups, so nothing put the erased default back.

So this is a real tension — gate rebinds to a known-pollable list, or let a game have its own
actions on the rebinding screen — not an oversight. The consequence is now stated in the table so a
game plans around it instead of finding out.

### FINDING 6 — TWO AUDIT PREDICTIONS WERE WRONG, AND THAT IS THE ARGUMENT

The audit that scoped this row predicted, with file and line numbers, that a game's own screen
could not register: *"`ScreenKeys.menu_for()` is a closed if-chain: `menu_for()` names the eight
template screens by class"*. **It is a closed if-chain, and it is irrelevant.**

- `UiRoot.open(screen: UiScreen)` takes an **instance**, not an id.
- `UiRoot.find(from: Node) -> UiRoot` finds the stack by GROUP, not a hard-coded path — its header
  says so: *"Anything may find the stack with `UiRoot.find(node)` rather than a hard-coded scene
  path."*
- So `UiRoot.find(self).open(MyScreen.new())` is the whole of it, and no registration exists to be
  missing.
- `menu_for`'s **only** callers are in `src/systems/debug/dev_screens.gd`, which is the
  boundary-exempt debug directory. It serves `--open-menu=<id>` for screenshots.

The audit was reading the right files and drawing the wrong conclusion, and **only a fork could
tell the difference.** That is the case for performing over predicting, delivered as two
retractions rather than as an argument.

### AND THE CLOSING CHECKLIST IS FIXED AT THE SOURCE

Item 6 — *"This file marks the package DONE with its commit"* — has been worked around for **five
consecutive rows** by filling in the previous row's SHA. At five that is not five lapses; **the step
asks for a commit that satisfying the step creates**, so it can never be true when written. It now
says to write the line with the branch and PR, and to fill the SHA in the next row, which is what
has actually happened every time. The alternative — a second commit per package purely to amend one
line — buys nothing a reader wants.

### VERIFIED

Twelve rungs and seven checkers green on `4.7.2.stable.official.ed1daf0bf`, in this repository.
Boot `0 warnings, 0 errors`.

**And separately, the fork's own ladder** — which is the evidence for finding 3: rung 2 clean on
the second import, boot `0 warnings, 0 errors`, and all seven checkers exit 0 both before and after
the plant. **A fresh clone reports `Cannot open file 'res://localization/strings.en.translation'`
four times on its FIRST import and zero times on the second**, because `*.translation` is generated
and gitignored. `CLAUDE.md` already says to run `--import` first on a fresh clone; it does not say
that first run is noisy, and a consumer meeting four ERROR lines on step one has no way to know
they are expected. Recorded here; not worth a row on its own.

### GAPS

- **Whether a game root should inherit `check_strings`, `check_methods` and `check_budgets`** is
  now a stated choice and nobody has made it. It is a real decision with a real cost either way,
  and it belongs to whoever forks first.
- **`Actions.REBINDABLE` versus a game's own actions** — recorded above, correct as it stands, and
  a template change if a game needs it.
- **The `game/` root is a suggestion, not a convention.** The base names none, and the three tables
  now say "`game/`, or scripts beside your areas" rather than mandating one. If two forks pick
  differently that is fine; if the base ever wants to scan it, that has to be settled first.
- `src/systems/scene_director/director.gd` is still at 187 of its 190, seventh row running.


## 2026-09-10 — T5.31 · Clock and Weather on the flag surface

**Did.** Published `Clock` and `Weather` onto the flag surface through the existing
`Flags.declare_derived` seam, so an authored dialogue condition or quest step can ask what time it
is. Four keys: `time/hour` and `time/day` as ordered ints, `time/phase/<name>` and
`weather/kind/<name>` as one bool each under the lowercased enum name, exactly one row existing at
a time. New case `tests/unit/time_flags_test.gd`, 27 assertions. Also fixed
`QuestTracker.ids_in_state`, which this row surfaced as an unfixed site of gotcha 33, and the
`item_count_test.gd` helper that was coupled to the broken order. `5.4.1` → `5.5.0`, a MINOR.

**Why.** `Clock` held the day, the hour, the minute and the phase, emitted four signals, and never
once called `Flags.set_flag`. `src/core/state/flag_query.gd` is the ONE evaluator both
`DialogueNode` and `QuestStep` go through and it reads `Flags` and nothing else — so no authored
condition in the base could mention time or weather at all, including the shop hours `clock.gd`'s
own header names as a reason a clock is foundational. Two independent audits converged here and it
was their only convergence.

**The unpriced cost, and both answers the plan offered were wrong.** The plan said publish enum
ordinals and state the coupling, or publish stable string names.

Ordinals do couple, because `GameEnums` is append-only precisely so its numbers can live inside
authored `.tscn` files. But the sharper objection is that ordering on a phase is meaningless
whatever the numbering, and a probe measured it: `phase_for_hour` across a day gives

```
00:6 01:6 02:6 03:6 04:6 05:0 06:0 07:1 08:1 09:1 10:1 11:2
12:2 13:2 14:3 15:3 16:3 17:4 18:4 19:4 20:5 21:5 22:5 23:5
```

`DEEP_NIGHT` is the highest ordinal and the earliest hours, so `AT_LEAST DUSK` holds at 00:00 and
fails at 06:00. Equality is the only sound question about a phase.

And a plain string name would have been unreadable by the one evaluator, which a second throwaway
probe measured rather than argued:

```
PROBE equals-on-string:  false     [flags] probe/phase is String, expected int
PROBE is_true-on-string: false     [flags] probe/phase is String, expected bool
PROBE equals-on-int:     true
PROBE is_true-on-bool:   true
```

The closed set compares bools and ints and nothing else. Publishing names as strings would have
shipped four flags that looked right in a debug dump and answered nothing, and no gate in this
repository would have caught it, because writing a flag is not the same claim as its being askable.
That is why every assertion in the new case goes through `FlagQuery.passes` and not
`Flags.get_int`.

So the third answer, which the plan did not consider: ints where ordering means something, and a
bool under the name where only equality does. No seventh comparison added to a set whose own file
says it stays closed. Erase-not-set-false, following `Inventory`, so one row exists per concept
rather than seven and fifteen; the erase runs before the set, because a phase flag left true would
make an authored dawn-only line fire at every hour after the first dawn.

**Connects.** `Flags.declare_derived` (T3.3, `inventory.gd:59`) — second caller, and both of that
file's store-wipe subscriptions came across with it, since `Director.start_new_game` clears the
flags and then emits `game_started` while `Flags._apply_save` clears a store whose derived keys are
deliberately absent from the file it restores from. `FlagQuery` (WP-08) unchanged: the point of the
row is that nothing about the evaluator had to move. `bag_mirror_test.gd` (T5.28) is the shape of
the ordering assertions. ADR-0007 is why time was in scope at all and why a calendar is not.

**Verified.** Twelve rungs, from a fresh worktree with `--import` first (gotcha 53).

| rung | result |
|---|---|
| `--check-only` per file | clean; only the expected `Identifier not found: SaveSystem` |
| `--headless --import` | no `SCRIPT ERROR`, no `Parse Error` |
| `--headless --quit-after 30` | `Session ended after 0.8s — 0 warnings, 0 errors` |
| `test_runner.tscn` | `2331 passed, 0 failed, 0 skipped`, exit 0 |
| seven checkers | each exit 0, each `PASS`, zero `SCRIPT ERROR` lines |
| windowed capture | `Captured 960x540`, `0 warnings, 0 errors`, HUD reads `Day 1 | 18:40 | Dusk`, and the PNG was looked at |

Boot publishes exactly four rows, which is the claim rather than an inference:

```
[flags] time/day = 1
[flags] time/hour = 6
[flags] time/phase/dawn = true
[flags] weather/kind/clear = true
```

**The plant, one path red and the other green.** Publishing removed from the `set_time` path only:

| run | result |
|---|---|
| control | `2331 passed, 0 failed`, exit 0 |
| plant | exit 1, `2329 passed, 2 failed` |

The two failures are both on the jump path — *"a jump onto the hour opens it — expected true, got
false"* and *"and the flag was current inside that one too — expected 14, got 11"* — and the `11`
is the value the tick path had published, which is what makes it a plant that separates the two
publish sites rather than one that breaks everything. `set_time` is not a corner: a sleep, a
cutscene, a debug command and a loaded save all route through it.

**Assertion delta, measured twice and not predicted — and the first measurement was wrong.**
Baseline on `main` at `5.4.1`: 2,302. Final: **2,331**, so **+29**.

The run taken straight after the code landed read **2,329**, with a per-case diff of one line:

```
46a47
> time_flags_test: 27
```

That number is what a lazier version of this entry would have recorded, and it would have been
wrong by three. Re-running after the documentation landed:

```
41c41
< record_shape_test: 133
---
> record_shape_test: 135
46a47
> time_flags_test: 27
```

**`record_shape_test` moved by two, and the cause is arithmetic rather than a surprise:** its plan
is `plan(_docs.size() + _packages.size() * 2 + 2)`, so adding one package id to the board is worth
exactly two outcomes. Accounted per case, which is what the house rule asks for: 27 new case + 2
record shape = 29.

This is the same trap the previous two rows fell into — one predicted +2 and measured +4, the other
predicted +5 and measured +6, both because their own prose added something a computed plan counts.
The only defence is to measure after the record is written, not before, and to diff per case rather
than read the total.

**CI, read out of the job logs rather than off the green tick (gotcha 26).** Run
`34451843653` on `claude/t5-31-time-flags`, PR #62, both jobs `success`:

| job | result |
|---|---|
| Ladder (full checkout) | `=== 2331 passed, 0 failed, 0 skipped ===` |
| Ladder (stripped template) | `=== 2257 passed, 0 failed, 25 skipped ===` |

**The stripped gap is 74, which is the seventh consecutive recorded run at exactly 74.** Nothing
enforces that number — no assertion compares the two jobs, and `check_content.gd` is deliberately
exempt from the empty-scan guard because the strip deletes its whole input by design. So the gap
holding is an observation each row has to make by reading both logs, not a gate; T5.27 named the
cross-job comparison as a candidate and it is still a candidate. Worth noting that 27 new
assertions landed in the full job and the gap did not move, which is the right answer: the new case
builds nothing from `data/` or `scenes/areas/`, so it survives the strip intact.

**What the row surfaced: gotcha 33, at the one site nobody had fixed.**
`QuestTracker.ids_in_state` sorted with `Array[StringName].sort()`, which orders by interned handle
rather than alphabetically. `area_db.gd`, `equipment.gd` and `inventory.gd` each already carry a
note about it and each already sort through `String`; this function was missed, and its own doc
comment claimed *"Sorted, so the journal draws a stable order without holding one of its own."* It
was the allocator's order. Publishing four new flag names shifted the intern table and a journal
assertion in `item_count_test.gd`, on a code path this row never touched, went red:

| `src/` | `ids_in_state(ACTIVE)` returned |
|---|---|
| baseline | `[quest/fixture_gather, quest/fixture_errand]` |
| with this row | `[quest/fixture_errand, quest/fixture_gather]` |

The baseline is the order that is not alphabetical, so the failure looked like the new code's fault
and was the old code's. **Two wrong hypotheses died before the right one, and both were cheaper
than the three rounds of guessing that preceded them.** First a timing race, on the theory that
`Clock._process` was waking `QuestTracker` through `flag_changed` mid-block — killed by the failure
being deterministic across three runs. Then pointer-ordered sorting, which a two-element probe
appeared to disprove:

```
PROBE StringName sort: [&"aaa_probe", &"zzz_probe"]
```

That came out alphabetical **by luck** — two elements have even odds — and the eight-element probe
is what confirmed the cause:

```
PROBE StringName sort: [alpha, delta, echo, foxtrot, charlie, bravo, hotel, golf]
PROBE String sort:     [alpha, bravo, charlie, delta, echo, foxtrot, golf, hotel]
PROBE orders agree: false
```

Fixed with the same `sort_custom(_before)` the other three files use. The test helper stopped
returning "the last Label in the list" — a bet on an order the base never promised — and now
addresses a named quest through its own row; its old comment guarded the right way against the
wrong risk, saying it found the row by type rather than index so a heading could not mislead it,
while the order of the quests was the unexamined thing.

Recorded as **gotcha 79**, not folded into 33, because the lesson is different: 33 says sort
StringNames through `String`, and 79 says a gotcha with a note in three files is not a gotcha that
is fixed — grep for the pattern, not the note; suspect the untouched file when a change in one
system reddens an assertion in another; and do not prove a cause on two data points.

**Unblocks.** Any authored content that wants to be time- or weather-gated, with no code: shop
hours, a night-only conversation, a quest step that waits for rain. And P4, the optional
day-of-cycle row, which needs `time/day_of_cycle` published the same way and now has the shape to
copy.

**Gaps.** `clock.gd` is at 142 of its 150-line budget, the tightest it has been — the next change
to it will likely need a split or a justified budget, and `docs/ARCHITECTURE.md` § Line budgets is
where that argument goes. No `time/minute` (a continuous value for a lighting gradient, not a
question a condition asks, and it would rewrite a flag 1,440 times a day). No calendar, weekday,
month or season — ADR-0007 game choices. `rest_point.gd` deliberately untouched: it reads an
authored `@export var night_only` and calls `Clock.is_night()`, and `traversal_test.gd:95` asserts
exactly that, so rewriting it would strip an `@export` from authored `.tscn` instances. Shop hours
still take two conditions, because a quest step and a dialogue node each carry one; a game wanting
both on one line writes a small listener in its own code root, and the base deliberately grows no
expression language for it.

## 2026-09-10 — T5.32 · A schedule could only describe one day

**Did.** Gave `Clock` a `days_per_cycle` export (default 7), a public `day_of_cycle()` returning
`(day - 1) % maxi(1, days_per_cycle) + 1`, and a fourth derived flag `time/day_of_cycle` published
from `_publish_time()`. Gave `ScheduleEntry` an `on_day_of_cycle` export, `@export_range(-1, 30, 1)`
defaulting to `-1` for "every day". Gave `NpcSchedule.entry_for_hour` a second argument
`on_day: int = -1`, with two private helpers — `_applies_on`, which admits an entry when its day is
`-1` or matches, and `_outranks`, which prefers a later hour and, at the same hour, prefers the
day-specific entry. Re-keyed `NpcSchedule.problems()`'s duplicate check from the hour to the pair
`Vector2i(from_hour, on_day_of_cycle)`, and added a check for a day below `-1` in
`ScheduleEntry.problems()`. Pointed `NpcBrain.decide_for_hour` and `snap_to_hour` at
`Clock.day_of_cycle()`. Added a third fixture schedule entry that collides with the morning block
on the hour and differs only by day, plus `MARKET_DAY` / `ORDINARY_DAY` constants and an optional
day parameter on `FixtureContent._entry`. Eleven assertions in `npc_test.gd` across two new
functions, eight in `time_flags_test.gd`. `5.6.0`, a MINOR.

**Why.** `ScheduleEntry` exported `from_hour` and nothing else, so an hour was an entry's whole
address and `entry_for_hour(hour)` was the whole lookup. Every NPC in every game built on this base
therefore repeated one identical day, forever, and a market day — or a temple busy one day in
seven, or a character who takes a day off — was not badly supported but inexpressible, with nothing
in the repository saying so.

**This row was explicitly optional and was built on the owner's answer, not on inference.** The
plan rated it non-blocking and named it "the honest place to stop early if you want to", with every
other planned row done. It was put to the owner as a three-way choice — build it, close it by
written refusal, or defer it and start a game — and the answer was to build it in full. Recording
that because the row exists by decision, and a later reader should not read it as a board row's
momentum.

**In scope only because of ADR-0007.** Its seam test puts a cycle *length* on the template-default
side (a formula: one number, one modulo) and a *calendar* on the game-choice side. So this adds
`days_per_cycle` and adds no weekday names, no months, no seasons and no date type, and the refusal
is as much of the deliverable as the feature. `rest_point.gd` was not touched — it reads an authored
`night_only` and calls `Clock.is_night()`, which `traversal_test.gd:95` asserts exactly, and an
earlier draft's claim that it hardcodes the hour was false.

**Connects.** T5.31's seam, verbatim, and that is the point of having built it: `time/day_of_cycle`
goes out through `Flags.declare_derived` from `_publish_time()`, which runs on both the tick and the
jump path before their emits, plus `_republish()` on `game_started` / `game_loaded`. Adding a key
was one line there and nothing else. ADR-0007 supplies the scope boundary. `GameEnums`' append-only
discipline is the precedent for `-1` as the default. `check_layers.gd` is why nothing in `content`
validates a day against the real cycle length.

**AN ORDERED INT, NOT A BOOL-PER-NAME — a departure from T5.31 one row later, and stated rather
than drifted into.** T5.31's argument for names is entirely about a PHASE and rests on two
properties: an enum behind it, and a day wrapping where an enum does not, so `AT_LEAST DUSK` holds
at 00:00 and fails at 06:00. A day of the cycle has neither. No enum to be inserted into, and no
wrap inside its own range, which runs `1` to `days_per_cycle` and stops. So `EQUALS 3` is a market
day and `AT_LEAST 5` is the back half, and both mean what an author expects. The `AT_LEAST 4`
assertion in `time_flags_test` is one that could not have been written at all under the phase's
shape, which is the difference asserted rather than argued. The bool-per-name shape would also have
cost `days_per_cycle` rows in the store to answer what one int answers.

**The default does the work twice, and that is what makes this a MINOR.** On the field, `-1` means
every day, so every `.tres` authored before the field existed resolves exactly as before with no
edit and no migration. On the argument, `-1` means "no particular day" and only every-day entries
are considered, so an existing `entry_for_hour(hour)` call site still compiles and still answers.
What it deliberately does not mean is "any day": that reading would leak a day-specific block into
every day — the defect arriving through the fix — and there is an assertion on exactly that.

**The validator had to change with the lookup, and this is the one that was nearly missed.**
`problems()` keyed its duplicate check on the hour alone. Left that way, the very fixture proving
the feature works would have been reported as malformed content, and `check_content.gd` would have
failed the build on correctly authored data. Keyed on the pair, a market day is legal while a
genuine collision — two entries agreeing on hour AND day — still is not, because that one remains
ambiguous in the old array-order way. The message now names the day so an author can tell which of
the two blocks to move.

**A stated cost, and it is a layering consequence rather than an oversight.** Nothing validates a
day against the real cycle length: `on_day_of_cycle = 9` on a seven-day cycle parses, loads, passes
every checker and is simply a block that never runs. `NpcSchedule` and `ScheduleEntry` are in
`content` and may not touch an autoload, so no validator there can ask `Clock` how long the cycle
is, and `check_layers.gd` exists to refuse `content` reaching up into `systems` for a number. What
is checked is the case needing no autoload — a value below `-1`. A first draft of
`schedule_entry.gd`'s header claimed `NpcSchedule.problems` reported the over-range case; it cannot,
for the same reason, and the claim was corrected before commit rather than shipped as a comment
promising a check nothing performs. That is the same class of defect T5.27 found in a comment.

**THE PLAN'S BUDGET WARNING WAS WRONG, AND MEASURING BEAT BOTH REMEDIES.** `clock.gd` was at 142 of
its 150 code lines, and the plan warned an export plus a const plus a publish line would push it
over, with the answer required to be a split or a justified budget in `ARCHITECTURE.md` rather than
a quietly raised number. It landed at **147 of 150**. What would have cost the lines was a setter
that republishes on assignment — about four, taking it to 151 — and it was dropped on an argument
rather than to fit: `Director.start_new_game` emits `game_started` and `_republish` is connected to
it, so a value set before a game begins is published when it begins, and after that any tick
republishes within one in-game minute. The window a setter would close is one no caller can
observe, and `seconds_per_minute` has run without one since the file was written.

**The split was considered and refused on evidence.** The candidate was moving the flag projection
to a `ClockFlags` class, worth about ten lines. Two things killed it. `phase_flag`'s own header says
it is public *because it is the spelling an author writes into a dialogue condition*, so moving it
changes a consuming game's call site and would make this a MAJOR rather than a MINOR. And a grep
found `Clock.phase_flag`, `Clock.FLAG_DAY` and `Clock.FLAG_HOUR` have exactly one consumer between
them — `tests/unit/time_flags_test.gd` — so the split would have traded a real API break for a
number while splitting one concern across two files. `clock.gd` now has three lines of budget left,
and the next row to touch it genuinely does face the split. Written down here so that is not
rediscovered. *(T5.33 correction: this entry originally called that "the tightest any file in this
base has been". It was wrong twice — `director.gd` is at 187 of its raised 190 with the same three,
and `dev_stage.gd` was at 248 of 250 with two before T5.20 split it. `clock.gd` and `director.gd`
are the two tightest, three lines each.)*

**Verified.**

| rung | command | result |
|---|---|---|
| import, FIRST | `--headless --import` | exit 0, no `SCRIPT ERROR`, no `Parse Error` |
| type gate | `--check-only` on all seven changed files | only `Identifier not found: <Autoload>` — `SaveSystem`, `Log`, `Director`, `Flags` — the documented rung-1 gotcha, and the only diagnostic on each |
| boot | `--headless --quit-after 30` | `Session ended after 0.8s — 0 warnings, 0 errors` |
| suite | `tests/test_runner.tscn --quit-after 400` | `2355 passed, 0 failed, 0 skipped`, exit 0 |
| check_budgets | `--script tools/check_budgets.gd` | `PASS`, exit 0; `clock.gd 147 / 150` |
| check_content | `--script tools/check_content.gd` | `PASS`, exit 0 |
| check_boundary | `--script tools/check_boundary.gd` | `PASS`, exit 0 |
| check_strings | `--script tools/check_strings.gd` | `PASS`, exit 0 |
| check_layers | `--script tools/check_layers.gd` | `PASS`, exit 0 |
| check_signals | `--script tools/check_signals.gd` | `PASS`, exit 0 |
| check_methods | `--script tools/check_methods.gd` | `PASS`, exit 0 |
| capture | `--resolution 960x540 --shot-frame=70 --time=18:40 --freeze-time` | `0 warnings, 0 errors`; PNG inspected, shaded, HUD `Day 1 / 18:40 / Dusk`, NPC at its dusk post |

**The plant, run before the green and recorded from the run.** `_applies_on` reduced to
`return true`, which is the plan's instruction to ignore the day argument in the lookup:

| run | result |
|---|---|
| control | `2350 passed, 0 failed`, exit 0 |
| plant | **exit 1**, `2346 passed, 4 failed` |
| control, after restoring | `2350 passed, 0 failed`, exit 0 |

The four:

```
FAILED: an ordinary day gets the every-day block — expected fixture_post_a, got fixture_post_b
FAILED: so one hour resolves to two different places on two days — expected true, got false
FAILED: and the market block does not leak into a day-agnostic lookup — expected fixture_post_a, got fixture_post_b
FAILED: the day's first hour switches over — expected fixture_post_a, got fixture_post_b
```

**The fourth is the one worth keeping.** `the day's first hour switches over` lives in
`_the_night_shift_wraps_past_midnight`, a pre-existing assertion this row never touched. An older
invariant catches the same regression independently, which is the cheapest evidence available that
the new entry did not open a hole in the old behaviour — and it is the kind of thing a plant only
tells you if you read every failure rather than the count.

**The fixture is built so the failure cannot be argued.** The third entry collides with the morning
block on `from_hour` and differs only by day, so the hour cannot separate them and only the day can.
It reuses `EVENING_WAYPOINT` rather than inventing a third name, because
`npc_test._authored_waypoints_exist_somewhere` checks every waypoint a schedule names against every
area's `Waypoints/` markers. The two every-day entries are appended first on purpose: `npc_test`
derives its `first` and `latest` blocks by scanning for an extreme `from_hour` and keeps the
earliest match, so a fixture whose day-agnostic assertions depended on array order would be
measuring the fixture rather than the lookup.

**Gotcha 79 did not bite, and that is a result rather than an absence.** T5.31 filed it: publishing
new flag names interns new StringNames and shifts the intern table, reordering anything sorting
`StringName`s with `.sort()` (gotcha 33). This row published a new flag name and no assertion in a
file it never touched went red, which confirms T5.31's fix at `QuestTracker.ids_in_state` was the
last site. No new gotcha, so the list stays at seventy-nine and the four documents stating its
length are untouched.

**The assertion delta, measured and not predicted.** 2,331 → **2,355, +24**: 11 in `npc_test`
(68 → 79), 8 in `time_flags_test` (27 → 35), 2 in `record_shape_test` (135 → 137), whose plan is
`_docs.size() + _packages.size() * 2 + 2` so this package id on the board is worth exactly two
outcomes — and **3 in `doc_counts_test` (6 → 9), which this row did not see coming.** Measured by
diffing every case against `main` **after** the documentation landed; the pre-docs run read 2,350.

**AND THE SECOND COMPUTED PLAN CAUGHT THIS ROW OUT, WHICH IS WHY THE DIFF IS PER CASE AND NOT A
TOTAL.** +21 was written into the first draft of the record, from 11 + 8 + 2, and it was wrong by
two. The total alone would have said only that a prediction was off; the per-case diff named the
case in one line. `doc_counts_test._gather` appends a CLAIM for every line **outside** the gotcha
list that both mentions a gotcha and spells a number, then asserts each spells the list's real
length. This row wrote three such lines — the "gotcha 79 did not bite" sentences in `CONTEXT.md` and
the board — so it created three assertions about itself. All three spell `seventy-nine`, all pass, and
nothing needed fixing. T5.31 recorded that a row's own prose can add a claim a computed plan
counts, naming `record_shape_test`; this is the same effect in a second plan, and it is the whole
reason the measurement happens after the documentation lands rather than before.

**Unblocks.** Nothing, and that is the entry. **T5.32 was the last planned row, the board has no
open row, and no chip was created because there is nothing to hand off to.** Item 8 asks for a chip
so a handoff is automatic; the honest discharge of it here is to say in the board, the roadmap and
`CONTEXT.md` that the base is complete and the next thing to happen to this repository is a game
being started on it. `NEW_GAME.md` is that checklist. If a genuine defect surfaces while a game is
being built, that is the next row, and it will have been found rather than invented.

**Gaps, stated rather than left implicit.**
- A day past the end of the cycle is silently inert. Layering consequence, argued above, recorded
  in `AUTHORING.md` as the one trap in that section.
- `days_per_cycle` is an `@export` on a script autoload, so there is no inspector for it and a game
  sets it from code — the same as `seconds_per_minute`, which has been true since the clock was
  written and is not a new limitation.
- No UI shows the day of the cycle. The HUD still reads `Day N | HH:MM | Phase`. Adding a row to it
  is a game's presentation choice, and putting one in the base would have been the calendar this
  row refuses.


**CI, read out of the job logs rather than off the green tick (gotcha 26).** Run `34454905464` on
`claude/t5-32-day-of-cycle`, PR #63, both jobs `success`:

| job | result |
|---|---|
| Ladder (full checkout) | `=== 2355 passed, 0 failed, 0 skipped ===` |
| Ladder (stripped template) | `=== 2281 passed, 0 failed, 25 skipped ===` |

**The stripped gap is 74, the eighth consecutive recorded run at exactly 74.** Still nothing
enforces it — no assertion compares the two jobs, and `check_content.gd` stays deliberately exempt
from the empty-scan guard because the strip deletes its whole input by design. So the gap holding is
an observation each row makes by reading both logs, not a gate; T5.27 named the cross-job comparison
as a candidate and it remains one, and with the board now closed it is a candidate a *game* would
raise rather than a row here. **Twenty-four new assertions landed in the full job and the gap did
not move**, which is the right answer twice over: the two new test functions build their content
from `FixtureContent` rather than from `data/`, and the two computed-plan cases that grew —
`record_shape_test` and `doc_counts_test` — read `docs/`, which the strip does not touch.

**Re-run on the commit that actually merged, because the branch moved after the record above was
written.** `main`'s protection sets `required_status_checks.strict = true` — a branch must be
current with the base before it can merge — so once PR #62 (T5.31) landed, this branch was behind
`main` by exactly that merge commit and `main` had to be merged in. **A merge, not a rebase**, the
branch being pushed and shared. The tree came out byte-identical to before it, since this branch
already contained every T5.31 commit, and `git diff` between the two heads is empty. Run
`34456450946` on `b93c95d`, both jobs `success`, and the numbers did not move:
`=== 2355 passed, 0 failed, 0 skipped ===` and `=== 2281 passed, 0 failed, 25 skipped ===`, gap 74.
The full ladder was re-run locally on the merged commit as well — import clean, boot
`0 warnings, 0 errors`, suite 2,355 exit 0, all seven checkers exit 0 — because gotcha 53 says a
failure straight after a checkout is a cache question before it is a code question, and the cheap
answer is to ask the engine rather than to reason about the tree.

**No admin override was used, and the first refusal was a misreading worth recording.** An earlier
attempt at `gh pr merge 62` was refused as *"the base branch policy prohibits the merge"*, which
read as a required review. It was not: reading
`repos/<owner>/<repo>/branches/main/protection` shows two required contexts, `strict = true`,
`enforce_admins = false` and **no review requirement at all**. `mergeStateStatus` was `CLEAN` on
retry and the plain merge succeeded. So the refusal was transient — the required contexts had not
yet been attributed to the protection when the first attempt ran — and reaching for `--admin`
would have bypassed a gate that was about to pass on its own.

**And that is the last CI record on this board.** The base is complete at `5.6.0`.
**Commit:** on `claude/t5-32-day-of-cycle`, PR targeting `main`. No SHA, per board item 6 — the
commit that satisfies this step is the one this line goes into. With no next row to fill it in, it
stays as written, which is itself the record that this is the end of the board.

## 2026-09-10 — T5.33 · The audit of a base declared finished

**Did.** Audited the base one row after declaring it complete, and fixed what the audit found.
`NpcSchedule.problems()` now requires at least one entry at `on_day_of_cycle = -1`, with the
reasoning in its own header and in `schedule_entry.gd`'s. Five assertions in `npc_test.gd` across a
new `_every_schedule_must_cover_every_day`, plus a `_problems_mentioning` helper, plus one existing
assertion re-expressed. Corrected three documentation numbers, deleted a fourth, and fixed the
closing checklist that let two of them rot. `5.6.1`, a PATCH.

**Why.** T5.32 closed the board, declared the base complete and deliberately created no chip. The
owner then asked for a full check before starting a game on it. **The check found that the row
declaring the base finished had made a documented invariant violable, one day earlier.** Both halves
of that are the argument for auditing something you have just called done: the defect was new, and
the document that would have caught it was the one nobody re-read.

**The finding.** `schedule_entry.gd` has always promised, in its own header, that a day is *always
completely covered* — "The cost is that a gap in the day cannot be expressed - which is correct,
because an NPC is always somewhere." Before T5.32 that was not a convention but a STRUCTURAL fact:
every entry applied on every day, so `entry_for_hour`'s wrap-to-the-last-block fallback could never
come up empty. `on_day_of_cycle` made it violable by authored data for the first time, and nothing
in the repository noticed — not `problems()`, not `check_content`, not one of 2,355 assertions.

**Measured, not argued.** A throwaway probe under `--headless --script`, which works because
`NpcSchedule` and `ScheduleEntry` touch no autoload — the same property that makes them loadable by
`check_content`:

```
=== A: only day-specific entries, asked about a day that matches none ===
  hours with NO block on day 2: 24 of 24
  problems() reports: 0  ->  []
  and on the market day itself, gaps: 0
=== B: mixed - one every-day entry present ===
  gaps on day 2: 0, on day 3: 0        problems(): 0
=== C: two day-specific entries, different days, same hour ===
  day1 -> a_place   day2 -> b_place    problems(): 0
=== D: a day ABOVE the cycle length ===
  problems(): 0    ever selected across a 7-day cycle: false
```

Case A is the defect: an author who writes only day-specific entries gets an NPC with no
instructions for twenty-four hours on every day the schedule does not name, and the build says
nothing. `NpcBrain.decide_for_hour` returns early on a null entry, so the NPC keeps standing
wherever it happened to be — precisely the "reads as random" failure the entry header exists to
prevent. **Cases B, C and D came back correct, and that is why case A was worth acting on rather
than a symptom of something broader**: an every-day block still covers a named special day, two
day-specific entries on *different* days at one hour resolve independently and are correctly NOT
reported as a collision, and an over-range day parses and is never selected — the cost T5.32 stated
in writing, now confirmed by running it.

**Connects.** T5.32 introduced the hole; this closes it. ADR-0007 and `check_layers.gd` are why the
rule is the shape it is. `1.0.2`, `5.3.2` and `5.3.3` in `CHANGELOG.md` are the version precedent.
T5.26's declined column-count gate is why the table scan here was rewritten before its result was
believed.

**One rule, at exactly the strength this layer supports.** Every schedule must carry at least one
entry at `-1`. That is necessary *and* sufficient for total coverage: `_applies_on` admits an
every-day entry whatever day is asked, so `latest` is never null and `entry_for_hour` never returns
null. The stronger rule — every day of the cycle is covered — was rejected on layering rather than
effort: it needs `Clock.days_per_cycle`, `NpcSchedule` is in `content`, and `check_layers.gd` exists
to refuse `content` reaching up into `systems`. So coverage is now half enforced and half a stated
cost, and both headers say which half is which rather than leaving a reader to find out.

**Verified.**

| rung | result |
|---|---|
| `--import` | exit 0, no `SCRIPT ERROR`, no `Parse Error` |
| boot | `0 warnings, 0 errors` |
| suite | `2362 passed, 0 failed, 0 skipped`, exit 0 |
| seven checkers | each exit 0, each `PASS` |

**Plant — the new check disabled with `if false and not covers_every_day`:**

| run | result |
|---|---|
| control | `2362 passed, 0 failed`, exit 0 |
| plant | **exit 1**, `2361 passed, 1 failed` |
| control, restored | `2362 passed, 0 failed`, exit 0 |

```
FAILED: and that is reported as a problem rather than passing check_content — expected 1, got 0
```

**The 24-of-24 consequence assertion stays GREEN under the plant, deliberately, and that shape is
worth keeping.** The gap exists whether or not the validator reports it. A single assertion bundling
the consequence and the report would have gone red for the wrong reason, and taught a later reader
that the plant changed the coverage rather than the reporting.

**An existing assertion had to be re-expressed, which is the kind of thing a new rule does to a
suite.** T5.32's collision case asserted `problems().size() == 1` on a schedule that also happens to
have no every-day entry, so it now reports two. Rewritten to count problems by PHRASE through
`_problems_mentioning`, because an assertion on a total silently depends on how many *other* rules
the same resource breaks — fragile rather than strict, and it would have failed the next time any
validator gained a rule.

**Three documentation numbers were wrong.**

| where | said | actually |
|---|---|---|
| `TESTING.md` opening | full `2302 passed`, stripped `2226 passed` | `2362` / `2288` |
| `NEW_GAME.md` § 7 | "all 930 assertions stay green" | number deleted; it carried no weight |
| T5.32's record | `clock.gd`'s 3 spare lines were "the tightest any file has been" | `director.gd` has 3; `dev_stage.gd` had 2 pre-T5.20 |

**`TESTING.md` is the one with a lesson, because it was missed by two rows running.** Closing item 5
was being read as "update `CLAUDE.md` and `ARCHITECTURE.md`" — the two files the T5.32 brief named —
while the suite size is stated in FOUR places. T5.31 updated two and left two; T5.32 did exactly the
same, in the file a newcomer reads to learn the suite. **The stale pair even contradicted the rest of
the repository**: `2302 − 2226 = 76`, against a stripped gap the board recorded as exactly 74 for
eight straight runs. Nothing caught that, and it is the cheapest kind of contradiction to catch.
Item 5 now enumerates all four files and states that the stripped number can only come from the CI
job log, so that step finishes AFTER CI rather than before.

**`NEW_GAME.md`'s number was deleted rather than corrected.** The sentence's point is that a
narrowed export filter fails while everything on disk stays green; no reader needs the total to
follow it. Replacing a stale number with a fresh one only schedules the next staleness, so where a
count carries no weight the right fix is to remove it.

**T5.32's budget claim was wrong twice, and no gate could have caught it** because it was a claim
about this base's own history rather than about its code: `director.gd` is at 187 of its raised 190
with the same three spare lines, and `dev_stage.gd` stood at 248 of 250 — two — until T5.20 split it.
The corrected statement is narrower and more useful: `clock.gd` and `director.gd` are the two
tightest files in the base, three lines each, and the next row to touch either faces a split.

**What the audit CONFIRMED, recorded because a clean result is evidence too.**
- **Zero markdown table column mismatches across every live document** — the defect that recurred
  in T5.15, T5.19 and T5.26. A naive sweep produced four hits and **all four were false positives**:
  an ASCII tree inside a code fence, and T5.32's own deliberately escaped `\|`. The scan was
  rewritten to track fences and escaped and inline-code pipes before its result was trusted. That is
  T5.26's measurement repeating — it declined a column-count gate because three of four candidates
  were false positives — and it is the reason this audit reports a clean result rather than four
  findings.
- "Ten autoloads" (10), "seven checkers" (7), "eight template screens" — `ScreenKeys.menu_for`'s
  chain is exactly eight — all correct against the code.
- `AUTHORING.md`'s "20 per area to `transitions_test`, 5 to `world_map_test`" is correct, and was
  nearly reported as an off-by-one: `world_map_test` declares `PER_AREA = 4`, and the 5 is right
  only because the plan also carries `PER_DEF = 1` with one def asserted per area.
- `UPGRADING.md`'s and `NEW_GAME.md:149`'s run outputs are correctly attributed to named synthetic
  forks and legitimately frozen — the contrast with the unattributed 930 is what made that a
  finding and these not.
- No TODO/FIXME/HACK debt under `src/`, `tools/`, `tests/`. Nine `NO CALLER` exemptions, each with
  its reason. CHANGELOG headings ordered, no duplicates.

**2,355 → 2,362, +7**: five in `npc_test` (79 → 84) and **two in `record_shape_test`** (137 → 139),
this row's own package id passing through a computed plan — exactly the effect T5.32 documented one
row earlier, and the pre-documentation run read 2,360, so a predicted +5 would have been wrong by
two. `doc_counts_test` did NOT move, because this row spells no gotcha count anywhere. **The plan guard caught an
off-by-one on the way** — `npc_test planned 85 outcomes and produced 84`, with all 84 passing — which
is that mechanism doing exactly its job, and worth recording because a stale plan is the one test
defect whose failure text reads like a crash.

**Unblocks.** A game, again — but now with the coverage rule gated rather than promised. The board
has no open row and no chip was created.

**Gaps.**
- A day above the cycle length is still silently inert. Unchanged by this row, argued in
  `schedule_entry.gd` and flagged in `AUTHORING.md`; closing it needs `content` to read `systems`.
- **The four files stating the suite size are still ungated.** This row fixed the numbers and the
  checklist, not the absence of a check. A `docs_test`-style assertion comparing a stated total to
  the runner's own is possible for the full checkout; the stripped number is not available inside
  the suite at all, which is the same cross-job comparison T5.27 named and left open.
- The audit was one session's sweep, not exhaustive. It covered the ladder, cross-document numeric
  claims, table structure, TODO debt, exemptions and the code this row's predecessor touched. It did
  not re-perform `AUTHORING.md`, `ART_CONTRACT.md`, `TESTING.md` or the extension surface, each of
  which found defects when performed and would likely find more.

**CI, read out of the job logs rather than off the green tick (gotcha 26).** Run `34461450820` on
`claude/t5-33-audit`, PR #64, both jobs `success`:

| job | result |
|---|---|
| Ladder (full checkout) | `=== 2362 passed, 0 failed, 0 skipped ===` |
| Ladder (stripped template) | `=== 2288 passed, 0 failed, 25 skipped ===` |

**The gap is 74, the ninth consecutive recorded run at exactly 74, and still nothing enforces it.**
The five new assertions build their content from `FixtureContent` and the two computed ones read
`docs/`, neither of which the strip touches, so the gap holding is the right answer.

**And this is where the new closing item 5 earned itself immediately.** The stripped number cannot
be measured locally, so `TESTING.md` was written with `2288` *inferred* from the 74 gap — a
prediction, of exactly the kind this project forbids, and it was flagged as one at the time rather
than presented as measured. The CI log then returned `2288`. **Being right does not make it a
measurement**, which is the whole reason item 5 now says that step finishes after CI: had the gap
moved by one, the file teaching the suite would have shipped a wrong number for the third row
running.

**Commit:** on `claude/t5-33-audit`, PR #64, targeting `main`. No SHA, per board item 6.

## 2026-09-26 — T6.0 · Planning Phase T6

**Did.** Planned Phase T6 and wrote it into the record: `ROADMAP.md` § Phase T6 with eight rows and
eight exit criteria, board rows T6.0–T6.8 with a file manifest and budget warning per row, the
`CONTEXT.md` headline and next-package paragraph, and corrections to three "Commonly forgotten"
items and to `CONTEXT.md`'s candidates list. `5.6.2`, a PATCH; `src/`, `tools/` and `tests/` are
byte-identical.

**Why.** The owner asked what the base had missed, given it will be the formula for many games. The
base was complete at `5.6.1`, so the question was whether anything structural was absent that every
game would otherwise build or retrofit — and the risk in answering it was the one `CONTEXT.md` warns
about in as many words: inventing work twenty reasonable lines at a time.

**So the answer was filtered, not brainstormed.** Three filters, all already in the repository:
ADR-0007's seam test for what a template DEFAULT is; the refused list, which is not reopened; and the
standing rule that work is found, not invented. A candidate survived only as a confirmed defect or as
an undecided item on `SYSTEMS_INVENTORY.md` § "Commonly forgotten" — a list that says of itself it
was written *"so they are decisions rather than oversights"*, and eight of whose fifteen items were
still neither.

**Method.** Three parallel explorations: an inventory of what exists; a sweep of everything refused,
deferred or settled; and a presence check across thirty-six capabilities a general HD-2D exploration
base usually needs, each marked present, partial or absent with a file cited. Then an adversarial
review of the draft ranking, asked specifically to classify each candidate against ADR-0007 and to
grep before accepting any "absent". Then every load-bearing claim re-read in the code before it was
written into the record.

**The review overturned three first premises — which is what it was for.**

| premise | reality |
|---|---|
| shader warm-up is missing (forgotten #14) | built in T2.0 — `Director.WARM_UP_FRAMES = 3`, `_warm_up()` at `director.gd:198` |
| per-section save versions were never exercised | exercised — `core_test.gd:134` registers a v3 probe and asserts the applier saw 3 |
| the F2 freecam is declared but unbound | bound at `actions.gd:127`; it has no consumer |

Proposing the first as a row would have rebuilt something that works. That the draft got it wrong is
the ordinary case this project keeps recording: T5.30's audit predictions were wrong twice, and the
fix is the same — read the code before writing the row.

**It found one real defect by reading.** `SaveSystem.load_from_slot` does this for every section:

```
apply.call(DictRead.get_dict(wrapped, "data"), DictRead.get_int(wrapped, "v", 1))
```

— the STORED version, with no comparison against the version the running build registered. Every
applier in the base (`flags`, `inventory`, `clock`, `weather`, `director`, `quest_tracker`,
`dialogue`) takes `_from_version` and ignores it. The envelope has the guard — `_migrate` refuses
`from_version > SCHEMA_VERSION` with "Save is from a newer build" — and the section level has no
twin. So a section from a newer build is applied, differently shaped, as if current. **This is a
claim from reading, not yet a measurement**, and T6.1's first job is to prove it red on today's code
before touching it.

**The owner decided three things.** Phase T6 only. Photo mode, a codex, in-area camera zones and
positional ambient emitters are GAME CHOICES — each has its seam already (the F2 freecam;
`Readable.has_been_read()`; framing living in the area scene; authored `AudioStreamPlayer3D` nodes).
And font fallback proves both Bengali and CJK, so the chain is shown to generalise rather than to
work for one font.

**Connects.** ADR-0007 is the filter. `SYSTEMS_INVENTORY.md` § "Commonly forgotten" supplies the rows
and, through T6.8, the exit criterion. `KeyBindings.text_for(action, pad)` (`key_bindings.gd:105`),
which already exists with one caller, is why T6.2 needs no glyph system — only the fact of which
device is active.

**Two budgets found while writing the manifests, recorded so the rows do not rediscover them.**
`save_system.gd` is at 172 of 180 and T6.1 and T6.4 both edit it; `director.gd` is at 187 of 190, so
T6.4 cannot simply have `Director` register the save header. `settings.gd` at 141 of 150 takes a
setting from both T6.5 and T6.7.

**Verified.** Documentation only, so the claims to check are that the record still passes its own
gates, that the version agrees with itself, and that nothing outside the record moved.

| rung | result |
|---|---|
| `--import` | exit 0 |
| boot | `0 warnings, 0 errors` |
| suite | `2364 passed, 0 failed, 0 skipped`, exit 0 |
| seven checkers | each exit 0, each `PASS` |
| table structure | fence- and escape-aware scan across every live document: clean |
| scope | `git status` shows only `docs/`, `CLAUDE.md` and `project.godot` changed |

**2,362 → 2,364, +2**, both in `record_shape_test` (139 → 141) for this row's own package id.
`docs_test` (122), `doc_counts_test` (9) and `version_test` (30) did not move, which is the check
that the new prose named no unresolvable `res://` path, spelled no gotcha count, and left exactly two
bold semvers live. Measured after the documentation landed.

**Stale records corrected.** `CONTEXT.md`'s candidates list still offered time on the flag surface
and the cycle above the day as open, two rows after T5.31 and T5.32 built them — struck through
rather than deleted, because that list is where a reader looks for what is open. Forgotten #14 marked
DONE (T2.0); #12 and #13 marked CLOSED (game's), #13 citing the owner's 2026-09-02 decision that the
list itself had never recorded; #15 marked partly done, its player-facing half assigned to T6.4.

**Unblocks.** T6.1, with its manifest on the board.

**Gaps.** The defect in T6.1 is read, not run. The thirty-six-item presence check is one sweep and
could miss what no search term named. And first-run defaults (forgotten #8) cannot be decided by
reading at all — they wait on the owner's playtest, which outranks every row in this phase.

**CI, from the job logs (gotcha 26).** Run `36176645207`, PR #65, both jobs `success`:
`=== 2364 passed, 0 failed, 0 skipped ===` and `=== 2290 passed, 0 failed, 25 skipped ===`. The gap is
74, the tenth consecutive recorded run at exactly 74. `TESTING.md`'s stripped figure was written as
2290 by inference before CI ran — as T5.33 did — and the log confirms it; it counts as measured only
from this line on.

**Commit:** `487e7f4` on `claude/t6-0-plan`, PR #65, targeting `main`, plus `488e493` for the CI record. Filled in by T6.1.


## 2026-09-28 — T6.1 · A save from a newer build must be refused, not applied

**Did.** Proved T6.0's read defect red on `5.6.2`, then fixed it: `SaveSystem.load_from_slot` now
refuses a section whose stored `"v"` exceeds the version its participant registered — `Log.error`,
the section left at defaults, the rest of the file loaded. Added the suite's first worked,
exercised migration. `5.6.3`, a PATCH.

**Why.** The envelope refused a newer schema in `_migrate`; the section level had no twin, and every
applier in the base ignores `_from_version`. So a section a newer build wrote — a player rolling
back, a beta branch — was applied, differently shaped, as if current. For a base games will update
across many versions, that is the one save defect a formula cannot ship with.

**Red first.** Three blocks added to `tests/unit/save_recovery_test.gd`, run against unmodified
`src/`:

```
=== 2371 passed, 2 failed, 0 skipped ===
FAILED: but its applier was never called — expected 0, got 1
FAILED: so the probe keeps its defaults — expected unset, got from the future
```

The newer-section block failed on exactly the two assertions the reading predicted. The other two
blocks — a v2 section read as it is, and a v1 section migrated `old_key` → `new_key` — were green on
`5.6.2`, correctly: the loader always passed an older version through. The mechanism existed; the
guard and an example did not.

**The fix.** Four code lines. `save_system.gd` 172 → 176 of 180 by `check_budgets.gd`; no budget
raised, and T6.4 inherits four lines of room.

**Plant.** The guard's condition prefixed with `false and`: exit 1, `2371 passed, 2 failed`, the
same two failures. Restored: exit 0, `2373 passed, 0 failed` (pre-documentation).

**Connects.** `UPGRADING.md` § 4 item 3 now says how a game bumps a section and migrates it, and
names `_probe_apply` as the example to copy. `CHANGELOG.md` `5.6.3` justifies the PATCH on `1.0.2`.
`SYSTEMS_INVENTORY.md`'s save row and forgotten #15 record the refusal.

**Verified.**

| rung | result |
|---|---|
| `--check-only` | only `Identifier not found: Log` / `SaveSystem`, the expected autoload error |
| `--import` | exit 0, no `SCRIPT ERROR`, no `Parse Error` |
| boot | `0 warnings, 0 errors` |
| suite | `2375 passed, 0 failed, 0 skipped`, exit 0 |
| seven checkers | each exit 0, each `PASS`; `save_system.gd` 176 / 180 |

**2,364 → 2,375, +11**, measured per case against a `main` worktree after the documentation landed:
`save_recovery_test` 17 → 26 (the nine new assertions) and `record_shape_test` 141 → 143 (this
row's own package id). `docs_test`, `doc_counts_test` and `version_test` did not move. The stripped
figure in `TESTING.md` is written as 2301 by inference until the CI log confirms it.

**Unblocks.** T6.2, and T6.4 — which edits `save_system.gd` next.

**Gaps.** No applier in the base has migrated anything yet; each still ignores `_from_version`,
which is correct until one changes shape. The refusal loads defaults silently to the player — the
only trace is the log — and whether a damaged or partly-refused slot should say so on screen is
T6.4's question.

**Commit:** `53c44ae` on `claude/t6-1-newer-section`, PR #66, targeting `main`, merged as `d955449`; no separate CI-record commit was made. Filled in by T6.2, which also confirmed the stripped `2301` from the CI job log (`Ladder (stripped template)`, job 108988875530: `=== 2301 passed, 0 failed, 25 skipped ===`).

## 2026-09-28 — T6.2 · The base knows which input device is active

**Did.** Forgotten #4. New `src/systems/input/input_device.gd`: a pure static
`device_for(event, previous)` — a key, a click, a pad button, or a stick at or past
`Actions.STICK_DEADZONE` switches the device; mouse motion, sub-deadzone drift and unrecognised
events keep the previous answer. `Actions` holds the answer (`device()`), feeds it from `_input`
through a public `observe()`, emits the new `Events.input_device_changed(device)` only on a change,
and falls back to the keyboard when the last pad is unplugged. `GameEnums.DeviceKind` types the
signal. Consumers: the interact prompt names the button (`[E]  Barter  The Keeper's Basket`) and the
dialogue hint reads `{key} to continue`, both through `KeyBindings.text_for`, both redrawing on the
signal. `ART_CONTRACT.md` § Button prompts says where an icon sheet will plug in.

**Why.** No prompt in the base could name the button a pad player would press. **And the dialogue
hint was wrong for everyone**: it said `Space to continue`, and Space advanced nothing — it was bound
to `jump`, removed in T5.5, while the box has only ever listened for `interact`. Found by reading the
second consumer the manifest named, not by the plan.

**Decisions.** No new autoload — the stateful half is `Actions`, as the manifest said, and its MUST
NOT line was narrowed in writing ("read an event for anything but its device") rather than dropped.
The enum is `DeviceKind`, not `InputDevice`, because the first name collided with the new class and
`check_layers.gd` failed (`core ... names InputDevice, which is systems`, `FAIL — 2 upward
reference(s)`). Plugging a pad in changes nothing until it is pressed: owning a pad is not using one.

**Connects.** `Events.input_device_changed` → `interact_prompt.gd`, `dialogue_screen.gd`.
`KeyBindings.text_for` gains its second and third callers. `localization/strings.csv`: the
`ui.dialogue.continue` value changed and `ui.prompt.button` was added, which is what `CHANGELOG.md`
`5.7.0` tells a game with its own language column to act on.

**Verified.** Plants, each a different failure: deadzone ignored `2405 passed, 1 failed` (`stick drift
under the deadzone keeps the keyboard — expected 0, got 1`); announce on every event `2404 passed, 2
failed` (`expected 1, got 3`, `expected 2, got 5`); dialogue unsubscribed `2405 passed, 1 failed`
(`mid-conversation, the pad renames it — expected true, got false`). Windowed 960×540 captures,
looked at: `--stand-by=Keeper` → `[E]  Barter  The Keeper's Basket`; `--talk=talk/gardener` → `E to
continue`.

| rung | result |
|---|---|
| `--import` | exit 0, no `SCRIPT ERROR`, no `Parse Error` |
| boot | `0 warnings, 0 errors` |
| suite | `2408 passed, 0 failed, 0 skipped`, exit 0 |
| seven checkers | each exit 0, each `PASS`; `actions.gd` 107 / 150 |

**2,375 → 2,408, +33: 31 in the new `input_device_test` and 2 in `record_shape_test` for this row's own package id; every other case unmoved**, measured per case against a `main` worktree after the
documentation landed.

**Unblocks.** T6.3 next; T6.7 (dialogue skip and auto-advance), which the board ordered after this
row because its hints will name buttons the same way.

**Gaps.** Hotplug cannot be driven headless: the suite calls the handler directly and the engine's
emission of `joy_connection_changed` is untested. The pad variant of either prompt is asserted, never
photographed — there is no pad here. No button icons. `KeyBindings`' header still claims `Actions`
never mentions it, which stopped being true when `Actions` began calling `load_all()`.

**Commit:** `8bed5af` on `claude/t6-2-input-device`, PR #67, targeting `main`, merged as `f19cbd6`; no separate CI-record commit was made. Filled in by T6.3, which also took the stripped count from the CI job log (`Ladder (stripped template)`, job 109013767306: `=== 2334 passed, 0 failed, 25 skipped ===`; full job 109013767855: `=== 2408 passed, 0 failed, 0 skipped ===`). `TESTING.md` had kept T6.1's stripped `2301` through T6.2; T6.3 replaces it.

## 2026-09-29 — T6.3 · A reusable confirm screen, and "are you sure" on overwriting a save

**Did.** Forgotten #7. First merged PR #67 (T6.2) with plain `gh pr merge --merge` once it was
CLEAN. The session had opened on an unmerged `main` and stopped there; the owner said "do what's
best". Then:

- New `src/ui/screens/confirm_screen.gd`, `ConfirmScreen extends MenuScreen`. Its constructor is
  `asking(question_key, detail, on_yes)`. It sets `closes_on_cancel = false` in `_init`, overrides
  `focus_first()` so focus lands on No, and on Yes runs `on_yes` and then `request_close()`.
- `save_screen.gd`: an occupied slot pushes the question, with its own header as the detail; an
  empty slot writes at once.
- Three strings: `ui.save.overwrite`, `ui.confirm.yes`, `ui.confirm.no`.
- New `tests/unit/confirm_test.gd`, 27 assertions.

**Why.** Overwriting a save was the one irreversible action in the base's menus, and it happened
on a single press.

**Connects.** `UiRoot._unhandled_input` already honoured `closes_on_cancel`, and `_derive_mode`'s
comment already anticipated "a confirmation overlay". Nothing in `src/ui/root/` changed. The quit
half of #7 is T5.10's `Autosave` on `Events.game_ending`. Reading `Autosave.request()` found two
refusals it has, autosave OFF and mid-transition. In those cases a quit still loses progress
without a question, and that is now written into `SYSTEMS_INVENTORY.md` item 7 instead of the
claim that quitting is safe.

**Verified.**
- `--import`: zero `SCRIPT ERROR` / `Parse Error` lines.
- Boot: `0 warnings, 0 errors`.
- Suite: `=== 2435 passed, 0 failed, 0 skipped ===` before the docs landed, exit 0. After them:
  `=== 2437 passed, 0 failed, 0 skipped ===`, measured per case against a `main` worktree (2,408),
  +29: 27 in `confirm_test` and 2 in `record_shape_test` for this row's package id. The first
  post-docs run failed twice on `CONTEXT.md states the declared version — expected 5.8.0, got
  5.7.0`, which is `version_test` doing its job on two stale version lines. Both are fixed.
- All seven checkers exit 0.
- The first run failed once, on the test's own bookkeeping: `and nothing ran — expected 0, got 1`.
  The counter carried over from the block before, and was fixed by resetting it.
- A CONTROL assertion was added after that: the same cancel event closes a screen that allows
  cancel. Without it, the cancel assertions pass on an event that never matches.
- Plant 1, the save screen skipping the question: `2431 passed, 2 failed`, `an occupied slot asks
  first — expected true, got false`, plus the plan shortfall.
- Plant 2, `closes_on_cancel = true`: `2431 passed, 4 failed`, including `cancel does not answer
  it — expected 1, got 0`.
- Windowed 960×540 capture through a temporary `--probe-confirm`, looked at: `Overwrite this
  save?`, `Slot 6 · 2026-09-29 09:11:19 · 00:00 played`, `Yes`, and `No` focused. The covered save
  list is not drawn through it. The probe and the slot file it wrote are both gone.

**Unblocks.** T6.4, next. It edits `save_screen.gd` again (71 of 250) and `save_system.gd` (176 of
180). A damaged slot T6.4 draws is still a slot the writing half can press, and that press now
asks first.

**Gaps.** Loading from the pause menu does not ask, though it discards unsaved progress in the
session as quitting does. It is a single `ConfirmScreen.asking` call for a game that wants it,
and the manifest did not ask for it. The question's two rows are Yes and No rather than verbs
("Overwrite" / "Keep it"). That keeps one generic pair of strings; a caller wanting verbs would
need a label override, which nobody needs yet. T6.2's stripped count `2334` had not reached
`TESTING.md`, and this row replaces it.

**Commit:** `2195b8a` on `claude/t6-3-confirm-screen`, PR #68, targeting `main`, merged as `2b409de`; no separate CI-record commit was made. Filled in by T6.4, which also took the stripped count from the CI job log (`Ladder (stripped template)`, job 109341273520: `=== 2363 passed, 0 failed, 25 skipped ===`; full job 109341273896: `=== 2437 passed, 0 failed, 0 skipped ===`).

## 2026-09-29 — T6.4 · A save slot says where it was saved, and says so when it is damaged

**Did.** Forgotten #15. First merged PR #68 (T6.3) with plain `gh pr merge 68 --merge`, since it
was CLEAN with four green checks, then branched `claude/t6-4-slot-header` from `2b409de`.
`SaveSystem.header_provider` is an optional Callable. `save_to_slot` stores what it returns as
the envelope's `"header"`, and `slot_info` hands it back. `WorldMap` sets it to `{"area": <id>}`
and clears it on exit, but only if it is still its own. `WorldMap.place_key(header)` turns that
back into a name key. `SaveScreen` rows now read `Slot 1 · <place> · <stamp> · <played>`, and
`Unknown place` when nothing names it. `slot_info` now answers `{}` for any file the loader would
refuse, so `has_slot` with an empty header means damaged, drawn `Slot N · damaged`. New case
`slot_header_test.gd`, 32 assertions. `5.9.0`, a MINOR.

**Why.** A corrupt file was drawn as `empty`, which tells a player their save never existed. The
worse case was found by reading, not planned: a file from a newer build PARSES, so it drew a
normal header, offered a load that failed, and could become Continue. The place is the other half
of forgotten #15's "recovery messaging". A header with only a timestamp does not tell six slots
apart.

**Connects.** `core` → `systems` is upward, so the hook is set from above, the way autoloads
already hand `SaveSystem` their callables with `register`. `WorldMap`, not `director.gd`, which is
at 187 of 190. `WorldMap` already reads `Director.current_area_id` and owns the name. The damaged
slot reuses T6.3's route unchanged: `_on_slot` asks on `has_slot`, so a damaged slot counts as
occupied with no new code, and the test asserts that decision rather than assuming it.

**Verified.**
- Fresh worktree, `--headless --import` first: no `SCRIPT ERROR` or `Parse Error`. Boot
  `--quit-after 30`: `0 warnings, 0 errors`.
- Suite before the documentation: `=== 2469 passed, 0 failed, 0 skipped ===`, and
  `slot_header_test: 32/32`. After it: `=== 2471 passed, 0 failed, 0 skipped ===`, +34 against a `main` worktree measured per case: 32 in `slot_header_test` and 2 in `record_shape_test`, every other case unmoved.
- All seven checkers exit 0. `check_budgets`: `save_system.gd 179 / 180`, `save_screen.gd 73 / 250`
  and `world_map.gd 76 / 250`.
- Three plants, each exit 1, each restored. Removing the damaged branch gave three failures, the
  first `expected Slot 4 · damaged, got Slot 4 · empty`. Removing the version refusal gave three,
  including `and Continue never points at it`. Removing the only-if-ours guard gave
  `2468 passed, 1 failed`.
- Windowed capture, 960×540, through a temporary `--t64-probe` in `dev_screens.gd` writing to
  `user://t64_probe`. `Slot 1 · Rose Courtyard · 2026-09-29 09:53:52 · 00:00 played`, the autosave
  with the same place, slots 3 and 4 `damaged`, and slots 2, 5 and 6 `empty`, all looked at. The probe was
  removed (`git diff src/systems/debug/` empty), the scratch directory was deleted, and
  `user://saves` is untouched and empty.

**Unblocks.** T6.5, focus loss, next. Its manifest says to measure first, windowed, whether Godot
4.7 releases held inputs on alt-tab. `save_system.gd` is now at 179 of 180, so the next row that
touches it needs a justified budget or a split. No row in T6 plans to.

**Gaps.** An area with no `AreaDef` names no place. The header could carry the area root's
`display_name_key` instead, but `Director` keeps the root private and has no budget for a getter.
A damaged file logs `is not valid save JSON` each time the list draws. That is true and is left
loud. `menus_test.gd` and `confirm_test.gd` still write into the real `user://saves` rather than
`SaveFixture.ROOT`, and empty it at set-up. That was not introduced here and is flagged as a
separate task.

**Commit:** `a90b57a` on `claude/t6-4-slot-header`, PR #69, targeting `main`, merged as `9b6a7e7`; no separate CI-record commit was made. Filled in by T6.5, which also took the stripped count from the CI job log (`Ladder (stripped template)`, job 109354905555: `=== 2397 passed, 0 failed, 25 skipped ===`; full job 109354905350: `=== 2471 passed, 0 failed, 0 skipped ===`). `TESTING.md` had kept T6.3's stripped `2363` through T6.4; T6.5 replaces it.

## 2026-09-29 — T6.5 · Losing window focus leaves nothing latched; pausing on it is a setting

**Did.** Forgotten #3. First merged PR #69 (T6.4) with plain `gh pr merge 69 --merge`, since it was
CLEAN with four green checks, then branched `claude/t6-5-focus-loss` from `9b6a7e7`. Measured the
engine first, windowed (below). `UiRoot` now announces `Events.focus_lost`, deferred, on
`NOTIFICATION_APPLICATION_FOCUS_OUT`. `PlayerController` drops a toggled run, `InteractionSensor`
drops a hold in progress, and `RebindScreen` stops listening. `gameplay/pause_on_focus_loss` is a
new setting, off by default, and `ScreenKeys.pause_for_focus_loss` opens the pause menu when it is
on. `UiRoot.open` now rolls back a screen the engine refused to add. New case
`focus_loss_test.gd`, 30 assertions. Gotcha 80. `5.10.0`, a MINOR.

**The measurement, with the command.** A temporary `extends SceneTree` probe,
`src/systems/debug/focus_probe.gd`, bound `probe_hold` to physical D and printed focus, key and
action state every 0.25s. It was run as `Godot_v4.7.2-stable_win64_console.exe --path .
--resolution 640x360 --script res://src/systems/debug/focus_probe.gd`, started from PowerShell. The
driver called `user32!keybd_event(0x44, 0x20, KEYEVENTF_SCANCODE)` to hold D, alt-tabbed away
after 2s, and released D 2s later while unfocused. Output: `t=2.03 EVENT D`, then
`focused=true key=true action=true` through t=4.02, then `focused=false key=false action=false`
from t=4.26 to the end. No release event was logged. **Godot 4.7.2 clears held keys and actions on
focus loss**, so a held walk stops without the base doing anything. A pad was not measured. An
earlier run with F13 (VK 0x7C, no scancode) registered no press at all, and proved nothing.

**Why.** Only the base's own state can stay latched: a run toggled on, a hold part-way to firing,
a rebind row waiting for a key. The engine knows nothing about those. Pausing is a setting and not
a default, because this project verifies visuals with windows launched from a terminal. A click
back to that terminal would pause every capture, and a player glancing at a second monitor would
hit the same thing.

**Connects.** `UiRoot` announces the event, the way it already announces `ui_mode_changed`.
`ScreenKeys` does the pausing, because that is where a bus request becomes a screen. `UiRoot` must
not know what a screen contains. The setting's consumer is `ScreenKeys.PAUSE_ON_FOCUS_LOSS`, which
`settings_consumers_test` finds by name. The settings screen draws the row from `DEFAULTS` with no
edit, as its header promises.

**Verified.**
- `--headless --import` first in the fresh worktree, then after every edit: exit 0, no
  `SCRIPT ERROR`. Boot `--quit-after 30`: `0 warnings, 0 errors`.
- Suite before the documentation: `=== 2502 passed, 0 failed, 0 skipped ===` with
  `focus_loss_test: 27/27`, then 30/30 after the rollback case. After the documentation:
  `=== 2504 passed, 0 failed, 0 skipped ===`, +33: 30 in the new `focus_loss_test`, 3 in `options_test` and 1 in `settings_consumers_test` for the new setting's row and consumer, 2 in `record_shape_test` for this row's own package id, and −3 in `doc_counts_test`, because the three historical `seventy-nine` lines in `WORK_PACKAGES.md` became digits; every other case unmoved. Measured per case against a `main` worktree.
- All seven checkers exit 0 with `PASS` and no `SCRIPT ERROR` in their logs.
- Plants, each exit 1, each restored. Run toggle not cleared: `focus loss drops it — expected
  false, got true`. `WM_WINDOW_FOCUS_OUT` in `is_focus_loss`: `2500 passed, 2 failed`. Rollback
  disabled: `2498 passed, 4 failed`. Synchronous emit restored: the engine's own `add_child()
  failed`, and `the engine's propagation is not answered inside itself — expected 0, got 1`.
- Windowed, 960×540: `--resolution 960x540 --quit-after 120 -- --new-game --shot=<png>
  --shot-frame=90 --time=18:40 --freeze-time`, with a temporary two-line probe in
  `dev_capture.gd` propagating `NOTIFICATION_APPLICATION_FOCUS_OUT` from the root at frame 40.
  Windows refused `SetForegroundWindow`, even with `AttachThreadInput`, so the OS focus change
  could not be driven. **The first capture showed a stopped world and no menu**, while the log
  said `Opened 'pause' at depth 1`. That is gotcha 80, fixed as described. After the fix, the
  menu is drawn over the dimmed courtyard with Resume focused. The control, with the setting off,
  shows the courtyard with the prompt up and no menu. Both were looked at. The probes were
  removed (`git status src/systems` clean), and `settings.cfg` was restored from a copy.

**Unblocks.** T6.6, the font fallback: Bengali and CJK through the theme. `settings.gd` is at 142
of 150, so T6.7's `gameplay/dialogue_auto_advance` still fits.

**Gaps.** A pad's held buttons were not measured. Getting focus back does nothing, on purpose.
`InteractionSensor` still reads `Input` directly and would see a held key the same frame focus
returns. That is the engine's state, and it was measured clear. The capture could not drive the
OS focus change, so the photographed path starts at the engine's notification. The OS-to-engine
half is the probe's measurement.

**Commit:** `f0805ce` on `claude/t6-5-focus-loss`, PR #71, targeting `main`, merged as `26f48c1`; no separate CI-record commit was made. Filled in by T6.6, which also took the stripped count from the CI job log (`Ladder (stripped template)`, job 109373463415: `=== 2430 passed, 0 failed, 25 skipped ===`; full job 109373463289: `=== 2504 passed, 0 failed, 0 skipped ===`). `TESTING.md` had kept T6.4's stripped `2397` through T6.5; T6.6 replaces it.

## 2026-09-29 — T6.6 · Text in any script renders, not as tofu

**Did.** First merged PR #71 (T6.5) with plain `gh pr merge 71 --merge`, CLEAN with both CI jobs
green, as `26f48c1`, and branched `claude/t6-6-font-fallback` from it. Imported first. Captured the
before state, which showed no tofu, because Windows fonts drew it. Captured again with system
fallback off: boxes. With permission, downloaded Noto Sans Bengali, Noto Sans SC and their
licences, and fontTools, and cut a 2.8 MB CJK subset at weight 600. Put the chain in the theme,
found the fresh-clone `Parse Error`, and moved the chain into `assets/fonts/font_chain.tres`, which
`UiRoot.install_font_chain` installs at boot. Wrote `font_chain_test.gd`. Checked every count in
the CSV for `tr_n`, and found `RestPoint`'s `{hours}`, which is now T6.10.

**Why.** Before this, a Bengali or CJK string rendered only if the player's OS had a font for it.
The machine the base is written on does, so nothing looked broken.

**Connects.** `UiRoot` is the first UI node, and it already sits where the UI's facts are stated.
`UiAccessibility` and `UiRowStyles` already change the project theme at runtime. `ART_CONTRACT.md`
§ Fonts is the consumer's rule. `NEW_GAME.md` § 2 lists `assets/fonts/**` as keep.

**Verified.**
- Fresh worktree: `--headless --import` first. Then a copy of the tree with no `.godot/`:
  `--import` with the chain in the theme printed `Parse Error: [ext_resource] referenced
  non-existent resource` ×2. With the chain in its own file, it printed 0, and the fresh boot logged
  `Font chain installed: 2 fallback(s)`.
- Boot `--quit-after 30`: `Font chain installed: 2 fallback(s)`, then `0 warnings, 0 errors`.
- Suite: after the documentation, `=== 2533 passed, 0 failed, 0 skipped ===` with `font_chain_test: 25/25`. Against a `main` worktree, +29: 25 in the new `font_chain_test`, 2 in `record_shape_test` for this row's own package id, and 2 in `docs_test` for the two font paths the board's plant record names; every other case unmoved.
- All seven checkers exit 0 with `PASS` and no `SCRIPT ERROR`.
- Plants: Each exited 1, and each was restored byte-identical. With the chain's two fallbacks swapped: `2523 passed, 8 failed`, starting with `fallback 0 is the Bengali font — expected res://assets/fonts/NotoSansBengali-Variable.ttf, got res://assets/fonts/NotoSansSC-SemiBold-subset.ttf`. With `install_font_chain`'s check for an existing `default_font` removed: `2530 passed, 1 failed`, `a theme with its own font keeps it — expected true, got false`.
- Windowed, 960×540: `--resolution 960x540 --script res://src/systems/debug/font_probe.gd --
  <png> before|late`, a temporary probe drawing Latin, Bengali, Chinese and Japanese at 64 px with
  system fallback off. For the after capture it added a real `UiRoot`. Before: boxes. After: all
  drawn, conjuncts shaped, weights matched. Both were looked at. The probe was removed.
- The ladder's own capture, `--resolution 960x540 --quit-after 90 -- --new-game --shot=<png>
  --shot-frame=70 --time=18:40 --freeze-time`, taken on this branch and on a `main` worktree. The
  courtyard, the HUD clock, the toast and the prompt match, all in the engine's Latin. One branch
  capture caught `Loading 50%` at frame 70, so boot time was compared: three alternating runs
  each, with no other Godot process alive. Branch 4.9, 5.5 and 8.5 s; `main` 6.0, 9.5 and 5.2 s.
  That is noise, and there is no systematic cost.
- **A concurrency hazard, recorded because it will recur.** The first suite run failed 8
  `slot_header_test` assertions, because another session's suite started while mine was in that
  case, and both write the shared `user://` fixture folders. It is not a defect in this row. The
  measured runs were started only with no other Godot process alive. The user data directory was
  copied aside first, and was compared afterwards: `saves/` was empty before and after, and
  `settings.cfg` was byte-identical.

**Unblocks.** T6.7, dialogue skip and auto-advance. `settings.gd` is still at 142 of 150.

**Gaps.** No Bengali or CJK locale column exists, so no real translated screen was photographed,
only the chain drawing the strings. Hangul is not in the subset. A game that sets its own
`default_font` gets no fallbacks unless it adds them, and `ART_CONTRACT.md` says so. RestPoint's
plural is T6.10.

**Commit:** `487d4fd` on `claude/t6-6-font-fallback`, PR #75, targeting `main`, merged as `db0d6ec`; no separate CI-record commit was made. Filled in by T6.9, which also took the stripped count from the CI job log (`Ladder (stripped template)`, job 109434179199: `=== 2459 passed, 0 failed, 25 skipped ===`; full job 109434179375: `=== 2533 passed, 0 failed, 0 skipped ===`). Copied into this log by T6.7.

## 2026-09-29 — T6.9 · Running the suite destroyed the developer's real saves

**Did.** Owner-reported, taken ahead of T6.7. `menus_test.gd` and `confirm_test.gd` said they owned
`user://saves` for the run and cleared every slot there, and neither had called
`SaveFixture.activate()`. The report also asked about `settings_effects_test.gd`. Grepping for
every call that touches the store found **fourteen** unredirected cases, not three. Each now calls
`SaveFixture.activate()` first: at the top of `_set_up` where a case has one, directly after
`plan()` otherwise. The two headers now say the scratch store. `TESTING.md` states the rule,
gotcha 79 records the instance, and the version is `5.11.1`, a PATCH. Numbered T6.9 rather than
T6.7 so that no planned row's id moves. A suffix was not possible, because `record_shape_test.gd`
reads `T6.3a` as T6.3.

**Why.** Since T5.22, `SaveFixture` has existed so that the suite never touches a developer's
saves, and the runner resets it after every case. But it only helps a case that calls it, and
T5.22 wired the two it was written for. Every other case that saves passed green while writing to,
and deleting from, the real directory. "Deletes what it wrote" is no defence: the suite's slot
numbers are a player's slot numbers.

**Connects.** `tests/framework/save_fixture.gd` and `test_runner.gd`'s unconditional
`SaveFixture.deactivate()`, both unchanged. Gotcha 79, whose lesson this is: grep for the pattern,
not the sites someone happened to fix.

**Verified.**
- Fresh worktree: `--headless --import` first, exit 0.
- **Red first, on the unchanged tree.** The real directory was empty before this row. Seven sentinel
  files were planted in it, `slot_00.json` to `slot_05.json` plus `autosave.json`, each holding its
  own name. Suite: `=== 2437 passed, 0 failed, 0 skipped ===`, exit 0, and then `survived 0 of 7,
  lost 7`.
- **Fixed**, sentinels re-planted: `=== 2437 passed, 0 failed, 0 skipped ===`, exit 0, `survived 7
  of 7, lost 0`, each file still holding its own name.
- **Plant: only the three reported cases redirected.** `=== 2437 passed ...`, exit 0, and `survived
  2 of 7, lost 5`: slots 2 to 5 and the autosave. That is why all fourteen changed.
- CI on `6e7f5df`, both jobs green: full `=== 2473 passed, 0 failed, 0 skipped ===` (job 109371292649),
  stripped `=== 2399 passed, 0 failed, 25 skipped ===` (job 109371293082). `TESTING.md` still said
  T6.3's stripped `2363` and now says `2399`.
- After the documentation landed and `main` (T6.4) was merged in: `=== 2473 passed, 0 failed, 0
  skipped ===`, exit 0, measured per
  case against `main` at 2,471: +2, both in `record_shape_test` for this row's package id,
  every other case unmoved. Sentinels planted for that run survived it too, 7 of 7.
- After `main` brought T6.5 and T6.6 in: `=== 2535 passed, 0 failed, 0 skipped ===`, exit 0, against
  `main` at 2,533, +2, both in `record_shape_test`. A real `autosave.json` that was not this row's
  was in `user://saves` by then, so only the six slot sentinels were planted, all six survived,
  and that file's md5 was unchanged by the run.
- `--check-only` on the fourteen changed cases: only the documented autoload identifiers.
- Boot `--quit-after 30`: `0 warnings, 0 errors`.
- All seven checkers exit 0: budgets, content, boundary, strings, layers, signals, methods.
- Windowed 960x540 capture at 18:40, frozen, looked at: the courtyard at dusk, HUD, the `[E]` prompt,
  and an `Autosaved.` toast. Session `0 warnings, 0 errors`. **It overwrote the sentinel
  `autosave.json`.** That is the GAME, not the suite: `--new-game` starts a real run, and T5.10's
  arrival and quit autosaves write the real slot as designed. See Gaps.
- The sentinels were removed afterwards. An `autosave.json` then appeared mid-suite, and it was not
  the suite's: `project_gulistan_2026-09-29T16-40-05.log` is a separate `--new-game 'courtyard'`
  process from another session on this machine, logging `Slot 6 written (6 sections)`. It names
  demo content no test may name. Every worktree shares one `user://`, so that file was left for
  its owner.

**Unblocks.** T6.7, next, unchanged. T6.4, T6.5 and T6.6 merged to `main` while this row was open, and each was merged
into the branch before the final ladder. T6.4's `slot_header_test.gd` already activates the scratch
store, and any later case that saves belongs in the scratch store from
the first line, and `TESTING.md` says so.

**Gaps.** **Nothing fails a new case that saves without activating.** A runner-side check cannot
see a write followed by a delete in an empty directory, and an empty directory is the ordinary
state on CI. The structural fix is for the runner to activate the scratch store before every
case, which means `save_dir_test.gd` must stop asserting the default at entry. That design choice
is recorded, not taken.

**The ladder's capture rung writes the developer's real autosave**, found while proving this row.
It plays a real session, and the autosave policy does what it does for a player. Out of scope for
a test-only row, and flagged as its own task. The same shared `user://` means two sessions running
the suite at once share `user://test_saves` too, and each `activate()` empties it.

## 2026-09-29 — T6.10 · A capture or debug launch wrote over the developer's real saves

**Did.** Added `src/systems/debug/dev_saves.gd` (`DevSaves`), the first debug node in
`game_root.tscn`. In a debug build, a launch with any user argument sets `SaveSystem.save_dir` to
`user://dev_saves`, and `--real-saves` opts out. Fixed `--autosave-continue`, which looked for a
`Slot 7` Continue row the menu no longer draws. Seven assertions in `dev_tools_test.gd`, and its
wired-file count went from 6 to 7. `5.10.0`, a MINOR.

**Why.** T6.9's Gaps: the capture rung's `--new-game` is a real run, so the autosave wrote the
developer's real `autosave.json` on arrival and on quit, in every worktree, because they share
one `user://`. Reading the debug directory found worse: `--save-state`/`--load-state` and
`--cross-area-save` delete the slot they used. Redirect was chosen over suppressing the
autosave. Suppression covers one writer of three, changes what the capture photographs, and
would make the autosave probe pair prove nothing. `save_dir` is the seam T5.22 made public, so
`save_system.gd`, at 179 of 180, did not change.

**Connects.** `SaveSystem.save_dir` (T5.22), `Autosave` (T5.10), `dev_probes.gd`'s and
`dev_scenario_shots.gd`'s two-process pairs, which now meet in scratch. `SaveFixture.ROOT` is
deliberately a different directory, because `activate()` empties it.

**Verified.**
- Fresh worktree, branched from T6.9's tip `2391b55`: `--headless --import` exit 0, zero `SCRIPT
  ERROR` / `Parse Error` lines.
- **Red first, on the unchanged tree.** The real `user://saves` was empty. A sentinel
  `autosave.json` was planted, and the ladder's capture command logged `Slot 6 written (6
  sections)`. The file then held the capture's autosave, header area and all.
- **Fixed.** The sentinel was re-planted, SHA-1 `45f765b9…`. The same capture logged `Debug launch:
  saves go to user://dev_saves, not user://saves (--real-saves keeps the real ones)`, then `Slot 6
  written`, and exit 0 with `0 warnings, 0 errors`. The sentinel still had SHA-1 `45f765b9…`, and
  `user://dev_saves/autosave.json` existed.
- **Opt-out.** `--new-game --real-saves` wrote the real slot, and the SHA changed, as intended.
- **The pair.** `--new-game --autosave-write`, then `--autosave-continue=<dir>` in a fresh process,
  both redirected. Before the fix, the second half logged `found no Continue row on the main
  menu`, and it failed identically with `--real-saves` on both, so the redirect was not the cause.
  After: `pressed the 'Continue — Autosave' row`, and state restored from `day=4 time=22:15
  weather=4 carrying=1` to `area='lantern_hall' day=4 time=22:16 weather=4 carrying=1`. Both
  sessions `0 warnings, 0 errors`, and the sentinel was unchanged. The menu photograph shows
  `Continue — Autosave`.
- Windowed 960x540 capture at 18:40, frozen, looked at: the courtyard at dusk, `Day 1 | 18:40 |
  Dusk`, the `[E] Use Iron Lever` prompt, and the `Autosaved.` toast. The toast is the game
  behaving as for a player, into scratch.
- **Plant:** `save_dir_for` returning `""` always. `=== 2479 passed, 2 failed ===`, exit 1, on
  exactly `the ladder's capture saves to scratch` and `so does a probe with no shutter`. Restored.
- Suite before documentation `=== 2481 passed, 0 failed, 0 skipped ===`: +8 over 2,473, all in
  `dev_tools_test`. After the documentation: `=== 2483 passed, 0 failed, 0 skipped ===`, +10 over 2,473: 8 in `dev_tools_test` and 2 in `record_shape_test` for this row's package id, every other case unmoved, measured per case. Boot `0 warnings, 0 errors`. All seven checkers exit 0.
- `--check-only` on both changed scripts: only the documented autoload identifiers.
- The sentinel was removed afterwards, and the real `user://saves` is empty again, as it was.

**Unblocks.** T6.5, next, unchanged. Every later session's capture now leaves the developer's
saves alone.

**Gaps.** **`--locale=` still writes the real `user://settings.cfg`**, through
`Settings.set_value`, and `Settings.PATH` is a `const`. Same harm, different store, and flagged
as its own task. **The redirect itself is not asserted by the suite**, whose process has no user
arguments. The rule is asserted, and the sentinel run is the proof. **T6.5's PR #71 also claims
`5.10.0`**, so whichever merges second takes `5.11.0`.

**Commit:** on `claude/t6-10-capture-saves`, stacked on T6.9's PR #70; PR #72, squash-merged to `main` as `2fe62ae` from branch head `243d242`. CI (`Ladder (stripped template)`, job 109473299408: `=== 2482 passed, 0 failed, 25 skipped ===`; full job 109473298931: `=== 2556 passed, 0 failed, 0 skipped ===`). Filled in by T6.7.

## 2026-09-29 — T6.11 · A debug launch, and every suite run, wrote the developer's real settings

**Did.** `Settings.file_path` is a new var, where `save()` writes, defaulting to `Settings.PATH`,
which keeps its name and is still the file read at boot. `DevSaves._parse_arguments` became the
static `DevSaves.apply(arguments) -> bool`, which now also sets `Settings.file_path` to
`user://dev_settings.cfg`. The test runner sets it to `SaveFixture.SETTINGS_PATH`,
`user://test_settings.cfg`, before the first case. Nine assertions in `dev_tools_test.gd`.
`5.11.0`, a MINOR.

**Why.** T6.10's Gaps: `--locale=` goes through `Settings.set_value`, which saves, and the path was
a `const`. Measuring it found the suite was worse: five cases call `reset_to_defaults()`, so every
green run saved the developer's settings as an empty file. Redirect was chosen over a "don't
persist" switch, because a switch stops `save()` running in every capture and case, so a broken
`save()` would pass the ladder. **Writes only, no reload:** `Settings` loads before any
`GameRoot` child exists, reading the real file is harmless and is what a capture should show, and
reading scratch back would carry one capture's language into the next. `PATH` kept its name so no
game that reads it changes, which keeps this a MINOR rather than a MAJOR.

**Connects.** `SaveSystem.save_dir` (T5.22), whose pattern `file_path` copies; `DevSaves` (T6.10),
whose rule and `--real-saves` opt-out now cover settings; `SaveFixture` (T6.9), which names the
suite's scratch; the runner's locale pin (T5.1), which stays because the real file is still read.

**Verified.**
- Built on T6.10's tip `a4ba31a` (neither PR #70 nor #72 had merged). `--headless --import`: zero
  `SCRIPT ERROR` / `Parse Error` lines.
- **Red first, on the real `user://`.** The developer's `settings.cfg` was a 0-byte file written
  at 18:31, the same minute as `user://test_saves`: a suite had already emptied it. Backed up.
  Planted a sentinel (`locale="en"` plus a `[sentinel]` section, SHA-256 `7eb7a3b2…`). The capture
  `--new-game --locale=en_XA --shot=… --shot-frame=70 --time=18:40 --freeze-time` logged `Locale
  forced to en_XA`, and the file became `locale="en_XA"`, SHA-256 `44967d65…`. A re-planted
  sentinel, then the unchanged suite at `2483 passed, 0 failed`: the file was 0 bytes.
- **Another session was using the same `user://` at the same time.** Sentinel `slot_0N.json` files
  appeared in `user://saves` at 18:49:31, not mine, and the real `settings.cfg` was rewritten at
  18:52:01, after my suite ended. My first green run was therefore meaningless and showed 11
  failures from two suites emptying `user://test_saves` under each other. Every proof after it
  ran with `APPDATA` pointed at a private scratch directory; Godot honours it, and `user://`
  resolved there.
- **Isolated, unchanged tree** (a scratch worktree at `a4ba31a`): capture rewrote the sentinel
  (`7eb7a3b2…` → `44967d65…`, `locale="en_XA"`), and the suite, `2483 passed, 0 failed, 0
  skipped`, left it 0 bytes (`e3b0c442…`).
- **Isolated, this tree:** capture logged `Debug launch: saves go to user://dev_saves and settings
  to user://dev_settings.cfg (--real-saves keeps the real ones)` then `Locale forced to en_XA`, exit
  0, `0 warnings, 0 errors`; sentinel still `7eb7a3b2…`. The suite, `2492 passed, 0 failed, 0
  skipped` before documentation: sentinel still `7eb7a3b2…`, and `test_settings.cfg` held the
  suite's writes.
- **Plants**, each exit 1 on exactly its assertions: the settings line deleted from `apply`,
  `2490 passed, 2 failed` (`a capture's settings go to scratch`, `and a setting it changes is
  written there`); `save()` back to the fixed path, `2491 passed, 1 failed` (the write); the
  runner's line deleted, `2491 passed, 1 failed` (`the suite itself writes its settings to
  scratch — expected user://test_settings.cfg, got user://settings.cfg`). Restored each.
- All seven checkers exit 0; `settings.gd` 142 of 150, `dev_saves.gd` 23, `dev_tools_test.gd` 222.
- Suite after the documentation, isolated: `=== 2494 passed, 0 failed, 0 skipped ===`, exit 0, +11 over 2,483: 9 in `dev_tools_test` and 2 in `record_shape_test` for this row's package id, every other case unmoved, diffed per case against the unchanged tree. Boot `0 warnings, 0 errors`. (A first post-doc run failed `CONTEXT.md states the declared version`, on two bold `**5.10.0**` lines further down CONTEXT.md; fixed.)
- Windowed 960x540 capture at 18:40 frozen, with `--locale=en_XA`, looked at. Before the documentation, at frame 70: the courtyard at dusk, `[~~Day 1 | 18:40 | [~~Dusk~~]~~]`, `[~~E~~] [~~Use~~] [~~Iron Lever~~]` and the `[~~Autosaved.~~]` toast, pseudolocalized throughout. After it, frame 70 showed only `[~~Loading 50%~~]` on this tree AND on the unchanged tree, identically: the machine had slowed (400 frames took 140s). Re-shuttered at frame 300: the same courtyard and prompt, `Slot 6 written` into scratch, sentinel byte-identical.
- **The developer's real `settings.cfg`**: another session's unfixed suite rewrote it again at 19:21, to 0 bytes, byte-identical to my 18:46 backup, so nothing needed writing. The two scratch files my one un-isolated run created there were removed.

**Unblocks.** T6.6, next on `main`. Every later capture and suite run leaves the developer's
settings alone, and sentinel proofs have a recipe that other sessions cannot disturb.

**Gaps.** On a machine with no settings file, boot still writes the defaults to the real path
before anything can redirect it; that creates a file and overwrites nothing. The suite still READS
the developer's real settings, which is why the locale pin stays; a case that depends on another
setting's default must still reset first. `user://test_saves` is shared by concurrent suite runs in
different worktrees, and one empties it under the other: seen here, not fixed. **Versions
renumber at merge:** T6.5 took `5.10.0` on `main`, so T6.10 becomes `5.11.0` and this row `5.12.0`.

**Commit:** on `claude/t6-11-dev-settings`, stacked on T6.10's PR #72; PR #74, squash-merged to `main` as `9d8c34f` from branch head `5d0d787`. CI (`Ladder (stripped template)`, job 109466989630: `=== 2482 passed, 0 failed, 25 skipped ===`; full job 109466989898: `=== 2556 passed, 0 failed, 0 skipped ===`). Filled in by T6.7.

**Merge of `main` (T6.5 and T6.6) into T6.11, same day.** Auto-fix reported PR #74 conflicting.
`main` had taken `5.10.0` (T6.5) and `5.11.0` (T6.6) while this stack claimed `5.9.1`, `5.10.0`
and `5.11.0`, so the stack now lands after them: **T6.9 `5.11.1`, T6.10 `5.12.0`, T6.11
`5.13.0`**, in `project.godot`, the CHANGELOG headings, the board, ROADMAP and CONTEXT. This
DEVLOG's older entries keep the numbers they claimed, as a record. **T6.6 had also numbered a
new TODO row T6.10** (`RestPoint`'s plural), which collided with this stack's DONE T6.10, and it
is now **T6.12**. `settings_consumers_test.gd` took `main`'s `plan(79)` and kept T6.9's
`SaveFixture.activate()`. `settings.gd` is 143 of 150 with T6.5's key. Verified isolated:
`--import` zero script errors, boot `0 warnings, 0 errors`, `=== 2556 passed, 0 failed, 0
skipped ===`, which is +23 over `main`'s measured 2,533: 17 in `dev_tools_test` and 6 in
`record_shape_test`, every other case unmoved. All seven checkers exit 0, and the isolated sentinel run on the merged tree left `settings.cfg` byte-identical through the capture and the suite.

**A second merge of `main`, minutes later**, because PR #70 (T6.9) squash-merged as `8436c69` at
`5.11.1`, the number this branch had already given it. Its test code was identical to this
branch's. Its documents had reworded T6.9 after T6.5 and T6.6 ("taken ahead of T6.7") and recorded
a CI stripped count, so T6.9's own text was taken from `main`. T6.10, T6.11 and T6.12 were kept from
here. T6.9's board commit line now carries `8436c69`.
`8436c69` is 2,535; this merged tree is `=== 2556 passed, 0 failed, 0 skipped ===`, +21, with `--import`, boot and all seven checkers green again.

## 2026-09-29 — T6.12 · Nothing failed a case that saved without activating the scratch store

**Did.** Closed the gap T6.9 recorded. Before every case, `tests/test_runner.gd` calls the new
`SaveFixture.park()`, which points the store at `user://test_saves_unclaimed`, emptied. The runner
listens on `Events.game_saved` and `game_loaded`, and fails a case that saved, or loaded a file
that exists, while `save_dir` was that directory or `DEFAULT_SAVE_DIR`. A file left in the parked
directory fails it too. `save_dir_test.gd` now asserts a case starts parked, and asserts the
`is_unclaimed` rule both ways, 18 → 20. The owner confirmed taking this ahead of T6.5. T6.5 had
already merged to `main` by then, and T6.11 is another open branch, so this is T6.12, stacked on
T6.10. `5.10.1`, a PATCH.

**Why.** T6.9 offered two options, a runner that activates for every case, or a check that fails
a write to the default. Each alone leaves a hole. The check alone goes red only after a bad case
has already written or deleted the developer's slots. Activating for every case alone makes the
omission harmless and silent, and silence is how fourteen piled up. Parking is not activating: a
case still has to claim the store, and the runner says so by name if it does not. The signals
already exist for a game's own listeners, so `src/` gained no test-only seam, the line
`fixtures.gd`'s header draws.

**Connects.** `tests/framework/save_fixture.gd`, whose header now explains the two halves.
`TESTING.md`'s rule, which said "nothing fails if you forget", now says what fails and what the
check does not hear. `SaveSystem.save_to_slot` and `load_from_slot`, unchanged, and their signals.

**Verified.**
- `--headless --import` first in the worktree, exit 0.
- **Plants**, each run with seven sentinel files in the real, otherwise empty `user://saves`,
  `slot_00.json` to `slot_05.json` and `autosave.json`, each holding its own name:
  - `confirm_test` with `activate()` commented out: `=== 2485 passed, 1 failed ===`, exit 1,
    `confirm_test used the save store without SaveFixture.activate(): saved slot 3 in
    user://test_saves_unclaimed`. Sentinels intact 7 of 7.
  - `menus_test` without it: exit 1, `saved slot 2 …, saved slot 6 …`. 7 of 7.
  - `save_recovery_test` without it: **green on the first version of the check**, which heard only
    saves. It plants files by hand, loads them, and deletes them. Loads were added, and it went
    red: exit 1, `loaded slot 4 in user://test_saves_unclaimed`. 7 of 7.
- **The load check's first version had a false positive**: `item_count_test` emits
  `game_loaded(1)` by hand to stand in for a load, with no file behind it. Only a load of a slot
  that exists counts now.
- **A clean run failed eleven assertions once**, in `menus_test` and `smoke_test`, while the plant
  runs of the same code passed. Another session's headless suite, log
  `project_gulistan_2026-09-29T18-51-32.log`, ran from 18:51:32 to 18:51:43 against the same
  `user://test_saves`, overlapping this run's 18:51:34 to 18:51:46. The re-run: `=== 2485 passed,
  0 failed, 0 skipped ===`, exit 0, sentinels intact 7 of 7.
- **Broken assertion**: `save_dir_test`'s `is_unclaimed(ROOT)` expected `true`: `=== 2486 passed,
  1 failed ===`, exit 1. (Reverting it with `git checkout` also reverted this row's uncommitted
  edits to that file, which the next run caught at once. Re-applied.)
- Sentinels removed afterwards. The real `user://saves` is empty, and still empty after the final
  suite and the capture.
- Final, after the documentation landed: `=== 2487 passed, 0 failed, 0 skipped ===`, exit 0.
  Measured per case against T6.10's tip, run in a temporary worktree at 2,483: +4, 2 in
  `save_dir_test` and 2 in `record_shape_test` for this row's package id, every other case
  unmoved.
- `--check-only` on the three changed files: only the documented autoload identifier, `Events`.
- `--import`: zero `SCRIPT ERROR` / `Parse Error` lines. Boot `--quit-after 30`: `0 warnings,
  0 errors`. (Run while the sentinels were planted, boot logged 7 errors, the main menu reading
  files that are not save JSON. That was the sentinels. It was clean once they were removed.)
- All seven checkers exit 0. `test_runner.gd` 182 of 250, `save_fixture.gd` 31 of 250.
- CI on `3e62559`, both jobs green: full `=== 2487 passed, 0 failed, 0 skipped ===` (job 109424173775),
  stripped `=== 2413 passed, 0 failed, 25 skipped ===` (job 109424174438). `TESTING.md` still said
  T6.9's stripped `2399`, which T6.10 never re-measured, and now says `2413`.
- Windowed 960x540 capture at 18:40, frozen, looked at: the courtyard at dusk, the HUD's
  `18:40 | Dusk`, the `[E]` prompt. Session `0 warnings, 0 errors`.

**Unblocks.** T6.6, the next planned row. T6.5 is on `main`. Any later case that saves is caught
by the runner if it forgets, so the rule in `TESTING.md` is now enforced.

**Gaps.** **Two suite runs at once still share `user://test_saves`** and `user://test_fixtures`,
and each `activate()` empties it. That caused the one red clean run above. Flagged as its own task:
per-process scratch directories. **The check does not hear** a file written by hand and deleted
without ever being loaded, or a bare `has_slot`/`slot_info` read. Parking keeps both away from
real saves, so they are harmless, just unannounced. **This branch conflicts with `main`**, as
T6.9's and T6.10's do, since T6.5 landed. Merge in order T6.9, T6.10, T6.12, taking each version
after whatever `main` holds.

**Commit:** on `claude/t6-12-save-guard`; PR #73, squash-merged to `main` as `76cd32d` from branch head `c81729f`. CI (`Ladder (stripped template)`, job 109474633431: `=== 2486 passed, 0 failed, 25 skipped ===`; full job 109474633769: `=== 2560 passed, 0 failed, 0 skipped ===`). Filled in by T6.7.

### 2026-09-29 — T6.12, `main` merged in

**Did.** T6.5 (`5.10.0`) and T6.6 (`5.11.0`) merged to `main` while PR #73 was open, and PR #73 carries
T6.9 and T6.10 too. Merging `main` in conflicted in ten files, all documents except
`project.godot` and `settings_consumers_test.gd`. The stack renumbered in order: T6.9 `5.11.1`,
T6.10 `5.12.0`, T6.12 `5.12.1`, and CHANGELOG, board, ROADMAP and CONTEXT now say so. The plan
kept both sides of `settings_consumers_test` (T6.9's `SaveFixture.activate()` and T6.5's new
assertion, plan 79). **An id collision:** T6.6 had planned `RestPoint`'s plural form as T6.10, not
knowing the open capture-saves T6.10. That row was DONE with a PR and commits under the name, and
the planned row had only documents, so the planned row moved, to **T6.13**. The entries above
that say "T6.10" for the plural are left as written, because they record what was true then.

**Verified.** `--import`, 0 `SCRIPT ERROR`/`Parse Error` lines. Suite `=== 2549 passed, 0 failed, 0
skipped ===`, exit 0, which is `main`'s 2,533 plus the stack's 16. The first run failed three
assertions in `slot_header_test` while another process's log (`20-24-52`) was writing
`test_saves`. That is the shared-directory race again, and the re-run was clean.

**Then T6.9 itself landed** on `main`, squash-merged from PR #70 as `8436c69`, at the same `5.11.1`
this stack had given it. It had been re-resolved on its own branch against T6.5 and T6.6, so
`main`'s wording of the T6.9 DEVLOG entry, board section and row replaced this branch's copies,
and the board's T6.9 commit line now names `8436c69`. Everything T6.10 and T6.12 added was kept.
`main` still called the plural-form row T6.10, and this branch keeps it at T6.13. Suite
`=== 2549 passed, 0 failed, 0 skipped ===`, all seven checkers exit 0, boot `0 warnings, 0 errors`.
The ladder's windowed capture at `--shot-frame=70` photographed `Loading 48%` three times running
after this merge. Frames were slow because other sessions' Godot processes (`base 5.10.2`) were
running: a 260-frame run took 113 s. Outside the documents the tree is byte-identical to
`2e40f4a`, whose frame-70 capture had shown the courtyard, and a capture at frame 240 shows the
courtyard at dusk, the HUD and the `[E]` prompt. That run logged one `Keeper cannot reach 'dais'`,
from simulating at about 2 fps, and no other error.

**Then T6.11 landed** on `main`, squash-merged from PR #74 as `9d8c34f` at `5.13.0`, carrying T6.10
(`5.12.0`) with it. This row is now `5.13.1`. T6.11's merge had renumbered the plural-form row
from T6.10 to **T6.12**, which collided with this row: DONE, with PR #73 and commits under the
name. So the planned row moved again, to **T6.13**, and the board and CONTEXT record both moves.
The documents were rebuilt on `main`'s versions, with T6.12's own content re-applied, rather than
merging this branch's older copies of T6.9 to T6.11. `save_fixture.gd` keeps both headers and
both constants, T6.11's `SETTINGS_PATH` and this row's `UNCLAIMED`. The runner keeps T6.11's
one-time settings redirect beside this row's per-case park and check. `dev_saves.gd` and
`dev_tools_test.gd` are `main`'s. Suite `=== 2560 passed, 0 failed, 0 skipped ===`: `main`'s
2,556 and this row's 4.
All seven checkers exit 0, boot `0 warnings, 0 errors`, and the frame-70 windowed capture shows the courtyard at dusk again, with the HUD and the `[E]` prompt.

## 2026-09-29 — T6.7 · Dialogue for fast and slow readers

**Did.** First merged PR #75 (T6.6) with plain `gh pr merge 75 --merge`: it was CLEAN, with all
four checks green. Then branched `claude/t6-7-dialogue-speed` from `origin/main` at `db0d6ec`.
Cancel during a conversation now calls `DialogueScreen.skip()`, which walks the runner through
`advance()` until a choice is offered or the conversation ends. Added
`gameplay/dialogue_auto_advance`, off by default, which moves a whole line on after
`hold_seconds()` and never answers a choice. The hint names the skip key and reads "Auto" while
auto-advance is on. Four CSV rows. The new assertions are a new file, `dialogue_speed_test.gd`,
because `dialogue_test.gd` would have gone to 305 of 250.

**Then `main` moved under the open PR.** T6.9 to T6.12 were merged while this row was in
review, so PR #78 went CONFLICTING. Merged `origin/main` in, never rebased; ten files conflicted,
all of them documents except `project.godot` and `settings_consumers_test.gd` (T6.12's
`SaveFixture.activate()` beside this row's plan of 80). This row was claimed as `5.12.0` and
lands as **`5.14.0`**, above T6.12's `5.13.1`. The plural-form row it called T6.10 is **T6.13**
on `main`. `settings.gd` was 143 after T6.11, so it is 144 of 150 here. Main's ROADMAP had lost a
line from T6.6's entry, which ended mid-sentence at "The `tr_n`"; restored. The DEVLOG Commit
lines for T6.6, T6.10, T6.11 and T6.12 and the board's for T6.10 and T6.12 are filled in from
`git log` and each PR's job logs.

**Why.** Forgotten #5: a player who reads fast will hate the game without a skip, and one who
reads slowly may want the conversation to keep going without them. The one hard rule was the
manifest's: a skip must not skip past a choice or skip an effect. Walking the runner satisfies
both, because effects fire on arrival and the runner already refuses to advance at a choice.

**Connects.** `DialogueRunner` is untouched; the screen only calls `advance()` more often. Cancel
was free in a conversation, because `UiRoot` ignores it on a screen with `closes_on_cancel =
false` and the pause key refuses while a screen is open. `KeyBindings.text_for(Actions.CANCEL,
pad)` names the key, so the T6.2 device switch and a rebind both rename it. The settings screen
drew the new row with no edit, because it is generated from `Settings.DEFAULTS`.

**Verified.**
- Rung 2 import exit 0; rung 3 `--quit-after 30`: `0 warnings, 0 errors`.
- All seven checkers exit 0 (see the board's T6.7 section for the budget split).
- Suite: `=== 2591 passed, 0 failed, 0 skipped ===`, against `2560` on a `main` worktree at `76cd32d` (before the merge: `2564` against `2533` at `db0d6ec`), +31: 25 in the new `dialogue_speed_test`, 3 in `options_test` and 1 in `settings_consumers_test` for the new setting's row and consumer, and 2 in `record_shape_test` for this row's own package id; every other case unmoved.
- Plants. `runner.stop()` as the skip: `2549 passed, 13 failed`, first `a skip stops at the
  choice — expected menu, got`. Deleting the loop's `not _waiting_on_choice()` stayed green,
  because the runner refuses at a choice; recorded, not hidden.
- Windowed capture through a temporary probe: the "Auto" hint mid-reveal at frame 90, and the
  menu waiting with three choices at frame 1,400. Both PNGs looked at; probe removed.
- The shared `user://` hazard: every suite run waited until `tasklist` showed no Godot, and the
  user data dir was copied aside first. `settings.cfg` ended identical. `saves/autosave.json` and
  `test_saves/slot_04.json` had been written at 20:29 by another session's run, seconds before
  the copy, and were gone afterwards; the autosave was put back.

**Unblocks.** T6.8, closing the forgotten list behind a text scan; item 5 is now DONE.

**Gaps.** No backlog screen. The pad's B also means "back" in most menus, and in a conversation it
now skips; that is the conventional mapping, but no player has tried it. A slow capture logged
`Keeper cannot reach 'dais'` (gotcha 21's guard) and was not investigated.

**Commit:** on `claude/t6-7-dialogue-speed`, PR #78 targeting `main`. No SHA, per board item 6. CI on `e6db60b`, PR #78: `Ladder (stripped template)`, job 109480897827: `=== 2517 passed, 0 failed, 25 skipped ===`; `Ladder (full checkout)`, job 109480898120: `=== 2591 passed, 0 failed, 0 skipped ===`. `TESTING.md` now states the stripped `2517`.

## 2026-09-29 — T6.13 · Two suite runs at once, in two worktrees, broke each other

**Did.** New `tests/framework/run_scratch.gd`, class `RunScratch`: one scratch directory per
process, `user://test_runs/<pid>`, begun empty before the first case, heartbeat written before
every case, removed after the report, and a stale sibling pruned by a later run. Every scratch path
the suite writes moved under it: `SaveFixture.root()` / `settings_path()` and `Fixtures.root()` /
`*_dir()` replace constants, and `content_scan_test`, `export_test` and `save_dir_test` build
their own directories from `RunScratch.path()`. `KeyBindings.file_path` is a new static var the
runner points at the run's copy. `dev_tools_test` proves a settings write on a path of its own
instead of deleting and re-creating the shared `user://dev_settings.cfg`. 26 assertions in the new
`run_scratch_test.gd`. `5.12.0`, a MINOR.

**Why.** T6.11's Gaps: every worktree shares one `user://`, and `SaveFixture.activate()` empties a
fixed directory in it. The fix had to cover every scratch path, not only the save store:
the red runs failed in fixture content and settings too. Per process rather than per worktree,
because two suites in ONE worktree collide the same way. The pid names the directory because no
two live processes share one. It does NOT say whether a run is alive; see Verified.

**Connects.** `SaveFixture` (T5.22, T6.9, T6.11) and `Fixtures` (T1.3), whose roots moved;
`KeyBindings` (T5.5), whose path became redirectable on `Settings.file_path`'s pattern (T6.11);
`DevSaves` (T6.10), whose scratch stays outside every run's directory; T6.12's `UNCLAIMED`, on a
sibling branch, which still needs moving.

**Verified.**
- Built on T6.11's tip `15775bd`, PR #74 unmerged. `--headless --import`: no `SCRIPT ERROR` /
  `Parse Error` lines. Unchanged tree alone: `2494 passed, 0 failed`.
- **Red, unchanged tree.** First on the shared `user://`, two runs 0.3s and 0.6s apart: 16 and 18
  failed, then 9 and 27, with other sessions' suites running on the machine too. Then isolated: a
  scratch worktree at `15775bd`, both runs sharing one private `APPDATA` via a script,
  `pair.sh`, at four offsets. **0.3s: 15 and 8 failed. 2s: 0 and 0. 6s: 2 and 1. 12s: 0 and 0.**
  The failures included `the autosave slot accepts a write — expected 0, got 12`, `QuestDb reports
  a bad file in its root — expected 1, got 2`, `and after all six the autosave file is still
  there`, and `dialogue_test` crashing on a conversation the other run had just rewritten.
- **The first fix was not green, and why.** On the shared `user://`, three pairs: two passed, the
  third failed 12 in `save_recovery_test` (`Cannot call method 'store_string' on a null value`).
  Cause: `run_scratch_test` pruned the SHARED parent with a fake liveness answer, calling every
  other run dead. Fixed by pruning a parent of its own. Then, isolated, 0.3s and 2s passed, and
  **6s and 12s failed 3 each**, all in `options_test`, after `Could not write
  user://test_runs/7616/settings.cfg: File not found` at the second run's start. A probe settled
  it: `OS.is_process_running` answered `true` for its own pid, **`false` for explorer's**, and
  `true` for its own `OS.create_process` child. On Windows it knows only processes the caller
  started, so every `begin()` deleted every other live run's directory. Liveness became a
  heartbeat file, pruned only when over 900s old; a directory with no heartbeat is kept.
- **Green, this tree, isolated, same script, same four offsets: 0.3s, 2s, 6s and 12s all
  `2520 passed, 0 failed` on BOTH runs, exit 0**, and `test_runs` empty afterwards.
- **Plants**, on the heartbeat version, each exit 1 on exactly its own assertions, restored after:
  `root_for` returning the shared parent, `2518 passed, 2 failed` (`the root is named for this
  process`, `two processes never share a root`); the heartbeat age check deleted, `2517 passed, 3
  failed` (`a run whose heartbeat is fresh is left alone` and the two counts beside it); the
  no-heartbeat guard deleted, `2518 passed, 2 failed` (`a run with no heartbeat yet is left
  alone`, `so nothing is removed`); the runner's bindings pin deleted, `2518 passed, 2 failed`
  (`the bindings file the runner pinned is this run's own`, `and the player's bindings file is
  not written`). Before the heartbeat, the pid version's liveness plant failed its 1.
- All seven checkers exit 0. Budgets, all of 250: `run_scratch.gd` 48, `run_scratch_test.gd` 76,
  `test_runner.gd` 168, `key_bindings.gd` 105, `dev_tools_test.gd` 224.
- Suite after the documentation: `=== 2522 passed, 0 failed, 0 skipped ===`, exit 0, +28 over
  2,494: 26 in `run_scratch_test` and 2 in `record_shape_test` for this row's id, every other case
  unmoved, diffed per case against the unchanged tree. The stripped count is CI's.
- No real `user://input.cfg` existed on this machine, so the bindings plant cost nothing.

**Unblocks.** Concurrent suites across sessions, which is the normal state of this machine. Any
sentinel proof no longer needs a private `APPDATA` to keep the SUITE out of it, only other
launches.

**Gaps.** T6.12's `user://test_saves_unclaimed` is on a sibling branch and still fixed; whichever
merges second moves it. A crashed run's directory is pruned only after 15 minutes, and that path is
proved with a negative threshold, not by waiting. The old fixed directories from earlier runs stay
in `user://` until a developer deletes them, on purpose. Twelve code files, over the size rule,
most of them one-line renames. **Versions renumber at merge**, as every row in this stack does.

**Commit:** on `claude/t6-13-parallel-suites`, stacked on T6.11's PR #74. No SHA, per board item 6.

**Merge of `main` (T6.12 and T6.7) into T6.13, same day, and T6.12's parking directory moved.**
PR #77 reported conflicting: T6.9, T6.10 and T6.11 had squash-merged under it, and T6.12 (PR #73)
and T6.7 (PR #78) had landed after them. T6.12 is the sibling this entry's Gaps named, so the move
it asked for was made in the merge itself, not as a row of its own.
- **Did.** `SaveFixture.UNCLAIMED`, the fixed `user://test_saves_unclaimed`, is now
  `SaveFixture.unclaimed()`, returning `RunScratch.path("saves_unclaimed")`. Every caller moved:
  `park()`, `is_unclaimed()` and `unclaimed_files()` in `save_fixture.gd`, the leftover-file message
  in `test_runner.gd`, and `save_dir_test.gd`, whose `SaveFixture.ROOT` also became `root()`. The
  runner calls `RunScratch.beat()` and then T6.12's `SaveFixture.park()` before every case. Four
  comments still naming `SaveFixture.ROOT` now say `root()`.
- **Why.** `park()` EMPTIES the parking directory before EVERY case, so as a fixed name it was the
  same race T6.13 closed, met on every case rather than only on the ones that save.
- **Assertions.** `run_scratch_test.gd` lists two more paths, 26 → 28: the parking directory, and
  `SaveSystem.save_dir` as the runner left it for that case. The second checks what the runner
  actually DID, not only what the function returns. **Plant:** `unclaimed()` returning the old
  fixed name gives `2619 passed, 2 failed`, exactly those two.
- **Renumbered.** Versions: `main` was at `5.14.0` (T6.7), so this row lands as **`5.15.0`**,
  claimed `5.12.0`. Ids: the plural row, which `main` numbered T6.13, becomes **T6.14**. A planned row
  has only documents to update, so it moves and the DONE row keeps its id, as at T6.12's merge.
- **Verified, alone.** `--headless --import` first, no `SCRIPT ERROR` or `Parse Error` lines. Boot `--quit-after 30`: `0 warnings, 0 errors`.
  Suite `=== 2621 passed, 0 failed, 0 skipped ===`, exit 0. All seven checkers exit 0.
  `test_runner.gd` 168 → 191 of 250 with T6.12's check; `save_fixture.gd` 35, `run_scratch_test.gd`
  78. Windowed 960x540 capture at 18:40, looked at: the courtyard at dusk, HUD, the `[E]` prompt and
  an `Autosaved.` toast, `0 warnings, 0 errors`.
- **Verified, two at once.** `pair.sh` from this entry, both suites sharing one private `APPDATA`,
  offsets 0.3s, 2s, 6s and 12s. **Merged tree: all eight runs `2621 passed, 0 failed`, exit 0, and
  `test_runs` empty afterwards.** With the fixed name planted back, the pairs showed only the two
  planted failures each: an honest suite leaves the parking directory empty, so the race had
  nothing to delete. So a second plant made it visible: `settings_effects_test` without its
  `activate()`, which writes the autosave and all six slots into the parking directory.
  **Fixed name: at 0.3s, 6 and 5 failed**, three and two beyond the planted ones, all in that case
  and all the OTHER run's doing: `and after all six the autosave file is still there — expected true,
  got false` (the other run's `park()` deleted it) and `so quitting from the main menu cannot
  flatten a real run's autosave — expected false, got true` (the other run's file). At 2s to 12s,
  3 and 3, no collateral. **Per run: 1 and 1 at all four offsets**, only the forgetful case, each
  naming its own `user://test_runs/<pid>/saves_unclaimed`.
- **Suite size.** Suite 2,591 on `main` at `287e783` → **2,621**, +30: 28 in the new `run_scratch_test` (26 from T6.13, and 2 from the merge for the parking directory) and 2 in `record_shape_test` for this row's own package id; every other case unmoved. Measured per case against `main`, after the documentation landed. The stripped count is CI's.
- **Unblocks.** T6.8, next, unchanged. T6.14, the plural row, after it.
- **Gaps.** None new. The stripped count is CI's.

## 2026-09-29 — T6.8 · Close the list, and gate it

**Did.** New `tests/unit/forgotten_list_test.gd` and its `CASES` line: it reads
`SYSTEMS_INVENTORY.md` § "Commonly forgotten" and fails an item without the bold marker
`DONE — <id>` or `CLOSED (game's) — <id>`, an id with no row on the board, and a gap in the
numbering. Rewrote the verdicts of items #1, #6 and #8 to #13 into that marker, and added a
paragraph at the top of the section saying the rule. Ticked the last Phase T6 exit criterion.

**Why.** The phase's exit criterion. The list was written so that fifteen regrets would be
decisions, and T6.0 had already found three items describing settled work as missing; without a
gate a new item is an oversight again the moment it is written.

**Connects.** `record_shape_test.gd` (T5.24), whose package-id shape and whole-id lookup the new
case reuses; the board, which is the index an id must be findable in.

**Verified.**
- **Red first, on the list as it stood:** the new case failed 16, two for each of #1, #6, #8, #9,
  #10, #11, #12, #13; `=== 2637 passed, 16 failed ===`, exit 1.
- **After the edits:** `forgotten_list_test: 32/32`, `=== 2653 passed, 0 failed ===`, exit 0.
- **Plants**, restored after: #8's id to `T6.99` fails `forgotten #8 names T6.99, which has a row
  on the board`; #14 renumbered 16 fails `numbered 1 to N without a gap`. `2651 passed, 2 failed`,
  exit 1, exactly those two.
- The first draft did not parse: the heredoc that wrote it turned every doubled backslash into one, so
  `"\*"` was an invalid escape. The patterns now use bracket classes, `[*]`, `[.]`, `[(]`, and no
  backslash at all, which also means no reader has to count them.
- **Ladder, all green:** `--import` 0 `SCRIPT ERROR` / `Parse Error`; boot `0 warnings, 0 errors`; `=== 2655 passed, 0 failed, 0 skipped ===`, exit 0; all seven checkers exit 0. No visual or input surface: nothing under `src/` changed, so there is nothing to photograph, said rather than skipped.

**Unblocks.** T6.14, the plural form, which is the last row of the phase.

**Gaps.** #8 was first closed as a placeholder, because the owner's playtest verdict had not been
given. Asked on 2026-09-30, the owner has not playtested yet and will soon; the closure stands until then.
No playtest of the defaults was run. The gate checks that a verdict exists and names a real package, never that it is right.
Suite 2,621 on `claude/t6-13-parallel-suites` at `8021b59` → **2,655**, +34: 32 in the new `forgotten_list_test` (two, plus two for each of fifteen items) and 2 in `record_shape_test` for this row's own package id; every other case unmoved. Measured per case against `8021b59`, after the documentation landed. Stripped, in CI: `2581 passed, 0 failed, 25 skipped`.

**Commit:** on `claude/t6-8-close-the-list`, PR #79, built on T6.13's PR #77. No SHA, per board item 6.

## 2026-09-30 — T6.14 · A count that reaches a string picks its plural form

**Did.** `RestPoint` asks `TranslationServer.translate_plural(rested_key, rested_key, hours)` for
the form the locale's rule picks and sends that, and the new static `hours_for(minutes)` reports
the nearest whole hour, never zero. `strings.csv` gained the importer's `?plural` column after
`keys` and the rest row's second form below it; `gen_pseudolocale.gd` filled `en_XA` for both.
New `tests/unit/plural_count_test.gd` and its `CASES` line. Gotcha 82. Phase T6 marked COMPLETE.

**Why.** T6.6's `tr_n` check found `{hours}` = `floori(minutes / 60)` in one key: a rest under two
hours read "1 hours", one under an hour "0 hours". It is the only count in the base with a noun
beside it, and the last row of the phase.

**Checked first.** The regenerated 4.7 reference lists four `ResourceImporterCSVTranslation`
options and no description, so it does not say. A scratch project with a `keys,?plural,en,fr`
CSV did: the importer builds plural messages, a row with an empty key carries the next form, and
French answered its singular for 0 where English answered its plural. `.po` was not needed.

**Connects.** `notification_toast.gd`, whose `tr(key).format(args)` the test reproduces and whose
`tr()` is why the choice cannot happen there without a new argument; `Clock.skip_to_hour`, which
skips 1 to 1,440 minutes and so can never honestly be reported as zero; `gen_pseudolocale.gd`,
`check_content`, `check_strings` and `check_boundary`, all of which already tolerated the new
column and the empty-key row, checked by reading each before the edit.

**Verified.**
- **Red first**, on the old `rest_point.gd` and CSV: `=== 2659 passed, 8 failed ===`, exit 1.
  "two hours are plural — expected 2 hours slip past., got 2 hour slips past." (`tr()` answers the
  first form), "half an hour reads as one hour, not zero — … got 0 hour slips past.", and the
  three CSV lint lines on the one `{hours}` row.
- **After:** `=== 2667 passed, 0 failed, 0 skipped ===`, exit 0, on the T6.8 tip and again after
  rebasing onto `main` at `0d3585d`.
- **Plants**, restored after: emitting `rested_key` instead of the chosen form, 3 failed; flooring
  again, 3 failed; deleting the CSV's second form, 1 failed, which exposed a weak assertion (a
  missing form comes back as the key, which also differs from the singular). Tightened to refuse
  the key, the same plant fails 2.
- **Photographed**, windowed, `--new-game --time=19:00 --stand-by=StoneBench --interact=1`: a
  59-minute rest reads "You rest a while. 1 hour slips past." (the old code: "0 hours"). With
  `--time=07:00 --locale=en_XA`, a 778-minute rest reads "[~~You rest a while. 13 hours slip
  past.~~]". The first capture, at frame 150, showed "Autosaved." because the rest line was queued
  behind it; frame 330 showed it.
- **Ladder, all green:** `--import` 0 `SCRIPT ERROR` / `Parse Error`; boot `0 warnings, 0 errors`;
  all seven checkers exit 0; `check_content` reports `localization columns: 4 (keys, ?plural, en, en_XA)`.

**Unblocks.** Nothing queued: Phase T6 is complete. A game's own counted strings now have a
proved path, and the lint catches a `{hours}` row authored with one form.

**Gaps.** The toast did not learn a `count` argument, so `RestPoint` is the one sender passing
resolved text through `notify_requested`, a signal documented as taking a key; its header says
why, and when to move it. The lint knows only `{hours}`; a game's own counted placeholder is not
checked. Only English's rule is asserted. #8's closure still waits on the owner's playtest.
Suite 2,655 on `main` at `0d3585d` → **2,669**, +14: 12 in the new `plural_count_test` and 2 in
`record_shape_test` for this row's own package id. The stripped count is CI's.

**Commit:** on `claude/t6-14-plural-forms`, built on `main` at `0d3585d`. No SHA, per board item 6.

## 2026-09-30 — Process · Packages run one at a time

**Did.** Audited every chat, worktree and branch of the project at the owner's request ("multiple
chats showed starting multi worktrees instead of one at once"). Found 20 worktrees, 19 of them
finished work with merged PRs, one live (T6.14, PR #80), and **nothing lost**: every branch ahead
of `main` held only merge commits or patches already on `main` — T6.12's head `c81729f` is
byte-identical to its squash `76cd32d`, T6.9's `123b6aa` is a count since superseded, and PR #76
is an earlier T6.13 closed in favour of #77. Merged PR #80 on green CI and recorded its stripped
count. Wrote the rule down: `WORK_PACKAGES.md` § The rules gains **Serial, not parallel**, closing
item 7 requires the merge, item 8 raises the next chip only after it, item 9 removes the worktree.
`CLAUDE.md` and `CONTEXT.md` carry it. `5.16.1`, a docs-only PATCH.

**Why.** Four causes, all visible in the history. (1) Item 8 raised the next chip at push, not at
merge, so each package began from a `main` that lacked the one before it and had to merge `main`
back in — `claude/t6-10-capture-saves` did so three times. (2) Defects found mid-package were
raised as chips, so T6.9 to T6.13 ran at once. (3) Ids and versions were claimed at start and
reassigned at merge: T6.14 was numbered four times, and `5.10.0` to `5.12.0` were each claimed by
one row and shipped by another. (4) Chips raised early were started more than once: T6.6 had two
chats, T6.7, T6.8 and T6.13 three each. And the collision was not theoretical — T6.13 exists
because two suites in two worktrees emptied each other's saves.

**Connects.** The board's closing checklist; `CLAUDE.md` § One package per chat; T6.13's
`RunScratch`, which isolates the suite but not `DevSaves`' `user://dev_saves` or
`user://dev_settings.cfg`, both still one path for every worktree on the machine.

**Verified.** `--import` 0 `SCRIPT ERROR` / `Parse Error`; boot `0 warnings, 0 errors`; suite
`=== 2669 passed, 0 failed, 0 skipped ===`, exit 0, unmoved; all seven checkers exit 0. **The
first suite run failed four `font_chain_test` assertions** straight after fast-forwarding the main
checkout over T6.6 to T6.14; a second `--import` cleared them with no file changed — gotcha 53, a
cache question before a code question. PR #80's CI on `f6f0344`: stripped `2592`, full `2669`.

**Unblocks.** Whatever the owner opens next starts from one clean `main` and one worktree.

**Gaps.** The 19 finished worktrees, their local branches and the merged remote branches are
**not** removed: the tooling refused the bulk removal as irreversible, so it is the owner's to
run. The rule is prose, and nothing gates it; a chat can still ignore it. `user://dev_saves` is
still shared across worktrees.

## 2026-10-16 — Process · Development moves to Linux and the cloud

**Did.** The owner is wiping this Windows machine and moving to Linux and Claude Code cloud
sessions. Audited what lived only on its disk: the repository was fully pushed (no uncommitted
work, no unpushed branch, no stash, one worktree), so the losses were Claude's per-machine memory
and the Windows engine install. Added `tools/cloud_setup.sh`, which installs the engine CI pins
(same digest and `--version` string as `.github/actions/setup-godot`) and runs `--import`; moved
the memory into `.claude/agent-notes.md`; `CLAUDE.md` § The engine points at both.

**Why.** A cloud session starts from a clone with no engine and no memory. Without these it would
relearn the merge procedure and the suite-total fixpoint by failing them.

**Connects.** `.github/actions/setup-godot/action.yml` is still the one pin; the script copies it.

**Verified.** On the Windows machine before the move: `--import` 0 `SCRIPT ERROR` / `Parse Error`; boot `0 warnings, 0 errors`; suite `=== 2669 passed, 0 failed, 0 skipped ===`, exit 0, unmoved; all seven checkers exit 0.

**Unblocks.** Every later package, run from the cloud.

**Gaps.** The script has not run on a Linux machine from this session; the cloud session that
continues this work runs it first. The windowed capture rung needs a GPU, which cloud sessions
lack, so it needs the owner's Linux desktop.
