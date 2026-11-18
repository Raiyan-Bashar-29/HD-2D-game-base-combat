class_name BattleSetup
extends RefCounted
## Builds a `Battle` from definitions, and takes it down again. The one place a `CombatantDef`
## becomes nodes, so the battle screen (C2.7), a test and the hybrid (C4) build fighters alike.
##
## EACH FIGHTER IS A PLAIN NODE holding `Vitals`, `StatusSet` and `Combatant`, C1.6's shape,
## added under the holder the caller gives. A group of two of the same enemy is told apart by a
## suffix: `<id>_1`, `<id>_2`, so every flag and signal names one fighter.
##
## THE PARTY IS BUILT AT ITS LEVEL by the caller (`Party.at_level`), so this file never reads
## experience.
##
## ENEMIES START FULL AND LEAVE NO TRACE. Their pool flags are erased when built and again on
## `release`, so a save after the fight carries none of them. The party's are kept: a party
## member's hp is meant to carry from one fight to the next.
##
## HERO POWERS (C6.2a): a definition with a `power_kit` gets a `PowerSet` with that kit equipped,
## on either side. Its cooldowns start fresh each battle; the battle counts them in turns.
##
## GEAR (C7.1b): every party member gets a `GearSet`, and wears what the field body with the same
## id wears. An enemy gets one only when its definition lists starting gear, and it is not saved.
##
## HELPERS (C8.10d): each owned fighter out in the field joins the party's side as a guest
## (`Battle.guests`): same id as its field body, so the same hp, the party's faction, its own
## `brain` or, with none, a plain attack at the first foe. An untouchable one is never picked
## (`Unseen.INERT`). Its gear is not saved and it is not stood back up: one that falls here
## falls in the field too, and leaves.
##
## CALLED MID-BATTLE (C8.10e): `summon` puts a fighter a power brought on its user's side: a
## guest when the user is in the party, one more foe otherwise. It starts full, keeps no gear
## and leaves no pool flags (group `SUMMONED`); `dismiss` takes it out of the battle again.
##
## REINFORCEMENTS (C8.22a): `reinforce` brings the encounter's next `wave` of held-back foes in
## when every foe is down; each is built fresh as the next `<id>_<n>` of its kind (C8.25), in
## group `REINFORCED`.
##
## THE RESERVE LINE (C8.3): `bench` members are built like the party into `Battle.reserve`, off
## the field until a SWAP brings one in; `release` stands them up and frees them like the party.
##
## IN PLAIN WORDS: the factory. Give it an encounter file and the party, and it makes one
## fighter node per combatant, picks the turn order the encounter asked for, and starts the
## `Battle`. `release` cleans everything up afterwards.
##
## OWNS: turning definitions into fighters, and freeing them.
## MUST NOT: open a screen, play music, or decide rewards.


## Fighters brought into a running battle by a power: their pools are forgotten on `release`.
## Foes that arrived as reinforcements (C8.22a).
const REINFORCED: StringName = &"battle_reinforced"
const SUMMONED: StringName = &"battle_summoned"


## A battle between `party` and `encounter`'s enemies, built under `holder` and started.
## `holder` MUST be in the tree: each fighter's sheet, id and pools are wired in its `_ready`,
## and before that its `Vitals` would answer for the default owner.
static func build(encounter: Encounter, party: Array[CombatantDef], holder: Node,
		rng: RandomNumberGenerator = null, helpers: Array[OwnedFighter] = [],
		bench: Array[CombatantDef] = []) -> Battle:
	if not holder.is_inside_tree():
		push_error("BattleSetup.build: the holder must be in the tree")
	var ours: Array[Combatant] = []
	for def: CombatantDef in party:
		ours.append(_fighter(def, def.combatant_id, holder, false))
	var guests: Array[Combatant] = []
	for one: OwnedFighter in helpers:
		guests.append(_guest(one, ours, holder))
	var theirs: Array[Combatant] = _foes(encounter, holder)
	# The encounter file chooses the turn order: plain rounds, or CTB where speed buys extra turns.
	var turns: TurnScheduler = CtbScheduler.new() if encounter.turn_order == Encounter.TurnOrder.CTB \
			else RoundScheduler.new()
	turns.weakness_extra_turns = encounter.weakness_extra_turns
	var battle := Battle.new(ours + guests, theirs, turns, rng)
	battle.encounter = encounter
	battle.can_flee = encounter.can_flee
	battle.flee_chance = encounter.flee_chance
	battle.free_swaps = encounter.free_swaps
	# Remember each fighter's definition (for names and menus) and each enemy's AI brain.
	for i: int in party.size():
		battle.defs[ours[i].combatant_id] = party[i]
	_bench(battle, bench, holder)
	for i: int in guests.size():
		var id: StringName = guests[i].combatant_id
		battle.guests.append(id)
		battle.defs[id] = helpers[i].fighter
		battle.brains[id] = helpers[i].fighter.brain if helpers[i].fighter.brain != null else BattleBrain.new()
	for i: int in encounter.enemies.size():
		battle.defs[theirs[i].combatant_id] = encounter.enemies[i]
		if encounter.enemies[i].brain != null:
			battle.brains[theirs[i].combatant_id] = encounter.enemies[i].brain
	battle.start()
	return battle


