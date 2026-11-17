class_name WieldRun
extends PowerExecutor
## Runs a made weapon (C8.14b) on one fighter. Its settings are a `WieldMechanism`; read its
## header for what the fields mean.
##
## IN PLAIN WORDS: a use remembers the user's `lent_moves` and `lent_element`, writes the weapon's
## over them, and adds the bonuses to its sheet under `wield/<power>`. `tick` counts down; at 0,
## or on `end`, the bonuses come off and the remembered moves and element come back, unless worn
## gear has written its own meanwhile.
##
## OWNS: the weapon's clock and what it replaced.
## MUST NOT: touch gear, or name a character.

var _left: float = 0.0
var _before_moves: MoveSet
var _before_element: StringName = &""
var _holding: bool = false


func use(user: Combatant, _targets: Array[Combatant], _rng: RandomNumberGenerator) -> void:
	var wield: WieldMechanism = mechanism as WieldMechanism
	if not _holding:
		_before_moves = user.lent_moves
		_before_element = user.lent_element
		for bonus: StatModifier in wield.bonuses:
			if bonus != null:
				user.sheet.add(StatModifier.of(bonus.stat, bonus.op, bonus.value, _source()))
	if wield.moves != null:
		user.lent_moves = wield.moves
	if wield.element != &"":
		user.lent_element = wield.element
	_holding = true
	_left = wield.lasts


## Time passed: the weapon goes at 0.
func tick(amount: float) -> void:
	if not _holding:
		return
	_left -= amount
	if _left <= 0.0:
		_drop()


## The kit came off: the weapon goes.
func end() -> void:
	_drop()


## True while the weapon is held: for a HUD, or a test.
func holding() -> bool:
	return _holding


func _drop() -> void:
	if not _holding:
		return
	_holding = false
	var user: Combatant = Combatant.of(holder.get_parent()) if is_instance_valid(holder) else null
	if user == null:
		return
	var wield: WieldMechanism = mechanism as WieldMechanism
	user.sheet.remove_from(_source())
	if wield.moves != null and user.lent_moves == wield.moves:
		user.lent_moves = _before_moves
	if wield.element != &"" and user.lent_element == wield.element:
		user.lent_element = _before_element


func _source() -> StringName:
	return StringName("wield/" + (String(power.power_id) if power != null else ""))
