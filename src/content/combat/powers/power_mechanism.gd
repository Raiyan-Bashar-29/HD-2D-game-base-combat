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
## OWNS: the base shape every mechanism shares.
## MUST NOT: hold running state or touch a fighter. The executor does both.


## The registry key of this mechanism, such as `barrage`. Each subclass returns its own; the
## base returns nothing, which `problems` reports.
func kind() -> StringName:
	return &""


## Empty when it can run. A subclass adds its own checks to this list.
func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if kind() == &"":
		found.append("%s is a mechanism with no kind" % context)
	return found
