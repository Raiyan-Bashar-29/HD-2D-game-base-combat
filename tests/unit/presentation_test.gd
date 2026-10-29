extends TestCase
## Weather presentation: the wetness curve, the emitter mix, and the surfaces that get wet.
##
## WHAT THIS CAN AND CANNOT PROVE
## It can prove that a storm reaches the emitters, that the mix table has a row for every
## kind, that a soaked material really is darker and shinier than a dry one, and that it
## returns EXACTLY to its authored values when it dries. It cannot prove any of that is
## visible: gotcha 2, --headless shades nothing. The pictures are in docs/DEVLOG.md.
##
## OWNS: assertions about how weather state becomes a picture.
## MUST NOT: assert on a rendered pixel, or on the weather state machine, which is
## world_test.gd's job.

var _toasts: Array[Dictionary] = []


func run() -> void:
	plan(47)
	_wetness_curve()
	_mix_table()
	_emitters_follow_the_weather()
	_surfaces_wet_and_dry()
	_localization()
	Weather.sheltered = false
	Weather.force(GameEnums.WeatherKind.CLEAR)


## The one part of the weather visuals with memory, and therefore the only part an assertion
## can catch drifting. Soaking fast and drying slow is the whole effect.
func _wetness_curve() -> void:
	var model := WetnessModel.new()
	equal("wetness starts dry", is_equal_approx(model.wetness(), 0.0), true)

	model.advance(1.0, 1.0)
	equal("one second of rain is not a soaking", model.wetness() < 0.2, true)
	equal("but it is measurably wet", model.wetness() > 0.05, true)

	model.advance(WetnessModel.DEFAULT_SOAK, 1.0)
	equal("a full soak reaches 1.0", is_equal_approx(model.wetness(), 1.0), true)

	# The asymmetry is the point: ground that dried as fast as it wetted reads as a switch.
	model.advance(WetnessModel.DEFAULT_SOAK, 0.0)
	equal("a soak's worth of drying is not enough", model.wetness() > 0.5, true)
	model.advance(WetnessModel.DEFAULT_DRY, 0.0)
	equal("and it does dry out completely", is_equal_approx(model.wetness(), 0.0), true)

	model.reset_to(4.0)
	equal("wetness clamps above", is_equal_approx(model.wetness(), 1.0), true)
	model.advance(1.0, -3.0)
	equal("wetness clamps below", model.wetness() < 1.0, true)
	equal("and never goes negative", model.wetness() >= 0.0, true)


## Every WeatherKind must have a row, or a kind added later renders as nothing at all and
## nobody notices until a capture is taken on the one day it rolls.
func _mix_table() -> void:
	var kinds: Array = GameEnums.WeatherKind.keys()
	equal("the mix table covers every WeatherKind", WeatherVisuals.MIX.size(), kinds.size())

	var clear: Vector3 = WeatherVisuals.mix_for(GameEnums.WeatherKind.CLEAR)
	equal("a clear sky emits nothing at all", clear, Vector3.ZERO)

	var rain: Vector3 = WeatherVisuals.mix_for(GameEnums.WeatherKind.RAIN)
	var storm: Vector3 = WeatherVisuals.mix_for(GameEnums.WeatherKind.STORM)
	var snow: Vector3 = WeatherVisuals.mix_for(GameEnums.WeatherKind.SNOW)
	equal("rain rains", rain.x > 0.0, true)
	equal("rain does not snow", is_equal_approx(rain.y, 0.0), true)
	equal("a storm rains harder than rain", storm.x > rain.x, true)
	equal("and blows harder too", storm.z > rain.z, true)
	equal("snow snows", is_equal_approx(snow.y, 1.0), true)
	equal("snow does not rain", is_equal_approx(snow.x, 0.0), true)
	equal("wind is all motes", WeatherVisuals.mix_for(GameEnums.WeatherKind.WIND).z > 0.9, true)


func _emitters_follow_the_weather() -> void:
	var visuals := WeatherVisuals.new()
	visuals.announce_changes = true
	attach(visuals)

	equal("an emitter exists for rain", visuals.emitter(GameEnums.WeatherKind.RAIN) != null, true)
	equal("and for snow", visuals.emitter(GameEnums.WeatherKind.SNOW) != null, true)
	equal("and for wind", visuals.emitter(GameEnums.WeatherKind.WIND) != null, true)
	# CLEAR, CLOUDY, OVERCAST and FOG are the environment driver's fog, not particles.
	equal("but not for a clear sky", Precipitation.make(GameEnums.WeatherKind.CLEAR), null)

	var rain: Precipitation = visuals.emitter(GameEnums.WeatherKind.RAIN)
	var motes: Precipitation = visuals.emitter(GameEnums.WeatherKind.WIND)

	Weather.force(GameEnums.WeatherKind.STORM)
	visuals.drive(0.0)
	equal("a storm runs the rain at full", is_equal_approx(rain.weight(), 1.0), true)
	equal("and the rain is actually emitting", rain.emitting, true)
	equal("and the motes blow with it", motes.weight() > 0.5, true)

	Weather.force(GameEnums.WeatherKind.CLEAR)
	visuals.drive(0.0)
	equal("a clear sky stops the rain", is_equal_approx(rain.weight(), 0.0), true)
	equal("and switches the emitter off", rain.emitting, false)

	_shelter_and_toast(visuals, rain)
	visuals.free()


