extends TestCase
## Team attacks (C8.2). An ally holding a FOLLOW_UP status strikes the foe a party member's plain
## attack just hit; an asleep ally, a failed roll or a missed attack gives none. A dual tech is
## refused while its partner is down and, once used, both strike every foe; an all-out waits
## until every foe is broken, then everyone strikes; in a CTB order the partner is pushed back.
## C8.21: a one-target skill that hurts a foe draws follow-ups too; in a round order a partner
## loses its next turn; team techs sit in their own submenu.
##
## OWNS: assertions about `TeamAttacks`, `TeamMechanism`, `TeamRun` and `PowerUse.Reason.TEAM`.
## MUST NOT: name a game's fighters, kits or encounters, or wait for frames.

const HERO: StringName = &"fixture_team_hero"
const FRIEND: StringName = &"fixture_team_friend"
const FOE: StringName = &"fixture_team_foe"
const DUAL: StringName = &"power/fixture_team_dual"
const ALL_OUT: StringName = &"power/fixture_team_all_out"

var _followed: Array[StringName] = []
var _teams: Array = []
var _holder: Node
var _battle: Battle
var _hero: Combatant
var _friend: Combatant


func run() -> void:
	plan(10)
	_holder = Node.new()
	attach(_holder)
	_build()
	equal("a team tech is a sound mechanism that aims at the foes and makes a TeamRun",
		[_mechanism([], false).problems("fixture").is_empty(), _mechanism([], false).aims_at_foes(),
			PowerMechanisms.make(_mechanism([], false)) is TeamRun, _bad().problems("fixture").size()],
		[true, true, true, 1])
	Events.followed_up.connect(_on_followed)
	Events.team_attacked.connect(_on_team)
	_follow_ups()
	_techs()
	_after_skill()
	_rounds_and_menu()
	Events.followed_up.disconnect(_on_followed)
	Events.team_attacked.disconnect(_on_team)
	BattleSetup.release(_battle)
	_holder.free()


func _follow_ups() -> void:
	var foe: Combatant = _battle.enemies[0]
	var rng := RandomNumberGenerator.new()
	var hit := DamageResult.new()
	var before: int = _hp(foe)
	var count: int = TeamAttacks.after_attack(_hero, foe, hit, rng)
	equal("an ally holding FOLLOW_UP strikes the same foe and is announced; the attacker does not",
		[count, _hp(foe) < before, _followed], [1, true, [FRIEND]])
	var missed := DamageResult.new()
	missed.missed = true
	var after_miss: int = TeamAttacks.after_attack(_hero, foe, missed, rng)
	StatusSet.of(_friend.get_parent()).apply(_sleep())
	var asleep: int = TeamAttacks.after_attack(_hero, foe, hit, rng)
	StatusSet.of(_friend.get_parent()).cure(&"status/fixture_team_sleep")
	StatusSet.of(_friend.get_parent()).reactor(StatusEffect.Reaction.FOLLOW_UP).reaction_chance = 0.0
	var unlucky: int = TeamAttacks.after_attack(_hero, foe, hit, rng)
	StatusSet.of(_friend.get_parent()).reactor(StatusEffect.Reaction.FOLLOW_UP).reaction_chance = 1.0
	equal("a missed attack, an asleep ally and a failed roll give no follow-up",
		[after_miss, asleep, unlucky], [0, 0, 0])


func _techs() -> void:
	var dual: Power = _kit_power(DUAL)
	var all_out: Power = _kit_power(ALL_OUT)
	StatusSet.of(_friend.get_parent()).apply(_sleep())
	var down: PowerUse.Reason = PowerUse.refusal(_hero, dual)
	StatusSet.of(_friend.get_parent()).cure(&"status/fixture_team_sleep")
	equal("a dual tech is refused while its partner is asleep, and ready when it wakes",
		[down, PowerUse.refusal(_hero, dual)], [PowerUse.Reason.TEAM, PowerUse.Reason.NONE])
	var hp: Array[int] = [_hp(_battle.enemies[0]), _hp(_battle.enemies[1])]
	var friend_time: float = (_battle.scheduler as CtbScheduler).wait_of(FRIEND)
	var used: bool = PowerUse.use(_hero, dual, _battle.enemies.duplicate(), RandomNumberGenerator.new())
	equal("used, both strike every foe, and it is announced with both names",
		[used, _hp(_battle.enemies[0]) < hp[0], _hp(_battle.enemies[1]) < hp[1], _teams],
		[true, true, true, [[HERO, FRIEND]]])
	equal("in a CTB order the partner is pushed back",
		(_battle.scheduler as CtbScheduler).wait_of(FRIEND) > friend_time, true)
	var refused: PowerUse.Reason = PowerUse.refusal(_hero, all_out)
	for foe: Combatant in _battle.enemies:
		StatusSet.of(foe.get_parent()).apply(Weakness.broken_status())
	equal("an all-out waits until every standing foe is broken, then everyone strikes",
		[refused, PowerUse.use(_hero, all_out, _battle.enemies.duplicate(), RandomNumberGenerator.new()),
			_teams.back()], [PowerUse.Reason.TEAM, true, [HERO, FRIEND]])


