extends TestCase
## The combat data a game ships, checked the way upstream's `check_content.gd` checks its own:
## every name a player will read has a row in `strings.csv`, and every encounter, skill and
## status is sound. Since C2.20 that includes status names and command categories.
##
## WHY A TEST AND NOT A CHECKER. The fork keeps upstream's tools untouched (ADR-0008), so the
## combat equivalent lives here. It reads `data/` directly, so the stripped template, which has
## deleted `data/`, simply finds nothing to check.
##
## IN PLAIN WORDS: if a skill, fighter or command in the data names a translation key that was
## never added to the CSV, the player would see the raw key on screen. This catches it.
##
## OWNS: assertions about the translation keys and soundness of the combat data under `data/`.
## MUST NOT: name a game's content. It walks whatever the directories hold.

const CSV: String = "res://localization/strings.csv"
const SKILL_DIR: String = "res://data/skills"
const ENCOUNTER_DIR: String = "res://data/encounters"
const PARTY_DIR: String = "res://data/party"
const STATUS_DIR: String = "res://data/statuses"
## The action formula's data (C3.10): loadouts, enemy definitions and enemy brains, side by side.
const ACTION_DIR: String = "res://data/action"

var _csv: Dictionary[String, bool] = {}


func run() -> void:
	_csv = _csv_keys()
	# Every key the data names, with where it was found, so a failure says which file to fix.
	var named: Dictionary[String, String] = {}
	# Everything `problems()` says is wrong with a skill or status, with where it came from.
	var wrong: PackedStringArray = PackedStringArray()
	for skill: Resource in _load_all(SKILL_DIR):
		_from_skill(skill as Skill, named)
		wrong.append_array((skill as Skill).problems())
	for status: Resource in _load_all(STATUS_DIR):
		_from_status(status as StatusEffect, named)
		wrong.append_array((status as StatusEffect).problems())
	for encounter: Resource in _load_all(ENCOUNTER_DIR):
		for def: CombatantDef in (encounter as Encounter).enemies:
			_from_def(def, named)
	for roster: Resource in _load_all(PARTY_DIR):
		for def: CombatantDef in (roster as PartyRoster).members:
			_from_def(def, named)
	for action: Resource in _load_all(ACTION_DIR):
		_from_action(action, named, wrong)
	plan(5 + named.size())
	equal("the CSV was read", _csv.size() > 0, true)
	equal("a key nobody wrote is not found", _known("fixture.never_written"), false)
	equal("every encounter under data/ is sound", EncounterDb.problems(), PackedStringArray())
	equal("every skill, status and action resource under data/ is sound", wrong, PackedStringArray())
	equal("the status catalogue is sound", StatusDb.problems(), PackedStringArray())
	for key: String in named:
		equal("%s names '%s', which is in strings.csv" % [named[key], key], _known(key), true)


## One file from the action folder, whichever of the three shapes it is. An unknown shape is
## reported, so a stray resource cannot sit there unchecked.
func _from_action(action: Resource, named: Dictionary[String, String], wrong: PackedStringArray) -> void:
	var where: String = action.resource_path
	if action is ActionLoadout:
		wrong.append_array((action as ActionLoadout).problems(where))
		if (action as ActionLoadout).fighter != null:
			_from_def((action as ActionLoadout).fighter, named)
	elif action is CombatantDef:
		wrong.append_array((action as CombatantDef).problems(where))
		_from_def(action as CombatantDef, named)
	elif action is ActionBrain:
		wrong.append_array((action as ActionBrain).problems(where))
	else:
		wrong.append("%s is not a loadout, a fighter or a brain" % where)


func _known(key: String) -> bool:
	return _csv.has(key)


## The first column of every row after the header, parsed as text: `check_strings.gd`'s way.
func _csv_keys() -> Dictionary[String, bool]:
	var keys: Dictionary[String, bool] = {}
	var lines: PackedStringArray = FileAccess.get_file_as_string(CSV).split("\n")
	for i: int in range(1, lines.size()):
		var comma: int = lines[i].find(",")
		if comma > 0:
			keys[lines[i].substr(0, comma)] = true
	return keys


## Every `.tres` in `directory`, loaded. A missing directory is no content, not a failure.
func _load_all(directory: String) -> Array[Resource]:
	var found: Array[Resource] = []
	if not DirAccess.dir_exists_absolute(directory):
		return found
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.ends_with(".tres"):
			var loaded: Resource = ResourceLoader.load(directory.path_join(file_name))
			if loaded != null:
				found.append(loaded)
	return found


## A skill's name, and the names of the statuses it leaves or toggles.
func _from_skill(skill: Skill, named: Dictionary[String, String]) -> void:
	if skill == null:
		return
	if skill.name_key != "":
		named[skill.name_key] = String(skill.id)
	for status: StatusEffect in skill.statuses:
		_from_status(status, named)
	_from_status(skill.toggle_status, named)


func _from_status(status: StatusEffect, named: Dictionary[String, String]) -> void:
	if status != null and status.name_key != "":
		named[status.name_key] = String(status.id)


## A fighter's own name, its commands' labels, and the names of the skills those commands use.
func _from_def(def: CombatantDef, named: Dictionary[String, String]) -> void:
	if def == null:
		return
	if def.name_key != "":
		named[def.name_key] = String(def.combatant_id)
	for command: BattleCommand in def.commands:
		if command == null:
			continue
		if command.label_key != "":
			named[command.label_key] = String(def.combatant_id)
		if command.category != "":
			named[command.category] = String(def.combatant_id)
		_from_skill(command.skill, named)
