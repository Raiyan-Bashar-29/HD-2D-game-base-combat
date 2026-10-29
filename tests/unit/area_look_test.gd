extends TestCase
## The three art-contract seams T3.2 opened, plus the texture import defaults it measured.
##
## WHAT THIS CASE CANNOT DO, SAID FIRST SO NOBODY MISREADS A GREEN RUN
## Every seam here is VISUAL, and `--headless` shades nothing (gotcha 2). Nothing below claims
## that a material looks like wood, that a fog density reads as haze, or that a 36-degree lens
## frames an interior better than a 27-degree one. Those claims are six windowed captures, looked
## at and read, quoted in docs/DEVLOG.md. What is here is the half a machine can see: that the
## seam EXISTS, that it is reached from DATA rather than from code, and that the value has not
## grown back into a script.
##
## WHAT IT CAN DO, AND EACH ONE IS THE REGRESSION SHAPE art_contract_test.gd ESTABLISHED
## 1. A shared material is one file used by more than one area, and no two areas declare the same
##    material inline. The second half is the defect T3.2 actually found: the two demo areas each
##    carried a byte-identical StandardMaterial3D, and two copies of one value eventually
##    disagree — the only question is which package finds out.
## 2. Every value in the environment post stack is an @export at the default T2.1 shipped, and the
##    driver assigns no number to the environment any more.
## 3. Every camera framing value is an @export, the rig assigns no number to its camera, and an
##    area really USES the seam rather than merely being allowed to.
## 4. The texture importer defaults close the detect_3d/compress_to hazard — in project.godot for
##    whatever a game imports next, and in every committed .import for what is here already.
##
## OWNS: assertions about area-authored look — materials, the post stack, framing, texture import.
## MUST NOT: claim what anything looks like, or name demo content.

const WOOD_MATERIAL: String = "res://assets/materials/wood.tres"
const DRIVER: String = "res://src/gameplay/world/environment_driver.gd"
const RIG: String = "res://src/gameplay/camera/hd2d_camera_rig.gd"
const TEXTURE_DEFAULTS: String = "importer_defaults/texture"
const DETECT_3D: String = "detect_3d/compress_to"

## The post stack, with the value T2.1 shipped as a literal beside it. A name here that is not an
## @export on the driver, or whose default has moved, fails — so this is the contract rather than
## a copy of it.
const POST_STACK: Dictionary = {
	"tonemap_exposure": 1.0,
	"glow_enabled": true,
	"glow_intensity": 0.9,
	"glow_strength": 1.1,
	"glow_bloom": 0.15,
	"glow_hdr_threshold": 0.92,
	"glow_hdr_scale": 2.0,
	"fog_enabled": true,
	"fog_depth_begin": 30.0,
	"fog_depth_end": 160.0,
	"fog_sky_affect": 0.35,
	"volumetric_fog_enabled": true,
	"volumetric_fog_density": 0.005,
	"volumetric_fog_length": 96.0,
	"volumetric_fog_anisotropy": 0.3,
	"volumetric_fog_gi_inject": 0.0,
	"ssao_enabled": false,
	"sdfgi_enabled": false,
	"ssil_enabled": false,
	"ssr_enabled": false,
}

## Camera framing, with the rig's shipped default. An area overrides any of these in its scene.
const FRAMING: Dictionary = {
	"distance": 14.0,
	"pitch_degrees": -32.0,
	"yaw_degrees": 0.0,
	"fov": 27.0,
	"height_offset": 1.15,
	"follow_lag": 0.10,
	"frame_bias": 0.10,
	"dof_enabled": true,
	"far_start": 4.0,
	"far_transition": 8.0,
	"near_start": 5.0,
	"near_transition": 4.0,
	"blur_amount": 0.12,
}


## 14 fixed outcomes: 4 for the shared material's own values, 2 for its users, 1 for the
## inline-duplicate gate, 1 for the driver holding no number, 1 for the rig holding no number,
## 1 for an area actually overriding a framing value, and 4 for the import defaults.
func run() -> void:
	plan(14 + POST_STACK.size() + FRAMING.size())
	_a_shared_material_is_one_file_and_more_than_one_area()
	_no_two_areas_declare_the_same_material_inline()
	_every_post_stack_value_is_an_export_at_its_shipped_default()
	_the_driver_assigns_no_number_to_the_environment()
	_every_framing_value_is_an_export_at_its_shipped_default()
	_the_rig_assigns_no_number_to_its_camera()
	_an_area_really_uses_the_framing_seam()
	_the_texture_import_defaults_close_the_3d_compression_hazard()


