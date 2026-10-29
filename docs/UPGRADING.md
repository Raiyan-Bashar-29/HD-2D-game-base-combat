# Receiving a later fix to the base

**The question this answers:** you forked this template, you have been building your game for
three months, and the base has since fixed something. How do you get it?

[`NEW_GAME.md`](NEW_GAME.md) is the sibling document — it says how to *leave*. This says how to
**stay in touch**, and it is the one question a reusable base has to answer.

**The one-line version:** keep the template as a git remote, `git merge template/main`, expect a
conflict in exactly two files, delete any demo content the merge brings back, and run the ladder.

**Everything below was PERFORMED, not designed.** A stripped fork was made, two template releases
were landed on the base, and both were merged in. The output is quoted verbatim in § 7, including
the one place it went red — and it found a real defect in the template, which is fixed and shipped
as part of 1.0.0.

**The versions 1.1.0 and 1.1.1 below are SYNTHETIC.** They exist only in the throwaway repositories
this document was performed against, because a version-to-version walk needs two versions and the
real template has released one. [`CHANGELOG.md`](CHANGELOG.md) is the real history and its newest
entry is 1.0.0. Everything quoted below is real output; the release numbers are the scaffolding it
was produced on.

---

## 1. Which base am I on?

`project.godot` carries `[template] base/version`, read through
[`src/core/util/template_version.gd`](../src/core/util/template_version.gd) and printed in every
boot banner:

```
Marsh Lantern 0.0.1 | base 1.1.1 | Godot 4.7.2-stable (official) | headless | debug=true
```

Two versions, and they are different facts. `0.0.1` is **your game's**
(`application/config/version`, which [`NEW_GAME.md`](NEW_GAME.md) § 4 tells you to reset on day
one). `1.1.1` is **the base's**, and *you never edit that line* — a merge changing it is the
template announcing a release in your diff.

That is also why the version is not a `const` in a file under `src/`: reading it would mean
opening engine code, and the whole premise here is that you do not read `src/`.

## 2. Set the remote up once

```bash
git remote add template <the template's URL>
git fetch template
```

You have `origin` (your game) and `template` (the base). Nothing else is needed — this is a
normal git remote, and the merge below is a normal merge.

## 3. Read the changelog before you merge, not after

[`CHANGELOG.md`](CHANGELOG.md) has one entry per version, and each entry ends with **what a
consuming game has to do about it**. Compare its newest heading against your `base/version`.
`TemplateVersion.same_major_as()` is the same question in code, if you want it in a tool.

## 4. What the version numbers promise

| Bump | Means | You |
|---|---|---|
| **PATCH** `1.1.0 → 1.1.1` | nothing you wrote is affected | merge it |
| **MINOR** `1.0.0 → 1.1.0` | the base gained something you may ignore | merge it |
| **MAJOR** `1.x → 2.0.0` | **a file you wrote must change** | read the entry first |

### What this template CANNOT promise, said plainly

1. **It cannot promise a clean merge.** Git decides that, from your diff and the base's, and
   neither this document nor the version number can see your diff. What it promises is that the
   conflicts are confined to the two MIXED files in § 5, and that both have a mechanical
   resolution.
2. **It cannot promise your content still loads.** A MAJOR bump can change a field on
   `ItemDefinition` or the shape of an area scene. The version tells you to expect that; only
   your own ladder tells you whether it happened.
