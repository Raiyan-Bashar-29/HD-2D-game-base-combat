extends SceneTree
## Content gate: the checks that catch a broken item, a duplicate object id, or a localization
## key that will render on screen as its own name.
##
## ITS SIBLING IS tools/check_boundary.gd, which asks the opposite question: this tool checks
## that the DEMO is well formed, that one checks that the ENGINE does not know the demo exists.
## Both must exit 0. They were one tool for about ten minutes, until check_budgets.gd refused
## the result at 252 of the 250 allowed code lines.
##
## RUN:  godot_console --headless --script tools/check_content.gd
## Exit 0 if clean, 1 on any violation. Safe in a commit hook next to check_budgets.gd.
##
## WHY IT CAN BE A --script TOOL AT ALL
## Because ItemDefinition and ItemDb touch no autoload. Under --headless --script the autoload
## *identifiers* do not resolve, so the moment anyone adds a Log call to a content class, this
## tool stops compiling and the gate fails. That is a real mechanical enforcement of the
## content-layer rule, not a style note. print() is used here for the same reason.
##
## WHAT IT DELIBERATELY DOES NOT CHECK
## Computed localization keys. interact_prompt.gd builds "verb.%s" and "refusal.%s" from enum
## names at runtime, and no text scan can follow that. Those are covered by an enum loop in
## tests/unit/items_test.gd, which is better verification than a scan could be. It also cannot
## report unused CSV keys, for the same reason: a key referenced only by computed name would
## look orphaned. And it is not a general hard-coded-string audit - telling a player-facing
## literal from a log message or a flag key needs semantics a text scan does not have, and a
## partial tool that looks complete is how 409 passing checks happened.
##
## MUST NOT: import a gameplay or ui class, or reference an autoload.

const CSV: String = "res://localization/strings.csv"
const AREA_ROOT: String = "res://scenes/areas"

var _violations: int = 0
var _keys: Dictionary[String, bool] = {}


func _initialize() -> void:
	print("")
	print("Content check")
	print("=".repeat(78))
	_load_keys()
	_report_scan()
	_check_items()
	_check_dialogue()
	_check_schedules()
	_check_quests()
	_check_areas()
	_check_path_actions()
	_check_scenes()
	print("=".repeat(78))
	if _violations > 0:
		print("FAIL — %d content violation(s)" % _violations)
		quit(1)
		return
	print("PASS")
	quit(0)


func _fail(message: String) -> void:
	_violations += 1
	print("  !! %s" % message)


## The CSV is parsed directly rather than through the engine's translation system, because
## that system is not available under --script and because a missing key must be detectable
## even when strings.en.translation has not been regenerated.
func _load_keys() -> void:
	var file: FileAccess = FileAccess.open(CSV, FileAccess.READ)
	if file == null:
		_fail("cannot open %s" % CSV)
		return
	var first: bool = true
	var columns: int = 0
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() == 0 or row[0] == "":
			continue
		if first:
			first = false
			columns = row.size()
			print("  localization columns: %d (%s)" % [columns, ", ".join(row)])
			continue
		_keys[row[0]] = true
		# A ROW THAT DISAGREES WITH THE HEADER MEANS AN UNQUOTED COMMA, and the value was silently
		# cut short at it. Nothing else catches this: the key still resolves, tr() still returns a
		# string, and the line just quietly loses its second half. WP-01 shipped a lever whose
		# toast ended at "Somewhere north" for three packages before a capture showed it.
		#
		# THE HEADER IS THE WIDTH, not the literal two this used to require. A game may add locale
		# columns - the template itself now has two - and hard-coding two would have made the
		# second language fail the gate that exists to protect the first. Equality rather than a
		# maximum, so a half-added locale that fills only some rows is caught as well.
		if row.size() != columns:
			_fail("%s has %d column(s) where the header has %d, so an unquoted comma has cut its text off at \"%s\"" % [
				row[0], row.size(), columns, row[1],
			])
	file.close()
	print("  localization keys: %d" % _keys.size())


## Records what the undocumented ResourceLoader.list_directory actually returned, so its
## behaviour stays a fact in the build log instead of an assumption in a comment.
func _report_scan() -> void:
	var raw: PackedStringArray = ResourceLoader.list_directory(ItemDb.content_dir)
	print("  list_directory(%s) -> %s" % [ItemDb.content_dir, str(raw)])
	print("  resolved paths        -> %s" % str(ContentScan.resource_paths(ItemDb.content_dir)))


