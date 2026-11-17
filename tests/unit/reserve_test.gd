extends TestCase
## The reserve line (C8.3). A battle built with a reserve keeps it off the field and out of the
## turn order; a party member's SWAP aims only at standing reserve members, brings one into its
## slot and the turn order, sends itself to the reserve and spends the turn. A fallen member, a
## guest and a missing target are refused. The screen offers Swap only while a reserve stands,
## and the log says who came in. `Party.reserve` reads the saved reserve. C8.22c: with the
## encounter's `free_swaps`, Swap says it is free and the one coming in takes the same turn, once a turn.
##
## OWNS: assertions about `BattleReserve`, `Battle.reserve`, the SWAP command and `Party.reserve`.
## MUST NOT: name a game's fighters or encounters, or wait for frames.

const HERO: StringName = &"fixture_reserve_hero"
const BENCH: StringName = &"fixture_reserve_bench"
const SPARE: StringName = &"fixture_reserve_spare"
const FOE: StringName = &"fixture_reserve_foe"

var _swaps: Array = []


func run() -> void:
	plan(10)
	SaveFixture.activate()
	Flags.clear_all()
	var holder := Node.new()
	attach(holder)
	var stack := UiRoot.new()
	attach(stack)
	var roster: Array[CombatantDef] = [_def(HERO, 9.0), _def(BENCH, 5.0), _def(SPARE, 4.0)]
	Party.arrange([HERO], [BENCH, SPARE])
	equal("the saved reserve is read back in order", _ids(Party.reserve(roster)), [BENCH, SPARE])
	var battle: Battle = BattleSetup.build(_encounter(), [roster[0]], holder, RandomNumberGenerator.new(),
			[], Party.reserve(roster))
	var hero: Combatant = battle.party[0]
	var bench: Combatant = battle.reserve[0]
	var spare: Combatant = battle.reserve[1]
	battle.start()
	equal("the reserve is built but off the field and out of the turn order",
		[battle.reserve.size(), battle.party.size(), battle.scheduler.has(BENCH)], [2, 1, false])
	Vitals.of(spare.get_parent()).change(&"hp", -9999)
	while battle.next_turn() != hero:
		battle.act(_command(BattleCommand.Kind.DEFEND), [])
	var offered: bool = _offered(stack, battle)
	var swap: BattleCommand = _command(BattleCommand.Kind.SWAP)
	equal("Swap is offered and aims only at the standing reserve", [offered, battle.targets_for(swap)],
		[true, [bench]])
	equal("a fallen reserve member or no target is refused",
		[battle.act(swap, [spare]), battle.act(swap, []), battle.current()], [false, false, hero])
	Events.party_swapped.connect(_on_swapped)
	var done: bool = battle.act(swap, [bench])
	Events.party_swapped.disconnect(_on_swapped)
	equal("a swap brings the member into the slot and the turn order, benches the other, and is announced",
		[done, battle.party, battle.reserve.has(hero), battle.scheduler.has(BENCH), battle.scheduler.has(HERO),
			battle.current(), _swaps], [true, [bench], true, true, false, null, [[HERO, BENCH]]])
	equal("a guest cannot swap", BattleReserve.swap(battle, _guest(battle), [hero]), false)
	stack.close_all()
	BattleSetup.release(battle)
	equal("release stands the reserve up too", Vitals.of(spare.get_parent()).is_defeated(), false)
	_free_then_close(stack, holder, roster)
	Flags.clear_all()


# A free swap keeps the turn for the one coming in; a second swap that turn spends it (C8.22c).
func _free_then_close(stack: UiRoot, holder: Node, roster: Array[CombatantDef]) -> void:
	var encounter: Encounter = _encounter()
	encounter.free_swaps = true
	var battle: Battle = BattleSetup.build(encounter, [roster[0]], holder, RandomNumberGenerator.new(),
			[], Party.reserve(roster))
	battle.start()
	var hero: Combatant = battle.party[0]
	var bench: Combatant = battle.reserve[0]
	while battle.next_turn() != hero:
		battle.act(_command(BattleCommand.Kind.DEFEND), [])
	var screen := BattleScreen.for_battle(battle)
	stack.open(screen)
	var offered: bool = screen.row_texts().has(tr(BattleMenu.FREE_SWAP_KEY))
	var swap: BattleCommand = _command(BattleCommand.Kind.SWAP)
	var kept: bool = battle.act(swap, [bench])
	equal("a free swap says so, and the one coming in takes the same turn",
		[offered, kept, battle.current(), battle.party, battle.free_swap_used], [true, true, bench, [bench], true])
	screen.refresh()
	var spent_label: bool = screen.row_texts().has(tr(BattleScreen.SWAP_KEY))
	var again: bool = battle.act(swap, [hero])
	equal("a second swap in the same turn spends it, and the menu said so",
		[again, battle.current(), battle.party, spent_label], [true, null, [hero], true])
	while battle.next_turn() != hero:
		battle.act(_command(BattleCommand.Kind.DEFEND), [])
	equal("the next turn has a free swap again", [battle.free_swap_used, battle.act(swap, [bench]), battle.current()],
		[false, true, bench])
	stack.close_all()
	BattleSetup.release(battle)
	Battle.running = null
	holder.free()
	stack.free()


func _offered(stack: UiRoot, battle: Battle) -> bool:
	var screen := BattleScreen.for_battle(battle)
	stack.open(screen)
	return screen.row_texts().has(tr(BattleScreen.SWAP_KEY))


func _guest(battle: Battle) -> Combatant:
	battle.guests.append(BENCH)
	return battle.party[0]


func _on_swapped(out: StringName, coming: StringName) -> void:
	_swaps.append([out, coming])


func _ids(defs: Array[CombatantDef]) -> Array[StringName]:
	var out: Array[StringName] = []
	for def: CombatantDef in defs:
		out.append(def.combatant_id)
	return out


func _command(kind: BattleCommand.Kind) -> BattleCommand:
	var command := BattleCommand.new()
	command.kind = kind
	return command


func _encounter() -> Encounter:
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_reserve"
	var foe: CombatantDef = _def(FOE, 1.0)
	foe.faction = &"side_b"
	foe.brain = BattleBrain.new()
	encounter.enemies = [foe]
	return encounter


func _def(id: StringName, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name"
	def.faction = &"side_a"
	def.base_stats = {&"max_hp": 40.0, &"attack": 5.0, &"speed": speed}
	def.level_curve = LevelCurve.new()
	return def
