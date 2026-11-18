class_name PartyScreen
extends MenuScreen
## The party screen (C10.20): who fights, who waits, and how far each has grown.
##
## IN PLAIN WORDS: the party key (P) opens it. Two lists, the members in the fight and those
## waiting in reserve. Each row reads "Name  Lv 3  Exp 40/90  HP 25/30", with the form a member
## holds after it; a member out in the field gives its own hp, its gear counted (C10.36a). Press one member, then another: they trade places, across the lines or within
## one. A member in the fight, picked, can also be sent to wait, unless it is the last one there,
## so the fighting line is never empty.
##
## OWNS: the rows and what pressing them does.
## MUST NOT: keep its own line-up (`Party.arrange` does), or change a member's hp or level.

const SCREEN_ID: StringName = &"party"
const TITLE_KEY: String = "ui.party.title"
const HINT_KEY: String = "ui.party.hint"
const MEMBER_KEY: String = "ui.party.member"
const FORM_KEY: String = "ui.party.form"
const PICKED_KEY: String = "ui.party.picked"
const ACTIVE_KEY: String = "ui.party.active"
const RESERVE_KEY: String = "ui.party.reserve"
const BENCH_KEY: String = "ui.party.bench"

## Every fighter that could join, and the field bodies of those out now (for their form).
var roster: Array[CombatantDef] = []
var bodies: Dictionary[StringName, Node] = {}
## The member pressed first, waiting for the second; empty for none.
var picked: StringName = &""


func _init() -> void:
	screen_id = SCREEN_ID
	pauses_world = true
	closes_on_cancel = true
	title_key = TITLE_KEY
	hint_key = HINT_KEY
	opaque = false


## A screen for `members`, with the bodies of those in the field by id.
static func for_roster(members: Array[CombatantDef], field: Dictionary[StringName, Node]) -> PartyScreen:
	var screen := PartyScreen.new()
	screen.roster = members
	screen.bodies = field
	return screen


## One member's line: name, level, experience to the next level, hp, and the form `body` holds.
## A member out in the field reads its hp from its body, whose maximum counts its gear (C10.36a).
static func member_line(def: CombatantDef, body: Node) -> String:
	var id: StringName = def.combatant_id
	var level: int = Party.level_of(id)
	var stats: Dictionary[StringName, float] = Party.at_level(def).base_stats
	var most: int = roundi(stats[&"max_hp"]) if stats.has(&"max_hp") else 0
	var hp_flag := StringName(Vitals.PREFIX + String(id) + "/hp")
	var hp: int = Flags.get_int(hp_flag) if Flags.has_flag(hp_flag) else most
	var vitals: Vitals = Vitals.of(body) if body != null and is_instance_valid(body) else null
	if vitals != null:
		most = vitals.maximum(&"hp")
		hp = vitals.current(&"hp")
	var line: String = TranslationServer.translate(MEMBER_KEY).format({"name": TranslationServer.translate(def.name_key),
		"level": level, "exp": Party.experience_of(id),
		"next": def.level_curve.exp_for(level + 1) if def.level_curve != null else 0, "hp": hp, "max": most})
	var form: String = LookSwap.form_name_key(body) if body != null and is_instance_valid(body) else ""
	if form != "":
		line = TranslationServer.translate(FORM_KEY).format({"line": line, "form": TranslationServer.translate(form)})
	return line


## `a` and `b` trade places: across the two lines, or within one.
func swap(a: StringName, b: StringName) -> void:
	var fighting: Array[StringName] = _ids(Party.active(roster))
	var waiting: Array[StringName] = _ids(Party.reserve(roster))
	for line: Array[StringName] in [fighting, waiting]:
		var at_a: int = line.find(a)
		var at_b: int = line.find(b)
		if at_a >= 0:
			line[at_a] = b
		if at_b >= 0:
			line[at_b] = a
	Party.arrange(fighting, waiting)


func _fill() -> void:
	var fighting: Array[CombatantDef] = Party.active(roster)
	add_note(tr(ACTIVE_KEY))
	for def: CombatantDef in fighting:
		_row(def)
	if picked != &"" and fighting.size() > 1 and _ids(fighting).has(picked):
		add_row(tr(BENCH_KEY), _bench)
	add_note(tr(RESERVE_KEY))
	for def: CombatantDef in Party.reserve(roster):
		_row(def)


func _row(def: CombatantDef) -> void:
	var body: Node = bodies[def.combatant_id] if bodies.has(def.combatant_id) else null
	var text: String = member_line(def, body)
	if def.combatant_id == picked:
		text = tr(PICKED_KEY).format({"line": text})
	add_row(text, _on_member.bind(def.combatant_id))


func _on_member(id: StringName) -> void:
	if picked == &"" or picked == id:
		picked = id if picked == &"" else &""
	else:
		swap(picked, id)
		picked = &""
	refresh()


# The picked member leaves the fight for the reserve.
func _bench() -> void:
	var fighting: Array[StringName] = _ids(Party.active(roster))
	var waiting: Array[StringName] = _ids(Party.reserve(roster))
	fighting.erase(picked)
	waiting.append(picked)
	Party.arrange(fighting, waiting)
	picked = &""
	refresh()


static func _ids(defs: Array[CombatantDef]) -> Array[StringName]:
	var out: Array[StringName] = []
	for def: CombatantDef in defs:
		out.append(def.combatant_id)
	return out
