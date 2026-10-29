class_name TestCase
extends Node
## Base for a group of related assertions. Subclass it, override `run()`, and add the script
## to `CASES` in `tests/test_runner.gd`.
##
## WHY THE SUITE IS SPLIT ACROSS FILES
## `test_runner.gd` reached ~200 of its 250 code lines with its largest case at 35 of the 40
## allowed per function. Adding the item cases would have failed `check_budgets.gd`. Rather
## than raise the budget - which is the move that turned the previous project's main.gd into
## 3,983 lines, twenty reasonable lines at a time - the suite grew a seam. The
## `tests/framework/` and `tests/unit/` directories already existed, empty, for this.
##
## OWNS: assertion counting, failure messages, and the shape questions more than one case asks
## of a .tscn.
## MUST NOT: contain game logic, or know which other cases exist.

var passed: int = 0
var failed: int = 0
var failures: Array[String] = []
var skipped: int = 0
var skips: Array[String] = []
var planned: int = -1


## Override with the case's assertions. Called once, with the tree live and autoloads ready.
func run() -> void:
	Log.warn("test", "%s does not override run()" % name)


## The only assertion. Deliberately the only one: a suite with eight assertion helpers spends
## its time debating which to use. Floats go through `is_equal_approx(a, b), true`.
func equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		passed += 1
		Log.debug("test", "  ok   %s" % label)
		return
	failed += 1
	var message: String = "%s — expected %s, got %s" % [label, str(expected), str(actual)]
	failures.append(message)
	Log.warn("test", "  FAIL %s" % message)


## Instantiate a scene WITHOUT putting it in the tree, so the caller can set exported
## properties first, then call attach().
##
## WHY THE TWO STEPS ARE SEPARATE, and why this is not needless ceremony: Interactable
## forwards object_id to its PersistentState child in _enter_tree, which runs on add_child.
## Anything set after that is too late - PersistentState has already decided it has no id,
## logged an error, and stopped persisting. A one-step spawn() helper hid exactly that bug
## the first time this file was written.
func build(scene_path: String) -> Node:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		equal("scene loads: %s" % scene_path, false, true)
		return null
	return packed.instantiate()


## Put a fully configured node into the tree. The caller still owns freeing it - anything
## left alive at exit prints a wall of leaked-RID errors that buries real ones.
func attach(node: Node) -> void:
	if node != null:
		add_child(node)


## HOW MANY OUTCOMES THIS CASE WILL PRODUCE, declared as the first statement of run().
##
## WHY A COUNT, WHICH IS BOOKKEEPING NOBODY LIKES
## `ROADMAP.md` carried this since T1.1: a deliberately CRASHING case exited 0, which
## invalidated every green result the project had. T1.3 probed why. A GDScript runtime error
## aborts ONLY the innermost frame - proven: a null call inside a helper printed its
## `SCRIPT ERROR`, and both the calling function and `_ready()` above it ran to completion. So
## the runner cannot see a crash. Nothing it can inspect afterwards differs, EXCEPT that the
## assertions after the crash never ran.
##
## A count is therefore the only thing that catches it, and it catches three more silent passes
## with the same line: a `run()` that returns early, a case that asserts nothing at all, and a
## helper quietly commented out. This is TAP's `1..N` plan, for TAP's reason.
##
## A SKIP COUNTS AS THE OUTCOMES IT STANDS IN FOR, so the plan is the same number whether or
## not this checkout has demo content in it, and a stripped run reports exactly how many
## assertions it gave up.
func plan(count: int) -> void:
	if planned >= 0:
		equal("%s declares its plan once" % name, true, false)
		return
	planned = count


## Deliberately not run, and SAID SO. Used where a case genuinely asserts something about demo
## content - the content validator's own coverage, the shape of the authored areas - which a
## stripped template has none of. Silence would let a stripped run look identical to a full one
## while covering a third less.
func skip(label: String, why: String, stands_for: int = 1) -> void:
	skipped += stands_for
	skips.append("%s (%s) — %d assertion(s) not run" % [label, why, stands_for])
	Log.debug("test", "  SKIP %s — %s" % [label, why])


func outcomes() -> int:
	return passed + failed + skipped


## The parent of the node in `scene_path` that carries `script_path`, or "" when there is no
## such node. `get_node_path` is relative to the scene root, so a node directly under it
## answers "." and one that has been deleted answers nothing at all.
##
## HERE RATHER THAN IN A CASE because a second case now asks the same question of the same
## scene, and this project moves a helper out on its second caller rather than its third.
## It is shape, not game logic: it reads a .tscn and says where a script hangs.
##
## READ THROUGH `SceneState`, NEVER AS TEXT, which is the reason it is worth sharing at all.
## The first version of this question searched the .tscn for the script path and stayed GREEN
## when the node was deleted, because an `[ext_resource]` line survives a node's removal.
## The engine's own parse cannot be fooled that way: a script is a PROPERTY of a node here,
## and the node either exists or it does not.
func parent_of_script(scene_path: String, script_path: String) -> String:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return ""
	var state: SceneState = packed.get_state()
	for node: int in state.get_node_count():
		for property: int in state.get_node_property_count(node):
			if state.get_node_property_name(node, property) != &"script":
				continue
			var script: Script = state.get_node_property_value(node, property) as Script
			if script != null and script.resource_path == script_path:
				return String(state.get_node_path(node, true))
	return ""
