# POWER ENGINE INTERFACE CONTRACT — shared services Claude should implement

**Scope:** engine-agnostic pseudocode and design interfaces. You still must choose an engine (Unity/Unreal/Godot/Minecraft/etc.), target networking model, asset set and actual combat stats.

## Interfaces and events
```text
interface AbilityRunner:
    try_activate(actor, ability_id, target_or_point, input_context) -> Result
    cancel_instance(ability_instance_id, reason) -> Result

interface AbilityDefinition:
    id, owner_requirements, allowed_forms, trigger, target_filter
    handler_family, subeffects, timing, resource_costs, cooldown
    exception_rules, parameters, rng_seed_scope

interface EffectTransaction:
    begin(caster, ability, target) -> transaction_id
    validate() -> Result
    reserve_resources() -> reservation
    commit_once(event_id) -> Result
    cancel_and_rollback() -> Result

interface HitResolver:
    resolve_hit(hit_event, source, target, owned_hit_id)
    # order: eligible target -> defenses/immunities -> interceptors
    #        -> typed health/status/physics operations -> combat log

interface EventBus:
    pre_commit(event) -> reversible event
    on_commit(event) -> listener notification
    on_cancel(event) -> rollback cleanup

interface TemporalBuffer:
    record(entity, timestamp, whitelisted_fields)
    get_snapshot(entity, timestamp) -> snapshot or NONE
    restore_subset(entity, snapshot, field_mask)

interface OwnedEntityRegistry:
    register(owner, entity, source_ability, lifetime, persistence_policy)
    destroy_owned_instances(owner, ability_instance_id)

interface StatusController:
    add_instance(target, status, source_id, duration, stack_policy)
    remove_instance(target, source_id)
```

## State machine and safe sequencing
```text
IDLE -> WINDUP -> ACTIVE -> RECOVERY -> IDLE
              \-> INTERRUPTED -> CLEANUP -> IDLE
TRANSFORMING -> FORM_ACTIVE -> REVERTING -> IDLE
PASSIVE: EVENT_RECEIVED -> PREDICATE -> EFFECT -> IDLE
```

1. Ownership, form, actor condition, target restrictions, resource cost and cooldown are **server-validated**.
2. Animation timings define the active frames, not the visual effect alone.
3. Effect handlers create **owned, explicitly scoped instances**. Every projectile, field, summon, modifier and interception gets a unique `ability_instance_id`.
4. Collision checks use swept collision when appropriate; an entity/ability hit ledger prevents accidental duplicate damage from multiple colliders.
5. Damage, shield, immunity, time-rewind and delayed-settlement events are processed in a stable deterministic order. Rejected events are not applied and rolled back multiple times.
6. Every effect has `on_interrupt`, `on_expire`, `on_death`, `on_unload`, `on_save` behavior; world edits should be reversible unless permanent by design.
7. Resource spending should be transaction-safe. A network retry cannot create a second summon, an additional projectile fan or double cost.
8. Use authored data for conceptual/rule powers. Avoid turning a sentence like “rewrites reality” into unrestricted file/code execution.

## Example: a basic shard volley
```text
activate(caster, target, ability):
  assert caster.owns(ability) && caster.form.allows(ability)
  require target.is_valid && caster.has_cost(ability.cost)
  ability.begin_windup()
  on_cast_frame:
      for angle in spread_shots(count, spread_angle):
          projectile = spawn(caster.socket, angle)
          projectile.owner = caster
          projectile.on_swept_hit = (hit) => HitResolver.resolve_hit_once(hit)
  on_cancel_or_finish: end_attack_state()  # don't remove manifested kagune
```

## Example: temporal recall
```text
each_sim_tick:
  history.append(player, time, {position, health, eligible_statuses})
on_recall:
  snapshot = history.lookup(player, now - lookback)
  if snapshot is NONE: DENY
  safely_move_to(snapshot.position)
  restore_selected_fields(snapshot)  # NEVER clone inventory, XP, or other actors
```

## Example: delayed damage escrow
```text
on_cast(ally):
  ledger = register_temporary_ledger(ally)
  intercept all qualifying damage/heal events into ledger
on_effect_end:
  settle aggregated effects exactly once with defined ordering
  unregister interception before applying settlement (avoid recursion)
```

## Required automated tests (run per handler + character-specific exceptions)
- Invalid owner or form cannot cast a move; no cost is spent for invalid requests.
- Target / faction / immunity and resistance exceptions are checked for every effect.
- Cast interrupts and world unloading clean up modifiers, projectiles, summons, listeners and colliders.
- Multihit, overkill, invulnerability, reflection and piercing respect each ability's rule flags.
- Persistent state survives save/load without entity duplication, leaked timers or stale ownership.
- Parallel effects (time stop and rewind, counter and absorption, portal transit and teleport) are deterministically ordered.
- Network retries do not apply damage, resource loss or permanent world edits twice.
- Lore-specific preconditions and exact version mechanics are manually unit-tested once verified.
