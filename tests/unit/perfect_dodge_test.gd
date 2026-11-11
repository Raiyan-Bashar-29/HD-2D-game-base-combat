extends TestCase
## Perfect dodge and no flinch (C6.6c). A hit dodged in the first `perfect_window` seconds of a
## dodge's i-frames is a perfect dodge: `Events.perfect_dodge` follows `attack_dodged`, and a
## gauge rule's `on_perfect_dodge` is paid on top of its `on_dodge`. A hit later in the i-frames
## is a plain dodge. The `knockback_taken` stat scales a push (1 plus the stat), and at -1 there
## is no push at all, so the player is not stunned: it does not flinch.
##
## OWNS: assertions about `ActionMove.perfect_window`, `MoveTimeline.perfectly`, the perfect dodge
## in `Hurtbox.take` and `PowerSet`, and `knockback_taken` in `Hurtbox._push`.
## MUST NOT: name a game's fighters, moves or kits, or wait for frames.

const ME: StringName = &"fixture_dodger"
const FOE: StringName = &"fixture_striker"

var _actors: Array[Node] = []
var _dodged: int = 0
var _perfect: int = 0
var _pushes: Array[Vector3] = []


func run() -> void:
	plan(11)
	SaveFixture.activate()
	Flags.clear_all()
	Events.attack_dodged.connect(_on_dodged)
	Events.perfect_dodge.connect(_on_perfect)
	Events.knockback_requested.connect(_on_push)
	_shapes()
	_the_window()
	_dodges_and_the_gauge()
	_knockback_taken()
	_the_player_does_not_flinch()
	Events.attack_dodged.disconnect(_on_dodged)
	Events.perfect_dodge.disconnect(_on_perfect)
	Events.knockback_requested.disconnect(_on_push)
	for actor: Node in _actors:
		actor.free()
	_actors.clear()
	Flags.clear_all()


func _shapes() -> void:
	equal("a roll with a perfect window inside its i-frames has no problems",
		_roll(0.1).problems("fixture").size(), 0)
	var wide := _roll(2.0)
	var negative := _roll(-0.1)
	equal("a window longer than the i-frames, or below 0, is a problem",
		[wide.problems("fixture").size(), negative.problems("fixture").size()], [1, 1])


func _the_window() -> void:
	var clock := _rolling(_roll(0.2), 0.1)
	var early: bool = clock.perfectly()
	clock.step(0.3)
	equal("early in the i-frames is perfect; later is only untouchable",
		[early, clock.perfectly(), clock.invulnerable()], [true, false, true])
	equal("a roll with no window is never perfect", _rolling(_roll(0.0), 0.05).perfectly(), false)


func _dodges_and_the_gauge() -> void:
	var dodger: Node3D = _actor(ME, &"side_a", {&"max_hp": 50.0})
	var powers := PowerSet.new()
	dodger.add_child(powers)
	powers.equip(_kit())
	var striker: Node3D = _actor(FOE, &"side_b", {&"attack": 2.0})
	var rng := RandomNumberGenerator.new()
	var hurtbox: Hurtbox = _hurtbox(dodger)
	hurtbox.timeline = _rolling(_roll(0.2), 0.05)
	_dodged = 0
	_perfect = 0
	equal("a hit just after the dodge starts counts but does nothing",
		[hurtbox.take(Combatant.of(striker), _swing(0.0), rng, Vector3.ZERO), _hp(dodger)], [true, 50])
	equal("it is a dodge and a perfect one", [_dodged, _perfect], [1, 1])
	equal("the gauge pays on_dodge and on_perfect_dodge", _focus(dodger), 7)
	hurtbox.timeline = _rolling(_roll(0.2), 0.5)
	hurtbox.take(Combatant.of(striker), _swing(0.0), rng, Vector3.ZERO)
	equal("a hit late in the i-frames is a plain dodge", [_dodged, _perfect, _focus(dodger)], [2, 1, 9])
	hurtbox.timeline = null


