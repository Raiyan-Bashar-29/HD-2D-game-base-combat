class_name WetnessModel
extends RefCounted
## How wet the world is, as one 0..1 number that rises in rain and falls back afterwards.
##
## WHY THIS IS A SEPARATE, PURE OBJECT
## Everything else in the weather visuals can be computed from Weather's state in a single
## frame: how many raindrops, how loud the bed, how grey the fog. Drying cannot. "It stopped
## raining forty seconds ago" is memory, and memory is the part that needs assertions. A
## RefCounted with no node, no material and no autoload can be stepped a thousand simulated
## seconds inside a synchronous test — and gotcha 10 says a test cannot wait for a real frame,
## so the node that paints this value could never be asserted on directly.
##
## OWNS: one value and the two rates it moves at.
## MUST NOT: touch a material, a particle, or Weather. It is handed a target each step and
## reports where the value got to. What "wet" means is the caller's decision, not this file's.

## Real seconds from bone dry to fully soaked while it is raining as hard as it can.
const DEFAULT_SOAK: float = 8.0
## Real seconds from fully soaked back to dry once the rain stops. Deliberately much longer
## than the soak: a courtyard that dried as fast as it wetted reads as a light switch, not as
## weather. The asymmetry IS the effect.
const DEFAULT_DRY: float = 26.0

var soak_seconds: float = DEFAULT_SOAK
var dry_seconds: float = DEFAULT_DRY

var _value: float = 0.0


## The current wetness, 0.0 dry to 1.0 soaked.
func wetness() -> float:
	return _value


## Move towards `target` by one frame and return the new value. Rising and falling use
## different rates, which is the entire reason this is not a lerp.
func step(delta: float, target: float) -> float:
	var wanted: float = clampf(target, 0.0, 1.0)
	if wanted > _value:
		_value = minf(wanted, _value + delta / maxf(0.01, soak_seconds))
	else:
		_value = maxf(wanted, _value - delta / maxf(0.01, dry_seconds))
	return _value


## Set the value outright, with no travel. For entering an area that is already in a
## downpour, and for the capture flags that have to photograph one specific moment of a
## dry-out rather than wait twenty-six real seconds for it.
func reset_to(value: float) -> void:
	_value = clampf(value, 0.0, 1.0)


## Run the model forward without frames, so a test — or a screenshot — can ask what the world
## looks like forty seconds after the rain stopped. Stepped in slices rather than solved in
## closed form on purpose: a formula here would be a second implementation of the thing under
## test, and the two would drift.
func advance(seconds: float, target: float, slice: float = 0.05) -> float:
	var left: float = maxf(0.0, seconds)
	var grain: float = maxf(0.001, slice)
	while left > 0.0:
		step(minf(grain, left), target)
		left -= grain
	return _value
