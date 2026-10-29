# ADR-0001 — Code lives in `src/`, separate from `scenes/`

**Status:** Accepted, 2026-08-23

## Context
Godot convention is to keep a script next to the scene that uses it. That is ergonomic: one
folder per feature, everything to hand. The alternative is a layered code tree separate from
the scene tree.

## Decision
Code goes in `src/`, in five layers: `core`, `systems`, `gameplay`, `content`, `ui`. Scenes go
in `scenes/`.

## Why
The dependency rule — layers may only depend downward — becomes checkable by **path**. A tool
can read an import and know whether it crosses a layer illegally. With colocated scripts,
"core must not depend on gameplay" is a sentence in a document that nothing can verify, which
is precisely the class of rule that failed in the previous project.

## Costs, accepted
Jumping between a scene and its script means crossing folders. Scene files reference scripts
by `res://src/...` path, which is slightly more verbose.

## Revisit if
A layer-violation checker turns out to be unbuildable, which would remove the only reason for
the split.

## Amendment, 2026-08-25 — `content` moved below `gameplay`

The original layer order was `core -> systems -> gameplay -> content -> ui`, which put `content`
above `gameplay`. That was wrong. A `Pickup` in `gameplay` must reference an `ItemDefinition` in
`content`, which under that order was an upward dependency and failed this ADR's own test.

Content is data, not a consumer: typed `Resource` shapes that depend on nothing. The order is
now `core -> content -> systems -> gameplay -> ui`.

The mistake was harmless only because `src/content/` was empty. It would have become a real
violation on the day the first `Resource` landed, which is the day this amendment was written.
Recorded rather than quietly fixed, because the same reasoning error - "this layer feels
higher-level, so it goes on top" - is easy to repeat.
