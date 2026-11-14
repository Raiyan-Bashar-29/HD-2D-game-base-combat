class_name LoadoutHost
extends Node
## Opens the passive loadout screen (C9.7) when its key is pressed, and closes it on a second
## press. It sits beside `CommandHost` under the UI layer.
##
## IN PLAIN WORDS: press L and, if the player is a fighter and no other screen is open,
## `LoadoutScreen` opens for the controlled member and every follower walking behind them.
## A game with no fighter never sees it.
##
## OWNS: turning the loadout key into an open or closed loadout screen, and who is on it.
## MUST NOT: decide what may be chosen, or open over another screen.

## The loadout of the controlled member. Null means the fighter's own; a test sets its own.
var loadout: ActionLoadout


func _ready() -> void:
	# Like ScreenKeys: the key that opened the screen must also be able to close it.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(CombatActions.LOADOUT):
		return
	var stack: UiRoot = UiRoot.find(self)
	if stack != null and toggle(stack, Director.player):
		get_viewport().set_input_as_handled()


## Closes the loadout screen when it is on top, else opens it for `player` and their
## followers. True when something opened or closed.
func toggle(stack: UiRoot, player: Node) -> bool:
	var top: UiScreen = stack.top()
	if top != null and top.screen_id == LoadoutScreen.SCREEN_ID:
		return stack.close_top()
	if not stack.is_gameplay_input_allowed():
		return false
	var bodies: Array[Node] = []
	var defs: Array[CombatantDef] = []
	_gather(player, bodies, defs)
	if bodies.is_empty():
		return false
	return stack.open(LoadoutScreen.for_members(bodies, defs))


## Fills the two lists with the controlled member, then each follower in line order. Anyone
## who is not a fighter, or whose loadout names no definition, is left out.
func _gather(player: Node, bodies: Array[Node], defs: Array[CombatantDef]) -> void:
	if player == null or not is_instance_valid(player) or Combatant.of(player) == null:
		return
	var lead: ActionLoadout = loadout if loadout != null else FieldParty.lead(player)
	if lead == null:
		lead = ActionHost.configured()
	if lead == null or lead.fighter == null:
		return
	bodies.append(player)
	defs.append(lead.fighter)
	for follower: PartyFollower in FieldParty.followers(player as Node3D):
		if follower.loadout != null and follower.loadout.fighter != null and Combatant.of(follower) != null:
			bodies.append(follower)
			defs.append(follower.loadout.fighter)
