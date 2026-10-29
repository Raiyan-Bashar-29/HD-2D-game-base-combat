class_name PathActionPoint
extends Interactable
## One path action, offered on one person. A `Speaker` you can scrutinise instead of talk to.
##
## ONE NODE PER ACTION, AND NO MENU. An NPC offering three actions is three overlapping
## `Interactable`s, which the player selects between with the ranking and Tab-cycling the
## interaction sensor has had since Phase 0 — the exact case its header describes as "stand
## where a sign, a lever and a door all overlap and the game must pick the one the player
## means". A path-action menu would be a second selection mechanism competing with that one,
## with its own focus handling and its own screen, to solve a problem already solved.
##
## STANDING IS READ FROM THE PERSON, NOT FROM THIS NODE. `standing_id` names the NPC, so three
## actions on one keeper all move the same number, and moving that keeper to another area does
## not reset it. This node holds no standing of its own for the same reason a `Gate` holds no
## inventory: the fact belongs to whoever it is about.
##
## OWNS: offering one action, refusing it, and applying its outcome.
## MUST NOT: contain the action's data (that is the `.tres`), decide what standing means, draw
## anything, or know that a dialogue box exists.

## The authored action. Without one this node refuses everything and says so at load.
@export var action: PathAction = null
## Which person's standing this action reads and moves. Usually the NPC that owns this node.
@export var standing_id: StringName = &""

const DONE_FIELD: StringName = &"done"

## Emitted after the action resolves, with whether it succeeded. Local listeners only; the bus
## carries the flag change and the toast.
signal resolved(success: bool)


func _ready() -> void:
	if action != null:
		verb = action.verb
		if label_key == "":
			label_key = action.label_key
	super()
	if action == null:
		Log.error("interact", "%s has no PathAction and will refuse everything" % name)
	elif standing_id == &"":
		Log.error("interact", "%s names no standing_id, so its outcome would move nobody" % name)
	# Restore before the first frame is drawn, so an action the player already performed is
	# never briefly on offer again.
	if is_done():
		set_available(false)


## Refusals happen BEFORE anything and cost nothing. Order matters: a missing item is reported
## before low standing, because "you need the ledger" is actionable and "they do not trust you
## enough" is not, and telling the player the harder thing first reads as a dead end.
func refusal(who: Node3D) -> GameEnums.RefusalReason:
	if action == null or standing_id == &"":
		return GameEnums.RefusalReason.STORY_GATED
	if is_done():
		return GameEnums.RefusalReason.ALREADY_DONE
	if action.requires_item != &"" and not _carried_by(who):
		return GameEnums.RefusalReason.MISSING_ITEM
	if not Standing.at_least(standing_id, action.required_standing):
		return GameEnums.RefusalReason.LOW_STANDING
	return GameEnums.RefusalReason.NONE


## Past this point the action has been COMMITTED, so it can no longer refuse — it either works
## or it fails, and either way standing moves and the player is told which happened.
func perform(_who: Node3D) -> void:
	var before: int = Standing.of(standing_id)
	var success: bool = action.succeeds_at(before)
	var after: int = Standing.change(
		standing_id, action.standing_on_success if success else action.standing_on_failure)

	if success:
		if action.success_flag != &"":
			Flags.set_flag(action.success_flag, true)
		# `once` applies to SUCCESS only. A failed attempt must remain repeatable, or a single
		# early failure would lock the player out of the action forever with no way back.
		if action.once:
			_mark_done()
	_announce(success)
	Log.info("interact", "%s %s on '%s': standing %d -> %d" % [
		action.verb_name(), "succeeded" if success else "FAILED", standing_id, before, after,
	])
	resolved.emit(success)


## True once this action has been performed successfully, across saves.
func is_done() -> bool:
	var store: PersistentState = state()
	return store != null and store.fetch_bool(DONE_FIELD)


## Names the standing and the item in the refusal message, so LOW_STANDING can say how far short
## the player is instead of leaving them to guess.
func refusal_args(who: Node3D) -> Dictionary:
	if action == null:
		return {}
	if action.requires_item != &"" and not _carried_by(who):
		var definition: ItemDefinition = ItemDb.definition(action.requires_item)
		return {"item": tr(definition.name_key)} if definition != null else {}
	return {"standing": Standing.of(standing_id), "needed": action.required_standing}


func _announce(success: bool) -> void:
	var key: String = action.success_key if success else action.failure_key
	if key != "":
		Events.notify_requested.emit(key, 3.0, {"standing": Standing.of(standing_id)})


func _mark_done() -> void:
	var store: PersistentState = state()
	if store != null:
		store.store(DONE_FIELD, true)
	set_available(false)


## Asks whoever is interacting, never the player and never a global inventory — the same
## reasoning that lets a gate be opened by an NPC or a follower.
func _carried_by(who: Node3D) -> bool:
	var bag: Inventory = Inventory.of(who)
	return bag != null and bag.has(action.requires_item)


## Same unwired field, same fix as `Gate.locked_key`: `PathAction.refusal_key`'s own comment
## claimed it was "shown for the LOW_STANDING refusal", and nothing read it. Found while wiring
## the gate; left half-done it would have been a second latent one.
func refusal_key(_who: Node3D, reason: GameEnums.RefusalReason) -> String:
	if action == null or reason != GameEnums.RefusalReason.LOW_STANDING:
		return ""
	return action.refusal_key
