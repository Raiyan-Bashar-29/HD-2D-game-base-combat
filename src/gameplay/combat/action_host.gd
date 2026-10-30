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
## AND IT GRANTS A FIELD KILL'S REWARD (C3.8), when an `ActionEnemy` announces its defeat, and
## brings the loadout's companions along as followers (C4.7, `FieldParty`).
##
## OWNS: installing the combat actions, fitting the player with a fighter, and field rewards.
## MUST NOT: read input itself, or run a fight. `ActionFighter` does that.

const LOADOUT_SETTING: String = "combat/action/loadout"


func _ready() -> void:
	CombatActions.install()
	Log.info("combat", "Action inputs ready: %d" % CombatActions.ALL.size())
	Events.player_spawned.connect(_on_player_spawned)
	Events.field_enemy_defeated.connect(_on_field_enemy_defeated)
	# A safety net (C4.1): a new room always starts at full fight speed.
	Events.area_entered.connect(func(_area: StringName) -> void: CombatClock.reset())


## The loadout `project.godot` names, or null when field combat is off, the file is gone, or it
## is not a loadout. Only the last is an error.
static func configured() -> ActionLoadout:
	var path: String = str(ProjectSettings.get_setting(LOADOUT_SETTING, ""))
	if path == "":
		return null
	# A missing file is not an error: a game that deleted its demo content (NEW_GAME.md) keeps
	# the setting but no loadout, and simply has no field combat until it names its own.
	if not ResourceLoader.exists(path):
		Log.info("combat", "%s names '%s', which does not exist: no field combat" % [LOADOUT_SETTING, path])
		return null
	var loaded: ActionLoadout = load(path) as ActionLoadout
	if loaded == null:
		Log.error("combat", "%s names '%s', which is not an ActionLoadout" % [LOADOUT_SETTING, path])
	return loaded


## Adds what fighting needs under `body`: who the fighter is (`fit_identity`), then a `Hitbox`, a
## `LockOn`, an `ActionFighter` holding the loadout, and a `FieldDefeat`. A body that already has
## a `Combatant` is left alone and gets nothing, so equipping twice is harmless. Returns the
## fighter, or null.
static func equip(body: Node3D, loadout: ActionLoadout) -> ActionFighter:
	if body == null or loadout == null or loadout.fighter == null or Combatant.of(body) != null:
		return null
	fit_identity(body, loadout)
	body.add_child(Hitbox.new())
	body.add_child(LockOn.new())
	var fighter := ActionFighter.new()
	fighter.loadout = loadout
	fighter.moves = loadout.moves
	body.add_child(fighter)
	var defeat := FieldDefeat.new()
	if loadout.defeat_rule != null:
		defeat.rule = loadout.defeat_rule
	body.add_child(defeat)
	return fighter


## Adds who `loadout`'s fighter is under `body`: `Vitals`, `StatusSet`, `Combatant`, an `AtbMeter`
## when the loadout has ATB rules, and a `Hurtbox` with a shape. The player's body gets this from
## `equip`, and a party follower's from itself (C4.7). Every node but the hurtbox is the member
## and moves with them on a party switch (`FieldParty`). Returns the combatant.
static func fit_identity(body: Node3D, loadout: ActionLoadout) -> Combatant:
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
	# The field counts in seconds, so a break here is a stagger (C4.6).
	combatant.real_time = true
	body.add_child(combatant)
	# The hybrid's ATB gauge (C4.2), only when the loadout asks for one.
	if loadout.atb != null:
		var meter := AtbMeter.new()
		meter.gauge = AtbGauge.new(loadout.atb)
		body.add_child(meter)
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
	return combatant


## A field kill's reward for `player` (C3.8): its experience to the loadout's fighter, unless the
## player is down, and to every standing follower (C4.7); its loot into the player's `Inventory`.
static func reward(experience: int, loot: Array[StringName], player: Node, loadout: ActionLoadout) -> Rewards:
	var members: Array[CombatantDef] = []
	var vitals: Vitals = Vitals.of(player) if player != null else null
	if loadout != null and loadout.fighter != null and vitals != null and not vitals.is_defeated():
		members.append(loadout.fighter)
	for follower: PartyFollower in FieldParty.followers(player as Node3D):
		var theirs: Vitals = Vitals.of(follower)
		if follower.loadout != null and theirs != null and not theirs.is_defeated():
			members.append(follower.loadout.fighter)
	return Rewards.give(experience, loot, members, Inventory.of(player) if player != null else null)


func _on_player_spawned(player: Node3D) -> void:
	var loadout: ActionLoadout = configured()
	if loadout == null:
		return
	# Deferred: the player is still inside its own `_ready` when it announces itself.
	_equip_later.call_deferred(player, loadout)


func _on_field_enemy_defeated(_who: StringName, experience: int, loot: Array[StringName]) -> void:
	# Whoever is controlled now, which a party switch changes (C4.7).
	var lead: ActionLoadout = FieldParty.lead(Director.player)
	var given: Rewards = reward(experience, loot, Director.player, lead if lead != null else configured())
	Log.info("combat", "Field victory: %d experience, %d item(s)" % [given.experience, given.items.size()])


func _equip_later(player: Node3D, loadout: ActionLoadout) -> void:
	if is_instance_valid(player) and equip(player, loadout) != null:
		var party: Array[PartyFollower] = FieldParty.spawn(player, loadout)
		Log.info("combat", "Player fitted for field combat, with %d follower(s)" % party.size())
