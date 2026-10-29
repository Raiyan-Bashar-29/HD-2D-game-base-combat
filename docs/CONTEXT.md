# Context — read this first, it takes one minute

> **In the combat fork, read [`COMBAT.md`](COMBAT.md) first.** Everything below is the upstream
> non-combat base's situation. It is still true for every system inherited from it, and still
> says "no combat", which is upstream's rule and not this repository's ([ADR-0008](decisions/ADR-0008-combat-is-in-scope.md)).

A state snapshot for a new session. `CLAUDE.md` has the *rules*; this file has the *situation*.
Keep it short. When it drifts from reality, fix it in the same commit as the change.

**Last updated:** 2026-10-16 · **T6.15 (a wandering NPC never picks a spot it cannot walk to) complete, at 5.16.2, a PATCH. Development has moved to cloud sessions, and they CAN run the windowed capture rung (see `.claude/agent-notes.md`).**
**Phases T1 to T6 are complete and stay complete. No row is open and no phase is planned; the next input is the owner's playtest, or a phase the owner opens.**

**A SELF-CHOSEN TARGET IS CLAMPED; ONLY AN AUTHORED ONE MAY BE "UNREACHABLE"** — T6.15, `5.16.2`.
The first cloud capture logged `Keeper cannot reach 'dais'`. It was not gotcha 21's timing: every
error came from a random wander offset on the dais or beside its riser. `_tick_wander` now hands
the agent `NpcBrain.reachable_point()`, the end of a real path, so the error once again means a
content defect. Anything else that invents a destination should go through the same method.
Suite 2,669 → **2,678**, measured after the docs; stripped 2,592 → 2,601.

**ONE PACKAGE AT A TIME, FROM NOW ON** — `5.16.1`, a docs-only PATCH. Phase T6 ran T6.9 to
T6.13 as five chats in five worktrees at once, and it cost renumbered rows, versions claimed by
one row and shipped by another, `main` merged back into branches up to three times, two or three
chats for the same package, and T6.13 itself. So a chat that finds another package's PR open or
its worktree unmerged **stops and tells the owner**; the chip for the next package is raised only
**after** the merge; a defect found mid-package is a board row, not a chip. The rule is at the top
of `WORK_PACKAGES.md`. **And T6.13 did not make parallel worktrees safe outside the suite**:
`user://dev_saves` and `user://dev_settings.cfg` are one directory for every worktree on the
machine, so two capture rungs at once still share them.

**A COUNT BESIDE A NOUN GOES THROUGH `translate_plural`, NEVER `tr()`.** `tr()` on a plural row
answers its first form for any count, which is why T6.14's red run read "13 hour slips past"
(gotcha 82). **4.7.2's CSV importer reads plural forms, undocumented**: the `?plural` column after
`keys` names the plural key, and the next form is a following row with an EMPTY key. `.po` was
not needed. `RestPoint` picks the form and reports the nearest hour, never zero, and
`plural_count_test.gd` fails a `{hours}` row without both forms. The toast did not learn a `count`
argument: with one counted sender that would widen a contract for one caller, and
`rest_point.gd`'s header says to move it there when a second arrives.

**#8, FIRST-RUN DEFAULTS, IS CLOSED (game's).** T6.0's manifest asked for the owner's playtest
verdict there; asked in T6.8 on 2026-09-30, the owner has not playtested yet and plans to, so the
closure stands until then:
the base keeps every default in one `Settings.DEFAULTS` line, and "pleasant" is judged against a
game's own mix and look. **A default found unpleasant by playing is still a defect**, a row ahead
of the queue.

**Regex patterns in a test are written with bracket classes, `[*]`, `[.]`, `[(]`.** The first
draft was written through a shell heredoc that turned every doubled backslash into one, so `"\*"` was
an invalid escape and the case never parsed; T4.4's `doc_counts_test.gd` met the same thing. Brackets need no escaping in GDScript or in a shell.

**The phase, in order** — manifests in `WORK_PACKAGES.md` § T6.0:

| row | what | closes |
|---|---|---|
| ~~T6.1~~ | ~~a save section from a newer build is refused; the first worked migration~~ **DONE** | the defect |
| ~~T6.2~~ | ~~the base knows the active input device; the prompt shows the right key~~ **DONE** | forgotten #4 |
| ~~T6.3~~ | ~~a reusable confirm screen; "are you sure" on overwriting a save~~ **DONE** | forgotten #7 |
| ~~T6.4~~ | ~~a slot shows where it was saved, and a damaged slot is shown as damaged~~ **DONE** | forgotten #15 |
| ~~T6.5~~ | ~~losing window focus leaves nothing latched; pausing on it is a setting~~ **DONE** | forgotten #3 |
| ~~T6.6~~ | ~~Bengali and CJK both render through a font fallback chain~~ **DONE** | structural |
| ~~T6.9~~ | ~~the suite destroyed real saves; every case that saves redirects first~~ **DONE**, out of number order | owner-reported |
| ~~T6.10~~ | ~~a capture or debug launch saves to scratch, never over the developer's saves~~ **DONE**, out of number order | found by T6.9 |
| ~~T6.11~~ | ~~a debug launch or a suite run writes scratch settings, never the developer's file~~ **DONE**, out of number order | found by T6.10 |
| ~~T6.12~~ | ~~a case that saves without activating the scratch store fails the suite~~ **DONE**, out of number order | found by T6.9 |
| ~~T6.7~~ | ~~dialogue can skip to its end and auto-advance~~ **DONE** | forgotten #5 |
| ~~T6.13~~ | ~~two suite runs at once, in two worktrees, cannot empty each other's scratch~~ **DONE**, out of number order | found by T6.11 |
| ~~T6.8~~ | ~~every forgotten item marked DONE or CLOSED, gated by a text scan~~ **DONE** | the exit criterion |
| ~~T6.14~~ | ~~a count that reaches a string picks its plural form~~ **DONE**, the last row; **Phase T6 is COMPLETE** | a defect |

**THE OWNER'S PLAYTEST OUTRANKS THIS QUEUE.** A defect found by playing becomes the next row ahead of
anything above — found, not invented, the standard every T6 row had to meet. T6.9 is the first,
numbered after T6.8 so that no planned id moves. T6.10 is the second, found while proving T6.9, T6.11 the third, found by T6.10, T6.12 the fourth, the gap T6.9 recorded, and T6.13 the fifth, found by T6.11.

Suite 2,655 on `main` at `0d3585d` → **2,669**, +14: 12 in the new `plural_count_test` (nine, plus three for the one `{hours}` row) and 2 in `record_shape_test` for this row's own package id; every other case unmoved. The stripped count is CI's.

*(Previously: T6.8 marked every "Commonly forgotten" item `DONE — <id>` or `CLOSED (game's) —
<id>`, at `5.15.1`, a PATCH, and `forgotten_list_test.gd` fails an item without that marker, an
id with no board row, or a gap in the numbering. Before the edits it failed 16; after, 32 of 32.
Suite 2,655, stripped 2,581.)*

*(Previously: T6.13 stopped two suite runs at once, in two worktrees, breaking each other, at
`5.15.0`, a MINOR. Every path the suite writes is under `user://test_runs/<pid>`, owned by
`tests/framework/run_scratch.gd`; `SaveFixture.root()`, `unclaimed()`, `settings_path()`,
`Fixtures.root()` and the five `Fixtures.*_dir()` are functions now. A new scratch path goes under
`RunScratch.path()`. **`OS.is_process_running()` is false, on Windows, for any process you did not
start**, so liveness is a heartbeat file pruned after `RunScratch.STALE_SECONDS`. It also stopped
the suite deleting the developer's `user://input.cfg`: `KeyBindings.file_path` is a var the runner
points at the run's own copy.)*

*(Previously: T6.7 let dialogue be skipped to its end and auto-advance, at `5.14.0`, a MINOR.
Cancel during a conversation calls `DialogueScreen.skip()`, which walks the runner through
`advance()`, so every node passed fires its effect; it stops at the first choice, and a second
skip there does nothing. `gameplay/dialogue_auto_advance` is off by default and never answers a
choice. The plant that stayed green was deleting the screen's own stop-at-a-choice check, because
`advance()` already refuses there; the one that counts is `runner.stop()`, 13 failed.)*

*(Previously: T6.12 made a case that saves without `SaveFixture.activate()` fail the suite, at
`5.13.1`, a PATCH, test-only. Before every case the runner parks the store at
`user://test_saves_unclaimed` and fails a case that saves, or loads a real file, while parked.
T6.9 to T6.12 landed out of number order, and the plural row moved from T6.10 to **T6.13**, now T6.14. Every
worktree shares one `user://`: for any sentinel proof give Godot a private one with
`APPDATA="$(cygpath -w <dir>)"`.)*

*(Previously: T6.11 stopped a debug launch and the suite writing the developer's real settings, at
`5.13.0`, a MINOR. `Settings.file_path` is where `save()` writes. `DevSaves` points it at
`user://dev_settings.cfg` under T6.10's rule, and the runner points it at
`user://test_settings.cfg` before the first case. Five cases call `reset_to_defaults()`, so every
green run had left `settings.cfg` at zero bytes. Writes only: the real file is still read at boot.)*

*(Previously: T6.6 made Bengali and CJK render from fonts the game ships, at `5.11.0`, a MINOR.
Windows had hidden the tofu: Nirmala UI and YaHei drew the text through system fallback, so the
before capture turned it off. `assets/fonts/font_chain.tres` has no base font and falls back to
Noto Sans Bengali, then a Noto Sans SC subset, both at weight 600. `UiRoot.install_font_chain`
installs it at boot rather than the theme naming it, because the theme loads before the first
import and a fresh clone printed `Parse Error` (gotcha 81). The `tr_n` check found `RestPoint`'s
`{hours}` reading "1 hours", now T6.14.)*

*(Previously: T6.10 made a capture or debug launch save to `user://dev_saves`, claimed as `5.10.0`,
landing as `5.12.0`, a MINOR. The capture rung's `--new-game` is a real run, so the autosave wrote
the real slot, and three probes deleted real slots. `DevSaves` redirects `SaveSystem.save_dir` for
any launch with user arguments; `--real-saves` opts out. It also fixed `--autosave-continue`.)*

*(Previously: T6.9 stopped the suite touching `user://saves`, claimed as `5.9.1`, landing as
`5.11.1`, a PATCH, test-only. Fourteen cases wrote or deleted slots there, and a green run of the
unchanged suite deleted all seven planted sentinel saves. Each case now calls
`SaveFixture.activate()` first, and all seven survive. Nothing yet fails a new case that forgets;
that is recorded in `WORK_PACKAGES.md` § T6.9.)*

*(Previously: T6.5 made losing window focus leave nothing latched at `5.10.0`, a MINOR. Measured
first, windowed: the engine already clears a held key on focus loss, so the base releases only its
own state on `Events.focus_lost` from `UiRoot`: a toggled run, a hold part-way to firing, a rebind
waiting for a key. `gameplay/pause_on_focus_loss` is off by default. The first windowed run found a
pause menu recorded and never drawn, because the engine propagates the notification, and that is
gotcha 80.)*

*(Previously: T6.4 made a save slot name where it was saved at `5.9.0`, a MINOR, and draw a damaged
file as damaged. `SaveSystem.header_provider` is an optional hook `WorldMap` sets, because `core`
may not ask `Director`; the header holds the area id and the name is localized when drawn.
`slot_info` got stricter and answers `{}` for any file the loader would refuse, so a file from a
newer build is damaged too and never becomes Continue. A damaged slot counts as occupied, so
writing over it asks first. `save_system.gd` 176 → 179 of 180.)*

*(Previously: T6.3 built a reusable confirm screen at `5.8.0`, a MINOR, and overwriting a save now
asks first. `ConfirmScreen.asking(question_key, detail, on_yes)` sets `closes_on_cancel = false`,
so escape and pause cannot answer it, and focus lands on No. An empty slot still saves at once.
The quit half of forgotten #7 was recorded rather than built: T5.10's quit-autosave answers it,
except when autosave is off or a transition is in flight.)*

*(Previously: T6.2 taught the base which input device is active at `5.7.0`, a MINOR. The pure
`InputDevice.device_for(event, previous)` decides, and mouse motion and sub-deadzone stick drift are
not a switch. `Actions` holds the answer and emits `input_device_changed` only on a change; no
autoload was added. The last pad unplugged falls back to the keyboard, and hotplug is proved by
calling the handler, since no pad exists headless. The prompts name the button through
`KeyBindings.text_for`, and that fixed a lying hint: it had said `Space to continue` while Space
advanced nothing. The enum is `GameEnums.DeviceKind` because `InputDevice` collided with the class.)*

*(Previously: T6.1 refused a save section from a newer build at `5.6.3`, a PATCH. Proved red first
— a section stored at v3 for a probe registered at v2 reached its applier, `expected unset, got from
the future` — then `load_from_slot` gained the section-level twin of `_migrate`'s refusal: `Log.error`,
defaults, carry on, one bad section never costing the file. It also gave the suite its first worked
migration, `old_key` → `new_key` from v1 in `save_recovery_test.gd`, which `UPGRADING.md` § 4 tells
a game to copy. `save_system.gd` 172 → 176 of 180.)*

*(Previously: T6.0 planned Phase T6 at `5.6.2`, documentation only. The owner asked what a base
meant as the formula for many games had missed, and the answer was filtered rather than
brainstormed: ADR-0007 decides what a template default is, the refused list stays refused, and work
is found, not invented — so every row is a confirmed defect or an undecided "Commonly forgotten"
item. Three explorations and an adversarial review overturned three first premises (shader warm-up
built in T2.0, section versions exercised by `core_test.gd:134`, the F2 freecam bound) and found one
real defect by reading, which became T6.1. The owner decided T6 only; photo mode, a codex, in-area
camera zones and positional ambient emitters are GAME CHOICES; and font fallback proves both Bengali
and CJK.)*

*(Previously: T5.33 audited the base one row after T5.32 declared it finished, at `5.6.1`, and found
the row declaring it finished had made a documented invariant violable. `schedule_entry.gd` always
promised a day is completely covered; `on_day_of_cycle` let a schedule of only day-specific entries
answer nothing for **24 hours of 24** on any unnamed day while `problems()` returned zero, so
`check_content` passed on content that strands an NPC. The fix was one rule at the strength the
`content` layer supports — at least one entry at `-1`, necessary and sufficient — with the plant red
on exactly that assertion and the consequence assertion deliberately green under it. PATCH on three
cited precedents. It also found `TESTING.md` stating a stale suite size through two rows, because
closing item 5 was read as two files when the size lives in four; item 5 now lists all four and
finishes after CI.)*
*(Previously: T5.32 gave a schedule a second dimension at `5.6.0`, and it was the row the plan
called explicitly optional — rated non-blocking, named "the honest place to stop early", put to the
owner as a three-way choice and built in full. `ScheduleEntry` exported `from_hour` and nothing
else, so an hour was an entry's whole address and `entry_for_hour(hour)` the whole lookup: **every
NPC in every game on this base repeated one identical day forever**, a market day being not badly
supported but INEXPRESSIBLE. In scope only because of ADR-0007, whose seam test puts a cycle LENGTH
on the template-default side and a CALENDAR on the game-choice side — so it added `days_per_cycle`
and no weekday names, months, seasons or date type. `time/day_of_cycle` publishes as an ORDERED int
rather than the phase's bool-per-name, and the departure was stated rather than drifted into: that
argument rests on an enum behind the value and a day wrapping where an enum does not, and a day of
the cycle has neither. `-1` did the work twice, meaning "every day" on the field and "no particular
day" on the argument, which is what kept it a MINOR. `problems()` had to re-key on the PAIR or
`check_content` would have failed the build on correctly authored data. The plan's warning that
`clock.gd` would exceed its 150-line budget was wrong — it landed at 147, so neither a split nor a
justified budget was needed — and `doc_counts_test` caught the row out by counting its own prose
about gotcha 79, which is why the delta was measured per case rather than predicted.)*
*(Previously: T5.31 put `Clock` and `Weather` on the flag surface at `5.5.0`, and the defect was
structural rather than missing — `Clock` held the time, emitted four signals and **never once
called `Flags.set_flag`**, while `flag_query.gd` is the ONE evaluator `DialogueNode` and `QuestStep`
both go through and reads `Flags` and nothing else, so **no authored condition could mention time or
weather at all**, including the shop hours `clock.gd`'s own header names as its purpose. Two
independent audits converged there and it was their only convergence. **Both answers the plan
offered were wrong, and probes settled it rather than argument**: ordinals couple, but the sharper
objection is that ordering on a phase is meaningless whatever the numbering — `phase_for_hour`
across a day yields `6,6,6,6,6,0,0,1,1,1,1,2,2,2,3,3,3,4,4,4,5,5,5,5`, so `DEEP_NIGHT` is the
highest ordinal and the earliest hours — and a plain string name is **unreadable by the one
evaluator**, `passes` returning false for every test in the closed set against a String, which
would have shipped four flags that looked right in a dump and answered nothing. So: ordered ints
for the hour and the day, one erased-rather-than-false bool under the lowercased name for a phase
and a weather kind. It also surfaced **gotcha 33 at the one site nobody had fixed** —
`QuestTracker.ids_in_state` sorting `Array[StringName]` by interned handle while its own comment
promised a stable order — which went red in `item_count_test.gd` on a path the row never touched,
and became **gotcha 79**: a note in three files is not a fix in all of them.)*

*(Previously: T5.30 performed the extension surface at `5.4.1`, the one consumer document never
walked, with `src/`, `tools/`, `tests/` and `.github/` byte-identical and no game code committed —
because `UPGRADING.md` and `NEW_GAME.md` both record that a performance happens OUTSIDE the
template and only findings come back. Six findings. Three Tier 2 rows named a class and no path;
the three override hooks were named nowhere, and a guessed `_on_shown()` **compiles, passes every
rung and never runs**, since GDScript has no `@override`; **all seven checkers pass over a game
code root**, measured, including over a planted raw literal and a planted uncalled public method —
two of them should stay blind and the other five are now a stated choice; no document had a row for
game CODE; a game's own input action cannot be player-rebindable and that gate is correct, with a
real bug behind it; and two audit predictions were wrong, which is the argument for performing over
predicting. It also fixed board item 6 at the source, after five rows had worked around a step that
asks for a commit satisfying it creates.)*

*(Previously: T5.29 made the player prefab a seam at `5.4.0`, and **ADR-0007 found it within an
hour of existing** — `game_root.gd:28` held `const PLAYER_SCENE` in the `core` layer, so replacing
the protagonist meant editing `src/`, which `ARCHITECTURE.md` forbids in as many words. Five audits
had missed it; the critic arguing the base was finished found it. Its comparison run is what made
it a defect rather than a preference: the same missing-path plant gave `1 errors` on the new seam
and **`0 warnings, 0 errors` on the old const**, the key silently ignored. The fallback is
deliberate and asymmetric with `first_area`, which has none. Two stale "four facts" counts fell out
of it, and `NEW_GAME.md` § 2 gained the one exception to "keep and never edit".)*
*(Previously: T5.28 settled the template-default vs game-choice distinction as
[ADR-0007](decisions/ADR-0007-template-default-vs-game-choice.md) at `5.3.5`, the row ranked first
five times and never taken — deferred each time because "it is prose and cannot be proved by
running the engine" while the same paragraph recorded that it DECIDES the rows under it, so
deferring the cheap ungateable row kept the expensive gateable ones frozen. The answer is three
kinds, not two: TEMPLATE RULE, TEMPLATE DEFAULT, GAME CHOICE, separated by a mechanical test —
does a seam exist? It closed two candidate rows by written refusal (a chapter sequencer, since a
`story/chapter` int flag with `AT_LEAST` is already a complete chapter model through the one
`FlagQuery`; and an economy, genre rather than structure) and gave the `Cutscenes` row the reason
it had always lacked: a draft had proposed building the staging seam because nine `cutscene`
mentions across eight files looked like unpaid IOUs, and read in full every one is a RECEIPT.
`Fixtures.activate()` became an assertion rather than a skip, reversing what `TESTING.md`
documented, because a skip reports GREEN.)*
*(Previously: T5.27 moved enforcement out of the suite and into the ladder at `5.3.4`. Rungs 5–11
read only the exit code, and a throwaway probe showed what that hides: a loop of three calling a
function that indexes an empty array on the second printed `SCRIPT ERROR`, then `loop finished,
items processed: 2 of 3`, then `PASS`, **exit 0** — gotcha 24, the error aborting the innermost
frame only. **The first plant said the premise was false**, exiting 1 from inside `check_layers`,
and the minimal probe is what separated "the tool dies" from "the tool continues and lies". All
fourteen checker steps now grep their own logs; six checkers refuse a scan of nothing, proved by
the *unmodified* tool going green on the same empty scan; `check_content` is exempt because the
stripped job deletes its entire input by design — the first exemption derived from what the strip
REMOVES. It also reworded a comment that claimed a check nothing performed, and ignored the
ladder's ten log files, which had never been gitignored.)*
*(Previously: T5.26 fixed the ladder's own gate at `5.3.3`. `gates_test.gd`'s header said it
existed to catch "a gate written, committed, and never wired" and could catch neither shape of
that: `LADDER` was a const of seven with nothing asserting it named them all, and the wiring
assertion was `workflow.contains(checker)`, true of a checker named only in a COMMENT — and this
workflow's comments name every checker deliberately. Measured: both `run:` lines for
`check_signals` commented out left the suite green at 2,276, a checker running in neither job.
The count is now of INVOCATIONS against `JOBS.size()`, with the job names asserted so the number
is not a fiction, and the list derived from `tools/` as `test_runner.gd` has done for `CASES`
since T2.2. Gotcha 78. It also found two `SYSTEMS_INVENTORY.md` rows carrying five cells in a
three-column table, so their `Reads` and MUST NOT content rendered as nothing — T5.15's defect in
a new shape — and `gates_test.gd` missing from that file entirely, which is T5.19's `Row styles`
defect again. A column-count gate was declined on measurement: three of four candidates in a
naive sweep were false positives, GFM's trailing pipe being optional and cell pipes being
escapable, so it is a row of its own.)*

**FINDABILITY IS STILL THE PROPERTY, AND THAT IS T5.24'S DESIGN RATHER THAN AN ACCIDENT.** The
roadmap IS legitimately selective where the board is not: it records a package as a log row, as a
tick beside an exit criterion, or as a parenthesis in a phase's Done list — and **T5.14 is only
ever the second**, so a gate demanding a log row would fail a package that is thoroughly recorded.
The roadmap may record a package in whichever shape fits; it may not omit one. T5.25 changed only
*what string the check compares*, not what counts as recorded.

*(Previously: T5.24 gated roadmap completeness at `5.3.1`, because the package log had run T5.15
and then jumped to T5.21 — T5.16 through T5.20 each had a DEVLOG entry and a board row and no
trace in the file `CLAUDE.md` sends a reader to, and nothing was red because nothing counted the
rows. **Its plant was the live repository**, run before a document was edited, at `2266 passed, 6
failed`, exit 1 — **and it named SIX, not five: WP-07, path actions**, the signature non-combat
mechanic, missing from `ROADMAP.md` since 2026-08-26 and named by neither of the two packages that
had recorded this gap by reading the file. Both counted five; that is the case for a gate over a
third reverse-count, delivered as a measurement. Its follow-up plants found **gotcha 76** twice
over: deleting T5.19's whole log row left the suite green, two other rows mentioning T5.19 while
saying something else, and the corrected plant on T5.18 went green for the same reason, because a
row that records a gap is a cross-reference to every id in the gap. **T5.24 found ITSELF in that
state** — its only roadmap mention an aside inside the WP-07 line — and gave itself a real log row.
Rules that came out of it: plant a record gate on an id the document names exactly ONCE, re-count
after your own edits, and know that a package whose only trace is somebody else's sentence passes.
It also added gotchas 75 and 76 to the list, 75 having been named in T5.23's entry and never
appended, so the list held 74 while the record referred to a 75th. `record_shape_test.gd`
68 → 121; suite 2,221 → 2,274.)*

*(Previously: T5.23 gave a sheet a SECOND IDLE and made dwell time the chooser — the last Phase T5
exit criterion, a MINOR at 5.3.0. The gap was never the block: `SpriteSheetLayout` could address 32
animations since T2.1, but every block is chosen by a `GameEnums.MoveState` and standing still is
ONE state, so nothing would ever ask for a second one. `idle_break_row` names the block,
`idle_break_after` starts it, it plays once and hands back, and the clock restarts from the END of
the break. Dwell rather than weather, a schedule or an area tag because each of those needs an
autoload both `sprite_sheet_layout.gd` and `character_visual.gd` are forbidden to touch. Its plants
found gotcha 75, now on the list. Before that: T5.22 made `SaveSystem.SAVE_DIR` the settable
`save_dir` so the suite stopped writing into the developer's own save directory, a MINOR at 5.2.0
with all six uses inside one file, and its load-bearing case passed its own plant because the
overwrite was byte-identical to what it overwrote — gotcha 74.)*

*(Previously: T5.21 wrote the scene-level interaction test `interaction_test.gd` had asked for in
writing since WP-02, and it found a real defect on its first run — `<` on two `StringName`s
compares interned addresses, not text, so `_select()`'s tie-break sorted by load order while its
comment promised the name. Gotcha 73, and its second half is that a probe of an ORDERING must run
in the context whose order is in question. T5.20 split the staging surface at `5.0.0`, a MAJOR
whose one obligation is adding the `DevScreens` node to `game_root.tscn`. T5.19 reconciled twelve
record defects and gated the two that are structure.)*

> **This is a TEMPLATE, not a game.** Read [`TEMPLATE.md`](TEMPLATE.md) — it is short, and the
> roadmap, the board and parts of this file were written before that reframing. The courtyard and
> the garden-keeper are *proof that a system works*, not the product.

## Which branch to work from

**`main`. Branch from it, target it, and stop stacking.** As of 2026-09-03 every package from
WP-01 to T4.2 is on `main` — PR #26 was retargeted to `main` and merged, which landed the whole
71-commit chain at once as `648bac1`, tagged `v1.0.0`. **T5.6 is on `claude/t5-6-character-swap`, branched from T5.5's `claude/t5-5-settings-consumers` (PR #34) because that row had not merged yet — so T5.5 and T5.6 are a two-deep stack and T5.6's PR targets T5.5's branch.** T4.3 was on
**`claude/t4-3-new-game-perform`**, branched from `main`.

**The stack is history and should not be built on.** Every `claude/wp-*` and `claude/t*` branch
named in earlier versions of this section is merged into `main` and kept only as history. Nineteen
of their PRs read **Closed** rather than Merged: once their commits were on `main`, GitHub refused
to retarget them (*"There are no new commits between base branch 'main' and head branch"*), so
they were closed with a comment pointing at #26. That is a GitHub limitation and not a gap in the
record — every commit is reachable from `main` and from `v1.0.0`.

**A one-package chat now starts:** `git checkout -b claude/<package> origin/main`, then
`--headless --import` before anything else, or every `class_name` global fails to resolve.

**Remote:** https://github.com/Raiyan-Bashar-29/HD-2D-game-base-non-combat-

## What this is

A reusable BASE TEMPLATE for HD-2D exploration games. Godot 4.7.2, GDScript.
Visual reference: Octopath Traveler I/II/0, The Adventures of Elliot.

**No combat.** Explicitly retracted by the owner — not an oversight. **Art is deferred**;
everything runs on procedural placeholders, permanently â the template ships an art *contract*,
never art, and each game brings its own. The goal is a skeleton with a home for every system a
game built on this will need, so a new game is content and data rather than new architecture.

## Where it stands

Phase 0, Phase 1 and Phase 2 are complete, and **every T-phase is COMPLETE: T1, T2, T3, T4 and —
since T5.23 took its last exit criterion on 2026-09-09 — T5, the base as a reusable CHARACTER
kit.** `ROADMAP.md` has no unticked box anywhere, and T5.24 marked the phase header to match; the
file's package log is now complete too, and `record_shape_test.gd` fails if it stops being.

**WP-15 IS CLOSED and WP-10 stays OPTIONAL, so nothing is blocking.** The two rows that stood
between the board and Phase T4 are settled: the owner closed WP-15's remnant on 2026-09-02 rather
than build credits and an accessibility pass, both of which belong to a consuming game; crafting
was already optional and blocks nothing.

**THE RELEASE TAGS ARE TAKEN, AND TAGGING IS STILL THE OWNER'S.** `v1.0.0` on `648bac1` landed
WP-01 through T4.2 as one 71-commit linear chain, and `v2.0.0`, `v3.0.0`, `v4.0.0` and `v4.2.1`
followed it, each verified to name a tree that genuinely declares the version it claims. **Stating
a version is engineering; cutting a release is not** — T4.3 bumped `base/version` to `1.0.1` and
deliberately did NOT tag it, and `1.0.2`'s tag was asked for and DECLINED on 2026-09-04. So several
versions this repository declares carry no tag naming them, and that is the policy working rather
than a gap to close.

**THE BOARD WAS CLOSED ON 2026-09-04 AND REOPENED THE SAME DAY, AND BOTH DECISIONS WERE RIGHT.**
T4.4 put the choice to the owner — every phase closed, every document performed, nothing blocking
— and the answer was *nothing at all*, so the board was closed and that closure was recorded. The
very next question was whether the SKELETON was actually finished, and reading `ROADMAP.md`
instead of the closing summary answered no: **Phase 1 read COMPLETE while carrying three unticked
exit criteria, and Phase 2 read IN PROGRESS with one.** T5.1 closed all four by PROVING them, and
one turned out to be a genuinely missing FEATURE — the locale setting was wired to nothing at all.
**Every exit criterion in Phases 0 through T4 is ticked, and each was proved rather than
asserted** — and Phase T5's last box, the second idle, was taken by T5.23, so no phase now
carries an unticked criterion.

**So the base is COMPLETE through Phase T5, and what it is FOR has been sharpened.** The owner's
intent is reusable CHARACTER infrastructure that future games inherit by swapping assets — several
idle formats, several movement styles — so that a new game starts from a working base rather than
going in blind. Phase T5 delivered it: gaits are data, a whole character swaps by pointing at
another sheet, and every facing draws a different figure.

**A new session's default is still NOT to invent work.** A genuine defect, an unticked criterion,
or a seam the owner's reframing actually needs is a package. One invented so that there is one is
how the previous project reached 3,983 lines in a single file, twenty reasonable lines at a time.
**The version is** **5.16.2**, and it is UNTAGGED — `v4.2.1` is the most recent tag, and the gap is
the owner's to close or to leave.

**THERE IS NO NEXT PACKAGE, AGAIN: PHASE T6 IS COMPLETE.** T6.14 was its last row, on 2026-09-30.
The discipline from before T6.0 returns unchanged: the next thing is a game started on this base
through [`NEW_GAME.md`](NEW_GAME.md), a defect found by the owner's playtest (#8's closure waits on
it), or a phase the owner opens. A genuine defect found while doing any of those is the next row —
found, not invented.

*(Historical, true from T6.0 to T6.14: the board held Phase T6's planned rows, and a new session
took the lowest unfinished one rather than choosing.)*

*(Historical, and it was true through T5.31: the next package was a choice, not a queue.)* Nothing
is blocking, **Phase T5 has no unticked exit criterion** — T5.23 took the last one. **T5.24 gated roadmap completeness, T5.25 made that
gate able to fail, T5.26 did the same for the ladder's own gate, and T5.27 moved the question out
of the suite and into the ladder** — four rows in a row about whether a check checks anything.
**That run is finished and the next row should not be another one of them**; the list it was
working from is now closed but for one item.

**WHAT THAT RUN CLOSED**, all four found in the audit that produced T5.25 and none of them
remembered rather than measured: rungs 5–11 now grep their own logs for `SCRIPT ERROR` and upload
them, because a runtime error aborting the innermost frame lets a checker's loop finish and print
`PASS` at exit 0 — probed, not assumed. Six of seven checkers now refuse a scan of nothing;
`check_content` is exempt because the stripped job deletes its entire input by design. And
`ladder.yml`'s claim that the two jobs "must report exactly the same numbers" now says what is
enforced instead of what nobody checks.

**WHAT IT LEFT, AND IT IS ONE ITEM AND ONE DECISION.**
- **`Fixtures.activate()` is called unchecked at 14 of 16 sites.** `TESTING.md:193-195` writes the
  shape out: `if not Fixtures.activate(): skip(...); return`. **The two sites that handle it
  disagree with each other** — `bag_mirror_test.gd:47` skips, `audio_duck_test.gd:180` asserts the
  return is `true` — and the second is arguably the better rule, because a fixture root that
  cannot be written turns a skip into a silent no-op, which is the same "passes because it found
  nothing" failure the tools were just guarded against. **This needs the owner to pick which rule
  is right before either is gated**: assert loudly, and one document changes; skip, and fourteen
  files do. Recorded here rather than decided in passing.
- **The cross-job count comparison** `ladder.yml` used to imply: each job publishes its checker
  counts, a third job diffs them. Real work, genuine value, and not urgent — the exit-code
  requirement already catches the failure that matters.

Still ungated with the reason recorded rather than as an oversight: the suite's own assertion total
(impossible from inside a running suite), the board's `**Commit:**` lines (15 of 52, so a gate
fails 37 historical rows), the board's detail-section headings, branch names, and a markdown
table's column count — the last declined on measurement, three of four candidates in a naive sweep
being false positives.

