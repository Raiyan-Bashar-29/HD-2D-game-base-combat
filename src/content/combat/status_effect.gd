class_name StatusEffect
extends ContentEntry
## A status: how long it lasts, what happens when it is applied again, what it changes, and what
## it does each tick. `data/statuses/<name>.tres`, id `status/<name>`, `StatusDb` finds it.
##
## DURATION IS IN TURNS OR IN SECONDS, AND THAT ONE ENUM IS WHY EVERY FORMULA SHARES THIS FILE.
## A turn-based battle calls `StatusSet.tick_turn()`, an action one calls `tick_seconds(delta)`,
## and the hybrid calls whichever its clock is; a status only answers to its own unit. A duration
## of zero or less lasts until it is cured.
##
## ITS MODIFIERS ARE AUTHORED WITHOUT A SOURCE. `StatusSet` stamps each with this status's id
## when applying it, so expiry and cure remove exactly what this status added, by source, the
## C1.2 rule, and an author cannot get the source wrong.
##
## THE TICK IS A POOL CHANGE, NOT A DAMAGE REQUEST. Content may not depend on systems, where the
## damage pipeline lives, and a poison that skipped defence is what most games mean anyway.
## A tick that should resolve through a formula is C1.6's, where a `Combatant` has both.
##
## OWNS: the shape of one status and what is wrong with it.
## MUST NOT: hold who has it, how long is left, or apply itself.

enum Unit { TURNS, SECONDS }
## REFRESH resets the duration; STACK resets it and adds a stack, up to `max_stacks`, each stack
## adding the modifiers and the tick again; IGNORE refuses while it is already held.
enum Stacking { REFRESH, STACK, IGNORE }
## What a status stops its holder doing (C2.14). SKIP_TURN: they lose every turn while it is held
## (sleep, stun, freeze). NO_SKILLS: no SKILL commands (silence). NO_ITEMS and NO_FLEE: the same
## for ITEM and FLEE. A plain ATTACK and DEFEND are never blocked, so nobody is ever stuck.
enum Block { SKIP_TURN, NO_SKILLS, NO_ITEMS, NO_FLEE }

@export var unit: Unit = Unit.TURNS
@export var duration: float = 3.0
@export var stacking: Stacking = Stacking.REFRESH
@export var max_stacks: int = 1
@export var modifiers: Array[StatModifier] = []
## The pool a tick changes, and by how much per stack. Empty or zero means no tick.
@export var tick_pool: StringName = &""
@export var tick_change: int = 0
## Seconds between ticks, for a SECONDS status. A TURNS status ticks once a turn.
@export var tick_interval: float = 1.0
## Free labels a skill can match: `buff`, `debuff`, `ailment`, or any name a game uses. A
## DISPEL effect clears every held status carrying its tag (C2.13).
@export var tags: Array[StringName] = []
## What the holder cannot do while this is held.
@export var blocks: Array[Block] = []
## True for a sleep: the first hit that does damage ends it.
@export var breaks_on_hit: bool = false


## True when this status carries `block`.
func has_block(block: Block) -> bool:
	return blocks.has(block)


func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if id == &"":
		found.append("%s has no id" % resource_path)
	if max_stacks < 1:
		found.append("%s (%s) has max_stacks below 1" % [resource_path, id])
	if tick_change != 0 and tick_pool == &"":
		found.append("%s (%s) ticks but names no tick_pool" % [resource_path, id])
	if unit == Unit.SECONDS and tick_change != 0 and tick_interval <= 0.0:
		found.append("%s (%s) ticks in seconds with no tick_interval" % [resource_path, id])
	if blocks.has(Block.SKIP_TURN) and duration <= 0.0 and not breaks_on_hit:
		# Nothing would ever end it short of a cure, and a whole side asleep forever would stall.
		found.append("%s (%s) skips turns forever: give it a duration or breaks_on_hit" % [resource_path, id])
	for modifier: StatModifier in modifiers:
		if modifier == null or modifier.stat == &"":
			found.append("%s (%s) has a modifier with no stat" % [resource_path, id])
	return found
