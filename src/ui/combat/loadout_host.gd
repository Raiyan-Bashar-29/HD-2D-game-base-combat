class_name LoadoutHost
extends Node
## Opens the passive loadout screen (C9.7), or the gear screen (C7.7a), when its key is pressed,
## and closes it on a second press. It sits beside `CommandHost` under the UI layer.
##
## IN PLAIN WORDS: press L (G for gear) and, if the player is a fighter and no other screen is
## open, `LoadoutScreen` (`GearScreen`) opens for the controlled member and every follower
## walking behind them.
## A game with no fighter never sees it.
##
## OWNS: turning the loadout and gear keys into an open or closed screen, and who is on it.
## MUST NOT: decide what may be chosen, or open over another screen.

## The loadout of the controlled member. Null means the fighter's own; a test sets its own.
var loadout: ActionLoadout


func _ready() -> void:
	# Like ScreenKeys: the key that opened the screen must also be able to close it.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if Actions.pressed_now(event, CombatActions.PARTY):
		var root: UiRoot = UiRoot.find(self)
		if root != null and toggle_party(root, Director.player):
			get_viewport().set_input_as_handled()
		return
	var gear: bool = Actions.pressed_now(event, CombatActions.GEAR)
	if not gear and not Actions.pressed_now(event, CombatActions.LOADOUT):
		return
	var stack: UiRoot = UiRoot.find(self)
	if stack != null and toggle(stack, Director.player, gear):
		get_viewport().set_input_as_handled()


## Closes the loadout screen (the gear screen when `gear`) when it is on top, else opens it for
## `player` and their followers. True when something opened or closed.
func toggle(stack: UiRoot, player: Node, gear: bool = false) -> bool:
	var top: UiScreen = stack.top()
	var wanted: StringName = GearScreen.SCREEN_ID if gear else LoadoutScreen.SCREEN_ID
	if top != null and top.screen_id == wanted:
		return stack.close_top()
	if not stack.is_gameplay_input_allowed():
		return false
	var bodies: Array[Node] = []
	var defs: Array[CombatantDef] = []
	_gather(player, bodies, defs)
	if bodies.is_empty():
		return false
	if gear:
		return stack.open(GearScreen.for_members(bodies, defs))
	return stack.open(LoadoutScreen.for_members(bodies, defs))


## Closes the party screen when it is on top, else opens it for the roster (C10.20), with the
## bodies of `player` and their followers for the forms they hold. `members` stands in for the
## configured roster when given. True when something changed.
func toggle_party(stack: UiRoot, player: Node, members: Array[CombatantDef] = []) -> bool:
	var top: UiScreen = stack.top()
	if top != null and top.screen_id == PartyScreen.SCREEN_ID:
		return stack.close_top()
	if not stack.is_gameplay_input_allowed():
		return false
	var bodies: Array[Node] = []
	var defs: Array[CombatantDef] = []
	_gather(player, bodies, defs)
	var field: Dictionary[StringName, Node] = {}
	for i: int in defs.size():
		field[defs[i].combatant_id] = bodies[i]
	var roster: Array[CombatantDef] = members if not members.is_empty() \
			else BattleHost.roster_from(str(ProjectSettings.get_setting(BattleHost.ROSTER_SETTING, "")))
	if roster.is_empty():
		roster = defs
	return not roster.is_empty() and stack.open(PartyScreen.for_roster(roster, field))


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
