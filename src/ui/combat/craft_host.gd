class_name CraftHost
extends Node
## Opens the craft screen (C7.8) when a `CraftStation` asks. It sits beside `LoadoutHost`
## under the UI layer.
##
## IN PLAIN WORDS: on `Events.craft_requested`, if no other screen holds the game, the craft
## screen opens for that station over the player's bag.
##
## OWNS: turning a station's request into an open craft screen.
## MUST NOT: decide what can be made, or open over another screen.

## The bag crafted from. Null means the player's; a test sets its own.
var bag: Inventory


func _ready() -> void:
	Events.craft_requested.connect(_on_craft_requested)


func _exit_tree() -> void:
	if Events.craft_requested.is_connected(_on_craft_requested):
		Events.craft_requested.disconnect(_on_craft_requested)


## Opens the craft screen at `station` on `stack`. False when another screen holds the game or
## there is no bag.
func open(stack: UiRoot, station: StringName) -> bool:
	var used: Inventory = bag if bag != null else Inventory.of(Director.player)
	if stack == null or used == null or not stack.is_gameplay_input_allowed():
		return false
	return stack.open(CraftScreen.for_station(station, used))


func _on_craft_requested(station: StringName) -> void:
	open(UiRoot.find(self), station)
