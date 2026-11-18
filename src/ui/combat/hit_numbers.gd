class_name HitNumbers
extends Node
## Numbers and words over fighters in the field (C10.12). Placeholder look: `Label3D`s, no art.
##
## IN PLAIN WORDS: when a real-time fighter is hurt, the amount rises from above it for `LIFE`
## seconds of real time and fades (a critical one is bigger, with its own words), and the body
## flashes (`HitFlash`). A hit blocked whole, a miss and a dodge show their word instead, and a
## timed press shows its grade over the one who pressed. A turn-based battle has its own screen,
## so a fighter that is not real-time shows nothing here.
##
## OWNS: the floating labels and their life.
## MUST NOT: decide what landed. It only listens to the bus.

const AMOUNT_KEY: String = "ui.combat.pop.amount"
const CRITICAL_KEY: String = "ui.combat.pop.critical"
const WORD_PREFIX: String = "ui.combat.pop."
const LIFE: float = 0.8
const RISE: float = 1.5
const HEIGHT: float = 2.0
const SIZE: int = 48
const CRITICAL_SIZE: int = 72
## Metres a font pixel spans, and how far apart pops made together are stacked.
const PIXEL: float = 0.01
const STACK: float = 0.6

## The labels up now, each with its age in seconds.
var shown: Dictionary[Label3D, float] = {}


func _ready() -> void:
	Events.combatant_damaged.connect(_on_damaged)
	Events.attack_blocked.connect(_on_word.bind(&"blocked"))
	Events.attack_missed.connect(_on_word.bind(&"missed"))
	Events.attack_dodged.connect(_on_word.bind(&"dodged"))
	Events.prompt_graded.connect(_on_graded)


## The body of the real-time fighter `who` in the field, or null.
func body_of(who: StringName) -> Node3D:
	for node: Node in get_tree().get_nodes_in_group(Hurtbox.GROUP):
		var fighter: Combatant = (node as Hurtbox).fighter() if node is Hurtbox else null
		if fighter != null and fighter.combatant_id == who and fighter.real_time:
			return fighter.get_parent() as Node3D
	return null


func _process(delta: float) -> void:
	for label: Label3D in shown.keys():
		if not is_instance_valid(label):
			shown.erase(label)
			continue
		shown[label] += delta
		label.position.y += RISE * delta
		label.modulate.a = clampf(1.0 - shown[label] / LIFE, 0.0, 1.0)
		if shown[label] >= LIFE:
			shown.erase(label)
			label.queue_free()


func _pop(body: Node3D, text: String, big: bool) -> void:
	if body == null or body.get_parent() == null:
		return
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = CRITICAL_SIZE if big else SIZE
	label.pixel_size = PIXEL
	# Pops made in the same moment stand one above another, not on top of each other.
	var fresh: int = shown.values().filter(func(age: float) -> bool: return age < 0.2).size()
	body.get_parent().add_child(label)
	label.global_position = body.global_position + Vector3.UP * (HEIGHT + STACK * fresh)
	shown[label] = 0.0


func _on_damaged(who: StringName, _by: StringName, amount: int, critical: bool) -> void:
	var body: Node3D = body_of(who)
	if body == null or amount <= 0:
		return
	_pop(body, tr(CRITICAL_KEY if critical else AMOUNT_KEY).format({"amount": amount}), critical)
	HitFlash.flash(body)


func _on_word(who: StringName, _by: StringName, word: StringName) -> void:
	_pop(body_of(who), tr(WORD_PREFIX + String(word)), false)


func _on_graded(who: StringName, grade: StringName) -> void:
	_pop(body_of(who), tr(WORD_PREFIX + "grade." + String(grade)), grade == &"perfect")