**The strongest rows, in the order this file recommends them**: the **template-default vs
game-choice taxonomy**, which gates
three rows below it and is honestly weak in that it is prose and cannot be proved by running the
engine; a **narrative-staging seam**, `Cutscenes` being the only `TODO` in `SYSTEMS_INVENTORY.md`
with no stated reason; **time above the scale of one day**; and **the placeholder sheet's fourth
animation BLOCK, which no test asserts is visually distinct from its first** —
`sheet_facings_test.gd` does exactly this for FACINGS and the equivalent for BLOCKS is answered
only by a windowed capture a person reads, which is T5.8's own argument left half-applied.
**T5.21 took the scene-level interaction test off this list**, and what that row returned is worth
recording: a false-confidence gap that a run could close, closed, with a real defect found in the
code the test was written to cover. **T5.22 took the redirectable `SAVE_DIR`** and returned a
gotcha rather than a defect — the case that proved it passed its own plant first, gotcha 74.
**T5.23 took the second idle and closed Phase T5**, returning gotcha 75, the same family one
number along. **T5.24 took the roadmap reconcile and returned gotcha 76**, which is that family's
third turn and the new gate's own stated limit: `contains` findability cannot tell a record from
an incidental mention, so plant a record gate on an id its document names exactly once. **The
tightest file is still `src/systems/scene_director/director.gd` at 187 of its 190** — three lines,
on an override WP-14 already raised once, so raising it again is a decision rather than a
mechanical move. `tools/gen_placeholders.gd` stays on the list at 234 of 250; T5.20 split
`dev_stage.gd`, which was the urgent one at 248, down to 175.


167 files, 15,862 code lines, 17 scenes, 2 areas, 4 items, 1 conversation, 1 schedule, 1 quest of
three steps (one of them a COUNT), 2 mapped areas, 2 path actions, 2 sprite sheet layouts,
3 tagged surfaces, 2 languages, **5 gait blocks on the swap sheet and 4 on the default one, the
fourth being a second IDLE rather than a gait**,
1 shared area material, **24 settings and 24 consumers**.
Template version **5.16.2**, and that version is deliberately UNTAGGED — `v4.2.1` is the most
recent tag, each tag naming the tree that declares it.
Boots headless with **0 warnings, 0 errors**, and a run killed mid-load now shuts down clean too.

