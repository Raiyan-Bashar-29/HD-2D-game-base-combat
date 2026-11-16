extends TestCase
## What the player sees (C8.17). A move's timed press shows the `press` cue while its window is
## open and clears it after; an unseen player is drawn faded and whole again once seen; a ledger's
## held hits are announced as one hurt when it ends.
##
## OWNS: assertions about `ActionFighter`'s prompt cue, `Unseen.fade` and `Delayed`'s release.
## MUST NOT: name a game's kits, powers or characters, or wait for physics.

const DT: float = 0.05

var _cues: Array[StringName] = []
var _hurts: Array[int] = []


func run() -> void:
	plan(4)
	SaveFixture.activate()
	Flags.clear_all()
	var player: PlayerController = build("res://scenes/characters/player.tscn") as PlayerController
	attach(player)
	var fighter: ActionFighter = ActionHost.equip(player, _loadout())
	Events.defence_prompt.connect(_on_cue)
	fighter.drive(DT, true, false)
	for _i: int in 4:
		fighter.drive(DT, false, false)
	var during: Array[StringName] = _cues.duplicate()
	for _i: int in 6:
		fighter.drive(DT, false, false)
	equal("a timed press shows its cue while its window is open, then clears it", [during, _cues], [[&"press"], [&"press", &""]])
	Events.defence_prompt.disconnect(_on_cue)
	var cloak := StatusEffect.new()
	cloak.id = &"status/fixture_unseen"
	cloak.unit = StatusEffect.Unit.SECONDS
	cloak.duration = 5.0
	cloak.unseen = true
	StatusSet.of(player).apply(cloak)
	fighter.drive(DT, false, false)
	var sprite: Sprite3D = (player.get_node(^"Visual") as CharacterVisual).sprite
	var faded: float = sprite.modulate.a
	StatusSet.of(player).cure(cloak.id)
	fighter.drive(DT, false, false)
	equal("an unseen fighter is drawn faded, and whole once seen", [is_equal_approx(faded, Unseen.FADED), sprite.modulate.a], [true, 1.0])
	_ledger(player)
	player.free()
	Flags.clear_all()


func _ledger(player: PlayerController) -> void:
	var hold := StatusEffect.new()
	hold.id = &"status/fixture_ledger"
	hold.unit = StatusEffect.Unit.SECONDS
	hold.duration = 5.0
	hold.ledger = true
	var me: Combatant = Combatant.of(player)
	StatusSet.of(player).apply(hold)
	Events.combatant_damaged.connect(_on_hurt)
	Delayed.bank(me, -4)
	Delayed.bank(me, -3)
	var held: int = _hurts.size()
	StatusSet.of(player).cure(hold.id)
	Events.combatant_damaged.disconnect(_on_hurt)
	equal("held hits are not announced while held", held, 0)
	equal("they are announced as one hurt when the ledger ends", _hurts, [7])


func _on_cue(kind: StringName, _seconds: float) -> void:
	_cues.append(kind)


func _on_hurt(_who: StringName, _by: StringName, amount: int, _critical: bool) -> void:
	_hurts.append(amount)


func _loadout() -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_seer"
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"attack": 3.0}
	var swing := ActionMove.new()
	swing.startup = 0.2
	swing.active = 0.2
	swing.recovery = 0.2
	swing.prompt = TimedWindow.new()
	swing.prompt.opens = 0.1
	swing.prompt.closes = 0.3
	var made := ActionLoadout.new()
	made.fighter = def
	made.moves = MoveSet.new()
	made.moves.attack_chain = [swing]
	return made
