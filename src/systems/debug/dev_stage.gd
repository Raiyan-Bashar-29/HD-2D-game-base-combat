extends Node
## Staging: put the game into the state a photograph needs, then get out of the way.
##
## THE SEAM, AND WHY THERE ARE NOW SIX DEBUG FILES
## `dev_capture.gd` answers "what does the game LOOK like under condition X" and owns the
## shutter. `dev_probes.gd` answers "does sequence Y actually work" and owns the measurements.
## `dev_gait_shots.gd` and `dev_scenario_shots.gd` answer "WHEN does the shutter open" for a
## moment that has no still frame to aim at. This file answers "put the player THERE, holding
## THAT, with THIS person feeling THAT way" so the others have something worth looking at. The
## first three were one file until the budget checker refused it twice, at 310 and then at 320 of
## the 250 allowed code lines — and both times the seam it exposed was already there in the
## reasoning. That is the tool working.
##
## THE THIRD TIME IT REFUSED THIS FILE, at 248 of 250 with the next change due, the seam it
## exposed was WHAT IS TRUE IN THE WORLD versus WHAT IS DRAWN OVER IT. The five flags that end
## in a `UiRoot.open()` — `--open-inventory`, `--talk`, `--talk-advance`, `--open-menu` and
## `--console` — moved to `dev_screens.gd`, which is also the only debug staging file that names
## the `ui` layer at all. Nothing here pushes a screen, and nothing there poses world state.
##
## EVERY FLAG HERE GOES THROUGH THE REAL PATH. Standing is set through `Flags` on the key
## `Standing` publishes, an interaction is a real `InputEventAction` through
## `Input.parse_input_event`, an item is equipped through `Equipment.equip` and so obeys the
## same refusal a screen would. A staging tool that reached past the game to pose it would
## photograph a mock.
##
## THE FLAGS RUN CONCURRENTLY, and each waits a different number of frames before acting, which
## is what orders them: --stand-by settles first, --cycle after it, --interact last. That is
## fragile if a fourth is added; add it with a longer wait than the one it must follow.
##
## EVERYTHING AFTER THE BARE `--` IS PASSED TO THE GAME:
##
##   --give=<list>        put items in the player's bag: item/rose_key,item/rose_petal:3. After
##                        the area lands, because a new game now empties the bag - gotcha 32.
##                        This also poses a counted quest step, since a count is a flag.
##   --equip=<list>       put items IN HAND, after the area lands: --equip=item/lantern. The
##                        carrier must already hold them, so --give comes first on the line.
##                        Equipment is a flag, and --new-game clears flags — see gotcha 32.
##   --goto=<area>        travel somewhere else once the boot load has settled.
##   --stand-by=<name>    put the player beside a named node and let the sensor settle on it.
##   --flag=<key>:<value> forge a plot flag AFTER the area lands: --flag=met/someone:true,
##                        --flag=count/lit:3. --new-game clears flags, so it cannot be earlier.
##                        A quest step is a flag condition, so this poses quest progress.
##   --standing=<who>:<n> set someone's standing, to photograph an action refused, failing and
##                        succeeding without playing the twenty minutes it takes to earn it.
##   --cycle=<n>          press the cycle key n times, to select past the first of several
##                        overlapping targets. An NPC with two path actions and a conversation
##                        is three overlapping interactables.
##   --interact=<n>       press the interact key n times, so a capture shows the OUTCOME of an
##                        action rather than only its prompt. A refusal, a failure and a
##                        success look identical until the button is pressed.
##   --new-game           start a game. Since WP-12 the boot goes to the main menu, not to an
##                        area, so without this there is no world to photograph.
##   --npc-settle=<n>     let NPCs walk for n physics frames, so a screenshot shows them AT
##                        their posts rather than halfway there.
##
## THE FLAGS THAT PUSH A SCREEN LIVE NEXT DOOR, in `dev_screens.gd`, and this file deliberately
## knows nothing about them: `--open-inventory`, `--talk`, `--talk-advance`, `--open-menu` and
## `--console`. They draw OVER what the flags above pose, which is why `DevScreens` sits after
## `DevStage` in `game_root.tscn`.
##
## OWNS: putting the world into a named state for a capture.
## MUST NOT: be depended upon by gameplay, measure anything, push a screen, or reach past the
## game to pose it. Deleting this file must not break the game.

