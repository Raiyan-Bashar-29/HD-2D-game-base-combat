class_name ContentScan
extends RefCounted
## The one directory scan behind every catalogue: find the .tres files under a content root,
## load each, check its id against its file name, and report what is wrong — per file.
##
## WHY THIS EXISTS, AND WHAT T3.1 ACTUALLY MEASURED. Five registries carried the same
## scan-and-validate body. WP-08 reconsidered the refactor at the fourth copy and kept it,
## correctly, on the grounds that a base holding the CACHE would hand back untyped
## `Resource`s. `AreaDb` made it the fifth and changed only the arithmetic. What settles it is
## a different split of the same idea: the duplication is in the SCAN, not the cache, so the
## shared part is a FUNCTION that fills a caller-owned typed dictionary, and the base class is
## on the RESOURCE (`ContentEntry`) rather than on the registry. Nothing is cast at any call
## site; `ItemDb.definition()` still returns `ItemDefinition`.
##
## Measured before and after, in code lines as `tools/check_budgets.gd` counts them: the five
## registries were 290 lines and are now 187; this file is 39 and `ContentEntry` is 5, so 290
## against 231, with the scan-and-validate body existing ONCE instead of five times. The saving
## is not the 59 lines. It is that a bug in the id check, the duplicate check, the type check or
## the .remap handling is now ONE fix instead of five.
##
## WHY `resource_paths()` LIVES HERE NOW. It was on `ItemDb`, and the other four registries,
## `check_content.gd`, `catalogue_report.gd` and three test cases all called
## `ItemDb.resource_paths()` for content that is not items — `path_actions_test.gd` scanned
## path actions through it. Three registry headers spent a paragraph explaining that call. The
## function was always the shared scan; it now has the name and the home it always had the job
## of.
##
## WHY TWO SCANNING METHODS. `ResourceLoader.list_directory()` is the right tool — it
## understands the .remap indirection an exported .pck uses, which a raw DirAccess listing does
## not. But its documentation description is EMPTY in 4.7.2, i.e. undocumented, so its
## behaviour is treated as unproven: probed output showed bare filenames, `_normalise` handles
## full paths too, and DirAccess remains a fallback that is known to work from source. The test
## suite cross-checks the two counts, so a change in either fails a gate rather than silently
## shrinking a catalogue.
##
## WHY A SCAN AND NOT A LIST is ADR-0006 and is not restated: dropping a .tres in a folder is
## the entire act, a hand-maintained list rots, and a generated manifest fails SILENTLY when
## someone forgets to regenerate it.
##
## OWNS: turning a content root into validated resources in the caller's dictionary, and
## saying what was wrong with each file that failed.
## MUST NOT: hold a cache, remember a directory, know a content type by name, or touch an
## autoload. Problems are RETURNED, never logged, so tools/check_content.gd can use this class
## under `--script`.


## Every .tres under `directory` that loads as `kind`, into `by_id`; returns the problems.
##
## `by_id` is the CALLER'S typed dictionary and is filled in place — a `Dictionary` parameter
## is a reference, and passing a `Dictionary[StringName, ItemDefinition]` through an untyped
## parameter keeps its runtime type, so an entry of the wrong class would be refused by the
## dictionary itself. That is what keeps `ItemDb._by_id` typed with no cast anywhere.
##
## `kind_label` and `noun` carry the two words the messages use ("an ItemDefinition",
## "item") rather than being derived from `kind.get_global_name()`, because the article is not
## derivable: it is "an NpcSchedule" and "a Quest". A diagnostic a consuming game may be
## reading is not worth a rule that is right four times in five.
##
## AN EMPTY CONTENT ROOT IS NOT A PROBLEM, and the folder need not exist. That was T1.2's
## finding and it is the reason a stripped template passes its own content gate on step one of
## docs/NEW_GAME.md. A file that is PRESENT and does not load is the real error, and it is
## reported here per file.
static func into(directory: String, prefix: String, kind: Script,
		kind_label: String, noun: String, by_id: Dictionary) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	for path: String in resource_paths(directory):
		var entry: ContentEntry = ResourceLoader.load(path) as ContentEntry
		if entry == null or not is_instance_of(entry, kind):
			problems.append("%s is not %s" % [path, kind_label])
			continue
		var required: StringName = StringName(prefix + path.get_file().get_basename())
		if entry.id != required:
			problems.append("%s declares id '%s' but its file name requires '%s'" % [
				path, entry.id, required,
			])
			continue
		if by_id.has(entry.id):
			problems.append("duplicate %s id '%s' at %s" % [noun, entry.id, path])
			continue
		problems.append_array(entry.problems())
		by_id[entry.id] = entry
	return problems


## Public so the validator can print exactly what the scan saw. That printout is how the
## undocumented method's behaviour stays a recorded fact rather than an assumption.
static func resource_paths(directory: String) -> PackedStringArray:
	var found: PackedStringArray = ResourceLoader.list_directory(directory)
	if found.is_empty():
		found = DirAccess.get_files_at(directory)
	var out: PackedStringArray = PackedStringArray()
	for entry: String in found:
		var full: String = _normalise(directory, entry)
		if full != "" and not out.has(full):
			out.append(full)
	return out


## Absorbs every difference between running from source and from an exported .pck, and
## between the two scanning methods: bare name or full path, .tres or a converted .res, and
## the .remap/.import indirection.
static func _normalise(directory: String, entry: String) -> String:
	var name: String = entry.trim_suffix(".remap").trim_suffix(".import")
	if not (name.ends_with(".tres") or name.ends_with(".res")):
		return ""
	if name.begins_with("res://"):
		return name
	return "%s/%s" % [directory, name]
