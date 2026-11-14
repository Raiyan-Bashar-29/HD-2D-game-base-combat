extends TestCase
## The M.U.G.E.N converter (C9.9a): a made-up character, written to this run's scratch folder,
## is read and turned into moves by the formula in `MugenFormula`.
##
## OWNS: assertions about `MugenIni`, `MugenAir`, `MugenTriggers`, `MugenState`, `MugenFormula`
## and `MugenCharacter`.
## MUST NOT: name a real character, or read a file from outside the scratch folder.

const DEF: String = "[Info]\nname = \"Fixture Fighter\" ; a comment\nauthor = \"nobody\"\n" \
	+ "[Files]\ncmd = Fixture.cmd\ncns = Fixture.cns\nst = Fixture.cns\nanim = fixture.air\n"
const AIR: String = "[Begin Action 0]\nClsn2Default: 1\n Clsn2[0] = -10,-50,10,0\n0,0, 0,0, 10\n" \
	+ "[Begin Action 200]\nClsn2Default: 1\n Clsn2[0] = -10,-50,10,0\n200,0, 0,0, 6\n" \
	+ "Clsn1: 1\n Clsn1[0] = 10,-40,40,-20\n200,1, 0,0, 3\n200,2, 0,0, 9\n" \
	+ "[Begin Action 700]\n700,0, 0,0, 12\nClsn2: 1\n Clsn2[0] = -10,-50,10,0\n700,1, 0,0, 6\n" \
	+ "[Begin Action 900]\nClsn1: 1\n Clsn1[0] = 0,-10,20,0\n900,0, 0,0, 4\n900,1, 0,0, 4\n"
const CNS: String = "[Statedef 0]\ntype = S\nanim = 0\n" \
	+ "[Statedef 200]\nmovetype = A\nanim = 200\n" \
	+ "[State 200, hit]\ntype = HitDef\ntrigger1 = AnimElem = 2\ndamage = 20, 5\n" \
	+ "animtype = Medium\nground.velocity = -3, 0\n" \
	+ "[State 200, go]\ntype = VelSet\ntrigger1 = time = 0\nx = 2\n" \
	+ "[State 200, next]\ntype = ChangeState\ntriggerall = time >= 12\n" \
	+ "trigger1 = command = \"a\"\nvalue = 201\n" \
	+ "[State 200, glow]\ntype = BGPalFX\ntrigger1 = 1\n" \
	+ "[State 200, end]\ntype = ChangeState\ntrigger1 = AnimTime = 0\nvalue = 0\n" \
	+ "[Statedef 700]\nmovetype = I\nanim = 700\nvelset = 5, 0\n" \
	+ "[State 700, end]\ntype = ChangeState\ntrigger1 = AnimTime = 0\nvalue = 0\n" \
	+ "[Statedef 800]\nmovetype = A\nanim = 0\n" \
	+ "[State 800, send]\ntype = Helper\ntrigger1 = time = 3\nstateno = 900\n" \
	+ "[State 800, safe]\ntype = NotHitBy\ntrigger1 = time = [0,4]\nvalue = SCA\ntime = 1\n" \
	+ "[State 800, firm]\ntype = HitOverride\ntrigger1 = time = 2\ntime = 4\n" \
	+ "[State 800, end]\ntype = ChangeState\ntrigger1 = time = 10\nvalue = 0\n" \
	+ "[Statedef 900]\nanim = 900\n" \
	+ "[State 900, hit]\ntype = HitDef\ntrigger1 = TimeMod = 4, 0\ndamage = 10\n"
const CMD: String = "[Command]\nname = \"a\"\ncommand = ~D, F, a\n[Statedef -1]\n" \
	+ "[State -1, a]\ntype = ChangeState\nvalue = 200\ntriggerall = power >= 500\n" \
	+ "trigger1 = command = \"a\"\n"

var _dir: String


func run() -> void:
	plan(9)
	_dir = RunScratch.path("mugen_fixture")
	DirAccess.make_dir_recursive_absolute(_dir)
	for name: String in ["Fixture.def", "Fixture.cmd", "Fixture.cns", "fixture.air"]:
		var file: FileAccess = FileAccess.open(_dir.path_join(name), FileAccess.WRITE)
		file.store_string(DictRead.get_string({"def": DEF, "cmd": CMD, "cns": CNS, "air": AIR}, name.get_extension()))
		file.close()
	_reading()
	_converting()


