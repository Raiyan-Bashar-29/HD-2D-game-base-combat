extends TestCase
## WHAT A SETTING DOES, rather than whether anything reads it.
##
## THE SPLIT FROM `settings_consumers_test.gd` IS BY QUESTION, and it was forced by a budget the
## way T5.6's was. That file asks *is this key reached, and is its consumer wired into the running
## game* - a reachability question, answered against `Settings.DEFAULTS` and `SceneState`. This one
## asks *and does the effect actually happen* - answered by driving the real path and reading the
## number that comes back. The two questions fail differently and are worth failing separately: a
## key can be read by a consumer that does the wrong thing with it, which is exactly the pair of
## defects T5.7 found.
##
## BOTH SUBJECTS HERE ARE T5.5 LEAVING A SETTING HALF-APPLIED, and neither was a mistake at the
## time - both are written down in that row's own DEVLOG as gaps:
##
##   `accessibility/reduce_motion` reached the dialogue typewriter and neither of the other two
##   motions this template draws. A preference honoured in one place out of three is a preference
##   the player will discover is untrue.
##
##   `video/shadows` turned the atlas off correctly and turned it back on at a 2048 const called
##   "the engine's own default". The engine's default is 4096. Only the OFF half had ever been
##   photographed, and off is the half a wrong constant cannot break.
##
## NOTHING HERE IS PHOTOGRAPHED, and that is a finding rather than an omission. A cut and a
## finished dissolve are the same picture; a camera at rest is the same picture however it got
## there; and `--headless` shades nothing anyway (gotcha 2). What separates them is the frames
## BETWEEN, so every assertion below drives the real path one step at a time and reads a value
## that only one of the two behaviours can produce.
##
## OWNS: assertions that reduce-motion reaches every motion the template draws, that the screen
## shake is the player scale on the area author's amplitude, and that the shadow atlas comes back
## at the authored size, and that the autosave lands in a slot no manual save can reach.
## MUST NOT: ask whether a setting has a consumer at all - `settings_consumers_test.gd` owns that,
## and duplicating its scan here would give two answers to one question.

const FADE: GDScript = preload("res://src/ui/hud/screen_fade.gd")
## Long enough that a real tween cannot have finished by the next statement. `run()` is
## synchronous, so a tweened fade has moved NOTHING when control comes back - which is exactly
## what makes an instant one distinguishable from an animated one without a single frame passing.
const FADE_SECONDS: float = 0.5
## An area-authored smoothing, deliberately not the rig's own default, so the restore assertion
## proves the AUTHORED number came back rather than a default that happens to match.
const SOFT_LAG: float = 0.22
## Far enough that one exponentially-smoothed step is nowhere near it, so "part of the way" is
## not a float-comparison argument.
const STEP_METRES: float = 10.0
const PHYSICS_DELTA: float = 1.0 / 60.0
## An area-authored shake amplitude, in metres of camera slide at full strength. Deliberately
## not the rig's own default, for `SOFT_LAG`'s reason: a restore assertion has to prove the
## AUTHORED number came back and not a default that happens to match it.
const AUTHORED_SHAKE: float = 0.4
## How long a measured shake decays over. Long enough that one physics step is nowhere near the
## end of it, so "it came back to rest" is a claim about the decay and not about rounding.
const SHAKE_SECONDS: float = 0.6
## What `_apply_shadows` used to restore, kept here as the thing that must NOT come back. It is
## named in a test rather than in `settings.gd`, which is the difference between a record and a
## constant something might start using again.
const OLD_CONST: int = 2048
## A size no project setting has, so a `ShadowAtlas` that answered it can only have read this
## viewport.
const SCRATCH_ATLAS: int = 1024
## An area id for the autosave assertions to stand a run up with. It names no content, which is
## the whole point: the policy asks whether a run EXISTS, never which area it is in.
const FIXTURE_AREA: StringName = &"fixture_area"


func run() -> void:
	plan(63)
	# This case writes or deletes slots; redirected so they are not the developer's own. The
	# runner deactivates after every case.
	SaveFixture.activate()
	_the_fade_cuts_instead_of_dissolving()
	_the_camera_stops_smoothing_and_the_author_still_decides()
	_shadows_come_back_at_the_size_the_project_authored()
	_the_shake_is_the_players_scale_on_the_authors_amplitude()
	_a_shake_ends_itself_and_never_starts_where_the_author_refused()
	_the_autosave_has_a_slot_no_manual_save_can_reach()
	_an_autosave_is_a_file_and_six_manual_saves_leave_it_alone()
	_the_policy_refuses_three_things_and_says_so_when_it_does_not()
	Settings.reset_to_defaults()



