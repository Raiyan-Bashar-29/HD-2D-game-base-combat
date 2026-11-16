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
## `hits` [{tick, until, damage, weight, push, box}], `invincible` and `armour` (tick
## spans), `speeds` [{tick, x}], `spawns` [{tick, state, x, y, foe}], `sounds` [{tick, group,
## index}], `chains` [{tick, state}] (`cancel_on_hit` when one is asked for only after a hit lands,
## C8.19b; each hit also keeps `rise`, `fall` and a throw's `throw` state), `pauses` [{tick, time}] (the screen freezes), `shakes`
## [{tick, time, ampl}], `shots` [{tick, state, x, y, foe, speed, rise, air, pierce, facts}],
## `air` (the state falls: `physics = A`), `effects` [{tick, anim, x, y, length}] (each
## `Explod` of an animation in the character's own file; C8.16e), `skipped`, `needs`. Speeds are pixels a tick, y down.
##
## SHOTS (C8.16c): what a state sends out that hurts flies on its own. A `Helper` whose state
## hits, and every `Projectile`, is a shot: where it starts (`x`, `y` pixels from the sender,
## or from the foe when `foe`, M.U.G.E.N's `postype = p2`), its speed (pixels a tick, forward)
## and the facts of its own state. Its hits are not the sender's: the sender's body box does
## not strike for them. A `Projectile` lives `removetime` ticks, else `PROJECTILE_TICKS`, and
## flies through what it strikes only with `projhits` over 1; a helper always does (C8.16d).
##
## OWNS: reading states and their controllers.
## MUST NOT: convert a unit or build a resource. `MugenFormula` does.

## How long a `Projectile` with no `removetime` flies, in ticks.
const PROJECTILE_TICKS: int = 60

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


## The facts of state `number`. With `depth` above 0 it also reads the states its helpers are
## sent into, and theirs, `depth` levels deep (C8.16e: a shot may send out shots).
static func facts(number: int, states: Dictionary, anims: Dictionary, depth: int = 2) -> Dictionary:
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
		"shots": [], "effects": [], "skipped": {},
		"needs": PackedStringArray()}
	var start: PackedFloat64Array = MugenIni.numbers(MugenIni.value(def, "velset", "0") + ",0")
	if start[0] != 0.0 or start[1] != 0.0:
		(out["speeds"] as Array).append({"tick": 0, "x": start[0], "y": start[1]})
	out["air"] = MugenIni.value(def, "physics").to_lower() == "a"
	for ctrl: Dictionary in ctrls:
		_read(ctrl, out, MugenTriggers.span(ctrl, frames, DictRead.get_int(out, "length")), anims)
	if depth > 0:
		_follow(out, states, anims, depth)
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


static func _read(ctrl: Dictionary, out: Dictionary, when: Dictionary, anims: Dictionary) -> void:
	var tick: int = when["from"]
	var kind: String = _type(ctrl)
	var pos: PackedFloat64Array = MugenIni.numbers(MugenIni.value(ctrl, "pos", MugenIni.value(ctrl, "offset", "0,0")) + ",0")
	match kind:
		"hitdef":
			_hit(ctrl, out, when)
		"projectile":
			_projectile(ctrl, out, tick, pos, anims)
		"nothitby":
			if MugenIni.value(ctrl, "value").to_lower().begins_with("s"):
				(out["invincible"] as Array).append(_held(ctrl, when))
		"hitoverride":
			(out["armour"] as Array).append(_held(ctrl, when))
		"velset", "veladd":
			if MugenIni.value(ctrl, "x") != "" or MugenIni.value(ctrl, "y") != "":
				(out["speeds"] as Array).append({"tick": tick, "x": MugenIni.number(ctrl, "x"), "y": MugenIni.number(ctrl, "y")})
		"helper":
			_spawn(ctrl, out, tick, pos)
		"playsnd":
			_sound(ctrl, out, tick)
		"changestate":
			_chain(ctrl, out, when, tick)
		"superpause", "pause":
			(out["pauses"] as Array).append({"tick": tick, "time": int(MugenIni.number(ctrl, "time", 30.0))})
		"envshake":
			(out["shakes"] as Array).append({"tick": tick, "time": int(MugenIni.number(ctrl, "time", 1.0)),
				"ampl": absf(MugenIni.number(ctrl, "ampl", -4.0))})
		"explod":
			_effect(ctrl, out, tick, pos, anims)
		"null", "selfstate", "destroyself", "changeanim", "turn":
			pass
		_:
			var skipped: Dictionary = out["skipped"]
			skipped[kind] = DictRead.get_int(skipped, kind) + 1
			return
	for need: String in when["needs"]:
		if not (out["needs"] as PackedStringArray).has(need) and kind in ["hitdef", "nothitby", "hitoverride"]:
			MugenIni.note(out, "needs", need)


# A `ChangeState` a button asks for is a chain; one asked for only once the hit has landed also
# marks the move `cancel_on_hit` (C8.19b).
static func _chain(ctrl: Dictionary, out: Dictionary, when: Dictionary, tick: int) -> void:
	if not "command" in "".join(when["needs"] as PackedStringArray):
		return
	(out["chains"] as Array).append({"tick": tick, "state": int(MugenIni.number(ctrl, "value"))})
	if DictRead.get_bool(when, "on_hit"):
		out["cancel_on_hit"] = true


# A `PlaySnd`: its group and index.
static func _sound(ctrl: Dictionary, out: Dictionary, tick: int) -> void:
	var sound: PackedFloat64Array = MugenIni.numbers(MugenIni.value(ctrl, "value").trim_prefix("S").trim_prefix("s"))
	(out["sounds"] as Array).append({"tick": tick, "group": int(sound[0]), "index": int(sound[sound.size() - 1])})


