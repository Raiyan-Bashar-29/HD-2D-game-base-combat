extends TestCase
## A weapon's own swing chain (C7.3b): a worn piece's `moves`, or its type's, replace the
## wearer's field chain, and its dodge when it has one, while the wearer keeps its own skills.
##
## OWNS: assertions about `GearDefinition.strike_moves`, the `moves` checks on a piece and a type,
## what `GearSet` writes into `Combatant.lent_moves`, `Combatant.field_moves` and
## `ActionFighter.current_moves` playing it.
## MUST NOT: name a game's gear, items or characters, or wait for frames. The gear files are
## written to this run's scratch directory, over the fixture items.

const LANCE: StringName = FixtureContent.STACK_ITEM
const HELM: StringName = FixtureContent.WORN_ITEM
const HERO: StringName = &"fixture_swinger"
# Each move's `power` tells the sets apart once the files are loaded back.
const OWN_POWER: float = 1.0
const TYPE_POWER: float = 5.0
const PIECE_POWER: float = 7.0
const HELM_POWER: float = 9.0

var _directory: String


func run() -> void:
	plan(12)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_write_gear()
	_content()
	_playing()
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	Flags.clear_all()


func _content() -> void:
	var lance: GearDefinition = GearDb.for_item(LANCE)
	equal("a piece with no moves of its own lends its type's", _power_of(lance.strike_moves()), TYPE_POWER)
	lance.moves = _kit_moves(PIECE_POWER, false)
	equal("its own moves win over the type's", _power_of(lance.strike_moves()), PIECE_POWER)
	lance.moves = null
	var bare := GearDefinition.new()
	equal("a piece with neither lends none", bare.strike_moves() == null, true)
	equal("the fixture piece has no problems", lance.problems().size(), 0)
	lance.moves = MoveSet.new()
	equal("a piece whose moves have no chain is a problem", lance.problems().size() > 0, true)
	lance.moves = null
	var kind := GearType.new()
	kind.type_id = &"gear_type/fixture_bad"
	kind.name_key = "ui.cancel"
	kind.slots = [&"weapon"]
	kind.moves = MoveSet.new()
	equal("a type whose moves have no chain is a problem", kind.problems("fixture").size(), 1)


func _playing() -> void:
	var body: Node = _body()
	var me: Combatant = Combatant.of(body)
	var fighter: ActionFighter = body.get_node("ActionFighter") as ActionFighter
	var gear: GearSet = GearSet.of(body)
	equal("with nothing worn the fighter plays its own chain", _power_of(fighter.current_moves()), OWN_POWER)
	gear.wear(LANCE)
	var playing: MoveSet = fighter.current_moves()
	equal("a worn weapon's chain is played in the field", _power_of(playing), TYPE_POWER)
	equal("a weapon with no dodge keeps the fighter's dodge, and its own skills",
		[playing.dodge == fighter.moves.dodge, playing.skills == fighter.moves.skills], [true, true])
	equal("the same set comes back until something changes", fighter.current_moves() == playing, true)
	gear.wear(HELM)
	equal("the weapon speaks first: a helm's moves do not replace its chain",
		[_power_of(me.lent_moves), _power_of(fighter.current_moves())], [TYPE_POWER, TYPE_POWER])
	gear.take_off(LANCE)
	gear.take_off(HELM)
	equal("with the gear off, the fighter's own moves are back",
		[me.lent_moves == null, fighter.current_moves() == fighter.moves], [true, true])


func _body() -> Node:
	var body := CharacterBody3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = HERO
	fighter.base_stats = {&"max_hp": 40.0, &"attack": 2.0}
	body.add_child(fighter)
	var gear := GearSet.new()
	gear.kept = false
	body.add_child(gear)
	var action := ActionFighter.new()
	action.name = "ActionFighter"
	action.moves = _kit_moves(OWN_POWER, true)
	action.moves.skills = [_move(OWN_POWER)]
	action.set_physics_process(false)
	body.add_child(action)
	attach(body)
	return body


func _write_gear() -> void:
	_directory = RunScratch.path("gear_moves")
	DirAccess.make_dir_recursive_absolute(_directory)
	var lance := _type("fixture_lance", &"weapon")
	lance.moves = _kit_moves(TYPE_POWER, false)
	_save("fixture_lance", LANCE, lance, null)
	_save("fixture_helm", HELM, _type("fixture_plate", &"head"), _kit_moves(HELM_POWER, true))
	GearDb.content_dir = _directory
	GearDb.rescan()


func _type(name: String, slot: StringName) -> GearType:
	var made := GearType.new()
	made.type_id = StringName("gear_type/" + name)
	made.name_key = "ui.cancel"
	made.slots = [slot]
	return made


func _save(name: String, item_id: StringName, kind: GearType, moves: MoveSet) -> void:
	var made := GearDefinition.new()
	made.id = StringName(GearDb.ID_PREFIX + name)
	made.item_id = item_id
	made.type = kind
	made.moves = moves
	ResourceSaver.save(made, _directory.path_join(name + ".tres"))


# A two-swing chain whose moves all have `power`, and a dodge when `dodge` is true.
func _kit_moves(power: float, dodge: bool) -> MoveSet:
	var made := MoveSet.new()
	made.attack_chain = [_move(power), _move(power)]
	if dodge:
		made.dodge = _move(power)
		made.dodge.iframes_from = 0.0
		made.dodge.iframes_to = 0.1
	return made


func _move(power: float) -> ActionMove:
	var made := ActionMove.new()
	made.startup = 0.05
	made.active = 0.1
	made.recovery = 0.1
	made.chain_after = 0.05
	made.power = power
	return made


# The power of the first swing in `moves`' chain, or -1 for none.
func _power_of(moves: MoveSet) -> float:
	return moves.attack_chain[0].power if moves != null and not moves.attack_chain.is_empty() else -1.0
