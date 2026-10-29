extends TestCase
## The version the template states about ITSELF, and the two places that must agree with it.
##
## WHY A VERSION NEEDS A GATE AND `application/config/version` DOES NOT
## The game's version is the game's business and nothing in the template reads it. The BASE's
## version is a promise made to a fork — `docs/UPGRADING.md` tells a consuming game to compare it
## against what it merged last — and a promise nothing checks decays into a number somebody
## forgot to bump. THREE facts are checkable and all three rot silently: the setting in
## `project.godot` disagreeing with `docs/CHANGELOG.md`, the boot banner quietly losing the value,
## which is the only way a fork's bug report says which base it was built on, and `CONTEXT.md`
## stating a version it stopped being — which it did, for two majors, until T5.19.
##
## THE BANNER IS ASSERTED BY A TEXT SCAN, AND THE ANCHOR IS UNIQUE ON PURPOSE. `Log._ready()`
## has already run by the time any case does, and calling it again would open a second log file.
## So the assertable form is the one `check_boundary.gd` uses — read the source. `CONTEXT.md`
## gotcha 43 is the rule that shape has to follow: comments are skipped, because a file that
## explains its own banner would otherwise satisfy the scan with the banner deleted, and the
## fragment must appear EXACTLY ONCE, because a second copy makes the deletion invisible.
##
## OWNS: assertions about the template's own version and the places that repeat it.
## MUST NOT: assert anything about the GAME's version, or about what `UPGRADING.md` says. Prose
## is reviewed; `docs_test.gd` already checks the paths it names.

const LOG_SOURCE: String = "res://src/core/log/log.gd"
## Unique in that file, and it has to stay that way — see the header.
const BANNER_ANCHOR: String = "| base %s |"
const CHANGELOG: String = "res://docs/CHANGELOG.md"
const CONTEXT: String = "res://docs/CONTEXT.md"


func run() -> void:
	var stated: Array[String] = _bold_versions(CONTEXT)
	plan(28 + stated.size())
	_the_setting_is_what_the_class_reports()
	_the_parts_agree_with_the_string()
	_is_semver_refuses_everything_that_is_not_three_integers()
	_comparison_orders_versions()
	_an_absent_setting_reads_as_unknown()
	_the_boot_banner_names_the_base_version()
	_the_changelog_top_entry_is_this_version()
	_the_context_states_this_version(stated)


func _the_setting_is_what_the_class_reports() -> void:
	equal("project.godot declares the base version",
		ProjectSettings.has_setting(TemplateVersion.SETTING), true)
	var declared: String = str(ProjectSettings.get_setting(TemplateVersion.SETTING, ""))
	equal("current() is the declared value", TemplateVersion.current(), declared)
	equal("the declared value is three integers", TemplateVersion.is_semver(declared), true)


func _the_parts_agree_with_the_string() -> void:
	var pieces: PackedStringArray = TemplateVersion.current().split(".")
	equal("major is the first part", TemplateVersion.major(), pieces[0].to_int())
	equal("minor is the second part", TemplateVersion.minor(), pieces[1].to_int())
	equal("patch is the third part", TemplateVersion.patch(), pieces[2].to_int())


## The rejects are the shapes a hand-edited project.godot actually produces: a two-part version,
## a four-part one, a suffix borrowed from semver proper, and an empty setting.
func _is_semver_refuses_everything_that_is_not_three_integers() -> void:
	equal("accepts 1.0.0", TemplateVersion.is_semver("1.0.0"), true)
	equal("accepts a multi-digit part", TemplateVersion.is_semver("12.30.400"), true)
	equal("refuses two parts", TemplateVersion.is_semver("1.0"), false)
	equal("refuses four parts", TemplateVersion.is_semver("1.0.0.0"), false)
	equal("refuses a pre-release suffix", TemplateVersion.is_semver("1.0.0-rc1"), false)
	equal("refuses a non-numeric part", TemplateVersion.is_semver("1.0.x"), false)
	equal("refuses a negative part", TemplateVersion.is_semver("1.0.-1"), false)
	equal("refuses empty", TemplateVersion.is_semver(""), false)
	equal("refuses whitespace", TemplateVersion.is_semver("1. 0.0"), false)


