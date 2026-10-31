class_name CombatSaveGuard
extends Node
## Says "not now" to a save while a fight would be written down half-finished (C5.2). One lives
## under GameRoot, beside `ActionHost`.
##
## IN PLAIN WORDS: upstream's `SaveSystem.blockers` (5.17.0) lets any system refuse a save and
## say why. This node refuses two moments:
## - DURING A TURN-BASED BATTLE, from `battle_started` to `battle_ended`. A save then would keep
##   the party's hp mid-fight, perhaps a fallen leader at 0, and statuses for fighters that only
##   exist inside the battle. The pause menu cannot open in a battle anyway; this stops the
##   autosave that quitting the game makes.
## - WHILE THE PLAYER LIES DEFEATED in the field, waiting for their `DefeatRule`. A save then
##   would keep them at 0 hp, and loading it would leave them on the ground for ever, because
##   defeat is an edge (`Vitals`) and a load fires no edge.
## The save screen shows the reason; the autosave skips quietly and tries again at the next
## area entry. Loading is never refused.
##
## WHAT SAVES AND WHAT DOES NOT, for the record: every pool (`Vitals` keeps them in `Flags`),
## each fighter's statuses with their time left (`StatusSet`'s section), defeated field enemies
## that `remember_defeat`, and revealed weaknesses are all saved. Field enemies' hp, their AI and
## every ATB gauge are not: an area is rebuilt fresh on load, as on re-entry.
##
## OWNS: the two combat reasons a save is refused.
## MUST NOT: write or load a save, or decide anything about a fight. It only watches.

const BLOCKER: StringName = &"combat"
const IN_BATTLE_KEY: String = "ui.combat_save.in_battle"
const FALLEN_KEY: String = "ui.combat_save.fallen"

var _in_battle: bool = false
var _player: Node3D = null


func _ready() -> void:
	SaveSystem.blockers.add(BLOCKER, reason)
	Events.battle_started.connect(func(_ids: Array[StringName]) -> void: _in_battle = true)
	Events.battle_ended.connect(func(_outcome: int) -> void: _in_battle = false)
	Events.player_spawned.connect(_on_player_spawned)


func _exit_tree() -> void:
	SaveSystem.blockers.remove(BLOCKER)


func _on_player_spawned(player: Node3D) -> void:
	_player = player


## Why a save would be refused right now, as a localization key, or "" when saving is fine.
## `SaveSystem.blockers` calls it before every save.
func reason() -> String:
	if _in_battle:
		return IN_BATTLE_KEY
	if is_instance_valid(_player):
		var vitals: Vitals = Vitals.of(_player)
		if vitals != null and vitals.is_defeated():
			return FALLEN_KEY
	return ""