func _after_skill() -> void:
	var foe: Combatant = _battle.enemies[0]
	_followed.clear()
	var skill := Skill.new()
	skill.id = &"skill/fixture_team_jab"
	skill.name_key = "fixture.skill"
	skill.power = 5.0
	skill.sure_hit = true
	TeamAttacks.use_skill(_hero, skill, [foe], RandomNumberGenerator.new(), 0)
	var after_hurt: Array[StringName] = _followed.duplicate()
	var mend := Skill.new()
	mend.id = &"skill/fixture_team_mend"
	mend.name_key = "fixture.skill"
	mend.target = FactionTable.Target.ALLY
	TeamAttacks.use_skill(_hero, mend, [_friend], RandomNumberGenerator.new(), 0)
	equal("a one-target skill that hurts a foe draws the follow-up; one on an ally does not",
		[after_hurt, _followed], [[FRIEND], [FRIEND]])


func _rounds_and_menu() -> void:
	var rounds := RoundScheduler.new()
	rounds.join(&"a", 10.0)
	rounds.join(&"b", 5.0)
	rounds.skip_next(&"b")
	var shown: Array[StringName] = rounds.preview(3)
	equal("in a round order a partner's next turn passes it by, and the preview shows it (C8.23)",
		[shown, rounds.next(), rounds.next(), rounds.next()], [[&"a", &"a", &"b"], &"a", &"a", &"b"])
	var categories: Array[String] = []
	for command: BattleCommand in PowerMenu.commands(_hero):
		categories.append(command.category)
	equal("team techs sit in a submenu of their own", categories,
		[PowerMenu.TEAM_CATEGORY_KEY, PowerMenu.TEAM_CATEGORY_KEY])


func _build() -> void:
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_team"
	encounter.turn_order = Encounter.TurnOrder.CTB
	var foe: CombatantDef = _def(FOE, &"side_b")
	foe.brain = BattleBrain.new()
	var second: CombatantDef = _def(StringName(String(FOE) + "_2"), &"side_b")
	second.brain = BattleBrain.new()
	encounter.enemies = [foe, second]
	var hero: CombatantDef = _def(HERO, &"side_a")
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_team"
	kit.name_key = "fixture.kit"
	kit.powers = [_power(DUAL, _mechanism([FRIEND], false)), _power(ALL_OUT, _mechanism([], true))]
	hero.power_kit = kit
	_battle = BattleSetup.build(encounter, [hero, _def(FRIEND, &"side_a")], _holder, RandomNumberGenerator.new())
	_hero = _battle.party[0]
	_friend = _battle.party[1]
	var follow := StatusEffect.new()
	follow.id = &"status/fixture_team_follow"
	follow.reactions = [StatusEffect.Reaction.FOLLOW_UP]
	StatusSet.of(_friend.get_parent()).apply(follow)


func _mechanism(partners: Array[StringName], broken: bool) -> TeamMechanism:
	var team := TeamMechanism.new()
	team.partners = partners
	team.needs_broken = broken
	team.power = 6.0
	team.partner_delay = 50.0
	return team


func _bad() -> TeamMechanism:
	var team: TeamMechanism = _mechanism([], false)
	team.hits = 0
	return team


func _power(id: StringName, team: TeamMechanism) -> Power:
	var power := Power.new()
	power.power_id = id
	power.name_key = "fixture.power"
	power.mechanism = team
	return power


func _kit_power(id: StringName) -> Power:
	return PowerSet.of(_hero.get_parent()).kit.power(id)


func _sleep() -> StatusEffect:
	var sleep := StatusEffect.new()
	sleep.id = &"status/fixture_team_sleep"
	sleep.duration = 2.0
	sleep.blocks = [StatusEffect.Block.SKIP_TURN]
	return sleep


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")


func _on_followed(who: StringName, _against: StringName) -> void:
	_followed.append(who)


func _on_team(_who: StringName, members: Array[StringName]) -> void:
	_teams.append(members)


func _def(id: StringName, side: StringName) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name"
	def.faction = side
	def.base_stats = {&"max_hp": 400.0, &"attack": 5.0, &"speed": 10.0 if id == HERO else 5.0}
	def.level_curve = LevelCurve.new()
	return def