## Frees every fighter node the battle held and erases the enemies' pool flags. A party member
## left at zero stands back up at 1 hp, so a lost or a costly fight never leaves the next one
## starting already lost. A lost battle whose encounter names a `defeat_rule` (C10.2) stands them
## up with its `revive_fraction` instead, and `FieldDefeat.after_battle` carries the rule out.
static func release(battle: Battle) -> void:
	for fighter: Combatant in battle.enemies + battle.party:
		if battle.enemies.has(fighter) or fighter.is_in_group(SUMMONED):
			_forget_pools(fighter)
	var lost: bool = battle.outcome() == Battle.Outcome.LOST and battle.encounter != null
	var rule: DefeatRule = battle.encounter.defeat_rule if lost else null
	for fighter: Combatant in battle.party + battle.reserve:
		var vitals: Vitals = Vitals.of(fighter.get_parent())
		if not battle.guests.has(fighter.combatant_id):
			vitals.revive(1 if rule == null else roundi(vitals.maximum(vitals.defeat_pool) * rule.revive_fraction))
	if rule != null:
		FieldDefeat.after_battle(rule, Director.player)
	for fighter: Combatant in battle.party + battle.enemies + battle.reserve:
		var actor: Node = fighter.get_parent()
		if is_instance_valid(actor):
			actor.queue_free()


## A fighter made from `def` joins `battle` on `user`'s side as `id`, played by `brain` (a plain
## attack when null), and takes turns from the next ordering. Untouchable: no foe picks it.
static func summon(battle: Battle, def: CombatantDef, brain: BattleBrain, id: StringName,
		user: Combatant, untouchable: bool) -> Combatant:
	var holder: Node = user.get_parent().get_parent()
	var called: Combatant = _fighter(def, id, holder, true, false)
	called.faction = user.faction
	called.add_to_group(SUMMONED)
	if untouchable:
		called.add_to_group(Unseen.INERT)
	if battle.party.has(user):
		battle.party.append(called)
		battle.guests.append(id)
	else:
		battle.enemies.append(called)
	battle.defs[id] = def
	battle.brains[id] = brain if brain != null else BattleBrain.new()
	battle.admit(called)
	return called


## Takes a called fighter out of `battle` and frees it, leaving no pool flags behind.
static func dismiss(battle: Battle, fighter: Combatant) -> void:
	if battle != null:
		battle.scheduler.leave(fighter.combatant_id)
		battle.party.erase(fighter)
		battle.enemies.erase(fighter)
		battle.guests.erase(fighter.combatant_id)
	_forget_pools(fighter)
	var actor: Node = fighter.get_parent()
	if is_instance_valid(actor):
		actor.queue_free()


# A field helper's battle copy: its field id and pools, the party's side, gear not kept.
static func _guest(one: OwnedFighter, ours: Array[Combatant], holder: Node) -> Combatant:
	var field: Combatant = Combatant.of(one)
	var guest: Combatant = _fighter(one.fighter, field.combatant_id, holder, false, false)
	guest.faction = ours[0].faction if not ours.is_empty() else field.faction
	if one.untouchable:
		guest.add_to_group(Unseen.INERT)
	return guest


# One fighter = a plain Node with three children: Vitals (HP/MP), StatusSet, Combatant, and a
# fourth, a PowerSet, when it has hero powers, and a GearSet for what it wears.
static func _fighter(def: CombatantDef, id: StringName, holder: Node, fresh: bool,
		keep_gear: bool = true) -> Combatant:
	var actor := Node.new()
	actor.name = String(id)
	actor.add_child(Vitals.new())
	var statuses := StatusSet.new()
	statuses.save_id = StringName("statuses/" + String(id))
	actor.add_child(statuses)
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = def.faction
	combatant.base_stats = def.base_stats
	combatant.weak_to = def.weak_to
	combatant.attack_tags = def.attack_tags
	combatant.traits = def.traits
	combatant.steal_table = def.steal_table
	combatant.capture_item = def.capture_item
	combatant.back_row = def.back_row
	# Copies of one definition share a kind, so a weakness revealed on one shows on all.
	combatant.kind = def.combatant_id
	actor.add_child(combatant)
	holder.add_child(actor)
	# The kit goes on after the actor is in the tree, when the Combatant's sheet is wired up, so
	# the kit's stat bonuses land on it.
	if def.power_kit != null:
		var powers := PowerSet.new()
		actor.add_child(powers)
		powers.equip(def.power_kit)
	PassiveLending.own(actor, def)
	# Gear after the Combatant too: a party member's is saved, an enemy's is not.
	GearSet.fit(actor, def, keep_gear and not fresh)
	# Enemies always start at full HP, even if an old flag says otherwise.
	if fresh:
		_forget_pools(combatant)
	return combatant


