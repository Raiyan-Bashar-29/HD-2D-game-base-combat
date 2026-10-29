extends TestCase
## The export seam: what an assertion running under res:// CAN honestly say about a build it is
## not running in.
##
## WHAT THIS CASE CANNOT DO, SAID FIRST SO NOBODY MISREADS A GREEN RUN
## It cannot test an exported build. It runs from res:// in the editor, where every content file
## is plainly on disk — which is exactly the blind spot T2.0 existed to close, and the reason the
## proof itself is a RUN of the exported executable with its numbers quoted in docs/DEVLOG.md
## rather than an assertion here. _the_suite_is_not_an_exported_build() asserts that blindness
## instead of leaving it implied, so this file cannot quietly start looking like the proof.
##
## WHAT IT CAN DO, AND ALL THREE ARE LOAD-BEARING
## 1. Pin the preset field the whole content pipeline rests on. ItemDb, DialogueDb and ScheduleDb
##    find content by SCANNING a directory (ADR-0006), so those resources are nobody's dependency
##    and only export_filter="all_resources" ships them. Measured both ways in T2.0. A consuming
##    game that narrows it now fails rung 4 instead of shipping empty catalogues.
## 2. Prove the reporter agrees with the registries. The exported run is read through
##    CatalogueReport, so a reporter that printed a stale or invented number would make the proof
##    worthless — and it would look identical.
## 3. Prove every path the scan resolves actually loads. A PARTIAL ship is worse than an empty
##    one, because three of four items is a plausible number.
##
## OWNS: assertions about the export contract and the catalogue readout.
## MUST NOT: assert what the registries themselves do — items_test.gd, dialogue_test.gd and
## npc_test.gd own the catalogues. This case owns only the seam to the build.

const PRESET_FILE: String = "res://export_presets.cfg"
## The one value that makes an unreferenced resource ship. Not a preference: measured.
const REQUIRED_FILTER: String = "all_resources"

var _saved_item_dir: String = ""
## An existing but empty directory, so the empty-root case produces no engine error of its own.
## Inside this run's own scratch directory, T6.13, so no other suite can put a file in it.
var _empty_root: String = RunScratch.path("export_empty")


func run() -> void:
	plan(23)
	_saved_item_dir = ItemDb.content_dir
	_the_report_agrees_with_the_registries()
	_every_resolved_path_loads()
	_the_suite_is_not_an_exported_build()
	_an_empty_root_is_reported_and_not_refused()
	_the_preset_pins_the_only_filter_that_ships_content()


## One line of origin plus one line per registry, each carrying the count and the root it came
## from. This is the shape the exported run is read in, so its shape is asserted.
func _the_report_agrees_with_the_registries() -> void:
	var lines: PackedStringArray = CatalogueReport.report_lines()
	equal("report is origin plus one line per registry", lines.size(), 6)
	equal("first line is the origin", lines[0].begins_with("origin: "), true)
	_line_reports(lines[1], CatalogueReport.LABEL_ITEMS, ItemDb.count(), ItemDb.content_dir)
	_line_reports(
		lines[2], CatalogueReport.LABEL_DIALOGUE, DialogueDb.count(), DialogueDb.content_dir
	)
	_line_reports(
		lines[3], CatalogueReport.LABEL_SCHEDULES, ScheduleDb.count(), ScheduleDb.content_dir
	)
	_line_reports(
		lines[4], CatalogueReport.LABEL_QUESTS, QuestDb.count(), QuestDb.content_dir
	)
	_line_reports(
		lines[5], CatalogueReport.LABEL_AREAS, AreaDb.count(), AreaDb.content_dir
	)


func _line_reports(line: String, label: String, found: int, directory: String) -> void:
	equal("%s line reports its count" % label, line.contains("%s: %d " % [label, found]), true)
	equal("%s line reports its root" % label, line.contains(directory), true)


## Every path the scan hands back must load, and there must be exactly as many of them as there
## are catalogued ids. A path that resolves and does not load is the partial ship.
func _every_resolved_path_loads() -> void:
	var roots: PackedStringArray = PackedStringArray([
		ItemDb.content_dir, DialogueDb.content_dir, ScheduleDb.content_dir, QuestDb.content_dir,
		AreaDb.content_dir,
	])
	var resolved: int = 0
	var unloadable: int = 0
	for root: String in roots:
		for path: String in ContentScan.resource_paths(root):
			resolved += 1
			if not ResourceLoader.exists(path):
				unloadable += 1
	equal("every resolved path exists as a resource", unloadable, 0)
	equal("one resolved path per catalogued id", resolved,
		ItemDb.count() + DialogueDb.count() + ScheduleDb.count() + QuestDb.count()
		+ AreaDb.count())


## THE BLIND SPOT, ASSERTED RATHER THAN ASSUMED. If this ever fails, the suite is running inside
## an exported build and the honest limits in this file's header no longer apply — which would be
## a change worth noticing, not a test to relax.
func _the_suite_is_not_an_exported_build() -> void:
	equal("the suite is not an exported build", CatalogueReport.is_exported(), false)
	equal("the suite runs under the editor binary", OS.has_feature("editor"), true)


## AN EMPTY CATALOGUE IS REPORTED, NEVER REFUSED. It was an error until T1.2, and that made a
## stripped template fail its own content gate on the first command of docs/NEW_GAME.md. A base
## template with no game in it yet is a legal state; in an EXPORTED build the same emptiness is
## the failure this package exists to detect, which is why it warns there and only reports here.
func _an_empty_root_is_reported_and_not_refused() -> void:
	DirAccess.make_dir_recursive_absolute(_empty_root)
	ItemDb.content_dir = _empty_root
	ItemDb.rescan()
	equal("an empty root yields no definitions", ItemDb.count(), 0)
	equal("an empty root is not a problem", ItemDb.problems().is_empty(), true)
	equal("an empty root is named as empty", CatalogueReport.empty_labels().has(
		CatalogueReport.LABEL_ITEMS), true)
	var lines: PackedStringArray = CatalogueReport.report_lines()
	equal("the report says zero", lines[1].contains("%s: 0 " % CatalogueReport.LABEL_ITEMS), true)
	ItemDb.content_dir = _saved_item_dir
	ItemDb.rescan()
	DirAccess.remove_absolute(_empty_root)
	equal("the root is restored for the cases after this one",
		ItemDb.content_dir, _saved_item_dir)


## THE PRESET IS PART OF THE ENGINE CONTRACT, so it is asserted like one. export_presets.cfg is
## committed (it is not gitignored — only override.cfg is), and a consuming game inherits it. If
## it is absent the case SKIPS LOUDLY rather than passing: a missing preset is a real state for a
## checkout that has not exported yet, and a silent pass would be indistinguishable from a preset
## that is present and wrong.
func _the_preset_pins_the_only_filter_that_ships_content() -> void:
	if not FileAccess.file_exists(PRESET_FILE):
		skip("export preset pins all_resources", "no export_presets.cfg in this checkout", 2)
		return
	var preset: ConfigFile = ConfigFile.new()
	equal("the preset parses", preset.load(PRESET_FILE), OK)
	var filter: Variant = preset.get_value("preset.0", "export_filter", "")
	equal("the preset ships every resource, not only dependencies", str(filter), REQUIRED_FILTER)
