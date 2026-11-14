class_name MugenState
extends RefCounted
## Collects the FACTS of one M.U.G.E.N state, in its own units: ticks and pixels (C9.9a).
##
## IN PLAIN WORDS: a state is one thing a fighter does (a swing, a dash, a special). It plays
## an animation and runs "controllers", each a small order with a time to fire: `HitDef` (this
## swing hurts), `NotHitBy` (cannot be hit), `HitOverride` (takes the hit without flinching),
## `VelSet` (moves), `Helper` and `Projectile` (send something out), `PlaySnd`, `ChangeState`
## (go on to another state). This file reads those into one dictionary of facts and counts every
## controller it has no use for in `skipped`, so nothing is dropped unseen.
##
## The facts: `state`, `anim`, `attack` (the state calls itself an attack), `length`, `frames`,
## `hits` [{tick, until, damage, weight, push, box, via}], `invincible` and `armour` (tick
## spans), `speeds` [{tick, x}], `spawns` [{tick, state}], `sounds` [{tick, group, index}],
## `chains` [{tick, state}], `pauses` [{tick, time}] (the screen freezes), `shakes` [{tick,
## time, ampl}], `skipped`, `needs`.
##
## OWNS: reading states and their controllers.
## MUST NOT: convert a unit or build a resource. `MugenFormula` does.

const _WEIGHTS: Dictionary = {"": 1, "light": 1, "medium": 2, "med": 2, "hard": 3, "heavy": 3}