## How long the world must stay settled before `--stand-by` resolves a node NAME. Gotcha 35's
## rule covers anything that draws, and those flags are in `dev_screens.gd` now — but the rule's
## other half is this one: resolving a name in the tree while a transition is in flight finds it
## in the DEPARTURE area, which is exactly what T4.2 spent a package discovering.
## Generous on purpose: it costs a capture a fraction of a second and it removes a race that
## costs an hour to diagnose.
const SETTLE_FRAMES: int = 20

## Set by --new-game, read by every flag that poses state a fresh game resets: `start_new_game()`
## empties the bag and clears the flags, so anything staged during argument parsing is thrown
## away a frame later. Gotcha 32.
var _fresh_game: bool = false


func _ready() -> void:
	# Staging has to work with a screen open: half of what is worth photographing is a screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# THE DEBUG SURFACE DOES NOT EXIST IN A SHIPPED BUILD. Same guard, same reason, as
	# dev_capture.gd: until T1.2 a release export still answered these flags.
	if not OS.is_debug_build():
		return
	_parse_arguments()


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--give="):
			_give(argument.trim_prefix("--give="))
		elif argument.begins_with("--equip="):
			_equip(argument.trim_prefix("--equip="))
		elif argument.begins_with("--goto="):
			_goto(StringName(argument.trim_prefix("--goto=")))
		elif argument.begins_with("--stand-by="):
			_stand_by(argument.trim_prefix("--stand-by="))
		elif argument.begins_with("--flag="):
			_force_flag(argument.trim_prefix("--flag="))
		elif argument.begins_with("--standing="):
			_force_standing(argument.trim_prefix("--standing="))
		elif argument.begins_with("--cycle="):
			_cycle_target(maxi(1, argument.trim_prefix("--cycle=").to_int()))
		elif argument.begins_with("--interact="):
			_press_interact(maxi(1, argument.trim_prefix("--interact=").to_int()))
		elif argument == "--new-game":
			_fresh_game = true
			_new_game()
		elif argument.begins_with("--npc-settle="):
			_npc_settle(maxi(1, argument.trim_prefix("--npc-settle=").to_int()))


## Wait for a transition to finish and for the freed area to actually leave the tree.
## Duplicated in dev_probes.gd, deliberately: five lines repeated once is a better trade than a
## shared base class binding two independent debug nodes together.
func _settled() -> void:
	while Director.is_transitioning():
		await get_tree().process_frame
	for _i: int in 4:
		await get_tree().process_frame


func _wait_for_area() -> void:
	while Director.current_area_id == &"":
		await get_tree().process_frame
	await _settled()


## Wait until the world has been settled for `frames` CONSECUTIVE frames, and start counting
## again the moment it is not. Gotcha 21's persistence shape, applied to staging.
##
## WHY A COUNTER AND NOT A LONGER WAIT. `--goto` and `--open-menu` both begin by waiting for the
## first area, so they come out of that wait on the same frame and race: if the menu opens first,
## the travel `--goto` is about to request unwinds it, and the capture is of an empty screen with
## every rung green. A fixed number of extra frames only moves the race. This one cannot be won
## early, because a transition starting resets the count.
func _settle_stable(frames: int) -> void:
	var stable: int = 0
	while stable < frames:
		if Director.current_area_id == &"" or Director.is_transitioning():
			stable = 0
		else:
			stable += 1
		await get_tree().process_frame


## Put items in the bag for a capture.
##
## AFTER THE AREA LANDS WHEN --new-game IS ON THE LINE, and this became necessary in T3.3 rather
## than being an oversight before it: `start_new_game()` now EMPTIES THE BAG, on the same
## reasoning that has it clear the flags, so items staged during argument parsing are thrown away
## a frame later. Fourth staging flag to need this wait after --open-menu, --flag and
## --open-inventory, and the fourth time gotcha 32 has been the answer. Any flag that poses state
## a new game resets needs it.
func _give(list: String) -> void:
	await get_tree().process_frame
	if _fresh_game:
		await _wait_for_area()
	Log.info("test", "--%s" % DevCommands.give(list))




