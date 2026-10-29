class_name Speaker
extends Interactable
## Something you can talk to. A plaque, a parrot, or eventually an NPC.
##
## IT NAMES A CONVERSATION ID AND NOTHING ELSE, exactly as `AreaDoor` names an area id. It does
## not know what is said, what the conversation changes, or that a dialogue box exists. That
## keeps the fiftieth speaker in the game a `.tscn` override and a `.tres` file with no code at
## all, which is the same test `ItemDb` and `DialogueDb` are built to pass.
##
## SINCE T5.14 IT ALSO ASKS FOR A TURN, and that sentence above is still true of the DATA it
## carries: no second export, no second id. What it gained is a three-line ask on the bus so
## the person you talk to looks at you, which needs nothing authored and nothing configured.
##
## WHY IT GOES THROUGH THE BUS. `Speaker` is in the gameplay layer and the dialogue box is in
## the ui layer, and dependencies here point downward only: gameplay must not name a screen.
## So it emits `Events.dialogue_requested` and stops, exactly as `AreaDoor` emits
## `area_change_requested` rather than loading an area itself. `ScreenKeys` listens, because it
## is already the one place a thing becomes a screen.
##
## NO "ALREADY TALKING" REFUSAL, deliberately. It cannot happen: `InteractionSensor` takes its
## own `&"dialogue"` token on `Events.dialogue_started`, so while a conversation is open the
## sensor is suspended and this object cannot be attempted at all. A guard here would be a
## second answer to a question WP-02 already answered once.
##
## OWNS: which conversation it offers, and refusing when it has none.
## MUST NOT: read dialogue data beyond checking that its id resolves, read or write a flag,
## open a screen, or know what a dialogue box contains.

## The conversation to open. Must match data/dialogue/<name>.tres, whose id is `talk/<name>`.
@export var conversation_id: StringName = &""


func _ready() -> void:
	verb = GameEnums.InteractVerb.TALK
	super()
	if conversation_id == &"":
		Log.error("dialogue", "%s names no conversation and will refuse every attempt" % name)
	elif not DialogueDb.has(conversation_id):
		# Loud at load, not at use. A speaker whose conversation was renamed must not look like
		# scenery until a player walks the length of the map to try it.
		Log.error("dialogue", "%s offers '%s', which does not exist" % [name, conversation_id])


## STORY_GATED when there is nothing to say: a refusal with a message rather than a silent
## no-op, on the same reasoning that makes a locked gate keep offering its prompt.
func refusal(_who: Node3D) -> GameEnums.RefusalReason:
	if conversation_id == &"" or not DialogueDb.has(conversation_id):
		return GameEnums.RefusalReason.STORY_GATED
	return GameEnums.RefusalReason.NONE


func perform(who: Node3D) -> void:
	Log.info("dialogue", "%s asks for '%s'" % [name, conversation_id])
	_turn_to_whoever_spoke(who)
	Events.dialogue_requested.emit(conversation_id)


## LOOK AT WHOEVER SPOKE, IF THERE IS ANYBODY HERE TO LOOK. A `Speaker` on a plaque has no
## character above it and asks for nothing; a `Speaker` on a person asks the bus to turn that
## person towards the one who started the conversation.
##
## THIS IS THE WHOLE OF WHAT IT KNOWS ABOUT THE BODY IT HANGS UNDER: that it is a
## `CharacterBody3D`, which is the engine's word and not this game's. It does not know the body
## has a brain, a schedule, a visual or a sprite - `Events.turn_requested` carries the node and
## whatever draws that node decides what a turn means. `NpcBrain` is not named here and must
## not be: the same three lines turn a talking statue, a parrot or the player.
##
## AND IT DOES NOT NEED UNDOING WHEN THE CONVERSATION ENDS. A standing character keeps the
## facing it was last given, so the NPC is still looking at the player when the box closes -
## which is the behaviour anybody would want and costs no listener to get.
func _turn_to_whoever_spoke(who: Node3D) -> void:
	if who == null:
		return
	var character: CharacterBody3D = _character()
	if character == null:
		return
	Events.turn_requested.emit(character, who.global_position)


## The character this speaker is attached to, or null when it is attached to scenery. Walks up
## rather than reading `get_parent()`, so a game may nest its speaker under an offset marker.
func _character() -> CharacterBody3D:
	var walker: Node = get_parent()
	while walker != null:
		if walker is CharacterBody3D:
			return walker as CharacterBody3D
		walker = walker.get_parent()
	return null
