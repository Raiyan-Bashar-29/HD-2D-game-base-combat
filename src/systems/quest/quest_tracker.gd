class_name QuestTracker
extends Node
## Turns flag changes into quest progress. The only thing in the game that reads quest data.
##
## IT KNOWS WHAT A STEP MEANS AND NOTHING ELSE. A step is a `GameEnums.FlagTest` against
## `Flags`, evaluated by `FlagQuery` — the same function a dialogue condition goes through — so
## this file has no idea what any objective IS. It watches one signal, `Events.flag_changed`,
## re-derives every quest, and announces the differences on `Events.quest_*`. Nothing in the
## world has to know the quest system exists: a conversation writes a met/ flag, a lever writes
## an unlocked flag, and a quest that tests either progresses. That is the trigger volume's
## rule — a trigger never names its consequence — applied to narrative state.
##
## DERIVED, EXCEPT FOR TWO LATCHES, AND THE ASYMMETRY IS THE DESIGN
## flags.gd's header says: if it can be derived, derive it. Almost all of this is derived.
## Two things cannot be:
##   - THAT A QUEST STARTED. Its start condition is a flag, and a game that resets that flag
##     must not un-give a quest the player has been carrying for three hours.
##   - THAT A QUEST COMPLETED. A step may test AT_LEAST 3 on a counter; if something later
##     decrements it, a finished quest would reopen. Completion is a fact about history, not
##     about the world right now.
## So exactly those two are latched, and they are exactly what the save section holds. The
## CURRENT STEP is not latched: it is a live question about the world, so a game that reopens
## the flag behind objective two sees objective two come back. That is a deliberate line, not an
## oversight — the alternative is a per-step latch, which doubles the saved state to remove a
## behaviour nobody has asked for.
##
## A COMPLETED QUEST GRANTS NOTHING. `Events.quest_completed` is emitted and that is all. A
## reward_item field would need `Inventory` and a player, both in the `gameplay` layer, and
## `src/` points downward only — see quest.gd's header.
##
## A NODE, NOT AN AUTOLOAD. Adding an autoload requires an ADR and this one would buy nothing:
## it has no init-order requirement and no interface the boot scene cannot give it. It lives
## under `GameRoot` beside `CatalogueReport`, so it outlives every area and every screen, and it
## is found the way `UiRoot` is found — by group, so a test or a tool can run without one.
##
## OWNS: which quests are active and complete, the current objective of each, and its own save
## section.
## MUST NOT: write a flag, grant anything, draw anything, or know what an objective means.

## The group this node joins, so a screen can find it without a hard path. Same mechanism as
## `UiRoot.GROUP`, for the same reason: the boot scene owns the tree shape, not its consumers.
const GROUP: StringName = &"quest_tracker"
const CATEGORY: String = "quest"
const SAVE_ID: StringName = &"quests"

## Toast keys. Engine-owned, so they live here rather than in any quest's .tres: a game that
## wants different wording edits the CSV row, not every quest it has authored.
const STARTED_KEY: String = "notify.quest.started"
const ADVANCED_KEY: String = "notify.quest.advanced"
const COMPLETED_KEY: String = "notify.quest.completed"

var _state: Dictionary[StringName, GameEnums.QuestState] = {}
var _step: Dictionary[StringName, StringName] = {}
## Re-entrancy guard, on the same reasoning as Director's. Nothing here writes a flag, but a
## listener on `quest_completed` legitimately might — starting the next chapter is the obvious
## case — and that would land back in `evaluate()` half way through this one.
var _evaluating: bool = false
## AND THE RE-ENTRANT CALL IS REMEMBERED RATHER THAN DROPPED, which is the whole of the fix
## below. Returning on a re-entrant call is only correct if the pass already running is going to
## see the flag that arrived; whether it does depends on where the newly-startable quest sits in
## `QuestDb.all()`, so a chapter that begins when the previous one ends used to start or not
## start according to the order the content directory happened to be scanned in. Silently, and
## with nothing able to see it: the demo has one quest, so it cannot chain, and `quests_test.gd`
## drives `evaluate()` directly rather than through `flag_changed`, which is the only path a
## re-entrant call can arrive on. `quest_chain_test.gd` is the case that goes through the signal.
var _pending: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	SaveSystem.register(SAVE_ID, _collect_save, _apply_save)
	Events.flag_changed.connect(_on_flag_changed)
	Events.game_started.connect(_on_game_started)
	Log.info(CATEGORY, "Quest tracker ready over %d quest(s)" % QuestDb.count())


