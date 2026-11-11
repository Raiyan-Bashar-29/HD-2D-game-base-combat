class_name OnceLedger
extends RefCounted
## Which once-per-battle powers one fighter has already used (C6.5f). Held by its `PowerSet` as
## `once`. See `docs/POWERS.md` § The framework.
##
## IN PLAIN WORDS: a power marked `once_per_battle` is written down here when it is used, and
## `PowerUse.refusal` then says ONCE until the list is wiped. A battle builds its fighters a fresh
## `PowerSet`, so each battle starts with an empty list. In the field, the `PowerSet` wipes it
## each time an area is entered (`Events.area_entered`, which a new game and a load also send).
##
## NOT SAVED: a load enters an area, which wipes the list anyway.
##
## OWNS: the list of used once-per-battle power ids.
## MUST NOT: decide whether a power may be used (`PowerUse` does), or name a character.

var _spent: Array[StringName] = []


## True when `power_id` has been used since the list was last wiped.
func spent(power_id: StringName) -> bool:
	return _spent.has(power_id)


## Writes `power_id` down as used.
func spend(power_id: StringName) -> void:
	if not _spent.has(power_id):
		_spent.append(power_id)


## Wipes the list. Connected to `Events.area_entered`, whose area id it does not need.
func forget(_area_id: StringName = &"") -> void:
	_spent.clear()
