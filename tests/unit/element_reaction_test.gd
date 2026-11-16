extends TestCase
## Elemental reactions (C8.4). A reaction file names two elements; a hit carrying one marks its
## target, and a later hit carrying the other reacts: more damage, the reaction's status, the mark
## used up, and an announcement. An element no reaction names leaves no mark; a real-time fighter
## is marked in seconds; a saved mark is found again.
##
## OWNS: assertions about `ElementReaction`, `ReactionDb` and `ElementReactions`.
## MUST NOT: name a game's elements or reactions, or wait for frames. The reaction files are
## written to this run's scratch directory.

const FIRE: StringName = &"fixture_heat"
const ICE: StringName = &"fixture_frost"
const PLAIN: StringName = &"fixture_plain"
const MELT: StringName = &"reaction/fixture_melt"
const DAZED: StringName = &"status/fixture_reaction_dazed"

var _reacted: Array = []


func run() -> void:
	plan(6)
	_write_content()
	equal("the scratch reaction is sound; one with one element and no name is flagged twice",
		[ReactionDb.problems().size(), ReactionDb.naming(ICE).size(), ElementReaction.new().problems().size()],
		[0, 1, 2])
	var target: Combatant = _fighter(false)
	var statuses: StatusSet = StatusSet.of(target.get_parent())
	ElementReactions.land(target, _hit(PLAIN, 10.0))
	ElementReactions.land(target, _hit(FIRE, 10.0))
	equal("an element no reaction names leaves no mark; one a reaction names does",
		[statuses.stacks(ElementReactions.mark(PLAIN, false).id), statuses.stacks(ElementReactions.mark(FIRE, false).id)],
		[0, 1])
	Events.elements_reacted.connect(_on_reacted)
	var vitals: Vitals = Vitals.of(target.get_parent())
	var before: int = vitals.current(&"hp")
	target.receive(_hit(ICE, 10.0), &"fixture_attacker")
	Events.elements_reacted.disconnect(_on_reacted)
	equal("the other element reacts: half again the damage, its status, the mark used up, announced",
		[before - vitals.current(&"hp"), statuses.stacks(DAZED), statuses.stacks(ElementReactions.mark(FIRE, false).id),
			_reacted], [15, 1, 0, [[target.combatant_id, MELT]]])
	equal("with no mark left, the next hit only marks again",
		[ElementReactions.land(target, _hit(FIRE, 10.0)), statuses.stacks(ElementReactions.mark(FIRE, false).id)], [null, 1])
	var quick: Combatant = _fighter(true)
	ElementReactions.land(quick, _hit(ICE, 5.0))
	var held: StatusEffect = ElementReactions.mark(ICE, true)
	equal("a real-time fighter is marked in seconds",
		[StatusSet.of(quick.get_parent()).stacks(held.id), held.unit], [1, StatusEffect.Unit.SECONDS])
	equal("a saved mark is found by its id; another id is not",
		[ElementReactions.built_in(held.id) == held, ElementReactions.built_in(&"status/fixture_other")], [true, null])
	ReactionDb.content_dir = ReactionDb.REACTION_DIR
	ReactionDb.rescan()


func _on_reacted(who: StringName, reaction_id: StringName) -> void:
	_reacted.append([who, reaction_id])


func _hit(element: StringName, amount: float) -> DamageResult:
	var result := DamageResult.new()
	result.element = element
	result.amount = amount
	return result


func _fighter(real_time: bool) -> Combatant:
	var body := Node3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = &"fixture_reaction_rt" if real_time else &"fixture_reaction_target"
	fighter.real_time = real_time
	fighter.base_stats = {&"max_hp": 100.0, &"attack": 1.0}
	body.add_child(fighter)
	attach(body)
	return fighter


func _write_content() -> void:
	var directory: String = RunScratch.path("reactions")
	DirAccess.make_dir_recursive_absolute(directory)
	var dazed := StatusEffect.new()
	dazed.id = DAZED
	dazed.duration = 1.0
	var melt := ElementReaction.new()
	melt.id = MELT
	melt.name_key = "fixture.name"
	melt.first = FIRE
	melt.second = ICE
	melt.status = dazed
	ResourceSaver.save(melt, directory.path_join("fixture_melt.tres"))
	ReactionDb.content_dir = directory
	ReactionDb.rescan()
