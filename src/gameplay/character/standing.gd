class_name Standing
extends RefCounted
## What one person thinks of the player. A namespace over `Flags`, and deliberately nothing more.
##
## WHY THIS IS NOT A STORE, A COMPONENT OR AN AUTOLOAD
## Standing is exactly the kind of fact `Flags` exists to hold: a small number the plot cares
## about that must survive a reload. It is already saved, already announced on `flag_changed`,
## already dumpable with `Flags.with_prefix("standing/")`. A second store would be a second
## truth and a second save section for one integer per NPC, and an autoload would need an ADR
## it could not justify. So this class owns the KEY SHAPE and the clamp, and owns nothing else.
##
## WHY IT IS KEYED BY NPC AND NOT BY AREA. `PersistentState` namespaces per area, which is right
## for a chest — the same chest in two areas is two chests. It is wrong for a person: the
## garden-keeper who dislikes you in the courtyard must still dislike you in the hall. So the
## key is `standing/<who>`, in the `Flags` namespace the header of flags.gd already documents
## alongside `met/` and `story/`.
##
## OWNS: the key shape, the range, and the clamp.
## MUST NOT: decide what any level MEANS, or what changes it. A path action does that.

const PREFIX: String = "standing/"
## Standing runs from hostile to devoted. Clamped rather than unbounded, so a repeatable action
## cannot farm a number that later gates content — the ceiling is the design, not an accident.
const MINIMUM: int = -3
const MAXIMUM: int = 5


static func key(who: StringName) -> StringName:
	return StringName(PREFIX + String(who))


## Nobody starts at zero by accident: an NPC the player has never met has no flag at all, and
## the default IS the neutral value rather than a stored one. That keeps a save file free of a
## row per person the player has never spoken to.
static func of(who: StringName) -> int:
	return Flags.get_int(key(who), 0)


## Returns the NEW value, so a caller can report what happened without reading it back and
## without assuming the delta was applied in full — it is clamped, and at the ceiling it is not.
static func change(who: StringName, delta: int) -> int:
	var next: int = clampi(of(who) + delta, MINIMUM, MAXIMUM)
	Flags.set_flag(key(who), next)
	return next


static func at_least(who: StringName, threshold: int) -> bool:
	return of(who) >= threshold


## Every standing in the game, for a debug dump or a future journal page. Reads through Flags so
## there is no second list to keep in step.
static func all() -> Dictionary[StringName, Variant]:
	return Flags.with_prefix(PREFIX)
