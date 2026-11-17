class_name CombatSettings
extends RefCounted
## The combat options a player changes on the settings screen (C5.3b): the difficulty, whether
## battles play themselves, wait mode for the command menu, lock-on assist, and hold to attack.
##
## IN PLAIN WORDS: `install()` adds them to upstream's settings with `Settings.game.add` (base
## 5.19.0), under their own "Combat" section, once at boot (`ActionHost`). They are kept on the
## player's machine like every other setting, and each is read where it acts. ONLY WHERE THE GAME
## HAS THE FEATURE (C5.3e): a row that changes nothing is worse than none, so the difficulty needs a
## difficulty file, auto-battle a party roster, and the rest a field loadout (wait mode one with ATB
## rules). A reader treats a setting never added as off, or as the project's default.
## - DIFFICULTY, by `CombatDifficulty.current()`. The choices are "none" and every difficulty
##   file, lowest `order` first, each shown by its own `name_key` (base 5.21.0). The default is
##   the project's `combat/difficulty/default`.
## - AUTO_BATTLE, by `AutoBattle.on()`.
## - WAIT_MODE, by `CommandOverlay.slow()`: on, the fight stops while the command menu is open.
## - LOCK_ON_ASSIST, by `LockOn.refresh()`: on, a lock whose target falls moves to the nearest
##   other foe in reach.
## - HOLD_TO_ATTACK (C5.3d), by `ActionFighter`: a held attack button keeps the chain going. It
##   joins upstream's own Accessibility section rather than the Combat one.
##
## A SAVE'S OWN CHOICE WINS UNTIL THE PLAYER CHANGES THE SETTING. The flags `combat/difficulty`,
## `combat/auto_battle` and `combat/hold_to_attack` are kept with a save (the battle screen's Auto
## row sets the second),
## and while one is there it is what counts. Changing the matching setting drops it, so the change
## takes effect at once; a reset of every setting does the same.
##
## OWNS: the combat settings' names, defaults and choices, and dropping a save's flag when the
## player changes the matching setting.
## MUST NOT: act on a setting itself. The five readers above do.

const DIFFICULTY: String = "combat/difficulty"
const AUTO_BATTLE: String = "combat/auto_battle"
const WAIT_MODE: String = "combat/wait_mode"
const LOCK_ON_ASSIST: String = "combat/lock_on_assist"
const HOLD_TO_ATTACK: String = "accessibility/hold_to_attack"
## How "no difficulty" reads on the settings screen.
const NONE_KEY: String = "ui.settings.combat.difficulty.none"
## Where the command menu's slow-down is set; 0 there means the project starts in wait mode.
const SLOW_SETTING: String = "combat/hybrid/slow"
## The party roster turn-based battles are fought with (`BattleHost`); none, no battles.
const ROSTER_SETTING: String = "combat/party/roster"


## Adds the settings this game has a feature for. `loadout` is the field fighter's
## (`ActionHost.configured()`, null for none) and `battles` whether turn-based battles have a party
## (`has_battles()`). Safe to call again.
static func install(loadout: ActionLoadout, battles: bool) -> void:
	if not DifficultyDb.ids().is_empty():
		_add_difficulty()
	if battles:
		Settings.game.add(AUTO_BATTLE, false)
	if loadout != null and loadout.atb != null:
		var slow: float = ProjectSettings.get_setting(SLOW_SETTING, 0.1)
		Settings.game.add(WAIT_MODE, is_zero_approx(slow))
	if loadout != null:
		Settings.game.add(LOCK_ON_ASSIST, false)
		Settings.game.add(HOLD_TO_ATTACK, false)
	if not Events.setting_changed.is_connected(_on_changed):
		Events.setting_changed.connect(_on_changed)


## True when `[combat] party/roster` names a file, so there are turn-based battles to play.
static func has_battles() -> bool:
	var path: String = str(ProjectSettings.get_setting(ROSTER_SETTING, ""))
	return path != "" and ResourceLoader.exists(path)


## True when the combat setting `path` is added and on; false before `install`, so a test or a
## stripped game that never installed them reads every one as off.
static func is_on(path: String) -> bool:
	return Settings.default_of(path) != null and Settings.get_bool(path)


## A save's own `flag` when it has one, else the player's setting `path` (off before `install`).
static func flag_or_setting(flag: StringName, path: String) -> bool:
	return Flags.get_bool(flag) if Flags.has_flag(flag) else is_on(path)


## The difficulty id the player chose, or `fallback` before `install`.
static func difficulty(fallback: String) -> String:
	return Settings.get_string(DIFFICULTY) if Settings.default_of(DIFFICULTY) != null else fallback


## None, then every difficulty file, lowest `order` first, each by its own `name_key`.
static func _add_difficulty() -> void:
	var ids: Array = [""]
	var labels: Array[String] = [NONE_KEY]
	for id: StringName in DifficultyDb.ids():
		ids.append(String(id))
		labels.append(DifficultyDb.of(id).name_key)
	var fallback: String = str(ProjectSettings.get_setting(CombatDifficulty.SETTING, ""))
	Settings.game.add(DIFFICULTY, fallback if ids.has(fallback) else "", ids, labels)


static func _on_changed(section: String, key: String, _value: Variant) -> void:
	var path: String = "%s/%s" % [section, key]
	if path == DIFFICULTY:
		Flags.erase_flag(CombatDifficulty.FLAG)
	elif path == AUTO_BATTLE:
		Flags.erase_flag(AutoBattle.FLAG)
	elif path == HOLD_TO_ATTACK:
		Flags.erase_flag(ActionFighter.HOLD_FLAG)
