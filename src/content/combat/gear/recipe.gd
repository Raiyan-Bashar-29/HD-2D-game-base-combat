class_name Recipe
extends ContentEntry
## One thing a craft station can do, as authored data (C7.6). See `docs/GEAR.md` § Crafting.
##
## IN PLAIN WORDS: a recipe says "pay these items, get those items". Its `kind` says which of
## five jobs it is:
##   - CRAFT: `inputs` become `outputs`.
##   - TRANSMUTE: the same, for turning materials into better ones (a separate list on screen).
##   - UPGRADE: `piece` goes up one level of its own track, at the track's cost.
##   - AWAKEN: `piece`, at its cap, is used up with `inputs` and becomes `outputs`.
##   - DISMANTLE: `piece` is used up and gives `outputs`.
## `station` says where it can be done (empty is anywhere), and `needs_flag` hides it until a
## `Flags` key is set, such as a found blueprint. `lucky_chance` is the chance that
## `lucky_outputs` come out in place of `outputs` (a better tier of the same thing).
##
## OWNS: the data of one recipe, and checking it.
## MUST NOT: know what is in a bag, or touch an autoload.

enum Kind { CRAFT, UPGRADE, AWAKEN, DISMANTLE, TRANSMUTE }

@export var name_key: String = ""
@export var kind: Kind = Kind.CRAFT
## What is paid: item id -> how many.
@export var inputs: Dictionary[StringName, int] = {}
## What is given: item id -> how many.
@export var outputs: Dictionary[StringName, int] = {}
## The piece worked on (UPGRADE, AWAKEN, DISMANTLE), by item id.
@export var piece: StringName = &""
## Where it is done, such as `forge`. Empty is anywhere.
@export var station: StringName = &""
## The recipe is known only once this `Flags` key is set. Empty is always known.
@export var needs_flag: StringName = &""
## Given in place of `outputs`, with the chance `lucky_chance` (0 to 1).
@export var lucky_outputs: Dictionary[StringName, int] = {}
@export var lucky_chance: float = 0.0


## True for the kinds that work on one named piece.
func works_on_piece() -> bool:
	return kind == Kind.UPGRADE or kind == Kind.AWAKEN or kind == Kind.DISMANTLE


## Every item id the recipe names, for a checker that knows the item catalogue.
func item_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.append_array(inputs.keys())
	out.append_array(outputs.keys())
	out.append_array(lucky_outputs.keys())
	if piece != &"":
		out.append(piece)
	return out


func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var where: String = "%s (%s)" % [resource_path, id]
	if name_key == "":
		found.append("%s has no name_key" % where)
	found.append_array(UpgradeLevel.cost_problems(where, inputs))
	found.append_array(UpgradeLevel.cost_problems(where, outputs))
	found.append_array(UpgradeLevel.cost_problems(where, lucky_outputs))
	if works_on_piece() != (piece != &""):
		found.append("%s names a piece it does not work on, or works on a piece it does not name" % where)
	if kind == Kind.UPGRADE and not (inputs.is_empty() and outputs.is_empty()):
		found.append("%s is an upgrade, whose cost is the piece's track, but lists items" % where)
	if kind != Kind.UPGRADE and outputs.is_empty():
		found.append("%s gives nothing" % where)
	if (kind == Kind.CRAFT or kind == Kind.TRANSMUTE) and inputs.is_empty():
		found.append("%s costs nothing" % where)
	if kind == Kind.DISMANTLE and not inputs.is_empty():
		found.append("%s is a dismantling but costs items besides the piece" % where)
	if lucky_chance < 0.0 or lucky_chance > 1.0 or (lucky_chance > 0.0) != (not lucky_outputs.is_empty()):
		found.append("%s has a lucky chance outside 0 to 1, or one without lucky outputs" % where)
	return found
