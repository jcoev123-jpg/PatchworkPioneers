class_name RunV3FloorBandRoster
extends RefCounted
## Scene-free V3-2 normal-enemy group sampler. It selects enemy IDs only; HP
## and damage stay with the already accepted floor-band stat scaling
## (RunNormalAttackFloorScaling), and no Fight route is launched here.
##
## pick(floor_number, desired_count, rng, pools_by_band) -> Dictionary
##   floor_number: int 1-11 only. Floors 1-4 use "1-4", 5-8 use "5-8" and 9-11
##     use "9-11"; floor 12 is Boss-only and any other value is rejected.
##   desired_count: int 2-4 inclusive.
##   rng: the run's seeded RandomNumberGenerator. It is the only randomness
##     source; nothing else is seeded, randomized or read.
##   pools_by_band: Dictionary with the three exact interval keys "1-4",
##     "5-8" and "9-11". Every band must be an Array of at least four
##     distinct, nonempty, already trimmed String IDs. Extra eligible IDs are
##     allowed and later appended enemies need no fixed total or slot.
## Every band is validated before any RNG draw, so a malformed unused band
## still rejects the call without consuming randomness.
##
## Success: {"ok": true, "band": band_key, "enemy_ids": Array} where
## band_key is one of the three exact interval keys and enemy_ids holds
## exactly desired_count distinct IDs from that band, without replacement.
## Rejection: {"ok": false, "band": "", "enemy_ids": []}.
##
## Selection is order-invariant: the chosen band's candidate IDs are
## duplicated and sorted, then exactly desired_count calls to
## RandomNumberGenerator.randi_range(0, remaining.size() - 1) pick one ID each
## and remove it. Caller arrays and dictionaries are never mutated and the
## returned array is detached.
##
## Four IDs are future data only: CombatEnemies.MAX_ENEMIES stays 3 and this
## service never builds a battle roster.

const BAND_LOW := "1-4"
const BAND_MID := "5-8"
const BAND_HIGH := "9-11"
const BAND_KEYS := ["1-4", "5-8", "9-11"]
const MIN_IDS_PER_BAND := 4
const MIN_GROUP_SIZE := 2
const MAX_GROUP_SIZE := 4
const FAILURE := {"ok": false, "band": "", "enemy_ids": []}


func pick(floor_number: Variant, desired_count: Variant, rng: Variant,
		pools_by_band: Variant) -> Dictionary:
	if typeof(floor_number) != TYPE_INT or typeof(desired_count) != TYPE_INT:
		return FAILURE.duplicate(true)
	var floor: int = floor_number
	var count: int = desired_count
	if count < MIN_GROUP_SIZE or count > MAX_GROUP_SIZE:
		return FAILURE.duplicate(true)
	var band := _band_for_floor(floor)
	if band.is_empty():
		return FAILURE.duplicate(true)
	if not rng is RandomNumberGenerator:
		return FAILURE.duplicate(true)
	if not pools_by_band is Dictionary:
		return FAILURE.duplicate(true)

	# Validate every band, not only the requested one, before consuming RNG.
	var validated := _validated_bands(pools_by_band)
	if validated.is_empty() or not validated.has(band):
		return FAILURE.duplicate(true)
	var remaining: Array = validated[band]
	if remaining.size() < count:
		return FAILURE.duplicate(true)

	var selected: Array = []
	for _draw in range(count):
		var index: int = rng.randi_range(0, remaining.size() - 1)
		selected.append(remaining[index])
		remaining.remove_at(index)
	return {"ok": true, "band": band, "enemy_ids": selected}


## Sorted copies of every band's candidate IDs, or {} when any band is
## malformed. Every band in BAND_KEYS is required to be present and clean.
static func _validated_bands(pools_by_band: Dictionary) -> Dictionary:
	var validated := {}
	for band in BAND_KEYS:
		if not pools_by_band.has(band):
			return {}
		var candidates = pools_by_band[band]
		if not candidates is Array or candidates.size() < MIN_IDS_PER_BAND:
			return {}
		var ids: Array = []
		for id in candidates:
			if not id is String or id.is_empty() or id != id.strip_edges():
				return {}
			if id in ids:
				return {}
			ids.append(id)
		ids.sort()
		validated[band] = ids
	return validated


## "" for every value that is not an ordinary normal-Fight floor.
static func _band_for_floor(floor: int) -> String:
	if floor >= 1 and floor <= 4:
		return BAND_LOW
	if floor >= 5 and floor <= 8:
		return BAND_MID
	if floor >= 9 and floor <= 11:
		return BAND_HIGH
	return ""