func _reading() -> void:
	var info: Dictionary = MugenIni.parse(DEF)[0]
	equal("a section keeps its keys in lower case, drops a comment and keeps a quoted value",
		[info["name"], MugenIni.value(info, "name"), MugenIni.value(info, "none", "x")],
		["info", "\"Fixture Fighter\"", "x"])
	var swing: Array = MugenAir.parse(AIR)[200]
	equal("an animation gives its ticks, its hurting span and its box",
		[MugenAir.ticks_before(swing, 2), MugenAir.length(swing), MugenAir.spans(swing, "hit", true),
		MugenAir.bounds(swing, 1, "hit"), MugenAir.frame_at(swing, 8)],
		[6, 18, [Vector2i(6, 9)], Rect2(10, -40, 30, 20), 1])
	equal("a frame with no body box is an untouchable span, and a default box stays",
		[MugenAir.spans(MugenAir.parse(AIR)[700] as Array, "body", false), MugenAir.spans(swing, "body", false)],
		[[Vector2i(0, 12)], []])
	var waits: Dictionary = MugenTriggers.span(MugenIni.parse(
		"[State 1]\ntriggerall = time >= 12\ntrigger1 = command = \"a\"\ntrigger2 = MoveHit\n")[0], swing, 18)
	equal("a trigger gives its ticks, and what it cannot know is listed",
		[waits["from"], waits["to"], waits["on_hit"], waits["needs"]],
		[12, 18, true, PackedStringArray(["command=\"a\""])])


func _converting() -> void:
	var result: Dictionary = MugenCharacter.convert(_dir.path_join("Fixture.def"), {"height": 1.0, "prefix": "fx"})
	var moves: Dictionary = {}
	for made: Dictionary in result["moves"]:
		moves[made["state"]] = made
	equal("the attack, the dodge and the sender are kept; the idle and the sent state are not",
		[result["name"], result["author"], moves.keys(), result["problems"]],
		["Fixture Fighter", "nobody", [200, 700, 800], PackedStringArray()])
	var swing: Dictionary = moves.get(200, {})
	equal("an attack's times, power, weight, push and chain follow the formula",
		_round([swing["startup"], swing["active"], swing["recovery"], swing["power"], swing["poise"],
		swing["knockback"], swing["chain_after"], swing["travel_speed"]]) + [swing["chains_to"],
		swing["button"], swing["meter"], _round(swing["hitbox_size"] as Array),
		_round(swing["hitbox_offset"] as Array), swing["notes"]],
		[0.1, 0.05, 0.15, 8.0, 2.0, 0.4, 0.05, 2.4, 201, "~D, F, a (a)", 500, [1.0, 0.4, 0.6],
		[0.0, 0.6, -0.5], PackedStringArray(["not converted: bgpalfx x1"])])
	var roll: Dictionary = moves.get(700, {})
	equal("a dodge is its untouchable frames and its speed",
		_round([roll["iframes_from"], roll["iframes_to"], roll["travel_speed"], roll["hits"]]),
		[0.0, 0.2, 6.0, 0.0])
	var sender: Dictionary = moves.get(800, {})
	equal("a state that hurts through what it sends out takes those hits, and keeps its armour stretch",
		_round([sender["startup"], sender["hits"], sender["power"], sender["iframes_to"], sender["armour_from"],
		sender["armour_to"]]) + [sender["notes"]],
		[0.05, 2.0, 4.0, 0.083, 0.033, 0.1, PackedStringArray(["sends out state 900 at 0.05s"])])
	var written: PackedStringArray = MugenCharacter.write(result, _dir.path_join("out"))
	var saved: ActionMove = load(_dir.path_join("out/moves/fx_200.tres"))
	equal("the output is a report, a JSON file and one move file each, which loads as written",
		[written.size(), saved.id, snappedf(saved.startup, 0.001), saved.hits, saved.poise,
		FileAccess.get_file_as_string(_dir.path_join("out/report.md")).contains("| move/fx_700 |")],
		[5, &"move/fx_200", 0.1, 1, 2, true])


func _round(values: Array) -> Array:
	var out: Array = []
	for value: Variant in values:
		out.append(snappedf(DictRead.to_float(value), 0.001))
	return out