**Works, and verified by running it:** logging with rotation · signal registry (`events.gd`) ·
input actions · settings · save/load with atomic writes and versioning · plot flags · area
director with a re-entrancy guard and threaded loading · world clock · weather state · audio
buses · HD-2D camera rig with tilt-shift DOF · billboarded lit shadow-casting 8-way character ·
camera-relative walk/run/sneak · day/night lighting · screen fade · dev screenshot capture ·
**A CHARACTER WHOSE GAITS ARE DATA**: `animation_for` takes a `GameEnums.MoveState`, so idle,
walk, run, sneak and climb are separate cycles a SHEET names and every character - player or
NPC, both through the same `CharacterVisual` - picks up by asset swap with no code. An unnamed
gait inherits the walk block, so no sheet authored before T5.2 changed behaviour. Proved by
the asset's own pixels, by `sprite.frame` read live, and by a capture in which the player
walks in GREEN while the NPC beside them stands in BLUE - same sheet, same frame ·
**SETTINGS THAT ACTUALLY DO SOMETHING, ALL TWENTY OF THEM**: every key in `Settings.DEFAULTS` is
read by something and `settings_consumers_test.gd` fails on one that is not. Nine were wired at
T5.5 and three removed rather than faked. The placements are the lesson: bloom to
`EnvironmentDriver` because the Environment is that node's, but `video/shadows` to the shadow
ATLAS in `Settings` itself, because shadows are cast by lights an AREA AUTHOR placed and no node
owns the set of them - so a game that adds a hundred lights gets that setting for free and writes
no code. `UiAccessibility` under `UILayer` scales the project theme's font sizes from a cached
base, which is the seam a fork previously could not reach without editing `src/`. Six settings
photographed in pairs differing by one line of `settings.cfg` - text scale moved every font in the
UI including the HUD clock, shadows removed every cast shadow in the frame, and `set_dof_enabled()`
finally has a caller ·
**A LANGUAGE YOU CAN ACTUALLY SWITCH**: `Settings._apply_locale` reaches `TranslationServer`
on `_apply_display`'s reasoning — nothing else owns it — and `tools/gen_pseudolocale.gd`
generates an `en_XA` column so a second language EXISTS without the template pretending to
ship a translation. Two captures of the satchel differing only in that setting were read:
`Satchel / Key Items / Rose Key x1` against `[~~Satchel~~] / [~~Key Items~~] /
`[~~[~~Rose Key~~] x1~~]`, the row double-wrapped because the row format AND the item name
both come from the table. An unbracketed string on screen is therefore a hard-coded one,
which is `check_strings.gd`'s static rule made visible and including anything computed ·
**A SAVE THAT SURVIVES A REAL RELAUNCH**, proved in TWO PROCESSES rather than one reload:
`--save-state` / `--load-state` in `dev_probes.gd`, with the fresh process's boot line as
the control and the weather deliberately STORM because CLEAR is the boot default ·
placeholder art generator · line-budget checker · a headless test suite (2,302 assertions) that
builds its own content and passes with the demo deleted, and that FAILS on a case which crashes,
returns early, asserts nothing, or is not listed in the runner ·
an engine/demo boundary gate that derives the demo ids and fails on any of them in src/ ·
a LOCALIZATION gate that fails on a literal reaching a text sink and on any `*_KEY` const with no
CSV row — the second half proved to catch what nothing else could, since a planted typo passed
`check_content`, `check_boundary` and 1,517 assertions ·
a SMOKE TEST that drives a session end to end from fixtures and asserts it logged nothing ·
**CI that runs ten of the twelve rungs on every push, PR and manual dispatch**, in two jobs (full
checkout and a stripped template), on a downloaded engine whose SHA512 and build string are both
verified — proved red on a broken assertion and green again ·
interaction sensor with ranking and Tab-cycling · Interactable contract · localized prompt and
toasts · readable signs · levers · gates gated by flag or by a carried key · per-object
persistence (ADR-0005) · typed item definitions found by directory scan (ADR-0006), and since T3.1 **ONE scan behind all
five catalogues** — `ContentScan.into()` fills each registry's own TYPED dictionary, so the five
façades keep their own content root, cache and accessor and nothing anywhere is a cast · an
inventory component with a capacity seam · pickups · take-all chests · a content validator ·
trigger volumes that fire on entry · a rest point that skips hours · authored climb points ·
a screen stack with real pause semantics · a token input lock · a HUD clock readout · an
inventory screen with focus navigation · one action-to-screen binding · a SECOND area, an
interior, and a door that really travels · a loading readout drawn above the curtain ·
shader warm-up behind black · a dialogue runner with conditions, branches and effects · a
non-pausing dialogue box with a typewriter reveal · an authorable .tres conversation format ·
a navmesh baked from each area's own geometry · an NPC that keeps a timetable and can be
talked to · schedules as authored data · path actions with a standing that gates them and
that they move Â· **weather you can see**: generated rain, snow and wind emitters driven by
`Weather.intensity()`, surfaces that darken and gain a wet clearcoat and then dry out over
twenty-six seconds, and a layered ambience bed on procedurally generated noise ·
**an exported build that finds its content**: a committed Windows preset, and a boot-time readout
of every catalogue's count and resolved paths that WARNS on an empty one in an export ·
**an art CONTRACT rather than art**: a `SpriteSheetLayout` resource carrying facings, frames,
cell size and animation blocks, with the direction sectors DERIVED from the facing count, so a
sheet with a different cell and frame count was swapped in with no code change at all · a project
`Theme` at `assets/theme/ui_theme.tres` wired as `gui/theme/custom`, holding every font size,
colour and inset the UI draws with, so one edit to that one file restyled the menu, the inventory
screen and the HUD at once. Both demonstrated by windowed captures that were LOOKED AT ·
**documentation a consumer can actually start from**: `AUTHORING.md`, `ART_CONTRACT.md`,
`TESTING.md` and an extension surface, routed to from `CLAUDE.md` and this file, and proved by
authoring a new area, NPC and conversation from them alone — plus a gate that fails on a
documented path or worked-example field the engine no longer has ·
**quests as authored data**: `Quest` / `QuestStep` .tres found by the fourth directory-scan
registry, every step naming a FLAG CONDITION rather than a callback, a `QuestTracker` that derives
progress from `Flags` and latches only the two things that cannot be derived, and a journal screen
on `J` — the placeholder quest is started by the keeper's conversation, advanced by the courtyard
lever and completed by the dais trigger volume, and **none of those three files was touched**.
Two windowed captures LOOKED AT, and the `J` key proved by a temporary probe that was removed ·
**equipment as a FLAG rather than a store**: `Equipment` is a component beside `Inventory` that owns
no dictionary — a slot is `equip/<wearer>/<item id>`, so it is already saved, already announced on
`flag_changed`, and a `Gate`, a `QuestStep`, a `DialogueChoice` and a `ClimbPoint` gate on what is
in hand **with no code and no new field in any of them**; the demo's equip-gated arch works with
`Gate` untouched. Enter on a satchel row holds or stows, proved by a temporary probe that was
removed. Three windowed captures LOOKED AT and READ · **a WORLD MAP whose discovery is a flag**: `AreaDef` .tres per area in `data/areas/`, found by the
fifth directory-scan registry, carrying the map position, the arrival spawn and
`known_from_start`; `WorldMap` under `GameRoot` turns `area_entered` into the flag `map/<area id>`
and emits the same `area_change_requested` an `AreaDoor` emits, so `Director` still owns every
transition; `MapScreen` on `M` draws one dot per def at its authored NORMALISED position in three
states, and names no area anywhere. Discovery needs no save section, no migration and no code in
anything that reveals a place — `--flag=map/<id>:true` is the second capture and a conversation
effect writes the identical key. Three windowed captures LOOKED AT and READ ·
**a refusal can carry an AUTHORED line**:
`Gate.locked_key` and `PathAction.refusal_key` had both been declared, validated by `check_content`
and read by nothing, and the player got a generic message about a different door ·
**an ATTRIBUTE with exactly one consumer, and GROUND you can hear**: `attr/<who>/<name>` is the
FIFTH namespace over `Flags` — an integer number of steps clamped to ±4, with no resource, no
registry and no save section — and `PlayerController.current_speed()` scales every gait by `pace`,
measured windowed at 2.861 m against 4.687 m over the same 60 frames. The attribute's NAME is a
const on its consumer, so an attribute nobody reads has nowhere to be written down.
`metadata/surface` tags an area's geometry and is INHERITED from the nearest tagged ancestor, so
the courtyard tags `Terrain` once and overrides two floors; a `Footsteps` component probes down,
steps every 1.7 m and GENERATES the sound from the surface's name, so `sand` is audible the day a
game writes it and no table of surface names ever exists under `src/`. Three surfaces reported
correctly in a windowed run, one of them inherited, and the sound following each ·
**"BRING ME THREE PETALS", AND THE QUEST SYSTEM STILL DOES NOT KNOW WHAT AN INVENTORY IS**:
`Inventory` publishes each count as `bag/<carrier_id>/<item id>` — the SIXTH namespace over `Flags`
and the first whose value is a number — so a step is `AT_LEAST 3` on that key, `QuestStep` gained
no field and `QuestTracker` gained no knowledge, and the dependency points DOWN from `gameplay` to
`core` rather than up from `systems` to `gameplay`. The mirror is declared DERIVED, so it is
readable and announced but never saved and no save version moved. A step reopens when a count falls
and a completed quest does not — WP-08's asymmetry, tested at last against something that really
decrements. The journal draws `— Gather three rose petals.   2 / 3` and still reads no flag. Two
windowed captures LOOKED AT and READ, differing by exactly one petal ·
**THE LOOK OF AN AREA IS DATA, AND ONE OF THE THREE SEAMS TURNED OUT TO EXIST ALREADY**:
`assets/materials/wood.tres` is one shared `StandardMaterial3D` that two areas point at, and
tinting that one file turns the courtyard's dais and the hall's plinth magenta together — a
library of ONE, because a tiling rate belongs to the surface and not the substance, so the other
five materials are genuinely not duplicates; the twenty post-stack numbers in
`EnvironmentDriver` are `@export`s at exactly the values T2.1 shipped, so
`volumetric_fog_density = 0.06` on one area's driver node hazes that area and no other; and
`HD2DCameraRig`'s framing exports, which have been there since it was written and which no area had
ever set, now give the interior 36 degrees at 9.5 m against the outdoor 27 at 14 — one run logs
both rigs. A PNG a game drops in imports correctly first time, because `[importer_defaults]` sets
`detect_3d/compress_to = 0`, which is the section T2.1 could not check against the API dump and
T3.2 settled by MEASURING instead. Six windowed captures LOOKED AT and READ, each pair differing by
one edit to one file, and six gates proved red with the real violation — one of which was the test
itself, passing while the thing it checked was deleted ·
**A CONSOLE YOU CAN TYPE IN AND AN OVERLAY YOU CAN READ WHILE THE GAME RUNS, AND THE SIX COMMANDS
ARE THE COMMAND LINE'S OWN**: `goto`, `flag`, `time` and `give` have ONE body each in
`src/systems/debug/dev_commands.gd`, which `dev_stage.gd`, `dev_capture.gd` and
`DebugConsoleScreen` all call, so what you type in the console is exactly what you pass after the
bare `--`. The console is a `UiScreen` on F1 declaring `pauses_world` — no second pause mechanism —
and it lives under `src/ui/`, INSIDE the boundary gate, because it names no content. The overlay is
a `CanvasLayer` on F3 beside the HUD that never enters the stack, reporting frame time, fps,
process time, draw calls, node count and ORPHAN count. Absence from a release export is MEASURED
with a control: a debug export logs both armed lines and a release export logs neither. Three
windowed captures LOOKED AT and READ, one of them a checkable prediction — launched at
`--time=12:00 --freeze-time`, handed `time 18:40`, and the HUD reads `Day 1 | 18:40 | Dusk` over a
dusk-lit courtyard.

**Not built:** command HISTORY and autocomplete in the debug console, and a watch list of live
flags — deferred by the row, and the transcript is deliberately un-scrollable for the same reason:
a console that needs scrolling wants history, and half of it is worse than none · a console command
that mutates content on disk, also refused by the row · a GRAPH on the performance overlay, which
is a second thing to get wrong when the averaged number already answers the question ·
`Actions.DEBUG_FREECAM` on F2, declared since WP-01 and still bound to nothing — inventing a free
camera was not a dev-tools row's job, and naming it is cheaper than a reader wondering whether F2
was missed · item instances (durability) ·
footstep PARTICLES, and a second attribute with a consumer — naming one is free, reading one is a
line of engine code ·
an equipment SCREEN, a character sheet, and no attribute gates an interaction ·
item tooltips, sorting and drag-and-drop · fog of war, map zoom and pan, map art, travel costs and
objective markers on the map — `quest_advanced` has an emitter, so markers are a listener and one
more marker state · **a quest step that TAKES the items it counted** — a step can REQUIRE N of an
item id since T3.3, and WP-08's layer refusal is unchanged: a completed quest emits
`quest_completed` and stops, so handing anything over is a listener's job · a DEPARTURE-side travel
point, which is a game policy rather than a mechanism ·
no CI export rung (a GPU-less runner has no platform template) · export
presets for platforms other than Windows · a release-build content readout, since the debug gate
means a release export prints nothing · a counted step whose CARRIER is validated by a gate — the
item id is checked, the carrier is an `@export` in a scene `check_content` does not open.
Git LFS stays off, and T3.2 turned that from an omission into a written refusal with the reason
and the turn-on steps — stated once, in `ART_CONTRACT.md`.

## Known defects

**Fixed 2026-08-27 in WP-09, and both had been wrong for packages while every rung stayed green:**

1. **`Gate.locked_key` and `PathAction.refusal_key` were DECLARED, VALIDATED AND READ BY NOTHING.**
   Since WP-01 and WP-07 respectively. Authored content set them, `check_content` required a CSV
   row for them, and `interact_prompt.gd` computed `refusal.<reason>` from the enum and never asked
   the object — so every gate in the game told the player "It will not budge. Something holds it
   shut." whatever its author had written, and `PathAction.refusal_key`'s own comment claimed it was
   "shown for the LOW_STANDING refusal". This is gotcha 2's shape in its most invisible form: a
   message that is merely WRONG looks exactly like a message that is right, so eight rungs, both CI
   jobs and 1,149 assertions were green over it. Found by looking for where an equip-gated gate
   would say "you need a light". `interaction_refused` now carries a `message_key`, and the
   authored line is photographed in WP-09's second capture.
2. **The satchel screen redrew only on `inventory_changed`.** So equipping from anywhere other than
   a row press left a held item drawn as merely carried — the first WP-09 capture photographed
   exactly that while the log said `player equipped`. Found by a capture, not by a gate; the screen
   was still right about the bag, so nothing could fail. See gotcha 34.

**Also fixed 2026-08-27 in WP-09, and it is gotcha 32 for the third time:** `--open-inventory` did
not wait for the area, so with `--new-game` it drew over the title screen and the arriving
transition unwound it. Third staging flag to need that wait after `--open-menu` and `--flag`, and
`dev_stage.gd` now says any flag that puts something on screen needs it.


**Fixed 2026-08-26 in T2.0, and it was invisible until an export existed:**

1. **A missing `[editable]` marker silently dropped every instance override in an exported build.**
   `courtyard.tscn` set `object_id`, `label_key` and `conversation_id` on two nodes INSIDE its
   instanced `npc.tscn` with no `[editable path="Actors/Keeper"]`. From source the text loader
   applies them; an export converts `.tscn` to binary `.scn` and the conversion DROPS overrides on
   a non-editable instance. So the shipped keeper had no identity, no prompt, no conversation and
   never ran its schedule — while every ladder rung, both CI jobs and 930 assertions stayed green.
   This project hand-authors its `.tscn` files, so the marker the editor would have written is
   exactly what a hand-authored scene forgets. Now a `tools/check_content.gd` gate, proved red on
   the real bug. See gotcha 27.

**Fixed 2026-08-26 in T1.3, and it had been wrong since ADR-0006:**

1. **`ItemDb.reload()` had never called our function.** `Script` declares `reload()`, and
   `ItemDb` as an identifier IS the GDScript object, so the static call dispatched to
   `Script.reload()` — which reloads the script and resets its static variables. That happens to
   do exactly what our `reload()` was written to do, so nothing broke and no test could see it.
   It surfaced only when a redirectable `content_dir` was added: the assignment stuck, and the
   next `reload()` silently reset it. Proved with a print inside `_ensure_loaded()` that
   `ItemDb.reload()` never reached. All three registries now expose `rescan()`. Fourth
   native-name collision in this project, after `Area3D.priority`, `class_name Container` and
   `DictRead.get_name` — see gotcha 17, and note that a *static* function is no exception.
2. **The test suite could not fail on a crash**, which invalidated every green result the project
   had. Fixed with two mechanisms, because the first was measurably not enough — see gotcha 24.

**Fixed 2026-08-26 in T1.2, both found by doing rather than by a gate:**

1. **`dev_capture.gd` had failed to parse since the WP-13 merge and every rung stayed green.**
   `await _settled()` was added without the function, so F12, `--shot`, `--time`, `--freeze-time`
   and `--weather` were all dead for a package. See gotcha 22: `0 warnings, 0 errors` counts
   `Log.error` calls, not engine parse errors. Found by grepping `--headless --import`.
2. **A stripped template failed its own content gate on step one of `docs/NEW_GAME.md`**, because
   the three content registries reported an empty folder as a problem. Found by actually
   performing the checklist instead of writing it.

**Fixed 2026-08-26 in WP-13, both found by running it and neither by a static gate:**

1. **`SurfaceWetness` was driven before it had collected anything to drive.** `WeatherVisuals`
   readies before it, and `apply()` skips a value that has not moved â so arriving in an area
   mid-downpour would have shown a dry courtyard forever. Found by reading the line ORDER in the
   boot log, not by a failing test.
2. **Every `play()` against the Dummy audio driver leaks an instance.** See the audio gotcha.


**Fixed 2026-08-26 in WP-06. Three found by running it, eight more by an independent
adversarial review of code that had already passed every gate:**

1. **A HARD SOFT-LOCK in dialogue.** `advance()` asked the AUTHORED choice array while the
   screen drew the FILTERED one, so a node whose every choice failed its condition rendered a
   box with no buttons that would not advance and could not be escaped, holding the player's
   and the sensor's tokens until the process was killed. `advance()` now reads
   `available_choices()`.
2. **The navmesh baked EMPTY and said nothing.** `SOURCE_GEOMETRY_ROOT_NODE_CHILDREN` parses
   children of the `NavigationRegion3D`, which has none. An empty bake takes 0ms, so "baked in
   0ms" is what the failure looks like. Now group-sourced, and the log reports the polygon count
   and errors at zero.
3. **The navmesh bridged a step the body cannot climb.** `agent_max_climb` was above the dais's
   0.4m riser, but `move_and_slide()` has NO step-up, so the NPC walked into it and stopped
   while the agent insisted it had not arrived â silently. See the settled decision below.
4. **A non-`Node3D` area root left the curtain black forever**, with the old area already freed
   and `current_area_id` empty, so not even `reload_current_area()` could recover. Every failure
   path now goes through `Director._abandon()`, which lifts the fade on the way out.
5. **A failed load left "Loading" pinned over the game** for the rest of the session. It now
   hides when the curtain lifts, which every path out of a transition does.
6. **A refused transition left a save's position override armed for the NEXT one**, teleporting
   the player to coordinates authored for a different area. Cleared on every path that does not
   place the player.
7. **The loading readout could never appear during the boot load** â the one load, on a cold
   cache, that most needs it. Progress now shows it as well as updating it.
8. **Nothing closed screens on an area change; `UiRoot.close_all()` was dead code.** Travel does
   not lock the player, so a conversation opened during the fade-out kept running over the new
   area with its speaker freed. `UiRoot` now unwinds on `area_unloading`.
9. **Choice buttons and `choose(index)` indexed two different lists.** The world runs behind a
   dialogue box, so a flag written while it is open shifts every index between drawing a button
   and pressing it. The UI now calls `take(choice)` with the object it drew.
10. **`InteractionSensor._on_availability_changed` swapped `_current` without resetting the
    hold**, so a part-finished hold fired an adjacent object that became available mid-hold.

**Fixed 2026-08-26 in WP-05, found by a capture:**

1. **An unquoted comma in `strings.csv` had been eating text since WP-01.**
   `object.lever.gate.on` was cut at its comma, so the lever toast had read `Somewhere north`
   for three packages. Nothing caught it: the key still resolved and `tr()` still returned a
   string. Both offending rows are quoted, and `check_content.gd` now FAILS any row that parses
   to more than two columns. A translator adding a comma cannot reintroduce it silently.

**Fixed 2026-08-26 in WP-04. All three were invisible until a SECOND area existed, and all
three compiled cleanly and passed every static gate:**

1. **`DictRead.get_name()` never worked, and loading a save had never restored the area.**
   `Resource` declares `resource_name` with the getter `get_name`, and a GDScript *is* a
   Resource, so the static call dispatched to the native zero-argument method and threw at
   runtime. Its one caller was `Director._apply_save`. With one area it looked fine, because
   you always reloaded into the area you were already in. Now `get_string_name`.
2. **The interaction prompt survived an area change**, offering an Iron Lever in an area that
   no longer existed. `InteractionSensor` pruned its candidate list but never validated
   `_current`, and **a freed object compares EQUAL to `null` in Godot 4** — so
   `best != _current` reported "unchanged" and nothing was re-announced. `_announced_id: int`
   now carries the identity, because an int survives the object it names.
3. **`follow_clock = false` did not mean "do not use the clock".** It only stopped the driver
   *updating*; `_ready()` still sampled the clock once, so the first interior ever built was
   pitch black when entered at 02:30 and fine at noon, from the same scene file. An interior
   now has its own authored ambient, fog and background.

**Fixed 2026-08-26 in WP-01, both found by running the engine, neither visible in the source:**

1. **A climb oscillated on its corner forever.** The path turns at the top on purpose — a
   straight line from the foot of a ladder to the ledge above passes *through* the ledge, and
   a climb that writes `global_position` has no collision left to stop it. But the corner has
   to latch: without it, the frame after arriving at the waypoint steps off towards the
   target, and the next frame steers back. 600 test steps, no convergence.
2. **A trigger volume near the area origin fired at spawn.** The player exists at the origin
   for one frame before `Director` places them on the spawn marker, so the courtyard's dais
   trigger toasted from three metres away, on every load. `TriggerVolume` now arms two
   physics frames late.

**Fixed 2026-08-24, all four found by audit and each verified after the fix:**

1. Toggle-run did nothing. `_is_running()` polled `is_action_just_pressed` and is called
   twice per frame, so the toggle flipped twice and netted to zero. Polling moved to
   `_poll_run_toggle()`, called once at the top of `_physics_process`.
2. A missing area left the opaque fade up forever with no recovery. `game_root.gd` now logs
   an error and requests the fade-in regardless.
3. `player_yaw` was written to every save and never read back, so facing was silently lost.
   Restored via `_yaw_override`.
4. **A fresh clone did not run at all.** `class_name` globals live in the gitignored
   `.godot/` cache, so `events.gd` could not resolve `GameEnums`, the `Events` autoload
   failed, and the console filled with parse errors that looked like broken code. Fix is
   documentation: run `--headless --import` once after cloning. Now stated in `README.md`
   and `CLAUDE.md`.

**Not defects, but known and deliberate:**

- `Weather` keeps rolling during a visual capture unless `--freeze-time` is passed, so an
  un-frozen screenshot is not reproducible.
- The environment driver rebuilds a `Dictionary` every frame in `_sample()`. Measured as
  harmless at this scale; revisit if the frame budget tightens.
- **THE PLACEHOLDER SHEET DRAWS ONE POSE EIGHT TIMES, so no facing is visible in any picture.**
  Measured on `character_placeholder.png`: every facing's walk cell is within 4% of facing 0's,
  and facing 4 — the one 180 degrees away, the back view — differs by **0.5%**, about eight pixels
  of a 1,536-pixel cell. The walk cycle itself is 1.6-5.8%. So a character moving sideways is a
  front-facing figure translating across the screen, which is what the owner reported as "they
  just slide to the side" on 2026-09-05. **The CODE is correct** — `_aim` quantises the facing
  (`facing_test.gd`) and `update_from_velocity` advances the cycle (`gaits_test.gd`, T5.3) — the
  sheet has nothing different to draw. Same shape as gotcha 54 one level up: the facing machinery
  is asserted at both ends and invisible in every capture ever taken. Fixable inside
  `tools/gen_placeholders.gd` alone, no `src/` and no art-contract change, and it is candidate J.
- **Three settings were REMOVED rather than wired, and each is a real feature a game will want.**
  Screen shake, autosave and subtitles. Autosave is the largest: `SaveSystem` has no notion of the
  slot a run belongs to, so it needs a slot POLICY before it needs a trigger, and picking one is a
  design decision rather than a wiring. All three are candidate rows.

## Decisions already made — do not re-litigate

- **THE TEMPLATE'S VERSION IS `[template] base/version`, NOT `application/config/version`.** The
  obvious field is the wrong one, and `NEW_GAME.md` § 4 already said why without noticing: it tells
  a fork to reset it to `0.0.1` on day one, so after exactly one fork it records the GAME's version
  and nothing remembers which base the game came from. Two facts, two settings. It is a project
  setting rather than a `const` under `src/` for the same reason `[game] world/first_area` is —
  reading a `const` means opening engine code, and the premise of the whole boundary is that a
  consuming game does not read `src/`. A fork LEAVES THAT LINE ALONE.
- **`TemplateVersion` IS ITS OWN FILE AND WILL NOT BE FOLDED INTO `GameConfig`.** `GameConfig`'s
  header says it owns "the values a game author writes once"; the base's version is the one value
  a game author must NEVER write. Folding them would make that sentence false to save a small file.
- **THERE WILL BE NO AUTOMATIC UPGRADE AND NO COMPATIBILITY TABLE.** `UPGRADING.md` § 4 states both
  in writing, so shipping either would contradict the document. A table is a list of exceptions to
  the promise, and the promise is the product; `same_major_as()` and `compare_to()` are the whole
  surface. Git shows a diff and the game's author decides.
- **"IS THE BASE DONE" IS A QUESTION ABOUT `ROADMAP.md`, NOT ABOUT THE CLOSING SUMMARY — AND ON
  2026-09-04 THE TWO DISAGREED.** T4.4 closed the board on the owner's instruction and recorded
  the closure; asked an hour later whether the skeleton was finished, the honest answer came from
  the criteria and was **no**. Phase 1 read COMPLETE with three unticked exit criteria and Phase 2
  read IN PROGRESS with one, and one of the four was a missing FEATURE rather than a missing proof.
  T5.1 closed all four by proving them. **Two rules come out of it.** A phase marked complete "except
  for the hard ones" is a phase whose hard parts nobody has the answer to — and here that hid a
  system wired to nothing for the whole life of the project. And **a summary is not a state file**:
  when they disagree, the file with the checkboxes wins, which is why `CONTEXT.md` says to read the
  roadmap rather than the last package's write-up. WP-10 crafting is still OPTIONAL and unbuilt,
  and the reasoning for closing the board still stands for work with no criterion behind it: a
  package invented so that there is one is how the previous project reached 3,983 lines in one file.
- **WP-15's REMNANT IS CLOSED, BY THE OWNER, 2026-09-02.** Credits name a team a template does not
  have, and an accessibility pass over placeholder art and a UI every game restyles is a pass over
  something designed to be thrown away. What the template owes accessibility is the SEAMS, and they
  exist and are proved: the project `Theme`, rebindable input, and no timed input anywhere because
  there is no combat. Recorded rather than deleted, the way WP-10 is marked OPTIONAL.

- **A DEV TOOL THAT NAMES NO CONTENT BELONGS UNDER `src/`, NOT IN THE EXEMPT DEBUG DIRECTORY.**
  `DebugConsoleScreen` is a `UiScreen` in `src/ui/screens/` beside the journal and the map. The
  permission is that a command takes its argument from whoever typed it, so `goto courtyard` is
  input rather than a literal — but the REASON is stronger than the permission:
  `src/systems/debug/` is exempt from `check_boundary.gd`, so filing the console there would have
  bought it an exemption it does not need and switched off the gate that ought to be watching it.
  The rule generalises: the exemption is for code that must name the demo, and nothing else goes
  looking for it.
- **THE COMMAND LINE AND THE CONSOLE ARE ONE IMPLEMENTATION, AND THE VERB RETURNS ITS REPORT.**
  `DevCommands` holds `goto`, `flag`, `time` and `give`; `dev_stage.gd`, `dev_capture.gd` and the
  console all call it, and the console's argument is byte-for-byte the `--verb=` argument. Each
  verb returns a sentence rather than logging one, because a staging flag wants that line in the
  log and a console wants it on screen — a shared body that logged would have forced one of them
  to read the log to find out what happened.
- **THE CONSOLE PAUSES THE WORLD AND THE OVERLAY DOES NOT, WHICH IS ONE DECISION MADE TWICE.**
  Both answer *should the world be stopped?* and the answers are opposite for the same reason: a
  clock that runs while you type at it photographs a moving target, and a frame time is worthless
  unless frames are still happening. So the console declares `pauses_world` and `UiRoot`'s table
  does the rest, and the overlay is a `CanvasLayer` at layer 101 that never enters the stack, holds
  no pause, takes no focus and answers no cancel. **Anything that must be READABLE DURING
  gameplay is not a screen** — that is the general form.
- **A DEV TOOL'S CHROME IS TEXT AND ITS OUTPUT IS DATA.** The console's title and input hint are
  localization keys like every other screen's; its transcript is echoes of a typed command and the
  values that came back, and the overlay is numbers, neither of which any `strings.csv` could
  hold. This is the line `check_strings.gd` forces a developer surface to draw, and drawing it
  deliberately is the difference between satisfying the gate and routing around it.
- **A GUARD ASSERTED BY A TEXT SCAN MUST BE ANCHORED UNIQUELY, AND THE SCAN MUST SKIP COMMENTS.**
  `OS.is_debug_build()` is true everywhere the suite can run, so the release gate can only be
  asserted by reading source — and WP-14b's first attempt would have passed over a deleted guard
  twice over: once because the file EXPLAINS its gate in a comment, and once because the same
  fragment appeared in two functions. The second was fixed in the code rather than in the test.
  See gotcha 43.
- **GDScript, not C#.** The installed engine is the standard build; .NET is not available.
- **Warnings are errors.** `var x = 5` does not parse. Read untyped data via `DictRead`, never
  `int(value)` on a `Variant`.
- **Input actions live in code** (`src/systems/input/actions.gd`), so the editor's Input Map
  panel looks empty. Intentional — ADR-0003.
- **Ten autoloads, no `GameManager`.** Adding one requires an ADR.
- **THE STRING AUDIT CHECKS SINKS AND DECLARATIONS, NEVER LITERALS.** `check_content.gd` refused a
  general hard-coded-string audit in writing, and that refusal is right: nothing in a line of text
  says whether `"world"` is a log category, a flag namespace or a sentence for a player, and a
  partial tool that looks complete is how 409 passing checks happened. `check_strings.gd` (WP-14)
  therefore never inspects a literal and guesses. It asks two questions with mechanical answers —
  does the right-hand side of a **text sink** go through `tr()`, and does every `*_KEY` **const**
  name a real CSV row — because whatever reaches `.text` is player-facing by construction whatever
  it contains. Do not "improve" it into a literal classifier; that is the tool `check_content.gd`
  turned down, and its header says why.
- **A SMOKE TEST DRIVES A GAME, NOT THE DEMO.** WP-14's row said "the whole demo" and was re-framed
  in the commit that took it. `tests/unit/smoke_test.gd` composes the session from
  `tests/framework/fixtures.gd`, and its one game-shaped block asserts only that
  `GameConfig.first_area()` RESOLVES — never what it is called — and skips, counted, in a stripped
  checkout. The rule is TESTING.md's and `check_boundary` enforces it over `tests/unit/`; a smoke
  test is not an exception to it just because "end to end" sounds like it should name real places.
- **ONE content scan, five typed façades — and the base is on the RESOURCE, not the registry.**
  `ContentScan.into()` is the only scan-and-validate in the project; `ContentEntry` is the base
  every catalogued `.tres` extends. Each registry keeps its own `content_dir`, its own typed
  cache and its own typed accessor, because a base-class `static var` is ONE storage shared by
  every subclass (gotcha 37) and because an untyped accessor is against non-negotiable #2.
  Settled by T3.1 after WP-08 and WP-11 costed it twice. Do not re-argue it, and do not "finish
  the job" by moving `has()`/`count()`/`rescan()` onto a base — those name their own type.
- **No jumping.** Vertical movement is authored: a `ClimbPoint` names two markers and asks
  `PlayerController.begin_climb()`. The climb turns its corner at the *top* end, both going
  up and coming down, so it never cuts through the ledge.
- **A climb is refused, not hidden.** Mid-air gets `RefusalReason.NOT_GROUNDED` with a
  message, on the same reasoning that makes a locked gate offer its prompt.
- **A trigger volume never names its consequence.** It sets a flag and emits
  `Events.trigger_fired`; anything may watch either. Same reasoning as the lever.
- **A time skip is one event.** `Clock.skip_to_hour` routes through `set_time`, never
  `advance_minutes` — an eight-hour sleep must not emit 480 `minute_passed` signals.
- **Inventory is a component, not an autoload.** Interactables are handed the interactor, so
  `Inventory.of(who)` needs no global and works for an NPC or a stash too. A global would
  hard-code "one bag in the universe" into every interactable.
- **Capacity is unlimited**, behind `can_accept()`. Slots or weight go in that one method.
- **`ItemCategory` stays an enum.** The eight values are a closed set and a new *item* never
  needs a new category, so it does not violate the no-code-per-item rule.
- **Item instances are deferred** until something actually has durability; `{id, count}` is
  enough. Never persist an enum ordinal — persist ids.
- **Input is held by NAMED TOKENS, never a boolean.** `InputLock` on the player and on the
  interaction sensor. `lock(&"dialogue")`, `release(&"dialogue")`. A boolean broke the moment
  WP-01 gave it a second caller, and a counter would strand instead. Do not reintroduce
  `set_input_locked(bool)` as a convenience over the top of it.
- **A screen never pauses anything itself.** It declares `pauses_world` and `closes_on_cancel`
  as a `UiScreen`, and `UiRoot` does the rest. `UiRoot.is_gameplay_input_allowed()` is the one
  truth; everything else listens to `Events.ui_mode_changed`.
- **A screen declares its flags in `_init`, never in `_build`.** `_build` runs from `_ready`,
  i.e. after a caller has had its chance to override one, so setting `pauses_world` there
  silently discards an overlay's request to keep the world running. `StubScreen` did exactly
  that and made the overlay assertion in `ui_test.gd` pass vacuously for a whole package.
- **The HUD is a layer, not a class.** The clock, the prompt and the toasts are independent
  siblings under `UILayer`, each subscribing to the one signal it draws. There is no `Hud`
  node owning them, and adding one would only create somewhere for the fourth readout to
  accumulate.
- **An inventory screen is handed its carrier**, `InventoryScreen.for_carrier(who)`, on the
  same reasoning as `Inventory.of(who)`: the same window shows an NPC's satchel or a stash.
- **One node binds actions to screens.** `ScreenKeys`, under `UILayer`. The journal key and
  the map key join it there rather than each finding a different home, which is how a boolean
  per screen was born last time.
- **A dialogue condition is a CLOSED SET of comparisons, never an expression.** `FlagTest` has
  six values, `FlagWrite` has five. The moment a conversation can hold an expression it needs a
  parser, error reporting and a sandbox, and the .tres stops being reviewable in a diff. When
  six are genuinely not enough, add a seventh, not a grammar.
- **A conversation is an ORDERED ARRAY and the runner falls through.** The entry point is the
  first node whose condition passes, not `nodes[0]`, and a skipped node falls through to the
  next in authored order. That is what makes "if we have met, greet me differently" two nodes
  and no wiring. Effects fire on ARRIVAL, so a node has the same consequence however reached,
  which is why a choice has a condition but no effect.
- **A failing choice is OMITTED, not shown disabled** — the opposite of a locked gate, on
  purpose. A gate you cannot open teaches you there is something to come back for; a reply you
  cannot give teaches you only that the writer thought of it. So `choose(index)` indexes what is
  ON SCREEN, not the authored array.
- **A conversation is NOT SAVED.** Persisting a position writes a node id into the save file,
  making every node id in every .tres a permanent public identifier — rename one and old saves
  load into a position that no longer exists. The section exists, is always empty, and logs what
  it discarded. A save taken mid-conversation reloads with the conversation over and control
  returned.
- **A waypoint must be somewhere the BODY can walk, which is not the same as somewhere the
  navmesh covers.** A `NavigationMesh` bakes `agent_max_climb` into the walkable surface and
  will happily bridge a knee-high step, but `CharacterBody3D.move_and_slide()` has no step-up at
  all. This game has no jumping and authored vertical movement, so the climb limit is kept BELOW
  anything the body cannot manage and waypoints sit on the ground.
- **A navmesh is baked at load, never checked in.** A committed one goes stale the moment
  someone moves a wall, and a stale navmesh fails silently. It is baked behind the same curtain
  that already hides the shader warm-up, and the polygon count is logged so an empty bake is an
  error rather than silence.
- **A schedule names a WAYPOINT, not a position**, and has no `until_hour`: an entry runs until
  the next begins and the last wraps past midnight, so a day is always completely covered and
  two entries cannot disagree about who owns 14:00.
- **A UI takes a dialogue choice by IDENTITY, never by index.** `take(choice)`, not
  `choose(index)`. A conversation leaves the world running, so any flag written while the box is
  open can shift every index under the player's finger.
- **`Weather` renders NOTHING, and `WeatherVisuals` decides NOTHING.** Every number in the
  visuals is read from `Weather`; the toast on a change is emitted by the visuals, so the state
  machine still does not know a screen exists.
- **A weather emitter is TOLD its weight; it never polls.** One that read `Weather` itself would
  be a second place the rules live, and the two would disagree mid cross-fade.
- **Weather particles are GENERATED, never authored.** Art is deferred indefinitely, so a rain
  texture is a dependency this project will not take.
- **`SurfaceWetness` duplicates every material it touches**, or a scene's shared sub-resources
  would leave the courtyard wet after a reload on a clear day.
- **Wetness is a pure `RefCounted`, not a node field**, because drying is the only part with
  memory and no assertion can wait for a `_process` frame.
- **A REFUSAL and a FAILURE are different things.** A refusal happens before anything: the
  player is told why and nothing changes. A failure happens after committing: the action ran, it
  did not work, and it COST something. An action that could only refuse is a lock with extra
  steps; one that could only fail gives the player no way to read the situation first. Path
  actions have both, and `once` applies to SUCCESS only, or a single early failure would lock
  the player out forever with no way back.
- **A path action is a THRESHOLD, never a dice roll.** A random one makes the player save-scum,
  and a save-scummed mechanic is experienced as a slot machine rather than as a relationship.
- **Standing is a namespace over `Flags`, not a store**, keyed `standing/<who>` and NOT through
  `PersistentState` â that namespaces per area, which is right for a chest and wrong for a
  person: the keeper who dislikes you in the courtyard must still dislike you in the hall.
- **An NPC's actions are overlapping Interactables, not a menu.** The sensor already ranks and
  Tab-cycles between overlapping targets; a menu would be a second selection mechanism competing
  with the first.
- **A door names an id and a spawn, and nothing else.** `AreaDoor` emits
  `Events.area_change_requested` and stops. It does not load, fade or place the player.
  `Director` owns the sequence and the guard, and nothing else calls `change_area()` — a door
  that ran its own transition would be a second, unguarded path, which is how two doors firing
  at once leaves two areas in the tree.
- **An interior has its own light, not a frozen sample of the outdoor one.** `follow_clock =
  false` now means the Interior group on `EnvironmentDriver` is applied once and the outdoor
  path never touches that area's sun. It used to mean only "stop updating", which is not the
  same thing and made an interior's brightness depend on the hour it was entered at.
- **The loading indicator is the ONE node after `ScreenFade`.** Gotcha 12 says the curtain must
  be the last child of `UILayer` so it covers every screen. The indicator has to be readable
  *while* the curtain is up, so it is the single deliberate exception, and there should not be
  a second one.
- **Pause is per node, not global.** `get_tree().paused` is set by UiRoot, but each node
  decides for itself in its own `_ready()`. The full table is the header of
  `src/ui/root/ui_root.gd`. Clock and Weather stop; Audio, Director, ScreenFade,
  NotificationToast and DevCapture do not.
- **A TEST BUILDS ITS OWN CONTENT, and a test that names demo content is testing the demo.**
  `tests/framework/fixtures.gd` is the seam, and its rule is one line: **in memory when a system
  is HANDED content, on disk when a system LOOKS IT UP BY ID.** The three registries scan a
  directory (ADR-0006) and cache statically, so an in-memory `ItemDefinition` is invisible to
  `Inventory.add(id)`; the fixtures write `.tres` files to `user://test_fixtures/` and point
  `content_dir` there. A test-only injection method on each registry was rejected: a backdoor in
  engine code that exists for the suite and nothing else is worse than a temp folder, and going
  out through `ResourceSaver` and back through the real scan proves the authoring round trip as a
  side effect. Since T1.3 `check_boundary` scans `tests/` too, so this is a gate, not a habit.