## Every state in `sections`: state number -> {"def": its header, "ctrls": its controllers}.
static func index(sections: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	var ctrls: Array = []
	for section: Dictionary in sections:
		var name: String = section["name"]
		if name.begins_with("statedef"):
			ctrls = []
			out[name.trim_prefix("statedef").strip_edges().to_int()] = {"def": section, "ctrls": ctrls}
		elif name.begins_with("state") and not out.is_empty():
			ctrls.append(section)
	return out


## The facts of state `number`. `follow` also reads the states its helpers are sent into.
static func facts(number: int, states: Dictionary, anims: Dictionary, follow: bool = true) -> Dictionary:
	var state: Dictionary = states.get(number, {})
	var def: Dictionary = state.get("def", {})
	var ctrls: Array = state.get("ctrls", [])
	var anim: int = int(MugenIni.number(def, "anim", -1.0))
	for ctrl: Dictionary in ctrls:
		if anim < 0 and _type(ctrl) == "changeanim":
			anim = int(MugenIni.number(ctrl, "value", -1.0))
	var frames: Array = anims.get(anim, [])
	var out: Dictionary = {"state": number, "anim": anim, "frames": frames,
		"attack": MugenIni.value(def, "movetype").to_lower() == "a",
		"length": _length(ctrls, frames), "hits": [], "invincible": [], "armour": [],
		"speeds": [], "spawns": [], "sounds": [], "chains": [], "pauses": [], "shakes": [],
		"skipped": {},
		"needs": PackedStringArray()}
	var start: PackedFloat64Array = MugenIni.numbers(MugenIni.value(def, "velset", "0"))
	if start[0] != 0.0:
		(out["speeds"] as Array).append({"tick": 0, "x": start[0]})
	for ctrl: Dictionary in ctrls:
		_read(ctrl, out, MugenTriggers.span(ctrl, frames, DictRead.get_int(out, "length")))
	if follow:
		_follow(out, states, anims)
	return out


# The state's length: when it leaves with no button asked for, else its animation's length.
static func _length(ctrls: Array, frames: Array) -> int:
	var whole: int = MugenAir.length(frames)
	var best: int = -1
	for ctrl: Dictionary in ctrls:
		if _type(ctrl) not in ["changestate", "selfstate", "destroyself"]:
			continue
		var when: Dictionary = MugenTriggers.span(ctrl, frames, whole)
		var asked: bool = false
		for need: String in when["needs"]:
			asked = asked or need.contains("command")
		if not asked and DictRead.get_int(when, "from") > 0 and (best < 0 or DictRead.get_int(when, "from") < best):
			best = DictRead.get_int(when, "from")
	return best if best > 0 else whole


static func _read(ctrl: Dictionary, out: Dictionary, when: Dictionary) -> void:
	var tick: int = when["from"]
	var kind: String = _type(ctrl)
	match kind:
		"hitdef", "projectile":
			_hit(ctrl, out, when, kind == "projectile")
		"nothitby":
			if MugenIni.value(ctrl, "value").to_lower().begins_with("s"):
				(out["invincible"] as Array).append(_held(ctrl, when))
		"hitoverride":
			(out["armour"] as Array).append(_held(ctrl, when))
		"velset", "veladd":
			if MugenIni.value(ctrl, "x") != "":
				(out["speeds"] as Array).append({"tick": tick, "x": MugenIni.number(ctrl, "x")})
		"helper":
			(out["spawns"] as Array).append({"tick": tick, "state": int(MugenIni.number(ctrl, "stateno"))})
		"playsnd":
			var sound: PackedFloat64Array = MugenIni.numbers(MugenIni.value(ctrl, "value").trim_prefix("S").trim_prefix("s"))
			(out["sounds"] as Array).append({"tick": tick, "group": int(sound[0]),
				"index": int(sound[sound.size() - 1])})
		"changestate":
			if "command" in "".join(when["needs"] as PackedStringArray):
				(out["chains"] as Array).append({"tick": tick, "state": int(MugenIni.number(ctrl, "value"))})
		"superpause", "pause":
			(out["pauses"] as Array).append({"tick": tick, "time": int(MugenIni.number(ctrl, "time", 30.0))})
		"envshake":
			(out["shakes"] as Array).append({"tick": tick, "time": int(MugenIni.number(ctrl, "time", 1.0)),
				"ampl": absf(MugenIni.number(ctrl, "ampl", -4.0))})
		"null", "selfstate", "destroyself", "changeanim", "explod", "turn":
			pass
		_:
			var skipped: Dictionary = out["skipped"]
			skipped[kind] = DictRead.get_int(skipped, kind) + 1
			return
	for need: String in when["needs"]:
		if not (out["needs"] as PackedStringArray).has(need) and kind in ["hitdef", "nothitby", "hitoverride"]:
			MugenIni.note(out, "needs", need)


# One or more hits of a HitDef or Projectile: a repeating trigger hits once each time it fires.
static func _hit(ctrl: Dictionary, out: Dictionary, when: Dictionary, shot: bool) -> void:
	var frames: Array = out["frames"]
	var prefix: String = "proj" if shot and MugenIni.value(ctrl, "damage") == "" else ""
	var every: int = when["every"]
	var last: int = DictRead.get_int(when, "to") if every > 0 else DictRead.get_int(when, "from")
	var tick: int = when["from"]
	while (tick < last or tick == DictRead.get_int(when, "from")) and (out["hits"] as Array).size() < 99:
		var until: int = tick + 1
		for run: Vector2i in MugenAir.spans(frames, "hit", true):
			if tick >= run.x and tick < run.y:
				until = run.y
		(out["hits"] as Array).append({"tick": tick, "until": until, "via": -1 if not shot else 0,
			"damage": MugenIni.number(ctrl, prefix + "damage"),
			"weight": _WEIGHTS.get(MugenIni.value(ctrl, "animtype").to_lower(), 4),
			"push": absf(MugenIni.number(ctrl, "ground.velocity")),
			"box": MugenAir.bounds(frames, MugenAir.frame_at(frames, tick), "hit")})
		tick += maxi(every, 1)


# The span a NotHitBy or HitOverride holds: from its first firing to its last, plus its `time`.
static func _held(ctrl: Dictionary, when: Dictionary) -> Vector2i:
	return Vector2i(DictRead.get_int(when, "from"), DictRead.get_int(when, "to") + int(MugenIni.number(ctrl, "time", 1.0)))


# A state that hurts only through what it sends out takes its hits from those states.
static func _follow(out: Dictionary, states: Dictionary, anims: Dictionary) -> void:
	for spawn: Dictionary in out["spawns"]:
		if not states.has(spawn["state"]):
			continue
		var sent: Dictionary = facts(DictRead.get_int(spawn, "state"), states, anims, false)
		for hit: Dictionary in sent["hits"]:
			var moved: Dictionary = hit.duplicate()
			moved["tick"] = DictRead.get_int(hit, "tick") + DictRead.get_int(spawn, "tick")
			moved["until"] = DictRead.get_int(hit, "until") + DictRead.get_int(spawn, "tick")
			moved["via"] = spawn["state"]
			(out["hits"] as Array).append(moved)


static func _type(ctrl: Dictionary) -> String:
	return MugenIni.value(ctrl, "type").to_lower()
