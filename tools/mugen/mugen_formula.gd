class_name MugenFormula
extends RefCounted
## The formula: one M.U.G.E.N state's facts, in ticks and pixels, become one `ActionMove` (C9.9a).
##
## IN PLAIN WORDS, and written out in `docs/POWERS.md` § Converting a M.U.G.E.N character:
## - TIME: 60 ticks are one second.
## - LENGTH: `metres_per_pixel` is our fighter's height divided by the character's standing
##   body box. A speed in pixels a tick is that times 60.
## - STARTUP is the time to the first hit; ACTIVE runs to the end of the last hit's hurting
##   frames; RECOVERY is the rest of the state.
## - POWER is the mean damage of a hit times `power_scale`; HITS is how many hits fire.
## - POISE is the hit's weight: light 1, medium 2, hard 3, a launcher 4.
## - KNOCKBACK is the slide the push ends in: the push speed divided by 0.15 (their ground
##   friction keeps 85% of a slide each tick), in metres.
## - I-FRAMES are the first stretch with no body box or under `NotHitBy`; the second stretch
##   becomes `iframes2`; a third or later one is noted.
## - ARMOUR is the first stretch under `HitOverride` (hurt, but not pushed).
## - EVENTS: each `PlaySnd` is a sound, each `EnvShake` a screen shake (strength: its pixels
##   over 20, at most 1), each `Pause` or `SuperPause` a hit pause. `MugenEvents` builds them.
## - The HITBOX is the box round the hurting boxes of the first hit's frame, `depth` thick.
## - A button the state waits for before going on gives `chain_after`.
## Sent-out helpers have no field on a move; they are reported in `notes` for the author.
##
## OWNS: the numbers of the conversion.
## MUST NOT: read a file. `MugenState` collects the facts.

const TICKS: float = 60.0
## Their ground friction: a slide loses this much of its speed each tick.
const FRICTION: float = 0.15
## An `EnvShake` this many pixels strong is our strongest shake.
const SHAKE_FULL: float = 20.0


## Our numbers for `facts`, as a dictionary a JSON file can hold. `scale` has
## `metres_per_pixel`, `power_scale`, `depth` and `body_height` (pixels).
static func numbers(facts: Dictionary, scale: Dictionary) -> Dictionary:
	var mpp: float = scale["metres_per_pixel"]
	var hits: Array = facts["hits"]
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return DictRead.get_int(a, "tick") < DictRead.get_int(b, "tick"))
	var length: int = maxi(DictRead.get_int(facts, "length"), 1)
	var first: int = length
	var last: int = 0
	var damage: float = 0.0
	for hit: Dictionary in hits:
		first = mini(first, DictRead.get_int(hit, "tick"))
		last = maxi(last, DictRead.get_int(hit, "until"))
		damage += DictRead.get_float(hit, "damage")
	var out: Dictionary = {"state": facts["state"], "anim": facts["anim"], "hits": hits.size(),
		"length": length / TICKS, "notes": _notes(facts)}
	out["events"] = _events(facts, length)
	var dodges: Array[Vector2i] = _untouchable(facts)
	var armour: Array[Vector2i] = _armour(facts)
	armour.resize(1)
	dodges.resize(2)
	for pair: Array in [["iframes", dodges[0]], ["iframes2", dodges[1]], ["armour", armour[0]]]:
		out[str(pair[0]) + "_from"] = (pair[1] as Vector2i).x / TICKS
		out[str(pair[0]) + "_to"] = (pair[1] as Vector2i).y / TICKS
	out["travel_speed"] = _speed(facts, first, last) * TICKS * mpp
	if hits.is_empty():
		out.merge({"startup": 0.0, "active": length / TICKS, "recovery": 0.0, "power": 0.0})
		return out
	last = clampi(last, first + 1, maxi(length, first + 1))
	var lead: Dictionary = hits[0]
	out.merge({"startup": first / TICKS, "active": (last - first) / TICKS,
		"recovery": maxi(length - last, 0) / TICKS,
		"power": snappedf(damage / hits.size() * DictRead.get_float(scale, "power_scale"), 0.1),
		"poise": lead["weight"], "knockback": snappedf(DictRead.get_float(lead, "push") / FRICTION * mpp, 0.01)})
	out["chain_after"] = out["recovery"]
	for chain: Dictionary in facts["chains"]:
		out["chain_after"] = clampf((DictRead.get_int(chain, "tick") - last) / TICKS, 0.0, DictRead.get_float(out, "recovery"))
		out["chains_to"] = chain["state"]
	_box(out, lead["box"] as Rect2, scale)
	return out


