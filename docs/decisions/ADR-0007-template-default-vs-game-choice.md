# ADR-0007 — A template rule, a template default and a game choice are three different things

**Status:** Accepted, 2026-09-09.

## Context

[`docs/TEMPLATE.md`](../TEMPLATE.md) § *"The one constraint nobody has scoped"* has said since
2026-08-26:

> The same class of question applies to a few other decisions made for one game's constraints and
> now imposed on all of them — most notably "a conversation is not saved". They may well be the
> right defaults. **What is missing is the distinction between a template default and a game
> choice, which no document currently draws.**

Nothing ever scheduled it. `docs/CONTEXT.md` has carried it as the **first-ranked** candidate row
for five packages, each time noting that *"its honest weakness is that it is prose and cannot be
proved by running the engine"* — which is exactly why it kept losing to rows that could be gated.

It is not a cosmetic gap. `CONTEXT.md` records that the row **"DECIDES the two rows under it
rather than guessing: whether a chapter sequencer, a calendar and an economy are this base's
business at all is one question asked three times."** Both of those rows — a narrative-staging
seam and time above the scale of one day — carried *"Scope depends on the taxonomy row above"* and
*"Also gated by the taxonomy question"*. So three candidate rows were unscopable, indefinitely, for
want of one distinction, and the project's own rule against inventing work meant none of them could
honestly be started.

The confusion is real and not merely verbal. "No combat" was decided for one game and now
forecloses combat for every game built on this base — a much larger commitment, and `TEMPLATE.md`
records it precisely because nobody had said so out loud. Meanwhile `world/first_area` is also a
decision the template made, and a game overrides it by editing one line of `project.godot`. Calling
both "a decision the template made" is what loses the difference.

## Decision

**Every choice this base makes is exactly one of three kinds, and the kind is stated wherever the
choice is recorded.**

| Kind | What it means | How a game relates to it | Where it is recorded |
|---|---|---|---|
| **TEMPLATE RULE** | Foreclosed for every game built on this base. Not a default — an absence with a gate behind it wherever one is possible | It cannot override it. Wanting to is a fork of the template, not a game | `TEMPLATE.md`, `CLAUDE.md`, and a checker where the rule is mechanical |
| **TEMPLATE DEFAULT** | The base picks a value or a shape and ships one that works. **A seam exists** | It replaces the value through the seam, touching no `src/` file | `AUTHORING.md` / `ART_CONTRACT.md` for authored data; `project.godot` `[game]` for boot facts |
| **GAME CHOICE** | The base builds **nothing** and provides only the seam and the facts | It builds it in its own code root, on the base's signals and flags | `SYSTEMS_INVENTORY.md` as `OPTIONAL`, or absent with a stated reason |

**The test that separates default from rule is whether a seam exists.** A "default" a game cannot
replace without editing `src/` is not a default; it is a rule that has not admitted it. That test is
mechanical, and it is what makes this ADR more than vocabulary.

### Applied, so this ADR decides rather than describes

- **No combat is a TEMPLATE RULE.** Owner decision, affirmed repeatedly, and now stated as the kind
  of thing it is. Not up for revisiting per game.
- **The layer rule, and "no file under `src/` may name demo content", are TEMPLATE RULES** — both
  already have checkers (`check_layers.gd`, `check_boundary.gd`), which is what a rule looks like
  when it can be mechanised.
- **Art being deferred is a TEMPLATE RULE** for this base's development, and a TEMPLATE DEFAULT for
  a consuming game: the placeholders ship and work, and `ART_CONTRACT.md` is the seam that replaces
  them.
- **Time is a TEMPLATE DEFAULT.** `Clock`, `NpcSchedule` and `Weather` already live here, so a cycle
  above the day extends a system that is present rather than adding one. The base owns the *facts*
  — the hour, the day, the phase, the cycle position — and a game chooses the numbers.
- **A chapter sequencer is a GAME CHOICE.** A `story/chapter` integer flag with `AT_LEAST` is
  already a complete chapter model for both authored condition surfaces, and both `DialogueNode`
  and `QuestStep` evaluate through the one `FlagQuery`. A first-class `Chapter` resource would add
  a second way to express what one already expresses.
- **An economy is a GAME CHOICE**, on the same footing as `Harvestables` (already `OPTIONAL`,
  WP-10). Currency, value and exchange are genre, not structure. `Inventory`, `Equipment` and
  `Interactable` are the seams it would be built on.

## Why

- **The distinction is what makes "breadth of systems, one shallow proof each" actionable.** That
  doctrine says every system gets a home and one proof. It does not say which things are systems.
  Without this ADR, "is an economy a system this base owes a shallow proof of?" has no answer, and
  three candidate rows sat on that unanswered question.
- **The seam test converts an editorial question into a checkable one.** "Is this a default or a
  rule?" was a matter of tone. "Can a game replace it without editing `src/`?" is a fact about the
  repository, and the answer is sometimes embarrassing — which is the point. It is what surfaced
  that `game_root.gd`'s hardcoded player scene is a rule masquerading as a default.
- **Recording the kind beside the choice is what stops the drift TEMPLATE.md warned about.** "No
  combat" grew from one game's constraint into every game's foreclosure without any document
  marking the moment. A stated kind makes that promotion visible when it happens instead of years
  later.
- **Naming a GAME CHOICE is a refusal to build, and refusals need to be written down.** Otherwise
  each is rediscovered as a candidate row, ranked, deferred for want of a reason, and ranked again.
  That is what happened three times.
- **It is prose, and prose was never the objection.** The objection was that prose cannot be proved
  by running the engine, and it cannot. What is gated is the *structure*: `record_shape_test.gd`
  asserts every document opens with its title and every recorded package is findable in both the
  board and the roadmap, and `docs_test.gd` asserts every `res://` path a document names resolves.
  An ADR is covered by both. **No new gate is added, and inventing one to have one would be the
  thing this project spent T5.24 through T5.27 learning not to do.**

## The honest limit

**"A conversation is not saved" — the example `TEMPLATE.md` named — is left classified but not
resolved, deliberately.** By the seam test it is currently a TEMPLATE RULE: `dialogue_runner.gd`
warns and refuses on `_collect_save`, and a game wanting resumable conversations would have to edit
`src/`. But its stated reason is a good one — it keeps every dialogue node id private rather than
promoting it to a permanent save identifier — and whether the *right* answer is "rule, and say so"
or "default, and add the seam" is a judgement about a system this ADR is not otherwise touching.
Recorded here so the next reader finds a stated question rather than an unexamined absence.

The same applies to any other choice this ADR did not enumerate: the three kinds exist now, and
classifying the rest is done where each is recorded, not in one sweep.

## Revisit if

A choice cannot be classified — which would mean the three kinds are the wrong three — or a
TEMPLATE DEFAULT is found with no seam, which by the test above means it was never a default and
the record was wrong.
