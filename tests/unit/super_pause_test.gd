extends TestCase
## The super pause (C10.34): a PAUSE event with `others_only` stops every other real-time fighter's
## own time for its seconds while the user's runs on, and the fight's clock is untouched; the
## converter marks a superpause so; a sound the converter cannot find is listed for the report.
##
## OWNS: assertions about `MoveEvent.others_only` through `MoveEvents`, the converter's flag and
## `MugenEvents.missing`.
## MUST NOT: name a game's fighters or use fan assets, or wait for frames.

var _bodies: Array[Node] = []


func run() -> void:
	plan(3)
	SaveFixture.activate()
	Flags.clear_all()
	var user: Node3D = _body(&"fixture_spause_user")
	var other: Node3D = _body(&"fixture_spause_other")
	var event := MoveEvent.new()
	event.kind = MoveEvent.Kind.PAUSE
	event.seconds = 0.5
	event.others_only = true
	MoveEvents._stop_others(user, event.seconds)
	var stopped: Array[float] = [FighterTime.rate(user), FighterTime.rate(other), CombatClock.scale]
	StatusSet.of(other).tick_seconds(0.6)
	equal("a super pause stops the others' time, not the user's nor the fight's, and wears off",
		stopped + [FighterTime.rate(other)], [1.0, 0.0, 1.0, 1.0])
	var move := ActionMove.new()
	move.active = 1.0
	MugenEvents.missing.clear()
	MugenEvents.fill(move, {"events": [{"kind": "pause", "seconds": 0.3, "at": 0.1, "others_only": true},
		{"kind": "sound", "file": "sounds/fixture_none.wav", "at": 0.1}]}, "res://nowhere")
	equal("the converter marks a super pause as sparing its user", [move.events.size(), move.events[0].others_only], [1, true])
	equal("and lists a sound it could not find for the report", MugenEvents.missing, PackedStringArray(["sounds/fixture_none.wav"]))
	MugenEvents.missing.clear()
	for body: Node in _bodies:
		body.free()
	Flags.clear_all()


func _body(id: StringName) -> Node3D:
	var actor := Node3D.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 10.0}
	actor.add_child(fighter)
	attach(actor)
	_bodies.append(actor)
	return actor