## `numbers` as an `ActionMove` with the id `id`.
static func move(made: Dictionary, id: StringName) -> ActionMove:
	var out := ActionMove.new()
	out.id = id
	out.startup = made["startup"]
	out.active = made["active"]
	out.recovery = made["recovery"]
	out.chain_after = made.get("chain_after", 0.0)
	out.iframes_from = made["iframes_from"]
	out.iframes_to = made["iframes_to"]
	out.iframes2_from = DictRead.get_float(made, "iframes2_from")
	out.iframes2_to = DictRead.get_float(made, "iframes2_to")
	out.armour_from = DictRead.get_float(made, "armour_from")
	out.armour_to = DictRead.get_float(made, "armour_to")
	out.power = made["power"]
	out.hits = maxi(DictRead.get_int(made, "hits"), 1)
	out.poise = made.get("poise", 0)
	out.knockback = made.get("knockback", 0.0)
	out.travel_speed = made["travel_speed"]
	if made.has("hitbox_size"):
		out.hitbox_size = DictRead.get_vector3(made, "hitbox_size")
		out.hitbox_offset = DictRead.get_vector3(made, "hitbox_offset")
	return out


# The hitbox: x is how thick, y how tall, z how far forward (forward is -z); y up from the feet,
# where a fighter's own origin is (C9.9b: it was from mid-body, which put every box too low).
static func _box(out: Dictionary, box: Rect2, scale: Dictionary) -> void:
	if not box.has_area():
		return
	var mpp: float = scale["metres_per_pixel"]
	var middle: Vector2 = box.get_center()
	out["hitbox_size"] = DictRead.put_vector3(Vector3(DictRead.get_float(scale, "depth"), box.size.y * mpp, box.size.x * mpp))
	out["hitbox_offset"] = DictRead.put_vector3(Vector3(0.0, -middle.y * mpp, -middle.x * mpp))


# Every untouchable stretch: frames with no body box, joined with `NotHitBy` spans.
static func _untouchable(facts: Dictionary) -> Array[Vector2i]:
	var spans: Array[Vector2i] = MugenAir.spans(DictRead.get_array(facts, "frames"), "body", false)
	for held: Vector2i in facts["invincible"]:
		spans.append(held)
	return _merged(spans, maxi(DictRead.get_int(facts, "length"), 1))


# Every stretch under `HitOverride`.
static func _armour(facts: Dictionary) -> Array[Vector2i]:
	var spans: Array[Vector2i] = []
	for held: Vector2i in DictRead.get_array(facts, "armour"):
		spans.append(held)
	return _merged(spans, maxi(DictRead.get_int(facts, "length"), 1))


# `spans` in time order, kept inside `length` ticks, with the ones that touch joined.
static func _merged(spans: Array[Vector2i], length: int) -> Array[Vector2i]:
	spans.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	var out: Array[Vector2i] = []
	for span: Vector2i in spans:
		var held := Vector2i(mini(span.x, length), mini(span.y, length))
		if held.y <= held.x:
			continue
		if not out.is_empty() and held.x <= out[-1].y:
			out[-1] = Vector2i(out[-1].x, maxi(out[-1].y, held.y))
		else:
			out.append(held)
	return out


# The timed events, earliest first, each once: sounds, screen shakes and hit pauses.
static func _events(facts: Dictionary, length: int) -> Array:
	var out: Array = []
	for sound: Dictionary in DictRead.get_array(facts, "sounds"):
		out.append({"tick": sound["tick"], "kind": "sound", "file": "sounds/%d_%d.wav" % [sound["group"], sound["index"]]})
	for shake: Dictionary in DictRead.get_array(facts, "shakes"):
		out.append({"tick": shake["tick"], "kind": "shake", "seconds": maxi(DictRead.get_int(shake, "time"), 1) / TICKS,
			"amount": snappedf(clampf(DictRead.get_float(shake, "ampl") / SHAKE_FULL, 0.05, 1.0), 0.01)})
	for pause: Dictionary in DictRead.get_array(facts, "pauses"):
		out.append({"tick": pause["tick"], "kind": "pause", "seconds": maxi(DictRead.get_int(pause, "time"), 1) / TICKS})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return DictRead.get_int(a, "tick") < DictRead.get_int(b, "tick"))
	var seen: Dictionary = {}
	var kept: Array = []
	for event: Dictionary in out:
		event["at"] = clampi(DictRead.get_int(event, "tick"), 0, length) / TICKS
		event.erase("tick")
		if not seen.has(str(event)):
			seen[str(event)] = true
			kept.append(event)
	return kept


# The fastest forward speed set before the hits end (or at any time, for a move with no hit).
static func _speed(facts: Dictionary, first: int, last: int) -> float:
	var best: float = 0.0
	for speed: Dictionary in facts["speeds"]:
		if (last <= 0 or DictRead.get_int(speed, "tick") <= maxi(last, first)) and absf(DictRead.get_float(speed, "x")) > absf(best):
			best = DictRead.get_float(speed, "x")
	return best


static func _notes(facts: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for spawn: Dictionary in facts["spawns"]:
		out.append("sends out state %d at %.2fs" % [spawn["state"], DictRead.get_int(spawn, "tick") / TICKS])
	if _untouchable(facts).size() > 2:
		out.append("more than two untouchable stretches; only the first two are kept")
	if _armour(facts).size() > 1:
		out.append("more than one armour stretch; only the first is kept")
	for kind: String in facts["skipped"]:
		out.append("not converted: %s x%d" % [kind, facts["skipped"][kind]])
	for need: String in facts["needs"]:
		out.append("depends on: %s" % need)
	return out
