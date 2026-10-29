# ADR-0002 — GDScript warnings are errors

**Status:** Accepted, 2026-08-23

## Context
GDScript is dynamically typed by default. Optional static typing exists, and the compiler can
emit warnings for untyped and unsafe constructs. Those warnings can be set to error.

## Decision
`untyped_declaration`, `unsafe_call_argument`, `unsafe_method_access`,
`unsafe_property_access`, `unsafe_void_return`, `standalone_expression`,
`unassigned_variable` and `unreachable_code` are all **errors**.

## Why
It converts a whole category of runtime bug into a parse failure, and it makes
`--headless --check-only` a genuine build gate rather than a syntax check. Verified: a script
assigning a `String` to an `int` and calling an undefined function exits 1, naming both file
and line.

The previous project's 14,557 lines were largely untyped. Its failures were the exact
failures this setting prevents: a wrong type reaching a function three systems away and
surfacing as inexplicable behaviour.

## Costs, accepted
More verbose code. Untyped data from JSON and save files cannot be converted inline —
`int(value)` on a `Variant` will not compile. `DictRead` exists specifically to absorb that
cost in one place, and it turned out to be a better design anyway: every external read is now
type-checked with a fallback instead of trusting the file.

This rule caught real defects during its own introduction, including two in `check_budgets.gd`,
the tool that enforces the other rules.
