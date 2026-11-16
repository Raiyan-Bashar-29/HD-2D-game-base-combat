class_name CraftStation
extends Interactable
## A forge, a workbench, an alchemist's table (C7.8): interacting asks for the craft screen
## at this station.
##
## IN PLAIN WORDS: set `station` to the id the recipes name (`Recipe.station`), so only the
## recipes for anywhere and for this station are offered. It only asks
## (`Events.craft_requested`); `CraftHost` opens the screen.
##
## OWNS: which station this is, and asking for its screen.
## MUST NOT: open a screen itself, or decide what can be made (`Crafting` does).

## The station id recipes name. Empty offers only the recipes that can be made anywhere.
@export var station: StringName = &""


func _ready() -> void:
	verb = GameEnums.InteractVerb.USE
	super()


func perform(_who: Node3D) -> void:
	Events.craft_requested.emit(station)
