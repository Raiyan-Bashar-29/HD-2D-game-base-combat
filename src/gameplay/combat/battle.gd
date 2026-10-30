class_name Battle
extends RefCounted
## One turn-based fight: two sides of `Combatant`s, a `TurnScheduler`, and the rules for what a
## command does. The battle screen (C2.7), a `BattleBrain` (C2.5) and a test all drive it the
## same way: `next_turn()`, then `act(command, targets)`, until `outcome()` is not ONGOING.
##
## IT NEVER RUNS ON `_process`. It moves only when called, so the modal pause that freezes the
## field cannot freeze it, and a test plays a whole battle with no frames (C2.0).
##
## IT HOLDS COMBATANTS, IT DOES NOT OWN THEM. Whoever builds the sides (C2.6) adds the nodes to
## the tree and frees them. Each combatant's `Vitals` and `StatusSet` are its parent's children,
## C1.6's rule, and everything said here goes through them.
##
## THE RULES, each a template default:
## - ATTACK is a power-0 hit through the actor's formula, so the attack stat alone decides it.
##   It can miss against evasion, and a target holding a COUNTER status strikes back (C2.15).
## - SKILL and ITEM spend the cost (and, for ITEM, one item from `inventory`), then do what
##   `SkillUse.apply` says: power, effects, hits and statuses (C2.13). A reviving skill aims only
##   at the fallen, and anyone revived rejoins the turn order.
## - DEFEND applies `defend_status`, by default one turn of +100 defence: half damage against
##   the standard softness of 100.
## - FLEE succeeds at `flee_chance` when `can_flee`; a failed flee still spends the turn.
## - Each actor's TURNS statuses tick at the start of its own turn, so DEFEND lasts until then.
## - A status that blocks turns (sleep, stun) makes its holder lose the turn after that tick, and
##   one that blocks SKILL, ITEM or FLEE refuses that command (C2.14). ATTACK and DEFEND are
##   never blocked, so `allows` always leaves something to do.
## - As a fighter's turn begins, after its statuses tick, each `regen_<pool>` stat refills or
##   drains that pool (`Meters`, C2.16).
## - BOOST: `act` may spend up to `boost_max` points of `boost_pool` on an ATTACK (more swings)
##   or a SKILL (its `boost_power` and `boost_hits`). Points are spent only if the action happens.
## - A defeated combatant leaves the scheduler. No enemy standing is WON, no party member LOST.
##
## IN PLAIN WORDS: this is the referee of a turn-based fight. Hand it two lists of fighters,
## then loop: ask `next_turn()` who moves, tell `act()` what they do, and stop when `outcome()`
## says someone won, lost or ran. It never draws or waits; `BattleScreen` does the showing.
##
## OWNS: whose turn it is, whether a command is legal, and the outcome.
## MUST NOT: draw anything, read input, wait for time, or decide what winning gives (C2.8).

enum Outcome { ONGOING, WON, LOST, FLED }

var party: Array[Combatant] = []
var enemies: Array[Combatant] = []
var scheduler: TurnScheduler
var rng: RandomNumberGenerator
## Where ITEM commands spend from. Null refuses every ITEM.
var inventory: Inventory
var can_flee: bool = true
var flee_chance: float = 1.0
var defend_status: StatusEffect = _default_defend()
## BOOST (C2.16): the pool Boost levels are spent from, the most levels one action may spend,
## and how many extra hits each level gives a plain ATTACK. A skill's own `boost_power` and
## `boost_hits` say what boosting it does. A fighter with no `max_bp` simply cannot boost.
var boost_pool: StringName = &"bp"
var boost_max: int = 3
var attack_boost_hits: int = 1
## The brain of each fighter nobody controls, by combatant id. `BattleSetup` fills it from the
## definitions; the screen asks `brain_of` to know whose turn it plays itself.
var brains: Dictionary[StringName, BattleBrain] = {}
## Each fighter's definition, by combatant id, for its name and command menu. `BattleSetup`
## fills it; a fighter built by hand has none, and the screen falls back to its id.
var defs: Dictionary[StringName, CombatantDef] = {}
## The encounter this battle was built from, for its rewards. Null for one built by hand.
var encounter: Encounter

var _by_id: Dictionary[StringName, Combatant] = {}
var _current: Combatant
var _outcome: Outcome = Outcome.ONGOING


func _init(our_side: Array[Combatant], their_side: Array[Combatant], turns: TurnScheduler = null,
		seeded: RandomNumberGenerator = null) -> void:
	party = our_side
	enemies = their_side
	scheduler = turns.duplicate() as TurnScheduler if turns != null else RoundScheduler.new()
	rng = seeded if seeded != null else RandomNumberGenerator.new()