func _knockback_taken() -> void:
	var striker: Node3D = _actor(&"fixture_pusher", &"side_b", {&"attack": 1.0})
	var rng := RandomNumberGenerator.new()
	var lengths: Array[float] = []
	for taken: float in [0.0, -0.5, -1.0]:
		var target: Node3D = _actor(StringName("fixture_pushed_%d" % lengths.size()), &"side_a",
			{&"max_hp": 99.0, &"knockback_taken": taken})
		target.position = Vector3(3.0, 0.0, 0.0)
		_pushes.clear()
		_hurtbox(target).take(Combatant.of(striker), _swing(2.0), rng, Vector3.ZERO)
		lengths.append(_pushes[0].length() if not _pushes.is_empty() else 0.0)
	equal("knockback_taken scales the push: 0 is whole, -0.5 is half, -1 is none",
		lengths, [2.0, 1.0, 0.0])


func _the_player_does_not_flinch() -> void:
	var striker: Node3D = _actor(&"fixture_brute", &"side_b", {&"attack": 1.0})
	var rng := RandomNumberGenerator.new()
	var stunned: Array[bool] = []
	for taken: float in [0.0, -1.0]:
		var player := build("res://scenes/characters/player.tscn") as PlayerController
		attach(player)
		_actors.append(player)
		player.position = Vector3(2.0, 0.0, 0.0)
		var def := CombatantDef.new()
		def.combatant_id = StringName("fixture_hero_%d" % stunned.size())
		def.faction = &"side_a"
		def.base_stats = {&"max_hp": 40.0, &"knockback_taken": taken}
		var loadout := ActionLoadout.new()
		loadout.fighter = def
		loadout.moves = MoveSet.new()
		var fighter: ActionFighter = ActionHost.equip(player, loadout)
		_hurtbox(player).take(Combatant.of(striker), _swing(2.0), rng, Vector3.ZERO)
		stunned.append(fighter.stunned())
	equal("a pushed player is stunned; one with knockback_taken -1 is not", stunned, [true, false])
	equal("and both were still hurt", Vitals.of(_actors[-1]).current(&"hp") < 40, true)


## A fighter with a hurtbox, in the tree.
func _actor(id: StringName, side: StringName, stats: Dictionary[StringName, float]) -> Node3D:
	var actor := Node3D.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = stats
	combatant.real_time = true
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	attach(actor)
	_actors.append(actor)
	return actor


func _hurtbox(actor: Node) -> Hurtbox:
	for child: Node in actor.get_children():
		if child is Hurtbox:
			return child as Hurtbox
	return null


func _hp(actor: Node) -> int:
	return Vitals.of(actor).current(&"hp")


func _focus(actor: Node) -> int:
	return Vitals.of(actor).current(&"focus")


## A dodge roll untouchable for its first second, with a perfect window of `window` seconds.
func _roll(window: float) -> ActionMove:
	var made := ActionMove.new()
	made.startup = 0.0
	made.active = 0.6
	made.recovery = 0.4
	made.iframes_to = 1.0
	made.perfect_window = window
	return made


## A clock playing `move`, `seconds` in.
func _rolling(move: ActionMove, seconds: float) -> MoveTimeline:
	var clock := MoveTimeline.new()
	clock.start(move)
	clock.step(seconds)
	return clock


func _swing(knockback: float) -> ActionMove:
	var made := ActionMove.new()
	made.startup = 0.0
	made.active = 0.2
	made.recovery = 0.2
	made.power = 3.0
	made.knockback = knockback
	return made


func _kit() -> PowerKit:
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_dodge"
	kit.name_key = "fixture.kit"
	kit.stat_bonuses = [StatModifier.of(&"max_focus", StatModifier.Op.ADD, 100.0, &"any"),
		StatModifier.of(&"start_focus", StatModifier.Op.ADD, 0.0, &"any")]
	var focus := GaugeRule.new()
	focus.pool = &"focus"
	focus.on_dodge = 2.0
	focus.on_perfect_dodge = 5.0
	kit.gauges = [focus]
	return kit


func _on_dodged(_who: StringName, _by: StringName) -> void:
	_dodged += 1


func _on_perfect(_who: StringName, _by: StringName) -> void:
	_perfect += 1


func _on_push(_who: StringName, push: Vector3) -> void:
	_pushes.append(push)
