class_name CommandMechanism
extends PowerMechanism
## M8, a command (C6.11): an absolute order given to one foe. See `docs/POWERS.md` § M8.
##
## IN PLAIN WORDS: using the power gives the aimed foe one `order`:
## - OBEY: `status` (one that `obeys`) goes on the foe, and while it lasts the foe fights for
##   the user's side; a battle counts it out of its own side;
## - STOP: `status` (one that skips turns) goes on the foe;
## - FORGET: the foe leaves the fight and gives nothing: a field foe is gone from the area, a
##   battle foe stands aside, counted as fallen, for the rest of the battle;
## - FALL: the foe is defeated at once, as by any hit, so its rewards follow.
## For FORGET and FALL a `status` is optional, a mark put on first.
##
## The order is refused (and its cost is spent) when the foe carries the trait `immune_tag`,
## holds a status tagged `canceller_tag`, or was already commanded under `once_flag`; and, in
## the field, when the foe is farther than `reach` metres or behind the user (`sight`).
## `once_flag` makes each foe answer to one look only: the flag `<once_flag>/<foe id>` is saved
## in `Flags`, so it holds across fights. A canceller lifts it: the order is refused, the flag
## is cleared, and a later order works once the canceller is gone.
##
## OWNS: the shape of a command.
## MUST NOT: hold running state. `CommandRun` (gameplay) runs it.

enum Order { OBEY, STOP, FORGET, FALL }

@export var order: Order = Order.STOP
## OBEY and STOP: what the foe is given. FORGET and FALL: an optional mark. Null for none.
@export var status: StatusEffect
## Field: metres the foe may stand from the user. 0: any distance.
@export var reach: float = 0.0
## Field: the foe must stand in front of the user.
@export var sight: bool = true
## A foe with this trait refuses the order. Empty: none refuses.
@export var immune_tag: StringName = &""
## A foe holding a status with this tag refuses, and its once flag is cleared. Empty: none.
@export var canceller_tag: StringName = &""
## The flag family that makes each foe answer once. Empty: no once rule.
@export var once_flag: String = ""


func kind() -> StringName:
	return &"command"


func statuses() -> Array[StatusEffect]:
	var out: Array[StatusEffect] = []
	if status != null:
		out.append(status)
	return out


## A command is aimed at one foe, so a battle offers the foes.
func aims_at_foes() -> bool:
	return true


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if order == Order.OBEY and (status == null or not status.obeys):
		found.append("%s orders OBEY but its status does not obey" % context)
	if order == Order.STOP and (status == null or not status.has_block(StatusEffect.Block.SKIP_TURN)):
		found.append("%s orders STOP but its status does not skip turns" % context)
	if reach < 0.0:
		found.append("%s has a negative reach" % context)
	if status != null:
		found.append_array(status.problems())
	return found
