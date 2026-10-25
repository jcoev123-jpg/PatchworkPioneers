extends RefCounted
## Shared, implementation-independent floor-band oracle for mounted tests.
## It reads only the authored ordinary normal-enemy catalogs and restates the
## documented live band rule: order the actors by authored max HP and then ID,
## then split them into three consecutive bands with the larger remainder first.
## Never import the entry service's own band helpers here.

const NORMAL_CATALOGS := [
    "res://data/enemies/starter_enemies.json",
    "res://data/enemies/run_enemies.json",
]

static var _records: Dictionary = {}
static var _bands: Dictionary = {}


static func records() -> Dictionary:
	if not _records.is_empty():
		return _records
	for path in NORMAL_CATALOGS:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Array:
			continue
		for record in parsed:
			if not record is Dictionary or not record.get("id") is String:
				continue
			var copy: Dictionary = record.duplicate(true)
			if copy.get("max_hp") is float:
				copy["max_hp"] = int(copy["max_hp"])
			_records[copy["id"]] = copy
	return _records


static func bands() -> Dictionary:
	if not _bands.is_empty():
		return _bands
	var entries: Array = []
	for enemy_id in records():
		entries.append({"id": enemy_id, "max_hp": int(records()[enemy_id]["max_hp"])})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["max_hp"] != b["max_hp"]:
			return a["max_hp"] < b["max_hp"]
		return a["id"] < b["id"])
	var ids: Array = []
	for entry in entries:
		ids.append(entry["id"])
	if ids.size() < 12:
		return {}
	var low_end := int(ceilf(ids.size() / 3.0))
	var mid_end := low_end + int(ceilf((ids.size() - low_end) / 2.0))
	_bands = {
		"1-4": ids.slice(0, low_end),
		"5-8": ids.slice(low_end, mid_end),
		"9-11": ids.slice(mid_end, ids.size()),
	}
	return _bands


static func band_for_floor(floor_number: int) -> String:
	if floor_number >= 1 and floor_number <= 4:
		return "1-4"
	if floor_number >= 5 and floor_number <= 8:
		return "5-8"
	if floor_number >= 9 and floor_number <= 11:
		return "9-11"
	return ""


static func band_ids(floor_number: int) -> Array:
	var key := band_for_floor(floor_number)
	if key.is_empty() or not bands().has(key):
		return []
	return bands()[key]


## Exactly `count` shrinking-array draws on the supplied generator.
static func group(floor_number: int, count: int, rng: RandomNumberGenerator) -> Array:
	var remaining: Array = band_ids(floor_number).duplicate()
	remaining.sort()
	var chosen: Array = []
	for _draw in range(count):
		if remaining.is_empty():
			return []
		var index: int = rng.randi_range(0, remaining.size() - 1)
		chosen.append(remaining[index])
		remaining.remove_at(index)
	return chosen


## The live Fight admission order on one oracle generator: one sorted encounter
## draw, then exactly one floor-band draw per authored schedule source.
static func fight(oracle_rng: RandomNumberGenerator, floor_number: int,
		encounter_ids: Array, arity_for: Callable) -> Dictionary:
	var sorted: Array = encounter_ids.duplicate()
	sorted.sort()
	if sorted.is_empty():
		return {}
	var chosen: String = sorted[oracle_rng.randi_range(0, sorted.size() - 1)]
	var arity: int = int(arity_for.call(chosen))
	if arity <= 0:
		return {}
	return {"encounter_id": chosen, "arity": arity,
		"group": group(floor_number, arity, oracle_rng)}


## True when every ID is a distinct member of that floor's band.
static func legal_group(ids: Array, floor_number: int) -> bool:
	var band := band_ids(floor_number)
	var seen: Array = []
	for enemy_id in ids:
		if not enemy_id is String or enemy_id in seen or not band.has(enemy_id):
			return false
		seen.append(enemy_id)
	return not seen.is_empty()
