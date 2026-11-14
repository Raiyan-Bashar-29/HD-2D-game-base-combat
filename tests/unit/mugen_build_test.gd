extends TestCase
## The starter files for a converted character (C9.9e): from a choices file, the converter's
## moves and an unpacked sprite folder, `MugenStarter` writes a kit, a loadout and an art file
## that load and point at each other. Also: a move's sounds come out of the converter with
## their times, and a field enemy shows its definition's art.
##
## OWNS: assertions about `MugenKit`, `MugenArt`, `MugenStarter`, `MugenIni.note`, the `sounds`
## of `MugenFormula.numbers`, and `ActionEnemy`'s art.
## MUST NOT: name a real character, or write outside this run's scratch folder.

const SWING: Dictionary = {"state": 200, "anim": 200, "startup": 0.1, "active": 0.05, "recovery": 0.15,
	"chain_after": 0.05, "iframes_from": 0.0, "iframes_to": 0.0, "power": 8.0, "hits": 1, "poise": 2,
	"knockback": 0.4, "travel_speed": 2.4, "hitbox_size": [1.0, 0.4, 20.0], "hitbox_offset": [0.0, 0.6, -10.0],
	"sounds": [{"at": 0.5, "file": "sounds/1_0.wav"}, {"at": 0.0, "file": "sounds/1_0.wav"},
		{"at": 0.5, "file": "sounds/1_0.wav"}, {"at": 0.2, "file": "sounds/9_9.wav"}]}
const BLAST: Dictionary = {"state": 300, "anim": 300, "startup": 0.2, "active": 0.1, "recovery": 0.3,
	"iframes_from": 0.1, "iframes_to": 0.3, "power": 20.0, "hits": 3, "travel_speed": 0.0, "meter": 600}
const CHOICES: Dictionary = {"name": "fx", "chain": [200], "max_box": 4.0,
	"dodge": {"active": 0.3, "iframes_to": 0.3, "travel_speed": 6.0},
	"gauge": {"pool": "zeal", "max": 50, "start": 5, "on_hit_dealt": 4, "on_hit_taken": 2},
	"specials": [{"state": 300, "id": "blast", "cooldown": 2.0}],
	"stances": [{"id": "calm", "chain": [200], "tint": [0.5, 0.25, 1.0], "stats": {"attack": 1.5},
		"specials": [{"state": 300, "id": "calm_blast", "cost": 7}, {"state": 999, "id": "none"}]}],
	"stats": {"attack": 12, "max_hp": 60}, "growth": {"attack": 2}, "attack_tags": ["blade"],
	"anims": {"300": 301}}

var _dir: String


func run() -> void:
	plan(12)
	_dir = RunScratch.path("mugen_build")
	_folder()
	var result: Dictionary = MugenStarter.write(_dir.path_join("choices.json"))
	_files(result)
	_kit(load(_dir.path_join("out/kit.tres")) as PowerKit)
	_fighter(load(_dir.path_join("out/loadout.tres")) as ActionLoadout)
	_art(load(_dir.path_join("out/art.tres")) as MemberArt)
	_small_things()
	_enemy()


# The converter's output, an unpacked sprite folder and the choices, in the scratch folder.
func _folder() -> void:
	var art: String = _dir.path_join("art")
	DirAccess.make_dir_recursive_absolute(art.path_join("sounds"))
	for name: String in ["sheet.png", "a200.png", "a301.png"]:
		Image.create(8, 4, false, Image.FORMAT_RGBA8).save_png(art.path_join(name))
	AudioStreamWAV.new().save_to_wav(art.path_join("sounds/1_0.wav"))
	var layout := SpriteSheetLayout.new()
	layout.cell_size = Vector2i(2, 2)
	ResourceSaver.save(layout, art.path_join("layout.tres"))
	var texts: Dictionary = {"moves.json": {"moves": [SWING, BLAST]},
		"art/sprites.json": {"pixel_size": 0.03, "sheet": {"file": "sheet.png", "layout": "layout.tres", "ground_offset": -0.1},
			"strips": {"200": {"file": "a200.png", "frames": 4, "feet": [1, 3], "seconds": 0.3},
				"301": {"file": "a301.png", "frames": 2, "feet": [2, 3], "seconds": 0.6}}},
		"choices.json": CHOICES.merged({"moves": _dir.path_join("moves.json"), "sprites": art,
			"out": {"kit": _dir.path_join("out/kit.tres"), "loadout": _dir.path_join("out/loadout.tres"),
				"art": _dir.path_join("out/art.tres"), "strings": _dir.path_join("out/strings.txt")}})}
	for name: String in texts:
		var file: FileAccess = FileAccess.open(_dir.path_join(name), FileAccess.WRITE)
		file.store_string(JSON.stringify(texts[name]))
		file.close()


func _files(result: Dictionary) -> void:
	var problems: PackedStringArray = result["problems"]
	equal("four files are written, and the problems are the state not converted (twice) and the pictures not imported",
		[(result["written"] as PackedStringArray).size(), problems.size(), problems[0],
		"\n".join(problems).count("not imported yet")],
		[4, 5, "state 999 is not in moves.json", 3])
	var keys: PackedStringArray = result["strings"]
	equal("every name it used is listed for the CSV, once",
		[keys.size(), keys.has("combat.kit.fx.name"), keys.has("combat.form.fx_calm.name"),
		keys.has("combat.power.fx_blast.desc"), keys.has("combat.member.fx.name"),
		FileAccess.get_file_as_string(_dir.path_join("out/strings.txt")).count("\n")],
		[12, true, true, true, true, 12])
	equal("a missing choices file writes nothing and says so",
		[(MugenStarter.write(_dir.path_join("none.json"))["written"] as PackedStringArray).size(),
		(MugenStarter.write(_dir.path_join("none.json"))["problems"] as PackedStringArray).size()], [0, 1])


