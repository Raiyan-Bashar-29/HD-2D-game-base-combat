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
## IN PLAIN WORDS: the factory. Give it an encounter file and the party, and it makes one
## fighter node per combatant, picks the turn order the encounter asked for, and starts the
## `Battle`. `release` cleans everything up afterwards.
##
## OWNS: turning definitions into fighters, and freeing them.
## MUST NOT: open a screen, play music, or decide rewards.


## A battle between `party` and `encounter`'s enemies, built under `holder` and started.
## `holder` MUST be in the tree: each fighter's sheet, id and pools are wired in its `_ready`,
## and before that its `Vitals` would answer for the default owner.
static func build(encounter: Encounter, party: Array[CombatantDef], holder: Node,
		rng: RandomNumberGenerator = null) -> Battle:
	if not holder.is_inside_tree():
		push_error("BattleSetup.build: the holder must be in the tree")
	var ours: Array[Combatant] = []
	for def: CombatantDef in party:
		ours.append(_fighter(def, def.combatant_id, holder, false))
	var theirs: Array[Combatant] = []
	# Count each enemy type first, so only duplicates get a number ("Wisp 1", "Wisp 2").
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
	# The encounter file chooses the turn order: plain rounds, or CTB where speed buys extra turns.
	var turns: TurnScheduler = CtbScheduler.new() if encounter.turn_order == Encounter.TurnOrder.CTB \
			else RoundScheduler.new()
	var battle := Battle.new(ours, theirs, turns, rng)
	battle.encounter = encounter
	battle.can_flee = encounter.can_flee
	battle.flee_chance = encounter.flee_chance
	# Remember each fighter's definition (for names and menus) and each enemy's AI brain.
	for i: int in party.size():
		battle.defs[ours[i].combatant_id] = party[i]
	for i: int in encounter.enemies.size():
		battle.defs[theirs[i].combatant_id] = encounter.enemies[i]
		if encounter.enemies[i].brain != null:
			battle.brains[theirs[i].combatant_id] = encounter.enemies[i].brain
	battle.start()
	return battle


## Frees every fighter node the battle held and erases the enemies' pool flags. A party member
## left at zero stands back up at 1 hp: the template default until C5's defeat flow, so a lost
## or a costly fight never leaves the next one starting already lost.
static func release(battle: Battle) -> void:
	for fighter: Combatant in battle.enemies:
		_forget_pools(fighter)
	for fighter: Combatant in battle.party:
		Vitals.of(fighter.get_parent()).revive(1)
	for fighter: Combatant in battle.party + battle.enemies:
		var actor: Node = fighter.get_parent()
		if is_instance_valid(actor):
			actor.queue_free()


# One fighter = a plain Node with three children: Vitals (HP/MP), StatusSet, Combatant.
static func _fighter(def: CombatantDef, id: StringName, holder: Node, fresh: bool) -> Combatant:
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
	# Copies of one definition share a kind, so a weakness revealed on one shows on all.
	combatant.kind = def.combatant_id
	actor.add_child(combatant)
	holder.add_child(actor)
	# Enemies always start at full HP, even if an old flag says otherwise.
	if fresh:
		_forget_pools(combatant)
	return combatant


static func _forget_pools(fighter: Combatant) -> void:
	var vitals: Vitals = Vitals.of(fighter.get_parent())
	for stat: StringName in fighter.base_stats:
		if String(stat).begins_with(Vitals.MAX_PREFIX):
			Flags.erase_flag(vitals.key(StringName(String(stat).trim_prefix(Vitals.MAX_PREFIX))))
