extends TestCase
## The combat fork's own record, gated the way upstream gates its own.
##
## WHY A SEPARATE CASE AND NOT A WIDER `record_shape_test.gd` OR `version_test.gd`
## Both are upstream files. Every line this fork changes in one is a line a later
## `git merge template/main` can conflict on, so this fork's gates live in a file upstream does not
## have (ADR-0008). They ask upstream's questions of this fork's documents:
## - every `## date — Cn.m` package in `COMBAT_DEVLOG.md` has a row on `COMBAT.md`'s board, which
##   `record_shape_test.gd` asks of `DEVLOG.md` against `WORK_PACKAGES.md`;
## - the combat version is declared, is three integers, is printed at boot, and every BOLD semver
##   in `COMBAT.md` is it, which `version_test.gd` asks of the base version and `CONTEXT.md`.
##
## OWNS: assertions about `COMBAT.md`, `COMBAT_DEVLOG.md` and `[combat] core/version`.
## MUST NOT: assert anything about upstream's documents or the base version; their own cases do.

const LOG: String = "res://docs/COMBAT_DEVLOG.md"
const BOARD: String = "res://docs/COMBAT.md"
const LOG_SOURCE: String = "res://src/core/log/log.gd"
## Unique in that file, for `version_test.gd`'s reason: a second copy hides a deletion.
const BANNER_ANCHOR: String = "combat %s"
const HEADING_PATTERN: String = "^## [0-9-]{10} — (C[0-9]+[.][0-9]+)"
const BOLD_SEMVER: String = "\\*\\*([0-9]+[.][0-9]+[.][0-9]+)\\*\\*"


func run() -> void:
	var packages: Array[String] = _packages()
	var stated: Array[String] = _bold_versions(BOARD)
	plan(5 + packages.size() + stated.size())
	_the_version_is_declared()
	equal("the boot banner names the combat version exactly once",
		_code_occurrences(LOG_SOURCE, BANNER_ANCHOR), 1)
	equal("COMBAT_DEVLOG.md records at least one package", packages.size() > 0, true)
	var board: String = FileAccess.get_file_as_string(BOARD)
	for id: String in packages:
		var matcher := RegEx.create_from_string("\\b" + id.replace(".", "\\.") + "\\b")
		equal("%s has a row on COMBAT.md" % id, matcher.search(board) != null, true)
	equal("COMBAT.md states the combat version", stated.size() > 0, true)
	for version: String in stated:
		equal("COMBAT.md states the declared combat version", version, CombatVersion.current())


func _the_version_is_declared() -> void:
	var declared: String = str(ProjectSettings.get_setting(CombatVersion.SETTING, ""))
	equal("project.godot declares the combat version", TemplateVersion.is_semver(declared), true)
	equal("current() is the declared value", CombatVersion.current(), declared)


func _packages() -> Array[String]:
	var found: Array[String] = []
	var matcher := RegEx.create_from_string(HEADING_PATTERN)
	for line: String in FileAccess.get_file_as_string(LOG).split("\n"):
		var hit: RegExMatch = matcher.search(line)
		if hit != null and not found.has(hit.get_string(1)):
			found.append(hit.get_string(1))
	return found


func _bold_versions(path: String) -> Array[String]:
	var found: Array[String] = []
	var matcher := RegEx.create_from_string(BOLD_SEMVER)
	for hit: RegExMatch in matcher.search_all(FileAccess.get_file_as_string(path)):
		found.append(hit.get_string(1))
	return found


## Comments are skipped, gotcha 43: a file that explains its own banner would otherwise pass a
## scan with the banner deleted.
func _code_occurrences(path: String, fragment: String) -> int:
	var found: int = 0
	for raw: String in FileAccess.get_file_as_string(path).split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("#") or not line.contains(fragment):
			continue
		found += 1
	return found
