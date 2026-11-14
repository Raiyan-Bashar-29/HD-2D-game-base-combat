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
## - I-FRAMES are the first stretch with no body box or under `NotHitBy`; later ones are noted.
## - The HITBOX is the box round the hurting boxes of the first hit's frame, `depth` thick.
## - A button the state waits for before going on gives `chain_after`.
## Super armour (`HitOverride`), sent-out helpers, sounds and screen pauses have no field on a
## move; they are reported in `notes` for the author.
##
## OWNS: the numbers of the conversion.
## MUST NOT: read a file. `MugenState` collects the facts.

const TICKS: float = 60.0
## Their ground friction: a slide loses this much of its speed each tick.
const FRICTION: float = 0.15


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
	var sounds: Array = []
	for sound: Dictionary in facts["sounds"]:
		sounds.append({"at": DictRead.get_int(sound, "tick") / TICKS, "file": "sounds/%d_%d.wav" % [sound["group"], sound["index"]]})
	out["sounds"] = sounds
	var dodge: Vector2i = _iframes(facts)
	out["iframes_from"] = dodge.x / TICKS
	out["iframes_to"] = dodge.y / TICKS
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


# The first untouchable stretch: frames with no body box, joined with `NotHitBy` spans.
static func _iframes(facts: Dictionary) -> Vector2i:
	var spans: Array[Vector2i] = MugenAir.spans(DictRead.get_array(facts, "frames"), "body", false)
	for held: Vector2i in facts["invincible"]:
		spans.append(held)
	spans.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	if spans.is_empty():
		return Vector2i.ZERO
	var out: Vector2i = spans[0]
	for span: Vector2i in spans:
		if span.x <= out.y:
			out.y = maxi(out.y, span.y)
	out.y = mini(out.y, maxi(DictRead.get_int(facts, "length"), out.x))
	return out


# The fastest forward speed set before the hits end (or at any time, for a move with no hit).
static func _speed(facts: Dictionary, first: int, last: int) -> float:
	var best: float = 0.0
	for speed: Dictionary in facts["speeds"]:
		if (last <= 0 or DictRead.get_int(speed, "tick") <= maxi(last, first)) and absf(DictRead.get_float(speed, "x")) > absf(best):
			best = DictRead.get_float(speed, "x")
	return best


static func _notes(facts: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for held: Vector2i in facts["armour"]:
		out.append("super armour %.2fs to %.2fs" % [held.x / TICKS, held.y / TICKS])
	for spawn: Dictionary in facts["spawns"]:
		out.append("sends out state %d at %.2fs" % [spawn["state"], DictRead.get_int(spawn, "tick") / TICKS])
	if DictRead.get_int(facts, "pause") > 0:
		out.append("screen pause %.2fs" % (DictRead.get_int(facts, "pause") / TICKS))
	if MugenAir.spans(DictRead.get_array(facts, "frames"), "body", false).size() + (facts["invincible"] as Array).size() > 1:
		out.append("more than one untouchable stretch; only the first is kept")
	for kind: String in facts["skipped"]:
		out.append("not converted: %s x%d" % [kind, facts["skipped"][kind]])
	for need: String in facts["needs"]:
		out.append("depends on: %s" % need)
	return out
