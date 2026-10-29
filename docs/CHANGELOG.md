# Changelog

**What this file is for, and it is not release notes for players.** A game built on this base
merges the base's later commits ([`UPGRADING.md`](UPGRADING.md)), and the only question that
matters at that moment is *what will this do to the files I wrote*. So every entry says what
changed and, more importantly, **what a consuming game has to do about it** — which for most
entries is nothing, and saying so explicitly is the point.

**The top `##` heading is the version in `project.godot`'s `[template] base/version`**, and
`tests/unit/version_test.gd` fails rung 4 if the two disagree. Bumping one without the other is
the exact rot this discipline exists to prevent.

**What the numbers mean** — the full promise is in [`UPGRADING.md`](UPGRADING.md):

| Bump | Means | A consuming game |
|---|---|---|
| **MAJOR** | a file the game wrote must change | must read the entry before merging |
| **MINOR** | the base gained something a game may ignore | merges and carries on |
| **PATCH** | nothing a game wrote is affected | merges and carries on |

---
## 5.16.4

*2026-10-29 — T7.1: CI's actions off the deprecated Node 20.*

**A consuming game does: nothing**, unless it edited `.github/` itself, in which case the merge
may conflict there and the resolution is to take these version lines. `src/`, `tools/` and
`tests/` are byte-identical.

**What changed.** `actions/checkout@v4` to `@v5` and `actions/upload-artifact@v4` to `@v6` in
`ladder.yml`, and `actions/cache@v4` to `@v5` in `setup-godot`.

**Why.** Every CI job ended in GitHub's warning that these three target Node 20, which is
deprecated and was being forced onto Node 24. A warning on every run is one nobody reads, so it
would have hidden the next real one.

---
## 5.16.3

*2026-10-29 — T7.0: a script for the owner's playtest.*

**A consuming game does: nothing.** `src/`, `tools/` and `tests/` are byte-identical; only
documents changed. A game may copy `docs/PLAYTEST.md` as its own playtest script and replace the
demo's names with its own.