## Shelter is a Weather contract this node has to honour, and the toast is the only reason
## this node knows the UI exists at all — so both are asserted where they are implemented.
func _shelter_and_toast(visuals: WeatherVisuals, rain: Precipitation) -> void:
	Weather.force(GameEnums.WeatherKind.STORM)
	Weather.sheltered = true
	visuals.drive(0.0)
	equal("shelter stops the rain reaching you", is_equal_approx(rain.weight(), 0.0), true)
	equal("without changing the weather", Weather.current(), GameEnums.WeatherKind.STORM)
	Weather.sheltered = false
	visuals.drive(0.0)
	equal("and stepping out puts you back in it", rain.weight() > 0.9, true)

	# Ambience is layered rather than one track per kind, so a storm raises both beds. The
	# LEVEL is asserted rather than the playback: this run's audio driver is Dummy, and the bed
	# deliberately starts no playback against it — see AmbienceBed.is_audible(). The level is
	# what set_level was asked for and what volume_db is derived from, in both cases.
	equal("the storm raises the rain bed", Audio.beds.level(&"rain") > 0.5, true)
	equal("and the wind bed with it", Audio.beds.level(&"wind") > 0.3, true)
	equal("this run has no audio device", AmbienceBed.is_audible(), false)
	Weather.force(GameEnums.WeatherKind.CLEAR)
	visuals.drive(0.0)
	equal("a clear sky silences the rain bed", is_equal_approx(Audio.beds.level(&"rain"), 0.0), true)
	equal("and leaves nothing playing", Audio.beds.is_playing(&"rain"), false)

	_toasts.clear()
	Events.notify_requested.connect(_on_notify_requested)
	Weather.request(GameEnums.WeatherKind.RAIN, 1.0)
	Events.notify_requested.disconnect(_on_notify_requested)
	equal("the sky turning announces itself once", _toasts.size(), 1)
	if _toasts.size() == 1:
		equal("with a key, never a literal", DictRead.get_string(_toasts[0], "key"), WeatherVisuals.TURNS_KEY)
		var args: Dictionary = DictRead.get_dict(_toasts[0], "args")
		equal("naming the weather", DictRead.get_string(args, "weather"), tr("weather.rain"))
	Weather.force(GameEnums.WeatherKind.CLEAR)


## The exit criterion, at the level an assertion can reach: a soaked material really is darker
## and shinier, and drying returns it EXACTLY to what the author set rather than to a default.
func _surfaces_wet_and_dry() -> void:
	var host := Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.5, 0.4, 1.0)
	material.roughness = 0.8
	mesh_instance.mesh = BoxMesh.new()
	mesh_instance.set_surface_override_material(0, material)
	host.add_child(mesh_instance)

	var wetness := SurfaceWetness.new()
	host.add_child(wetness)
	attach(host)
	equal("the wetness node adopted the surface", wetness.surface_count(), 1)

	var owned: StandardMaterial3D = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	# It must NOT be the material it was handed: a sub-resource is shared between every
	# instantiation of a scene, so writing to that one leaves the area wet after a reload.
	equal("and took its own copy of it", owned != material, true)
	var dry_albedo: Color = owned.albedo_color
	var dry_roughness: float = owned.roughness

	wetness.apply(1.0)
	equal("a soaked surface is darker", owned.albedo_color.v < dry_albedo.v, true)
	equal("and smoother, so light catches it", owned.roughness < dry_roughness, true)
	equal("and reports what it painted", is_equal_approx(wetness.applied(), 1.0), true)

	wetness.apply(0.0)
	equal("drying restores the exact authored colour", owned.albedo_color, dry_albedo)
	equal("and the exact authored roughness", is_equal_approx(owned.roughness, dry_roughness), true)
	host.free()


## The weather name is BUILT at runtime from the enum, exactly like verb.* and refusal.*, so
## no text-scanning validator can follow it. An enum loop is the only thing that can.
func _localization() -> void:
	var kinds: Array = GameEnums.WeatherKind.keys()
	var missing: int = 0
	for index: int in kinds.size():
		var raw: String = kinds[index]
		var key: String = WeatherVisuals.NAME_KEY % raw.to_lower()
		if tr(key) == key:
			missing += 1
			Log.warn("test", "no translation for %s" % key)
	equal("every WeatherKind has a name to show", missing, 0)
	equal("and the toast has a line to put it in", tr(WeatherVisuals.TURNS_KEY) != WeatherVisuals.TURNS_KEY, true)


func _on_notify_requested(key: String, _seconds: float, args: Dictionary) -> void:
	_toasts.append({"key": key, "args": args})