## THE ONE THING A STILL FRAME CANNOT PROVE, so it is not photographed. A cut and a dissolve are
## byte-identical once either has finished; they differ only in the frames between, which is
## T5.5's own honest limit on the typewriter restated for the fade.
##
## What CAN be measured is the real path, driven from outside: `Events.screen_fade_requested` is
## the only input this node has, and `run()` is synchronous, so a tween created inside the
## handler has not advanced by the time the next line reads `color.a`. A dissolve therefore
## leaves the alpha where it started and a cut leaves it at the target - one assertion, no
## awaits, no test-only accessor, and no reaching at the private tween.
func _the_fade_cuts_instead_of_dissolving() -> void:
	var fade: ColorRect = FADE.new() as ColorRect
	attach(fade)
	Settings.set_value(FADE.REDUCE_MOTION, false)
	fade.color.a = 1.0
	Events.screen_fade_requested.emit(false, FADE_SECONDS)
	equal("with motion allowed the fade is still at the start of its half second",
			is_equal_approx(fade.color.a, 1.0), true)

	Settings.set_value(FADE.REDUCE_MOTION, true)
	fade.color.a = 1.0
	Events.screen_fade_requested.emit(false, FADE_SECONDS)
	equal("and with reduce motion on the identical request has already landed",
			is_equal_approx(fade.color.a, 0.0), true)
	Events.screen_fade_requested.emit(true, FADE_SECONDS)
	equal("in both directions, so a transition cuts at each end",
			is_equal_approx(fade.color.a, 1.0), true)
	Settings.set_value(FADE.REDUCE_MOTION, false)
	fade.queue_free()


## `follow_lag` is the only number on the rig that is motion rather than framing, and the veto
## shape is `_authored_dof`'s exactly: the setting may remove the area author's smoothing and may
## never add smoothing they did not ask for.
##
## DRIVEN THROUGH `_physics_process`, which is where the smoothing actually lives. Asserting the
## exported number alone would be two green ends either side of an untested wire - gotcha 54 -
## because nothing would have proved the camera reads `follow_lag` at all.
func _the_camera_stops_smoothing_and_the_author_still_decides() -> void:
	Settings.set_value(HD2DCameraRig.REDUCE_MOTION, false)
	var target := Node3D.new()
	attach(target)
	var rig := HD2DCameraRig.new()
	rig.follow_lag = SOFT_LAG
	rig.yaw_degrees = 0.0
	attach(rig)
	rig.set_target(target)
	equal("the rig keeps the lag its area scene authored",
			is_equal_approx(rig.follow_lag, SOFT_LAG), true)
	target.global_position = Vector3(STEP_METRES, 0.0, 0.0)
	rig._physics_process(PHYSICS_DELTA)
	var lagged: float = rig.camera.global_position.x
	equal("and one step carries the camera only part of the way",
			lagged > 0.0 and lagged < STEP_METRES, true)

	Settings.set_value(HD2DCameraRig.REDUCE_MOTION, true)
	equal("the setting zeroes the smoothing", is_equal_approx(rig.follow_lag, 0.0), true)
	target.global_position = Vector3(STEP_METRES * 2.0, 0.0, 0.0)
	rig._physics_process(PHYSICS_DELTA)
	equal("and the same step now lands the camera exactly on the target, with no drift left",
			is_equal_approx(rig.camera.global_position.x, STEP_METRES * 2.0), true)
	Settings.set_value(HD2DCameraRig.REDUCE_MOTION, false)
	equal("turning it off gives the area author's number back",
			is_equal_approx(rig.follow_lag, SOFT_LAG), true)
	rig.queue_free()

	var rigid := HD2DCameraRig.new()
	rigid.follow_lag = 0.0
	attach(rigid)
	equal("a rig authored rigid starts rigid", is_equal_approx(rigid.follow_lag, 0.0), true)
	Settings.set_value(HD2DCameraRig.REDUCE_MOTION, true)
	Settings.set_value(HD2DCameraRig.REDUCE_MOTION, false)
	equal("and turning the setting off does NOT hand it smoothing the author refused",
			is_equal_approx(rigid.follow_lag, 0.0), true)
	rigid.queue_free()
	target.queue_free()


