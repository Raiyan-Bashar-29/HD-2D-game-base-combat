extends TestCase
## Combos, juggles and grabs (C10.24): landed hits inside the gap count up and the HUD shows the
## combo, which resets after the gap; a juggled foe takes more from an attacker with
## `juggle_bonus`; a held fighter breaks free after enough struggles; `grab_immune` is never held;
## with `shield_held` on, only the holder may hit a held victim.
##
## OWNS: assertions about `ComboCounter`, `Hurtbox`'s juggle bonus and `Grab`'s escape, immunity
## and shield.
## MUST NOT: name a game's fighters or moves, or wait for frames.

var _world: Node3D
var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(5)
	SaveFixture.activate()
	Flags.clear_all()
	_world = Node3D.new()
	attach(_world)
	var hero: Combatant = _fighter(&"fixture_combo_hero", Vector3.ZERO, {})
	var counter := ComboCounter.new()
	hero.get_parent().add_child(counter)
	var hud := CombatHud.new()
	hud.subject = hero.get_parent()
	attach(hud)
	for i: int in 3:
		Events.combatant_damaged.emit(&"fixture_combo_foe", hero.combatant_id, 4, false)
	var shown: bool = hud.text.contains(tr(CombatHud.COMBO_KEY).format({"count": 3}))
	counter.pass_time(ComboCounter.GAP + 0.1)
	equal("three hits inside the gap make a combo of 3 the HUD shows, and the gap resets it", [shown, counter.count], [true, 0])
	hud.free()
	_juggle(hero)
	_grab()
	_world.free()
	Flags.clear_all()


func _juggle(hero: Combatant) -> void:
	var striker: Combatant = _fighter(&"fixture_combo_striker", Vector3(10, 0, 0), {&"juggle_bonus": 0.5})
	var grounded: Combatant = _fighter(&"fixture_combo_grounded", Vector3(12, 0, 0), {})
	var lifted: Combatant = _fighter(&"fixture_combo_lifted", Vector3(14, 0, 0), {})
	var launch := ActionMove.new()
	launch.launch = 1.0
	Juggle.lift(lifted.get_parent(), launch)
	var blow := ActionMove.new()
	blow.active = 0.1
	blow.power = 10.0
	blow.hitbox_size = Vector3.ONE
	_hurtbox(grounded).take(striker, blow, _rng, Vector3.ZERO)
	_hurtbox(lifted).take(striker, blow, _rng, Vector3.ZERO)
	equal("a juggled foe takes more from an attacker with juggle_bonus", _lost(lifted) > _lost(grounded), true)


func _grab() -> void:
	var holder: Combatant = _fighter(&"fixture_combo_holder", Vector3(20, 0, 0), {})
	var victim: Combatant = _fighter(&"fixture_combo_victim", Vector3(20, 0, -1), {})
	var hitbox := Hitbox.new()
	hitbox.attacker = holder
	hitbox.timeline = MoveTimeline.new()
	holder.get_parent().add_child(hitbox)
	var throw := ActionMove.new()
	throw.startup = 5.0
	throw.active = 0.1
	throw.power = 1.0
	throw.hitbox_size = Vector3.ONE
	hitbox.timeline.start(throw)
	Grab.hold(victim.get_parent() as Node3D, hitbox, throw)
	ProjectSettings.set_setting(Grab.SHIELD_SETTING, true)
	var other := Hitbox.new()
	var shield: Array[bool] = [Grab.shielded(victim.get_parent(), other), Grab.shielded(victim.get_parent(), hitbox)]
	ProjectSettings.set_setting(Grab.SHIELD_SETTING, false)
	other.free()
	equal("with shield_held on, only the holder may hit a held victim", shield, [true, false] as Array[bool])
	var broke: Array[bool] = []
	for i: int in 6:
		broke.append(Grab.struggle(victim.get_parent()))
	equal("six struggles break a held fighter free",
		[broke[4], broke[5], Grab.held(victim.get_parent())], [false, true, false])
	var stone: Combatant = _fighter(&"fixture_combo_stone", Vector3(30, 0, 0), {&"grab_immune": 1.0})
	equal("grab_immune is never held", [Grab.immune(stone.get_parent()), Grab.immune(victim.get_parent())], [true, false])


func _lost(fighter: Combatant) -> int:
	return 100 - Vitals.of(fighter.get_parent()).current(&"hp")


func _hurtbox(fighter: Combatant) -> Hurtbox:
	for child: Node in fighter.get_parent().get_children():
		if child is Hurtbox:
			return child as Hurtbox
	return null


func _fighter(id: StringName, at: Vector3, extra: Dictionary[StringName, float]) -> Combatant:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = StringName("side_" + String(id))
	fighter.real_time = true
	var stats: Dictionary[StringName, float] = {&"max_hp": 100.0, &"attack": 10.0, &"defence": 1.0}
	stats.merge(extra, true)
	fighter.base_stats = stats
	fighter.formula = DamageFormula.new()
	fighter.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(fighter)
	actor.add_child(Hurtbox.new())
	_world.add_child(actor)
	Vitals.of(actor).set_to(&"hp", 100)
	return fighter
