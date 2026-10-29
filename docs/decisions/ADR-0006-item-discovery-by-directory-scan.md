# ADR-0006 — Items are discovered by scanning a directory, not from a list

**Status:** Accepted, 2026-08-25. Its one open limit — the exported build — CLOSED 2026-08-26 by T2.0.

## Context

`docs/ARCHITECTURE.md` claims *"adding the fiftieth item must not touch a single line of code"*.
Until this change the project had zero `Resource` classes, so the claim had never been
exercised — the audit called it not merely untested but unrunnable. Items are the first content
type, so they decide what the claim actually means.

Something has to turn an item id into an `ItemDefinition`. Four options:

| Option | Fiftieth item touches code? | Failure mode |
|---|---|---|
| Hand-maintained registry resource | **Yes**, one edit per item | Rot, guaranteed |
| Generated manifest | Almost — you must remember to run a tool | **Silent.** A forgotten regeneration is indistinguishable from an item never added |
| `DirAccess.get_files_at()` | No | **Silent in an exported build.** Text resources are converted and reached through a remap, so matching on the extension finds nothing |
| `ResourceLoader.list_directory()` | No | Undocumented in 4.7.2 — semantics must be proven, not assumed |

## Decision

`ItemDb` scans `res://data/items` with `ResourceLoader.list_directory()`, falls back to
`DirAccess.get_files_at()` if that returns nothing, and normalises both possible return shapes
(bare filename or full path) plus the `.tres`, `.res`, `.remap` and `.import` suffixes.
Definitions are cached by id. **A definition's `id` must equal `item/` plus its filename**; a
mismatch is refused and reported with both values.

`ItemDb` is a static `class_name`, not an autoload.

## Why

- **A scan is the only option where dropping a `.tres` in a folder is the whole act.** A
  manifest is one forgotten command away from an item that does not exist, and silent-wrong is
  the failure mode this project exists to prevent.
- **`list_directory` is the resource-aware one** — it understands the indirection an exported
  pack uses, which a raw directory listing does not. Its doc description is empty in 4.7.2, so
  its behaviour is treated as unproven: `tools/check_content.gd` prints what it actually
  returned on every run, and a test cross-checks the count against an independent `DirAccess`
  listing, so a change fails a gate instead of silently shrinking the catalogue.
- **Static, not an autoload:** it holds no mutable state, has no lifecycle, is never saved and
  needs no init order, so an autoload would need an ADR and buy nothing. Decisively, an autoload
  **cannot** be used by `tools/check_content.gd`, because autoload identifiers do not resolve
  under `--headless --script` — the validator would have to duplicate the loading code it exists
  to test. This is also why no content class may touch an autoload: the moment one does, the
  validator stops compiling and the gate fails. That is mechanical enforcement of the content
  layer rule, which no other layer here has.
- **id equals filename** turns a copy-paste slip into a named startup failure rather than a
  duplicate that silently shadows another item.

## The honest limit — CLOSED 2026-08-26 by T2.0

**The exported-build half is now proven, and the decision above stands unchanged.** A Windows
debug export was built and run from its own `.exe`, outside the editor, in a directory holding
nothing but the executable and its `.pck`. It reported exactly what the editor reports:

```
origin: template=true editor=false debug=true exe=game.exe
items: 3 found in res://data/items -> [".../rose_key.tres", ".../rose_petal.tres", ".../stone_chip.tres"]
dialogue: 1 found in res://data/dialogue -> [".../gardener.tres"]
schedules: 1 found in res://data/schedules -> [".../keeper.tres"]
```

Three findings, in the order they matter:

1. **`ResourceLoader.list_directory()` works through the pack, and this is the first evidence of
   it.** The pack stores `data/items/rose_key.tres.remap`; the scan returns the `.tres` path and
   `ResourceLoader.load()` follows the remap. The undocumented method is the right one, for the
   reason given above, and `_normalise`'s `.remap` handling is now observed rather than defensive.
   The `DirAccess` fallback never fires in an export and is kept for source runs.
2. **The preset field is the whole risk.** `export_filter="all_resources"` ships them;
   `export_filter="scenes"` ships **zero** of them. That is measured both ways, and the remedy
   contemplated below — a generated manifest — is therefore NOT needed.
3. **`include_filter="*.tres"` would have been the plausible wrong fix.** It is for non-resource
   files. A `.tres` is a resource and travels under `export_filter`; setting the include filter
   instead changes nothing and looks like a fix.

So the two consequences written down above resolve as: (1) confirmed, and now enforced by an
assertion in `tests/unit/export_test.gd` rather than trusted to a comment; (2) not triggered, and
`ItemDb.resource_paths()` is unchanged. (T3.1 moved that function to `ContentScan.resource_paths()`
— the same implementation, under the name of the job it does, called by all five catalogues
instead of four of them calling the item registry. Nothing about this decision changed.)

`ARCHITECTURE.md`'s claim — *"adding the fiftieth item must not touch a single line of code"* — is
verified in the editor, headless **and in an exported build**.

## Revisit if

An export ships an empty catalogue, or item counts grow enough that a boot-time scan measures.
