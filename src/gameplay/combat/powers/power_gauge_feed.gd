class_name PowerGaugeFeed
extends RefCounted
## The gauge side of what a fighter's powers hear (C6.4a, C6.6c): a hit, a dodge, a miss, a kill
## and a pool change move the gauges of the kit the fighter wears.
##
## IN PLAIN WORDS: `PowerSet` hears the battle's events and passes each one here with the set it
## belongs to. This turns it into gauge events for that set, and remembers who fell a moment ago so
## the damage that follows can be called a kill.
##
## OWNS: turning fighter events into gauge events, and the who-just-fell memory.
## MUST NOT: change cooldowns, statuses or running mechanisms.

# The id that fell a moment ago, until the next damage event says who felled it.
var _just_fell: StringName = &""


# A hit landed or taken moves the gauges; a heal (a negative amount) does not.
func damaged(powers: PowerSet, who: StringName, by: StringName, amount: int) -> void:
	var me: StringName = _id(powers)
	var felled: bool = who != &"" and who == _just_fell
	_just_fell = &""
	if amount <= 0 or me == &"":
		return
	if felled and by == me and who != me:
		powers.gauges.happen(powers.get_parent(), GaugeRule.Event.KILL)
	if by == me:
		powers.gauges.happen(powers.get_parent(), GaugeRule.Event.HIT_DEALT)
	if who == me:
		powers.gauges.happen(powers.get_parent(), GaugeRule.Event.HIT_TAKEN)


# Remembers who fell, for the damage event that follows; and an ally falling moves the gauges.
func defeated(powers: PowerSet, who: StringName) -> void:
	_just_fell = who
	var me: Combatant = Combatant.of(powers.get_parent())
	if me == null or who == &"" or who == me.combatant_id:
		return
	var other: Combatant = Combatant.find(powers.get_tree(), who)
	if other != null and me.can_target(other, FactionTable.Target.ALLY):
		powers.gauges.happen(powers.get_parent(), GaugeRule.Event.ALLY_DEFEATED)


func revived(who: StringName) -> void:
	if who == _just_fell:
		_just_fell = &""


func dodged(powers: PowerSet, who: StringName) -> void:
	if who != &"" and who == _id(powers):
		powers.gauges.happen(powers.get_parent(), GaugeRule.Event.DODGE)


func perfect_dodged(powers: PowerSet, who: StringName) -> void:
	if who != &"" and who == _id(powers):
		powers.gauges.happen(powers.get_parent(), GaugeRule.Event.PERFECT_DODGE)


# `by` threw the attack that missed.
func missed(powers: PowerSet, by: StringName) -> void:
	if by != &"" and by == _id(powers):
		powers.gauges.happen(powers.get_parent(), GaugeRule.Event.MISS)


func vitals_changed(powers: PowerSet, who: StringName, pool: StringName) -> void:
	if who != &"" and who == _id(powers) and powers.gauges.has_pool(pool):
		powers.gauges.refresh_levels(powers.get_parent(), pool)


func _id(powers: PowerSet) -> StringName:
	var fighter: Combatant = Combatant.of(powers.get_parent())
	return fighter.combatant_id if fighter != null else &""
