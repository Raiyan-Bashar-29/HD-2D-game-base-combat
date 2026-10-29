extends TestCase
## Attributes and surfaces: what a character is LIKE, what they are standing on, and the one
## consumer that turns the first into something the player can feel.
##
## WHAT IS DELIBERATELY NOT HERE, and it is most of a footstep. A step needs a physics frame and
## makes a sound, and `TestCase.run()` is synchronous while `--headless` runs the Dummy audio
## driver — so the raycast, the frame loop and the `play()` are proved by a windowed probe with
## the log quoted in `DEVLOG.md`, exactly the split `SurfaceWetness` made for drying. What IS
## here is the three pure parts underneath: how often a step falls (`travel`), what is underfoot
## (`GroundSurface.of_node`) and what that sounds like (`brightness_for`). If those three are
## right, the untested remainder is a raycast and a `play()` call.
##
## FIXTURES, NOT THE DEMO. Both surfaces below are abstract names built here on bare nodes;
## nothing in this file names a courtyard, a floor or a material, and `check_boundary` scans it.
##
## OWNS: assertions about the attribute container, its one consumer, surface resolution and the
## stride accumulator.
## MUST NOT: re-assert flag save arithmetic (core_test) or how fast the body actually moves
## across a floor, which no assertion can see.

const SLOT: int = 5
## Abstract on purpose. `FixtureContent`'s rule: if a name in a test describes a place, that is
## the demo growing back.
const SOFT: StringName = &"fixture_soft"
const HARD: StringName = &"fixture_hard"
const WHO: StringName = &"fixture_walker"
const OTHER: StringName = &"fixture_other"

var _body: PlayerController = null


func run() -> void:
	plan(56)
	# This case writes or deletes slots; redirected so they are not the developer's own. The
	# runner deactivates after every case.
	SaveFixture.activate()
	Flags.clear_all()
	SaveSystem.unregister(&"world")
	_an_attribute_defaults_and_clamps()
	_it_is_saved_because_it_is_a_flag()
	_the_one_consumer()
	_a_surface_is_read_off_the_geometry()
	_a_step_sounds_like_its_surface()
	_the_stride_accumulator()
	_tear_down()


## The container's whole surface: a key shape, a baseline nothing has to store, and a clamp.
func _an_attribute_defaults_and_clamps() -> void:
	equal("the key is namespaced per character",
		Attributes.key(WHO, &"pace"), &"attr/fixture_walker/pace")
	equal("an untouched attribute is the baseline", Attributes.of(WHO, &"pace"), Attributes.BASELINE)
	equal("and stores nothing to say so", Flags.has_flag(Attributes.key(WHO, &"pace")), false)
	equal("its multiplier is exactly one", is_equal_approx(Attributes.multiplier(WHO, &"pace"), 1.0), true)

	equal("changing it returns the new value", Attributes.change(WHO, &"pace", 2), 2)
	equal("and it reads back", Attributes.of(WHO, &"pace"), 2)
	equal("two steps is two steps of scale",
		is_equal_approx(Attributes.multiplier(WHO, &"pace"), 1.0 + 2.0 * Attributes.STEP), true)

	equal("the ceiling clamps a delta", Attributes.change(WHO, &"pace", 99), Attributes.MAXIMUM)
	equal("the floor clamps one too", Attributes.change(WHO, &"pace", -99), Attributes.MINIMUM)
	equal("and setting outright is clamped on the way in",
		Attributes.set_to(WHO, &"pace", 500), Attributes.MAXIMUM)

	equal("a second character has their own", Attributes.of(OTHER, &"pace"), Attributes.BASELINE)
	equal("adding an attribute needs no declaration", Attributes.set_to(WHO, &"fixture_new", 1), 1)
	equal("and it reads back like any other", Attributes.of(WHO, &"fixture_new"), 1)
	equal("one character's attributes are one prefix", Attributes.all_of(WHO).size(), 2)
	equal("and the other's are untouched", Attributes.all_of(OTHER).size(), 0)