## `_apply_shadows` zeroed the atlas to turn shadows off and restored a `2048` const to turn them
## back on, under a comment calling 2048 "the engine's own default". IT IS 4096, in this very
## repository, so the first toggle halved the shadow map and the second never put it back. Only
## the OFF half was ever photographed, and off is the half a wrong constant cannot break.
##
## DRIVEN THROUGH `Settings._apply_shadows` RATHER THAN THROUGH THE SETTING, and this is a real
## limit rather than a convenience: `_apply_display` returns early under `--headless`, so the
## public path from `set_value` cannot reach the atlas in the suite at all. What is proved here is
## the wire from the autoload to `ShadowAtlas` and the number that comes back; that the setting
## reaches `_apply_display` is `_every_setting_has_a_consumer`'s job, and the windowed run's.
func _shadows_come_back_at_the_size_the_project_authored() -> void:
	var authored: int = get_viewport().positional_shadow_atlas_size
	equal("the project authors a positional atlas", authored > 0, true)
	equal("and it is NOT the 2048 the old const restored", authored != OLD_CONST, true)
	Settings._apply_shadows(false)
	equal("turning shadows off zeroes the atlas, so every light in the world stops casting",
			get_viewport().positional_shadow_atlas_size, 0)
	Settings._apply_shadows(true)
	equal("and turning them back on restores what the project authored, not a constant",
			get_viewport().positional_shadow_atlas_size, authored)

	# And the remembering, on a viewport of its own, so the numbers cannot come from the root by
	# accident. A SubViewport authors its own atlas size independently of the project setting.
	var scratch := SubViewport.new()
	scratch.positional_shadow_atlas_size = SCRATCH_ATLAS
	attach(scratch)
	var atlas := ShadowAtlas.new()
	equal("a fresh atlas has remembered nothing yet", atlas.authored_positional(), -1)
	atlas.apply(scratch, false)
	equal("the first apply remembers before it zeroes", atlas.authored_positional(), SCRATCH_ATLAS)
	equal("and reads the directional size from the project rather than from a const",
			atlas.authored_directional(),
			ProjectSettings.get_setting(ShadowAtlas.DIRECTIONAL_SETTING, -1))
	atlas.apply(scratch, true)
	equal("so this viewport gets ITS size back and not the root's",
			scratch.positional_shadow_atlas_size, SCRATCH_ATLAS)
	scratch.queue_free()


## THE SHAKE, AND IT IS THE THIRD TIME THIS RIG HAS TAKEN `_authored_dof`'s VETO SHAPE. The
## author's number is the AMPLITUDE on their rig; the player's number is a 0..1 SCALE on it; and
## `reduce_motion` removes it outright rather than making it smaller, for the reason the fade
## above cuts instead of dissolving faster.
##
## DRIVEN THROUGH `_physics_process`, never by reading `shake_metres` alone. The amplitude and
## the displacement are the two ends of a wire, and asserting both ends of one is exactly what
## gotcha 54 looks like - so every distance below comes out of the camera's real position after
## a real step, and only the SETUP reads the exported number.
##
## AND EVERY DISTANCE IS COMPARABLE BECAUSE THE SHAKE IS A SINE. Each measurement fires a fresh
## request and takes exactly one step, so the phase is identical every time; a random jitter
## would have made "half as far" an unassertable claim, which is the argument for the waveform
## rather than a happy consequence of it.
func _the_shake_is_the_players_scale_on_the_authors_amplitude() -> void:
	Settings.set_value(HD2DCameraRig.REDUCE_MOTION, false)
	Settings.set_value(HD2DCameraRig.SHAKE_SETTING, 1.0)
	var target := Node3D.new()
	attach(target)
	var rig: HD2DCameraRig = _rig_for(target, AUTHORED_SHAKE)
	equal("the rig keeps the amplitude its area scene authored",
			is_equal_approx(rig.shake_metres, AUTHORED_SHAKE), true)
	var rest: Vector3 = rig.camera.global_position
	rig._physics_process(PHYSICS_DELTA)
	equal("and a step with nothing asked for leaves the camera exactly where placement put it",
			rig.camera.global_position.is_equal_approx(rest), true)

	var full: float = _shaken_by(rig, rest)
	equal("one request actually displaces the camera", full > 0.0, true)
	Settings.set_value(HD2DCameraRig.SHAKE_SETTING, 0.5)
	equal("halving the setting halves the amplitude",
			is_equal_approx(rig.shake_metres, AUTHORED_SHAKE * 0.5), true)
	equal("and the identical request moves the camera exactly half as far, so the setting is a "
			+ "scale and not a switch", is_equal_approx(_shaken_by(rig, rest) * 2.0, full), true)

	Settings.set_value(HD2DCameraRig.REDUCE_MOTION, true)
	equal("reduce motion removes the shake outright rather than making it smaller",
			is_equal_approx(rig.shake_metres, 0.0), true)
	equal("so the same request moves the camera not at all",
			is_equal_approx(_shaken_by(rig, rest), 0.0), true)
	Settings.set_value(HD2DCameraRig.REDUCE_MOTION, false)
	Settings.set_value(HD2DCameraRig.SHAKE_SETTING, 1.0)
	equal("and turning both back gives the area author's amplitude back",
			is_equal_approx(rig.shake_metres, AUTHORED_SHAKE), true)
	rig.queue_free()
	target.queue_free()


