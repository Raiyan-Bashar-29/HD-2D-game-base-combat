extends TestCase
## The interaction loop and per-object persistence, driven by direct calls rather than
## simulated input: a gate that refuses until a lever is thrown, and object state that
## survives the object being destroyed and rebuilt.
##
## OWNS: assertions about interactables. MUST NOT: assert on the sensor's ranking, which needs
## real geometry — that is `selection_test.gd`, which T5.20 finally wrote and which found the
## tie-break defect this line's absence had been hiding since WP-02.

var _gate: Gate = null
var _lever: Lever = null

## An area-authored gate amplitude, as 0..1 of the rig's own metres. Not 0.7, which is the
## demo courtyard's taste judgement and would tie this case to content it must not name.
const HEAVY_SHAKE: float = 0.6


func run() -> void:
	plan(25)
	_gating()
	_persistence()
	_the_gates_own_ask()


func _gating() -> void:
	Flags.clear_all()
	# Configure BEFORE attaching: object_id is forwarded in _enter_tree.
	_lever = build("res://scenes/objects/lever.tscn") as Lever
	_lever.object_id = &"t_lever"
	_lever.world_flag = &"test/gate_unlocked"
	_lever.label_key = "fixture.lever.label"
	attach(_lever)
	_gate = build("res://scenes/objects/gate.tscn") as Gate
	_gate.object_id = &"t_gate"
	_gate.requires_flag = &"test/gate_unlocked"
	_gate.label_key = "fixture.gate.label"
	attach(_gate)

	# Locked: the interaction is offered and refused, not hidden. A player must be able to
	# tell a locked gate from scenery, or they never learn to come back.
	equal("gate is offerable while locked", _gate.is_offerable(), true)
	equal("gate refuses with LOCKED", _gate.refusal(null), GameEnums.RefusalReason.LOCKED)
	equal("locked gate attempt fails", _gate.attempt(null), false)
	equal("locked gate did not open", _gate.is_open(), false)

	# The lever knows nothing about the gate; it only publishes a flag.
	equal("lever starts off", _lever.is_on(), false)
	equal("lever throw succeeds", _lever.attempt(null), true)
	equal("lever is on", _lever.is_on(), true)
	equal("lever published its flag", Flags.get_bool(&"test/gate_unlocked"), true)

	# Same gate, same button, now allowed.
	equal("gate no longer refuses", _gate.refusal(null), GameEnums.RefusalReason.NONE)
	equal("gate opens", _gate.attempt(null), true)
	equal("gate is open", _gate.is_open(), true)
	equal("open gate refuses as ALREADY_DONE", _gate.refusal(null), GameEnums.RefusalReason.ALREADY_DONE)
	equal("open gate stops being offered", _gate.is_offerable(), false)


func _persistence() -> void:
	# Identity is authored, so state is addressable without knowing the node path.
	equal("state key format", String(_gate.state().key(&"open")), "obj/global/t_gate/open")
	equal("state landed in Flags", Flags.get_bool(&"obj/global/t_gate/open"), true)

	var gate_scene: PackedScene = load("res://scenes/objects/gate.tscn")
	if _lever != null and is_instance_valid(_lever):
		_lever.free()
	_gate.free()
	_lever = null
	_gate = null

	# Destroy and rebuild, which is what an area reload does. State must survive.
	var rebuilt: Gate = gate_scene.instantiate() as Gate
	rebuilt.object_id = &"t_gate"
	rebuilt.label_key = "fixture.gate.label"
	add_child(rebuilt)
	equal("rebuilt gate is still open", rebuilt.is_open(), true)
	equal("rebuilt gate is not offered again", rebuilt.is_offerable(), false)

	# Clearing one object forgets only that object.
	Flags.set_flag(&"unrelated/keep", true)
	rebuilt.state().clear()
	equal("cleared object state is gone", Flags.has_flag(&"obj/global/t_gate/open"), false)
	equal("unrelated flag survived", Flags.get_bool(&"unrelated/keep"), true)

	rebuilt.free()
	Flags.clear_all()


## THE GATE'S OWN ASK, which until now was proved only by reading four lines of `perform()`.
##
## T5.9 asserted everything on the RIG side - the amplitude, the decay, the player's scale on it -
## and left the emitter to a code read, because the only way to make a gate emit is to open one.
## But a gate can be opened by a direct call, and `perform()` is the same method the sensor calls,
## so the ask is assertable after all: a heavy gate asks for exactly the amplitude its author
## wrote and for the template's own answer about how long a jolt lasts, and a gate whose author
## refused a shake asks for NOTHING while still opening. That last one is the half that matters -
## a bare `emit` with no `if` would keep every other assertion here green.
##
## T5.12 photographed the same two facts through a real interact key, which is what says the ask
## reaches a camera; this says it is the RIGHT ask, and the two together are the claim.
func _the_gates_own_ask() -> void:
	Flags.clear_all()
	var asked: Array[Array] = []
	var listener: Callable = func(strength: float, seconds: float) -> void:
		asked.append([strength, seconds])
	Events.camera_shake_requested.connect(listener)

	var heavy: Gate = build("res://scenes/objects/gate.tscn") as Gate
	heavy.object_id = &"t_heavy_gate"
	heavy.label_key = "fixture.gate.label"
	heavy.open_shake = HEAVY_SHAKE
	attach(heavy)
	equal("a heavy gate opens", heavy.attempt(null), true)
	equal("a heavy gate asked once", asked.size(), 1)
	equal("it asked for the amplitude its author wrote",
		is_equal_approx(DictRead.to_float(asked[0][0]), HEAVY_SHAKE), true)
	equal("it asked for the template's own jolt length",
		is_equal_approx(DictRead.to_float(asked[0][1]), Gate.SHAKE_SECONDS), true)

	# A garden gate. The default is ZERO and zero means silent, so this one opens and says
	# nothing - and a `perform()` that emitted unconditionally would fail here and nowhere else.
	asked.clear()
	var quiet: Gate = build("res://scenes/objects/gate.tscn") as Gate
	quiet.object_id = &"t_quiet_gate"
	quiet.label_key = "fixture.gate.label"
	attach(quiet)
	equal("a silent gate still opens", quiet.attempt(null), true)
	equal("a silent gate asked for nothing", asked.size(), 0)

	Events.camera_shake_requested.disconnect(listener)
	Flags.clear_all()