## The argument for a namespace over `Flags` instead of a store: there is nothing to register,
## nothing to migrate, and a new game clears it for free. Asserted rather than assumed, because
## that claim is the whole reason there is no save section.
func _it_is_saved_because_it_is_a_flag() -> void:
	Attributes.set_to(WHO, &"pace", 3)
	equal("save", SaveSystem.save_to_slot(SLOT), OK)
	Attributes.set_to(WHO, &"pace", -1)
	equal("load", SaveSystem.load_from_slot(SLOT), OK)
	equal("the attribute came back", Attributes.of(WHO, &"pace"), 3)
	Flags.clear_all()
	equal("and a new game's clear takes it away", Attributes.of(WHO, &"pace"), Attributes.BASELINE)


## The point of the package: an attribute that changes something. This is the whole consumer,
## and it is asserted here because a declared-and-unread system is what WP-09b existed to avoid.
func _the_one_consumer() -> void:
	_body = build("res://scenes/characters/player.tscn") as PlayerController
	_body.character_id = WHO
	attach(_body)
	var base: float = _body.walk_speed

	equal("with no attribute the body walks at its authored speed",
		is_equal_approx(_body.current_speed(), base), true)
	Attributes.set_to(WHO, PlayerController.PACE, Attributes.MAXIMUM)
	equal("a raised pace is measurably faster", _body.current_speed() > base, true)
	equal("by exactly the multiplier",
		is_equal_approx(_body.current_speed(), base * Attributes.multiplier(WHO, PlayerController.PACE)),
		true)
	Attributes.set_to(WHO, PlayerController.PACE, Attributes.MINIMUM)
	equal("and a lowered one is slower", _body.current_speed() < base, true)
	equal("the attribute belongs to the character, not the class",
		is_equal_approx(Attributes.multiplier(OTHER, PlayerController.PACE), 1.0), true)
	Attributes.set_to(WHO, PlayerController.PACE, 0)
	equal("back at zero the authored number is the truth again",
		is_equal_approx(_body.current_speed(), base), true)
	equal("and the body carries a footsteps component",
		_body.get_node_or_null(^"Footsteps") != null, true)


## Metadata, and inheritance from the nearest tagged ancestor. Built on bare nodes rather than
## on a scene: what is under test is the walk up the tree, and a scene would only add furniture.
func _a_surface_is_read_off_the_geometry() -> void:
	var ground: Node3D = Node3D.new()
	var soft: StaticBody3D = StaticBody3D.new()
	var hard: StaticBody3D = StaticBody3D.new()
	var quiet: StaticBody3D = StaticBody3D.new()
	ground.add_child(soft)
	ground.add_child(hard)
	ground.add_child(quiet)

	equal("untagged geometry answers nothing", GroundSurface.of_node(quiet), GroundSurface.NONE)
	equal("and says so", GroundSurface.is_tagged(quiet), false)
	soft.set_meta(GroundSurface.META, SOFT)
	hard.set_meta(GroundSurface.META, HARD)
	equal("a tagged body answers its own tag", GroundSurface.of_node(soft), SOFT)
	equal("and a second one answers differently", GroundSurface.of_node(hard), HARD)
	equal("which is what 'at least two materials' means", GroundSurface.of_node(soft) != GroundSurface.of_node(hard), true)

	ground.set_meta(GroundSurface.META, HARD)
	equal("an untagged body inherits from the root", GroundSurface.of_node(quiet), HARD)
	equal("and a tagged one still overrides it", GroundSurface.of_node(soft), SOFT)
	equal("a String tag is read too, because that is what the inspector writes",
		GroundSurface.of_node(_tagged_with(ground, String(SOFT))), SOFT)
	equal("nothing at all is not a surface", GroundSurface.of_node(null), GroundSurface.NONE)
	ground.free()