func _check_items() -> void:
	ItemDb.rescan()
	for problem: String in ItemDb.problems():
		_fail(problem)
	print("  item definitions: %d" % ItemDb.count())
	for item_id: StringName in ItemDb.all():
		var definition: ItemDefinition = ItemDb.definition(item_id)
		print("     %-22s %-12s max_stack=%d" % [item_id, definition.category_name(), definition.max_stack])
		if not _keys.has(definition.name_key):
			_fail("%s name_key '%s' is not in the CSV" % [item_id, definition.name_key])
	_check_stray_definitions("res://data")


## An ItemDefinition outside data/items is the one silent failure this design admits: a Pickup
## can reference it by path while ItemDb never finds it, so can_accept refuses an item the
## player can plainly see.
func _check_stray_definitions(root: String) -> void:
	for directory: String in DirAccess.get_directories_at(root):
		var path: String = "%s/%s" % [root, directory]
		if path == ItemDb.content_dir:
			continue
		for file_name: String in DirAccess.get_files_at(path):
			if not file_name.ends_with(".tres"):
				continue
			var resource: Resource = ResourceLoader.load("%s/%s" % [path, file_name])
			if resource is ItemDefinition:
				_fail("%s/%s is an ItemDefinition outside %s" % [path, file_name, ItemDb.content_dir])



## Conversations get exactly the treatment items get, because ADR-0006's reasoning was never
## about items. The extra check here is the one a text scan cannot do: every text_key and
## speaker_key a conversation names must exist in the CSV, or the line renders on screen as its
## own key. Dangling node links are checked by Conversation.problems() itself.
func _check_dialogue() -> void:
	DialogueDb.rescan()
	for problem: String in DialogueDb.problems():
		_fail(problem)
	print("  conversations: %d" % DialogueDb.count())
	for talk_id: StringName in DialogueDb.all():
		var talk: Conversation = DialogueDb.conversation(talk_id)
		print("     %-22s %d nodes" % [talk_id, talk.nodes.size()])
		_check_conversation_keys(talk)


func _check_conversation_keys(talk: Conversation) -> void:
	for node: DialogueNode in talk.nodes:
		if node == null:
			continue
		var context: String = "%s/%s" % [talk.id, node.node_id]
		_require_key(context, "text_key", node.text_key)
		_require_key(context, "speaker_key", node.speaker_key)
		for choice: DialogueChoice in node.choices:
			if choice != null:
				_require_key(context, "choice text_key", choice.text_key)


## An empty key is not an error here - a narrator line with no speaker is legitimate, and
## node.problems() already refuses an empty text_key. What is an error is a key that names a
## CSV row which does not exist, because tr() silently returns the key itself.
func _require_key(context: String, field: String, key: String) -> void:
	if key == "" or _keys.has(key):
		return
	_fail("%s %s '%s' is not in the CSV" % [context, field, key])


## Schedules get the same treatment as items and conversations, plus the check no text scan can
## do: every waypoint a schedule names must exist as a marker in at least one area, or the NPC
## following it stands still forever and nothing says why.
func _check_schedules() -> void:
	ScheduleDb.rescan()
	for problem: String in ScheduleDb.problems():
		_fail(problem)
	print("  schedules: %d" % ScheduleDb.count())
	var known: Dictionary[StringName, bool] = _all_waypoint_names()
	for schedule_id: StringName in ScheduleDb.all():
		var schedule: NpcSchedule = ScheduleDb.schedule(schedule_id)
		print("     %-22s %d entries" % [schedule_id, schedule.entries.size()])
		for entry: ScheduleEntry in schedule.entries:
			if entry == null or entry.waypoint == &"":
				continue
			if not known.has(entry.waypoint):
				_fail("%s sends an NPC to '%s', which no area has a marker for" % [
					schedule_id, entry.waypoint,
				])