## Put items in hand for a capture. AFTER the area lands, for gotcha 32's reason: equipment is a
## flag and `--new-game` clears every flag, so this staged during argument parsing would be gone
## by the time there was anything to photograph — exactly how WP-08's first capture came back
## empty. Goes through `Equipment.equip`, so a capture of an item in hand is a capture of the
## real rule: an item the player is not carrying is refused here as it would be in the screen.
func _equip(list: String) -> void:
	await get_tree().process_frame
	if _fresh_game:
		await _wait_for_area()
		# ONE FRAME BEHIND --give, WHICH NOW WAITS FOR THE AREA TOO. Two flags leaving the same
		# wait resume in creation order, which is command-line order - and gotcha 35 says an
		# ordering that rests on that is a race, not an order. A frame boundary is an order: the
		# bag is filled before anything asks to hold what is in it, whichever way round they were
		# typed. Verified by running both on one line; the log is in DEVLOG.md for T3.3.
		await get_tree().process_frame
	var worn: Equipment = Equipment.of(Director.player)
	if worn == null:
		Log.error("test", "--equip found no Equipment on the player")
		return
	for item_id: String in list.split(",", false):
		var done: bool = worn.equip(StringName(item_id))
		Log.info("test", "--equip %s: %s (flag %s)" % [
			item_id, str(done), worn.key(StringName(item_id)),
		])


## Travel back and forth `count` times and report what it cost. A leak in a transition is
## invisible in a single trip and obvious over twenty, which is why the criterion is twenty
## and why this is a RUN rather than an assertion: TestCase.run() is synchronous and cannot
## await a threaded load.
##
## Node count and static memory are sampled with the area settled and the same area loaded at
## both ends, so the two numbers are directly comparable. Anything that grows per trip shows
## up as a slope rather than noise.
func _goto(area_id: StringName) -> void:
	await _wait_for_area()
	Log.info("test", "--%s" % DevCommands.travel_to(String(area_id)))
	await _settled()
	Log.info("test", "--goto arrived in '%s'" % Director.current_area_id)


## Step the clock through a whole day and report where every NPC actually stands at each hour.
## The criterion is "at the market at noon and home at night"; this is the measurement.
func _npc_settle(frames: int) -> void:
	await _wait_for_area()
	for _i: int in frames:
		await get_tree().physics_frame
	for npc: Node in _all_npcs():
		var brain: NpcBrain = npc as NpcBrain
		Log.info("test", "--npc-settle %s at '%s' (%s), %.2fm away" % [
			npc.name, brain.current_waypoint(), brain.activity_name(),
			_distance_to_intent(brain),
		])


## USES `_settle_stable`, NOT `_wait_for_area` ALONE, AND GOTCHA 35 IS WHY — the rule was already
## written down for `--open-menu` below and this call site was missed. T4.2 found it by authoring
## an area and trying to photograph an object in it: `--goto=orchard --stand-by=BrambleWay` failed
## with "found no node called 'BrambleWay'", because `_wait_for_area` returns on the same frame
## `--goto` asks to travel, so the name was resolved in the DEPARTURE area every time. Measured
## with a control: a courtyard node resolved while travelling to the orchard, and both orchard
## nodes did not. That made every object in an authored area unphotographable, since a new area
## is reached with `--goto`.
## Walk the player up to a named node and let the interaction sensor settle on it. A capture of
## a prompt is worthless if the prompt is for whatever happened to be nearest the spawn point.
func _stand_by(node_name: String) -> void:
	await _wait_for_area()
	await _settle_stable(SETTLE_FRAMES)
	var target: Node3D = get_tree().root.find_child(node_name, true, false) as Node3D
	if target == null:
		Log.error("test", "--stand-by found no node called '%s'" % node_name)
		return
	var player: Node3D = Director.player
	player.global_position = target.global_position + Vector3(0.0, 0.0, 1.1)
	for _i: int in 30:
		await get_tree().physics_frame
	var sensor: InteractionSensor = player.get_node_or_null(
		^"InteractionSensor") as InteractionSensor
	var current: Interactable = sensor.current()
	Log.info("test", "--stand-by beside '%s', sensor has '%s'" % [
		node_name, current.name if current != null else "NOTHING",
	])


