class_name DevKit
extends RefCounted
## The `power_kit` development verb (C6.23, combat fork only): put a hero-power kit on the player
## for this visit, from the debug console (`power_kit <name>`) or the command line
## (`--power-kit=<name>`, `dev_stage.gd`).
##
## IN PLAIN WORDS: `power_kit wanderer` finds `kit/wanderer` (the full id works too) in
## `PowerKitDb` and equips it on the player's `PowerSet`, adding one when the player has none.
## `power_kit none` takes the player's own kit off; kits lent by worn gear stay. `power_kit` alone
## lists every kit. The loadout's own kit comes back when the player's body is next built, so
## nothing is saved. Like the rest of `DevCommands`, the report is plain English: developer
## output, not player text.
##
## OWNS: the verb's body and its one-line report.
## MUST NOT: save anything, or be depended upon by gameplay. Deleting it breaks only the console
## and the harness.

const VERB: StringName = &"power_kit"
const NONE: String = "none"


## Runs `power_kit <argument>` on the player. Refuses, never crashes, with no fighter in the tree.
static func power_kit(argument: String) -> String:
	var player: Node = Director.player
	var wanted: String = argument.strip_edges()
	if wanted == "":
		var names: PackedStringArray = []
		for kit_id: StringName in PowerKitDb.ids():
			names.append(String(kit_id))
		return "power_kit kits: %s" % ", ".join(names)
	if player == null or Combatant.of(player) == null:
		return "power_kit found no fighter in the player"
	var powers: PowerSet = PowerSet.of(player)
	if wanted == NONE:
		if powers != null:
			powers.equip(null)
		return "power_kit took the player's own kit off"
	var kit_id := StringName(wanted if wanted.begins_with(PowerKitDb.ID_PREFIX) else PowerKitDb.ID_PREFIX + wanted)
	var kit: PowerKit = PowerKitDb.kit(kit_id)
	if kit == null:
		return "power_kit has no kit '%s'" % kit_id
	if powers == null:
		powers = PowerSet.new()
		player.add_child(powers)
	powers.equip(kit)
	return "power_kit put %s on the player" % kit_id