## Gotcha 38: a misspelled property in a hand-authored .tres is silently DISCARDED, so the values
## are read back off the LOADED resource rather than trusted to the file.
func _a_shared_material_is_one_file_and_more_than_one_area() -> void:
	var material: StandardMaterial3D = load(WOOD_MATERIAL) as StandardMaterial3D
	equal("the shared material loads", material != null, true)
	equal("it carries a texture", material.albedo_texture != null, true)
	equal("it filters nearest, which is what keeps pixel art pixels",
		material.texture_filter, BaseMaterial3D.TEXTURE_FILTER_NEAREST)
	equal("its uv scale survived the hand-authored file", material.uv1_scale, Vector3(2, 2, 1))
	_the_shared_material_has_more_than_one_user()


func _the_shared_material_has_more_than_one_user() -> void:
	var users: Array[String] = []
	for scene: String in _area_scenes():
		if _read(scene).contains(WOOD_MATERIAL):
			users.append(scene)
	if users.size() < 2:
		skip("a shared material is used by more than one area",
			"this checkout has %d area(s) naming it" % users.size(), 2)
		return
	equal("the shared material is used by more than one area", users.size() >= 2, true)
	var resolved: int = 0
	for scene: String in users:
		for dependency: String in ResourceLoader.get_dependencies(scene):
			if dependency.contains(WOOD_MATERIAL):
				resolved += 1
				break
	equal("every area naming it really depends on it", resolved, users.size())


## THE DEFECT THIS SEAM EXISTS FOR. Sub-resource bodies are compared with their ExtResource ids
## resolved to paths, because the same material carries different ids in different scenes — which
## is exactly why two copies of it stayed invisible until someone read both files side by side.
func _no_two_areas_declare_the_same_material_inline() -> void:
	var scenes: Array[String] = _area_scenes()
	if scenes.size() < 2:
		skip("no two areas declare the same material inline",
			"this checkout has %d area(s)" % scenes.size())
		return
	var seen: Dictionary = {}
	var duplicates: Array[String] = []
	for scene: String in scenes:
		for body: String in _inline_materials(scene):
			if seen.has(body) and not duplicates.has(body):
				duplicates.append(body)
			seen[body] = true
	equal("no two areas declare the same material inline (%d duplicated)" % duplicates.size(),
		duplicates.size(), 0)


func _every_post_stack_value_is_an_export_at_its_shipped_default() -> void:
	var driver := EnvironmentDriver.new()
	var source: String = _read(DRIVER)
	for name: String in POST_STACK:
		equal("%s is an @export at the value T2.1 shipped" % name,
			[driver.get(name), _declares_export(source, name)],
			[POST_STACK[name], true])
	driver.free()


## THE REGRESSION GATE. `_environment.<anything> = <a number>` is the shape every one of those
## values had before T3.2. A CALL is not a literal: `maxf(0.1, ...)` clamps a computed value and
## is not a look decision, so only the first token after the `=` is judged.
func _the_driver_assigns_no_number_to_the_environment() -> void:
	equal("the driver writes down no environment number",
		_numeric_assignments(DRIVER, "_environment"), 0)


func _every_framing_value_is_an_export_at_its_shipped_default() -> void:
	var rig := HD2DCameraRig.new()
	var source: String = _read(RIG)
	for name: String in FRAMING:
		equal("%s is an @export at the rig's shipped value" % name,
			[rig.get(name), _declares_export(source, name)],
			[FRAMING[name], true])
	rig.free()


func _the_rig_assigns_no_number_to_its_camera() -> void:
	equal("the rig writes down no camera or depth-of-field number",
		_numeric_assignments(RIG, "camera") + _numeric_assignments(RIG, "_attributes"), 0)


## A seam nothing uses is a seam nobody has tried. This is the "one piece of placeholder content
## per system" half, and it is content-dependent, so a stripped template skips it and says so.
##
## IT LOOKS INSIDE RIG NODES, NOT AT WHOLE FILES, and the first draft did not. `WeatherVisuals`
## exports a `height_offset` too, so a scan of every line in an area scene matched a node that has
## nothing to do with the camera and the assertion passed with the override deleted — found by
## planting exactly that (gotcha 23), and it is gotcha 17's family: two classes, one property name.
func _an_area_really_uses_the_framing_seam() -> void:
	var scenes: Array[String] = _area_scenes()
	if scenes.is_empty():
		skip("an area authors its own camera framing", "this checkout has no areas")
		return
	var overriding: int = 0
	for scene: String in scenes:
		for block: String in _blocks_with_script(scene, RIG):
			for line: String in block.split("\n"):
				if line.contains(" = ") and FRAMING.has(line.get_slice(" = ", 0)):
					overriding += 1
					break
	equal("at least one camera rig in an area authors its own framing", overriding >= 1, true)


