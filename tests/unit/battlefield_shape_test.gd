extends TestCase
## Battlefield shapes (C10.33): a circle left at a point stays there when the caster walks away;
## a line holds a foe ahead and not one beside or behind; a zone is a box; an effect for TAGGED
## fighters reaches only those carrying the tag.
##
## OWNS: assertions about `BattlefieldShape.covers` and `BattlefieldEffect.Who.TAGGED`.
## MUST NOT: name a game's kits or fighters, or wait for frames.

func run() -> void:
	plan(4)
	SaveFixture.activate()
	var field := BattlefieldMechanism.new()
	field.shape = BattlefieldMechanism.Shape.AT_POINT
	field.radius = 3.0
	var away: Vector3 = Vector3(-20, 0, 0)
	equal("a circle left at a point covers what is near the point, wherever the caster is",
		[BattlefieldShape.covers(field, away, Vector3(10, 0, 0), Vector3.FORWARD, Vector3(11, 0, 0)),
			BattlefieldShape.covers(field, away, Vector3(10, 0, 0), Vector3.FORWARD, away)], [true, false])
	field.shape = BattlefieldMechanism.Shape.LINE
	field.length = 10.0
	field.width = 2.0
	equal("a line holds a foe ahead and not one beside or behind",
		[_covers(field, Vector3(0, 0, -5)), _covers(field, Vector3(3, 0, -5)), _covers(field, Vector3(0, 0, 5))], [true, false, false])
	field.shape = BattlefieldMechanism.Shape.ZONE
	field.size = Vector3(6, 4, 6)
	equal("a zone is a box", [_covers(field, Vector3(2, 1, 2)), _covers(field, Vector3(4, 0, 0)), _covers(field, Vector3(0, 3, 0))],
		[true, false, false])
	var marked := BattlefieldEffect.new()
	marked.who = BattlefieldEffect.Who.TAGGED
	marked.tag = &"fixture_marked"
	field.effects = [marked]
	var caster := Combatant.new()
	caster.combatant_id = &"fixture_shape_caster"
	var tagged := Combatant.new()
	tagged.combatant_id = &"fixture_shape_tagged"
	tagged.traits = [&"fixture_marked"]
	var plain := Combatant.new()
	plain.combatant_id = &"fixture_shape_plain"
	equal("an effect for TAGGED fighters reaches only those with the tag",
		[BattlefieldGroups.effects_for(caster, field, tagged).size(), BattlefieldGroups.effects_for(caster, field, plain).size()], [1, 0])
	for each: Combatant in [caster, tagged, plain]:
		each.free()


func _covers(field: BattlefieldMechanism, at: Vector3) -> bool:
	return BattlefieldShape.covers(field, Vector3.ZERO, Vector3.ZERO, Vector3.FORWARD, at)
