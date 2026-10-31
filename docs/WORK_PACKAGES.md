# Work Packages

**One package, one chat.** A chat context window is the binding constraint on this project, so
work is sliced into packages that each fit in one. Every package names the exact files to read,
so a new session loads a few hundred lines instead of three thousand.

Read `CLAUDE.md` and `docs/CONTEXT.md` first — always, about a minute — then find your package
below and **read its manifest and nothing else.**

## The rules

**Size.** No package exceeds roughly **8 files or 500 new code lines**. Over that, split it and
add a row. Same reasoning as the file budgets: a package that grows past one chat becomes a
package that gets half-finished.

**Serial, not parallel. ONE PACKAGE IS IN FLIGHT AT A TIME, AND PHASE T6 IS WHY.** T6.9 to T6.13
ran as five chats in five worktrees at once. Every one of them had to merge `main` back in before
it could land, some three times; four rows were renumbered at their merge and T6.14 four times
over; `5.10.0` to `5.12.0` were each claimed by one row and shipped by another; T6.6, T6.7, T6.8
and T6.13 each ended up with two or three chats for the same package; and **T6.13 exists only
because two suites in two worktrees emptied each other's saves** — every worktree shares one
`user://`. Parallel packages cost more than they saved, every time. So:

- **Before starting, check.** `gh pr list --state open` and `git worktree list`. If another
  package's PR is open, or its worktree is unmerged, **stop and tell the owner** — do not start
  alongside it, and do not start a second chat for a package that already has one.
- **Build from `origin/main`, fetched now.** The row id and the version bump are decided then,
  against what `main` actually holds — never claimed ahead of a merge, so there is nothing to
  renumber.
- **A defect found mid-package becomes a `TODO` row on this board, not a chip.** It is picked up
  after the current package merges. The only exception is the owner saying, in the chat, to run
  it now.

**Closing a package.** Not done until all of this is true:

1. Ladder green — `--import` with **zero `SCRIPT ERROR` / `Parse Error` lines** (gotcha 22: the
   boot rung's `0 warnings, 0 errors` does not see them), boot `0 warnings, 0 errors`, tests
   pass, `check_budgets` exits 0, `check_content` exits 0, `check_boundary` exits 0.
2. New behaviour covered by assertions in `tests/unit/`, and a deliberately broken assertion
   still exits 1.
3. `SYSTEMS_INVENTORY.md` statuses and `ROADMAP.md` criteria updated.
4. `DEVLOG.md` appended — did / why / connects / verified / unblocks / gaps.
5. `CONTEXT.md` updated — counts, new settled decisions, new gotchas, next package.
   **AND EVERY OTHER PLACE THAT STATES THE SUITE SIZE, WHICH IS FOUR FILES AND NOT TWO.** This
   step used to be read as `CLAUDE.md` and `docs/ARCHITECTURE.md`, and T5.31 and T5.32 both did
   exactly that and both left `docs/TESTING.md` stating `2302` / `2226` — the file a newcomer
   reads to learn the suite. Nothing gates these, so the list is the gate:
   - `CLAUDE.md` — the runner command's trailing comment
   - `docs/ARCHITECTURE.md` — the rung 4 row of the ladder table
   - `docs/TESTING.md` — **both** numbers in the opening section, full checkout *and stripped*
   - `docs/CONTEXT.md` — the headline's `Suite N → M` line

   The stripped number can only come from the CI job log, so this step finishes *after* CI, not
   before. And if a document states a count that carries no weight, delete the number instead of
   updating it — T5.33 did that to `NEW_GAME.md`'s "all 930 assertions", which no reader needed.
6. This file marks the package `DONE`, and its detail section ends with a `**Commit:**` line.
   **THE SHA CANNOT BE IN IT WHEN YOU WRITE IT, AND FIVE ROWS RUNNING PROVED THAT RATHER THAN
   FORGOT IT.** This step asks for a commit that satisfying this step creates. So write the line
   with the branch and the PR and no SHA, and **fill in the SHA in the NEXT row** — T5.26 filled
   T5.25's, T5.27's was filled by T5.28, and so on. That is not a lapse to apologise for each
   time; it is the only order that exists. The alternative, a second commit per package purely to
   amend the line, buys nothing a reader wants.
7. Committed, pushed, CI green, and **the PR merged into `main`**. Not "pushed and waiting":
   the next package builds on this one, so it cannot start until this one is in `main`.
8. **Then, and only then, the chip for the next package is created** — once, by this chat, and
   its prompt names the `origin/main` SHA it builds from. If the board has no next row, no chip.
   A chip raised before the merge is how Phase T6 got three chats for one package. If no chip ever
   arrives, nothing is lost: this file's row for the next package IS the fallback handoff, and
   `docs/CONTEXT.md` opens with the branch map saying which tip to build from. Use the
   spawn-task mechanism with a self-contained prompt: it must name the start-here docs, the
   goal, the files to write, the exit criteria, and what is deferred - everything a session
   with no memory of this one needs. WP-01 chip is the worked example; copy its shape.
9. **The worktree goes.** After the merge this chat's session is archived, which removes its
   worktree, and the next chat's first `git worktree list` should show `main` and nothing else.
   A merged worktree left behind is where the next accidental parallel chat starts.

**Anything with a visual consequence needs a windowed capture and an actual look at the PNG.**
Headless shades nothing. This project has already shipped two bugs that every other gate passed.

## Board

| # | Package | Status |
|---|---|---|
| 01 | Triggers and traversal | **DONE** — see below |
| 02 | UI foundation | **DONE** — see below |
| 03 | HUD and inventory screen | **DONE** — see below |
| 04 | Second area, transitions, loading | **DONE** — see below |
| 05 | Dialogue | **DONE** — see below |
| 06 | NPCs and navigation | **DONE** — see below |
| 07 | Path actions | **DONE** — see below |
| 08 | Quests | **DONE** — `a00ddda`, PR #16. The first package of Phase T3; see below |
| 09 | Character depth — equipment | **DONE (split)** — `1b3d799`, PR #17. The equipment third; see below. The row asked for three systems, which is over the size limit |
| 09b | Character depth — attributes and surfaces | **DONE** — `da126d9`, PR #19. The fourth package of Phase T3; see below |
| 10 | Crafting and gathering | **OPTIONAL** — a genre choice, not a requirement of every game (TEMPLATE.md). Does not block v1.0 |
| 11 | World map and fast travel | **DONE** — `cf3f3a1`, PR #18. The third package of Phase T3, and the last system with no proof at all; see below |
| 12 | Menus | **DONE** — taken out of order; it needed only WP-02 |
| 13 | Presentation | **DONE** — taken out of order; see below |
| 14 | Dev tools and hardening — **the hardening half** | **DONE (split)** — `975ff4b`, PR #23. The eighth package of Phase T3; see below. The row named four things, which is over the size limit, so its own title was the seam. Its smoke-test wording was RE-FRAMED in the same commit, because "drives the whole demo" would have welded the demo into a permanent gate |
| 14b | Dev tools — debug console and performance overlay | **DONE** — `22e0046`, PR #24. The NINTH package of Phase T3 and the row that CLOSES the phase; see below. The four commands became ONE implementation both the command line and the console call, which is also what made room in `dev_stage.gd` — it was at exactly 250/250 |
| 15 | Release engineering | **CLOSED, 2026-09-02, by the owner** — the export proof was template work and shipped as **T2.0**; credits and the accessibility pass belong to a consuming game and will not be built here. Closed the way WP-10 is OPTIONAL: recorded, not deleted. See below |

### The template phases, added 2026-08-26

Read [`TEMPLATE.md`](TEMPLATE.md) first. These are NOT numbered WP-nn because they cut across the
original board rather than continuing it.

| # | Package | Status |
|---|---|---|
| T1.1 | Integration — every package onto `main` | **DONE** — PR #10 |
| T1.2 | Engine/demo boundary: the rule, a gate, and the leaks fixed | **DONE** — see T1.2 below |
| T1.3 | Test fixtures + framework hardening | **DONE** — see T1.3 below |
| T1.4 | CI — automate the ladder | **DONE** — see T1.4 below |
| T2.0 | **The export proof** | **DONE** — the assumption HELD; see T2.0 below |
| T2.1 | Art contract seams | **DONE** — see T2.1 below |
| T2.2 | Consumer documentation | **DONE** — `36b5abd`, PR #15. Phase T2 closes; see T2.2 below |
| T3.1 | **A generic content registry** — one scan, with a thin typed façade per catalogue | **DONE** — `767fbe3`, PR #20. The fifth package of Phase T3; see below. The refactor PAID, and not in the shape WP-08 costed: the duplication was in the SCAN, not the cache, so the base went on the RESOURCE |
| T3.2 | The five art-contract seams T2.1 left | **DONE** — the seventh package of Phase T3 and the last of its T-numbered rows, though the phase itself stays open on WP-14; see below. Four seams built and one refused in writing, and the point of the row is as much that they stop being mentioned in five documents as that four of them exist |
| T4.1 | **Template v1.0 — the version, and the upgrade note** | **DONE** — `799d957`, PR #25. The first package of Phase T4. The version is `[template] base/version`, NOT `application/config/version`, and the reason is the whole package in one line: a fork resets its own version on day one, so that field stops recording which base the game came from. `docs/UPGRADING.md` was PERFORMED against a real stripped fork and found a template defect nobody would have reasoned their way to; see below |
| T4.2 | **A second worked example, authored from `AUTHORING.md` alone** | **DONE** — the second package of Phase T4, and T2.2's mechanism applied to CONTENT. Five defects, two of them in the TEMPLATE rather than the prose: `check_boundary` matched SUBSTRINGS, so an item called `pear` collided with the word `appeared` and failed a gate its author could not fix; and `--stand-by` always resolved in the DEPARTURE area, so no object in an authored area could be photographed. Both gotcha 44's shape — found only by authoring content this repository does not have; see below |
| T4.3 | **`NEW_GAME.md` performed as a fork, and the release tag** | **DONE** — the last package of Phase T4, which it CLOSES. Landed the 26-PR stack on `main` as one 71-commit chain and tagged `v1.0.0` with the owner's authorisation, then performed `NEW_GAME.md` from a fresh clone. Two defects, one in the TEMPLATE: `core_test.gd` asserted an empty `first_area` was illegal when four other statements call it legal, so a fork had a red rung 4 before authoring its first area; and the prune list never learned about `quest.`, so a fork shipped this template's demo quest strings with every gate green. Bumped to `1.0.1`; see below |
| T4.4 | **`TESTING.md` performed, the last document never walked** | **DONE** — five for five: every document performed has found a defect reading would not, and this is the third of the five where the defect was in the TEMPLATE. The test runner SKIPPED A LISTED CASE THAT DID NOT PARSE, in silence, for the life of the suite — `load()` returns a non-null uninstantiable `GDScript`, `script.new()` then raises a runtime error, and that aborts only `_run_case`, so the loop moved on and the suite reported `1608 passed, 0 failed` and exit 0 with a whole case never run. `error_watch.gd` had counted the error the whole time and nothing asked it. Also: the document's ONE worked example did not compile, and three documents gave three different gotcha counts. Bumped to `1.0.2`; see below |
| T5.1 | **The skeleton's four open exit criteria, closed by proving them** | **DONE** — asked whether the base was actually finished, `ROADMAP.md` said no: **Phase 1 read COMPLETE with three unticked exit criteria and Phase 2 read IN PROGRESS with one.** All four proved rather than ticked, and **one was a missing FEATURE** — `Settings` stored a locale, the options screen cycled one, and nothing anywhere called `TranslationServer.set_locale`, with only one locale column in the CSV so there was nothing to switch to. Also: the eight-direction facing mapping had no assertions (21 now, camera-yaw independent), the save criterion needed TWO PROCESSES, and the 30-second session had never been run. Bumped to `1.1.0`; see below |
| T5.2 | **An animation block per GAIT** | **DONE** — the first row of Phase T5, and the owner's reframing made concrete: a future game should inherit working characters and change only assets. `SpriteSheetLayout.animation_for` took a **boolean**, so a sheet could hold an idle cycle and a walk cycle and nothing else — run and sneak replayed the walk block faster — while `GameEnums.MoveState` had ten values and `Events.player_state_changed` was declared, emitted and **listened to by nothing.** Sixth instance of declared-validated-and-read-by-nothing. Now a `MoveState`, with `run_row`/`sneak_row`/`climb_row` defaulting to -1 = "replay the walk block" so no existing sheet changes behaviour. Bumped to `1.2.0`; see below |
| T5.3 | **Delivering the gaits that were already declared** | **DONE** — a full-base audit found the **seventh** instance of declared-validated-and-read-by-nothing, and **T5.2 one row above had created it**: `MoveState.CLIMB` never reached `CharacterVisual`, because `_physics_process` returns early while a climb owns the body and `climb_step` touched the visual only after resetting to IDLE. `climb_row` was exported, validated and asserted, and **undrawable** — a ticked exit criterion that was false, invisible in the demo because the shipped sheet leaves it at -1. Second defect in the same function: `_frame` was pinned to 0 whenever horizontal speed was zero, so **no idle block had ever advanced a cell** while "more than one idle" sat on the criteria. Both fixed, both proved by planting the revert (`1688 passed, 6 failed`, exit 1 → `1694 passed, 0 failed`). **Gotcha 54: a unit test at each end of a seam proves nothing about the wire between them.** See below |
| T5.4 | **The three missing enforcement gates** | **DONE** — the T5.3 audit found the structural cause rather than another instance: **no gate anywhere asked whether a declared thing has a CONSUMER**, which is why the same defect arrived through a fully green ladder seven times. `check_signals.gd` requires every registry signal to have an emitter and resolves indirect `Signal`-value dispatch, so the three quest signals — **zero** direct `.emit` sites — are not false positives; it named `debug_command` at once. `check_layers.gd` enforces `core -> content -> systems -> gameplay -> ui` and **found a real violation on its first run: 55 upward references**, 13 of them the interaction sensor sitting in `systems/` while typed on `Interactable`. Moved to `src/gameplay/interaction/` — **gotcha 55: a rule with no gate is a rule already being broken.** `check_boundary.gd` gained the `localization/` half and closed gotcha 48. Every gate planted red and proved green. Four checkers to six; see below |
| T5.5 | **The twelve settings with no consumer** | **DONE** — 12 of 23 settings were declared, drawn to the player, translated in both languages and read by nothing. **Nine wired**, each placed by who owns the thing that has to change: the viewport and the shadow ATLAS to `Settings` itself, bloom to `EnvironmentDriver`, DOF to `HD2DCameraRig` (**`set_dof_enabled()`'s first ever caller**), the prompt's two to `InteractPrompt`, the typewriter's to `DialogueScreen`, the hold floor to `InteractionSensor`, and `accessibility/text_scale` to a new `UiAccessibility`. **Three REMOVED** — screen shake, autosave and subtitles have no machinery here to reach, and a row drawn to the player that cannot do anything is worse than a dead constant. **Five of the twelve were a TEMPLATE defect**: a fork could not wire `accessibility/*` without editing `src/`. Plus the four one-liners — `reset_to_defaults()` never re-applied the locale, `Actions.JUMP` is gone, `rebind()` gates on `REBINDABLE`. **The seventh gate was deliberately not built**: the consumer question is an ASSERTION, because `Settings.DEFAULTS` is a runtime fact. Writing it found **gotcha 56: a text search for a wire stays green after the wire is cut.** Eight plants each exit 1; six settings photographed in pairs. 1,782 assertions (stripped 1,708, so all 64 survive the strip); version 2.0.0. CI green, PR #34. See below |
| T5.6 | **A wholesale character swap, photographed** | **DONE** — Phase T5's last unmet exit criterion, and the only one of the three that was a proof rather than a feature. The repository held a sheet with a different GRID (`character_alt.png`, 4 facings, 24×40, two blocks) and a sheet with GAITS (the default, 8 facings, 32×48, three blocks) and **never one with both**, so the phase's claim had only ever been demonstrated in halves. The alt sheet is now five blocks — idle, walk, run, sneak, climb, 96×600 — and its layout is **the only one in the project that leaves no gait at -1**. The player was pointed at the pair, driven through all five gaits through the real input path, and photographed; **no file under `src/` changed for the swap**, which is the claim the row exists to test, and the swap is two `ExtResource` paths in `player.tscn`. **The CONTROL is the strongest evidence**: the same probe on the DEFAULT sheet draws blocks 0, 1, 2, **1, 1** — sneak and climb falling back to the walk block, which is the `-1` contract measured in the live game for the first time rather than in an assertion. Four defects, three of them this row's own and all four invisible to any rung that does not open a window — **gotchas 57 to 60**: a generator that clips to the image draws into the next cell; a foot-anchored sprite's bottom rows are eaten by the ground plane so a tally there cannot be read; reading `sprite.frame` before the post-draw await measures a different moment from the photograph; and `unproject_position` answers in the viewport's LOGICAL size. Two plants, each exit 1, and **plant 2 re-created T5.3's defect exactly** (`climb_row = -1` → `expected [2, 3, 4], got [2, 3, -1]`), which makes good the row's own claim that this sheet would have caught it. New `character_swap_test.gd` (14) and `dev_gait_shots.gd`. 1,798 assertions; version 2.1.0. See below |
| T5.7 | **`reduce_motion` finished, plus the shadow atlas** | **DONE** — candidate I, both halves already diagnosed by T5.5 and deliberately skipped by T5.6. `accessibility/reduce_motion` now reaches **all three** motions this template draws: `ScreenFade` cuts instead of dissolving and `HD2DCameraRig.follow_lag` goes to zero, each naming the key as a `const` on itself and each taking `_authored_dof`'s **veto** shape — the setting may remove smoothing an area author authored and may never add smoothing they refused. **The shadow half was a LIVE DEFECT, not the portability worry it was filed as.** `_apply_shadows` restored `const POSITIONAL_ATLAS: int = 2048` under a comment calling 2048 "the engine's own default"; **it is 4096**, so this repository booted every windowed session at half the shadow resolution the project authored — measured `boot = 2048` against `boot = 4096` on a real display server, before a player touches anything. New `ShadowAtlas` in `core` reads the authored sizes before the first zeroing (a const cannot be right there at all, because the number is a project setting a game is invited to change), and `settings.gd` came DOWN to 139 of its 150. That is **gotcha 61**, and its transferable half is that `_apply_display()` returns early under `--headless`, so **no rung below the windowed capture executes that code** — the suite could not have caught it however many assertions were aimed at the setting. **AND THE CAMERA MOTION WAS PHOTOGRAPHABLE, WHICH THIS ROW PREDICTED IT WOULD NOT BE**: T5.5's honest limit (an instant reveal photographs identically to a finished one) holds for the fade and fails for the camera, because a camera following a moving character has no finished state — two `--gait-shots` runs differing by one line of `settings.cfg` translate the whole world **42 px**, residual 0.0268 at −42 px against 0.0975 at zero, so it is a rigid shift and not a lighting change. Four plants, each exit 1, one of them re-proving **gotcha 56** on a second node. `settings_consumers_test.gd` hit 269/250 and split; `settings_effects_test.gd` is the new half, divided by QUESTION — *is the key reached* against *does the effect happen*. 1,798 → 1,821 assertions. See below |
| T5.16 | **Quest chaining — a correctness defect, and the stack landed first** | **DONE** — `4.2.1`, and OFF THIS PHASE'S THEME ON PURPOSE: a correctness bug in the base does not wait for a thematic slot. Found by auditing the base rather than by a rung. `QuestTracker.evaluate()` guarded re-entrancy by RETURNING, discarding the re-derivation a listener on `quest_completed` legitimately asked for — **the case the guard's own comment names** — so a quest whose start condition another quest writes started or silently did not according to `ContentScan` insertion order, which is not sorted. Eight rungs and 2,051 assertions were green over it because the demo has ONE quest, so it cannot chain, and `quests_test.gd` drives `evaluate()` directly by design while a re-entrant call can only arrive on `flag_changed`. Fixed with a pending bit drained by the outer pass, bound by `QuestDb.count() + 2`. **The plant fails exactly 1 of 8, and the 1 is the adversarial order** — which is what proves the two order blocks are not the same test. Gotcha 72. **Also landed the 16-PR T5 stack on `main` as one fast-forward (`16e8bfd`) and turned on branch protection**; see below
| T5.17 | **Reconciling the record with what the gates now do** | **DONE** — no version bump and no code changed, so the tree stayed at `4.2.1`. Six documentation defects from the same audit that produced T5.16, every one of them prose disagreeing with shipped behaviour: `CONTEXT.md` still listing the `Button` styleboxes as unbuilt three hundred lines below its own header announcing T5.15 built them; `quest.` missing from the CANONICAL prefix table while `NEW_GAME.md` alone carried it; `keys.*` named as an engine prefix in three documents with ZERO rows in the CSV — gotcha 48 in the other direction; the `OPTIONAL` status `TEMPLATE.md` promised on 2026-08-26 and never delivered, now carried by `Harvestables`; `AUTHORING.md`'s gate table explaining three of seven checkers in the document a consumer authors from; and the gotcha count. **Its own recorded gap set the next row's shape** — *"Nothing gates a prose claim, and nothing can"*, five of the six being invisible to `docs_test.gd` **Commit:** `2be54a4` on `claude/t5-17-record-reconcile`, PR #46, targeting `main`. |
| T5.18 | **The save loader's refusals, and a path nothing can enter** | **DONE** — `4.3.0`, and **`save_system.gd` is BYTE-IDENTICAL**: this row is assertions plus one corrected claim. `core_test.gd` owned the round trip and covered ONE refusal; a grep for `ERR_FILE_CORRUPT` across `tests/` returned nothing, so six branches were carried by review alone. The distinction now pinned is a policy rather than a detail: **a corrupt ENVELOPE is refused outright, a corrupt SECTION is skipped and the rest loads** — the difference between a player losing a setting and a player losing forty hours. **And `_migrate`'s success path is UNREACHABLE by arithmetic**: it runs only when `version != 1`, then refuses `<= 0` and `> 1`, and no integer is all three of not-one, above-zero and at-most-one — so `SYSTEMS_INVENTORY.md` calling migration DONE meant *written*, not *exercised*, which is the eighth appearance of declared-and-not-reached and the first where the unreached thing is a control-flow path. The case **PINS `SCHEMA_VERSION`**, so shipping v2 fails the suite and names what to write. **Planted in BOTH directions** — the newer-build guard removed fails 2 of 17, a bad section made fatal fails 1 at `expected 0, got 16`, the opposite sign, which is what proves the two are not confused. Also took `v2.0.0`, `v3.0.0`, `v4.0.0` and `v4.2.1`, each verified against T4.3's condition that a tag name a tree declaring its own version; see below |
| T5.19 | **Reconciling the record, and gating its shape** | **DONE** — `4.3.1`, a PATCH, and no production code changed. **Twelve places where the record disagreed with the repository, one package after T5.17 reconciled it.** `CONTEXT.md` — the file `CLAUDE.md` sends every session to FIRST — stated template version `2.4.0` two majors late, called the version `1.1.0` untagged, still listed branch protection as unbuilt after T5.16 turned it on, and carried a **"THE NEXT PACKAGE"** paragraph describing work T5.2 had shipped. `ARCHITECTURE.md` was 348 assertions behind and named "rung 9" for a capture that is rung 12. `SYSTEMS_INVENTORY.md` had T5.15's `Row styles` row at LINE 1, above the title — its ONLY copy, so the system was missing from its table. T5.17 had no board row. **The answer was not a third manual reconcile.** Two defects are STRUCTURE, which is assertable where prose is not: `record_shape_test.gd` fails if a document does not open with its title or a recorded package has no board row, and `version_test.gd` gained a third fact — a **bold** semver in `CONTEXT.md` must equal `project.godot`'s. 2,076 → 2,143. Three plants, each the real reversion, each exit 1 against an exit-0 control. **Gotcha 70 again:** plant 3 passed first time because `sed` addressed the wrong line and changed nothing **Commit:** `ef29717` on `claude/t5-19-record-gate`, PR #48, targeting `main`. |
| T5.20 | **Splitting the staging surface, and the gate that makes a split safe** | **DONE** — `5.0.0`, a MAJOR, and the production change is a MOVE: `dev_stage.gd` was at **248 of its 250** allowed code lines, two from failing rung 5 on its next edit. **The docs had named `gen_placeholders.gd` next to split for ten straight rows and it was the wrong file** — at 230 of 250 it has twenty lines spare, and T5.19's measurement is what found the real one. **The seam was chosen by QUESTION, on this family's own three-way precedent** rather than by cutting the file in half: the five flags that end in a `UiRoot.open()` — `--open-inventory`, `--talk=`, `--talk-advance=`, `--open-menu=`, `--console=` — moved to a sixth file, `dev_screens.gd`, leaving *what is TRUE in the world* here and *what is DRAWN OVER it* there. **It is also a dependency fact**, which is what makes it a seam and not a filing preference: those five were the only staging that named the `ui` layer at all. 248 → **175**, new file **102**, and `_parse_arguments` fell from 32 of its 40-line function budget to 22. **MAJOR rather than the MINOR its 3.1.0 precedent used**, because a game that merges `src/` without adding the `DevScreens` node does not miss a new feature — it silently LOSES five flags it may already invoke, with nothing red anywhere. **A refactor, so the evidence is that behaviour did not change**: five invocations byte-identical before and after, including both cross-file orderings, plus a sixth pair proving the `_fresh_game` pre-pass equivalent on reverse-order arguments. **The new gate is the split's own failure mode**: no two debug nodes may dispatch the same flag, `--new-game` the one stated exception — planted red at `expected ["--new-game"], got ["--new-game", "--open-menu="]`. Removed an orphaned doc block describing a function deleted in an earlier split. 2,143 → 2,148 **Commit:** `ddad201` on `claude/t5-20-dev-stage-split`, PR #49 into T5.19's branch, reaching `main` with PR #51 from `land/t5-20-dev-stage-split`. |
| T5.21 | **A scene-level interaction test, and the defect it found** | **DONE** — `5.1.0`, a MINOR. THE ROW EXISTED BECAUSE ANOTHER FILE ASKED FOR IT IN WRITING: `interaction_test.gd`'s MUST NOT line has said since WP-02 that the sensor's ranking *"needs real geometry and belongs in a scene-level test"*, and that test was never written — so the decision the sensor's own header calls the actual problem it solves (*"detection is trivial; selection is not"*) was asserted nowhere in a suite of 2,148, and `Speaker` and `Readable`, two of the eleven prefabs `AUTHORING.md` tells a consumer to place, had no scene-level assertions at all. Gotcha 54's shape at the top of the interaction stack: `interaction_test.gd` proved what an object does once chosen, `turn_test.gd` proved the turn once it is, and between them sat the decision neither made. `tests/unit/selection_test.gd`, 24 assertions. **AND IT FOUND A REAL DEFECT ON ITS FIRST RUN — gotcha 73**: `_select()` broke a scoring tie with `a.name < b.name`, but `Node.name` is a `StringName` and `<` on two of those compares their INTERNED ADDRESSES, not their text, so ties were ordered by script and scene load order while the comment above the line promised the NAME. Measured both ways in one run, same pair: `StringName` said `Z_later < A_earlier`, `String` said the opposite. The comment was half true, which is why it survived eight rungs — an address does not move, so the order WAS stable within a run; it simply was never the name, so an author numbering two overlapping objects to choose between them was ignored. One cast fixes it. **The first probe of the comparison said the language was innocent and agreed by coincidence**, which is gotcha 70 turned around and is the second half of 73. `InteractionSensor` gained one public method, `cycle()`, because the suite provably cannot press a key — `Input.parse_input_event` is buffered until a main-loop flush that never comes mid-run, and `Input.action_press` lands but then leaves the action reading `is_action_just_pressed() == true` for the whole run, which would cycle every other case's sensor; same reasoning as `is_suspended()`, and the binding is still proved windowed by `dev_stage.gd --cycle`. **Five plants, each failing a DIFFERENT set** — tie-break reverted 3, priority term deleted 1, facing term 1, cycle offset ignored 4, lone-candidate guard 1 — which is what says they are not one assertion five times. 2,148 → **2,173 assertions**; see below
| T5.22 | **A redirectable `SAVE_DIR`** | **DONE** — `5.2.0`, a MINOR, and a consuming game does nothing: `SaveSystem.SAVE_DIR` became the settable `save_dir`, but all six uses were inside `save_system.gd`. **THE SUITE WAS WRITING INTO THE DEVELOPER'S OWN SAVE DIRECTORY AND IT WAS THE LAST ROOT THAT COULD.** `fixtures.gd` repoints five content roots; the store was the sixth and the only one left out, because its directory was a `const` — so `save_recovery_test.gd`, the case whose whole purpose is writing MALFORMED save files, and `core_test.gd`'s round trip both wrote real slots. **They cleaned up after themselves, which is not the same as never having been there**: the run that fails to clean up is the run that crashed, and a slot number the suite picks is a slot number a player may have filled. `tests/framework/save_fixture.gd` points the store at `user://test_saves` with `activate()` / `deactivate()` / `is_active()` on `Fixtures`' shape, and `test_runner.gd` deactivates after EVERY case rather than only the ones that switched — that file's own discipline and its reason verbatim. **PUBLIC rather than test-only**, because a portable build writing beside its executable wants the same seam and a backdoor existing for the suite alone is what `fixtures.gd`'s header refuses to add. 166 → 172 of the 180 override, which is where the row's "genuinely small" claim was checked before it was started rather than after. **AND THE FIRST VERSION OF THE LOAD-BEARING CASE PASSED THE PLANT — gotcha 74**: it compared the untouched file byte-for-byte against a copy taken before the redirected write, and the full reversion passed, because both writes landed on the same path in the same second and the only varying fields are second-resolution `saved_utc` and tenth-snapped `playtime_seconds`. Distinguishable markers fixed it; the same plant now fails 4. **Two plants, each a different set** — the full reversion 4, the runner's unconditional deactivate removed 3, which is what says they are not one assertion twice. 2,173 → **2,192 assertions**; see below |
| T5.23 | **A second idle block and a chooser** | **DONE** — `5.3.0`, a MINOR, and a consuming game does nothing unless it wants a fidget: both new fields default to the value that means "no second idle". **THE LAST PHASE T5 EXIT CRITERION**, open since the phase was written and reworded once by T5.3. **THE GAP WAS NEVER THE BLOCK** — `SpriteSheetLayout` could address 32 animations and `frame_index` could draw any of them since T2.1, so a sheet could always CARRY a second idle; what was missing is that every block in this template is chosen by a `GameEnums.MoveState`, and standing still is one state, so nothing would ever ask for one. A character therefore stood in exactly one way forever. **So the row is a CHOOSER, and the chooser is dwell time with its threshold on the SHEET**: `idle_break_row` names the block, `idle_break_after` says how many seconds of unbroken standing start it, the block plays ONCE and hands back to `idle_row`, and the clock restarts from the END of the break so the authored number is the gap a player actually sees. **DWELL RATHER THAN WEATHER, A SCHEDULE OR AN AREA TAG**, and the argument is the two MUST NOT lines rather than taste: each of the other three needs an autoload (`Weather`, `Clock`, `Flags`) that `sprite_sheet_layout.gd` may not touch, and that `character_visual.gd` may not reach from the other side, it being TOLD a velocity and a state. Dwell is the one trigger derivable from what the visual is ALREADY handed every frame — the only one of the four needing no new dependency anywhere — and nothing is lost, since a game wanting a rain idle pushes a MoveState or swaps the layout resource. `problems()` gained three branches, each gotcha 38's shape: a row with no delay, a delay with no row, and a break pointing at the idle block it is meant to interrupt. **THE WINDOWED CAPTURE RETURNED NUMBERS RATHER THAN A JUDGEMENT.** A new `--idle-shots=<dir>` pass presses NOTHING — the whole input is standing still — and it WATCHES instead of aiming a frame number, because the moment of interest is set by a threshold on the sheet the probe must not know (gotcha 52) and because one shot cannot show that the break STARTED and ENDED. Blocks seen over eight seconds: `0x12, 3x8, 0x18, 3x8, 0x2` — the break running 1.33s, which is 4 cells at 3fps exactly, and the gap between two breaks **3.0s, the authored number, measured from the END of the previous one**, which confirms the restart decision independently of the suite. Crops: the idle block's own cycle moves 0.0949, the break's own cycle 0.1406, and the two BLOCKS **0.6184** — four to six times either, which is what separates a second idle from a recolour with a wobble. **AND THE PLANTS FOUND A HOLE IN THE NEW TEST ITSELF — gotcha 75**: "interrupted standing does not accumulate" PASSED under the very defect it was written for, because the wrongly-started break had already FINISHED inside the same stand, so the case read the idle block and agreed by coincidence — gotcha 70's family, one row after T5.22 met it, and the fix is timing rather than logic. **Seven plants, seven DIFFERENT failure sets** — break never starts 4, break loops 2, moving does not cancel 2, dwell reset at the START rather than the end 2, fallback to row 0 instead of the idle block 1, `has_idle_break` dropping its delay half 1, the three half-configured problems unreported 3 — which is what says they are not one assertion seven times. `tests/unit/idle_break_test.gd`, 26 assertions. 2,192 -> **2,221**, and the delta is **+26 +2 +1** rather than one number: 26 are `idle_break_test.gd`'s own plan; 2 belong to `docs_test.gd`, whose plan is `paths + fields + 2` and which now asserts that `idle_break_row` and `idle_break_after` exist on the class, because they were added to `ART_CONTRACT.md`'s worked example; and 1 belongs to `record_shape_test.gd`, whose plan is `docs + packages + 2` and which gains one package from this entry's own DEVLOG heading. `version_test.gd`'s plan is `28 + <bold semvers in CONTEXT.md>` and is UNCHANGED at 30, both semvers having been rewritten in place rather than added to; see below **Commit:** `24a84dd` on `claude/t5-23-second-idle`, PR #54, targeting `main`. |
| T5.24 | **The roadmap's missing run, and whether completeness should be gated** | **DONE** — `5.3.1`, a PATCH, and a consuming game does nothing to its own code: `src/` and `tools/` are byte-identical. **THE ROW WAS TWO THINGS AND THE SECOND IS THE ONE THAT MATTERED.** `ROADMAP.md`'s package log recorded T5.15 and jumped to T5.21, with nothing for T5.16, T5.17, T5.18, T5.19 or T5.20 — five delivered packages, each with a DEVLOG entry and a board row, absent from the roadmap. T5.21 recorded the gap, T5.23 recorded it again and promoted it to the top of the next-package list without closing it, and **nothing was red because nothing counted the rows.** Writing five entries is bookkeeping; the question worth answering was whether roadmap completeness should be GATED the way `record_shape_test.gd` already gates two other structural facts. **IT SHOULD, AND T5.19 IS THE PRECEDENT RATHER THAN THE ANALOGY**: that row exists precisely because a third manual reconcile was the wrong answer, and its argument — a file either opens with its title or it does not, a package either has a row or it does not, neither question has a reading or a tone — transfers to "a package the DEVLOG records has no entry in `ROADMAP.md`" without a word changed. Same file's business, same MUST NOT line, no new case needed. **THE COUNTER-ARGUMENT WAS REAL AND IS ANSWERED BY THE SHAPE OF THE CHECK, NOT WAVED AWAY.** The roadmap's package log IS legitimately selective in a way the board is not — it records a package in whichever of three shapes fits: a log row under a phase, a tick beside an exit criterion, or a parenthesis in a phase's Done list. **T5.14 is only ever the second of those**, so a gate demanding a package-log row would have failed a package that is thoroughly recorded. So the check is `roadmap.contains(id)`, FINDABILITY — which is the identical choice T5.19 made one function above for the board, and for the identical reason it wrote down: "findable" is the property that matters and a stricter rule would fail eight packages that are genuinely recorded. **AND T5.16 HAD DECLINED TO TOUCH THE ROADMAP IN WRITING**, on the grounds that "no exit criterion covers a defect fix, and inventing one to have something to tick would be the ticking-without-proving this project spent T5.1 undoing". That is right about the CRITERIA list and says nothing about the package LOG, which is a different list in the same file answering a different question — and separating the two is what makes this assertable rather than a matter of editorial taste. **THE PLANT IS THE LIVE REPOSITORY, WHICH IS THE STRONGEST FORM AVAILABLE.** The assertion was written first and run before a single doc was edited: exit 1, six named failures, `FAIL T5.16 is findable in the roadmap — expected true, got false` and five more. Nothing was fabricated to make it fail, so gotcha 74's and gotcha 75's family — a plant that passes, or fails for the wrong reason — cannot apply to the red run; the questions that remained were whether it fails for one reason per package and whether it goes green for the right reason, and both were measured. **AND IT FOUND A SIXTH PACKAGE THE ROW HAD NOT NAMED: WP-07**, path actions, the signature non-combat mechanic, missing from the roadmap since 2026-08-26 and named by neither T5.21's nor T5.23's recording of this gap. **That is the whole argument for the gate over a third reconcile, delivered as a measurement rather than as a prediction**: two manual passes had looked at this and counted five. `record_shape_test.gd` 68 → 121 assertions, and every one of the 53 is a computed plan doing its job rather than a case this row wrote. 2,221 → **2,274 assertions**; see below |
| T5.25 | **The gate that could not fail, and the numbers nothing was measuring** | **DONE** — `5.3.2`, a PATCH, and `src/` and `tools/` are byte-identical. **THE GATE T5.24 SHIPPED ONE ROW EARLIER COULD NOT FAIL FOR FOUR OF THE IDS IT WAS CHECKING.** Findability was `roadmap.contains(id)` and `board.contains(id)`, and `contains` cannot tell an id from a PREFIX of a longer one: `T5.1` is a substring of T5.10 through T5.19, `T5.2` of T5.20 through T5.24, `WP-09` of `WP-09b`, `WP-14` of `WP-14b`. Delete every genuine trace of those four packages and the suite stays green, because a sibling's own row spells the prefix. **WORTH SEPARATING FROM GOTCHA 76 RATHER THAN FILED UNDER IT**: 76 is that a mention may be incidental, which is a judgement about whether a trace counts; this is that the assertion was reading a DIFFERENT STRING, which is not a judgement — and the four ids affected are the four *oldest* in each family, the ones whose disappearance a reader is least likely to notice. One word boundary per call site, the dot escaped because an unescaped one matches any character and would let `T5x1` satisfy `T5.1` — the same defect mirrored. **THE LIVE REPOSITORY IS NOT THE PLANT THIS TIME, AND THAT IS THE POINT.** Measured before the change was written: all 52 packages satisfy the word-boundary form in both files, so the tree is green either way and T5.24's strongest-available plant — the repository itself — does not exist for this defect. So the proof is three runs against one plant, T5.2's seven genuine roadmap traces renamed away: tightened gate, no plant, **green 2,274**; tightened gate, plant, **red exit 1, ONE failure, `FAIL T5.2 is findable in the roadmap — expected true, got false`**; original `contains()` gate, SAME plant, **green 2,274**. The third run is the one that carries the row — without it the change is untested by construction, since runs one and two alone are also consistent with a gate that was already working. **AND THE SECOND HALF WAS THE RECORD, RECONCILED AGAINST MEASUREMENT RATHER THAN AGAINST ITSELF** — the failure mode T5.17 and T5.19 both hit by re-reading the documents instead of running the engine. Six documents quoted totals nothing had re-measured: `README.md` **555 assertions** against 2,274, stale since before `2.0.0`; `CLAUDE.md` "over 5,400 lines" against 8,986 and `2,173` in its own runner command; `TESTING.md` 1625/1551; `ARCHITECTURE.md` 2,173; `CONTEXT.md` a census of 166 files / 15,552 code lines taken before T5.23 added a file. **AND TWO SELF-CONTRADICTIONS IN THE FILE `CLAUDE.md` SENDS EVERY SESSION TO FIRST** — "the base is 5.0.0-complete" nine lines above declaring **5.3.1**, and Phase T5's second-idle criterion "still stands open" fourteen lines above "Phase T5 has no unticked exit criterion". `version_test.gd` missed the first because it reads only BOLD semvers and `5.0.0-complete` is unbolded, which is the same ungated-shape lesson as T5.19's. **The nine `**Commit:**` lines are written and deliberately NOT gated**, and the reason is a measurement rather than a preference: 15 of 52 packages had one, so the gate would fail 37 historical rows, and scoping it to "T5.16 onward" is the rotting exception list `HEADING_PATTERN`'s header refuses to become. `CONVENTIONS.md` gained the branch-naming rule the project never wrote down. 2,274 → **2,276 assertions**, both of them this row's own DEVLOG heading passing through a computed plan; see below |
| T5.26 | **The ladder's own gate could not see an unwired checker** | **DONE** — `5.3.3`, a PATCH, one test file, and `src/` / `tools/` / `.github/` byte-identical. **`gates_test.gd`'s HEADER STATES ITS PURPOSE AS CATCHING "A GATE WRITTEN, COMMITTED, AND NEVER WIRED" AND IT COULD CATCH NEITHER SHAPE OF THAT.** `LADDER` was a const naming seven checkers with nothing asserting it named ALL of them, so an eighth `tools/check_*.gd` was invisible to the one case whose whole subject is a gate nobody runs — the defect being its own blind spot. And the wiring assertion was `workflow.contains(checker)`, **true of a workflow that names the checker in a COMMENT**, which this one does for every checker on purpose, the comments carrying each rung's reasoning. **MEASURED RATHER THAN ARGUED: both `run:` lines for `check_signals` commented out left the suite GREEN at 2,276** — running in neither job, ladder's own gate reporting fine. That is the comparison run and the row's whole evidence, the three-run shape T5.25 needed for the same reason: the tightened assertions are green on the live tree, so A and B alone cannot tell a fix from a no-op. **AND THE THING `contains` COULD NOT EXPRESS AT ALL IS THE COUNT BEING PER-JOB** — one bool for a whole file cannot say a checker is wired into the full job and missing from the stripped one, which is half a ladder, and the stripped half is the one that proves the template stands with no game present. So INVOCATIONS are counted — a non-comment line carrying the path and `--script` — against `JOBS.size()`, with the job names asserted so the number is not a fiction, which is `dev_tools_test.gd`'s empty-extractor guard applied to a const. The list is now derived from `tools/`, the pattern `test_runner.gd` has used for `CASES` since T2.2 and on `check_boundary.gd`'s argument that a list of what to check rots. **The plan is computed** — `42 + JOBS.size() + LADDER.size() * 2 + on_disk.size()` — so wiring an eighth checker never means editing a number. **Three plants, three different failures, exactly one each**: both steps commented `expected 2, got 0`; stripped step alone removed `expected 2, got 1`; eighth checker unlisted `expected true, got false`, on a run whose total rose by one unaided. **Gotcha 78**, not filed under 77 — 77 is a substring matching a sibling ID, this is a substring unable to tell a step from a comment; same mistake, second document, one row apart, so the generalisation is recorded rather than the instance: when a gate reads a FILE, ask which parts are prose. 2,276 → **2,287 assertions**; see below |
| T5.27 | **A checker can skip a file and still print PASS** | **DONE** — `5.3.4`, a PATCH, `src/` byte-identical; the change is `ladder.yml` and six of the seven tools. **RUNGS 5–11 READ ONLY THE EXIT CODE** while rung 4 has `ErrorWatch`, and the question was whether that gap hides anything. **It does, and a throwaway probe measured it rather than arguing it**: a loop of three calling a function that indexes an empty array on the second printed `SCRIPT ERROR: Out of bounds get index '9'`, then `loop finished, items processed: 2 of 3`, then `PASS`, **exit 0**. Gotcha 24 exactly — the error aborts the INNERMOST FRAME ONLY, the loop finishes, a file is silently unscanned, and the tool reports success. **AND THE FIRST PLANT DID NOT SHOW IT**: the same error injected into `check_layers._scan_script` gave exit 1, so the tool died rather than lying and the premise looked false — the minimal probe is what separated "dies" from "continues and reports PASS", which is gotcha 75's family and why the probe is in the record. All fourteen steps now capture a log, print it, and force failure on `SCRIPT ERROR`/`Parse Error` even at exit 0; seven logs uploaded from both jobs; each step still names its checker beside `--script` once per job, so T5.26's invocation gate is untouched. **SECOND, SIX CHECKERS COULD PASS ON A SCAN OF NOTHING** — 0 of 7 guarded it while all seven printed their scanned count. `check_layers` aimed at a script-free directory gave `scripts scanned: 0` then `PASS`, exit 0; guarded it fails, and **the comparison against the unmodified tool on the same empty scan is the row** rather than the guard's own green run. The rule was already written for doc gates at `4.3.1` — "worse than no gate" — and never turned on the tools; the count lives beside each collector's `append` so it cannot drift from the scan. **`check_content` IS EXEMPT AND THE EXEMPTION IS THE INTERESTING PART**: its whole input is `data/` and `scenes/areas`, which the stripped job DELETES by design, so a zero scan is legitimate there and nowhere else — the first exemption in this run derived from what the strip removes rather than from what a gate can judge. **THIRD, A COMMENT CLAIMED A CHECK NOTHING PERFORMED** — "a stripped template must report exactly the same numbers", twice, with the jobs independent and nothing comparing them; reworded to what is enforced (both exit 0, which catches the failure that matters) and the real cross-job comparison named as a candidate. 167 files, 15,852 code lines. 2,287 → **2,291 assertions**, both from this row's own DEVLOG heading through a computed plan — **the enforcement here is not in the suite at all**, the first time that is true in this run; see below |
| T5.28 | **A template rule, a template default and a game choice are three different things** | **DONE** — `5.3.5`, a PATCH, and `src/` / `tools/` / `.github/` byte-identical. **THE ROW RANKED FIRST FIVE TIMES AND NEVER TAKEN.** `TEMPLATE.md` § *"The one constraint nobody has scoped"* has said since 2026-08-26 that *"what is missing is the distinction between a template default and a game choice, which no document currently draws"*, and nothing ever scheduled it. `CONTEXT.md` deferred it each time for one honest reason — *"it is prose and cannot be proved by running the engine"* — **while also recording that it "DECIDES the two rows under it rather than guessing"**, both of which carried *"Scope depends on the taxonomy row above"*. **So deferring the cheap row kept the expensive ones frozen**, and three candidate rows were unscopable indefinitely for want of one distinction. **THE ANSWER IS THREE KINDS, NOT TWO**, which is what made it tractable: a TEMPLATE RULE is foreclosed for every game and carries a checker where the rule is mechanical; a TEMPLATE DEFAULT ships a working value **and a seam**; a GAME CHOICE means the base builds nothing and offers only the seam and the facts. **AND THE TEST THAT SEPARATES A DEFAULT FROM A RULE IS MECHANICAL RATHER THAN EDITORIAL — DOES A SEAM EXIST?** A "default" a game cannot replace without editing `src/` is a rule that has not admitted it; "is this a default or a rule" was a matter of tone, "can a game replace it without editing src/" is a fact about the repository. It is immediately productive: applied to `game_root.gd:28`'s `const PLAYER_SCENE` it says the player prefab is a **rule pretending to be a default**, which is the next row. **APPLIED RATHER THAN DESCRIBED** — RULES: no combat, the layer rule, the demo-name boundary (the last two already have checkers, which is what a rule looks like mechanised). DEFAULT: time, because `Clock`, `NpcSchedule` and `Weather` are already here so a cycle extends a present system. GAME CHOICES: a chapter sequencer, since a `story/chapter` int flag with `AT_LEAST` is already a complete chapter model through the one `FlagQuery` and a `Chapter` resource would add a second way to say one thing; and an economy, genre rather than structure, on `Harvestables`' footing. **TWO CANDIDATE ROWS CLOSED BY A REFUSAL RATHER THAN BUILT**, and writing the refusal down is the point — otherwise each is rediscovered, ranked, deferred for want of a reason, and ranked again, which is what happened three times. **AND THE CUTSCENES ROW NEEDED A REASON, NOT A PACKAGE**: a draft of this row proposed building the staging seam because nine `cutscene` mentions across eight files under `src/` looked like unpaid IOUs, and **read in full every one is a RECEIPT** — *"deletes nothing here — it calls `Audio.duck()` from its own occasion"*, *"forced by a cutscene, without touching this file"*, *"a cutscene can later ask for the same fade"* — each a statement that the file is already cutscene-ready and the game supplies the occasion. Reading a comment as a debt is how a comment becomes a work package. **Also settled: `Fixtures.activate()` is ASSERTED, not skipped**, reversing `TESTING.md`, because a skip reports GREEN so the one condition the check exists to catch is the one nobody sees — T5.27's failure one row earlier; `bag_mirror_test.gd` converted and **the plan gate caught the arithmetic before the suite did**, `planned 10 outcomes and produced 11`. **NO NEW GATE, AND SAYING SO IS PART OF THE ROW** — `record_shape_test.gd` and `docs_test.gd` already cover an ADR, and inventing one to have one is what the previous four rows were about; see below |
| T5.29 | **The player prefab was a rule pretending to be a default** | **DONE** — `5.4.0`, a MINOR: the base gained a seam a game may ignore. **ADR-0007 FOUND THIS WITHIN AN HOUR OF EXISTING, WHICH IS THE ROW'S BEST ARGUMENT FOR ITSELF.** `game_root.gd:28` held `const PLAYER_SCENE := "res://scenes/characters/player.tscn"` — engine code, in the **core** layer, naming the prefab a consuming game replaces FIRST — while `GameConfig` exposed exactly two `[game]` keys with no `player_scene` among them. `ARCHITECTURE.md` states the contract as "a game adds content and resources; it does not add code under `src/`", so **a game with a differently-shaped protagonist had no legal way to get one.** T5.28's seam test asks one question — *does a seam exist?* — and a "default" a game cannot replace without editing `src/` is a RULE that has not admitted it; this is the first thing the test caught, and finding it an hour after writing the ADR is the strongest evidence the distinction was worth a package. **THE COMPARISON RUN IS WHAT MAKES IT A DEFECT RATHER THAN A PREFERENCE**, the same shape T5.25–T5.27 each needed: `[game] world/player_scene` pointed at a scene that does not exist, then boot. **Old code: `0 warnings, 0 errors`** — the key silently ignored, the player spawned from the const, a game's stated choice discarded without a word. **New seam: `1 errors`, `Player scene missing or invalid at <the missing path>`** on the existing `Log.error("boot", …)` path. **The old run is the row**: what was broken was not a wrong path but that setting it did nothing — the plant alone only shows the error path works. **THE FALLBACK IS THE ONE ASYMMETRY AND IT IS DELIBERATE**: `world/first_area` has none, because a template nobody has put a game in yet legitimately starts in no area, but a game can never legitimately have NO player, so an unset key means the template's own prefab rather than `load("")` and an empty world. `scenes/characters/` is Engine per `TEMPLATE.md`, so `GameConfig` naming that path is engine naming engine — not the boundary leak the `const` in `core` was. **`game_root.gd` DID NOT GROW** — 26 of its 60-line hard budget before and after, a path moved and no logic added, which matters because that file's header records the previous project's equivalent reaching 3,983 lines. **TWO STALE COUNTS FELL OUT OF IT**, neither gated and both T5.25's class: `GameConfig`'s header said it owned "the four facts a game author writes once" and `SYSTEMS_INVENTORY.md` said "the four values a consuming game sets" — five now. And **`NEW_GAME.md` § 2 gained the one exception to "Keep, and never edit to start a game"**, because a fork points PAST the template's prefab rather than editing it, which is the instruction that section already gave and could not previously be obeyed. 2,294 → **2,300 assertions**, three in `core_test.gd` and no new case; see below |
| T5.30 | **Performing the extension surface, the one consumer document never walked** | **DONE** — `5.4.1`, a PATCH, and `src/` / `tools/` / `tests/` / `.github/` byte-identical with **no game code committed**. `SYSTEMS_INVENTORY.md` listed the extension surface beside `AUTHORING.md`, `ART_CONTRACT.md` and `TESTING.md`, and it was the only one of the four never performed — while each of the other three found defects reading had not. **THE VENUE IS THE METHOD, AND A DRAFT OF THIS ROW GOT IT WRONG**: `UPGRADING.md` records that "a stripped fork was made" and its synthetic versions "exist only in the throwaway repositories this document was performed against", `NEW_GAME.md` that "the whole strip above was performed against a fresh clone" — so a performance happens OUTSIDE the template and only findings come back. The draft had proposed adding a `game/` root to the base and wiring it into the checkers' scan roots, which would have committed a consuming game's proof into the template. **SIX FINDINGS.** *(1)* Three Tier 2 rows named a class and gave no path while the `Events` row gave one, so `UiScreen` was hunted in `src/ui/root/` — where `UiRoot` lives and it does not — before a grep found `src/ui/screens/ui_screen.gd`; every row now names its file. *(2)* The three override hooks were described in prose and named nowhere: a first attempt guessed `_on_shown()`, **which compiles and never runs**; they are `_build()`, `_opened()`, `_closed()`. *(3)* **THE SHARPEST, AND MEASURED RATHER THAN INFERRED: all seven checkers pass over a game code root** — a fork carrying three subclasses went green on every one, **including over a planted raw player-facing literal and a planted uncalled public method**, precisely what `check_strings.gd` and `check_methods.gd` exist to catch. A consuming game inherits none of the ladder's discipline. **Two of those gates should stay blind and that is a relief rather than a gap** — `check_boundary.gd` exists to prove the ENGINE does not know the game, so aiming it at a game's own root would fail an author for doing the right thing — and the other five are now a stated choice instead of an unnoticed absence. *(4)* **No document had a row for game CODE**, though Tier 2 tells a game to `extends Interactable`: `TEMPLATE.md`, `NEW_GAME.md` § 2 and `UPGRADING.md` § 5 each gained one. *(5)* **A game's own input action cannot be player-rebindable**, and the constraint is CORRECT rather than an oversight: `KeyBindings.rebind()` gates on the `Actions.REBINDABLE` const rather than `InputMap.has_action`, and its header records that asking `has_action` was a real bug — `debug_console` could be written into `input.cfg` and `reset_bindings()` would not restore the default. Stated now rather than discovered. *(6)* **TWO AUDIT PREDICTIONS WERE WRONG, WHICH IS THE ARGUMENT FOR PERFORMING OVER PREDICTING**: the audit said a game's own screen could not register because `ScreenKeys.menu_for()` is a closed `if`-chain, and it is — and it is irrelevant, since `UiRoot.open()` takes an INSTANCE and `UiRoot.find(node)` finds the stack by group, so `UiRoot.find(self).open(MyScreen.new())` is the whole of it, and `menu_for`'s only caller is boundary-exempt debug code. **Also fixed the closing checklist at the source**: item 6 asked for a commit that satisfying item 6 creates, which five rows running had worked around by filling in the previous row's SHA; it now says to do exactly that; see below |
| T5.31 | **Clock and Weather on the flag surface** | **DONE** — `5.5.0`, a MINOR: the base gained a seam a game may ignore. **`Clock` HELD THE DAY, THE HOUR AND THE PHASE, EMITTED FOUR SIGNALS, AND NEVER ONCE CALLED `Flags.set_flag`** — while `src/core/state/flag_query.gd` is the ONE evaluator both `DialogueNode` and `QuestStep` go through and it reads `Flags` and nothing else. So **no authored condition in this template could mention time or weather at all**, including the shop hours `clock.gd`'s own header names as a reason a clock is foundational. Two independent audits converged here and it was their only convergence. The seam needed no invention: `Flags.declare_derived` already existed, is idempotent, and `_collect_save` SKIPS derived keys, so a published `time/hour` never reaches a save and recomputes from the clock's own saved state — `inventory.gd:59`'s shape since T3.3, including both of its store-wipe subscriptions, because `start_new_game` clears the flags and THEN emits while `game_loaded` fires after every section so the republish cannot depend on participant order. **THE UNPRICED COST WAS THE ROW, AND BOTH ANSWERS THE PLAN OFFERED WERE WRONG.** Ordinals do couple — `GameEnums` is append-only because its numbers live in authored `.tscn` files — but the sharper objection is that **ordering on a phase is meaningless whatever the numbering**: measured, `phase_for_hour` across a day yields `6,6,6,6,6,0,0,1,1,1,1,2,2,2,3,3,3,4,4,4,5,5,5,5`, so DEEP_NIGHT is the HIGHEST ordinal and the EARLIEST hours and `AT_LEAST DUSK` would hold at 00:00 and fail at 06:00. **AND A STRING NAME WOULD HAVE BEEN UNREADABLE BY THE ONE EVALUATOR, WHICH A THROWAWAY PROBE MEASURED RATHER THAN ARGUED**: `FlagQuery.passes` against a flag holding `"DUSK"` returns FALSE for every test in the closed set, `EQUALS` and `IS_TRUE` alike, each logging `expected int` / `expected bool` — four flags that would have looked right in a dump and answered nothing, with no gate in this repository able to catch it, because writing a flag is not the same claim as its being ASKABLE. **So the third answer, which the plan did not consider**: `time/hour` and `time/day` as ordered ints, where `AT_LEAST 9` with `AT_MOST 17` is a shop's hours and the comparison means what an author expects; and a phase and a weather kind as **one bool under the lowercased name**, stable against an enum insertion AND readable, with **no seventh comparison** added to a set whose own file says it stays closed. Exactly one row exists at a time and it is **ERASED rather than set false** — `Inventory` erases a spent stack rather than zeroing it, an absent flag answers `IS_TRUE` false and `IS_FALSE` true, so the semantics are identical at a seventh of the rows and boot publishes four flags rather than seventeen; the erase comes FIRST, because a phase flag left true would make an authored dawn-only line fire at every hour after the first dawn. **THE PLANT IS THE REQUIRED SHAPE, ONE PATH RED AND THE OTHER GREEN**: publishing dropped from the `set_time` path only gave exit 1 on exactly two assertions, *"a jump onto the hour opens it"* and *"the flag was current inside that one too — expected 14, got 11"*, where **the `11` is what the tick path had published**. **AND THE ROW SURFACED A DOCUMENTED GOTCHA AT THE ONE SITE NOBODY HAD FIXED**: `QuestTracker.ids_in_state` sorted with `Array[StringName].sort()`, which orders by interned handle rather than alphabetically — gotcha 33, already noted and fixed in `area_db.gd`, `equipment.gd` and `inventory.gd`, while this function's own comment claimed *"sorted, so the journal draws a stable order"*. It was the allocator's order: four new flag names shifted the intern table and a journal assertion in `item_count_test.gd`, on a code path this row never touched, went red — baseline returning `[gather, errand]`, which is the order that is NOT alphabetical. **Two wrong hypotheses died before the right one**, a timing race (killed by the failure being deterministic across three runs) and pointer-sorting "disproved" by a two-element probe that came out alphabetical BY LUCK, which is why the second probe used eight names and returned `alpha, delta, echo, foxtrot, charlie, bravo, hotel, golf`. Fixed with the same `sort_custom(_before)`, and the test stopped reading "the last Label" — a bet on an order the base never promised — for a named quest's own row. `clock.gd` is now at **142 of its 150-line budget**, the tightest it has been. 2,302 → **2,331 assertions**, +29: 27 in the new case plus 2 in `record_shape_test`, whose plan is `_docs.size() + _packages.size() * 2 + 2`, so a new package id is worth exactly two. **MEASURED by diffing every case against `main`, and re-measured after the documentation landed** — which is what caught the second pair, since the pre-docs run read 2,329 and writing that down is the mistake the last two rows made; see below |
| T5.32 | **A schedule could only describe one day** | **DONE** — `5.6.0`, a MINOR: the base gained something a game may ignore, and every existing authored `.tres` stays valid unedited. **THE ROW THE PLAN CALLED EXPLICITLY OPTIONAL, AND THE OWNER CHOSE TO BUILD** — rated non-blocking, named *"the honest place to stop early if you want to"*, put to the owner as a live three-way choice and taken in full; recorded because it exists by decision rather than by implication. **`ScheduleEntry` EXPORTED `from_hour` AND NOTHING ELSE**, so an hour was an entry's whole address and `entry_for_hour(hour)` was the whole lookup — **every NPC in every game on this base repeated one identical day forever**, and a market day was not badly supported but INEXPRESSIBLE. **In scope only because of ADR-0007**, whose seam test puts a cycle LENGTH on the template-default side (a formula, one modulo) and a CALENDAR on the game-choice side, so this row adds `days_per_cycle` and adds no weekday names, no months, no seasons and no date type — the refusal being as much of the deliverable as the feature. **It follows T5.31's seam verbatim because that seam was built for it**: `time/day_of_cycle` publishes like `time/day`, through `Flags.declare_derived` from `_publish_time()`, so it never reaches a save and recomputes from the clock's own state — one line added there and nothing else. **AN ORDERED INT, NOT A BOOL-PER-NAME, WHICH IS A DEPARTURE FROM T5.31 ONE ROW LATER AND IS STATED RATHER THAN DRIFTED INTO**: that argument is entirely about a PHASE and rests on two properties a day of the cycle lacks — no enum behind it, and no wrap inside its own range, which runs `1` to `days_per_cycle` and stops. So `EQUALS 3` is a market day and `AT_LEAST 5` is the back half and both mean what an author expects; the `AT_LEAST` assertion is one that could not be written at all under the phase's shape. **THE DEFAULT IS WHAT MAKES IT A MINOR AND `-1` DOES THE WORK TWICE**: on the field it means every day, so existing `.tres` need no edit and no migration (`GameEnums`' append-only discipline, for the same reason — these numbers live in authored files); on the argument it means "no particular day", so an existing `entry_for_hour(hour)` call still compiles and still answers. What it deliberately does NOT mean is "any day", which would have leaked a day-specific block into every day — the defect arriving through the fix, and there is an assertion on exactly that. **TWO THINGS HAD TO CHANGE WITH THE LOOKUP AND ONE WAS NEARLY MISSED**: `problems()` keyed its duplicate check on the hour alone, so left alone **`check_content.gd` would have failed the build on correctly authored data** — the very fixture proving the feature reported as malformed; keyed on the pair `Vector2i(hour, day)` a market day is legal while a genuine collision still is not. And `NpcBrain` reads `Clock.day_of_cycle()` itself at both sites rather than taking the day as a parameter, because the hour is something a caller hypothesises about while which day it is is a fact `Clock` owns — which also gives the new public method its `src/` caller for `check_methods.gd`. **A STATED COST, being a layering consequence rather than an oversight**: nothing validates a day against the real cycle length, so `on_day_of_cycle = 9` on a seven-day cycle parses, loads, passes every checker and simply never runs — `content` may not touch an autoload and `check_layers.gd` exists to refuse it reaching up into `systems` for a number. A draft header claimed `NpcSchedule.problems` caught it; it cannot, and the claim was corrected before commit rather than shipped as a comment promising a check nothing performs. **THE BUDGET PREDICTION WAS WRONG AND MEASURING BEAT BOTH REMEDIES**: the plan warned `clock.gd` at 142 of 150 would go over and demanded a split or a justified budget, and **neither was needed — it landed at 147**. What would have cost the lines was a republishing setter, dropped on an argument rather than to fit (`game_started` republishes, and a tick republishes within one in-game minute, so the window is one no caller can observe); the split was refused on evidence, since `phase_flag`'s own header says it is public BECAUSE it is the spelling an author writes, making the move a MAJOR, and its only consumer is one test file. Three lines of budget remain — **T5.33 corrected this row's original claim that they were the tightest in the base**: `director.gd` has the same three at 187 of its raised 190, and `dev_stage.gd` had two at 248 of 250 before T5.20 split it, so `clock.gd` and `director.gd` are the two tightest and the next row to touch either faces a split. **The plant is the shape the plan asked for**: the day argument ignored in the lookup gave exit 1, `2346 passed, 4 failed` against a control of `2350 passed, 0 failed` — three new assertions failing together, and **a fourth that is the cheap evidence**: *"the day's first hour switches over"*, a pre-existing assertion this row never touched, catching the same regression independently. **Gotcha 79 did not bite, and that is a result** — a new flag name was published and nothing in an untouched file went red, confirming T5.31's `QuestTracker.ids_in_state` fix was the last site; no new gotcha, so the list stayed at 79. 2,331 → **2,355 assertions**, +24: 11 in `npc_test`, 8 in `time_flags_test`, 2 in `record_shape_test` and **3 in `doc_counts_test`, which this row did not see coming** — that case makes a claim of every line outside the list mentioning a gotcha and spelling a number, so this row's own prose became three assertions about itself, all three passing. Measured by diffing every case against `main` AFTER the documentation landed; the pre-docs run read 2,350 and a predicted +21 would have been wrong by three. **THIS IS THE LAST PLANNED ROW: no chip was created, because there is nothing to hand off to.** Every row here is DONE and the base is complete; the next thing to happen to this repository is a game being started on it |
| T5.33 | **The audit of a base declared finished** | **DONE** — `5.6.1`, a PATCH. **THE BASE WAS DECLARED COMPLETE AND THEN AUDITED, AND THE AUDIT FOUND THAT THE ROW DECLARING IT COMPLETE HAD MADE A DOCUMENTED INVARIANT VIOLABLE.** `schedule_entry.gd` has always promised **a day is always completely covered**, "because an NPC is always somewhere", and before T5.32 that was STRUCTURALLY true — every entry applied on every day, so the wrap-to-the-last-block fallback could never come up empty. `on_day_of_cycle` made it violable by authored data and nothing noticed. **Measured with a throwaway probe rather than argued**: a schedule of only day-specific entries answers NOTHING on any day it does not name — **24 hours of 24** — while `problems()` returned 0, so `check_content` PASSED on content that strands an NPC and `NpcBrain.decide_for_hour`, which returns early on null, left it standing wherever it happened to be. That is precisely the "reads as random" failure the entry header exists to prevent. **The fix is one rule and it is exactly the right strength**: every schedule must carry at least one entry at `-1`, which is necessary AND sufficient for total coverage, since `_applies_on` admits an every-day entry whatever day is asked. The stronger rule — every day of the cycle is covered — would need `Clock.days_per_cycle`, and `content` may not touch an autoload, so this is the strongest form the layer can actually check. **The plant is the check removed**: exit 1, one failure, `and that is reported as a problem rather than passing check_content — expected 1, got 0`, against an exit-0 control — and the "24 of 24 hours answer nothing" assertion stays GREEN under the plant, which is right and is why the two are separate: the consequence exists whether or not the validator reports it. **PATCH, settled on three precedents in `CHANGELOG.md` rather than instinct**, because a new gate that fails existing content looks like the MAJOR test *a file the game wrote must change*: `5.3.3`, `5.3.2` and `1.0.2` are all this shape and all PATCH, and `1.0.2` states the reason — *"That is the bug being fixed, not a new restriction."* A schedule with no every-day entry is already broken. **AND THREE DOCUMENTATION NUMBERS WERE WRONG, one of them with a lesson.** `TESTING.md` stated the suite as `2302` / `2226` — stale through **two consecutive rows**, because the closing checklist was being read as "update `CLAUDE.md` and `ARCHITECTURE.md`" when it governs FOUR files; the stale pair even disagreed with the rest of the repository, its difference being 76 against a stripped gap the board recorded as exactly 74 for eight straight runs, and nothing caught that either. Item 5 now lists all four files and says the stripped number can only come from the CI job log, so that step finishes AFTER CI. `NEW_GAME.md`'s "all 930 assertions" had the number **deleted** rather than updated, because it carried no weight — the better fix for a count no reader needs. And T5.32's own record claimed `clock.gd`'s three spare lines were "the tightest any file in this base has been", **wrong twice**: `director.gd` sits at 187 of its raised 190 with the same three, and `dev_stage.gd` was at 248 of 250 with TWO before T5.20 split it. **What the audit also CONFIRMED is worth recording, since a clean result is evidence too**: zero markdown table column mismatches across every live document — the defect that recurred in T5.15, T5.19 and T5.26 — found with a fence- and escape-aware scan after a naive one produced four hits that were all false positives; and "Ten autoloads", "seven checkers", "eight template screens" and `AUTHORING.md`'s per-area figures all verified correct against the code, the last of these nearly mis-reported before `world_map_test`'s plan was read properly as `PER_AREA 4 + PER_DEF 1`. 2,355 → **2,362 assertions**, +7 — five in `npc_test` and two in `record_shape_test` for this row's own board id, the pre-docs run having read 2,360; the plan guard caught an off-by-one on the way, reporting `planned 85 outcomes and produced 84` with every assertion passing, which is that mechanism doing its job |
| T6.0 | **Planning Phase T6 — what every game on this formula would otherwise build first** | **DONE** — `5.6.2`, a PATCH, and `src/`, `tools/`, `tests/` are byte-identical. **THE OWNER ASKED WHAT THE BASE HAD MISSED, AND THE ANSWER WAS FILTERED RATHER THAN BRAINSTORMED.** ADR-0007 decides what a template DEFAULT is, the refused list rules out cutscenes, an economy, a chapter sequencer, a calendar, combat and credits, and the standing rule is that work is found, not invented — so every surviving row is either a confirmed defect or an undecided item on the project's own "Commonly forgotten" list. **Method: three parallel explorations and an adversarial review, then every load-bearing claim re-read in the code**, and the review **overturned three first premises**: shader warm-up was proposed as missing and was built in T2.0 (`Director.WARM_UP_FRAMES`); per-section save versions were proposed as never exercised and are exercised by `core_test.gd:134`; the F2 freecam was called unbound and is bound, merely unconsumed. **IT FOUND ONE REAL DEFECT BY READING**: `SaveSystem.load_from_slot` hands each section's stored version to its applier with no check that it is not newer than the running build, and every applier ignores that version — the envelope has the guard and the section level has no twin. That is T6.1, to be proved red before it is fixed. **The owner decided three things**: T6 only; photo mode, a codex, in-area camera zones and positional ambient emitters are GAME CHOICES, each with its seam named; and font fallback proves both Bengali and CJK. Stale records fixed in passing: `CONTEXT.md` listed time on the flag surface and the day cycle as open candidates though T5.31 and T5.32 built both, and three "Commonly forgotten" items described settled work as missing. See below for every candidate's classification and each row's file manifest |
| T6.1 | **A save from a newer build must be refused, not applied** | **DONE** — `5.6.3`, a PATCH on `1.0.2`'s "the bug being fixed, not a new restriction". **PROVED RED BEFORE IT WAS FIXED**: on `5.6.2`, a section stored at `"v": 3` for a probe registered at v2 reached its applier — `but its applier was never called — expected 0, got 1` and `so the probe keeps its defaults — expected unset, got from the future`, exactly the two failures T6.0 predicted from reading. `load_from_slot` now refuses a section whose stored version exceeds the registered one — `Log.error`, defaults, continue — the section-level twin of `_migrate`'s envelope refusal; one bad section still does not cost the file. The plant (guard disabled) fails the same two assertions again. **And the suite's first worked, exercised migration**: `_probe_apply` in `save_recovery_test.gd` renames `old_key` → `new_key` from v1 and asserts the value survives, with a v2 boundary block so the refusal cannot pass by refusing everything; `UPGRADING.md` § 4 now tells a game to copy it. `save_system.gd` 172 → 176 of 180, no budget touched. See below |
| T6.2 | **The base knows which input device is active** | **DONE** — `5.7.0`, a MINOR: a signal, an enum, two methods and a class a game may ignore. The pure `InputDevice.device_for(event, previous)` decides and `Actions` holds the answer, emitting `input_device_changed` only on a change — **no autoload added**, `Actions`' MUST NOT narrowed rather than dropped. Mouse motion and sub-deadzone stick drift are not a switch; unplugging the last pad falls back to the keyboard. The interact prompt now names the button — `[E]  Barter  The Keeper's Basket`, photographed — and **the dialogue hint had said "Space to continue" while Space advanced nothing**, bound to the `jump` T5.5 removed; it now reads `E to continue` and follows the device mid-conversation. Three plants, three different failures. Hotplug cannot be driven headless and is proved by calling the handler. Suite 2,375 → 2,408; see below |
| T6.3 | **A reusable confirm screen, and "are you sure" on overwriting a save** | **DONE** — `5.8.0`, a MINOR: a class and three strings a game may ignore. `ConfirmScreen.asking(question_key, detail, on_yes)` is a `MenuScreen` with `closes_on_cancel = false`, so **escape and pause cannot answer it**, and focus lands on **No**, so mashing accept loses nothing. Pressing an occupied slot on the save screen asks `Overwrite this save?` under the header about to be lost; an empty slot saves at once. The quit half of forgotten #7 is T5.10's quit-autosave, recorded with its two refusals rather than built. Two plants, two different failures, and a control assertion proving the cancel event really reaches `UiRoot`. Photographed over the pause menu. Suite 2,408 → 2,437; see below |
| T6.4 | **A save slot says where it was saved, and says so when it is damaged** | **DONE** — `5.9.0`, a MINOR: a hook, a constant and a static method a game may ignore. `SaveSystem.header_provider` is an optional Callable stored as the file's `"header"`, so `core` never asks `Director`; **`WorldMap` sets it, not `director.gd`**, which is at its budget, and `WorldMap.place_key` reads the area id back as a name key. The row reads `Slot 1 · Rose Courtyard · …`, photographed; an unmapped area or a pre-5.9.0 save reads `Unknown place`. **`slot_info` now answers `{}` for any file the loader would refuse**, so a file from a newer build is DAMAGED too, and Continue can no longer point at one. A damaged slot is a note when loading and, counted as occupied, asks before it is overwritten. Three plants, three different failures. `save_system.gd` 176 → 179 of 180. Suite 2,437 → 2,471; see below |
| T6.5 | **Losing window focus leaves nothing latched** | **DONE** — `5.10.0`, a MINOR: a signal, a setting and three public methods a game may ignore. **Measured first, windowed**: Godot 4.7.2 clears a held key and its action on focus loss by itself, and sends no release event. So the base drops only its own latches on `Events.focus_lost` from `UiRoot`: a toggled run, a hold in progress, a rebind capture. `gameplay/pause_on_focus_loss`, **off by default**, makes `ScreenKeys` open the pause menu. **The first windowed run found the player stranded under an invisible menu**: the engine PROPAGATES the notification, `add_child` failed inside the walk, and the stack had recorded the screen anyway. The suite had used `notification()` and passed. Now the announcement is deferred, `UiRoot.open` rolls back a failed add, and the test propagates. Gotcha 80. Photographed. Suite 2,471 → 2,504; see below |
| T6.6 | **Text in any script renders, not as tofu** | **DONE** — `5.11.0`, a MINOR: a resource, two fonts, a constant and a static method a game may ignore. **WINDOWS HID THE DEFECT**: with system fallback on, Nirmala UI and YaHei drew Bengali and Chinese with no bundled font, so the before capture switched `allow_system_fallback` off to show the boxes a player without those fonts sees. `assets/fonts/font_chain.tres` has no base font, so the engine's Latin is unchanged, and falls back to Noto Sans Bengali then a 2.8 MB Noto Sans SC subset, both at weight 600 to match. **THE THEME NAMES NO FONT, MEASURED**: it loads before the first import, and a copy of the tree with no `.godot/` printed `Parse Error` twice on rung 2's `--import`. So `UiRoot.install_font_chain` installs the chain at boot (gotcha 81). The suite shapes real strings headless: ক্ষ is one glyph from the Bengali font. The `tr_n` check found RestPoint's `{hours}`, which became T6.10 |
| T6.9 | **Running the suite destroyed the developer's real saves** | **DONE** — `5.11.1`, a PATCH, test-only: `src/` and `tools/` byte-identical. **OUT OF NUMBER ORDER ON PURPOSE**: an owner-reported defect, taken ahead of T6.7 under the playtest rule, and numbered after T6.8 so that no planned row's id moves. Fourteen cases wrote or deleted slots against the default `user://saves`, because only T5.22's two had ever called `SaveFixture.activate()`. Seven sentinel saves planted there: the unchanged suite passed 2,437 of 2,437 and **deleted all seven**; fixing only the three suspected cases still lost five; all fourteen redirected, all seven survive byte-identical. `TESTING.md` now states the rule. See below |
| T6.10 | **A capture or debug launch wrote over the developer's real saves** | **DONE** — `5.12.0` (claimed `5.10.0`, renumbered to land after T6.6), a MINOR: a class and a flag a game may ignore. **OUT OF NUMBER ORDER ON PURPOSE**, like T6.9, which found it. The ladder's capture rung runs `--new-game`, a real run, so the autosave wrote the real `autosave.json`, and `--save-state`/`--load-state`/`--cross-area-save` deleted real slots. The new `dev_saves.gd`, first of the debug nodes, sets `SaveSystem.save_dir` to `user://dev_saves` for any launch with user arguments; `--real-saves` opts out. **A redirect, not a suppression**, so the capture still photographs the toast. A planted sentinel was overwritten by one capture before and survives it byte-identical after. Also fixed `--autosave-continue`, which could not find the Continue row. `save_system.gd` untouched at 179 of 180. See below |
| T6.11 | **A debug launch, and every suite run, wrote the developer's real settings** | **DONE** — `5.13.0` (claimed `5.11.0`, renumbered to land after T6.6), a MINOR: a var and two constants a game may ignore. **OUT OF NUMBER ORDER ON PURPOSE**, like T6.9 and T6.10; T6.10 found it and recorded it undone. `Settings.PATH` was the only path, so a `--locale=en_XA` capture rewrote a sentinel's `locale="en"`, and **a green suite left it at zero bytes**, which T6.10 had not suspected. `Settings.file_path` is where `save()` writes; `DevSaves` points it at `user://dev_settings.cfg` under its existing rule, and the runner at `user://test_settings.cfg` before the first case. **Writes only, never re-read**, so no launch inherits the last one's language. The sentinel now survives both byte-identical. `settings.gd` 141 → 142 of 150. See below |
| T6.12 | **Nothing failed a case that saved without activating the scratch store** | **DONE** — `5.13.1`, a PATCH on `5.6.1`'s precedents, test-only: `src/` and `tools/` byte-identical. **OUT OF NUMBER ORDER ON PURPOSE**, the gap T6.9 recorded; Both halves T6.9 offered, because each alone leaves a hole: the runner PARKS the store in `user://test_saves_unclaimed` before every case, so a forgotten `activate()` cannot reach a real save, and FAILS a case that saves, or loads a real file, anywhere but the store it claimed. Heard on `game_saved`/`game_loaded`, not by a directory diff. **Three plants red**, each naming its case: `confirm_test` and `menus_test` (saves) and `save_recovery_test` (a hand-planted file, loaded then deleted). Seven sentinel saves survived every run. See below |
| T6.14 | **A count that reaches a string picks its plural form** | **DONE** — `5.16.0`, a MINOR. **THE LAST ROW OF PHASE T6, WHICH IS NOW COMPLETE.** Numbered T6.10 by T6.6, then T6.12, T6.13 and T6.14 as rows ahead of it merged. **4.7.2's CSV importer reads plural forms** — the docs are silent, a scratch project proved it: a `?plural` column, and the next form on a following row with an empty key; `.po` was not needed. `RestPoint` asks `translate_plural` for the form and reports the nearest hour, never zero. Proved red first, 8 failed, including "13 hour slips past", because `tr()` on a plural row answers its first form. Photographed: "1 hour slips past." for 59 minutes. See below |
| T6.15 | **A wandering NPC picked spots it could not walk to, and logged an error for it** | **DONE** — `5.16.2`, a PATCH: one public static method, no file a game wrote changes. **FOUND BY THE MOVE TO THE CLOUD**, in the first windowed capture a cloud session ran: `0 warnings, 1 errors`, `Keeper cannot reach 'dais'`. **NOT TIMING, AS GOTCHA 21 SUGGESTED**: a diagnostic print showed every one of 10 errors in 8 runs was a random wander offset on the dais or beside its riser, never the authored marker. `_tick_wander` now passes the offset through `NpcBrain.reachable_point()`, the end of a real `map_get_path`. Red first, 5 of 7 failed; after, 10 windowed runs logged 0 errors. **`map_force_update` does nothing while async iterations are on** (gotcha 83), so the test switches them off. See below |
| T7.0 | **A script for the owner's playtest** | **DONE** — `5.16.3`, a PATCH, documents only. **PHASE T7 OPENS: PLAYTEST AND HARDEN.** New `docs/PLAYTEST.md` walks every player-facing system through the demo, step by step, asks #8's first-run question before settings are opened, and gives the shape a finding is reported in. **Rows T7.1 onward are not planned; they are whatever the playtest finds**, one package at a time, each red first. |
| T7.2 | **A save could fail, but never be refused** | **DONE** — `5.17.0`, a MINOR: one class and one string a game may ignore. **Found from the combat fork**, like T7.1. A save written while the player lay defeated, or the quit autosave mid-battle, stored a world no load continues from, and the store had no way to hear "not now". New `SaveSystem.blockers` (`SaveBlockers`): a named callable answers a reason key or `""`. While one answers, `save_to_slot` writes nothing and returns `ERR_UNAVAILABLE`, the autosave skips quietly, and the save screen toasts the reason. Loading is never refused, and a freed owner's blocker is dropped. Red first: with `refusal()` stubbed to `""`, 10 of `save_blocker_test`'s 17 assertions failed. `save_system.gd`'s budget went from 180 to 190, with the reason in `ARCHITECTURE.md`. |
| T7.1 | **CI's actions targeted the deprecated Node 20** | **DONE** — `5.16.4`, a PATCH, CI only: `src/`, `tools/` and `tests/` byte-identical. Every job ended in GitHub's Node 20 deprecation warning for `actions/checkout@v4`, `actions/cache@v4` and `actions/upload-artifact@v4`; found reading the combat fork's CI log. Moved to `@v5`, `@v5`, `@v6`. Proof is CI itself: the ladder green on both jobs with the warning gone. |
| T6.7 | **Dialogue for fast and slow readers** | **DONE** — `5.14.0` (claimed `5.12.0`, renumbered to land after T6.12), a MINOR: a setting, two public methods a game may ignore, and cancel now doing something in a conversation where it did nothing. **A SKIP WALKS, IT DOES NOT JUMP**: cancel calls `DialogueScreen.skip()`, which drives the runner through `advance()`, so every node passed is arrived at and fires its effect; it stops at the first choice, shown whole, and a second skip there does nothing; with no choice ahead it runs to the end. A cycle stops after 512 lines. `gameplay/dialogue_auto_advance`, off by default, holds a whole line 1.5 s plus 15 characters a second over the text speed, and never answers a choice. **THE PLANT THAT STAYED GREEN**: deleting the screen's stop-at-a-choice check changes nothing, because the runner already refuses there; the red plant is `runner.stop()` as the skip, `2549 passed, 13 failed`. `dialogue_test.gd` would have been 305 of 250, so the cases are `dialogue_speed_test.gd`. Photographed |
| T6.13 | **Two suite runs at once, in two worktrees, broke each other** | **DONE** — `5.15.0` (claimed `5.12.0`, renumbered to land after T6.7), a MINOR: a class and a var a game may ignore, and test-framework constants turned into functions. **OUT OF NUMBER ORDER ON PURPOSE**, like T6.9 to T6.11; T6.11 found it, and T6.12 was taken by PR #73. Every worktree shares one `user://`, and `SaveFixture.activate()` EMPTIES a fixed directory under it, so two suites started 0.3s apart failed 15 and 8. Every scratch path is now under `RunScratch.root()`, `user://test_runs/<pid>`, and both pass. **Liveness is a heartbeat, because the pid design failed its own proof**: on Windows `OS.is_process_running` is false for a process the caller did not start, so each run pruned every other. At the merge T6.12's parking directory, a fixed name `park()` empties before every case, moved under it too. Also stopped `options_test` deleting the real `input.cfg`. See below |
| T6.8 | **Close the list, and gate it** | **DONE** — `5.15.1`, a PATCH, and `src/` and `tools/` are byte-identical. **THE PHASE'S EXIT CRITERION, AND EVERY ONE OF THEM IS NOW TICKED.** Every item of `SYSTEMS_INVENTORY.md` § "Commonly forgotten" carries the bold marker `DONE — <id>` or `CLOSED (game's) — <id>`, and the new `forgotten_list_test.gd` fails an item without one, an id with no row on this board, and a gap in the numbering. **PROVED RED ON THE LIST AS IT STOOD**: 16 failed, two for each of eight items — #1, #6 and #9 to #13 were settled work described in prose the scan could not read (`BOTH DONE`, `Both work as of T5.5`, `owner decision, T6.0`), and #8 had no verdict at all. After, 32 of 32. Two plants, an id with no board row and a numbering gap, fail one each. **#8 IS CLOSED (game's), PENDING THE OWNER'S PLAYTEST**: the manifest asked for the owner's playtest verdict on first-run defaults; asked on 2026-09-30, the owner has not playtested yet and means to soon, so the closure stands until then, and the base keeps every default in one `Settings.DEFAULTS` line for a game to tune against its own content. A default found unpleasant by playing is still a defect under the playtest rule. T6.14 closed the phase. See below |
| T3.3 | **A quest step that can read an ITEM COUNT** | **DONE** — `292dd44`, PR #21. The sixth package of Phase T3; see below. WP-09 costed two designs and closed neither; this took the FIRST one with the cost that made it look expensive removed — the count is a DERIVED flag, so it is readable without being saved twice |

**Why T2.0 jumps the queue, and it is deliberately out of thematic order.** It belongs to Phase
T3 by subject and is sequenced FIRST by risk. The three content registries find items,
conversations and schedules by DIRECTORY SCAN (ADR-0006). No export preset exists, so nobody has
ever run an exported build. If a Godot export omits unreferenced resources, every catalogue ships
EMPTY — and every ladder rung, both CI jobs, `check_content` and 911 assertions all stay green,
because they run from `res://` in the editor where the files are plainly there. That is the
"409 passing checks and never rendered a frame" failure this project was founded to prevent,
reproduced at the last possible moment.

The asymmetry is what decides the order: the proof is cheap (one preset, one export, one count),
and if it FAILS the fix is architectural — a revision to ADR-0006 touching how all content is
found. Every package built in the meantime would be built on an assumption known to be false.
T2.1 by contrast fails locally, inside `CharacterVisual` and a `Theme`. Cheap test, architectural
blast radius, so it goes first.

**Re-framed rows on the original board.** WP-09 was SPLIT rather than restated, and its section
says why: three systems in one row is over the size limit. Its criterion "the lantern gates an
area" was also a content claim, and what was built and proved is *equipment can gate traversal*,
of which a lantern is the example. WP-10 is a
genre choice, and the board row now says OPTIONAL. **WP-14's "a smoke test that drives the whole
demo" was re-framed by WP-14 itself, in the commit that took the row** — that wording would have
hard-wired the courtyard, the keeper and the rose key into a permanent gate, which is the boundary
`check_boundary` exists to defend arriving through the back door of a test, and the welding T1.3
spent a whole package undoing. `tests/unit/smoke_test.gd` drives *a* game, from
`tests/framework/fixtures.gd`, and skips its one game-shaped block loudly in a stripped checkout.
WP-14 was also SPLIT along its own title, for the size reason WP-09 was split: it named four
things, and the two that are gates shipped while the two that are UI became **WP-14b**.

When every package is `DONE`, the skeleton is complete: every system has a working minimal
implementation plus one piece of placeholder content proving it. Everything after that is
content, and none of it should need new architecture. That is the bet this project is making.

---

## WP-01 · Triggers and traversal — **DONE**

**Goal.** Complete the interactable catalogue so the Phase 1 loop is genuinely whole: volumes
that fire on entry, a place to rest and skip time, and authored vertical movement.

**Read:** `src/gameplay/interactables/interactable.gd`, `gate.gd` (closest existing pattern),
`src/gameplay/objects/persistent_state.gd`, `src/core/util/layers.gd`,
`src/systems/world_clock/clock.gd`, `src/gameplay/character/player_controller.gd`,
`src/core/events/events.gd`, `tests/unit/pickups_test.gd` (the test idiom),
`scenes/areas/courtyard/courtyard.tscn`, `scenes/objects/gate.tscn`.

**Write**
- `src/gameplay/interactables/trigger_volume.gd` — `Area3D` on `Layers.TRIGGER`, once-or-repeat,
  persisted by `object_id`, sets a flag and emits. **Must not know what its action does.** The
  `Triggers/` node, the collision layer and the inventory row all exist already and nothing
  populates them.
- `src/gameplay/interactables/rest_point.gd` — `SIT` verb, skips to a target hour.
- `Clock.skip_to_hour(hour)` — routed through `set_time`, **not** `advance_minutes`, or an
  eight-hour sleep emits 480 `minute_passed` signals.
- `src/gameplay/interactables/climb_point.gd` + a climb state in `PlayerController`. This is the
  authored vertical movement that "no jumping" implies.
- Prefabs in `scenes/objects/`, placed in the courtyard, plus CSV rows.
- Cases in `tests/unit/`.

**Exit criteria**
- A trigger fires once on entry, does not re-fire, and stays fired across a reload.
- Resting advances the clock, and captures before and after show the lighting actually changed.
- A climb point moves the player vertically and cannot be entered mid-air.
- Ladder green; `check_content` still exits 0.

**Unblocks:** the clock time-skip that NPC schedules (WP-06) need.
**Deferred here:** physics props, water volumes, harvestables (WP-10).

**Closed 2026-08-26**, commit `81b28b0`. All four exit criteria met. 215 assertions
(was 165), boot `0 warnings, 0 errors`, both checkers exit 0. Two bugs the engine caught and
static checks could not: a climb that oscillated on its corner because the waypoint did not
latch, and a trigger near the area origin firing at spawn because the player exists there for
a frame before `Director` places them. Both are written up in `DEVLOG.md` and `CONTEXT.md`.
One scope addition beyond the manifest, deliberate and small: `RefusalReason.NOT_GROUNDED`,
because a climb refused mid-air with no message is indistinguishable from a broken button.

---

## WP-02 · UI foundation — **DONE**

**Goal.** A screen stack, pause semantics and input contexts — so no screen is ever built on an
ad-hoc pause and a boolean.

**Why before any screen.** Nothing currently has a home for modal UI. `InteractionSensor` reads
input every physics frame with no notion of an open screen, and the only hand-over mechanism is
`PlayerController.set_input_locked()`, driven solely by dialogue signals. Build a screen first
and you get one boolean per screen, forever.

**Read:** `src/ui/` (all three files), `scenes/boot/game_root.tscn`, `src/core/boot/game_root.gd`,
`src/gameplay/interaction/interaction_sensor.gd`, `src/gameplay/character/player_controller.gd`,
`src/systems/input/actions.gd`, `src/core/events/events.gd`.

**Write:** `src/ui/root/ui_root.gd` — a screen stack, one `is_gameplay_input_allowed()` truth,
and a `ui_mode_changed` signal on the bus. Replace the single input-lock boolean with a counted
or token lock (`lock(&"dialogue")`), so two systems locking cannot unlock each other. Pause via
deliberate `process_mode` per node — music and the fade keep running, gameplay stops.

**Exit criteria:** a stub screen opens, gameplay input stops, music keeps playing, the fade still
works, and closing it restores control. Two overlapping locks release correctly.

**Unblocks:** every screen in the game.

**Done 2026-08-26**, commit `444dbd2`.
`InputLock` (`src/core/util/input_lock.gd`), `UiRoot` (`src/ui/root/ui_root.gd`), `UiScreen`
and `StubScreen` (`src/ui/screens/`), `GameEnums.UiMode`, `Events.ui_mode_changed`.
`PlayerController.set_input_locked(bool)` is DELETED; its callers hold named tokens, and
`InteractionSensor` grew its own lock and now knows an open screen exists at all. Suite 215 ->
294, everything green, plus three windowed captures and a real-input probe in the live tree.
Two things the manifest did not anticipate, both small and both justified in `DEVLOG.md`:
`Audio`, `Director`, `NotificationToast` and `DevCapture` each opted out of pause in their own
`_ready()` (autoloads are pausable by default, so music would have cut out), and `ScreenFade`
moved to be the last child of `UILayer`, because a curtain that does not cover the screens is
not a curtain.

---

## WP-03 · HUD and inventory screen — **DONE**

**Goal.** The first real consumers of the stack. The inventory has data and no window.

**Read:** `src/ui/root/ui_root.gd` and `src/ui/screens/ui_screen.gd` (both from WP-02),
`src/ui/screens/stub_screen.gd` (the worked example), `src/ui/hud/`, `src/ui/prompt/`,
`src/gameplay/character/inventory.gd`, `src/content/items/item_definition.gd`, `item_db.gd`,
`src/systems/world_clock/clock.gd`, `localization/strings.csv`.

**Write:** a HUD (clock readout; prompt and toasts already exist) and an inventory screen bound
to `Events.inventory_changed`. The UI stays dumb — it reads `Inventory.ids()` and renders; it
holds no rules. Every string is a CSV key.

**Exit criteria:** open with `I`, items listed with localized names and counts grouped by
category, gameplay frozen while open, basic gamepad navigation. Capture and look at it.
The screen is a `UiScreen` pushed onto `UiRoot` — it must NOT touch `get_tree().paused`, must
NOT lock the player, and must NOT add a signal for any of that. If it needs to, the stack is
wrong and that is a WP-02 bug, not a reason to work around it. Delete `StubScreen` once this
and one other real screen exist.

**Done 2026-08-26**, commit `1563915`.
`src/ui/hud/hud_clock.gd`, `src/ui/screens/inventory_screen.gd`, `src/ui/root/screen_keys.gd`,
`tests/unit/screens_test.gd`, 22 CSV rows. `StubScreen` is DELETED along with its two
`ui.stub.*` rows and the `--open-screen` flag, which became `--give=<list>` plus
`--open-inventory` so a capture shows real rows. `ui_test.gd` now drives real screens. Suite
294 -> 355, everything green, two windowed captures examined and a real-input probe that
pressed I, ui_down, ui_up, Escape and I twice in the live tree.
One thing the manifest did not anticipate, justified in `DEVLOG.md`: a screen must declare
`pauses_world` in `_init`, not `_build`, or `_ready` discards a caller's override — which had
been making the overlay assertion in `ui_test.gd` pass vacuously since WP-02.

---

## WP-04 · Second area, transitions, loading — **DONE**

**Goal.** Prove `Director` for real. It is written, guarded, logged — and has **never swapped two
areas**, because only one exists.

**Read:** `src/systems/scene_director/director.gd`, `src/gameplay/world/area_root.gd`,
`src/gameplay/world/environment_driver.gd`, `scenes/areas/courtyard/courtyard.tscn`,
`src/ui/hud/screen_fade.gd`, `src/gameplay/interactables/gate.gd`.

**Write:** a second area, a door that travels, a loading indicator behind the fade, shader
warm-up. Interior variant with `follow_clock = false`.

**Exit criteria:** twenty round trips with no growth in node count or memory; two transitions in
one frame refused with a log line; world state on both sides survives a save and reload;
captures of both areas.

**Done 2026-08-26**, commit `3ed321f`.
`scenes/areas/lantern_hall/`, `src/gameplay/interactables/area_door.gd`,
`src/ui/hud/loading_indicator.gd`, `tests/unit/transitions_test.gd`,
`Events.area_load_progress`, `Director.WARM_UP_FRAMES`, an Interior group on
`EnvironmentDriver`, and `--round-trips`, `--cross-area-save` and `--goto` in `dev_capture.gd`.
Suite 370 -> 414. Twenty round trips held node count exactly flat at 120 and memory to -12 KiB;
the guard refused forty same-frame second requests in the same run; a save taken IN THE HALL
reloaded into the hall with its coffer still empty, after the values were deliberately wiped
first.
Three defects the manifest could not have anticipated, all invisible with one area and all
justified in `DEVLOG.md`: `DictRead.get_name` dispatched to the native `Resource.get_name`, so
loading a save had never restored the area; `InteractionSensor` held a freed `_current` because
a freed object compares EQUAL to null, leaving a prompt for an unloaded area on screen; and
`follow_clock = false` still sampled the clock once, so the first interior was pitch black at
02:30 and fine at noon from the same scene file.

---

## WP-05 · Dialogue — **DONE**

**Goal.** The largest unproven system. A runner, an authorable diffable format, and a UI.

**Read:** `src/core/state/flags.gd`, `src/core/events/events.gd` (the dialogue signals are
already declared), `src/ui/root/ui_root.gd`, `src/content/items/item_definition.gd` (the content
Resource pattern to copy), `src/gameplay/character/player_controller.gd` (it already yields to
dialogue signals), `docs/decisions/ADR-0006-item-discovery-by-directory-scan.md` (registry
pattern to reuse for conversations).

**Write:** a conversation format under `data/dialogue/`, a runner, a dialogue box with portraits
and choices and text speed. Conditions read `Flags`; effects set them. Placeholder story only.

**Exit criteria:** a conversation that reads a flag, branches on it, sets another, and survives
a save mid-conversation or explicitly refuses to be saved mid-conversation.


**Done 2026-08-26**, commit `addf337`.
`src/content/dialogue/` (four data classes plus the registry), `dialogue_runner.gd`,
`dialogue_screen.gd`, `speaker.gd`, `data/dialogue/gardener.tres`, `tests/unit/dialogue_test.gd`,
`Events.dialogue_requested`, `GameEnums.FlagTest` and `FlagWrite`. Suite 414 -> 460.
The exit criterion is met by the SECOND half, deliberately: a conversation is not saved. A saved
node id would make every node id in every .tres a permanent public identifier, so the section
exists, is always empty, and logs what it discarded; a mid-conversation save reloads with the
conversation over and control returned.
The first draft of `speaker.gd` reached for `UiRoot` and `DialogueScreen` directly, which is a
layer violation — gameplay must not name a screen. It emits `Events.dialogue_requested` instead
and `ScreenKeys` listens, matching `AreaDoor` exactly.
One defect from WP-01 found on the way: `object.lever.gate.on` had an unquoted comma, so the
lever's toast had been cut at `Somewhere north` for three packages. `check_content.gd` now fails
any CSV row that parses to more than two columns.

---

## WP-06 · NPCs and navigation — **DONE**

**Goal.** Navmesh baking, an NPC brain, and schedules driven by the world clock.

**Read:** `src/gameplay/character/character_visual.gd` (reused unchanged for NPCs),
`src/gameplay/world/area_root.gd`, `src/systems/world_clock/clock.gd`,
`src/gameplay/interactables/interactable.gd` (an NPC is an interaction target).

**Write:** `NavigationRegion3D` baking in the area template, `NavigationAgent3D` pathing, a brain
with idle/wander/travel, and schedules keyed to `hour_passed`. Level-of-detail for offscreen
NPCs is deferred.

**Exit criteria:** an NPC is at the market at noon and home at night, across a save and reload,
and thirty NPCs do not measurably cost frame time.


**Done 2026-08-26**, commit `c42c844`.
`src/content/npc/` (three classes), `src/gameplay/character/npc_brain.gd`,
`scenes/characters/npc.tscn`, `data/schedules/keeper.tres`, `Navigation/` and `Waypoints/` added
to both areas and to the `AreaRoot` contract, `GameEnums.NpcActivity`, `tests/unit/npc_test.gd`.
`dev_capture.gd` was SPLIT — it had reached 310 of its 250 allowed lines — into itself plus
`src/systems/debug/dev_probes.gd`, which now owns every scripted scenario. Suite 460 -> 555.
The schedule criterion is measured by `--npc-day`, which steps the clock through a whole day:
gate_post at 06:00 and 09:00, the dais at 12:00 and 15:00, the bench from 20:00 through 02:00 —
the last of those being the midnight wrap working. `--npc-storm=30` reports
`16.598 ms/frame with 1 NPC, 16.675 with 31`.
Three defects found while building it and eight more from an independent adversarial review of
WP-01 to WP-05, including a HARD SOFT-LOCK in dialogue that could only be escaped by killing the
process. All eleven are listed in `CONTEXT.md` and justified in `DEVLOG.md`.

---

## WP-07 · Path actions — **DONE**

**Goal.** The signature mechanic: per-NPC non-combat verbs in the spirit of Octopath's
Scrutinise, Inquire, Purchase and Guide.

**Read:** WP-06 output, `src/gameplay/interactables/interactable.gd`,
`src/gameplay/character/inventory.gd`, `src/core/state/flags.gd`, `src/core/util/game_enums.gd`.

**Write:** available actions per NPC as content data, success conditions, consequences, and a
reputation or standing store. Reuses the refusal-with-a-reason pattern the interaction system
already has.

**Exit criteria:** one NPC with two actions, one of which can fail and change standing, all
persisted.


**Done 2026-08-26**, commit `e5f90bc`.
`src/content/npc/path_action.gd`, `src/gameplay/interactables/path_action_point.gd`,
`src/gameplay/character/standing.gd`, `scenes/objects/path_action.tscn`, two authored actions in
`data/actions/`, five new `InteractVerb`s and `RefusalReason.LOW_STANDING`,
`tests/unit/path_actions_test.gd`. Suite 555 -> 606.
NO FOURTH REGISTRY: a path action is only ever reached through the NPC that offers it, exactly
as a chest reaches its `ItemDefinition`s, so nothing looks one up by id and the note in
`schedule_db.gd` about three being a pattern does not fire.
The criterion is met by barter's three bands: refused below standing 1, committed and FAILING at
1, committed and succeeding at 2 — captured once per band, and in the success shot the prompt
has already fallen back to the other action because `once` applies to success only.
`dev_probes.gd` was SPLIT again, into itself plus `dev_stage.gd`; the budget checker has now
found three seams in the debug surface, at 310, 320 and 250 lines.
One defect fixed in WP-06's code: the unreachable guard believed a single frame's answer, and a
`NavigationAgent3D` recomputing after a wander re-target legitimately answers "unreachable"
before it has finished thinking. It now requires thirty consecutive frames.

---

## WP-08 · Quests — **DONE**

**Goal.** Phase T3's first package, and the widest remaining hole: quests were the one system in
the catalogue with **no proof at all**. The flag store, a conversation that writes a flag, an NPC
to talk to and a screen stack all existed, and nothing tied them into an objective the player can
be told about and can see completed.

**The one decision everything else follows from: A STEP NAMES A FLAG CONDITION, NEVER A CALLBACK.**
The same closed set of six comparisons `FlagTest` already gave a dialogue condition. That is what
makes a quest authored data rather than a code change, and it is what makes the rest of the game
able to feed a quest without knowing quests exist — a conversation writing `met/gardener` starts
one, a lever writing `area/courtyard/gate_unlocked` advances it, a trigger volume writing
`area/courtyard/dais_entered` finishes it, and **none of those three files was touched.** The
placeholder quest is built entirely out of flags the demo was already writing.

**Wrote**
- `src/content/quest/quest.gd`, `quest_step.gd` — typed `Resource`s, id equals file name with a
  `quest/` prefix, `problems()` returning `PackedStringArray`, no autoload touched so the
  `--script` build gate can load them.
- `src/content/quest/quest_db.gd` — the fourth registry. `content_dir` a `static var`, `rescan()`
  and not `reload()` (gotcha 17), an empty folder not an error.
- `src/systems/quest/quest_tracker.gd` — watches `Events.flag_changed`, re-derives every quest,
  emits `Events.quest_started` / `quest_advanced` / `quest_completed` (all three declared in
  Phase 0 and unlistened-to until now) and asks for a toast. A node under `GameRoot`, found by
  group the way `UiRoot` is; no ADR, because no autoload.
- `src/ui/screens/journal_screen.gd` — a `UiScreen` declaring its flags in `_init`, bound to `J`
  through `ScreenKeys.toggle_journal` and to `--open-menu=journal` through `menu_for`, which is
  the binding `screen_keys.gd`'s own header predicted would land there.
- `src/core/state/flag_query.gd` — **extracted, not copied.** `DialogueRunner._passes` was the
  only evaluator of `FlagTest`; a quest step asks the identical question, so the `match` moved to
  one file both call. A test fails if a second copy grows back in either.
- `data/quests/keepers_errand.tres` — ONE quest, two steps, plus 15 CSV rows.
- `tests/unit/quests_test.gd` — 49 outcomes, plan computed so authoring a second quest edits no
  number. 1081 → **1149** (49 here, 2 in `export_test.gd` for the fourth catalogue line, and 17 that
  `docs_test.gd` computed from the new worked quest example in `AUTHORING.md`).
- `tools/content_scenes.gd` — the tool split, below.
- Fourth redirect in `tests/framework/fixtures.gd` and a fixture quest in `fixture_content.gd`;
  `GameEnums.QuestState`; the fourth row in `CatalogueReport`; `--flag=` in `dev_stage.gd`;
  `docs/AUTHORING.md` § Add a quest.

**DERIVED, EXCEPT FOR TWO LATCHES, and the asymmetry is the design.** `flags.gd` says: if it can
be derived, derive it — and almost all of this is. Two things cannot be. That a quest **started**:
its start condition is a flag, and resetting that flag must not un-give a quest the player has
carried for three hours. That a quest **completed**: a step may test `AT_LEAST 3` on a counter, and
something decrementing it later must not reopen a finished quest. Those two, and only those two,
are what the save section holds — as **two lists of ids**, never an enum ordinal. The **current
objective is not latched**: it is a live question, so clearing the flag behind objective two brings
objective two back. Both halves are asserted, because a latch nothing tests is indistinguishable
from a cache.

**A COMPLETED QUEST GRANTS NOTHING, and that is a layer rule rather than a shortcut.** A
`reward_item` field would need `Inventory` and a player — both `gameplay` — inside a `systems`
tracker, and `src/` points downward only. It emits `quest_completed` and stops, which is the
reasoning that already keeps `Weather` from drawing rain and a `TriggerVolume` from naming its
consequence. Anything that wants to hand over an item listens; anything that wants to gate a
conversation tests the flag the last step tested, with no code at all.

**THE FOURTH REGISTRY CAME DUE ON A NOTE `schedule_db.gd` LEFT.** Its header said "three is a
pattern, four is a problem — if a fourth registry appears, that is the moment to reconsider." It
was reconsidered rather than ignored, and the verdict is to keep the copy: GDScript has no
generics, so a shared base could only cache `Resource` and hand it back untyped, making all four
accessors a cast at the call site — and static typing is non-negotiable #2, not a preference. What
is genuinely shared already is: `QuestDb` calls `ItemDb.resource_paths()` rather than copying the
`.remap` handling. The refactor that would pay is a base holding the cache plus a thin typed façade
each; that touches four registries and the four areas of the suite covering them, so it is **T3.1
on the board** rather than a paragraph here.

**`check_content.gd` was SPLIT, and the seam was already in the reasoning.** It stood at 237 of 250
and the quest checks did not fit. `tools/content_scenes.gd` now holds the scene *text* scans —
duplicate `object_id`, `_key` literals, the `[editable]` marker — which need no class registered
and keep working on a scene broken for an unrelated reason; what stayed asks the *registries* what
they loaded. Still ONE command and ONE CI rung, because it is a `RefCounted` the entry point
instantiates rather than a second `SceneTree` tool. 237 → 178 + 102. Fifth time the budget checker
has exposed a split that was already there.

**The quest checks print the flags rather than validating them,** and the line is drawn there
deliberately. A flag can be written from a scene, a conversation, a path action or another quest,
and the writer that matters most is a runtime one — `PersistentState` builds
`obj/<area>/<object>/<field>` at load. A checker that failed on any flag with no findable writer
would be wrong most times it fired, and a partial check that looks complete is the failure mode
this project exists to prevent. So they go in the build log where a reviewer reads them:

```
  quests: 1
     quest/keepers_errand   2 steps, starts on met/gardener is_true
        unlock              done when area/courtyard/gate_unlocked is_true
        dais                done when area/courtyard/dais_entered is_true
```

**PROVED RED, THEN GREEN — both gates, both the real failure shape (gotcha 23).** The exact output
is in `DEVLOG.md`. (1) A step's `summary_key` misspelled by one letter in the authored quest:
`check_content` exits 1 naming the quest, the step and the key; reverted, exit 0. (2) A second copy
of the comparison table planted back in `dialogue_runner.gd`: the suite exits 1 on *"and it no
longer carries its own copy of the comparison table"*, `1148 passed, 1 failed`; reverted,
`1149 passed, 0 failed`, exit 0.

**One defect, found by the capture and not by any gate.** `--flag=` was applied during argument
parsing, and `--new-game` **clears every flag** — so the first WP-08 capture photographed a journal
with no quest in it and every rung stayed green. `--flag` now waits for the area the way
`--open-menu` does. This is gotcha 31's family: not a rung blind to an error, but staging that ran
before the thing it was staging for.

**The input path was proved by a temporary probe and the probe was removed** (gotcha 15 —
`TestCase.run()` is synchronous and no assertion can press a key). Run windowed, quoted verbatim in
`DEVLOG.md`: `depth=0 top=NONE` → press `J` → `depth=1 top=journal` → press again → `depth=0
top=NONE`. `git diff src/systems/debug/` is empty.

**Two windowed captures, LOOKED AT, both at midday with `--new-game --shot-frame=70`.** The journal
over a live courtyard showing *Underway · The Keeper's Errand · — Unlock the north gate* with the
*New errand* toast up; and the same screen after all three flags with *Settled · The Keeper's
Errand · — Nothing left to do* and *The Keeper's Errand is settled*. **The `Button` styleboxes were
left unpopulated**: the journal did not force the decision — its rows are legible against the
shipped dark palette — and T2.2's reasoning for leaving them holds, so the gap stays stated rather
than guessed at.

**Deferred, with reasons, not silently.** A quest step **cannot read an item count**: `Inventory`
keeps counts, not flags, so "bring me three petals" is not authorable, and the original exit
criterion "completed by an item handover" is **not met** for that reason. The seam is a `Pickup` or
`ItemContainer` that writes a flag, which is a template change — recorded in
`ARCHITECTURE.md`'s limitations and in `AUTHORING.md` where an author would hit it, so nobody works
around it under `src/`. Also deferred: branching and failable quests, timed quests, rewards beyond
a flag, sorting and filtering in the journal, and map markers (WP-11).

**Ladder, all green.** `--headless --import` exit 0 with **zero** `SCRIPT ERROR` / `Parse Error`
lines; boot `0 warnings, 0 errors`; suite **1149 passed, 0 failed, 0 skipped**, exit 0;
`check_budgets`, `check_content`, `check_boundary` all exit 0 — and `check_boundary` now derives
`quest/keepers_errand` and `keepers_errand` as demo names and finds neither anywhere in `src/` or
`tests/`.

**CI green, run 33091433887, job logs read rather than the tick.** Full checkout **1149 passed, 0
failed, 0 skipped** with `quests: 1` in `check_content`; stripped template **1094 passed, 0 failed,
16 skipped** with `quests: 0` — the empty quest folder is not an error, which is the T1.2 finding
holding for the fourth registry. All three checkers PASS in both jobs. The push run (33091433975)
and the pull-request run (33091486449) are both green too.

**Commit:** `a00ddda` on `claude/wp-08-quests`, PR #16 — stacked onto `claude/t2-2-consumer-docs`
(#15) rather than `main`, matching the rest of the chain.

---

## WP-09 · Character depth — equipment — **DONE**

**Read:** `src/gameplay/character/` (all), `src/gameplay/interactables/gate.gd`,
`src/systems/audio/audio_director.gd`.
**Write:** an attribute container where adding an attribute is data not code; surface-aware
footsteps; equipment that changes traversal — a lantern that makes dark places enterable.
**Exit criteria:** the lantern gates an area, footsteps change with the surface underfoot.

**THE ROW WAS THREE PACKAGES AND IT WAS SPLIT, which is the board's own rule rather than a
shortcut.** "No package exceeds roughly 8 files or 500 new code lines. Over that, split it and add
a row." An attribute container, a surface system with audio, and equipment are three systems with
three sets of content, three test files and three captures. The equipment third was built because
it is the one with a CONSUMER: traversal already has a class that gates on a flag, so equipment had
somewhere to be proved the day it existed. `09b` carries the other two, each with its reason.

**EQUIPMENT OWNS NO DICTIONARY, and everything else follows from that.** A slot is a flag:

```
equip/<wearer_id>/<item id>          equip/player/item/brass_lantern
```

which is `PersistentState`'s `obj/<area>/<object>/<field>` and `Standing`'s `standing/<who>`
applied to a third case. Three consequences, and together they are the whole argument against a
`Dictionary[EquipSlot, StringName]` plus a save section:

1. **It is already saved.** No `SaveSystem.register`, no save version, no migration, and a new
   game clears it for free because `start_new_game()` clears flags.
2. **A gate can require it with no code.** A `requires_flag` pointing at one of those keys gates
   traversal on a held lantern, and `Gate` was NOT TOUCHED. Neither was `QuestStep`, nor
   `DialogueChoice`, nor `ClimbPoint` — so "carry a light to the dark place" is authorable as a
   quest step today. Same seam WP-08 built quests on, used a second time by a second system, which
   is the first evidence that the seam generalises rather than fitting one case.
3. **It is announced already.** `flag_changed` fires, so `QuestTracker` re-derives and a dialogue
   condition re-evaluates, and nothing had to learn that equipment exists.

The cost is stated rather than hidden: the key contains an item id, so an item id becomes a public
identifier the way an `object_id` is. Renaming an item's `.tres` brings it back stowed — the item
itself survives, because `Inventory` deliberately keeps counts whose definition vanished.

**THE ITEM STAYS IN THE BAG WHILE IT IS HELD**, and this is the load-bearing invariant. Moving it
out would make equipment a second place items live: `count_of()` would begin lying, and
`Gate.requires_item` would refuse a key that is in the player's hand. So equipping is purely a
flag, and the price is that losing the item has to stow it — `_revalidate`, bound to
`inventory_changed` rather than to `item_lost`, because that is the one signal every path emits
including a restored save. That invariant is what the planted violation below breaks.

**TWO @exports THAT HAD BEEN DECLARED, VALIDATED AND READ BY NOTHING.** Found while looking for
where an equip-gated gate says "you need a light": `Gate.locked_key` (since WP-01) and
`PathAction.refusal_key` (since WP-07) were both set by authored content, both checked by
`check_content`, and both dead — the prompt computed `refusal.<reason>` from the enum and never
asked. `PathAction.refusal_key`'s own comment claimed it was "shown for the LOW_STANDING refusal".
This is gotcha 2's shape exactly: a message that is merely WRONG looks the same as a message that
is right, so nothing failed. `interaction_refused` now carries a `message_key` — beside `args`, for
the same reason `args` travels there — and `Interactable.refusal_key(who, reason)` is the override.
An empty string means "compute it from the reason", which is what every object that has not
authored a line returns.

**Two defects the CAPTURE found and no gate could.** (1) The satchel screen redrew only on
`inventory_changed`, so equipping from anywhere other than a row press left a held item drawn as
merely carried — the first capture came back reading `Brass Lantern x1` with no marker while the
log said it was equipped. It now listens to `equipment_changed` too. (2) `--open-inventory` did
not wait for the area, so with `--new-game` it drew over the title screen. Third flag to need that
wait after `--open-menu` and `--flag`, and gotcha 32's family again.

**One engine surprise worth the gotcha list.** `Array[StringName].sort()` DOES NOT SORT
ALPHABETICALLY — it orders by the StringName's internal handle. Two fixture ids came back reversed
and the only trace was one failing assertion. `Inventory.ids()` already sorted through `String` for
this reason, which is what made it findable in a minute; `equipped_ids()` now does the same.

**Files.** `src/gameplay/character/equipment.gd` (82 code lines) · `GameEnums.EquipSlot` ·
`ItemDefinition.equip_slot` and `is_equippable()` · `Events.equipment_changed`, plus `message_key`
on `interaction_refused` · `Interactable.refusal_key` with overrides in `gate.gd` and
`path_action_point.gd` · `interact_prompt.gd` preferring the authored line ·
`inventory_screen.gd` (rows equip, and redraw on equipment) · `--equip=` in `dev_stage.gd` and the
`--open-inventory` wait · `scenes/characters/player.tscn` gains an `Equipment` node ·
`data/items/brass_lantern.tres` plus a pickup and an equip-gated `Gate` in the courtyard and 6 CSV
rows · `tests/unit/equipment_test.gd` (70 outcomes) · three equippable fixture items and an
`equip_slot` parameter on `FixtureContent.item()` · `docs/AUTHORING.md` § Make an item equippable.
1149 → **1224** (70 here, and 5 that `docs_test.gd` computed from the new worked example).

**`items_test.gd`'s hard-coded `3` became `FixtureContent.items().size()`**, on the same reasoning
as a computed plan: adding a fixture must not mean editing a number somewhere else.

**PROVED RED, THEN GREEN — both, with the real failure shape (gotcha 23).** (1) The gate's
`locked_key` misspelled by one letter in the authored scene: `check_content` exits 1 with
`courtyard.tscn:369 localization key 'object.gate.arch.lockd' is not in the CSV`; reverted, exit 0.
(2) The load-bearing invariant broken the way it would really break — `equip()` made to remove the
item from the bag: the suite exits 1, `1201 passed, 18 failed`, first failure
*"it is still carried — expected true, got false"*; reverted, `1219 passed, 0 failed`, exit 0.

**The input path was proved by a temporary probe and the probe was removed** (gotcha 15). Run
windowed: `PROBE focus='@Button@26' held=[]` → press → `held=[&"item/brass_lantern"]` → press again
→ `held=[]`. `git diff src/systems/debug/` carries only `--equip` and the `--open-inventory` wait.

**Three windowed captures at midday, LOOKED AT and READ rather than glanced at** (gotcha 28 — a
screen that merely looks fine is not evidence). The satchel showing
`Brass Lantern  x1   [in hand]` under *Tools* beside an unmarked `Rose Petal  x2` under *Materials*
— the discriminating pair, since a marker glued onto every row would look identical on one item.
The arch refusing with *"It is pitch dark beyond the arch, and you have no light in hand."* while
the lantern sits in the bag. And the same arch, same camera, same hour, one `--equip` different:
the blocker slab GONE and *"Lantern raised, the dark under the arch gives way."* up.
**The `Button` styleboxes were left unpopulated again** — the satchel's rows are legible against
the shipped dark palette, so it did not force the decision either.

**Deferred, with reasons, not silently.**
- **A quest step still cannot read an ITEM COUNT**, and equipment did not make it cheaper. Being
  HELD is a fact about one item, which is what a flag is; holding THREE OF something is a count,
  and both ways to expose it are real design decisions rather than an afternoon: an `Inventory`
  that mirrored `count/<item>` into `Flags` would write every carried item into the flag section
  as well as its own, and a `QuestStep` that read the bag directly would put `gameplay/Inventory`
  inside a `systems` tracker against the layer rule. It is **T3.3** on the board now rather than a
  line in three documents.
- **Attributes and footsteps** are `09b`, and the reason is stated there rather than here.
- No equipment SCREEN — the satchel is where equipping happens, and a second window listing five
  slots with one thing in them would be a UI for content that does not exist.
- No stat effect from equipment: nothing reads a stat yet, which is `09b`'s problem.
- Combat is still not a thing. `EquipSlot` has no weapon and no armour value and will not get one.

**Ladder, all green.** `--headless --import` with **zero** `SCRIPT ERROR` / `Parse Error` lines;
boot `0 warnings, 0 errors`; suite **1224 passed, 0 failed, 0 skipped**, exit 0; `check_budgets`,
`check_content` and `check_boundary` all exit 0 — and `check_boundary` derives
`item/brass_lantern` and `brass_lantern` as demo names and finds neither in `src/` or `tests/`.

**CI green, run 33095187525, job logs read rather than the tick.** Full checkout **1224 passed, 0
failed, 0 skipped** with `quests: 1` in `check_content`; stripped template **1169 passed, 0 failed,
16 skipped** with `quests: 0` — the equipment case runs in BOTH, because it is fixtures all the way
down and skips nothing. All three checkers PASS in both jobs. The push run (33095176524) and the
pull-request run (33095253385) are green too.

**Commit:** `1b3d799` on `claude/wp-09-character`, PR #17 — stacked onto `claude/wp-08-quests`
(#16) rather than `main`, matching the rest of the chain.

---

## WP-09b · Character depth — attributes and surfaces — **DONE**

The two thirds of the original WP-09 row that were split out. Both are real; neither had a consumer
the way equipment did, and that is the whole reason they went second.

**Read:** `src/gameplay/character/player_controller.gd`, `src/gameplay/character/standing.gd` (the
namespace-over-Flags shape), `src/gameplay/character/equipment.gd` (the same shape, applied),
`src/systems/audio/audio_director.gd`, `src/gameplay/world/surface_wetness.gd` (something already
walks every material in an area), `src/core/util/layers.gd`.
**Write:** an attribute container where adding an attribute is DATA, not code, and a decision
FIRST about what reads one; surface tagging on area geometry, and footsteps that change with it.
**Exit criteria:** an attribute changes something observable and persists; the surface under the
player is reported correctly on at least two materials, and the step sound follows it.

**IT WAS TAKEN OVER T3.1 AND T3.3, AND THE REASON IS `TEMPLATE.md`'s REPLACEMENT RULE.** T3.1 is a
refactor of five copies of one scan — genuinely worth doing, and it changes nothing a consuming
game can observe. T3.3 is depth in a system that already has a proof. This row was the last one
in the catalogue holding TWO systems with no implementation at all, so it is the only one of the
three that is breadth rather than polish. T3.1 remains the strongest of the two that are left, and
its arithmetic is unchanged: still five copies, still five places to fix one scan bug.

**THE FIRST QUESTION WAS "WHAT READS ONE", AND IT WAS ANSWERED BEFORE ANYTHING WAS WRITTEN.** The
row said so and it was the right instruction: 17 of the 23 settings have no consumer, and WP-09
found `Gate.locked_key` and `PathAction.refusal_key` declared, validated by a content gate and read
by nothing for six packages. So `Attributes` ships with EXACTLY ONE consumer,
`PlayerController.current_speed()`, and two structural decisions exist to stop that number growing
silently:

1. **There is no registry, no `AttributeDef` and no enum of names.** Any StringName is an attribute
   the moment something writes it, so declaring the fiftieth costs no code — ADR-0006's test met
   with no sixth directory scan, which `area_db.gd`'s header explicitly warns against.
2. **An attribute's NAME is a const on its consumer, never on the container.**
   `PlayerController.PACE` sits beside the line that reads it. So an attribute nobody reads has
   *nowhere to be written down*, and `attributes.gd` cannot accumulate a table of good intentions.
   That is the whole of the design: a rule about where a name lives, not a mechanism.

**A FIFTH NAMESPACE OVER `Flags`, AND IT WAS REACHED FOR FIRST, AS WP-11 SAID TO.** `attr/<who>/<name>`
after `obj/<area>/<object>/<field>`, `standing/<who>`, `equip/<wearer>/<item>` and `map/<area>`.
Same three consequences, asserted rather than assumed: already saved with no register, version or
migration; already cleared by a new game; already announced on `flag_changed`, so a quest step can
test an attribute today. Same stated cost, too: the key contains a character id, so renaming a
carrier resets its attributes on an old save.

**A VALUE IS A STEP, NOT THE NUMBER.** Clamped to ±4, worth 0.125 of the base each, so the tuned
`walk_speed = 3.2` in `player_controller.gd` stays the truth and a save file never contains a
walk speed. `Standing`'s clamp for `Standing`'s reason — the ceiling is the design.

**A SURFACE IS ONE METADATA KEY, INHERITED FROM THE NEAREST TAGGED ANCESTOR.** `metadata/surface`
on a body, or on anything above it. The alternatives were a component per floor tile (a node per
tile), a group (one flat namespace shared with `navmesh_source`, where a typo becomes a second
surface silently) and an enum (**a list of surface names in `src/`, which `check_boundary` fails
the build over**). Inheritance is what makes it cheap: the courtyard tags `Terrain` once and
overrides the two floors that differ, and the third surface the probe reported was the inherited
one.

**A STEP'S SOUND IS DERIVED FROM THE SURFACE'S NAME.** Not looked up in a table, because a table
mapping a name to a timbre is the same boundary violation as the enum, and it would mean a game
that authors `sand` gets silence until someone edits `src/`. Two axes, brightness and decay,
derived from two salted hashes of the name. Art is deferred and audio is art, so the burst is
generated exactly the way `AmbienceBed` generates its rain, and `stream_for()` is the one function
a game with real recordings replaces.

**THE PROBE FOUND A DEFECT THAT NOTHING ELSE COULD HAVE, AND IT IS GOTCHA 2 WITH A SPEAKER ON IT.**
The first windowed run reported `playing=true` on all three surfaces with every rung green — and
grass came out at brightness 0.452 against stone's 0.446, which is *the same sound*. The cause is
that **`String.hash()` mixes its low bits weakly**: `"grass"` hashes to 260508453 and `"stone"` to
274826446, wildly different numbers whose last three digits are 453 and 446, so `hash() % 1000`
clusters short names of similar length. A step that plays is not a step that *follows*. Fixed with
an avalanche in `_spread` — one multiply and two shifts — which moves the same pair to 796 and 572,
and the regression assertion demands a MARGIN rather than mere inequality, because inequality is
exactly what the broken version passed. New gotcha 36.

**WHAT IS ASSERTED AND WHAT IS QUOTED, SAID OUT LOUD RATHER THAN IMPLIED.** A footstep is the one
claim this ladder cannot see at all: not visual, so no capture reads it; not synchronous, so no
assertion reaches it; and headless the audio driver is `Dummy`, where every `play()` leaks
(gotcha 20). So the file is split the way `SurfaceWetness` split for drying. Assertable and
asserted: `travel()` (the stride accumulator, remainder CARRIED), `GroundSurface.of_node()` (the
walk up the tree) and `brightness_for()` / `decay_for()` (pure functions of a name). Quoted from a
windowed run: the raycast, the frame loop and the `play()`.

**THE ATTRIBUTE NEEDED NO NEW STAGING FLAG**, which is the namespace paying for itself a fifth
time. `--flag=attr/player/pace:4` already works, already waits for the area (gotcha 32's fix), and
already goes through `_settle_stable` (gotcha 35). `dev_stage.gd` stayed at 247 of its 250 lines
and did not have to split.

**Files.** `src/gameplay/character/attributes.gd` (21 code lines) ·
`src/gameplay/world/ground_surface.gd` (26) · `src/gameplay/character/footsteps.gd` (115) ·
`PlayerController.character_id`, `PlayerController.PACE` and `current_speed()` made public ·
a `Footsteps` node in `player.tscn` · three `metadata/surface` tags in `courtyard.tscn` and one in
`lantern_hall.tscn` · `tests/unit/character_depth_test.gd` (56 outcomes) ·
`docs/AUTHORING.md` § Tag the ground you walk on. No new signal, no new autoload, no new registry,
no new CSV row — there is no player-facing text in either system.
1298 → **1355**.

**PROVED RED, THEN GREEN — three times, each with the real failure shape (gotcha 23).**
(1) `const HOME_GROUND := &"courtyard"` in `footsteps.gd`: `check_boundary` exits 1 with
`res://src/gameplay/character/footsteps.gd:54 names demo content 'courtyard' (from
res://data/areas/courtyard.tres)`; reverted, exit 0.
(2) The consumer broken the way it would really break — `current_speed()` made to return the gait
speed and ignore the attribute, which is precisely the declared-and-unread failure this package
exists to avoid: the suite exits 1 with `1352 passed, 3 failed`, naming *"a raised pace is
measurably faster — expected true, got false"*; reverted, `1355 passed, 0 failed`, exit 0.
(3) The inheritance walk stopped after one node — the break that would silently lose the demo's
third surface: exits 1 with *"an untagged body inherits from the root — expected fixture_hard,
got "*; reverted, exit 0.

**The probe was temporary and was removed** (gotcha 15). Run windowed, `git diff
src/systems/debug/` empty afterwards:
```
PROBE audible=true driver=WASAPI
PROBE at (4.0, 0.2, 4.0)    grounded=true surface='grass' brightness=0.733 decay=2.13 playing=true steps=1
PROBE at (0.0, 0.6, -2.0)   grounded=true surface='wood'  brightness=0.841 decay=4.68 playing=true steps=2
PROBE at (-8.5, 3.4, -2.5)  grounded=true surface='stone' brightness=0.550 decay=3.02 playing=true steps=3
PROBE pace=0 speed=3.200 moved=2.861 m in 60 frames, steps=4
PROBE pace=4 speed=4.800 moved=4.687 m in 60 frames, steps=7
```
The first three are the surface criterion: grass and wood from their own tags, stone INHERITED from
`Terrain`. The last two are the attribute criterion, driven by real `MOVE_UP` input over the same
60 physics frames — 2.861 m against 4.687 m, and 4 steps against 7, because a faster walk covers a
stride sooner.

**One windowed capture, LOOKED AT** — the courtyard at 12:00 after the metadata edits, confirming
the three tagged materials are the three the player actually walks on and that nothing about the
scene moved: grass underfoot, the wood dais with the keeper beside it, stone pillars and the back
wall. `build/shots/wp09b_courtyard.png`.

**WHAT WAS NOT BUILT, AND SAID RATHER THAN DROPPED.** No footstep PARTICLES — the inventory row
asked for "step audio and particles", and `Footsteps.current_surface()` is the hook a puff would
listen to, which is why it is a query and not a signal (nothing needs a signal yet). No second
attribute, and no consumer for one: that is the rule, not an omission. No character sheet screen,
no attribute that gates an interaction, and no surface that costs anything to cross — a slow
surface is a `PlayerController` change and belongs with whoever wants one.

**Commit:** `da126d9` on `claude/wp-09b-attributes`, PR #19 — stacked onto `claude/wp-11-worldmap`
(#18) rather than `main`, matching the rest of the chain.

---

## WP-10 · Crafting and gathering

**Read:** `src/content/items/`, `src/gameplay/interactables/pickup.gd`,
`src/gameplay/character/inventory.gd`, `src/systems/world_clock/clock.gd`.
**Write:** harvestables with a regrowth timer keyed to the clock, and recipes as content data.
**Exit criteria:** gather, wait, it regrows; craft, and the recipe consumes and produces
correctly; all persisted.

---

## WP-11 · World map and fast travel — **DONE**

**Read:** `src/systems/scene_director/director.gd`, `src/gameplay/world/area_root.gd`, WP-02/03.
**Write:** an `AreaDef` content resource, a region map with discovery, travel points.
**Exit criteria:** discover an area, travel to it, discovery persists.

**IT WAS TAKEN OVER T3.1, T3.3 AND WP-09b DELIBERATELY**, and the reason is the one that put
WP-08 first: this was the last system in the catalogue with NO PROOF AT ALL, and `TEMPLATE.md`'s
replacement rule is breadth of systems with one shallow proof each. The three alternatives are
all real and all narrower — a refactor, a gap in an existing system, and half of a split row —
and each of them improves something that already works. This built the last thing that did not.

**DISCOVERY IS A FLAG, AND IT OWNS NO STORE.** A known area is:

```
map/<area id>                        map/lantern_hall
```

which is `PersistentState`'s `obj/<area>/<object>/<field>`, `Standing`'s `standing/<who>` and
`Equipment`'s `equip/<wearer>/<item>` applied to a FOURTH case. **WP-09's section said to copy
this shape and it copied cleanly**, which is now three independent systems on one namespace
convention rather than two and a coincidence. The same three consequences, and they are the whole
argument against a discovery store with a save section:

1. **It is already saved.** No `SaveSystem.register`, no version, no migration, and a new game
   clears it for free. That is what makes "discovery persists across a save and a reload,
   including from the far side of an area that is no longer loaded" true with no code at all: the
   flag never lived in the area.
2. **Anything can reveal a place with no code.** `--flag=map/lantern_hall:true` is the second
   capture, and a `DialogueChoice` effect, a `TriggerVolume` or a `Lever` writes exactly the same
   key. Nothing was touched to make that work. The key runs the other way too: a `Gate` with
   `requires_flag = &"map/<id>"` is a road that opens once you know where it goes.
3. **It is announced already.** `flag_changed` fires, so a quest step testing "have you found the
   orchard" works today.

The cost is stated: the key contains an area id, so renaming an area's folder makes an old save
forget it was found. Same price `Equipment` pays for an item id, and smaller than the
alternative, which writes the same id into a save section of its own anyway.

**THE MAP SCREEN NAMES NO AREA AND NO POSITION, WHICH IS WHAT THE BOUNDARY GATE WOULD HAVE
CAUGHT.** Every dot is drawn at the `map_position` its own `.tres` declares, in normalised 0..1
space so the same authored number is right at every window size. Proved by planting
`const HOME := &"courtyard"` in `map_screen.gd`: `check_boundary` exits 1 naming the file, the
line and `res://data/areas/courtyard.tres` as the source — the gate derives area ids from the new
registry as well as from `scenes/areas/`.

**TRAVEL ASKS AND DOES NOTHING ELSE.** `WorldMap.travel_to` emits `Events.area_change_requested`
and stops, exactly as `AreaDoor` does, so `Director` still owns every transition and its guard.
Four refusals, each logged rather than silent: not on the map, not found, already there, already
moving. The headline assertion is the one `transitions_test` makes about a door — one request,
naming the area and the AUTHORED arrival spawn, with the player unmoved and nothing loaded.

**A FIFTH REGISTRY, AND IT IS EVIDENCE FOR T3.1 RATHER THAN AGAINST IT.** `AreaDb` is the fifth
copy of the same thirty lines of scan-and-validate. WP-08 reconsidered and kept the fourth copy
with reasons that have not changed — GDScript has no generics, so a shared base could only cache
`Resource` and hand it back untyped. What changed is the arithmetic: five copies is five places
to fix a scan bug, and `area_db.gd`'s header says so and points at the board row.

**THE ID HAS NO PREFIX**, unlike `item/` and `quest/`. Those prefixes make a save file
self-describing about things that live only in a save file; an area id is already a public
identifier, because it is a folder name. A `map/orchard` id would have put a translation table
between `AreaDb` and `Director`, and a translation table is a second place the truth lives.

**WHAT A "TRAVEL POINT" TURNED OUT TO BE.** The row asked for one. The arrival point is authored —
`AreaDef.arrival_spawn`, and the suite fails if it names a marker no area has. A DEPARTURE point,
a kiosk you must stand at to fast travel, is a game's policy rather than the template's: it is a
restriction on a mechanism, it needs content the demo does not have, and it would be one
interactable emitting a request the map screen already emits. Not built, and said rather than
quietly dropped.

**TWO GAPS FOUND IN OTHER PEOPLE'S WORK, both one line.** `journal_screen.gd` was never added to
`art_contract_test.gd`'s `STYLED_SCREENS`, whose own comment says "a sixth screen belongs on this
list" — so the regression gate that stops a colour being written down again could not see the
journal at all. Both it and the map are on the list now. And `docs/NEW_GAME.md` never listed
`data/quests/`; it now lists that and `data/areas/`.

**ONE NEW PALETTE ENTRY, AND IT IS THE FIRST SINCE T2.1 WROTE THE FILE.** An undiscovered marker
has to be VISIBLE and clearly lesser, and `dim` is a translucent black that would have drawn
nothing against the plate. `UiPalette/colors/muted`, one line in `ui_theme.tres`, and the screen
reads it by name — the seam working exactly as T2.1 said it would. **The `Button` styleboxes were
left unpopulated for the fourth time**: the map's markers are Buttons over an opaque plate and are
legible against the shipped dark palette, so this screen did not force the decision either.

**A STAGING RACE, FOUND BY THE THIRD CAPTURE AND FIXED WITH GOTCHA 21's SHAPE.** `--goto` and
`--open-menu` both begin by waiting for the first area, so they come out of that wait on the same
frame: if the menu opens first, the travel `--goto` is about to request unwinds it, and the
capture is of nothing with every rung green. A fixed number of extra frames only moves the race.
`dev_stage._settle_stable(20)` requires twenty CONSECUTIVE settled frames and resets its count
the moment a transition starts, which cannot be won early. Fourth staging flag to need a wait,
and the first to need a persistent one.

**Files.** `src/content/world/area_def.gd` (16 code lines) · `src/content/world/area_db.gd` (61) ·
`src/systems/world_map/world_map.gd` (67) · `src/ui/screens/map_screen.gd` (153) ·
`Events.area_discovered` · `ScreenKeys.toggle_map` and `MapScreen` in `menu_for` ·
`AreaDb` in `CatalogueReport` and in `Fixtures` · `_check_areas` in `check_content` ·
`_settle_stable` in `dev_stage.gd` · `UiPalette/colors/muted` · a `WorldMap` node in
`game_root.tscn` · `data/areas/courtyard.tres` and `data/areas/lantern_hall.tres` plus 6 CSV rows ·
`tests/unit/world_map_test.gd` (59 outcomes) · two fixture `AreaDef`s ·
`docs/AUTHORING.md` § Put an area on the world map.
1224 → **1298** (59 here, 2 in `export_test` for the fifth catalogue line, 4 in
`art_contract_test` for the two screens added to `STYLED_SCREENS`, and 9 that `docs_test.gd`
COMPUTED from the new worked example in `AUTHORING.md`).

**PROVED RED, THEN GREEN — three times, each with the real failure shape (gotcha 23).**
(1) An `AreaDef`'s `name_key` misspelled by one letter: `check_content` exits 1 with
`lantern_hall name_key 'area.lantern_hall.nam' is not in the CSV`; reverted, exit 0.
(2) The load-bearing invariant broken the way it would really break — `discover()` made to keep a
`Dictionary` instead of writing the flag: the suite exits 1 with `1288 passed, 10 failed`, first
failure *"and the whole of that is one flag — expected true, got false"*, plus the ErrorWatch
catching an out-of-bounds read in a block that never got its signal and the plan reporting
`planned 59 outcomes and produced 57`. All three mechanisms fired on one break; reverted,
`1298 passed, 0 failed`, exit 0.
(3) `const HOME := &"courtyard"` in `map_screen.gd`: `check_boundary` exits 1 with
`res://src/ui/screens/map_screen.gd:33 names demo content 'courtyard' (from
res://data/areas/courtyard.tres)`; reverted, exit 0.

**The input path was proved by a temporary probe and the probe was removed** (gotcha 15). Run
windowed: `PROBE after M: top=map depth=1` → `PROBE focus='@Button@27' text='Lantern Hall'` →
`PROBE after M again: top=NOTHING depth=0` → M, then Enter →
`[map] Travelling to 'lantern_hall' (spawn 'from_courtyard')` →
`PROBE after Enter: area=lantern_hall depth=0`. The stack unwound itself on the travel, which is
why `MapScreen` does not close itself. `git diff src/systems/debug/dev_capture.gd` is empty.

**Three windowed captures at midday, LOOKED AT and READ rather than glanced at** (gotcha 28 — a
map with the wrong area marked still looks like a map). All three at 960x540, `--new-game`,
`--shot-frame=100`, `--time=12:00 --freeze-time`.

1. `--open-menu=map`: a large WHITE dot low on the plate reading *"Rose Courtyard · you are
   here"*, and a small GREY dot above it reading *"???"*. The DISCRIMINATING pair — an
   undiscovered place drawn differently from a discovered one in the same shot, which a map whose
   dots all looked alike could not show.
2. `--flag=map/lantern_hall:true --open-menu=map`: same camera, same hour, ONE FLAG different.
   The grey `???` is now a GOLD dot reading *"Lantern Hall"* with the focus ring on it, and the
   courtyard marker has not moved or changed. That is the seam photographed: a flag written from
   outside put a place on the map.
3. `--goto=lantern_hall --open-menu=map`: the two states have SWAPPED. Lantern Hall is the white
   *"you are here"* marker, Rose Courtyard is the gold selectable one — **from the far side of an
   area that is no longer loaded**, over the hall's warm interior rather than the courtyard's
   daylight, which is how the shot also proves the travel really happened.

**Ladder, all green.** `--headless --import` with **zero** `SCRIPT ERROR` / `Parse Error` lines;
boot `0 warnings, 0 errors` with `areas: 2 found in res://data/areas` and `World map ready over 2
mapped area(s)`; suite **1298 passed, 0 failed, 0 skipped**, exit 0; `check_budgets`,
`check_content` and `check_boundary` all exit 0. A stripped template, built by hand the way the CI
job builds it, ran **1230 passed, 0 failed, 19 skipped**, exit 0, with all three checkers passing
and `mapped areas: 0` — the map case skips exactly one assertion there and says which.

**Deferred, with reasons, not silently.**
- **A departure-side travel point**, for the reason above: it is a restriction on a mechanism,
  and it is a game's policy rather than the template's.
- **Objective markers on the map.** `Events.quest_advanced` has an emitter as of WP-08 and
  `MapScreen` already redraws on facts, so this is a listener and one more marker state — but it
  is a second system's proof on this package's screen, and the board has a row for it.
- Fog of war, zoom and pan, custom map art, travel costs, travel time, mounts. Art is deferred
  indefinitely, so a map drawn from a `ColorRect` per place is the map this template ships.
- **A second region or a third area.** `TEMPLATE.md` is explicit: two areas is what the demo has
  and two areas is enough. A third would be the retracted rule winning an argument.
- Combat is still not a thing.

**CI green, run 33262997072, job logs read rather than the tick.** Full checkout **1298 passed, 0
failed, 0 skipped** with `quests: 1` and `mapped areas: 2` in `check_content`; stripped template
**1230 passed, 0 failed, 19 skipped** with `quests: 0` and `mapped areas: 0`. Every rung green in
both jobs, and both numbers match the local runs exactly.

**Commit:** `cf3f3a1` on `claude/wp-11-worldmap`, PR #18 — stacked onto
`claude/wp-09-character` (#17) rather than `main`, matching the rest of the chain.

---

## WP-12 · Menus — **DONE**

**Read:** `src/ui/root/ui_root.gd`, `src/core/state/settings.gd`, `src/core/save/save_system.gd`,
`src/systems/input/actions.gd`, `src/core/boot/game_root.gd`.
**Write:** main menu (new / continue / quit), settings screen covering every row in
`Settings.DEFAULTS`, save-and-load screen with slot headers, key rebinding, controller navigation.
**Exit criteria:** the whole game reachable and playable on a gamepad, rebinding persists, and
`GameRoot` no longer boots straight into an area.

**Closed 2026-08-26**, commit `094d4dc`. All three exit criteria met. A `MenuScreen` base plus
five menus, `KeyBindings` for the override file, `Director.start_new_game()`,
`SaveSystem.latest_slot()`, two bus signals, and a `GameRoot` that emits `main_menu_requested`
instead of loading `courtyard`. 717 assertions (was 460), boot `0 warnings, 0 errors`, both
checkers exit 0, four windowed captures looked at.

Controller navigation needed no gamepad code: a `VBoxContainer` of `Button`s answers `ui_up`,
`ui_down` and `ui_accept` already, so no screen owns a cursor. Proved with a real-input probe,
quoted verbatim in `DEVLOG.md`.

**Three bugs the engine caught and no static gate could:** a menu backed out of had no focused
row so a gamepad did nothing at all (`UiScreen._opened` had never meant what its docstring said);
two translucent screens stacked printed through each other; and
`InputEventJoypadButton.as_text()` is sixty characters wide and ran off the side of a menu.

**Honestly over budget:** 11 files and roughly 700 new code lines, against the board's "about 8
files or 500". Landed whole rather than split, because the five menus share one base and one CSV
block and a half-landed menu set is a game with no way back to the main menu.

**Deferred:** thirteen settings still have no runtime consumer (WP-13/WP-15), runtime language
switching, a duplicate-binding warning, and per-device button glyphs.

---

## WP-13 · Presentation — **DONE**

**Taken out of board order**, from WP-05's tip. WP-06 through WP-12 are still open, and this
package touched nothing they own: five new files, plus `Audio.beds`, two capture flags, one
node in each area scene, and nine CSV rows.

**Read:** `src/systems/weather/weather.gd`, `src/gameplay/world/environment_driver.gd`,
`src/systems/audio/audio_director.gd`.

**Wrote**
- `src/systems/weather/wetness_model.gd` — `WetnessModel`. Pure `RefCounted`: 0..1, rises over
  eight seconds of rain and falls over twenty-six. Pure because drying is the only part of
  the weather visuals with memory, and gotcha 10 means no assertion can wait for a frame.
- `src/gameplay/world/precipitation.gd` — `Precipitation`. One `GPUParticles3D` per kind that
  generates its own mesh, materials and snowflake texture. **Told a weight; never polls
  Weather.**
- `src/gameplay/world/weather_visuals.gd` — `WeatherVisuals`. One node per area. Owns the
  `MIX` table, follows the player, cross-fades on `Weather.blend()`, steps the wetness, sets
  the ambience levels, and toasts the change. **Decides nothing.**
- `src/gameplay/world/surface_wetness.gd` — `SurfaceWetness`. Darkens and clearcoats an area's
  materials, on private duplicates so wetness cannot outlive the area.
- `src/systems/audio/ambience_bed.gd` — `AmbienceBed`, as `Audio.beds`. Named layers on
  procedurally generated filtered noise, because there is no audio in the project.
- `dev_capture.gd`: `--wet=<0..1>` and `--dry-for=<seconds>`.
- `tests/unit/presentation_test.gd` — 47 assertions. 460 -> 507.

**Interior lighting was already done** in WP-04 and was deliberately not rebuilt.

**Exit criteria — met.** Import clean; boot `0 warnings, 0 errors`; 507 assertions pass and a
deliberately broken one exits 1; `check_budgets` and `check_content` both exit 0. Seven
windowed captures at 13:00 with time and weather frozen, each one opened and looked at: clear,
rain and storm are unmistakably three different images, and a soak-to-dry triptych at wetness
1.0 / 0.5 / 0.0 under an unchanged clear sky shows the ground darkening and coming back.

**Commit:** `8ebc7f8` on `claude/wp-13-presentation`. See `docs/DEVLOG.md`, entry
`2026-08-26 — WP-13`.

---

## WP-14 · Dev tools and hardening — **DONE (the hardening half)**

**Read:** `tools/`, `src/systems/debug/dev_capture.gd`, `tests/`.

**The row as written, and what changed about it.** It asked for four things: an in-game debug
console, a performance overlay, "a smoke test that drives **the whole demo** through public APIs",
and the hard-coded-string audit. Two of those were re-framed or split before any code was written,
both in this commit, and neither quietly.

### The re-framing: a smoke test drives A GAME, not THE DEMO.

"Drives the whole demo" would have put `courtyard`, `keeper` and `rose_key` into a permanent gate
on the ladder. That is precisely the coupling `tools/check_boundary.gd` exists to prevent, arriving
through the back door of a test — and the gate would in fact have caught it, because
`check_boundary` has scanned `tests/unit/` since T1.3. T1.3 spent an entire package unwelding the
suite from the demo, and a smoke test written to the row's letter would have grown that welding
straight back, with "end to end" as the excuse. `TEMPLATE.md` and `TESTING.md` both already say a
test builds its own content.

So `tests/unit/smoke_test.gd` composes its session from `tests/framework/fixtures.gd` and names no
content at all. Its ONE game-shaped block asserts that `GameConfig.first_area()` resolves to a real
scene — never what that area is called — and `skip`s, counted, in a checkout with no game in it.

**And "end to end" cannot mean what it sounds like, for a reason the row could not have known.**
`TestCase.run()` is synchronous (TESTING.md rule 2), so no assertion can await a frame, a threaded
load or a keypress — a smoke test here cannot travel between areas or press a button. What it can
be, and is, is the CHAIN: a run begins and empties the bag, a flag written starts a quest, items
gathered publish their counts, a counted objective notices, something is picked up and put in hand,
time is skipped, and the whole session is saved, wiped and restored with the quest still settled.
Every one of those seams has its own case already; **this asserts that they compose**, which is the
one thing a per-system case cannot see.

### The split: the row named four things, which is over the size limit.

Same reasoning that split WP-09, and the row's own title was the seam. **Hardening** — the two
gates and the shutdown fix — shipped here. **Dev tools** — the console and the overlay, both UI
surfaces needing a screen, an action binding, localization keys and a windowed capture each — are
the new **WP-14b** row. Building all four would have been four half-finished things, which is the
outcome the 8-file limit exists to prevent.

### `Director` now drains its own loader thread, and the payoff was not the predicted one.

The defect was real and reproduced at five frame counts (`--new-game --quit-after 8/12/16/20/25`):
quitting while a threaded load was in flight tore the loader thread down inside the text parser,
which then printed **`Parse Error` for files that parse perfectly** — `courtyard.tscn`,
`wood.tres`, `gate.tscn` — plus leaked RIDs and 10-19 leaked ObjectDB instances, *after* the run
had already logged `0 warnings, 0 errors`. **Gotcha 22 with the polarity reversed:** not an error a
rung cannot see, but a FALSE error poisoning the `Parse Error` grep that rung 2 uses as this
project's compile check.

**Its real cost was a permanently weakened gate, and that is the finding.** CI's rung 3 read only
the LAST LINE of its boot log, carrying a comment that said a whole-log grep "would be a flake
generator" — so the single most load-bearing check on the ladder was switched off on that rung, on
purpose, correctly, for as long as the defect lived. A live defect had bought itself a hole in the
gate that would have caught its relatives. That generalises, and is now gotcha 41.

The fix is `Director._exit_tree()`. **There is no cancel** — checked against `--doctool`, which
gives `load_threaded_request`, `load_threaded_get_status` and `load_threaded_get` and nothing that
abandons a request — so the only clean end is to WAIT, and `load_threaded_get()` blocking is
undocumented in the dump and therefore **measured**: 118-197ms for the demo's larger area, paid
once, on the way out. `NOTIFICATION_EXIT_TREE` was measured too, rather than assumed: with a load
in flight it arrives *before* the session's own closing log line, `NOTIFICATION_PREDELETE` arrives
after it, and `NOTIFICATION_WM_CLOSE_REQUEST` never arrives at all, because headless has no window.
After the fix: **zero parse errors, zero RID leaks, zero ObjectDB leaks at all five frame counts.**
CI's rung 3 now greps its whole log — a STRONGER rung, not a faster one, and the distinction
matters because editing a workflow to make a rung pass is forbidden and this is the opposite.

**The row predicted the fix would let the boot timeout drop, and it does — but not for the row's
reason, which was stale rather than merely incomplete.** Gotcha 13 said 120 frames were needed
because the boot raced a threaded load. Gotcha 31 says a plain boot stops at the MAIN MENU and
never enters an area, so it was never racing anything; gotcha 13 was written before WP-12 added the
menu and had been wrong ever since. **Measured, and this is the control:** `--quit-after 30` and
`--quit-after 120` produce byte-identical logs — 29 lines each, same content, both
`0 warnings, 0 errors`, and both were already clean *before* the fix. So the local boot rung is
now 30, justified by the measurement rather than by the fix; CI keeps 300, because a shared runner
is slower, a headless frame costs milliseconds, and a rung that quits before the boot finishes
would report clean about work it never did. Gotcha 13 is rewritten to say all of this.

### The string audit, and why it is NOT the tool `check_content.gd` refused.

`check_content.gd`'s header already turned down a general hard-coded-string audit, in writing, and
that refusal is correct: *"telling a player-facing literal from a log message or a flag key needs
semantics a text scan does not have, and a partial tool that looks complete is how 409 passing
checks happened."* Nothing in a line of text says whether `"world"` is a log category, a flag
namespace or a sentence for a player.

So `tools/check_strings.gd` never inspects a literal and guesses. Both its checks are anchored at a
**sink** or a **declaration**, where the semantics are structural:

1. **The sink rule.** The right-hand side of a `.text` / `.tooltip_text` / `.placeholder_text` /
   `.title` assignment either passes through `tr()` or contains no string literal at all. Whatever
   reaches `.text` is on screen *by construction*, whatever it contains — so no opinion about any
   individual string is needed. `label.text = text_value` passes on holding no literal;
   `button.text = tr(A if held else B).format({"item": x})` passes on the `tr()`, which is what
   makes the `.format()` dictionary key harmless rather than something the scan must parse. All
   four property names verified against `--doctool` for 4.7.2, and matched with a trailing `" = "`
   so `text_direction` and `text_overrun_behavior` — enums, not text — are not swept in.
2. **The key rule, and this is the half with teeth.** Every `*_KEY` const under `src/` names a real
   row in `strings.csv`. **71 of them, and nothing had ever checked one:** `check_content` validates
   the keys authored in `.tres` content, and `items_test.gd`'s enum loop covers the two COMPUTED
   families (`verb.*`, `refusal.*`). A const key sat in neither. `*_PREFIX` deliberately does not
   qualify — a prefix is completed at runtime — and a key holding `%` is a pattern the scan cannot
   follow, so it is COUNTED AND PRINTED rather than silently skipped, on `check_boundary`'s
   precedent. There is exactly one: `weather.%s`.

**The second rule closes a hole that was measurably live.** With `notify.item_takne` planted — one
transposition in the toast every pickup and every chest shows — `check_content` **PASSED**,
`check_boundary` **PASSED**, and all **1,517 assertions PASSED**. tr() returning its own argument
is not an error, so the player would simply have read `notify.item_takne` on screen forever. That
is this project's founding failure mode, still live at 1,517 assertions, found by building the gate
that looks for it.

### Both gates proved red with the real violation, and one plant caught the TEST.

Gotcha 23, and it earned its keep twice.

- **Sink rule.** `label.text = "No items"` planted in `inventory_screen.gd:228`:
  `!! res://src/ui/screens/inventory_screen.gd:228 assigns a literal to .text with no tr(): "No items"`,
  `FAIL — 1 string violation(s)`, exit **1**. Removed → `PASS`, exit 0.
- **Key rule.** `notify.item_taken` → `notify.item_takne` in `pickup.gd:24`:
  `!! res://src/gameplay/interactables/pickup.gd:24 TAKEN_KEY = 'notify.item_takne' has no row in res://localization/strings.csv`,
  exit **1**. Removed → `PASS`, exit 0. This is the plant that was also run against the rest of the
  ladder, with the result quoted above.
- **The smoke test**, planted by deleting `Inventory`'s `game_started` subscription — the real way
  a new game would stop emptying the bag: four of its assertions went red and cascaded down the
  chain exactly as a smoke test should, `1539 passed, 1 failed`, exit 1. Restored →
  `1540 passed, 0 failed`.

**And the third plant found a defect in the new test rather than in the code.** The smoke test's
save/load block carried a comment claiming it asserted the save-participant ORDER — T3.3's
invariant, that a derived count must be republished on `game_loaded` because `Flags._apply_save`
wipes the store from underneath it. Deleting that subscription, which is exactly how the invariant
would really be lost, left the assertion **GREEN**: the test's own wipe happens to let
`_apply_save` publish for itself, so the ordering never came into play. The assertion was true and
the comment above it was not, and **no failure could ever have shown the difference.** The comment
now states the weaker claim, which is the true one, and points at `item_count_test.gd`, which did
go red on that plant. This is T3.2's framing gate (gotcha 40) in a second costume and is now gotcha
42: plant the real violation even when the assertion looks obvious — *especially* then, because the
thing being tested is the test.

### One budget was RAISED rather than a file split, and that is a first.

`director.gd` has a per-file override of 180 — a self-imposed tightening, 70 below the 250 default,
because "an autoload that owns one concern does not need 250 lines". It was at 176, and the drain
took it to 187. `check_budgets.gd` offers two remedies, "split the file, or justify a new budget",
and the split was the wrong one: the drain has to sit with the code that owns the loader thread,
and `Director`'s entire header is an argument for *one owner, one guarded path*. Carving up the
project's single transition path to save seven lines would trade real safety for a number. Raised
to **190**, with the reasoning in `docs/ARCHITECTURE.md` § Line budgets and at the override itself.
**What keeps this from being a slippery slope: 190 is not above the default.** Going over 250 still
means split.

The restructure that came with it is worth keeping on its own merits: `_load_area_scene` now sets
and clears `_in_flight` in ONE place and delegates the polling loop to `_await_load`, so the
invariant `_exit_tree()` depends on reads off a single function instead of four exit paths.

### Files: 12, and new code is 191 lines added against 6 removed.

`tools/check_strings.gd` (110 code lines, new) · `tests/unit/smoke_test.gd` (74 code lines, new) ·
`src/systems/scene_director/director.gd` (`_in_flight`, `_await_load`, `_exit_tree`) ·
`tools/check_budgets.gd` (the raised override and its reason) · `tests/test_runner.gd` (the CASES
entry) · `.github/workflows/ladder.yml` (rung 8 in both jobs, and rung 3's whole-log grep) ·
`CLAUDE.md` · `docs/CONTEXT.md` · `docs/ARCHITECTURE.md` · `docs/WORK_PACKAGES.md` ·
`docs/ROADMAP.md` · `docs/SYSTEMS_INVENTORY.md`. 1,517 → **1,543**.

**The suite total moved by more than the 23 assertions this package wrote**, and that is expected
rather than absorbed: `docs_test.gd` COMPUTES its plan from the documents, asserting that every
`res://` path they name exists, so adding `tools/check_strings.gd` and `tests/unit/smoke_test.gd`
to the ladder blocks in five documents adds assertions of its own. 23 from `smoke_test.gd` + 3 from
`docs_test.gd` = 26.

### Ladder, all green.

`--headless --import` with **zero** `SCRIPT ERROR` / `Parse Error` lines; boot at the new
`--quit-after 30` ending `0 warnings, 0 errors`; suite **1543 passed, 0 failed, 0 skipped**, exit
0; `check_budgets` **130 files, 11,338 code lines, 0 warnings, 0 violations**; `check_content`
PASS; `check_boundary` PASS; `check_strings` PASS over 93 engine scripts, 216 CSV rows, 71 key
declarations checked and 1 pattern reported.

**Stripped template, run locally** — `--headless --path <copy>` over a tree with `.git`, `.godot`,
`data/` and `scenes/areas/` removed: **1469 passed, 0 failed, 25 skipped** (was 1445/0/23), all
four checkers exit 0, import clean.

**THE ONE NEW SKIP IS NAMED AND COUNTED:** `smoke_test: a game in this checkout can be started
(no content — this is a stripped template) — 2 assertion(s) not run`. That is the whole of the
+2, and it is the right block to be the only one: it is the single place this package asserts
something about *a game* rather than about the engine. The outcome arithmetic reconciles exactly —
1494 outcomes against 1468 before, so +26 = 23 from `smoke_test.gd` (21 run, 2 skipped) + 3 from
`docs_test.gd`'s computed plan.

**`check_strings` reports byte-identical numbers stripped and full** — 216 CSV rows, 93 engine
scripts, 19 sinks, 71 key declarations, 1 pattern. That is the result to want rather than a
coincidence: both rules are about `src/` and `localization/`, neither of which the strip touches,
so any drift in those numbers would mean an engine string had come to depend on a game being
present. CI asserts the same thing by running rung 8 in both jobs.

**No windowed capture, and the reason is that nothing here is visual.** A shutdown drain, a text
scanner and a synchronous test have no pixels; claiming a capture proved any of them would be
theatre. The visual rung is unchanged and still owned by the packages that have something to show.
**No temporary probe either, and `git diff src/systems/debug/` is empty** — this package touches no
input path and no audio path, and the shutdown claim is proved by the engine's own output at five
frame counts rather than by a probe.

### Deferred, with reasons.

- **The debug console and the performance overlay** — WP-14b, above.
- **The sink rule cannot see four things**, and its header lists them rather than implying
  completeness: a literal reaching a sink through a variable assigned earlier; a sink outside
  `src/*.gd`, so a `.tscn` authoring `text = "Play"` is not scanned; a literal handed to
  `draw_string()` or `set_tooltip_text()`; and whether the key `tr()` received was the RIGHT key —
  a wrong key that exists renders the wrong sentence, which is gotcha 2's shape and not a
  text-scan problem.
- **The suite still cannot enter an area**, so the smoke test is a composed session and not a
  played one. Multi-frame scenarios remain *runs* in `dev_probes.gd`, per TESTING.md.
- **No CI export rung** and **no branch protection**, both unchanged from T2.0 and T1.4.
- Combat is still not a thing.

**CI green, run 33541171263, JOB LOGS read rather than the tick** (gotcha 26). Full checkout
**1543 passed, 0 failed, 0 skipped**; stripped template **1469 passed, 0 failed, 25 skipped** —
both identical to the local numbers. **Rung 8 ran in both jobs and reported identical figures** (93
engine scripts, 71 key declarations), which is the point of running it on a stripped tree. **Rung
3's new whole-log grep printed `Parse Error lines in boot.log: 0`** — the line that could not have
existed before this package. All seven rungs present in the full job and all six in the stripped
one. The run took 36 seconds, and per gotcha 26 that is a cached engine rather than evidence of a
skip: the rung logs show 1,543 assertions actually executed.

**Commit:** `975ff4b` on `claude/wp-14-hardening`, PR #23 — stacked onto
`claude/t3-2-art-seams` (#22) rather than `main`, matching the rest of the chain.

---

## WP-14b · Dev tools — debug console and performance overlay — **DONE**

**The half WP-14 split off** rather than half-finish four things, and the LAST row of Phase T3.
Neither of these is a gate; both are developer convenience, and both are UI.

**Read:** `src/systems/debug/dev_stage.gd`, `src/ui/root/ui_root.gd`, `src/ui/screens/`,
`src/systems/input/actions.gd`, `src/ui/hud/`, `localization/strings.csv`.

**Built:** a debug console (`goto`, `flag`, `time`, `give`) on F1, and a performance overlay on
F3. The three things WP-14 had already decided were taken as decided and are not re-argued below.

### The question the row asked first: CAN the console live under `src/ui/`? Yes, and it SHOULD.

The row's own test is whether any part of it wants a hard-coded area or item id. No part does — a
command takes its argument from whoever typed it, so `goto courtyard` is INPUT and not a literal.

What settled it was the stronger form of that argument rather than the permission.
`src/systems/debug/` is EXEMPT from `tools/check_boundary.gd`, and the exemption is justified only
because those files exist to drive the demo. Putting the console there would have bought it an
exemption it does not need and switched off the gate that should be watching it. Under
`src/ui/screens/` the console is policed exactly like the journal and the map, and it passes —
`check_boundary` scanned 127 engine scripts including this one and reported PASS.

**So the split is: the SURFACE is `src/ui/`, the VERBS are `src/systems/debug/`.** Everything that
would ever want to name content lives on the far side of `DevCommands`, which is in the exempt
directory where the rest of the harness already is.

### One parser, and the file it came out of was at exactly 250/250.

The row said the four commands already exist and to reuse them. They did — `--goto=`, `--flag=`
and `--give=` in `dev_stage.gd`, `--time=` in `dev_capture.gd` — and "reuse" was taken in its
strongest available sense rather than as a suggestion to copy the parsing shape.
`src/systems/debug/dev_commands.gd` now holds the four bodies, both argument parsers CALL them,
and the console calls them too. **What you type in the console is exactly what you pass on the
command line, argument for argument** — `time 18:40` is `--time=18:40`.

Each verb RETURNS its report instead of logging one, because a staging flag wants that line in the
log and a console wants it on the screen; returning the sentence lets both have it.

**And the reuse paid for itself immediately, which was not the reason for doing it.**
`dev_stage.gd` was at **exactly 250 of its 250 allowed code lines** before this package — measured
by stashing the branch and re-running the checker — so the sixth staging flag this row needed
(`--console=`) could not have been added at all. Extracting the verbs took it to **247** *while*
adding the flag. WP-14 raised a budget rather than split a file and wrote down that doing so was a
last resort; this is the other outcome, and the checker found the seam again.

### The console is a screen, the overlay is not, and that is one decision made twice.

Both follow from the same question — should the world be stopped? The console wants it stopped:
typing `time 18:40` while the clock runs photographs a moving target. So it declares
`pauses_world` and `UiRoot`'s pause table does the rest; there is no second pause mechanism, which
is what ADR-0004 exists to prevent. The overlay wants the opposite, because a frame time is
worthless unless frames are still happening — so it is a `CanvasLayer` at layer 101 beside the
HUD, never enters the stack, holds no pause, takes no focus and answers no cancel.

**Both proved windowed.** F1: `depth 0` → `PROBE F1 opened: true, depth 1, world paused true` →
`PROBE F1 again closed it: depth 0, world paused false`.

### Chrome is text, output is data — the line `check_strings.gd` forced this package to draw.

A console is full of text and the localization gate has opinions about text, so the split had to
be stated rather than discovered. The console's TITLE and its input hint are localization keys
like every other screen's (`ui.debug.console.title`, `ui.debug.console.hint`); the transcript is
echoes of a typed command and the values that came back, which no `strings.csv` could hold. The
overlay is all data and has no chrome, so it has no key at all.

The gate was satisfied the way it intends rather than routed around, with one honest exception
stated in the code: joining the transcript straight into `.text` FAILS the sink rule, correctly,
because a separator literal on the right of a `.text =` is indistinguishable to a text scan from a
sentence meant for a player. The join goes into a local first, and the comment says why.

**And the two new keys are really gated.** With `ui.debug.console.title` transposed to
`ui.debug.consloe.title`, `check_strings` printed
`!! res://src/ui/screens/debug_console_screen.gd:31 TITLE_KEY = 'ui.debug.consloe.title' has no row`
and exited **1**, while `check_content` exited 0, `check_boundary` exited 0 and all **1,573
assertions passed**. WP-14's finding, reproduced on this package's own keys.

### THE ASSERTION THAT WOULD HAVE PASSED OVER A DELETED GUARD — gotcha 42, caught by planting.

The release gate has to be asserted, and `OS.is_debug_build()` is true in every context the suite
can run in, so the assertable form is a text scan for the guard. The first version scanned each
file for the bare call. **It was wrong twice over, and planting is what found it:**

1. `screen_keys.gd` EXPLAINS its gate in a comment, so a whole-file scan would have read its own
   documentation back and passed with the binding deleted. The scan now skips comment lines, the
   way `check_boundary.gd` and `check_strings.gd` both do.
2. `perf_overlay.gd` carried `if not OS.is_debug_build():` **twice** — in `_ready` and in `_input`
   — so deleting the real one in `_ready` would have left the assertion green on the other. The
   fix was in the CODE rather than in the test: `_input` and `toggle()` now gate on
   `_label == null`, which is the same question and a stricter one, because a release build never
   builds the label. One place decides, and the anchor is unique.

Each of the three gate sites is now named by a fragment that appears nowhere else in its file, and
each was proved red with the real violation and the explaining comment left in place:

- the guard deleted from `toggle_console` →
  `FAILED: screen_keys.gd gates on 'if not OS.is_debug_build():' — expected true, got false`,
  `1572 passed, 1 failed`, exit 1. Restored → `1573 passed, 0 failed`.
- `and OS.is_debug_build()` deleted from `menu_for` → the matching failure, exit 1.
- the guard deleted from `PerfOverlay._ready` → the matching failure, exit 1.

Four more plants, on the behaviour rather than on the gate: the transcript trim removed →
`the transcript is bounded — expected 12, got 42`; the empty-line guard removed →
`so the transcript did not grow — expected 2, got 4`; `flag`'s malformed-argument refusal removed
→ two failures, including `and wrote nothing — expected false, got true`; and the CSV key typo
above.

### ABSENT FROM A RELEASE EXPORT — measured, with a control.

Not assumed, and not left to the text scan. Both tools log one line when they arm, and two real
exports were built and run:

| | `Debug console armed on debug_console` | `Performance overlay armed on debug_perf` |
|---|---|---|
| **debug export** (`--export-debug`) | present | present |
| **release export** (`--export-release`) | **absent** | **absent** |

Both runs otherwise identical and both ending `0 warnings, 0 errors`. The debug build is the
control: without it, two absent lines would prove only that nothing was logged. This is the shape
gotcha 39 established — a measurement outranks an assumption, and a control is what makes it one.

### Windowed captures, LOOKED AT and READ (gotcha 28).

Three, and two of them carry a checkable prediction rather than merely looking fine.

1. **The console with a real transcript.** Run at `--time=12:00 --freeze-time`, then
   `--console="time 18:40;flag map/somewhere:true;give item/rose_petal:2"`. The panel shows six
   lines — the echo and the answer for each command — over a courtyard still visible through the
   dim, so the world is stopped rather than gone. **The prediction:** the run asked for noon, and
   the HUD clock in the capture reads `Day 1 | 18:40 | Dusk` with the scene lit for dusk. The
   console really moved the clock, and the lighting and the readout agree.
2. **`goto` really travels.** `--console="goto lantern_hall"` from the courtyard. The capture is
   the interior — different geometry, the interior's own 36° / 9.5 m framing from T3.2 — with the
   toast `Lantern Hall is added to your map`, and no console, because travel unwinds the stack
   through `ScreenKeys`. The log reads `Entered 'courtyard'` … `goto requested 'lantern_hall'` …
   `Entered 'lantern_hall'`.
3. **The overlay over live gameplay.** `16.67 ms/frame  60 fps  17.72 ms process  98 draw calls
   169 nodes  0 orphans`, top-left in gold, with the NPC visibly at a different post than in the
   console capture — which is the point of it not being a screen.

**The first attempt at capture 3 came back with no overlay in it, and it was not a defect.** The
shutter frame landed before F3. Diagnosed by probing rather than guessed at: the label reported
`rect=[P: (32.0, 24.0), S: (1888.0, 40.0)] vis=true colour=(0.86, 0.74, 0.52, 1.0)` with the right
text, so nothing was wrong with the drawing and the timing was the whole story.

### The input probe, quoted and then removed (gotcha 15).

A console is an input path end to end and `TestCase.run()` cannot press a key. A temporary probe
in `src/systems/debug/dev_probes.gd` pressed F1, F3 and a real ENTER through the `LineEdit`:

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

**The frame time visibly changes**, which is the row's own criterion: the load spike reads 35.71
ms at 28 fps, and ninety frames later the same overlay reads 16.70 ms at 54 fps. The probe also
settled a 4.3-era question the dump does not answer — `LineEdit` distinguishes having focus from
being in EDIT mode, and `has focus true` with the enter actually taking is what proves
`grab_focus()` plus `edit()` is the right pair. **`git diff src/systems/debug/dev_probes.gd` is
empty.**

### Files: 12, and new code is 321 lines.

`src/systems/debug/dev_commands.gd` (63 code lines, new) ·
`src/ui/screens/debug_console_screen.gd` (80, new) · `src/ui/hud/perf_overlay.gd` (68, new) ·
`tests/unit/dev_tools_test.gd` (98, new) · `src/systems/debug/dev_stage.gd` (the three verbs
delegate, and `--console=`) · `src/systems/debug/dev_capture.gd` (`--time=` delegates) ·
`src/ui/root/screen_keys.gd` (`toggle_console`, the `menu_for` entry, the armed line) ·
`src/systems/input/actions.gd` (`DEBUG_PERF` on F3) · `scenes/boot/game_root.tscn` (the
`PerfOverlay` layer) · `localization/strings.csv` (two rows) · `tests/test_runner.gd` (the CASES
entry) · plus the documents. **130 → 134 files, 11,338 → 11,659 code lines.**

**1,543 → 1,574 assertions**, and the arithmetic is stated rather than absorbed: **+30** is the
whole of `dev_tools_test.gd`, and **+1** is `docs_test.gd`, which COMPUTES its plan from the
documents and gained one `res://` path to resolve when these sections named
`src/systems/debug/dev_commands.gd`. Every plant below was run before the documents were written
and therefore quotes 1573 rather than 1574; the totals differ by that one computed assertion and
nothing else.

### Ladder, all green.

`--headless --import` with **zero** `SCRIPT ERROR` / `Parse Error` lines; boot at `--quit-after
30` ending `0 warnings, 0 errors`; suite **1574 passed, 0 failed, 0 skipped**, exit 0;
`check_budgets` **134 files, 11,659 code lines, 0 warnings, 0 violations**; `check_content` PASS;
`check_boundary` PASS over 127 engine scripts; `check_strings` PASS over 96 engine scripts, 218
CSV rows, 24 sinks, 73 key declarations and 1 pattern.

**Stripped template, run locally** — `--headless --path <copy>` over a tree with `.git`, `.godot`,
`data/` and `scenes/areas/` removed: **1500 passed, 0 failed, 25 skipped** (was 1469/0/25), all
four checkers exit 0, import clean.

**THERE IS NO NEW SKIP, and that is the result to want rather than a gap.** The +31 is the whole
of `dev_tools_test.gd` plus `docs_test.gd`'s one computed assertion, and every one of the 30 runs
in a stripped template — because a console and an overlay are ENGINE, and nothing about either
needs a game to be present. `check_strings`
again reports byte-identical numbers stripped and full (218 rows, 96 scripts, 24 sinks, 73 keys, 1
pattern), which is what it should: both its rules are about `src/` and `localization/`, neither of
which the strip touches.

### Deferred, with reasons, not silently.

- **Command history, autocomplete and a watch list of live flags** — deferred by the row, and the
  transcript is deliberately un-scrollable for the same reason: a console that needs scrolling
  wants history, and half of it is worse than none.
- **No command mutates content on disk**, per the row.
- **The overlay has no graph**, only a number. A sparkline is a second thing to get wrong, and the
  averaged number already answers the question the row asked.
- **`DEBUG_FREECAM` on F2 is still declared and still unbound.** It predates this package, it is
  not a dev-tools row's job to invent a free camera, and saying so is cheaper than a reader
  wondering whether F2 was missed.
- **The `Button` styleboxes**, for the sixth package running. The console draws no `Button` at
  all, so this row had no occasion to take them; the reason has not changed and neither has the
  seam.
- Combat is still not a thing.

**CI green, run 33546328207, JOB LOGS read rather than the tick** (gotcha 26). Full checkout
**1574 passed, 0 failed, 0 skipped**; stripped template **1500 passed, 0 failed, 25 skipped** —
both identical to the local numbers. `check_budgets` reported **134 files, 11,659 code lines, 0
warnings, 0 violations** in BOTH jobs, and rung 8 reported identical figures in both (218 CSV
rows, 96 engine scripts, 73 key declarations), which is the point of running it on a stripped
tree. Rung 3's whole-log grep printed `Parse Error lines in boot.log: 0`. All seven rungs present
in the full job and all six in the stripped one. The run took 38 seconds, and per gotcha 26 that
is a cached engine rather than evidence of a skip: the rung logs show 1,574 assertions actually
executed.

**Commit:** `22e0046` on `claude/wp-14b-dev-tools`, PR #24 — stacked onto
`claude/wp-14-hardening` (#23) rather than `main`, matching the rest of the chain.


---
## WP-15 · Release engineering

**Read:** `docs/decisions/ADR-0006-item-discovery-by-directory-scan.md` **first**, `project.godot`,
`tools/check_content.gd`.

**Write:** an export preset, shader warm-up, an accessibility pass, credits.

**This package must settle ADR-0006's open question.** Items are found by scanning a directory,
which is verified in the editor and headless only. The preset **must export all resources in the
project** — a "selected scenes and dependencies" preset would strip the item `.tres` files
entirely, because nothing references most of them. If an exported build comes back with an empty
catalogue, the remedy is a generated manifest and `ItemDb.resource_paths()` is the only function
that changes.

**Exit criteria:** an exported build runs on a machine without Godot installed, with a non-empty
item catalogue, and a thirty-minute soak produces zero errors.

### Everything above is DONE, in T2.0 — and the remnant should be CLOSED, not built.

The export preset, the ADR-0006 question and the shader warm-up all shipped in T2.0, which was
sequenced to the front of Phase T2 by risk. What is left of this row is **credits and an
accessibility pass**, and WP-14 flagged both as belonging to a *consuming game* rather than to the
template:

- **Credits** name a team, and a template does not have one. A game built on this base credits its
  own people; a `credits.tres` shipped by the template would be either empty or wrong, and the
  mechanism it would need — a screen that reads a resource and scrolls it — is `MenuScreen` plus a
  `.tres`, which Tier 1 of the extension surface already covers with no new code.
- **An accessibility pass** over placeholder art and a UI whose every colour and size a game is
  expected to replace is a pass over something designed to be thrown away. The seams that make
  accessibility *possible* are the ones that matter and they already exist and are proved: the
  project `Theme` holds every font size and colour in one file (T2.1), input is rebindable through
  `actions.gd` with a rebind screen (WP-12), and there is no timed input anywhere in the template
  because there is no combat. A real pass belongs to whoever ships real art.

**The recommendation is therefore to close this row with that reasoning**, the way WP-10 was marked
OPTIONAL, rather than build two things for a game that does not exist. Recorded here rather than
acted on, because retiring a row is the owner's call and not a package's.

**WP-14b SURFACED THIS RATHER THAN DECIDING IT, 2026-09-02, and with Phase T3 now closed it is the
only thing standing between the board and Phase T4.** WP-14b found nothing that changes the
reasoning above and one small thing that reinforces it: the console and the overlay are the last
two engine surfaces a consuming game does NOT restyle, because a player never sees either — which
sharpens the point that a pass over the surfaces a game *does* restyle belongs to whoever ships the
real art. **This needs a yes or a no from the owner**, and the two live options are:

- **CLOSE the row** with the reasoning above recorded, and go straight to Phase T4. This is the
  recommendation.
- **KEEP it** and build credits plus an accessibility pass, which is roughly one package and
  produces two artefacts a consuming game replaces.

WP-10 (crafting) is already OPTIONAL and does not block v1.0 either way.

---

### THE ANSWER, 2026-09-02: CLOSED.

The owner took the recommendation. **Credits and the accessibility pass will not be built on this
base.** The row is closed the way WP-10 is marked OPTIONAL — recorded with its reasoning rather
than deleted, so a later session finds the argument instead of re-deriving it.

Nothing about the reasoning changed on the way to the decision, and the two artefacts a consuming
game would replace are still a `credits.tres` and a restyle of a `Theme` a game is expected to
replace. **What the template owes accessibility is the seams, and it has them and they are
proved:** the project `Theme` at `assets/theme/ui_theme.tres` (T2.1), rebindable input through
`src/systems/input/actions.gd` plus the rebind screen (WP-12), and no timed input anywhere,
because there is no combat.

**With this closed, Phase T4 begins.** T4.1 is below.

---

## T4.1 · Template v1.0 — the version, and the upgrade note — **DONE** — `799d957`, PR #25

**Read:** `docs/TEMPLATE.md`, `project.godot`, `src/core/util/game_config.gd`,
`docs/NEW_GAME.md`.

The first package of Phase T4, and the roadmap named two deliverables. The second is the one that
mattered: *nothing described how a game already forked from this base receives a later fix*, which
is the one question a reusable base has to answer.

### The version does NOT live in `application/config/version`, and that is the package in one line.

That field was the obvious candidate and it is the wrong one, for a reason `NEW_GAME.md` § 4 was
already carrying: **it tells a fork to reset it to `0.0.1` on day one.** So after exactly one fork
that field means *the game's* version, and nothing anywhere records which base the game came from
— and "which base am I on" is the first question an upgrade note has to answer.

So the template states its own version in its own section:

```
[template]
base/version="1.0.0"
```

read through `src/core/util/template_version.gd`. **A fork leaves that line alone, and a merge
that changes it is the base announcing a release inside the fork's own diff** — which is what the
performed merge in `UPGRADING.md` § 7 actually shows happening.

It is a project setting rather than a `const` under `src/` for the same reason `[game]
world/first_area` is: reading a `const` means opening engine code, and the premise of the whole
boundary is that a consuming game does not read `src/`.

### It is readable at runtime because it is in every boot banner, which is not decoration.

The banner now reads `<game> <game version> | base <base version> | Godot ... | debug=...`. A bug
report from a forked game is unanswerable without it: the game's own version says nothing about
which template fix it already has. `Log` previously allowed itself exactly one dependency,
`GameConfig`; `TemplateVersion` is the same kind of thing — a pure reader of `project.godot` that
depends on nothing — so the edge is not widened in kind.

### `TemplateVersion` is a separate file from `GameConfig`, and the split is not tidiness.

`GameConfig`'s header says it owns *"the values a game author writes once"*. The base's version is
the one value a game author must NEVER write. Putting it there would have made that sentence
false; a second small file keeps both true.

### The upgrade note was PERFORMED, and it found a defect nobody would have reasoned to.

`NEW_GAME.md`'s precedent (T2.2) is that a consumer document's claims are run, not written from
intent. So: a stripped fork was made from a clone of the base, following `NEW_GAME.md` step by
step; two template releases were landed on the base; both were merged in; and the fork's whole
ladder was run afterwards. Everything quoted in `UPGRADING.md` § 7 is real output. **The two
release numbers, 1.1.0 and 1.1.1, are synthetic scaffolding and the document says so** — a
version-to-version walk needs two versions, and the real template has released one.

Four things came out of it that no amount of design would have produced:

1. **`project.godot` auto-merged**, including a base edit three lines from a field the fork had
   renamed. The note says so AND says not to count on it, because git decided that, not the
   template.
2. **`localization/strings.csv` conflicts every time**, because both sides append at the end of
   the file. The resolution is always "keep both sides" — it is a key-value file, not competing
   edits to one value.
3. **A merge pushes the template's DEMO CONTENT back into the fork.** An item belonging to the
   template's demo arrived as a new file with no conflict and therefore no warning, because
   `data/` is a directory both sides own files in and git has no opinion about whose. This is in
   no other document.
4. **The fork's rung 4 went RED, and it was a real template defect.** `smoke_test.gd` gated its
   first-area block on `Fixtures.has_demo_content()` — "any content at all", which flips true on
   the first `.tres` of any kind. A game that authored one item before its first area therefore
   armed an assertion about AREAS and failed rung 4, *in exactly the window `NEW_GAME.md` walks an
   author through, while `NEW_GAME.md` claimed the ladder stays green.* The fix is one line and it
   is the general rule: **a block must gate on the same question it asserts.**
   `Fixtures.area_ids()` is that question and it already existed. Nothing is weakened — a game
   WITH areas still fails on an unset first area and on one naming a scene that is not there,
   which was planted and proved.

`NEW_GAME.md` was corrected in the same commit: its stale `880 passed, 0 failed, 12 skipped`
became the measured `1527 passed, 0 failed, 25 skipped`, it now says `[template] base/version` is
the one `project.godot` field a fork must not touch, and it states the authoring-order trap.

### What the template CANNOT promise, written down rather than implied.

Five things, in `UPGRADING.md` § 4: it cannot promise a clean merge (git decides, from a diff the
template cannot see), that your content still loads across a MAJOR, that a save survives, or
anything at all about a fork that edited `src/` — and there will be no automatic upgrade script.
The fourth is the sharpest: **the boundary rule is what makes the merge safe**, so a fork that
broke it has no upgrade path and no version number can give it one.

### The changelog is a GATE, not a courtesy.

`docs/CHANGELOG.md`'s newest `## <semver>` heading must equal `[template] base/version`, asserted
by `tests/unit/version_test.gd`. Bumping one without the other is the exact rot the discipline
exists to prevent, and it was planted: bumping the heading alone fails rung 4.

### Five plants, each proved red with the real violation (gotcha 23), and one is gotcha 43's.

1. The banner loses its base-version fragment — `expected 1, got 0`.
2. **The same fragment written TWICE** — `expected 1, got 2`. This is gotcha 43 taken as a rule
   rather than as a story: the scan asserts the fragment appears EXACTLY ONCE, so a decorative
   second copy cannot hide a deleted real one.
3. The changelog bumped and the setting not — `expected 1.0.0, got 1.0.1`.
4. A two-part version in `project.godot` — three failures, including `current()` falling back to
   `0.0.0` rather than returning something unparseable.
5. `first_area` pointed at an area that does not exist, WITH areas present — the block that was
   loosened still fails, which is what proves the loosening was not a weakening.

### No visual and no input surface, said rather than skipped.

Nothing this package touches draws a pixel or reads a key, so there is no windowed capture and no
debug probe. The boot banner is the one new runtime output and it is a log line, proved on rung 2
and quoted below. `git diff src/systems/debug/` is clean because nothing went in there.

### Files: eleven, and new code is 118 lines.

New: `src/core/util/template_version.gd` (43 code lines), `tests/unit/version_test.gd` (74),
`docs/UPGRADING.md`, `docs/CHANGELOG.md`. Edited: `project.godot`, `src/core/log/log.gd` (+1),
`tests/unit/smoke_test.gd` (one line changed), `tests/test_runner.gd` (+1), `docs/NEW_GAME.md`,
`docs/TEMPLATE.md`, `CLAUDE.md`. Under the 500-line limit with room to spare.

### Ladder, all green.

```
--headless --import                     zero SCRIPT ERROR / Parse Error lines
--headless --quit-after 30              Session ended after 0.7s — 0 warnings, 0 errors
                                        Project Gulistan 0.0.1 | base 1.0.0 | Godot 4.7.2-stable
res://tests/test_runner.tscn            === 1601 passed, 0 failed, 0 skipped ===   (was 1574)
check_budgets/content/boundary/strings  exit=0, all four
stripped template                       === 1527 passed, 0 failed, 25 skipped ===  NO new skip
the performed fork, after two merges    === 1538 passed, 0 failed, 14 skipped ===, four checkers exit=0

CI, run 33595460507, JOB LOGS read rather than the tick (gotcha 26):
Ladder (full checkout)      === 1601 passed, 0 failed, 0 skipped ===, every rung PASS
Ladder (stripped template)  === 1527 passed, 0 failed, 25 skipped ===, every rung PASS
and CI's own boot lines read `Project Gulistan 0.0.1 | base 1.0.0 | Godot 4.7.2-stable`.
```

### Deferred, with reasons, not silently.

- **A git tag on the real repository.** The version the template states about itself is the
  deliverable the roadmap asked for, and it is assertable; a tag is a release action, and releases
  are the owner's. `v1.0.0` exists only in the throwaway proof repositories.
- **A compatibility TABLE in `TemplateVersion`.** A table is a list of exceptions to the promise,
  and the promise is the product. `same_major_as()` and `compare_to()` are the whole surface.
- **A tool that performs the merge.** `UPGRADING.md` § 4 states there will be no automatic
  upgrade, and shipping one would contradict the document in the same package that wrote it.
- **Credits and the accessibility pass** — WP-15, closed above.


## T4.2 · A second worked example, authored from `AUTHORING.md` alone — **DONE**

**Goal.** T2.2's mechanism — *perform the document and count the defects* — applied to CONTENT
rather than to docs. T2.2 performed the area, NPC and conversation sections and found six defects;
everything `AUTHORING.md` has gained since (the world map, surfaces and attributes, equipment and
the gate that reads it, quests, counted steps, the `obj/` writers) had been WRITTEN but never
walked. Gotcha 44 is the argument for doing it: the states a consuming game passes through are
exactly the states this repository never sits in.

**Method, and the one rule that makes it worth anything.** A new area — an orchard with a warden,
a schedule, a four-node conversation, two items, a sign, a basket, a pickup, an equip-gated arch,
a world-map def and a two-step quest whose first step counts items — was authored **from the
document alone, with `src/` never opened while writing**. Every time the document did not say
enough, that was recorded rather than patched from knowledge. The content was then DELETED, the
way T2.2's was: this is a test of the documents, and `TEMPLATE.md` says the demo does not get
deepened.

**Five defects, and two of them were in the TEMPLATE rather than in the prose.**

1. **§ Add an area ends at a RED rung 4, and § Put an area on the world map calls that state
   legitimate.** Following the area section exactly — scene, CSV row, then its own three closing
   commands — gives `1621 passed, 4 failed`, `FAILED: every authored area is on the map`. The area
   section never mentions `data/areas/<id>.tres`; the map section said an area without one "is
   simply not on the map — legitimate for a cupboard". The suite requires one per authored area, so
   that sentence was false, and it was false in the section a reader goes to when the assertion
   fires. Both corrected, and the real cost measured with a control: an area adds **20** assertions
   to `transitions_test.gd`, as documented, **plus 5** to `world_map_test.gd`, which was not.
2. **`check_boundary` matched SUBSTRINGS, so an item called `pear` failed a gate its author could
   not fix.** `tests/unit/menus_test.gd` says *"and Load has appeared under it"*, and **`appeared`
   contains `pear`**. Gotcha 44's shape exactly — green in the full demo, green in the stripped
   template, red only in a consuming game's hands, because the collision needs an id this
   repository does not have. **And the document made it worse**: its gate table said a
   `check_boundary` failure "is a bug in the *engine*, not in your content", sending the author to
   file a bug rather than rename. FIXED: ids are matched as whole words. The two remaining hits
   were real whole-word ones — an engine test using `"apple"` and `"pear"` as throwaway dictionary
   keys — and **that fix belonged in the test**, which now draws them from the reserved `fixture_`
   namespace, immune by construction because an id after an underscore is not a whole word.
3. **`--stand-by` always resolved in the DEPARTURE area, so no object in an authored area could be
   photographed at all.** `--goto=orchard --stand-by=BrambleWay` failed with *found no node called
   'BrambleWay'*. Not a race — a deterministic loss: `_wait_for_area()` returns on the same frame
   `--goto` asks to travel. Gotcha 35, whose rule `dev_stage.gd`'s own header already states for
   `--open-menu` — this call site was simply missed, which is gotcha 41's family. FIXED with
   `_settle_stable(SETTLE_FRAMES)`, and the document now carries a `--goto` + `--stand-by` recipe
   with frames that work (260/290/340 rather than 1/70/90).
4. **The quest section named no `obj/` field, and a step that can never finish passes every
   gate.** Its writers table pointed at ADR-0005 for `obj/<area>/<object>/<field>`. Writing
   `obj/orchard/bramble_way/opened` from that: `check_content` PASSED, the journal drew the
   objective, the run reported `0 warnings, 0 errors` — and the field is `open`. **This is the one
   flag family no gate can check**, because the field lives in engine code and the object is placed
   in a scene. All seven are now a table in the document (`open`, `thrown`, `emptied`, `taken`,
   `read`, `fired`, `done`), each shorter than the word you would guess, with the trap stated.
5. **§ Tag the ground you walk on cannot be verified at all**, against the document's opening
   promise that every section "ends with a command that tells you whether you got it right". No
   gate reads `metadata/surface`, nothing logs it on load, and no debug flag walks anybody — the
   surface resolves only when a character WALKS. Stated honestly rather than papered over.

**Six sections performed CORRECTLY and are now proved rather than asserted**, which is the other
half of the result: the world map (the def, the normalised `map_position` measured at 0.61/0.24 of
the plate, discovery-by-arrival), the conversation and its fall-through entry, the NPC and its
schedule, the `[editable]` marker rule, the counted quest step (`Gather three pears. 2 / 3`), and
an authored `locked_key` reaching the player.

**Gates proved red with the real violation, then green (gotcha 23).** The new `--stand-by`
assertion was proved by deleting the settle call: `FAIL func _stand_by settles rather than only
waiting for an area`, exit 1 — **and the other two `_settle_stable` calls were still in the file**,
so a whole-file scan would have stayed green. That is gotcha 43's rule met by narrowing the TEXT
rather than the fragment. The boundary matcher got a plant AND a control, because a fix that makes
a gate accept more has to show it still refuses: `rose_key` planted whole → `FAIL — 5 boundary
violation(s)`; `rose_keys` planted → `PASS`; the same `rose_keys` plant against the OLD substring
matcher → `FAIL — 4 boundary violation(s)`, flagging `rose_keys` as `rose_key` and `appeared` as
`pear`. Both plants use PERMANENT demo ids, so they are repeatable after the walkthrough content
was deleted.

**Files: 5, and the new code is 6 assertions plus two fixes.** `tools/check_boundary.gd`,
`src/systems/debug/dev_stage.gd`, `tests/unit/core_test.gd`, `tests/unit/dev_tools_test.gd`,
`docs/AUTHORING.md`.

**Ladder, all green.** Import exit 0 with **zero** `SCRIPT ERROR` / `Parse Error`; boot
`0 warnings, 0 errors`; suite **1607 passed, 0 failed, 0 skipped** (1601 + 6); `check_content`,
`check_boundary`, `check_budgets`, `check_strings` all exit 0. Stripped template **1533 passed, 0
failed, 25 skipped** — 1527 + 6, **no new skip**. Five windowed captures LOOKED AT and READ.

**CI green, run `33599084960`, job logs read rather than the tick (gotcha 26).** Full checkout
`=== 1607 passed, 0 failed, 0 skipped ===`; stripped template `=== 1533 passed, 0 failed, 25
skipped ===`, the 25 skips unchanged from T4.1. All four checkers PASS in both jobs. The push run
(`33599052173`) and the dispatch (`33599094672`) agree.

**Commit:** `4f5f753` on `claude/beautiful-proskuriakova-2df954`, PR #26 — stacked onto
`claude/wp-t4-version-upgrade` (#25) rather than `main`, matching the rest of the chain.

**What was deliberately NOT done.** A `check_content` rule for `obj/` flags: it would have to know
each prefab class's field constant, which means a list in a tool naming engine internals that
`check_boundary` cannot help it keep honest — the field table plus "read it out of a run" is the
cheaper truth, and defect 4 is now documented rather than gated. And the world-map assertion was
NOT weakened to match the prose: requiring a def per area is a real invariant, and the document was
the thing written from intent.

---

## T1.2 · Engine/demo boundary — **DONE**

**Goal.** Turn `TEMPLATE.md`'s prose rule — *no file under `src/` may name demo content* — into a
mechanical gate, and fix the four leaks it already had.

**Read:** `CLAUDE.md`, `docs/TEMPLATE.md`, `docs/CONTEXT.md`, this row.

**Wrote**
- `tools/check_boundary.gd` — the gate. Demo names **derived** from the folders under
  `scenes/areas/` and the `id` of every `.tres` under `data/`, plus each id's last segment.
  Fails on any of them in a CODE line under `src/`. Also fails if a debug script defining
  `_parse_arguments()` loses its `OS.is_debug_build()` guard, because that guard is the
  precondition the one exemption rests on.
- `src/core/util/game_config.gd` — `GameConfig`. Reads the new `[game]` section of
  `project.godot`. The only file under `src/` that knows a game-specific answer.
- `director.gd` lost `const FIRST_AREA := &"courtyard"`; `log.gd` lost the literal `Gulistan`
  from the banner and the log file name; the three debug nodes got their release guard.
- `docs/NEW_GAME.md` — the strip-and-start checklist, performed against a stripped copy.

**Two decisions to not re-litigate.** Comments are exempt from the gate and code is not — a `##`
line teaching `id = &"item/rose_key"` changes no behaviour and forbidding it would make the
documentation useless. And `src/systems/debug/` is the single exempt directory, justified in the
tool's header, conditional on the release guard, with its demo names counted and printed rather
than silently skipped. **A second exempt directory means the rule is gone.**

**It became its own tool, not part of `check_content.gd`.** The combined file came out at 252 of
the 250 allowed code lines and the budget checker refused it. That is the fourth split the
checker has forced and the fourth that was already in the reasoning: `check_content.gd` validates
that the *demo* is well formed, this validates that the *engine* does not know the demo exists.

**Closed 2026-08-26**, commit `06ce363`. All five exit criteria met. 921 assertions (was 910), boot
`0 warnings, 0 errors`, all three checkers exit 0. The gate proved by planting `&"courtyard"` in
`src/core/util/layers.gd` — `FAIL — 1 boundary violation(s)`, exit 1 — and removing it. Two bugs
found that no gate had caught: `dev_capture.gd` had failed to *parse* since the WP-13 merge while
every rung stayed green (gotcha 22), and a stripped template failed its own content gate on step
one of `NEW_GAME.md` because an empty content folder was treated as a problem. Both written up in
`DEVLOG.md`.

**Left for T1.3, and CLOSED by it:** the suite was still welded to the demo, so `data/` could not
actually be deleted. Everything else on the ladder survived it, which T1.2 ran and quoted.

---

## T1.3 · Test fixtures + framework hardening — **DONE**

**Goal.** Unweld the suite from the demo, so `data/` and `scenes/areas/` can be deleted and rung 4
of the ladder survives; and make the suite able to fail, which it demonstrably was not.

**Read:** `CLAUDE.md`, `docs/TEMPLATE.md`, `docs/CONTEXT.md`, `tests/framework/`, `tests/test_runner.gd`.

**Wrote**
- `tests/framework/fixture_content.gd` — the content a case needs, built in code and deliberately
  abstract. Items, a conversation graph, a timetable, a path action.
- `tests/framework/fixtures.gd` — where it lives. **The decision is split along one line:** in
  memory when a system is HANDED content, written to `user://test_fixtures/` and scanned by the
  registry when a system LOOKS IT UP BY ID. The three registries find content by directory scan
  (ADR-0006), so the alternative was a test-only backdoor in engine code.
- `tests/framework/error_watch.gd` — an `OS.add_logger` `Logger` counting `ERROR_TYPE_SCRIPT`.
- `TestCase.plan()` / `skip()`, and a runner that enforces both plus a manifest scan.
- `ItemDb`/`DialogueDb`/`ScheduleDb`: `content_dir`, and `reload()` renamed to `rescan()`.
- `tools/check_boundary.gd` now scans `tests/framework/` and `tests/unit/` too.

**Three decisions to not re-litigate.** Fixtures on disk rather than injected, because the
registries scan directories and a backdoor in engine code that exists only for the suite is worse
than a temp folder — and the round trip through `ResourceSaver` proves the authoring format as a
side effect. The plan is a maintained number, TAP-style, because a GDScript crash aborts only its
own frame and nothing else can see a swallowed assertion. And `ErrorWatch` counts only
`ERROR_TYPE_SCRIPT`, because deliberate negative-path tests raise `push_error` and a gate that
fires on those gets switched off within a day.

**Closed 2026-08-26**, commit `a8377a0`. Both exit criteria met, plus the two Phase T1 criteria
that were waiting on it. 911 assertions (was 921 — the drop is aggregation: named per-item and
per-waypoint assertions became set-level ones that also cover content added later). Stripped run:
`861 passed, 0 failed, 12 skipped`, exit 0, every skip named and counted. All four silent-pass
modes planted and each exited 1, quoted in `DEVLOG.md`. One bug found that no gate had caught and
none could: **`ItemDb.reload()` had never called our function** — `Script.reload()` won the name,
the fourth native-name collision in this project — so every `reload()` in the three registries and
in `check_content.gd` was a script reload that happened to have the same effect.

**Left for T1.4, and CLOSED by it:** none of this ran automatically. The ladder was seven
commands a human types.

---

## T1.4 · CI — automate the ladder — **DONE**

**Goal.** A pushed branch with a broken assertion goes red. That was the last unmet Phase T1
criterion, and Phase T1 is now complete.

**Read:** `CLAUDE.md`, `docs/TEMPLATE.md`, `docs/CONTEXT.md` (gotchas 22 and 24 shape the
workflow), `tests/test_runner.gd`, `tests/framework/`, and the headers of the three `tools/check_*`
gates for their exit-code contracts.

**Wrote**
- `.github/workflows/ladder.yml` — two jobs. **Ladder (full checkout)**: rung 2 import with
  `SCRIPT ERROR` / `Parse Error` grepped at zero tolerance, rung 3 boot asserting the last
  `Session ended` line, rung 4 the suite, then `check_budgets`, `check_content`, `check_boundary`,
  each its own step. **Ladder (stripped template)**: `rm -rf data scenes/areas` then the same
  rungs minus the boot, and it asserts the run reports named skips so a stripped run can never
  look identical to a full one.
- `.github/actions/setup-godot/action.yml` — downloads `Godot_v4.7.2-stable_linux.x86_64.zip`,
  verifies it against a SHA512 pinned as a literal, and asserts `godot --version` is exactly
  `4.7.2.stable.official.ed1daf0bf` before any rung depends on it. Standard build, never mono.
  One file, because a version pinned in two jobs is a version that drifts.

**Four decisions to not re-litigate**, each argued in the workflow's own comments. **`.godot/` is
not cached and the engine archive is** — a restored cache can resolve a `class_name` this commit
deleted, and "CI is green and a fresh clone is broken" is the exact failure this package exists to
prevent; the engine zip is immutable and keyed by version, so cache the fixed thing and never the
derived one. **Rung 1 is absent** because autoload identifiers do not resolve under `--check-only`
and a machine cannot tell that expected error from a real one. **The boot rung asserts one line,
not the whole log**, because quitting mid-load prints spurious `Parse Error` lines after a clean
report and a whole-log grep would be a flake generator; the frame count is 300, not 120, since a
headless frame is nearly free and racing a threaded load is not. **The windowed capture is stated
as impossible, not dropped** — a GPU-less runner shades nothing, so any capture it produced would
be exactly the evidence gotcha 2 calls worthless.

**Closed 2026-08-26**, commit `272053f`. The one exit criterion met, and Phase T1 with it. Proved
red: one assertion in `core_test.gd` changed to expect 6 where the answer is 5, and run
[32989608134](https://github.com/Raiyan-Bashar-29/HD-2D-game-base-non-combat-/actions/runs/32989608134)
failed at `Rung 4 - test suite` in BOTH jobs, printing `FAILED: dict_read int — expected 6, got
5`. Restored, and run
[32989771404](https://github.com/Raiyan-Bashar-29/HD-2D-game-base-non-combat-/actions/runs/32989771404)
went green: `911 passed, 0 failed, 0 skipped` full, `861 passed, 0 failed, 12 skipped` stripped —
reproducing T1.3's hand-run numbers exactly. Nothing in `src/` changed and the one line touched in
`tests/` was reverted, so the stated tripwire for this package never fired. Two new gotchas, 25
and 26: GitHub runs every `run:` block as `bash -e {0}` so a step's own `set -uo pipefail` does not
turn errexit off — the first red run said only `exit code 1` — and `gh`'s run listing lags enough
to support a confident wrong diagnosis.

**Left for T2.1:** no branch protection, so the gate reports and nothing stops a red branch
merging — that is a repository setting, not a file. No status badge, deliberately: on a private
repo it renders as "unknown".

---

## T2.0 · The export proof — **DONE**

**Goal.** Prove that an exported build finds its content. Everything about this project's content
pipeline rested on an assumption nobody had ever tested: that a Godot export ships resources that
no scene references.

**THE ANSWER: IT DOES. The assumption held, and ADR-0006 needed no revision.** A Windows *debug*
export was built and run from its own `.exe`, outside the editor, in a directory containing nothing
but the executable and its `.pck` — no `project.godot`, no loose `data/`. Both sides, quoted:

```
editor    origin: template=false editor=true debug=true exe=Godot_v4.7.2-stable_win64.exe
exported  origin: template=true  editor=false debug=true exe=game.exe

both      items: 3 found in res://data/items -> [rose_key.tres, rose_petal.tres, stone_chip.tres]
both      dialogue: 1 found in res://data/dialogue -> [gardener.tres]
both      schedules: 1 found in res://data/schedules -> [keeper.tres]
```

Counts, roots and resolved paths identical, and `Session ended … 0 warnings, 0 errors` in both. The
exported build also *used* the content, not merely counted it: `--give=item/rose_key,item/rose_petal:3`
logged `+1 item/rose_key` and `+3 item/rose_petal`, which means the definitions loaded through the
pack's `.remap` indirection.

**Four measured facts, and three of them were assumptions until now.**

1. **`export_filter` is the entire risk, and `"all_resources"` is the only right answer.**
   Measured both ways: with it, all seven `data/**` resources are stored in the pack; with
   `export_filter="scenes"`, **zero** are.
2. **`ResourceLoader.list_directory()` works through the pack.** The pack stores
   `data/items/rose_key.tres.remap`; the scan returns the `.tres` path and the load follows the
   remap. ADR-0006 chose it *because* it is the resource-aware one and recorded that as unproven.
   It is now proven, and `_normalise`'s `.remap` handling is observed rather than defensive.
3. **`include_filter="*.tres"` would have been the plausible wrong fix.** The include filter is for
   NON-resource files. It is empty, and setting it instead of `export_filter` changes nothing while
   looking like a remedy.
4. **A narrowed filter fails LOUDLY here, not silently.** With `export_filter="scenes"` and the
   boot scene selected, the build strips the `class_name` scripts that are nobody's dependency —
   `GameConfig`, `GameEnums`, `DictRead`, `KeyBindings` — and dies at boot on parse errors. So the
   feared *silent empty catalogue* cannot be produced by narrowing the filter alone. It CAN be
   produced by an exclude filter, which is silent: `exclude_filter="data/*"` exported and booted
   cleanly to the main menu with `items: 0, dialogue: 0, schedules: 0`. That run is also how the
   new readout was proved to FAIL — three warnings, `1 warnings` → `3 warnings, 0 errors`.

**A SECOND DEFECT, EXPORT-ONLY, AND THE REAL PRIZE OF RUNNING THIS EARLY.** The exported build
booted with three lines the editor never printed:

```
[ERROR] [world   ] Keeper has a PersistentState with no object_id — its state cannot persist
[WARN ] [interact] Talk has no label_key, so its prompt will be blank
[ERROR] [dialogue] Talk names no conversation and will refuse every attempt
```

`courtyard.tscn` overrode `object_id`, `label_key` and `conversation_id` on two nodes **inside** its
instanced `npc.tscn` without the `[editable path="Actors/Keeper"]` marker. From source the text
loader applies those overrides; an export converts `.tscn` to binary `.scn` and the conversion
**drops** overrides on a non-editable instance. So the NPC shipped with no identity, no prompt and
no conversation, and its schedule never ran — while every rung, both CI jobs, `check_content` and
930 assertions stayed green. This project hand-authors its `.tscn` files, so the marker the editor
would have written is exactly what a hand-authored scene forgets. Stale `index=` values were ruled
out first by correcting them and re-exporting: no change.

**Wrote**
- `export_presets.cfg` — one Windows Desktop preset, committed (`git check-ignore -v` exits 1; only
  `override.cfg` is ignored). Its header carries the measurement, not a preference.
- `src/systems/debug/catalogue_report.gd` — reports every catalogue's count, root and resolved
  paths at boot, behind `OS.is_debug_build()`, in the one directory `check_boundary` exempts. It
  reports the PATHS and not only the counts because a partial ship is worse than an empty one.
  Wired into `scenes/boot/game_root.tscn` as a fifth root node.
- `tools/check_content.gd` — `_check_editable_instances()`, the gate for the second defect. 189 →
  237 of 250 code lines. Deliberately stricter than the failure needs: an *added* node inside an
  instance was observed to survive the conversion and is still required to be declared editable,
  because "which kind is this" is a distinction the exporter makes and an author should not have to.
- `tests/unit/export_test.gd` — 19 assertions. It **cannot test an exported build** and says so in
  its header and in an assertion (`is_exported() == false`), so it can never quietly start looking
  like the proof. What it does do is pin `export_filter="all_resources"` as a tested invariant,
  prove the reporter agrees with the registries, and prove every resolved path loads.
- `scenes/areas/courtyard/courtyard.tscn` — the missing `[editable]` marker.
- `docs/NEW_GAME.md` § 7 Export, and ADR-0006's honest limit closed.

**Verified.** Ladder green: import 0 `SCRIPT ERROR`/`Parse Error`; boot `0 warnings, 0 errors`;
suite **930 passed, 0 failed, 0 skipped** (911 + 19), exit 0; `check_budgets`, `check_content`,
`check_boundary` all exit 0. Stripped template: **880 passed, 0 failed, 12 skipped**, exit 0, with
`check_content` and `check_boundary` still green. Both new gates proved RED before green
(gotcha 23): deleting the `[editable]` line made `check_content` print four named violations and
`FAIL — 4 content violation(s)`; flipping `REQUIRED_FILTER` to `"scenes"` made rung 4 print
`FAIL the preset ships every resource, not only dependencies — expected scenes, got all_resources`
and exit 1. Both reverted.

**Setup note for the next person:** the export templates were not installed. Only
`Godot_v4.7.2-stable_export_templates.tpz` (1.28 GB) provides them; the four Windows x86_64 files
were extracted into `%APPDATA%/Godot/export_templates/4.7.2.stable/`. `--export-pack` needs no
template and is enough to see *which files* ship; only a real template proves they are *found*.

**Left for later, deliberately:** export presets for platforms other than Windows (each needs its
own template, and a consuming game's decision). No CI export rung — a GPU-less runner has no
platform template, and this is the same honesty as T1.4's stance on the windowed capture.

**CI green**, run
[32995130430](https://github.com/Raiyan-Bashar-29/HD-2D-game-base-non-combat-/actions/runs/32995130430),
both jobs: `930 passed, 0 failed, 0 skipped` full checkout, `880 passed, 0 failed, 12 skipped`
stripped, reproducing the hand-run numbers exactly. Dispatched manually rather than waited for,
per gotcha 26.

**Closed 2026-08-26**, commit `835fb79`. New gotcha 27.


---

## T2.1 · Art contract seams — **DONE**

**Goal.** Make the art contract authorable data instead of code constants, and prove it by
swapping something. Phase T2's goal is *"a second, visually different game starts from this
without editing `src/`"*, and two things made that false.

**The two seams, and what was actually wrong with each.**

1. **`CharacterVisual` hard-coded the sheet.** `FACING_COUNT = 8` and `FRAME_COUNT = 4` were
   constants, and the eight-way sector maths was a **separate literal `TAU / 8.0`** that had to
   agree with the first by hand. Two places holding one number, waiting for the first game whose
   sheet has four facings. There was also no animation-row offset, so idle-versus-walk was not
   merely unimplemented, it was structurally impossible — the sheet had exactly one cycle and
   nowhere to put a second.
2. **The UI look lived as constants inside five screen files.** `menu_screen.gd`,
   `dialogue_screen.gd`, `inventory_screen.gd`, `hud_clock.gd`, `loading_indicator.gd`. The
   accent colour was written out three times in slightly different values (`0.86, 0.74, 0.52`
   twice, `0.90, 0.78, 0.55` once); `40` appeared twice, `24` three times, `18` twice. So a
   restyle was five edits that would drift, and a consuming game had nowhere to put its own look
   but a fork of the screens.

**A FACING IS NOT A COLUMN, and getting that wrong would have re-created the bug.** The obvious
implementation maps `GameEnums.Facing` down onto `layout.facings` — `int(facing) * facings / 8` —
and that puts the number 8 back in the code, in a second place, exactly where it was. So the two
are quantised *separately from the same angle*: `_facing` from `GameEnums.Facing.size()`, because
eight is how many directions the **game** reasons about, and `_column` from `layout.facings`,
because that is how many the **art** distinguishes. Neither reads a literal. When `facings == 8`
they agree by construction, which is why nothing about the existing sheet changed.

**Wrote**
- `src/content/art/sprite_sheet_layout.gd` — 34 code lines. `facings`, `frames`, `animations`,
  `cell_size`, `idle_row`, `walk_row`, plus `sheet_rows()`, `sheet_size()`, `sector_radians()`,
  `column_for_angle()`, `animation_for()`, `frame_index()` and `problems()`. In `src/content/`
  because it is a data shape, so anything may read it, and it touches no autoload — the same
  constraint `item_definition.gd` carries, and for the same reason: `tools/` loads content classes
  under `--script`, where autoload identifiers do not resolve.
- `assets/placeholder/character_layout.tres` — the old constants, moved out of code unchanged:
  8 facings, 4 frames, 1 block, 32x48.
- `assets/placeholder/character_alt_layout.tres` + `character_alt.png` — the swap subject, and it
  disagrees with the default on **every** number: 4 facings, 3 frames in **2** blocks, 24x40.
- `assets/theme/ui_theme.tres`, wired as `gui/theme/custom` in `project.godot`. Nine type
  variations carrying font sizes, a `UiPalette` of four colours, a `UiMetrics` of six insets.
- `tools/gen_placeholders.gd` — `_build_alt_sheet()`, and see below for why every cell is labelled.
- `tests/unit/art_contract_test.gd` — 83 assertions. 930 → **1013**.

**THE PALETTE IS NOT COPIED INTO THE VARIATIONS, and that is the whole design.** A `Theme`
resource has no variables, so a colour repeated into nine variations is nine places to change and
"one Theme edit restyles every screen" would simply be false. So the variations carry **only**
`font_size` — the one thing that genuinely differs by role — and the screens read the four colours
and six insets by name from `UiPalette` / `UiMetrics`. It costs each screen a `get_theme_color`
call and buys the criterion outright.

**Three values were deliberately UNIFIED rather than carried across.** The dialogue box's dim was
`0.03, 0.02, 0.05, 0.72` against the inventory's `0.04, 0.03, 0.06, 0.78`; its speaker tint was
`0.90, 0.78, 0.55` against the others' `0.86, 0.74, 0.52`; its hint was 16pt against the others'
18. Those differences were duplication, not design — nobody chose them — and keeping them would
have meant three palette entries that exist only to preserve a typo. Two column separations moved
by 2px and 4px for the same reason. This is a visual change, and it is the only one in the
package; the captures show it as an improvement in consistency.

**EVERY CELL OF THE ALT SHEET IS SELF-LABELLING, because gotcha 2 has a sharper form here than
usual.** A day/night system that lights nothing is at least obviously wrong on screen. **A
character drawn from the wrong cell still looks like a character** — it is a person, upright, lit,
facing *some* direction. So a capture cannot be *judged*, it has to be *read*. Each cell of
`character_alt.png` therefore carries `column + 1` bright pips down its left edge and `frame + 1`
along its foot, and the two animation blocks wear different tints. Four left pips and two foot
pips on an orange body is block 1, frame 1, column 3 — index `(1*3 + 1) * 4 + 3 = 19` — and no
amount of plausible-looking pixel art can fake that number.

**Verified. Both criteria are VISUAL claims and both were demonstrated by a capture that was
looked at, not by an assertion.**

*Criterion 1 — swap in a sheet with a different cell and frame count, changing no code.* Two
`ExtResource` paths in `scenes/characters/player.tscn` repointed at the alt pair; nothing else
touched, and the file was reverted afterwards. Standing still, the probe logged
`sprite visible=true frame=0/24 size_px=(96.0, 240.0)` and the zoomed capture showed the green
idle-block body, one left pip, one foot pip and eyes — column 0, frame 0, idle. Walking, the probe
logged `frame=19/24` and the capture showed the orange walk-block body, **four** left pips, **two**
foot pips, no eyes and offset legs — block 1, frame 1, column 3, which is index 19 exactly. The
default sheet reports `frame=0/32 size_px=(256.0, 192.0)`, so `hframes`/`vframes` follow the
layout and not a constant. The NPC beside the player kept the 8x4 sheet throughout, which is the
incidental proof that a layout is per-node rather than global.

*Criterion 2 — one `Theme` change restyles every screen at once.* Six lines of
`assets/theme/ui_theme.tres` and no other file: `text` white → near-black, `accent` gold → deep
red, `dim` and `solid` near-black → parchment, `margin` 64 → 120, `TitleText` 40 → 56. Captures
before and after of the main menu and of the inventory screen over a frozen world. Both screens
restyled completely, and the HUD clock followed without being mentioned. Reverted.

*Ladder, all green.* `--headless --import` exit 0 with **zero** `SCRIPT ERROR` / `Parse Error`
lines; boot `0 warnings, 0 errors`; suite **1013 passed, 0 failed, 0 skipped**, exit 0;
`check_budgets`, `check_content`, `check_boundary` all exit 0; windowed capture at 18:40 looked at
and unchanged from before the refactor.

*Both new gates proved RED before green (gotcha 23).* Adding
`add_theme_font_size_override(&"font_size", 22)` back to `hud_clock.gd` — the exact regression the
gate exists to catch — printed `FAILED: hud_clock.gd writes down no font size — expected 0, got 1`
and exited 1. Changing `frames = 3` to `4` in the alt layout printed `FAILED: the alt layout is 3
frames in 2 blocks — expected [3, 2], got [4, 2]` and `FAILED: the two layouts disagree on the
frame count`, and exited 1. Both reverted, both green again.

**A temporary probe, added and removed as gotcha 15 prescribes.** `CharacterVisual.describe()`
existed with no caller, so no run had ever printed which cell was being drawn. A
`_temporary_t21_probe()` in `dev_capture.gd` logged it at the shutter, and a `_temporary_t21_walk()`
pressed `move_left` twelve frames before the shot — an assertion cannot press a key and
`TestCase.run()` never reaches a frame. Both are quoted above and both are gone;
`git diff src/systems/debug/dev_capture.gd` is empty.

**What the assertions deliberately do NOT claim.** `art_contract_test.gd` says so in its header
and means it: it cannot say what a sprite looks like. What it does cover is the part that is a
pure function of the facing count — the sector maths, the frame indexing, the layout's own
validation — plus a **compatibility assertion** that an 8x4 layout produces the same index the old
`_frame * FACING_COUNT + facing` produced, which is what says this refactor moved the numbers
without moving the picture. It also pins the theme resolving *through the project setting on a
live Control*, because a theme item that exists in a file and does not resolve from a node is not
wired — the same failure shape as an unwired `@export`.

**A regression gate, not just a refactor.** The look reached five files one reasonable line at a
time, and nothing but a check stops it going back. `_no_screen_holds_a_size_or_a_colour_of_its_own`
fails if any of the five names a `Color(` or calls `add_theme_font_size_override` in a code line,
and fails if `character_visual.gd` regains a `TAU / 8` or a `FACING_COUNT`. Comments are exempt,
on `check_boundary`'s reasoning: a `##` line naming what the theme replaced teaches by example and
changes nothing.

**Left for later, because the package hit its file budget and half-doing five seams is worse than
finishing two:** shared materials, the environment post-stack and camera framing as `@export`s,
the texture import defaults, and the Git LFS lines. **All five were closed by T3.2** — four built,
LFS refused in writing — and the current state of every one of them is stated once, in
`docs/ART_CONTRACT.md`. Nothing in this paragraph describes the project as it is now.

**One gap the restyle capture exposed, and it belongs to the theme rather than to a screen.** The
theme governs sizes, colours and insets; it does **not** yet set the `Button` styleboxes, so
`MenuRow` and `ChoiceRow` still draw Godot's default dark panel. Against the parchment palette
that left every row dark-on-light — legible, but plainly not restyled with the rest. The seam
exists and is the right one (`MenuRow/styles/normal` and friends in the same file, no code); it is
simply unpopulated. A consuming game with a light palette will hit this immediately, which makes
it T2.2's business to say so, or a one-line theme addition whenever a real look is chosen.

---

## T2.2 · Consumer documentation — **DONE**

**Goal.** Phase T2's last exit criterion, and the only one in the project that cannot be checked
by running a command: *someone who has not read `src/` can author an area, an NPC and a
conversation from the docs.* Everything the template can do was documented in **file headers**,
which are excellent and are the wrong place for a consumer — they are found by already knowing
which file to open. There was no document that starts at "I want to add an area" and ends at a
working area.

**Wrote**
- `docs/AUTHORING.md` — the main deliverable. Task-first: add an area, an interactable object, an
  item, a conversation, an NPC. Each task names the files, the required fields, and the gate that
  catches getting it wrong. Includes the ten required children of an area root, a complete
  minimal area written out in full, the `[editable path=...]` trap, and the debug flags that
  actually drive the game.
- `docs/ART_CONTRACT.md` — the consumer-facing form of the two headers T2.1 wrote to be read by a
  consuming game. The sheet grid, the declared cell size, the theme's three-way split, and the
  `Button` stylebox gap stated plainly.
- `docs/TESTING.md` — the five non-obvious rules of this suite, each of which has cost this
  project an hour: the suite is a scene, `run()` is synchronous, every case declares a plan, the
  plan is not enough on its own, and an unlisted case never runs.
- `docs/ARCHITECTURE.md` § **The extension surface** — three tiers: authored data, the points that
  are open to subclass or replace, and the internals. **Put in `ARCHITECTURE.md` and not in
  `AUTHORING.md` deliberately:** `AUTHORING.md` is about content files that need no code at all,
  and the moment it also described subclassing, the "you never edit `src/`" line at its head would
  have been contradicted by its own contents.
- `tests/unit/docs_test.gd` — 68 outcomes, computed rather than declared. 1013 → **1081**.
- Both routers: a doc-router table in `CLAUDE.md` replacing a flat list, and `CONTEXT.md`'s
  "Read next". A document nobody is routed to is a document nobody reads.

**THE CRITERION WAS PERFORMED, NOT ASSERTED, and the deliverable of that exercise is the list of
things that were wrong.** A new area, a new NPC with a schedule and a new four-node conversation
were authored from `AUTHORING.md` alone — nothing copied from an existing area, no `src/`
consulted while writing them. The full ladder ran green with the new content in
(`1101 passed`), `check_content` passed including the `[editable]` gate, and a windowed capture at
midday shows the new NPC in the new area delivering its first-meeting line over a dialogue box.
Then **the content was deleted** — it was a test of the documents, not new demo content, and
`TEMPLATE.md` is explicit that the demo does not get deepened.

**Six defects the walkthrough found, in the order they hurt:**

1. **The documented capture command never leaves the main menu.** A `--shot` on its own
   photographs the title screen; the area is never entered. An author following the document
   would see their brand-new area render as somebody else's menu. `--new-game` is required, and
   nothing anywhere documented the debug harness flags at all — now a table of eight in
   `AUTHORING.md`.
2. **The gate table claimed the boot rung catches "an unresolvable first area".** It does not.
   `--headless --quit-after 120` stops at the main menu and reports `0 warnings, 0 errors`
   without loading any area, so it cannot see a wrong `area_id`, an empty navmesh bake or a
   broken NPC. Gotcha 22's family: a rung reporting clean about work it never did.
3. **`--stand-by=` takes a NODE NAME, not an `object_id`** — and the id is what the same document
   had just told the author to set. It fails with `found no node called ...`.
4. **The NPC placement example omitted its own `[ext_resource]` line** for the NPC prefab, so the
   block could not be used as written. Every worked example is now self-contained.
5. **The navmesh example implied a healthy bake is a big number.** A flat floor bakes **2**
   polygons, which looks like the empty-bake failure and is not. Now: any non-zero count.
6. **The suggested capture hour makes a new area look broken.** A minimal area has no props and
   no lanterns, and at 18:40 it renders very nearly black. Now: capture at midday first.

Two things the walkthrough confirmed rather than corrected, both worth recording because they are
the parts most likely to be got wrong from a document: an override block on a node inside an
instance needs **no `index=`** — the name resolves it, and the stale indices in the demo's
courtyard really are the red herring T2.0 said they were — and one `[editable path=...]` at the
foot of the file is sufficient for both overridden children of one instance.

**`docs_test.gd`, and why prose got a gate at all.** Most of this package is prose and prose is
not assertable. But two things in a consumer document are facts about the repository and both rot
in silence: a `res://` path that no longer resolves, and a field name in a worked example that was
renamed. Both are found by a reader, once, following the document into a dead end and concluding
the template is broken. So the case scans every `.md` in `docs/` plus `CLAUDE.md`, asserts every
`res://` path resolves, and — by reading each fenced block's own script `ext_resource` lines —
asserts that every property named in a worked `.tres`/`.tscn` example exists on the class that
block says the resource is scripted by. The class mapping comes out of the documents, so there is
no second list here to go stale in turn.

**Paths under the content roots are skipped when absent, not failed**, because `docs/` teaches by
example and a stripped template has deleted exactly those files.

**`DEVLOG.md` is exempt, and finding that out was the case's first red.** Its very first run failed
on a path the DEVLOG names under `tests/unit/`: a temporary probe created to prove the runner
fails on a crash, quoted by name, and then correctly deleted. That is a true entry about a path
that should not exist. A log of what was done necessarily names removed files, so the history is
scanned for nothing; everything a reader is meant to *follow* still is. It is also why the two
planted violations below are quoted verbatim in `DEVLOG.md` and only described here.

**Proved red, then green (gotcha 23).** Two planted violations, both the real failure shape rather
than a convenient one: renaming `walk_row` to a name the class does not have, in `ART_CONTRACT.md`'s
worked layout, and repointing one script path in `AUTHORING.md` at a file that does not exist.
Together they produced **6 failures** and exit 1 — one for the dead path, one for the renamed
field, and four for the properties that could no longer be resolved against a missing class. Both
reverted: `1081 passed, 0 failed, 0 skipped`, exit 0. The output is in `DEVLOG.md`.

**Two documents were corrected in passing, because a consumer reads them.** `ARCHITECTURE.md`'s
area diagram listed **eight** children and was missing `Navigation/` and `Waypoints/` — as did
`SYSTEMS_INVENTORY.md`'s row, which said "the eight required children are now asserted" while
`transitions_test.gd` has asserted **ten** since it was written. And two of `ARCHITECTURE.md`'s
"known limitations" had been false since T2.0 and WP-13 — the export path is proven and weather
does render — so they are replaced by the two that were true then: the `Button` styleboxes, and the missing
material and camera exports. The second was closed by T3.2 and its bullet is gone.

**The `Button` stylebox gap was left unfixed, deliberately.** It is one addition to
`ui_theme.tres` with no code, and it was tempting. But a stylebox has to be *designed*, and the
only palette available to design against is the placeholder one — so the result would be a
decision shipped as a default, in a package whose whole job is to describe the template honestly
rather than to change it. It is now stated in three places a consumer actually reaches:
`ART_CONTRACT.md`, `ARCHITECTURE.md`'s limitations, and `CONTEXT.md`. The main-menu capture taken
during the walkthrough shows it plainly.

**Ladder, all green.** `--headless --import` exit 0 with **zero** `SCRIPT ERROR` / `Parse Error`
lines; boot `0 warnings, 0 errors`; suite **1081 passed, 0 failed, 0 skipped**, exit 0;
`check_budgets`, `check_content`, `check_boundary` all exit 0; windowed capture at 18:40 taken and
looked at, and the courtyard is unchanged.

**Why the next package is WP-08 and not a new T-phase row.** Phase T2 closes here: all four exit
criteria are ticked. Phase T3 is *"finish the system catalogue"*, and its packages are the
original WP-08 to WP-15, re-framed — so T3 is the phase and WP-08 is its first package, not an
alternative to it. The board's ordering predates the template reframing and survives it: quests
are a system with **no** proof at all, and the replacement rule is breadth of systems, one shallow
proof each. The five T2.1 leftovers are engine work whose two exit criteria are already met; they belong in a
T3 row of their own rather than reopening T2. That row became **T3.2**, and closed them.

**CI green, run 33086307621, job logs read rather than the tick.** Full checkout
`1081 passed, 0 failed, 0 skipped`; stripped template `1027 passed, 0 failed, 16 skipped`, the
four new skips being exactly the doc-named paths under the content roots that a stripped checkout
has deleted. All three checkers PASS in both jobs.

**Commit:** `36b5abd` on `claude/t2-2-consumer-docs`, PR #15.

---

## T3.1 · A generic content registry — **DONE**

**Read:** the five registries — `src/content/items/item_db.gd`, `dialogue/dialogue_db.gd`,
`npc/schedule_db.gd`, `quest/quest_db.gd`, `world/area_db.gd` — plus `docs/AUTHORING.md` as the
acceptance test and `tests/framework/fixtures.gd` as the seam most likely to break.
**Write:** one scan, and a thin typed façade per catalogue.
**Exit criteria:** the five catalogues behave identically from the outside — same typed
accessors, same ids, same per-file error reporting, same `content_dir` redirection — with the
scan living in one place; **or** the row closed with a measured argument for the five copies.

**THE ROW WAS COSTED TWICE BEFORE THIS CHAT, AND BOTH COSTINGS WERE RIGHT ABOUT THE WRONG
THING.** WP-08 reconsidered at the fourth copy and kept it: GDScript has no generics, so a base
holding the CACHE could only store `Resource` and hand it back untyped, making every accessor a
cast at the call site — against non-negotiable #2. WP-11 made it the fifth and changed only the
arithmetic. Neither verdict is overturned. **What neither weighed is that the duplication was
never in the cache.** It was in the scan, and a scan needs exactly two things from a resource:
its `id`, and its `problems()`. So the base went on the **resource** (`ContentEntry`) and the
shared part is a **function** (`ContentScan.into()`) that fills the *caller's own typed
dictionary*. `ItemDb._by_id` is still `Dictionary[StringName, ItemDefinition]`,
`ItemDb.definition()` still returns `ItemDefinition`, and there is no cast at any call site in
the project. WP-08's constraint was satisfied rather than traded away.

**THE MEASUREMENT, WRITTEN DOWN AS THE ROW ASKED, in code lines as `check_budgets` counts them.**

| | before | after |
|---|---|---|
| `item_db.gd` | 70 | 36 |
| `dialogue_db.gd` | 53 | 36 |
| `schedule_db.gd` | 53 | 36 |
| `quest_db.gd` | 53 | 36 |
| `area_db.gd` | 61 | 43 |
| **five registries** | **290** | **187** |
| `content_scan.gd` | — | 39 |
| `content_entry.gd` | — | 5 |
| **total** | **290** | **231** |

Net −59 lines, and that is the *least* interesting number. What was genuinely identical across
the five was `_register()` at 17 lines apiece — the load, the type check, the id-equals-filename
check, the duplicate check and the `problems()` append — plus a five-line `_ensure_loaded()`.
Roughly a hundred lines of copy became one twenty-line function, so **a bug in the id check, the
duplicate check, the type check or the `.remap` handling is now one fix instead of five.** What
did NOT move is the part that carries a type: each façade keeps its own `content_dir`, its own
typed `_by_id`, and its own accessor. Five wrappers of the same length was the outcome to avoid
and it did not happen — `has()`, `all()`, `count()`, `problems()` and `rescan()` were never the
duplication, they are three lines each and they name their own type.

**A STATIC BASE CLASS WOULD HAVE BEEN A DISASTER, AND IT TOOK A PROBE TO KNOW IT — NEW GOTCHA
37.** The obvious shape is `ItemDb extends ContentDb`, with `_by_id`, `_loaded` and `content_dir`
as `static var`s on the base. Measured under 4.7.2 with two throwaway subclasses bumping a base
counter: `A.shared=3 B.shared=3 Base.shared=3`. **A base-class `static var` is ONE storage shared
by every subclass.** Five registries inheriting it would have shared one cache and one
`content_dir`, so `Fixtures.activate()` would have pointed all five at one folder and four
catalogues would have come back empty — with every accessor still typed and the shape still
looking right. That is why the shared part had to be a function.

**`ItemDb.resource_paths()` BECAME `ContentScan.resource_paths()`, and no alias was left.** The
function was always the shared scan; four registries, `check_content.gd`, `catalogue_report.gd`
and three test cases called it through the item registry, and `path_actions_test.gd` scanned
**path actions** through it. Three registry headers spent a paragraph apologising for the call.
Nine call sites, one identifier each, and three headers got shorter. A delegating alias was
considered and refused: the point of the package is one implementation with one name.

**WHAT THE `ContentEntry` BASE IS ACTUALLY FOR, because "a base class for tidiness" would be the
wrong reason.** `project.godot` sets `unsafe_property_access` and `unsafe_method_access` to
**error**, so a shared scan reading `resource.id` or calling `resource.problems()` through a
`Resource` does not compile. `ContentEntry` is what makes the shared scan legal. It holds exactly
the two members the scan uses and its `MUST NOT` says so: a field belongs there only when the
SCAN uses it.

**THE ACCEPTANCE TEST WAS `AUTHORING.md`, AND NOT ONE WORD OF IT CHANGED.** It names `ItemDb`
once, describes the scan, the folders and the id-equals-filename rule, and every sentence is
still true. Neither did `data/`: the demo's `.tres` files were untouched and load unchanged with
`id` now declared on the base.

**47 NEW ASSERTIONS, AND THEY ARE ABOUT THE FAILURE MODE A SHARED SCAN HAS.**
`tests/unit/content_scan_test.gd` drives `ContentScan.into()` directly for every branch it has —
empty root, absent root, sound file, id mismatch naming both values, a resource of the wrong
type, a `.tres`/`.res` duplicate, an empty prefix, and a resource whose own `problems()` must
reach the caller — and then plants the *same* violation in all five fixture roots at once and
names each registry: **a shared scan is exactly the change that can leave four catalogues
reporting a bad file and the fifth silent.** It also asserts that one bad file costs the
catalogue exactly that file, because a scan that gave up on the first problem would satisfy every
other assertion in the file.

**THE ONE THING THE TEST GOT WRONG FIRST, and it is worth the line.** Re-saving a *different*
`AreaDef` over a path already loaded in the same run handed the scan back the FIRST resource:
`ResourceLoader` caches by path. One failing assertion — `expected 1, got 0` — was the only
trace, and the fix is a second id rather than a second write. Anything in the suite that expects
a re-authored file to be re-read needs a new path.

**Verified.** `--headless --import` with zero `SCRIPT ERROR` / `Parse Error`; boot
`0 warnings, 0 errors`; **`1402 passed, 0 failed, 0 skipped`** (was 1355 — +47, none lost);
`check_budgets` 125 files / 10,506 code lines / 0 warnings / 0 violations; `check_content` PASS;
`check_boundary` PASS over 119 engine scripts. **Stripped template run locally** — `data/` and
`scenes/areas/` moved aside — `1334 passed, 0 failed, 19 skipped` (was 1287/19), both checkers
exit 0, which is the rung that proves an empty content root is still not an error.

**The gates were proved failing, not assumed (gotcha 23).** Two real violations planted in
`data/items/`: `planted_mismatch.tres` carrying `id = &"item/mismatched"`, and
`planted_broken.tres` containing one line of prose. `check_content` exit **1**, naming both —
`planted_broken.tres is not an ItemDefinition`, and
`planted_mismatch.tres declares id 'item/mismatched' but its file name requires
'item/planted_mismatch'`. Both removed; exit **0**. The verbatim output, with the full paths, is
in `DEVLOG.md`, which is the one document exempt from the `res://`-path gate.
The suite's own exit-1 was proved by the
accidental `ResourceLoader` cache failure above — `1401 passed, 1 failed`, exit 1.

**A windowed capture, although there should have been nothing to see, and there was not.**
`--new-game --shot-frame=70 --quit-after 90 --time=12:00`: the courtyard at midday with the
player, the keeper, the sign, the pickup, the HUD clock and the `Read Weathered Notice` prompt —
indistinguishable from WP-09b's. The boot readout still names every catalogue and its resolved
paths: `items: 4`, `dialogue: 1`, `schedules: 1`, `quests: 1`, `areas: 2`. **If a screen had
changed, the refactor had leaked.** No temporary probe was needed: this package touches no input
and no audio path. `src/systems/debug/catalogue_report.gd` carries one deliberate line — the
`resource_paths` rename — and nothing else.

**Files: 20, and the board's "about 8" is worth explaining rather than quietly exceeding.** Two
new engine files, five registries rewritten, five resource classes changed by one `extends` line
each, one new test case, and eleven single-identifier renames the compiler would have caught. New
code is **negative**. A refactor's file count is a poor proxy for how much of a chat it costs, and
the rule's own reasoning — a package that outgrows one chat gets half-finished — was never in
danger here.

**Why this was taken over T3.2 and T3.3.** T3.2 is five deferred art seams and T3.3 adds a
capability. This row was the only one on the board that was pure debt with a known interest rate,
and it was the one that got *worse* every package — a sixth catalogue would have been a sixth
copy. **T3.3 is next**: "bring me three petals" is still not authorable, which is a limit on what
a consuming game can express, and `TEMPLATE.md`'s replacement rule puts breadth of expression
ahead of art seams.

**Not built, and said rather than dropped:** a sixth catalogue, a hot-reload or file-watcher on
the content roots, a content editor, async or threaded scanning, a cache that outlives a session,
and any change to what a `.tres` may contain. `ContentScan` also does not recurse into
subdirectories — neither did any of the five copies, and a nested content root is a request
nobody has made.

**Commit:** `767fbe3` on `claude/t3-1-registry`, PR #20 — stacked onto
`claude/wp-09b-attributes`, matching the rest of the chain.

---

## T3.3 · A quest step that can read an ITEM COUNT — **DONE**

**Read:** `src/content/quest/quest_step.gd`, `src/systems/quest/quest_tracker.gd`,
`src/core/state/flag_query.gd`, `src/gameplay/character/inventory.gd`, plus `AUTHORING.md`'s quest
and item sections read as a consumer would.
**Write:** a step that can require N of an item id, without the quest system learning what an
inventory is.
**Exit criteria:** the journal shows the progress, the step completes at the threshold, and it
uncompletes or does not — per a decision stated out loud and asserted.

### The row was scoped once and it named two designs. This is the FIRST one, with the cost that made it look expensive removed.

WP-09 declined to close this and costed both candidates rather than shrugging:

> an `Inventory` that mirrored `count/<item>` into `Flags` would write every carried item into the
> flag section as well as its own, and a `QuestStep` that read the bag directly would put
> `gameplay/Inventory` inside a `systems` tracker against the layer rule.

**The second one is not a design, it is the layer rule being broken**, and WP-08 had already
refused exactly that once — the `reward_item` field. So the choice was the first one or nothing,
and the whole question was whether its stated cost is real.

**It is not, and one line of `flags.gd` is why.** The cost was "the same number is now in the save
file twice, written by two participants in two formats" — which is a genuinely bad trade, and it is
also the thing `flags.gd`'s own header forbids: *"WHAT DOES NOT BELONG HERE: anything recomputable.
If it can be derived, derive it."* A count mirrored into `Flags` is recomputable BY DEFINITION,
because the bag it came from is the truth and is already saved. So the mirror is declared DERIVED:

```gdscript
Flags.declare_derived(BagKeys.PREFIX)          # Inventory._ready
```

and `Flags._collect_save` skips those keys. The published count is readable, announced on
`flag_changed`, visible to `FlagQuery` — and absent from the save file. **`Inventory.SAVE_VERSION`
did not move, `Flags`'s format did not change, and there is no migration**, which is the answer to
the package's "a new field on a saved resource may need a version bump": nothing new is saved.

### The one decision everything else follows from: THE DEPENDENCY POINTS DOWN, so the quest system was not touched at all.

```
bag/<carrier_id>/<item id>          bag/player/item/rose_petal -> 3
```

`Inventory` (`gameplay`) writes to `Flags` (`core`). `QuestTracker` (`systems`) reads `Flags`
through the `FlagQuery` it already used. **Neither has heard of the other**, and the inversion is
the entire package: a tracker reading a bag points UP, a bag publishing a flag points DOWN, and
they deliver the same capability.

What that bought, and none of it is a coincidence — it is WP-08's seam used for the **third** time
after `Equipment`:

- **`QuestStep` gained no field.** Not `required_item`, not `required_count`. A counted step is
  `condition_flag = &"bag/player/item/rose_petal"`, `condition_test = 4`, `condition_value = 3` —
  the closed set of six comparisons, unchanged since WP-08.
- **`QuestTracker` gained no knowledge.** Its one new function, `step_progress`, is a pass-through
  to `FlagQuery`; it names no `Inventory`, no `ItemDb` and no `BagKeys`.
- **Nothing that writes a count had to change.** A `Pickup`, an `ItemContainer`, `--give=` and a
  restored save all go through `Inventory.add`, so all four advance a counted step already.
- **Sixth namespace-over-`Flags`**, after `PersistentState`, `Standing`, `Equipment`, `WorldMap` and
  `Attributes` — and the first whose value is a NUMBER rather than a truth.

**And a test fails if that stops being true.** `item_count_test.gd`'s last block text-scans
`quest_tracker.gd` and `quest_step.gd` for `Inventory`, `ItemDb.` and `BagKeys`, and
`journal_screen.gd` for `Flags.`. Nothing else in the suite could fail if the tracker started
reading a bag directly — **the behaviour would be identical and the layer rule would be gone** —
which is the same reasoning `art_contract_test.gd` uses to keep a sheet dimension out of
`character_visual.gd`. It also asserts that exactly ONE file under `src/` builds a bag key.

**The first version of that block was WRONG in an instructive way.** A raw text scan failed on both
files, because both HEADERS explain at length why an `Inventory` is not reachable from them — so
the gate fired on the paragraph documenting the rule it enforces. `check_boundary` had already drawn
this line: **comments are exempt, code is not.** The block now strips comment lines first.

### `BagKeys` is its own file, and the reason is a compile error rather than tidiness.

Three places need the key shape and none may rebuild it: `Inventory` WRITES it,
`tools/check_content.gd` PARSES it back to validate the item id, and the suite asserts on it.
`Equipment.PREFIX` lives on `Equipment` and that could not work here: `check_content` runs under
`--headless --script`, where autoload identifiers do not resolve, so naming `Inventory.PREFIX`
would not COMPILE — the mechanism that file's own header calls a real enforcement of the layer
rule. `src/core/state/bag_keys.gd` touches no autoload, and its MUST NOT says it must not start.

The parser earns its place on one line: **an item id contains a slash**, so the carrier is the
FIRST segment after the prefix and the item id is everything left. Splitting on the last slash
answers `rose_petal`, which `ItemDb` would then fail to find — a validator failing on valid content
is worse than no validator. That round trip is an assertion.

### THE UNCOMPLETE QUESTION, STATED OUT LOUD: a step reopens, a quest does not — and no new decision was needed.

This is the exit criterion that asked for a decision, and the honest answer is that WP-08 had
already made it and `quest_tracker.gd`'s header names **this exact case**:

> A step may test AT_LEAST 3 on a counter; if something later decrements it, a finished quest would
> reopen. Completion is a fact about history, not about the world right now.

So: **spend a petal on an ACTIVE quest and the objective comes back**, because a step is a live
question. **Spend one after the quest settled and nothing happens**, because completion is latched
and saved. Both halves are asserted against the thing that finally decrements — a bag — rather than
against a flag written by hand, which is all the suite could do before. The package's contribution
here is not a decision; it is the first real test of one.

Two adjacent behaviours, also asserted: a count **already satisfied** when the quest starts passes
its step at once (a step is never "reached"), and a FOURTH petal does not un-finish a step needing
three, because the test is `AT_LEAST` and not `EQUALS`.

### The journal draws the tally, and it still reads no flag.

`— Gather three rose petals.   2 / 3`, from `ui.journal.progress`. An objective line is a FORMAT,
so the format is a localization key and not a `"%s / %s"` in a screen file.

`journal_screen.gd`'s MUST NOT line forbids it from reading a flag, and drawing "2 / 3" needs the
current value of one. Non-negotiable #4 says: when a change needs a MUST NOT broken, add a system
instead of widening the boundary. So `FlagQuery.progress()` answers `(have, need)` — where the
comparison table already lives — and `QuestTracker.step_progress()` passes it through, so the
screen still talks to nothing but the tracker.

**`need == 0` means "not a count", and two of the six tests deliberately return it.** `AT_MOST` is
a CEILING: drawing `2 / 3` under *keep it below three* would tell the player to gather more of the
one thing they must not. And a `condition_value` of 0 is not a count either — `AT_LEAST 0` passes
with an empty bag, so it is an unconditional step wearing an errand's clothes.

### The new content gate, and why validating THIS flag namespace is not a contradiction.

`check_content` prints every quest flag and validates none of them, on a rule WP-08 wrote down: a
flag can be written from a scene, a conversation, a path action or at runtime, so failing on one
with no findable writer would be wrong most times it fired. **`bag/<carrier>/<item id>` is different
in the one way that matters: it has exactly ONE writer, and half the key is an item id this tool can
look up.** So three mistakes that are otherwise completely silent now fail the build:

- an item id **no `.tres` declares** — the count reads zero forever and the objective never clears;
- a **count of zero**, which is always satisfied;
- a bag key under a test that is **not a count** — worse than the others, because `get_bool` on an
  int warns and answers false, so the step can never pass at all.

The carrier is deliberately NOT validated, and the omission is stated rather than papered over: a
`carrier_id` is an `@export` on a node in a scene this tool does not open, and a game may put a bag
on an NPC or a stash. Same line `_all_waypoint_names` draws.

`_condition_text` also now prints the VALUE for the tests that use one. The first version did not,
and `bag/player/item/rose_petal at_least` in the build log says nothing about the errand a reviewer
is checking.

### ALL THREE BRANCHES PROVED RED, THEN GREEN, WITH THE REAL FAILURE SHAPE (gotcha 23).

Planted in `data/quests/keepers_errand.tres`, one at a time, each reverted:

1. **A plural slip on the item id** — `item/rose_petals`. `check_content` exit **1**:
   `quest/keepers_errand/petals counts 'item/rose_petals', which no item .tres declares`.
2. **`condition_value = 0`.** Exit **1**:
   `quest/keepers_errand/petals asks for 0 of 'item/rose_petal'; a count below one is always satisfied`.
3. **`condition_test = 1`** (IS_TRUE on a count). Exit **1**:
   `quest/keepers_errand/petals tests an item count with is_true, which is not a count`.

Reverted after each: exit **0**, with `petals done when bag/player/item/rose_petal at_least 3` in
the build log.

**And the suite's own exit 1, on the invariant rather than on a broken assertion.** The load-bearing
invariant is that every path which moves a count republishes, so `_publish()` was deleted from
`remove()` — the way it would really be lost. Exit **1**, `1460 passed, 9 failed`, first failure
*"spending two republishes one — expected 1, got 3"*, and `error_watch.gd` additionally caught the
downstream crash: a quest wrongly completed, so `current_step` answered null. Restored:
`1468 passed, 0 failed`, exit 0.

### One latent defect found, because the design could not tolerate it.

**A new game did not empty the bag.** `Director.start_new_game()` clears the flags, resets the
playtime and emits `game_started`; nothing was listening on behalf of `Inventory`, so the previous
run's items carried into a fresh game. Unreachable in practice — the boot goes to the main menu with
an empty bag — and invisible to every gate, because nothing asserted it.

It surfaced only because this design *cannot* tolerate it: the flags are cleared and `_counts` is
not, so the mirror and the truth disagree the moment a new game starts. `Inventory` now clears on
`game_started` and republishes on `game_loaded` — the second because `Flags._apply_save` wipes the
store and the derived keys are deliberately not in the file it restores from, so **the answer must
not depend on save-participant order**, and `game_loaded` fires once after every section is applied.
Both are asserted.

**And that made `--give=` need the area wait**, which is gotcha 32 for the FOURTH time after
`--open-menu`, `--flag` and `--open-inventory`: items staged during argument parsing are now thrown
away by the new game a frame later. Given the wait, `--give` and `--equip` would then leave
`_wait_for_area` on the same frame and be ordered by chance — gotcha 35 — so `--equip` waits one
frame more. That is an ordering rather than a race, and it was **verified both ways round on the
command line**: `--equip` reports `true` whether it is typed before or after `--give`.

### Two windowed captures, LOOKED AT and READ rather than glanced at (gotcha 28).

Both `--new-game --open-menu=journal --shot-frame=110 --quit-after 130 --time=12:00 --freeze-time`,
so the two differ by exactly one petal:

- **`--give=item/rose_petal:2`** — `Journal / Underway / The Keeper's Errand /
  — Gather three rose petals.   2 / 3`, with the *New errand* toast up, the HUD reading
  `Day 1 | 12:00 | Midday`, and the courtyard visible and stopped behind the dim panel. The tally
  is a **checkable prediction** and not a screenshot that merely looks fine: two given, three
  required.
- **`--give=item/rose_petal:3`** — the same screen, same camera, same hour: `Settled /
  The Keeper's Errand / — Nothing left to do.` The log line between them is
  `quest/keepers_errand: completed`.

The staging log is the other half of the reading, because it shows the objective walking forward
through steps the demo already had: `--give item/rose_petal x2: true`, then `started`, then
`advanced [unlock]`, `advanced [dais]`, `advanced [petals]`.

**No temporary probe was needed and none was left** (gotcha 15). This package touches no input path
and no audio path — `J` was proved by WP-08's probe and `ScreenKeys` was not touched.
`git diff src/systems/debug/` carries only the `--give` wait, the `--equip` frame gap and their
header lines.

### The demo gained ONE step and one petal, and no new object.

A third step on `keepers_errand`, last so the two existing objectives and both WP-08 captures still
mean what they meant, and the courtyard chest holds three petals instead of two so the errand can
actually be finished. **One piece of placeholder content per system**: no second quest, no second
item, no new pickup.

### Files: 14, and new code is 312 lines added against 22 removed.

`src/core/state/bag_keys.gd` (28 code lines, new) · `flags.gd` (+`declare_derived`, `is_derived`,
and `_collect_save` skipping them) · `flag_query.gd` (+`progress`) · `inventory.gd`
(+`carrier_id`, `_publish`, the two subscriptions) · `quest_tracker.gd` (+`step_progress`) ·
`journal_screen.gd` (the tally line) · `dev_stage.gd` (the `--give` wait, the `--equip` frame gap) ·
`tools/check_content.gd` (`_check_item_count`, `_condition_text` with its value, `_test_name`) ·
`data/quests/keepers_errand.tres` and `courtyard.tscn` and 3 CSV rows ·
`tests/unit/item_count_test.gd` (66 outcomes, new) · `fixture_content.gd` (a second fixture quest
and a counted `quest_step`) · `fixtures.gd` · `content_scan_test.gd` (its hard-coded `1` became
`FixtureContent.quests().size()`, on the same reasoning as a computed plan) ·
`docs/AUTHORING.md` § Count items in a quest step.
1402 → **1468**.

### Ladder, all green.

`--headless --import` with **zero** `SCRIPT ERROR` / `Parse Error` lines; boot
`0 warnings, 0 errors`; suite **1468 passed, 0 failed, 0 skipped**, exit 0; `check_budgets`
**127 files, 10,869 code lines, 0 warnings, 0 violations**; `check_content` PASS; `check_boundary`
PASS over 121 engine scripts, deriving 16 demo names and finding none of them in `src/` or `tests/`.

**Stripped template, run locally** — `1400 passed, 0 failed, **19** skipped` (was 1334/19), both
checkers exit 0, `quests: 0` and `demo names derived: 0`. **The skip count did not move**: all 66
new assertions are fixtures all the way down and every one runs in a checkout with no game in it.

### Deferred, with reasons, not silently.

- **A step that TAKES the items.** A completed quest still emits `quest_completed` and stops —
  WP-08's layer reason holds exactly as it did, and a consuming game that wants the petals handed
  over listens to the signal or puts an `ItemContainer` in front of the keeper.
- **No sixth catalogue.** T3.1 made one cheap and WP-09b declined one deliberately; a count needs no
  resource, no registry and no save section, which is `Attributes`' argument used a second time.
- **`AT_MOST` draws no tally**, on purpose — see above. And `EQUALS` counts, though nothing authored
  uses it.
- **No count in the inventory screen's rows beyond `xN`**, no "quest item" marker, and no objective
  marker on the map — `quest_advanced` has an emitter, so a marker is a listener plus one more
  `MapScreen` state, and that is WP-11's deferred row rather than this one.
- **The carrier is not validated by any gate**, stated above.
- **Branching quests, a failure state, timed quests, item instances and a journal detail pane** are
  all still deferred, unchanged.
- Combat is still not a thing, and a count of arrows would not change that.

**CI green, run 33529911105, job logs read rather than the tick** (gotcha 26). Full checkout
**1468 passed, 0 failed, 0 skipped** with `item definitions: 4` and `quests: 1`; stripped template
**1400 passed, 0 failed, 19 skipped** with `item definitions: 0` and `quests: 0`. All three checkers
PASS in both jobs. **19 skips in both the previous run and this one** — no new skip to name, because
the counted step is proved on a fixture quest and a fixture item that a stripped checkout still
writes to `user://`. The push run (33529829466) and the pull-request run (33529893285) are green
too.

**Commit:** `292dd44` on `claude/t3-3-item-count`, PR #21 — stacked onto `claude/t3-1-registry`
(#20) rather than `main`, matching the rest of the chain.

---

## T3.2 · The five art-contract seams T2.1 left — **DONE**

**This is the last T-numbered row of Phase T3, and the phase is NOT closed by it.** WP-14 is still
TODO and WP-15 has a remnant; the phase's exit criterion is about systems having a proof, not
about T-rows being finished. The chip this package raises is for WP-14.

**Read:** `docs/ART_CONTRACT.md` as the consumer it is written for, `docs/CONTEXT.md` gotcha 30,
and the two area scenes, `src/gameplay/world/environment_driver.gd`,
`src/gameplay/camera/hd2d_camera_rig.gd`, `project.godot`, `.gitattributes`.
**Write:** whatever each of the five needs — including nothing, said out loud.
**Exit criteria:** for each of the five, either the seam EXISTS and a change to one file
demonstrably changes what is rendered, or it is REFUSED in writing with the reason, where an
artist reads it. Either way each is mentioned in exactly **one** place afterwards.

### The row's real deliverable was the fifth criterion, not the first four.

These five were named in `CONTEXT.md`, `ROADMAP.md`, `WORK_PACKAGES.md`, `ARCHITECTURE.md` and
`ART_CONTRACT.md` — five documents, four of them too many, each saying a slightly different thing
about work nobody was doing. A backlog item mentioned in five places is not tracked five times; it
is tracked zero times and described five times, and the descriptions drift. So half the acceptance test
here is documentary, and it is worth stating PRECISELY, because the loose version of it is not
what was achieved. **What is now in exactly one place is the CURRENT STATE of each seam — the
thing a reader would act on — and that place is `ART_CONTRACT.md`.** The four stale claims are
gone: `ARCHITECTURE.md`'s "no shared material library" bullet is deleted, `CONTEXT.md`'s "Not
built" line no longer lists them, `ROADMAP.md`'s T2.1 entry says "closed by T3.2" instead of
reciting the five, and `.gitattributes` points at `ART_CONTRACT.md` instead of restating the LFS
reason.

Each seam is still NAMED in several documents, and that is correct rather than a failure to
finish: a package section in this file, a settled decision in `CONTEXT.md`, a row in
`SYSTEMS_INVENTORY.md` and a gotcha are the project's standard record shape for finished work, and
none of them is a description of pending work that can drift out of date. **The difference that
mattered was never the number of mentions; it was five documents each independently describing
something nobody was doing.** Nothing was deleted from the record either: T2.1's own section still
says what T2.1 left, because that is still true, and now says where to read what happened to it.

**Four built, one refused.** The refusal is written where an artist reads it, with the reason and
with the steps to turn it on, which is a different artefact from silence.

### 1. Shared materials — BUILT, and the defect was already in the tree.

`assets/materials/wood.tres`, pointed at by both areas with an `ExtResource`. The two demo areas
had each grown a **byte-identical** `StandardMaterial3D` called `m_wood` — same texture, same
`texture_filter = 0`, same `uv1_scale = Vector3(2, 2, 1)` — and neither file could see the other.

**A library of ONE, and that is the whole argument.** The other five materials across the two
areas are deliberately still inline, because they are not duplicates: one area tiles stone at
`(3, 3)` and the other floors it at `(8, 8)` and walls it at `(6, 2)`. **A tiling rate is a
property of the surface it is stretched over, not of the substance**, so hoisting those would give
a shared file with a per-area override on every user — the duplication with an extra indirection,
and a palette instead of a seam. A material is shared when two areas genuinely want the same
thing, and exactly one of six did.

Nothing under `src/` knows the folder exists. A shared material is a scene-authoring convention,
not a system: no registry, no id, no directory scan, no sixth catalogue.

**What already made this safe, and it was not planned for this:** `SurfaceWetness` duplicates
every material before darkening it (WP-13's settled decision). Without that, rain in the courtyard
would leave the hall's plinth wet on the far side of an area change — the exact failure a shared
sub-resource invites, closed a package before it could happen.

### 2. The environment post stack — BUILT, twenty exports at the values T2.1 shipped.

`_build_post_stack()` held twenty literals. All twenty are now `@export`s on `EnvironmentDriver`,
in two groups, **at exactly the values they had**, so no area that leaves them alone renders
differently — the point of the seam is that a game can reach them, not that anything moved.

**Per AREA, not per project, and not a resource.** The driver already lives in the area scene and
its `Interior` group already varies that way; a game wanting one look everywhere authors its areas
from one copy. A `.tres` "environment look" resource was considered and dropped: it is the shape
`SpriteSheetLayout` has, but a layout is *shared between nodes in one scene* while a post stack is
*one per area* — so it would have added a resource class, a folder and a wiring step to reach
exactly the same set of numbers.

**What stayed in code, and why that is not half a job.** The tonemapper, the fog mode, the glow
blend mode, `AMBIENT_SOURCE_COLOR` and `BG_SKY` are the STRUCTURE the rest of the file assumes,
not numbers an area tunes — `_apply_now` writes `ambient_light_color` every frame, which only
means anything if the source is a colour. The four expensive effects (`ssao`, `sdfgi`, `ssil`,
`ssr`) ARE exports despite being `false` everywhere, because "revisit only if the look demands it"
is a decision for the game and **a value a consuming game cannot reach is not a seam, it is an
opinion.** The day/night KEYFRAMES table is untouched and no seam is claimed for it: that is a
curve, not a look setting.

### 3. Per-area camera framing — the seam ALREADY EXISTED, and the row was wrong about it.

`HD2DCameraRig` has carried `distance`, `fov`, `pitch_degrees`, `height_offset`, `follow_lag`,
`frame_bias` and the whole depth-of-field group as `@export`s since it was written, and its header
has said "duplicate it and change the numbers" the whole time. What was missing was **an area
using them** — both demo areas took every default, so the claim had never been run.

So this one cost an authored value and a capture rather than an implementation: the interior now
frames at `distance = 9.5, fov = 36.0, height_offset = 0.95` against the outdoor `14.0 / 27.0 /
1.15`, because a room reads better close. One run logs both — `Rig ready: fov 27.0, distance 14.0`
then `Rig ready: fov 36.0, distance 9.5` — which is the seam being two different things in one
session rather than a setting that parsed.

**Reporting a seam as missing when it exists is its own kind of stale**, and it is why the
five-mentions problem was worth a package: the claim was copied between documents four times
without anyone opening the file.

### 4. The texture import defaults — BUILT, and gotcha 30 is now WRONG.

T2.1 stopped here on a sound rule: `[importer_defaults]` is undocumented, absent from `--doctool`,
and this project checks every name against the API dump before typing it. **The rule was right and
the conclusion was not**, because there is a stronger form of evidence available and it is
non-negotiable #1: *run the engine.*

The measurement, in four steps. A throwaway texture was copied into a scratch folder under `res://`
and imported with stock defaults (`detect_3d/compress_to=1`, `mipmaps/generate=false`); the section was
written into `project.godot`; the generated `.import` was DELETED; and `--headless --import`
regenerated it. It came back carrying `detect_3d/compress_to=0` and `mipmaps/generate=true`. A
second probe confirmed `ProjectSettings.get_setting("importer_defaults/texture")` returns it as a
Dictionary at runtime — `type=27 value={ "detect_3d/compress_to": 0, "mipmaps/generate": true }` —
which is what makes it assertable. Both are quoted in `DEVLOG.md`, and the probe directory is gone.

**Exactly one value is set in the end**, `detect_3d/compress_to = 0`, because exactly one was
wrong: it is the editor's "this texture was used in 3D, switch it to VRAM compression" rewrite, and
every character sheet in an HD-2D game IS used in 3D through `Sprite3D`. `mipmaps/generate` was
only the control value — it moved `false → true` to prove the section applied, and was removed.
The three other values `ART_CONTRACT.md` recommended turn out to be Godot's own defaults already,
measured on the untouched probe, so setting them would have been ceremony. **A default nobody
needs is a default nobody maintains.**

All eight committed `.import` files moved `1 → 0` too, so the hazard is closed for what is here as
well as for what a game imports next — and the sheets were re-imported and photographed, because
a compression change is precisely the edit that looks applied and silently ruins pixel art.

### 5. Git LFS — REFUSED, in writing, with the reason and the turn-on steps.

Two of the three reasons were already recorded: pointers for a 2 KB procedural placeholder are
pure overhead, and enabling them puts the CI checkout on a dependency it does not declare
(`actions/checkout` needs `lfs: true`, and without it every PNG arrives as a text pointer and the
import fails). The third is the one that decides it and had not been said: **this template cannot
verify the change it would be making.** Proving LFS works needs an LFS-enabled remote and a CI run
against real binaries, and neither exists while art is deferred. A configuration nobody can test
is exactly the change that looks applied and does nothing.

So it is refused rather than omitted, and the difference is that `ART_CONTRACT.md` now names the
three steps to turn it on. `.gitattributes` keeps the commented line and **stops restating the
reason** — its comment is a pointer, because that file was the fifth mention this package existed
to remove.

### The assertions, and the one that found a defect in itself.

`tests/unit/area_look_test.gd`, **47 new assertions**, 1,468 → 1,515 — and then to **1,517**,
because `docs_test.gd` COMPUTES its plan from the documents and this package added two `res://`
paths to them. Said rather than absorbed: the gate proofs below were run at 1,515, before the
documentation was written. The shape is the one
`art_contract_test.gd` established: fail if a hard-coded value grows back.

- `_the_driver_assigns_no_number_to_the_environment` — zero code lines matching
  `^_environment\.[a-z_0-9]+ = -?[0-9]`. A CALL is not a literal, deliberately: `maxf(0.1, …)`
  clamps a computed value and is not a look decision, so only the first token after `=` is judged.
- `_the_rig_assigns_no_number_to_its_camera` — the same over `camera.` and `_attributes.`.
- Twenty plus thirteen assertions pairing each export's live value with `@export` appearing on its
  declaration line, so a rename, a deletion and a moved default all fail by name.
- `_no_two_areas_declare_the_same_material_inline` — sub-resource bodies compared with
  `ExtResource` ids resolved to paths, because the same material carries different ids in
  different scenes, which is why two copies of it were invisible in the first place.
- `_the_texture_import_defaults_close_the_3d_compression_hazard` — the project setting AND every
  committed `.import`, naming the offenders in the failure message.

**A gate that never fails has never been tested, and one of these was not a gate.**
`_an_area_really_uses_the_framing_seam` passed with the override deleted, because it scanned every
line of an area scene and `WeatherVisuals` also exports a **`height_offset`** — two classes, one
property name, gotcha 17's family. Found by planting the real violation, which is the entire
argument for planting it. It now walks `[node]` blocks and reads only those whose `script`
resolves to the rig, buffering each block and judging it at the end rather than from the moment
the `script` line goes by, since a property authored above `script` is legal `.tscn`.

### Six gates proved RED with the real violation, then green (gotcha 23).

| Planted | Output | Exit |
|---|---|---|
| both areas' `m_wood` re-inlined | `FAILED: no two areas declare the same material inline (1 duplicated) — expected 0, got 1`, plus the 2 skips a shared material with no users correctly produces | 1 |
| `_environment.glow_intensity = 0.9` | `FAILED: the driver writes down no environment number — expected 0, got 1` | 1 |
| `camera.fov = 27.0` | `FAILED: the rig writes down no camera or depth-of-field number — expected 0, got 1` | 1 |
| `"detect_3d/compress_to": 1` and one `.import` back to `=1` | `FAILED: the default disables the 3D re-import to VRAM compression` and `FAILED: every committed texture .import disables 3D detection: ["res://assets/placeholder/character_placeholder.png.import"]` | 1 |
| the hall's three framing lines deleted | first draft: **passed** — the defect above. After the fix: `FAILED: at least one camera rig in an area authors its own framing — expected true, got false` | 1 |
| the `glow_intensity` default moved to `0.8` | `FAILED: glow_intensity is an @export at the value T2.1 shipped — expected [0.9, true], got [0.8, true]` | 1 |

All reverted, all green again: `1515 passed, 0 failed, 0 skipped` — 1,517 once the documents were
written, for the reason above.

### Six windowed captures, LOOKED AT and READ. This package is entirely visual.

All at `--new-game … --time=12:00 --freeze-time`, midday rather than dusk (gotcha 31: a propless
area at 18:40 renders near-black and looks exactly like a lighting bug), and the interior needs
`--goto` with `--shot-frame=95 --quit-after 110` because no ordinary run enters an area at all.

Captures 1 and 2 are the baselines. **Seam 1:** one line added to `assets/materials/wood.tres` —
`albedo_color = Color(0.85, 0.15, 0.55, 1)` — and captures 3 and 4 show the courtyard's dais AND
the hall's plinth both magenta, from **one file neither area contains**. Reverted. **Seam 2:** one
line added to `courtyard.tscn`'s driver node, `volumetric_fog_density = 0.06`, and capture 5 is
the same frame hazed to the horizon with the sky wall gone milky — everything else identical.
Reverted. **Seam 3:** capture 6 against capture 2, the same interior at the same hour with the
player sprite drawn at roughly 130 px against 78 and the floor grid visibly larger. Kept, as the
one piece of placeholder content proving the seam.

**The `.import` change was photographed rather than assumed.** All six captures were taken AFTER
the eight `.import` files moved to `detect_3d/compress_to=0` and the project re-imported: the
character sprites are crisp, hard-edged and free of block artefacts, and `compress/mode=0` still
reads `0` in all eight files. This is the check the exit criteria singled out, because a
compression change is the one edit that passes every rung and ruins the picture.

### Files: 13, and the only new code is a test.

`assets/materials/wood.tres` (new), `courtyard.tscn`, `lantern_hall.tscn`,
`environment_driver.gd` (+22 code lines, 183 → 205 of 250), eight `.import` files, `project.godot`,
`.gitattributes`, `tests/unit/area_look_test.gd` (new, 227 of 250), `tests/test_runner.gd`, and the
documents. `hd2d_camera_rig.gd` was **not touched** — the seam was already there.

### Ladder, all green.

`--headless --import` with **zero** `SCRIPT ERROR` / `Parse Error` lines; boot
`0 warnings, 0 errors`; suite **1517 passed, 0 failed, 0 skipped**, exit 0; `check_budgets`
**128 files, 11,119 code lines, 0 warnings, 0 violations**; `check_content` PASS; `check_boundary`
PASS over 122 engine scripts, deriving 16 demo names and finding none of them.

**Stripped template, run locally** — `1445 passed, 0 failed, **23** skipped` (was `1400 / 19`),
both checkers exit 0, `demo names derived: 0`. **The skip count MOVED and the four new ones are
named**, because a skip nobody names is a stripped run pretending to be a full one. All four are
`area_look_test`'s three content-dependent blocks — a shared material with no areas to use it
(2 outcomes), the inline-duplicate gate with fewer than two areas to compare, and no area to author
framing — and every one is correctly a claim about CONTENT rather than about the engine. The
arithmetic closes exactly: of the case's 47 outcomes, 4 skip and 43 run, and the remaining +2 on
the passed count is `docs_test` picking up the two new `res://` paths the documents name, both
under `assets/`, which a stripped checkout keeps.

### Deferred, with reasons, not silently.

- **The day/night keyframe table** is still a `const`. It is a curve rather than a look setting,
  and no document has ever listed it as a seam. Say so before building it, not after.
- **The `Button` styleboxes** are left for the FOURTH time, and deliberately. A stylebox has to be
  *designed*, and the only palette to design against is the placeholder one, so populating them
  would ship a decision as a default — the reasoning T2.2 gave, unchanged. This package had the
  file open and still did not take it, which is the point at which "left again" should be read as
  settled rather than pending.
- **No shared material beyond one.** ONE piece of placeholder content per system; a palette of
  five would be content, and four of the five would be wrong (see seam 1).
- **No environment-look resource**, no sixth catalogue, no registry for materials.
- **Git LFS**, refused above.
- Art is still deferred, permanently. This package built the seams art drops into and no art.

**CI green, run 33535503432, job logs read rather than the tick** (gotcha 26). Full checkout
**1517 passed, 0 failed, 0 skipped** with `item definitions: 4` and `quests: 1`; stripped template
**1445 passed, 0 failed, 23 skipped** with `item definitions: 0` and `demo names derived: 0`. All
three checkers PASS in both jobs, both at `128 files, 11119 code lines, 0 warnings, 0 violations`.
The four new skips are the ones named above. The push run (33535489902) and the pull-request run
(33535564427) are green too.

**Commit:** `d20fbc1` on `claude/t3-2-art-seams`, PR #22 — stacked onto `claude/t3-3-item-count`
(#21) rather than `main`, matching the rest of the chain.

---

## T4.3 · `NEW_GAME.md` performed, and the release tag taken — **DONE**

**The last package of Phase T4, and the phase's third exit criterion.** Two jobs: land the stack
and take the tag the owner had deferred, then perform the one document a fork reads first.

**THE TAG WAS STILL BLOCKED FOR THE SAME REASON, AND THE FIX WAS ONE MERGE.** Phase T4's third
criterion had been refused on 2026-09-02 — *not yet, merge the stack first* — because
`origin/main` was at `d0bf153`. It still was: all 26 PRs open, zero merged, so the reason had not
expired. What made it tractable is that the stack was one LINEAR chain. `git merge-base
--is-ancestor` confirmed all 25 ancestor branches were contained in T4.2's tip, 71 commits ahead
of `main`, so retargeting PR #26 from `claude/wp-t4-version-upgrade` to `main` and merging it
landed the entire stack at once as `648bac1`. Only then did `v1.0.0` name a tree that actually
declares `base/version="1.0.0"`. Put back to the owner with that answer in hand, and authorised.

Six PRs (#1, #2, #3, #10, #12, #13) auto-closed as merged because they targeted `main`. The other
19 could not: GitHub refuses to retarget a PR whose base already contains its commits — *"There
are no new commits between base branch 'main' and head branch"* — so they were closed with a
comment pointing at #26. **They read Closed, not Merged.** Every commit is on `main` and reachable
from `v1.0.0`; this is a GitHub limitation, not a gap in the record, and it is written here
because the board would otherwise look like 19 abandoned packages.

**THEN THE FOURTH DOCUMENT WAS PERFORMED, AND IT FOUND A TEMPLATE DEFECT.** A fresh `git clone`
from GitHub into a short path, then sections 1 to 4 followed literally with `src/` never opened
while performing — the same discipline as T2.2, T4.1 and T4.2. Four for four now: every document
walked has found something reading did not.

**DEFECT 1 — `core_test.gd` failed a fork that had not authored its first area yet.** It asserted
`equal("a template with a game in it names one", configured != "", true)` — unconditionally,
though the name is conditional. Four things in the repository already said an empty
`[game] world/first_area` is legal: that case name, the comment eight lines below it in the same
function, `NEW_GAME.md` section 4, and the file's own header MUST NOT line, since whether a game
is configured is a claim about the PROJECT and not about `GameConfig`. Gotcha 46's shape, one
function further down.

It was green in the full template and green in the stripped one — neither ever empties that field
— and red only in a real fork: `1537 passed, 1 failed, 20 skipped`, exit 1. The control names what
it was really asserting: `first_area="tideglass_field"`, an area that does not exist, made it pass
`1538 passed, 0 failed`. It demanded a non-empty STRING. **Removed rather than made conditional**,
because `smoke_test.gd` already makes the claim properly — gated on `Fixtures.area_ids()` and
stronger, since it also requires the named area to resolve. `plan(50)` became `plan(49)`.

**DEFECT 2 — section 3's prune list never learned about quests.** Written at T1.2, before WP-08
existed, it listed `area. talk. action. object. item.` and was never extended. A fork that followed
the document kept five rows of demo content in its own `localization/strings.csv`:
`quest.keepers_errand.*`, *"The Keeper's Errand"*, *"three rose petals"*. All four checkers exited
0 and the whole suite was green, because **no gate reads `localization/` for demo content at all**
(gotcha 48). Verified that every `quest.*` key is demo and that the engine's quest strings live
under `notify.quest.*`, which the prune keeps. The prefix is now listed, and the section carries a
third trap saying no gate checks this file, with a grep to run afterwards.

**FOUR PROSE DEFECTS, RE-MEASURED RATHER THAN INHERITED.** The `awk` comment claimed "keeps 147 of
189 rows"; the file is 219 rows and the corrected `awk` keeps 168. Section 6's quoted checker
output was T1.2's and had drifted — no `quests: 0` line at all, and `src scripts scanned: 74` where
the tool now prints `engine scripts scanned: 129, over src/ and ["res://tests/framework",
"res://tests/unit"]`. The intro said "rename four fields" where section 4 lists five. And section 6
asserted the unset-first-area error **with no command to produce it**: `--headless --new-game`
prints nothing and ends `0 warnings, 0 errors`, because game flags need a `--` separator and
`--quit-after` counts FRAMES — two independent ways to get a green run that verified nothing
(gotcha 47).

**Ladder, all green.** Import exit 0 with **zero** `SCRIPT ERROR` / `Parse Error`; boot
`0 warnings, 0 errors`; suite **1608 passed, 0 failed, 0 skipped**, exit 0; `check_content`,
`check_boundary`, `check_budgets`, `check_strings` all exit 0. Stripped template **1534 passed, 0
failed, 25 skipped**, all four checkers exit 0 — **no new skip**.

**The total moved by +1 and it was predicted.** Minus the one assertion removed, plus two:
`docs_test` computes its plan from the docs, and section 6's corrected checker output names
`res://tests/framework` and `res://tests/unit` for the first time.

**Planted, and the fix that accepts MORE has a control (gotcha 23).** The defect was found in a
real fork rather than manufactured, so the control is the half that matters: copying an area back
into the fork with `first_area` still empty turned it red again — `FAILED: the configured first
area is set` and `FAILED: and its scene really exists`, exit 1, both from `smoke_test.gd`. A game
WITH areas and an unset first area is still caught. For the CSV, the old `awk` leaves 5 demo rows
and the corrected one leaves 0, with the new trap-3 grep returning nothing.

**Both numbers the document quotes were measured on the final tree**, not carried over: a fork
that followed sections 1 to 4 with `first_area` empty reports `1539 passed, 0 failed, 20 skipped`
across fifteen named cases, and the harsher stripped variant CI runs reports `1534 passed, 0
failed, 25 skipped`. The banner line quoted in section 6 was copied out of the fork's own run.

**Version bumped to 1.0.1, and the tag for it taken separately.** T4.1's precedent decides it — stating
a version is engineering and assertable, cutting a release is the owner's — so the bump landed with the package and the tag was asked for on its own, and authorised (`v1.0.1` on `a291691`). Leaving `main` saying
`1.0.0` after changing it would have made one version name two trees, which is the rot
`version_test.gd` exists to prevent. `docs/CHANGELOG.md` gains a `## 1.0.1` PATCH entry whose *a
consuming game does* line is actionable: a fork made at 1.0.0 that followed `NEW_GAME.md` should
grep its CSV for `quest.` and delete what it finds.

**What was deliberately NOT done.** No gate over `localization/`. It would need to know which key
prefixes are engine and which are content — the same list that just rotted, moved one directory
away and given the authority to fail a build. The document's own grep is the cheaper truth and is
aimed at the person actually holding the fork. This is the same objection that refused a
`check_content` rule for `obj/` flags at T4.2, and it is recorded for the same reason.

**CI green, run `33785871834`, job logs read rather than the tick (gotcha 26).** Full checkout
`=== 1608 passed, 0 failed, 0 skipped ===`; stripped template `=== 1534 passed, 0 failed, 25
skipped ===`, the 25 skips unchanged from T4.2. All four checkers PASS in both jobs.

**Commit:** `4ec29fb` on `claude/t4-3-new-game-perform`, PR #27, targeting `main` directly.


## T4.4 · `TESTING.md` performed, the last document never walked — **DONE**

**The fifth document performed, and the fifth to find a defect.** T2.2 walked the first half of
`AUTHORING.md`, T4.1 `UPGRADING.md`, T4.2 the rest of `AUTHORING.md`, T4.3 `NEW_GAME.md`. Five for
five, and **three of the five found a defect in the TEMPLATE rather than in the prose.** The
mechanism was the same one and it is not negotiable: do what the document says a consumer does,
from the document alone, and treat every wall as a finding rather than as a reason to go and read
the code. For `TESTING.md` the consumer is somebody adding assertions to a suite they did not
write, so the walk began by copying the document's own worked example verbatim into a new case
and registering it in `CASES`.

### The defect: a listed case that does not parse reported a clean pass, and exit 0

The very first run found it, and it found it by accident, which is the point. The copied example
did not compile — see below — and the suite's answer to a case that does not compile was:

```
SCRIPT ERROR: Parse Error: Identifier "inventory" not declared in the current scope.
   at: GDScript::reload (tests/unit/inventory_order_test.gd:14)
ERROR: Failed to load script "tests/unit/inventory_order_test.gd" with error "Parse error".
SCRIPT ERROR: Invalid call. Nonexistent function 'new' in base 'GDScript'.
=== 1608 passed, 0 failed, 0 skipped ===
```

*(The throwaway case's `res://` prefix is stripped in that quote on purpose. It was deleted at
the end of the package, and `docs_test.gd` asserts that every `res://` path named in `docs/`
resolves — so quoting the engine's own line verbatim fails rung 4. `DEVLOG.md` is exempt from
that scan for exactly this reason; the board is not. The gate caught it here, which is a fair
demonstration that it works.)*


**Exit 0.** `0 failed`, `0 skipped`, and a whole case never run — a last line byte-identical to
one from a checkout in which the file does not exist.

The chain is three facts this project already knew, meeting in a place nobody looked.
`load()` on a script with a parse error returns a `GDScript` that is **not `null`** and cannot be
instantiated; `_run_case` tested only for `null`, so it walked into `script.new()`; and the
failure of that call is a GDScript runtime error, which **gotcha 24 established aborts only the
innermost frame.** So `_run_case` itself aborted, the `does not extend TestCase` failure two lines
below was never reached, and the `for` loop in `_ready` carried on. The sharpest part is that
`tests/framework/error_watch.gd` — T1.3's second mechanism, built precisely because the plan was
measured and found insufficient — **had counted the error the whole time.** `_no_script_errors` is
read per case from *inside* `_run_case`, after `run()` returns, so an error raised on the way IN
is tallied by the watch and read by nobody. Three correct mechanisms, all silent: the plan never
ran, the manifest was satisfied because the file WAS listed, and the watch was never asked.

**Two guards, because the second is the general one.** `can_instantiate()` before instantiating,
which names the file; and a run-level check that any engine script error no named case accounted
for fails the run, because the next hole in that wall will not be a parse error.

**Proved by planting, and the plant was caught twice — once deliberately and once by accident.**
Deliberately: a parse error appended to `version_test.gd`, a case with nothing else wrong with it.

```
res://tests/unit/version_test.gd is listed but does not parse, so it never ran
FAILED: 2 engine script error(s) were raised outside any case: ["Parse Error: Identifier
  nothing_declared_anywhere not declared in the current scope. at
  res://tests/unit/version_test.gd:123 in GDScript::reload()", ...]
=== 1591 passed, 2 failed, 0 skipped ===
```

Exit 1, both guards firing independently, the file and the line named, and the parse errors
quoted. Removed, and the control is exit 0 at `=== 1624 passed, 0 failed, 0 skipped ===`. By
accident, and it is better evidence than the plant: while this package was writing
`doc_counts_test.gd`, a stray escape produced `Invalid escape in string` at line 29 — and the new
guard reported the file and line unprompted, on a real mistake, where the old runner would have
carried on green.

### The document's one worked example did not compile, and it was wrong twice over

`equal("an empty inventory holds nothing", inventory.count(), 0)` — the only assertion example in
the document. Copied verbatim it produces two parse errors. **Nothing declares `inventory`**:
`TestCase` provides `plan`, `equal`, `skip`, `build` and `attach` and no content whatsoever, which
the document nowhere states. And **`Inventory` has no `count()`** — it has `distinct_count()`,
`total_count()` and `count_of(id)`. So a consumer's first act on this document is a compile
failure, followed, until this package, by a *green suite* that hid it. The replacement was written
and then RUN as a real case before being put in the document, which is non-negotiable #1 aimed at
prose.

### Three documents, three different answers to a countable question

`CLAUDE.md` said 44 in two places, `CONTEXT.md` said 48 and `TESTING.md` said
43, over a list of 48 entries. Each was true when written; none was updated.
This is gotcha 48's shape — a number in prose with no gate — but **without gotcha 48's excuse**:
the localization gate was refused in writing because it would need a list of which key prefixes
are engine, which is the same rot moved sideways. A count needs no list. `doc_counts_test.gd`
counts the entries, checks they run 1..N without a gap or a repeat, spells the number, and
requires every document that states it to state that one.

It is **its own case file rather than three more checks inside `docs_test.gd`**, because that
file's MUST NOT line forbids asserting anything about what the documents SAY, and non-negotiable
#4 says a change that needs a MUST NOT broken adds a system instead of widening the boundary.

**Planted twice.** A fiftieth gotcha added with no count updated fails all four claim sites at
once — `expected fifty, got forty-nine` — which is the rot that actually happened. `CLAUDE.md`
alone drifted back to 44 fails exactly one, naming the file. Both exit 1; both restored.
The gate also had a hole of its own on the first pass, and it was gotcha 43's shape: the section
heading is the PRIMARY statement of the count and was being swallowed by the section it opens, so
the gate would have passed while the list's own title was wrong. It is kept as a claim now.

### The assertion that was kept, and why

The throwaway case was deleted; **`bag_mirror_test.gd` was kept**, because it covers something
genuinely missing. `Inventory.add` carries a comment saying `_publish()` runs *before* either
signal, "so nothing woken by one reads a flag that still says the old number". `remove` has the
identical ordering and no comment, and **nothing asserted it on either path** — so a listener that
reacted to `item_gained` by reading `bag/<carrier>/<item>` would have read the previous count, with
an off-by-one in whatever it drew as the only trace. Ten assertions, and the last is the
interesting one: spending the LAST of a stack ERASES the row rather than zeroing it, so "current"
there means absent, and an emission tally is what makes a missing row distinguishable from a
handler that never ran.

Planted on both sides. `_publish()` moved after `Events.item_lost.emit` gives
`FAIL the flag already read the REMAINDER inside item_lost — expected 3, got 5` — the listener
reading the old number, exactly the defect the comment warns about. After
`Events.item_gained.emit` gives `expected 5, got -1`. **Nothing else in the suite failed on either
plant**, which is the proof the invariant was uncovered rather than covered twice.

One assertion of the ten caught the author rather than the code, and it is worth recording: the
first version expected `0` from the erased row and got `-1`, because `_publish` erases rather than
zeroes. The code was right and the assertion was wrong — which is what the second and third
outcomes of `plan()` are for, and the plan itself caught a miscount in the same file
(`planned 9 outcomes and produced 10`).

### What was deliberately NOT done

No windowed capture, and no temporary probe under `src/systems/debug/`. This package changes no
rendering, no input path and no engine file at all — `git diff src/` is empty, the inventory
plants having been fully restored — so a capture would be a screenshot of something it did not
touch, which is ceremony that later reads as evidence. `git diff src/systems/debug/` is clean.

No third mechanism in the runner. The plan, the watch and the manifest are enough once the watch
is actually asked, and the run-level backstop is that asking. Adding a fourth would be a second
thing to get wrong in the file whose job is judging whether things went wrong.

### Verification

Full ladder green, run locally. Rung 2 greps to zero `SCRIPT ERROR` / `Parse Error`; rung 3 ends
`0 warnings, 0 errors`; rung 4 is `=== 1625 passed, 0 failed, 0 skipped ===`, up 17 from 1,608 —
ten from `bag_mirror_test.gd`, six from `doc_counts_test.gd`, and one more because `docs_test.gd`
COMPUTES its plan from the documents and this section names an additional `res://` path. All
four checkers exit 0.

**Stripped template, measured rather than inherited:** `=== 1551 passed, 0 failed, 25 skipped ===`,
up 17 by the same arithmetic, and **the 25 skips are unchanged** — neither new case adds one,
since fixtures work in a stripped checkout and the documents are still there. All four checkers
exit 0 against `--path` as well.

**Version bumped to 1.0.2; the tag for it was ASKED FOR AND DECLINED, 2026-09-04.** That is
T4.1's precedent working rather than being suspended: the bump ships with the package, the tag
is a separate request, and the owner answers it. `v1.0.0` and `v1.0.1` were both asked for the
same way and both granted; this one was not, so `main` declares `1.0.2` with no tag naming it.
The `## 1.0.2` CHANGELOG entry's *a consuming game does* line is honest about the one visible
consequence: a game whose suite contains a case that does not compile will see rung 4 fail where
it previously passed, and that is the bug being fixed rather than a new restriction — the case was
never running.

**CI green, runs `33840155182` and `33840636717` — the second on the final commit `91e2054`, because the closing doc commits change the suite total by changing what `docs_test.gd` computes its plan from. Job logs read rather than the tick (gotcha 26).** Both jobs report
`success`. Full checkout `=== 1625 passed, 0 failed, 0 skipped ===`; stripped template
`=== 1551 passed, 0 failed, 25 skipped ===` — byte-identical to the local measurements, and the
25 skips unchanged from T4.3. All four checkers pass in both jobs. The only `error:` strings
anywhere in the log are the workflow's own `::error::` echo lines for the failure path it did not
take, plus the expected "couldn't open directory" notices for the content roots in the tree
where that content is deliberately deleted.

**Commit:** `29ba248` on `claude/t4-4-testing-perform`, PR #29, targeting `main`.

## The board was closed, then reopened the same day — 2026-09-04

**Closed by T4.4, on the owner's instruction:** the last consumer document had been performed,
every phase was complete, and the two remaining candidates — WP-10 crafting, and nothing — were
put to the owner, who chose nothing.

**Reopened within the hour, and for a good reason.** Asked whether the SKELETON was actually
finished, `ROADMAP.md` disagreed with the closing summary: **Phase 1 read COMPLETE while carrying
three unticked exit criteria, and Phase 2 read IN PROGRESS with one.** T5.1 closed all four by
proving them, and one was a missing FEATURE rather than a missing proof — the locale setting was
wired to nothing at all. **When a summary and a state file disagree, the file with the checkboxes
wins.** That is now a settled decision in `CONTEXT.md` rather than a lesson to relearn.

**The board is a queue of criteria, not of ideas.** WP-10 remains OPTIONAL and unbuilt, kept as a
record the way WP-15's remnant is. An unticked criterion is a row. A real defect is a row. A seam
the owner's intent for the base actually needs is a row — which is what the next one is. A package
invented so that there is one is how the previous project got a 3,983-line file, twenty reasonable
lines at a time.

## T5.1 · The skeleton's four open exit criteria, closed by proving them — **DONE**

**The board had just been closed, and the base was not finished.** T4.4 put the choice to the
owner and recorded the closure. The next question was whether the SKELETON was actually done, and
the answer came from `ROADMAP.md` rather than from the closing summary: **Phase 1 read COMPLETE
while carrying three unticked exit criteria, and Phase 2 read IN PROGRESS with one.** Nobody had
lied — each criterion was ticked as it was proved, and the three awkward ones were left, then the
phase was called done on the strength of everything else. **Every criterion in every phase is now
ticked, and each of these four was proved rather than ticked.**

### The one that was a missing FEATURE, not a missing proof

Phase 2's *"switch language at runtime and see every visible string change"* could not pass, and
reading the code would not have shown why, because `settings_screen.gd` does exactly the right
thing: it offers `TranslationServer.get_loaded_locales()` and stores the choice through
`Settings.set_value`. `Settings` then announces `setting_changed` — and **nothing anywhere calls
`TranslationServer.set_locale`.** Grepped to be certain; the only hits were the settings screen
reading the loaded list. So the language could be chosen, was validated, was persisted, survived a
relaunch, and changed nothing at all. **Fifth instance of this project's most expensive shape** —
declared, validated and read by nothing — after `Gate.locked_key`, `PathAction.refusal_key`,
`ItemDb.reload` and `HD2DCameraRig`'s framing exports.

**And there was nothing to switch to, which is why fixing the wiring alone would not have closed
it.** The CSV had ONE locale column; `get_loaded_locales()` returned `["en"]`, measured. So the
options screen's locale stepper had been cycling a list of one for as long as it had existed.

Three changes, and the second is the one with teeth:

- **`Settings._apply_locale`**, on `_apply_display`'s stated reasoning rather than by analogy with
  it. That function's own comment says why it exists — *"nothing else owns the window"* — and the
  identical sentence is true of `TranslationServer`. A consumer would have to be a system, and
  "the language" is not one: every screen reads it, none owns it. **Not** skipped under headless,
  which is the one way it differs from the display: a translation has no window in it, so the suite
  asserts `tr()` instead of trusting a screenshot.
- **`check_content.gd`'s CSV rule is now the header width.** It failed any row parsing to more than
  TWO columns — the rule that catches WP-01's unquoted comma, which shipped a lever toast reading
  *"Somewhere north"* for three packages — so **the second language would have failed the gate that
  exists to protect the first.** It compares against the header now, and demands equality rather
  than a maximum so a half-added locale filling only some rows is caught too. Planted with the
  original bug: unquoting WP-01's own row gives `object.lever.gate.on has 4 column(s) where the
  header has 3, so an unquoted comma has cut its text off at "The lever gives with a heavy clack.
  Somewhere north"`, exit 1; restored, exit 0. The same defect, still caught, one column wider.
- **`tools/gen_pseudolocale.gd`** generates an `en_XA` column, wrapping each English value as
  `[~~English~~]`. A real second language is 218 rows the template has no business inventing and a
  consuming game replaces anyway; a generated one proves the mechanism. **Same argument that
  generates placeholder ART** rather than shipping art. It earns its keep afterwards: an
  unbracketed string on screen never went through the CSV — `check_strings.gd`'s static rule made
  visible, and covering anything computed — and the padding makes every label longer than its
  English, so a layout that only just fits fails here rather than in a translated build. It writes
  through `store_csv_line`, because that is what knows how to quote a comma and hand-writing the
  file is how the WP-01 bug comes back.

**Proved by two captures of the satchel at 12:00, differing only in that setting, and READ:**
`Satchel / Key Items / Rose Key x1 / Enter to hold or stow · Escape to close` against
`[~~Satchel~~] / [~~Key Items~~] / [~~[~~Rose Key~~] x1~~] / [~~Enter to hold or stow · Escape to
close~~]`. The item row is **double-wrapped**, which is the interesting part: the row format and
the item name are two separate table lookups, so both wrap. The HUD reads
`[~~Day 1  |  12:00  |  [~~Midday~~]~~]` — one outer wrap with the phase wrapped inside and the
numerals bare, which is correct: the CSV key is `Day {day}  |  {time}  |  {phase}`, a single format
string with named placeholders, so the translator owns the separators and the order.

### A capture flag that persists broke the suite in four unrelated files

`--locale=` is routed through `Settings.set_value` deliberately, because a flag that set
`TranslationServer` directly would photograph a path no player can take. `set_value` calls
`save()`. So the `en_XA` capture left the setting on disk and the **next** suite run failed in
`items_test` and `screens_test` — `expected fixture.fixture_stack.name x3, got
[~~fixture.fixture_stack.name x3~~]` — four failures, in two files this package never touched,
caused by a screenshot taken ten minutes earlier. `test_runner.gd` now pins the language for the
same reason it already pins `Clock.paused`, reading
`internationalization/locale/fallback` from `ProjectSettings` rather than hard-coding English so a
consuming game whose default is another language gets a deterministic suite too. **Gotcha 50.**

### Eight-direction facing: assertions, because a screenshot cannot judge it

`art_contract_test.gd` proves the LAYOUT's quantisation for all eight sectors, but its MUST NOT
line forbids asserting what a character looks like, and `character_depth_test.gd` owns attributes
and surfaces — so nothing connected a direction of TRAVEL to a column, which is where an axis swap
or a sign error lives. `tests/unit/facing_test.gd`, 21 assertions.

**Every one is camera-yaw independent, on purpose.** `_screen_angle` subtracts the active camera's
yaw so "towards the camera" is the front pose whatever angle an area frames from — a feature, and
it makes "north-east is column 3" true for one camera only. So what is asserted is what holds for
every camera: the eight directions stay DISTINCT, and one sector of turn advances the facing by
exactly one.

**Planted twice, and the second plant justifies the design.** Swapping the axes in `_screen_angle`
(`atan2(y, x)` for `atan2(x, y)` — the actual slip) fails all eight with `expected 1, got 7`, the
mirror — **and the distinctness and column-agreement assertions still PASS under it**, because a
mirrored character is still eight distinct poses consistently drawn. Only the turn-direction
assertion sees it, which is gotcha 28 in assertion form. Deleting the standing-still guard gives
`expected 0, got 2`. Both exit 1; control `facing_test: 21/21`, exit 0.

Then the walk-through, because the criterion says *walk*: a temporary `--face-all` probe drove the
LIVE player through all eight directions in the courtyard against the real camera rig, reporting
`facing=N column=N` for N in 0..7, with frame numbers logged so the shutter could be aimed —
sector 3 spans frames 123-162, making a capture at 140 a checkable prediction. Read at 1920x1080:
courtyard at midday, HUD `Day 1 | 12:00 | Midday`, prompt drawn, player drawn from BEHIND, which
is what north-east should look like. Probe removed; `git diff src/systems/debug/` clean.

**One thing the assertions deliberately do not claim.** The shipped placeholder sheet is the plain
figure, not T2.1's pip-labelled one, so a column number cannot be read off this capture — that is
what the labelled alt sheet and `frame_index()`'s own assertions are for. The capture shows the
character rendering correctly in-area and facing away; the mapping is proved by the 21 assertions
and the live probe, not by the screenshot.

### The save criterion needed two processes

`--cross-area-save` already saves and reloads IN PROCESS, and that cannot tell a value read back
from disk from one that was never cleared — *quit and relaunch* is exactly the case where nothing
is left in memory to be right by accident. `--save-state=<slot>` and `--load-state=<slot>` are
that pair:

```
run 1  --save-state before: area='lantern_hall' at=0.00,-4.20 day=3 time=21:45 weather=4 carrying=1
run 2  --load-state at boot: area=''            at=0.00,0.00  day=1 time=06:00 weather=0 carrying=0
run 2  --load-state after:   area='lantern_hall' at=0.00,-4.20 day=3 time=21:45 weather=4 carrying=1
```

The middle line is the CONTROL and it is the whole point. **The weather is deliberately STORM (4)
rather than CLEAR**, because CLEAR is the boot default: the first version of this probe reported
`weather=0` on both sides and looked like a pass while proving nothing about weather at all.

`save` and `load` joined `DevCommands` for this, since the settled decision is that the console and
the command line are one implementation — six verbs now, zero-based slots matching `SaveSystem` and
the save screen. **`dev_stage.gd` could not host the flag: it is at 248 of its 250 code lines**, so
the pair went to `dev_probes.gd`, which owns scripted scenarios and already had `--cross-area-save`.

The existing verb-count assertion caught the additions — `there are four verbs — expected 4, got 6`
— which is it working rather than being in the way. It gained a companion that **cannot rot**: every
verb in `VERBS` must dispatch. Planted with a seventh verb declared and unwired, and the dispatch
assertion fails independently of the count, which is the case a dutifully bumped number hides.

### The 30-second session had simply never been run

The boot rung is 30 **frames** at the main menu (gotcha 31), so the criterion had been measuring
nothing for the life of the project. A windowed **33.6-second** session that entered the courtyard,
baked its navmesh (92 polygons), opened the satchel, cycled the sensor and interacted twice ended
`0 warnings, 0 errors` with **zero** `SCRIPT ERROR`, `Parse Error` or leaked-RID lines across 53 log
lines. An idle 30 seconds passed too, but a session in which nothing happens is not a play session
and was not accepted as one.

### Measured in passing, because the owner asked whether characters animate

They do, and the numbers match the formula. Pressing the real movement action and reading the
**Sprite3D cell being drawn** — not a private counter — gives `6 -> 14 -> 22 -> 30` for column 6
(west), which is frames 0 to 3: `4.04m over 60 frames, 8 cell changes` walking against
`1.50m, 4 changes` sneaking, and `standing still: drawn cell 6`, frame 0, the neutral pose. Two
cycles per second walking, one sneaking, against
`walk_fps 8.0 * clampf(speed / 3.2, 0.35, 2.0)`. **Two false starts are gotcha 51:** driving
`update_from_velocity` from a probe measures nothing, because the controller overwrites the visual
from its own velocity every physics frame; and `run` is a TOGGLE, so `action_press(RUN)` toggles it
— the first "running" trial covered 0.75m against walking's 2.30m, having toggled off and walked
into the dais.

### What was deliberately NOT done

No new autoload for the locale — that needs an ADR, and `Settings` already owned the value and had
the precedent for applying one. No real second language: the template does not choose a game's
languages, and 218 invented rows would be content masquerading as infrastructure. No pip-labelled
sheet swapped onto the player to read a column off a capture; the assertions and the live probe
answer that, and swapping the demo's art to test the engine would be the demo growing back.

### Verification

Rung 2 greps to zero `SCRIPT ERROR` / `Parse Error`. Rung 3 ends `0 warnings, 0 errors`. Rung 4 is
`=== 1653 passed, 0 failed, 0 skipped ===`, exit 0 — up 28 from 1,625: 21 from `facing_test.gd`,
6 from `core_test.gd`'s locale block, 1 from the new dispatch assertion. All four checkers exit 0.

**Stripped template:** `=== 1579 passed, 0 failed, 25 skipped ===`, exit 0, up 28 by the same
arithmetic, **the 25 skips unchanged** — no new skip to name, since `localization/` survives a strip
and the locale block needs no demo content. All four checkers exit 0 with `--path`.

**Version bumped to 1.1.0 — MINOR, and the tag not taken.** The base gained something a game may
ignore, which is the CHANGELOG's own definition. Its *a consuming game does* line is actionable:
`strings.csv` will conflict, as it always does, and after resolving it a game either reruns
`gen_pseudolocale.gd` or deletes the `en_XA` entry from `project.godot` and drops the column —
nothing under `src/` names it.

### What this unblocks, and the next package

The skeleton is complete in the sense the roadmap uses. The owner has since sharpened what the base
is FOR: **reusable character infrastructure that future games inherit by swapping assets** — several
idle formats, several movement styles — so a new game starts from something working rather than
going in blind. That names the next package, and the seam is already half-built:
**`SpriteSheetLayout.animation_for(moving: bool)` takes a BOOLEAN**, so a sheet can carry only idle
and walk blocks and run/sneak just replay the walk row faster. Meanwhile `GameEnums.MoveState` has
ten values and `Events.player_state_changed(state)` is declared **and emitted** and **listened to
by nothing**. Choose the animation block by `MoveState` instead, and one sheet carries separate
idle / walk / run / sneak / climb blocks that every future character — player or NPC, both use
`CharacterVisual` unchanged — gets by asset swap with no code. Sixth instance of
declared-validated-and-read-by-nothing.

**CI green, run `33847717732`, job logs read rather than the tick (gotcha 26).** Both jobs report
`success`. Full checkout `=== 1653 passed, 0 failed, 0 skipped ===`; stripped template
`=== 1579 passed, 0 failed, 25 skipped ===` — byte-identical to the local measurements, and the 25
skips unchanged from T4.4.

**Commit:** `a1e1da6` on `claude/t5-1-close-the-skeleton`, PR #30, targeting `main`.

## T5.2 · An animation block per GAIT — **DONE**

**The owner's reframing, made concrete.** After T5.1 closed the last roadmap criteria, the owner
said what the base is actually FOR: reusable character infrastructure that future games inherit by
swapping assets — several idle formats, several movement styles — so that a new game starts from
something working rather than going in blind. That named this row, and the seam turned out to be
half-built already.

### `animation_for` took a BOOLEAN

So a sheet could hold an idle cycle and a walk cycle, and that was the ceiling. Run and sneak
replayed the walk block at a different rate; there was nowhere to name a third. Meanwhile:

- `GameEnums.MoveState` has **ten** values — `IDLE, WALK, RUN, SNEAK, JUMP, FALL, CLIMB, SWIM,
  BUSY, LOCKED` — and has since WP-01.
- `Events.player_state_changed(state)` is declared **and emitted** by `PlayerController`.
- **Nothing listened to it.** Grep found the declaration and the emit and no subscriber.

So the information the sprite needed existed, was announced every time it changed, and had no
route to the thing that would have drawn it. **Sixth instance of this project's most expensive
shape** — declared, validated, read by nothing — after `Gate.locked_key`, `PathAction.refusal_key`,
`ItemDb.reload`, `HD2DCameraRig`'s framing exports and T5.1's locale setting. The pattern is worth
naming plainly: *this project's characteristic defect is not broken code, it is correct code with
no consumer.*

### What changed, and the fallback is the load-bearing part

`animation_for(state: GameEnums.MoveState)`, with `run_row`, `sneak_row` and `climb_row` added as
`@export`s defaulting to **-1**, meaning "replay the walk block".

**`-1` rather than `0`, and this is the whole compatibility story.** Row 0 is a real row — normally
the idle block — so a default of `0` would have drawn a *standing* character for anything running,
on every sheet not yet updated. `-1` is the only value that can mean "I have not drawn this". The
assertions are ordered to match: the fallback is asserted **before** the feature, because what must
not break is that a two-block sheet keeps drawing exactly what it drew.

States with no gait of their own fall to **idle**, not walk: there is no jumping and no swimming
in this template, and `BUSY` / `LOCKED` mean something else is driving the character, which looks
like standing there rather than walking on the spot.

`problems()` now validates **every** named row by field name — `names run_row row 9, past its 3
animation(s)` — because the draw call clamps to the last block, so an unreported typo animates
plausibly and wrongly. That is gotcha 38's shape: a number the loader kept and nobody checked.

### Who tells the visual what it is doing

`CharacterVisual` is **told** its state and never reads `Events.player_state_changed` — every NPC
uses the same class and none of them is the player, so a subscription would make every NPC in the
world animate to the player's gait. The parameter defaults to `WALK`, so an un-updated caller
behaves exactly as before: moving draws the walk block, standing draws the idle one.

`NpcBrain` passes `WALK` or `IDLE` from whether it is stepping. It gets no `MoveState` field of its
own — that would be a second state machine to keep in step with the brain — and it picks up a
game's walk block for free without knowing that animation blocks exist.

**And `PlayerController` now computes its state BEFORE drawing.** `_update_state(wish)` ran *after*
`visual.update_from_velocity`, which was invisible for the life of the project because nothing read
the state, and became a one-frame lag on every gait change the moment something did.

### Proved three ways, because the claim is visual and the failure mode is plausible

**Assertions (19).** The mapping, the fallback for all three unnamed gaits, the five states with no
gait, the override when a row is named, the clamp, and that `-1` is not a reported problem while a
row past the end is. Planted twice: removing the `>= 0` check gives
`gait 2 with no row of its own inherits the walk block — expected 1, got 0`, which is the
compatibility regression a consuming game would hit; dropping `run_row` from `problems()` gives
`and it is a reported problem, not a silent clamp — expected true, got false`. Both exit 1, control
`1676 passed, 0 failed`.

**The asset, measured.** Sampling the generated sheet's own pixels: 256×576, and the torso of
block 0/1/2 reads `(0.298, 0.447, 0.620)` blue, `(0.239, 0.518, 0.439)` green,
`(0.620, 0.337, 0.298)` rust. This settled in one command what four captures had left ambiguous,
and it is the lesson in gotcha 52: **a PNG on disk has no timing in it.**

**The runtime, read off the real sprite.** A temporary probe reported `body.visual.sprite.frame` —
what is actually being drawn, not a private counter — in the live courtyard:
`idle: state=0 cell=0 block=0`, `walk: state=1 cell=38 block=1`, `run: state=2 cell=78 block=2`,
each cycling within its own block. Probe removed; `git diff src/systems/debug/` clean.

**Three captures, READ.** The placeholder sheet gained a cloth tint per block and a forward lean on
the run, on the alt sheet's reasoning (gotcha 28): a running figure drawn from the walk block is
still a person mid-stride, so the BLOCK has to be readable rather than judged. The walk capture is
the decisive one — **the player is in green and the keeper NPC standing beside them is in blue, in
the same frame, from the same sheet.** Two characters, two blocks. The run capture shows the player
in rust with the NPC still blue.

### What was deliberately NOT done

No second idle, no turn-in-place, and no wholesale character swap — all three are now roadmap
criteria under Phase T5 rather than notes, because the block seam is what they were waiting on and
each is its own package. No `MoveState` field on `NpcBrain`. No subscription to
`player_state_changed` from the visual, for the reason above — and it is worth recording that the
signal STILL has no listener, which is correct: the visual is pushed to, and a listener would be a
second path to the same fact.

### Verification

Rung 2 greps to zero `SCRIPT ERROR` / `Parse Error`; rung 3 ends `0 warnings, 0 errors`; rung 4 is
`=== 1676 passed, 0 failed, 0 skipped ===`, exit 0 — up 23 from 1,653: 19 from the gait block in
`art_contract_test.gd` and 4 more because `docs_test.gd` and `doc_counts_test.gd` compute their
plans from the documents, and this package adds gait fields to `ART_CONTRACT.md` and a gotcha.
All four checkers exit 0.

**Stripped template:** `=== 1602 passed, 0 failed, 25 skipped ===`, exit 0, up 23 by the same
arithmetic, **the 25 skips unchanged** — no new skip to name. All four checkers exit 0 with
`--path`. Budgets: the layout went 34 → 62 of 250, `character_visual` 107 → 110,
`gen_placeholders` 129 → 143, `npc_brain` 171 → 172.

**One thing the suite caught that is worth quoting**, because it is the T4.4 guard earning its keep
two packages later: changing the signature broke `art_contract_test.gd`, and the runner said
`res://tests/unit/art_contract_test.gd is listed but does not parse, so it never ran` with the six
parse errors quoted by file and line. Before T4.4 that would have been a green run with one case
silently skipped.

**Version bumped to 1.2.0 — MINOR, and untagged.** The base gained something a game may ignore.
The *a consuming game does* line is honest about the one visible consequence: nothing changes unless
you want the gaits, but if you were using the shipped placeholder it is now 256×576 with three
blocks rather than 256×192 with one.

---

## T5.3 · Delivering the gaits that were already declared — **DONE**

**The row exists because an audit went looking for this project's characteristic defect across the
whole base and found the seventh instance in the package one row above.** T5.2 made
`SpriteSheetLayout.animation_for` take a `MoveState` and shipped `run_row`, `sneak_row` and
`climb_row` as authored data. Run and sneak work. **Climb never arrived.**

`PlayerController._physics_process` opens with `if _climbing: climb_step(delta); return`, so the
line that hands the state to the visual is unreachable for the duration of a climb, and
`climb_step` touched the visual only after `_enter_state(IDLE)`. All three callers of
`update_from_velocity` were checked: those two, plus `npc_brain.gd:108`, which passes `WALK` or
`IDLE`. **No call site in the project could pass `CLIMB`**, so `climb_row` — exported, defaulted
to -1, range-limited, matched in `animation_for`, counted by `distinct_gaits()`, validated by
`problems()`, asserted by `art_contract_test.gd`, documented in `ART_CONTRACT.md` — could not be
drawn by anything.

**Why every gate stayed green, which is the transferable part and is now gotcha 54.** Both ends of
the seam were asserted and the wire was not: `traversal_test.gd` asserted the body reports
`state == CLIMB`, `art_contract_test.gd` asserted `animation_for(CLIMB)` returns the right row.
Two green assertions that together read as coverage of a path that did not exist. And it was
invisible in the demo, because the shipped sheet leaves `climb_row` at -1 and the fallback draws
the walk block, which looks correct. The first observer would have been the first consuming game
to draw a climb cycle — the exact audience Phase T5 exists for.

**The second defect, same function.** The `else` branch pinned `_frame = 0` whenever horizontal
speed was zero, so **no idle block had ever advanced a single cell**: three of the shipped sheet's
four idle cells were undrawable, while *"more than one idle"* sat on the phase's exit criteria. The
criterion as written would have added a second static pose and left a held pose. It has been
reworded rather than closed.

**What changed.** `climb_step` derives a velocity from the move it just applied and drives the
visual on both legs (`_drive_visual`); `update_from_velocity` treats a climb as moving even with
zero horizontal component, and does not re-aim on a vertical move so facing survives a ladder. An
idle block that DIFFERS from the walk block advances at a new `idle_fps` export; a sheet whose idle
*is* its walk block still holds cell 0, which is every sheet authored before T2.1 and is the same
fallback reasoning as `run_row = -1` — the data answers and no flag is added. `_rate_for`,
`_advance` and `_idle_animates` split out to stay inside the 40-line function budget.

**Files:** `src/gameplay/character/character_visual.gd`,
`src/gameplay/character/player_controller.gd`, `src/core/events/events.gd` (four false docstrings),
`tests/unit/gaits_test.gd` (new, 12 assertions), `tests/unit/traversal_test.gd` (+6),
`tests/test_runner.gd` (the CASES row), and the documents. No version bump: no game's files change,
and a game that authored a climb cycle was already getting nothing.

**Proved by planting the defect.** Fix reverted, tests kept: `=== 1688 passed, 6 failed ===`,
exit 1, naming `a climb draws the climb block — expected 1, got 0`. Restored:
`=== 1694 passed, 0 failed, 0 skipped ===`, exit 0. All four checkers exit 0.

---


---

## T5.4 · The three missing enforcement gates — **DONE**

**The row exists because the T5.3 audit found the structural cause rather than another instance.**
Seven times this project has shipped correct code with no consumer through a fully green ladder.
That is not seven mistakes. It is one missing question: **no gate anywhere asked whether a
declared thing has a consumer.** Four gates stood — content, budgets, strings, the demo boundary —
and every one of them validates a thing that EXISTS.

Three gates close it, in three different places. Each was proved red by planting a real violation
and green by removing it; the exit codes are in `DEVLOG.md` and are not repeated here.

### 1. `tools/check_signals.gd` — every declared signal has an emitter

Named `debug_command` on its first run: declared, typed, documented, never emitted. `item_used`
passed because its doc block already said so. The exemption is the phrase `NO EMITTER` in the
signal's own `##` block, not a list in the tool — the next reader of the declaration sees the
decision without opening anything — and a signal carrying the phrase that DOES have an emitter
fails too, because a stale exemption is how a gate rots into decoration.

**The method trap is why this is not a grep.** `quest_started`, `quest_advanced` and
`quest_completed` have **zero** direct `.emit` sites: they are handed as first-class `Signal`
values to a helper that calls `fact.emit.callv(args)`. A naive scan reports three false positives
on a correct registry. The gate reads a bare `Events.<name>` by what its FILE does with a
`Signal`-typed identifier — `.emit` makes the file an emitter, `.connect` a listener, neither
makes the reference count as nothing, which is the direction that can only over-report.

It checks its own preconditions rather than assuming them: zero `[connection]` blocks in any
`.tscn`, zero `emit_signal(` string calls. Either would let a signal be wired without the text
this tool searches for, and a green run would then mean nothing.

### 2. `tools/check_layers.gd` — the invariant that had no gate

**The tree was not clean.** The brief for this package said it was; the first run said 55 upward
references, exit 1. `ARCHITECTURE.md` has stated `core -> content -> systems -> gameplay -> ui`
since Phase 0, gives the test in the next sentence — *could you delete the layer above and still
compile?* — and nothing had ever run it.

Forty-two were `src/systems/debug/`, the development harness, which `check_boundary.gd` already
exempts on the same precondition. **Thirteen were real:** `interaction_sensor.gd` sat in
`systems/` while typed on `Interactable`, which is `gameplay`. It was in the wrong layer — its
own second line says it *"lives as a child of the player"*, and a player component is not a
game-agnostic service — so the fix was to move it to `src/gameplay/interaction/`, not to grant an
exemption. **The same shape as `const FIRST_AREA := &"courtyard"` in `core` before T1.2, with the
roles reversed: there the gate existed and the rule did not; here the rule existed and the gate
did not.** Gotcha 55.

Nothing is listed that can be derived: layers from the path, `class_name` symbols from the files
declaring them, autoloads from `project.godot`. That is what makes "the five autoloads under
`src/systems/` are globals" automatic — they are layer 2, so `gameplay` and `ui` calling them is
already downward, and no carve-out is needed or written.

### 3. `localization/` demo content, in `check_boundary.gd` — gotcha 48 closed

`check_content` and `check_strings` both open the CSV and both ask only whether a key a script
names has a row. Neither asks whether a ROW names content that exists.

**The two halves are asymmetric on purpose.** Presence is REPORTED — 218 rows, 51 in a content
namespace (`object` 24, `talk` 10, `action` 6, `quest` 5, `item` 4, `area` 2; the audit's 59
included the eight engine `item.category.*` rows) — because the template legitimately ships its
own demo rows and a gate switched off where it lives is decoration. What FAILS is the ORPHAN: a
row naming content that is not there, which is the actual T4.3 defect and is wrong in the
template and in every game built on it.

**The stripped CI job now performs `NEW_GAME.md`'s prune and then runs this gate**, so the prune
list is itself checked by something derived from a different place. If a namespace goes missing
from it again, CI goes red — which is the expiry story gotcha 48 said a tool could not have. It
could not, as a list of engine prefixes; it can, by asking the opposite question.

### What this package deliberately did not do

- **It did not widen the consumer question past signals and CSV rows.** Settings, `@export`
  properties, enum values and public methods are all still declarable-and-dead, and candidate B
  is the largest of those by a distance.
- **It did not gate `object.` and `action.` rows.** Nothing derives their ids, and the header
  says so rather than letting a green run be read as more than it is.
- **It wrote no ADR.** Two tools and a file moved one directory is not an architecture decision;
  the layer rule was already decided in `ARCHITECTURE.md` and ADR-0001.

## T5.5 · The twelve settings with no consumer — **DONE**

**The row exists because twelve of twenty-three settings were declared, drawn to the player,
translated in both languages, and read by nothing** — and because five of those twelve were a
defect in the TEMPLATE rather than a missing feature of a game, which is a different and worse
thing than the six declared-and-dead instances before them.

### What made the `accessibility/*` five sharper than the rest

The thing a text-size preference has to change is the project theme — `assets/theme/ui_theme.tres`,
wired as `gui/theme/custom`, holding nine `font_sizes` — and every screen that draws from it lives
under `src/ui/`. So a game forked from this base **could not** honour that setting without editing
`src/`, which is the exact failure this template exists to prevent. The other seven were merely
unfinished; these five were unfinishable from outside.

### Nine wired, and the placement was decided by ownership rather than by tidiness

| Setting | Consumer |
|---|---|
| `video/resolution_scale` | `Settings._apply_render_scale` — `scaling_3d_scale` is the viewport's, and no system owns the viewport |
| `video/shadows` | `Settings._apply_shadows` — the shadow ATLAS; see below |
| `video/bloom` | `EnvironmentDriver` — the `Environment` is that node's and nothing else may touch it |
| `video/depth_of_field` | `HD2DCameraRig._on_setting_changed` — **`set_dof_enabled()`'s first ever caller** |
| `gameplay/show_interact_hints` | `InteractPrompt._redraw` |
| `accessibility/text_scale` | new `UiAccessibility` under `UILayer` |
| `accessibility/high_contrast_prompts` | `InteractPrompt._apply_contrast` |
| `accessibility/reduce_motion` | `DialogueScreen._on_line_changed` — the typewriter |
| `accessibility/hold_to_confirm` | `InteractionSensor.hold_needed` |

**`video/bloom` and `video/shadows` look like the same kind of setting and are not, and that is
the most transferable thing in the row.** Bloom is one property of one `Environment` that one node
owns, so it went to that node. Shadows are cast by **lights an area author placed** — the courtyard
has four, and the two demo areas carry eight `shadow_enabled = true` between them — and **no node
owns the set of them.** A driver that walked the tree collecting lights would be wrong for every
light added after it was written, which is the god object ADR-0001 refuses. So it is applied at the
atlas: `positional_shadow_atlas_size = 0` and `directional_shadow_atlas_set_size(0, true)`, after
which every light in the world casts nothing, whoever placed it and whenever. **A game that adds a
hundred lights gets the setting for free and writes no code.** That is the test of a template seam,
and it is why the placement is beside `_apply_display` rather than in a listener invented to hold
it.

`accessibility/text_scale` scales the theme's font sizes from a CACHED base, never from the live
value — multiplying the current size compounds and rounds on the way, so walking the row to 1.5 and
on to 2.0 would not land where going straight to 2.0 does. `Window.content_scale_factor` is the
one-line alternative and is wrong: it magnifies the HUD's layout and the dialogue frame's margins
too, so a player who asked for bigger text gets less of the world.

### Three settings removed, and that is a decision rather than a shortcut

`gameplay/camera_shake`, `gameplay/autosave` and `accessibility/subtitles` have no machinery in
this template to reach. There is no screen shake anywhere under `src/`; there is no autosave, and
`SaveSystem` has no notion of the slot a run belongs to; nothing is voiced. Wiring them would have
meant inventing three features inside a row about connecting existing ones. **A row drawn to the
player that cannot do anything is worse than a dead constant, because the player is the one who
finds out.** They are gone from `DEFAULTS` and from the CSV, which is all it took —
`settings_screen.gd` is generated from `DEFAULTS` and needed no edit at all, which is the payoff
of a decision made when that screen was written. Each returns in one line plus one CSV row the day
its feature exists, and the reason each was removed is recorded in the `DEFAULTS` block itself,
where the next person considering re-adding one will be standing. Screen shake and autosave are
candidate rows below.

### The four folded-in fixes

- **`reset_to_defaults()` never called `_apply_locale()`.** One line, and a live bug: Reset wrote
  `locale = "en"` and left the UI in the old language. Invisible to every other rung, because the
  file on disk was correct — only the screen could tell.
- **`set_dof_enabled()` had no caller.** It has one, and the rig now remembers what the area author
  authored, so the setting is the player's VETO rather than a blanket yes: a rig shipping with DOF
  off stays off however the setting moves.
- **`Actions.JUMP` is gone entirely** — const, Space/pad binding, `REBINDABLE` entry and CSV row.
  It was a rebinding row for a verb `player_controller.gd` says three times over this template does
  not have, and nothing polled it. `GameEnums.MoveState.JUMP` is a different symbol and stays.
- **`KeyBindings.rebind()` gates on `Actions.REBINDABLE`.** It gated on `InputMap.has_action`, so
  `debug_console` could be written into `input.cfg` and then never reset, because `reset_bindings()`
  re-declares only the four rebindable groups. This spends that file's MUST NOT line in exactly one
  expression and the header says so: the alternative was a second copy of the list, and two lists
  that drift is the defect this project keeps finding.

### The seventh gate was deliberately not built, and the reason is not effort

T5.4's own closing note said its three gates do not catch this class, because a setting is a string
key read through `DictRead` — not a `class_name`, a `signal` or a CSV row. So the question had to be
asked somewhere new. **It is asked as an assertion in `tests/unit/settings_consumers_test.gd`, and
the deciding factor was what the two places can REACH.** A `check_*` tool reads text off disk and
would have to reconstruct the key list by parsing `settings.gd`; a test has `Settings.DEFAULTS` as
the engine actually loaded it. Where the subject of a rule is a runtime fact, the assertion is the
truer place — and T5.4's three went to `tools/` for the mirror reason: which layer a path is in,
and what a `.tscn` contains, no running game can see. CI runs the suite as its own step, so the
coverage is identical either way.

**Writing it found a third way to be a consumer, and the first version failed on nine correct
settings.** The obvious rule — *some file other than `settings.gd` and `settings_screen.gd` names
this key* — reported `video/vsync`, `audio/music` and seven more as dead. Both exclusions were
wrong, in opposite directions: `audio_director.gd` handles `section == "audio"` wholesale and then
computes each key as `"audio/%s" % bus_name.to_lower()`, so the five volume keys **appear nowhere as
literals**; and `settings.gd` genuinely IS the consumer for five of them, for the reason its header
has given since WP-01. For that file alone two mentions are required, because the `DEFAULTS`
declaration is a mention.

### Proof

Eight plants, each a real reversion rather than a broken assertion, and each exit 1 — the full
table is in `DEVLOG.md`. The two that matter as a pair: a NEW setting declared with no reader
(`something consumes 'video/planted_knob' — expected true, got false`) and an EXISTING consumer
that stops reading its key (`something consumes 'video/bloom'`). The headline assertion catches a
dead setting arriving from either direction.

**The ninth plant found a defect in this package's own work.** Mindful of gotcha 54, the test
asserted not only that `UiAccessibility` works but that the running game instances one. The first
version read `game_root.tscn` as TEXT — and when the node was deleted as a plant the suite stayed
**green, byte-identical**, because an `[ext_resource]` line survives the removal of every node that
used it and eight other nodes carry `parent="UILayer"`. Rewritten against `PackedScene.get_state()`,
where a script is a PROPERTY of a node: replanted, exit 1. **That is gotcha 56 — writing the wire
assertion was not the hard part, writing one that can fail was.**

Six settings photographed in pairs, each pair differing by exactly one line in
`user://settings.cfg`: text scale (20.9% of pixels, every font in the UI including the HUD clock),
shadows (97.6%, every cast shadow in the frame gone), depth of field (21.2% — and the first crop
showed nothing because the crate sits inside the in-focus band, so a per-block diff located the
region first), bloom (99.9% at 21:00), render scale (76.6%), and the prompt's two. The outline
width is **the one number in this package chosen by photograph rather than by taste**: 6 swamped an
18px font and read worse than no outline at all, 2 was invisible against the courtyard's grass, 4
survived.

### What this package deliberately did not do

- **It did not wire the three it removed.** Screen shake, autosave and subtitles are features, and
  autosave needs a slot POLICY before it needs a trigger.
- **It did not finish `reduce_motion`. CLOSED BY T5.7.** `ScreenFade` and the camera's `follow_lag` are motion too
  and still ignore it. One consumer makes the setting honest, not complete.
- **It did not read the authored shadow atlas size. CLOSED BY T5.7, AND IT WAS WORSE THAN THIS BULLET SAYS — the const was 2048 and the engine default is 4096, so it halved THIS repository, not a hypothetical fork.** `_apply_shadows` restores a `2048` const, so a
  game that authored a different size in `project.godot` loses it the first time a player toggles
  shadows. The fix is `HD2DCameraRig`'s `_authored_dof` pattern and costs two lines `settings.gd`
  does not have — it is at 144 of its 150-line override.
- **It wrote no ADR.** One node under `UILayer`, four settings applied where the thing they change
  already lives, and one input list read instead of copied. `ARCHITECTURE.md` already says the
  owning system reacts; this row only made that true for nine more settings.

## T5.7 · `reduce_motion` finished, plus the shadow atlas — **DONE**

Candidate I. Both halves were diagnosed by T5.5, written down as gaps, and deliberately skipped by
T5.6 because folding them in would have put three unrelated diffs in the one row whose headline
claim was *no file under `src/` changed*. Neither was hard. One of them was not what it was
filed as.

### The three motions

`accessibility/reduce_motion` had one consumer — the dialogue typewriter — and T5.5 said in its
own DEVLOG that one consumer makes a setting honest and not complete. It has three now.

| Motion | Consumer | What reduce-motion does to it |
|---|---|---|
| animated TEXT | `DialogueScreen._on_line_changed` | the line arrives whole (T5.5) |
| the screen FADE | `ScreenFade._on_fade_requested` | cuts, exactly as a fade of zero seconds does |
| the CAMERA | `HD2DCameraRig._apply_reduce_motion` | `follow_lag` goes to zero, so the camera stops sliding after a stopped character |

Each names the key as a `const` on itself, which is the convention that makes
`settings_consumers_test._is_consumed` decidable rather than a heuristic, and an assertion now
requires the three consts to agree with the declaration — three copies of a string are three
chances to typo one into a key nothing sets.

**THE CUT IS NOT A FASTER FADE, and that is a decision.** Halving a duration is still animation,
and a preference that only makes motion briefer has not honoured the request. `DialogueScreen`
made the same choice for the same reason a row earlier.

**THE CAMERA TAKES THE VETO SHAPE and this is the half worth reading.** `_authored_lag` is read at
`_ready` before the setting is folded in, exactly as `_authored_dof` is, so a rig an area author
shipped rigid (`follow_lag = 0.0`) stays rigid however the setting moves. The setting may REMOVE
smoothing an author authored; it may never ADD smoothing they refused. Assigned to `follow_lag`
rather than clamped at the read site, because a second "effective lag" variable beside the
exported one is two numbers that can disagree — the defect this project keeps finding.

### The shadow atlas, which was not the defect it was filed as

T5.5 recorded this as a portability worry: *a game that authored a different atlas size in
`project.godot` would have it replaced the first time a player toggles shadows.* Measured, on a
real display server, it is worse and nearer:

```
                       boot     off      back on
with the 2048 const    2048     0        2048
with ShadowAtlas       4096     0        4096
```

**The engine's default positional atlas is 4096, not 2048**, and `_apply_display()` runs at
`_ready`, so this repository booted **every windowed session at half the shadow resolution the
project authored**, before a player touched anything. Two things hid it for two rows. The OFF half
is the half a wrong constant cannot break, and off is the only half T5.5 photographed. And
`_apply_display()` returns early when `DisplayServer.get_name() == "headless"`, so **no rung below
the windowed capture executes that code at all** — the suite could not have caught it however many
assertions were pointed at the setting. That is gotcha 61.

**WHERE IT WENT, WHICH THE ROW WAS ASKED TO DECIDE.** `settings.gd` was at 144 of its 150-line
override, and the fix needs STATE — the authored sizes — which is the kind of thing every future
setting will be tempted to add beside. So it is `ShadowAtlas`, a `RefCounted` in `core` that owns
one property of the renderer and knows nothing about `video/shadows`, and `settings.gd` came DOWN
to 139 because the two consts and four lines of body left with it. A const cannot be right there
at all: the number is a project setting a consuming game is invited to change, so the only correct
value is the one read back before the first zeroing.

### What the verification found out about itself

The row was told to think about what a still frame can prove before promising one, on T5.5's
honest limit: *an instant reveal photographs identically to a finished one.* That limit holds for
the fade and **fails for the camera**, and noticing why is the most transferable thing here.

A fade converges. A camera following a MOVING character never does — `follow_lag` sets a steady
trailing distance that persists for as long as the character keeps walking, so there is a picture
to take. Two `--gait-shots` runs differing by one line of `settings.cfg`:

- the whole world is translated **42 px** between them at run speed;
- a brute-force offset search over a static band (rows 340–450, no HUD, no character) puts the
  residual at **0.0268 at −42 px** against **0.0975 at zero** — a 3.6× drop, so it is a RIGID
  SHIFT of the scene and not a lighting or content difference;
- every static landmark agrees: the pillar edge, the platform edge, the crate and the low wall
  all move together while the character stays put.

The fade is proved by assertion only, and the reason is recorded rather than left as an omission:
`Events.screen_fade_requested` is the node's only input and `run()` is synchronous, so a tween
created inside the handler has not advanced when the next line reads `color.a`. A dissolve leaves
the alpha where it started and a cut leaves it at the target — no awaits, no test-only accessor,
and no reaching at the private tween.

### What this package deliberately did not do

- **It did not build screen shake**, which is candidate H, even though `reduce_motion` will have
  to reach it. The pattern to copy is now written down on the rig.
- **It did not touch `face_direction()`**, which is candidate C and the owner's seam decision.
- **It wrote no ADR.** One `RefCounted` in `core`, two settings applied where the thing they
  change already lives. No autoload, no new layer, no new seam concept.
- **It did not fix what the owner saw.** Sideways movement reads as a slide, and it is the
  placeholder SHEET rather than the camera or the animation code — candidate J, measured in this
  row and left for its own.

## T5.8 · A placeholder sheet whose facings are distinguishable — **DONE**

Candidate J, and the only row on this board that came from the owner **playing the game** rather
than from an audit. On 2026-09-05 they said sideways movement "just slides to the side". It did.

### What was wrong, and it was not the code

`character_placeholder.png` drew **one pose eight times**. Measured as the fraction of differing
pixels in a cell, walk block, over the figure band:

| pair | before | after |
|---|---|---|
| default sheet, least alike facings | **0.0000** — facings 2 and 3 byte-identical | 0.0747 |
| default sheet, front against back | 0.0070 — the two eyes and nothing else | 0.3213 |
| alt sheet, least alike facings | **0.0000** — three columns differed only by the pip tally | 0.2188 |

`_aim` quantises the direction (`facing_test`), `column_for_angle` derives the sector from the
layout (`art_contract_test`), `update_from_velocity` advances the cycle (`gaits_test`). All green,
all correct. **The sheet had nothing different to draw**, so the facing system was invisible in
every capture this project ever took — T5.2's, T5.3's and T5.6's — and the first observer was
whoever played it. That is **gotcha 62**: gotcha 54 with the unwired middle made of pixels.

### What it did

**Five poses and a mirror**, in `tools/gen_placeholders.gd` and nowhere else: front,
three-quarter, side, three-quarter back, back. The torso narrows and steps forward as the figure
turns, the legs close into a front-to-back stride, the hair wraps further round the head, the eyes
go 2, 2, 1, 0, 0, a profile grows a nose and hides its far arm, and a back is drawn in its own
shadow. Facings 5-7 are 1-3 **flipped**. The four-facing sheet gets three of the same poses.

A cell is now drawn into a CELL-SIZED image and blitted, which the mirror needed — and which makes
**gotcha 57 structurally impossible** rather than asserted, because `_plot` now clips to the cell.

**`tests/unit/sheet_facings_test.gd`** (8 assertions), and the floor was picked by measurement on
T5.5's precedent: 0.05 is above the largest gap either OLD sheet could reach (0.0347) and below
the smallest either new one reaches (0.0747). Four claims per sheet, each failing differently —
the least alike pair clears the floor, front against back clears it under its own name, the
mirrored half is a real mirror, and the cycle still advances (which refuses the cheap way to pass
the first three).

**Proved by planting the defect:** `FACING_TURN` back to all zeros, both sheets regenerated and
re-imported → `=== 1823 passed, 6 failed ===`, **exit 1**. Removed → `=== 1829 passed, 0 failed
===`, **exit 0**.

**And photographed, which is what the row is for.** `--facing-shots=<dir>` on `dev_gait_shots.gd`
walks the character north, east, south and west: columns **4, 2, 0 and 6** decoded out of
`sprite.frame`, agreeing with four pictures that read as a back with no face, a right profile, a
front, and the same profile mirrored. **T5.6 recorded that absence as its own gap** — every
capture ever taken had been column 0 or column 1.

### What it deliberately did not do

- **It did not split `gen_placeholders.gd`**, which is now at 230 of its 250. A split plus a
  rewrite in one diff makes the rewrite unreviewable. The seam is named in the DEVLOG and the next
  row that touches a character sheet has to take it.
- **It did not put pip tallies on the DEFAULT sheet.** They belong to the swap demonstration; on
  the sheet the demo ships they would appear in every screenshot this project takes.
- **It did not touch `face_direction()`**, which is candidate C and the owner's seam decision —
  though it removes the argument against building one.
- **It changed no art CONTRACT.** Same facings, frames, blocks and cells; both `.tres` untouched.

## T5.9 · Screen shake, and the setting that scales it — **DONE**

Candidate H, and the row T5.7 obliged: *when a shake exists, `reduce_motion` has to reach it in
the same row rather than in a fourth one, or that setting is a gap again.* Both halves landed.
Version 2.4.0.

### What it built, and where each piece went

| Piece | Where | Note |
|---|---|---|
| the motion | `HD2DCameraRig._offset_by_shake` | a decaying SINE along the camera's own axes, applied after `look_at` |
| the ask | `Events.camera_shake_requested(strength, seconds)` | `_requested`, many askers by design, like `notify_requested` |
| the asker | `Gate.perform` when `open_shake > 0.0` | **defaults to 0.0** — every gate already authored stays silent |
| the author's number | `shake_metres`, `shake_hz` on the rig | 0.35 m, 18 Hz |
| the player's veto | `gameplay/camera_shake`, 0..1 | back in `DEFAULTS`; one line plus one CSV row, and `settings_screen.gd` needed no edit |
| the accessibility veto | `accessibility/reduce_motion` | removes it OUTRIGHT rather than scaling it |

It stayed on `HD2DCameraRig`, which went 102 -> 138 of its 250. A `CameraShake` `RefCounted` on
`ShadowAtlas`'s model was considered and refused: the offset is applied to a camera this node
already places, inside a function it already calls every physics frame, and a class holding four
floats would have been a seam invented to look like T5.7's.

### The pattern was copied, not reinvented

`_authored_shake` is read at `_ready` beside `_authored_dof` and `_authored_lag` — three authored
values on one node now — and the player's scale is folded INTO `shake_metres` rather than kept in
a second variable beside it, on T5.7's reasoning exactly. **A rig an area author shipped at
`shake_metres = 0.0` never shakes, whoever asks and whatever the player prefers.** `SHAKE_SETTING`
is a `const` on the consumer, which is what keeps `settings_consumers_test._is_consumed` decidable.

**`reduce_motion` cuts rather than scales**, the third time this project has made that call after
the typewriter and the fade: a quieter shake is still a shake.

### WHO MAY ASK — the seam question, decided and recorded

On the bus, with many askers by design: the thing that just happened knows how hard it hit and
nothing about a camera; the rig knows how far it may move and nothing about gates. The template's
own asker is **`Gate`**, because a heavy leaf grinding open is the one impact a game with no
combat actually has, and because it is AUTHORED — `open_shake` is per gate and defaults to silent,
so a garden gate and a portcullis are one class with different numbers. The demo courtyard's
`NorthGate` sets `0.7`, in a `.tscn` and not under `src/`.

### A sine and not noise, which is what made it provable

Random jitter cannot be verified — two runs differ — so "exactly half as far" would have been an
unassertable claim in the suite and an unmeasurable one in a capture. Five windowed runs of one
command differing only by `user://settings.cfg`:

| `camera_shake` | camera x | best rigid offset vs the control | residual there | residual at zero |
|---|---|---|---|---|
| (no shake asked for) | 0.000000 | — | — | — |
| 1.0 | **0.302357** | **(+14, −12) px** | 0.0173 | 0.0513 |
| 0.5 | **0.151178** | **(+8, −6) px** | 0.0125 | 0.0402 |
| 0.0 | 0.000000 | (0, 0) | 0.0004 | 0.0004 |
| `reduce_motion = true` | 0.000000 | (0, 0) | 0.0001 | 0.0001 |

The picture halves when the number halves. **Looked at, not only measured:** the world is
displaced while the HUD and the prompt sit at identical pixels — a camera shake and not a screen
shake, which no log line could have said. **Gotcha 64** came out of reconciling the two columns.

**Proved by planting, both exit codes recorded.** `_apply_shake_scale` reverted to ignoring both
settings -> `1844 passed, 4 failed`, **exit 1**; the rig's `connect` line removed, leaving both
ends of the wire green -> `1847 passed, 1 failed`, **exit 1**; both removed -> `1848 passed,
0 failed`, **exit 0**. Suite 1,829 -> 1,848.

### What it deliberately did not do

- **It did not photograph a GATE opening.** The demo's north gate needs the lever and the key, so
  it is not on a boot capture's path; `--shake=` on `dev_capture.gd` fires the same signal instead.
  A `dev_probes.gd` row that unlocks the gate and shoots the frame after would close it.
- **It did not assert `shake_hz`.** Every assertion measures the same instant of the wave, which
  is what makes them comparable and also means a changed frequency would keep them all green.
- **It did not make shakes additive.** A new request replaces a running one, so nothing repeatable
  can drive the camera off the world. Four lines in `shake()` if a game wants layered rumble.
- **It did not split `gen_placeholders.gd`**, still at 230 of its 250 and still next, because it
  touched no character sheet.
- **It wrote no ADR.** One signal, one method, two exports on the node that already owned the
  camera.

## T5.10 · Autosave, and the slot policy it needed first — **DONE**

Candidate G, and the SECOND of the three settings version 2.0.0 removed to come back with the
feature it was waiting for. Only `accessibility/subtitles` is still out. Version 2.5.0.

### The design question was the SLOT, and the answer

| Candidate | Verdict |
|---|---|
| rotate through the manual slots | **rejected** — an autosave can then destroy a save the player made on purpose |
| reserve slot 5 of the six | **rejected** — same objection, plus it changes what slot 5 MEANS in every save file already on disk. A MAJOR bump paid for nothing |
| **one past the six** (`AUTOSAVE_SLOT = MAX_SLOTS`, `user://saves/autosave.json`) | **taken.** No manual list can reach it, because every manual list iterates `MAX_SLOTS` and never counts that high — no filter to remember, no existing save touched, MINOR bump |

**The read range is deliberately not the write range.** `latest_slot()` iterates
`AUTOSAVE_SLOT + 1` and the save screen's writing half still iterates `MAX_SLOTS`: writing is
manual-only, reading is everything. Continue resumes the autosave and the load list offers it as a
row of its own, while the save list — built over the identical files — cannot name it.

### What it built, and where each piece went

| Piece | Where | Note |
|---|---|---|
| the policy | `Autosave` under `GameRoot`, `src/systems/autosave/` | a node, not an autoload — an autoload needs an ADR, and this is two connections and one decision |
| the slot | `SaveSystem.AUTOSAVE_SLOT`, `AUTOSAVE_FILE`, `is_autosave()` | a slot number's legality and its path are facts about the store, so they belong to the store |
| the occasions | `Events.game_ending`, `Events.area_entered` | both already on the bus. **No signal was added** |
| the trigger for quit | `game_ending`, synchronous | the close button comes through the same path; `game_root.gd` gained nothing but lost a stale comment |
| the trigger for arrival | `area_entered`, **one frame late** | see gotcha 65 — on the spot it would have been refused every time |
| the player's veto | `gameplay/autosave`, back in `DEFAULTS`, default `true` | takes an occasion away, never adds one |
| the indicator | `notify.autosaved` on the existing toast | `SYSTEMS_INVENTORY.md` item 6, photographed |
| a game's own occasion | `Autosave.request()` | public, so a chapter break or a bed is one call and no edit to `src/` |

### Gotcha 65, which is the thing here that will cost the next person an hour

`Director._run_transition` emits `area_entered` and clears `_transitioning` **two statements
later** — correctly, because that signal means "the area is in the tree and the player is placed"
and the transition is not over until the curtain has been asked to lift. A handler reading
`is_transitioning()` on the spot is therefore refused on **every arrival**, and the feature never
fires once, with nothing red anywhere: both ends of the wire correct, the guard behaving exactly as
specified, and a feature that does nothing. Gotcha 54's family with the unwired middle made of
ORDERING. Fixed with one `await get_tree().process_frame`; the assertion that pins it emits
`area_entered` inside a synchronous `run()`, where no frame ever comes, and requires that nothing
was written.

### Verified

Six checkers exit 0, `1848 -> 1898` assertions, `0 warnings, 0 errors` on boot and on both
captures. Four plants, each a real reversion, each exit 1 — the synchronous area handler
(1 failed), the autosave reserving a manual slot (5 failed), `latest_slot()` blind to the autosave
(1 failed), and the transition guard deleted (3 failed) — all removed, `1898 passed, 0 failed`.
CI green on `0e99c86`, PR #39; stripped template 1,824, so all 50 new assertions survive the strip.
**The layer gate caught this row's own trailing comment**: a `core` file naming `Autosave`, which
is `systems`.

**A save is a FILE, so most of this row is provable in the suite** in a way T5.7's and T5.9's
camera work was not — including the policy's whole promise, driven end to end: write the autosave,
then write into all six slots the save screen offers, and the autosave header is still `equal` to
what it was. **What the capture carries is the INDICATOR.** Two runs of the standing regression
command differing by one line of `settings.cfg`: with defaults, `[save] Slot 6 written`,
`user://saves/autosave.json` on disk, and `Autosaved.` on the toast over an otherwise identical
frame; with `autosave=false`, no log line, an **empty** saves directory, and no toast. The standing
dusk capture now carries that toast, which is the feature and not a regression.

### What it did NOT do, deliberately

- **It did not photograph a LOAD of the autosave.** `load_from_slot` is the same call the load list
  already makes and the autosave's row in that list is asserted, but no probe boots, autosaves,
  quits, relaunches and continues into it. A `dev_probes.gd` row, the same shape as T5.9's
  gate-opening gap, and the one claim here resting on "same code path" rather than a measurement.
- **It did not add an "are you sure" on quitting**, `SYSTEMS_INVENTORY.md` item 7, now half
  obsolete: with the autosave on there is less unsaved progress to warn about, and with it off
  there is exactly as much as before.
- **It did not make autosaves queue.** A second landing while the first is in flight is refused by
  `_busy`, which is right for two occasions a frame or a session apart.
- **It did not split `gen_placeholders.gd`**, still at 230 of its 250 and still next, because it
  touched no character sheet.
- **It wrote no ADR.** One node, two connections, one decision, and a slot number on the file that
  already owns slot numbers.

## T5.11 · Music ducking, built — and the alias beside it deleted — **DONE**

Candidate E, and the row was explicitly "build it or delete it". **The answer is both**, split on
one line. Version 3.0.0 — a MAJOR bump, because a public method was deleted.

### The three dead methods, and what each got

| Method | Verdict | Why |
|---|---|---|
| `duck()` / `unduck()` | **built** | The occasion already existed. `Events.dialogue_started` / `dialogue_finished` have been on the bus since Phase 0 with one emitter each, and lowering music under dialogue is what ducking IS. One node, no new signal — T5.10's shape exactly |
| `stop_music()` | **deleted** | Two lines of alias over `play_music(null, fade)`, no caller in three phases, and no occasion this template has that the surviving spelling does not already serve. Two ways to say one thing in a file with a hard 150-line budget is a cost with nothing on the other side |

**And it was not merely uncalled — it was WRONG, which only wiring it could reveal.** `duck()`
tweened to an ABSOLUTE −8 dB, so against a player who had moved `audio/music` to 0.25 (−12 dB) it
made the music four decibels LOUDER every time somebody spoke. `target_db(bus)` is the fix: the
player's own level plus whatever duck is in force, with a muted bus staying muted. Three smaller
defects fell out of the same wiring — a settings change lifted the duck, two ducks raced, and a
positive "duck" would have worked.

**The count is the design decision.** `DialogueDuck` holds while ANY conversation runs and releases
after the LAST, because two overlapping conversations make a plain duck/unduck pair lift the music
underneath one still running, with nothing red anywhere. `held()` is public so the balance is
assertable as a count and not only as a decibel.

**No new setting, deliberately.** Nothing was owed one — T5.9's and T5.10's keys were both settings
2.0.0 had removed — and the player already owns the outcome through `audio/music` and
`audio/ambience`, which the duck is now measured FROM rather than against.

**Essentially all of it is proved in the suite**, because a bus volume in dB is a number the audio
server hands back even under the dummy driver. Suite 1,898 → 1,935; five plants, each a real
reversion, each exit 1. **Gotcha 66** retires an honest limit T5.7 recorded: `get_processed_tweens()`
plus `Tween.custom_step()` make a fade distinguishable from a cut inside a synchronous `run()`.

### What it did NOT do

- **It did not build the fourth consumer gate**, and said so in writing. A public-method liveness
  gate cannot be a text scan the way `check_signals.gd` is — methods are called through
  `Callable`, `.bind`, `.tscn` properties and typed variables, and "has a caller in the suite" is
  not "has a caller in the game". It is candidate K, a package rather than a paragraph.
- **It did not prove anything can be HEARD.** There is no audio in the project at all, which is why
  the inventory row stays `PART`.
- **It did not add a `dev_probes.gd` probe.** One that opens the demo conversation and logs the
  Music bus would close the last gap here, and it is the same probe row T5.9 and T5.10 both want.
- **It did not split `gen_placeholders.gd`**, still at 230 of its 250 and still next.
- **It wrote no ADR.** One node, two connections, one decision, and a method on the file that
  already owns bus decibels.

## T5.12 · Two capture gaps closed, and the third argued away — **DONE**

**2026-09-06. Version 3.1.0.** Three consecutive rows — T5.9, T5.10 and T5.11 — closed with the
same admission in their own Gaps section, each naming a probe as the fix. Three rows deferring the
same work is the signal, and the first job was to ask whether all three deserved it.

| Gap | Verdict | Why |
|---|---|---|
| T5.9 — the gate's own shake | **built** | `--shake=` emits the signal a gate emits, so it photographs the RIG. Nothing had ever shown a gate doing it, and `Gate.perform()`'s emit was proved by reading four lines |
| T5.10 — the autosave read back | **built** | The row's own words: the only claim in it resting on "it is the same code path" |
| T5.11 — the Music bus in dB | **NOT built** | **A still frame cannot show a decibel**, so the probe's whole output would be a log line — and this row's standard is that a log line does not close a capture gap. Gotcha 66 already retired the limit that made it look necessary, and the duck is measured end to end in the suite through a real `DialogueRunner`. The pause hazard that would have justified it was checked and does not exist: `AudioDirector` is `PROCESS_MODE_ALWAYS` and `DialogueScreen` sets `pauses_world = false` |

**`src/systems/debug/dev_scenario_shots.gd` is the fifth debug file, 198 of its 250.** The budget
forced the split and the seam was already there, for the third time in this directory:
`dev_probes.gd` (205/250) prints a NUMBER, `dev_capture.gd` shoots at a FRAME NUMBER, and neither
can photograph a moment that exists for six tenths of a second and only after a scripted sequence
produced it. That is `dev_gait_shots.gd`'s question with the subject changed, which is why the
shutter takes its shape rather than a new one.

**THE PROBE FOUND TWO DEFECTS IN ITSELF BEFORE IT FOUND ANYTHING ELSE, both silent, both green.**
Standing beside a thing does not SELECT it — the first run pressed interact on a barter action two
metres away, the lever was never thrown, and the gate refused with `LOCKED`; cycling is what a
player does about that. And `rest` sampled twenty frames after a teleport is the exponential
smoothing tail, which the probe reported as a 0.4288 m "shake" of a gate that had not opened.
`_camera_still()` now waits for the rig to park and reports **53 frames**.

**0.154743 m against 0.000050 m**, the same command with one line of `settings.cfg` changed and
`NorthGate opened` in both logs — and reproducible to the micrometre, because T5.9 chose a sine
over noise and this is the first thing to depend on that. The picture carries what the number
cannot: the world slid up and left with the HUD clock exactly where the control put it.

**The autosave pair is two processes for `--save-state`'s reason**, and adds the OCCASION and the
DOOR — written by `Events.area_entered`, read by pressing the main menu's own Continue row.
Run A's last report and run B's are identical; run B's boot report between them reads
`area='' day=1 time=06:00 weather=0 carrying=0`. `autosave_continued.png` shows **Day 4 | 22:15 |
Night** and a toast reading "Autosaved." A restored `Clock.hour` is a number in a log; a hall lit
for night is the photograph that says it reached a renderer.

**12 assertions, neither group about the probes' own behaviour.** `interaction_test.gd` +6: a gate
asks for exactly the amplitude its author wrote and for `Gate.SHAKE_SECONDS`, and **a gate left at
the default zero opens and asks for nothing** — the half a bare `emit` would keep green.
`dev_tools_test.gd` +6: every script under `src/systems/debug/` that reads
`OS.get_cmdline_user_args()` has a node in `game_root.tscn`, because a debug file with no node is
not a broken tool but an absent one. Suite 1,935 → 1,947. Two plants, each a real reversion, each
**exit 1** with its control at **exit 0**.

**3.1.0 and not a PATCH on one line.** Nothing under `src/` outside the debug directory changed,
which is the PATCH condition — but `game_root.tscn` gained a node, and that is a file a consuming
game has to merge. **Found and not fixed:** the main menu's Continue row reads "Continue — Slot 7"
for the autosave, which is the reading T5.10's file naming was chosen to avoid. It is a wording
question on a UI string and belongs to whoever owns that screen's copy.

## T5.13 · A public-method liveness gate — **DONE**

**2026-09-06. Version 4.0.0.** Candidate K, the fourth consumer question, and the last of the four
with no enforcement. `tools/check_methods.gd` is rung 11: a public method declared at column 0
under `src/` whose name is written nowhere else in the repository fails the build.

**The design question was which methods it is even asked of, and the answer is what makes the
tool possible.** T5.11 recorded, correctly, that a method is called through `Callable`, `.bind`,
`.tscn` properties and typed variables a scan cannot resolve. **None of that matters, because the
gate does not resolve calls.** It asks the narrowest question a text scan can answer soundly —
*did anybody write this name down at all*, on any non-comment line, in `.gd`, `.tscn` or `.tres`.
Every one of those dispatch forms writes the name out, including the one an earlier draft got
wrong: an unqualified inherited call, `set_available(false)` in a subclass, which made `perform`,
`add_row`, `push` and `request_close` all look dead.

**First run: exit 1, twelve violations of 316 public methods.**

| Verdict | Count | Which |
|---|---|---|
| **deleted** | 2 | `DialogueNode.has_choices()` — an alias over `not choices.is_empty()`, which both real readers already write. `ItemDefinition.is_equippable()` — its doc claimed "an `Equipment` component and a UI row both ask this" and **neither ever did**; the one place that asks writes `slot_of(id) != NONE`, which also answers for an id with no definition |
| **wired** | 1 | `NpcBrain.current_activity()` — `activity_name()` indexed the private field beside it and now reads the accessor |
| **exempt** | 9 | A log level, the untyped `Flags` hatch, a `PersistentState` typed family of three, a `Readable`'s persisted read flag, a `Footsteps` pair, and `Director.reload_current_area()`, which was the close call and is recorded as such |

**A gate for dead code found two false claims in prose**, which is not what it was built for and
is the most useful thing it did: `is_equippable()` named callers that never existed and
`Footsteps.current_surface()` said "read by the probe" when no probe has ever read it.

**Proved against the case that motivated it.** At `7a162ca`, the merge base before T5.11,
`git grep -w` for `duck`, `unduck` and `stop_music` returns five hits: three declaration headers
and two comment lines, one of them the word "duck-typed" in an unrelated file. The tool drops
comments and declaration headers before counting, so it would have failed on the day each landed.

**What it deliberately does NOT fail on is the other half of the design.** 86 of the 314 public
methods are reached only from `tests/` or `tools/`, and "has a caller in the suite" is genuinely
not "has a caller in the game" — but a template declares accessors a consuming game calls and this
repository never will, so failing there would be answered with a fake caller in `src/`, which the
gate would then certify as green. Reported on every run, never failed: `check_signals.gd`'s
asymmetry for a listener, with the subject changed. **The gate under-reports and cannot
over-report** — 37 names are declared in more than one file and are treated as one — so a green
run is not a proof while a red run is always real.

**One precondition, and it fired on this row's own test file.** No line may both dispatch
(`call(`, `callv(`, `call_deferred(`, `Callable(`, `has_method(`) and build a string, because a
name assembled at runtime is the one form the scan cannot see. `gates_test.gd`, asserting that
exact classifier, wrote the opaque sample out whole; the gate was right and the test was the
violation. The sample is now split across two constants. **Gotcha 69**, and it waits for every
gate whose evidence is a line of text.

**+24 assertions, 1,947 → 1,970, all on the CLASSIFIERS** and none on today's tree: what a
declaration is, what a reference is, the two kinds of line thrown away first, the precondition
classifier, and that every use of the exemption phrase in the whole engine tree sits in a comment.
Three plants — a restored dead method, a stale exemption, a built name — each **exit 1**, control
**exit 0**.

**4.0.0 and not a PATCH, on the two deletions.** A new tool under `tools/` that changes nothing
under `src/` carries a consuming game no obligation and would be a PATCH; two public methods gone
is a MAJOR bump by the rule 3.0.0 set for `stop_music()`, and the `CHANGELOG.md` entry names the
one-line replacement for each.

### What it did NOT do

- **It did not answer the 86.** A method kept alive only by its own test is exactly the class
  `duck()` was in, and this gate cannot see into it. A run of the game with a call recorder could;
  that is a package of its own and is not on the board yet.
- **It did not touch `face_direction()`**, which is candidate C and the owner's seam decision. It
  is one of the 86, which is now a measured fact rather than an impression.
- **It did not split `gen_placeholders.gd`**, still at 230 of its 250 and still next.
- **It did not fix the "Continue — Slot 7" wording** T5.12 found in `MainMenuScreen._fill`.
- **It wrote no ADR.** One tool, one exemption phrase copied from an existing gate.

## Candidate rows — ranked. ALL ARE DONE — T5.4-T5.15, and F was the last

These are the audit's findings that are packages rather than one-line corrections. Ranked by value
to a consuming game per unit of work. Each is sized to one chat.

| # | Candidate | Why it is worth a row |
|---|---|---|
| ~~C~~ | ~~**A turn in place** — but the seam decision first~~ | **DONE — T5.14, 2026-09-06. The SEAM DECISION was the package and the owner made it.** The answer was BOTH, and the reason settled the shape: the case the owner described — an NPC that notices the player, walks over and stops them — has no interactable in it, so no asker inside the interaction path could serve it. That rules out a method call and leaves the bus. **`Events.turn_requested(character, towards)`**, on `camera_shake_requested`'s shape; `CharacterVisual` listens and answers only for the character the request NAMES; `InteractionSensor` asks for the player while STILL, `Speaker` asks for whoever you talk to, and a third asker needs nothing added. **The hold flag the estimate assumed does not exist**: `update_from_velocity` re-aims only while moving, so a turn given to a standing character simply persists — an NPC is still looking at you when the box closes, for free. Photographed to T5.8's standard: column 3 to column 5, **0.7666 of the crop's pixels changed against a 0.1838 no-turn control**. **Gotcha 70**: the stillness-gate plant PASSED on the first draft of its own test, because the case never staged a target changing mid-walk — a green plant is evidence about the test |
| ~~D~~ | ~~**A wholesale character swap, photographed**~~ | **DONE — T5.6, 2026-09-05.** The alt sheet gained its gait set, the player was pointed at it and all five gaits were photographed with nothing under `src/` changed. Phase T5's third exit criterion is ticked and the phase is closable at the owner's word — the two boxes that remain are a second idle block and candidate C, which is the owner's seam decision |
| ~~E~~ | ~~**Music ducking, or delete it**~~ | **DONE — T5.11, 2026-09-05.** Both halves of the either/or, split on one line: `duck()` and `unduck()` were BUILT, because `Events.dialogue_started` / `dialogue_finished` were already on the bus with one emitter each and no signal had to be added; `stop_music()` was DELETED, being two lines of alias over `play_music(null, fade)` with no caller and no occasion. A MAJOR bump, 3.0.0, and the entry names the one-line replacement. **The methods were not merely uncalled, they were wrong** — `duck()` tweened to an ABSOLUTE −8 dB, so at `audio/music` 0.25 it made the music LOUDER; `target_db()` measures the duck from the player’s own level instead. `DialogueDuck` COUNTS conversations, because a plain pair lifts the music underneath a second one still running. **Gotcha 66**: `get_processed_tweens()` + `Tween.custom_step()` tell a fade from a cut inside a synchronous `run()` |
| ~~F~~ | ~~**The `Button` styleboxes**~~ | **DONE — T5.15, 2026-09-06. FOUR PACKAGES REFUSED THIS ROW FOR THE SAME REASON AND THE REASON WAS RIGHT** — a stylebox has to be *designed*, and the only palette to design against is the placeholder one, so populating it ships a decision as a default. **The fix answers that reason rather than overruling it: nothing in `src/ui/root/ui_row_styles.gd` designs a colour. It designs the RELATIONSHIP between the five states** and takes every colour from the palette, at boot, into `MenuRow` and `ChoiceRow`. **`hover` is `surface` moved TOWARD `text`, and that word is the package**: the one expression lightens a dark row and darkens a light one, so the fix survives a palette this base does not ship — which is the half of the stated defect a hard-coded lighten would have left in place, and **the plant proves it, passing every dark assertion and failing only the light ones**. `pressed` moves toward `accent` (a press is an act, so a hue rather than a shade); `disabled` keeps the hue and drops the alpha; **`focus` draws NO CENTRE**, only an accent ring, so it composes with whatever is under it — the state a mouse user never sees and a gamepad player navigates by. **ONE palette token added and argued**: `dim` and `solid` are the panel a row sits ON, `muted` already means "present but lesser", so there was no token for a button SURFACE. Photographed twice: on the shipped palette a row's separation from its panel goes **0.0981 -> 0.3490 summed channel delta (3.6x), with all 61,998 changed pixels inside the row band and none outside**; then the whole thing again on parchment, from six palette lines and no code. MINOR, **4.2.0** — a game that authored its own `styles/normal`, or ships a palette with no `surface`, is left exactly as it was, and both refusals are asserted. **Found and fixed as its own line:** the Continue row said "Continue — Slot 7" for the autosave, the reading T5.10's file naming was chosen to avoid |
| ~~G~~ | ~~**Autosave**~~ | **DONE — T5.10, 2026-09-05.** The SLOT was the design question and it is answered: a dedicated slot ONE PAST the manual six (`SaveSystem.AUTOSAVE_SLOT`, `user://saves/autosave.json`), so no manual save can reach it and no save already on disk changes meaning — a MINOR bump, where reserving slot 5 would have been a MAJOR one for nothing. The policy is a node under `GameRoot`, not a second job for `SaveSystem` and not an autoload; the occasions are `game_ending` and one frame after `area_entered`, both already on the bus, so **no signal was added and `game_root.gd` gained nothing**. Three refusals — the player's veto, a transition in flight, no run in progress — each proved by the absence of a file. `gameplay/camera_shake` and `gameplay/autosave` have both now come back with their features; only `accessibility/subtitles` is left. **Gotcha 65**: `area_entered` is emitted two statements before `_transitioning` is cleared, so the obvious guard would have refused every arrival, silently |
| ~~H~~ | ~~**Screen shake**~~ | **DONE — T5.9, 2026-09-05.** Built on `HD2DCameraRig` as a decaying sine, asked for through `Events.camera_shake_requested` with `Gate.open_shake` as the template's own asker, and `gameplay/camera_shake` is back in `DEFAULTS` as its 0..1 scale — the FIRST of the three settings 2.0.0 removed to return with the feature it was waiting for. `accessibility/reduce_motion` reaches it in the same row, which is the obligation T5.7 recorded. Photographed: the same command at scale 1.0 / 0.5 / 0.0 moves the camera 0.302357 / 0.151178 / 0.000000 m and the picture (+14,-12) / (+8,-6) / (0,0) px, with the HUD unmoved throughout |
| ~~I~~ | ~~**`reduce_motion` finished**~~ | **DONE — T5.7, 2026-09-05.** Both halves landed. The setting reaches all three motions, and the shadow atlas turned out to be a live defect rather than a portability worry: the `2048` const halved this repository's own atlas on every windowed boot, because the engine's default is 4096. Gotcha 61 |
| ~~J~~ | ~~**A placeholder sheet whose facings are distinguishable**~~ | **DONE — T5.8, 2026-09-05.** Both sheets now draw five poses and a mirror instead of one pose repeated. The worst facing pair went from 0.0000 — facings 2 and 3 were byte-identical — to 0.0747 on the default sheet and 0.2188 on the alt one, and the same character was photographed walking north, east, south and west, which nothing here had ever captured. The code was correct throughout, which is **gotcha 62**: gotcha 54 with the unwired middle made of pixels. No file under `src/` changed except the debug capture tool |
| ~~K~~ | ~~**A public-method liveness gate — the fourth consumer question**~~ | **DONE — T5.13, 2026-09-06.** `tools/check_methods.gd` is rung 11, and the design question — which methods it is even asked of — has the answer that made it buildable: not "is it called on a value of the right type", which no text scan can know, but "did anybody write this name down at all", which every dispatch form satisfies, including the unqualified inherited call an earlier draft missed. **First run: 12 violations of 316, exit 1** — two deleted (a MAJOR bump, 4.0.0, with the one-line replacement named for each), one wired, nine exempted with an argued sentence each, and **two of the twelve carried doc comments naming callers that never existed**. Proved against `duck()`: at `7a162ca` it had zero references outside its own declaration, so it would have failed on the day it landed. **86 of 314 are reached only from tests/ or tools/ and that is REPORTED, never failed** — the distinction is real, but 86 exemptions on day one is decoration and would be answered with a fake caller. Exemption is `NO CALLER` in the method own `##` block; a stale one fails too. **Gotcha 69**: the precondition fired on the test file that quoted its own trigger pattern, and the gate was right |

---

## T5.16 · Quest chaining, and the stack landed first — **DONE**

**2026-09-07. Version 4.2.1, a PATCH.** Two things, and the first was not a package.

**THE STACK WAS LANDED BEFORE ANYTHING WAS BUILT ON IT.** `main` had not moved since 2026-09-03
and still declared `1.0.1`, while sixteen CI-green PRs (#29-#44) carried T4.4 and T5.1 through
T5.15 and declared `4.2.0`. `CONTEXT.md` records the 26-PR stack of T4.3 as history and says
*"stop stacking"*; it had recurred at 16, three days after being resolved. `origin/main` was an
ancestor of the tip and `rev-list tip..main` was **0**, so retargeting PR #44 to `main` landed
all of it as one fast-forward — 31 commits, 115 files, `+13243/-593`, `16e8bfd`. Verified on
`main` afterwards rather than trusted: `2051 passed, 0 failed, 0 skipped`, seven checkers exit 0,
CI green, zero open PRs. Three PRs auto-closed as **Merged**; the other twelve hit the identical
GitHub refusal T4.3 documented, which was TESTED on #32 rather than assumed.

**AND ONE STRANDED COMMIT WAS ABANDONED ON PURPOSE, WHICH IS THE INTERESTING HALF.** Three
docs-only commits on `t5-11`/`t5-12` were not in the tip. `3eb8e59` was cherry-picked and
hand-resolved. **`f7d57cd` was not**: it recorded the owner's turn-in-place answer as *"the NPC
half lives on `NpcBrain`"*, and T5.14 shipped it via `Events.turn_requested` with `Speaker` as
the asker. Restoring a superseded decision into the *"do not re-litigate"* list is worse than
losing it — a wrong entry there is authoritative by position.

**THE DEFECT, AND IT WAS ANNOUNCED BY ITS OWN COMMENT.** `QuestTracker.evaluate()` guarded
re-entrancy with a bare `return`. The guard's comment says a listener on `quest_completed`
*"legitimately might"* write a flag and names *"starting the next chapter"* as the obvious case —
and returning DISCARDS the re-derivation that flag asked for. It is harmless only if the running
pass still reaches the newly-startable quest, and that depends on where the quest sits in
`QuestDb.all()`: `ContentScan` insertion order, which **does not sort**. So an authored chain
worked or did not according to filenames, and differently on two machines.

**WHY EIGHT RUNGS AND 2,051 ASSERTIONS WERE GREEN, and it is not that the suite was weak.** Two
independent reasons, both structural. The demo has ONE quest, so it cannot chain at all. And
`quests_test.gd` states in its own header that it drives `evaluate()` and `Flags.set_flag`
directly *"rather than through the signal chain a running game uses"* — which is the right choice
for asking what a step MEANS, and is exactly why no number of assertions in that file could have
found this: **a re-entrant call can only arrive on `flag_changed`.** The suite was pointed at a
different question. That is gotcha 44's family, and gotcha 72 states the general form.

**THE FIX IS FOUR LINES AND THE BOUND IS DERIVED.** A re-entrant call sets `_pending`; the outer
pass drains until nothing moves. The pass limit is `QuestDb.count() + 2` rather than a picked
number — a chain can be no longer than the catalogue, because a quest advances at most once per
pass and never goes backwards — so it cannot go stale at a game's sixtieth quest. Exceeding it
logs an error instead of hanging. Same reasoning that derives the facing sectors from the facing
count rather than writing 8 in a second place.

**Files.** `src/systems/quest/quest_tracker.gd` (114 -> 126 code lines) ·
`tests/framework/fixture_content.gd` (+1 helper, +7 consts, 182 -> 202) ·
`tests/unit/quest_chain_test.gd` (new, 55 code lines, 8 assertions) · the `CASES` entry ·
`project.godot` and `docs/CHANGELOG.md` for the bump. No new signal, no new autoload, no new
registry, no CSV row — there is no player-facing text in a re-entrancy fix.
**2,051 -> 2,059 assertions.**

**TWO FIXTURE QUESTS COVER BOTH SCAN ORDERS, WHICH IS WHY THERE ARE NOT FOUR.** `chain_lead` and
`chain_next` are the same shape — a flag to start, one step, a flag to finish — so which one is
the DEPENDENT is the test's choice. Making `next` the trigger puts the dependent FIRST in the
scan (adversarial); making `lead` the trigger puts it second (benign). The scan order itself is
**asserted, not assumed**, because `ContentScan` does not sort and "lead is first" is an
observation about this machine: if it ever stops holding, the two blocks quietly swap meaning and
both test the benign case. That assertion is the thing standing between this case and gotcha 44.

**PROVED RED, THEN GREEN, WITH THE REAL FAILURE SHAPE (gotcha 23).** Planting the original bare
`return`: exit 1, `2058 passed, 1 failed`, failing on
`the dependent scanned BEFORE its trigger started anyway — expected 1, got 0` while *"the trigger
completed"* and *"the listener fired once"* both still pass — the mechanism, not a symptom.
**Exactly 1 of 8 failed**, which is the load-bearing number: the benign order passes while the
defect is live, so a case that had happened to test only that order would have looked like proof.
Control restored: `2059 passed, 0 failed`, exit 0.

**Ladder, all green.** `--import` with zero `SCRIPT ERROR`/`Parse Error` lines; boot
`0 warnings, 0 errors`; suite `2059 passed, 0 failed, 0 skipped` with `quest_chain_test 8/8`;
`check_budgets`, `check_content`, `check_boundary`, `check_strings`, `check_layers`,
`check_signals`, `check_methods` all exit 0.

**Deferred, with reasons, not silently.**
- **The drain's pass bound is unasserted**, and the case says so in its header. No listener this
  template can construct reaches it — a flag-per-flag listener recurses through the signal before
  the drain is re-entered, and a quest completes at most once. Asserting it would need a probe
  fabricating a state the system cannot reach, which proves the probe.
- **A re-entrant call inherits the outer pass's `announce`.** Correct for the one caller that
  passes false, and a coincidence rather than a rule. Stated in `DEVLOG.md`.
- **No gate.** Gotcha 72 names the tell — ask whether the caller wanted a RETRY or wanted to be
  REFUSED — and that is prose. A gate would have to understand intent.
- **`ROADMAP.md` untouched.** No exit criterion covers a defect fix and inventing one to tick is
  what T5.1 spent a package undoing.

**Commit:** `4d101b2` on `claude/t5-16-quest-chaining`, PR #45, targeting `main`.

---

## T5.18 · The save loader's refusals, and a path nothing can enter — **DONE**

**2026-09-07. Version 4.3.0, a MINOR. `save_system.gd` is byte-identical to `main`** — `git diff`
on it is empty, so this row is 17 assertions and one corrected claim in the record.

**WHY THIS ROW AND NOT THE TAXONOMY, which inverted the analysis's own ranking.** The audit that
produced T5.16 ranked the template-default vs game-choice taxonomy first, because it decides the
scope of three other rows. That is still true and the row is still there. It lost on one point:
**prose cannot be proved by running the engine**, and non-negotiable #1 is that nothing is done
until the engine has run it. The save loader won on four counts nothing else on the list combines:
a false DONE in the record, the only candidate that can lose a player's data, provable by running,
and independent of the unanswered taxonomy question.

**WHAT WAS ACTUALLY UNASSERTED, MEASURED RATHER THAN ASSUMED.** `core_test.gd` owns the round trip
and covered exactly one refusal, an empty slot. `grep -rn ERR_FILE_CORRUPT tests/` returned
**nothing**, and no test anywhere had ever written a malformed save file. Six branches were carried
by review: a file that is not JSON, a missing `version`, a save from a newer build, a
non-Dictionary section, a section predating per-section versioning, and a section absent entirely.

**THE DISTINCTION THE CASE EXISTS TO PIN IS A POLICY.** A corrupt ENVELOPE is refused outright; a
corrupt SECTION is logged and skipped while the rest of the save loads. That is the difference
between a player losing a setting and a player losing forty hours, it was implemented correctly,
and it was asserted nowhere — so nothing stopped a later change collapsing the two into each other.
Each skip block asserts BOTH that the load returned `OK` and that the applier was never called,
because those are different claims and only the second answers *was the bad section skipped*.

**`_migrate`'s SUCCESS PATH IS UNREACHABLE, AND IT IS ARITHMETIC.** It is called only when
`version != SCHEMA_VERSION`, then refuses `from_version <= 0` and `from_version > SCHEMA_VERSION`.
At `SCHEMA_VERSION == 1` **no integer is all three of not-one, above-zero and at-most-one**, so the
path — including its `"Migrated save from v%d to v%d"` line — cannot be entered by any file a
player can have. That is not a defect: there are no migrations at v1, and the comment telling a
future author where to add one is right. **The defect was the RECORD.** `SYSTEMS_INVENTORY.md`
said migration was DONE, which reads as *exercised* and meant *written* — the eighth appearance of
declared-and-not-reached, and the first where the thing unreached is a control-flow path rather
than a field, a signal or a method.

**AND IT EXPIRES BY ITSELF, which is the half worth copying elsewhere.** The case asserts the
version boundary exhaustively — `-1`, `0` and `2` refused, `1` loads — and then PINS
`SCHEMA_VERSION` to 1. A v2 schema gives `_migrate` its first reachable success case and in the
same stroke makes that exhaustive block incomplete, so the suite fails with *"SCHEMA_VERSION is
still 1, so _migrate has no reachable success path"* at exactly the moment a migration test first
becomes possible. Same shape as `check_signals.gd` failing a `NO EMITTER` exemption that acquires
an emitter: gaining what the exemption excuses is itself the failure, so it cannot rot.

**Files.** `tests/unit/save_recovery_test.gd` (new, 81 code lines, 17 assertions) · the `CASES`
entry · the Save system row in `SYSTEMS_INVENTORY.md` · `project.godot` and `docs/CHANGELOG.md`
for the bump. **No production code, no new signal, no new autoload, no CSV row.**
2,059 → **2,076 assertions**.

**PROVED RED TWICE, IN OPPOSITE DIRECTIONS (gotcha 23, and gotcha 42's reason for insisting).**
These assert EXISTING behaviour and passed on the first run, which on its own proves nothing.
(1) The `from_version > SCHEMA_VERSION` guard deleted: exit 1, `2074 passed, 2 failed` — *"a save
from a newer build is refused — expected 16, got 0"* and *"one past the schema is refused"*, the
second being the exhaustiveness block catching it independently of the block written for it.
(2) The non-Dictionary section's `continue` changed to `return ERR_FILE_CORRUPT`: exit 1, `2075
passed, 1 failed` — *"a section that is not a Dictionary does not fail the load — expected 0, got
16"*. **The opposite sign is the whole point**: a case that had confused refuse-the-file with
skip-the-section would pass one plant and fail the other. Control: `2076 passed, 0 failed`, exit 0,
with `git diff src/core/save/save_system.gd` empty.

**Ladder, all green.** `--import` with zero `SCRIPT ERROR`/`Parse Error` lines; boot
`0 warnings, 0 errors`; suite `2076 passed, 0 failed, 0 skipped` with `save_recovery_test 17/17`;
all seven checkers exit 0.

**FOUR TAGS, AND WHY NOT ONE.** The base declared `4.2.1` while the newest tag was `v1.0.1`, three
MAJOR bumps back — and a MAJOR is precisely what `UPGRADING.md` tells a consuming game it must read
before merging. Tagging only the tip would have left those three reachable solely by grepping
history; `git diff v3.0.0..v4.0.0` now shows a fork what broke. Each was verified against T4.3's
condition first — `git show <commit>:project.godot` must declare the version the tag claims — and
all four did, and all four are ancestors of `main`.

**Deferred, with reasons, not silently.**
- **`SAVE_DIR` is a `const` with no redirect**, unlike the five content roots `Fixtures` repoints,
  so this case writes a real slot in the developer's own `user://saves` and deletes it on every
  path, as `core_test.gd` already does. On the candidate list; `save_system.gd` has 14 lines of
  budget left, so it is genuinely small.
- **A write that fails mid-flight is unasserted.** `_write_atomic`'s error branch needs a read-only
  directory or a full disk, which no assertion can arrange portably. Named on `export_test.gd`'s
  precedent rather than left implied.
- **`slot_info()` parses the WHOLE file**, and `latest_slot()` does it for six slots on every menu
  build. Same audit; untouched here because it is a performance change to a file with 14 lines
  spare and deserves its own row.
- **No windowed capture.** Nothing here is visual — every claim is a return code or a call count,
  so the honest ladder for this row ends at the suite.

**Commit:** `edcc869` on `claude/t5-18-save-recovery`, PR #47, targeting `main`.

---
## T5.22 · A redirectable `SAVE_DIR` — **DONE**

`5.2.0`, a MINOR. **The suite was writing into the developer's own save directory, and the save
store was the last content root that still could.**

`tests/framework/fixtures.gd` repoints five content roots — `ITEM_DIR`, `DIALOGUE_DIR`,
`SCHEDULE_DIR`, `QUEST_DIR`, `AREA_DEF_DIR` — under `user://test_fixtures`, so a run reads fixture
content instead of the game's. The save store was the sixth root and the only one left out,
because `SaveSystem.SAVE_DIR` was a `const`. Two cases wrote real slots through it:
`save_recovery_test.gd`, whose entire purpose is writing MALFORMED save files, and
`core_test.gd`'s round trip.

### Why "it cleans up after itself" was not an answer

Both cases delete what they write, on every path including the failing ones. That is careful, and
it is not the same as never having written the file. The run that fails to clean up is by
definition the run that crashed, which is the run you least want leaving a corrupt `slot_00.json`
in a directory a person's actual game reads. And the slot numbers the suite picks — `MAX_SLOTS - 1`
in `core_test.gd`, a slot of its own in `save_recovery_test.gd` — are slot numbers a player may
have filled.

### The shape, and why the seam is public

`const SAVE_DIR` became `const DEFAULT_SAVE_DIR` plus `var save_dir`, whose setter calls
`_ensure_dir()` so assigning creates the directory and no caller has to remember to. `_ready()`
calls the same helper, so boot and redirect share one path rather than two that can drift.

It is **public rather than test-only** deliberately. The alternative was a test-only injection
point on `SaveSystem`, and `fixtures.gd`'s own header already argues that case and refuses it:
engine code carrying a backdoor that exists for the suite and for nothing else. The same seam is
one a game legitimately wants — a portable build writing beside its executable rather than into
`user://` — so exposing it costs nothing that was not already going to exist.

`tests/framework/save_fixture.gd` is new and mirrors `Fixtures`: `activate()` / `deactivate()` /
`is_active()`, emptying the scratch directory on the way IN as well as out, because the run that
failed to clean up is the run that crashed. `test_runner.gd` calls `SaveFixture.deactivate()`
after every case unconditionally, next to the existing `Fixtures.deactivate()` and for the reason
that call already states.

### The budget, checked before the row was started

`save_system.gd` has an OVERRIDE of 180, not the 250 default, and stood at 166. The redirect cost
six lines and it is now 172. That was measured first, because the row's own justification said it
was "genuinely small" and a design that did not fit would have been a signal rather than a reason
to raise the override — which `check_budgets.gd`'s header forbids in as many words.

### Assertions, and the plant that passed

`tests/unit/save_dir_test.gd` is new, 18 assertions, split by QUESTION on T5.7's precedent:
`core_test.gd` asks *does a good save survive*, `save_recovery_test.gd` asks *what happens to a
bad one*, and this asks *which directory did it go in*. Neither of the other two should be
asserting anything about a directory.

The "real" directory in these assertions is a SECOND scratch one. The honest claim is "a write
while redirected does not touch the directory that was in force before it", and asserting that
against `user://saves` would be asserting about the developer's disk: the case would pass on a
machine where the slot happened to be filled and fail on one where a real save collided. Two
scratch directories make the same claim deterministic, and nothing in the case writes to
`user://saves` at all — which is the row.

**The first version of the load-bearing case passed the plant.** It took a copy of the stand-in
file, wrote again while redirected, and compared the two byte-for-byte. The full reversion — every
use of `save_dir` put back to the constant — passed it. Both writes landed on the same path inside
the same second, and the only fields that vary are `saved_utc`, second-resolution, and
`playtime_seconds`, which `snappedf` rounds to a tenth: the overwrite was byte-identical to what
it overwrote. The two saves now carry different markers through the probe's section, and the
assertion is that the earlier file still carries the first and does not carry the second.
**Gotcha 74**, and it is gotcha 70 one turn on: 70 says a plant that passes is evidence about the
plant, 74 says a plant that passes against an edit you have *confirmed* applied is evidence about
the case.

### Plants

| Plant | Fails | Exit |
|---|---|---|
| control, no plant | 0 of 2,192 | **0** |
| `slot_path` alone back to the constant | 17 | **1** |
| every use of `save_dir` back to the constant, the full reversion | 4 | **1** |
| `SaveFixture.deactivate()` removed from `test_runner.gd` | 3 | **1** |

The first plant is recorded because it is instructive rather than good: reverting only
`slot_path` makes the write FAIL — `_write_atomic` still opens the redirected directory, so the
rename has nowhere to land — which is a louder failure than the one the row is about. The full
reversion is the honest one, and the two fail different sets.

### What this did NOT touch

- **`slot_info()` parses the WHOLE file**, and `latest_slot()` does it for six slots on every menu
  build. Named by T5.18 and deliberately left again: it is a performance change to a file with
  eight lines spare, and it has its own row.
- **No windowed capture claim.** The capture was run and is green, but nothing here is visual —
  every claim in this row is a path, a return code or a file's contents.

**Commit:** `8cd80fb` on `claude/t5-21-save-dir`, PR #53, targeting `main`. **The branch name
says 21 and the package is 22** — the numbering collision this row records happened after the
branch was cut, and the branch was never renamed. The in-tree record is authoritative; see
`CONVENTIONS.md`.

---
## T5.21 · A scene-level interaction test, and the defect it found — **DONE**

`5.1.0`, a MINOR. **The row existed because another file asked for it in writing.**
`interaction_test.gd`'s MUST NOT line has read since WP-02 that the sensor's ranking *"needs real
geometry and belongs in a scene-level test"* — an accurate note about a test that was then never
written, and the four phases since never came back to it.

### What was actually unasserted

The ranking is the rule every interactable in the game rests on, and the sensor's own header
calls it the actual problem the file solves: *"Detection is trivial; selection is not."* None of
it had an assertion:

- **priority over proximity** — the case the header names, a player facing a lever with a sign
  fractionally closer;
- **proximity between equal priorities**, and **the facing term** on top of it, including whether
  velocity reaches `_facing` at all;
- **the name tie-break**;
- **what leaves the RANKING without leaving the candidate set** — out of reach, and present but
  inert;
- **the Tab cycle and its wrap**, which is the player's override of every one of the above.

And `Speaker` and `Readable` — two of the eleven prefabs `AUTHORING.md` tells a consuming game to
place — had no scene-level assertions of any kind. `turn_test.gd` asserts the turn a `Speaker`
asks for, which is a different question from whether it can be selected in the first place.

**This is gotcha 54's shape at the top of the interaction stack.** `interaction_test.gd` proves
what an object does once it is chosen; `turn_test.gd` proves the turn once it is. Between them sat
the decision neither one makes, with a green assertion on either side of it.

### The defect, found on the first run — gotcha 73

`_select()` broke a scoring tie with `a.name < b.name`, under a comment promising that *"ties are
broken by node name so the order is stable frame to frame rather than dependent on physics
callback order."*

`Node.name` is a `StringName`, and `<` on two `StringName`s compares their **interned addresses,
not their text.** Measured both ways inside one run, on the same pair of names:

```
TIE StringName Z<A=true A<Z=false | String Z<A=false A<Z=true
```

So ties were ordered by whichever name the engine happened to intern first, which is script and
scene load order.

**The comment was not wrong, only half true, and that is why it survived eight rungs.** An
interned address does not move while the node lives, so the order genuinely IS stable within a
run and the frame-to-frame flicker the comment worried about never happened. What was false is
that it was ever the NAME: an author numbering two overlapping objects `sign_a` and `sign_b` to
choose between them was ignored, and because intern order is load order, the same two objects
could tie differently when reached another way. 2,148 assertions were green over it because the
demo has no two interactables at an exact tie. The fix is one cast,
`String(a.name) < String(b.name)`.

**And the first probe of the comparison said the language was innocent.** A standalone `--script`
probe created two nodes, compared their names and printed alphabetical order — so the defect
looked like a broken fixture and very nearly was recorded as one. It agreed by coincidence: with
only those two names interned, their addresses happened to fall in alphabetical order. That is
**gotcha 70 turned around** — there a plant PASSED and was evidence about the plant; here a probe
passed and was evidence about the probe. A probe of an ORDERING has to run in the context whose
order is in question, because the property belongs to the process and not to the two values.

### `InteractionSensor.cycle()`, and why the test could not press Tab

The cycle lived inline in `_handle_input` behind `Input.is_action_just_pressed`. The suite is
synchronous — `run()` is called, not awaited — and two facts were measured rather than assumed:

- `Input.parse_input_event` is **buffered** until a main-loop flush that never comes mid-run, so
  the action reads back `pressed=false` immediately after the call;
- `Input.action_press` **does** land, but the process-frame counter never advances inside one
  `_ready()`, so the action then reads `is_action_just_pressed() == true` for the **rest of the
  run** — and `turn_test.gd` also drives a sensor with more than one candidate, so that stuck key
  would cycle its selection too.

So the override was genuinely unassertable through input. It is now a public `cycle()` returning
false when there is nothing to cycle to, called by `_handle_input` on the keypress — the same
reasoning that already made `is_suspended()` public, in that method's own words: so a test can
assert the hand-over without faking input. The **binding** is still proved windowed, by
`dev_stage.gd --cycle`.

### Verification

Twelve rungs, seven checkers, all green. Suite **2,148 → 2,173**, exit 0.

**Five plants, each failing a DIFFERENT set**, which is what says they are not one assertion five
times rather than five:

| Plant | Result |
|---|---|
| tie-break reverted to `a.name < b.name` | exit 1, **3 failed** |
| the authored-priority term deleted from `_score` | exit 1, **1 failed** |
| the facing term deleted from `_score` | exit 1, **1 failed** |
| `_select` returns `ranked[0]`, ignoring the cycle offset | exit 1, **4 failed** |
| `cycle()`'s lone-candidate guard removed | exit 1, **1 failed** |

Each was reverted and the suite re-run to `2,173 passed, 0 failed`, and the source confirmed
byte-identical to before the plant. Per gotcha 70 the source was checked as genuinely modified
before each run was trusted.

### Notes, and what is deliberately not here

- **The distances are fractions of `max_distance`, never metres.** It is an `@export`, so a
  consuming game that gives the player longer arms must not fail this file — and a case that
  wrote `1.0` would.
- **The tie case hands its two objects over in REVERSE name order.** That is the half that can
  fail: a sort that had quietly become a no-op returns the first candidate, and with candidates
  arriving in name order that is the same answer the rule gives.
- **The cycle case's last assertion is the one with teeth.** `_physics_process` re-selects every
  frame, so a cycle offset reset there would take the player's deliberate choice back one frame
  later while the four assertions above it all still passed.
- **A windowed capture was taken** and is not load-bearing: nothing here is a visual claim. It
  shows the demo still boots and the prompt still reads a real selection at dusk.
- **The keybinding itself is still not in the suite**, and cannot be, for the reason above. Named
  rather than left implied.

**Commit:** `ab5ebbf` on `claude/t5-20-selection-test`, PR #50, targeting `main`, plus `b5821ca`
which renumbered the package T5.20 → T5.21 and the version `4.4.0` → `5.1.0` when it was rebased
onto the T5.19/T5.20 stack, and `0f93951` recording its CI run. **The branch name says 20 and the
package is 21**, for the same reason as T5.22 and with the same answer.

## T5.24 · The roadmap's missing run, and whether completeness should be gated — **DONE**

`5.3.1`, a PATCH. `src/` and `tools/` byte-identical; the only non-documentation change is
`project.godot`'s `[template] base/version`.

### What was wrong

`docs/ROADMAP.md`'s Phase T5 package log ran T5.15 and then T5.21. **T5.16, T5.17, T5.18, T5.19
and T5.20 were absent** — five delivered packages, each with a DEVLOG entry and a board row and a
version bump of its own, and no trace at all in the file `CLAUDE.md` sends a reader to for "where
things stand". T5.21 recorded the gap. T5.23 recorded it again and promoted it to the top of
`CONTEXT.md`'s next-package list. Neither closed it, and **nothing was red, because nothing
counted the rows.**

### The decision, which was the actual package

**Gate it, in `record_shape_test.gd`, as one more findability assertion.**

T5.19 is the precedent and not an analogy. That row exists *because a third manual reconcile was
the wrong answer* — its own words — and its argument for gating structure transfers here with
nothing changed: a file either opens with its title or it does not; a package either has a row or
it does not; **neither question has a reading, an interpretation or a tone, which is exactly why
they are assertable when the sentences around them are not.** "A package the DEVLOG records has no
entry in `ROADMAP.md`" is that same shape, and it is the same file's business — so it went in
beside the board check rather than into a fourth case, which is what `CLAUDE.md` rule 4 asks and
what T5.19's own MUST NOT line permits.

### The counter-argument, which was real

**The roadmap's package log IS legitimately selective in a way the board is not.** The board has
one shape — a row per package. The roadmap has three, and uses all of them: a package-log row
under a phase; a tick beside an exit criterion; a parenthesis in a phase's Done list. **T5.14 is
only ever the second of those** — it has no package-log row anywhere and is nonetheless recorded
at length beside the criterion it closed. A gate demanding a package-log row would have failed a
package that is thoroughly recorded, which is the objection landing.

**It is answered by the shape of the check rather than by overruling it.** The assertion is
`roadmap.contains(id)` — findability — which is the identical choice T5.19 made one function above
for the board, and its reason there was written down: *"the gate asserts a package is FINDABLE on
the board, not that it has an index row, because 'findable' is the property that matters and a
stricter rule would have failed eight packages that are genuinely recorded."* The roadmap may
record a package in whichever of its three shapes fits. It may not omit one entirely.

**And T5.16 had declined to touch the roadmap in writing**, which is the strongest-looking
objection because it is a considered refusal by a package rather than an oversight: *"no exit
criterion covers a defect fix, and inventing one to have something to tick would be the
ticking-without-proving this project spent T5.1 undoing."* That is right about the CRITERIA list
and says nothing about the package LOG, which is a different list in the same file answering a
different question — where a package sits in the plan, not whether a phase may close.
Distinguishing the two is what makes this assertable rather than a matter of editorial taste, and
it is why the fix for T5.16 is a log row and **not** a new criterion.

### The plant was the live repository, and the follow-ups found the gate's limit

The assertion was written and run **before a single document was edited** — the strongest form of
plant available and the one form neither gotcha 74's nor gotcha 75's failure mode can reach, both
being failures of a *fabricated* condition. Nothing was fabricated, so the red run cannot have
failed for a fabrication's reason.

```
=== 2266 passed, 6 failed, 0 skipped ===   exit 1
FAIL WP-07 is findable in the roadmap — expected true, got false
FAIL T5.16 is findable in the roadmap — expected true, got false
FAIL T5.17 is findable in the roadmap — expected true, got false
FAIL T5.18 is findable in the roadmap — expected true, got false
FAIL T5.19 is findable in the roadmap — expected true, got false
FAIL T5.20 is findable in the roadmap — expected true, got false
```

**Six, not five, and the sixth is the argument.** **WP-07 — path actions, the signature
non-combat mechanic, `PathAction` and `PathActionPoint` and the whole refusal-versus-failure
design — has been missing from `ROADMAP.md` since 2026-08-26.** Two packages recorded this gap by
reading the file, and both counted five. That is the case for a gate over a third reverse-count,
delivered as a measurement rather than as a prediction.

**THEN THE FIRST TWO PLANTS OF THE GREEN DIRECTION PASSED, AND THAT IS GOTCHA 76.** Deleting
T5.19's whole package-log row left the suite green: two other rows mention T5.19 while saying
something else, and `contains` is true of either. Re-planted on T5.18 it passed **again** — this
row's own new entry names all five reconciled packages while explaining what was missing, so
deleting T5.18's row left it findable inside the sentence describing its absence. **A row that
records a gap is a cross-reference to every id in the gap**, and a reconcile package invalidates
its own plants as it works. The plants moved to ids the file names exactly once, counted on the
finished tree:

| Plant | Result |
|---|---|
| The live repository, assertion added, no document touched | **exit 1** — `2266 passed, 6 failed`, one per missing package, each named |
| T5.19's whole package-log row deleted | **exit 0, GREEN** — gotcha 76: two incidental mentions elsewhere satisfy `contains` |
| T5.18's row deleted | **exit 0, GREEN** — gotcha 76 again, from this row's own entry naming T5.18 |
| WP-07's Done line deleted, before this row had a log row of its own | **exit 1, 2 failed** — `WP-07` **and `T5.24`**: how the row found its own only trace was an aside in the line it had just written. Fixed by giving it a real log row |
| T5.13's package-log row deleted — its sole mention | **exit 1** — `FAIL T5.13 is findable in the roadmap`, **exactly 1 of 2,274** |
| WP-05's Done-list parenthesis deleted — its sole mention | **exit 1** — exactly 1, and from a DIFFERENT recording shape, which proves the check is indifferent to shape |
| T5.20's row deleted AND its cross-reference in this row's entry removed | **exit 1** — exactly 1: the two-edit form of the plant that passed above |
| Control, fully reconciled | **exit 0** — 2,274 passed |

**Exactly 1 failure on each of the last three is the load-bearing detail**, not the exit code: it
says the six in the first row are six independent facts rather than one assertion reported six
times.

### Notes, and what is deliberately not here

- **THE GATE CANNOT TELL A RECORD FROM AN INCIDENTAL MENTION — gotcha 76, and it is written down
  rather than engineered away.** The alternative is a gate on recording SHAPE, which fails T5.14
  for being recorded beside its criterion instead of as a row, so the weaker check is the correct
  one. The consequence is a plant rule, not a code change: count an id's mentions before planting
  on it, and count again after your own edits.
- **Gotcha 75 was named in T5.23's DEVLOG entry and never added to the list.** Both 75 and 76 are
  entries now. `doc_counts_test.gd` could not have caught it and its header says why — it owns the
  agreement between the list's LENGTH and the documents stating it, and 74 entries against four
  claims of 74 was internally consistent. A gate on "every gotcha number a DEVLOG entry
  cites exists in the list" is a cross-reference rather than a count, and needs its own case.
- **The roadmap's T5.22 row sits AFTER its T5.23 row, and that was left alone.** The gate's MUST
  NOT line forbids asserting the ORDER of anything, and reordering a hundred-line block inside a
  package about completeness would be churn wearing a fix's clothes. Named here rather than left
  for a reader to find.
- **One thing was fixed in passing and is small enough to say in a line**: this file's detail
  heading for the scene-level interaction test read `## T5.20 ·` over T5.21's content. The row and
  the entry both say T5.21; the heading was a typo, and the gate could not see it because
  `contains` finds T5.20 elsewhere.
- **This does not gate the roadmap's TICKS, and cannot.** Whether an exit criterion is honestly
  ticked is exactly the prose judgement T5.17's sentence is about, and T5.1 is what happens when
  it goes wrong. The gate says a package is recorded, never that the record is true.

**Commit:** `ad80ce9` on `claude/t5-24-roadmap-gate`, PR #55, targeting `main`.

---
## T5.25 · The gate that could not fail, and the numbers nothing was measuring — **DONE**

**The defect, stated as the assertion it defeats.** `record_shape_test.gd` asked
`roadmap.contains(id)` and `board.contains(id)`. `String.contains` is a substring test, so for any
id that is a prefix of a longer id the question being asked was not "is this package recorded" but
"is some package whose id starts with these characters recorded". Four ids in this repository are
such prefixes:

| id | satisfied by | so deleting its every genuine trace left the suite |
|---|---|---|
| `T5.1` | `T5.10`–`T5.19` | green |
| `T5.2` | `T5.20`–`T5.24` | green |
| `WP-09` | `WP-09b` | green |
| `WP-14` | `WP-14b` | green |

**Why this is not simply gotcha 76, which T5.24 already recorded.** 76 says findability is
satisfied by an incidental cross-reference — a sentence in another row's prose counts as a trace.
That is a judgement call about what "recorded" should mean, and the gate's MUST NOT line
deliberately declines to make it. This is different in kind: the assertion was **comparing against
a string that is not the id**, so no judgement about traces was involved and no amount of
tightening what counts as a trace would have found it. The two also differ in who they endanger —
76 affects any package, while this affected precisely the four oldest ids in each family, whose
rows are furthest up the file and least likely to be missed by a reader.

**Why the live repository could not be the plant, and what replaced it.** T5.24's strongest claim
was that its plant was the repository itself: the assertion was written, run, and failed on six
real packages before a document was edited. That shape is unavailable here, and the reason was
measured before the change was written — all 52 recorded packages satisfy the word-boundary form
in both files, so tightening the check turns nothing red. A gate that is green before and after is
exactly the shape gotcha 70 warns about, so the row needs a deletion, and needs the *comparison*
run as well:

| run | gate | plant | result |
|---|---|---|---|
| A | word boundary | none | `=== 2274 passed, 0 failed, 0 skipped ===`, exit 0 |
| B | word boundary | `T5.2`'s seven roadmap traces renamed | `=== 2273 passed, 1 failed ===`, exit 1, `FAIL T5.2 is findable in the roadmap — expected true, got false` |
| C | **original `contains()`** | **the same plant** | `=== 2274 passed, 0 failed ===`, **exit 0** |

**C is the run that carries the row.** A and B alone are also consistent with a gate that was
already working correctly; only C shows the old check was blind to the same deletion. One failure
rather than several is the second thing B proves — the board half still passes, because the plant
removed the id from the roadmap only.

**The record half, and why it is in the same row rather than its own.** The plan was to fix a
gate; the numbers were found while measuring for it, and a package that re-measures the suite to
write one number and leaves five other documents quoting older ones would be the thing T5.19
exists to have stopped. Every replacement came off a recorded run, not off another document:

| file | claimed | measured |
|---|---|---|
| `README.md` | 555 assertions | 2,276 |
| `CLAUDE.md` | DEVLOG "over 5,400 lines"; `2,173 assertions` | 8,986 lines; 2,276 |
| `docs/TESTING.md` | `1625` full / `1551` stripped | `2276` full / `2202` stripped, from CI run `34317589462` |
| `docs/ARCHITECTURE.md` | 2,173 assertions in the rung table | 2,276 |
| `docs/CONTEXT.md` | 166 files, 15,552 code lines | 167 files, 15,793 |

**And two contradictions inside `CONTEXT.md`**, the file `CLAUDE.md:5` sends every session to
first: "the base is 5.0.0-complete" nine lines above "**The version is** **5.3.1**", and "Phase
T5's second-idle box is the one that still stands open" fourteen lines above "**Phase T5 has no
unticked exit criterion** — T5.23 took the last one". The first survived `version_test.gd` because
that gate reads only **bold** semvers and `5.0.0-complete` is unbolded — an ungated shape beside a
gated one, which is T5.19's lesson recurring rather than a new kind of defect. The completeness
sentence was rewritten to name the phase rather than a version, because a version is not a
completeness state and pinning one there is what made it rot.

**Also in this row.** `ROADMAP.md`'s T5.22 log row was the only one in the file with no date and a
non-conforming header, and it sat AFTER T5.23's row — both self-declared in T5.24's DEVLOG entry
and both left; reformatted and moved, and its missing `save_dir_test.gd` / 18 assertions added, a
detail every other row in the run states. T5.24's own entry claimed the five absent packages each
had "a version bump of its own"; T5.17 changed no code and left the tree at `4.2.1`, so the claim
was narrowed.

**What is NOT gated, and the measurement behind that.**
- **The `**Commit:**` lines.** All nine are now written for T5.16–T5.24. Only **15 of 52**
  packages carried one, so an assertion would fail 37 historical rows; scoping it to "T5.16
  onward" is the rotting exception list `HEADING_PATTERN`'s own header refuses to become, and
  backfilling 37 rows of commit archaeology is not this row. Recorded as a gap.
- **The suite's own total.** Still ungated for T5.19's reason, which has not changed: a case
  cannot know the suite's final total while the suite is running. This row's `2,276` is review's
  problem like every one before it.
- **The branch names.** `CONVENTIONS.md` now states the pattern and the load-bearing line — the
  branch name is not authoritative, the in-tree record is. Deliberately no gate: a branch is cut
  before the work is understood, and renaming one mid-stack moves the base of every PR above it,
  which is exactly why `claude/t5-21-save-dir` still carries T5.22.

**Commit:** `03a097c` on `claude/t5-25-record-reconcile`, PR #56, targeting `main`, plus `7dc5f63`
recording its CI run. **This line shipped without its SHA** — it was written before the commit
existed, which is the one ordering the closing checklist cannot avoid, and T5.26 filled it in.

---
## T5.26 · The ladder's own gate could not see an unwired checker — **DONE**

**The defect, in the file's own words.** `gates_test.gd`'s header: *"This is the assertion that
would have caught a gate written, committed, and never wired — which is the defect the whole
package is about, applied to the package itself."* It could catch neither shape of that.

| shape | why it passed | now |
|---|---|---|
| an eighth `tools/check_*.gd` never wired | `LADDER` is a const of seven and nothing said it named all of them | the list is derived from `tools/` |
| a checker named only in a `#` comment | `workflow.contains(checker)` is true of a comment | invocations counted: a non-comment line with the path and `--script` |
| a checker in the full job, absent from the stripped one | `contains` returns one bool for the whole file | the count must equal `JOBS.size()` |

**The comparison run is the evidence, and it is the same shape T5.25 needed.** The tightened
assertions are green on the live tree, so a run before and a run after prove nothing on their own.
Commenting out **both** `run:` lines for `check_signals` — leaving it running in neither job, its
name still in the file twice as comments:

| run | gate | plant | result |
|---|---|---|---|
| A | invocation count | none | `=== 2285 passed, 0 failed ===`, exit 0 |
| B | invocation count | both `check_signals` steps commented out | `=== 2284 passed, 1 failed ===`, exit 1, `expected 2, got 0` |
| C | **original `contains()`** | **the same plant** | `=== 2276 passed, 0 failed ===`, **exit 0** |

**C is the row.** A checker running in neither job of the ladder, and the ladder's own gate said
fine.

**The runs read 2,285 and the finished tree reads 2,287, and both are right.** They were measured
before this row's DEVLOG entry existed; writing it added a package id, and `record_shape_test.gd`
scores one board row plus one roadmap row per recorded package on a computed plan, so a new entry
is +2. This file warns that a closing doc commit can move the total — here it moved it by two,
predictably.

**Two further plants, each a different failure.**
- The **stripped job's step alone** removed: `expected 2, got 1`. This is the shape that matters
  most in practice, because a full-job-only checker looks wired to anyone reading the first half
  of the workflow — and the stripped job is the half that proves the template stands up with no
  game present.
- An **eighth checker written and unlisted**, `tools/check_planted.gd`:
  `is listed in LADDER, so it is checked at all — expected true, got false`. That run's total rose
  by one on its own, which is the computed plan proving itself in passing.

**Why the count is asserted against `JOBS.size()` and the job names are asserted too.** A constant
compared against reality is only as good as the constant. `JOBS` is `["ladder", "stripped"]` and
each is asserted present as a job declaration, so a renamed or deleted job fails by name rather
than making every count below it quietly wrong — `dev_tools_test.gd`'s guard against a silently
empty extractor, applied to a const.

**Why the list is derived rather than listed.** `test_runner.gd` has scanned `tests/unit` for
files missing from `CASES` since T2.2, for this exact reason, and `check_boundary.gd` derives its
namespaces rather than naming them on the same argument. A list of what to check rots, and it rots
invisibly precisely where the list is the only thing standing between a gate and irrelevance.

**Gotcha 78, and deliberately not filed under 77.** 77 is that a substring test on an ID is
satisfied by a longer sibling; this is that a substring test on a CI FILE cannot tell a step from a
comment, and that a list is not a check on itself. Same underlying mistake — a gate reading a file
and not asking which parts of it are prose — in a second document one row later, which is why the
generalisation is written down rather than the instance.

**Scope.** One test file, +58 lines of which ~23 are code, `gates_test.gd` at 166 of its 250.
`src/`, `tools/` and `.github/` byte-identical. Suite 2,276 → **2,287**.

**What this row did NOT take, all of it found in the same audit and recorded rather than
forgotten:** rungs 5–11 read only the exit code with no `SCRIPT ERROR` grep and no log artifact,
so gotcha 24's innermost-frame abort can leave a checker under-scanning and still printing `PASS`;
`ladder.yml:363-373` asserts in prose that the two jobs "must report exactly the same numbers"
with nothing comparing them; no checker asserts its own scan was non-empty, 0 of 7, against a rule
`CHANGELOG.md` states for doc gates in as many words; and `Fixtures.activate()` is unchecked at 14
of 16 call sites against a shape `TESTING.md` spells out. Those touch `ladder.yml` and seven tools
and are their own rows.

**Commit:** `83c9fdd` on `claude/t5-26-ladder-gate`, PR #57, targeting `main`, plus `c14b24a`
recording its CI run. Filled in by T5.27 — the same ordering problem T5.26 named in T5.25's line
and then repeated, which is the argument for the closing checklist naming the follow-up commit
rather than pretending item 6 can be satisfied before the commit exists.

---
## T5.27 · A checker can skip a file and still print PASS — **DONE**

**The premise, measured with a throwaway probe rather than asserted.** Rungs 5–11 were bare
`run: godot --headless --script tools/check_*.gd` — exit code only, no log grep, no artifact —
while rung 4 has `ErrorWatch`. The question was whether that gap can actually hide anything.

```gdscript
for i: int in [1, 2, 3]:
    seen += _per_item(i)        # _per_item indexes an empty array when i == 2
print("  loop finished, items processed: %d of 3" % seen)
print("PASS")
quit(0)
```

```
SCRIPT ERROR: Out of bounds get index '9' (on base: 'Array[int]')
  loop finished, items processed: 2 of 3
PASS
exit=0
```

**Gotcha 24 exactly** — the error aborts the innermost frame, the loop finishes, one item is
silently unscanned, and the tool reports success. The exit code cannot see it.

**AND THE FIRST PLANT DID NOT SHOW THIS, WHICH IS WHY THE PROBE IS IN THE RECORD.** Injecting the
same error into `check_layers._scan_script` gave **exit 1** — the tool died rather than lying, so
the premise looked false and the CI grep looked unjustified. A minimal probe is what separated
"the tool dies" from "the tool continues and reports PASS". Gotcha 75's family: a plant that fails
for the wrong reason is as misleading as one that passes.

**The fix.** All fourteen checker steps now capture output to `check_<name>.log`, print it, and
force failure if the log carries `SCRIPT ERROR` or `Parse Error` even at exit 0. Seven logs
uploaded from both jobs. Each step still names its checker beside `--script` exactly once per job,
so T5.26's invocation gate is unaffected — verified, 2 per checker.

### Six checkers could pass on a scan of nothing

| run | tool | scan | result |
|---|---|---|---|
| control | `check_layers` | `res://src` | `scripts scanned: 105`, `PASS`, exit 0 |
| plant | `check_layers` **guarded** | `res://localization` | `scripts scanned: 0`, `FAIL — nothing was scanned`, **exit 1** |
| comparison | `check_layers` **unmodified** | `res://localization` | `scripts scanned: 0`, **`PASS`, exit 0** |

The comparison is the row: 0 of 7 tools guarded this while every one of them printed its own
scanned count. `CHANGELOG.md` has stated the rule for doc gates since `4.3.1` — *"a doc gate that
passes because it found nothing to check is worse than no gate"* — and it had never been turned on
the tools. The count is incremented in each collector, beside the `append`, so it cannot drift
from the scan it describes.

**`check_content` IS EXEMPT, AND THE EXEMPTION IS THE INTERESTING PART.** Its entire input is
`data/` and `scenes/areas`, which the stripped job **deletes on purpose**. Scanning nothing is a
legitimate state for that checker and for no other, so guarding it would fail the stripped job for
doing exactly what it exists to do. The other six read `src/`, `tests/`, `tools/` and
`localization/` — none of which the strip touches — so zero there is always a defect. This is the
first exemption in the run that comes from what the strip removes rather than from what a gate can
judge.

### A comment claimed a check nothing performed

`ladder.yml` said a stripped template **"must report exactly the same numbers"**, twice. The jobs
are independent and nothing compares their output; the claim had been true every time anyone
checked it by hand and was enforced by nothing. Reworded to state what *is* enforced — both jobs
must exit 0, which catches the failure mode that matters, an engine string that stops resolving
once the game is gone — and to name the real mechanism as a candidate: each job publishes its
counts, a third job diffs them. Recorded rather than implied.

**Scope.** `ladder.yml` and six tools; `src/` byte-identical. 167 files, 15,852 code lines.
**Suite 2,287 → 2,291, and not one of the four is an assertion this row wrote — the enforcement
here is not in the suite at all**, which is the first time that has been true in this run and the
reason the assertion total is the wrong measure of it. **Two came from the DEVLOG heading, as
predicted, and two were a surprise**: the plant table above quotes `res://src` and
`res://localization`, and `docs_test.gd` asserts that every `res://` path the documents name
resolves. Writing the evidence down added assertions about the evidence. Predicted +2, measured
+4 — which is the fifth time in this run that a number had to be read off a run rather than
reasoned to.

"**Also: `.gitignore` had no `*.log` pattern.** The workflow has written `import.log`, `boot.log`
and `tests.log` since T1.4, so running the ladder locally the way CI does has always left
untracked logs; this row took that from three filenames to ten and then fixed it. Nothing `.log`
has ever been tracked, so the pattern cannot orphan anything the repository depends on - checked
before adding it. Verified by writing a log and confirming `git status --untracked-files=all`
reports only the `.gitignore` change.

**Commit:** `217405c` on `claude/t5-27-checker-blindspots`, PR #58, targeting `main`, plus
`e87dd05` (the `*.log` ignore) and its CI record. Filled in by T5.28 — the third row running to
ship this line without its SHA, since item 6 asks for a commit that satisfying item 6 creates.

---
## T5.28 · A template rule, a template default and a game choice are three different things — **DONE**

**The row that was ranked first five times and never taken.** `TEMPLATE.md` § *"The one constraint
nobody has scoped"*, since 2026-08-26:

> What is missing is the distinction between a **template default** and a **game choice**, which no
> document currently draws.

`CONTEXT.md` deferred it every time for one honest reason — *"it is prose and cannot be proved by
running the engine"* — while also recording that it **"DECIDES the two rows under it rather than
guessing"**. Both of those rows carried *"Scope depends on the taxonomy row above"* and *"Also
gated by the taxonomy question"*. **So deferring the cheap row kept the expensive ones frozen, and
three candidate rows were unscopable indefinitely for want of one distinction.**

### The answer is three kinds, not two — which is what made it tractable

| Kind | A game… | Test | Recorded in |
|---|---|---|---|
| **TEMPLATE RULE** | cannot override it; wanting to is a fork | no seam, plus a checker where mechanical | `TEMPLATE.md`, `CLAUDE.md` |
| **TEMPLATE DEFAULT** | replaces the value through a seam, touching no `src/` file | **a seam exists** | `AUTHORING.md`, `[game]` |
| **GAME CHOICE** | builds it in its own code root | the base builds nothing | `OPTIONAL`, or absent with a reason |

**The test that separates a default from a rule is mechanical rather than editorial: does a seam
exist?** A "default" a game cannot replace without editing `src/` is a rule that has not admitted
it. "Is this a default or a rule?" was a matter of tone; "can a game replace it without editing
`src/`?" is a fact about the repository — and it is immediately productive. Applied to
`src/core/boot/game_root.gd:28`'s `const PLAYER_SCENE`, it says the player prefab is a **rule
pretending to be a default**, which is the next row.

### Applied, so the ADR decides rather than describes

- **RULES:** no combat; the layer rule; the demo-name boundary. The last two already have checkers,
  which is what a rule looks like once it can be mechanised.
- **DEFAULT:** time. `Clock`, `NpcSchedule` and `Weather` are already here, so a cycle above the day
  extends a present system rather than adding one. The base owns the facts; a game chooses numbers.
- **GAME CHOICES:** a chapter sequencer (a `story/chapter` int flag with `AT_LEAST` is already a
  complete chapter model for both authored surfaces, through the one `FlagQuery` — a `Chapter`
  resource would add a second way to say one thing) and an economy (genre, not structure, on the
  same footing as `Harvestables`/WP-10).

**Two candidate rows are closed by a refusal rather than built, and writing the refusal down is the
point.** Otherwise each is rediscovered, ranked, deferred for want of a reason, and ranked again —
which is what happened three times.

### The Cutscenes row needed a reason, not a package

It was the only `TODO` in `SYSTEMS_INVENTORY.md` with a blank boundary column. **A draft of this
row proposed building the staging seam, on the grounds that nine `cutscene` mentions across eight
files under `src/` were unpaid IOUs. Read in full, every one is a RECEIPT:**

| file | what it actually says |
|---|---|
| `dialogue_duck.gd:26` | "deletes nothing here — it calls `Audio.duck()` from its own occasion" |
| `surface_wetness.gd:21` | "keeping it out of here is what lets a cutscene soak one courtyard on demand" |
| `environment_driver.gd:10` | "forced by a cutscene, **without touching this file**" |
| `screen_fade.gd:6` | "a cutscene **can later ask for** the same fade" |
| `player_controller.gd:274` | the grounded rule deliberately not re-checked, so a cutscene may lift the player off a ledge |

Each is a statement that the file is **already** cutscene-ready and the consuming game supplies the
occasion. **Reading a comment as a debt is how a comment becomes a work package.** The row now has
a stated reason and a boundary line, and the base ships no sequencer and no cutscene resource — a
step enum would grow `GameEnums`, append-only because ordinals live in `.tscn` files, for a shape
every game authors differently.

### `Fixtures.activate()` is asserted, not skipped

Reverses what `TESTING.md` documented. **A skip reports GREEN**, so the one condition the check
exists to catch — a fixture root that could not be written — is the one condition nobody sees, and
the ten assertions below it would silently be testing the developer's own content root. That is the
same "passes because it found nothing" failure T5.27 guarded the seven checkers against *one row
earlier*, and `CHANGELOG.md` has called it worse than no gate since `4.3.1`.
`bag_mirror_test.gd` converted; **the plan gate caught the arithmetic before the suite did** —
`planned 10 outcomes and produced 11`, because an assertion is one outcome where a skip was a
substitute for ten. 14 of 16 call sites still discard the return, recorded rather than implied.

### No new gate, and saying so is part of the row

`record_shape_test.gd` asserts every document opens with its title and every recorded package is
findable in both the board and the roadmap; `docs_test.gd` asserts every `res://` path a document
names resolves. An ADR is covered by both. **Inventing a gate to have one is what T5.24–T5.27 spent
four rows learning not to do**, and this row's own subject is a distinction that is prose by nature.

**Scope.** `5.3.5`, a PATCH. One new ADR; `TEMPLATE.md`, `CONTEXT.md`, `SYSTEMS_INVENTORY.md`,
`TESTING.md` and the record; one test file. **`src/`, `tools/` and `.github/` byte-identical.**

**Commit:** `cc62f06` on `claude/t5-28-taxonomy`, PR #59, targeting `main`, plus `bb30e69`
recording its CI run. Filled in by T5.29 — the fourth row running to ship this line without its
SHA, which by now is evidence about the checklist rather than about four sessions: item 6 asks for
a commit that satisfying item 6 creates, and no amount of remembering fixes an ordering.

---
## T5.29 · The player prefab was a rule pretending to be a default — **DONE**

**ADR-0007 found this within an hour of existing, which is the row's best argument for itself.**

`src/core/boot/game_root.gd:28`:

```gdscript
const PLAYER_SCENE: String = "res://scenes/characters/player.tscn"
```

Engine code, in the **`core`** layer, naming the prefab a consuming game replaces first — with
`GameConfig` exposing exactly two `[game]` keys and no `player_scene` among them. `ARCHITECTURE.md`
states the contract as *"a game adds content and resources; it does not add code under `src/`"*, so
**a game with a differently-shaped protagonist had no legal way to get one.**

T5.28's seam test asks one question — **does a seam exist?** — and a "default" a game cannot
replace without editing `src/` is a RULE that has not admitted it. This is the first thing that
test caught.

### The comparison run is what makes it a defect rather than a preference

Same plant both times: `[game] world/player_scene` pointed at a scene that does not exist, then
boot headless.

| run | code | result |
|---|---|---|
| control | new seam, real path | `0 warnings, 0 errors`, player spawns |
| plant | new seam, missing path | **`1 errors`** — `Player scene missing or invalid at <the missing path>` |
| comparison | **old `const`**, same missing path | **`0 warnings, 0 errors`** — key silently ignored, player spawned from the const |

**The comparison is the row.** What was broken was not that the path was wrong; it was that
**setting it did nothing** — a game's stated choice discarded without a word. The plant only shows
the error path works; the old run shows there was no path at all.

### The fallback is the one asymmetry, and it is deliberate

`world/first_area` has none: a template nobody has put a game in yet legitimately starts in no
area, and `Director` reports that rather than loading nothing and going quiet. A game can never
legitimately have **no player**, so an unset key means the template's own prefab rather than
`load("")` and an empty world.

`scenes/characters/` is Engine per `TEMPLATE.md`, so `GameConfig` naming that path is **engine
naming engine** — not the boundary leak the `const` in `core` was. That distinction is the whole
reason the default may live in `src/` at all.

### What did not happen

**`game_root.gd` did not grow**: 26 of its 60-line hard budget before and after. Its header says
the file "may only do four things" and warns that the previous project's equivalent reached 3,983
lines; this row moved a path and added no logic. `GameConfig` went 26 → 32 of its 250.

### Two stale counts fell out of it

Both the class T5.25 spent a package on, and neither is gated:
- `GameConfig`'s own header claimed it owned *"the **four** facts a game author writes once and
  never changes."*
- `SYSTEMS_INVENTORY.md` claimed *"the **four** values a consuming game sets in project.godot."*

Five, now. And **`NEW_GAME.md` § 2 gained the one exception to "Keep, and never edit to start a
game"** — because a fork points *past* the template's prefab rather than editing it, which is the
same instruction the section already gave, now actually achievable.

**Scope.** `5.4.0`, a MINOR — the base gained something a game may ignore. Four production files
(`game_root.gd`, `game_config.gd`, `project.godot`, `core_test.gd`) plus the record. Suite
2,294 → **2,300**, three assertions and no new case.

**Commit:** `6955d0e` on `claude/t5-29-player-seam`, PR #60, targeting `main`, plus `c73ed20`
recording its CI run. Filled in by T5.30 — **fifth row running, and now fixed at the source**: the
closing checklist below asks for a commit that satisfying it creates, so it can never be true when
written. It now says so, and says what to do instead.

---
## T5.30 · Performing the extension surface — **DONE**

**The one consumer document never walked.** `SYSTEMS_INVENTORY.md` lists it beside `AUTHORING.md`,
`ART_CONTRACT.md` and `TESTING.md`; the other three were each performed, and each performance found
defects reading had not (AUTHORING alone found eleven across two passes).

### The venue is the method, and a draft of this row got it wrong

`UPGRADING.md` records that *"a stripped fork was made"* and that its synthetic versions *"exist
only in the throwaway repositories this document was performed against"*; `NEW_GAME.md` that *"the
whole strip above was performed against a fresh clone"*. **A performance happens OUTSIDE the
template and only findings come back.**

A draft of this row had proposed adding a `game/` root to the base and wiring it into the checkers'
scan roots — which would have committed a consuming game's proof into the template and made the
base ship the very thing it tells a fork to own. The precedent settled it before it cost anything.

### Six findings

| # | finding |
|---|---|
| 1 | **Three Tier 2 rows named a class and no path**, while the `Events` row named one. `UiScreen` was hunted in `src/ui/root/` — where `UiRoot` lives and it does not — before a grep found `src/ui/screens/ui_screen.gd`. Every row now names its file |
| 2 | **The three override hooks were described in prose and named nowhere.** A first attempt guessed `_on_shown()`, which compiles and never runs. They are `_build()`, `_opened()`, `_closed()` |
| 3 | **All seven checkers pass over a game code root** — measured, with plants |
| 4 | **No document had a row for game CODE** — `TEMPLATE.md`, `NEW_GAME.md` § 2 and `UPGRADING.md` § 5 each gained one |
| 5 | **A game's own input action cannot be player-rebindable**, and the constraint is deliberate |
| 6 | **Two audit predictions were wrong**, which is the argument for performing over predicting |

### Finding 3 is the sharpest, and it is a measurement

A fork carrying three Tier 2 subclasses went green on all seven checkers. Then, planted into the
game root:

```gdscript
func announce() -> String:
	return "The bell tolls for thee"      # a raw player-facing literal, and no caller
```

That is one violation of non-negotiable #3 and one uncalled public method — precisely what
`check_strings.gd` and `check_methods.gd` exist to catch. **Both still passed, and so did the other
five.** They scan `src/`, `tests/` and `tools/`; a game's root is none of those.

**Two of those gates should stay blind, and that is a relief rather than a gap.**
`check_boundary.gd` exists to prove *the engine* does not know the game's content exists, and a
game's own code is entitled to name its own ids — aiming that gate at a game root would fail an
author for doing the right thing. The remaining five are now **a stated choice**: whether a game
inherits the base's discipline or writes its own. Nothing decides it, and nobody had noticed the
question, because nobody had made a fork.

### Finding 5, stated carefully because the constraint is correct

A game may declare its own action with `InputMap.add_action()` and bind it in its own code. It
**cannot** make that action player-rebindable: `KeyBindings.rebind()` gates on the
`Actions.REBINDABLE` const, and `rebind_screen.gd` builds its rows by iterating the same const.

That gate is deliberate and has a bug behind it — its own header: *"THE GATE IS
`Actions.REBINDABLE`, NOT `InputMap.has_action`, AND THE DIFFERENCE WAS A BUG"*, because
`debug_console` could otherwise be overridden into `input.cfg` and `reset_bindings()` would not put
the default back. **So this is not an oversight to fix carelessly**; it is a real tension between
gating rebinds to a known-pollable list and letting a game have its own actions. Recorded, with the
consequence stated, and left as a decision.

### Finding 6 — the two the audit got wrong

The audit that scoped this row predicted a game's own screen could not register, because
`ScreenKeys.menu_for()` is a closed `if`-chain over the eight template screens. **It is, and it is
irrelevant.** `UiRoot.open()` takes an *instance*; `UiRoot.find(node)` locates the stack by group
rather than a hard-coded path; so `UiRoot.find(self).open(MyScreen.new())` is the whole of it. And
`menu_for`'s only caller is `dev_screens.gd`, which lives in the boundary-exempt debug directory —
a `--open-menu=` convenience, not the production path.

**That is the case for performing over predicting, delivered as two retractions.** The audit was
reading the right files and drawing the wrong conclusion, and only a fork could tell the difference.

**Scope.** `5.4.1`, a PATCH. Documentation and the version: `ARCHITECTURE.md`, `TEMPLATE.md`,
`NEW_GAME.md`, `UPGRADING.md`, `SYSTEMS_INVENTORY.md` and the record. **`src/`, `tools/`, `tests/`
and `.github/` byte-identical**, and no game code committed.

**Commit:** `d47940b` on `claude/t5-30-extension-surface`, PR #61, targeting `main`. Filled in by
T5.31 — the SHA cannot exist when the line is written, which is what item 6 above now says
outright instead of leaving each row to rediscover it.


## T5.31 · Clock and Weather on the flag surface — **DONE**

**The defect was structural rather than missing.** `Clock` owned the day, the hour and the minute,
emitted `minute_passed`, `hour_passed`, `day_passed` and `day_phase_changed` — and **never once
called `Flags.set_flag`**. `src/core/state/flag_query.gd` is the ONE evaluator that both
`DialogueNode` and `QuestStep` go through, and it reads `Flags` and nothing else.

So **no authored condition in this template could mention time or weather at all.** Not the hour,
not the day, not the phase. Including the shop hours `clock.gd`'s own header names as a reason a
clock is foundational. Two independent audits converged here, and it was their only convergence.

**The seam needed no invention, which is why this row is small.** `Flags.declare_derived` already
existed, is idempotent, and `Flags._collect_save` SKIPS derived keys — so a published `time/hour`
is never written to a save and recomputes from the clock's own saved state on load. Its only prior
caller was `inventory.gd:59`, the `bag/` namespace, and that file's two store-wipe subscriptions
came across with it: `Director.start_new_game` calls `Flags.clear_all()` and *then* emits
`game_started`, and `Flags._apply_save` clears a store whose derived keys are deliberately absent
from the file it restores from — so the republish hangs off `game_loaded`, which fires once after
every section is applied and therefore does not depend on participant order.

### The one unpriced cost, and BOTH answers the plan offered were wrong

The plan said: publish enum ordinals and state the coupling, or publish stable string names.

**Ordinals do couple** — `GameEnums` is append-only precisely because its numbers live inside
authored `.tscn` and `.tres` files. But the sharper objection is that **an ordering comparison on a
phase is meaningless whatever the numbering**, and that was measured rather than argued. Running
`phase_for_hour` across a day:

```
00:6 01:6 02:6 03:6 04:6 05:0 06:0 07:1 08:1 09:1 10:1 11:2
12:2 13:2 14:3 15:3 16:3 17:4 18:4 19:4 20:5 21:5 22:5 23:5
```

`DEEP_NIGHT` is the **highest** ordinal and the **earliest** hours, because a day wraps and an enum
does not. `AT_LEAST DUSK` would hold at 00:00 and fail at 06:00. Equality is the only sound
question about a phase, and that is true of any numbering you choose.

**And a plain string name would have been unreadable by the one evaluator — silently.** A
throwaway probe settled it, the shape T5.27 established:

| `FlagQuery.passes` against | result |
|---|---|
| a flag holding `"DUSK"`, `EQUALS 4` | **false**, logging `probe/phase is String, expected int` |
| a flag holding `"DUSK"`, `IS_TRUE` | **false**, logging `probe/phase is String, expected bool` |
| a flag holding `4`, `EQUALS 4` | true |
| a flag holding `true`, `IS_TRUE` | true |

The closed set compares bools and ints and nothing else. **Publishing names as strings would have
shipped four flags that looked correct in a debug dump and answered nothing** — and no gate in this
repository would have caught it, because writing a flag is not the same claim as its being askable.

**So the third answer, which the plan did not consider.** `time/hour` and `time/day` as ordered
ints, where `AT_LEAST 9` with `AT_MOST 17` is a shop's opening hours and the comparison means what
an author expects. A phase and a weather kind as **one bool under the lowercased name** —
`time/phase/dusk`, `weather/kind/rain` — stable against an enum insertion *and* readable through
`IS_TRUE` / `IS_FALSE`, with **no seventh comparison** added to a set whose own file says it stays
closed.

**Exactly one row exists at a time, and it is ERASED rather than set false.** `Inventory` erases a
spent stack rather than zeroing it, for the reason its header gives — a row reading 0 for something
the player does not have is a row in every dump forever. An absent flag answers `IS_TRUE` false and
`IS_FALSE` true, so the query semantics are identical at a seventh of the rows, and boot publishes
four flags rather than seventeen. The erase comes **first**: a phase flag left true would make an
authored dawn-only line fire at every hour after the first dawn.

### The gate and the plant

**Gate.** A `FlagQuery` condition on `time/hour` flips at the right minute, on **both** publish
paths — `_tick_minute` for a natural minute, `set_time` for a sleep, a cutscene, a debug command or
a loaded save. Plus the ordering invariant `bag_mirror_test.gd` owns one system over: the flag must
be current **inside** `hour_passed`, not one statement later.

**Plant** — publishing dropped from the `set_time` path only:

| run | result |
|---|---|
| control | `2331 passed, 0 failed`, exit 0 |
| plant | **exit 1**, `2329 passed, 2 failed` |

The two failures are exactly the set_time pair: *"a jump onto the hour opens it — expected true,
got false"* and *"and the flag was current inside that one too — expected 14, got 11"*. **The `11`
is the row the tick path had published**, which is what makes this a plant that fails one path and
leaves the other green rather than a plant that breaks everything.

### What the row surfaced: gotcha 33, at the one site nobody had fixed

`QuestTracker.ids_in_state` sorted with `Array[StringName].sort()`. **That orders by the
StringName's interned handle, not alphabetically** — which is gotcha 33, and `area_db.gd`,
`equipment.gd` and `inventory.gd` each already carry a note about it and each already sort through
`String`. This function was missed, and its own comment claimed *"Sorted, so the journal draws a
stable order without holding one of its own."*

It was not stable. It was the allocator's order. **Four new flag names shifted the intern table and
a journal assertion in `item_count_test.gd` — on a code path this row never touched — went red.**
The A/B is the evidence:

| `src/` | `ids_in_state(ACTIVE)` returned |
|---|---|
| baseline | `[quest/fixture_gather, quest/fixture_errand]` |
| with this row | `[quest/fixture_errand, quest/fixture_gather]` |

Note that the **baseline** order is the one that is not alphabetical. A probe confirmed the cause
rather than inferring it: eight names built in scrambled order sorted to `alpha, delta, echo,
foxtrot, charlie, bravo, hotel, golf` — neither alphabetical nor insertion order. **Two wrong
hypotheses died first**, and both cost less than the guessing that preceded them: a timing race,
ruled out by the failure being deterministic across three runs; and pointer-ordered sorting
"disproved" by a two-element probe that came out alphabetical **by luck**, which is why the second
probe used eight names instead of two.

Fixed with the same `sort_custom(_before)` the other three files use. And the test's helper stopped
returning "the last Label in the list" — a bet on an order the base never actually promised — and
started addressing a named quest through its own row. Its old comment had guarded the right way
against the wrong risk: *"found by type rather than by index, so a heading cannot make this assert
about the wrong row"*, while the order of the **quests** was the unfixed thing.

### Deliberately not in scope

- **`rest_point.gd` untouched.** An earlier draft claimed it hardcodes the hour; it does not. It
  reads an authored `@export var night_only` and calls `Clock.is_night()`, and
  `traversal_test.gd:95` asserts exactly that. Rewriting it would strip an `@export` from authored
  `.tscn` instances.
- **No `time/minute`.** A minute is a continuous value for interpolating a lighting gradient —
  `day_fraction()` is what samples it — not a question an authored format asks, and publishing it
  would rewrite a flag and announce it 1,440 times a day.
- **No calendar, weekday, month or season.** ADR-0007 classifies those as GAME CHOICES.
- **No `ScheduleEntry` day field.** A day-of-cycle is the optional follow-up row.

**Scope.** `5.5.0`, a MINOR — the base gained a seam a game may ignore. Three `src/` files
(`clock.gd`, `weather.gd`, `quest_tracker.gd`), one new test, plus `test_runner.gd`,
`item_count_test.gd` and the record. `clock.gd` is at **142 of its 150-line budget**, which is the
tightest it has been and worth knowing before the next change to it lands.

2,302 → **2,331 assertions**, +29 — and the arithmetic is worth stating because the first run of it
was wrong. 27 are the new case. The other **2 are `record_shape_test`**, whose plan is
`_docs.size() + _packages.size() * 2 + 2`, so a new package id on the board is worth exactly two
outcomes. **The pre-documentation run read 2,329, and writing that number down is precisely the
mistake the last two rows made** — they predicted +2 and measured +4, and predicted +5 and measured
+6, both times because their own prose added a claim a computed plan counts. So this was measured
twice, before and after the record landed, by diffing every case against `main`:

```
41c41
< record_shape_test: 133
---
> record_shape_test: 135
46a47
> time_flags_test: 27
```

**Commit:** `e0275d3` on `claude/t5-31-time-flags`, PR #62, targeting `main`, plus `e992f4b` for
the CI record. Filled in by T5.32, which is the order item 6 now describes rather than the lapse
five consecutive rows worked around.


## T5.32 · A schedule could only describe one day — **DONE**

**THE ROW THAT WAS EXPLICITLY OPTIONAL, TAKEN ON THE OWNER'S SAY-SO.** The plan rated this
non-blocking and named it *"the honest place to stop early if you want to"*, with every other
planned row done. It was put to the owner as a live choice — build it, declare the base finished by
written refusal, or defer it and start a game — and the answer was to build it in full. Recording
that is the point: this row exists because it was chosen, not because a board row implied it.

**The defect.** `ScheduleEntry` exported `from_hour` and nothing else, so an hour was an entry's
whole address, and `NpcSchedule.entry_for_hour(hour)` was the whole lookup. **Every NPC in every
game built on this base therefore repeated one identical day, forever.** A market day, a temple
busy one day in seven, a character who takes a day off — none of it was badly supported. It was
*inexpressible*, and nothing in the repository said so.

**IN SCOPE ONLY BECAUSE OF ADR-0007, AND THE LINE IT DRAWS IS THE WHOLE JUSTIFICATION.** That ADR
separates a TEMPLATE DEFAULT from a GAME CHOICE by asking whether a seam exists. A cycle *length*
is a formula — one number, one modulo — so it is a default with a seam. A *calendar* is a game's
own: what day 3 is called, how long a month is, when autumn starts. So this row adds
`days_per_cycle` and adds **no weekday names, no months, no seasons and no date type**, and the
refusal is as much of the deliverable as the feature.

### The shape, and it follows T5.31's seam verbatim because that seam was built for this

`time/day_of_cycle` publishes exactly as `time/day` does: through `Flags.declare_derived`, from
`_publish_time()`, which is called from `_tick_minute` and `set_time` **before their emits** plus
`_republish()` on `game_started` / `game_loaded`. Adding a key was one line there and nothing else,
which is the seam working as designed.

| what | where | shape |
|---|---|---|
| `days_per_cycle` | `clock.gd`, `@export`, default 7 | set from code at startup, as `seconds_per_minute` is |
| `day_of_cycle()` | `clock.gd`, public | `(day - 1) % maxi(1, days_per_cycle) + 1` |
| `time/day_of_cycle` | derived flag, ordered int | `EQUALS 3` is a market day; `AT_LEAST 5` is the back half |
| `on_day_of_cycle` | `schedule_entry.gd`, `@export_range(-1, 30, 1)` | `-1` means every day, and is the default |
| `entry_for_hour(hour, on_day = -1)` | `npc_schedule.gd` | day-specific beats every-day at the same hour |

**AN INT, NOT A BOOL-PER-NAME, AND THAT IS A DEPARTURE FROM T5.31 ONE ROW LATER — STATED RATHER
THAN DRIFTED INTO.** T5.31's argument for names is entirely an argument about a PHASE, and it rests
on two properties: there is an enum behind it, and a day wraps where an enum does not, so
`AT_LEAST DUSK` holds at 00:00 and fails at 06:00. A day of the cycle has neither property — no
enum to be inserted into, and no wrap inside its own range, which runs `1` to `days_per_cycle` and
stops. So both comparisons mean what an author expects, and copying the bool-per-name shape would
have cost `days_per_cycle` rows in the store to answer what one ordered int answers. The suite
asserts the difference rather than arguing it: the `AT_LEAST 4` assertion in `time_flags_test` is
one that could not be written at all under the phase's shape.

**THE DEFAULT IS WHAT MAKES IT A MINOR, AND `-1` DOES THE WORK TWICE.** On the field, `-1` means
every day, so every schedule `.tres` authored before this existed resolves exactly as before with
no edit and no migration — the same append-only discipline `GameEnums` runs on, for the same
reason: these numbers live inside authored files. On the *argument*, `-1` means "no particular
day", and only every-day entries are considered, so an existing `entry_for_hour(hour)` call site
still compiles and still answers. What it deliberately does **not** mean is "any day": that reading
would have leaked a day-specific block into every day, which is the defect the row exists to fix,
arriving through the fix. There is an assertion on exactly that.

### The two things that had to change with the lookup, and one of them was nearly missed

1. **`problems()` keyed its duplicate check on the hour alone.** Left as it was, the very fixture
   proving the feature works would be reported as malformed content and **`check_content.gd` would
   have failed the build on correctly authored data**. Keyed on the PAIR `Vector2i(hour, day)`, a
   market day is legal and a genuine collision — two entries agreeing on both — still is not,
   because that one is ambiguous in exactly the old array-order way.
2. **`NpcBrain` reads `Clock.day_of_cycle()` itself** rather than taking the day as a parameter, at
   both call sites. The hour stays a parameter because a caller legitimately hypothesises about it
   — the suite drives a whole day, `--npc-day` steps one — while *which day of the cycle it is* is
   a fact about the world that `Clock` owns. A second parameter would let two call sites disagree
   about the calendar. This is also what gives the new public method a real caller under `src/`,
   which `check_methods.gd` requires.

### A stated cost, because it is a layering consequence and not an oversight

**Nothing validates a day against the real cycle length.** An `on_day_of_cycle` of `9` on a
seven-day cycle parses, loads, passes every checker and is simply a block that never runs.
`NpcSchedule` and `ScheduleEntry` are in the `content` layer and may not touch an autoload — so no
validator there can ask `Clock` how long the cycle is, and `check_layers.gd` exists to refuse
exactly that dependency. The alternative is `content` reaching up into `systems` for a number,
which is worse than the gap. What *is* validated is the one case needing no autoload: a value below
`-1`, which is neither "every day" nor a day. A first draft of `schedule_entry.gd`'s header claimed
`NpcSchedule.problems` reported the over-range case; it cannot, for the same reason, and the claim
was corrected before commit rather than shipped as a comment promising a check nothing performs.

### The budget prediction was wrong, and measuring beat both remedies

The plan warned that `clock.gd` at **142 of its 150-line budget** would likely be pushed over, and
that the answer must be a split or a justified budget in `ARCHITECTURE.md` § Line budgets rather
than a quietly raised number. **Neither was needed: the file landed at 147 of 150.**

What would have cost the lines was a setter that republishes on assignment — about four, taking it
to 151. It was dropped on an argument rather than to fit: `Director.start_new_game` emits
`game_started` and `_republish` is connected to it, so a value set before a game begins is
published when it begins, and after that any tick republishes within one in-game minute. The window
a setter would close is one **no caller can observe**, and `seconds_per_minute` has run without one
since the file was written.

**And the split was considered and refused on evidence.** The candidate was moving the flag
projection to a `ClockFlags` class, which would have freed about ten lines. Two things killed it:
`phase_flag`'s own header says it is public *because it is the spelling an author writes into a
dialogue condition*, so moving it changes a game's call site and makes this a **MAJOR** rather than
a MINOR; and a grep found `Clock.phase_flag`, `Clock.FLAG_DAY` and `Clock.FLAG_HOUR` have exactly
one consumer between them, `tests/unit/time_flags_test.gd`, so the split would have traded a real
API break for a number while splitting one concern across two files. `clock.gd` now has
**three lines of budget left** — and T5.33's audit corrected the claim that first stood here,
which said that was the tightest any file in this base has ever been. **It is not, twice over:**
`director.gd` sits at 187 of its raised 190 with the same three, and `dev_stage.gd` was at 248 of
250 with **two** before T5.20 split it. What is true is narrower and still worth knowing —
`clock.gd` and `director.gd` are the two tightest files in the base, three lines each, and the next
row to touch either genuinely does face a split.

### Gate and plant

**The fixture is built so the failure cannot be argued.** `FixtureContent.schedule()` gained a
third entry that **collides with the ordinary morning block on the hour** and differs only by day,
so the hour cannot separate the two and only the day can. It reuses the existing evening waypoint
rather than inventing a third name, because `npc_test._authored_waypoints_exist_somewhere` checks
every waypoint a schedule names against every area. The every-day pair is appended first on
purpose: `npc_test` derives its `first` and `latest` blocks by scanning for an extreme `from_hour`
and takes the earliest match, so a fixture whose day-agnostic assertions depended on array order
would be measuring the fixture rather than the lookup.

**Plant — the day argument ignored in the lookup, `_applies_on` returning `true`:**

| run | result |
|---|---|
| control | `2350 passed, 0 failed`, exit 0 |
| plant | **exit 1**, `2346 passed, 4 failed` |

Three are the new assertions, failing together as designed: *"an ordinary day gets the every-day
block — expected fixture_post_a, got fixture_post_b"*, *"so one hour resolves to two different
places on two days — expected true, got false"*, and *"the market block does not leak into a
day-agnostic lookup"*. **The fourth is the one worth recording**: *"the day's first hour switches
over"*, a pre-existing assertion in `_the_night_shift_wraps_past_midnight` that this row never
touched. An older invariant catches the same regression independently, which is the cheapest
possible evidence that the new entry did not open a hole in the old behaviour.

### Verification

| rung | result |
|---|---|
| `--import` (first, gotcha 53) | exit 0, no `SCRIPT ERROR`, no `Parse Error` |
| `--check-only` on all seven changed files | only `Identifier not found: <Autoload>`, the documented rung-1 gotcha |
| boot | `0 warnings, 0 errors` |
| suite | **`2355 passed, 0 failed`**, exit 0 |
| seven checkers | each exit 0, each `PASS` |
| windowed capture | `0 warnings, 0 errors`, HUD `Day 1 \| 18:40 \| Dusk`, PNG inspected |

**2,331 → 2,355, +24**, measured by diffing every case against `main` **after** the documentation
landed: 11 in `npc_test`, 8 in `time_flags_test`, 2 in `record_shape_test`, whose plan is
`_docs.size() + _packages.size() * 2 + 2` so this package id on the board is worth exactly two —
**and 3 in `doc_counts_test`, which this row did not see coming and a prediction would have
missed.** The pre-docs run read 2,350; +21 was the number in the first draft of this section, and
it was wrong. Only a per-case diff said which case: `doc_counts_test` appends a CLAIM for every
line **outside** the gotcha list that mentions a gotcha and spells a number, so the three sentences
this row wrote about gotcha 79 not biting became two new assertions. Both asserted the spelled count, 79 then, and
both pass. **T5.31 warned about a computed plan counting a row's own prose; this is the second
computed plan doing it**, and it is the whole argument for measuring after the documentation lands
rather than before.

**Gotcha 79 did not bite, and that is a result.** T5.31 filed it: publishing new flag names interns
new StringNames and shifts the intern table, reordering anything sorting `StringName`s with
`.sort()`. This row published a new flag name and **no assertion in a file it never touched went
red**, which is the confirmation that T5.31's fix at `QuestTracker.ids_in_state` was the last site.
No new gotcha, so the list stayed at 79 and the four documents stating its length are
untouched.

**Scope.** `5.6.0`, a MINOR: the base gained something a game may ignore, and existing authored
`.tres` files stay valid because `-1` means every day. Four production files
(`clock.gd`, `schedule_entry.gd`, `npc_schedule.gd`, `npc_brain.gd`), three test files, and the
record.

**THIS IS THE LAST PLANNED ROW, AND THERE IS NO CHIP FOR A NEXT PACKAGE.** Item 8 asks for one so a
handoff is automatic; here the honest answer is that there is nothing to hand off to. Every row on
this board is DONE, the plan this row came from is exhausted, and the base is complete. The board
and `CONTEXT.md`'s branch map are the handoff, and the next thing to happen to this repository is a
game being started on it — `NEW_GAME.md` is that checklist.

**CI, from the job logs and not the tick (gotcha 26).** Run `34454905464`, PR #63, both jobs
`success`: full checkout `=== 2355 passed, 0 failed, 0 skipped ===`, stripped template
`=== 2281 passed, 0 failed, 25 skipped ===`. **The gap is 74, the eighth consecutive recorded run
at exactly 74, and still nothing enforces it.** Twenty-four new assertions landed in the full job
and the gap did not move, which is correct twice over: the new test functions build their content
from `FixtureContent` rather than `data/`, and the two computed-plan cases that grew read `docs/`,
which the strip does not touch.

**Commit:** `ad17667` on `claude/t5-32-day-of-cycle`, PR #63, targeting `main`, plus `8bbf313` and
`6df8059` for the CI records and `b93c95d` for the merge of `main` that `strict` required. Filled in
by T5.33 — which also retracts the claim above that there would be no next row to fill it in. There
was, and it came from auditing this one.


## T5.33 · The audit of a base declared finished — **DONE**

**THIS ROW EXISTS BECAUSE THE PREVIOUS ONE SAID THERE WOULD BE NO MORE.** T5.32 closed the board,
declared the base complete, and deliberately created no chip. The owner then asked for a full check
of the project before starting a game on it — and the check found that the row declaring the base
finished had made a documented invariant violable, plus three wrong numbers. Both halves are the
argument for auditing a thing you have just called done: the defect was one day old, and the
document that would have caught it was the one nobody re-read.

### The finding that mattered

`schedule_entry.gd` has always promised, in its own header, that **a day is always completely
covered** — "The cost is that a gap in the day cannot be expressed - which is correct, because an
NPC is always somewhere." Before T5.32 that was not a convention but a *structural* fact: every
entry applied on every day, so `entry_for_hour`'s wrap-to-the-last-block fallback could never come
up empty.

`on_day_of_cycle` made it violable by authored data for the first time, and **nothing in the
repository noticed** — not `problems()`, not `check_content`, not one of 2,355 assertions.

**Measured with a throwaway probe, run under `--headless --script` because `NpcSchedule` and
`ScheduleEntry` touch no autoload:**

```
=== A: only day-specific entries, asked about a day that matches none ===
  hours with NO block on day 2: 24 of 24
  problems() reports: 0  ->  []
  and on the market day itself, gaps: 0
```

So an author who writes only day-specific entries gets an NPC with **no instructions for twenty-four
hours**, on every day the schedule does not name, and the build says nothing.
`NpcBrain.decide_for_hour` returns early on a null entry, so the NPC keeps standing wherever it
happened to be — precisely the "reads as random" failure the entry header exists to prevent.

**The probe's other three cases came back correct**, which is what made the first one worth acting
on rather than a symptom of a broader mess: an every-day block still covers a named special day
(`gaps on day 2: 0, on day 3: 0`); two day-specific entries on *different* days at one hour resolve
independently and are correctly **not** reported as a collision; and a day above the cycle length
parses, loads and is never selected across a seven-day cycle — the cost T5.32 stated in writing.

### One rule, and it is exactly the strength the layer can support

**Every schedule must carry at least one entry at `on_day_of_cycle = -1`.** That is necessary *and*
sufficient for total coverage: `_applies_on` admits an every-day entry whatever day is asked, so
`latest` is never null and `entry_for_hour` never returns null.

The stronger rule — *every day of the cycle is covered* — was rejected on layering, not on effort.
It needs `Clock.days_per_cycle`, `NpcSchedule` is in `content`, and `check_layers.gd` exists to
refuse `content` reaching up into `systems`. So the every-day rule is the strongest form of the
coverage guarantee this layer can actually check, and `schedule_entry.gd`'s header now says which
part of coverage is enforced and which part remains a stated cost.

### Gate and plant

The assertions do two separable things on purpose. One measures the **consequence** — 24 of 24
hours answering nothing without an every-day entry. The other gates the **report** — that
`problems()` says so. Then a repair case proves one `-1` entry restores coverage on the named day
*and* every other, and the fixture serves as the positive control, since it always satisfied the
rule and was never affected.

**Plant — the new check disabled:**

| run | result |
|---|---|
| control | `2362 passed, 0 failed`, exit 0 |
| plant | **exit 1**, `2361 passed, 1 failed` |
| control, after restoring | `2362 passed, 0 failed`, exit 0 |

`FAILED: and that is reported as a problem rather than passing check_content — expected 1, got 0`.

**And the consequence assertion stays GREEN under the plant, which is the right answer and the
reason the two are separate.** The 24-of-24 gap exists whether or not the validator reports it; a
single assertion bundling both would have gone red for the wrong reason and taught a later reader
that the gap was the thing that changed.

**An existing assertion had to be re-expressed, not just added to.** T5.32's collision case
asserted `problems().size() == 1` on a schedule that — as it happens — also has no every-day entry,
so it now reports two. Rewritten to count problems *by phrase* through a small
`_problems_mentioning` helper, because an assertion on a total silently depends on how many other
rules the same resource happens to break, which is a fragile test rather than a strict one.

### Three documentation findings, and the checklist defect behind one of them

| where | said | actually |
|---|---|---|
| `TESTING.md` opening | full `2302 passed`, stripped `2226 passed` | `2362` / `2288` |
| `NEW_GAME.md` § 7 | "all 930 assertions stay green" | number deleted; it carried no weight |
| T5.32's own record | `clock.gd`'s 3 spare lines were "the tightest any file has been" | `director.gd` has 3 too; `dev_stage.gd` had 2 before T5.20 |

**`TESTING.md` is the one with a lesson, because it was missed by two consecutive rows.** Closing
item 5 was being read as "update `CLAUDE.md` and `ARCHITECTURE.md`" — the two files the T5.32 brief
happened to name — while the suite size is actually stated in **four** places. So T5.31 updated two
and left two; T5.32 did exactly the same, in the file a newcomer reads to learn the suite. **The
stale pair even disagreed with the rest of the repository**: `2302 − 2226 = 76`, while the board
recorded a stripped gap of exactly 74 for eight straight runs. Nothing caught that contradiction
either, and it is the cheapest kind to catch. Item 5 now enumerates all four files and states that
the stripped number can only come from the CI job log, so that step finishes *after* CI rather than
before.

**`NEW_GAME.md`'s number was deleted rather than corrected**, which is the better move for a count
that carries no weight: the sentence's point is that a narrowed export filter fails while everything
on disk stays green, and no reader needs the total to understand it. Replacing a stale number with a
fresh one just schedules the next staleness.

**T5.32's budget claim was wrong twice**, and it was a claim about this base's own history rather
than about its code, which is why no gate could have caught it: `director.gd` is at 187 of its
raised 190 with the same three lines spare, and `dev_stage.gd` stood at 248 of 250 — **two** — until
T5.20 split it. The corrected statement is narrower and more useful: `clock.gd` and `director.gd`
are the two tightest files in the base, three lines each, and the next row to touch either faces a
split.

### What the audit CONFIRMED, recorded because a clean result is evidence too

- **Zero markdown table column mismatches across every live document** — the defect that recurred
  in T5.15, T5.19 and T5.26. A naive sweep produced four hits and **all four were false positives**
  (an ASCII tree inside a code fence, and T5.32's own deliberately escaped `\|`), so the scan was
  rewritten to track fences and escaped and inline-code pipes before the result was trusted. That is
  T5.26's own measurement repeating: it declined a column-count gate because three of four
  candidates were false positives, and this is why.
- **"Ten autoloads" (10), "seven checkers" (7), "eight template screens"** — `ScreenKeys.menu_for`'s
  chain is exactly eight — all correct against the code.
- **`AUTHORING.md`'s "20 per area to `transitions_test`, 5 to `world_map_test`"** is correct, and it
  was nearly reported as an off-by-one: `world_map_test` declares `PER_AREA = 4`, and the 5 is right
  only because the plan also carries `PER_DEF = 1` and line 212 asserts one def per area. Checking
  before reporting is the whole of it.
- **`UPGRADING.md` and `NEW_GAME.md`'s historical run outputs are correctly attributed** to named
  synthetic forks (`Marsh Lantern 0.0.1 | base 1.1.1`, "measured at template 1.0.1") and are
  legitimately frozen — the contrast with `NEW_GAME.md`'s unattributed 930 is exactly what made that
  one a finding.
- **No TODO/FIXME/HACK debt** under `src/`, `tools/` or `tests/`; nine `NO CALLER` exemptions, each
  carrying its stated reason; CHANGELOG headings ordered with no duplicates.

### Verification

| rung | result |
|---|---|
| `--import` | exit 0, no `SCRIPT ERROR`, no `Parse Error` |
| boot | `0 warnings, 0 errors` |
| suite | **`2362 passed, 0 failed`**, exit 0 |
| seven checkers | each exit 0, each `PASS` |

**2,355 → 2,362, +7**: five in `npc_test` (79 → 84) and **two in `record_shape_test`** (137 → 139),
this row's own package id passing through a computed plan, with `doc_counts_test` unmoved since this
row spells no gotcha count. The pre-documentation run read 2,360. **The plan guard caught an off-by-one on the way** — `npc_test planned 85
outcomes and produced 84`, with every one of the 84 passing — which is that mechanism doing exactly
what it is for, and worth noting because a wrong plan is the one test defect that looks like a crash.

**Scope.** `5.6.1`, a PATCH on three cited precedents. Two production files (`npc_schedule.gd`,
`schedule_entry.gd`), one test file, and the record.

**Commit:** `87cce58` on `claude/t5-33-audit`, PR #64, targeting `main`, plus `71707ac` for the CI record. Filled in by T6.0.


## T6.0 · Planning Phase T6 — **DONE**

**The owner's question, 2026-09-26:** this base will be the formula for many games — what belongs in
it that we may have missed? The answer below is FILTERED, not brainstormed, and the filter is the
project's own: ADR-0007 decides what a template DEFAULT is, the refused list (cutscenes, economy,
chapter sequencer, calendar, combat, credits, jumping, expression conditions, quest rewards) is not
reopened, and work is found rather than invented. So every row is either a **confirmed defect** or an
item on `SYSTEMS_INVENTORY.md` § "Commonly forgotten" that is still neither done nor decided.

**Method.** Three parallel explorations — an inventory of what exists, a sweep of everything the owner
refused or deferred, and a presence check across thirty-six capabilities a general HD-2D exploration
base usually needs — then an adversarial review of the draft ranking, then every load-bearing claim
re-read in the code before it was written here.

**The review overturned three first premises**, which is why it ran:

| premise | reality |
|---|---|
| shader warm-up is missing (forgotten #14) | built in T2.0 — `Director.WARM_UP_FRAMES = 3`, `_warm_up()` |
| per-section save versions were never exercised | exercised — `core_test.gd:134` registers a v3 probe and asserts it |
| the F2 freecam is declared but unbound | bound (`actions.gd:127`); it has no *consumer* |

**And it found one real defect by reading.** `SaveSystem.load_from_slot` passes each section's
stored `"v"` straight to its applier, with no check that it is not newer than the running build —
and every applier in the base ignores `_from_version`. The envelope has exactly that guard
(`_migrate` refuses `from_version > SCHEMA_VERSION`); the section level has no twin. A save written
by a newer build would be applied, differently shaped, as if current. For a base that games will
update across many versions, that is the most consequential thing this sweep found.

### The owner's three decisions

1. **Phase T6 only.** Map objective markers, music by day phase and weather, proximity barks and a
   dialogue backlog all pass ADR-0007 as defaults but are neither defects nor on the forgotten list,
   so they wait until a game asks.
2. **Photo mode, a codex, in-area camera zones and positional ambient emitters are GAME CHOICES**,
   each because its seam already exists: the F2 freecam is bound; `Readable.has_been_read()`
   (`readable.gd:38`) exposes the fact a codex would collect; a scene may hold two rigs or tween the
   rig's exports, since framing lives in the area scene (`hd2d_camera_rig.gd:20`); and positional
   sound is an authored `AudioStreamPlayer3D`.
3. **Font fallback proves both Bengali and CJK** — two scripts, so the chain is shown to generalise
   rather than to work for one font.

### Deferred until a real game needs one

A platform or achievements seam; area streaming, LOD, pooling and occluders; mods or several content
roots; graphics quality presets; a colorblind palette; right-to-left text.

### Stale records fixed in this row

- `CONTEXT.md` still listed **time on the flag surface** and **a cycle above the day** as open
  candidates, though T5.31 and T5.32 built both.
- "Commonly forgotten" **#14** (shader warm-up) described as missing work built in T2.0 → DONE.
- **#12** (photo mode) and **#13** (credits) closed as game's — #12 by the owner's decision above,
  #13 by the owner on 2026-09-02, which the list itself had never recorded.

### Row manifests — read these files and nothing else

**Budget warnings first, because two rows share tight files.** `save_system.gd` is at **172 of
180** and both T6.1 and T6.4 edit it; `director.gd` is at **187 of 190**; `settings.gd` is at **141
of 150** and both T6.5 and T6.7 add a setting. Measure with `check_budgets.gd` before writing, and
where a row would overrun, the answer is a split or a justified budget in `ARCHITECTURE.md`
§ Line budgets — never a quietly raised number.

**T6.1 — a newer section is refused.** Write: `src/core/save/save_system.gd`,
`tests/unit/save_recovery_test.gd`, one paragraph in `docs/UPGRADING.md` on bumping a section
version and migrating. Read: `tests/unit/core_test.gd:134` for the version-probe pattern. **Prove the
defect red on today's code before fixing it.** Then add the first worked migration the suite has —
a probe at v2 migrating a hand-written v1 payload — as the model a game copies. PATCH.

**T6.2 — the active input device.** Write: new `src/systems/input/input_device.gd` (a pure
`device_for(event, previous)` that ignores mouse motion and sub-deadzone stick noise),
`src/systems/input/actions.gd` (the stateful half — no new autoload), `src/core/events/events.gd`
(`input_device_changed`), `src/ui/prompt/interact_prompt.gd` and `src/ui/screens/dialogue_screen.gd`
as consumers, a new test case plus its line in `tests/test_runner.gd`'s `CASES`, and a note in
`docs/ART_CONTRACT.md` on where an icon sheet will plug in. Reuse
`KeyBindings.text_for(action, pad)` (`key_bindings.gd:105`), which already exists and has one
caller. Hotplug cannot be driven headless — say so. MINOR.

**T6.3 — a confirm screen.** Write: new `src/ui/screens/confirm_screen.gd`,
`src/ui/screens/save_screen.gd` (overwrite routes through it), `localization/strings.csv`, a test.
Read: `src/ui/screens/ui_screen.gd` (`closes_on_cancel`). The quit half of forgotten #7 is already
covered by T5.10's quit-autosave — record that rather than build it.

**T6.4 — where a slot was saved, and a damaged slot.** Write: `src/core/save/save_system.gd` (an
optional header hook so `core` never asks `Director` — the layer rule), `src/ui/screens/save_screen.gd`,
`localization/strings.csv`, tests. **`director.gd` has three lines left**, so register the area from
somewhere that has room, or justify the budget. A slot that fails to read (`ERR_FILE_CORRUPT`,
`save_system.gd:195,201`) is drawn as damaged, not empty. After T6.3.

**T6.5 — focus loss.** Measure first, windowed: hold a key and alt-tab, and find out whether Godot 4.7
already releases pressed inputs. Then the base's own latches, which the engine cannot release:
`run_is_toggle` (`player_controller.gd:176`), hold-to-confirm progress in
`src/gameplay/interaction/interaction_sensor.gd`, and capture in `src/ui/screens/rebind_screen.gd`.
Write: `src/ui/root/ui_root.gd`, `src/core/events/events.gd` (`focus_lost`),
`src/core/state/settings.gd` (`gameplay/pause_on_focus_loss`), a test.

**T6.6 — fonts.** Write: `assets/fonts/` (new: Noto Sans Bengali, a CJK subset, and each OFL licence
beside its font), `assets/theme/ui_theme.tres` (a fallback chain), a test that the chain names both
in order, `docs/ART_CONTRACT.md` and `docs/NEW_GAME.md`. Capture one Bengali string (its conjuncts
exercise real shaping) and one CJK string, against tofu before. Check whether any count needs
`tr_n` before building plural support. If the eight-file limit is exceeded, split it into Bengali
first and CJK second.

**T6.7 — dialogue speed.** Write: `src/ui/screens/dialogue_screen.gd` (skip to the end of a
conversation, and auto-advance), `src/core/state/settings.gd`
(`gameplay/dialogue_auto_advance`), `localization/strings.csv`, `tests/unit/dialogue_test.gd`. A
backlog screen is a separate row and stays out. After T6.2.

**T6.8 — close the list.** Write: `docs/SYSTEMS_INVENTORY.md` (every forgotten item marked DONE or
CLOSED with a package id, plus the owner's playtest verdict on first-run defaults, #8), a new text-scan
test plus its `CASES` line, `docs/ROADMAP.md` (tick the phase), `docs/CONTEXT.md`. Last, because its
gate cannot pass until everything above has landed.

**The owner's playtest outranks this queue.** A defect found by playing becomes the next row ahead of
anything here — found, not invented, which is the standard every row above had to meet.

**Commit:** `487e7f4` on `claude/t6-0-plan`, PR #65, targeting `main`, plus `488e493` for the CI record. Filled in by T6.1.


## T6.1 · A save from a newer build must be refused, not applied — **DONE**

**The defect, as T6.0 read it.** `load_from_slot` handed every section's stored `"v"` to its applier
with no comparison against the version the running build registered, and every applier in the base
ignores `_from_version`. The envelope refuses a newer schema in `_migrate`; the section level had no
twin.

**Proved red on `5.6.2` before a line of `src/` changed.** A new block in
`tests/unit/save_recovery_test.gd` registers a probe at `PROBE_VERSION = 2` and hand-writes a
section at `"v": 3`:

```
=== 2371 passed, 2 failed, 0 skipped ===
FAILED: but its applier was never called — expected 0, got 1
FAILED: so the probe keeps its defaults — expected unset, got from the future
```

**The fix.** Four code lines in `load_from_slot`: read the stored version once, and if it exceeds
`_versions[id]`, `Log.error` — `Section '<id>' is from a newer build (v3 > v2) - loading defaults` —
and `continue`. The load still returns OK and every other section still applies, because one bad
section must not cost the whole file (that case's own header line). `save_system.gd` 172 → **176
of 180**, measured with `check_budgets.gd`; no budget raised.

**The plant.** The guard's condition prefixed with `false and`: `2371 passed, 2 failed`, the same
two assertions. Restored: `2373 passed, 0 failed` before the documentation landed.

**The first worked migration**, the model a game copies. `_probe_apply` upgrades a v1 payload in
place — `old_key` → `new_key` — then reads the current shape; one block hand-writes a v1 section
and asserts the value arrives through the renamed field, and one writes a v2 section and asserts it
is read without migration, so the refusal above cannot pass by refusing everything. Those two were
green on `5.6.2` too, as they should be: the loader always passed an older version through. What
the suite lacked was an example and the guard, not the mechanism. `UPGRADING.md` § 4, item 3,
gained the paragraph that points a game at it.

**Not in scope, and left alone.** `SCHEMA_VERSION` stays 1 and `_migrate`'s success path stays
unreachable, pinned as before. `director.gd` untouched. The slot header and the damaged-slot display
are T6.4.

**Scope.** `5.6.3`, a PATCH. One production file, one test file, and the record.

**Commit:** `53c44ae` on `claude/t6-1-newer-section`, PR #66, targeting `main`, merged as `d955449`; no separate CI-record commit was made. Filled in by T6.2.

---

## T6.2 · The base knows which input device is active — **DONE**

**The gap, as T6.0 read it.** Forgotten #4: nothing in the base knew whether the player was on a
keyboard or a pad, so no prompt could name the button they would press. The interact prompt named
only the verb. `KeyBindings.text_for(action, pad)` already produced the words for either half and
had one caller, the controls screen.

**And a defect nobody had listed, found by reading the second consumer.** The dialogue box's hint
read `Space to continue` — and Space advanced nothing. It had been bound to `jump`, which T5.5
removed with its poller, while `DialogueScreen._unhandled_input` has only ever listened for
`interact` (E, Enter, the pad's south button). A string naming a key goes stale on the first
rebind; the hint now asks the binding.

**The two halves, as the manifest asked.** `src/systems/input/input_device.gd` is one static,
pure function, `device_for(event, previous)`: a key, a mouse click, a pad button, or a stick at or
past `Actions.STICK_DEADZONE` is a switch; mouse MOTION, a stick under the deadzone, and any event
it does not recognise keep the previous answer. `Actions` holds the answer (`device()`), feeds it
from `_input` through a public `observe(event)`, and emits `Events.input_device_changed` only on a
change. **No autoload was added.** `Actions`' MUST NOT said it may not "read input"; it now says it
may not read an event for anything but its device — narrowed in writing, with the reason in its
header, rather than silently widened.

**One manifest deviation, forced by a checker.** The signal lives in `core` and needs a type, so
the enum went into `GameEnums` — a ninth file the manifest did not list. It is `DeviceKind`, not
`InputDevice`: the first spelling shared its name with the new class, and `check_layers.gd` read
`GameEnums.InputDevice` as `core` naming a `systems` class — `FAIL — 2 upward reference(s)`, exit 1.
Renamed, it passes. A text scan cannot tell an enum from a class of the same name, and should not
have to.

**Hotplug cannot be driven headless, and is not claimed.** Unplugging the last pad falls back to the
keyboard (`Input.joy_connection_changed` → `_on_joy_connection_changed`); plugging one in changes
nothing until it is pressed. The suite calls the handler with the arguments the engine would pass —
headless has no pads, so `get_connected_joypads()` is empty — and the engine's own emission is
untested by construction.

**Assertions.** `tests/unit/input_device_test.gd`, 31: eleven on the rule (each non-switch asked
from both devices, so a rule that always answers one cannot pass), seven on the state (one
announcement per change, none for repeated pad input or a bumped mouse), three on the unplug, six
on the prompt and four on the dialogue hint. Consumers are compared against `KeyBindings.text_for`,
never a spelled key, so a rebind or an engine rename of a pad button does not break the case.

**Three plants, three different failures.** Deadzone ignored: `2405 passed, 1 failed`, `stick drift
under the deadzone keeps the keyboard — expected 0, got 1`. Announce on every event: `2404 passed,
2 failed`, `more pad input is not announced again — expected 1, got 3` and `and that is the second
announcement — expected 2, got 5`. The dialogue never subscribing: `2405 passed, 1 failed`,
`mid-conversation, the pad renames it — expected true, got false`. Restored: `2406 passed`, before
the documentation landed.

**Photographed windowed**, 960×540: `--stand-by=Keeper` shows `[E]  Barter  The Keeper's Basket`,
and `--talk=talk/gardener` shows `E to continue` at the foot of the box. The pad variant cannot be
photographed without a pad — that is the suite's job, and it asserts it.

**Budgets**, measured with `check_budgets.gd` before and after: `actions.gd` 91 → **107 of 150**,
`interact_prompt.gd` 88 → 99, `dialogue_screen.gd` 136 → 143, `events.gd` 46 → 47, `input_device.gd`
13. Nothing tight was touched.

**Not in scope.** Button ICONS — `ART_CONTRACT.md` § Button prompts names `KeyBindings.text_for` as
the one seam a sheet replaces and lists what it will need. The controls screen still labels its two
columns rather than highlighting the active one. `KeyBindings`' header still says `Actions` never
mentions it, which has been untrue since `Actions` called `load_all()`; recorded, not fixed here.

**Scope.** `5.7.0`, a MINOR. Suite 2,375 → 2,408: +33: 31 in the new `input_device_test` and 2 in `record_shape_test` for this row's own package id; every other case unmoved.

**Commit:** `8bed5af` on `claude/t6-2-input-device`, PR #67, targeting `main`, merged as `f19cbd6`; no separate CI-record commit was made. Filled in by T6.3, which also took the stripped count from the CI job log (`Ladder (stripped template)`, job 109013767306: `=== 2334 passed, 0 failed, 25 skipped ===`; full job 109013767855: `=== 2408 passed, 0 failed, 0 skipped ===`). `TESTING.md` had kept T6.1's stripped `2301` through T6.2; T6.3 replaces it.

---

## T6.3 · A reusable confirm screen, and "are you sure" on overwriting a save — **DONE**

**Closes forgotten #7.** Pressing an occupied slot on the save screen used to overwrite it
immediately, with no way back. That is the one irreversible action this template's menus offer.

**What was built.** `src/ui/screens/confirm_screen.gd`, `ConfirmScreen extends MenuScreen`. It
extends `MenuScreen` rather than bare `UiScreen` because a question IS a titled column of two
rows: the panel, the title, the gamepad navigation and the row styling are already written, and a
second copy of them is a second place for the pad to stop working. It is still a `UiScreen`, as the
manifest asks. `asking(question_key, detail, on_yes)` is the one constructor, and every field is
set before `_build` runs on add_child.

- **`closes_on_cancel = false`**, set in `_init`, as `menus_test.gd` requires of every flag. So
  `UiRoot._unhandled_input` returns early on cancel AND pause, and `ScreenKeys.toggle_pause_menu`
  refuses too, because the stack is not in gameplay.
- **Focus lands on No**, though Yes is drawn first. `focus_first()` is overridden rather than
  `_opened()`, because the base calls `focus_first` from both `refresh()` and `_opened()`, and a
  redraw must not move focus onto the destructive answer.
- **Yes runs `on_yes`, then asks to close.** The caller's redraw happens while the question is
  still on top, so the revealed save list already shows the new header when `UiRoot` hands it
  focus.
- **No row names a key**, so `KeyBindings.text_for` is not called. T6.2's pattern applies to a
  button naming a key, and neither answer does.

**The save screen.** `_on_slot`: writing to an occupied slot pushes
`ConfirmScreen.asking(OVERWRITE_KEY, slot_text(slot), _write.bind(slot))`. The detail line is the
header about to be lost. An empty slot writes at once, because asking where nothing can be lost
would teach the player to press through the question. `SaveScreen`'s MUST NOT now also forbids
drawing its own question.

**The quit half is recorded, not built**, as the manifest instructed. T5.10's `Autosave` writes the
autosave slot on `Events.game_ending`, on both quit paths, before `quit()`. Reading
`Autosave.request()` shows two refusals the plan did not mention: autosave turned off in
Settings, and a transition in flight. In either case quitting still loses progress without a
question. That is written into `SYSTEMS_INVENTORY.md` item 7 rather than papered over, and a game
that wants the question calls `ConfirmScreen.asking` from its own quit row.

**Assertions.** `tests/unit/confirm_test.gd`, 27. Three on the flags, on a fresh instance. Four on
focus and draw order, including after a `refresh()`. Four on which row runs the action, on an
UNSTACKED screen, so the stack's deferred close cannot fire mid-case. Six on cancel: cancel,
pause, the pause key, nothing ran, and the **control**, where the same `InputEventAction` closes
the screen once `closes_on_cancel` is flipped. Without that control, an event that never matched
the action would pass the other five. Three on the empty slot, four on the occupied slot, and
three that the keys exist. Rows are pressed with `pressed.emit()`, which is the Button's own path.

**Two plants, two different failures.** Save screen skipping the question (`if false and …`):
`2431 passed, 2 failed`, `an occupied slot asks first — expected true, got false`, plus the plan
shortfall `planned 27 outcomes and produced 24` from the guarded early return. Confirm screen
closing on cancel: `2431 passed, 4 failed`, `cancel cannot dismiss a question — expected false, got
true`, `cancel does not answer it — expected 1, got 0`, `pause does not answer it`, and `the pause
key opens nothing over it — expected false, got true`. Restored: `2435 passed`, before the
documentation landed.

**Photographed windowed**, 960×540, through a temporary `--probe-confirm` in `dev_screens.gd`. It
wrote slot 6 (logged `existed before: false`), opened the save list over the pause menu and
pressed slot 6's real row. The capture shows `Overwrite this save?`, the header `Slot 6 ·
2026-09-29 09:11:19 · 00:00 played`, then `Yes`, and `No` with the focus outline, over the dimmed
courtyard. The save list underneath is hidden, not printing through. Session `0 warnings, 0 errors`.
The probe was removed, `git diff src/systems/debug/` is empty, and the slot file it wrote was
deleted.

**Budgets**, measured with `check_budgets.gd` before and after: `save_screen.gd` 67 → **71 of 250**,
`confirm_screen.gd` **33**. Nothing tight was touched: `save_system.gd` stays at 176 of 180 for
T6.4, and `director.gd` stays at 187 of 190.

**Not in scope.** The slot's location and damaged display (T6.4), focus loss (T6.5), dialogue skip
(T6.7). The load direction does not ask, because loading from the pause menu discards unsaved
progress in the current session the same way quitting does. That is a question a game may want,
and it is one `ConfirmScreen.asking` call; the manifest did not ask for it.

**Scope.** `5.8.0`, a MINOR. Suite 2,408 → 2,437: +29: 27 in the new `confirm_test` and 2 in `record_shape_test` for this row's own package id; every other case unmoved.

**Commit:** `2195b8a` on `claude/t6-3-confirm-screen`, PR #68, targeting `main`, merged as `2b409de`; no separate CI-record commit was made. Filled in by T6.4, which also took the stripped count from the CI job log (`Ladder (stripped template)`, job 109341273520: `=== 2363 passed, 0 failed, 25 skipped ===`; full job 109341273896: `=== 2437 passed, 0 failed, 0 skipped ===`). `TESTING.md` had kept T6.1's stripped `2301` through T6.2 and T6.3; T6.4 replaces it.

## T6.4 · A save slot says where it was saved, and says so when it is damaged — **DONE**

**Closes forgotten #15.** Two defects on one screen. A slot's header named no place, because
`core` cannot ask `Director` and nothing above `core` could add to the header. And a slot whose
file did not parse was drawn as `Slot N · empty`, telling the player that a save they had made
was never there.

**The hook.** `SaveSystem.header_provider: Callable`, unset by default. `save_to_slot` calls it
once per write and stores the answer as the envelope's `"header"`, and `slot_info` already
returned everything except `"sections"`, so it hands the header back with no new reader. It is a
public `var` and not a `register_header()` method: one line of budget instead of four, and
`check_methods.gd` has nothing to ask about. One hook rather than a list, because a game that
wants more fields returns a bigger Dictionary from its own provider.

**Registered from `WorldMap`, not `director.gd`.** `director.gd` is at 187 of 190. `WorldMap`
already reads `Director.current_area_id` in `travel_to`, and it is the system that knows an area's
NAME, so the header's whole shape lives in one file: `HEADER_AREA` written by `_save_header`, and
read back by the static `place_key(header)` that `SaveScreen` calls. `_exit_tree` clears the hook
**only if it is still its own**, so a second map is not blanked by the first leaving. The header
holds the area ID and not the name, so the name is localized when it is drawn and a save written
in one language reads in another. An area with no `AreaDef`, and every save from before 5.9.0,
reads `Unknown place` rather than dropping the field, so every row has the same shape.

**Damaged.** `has_slot` true with `slot_info` empty. **`slot_info` had to get stricter for that
to be true.** It returned `{}` only for unparseable JSON. A file with version 0, or from a newer
build, parsed fine, drew a normal header, offered a load that `load_from_slot` refused, and
`latest_slot` could make it Continue. It now refuses exactly what `_migrate` refuses, in the same
line, with no extra budget. `SaveScreen._fill` became one `_add_slot` per slot: writing offers
every slot as a row, reading offers a row only for a readable header and a note for the rest.

**Is a damaged slot occupied? Yes.** When saving, it is a row, and `_on_slot` asks on `has_slot`,
not on a readable header, so writing over it asks first, with `Slot N · damaged` as the detail. The
file is still on disk, a player may be able to recover it by hand, and writing over it is as
irreversible as writing over a good one. One press to answer is cheap; a lost file is not.

**Assertions.** `tests/unit/slot_header_test.gd`, 32, on fixture content in `SaveFixture.ROOT`.
Three on the hook's ownership. Five on the header and the row naming the place. Six on the two
unnamed cases: an unmapped area, and no hook at all. Seven on damage: an unparseable file, a
parseable file from version 99 with a `9999` stamp, which proves Continue skips it, agreement with
`load_from_slot`, and a damaged autosave. Three on the load list and four on overwriting a damaged
slot, where only Yes replaces it with a readable save. Four on the keys and on `{place}` being in
both header strings.

**Three plants, three different failures.** Damaged branch removed from `slot_text`: `a file that
does not parse is damaged — expected Slot 4 · damaged, got Slot 4 · empty`, and the same for the
future file and the autosave. Version refusal removed from `slot_info`: `a file from a newer build
has no header either`, `so it is damaged too — … got Slot 5 · Unknown place · 9999-12-31T23:59:59`,
and `and Continue never points at it`. The only-if-ours guard removed: `2468 passed, 1 failed`, `the
first map leaving does not blank the second's hook`. Each exited 1; each was restored.

**Photographed windowed**, 960×540, through a temporary `--t64-probe` in `dev_screens.gd`. It moved
`save_dir` to `user://t64_probe`, wrote slot 1 on arrival, planted an unparseable slot 3 and a
version-99 slot 4, and opened the load list. The capture shows `Slot 1 · Rose Courtyard ·
2026-09-29 09:53:52 · 00:00 played`, and the autosave written on arrival with the same place.
Slots 3 and 4 read `damaged` as notes, and slots 2, 5 and 6 still read `empty`. The probe was
removed, `git diff src/systems/debug/` is empty, the scratch directory was deleted, and the
player's `user://saves` was untouched and is empty.

**Budgets**, measured with `check_budgets.gd` before and after: `save_system.gd` 176 → **179 of
180**, `save_screen.gd` 71 → 73 of 250, and `world_map.gd` 67 → 76 of 250. No budget was raised.
`director.gd` stays at 187 of 190.

**Not in scope.** Focus loss (T6.5), font fallback (T6.6), dialogue skip (T6.7). A damaged file
logs `is not valid save JSON` every time the list is drawn. That is an error condition truly
present on disk, and the log says so; it is not suppressed.

**Scope.** `5.9.0`, a MINOR. Suite 2,437 → 2,471: +34: 32 in the new `slot_header_test` and 2 in `record_shape_test` for this row's own package id; every other case unmoved.

**Commit:** `a90b57a` on `claude/t6-4-slot-header`, PR #69, targeting `main`, merged as `9b6a7e7`; no separate CI-record commit was made. Filled in by T6.5, which also took the stripped count from the CI job log (`Ladder (stripped template)`, job 109354905555: `=== 2397 passed, 0 failed, 25 skipped ===`; full job 109354905350: `=== 2471 passed, 0 failed, 0 skipped ===`). `TESTING.md` had kept T6.3's stripped `2363` through T6.4; T6.5 replaces it.

## T6.5 · Losing window focus leaves nothing latched; pausing on it is a setting — **DONE**

**Closes forgotten #3.** An alt-tab while a key is held should not leave the character walking.
The manifest said to measure whether the engine already handles that before writing code.

**Measured first, windowed.** A temporary `SceneTree` probe in `src/systems/debug/` bound an action
to D and logged `window_is_focused()`, `Input.is_physical_key_pressed(KEY_D)` and
`Input.is_action_pressed` every 0.25s. A PowerShell driver held D with `keybd_event` (scancode
0x20), alt-tabbed away two seconds later, and released D while the window was unfocused. The probe
read `focused=true key=true action=true` at t=4.02 and `focused=false key=false action=false` at
t=4.26, and it stayed false. The only key event logged was the press. **So Godot 4.7.2 clears the
held state on focus loss and sends no release event.** A held walk, a held run and a held interact
key needed nothing from the base. A pad was not measured, since none was attached. A first attempt
with F13 registered nothing, and is recorded so nobody repeats it.

**What the engine cannot release is the base's own state**, so each owner drops it on the new
`Events.focus_lost`. `PlayerController` sets `_run_toggled` false and leaves `run_is_toggle`, the
player's setting, alone. `InteractionSensor` sets `_hold` to zero and keeps its target, so the prompt
has something to offer the moment the player returns. The next physics frame would have zeroed it
anyway, but that frame waits while the tree is paused. `RebindScreen` stops listening, because the
next key after an alt-tab is not a choice the player made on that row. It connects in `_init`, and
freeing the screen drops the connection.

**Who announces it.** `UiRoot`, since it already announces the one other fact about the world and
input, the UI mode. It listens for `NOTIFICATION_APPLICATION_FOCUS_OUT` and not the window
notification, because one of the game's own windows taking focus is not the player leaving.
`is_focus_loss(what)` is static and public, so the rule is asserted without a window. **Who
pauses.** `ScreenKeys`, not `UiRoot`: `UiRoot` must not know what a screen contains, and
`ScreenKeys` is where a request on the bus becomes a screen. `pause_for_focus_loss(stack)` opens
the pause menu only where the pause key itself would work. It never toggles, so losing focus twice
leaves the menu up. This added `screen_keys.gd`, a file outside the manifest, and the reason is its
own header's table.

**The setting is OFF by default.** `gameplay/pause_on_focus_loss` is opt-in. A windowed capture
launched from a terminal, which is how this project verifies everything visual, would otherwise
pause whenever the developer clicked back to the terminal. So would a player glancing at a guide on
a second monitor. The owner's first-run playtest (forgotten #8) can flip it, and the flip is one
word.

**THE DEFECT THE FIRST WINDOWED RUN FOUND.** The capture used a temporary probe in `dev_capture.gd`,
calling `get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)` at frame 40.
That is the same call the SceneTree makes. The OS half could not be driven: Windows refused
`SetForegroundWindow` to a process launched from the background, even with `AttachThreadInput`.
The log said `Focus lost` and then `Opened 'pause' at depth 1`, and the PNG showed a stopped world
with no menu. A second probe read the stack's top screen as `tree=false size=(0.0, 0.0)`, and the
engine had printed `Parent node is busy setting up children, add_child() failed`. The engine
PROPAGATES the notification, which marks each node busy as it walks, and `UiRoot.open` had appended
to its stack BEFORE the failed `add_child`. So the player was stranded, paused under nothing. The
suite had sent the notification with `notification()`, which marks nothing busy, and passed. Two
fixes, one per half. `UiRoot` defers `announce_focus_lost`, so no listener runs inside the walk.
And `open` checks `is_inside_tree()` after `add_child`, and rolls back with a `Log.error` and
`false`, so a game's own careless listener cannot strand anyone either. Gotcha 80.

**Assertions.** `tests/unit/focus_loss_test.gd`, 30. Three on which notification counts. Three on
the propagation: nothing is heard inside it and nothing is added, then the deferred call's target
is heard once. Three on the rollback, through an inner `Opener` node that opens a screen from its
own `_notification` while the engine walks the stack. Three on the run toggle, three on the hold,
five on the rebind, six on pausing (off by default, the bus route, open, modal, and not toggled), two
on refusing over another screen, and one on the row's translation. `options_test` and
`settings_consumers_test` loop over `DEFAULTS`, so they gained 3 and 1.

**Plants.** Each exited 1, and each was restored. With the run toggle not cleared: `2498 passed,
1 failed`, `focus loss drops it — expected false, got true`. With `WM_WINDOW_FOCUS_OUT` in `is_focus_loss`:
`2500 passed, 2 failed`, `losing the application's focus is a focus loss — expected true, got
false`. With the rollback in `open` disabled: `2498 passed, 4 failed`, starting with `a screen
opened mid-propagation is refused — expected false, got true`. With the synchronous emit restored, the suite printed the engine's own `add_child() failed`, and
`the engine's propagation is not answered inside itself — expected 0, got 1` and `so nothing is
added to the stack mid-walk — expected 0, got 1` both failed.

**Photographed windowed**, 960×540, `--new-game --time=18:40 --freeze-time`, frame 90, with the
setting on in `user://settings.cfg`. The pause menu is drawn over the dimmed courtyard with
Resume focused, and the log shows `Focus lost` and then `Opened 'pause' at depth 1` with no engine
error. The control run, with the setting off, shows the courtyard running with the interact prompt
up and no menu. Both PNGs were looked at. The probe was removed (`git status src/systems` clean), and
the player's `settings.cfg` was restored from a copy.

**Budgets**, measured on a `main` worktree and after: `settings.gd` 141 → **142 of 150**, which
leaves T6.7 eight lines. `ui_root.gd` 103 → 116, `screen_keys.gd` 108 → 118,
`player_controller.gd` 171 → 174, `interaction_sensor.gd` 177 → 180 and `rebind_screen.gd` 79 → 80,
all of 250. `events.gd` 47 → 48 of 150. Nothing tight was touched.

**Not in scope.** Font fallback (T6.6), dialogue skip and auto-advance (T6.7), closing the list
(T6.8). Getting focus BACK does nothing: the pause menu waits for the player, and resuming on
refocus would be the surprise this setting exists to prevent.

**Scope.** `5.10.0`, a MINOR. Suite 2,471 → 2,504: +33: 30 in the new `focus_loss_test`, 3 in `options_test` and 1 in `settings_consumers_test` for the new setting's row and consumer, 2 in `record_shape_test` for this row's own package id, and −3 in `doc_counts_test`, because the three historical `seventy-nine` lines in `WORK_PACKAGES.md` became digits; every other case unmoved.

**Commit:** `f0805ce` on `claude/t6-5-focus-loss`, PR #71, targeting `main`, merged as `26f48c1`; no separate CI-record commit was made. Filled in by T6.6, which also took the stripped count from the CI job log (`Ladder (stripped template)`, job 109373463415: `=== 2430 passed, 0 failed, 25 skipped ===`; full job 109373463289: `=== 2504 passed, 0 failed, 0 skipped ===`). `TESTING.md` had kept T6.4's stripped `2397` through T6.5; T6.6 replaces it.

## T6.6 · Text in any script renders, not as tofu — **DONE**

The owner chose both scripts: Bengali, whose conjuncts need real shaping, and CJK, which needs
thousands of glyphs. The manifest asked for a capture against tofu before the change, and that is
where the row's first finding came from.

**Windows hid the defect.** The before capture, with the engine's defaults, drew Bengali, Chinese
and Japanese correctly and no box at all. `ThemeDB.fallback_font` is a `FontFile` with
`allow_system_fallback = true`, and Windows carries Nirmala UI and YaHei. So the defect is
invisible on the machine the base is written on, and real on a Steam Deck or a bare Linux box. The
capture that counts switched system fallback off on every font. Before the change, every non-Latin
glyph was a hex box. After it, every one was drawn, with system fallback still off, so only the
bundled fonts could have drawn them.

**The fonts.** Downloaded with the owner's permission, which named each file, its source and its
size: `NotoSansBengali[wdth,wght].ttf` (464 KB) and `NotoSansSC[wght].ttf` (17.8 MB), each with its
`OFL.txt`, from `github.com/google/fonts`, plus fontTools 4.66.0 from PyPI to cut the subset. The
Bengali font is committed unmodified. The SC font is subset to 8,392 code points (GB2312's 6,763
hanzi, JIS level 1 and one row of level 2, kana, CJK punctuation, full/half-width forms) and pinned
at weight 600: 2.8 MB. The licence reserves only the name `Source`, which the subset does not use.
The recipe is in `ART_CONTRACT.md` § Fonts.

**Weight 600, found by looking.** The first after capture drew every Bengali and CJK line visibly
lighter than the Latin beside it, because the engine's default is Open Sans SemiBold. The chain
asks the variable Bengali font for `wght` 600 through a `FontVariation`, and the SC subset was
re-cut at 600. The second capture matched.

**The theme names no font — the second finding, and the manifest's line it departs from.** The
manifest said to put the chain in `ui_theme.tres`, and the first version did. It passed on the
working copy. A copy of the tree with no `.godot/`, which is what CI and every consumer start
from, printed `Parse Error: [ext_resource] referenced non-existent resource` twice on the first
`--import`. The project theme is `gui/theme/custom`, which the engine loads at startup, before the
filesystem scan has imported the fonts. That is exactly what rung 2 greps for. So the chain is its
own resource, `assets/fonts/font_chain.tres`, and `UiRoot.install_font_chain(theme, path)` puts it
into the project theme at boot. `UiAccessibility` and `UiRowStyles` already change the project
theme at runtime, which is the precedent. A theme that already has a `default_font` is left alone,
because a game that set its own type did it on purpose. After the move, the fresh-tree import
printed 0 `Parse Error` lines, and the fresh boot logged `Font chain installed: 2 fallback(s)`. A
Label on screen before the install picks the font up, which the capture showed. Gotcha 81.

**Assertions.** `tests/unit/font_chain_test.gd`, 25. Five on the chain: a FontVariation, no base
font, two fallbacks, Bengali then CJK. Five on coverage: the engine font has no Bengali and no
hanzi, the Bengali link has Bengali, and the CJK link has hanzi and kana. Six on SHAPING, which
runs headless because HarfBuzz is not the rasteriser: ক্ষ is three code points and ONE glyph from
the Bengali font, the hanzi and kana come from the subset, and Latin still comes from the engine
font. That last one matters because the Bengali font carries Latin too. Three read the theme from
disk and find no font in it. Five cover the install rule, and one checks both licences.

**The `tr_n` check, as the manifest asked, before any plural support.** Every `{…}` in
`strings.csv` was read. `x{count}`, `{have} / {need}`, `{standing} of {needed}` and `{percent}%`
carry no noun, so they need no plural form. One does: `RestPoint` sends `{hours}` =
`floori(minutes / 60)` into a single key, so a rest under two hours reads "1 hours" or "0 hours
slip past". The key is demo content, but the count comes from a template system, so every game
meets it. That is **T6.13**, and it was not built here.

**Plants.** Each exited 1, and each was restored byte-identical. With the chain's two fallbacks swapped: `2523 passed, 8 failed`, starting with `fallback 0 is the Bengali font — expected res://assets/fonts/NotoSansBengali-Variable.ttf, got res://assets/fonts/NotoSansSC-SemiBold-subset.ttf`. With `install_font_chain`'s check for an existing `default_font` removed: `2530 passed, 1 failed`, `a theme with its own font keeps it — expected true, got false`.

**Photographed windowed**, 960×540, through a temporary `extends SceneTree` probe in
`src/systems/debug/`. The probe drew four 64 px Labels (Latin with é and ñ, Bengali with ক্ষ স্ত্রী
শ্রদ্ধা যুক্তাক্ষর, Chinese, Japanese), switched `allow_system_fallback` off, and for the after
capture added a real `UiRoot`, so the install path under test is the shipped one. Before: the Latin
line drawn, and every other glyph a hex box. After: all four lines drawn, weights matched, and Latin
pixel-identical to before. Both PNGs were looked at. The probe was removed, and
`git status src/systems` is clean.

**Budgets.** `ui_root.gd` 116 → 127 of 250. The test is 105 code lines. Nothing tight was touched.

**Not in scope.** Dialogue skip and auto-advance (T6.7), closing the list (T6.8), plural forms
(T6.13). There is no Bengali or CJK locale: `strings.csv` keeps `en` and `en_XA`, and a game adds
the column. Right-to-left text stays deferred. Hangul is not in the subset.

**Scope.** `5.11.0`, a MINOR. Suite 2,504 → 2,533: +29: 25 in the new `font_chain_test`, 2 in `record_shape_test` for this row's own package id, and 2 in `docs_test` for the two font paths the board's plant record names; every other case unmoved.

**Commit:** `487d4fd` on `claude/t6-6-font-fallback`, PR #75, targeting `main`, merged as `db0d6ec`; no separate CI-record commit was made. Filled in by T6.9, which also took the stripped count from the CI job log (`Ladder (stripped template)`, job 109434179199: `=== 2459 passed, 0 failed, 25 skipped ===`; full job 109434179375: `=== 2533 passed, 0 failed, 0 skipped ===`).

## T6.9 · Running the suite destroyed the developer's real saves — **DONE**

**Reported by the owner, taken ahead of T6.7.** `menus_test.gd` and `confirm_test.gd` each said
`THIS CASE OWNS user://saves FOR THE RUN`, deleted every slot at set-up, then wrote slots, all
against `SaveSystem.save_dir`. Neither called `SaveFixture.activate()`, so that was still
`DEFAULT_SAVE_DIR`. **Numbered T6.9, not inserted as T6.7**, so that no planned row's id, manifest
or chip prompt moves. A suffix was not available either: `record_shape_test.gd` reads a package id
as `T<n>.<n>`, so `T6.3a` would have been read as T6.3.

**Measured red before anything was changed.** Seven sentinel files were planted in the real
`user://saves`: `slot_00.json` to `slot_05.json` plus `autosave.json`, each naming itself. The
unchanged suite printed `=== 2437 passed, 0 failed, 0 skipped ===` and exited 0, and **all seven
were gone**.

**It was fourteen cases, not three.** Every case touching the store was found by grepping for
`save_to_slot`, `delete_slot`, `has_slot` and `request()`. T5.22 had redirected `core_test`,
`save_dir_test` and `save_recovery_test`; the rest never had been. `settings_effects_test.gd`,
which the report asked about, is one of them: it writes the autosave and all six manual slots,
then clears every slot. **Plant: only `menus`, `confirm` and `settings_effects` redirected.** The
suite was still green and **five of seven were lost**: slots 2 to 5, from `pickups`, `smoke`,
`traversal`, `dialogue`, `equipment`, `world_map` and `character_depth`, and the autosave, from
`settings_consumers_test.gd`'s `_clear_autosave`.

**The fix is one call in each of the fourteen**, commented where it stands:
`SaveFixture.activate()` at the top of `_set_up` in `confirm`, `menus`, `dialogue` and `npc`, and
directly after `plan()` in `run()` for `character_depth`, `equipment`, `items`, `path_actions`,
`pickups`, `settings_consumers`, `settings_effects`, `smoke`, `traversal` and `world_map`. Nothing
in `src/`, `tools/` or `tests/framework/` changed. The runner already called
`SaveFixture.deactivate()` after every case. The `menus` and `confirm` headers now say they own
the SCRATCH store and never `user://saves`.

**Fourteen files is over the board's "about 8".** Splitting was rejected: the rule exists so that a
package fits in one chat, and this is 42 inserted lines. Half the cases redirected would still
fail the only proof that matters, a real save surviving a run.

**Green.** All seven sentinels survive, each still naming itself, and the suite is unchanged at
2,437 before the documentation. The sentinels were then removed and the directory is empty again,
as it was before this row. `TESTING.md` § fixtures now carries the rule: any case that saves,
through any path, activates first, because nothing fails when it does not.

**No new gotcha, and that was a choice.** This is gotcha 79's lesson again: T5.22 fixed the sites
it had in front of it, not every site matching the pattern. The instance is appended to 79 rather
than given a number of its own. A new number would have meant rewriting three historical lines on this board,
which `doc_counts_test.gd` reads as claims about the count.

**What still is not gated.** Nothing makes a NEW case that saves without activating fail. The
runner cannot see a write-then-delete in an empty directory, the ordinary state on CI. The
structural answer is a runner that activates the scratch store before every case, and
`save_dir_test.gd` would have to stop asserting the default at entry. That design question was
recorded, not built.

**Scope.** `5.11.1`, a PATCH, test-only. T6.4, T6.5 and T6.6 merged to `main` while this row was open, and the branch merged each in. `slot_header_test.gd` activates the scratch store itself, and `focus_loss_test.gd` and `font_chain_test.gd` do not touch it. Suite 2,533 → **2,535**, +2, both in `record_shape_test` for this row's own package id; every other case unmoved, the fourteen changed cases included.

**Commit:** squash-merged to `main` as `8436c69`, PR #70, from `claude/t6-9-suite-saves`. Filled in by T6.11 at its second merge of `main`.

## T6.10 · A capture or debug launch wrote over the developer's real saves — **DONE**

**Found by T6.9, while proving it.** The ladder's last rung is
`--resolution 960x540 --quit-after 90 -- --new-game --shot=<path> ...`. `--new-game` starts a real
run, so T5.10's `Autosave` writes `SaveSystem.AUTOSAVE_SLOT` a frame after the area arrives and
again on quit. Every worktree on the machine shares one `user://`, because `config/name` is the
same, so a capture in any session overwrote the developer's own autosave. Reading the debug
directory for every other writer found three probes that are worse: `--save-state`/`--load-state`
(`dev_probes.gd`) and `--cross-area-save` delete the slot they used. **Numbered T6.10**, after
T6.9, for T6.9's reason: no planned row's id moves.

**Measured red first.** A sentinel `autosave.json` was planted in the real, empty
`user://saves`. One capture on T6.9's tip logged `Slot 6 written (6 sections)`, and the file was
the capture's autosave.

**Decided: redirect, not suppress.** Turning the autosave off for a capture would stop one writer
of three. It would also photograph a game that behaves differently from a player's, without the
`Autosaved.` toast, and it would make the `--autosave-write`/`--autosave-continue` pair, which
exists to prove the autosave works, prove nothing. Every writer goes through
`SaveSystem.save_dir`, the public seam T5.22 made, so one assignment covers the autosave, every
probe and every console `save`. `save_system.gd` did not change and stays at 179 of 180.

**Decided: any user argument is a debug launch, not only `--shot`.** `--save-state` shoots
nothing and deletes a slot. A plain editor run passes no arguments and keeps the real store, so
playing and saving still mean what they say. `--real-saves` is the way back, for a staged launch
that should write the real store.

**Built.** `src/systems/debug/dev_saves.gd`, `class_name DevSaves`, the first debug node in
`game_root.tscn`. It is a new file rather than a branch in `dev_capture.gd` or `dev_stage.gd`,
because neither owns where saves go: one owns the shutter, the other the world's state. The pure
static `save_dir_for(arguments)` decides and `_parse_arguments` applies it, logging the redirect.
The scratch directory is **never emptied**, because the probe pairs span two processes. It is
**not** `SaveFixture.ROOT`, which `activate()` empties, so a suite in another session cannot eat
a pair's autosave. Released builds return at once, like every debug file.

**Found on the way: `--autosave-continue` had been broken since the menu began naming the
autosave.** It looked for `Continue — Slot 7`, and the row reads `Continue — Autosave`. It failed
the same way against the real store with `--real-saves`, so this was not the redirect. Fixed in
`_press_continue`, and the pair round-trips through scratch: posed `day=4 time=22:15 weather=4
carrying=1`, restored `area='lantern_hall' day=4 time=22:16 weather=4 carrying=1`.

**Assertions.** Seven in `dev_tools_test.gd`: no arguments leave the store alone; the capture's
arguments, and a probe's with no `--shot`, go to scratch; `--real-saves` keeps the real store;
scratch is neither the real store nor the suite's; `DevSaves` is the first debug node in the
scene. `_every_debug_flag_has_a_node_to_parse_it` now counts seven files. **Plant:**
`save_dir_for` returning `""` always, the unfixed rule, failed exactly the two scratch
assertions, exit 1. The redirect itself cannot be driven by the suite, whose process has no user
arguments, so the sentinel run is its proof.

**Not done: `--locale=` writes the real `user://settings.cfg`.** `dev_capture.gd` sets the locale
through `Settings.set_value`, which persists, and `Settings.PATH` is a `const`. Same class of
harm, but its fix is a `src/core` seam in a file at a tight budget, so it is its own task.

**Scope.** `5.12.0` (claimed `5.10.0`; renumbered at T6.11's merge of `main`), a MINOR. Suite 2,473 → **2,483**, +10: 8 in `dev_tools_test` (seven new, and one more file in the wired-node count) and 2 in `record_shape_test` for this row's own package id; every other case unmoved.

**Commit:** on `claude/t6-10-capture-saves`, stacked on `claude/t6-9-suite-saves` (PR #70), PR
targeting `main`, PR #72, squash-merged as `2fe62ae` from branch head `243d242`. Commit `a4ba31a`, filled in by T6.11; the merge SHA by T6.7. **Version collision to resolve at merge:** T6.5's PR #71 also
claims `5.10.0`; whichever of the two merges second takes `5.11.0`.

## T6.11 · A debug launch, and every suite run, wrote the developer's real settings — **DONE**

**Found by T6.10, which recorded it undone.** `dev_capture.gd`'s `--locale=` goes through
`Settings.set_value` on purpose, so the capture photographs the path a player takes, and
`set_value` calls `save()`, which wrote `Settings.PATH`, a `const`. **Numbered T6.11**, out of
number order for T6.9's reason: no planned row's id moves.

**Measured red first, and it was worse than reported.** A sentinel `settings.cfg` holding
`locale="en"` and a `[sentinel]` section, on T6.10's tip `a4ba31a`: the ladder's capture with
`--locale=en_XA` rewrote it to `locale="en_XA"`, and **a green suite run, `2483 passed, 0 failed`,
left it at zero bytes**, because five cases call `Settings.reset_to_defaults()`, which clears the
config and saves. The developer's real file was in fact a 0-byte file last written in the same
minute as `user://test_saves`. T6.10 had not suspected the suite at all.

**Decided: redirect, not "don't persist".** A switch that skipped `save()` would stop the write,
and also stop the save path running at all in every capture and every case, so a broken `save()`
would pass the whole ladder. A redirect runs it exactly as for a player, into scratch, which is
T6.10's reasoning about the autosave unchanged. `Settings.file_path` is a var on T5.22's
`SaveSystem.save_dir` pattern, defaulting to `PATH`. **`PATH` keeps its name**, so no game that
reads it changes, which is what keeps this a MINOR.

**Decided: writes only, no reload.** `Settings` loads in its own `_ready`, before `GameRoot`'s
first child, so `DevSaves` cannot move the READ without re-loading and re-applying display and
locale mid-launch. It does not need to. Reading the real file is harmless, and it is what a
capture should show: the developer's game. Re-reading scratch would be actively wrong, because
one capture's `--locale=en_XA` would then persist into the next capture that did not ask for it.
So the scratch file is written and never read.

**Decided: `DevSaves`, not a sibling.** The rule is the same (any user argument, `--real-saves`
opts out), and two nodes holding one rule is a place for it to drift. `DevSaves` now OWNS where a
debug launch's saves and settings are written. `_parse_arguments` became the static
`apply(arguments) -> bool`, so the suite drives the real assignments. **The suite is redirected
by the runner, once, before the first case**, not per case like `SaveFixture.activate()`: a
settings write is not something a case opts into, and a per-case switch is the one T6.9 recorded
that a new case can forget. The path is `SaveFixture.SETTINGS_PATH`.

**Assertions.** Nine in `dev_tools_test.gd`: the suite writes to its scratch; no arguments
redirect nothing and leave the path; the capture's arguments move settings and saves; a setting
then written lands in the scratch file; `--real-saves` redirects nothing; scratch is neither the
player's file nor the suite's. **Three plants**, each exit 1 on exactly its assertions: deleting
the settings line from `apply` (2 failed), `save()` back to the fixed path (1), and deleting the
runner's line (1).

**Proof isolated from other sessions.** The first green run was contaminated: another session
was running its own sentinel experiment on the same shared `user://` at the same minute. Every
proof after that ran with `APPDATA` pointed at a scratch directory, so `user://` was private.

**Not done.** On a machine with no settings file yet, boot writes defaults to the real path,
before anything can redirect it. That creates a file and overwrites nothing. The suite's own
process still READS the developer's real settings, which is why the runner's locale pin stays.

**Scope.** `5.13.0` (claimed as `5.11.0` before the merge of `main`), a MINOR. `settings.gd` 141 → 142 of 150; `dev_saves.gd` 20 → 23.

**Commit:** on `claude/t6-11-dev-settings`, stacked on `claude/t6-10-capture-saves` (PR #72), PR
#74 targeting `main`, squash-merged as `9d8c34f`; filled in by T6.12. **Renumbered at the merge of `main`:** T6.5 took
`5.10.0` and T6.6 `5.11.0` there first, so the stack lands after them as T6.9 `5.11.1`, T6.10
`5.12.0` and this row `5.13.0`. T6.6's new plural row, which it numbered T6.10, became **T6.12**, then **T6.13** at T6.12's merge, whose DONE row already held T6.12, and **T6.14** at T6.13's.

## T6.12 · Nothing failed a case that saved without activating the scratch store — **DONE**

**The gap T6.9 recorded.** T6.9 redirected fourteen cases that wrote the developer's real
`user://saves`, and `TESTING.md` stated the rule. Nothing enforced it. A diff of the directory
around each case cannot see a write followed by a delete in an empty directory, and empty is the
ordinary state on CI. **Numbered T6.12**, after T6.10, with T6.11 then in progress on another
branch. The owner confirmed taking it before T6.5, which merged to `main` while this row was open.

**Decided: both of T6.9's options, not one.** (b) alone, a check, goes red only AFTER the case has
written or deleted a real slot: the first run of a bad case still costs the developer their
saves. (a) alone, activating for every case, makes the omission harmless and silent, and silence
is how fourteen piled up. So:

- **Parked.** `SaveFixture.park()` points the store at `UNCLAIMED`, `user://test_saves_unclaimed`,
  emptied, and the runner calls it before every case. No case starts on the shipped default, so
  a forgotten `activate()` cannot reach a real save, crash or no crash.
- **Checked.** The runner listens on `Events.game_saved` and `game_loaded`, signals `save_to_slot`
  and `load_from_slot` already emit for a game's own listeners, so no seam was added to `src/`.
  A save, or a load with a file behind it, while `save_dir` is `UNCLAIMED` or `DEFAULT_SAVE_DIR`
  fails the case by name. A file left in `UNCLAIMED` fails it too, for a plant nothing announces.
  A case that points the store at a scratch directory of its own, as `save_dir_test` does, has
  made a choice and is not flagged.

**Why loads count.** `save_recovery_test` plants files by hand and deletes them, and never saves,
so the first version of the check passed it with `activate()` removed. Its loads are the tell: on
the old default they read whatever the developer kept in that slot. Only a load with a FILE
behind it counts, because `item_count_test` emits `game_loaded` by hand to stand in for one, and
that tripped the first version of the load check.

**`save_dir_test` changed its entry claim**, from "the store starts on the shipped default" to
"the store starts parked", plus two assertions for `is_unclaimed`. 18 → 20.

**Plants, each with seven sentinel saves in the real `user://saves`:**
- `confirm_test` without `activate()`: exit 1, `saved slot 3 in user://test_saves_unclaimed`.
- `menus_test` without it: exit 1, `saved slot 2 …, saved slot 6 …`, the autosave among them.
- `save_recovery_test` without it: exit 1, `loaded slot 4 …`.
- Every run, and the clean run: sentinels intact 7 of 7.

**Not done: two suite runs at once still share `user://test_saves`.** Found while proving this: a
clean run failed eleven assertions in `menus_test` and `smoke_test` because another session's
suite overlapped it, and each `activate()` empties the directory. The re-run was green. Flagged as
its own task: per-process scratch directories.

**Landed after the whole stack.** T6.5 and T6.6 merged to `main` while this row was open, then
T6.9 (`5.11.1`, `8436c69`), then T6.11 (`5.13.0`, `9d8c34f`), which carried T6.10 (`5.12.0`)
with it. So this row is `5.13.1`, a PATCH on top. **The planned plural-form row moved twice.**
T6.6 numbered it T6.10, colliding with the capture-saves T6.10. T6.11's merge renumbered it
T6.12, colliding with this row, which was DONE with PR #73 and commits under that name. It is now
**T6.13**: a planned row has only documents to update, so it moves, not the DONE row.

**Scope.** `5.13.1`, a PATCH. Test-only: `tests/test_runner.gd`,
`tests/framework/save_fixture.gd`, `tests/unit/save_dir_test.gd`, and the documents. Suite 2,556 on `main` at `9d8c34f` → **2,560**, +4: 2 in `save_dir_test` and 2 in `record_shape_test` for this row's package id; every other case unmoved.

**Commit:** on `claude/t6-12-save-guard`, PR #73, targeting `main`, squash-merged as `76cd32d` from branch head `c81729f`; no separate CI-record commit. Filled in by T6.7, with the counts from the CI job log (`Ladder (stripped template)`, job 109474633431: `=== 2486 passed, 0 failed, 25 skipped ===`; full job 109474633769: `=== 2560 passed, 0 failed, 0 skipped ===`). `TESTING.md` still stated `2397` stripped when T6.7 branched from it.

## T6.7 · Dialogue for fast and slow readers — **DONE**

Forgotten #5 asked for text speed and an instant skip. Text speed was already there:
`gameplay/text_speed` scales the reveal. What was missing was the skip, and for the reader at the
other end, a way for the conversation to move on without a key press.

**A skip walks the conversation, it does not jump it.** The screen's header already said why
escape must not dismiss a conversation: a conversation has effects, and a player who escapes out
of the middle skips the effect of the node they were about to reach. So cancel (Escape, or the
pad's B) now calls `DialogueScreen.skip()`, which drives the runner through `advance()` node by
node. Every node on the way is ARRIVED at, and its effect fires exactly as if it had been read.
That is the same rule, not an exception to it: nothing is jumped over, only not read.

**At a choice, the skip stops.** A branch is the player's to take. The skip stops at the first
node offering a choice, shows the choice whole (the reveal is finished and the buttons appear),
and a second skip there does nothing until the player answers. With no choice ahead, it runs to
the end of the conversation and the box asks to close. A cycle of plain lines is authorable, so
the loop stops after 512 lines with a warning rather than hanging the game on one key press.

**Auto-advance is opt-in.** `gameplay/dialogue_auto_advance`, off by default, on the reasoning of
`gameplay/pause_on_focus_loss`: a default that hurries a slow reader is the wrong default. On, a
line that has finished revealing is held for 1.5 s plus its length at 15 characters a second, all
divided by the text speed, because a player who slowed the text is a slower reader. The hold is
counted from the frame the line became whole, so a line that arrived whole under reduce-motion
is held just as long. It never answers a choice. The hint reads "Auto" while it is on, and
redraws the moment the setting changes.

**Cancel was free in a conversation.** `closes_on_cancel` is false for a conversation, so `UiRoot`
already ignored cancel there, and the pause key refuses while a screen is open. No binding was
added and none moved. The hint names the key through `KeyBindings.text_for(Actions.CANCEL, pad)`,
so a rebind renames it.

**Assertions.** `tests/unit/dialogue_speed_test.gd`, 25, split from `dialogue_test.gd` because
that file would have gone to 305 of 250 lines. Fifteen on the skip: it stops at the menu with the
conversation still running, the choice shown and the line whole; both nodes were announced; an
effect planted on the menu fired once, and a second skip fires nothing; after the player answers,
a skip through a plain line lands on the menu again and the effect fires again, as reading would
have; after the closing line is picked, a skip ends the conversation and the box asks to close
exactly once. One on a cycle. Nine on auto-advance: off by default, and off it waits however
long; on, the hint changes and still names the skip key; half the hold is not enough and the
whole hold is; at the menu it waits. The frame clock is stepped by calling `_process` with a
chosen delta, because the suite is synchronous.

**Plants.** Each exited 1, and each was restored. **The first stayed green, and that is the
finding.** Deleting `not _waiting_on_choice()` from the skip loop changes nothing: the runner's
`advance()` already refuses at a choice, so the loop spins to its limit and stops at the menu
anyway. The screen's check stays as a second guard. The plant that counts is the tempting wrong
skip, one that calls `runner.stop()`: `2549 passed, 13 failed`, starting with `a skip stops at
the choice — expected menu, got` (nothing, because the conversation had ended). The first run
of that plant failed on script errors instead, `Invalid access to property or key 'node_id'`,
so the case now reads the node through a null-safe helper and fails on named assertions.

**Photographed windowed**, 960×540, through a temporary `--probe-auto-advance` flag in
`src/systems/debug/dev_screens.gd` that turned the setting on in memory without saving it. At
frame 90: the greeting mid-reveal, and the hint `Auto  E to continue  Escape to skip`. At frame
1,400 of the same scenario: the menu, `Well? Ask, or do not.`, with its three choices and focus on
the first. Nothing had been pressed, so auto-advance moved the line and then waited at the
choice. Both PNGs were looked at. The probe was removed, and `git status src/systems` is clean.

**Found while photographing, and not this row's.** The second capture ran at about 2.3 frames a
second, 1,500 frames in 638 s, while other sessions' suites were loading the machine. It logged
`Keeper cannot reach 'dais'` twice, which is the message gotcha 21's persistence guard in
`npc_brain.gd` prints. Why it fired at that frame rate was not investigated; nothing on the
dialogue path touches it. The 90-frame capture and the ladder's own rung were clean.

**Budgets.** `settings.gd` 143 (after T6.11) → 144 of 150, which leaves six lines. `dialogue_screen.gd` 143 →
186 of 250. The new test is its own file.

**Not in scope.** A backlog of past lines (its own row), closing the list (T6.8), plural forms
(T6.14).

**Scope.** `5.14.0` (claimed `5.12.0`, renumbered at the merge of `main`, where T6.10 to T6.12 had taken `5.12.0` to `5.13.1`), a MINOR. Suite 2,560 on `main` at `76cd32d` → 2,591, +31: 25 in the new `dialogue_speed_test`, 3 in `options_test` and 1 in `settings_consumers_test` for the new setting's row and consumer, and 2 in `record_shape_test` for this row's own package id; every other case unmoved.

**Commit:** on `claude/t6-7-dialogue-speed`, PR #78 targeting `main`. No SHA, per item 6. CI on `e6db60b`, PR #78: `Ladder (stripped template)`, job 109480897827: `=== 2517 passed, 0 failed, 25 skipped ===`; `Ladder (full checkout)`, job 109480898120: `=== 2591 passed, 0 failed, 0 skipped ===`. `TESTING.md` now states the stripped `2517`.

## T6.13 · Two suite runs at once, in two worktrees, broke each other — **DONE**

**Found by T6.11, which saw it and recorded it undone.** `user://` is keyed on `config/name`, so
every worktree on the machine shares it, and every scratch path the suite used was a fixed name
under it: `user://test_saves`, `test_saves_stand_in`, `test_settings.cfg`, `test_fixtures`,
`test_export_empty`, `content_scan_test`. `SaveFixture.activate()` and `deactivate()` EMPTY their
directory and `Fixtures.activate()` rewrites its own, so a second suite deleted the first's slots
and fixtures mid-case. **Numbered T6.13**, out of number order for T6.9's reason; T6.12 was PR #73, a sibling that merged first.
T6.11's SHA, per item 6: `15775bd`.

**Measured red first, with nothing else able to touch it.** A scratch worktree at `15775bd`, two
suites sharing one private `APPDATA`, started at four offsets: 0.3s apart failed **15 and 8**, 6s
apart 2 and 1, 2s and 12s apart passed. The failures were saves (`the autosave slot accepts a
write — expected 0, got 12`), fixture content (`QuestDb reports a bad file in its root — expected
1, got 2`, a planted file from the other run's scan), a dialogue case crashing on a conversation
the other run had just rewritten, and T6.11's own settings assertion.

**Decided: one directory per process, `user://test_runs/<pid>`, owned by the new
`tests/framework/run_scratch.gd`.** Every scratch path is under it: `SaveFixture.root()` and
`settings_path()`, `Fixtures.root()` and its five `*_dir()`, and the per-case directories in
`content_scan_test`, `export_test` and `save_dir_test`. They became functions because the name
carries the pid. The runner calls `RunScratch.begin()` before anything else and `finish()` after
the report. `DevSaves.SCRATCH_DIR` and `SCRATCH_SETTINGS` stay where they were, and
`dev_tools_test` now asserts neither is under `RunScratch.PARENT` at all, a stronger claim than
"differs from this run's root". **The old fixed paths are left alone**: a suite on an older base
may be using them at this moment, and deleting them would be this defect.

**The first design failed its own proof, twice, and both are worth keeping.** *(1)* The case that
tested pruning passed a fake liveness answer against the SHARED parent, which called every other
run dead: a concurrent run lost its directory, 12 failures in `save_recovery_test`. A case now
prunes a parent inside its own root, and `prune(parent, stale_after)` takes both. *(2)* Liveness
was `OS.is_process_running(pid)`, and two pairs at 6s and 12s still failed 3, all writes to
settings and bindings finding their directory gone. Measured with a probe: on Windows it answers
**false for explorer's pid and true only for a child from `OS.create_process`**, so each run's
`begin()` deleted every other live run. **Liveness is now a heartbeat file** the runner writes
before every case; a directory is pruned only when its heartbeat is over `STALE_SECONDS` (900)
old, and one with no heartbeat yet is kept, so deletion needs positive evidence.

**Found on the way: the suite deleted the developer's key bindings.** `options_test` rebinds a key
and its tear-down calls `Actions.reset_bindings()`, which removed `user://input.cfg`, the real
file, on every run. `KeyBindings.PATH` was a `const`; `KeyBindings.file_path` is a static var on
T6.11's pattern, and the runner points it at `RunScratch.path("input.cfg")`.

**Assertions.** 28 in the new `tests/unit/run_scratch_test.gd`: the root is named for this
process and exists; two pids never share one; twelve scratch paths, including the three the runner
pinned or parked and the parking directory added at the merge, are inside it; the player's bindings file is not the one written; a fresh heartbeat
survives the real threshold and a stale one is removed, nested, and reported; a directory with no
heartbeat yet, this process's own, and a folder not named by a number all survive; this run's
heartbeat is fresh; `remove_tree` takes a nested tree and answers true when absent. Plus
`dev_tools_test`'s three changed ones. **Four plants**, each exit 1 on exactly its own: see
DEVLOG.md.

**Merged after T6.12, and T6.12's parking directory moved in.** T6.12 landed first with
`SaveFixture.UNCLAIMED`, the fixed `user://test_saves_unclaimed`, which `park()` empties before
EVERY case. At the merge it became `SaveFixture.unclaimed()`, `RunScratch.path("saves_unclaimed")`,
and every caller moved. Two suites on one private `APPDATA`, with `settings_effects_test`'s
`activate()` planted out so something lands in the parking directory: the fixed name failed 6 and 5
at 0.3s, three and two of them the other run's doing; per run, 1 and 1 at every offset, only the
planted case. Unplanted, the merged tree passes 2,621 on both sides at 0.3s, 2s, 6s and 12s.

**Not done.** `Log` stays disabled under the suite, so `user://logs` is not shared by it.
**Over the size rule:** twelve code files, most one-line call-site renames; the two new files are 124 code
lines.

**Scope.** `5.15.0` (claimed `5.12.0`, renumbered at the merge of `main`, where T6.12 and T6.7 had
taken `5.13.1` and `5.14.0`), a MINOR. All of 250: `key_bindings.gd` 105, `fixtures.gd` 81,
`test_runner.gd` 191 with T6.12's check, `run_scratch.gd` 48, `dev_tools_test.gd` 224.
Suite 2,591 on `main` at `287e783` → **2,621**, +30: 28 in the new `run_scratch_test` (26 from T6.13, and 2 from the merge for the parking directory) and 2 in `record_shape_test` for this row's own package id; every other case unmoved. Measured per case against `main`, after the documentation landed. The stripped count is CI's.

**Commit:** `8021b59` on `claude/t6-13-parallel-suites`, stacked on `claude/t6-11-dev-settings` (PR #74),
PR #77 targeting `main`. Filled in by T6.8.

---

## T6.8 · Close the list, and gate it — **DONE**

**The criterion, as T6.0 wrote it.** Every "Commonly forgotten" item marked DONE or CLOSED (game's)
with a package id, and a text-scan assertion that fails if one is not. Last in the phase, because
its gate could not pass until every row above had landed.

**The gate is a marker, not a reading.** `tests/unit/forgotten_list_test.gd` finds the section by
its heading, splits it at `N. **`, and asks each item for `**DONE — <id>` or
`**CLOSED (game's) — <id>`, where `<id>` has `record_shape_test.gd`'s package shape and must be
findable on this board by the whole id, so `T5.1` is not satisfied by `T5.10`. It also fails a
numbering gap, and fails an empty scan by its first assertion, so a renamed heading cannot pass by
finding nothing. Its MUST NOT line: it never judges whether a verdict is right. The plan is
`2 + 2 × items`, computed, so a sixteenth item costs no number edit.

**Proved red on the list as it stood.** 16 failed, two for each of eight items:

| item | why the scan could not read it | now |
|---|---|---|
| #1 pause semantics | "Already handled", no id | DONE — WP-02 |
| #6 autosave indicator | `BOTH DONE — T5.10` | DONE — T5.10, both halves |
| #8 first-run defaults | no verdict at all | CLOSED (game's) — T6.8 |
| #9 reduced motion, DoF | `Both work as of T5.5` | DONE — T5.5 and T5.9 |
| #10 subtitles, speaker names | prose only | DONE — WP-05 for names; subtitles removed by T5.5 |
| #11 localization | no verdict | DONE — T5.1, gated since WP-14 |
| #12 photo mode | `CLOSED (game's) — owner decision, T6.0` | CLOSED (game's) — T6.0 |
| #13 credits | `CLOSED (game's) — owner, 2026-09-02` | CLOSED (game's) — WP-15 |

After: 32 of 32. **Two plants**, each one exit 1 on exactly its own: #8's id changed to `T6.99`
fails `names T6.99, which has a row on the board`; #14 renumbered 16 fails the numbering. The
removed-marker case is the red run above, with the real violation rather than a planted one.

**#8 is CLOSED (game's), pending the owner's playtest.** The manifest asked for the owner's
playtest verdict on first-run defaults. Asked on 2026-09-30, the owner has not playtested yet and
means to soon, so the closure stands until that playtest. The base's half is real: every default is one `Settings.DEFAULTS`
line, every one has had a consumer since T5.5, and the two T6 added are off for the player who
never opens the menu. Whether the rest are pleasant depends on a mix, a pace and a look the base
does not have. A default later found unpleasant by playing is still a defect under the playtest rule,
and becomes a row ahead of the queue.

**The phase stays OPEN.** Every exit criterion is ticked, but T6.14, the plural form T6.6 found, is
a defect inside the phase and comes next.

**Scope.** `5.15.1`, a PATCH: one new case and its `CASES` line, and documents. Suite 2,621 on `claude/t6-13-parallel-suites` at `8021b59` → **2,655**, +34: 32 in the new `forgotten_list_test` (two, plus two for each of fifteen items) and 2 in `record_shape_test` for this row's own package id; every other case unmoved. Measured per case against `8021b59`, after the documentation landed. Stripped, in CI: `2581 passed, 0 failed, 25 skipped`.

**Commit:** on `claude/t6-8-close-the-list`, built on `claude/t6-13-parallel-suites` (PR #77),
PR #79 targeting `main`, merged as `0d3585d` from branch head `49bf3c9`, after PR #77 merged as
`1566f00`. Filled in by T6.14, with the counts from the CI job log on `49bf3c9`, PR #79:
`Ladder (stripped template)`, job 109761269330: `=== 2581 passed, 0 failed, 25 skipped ===`;
`Ladder (full checkout)`, job 109761269579: `=== 2655 passed, 0 failed, 0 skipped ===`.

## T6.14 · A count that reaches a string picks its plural form — **DONE**

**The defect.** `RestPoint.perform` sent `{hours}` = `floori(minutes / 60)` into one key, so a rest
under two hours read "1 hours slip past", and one under an hour "0 hours", after the clock had
moved. T6.6's `tr_n` check found it. It is the only count in the base with a noun beside it.

**Checked first, in the 4.7 docs, and then in the engine.** The regenerated reference lists four
options on `ResourceImporterCSVTranslation` (`compress`, `delimiter`, `unescape_keys`,
`unescape_translations`) and no description at all, so the docs do not answer it. `Translation`
has `add_plural_message` and `get_plural_message`. A scratch project answered it: **4.7.2's CSV
importer reads plural forms.** A column headed `?plural` names the plural key, and a following row
with an empty key holds the next form, as many rows as the locale has forms. The locale's rule
applies: the same file imported for `fr` answered its singular for 0, English its plural. `.po`
was not needed.

**Proved red before the fix.** The new `tests/unit/plural_count_test.gd` renders the toast exactly
as `notification_toast.gd` `_show_next()` does, `tr(key).format(args)`, from what `RestPoint`
emitted, against a fixture translation it builds (a test may not name the demo key). On the old
code: `2659 passed, 8 failed`. Five were rest lines, and they showed both halves of the defect:
`tr()` on a plural row answers its FIRST form, so a thirteen-hour rest read "13 hour slips past",
and flooring made 30 and 1 minutes read "0". Three were the CSV lint on the one `{hours}` row.

**The fix.**
- `RestPoint` asks `TranslationServer.translate_plural(rested_key, rested_key, hours)` and sends
  the chosen form; the toast's own `tr()` passes resolved text through unchanged. A row with no
  plural form answers itself for any count, so a game's plain row still works (asserted).
- `hours_for(minutes)` is the nearest whole hour and never zero, since `skip_to_hour` always skips
  1 to 1,440 minutes. 89 minutes is 1, 90 is 2.
- `strings.csv` gains the `?plural` column after `keys`, empty on every row but one, and the rest
  row's second form below it. `gen_pseudolocale.gd` found `en` by name and filled `en_XA` for both
  forms; `check_content`, `check_strings` and `check_boundary` already skip an empty key.

**Plants.** Emitting `rested_key` instead of the chosen form: 3 failed. Flooring again: 3 failed.
Deleting the second form from the CSV: it went red on 1 at first, because a missing form comes
back as the key itself, which also differs from the singular. The assertion now also requires
that neither form is the key, and the same plant fails 2.

**Photographed**, windowed, standing at the bench (`--stand-by=StoneBench --interact=1`): a
59-minute rest reads "You rest a while. 1 hour slips past.", where the old code said "0 hours";
a 778-minute rest under `--locale=en_XA` reads "[~~You rest a while. 13 hours slip past.~~]".

**Deliberately not done.** The toast did not learn a `count` argument. With one counted sender
that would widen `notification_toast.gd` and `Events.notify_requested`'s contract for one caller,
and the manifest was `rest_point.gd`, the CSV and a test. `rest_point.gd`'s header says when to
move it: the second counted toast. Until then `RestPoint` is the one sender that passes resolved
text through a signal documented as taking a key, and its header says why.

**The phase closes.** Every exit criterion was ticked by T6.8; this was the last row. Phase T6 is
COMPLETE. #8's closure still stands only until the owner's playtest, as T6.8 recorded.

**Scope.** `5.16.0`, a MINOR. Suite 2,655 on `main` at `0d3585d` → **2,669**, +14: 12 in the new
`plural_count_test` (nine, plus three for the one `{hours}` row) and 2 in `record_shape_test` for
this row's own package id; every other case unmoved. The stripped count is CI's.

**Commit:** on `claude/t6-14-plural-forms`, built on `main` at `0d3585d`, PR #80, merged as `c63425e`. Filled in by the serial-packages process change (`5.16.1`), with the counts from the CI job log on `f6f0344`, run 36677397254: `Ladder (stripped template)`: `=== 2592 passed, 0 failed, 25 skipped ===`; `Ladder (full checkout)`: `=== 2669 passed, 0 failed, 0 skipped ===`.