## MEASURED, NOT LOOKED UP. `[importer_defaults]` is absent from --doctool (gotcha 30), so the
## format was proved by importing a throwaway texture with the section set and reading the
## regenerated .import back — quoted in docs/DEVLOG.md. This asserts the OUTCOME of that
## measurement, so an editor session that clears the section, or a re-import that flips one file
## back to VRAM compression, fails rung 4 instead of a capture nobody thought to take.
func _the_texture_import_defaults_close_the_3d_compression_hazard() -> void:
	var defaults: Dictionary = ProjectSettings.get_setting(TEXTURE_DEFAULTS, {})
	equal("the project sets texture importer defaults", defaults.has(DETECT_3D), true)
	equal("the default disables the 3D re-import to VRAM compression",
		DictRead.get_int(defaults, DETECT_3D, -1), 0)
	var detecting: Array[String] = []
	var lossy: Array[String] = []
	for path: String in _import_files("res://"):
		var body: String = _read(path)
		if not body.contains("importer=\"texture\""):
			continue
		if not body.contains("%s=0" % DETECT_3D):
			detecting.append(path)
		if not body.contains("compress/mode=0"):
			lossy.append(path)
	equal("every committed texture .import disables 3D detection: %s" % str(detecting),
		detecting.size(), 0)
	equal("every committed texture .import is lossless: %s" % str(lossy), lossy.size(), 0)


## Lines of CODE assigning a bare number to `<prefix>.<property>`. Comments are exempt, on
## check_boundary's reasoning: a `##` line naming the value an export replaced teaches by example
## and changes nothing, while a literal in code changes what is drawn.
func _numeric_assignments(path: String, prefix: String) -> int:
	var pattern := RegEx.new()
	var compiled: int = pattern.compile("^%s\\.[a-z_0-9]+ = -?[0-9]" % prefix)
	if compiled != OK:
		return -1
	var hits: int = 0
	for line: String in _read(path).split("\n"):
		var code: String = line.strip_edges()
		if not code.begins_with("#") and pattern.search(code) != null:
			hits += 1
	return hits


func _declares_export(source: String, name: String) -> bool:
	for line: String in source.split("\n"):
		if line.begins_with("@export") and line.contains("var %s:" % name):
			return true
	return false


## The property lines of every inline StandardMaterial3D in a scene, with ExtResource ids swapped
## for the paths they point at so that two scenes can be compared at all.
func _inline_materials(scene: String) -> Array[String]:
	var paths: Dictionary = {}
	var bodies: Array[String] = []
	var body: String = ""
	var inside: bool = false
	for line: String in _read(scene).split("\n"):
		if line.begins_with("[ext_resource "):
			paths[_quoted(line, "id=\"")] = _quoted(line, "path=\"")
		elif line.begins_with("[sub_resource type=\"StandardMaterial3D\""):
			inside = true
			body = ""
		elif line.begins_with("["):
			if inside:
				bodies.append(body)
			inside = false
		elif inside and not line.strip_edges().is_empty():
			var resolved: String = line
			for id: String in paths:
				resolved = resolved.replace("ExtResource(\"%s\")" % id, str(paths[id]))
			body += resolved + "\n"
	if inside:
		bodies.append(body)
	return bodies


## Every `[node ...]` block in a scene whose `script` resolves to `script_path`, body only. The
## whole block is buffered and judged at its end rather than from the moment the `script` line
## goes by, because a property authored ABOVE the script line is legal .tscn and would be missed.
func _blocks_with_script(scene: String, script_path: String) -> Array[String]:
	var paths: Dictionary = _ext_paths(scene)
	var out: Array[String] = []
	var body: String = ""
	var wanted: bool = false
	for line: String in _read(scene).split("\n") + PackedStringArray(["[end]"]):
		if line.begins_with("["):
			if wanted:
				out.append(body)
			wanted = false
			body = ""
			continue
		if line.begins_with("script = ExtResource("):
			wanted = str(paths.get(_quoted(line, "ExtResource(\""), "")) == script_path
		body += line + "\n"
	return out


func _ext_paths(scene: String) -> Dictionary:
	var paths: Dictionary = {}
	for line: String in _read(scene).split("\n"):
		if line.begins_with("[ext_resource "):
			paths[_quoted(line, "id=\"")] = _quoted(line, "path=\"")
	return paths


func _quoted(line: String, after: String) -> String:
	if not line.contains(after):
		return ""
	return line.split(after)[1].split("\"")[0]


func _area_scenes() -> Array[String]:
	var out: Array[String] = []
	for id: StringName in Fixtures.area_ids():
		out.append("res://scenes/areas/%s/%s.tscn" % [id, id])
	return out


func _import_files(root: String) -> Array[String]:
	var out: Array[String] = []
	for file: String in DirAccess.get_files_at(root):
		if file.ends_with(".import"):
			out.append(root.path_join(file))
	for folder: String in DirAccess.get_directories_at(root):
		if not folder.begins_with("."):
			out.append_array(_import_files(root.path_join(folder)))
	return out


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)
