# CLAUDE — USE THIS V3 EXECUTION LOGIC EDITION FIRST

The existing archive has been upgraded with a third **Coding Logic / Execution** column for all 3,306 power entries and separate algorithms for 199 character-profile moves.

**Start with** `CLAUDE_EXECUTION_LOGIC_GUIDE.md`, then `POWER_ENGINE_INTERFACE_CONTRACT.md`.

**Primary data**: `fictional_powers_claude_code_ready.json` (v3 schema), `fictional_character_profiles.json` (v3 character profiles), and `fictional_powers_execution_logic_columns.xlsx` (visually compare description and coding logic).

Do not confuse named powers with generic power types; do not assign all of a universe's powers to a character. No exact cooldowns/damage are asserted. `coding_logic.pseudocode` is engine-neutral design, **not immediately runnable game code**. All entries still require canon/game-version checks.

---

## Previous character implementation notes (retained)

# CLAUDE: IMPLEMENT THIS CHARACTER DATA IN A GAME

## Which files to read
1. `fictional_character_profiles.json` — researched character forms and moves (start with `Eto Yoshimura`).
2. `fictional_powers_claude_code_ready.json` — all ability metadata, 3,306 entries, owners and ability-engine templates.
3. `fictional_powers_multiverse_expansion.md` — readable encyclopedia / detailed profiles and links.

## Mandatory rules
- NEVER confuse the canon description with code instructions. `suggested_game_logic` is a proposed architecture, not canon.
- NEVER assign every ability to every character in that franchise. Only use explicit `character_owner` or abilities in that character's profile.
- `null` is UNKNOWN, not a zero-value. Ask for, or clearly label, assumed range, damage, cooldown, duration, and cost.
- Respect continuity/version, form requirements, progression level and character-specific exceptions.
- Distinguish underlying **species physiology**, **power source**, **active form**, **attack action**, **passive**, **weapon mode** and **debuff/status**.
- If a profile says `index_profile_needs_manual_verification`, it is a rough roster pointer, not an authoritative complete moveset.
- Server-authoritative collision, resources, ownership and state checks are advisable for multiplayer.

## Recommended code architecture
`CharacterDefinition` holds species, rank, form and ability references.
`AbilityDefinition` holds type/trigger/target/effects/requirements/tunable parameters.
`CharacterState` holds current form, HP, resources, active effects and cooldowns.
`AbilityRunner` runs validate -> start animation -> spawn hitbox/projectile/zone -> resolve effect -> cleanup.
`EntityController` owns actors, summons and detachable parts.
`HitResolver` prevents repeated accidental hits and checks allegiances, immunity and defenses.
`TransformStateMachine` changes equipment, animations, hitboxes and ability lists.

## Standard request to Claude
> Read the character profile and all its named abilities first. Implement **only this character** in [my engine/language]. Make `normal`, `kagune_manifested`, and `kakuja_form` distinct states. Provide an ability state machine, projectile code, melee hitboxes, detachable kagune entity behavior, regeneration component, and AI decisions. Explain which values are your game-balance defaults and which abilities are canon. Include debug commands and tests. Do not infer non-canon additional powers.

## Worked example: Eto Yoshimura
- Race: natural one-eyed ghoul; canonical **Ukaku** RC type; SSS threat designation as One-Eyed Owl.
- The **Kakuja** is a transformation of her kagune; it is not proof of a second Rinkaku type.
- In normal form: can manifest ukaku appendages from back. In active kagune: create RC shard projectile bursts and reshape appendages into striking/grasping/sensory structures.
- In kakuja: change rig/body silhouette, allow heavy front-arcs and large morphing attacks, retain tactical intelligence.
- **Detached kagune** must be an independent owned entity that travels and binds targets, not a projectile that simply disappears on contact.
- **RC alteration** is a special story-dependent, target-dependent interaction; do not implement as a generic guaranteed mind-control bullet.
- **Regeneration** should handle significant damage while still allowing defeat/counters in a game; do not implement immortal god mode without design approval.
- Inputs left unspecified: exact RC cell costs, projectile speeds, counts, cooldowns, ranges, damage values, regeneration rate and strict balance.

## Basic pseudocode
```text
try_use(character, ability, target):
    definition = lookup_ability(character.form, ability)
    if definition is None: return NOT_AVAILABLE_IN_FORM
    if not valid_resource_or_state(character, definition): return DENIED
    if not valid_target(target, definition): return INVALID_TARGET
    consume_configured_cost(character, definition)
    play_telegraph(character, definition)
    execute_effect_handler(character, target, definition.delivery)
    enter_recovery_state(character, definition)

# A projectile attack is NOT the same as transforming or generating summons.
# Each delivery type has its own handler.
```

## Suggested tests for Eto
1. Ukaku volley cannot fire if her attack state forbids it; hits intended targets only.
2. A projectile does not damage its owner by default, unless intentionally enabled.
3. Kakuja transition grants the correct moveset, model and collision bounds, then restores on exit.
4. Detached kagune can persist independently and release a grapple when destroyed.
5. Regeneration restores permitted injuries without making lethal hit resolution impossible.
6. Unverified RC alteration cannot be cast as a guaranteed effect on arbitrary NPCs.
7. Animation interrupts and form-change interruptions clean up orphaned projectiles/attachments.
8. Saving/loading retains form, summons and source ownership consistently.

## Research provenance
- https://tokyoghoul.fandom.com/wiki/Eto_Yoshimura
- https://tokyoghoul.fandom.com/wiki/Kagune
- https://tokyoghoul.fandom.com/wiki/Kishou_Arima
- https://www.oricon-group.com/news/2821/
- https://solo-leveling.fandom.com/wiki/Shadow_Extraction
- https://solo-leveling.fandom.com/wiki/Shadow_Exchange
- https://na.finalfantasyxvi.com/characters