func _kit(kit: PowerKit) -> void:
	var ids: Array = []
	for power: Power in kit.powers:
		ids.append(power.power_id)
	equal("the kit has the stance power, each stance's specials, then the specials of every stance",
		[kit.kit_id, ids], [&"kit/fx", [&"power/fx_stance", &"power/fx_calm_blast", &"power/fx_none", &"power/fx_blast"]])
	var blast: Power = kit.powers[3]
	var held: Power = kit.powers[1]
	equal("a special's move hits and its skill pays: the meter's share of the gauge, or the cost written",
		[blast.move.id, blast.move.hits, blast.skill.cost_pool, blast.skill.cost, blast.skill.target, blast.cooldown,
		held.skill.cost, held.requires_statuses, blast.requires_statuses.size()],
		[&"move/fx_300", 3, &"zeal", 10, FactionTable.Target.SELF, 2.0, 7, [&"status/form_fx_calm"], 0])
	var gauge: Array = []
	for bonus: StatModifier in kit.stat_bonuses:
		gauge.append([bonus.stat, bonus.value])
	equal("the gauge is two stat bonuses and a rule",
		[gauge, kit.gauges[0].pool, kit.gauges[0].on_hit_dealt, kit.gauges[0].on_hit_taken],
		[[[&"max_zeal", 50.0], [&"start_zeal", 5.0]], &"zeal", 4.0, 2.0])
	var form: FormMechanism = (kit.powers[0].mechanism as FormMechanism).cycle[0]
	equal("a stance is a form with its status, its stat change, its chain and its tint",
		[form.status.id, form.status.tags, form.status.modifiers[0].stat, form.status.modifiers[0].op,
		form.status.modifiers[0].value, form.attack_chain[0].id, form.look.tint, form.name_key],
		[&"status/form_fx_calm", [&"form"], &"attack", StatModifier.Op.MULTIPLY, 1.5, &"move/fx_200",
		Color(0.5, 0.25, 1.0), "combat.form.fx_calm.name"])


func _fighter(loadout: ActionLoadout) -> void:
	var swing: ActionMove = loadout.moves.attack_chain[0]
	equal("the loadout has the fighter, the chain with its hitbox kept inside the limit, and the dodge",
		[loadout.fighter.combatant_id, loadout.fighter.base_stats, loadout.fighter.level_curve.growth,
		loadout.fighter.attack_tags, swing.id, swing.hitbox_size, swing.hitbox_offset,
		loadout.moves.dodge.iframes_to, loadout.moves.dodge.travel_speed],
		[&"fx", {&"attack": 12.0, &"max_hp": 60.0}, {&"attack": 2.0}, [&"blade"], &"move/fx_200",
		Vector3(1.0, 0.4, 4.0), Vector3(0.0, 0.2, -2.0), 0.3, 6.0])
	equal("the loadout points at the kit and the art by path, and holds no copy",
		[loadout.fighter.power_kit.resource_path.get_file(), loadout.fighter.art.resource_path.get_file(),
		FileAccess.get_file_as_string(_dir.path_join("out/loadout.tres")).contains("kit/fx")],
		["kit.tres", "art.tres", false])


func _art(art: MemberArt) -> void:
	var swing: MoveArt = art.moves[&"move/fx_200"]
	var blast: MoveArt = art.moves[&"move/fx_300"]
	equal("the art has the sheet and a strip per move; a sound plays once per time, in order, if its file is there",
		[art.sheet != null, art.layout.cell_size, art.pixel_size, art.ground_offset, art.moves.size(),
		swing.frames, swing.feet, swing.seconds, swing.sounds.size(), swing.sound_at, blast.frames, blast.seconds],
		[true, Vector2i(2, 2), 0.03, -0.1, 2, 4, Vector2i(1, 3), 0.3, 2, [0.0, 0.5], 2, 0.6])


func _small_things() -> void:
	var out: Dictionary = {"problems": PackedStringArray()}
	MugenIni.note(out, "problems", "one")
	MugenIni.note(out, "problems", "one")
	MugenIni.note(out, "fresh", "two")
	var made: Dictionary = MugenFormula.numbers({"state": 5, "anim": 5, "length": 30, "hits": [], "invincible": [],
		"armour": [], "speeds": [], "spawns": [], "chains": [], "pause": 0, "skipped": {}, "needs": PackedStringArray(),
		"sounds": [{"tick": 12, "group": 3, "index": 4}]}, {"metres_per_pixel": 0.02, "power_scale": 0.4, "depth": 1.0})
	equal("a note is kept once, and a move's sounds come out with their seconds and file",
		[out["problems"], out["fresh"], made["sounds"]],
		[PackedStringArray(["one"]), PackedStringArray(["two"]), [{"at": 0.2, "file": "sounds/3_4.wav"}]])


func _enemy() -> void:
	var art := MemberArt.new()
	art.sheet = ImageTexture.create_from_image(Image.create(8, 4, false, Image.FORMAT_RGBA8))
	art.layout = SpriteSheetLayout.new()
	art.layout.cell_size = Vector2i(2, 2)
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_drawn_foe"
	def.base_stats = {&"max_hp": 5.0}
	def.art = art
	var foe := build("res://scenes/objects/action_enemy.tscn") as ActionEnemy
	foe.fighter = def
	foe.brain = ActionBrain.new()
	attach(foe)
	var shown: MemberArt = null
	for child: Node in foe.get_children():
		if child is ArtSwap:
			(child as ArtSwap).watch()
			shown = (child as ArtSwap).current
	equal("a field enemy shows its definition's art", [shown, (foe.get_node(^"Visual") as CharacterVisual).sprite.texture],
		[art, art.sheet])
	foe.free()