func _exit_tree() -> void:
	SaveSystem.unregister(SAVE_ID)


## The tracker, found by group rather than by path. Returns null before the tree is built, which
## callers must handle: a dev tool or a test may run without one.
static func find(from: Node) -> QuestTracker:
	if from == null or not from.is_inside_tree():
		return null
	return from.get_tree().get_first_node_in_group(GROUP) as QuestTracker


func state_of(quest_id: StringName) -> GameEnums.QuestState:
	return _state.get(quest_id, GameEnums.QuestState.UNSTARTED)


## The objective to show for a quest, or null when it has not started or is finished. Asked
## LIVE, so it answers about the world as it is now rather than about a cached decision.
func current_step(quest_id: StringName) -> QuestStep:
	if state_of(quest_id) != GameEnums.QuestState.ACTIVE:
		return null
	var found: Quest = QuestDb.quest(quest_id)
	return _first_incomplete(found) if found != null else null


## HOW FAR ALONG A COUNTED STEP IS: (have, need), and `need == 0` for a step that is not a count.
## Asked live, exactly as `current_step` is.
##
## A PASS-THROUGH, AND THE ONE LINE IN IT IS THE POINT. `JournalScreen` must draw "2 / 3" and its
## MUST NOT line forbids it from reading a flag; `FlagQuery` can answer but is not something a
## screen should be reaching into either. So the screen asks the tracker, the tracker asks the
## closed set, and the seam the journal was built against does not widen. This file still has no
## idea that an item, an inventory or a count of anything exists - a counted step is a flag whose
## value happens to be a number, which is why the whole feature needed no field on `QuestStep`.
func step_progress(step: QuestStep) -> Vector2i:
	if step == null:
		return Vector2i.ZERO
	return FlagQuery.progress(step.condition_flag, step.condition_test, step.condition_value)


## Sorted, so the journal draws a stable order without holding one of its own. Sorted by id and
## not by "when it started", because start order is not saved and inventing one would be a
## second kind of state to keep consistent.
##
## `sort_custom` THROUGH `String`, NOT `sort()` — GOTCHA 33, AND THIS FILE WAS THE SITE IT WAS
## NEVER FIXED AT. `Array[StringName].sort()` orders by the StringName's interned handle rather
## than alphabetically, so "a stable order" was a claim this function did not deliver: the order
## was the allocator's, and it changed when anything else interned a name earlier in the boot.
## `area_db.gd`, `equipment.gd` and `inventory.gd` each carry this same note and each fixed it;
## the three of them are why the cause here was findable in a minute. Measured rather than
## reasoned: eight names built in scrambled order sorted to alpha, delta, echo, foxtrot,
## charlie, bravo, hotel, golf — neither alphabetical nor insertion order.
func ids_in_state(state: GameEnums.QuestState) -> Array[StringName]:
	var out: Array[StringName] = []
	for quest_id: StringName in _state:
		if _state[quest_id] == state:
			out.append(quest_id)
	out.sort_custom(_before)
	return out


func _before(a: StringName, b: StringName) -> bool:
	return String(a) < String(b)


## Re-derive every quest and announce what moved. Public so a test can drive it without a frame,
## and so a load can re-seed silently.
##
## announce = false seeds the latches and the current step WITHOUT emitting, which is what a
## restored save needs: the player is resuming three objectives in, and three toasts and three
## `quest_advanced` signals for progress they made an hour ago would be noise at best and a
## re-fired consequence at worst.
func evaluate(announce: bool = true) -> void:
	if _evaluating:
		_pending = true
		return
	_evaluating = true
	_pending = true
	## A chain can be no longer than the number of quests, because a quest advances at most once
	## per pass and never goes backwards — so the bound is DERIVED from the catalogue rather
	## than picked, and cannot go stale as a game authors its sixtieth quest. The margin is for
	## the settling pass that finds nothing left to do. Exceeding it means a listener is writing
	## a flag on every pass, which is a live loop and worth an error rather than a hang.
	var limit: int = QuestDb.count() + 2
	var passes: int = 0
	while _pending:
		_pending = false
		passes += 1
		if passes > limit:
			Log.error(CATEGORY, "did not settle in %d pass(es) — a listener is writing a flag "
					% limit + "every pass; abandoning")
			break
		for quest_id: StringName in QuestDb.all():
			_evaluate_one(QuestDb.quest(quest_id), announce)
	_evaluating = false


