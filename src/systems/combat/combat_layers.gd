class_name CombatLayers
extends RefCounted
## The combat fork's physics layers (C3.1). `Layers` (upstream, `src/core/util/layers.gd`) names
## layers 1 to 10; this names the two the fork adds, so upstream's file is never edited.
##
## IN PLAIN WORDS: a HITBOX is the area a swing or a spell covers for a moment; a HURTBOX is the
## area on a fighter that can be hit. A hitbox's mask is the hurtbox layer, so the physics
## engine reports exactly "this swing touched that fighter", and nothing else (walls, NPCs,
## interactables) ever enters the question.
##
## These constants mirror `[layer_names]` in `project.godot`, `3d_physics/layer_11` and
## `layer_12`. `combat_input_test.gd` fails if the two ever disagree.
##
## OWNS: the hitbox and hurtbox layer bits and their masks.
## MUST NOT: name a layer upstream owns; use `Layers` for those.

const HITBOX: int = 1 << 10   ## Layer 11: a swing, a projectile, a blast. Lives for a moment.
const HURTBOX: int = 1 << 11  ## Layer 12: the part of a fighter that can be hit.

## What a hitbox detects: hurtboxes only.
const HITBOX_MASK: int = HURTBOX
## What a hurtbox detects: nothing. It is found by hitboxes, it does not look.
const HURTBOX_MASK: int = 0
