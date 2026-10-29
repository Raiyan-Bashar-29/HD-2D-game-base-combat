extends ColorRect
## The black rectangle that area transitions hide behind.
##
## Listens for Events.screen_fade_requested and nothing else. Director asks for a fade
## without knowing this node exists, which is exactly the case the event bus is for: the
## sender does not care who performs it, and a cutscene can later ask for the same fade.
##
## Starts fully black so the very first frame of a fresh boot is not a flash of an
## unlit, unpopulated world.
##
## AND THE SECOND CONSUMER OF `accessibility/reduce_motion`. A full-screen rectangle animating
## its alpha is the largest single piece of motion this template draws — larger than the
## typewriter `DialogueScreen` skips for the same setting — so a player who asked to be spared
## motion is handed the cut instead of the dissolve. The effect is identical to a fade of zero
## seconds, which this node already knew how to perform, so honouring the setting is one branch
## and no new code path.
##
## THE CUT IS DELIBERATELY NOT A FASTER FADE. Halving the duration is still animation, and a
## preference that only makes motion briefer has not honoured the request; `DialogueScreen` made
## the same choice for the same reason and its header says so.
##
## OWNS: the fade rectangle and its tween.
## MUST NOT: know why the screen is fading, or who asked. It performs one visual effect.

const START_OPAQUE: bool = true
## Named here, on the consumer, which is `DialogueScreen.REDUCE_MOTION`'s convention and
## `PlayerController.PACE`'s before it: a setting nobody reads has nowhere to be written down.
const REDUCE_MOTION: String = "accessibility/reduce_motion"

var _tween: Tween = null


func _ready() -> void:
	# Never intercept clicks. A full-screen rectangle that eats input is a bug that takes
	# an hour to find.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep fading even when the game is paused, so a pause during a transition does not
	# leave the screen stuck black.
	process_mode = Node.PROCESS_MODE_ALWAYS
	color = Color(0.0, 0.0, 0.0, 1.0 if START_OPAQUE else 0.0)
	Events.screen_fade_requested.connect(_on_fade_requested)


func _on_fade_requested(to_black: bool, seconds: float) -> void:
	var target: float = 1.0 if to_black else 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	# Read per request rather than cached at ready, so a player who changes the setting mid-run
	# gets it on the next transition without this node listening to `setting_changed` at all.
	# There is nothing to un-apply: the choice is made fresh each time the shutter is asked for.
	if seconds <= 0.0 or Settings.get_bool(REDUCE_MOTION):
		color.a = target
		return
	_tween = create_tween()
	_tween.tween_property(self, "color:a", target, seconds)
