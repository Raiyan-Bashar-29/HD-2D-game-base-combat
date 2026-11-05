class_name PowerMechanisms
extends RefCounted
## Which executor runs which mechanism (C6.1b): the one list that maps a `PowerMechanism.kind()`
## to the `PowerExecutor` script that runs it. See `docs/POWERS.md` § The framework.
##
## IN PLAIN WORDS: a power's data says "I am a barrage"; this file says "a barrage is run by
## that script". **Adding a mechanism to the base adds one line to `BUILT_IN`.** A game adds its
## own without touching this file: it calls `register(kind, script)` once at boot, and a kind it
## registers wins over a built-in one of the same name.
##
## OWNS: the kind -> executor table, and making an executor for a mechanism.
## MUST NOT: name a character or a kit, or run an executor itself.

## The base's own mechanisms: kind -> executor script path. The first, `form`, came in C6.5a.
const BUILT_IN: Dictionary[StringName, String] = {
	&"form": "res://src/gameplay/combat/powers/mechanisms/form_run.gd",
}

## Kinds a game (or a test) registered at run time.
static var _registered: Dictionary[StringName, GDScript] = {}


## From now on, mechanisms of `kind` are run by `script`, which must extend `PowerExecutor`.
static func register(kind: StringName, script: GDScript) -> void:
	_registered[kind] = script


## Forgets a kind registered at run time. The built-in table is untouched.
static func unregister(kind: StringName) -> void:
	_registered.erase(kind)


## A new executor for `mechanism`, or null (with a warning) when nothing runs its kind.
static func make(mechanism: PowerMechanism) -> PowerExecutor:
	if mechanism == null:
		return null
	var kind: StringName = mechanism.kind()
	var script: GDScript = _registered.get(kind, null)
	if script == null and BUILT_IN.has(kind):
		script = load(BUILT_IN[kind]) as GDScript
	if script == null:
		Log.warn("powers", "No executor runs mechanism kind '%s'" % kind)
		return null
	var made: PowerExecutor = script.new() as PowerExecutor
	if made == null:
		Log.warn("powers", "The executor for '%s' does not extend PowerExecutor" % kind)
		return null
	made.mechanism = mechanism
	return made
