# ADR-0004 — Systems register save callables; the save system knows no content

**Status:** Accepted, 2026-08-23

## Context
The obvious save design is one function that reaches into every system and reads its state.
In the previous project, that responsibility lived inside `main.gd` — the file that reached
3,983 lines.

## Decision
`SaveSystem` holds no knowledge of game content. A system registers a pair of callables:

```gdscript
SaveSystem.register(&"clock", _collect_save, _apply_save)
```

`_collect_save()` returns a `Dictionary`; `_apply_save(data)` consumes one. Each system owns
its own section format. The save file is a JSON envelope with a schema version and one
section per participant.

## Why
Adding a saveable system never edits the save code, so the save file cannot become the place
that knows about everything. Sections are independent, so a missing section loads at defaults
instead of failing the whole file, and a system can change its own format without touching
any other. Writes are atomic — temp file then rename — so a crash mid-save leaves the
previous save intact rather than truncating it to zero bytes.

Callables were chosen over a `SaveParticipant` base class because GDScript has no interfaces,
and a base class would fight composition: a node already extends something.

## Costs, accepted
The registration order determines the apply order, which is an implicit dependency. It is
documented in `save_system.gd` and matters only if one system's restore depends on another's.
A participant that is freed without calling `unregister()` leaves a dead callable, so
`register()` validates and the collector reports a non-Dictionary return as an error rather
than writing corrupt data.
