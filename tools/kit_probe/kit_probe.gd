extends Node
## Tries a power kit in the engine: builds a hero wearing it and a foe in front, presses every
## quick slot in every style, and prints what happened. See `docs/POWER_COOKBOOK.md` § 6.
##
## IN PLAIN WORDS: a kit can pass `check_content` and still not do what you meant. This scene
## shows what it really does: for each slot, whether the press was taken (or why it was
## refused), the damage the foe took, and every kit gauge after it. Gauges are filled before
## each press, so a cost never hides a power. A style cycle (a form power with a `cycle`) is
## pressed between rounds, so each style's own slots are tried.
##
## RUN: godot --headless res://tools/kit_probe/kit_probe.tscn -- --kit=res://data/powers/<kit>.tres
##      godot --headless res://tools/kit_probe/kit_probe.tscn -- --cookbook
## `--cookbook` tries the example kit written in `docs/POWER_COOKBOOK.md` itself.
##
## OWNS: a throwaway arena and a report. It saves nothing and changes no file but its own
## scratch copy of the cookbook kit, which it deletes.
## MUST NOT: be loaded by the game or the suite.

const COOKBOOK: String = "res://docs/POWER_COOKBOOK.md"
const SCRATCH: String = "user://kit_probe_cookbook.tres"
## Physics frames to wait after each press: long enough for a barrage or a finisher to land.
const WAIT: int = 150

var _hero: PlayerController
var _fighter: ActionFighter
var _me: Combatant
var _foe: Combatant


func _ready() -> void:
	CombatActions.install()
	var kit: PowerKit = _kit()
	if kit == null:
		print("KIT PROBE: no kit. Pass --kit=res://... or --cookbook")
		get_tree().quit(1)
		return
	print("KIT %s  problems: %s" % [kit.kit_id, kit.problems("probe")])
	_arena(kit)
	await _frames(5)
	await _rounds(kit)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	get_tree().quit()


func _kit() -> PowerKit:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--kit="):
			return load(arg.trim_prefix("--kit=")) as PowerKit
		if arg == "--cookbook":
			return _cookbook()
	return null


# Cuts the example kit out of the cookbook, between its two markers, and loads it.
func _cookbook() -> PowerKit:
	var text: String = FileAccess.get_file_as_string(COOKBOOK)
	var parts: PackedStringArray = text.split("<!-- example-kit:start -->")
	if parts.size() < 2:
		return null
	var block: String = parts[1].split("<!-- example-kit:end -->")[0].strip_edges()
	block = block.trim_prefix("```").trim_suffix("```").strip_edges()
	var out := FileAccess.open(SCRATCH, FileAccess.WRITE)
	out.store_string(block + "\n")
	out.close()
	return ResourceLoader.load(SCRATCH, "", ResourceLoader.CACHE_MODE_IGNORE) as PowerKit


# A floor, the hero wearing `kit`, and a foe with plenty of hp 1.5 m in front of it.
func _arena(kit: PowerKit) -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	ground.add_child(shape)
	add_child(ground)
	var def := CombatantDef.new()
	def.combatant_id = &"probe_hero"
	def.faction = &"player"
	def.base_stats = {&"max_hp": 400.0, &"attack": 10.0, &"defence": 5.0}
	def.level_curve = LevelCurve.new()
	def.power_kit = kit
	var loadout := ActionLoadout.new()
	loadout.fighter = def
	loadout.moves = MoveSet.new()
	_hero = (load("res://scenes/characters/player.tscn") as PackedScene).instantiate() as PlayerController
	add_child(_hero)
	_fighter = ActionHost.equip(_hero, loadout)
	_me = Combatant.of(_hero)
	_foe = _dummy(_hero.global_position + Vector3(0, 0, -1.5))


func _dummy(at: Vector3) -> Combatant:
	var body := CharacterBody3D.new()
	body.position = at
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var foe := Combatant.new()
	foe.combatant_id = &"probe_foe"
	foe.faction = &"enemy"
	foe.base_stats = {&"max_hp": 100000.0, &"attack": 10.0, &"defence": 5.0}
	body.add_child(foe)
	var hurt := Hurtbox.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	shape.shape = capsule
	shape.position = Vector3(0, 0.8, 0)
	hurt.add_child(shape)
	body.add_child(hurt)
	add_child(body)
	return foe


# One round per style of the kit's first cycle (one round with none): enter the style, then
# press every other slot.
func _rounds(kit: PowerKit) -> void:
	var cycle: Power = _cycle_power(kit)
	var styles: int = (cycle.mechanism as FormMechanism).cycle.size() if cycle != null else 1
	for round: int in styles:
		if cycle != null:
			await _frames(roundi(cycle.cooldown * 60.0) + 2)
			print("\n== style switch: %s" % _fighter.press_slot(PowerSlots.powers(_me).find(cycle)))
		var slotted: Array[Power] = PowerSlots.powers(_me)
		for slot: int in slotted.size():
			if slotted[slot] != cycle:
				await _press(slot, slotted[slot])


func _press(slot: int, power: Power) -> void:
	await _home()
	_fill()
	var before: int = _hp()
	var why: PowerUse.Reason = PowerUse.refusal(_me, power)
	var taken: bool = _fighter.press_slot(slot)
	await _frames(WAIT)
	print("slot %d %s: %s, foe took %d, %s" % [slot + 1, power.power_id,
		"used" if taken else "REFUSED (%s)" % PowerUse.Reason.keys()[why], before - _hp(), _gauges()])


# Back to the start, facing the foe, idle: a lunge may have carried the hero past it.
func _home() -> void:
	while _fighter.timeline.busy():
		await get_tree().physics_frame
	_hero.global_position = Vector3.ZERO
	_hero.velocity = Vector3.ZERO
	_fighter.facing = Vector3.FORWARD
	await _frames(2)


func _cycle_power(kit: PowerKit) -> Power:
	for power: Power in kit.powers:
		var form: FormMechanism = power.mechanism as FormMechanism if power != null else null
		if form != null and not form.cycle.is_empty():
			return power
	return null


# Every kit gauge to its top, so a cost never hides what a power does.
func _fill() -> void:
	var vitals: Vitals = Vitals.of(_hero)
	for rule: GaugeRule in _rules():
		vitals.change(rule.pool, vitals.maximum(rule.pool))


func _gauges() -> String:
	var vitals: Vitals = Vitals.of(_hero)
	var out: PackedStringArray = []
	for rule: GaugeRule in _rules():
		out.append("%s %d/%d" % [rule.pool, vitals.current(rule.pool), vitals.maximum(rule.pool)])
	return ", ".join(out) if not out.is_empty() else "no gauges"


func _rules() -> Array[GaugeRule]:
	var out: Array[GaugeRule] = []
	for kit: PowerKit in PowerSet.of(_hero).kits():
		for rule: GaugeRule in kit.gauges:
			if rule != null:
				out.append(rule)
	return out


func _hp() -> int:
	return Vitals.of(_foe.get_parent()).current(&"hp")


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