- **A CASE THAT ASSERTS THINGS ABOUT THE DEMO SKIPS LOUDLY, never silently.** `skip()` stands in
  for the assertions it replaces, so the plan is the same number with or without `data/` and a
  stripped run prints what it gave up. `861 passed, 0 failed, 12 skipped` is a different claim
  from `861 passed`, and the difference is the whole point.
- **EVERY CASE DECLARES A PLAN, and the number is maintained by hand.** TAP's `1..N`. It is the
  only thing that can see a crash that swallowed an assertion, an early return, a commented-out
  block, or a case that asserts nothing — see gotcha 24 for why nothing cheaper works. A stale
  plan fails loudly with both numbers and the case name, so it is self-correcting friction rather
  than a trap.
- **A CONTENT ROOT IS A `static var`, NOT A CONST.** `ItemDb.content_dir` and its two siblings.
  A game may keep its items somewhere else, and the fixtures do. `ItemDb.ITEM_DIR` is now the
  DEFAULT, not the answer, and `tools/check_content.gd` validates whatever the root currently is.
- **NO FILE UNDER `src/` OR `tests/` MAY NAME DEMO CONTENT**, and since T1.2 `tools/check_boundary.gd` is
  what says so. It derives the forbidden names from `scenes/areas/` and the ids in `data/`
  rather than listing them, so it cannot go stale. **Comments are exempt, code is not:** a `##`
  line saying `data/items/rose_key.tres must declare id = &"item/rose_key"` is teaching by
  example and changes nothing; a `const` changes behaviour. One directory is exempt,
  `src/systems/debug/`, because those three files exist to drive the demo — and the exemption is
  conditional on their argument parsing staying behind `OS.is_debug_build()`, which the same
  tool checks. Do not widen the exemption; a second exempt directory means the rule is gone.
- **A GAME-SPECIFIC ANSWER LIVES IN `project.godot`, read through `GameConfig`.** The starting
  area is `[game] world/first_area`, the game's name is `application/config/name`, and
  `src/core/util/game_config.gd` is the only place under `src/` that reads either. An `@export`
  on the boot scene was rejected: `scenes/boot/` is engine too, so that would have moved the
  leak, not closed it. An empty `first_area` is a legal state — a template nobody has put a game
  in yet — and `Director` says so instead of clearing the flags and going quiet.
- **AN EMPTY CONTENT FOLDER IS NOT AN ERROR.** `ItemDb`, `DialogueDb` and `ScheduleDb` used to
  report "no items found" as a problem, which made a stripped template fail its own gate on step
  one of `docs/NEW_GAME.md`. A file that is present and does not load is the error, and it is
  reported per file. Whether a game needs items is that game's question, not this base's.
- **`export_filter="all_resources"` IS PART OF THE ENGINE CONTRACT, NOT A PREFERENCE.** The three
  registries find content by directory scan, so those resources are nobody's dependency and only
  that setting ships them — measured both ways in T2.0, and asserted by `tests/unit/export_test.gd`
  so a consuming game that narrows it fails rung 4 instead of shipping empty catalogues.
- **THE EXPORT IS VERIFIED BY A DEBUG BUILD, AND THE READOUT NEVER REACHES A PLAYER.**
  `CatalogueReport` reports every catalogue's count and RESOLVED PATHS at boot, behind
  `OS.is_debug_build()`. The paths and not only the counts, because a partial ship is worse than an
  empty one: three of four items is a plausible number. It ASKS the same registries the game asks —
  a reporter that did its own scan would be reporting on itself.
- **AN EXPORT PROOF CANNOT BE AN ASSERTION, and the suite says so out loud.** A test running under
  `res://` cannot test a build it is not running in, so `export_test.gd` asserts
  `is_exported() == false` rather than leaving the blindness implied. The proof is a RUN of the
  exported executable with both sides' numbers quoted in `DEVLOG.md`. There is deliberately no CI
  export rung: a GPU-less runner has no platform template, the same honesty T1.4 applied to the
  windowed capture.
- **A FACING IS NOT A COLUMN, and the sector width lives in exactly one place.** `GameEnums.Facing`
  has eight values because eight is how many directions the GAME reasons about; `layout.facings` is
  how many the ART distinguishes. The two are quantised SEPARATELY from the same angle — the enum
  from `GameEnums.Facing.size()`, the column from `SpriteSheetLayout.column_for_angle()` — because
  the obvious alternative, mapping the enum down with `int(facing) * facings / 8`, puts the number 8
  back in the code in a second place, which is the exact bug T2.1 existed to remove. When
  `facings == 8` they agree by construction, so the existing sheet did not move.
- **NO SHEET DIMENSION LIVES IN CODE.** `SpriteSheetLayout` is the art CONTRACT: facings, frames,
  animation blocks, cell size and the idle/walk row offsets. `CharacterVisual` reads all of it and
  holds none of it, and `tests/unit/art_contract_test.gd` FAILS if `character_visual.gd` regains a
  `TAU / 8` or a `FACING_COUNT`. The cell size is DECLARED and validated against the texture rather
  than divided out of it, so a sheet of the wrong size is a named problem instead of every
  character in the game silently misplaced.
- **AN UNWIRED `layout` IS LEGAL AND LOUD.** `CharacterVisual` falls back to 8x4/32x48 and WARNS,
  naming the node. Gotcha 2's whole lesson is that a silent default looks exactly like success, so
  the fallback exists to keep a node recognisable while the log says it is unwired — it is not a
  fallback anything should rely on.
- **THE UI LOOK IS ONE FILE, AND THE PALETTE IS NOT COPIED INTO THE VARIATIONS.**
  `assets/theme/ui_theme.tres`, wired as `gui/theme/custom` so it reaches the HUD too — which is
  drawn UNDER `UiRoot` and would have been missed by handing the theme to the stack. Type variations
  carry ONLY `font_size`, the one thing that genuinely differs by role; the four colours and six
  insets live once each in `UiPalette` and `UiMetrics` and the screens read them by name. A `Theme`
  resource has no variables, so a colour repeated into nine variations would be nine places to
  change and "one Theme edit restyles every screen" would simply be false. A test case fails if any
  of the five styled files writes a `Color(` or an `add_theme_font_size_override` down again.
- **A DOCUMENT IS TASK-FIRST OR IT IS A FILE HEADER.** The headers in this project are good and
  are found only by already knowing which file to open. `AUTHORING.md` therefore starts from
  "I want to add an area", not from `AreaRoot`, and the four consumer documents are routed to from
  both `CLAUDE.md`'s table and `CONTEXT.md` — a document nobody is routed to is a document nobody
  reads. The extension surface went into `ARCHITECTURE.md` rather than `AUTHORING.md` because
  `AUTHORING.md` opens with "you never edit `src/`" and a section on subclassing underneath that
  would contradict it.
- **A DOCUMENTATION CRITERION IS PERFORMED, NEVER ASSERTED.** T2.2's exit criterion was closed by
  authoring a real area, NPC and conversation from the documents alone and running them; the
  deliverable of that exercise is the list of six things the documents got wrong. A walkthrough
  that works first time means the author was still reading from memory.
- **THE DOCS ARE GATED FOR EXISTENCE, NOT FOR TRUTH.** `tests/unit/docs_test.gd` asserts that every
  `res://` path the documents name resolves and that every property in a worked `.tres` example
  exists on the class that block declares. It cannot check that a documented *sentence* is true —
  only a walkthrough does that. `DEVLOG.md` is exempt from the path scan, because a history
  necessarily names files it correctly removed.
- **A QUEST STEP NAMES A FLAG CONDITION, NEVER A CALLBACK.** The same closed set of six comparisons
  `GameEnums.FlagTest` gives a dialogue condition, evaluated by the same `FlagQuery.passes` both
  call. That is what makes a quest authored data (adding the fiftieth touches no code, ADR-0006's
  test) and it is what lets the rest of the game feed a quest without knowing quests exist — the
  placeholder quest is started by a conversation effect, advanced by the courtyard lever and
  completed by the dais trigger volume, and none of those three files was touched. The cost is
  stated rather than hidden: **a step cannot read an item count**, because `Inventory` keeps counts
  and not flags, so "bring me three petals" is not authorable and the seam is a `Pickup` that writes
  a flag.
- **QUEST PROGRESS IS DERIVED; EXACTLY TWO THINGS ARE LATCHED.** `flags.gd` says derive what can be
  derived, and the current objective is the first step whose test fails, asked live on every flag
  change. Two things cannot be derived: that a quest STARTED (clearing its start flag must not
  un-give a quest carried for three hours) and that it COMPLETED (a step testing `AT_LEAST 3` on a
  counter must not reopen when something decrements it). Those two are the whole save section, held
  as **two lists of quest ids** — never an enum ordinal. An ACTIVE quest's objective is deliberately
  NOT latched, so clearing the flag behind objective two brings objective two back; a per-step latch
  would double the saved state to remove a behaviour nobody has asked for. Both halves are asserted,
  because a latch nothing tests is indistinguishable from a cache.
- **A COMPLETED QUEST GRANTS NOTHING.** It emits `Events.quest_completed` and stops. A `reward_item`
  field would put `Inventory` and a player — both `gameplay` — inside a `systems` tracker, and
  `src/` points downward only. Anything that wants to hand over an item listens; anything that wants
  to gate a conversation tests the flag the last step tested, with no code at all. Same reasoning
  that keeps `Weather` from drawing rain.
- **THE FLAG-TEST TABLE LIVES IN EXACTLY ONE FILE**, `src/core/state/flag_query.gd`, extracted from
  `DialogueRunner` when a quest step began asking the identical question. Two copies of a rule
  eventually disagree, and the disagreement would surface as a quest that will not complete for a
  flag a conversation is perfectly happy with. A test fails if the table grows back in either file —
  the gate `art_contract_test.gd` established for sheet dimensions. Only the READ half is shared:
  `FlagWrite` still has one caller, and a shared file serving one consumer is not a seam.
- **THE FOURTH REGISTRY WAS RECONSIDERED AND THE COPY WAS KEPT.** `schedule_db.gd` said "three is a
  pattern, four is a problem — if a fourth registry appears, that is the moment to reconsider."
  Reconsidered in WP-08; GDScript has no generics, so a shared base could only cache `Resource` and
  hand it back untyped, making all four accessors a cast at the call site — and static typing is
  non-negotiable #2, not a preference. What is genuinely shared already is: `QuestDb` calls
  `ItemDb.resource_paths()` rather than copying the `.remap` handling. The refactor that pays is a
  base plus a thin typed façade each, and it is **T3.1 on the board** rather than a shrug.
- **A CONTENT CHECK PRINTS WHAT IT CANNOT VALIDATE.** `check_content` prints every flag a quest and
  its steps name and validates none of them. A flag can be written from a scene, a conversation, a
  path action or another quest, and the writer that matters most is a runtime one —
  `PersistentState` builds `obj/<area>/<object>/<field>` at load — so a checker that failed on any
  flag with no findable writer would be wrong most times it fired. A partial check that looks
  complete is the failure mode this project exists to prevent, so the flags go in the build log
  where a reviewer reads them.
- **EQUIPMENT IS A FLAG, NOT A STORE.** `Equipment` is a component beside `Inventory` — same
  `of(who)` reasoning, so an NPC or a stash can have one — and it owns NO DICTIONARY. A slot is
  `equip/<wearer_id>/<item id>` in `Flags`, which is `PersistentState`'s `obj/<area>/<object>/<field>`
  and `Standing`'s `standing/<who>` applied a third time. Three things fall out and together they
  are the whole argument against a `Dictionary[EquipSlot, StringName]` plus a save section: it is
  already saved (no register, no version, no migration, and a new game clears it because
  `start_new_game()` clears flags); a `Gate`, a `QuestStep`, a `DialogueChoice` and a `ClimbPoint`
  gate on it **with no code and no new field**, which is WP-08's seam used by a second system; and
  `flag_changed` already announces it. The cost is stated: the key contains an item id, so renaming
  an item's `.tres` brings it back stowed.
- **THE ITEM STAYS IN THE BAG WHILE IT IS HELD.** Moving it out would make equipment a second place
  items live — `Inventory.count_of()` would begin lying and `Gate.requires_item` would refuse a key
  that is in the player's hand. So equipping is purely a flag, and the price is that losing the item
  has to stow it: `Equipment._revalidate`, on `inventory_changed` rather than on `item_lost`, because
  that is the one signal every path emits including a restored save. It is the invariant the suite
  fails first when broken.
- **ONE ITEM PER SLOT, AND THE NEWCOMER WINS.** Holding a second LIGHT stows the first rather than
  being refused, because a refusal would make swapping a lantern a two-step chore the player cannot
  see a reason for. `can_equip()` is the seam a strength rule or a two-handed rule goes into, the
  analogue of `Inventory.can_accept()`.
- **`EquipSlot` HAS NO WEAPON AND NO ARMOUR VALUE**, the same absence `ItemCategory` has, and for
  the same retraction. A slot answers "what does holding this let you do", never "how hard do you
  hit". It is append-only, because an `ItemDefinition` stores it as an ordinal.
- **A REFUSAL MAY CARRY AN AUTHORED LINE, and a reason is a CATEGORY rather than a sentence.**
  `interaction_refused` carries a `message_key` beside `args` — travelling on the signal rather than
  asked of the target, exactly as `args` does — and `Interactable.refusal_key(who, reason)` is the
  override, with "" meaning "compute `refusal.<reason>` from the enum". The alternative was a new
  `RefusalReason` per authored line, which is a category per sentence and the growth the closed sets
  exist to prevent. `Gate.locked_key` and `PathAction.refusal_key` had been declared, validated by
  `check_content` and read by NOTHING since WP-01 and WP-07 — see the defects section.
- **A UI REDRAWS ON THE WORLD'S SIGNAL, NEVER ONLY ON ITS OWN INPUT.** `InventoryScreen` refreshed
  on `inventory_changed` alone, so a row press redrew and an equip from anywhere else did not — and
  the first WP-09 capture photographed a held lantern drawn as merely carried. A press is never the
  only writer: staging equips from the command line, and `_revalidate` stows on its own. That is
  why `equipment_changed` exists at all, and it is a general rule rather than one screen's bug.
- **DISCOVERY IS A FLAG, AND THE NAMESPACE CONVENTION IS NOW A PATTERN.** `map/<area id>` in
  `Flags`, with no store, no save section, no migration and no register — the FOURTH use of
  namespace-over-`Flags` after `PersistentState`'s `obj/<area>/<object>/<field>`, `Standing`'s
  `standing/<who>` and `Equipment`'s `equip/<wearer>/<item>`. Three independent systems on one
  convention is evidence it generalises rather than a coincidence, and the next thing that needs
  saved per-thing state should reach for it before reaching for a save section. Two things fall
  out and they are the whole design: anything that writes the key reveals a place (a
  `DialogueChoice` effect, a `TriggerVolume`, a `Lever`, a quest consequence — none of which was
  touched), and a `Gate` with `requires_flag = &"map/<id>"` is a road that opens once you know
  where it goes. The cost is stated: renaming an area's folder makes an old save forget it was
  found, the same price `Equipment` pays for an item id.
- **A MAP DOT'S POSITION IS AUTHORED DATA, IN NORMALISED 0..1 SPACE.** `AreaDef.map_position`, and
  `MapScreen` has never heard of any area. A map that knew where the courtyard goes would be
  engine code naming demo content, which `check_boundary` fails the build over — proved by
  planting it. Normalised rather than pixels so one authored number is right at every window size
  and every UI scale.
- **AN AREA ID HAS NO REGISTRY PREFIX**, unlike `item/` and `quest/`. Those prefixes make a save
  file self-describing about a thing that lives only in a save file; an area id is already a
  public identifier, because it is a folder name. `data/areas/orchard.tres` declares
  `id = &"orchard"`, which is what `Director` travels to, so there is no translation table
  between `AreaDb` and `Director` — and a translation table is a second place the truth lives.
- **FAST TRAVEL ASKS; IT DOES NOT TRAVEL.** `WorldMap.travel_to` emits
  `Events.area_change_requested` and stops, exactly as `AreaDoor` does. Four refusals, each
  logged: not on the map, not found, already there, already moving. Nothing but `Director` calls
  `change_area()`, which is what keeps two things firing at once from leaving two areas in the
  tree — and a fast-travel path that ran its own transition would have been the second one.
- **AN AREA WITH NO `AreaDef` IS NOT AN ERROR**, it is a cupboard a game chose not to draw. It is
  said at INFO level once per arrival rather than warned, because the boot rung counts warnings
  and a template with no map at all is a legal state — but it is said, because "the .tres is
  authored and the dot never appeared" must not be silent. Same shape as an empty content root.
- **STAGING THAT PUTS SOMETHING ON SCREEN WAITS FOR THE WORLD TO STAY STILL, NOT MERELY TO ARRIVE.**
  `dev_stage._settle_stable(20)` demands twenty CONSECUTIVE settled frames and resets on any
  transition, which is gotcha 21's persistence shape applied to staging. `--goto` and
  `--open-menu` both leave `_wait_for_area` on the same frame, so a fixed extra delay only moves
  the race; a counter that a starting transition resets cannot be satisfied early.
- **AN ATTRIBUTE'S NAME LIVES ON ITS CONSUMER, NEVER ON THE CONTAINER.** `attr/<who>/<name>` is the
  fifth namespace over `Flags`, and `Attributes` has NO registry, no `AttributeDef` and no enum of
  names — any StringName is an attribute the moment something writes it, which is ADR-0006's
  no-code-per-thing test met without a sixth directory scan. What stops that becoming the failure
  this project keeps catching is a rule about where a name is written down:
  `PlayerController.PACE` sits beside the line that reads it, so **an attribute nobody reads has
  nowhere to be declared** and `attributes.gd` cannot grow a table of good intentions. The cost is
  stated: naming an attribute is free, READING one is always a line of engine code, and
  `AUTHORING.md` says so to an author's face. The value is a STEP, not the number, because a flag
  holding `4.7` would be a walk speed authored into a save file and the tuned `walk_speed` would
  stop being the truth.
- **A SURFACE IS METADATA ON GEOMETRY, INHERITED FROM THE NEAREST TAGGED ANCESTOR.**
  `metadata/surface` on a body or anything above it. A component would be a node per floor tile; a
  group would share one flat namespace with `navmesh_source`, where a typo becomes a second surface
  silently; an ENUM would be a list of surface names in `src/`, which `check_boundary` fails the
  build over. Inheritance is what makes it cheap to author, and the demo's third surface comes from
  it. A step's timbre is DERIVED from the name for the same boundary reason a table is refused: a
  game that authors `sand` hears it without editing `src/`.
- **A FOOTSTEP IS THE ONE CLAIM THE LADDER CANNOT SEE AT ALL, AND THE FILE IS SPLIT ALONG THAT
  LINE.** Not visual, so no capture reads it; not synchronous, so no assertion reaches it; and
  headless the audio driver is `Dummy`, where every `play()` leaks (gotcha 20). So the pure parts
  — the stride accumulator, the surface query and the two timbre functions — are asserted, and the
  raycast, the frame loop and the `play()` are a windowed run with the log quoted. The same split
  `SurfaceWetness` made for drying, and it is said out loud rather than implied.
- **AN ITEM COUNT IS A FLAG THAT IS PUBLISHED DOWNWARD, NOT A BAG THAT IS READ UPWARD.**
  `bag/<carrier_id>/<item id>` in `Flags`, written only by `Inventory._publish`, and it is the
  general answer whenever a lower layer holds something an upper one must observe. `QuestTracker`
  is `systems` and `Inventory` is `gameplay`, so a tracker reading a bag points the wrong way —
  the same violation WP-08 refused over `reward_item`. Publishing inverts it, and the capability is
  identical: `QuestStep` gained NO field, `QuestTracker` gained no knowledge, and `item_count_test`
  FAILS if either file's code names `Inventory`, `ItemDb` or `BagKeys` — nothing else in the suite
  could, because the behaviour would be identical with the layer rule gone. Settled by T3.3 from
  the FIRST of WP-09's two costed designs. Do not "simplify" it by handing the tracker a bag.
- **A DERIVED FLAG IS READABLE, ANNOUNCED, AND NOT SAVED.** `Flags.declare_derived(prefix)`, and
  `_collect_save` skips those keys. That is what makes the count projection legal rather than a
  second copy of the truth: `flags.gd`'s own header forbids storing anything recomputable, and a
  count mirrored from the bag is recomputable by definition. The consequence is a duty rather than
  a freedom — the PUBLISHER must republish whenever the store is wiped under it, which is why
  `Inventory` subscribes to `game_started` (clear) and `game_loaded` (republish, after every
  section, so the answer cannot depend on save-participant order). Anything else that wants to be
  readable-but-derived pays the same price and should say so in its header.
