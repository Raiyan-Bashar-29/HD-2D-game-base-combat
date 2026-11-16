extends TestCase
## What saves and flights keep (C8.19a). Who applied a status survives a save and a load; a flight
## brings home what the party stole and nothing else; a thing that `stays_broken` is gone on
## re-entry once broken, and one that does not comes back.
##
## OWNS: assertions about `StatusSet`'s saved applier, `Rewards.grant` on FLED and
## `ArenaThing.stays_broken`.
## MUST NOT: name a game's kits, items or characters.

const LOOT: StringName = &"fixture_stolen_thing"


func run() -> void:
	plan(4)
	SaveFixture.activate()
	Flags.clear_all()
	_applier()
	_flight()
	_broken()
	Flags.clear_all()


func _applier() -> void:
	var actor := Node3D.new()
	var statuses := StatusSet.new()
	statuses.owner_id = &"fixture_keeper"
	actor.add_child(statuses)
	attach(actor)
	var effect: StatusEffect = Weakness.pressured_status()
	statuses.apply(effect, null, &"fixture_caster")
	var saved: Dictionary = statuses._collect_save()
	statuses._apply_save(saved, 1)
	equal("who applied a status survives a save and a load", statuses.applier(effect.id), &"fixture_caster")
	actor.free()


func _flight() -> void:
	var holder := Node.new()
	attach(holder)
	var hero := CombatantDef.new()
	hero.combatant_id = &"fixture_flee_hero"
	hero.name_key = "fixture.name"
	hero.faction = &"side_a"
	hero.base_stats = {&"max_hp": 50.0, &"speed": 9.0}
	var foe := CombatantDef.new()
	foe.combatant_id = &"fixture_flee_foe"
	foe.name_key = "fixture.name"
	foe.faction = &"side_b"
	foe.base_stats = {&"max_hp": 50.0, &"speed": 1.0}
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_flee"
	encounter.enemies = [foe]
	encounter.experience = 10
	encounter.loot = [&"fixture_loot_thing"]
	var battle: Battle = BattleSetup.build(encounter, [hero], holder, RandomNumberGenerator.new())
	battle.next_turn()
	battle.party[0].spoils.append(LOOT)
	var flee := BattleCommand.new()
	flee.kind = BattleCommand.Kind.FLEE
	battle.act(flee, [])
	var given: Rewards = Rewards.grant(battle, encounter, null)
	equal("a flight keeps the spoils and nothing else", [given.items + given.left_behind, given.experience], [[LOOT], 0])
	BattleSetup.release(battle)
	holder.free()


func _broken() -> void:
	var world := Node3D.new()
	attach(world)
	var kept: ArenaThing = _thing(world, &"thing/fixture_kept_broken", true)
	var back: ArenaThing = _thing(world, &"thing/fixture_comes_back", false)
	Vitals.of(kept).set_to(&"hp", 0)
	Vitals.of(back).set_to(&"hp", 0)
	var again: ArenaThing = _thing(world, &"thing/fixture_kept_broken", true)
	var other: ArenaThing = _thing(world, &"thing/fixture_comes_back", false)
	equal("a thing that stays broken is gone on re-entry", again.is_queued_for_deletion(), true)
	equal("one that does not comes back", other.is_queued_for_deletion(), false)
	world.free()


func _thing(world: Node3D, id: StringName, stays: bool) -> ArenaThing:
	var thing := ArenaThing.new()
	thing.thing_id = id
	thing.hp = 5.0
	thing.stays_broken = stays
	world.add_child(thing)
	return thing
