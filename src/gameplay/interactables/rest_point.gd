class_name RestPoint
extends Interactable
## A bed, a bench or a campfire: somewhere to sit and let the hours go by. The player's only
## way of asking the world to move time forward.
##
## WHY A TIME SKIP IS ONE EVENT AND NOT A FAST-FORWARD
## The naive implementation runs the clock quickly until it reaches morning, which means every
## listener in the game - lighting, schedules, weather, ambience - is woken 480 times for an
## eight-hour sleep, and any of them that does real work per minute now does it 480 times in
## one frame. Clock.skip_to_hour exists so that a skip is a single set_time, and this object
## is its only gameplay caller.
##
## WHY THE PLURAL FORM IS PICKED HERE AND NOT BY THE TOAST
## The toast renders `tr(key).format(args)`, and `tr()` on a plural row answers its FIRST form,
## so it read "13 hour slips past". This is the only sender with a count beside a noun, and the
## only one that knows the number, so it asks `translate_plural` for the form the current
## locale's rule picks and sends that. The toast's own `tr()` then passes it through unchanged,
## because resolved text is not a key. A row with no plural form answers itself for any count,
## so a game's existing plain row still works. When a second counted toast arrives, the toast
## should learn a `count` argument instead, and this should move there.
##
## OWNS: which hour it rests until, whether it may be used now, and how many hours it reports.
## MUST NOT: change the lighting, fade the screen, save the game, or know why the hour it
## jumps to matters. It moves the clock. Everything downstream of the clock is somebody else's.

## The hour rested until. If it has already passed today, the rest rolls over to tomorrow -
## a bench you sit on at dawn to reach dusk works with the same field as a bed.
@export_range(0, 23, 1) var target_hour: int = 6
## Refuse before dusk, for a bed that is only for sleeping the night through. Off by default,
## so a bench is usable at any hour.
@export var night_only: bool = false
## Optional toast shown afterwards. A localization key, never raw text.
@export var rested_key: String = ""

## The placeholder the rested toast fills.
const HOURS_ARG: String = "hours"

## Local listeners. `minutes` is how much time was actually skipped.
signal rested(minutes: int)


func _ready() -> void:
	verb = GameEnums.InteractVerb.SIT
	super()


func refusal(_who: Node3D) -> GameEnums.RefusalReason:
	if night_only and not Clock.is_night():
		return GameEnums.RefusalReason.WRONG_TIME
	return GameEnums.RefusalReason.NONE


func perform(_who: Node3D) -> void:
	var skipped: int = Clock.skip_to_hour(target_hour)
	if rested_key != "":
		var hours: int = hours_for(skipped)
		Events.notify_requested.emit(TranslationServer.translate_plural(rested_key, rested_key, hours),
				3.0, {HOURS_ARG: hours})
	rested.emit(skipped)
	Log.info("interact", "%s rested %d minutes to %02d:00" % [name, skipped, Clock.hour])


## The hours a rest reports: the nearest whole hour, and never zero, because a rest always moves
## the clock. `skip_to_hour` skips 1 to 1440 minutes; flooring made anything under an hour "0".
static func hours_for(minutes: int) -> int:
	return maxi(1, roundi(float(minutes) / 60.0))
