class_name Grab
extends Node
## A fighter held by a grab (C8.8b), until the throw.
##
## IN PLAIN WORDS:
## - A move with a `throw_move` is a grab. When it lands on a fighter that flinches, the
##   `Hitbox` starts the throw on the attacker's clock and calls `hold` on the victim.
## - While held, the victim cannot start a move (the player's fighter and a field foe both
##   ask `held`) and stays at the same offset from its holder, so it follows a holder that
##   moves.
## - The moment the throw is live, it is struck through the holder's `Hitbox`: the throw
##   always lands, whatever its box's shape, and only once. Then the victim is let go, so the
##   throw's `knockback` and `launch` carry it away.
## - It is let go with no throw when the holder's clock leaves that swing first (the holder
##   was hit, staggered or fell), or when the victim is down.
##
## ESCAPING (C10.24): each attack or dodge the held player presses is a `struggle`; `ESCAPE`
## of them (the project setting `combat/grab/escape_presses`) break free with no throw. A fighter
## with the stat `grab_immune` above 0 is struck but never held (`immune`). With the setting
## `combat/grab/shield_held` on, nobody but the holder can hit a held victim (`shielded`).
##
## The `Hitbox` makes this node under the victim's body the first time it is grabbed.
##
## OWNS: who holds one fighter, and letting go.
## MUST NOT: resolve the throw's hit (the `Hurtbox` does) or decide whether a hit grabs (the
## `Hitbox` does).

const ESCAPE_SETTING: String = "combat/grab/escape_presses"
const SHIELD_SETTING: String = "combat/grab/shield_held"
const IMMUNE: StringName = &"grab_immune"

var _holder: Hitbox
var _throw: ActionMove
var _swing: int = -1
var _offset: Vector3 = Vector3.ZERO
var _struggles: int = 0


func _physics_process(_delta: float) -> void:
	pass_time()


## The `Grab` on `body`, or null.
static func of(body: Node) -> Grab:
	if body == null:
		return null
	for child: Node in body.get_children():
		if child is Grab:
			return child as Grab
	return null


## True while `body` is held by a grab.
static func held(body: Node) -> bool:
	var grab: Grab = Grab.of(body)
	return grab != null and grab._holder != null


## The held `body` struggles once when `pressed` (an attack or dodge press). True when that broke
## it free.
static func struggle(body: Node, pressed: bool = true) -> bool:
	var grab: Grab = Grab.of(body)
	if not pressed or grab == null or grab._holder == null:
		return false
	grab._struggles += 1
	var needed: int = ProjectSettings.get_setting(ESCAPE_SETTING, 6)
	if grab._struggles < needed:
		return false
	grab._holder = null
	return true


## True when `body`'s fighter can never be held: its `grab_immune` stat is above 0.
static func immune(body: Node) -> bool:
	var fighter: Combatant = Combatant.of(body)
	return fighter != null and fighter.sheet.value(IMMUNE) > 0.0


## True when `body` is held and `by` is not its holder, with `shield_held` on: the hit is ignored.
static func shielded(body: Node, by: Hitbox) -> bool:
	var grab: Grab = Grab.of(body)
	var on: bool = ProjectSettings.get_setting(SHIELD_SETTING, false)
	return on and grab != null and grab._holder != null and grab._holder != by


## `holder`'s fighter now holds `victim` and is playing `throw` on its clock. The victim drops
## its own swing.
static func hold(victim: Node3D, holder: Hitbox, throw: ActionMove) -> void:
	var grab: Grab = Grab.of(victim)
	if grab == null:
		grab = Grab.new()
		victim.add_child(grab)
	grab._holder = holder
	grab._struggles = 0
	grab._throw = throw
	grab._swing = holder.timeline.swing
	grab._offset = victim.global_position - holder.global_position
	for child: Node in victim.get_children():
		if child is Hurtbox and (child as Hurtbox).timeline != null:
			(child as Hurtbox).timeline.cancel()


## One frame of being held: follow the holder, take the throw when it is live, or be let go.
func pass_time() -> void:
	if _holder == null or not is_instance_valid(_holder):
		_holder = null
		return
	var victim: Node3D = get_parent() as Node3D
	var clock: MoveTimeline = _holder.timeline
	var vitals: Vitals = Vitals.of(victim)
	var down: bool = vitals != null and vitals.is_defeated()
	if clock == null or clock.swing != _swing or clock.move != _throw or down:
		_holder = null
		return
	victim.global_position = _holder.global_position + _offset
	if not clock.is_hitting():
		return
	var holder: Hitbox = _holder
	_holder = null
	for child: Node in victim.get_children():
		if child is Hurtbox:
			holder.strike(child as Hurtbox)
