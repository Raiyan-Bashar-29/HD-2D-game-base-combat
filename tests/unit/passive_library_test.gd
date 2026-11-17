extends TestCase
## The sample passive library (C9.3b): every file a game ships under its passive directory can
## be held by one fighter at once, puts its held status on, and comes off cleanly.
##
## IN PLAIN WORDS: the other passive tests build their own passives. This one loads the REAL
## files, whatever they are, so a file that loads but breaks when held is caught. A stripped
## template has no files, and the case then skips and says so.
##
## OWNS: assertions about the files under `PassiveDb.PASSIVE_DIR`, taken as a whole.
## MUST NOT: name any one passive, or wait for frames.

const HOLDER: StringName = &"fixture_library_holder"


func run() -> void:
	plan(3)
	var library: Array[PassiveSkill] = _library()
	if library.is_empty():
		skip("the passive library", "this template ships no passives", 3)
		return
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	var broken: int = 0
	var held: int = 0
	for passive: PassiveSkill in library:
		broken += passive.problems().size()
		held += 1 if passive.held != null else 0
	equal("every passive in the library is sound", broken, 0)
	var body: Node3D = _holder()
	var def := CombatantDef.new()
	def.passives = library
	PassiveLending.own(body, def)
	equal("one fighter holds the whole library, and every held status is on",
		[PassiveSet.of(body).passives().size(), _on(body, library)], [library.size(), held])
	PassiveMoments.skill(Combatant.of(body), [])
	def.passives = []
	PassiveLending.own(body, def)
	equal("released, no passive and no held status is left",
		[PassiveSet.of(body).sources().size(), _on(body, library)], [0, 0])
	body.free()
	Flags.clear_all()


func _library() -> Array[PassiveSkill]:
	var found: Array[PassiveSkill] = []
	if not DirAccess.dir_exists_absolute(PassiveDb.PASSIVE_DIR):
		return found
	for path: String in ContentScan.resource_paths(PassiveDb.PASSIVE_DIR):
		var passive: PassiveSkill = load(path) as PassiveSkill
		if passive != null:
			found.append(passive)
	return found


func _on(body: Node3D, library: Array[PassiveSkill]) -> int:
	var count: int = 0
	for passive: PassiveSkill in library:
		if passive.held != null:
			count += StatusSet.of(body).stacks(passive.held.id)
	return count


func _holder() -> Node3D:
	var body := Node3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = HOLDER
	fighter.base_stats = {&"max_hp": 40.0, &"max_mp": 40.0, &"attack": 2.0}
	body.add_child(fighter)
	attach(body)
	return body
