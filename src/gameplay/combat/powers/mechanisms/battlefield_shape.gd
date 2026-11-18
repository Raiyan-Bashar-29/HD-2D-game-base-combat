class_name BattlefieldShape
extends RefCounted
## Where a battlefield reaches in the field (C10.33), moved out of `BattlefieldRun` for its budget.
##
## IN PLAIN WORDS: AROUND is a circle of `radius` around the caster, wherever it walks (0: the
## whole fight). AT_POINT is the same circle left where it was raised: on the aimed foe, else on
## the caster. LINE is a strip `length` long and `width` wide running ahead from where the caster
## stood. ZONE is a box of `size` centred where it was raised. Heights count only for a ZONE.
##
## OWNS: the test of one point against one shape.
## MUST NOT: hold state; the run keeps where and which way it was raised.


## True when `at` lies inside `field`'s shape, raised at `point` facing `facing`, with the caster
## standing at `caster` now.
static func covers(field: BattlefieldMechanism, caster: Vector3, point: Vector3, facing: Vector3, at: Vector3) -> bool:
	match field.shape:
		BattlefieldMechanism.Shape.AT_POINT:
			return field.radius <= 0.0 or _flat(at - point).length() <= field.radius
		BattlefieldMechanism.Shape.LINE:
			var ahead: Vector3 = _flat(facing).normalized()
			var gap: Vector3 = _flat(at - point)
			var along: float = gap.dot(ahead)
			return along >= 0.0 and along <= field.length and absf(gap.dot(ahead.cross(Vector3.UP))) <= field.width / 2.0
		BattlefieldMechanism.Shape.ZONE:
			var half: Vector3 = field.size / 2.0
			var gap: Vector3 = at - point
			return absf(gap.x) <= half.x and absf(gap.y) <= half.y and absf(gap.z) <= half.z
	return field.radius <= 0.0 or _flat(at - caster).length() <= field.radius


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
