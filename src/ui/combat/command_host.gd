class_name CommandHost
extends Node
## Opens the hybrid's command menu (C4.4) when the command key is pressed mid-fight, and closes
## it on a second press. It sits beside `BattleHost` under the UI layer.
##
## IN PLAIN WORDS: press F (or the pad's extra centre button) and, if the player can fight with
## commands right now, `CommandOverlay` opens. "Can" means all of these:
## - the player is a fighter (`ActionHost` fitted them) and is still standing;
## - they have an ATB gauge, which only a loadout with `atb` rules gives;
## - the loadout offers at least one command;
## - no other screen is open (a conversation, the pause menu, a battle).
## Otherwise the press does nothing at all, so a game with no hybrid never sees this menu.
##
## OWNS: turning the command key into an open or closed command menu.
## MUST NOT: decide what the menu offers or does, or open over another screen.

## The loadout whose commands the menu offers. Null means the controlled member's; a test sets
## its own.
var loadout: ActionLoadout


func _ready() -> void:
	# Like ScreenKeys: the key that opened the menu must also be able to close it.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(CombatActions.COMMAND):
		return
	var stack: UiRoot = UiRoot.find(self)
	if stack != null and toggle(stack, Director.player):
		get_viewport().set_input_as_handled()


## Closes the command menu when it is on top, else opens it for `player` when they can use it.
## True when something opened or closed.
func toggle(stack: UiRoot, player: Node) -> bool:
	var top: UiScreen = stack.top()
	if top != null and top.screen_id == CommandOverlay.SCREEN_ID:
		return stack.close_top()
	if not stack.is_gameplay_input_allowed() or not can_open(player):
		return false
	return stack.open(CommandOverlay.for_fighter(Combatant.of(player), _loadout(player).commands))


## Whether `player` may open the menu now: a standing fighter with a gauge and something to use.
func can_open(player: Node) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var fighter: Combatant = Combatant.of(player)
	var vitals: Vitals = Vitals.of(player)
	var offered: ActionLoadout = _loadout(player)
	return fighter != null and vitals != null and not vitals.is_defeated() \
			and AtbMeter.of(player) != null and offered != null and not offered.commands.is_empty()


## The set loadout, else the controlled member's (a party switch changes it, C4.7), else the
## one `project.godot` names.
func _loadout(player: Node) -> ActionLoadout:
	if loadout != null:
		return loadout
	var lead: ActionLoadout = FieldParty.lead(player)
	return lead if lead != null else ActionHost.configured()
