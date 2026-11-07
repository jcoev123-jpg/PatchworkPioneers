class_name StitchedSewnPatches
extends RefCounted
## Design v4 S13: every part shows as a cloth patch sewn on the doll's head, arms, torso or
## legs (data/sewn_patches.json). The doll's picture never changes; the patch picture
## does. Hidden depth, never shown as numbers:
## - THREAD: two worn patches of one thread give a small bonus, all four a whole-cloth bonus.
## - BREAK-IN: a patch worn on the same doll for a few fights sits better (sooner in the
##   doll's favoured slot).
## - ILL-FITTING: a foe's patch outside the favoured slot adds a little fray at fight start.
## Torn patches count for nothing. StitchedRules adds the bonus to a hero's stats and the run
## session keeps the wear record and the fight-start fray.

const PATH := "res://data/sewn_patches.json"
const ART := "res://assets/paper/stitched/patches/"
const THREADS := ["crimson", "indigo", "bone", "ash"]
const SLOTS := ["head", "arms", "torso", "legs"]

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
		_cache = parsed if parsed is Dictionary else {"threads": {}}
	return _cache


static func thread_of(part_id: String) -> String:
	return str(data().get("threads", {}).get(part_id, ""))


static func is_foe_patch(part_id: String) -> bool:
	return part_id in data().get("foe_patches", [])


static func favoured_slot(hero_id: String) -> String:
	return str(data().get("favoured", {}).get(hero_id, ""))


## Thread -> how many untorn worn patches carry it.
static func thread_counts(parts: Dictionary) -> Dictionary:
	var counts := {}
	for slot in parts:
		var worn: Variant = parts[slot]
		if not worn is Dictionary or bool(worn.get("torn", false)):
			continue
		var thread := thread_of(str(worn.get("id", "")))
		if not thread.is_empty():
			counts[thread] = int(counts.get(thread, 0)) + 1
	return counts


## The thread the name plate's knot shows: a whole cloth first, else the first pair; "" for none.
static func set_thread(parts: Dictionary) -> String:
	var counts := thread_counts(parts)
	for thread in THREADS:
		if int(counts.get(thread, 0)) >= SLOTS.size():
			return thread
	for thread in THREADS:
		if int(counts.get(thread, 0)) >= 2:
			return thread
	return ""


static func whole_cloth(parts: Dictionary) -> bool:
	var thread := set_thread(parts)
	return not thread.is_empty() and int(thread_counts(parts).get(thread, 0)) >= SLOTS.size()


## True once the patch in this slot has been worn by this doll for enough fights.
static func broken_in(hero_id: String, slot: String, worn: Dictionary, wear: Dictionary) -> bool:
	var record: Variant = wear.get(slot, {})
	if not record is Dictionary or str(record.get("id", "")) != str(worn.get("id", "")):
		return false
	var needed := int(data().get("broken_in_fights_favoured" if slot == favoured_slot(hero_id) else "broken_in_fights", 3))
	return int(record.get("fights", 0)) >= needed


## The hidden stat bonus for one hero: thread sets plus broken-in patches.
static func hidden_bonus(hero_id: String, parts: Dictionary, wear: Dictionary = {}) -> Dictionary:
	var totals := {}
	var counts := thread_counts(parts)
	for thread in counts:
		var count := int(counts[thread])
		if count >= SLOTS.size():
			_add(totals, data().get("whole_cloth_bonus", {}).get(thread, {}))
		elif count >= 2:
			_add(totals, data().get("pair_bonus", {}).get(thread, {}))
	for slot in parts:
		var worn: Variant = parts[slot]
		if worn is Dictionary and not bool(worn.get("torn", false)) and broken_in(hero_id, slot, worn, wear):
			_add(totals, data().get("broken_in_bonus", {}).get(slot, {}))
	return totals


## Fray a doll takes at fight start for each foe patch worn outside its favoured slot.
static func ill_fitting_fray(hero_id: String, parts: Dictionary) -> int:
	var total := 0
	for slot in parts:
		var worn: Variant = parts[slot]
		if worn is Dictionary and not bool(worn.get("torn", false)) \
				and is_foe_patch(str(worn.get("id", ""))) and slot != favoured_slot(hero_id):
			total += int(data().get("ill_fitting_fray", 0))
	return total


## The wear record after one more fight: a patch still in its slot counts up, a new one starts at 1.
static func wear_after_fight(parts: Dictionary, wear: Dictionary) -> Dictionary:
	var next := {}
	for slot in parts:
		var worn: Variant = parts[slot]
		if not worn is Dictionary:
			continue
		var id := str(worn.get("id", ""))
		var record: Variant = wear.get(slot, {})
		var fights := int(record.get("fights", 0)) if record is Dictionary and str(record.get("id", "")) == id else 0
		next[slot] = {"id": id, "fights": fights + 1}
	return next


## The patch picture for a part: its own picture when drawn, else the plain patch for its slot.
static func icon_path(part_id: String, slot: String) -> String:
	var own := ART + part_id + ".png"
	if ResourceLoader.exists(own):
		return own
	var plain := ART + "patch_" + slot + ".png"
	return plain if ResourceLoader.exists(plain) else ""


## Tier II gets a double-stitched border, tier III gold thread; tier I is the plain patch.
static func border_path(tier: int) -> String:
	var path := ART + "border_%d.png" % tier
	return path if tier >= 2 and ResourceLoader.exists(path) else ""


static func knot_path(thread: String) -> String:
	var path := ART + "knot_" + thread + ".png"
	return path if not thread.is_empty() and ResourceLoader.exists(path) else ""


static func _add(totals: Dictionary, bonus: Variant) -> void:
	if bonus is Dictionary:
		for key in bonus:
			totals[key] = int(totals.get(key, 0)) + int(bonus[key])