- **A COUNTED CONDITION IS `AT_LEAST` OR `EQUALS`, AND `AT_MOST` DRAWS NO TALLY.** `AT_MOST` is a
  ceiling, so "2 / 3" under *keep it below three* tells the player to gather more of the one thing
  they must not; a `condition_value` of 0 is not a count either, because `AT_LEAST 0` passes with an
  empty bag. `FlagQuery.progress()` answers `(have, need)` with `need == 0` meaning "not a count",
  and `check_content` fails the build on both mistakes rather than letting a journal draw `0 / 0`.
- **THE BAG KEY SHAPE LIVES IN `src/core/state/bag_keys.gd`, AND NOT ON `Inventory`.** Three places
  need it and none may rebuild it: the bag WRITES it, `check_content` PARSES it to validate the item
  id, and the suite asserts on it. The reason it cannot sit beside `Equipment.PREFIX` is a compile
  error, not taste — `check_content` runs under `--script`, where autoload identifiers do not
  resolve, so naming `Inventory.PREFIX` would not compile. Keep that file free of autoloads.
- **ONE FLAG NAMESPACE IS VALIDATED BY `check_content`; THE REST ARE STILL ONLY PRINTED.** WP-08's
  rule stands — a flag can be written from anywhere, so failing on one with no findable writer would
  be wrong most times it fired. `bag/<carrier>/<item id>` is the exception because it has exactly
  ONE writer and half the key is an item id the tool can look up. The CARRIER is deliberately not
  validated: it is an `@export` in a scene the tool does not open, and a game may put a bag on an
  NPC or a stash.
- **A NEW GAME IS A NEW BAG.** `Director.start_new_game()` clears the flags; `Inventory` now clears
  its counts on `game_started` for the same reason. It did not before T3.3, so the previous run's
  items carried into a fresh game — unreachable in practice and invisible to every gate, and found
  only because the count projection cannot tolerate the two disagreeing.
- **A MATERIAL IS SHARED WHEN TWO AREAS WANT THE SAME THING, AND NOT BEFORE.**
  `assets/materials/` holds `StandardMaterial3D` resources more than one area points at, and it
  holds exactly ONE — the wood the two demo areas had each grown a byte-identical inline copy of.
  The other five were deliberately left inline, and the reason is the whole rule: **a tiling rate
  is a property of the surface it is stretched over, not of the substance.** One area tiles stone
  at `(3, 3)` and the other floors it at `(8, 8)` and walls it at `(6, 2)`, so hoisting those gives
  a shared file with a per-area override on every user — the duplication with an extra
  indirection, and a palette rather than a seam. Nothing under `src/` knows the folder exists: this
  is a scene-authoring convention, not a system, so there is no registry, no id and no sixth
  directory scan. A test fails if two areas declare the same material inline, comparing bodies with
  `ExtResource` ids resolved to paths — which is what nobody could do by eye, and why the duplicate
  survived. What makes sharing safe was already true: `SurfaceWetness` DUPLICATES every material
  before darkening it, so rain outdoors cannot leave an interior's floor wet after an area change.
- **THE LOOK IS PER AREA AND THE STRUCTURE IS IN CODE.** The twenty post-stack values on
  `EnvironmentDriver` are `@export`s at exactly the numbers T2.1 shipped; the tonemapper, the fog
  mode, the glow blend mode and `AMBIENT_SOURCE_COLOR` stay in code because they are what the rest
  of the file ASSUMES rather than what an area tunes — `_apply_now` writes `ambient_light_color`
  every frame, which means nothing unless the source is a colour. Per area rather than per project
  because the driver already lives in the area scene and its `Interior` group already varies that
  way. An "environment look" `.tres` was considered and dropped: a `SpriteSheetLayout` is shared
  between nodes in one scene, a post stack is one per area, so the resource would add a class, a
  folder and a wiring step to reach the same numbers. **The four expensive effects are exports
  despite being `false` everywhere, because a value a consuming game cannot reach is not a seam,
  it is an opinion.** The day/night KEYFRAMES table is NOT part of this and no seam is claimed for
  it: that is a curve, not a look setting.
- **A SEAM THAT NOTHING USES HAS NEVER BEEN TRIED, AND FOUR DOCUMENTS CAN AGREE IT IS MISSING WHEN
  IT IS NOT.** `HD2DCameraRig` has carried its framing as `@export`s since it was written and its
  header has said "duplicate it and change the numbers" the whole time; what was missing was an
  AREA setting one. T2.1's leftover list said the seam did not exist and three more documents
  copied that. So an area now authors its own framing — the interior at 36 degrees and 9.5 m
  against the outdoor 27 and 14 — and a test fails if none does. Generalise the lesson rather than
  the fix: **a backlog line about code is worth re-checking against the code before it is worked**,
  and a claim repeated in five documents is repeated, not verified.
- **AN UNDOCUMENTED FORMAT IS SETTLED BY MEASUREMENT, NOT BY STOPPING.** `[importer_defaults]` in
  `project.godot` sets `detect_3d/compress_to = 0`, so a PNG a game drops in imports correctly the
  first time and no re-import can put VRAM block artefacts through pixel art. T2.1 refused to
  hand-author it because the section is absent from `--doctool` and this project checks every name
  against the API dump — the rule was right, the conclusion was not, and gotcha 39 records the
  reversal: non-negotiable #1 says the ENGINE decides, and the engine can be asked. Exactly one
  value is set, because the other three were measured to be Godot's own defaults already and **a
  default nobody needs is a default nobody maintains.**
- **GIT LFS IS REFUSED, NOT DEFERRED, AND THE THIRD REASON IS THE ONE THAT DECIDES IT.** Pointers
  for a 2 KB procedural placeholder are overhead, and enabling them puts the CI checkout on a
  dependency it does not declare — both were already recorded. The one that had not been said is
  that **this template cannot verify the change it would be making**: proving LFS works needs an
  LFS-enabled remote and a CI run against real binaries, and neither exists while art is deferred.
  The refusal lives in `ART_CONTRACT.md` with the three steps to turn it on, and `.gitattributes`
  keeps a pointer rather than restating it.
- **A BACKLOG ITEM MENTIONED IN FIVE PLACES IS TRACKED IN NONE OF THEM.** T3.2's stated deliverable
  was as much that its five items stop appearing in five documents as that four of them got built,
  and the rule that came out of it is about STATE and not about word counts: **the current state of
  anything lives in exactly one document — the one its consumer reads — and every other mention is
  either a historical record that says "closed by <package>" or it is deleted.** A finished thing
  named in a package section, a settled decision and an inventory row is the normal record shape
  and is fine; five documents each describing PENDING work is the shape that rots, because none of
  them is the one that gets corrected. Nothing was removed from the record; T2.1's section still
  says what T2.1 left, because that is still true.
- Six ADRs in `docs/decisions/` cover the layered `src/`, warnings-as-errors, the input map,
  and save-via-callables.

## Verify before claiming anything is done

Since T1.4 these run in CI too — `.github/workflows/ladder.yml`, on every push, pull request and
manual `gh workflow run ladder.yml --ref <branch>`. CI is not a substitute for running them: the
windowed capture is the one rung a GPU-less runner cannot do, and push events on this repo have
lagged by as much as 25 minutes.

```bash
G=/c/Rai/softwares/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
"$G" --headless --check-only --script <file>   # type gate
"$G" --headless --import                       # scenes and resources
"$G" --headless --quit-after 30                # must end "0 warnings, 0 errors"
"$G" --headless res://tests/test_runner.tscn --quit-after 400   # 2,302 assertions, exit 1 on fail
"$G" --headless --script tools/check_budgets.gd            # must exit 0
"$G" --headless --script tools/check_content.gd            # must exit 0
"$G" --headless --script tools/check_boundary.gd           # must exit 0 — src/ and tests/ name no demo content, and no orphan CSV row
"$G" --headless --script tools/check_strings.gd            # must exit 0 — no player-facing literal, every *_KEY exists
"$G" --headless --script tools/check_layers.gd             # must exit 0 — core -> content -> systems -> gameplay -> ui
"$G" --headless --script tools/check_signals.gd            # must exit 0 — every declared signal has an emitter
"$G" --headless --script tools/check_methods.gd            # must exit 0 — every public method under src/ has a caller, or says NO CALLER
"$G" --resolution 960x540 --quit-after 90 -- --new-game --shot=<path> --shot-frame=70 --time=18:40 --freeze-time
```

## Eighty-three gotchas that each cost an hour

1. Autoload identifiers (`Log`, `Events`, …) **do not resolve** under `--check-only`. That
   error is expected. Rungs 2 and 3 are the real compile check.
2. `--headless` uses a dummy rasteriser and **shades nothing**. Visual claims need the
   windowed capture. A day/night system once ran, logged correct times, reported no errors and
   lit nothing — because one `@export` was unwired in the scene.
3. Author with 4 spaces, then `unexpand -t 4 --first-only` before saving. Tabs are the project
   style, and mixed indentation is a parse error.
4. The test suite is a SCENE entered positionally, never `--script`. Under `--script` the
   autoload identifiers fail to compile, so no test touching a system can run that way.
5. Do not name an `` after a native member. `Area3D` already has `priority`, so ours
   is `interact_priority`; redefining a native member is a parse error that cascades into
   every subclass as "could not resolve class".
6. `set_anchors_preset()` leaves offsets at zero, giving a zero-size Control whose text spills
   off screen. Use `set_anchors_and_offsets_preset()`.
7. `Container` is a NATIVE Godot class. `class_name Container` is a parse error that cascades
   into every subclass as "could not resolve class". Ours is `ItemContainer`. Check a name
   against the API dump before claiming it.
8. Configure an interactable BEFORE `add_child`. `object_id` is forwarded to `PersistentState`
   in `_enter_tree`, so anything set afterwards is too late and the object silently stops
   persisting. `TestCase.build()` then `attach()` exists to make that ordering explicit.
9. A body spawns at the area **origin** and is placed on its spawn marker a frame later, so
   an `Area3D` sitting near the origin sees it pass through. `TriggerVolume` arms two physics
   frames late for exactly this reason. Anything else that watches for bodies needs the same
   guard.
10. `TestCase.run()` is **synchronous** — the runner calls it, it does not await it. So no
    test can wait on a physics frame, which is why interactions are driven through `attempt()`
    and a climb through `climb_step(delta)` in a bounded loop. A test that needs a real
    physics step belongs in the windowed run instead.
11. **Autoloads are PAUSABLE by default**, so `get_tree().paused` silently stops `Clock`,
    `Weather` and `Audio` alike. Audio has to opt out explicitly or the score cuts out the
    moment a menu opens — and it is the autoload *node* that needs it, not just the
    `AudioStreamPlayer` children, because the cross-fade tweens are created on the node.
    Verified with `can_process()` in `tests/unit/ui_test.gd`, not assumed.
12. **Child order in a `CanvasLayer` is draw order.** `ScreenFade` has to come after every
    SCREEN or the curtain does not cover them. It was the first child until WP-02. Since WP-04
    exactly one node sits after it, `LoadingIndicator`, which has to be readable while the
    curtain is up — that is the only deliberate exception and there should not be a second.
13. **A RUN THAT QUITS MID-LOAD USED TO PRINT `Parse Error` FOR FILES THAT PARSE PERFECTLY, AND
    THAT IS FIXED — but the shape is worth keeping, because it is the only case in this project
    where the engine reported a failure that was not there.** Killing the process while a
    threaded load is in flight tore the loader thread down inside the text parser, which then
    printed `Parse Error` for `courtyard.tscn` and `wood.tres` plus leaked RIDs and leaked
    ObjectDB instances, *after* the run had already reported `0 warnings, 0 errors`. **Gotcha 22
    with the polarity reversed:** not an error a rung cannot see, but a FALSE error poisoning the
    `Parse Error` grep that rung 2 uses as the project's compile check — and its real cost was
    that CI's boot rung had to read only the last line of its log instead of grepping it, so a
    live defect had bought itself a permanently weakened gate. Fixed in WP-14:
    `Director._exit_tree()` drains its own loader thread, because `--doctool` confirms there is
    no `load_threaded_cancel` and `load_threaded_get()` blocks (measured, 118-197ms, paid once
    on the way out). CI's rung 3 now greps the whole log.

    **THIS GOTCHA ALSO USED TO GIVE THE WRONG REASON FOR THE BOOT RUNG'S FRAME COUNT, and that
    part was stale rather than fixed.** It said 120 rather than 30 because "the area load is
    threaded and 30 frames does not finish it". Since WP-12 the boot stops at the MAIN MENU and
    loads no area at all — gotcha 31 — so the boot rung was never racing a load, and 30 frames
    was measured as producing a byte-identical log to 120 (29 lines, same content, both
    `0 warnings, 0 errors`). **The local boot rung is `--quit-after 30`.** CI keeps 300 for the
    reason that does apply: a shared runner is slower, a headless frame costs milliseconds, and
    a rung that quits before the boot finishes would report clean about work it never did.
14. **`x if c else [] as Array[StringName]` is a RUNTIME cast failure.** The empty literal is
    a plain `Array`, the ternary takes its type from it, and the assignment throws every time
    the condition is false. It compiles, the boot run is clean, and the test suite still
    reports every assertion passing — the only trace is a `SCRIPT ERROR` line in the output.
    Declare the typed local, then assign inside an `if`.
15. **No assertion can press a key.** `TestCase.run()` is synchronous, so an input event never
    reaches the frame that would deliver it. An input path is proved by a TEMPORARY probe
    added to `dev_capture.gd`, run windowed with real `InputEventAction`s, read in the log,
    and then removed. WP-03's probe is quoted verbatim in `DEVLOG.md`; copy its shape.
16. **A FREED object compares EQUAL to `null` in Godot 4.** So `if thing != null` does NOT
    fire for a dangling reference, and `a != b` against one reports "unchanged". Only
    `is_instance_valid()` tells the truth. Worse, a freed instance cannot even be PASSED to a
    typed parameter — the argument type check itself fails with "previously freed" — so a
    dangling reference must never cross a call boundary; read the field in place. This kept a
    prompt for an unloaded area on screen through three packages.
17. **Check a name against the API dump before using it, EVERY time — static functions
    included.** `Resource` declares `resource_name` with the getter `get_name`, and a GDScript
    is a Resource, so `DictRead.get_name(...)` compiled and then dispatched to the native
    zero-argument method at runtime. Third time this project has been bitten by a native-name
    collision, after `Area3D.priority` and `class_name Container`. Regenerate with
    `--headless --doctool <dir>` and grep it.
18. **A navmesh bake that finds nothing takes NO TIME and reports SUCCESS.** `bake_navigation_mesh`
    on a region whose geometry mode does not actually reach the terrain produces zero polygons,
    logs nothing, and every NPC then concludes it has already arrived, everywhere. Always report
    `navigation_mesh.get_polygon_count()` and treat zero as an error. Godot's default
    `SOURCE_GEOMETRY_ROOT_NODE_CHILDREN` parses the children of the `NavigationRegion3D` itself,
    which in this project's area layout has none — the terrain is a sibling, so the areas use
    `SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN` with the group `navmesh_source`.
19. **`agent_max_climb` describes an abstraction the character controller does not implement.**
    The bake will bridge a knee-high step; `CharacterBody3D.move_and_slide()` has no step-up at
    all, so the body walks into the riser and stops while the agent reports "not finished"
    forever. Keep the climb limit below anything the body cannot manage. Related: do not ask the
    navigation map anything before it has synchronised — an unsynchronised map answers
    "unreachable" to everything, and acting on that answer strands an agent at the origin.
20. **Under `--headless` the audio driver is `Dummy`, and every `play()` against it LEAKS.**
    The AudioServer releases a stopped playback on the next mix and headless quits before there
    is one, so each `play()` shows up as a leaked ObjectDB instance along with its stream.
    Stopping the player and nulling its stream in `_exit_tree` does NOT help â the server owns
    the playback. Anything that starts a sound gates on `AmbienceBed.is_audible()`, which reads
    `AudioServer.get_driver_name()`: measured as `Dummy` headless, `WASAPI` windowed.
21. **An asynchronous system needs a PERSISTENCE test, not just a delay before you ask it.**
    `NavigationAgent3D` recomputes its path over frames, so the frame after a target moves it
    answers "unreachable" to a question it has not finished thinking about. WP-06 added a delay
    before the first question and it was still wrong â the keeper reported "cannot reach" in
    windowed runs and never in headless ones, because a WANDER activity re-targets every few
    seconds and only real-framerate timing landed inside the window. The answer must now hold
    for thirty consecutive physics frames, and a new target clears the evidence. Anything asked
    of an async subsystem should be treated the same way.
22. **"0 warnings, 0 errors" DOES NOT MEAN THE SCRIPTS COMPILED.** `Log` counts its own
    `Log.warn` and `Log.error` calls; an engine-level `Parse Error` is neither, so a file that
    fails to load prints a `SCRIPT ERROR` on stderr and the boot rung still reports a clean
    session. `dev_capture.gd` was dead for a whole package this way — the WP-13 merge added
    `await _settled()` without the function, and F12, `--shot`, `--time` and `--weather` were all
    broken while every rung stayed green. **Rung 2, `--headless --import`, is the compile check.**
    Grep its output for `SCRIPT ERROR` and `Parse Error` and require zero; do not read only the
    last line of rung 3.
23. **A GATE THAT NEVER FAILS HAS NEVER BEEN TESTED.** Every checker added since T1.2 is proved
    by planting a violation, watching it exit 1, removing it, and watching it exit 0 — both
    quoted in `DEVLOG.md`. This costs two minutes and is the only thing separating a gate from a
    reassuring printout. `tools/check_boundary.gd` also gets it wrong in a way no failure can
    show: it reads text, so a computed id or a name that exists in neither `data/` nor
    `scenes/areas/` passes silently. Its header lists what it cannot see, and that list is part
    of the gate.

24. **A GDScript RUNTIME ERROR ABORTS ONLY THE INNERMOST FRAME, so a crashing test passed for
    the life of the project.** Probed: a null dereference three frames deep printed its
    `SCRIPT ERROR`, and both the calling function and `_ready()` above it ran to completion. So
    the runner sees a case that returned normally, and a completion sentinel at the end of
    `run()` cannot work either — it is reached. T1.3 needed TWO mechanisms, and the second was
    added because the first was measured and found wanting: a declared PLAN catches every crash
    that swallows an assertion, but a crash planted in a leaf helper with nothing asserted after
    it still reported `2/2` and exit 0. `tests/framework/error_watch.gd` — an `OS.add_logger`
    `Logger` counting `ERROR_TYPE_SCRIPT` — is the only thing in the engine that sees that one.
    Related and useful: `get_tree().quit(1)` followed later by `quit(0)` exits 0, last call wins,
    which is why the runner ARMS its exit code to failure on its first line.


