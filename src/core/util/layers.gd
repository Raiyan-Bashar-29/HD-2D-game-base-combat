class_name Layers
extends RefCounted
## Named collision layers and masks. The one place a layer number may appear.
##
## Why: bare numbers like `collision_mask = 21` are unreadable and silently wrong after a
## reshuffle. These constants mirror [layer_names] in project.godot exactly — if you add a
## layer there, add it here in the same commit.
##
## Layer = "what I am". Mask = "what I detect".

const WORLD: int = 1 << 0            ## Static terrain, buildings, anything you collide with.
const PLAYER: int = 1 << 1           ## The player body.
const NPC: int = 1 << 2              ## Non-player characters.
const INTERACTABLE: int = 1 << 3     ## Anything the interaction system can select.
const TRIGGER: int = 1 << 4          ## Volumes that fire on entry: area edges, plot triggers.
const PROP_DYNAMIC: int = 1 << 5     ## Pushable, droppable physics props.
const WATER: int = 1 << 6            ## Swimmable or wadeable volumes.
const CAMERA_OCCLUDER: int = 1 << 7  ## Geometry the camera should fade or avoid.
const LEDGE: int = 1 << 8            ## Climbable or droppable edges.
const SIGHT_BLOCKER: int = 1 << 9    ## Blocks NPC line of sight and interaction raycasts.

## What the player body collides with when moving.
const PLAYER_MOVE_MASK: int = WORLD | PROP_DYNAMIC

## What the interaction sensor looks for.
const INTERACT_MASK: int = INTERACTABLE | NPC

## What blocks an interaction raycast from reaching its target.
const INTERACT_BLOCK_MASK: int = WORLD | SIGHT_BLOCKER