## Joins everyone standing to the scheduler and announces the battle.
func start() -> void:
	var enemy_ids: Array[StringName] = []
	for fighter: Combatant in party + enemies:
		# Remember every fighter by id, so the scheduler's ids can be turned back into nodes.
		_by_id[fighter.combatant_id] = fighter
		# Only fighters still standing get a place in the turn order.
		if not _vitals(fighter).is_defeated():
			scheduler.join(fighter.combatant_id, fighter.sheet.value(&"speed"))
	for fighter: Combatant in enemies:
		enemy_ids.append(fighter.combatant_id)
	Events.battle_started.emit(enemy_ids)
	# A side that starts with nobody standing ends the fight at once.
	_check_outcome()


## Begins the next turn and returns whose it is: null once the battle is over. The actor's
## statuses tick first, and one that falls to a tick is skipped.
func next_turn() -> Combatant:
	_current = null
	# A cap on lost turns in a row, so a whole field asleep can never loop forever.
	var skips_left: int = 64 * maxi(1, party.size() + enemies.size())
	# Loop because a fighter may fall to poison at the start of their turn; then try the next one.
	while _outcome == Outcome.ONGOING:
		var id: StringName = scheduler.next()
		if id == &"":
			return null
		var actor: Combatant = _by_id[id]
		# Turn-counted statuses (poison, DEFEND) tick when their holder's own turn begins.
		var statuses: StatusSet = StatusSet.of(actor.get_parent())
		# Asleep or stunned is decided BEFORE the tick, so a sleep lasting N turns costs exactly
		# N turns: the tick on the last lost turn is the one that wears it off.
		var sleeper: StringName = statuses.blocker(StatusEffect.Block.SKIP_TURN) if statuses != null else &""
		if statuses != null:
			statuses.tick_turn()
		# Each `regen_<pool>` stat refills (or drains) its pool once a turn, asleep or not
		# (C2.16). It runs before the defeat check, so a drain that empties hp counts too.
		Meters.regen_turn(actor)
		if _vitals(actor).is_defeated():
			# The tick or the drain knocked them out: take them out of the queue and look for
			# the next actor.
			_settle()
			continue
		if sleeper != &"":
			Events.turn_skipped.emit(actor.combatant_id, sleeper)
			skips_left -= 1
			if skips_left <= 0:
				return null
			continue
		_current = actor
		return actor
	return null


func current() -> Combatant:
	return _current


## The brain that plays `fighter`, or null for one the player controls.
func brain_of(fighter: Combatant) -> BattleBrain:
	if fighter == null or not brains.has(fighter.combatant_id):
		return null
	return brains[fighter.combatant_id]


func outcome() -> Outcome:
	return _outcome


## Who `command` may be aimed at by the current actor. An ALL skill takes every one of them.
func targets_for(command: BattleCommand) -> Array[Combatant]:
	var out: Array[Combatant] = []
	if _current == null or command == null:
		return out
	# A plain ATTACK always aims at enemies; a skill or item says who it may aim at.
	var filter: FactionTable.Target = FactionTable.Target.ENEMY
	match command.kind:
		BattleCommand.Kind.SKILL, BattleCommand.Kind.ITEM:
			filter = command.skill.target
		# DEFEND and FLEE aim at nobody.
		BattleCommand.Kind.DEFEND, BattleCommand.Kind.FLEE:
			return out
	# A reviving skill aims only at the fallen; everything else only at those still standing.
	var reviving: bool = command.skill != null and command.skill.revives() \
			and command.kind != BattleCommand.Kind.ATTACK
	for fighter: Combatant in party + enemies:
		if _vitals(fighter).is_defeated() == reviving and _current.can_target(fighter, filter):
			out.append(fighter)
	return out


## True when no status on the current actor forbids `command`'s kind: silence stops SKILL,
## and so on. The screen greys out what this refuses, and the AI never picks it.
func allows(command: BattleCommand) -> bool:
	if _current == null or command == null:
		return false
	var statuses: StatusSet = StatusSet.of(_current.get_parent())
	if statuses == null:
		return true
	match command.kind:
		BattleCommand.Kind.SKILL:
			return statuses.blocker(StatusEffect.Block.NO_SKILLS) == &""
		BattleCommand.Kind.ITEM:
			return statuses.blocker(StatusEffect.Block.NO_ITEMS) == &""
		BattleCommand.Kind.FLEE:
			return statuses.blocker(StatusEffect.Block.NO_FLEE) == &""
	return true