25. **GITHUB RUNS EVERY `run:` BLOCK AS `bash -e {0}`, so `set -uo pipefail` inside a step does
    NOT turn errexit off.** T1.4's first red run reported nothing but `Process completed with exit
    code 1`: the step died on the failing `godot` line, before the line that prints WHICH
    assertion failed. The uploaded artefact had the answer and the step did not, which is a gate
    that fails without saying why — half a gate. Any rung that must outlive its own command's
    failure captures the status with `|| status=$?`, which is exempt from errexit, and judges it
    afterwards. Related, and it wasted an hour on its own: **verifying a shell fragment
    interactively with `( ... )` inside an `&&` chain also silently disables `set -e`** — the same
    fragment reported exit 0 on a deliberately failing suite inline and exit 1 as a script file.
    Test a workflow fragment as a FILE, never inline.

26. **`gh`'s run listing lags, and believing it produces a confident wrong diagnosis.**
    `actions/runs` reported `total_count: 0` for four minutes after a push whose run had already
    been created AND completed. On that evidence CI looked disabled, which cost a needless
    visibility change to rule out a private-repo minutes limit — the runs that had already passed
    were pushed while the repo was private. Push-event delivery on this repo ran up to **25
    minutes** behind at times. Check `run_started_at` against the push time before concluding
    anything is broken, and prefer `gh workflow run` for a prompt answer: `workflow_dispatch` is a
    trigger on the ladder precisely because a gate with one way in has a single point of failure.
    A manual run gets its own `concurrency` group keyed on its run id, because a dispatch was
    once cancelled by the very push it was verifying and a cancelled run reports neither pass nor
    fail.

27. **AN EXPORT DROPS AN INSTANCE OVERRIDE THAT HAS NO `[editable]` MARKER, and running from
    source cannot see it.** A hand-authored `.tscn` that sets a property on a node INSIDE an
    instanced scene needs `[editable path="<the instance>"]` at the foot of the file. Without it
    the text loader applies the override happily; the exporter converts `.tscn` to binary `.scn`
    and the conversion silently discards it, so the prefab reverts to its defaults in the shipped
    build ONLY. The demo's NPC lost its `object_id`, its prompt and its conversation exactly this
    way, and every rung, both CI jobs and 930 assertions were green throughout. Stale `index=`
    values look like the culprit and are not — correcting them changed nothing.
    `tools/check_content.gd` gates it now. Related, from the same package:
    **`export_filter="all_resources"` is the only setting that ships directory-scanned content**
    (`"scenes"` ships zero of it), **`include_filter="*.tres"` is the plausible wrong fix** because
    the include filter is for NON-resource files, and **a debug export is required to verify
    content at all**, because the readout is behind `OS.is_debug_build()`. An export template must
    be installed first, and it comes only in a 1.28 GB `.tpz`.


28. **A SPRITE DRAWN FROM THE WRONG CELL STILL LOOKS LIKE A CHARACTER.** This is gotcha 2 in its
    sharpest form: a day/night system that lights nothing is at least obviously wrong on screen,
    but a person drawn from the wrong row is still a person — upright, lit, facing *some*
    direction — so a capture of it cannot be JUDGED, it has to be READ. T2.1's second placeholder
    sheet therefore labels every cell: `column + 1` bright pips down the left edge, `frame + 1`
    along the foot, and a different body tint per animation block. That is what turned
    `frame=19/24` from a number to be taken on trust into a checkable prediction — four left pips,
    two foot pips, orange body, `(1*3 + 1) * 4 + 3 = 19`. Any future visual seam whose failure mode
    is "plausible but wrong" needs the same treatment; a screenshot of something that merely looks
    fine is not evidence.

29. **A `Theme` HAS NO VARIABLES, so a colour put in a type variation is a colour duplicated.**
    Godot's `Theme` stores each item per type, and there is no reference between them — so the
    natural-looking design, where `TitleText` carries both its `font_size` and its `font_color`,
    means the accent colour is written into as many variations as use it and "one Theme edit
    restyles every screen" is false the moment there are two. The split T2.1 settled on: variations
    carry ONLY sizes, and the colours and insets live once each under `UiPalette` / `UiMetrics`
    which the screens read by name. Related, and it is what makes this work at all: the project
    theme set as `gui/theme/custom` resolves from ANY Control in the tree, so a screen never has to
    be handed it — but a theme item that exists in the file and does not resolve from a node is not
    wired, which is the same failure shape as an unwired `@export`, and it is worth one assertion.

30. **`[importer_defaults]` IS UNDOCUMENTED AND ABSENT FROM `--doctool`.** Godot's per-importer
    project defaults are an editor-managed `project.godot` section, so the rule this project runs
    on — check every name against the API dump before using it — cannot be satisfied for it, and
    hand-authoring an undocumented format is exactly the change that looks applied and does
    nothing. T2.1 stopped rather than guess. **ITS CONCLUSION WAS WRONG AND T3.2 REVERSED IT — see
    gotcha 39.** The first half stands: there is still no dump to check. What was missing was that
    a MEASUREMENT is available and is stronger evidence than a dump, which is non-negotiable #1.
    The latent hazard it named is closed: the section now sets `detect_3d/compress_to = 0` and so
    does every committed `.import`, so a re-import can no longer put VRAM block artefacts through
    pixel art. Keep this entry for its general lesson, which is not about textures: **"I cannot
    check this the usual way" is a reason to find another check, not a reason to stop.**

31. **NO ORDINARY RUN EVER ENTERS AN AREA, so most of the ladder is blind to area content.**
    `--headless --quit-after 30` boots to the MAIN MENU and reports `0 warnings, 0 errors`
    without loading anything — it cannot see a wrong `area_id`, an empty navmesh bake, an NPC with
    no schedule or an unlit interior. Neither can a bare `--shot`: the PNG is the title screen,
    which is what the first capture in T2.2 turned out to be. **`--new-game` is what starts a
    game**, `--goto=<area>` travels to a different one, and the area load is threaded so the
    shutter needs `--shot-frame=70` with `--quit-after 90` rather than the old bare 55. This is
    gotcha 22's family, one level up: not a rung that cannot see an error, but a rung reporting
    clean about work it never did. Related and cheap to trip over: `--stand-by=` takes a NODE
    NAME, not an `object_id`, and a propless new area at 18:40 renders near-black, which looks
    exactly like a lighting bug — capture a new area at midday first.

32. **STAGING THAT RUNS BEFORE `--new-game` HAS ITS STATE THROWN AWAY.** `--new-game` CLEARS EVERY
    FLAG, so `--flag=met/x:true` applied during argument parsing is gone by the time the area
    lands — and the run still reports `0 warnings, 0 errors`, because nothing failed. The first
    WP-08 capture was a journal with no quest in it for exactly that reason, and the only trace is
    the ORDER of the log lines: `--flag` before `Quest tracker ready`, and no `started` line after
    it. `--flag` now waits for the area the way `--open-menu` already did. This is gotcha 31 one
    step further in: not a rung blind to an error, and not a rung reporting clean about work it
    never did, but staging that ran before the thing it was staging for. Any future `--` flag that
    poses state a new game resets needs the same wait, and `dev_stage.gd`'s header says so.


33. **`Array[StringName].sort()` DOES NOT SORT ALPHABETICALLY.** It orders by the StringName's
    internal handle, so the result is stable within a run and arbitrary between them. It compiles,
    it looks like a sort, and `Equipment.equipped_ids()` returned two ids in the wrong order with a
    single failing assertion as the only trace. `Inventory.ids()` had already hit this and sorts
    through `String` with a `sort_custom`, which is the only reason this cost a minute rather than
    an hour — a comment saying WHY a line is not the obvious one is worth more than the line.
    Anything sorting `StringName`s goes through `String`. **And a note in three files is not a fix
    in all of them: `QuestTracker.ids_in_state` was still calling `out.sort()` five phases later,
    with a doc comment promising a stable order. See gotcha 79.**

34. **A UI THAT REDRAWS ONLY ON ITS OWN INPUT IS SILENTLY WRONG THE MOMENT SOMETHING ELSE WRITES.**
    `InventoryScreen` refreshed on `inventory_changed`, so pressing a row to equip redrew correctly
    and equipping from anywhere else did not — and the first WP-09 capture came back showing a held
    lantern drawn as merely carried while the log said `player equipped`. Nothing failed, because
    the screen was still right about the bag. A press is never the only writer: staging equips from
    the command line, `_revalidate` stows on its own, and a save restores. Subscribe to the fact,
    not to the gesture. This is gotcha 2's family in the UI layer, and only a capture sees it.

35. **TWO STAGING FLAGS THAT BOTH WAIT FOR "THE AREA" LEAVE THAT WAIT ON THE SAME FRAME, AND
    RACE.** `--goto` and `--open-menu` each begin with `_wait_for_area()`, so they resume
    together: if the menu opened first, the travel `--goto` was about to request unwound it —
    `ScreenKeys` unwinds the stack on every `area_change_requested` — and the capture came back
    showing nothing, with `0 warnings, 0 errors` and every rung green. This is gotcha 32's family
    one step further out: not staging that ran before the thing it staged for, but two pieces of
    staging that were both correct and were ordered by chance. A LONGER FIXED WAIT ONLY MOVES THE
    RACE. The fix is gotcha 21's shape — `dev_stage._settle_stable(20)` requires twenty
    CONSECUTIVE settled frames and resets its count the moment a transition begins, so it cannot
    be satisfied early no matter which flag resumed first. Any future staging flag that puts
    something on screen uses it, and `dev_stage.gd`'s header says so.

36. **`String.hash()` MIXES ITS LOW BITS WEAKLY, so `hash() % N` CLUSTERS SHORT SIMILAR NAMES.**
    Measured: `"grass"` hashes to 260508453 and `"stone"` to 274826446 — wildly different numbers
    whose last three digits are 453 and 446 — and `"wood"` and `"sand"` differ by 159027 in a
    number of 2.09 billion. WP-09b derives a footstep's timbre from the surface's name, so those
    two surfaces produced brightnesses 0.006 apart and **sounded identical**, with every rung
    green, a `playing=true` in the log and an inequality assertion passing. Adding a second derived
    axis did not help — the salted hashes collided the same way. The fix is an avalanche before the
    modulus (one multiply, two shifts), which moves the pair to 796 and 572. Two lessons, and the
    second is the general one: anything deriving a VALUE from a Godot string hash must mix it
    first, and **a regression assertion about a perceptible difference must demand a MARGIN**,
    because mere inequality is exactly what the broken version passed. Gotcha 2 with a speaker on
    it: a step that plays is not a step that follows.


37. **A BASE-CLASS `static var` IS ONE STORAGE SHARED BY EVERY SUBCLASS.** Probed under 4.7.2 with
    two throwaway subclasses bumping a counter declared on their base: `A.shared=3 B.shared=3
    Base.shared=3`. This is the opposite of the per-class statics most languages give you, and it
    is what made the obvious shape of T3.1 — `ItemDb extends ContentDb`, with `_by_id`, `_loaded`
    and `content_dir` on the base — silently catastrophic: five registries would have shared ONE
    cache and ONE content root, so `Fixtures.activate()` would have pointed all five at a single
    folder and four catalogues would have come back empty. Every accessor would still have been
    typed and the class diagram would still have looked right. The shared part of five static
    classes must therefore be a FUNCTION taking the caller's state, never inherited state. Three
    related facts from the same probe, each of which the design depends on: a `class_name` passed
    as a `Script` works with `is_instance_of()`; `Script.get_global_name()` returns the class name;
    and a `Dictionary[StringName, X]` handed to an untyped `Dictionary` parameter keeps its value
    type and is filled BY REFERENCE — which is the whole mechanism keeping every registry accessor
    typed with one shared scan. Related and cheaper to trip over: **`ResourceLoader` caches by
    path**, so re-saving a different resource over a path already loaded in this run hands the next
    scan the FIRST one. A new file name, not a second write.

38. **A MISSPELLED PROPERTY NAME IN A HAND-AUTHORED `.tres` IS SILENTLY DISCARDED.** Measured under
    4.7.2: `conditio_flag = &"bag/player/item/rose_petal"` in a quest step loaded with **no engine
    error, no warning and no `Invalid` line anywhere** — the resource simply came back with that
    field at its default. This project hand-authors every `.tres`, so it is exactly the slip the
    editor would have made impossible, and it is `[editable]`'s family (gotcha 27): a property the
    loader drops looks identical to a property nobody set. The only thing that saw it was
    `problems()` on the resource itself, and only because a non-ALWAYS test with no flag is a
    declared problem — a misspelt `condition_value` would have become 0 in silence, which is why
    T3.3's content gate refuses a count below one. **Every field a `.tres` sets that MATTERS must be
    reachable by `problems()` or by a checker**, or authoring it is a suggestion.


39. **AN UNDOCUMENTED ENGINE FORMAT CAN BE SETTLED BY MEASUREMENT, AND `[importer_defaults]` WAS.**
    Gotcha 30 stopped T2.1 for a good reason and reached the wrong conclusion, and this project's
    own non-negotiable #1 is why: *nothing is done until the engine has run it* is not merely a
    completion rule, it is an EVIDENCE rule, and it outranks the API dump. Measured under 4.7.2 in
    four steps — a throwaway texture copied into a scratch folder under `res://`, imported with stock
    defaults; the section written into `project.godot`; the generated `.import` DELETED; and
    `--headless --import` run again. It came back carrying `detect_3d/compress_to=0` and
    `mipmaps/generate=true`, against the stock `1` and `false`. So: the section works, the key is
    the **importer's** name (`texture`, not a file extension), the value is a **Dictionary of
    param paths**, it applies to a FRESH import only — an existing `.import` keeps its own params,
    which is why all eight committed ones had to be edited too — and
    `ProjectSettings.get_setting("importer_defaults/texture")` reads it back at runtime as a
    Dictionary (`type=27`), which is what makes it assertable rather than merely written. Two
    things generalise past textures. **A control value is what turns a probe into evidence:** only
    one value mattered, but a second one whose stock default was the OPPOSITE of what was written
    is what proved the section applied at all rather than the value happening to already be right.
    And **the stock defaults were measured, not assumed** — three of the four settings
    `ART_CONTRACT.md` had recommended turned out to be Godot's own defaults, so writing them down
    would have been ceremony that later reads as a decision.

40. **TWO CLASSES CAN EXPORT THE SAME PROPERTY NAME, SO A TEXT SCAN OF A SCENE FILE IS NOT A SCAN
    OF A NODE.** `HD2DCameraRig` and `WeatherVisuals` both export `height_offset`, and they mean
    entirely different things. An assertion that an area authors its own camera framing therefore
    PASSED with the framing deleted, because the courtyard's weather node carries a
    `height_offset = 5.0` line and the scan was looking at whole files. Every rung green, and the
    only reason it was caught is that the gate was proved red before being believed (gotcha 23) —
    which is the entire argument for planting the real violation, since the gate was the thing
    that was broken. Anything reading a `.tscn` as text must resolve the OWNING NODE first: walk
    `[node ...]` blocks, buffer each one, and match on the `script` ExtResource resolved to a path
    — buffering rather than switching on the `script` line as it goes by, because a property
    authored above `script` is legal `.tscn`. This is gotcha 17's family (`Area3D.priority`,
    `class_name Container`, `DictRead.get_name`, `ItemDb.reload`) moved out of GDScript and into
    scene text, and it is the sixth name collision this project has paid for.

41. **A DEFECT CAN BUY ITSELF A WEAKENED GATE, AND THAT COSTS MORE THAN THE DEFECT.** The engine
    printing false `Parse Error` lines on a mid-load shutdown (gotcha 13) was, on its own, cosmetic
    noise after a run had already reported cleanly. Its real price was paid one level up: CI's boot
    rung was written to grep only the LAST LINE of its log, with a comment explaining that a
    whole-log grep "would be a flake generator" — so the project's single most load-bearing check,
    the `Parse Error` grep that gotcha 22 exists to insist on, was switched off on that rung, on
    purpose, correctly, for as long as the defect lived. **Nobody weakens a gate for no reason;
    they weaken it because something real is making it lie.** So a gate carrying a comment that
    explains why it checks less than it could is a defect report in disguise, and the fix is
    upstream of the gate every time. WP-14 fixed the shutdown and switched the grep back on. When
    you find a scope-limiting comment on a check, read it as a lead rather than as settled design.

42. **AN ASSERTION THAT PASSES CAN STILL BE ASSERTING THE WRONG THING, AND ONLY PLANTING FINDS
    OUT.** WP-14's smoke test carried a comment claiming its save/load block asserted the
    save-participant ORDER — the invariant T3.3 established, that a derived count must be
    republished on `game_loaded` because `Flags._apply_save` wipes the store from underneath it.
    Deleting that subscription, which is exactly how the invariant would really be lost, left the
    assertion GREEN: the test's own wipe happened to let `_apply_save` publish for itself, so the
    ordering never came into play. The assertion was true, the comment above it was not, and no
    failure could ever have shown the difference. This is T3.2's framing gate (gotcha 40) in a
    second costume, and the same rule closes both: **plant the real violation even when the
    assertion looks obvious — especially then, because the thing being tested is the test.**

43. **AN ASSERTION THAT SCANS SOURCE FOR A GUARD WILL READ THE GUARD'S OWN DOCUMENTATION BACK TO
    ITSELF, AND WILL BE SATISFIED BY THE WRONG COPY.** WP-14b had to assert that the debug console
    and the performance overlay are unreachable in a release build. `OS.is_debug_build()` is true
    in every context the suite can run in — a test cannot exercise the false branch — so the
    assertable form is a text scan for the guard, the same mechanism `check_boundary.gd` already
    uses for `src/systems/debug/`. **The first version was wrong in two independent ways, and
    planting found both.** One: `screen_keys.gd` EXPLAINS its gate in a `##` comment, so a
    whole-file scan passed while reading its own explanation with the binding deleted — the fix is
    the comment rule every other text tool in this project already applies. Two, and it is the
    sharper half: `perf_overlay.gd` carried the identical fragment `if not OS.is_debug_build():`
    in BOTH `_ready` and `_input`, so deleting the real one left the assertion green on the
    decorative one. **That fix belonged in the CODE, not in the test.** `_input` and `toggle()`
    now ask `_label == null`, which is the same question and a stricter one — a release build
    leaves `_ready` early and never builds the label — so one place decides and the anchor is
    unique. Two rules generalise: **a scan-for-a-guard assertion must name a fragment that appears
    exactly once in its file**, and **a guard written twice is a guard that cannot be asserted**,
    which is a design smell before it is a testing problem. Gotchas 40 and 42's family, third
    costume, and the third time planting has caught the test rather than the code.


44. **A BLOCK THAT GATES ON A BROADER QUESTION THAN IT ASSERTS IS GREEN EVERYWHERE EXCEPT IN A
    CONSUMER'S HANDS.** `smoke_test.gd` asked *"does this checkout have any content?"* and then
    asserted about **areas**. Both extremes are fine — the full demo has areas, a stripped template
    has neither — so every run this project ever made was green. The failure lives only in the gap:
    a real game that authored one item before its first area, which is exactly the window
    `NEW_GAME.md` walks an author through while promising the ladder stays green. It was found by
    PERFORMING `docs/UPGRADING.md` against a real fork, and it could not have been found any other
    way, because a suite cannot run in a state neither of this repository's two checkouts is ever
    in. Two rules generalise. **A block must gate on the same question it asserts** —
    `Fixtures.area_ids()` already existed and is that question; the broader `has_demo_content()`
    was reached for because it was the one that was already being used. And **a template's
    intermediate states are a place tests never look**: the full demo and the stripped template are
    the two states this repo has, and every state a consuming game passes through lies between
    them. Gotchas 40, 42 and 43's family, fourth costume, and the first of them that no plant in
    this repository would have caught — the fork had to exist.

45. **A GATE THAT MATCHES SUBSTRINGS IS GREEN IN BOTH OF THIS REPOSITORY'S STATES AND RED ONLY IN A
    CONSUMER'S HANDS.** `check_boundary.gd` asked whether a line CONTAINS a content id. T4.2
    authored an item called `pear` — nothing exotic — and the gate failed on
    `tests/unit/menus_test.gd`'s *"and Load has appeared under it"*, because **`appeared` contains
    `pear`**. The full demo is green because its own ids happen not to collide; the stripped
    template is green because it has no ids at all; the failure lives only in the gap, and it needs
    an id this repository does not have. Gotcha 44's family, fifth costume, and **the second one
    that no plant here could have caught** — the content had to be authored. Three rules
    generalise. **A text gate that matches an identifier matches it as a WHOLE WORD**, or every
    short id (`pear`/`appeared`, `ore`/`before`, `art`/`start`) is a build failure a consuming game
    cannot fix. **A gate's failure message must not tell the reader whose bug it is** — the gate
    table in `AUTHORING.md` said a `check_boundary` hit "is a bug in the *engine*, not in your
    content", which sent an author to file a bug rather than rename an item. And **an engine test's
    throwaway literals are content ids waiting to happen**: `borrowed["pear"] = 1` was an arbitrary
    dictionary key that became a boundary violation the day a game used the word, so such literals
    come from the reserved `fixture_` namespace, which is immune BY CONSTRUCTION because an id
    sitting after an underscore is not a whole word.

46. **A RULE WRITTEN IN A FILE'S OWN HEADER CAN STILL BE UNFOLLOWED BY A CALL SITE IN THAT SAME
    FILE.** `dev_stage.gd` states gotcha 35's rule — staging that puts something on screen uses
    `_settle_stable`, not `_wait_for_area` alone — and `--stand-by` did not, for six packages.
    `--goto=<new area> --stand-by=<object in it>` therefore resolved the node name in the
    **departure** area, every time, deterministically rather than as a race, so no object in an
    authored area could be photographed at all. Every rung stayed green because the flag is only
    used by hand. Two rules. **A written rule with more than one call site wants an assertion, not
    a paragraph** — gotcha 41's family: a rule nothing checks is a comment. And **an assertion that
    a function contains a call must be scoped to that FUNCTION when the fragment repeats**:
    `_settle_stable(SETTLE_FRAMES)` appears three times in that file, so a whole-file scan is
    satisfied by any one of them and would have stayed green with the broken call site deleted.
    That is gotcha 43's rule met by narrowing the TEXT rather than the fragment, and the plant
    proved it — deleting the one call failed while the other two remained.


