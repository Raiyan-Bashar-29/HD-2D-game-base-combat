extends TestCase
## Late outcomes (C8.15a). A delayed hit: a status with `late_power` does nothing while it
## counts down, in turns or in seconds, then its caster's hit lands; a cure stops it; with no
## caster nothing lands. A ledger: hits and heals on the holder are held back and applied as
## one sum when the status runs out or is cured, and a sum that empties the pool fells.
##
## OWNS: assertions about `Delayed`, `StatusEffect.late_power` and `StatusEffect.ledger`.
## MUST NOT: name a game's statuses or fighters. Every name here is made up for the case.

var _actors: Array[Node] = []
var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(8)
	SaveFixture.activate()
	Flags.clear_all()
	_rng.seed = 5
	_late()
	_ledger()
	for actor: Node in _actors:
		actor.free()
	_actors.clear()
	Flags.clear_all()


func _late() -> void:
	var caster: Combatant = _fighter(&"fixture_caster", &"side_a")
	var marked: Combatant = _fighter(&"fixture_marked", &"side_b")
	var mark: StatusEffect = _status(&"status/fixture_mark", 2.0)
	mark.late_power = 30.0
	var endless: StatusEffect = _status(&"status/fixture_never", 0.0)
	endless.late_power = 30.0
	equal("a delayed hit needs a duration", [mark.problems().size(), endless.problems().size()], [0, 1])
	var skill := Skill.new()
	skill.statuses = [mark]
	SkillUse.apply(caster, skill, [marked], _rng)
	var statuses: StatusSet = StatusSet.of(marked.get_parent())
	var at_once: int = _hp(marked)
	statuses.tick_turn()
	var mid: int = _hp(marked)
	statuses.tick_turn()
	equal("nothing lands until the count ends, then the caster's hit does",
		[at_once, mid, _hp(marked) < 500, statuses.stacks(mark.id)], [500, 500, true, 0])
	var saved: Combatant = _fighter(&"fixture_spared", &"side_b")
	statuses = StatusSet.of(saved.get_parent())
	SkillUse.apply(caster, skill, [saved], _rng)
	statuses.cure(mark.id)
	statuses.tick_turn()
	statuses.tick_turn()
	equal("a mark cured before it comes due lands nothing", _hp(saved), 500)
	var timed: Combatant = _fighter(&"fixture_timed_mark", &"side_b")
	statuses = StatusSet.of(timed.get_parent())
	var clock: StatusEffect = _status(&"status/fixture_mark_clock", 1.0)
	clock.unit = StatusEffect.Unit.SECONDS
	clock.late_power = 30.0
	statuses.apply(clock, _rng, caster.combatant_id)
	statuses.tick_seconds(0.6)
	var early: int = _hp(timed)
	statuses.tick_seconds(0.6)
	equal("a delay counted in seconds does the same in the field", [early, _hp(timed) < 500], [500, true])
	var orphan: Combatant = _fighter(&"fixture_orphan", &"side_b")
	statuses = StatusSet.of(orphan.get_parent())
	statuses.apply(mark, _rng, &"fixture_nobody")
	statuses.tick_turn()
	statuses.tick_turn()
	equal("with its caster gone the mark lands nothing", _hp(orphan), 500)


func _ledger() -> void:
	var foe: Combatant = _fighter(&"fixture_debtor_foe", &"side_a")
	var me: Combatant = _fighter(&"fixture_debtor", &"side_b")
	var statuses: StatusSet = StatusSet.of(me.get_parent())
	var book: StatusEffect = _status(&"status/fixture_book", 2.0)
	book.ledger = true
	statuses.apply(book)
	foe.hit(me, 40.0, &"", _rng, true)
	foe.hit(me, 40.0, &"", _rng, true)
	var mend := Skill.new()
	var effect := SkillEffect.new()
	effect.kind = SkillEffect.Kind.HEAL
	effect.amount = 10.0
	mend.effects = [effect]
	SkillUse.apply(me, mend, [me], _rng)
	var held_back: int = _hp(me)
	statuses.tick_turn()
	statuses.tick_turn()
	var settled: int = _hp(me)
	foe.hit(me, 40.0, &"", _rng, true)
	var one: int = settled - _hp(me)
	equal("a ledger holds two hits and a heal, then applies the sum once",
		[held_back, 500 - settled, one > 0], [500, 2 * one - 10, true])
	statuses.apply(book)
	foe.hit(me, 40.0, &"", _rng, true)
	var before: int = _hp(me)
	statuses.cure(book.id)
	equal("a cure settles the ledger too", [before - _hp(me), statuses.has_meta(Delayed.SUM)], [one, false])
	statuses.apply(book)
	for i: int in 40:
		foe.hit(me, 40.0, &"", _rng, true)
	var standing: bool = _hp(me) > 0
	statuses.cure(book.id)
	equal("a sum larger than the pool fells the holder when it settles", [standing, _hp(me)], [true, 0])


func _status(id: StringName, lasts: float) -> StatusEffect:
	var made := StatusEffect.new()
	made.id = id
	made.name_key = "ui.cancel"
	made.duration = lasts
	return made


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")


func _fighter(id: StringName, side: StringName) -> Combatant:
	var actor := Node.new()
	actor.add_child(Vitals.new())
	var statuses := StatusSet.new()
	statuses.save_id = StringName("statuses/" + String(id))
	actor.add_child(statuses)
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = {&"max_hp": 500.0, &"attack": 10.0}
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(combatant)
	attach(actor)
	_actors.append(actor)
	return combatant