**What changed.** New `docs/PLAYTEST.md`:
- a step-by-step play-through of every player-facing system in the demo;
- the first-run defaults question (#8) asked before settings are opened;
- the default controls table;
- the shape a finding is reported in, each finding becoming a `T7.n` row.

`CONTEXT.md` also records that a combat fork exists downstream and that this changes nothing
here.

**Why.** Phase T6 closed waiting on the owner's playtest. A playtest without a script finds what
the player happens to try, and a script is what makes it cover the base.

---
## 5.16.2

*2026-10-16 — T6.15: a wandering NPC never picks a spot it cannot walk to.*

**A consuming game does: nothing.** No file a game wrote changes; one public static method is new.

**What changed.** `NpcBrain._tick_wander()` used to hand the agent a raw random offset from the
post. Now it passes the offset through the new `NpcBrain.reachable_point(map, from, wish, layers)`,
which returns where a real path from the NPC ends. With no path at all, it returns `from`.
`_check_reachable()` is unchanged, so an *authored* waypoint that cannot be reached is still an
error. `tests/unit/npc_reach_test.gd` covers the clamp on a hand-built map.

**Why.** A wander target near a riser the body cannot climb, or in the strip the bake erodes by
`agent_radius`, was reported as `Keeper cannot reach 'dais'`: an ERROR for a destination nobody
wrote. In the demo courtyard it fired 10 times in 8 windowed runs; after the fix, 0 in 10.
**A game with a post beside a step, a wall or a prop had the same error waiting.**

---
## 5.16.1

*2026-09-30 — packages run one at a time: the next starts only after the last one's PR merges.*

**A consuming game does: nothing.** `src/`, `tools/` and `tests/` are byte-identical; only the
process documents changed. A game that keeps the board's working method may want the same rule.

**What changed.** `WORK_PACKAGES.md` § The rules gains **Serial, not parallel**: before starting,
check `gh pr list --state open` and `git worktree list` and stop if another package is in flight;
build from a freshly fetched `origin/main` and decide the row id and version then; a defect found
mid-package becomes a `TODO` row, not a chip. Closing item 7 now requires the PR **merged**, item 8
raises the next chip only after that, and a new item 9 removes the merged worktree. `CLAUDE.md`
says the same in one paragraph; `CONTEXT.md` states the rule and that `user://dev_saves` is still
shared by every worktree. `TESTING.md` states T6.14's stripped count from CI, `2592`.

**Why.** Phase T6 ran T6.9 to T6.13 at once, in five worktrees, and paid for it in renumbered rows,
claimed versions, repeated merges of `main` and duplicate chats, and one package, T6.13, that
existed only because two parallel suites emptied each other's saves.

---
## 5.16.0

*2026-09-30 — a rest's toast agrees with its count: "1 hour slips past", never "1 hours" or "0 hours".*

**A consuming game does: nothing, unless it has a `{hours}` row of its own or has edited
`localization/strings.csv`.**
- **The CSV gained a column.** `?plural` now sits after `keys` on every row, so a game that edited
  the file will see every line conflict, not only the last one (`UPGRADING.md` § 6). Resolve it by
  taking yours and adding one empty field after the key on every row: in a shell,
  `sed -i '1s/^keys,/keys,?plural,/; 2,$s/^\([^,]*\),/\1,,/'`. Then `--headless --import`.
- **Any row whose text uses `{hours}` must have both English forms**, or the new
  `tests/unit/plural_count_test.gd` fails it: the plural key in `?plural`, and the second form on
  the next row with an empty key, as the base's own rest row shows. A plain row still renders at
  runtime; only the lint asks for the second form.
- **A rest now reports the nearest whole hour, and never zero.** It used to floor. A game that
  read the toast's `hours` argument elsewhere sees 1 for a 30-minute rest where it saw 0.

**What changed.** 4.7.2's CSV importer reads plural forms, though its documentation does not say
so; a scratch project proved it, and the locale's own rule picks the form. `RestPoint` now asks
`TranslationServer.translate_plural` for that form and sends it, because `tr()` on a plural row
answers the first form: measured before the fix, a thirteen-hour rest read "13 hour slips past".
`RestPoint.hours_for(minutes)` is new. Proved red first, with 8 failed, and photographed after.
**MINOR, and the call is stated:** nothing in `src/` a game wrote must change, and a game's plain
rows keep working, but the lint does ask something of a game's own `{hours}` rows.

---
## 5.15.1

*2026-09-29 — every "Commonly forgotten" item carries a verdict, and one without fails the suite.*

**A consuming game does: nothing.** A PATCH, and `src/` and `tools/` are byte-identical: one new
test case, `tests/unit/forgotten_list_test.gd`, and documents. If your game has edited
`docs/SYSTEMS_INVENTORY.md` § "Commonly forgotten", every item there now needs the bold marker
`DONE — <id>` or `CLOSED (game's) — <id>` naming a package on your board, or the case fails; a
game that deleted the section fails the case's first assertion and should delete the case with it.

**What changed.** Phase T6 was planned as the closure of that list, and its exit criterion was
that every item says DONE or CLOSED (game's) beside a package id. Eight of fifteen did not in a
form anything could read: some were settled work described in prose, one (#8, first-run defaults)
had no verdict at all. Measured before the edits, the new case failed 16 assertions, two for each
of those eight; after, it passes 32 of 32. Planted: an id with no board row and a gap in the
numbering fail one assertion each. #8 is CLOSED (game's): the base keeps every default in one
`Settings.DEFAULTS` line and a game tunes them against its own content. Asked for a playtest
verdict on those defaults, the owner has not playtested yet; the closure stands until they do.

---
## 5.15.0

*2026-09-29 — two suite runs at the same time, in two worktrees, no longer break each other.*

**A consuming game does: nothing, unless a test case of its own named a scratch path.** Every path
the suite writes now lives under `user://test_runs/<pid>`, one directory per running process,
removed at the end of the run; a crashed run's is pruned by a later run once its heartbeat file is
15 minutes old. If a case YOUR game added wrote `SaveFixture.ROOT`, `SaveFixture.UNCLAIMED`,
`SaveFixture.SETTINGS_PATH`, `Fixtures.ROOT` or one of `Fixtures.ITEM_DIR` / `DIALOGUE_DIR` /
`SCHEDULE_DIR` / `QUEST_DIR` / `AREA_DEF_DIR`, it will not parse: each is now a function
(`SaveFixture.root()`, `SaveFixture.unclaimed()`, `SaveFixture.settings_path()`,
`Fixtures.quest_dir()`). A case that only calls `activate()`, as `TESTING.md` tells it to,
changes nothing. A scratch directory of its own belongs under `RunScratch.path("<name>")`. **If
your game has its own runner**, copy `RunScratch.begin()`, `beat()` and `finish()` from
`tests/test_runner.gd` along with 5.13.1's `park()`.
**MINOR, and the call is stated rather than hidden:** those constants were test-framework
internals no document told a game to use, and the only `src/` change is additive.
`KeyBindings.file_path` is a new var, defaulting to `KeyBindings.PATH`, which keeps its name and
value; a shipped build never moves it.

**What changed.** `user://` is keyed on `config/name`, so every worktree on a machine shares it,
and `SaveFixture.activate()` and `deactivate()` empty their directory while `Fixtures` rewrites
its own. Two suites running at once deleted each other's slots and fixtures mid-case. Measured
with a private `APPDATA` holding nothing else, on the unchanged tree, two suites started 0.3s
apart failed 15 and 8, and 6s apart 2 and 1, in runs that pass alone. On this tree the same
pairs pass on both sides. **Liveness is a heartbeat file, not the pid**, because on Windows
`OS.is_process_running()` answers false for any process the caller did not start, and a first
version that trusted it deleted every concurrent run's directory. **5.13.1's parking directory
moved in with the rest.** `park()` empties it before EVERY case, so as the fixed name
`user://test_saves_unclaimed` it was the same race, met far more often than `activate()`'s. **And
one real file was found on the way:** `options_test` rebinds a key and then resets, and the reset
deleted `user://input.cfg`, the developer's real key bindings, on every suite run. The runner now
points `KeyBindings.file_path` at the run's own copy.

---
## 5.14.0

*2026-09-29 — dialogue can be skipped to its end, and can move on by itself.*

**A consuming game does: nothing.** Its settings screen gains one row, "Auto-advance dialogue",
because the screen is generated from `Settings.DEFAULTS`, and the row is off. **MINOR**: the base
gained a setting, two public methods on `DialogueScreen` (`skip()`, `hold_seconds()`) and four
strings, and a game may ignore all of them. It is not a PATCH, because a key that did nothing now
does something: **cancel (Escape, or the pad's B) during a conversation skips.** Before, it did
nothing there, since a conversation has `closes_on_cancel = false`. A game that bound its own
meaning to cancel while a conversation is open should read this.

**What a skip does.** It walks the runner through `advance()`, so every node on the way is
arrived at and its effect fires, exactly as if the player had read it. It stops at the first node
that offers a choice and shows that choice whole, because a branch is the player's to take, and a
second skip there does nothing. With no choice ahead, it runs the conversation to its end and the
box closes. A cycle of plain lines stops the skip after 512 lines rather than hanging the game.

**What auto-advance does.** `gameplay/dialogue_auto_advance`, off by default so a slow reader is
never hurried. On, a whole line is held for 1.5 s plus its length at 15 characters a second,
divided by `gameplay/text_speed`, and then moves on. It never answers a choice. The hint reads
"Auto" while it is on.

**Strings.** `ui.dialogue.skip`, `ui.dialogue.hint` and `ui.dialogue.hint_auto` join the continue
hint, and `ui.settings.gameplay.dialogue_auto_advance` labels the row. A game with its own locale
column adds four rows.

---
## 5.13.1

*2026-09-29 — a test case that saves without `SaveFixture.activate()` now fails the suite, and
cannot reach the developer's saves while it does.*

**A consuming game does: nothing, unless one of YOUR cases saves or loads without
`SaveFixture.activate()`.** That case now fails rung 4 by name, `<case> used the save store without
SaveFixture.activate(): saved slot N in user://test_saves_unclaimed`. Add the call at the top of
its set-up. **PATCH, on the precedents `5.6.1` cites:** the case was already writing into, and
deleting from, your real `user://saves` while passing, so the gate names an existing defect rather
than imposing a new rule. `src/` and `tools/` are byte-identical. **If your game has its own
runner**, copy the `SaveFixture.park()` call and `_saves_were_claimed` from `tests/test_runner.gd`.

**What changed.** Before every case the runner parks the store in `user://test_saves_unclaimed`,
so no case starts on the shipped default. It then fails any case that saved, or loaded a real
file, while the store was parked or on the default. It hears this through `Events.game_saved` and
`game_loaded`, not by diffing a directory, which cannot see a write followed by a delete.
`save_dir_test.gd` now asserts the store starts parked. Three cases with `activate()` removed
each went red, and seven sentinel saves in the real directory survived every run.


---
## 5.13.0

*2026-09-29 — neither a debug launch nor the suite writes the developer's real settings any more.*

**A consuming game does: nothing to merge.** Your captures and your suite stop touching your
`user://settings.cfg` the moment this lands. **But know the new seam:** `Settings.file_path` is
where `save()` writes. It defaults to `Settings.PATH`, which keeps its name and value, and it is
still the file READ at boot, so a game that reads `Settings.PATH` changes nothing. In a debug
build, `DevSaves` points it at `user://dev_settings.cfg` under the same rule as the saves: any
user argument after `--`, with `--real-saves` opting out of both. The test runner points it at
`user://test_settings.cfg` before the first case, so a case YOUR game added needs nothing. If
your game writes settings from its own code, it goes through `Settings.save()` and is covered.
**MINOR**: a public var and two constants a game may ignore, the 5.10.0 precedent. A shipped
build is unaffected: `file_path` is only moved by a debug node and by the suite.

**What changed.** `Settings.PATH` was a `const` and the only path, so `--locale=`, which goes
through `Settings.set_value` on purpose, wrote the real file: a planted sentinel `locale="en"`
came back `"en_XA"` after one capture. Worse, a green suite run left the sentinel at ZERO BYTES,
because five cases call `Settings.reset_to_defaults()`. Now the redirect is **writes only**:
settings are loaded before any debug node exists, which is what a capture should show, and the
scratch file is never read back, so no launch inherits the last one's language. Measured: the
same sentinel survives the capture and the full suite byte-identical, where both overwrote it
on the unchanged tree. **Not changed:** on a machine with no settings file yet, boot still
writes the defaults to the real path, before anything can redirect it. That creates a file; it
overwrites nothing.

---
## 5.12.0

*2026-09-29 — a capture or debug launch no longer writes over the developer's real saves.*

**A consuming game does: nothing to merge.** Your debug launches stop touching your saves the
moment this lands. **But know the new rule:** in a debug build, a launch with ANY user argument
after `--` saves to `user://dev_saves`, never `user://saves`. A plain run from the editor passes
none and is unchanged. If you rely on a staged launch writing the real store, add `--real-saves`.
If your game adds its own debug node that saves during `_ready`, put it after `DevSaves` in
`game_root.tscn`. **MINOR**: it adds a class, `DevSaves`, and a flag a game may ignore, the T6.2
and T6.3 precedent. A shipped build is unaffected, because the node returns at once outside a
debug build, like every file in `src/systems/debug/`.

**What changed.** The ladder's capture rung runs `--new-game`, which starts a real run, so T5.10's
autosave wrote the real `autosave.json` on arrival and on quit. `--save-state`/`--load-state` and
`--cross-area-save` deleted the slot they used. Every writer goes through `SaveSystem.save_dir`,
so the new `src/systems/debug/dev_saves.gd` sets it once, before anything saves. It redirects
rather than suppressing the autosave, so a capture photographs the game a player gets, toast
included. Measured: a planted sentinel `autosave.json` was overwritten by one capture on the
unchanged tree, and survives it byte-identical now. `--autosave-continue` also stopped finding
the Continue row after the menu began naming the autosave, and is fixed. **Not changed:**
`--locale=` still writes the real `user://settings.cfg`.

---
## 5.11.1

*2026-09-29 — running the suite no longer destroys the developer's real saves.*

**A consuming game does: nothing to merge.** Your inherited cases stop touching your saves the
moment this lands. **But check any case YOUR game added:** if it calls `SaveSystem.save_to_slot`,
`delete_slot`, or drives anything that saves, give it `SaveFixture.activate()` at the start of its
set-up, or it will keep writing to, and deleting from, the real `user://saves` while passing.
**PATCH**: only `tests/unit/` and the documents changed. `src/`, `tools/` and every data shape are
byte-identical, so nothing a game wrote is affected. There is no "no version" option to take
instead: every entry here is a version, and `version_test.gd` ties the top one to `project.godot`.
`5.6.2`, documentation only, is the precedent for a PATCH where no game code moves.

**What changed.** T5.22 made the store redirectable and pointed two cases at the scratch store.
Fourteen more wrote or deleted real slots against the default `user://saves`, among them
`menus_test.gd` and `confirm_test.gd`, which clear every slot at set-up. Measured: seven sentinel
files planted in the real directory, one per slot plus the autosave, and a full green run deleted
all seven. Each of the fourteen now calls `SaveFixture.activate()` first, and all seven survive
unchanged. Fixing only the three cases first suspected still lost five of the seven.
`TESTING.md` states the rule.

---
## 5.11.0

*2026-09-29 — Bengali and CJK text renders from fonts the game ships, not from the player's OS.*

**A consuming game does: nothing, unless its own theme sets `default_font`.** In that case the
chain is not installed. Your font keeps working exactly as before, and it still needs its own
`fallbacks` for Bengali or CJK. **MINOR**: the base gained a resource, two fonts, a constant and a
public static method a game may ignore, and nothing that rendered before moved. Latin still draws
in the engine's own font, because the chain has no base font. It is not a PATCH, because a game
that changes nothing now ships **3.3 MB more** and draws Bengali and CJK where it drew boxes.
That is a new capability, not a fix to a promise the base had made.

**What changed.** `assets/fonts/font_chain.tres` is a `FontVariation` with no base font and
`fallbacks = [Noto Sans Bengali at weight 600, a Noto Sans SC subset at weight 600]`.
`UiRoot.install_font_chain(theme, path)` puts it into the project theme at boot, unless the theme
already has a `default_font` or the file is gone. **The theme itself names no font**, and that
was measured, not chosen: the project theme loads before the first import, so a font named there
is a `Parse Error` on every fresh clone (gotcha 81).

**Why it mattered when nothing looked broken.** On Windows, system font fallback drew Bengali and
Chinese from Nirmala UI and YaHei, so the developer's machine showed no tofu. With system fallback
off, which is a player's machine without those fonts, every glyph was a box. `ART_CONTRACT.md`
§ Fonts has the captures, the licences, and the recipe that cut the subset. **Hangul is not in
the subset.** A game shipping Korean adds a font to the chain.

**Found, and recorded as its own row rather than built:** `RestPoint` passes `{hours}` into a
single string, so a rest of 60 to 119 minutes reads "1 hours". That is the one count in the base
that needs a plural form (T6.14; numbered T6.10 when this shipped, renumbered as each earlier id was taken).

---
## 5.10.0

*2026-09-29 — losing window focus leaves nothing latched, and pausing on it is a setting.*

**A consuming game does: nothing, unless it added its own language column to
`localization/strings.csv`.** In that case, translate one new row,
`ui.settings.gameplay.pause_on_focus_loss`. The settings screen draws a row for every key in
`Settings.DEFAULTS`, so without a translation that row shows its key. **MINOR**: the base gained
a signal, a setting, and three public methods a game may ignore. No signal and no method changed
shape. The new setting is **off by default**, so a game that changes nothing does not start pausing.

**Three changes in behaviour, and each one is a fix.** On focus loss, a TOGGLED run stops,
while the toggle-run setting stays as the player set it. A hold-to-confirm part-way to firing
drops to zero. A rebind row waiting for a key stops waiting. The engine already releases held
keys on focus loss (measured windowed, see DEVLOG T6.5), so a held run or a held interact key
needed nothing from the base.

**One more, found by the first windowed run.** `UiRoot.open` now returns false, and leaves the
stack unchanged, when the engine refuses to add the screen. Before, the screen was recorded
anyway, so the world paused under a menu that was never drawn. It happens when a screen is opened
from inside an engine notification that is being propagated. A game that opens screens from its
own `_notification` handler should defer the call (gotcha 80).

**What changed.** `Events.focus_lost()` is emitted by `UiRoot` alone, deferred to the idle frame
after `NOTIFICATION_APPLICATION_FOCUS_OUT`. It is not emitted when one of the game's own windows
takes focus. `UiRoot.is_focus_loss(what)` and `UiRoot.announce_focus_lost()` are public so the
rule can be asserted without a window. `gameplay/pause_on_focus_loss` is read by `ScreenKeys`, and
`ScreenKeys.pause_for_focus_loss(stack)` opens the pause menu only where the pause key would work.
It never toggles, so losing focus twice does not close the menu. **A game with its own latch** — a
toggled crouch, a charged action — connects to `Events.focus_lost` and drops it.

---
## 5.9.0

*2026-09-29 — a save slot says where it was saved, and a damaged slot says it is damaged.*

**A consuming game does: nothing, unless it added its own language column to
`localization/strings.csv`.** In that case, put `{place}` into your translations of
`ui.save.slot` and `ui.save.autosave`, and translate three new rows: `ui.save.damaged`,
`ui.save.autosave_damaged` and `ui.save.place_unknown`. A translation without `{place}` still
works; it just never names the place. **MINOR**: the base gained a hook, a constant and a static
method a game may ignore. No signal and no method changed shape, and no save written before this
version stops loading — an old header simply has no place, and its row reads `Unknown place`.

**One change in behaviour, and it is the fix.** `SaveSystem.slot_info` now answers `{}` for a file
`load_from_slot` would refuse — a `version` of 0 or newer than `SCHEMA_VERSION` — and not only for
one that does not parse. Before, such a file drew a normal header and offered a load that failed,
and `latest_slot` could make it Continue. A game that read `slot_info` to show a file from a newer
build will now get nothing, which is the point: `has_slot` true with `slot_info` empty means
DAMAGED, and that is how `SaveScreen` draws it.

**What changed.** `SaveSystem.header_provider` is an optional Callable returning a Dictionary,
called on every write and stored in the file as `"header"`; `slot_info` hands it back. It is a
hook because the answer lives above `core`, which may not ask `Director`. `WorldMap` sets it, to
`{"area": <area id>}` under `WorldMap.HEADER_AREA`, and `WorldMap.place_key(header)` turns that
back into the area's `name_key` — "" for an area with no `AreaDef`. The ID is saved, not the name,
so a save written in one language reads in another. **A game wanting more in the header** sets
`header_provider` after `WorldMap` is ready, and includes `HEADER_AREA` itself if it wants the
place kept. The save screen now reads `Slot 1 · Rose Courtyard · … · 00:12 played`. A damaged slot
reads `Slot 3 · damaged`: a note when loading, and a row when saving that **counts as occupied**, so
writing over it asks first.

---
## 5.8.0

*2026-09-29 — a reusable confirm screen, and overwriting a save asks first.*

**A consuming game does: nothing, unless it added its own language column to
`localization/strings.csv`.** In that case, translate three new rows: `ui.save.overwrite` (the
question), `ui.confirm.yes` and `ui.confirm.no`. Without them, those three render as their keys.
**MINOR**: the base gained a class and three strings a game may ignore. Nothing a game wrote is
touched: no signal, no method and no data shape changed, and `SaveScreen` keeps every public name
it had. The one change in behaviour, the extra question before an overwrite, is the point of the
row. A game that asserted an occupied slot is written the moment it is pressed will now find a
`ConfirmScreen` on top instead, and must press its Yes row.

**What changed.** `ConfirmScreen.asking(question_key, detail, on_yes)` builds a yes-or-no
`MenuScreen`. `question_key` is the title, `detail` an already-translated line under it, and
`on_yes` a Callable run only on Yes. It sets `closes_on_cancel = false`, so **escape and the pause
key cannot answer it**, and focus lands on **No**, so a player mashing accept through a menu
loses nothing. Open one with `UiRoot.find(node).open(screen)`, or `push(screen)` from a
`MenuScreen`. The save screen is its first caller: pressing an occupied slot asks
`Overwrite this save?` under the header about to be lost, and an empty slot still saves at once.

**The quit half of "are you sure" was not built.** T5.10's quit-autosave already writes the autosave
slot on both quit paths, except when the player has turned autosave off or a transition is in
flight. A game that wants a "really quit?" reuses `ConfirmScreen.asking` from its own quit row.

---
## 5.7.0

*2026-09-28 — the base knows which input device is active, and the two prompts that name a button
follow it.*

**A consuming game does: nothing, unless it added its own language column to
`localization/strings.csv`.** In that case: put `{key}` into your translation of
`ui.dialogue.continue`, where the button belongs in your sentence, and translate the new row
`ui.prompt.button` (`[{key}]` in English — the brackets are layout, so a language may lay the
button out differently). A translation without `{key}` still works; it just never names the
button. **MINOR**: the base gained a signal, an enum, two methods and a class a game may ignore.

**What changed.** `Actions` now tracks the device the player last used — keyboard and mouse, or a
pad — and emits `Events.input_device_changed(device)` only when it changes. Read the current answer
with `Actions.device()`, and the words for an action with
`KeyBindings.text_for(action, Actions.device() == GameEnums.DeviceKind.GAMEPAD)`. The rule is the
pure `InputDevice.device_for(event, previous)`: a key, a click, a pad button or a stick past
`Actions.STICK_DEADZONE` is a switch; **mouse motion and stick drift are not**, so a bumped desk or
a pad on the sofa never flips the prompts. Unplugging the last pad falls back to the keyboard. No
autoload was added.

**Two consumers.** The interact prompt now names the button — `[E]  Barter  The Keeper's Basket`
where it used to say only `Barter  The Keeper's Basket` — and the dialogue hint says `E to continue`.
**Which fixes a defect: the hint used to say `Space to continue`, and Space advances nothing.**
Space was bound to `jump`, which T5.5 removed; the dialogue box has only ever listened for
`interact`. A game that asserted on the prompt's exact text will see the leading button.

**Hotplug is not proved by the suite**, because no pad exists headless: the handler is called
directly and the engine's own emission of `joy_connection_changed` is untested. Button ICONS are
not here either — `docs/ART_CONTRACT.md` § Button prompts says where a sheet will plug in.

---
## 5.6.3

*2026-09-28 — the save defect `5.6.2` recorded, proved red and then fixed.*

**A consuming game does: nothing, unless a player loads a save a NEWER build of your game wrote** —
in which case each section stored at a version above the one its participant registered now loads
at that participant's defaults, with a `Log.error` naming it, where before the newer payload was
handed to your applier as if current. The rest of the file still loads. That is the bug being fixed,
not a new restriction — `1.0.2`'s words, and its reasoning holds here: no game could have been
relying on a differently-shaped payload being misread, and every applier in the base ignored the
version it was given. **PATCH.**

**What changed.** `SaveSystem.load_from_slot` compares each section's stored `"v"` against the
version `register()` recorded, and refuses a newer one — the section-level twin of the envelope's
`Save is from a newer build` refusal, which already existed in `_migrate`. An OLDER section is
still handed to its applier with its stored version, which is how a section migrates.

**Proved before it was fixed.** On `5.6.2`, a section written at `"v": 3` for a probe registered at
v2 failed two assertions: `but its applier was never called — expected 0, got 1` and `so the probe
keeps its defaults — expected unset, got from the future`. With the guard those pass; with the
guard planted out they fail again, identically.

**If you change a section's shape**, this is now the whole procedure: register at the next
version and upgrade the older payload inside your applier. `tests/unit/save_recovery_test.gd`
holds the first worked migration in the suite — `old_key` renamed to `new_key` from v1 — and
[`UPGRADING.md`](UPGRADING.md) § 4 says how to copy it.

---
## 5.6.2

*2026-09-26 — Phase T6 planned. Documentation only: `src/`, `tools/` and `tests/` are byte-identical.*

**A consuming game does: nothing.** No code, scene, resource or setting changed. PATCH, on the table
above — *nothing a game wrote is affected* — and on the same precedent as `5.3.5` and `5.4.1`, both
documentation-only.

**Read this entry anyway if you build on the base's saves.** The planning sweep found a defect in
`SaveSystem.load_from_slot`, recorded here because it is present in every version up to and
including this one: a save section written by a **newer** build is handed to an older build's
applier with no refusal — the envelope refuses a newer schema version, but the section level has no
such guard — and every applier in the base ignores the version it is given. If your game ever loads
a save produced by a later build of itself (a player rolling back, a beta branch), that section is
applied as if it were current. **T6.1 fixes it.** Until then, do not rely on a downgrade path.

**What else changed in the record.** `ROADMAP.md` gains Phase T6 — player-facing robustness — with
eight planned rows and one mechanical exit criterion; `WORK_PACKAGES.md` gains their board rows and
file manifests. `CONTEXT.md` no longer lists time on the flag surface and the day cycle as open
(`5.5.0` and `5.6.0` built them), and three "Commonly forgotten" items in `SYSTEMS_INVENTORY.md` were
corrected: photo mode and credits closed as each game's own, and shader warm-up marked built — it
has been since T2.0.

---
## 5.6.1

*2026-09-10 — an audit of `5.6.0`, run because the base had just been declared finished. It found
that `5.6.0` had quietly made a documented invariant violable, plus three wrong numbers in the
documentation.*

**A consuming game does: nothing, unless it authored a schedule with no every-day entry** — in
which case `check_content` now fails and names the file, where before it passed and the NPC
silently stood still. That is the bug being reported, not a new restriction.

**PATCH, and three precedents in this file settle it rather than instinct.** The table above says
MAJOR means *a file the game wrote must change*, and a new gate that fails existing content looks
like exactly that. This project has been here three times and called it a PATCH every time:
`5.3.3` ("a checker you wrote and wired into only the full job… will now fail rung 4 where before
it passed silently"), `5.3.2` ("a package you logged and never named… will now fail rung 4 where
before it may have passed on a sibling"), and `1.0.2`, which states the governing reason —
**"That is the bug being fixed, not a new restriction: the case was never running."** A schedule
with no every-day entry is already an NPC with no instructions. The gate converts a silent defect
into a named build failure; it does not impose a rule the content previously satisfied.

### What was broken, and `5.6.0` broke it

`schedule_entry.gd` has always promised that **a day is always completely covered**, "because an
NPC is always somewhere", and before `5.6.0` that was structurally true: every entry applied on
every day, so the wrap-to-the-last-block fallback could never come up empty. `on_day_of_cycle` made
it violable by authored data for the first time, and nothing noticed. Measured with a throwaway
probe against `5.6.0`:

```
A: only day-specific entries, asked about a non-matching day
   hours with NO block on day 2: 24 of 24
   problems() reports: 0
```

So a schedule made only of day-specific entries answered **nothing at all** on any day it did not
name, `problems()` was silent, `check_content` passed, and `NpcBrain.decide_for_hour` — which
returns early on a null entry — left the NPC standing wherever it happened to be. That is precisely
the "reads as random" failure `schedule_entry.gd`'s own header exists to prevent.

**The fix is one rule: every schedule must carry at least one entry at `on_day_of_cycle = -1`.**
That is necessary *and* sufficient for total coverage — `_applies_on` admits an every-day entry
whatever day is asked, so the fallback is never empty and `entry_for_hour` never returns null. It
is also the strongest form of the rule the `content` layer can actually check: "every day of the
cycle is covered" would need `Clock.days_per_cycle`, and `content` may not touch an autoload.

**If you are on `5.6.0`, the hole is open and unreported.** Grep your schedules for one with no
`on_day_of_cycle = -1` entry; there is no gate on that version to do it for you.

### And three documentation numbers were wrong

| where | said | actually |
|---|---|---|
| `TESTING.md` opening | full `2302 passed`, stripped `2226 passed` | `2362` / `2288` |
| `NEW_GAME.md` § 7 | "all 930 assertions stay green" | number deleted — it carried no weight |
| T5.32's own record | `clock.gd`'s 3 spare lines were "the tightest any file has been" | `director.gd` has 3 too, and `dev_stage.gd` had 2 before T5.20 |

**The `TESTING.md` pair is the one with a lesson.** It went stale through two consecutive rows
because the closing checklist was read as "update `CLAUDE.md` and `ARCHITECTURE.md`", and it names
four files, not two. The stale pair even disagreed with the rest of the repository — their
difference was 76 while the board recorded a stripped gap of 74 for eight straight runs — and
nothing caught that either. The checklist now lists all four explicitly and says the stripped number
can only come from the CI job log, so that step finishes after CI rather than before.

---
## 5.6.0

*2026-09-10 — an NPC's day can differ from the day before it. A market day, or any weekly rhythm,
was not merely unauthored before this: it was inexpressible.*

**A consuming game does: nothing, to keep working.** One new flag appears, one new field appears on
`ScheduleEntry` with a default that means "every day", and one new optional argument appears on
`NpcSchedule.entry_for_hour`. **Every schedule `.tres` you have already written stays valid with no
edit**, and every call you have already written returns what it always returned. If you want a
weekly rhythm, read on; if you do not, merge and carry on.

**MINOR, and the table above is why.** *A file the game wrote must change* is the MAJOR test, and
nothing here forces that: `on_day_of_cycle` defaults to `-1`, which means every day, so an existing
entry that never mentions the field resolves exactly as before. The `on_day` argument defaults to
`-1` for the same reason, so an existing `entry_for_hour(hour)` call site still compiles and still
answers. This is the base gaining something a game may ignore — the MINOR row, exactly. It is the
same append-only discipline `GameEnums` runs on, and for the same reason: these numbers live inside
authored files.

**WHAT WAS BROKEN.** `ScheduleEntry` exported `from_hour` and nothing else, so an hour was an
entry's whole address, and `NpcSchedule.entry_for_hour(hour)` was the whole lookup. **Every NPC in
every game built on this base therefore repeated one identical day, forever.** There was no way to
author a stall that only appears on market day, a temple that is busy one day in seven, or a
character who takes one day off — not badly, but at all.

**WHAT YOU CAN NOW WRITE.** Two things, and they are independent — take either or both.

*In a schedule*, one extra entry beside the ordinary one:

| Field | Shape | Means |
|---|---|---|
| `on_day_of_cycle` | int, `-1` or `1`..`days_per_cycle` | `-1` (the default) is every day; a number is that one day |

A day-specific entry **beats** an every-day entry at the same hour, which is the whole authoring
gesture: you add a block, you never rewrite one. Every hour the special day says nothing about
still runs the ordinary blocks. Worked snippet in
[`AUTHORING.md`](AUTHORING.md) § Add an NPC → *1. A schedule, if it should move*.

*In any dialogue condition or quest step*, one new flag:

| flag | shape | the test to use |
|---|---|---|
| `time/day_of_cycle` | int, `1`..`days_per_cycle` | `EQUALS 3` is a market day; `AT_LEAST 5` is the back half of the cycle |

**IT IS AN INT, AND THAT IS THE ONE PLACE THIS ENTRY DEPARTS FROM 5.5.0 — DELIBERATELY.** 5.5.0
argues at length that a phase is a *name* and not a number, and none of that argument transfers
here, so do not carry it across. It rests on two properties of a phase: there is an enum behind it,
and a day wraps where an enum does not, so `AT_LEAST DUSK` holds at 00:00 and fails at 06:00. A day
of the cycle has neither property. It has no enum behind it to be inserted into, and it does not
wrap inside its own range — it runs `1` to `days_per_cycle` and stops. So `EQUALS` and `AT_LEAST`
both mean what you expect, and there is no `time/day_of_cycle/3` bool to go looking for. Declared
through `Flags.declare_derived` like the rest of `time/`, so **it never reaches a save file** and
recomputes from the clock's own saved day on load.

**SETTING THE CYCLE LENGTH.** `Clock.days_per_cycle` defaults to **7** and is an `@export`. Set it
from code at startup, exactly as you already set `seconds_per_minute` — these are exports on a
*script* autoload and Godot exposes no inspector for those. There is deliberately no setter that
republishes: `Director.start_new_game` emits `game_started`, which the clock's `_republish` is
connected to, so a value set before a game begins is published when it begins, and after that any
tick republishes within one in-game minute.

**TWO STATED COSTS, because both will reach you eventually and neither is a bug.**

1. **Nothing validates a day against the real cycle length.** An `on_day_of_cycle` of `9` on a
   seven-day cycle parses, loads, passes `check_content` and is simply a block that never runs.
   `NpcSchedule` and `ScheduleEntry` live in the `content` layer and may not touch an autoload, so
   no validator there can ask `Clock` how long the cycle is — `check_layers.gd` exists to refuse
   exactly that dependency. What *is* checked is a value below `-1`, which needs no autoload.
2. **There are no weekday names, months, seasons or a date type, and there will not be.** A cycle
   *length* is a number, so the base supplies it as a default with a seam; a *calendar* is your
   game's own. [ADR-0007](decisions/ADR-0007-template-default-vs-game-choice.md) draws that line,
   and this row is on the default side of it only because a formula is all it adds. "Market Day" on
   screen is a localization key your game maps from `time/day_of_cycle`, in your code root.

**One thing to know if you subclass or replace `NpcBrain`.** It now reads `Clock.day_of_cycle()`
itself and passes it into the lookup, rather than taking the day as a parameter. The hour stays a
parameter because a caller legitimately hypothesises about it — the suite drives a whole day,
`--npc-day` steps one — while *which day of the cycle it is* is a fact about the world that `Clock`
owns, and a second parameter would let two call sites disagree about the calendar.

---
## 5.5.0

*2026-09-10 — `Clock` and `Weather` reach the flag surface, so an authored condition can finally
ask what time it is. And a documented gotcha turned out to have a site nobody had fixed.*

**A consuming game does: nothing, to keep working.** Four new flags appear, none of them saved.
If you want to use them, read on; if you do not, merge and carry on.

**WHAT WAS BROKEN, AND IT WAS STRUCTURAL RATHER THAN MISSING.** `Clock` held the day, the hour and
the phase and emitted four signals, and never once called `Flags.set_flag`. `FlagQuery` is the ONE
evaluator that both `DialogueNode` and `QuestStep` go through, and it reads `Flags` and nothing
else. So **no authored condition in the base could mention time or weather at all** — including
the shop hours `clock.gd`'s own header names as a reason a clock is foundational.

**WHAT YOU CAN NOW WRITE**, on any dialogue node or quest step, with no code:

| flag | shape | the test to use |
|---|---|---|
| `time/hour` | int, 0–23 | `AT_LEAST 9` with `AT_MOST 17` is a shop's opening hours |
| `time/day` | int, from 1 | `AT_LEAST` to gate on the world having run a while |
| `time/phase/<name>` | bool, exactly one exists | `IS_TRUE` / `IS_FALSE` — `time/phase/dusk` |
| `weather/kind/<name>` | bool, exactly one exists | `IS_TRUE` / `IS_FALSE` — `weather/kind/rain` |

The `<name>` is the `GameEnums.DayPhase` / `GameEnums.WeatherKind` entry lowercased, so
`time/phase/deep_night` and `weather/kind/overcast`. All four are declared through
`Flags.declare_derived`, which means **they are never written to a save file** and are recomputed
from the clock's own saved state on load. Do not put your own flags under `time/` or `weather/`:
those namespaces belong to those two files, whole, and a flag of yours there would silently stop
being saved.

**WHY A PHASE IS A NAME AND NOT A NUMBER, because the obvious design is the wrong one and you may
be about to propose it.** `time/phase` holding the `GameEnums.DayPhase` ordinal, read with
`EQUALS`, was rejected on two measurements. First, ordinals are a storage format: `GameEnums` is
append-only *precisely because* its numbers live inside authored `.tscn` and `.tres` files, so
inserting a phase would silently re-point every authored condition at its neighbour, with no parse
error to announce it. Second, and sharper — **an ordering comparison on a phase is already
meaningless.** Run `phase_for_hour` across a day and the ordinals come out
`6,6,6,6,6,0,0,1,1,1,1,2,2,2,3,3,3,4,4,4,5,5,5,5`: `DEEP_NIGHT` is the highest number and the
earliest hours, because a day wraps and an enum does not. `AT_LEAST DUSK` would hold at 00:00 and
fail at 06:00.

**And publishing the plain string name would have been worse, silently.** A String flag is
unreadable by every test in the closed set: `FlagQuery.passes` against a flag holding `"DUSK"`
returns **false** for `EQUALS` and `IS_TRUE` alike, logging `expected int` / `expected bool`. It
would have shipped four flags that looked right in a debug dump and answered nothing. A bool under
the name is stable against an enum insertion *and* readable, with no seventh comparison added to a
set whose own file says it stays closed.

**THE ONE BEHAVIOUR CHANGE, AND IT IS A FIX.** `QuestTracker.ids_in_state` used
`Array[StringName].sort()`, which orders by the StringName's interned handle rather than
alphabetically — **gotcha 33, which `area_db.gd`, `equipment.gd` and `inventory.gd` each already
carried a note about and each already fixed.** This was the site nobody fixed, and its own comment
claimed "sorted, so the journal draws a stable order". It was not stable: it was the allocator's
order, and it changed the moment anything else interned a name earlier in the boot — which is
exactly how this row found it, when four new flag names shifted the table and a journal assertion
one system away went red. **So your journal now lists quests in genuinely alphabetical id order.**
If you had a test asserting the old sequence, it will differ, and the old sequence was never a
thing the base promised.

There is deliberately **no `time/minute`**, and no calendar, weekday, month or season — the latter
are game choices under [`ADR-0007`](decisions/ADR-0007-template-default-vs-game-choice.md).

---
## 5.4.1

*2026-09-10 — the extension surface was the one consumer document never performed. It has been
now, from a throwaway fork, and it cost six findings.*

**A consuming game does: nothing.** No file under `src/`, `tools/`, `tests/` or `.github/`
changed. This is documentation and `project.godot`'s `[template] base/version`.

**IF YOU ARE ABOUT TO SUBCLASS ANYTHING, READ `ARCHITECTURE.md` § The extension surface AGAIN —
the Tier 2 table now names every file.** Three of its rows named a class and gave no path while
the `Events` row gave one, so `UiScreen` was hunted in `src/ui/root/` (where `UiRoot` lives and it
does not) before a grep found `src/ui/screens/ui_screen.gd`. The table also now names the actual
override hooks: **`_build()`**, **`_opened()`**, **`_closed()`** — the header described all three
in prose and named none, and a first attempt guessed `_on_shown()`, which compiles and never runs.

**THE ONE THAT CHANGES HOW YOU PLAN: NONE OF THE SEVEN CHECKERS SCANS YOUR CODE.** A fork carrying
three Tier 2 subclasses passed all seven — **including over a planted raw player-facing string
literal and a planted public method with no caller**, which are exactly what `check_strings.gd` and
`check_methods.gd` exist to catch. They scan `src/`, `tests/` and `tools/`, not your root.

Two of those should stay blind and that is a relief, not a gap: **`check_boundary.gd` exists to
prove the ENGINE does not know your content exists**, and your own code is entitled to name your
own ids — pointing it at your root would fail you for doing the right thing. The rest are now a
**choice you make deliberately**: whether your game inherits the base's discipline or writes its
own. `TEMPLATE.md`, `NEW_GAME.md` and `UPGRADING.md` each gained a row for your code root, which
none of the three had.

**AND ONE THING TIER 2 DOES NOT GIVE YOU, NOW STATED RATHER THAN DISCOVERED.** You may declare
your own input action with `InputMap.add_action()` and bind it in your own code, but you **cannot
make it player-rebindable**: `KeyBindings.rebind()` refuses any action absent from the
`Actions.REBINDABLE` const, and the rebind screen builds its rows from that same const. That gate
is deliberate and has a bug behind it — until `2.5.0` it asked only `InputMap.has_action`, so
`debug_console` could be overridden into `input.cfg` and `reset_bindings()` would not restore the
default. So the closed list is the fix. Your action works; it is simply not offered on the
rebinding screen, and if you need it to be, that is a template change.

**Good news the performance also produced:** opening your own screen needs **no registration**.
`UiRoot.open()` takes an instance and `UiRoot.find(self)` locates the stack by group, so
`UiRoot.find(self).open(MyScreen.new())` is the whole of it. `ScreenKeys.menu_for()` is not
involved — it is a debug convenience for `--open-menu=`, and its only caller is boundary-exempt.

---
## 5.4.0

*2026-09-09 — the player prefab is a seam. It was a `const` in the `core` layer, so replacing the
protagonist meant editing `src/`.*

**A consuming game does: nothing, unless it wants its own player — and now it can have one.** This
is a MINOR: the base gained a seam a game may ignore. Merge it and carry on.

**WHAT YOU CAN NOW DO THAT YOU COULD NOT.** `[game] world/player_scene` in `project.godot` names
the scene `GameRoot` spawns once per session:

```ini
[game]
world/player_scene="res://scenes/characters/player.tscn"
```

Replace that value with the path to your own scene. (It is shown with the template's own prefab
because `docs_test.gd` asserts every `res://` path a document names actually resolves, so a
document cannot print an illustrative path that does not exist — a constraint worth knowing before
you write your own docs on this base.)

Point it at your own scene and **keep the template's prefab exactly where it is** — you are
pointing past it, not editing it, which is what `NEW_GAME.md` § 2 has always asked. Delete the key
and the template's prefab is used again: **it falls back**, unlike `world/first_area`, and the
asymmetry is deliberate — a template with no game in it yet legitimately starts in no area, but it
can never legitimately have no player, so an unset key must not mean an empty world.

**WHY THIS WAS A DEFECT AND NOT A MISSING FEATURE.** `src/core/boot/game_root.gd` held
`const PLAYER_SCENE := "res://scenes/characters/player.tscn"` — engine code, in the `core` layer,
naming the prefab a game replaces first. `ARCHITECTURE.md` states the contract as *"a game adds
content and resources; it does not add code under `src/`"*, so a game with a differently-shaped
protagonist had no legal way to get one. [`ADR-0007`](decisions/ADR-0007-template-default-vs-game-choice.md)
calls this shape a **template RULE wearing a template DEFAULT's clothes**, and its test — *does a
seam exist?* — is what found it, one row after the ADR was written.

**If your fork already worked around this by editing `game_root.gd`**, this is the merge to undo it
on: take the base's `src/core/boot/game_root.gd`, move your path into `[game] world/player_scene`,
and you are back on the upgrade path `UPGRADING.md` § 5 describes. That is the whole reason the key
exists rather than the const being left alone.

**`project.godot` is MIXED on a merge** (`UPGRADING.md` § 6), so expect to resolve this section by
hand — keep your `first_area`, `first_spawn` and `application/*`, and take the new
`world/player_scene` line.

**Nothing else changed.** `game_root.gd` is the same length it was (26 of its 60-line hard budget);
the path moved, no logic did. Suite 2,294 → **2,300** — three assertions in `core_test.gd` for the
seam and its fallback, and no new case.

---
## 5.3.5

*2026-09-09 — the distinction between a template default and a game choice, unscoped since
2026-08-26, is now an ADR; and two long-standing candidate rows are closed by it rather than built.*

**A consuming game does: nothing.** No file under `src/`, `tools/` or `.github/` changed. The only
production-side change is `project.godot`'s `[template] base/version`.

**THE ONE THING WORTH READING IF YOU FORKED THIS BASE:**
[`ADR-0007`](decisions/ADR-0007-template-default-vs-game-choice.md) classifies every choice this
base makes as one of **three** kinds, and the kind is now stated wherever the choice is recorded:

| Kind | A game… | Test |
|---|---|---|
| **TEMPLATE RULE** | cannot override it; wanting to is a fork of the template | no seam exists, and a checker enforces it where mechanical |
| **TEMPLATE DEFAULT** | replaces the value through a seam, touching no `src/` file | **a seam exists** |
| **GAME CHOICE** | builds it in its own code root, on the base's signals and flags | the base builds nothing |

**The test that separates a default from a rule is mechanical: does a seam exist?** A "default" you
cannot replace without editing `src/` is a rule that has not admitted it. Apply it to your own fork
— it is how this base found that `game_root.gd`'s hardcoded player scene is a rule pretending to be
a default.

**What is now stated, so you can plan against it:** no combat, the layer rule and the demo-name
boundary are **RULES**. Time is a **DEFAULT** — the base owns the hour, day and phase, and you
choose the numbers. **A chapter sequencer and an economy are GAME CHOICES: this base will not build
them.** A `story/chapter` integer flag with `AT_LEAST` is already a complete chapter model for both
authored condition surfaces, and currency is genre rather than structure — `Inventory`,
`Equipment` and `Interactable` are the seams you would build one on.

**Cutscenes are a GAME CHOICE, and the seam is already open** — which is why that row sat as the
only `TODO` with no stated reason. The nine `cutscene` mentions across eight files under `src/` are
**receipts, not IOUs**: *"deletes nothing here — it calls `Audio.duck()` from its own occasion"*,
*"forced by a cutscene, without touching this file"*, *"a cutscene can later ask for the same
fade"*. Sequence your own beats in your own code root on `Clock.set_time`,
`Events.screen_fade_requested`, `PlayerController.lock_input` and `UiScreen.pauses_world`. **The
base ships no sequencer and no cutscene resource** — a step enum would grow `GameEnums`, which is
append-only because ordinals live in `.tscn` files, for a shape every game authors differently.

**One documented test shape changed, and it is the opposite of what this document said.**
`docs/TESTING.md` used to give the fixture-root check as
`if not Fixtures.activate(): skip(...); return`. **It is now an assertion**, and if your fork
copied the skip shape, change it: a fixture root that cannot be written turns a skipped case into
a case that silently tests nothing, and a skip reports GREEN — so the one condition the check
exists to catch is the one condition nobody sees. `bag_mirror_test.gd` is converted; its plan moves
10 → 11. 14 of 16 call sites still discard the return, and that is recorded rather than implied.

**No new gate.** `record_shape_test.gd` and `docs_test.gd` already cover an ADR's structure, and
inventing a gate to have one is what T5.24–T5.27 spent four rows learning not to do.

---
## 5.3.4

*2026-09-09 — a checker can skip files and still print PASS, and six checkers could pass on a
scan of nothing.*

**A consuming game does: nothing to its own code.** No file under `src/` changed. What changed is
`.github/workflows/ladder.yml` and six of the seven `tools/check_*.gd`.

**IF YOUR FORK COPIED THE LADDER, TAKE THIS ONE.** Every checker step now captures its output to
`check_<name>.log`, prints it, and **fails the step if that log contains `SCRIPT ERROR` or
`Parse Error`** — even when the checker itself reported `PASS` and exited 0. The reason is
measured, not assumed:

```
SCRIPT ERROR: Out of bounds get index '9' (on base: 'Array[int]')
  loop finished, items processed: 2 of 3
PASS
exit=0
```

That is gotcha 24 — a GDScript runtime error aborts the **innermost frame only**. An error inside
a checker's per-file function returns to the loop, the loop finishes, and the tool reports success
having silently skipped a file. **The exit code cannot see it**; rung 4 has `ErrorWatch` for
exactly this and rungs 5–11 had no equivalent. The seven logs are now uploaded as artifacts from
both jobs.

**AND SIX CHECKERS NOW REFUSE A SCAN OF NOTHING.** Each counts the files its collector actually
opened and fails with `nothing was scanned, so this gate could only ever pass` at zero. Before
this, pointing `check_layers` at a directory containing no scripts printed `scripts scanned: 0`
followed by `PASS`, exit 0. `CHANGELOG.md` has stated the rule for doc gates since `4.3.1` — "a
doc gate that passes because it found nothing to check is worse than no gate" — and it had never
been applied to the tools.

**`check_content` is deliberately exempt, and this is the one thing to know if you strip your
game.** Its entire input is `data/` and `scenes/areas`, which the stripped-template job *deletes
on purpose*. Scanning nothing is a legitimate state for that checker and only for it, so guarding
it would fail the stripped job by design. The other six read `src/`, `tests/`, `tools/` and
`localization/`, none of which the strip touches, so zero there is always a defect.

**One comment in `ladder.yml` claimed a check that nothing performed** and now says what is
actually enforced. It read "a stripped template must report exactly the same numbers"; the two
jobs are independent and nothing compares their output. What *is* enforced — and it catches the
failure mode that matters — is that each checker must exit 0 in both jobs, so an engine string
that stops resolving once the game is gone fails rather than merely differing. A real cross-job
count comparison needs each job to publish counts and a third job to diff them; that is recorded
as a candidate row rather than implied by a comment.

**Suite 2,287 → 2,291**, both from this row's own DEVLOG entry passing through a computed plan. No
new assertions in the suite: this row's enforcement lives in the tools and the workflow.

---
## 5.3.3

*2026-09-09 — the case that checks the checkers are wired could not see a checker that was not
wired.*

**A consuming game does: nothing.** No file under `src/` or `tools/` changed, and neither did
`.github/workflows/ladder.yml`. The change is one test file plus `project.godot`'s
`[template] base/version`.

**IF YOUR FORK ADDED ITS OWN CHECKER, THIS IS THE ONE THING TO KNOW.**
`tests/unit/gates_test.gd` now derives the checker list from `tools/` instead of trusting its own
`LADDER` const, so **every `tools/check_*.gd` in your tree must be listed in `LADDER` and invoked
by `ladder.yml` in BOTH jobs.** A checker you wrote and wired into only the full job, or wrote and
never wired at all, will now fail rung 4 where before it passed silently. That is the assertion
doing the job its own header claimed: "a gate written, committed, and never wired."

**Two things it could not previously distinguish, both measured on this repository.** The wiring
check was `workflow.contains(checker)`, true of a workflow naming the checker in a **comment** —
and this workflow's comments name every checker deliberately, because they carry each rung's
reasoning. Commenting out both `run:` lines for `check_signals` left the suite **green at 2,276**.
And `contains` returns one bool for a whole file, so it could not express "in both jobs" at all.

**If your fork removed the stripped job or renamed either job**, the new assertions will name it:
`JOBS` is `["ladder", "stripped"]` and the job names are asserted, not assumed, so the expected
invocation count is not a magic number. Rename a job and you get a failure that says which.

**No behaviour changed anywhere else.** Suite 2,276 → **2,287**: eleven new assertions, all of them
in this one case — two job names, one per checker for its own-step count, and seven from the
directory scan. The plan is computed, so wiring an eighth checker does not mean editing a number.

---
## 5.3.2

*2026-09-09 — the gate T5.24 added could not fail for four of the ids it was checking, and the
numbers six documents quoted had drifted from the tree.*

**A consuming game does: nothing.** No file under `src/` or `tools/` changed. The only
production-side change is `project.godot`'s `[template] base/version`.

**THE ONE THING WORTH KNOWING BEFORE YOU MERGE, AND IT IS AGAIN ABOUT YOUR DOCS.**
`record_shape_test.gd`'s two findability checks were `board.contains(id)` and
`roadmap.contains(id)`, and `contains` cannot tell an id from a PREFIX of a longer one. In this
repository that made four assertions unfalsifiable: `T5.1` is a substring of `T5.10` through
`T5.19`, `T5.2` of `T5.20` through `T5.24`, `WP-09` of `WP-09b`, `WP-14` of `WP-14b`. Deleting
every genuine trace of those four packages left the suite GREEN, because a sibling's own row
spells the prefix. Both checks now match on a word boundary instead.

**If your fork numbers packages the way this one does, check the same shape.** Any id that is a
prefix of another id — `T1.1` beside `T1.10`, `WP-3` beside `WP-30` — was being checked by
accident and is now checked for real, so a package you logged and never named in `ROADMAP.md` or
`WORK_PACKAGES.md` will now fail rung 4 where before it may have passed on a sibling. That is the
gate doing the job `5.3.1` claimed it was already doing. The fix is a sentence, as it was then.

**No new assertion, and no changed plan.** The count moves 2,274 → 2,276 purely because this
row's own DEVLOG entry adds one package id and the plan is
`_docs.size() + _packages.size() * 2 + 2`. The two findability functions assert exactly what they
asserted before; they simply cannot be satisfied by the wrong string any more.

**And the record was reconciled against measurement rather than against itself.** `README.md`
claimed 555 assertions against 2,274 — off by roughly 1,700 and stale since before `2.0.0`;
`CLAUDE.md` described `DEVLOG.md` as "over 5,400 lines" against 8,986 and quoted 2,173 in its own
runner command; `docs/TESTING.md` and `docs/ARCHITECTURE.md` quoted totals from two and four
versions back; `docs/CONTEXT.md` said "the base is 5.0.0-complete" nine lines above declaring
**5.3.1**, said Phase T5's second-idle criterion "still stands open" fourteen lines above saying
the phase has no unticked criterion, and carried a repository census measured before `5.3.0`
added a file. Every replacement number in this row came off a run recorded in `DEVLOG.md`.

**The board's checklist item 6 is met for the T5.16–T5.24 run.** All nine packages now carry the
`**Commit:**` line the board has asked for since T4.3. It is NOT gated, and the reason is
measured: only 15 of 52 packages had one, so a gate would fail 37 historical rows, and scoping it
to "T5.16 onward" is the rotting exception list `HEADING_PATTERN`'s own header refuses to become.

**`docs/CONVENTIONS.md` gained a branch-naming rule**, which the project had never written down —
including the line the two misnamed branches in this repository actually need: the branch name is
not authoritative, the in-tree record is.

---
## 5.3.1

*2026-09-09 — the roadmap's completeness is now a gate rather than a habit, and the six packages
it was already missing are recorded.*

**A consuming game does: nothing.** No file under `src/` or `tools/` changed — `git diff` on both
trees is empty. The only production-side change is `project.godot`'s `[template] base/version`.

**The one thing worth knowing before you merge, and it is about YOUR docs, not ours.**
`tests/unit/record_shape_test.gd` gained one assertion per package the DEVLOG records: **every
such package must now be findable in `docs/ROADMAP.md`**, exactly as it has had to be findable in
`docs/WORK_PACKAGES.md` since `4.3.1`. If your fork keeps `docs/DEVLOG.md` and `docs/ROADMAP.md`
and writes its own package entries, the new assertion applies to them, and a package you logged
without ever naming it in the roadmap will fail rung 4. That is the gate doing its job, and the
fix is a sentence.

**FINDABLE, not "has a package-log row".** The check is `roadmap.contains(id)`, the same shape as
the board check, so any of the roadmap's three recording shapes satisfies it: a package-log row
under a phase, a tick beside an exit criterion, or a parenthesis in a phase's Done list. A
stricter rule would have failed packages in this very repository that are genuinely recorded —
T5.14 appears only beside the criterion it closed — and "recorded in the file a reader is sent to"
is the property that actually matters.

**If your fork DELETED `docs/`**, nothing changes: `record_shape_test.gd` has failed on its "the
log records packages to check" precondition since `4.3.1`, deliberately, and `docs_test.gd` and
`doc_counts_test.gd` have always behaved that way. A doc gate that passes because it found nothing
to check is worse than no gate. If you deleted the docs you have already dealt with this.

**Recorded, not built:** `ROADMAP.md` gained package-log rows for **T5.16, T5.17, T5.18, T5.19 and
T5.20** and a Phase 2 Done line for **WP-07**. Six delivered packages had a DEVLOG entry and a
board row and no trace in the roadmap at all. WP-07 — path actions, the signature non-combat
mechanic — had been missing since 2026-08-26 and was found by the gate rather than by the two
manual reconciles that preceded it, which is the argument for the gate stated as a measurement.

**Also recorded, and none of it reaches your code:** Phase T5's roadmap header now reads
**COMPLETE**, which `5.3.0` earned and did not take; gotchas **75 and 76** were added to
`CONTEXT.md`'s list — 75 having been named in a DEVLOG entry and never added — and the four
documents that quote the list's length moved from 74 to 76. If your fork keeps
that list and its own count claims, `doc_counts_test.gd` governs them exactly as before; nothing
about its rule changed.

---
## 5.3.0

*2026-09-09 — a sheet may now name a SECOND IDLE, and dwell time chooses when it plays. The last
Phase T5 exit criterion.*

**A consuming game does: nothing, unless it wants a fidget.** Both new fields default to the
value that means "no second idle" — `idle_break_row` to `-1` and `idle_break_after` to `0.0` — so
every sprite sheet authored before this version behaves exactly as it did, standing in one way
for as long as it stands. The default is `-1` rather than `0` for the reason T5.2 gave for the
gait rows: `0` is a real row, so a default of `0` would have silently drawn the IDLE block as a
break on every existing sheet, which is a change that looks like nothing.

**To add one, draw a block and name it.** No code, in this template or in your game:

    idle_break_row = 3        # the block, addressed by INDEX like every other row
    idle_break_after = 6.0    # seconds of UNBROKEN standing before it plays

The block plays once through and hands back to `idle_row`, and the clock restarts from the END of
the break — so `idle_break_after` is the gap a player actually sees between two fidgets, not that
gap minus however long the block takes.

**Naming one half and not the other is now a reported problem**, along with a break that points
at the idle block it is supposed to interrupt. `SpriteSheetLayout.problems()` gained three lines,
because a row with no delay and a delay with no row both look configured, are both in range, and
both draw exactly what the sheet drew before.

**THE ONE THING TO CHECK IF YOU KEPT THE SHIPPED PLACEHOLDER LAYOUT.**
`assets/placeholder/character_layout.tres` went from `animations = 3` to `4` and now names
`idle_break_row = 3`, and `assets/placeholder/character_placeholder.png` was regenerated 16 rows
tall to match. Both change together, so a game that kept BOTH needs to do nothing. A game that
kept the `.tres` while pointing it at art of its own will get a size mismatch reported by
`problems()` on the first frame — set `animations` back to your own block count and
`idle_break_row` to `-1`. This is why the bump is a MINOR and not a PATCH.

`character_alt_layout.tres` deliberately names NEITHER field, so the repository holds a sheet with
a break and a sheet without, and the `-1` default stays exercised on a layout that names all five
gaits.

**Also new:** `--idle-shots=<dir>` on `dev_gait_shots.gd`, which stands a character still and
samples the block it draws for eight seconds, photographing an early and a late cell of each
distinct block and reporting how far apart the crops are. Deleting `src/systems/debug/` still
does not break the game.

---
## 5.2.0

*2026-09-09 — the save store becomes redirectable, so the suite stops writing into the
developer's own save directory. One `const` became a `var`; the rest is tests.*

**A consuming game does: nothing.** `SaveSystem.SAVE_DIR` is gone, but nothing outside
`save_system.gd` ever referenced it — the search that preceded this change found six uses and all
six were in that file. If your game DID reference it, the replacement is `SaveSystem.save_dir`
and the shipped default is `SaveSystem.DEFAULT_SAVE_DIR`; that is the only rename in this
release, which is why it is a MINOR rather than a MAJOR.

**What was wrong.** `tests/framework/fixtures.gd` repoints five content roots under
`user://test_fixtures` so a run reads fixture content instead of the game's. The save store was
the sixth root and the only one left out, because its directory was a `const`. So
`save_recovery_test.gd` — which exists to write MALFORMED save files — and `core_test.gd`'s round
trip both wrote real slots into whatever `user://saves` resolves to on the machine running the
suite. Both delete what they write, which is not the same as never having written it: a case that
crashes between the write and the delete leaves the file behind, and the slot numbers the suite
picks are slot numbers a player may have filled.

**What a game gains, and it is why this is public rather than test-only.** `save_dir` is settable
at runtime and creates the directory when assigned, so a portable build that wants its saves
beside its executable is now one assignment rather than a fork of `save_system.gd`. A test-only
backdoor was the alternative and is the thing `fixtures.gd`'s own header refuses to add.

**New: `tests/framework/save_fixture.gd`**, with `activate()` / `deactivate()` / `is_active()` on
`Fixtures`' shape, emptying the scratch directory on the way in as well as out. `test_runner.gd`
calls `SaveFixture.deactivate()` after every case unconditionally, for the reason the existing
`Fixtures.deactivate()` call states: a case that crashed part way through would otherwise hand
the next one a redirected store.

**And `tests/unit/save_dir_test.gd` is new**, 18 assertions split by QUESTION from the two cases
either side of it — `core_test.gd` asks *does a good save survive*, `save_recovery_test.gd` asks
*what happens to a bad one*, and this asks *which directory did it go in*. A fork that changed
where saves live will go red here; that is the case doing its job.

---
## 5.1.0

*2026-09-09 — the sensor's SELECTION rule gets the scene-level test it has been asking for in
writing since WP-02, and that test found a defect in the tie-break on its first run.*

**A consuming game does: nothing, unless it has two interactables that overlap EXACTLY, in
which case which one gets the prompt may change — for the better.** `InteractionSensor` breaks
a scoring tie by node name, and `_select()` compared `a.name < b.name`. `Node.name` is a
`StringName`, and `<` on two of those compares their **interned addresses, not their text**, so
ties were ordered by whichever name the engine happened to intern first — script and scene load
order. Measured both ways in one run: for the same pair of names, the `StringName` comparison
said `Z_later < A_earlier` and the `String` comparison said the opposite. The fix is one cast,
`String(a.name) < String(b.name)`.

**What that changes for a game.** The documented rule now actually holds: naming two
overlapping objects `sign_a` and `sign_b` chooses between them, which it did not before. If your
game had two objects at an exact tie and relied on the old winner, it may swap — but it could not
have relied on it, because the old winner depended on intern order and could differ between a
fresh boot and the same objects reached another way. Nothing outside an exact tie is affected:
priority, then proximity, then facing all rank as they always did.

**`InteractionSensor` gained one public method, `cycle()`.** It is the Tab override extracted
from `_handle_input` so it can be called without a keypress, and it returns false when there is
only one candidate. A subclass that overrode nothing is unaffected. It exists because the suite
is synchronous and provably cannot press a key: `Input.parse_input_event` is buffered until a
main-loop flush that never comes mid-run, and `Input.action_press` does land but then leaves the
action reading `is_action_just_pressed() == true` for the whole run, which would cycle every
other case's sensor. The key binding itself is still proved windowed by `dev_stage.gd --cycle`.

**And `tests/unit/selection_test.gd` is new**, 24 assertions on the ranking, the candidate set,
the cycle and the two prefabs — `Readable` and `Speaker` — that `AUTHORING.md` tells you to place
and which nothing had asserted at all. If your fork changed the ranking, it may go red on merge;
that is the case doing its job. 2,148 → 2,173 — the extra assertion beyond the file's own 24 is
`record_shape_test.gd` computing its plan from what it finds, and it now finds one more package on
the board.

**If you are merging from `4.3.1` or earlier, read the `5.0.0` entry below as well** — this is a
MINOR, but it sits on top of a MAJOR whose one obligation still stands: add the `DevScreens` node
to `game_root.tscn`.

---
## 5.0.0

*2026-09-09 — `src/systems/debug/dev_stage.gd` was at 248 of its 250 allowed code lines, so the
five staging flags that push a SCREEN moved into a new sixth debug file, `dev_screens.gd`. No
behaviour changed; the same invocations produce the same logs, byte for byte.*

**A consuming game does ONE thing: add the `DevScreens` node to `game_root.tscn`.** That is the
whole obligation, and it is a MAJOR rather than a MINOR because skipping it does not cost you a
new feature — it silently REMOVES five flags you may already be using. `--open-inventory`,
`--talk=`, `--talk-advance=`, `--open-menu=` and `--console=` are parsed by the new node and by
nothing else, so without it every one of them is read by no `_parse_arguments` at all: no error,
no warning, and a capture that comes back looking like a game that was never asked to do
anything. Compare version 3.1.0, which added a debug file whose absence merely meant going
without something new.

The one-line replacement, immediately after the existing `DevStage` node:

```
[node name="DevScreens" type="Node" parent="."]
script = ExtResource("22_screens")
```

with its resource line beside the others in the header, and `load_steps` incremented by one:

```
[ext_resource type="Script" path="res://src/systems/debug/dev_screens.gd" id="22_screens"]
```

**The order matters and is not cosmetic.** `DevScreens` must sit AFTER `DevStage`, because these
flags draw over what that file poses — `--give` fills the bag that `--open-inventory` photographs.
Node order is `_ready` order, so putting it earlier lets a screen resume a frame before the state
it is meant to show. If your `game_root.tscn` has diverged and the merge conflicts, that is the
only constraint to preserve.

**If you subclassed or called into `dev_stage.gd`, five private methods are no longer there:**
`_open_inventory`, `_talk`, `_reveal_done`, `_console` and `_open_menu`, along with the
`_talk_advance` field. They are unchanged in `dev_screens.gd`. Nothing public moved, and
`SETTLE_FRAMES` still exists in both files.

**Everything else is internal.** `dev_stage.gd` is 248 → 175 code lines and `dev_screens.gd` is
102, so both have room again; `_parse_arguments` fell from 32 of its 40-line function budget to
22. `tests/unit/dev_tools_test.gd` gained a gate worth knowing about if you maintain your own
debug flags: **no two debug nodes may dispatch the same flag**, with `--new-game` the one stated
exception, because the failure mode of a split like this one is leaving the branch behind in both
parsers and dispatching twice. 2,143 → 2,148.

---

## 4.3.1

*2026-09-08 — twelve places where the record disagreed with the repository, and two gates so the
two structural ones cannot recur. **No production code changed**: this release is documentation
and tests.*

**A consuming game does: nothing.** No field, method, signal, scene or setting changed, and no
file a game wrote is affected. Everything here is either a document this base ships or a test
case that reads one.

**What was wrong.** `CONTEXT.md` — the file `CLAUDE.md` orders every session to read first — was
stating template version `2.4.0` two majors after the fact, still called `1.1.0` untagged, still
listed branch protection as unbuilt after T5.16 turned it on, and still carried a **"THE NEXT
PACKAGE"** paragraph describing work T5.2 had already shipped. `ARCHITECTURE.md` was 348
assertions behind and pointed at "rung 9" for a capture that is rung 12. `SYSTEMS_INVENTORY.md`
had T5.15's `Row styles` row stranded at line 1 ABOVE the document's own title, which was the
row's only copy — so the system was missing from its table. T5.17 had shipped with no row on the
board at all.

**What now stops two of them coming back.** `tests/unit/record_shape_test.gd` is new and owns
STRUCTURE, which is the part of a document that is not prose: every document must open with its
own title, and every package the log records must have a row on the board. `version_test.gd`
gained a third fact — a **bold** semver in `CONTEXT.md` is a claim about the current version and
must equal `project.godot`'s. **A fork that keeps this base's `docs/` gains all three checks, and
one that REWRITES those documents is fine** — every case is computed from what the scan finds
rather than from a list of expected files. **A fork that DELETES `docs/` outright will see
`record_shape_test.gd` go red on its "the log records packages to check" precondition**, which is
the same thing `docs_test.gd` and `doc_counts_test.gd` have always done in that situation: delete
the three cases together, or keep the documents. The precondition is deliberate — a doc gate that
silently passes because it found nothing to check is worse than no gate.

**What is deliberately NOT gated, and why.** The assertion count and the public-method count both
drifted too, and both were corrected by hand. Neither got a gate: a case cannot know the suite's
own final total while the suite is still running, and re-deriving the method count would duplicate
`check_methods.gd`'s scan inside a test. T5.17's *"nothing gates a prose claim"* stands for
sentences; structure and a bold version are the exceptions, and the counts need a checker rung
rather than a case.

---
## 4.3.0

*2026-09-07 — the save loader's refusals are asserted, and its migration path is documented as
structurally unreachable. **No production code changed**: `save_system.gd` is byte-identical.*

**A consuming game does: nothing, and should read one line.** The base gained a test case, which
is a gain a game may ignore — except in one situation worth naming. **If your fork modified
`SaveSystem`, `tests/unit/save_recovery_test.gd` may go red on merge.** That is the case doing
its job rather than a defect in your game: it asserts that a corrupt envelope is refused while a
corrupt SECTION is skipped, and a fork that made either one behave like the other has changed how
much of a player's save survives a bad file.

**What was unasserted.** `core_test.gd` owns the round trip and covered exactly one refusal — an
empty slot. Nothing in the suite had ever written a MALFORMED save file, so six branches were
carried by review alone: a file that is not JSON, a missing `version` field, a save from a newer
build, a non-Dictionary section, a section predating per-section versioning, and a section absent
altogether. All six are now asserted, and two were proved by planting a reversion.

**The migration mechanism is unreachable, and that is arithmetic.** `_migrate` is called only when
`version != SCHEMA_VERSION`, and it refuses `<= 0` and `> SCHEMA_VERSION`. At `SCHEMA_VERSION == 1`
no integer is all three of not-one, above-zero and at-most-one — so its success path, including its
`"Migrated save from v%d to v%d"` line, cannot be entered by any file. This is not a bug: there
genuinely are no migrations at v1, and the comment telling a future author where to add one is
correct. What was wrong was `SYSTEMS_INVENTORY.md` describing migration as DONE, which read as
"exercised" when it meant "written". That row now says so.

**And it expires by itself.** The new case pins `SCHEMA_VERSION` to 1. Ship a v2 schema and the
suite fails with *"SCHEMA_VERSION is still 1, so _migrate has no reachable success path"* — which
is the reminder to write the migration test at the moment one first becomes possible, rather than
a note in a document nobody rereads.

---

## 4.2.1

*2026-09-07 — a quest whose start condition is written by another quest's completion did not
reliably start. Whether it did depended on the order the content directory happened to be
scanned in, and nothing in the ladder could see it.*

**A consuming game does: nothing, and gains a guarantee it did not have.** No field, method or
signal changed, and no file a game wrote is affected. A game that authored a chain of quests was
already relying on this working; on the unlucky scan order it silently was not.

**The defect.** `QuestTracker.evaluate()` guards against re-entrancy, because a listener on
`Events.quest_completed` legitimately writes flags — beginning the next chapter is the case the
guard's own comment names. It guarded by RETURNING, which discards the re-derivation the new flag
asked for. That is only harmless if the pass already running still reaches the newly-startable
quest, and whether it does depends on where that quest sits in `QuestDb.all()` — insertion order
from `ContentScan`, which does not sort. So a chapter that begins when the previous one ends
started or did not start according to filenames.

**The fix.** A re-entrant call now sets a pending bit and the outer pass drains it, re-deriving
until nothing more moves. The pass bound is DERIVED from `QuestDb.count()` rather than picked, so
it cannot go stale as a game authors its sixtieth quest, and exceeding it logs an error rather
than hanging.

**Why no rung caught it, which is the part worth reading.** The demo has one quest, so it cannot
chain; and `quests_test.gd` states in its own header that it drives `evaluate()` and
`Flags.set_flag` directly *"rather than through the signal chain a running game uses"* — which is
correct for asking what a step means, and is exactly why it could not reach the guard, since a
re-entrant call can only arrive on `flag_changed`. `tests/unit/quest_chain_test.gd` is the case
that goes through the signal, and it asserts BOTH scan orders, because the benign one passed
while the defect was live and a case that tested only that would have looked like proof.

---


## 4.2.0

*2026-09-06 — the `Button` styleboxes, declared as a known limitation since T2.2 and left for
six packages. Every menu row, and every reply in a conversation, now draws all five of its
states from the palette instead of falling through to the engine's fallback StyleBox.*

**A consuming game does: nothing, unless it wants to.** Nothing was removed or renamed, no
export changed, and no method a game calls has a different signature. **A game that authored
its own `MenuRow/styles/normal` keeps it untouched** — `UiRowStyles` skips any variation that
already declares a `normal` box. **A game that replaced `ui_theme.tres` with a palette that has
no `surface` entry keeps exactly the behaviour it had at 4.1.0**, and gets one `WARN` line at
boot saying so. The one merge conflict to expect is `scenes/boot/game_root.tscn`, which gains a
`UiRowStyles` node under `UILayer`.

### What is new

| | |
|---|---|
| `UiPalette/colors/surface` | The face of a pressable row at rest, and the only colour the five states are derived from. The first palette entry that needed a SURFACE rather than a mark on one |
| `UiMetrics/constants/row_padding` | Side inset between a row's border and its text |
| `UiMetrics/constants/focus_border` | Width of the ring round the focused row |
| `src/ui/root/ui_row_styles.gd` | Derives `normal`, `hover`, `pressed`, `disabled` and `focus` — plus the `_mirrored` and `hover_pressed` spellings — and writes them into the project theme at boot. `UiAccessibility`'s sibling: that one owns the theme's font SIZES, this one owns its Button styles |
| `ui.menu.continue_autosave` | The main menu's Continue row said "Continue — Slot 7" when the latest save was the autosave. It says "Continue — Autosave" |

### Why nothing here is a colour this base picked

The four previous packages that opened this file and closed it again all gave the same reason: a
stylebox has to be *designed*, and the only palette to design against is the placeholder one, so
populating them would ship a decision as a default. **Nothing in `ui_row_styles.gd` designs a
colour. It designs the relationship between the five states**, and takes every colour from the
palette:

- `hover` is `surface` moved **toward `text`** — which lightens a dark row and darkens a light
  one, from the same expression. That is what makes the fix survive a palette this base does not
  ship, and it is the half of the defect ("immediately wrong against a light one") that a
  hard-coded lighten would not have touched.
- `pressed` moves toward `accent`, because a press is an act and wants a hue rather than a shade.
- `disabled` keeps the hue and drops the alpha, so a refused row is the same row faded.
- `focus` draws **no centre at all**, only an `accent` ring, so it composes with whichever of the
  other four is underneath rather than hiding it.

**To restyle: change `UiPalette/colors/surface` and the four other palette entries. Nothing
else.** To opt out entirely: delete the `UiRowStyles` node from `game_root.tscn`.

### If you are upgrading and you replaced the theme

Add one line to your palette and you get the whole set:

```
UiPalette/colors/surface = Color(<the face of a row at rest>)
```

Without it the row styles are skipped and your menus look exactly as they did at 4.1.0. This is
deliberate: there is nothing to derive from, and inventing a surface would be the base picking
a colour for you after all.

---

## 4.1.0

*2026-09-06 — a turn in place. `Events.turn_requested` is a new signal, and with it
`CharacterVisual.face_direction()` — correct, asserted and reached only from `tests/` since the
day it was written — finally has an occasion. The player turns towards what the prompt is
offering; the person you talk to turns towards you.*

**A consuming game does: nothing. Every character it already has gains the behaviour, and any
character it does not want turning simply never has a request addressed to it.** No export
changed, no scene changed, no method was removed or renamed, and nothing a game wrote has to
move. This is the MINOR case exactly.

### What is new

| | |
|---|---|
| `Events.turn_requested(character: Node3D, towards: Vector3)` | Ask a character to face a world point without moving it. Many askers by design, on `camera_shake_requested`'s shape |
| `CharacterVisual` | Listens, and answers only when the request names the character it draws — itself, or any ancestor of itself |
| `InteractionSensor` | Asks for the player, when a target is selected **while standing still**, or when the player comes to rest with one selected |
| `Speaker` | Asks for the character it hangs under, if there is one, towards whoever spoke. A speaker on a plaque asks for nothing |

### Two things worth knowing before you build on it

**A turn does not need undoing, and there is no hold flag anywhere.**
`update_from_velocity` re-aims only while the character is actually moving, so a turn given to
somebody standing simply persists until they walk — which is why an NPC is still looking at the
player when the dialogue box closes, at the cost of no listener at all. A turn given to a
character who is *moving* is overwritten on the next physics frame, and that is not a defect to
work around; it is why `InteractionSensor` asks only while the player is still.

**Your own askers need no new seam.** An NPC that notices the player, walks over and stops them —
the case neither shipped asker covers — emits the same signal and needs nothing added here. That
is the reason the seam was drawn at the bus rather than inside either call site.

### Also

`src/systems/debug/dev_gait_shots.gd` gained a `--turn-shots=<dir>` pass, which photographs a
character before and after a turn and reports the fraction of the crop's pixels that differ,
against a same-gap control shot with no turn asked for. Debug surface only; deleting that file
still does not break the game.

---

## 4.0.0

*2026-09-06 — the seventh checker, `tools/check_methods.gd`: a public method under `src/` that
nothing anywhere calls now fails the build. It found twelve on its first run, and two of them are
deleted in this version, which is what makes this a MAJOR bump rather than a PATCH for a tool.*

**A consuming game does: nothing, unless it called one of the two deleted methods — and then it
is a one-line edit each. After that, run rung 11 on your own tree and expect it to say
something.** The gate is asked of every public method under `src/`, and your `src/` is bigger
than this one.

### The two methods that are gone, and what to write instead

| Removed | Write instead | Why it went |
|---|---|---|
| `DialogueNode.has_choices()` | `not node.choices.is_empty()` | Two lines of alias over the expression both real readers already write — `DialogueRunner` and `DialogueScreen` each call `available_choices().is_empty()` and never went through it. `stop_music()`'s shape exactly, and the same verdict |
| `ItemDefinition.is_equippable()` | `Equipment.slot_of(item_id) != GameEnums.EquipSlot.NONE` | Its doc block claimed "an `Equipment` component and a UI row both ask this"; neither ever did. `Equipment.can_equip()` compares against NONE through `slot_of()`, which is strictly better, because `slot_of()` also answers NONE for an id with no definition at all |

**Neither had a caller anywhere in the repository — not in `src/`, not in the suite, not in the
tools.** If your game calls one, the replacement above is exact and behaviour is unchanged.

### The gate itself

**Rung 11, `godot --headless --script tools/check_methods.gd`, and it is in CI as its own step.**
It fails when a public method declared at column 0 under `src/` — 314 of them here — has its name
written nowhere else in the repository, on any non-comment line, in `.gd`, `.tscn` or `.tres`.

**The exemption is the phrase `NO CALLER` in the method's own `##` block**, which is
`check_signals.gd`'s `NO EMITTER` with the subject changed, and **a stale exemption fails too**: a
method that carries the phrase and has a caller is a violation in the other direction. Nine
methods carry it in this version and each one states its reason in the same breath — a log level
you can select but this template never writes at, the untyped `Flags` hatch for a type the typed
accessors cannot cover, three `PersistentState` fetchers kept as a complete typed family, a
`Readable`'s persisted read flag that a quest condition asks, and a `Footsteps` pair that a dust
puff would read.

**What it does NOT fail on, deliberately: a method reached only from `tests/` or `tools/`.** There
are 86 of those, and "has a caller in the suite" is genuinely not "has a caller in the game" — but
a template declares accessors for a consuming game to call and this repository never will, so
failing there would be answered with a fake caller. The count is printed on every run instead.

**It under-reports and cannot over-report.** A local variable or another class's method sharing a
name keeps a dead method looking alive; 37 names are declared in more than one file and are
treated as one. A green run is therefore not a proof that everything public is live. **A red run
is always real.**

**One precondition, checked rather than assumed:** no line in the repository both dispatches
(`call(`, `callv(`, `call_deferred(`, `Callable(`, `has_method(`) and builds a string. A name
assembled at runtime is the one form this gate cannot see, so if you introduce one, rung 11 fails
loudly instead of quietly reporting a green it cannot back. **If your game dispatches that way,
that is where you will meet this tool first** — either name the method in full at the call site,
or accept that the gate stops covering it and say so.

**Nothing else under `src/` changed** except one line in `NpcBrain.activity_name()`, which now
reads its own `current_activity()` accessor instead of the private field beside it. Same value,
one fewer place that knows how the enum is stored.

---

## 3.1.0

*2026-09-06 — a fifth debug file, `dev_scenario_shots.gd`, and the node in `game_root.tscn` that
lets it read the command line. Two features that had never been photographed happening in a real
session now have been: a screen shake fired by opening a gate, and an autosave written by
arriving somewhere and read back by pressing Continue in a fresh process.*

**A consuming game does: take the new `DevScenarioShots` node when it merges `game_root.tscn`.**
That is the whole obligation, and it is the only file outside `src/systems/debug/` that this
version touches. If your `game_root.tscn` has diverged and the merge conflicts, the node is three
lines and the file's other nineteen are unchanged:

```
[node name="DevScenarioShots" type="Node" parent="."]
script = ExtResource("20_scenario")
```

**Nothing under `src/` outside the debug directory changed, so nothing you wrote is affected.**
This is a MINOR bump rather than a PATCH for one reason: a node in a shared scene is something
you have to take, and a version that says PATCH is promising you do not.

**What you gained**, all of it gated on `OS.is_debug_build()` and absent from a release export:

| Flag | Does |
|---|---|
| `--gate-shot=<dir>` | throws a demo lever, opens the demo gate, and photographs the shake, writing `gate_closed.png` / `gate_shake.png` / `gate_open.png` and the camera's distance from rest in metres on every frame |
| `--autosave-write` | poses a state, travels, and lets `Events.area_entered` write the autosave |
| `--autosave-continue=<dir>` | in a FRESH process: boots to the main menu, photographs it, presses the real Continue row, and photographs where the game came back |

**`--gate-shot` names demo content and is meant to.** `src/systems/debug/` is the one directory
exempt from the boundary rule, and a fork that deletes the courtyard will find the flag logs
`found no node called 'GateLever'` and stops. Point it at your own lever and gate — two string
constants in the file — or delete the flag. `--autosave-write` names an area id for the same
reason and takes the same edit.

**Two assertions came with it and neither is about the debug surface's own behaviour.**
`Gate.perform()` is now asserted to ask for exactly the amplitude its author wrote and for
`Gate.SHAKE_SECONDS`, and to ask for NOTHING when `open_shake` is left at its default zero —
which T5.9 had left to a code read. And every script under `src/systems/debug/` that reads
`OS.get_cmdline_user_args()` is now asserted to have a node in `game_root.tscn`, because a debug
file with no node is not a broken tool but an absent one, and nothing anywhere goes red.

---

## 3.0.0

*2026-09-05 — the music ducks under dialogue, the duck is measured from the player's own volume
instead of from an absolute decibel, and `Audio.stop_music()` is deleted. The deletion is
the whole reason this is a MAJOR bump; everything else here is additive.*

**A consuming game does: `grep -rn 'stop_music' your_game/`.** If it returns nothing — and it
almost certainly does, because it returned nothing in this repository either, which is why the
method went — this version is additive for you and you can stop at the next paragraph. If it
returns something, **replace `Audio.stop_music(fade)` with `Audio.play_music(null, fade)`**, which
is the same operation and always was: `stop_music` was a two-line alias over exactly that call.
There is no other break in this version.

**The second thing to check, and it is a behaviour change rather than a compile error.**
`Audio.duck()` no longer moves the buses to the decibel you pass it — it moves them that far
BELOW wherever the player's own volume settings have put them. If you were calling `duck()` with
a hand-tuned absolute figure, that figure is now an offset and you want a small negative number
(the default is `Audio.DUCK_DB`, −8 dB). Nothing warns you, because both readings are
valid floats. The old behaviour was a defect and not a choice: against a player who had turned
music down to 0.25 linear (−12 dB), a "duck" to −8 dB made the music four decibels LOUDER every
time somebody spoke, and against the default it ducked by eight. One call, opposite effects,
chosen by a slider on the options screen.

**What you gained**, none of which needs an edit under `src/`:

| Thing | Where | Default |
|---|---|---|
| `DialogueDuck` | the `DialogueDuck` node in `game_root.tscn` | on |
| `Audio.target_db(bus)` | anywhere | — |
| `Audio.DUCK_DB` / `DUCK_SECONDS` / `RESTORE_SECONDS` / `DUCKED_BUSES` | anywhere | −8 dB / 0.4 s / 0.6 s / Music + Ambience |
| `TestCase.parent_of_script(scene, script)` | any test case | — |

**The music now ducks while anybody is talking, and comes back when the last one stops.** The
occasion is `Events.dialogue_started` and `dialogue_finished`, which have been on the bus since
Phase 0 with one emitter each — **no signal was added**, and no new setting either. The buses it
moves are Music and Ambience; SFX and UI are deliberately untouched, since ducking exists so that
those can be heard. If your game wants ducking somewhere else — a cutscene, a codec call, a boss
door — call `Audio.duck()` and `Audio.unduck()` from your own occasion, or add a node beside
`DialogueDuck`; if it wants no ducking under dialogue at all, delete that one node from
`game_root.tscn` and nothing else changes.

**A duck holds while ANY conversation is running, counted.** Two overlapping conversations mean
two holds, and the music comes up after the second ends rather than the first. `DialogueDuck.held()`
is the count.

**A volume slider moved mid-duck no longer lifts the duck.** `_apply_all_volumes` re-applies every
bus on any `audio/*` change and now goes through `target_db`, so the slider lands on the ducked
level and the duck survives it. A bus the player has muted stays muted while ducked: nothing may
raise a level set to zero.

**If you subclassed or copied `tests/framework/test_case.gd`,** it gained one method,
`parent_of_script(scene_path, script_path)` — the `SceneState` walk that asks whether a scene
really carries a node with a given script. It moved out of `settings_consumers_test.gd` on its
second caller. A game that copied that private helper into its own case can keep it; nothing
forces the change.

---
## 2.5.0

*2026-09-05 — the base autosaves, and `gameplay/autosave` is back in `Settings.DEFAULTS` as the
player's veto over it. It is the second of the three settings version 2.0.0 removed to come back
with the feature it was waiting for; only `accessibility/subtitles` is still out.*

**A consuming game does:** nothing, unless one grep says otherwise. **No save file already on
disk changes meaning, and the format is untouched** — `SCHEMA_VERSION` is still 1, slots 0..5
still hold what they held and still carry the numbers your players know. That is why this is a
MINOR bump and not a MAJOR one, and it was the deciding factor in the slot design below.

**`grep -rn 'gameplay/autosave' your_game/`.** If it returns nothing, this version is additive
for you and you can stop here. If it returns something, you re-added the key yourself after 2.0.0
removed it — which that entry explicitly invited — and you now have **two declarations of the
same key** in a merged `settings.gd`. Keep the base's and delete yours: it is the same key with
the same boolean meaning and the same row in `settings_screen.gd`, and `Autosave.AUTOSAVE_SETTING`
is now the const that names it. If your own consumer wrote into a slot of its own choosing, that
consumer is the thing to delete, and it is yours — see the slot warning below before you do.

**What you gained**, all of it opt-in except the two occasions:

| Thing | Where | Default |
|---|---|---|
| `SaveSystem.AUTOSAVE_SLOT` | one past the six manual slots | 6 |
| `SaveSystem.AUTOSAVE_FILE` | `user://saves/autosave.json` | — |
| `SaveSystem.is_autosave(slot)` | anywhere | — |
| `Autosave.request()` | the `Autosave` node in `game_root.tscn` | — |
| `gameplay/autosave` | the options screen | **true** |
| `notify.autosaved`, `ui.save.autosave`, `ui.save.autosave_empty` | `localization/strings.csv` | — |

**THE ONE THING TO READ IF YOU ALREADY WROTE AN AUTOSAVE OF YOUR OWN.** The base's autosave slot
is `MAX_SLOTS`, i.e. **one past** the six the save screen offers, stored under a NAME rather than
a number. It was placed there and not at slot 5 precisely so that no save any player already has
changes meaning. If your own autosave reserved one of the manual slots, you now have two autosave
mechanisms and one of them can overwrite a save your player made on purpose — delete yours and
call `Autosave.request()`, or keep yours and set `gameplay/autosave` to false in your defaults.
Do not do both.

**Two occasions fire automatically, and both are refusable.** The base autosaves when the
application is ending (`Events.game_ending`, so the window's close button is covered too) and one
frame after arriving in a new area (`Events.area_entered`). Your own occasions — a chapter break,
a bed slept in — are one call to `request()` on the node, with no edit to `src/`. Every occasion,
yours included, is refused when the player has turned the setting off, when `Director` is
mid-transition, and when there is no run in progress at all.

**`SaveSystem.latest_slot()` now sees the autosave slot**, which is the one behaviour change to a
method you may already call: Continue resumes the autosave when it is the most recent save. The
save screen's writing half still counts to `MAX_SLOTS` and therefore still cannot name the
autosave; its reading half now lists it as a row of its own. If you subclassed `SaveScreen` or
wrote your own slot list, check which range you iterate: `MAX_SLOTS` is the manual range and
`AUTOSAVE_SLOT + 1` is everything.

**A save is a FILE, so this row is proved in the suite rather than in a photograph** — 50 new
assertions, including that six manual writes leave the autosave byte-identical. What the windowed
capture adds is the indicator: `notify.autosaved` on the toast that already existed, which is what
`SYSTEMS_INVENTORY.md` item 6 has asked for since WP-00. On the quit path that toast is emitted
and never seen, because the window is gone the same frame, and that is recorded rather than
special-cased.

## 2.4.0

*2026-09-05 — the base has a screen shake, and `gameplay/camera_shake` is back in
`Settings.DEFAULTS` as its scale. It is the first of the three settings version 2.0.0 removed to
come back with the feature it was waiting for, which is what removing them was for.*

**A consuming game does:** nothing, unless one grep says otherwise.

**`grep -rn 'gameplay/camera_shake' your_game/`.** If it returns nothing, this version is
additive for you and you can stop here. If it returns something, you had re-added the key
yourself after 2.0.0 removed it — which that entry explicitly invited — and you now have **two
declarations of the same key** in a merged `settings.gd`. Keep the base's and delete yours: it is
the same key with the same 0..1 meaning and the same `[0.0, 1.0, 0.1]` row in
`settings_screen.gd`, and `HD2DCameraRig.SHAKE_SETTING` is now the const that names it. If your
own consumer read it as something other than a 0..1 scale — a boolean, say — that consumer is the
thing to change, and it is yours.

**What you gained**, all of it opt-in:

| Thing | Where | Default |
|---|---|---|
| `HD2DCameraRig.shake(strength, seconds)` | the rig in your area scene | — |
| `Events.camera_shake_requested(strength, seconds)` | the bus, ask from anywhere | — |
| `shake_metres`, `shake_hz` on the rig | your area scene | 0.35 m, 18 Hz |
| `Gate.open_shake` | per gate | **0.0 — silent** |
| `gameplay/camera_shake` | the options screen | 1.0 |

**Nothing in your game shakes until you ask it to.** `Gate.open_shake` defaults to zero, so every
gate you have already authored opens exactly as silently as it did before; the base's own demo
courtyard sets `0.7` on its north gate and that is authoring in a `.tscn`, not a behaviour change
in `src/`. The two new exports on the rig have defaults, so an area scene you wrote before this
version loads unchanged and its rig shakes 0.35 m when something asks.

**The amplitude is the AREA AUTHOR'S and the setting is the PLAYER'S VETO**, which is the same
contract `video/depth_of_field` and `accessibility/reduce_motion` already have on this rig. The
setting is a 0..1 scale on `shake_metres` and cannot exceed it, so **a rig you authored at
`shake_metres = 0.0` never shakes, whoever asks and whatever the player prefers.**
`accessibility/reduce_motion` removes it outright rather than making it smaller — a smaller shake
is still a shake — so that setting now reaches four motions instead of three, which T5.7 recorded
as its own gap the day it shipped.

**No autoload, no ADR, no save version, no layer change.** One signal was ADDED to the registry
and none removed or altered, so nothing you connected has changed shape. `settings_screen.gd`,
`menu_screen.gd` and the theme resource were not touched: the screen is generated from `DEFAULTS`
and already carried the range row for this key, which is the seam claim from 2.0.0 tested
literally rather than repeated.

---

## 2.3.0

*2026-09-05 — both placeholder character sheets now draw a different figure for every facing.
They drew one pose repeated across every column, so the base's facing system was invisible on
screen for five phases while being correct and asserted the whole time.*

**A consuming game does:** almost certainly nothing. One grep decides it:

**`grep -rn 'character_placeholder\|character_alt' your_game/`.** If it returns nothing, stop
here — this version cannot reach you. If it returns something, you are drawing characters from
the base's placeholder art, and **those two PNGs now look different**. Nothing about their SHAPE
changed — `character_placeholder.png` is still 256x576 with 8 facings × 4 frames × 3 blocks and
`character_alt.png` is still 96x600 with 4 × 3 × 5, and **neither `.tres` layout changed at all**
— so nothing you wrote has to change and no code path behaves differently. What changed is the
pixels inside the cells: a facing now reads as front, three-quarter, side or back, with a profile
showing one eye and a nose and a back view showing no face. That is a visible change to your
characters and you should see it before your players do.

**Why this was worth a version.** Measured over the figure band, the old sheet's back view
differed from its front by **0.7%** of a cell — the two eyes and nothing else — and facings 2 and
3 were byte-identical. Three of the four-facing sheet's columns differed only by their column
tally. So a character walking east and a character walking west drew the same picture, and an
owner playing the game reported that sideways movement "just slides to the side". Nothing in
`src/` was wrong and nothing in `src/` changed.

**Added, and safe to ignore:** `--facing-shots=<dir>` on the existing
`src/systems/debug/dev_gait_shots.gd`, which walks a character north, east, south and west and
photographs each with the sheet column decoded out of `sprite.frame`. Same debug gating as the
rest. `tests/unit/sheet_facings_test.gd` is new: it requires every facing of a shipped sheet to
differ from every other by more than 5% of the cell, and asserts only the base's own placeholder
art, so it survives the demo strip. **If you ship your own sheets and add them to that case, note
that it measures the FIGURE and ignores four columns down each edge** — the alt sheet's pip
tallies live there and are deliberately not mirrored.

Nothing else in this version can reach a game. No file under `src/` changed except the debug
capture tool; no signal, enum value, setting, autoload, save version or layer moved.

---

## 2.2.0

*2026-09-05 — `accessibility/reduce_motion` reaches all three motions the base draws instead of
one, and the shadow atlas is restored to the size your `project.godot` authored instead of to a
constant that was wrong.*

**A consuming game does:** nothing, and there is nothing to grep for. Both changes are inside
files the base owns, and both make an existing setting do what its label already promised. But two
of them are VISIBLE, so see them before your players do.

**`accessibility/reduce_motion` now zeroes `HD2DCameraRig.follow_lag` and cuts `ScreenFade`.** It
previously reached only the dialogue typewriter. If your game ships rigs with a smoothed follow —
the base's default is `0.10` — a player with reduce-motion ON will now get a camera locked to the
character instead of one that slides after it, and area transitions will cut to black instead of
dissolving. **Your authored `follow_lag` is remembered and restored** when the setting goes off, on
the same `_authored_dof` pattern `video/depth_of_field` has used since 2.0.0: the setting is the
player's VETO over what your area author chose, never a replacement for it, and a rig you shipped
at `follow_lag = 0.0` stays rigid however the setting moves. Nothing to change in your area scenes.

**`video/shadows` no longer replaces your shadow atlas size with 2048.** This one is a fix to a
defect that was live in the base, and if you authored
`rendering/lights_and_shadows/positional_shadow/atlas_size` or `.../directional_shadow/size` in
your `project.godot`, **the base was silently discarding it at boot.** `Settings._apply_shadows`
restored a `const POSITIONAL_ATLAS: int = 2048` described as "the engine's own default"; the
engine's default is **4096**. Measured on the base itself: it booted every windowed session at
`2048` and now boots at `4096`. The new `ShadowAtlas` (`src/core/state/shadow_atlas.gd`) reads
both sizes back before the first zeroing and restores those, so whatever you authored is what you
get. **If your game looked correct to you before this version, your shadows may now be sharper and
slightly more expensive than you tuned for** — that is the authored value arriving, not a
regression, and you can set the two project settings to 2048 to get the old picture back
deliberately.

Nothing else in this version can reach a game. `settings.gd` came down from 144 to 139 code lines
and gained no new key; no setting was added or removed, so `settings_screen.gd` draws the same
twenty rows; no signal, enum value or autoload changed. `tests/unit/settings_consumers_test.gd`
split at its budget and `tests/unit/settings_effects_test.gd` is the new half — a test-only change,
but worth knowing if you carry local edits to that file.

---

## 2.1.0

*2026-09-05 — the second placeholder sheet gained a complete gait set, so the wholesale character
swap the base promises can be performed and photographed rather than described.*

**A consuming game does:** almost certainly nothing. One grep is worth running:

**`grep -rn 'character_alt' your_game/`.** If it returns nothing, stop here — this version is
purely additive to you. If it returns something, you are using the base's *swap demonstration
asset* as real art, and it changed shape: `character_alt.png` went from **96x240** (2 animation
blocks) to **96x600** (5), and `character_alt_layout.tres` now declares `animations = 5` with
`run_row = 2`, `sneak_row = 3` and `climb_row = 4` where it previously left all three at `-1`. The
two are committed together and `character_swap_test.gd` asserts they agree, so taking both is
safe and taking one is not. A character pointed at that pair will start drawing a distinct run,
sneak and climb cycle instead of replaying its walk block — which is the improvement, but it is a
visible change and you should see it before your players do.

Nothing else in this version can reach a game. No file under `src/` changed for the swap itself —
that was the point of the row, and it is what a fork inherits: your own sheets, your own layouts,
no code. `SpriteSheetLayout`, `CharacterVisual` and `PlayerController` are byte-identical to
2.0.0. No signal, no autoload, no setting, no save version, no layer.

**Added, and safe to ignore:** `src/systems/debug/dev_gait_shots.gd` and its `--gait-shots=<dir>`
flag, which drives a character through all five gaits and photographs each one with the block
decoded out of `sprite.frame`. Debug surface, gated on `OS.is_debug_build()` like the other three,
and deleting it cannot break a game. `tests/unit/character_swap_test.gd` is new and asserts only
the base's own placeholder sheet, so it survives the demo strip.

---

## 2.0.0

*2026-09-05 — every setting the options screen draws is now read by something. Nine were wired to
a consumer; three were removed, and `Actions.JUMP` went with them.*

**A consuming game does:** two things, and both are greppable.

1. **`grep -rn 'Actions.JUMP' your_src/`.** If it returns anything, that line will no longer parse:
   the const is gone. There was never anything in the base polling it, so a game that used it wrote
   the poller itself and knows where it is. Declare your own action if you need one — that is one
   `_define` call in your own `Actions` subclass or one line in `project.godot`.
2. **`grep -rn 'gameplay/autosave\|gameplay/camera_shake\|accessibility/subtitles' your_src/`.**
   Those three keys are gone from `Settings.DEFAULTS`, so `get_bool` on one now logs
   *"Unknown setting"* and returns `false`, and `set_value` refuses. If you had built a consumer
   for one of them, re-add the key: one line in `DEFAULTS` and one row in
   `localization/strings.csv`, and the settings screen picks it up with no edit, because it is
   generated from `DEFAULTS`.

Everything else in this version is additive. Nine settings that previously did nothing now do
something — if you had been shipping them to players as inert rows, they will start working, which
is the change and the point. No signal was added or removed, no autoload, no save version, no
layer. `settings_screen.gd`, `menu_screen.gd` and the theme resource were not touched.

**Why this is MAJOR for a change that only deleted four public names.** This file's own table says
MAJOR means *a file the game wrote must change*, and both greps above can require exactly that.
The first fails at parse time, which is the good kind; the second fails at runtime with a logged
error and a `false`, which is the kind worth a version number.

**What was wrong.** **Twelve of twenty-three settings had no consumer.** All twelve were declared
in `settings.gd`, drawn to the player by `settings_screen.gd`, translated in both languages, and
inert. Four were video settings, three gameplay, and five were the whole of `accessibility/*` —
and those five were the sharpest, because **a game forked from this base could not wire them
without editing `src/`.** The thing a text-size preference has to change is the project theme, and
every screen that draws from it lives under `src/ui/`. That makes it a defect in the TEMPLATE
rather than a missing feature of a game, which is the distinction this whole repository turns on.

**What each of the nine reaches now**, and the placements are the interesting part because two
identical-looking settings went to opposite places:

| Setting | Consumer |
|---|---|
| `video/resolution_scale` | `Settings._apply_render_scale` — `scaling_3d_scale` is the viewport's and no system owns the viewport |
| `video/shadows` | `Settings._apply_shadows` — the shadow ATLAS, so every light an area author placed obeys it |
| `video/bloom` | `EnvironmentDriver` — the `Environment` is that node's and nothing else may touch it |
| `video/depth_of_field` | `HD2DCameraRig` — `set_dof_enabled()` finally has a caller |
| `gameplay/show_interact_hints` | `InteractPrompt` |
| `accessibility/text_scale` | new `UiAccessibility`, under `UILayer` in `game_root.tscn` |
| `accessibility/high_contrast_prompts` | `InteractPrompt` — a 4px outline, a value picked by photograph |
| `accessibility/reduce_motion` | `DialogueScreen` — the typewriter reveal arrives whole |
| `accessibility/hold_to_confirm` | `InteractionSensor` — a 0.4s floor under `Interactable.hold_seconds` |

`video/bloom` and `video/shadows` look like the same kind of setting and are not. Bloom is one
property of one `Environment` that one node owns, so it went to that node. Shadows are cast by
**lights an area author placed** — the demo courtyard has four — and no node owns the set of them,
so a driver enumerating lights would be wrong for every light added after it was written. Applying
it at the atlas instead means **a game that adds a hundred lights gets the setting for free and
writes no code.** If you author a different `positional_shadow_atlas_size` in `project.godot`, note
that toggling this setting restores the base's `2048` rather than your value — recorded as a gap.

**Three settings removed rather than wired**, because honouring them would have meant inventing a
feature inside a row about connecting existing ones: there is no screen shake anywhere under
`src/`, there is no autosave and `SaveSystem` has no notion of the slot a run belongs to, and
nothing is voiced. **A row drawn to the player that cannot do anything is worse than a dead
constant, because the player is the one who finds out.** The reason each was removed is written in
the `DEFAULTS` block, where the next person to consider re-adding one will be standing.

**Four defects fixed alongside**, each one line to a few:
`Settings.reset_to_defaults()` never called `_apply_locale()`, so Reset wrote `locale = "en"` and
left the UI in the old language · `set_dof_enabled()` had no caller · `Actions.JUMP` was offered as
a rebinding row for a verb `player_controller.gd` says three times over this template does not have
· `KeyBindings.rebind()` gated on `InputMap.has_action` rather than `Actions.REBINDABLE`, so
`debug_console` could be overridden into `input.cfg` and then never reset, because
`reset_bindings()` re-declares only the rebindable groups.

**And the question the six checkers cannot ask is now asked, as an assertion rather than a seventh
checker.** A setting is a string key read through `DictRead` — not a `class_name`, a `signal` or a
CSV row — so none of T5.4's three gates can see it. `tests/unit/settings_consumers_test.gd` loops
over `Settings.DEFAULTS` as the engine loaded it and requires every key to be consumed. It went to
the suite rather than to `tools/` because that dictionary is available at runtime and a `check_*`
tool would have to parse `settings.gd` to reconstruct it. **If you add a setting to a fork and
nothing reads it, rung 4 goes red and names the key.**

---

## 1.2.0

*2026-09-04 — an animation block per GAIT, so a character's movement styles come from its sheet
rather than from its code.*

**A consuming game does:** nothing, unless it wants the new gaits. Every existing
`SpriteSheetLayout` keeps drawing exactly what it drew — `run_row`, `sneak_row` and `climb_row`
default to `-1`, which means "replay the walk block", and that is precisely what run and sneak did
before this version. To add a run cycle: draw the block, set `animations`, name `run_row`. No code,
in your project or in the base. **If you replaced `character_placeholder.png`** with your own
sheet, nothing changes for you; if you were using the shipped one, it is now 256×576 with three
blocks instead of 256×192 with one, and its layout names `walk_row = 1` and `run_row = 2`.

**`animation_for` took a BOOLEAN, so a sheet could only ever hold an idle cycle and a walk
cycle.** Run and sneak replayed the walk block faster and there was nowhere to put a distinct one —
while `GameEnums.MoveState` had ten values and `Events.player_state_changed(state)` was declared,
emitted by `PlayerController` and **listened to by nothing.** The information the sprite needed
existed, was announced every time it changed, and had no route to the thing that would draw it.
Sixth instance of this project's most expensive shape, after `Gate.locked_key`,
`PathAction.refusal_key`, `ItemDb.reload`, `HD2DCameraRig`'s framing exports and 1.1.0's locale
setting.

It now takes a `GameEnums.MoveState`. `CharacterVisual` is TOLD the state by whoever drives it —
never read from `player_state_changed`, because every NPC uses the same class and none of them is
the player. `NpcBrain` passes `WALK` or `IDLE` from whether it is stepping, which is the honest
extent of what a schedule-driven actor knows, and gets a game's walk block for free without
knowing that animation blocks exist.

**The fallback chain is the compatibility promise**, and it is asserted before the feature is:
a gait row left at `-1` inherits `walk_row`, and states with no gait of their own (`JUMP`, `FALL`,
`SWIM`, `BUSY`, `LOCKED`) fall to `idle_row` rather than to walk — something else driving the
character looks like standing there, not walking on the spot. `-1` rather than `0` is load-bearing:
row 0 is a real row, so a default of `0` would have drawn a standing character for anything running
on every sheet not yet updated.

**`problems()` now validates every named row, not just two.** A gait row past the end of the sheet
is reported by field name — `names run_row row 9, past its 3 animation(s)` — because the draw call
clamps to the last block, so an unreported typo animates plausibly and wrongly.

**`PlayerController` computes its state BEFORE drawing.** `_update_state` ran after the visual
update, which was invisible while nothing read the state and became a one-frame lag on every gait
change the moment something did.

**Also in this version:** the shipped placeholder sheet gains idle, walk and run blocks with a
different cloth tint each and a forward lean on the run, so which gait is drawn can be READ off a
capture instead of guessed at — proved by three captures in which the player walks in green and
runs in rust while the keeper NPC stands beside them in blue, from the same sheet in the same
frame. `art_contract_test.gd` gains 19 assertions over the mapping, the fallback and the clamp.
Suite 1,653 → 1,676; stripped 1,579 → 1,602, its 25 skips unchanged.

---

## 1.1.0

*2026-09-04 — the skeleton's four open exit criteria closed, and one of them was a missing
feature rather than a missing proof.*

**A consuming game does:** two things, both small, and only if it wants the second language.
`localization/strings.csv` gains an `en_XA` column, so **expect a conflict in that file** — it is
the one that conflicts on every merge (see [`UPGRADING.md`](UPGRADING.md)). Resolve it by keeping
your own rows, then run `godot --headless --script tools/gen_pseudolocale.gd` to refill the
column and `--headless --import` to regenerate the translation. If you do **not** want a
pseudolocale, delete the `en_XA` entry from `locale/translations` in `project.godot` and drop the
column — nothing in `src/` names it. Everything else here is additive.

**The locale setting was wired to nothing, and now it applies.** `settings_screen.gd` cycled a
locale and stored it; `Settings` announced `setting_changed`; and **no system anywhere called
`TranslationServer.set_locale`.** So changing the language did nothing at all, in a project whose
first non-negotiable about text is that every string is a key. `Settings._apply_locale` now
applies it, on `_apply_display`'s stated reasoning rather than by analogy with it — nothing else
owns `TranslationServer` either, exactly as nothing else owns the window. It is deliberately
**not** skipped under `--headless`, which is the one way it differs from the display: a
translation has no window in it, so the suite asserts against `tr()` instead of taking a
screenshot on trust.

**And there was no second language to switch to.** The CSV had one locale column, so the
criterion was unreachable however well the wiring worked.
[`tools/gen_pseudolocale.gd`](../tools/gen_pseudolocale.gd) generates an `en_XA` column —
`[~~English~~]` — which is the same argument that generates placeholder ART rather than shipping
art: the stand-in exists so the system can be verified before the content is. It earns its keep
afterwards too: a string that appears **unbracketed** on screen never went through the CSV, which
is `check_strings.gd`'s static rule caught visually and including anything computed, and the
padding makes every label longer than its English so a layout that only just fits fails here
rather than in a translated build.

**`check_content.gd`'s CSV rule is now the header width, not the literal two.** It failed any row
parsing to more than two columns, which caught WP-01's unquoted comma and would have failed the
second language outright. It compares against the header instead, and requires equality rather
than a maximum so a half-added locale filling only some rows is caught too. Planted: the original
WP-01 row, unquoted, gives *"object.lever.gate.on has 4 column(s) where the header has 3, so an
unquoted comma has cut its text off at 'The lever gives with a heavy clack. Somewhere north'"* —
the same bug, still caught, with three columns.

**`save` and `load` join the console vocabulary**, so there are six verbs rather than four, with
one body each as ADR-settled. Slots are zero-based because `SaveSystem` and the save screen both
are — a verb that renumbered them for friendliness would make `save 1` and menu slot 1 two
different files.

**`--locale=<code>` is a new capture flag** in `dev_capture.gd`, routed through `Settings` rather
than straight to `TranslationServer` so it exercises the path a player takes. **It PERSISTS**,
because a language choice should — pass `--locale=en` to put it back.

**The suite now pins its own language.** That persistence bit immediately: a `--locale=en_XA`
capture left the setting on disk and the next suite run failed in four unrelated cases that
compare `tr()` output. `test_runner.gd` pins the project's declared fallback locale for the same
reason it pins `Clock.paused`, and reads it from `ProjectSettings` rather than hard-coding
English — so a consuming game whose default is not English gets a deterministic suite too.

**Also in this version:** `facing_test.gd` (21 assertions) covers the direction-of-travel to
facing and column mapping, which `art_contract_test.gd`'s MUST NOT line forbade it from
asserting; `dev_probes.gd` gains the `--save-state` / `--load-state` pair for a two-process save
proof, and `--face-all` was a temporary probe that has been removed. The verb-count assertion
gained a companion that cannot rot — every verb in `VERBS` must dispatch — because a count alone
would pass on a seventh verb declared and forgotten. Suite 1,625 → 1,653; stripped 1,551 → 1,579
with its 25 skips unchanged.

---

## 1.0.2

*2026-09-04 — one defect in the TEST RUNNER, found by performing [`TESTING.md`](TESTING.md).*

**A consuming game does:** nothing, unless its suite has a case that does not compile — in which
case rung 4 will now fail where it previously passed, and the failure names the file. That is the
bug being fixed, not a new restriction: the case was never running.

**A listed test case that does not parse no longer reports a clean pass.** `load()` on a script
with a parse error returns a `GDScript` that is **not null** and cannot be instantiated, so
`_run_case` walked straight into `script.new()`; that call's failure is a runtime error, and a
GDScript runtime error aborts only the innermost frame, so the `does not extend TestCase` failure
below it was never reached and the loop in `_ready` moved on. Measured on this repository: a
parse error planted in one listed case produced `=== 1608 passed, 0 failed, 0 skipped ===` and
**exit 0**, indistinguishable from a run in which the case did not exist.
`tests/framework/error_watch.gd` had counted the error and nothing ever asked it.
[`tests/test_runner.gd`](../tests/test_runner.gd) now checks `can_instantiate()` before
instantiating, and separately fails the run on any engine script error that no named case
accounted for — the second guard being the general one, since the next hole in that wall will not
be a parse error.

**`TESTING.md`'s worked example now compiles.** Its one assertion example read
`inventory.count()`, which is wrong twice over — nothing declares `inventory`, and `Inventory`
has no `count()`. Copying it verbatim is what began this package. The document also states what
`TestCase` actually provides, that `Fixtures.activate()` returns a bool a case must check, and
that fixture ids are consts in `tests/framework/fixture_content.gd` rather than strings to
retype.

**Also in this version:** `bag_mirror_test.gd` asserts that the `bag/<carrier>/<item>` count
flags are already current when `item_gained` and `item_lost` fire — an ordering `Inventory.add`
documents in a comment and which nothing tested on either path. `TESTING.md`'s suite total,
gotcha count and `transitions_test.gd` plan are re-measured rather than inherited.

---

## 1.0.1

*2026-09-03 — two defects found by performing [`NEW_GAME.md`](NEW_GAME.md) as a fork.*

**A consuming game does:** nothing, unless it forked at 1.0.0 and followed `NEW_GAME.md`, in
which case check `localization/strings.csv` for rows starting `quest.` and delete them — they
are this template's demo quest, and the pruning instructions did not list them.

**`core_test.gd` no longer fails a fork that has not authored its first area yet.** It asserted
`[game] world/first_area != ""` unconditionally, which contradicted its own case name, the
comment eight lines below it, and `NEW_GAME.md` § 4 — all three of which call an empty setting a
legal state. It was green in the full template and in the stripped one, because neither ever
empties that field, and red only in a real fork during the window `NEW_GAME.md` walks an author
through. The claim now lives only in [`tests/unit/smoke_test.gd`](../tests/unit/smoke_test.gd),
which gates it on whether any area exists and also requires the named area to resolve, so a game
WITH areas and an unset first area still fails rung 4.

**`NEW_GAME.md` § 3 now prunes `quest.` from the localization CSV.** The prefix list was written
before quests existed (WP-08) and was never extended, so a fork that followed the document
shipped the demo's `quest.keepers_errand.*` rows inside its own game — with all four checkers and
the whole suite green, because no gate reads `localization/` for demo content. The section now
lists the prefix, and states that nothing checks this file for you.

**Also in this version:** `NEW_GAME.md`'s verification output, row counts and suite totals are
re-measured rather than inherited, and § 6 now gives the `--` separator that `--new-game`
requires — without it the run stops at the main menu and reports `0 warnings, 0 errors`, a green
run that proves nothing.

---

## 1.0.0

*2026-09-02 — the first version the template states about itself.*

**The baseline.** Everything up to and including WP-14b, which closed Phase T3: every system in
[`SYSTEMS_INVENTORY.md`](SYSTEMS_INVENTORY.md) has a working minimal implementation and one piece
of placeholder content proving it. There is nothing to migrate *from*, so this entry records what
a fork is forking rather than what changed.

**A consuming game does:** nothing. This is the first release.

**New in this version, and it is only the two things Phase T4 named:**

- `[template] base/version` in `project.godot`, read through
  [`src/core/util/template_version.gd`](../src/core/util/template_version.gd) and printed in the
  boot banner as `base <version>`. A fork leaves this line alone; a merge that changes it is the
  base announcing a release in the diff.
- [`UPGRADING.md`](UPGRADING.md) — how a game already forked from this base receives a later fix,
  performed against a real stripped fork rather than written from intent.

**Known and stated rather than fixed:** `project.godot` and `localization/strings.csv` are MIXED
files, and a merge into a diverged fork can conflict in both. `UPGRADING.md` § *The two files
that will conflict* says what those conflicts actually look like, because they were produced.
