class_name DictRead
extends RefCounted
## Safe, typed reads out of an untyped Dictionary.
##
## WHY THIS EXISTS
## Everything that arrives from outside the program is untyped: parsed JSON, save sections,
## content files. Godot hands those back as Variant, and this project compiles with
## unsafe_call_argument as an ERROR, so `int(data["hp"])` will not even parse. More
## importantly, a save file edited by hand or written by an older build can contain a string
## where a number belongs, and without a guard that becomes a crash three frames later in
## unrelated code.
##
## Every getter here does the same three things: read, verify the type, fall back to the
## default. A wrong type is never fatal and never silent.
##
## JSON NOTE: JSON has one number type, so a value saved as 5 may come back as 5.0.
## get_int therefore accepts a float and rounds it, and get_float accepts an int.
##
## Usage:
##     var day: int = DictRead.get_int(section, "day", 1)
##     var pos: Vector3 = DictRead.get_vector3(section, "position")


static func get_int(data: Dictionary, key: String, default: int = 0) -> int:
	var value: Variant = data.get(key, default)
	if value is int:
		return value
	if value is float:
		return roundi(value as float)
	return default


static func get_float(data: Dictionary, key: String, default: float = 0.0) -> float:
	var value: Variant = data.get(key, default)
	if value is float:
		return value
	if value is int:
		return float(value as int)
	return default


static func get_bool(data: Dictionary, key: String, default: bool = false) -> bool:
	var value: Variant = data.get(key, default)
	if value is bool:
		return value
	# A JSON round-trip can turn a bool into 0/1. Accept that rather than losing the value.
	if value is int:
		return (value as int) != 0
	return default


static func get_string(data: Dictionary, key: String, default: String = "") -> String:
	var value: Variant = data.get(key, default)
	if value is String:
		return value
	if value is StringName:
		return String(value as StringName)
	return default


## NOT `get_name`. `Resource` declares `resource_name` with the getter `get_name`, and a
## GDScript IS a Resource, so `DictRead.get_name(...)` dispatched to the NATIVE zero-argument
## method and threw at runtime — while compiling perfectly. It cost `Director` its ability to
## read the saved area id, unnoticed, because only a second area could reveal it. Same family
## as `Area3D.priority` and `class_name Container`: check a name against the API dump.
static func get_string_name(data: Dictionary, key: String, default: StringName = &"") -> StringName:
	var value: Variant = data.get(key, default)
	if value is StringName:
		return value
	if value is String:
		return StringName(value as String)
	return default


static func get_dict(data: Dictionary, key: String) -> Dictionary:
	var value: Variant = data.get(key, {})
	if value is Dictionary:
		return value
	return {}


static func get_array(data: Dictionary, key: String) -> Array:
	var value: Variant = data.get(key, [])
	if value is Array:
		return value
	return []


## Vector3 stored as a three-element array, which is how it survives a JSON round-trip.
static func get_vector3(data: Dictionary, key: String, default: Vector3 = Vector3.ZERO) -> Vector3:
	var raw: Array = get_array(data, key)
	if raw.size() != 3:
		return default
	return Vector3(to_float(raw[0]), to_float(raw[1]), to_float(raw[2]))


## The matching writer, so the read and write formats can never drift apart.
static func put_vector3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


## A bare Variant as a float. Not every untyped number arrives inside a Dictionary: the
## progress array ResourceLoader hands back is a plain Array, and `float(value)` on a Variant
## is an unsafe cast, which this project compiles as an error.
static func to_float(value: Variant) -> float:
	if value is float:
		return value
	if value is int:
		return float(value as int)
	return 0.0


## A Color already stored as a Color (from a code-side table), or as a 3/4-element array
## (from JSON). Both appear in this project: keyframe tables in code, content data on disk.
static func get_color(data: Dictionary, key: String, default: Color = Color.WHITE) -> Color:
	var value: Variant = data.get(key, null)
	if value is Color:
		return value
	var raw: Array = get_array(data, key)
	if raw.size() == 3:
		return Color(to_float(raw[0]), to_float(raw[1]), to_float(raw[2]))
	if raw.size() == 4:
		return Color(to_float(raw[0]), to_float(raw[1]), to_float(raw[2]), to_float(raw[3]))
	return default