## Every waypoint name in every area, pooled. Pooled rather than per-area on purpose: a schedule
## does not name an area, so the only thing that can be checked here is that the name exists
## SOMEWHERE. An NPC in the wrong area for its schedule is a placement mistake this tool cannot
## see, and pretending otherwise would be the partial check that looks complete.
func _all_waypoint_names() -> Dictionary[StringName, bool]:
	var found: Dictionary[StringName, bool] = {}
	for directory: String in DirAccess.get_directories_at(AREA_ROOT):
		var path: String = "%s/%s/%s.tscn" % [AREA_ROOT, directory, directory]
		var packed: PackedScene = ResourceLoader.load(path) as PackedScene
		if packed == null:
			continue
		var area: Node = packed.instantiate()
		var markers: Node = area.get_node_or_null(^"Waypoints")
		if markers != null:
			for child: Node in markers.get_children():
				found[StringName(child.name)] = true
		area.free()
	return found


## Path actions are referenced by path, not found by scan, so there is no registry to validate.
## What CAN be validated is every .tres in data/actions: that it really is a PathAction, that its
## own problems() is empty, and that every key it names exists in the CSV. A path action that
## says nothing on success is a mechanic the player performs and cannot tell they performed.
func _check_path_actions() -> void:
	var directory: String = "res://data/actions"
	var files: PackedStringArray = ContentScan.resource_paths(directory)
	print("  path actions: %d" % files.size())
	for path: String in files:
		var resource: Resource = ResourceLoader.load(path)
		var action: PathAction = resource as PathAction
		if action == null:
			_fail("%s is not a PathAction" % path)
			continue
		var name: String = path.get_file()
		print("     %-24s %-11s standing %d/%d" % [
			name, action.verb_name(), action.required_standing, action.success_standing,
		])
		for problem: String in action.problems(name):
			_fail(problem)
		_require_key(name, "label_key", action.label_key)
		_require_key(name, "success_key", action.success_key)
		_require_key(name, "failure_key", action.failure_key)
		_require_key(name, "refusal_key", action.refusal_key)





## Quests get the same treatment as items, conversations and schedules, plus the two checks no
## text scan can do: every summary_key a quest or a step names must exist in the CSV, and every
## FLAG a step or a start condition tests is printed - because a step whose flag nothing in the
## game ever writes is a quest that can be started and can never be finished, and that is
## invisible until a player has walked the whole area looking for the thing to do.
##
## THE FLAGS ARE PRINTED, NOT VALIDATED, and the line is drawn there deliberately. A flag can be
## written from a scene, a conversation .tres, a path action or another quest, and the writers
## that matter most are runtime ones - `PersistentState` builds obj/<area>/<object>/<field> at
## load time. A checker that failed on any flag it could not find a writer for would be wrong
## most times it fired, and this project's rule is that a partial check which looks complete is
## worse than none. So the flags go in the build log where a reviewer can read them.
func _check_quests() -> void:
	QuestDb.rescan()
	for problem: String in QuestDb.problems():
		_fail(problem)
	print("  quests: %d" % QuestDb.count())
	for quest_id: StringName in QuestDb.all():
		var found: Quest = QuestDb.quest(quest_id)
		print("     %-22s %d steps, starts on %s" % [
			quest_id, found.steps.size(), _condition_text(found.condition_flag, found.condition_test,
				found.condition_value),
		])
		_require_key(String(quest_id), "name_key", found.name_key)
		_require_key(String(quest_id), "summary_key", found.summary_key)
		_check_quest_steps(found)


func _check_quest_steps(found: Quest) -> void:
	for step: QuestStep in found.steps:
		if step == null:
			continue
		var context: String = "%s/%s" % [found.id, step.step_id]
		print("        %-19s done when %s" % [
			step.step_id, _condition_text(step.condition_flag, step.condition_test,
				step.condition_value),
		])
		_require_key(context, "summary_key", step.summary_key)
		_check_item_count(context, step)


