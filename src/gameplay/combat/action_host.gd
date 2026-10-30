class_name ActionHost
extends Node
## Where the action formula (C3) joins a running game. One lives under GameRoot.
##
## IN PLAIN WORDS: when the game starts it installs the combat actions (attack, dodge, lock on,
## cycle the target), so they exist before any fighter asks for them. Then, each time the player
## spawns, it fits them out as a real-time fighter from the loadout `[combat] action/loadout`
## names (C3.4). A game whose setting is empty has no field combat, and its player is exactly
## what upstream built. `player.tscn` is never edited: the fighter's parts are added as
## children of the spawned player, and go when the player does.
##
## IT IS A NODE IN THE COMPOSITION ROOT, NOT AN AUTOLOAD. Adding an autoload needs an ADR
## (CLAUDE.md), and nothing here must outlive the game root.
##
## OWNS: installing the combat actions, and fitting the player with a fighter.
## MUST NOT: read input itself, or run a fight. `ActionFighter` does that.

const LOADOUT_SETTING: String = "combat/action/loadout"


func _ready() -> void:
	CombatActions.install()
	Log.info("combat", "Action inputs ready: %d" % CombatActions.ALL.size())
	Events.player_spawned.connect(_on_player_spawned)


## The loadout `project.godot` names, or null when field combat is off or it fails to load.
static func configured() -> ActionLoadout:
	var path: String = str(ProjectSettings.get_setting(LOADOUT_SETTING, ""))
	if path == "":
		return null
	var loaded: ActionLoadout = load(path) as ActionLoadout if ResourceLoader.exists(path) else null
	if loaded == null:
		Log.error("combat", "%s names '%s', which is not an ActionLoadout" % [LOADOUT_SETTING, path])
	return loaded


## Adds what fighting needs under `body`: `Vitals`, `StatusSet`, `Combatant`, a `Hurtbox` with
## a shape, a `Hitbox`, a `LockOn` and an `ActionFighter`. A body that already has a `Combatant` is left
## alone and gets nothing, so equipping twice is harmless. Returns the fighter, or null.
static func equip(body: Node3D, loadout: ActionLoadout) -> ActionFighter:
	if body == null or loadout == null or loadout.fighter == null or Combatant.of(body) != null:
		return null
	var def: CombatantDef = loadout.fighter
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var combatant := Combatant.new()
	combatant.combatant_id = def.combatant_id if def.combatant_id != &"" else &"player"
	combatant.faction = def.faction
	combatant.base_stats = def.base_stats
	combatant.weak_to = def.weak_to
	combatant.attack_tags = def.attack_tags
	combatant.kind = def.combatant_id
	body.add_child(combatant)
	var hurtbox := Hurtbox.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	shape.shape = capsule
	# A capsule is centred on its node; lift it so its foot is at the body's feet.
	shape.position = Vector3(0.0, 0.8, 0.0)
	hurtbox.add_child(shape)
	body.add_child(hurtbox)
	body.add_child(Hitbox.new())
	body.add_child(LockOn.new())
	var fighter := ActionFighter.new()
	fighter.moves = loadout.moves
	body.add_child(fighter)
	return fighter


func _on_player_spawned(player: Node3D) -> void:
	var loadout: ActionLoadout = configured()
	if loadout == null:
		return
	# Deferred: the player is still inside its own `_ready` when it announces itself.
	_equip_later.call_deferred(player, loadout)


func _equip_later(player: Node3D, loadout: ActionLoadout) -> void:
	if is_instance_valid(player) and equip(player, loadout) != null:
		Log.info("combat", "Player fitted for field combat")
