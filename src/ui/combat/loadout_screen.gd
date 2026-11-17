class_name LoadoutScreen
extends MenuScreen
## The passive loadout screen (C9.7): choose which learned passives a party member holds.
## See `docs/PASSIVES.md` § The loadout.
##
## IN PLAIN WORDS: one member at a time. The first line is the member's name and how much
## skill cost is used out of the budget. Then:
##   - CHOSEN: press one to take it out.
##   - LEARNED: press one to choose it. One that cannot be chosen is greyed out with the reason
##     (over the budget, or the same kind is already held).
##   - LEARNING FROM GEAR: what the worn pieces are teaching, as "won fights / fights needed".
##   - FROM GEAR AND POWERS: passives held without choosing, so the player sees the whole set.
## The line at the bottom describes the row under the cursor. With more than one member, a row
## at the top steps to the next.
##
## OWNS: the rows and what pressing one does.
## MUST NOT: keep its own list of what is chosen or decide a refusal (`PassiveLoadout` does).

const SCREEN_ID: StringName = &"loadout"
const TITLE_KEY: String = "combat.loadout.title"
const HINT_KEY: String = "combat.loadout.hint"
const BUDGET_KEY: String = "combat.loadout.budget"
const NEXT_KEY: String = "combat.loadout.next_member"
const CHOSEN_KEY: String = "combat.loadout.chosen"
const LEARNED_KEY: String = "combat.loadout.learned"
const NONE_CHOSEN_KEY: String = "combat.loadout.none_chosen"
const NONE_LEARNED_KEY: String = "combat.loadout.none_learned"
const ROW_KEY: String = "combat.loadout.row"
const REFUSED_KEY: String = "combat.loadout.row_refused"
const LESSONS_KEY: String = "combat.loadout.lessons"
const LESSON_KEY: String = "combat.loadout.lesson"
const GIVEN_KEY: String = "combat.loadout.given"

## The members' bodies and, at the same index, their definitions.
var bodies: Array[Node] = []
var defs: Array[CombatantDef] = []
## Which member is shown.
var index: int = 0
## The line that describes the row under the cursor.
var detail: Label = null


func _init() -> void:
	screen_id = SCREEN_ID
	pauses_world = true
	closes_on_cancel = true
	title_key = TITLE_KEY
	hint_key = HINT_KEY
	opaque = false


## A screen for these members. `member_defs[i]` is the definition of `member_bodies[i]`.
static func for_members(member_bodies: Array[Node], member_defs: Array[CombatantDef]) -> LoadoutScreen:
	var screen := LoadoutScreen.new()
	screen.bodies = member_bodies
	screen.defs = member_defs
	return screen


func _fill() -> void:
	if index >= bodies.size() or index >= defs.size() or not is_instance_valid(bodies[index]):
		return
	var def: CombatantDef = defs[index]
	var who: StringName = def.combatant_id
	add_note(tr(BUDGET_KEY).format({"name": tr(def.name_key),
		"spent": PassiveLoadout.spent(who), "budget": PassiveLoadout.budget(def)}))
	if bodies.size() > 1:
		add_row(tr(NEXT_KEY), _on_next)
	_fill_chosen(who)
	_fill_learned(def)
	_fill_lessons(who)
	_fill_given()
	detail = add_note("")


func _fill_chosen(who: StringName) -> void:
	add_note(tr(CHOSEN_KEY))
	var chosen: Array[StringName] = PassiveLoadout.chosen(who)
	if chosen.is_empty():
		add_note(tr(NONE_CHOSEN_KEY))
	for passive_id: StringName in chosen:
		var passive: PassiveSkill = PassiveDb.passive(passive_id)
		if passive != null:
			_describe(add_row(_label(passive), _on_drop.bind(passive_id)), passive)


func _fill_learned(def: CombatantDef) -> void:
	add_note(tr(LEARNED_KEY))
	var chosen: Array[StringName] = PassiveLoadout.chosen(def.combatant_id)
	var shown: int = 0
	for passive_id: StringName in PassiveLoadout.known(def.combatant_id):
		var passive: PassiveSkill = PassiveDb.passive(passive_id)
		if passive == null or chosen.has(passive_id):
			continue
		shown += 1
		var why: PassiveLoadout.Refusal = PassiveLoadout.refusal(bodies[index], def, passive_id)
		var row: Button = add_row(_label(passive), _on_choose.bind(passive_id))
		if why != PassiveLoadout.Refusal.NONE:
			row.disabled = true
			row.text = tr(REFUSED_KEY).format({"label": row.text,
				"reason": tr(PassiveLoadout.refusal_key(why))})
		_describe(row, passive)
	if shown == 0:
		add_note(tr(NONE_LEARNED_KEY))


## What the worn pieces are teaching and have not taught yet.
func _fill_lessons(who: StringName) -> void:
	var gear: GearSet = GearSet.of(bodies[index])
	var lines: Array[String] = []
	for item_id: StringName in (gear.worn_ids() if gear != null else []):
		var piece: GearDefinition = GearDb.for_item(item_id)
		for lesson: PassiveLesson in (piece.teaches if piece != null else []):
			if lesson == null or lesson.passive == null or PassiveLoadout.knows(who, lesson.passive.id):
				continue
			lines.append(tr(LESSON_KEY).format({"name": tr(lesson.passive.name_key),
				"count": PassiveLoadout.progress(who, item_id, lesson.passive.id),
				"fights": lesson.fights}))
	_section(LESSONS_KEY, lines)


## What the member holds without choosing: from a kit, a worn piece, a form.
func _fill_given() -> void:
	var held: PassiveSet = PassiveSet.of(bodies[index])
	var lines: Array[String] = []
	for source: StringName in (held.sources() if held != null else []):
		if source == PassiveLoadout.SOURCE:
			continue
		for given: PassiveSkill in held.given_by(source):
			lines.append(tr(given.name_key))
	_section(GIVEN_KEY, lines)


func _section(heading_key: String, lines: Array[String]) -> void:
	if lines.is_empty():
		return
	add_note(tr(heading_key))
	for line: String in lines:
		add_note(line)


func _label(passive: PassiveSkill) -> String:
	return tr(ROW_KEY).format({"name": tr(passive.name_key), "cost": passive.cost})


## The bottom line shows `passive`'s description while `row` has the cursor.
func _describe(row: Button, passive: PassiveSkill) -> void:
	row.focus_mode = Control.FOCUS_ALL
	row.focus_entered.connect(_on_focused.bind(passive.desc_key))


func _on_focused(desc_key: String) -> void:
	if detail != null and is_instance_valid(detail):
		detail.text = tr(desc_key) if desc_key != "" else ""


func _on_choose(passive_id: StringName) -> void:
	if PassiveLoadout.choose(bodies[index], defs[index], passive_id):
		refresh()


func _on_drop(passive_id: StringName) -> void:
	if PassiveLoadout.drop(bodies[index], passive_id):
		refresh()


func _on_next() -> void:
	index = (index + 1) % bodies.size()
	refresh()