func _tagged_with(parent: Node, value: String) -> Node:
	var node: StaticBody3D = StaticBody3D.new()
	node.set_meta(GroundSurface.META, value)
	parent.add_child(node)
	return node


## The timbre is derived from the NAME, which is what lets a game author a sixth surface and
## hear it without editing `src/`. Two properties matter and both are asserted: different names
## sound different, and the same name sounds the same every run.
func _a_step_sounds_like_its_surface() -> void:
	var soft: float = Footsteps.brightness_for(SOFT)
	var hard: float = Footsteps.brightness_for(HARD)
	# AUDIBLY apart, not merely unequal. `String.hash()` clusters its low bits, so two short
	# names used to land within 0.006 of each other and pass an inequality test while sounding
	# identical — the whole reason `_spread` avalanches the hash. A margin is what makes this
	# assertion the regression guard for that, and 0.05 is roughly where the ear stops caring.
	equal("two surfaces are audibly apart, not merely unequal", absf(soft - hard) > 0.05, true)
	equal("and apart on the second axis too",
		absf(Footsteps.decay_for(SOFT) - Footsteps.decay_for(HARD)) > 0.2, true)
	equal("a timbre is deterministic", is_equal_approx(Footsteps.brightness_for(SOFT), soft), true)
	equal("so is the decay", is_equal_approx(Footsteps.decay_for(SOFT), Footsteps.decay_for(SOFT)), true)
	equal("which stays inside its own range",
		Footsteps.decay_for(SOFT) >= Footsteps.MIN_DECAY and Footsteps.decay_for(SOFT) <= Footsteps.MAX_DECAY,
		true)
	equal("an untagged surface has no decay either",
		is_equal_approx(Footsteps.decay_for(GroundSurface.NONE), 0.0), true)
	equal("and stays inside the audible range",
		soft >= Footsteps.MIN_BRIGHTNESS and soft <= Footsteps.MAX_BRIGHTNESS, true)
	equal("as does the other", hard >= Footsteps.MIN_BRIGHTNESS and hard <= Footsteps.MAX_BRIGHTNESS, true)
	equal("an untagged surface has no timbre at all",
		is_equal_approx(Footsteps.brightness_for(GroundSurface.NONE), 0.0), true)

	var stream: AudioStreamWAV = Footsteps.stream_for(SOFT)
	equal("a step is a real generated stream", stream != null, true)
	equal("of the declared length", stream.data.size(), int(Footsteps.MIX_RATE * Footsteps.STEP_SECONDS) * 2)
	equal("and does not loop, because a step is not a bed", stream.loop_mode, AudioStreamWAV.LOOP_DISABLED)
	equal("no sound is started headless, or every step leaks", AmbienceBed.is_audible(), false)


## The one part of a step that has memory, extracted for the reason `SurfaceWetness`'s dry-out
## was: behaviour over distance is assertable, a physics frame is not.
func _the_stride_accumulator() -> void:
	var walker: Footsteps = Footsteps.new()
	walker.stride = 1.0
	equal("half a stride is not a step", walker.travel(0.5), false)
	equal("the rest of it is", walker.travel(0.5), true)
	equal("standing still is never a step", walker.travel(0.0), false)
	equal("and neither is walking backwards through the accumulator", walker.travel(-2.0), false)
	equal("a long stride still only falls once", walker.travel(1.4), true)
	# The remainder is CARRIED, so the 0.4 left over plus 0.6 is the next step. A version that
	# reset to zero would drop it, and a character walking in small increments would fall
	# progressively further behind their own feet.
	equal("and the remainder carries into the next", walker.travel(0.7), true)
	equal("nothing was underfoot, so nothing was stepped on", walker.ground(), GroundSurface.NONE)
	equal("and with no probe in the tree it is not grounded", walker.is_grounded(), false)
	walker.free()


func _tear_down() -> void:
	if _body != null:
		_body.free()
		_body = null
	Flags.clear_all()
	SaveSystem.delete_slot(SLOT)
