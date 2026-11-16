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

## The base's own mechanisms: kind -> executor script path. `form` came in C6.5a, `barrier` in C6.6a,
## `barrage` in C6.7, `plant` in C6.26, `finisher` in C6.8,
## `battlefield` in C6.9a, `blink` in C6.12a, `sacrifice` and `refresh` in C6.12b,
## `foresight` in C6.10, `command` and `grant` in C6.11, `summon` in C8.10a, `clone` in C6.13a, `rewind` in C8.11b, `copy` in C8.13b, `steal` and `random` in C8.13c, `construct` in C8.14a, `wield` in C8.14b, `doors` in C8.14c, `team` in C8.2.
const BUILT_IN: Dictionary[StringName, String] = {
	&"form": "res://src/gameplay/combat/powers/mechanisms/form_run.gd",
	&"barrier": "res://src/gameplay/combat/powers/mechanisms/barrier_run.gd",
	&"barrage": "res://src/gameplay/combat/powers/mechanisms/barrage_run.gd",
	&"plant": "res://src/gameplay/combat/powers/mechanisms/plant_run.gd",
	&"finisher": "res://src/gameplay/combat/powers/mechanisms/finisher_run.gd",
	&"battlefield": "res://src/gameplay/combat/powers/mechanisms/battlefield_run.gd",
	&"summon": "res://src/gameplay/combat/powers/mechanisms/summon_run.gd",
	&"team": "res://src/gameplay/combat/powers/mechanisms/team_run.gd",
	&"blink": "res://src/gameplay/combat/powers/mechanisms/blink_run.gd",
	&"sacrifice": "res://src/gameplay/combat/powers/mechanisms/sacrifice_run.gd",
	&"refresh": "res://src/gameplay/combat/powers/mechanisms/refresh_run.gd",
	&"foresight": "res://src/gameplay/combat/powers/mechanisms/foresight_run.gd",
	&"command": "res://src/gameplay/combat/powers/mechanisms/command_run.gd",
	&"grant": "res://src/gameplay/combat/powers/mechanisms/grant_run.gd",
	&"clone": "res://src/gameplay/combat/powers/mechanisms/clone_run.gd",
	&"rewind": "res://src/gameplay/combat/powers/mechanisms/rewind_run.gd",
	&"copy": "res://src/gameplay/combat/powers/mechanisms/copy_run.gd",
	&"steal": "res://src/gameplay/combat/powers/mechanisms/steal_run.gd",
	&"random": "res://src/gameplay/combat/powers/mechanisms/random_run.gd",
	&"construct": "res://src/gameplay/combat/powers/mechanisms/construct_run.gd",
	&"wield": "res://src/gameplay/combat/powers/mechanisms/wield_run.gd",
	&"doors": "res://src/gameplay/combat/powers/mechanisms/doors_run.gd",
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
