# Roadmap

> **Read [`TEMPLATE.md`](TEMPLATE.md) first.** This project is a reusable base for many games,
> not one game. Phases 0 to 2 below happened and are accurate. Phases 3 and 4 were retired on
> 2026-08-26 because they planned a *consuming game's* work, and are replaced by the T-phases.

Phases, and the exit criteria that decide when each one is actually finished. An exit
criterion must be checkable by running the engine, not by reading the code and feeling good
about it.

Art generation is out of scope throughout. Every phase must work on placeholder art, and
"replace the placeholders" is a separate track that can start at any time without blocking
anything here.

---

## Phase 0 — Foundation · **COMPLETE**

*Goal: an empty folder becomes a project that boots, logs, and can be verified.*

Delivered:
- 80-directory layered structure, engine config, version control
- Ten autoloads: logging, events, input, settings, save, flags, clock, weather, audio, director
- Warnings-as-errors, making GDScript statically checked
- Placeholder art generator
- The verification ladder, all five rungs proven

Exit criteria, all met:
- [x] `--headless --import` completes with no errors
- [x] `--headless --quit-after 30` boots with **0 warnings, 0 errors**, exit code 0
- [x] Every script passes the parse and type gate
- [x] A save participant can register, and the save envelope round-trips — NOTE: this was
      marked met on 2026-08-23 having only been observed as a log line. The round trip was
      first actually executed on 2026-08-24 by the test suite, and passes.
- [x] A frame can be captured to PNG and inspected

## Phase 1 — One area, one character · **COMPLETE, and honestly so since 2026-09-04**

> **This phase read COMPLETE for months while carrying three unticked exit criteria**, and
> Phase 2 read IN PROGRESS with one. Nobody had lied: each was ticked as it was proved and
> the three that were awkward to prove — an eight-direction walk-through, a save across a
> real relaunch, and a 30-second session — were left, then the phase was called done on the
> strength of everything else. That is the drift this project polices everywhere else, in
> the one file that describes whether the project is finished. **T5.1 proved all four
> rather than ticking them**, and one of the four turned out to be a genuinely missing
> FEATURE rather than an unproved one: the locale setting was wired to nothing. The lesson
> is the cheap half of gotcha 23 — a criterion nobody has run is a criterion nobody knows
> the answer to, and "complete except for the hard ones" is how 409 passing checks happened.

*Goal: a person can be walked around a lit, living space and touch things in it.*

Done:
- HD-2D camera rig with tilt-shift depth of field
- Billboarded, lit, shadow-casting 8-way character sprite
- Camera-relative movement with walk, run and sneak
- Day/night lighting driven by the world clock, verified at dawn, midday, dusk and night
- Weather state affecting sun and fog, verified under a forced storm
- The courtyard: ground, pillars, walls, a dais, two lanterns, spawn markers

Remaining: nothing — the last item, the hard-coded-string audit, shipped as `tools/check_strings.gd`
in WP-14 (2026-09-01).

Also done, ahead of Phase 2 because every screen needs it first:
- Screen stack, pause semantics and input contexts (WP-02) - a screen declares whether it
  pauses; UiRoot does the pausing; input readers hold NAMED tokens so two of them cannot
  release each other
- The HUD clock readout and the inventory screen (WP-03) - the stack's first real
  consumers, plus the one action-to-screen binding and keyboard/gamepad focus in a screen

Exit criteria:
- [x] Walk the courtyard, and the character faces the direction of travel correctly in all
      eight directions — done 2026-09-04 (T5.1). `facing_test.gd` asserts the mapping from a
      direction of travel to a facing and a sheet column, in the form that holds for every
      camera angle: the eight directions stay distinct, and one sector of turn advances the
      facing by exactly one. Planted both ways — swapping the axes in `_screen_angle` gives
      `expected 1, got 7`, and deleting the standing-still guard gives `expected 0, got 2`.
      A live windowed probe then walked the real player through all eight in the courtyard,
      reporting `facing=N column=N` for N in 0..7, and a capture at frame 140 was read.
- [x] Approach three overlapping objects and select each one deliberately — ranking plus
      Tab cycling, done 2026-08-24
- [x] Pick up an item; it appears in the inventory and no longer exists in the world —
      done 2026-08-25, covered by the test suite
- [x] Refuse at a locked gate, throw the lever, open it, reload, and it is still open —
      done 2026-08-24, covered by the test suite
- [x] Open a chest, take its contents, reload, and it is still open and still empty —
      done 2026-08-25, covered by the test suite
- [x] Rest on the bench and watch the light change — done 2026-08-26. Two windowed captures
      from the same 06:30 start, one with the same skip the bench performs, show warm dawn
      becoming cool night with the lantern pools lit
- [x] Save, quit, relaunch, continue — position, time, weather and inventory all restored —
      done 2026-09-04 (T5.1), and in TWO PROCESSES, which is the whole point: the existing
      `--cross-area-save` reloads in process and cannot tell a value read back from disk
      from one that was simply never cleared. Run one posed `lantern_hall / 0.00,-4.20 /
      day 3 21:45 / STORM / carrying 1` and saved it; a fresh process reported that line
      back identically after loading. The boot line before the load is the control —
      `area='' at=0.00,0.00 day=1 time=06:00 weather=0 carrying=0` — and the weather is
      deliberately STORM rather than CLEAR, because CLEAR is the boot default and would
      have been right by accident.
- [x] Test suite passes headless and exits non-zero on failure — 606 assertions
- [x] A screen opens over the world, gameplay input stops, the fade still runs over the
      top of it, and Escape restores control — done 2026-08-26, windowed captures plus a
      real-input probe in the live tree
- [x] Press I and the inventory opens with real rows, grouped by category with localized
      names and counts; the world freezes; arrows and the d-pad move focus between rows;
      Escape closes it and control returns — done 2026-08-26, windowed capture at dusk and
      midday plus a real-input probe that pressed I, Escape and I twice in the live tree
- [x] The HUD shows the clock and follows it — done 2026-08-26, windowed capture and an
      assertion driving the real Clock
- [x] Two overlapping input locks release correctly: lock A, lock B, release A, the player is
      still locked — done 2026-08-26, covered by the test suite
- [x] A 30-second play session produces **zero** warnings or errors in the log — done
      2026-09-04 (T5.1), and it had simply never been run: the boot rung is 30 FRAMES at the
      main menu (gotcha 31). A windowed 33.6-second session that entered the courtyard,
      baked its navmesh, opened the satchel, cycled the sensor and interacted twice ended
      `0 warnings, 0 errors` with zero `SCRIPT ERROR`, `Parse Error` or leaked-RID lines.
- [x] The budget checker reports no file over its limit — a mandatory close-out gate for every
      package since WP-01; 73 files, 5,638 code lines, 0 violations at WP-06

> **Phases map onto work packages.** `docs/WORK_PACKAGES.md` is the executable version of this
> document: fifteen packages, one chat each, in dependency order. When the two disagree, the
> board is what is actually being worked and this file needs updating.

## Phase 2 — Two areas and a reason to move · **COMPLETE, 2026-09-04**

*Goal: prove the world is a world, not a room.*

- [x] A second area, with a door between them — the Lantern Hall, an interior (WP-04)
- [x] Loading that hides behind the fade, with the shader warm-up hitch handled (WP-04)
- [x] Navigation baking, and one NPC that walks a route by the clock (WP-06)
- [x] Dialogue runner, dialogue UI, and an authorable conversation format (WP-05)
- [x] Path actions — the non-combat verbs you perform on a person, with a standing that gates
      them and that they move (WP-07). **A refusal and a failure are different things, and
      keeping them apart is the whole design**: a refusal happens BEFORE anything and costs
      nothing, a failure happens AFTER committing and costs standing, and `success_standing` is
      a threshold rather than a probability because a save-scummed mechanic is experienced as a
      slot machine rather than as a relationship. This line was missing from the roadmap
      entirely until T5.24 gated the question
