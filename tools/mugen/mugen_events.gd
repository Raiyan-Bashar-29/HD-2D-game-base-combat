class_name MugenEvents
extends RefCounted
## Puts a converted move's timed events on its `ActionMove` (C8.16b).
##
## IN PLAIN WORDS: `MugenFormula` lists a move's events as plain data: a sound file and its
## time, a screen shake, a hit pause. This file turns each into a `MoveEvent` on the move. A
## shot (C8.16c) is a `MoveEvent` SHOT whose move is built by the same formula, its box kept
## inside `most` metres, with its arc, `pierce` and its own sounds (C8.16d). A sound needs
## its file: it is looked for in `folder`, the folder the sprites and sounds were unpacked into. A sound whose file is not there is left out, with no problem said, because
## the author may have unpacked only some sounds.
##
## OWNS: turning the formula's event list into `MoveEvent`s.
## MUST NOT: decide a time or a strength (the formula does), or name a character.


## Fills `move.events` from `made`, the formula's numbers for that move.
static func fill(move: ActionMove, made: Dictionary, folder: String, most: float = INF) -> void:
	for event: Dictionary in DictRead.get_array(made, "events"):
		var out := MoveEvent.new()
		out.at = minf(snappedf(DictRead.get_float(event, "at"), 0.001), move.length())
		out.amount = DictRead.get_float(event, "amount")
		out.seconds = snappedf(DictRead.get_float(event, "seconds"), 0.001)
		match DictRead.get_string(event, "kind"):
			"sound":
				out.kind = MoveEvent.Kind.SOUND
				out.sound = _sound(folder.path_join(DictRead.get_string(event, "file")))
				if folder == "" or out.sound == null:
					continue
			"shake":
				out.kind = MoveEvent.Kind.SHAKE
			"pause":
				out.kind = MoveEvent.Kind.PAUSE
			"shot":
				out.kind = MoveEvent.Kind.SHOT
				out.at_foe = DictRead.get_bool(event, "foe")
				out.offset = DictRead.get_vector3(event, "offset")
				out.shot = MugenFormula.move(DictRead.get_dict(event, "shot"), StringName("%s_shot%d" % [move.id, move.events.size()]))
				out.shot.hitbox_size = out.shot.hitbox_size.min(Vector3.ONE * most)
				out.lift = DictRead.get_float(event, "lift")
				out.gravity = DictRead.get_float(event, "gravity")
				out.pierce = DictRead.get_bool(event, "pierce")
				# The shot's own sounds play on the shot (C8.16d).
				fill(out.shot, DictRead.get_dict(event, "shot"), folder, most)
				if not out.shot.strikes():
					continue
			_:
				continue
		move.events.append(out)


# The sound at `path`: the imported one, else the file read as it is, else nothing.
static func _sound(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	if FileAccess.file_exists(path):
		return AudioStreamWAV.load_from_file(path)
	return null
