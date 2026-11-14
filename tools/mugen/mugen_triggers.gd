class_name MugenTriggers
extends RefCounted
## Works out WHEN a M.U.G.E.N state controller fires, in ticks from the start of its state (C9.9a).
##
## IN PLAIN WORDS: every controller carries trigger lines. `triggerall` lines must all hold;
## lines sharing a number (`trigger1`, `trigger1`) must all hold together; and any one numbered
## group is enough. Most triggers are about time (`time = 5`, `animelem = 3`, `animtime = 0`),
## and those are turned into a span of ticks. A trigger about something else (a button, a
## variable, the foe's place) cannot be known from the file, so it is listed in `needs` and
## treated as true. A trigger about the hit landing (`movecontact`) sets `on_hit`.
##
## The answer is `{"from", "to", "every", "on_hit", "needs"}`: the controller can fire from
## tick `from` to tick `to`, every `every` ticks when it repeats (0: no repeat).
##
## OWNS: reading trigger lines against one animation.
## MUST NOT: know what the controller does. `MugenState` does.

const _ON_HIT: Array[String] = ["movecontact", "movehit", "moveguarded", "numtarget"]
const _OPS: String = "(=|>=|<=|>|<|!=)"

static var _cache: Dictionary = {}


## When `controller` (an ini section) fires, in a state `length` ticks long playing `frames`.
static func span(controller: Dictionary, frames: Array, length: int) -> Dictionary:
	var out: Dictionary = {"from": 0, "to": length, "every": 0, "on_hit": false,
		"needs": PackedStringArray()}
	var groups: Dictionary = {}
	for pair: Array in MugenIni.starting(controller, "trigger"):
		var key: String = pair[0]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(str(pair[1]))
	var all: Vector3i = Vector3i(0, length, 0)
	for line: String in groups.get("triggerall", []):
		all = _and(all, _line(line, frames, length, out))
	var hull: Vector3i = Vector3i(-1, -1, 0)
	for key: String in groups:
		if key == "triggerall":
			continue
		var group: Vector3i = all
		for line: String in groups[key]:
			group = _and(group, _line(line, frames, length, out))
		hull = group if hull.x < 0 else Vector3i(mini(hull.x, group.x), maxi(hull.y, group.y),
			maxi(hull.z, group.z))
	if hull.x >= 0:
		out["from"] = hull.x
		out["to"] = hull.y
		out["every"] = hull.z
	return out


# One trigger line: its `&&` parts must all hold, and a part's `||` choices are joined.
static func _line(line: String, frames: Array, length: int, out: Dictionary) -> Vector3i:
	var held: Vector3i = Vector3i(0, length, 0)
	for part: String in line.to_lower().replace(" ", "").replace("\t", "").split("&&"):
		var hull: Vector3i = Vector3i(-1, -1, 0)
		for choice: String in part.split("||"):
			var one: Vector3i = _atom(choice.lstrip("(").rstrip(")"), choice, frames, length, out)
			hull = one if hull.x < 0 else Vector3i(mini(hull.x, one.x), maxi(hull.y, one.y), 0)
		held = _and(held, hull)
	return held


static func _and(a: Vector3i, b: Vector3i) -> Vector3i:
	var from: int = maxi(a.x, b.x)
	return Vector3i(from, maxi(mini(a.y, b.y), from), maxi(a.z, b.z))


# One comparison as (from, to, every). `raw` is kept for the `needs` list.
static func _atom(text: String, raw: String, frames: Array, length: int, out: Dictionary) -> Vector3i:
	var whole: Vector3i = Vector3i(0, length, 0)
	var found: RegExMatch = _match("^time%s(-?\\d+)$" % _OPS, text)
	if found != null:
		return _compare(found.get_string(1), found.get_string(2).to_int(), length)
	found = _match("^time=[\\[(](\\d+),(\\d+)[\\])]$", text)
	if found == null:
		found = _match("^(\\d+)<=?time<=?(\\d+)$", text)
	if found != null:
		return Vector3i(found.get_string(1).to_int(), found.get_string(2).to_int(), 0)
	found = _match("^animelem=(\\d+)(?:,%s?(-?\\d+))?$" % _OPS, text)
	if found == null:
		found = _match("^animelemtime[(](\\d+)[)]%s(-?\\d+)$" % _OPS, text)
	if found != null:
		var base: int = MugenAir.ticks_before(frames, found.get_string(1).to_int())
		var op: String = found.get_string(2) if found.get_string(2) != "" else "="
		var moved: Vector3i = _compare(op, found.get_string(3).to_int(), length - base)
		return Vector3i(moved.x + base, moved.y + base, 0)
	found = _match("^(?:timemod=(\\d+),(\\d+)|time%(\\d+)=(\\d+))$", text)
	if found != null:
		var every: int = (found.get_string(1) + found.get_string(3)).to_int()
		return Vector3i((found.get_string(2) + found.get_string(4)).to_int(), length, maxi(every, 1))
	if text == "animtime=0":
		return Vector3i(length, length, 0)
	if text == "!time":
		return Vector3i(0, 0, 0)
	if text.is_valid_int():
		return whole
	for word: String in _ON_HIT:
		if text.begins_with(word):
			out["on_hit"] = true
			return whole
	var needs: PackedStringArray = out["needs"]
	if not needs.has(raw):
		needs.append(raw)
		out["needs"] = needs
	return whole


static func _compare(op: String, value: int, length: int) -> Vector3i:
	match op:
		"=": return Vector3i(value, value, 0)
		">=": return Vector3i(value, maxi(length, value), 0)
		">": return Vector3i(value + 1, maxi(length, value + 1), 0)
		"<=": return Vector3i(0, value, 0)
		"<": return Vector3i(0, maxi(value - 1, 0), 0)
	return Vector3i(0, length, 0)


static func _match(pattern: String, text: String) -> RegExMatch:
	if not _cache.has(pattern):
		_cache[pattern] = RegEx.create_from_string(pattern)
	return (_cache[pattern] as RegEx).search(text)