func _comparison_orders_versions() -> void:
	var mine: String = TemplateVersion.current()
	equal("equal to itself", TemplateVersion.compare_to(mine), 0)
	equal("newer than 0.0.1", TemplateVersion.compare_to("0.0.1") > 0, true)
	equal("older than 99.0.0", TemplateVersion.compare_to("99.0.0") < 0, true)
	equal("an unparseable other reads as the oldest",
		TemplateVersion.compare_to("not-a-version") > 0, true)
	equal("same major as its own major.99.99",
		TemplateVersion.same_major_as("%d.99.99" % TemplateVersion.major()), true)
	equal("not the same major as the next one",
		TemplateVersion.same_major_as("%d.0.0" % (TemplateVersion.major() + 1)), false)


## A tree that predates this setting must read as OLDER than every real version, not as newer
## and not as a crash — that is what lets a fork compare against a base it merged long ago.
func _an_absent_setting_reads_as_unknown() -> void:
	var saved: String = TemplateVersion.current()
	ProjectSettings.set_setting(TemplateVersion.SETTING, null)
	equal("an unset version is UNKNOWN", TemplateVersion.current(), TemplateVersion.UNKNOWN)
	equal("UNKNOWN has a zero major", TemplateVersion.major(), 0)
	ProjectSettings.set_setting(TemplateVersion.SETTING, saved)
	equal("restored", TemplateVersion.current(), saved)


func _the_boot_banner_names_the_base_version() -> void:
	equal("the boot banner names the base version exactly once",
		_code_occurrences(LOG_SOURCE, BANNER_ANCHOR), 1)


## Comments are skipped for gotcha 43's reason: this file's own header quotes the anchor, and a
## scan that read documentation back to itself would pass over a deleted banner.
func _code_occurrences(path: String, fragment: String) -> int:
	var found: int = 0
	for raw: String in FileAccess.get_file_as_string(path).split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("#") or not line.contains(fragment):
			continue
		found += 1
	return found


## The changelog discipline, as a gate. Its newest `## <semver>` heading IS the released
## version, so bumping one of the two without the other fails here rather than in a fork.
func _the_changelog_top_entry_is_this_version() -> void:
	var newest: String = ""
	for raw: String in FileAccess.get_file_as_string(CHANGELOG).split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("## ") and TemplateVersion.is_semver(line.substr(3).strip_edges()):
			newest = line.substr(3).strip_edges()
			break
	equal("the changelog has a versioned entry", newest != "", true)
	equal("its newest entry is the declared version", newest, TemplateVersion.current())


## THE FILE EVERY SESSION IS TOLD TO READ FIRST STATES THIS VERSION, AND IT STATED `2.4.0` FOR
## TWO MAJORS. `CLAUDE.md` sends a new session to `CONTEXT.md` before anything else, so a stale
## version there is the first thing a reader believes and the last thing anybody re-checks. The
## convention that makes it assertable is `doc_counts_test.gd`'s, applied to a version instead of
## a count: a BOLD semver is a claim about the CURRENT version, and every other spelling — a
## backticked tag, a bare number in a sentence about what some earlier package bumped — is a
## record of what WAS true. So there is no list of exceptions here to rot in turn.
func _the_context_states_this_version(stated: Array[String]) -> void:
	equal("CONTEXT.md states the template version", stated.size() > 0, true)
	for version: String in stated:
		equal("CONTEXT.md states the declared version", version, TemplateVersion.current())


func _bold_versions(path: String) -> Array[String]:
	var found: Array[String] = []
	var matcher := RegEx.create_from_string("[*][*]([0-9]+[.][0-9]+[.][0-9]+)[*][*]")
	for hit: RegExMatch in matcher.search_all(FileAccess.get_file_as_string(path)):
		found.append(hit.get_string(1))
	return found
