class_name PowerExecutor
extends RefCounted
## The code that RUNS one power's mechanism on one fighter (C6.1b). Its settings are the
## `PowerMechanism` resource; this is its behaviour. See `docs/POWERS.md` § The framework.
##
## IN PLAIN WORDS: when a kit is equipped, `PowerSet` asks `PowerMechanisms` for one executor per
## power that has a mechanism, and keeps it for as long as the kit is on. Each executor is a
## small subclass of this one (a barrage, a barrier, a domain...) that overrides only the hooks
## it needs. The base does nothing, so a hook left alone is harmless.
##
## THE HOOKS, AND WHO CALLS THEM:
## - `use`: the power was used (`PowerUse.use`), after its skill, if any, has landed;
## - `tick`: time passed (`PowerSet`): seconds in the field, 1 per turn in a battle;
## - `end`: the kit came off (`PowerSet.unequip`); undo anything still running.
## - `power_used`: any power of the kit was used (`PowerSet.used`, C6.5a), so a form's cycle can
##   move on after a finisher.
## - `moves`: the field asks which moves the fighter plays now (`PowerSet.moves_over`, C6.5b), so
##   a form can hand over its own attack chain and dodge. The base hands back what it was given.
## - `moved`: the fighter started a move in the field, other than its dodge (`PowerSet.moved`,
##   C6.5b), so a form can drain per action.
## - `intercept_incoming`: a hit is about to land on this fighter or on one of its allies
##   (`PowerGuard.incoming`, from `Combatant.receive`, C6.6a), so a barrier can stop or soften it.
## - `projectile_landed`: a shot of this fighter's barrage ended without striking (`BarrageRun`,
##   C6.26), so a plant can leave something where it fell.
##
## OWNS: the running state of one mechanism on one fighter.
## MUST NOT: name a character, or be looked up by anything but its `kind`.

## The power this executor belongs to, and its mechanism's settings.
var power: Power
var mechanism: PowerMechanism
## The set that made it, and through it the fighter.
var holder: PowerSet


## The power was used. `targets` are who its skill landed on (empty for a power with no skill).
func use(_user: Combatant, _targets: Array[Combatant], _rng: RandomNumberGenerator) -> void:
	pass


## `amount` passed: seconds in the field, 1 per turn in a battle.
func tick(_amount: float) -> void:
	pass


## `used`, one of the kit's powers (this one's own included), was just used.
func power_used(_used: Power) -> void:
	pass


## The moves the fighter plays in the field while this runs, given `base`, the moves it would
## play otherwise. Return `base` itself to change nothing.
func moves(base: MoveSet) -> MoveSet:
	return base


## The fighter started `_move` in the field (never its dodge).
func moved(_move: ActionMove) -> void:
	pass


## A resolved hit, `result`, thrown by `_from`, is about to land on `_target`: this fighter
## itself, or one of its allies. Change `result` to stop or soften it; leave it alone otherwise.
func intercept_incoming(_target: Combatant, _result: DamageResult, _from: StringName) -> void:
	pass


## A shot of this fighter's barrage ended without striking: at `_at` in the field, or aimed at
## `_near` in a battle (where `_at` means nothing).
func projectile_landed(_at: Vector3, _near: Combatant) -> void:
	pass


## The kit came off, or the fighter left: stop anything still running.
func end() -> void:
	pass