## Force a standing before a capture, so the same action can be photographed refused, failing
## and succeeding without playing the twenty minutes it would take to earn it.
## Set a flag from the command line, so a capture can pose narrative state the way --give poses
## the bag. WP-08 needed it: a quest step is a flag condition, and photographing an objective
## completing otherwise means walking the player to a lever and a trigger volume in one run.
##
## `true` and `false` are spelled; anything else is read as an integer, which covers the counter
## flags AT_LEAST and AT_MOST test. Deliberately the raw store and not a system: this is the
## development harness, and a flag is exactly what the harness should be able to forge.
## AFTER THE TRANSITION, and finding that out cost a capture. `--new-game` CLEARS every flag, so
## a flag forged during argument parsing is gone by the time the area lands — the first WP-08
## capture photographed a journal with no quest in it for exactly that reason. Same wait, and the
## same reason, as --open-menu.
func _force_flag(value: String) -> void:
	await get_tree().process_frame
	if _fresh_game:
		await _wait_for_area()
	Log.info("test", "--%s by command line" % DevCommands.set_flag(value))


func _force_standing(value: String) -> void:
	var parts: PackedStringArray = value.split(":")
	if parts.size() != 2:
		Log.warn("test", "--standing expects <who>:<n>, got '%s'" % value)
		return
	var who: StringName = StringName(parts[0])
	Flags.set_flag(Standing.key(who), parts[1].to_int())
	Log.info("test", "--standing %s = %d by command line" % [who, Standing.of(who)])


## Press the cycle key, to select past the first of several overlapping targets. An NPC offering
## two path actions plus a conversation is three overlapping interactables, and this is how a
## capture reaches the second one.
func _cycle_target(times: int) -> void:
	await _wait_for_area()
	for _i: int in 40:
		await get_tree().physics_frame
	for _i: int in times:
		var event := InputEventAction.new()
		event.action = Actions.INTERACT_CYCLE
		event.pressed = true
		Input.parse_input_event(event)
		await get_tree().physics_frame
		await get_tree().physics_frame
	var sensor: InteractionSensor = Director.player.get_node_or_null(
		^"InteractionSensor") as InteractionSensor
	var current: Interactable = sensor.current()
	Log.info("test", "--cycle %d: sensor has '%s'" % [
		times, current.name if current != null else "NOTHING",
	])


## Press the interact key for real, so a capture photographs what the action DID. The three
## outcomes of a path action - refused, committed and failed, committed and succeeded - all
## show the same prompt beforehand, and differ only in the line that follows.
##
## Runs after --stand-by and --cycle have chosen a target, so the ordering of the flags on the
## command line is the ordering of the actions.
func _press_interact(times: int) -> void:
	await _wait_for_area()
	for _i: int in 70:
		await get_tree().physics_frame
	var sensor: InteractionSensor = Director.player.get_node_or_null(
		^"InteractionSensor") as InteractionSensor
	for _i: int in times:
		var target: Interactable = sensor.current()
		Log.info("test", "--interact on '%s'" % (target.name if target != null else "NOTHING"))
		var press := InputEventAction.new()
		press.action = Actions.INTERACT
		press.pressed = true
		Input.parse_input_event(press)
		await get_tree().physics_frame
		var release := InputEventAction.new()
		release.action = Actions.INTERACT
		release.pressed = false
		Input.parse_input_event(release)
		for _f: int in 20:
			await get_tree().physics_frame
	Log.info("test", "--interact done, keeper standing is %d" % Standing.of(&"keeper"))


func _distance_to_intent(brain: NpcBrain) -> float:
	var markers: Node = _waypoints_node()
	if markers == null:
		return -1.0
	var marker: Node3D = markers.get_node_or_null(
		NodePath(String(brain.current_waypoint()))) as Node3D
	if marker == null:
		return -1.0
	return marker.global_position.distance_to(brain.global_position)


func _waypoints_node() -> Node:
	var area: Node = get_tree().root.find_child("Waypoints", true, false)
	return area


func _all_npcs() -> Array[Node]:
	var out: Array[Node] = []
	var actors: Node = get_tree().root.find_child("Actors", true, false)
	if actors == null:
		return out
	for child: Node in actors.get_children():
		if child is NpcBrain:
			out.append(child)
	return out


## Start a game. Since WP-12 the boot sequence goes to the main menu rather than straight into
## an area, which is exactly what makes this a base rather than a demo — but it means a capture
## of the world needs this flag first.
func _new_game() -> void:
	await get_tree().process_frame
	Director.start_new_game()
	Log.info("test", "--new-game requested '%s'" % GameConfig.first_area())
