class_name ItemDefinition
extends ContentEntry
## One item, as authored data. The project's first Resource subclass.
##
## THE ID IS THE FILE NAME. `data/items/rose_key.tres` must declare `id = &"item/rose_key"`.
## ItemDb refuses any definition where the two disagree and names both, so a copy-paste slip
## is a loud startup problem rather than an item that silently never exists. The `item/`
## prefix makes a save file self-describing: `"item/rose_key": 1` sits next to
## `"obj/courtyard/north_gate/open": true` and both read as what they are.
##
## FOUR FIELDS, DELIBERATELY. No icon (nothing displays one - there is no inventory screen
## and art is deferred), no description (nothing shows it), no value (no economy), no tags
## (nothing reads them), no drop scene (nothing drops, and the reference would point the
## wrong way - a Pickup references its definition, not the reverse). Adding any of them later
## edits THIS FILE ONLY and leaves every existing .tres valid, so carrying them now buys no
## migration saving and invites content authored against a guess.
##
## `max_stack` rather than a `stackable` bool: two fields encoding one fact is how
## `stackable = false, max_stack = 99` eventually gets committed.
##
## OWNS: the immutable data of one item, and validating its own fields.
## MUST NOT: know who carries it, how many exist, how it is drawn, or what it does. It must
## also not touch an autoload - tools/check_content.gd loads this class under
## `--headless --script`, where autoload identifiers do not resolve, so a single `Log` call
## here would break the build gate. That is a real enforcement mechanism for the content
## layer rule, not a style preference.

## `id` is inherited from `ContentEntry`; for this catalogue it is `item/` plus this file name.
## Localization key for the player-facing name. Never raw text.
@export var name_key: String = ""
## Stable, locale-independent sort and filter key. Also expresses "key item" without a bool.
@export var category: GameEnums.ItemCategory = GameEnums.ItemCategory.MATERIAL
## The most of this the player may hold. 1 means a unique key item. Under the current
## countless inventory this caps the total held; when slots arrive it becomes per-stack.
@export_range(1, 999, 1) var max_stack: int = 99

## Where this may be worn or held, if anywhere. NONE — the default — means the item is carried
## and nothing more, which is what almost every item is; every .tres authored before this field
## existed stays valid unedited. A FIFTH field, then, and the header above says four: the reason
## it earned one is that "may this be equipped" is a property OF THE ITEM and of nothing else,
## so the alternative was a list of equippable ids somewhere in `src/` — engine code naming
## content, which is the one thing this project gates against.
@export var equip_slot: GameEnums.EquipSlot = GameEnums.EquipSlot.NONE


## Everything wrong with this definition, as data rather than a log line, so the same check
## serves the game, the test suite and the headless validator.
func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if id == &"":
		found.append("%s has no id" % resource_path)
	if name_key == "":
		found.append("%s (%s) has no name_key" % [resource_path, id])
	return found


func is_unique() -> bool:
	return max_stack <= 1


## The enum name, for validator output and debugging. `.keys()` yields a Variant, so it goes
## through a typed local before use - the project compiles with unsafe access as an error.
func category_name() -> String:
	var names: Array = GameEnums.ItemCategory.keys()
	var raw: String = names[category]
	return raw
