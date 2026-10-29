class_name ErrorWatch
extends Logger
## Counts the engine-level errors a test run causes, so a crashing case cannot pass.
##
## WHY THIS EXISTS, AND WHY THE PLAN WAS NOT ENOUGH
## `ROADMAP.md` carried this since T1.1: a deliberately crashing case exited 0. T1.3 probed the
## reason - a GDScript runtime error aborts ONLY the innermost frame, and the calling function
## and everything above it run to completion. The declared plan catches every crash that swallows
## an assertion, which is most of them, but NOT a crash in a leaf helper with no assertion after
## it. That was measured, not assumed: a planted `nothing.get_child_count()` inside a helper
## produced `2/2` and exit 0 with the plan already in place.
##
## `Logger` is the only thing in the engine that sees what the tally cannot. `OS.add_logger`
## installs one, and `_log_error` is handed every error the engine raises, including
## `ERROR_TYPE_SCRIPT` - which is exactly what a GDScript runtime failure is.
##
## WHY ONLY ERROR_TYPE_SCRIPT COUNTS AS A FAILURE
## The other three types are things a suite legitimately provokes. This project's cases assert
## refusals and bad input on purpose, and several of those paths call `push_error`, which arrives
## here as `ERROR_TYPE_ERROR`. Failing on those would make the gate unusable within a day, and a
## gate that gets switched off is worse than no gate. `ERROR_TYPE_SCRIPT` has no legitimate
## occurrence: a test cannot deliberately dereference null. Every type is COUNTED and reported
## either way, so the others are visible rather than discarded.
##
## OWNS: counting engine errors and describing the script ones.
## MUST NOT: assert, print during a run, or decide anything. The runner reads the counts.

const MAX_DESCRIPTIONS: int = 10

var script_errors: int = 0
var other_errors: int = 0
var descriptions: Array[String] = []


func _log_error(function: String, file: String, line: int, code: String, _rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type != Logger.ERROR_TYPE_SCRIPT:
		other_errors += 1
		return
	script_errors += 1
	# Capped: a crash inside a loop can raise the same error hundreds of times, and a wall of
	# identical lines is how the FIRST one gets lost.
	if descriptions.size() < MAX_DESCRIPTIONS:
		descriptions.append("%s at %s:%d in %s()" % [code, file, line, function])


## Everything raised so far, for the runner's per-case bookkeeping.
func total() -> int:
	return script_errors + other_errors
