# ADR-0005 — World objects carry an author-assigned `object_id`, and their state lives in `Flags`

**Status:** Accepted, 2026-08-24

## Context

An opened chest must stay open across a save and reload. That needs two things: a way to name
the chest that survives editing, and somewhere to keep what changed.

Three schemes for the name were considered.

**Node path** (`Interactables/ChestNorth`). Free, requires no authoring. Fatal flaw: identity
is coupled to scene structure, so renaming a node, reparenting it, or reordering siblings
silently orphans its saved state. The chest refills and nothing errors. That failure appears
weeks later, in a playtester's save, and is nearly impossible to trace back to the rename.

**Generated UUID stamped on the node.** Stable under renames, but unreadable in a diff and in
a save file, impossible to author deliberately, and a duplicated node carries a duplicate
UUID unless extra machinery prevents it.

**Author-assigned short id, unique within the area.** Costs one exported field per object.
Readable in a save file and in a log line, greppable, and stable under any scene edit.

## Decision

Every persistent world object gets a `PersistentState` child node with
`@export var object_id: StringName`, unique within its area. State is stored through `Flags`
under a namespaced key:

```
obj/<area_id>/<object_id>/<field>
```

`PersistentState` finds its `area_id` by walking up to the enclosing `AreaRoot`, so the id
only has to be unique within one area file, not globally.

No new autoload. `Flags` is already a generic key-value store and already a save participant,
so object state round-trips through the machinery that the test suite already covers.

## Why this shape

- **Renaming a node cannot orphan state.** Only editing `object_id` can, and that is a
  deliberate act visible in the diff.
- **A save file is readable.** `obj/courtyard/gate_lever/thrown: true` says what it means.
- **An unset id is caught, not tolerated.** `PersistentState` logs an error naming the node
  when `object_id` is empty. Silence would reintroduce the node-path failure by the back door.
- **Duplicate ids inside one area are a content bug** that a validator can detect by scanning
  scenes. Not built yet; recorded as the next tooling task.

## Costs, accepted

Someone must type an id when placing an object. That is the price of identity that survives
refactoring, and it is one field.

`Flags` will hold both plot state and object state. They are namespaced apart (`story/`,
`met/`, `obj/`) and `Flags.with_prefix()` can separate them, but a very large world will want
object state split into per-area save sections so the file does not grow without bound. The
key format already encodes the area, so that split is a change to `Flags` alone and touches no
object.

## Revisit if

Object counts reach the point where one flat dictionary is a measurable cost, or an object
needs to persist state that is not a simple value.