47. **A GAME FLAG WITHOUT `--` IS SWALLOWED BY GODOT, AND THE RUN THAT PROVES NOTHING LOOKS
    EXACTLY LIKE THE RUN THAT PASSED.** `--headless --new-game` does not start a new game. Godot
    keeps the argument for itself, `dev_stage.gd` never sees it, the run stops at the main menu
    having done nothing, and it ends `0 warnings, 0 errors` — green, and completely empty.
    Everything after `--` is the GAME's argument list: `"$G" --headless --quit-after 180 --
    --new-game` is the form that works. **`--quit-after` counts FRAMES, not seconds**, and gives
    the identical false green a second way: below about 120 the session ends at the menu before
    the flag has fired, so the same silent nothing appears for a completely different reason.
    `docs/NEW_GAME.md` section 6 asserted the behaviour of an unset first area for two packages
    without giving the command, so the natural guess was the one that verifies nothing. **A
    document that states an output must state the command that produced it**, which is the same
    rule as non-negotiable #1 aimed at prose.

48. **A MISSING PRUNE PREFIX SHIPPED SILENTLY, BECAUSE NO GATE READ `localization/` AT ALL.**
    **CLOSED BY T5.4**, and the closing is at the end of the entry — the diagnosis below is kept
    because it is the reasoning, and because half of it is still true.
    `check_boundary.gd` guards `src/`, `tests/framework/` and `tests/unit/` — the places where a
    demo id would be a LEAK. A demo row in `localization/strings.csv` is not a leak and not an
    error: it is a translation for content that was deleted, so nothing loads it, nothing resolves
    it and nothing complains. `check_strings.gd` anchors at sinks and declarations, so an orphan
    row is invisible to it too. The consequence is that `NEW_GAME.md`'s prune list is the ONLY
    thing standing between a fork and shipping this template's demo strings, and a list is exactly
    the artefact that rots: written at T1.2, it never learned about `quest.` when WP-08 added
    quests, so a fork shipped *"The Keeper's Errand"* and *"three rose petals"* inside its own game
    with all four checkers and 1,539 assertions green. **A checklist item with no gate behind it
    needs an expiry story**, and the story written here — "a grep the document tells the author to
    run" — was not one, because it rested on the author choosing to run it.
    **T5.4 found the expiry story the paragraph above says a tool cannot have, by asking the
    opposite question.** A tool that lists which prefixes are engine does rot; a tool that asks
    whether a ROW NAMES CONTENT THAT EXISTS derives everything and cannot. `check_boundary.gd`
    already computed the demo-name set from `data/` and `scenes/areas/`, so the orphan check was
    forty lines: a `quest.keepers_errand.*` row with no quest resource behind it is now **exit 1**,
    in the template and in every game built on it. Presence is still only REPORTED — 218 rows, 51
    in a content namespace — because the template legitimately ships its own demo rows and a gate
    switched off where it lives is decoration. **The stripped CI job now runs `NEW_GAME.md`'s
    `awk` verbatim and then this gate**, so the prune list is itself checked, by something derived
    from a different place. Two namespaces are still ungated and said so in the header: `object.`
    and `action.` keys are authored freely and match no id, so nothing can derive them.


49. **A SCRIPT THAT DOES NOT PARSE IS NOT `null`, SO THE TEST RUNNER SKIPPED A LISTED CASE IN
    SILENCE FOR THE LIFE OF THE SUITE.** `load()` on a `.gd` file with a parse error hands back a
    `GDScript` that exists, is not null, and cannot be instantiated. `_run_case` checked only for
    null, so it walked into `script.new()` — and **the failure of that call is a runtime error,
    which gotcha 24 already established aborts only the innermost frame.** So `_run_case` itself
    aborted, the `does not extend TestCase` failure two lines below was never reached, the `for`
    loop in `_ready` moved on to the next case, and the suite reported
    `=== 1608 passed, 0 failed, 0 skipped ===` and **exit 0** with an entire case never run.
    Measured, twice: the identical plant after the fix gives exit 1 and names the file. The
    sharpest part is that `tests/framework/error_watch.gd` **had counted the error the whole
    time** — `_no_script_errors` is read per case from inside `_run_case`, after `run()` returns,
    so an error raised on the way IN is tallied by the watch and read by nobody. T1.3 built two
    mechanisms because the first was measurably not enough (gotcha 24); this is the third hole in
    the same wall, and the one neither mechanism was positioned to see. Three rules generalise.
    **A guard that only checks `null` has not checked that a resource is USABLE** — `load()` has
    more than two outcomes, and `can_instantiate()` is the question actually being asked.
    **Gotcha 24's own reasoning applies to the RUNNER, not just to the cases** — the code that
    judges whether a frame aborted is written in the same language and aborts the same way, which
    is why the run-level backstop had to be a separate check rather than a better per-case one.
    And **a mechanism that sees a failure is worth nothing until something asks it**: the watch,
    the plan and the manifest were all correct and all silent here. Found by performing
    `docs/TESTING.md` — whose rule 5 *named* this failure shape in prose, as the thing
    `_manifest_is_complete` was analogous to, while nothing in the runner covered it. **The fifth
    document walked, and the fifth to find a defect; the third of the five where the defect was
    in the TEMPLATE rather than the prose.**


50. **A STAGING FLAG THAT GOES THROUGH A PERSISTED SETTING BREAKS THE NEXT RUN OF SOMETHING ELSE.**
    `--locale=<code>` is routed through `Settings.set_value` on purpose — a flag that set
    `TranslationServer` directly would photograph a path no player can take — and `set_value`
    calls `save()`, because a language choice should survive a relaunch. So one capture at
    `--locale=en_XA` left the setting on disk, and the NEXT suite run failed four assertions in
    `items_test` and `screens_test`: `expected fixture.fixture_stack.name x3, got
    [~~fixture.fixture_stack.name x3~~]`. Four failures, in two files the package had never
    touched, caused by a screenshot taken ten minutes earlier — and the suite had been green
    immediately before, so the obvious reading was that the last edit broke it. **A suite whose
    result depends on the developer's saved preferences is not deterministic**, and the fix is the
    one the runner already applied to time: `test_runner.gd` pins `Clock.paused` because a clock
    that advances mid-assertion makes time assertions flaky, and it now pins the locale for the
    identical reason one step further out. The pin reads `internationalization/locale/fallback`
    from `ProjectSettings` rather than hard-coding English, or a consuming game whose default is
    another language would inherit the flakiness the pin exists to remove. Two rules generalise.
    **Anything global that a dev flag can persist must be pinned by the harness, not trusted to be
    put back** — the flag was correct, the capture was correct, and the failure was still real.
    And **a failure in a file you did not touch is evidence about the ENVIRONMENT, not about your
    change**; the ten minutes spent suspecting the edit were spent because that reflex is backwards.

51. **`update_from_velocity` FROM A PROBE MEASURES NOTHING, AND `run` IS A TOGGLE.** Two facts,
    one probe, and both cost a measurement that looked like data. Driving
    `CharacterVisual.update_from_velocity` directly from `dev_probes.gd` reported the drawn cell
    frozen at 0 through twelve frames at two different speeds — which reads as "the walk cycle is
    broken" and is actually **`PlayerController._physics_process` overwriting the visual from its
    own velocity every physics frame**, that velocity being zero because nothing was pressing
    anything. A visual driven by a controller can only be measured THROUGH the controller: press
    the real action with `Input.action_press` and let the body move. The second fact bit
    immediately afterwards: `run` is a TOGGLE (`run_is_toggle`, polled through
    `is_action_just_pressed`), so `Input.action_press(Actions.RUN)` toggles it rather than holding
    it — the "running" trial covered **0.75m against walking's 2.30m**, having toggled off and
    then walked into the dais, which is a number that looks like a finding and is an artefact
    twice over. `sneak` is a hold and is what a speed comparison should use. Corrected, the
    measurement is clean and matches the formula: `4.04m / 8 cell changes` walking against
    `1.50m / 4` sneaking over 60 frames, against
    `walk_fps 8.0 * clampf(speed / 3.2, 0.35, 2.0)`. **A probe that reads a value someone else
    writes every frame is reading their answer, not yours.**


52. **`--shot-frame` AIMS AT A FRAME NUMBER, AND THE SAME FRAME NUMBER IS A DIFFERENT MOMENT IN
    EVERY RUN.** T5.2 needed three captures of one character in three gaits, and spent an hour
    getting them because a frame is not a point in the game's story. **Measured across runs of the
    identical command: the player was grounded in its area at process frame 17 in one run and at
    frame 115 in another** — the area load is threaded, so everything downstream of it slides by
    a hundred frames. Three separate failure modes came out of that one fact. A capture aimed
    early enough to catch a gait in one run **landed before the area existed in the next**, and a
    PNG of empty sky with a working HUD looks exactly like a rendering bug rather than a mis-timed
    shutter. A capture aimed late enough to be safe caught a character that had **walked clean out
    of the area** — x went 0 to -16.8 by frame 115 at run speed, and the camera followed it into
    nothing. And an oscillation added to keep the character in frame introduced a **one-frame
    window where velocity is zero** between releasing one direction and pressing the other, in
    which the visual correctly reports IDLE — so a walk capture came back showing the idle block
    and the honest reading of it was "the feature does not work". Three rules. **A capture that
    must land on a game STATE needs the shutter driven by that state, not by a frame count** —
    aim at a window, verify from the log which state the run was actually in at that frame, and
    treat the number as a guess to be checked rather than a setting. **Ask the ASSET before
    blaming the renderer:** sampling the generated sheet's pixels settled in one command what four
    captures had left ambiguous, because a PNG on disk has no timing in it. And **a probe that
    starts before the area does measures nothing** — `_gait_parade` skipped the
    `while Director.current_area_id == &""` wait that every other probe in that file opens with,
    and duly reported the player falling from -0.30 to -20.54 with `is_on_floor()` false, which is
    gotcha 9 seen from a probe that arrived too early and reads as "the player falls through the
    world".


53. **THE `.godot` IMPORT CACHE IS GITIGNORED, SO SWITCHING BRANCHES LEAVES THE OTHER BRANCH'S
    ASSETS IMPORTED AND THE SUITE FAILS ON A MISMATCH THAT EXISTS IN NEITHER BRANCH.** Measured
    while recording T5.2's CI run: `git checkout` back to the previous branch, run rung 4, and
    `the default layout fits its sheet — expected 0, got 1`. Both branches were green in CI.
    Nothing was wrong with either. `assets/placeholder/character_placeholder.png` had been
    regenerated at 256x576 on one branch and the checkout correctly restored the 256x192 file — but
    the IMPORTED texture lives in `.godot/`, which is gitignored and therefore not part of what a
    checkout changes, so the layout resource from one branch was being validated against the
    imported texture of the other. **`--headless --import` after the checkout, and it is
    `1653 passed, 0 failed`.** This is the fresh-clone rule (`--headless --import` FIRST, because
    `class_name` globals live in that cache) with a second and less obvious consequence: the cache
    holds IMPORTED ASSETS as well as script globals, so it goes stale on a branch switch and not
    only on a clone. Two rules. **Re-import after any checkout that touches an asset or a
    `.import` file**, and treat a rung-4 failure immediately after a branch switch as a cache
    question before a code question. And **a failure that contradicts a green CI run on the same
    tree is evidence about the local environment**, not about the tree — the same reflex gotcha 50
    asks for, one layer down: there, a leftover setting; here, a leftover import.
54. **A UNIT TEST AT EACH END OF A SEAM PROVES NOTHING ABOUT THE WIRE BETWEEN THEM, AND TWO GREEN
    ASSERTIONS READ AS COVERAGE OF THE WHOLE PATH.** T5.2 shipped `MoveState.CLIMB` as an
    addressable animation block. `traversal_test.gd` asserted a climbing body reports
    `state == CLIMB`; `art_contract_test.gd` asserted `animation_for(CLIMB)` returns the climb
    row. Both passed. **CLIMB never reached the sprite at all** — `_physics_process` returns
    early while a climb owns the body, so the one line that hands the state to the visual was
    unreachable, and `climb_step` touched the visual only after resetting the state to IDLE. The
    exit criterion was ticked, 1,676 assertions were green, and `climb_row` was undrawable. The
    defect is invisible in the demo because the shipped sheet leaves `climb_row` at -1 and the
    fallback draws the walk block, so the first observer would have been the first game to draw
    a climb cycle. **The assertion that catches this class asserts the OUTPUT of the whole path,
    not the state at either end**: decode the block out of `sprite.frame` after driving a real
    climb, which fails with `expected 1, got 0` the moment the wire is cut. Ask of any seam:
    which assertion fails if the middle is deleted? If the answer is none, the middle is
    unverified however many assertions surround it. This is the same lesson as gotcha 22 (`0
    warnings, 0 errors` counts the game's own logging, not compile errors) and gotcha 24 (a
    GDScript runtime error aborts only the innermost frame) in a third place: **a green signal
    that was never wired to the thing it claims to describe.** Found by an audit that swept for
    declared-and-unread values rather than by any gate, because no gate looks for one.
55. **A RULE WITH NO GATE IS A RULE THAT IS ALREADY BEING BROKEN, AND YOU WILL NOT FIND OUT FROM
    A GREEN LADDER.** `ARCHITECTURE.md` has stated `core -> content -> systems -> gameplay -> ui,
    downward only` since Phase 0, gives the test in the next sentence — *could you delete the
    layer above and still compile?* — and nothing had ever run it. T5.4 wrote the four-line
    checker, expecting to confirm a clean tree because the package brief said the tree was clean.
    **First run: 55 upward references, exit 1.** Forty-two were the debug harness, which is the
    same exemption `check_boundary.gd` already grants for the same reason. Thirteen were real:
    `interaction_sensor.gd` sat in `systems/` and was typed on `Interactable`, which is
    `gameplay` — delete `gameplay/` and `systems/` does not compile, the document's own test,
    failed. The file was simply in the wrong layer: its second line says it *"lives as a child of
    the player"*, and a player component is not a game-agnostic service. Moved to
    `src/gameplay/interaction/` and the reference became legal with no exemption. **This is the
    same shape as `const FIRST_AREA := &"courtyard"` sitting in `core` before T1.2 — it passed
    eight verification rungs because no rule forbade it — with the roles reversed: here the rule
    existed and the enforcement did not.** The transferable form: for every invariant a document
    states, ask which command fails when it is violated. If the answer is none, the invariant is
    a wish, and the cost of discovering that grows with the tree. Writing the gate is cheap while
    the tree is nearly clean and expensive once it is not — and you do not know which you have
    until you run it.

56. **A TEXT SEARCH FOR A WIRE CAN STAY GREEN AFTER THE WIRE IS CUT, BECAUSE THE DECLARATION IT
    FINDS IS NOT THE CONNECTION.** T5.5 built `UiAccessibility`, wired it into `game_root.tscn`,
    and — mindful of gotcha 54 — added the assertion that gotcha 54 asks for: not just that the
    class works, but that the running game instances one. It read the `.tscn` as text and
    required the script path and `parent="UILayer"` to both appear. **Then the node was deleted
    as a plant and the suite stayed green: `1782 passed, 0 failed`, byte-identical.** Both halves
    were still in the file — a `[ext_resource]` line SURVIVES the removal of every node that used
    it, and eight other nodes carry that parent — so the assertion was really checking that the
    file still mentioned a script somewhere, which it always would. The fix was to stop reading
    the scene as prose: `PackedScene.get_state()` gives `SceneState`, where a script is a
    PROPERTY of a node and the node either exists or does not, and `get_node_path(i, true)`
    answers `./UILayer`. Replanted: `expected ./UILayer, got ` — exit 1. **The transferable form
    is narrower than gotcha 54 and sharper: an assertion about STRUCTURE must be made against a
    parser, not a substring, because a file's declarations outlive the things that referenced
    them.** And it says something about gotcha 54 itself — writing the wire assertion is not the
    hard part, writing one that can actually fail is. Plant every assertion whose job is to
    catch an absence; the ones that check for a presence tell you they work by passing, and the
    ones that check for an absence never tell you anything at all.

57. **A GENERATOR THAT CLIPS TO THE IMAGE INSTEAD OF TO THE CELL DRAWS INTO THE NEXT CELL, AND
    THE SHEET STILL LOOKS LIKE PEOPLE.** `_plot` in `tools/gen_placeholders.gd` bounds-checks
    the IMAGE, which is correct and useless: a sprite sheet is a grid of independent cells, and
    T5.6's run block overreached its stride by four pixels so the trailing boot's last row
    landed at y=40 — one row inside the cell below, where it drew a stray foot floating above
    the next block's head. Every rung stayed green, because no rung looks at a placeholder's
    pixels, and at a glance the sheet was fine. **The assertion caught it on its first run**:
    `and no cell bleeds into the one below it — expected [], got [8, 9]`. The transferable form
    is that a cell's TOP ROW is the one row nothing legitimately occupies, so it is a free and
    exact test for the whole class — and it costs one assertion for any number of cells.

58. **A SPRITE ANCHORED BY ITS FEET HAS ITS BOTTOM ROWS EATEN BY THE GROUND PLANE, SO ANYTHING
    DRAWN THERE CANNOT BE READ IN A CAPTURE.** `CharacterVisual` lifts the sprite by half its
    cell height so the node origin sits where the collision capsule does, which puts the last
    few rows of every cell right at the ground and behind it in depth. T5.6's frame tally lived
    at `cell.y - 3` and photographed as ONE pip where the decoded frame said three: the tally
    was right, the sheet was right, and the picture was unreadable. Moved to `cell.y - 7`.
    **This is a capture STANDARD failing rather than a drawing failing**, and it is invisible to
    every check that reads the PNG instead of the screen — the assertion on the sheet passed
    throughout. If a placeholder carries information meant to be read off a screenshot, keep it
    clear of the bottom four rows.

59. **READING A SPRITE'S FRAME BEFORE THE POST-DRAW AWAIT MEASURES A DIFFERENT MOMENT FROM THE
    PHOTOGRAPH, AND THE DISAGREEMENT LOOKS LIKE A CONTENT BUG.** `await
    RenderingServer.frame_post_draw` lets a physics step run, so a probe that logs
    `sprite.frame` and then awaits the shutter has produced two honest measurements of two
    different frames. T5.6 spent a while believing its own sheet was wrong because the log said
    cell 2 and the image showed one foot pip. Await first, then read the frame and grab the
    image together — inside the post-draw callback nothing advances, so the number and the
    picture are the same frame by construction. This is the sharp edge of the project's own
    rule that a capture must be READ rather than judged: reading it against the wrong number is
    worse than not reading it.

60. **`Camera3D.unproject_position` ANSWERS IN THE VIEWPORT'S LOGICAL SIZE, NOT IN THE CAPTURED
    IMAGE'S PIXELS.** This project scales content from 1920x1080, so under
    `--resolution 960x540` the viewport still reports a visible rect of `(1920, 1080)` while
    `get_viewport().get_texture().get_image()` returns a 960x540 image. Every unprojected point
    therefore comes back at exactly twice its place in the capture, and T5.6's first five zoom
    crops were photographs of grass with the character just off the edge. Scale by
    `Vector2(shot.get_size()) / camera.get_viewport().get_visible_rect().size` rather than by a
    literal 0.5, or the crop is right at one resolution and silently wrong at every other.

61. **A CONSTANT THAT "SPELLS OUT THE ENGINE'S DEFAULT" IS A SECOND COPY OF A NUMBER YOU DO NOT
    OWN, AND `--headless` CANNOT SEE IT WRONG.** `Settings._apply_shadows` sized the shadow
    atlas to zero to turn shadows off and restored `const POSITIONAL_ATLAS: int = 2048` to turn
    them back on, under a comment calling 2048 the engine's own default. It is 4096 —
    `rendering/lights_and_shadows/positional_shadow/atlas_size` and the directional size both
    default to 4096 in 4.7.2 — so this repository booted every windowed session at half the
    shadow resolution the project authored, measured `boot = 2048` against `boot = 4096`. Two
    things hid it. The OFF half is the half a wrong constant cannot break, and off is the only
    half T5.5 photographed. And `_apply_display()` returns early when
    `DisplayServer.get_name() == "headless"`, so no rung below the windowed capture executes this
    code at all — the suite could not have caught it however many assertions were pointed at the
    setting. Read the authored value back before the first write, the way
    `HD2DCameraRig._authored_dof` does; a preference is a VETO over what the author chose, and a
    veto has to remember what it is vetoing.

62. **AN ASSET CAN BE THE UNWIRED MIDDLE, AND A SYSTEM CAN BE CORRECT, ASSERTED AT BOTH ENDS AND
    INVISIBLE FOR FIVE PHASES.** The facing system quantises a direction into a `GameEnums.Facing`
    (`facing_test`) and a sheet COLUMN (`art_contract_test`), and every one of those assertions
    was green and right. `character_placeholder.png` drew ONE POSE EIGHT TIMES: measured over the
    figure band, facing 4 — the back, 180 degrees from the front — differed from facing 0 by
    **0.7%** of a 1,536-pixel cell, and facings 2 and 3 were **byte-identical**. The alt sheet was
    worse: three of its four columns differed only by the column tally. **The first observer was
    an owner who played the game** and said sideways movement "just slides to the side". This is
    gotcha 54 with the middle made of pixels instead of code, and it is harder to see for one
    reason: no rung reads a placeholder's pixels, and a sheet that looks like a person passes
    every glance a capture gets. The transferable form: for any seam whose two ends are DATA and
    CODE, ask what the data has to CONTAIN for the code's correctness to be observable — and
    assert that, because "the column index is right" and "the column looks different" are two
    claims and only one of them was being made. The floor was picked by measurement rather than
    taste (0.05, against the old sheets' best pair at 0.035 and the new sheets' worst at 0.075),
    which is T5.5's rule for a threshold applied to an image.
63. **A COLOUR YOU WROTE INTO AN IMAGE IS NOT THE COLOUR THAT COMES BACK, TWICE OVER, AND BOTH
    HALVES COST T5.8 A RUN.** On the WRITE side, `Image.FORMAT_RGBA8` quantises: `0.68` is stored
    as `173/255` and reads back as `0.6784`, which is near enough to look identical and far enough
    to fail `Color.is_equal_approx` — so a generator pass that repainted "every SKIN pixel" as hair
    matched nothing and drew five bald heads. Compare a read-back colour with an explicit
    tolerance, never with an epsilon. On the READ side, **the imported texture is not the PNG**:
    `process/fix_alpha_border=true` is on for every texture in this project and rewrites the RGB
    of TRANSPARENT pixels so filtering cannot pull a halo out of them. It works on the whole image
    rather than per cell, so a pip tally bleeds its colour into the transparent margin of the
    cell next door, and a mirror assertion comparing all four channels reported two cells as
    unmirrored **over pixels the sprite discards before it draws them** (`ALPHA_CUT_DISCARD`). Two
    transparent pixels are the same pixel. Any assertion that reads an imported sheet has to say
    which pixels are VISIBLE before it says whether they agree.
64. **A CAMERA THAT TRANSLATES PARALLAXES, SO A RIGID-OFFSET SEARCH UNDER-REPORTS IT — AND THE
    TWO NUMBERS WILL NOT RECONCILE.** T5.7's brute-force offset search is the right tool for
    "did the picture move", and T5.9 used it again on the screen shake. But the focal-plane
    maths says a camera sliding 0.302 m at 14 m and a 27-degree lens should move the image about
    24 px, and the best rigid fit came back at **(+14, −12)**. Neither number is wrong. A camera
    TRANSLATION shifts near geometry further than far geometry, so there is no single offset that
    fits the whole frame, and a least-residual search returns a depth-weighted average of all of
    them. What the search proves is that the scene moved RIGIDLY ENOUGH that one offset drops the
    residual sharply — 0.0513 to 0.0173, a 3.0x fall — and it is that RATIO, plus a control at
    the same offset, that carries the claim. Do not quote the pixel count as a measurement of the
    displacement; the metres in the log are the measurement, and the search is the corroboration.

65. **A SIGNAL THAT ANNOUNCES THE END OF A THING IS EMITTED BEFORE THE FLAG SAYING IT ENDED IS
    CLEARED, AND A GUARD READ ON THE SPOT REFUSES EVERY TIME — SILENTLY, BECAUSE EACH REFUSAL IS
    CORRECT.** `Director._run_transition` emits `area_entered` and clears `_transitioning` **two
    statements later**, which is right: the signal's contract is "the area is in the tree and the
    player is placed", and the transition is not formally over until the curtain has been asked to
    lift. So `Autosave`, connected to `area_entered` and guarded by `is_transitioning()`, would
    have hit its own guard on every single arrival and never once written a file. Nothing would
    be red anywhere: no error, no warning, both ends of the wire correct, the guard behaving
    exactly as specified, and a feature that does nothing at all. It is gotcha 54's family with
    the unwired middle made of ORDERING rather than of a missing connection. The fix is one
    `await get_tree().process_frame` before the guard, and the assertion that pins it emits
    `area_entered` inside a synchronous `run()` — where no frame ever comes — and requires that
    **nothing was written**. Before trusting any guard on a `_entered` / `_finished` / `_changed`
    signal, read the emitter and find out what is still true at the moment it fires.

66. **A FADE AND A CUT READ IDENTICALLY IN A SYNCHRONOUS TEST, AND THE FIX IS TO STEP THE TWEEN
    BY HAND RATHER THAN TO GIVE UP ON THE CLAIM.** `TestCase.run()` is synchronous, so no idle
    frame ever arrives and a tween created inside it never moves at all — which means an
    assertion taken after the call sees the value the fade STARTED from, and an assertion taken
    after a `custom_step` long enough to finish sees the value it was heading for. Neither
    distinguishes a 0.4-second fade from an instant jump, and T5.7 wrote that down as a limit
    assertions could not reach. They can. `SceneTree.get_processed_tweens()` returns the live
    tweens and `Tween.custom_step(delta)` advances one by exactly `delta` — so "the bus has NOT
    moved yet", "half the fade is half the drop" and "the whole fade lands exactly on target" are
    three separate measurements, and a fade rewritten as a cut fails all three (measured, T5.11
    plant 2, exit 1). **Snapshot the tween list BEFORE the call under test and step only what is
    new**: stepping every processed tween would advance a screen fade or a music cross-fade some
    other case owns and is mid-flight. The default transition is linear, which is what makes the
    midpoint assertion exact rather than approximate — a tween authored with an ease would need
    the curve, not the fraction.

67. **A CAMERA STILL CATCHING UP WITH A TELEPORTED PLAYER LOOKS EXACTLY LIKE A SHAKE, AND THE
    FIRST TRACE THIS PROJECT TOOK OF ONE WAS THE WRONG PHENOMENON ENTIRELY.** T5.12's gate probe
    teleported the player, waited twenty frames, sampled the camera as `rest`, opened the gate and
    reported **0.428401 m rising monotonically to 0.428789 and stopping**. Every part of that run
    was green and the number was a real measurement of a real camera movement — of `follow_lag`.
    Exponential smoothing APPROACHES its target and never arrives, so there is no frame count
    after which a rig is "settled"; twenty frames leaves 4 % of the error, and 4 % of a 10 m
    teleport is three times the shake being looked for. **The tell is the SHAPE.** A decaying
    oscillation crosses its rest position repeatedly; an asymptotic approach never crosses it at
    all, and both summarise as "the camera moved by X". The fix is to wait on the DERIVATIVE
    rather than on a frame count — per-frame movement under 10 µm, which took **53 frames** — and
    the general rule is that any measurement taken against a smoothed value needs the smoothing
    proved finished, not assumed finished. Gotcha 52's family with the still moment made of
    convergence rather than of animation frames.

68. **A SCREEN'S NODE NAME IS ITS ENGINE CLASS, NEVER ITS `class_name`, SO `find_child` CANNOT
    FIND ONE.** `find_child("MainMenuScreen")` returned null on a session with the main menu
    plainly on screen: a `UiScreen` is `.new()`d rather than instanced from a `.tscn`, and Godot
    names a scriptless-instantiated node after the ENGINE class the script extends — `Control`
    here — so every screen in the stack shares one unhelpful name. `UiRoot.top()` is the answer
    and the reason the stack is public: a screen's identity is `screen_id` and its position in the
    stack, and its node name is an engine detail that happens to be a string. The same trap waits
    for anything else built with `.new()` — every menu, every dialogue box. Nodes that come from a
    `.tscn` keep their authored name, which is why `find_child("Player")` and
    `find_child("NorthGate")` work in the same file three lines away.

69. **A TEST THAT QUOTES A CHECKER'S TRIGGER PATTERN TRIPS THAT CHECKER**, and the checker is
    right. `check_methods.gd` fails a line that both dispatches and builds a string, because a
    method name assembled at runtime is invisible to it — and `gates_test.gd`, asserting that
    exact classifier, wrote the opaque sample out whole on one line. Rung 11 went red on the test
    file. The fix is never to exempt the test: split the sample across two constants so no single
    line is a dispatch site, which is what the file now does and says why. The same trap waits
    for every gate whose evidence is a line of text — `check_strings.gd` and `check_boundary.gd`
    both scan `tests/`, and both would fail a case that quoted a real violation to assert against
    it. **The gate's own test is the first place a text gate meets a false positive.**


70. **A PLANT THAT PASSES IS EVIDENCE ABOUT THE TEST, NOT ABOUT THE CODE.** T5.14 deleted the
    stillness gate from `InteractionSensor._turn_to_target` — a real reversion, the whole point of
    the line — and the suite came back **green**. The assertion staged a player who walked with
    the SAME target selected throughout, and in that sequence the surviving `just_stopped` term
    already implies stillness, so removing the test changed nothing measurable. The gate exists
    for a target that CHANGES mid-walk, which is a player crossing a courtyard past a row of
    objects, and that frame was simply not in the case. With it added the same plant fails twice.
    **The answer to a plant that passes is a harder case, never a weaker claim** — and the reason
    to plant every reversion is precisely that a green plant is the only way to find out that an
    assertion was decoration.

71. **A CONTROL'S `get_global_rect()` IS IN STRETCHED CANVAS COORDINATES AND AN INPUT EVENT IS
    IN WINDOW ONES, SO POINTING THE MOUSE AT A BUTTON'S CENTRE MISSES IT.** This project's
    `canvas_items` stretch keeps the logical size at 1920x1080 whatever the window does, so at
    `--resolution 960x540` every rect a Control reports is exactly twice the coordinate an
    `InputEventMouseMotion` needs. T5.15's state probe aimed at a row's centre, the row never
    hovered, and **the capture came back with the hover row byte-identical to the normal one** —
    which is a perfectly plausible picture of a hover style that is merely subtle, and would have
    been recorded as one. `Input.warp_mouse` fails the same way and for the same reason. The fix
    is one multiplication: `get_viewport().get_screen_transform() * rect.get_center()`. The tell
    is that `Button.is_hovered()` returns false and `get_draw_mode()` stays 0 while the picture
    looks arguable; ask the button, never the pixels.


72. **A RE-ENTRANCY GUARD THAT `return`s DISCARDS WORK, AND WHETHER THAT MATTERS DEPENDS ON
    ITERATION ORDER — SO IT IS RIGHT MOST OF THE TIME AND SILENT WHEN IT IS NOT.** `Director`'s
    guard refuses a second transition, which is correct: the second request is a mistake and
    dropping it IS the fix. `QuestTracker` copied the shape into a place where the second call is
    not a mistake but a consequence — a listener on `quest_completed` writing the next chapter's
    start flag, which the guard's own comment names — and there dropping it loses a re-derivation
    that something legitimately asked for. It survived because the loss is invisible whenever the
    pass still reaches the affected item: with the dependent scanned AFTER its trigger everything
    works, and `ContentScan` does not sort, so the same content behaved differently on two
    machines. **The tell is a guard around a loop over a collection**: ask whether the caller
    wanted a RETRY or wanted to be REFUSED. Refuse a duplicate command; remember a duplicate
    notification. The fix is a pending bit drained by the outer pass, with the pass count bounded
    by something derived from the collection so a runaway listener errors instead of hanging.
    And the general half, which is gotcha 44's family: **a suite can be pointed at the right
    system and still not reach the path**. `quests_test.gd` drove `evaluate()` directly by
    design, and a re-entrant call can only arrive on `flag_changed`, so no number of assertions
    in that file could ever have found this.

73. **`<` ON TWO `StringName`s COMPARES THEIR INTERNED ADDRESSES, NOT THEIR TEXT — SO SORTING BY
    `node.name` SORTS BY LOAD ORDER AND LOOKS LIKE SORTING BY NAME.** `InteractionSensor._select()`
    broke a scoring tie with `a.name < b.name`, and its header promised "ties are broken by node
    name so the order is stable frame to frame rather than dependent on physics callback order."
    `Node.name` is a `StringName`. Measured both ways inside one run, on the same pair: the
    `StringName` comparison said `Z_later < A_earlier` and `String(a) < String(b)` said the
    opposite. **The half that makes this expensive is that the comment was not wrong, only
    half true** — an interned address does not move while the node lives, so the order IS stable
    within a run and the flicker the comment worried about genuinely never happened. What was
    false is that it was ever the NAME: an author numbering two overlapping objects `sign_a` and
    `sign_b` to choose between them was ignored, and because intern order is script and scene
    load order, the same two objects could tie differently when reached another way. Eight rungs
    and 2,148 assertions were green over it, because the demo has no two interactables at an
    exact tie. The fix is one cast, `String(a.name) < String(b.name)`.
74. **A FILE COMPARED BYTE-FOR-BYTE AGAINST ITS OWN OVERWRITE CAN BE EQUAL TO IT, SO "UNTOUCHED"
    IS NOT A BYTE COMPARISON.** `save_dir_test.gd`'s load-bearing case asserts that a write while
    the store is redirected leaves the previous directory alone. The first version took a copy of
    the earlier file, wrote again, and compared the two — and the full reversion, every use of
    `save_dir` put back to the constant, PASSED it. Both writes landed on the same path inside
    the same second, and the only fields that vary are `saved_utc`, which is second-resolution,
    and `playtime_seconds`, which `snappedf` rounds to a tenth: the overwrite was byte-identical
    to what it overwrote. The two saves now carry different markers through the probe's section,
    and the same plant fails 4. **This is gotcha 70 one turn on** — that one says a plant that
    passes is evidence about the plant; this one says a plant that passes against a genuinely
    applied edit is evidence about the CASE. Both end the same way: the answer is a harder case,
    never a weaker claim.

    **AND THE PROBE THAT CHECKED THIS THE FIRST TIME SAID THE OPPOSITE, WHICH IS THE REAL
    LESSON.** A standalone `--script` probe created two nodes, compared their names, and printed
    alphabetical order — so the language looked innocent and the defect looked like a broken
    fixture. It agreed by coincidence: with only those two names interned, their addresses
    happened to fall in alphabetical order. **A probe of an ordering must run in the context
    whose order is in question**, because the thing being measured is a property of the whole
    process, not of the two values. This is gotcha 70 turned around — there a plant PASSED and
    was evidence about the plant; here a probe passed and was evidence about the probe. The tell
    for both is the same: a result that contradicts a measurement taken somewhere else is a
    question about the two contexts before it is an answer about the code.

75. **A BRAND-NEW ASSERTION CAN PASS ITS OWN PLANT BY COINCIDENCE OF TIMING, AND THE FIX IS THE
    CASE'S CLOCK RATHER THAN ITS LOGIC.** T5.23's *"interrupted standing does not accumulate"*
    passed under the very defect it was written for. The wrongly-started idle break had already
    FINISHED inside the same stand, so at the moment the case looked, the visual was drawing the
    idle block — which is exactly what the correct behaviour draws — and the assertion agreed by
    coincidence. Nothing about the claim was wrong; the sample was taken at the one instant that
    cannot distinguish the two behaviours. **This is gotcha 70's family and gotcha 74's twin from
    the other side**: 74 is a plant that passes because the two states are byte-identical, 75 a
    plant that passes because the two states are momentarily identical. When a case measures a
    thing that STARTS and ENDS, ask what it would read one tick earlier and one tick later before
    trusting a green.

76. **`contains` FINDABILITY IS SATISFIED BY AN INCIDENTAL CROSS-REFERENCE, SO A RECORD GATE
    CANNOT TELL "RECORDED" FROM "MENTIONED IN PASSING" — AND A RECONCILE PACKAGE MANUFACTURES
    THOSE MENTIONS AS IT WORKS.** T5.24's first plant deleted T5.19's whole package-log row from
    `ROADMAP.md` and the suite stayed **green at 2,274**. The gate was working exactly as written:
    two other rows in that file mention T5.19 while saying something else — one crediting its
    measurement, one its argument — and `roadmap.contains("T5.19")` is true of either. **Then the
    same thing happened a second time to the corrected plant**, because T5.24's own new row names
    all five packages it reconciled in the course of explaining what was missing, so deleting
    T5.18's row left T5.18 findable inside the sentence describing its absence. A row that records
    a gap is itself a cross-reference to every id in the gap. **The weakness is inherent to
    findability and is the price of the property being worth having**, the alternative being a
    gate on recording SHAPE, which would fail T5.14 for being recorded beside its criterion rather
    than as a row. Three rules follow. **Plant a record gate on an id the document names exactly
    once** — count first: `grep -o -- "$id" doc | wc -l`. **Re-count after your own edits**, since
    a reconcile row changes the answer for precisely the ids you came to fix. And know that **a
    package whose only trace is somebody else's sentence about it passes** — T5.24 found ITSELF in
    that state, its only roadmap mention being an aside inside the WP-07 line it had just written,
    which surfaced only because deleting that line failed TWO assertions instead of one. It gave
    itself a real log row. Same shape as gotcha 70 in that a green run was nearly filed as
    evidence, and the same answer: establish what the plant actually changed before trusting
    either outcome.

77. **A SUBSTRING TEST ON AN ID IS SATISFIED BY A LONGER SIBLING ID, SO THE ASSERTION IS READING A
    STRING THAT IS NOT THE ID — AND THE IDS IT CANNOT SEE ARE THE OLDEST ONES.** `contains("T5.1")`
    is true of a document that only ever mentions T5.10 through T5.19. In this repository that made
    four of `record_shape_test.gd`'s assertions unfalsifiable — `T5.1`, `T5.2`, `WP-09` and
    `WP-14`, prefixes of `T5.10`-`T5.19`, `T5.20`-`T5.24`, `WP-09b` and `WP-14b` — so deleting
    every genuine trace of those packages left the suite green. **Distinguish this from gotcha 76,
    which it looks like and is not.** 76 is a judgement about whether a mention COUNTS as a trace;
    this is that no trace was being looked for. Tightening what counts would never have found it.
    **The tell is that the ids affected are the low-numbered ones**, whose rows sit furthest up a
    file and whose absence a reader is least likely to notice, so the check is weakest exactly
    where review is weakest too. **T5.24's own entry had written the sentence and not followed
    it** — noting that a wrong detail heading "could not have been seen because
    `contains("T5.20")` succeeds elsewhere in the file" — which is the general fact stated about a
    specific place. Fix: match on a word boundary, `\bT5\.1\b`, **and escape the dot**, since an
    unescaped one matches any character and lets `T5x1` satisfy `T5.1`, which is the same defect
    mirrored. `\bWP-09\b` correctly does not match `WP-09b`, digit-to-letter being no boundary.
    **And the proof needs three runs, not two**: the tightened gate is green on the live tree
    either way, so A (no plant, green) and B (plant, red) are equally consistent with a gate that
    was already correct — only C, the OLD check against the SAME plant going green, shows what was
    broken. When a fix makes nothing newly red, the old code against the new plant is the evidence.

78. **A LIST OF WHAT TO CHECK IS NOT A CHECK THAT THE LIST IS COMPLETE, AND A SUBSTRING TEST ON A
    CI FILE CANNOT TELL A STEP FROM A COMMENT.** `gates_test.gd` existed to catch "a gate written,
    committed, and never wired" — its own words — and could catch neither shape of that. Its
    `LADDER` const named seven checkers with nothing asserting it named ALL of them, so an eighth
    `tools/check_*.gd` was invisible to the case whose entire subject is a gate nobody runs. And
    its wiring assertion was `workflow.contains(checker)`, which is true of a workflow naming the
    checker **in a comment** — and this workflow's comments do name the checkers, deliberately,
    because they carry the reasoning. **Measured: commenting out both `run:` lines for
    `check_signals` left the suite GREEN at 2,276.** A checker running in neither job, and the
    ladder's own gate said fine.
    **Two jobs is the second half.** The count has to be per-job rather than per-file: a checker
    wired into the full job and missing from the stripped one is wired into half a ladder, and the
    stripped half is the one that proves the template stands up with no game present. `contains`
    returns one bool for a whole file and cannot express that at all.
    Rules. **Assert the INVOCATION, not the name** — a non-comment line carrying both the script
    path and `--script`. **Assert the COUNT against the number of jobs**, with the job names
    themselves asserted so that number is not a fiction. **And derive the list from the
    directory**, which `test_runner.gd` has done for `CASES` since T2.2 and which is the same fix
    for the same reason: a list of things to check rots, and its rotting is invisible precisely
    where it matters most. The generalisation worth carrying is one question: **when a gate reads a
    FILE rather than the behaviour, ask which parts of that file are prose.** Gotcha 77 and this
    one are the same mistake in two documents, one week apart.
79. **A GOTCHA WITH A NOTE IN THREE FILES IS NOT A GOTCHA THAT IS FIXED, AND THE UNFIXED SITE IS
    INVISIBLE UNTIL SOMETHING UNRELATED PERTURBS IT.** Gotcha 33 above says
    `Array[StringName].sort()` orders by interned handle rather than alphabetically, and
    `area_db.gd`, `equipment.gd` and `inventory.gd` each carry a comment saying exactly that and
    each sort through `String`. **`QuestTracker.ids_in_state` still called `out.sort()`** — and its
    own doc comment claimed *"Sorted, so the journal draws a stable order without holding one of
    its own."* Three fixes and a written-down gotcha read as a closed matter, and the fourth site
    sat there for five phases.
    **It stayed invisible because the wrong order was STABLE.** The handle order does not vary
    between runs of the same binary on the same code, so every test passed, every capture looked
    right, and the journal drew a consistent list. **T5.31 published four new flag names at boot,
    which shifted the intern table, which flipped the order, which turned a journal assertion red
    in a file that row never touched.** Baseline returned `[quest/fixture_gather,
    quest/fixture_errand]` — the order that is not alphabetical — and the new code returned the
    alphabetical one, so the failure looked like the new code's fault and was the old code's.
    **And a coupled TEST is how the cost arrives.** `item_count_test.gd` read "the last Label in
    the list", which is a bet on an order the base never actually promised; its comment guarded
    the right way against the wrong risk, saying it found the row *"by type rather than by index,
    so a heading cannot make this assert about the wrong row"*, while the order of the QUESTS was
    the unexamined thing. A test that addresses a thing by position is a test that will fail for a
    reason that is not about its subject.
    Rules. **Grep for the pattern, not the note** — when a gotcha is written down, the fix is a
    search across the tree for every site, and a list of "already fixed in" files is a list of
    where somebody happened to look. **Suspect the untouched file first** when a change in one
    system reddens an assertion in another: the new code is usually the trigger and rarely the
    defect. **And prove a cause on enough data to be sure** — two wrong hypotheses died here
    first, a timing race (killed by the failure being deterministic across three runs) and
    pointer-ordered sorting, which a **two-element probe disproved by luck** before an
    eight-element one confirmed it: `alpha, delta, echo, foxtrot, charlie, bravo, hotel, golf`. A
    probe with two possible orders has even odds of lying to you.
    **T6.9 is the same lesson, and it cost real saves.** T5.22 built `SaveFixture` and redirected
    the two cases it had in front of it. Fourteen more kept calling `save_to_slot` and
    `delete_slot` against the real `user://saves`, and two of them said they owned it. **A green
    run deleted every real slot and the autosave**, and nothing failed, because a test that
    deletes what it wrote passes whether or not it was writing somewhere that mattered. Rule:
    **a case that saves through ANY path calls `SaveFixture.activate()` first** (`TESTING.md`).
    To check a claim like this, plant a sentinel file where the harm would land and see whether
    it survives the run. A green suite cannot tell you.
    **T6.10 found the same harm outside the suite.** A `--new-game` capture is a real run, so the
    autosave wrote the real slot, and the probes deleted real slots. `DevSaves` now points every
    debug launch at `user://dev_saves`. The same test applied: a planted sentinel survived.

