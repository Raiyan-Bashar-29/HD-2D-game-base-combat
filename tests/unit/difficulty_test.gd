extends TestCase
## Difficulty (C5.4a). A difficulty file is found by its id and checked; `choose` turns one on
## through a flag and refuses an unknown id; with one on, a hit the player's side lands on a foe is
## scaled by `dealt` and one it takes by `taken`, while a hit within a side, a miss or a heal is
## left alone; with none on, nothing changes. `Combatant.hit` applies it.
##
## OWNS: assertions about `Difficulty`, `DifficultyDb` and `CombatDifficulty`.
## MUST NOT: name a game's difficulties, or wait for frames.

const EASY: StringName = &"difficulty/fixture_easy"


func run() -> void:
	plan(8)
	SaveFixture.activate()
	Flags.clear_all()
	DifficultyDb.rescan()
	equal("the game's own difficulty files have no problems", DifficultyDb.problems(), PackedStringArray())
	var hard := _difficulty(&"difficulty/fixture_hard", 0.0, 0.0)
	hard.order = -1
	var directory: String = RunScratch.path("difficulty")
	DirAccess.make_dir_recursive_absolute(directory)
	ResourceSaver.save(_difficulty(EASY, 0.5, -0.5), directory.path_join("fixture_easy.tres"))
	ResourceSaver.save(_difficulty(&"difficulty/fixture_broken", -2.0, 0.0), directory.path_join("fixture_broken.tres"))
	ResourceSaver.save(hard, directory.path_join("fixture_hard.tres"))
	DifficultyDb.content_dir = directory
	DifficultyDb.rescan()
	equal("a difficulty is found by its id, a share below -1 is a problem, and they list by order",
		[DifficultyDb.of(EASY) != null, DifficultyDb.problems().size(), Difficulty.new().problems().size(),
			DifficultyDb.ids()], [true, 1, 1, [&"difficulty/fixture_hard", &"difficulty/fixture_broken", EASY]])
	equal("none is on until one is chosen; an unknown id is refused",
		[CombatDifficulty.current(), CombatDifficulty.choose(&"difficulty/fixture_none")], [null, false])
	var holder := Node3D.new()
	attach(holder)
	var hero: Combatant = _fighter(holder, &"fixture_diff_hero", &"player")
	var mate: Combatant = _fighter(holder, &"fixture_diff_mate", &"player")
	var foe: Combatant = _fighter(holder, &"fixture_diff_foe", &"side_b")
	var plain: Array[float] = [_scaled(hero, foe, 10.0), _scaled(foe, hero, 10.0)]
	equal("with none on, a hit is left as it is", plain, [10.0, 10.0])
	equal("choosing one sets the flag", [CombatDifficulty.choose(EASY), Flags.get_string(CombatDifficulty.FLAG)],
		[true, String(EASY)])
	equal("the side's hits are scaled by dealt and the hits it takes by taken; within a side, alone",
		[_scaled(hero, foe, 10.0), _scaled(foe, hero, 10.0), _scaled(hero, mate, 10.0)], [15.0, 5.0, 10.0])
	equal("a heal is left alone", _scaled(hero, foe, -4.0), -4.0)
	var before: int = Vitals.of(foe.get_parent()).current(&"hp")
	var landed: DamageResult = hero.hit(foe, 10.0, &"", RandomNumberGenerator.new(), true)
	equal("Combatant.hit lands the scaled amount", before - Vitals.of(foe.get_parent()).current(&"hp"),
		roundi(landed.amount))
	holder.free()
	Flags.clear_all()
	DifficultyDb.content_dir = DifficultyDb.DIFFICULTY_DIR
	DifficultyDb.rescan()


func _scaled(attacker: Combatant, target: Combatant, amount: float) -> float:
	var result := DamageResult.new()
	result.amount = amount
	CombatDifficulty.scale(attacker, target, result)
	return result.amount


func _difficulty(id: StringName, dealt: float, taken: float) -> Difficulty:
	var made := Difficulty.new()
	made.id = id
	made.name_key = "fixture.difficulty"
	made.dealt = dealt
	made.taken = taken
	return made


func _fighter(holder: Node3D, id: StringName, side: StringName) -> Combatant:
	var actor := Node3D.new()
	actor.add_child(Vitals.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = {&"max_hp": 500.0, &"attack": 10.0}
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(combatant)
	holder.add_child(actor)
	return combatant
