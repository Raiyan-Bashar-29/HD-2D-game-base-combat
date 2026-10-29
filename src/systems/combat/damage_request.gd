class_name DamageRequest
extends RefCounted
## One hit, asked for: whose numbers, against whose, how hard and of what kind.
##
## THE INPUTS ONLY. What came of it is a `DamageResult`, made fresh by `DamageFormula.resolve`,
## so one request can be resolved twice (a preview, then the real thing) and come out the same
## under the same seed.
##
## SHEETS, NOT ACTORS. A request carries the two `StatSheet`s and nothing that names a
## character, so the whole pipeline is pure and is tested without a scene. Who the numbers belong
## to, and where the result lands, is C1.6's `Combatant`. A null sheet reads as all zeroes.
##
## OWNS: the inputs to one resolution.
## MUST NOT: hold the outcome, touch Vitals, read Flags or emit on the bus.

var attacker: StatSheet
var defender: StatSheet
## The hit's own strength, before any stage: a skill's power, a weapon's base.
var power: float = 0.0
## Free StringName, like stat names. Empty means no element, and the element stage skips it.
var element: StringName = &""


static func of(from: StatSheet, to: StatSheet, amount: float, kind: StringName = &"") -> DamageRequest:
	var request := DamageRequest.new()
	request.attacker = from
	request.defender = to
	request.power = amount
	request.element = kind
	return request