## Forget everything. A new game, and the suite between cases.
func reset() -> void:
	_state.clear()
	_step.clear()


func _evaluate_one(found: Quest, announce: bool) -> void:
	if found == null or state_of(found.id) == GameEnums.QuestState.COMPLETE:
		return
	var was_active: bool = state_of(found.id) == GameEnums.QuestState.ACTIVE
	if not was_active:
		if not FlagQuery.passes(found.condition_flag, found.condition_test, found.condition_value):
			return
		_state[found.id] = GameEnums.QuestState.ACTIVE
		_announce(announce, STARTED_KEY, found, Events.quest_started, [found.id])
	var step: QuestStep = _first_incomplete(found)
	if step == null:
		_state[found.id] = GameEnums.QuestState.COMPLETE
		_step.erase(found.id)
		_announce(announce, COMPLETED_KEY, found, Events.quest_completed, [found.id])
		return
	if _step.get(found.id, &"") == step.step_id:
		return
	_step[found.id] = step.step_id
	# Not on the frame a quest STARTS: the player was just told they have a new quest, and the
	# first objective is already on the journal page the toast points at.
	_announce(announce and was_active, ADVANCED_KEY, found, Events.quest_advanced,
			[found.id, step.step_id])


## One place both the signal and the toast are emitted, so a future quest kind cannot acquire
## one without the other. The toast is an ASK on the bus (`notify_requested`), which anyone may
## emit — this node still has no idea a screen exists.
func _announce(announce: bool, key: String, found: Quest, fact: Signal, args: Array) -> void:
	Log.info(CATEGORY, "%s: %s %s" % [found.id, key.get_slice(".", 2), str(args)])
	fact.emit.callv(args)
	if announce:
		Events.notify_requested.emit(key, 3.0, {"quest": tr(found.name_key)})


## The first step whose condition does not hold, walking authored order. Null means every step
## is satisfied, which is what completion IS — there is no separate "done" flag to forget to set.
func _first_incomplete(found: Quest) -> QuestStep:
	for step: QuestStep in found.steps:
		if step == null:
			continue
		if not FlagQuery.passes(step.condition_flag, step.condition_test, step.condition_value):
			return step
	return null


func _on_flag_changed(_flag: StringName, _value: Variant) -> void:
	evaluate()


func _on_game_started() -> void:
	reset()
	# Flags are already cleared at this point, so this only starts quests whose condition is
	# ALWAYS. Without it a tutorial objective would not appear until some unrelated flag moved.
	evaluate()


## IDS, NEVER ORDINALS. `GameEnums.QuestState` may gain a value or be reordered; a saved `1`
## would then mean something else in every existing save file. Two lists of quest ids cannot
## drift, and they are readable in the JSON beside the obj/ keys ADR-0005 writes.
##
## The CURRENT STEP IS NOT SAVED, because it is derived — see the header. A restored save
## re-derives it in `_apply_save` and does so silently.
func _collect_save() -> Dictionary:
	var active: Array[String] = []
	var complete: Array[String] = []
	for quest_id: StringName in _state:
		if _state[quest_id] == GameEnums.QuestState.COMPLETE:
			complete.append(String(quest_id))
		elif _state[quest_id] == GameEnums.QuestState.ACTIVE:
			active.append(String(quest_id))
	active.sort()
	complete.sort()
	return {"active": active, "complete": complete}


func _apply_save(data: Dictionary, _from_version: int) -> void:
	reset()
	_restore(DictRead.get_array(data, "active"), GameEnums.QuestState.ACTIVE)
	_restore(DictRead.get_array(data, "complete"), GameEnums.QuestState.COMPLETE)
	# SILENTLY: the latches are back, so this only fills in the derived current step and
	# promotes anything the player finished in a state the save predates.
	evaluate(false)
	Log.info(CATEGORY, "Restored %d quest(s)" % _state.size())


## A saved id the catalogue no longer has is DROPPED AND NAMED, not carried. Carrying it would
## put a quest in the journal that has no title, no summary and no steps; dropping it silently
## would hide that a .tres was deleted or renamed under an existing save.
func _restore(ids: Array, state: GameEnums.QuestState) -> void:
	for raw: Variant in ids:
		if not raw is String:
			continue
		var quest_id: StringName = StringName(raw as String)
		if not QuestDb.has(quest_id):
			Log.warn(CATEGORY, "Save names '%s', which no quest .tres declares" % quest_id)
			continue
		_state[quest_id] = state