## The two claims a scale assertion cannot make. A shake that never ended would be a broken
## camera rather than a feature, and a rig whose author gave it no amplitude must not gain one
## from a player's preference - which is the half of the veto no setting can be trusted with.
func _a_shake_ends_itself_and_never_starts_where_the_author_refused() -> void:
	var target := Node3D.new()
	attach(target)
	var rig: HD2DCameraRig = _rig_for(target, AUTHORED_SHAKE)
	var rest: Vector3 = rig.camera.global_position
	rig.shake(1.0, SHAKE_SECONDS)
	for _i: int in roundi(SHAKE_SECONDS / PHYSICS_DELTA) + 2:
		rig._physics_process(PHYSICS_DELTA)
	equal("a shake decays to nothing by itself, so the camera comes back to rest",
			rig.camera.global_position.is_equal_approx(rest), true)
	rig.shake(0.0, SHAKE_SECONDS)
	rig._physics_process(PHYSICS_DELTA)
	equal("and a request of no strength is refused rather than started",
			rig.camera.global_position.is_equal_approx(rest), true)
	rig.queue_free()

	# Authored BEFORE it enters the tree, because `_ready` is the moment the rig remembers what
	# the area scene asked for - which is the whole mechanism, and setting it afterwards would
	# assert against a value the rig had already replaced.
	var still: HD2DCameraRig = _rig_for(target, 0.0)
	equal("a rig authored still starts still", is_equal_approx(still.shake_metres, 0.0), true)
	Settings.set_value(HD2DCameraRig.SHAKE_SETTING, 1.0)
	equal("and the setting at full does NOT hand it a shake the author refused",
			is_equal_approx(still.shake_metres, 0.0), true)
	equal("so asking it to shake moves it nowhere",
			is_equal_approx(_shaken_by(still, still.camera.global_position), 0.0), true)
	still.queue_free()
	target.queue_free()


## A rig in the tree, following `target`, authored rigid so no smoothing can be mistaken for a
## shake, and with `metres` authored before it enters the tree.
func _rig_for(target: Node3D, metres: float) -> HD2DCameraRig:
	var rig := HD2DCameraRig.new()
	rig.follow_lag = 0.0
	rig.shake_metres = metres
	attach(rig)
	rig.set_target(target)
	return rig


## One request, one step, and how far that left the camera from where placement alone would have
## put it. Every caller gets the same instant of the wave, because `shake()` restarts the decay
## and `_physics_process` advances it by exactly one delta before placing.
func _shaken_by(rig: HD2DCameraRig, rest: Vector3) -> float:
	rig.shake(1.0, SHAKE_SECONDS)
	rig._physics_process(PHYSICS_DELTA)
	return rig.camera.global_position.distance_to(rest)


## THE SLOT POLICY, WHICH WAS THIS ROW'S DESIGN QUESTION AND NOT ITS TRIGGER. An autosave that
## can overwrite a save the player made on purpose is the one thing an autosave must never be,
## so the promise is structural: the autosave's slot number is outside the range every manual
## list iterates, and it is not one of the six renamed.
func _the_autosave_has_a_slot_no_manual_save_can_reach() -> void:
	equal("the autosave slot is outside the manual range",
			SaveSystem.AUTOSAVE_SLOT >= SaveSystem.MAX_SLOTS, true)
	var shares_a_path: bool = false
	for slot: int in SaveSystem.MAX_SLOTS:
		equal("manual slot %d is not the autosave" % slot, SaveSystem.is_autosave(slot), false)
		if SaveSystem.slot_path(slot) == SaveSystem.slot_path(SaveSystem.AUTOSAVE_SLOT):
			shares_a_path = true
	equal("while the autosave slot is", SaveSystem.is_autosave(SaveSystem.AUTOSAVE_SLOT), true)
	equal("it is a file with a name rather than a seventh slot_NN.json",
			SaveSystem.slot_path(SaveSystem.AUTOSAVE_SLOT).ends_with(SaveSystem.AUTOSAVE_FILE), true)
	equal("and no slot the save screen offers lands on that same file", shares_a_path, false)


