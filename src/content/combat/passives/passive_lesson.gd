class_name PassiveLesson
extends Resource
## One passive a piece of gear teaches (C9.4): which passive, and how many won fights it takes.
## See `docs/PASSIVES.md` § The loadout.
##
## IN PLAIN WORDS: a piece of gear lists lessons (`GearDefinition.teaches`). Each fight the
## wearer wins with the piece on counts once towards every lesson of the piece. When the count
## reaches `fights`, the wearer has LEARNED the passive and keeps it for good, piece or no
## piece. A field foe defeated counts as one fight.
##
## OWNS: the data of one lesson, and checking it.
## MUST NOT: count anything. `PassiveLoadout` (gameplay) keeps the progress.

@export var passive: PassiveSkill
## Won fights needed while the piece is worn. 0 means it is learned at the first win.
@export var fights: int = 1


func problems(where: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if passive == null:
		found.append("%s has a lesson with no passive" % where)
	elif passive.id == &"":
		found.append("%s teaches a passive with no id, so it cannot be saved" % where)
	if fights < 0:
		found.append("%s has a lesson needing fewer than zero fights" % where)
	return found
