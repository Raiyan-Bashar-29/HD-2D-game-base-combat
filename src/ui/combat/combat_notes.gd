class_name CombatNotes
extends Node
## Short notes for what a fight took or gave (C10.13): a steal, a capture, a piece that broke.
##
## IN PLAIN WORDS: it listens to `item_stolen`, `creature_captured` and `gear_broke` and asks the
## toast (`Events.notify_requested`) to show "Stole Potion", "Caught: Wisp Jar" or "Coat broke".
## The battle log has its own steal line; this is for the field and anything after.
##
## OWNS: which note each event gets.
## MUST NOT: change what was taken or given.

const STOLEN_KEY: String = "ui.combat_hud.stolen"
const CAPTURED_KEY: String = "ui.combat_hud.captured"
const BROKE_KEY: String = "ui.combat_hud.broke"
const SECONDS: float = 2.5


func _ready() -> void:
	Events.item_stolen.connect(func(_w: StringName, _f: StringName, item_id: StringName) -> void: _note(STOLEN_KEY, item_id))
	Events.creature_captured.connect(func(_w: StringName, _t: StringName, item_id: StringName) -> void: _note(CAPTURED_KEY, item_id))
	Events.gear_broke.connect(func(_w: StringName, item_id: StringName) -> void: _note(BROKE_KEY, item_id))


func _note(key: String, item_id: StringName) -> void:
	Events.notify_requested.emit(key, SECONDS, {"item": PieceScreen.item_name(item_id)})
