class_name FieldParty
extends RefCounted
## A party in the field (C4.7): who walks behind the player, and switching which member the
## player controls.
##
## IN PLAIN WORDS: the player's body is always the one the camera follows and the keys move.
## What a switch changes is WHO that body is. A member is four nodes, its `Vitals`,
## `StatusSet`, `Combatant` and `AtbMeter`. A switch moves those four from the follower's body to
## the player's, and the leader's four the other way, swaps the two bodies' places, and gives the
## player's fighter the new member's loadout (moves and commands). So hp, statuses, weaknesses and
## the gauge all go with the member, and you take over standing where they stood.
##
## WHO COMES ALONG: the lead loadout's `companions`, minus any `Party` has put in reserve (once
## its line-up has been set; before that, everyone). A fallen member cannot be switched to.
##
## OWNS: choosing and spawning the followers, and the switch.
## MUST NOT: walk a follower (`PartyFollower` does) or read input (`ActionFighter` does).

const FOLLOWER_SCENE: String = "res://scenes/objects/party_follower.tscn"


## The companions of `lead` who are in the active line-up, in the loadout's order.
static func members(lead: ActionLoadout) -> Array[ActionLoadout]:
	var out: Array[ActionLoadout] = []
	if lead == null:
		return out
	var mates: Array[ActionLoadout] = []
	var roster: Array[CombatantDef] = []
	for entry: Resource in lead.companions:
		var mate: ActionLoadout = entry as ActionLoadout
		if mate != null and mate != lead and mate.fighter != null:
			mates.append(mate)
			roster.append(mate.fighter)
	var active: Array[CombatantDef] = Party.active(roster)
	for mate: ActionLoadout in mates:
		if active.has(mate.fighter):
			out.append(mate)
	return out


## Adds a follower on `player`'s spot for each of `members(lead)`, each walking to its place in
## the line behind. They are
## children of the player's parent, so they go when the area does.
static func spawn(player: Node3D, lead: ActionLoadout) -> Array[PartyFollower]:
	var out: Array[PartyFollower] = []
	var scene: PackedScene = load(FOLLOWER_SCENE) as PackedScene
	if player == null or player.get_parent() == null or scene == null:
		return out
	for member: ActionLoadout in members(lead):
		var follower: PartyFollower = scene.instantiate() as PartyFollower
		follower.loadout = member
		follower.leader = player
		follower.slot = out.size() + 1
		follower.name = "Follower_%s" % member.fighter.combatant_id
		player.get_parent().add_child(follower)
		# On the leader's own spot, the one place sure to have ground under it. It blocks no one,
		# so it simply walks out to its place in the line.
		follower.global_position = player.global_position
		out.append(follower)
	return out


## The followers walking after `player`, in line order.
static func followers(player: Node3D) -> Array[PartyFollower]:
	var out: Array[PartyFollower] = []
	if player == null or not player.is_inside_tree():
		return out
	for node: Node in player.get_tree().get_nodes_in_group(PartyFollower.GROUP):
		var follower: PartyFollower = node as PartyFollower
		if follower != null and follower.leader == player:
			out.append(follower)
	out.sort_custom(func(a: PartyFollower, b: PartyFollower) -> bool: return a.slot < b.slot)
	return out


## The loadout of whoever the player controls now: the fighter's, which a switch changes.
static func lead(player: Node) -> ActionLoadout:
	var fighter: ActionFighter = _fighter(player)
	return fighter.loadout if fighter != null else null


## Hands the player's body to the first standing follower in line. The one handed over goes to
## the back of the line, so pressing again walks through the whole party. False when no one can
## take over, or the player is not a party leader.
static func switch(player: Node3D) -> bool:
	var fighter: ActionFighter = _fighter(player)
	if fighter == null or fighter.loadout == null:
		return false
	var line: Array[PartyFollower] = followers(player)
	for follower: PartyFollower in line:
		var vitals: Vitals = Vitals.of(follower)
		if follower.loadout != null and vitals != null and not vitals.is_defeated():
			_swap(player, follower, fighter)
			line.erase(follower)
			line.append(follower)
			for i: int in line.size():
				line[i].slot = i + 1
			return true
	return false


static func _swap(player: Node3D, follower: PartyFollower, fighter: ActionFighter) -> void:
	var mine: Array[Node] = _identity(player)
	var theirs: Array[Node] = _identity(follower)
	for part: Node in mine:
		part.reparent(follower, false)
	for part: Node in theirs:
		part.reparent(player, false)
	var here: Vector3 = player.global_position
	player.global_position = follower.global_position
	follower.global_position = here
	var leading: ActionLoadout = fighter.loadout
	fighter.loadout = follower.loadout
	fighter.moves = follower.loadout.moves
	follower.loadout = leading
	# A swing or a lock belonged to the member who left, so both end here.
	fighter.timeline.cancel()
	var me: Combatant = Combatant.of(player)
	for child: Node in player.get_children():
		if child is Hitbox:
			(child as Hitbox).attacker = me
		elif child is LockOn:
			(child as LockOn).target = null
	# The lock change also tells the HUD to redraw, now for the new member.
	Events.lock_on_changed.emit(me.combatant_id if me != null else &"", &"")
	Log.info("combat", "Party switch: now controlling %s" % (me.combatant_id if me != null else &""))


## The nodes that are a member, and move with them on a switch.
static func _identity(body: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child: Node in body.get_children():
		if child is Vitals or child is StatusSet or child is Combatant or child is AtbMeter:
			out.append(child)
	return out


static func _fighter(player: Node) -> ActionFighter:
	if player == null:
		return null
	for child: Node in player.get_children():
		if child is ActionFighter:
			return child as ActionFighter
	return null
