class_name CatalogueReport
extends Node
## The export proof, made permanent: what the content registries actually found, reported
## at boot of every debug build — including an EXPORTED one.
##
## WHY THIS FILE EXISTS
## ItemDb, DialogueDb, ScheduleDb, QuestDb and AreaDb find content by SCANNING a directory
## (ADR-0006).
## Nothing in
## any scene references most of the content roots, so those resources are not DEPENDENCIES of
## anything, and Godot's exporter walks dependencies. If it omitted them, every catalogue would
## ship empty in an exported build — no items, no conversations, no NPC timetables — and NOTHING
## in this project could see it: every ladder rung, both CI jobs, check_content and all 911
## assertions run from res:// in the editor, where the files are plainly on disk. That is the
## "409 passing checks and never rendered a frame" failure this project was founded to prevent,
## and T2.0 is the package that closed it.
##
## WHAT NO ASSERTION CAN DO, WHICH IS THE WHOLE POINT
## A test running under res:// cannot test an exported build. So tests/unit/export_test.gd proves
## this reporter agrees with the registries and that its lines carry the evidence; the export
## claim itself is proved by RUNNING the executable and reading this output, and the numbers from
## both sides are quoted in docs/DEVLOG.md. A gate that could see it would have to run an export,
## which needs a platform template a CI runner does not have.
##
## WHY IT REPORTS THE PATHS AND NOT ONLY THE COUNTS
## A PARTIAL ship is worse than an empty one, because it looks fine — three of four items is a
## plausible number. The resolved paths are what make an exported run comparable with the
## editor's, and they are also where the .remap indirection an exported pack uses becomes visible
## rather than assumed: ContentScan.resource_paths() absorbs it, and this is the only place its
## behaviour under a real pack is ever observed.
##
## OWNS: counting what the registries found and reporting it.
## MUST NOT: load content itself, fix anything, or be depended upon by gameplay. It ASKS the same
## registries the game asks; a reporter that did its own scan would be reporting on itself.
## Deleting this file must not change what the game does.

## The content roots, in the order they are reported. A label, and the registry it names.
## A NEW registry is one row here, one row in report_lines and one in empty_labels, and no other
## change. WP-08 added the fourth and WP-11 the fifth, and that is exactly what each cost.
const LABEL_ITEMS: String = "items"
const LABEL_DIALOGUE: String = "dialogue"
const LABEL_SCHEDULES: String = "schedules"
const LABEL_QUESTS: String = "quests"
const LABEL_AREAS: String = "areas"


## The report as text: one line saying where res:// is coming from, one line per registry, and one
## line per content problem. RETURNED rather than printed, on the same reasoning that makes the
## registries return their problems instead of logging them — a test can read this, and a tool
## running under --script has no autoloads to log through.
static func report_lines() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	out.append(origin())
	_append_registry(out, LABEL_ITEMS, ItemDb.content_dir, ItemDb.count(), ItemDb.problems())
	_append_registry(
		out, LABEL_DIALOGUE, DialogueDb.content_dir, DialogueDb.count(), DialogueDb.problems()
	)
	_append_registry(
		out, LABEL_SCHEDULES, ScheduleDb.content_dir, ScheduleDb.count(), ScheduleDb.problems()
	)
	_append_registry(
		out, LABEL_QUESTS, QuestDb.content_dir, QuestDb.count(), QuestDb.problems()
	)
	_append_registry(
		out, LABEL_AREAS, AreaDb.content_dir, AreaDb.count(), AreaDb.problems()
	)
	return out


static func _append_registry(
	out: PackedStringArray,
	label: String,
	directory: String,
	found: int,
	problems: PackedStringArray,
) -> void:
	out.append("%s: %d found in %s -> %s" % [
		label, found, directory, str(ContentScan.resource_paths(directory)),
	])
	for problem: String in problems:
		out.append("  !! %s: %s" % [label, problem])


## Which catalogues came back empty. Empty is a legal state in the editor — a base
## template with no game in it yet — so this exists to be reported, never to refuse a boot.
static func empty_labels() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if ItemDb.count() == 0:
		out.append(LABEL_ITEMS)
	if DialogueDb.count() == 0:
		out.append(LABEL_DIALOGUE)
	if ScheduleDb.count() == 0:
		out.append(LABEL_SCHEDULES)
	if QuestDb.count() == 0:
		out.append(LABEL_QUESTS)
	if AreaDb.count() == 0:
		out.append(LABEL_AREAS)
	return out


## True when this process is an exported build rather than the editor or a source run. Both tags
## are reported by origin() rather than trusted silently: `template` and `editor` are documented
## as opposites, the 4.7.2 doc description for OS.has_feature is EMPTY, and this project's rule
## is that an undocumented behaviour is proven by observing it. The observed values from the
## exported run are in docs/DEVLOG.md.
static func is_exported() -> bool:
	return OS.has_feature("template")


## Where res:// is actually coming from. In an exported build the executable's directory holds the
## .pck and there is no loose content folder beside it, which is exactly the condition that makes
## the counts above worth reporting at all.
static func origin() -> String:
	return "origin: template=%s editor=%s debug=%s exe=%s" % [
		str(OS.has_feature("template")),
		str(OS.has_feature("editor")),
		str(OS.is_debug_build()),
		OS.get_executable_path().get_file(),
	]


## THE SAME GATE, THE SAME REASON, as the other three files in this directory. src/systems/debug/
## is the one directory tools/check_boundary.gd exempts from the engine/demo boundary rule, and
## the exemption is conditional on nothing here being reachable in a shipped build. A count
## readout is not player-facing, so it has no localization key and Log is the right destination —
## but it is also not something a player should ever see, so it stops here in a release build.
func _ready() -> void:
	if not OS.is_debug_build():
		return
	for line: String in report_lines():
		Log.info("content", line)
	_warn_if_empty()


## AN EMPTY CATALOGUE IS NOT AN ERROR IN THE EDITOR — that was one until T1.2, and it made a
## stripped template fail its own content gate on the first command of docs/NEW_GAME.md. In an
## EXPORTED build it is the exact failure this package exists to detect, so it warns there and
## stays quiet here. It cannot be an error either way: a consuming game may legitimately ship with
## no schedules, and a base that refused to boot without them would be lying about what it needs.
func _warn_if_empty() -> void:
	if not is_exported():
		return
	for label: String in empty_labels():
		Log.warn("content", "%s catalogue is EMPTY in an exported build — check export_filter" % label)
