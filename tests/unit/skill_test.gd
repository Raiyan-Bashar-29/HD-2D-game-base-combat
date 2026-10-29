extends TestCase
## `Skill`, `BattleCommand` and `SkillDb`: what an author can get wrong in each, a scan, and the
## combat fork's half of `check_content`: every skill and status under `data/` is sound.
##
## OWNS: assertions about combat content, and the content check upstream's checker cannot make.
## MUST NOT: name a game's skills or statuses. The last two cases scan whatever `data/` holds,
## and pass with none, so the stripped template passes them too.


func run() -> void:
	plan(14)
	_skill_problems()
	_command_problems()
	_a_scan_finds_skills_by_id()
	_the_shipped_content_is_sound()


func _sound() -> Skill:
	var skill := Skill.new()
	skill.id = &"skill/fixture_bolt"
	skill.name_key = "fixture.bolt"
	skill.cost_pool = &"mp"
	skill.cost = 4
	skill.power = 12.0
	return skill


func _says(found: PackedStringArray, text: String) -> bool:
	for problem: String in found:
		if problem.contains(text):
			return true
	return false


func _skill_problems() -> void:
	equal("a sound skill has no problems", _sound().problems(), PackedStringArray())
	var unnamed := _sound()
	unnamed.name_key = ""
	equal("a skill with no name is caught", _says(unnamed.problems(), "no name_key"), true)
	var unpaid := _sound()
	unpaid.cost_pool = &""
	equal("a cost with no pool is caught", _says(unpaid.problems(), "no cost_pool"), true)
	var idle := _sound()
	idle.power = 0.0
	equal("a skill that does nothing is caught", _says(idle.problems(), "does nothing"), true)
	var kind := _sound()
	kind.power = -10.0
	equal("a heal aimed at enemies is caught", _says(kind.problems(), "heals its enemies"), true)
	var holed := _sound()
	holed.statuses = [null]
	equal("an empty status slot is caught", _says(holed.problems(), "empty status"), true)


func _command_problems() -> void:
	var attack := BattleCommand.new()
	equal("an ATTACK needs nothing more", attack.problems("fixture"), PackedStringArray())
	var empty_skill := BattleCommand.new()
	empty_skill.kind = BattleCommand.Kind.SKILL
	equal("a SKILL command with no skill is caught", _says(empty_skill.problems("fixture"), "names no skill"), true)
	var item := BattleCommand.new()
	item.kind = BattleCommand.Kind.ITEM
	item.skill = _sound()
	equal("an ITEM command with no item is caught", _says(item.problems("fixture"), "no item_id"), true)
	var carried := BattleCommand.new()
	carried.kind = BattleCommand.Kind.SKILL
	carried.skill = _sound()
	carried.skill.name_key = ""
	equal("a command reports its skill's problems", _says(carried.problems("fixture"), "no name_key"), true)


func _a_scan_finds_skills_by_id() -> void:
	var directory: String = RunScratch.path("skills")
	DirAccess.make_dir_recursive_absolute(directory)
	ResourceSaver.save(_sound(), directory.path_join("fixture_bolt.tres"))
	var misnamed := _sound()
	misnamed.id = &"skill/fixture_other"
	ResourceSaver.save(misnamed, directory.path_join("fixture_misnamed.tres"))
	SkillDb.content_dir = directory
	SkillDb.rescan()
	var found: Skill = SkillDb.skill(&"skill/fixture_bolt")
	equal("a scan finds a skill by its id", found != null and found.power == 12.0, true)
	equal("and reports a file whose id disagrees with its name", _says(SkillDb.problems(), "fixture_misnamed"), true)
	SkillDb.content_dir = SkillDb.SKILL_DIR
	SkillDb.rescan()


func _the_shipped_content_is_sound() -> void:
	equal("every skill under data/ is sound", SkillDb.problems(), PackedStringArray())
	StatusDb.content_dir = StatusDb.STATUS_DIR
	StatusDb.rescan()
	equal("every status under data/ is sound", StatusDb.problems(), PackedStringArray())