# A `Helper`: where it starts, and whether at the foe (`postype = p2`).
static func _spawn(ctrl: Dictionary, out: Dictionary, tick: int, pos: PackedFloat64Array) -> void:
	(out["spawns"] as Array).append({"tick": tick, "state": int(MugenIni.number(ctrl, "stateno")),
		"x": pos[0], "y": pos[1], "foe": MugenIni.value(ctrl, "postype").to_lower().begins_with("p2")})


# An `Explod` of an animation in the character's own file (C8.16e).
static func _effect(ctrl: Dictionary, out: Dictionary, tick: int, pos: PackedFloat64Array, anims: Dictionary) -> void:
	var anim: int = int(MugenIni.number(ctrl, "anim", -1.0))
	if anims.has(anim):
		(out["effects"] as Array).append({"tick": tick, "anim": anim, "x": pos[0], "y": pos[1],
			"length": MugenAir.length(anims[anim] as Array)})


# One or more hits of a HitDef: a repeating trigger hits once each time it fires.
static func _hit(ctrl: Dictionary, out: Dictionary, when: Dictionary) -> void:
	var frames: Array = out["frames"]
	var every: int = when["every"]
	var last: int = DictRead.get_int(when, "to") if every > 0 else DictRead.get_int(when, "from")
	var tick: int = when["from"]
	while (tick < last or tick == DictRead.get_int(when, "from")) and (out["hits"] as Array).size() < 99:
		var until: int = tick + 1
		for run: Vector2i in MugenAir.spans(frames, "hit", true):
			if tick >= run.x and tick < run.y:
				until = run.y
		(out["hits"] as Array).append(_one(ctrl, tick, until, MugenAir.bounds(frames, MugenAir.frame_at(frames, tick), "hit")))
		tick += maxi(every, 1)


static func _one(ctrl: Dictionary, tick: int, until: int, box: Rect2) -> Dictionary:
	return {"tick": tick, "until": until, "damage": MugenIni.number(ctrl, "damage"),
		"weight": _WEIGHTS.get(MugenIni.value(ctrl, "animtype").to_lower(), 4),
		"push": absf(MugenIni.number(ctrl, "ground.velocity")), "box": box,
		"rise": -MugenIni.numbers(MugenIni.value(ctrl, "ground.velocity", "0") + ",0,0")[1],
		"fall": MugenIni.number(ctrl, "fall") > 0.0,
		"throw": int(MugenIni.number(ctrl, "p1stateno")) if MugenIni.value(ctrl, "p2stateno") != "" else 0}


# A `Projectile`: a shot of one hit, its box from the first frame of its `projanim`.
static func _projectile(ctrl: Dictionary, out: Dictionary, tick: int, pos: PackedFloat64Array, anims: Dictionary) -> void:
	var life: int = int(MugenIni.number(ctrl, "removetime", -1.0))
	life = life if life > 0 else PROJECTILE_TICKS
	var frames: Array = anims.get(int(MugenIni.number(ctrl, "projanim", -1.0)), [])
	var sent: Dictionary = {"state": out["state"], "anim": int(MugenIni.number(ctrl, "projanim", -1.0)),
		"frames": frames, "length": life, "hits": [_one(ctrl, 0, life, MugenAir.bounds(frames, 0, "hit"))],
		"invincible": [], "armour": [], "speeds": [], "spawns": [], "sounds": [], "chains": [],
		"pauses": [], "shakes": [], "shots": [], "effects": [], "air": false, "skipped": {}, "needs": PackedStringArray()}
	var velocity: PackedFloat64Array = MugenIni.numbers(MugenIni.value(ctrl, "velocity", "0") + ",0")
	(out["shots"] as Array).append({"tick": tick, "state": out["state"], "x": pos[0], "y": pos[1], "foe": false,
		"speed": velocity[0], "rise": velocity[1], "air": false,
		"pierce": MugenIni.number(ctrl, "projhits", 1.0) > 1.0, "facts": sent})


# The span a NotHitBy or HitOverride holds: from its first firing to its last, plus its `time`.
static func _held(ctrl: Dictionary, when: Dictionary) -> Vector2i:
	return Vector2i(DictRead.get_int(when, "from"), DictRead.get_int(when, "to") + int(MugenIni.number(ctrl, "time", 1.0)))


# Each sent-out helper whose state hurts is a shot, flying at its state's first forward speed.
static func _follow(out: Dictionary, states: Dictionary, anims: Dictionary, depth: int) -> void:
	for spawn: Dictionary in out["spawns"]:
		if not states.has(spawn["state"]):
			continue
		var sent: Dictionary = facts(DictRead.get_int(spawn, "state"), states, anims, depth - 1)
		if (sent["hits"] as Array).is_empty():
			continue
		var speed: Vector2 = Vector2.ZERO
		for entry: Dictionary in sent["speeds"]:
			speed.x = speed.x if speed.x != 0.0 else DictRead.get_float(entry, "x")
			speed.y = speed.y if speed.y != 0.0 else DictRead.get_float(entry, "y")
		var shot: Dictionary = spawn.duplicate()
		shot.merge({"speed": speed.x, "rise": speed.y, "air": sent["air"], "pierce": true, "facts": sent})
		(out["shots"] as Array).append(shot)


static func _type(ctrl: Dictionary) -> String:
	return MugenIni.value(ctrl, "type").to_lower()
