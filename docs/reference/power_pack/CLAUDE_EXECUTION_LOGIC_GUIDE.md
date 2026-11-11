# POWER ATLAS v3 — CLAUDE EXECUTION LOGIC GUIDE

## What is new
- Every one of the **3,306 catalogue powers** has a `coding_logic` object and **Coding Logic** column in CSV/HTML.
- **199 character-profile moves** also have separate `coding_logic` objects, preserving character-specific `suggested_game_logic` and form notes.
- `coding_logic.execution_steps` is the proposed implementation procedure, and `coding_logic.pseudocode` is engine-neutral reference pseudocode.
- The CSV/XLSX presents: **power, description, coding logic, pseudocode, handler, parameters, verification status**.
- `coding_logic.handler_family` names a reusable module: implement that module once, configure it for each power.

## Read in this order (for Claude)
1. This guide.
2. `POWER_ENGINE_INTERFACE_CONTRACT.md` for shared concepts, interfaces, event ordering and tests.
3. `fictional_character_profiles_execution_logic.json` for an explicitly named character and its owned moves; reject any unverified profile as a final moveset.
4. `fictional_powers_claude_execution_logic.json` for a specified power ID and its logic.
5. `Eto_Yoshimura_execution_logic.json` for a detailed example.

## IMPORTANT CAVEATS
- This is NOT 3,306 individually researched executable scripts. It is **3,306 algorithmic implementation proposals**, routed through shared handlers and generated from earlier descriptions, plus curated special cases.
- Many existing source descriptions are single sentences. For those entries, enough information to implement the exact canon power DOES NOT EXIST in the dataset. Do not make up missing rules or costs and present them as source-accurate.
- All unexplained values (damage, HP, radius, range, cooldown, effect duration, immunities) are unspecified **parameters**, not zero, infinity, or a claim about canon.
- `manual_verification_required` marks which rows need inspection before release. Even custom overrides must be reconciled against game version/continuity.
- Power types (e.g. Fire Manipulation) are **categories**, not character moves. Do not assign them by merely sharing a franchise.
- The proposed pseudocode assumes interfaces and operations specified in the interface contract; it is NOT copy-paste-ready Python/Java/C#/JavaScript.

## Preferred code architecture
`CharacterDefinition` — persistent identity, forms, explicit move ownership.
`CharacterRuntime` — HP, resources, current form, ability-state machine, effect instances.
`AbilityDefinition` — declarative inputs, constraints, costs and chosen handler-family configuration.
`AbilityRunner` — deterministic request -> validate -> reserve costs -> cast/windup -> effect -> recovery -> cleanup.
`EffectDispatcher` — `Projectile`, `MeleeHitbox`, `AreaVolume`, `TemporalBuffer`, `ConceptRule`, `Summon`, etc.
`HitResolver` — factions, shields, immunities, resistance, damage/status, already-hit guard.
`EventBus` — stable IDs and ordering for pre-commit interceptors, causality, counters and delayed effects.
`Persistence` — restores only owned summons and scoped form/ability states.

## Prompt template to give Claude
> Use the attached v3 execution logic data. Pick [CHARACTER_ID] and only its explicitly linked moves. Implement these abilities in [GAME ENGINE AND LANGUAGE]. Follow `coding_logic.execution_steps` and `pseudocode`, translating each engine-neutral service to concrete engine APIs. Apply version-specific canon exceptions; do not hallucinate exact numbers. Write runnable code, reusable modules, unit/integration tests, debug commands, and explain every design assumption. For a generic or flagged move, ask for missing specifics or clearly mark it as a placeholder, not canon accurate. Start with one move and demonstrate an entire request/collision/cleanup trace before expanding.

## How a single ability flows
```text
input or passive event
    → is this character allowed to use the ability in this form?
    → validate target & lore-specific activation requirements
    → check and reserve configured resource/cooldown
    → enter windup / telegraph / cast state
    → dispatch named mechanic-handler
    → event interception → collision and ownership → status/damage/world-state commit
    → emit authoritative gameplay event and client VFX
    → recover, expire, cancel and save cleanly
```
