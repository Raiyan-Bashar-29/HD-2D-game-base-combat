class_name LookDef
extends Resource
## How a fighter looks while in a form (C6.5d): the transformation you can see. See
## `docs/GEAR.md` Part 4.
##
## IN PLAIN WORDS: until art exists, a look is three placeholder things: a colour the sprite is
## tinted with, a size it is scaled to, and a short tag shown over its head. A form names a
## look (`FormMechanism.look`); `LookSwap` (gameplay) puts it on the body while the form is
## held and takes it off when the form ends. The art slots (sprite frames, a portrait, an aura)
## are added by the row that first reads them, so no field here waits for art.
##
## OWNS: the shape of a look.
## MUST NOT: touch a node. `LookSwap` applies it.

## A name for logs and problems, such as `look/<form>`.
@export var look_id: StringName = &""
## The sprite is multiplied by this colour. White leaves it as drawn.
@export var tint: Color = Color.WHITE
## The visual is scaled by this, on top of its own size. 1.0 leaves it as it is.
@export var scale: float = 1.0
## A localization key shown over the head while the look is on. Empty shows no tag.
@export var label_key: String = ""
## A second costume (C9.9d): while the look is on, this art's sheet and move strips are shown
## in place of the member's. Null keeps the member's art.
@export var art: MemberArt


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = []
	if look_id == &"":
		found.append("%s has a look with no look_id" % context)
	if scale <= 0.0:
		found.append("%s has a look whose scale is not above 0" % context)
	return found
