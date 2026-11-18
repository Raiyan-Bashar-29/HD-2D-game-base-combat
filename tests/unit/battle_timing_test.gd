extends TestCase
## Timed hits in a turn battle (C10.31): a press in the perfect centre grows the skill most, one
## later in the window less, and no press lands it plain; with hold-to-attack on nothing is timed.
##
## OWNS: assertions about `BattleTiming`, `Skill.prompt` and `SkillUse.timed`.
## MUST NOT: name a game's fighters, skills or encounters, or wait for frames.

var _stack: UiRoot
var _holder: Node


func run() -> void:
	plan(2)
	SaveFixture.activate()
	Flags.clear_all()
	_stack = UiRoot.new()
	attach(_stack)
	_holder = Node.new()
	attach(_holder)
	var strike := BattleCommand.new()
	strike.kind = BattleCommand.Kind.SKILL
	strike.skill = Skill.new()
	strike.skill.id = &"skill/fixture_timing"
	strike.skill.name_key = "fixture.skill"
	strike.skill.power = 4.0
	strike.skill.sure_hit = true
	strike.skill.prompt = TimedWindow.new()
	strike.skill.prompt.opens = 0.3
	strike.skill.prompt.closes = 0.5
	strike.skill.prompt.perfect = 0.06
	var lost: Array[int] = []
	for wait: float in [0.4, 0.46, -1.0]:
		lost.append(_lost_after(strike, wait))
	equal("a perfect press grows it most, a later one less, and no press lands it plain",
		[lost[0] > lost[1], lost[1] > lost[2], lost[2] > 0], [true, true, true])
	if Settings.default_of(CombatSettings.HOLD_TO_ATTACK) == null:
		Settings.game.add(CombatSettings.HOLD_TO_ATTACK, false)
	var before: bool = Settings.get_bool(CombatSettings.HOLD_TO_ATTACK)
	Settings.set_value(CombatSettings.HOLD_TO_ATTACK, true)
	var held: bool = BattleTiming.wants(strike)
	Settings.set_value(CombatSettings.HOLD_TO_ATTACK, false)
	equal("with hold-to-attack on nothing is timed", [held, BattleTiming.wants(strike)], [false, true])
	Settings.set_value(CombatSettings.HOLD_TO_ATTACK, before)
	_holder.free()
	_stack.free()
	Flags.clear_all()


# One battle: the member's skill, pressed `wait` seconds in (below 0: never pressed). The hp the
# foe lost.
func _lost_after(strike: BattleCommand, wait: float) -> int:
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_timing"
	encounter.enemies = [_def(&"fixture_timing_foe", &"side_b", 1.0)]
	var hero := _def(&"fixture_timing_hero", &"side_a", 9.0)
	hero.commands = [strike]
	# The same seed each time, so the formula's spread is the same and only the press differs.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var battle: Battle = BattleSetup.build(encounter, [hero], _holder, rng)
	var screen := BattleScreen.for_battle(battle)
	_stack.open(screen)
	var foe: Combatant = battle.enemies[0]
	var timing: BattleTiming = BattleTiming.begin(screen, strike, [foe])
	screen.add_child(timing)
	if wait >= 0.0:
		timing.step(wait)
		timing.press()
	else:
		timing.step(1.0)
	var lost: int = 999 - Vitals.of(foe.get_parent()).current(&"hp")
	_stack.close_all()
	return lost


func _def(id: StringName, side: StringName, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = side
	def.base_stats = {&"max_hp": 999.0, &"speed": speed, &"attack": 10.0, &"defence": 0.0}
	return def
