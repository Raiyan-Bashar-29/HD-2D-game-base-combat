class_name PowerMechanism
extends Resource
## The settings of the one thing a power does that a plain skill cannot (C6.1a): a barrage of
## projectiles, a barrier, a domain, a form, and so on. `docs/POWERS.md` lists the thirteen.
##
## IN PLAIN WORDS: each mechanism is a small subclass of this that only holds typed settings
## (how many blades, how wide the domain). The code that RUNS it lives in gameplay, in an
## executor found by `kind()` through the `PowerMechanisms` registry (C6.1b). A mechanism is
## named after what it does, never after a character, so one barrage serves many kits.
##
## A mechanism that puts statuses of its own on its holder (a form) lists them in `statuses()`
## (C6.5c), so the kit can find them: a save can load them, and the quick slots know them.
##
## A mechanism that strikes the foes by itself, with no skill to aim it (a barrage), says so in
## `aims_at_foes()` (C6.7), so a battle offers it every standing foe as its targets.
##
## OWNS: the base shape every mechanism shares.
## MUST NOT: hold running state or touch a fighter. The executor does both.


## The registry key of this mechanism, such as `barrage`. Each subclass returns its own; the
## base returns nothing, which `problems` reports.
func kind() -> StringName:
	return &""


## The statuses this mechanism can put on its holder. None for most; a form lists its own.
func statuses() -> Array[StatusEffect]:
	var none: Array[StatusEffect] = []
	return none


## True when the power aims at the foes by itself, with no skill to aim it. False for most.
func aims_at_foes() -> bool:
	return false


## Empty when it can run. A subclass adds its own checks to this list.
func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if kind() == &"":
		found.append("%s is a mechanism with no kind" % context)
	return found
