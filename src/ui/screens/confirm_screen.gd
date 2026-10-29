class_name ConfirmScreen
extends MenuScreen
## A yes-or-no question asked over whatever is open, for any action a player cannot take back.
## Overwriting a save is the first caller; a game's own "discard this?" is the next, and it needs
## no new screen to ask it.
##
## ESCAPE CANNOT DODGE THE QUESTION. `closes_on_cancel` is false, so `UiRoot` leaves cancel and
## pause alone while this is on top: the only ways out are the two rows. A question that cancel
## silently answers "no" teaches a player that cancel is safe until the day it is not.
##
## NO IS WHERE FOCUS LANDS. A player mashing accept through a menu must not overwrite anything,
## so the destructive answer is never the default one — even though it is drawn first.
##
## NO ROW NAMES A KEY, so nothing here asks `KeyBindings.text_for`. Both answers are rows the
## Button already navigates; a hint naming the accept key would be one more string to keep in
## step with the active device for no information the focused row does not already give.
##
## OWNS: the question, one line of detail under it, and which answer was chosen.
## MUST NOT: perform the action itself, know what it is confirming, or close anything but
## itself. The caller hands over a Callable; this screen calls it on "yes" and nothing else.

const SCREEN_ID: StringName = &"confirm"
const YES_KEY: String = "ui.confirm.yes"
const NO_KEY: String = "ui.confirm.no"

## What "yes" does. Called once, before the screen asks to close, so the caller's own redraw has
## already happened by the time the screen underneath is revealed.
var on_yes: Callable = Callable()
## Already translated, because only the caller knows how to format it — a slot header, an item
## name. Empty means no detail line.
var detail: String = ""

var _no_row: Button = null


func _init() -> void:
	screen_id = SCREEN_ID
	pauses_world = true
	closes_on_cancel = false
	opaque = false


## The one way to build a question. Everything is set before `_build` runs, which is on add_child.
static func asking(question_key: String, detail_text: String, action: Callable) -> ConfirmScreen:
	var screen := ConfirmScreen.new()
	screen.title_key = question_key
	screen.detail = detail_text
	screen.on_yes = action
	return screen


func _fill() -> void:
	if detail != "":
		add_note(detail)
	add_row(tr(YES_KEY), _on_yes)
	_no_row = add_row(tr(NO_KEY), request_close)


## Overrides the base so every path that restores focus — a refresh, a reveal — lands on "no".
func focus_first() -> void:
	if _no_row != null and not _no_row.is_queued_for_deletion():
		_no_row.grab_focus()
		return
	super.focus_first()


func _on_yes() -> void:
	if on_yes.is_valid():
		on_yes.call()
	request_close()
