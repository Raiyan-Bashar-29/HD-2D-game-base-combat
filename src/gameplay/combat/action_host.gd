class_name ActionHost
extends Node
## Where the action formula (C3) joins a running game. One lives under GameRoot.
##
## IN PLAIN WORDS: today it does one thing. When the game starts it installs the combat
## actions (attack, dodge, lock on, cycle the target), so they exist before any fighter asks
## for them. C3.4 grows it: it will give the player a fighter when the player spawns, from the
## loadout `[combat] action/loadout` names, and a game with no loadout will have no field combat.
##
## IT IS A NODE IN THE COMPOSITION ROOT, NOT AN AUTOLOAD. Adding an autoload needs an ADR
## (CLAUDE.md), and nothing here must outlive the game root.
##
## OWNS: installing the combat actions at boot.
## MUST NOT: read input itself, or build fighters before C3.4 says how.


func _ready() -> void:
	CombatActions.install()
	Log.info("combat", "Action inputs ready: %d" % CombatActions.ALL.size())
