class_name ContentEntry
extends Resource
## What every catalogued .tres has in common: an id that must equal its file name, and the
## ability to say what is wrong with itself.
##
## THIS IS THE HALF OF T3.1 THAT WP-08's ARGUMENT DID NOT CONSIDER, AND IT IS WHY THE ROW
## FINALLY PAID. WP-08 reconsidered a shared registry and kept the fourth copy for a sound
## reason: GDScript has no generics, so a base holding the CACHE could only hand back
## `Resource` and every accessor would become a cast at the call site, against non-negotiable
## #2. That verdict stands and is not overturned here. What it did not weigh is that the
## duplication was never in the cache — it was in the SCAN, and a scan needs only two things
## from a resource: its `id`, and its `problems()`. A base on the RESOURCE gives the scan both
## with full static typing, and leaves every registry's cache and accessor typed exactly as
## they were. `ContentScan.into()` is the one implementation; the five registries keep their
## own `Dictionary[StringName, <their type>]` and their own typed accessor.
##
## Without this class the scan would have to read `resource.id` and call `resource.problems()`
## through a `Resource`, and `unsafe_property_access` and `unsafe_method_access` are both set
## to ERROR in project.godot. The base is not decoration; it is what makes the shared scan
## compile at all.
##
## THE ID RULE IS THE SAME FOR ALL FIVE and is stated on each subclass with its own worked
## example, because that is what an author reads. `data/items/rose_key.tres` declares
## `id = &"item/rose_key"`; `data/areas/orchard.tres` declares `id = &"orchard"`, with no
## prefix, for the reason in `area_def.gd`'s header.
##
## OWNS: the two members every catalogued resource must have.
## MUST NOT: know which directory it was found in, cache anything, load anything, or grow a
## field that only one content type needs. A field belongs here only when the SCAN uses it.

## The catalogue key, and it must equal the file's base name with its catalogue's prefix in
## front. `ContentScan.into()` refuses any resource where the two disagree and names both
## values, so a copy-paste slip is a content error rather than a silent second entry.
@export var id: StringName = &""


## Everything wrong with this resource, in the author's terms and empty when it is sound.
## Every subclass overrides this; the base answers "nothing wrong" so a content type with
## nothing to check needs no boilerplate.
##
## Problems are RETURNED, never logged, so tools/check_content.gd can call this under
## `--script` where no autoload identifier resolves.
func problems() -> PackedStringArray:
	return PackedStringArray()