## The current actor does `command` to `targets`, spending `boost` Boost levels on it. False,
## changing nothing, when it is illegal: no turn, a bad target, a cost it cannot pay, a flee it
## may not make, a status forbids it, or a boost it may not spend.
func act(command: BattleCommand, targets: Array[Combatant], boost: int = 0) -> bool:
	if _current == null or command == null or not command.problems("act").is_empty():
		return false
	if not allows(command) or not can_boost(command, boost):
		return false
	var actor: Combatant = _current
	match command.kind:
		# A basic hit with no extra power: the attacker's attack stat against the target's defence.
		# Each Boost level adds `attack_boost_hits` more swings.
		BattleCommand.Kind.ATTACK:
			if not _legal(command, targets, true):
				return false
			var landed: DamageResult = null
			for i: int in 1 + attack_boost_hits * boost:
				var swing: DamageResult = actor.hit(targets[0], 0.0, &"", rng)
				if swing != null and not swing.missed:
					landed = swing
			# Only a plain attack is countered, once however many swings landed; a skill is
			# answered by REFLECT instead (C2.15).
			SkillUse.counter(actor, targets[0], landed, rng)
		BattleCommand.Kind.SKILL, BattleCommand.Kind.ITEM:
			if not _use(actor, command, targets, boost):
				return false
		# Guard: a one-turn defence bonus that wears off when this fighter's next turn starts.
		BattleCommand.Kind.DEFEND:
			StatusSet.of(actor.get_parent()).apply(defend_status)
		# Running away. A failed roll still uses up the turn, which is the classic rule.
		BattleCommand.Kind.FLEE:
			if not can_flee:
				return false
			if rng.randf() < flee_chance:
				_end(Outcome.FLED)
	# The action happened, so the Boost points it was promised are spent now.
	if boost > 0:
		_vitals(actor).change(boost_pool, -boost)
	# The turn is spent: clear it, then remove the fallen and check for a winner.
	_current = null
	_settle()
	return true


## True when the current actor may spend `boost` levels on `command`: zero always may; more
## needs an ATTACK or SKILL, no more than `boost_max`, and that many points in `boost_pool`.
func can_boost(command: BattleCommand, boost: int) -> bool:
	if boost == 0:
		return true
	if _current == null or command == null or boost < 0 or boost > boost_max:
		return false
	if command.kind != BattleCommand.Kind.ATTACK and command.kind != BattleCommand.Kind.SKILL:
		return false
	return _vitals(_current).current(boost_pool) >= boost


func _use(actor: Combatant, command: BattleCommand, targets: Array[Combatant], boost: int) -> bool:
	var skill: Skill = command.skill
	var single: bool = skill.scope == Skill.Scope.ONE
	if not _legal(command, targets, single):
		return false
	# Check everything that can refuse BEFORE paying, so a refused command costs nothing.
	if not SkillUse.affordable(actor, skill):
		return false
	if command.kind == BattleCommand.Kind.ITEM:
		# An item command also needs the item in the bag, and uses one up.
		if inventory == null or not inventory.remove(command.item_id, 1):
			return false
	SkillUse.pay(actor, skill)
	# One-target skills hit the chosen target; ALL skills hit everyone they are allowed to.
	# What the skill then does is `SkillUse`'s, shared with the field and the hybrid (C2.13).
	SkillUse.apply(actor, skill, targets if single else targets_for(command), rng, boost)
	# Heavy skills push the user back in a CTB queue; in round-based battles this does nothing.
	if skill.delay > 0.0 and scheduler is CtbScheduler:
		(scheduler as CtbScheduler).delay_by(actor.combatant_id, skill.delay)
	return true


## A ONE command needs exactly one allowed target; an ALL command ignores what it is given.
func _legal(command: BattleCommand, targets: Array[Combatant], single: bool) -> bool:
	if not single:
		return true
	return targets.size() == 1 and targets_for(command).has(targets[0])


## Removes the fallen from the queue, puts anyone revived back in it, and decides whether the
## battle is over.
func _settle() -> void:
	for fighter: Combatant in party + enemies:
		var down: bool = _vitals(fighter).is_defeated()
		if down and scheduler.has(fighter.combatant_id):
			scheduler.leave(fighter.combatant_id)
		elif not down and not scheduler.has(fighter.combatant_id):
			# Revived this turn (C2.13): they take turns again from the next ordering.
			scheduler.join(fighter.combatant_id, fighter.sheet.value(&"speed"))
	_check_outcome()


func _check_outcome() -> void:
	if _outcome != Outcome.ONGOING:
		return
	if _all_down(enemies):
		_end(Outcome.WON)
	elif _all_down(party):
		_end(Outcome.LOST)


func _all_down(side: Array[Combatant]) -> bool:
	for fighter: Combatant in side:
		if not _vitals(fighter).is_defeated():
			return false
	return true


func _end(how: Outcome) -> void:
	if _outcome != Outcome.ONGOING:
		return
	_outcome = how
	_current = null
	Events.battle_ended.emit(how)


func _vitals(fighter: Combatant) -> Vitals:
	return Vitals.of(fighter.get_parent())


static func _default_defend() -> StatusEffect:
	var guard := StatusEffect.new()
	guard.id = &"status/defend"
	guard.duration = 1.0
	guard.modifiers = [StatModifier.of(&"defence", StatModifier.Op.ADD, 100.0, &"")]
	return guard
