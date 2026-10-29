class_name Skill
extends ContentEntry
## One thing a combatant can do on its turn beyond a plain attack: what it costs, whom it may
## target, how hard it hits, and which statuses it leaves. `data/skills/<name>.tres`, id
## `skill/<name>`, `SkillDb` finds it.
##
## A SKILL IS DATA, AND THE BATTLE IS THE ONLY CODE. Every formula reads the same fields: C2.4's
## battle spends the cost, checks `target` with `FactionTable.allows`, resolves `power` through
## the user's `DamageFormula`, and rolls each status at `status_chance`. A fire spell, a heal and
## a poison dart differ only in these numbers.
##
## NEGATIVE POWER HEALS. A heal names an ALLY target and a power below zero, and the battle
## restores that much without resolving it through defence. Zero power with statuses is a pure
## buff or curse.
##
## `delay` IS THE CTB SEAM. A heavy skill pushes its user back that many ticks after acting
## (`CtbScheduler.delay_by`). A round scheduler ignores it.
##
## OWNS: the shape of one skill and what is wrong with it.
## MUST NOT: know who is using it, apply itself, or name a formula's internals.

enum Scope { ONE, ALL }

## Localization key for the skill's name in the command menu.
@export var name_key: String = ""
## The pool the cost is spent from, and how much. An empty pool or zero cost is free.
@export var cost_pool: StringName = &""
@export var cost: int = 0
@export var target: FactionTable.Target = FactionTable.Target.ENEMY
## ONE asks for a target; ALL takes every combatant the filter allows.
@export var scope: Scope = Scope.ONE
## Above zero hits through the formula; below zero heals; zero does neither.
@export var power: float = 0.0
@export var element: StringName = &""
@export var statuses: Array[StatusEffect] = []
@export_range(0.0, 1.0, 0.01) var status_chance: float = 1.0
## CTB ticks the user is pushed back after acting. Zero for none.
@export var delay: float = 0.0


func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if id == &"":
		found.append("%s has no id" % resource_path)
	if name_key == "":
		found.append("%s (%s) has no name_key" % [resource_path, id])
	if cost < 0:
		found.append("%s (%s) has a negative cost" % [resource_path, id])
	if cost > 0 and cost_pool == &"":
		found.append("%s (%s) costs %d but names no cost_pool" % [resource_path, id, cost])
	if is_zero_approx(power) and statuses.is_empty():
		found.append("%s (%s) does nothing: no power and no statuses" % [resource_path, id])
	if power < 0.0 and target == FactionTable.Target.ENEMY:
		found.append("%s (%s) heals its enemies" % [resource_path, id])
	for status: StatusEffect in statuses:
		if status == null:
			found.append("%s (%s) lists an empty status" % [resource_path, id])
	return found