- [x] The pause menu itself, and the other four menus with it (WP-12, taken early because
      Phase 3's controller-navigation criterion needed screens to navigate)
- [x] Localization wired for real: every string is already an ID, and since T5.1 the locale
      SETTING reaches `TranslationServer` and there is a second language to switch to
- [x] Weather visuals: rain, snow and wind particles, wet surfaces, ambience layers (WP-13)

Exit criteria:
- [x] Captures of clear, rain and storm that are visibly different, and wet surfaces that
      appear and dry out — done 2026-08-26, seven windowed captures at 13:00 with the clock
      and the weather both frozen: clear, rain, storm, snow, a soak-to-dry triptych at
      wetness 1.0 / 0.5 / 0.0, and a storm seen from inside the Lantern Hall with not one
      drop indoors
- [x] Cross between areas twenty times with no leak in node count or memory — done 2026-08-26,
      `--round-trips=20`: node count exactly flat at 120 across all twenty, memory -12 KiB
- [x] Trigger two transitions in the same frame and be refused cleanly, with a log line —
      done 2026-08-26, exercised forty times in the same run, two per trip
- [x] An NPC is at the market at noon and at home at night, across a save and reload — done
      2026-08-26. `--npc-day` walks the clock through a whole day: gate_post at 06:00 and
      09:00, the dais at 12:00 and 15:00, the bench from 20:00 through 02:00. Whereabouts
      persist through `PersistentState`, asserted in the suite. Two captures examined
- [x] Hold a conversation that reads and sets a flag, and branches on it — done 2026-08-26,
      covered by the test suite, plus a windowed capture and a real-input probe that pressed
      the button, advanced a line and took a branch with the world still running
- [x] Switch language at runtime and see every visible string change — done 2026-09-04
      (T5.1). It was unmet for a reason no amount of wiring would have fixed: the CSV had
      ONE locale column, so there was nothing to switch TO, and `settings_screen.gd`
      cycled a locale, stored it, and nothing ever read it back — `TranslationServer` was
      never told. `Settings._apply_locale` now applies it, on `_apply_display`'s stated
      reasoning rather than by analogy: nothing else owns `TranslationServer` either.
      `tools/gen_pseudolocale.gd` generates an `en_XA` column so a second language exists
      without the template pretending to ship a translation — the same argument that
      generates placeholder ART. Two captures of the satchel at 12:00, differing only in
      that setting, were READ: `Satchel / Key Items / Rose Key x1` against
      `[~~Satchel~~] / [~~Key Items~~] / [~~[~~Rose Key~~] x1~~]`, the item row
      double-wrapped because the row format AND the name both come from the table.

## Phases 3 and 4 — RETIRED, out of scope

They used to read *"thirty minutes that represent the finished game"* and *"regions, quest lines,
the full plot"*. Under the reframing in [`TEMPLATE.md`](TEMPLATE.md) those are not deferred work,
they are **a consuming game's phases**. A criterion like *"a new player finishes the slice with no
guidance and no soft-lock"* is one no template can meet, and leaving it here would keep pointing
effort at polishing the demo.

What follows replaces them.

---

## Phase T1 — Make it a base, not a demo · **COMPLETE**

*Goal: the demo can be deleted and the template still stands up.*

| Step | State |
|---|---|
| **T1.1 Integration** — every package onto `main` in one linear chain | **DONE** 2026-08-26, PR #10. WP-12 and WP-13 were built in parallel and merged in; the `UiRoot`/`ScreenKeys` duplicate close-on-travel was resolved in favour of `ScreenKeys`. |
| **T1.2 The boundary** — the rule, a gate that enforces it, and the leaks fixed | **DONE** 2026-08-26, commit `06ce363`. `tools/check_boundary.gd` derives the demo ids from `scenes/areas/` and `data/` and fails on any of them in `src/` code. All four known leaks closed. |
| **T1.3 Test fixtures + framework hardening** | **DONE** 2026-08-26, commit `a8377a0`. `tests/framework/fixtures.gd` and `fixture_content.gd` build the content a case needs; the three content registries gained a redirectable `content_dir`. Four silent-pass modes now fail: a crash, an early return, a case that asserts nothing, and a suite file nobody listed. `check_boundary` now scans `tests/` too. |
| **T1.4 CI** — automate the ladder | **DONE** 2026-08-26. `.github/workflows/ladder.yml` runs six of the seven rungs on every push, pull request and manual dispatch, in two jobs: the full checkout and a stripped template. The engine is downloaded, its SHA512 verified against a pinned literal and its build string asserted before any rung runs. Proved red then green. |

Exit criteria:
- [x] `main` contains the template — done 2026-08-26
- [x] A gate fails on a planted `&"courtyard"` in a `src/` file, and passes otherwise — done
      2026-08-26, and it is `tools/check_boundary.gd`, not `check_content.gd`: the combined file
      came out at 252 of the 250 allowed code lines and the budget checker refused it
- [x] No file under `src/` names demo content — done 2026-08-26. One exemption,
      `src/systems/debug/`, justified in the tool header and conditional on those files staying
      behind `OS.is_debug_build()`, which the same tool now checks
- [x] The debug surface cannot be driven in a release build — done 2026-08-26
- [x] `docs/NEW_GAME.md` exists, and its claims were run against a stripped copy of the repo
- [x] A deliberately crashing test case exits **1** — done 2026-08-26, T1.3, and it took TWO
      mechanisms because the obvious one is not enough. A GDScript runtime error aborts only the
      innermost frame (probed), so the declared plan catches a crash that swallows an assertion
      but a planted crash in a leaf helper still reported `2/2` and exit 0. `ErrorWatch`, an
      `OS.add_logger` Logger counting `ERROR_TYPE_SCRIPT`, catches that one: `zz_probe_test raised
      1 engine script error(s)`, exit 1. A failing assertion, an early return and a missing plan
      were each planted and each exited 1 as well
- [x] `data/` and `scenes/areas/` moved aside, and the suite still passes — done 2026-08-26,
      T1.3: `861 passed, 0 failed, 12 skipped`, exit 0, with every skip named and counted. Full
      checkout: `911 passed, 0 failed, 0 skipped`. Restored, and `git status` showed no change to
      any demo file
- [x] A pushed branch with a broken assertion goes red in CI — done 2026-08-26, T1.4. One
      assertion in `core_test.gd` changed to expect 6 where the answer is 5; run
      [32989608134](https://github.com/Raiyan-Bashar-29/HD-2D-game-base-non-combat-/actions/runs/32989608134)
      failed at `Rung 4 - test suite` in BOTH jobs, printing `FAILED: dict_read int — expected 6,
      got 5` and `910 passed, 1 failed`; rungs 5-7 were skipped. Restored, and run
      [32989771404](https://github.com/Raiyan-Bashar-29/HD-2D-game-base-non-combat-/actions/runs/32989771404)
      went green: `911 passed, 0 failed, 0 skipped` full, `861 passed, 0 failed, 12 skipped`
      stripped

## Phase T2 — Make it swappable · **COMPLETE, as of T2.2**

*Goal: a second, visually different game starts from this without editing `src/`.*

- **T2.0 The export proof — DONE, 2026-08-26.** Sequenced FIRST in Phase T2 by RISK, not by theme
  — it belongs to T3 by subject. A Windows preset, and the first run of an exported build there
  has ever been. **The assumption held:** `export_filter="all_resources"` ships resources that no
  scene references, and the exported `.exe` reports the same 3 items, 1 conversation and 1
  schedule the editor does. ADR-0006's honest limit is closed and needed no revision. The proof
  was not wasted, though: running the export found a SECOND defect that every rung, both CI jobs
  and 930 assertions were blind to — a missing `[editable]` marker dropped an instance's property
  overrides in the binary conversion only, so the demo's NPC shipped with no id, no prompt and no
  conversation. Fixed, and now a `check_content` gate. See the board.
- **T2.1 The art contract — DONE, 2026-08-27.** The first four items of the list below, which are
  the two exit criteria and their supports; the last five were left, in the order they are
  written, because the package hit its file budget and half-doing five seams is worse than
  finishing two. A `SpriteSheetLayout` resource replacing `FACING_COUNT`/`FRAME_COUNT`, with the
  sector width DERIVED from the facing count instead of a separate literal `TAU / 8.0`, and
  animation blocks with idle/walk row offsets so idle-vs-walk is no longer structurally
  impossible; a project `Theme` at `assets/theme/ui_theme.tres` so the UI look stops living as
  constants inside five screen files. It left five items, which were **closed by T3.2 in Phase
  T3** — four built, one refused in writing. See the board.
- **T2.2 Consumer documentation — DONE, 2026-08-27.** `AUTHORING.md`, `ART_CONTRACT.md`,
  `TESTING.md`, the extension surface as a section of `ARCHITECTURE.md`, and both routers
  updated so the new documents are reachable. (`NEW_GAME.md` was already done in T1.2.) The last
  criterion below was **performed rather than asserted**: a new area, a new NPC and a new
  conversation were authored from the documents alone, run, captured and looked at, six doc
  defects were found and fixed, and the content was then deleted — it was a test of the docs,
  not new demo content. `tests/unit/docs_test.gd` now fails on a documented `res://` path or
  worked-example field that no longer exists. See the board.

Exit criteria:
- [x] An exported build reports **non-zero** catalogue counts for items, conversations and
      schedules, matching the editor — T2.0, **2026-08-26**. Ran the exported `.exe` outside the
      editor: `items: 3, dialogue: 1, schedules: 1`, resolved paths identical to a source run.
      Moved here from Phase T3, where it was listed while `SYSTEMS_INVENTORY.md` simultaneously
      marked export presets LATER; that contradiction was settled 2026-08-26 in favour of blocking
- [x] Swap in a sprite sheet with a different cell and frame count, changing **no code** — T2.1,
      **2026-08-27**. `character_alt.png`, 4 facings x 3 frames x 2 animation blocks on a 24x40
      cell against the default 8 x 4 on 32x48. Two `ExtResource` paths in `player.tscn` changed
      and nothing else. Windowed capture LOOKED AT: the probe logged `frame=19/24`, and the
      picture showed the walk block's tint, four column pips and two frame pips — block 1,
      frame 1, column 3, which is exactly index 19
- [x] One `Theme` change restyles every screen at once — T2.1, **2026-08-27**. Six lines of
      `assets/theme/ui_theme.tres` and no other file: the main menu and the inventory screen both
      went from dark-on-translucent-black to dark-on-parchment with a deep-red accent and a wider
      inset, and the HUD clock followed. Captures before and after, both looked at
- [x] And a row DRAWS as one — T5.15, **2026-09-06**. T2.1 left the theme setting nine
      `font_sizes` and no `Button/styles/*`, so the restyle above changed everything on a menu
      except the menu rows themselves. `UiRowStyles` derives all five states from the palette at
      boot, and the derivation is directional, so the same expression is right on a dark palette
      and on a light one. Photographed on both
- [x] Someone who has not read `src/` can author an area, an NPC and a conversation from the docs
      — T2.2, **2026-08-27**. Performed, not claimed: an area, an NPC with a schedule and a
      four-node conversation were written from `AUTHORING.md` alone, with no reference to `src/`
      and nothing copied from an existing area. All seven ladder rungs green with the new content
      in (`1101 passed`), `check_content` clean including the `[editable]` marker, and the capture
      shows the NPC in the new area saying its first-meeting line. **The evidence is the six
      places the docs were wrong**, all fixed and listed in `DEVLOG.md` — the largest being that
      the documented capture command never leaves the main menu, so an author following it
      photographs the title screen and concludes their area is broken. A walkthrough that worked
      first time would have meant the author was still reading from memory

## Phase T3 — Finish the system catalogue · **COMPLETE, 2026-09-02**

Nine packages: WP-08, WP-09, WP-11, WP-09b, T3.1, T3.3, T3.2, WP-14 and WP-14b, the last of which
closed the phase's one exit criterion. WP-10 (crafting) is OPTIONAL and blocks nothing; WP-15's
remnant is a decision awaiting the owner rather than work in this phase.

The packages, re-framed — see the board. **The export proof moved OUT of this phase and
into T2.0**, at the front of Phase T2: it was always described here as "the one genuinely blocking
item", and a blocking item scheduled last is a contradiction. Sequenced by risk, not by theme.

- **WP-08 Quests — DONE, 2026-08-27.** The phase's first package, and the widest remaining hole:
  quests were the one system with no proof at all. A quest is now authored data in `data/quests/`,
  found by the fourth directory-scan registry, and **every step names a FLAG CONDITION rather than
  a callback** — so a conversation that writes a flag starts a quest, a lever advances it and a
  trigger volume finishes it, with none of the three knowing the quest system exists. `QuestTracker`
  derives progress from `Flags` and latches only the two things that cannot be derived (that a quest
  started, and that it completed). A `JournalScreen` on `J`, one placeholder quest, and 49 new
  assertions. See the board.

- **WP-09 Character depth — PARTIAL, and deliberately: EQUIPMENT DONE, 2026-08-27.** The row asked
  for three systems in one package — an attribute container, surface-aware footsteps and equipment
  that changes traversal — which is over the board's own 8-file limit, so it was split and the half
  with a consumer was built. An `ItemDefinition` gains one field, `equip_slot`, and `Equipment` is a
  component beside `Inventory` that **owns no dictionary**: a slot is the flag
  `equip/<wearer>/<item>`, so a `Gate`, a `QuestStep` and a `DialogueChoice` all gate on what is in
  hand with **no code and no new field in any of them**. Enter on a satchel row holds or stows.
  The other two thirds are **WP-09b** on the board, with the reason each was deferred.

- **WP-11 World map and fast travel — DONE, 2026-08-29.** The phase's third package, and the last
  system in the catalogue with no proof at all. An `AreaDef` .tres per area in `data/areas/`,
  found by the fifth directory-scan registry, carries the map position, the arrival spawn and
  `known_from_start` — and **discovery is the flag `map/<area id>` with no store behind it**, the
  fourth use of the namespace-over-`Flags` shape after `PersistentState`, `Standing` and
  `Equipment`. So discovery is already saved, already cleared by a new game, already announced on
  `flag_changed`, and writable by a conversation effect, a lever or a trigger volume with **no
  code in any of them**. `WorldMap` under `GameRoot` turns arrival into discovery and emits the
  same `area_change_requested` an `AreaDoor` emits; `MapScreen` on `M` draws one dot per def at
  its authored normalised position and names no area. Three windowed captures LOOKED AT and READ,
  and 65 new assertions. See the board.

- **WP-09b Character depth — DONE, 2026-08-29.** The phase's fourth package, and the two thirds of
  WP-09 that were split out for having no consumer. Both were built to have one. An attribute is
  the flag `attr/<who>/<name>` — the FIFTH namespace-over-`Flags` — and it ships with exactly one
  reader, `PlayerController.current_speed()`, with the attribute's NAME declared as a const on that
  consumer so an attribute nobody reads has nowhere to be written down. A surface is
  `metadata/surface` on area geometry, inherited from the nearest tagged ancestor, and a step's
  sound is DERIVED FROM THE SURFACE'S NAME rather than looked up in a table, so a game that authors
  `sand` hears it without editing `src/`. 56 new assertions cover the three pure parts; the
  raycast, the frame loop and the `play()` are a windowed probe with the log quoted. See the board.

- **T3.1 A generic content registry — DONE, 2026-08-30.** The phase's fifth package, and the one
  row that was a pure refactor: five catalogues carried five copies of the same scan-and-validate.
  WP-08 costed the refactor at the fourth copy and kept the copy for a sound reason — a base
  holding the CACHE could only hand back untyped `Resource`s — and WP-11 changed only the
  arithmetic. **Both were right about the wrong half.** The duplication was in the SCAN, which
  needs exactly two things from a resource: its `id` and its `problems()`. So the base went on the
  **resource** (`ContentEntry`) and the shared part is a **function**, `ContentScan.into()`, that
  fills the caller's own typed dictionary — every registry keeps its `content_dir`, its typed
  cache and its typed accessor, and **there is no cast at any call site in the project.** Five
  registries: 290 code lines to 187, plus 44 shared, so 290 against 231; the scan-and-validate
  body exists once instead of five times. `ItemDb.resource_paths()` became
  `ContentScan.resource_paths()` with no alias, since four registries and three test cases were
  calling the item registry to scan things that are not items. 47 new assertions, all of which run
  in a stripped template, and **not one word of `AUTHORING.md` had to change** — which was the
  acceptance test. New gotcha 37: a base-class `static var` is ONE storage shared by every
  subclass, measured, which is why a shared base CLASS would have given all five catalogues one
  cache. See the board.

- **T3.3 A quest step that can read an ITEM COUNT — DONE, 2026-08-31.** The phase's sixth package,
  and the one row on the board that was breadth of EXPRESSION: "bring me three petals" was not
  authorable, which is a limit on what a consuming game can say. WP-09 had costed both candidate
  designs and closed neither, and the one taken is its first with the cost that made it look
  expensive removed. `Inventory` PUBLISHES each count as `bag/<carrier_id>/<item id>` in `Flags` —
  the SIXTH namespace-over-`Flags` — so **the dependency points DOWN from `gameplay` to `core`
  instead of up from `systems` to `gameplay`**, and the quest system was not touched: no field on
  `QuestStep`, no line in `QuestTracker` that knows what an inventory is, and a test now FAILS if
  either learns. The mirror is a PROJECTION and not a second truth: `Flags.declare_derived` keeps
  it out of the save file, so nothing is saved twice, `Inventory.SAVE_VERSION` did not move and
  there is no migration. Two things fell out that were already decided and only needed asserting:
  a count already satisfied passes the step at once, and a count going back down reopens an
  ACTIVE objective while a COMPLETED quest stays complete — the case `quest_tracker.gd`'s own
  header names. 66 new assertions, three new `check_content` branches each proved red then green,
  and two windowed captures LOOKED AT and READ. See the board.

- **T3.2 The five art-contract seams T2.1 left — DONE, 2026-09-01.** The phase's seventh package,
  and the LAST of its T-numbered rows — but Phase T3 was not closed by it and this file should not
  be read as saying so: WP-14 was still TODO, WP-15 has a remnant, and the exit criterion below is
  about systems having a proof rather than about T-rows being finished. *(The phase closed two
  packages later, with WP-14b on 2026-09-02.)* T2.1 shipped the sprite-sheet contract and the project `Theme` and
  left five items, which then spent six packages being described in **five documents** — a backlog
  item mentioned five times is tracked zero times and described five times, and the descriptions
  drift. Four are now built and one is refused in writing, and every one of them is stated in
  exactly one place, `ART_CONTRACT.md`. **Shared materials:** `assets/materials/wood.tres`, one
  file both areas point at, and the defect was already there — the two demo areas each carried a
  byte-identical `m_wood`. A library of ONE, because the other five materials are *not* duplicates
  (a tiling rate belongs to the surface, not the substance) and a shared file with a per-area
  override on every user is duplication with an extra indirection. **The environment post stack:**
  twenty literals in `_build_post_stack()` became twenty `@export`s at exactly the values T2.1
  shipped; what stays in code is the STRUCTURE the rest of the driver assumes, and the four
  expensive effects are exports despite being `false` because a value a game cannot reach is not a
  seam, it is an opinion. **Per-area camera framing:** the seam already existed and the row was
  wrong about it — `HD2DCameraRig` has carried its framing as `@export`s since it was written, and
  what was missing was an area USING them, so the interior now frames at 36° / 9.5 m against the
  outdoor 27° / 14 m and one run logs both. **The texture import defaults:** gotcha 30 said this
  could not be done, because `[importer_defaults]` is undocumented and absent from `--doctool`.
  The rule was right and the conclusion was not — it was settled by MEASUREMENT instead, which is
  non-negotiable #1: a throwaway texture, the section added, its `.import` deleted, and
  `--headless --import` regenerated it carrying the values. One value is set,
  `detect_3d/compress_to = 0`, which closes the latent hazard that a re-import would put VRAM
  block artefacts through pixel art. **Git LFS is refused**, with the reason that decides it
  written down for the first time: the template cannot verify the change it would be making.
  47 new assertions, six gates each proved red with the real violation then green — one of which
  exposed a defect in the test itself — and six windowed captures LOOKED AT and READ. See the
  board.

- **WP-14 Dev tools and hardening — DONE as the HARDENING half, 2026-09-01.** The phase's eighth
  package, and the first row to be both RE-FRAMED and SPLIT in the commit that took it. The row
  asked for "a smoke test that drives **the whole demo**", which would have welded the courtyard,
  the keeper and the rose key into a permanent ladder gate — the coupling `check_boundary` exists to
  prevent, arriving through the back door of a test, and the welding T1.3 spent a package undoing.
  `smoke_test.gd` drives *a* game from `tests/framework/fixtures.gd`, names no content, and skips
  its one game-shaped block, counted, in a stripped checkout; and because `TestCase.run()` is
  synchronous it is the CHAIN rather than a playthrough — a run begins, a flag starts a quest, items
  publish their counts, an objective notices, something goes in hand, time skips, and the session is
  saved, wiped and restored. The row also named four things, over the size limit, so its own title
  was the seam: the two gates shipped and the two UI surfaces became **WP-14b**. **`Director` now
  drains its loader thread on shutdown**, and the interesting part is what the defect had been
  costing: quitting mid-load printed `Parse Error` for files that parse perfectly, so CI's boot rung
  had been written to read only its last line, with a comment saying a whole-log grep "would be a
  flake generator" — a live defect had bought itself a hole in the project's own compile check. No
  `load_threaded_cancel` exists in 4.7, so the fix waits, measured at 118-197ms, and **rung 3 now
  greps the whole log**. Gotcha 13's stated reason for the boot timeout turned out to be stale
  rather than merely incomplete (gotcha 31: a plain boot enters no area), and 30 frames was measured
  to produce a byte-identical log to 120. **A fourth checker, `check_strings.gd`**, is the
  hard-coded-string audit — deliberately not the literal-classifier `check_content.gd` refused in
  writing, but a **sink** rule and a **declaration** rule, because whatever reaches `.text` is
  player-facing by construction. Its second half closed a hole that was measurably live: with one
  transposed character planted in a toast key, `check_content`, `check_boundary` and all **1,517
  assertions passed**. 26 new assertions, three gates proved red with the real violation then green
  — **and one of those plants exposed a defect in the new test rather than in the code** (gotcha 42),
  a comment claiming an assertion covered save-participant order when the assertion stayed green
  with the invariant deleted. See the board.

Exit criteria:
- [x] Every system has one proof, and no system has a second area's worth of content
      — quests: **done**, WP-08, 2026-08-27. One quest, two steps, two windowed captures LOOKED AT:
      the journal with the objective open, and the same quest under "Settled" with its toast up
      — equipment: **done**, WP-09, 2026-08-27. One equippable item, one gate requiring it, three
      windowed captures LOOKED AT and READ rather than glanced at: the satchel with
      `Brass Lantern x1 [in hand]` beside an unmarked `Rose Petal x2`, the arch refusing with its
      own authored line, and the same arch with the blocker gone one flag later
      — attributes and surface-aware footsteps: **done**, WP-09b, 2026-08-29. An attribute that
      changes something and persists, proved windowed at 2.861 m against 4.687 m over the same 60
      frames with `pace` 0 and +4; the surface under the player reported correctly on THREE
      materials, two tagged directly and one inherited from the terrain root, and the step sound
      following it — `brightness=0.733 decay=2.13`, `0.841/4.68`, `0.550/3.02`, `playing=true` on
      a WASAPI device. Not visual and not synchronous, so the claim is a quoted log rather than a
      capture, and the file headers say which half is which
      — world map and fast travel: **done**, WP-11, 2026-08-29. Two areas on one map, three windowed
      captures LOOKED AT and READ: a map with the second area drawn as an unknown grey `???`, the
      same map one flag later with it drawn as a gold selectable `Lantern Hall`, and the same map
      again after actually travelling there -- the two states swapped, with the courtyard still on
      the map from the far side of an area no longer loaded
      — an item count in a quest step: **done**, T3.3, 2026-08-31. One counted step on the
      existing placeholder quest, two windowed captures LOOKED AT and READ rather than glanced at
      (gotcha 28): the journal reading `Underway - The Keeper's Errand - Gather three rose
      petals.  2 / 3` after `--give=item/rose_petal:2`, and the same screen at the same hour with
      one petal more reading `Settled - Nothing left to do.` The tally is a checkable prediction
      rather than a screenshot that merely looks fine
      — the look of an area as data: **done**, T3.2, 2026-09-01. Three seams, each demonstrated by
      a before/after pair from the same camera and hour in which ONE edit to ONE file is the only
      difference, all six LOOKED AT and READ (gotcha 28): one shared material tinted in
      `assets/materials/wood.tres` turns the dais in one area and the plinth in the other magenta
      together; `volumetric_fog_density = 0.06` on one area's driver node hazes that area alone;
      and the interior's own `fov = 36.0, distance = 9.5` draws the player at roughly 130 px
      against 78 at the same hour, with one run logging both rigs
      — dev tools: **done**, WP-14b, 2026-09-02. A debug console on F1 and a performance overlay
      on F3, three windowed captures LOOKED AT and READ. The console capture is a checkable
      prediction rather than a screenshot that looks fine: the run was launched at
      `--time=12:00 --freeze-time`, the console was handed `time 18:40`, and the HUD reads
      `Day 1 | 18:40 | Dusk` over a dusk-lit courtyard — readout and lighting agreeing. The
      overlay's own criterion is a frame time that visibly moves, measured across a load spike at
      35.71 ms / 28 fps and then 16.70 ms / 54 fps

**THIS CRITERION IS NOW TICKED**, and it was held open through T3.2 and WP-14 on purpose: it is
about every system having one proof, and the last two systems with none were the two dev tools.

- **WP-14b Dev tools — DONE, 2026-09-02.** The phase's NINTH package, the half WP-14 split off,
  and the row that CLOSES Phase T3. The console lives under `src/ui/` — settled rather than
  assumed, and settled on the stronger argument: it names no content, so putting it in the exempt
  debug directory would have bought it an exemption it does not need and switched off the gate
  that should be watching it. The four verbs became ONE implementation in
  `src/systems/debug/dev_commands.gd` that both argument parsers and the console call, so what you
  type in the console is exactly what you pass on the command line — and that extraction is also
  what made room for a sixth staging flag in `dev_stage.gd`, which was sitting at **exactly 250 of
  its 250 allowed code lines**. The console is a `UiScreen` declaring `pauses_world` and the
  overlay is a `CanvasLayer` that never enters the stack, which is one decision made twice from
  the same question. **Absence from a release export is MEASURED with a control** rather than
  assumed: a debug export logs both armed lines and a release export logs neither. 30 new
  assertions, seven plants each proved red with the real violation — **and the first version of
  the gate assertion was wrong twice over** (it read its own explaining comment, and the overlay
  carried the anchor fragment twice), which is gotcha 42 arriving on schedule and being caught
  only because the violation was planted. See the board.

## Phase T4 — Template v1.0 · **COMPLETE**

**Phase T3 closed with WP-14b, 2026-09-02.** WP-15's remnant — credits and an accessibility pass —
was **CLOSED by the owner** on the same day rather than built: both belong to a consuming game,
and the seams that make accessibility possible already exist and are proved. WP-10 (crafting) is
OPTIONAL and blocks nothing. The board carries the full reasoning.

- **T4.1 The version and the upgrade note — DONE, 2026-09-02** — `799d957`, PR #25. The phase's first package, and
  both of the things this phase was named for.

  **The version is `[template] base/version`, not `application/config/version`**, and that choice
  is the package: `NEW_GAME.md` § 4 tells a fork to reset its own version to `0.0.1` on day one,
  so after one fork that field no longer records which base the game came from. It is read through
  `src/core/util/template_version.gd` and printed in every boot banner as `base <version>`, which
  is what makes a bug report from a forked game answerable.

  **`docs/UPGRADING.md` was PERFORMED against a real stripped fork**, to `NEW_GAME.md`'s standard
  rather than written from intent: a fork made, two template releases landed on the base, both
  merged in, and the fork's whole ladder run afterwards. It found four things design would not
  have — that `project.godot` auto-merges, that `localization/strings.csv` conflicts every time in
  the same trivially-resolvable way, that **a merge pushes the template's own demo content back
  into a fork with no conflict and therefore no warning**, and a genuine template defect: a test
  block gated on "any content" while asserting about "any area", so a game that authored an item
  before its first area had a red rung 4 in exactly the window `NEW_GAME.md` walks it through.
  Fixed, planted and proved. `docs/CHANGELOG.md` is the version-to-version discipline and its
  newest heading is asserted equal to the setting.

  **What the template CANNOT promise is written down** — no clean merge, no content compatibility
  across a MAJOR, no save survival, nothing at all for a fork that edited `src/`, and no automatic
  upgrade, ever. See the board.
- **T4.2 A second worked example, authored from `AUTHORING.md` alone — DONE, 2026-09-02.** T2.2's
  mechanism applied to CONTENT: an orchard, a warden, a schedule, a conversation, two items, an
  equip-gated arch, a map def and a counted quest, all authored from the document alone with
  `src/` never opened — then deleted, because it was a test of the documents. **Five defects, and
  two were in the template rather than the prose:** `check_boundary` matched SUBSTRINGS, so an
  item called `pear` failed on the word `appeared` and the gate table told the author to blame
  the engine; and `--stand-by` always resolved in the DEPARTURE area, so no object in an authored
  area could be photographed at all. Both are gotcha 44's shape — invisible to both of this
  repository's states. Six more sections were performed and now hold proofs rather than claims.

- **T4.3 `NEW_GAME.md` performed, and the release tag taken — DONE, 2026-09-03.** The phase's
  last package. **The stack landed first:** all 26 PRs were still open and `origin/main` was at
  `d0bf153`, but every branch was an ancestor of T4.2's tip, so retargeting #26 to `main` merged
  the lot as one 71-commit chain and made `v1.0.0` an honest tag rather than the dishonest one
  refused the day before.

  **Then the fourth document was performed**, and like the three before it, it found what reading
  could not. A fresh clone was forked, stripped and renamed from `NEW_GAME.md` alone. **Two
  defects, one of them the template:** `core_test.gd` asserted `[game] world/first_area != ""`
  UNCONDITIONALLY, contradicting its own case name, the comment eight lines below it and
  `NEW_GAME.md` § 4 — so a fork that did exactly what the document says had a red rung 4 before
  it authored its first area, while the document promised the ladder stays green. Green in both
  of this repository's states, because neither ever empties that field. The claim moved to
  `smoke_test.gd`, which already made it correctly and more strongly; the control — areas present
  with the field still empty — was planted and is still red.

  **And § 3's prune list never learned about quests.** Written before WP-08, it omitted `quest.`,
  so a fork shipped the demo's `quest.keepers_errand.*` rows — "The Keeper's Errand", "three rose
  petals" — inside its own game, with all four checkers and the whole suite green, because **no
  gate reads `localization/` for demo content at all.** That is now stated in the document as its
  own trap, with a grep to run after pruning. Three further prose defects were re-measured rather
  than inherited, including a `--new-game` invocation that is silently green without a `--`.

- **T4.4 `TESTING.md` performed, the last document never walked — DONE, 2026-09-04.** After the
  phase's exit criteria were already met, so it adds none: the phase closed with T4.3 and this
  package neither reopens it nor is required by it. What it settles is the *last* of the five
  consumer documents, and **five for five now — every document performed has found a defect no
  amount of reading would have, and three of the five were defects in the TEMPLATE.**

  **The template defect is the sharpest of the three, because it invalidated the rung that judges
  every other one.** The suite SKIPPED A LISTED CASE THAT DID NOT PARSE, in silence, at exit 0.
  `load()` on a script with a parse error returns a `GDScript` that is not `null` and cannot be
  instantiated, so `_run_case` walked into `script.new()` — and gotcha 24 already established that
  a GDScript runtime error aborts only the innermost frame, so the failure two lines below was
  never reached and the loop moved on. Measured: `=== 1608 passed, 0 failed, 0 skipped ===` and
  exit 0, a last line byte-identical to a checkout in which the file does not exist. T1.3 built
  two mechanisms here because the first was measured and found wanting; this was the third hole in
  the same wall, and the one neither was positioned to see — `error_watch.gd` had counted the error
  the whole time and nothing ever asked it. Two guards close it, and the second closes the class.

  **The document's one worked example did not compile**, and was wrong twice over — nothing
  declares `inventory`, and `Inventory` has no `count()`. Copying it verbatim is what began the
  package, which is a fair summary of why documents get performed rather than proofread.

  **And three documents gave three different answers to a countable question:** 44,
  48 and 43, over a list of 48 gotchas. `doc_counts_test.gd` counts the
  entries and requires every document that states the number to state that one — gotcha 48's shape
  without gotcha 48's excuse, since a count needs no list of exceptions behind it.

  One assertion was KEPT rather than deleted with the throwaway: `bag_mirror_test.gd`, on the
  ordering between the count-flag publish and `item_gained` / `item_lost`, which `Inventory.add`
  documents in a comment and which nothing tested on either path.

**Exit criteria for the phase:**

- [x] The template states its own version, readably at runtime and assertably. — T4.1
- [x] A game already forked from this base has a documented, PERFORMED way to receive a later fix.
      — T4.1
- [x] A release tag on the repository. Deliberately not taken by T4.1: a tag is a release action
      and releases are the owner's. **Taken 2026-09-03**, once the whole PR stack had landed —
      `v1.0.0` on `648bac1`, the merge commit that brought WP-01 through T4.2 onto `main` in one
      linear chain of 71 commits. It was refused on 2026-09-02 for a reason that had not yet
      expired: `origin/main` was still at `d0bf153`, so a tag then would have named either a
      commit lacking the version it claimed or an unmerged branch.

---


## Phase T5 — The base as a reusable CHARACTER kit · **COMPLETE, 2026-09-09**

*Goal: a future game inherits working characters and changes only assets. Several idle formats and
several movement styles, so that swapping a sprite sheet makes a character feel different without
touching code.*

**Why this phase exists, and why it is not scope creep.** Phases 0 to T4 answered "does the base
have a home for every system a game needs". This one answers a narrower and more practical
question the owner put on 2026-09-04: *when we make the actual game, what do we get for free?* The
answer had better be "the characters move, animate and feel distinct from their art alone",
because that is the part a new game otherwise rebuilds blind. It is a phase rather than a package
because the first row exposed how much of it was declared and unread.

- **T5.1 The skeleton's four open exit criteria — DONE, 2026-09-04.** Not part of this phase's
  goal, but it is what revealed the gap: proving criteria rather than ticking them found the
  locale setting wired to nothing, and reading the roadmap honestly is what prompted the question
  this phase answers. See Phase 1 and Phase 2, now fully ticked.

- **T5.2 An animation block per GAIT — DONE, 2026-09-04.** `SpriteSheetLayout.animation_for` took
  a **boolean**, so a sheet could hold an idle cycle and a walk cycle and nothing else: run and
  sneak replayed the walk block faster. Meanwhile `GameEnums.MoveState` had ten values and
  `Events.player_state_changed` was declared, emitted and **listened to by nothing** — the sixth
  time this project has found something validated and unread. It now takes a `MoveState`, and
  `run_row` / `sneak_row` / `climb_row` default to `-1` meaning "replay the walk block", so every
  sheet authored before it behaves identically and a game adds a run cycle by drawing one. Proved
  by 19 assertions, a live probe reading the real `sprite.frame`, and three captures in which the
  player walks in green and runs in rust while the NPC beside them stands in blue — same sheet,
  same frame, different blocks.

- **T5.3 Delivering the gaits that were already declared — DONE, 2026-09-04.** An audit of the
  whole base went looking for more of this project's characteristic defect and found the
  **seventh instance, created by T5.2 two rows above.** `MoveState.CLIMB` never reached
  `CharacterVisual` at all: `_physics_process` returns early while a climb owns the body, and
  `climb_step` touched the visual only after resetting the state to IDLE — so across all three
  callers of `update_from_velocity` nothing could ever pass CLIMB, and `climb_row` was exported,
  defaulted, range-limited, validated by `problems()` and asserted by `art_contract_test.gd`
  while being **impossible to draw**. Invisible in the demo because the shipped sheet leaves
  `climb_row` at -1, so the fallback drew the walk block and looked right; the first person to
  see it would have been the first game that drew a climb cycle. **Both ends were asserted and
  the wire was not** — `traversal_test` proved the body reports CLIMB, `art_contract_test`
  proved the layout maps it, and nothing proved it arrived. Second defect in the same function:
  `update_from_velocity` pinned `_frame = 0` whenever horizontal speed was zero, so **no idle
  block had ever advanced a single cell** — three of the shipped sheet's four idle cells were
  undrawable, while "more than one idle" sat on the exit criteria below. Fixed: a climb counts
  as moving without turning the character, and an idle block that DIFFERS from the walk block
  advances at a new `idle_fps` (a sheet whose idle *is* its walk block still holds cell 0, which
  is the pre-T2.1 case and would otherwise walk on the spot). Proved by 18 new assertions and by
  planting the revert: the fix removed, the suite is `1688 passed, 6 failed`, exit 1, naming
  `a climb draws the climb block — expected 1, got 0`; restored, `1694 passed, 0 failed`, exit 0.
- **T5.4 The three missing enforcement gates — DONE, 2026-09-05.** Not a character row, and it is
  here because the T5.3 audit that produced it found the structural cause of seven packages'
  worth of the same defect: **no gate anywhere asked whether a declared thing has a CONSUMER.**
  Three gates close it. `tools/check_signals.gd` requires every signal in the registry to have an
  emitter, resolving indirect `Signal`-value dispatch so the three quest signals — which have
  **zero** direct `.emit` sites — are not false positives; it named `debug_command` on its first
  run. `tools/check_layers.gd` enforces `core -> content -> systems -> gameplay -> ui`, the one
  architectural rule with no gate, and **found a real violation immediately: 55 upward
  references**, of which 13 were the interaction sensor sitting in `systems/` while typed on
  `Interactable`. Moved to `src/gameplay/interaction/`; gotcha 55. `check_boundary.gd` gained the
  `localization/` half, closing gotcha 48: an orphan CSV row fails, presence is reported, and the
  stripped CI job now runs `NEW_GAME.md`'s prune `awk` before it, which checks the prune list
  itself. Each gate proved red by planting a real violation and green by removing it — exit codes
  in `DEVLOG.md`. Ladder: four checkers to six, rungs 9 and 10 in CI as their own steps. 1,728
  assertions.

- **T5.5 The twelve settings with no consumer — DONE, 2026-09-05.** Also not a character row,
  and the last of the T5.3 audit's structural findings. **Twelve of twenty-three settings were
  declared, drawn to the player, translated in both languages, and inert.** Nine got a real
  consumer, placed by who OWNS the thing that has to change: the viewport and the shadow atlas to
  `Settings` itself, bloom to `EnvironmentDriver` because the Environment is that node's, DOF to
  `HD2DCameraRig` — `set_dof_enabled()`'s first ever caller — the prompt's two to `InteractPrompt`,
  the typewriter's to `DialogueScreen`, the hold floor to `InteractionSensor`, and
  `accessibility/text_scale` to a new `UiAccessibility` under `UILayer`. **`video/shadows` is the
  placement worth reading**: shadows are cast by lights an AREA AUTHOR placed, no node owns the
  set of them, so it is applied at the shadow ATLAS and a game that adds a hundred lights gets it
  free. **Three were REMOVED** — screen shake, autosave and subtitles have no machinery in this
  template to reach, and a row drawn to the player that cannot do anything is worse than a dead
  constant. **Five of the twelve were a TEMPLATE defect and not a missing game feature**: a fork
  could not honour `accessibility/*` without editing `src/`, because the thing that changes is the
  theme every screen in `src/ui/` draws from. Plus the audit's four one-liners:
  `reset_to_defaults()` never re-applied the locale, `Actions.JUMP` is gone entirely, and
  `rebind()` gates on `Actions.REBINDABLE`. **The seventh gate was deliberately NOT built** — the
  consumer question is an ASSERTION, because `Settings.DEFAULTS` is a runtime fact and a `check_*`
  tool would have to parse `settings.gd` to get it. Writing it found gotcha 56. Eight plants, each
  exit 1; six settings photographed in pairs. 1,782 assertions, stripped 1,708. Version 2.0.0,
  untagged. CI green on `31fea16`, PR #34.

- **T5.6 A wholesale character swap, photographed — DONE, 2026-09-05.** The phase's last proof
  criterion, and the only one of the three that was a proof rather than a feature. The repository
  held a sheet with a different GRID and a sheet with GAITS and **never one with both**, so the
  phase's claim had been demonstrated in halves. `character_alt.png` went from two animation
  blocks to five (idle, walk, run, sneak, climb, 96x600) and `character_alt_layout.tres` is now
  the only layout in the project that leaves no gait at -1. The player was pointed at the pair,
  driven through all five gaits through the real input path and photographed, and **no file under
  `src/` changed for the swap** — the swap is two `ExtResource` paths in `player.tscn`. The
  CONTROL is the strongest evidence: the same probe on the DEFAULT sheet draws blocks 0, 1, 2, 1,
  1 — sneak and climb falling back to the walk block, which is the `-1` contract measured in the
  live game for the first time. Four defects, three of them this row's own, and all four
  invisible to any rung that does not open a window: gotchas 57 to 60. Two plants, each exit 1,
  and plant 2 re-created T5.3's defect exactly, which is the row's own claim made good.
  1,782 -> 1,798 assertions. Version 2.1.0, untagged.

- **T5.7 `reduce_motion` finished, and the shadow atlas — DONE, 2026-09-05.** The two things T5.6
  wrote down and deliberately skipped. `accessibility/reduce_motion` reached **three of the four**
  motions this template draws: `ScreenFade` cuts instead of dissolving and
  `HD2DCameraRig.follow_lag` goes to zero, both on `_authored_dof`'s veto shape. **The shadow half
  was a live defect rather than a portability worry** — `_apply_shadows` restored a `2048` const
  called "the engine's own default" and the default is **4096**, so every windowed boot of this
  repository ran at half the authored shadow resolution, measured `boot = 2048` against
  `boot = 4096` on a real display server. `ShadowAtlas` (new, `core`) reads the authored sizes
  before the first zeroing; `settings.gd` went 144 -> 139 of its 150. That is **gotcha 61**, whose
  transferable half is that `_apply_display()` returns early under `--headless`, so no rung below
  the windowed capture executes that code at all. **The camera motion turned out to be
  photographable, contradicting this row's own prediction**: two `--gait-shots` runs differing by
  one line of `settings.cfg` translate the whole world by 42 px, residual 0.0268 at -42 against
  0.0975 at zero. Four plants, each exit 1. 1,798 -> 1,821 assertions.
  `settings_consumers_test.gd` split at its budget, `settings_effects_test.gd` is the new half. Version 2.2.0, untagged.

**Exit criteria for the phase:**

- [x] A character's movement styles come from its sheet, not its code: idle, walk, run, sneak and
      climb each addressable, and an unnamed one falling back rather than breaking. — T5.2 for
      the addressing, **T5.3 for climb actually arriving.** This box was ticked while CLIMB
      reached nothing; it is honest now, and the lesson is that "addressable" was asserted at
      both ends of a seam whose middle had no assertion.
- [x] The same seam serves NPCs, with no NPC-specific animation code. — T5.2, `NpcBrain` passes a
      gait and knows nothing about animation blocks. Worth knowing: `NpcBrain` only ever passes
      WALK or IDLE, so RUN, SNEAK and CLIMB are exercised by the player alone.
- [x] **More than one idle.** A second idle block chosen over time or at random, so a standing
      character is not a held pose. **Reworded by T5.3's finding rather than closed:** the reason
      a standing character was a held pose was that the idle block never advanced at all, which
      T5.3 fixed. What remained was genuinely a SECOND block and a chooser between them.
      - **T5.23, 2026-09-09, and the CHOOSER was the package.** The block was never the gap:
      `SpriteSheetLayout` could address 32 animations and `frame_index` could draw any of them
      since T2.1, so a sheet could always CARRY a second idle. What was missing is that every
      block in this template is chosen by a `GameEnums.MoveState` and standing still is ONE
      state, so nothing would ever ask for one. **The chooser is dwell time with its threshold
      on the sheet** - `idle_break_row` names the block, `idle_break_after` starts it, it plays
      once and hands back, and the clock restarts from the END of the break. **Dwell rather than
      weather, a schedule or an area tag** because each of those needs an autoload that
      `sprite_sheet_layout.gd` may not touch and that `character_visual.gd` is forbidden from the
      other side, it being TOLD a velocity and a state; dwell is the one trigger derivable from
      what the visual is already handed every frame. Photographed by a pass that presses NOTHING
      and WATCHES rather than aiming a frame number: block sequence `0x12, 3x8, 0x18, 3x8, 0x2`
      over eight seconds, the break running 1.33s (4 cells at 3fps exactly) and the gap between
      two breaks measuring **3.0s, the authored number, from the END of the previous one**. The
      two blocks differ by **0.6184 of the crop** against 0.0949 and 0.1406 for either block own
      cycle.
- [x] **A turn in place.** — **T5.14, 2026-09-06, and the SEAM DECISION was the package.** The
      question was never how to animate a turn: `face_direction()` was correct and asserted from
      the day it was written, and had only test callers because nothing had decided WHO may ask.
      The owner's answer was BOTH, on the strength of a case neither candidate asker covered — an
      NPC that notices the player, walks over and stops them — so the seam is
      `Events.turn_requested(character, towards)` on the bus rather than a call inside either.
      `InteractionSensor` asks for the player while they are STILL; `Speaker` asks for the person
      you talk to. Photographed: the same character, same position, one shutter apart, column 3
      to column 5, **0.7666 of the crop's pixels changed against a 0.1838 no-turn control**.
- [x] **A worked example of swapping a character wholesale** — a second sheet with a different
      cell size, facing count and gait set, dropped in and photographed, to the standard T2.1 set
      for the layout swap. — **T5.6, 2026-09-05.** `character_alt.png` is 4 facings, 24x40 and
      FIVE blocks against the default's 8, 32x48 and three, and the swap is two `ExtResource`
      paths in `player.tscn` with nothing under `src/` touched. Five gaits driven through the
      real input path and photographed, each pip tally agreeing with the block decoded off
      `sprite.frame`; the same probe on the default sheet draws sneak and climb from the WALK
      block, which is the `-1` fallback measured live. Captures are re-takeable with `--gait-shots=<dir>` rather than committed, which is this project's standing practice for screenshots.

**EVERY BOX IN THIS PHASE IS NOW TICKED.** The last one — a second idle block and a chooser —
was closed by T5.23 on 2026-09-09, and the shape of it is worth keeping: the box had stood open
since the phase was written, was REWORDED once by T5.3's finding, and turned out to name a
chooser rather than the block it appeared to name. The other box that stood here — **a turn in
place, and WHO may ask for one** — was a seam decision T5.3, T5.5, T5.6 and T5.7 each declined to
make silently; the owner made it on 2026-09-06 and T5.14 built it. **Two of this phase's last
three boxes were seam decisions wearing the clothes of animation work**, which is the
generalisable thing: when a criterion here stays open a long time, the reason is usually that
nobody has decided WHO owns the answer, not that the code is hard.

**AND A THIRD THING THE OWNER SAW THAT NO EXIT CRITERION ASKS FOR — FIXED, T5.8, 2026-09-05.** On
2026-09-05 the owner reported that sideways movement "just slides to the side". It did, and **the
code was not the reason**: `character_placeholder.png` drew one pose eight times, measured at 0.7%
pixel difference between the front view and the back, with facings 2 and 3 byte-identical. Both
boxes above are about a character's BLOCKS; nothing on this list ever asked whether a facing is
distinguishable, and every capture in T5.2, T5.3 and T5.6 was taken without noticing.
**T5.8 gave both sheets five poses and a mirror** — front, three-quarter, side, three-quarter
back, back — took the worst facing pair from 0.0% to 7.5% (default) and 21.9% (alt), added
`sheet_facings_test.gd` with a floor picked by measurement, and photographed the same character
walking north, east, south and west through `--facing-shots`, which nothing in this repository had
ever captured. It touched no file under `src/` except the debug capture tool. That is gotcha 62.

- **T5.8 A placeholder sheet whose facings are distinguishable — DONE, 2026-09-05.** Candidate J,
  and the only row on this board that came from the owner playing the game rather than from an
  audit. Suite 1,821 -> 1,829, one plant at exit 1, version 2.3.0. **It does not tick either box
  above** — it is about the SHEET, not the blocks — but it changes the case for one of them: a
  turn in place was not worth animating while every facing drew the same picture, and now it is.

- **T5.9 Screen shake, and the setting that scales it — DONE, 2026-09-05.** Candidate H, and the
  row T5.7 obliged: it had finished `reduce_motion` for the three motions that EXISTED and written
  down that a shake would have to be reached in the SAME row it was built, or the setting was a
  gap again. `HD2DCameraRig` gained a decaying SINE offset (102 -> 138 of its 250, so no new class
  was needed), `Events.camera_shake_requested` is the ask, `Gate.open_shake` is the template's own
  asker and **defaults to 0.0**, and `gameplay/camera_shake` is back in `DEFAULTS` as its 0..1
  scale — **the first of the three settings 2.0.0 removed to come back with the feature it was
  waiting for**, which is what removing them instead of faking them was for. `reduce_motion`
  removes it outright rather than making it smaller, on the typewriter's and the fade's reasoning.
  A sine and not noise is what made it provable: the same command at scale 1.0 / 0.5 / 0.0 moves
  the camera **0.302357 / 0.151178 / 0.000000 m** and the picture **(+14,-12) / (+8,-6) / (0,0)
  px**, with the HUD at identical pixels throughout. Suite 1,829 -> 1,848, two plants each exit 1,
  **gotcha 64**, version 2.4.0.



- **T5.10 Autosave, and the slot policy it needed first — DONE, 2026-09-05.** Candidate G, and the
  **second** of the three settings 2.0.0 removed to come back with the feature it was waiting for;
  only `accessibility/subtitles` is left, and it still has nothing to caption. T5.5 refused to fake
  this one because `SaveSystem` had no notion of the slot a run belongs to, so **the slot was the
  design question and the trigger was the easy half**. The answer is a DEDICATED slot one past the
  manual six — `SaveSystem.AUTOSAVE_SLOT`, written to `user://saves/autosave.json` — which no
  manual list can reach, because every manual list iterates `MAX_SLOTS` and never counts that high.
  Reserving slot 5 instead would have changed what slot 5 MEANS in every save already on disk, a
  MAJOR bump paid for nothing; the format is untouched and `SCHEMA_VERSION` is still 1, so this is
  **2.5.0**. Reading is deliberately wider than writing: `latest_slot()` sees the autosave, so
  Continue resumes it and the load list offers it, while the save list cannot name it. The policy
  is a node under `GameRoot` — not a second job for `SaveSystem`, which owns the format and not the
  occasion, and not an autoload, which would need an ADR. Both occasions (`game_ending`,
  `area_entered`) were already on the bus, so **no signal was added and `game_root.gd` gained
  nothing but lost the stale comment that said an autosave would go there.** Three refusals, each
  proved by the absence of a file: the player's veto, a transition in flight, and no run in
  progress. **Gotcha 65** came out of the transition guard and is the transferable half:
  `area_entered` is emitted TWO STATEMENTS BEFORE `_transitioning` is cleared, so the obvious guard
  would have refused every arrival and the feature would never have fired once — with nothing red
  anywhere. Suite 1,848 -> 1,898, four plants each exit 1, and the indicator photographed: the same
  command with the setting on writes `autosave.json` and shows `Autosaved.` on the toast, and with
  it off writes nothing and shows nothing, over an otherwise identical frame.
- **T5.11 Music ducking, built — and the alias beside it deleted — DONE, 2026-09-05.** Candidate E,
  which was explicitly "build it or delete it", and **the answer is both**, split on one line.
  `duck()` and `unduck()` were BUILT, because the occasion already existed:
  `Events.dialogue_started` and `dialogue_finished` have been on the bus since Phase 0 with one
  emitter each, so a `DialogueDuck` node under `GameRoot` was the whole wiring and **no signal and
  no setting were added**. `stop_music()` was DELETED — two lines of alias over
  `play_music(null, fade)`, no caller in three phases, no occasion this template has that the
  surviving spelling does not serve — and deleting a public method is a MAJOR bump, so the base is
  **3.0.0**. **The methods were not merely uncalled, they were WRONG, which only wiring them could
  reveal:** `duck()` tweened to an ABSOLUTE −8 dB, so against a player who had moved `audio/music`
  to 0.25 (−12 dB) it made the music four decibels LOUDER every time somebody spoke. `target_db()`
  measures a duck from the player's own level instead, and a muted bus stays muted. Three smaller
  defects came out of the same wiring — a settings change lifted the duck, two ducks raced, and a
  positive "duck" would have worked. The duck COUNTS conversations and releases after the last,
  because a plain pair lifts the music underneath a second one still running with nothing red
  anywhere. **A bus volume in dB is a number the audio server hands back even under the dummy
  driver, so essentially all of this row is proved in the suite** in a way T5.7's and T5.9's camera
  work was not: suite 1,898 -> 1,935, five plants each exit 1, and the windowed capture is a
  regression check only, because a still frame cannot show a decibel. **Gotcha 66** retires an
  honest limit T5.7 wrote down: `SceneTree.get_processed_tweens()` and `Tween.custom_step()` tell a
  fade from a cut inside a synchronous `run()`. **The fourth consumer gate was considered and
  deliberately not built** — public-method liveness is a package, not a paragraph, and it is
  candidate K.
- **T5.12 Two capture gaps closed, and the third argued away — DONE, 2026-09-06.** Three
  consecutive rows closed with the same admission and each named a probe as the fix, which is one
  gap rather than three. **Two were built and the third was argued away**: a still frame cannot
  show a decibel, so T5.11's probe would have produced only a log line, and gotcha 66 had already
  retired the limit that made it look necessary. `src/systems/debug/dev_scenario_shots.gd` is the
  fifth debug file — `--gate-shot=<dir>` throws the demo's lever, opens its gate through the
  interact key and photographs the shake **the gate** asked for; `--autosave-write` and
  `--autosave-continue=<dir>` write an autosave from a real `area_entered` in one process and read
  it back through the real Continue row in another. **The probe found two defects in itself
  first**, both silent and both green: standing beside a thing does not SELECT it, and `rest`
  sampled twenty frames after a teleport is the follow-lag tail rather than rest. **0.154743 m
  against a `camera_shake=0` control at 0.000050 m**, reproducible to the micrometre because the
  shake is a sine. Suite 1,935 -> 1,947; two plants, each a real reversion, each exit 1 with its
  control at exit 0. **3.1.0 and not a PATCH on one line**: nothing under `src/` outside the debug
  directory changed, but `game_root.tscn` gained a node a consuming game has to merge.

- **T5.13 A public-method liveness gate — DONE, 2026-09-06.** Candidate K, and the fourth
  consumer question: T5.4 built three gates for the "declared and read by nothing" class and T5.5
  asked it of the settings, but **a public method was still declarable-and-dead with nothing
  saying so**, which is how `AudioDirector.duck()` survived three phases uncalled and turned out
  to be WRONG as well as unused. `tools/check_methods.gd` is rung 11. **The design question was
  which methods it is even asked of**, and the answer is the narrowest question a text scan can
  answer soundly: not "is it called on a value of the right type" but "did anybody write this name
  down at all" — which needs no knowledge of `Callable`, `.bind`, unqualified inherited calls or
  `.tscn` properties, because every one of them writes the name out. **First run: exit 1, twelve
  violations of 316.** Two deleted, one wired, nine exempted with an argued sentence each, and
  **two of the twelve carried doc comments naming callers that never existed** — a gate for dead
  code finding false claims in prose. Proved against its own motivating case: at `7a162ca`,
  `duck`, `unduck` and `stop_music` had zero references outside their declarations, so it would
  have failed on the day each landed. **86 of the 316 are reached only from `tests/` or `tools/`
  and that is REPORTED, never failed** — "a caller in the suite" is not "a caller in the game",
  but a template declares accessors this repository will never call, and a gate that starts out
  mostly exemptions is decoration. Suite 1,947 -> 1,970; three plants, each exit 1, control exit
  0. **4.0.0, a MAJOR bump, because two public methods are gone** and the entry names the
  one-line replacement for each. **Gotcha 69**: the gate's precondition fired on the test file
  that quoted its own trigger pattern, and the gate was right.

- **T5.15 The `Button` styleboxes — DONE, 2026-09-06.** Candidate F, the last row on the board,
  and the oldest declared limitation in the project: the theme set `font_sizes` on nine type
  variations and no `Button/styles/*` at all, so every menu row and every dialogue reply drew the
  engine's fallback panel. **Four packages had opened this file and closed it again, each giving
  the same reason** — a stylebox has to be *designed*, and the only palette to design against is
  the placeholder one, so populating it would ship a decision as a default. **That reason is what
  the fix answers rather than overrules: nothing in `src/ui/root/ui_row_styles.gd` designs a
  colour. It designs the RELATIONSHIP between the five states** and takes every colour from the
  palette. **`hover` is `surface` moved toward `text`, and that word is the whole package**: the
  same expression lightens a dark row and darkens a light one, so the fix survives a palette this
  base does not ship — which is the half of the stated defect ("immediately wrong against a light
  one") a hard-coded lighten would have left in place. `pressed` moves toward `accent` because a
  press is an act and wants a hue; `disabled` keeps the hue and drops the alpha; **`focus` draws
  no centre at all**, only an accent ring, so it composes with whatever is underneath — and it is
  the state a mouse user never sees and a gamepad player navigates by. **ONE palette entry was
  added and named as such**: `dim` and `solid` are the panel a row sits ON and `muted` already
  meant "present but lesser", so there was no token for a button SURFACE and inventing one
  silently would have been the invention the four refusals were about. Photographed twice over:
  on the shipped palette a row's separation from its panel goes from **0.0981 to 0.3490 summed
  channel delta, 3.6x**, with **every one of the 61,998 changed pixels inside the row band and
  none outside it**; and the whole thing again on a parchment palette, changed by six palette
  lines and no code. **MINOR, 4.2.0** — nothing removed, nothing renamed, and a game that
  authored its own `styles/normal` or ships a palette with no `surface` is left exactly as it
  was, both refusals asserted. Suite 1,983 -> 2,051; five plants, each a real reversion, each
  exit 1, control exit 0. **The plant that matters is the hard-coded lighten**: it passes every
  dark-palette assertion in the file and fails only the light ones, which is why the light
  palette had to be asserted rather than only photographed.

- **T5.16 Quest chaining, and the guard that discarded what it was warned about — DONE,
  2026-09-07.** Two things, and the first was not a package: **the sixteen-package T5 stack landed
  on `main`** as one fast-forward of 31 commits, `main` having declared `1.0.1` while the work
  declared `4.2.0`, so every document a new session is told to trust described a base fifteen
  versions stale. Then a real correctness defect, found by auditing the base rather than by any
  rung: `QuestTracker.evaluate()` guarded re-entrancy by **RETURNING**, so a listener on
  `quest_completed` writing the next chapter's start flag — **the case the guard's own comment
  names** — landed back in `evaluate()` mid-pass and was discarded. Harmless only if the running
  pass still reaches the newly-startable quest, which depends on where it sits in `QuestDb.all()`
  — `ContentScan` insertion order, unsorted — so a chapter that begins when the previous one ends
  started or silently did not according to filenames, and differently on two machines. Fixed with
  a pending bit drained by the outer pass, bounded at `QuestDb.count() + 2` so it cannot go stale
  at a game's sixtieth quest. `tests/unit/quest_chain_test.gd`, 8 assertions; the plant fails
  **exactly 1 of the 8**, and that is the load-bearing detail — the benign scan order passes while
  the defect is live, so the two order blocks are demonstrably not the same test twice. **Gotcha
  72**: the tell is whether a guard's caller wanted a RETRY or wanted to be REFUSED. `4.2.1`, a
  PATCH. Also: **branch protection went on `main`**, requiring both `Ladder` jobs, which retires
  this project's own "not built" line for it.

- **T5.17 Reconciling the record with what the gates now do — DONE, 2026-09-07.** Six
  documentation defects from the same audit that produced T5.16, every one of them prose
  disagreeing with shipped behaviour, and no code changed. `CONTEXT.md`'s "Not built" list still
  called the `Button` styleboxes unbuilt three hundred lines below its own header announcing
  T5.15 built them; `quest.` was missing from the prefix tables in `TEMPLATE.md` and
  `AUTHORING.md` while `AUTHORING.md` routes the reader to `TEMPLATE.md` as canonical, so the
  canonical copy was the wrong one; `keys.*` was listed as an engine prefix in three documents and
  has **zero** rows in the CSV, which is gotcha 48 in the other direction; `TEMPLATE.md` promised
  an `OPTIONAL` status in `SYSTEMS_INVENTORY.md` that never arrived in eleven packages;
  `AUTHORING.md`'s gate table explained **three of seven** checkers in the one document a consumer
  is told to author from; and `check_boundary`'s row omitted the localization half T5.4 added.
  **Split from T5.16 rather than folded into it** because T5.16 is a behaviour change with a plant
  and a control and this is prose with no assertions of its own — mixing them would have put six
  unverifiable edits inside a commit whose whole claim is that one thing was measured. **Its
  recorded gap is the sentence T5.19 then half-overturned**: *"nothing gates a prose claim, and
  nothing can"*, which is right about prose and wrong about structure.

- **T5.18 The save loader's refusals, and a path nothing can enter — DONE, 2026-09-07.**
  `tests/unit/save_recovery_test.gd`, 17 assertions, with `save_system.gd` byte-identical to
  `main`. **Six refusal branches were carried by review alone**: a file that is not JSON, a
  missing `version`, a save from a newer build, a non-Dictionary section, a section predating
  per-section versioning, and a section absent altogether — a grep for `ERR_FILE_CORRUPT` across
  `tests/` returned nothing and no test had ever written a malformed save file. **THE DISTINCTION
  THE CASE EXISTS TO PIN IS A POLICY**: a corrupt ENVELOPE is refused outright, a corrupt SECTION
  is logged and skipped while the rest of the save loads — the difference between a player losing
  a setting and a player losing forty hours, implemented correctly and asserted nowhere, so
  nothing stopped a later change collapsing the two. Chosen over the taxonomy row on one point
  that inverted the plan's own ranking: **prose cannot be proved by running the engine.** And it
  found the eighth appearance of declared-and-not-reached, the first where the unreached thing is
  a control-flow PATH: at `SCHEMA_VERSION == 1` no integer satisfies not-one, above-zero and
  at-most-one, so `_migrate`'s success path cannot be entered by any file a player can have, and
  `SYSTEMS_INVENTORY.md` called migration DONE — which reads as *exercised* and meant *written*.
  **The case expires by itself**, pinning `SCHEMA_VERSION` so the suite fails at exactly the
  moment a migration test first becomes possible. `4.3.0`, a MINOR. Also took `v2.0.0`, `v3.0.0`,
  `v4.0.0` and `v4.2.1`.

- **T5.19 Reconciling the record, and gating the part of it that is not prose — DONE,
  2026-09-08.** Twelve places where the record disagreed with the repository, plus
  `tests/unit/record_shape_test.gd` (63 assertions) and a third fact for `version_test.gd`. No
  production code changed. The twelve include `CONTEXT.md` — the file `CLAUDE.md` orders every
  session to read FIRST — stating version `2.4.0` two majors late, claiming 1,798 assertions
  against 2,143, and carrying a **"THE NEXT PACKAGE"** paragraph describing T5.2's long-shipped
  work, which was the most misleading of the twelve because it sent a reader to redo it.
  **AND THE ANSWER WAS A GATE RATHER THAN A THIRD RECONCILE**, which is this row's whole point:
  T5.17's *"nothing gates a prose claim, and nothing can"* is right about prose and wrong about
  two of the twelve, because a file either opens with its own title or it does not and a package
  either has a row or it does not. Neither question has a reading or a tone, which is exactly why
  they are assertable when the sentences around them are not — **structure is a third kind of
  fact**, after "what a document claims exists" (`docs_test.gd`) and "a count"
  (`doc_counts_test.gd`), and it got a third case rather than widening either MUST NOT line.
  **Gotcha 70 caught the author of the gate built to catch drift**: plant 3 passed at exit 0
  because the `sed` addressed line 143 and the claim was on 144, so a green run was nearly
  recorded as evidence. `4.3.1`, a PATCH.

- **T5.20 Splitting the staging surface, and the gate that makes a split safe — DONE,
  2026-09-09.** `src/systems/debug/dev_stage.gd` stood at **248 of its 250** allowed code lines,
  so the next change to it would have failed rung 5; five staging flags that push a screen moved
  to a new sixth debug file, `dev_screens.gd`. **The docs had pointed at the wrong file for ten
  rows** — `CONTEXT.md` and the candidate list had called `tools/gen_placeholders.gd` "the next
  file to split" since WP-14, and it has twenty lines spare; T5.19 measured every file with
  `check_budgets.gd`'s own rule and found which one was actually against the wall, which is the
  measurement earning its keep against ten packages of unchecked prose. **The seam was chosen by
  QUESTION, and it is a dependency fact rather than a filing preference**: `dev_stage.gd` answers
  *what is TRUE in the world* and `dev_screens.gd` *what is DRAWN OVER it*; every flag that moved
  ends in a `UiRoot.open()` and not one that stayed does, and those five were the only staging in
  the file naming the `ui` layer at all. Precedent respected in both directions — the surface has
  split three times along a question and `dev_gait_shots.gd` **declined** a fourth for buying only
  "a more accurate FILE NAME". One dividend: gotcha 35's rule that a flag drawing to SCREEN waits
  for a SETTLED area was stated in a header shared with eleven flags that do not draw, which is
  how `--stand-by` went four packages without following it; in `dev_screens.gd` it is the file's
  whole subject, so a seventh screen flag inherits it by being in the right place. `5.0.0`, a
  MAJOR.

- **T5.21 A scene-level interaction test, and the defect it found — DONE, 2026-09-09.** Taken
  because another file asked for it in writing: `interaction_test.gd`'s MUST NOT line has read
  since WP-02 that the sensor's ranking *"needs real geometry and belongs in a scene-level test"*,
  and that test was never written. So the rule every interactable rests on — the one the sensor's
  own header calls the actual problem it solves, *"detection is trivial; selection is not"* — had
  no assertion in a suite of 2,148, and `Speaker` and `Readable`, two of the eleven prefabs
  `AUTHORING.md` tells a consuming game to place, had no scene-level assertions at all.
  **Gotcha 54's shape at the top of the interaction stack**: `interaction_test.gd` proved what an
  object does once chosen, `turn_test.gd` proved the turn once it is, and between them sat the
  decision neither made. `tests/unit/selection_test.gd`, 24 assertions with real geometry —
  priority over proximity, proximity between equals, the facing term including whether velocity
  reaches `_facing` at all, the name tie-break, what leaves the ranking without leaving the
  candidate set, and the cycle with its wrap. **AND IT FOUND A REAL DEFECT ON ITS FIRST RUN,
  gotcha 73**: `_select()` tied on `a.name < b.name`, but `Node.name` is a `StringName` and `<`
  on two of those compares **interned addresses, not text**, so ties followed script and scene
  load order while the comment above the line promised the NAME. The comment was half true, which
  is why it survived eight rungs — an address does not move, so the order WAS stable within a run;
  it simply was never the name, so an author numbering two overlapping objects to choose between
  them was ignored. One cast fixes it. **The first probe of the comparison said the language was
  innocent and agreed by coincidence** — gotcha 70 turned around, and the second half of 73.
  `InteractionSensor` gained one public method, `cycle()`, because the synchronous suite provably
  cannot press a key: `Input.parse_input_event` is buffered until a flush that never comes
  mid-run, and `Input.action_press` lands but then leaves the action reading
  `is_action_just_pressed() == true` for the whole run, which would cycle every other case's
  sensor. Same reasoning as `is_suspended()`; the binding is still proved windowed by
  `dev_stage.gd --cycle`. **MINOR, 5.1.0.** Suite 2,148 -> 2,173; twelve rungs and seven checkers
  green. **Five plants, each failing a DIFFERENT set** — tie-break reverted 3, priority term 1,
  facing term 1, cycle offset ignored 4, lone-candidate guard 1 — which is what says they are not
  one assertion five times.

- **T5.22 A redirectable `SAVE_DIR` — DONE, 2026-09-09.** The suite was writing into the
  developer's own save directory, and the store was the last content root that still could:
  `fixtures.gd` repoints five, and this was the sixth, left out because `SaveSystem.SAVE_DIR` was
  a `const`. Two cases wrote real slots through it, `save_recovery_test.gd` — whose whole purpose
  is writing MALFORMED save files — and `core_test.gd`'s round trip. **They cleaned up after
  themselves, which is not the same as never having been there**: the run that fails to clean up
  is the run that crashed. `const SAVE_DIR` became `const DEFAULT_SAVE_DIR` plus `var save_dir`,
  whose setter creates the directory so boot and redirect share one path. **Public rather than
  test-only**, because a portable build writing beside its executable wants the same seam and a
  suite-only backdoor is what `fixtures.gd`'s header already refuses. New
  `tests/framework/save_fixture.gd` on `Fixtures`' shape and `tests/unit/save_dir_test.gd`, 18
  assertions; `test_runner.gd` deactivates after EVERY case. `save_system.gd` 166 -> 172 of its
  180, measured BEFORE the row started. **MINOR, 5.2.0.** Suite 2,173 -> 2,192; twelve rungs and
  seven checkers green. **AND THE FIRST VERSION OF THE LOAD-BEARING CASE PASSED THE PLANT —
  gotcha 74**: it compared the untouched file byte-for-byte against a copy taken before the
  redirected write, and the full reversion passed, both writes having landed on the same path in
  the same second with only second-resolution `saved_utc` and tenth-snapped `playtime_seconds`
  varying. Different markers fixed it; the same plant now fails 4. **Two plants, different sets**
  — full reversion 4, runner deactivate removed 3.

- **T5.23 A second idle block and a chooser — DONE, 2026-09-09. THE LAST PHASE T5 EXIT
  CRITERION.** T5.2 made gaits data, so idle, walk, run, sneak and climb are separate cycles a
  SHEET names and an unnamed gait inherits the walk block. What did not exist was more than one
  IDLE, or anything to choose between them, so a character stood in exactly one way forever.
  **THE GAP WAS NEVER THE BLOCK** — `SpriteSheetLayout` could address 32 animations and
  `frame_index` could draw any of them since T2.1, so a sheet could always carry a second idle;
  what was missing is that every block in this template is chosen by a `GameEnums.MoveState`,
  and standing still is one state, so nothing would ever ask. **So the row is a chooser, and the
  chooser is DWELL TIME with its threshold on the SHEET**: `idle_break_row` names the block,
  `idle_break_after` says how many seconds of unbroken standing start it, the block plays ONCE
  and hands back to `idle_row`, and the clock restarts from the END of the break — so the
  authored number is the gap a player sees rather than that gap minus the block's own length.
  **WHY DWELL AND NOT WEATHER, A SCHEDULE OR AN AREA TAG**, which were the other three
  candidates: each needs an autoload — `Weather`, `Clock`, `Flags` — that
  `sprite_sheet_layout.gd` is forbidden to touch and that `character_visual.gd` is forbidden
  from the other side, it being TOLD a velocity and a state. Dwell is the one trigger derivable
  from what the visual is ALREADY handed every frame, so it is the only one of the four needing
  no new dependency anywhere; and nothing is lost, a game wanting a rain idle pushing a
  MoveState or swapping the layout resource. **`problems()` gained three branches**, all of them
  gotcha 38's shape: a row with no delay, a delay with no row, and a break pointing at the idle
  block it is meant to interrupt — each looks configured, is in range, and draws exactly what
  the sheet drew before. **THE CAPTURE IS THE CLAIM AND IT RETURNED NUMBERS, NOT A JUDGEMENT.**
  A new `--idle-shots=<dir>` pass presses nothing at all — the whole input is standing still —
  and it WATCHES rather than aiming a frame number, because the moment of interest is decided by
  a threshold on the sheet that the probe must not know (gotcha 52's shape again), and because
  one shot of the break block could not show that it STARTED and ENDED. Sampling six times a
  second for eight seconds: `0x12, 3x8, 0x18, 3x8, 0x2`, the break running 1.33s and the gap
  between two breaks 3.0s from the end of the previous one. Crops: idle's own cycle 0.0949, the
  break's own cycle 0.1406, the two BLOCKS **0.6184** — four to six times either, which is what
  distinguishes a second idle from a recolour with a wobble. **AND THE PLANTS FOUND A HOLE IN
  THE NEW TEST — gotcha 75**: "interrupted standing does not accumulate" PASSED under the defect
  it was written for, because the wrongly-started break had already FINISHED inside the same
  stand, so the case read the idle block and agreed by coincidence. Gotcha 70's family, one row
  after T5.22 met it; the fix is timing, not logic. **MINOR, 5.3.0.** Suite 2,192 -> 2,221 (+26 the new case, +2 `docs_test` on the two fields now in `ART_CONTRACT.md`'s worked example, +1 `record_shape_test` on this row's DEVLOG heading);
  twelve rungs and seven checkers green. **Seven plants, seven different failure sets** — break
  never starts 4, break loops 2, moving does not cancel 2, dwell reset at the START rather than
  the end 2, fallback to row 0 instead of the idle block 1, `has_idle_break` dropping its delay
  half 1, the three half-configured problems unreported 3.

- **T5.24 The roadmap's missing run, and whether completeness should be gated — DONE,
  2026-09-09.** This file's own package log ran T5.15 and then jumped to T5.21: **T5.16, T5.17,
  T5.18, T5.19 and T5.20 were absent**, five delivered packages each with a DEVLOG entry and a
  board row — four of them with a version bump of its own, T5.17 having changed no code and left
  the tree at `4.2.1` — and no trace in the file `CLAUDE.md` sends a reader to for
  *where things stand*. T5.21 recorded the gap; T5.23 recorded it again and promoted it to the top
  of the next-package list; **nothing was red, because nothing counted the rows** — T5.4's
  structural cause one level up from code. **THE ROW WAS TWO THINGS AND THE SECOND MATTERED:**
  writing five entries is bookkeeping, and the question was whether completeness should be GATED
  the way `record_shape_test.gd` already gates two other structural facts. **It should, and T5.19
  is the precedent rather than an analogy** — that row exists precisely because a third manual
  reconcile was the wrong answer, and its argument transfers unchanged: a package either has a row
  or it does not, and that question has no reading and no tone. **THE COUNTER-ARGUMENT WAS REAL
  AND IS ANSWERED BY THE SHAPE OF THE CHECK.** This file's log genuinely is selective in a way the
  board is not — it records a package as a log row, as a tick beside an exit criterion, or as a
  parenthesis in a phase's Done list, and **T5.14 is only ever the second** — so the assertion is
  `roadmap.contains(id)`, findability, which is the identical choice T5.19 made for the board and
  for the reason written there. The roadmap may record a package in whichever shape fits; it may
  not omit one. **And T5.16's refusal to touch this file was about the CRITERIA list**, which says
  nothing about the package log — a different list in the same file, asking where a package sits in
  the plan rather than whether a phase may close. **THE PLANT WAS THE LIVE REPOSITORY**, run
  before a document was edited — the one plant shape gotchas 74 and 75 cannot reach, both being
  failures of a fabricated condition — and it named **SIX, not five**: **WP-07, path actions, the
  signature non-combat mechanic, missing from this file since 2026-08-26** and named by neither of
  the two packages that had recorded this gap by reading it. That is the case for a gate over a
  third reverse-count, as a measurement. **Gotcha 76** came out of the plants that followed:
  findability is satisfied by an incidental cross-reference, so deleting T5.19's log row left the
  suite green on two passing mentions elsewhere. `5.3.1`, a PATCH; `src/` and `tools/`
  byte-identical. Suite 2,221 → **2,274**, and all 53 are computed plans doing their job rather
  than a case this row wrote.

- **T5.25 The gate that could not fail, and the numbers nothing was measuring — DONE,
  2026-09-09.** T5.24 shipped findability as `roadmap.contains(id)` and `board.contains(id)`, and
  **`contains` cannot tell an id from a PREFIX of a longer one**, which made four of its
  assertions unfalsifiable: `T5.1` is a substring of T5.10 through T5.19, `T5.2` of T5.20 through
  T5.24, `WP-09` of `WP-09b`, `WP-14` of `WP-14b`. Delete every genuine trace of those four and
  the suite stays GREEN on a sibling's own row. **This is gotcha 76 with a sharper edge and it is
  worth separating from it**: 76 is that findability is satisfied by an incidental cross-reference,
  which is a judgement about whether a mention counts; this is that the assertion was reading a
  DIFFERENT STRING, which is not a judgement at all — the four packages hardest to notice going
  missing were the four the gate could not see. One word boundary on each check fixes both call
  sites, with the dot escaped because an unescaped one matches any character and would let `T5x1`
  satisfy `T5.1`, the mirror of the defect. **THE LIVE REPOSITORY IS NOT THE PLANT THIS TIME**,
  and that is the whole methodological point of the row: measured before the change was written,
  all 52 packages satisfy the word-boundary form in both files, so the tree is green either way
  and T5.24's strongest-available plant is unavailable here. So the proof is three runs on one
  plant — **T5.2's seven genuine roadmap traces renamed away**: tightened gate + no plant green at
  2,274, tightened gate + plant **red, exit 1, one failure, `FAIL T5.2 is findable in the
  roadmap`**, and the ORIGINAL `contains()` gate against the SAME plant **green at 2,274**. The
  third run is the one that matters; without it the change is untested by construction. **AND THE
  SECOND HALF WAS THE RECORD ITSELF, RECONCILED AGAINST MEASUREMENT RATHER THAN AGAINST ITSELF.**
  Six documents quoted totals nothing had re-measured: `README.md` **555 assertions** against
  2,274, stale since before `2.0.0`; `CLAUDE.md` "over 5,400 lines" against 8,986 and `2,173` in
  its own runner command, left behind by three version bumps; `TESTING.md` 1625/1551 and
  `ARCHITECTURE.md` 2,173; `CONTEXT.md` a census of 166 files and 15,552 code lines taken before
  T5.23 added a file, **and two self-contradictions in the file `CLAUDE.md` sends every session to
  FIRST** — "the base is 5.0.0-complete" nine lines above declaring **5.3.1**, and Phase T5's
  second-idle criterion "still stands open" fourteen lines above "Phase T5 has no unticked exit
  criterion". `version_test.gd` could not see the first because it reads only BOLD semvers and
  `5.0.0-complete` is unbolded. **The nine `**Commit:**` lines the board has asked for since T4.3
  are now written for T5.16–T5.24, and NOT gated** — 15 of 52 packages had one, so the gate would
  fail 37 historical rows and scoping it to "T5.16 onward" is the rotting exception list this
  file's own gate header refuses to become; the gap is recorded instead. `CONVENTIONS.md` gained
  the branch-naming rule the project never had, whose load-bearing line is that the branch name is
  not authoritative — two branches here are misnumbered and renaming one mid-stack moves the base
  of every PR above it. `5.3.2`, a PATCH; `src/` and `tools/` byte-identical. Suite 2,274 →
  **2,276**, both new assertions being this row's own DEVLOG heading passing through a computed
  plan rather than a case this row wrote.

- **T5.26 The ladder's own gate could not see an unwired checker — DONE, 2026-09-09.**
  `gates_test.gd`'s header states its purpose as catching "a gate written, committed, and never
  wired". **It could catch neither shape of that**, and both were found by auditing the gates one
  row after T5.25 audited a different one. **First: `LADDER` was a const naming seven checkers,
  with nothing asserting it named ALL of them** — so an eighth `tools/check_*.gd` was invisible to
  the one case whose entire subject is a gate nobody runs, which is the defect being the defect's
  own blind spot. `test_runner.gd` closed the identical hole for `CASES` at T2.2 by scanning the
  directory, so the fix is that pattern rather than a new idea, and the argument for it is
  `check_boundary.gd`'s: a list of what to check rots, and its rotting is invisible exactly where
  it matters. **Second: the wiring assertion was `workflow.contains(checker)`, which is true of a
  workflow that names the checker in a COMMENT** — and this workflow's comments do name the
  checkers, deliberately, because they carry the reasoning for each rung. **MEASURED RATHER THAN
  ARGUED: commenting out both `run:` lines for `check_signals` left the suite GREEN at 2,276**, a
  checker running in neither job with the ladder's own gate reporting fine. That is the comparison
  run and it is the row's whole evidence, the same three-run shape T5.25 needed and for the same
  reason — the tightened assertion is green on the live tree, so nothing about A and B alone
  distinguishes a fix from a no-op. **THIRD, AND IT IS WHAT `contains` COULD NOT EXPRESS AT ALL:
  the count is per-JOB.** One bool for a whole file cannot say that a checker is wired into the
  full job and missing from the stripped one — which is wired into half a ladder, and the stripped
  half is the half that proves the template stands up with no game present. So the assertion counts
  INVOCATIONS, a non-comment line carrying both the script path and `--script`, and compares that
  count to `JOBS.size()`, with the job names themselves asserted so the number is not a fiction —
  `dev_tools_test.gd`'s self-guard against a silently-empty extractor, applied to a constant. **The
  plan is computed**, `42 + JOBS.size() + LADDER.size() * 2 + on_disk.size()`, for
  `record_shape_test.gd`'s reason: wiring an eighth checker should not mean editing a number, and a
  number that must be edited gets edited to whatever the run reported. **Three plants, three
  different failures, exactly one each** — both steps commented out `expected 2, got 0`; the
  stripped job's step alone removed `expected 2, got 1`; an eighth checker written and unlisted
  `tools/check_planted.gd is listed in LADDER — expected true, got false`, on a run whose total
  rose by one on its own, which is the computed plan proving itself in passing. **Gotcha 78, and it
  is gotcha 77's mistake in a second document one row later**: when a gate reads a FILE rather than
  the behaviour, ask which parts of that file are prose. `5.3.3`, a PATCH; `src/` and `tools/`
  byte-identical, the change being one test file. Suite 2,276 → **2,287**.

- **T5.27 A checker can skip a file and still print PASS — DONE, 2026-09-09.** The third row of
  the run that began with T5.25, and the first to move enforcement out of the suite and into the
  ladder itself. **RUNGS 5–11 READ ONLY THE EXIT CODE**, with no log grep and no artifact, while
  rung 4 has `ErrorWatch` for precisely one reason: **gotcha 24, this project's founding
  observation, is that a GDScript runtime error aborts the INNERMOST FRAME ONLY.** An error inside
  a checker's per-file function returns to the loop, the loop finishes, and the tool prints `PASS`
  and exits 0 having silently skipped a file. **MEASURED WITH A THROWAWAY PROBE RATHER THAN
  ASSERTED** — a loop of three calling a function that indexes an empty array on the second:
  `SCRIPT ERROR: Out of bounds get index '9'`, then `loop finished, items processed: 2 of 3`, then
  `PASS`, **exit 0**. The exit code cannot see it. **And the first attempt at that plant did NOT
  demonstrate it** — injecting the same error into `check_layers._scan_script` exited 1, so the
  premise looked false; the minimal probe is what separated "the tool dies" from "the tool
  continues and lies", which is gotcha 75's family and the reason the probe exists in the record.
  Each of the fourteen checker steps now captures its output, prints it, and forces failure if the
  log carries `SCRIPT ERROR` or `Parse Error`, with all seven logs uploaded from both jobs.
  **SECOND, SIX CHECKERS COULD PASS ON A SCAN OF NOTHING**, 0 of 7 having guarded it while each
  printed its own scanned count. Pointing `check_layers` at a directory with no scripts gave
  `scripts scanned: 0` then `PASS`, exit 0; it now fails, and the comparison run against the
  unmodified tool on the same empty scan is what says the guard does something. `CHANGELOG.md` has
  carried the rule since `4.3.1` — *"a doc gate that passes because it found nothing to check is
  worse than no gate"* — and it had never been turned on the tools. **`check_content` IS EXEMPT AND
  THE EXEMPTION IS THE INTERESTING PART**: its whole input is `data/` and `scenes/areas`, which the
  stripped job DELETES by design, so scanning nothing is legitimate for that checker and only for
  it — guarding it would fail the stripped job for doing its job. The other six read `src/`,
  `tests/`, `tools/` and `localization/`, none of which the strip touches, so zero there is always
  a defect. **THIRD, A COMMENT CLAIMED A CHECK NOTHING PERFORMED.** `ladder.yml` said a stripped
  template "must report exactly the same numbers"; the jobs are independent and nothing compares
  their output. Reworded to what is enforced — both must exit 0, which catches the failure mode
  that matters, an engine string that stops resolving once the game is gone — with the genuine
  cross-job comparison named as a candidate row instead of implied. `5.3.4`, a PATCH; `src/`
  byte-identical, the change being `ladder.yml` and six tools. Suite 2,287 → **2,291**, both from
  this row's own DEVLOG heading through a computed plan: **the enforcement this row adds is not in
  the suite at all**, which is the first time in this run that has been true.

- **T5.28 A template rule, a template default and a game choice are three different things —
  DONE, 2026-09-09.** `TEMPLATE.md` § *"The one constraint nobody has scoped"* has said since
  2026-08-26 that *"what is missing is the distinction between a template default and a game
  choice, which no document currently draws"*, and **nothing ever scheduled it.** `CONTEXT.md`
  ranked it FIRST for five packages and deferred it every time for one honest reason: *"it is
  prose and cannot be proved by running the engine."* **That is true and it is not a reason to
  leave it**, because the row was never optional — `CONTEXT.md` also recorded that it *"DECIDES the
  two rows under it rather than guessing"*, and both of those rows carried *"Scope depends on the
  taxonomy row above"* and *"Also gated by the taxonomy question."* **Three candidate rows were
  unscopable indefinitely for want of one distinction**, and this project's rule against inventing
  work meant none of them could honestly be started. Deferring the cheap row kept the expensive
  ones frozen. **THE ANSWER IS THREE KINDS, NOT TWO**, which is what made it tractable:
  a TEMPLATE RULE is foreclosed for every game and has a checker where the rule is mechanical; a
  TEMPLATE DEFAULT ships a working value and **a seam**; a GAME CHOICE means the base builds
  nothing and offers only the seam and the facts. **THE TEST THAT SEPARATES A DEFAULT FROM A RULE
  IS MECHANICAL RATHER THAN EDITORIAL — DOES A SEAM EXIST?** A "default" a game cannot replace
  without editing `src/` is a rule that has not admitted it, and that test is a fact about the
  repository rather than a matter of tone. It is also immediately productive: applied to
  `game_root.gd`'s `const PLAYER_SCENE`, it says the player prefab is a rule pretending to be a
  default, which is the next row. **APPLIED, SO THE ADR DECIDES RATHER THAN DESCRIBES**: no combat,
  the layer rule and the demo-name boundary are RULES — the last two already have checkers, which
  is what a rule looks like when it can be mechanised; time is a DEFAULT, because `Clock`,
  `NpcSchedule` and `Weather` are already here and a cycle extends a present system rather than
  adding one; **a chapter sequencer and an economy are GAME CHOICES** — the first would add a
  second way to express what a `story/chapter` int flag already expresses through the one
  `FlagQuery`, and the second is genre, on the same footing as `Harvestables`. **TWO CANDIDATE ROWS
  ARE CLOSED BY A REFUSAL RATHER THAN BUILT**, and writing the refusal down is the point:
  otherwise each is rediscovered, ranked, deferred for want of a reason, and ranked again — which
  is exactly what happened three times. **AND THE CUTSCENES ROW NEEDED A REASON, NOT A PACKAGE.**
  It was the only `TODO` in `SYSTEMS_INVENTORY.md` with a blank boundary column, and a draft of
  this row proposed building the seam on the grounds that nine `cutscene` mentions across eight
  files under `src/` were unpaid IOUs. **Read in full they are RECEIPTS** — *"deletes nothing here
  — it calls `Audio.duck()` from its own occasion"*, *"keeping it out of here is what lets a
  cutscene soak one courtyard on demand"*, *"forced by a cutscene, without touching this file"*,
  *"a cutscene can later ask for the same fade"* — each one a statement that the file is already
  cutscene-ready and the consuming game supplies the occasion. Reading a comment as a debt is how
  a comment becomes a work package; the row has a stated reason and a boundary line instead.
  **Also settled: `Fixtures.activate()` is ASSERTED, not skipped**, reversing what `TESTING.md`
  documented, because a skip reports GREEN and so the one condition the check exists to catch is
  the one nobody sees — the same "passes because it found nothing" failure T5.27 guarded the seven
  checkers against one row earlier. `bag_mirror_test.gd` converted, its plan 10 → 11; the plan gate
  caught the arithmetic before the suite did. **NO NEW GATE, AND SAYING SO IS PART OF THE ROW** —
  `record_shape_test.gd` and `docs_test.gd` already cover an ADR's structure, and inventing one to
  have one is what the previous four rows were about. `5.3.5`, a PATCH; `src/`, `tools/` and
  `.github/` byte-identical.

- **T5.29 The player prefab was a rule pretending to be a default — DONE, 2026-09-09.**
  **ADR-0007 FOUND THIS WITHIN AN HOUR OF EXISTING, WHICH IS THE ROW'S BEST ARGUMENT FOR ITSELF.**
  `src/core/boot/game_root.gd:28` held
  `const PLAYER_SCENE := "res://scenes/characters/player.tscn"` — engine code, in the `core`
  layer, naming the prefab a consuming game replaces FIRST — and `GameConfig` exposed exactly two
  `[game]` keys with no `player_scene` among them. `ARCHITECTURE.md` states the contract as *"a
  game adds content and resources; it does not add code under `src/`"*, so **a game with a
  differently-shaped protagonist had no legal way to get one.** T5.28's seam test asks one
  question — *does a seam exist?* — and a "default" a game cannot replace without editing `src/`
  is a RULE that has not admitted it. This is that, and it is the first thing the test caught.
  **THE COMPARISON RUN IS WHAT MAKES IT A DEFECT RATHER THAN A PREFERENCE**, and it is the same
  shape T5.25 through T5.27 each needed: set `[game] world/player_scene` to a scene that does not
  exist and boot. **Against the OLD code: `0 warnings, 0 errors`** — the key silently ignored, the
  player spawned from the const, a game's stated choice discarded without a word. **Against the
  new seam: `1 errors`, `Player scene missing or invalid at <the missing path>`**
  — named, on the existing `Log.error("boot", …)` path, rather than a silent empty world. The old
  run is the row: what was broken is not that the path was wrong but that setting it did nothing.
  **THE FALLBACK IS THE ONE ASYMMETRY AND IT IS DELIBERATE.** `world/first_area` has none, because
  a template nobody has put a game in yet legitimately starts in no area and `Director` reports
  that. A game can never legitimately have NO player, so an unset key means the template's own
  prefab rather than `load("")` and an empty world. `scenes/characters/` is Engine per
  `TEMPLATE.md`, so `GameConfig` naming that path is engine naming engine — not the boundary leak
  the `const` in `core` was. **`game_root.gd` DID NOT GROW**: 26 of its 60-line hard budget before
  and after, because the path moved and no logic did — that file's header says it "may only do
  four things" and this row added none of them. **TWO STALE COUNTS FELL OUT OF IT**, both the kind
  T5.25 spent a package on: `GameConfig`'s own header said it owned *"the four facts a game author
  writes once"* and `SYSTEMS_INVENTORY.md` said *"the four values a consuming game sets"* — five,
  now, and `NEW_GAME.md` § 2 gained the one exception to "keep and never edit", since a fork points
  PAST the template's prefab rather than editing it. `5.4.0`, a MINOR — the base gained something a
  game may ignore. Suite 2,294 → **2,300**, three assertions in `core_test.gd` and no new case.

- **T5.30 Performing the extension surface, which was the one consumer document never walked —
  DONE, 2026-09-10.** `SYSTEMS_INVENTORY.md` listed it beside `AUTHORING.md`, `ART_CONTRACT.md`
  and `TESTING.md` as consumer documentation, and it was the only one of the four never performed.
  **THE METHOD IS THE PROJECT'S OWN AND SO IS THE VENUE**: `UPGRADING.md` records that *"a
  stripped fork was made"* and that its synthetic versions *"exist only in the throwaway
  repositories this document was performed against"*, and `NEW_GAME.md` that *"the whole strip
  above was performed against a fresh clone"* — so a performance happens OUTSIDE the template and
  only findings come back. **No game code is committed here**, which also answers the question a
  draft of this row got wrong: it had proposed adding a `game/` root to the base and wiring it
  into the checkers' scan roots, which would have put a consuming game's proof inside the
  template. **SIX FINDINGS.** *(1)* **Three Tier 2 rows named a class and gave no path** while the
  `Events` row gave one, so `UiScreen` was hunted in `src/ui/root/` — where `UiRoot` lives and it
  does not — before a grep found `src/ui/screens/ui_screen.gd`. Every row now names its file.
  *(2)* **The three override hooks were described in prose and named nowhere**: a first attempt
  guessed `_on_shown()`, which compiles and never runs; they are `_build()`, `_opened()` and
  `_closed()`, now in the table. *(3)* **THE SHARPEST, AND IT WAS MEASURED RATHER THAN INFERRED:
  all seven checkers pass over a game code root.** A fork carrying three subclasses went green on
  every one, **including over a planted raw player-facing string literal and a planted public
  method with no caller** — precisely what `check_strings.gd` and `check_methods.gd` exist to
  catch. A consuming game inherits none of the ladder's discipline. **Two of those gates should
  stay blind and that is a relief rather than a gap** — `check_boundary.gd` exists to prove the
  ENGINE does not know the game, so aiming it at a game's own root would fail an author for doing
  the right thing — and the rest are now a stated choice instead of an unnoticed absence. *(4)*
  **No document had a row for game CODE**: `TEMPLATE.md`'s "What is what", `NEW_GAME.md` § 2 and
  `UPGRADING.md` § 5 each gained one, since Tier 2 tells a game to `extends Interactable` and
  nothing said where that file lives or what happens to it on a merge. *(5)* **A game's own input
  action cannot be player-rebindable**, and the constraint is deliberate: `KeyBindings.rebind()`
  gates on the `Actions.REBINDABLE` const rather than `InputMap.has_action`, and its header
  records that asking `has_action` was a real bug — `debug_console` could be written into
  `input.cfg` and `reset_bindings()` would not restore the default. So the closed list is the fix,
  and the consequence for a game is now stated rather than discovered. *(6)* **AND TWO AUDIT
  PREDICTIONS WERE WRONG, WHICH IS WHY PERFORMING BEATS PREDICTING.** The audit that scoped this
  row said a game's own screen could not register, because `ScreenKeys.menu_for()` is a closed
  `if`-chain over the eight template screens. It is — and it is irrelevant: `UiRoot.open()` takes
  an INSTANCE, `UiRoot.find(node)` finds the stack by group, so
  `UiRoot.find(self).open(MyScreen.new())` is the whole of it, and `menu_for`'s only caller is
  `dev_screens.gd`, which is boundary-exempt debug code. `5.4.1`, a PATCH; `src/`, `tools/`,
  `tests/` and `.github/` byte-identical.

- **T5.31 Clock and Weather on the flag surface — DONE, 2026-09-10.** `Clock` held the day, the
  hour and the phase, emitted `minute_passed`, `hour_passed`, `day_passed` and
  `day_phase_changed`, and **never once called `Flags.set_flag`**. `src/core/state/flag_query.gd`
  is the ONE evaluator both `DialogueNode` and `QuestStep` go through and it reads `Flags` and
  nothing else, so **no authored condition in the base could mention time or weather at all** —
  including the shop hours `clock.gd`'s own header names as a reason a clock is foundational. Two
  independent audits converged here and it was their only convergence. The seam needed no
  invention: `Flags.declare_derived` already existed, is idempotent, and `_collect_save` skips
  derived keys, so a published `time/hour` never reaches a save and recomputes from the clock's
  own saved state — the shape `inventory.gd:59` has run on since T3.3, including its two
  store-wipe subscriptions (`game_started` clears the flags and *then* emits; `game_loaded` fires
  after every section is applied, so the republish cannot depend on participant order).
  **THE UNPRICED COST WAS THE ROW, AND BOTH OFFERED ANSWERS WERE WRONG.** The plan said publish
  enum ordinals and state the coupling, or publish stable string names. Ordinals do couple —
  `GameEnums` is append-only because its numbers live in authored `.tscn` files — but the sharper
  objection is that **ordering on a phase is meaningless whatever the numbering**: measured,
  `phase_for_hour` across a day yields `6,6,6,6,6,0,0,1,1,1,1,2,2,2,3,3,3,4,4,4,5,5,5,5`, so
  `DEEP_NIGHT` is the highest ordinal and the earliest hours and `AT_LEAST DUSK` would hold at
  00:00 and fail at 06:00. **And a string name would have been unreadable by the one evaluator, which
  a throwaway probe measured rather than argued**: `FlagQuery.passes` against a flag holding
  `"DUSK"` returns FALSE for every test in the closed set, `EQUALS` and `IS_TRUE` alike, each
  logging `expected int` / `expected bool` — four flags that would have looked right in a dump and
  answered nothing. So the third answer: `time/hour` and `time/day` as ordered ints, where
  `AT_LEAST 9` with `AT_MOST 17` is a shop's hours and an ordering comparison means what an author
  expects; and a phase and a weather kind as **one bool under the name**, erased rather than set
  false so exactly one row exists — `Inventory` erases a spent stack rather than zeroing it, and
  an absent flag answers `IS_TRUE` false and `IS_FALSE` true, so the semantics are identical at a
  seventh of the rows. **No seventh comparison was added** to a set whose own file says it stays
  closed. **AND THE ROW SURFACED A DOCUMENTED GOTCHA AT THE ONE SITE NOBODY HAD FIXED**:
  `QuestTracker.ids_in_state` sorted with `Array[StringName].sort()`, which orders by interned
  handle rather than alphabetically — gotcha 33, with a note and a fix already in `area_db.gd`,
  `equipment.gd` and `inventory.gd`, and this function's own comment claiming *"sorted, so the
  journal draws a stable order"*. It was the allocator's order; four new flag names shifted the
  intern table and a journal assertion in `item_count_test.gd` went red on a code path this row
  never touched. Fixed with the same `sort_custom(_before)` the other three use, and the test's
  helper stopped reading "the last Label" and started addressing a named quest's own row. The
  plant is the required shape: publishing dropped from the `set_time` path only, exit 1 on
  two assertions, *"a jump onto the hour opens it"* and *"the flag was current inside that one
  too — expected 14, got 11"*, where the `11` is what the tick path had published — one path red,
  the other green. `5.5.0`, a MINOR: the base gained a seam a game may ignore. 2,302 →
  **2,331 assertions**, +29: 27 in the new case and 2 in `record_shape_test`, whose plan is
  `_docs.size() + _packages.size() * 2 + 2` so a new package id is worth exactly two. MEASURED by
  diffing every case against `main`, and the re-measure after the documentation landed is what
  caught the second pair — the first run read 2,329.
- **T5.32 A schedule could only describe one day — DONE, 2026-09-10.** The row the plan called
  **explicitly optional** — rated non-blocking, named *"the honest place to stop early if you
  want to"* — put to the owner as a live three-way choice and built in full on their answer.
  `ScheduleEntry` exported `from_hour` and nothing else, so an hour was an entry's whole address
  and `NpcSchedule.entry_for_hour(hour)` was the whole lookup: **every NPC in every game built on
  this base repeated one identical day, forever**, and a market day or any weekly rhythm was not
  badly supported but inexpressible. In scope only because of ADR-0007, whose seam test puts a
  cycle *length* on the template-default side — a formula, one modulo — and a *calendar* on the
  game-choice side, so the row adds `days_per_cycle` and adds **no weekday names, no months, no
  seasons and no date type**; the refusal is as much of the deliverable as the feature. It follows
  T5.31's seam verbatim, because that seam was built for this: `time/day_of_cycle` publishes like
  `time/day`, through `Flags.declare_derived` from `_publish_time()`, so it never reaches a save
  and recomputes from the clock's own state, and adding the key was one line there and nothing
  else. **An ORDERED int rather than the phase's bool-per-name, and the departure is stated rather
  than drifted into**: T5.31's argument is entirely about a phase and rests on two properties a
  day of the cycle lacks — no enum behind it, and no wrap inside its own range, which runs `1` to
  `days_per_cycle` and stops — so `EQUALS 3` is a market day, `AT_LEAST 5` is the back half, and
  the `AT_LEAST` assertion is one that could not be written at all under the phase's shape.
  **The default is what makes it a MINOR, and `-1` does the work twice**: on the field it means
  every day, so existing `.tres` need no edit; on the argument it means "no particular day", so an
  existing `entry_for_hour(hour)` call still answers — and deliberately not "any day", which would
  have leaked a day-specific block into every day. Two things had to change with the lookup and
  one was nearly missed: `problems()` keyed its duplicate check on the hour alone, so left as it
  was **`check_content.gd` would have failed the build on correctly authored data**, and `NpcBrain`
  now reads `Clock.day_of_cycle()` itself at both sites. A stated cost, being a layering
  consequence: nothing validates a day against the real cycle length, because `content` may not
  touch an autoload and `check_layers.gd` exists to refuse it reaching up into `systems`.
  **The plan's budget warning was wrong and measuring beat both remedies** — `clock.gd` was
  predicted to pass 150 and landed at **147**, so neither the split nor a justified budget was
  needed; the split was refused on evidence, since `phase_flag` is public *because* it is the
  spelling an author writes, which would have made the move a MAJOR. Plant: the day argument
  ignored in the lookup gave exit 1, `2346 passed, 4 failed` against a control of `2350 passed,
  0 failed` — three new assertions failing together and a fourth, *"the day's first hour switches
  over"*, a pre-existing assertion this row never touched catching the same regression
  independently. Gotcha 79 did not bite, which is a result: a new flag name was published and
  nothing in an untouched file went red, confirming T5.31's `QuestTracker.ids_in_state` fix was
  the last site, so the list stays at seventy-nine. `5.6.0`, a MINOR. 2,331 → **2,355
  assertions**, +24: 11 in `npc_test`, 8 in `time_flags_test`, 2 in `record_shape_test` and **3 in
  `doc_counts_test`, which the row did not see coming** — that case makes a claim of every line
  outside the list that mentions a gotcha and spells a number, so this row's own prose about
  gotcha 79 became three assertions about itself, all three passing. Measured by diffing every case
  against `main` after the documentation landed; the pre-docs run read 2,350 and a predicted +21
  would have been wrong by three. **This is the last planned row, and no chip was created because there is nothing to hand
  off to**: every row on the board is DONE and the base is complete.
- **T5.33 The audit of a base declared finished — DONE, 2026-09-10.** T5.32 closed the board and
  declared the base complete; the owner then asked for a full check before starting a game on it,
  and **the check found that the row declaring the base finished had made a documented invariant
  violable.** `schedule_entry.gd` has always promised a day is always completely covered, "because
  an NPC is always somewhere", and before T5.32 that was STRUCTURALLY true — every entry applied on
  every day, so `entry_for_hour`'s wrap-to-the-last-block fallback could never come up empty.
  `on_day_of_cycle` made it violable by authored data and nothing noticed: not `problems()`, not
  `check_content`, not one of 2,355 assertions. Measured with a throwaway probe rather than argued —
  a schedule of only day-specific entries answers nothing on any day it does not name, **24 hours of
  24**, while `problems()` returned 0, so the build passed on content that strands an NPC and
  `NpcBrain.decide_for_hour`, returning early on null, left it standing wherever it was. The fix is
  one rule at exactly the strength this layer supports: at least one entry at `-1`, which is
  necessary AND sufficient for total coverage, the stronger "every day of the cycle is covered"
  needing `Clock.days_per_cycle` that `content` may not reach for. Plant — the check disabled —
  exit 1 on one assertion, `expected 1, got 0`, against an exit-0 control, with the
  consequence assertion deliberately staying green because the gap exists whether or not the
  validator reports it. **PATCH on three cited precedents** (`5.3.3`, `5.3.2`, `1.0.2`), the last
  stating the reason: *"That is the bug being fixed, not a new restriction."* **Three documentation
  numbers were also wrong**, and one carried a checklist defect: `TESTING.md` stated the suite as
  `2302` / `2226`, stale through TWO consecutive rows because closing item 5 was being read as two
  files when the suite size lives in four — and the stale pair even disagreed with the board's own
  stripped gap of 74, its difference being 76. Item 5 now enumerates all four and says the stripped
  number comes from the CI job log, so the step finishes after CI. `NEW_GAME.md`'s "all 930
  assertions" had the number deleted rather than updated, the better fix for a count no reader
  needs; and T5.32's claim that `clock.gd`'s three spare lines were the tightest in the base was
  wrong twice — `director.gd` has three at 187 of 190, `dev_stage.gd` had two at 248 of 250 before
  T5.20 split it. **What the audit confirmed is recorded too, a clean result being evidence**: zero
  table column mismatches across every live document, after a naive sweep produced four hits that
  were all false positives; and "Ten autoloads", "seven checkers", "eight template screens" and
  `AUTHORING.md`'s per-area figures all correct against the code. 2,355 → **2,362 assertions**, +7,
  five in `npc_test` and two in `record_shape_test` for this row's own board id, the pre-docs run
  having read 2,360; the plan guard caught an off-by-one on the way, reporting `planned 85 outcomes
  and produced 84` with every assertion passing.

## Phase T6 — Player-facing robustness · **COMPLETE, 2026-09-30** (planned 2026-09-26; every exit criterion met 2026-09-29; closed by T6.14)

*Goal: close every item on `SYSTEMS_INVENTORY.md`'s "Commonly forgotten" list as DONE or CLOSED
(game's), fix the one save defect a multi-version formula cannot ship with, and put in place the two
structural seams every shipped game needs and would otherwise retrofit expensively — the active
input device, and text that renders in any script.*

**Why this phase exists, and why it is not scope creep.** T1 to T5 are complete and stay complete.
The owner opened this phase on 2026-09-26 with one question: *this base will be the formula for many
games — what belongs in it that we missed?* The answer was filtered rather than brainstormed.
ADR-0007 decides what a template DEFAULT is; the refused list rules out cutscenes, an economy, a
chapter sequencer, a calendar, combat, credits and the rest; and the project's own standing rule is
that work is found, not invented. What survived is one confirmed defect plus the items of the
"Commonly forgotten" list — a list that says of itself it was written *"so they are decisions rather
than oversights"* — that are still neither done nor decided. See T6.0 below for how each candidate
was classified, including the ones refused.

- **T6.0 Planning the phase — DONE, 2026-09-26.** Three parallel explorations (what exists, what the
  owner already refused or deferred, a presence check across thirty-six capabilities a general HD-2D
  base usually needs) and an adversarial review, with every load-bearing claim then re-read in the
  code. **The review overturned three first premises, which is the argument for running one**: the
  shader warm-up proposed as missing was built in T2.0 (`Director.WARM_UP_FRAMES`); per-section save
  versions proposed as never exercised are exercised (`core_test.gd:134`); and the F2 freecam called
  unbound is bound and merely unconsumed. **It found one real defect by reading**, now T6.1. The owner
  decided three things: T6 only; photo mode, a codex, in-area camera zones and positional ambient
  emitters are GAME CHOICES; and font fallback proves both Bengali and CJK. Stale records fixed on
  the way.
- **T6.1 A save from a newer build must be refused, not applied — DONE, 2026-09-28, `5.6.3`.**
  Proved red on `5.6.2` first — a section stored at v3 for a probe registered at v2 reached its
  applier, `expected unset, got from the future` — then `load_from_slot` gained the section-level
  twin of `_migrate`'s newer-build refusal. The suite's first worked migration (`old_key` →
  `new_key` from v1) lives in `save_recovery_test.gd`, and `UPGRADING.md` § 4 points games at it.
- **T6.2 The base knows which input device is active — DONE, 2026-09-28, `5.7.0`.** The pure
  `InputDevice.device_for(event, previous)` decides — mouse motion and sub-deadzone stick drift are
  not a switch — and `Actions` holds the answer, emitting `input_device_changed` only on a change;
  no autoload was added. The interact prompt names the button (`[E]  Barter  …`) and the dialogue
  hint follows the device mid-conversation, which also fixed it: it had said "Space to continue"
  and Space advanced nothing. Hotplug is proved by calling the handler, since no pad exists headless.
- **T6.3 A reusable confirm screen, and "are you sure" on overwriting a save — DONE, 2026-09-29,
  `5.8.0`.** `ConfirmScreen.asking(question_key, detail, on_yes)` is a `MenuScreen` that cancel and
  pause cannot answer, with focus on No. Pressing an occupied slot on the save screen asks first
  and names the header about to be lost; an empty slot saves at once. The quit half of forgotten
  #7 was already answered by T5.10's quit-autosave and is recorded, not built. Photographed.
- **T6.4 A save slot says where it was saved, and says so when it is damaged — DONE, 2026-09-29,
  `5.9.0`.** `SaveSystem.header_provider` is an optional hook `WorldMap` sets, so `core` never
  asks `Director`. The header carries the area id, and the row names the place, localized when
  drawn. A file the loader would refuse, including one that parses but is from a newer build,
  reads DAMAGED rather than empty. It cannot be loaded from the list and never becomes Continue,
  and it counts as occupied, so overwriting it asks first. Closes forgotten #15. Photographed.
- **T6.5 Losing window focus leaves nothing latched — DONE, 2026-09-29, `5.10.0`.** Measured
  first: the engine already releases held keys on focus loss. So the base releases only its own
  latches, a toggled run, a hold in progress and a rebind capture, on `Events.focus_lost` from
  `UiRoot`. `gameplay/pause_on_focus_loss`, off by default, opens the pause menu. The first
  windowed run found the menu recorded and never drawn, because the engine propagates the
  notification. Gotcha 80. Closes forgotten #3. Photographed.
- **T6.6 Text in any script renders, not as tofu — DONE, 2026-09-29, `5.11.0`.** Noto Sans
  Bengali and a Noto Sans SC subset, both at weight 600 to match the engine's Latin, in a
  fallback chain `UiRoot` installs into the project theme. The theme names no font, because it
  loads before the first import and a fresh clone printed `Parse Error` (gotcha 81). Windows
  system fonts had hidden the tofu, so the before capture turned system fallback off. Photographed:
  the ক্ষ conjunct and the hanzi and kana shaped, and the suite asserts ক্ষ is ONE glyph. The `tr_n`
  check found one count needing a plural form, RestPoint's hours, which is T6.14.
- **T6.9 Running the suite destroyed the developer's real saves — DONE, 2026-09-29, `5.11.1`** (claimed `5.9.1`; renumbered at the merge).
  An owner-reported defect, taken ahead of T6.5 and numbered after T6.8 so no planned id moves.
  Fourteen cases wrote or deleted slots in the real `user://saves`, and a green run deleted all
  seven planted sentinel saves. Each case now calls `SaveFixture.activate()` first, and all seven
  survive. Test-only. No exit criterion covers a defect fix, so none is ticked.
- **T6.10 A capture or debug launch wrote over the developer's real saves — DONE, 2026-09-29,
  `5.12.0`** (claimed `5.10.0`). Found while proving T6.9. A `--new-game` capture is a real run, so the autosave wrote
  the real slot, and three probes deleted real slots. `DevSaves` points any debug launch with user
  arguments at `user://dev_saves` (`--real-saves` opts out), and a planted sentinel survives the
  capture. No exit criterion covers a defect fix, so none is ticked.
- **T6.11 A debug launch, and every suite run, wrote the developer's real settings — DONE,
  2026-09-29, `5.13.0`** (claimed `5.11.0`). Found by T6.10. A `--locale=` capture rewrote the real
  `settings.cfg`, and a green suite left it at zero bytes. `Settings.file_path` is where `save()`
  writes; `DevSaves` and the test runner point it at scratch, writes only, and a planted sentinel
  survives both. No exit criterion covers a defect fix, so none is ticked.
- **T6.12 Nothing failed a case that saved without activating the scratch store — DONE,
  2026-09-29, `5.13.1`.** The gap T6.9 recorded. The runner parks the store in a scratch
  directory before every case and fails a case that saves, or loads a real file, while parked.
  Three cases with `activate()` removed went red, and seven sentinel saves survived every run.
  Test-only. No exit criterion covers a defect fix, so none is ticked.
- **T6.7 Dialogue for fast and slow readers — DONE, 2026-09-29, `5.14.0`.** Cancel during a
  conversation skips: the screen walks the runner through `advance()`, so every node passed fires
  its effect, and it stops at the first choice. `gameplay/dialogue_auto_advance`, off by default,
  moves a whole line on after a hold and never answers a choice. Photographed. Closes forgotten #5.
- **T6.13 Two suite runs at once, in two worktrees, broke each other — DONE, 2026-09-29,
  `5.15.0`** (claimed `5.12.0`). Found by T6.11. Every worktree shares one `user://`, and the
  suite's scratch paths were fixed names under it that `SaveFixture` empties. Every path now lives
  under `user://test_runs/<pid>`, pruned by heartbeat; two suites 0.3s apart failed 15 and 8
  before and pass now. At the merge T6.12's parking directory, a fixed name `park()` emptied before
  every case, moved under it too. It also stopped the suite deleting the real `input.cfg`. No exit
  criterion covers a defect fix, so none is ticked.
- **T6.8 Close the list, and gate it — DONE, 2026-09-29, `5.15.1`.** The phase's exit criterion.
  Every one of the fifteen "Commonly forgotten" items now carries `DONE — <id>` or
  `CLOSED (game's) — <id>`, and `forgotten_list_test.gd` fails an item without one, an id with no
  board row, and a gap in the numbering. Before the edits it failed 16, two for each of eight items;
  after, 32 of 32. #8, first-run defaults, is CLOSED (game's); the owner, asked for a playtest
  verdict on 2026-09-30, has not playtested yet, and the closure stands until they do. **Every exit criterion is now ticked; the phase
  stays OPEN for T6.14, a defect found inside it.**
- **T6.14 A count that reaches a string picks its plural form — DONE, 2026-09-30, `5.16.0`.**
  Found by T6.6, which numbered it T6.10. `RestPoint` sent `{hours}` into one key, so a short rest
  read "1 hours" or "0 hours". 4.7.2's CSV importer reads plural forms (a `?plural` column, the next
  form on a row with an empty key), so `.po` was not needed; `RestPoint` asks `translate_plural`
  and reports the nearest hour, never zero. Red first with 8 failed, photographed after. No exit
  criterion covers a defect fix, so none is ticked. **The last row: Phase T6 is COMPLETE.**
- **T6.15 A wandering NPC never picks a spot it cannot walk to — DONE, 2026-10-16, `5.16.2`.**
  A defect found after the phase closed, by the first windowed capture a cloud session ran, and
  numbered here so that no closed row moves. A random wander offset could land on a riser or in the
  eroded strip beside it, and `NpcBrain` logged an ERROR for a destination nobody authored. The
  offset now goes through `NpcBrain.reachable_point()`, the end of a real path. Red first, 5 of 7
  failed; 10 windowed runs after, 0 errors. No exit criterion covers a defect fix.

**Exit criteria for the phase:**

- [x] A save section written by a newer build is refused with defaults loaded, and the suite holds
  one worked, exercised migration a game can copy. — T6.1
- [x] The base knows the last-used input device, and the interaction prompt shows the right key for
  it. — T6.2
- [x] Overwriting an occupied save slot asks first, through a confirm screen a game can reuse. — T6.3
- [x] A save slot shows where it was saved, and a damaged slot is shown as damaged. — T6.4
- [x] Losing window focus leaves no base-owned input latched, and pausing on it is a setting. — T6.5
- [x] A Bengali string and a CJK string both render through the theme's fallback chain,
  photographed. — T6.6
- [x] Dialogue can be skipped to its end and can auto-advance. — T6.7
- [x] Every "Commonly forgotten" item is marked DONE or CLOSED (game's) with a package id, and a
  text-scan assertion fails if one is not. — T6.8

## Phase T7 — Playtest and harden · **OPEN, 2026-10-29**

*Goal: the owner plays the base through a script that covers every player-facing system, and
every finding is fixed or closed with a reason. Nothing is planned beyond the script, because a
phase that fixes what playing finds cannot list its rows in advance.*

- **T7.0 A script for the owner's playtest — DONE, 2026-10-29, `5.16.3`.** `docs/PLAYTEST.md`:
  - eleven sections, from the first run to the debug tools;
  - each step is "do this, expect that", using only names the demo ships;
  - steps that need a human's judgement are marked *(feel)*, and the rest can be photographed
    from a cloud session;
  - #8's first-run question is asked before settings are opened;
  - findings are reported in one shape, and each becomes a `T7.n` row.
- **T7.1 CI's actions off the deprecated Node 20 — DONE, 2026-10-29, `5.16.4`.** Found by the
  combat fork's CI, not the playtest: every job warned that `checkout`, `cache` and
  `upload-artifact` at `@v4` target Node 20. Moved to `checkout@v5`, `cache@v5`,
  `upload-artifact@v6`. CI only.
- **T7.2 A save can be refused, not only fail — DONE, 2026-10-31, `5.17.0`.** Found from the
  combat fork. `SaveSystem.blockers` lets a game name a moment when saving would record a broken
  world.
  - While a blocker answers with a reason key, every save is refused (`ERR_UNAVAILABLE`), and the
    autosave skips.
  - The save screen says why.
  - Loading is never refused.

**Exit criteria for the phase:**

- [ ] The owner has played through `PLAYTEST.md`, and every finding is a row that is DONE, or is
  CLOSED with a reason.
- [ ] #8, first-run defaults, has the owner's verdict.

## Sequencing rules

1. **Breadth of systems, one shallow proof each.** This *replaces* "depth before breadth", which
   is retracted — see [`TEMPLATE.md`](TEMPLATE.md). It was the right rule for one game and the
   wrong one for a formula library.
2. **No content without a system.** If an area needs a feature that does not exist, build the
   feature or cut the area. Do not special-case it. *(Unchanged, still correct.)*
3. **No file under `src/` may name demo content.** The boundary that had no rule until T1.2.
4. **A system is proved by a fixture, demonstrated by the demo.** An assertion that names
   `item/rose_key` is testing the demo, not the item system.
5. **Nothing is done until the engine says so.** Every completion claim cites a command that was
   run and its result. *(Unchanged. This is the project's spine.)*
6. **Every session appends to `DEVLOG.md`.** What changed, why, how it connects, what was verified.
7. **Art stays deferred, permanently.** The template ships a *contract* art must satisfy, never
   art. Each game brings its own.