## THE ONE FLAG NAMESPACE THIS TOOL DOES VALIDATE, AND WHY THAT IS NOT A CONTRADICTION.
## Every other flag a quest names is PRINTED and not judged, for the reason above: a flag can be
## written from a scene, a conversation, a path action or at runtime, so failing on one with no
## findable writer would be wrong most times it fired. `bag/<carrier>/<item id>` is different in
## the one way that matters - IT HAS EXACTLY ONE WRITER, `Inventory._publish`, and half of the
## key is an item id that this tool can look up. So the two mistakes that produce a step nobody
## can ever finish are catchable here, and both are silent everywhere else:
##
##   - AN ITEM NO CATALOGUE HAS. The flag stays absent forever, the count reads zero, and the
##     objective sits in the journal for the rest of the game. A misspelled item id in a quest
##     is exactly as invisible as the misspelled `locked_key` WP-09 found.
##   - A COUNT OF ZERO, or a test that is not a count. `AT_LEAST 0` passes with an empty bag, so
##     the step is unconditional while READING as an errand; a bag flag under IS_TRUE is worse,
##     because `get_bool` on an int warns and answers false, so the step never passes at all.
##
## The carrier is NOT validated: a carrier id is an `@export` on a node in a scene this tool
## does not open, and a game may put a bag on an NPC or a stash. That omission is stated rather
## than papered over, which is the same line `_all_waypoint_names` draws.
func _check_item_count(context: String, step: QuestStep) -> void:
	if not BagKeys.is_bag_key(step.condition_flag):
		return
	var item_id: StringName = BagKeys.item_of(step.condition_flag)
	if not ItemDb.has(item_id):
		_fail("%s counts '%s', which no item .tres declares" % [context, item_id])
	var counted: bool = (step.condition_test == GameEnums.FlagTest.AT_LEAST
		or step.condition_test == GameEnums.FlagTest.EQUALS)
	if not counted:
		_fail("%s tests an item count with %s, which is not a count" % [
			context, _test_name(step.condition_test),
		])
	elif step.condition_value < 1:
		_fail("%s asks for %d of '%s'; a count below one is always satisfied" % [
			context, step.condition_value, item_id,
		])


## Areas on the world map get the same treatment as every other catalogue, plus the check no text
## scan can do: every name_key must exist in the CSV, or a dot on the map is labelled with its own
## key. The MAP POSITION is printed rather than judged -- whether two places overlap is a design
## question about a map this tool has never seen the size of, and a checker that guessed would be
## the partial check that looks complete.
##
## THAT THE AREA HAS A SCENE IS NOT CHECKED HERE, and the omission is the same one `area_def.gd`
## states: the id becomes a path through `Director.AREA_PATH_TEMPLATE`, the one place that knows
## the shape, and `Director` is an autoload this tool cannot reach under `--script`.
## `tests/unit/world_map_test.gd` asserts it, where the autoload resolves.
func _check_areas() -> void:
	AreaDb.rescan()
	for problem: String in AreaDb.problems():
		_fail(problem)
	print("  mapped areas: %d" % AreaDb.count())
	for area_id: StringName in AreaDb.ids():
		var def: AreaDef = AreaDb.area(area_id)
		print("     %-22s at %s, arrive at '%s'%s" % [
			area_id, def.map_position, def.arrival_spawn,
			", known from the start" if def.known_from_start else "",
		])
		_require_key(String(area_id), "name_key", def.name_key)


## A condition as one readable phrase for the build log.
##
## THE VALUE IS PRINTED FOR THE TESTS THAT USE ONE, which the first version of this omitted -
## `AT_LEAST` and `EQUALS` both compare against a number, and a log line reading
## `bag/player/item/x at_least` says nothing about the errand a reviewer is checking. IS_TRUE and
## IS_FALSE ignore the field, so printing a 0 beside them would invite the reader to wonder what
## it does.
func _condition_text(flag: StringName, test: GameEnums.FlagTest, value: int = 0) -> String:
	if test == GameEnums.FlagTest.ALWAYS:
		return _test_name(test)
	if test == GameEnums.FlagTest.IS_TRUE or test == GameEnums.FlagTest.IS_FALSE:
		return "%s %s" % [flag, _test_name(test)]
	return "%s %s %d" % [flag, _test_name(test), value]


## `.keys()` yields a Variant, so the enum name goes through a typed local before use - this
## project compiles with unsafe access as an error.
func _test_name(test: GameEnums.FlagTest) -> String:
	var names: Array = GameEnums.FlagTest.keys()
	var found: String = names[test]
	return found.to_lower()


## The scene text scans, which live in tools/content_scenes.gd. Split out in WP-08 when this file
## stood at 237 of its 250 lines and the quest checks did not fit; the seam was already in the
## reasoning - see that file's header. Still ONE command and ONE CI rung, because a second
## SceneTree tool would be a second thing to forget to run.
func _check_scenes() -> void:
	var scenes := ContentSceneChecks.new()
	scenes.run(_keys)
	print("  scenes scanned: %d" % scenes.scanned)
	for problem: String in scenes.failures:
		_fail(problem)
