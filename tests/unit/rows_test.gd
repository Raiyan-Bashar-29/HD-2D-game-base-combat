extends TestCase
## Front and back rows (C8.5). A close blow from the back row, or onto a back-row fighter still
## screened by a standing front-row ally, is softened; ranged and magic hits are not; with the
## front row down the back row is open. A landed `knock_back` hit moves its target back and a
## `pull` brings it forward, announced; outside a battle nothing changes.
##
## OWNS: assertions about `Rows`, `Combatant.back_row` and `CombatantDef.back_row`.
## MUST NOT: name a game's fighters or encounters, or wait for frames.

const HERO: StringName = &"fixture_rows_hero"
const ARCHER: StringName = &"fixture_rows_archer"
const FOE: StringName = &"fixture_rows_foe"

var _moves: Array = []


func run() -> void:
	plan(6)
	var holder := Node.new()
	attach(holder)
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_rows"
	var foe: CombatantDef = _def(FOE, &"side_b", false)
	foe.brain = BattleBrain.new()
	encounter.enemies = [foe]
	var battle: Battle = BattleSetup.build(encounter, [_def(HERO, &"side_a", false), _def(ARCHER, &"side_a", true)],
			holder, RandomNumberGenerator.new())
	var hero: Combatant = battle.party[0]
	var archer: Combatant = battle.party[1]
	var enemy: Combatant = battle.enemies[0]
	equal("the definition's row reaches the battle fighter", [hero.back_row, archer.back_row], [false, true])
	equal("a close blow from the back row is halved; from the front it is not",
		[_soft(archer, enemy, []), _soft(hero, enemy, [])], [5.0, 10.0])
	equal("a close blow on a screened back-row fighter is halved; ranged and magic are not",
		[_soft(enemy, archer, []), _soft(enemy, archer, [Rows.RANGED]), _soft(enemy, archer, [Rows.MAGIC])],
		[5.0, 10.0, 10.0])
	Vitals.of(hero.get_parent()).change(&"hp", -9999)
	var open: float = _soft(enemy, archer, [])
	Vitals.of(hero.get_parent()).change(&"hp", 9999)
	equal("with the front row down, the back row is open", open, 10.0)
	Events.row_changed.connect(_on_row)
	Rows.shift(enemy, _hit([Rows.KNOCK_BACK]))
	var knocked: bool = enemy.back_row
	Rows.shift(enemy, _hit([Rows.PULL]))
	Events.row_changed.disconnect(_on_row)
	equal("a knock_back hit moves its target back, a pull brings it forward, each announced",
		[knocked, enemy.back_row, _moves], [true, false, [[FOE, true], [FOE, false]]])
	BattleSetup.release(battle)
	# An ended battle clears `Battle.running`; this one was only released, so clear it here.
	Battle.running = null
	var outside: float = _soft(archer, enemy, [])
	equal("outside a battle nothing changes", outside, 10.0)
	holder.free()


func _soft(attacker: Combatant, target: Combatant, tags: Array[StringName]) -> float:
	var result: DamageResult = _hit(tags)
	Rows.soften(attacker, target, result)
	return result.amount


func _hit(tags: Array[StringName]) -> DamageResult:
	var result := DamageResult.new()
	result.amount = 10.0
	result.tags.assign(tags)
	return result


func _on_row(who: StringName, back: bool) -> void:
	_moves.append([who, back])


func _def(id: StringName, side: StringName, back: bool) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name"
	def.faction = side
	def.back_row = back
	def.base_stats = {&"max_hp": 40.0, &"attack": 5.0, &"speed": 5.0}
	def.level_curve = LevelCurve.new()
	return def