static func _forget_pools(fighter: Combatant) -> void:
	var vitals: Vitals = Vitals.of(fighter.get_parent())
	for stat: StringName in fighter.base_stats:
		if String(stat).begins_with(Vitals.MAX_PREFIX):
			Flags.erase_flag(vitals.key(StringName(String(stat).trim_prefix(Vitals.MAX_PREFIX))))


## The DEFEND status a battle uses unless a game sets its own: one turn of +100 defence.
static func default_defend() -> StatusEffect:
	var guard := StatusEffect.new()
	guard.id = &"status/defend"
	guard.name_key = "ui.battle.status.defend"
	guard.duration = 1.0
	guard.modifiers = [StatModifier.of(&"defence", StatModifier.Op.ADD, 100.0, &"")]
	return guard


# The reserve line (C8.3): built like the party, kept off the field until a SWAP.
static func _bench(battle: Battle, bench: Array[CombatantDef], holder: Node) -> void:
	for def: CombatantDef in bench:
		battle.reserve.append(_fighter(def, def.combatant_id, holder, false))
		battle.defs[def.combatant_id] = def


# The encounter's enemies, built fresh. Each type is counted first, so only duplicates get a
# number ("Wisp 1", "Wisp 2").
static func _foes(encounter: Encounter, holder: Node) -> Array[Combatant]:
	var theirs: Array[Combatant] = []
	var seen: Dictionary[StringName, int] = {}
	for def: CombatantDef in encounter.enemies:
		seen[def.combatant_id] = seen.get(def.combatant_id, 0) + 1
	var counted: Dictionary[StringName, int] = {}
	for def: CombatantDef in encounter.enemies:
		var id: StringName = def.combatant_id
		if seen[id] > 1:
			counted[id] = counted.get(id, 0) + 1
			id = StringName("%s_%d" % [id, counted[def.combatant_id]])
		theirs.append(_fighter(def, id, holder, true))
	return theirs


## When every foe of `battle` is down, the encounter's next `wave` of `reinforcements` join it.
## Returns how many arrived.
static func reinforce(battle: Battle) -> int:
	var encounter: Encounter = battle.encounter
	if encounter == null or encounter.reinforcements.is_empty() or battle.enemies.is_empty():
		return 0
	var arrived: int = 0
	for foe: Combatant in battle.enemies:
		if not Vitals.of(foe.get_parent()).is_defeated():
			return 0
		if foe.is_in_group(REINFORCED):
			arrived += 1
	var holder: Node = battle.enemies[0].get_parent().get_parent()
	var ids: Array[StringName] = []
	while ids.size() < maxi(1, encounter.wave) and arrived + ids.size() < encounter.reinforcements.size():
		var def: CombatantDef = encounter.reinforcements[arrived + ids.size()]
		var id: StringName = _numbered(battle, def)
		var foe: Combatant = _fighter(def, id, holder, true)
		foe.add_to_group(REINFORCED)
		battle.enemies.append(foe)
		battle.defs[id] = def
		battle.brains[id] = def.brain if def.brain != null else BattleBrain.new()
		battle.admit(foe)
		ids.append(id)
	if not ids.is_empty():
		Events.reinforcements_arrived.emit(ids)
	return ids.size()


# The next free "<id>_<n>" for another of `def` in `battle`, so a late foe joins the count: the
# third of a kind is "Name 3" on the screen (C8.25).
static func _numbered(battle: Battle, def: CombatantDef) -> StringName:
	var n: int = 1
	for one: Combatant in battle.enemies:
		var known: CombatantDef = battle.defs.get(one.combatant_id, null)
		if known != null and known.combatant_id == def.combatant_id:
			n += 1
	var id := StringName("%s_%d" % [def.combatant_id, n])
	while battle.defs.has(id):
		n += 1
		id = StringName("%s_%d" % [def.combatant_id, n])
	return id