80. **AN ENGINE NOTIFICATION ARRIVES BY PROPAGATION, AND A NODE IT IS BEING PROPAGATED TO CANNOT
    TAKE A CHILD. `notification()` IN A TEST DOES NOT REPRODUCE THAT.** T6.5's `UiRoot` answered
    `NOTIFICATION_APPLICATION_FOCUS_OUT` by emitting `Events.focus_lost`, and `ScreenKeys` answered
    that by opening the pause menu, all synchronously. The engine sends the notification with
    `propagate_notification` from the root, which marks each node busy while it walks it, so the
    `add_child` failed: `Parent node is busy setting up children, add_child() failed`. **And
    `UiRoot.open` appends to its stack BEFORE `add_child`,** so the stack recorded a screen that
    was never in the tree. The world paused, nothing was drawn, and the log said
    `Opened 'pause' at depth 1`. The suite had passed, because it sent the notification with
    `_stack.notification(...)`, which marks nothing busy. The windowed capture caught it: a
    stopped world, the prompt gone, and no menu. A probe then read `tree=false size=(0.0, 0.0)`
    for the stack's top screen.
    Rules. **A handler for an engine notification that could change the tree defers its work**
    (`call_deferred`). **A test sends a notification the way the engine does**, with
    `propagate_notification`, and asserts nothing is answered inside it. And a log line that
    says a thing happened is not proof it did, when the call that makes it happen can fail
    after the line is written.
81. **THE PROJECT THEME LOADS BEFORE THE FIRST IMPORT, SO AN IMPORTED RESOURCE NAMED IN IT IS A
    `Parse Error` ON EVERY FRESH CLONE.** T6.6's first version put the font chain in
    `ui_theme.tres`, which is `gui/theme/custom`. The engine loads that theme at startup, before the
    filesystem scan. On a fresh clone the fonts are not imported yet, so the first `--import`
    printed `Parse Error: [ext_resource] referenced non-existent resource` twice. That is exactly
    what CI's rung 2 greps for. **The second `--import` was clean**, and so was every run on the
    machine that wrote it, because its `.godot/` already held the fonts. It was found only by
    importing a copy of the tree with no `.godot/`. Rules. **The theme names no imported resource**:
    a font, texture or stylebox image goes in its own file and is installed at runtime (the chain
    is `UiRoot.install_font_chain`). And **a change to what loads at startup is proved on a tree
    with no `.godot/`**, not on the working copy. The companion trap was on the same row: **on
    Windows, system font fallback hides tofu.** Nirmala UI and YaHei drew Bengali and Chinese with
    no bundled font at all, so the "before" capture had to switch `allow_system_fallback` off to
    show what a player without those fonts sees.
82. **`tr()` ON A PLURAL ROW ANSWERS ITS FIRST FORM, FOR ANY COUNT, AND SAYS NOTHING.** T6.14's
    red run read "13 hour slips past": the row had both forms, and the toast's `tr(key)` took the
    singular. A count beside a noun goes through `TranslationServer.translate_plural(key, key, n)`
    (or `tr_n`), never `tr()`. **The CSV importer reads plural forms and its documentation does not
    say so**: the 4.7 reference lists four importer options and no description. A `?plural` column
    names the plural key, and each further form is a following row with an EMPTY key. A missing
    form comes back as the key itself, so a check that the forms merely differ passes on a row with
    one form; T6.14's lint also refuses the key.
83. **IN 4.7, `map_force_update` DOES NOTHING WHILE ASYNC ITERATIONS ARE ON, AND THEY ARE ON BY
    DEFAULT.** A map built by hand in a synchronous test kept iteration id 0, every query came back
    empty, and a clamp that returns `from` on an empty path passed its island case for the wrong
    reason. `map_set_use_async_iterations(map, false)` AND `region_set_use_async_iterations(region,
    false)` make it synchronous. Assert `map_get_iteration_id(map) > 0` before trusting any answer.
    The sibling lesson from T6.15: a "cannot reach" from a target the code INVENTED is the code's
    fault. Log the target before blaming timing.

## How work is sliced

**One package, one chat** — see [`docs/WORK_PACKAGES.md`](WORK_PACKAGES.md), which is the
board of every package from here to skeleton-complete — WP-01 to WP-15 plus the T-phases. Each
names the exact files that chat should read, so a session loads a few hundred lines instead of three thousand. The layer rule
(`core -> content -> systems -> gameplay -> ui`, downward only) is what makes that possible: a
package never has to read upward.


T5.20 and now T5.24 each came off it. What remains is a real choice, not a queue:

- ~~**The template-default vs game-choice taxonomy.**~~ **CLOSED by T5.28 —
  [ADR-0007](decisions/ADR-0007-template-default-vs-game-choice.md).** Ranked first for five
  packages and deferred each time because *"it is prose and cannot be proved by running the
  engine"*. The ADR draws it **three** ways rather than two — TEMPLATE RULE, TEMPLATE DEFAULT,
  GAME CHOICE — and the test that separates a default from a rule is mechanical: **does a seam
  exist?** A "default" a game cannot replace without editing `src/` is a rule that has not
  admitted it. **Do not re-rank this row.**
- ~~**A narrative-staging seam.**~~ **CLOSED by T5.28 as a GAME CHOICE, and the reason is that the
  seam was already open.** The nine `cutscene` mentions across eight files under `src/` read as
  IOUs and are **receipts**: `dialogue_duck.gd` *"deletes nothing here — it calls `Audio.duck()`
  from its own occasion"*, `environment_driver.gd` *"without touching this file"*,
  `screen_fade.gd` *"can later ask for the same fade"*. A game sequences its own beats in its own
  code root. **The base builds no sequencer and no cutscene resource** — a step enum would grow
  `GameEnums`, which is append-only because ordinals live in `.tscn` files, for a shape every game
  authors differently. What this row actually needed was a stated reason, and it has one.
- ~~**Time on the flag surface**~~ — **BUILT, T5.31 (`5.5.0`), and the cycle above the day with it,
  T5.32 (`5.6.0`).** Kept here struck through rather than deleted, because this list is where a
  reader looks for what is still open, and for two rows it said this was. T6.0 found it stale.
  `time/hour` and `time/day` publish as ordered ints, a phase and a weather kind as one bool under
  the lowercased name, `time/day_of_cycle` as an ordered int; all derived, none saved. A calendar
  with weekday names, months or seasons remains a GAME CHOICE.
- **A call recorder, to answer the 86.** T5.13's gate reports 86 public methods reached only from
  `tests/` or `tools/`, and a text scan cannot shrink that number.
- **Split `tools/gen_placeholders.gd`**, at 234 of its 250 — sixteen lines spare, so it is a want
  rather than a need. T5.20 corrected the ten-row-old claim that it was the tightest file; it was
  not, and `check_budgets.gd` had the number all along.
- **`src/systems/scene_director/director.gd` at 187 of its 190** is the tightest file in the repo
  after T5.20. Its override was already raised once by WP-14, so the row is really the question of
  whether a scene director deserves more room or a seam — not a mechanical split.
- **The placeholder sheet's fourth animation BLOCK is not asserted visually distinct from its
  first.** `sheet_facings_test.gd` measures exactly this for FACINGS, with a floor picked by
  measurement, after T5.8 found `character_placeholder.png` drawing one pose eight times at 0.7%
  difference. T5.23 added a second idle block and measured the two blocks at 0.6184 of the crop —
  **in a windowed capture a person read, not in the suite** — so the equivalent of T5.8's gate for
  BLOCKS does not exist and a sheet whose break block is a recolour of its idle would pass. That
  is T5.8's own argument left half-applied, and it is the cheapest honest row on this list.
- **T5.23's idle-break capture caught a SIDE facing, where `_character_cell` draws no far arm.**
  The raised arm was verified numerically and only partly visually. Re-taking it on a front facing
  is a capture rather than a package, and belongs to whoever next touches the sheet.
- **WP-10 crafting**, if a game wants it. Still OPTIONAL per `TEMPLATE.md`.
- **Nothing at all**, which stays legitimate for a base that has answered every question it set
  out to.

*(This line names ONE package or one honest choice between a few. Earlier revisions accumulated a
stale line per package and two were left stranded here; if you ever find two, the lower one is
history — delete it.)*

The original WP-08 through WP-15 continue after the T1 and T2 phases, several of them re-framed.

## Plan — where this is going

**Phase 1 is complete and Phase 2 is well under way.** The demo loop works end to end: walk a lit
courtyard through a day/night cycle, be prompted, read a sign, throw a lever, take an item,
empty a chest, be refused by a gate that wants a key, open it once you carry the key, cross a
volume that fires once, rest on a bench and watch the light change, climb a trellis to a terrace
and back down, press I at any point to see what you are carrying in a window that stops the
world — then walk north through a door into a lantern-lit hall that has never heard of the sun,
and come back, and ask the garden-keeper who they are and what lies behind the north gate, in a
box that leaves the world running behind it — and that conversation now hands you an errand, which
the lever you already threw and the dais you already crossed advance, and three rose petals out of
the wicker chest settle — the journal counting them `2 / 3` on the way, readable on `J` at any
point — and pick a lantern up, hold it from the satchel with Enter, and pass under an arch
that turned you away a moment earlier with a line its author wrote — and press `M` to see the two
places you know drawn on one map, the hall a grey `???` until you have walked to it and a gold dot
you can press to travel back to once you have — and every one of those walks now sounds different
depending on whether you are crossing grass, the wooden dais or stone. Every one of those changes
survives a save and a
reload, including from the far side of an area that is no longer loaded. All of it is covered
by 2,302 headless assertions.

**Next, and for the first time it is not an ordered queue.** Every blocking row is done: Phase T3
closed with WP-14b, WP-15 was CLOSED by the owner, and T4.1 shipped the version and the upgrade
note. The one criterion left in Phase T4 is a RELEASE TAG, which is the owner's to take.

1. **The rest of the system catalogue is COMPLETE**, and WP-15 is closed — see the board. WP-11
   closed the last row that had no proof at all, and WP-10 is OPTIONAL.
   *(Every T-numbered row is DONE. T3.1 — one scan behind all five catalogues, every accessor still
   typed. T3.3 — an item count is a flag published downward, so a step can require N of an item id
   and the quest system still does not know what an inventory is. T3.2 — the look of an area is
   data: a shared material library, the environment post stack and per-area camera framing, plus
   texture import defaults settled by measurement and Git LFS refused in writing.)*

*(Path actions, NPC schedules, navigation baking, weather visuals, quests, equipment, the world
map, the shared content scan and counted quest steps are all DONE — WP-06, WP-07, WP-08, WP-09, WP-09b, WP-11,
WP-13, T3.1 and T3.3.)*

**Still open, and expensive later:**
- **The export path is PROVEN as of T2.0** — an exported `.exe` reports the same catalogue counts
  and resolved paths the editor does. What remains unproven is a RELEASE export's content, because
  the readout is behind `OS.is_debug_build()`, and every platform other than Windows.
- **The string audit exists as of WP-14 and is deliberately PARTIAL.** `tools/check_strings.gd`
  checks a literal reaching a text SINK and every `*_KEY` const resolving. What it still cannot
  see is written in its own header: a literal reaching a sink through a variable, a sink outside
  `src/*.gd` (a `.tscn` authoring `text = "Play"`), a literal handed to `draw_string()`, and
  whether the key `tr()` got was the RIGHT key. Computed keys (`verb.*`, `refusal.*`) are still
  the enum loop in `items_test.gd`, which is better verification than a scan could be.

## Read next

`CLAUDE.md` (rules, and the doc router table) · `docs/TEMPLATE.md` (why this is not a game) ·
**`docs/AUTHORING.md`** (add an area, an NPC, a conversation, an item, an object, a quest,
equipment, a place on the world map) ·
**`docs/ART_CONTRACT.md`** (what art must satisfy) · **`docs/TESTING.md`** (adding assertions) ·
`docs/ARCHITECTURE.md` (§ The extension surface — what may be subclassed) ·
`docs/NEW_GAME.md` · `docs/SYSTEMS_INVENTORY.md` · `docs/ROADMAP.md` · `docs/DEVLOG.md` ·
`src/core/events/events.gd` (the connection map)
