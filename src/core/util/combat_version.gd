class_name CombatVersion
extends RefCounted
## What the COMBAT FORK says about itself, beside what the base it was forked from says.
##
## WHY A SIBLING OF `TemplateVersion` AND NOT A PARAMETER ON IT
## `TemplateVersion` is an upstream file, and every line this fork changes in an upstream file is
## a line a later `git merge template/main` can conflict on (ADR-0008). A sibling costs one small
## file and never conflicts. It reuses the upstream's rules rather than restating them: the same
## three-integer shape, the same UNKNOWN for an absent setting, the same comparison.
##
## TWO VERSIONS, TWO PROMISES. `[template] base/version` is the base this fork has merged up to,
## and it is the upstream's to bump. `[combat] core/version` is this fork's own release, bumped by
## combat packages under the same MAJOR / MINOR / PATCH promise `docs/UPGRADING.md` states.
##
## OWNS: reading the combat fork's own version out of project.godot.
## MUST NOT: read or bump the base's version, or gate anything at runtime.

## Written by combat packages, never by a game built on this fork.
const SETTING: String = "combat/core/version"


## The version this tree of the combat fork IS, or `TemplateVersion.UNKNOWN` when it states none.
static func current() -> String:
	var value: String = str(ProjectSettings.get_setting(SETTING, ""))
	return value if TemplateVersion.is_semver(value) else TemplateVersion.UNKNOWN