## A SAVE IS A FILE, which is why most of this row is provable here and the camera work of T5.7
## and T5.9 was not: there is a real artefact on disk to assert against rather than a picture to
## be looked at. The claim is the one the policy makes to the player - write into all six slots
## the save screen offers and the autosave is still exactly the autosave.
func _an_autosave_is_a_file_and_six_manual_saves_leave_it_alone() -> void:
	_clear_every_slot()
	var auto: int = SaveSystem.AUTOSAVE_SLOT
	equal("the autosave slot accepts a write", SaveSystem.save_to_slot(auto), OK)
	equal("and there is a file on disk afterwards",
			FileAccess.file_exists(SaveSystem.slot_path(auto)), true)
	var before: Dictionary = SaveSystem.slot_info(auto)
	equal("with a header the load list can read without applying anything",
			DictRead.get_string(before, "saved_utc", "") != "", true)
	equal("and Continue sees it, because an autosave nobody can come back to is not one",
			SaveSystem.latest_slot(), auto)

	for slot: int in SaveSystem.MAX_SLOTS:
		equal("manual slot %d writes" % slot, SaveSystem.save_to_slot(slot), OK)
	equal("and after all six the autosave file is still there",
			FileAccess.file_exists(SaveSystem.slot_path(auto)), true)
	equal("carrying the header it was written with",
			SaveSystem.slot_info(auto), before)
	_clear_every_slot()


## THE THREE REFUSALS, EACH DRIVEN THROUGH THE REAL PREDICATE `request()` READS, and each proved
## by the absence of a file rather than by the return code alone - a policy that returned ERR_SKIP
## and wrote anyway would pass half of this and is exactly the pair of ways to be wrong that
## T5.7 found. The transition state is set on `Director` itself, not modelled here: this asserts
## the guard the running game consults, and a copy of it would assert nothing.
func _the_policy_refuses_three_things_and_says_so_when_it_does_not() -> void:
	var policy := Autosave.new()
	attach(policy)
	_clear_every_slot()
	var auto: int = SaveSystem.AUTOSAVE_SLOT
	var was_area: StringName = Director.current_area_id
	Settings.set_value(Autosave.AUTOSAVE_SETTING, true)

	Director.current_area_id = &""
	equal("with no run in progress there is nothing to autosave", policy.request(), ERR_SKIP)
	equal("so quitting from the main menu cannot flatten a real run's autosave",
			SaveSystem.has_slot(auto), false)

	Director.current_area_id = FIXTURE_AREA
	Director._transitioning = true
	equal("and mid-transition it refuses", policy.request(), ERR_SKIP)
	equal("so a world that exists in neither area is never written", SaveSystem.has_slot(auto), false)
	Director._transitioning = false

	Settings.set_value(Autosave.AUTOSAVE_SETTING, false)
	equal("and the player's veto refuses it", policy.request(), ERR_SKIP)
	equal("with nothing on disk to show for it", SaveSystem.has_slot(auto), false)

	var announced: Array[String] = []
	var listener: Callable = func(key: String, _seconds: float, _args: Dictionary) -> void:
		announced.append(key)
	Events.notify_requested.connect(listener)
	equal("nothing has been announced by three refusals", announced.size(), 0)
	Settings.set_value(Autosave.AUTOSAVE_SETTING, true)
	equal("and with a run, no transition and the setting on, it writes", policy.request(), OK)
	equal("into the autosave slot and no other", SaveSystem.has_slot(auto), true)
	equal("and the player is told it happened, which is the indicator item 6 asks for",
			announced, [Autosave.NOTIFY_KEY] as Array[String])
	Events.notify_requested.disconnect(listener)

	Director.current_area_id = was_area
	_clear_every_slot()
	policy.queue_free()


## Every slot INCLUDING the autosave's. A file left behind here is a save the next test file
## sees, and `menus_test.gd` asserts that a first run has none.
func _clear_every_slot() -> void:
	for slot: int in SaveSystem.AUTOSAVE_SLOT + 1:
		SaveSystem.delete_slot(slot)
