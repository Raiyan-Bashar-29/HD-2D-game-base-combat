class_name DialogueDuck
extends Node
## The one OCCASION this template ducks the music for: somebody is talking. It holds the music
## and ambience down for as long as any conversation is running, and lets them back up when the
## last one ends.
##
## WHY THIS FILE EXISTS. `AudioDirector.duck()` and `unduck()` were written in WP-04, typed,
## documented and correct, and **called by nothing anywhere in the repository** — the only
## `duck` a grep found in three phases was the phrase "duck-typed" in a comment. That is the
## eighth instance of the defect this project keeps finding: a declaration nobody consumes,
## through a green ladder every time. T5.4 built gates that ask the consumer question of
## signals and of CSV rows, and T5.5 asked it of settings; **a public method is still
## declarable-and-dead and nothing says so**, so this one had to be found by reading. The row
## it came from allowed deleting the two methods instead, and building won for a plain reason:
## unlike the settings T5.5 removed, there was a real occasion already sitting on the bus.
##
## THE OCCASION IS NOT A NEW SIGNAL. `Events.dialogue_started` and `dialogue_finished` have
## been declared since Phase 0 with one emitter each, and `PlayerController` and
## `InteractionSensor` already listen to them. This is a third listener and nothing more —
## the same shape T5.10's autosave used for `area_entered`, and for the same reason: an
## occasion that already exists needs no new signal.
##
## AND IT IS NOT A SECOND JOB FOR `AudioDirector`, which owns the mixer and not the reasons.
## `SaveSystem` owns the save format and `Autosave` owns when to write one; `AudioDirector`
## owns how far down a duck goes and this owns what makes it happen. A consuming game that
## wants ducking on a cutscene, a codec call or a boss door deletes nothing here — it calls
## `Audio.duck()` from its own occasion, or adds a node beside this one.
##
## IT COUNTS, AND THE COUNT IS THE POINT. A plain duck-on-start / unduck-on-finish pair is
## wrong the first time two conversations overlap — an NPC talking to another NPC while the
## player reads a sign — because the first `dialogue_finished` would lift the music back up
## underneath a conversation still running. Nothing would be red: both handlers correct, both
## signals correct, the music simply back at full volume over dialogue. So the duck goes down
## on the FIRST conversation and comes back up after the LAST, and `held()` is public so an
## assertion can read the count rather than infer it from a decibel.
##
## NOTHING HERE IS GUARDED ON THE RUNNER'S STATE, which is deliberate after gotcha 65.
## `DialogueRunner.stop()` clears `_talk` BEFORE it emits `dialogue_finished`, so a handler
## that asked "is a conversation running?" on the spot would be told no on every single end —
## the same ordering trap that would have refused every autosave. This file asks nothing of
## anyone: the signals ARE the count.
##
## OWNS: how long the music stays down, counted in conversations.
## MUST NOT: know what is being said, touch a bus directly, or decide how far down a duck
## goes. It names an occasion and calls `Audio`.

## Conversations currently holding the music down.
var _held: int = 0


func _ready() -> void:
	Events.dialogue_started.connect(_on_dialogue_started)
	Events.dialogue_finished.connect(_on_dialogue_finished)


## How many conversations are holding the duck down. Public so the balance is assertable as a
## count and not only as a level: a duck and an unduck that both "worked" can still be wrong
## about each other, and that is the failure this file is shaped around.
func held() -> int:
	return _held


func _on_dialogue_started(_speaker_id: StringName) -> void:
	_held += 1
	if _held == 1:
		Audio.duck()


## `maxi` floors the count at zero rather than letting a stray `dialogue_finished` — a load
## that ended a conversation nobody started here, say — drive it negative and leave the music
## ducked for the rest of the session with no way back up.
func _on_dialogue_finished(_speaker_id: StringName) -> void:
	_held = maxi(_held - 1, 0)
	if _held == 0:
		Audio.unduck()