3. **It cannot promise a save file survives.** Saves carry a version and the template migrates
   its own fields; it knows nothing about yours.

   **Changing the shape of your own section is yours to migrate, and the procedure is two steps.**
   Pass the next number as `register()`'s fourth argument — `SaveSystem.register(&"id", collect,
   apply, 2)` — and in your applier, upgrade an older payload in place before reading it: one
   `if from_version == 1:` per past version, each producing the next shape and falling through.
   Never bump `SCHEMA_VERSION` for this; that is the envelope's, and a section changes without it.
   The loader refuses a section stored at a version ABOVE the one you registered — a save a newer
   build of your game wrote — and leaves that section at its defaults, so your applier never has to
   guard against the future (since `5.6.3`). The worked example to copy is
   `_probe_apply` in [`tests/unit/save_recovery_test.gd`](../tests/unit/save_recovery_test.gd),
   which renames `old_key` to `new_key` from v1 and asserts the value survives.
4. **It cannot promise anything about a fork that edited `src/`.** That is not a limitation of
   the merge — it is the one rule the whole template rests on. See § 5.
5. **There is no automatic upgrade, and there will not be one.** No script rewrites your files.
   Git shows you a diff and you decide.

## 5. The three classes of file, and only one of them is yours

| Path | Class | On a merge |
|---|---|---|
| `src/**` | **Engine** | takes the base's version. Never edit it, and this is why. |
| `tools/**`, `tests/framework/**`, `tests/unit/**` | **Engine** | same |
| `scenes/objects/`, `scenes/characters/`, `scenes/boot/` | **Engine** | same |
| `data/**` | **Yours** | keep yours — but see § 7 |
| `scenes/areas/**` | **Yours** | keep yours — but see § 7 |
| **your own code root** (`game/`, or scripts beside your areas) | **Yours** | keep yours — the base ships none, so a merge never touches it |
| `project.godot` | **MIXED** | § 6 |
| `localization/strings.csv` | **MIXED** | § 6 |

**The rule that makes this work at all is the boundary rule** — no file under `src/` names your
content, enforced by [`tools/check_boundary.gd`](../tools/check_boundary.gd) — which is why you
never had a reason to edit `src/`, and why taking the base's copy of it wholesale is safe. A fork
that broke that rule has no upgrade path, and no version number can give it one. That is the
honest cost of editing engine code, stated once, here.

## 6. The two files that will conflict

### `localization/strings.csv` — it conflicts, and the resolution is always the same

Both sides append rows at the end of the file, so both sides edit the last line. This is what it
actually looked like:

```
<<<<<<< HEAD
item.lantern_wick.name,Lantern wick
=======
ui.pause.resume,Resume
item.lamp_oil.name,Lamp oil
>>>>>>> template/main
```

**Keep both sides.** These are rows in a key-value file, not competing edits to one value. The
only real collision is the base and your game choosing the *same key*, which the key prefixes make
unlikely: engine rows are `ui.*`, `verb.*`, `refusal.*`, `notify.*`, `weather.*`, `time.*`,
`item.category.*`; yours are everything else. **Two traps carry over from
[`NEW_GAME.md`](NEW_GAME.md) § 3** — a value containing a comma must stay quoted, and
`ui.menu.title` is an engine key holding *your* game's name, so keep your side of that one.

Run `--headless --import` afterwards to regenerate `strings.en.translation`.

### `project.godot` — it merged clean, and do not count on that

It is a MIXED file, but the mixing is by *section*: you own `[application]` and `[game]`, the base
owns everything else. Both merges in § 7 auto-merged, including one where the base edited
`application/config/features` three lines below a field the fork had renamed. Git handled it.

**Check these lines by eye after every merge**, because a wrong auto-merge here is silent:

```
config/name                — yours
config/description         — yours
config/version             — yours
[game] world/first_area    — yours, and the one that matters
[template] base/version    — the base's. It should have gone UP.
```

## 7. The proof — two merges, run

A real fork was made from base 1.0.0 following [`NEW_GAME.md`](NEW_GAME.md): demo deleted, CSV
pruned from 219 rows to 173, project fields renamed, one item of its own authored. Then two
template releases were landed on the base and merged in.

### Merge one, base 1.0.0 → 1.1.0 (a MINOR, one change per risk class)

```
$ git merge template/main
Auto-merging localization/strings.csv
CONFLICT (content): Merge conflict in localization/strings.csv
Auto-merging project.godot
Automatic merge failed; fix conflicts and then commit the result.
```

One conflict, in the file § 6 says will conflict. `project.godot` auto-merged and kept every line
on the correct side:

```
config/name="Marsh Lantern"                                  ← the game's
config/features=PackedStringArray(..., "Double Precision")   ← the base's
world/first_area="fen"                                       ← the game's
base/version="1.1.0"                                         ← the base's, and it went up
```

**The base's change under `src/` merged with no conflict and no thought**, which is § 5 working.

### The finding that is in no other document: a merge brings the template's demo content back

`data/items/lamp_oil.tres` — an item belonging to the *template's* demo — arrived in the fork as a
new file, because `data/` is a directory both sides own files in and git has no opinion about
whose. **Delete it.** It is not a conflict, so nothing tells you it happened: check
`git diff --stat` for new files under `data/` and `scenes/areas/` on every merge.

### Then the ladder went RED, and that was a real template defect

```
=== 1539 passed, 1 failed, 12 skipped ===
  FAIL and its scene really exists — expected true, got false
```

Not caused by the merge. `tests/unit/smoke_test.gd` gated its first-area block on *"does this
checkout have any content"*, which flips true on the first `.tres` of any kind — so a game that
authored one item before its first area armed an assertion about **areas** and failed rung 4. That
is exactly the window [`NEW_GAME.md`](NEW_GAME.md) walks an author through, while claiming the
ladder stays green. The block now gates on `Fixtures.area_ids()`, the same question it asserts.
In the real template that fix is part of 1.0.0; in the proof it was landed on the base as the
synthetic **1.1.1**, so that merge two below is a real patch release being received.

**This is the argument for performing a document rather than writing one.** Nobody finds that by
reasoning about merges.

### Merge two, base 1.1.0 → 1.1.1 (a PATCH — the fix above)

```
$ git merge template/main
Auto-merging project.godot
Merge made by the 'ort' strategy.
 docs/CHANGELOG.md        |  9 +++++++++
 project.godot            |  2 +-
 tests/unit/smoke_test.gd | 17 +++++++++++++----
```

No conflict. A patch that touches only engine files and the version line is the easy case, and it
is the case most releases will be.

### And the fork, merged twice, on its own ladder

```
Marsh Lantern 0.0.1 | base 1.1.1 | Godot 4.7.2-stable (official) | headless | debug=true
Session ended after 0.6s — 0 warnings, 0 errors
=== 1538 passed, 0 failed, 14 skipped ===
check_budgets exit=0   check_content exit=0   check_boundary exit=0   check_strings exit=0
```

Fourteen skips, not zero: the fork has one item and no areas, so the cases that ask about areas
say so and are counted. That is [`NEW_GAME.md`](NEW_GAME.md) § 5 working as designed.

## 8. After every merge, in this order

```bash
G=/c/Rai/softwares/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
"$G" --headless --import
"$G" --headless --quit-after 30
"$G" --headless res://tests/test_runner.tscn --quit-after 400
"$G" --headless --script tools/check_budgets.gd
"$G" --headless --script tools/check_content.gd
"$G" --headless --script tools/check_boundary.gd
"$G" --headless --script tools/check_strings.gd
```

`--import` comes **first**, always: it regenerates the `class_name` cache and
`strings.en.translation`, and its output is the real compile check — require zero `SCRIPT ERROR`
and `Parse Error` lines, because the boot rung's `0 warnings, 0 errors` does not see them. Read
the boot banner and confirm `base <version>` went up.

Then `git diff --stat HEAD@{1}` and look for new files under `data/` and `scenes/areas/`.

## 9. If you are behind by a MAJOR

Merge one version at a time, running § 8 between each. `git merge v1.9.0` then `git merge v2.0.0`
is longer than one merge and much shorter than one debugging session, because a red rung then
points at one release instead of nine.

## Read next

[`CHANGELOG.md`](CHANGELOG.md) — what each version did and what you have to do about it ·
[`NEW_GAME.md`](NEW_GAME.md) — the strip-and-start checklist ·
[`TEMPLATE.md`](TEMPLATE.md) — why the boundary that makes this possible exists
