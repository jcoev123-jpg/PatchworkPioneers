class_name StitchedWrenGifts
extends RefCounted
## Design v4 S12: Wren's gifts (data/kid/gifts.json) on top of his four basic hands.
##
## The catalog is data; StitchedRules owns every effect (StitchedRules.use_hand_action) and
## StitchedRunSession owns the run's slots, pool and seeded offers. This helper loads and
## validates the pool, draws a seeded 1-of-3 offer and keeps the between-runs profile.

const PATH := "res://data/kid/gifts.json"
const PROFILE_PATH := "user://wren_gifts_profile.json"
const STAGED_SUFFIX := ".tmp"
const SLOTS := 4
const OFFER_SIZE := 3
const TARGETS := ["doll", "foe", "none"]
const RARITIES := ["common", "uncommon", "rare"]
const UNLOCKS := ["start", "floor_4", "floor_8", "boss"]
## Every effect StitchedRules knows how to resolve; a gift outside this list never loads.
const EFFECTS := [
	"snip_string", "tug", "shove", "flick_button", "blow_candle", "hug", "cover_eyes", "pinch",
	"knot", "brush_off", "point", "tangle_thread", "lullaby", "quick_stitch", "tip_over", "whisper",
	"nightlight",
]

static var _cache: Dictionary = {}


## {"ok", "by_id": {id: gift}, "order": [basics then gifts], "weights", "elite_weights"}.
## The four basic hands join as common, always-unlocked gifts that are never offered.
static func catalog() -> Dictionary:
	if _cache.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		_cache = validate(JSON.parse_string(file.get_as_text()) if file != null else null)
	return _cache.duplicate(true)


static func validate(document: Variant) -> Dictionary:
	var basics := StitchedKidHandActions.catalog()
	if not bool(basics.get("ok", false)):
		return {"ok": false, "error": str(basics.get("error", "hand actions missing"))}
	if not document is Dictionary or not document.get("gifts") is Array:
		return {"ok": false, "error": "gifts need a gifts array"}
	var weights := _weights(document.get("rarity_weights"))
	var elite := _weights(document.get("elite_rarity_weights"))
	if weights.is_empty() or elite.is_empty():
		return {"ok": false, "error": "gifts need common/uncommon/rare weights"}
	var by_id := {}
	var order: Array = []
	for id in basics.order:
		var basic: Dictionary = basics.by_id[id].duplicate(true)
		basic.merge({"rarity": "common", "unlock": "start", "once_per_fight": false, "icon": "hand_" + id, "basic": true})
		by_id[id] = basic
		order.append(id)
	for entry in document.gifts:
		if not entry is Dictionary or not entry.get("id") in EFFECTS or by_id.has(entry.get("id")):
			return {"ok": false, "error": "unknown or repeated gift " + str(entry.get("id") if entry is Dictionary else entry)}
		if not entry.get("name") is String or not entry.get("text") is String or not entry.get("icon") is String \
				or not entry.get("target") in TARGETS or not entry.get("rarity") in RARITIES \
				or not entry.get("unlock") in UNLOCKS or not entry.get("once_per_fight") is bool:
			return {"ok": false, "error": "malformed gift " + str(entry.id)}
		if RegEx.create_from_string(r"\d").search(str(entry.text)) != null:
			return {"ok": false, "error": "gift text shows no numbers: " + str(entry.id)}
		var gift: Dictionary = entry.duplicate(true)
		gift["basic"] = false
		by_id[entry.id] = gift
		order.append(entry.id)
	return {"ok": true, "by_id": by_id, "order": order, "weights": weights, "elite_weights": elite}


static func _weights(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var out := {}
	for rarity in RARITIES:
		if not (value.get(rarity) is float or value.get(rarity) is int) or int(value[rarity]) <= 0:
			return {}
		out[rarity] = int(value[rarity])
	return out


static func gift(id: String) -> Dictionary:
	return catalog().get("by_id", {}).get(id, {})


static func is_gift(id: String) -> bool:
	return catalog().get("by_id", {}).has(id)


## The hand picture for a slot; new gifts borrow one of the four basic hands until drawn.
static func icon_path(id: String) -> String:
	var own := "res://assets/paper/kid/gift_%s.png" % id
	if ResourceLoader.exists(own):
		return own
	return "res://assets/paper/kid/%s.png" % str(gift(id).get("icon", "hand_steady"))


static func basics() -> Array:
	return StitchedKidHandActions.IDS.duplicate()


## Gifts any run may offer given a profile {"best_floor": int, "boss_wins": int}.
static func pool_for(profile: Dictionary) -> Array:
	var book := catalog()
	var out: Array = []
	if not bool(book.get("ok", false)):
		return out
	var floor_reached := int(profile.get("best_floor", 0))
	var bosses := int(profile.get("boss_wins", 0))
	for id in book.order:
		var entry: Dictionary = book.by_id[id]
		if bool(entry.basic):
			continue
		var open := false
		match str(entry.unlock):
			"start": open = true
			"floor_4": open = floor_reached >= 4
			"floor_8": open = floor_reached >= 8
			"boss": open = bosses >= 1
		if open:
			out.append(id)
	return out


## True when every id is a known, non-basic gift and none repeats.
static func valid_pool(pool: Variant) -> bool:
	if not pool is Array:
		return false
	var seen := {}
	for id in pool:
		if not id is String or not is_gift(id) or bool(gift(id).basic) or seen.has(id):
			return false
		seen[id] = true
	return true


## True when slots holds at most SLOTS distinct known ids; basic hands count too.
static func valid_slots(slots: Variant) -> bool:
	if not slots is Array or slots.size() > SLOTS:
		return false
	var seen := {}
	for id in slots:
		if not id is String or not is_gift(id) or seen.has(id):
			return false
		seen[id] = true
	return true


## Up to three distinct gifts from pool minus slots, drawn by rarity weight on a private RNG so
## the run's own draws never move. Same seed and offer index -> the same three gifts.
## A forged, repeated or basic pool entry, or unknown, repeated or over-capacity slots, yield
## an empty offer: a malformed input must never look like a seeded choice.
static func draw_offer(seed_number: int, offer_index: int, pool: Array, slots: Array, elite: bool) -> Array:
	var book := catalog()
	if not bool(book.get("ok", false)):
		return []
	if not valid_pool(pool) or not valid_slots(slots):
		return []
	var weights: Dictionary = book.elite_weights if elite else book.weights
	var left: Array = []
	for id in pool:
		if not id in slots and is_gift(id):
			left.append(id)
	left.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_number, offer_index, "wren_gifts"])
	var out: Array = []
	while out.size() < OFFER_SIZE and not left.is_empty():
		var total := 0
		for id in left:
			total += int(weights[book.by_id[id].rarity])
		var roll := rng.randi_range(1, total)
		for index in left.size():
			roll -= int(weights[book.by_id[left[index]].rarity])
			if roll <= 0:
				out.append(left[index])
				left.remove_at(index)
				break
	return out


static func load_profile(path: String = PROFILE_PATH) -> Dictionary:
	var profile := {"best_floor": 0, "boss_wins": 0}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return profile
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for key in profile:
			if parsed.get(key) is float or parsed.get(key) is int:
				profile[key] = maxi(0, int(parsed[key]))
	return profile


## Records a run's progress; returns the gifts this newly opens for later runs.
## The new profile is staged beside the accepted file, verified byte for byte and
## value for value, then renamed into place, so the accepted file is never opened
## for a truncating write: a failed stage or publish keeps the previous good
## profile and opens nothing.
static func record_progress(floor_reached: int, boss_won: bool, path: String = PROFILE_PATH) -> Array:
	var before := load_profile(path)
	var after := before.duplicate()
	after.best_floor = maxi(int(before.best_floor), floor_reached)
	if boss_won:
		after.boss_wins = int(before.boss_wins) + 1
	if after == before:
		return []
	# A missing profile is a genuine first run and may be created from the default
	# progress. An existing file whose bytes do not read as a profile is kept exactly
	# as it is: without its true progress nothing is guessed, overwritten or opened.
	if FileAccess.file_exists(path) and not _reads_as_profile(path):
		return []
	if not _publish_profile(path, JSON.stringify(after), after):
		return []
	# Unlock differences are derived only from the profile the publish verified.
	var opened: Array = []
	var old_pool := pool_for(before)
	for id in pool_for(after):
		if not id in old_pool:
			opened.append(id)
	return opened


## True when the file's bytes parse into a profile dictionary the way load_profile reads it.
static func _reads_as_profile(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed is Dictionary


## Stages the payload beside the accepted profile, proves the staged bytes and values,
## renames the stage over the destination and proves the published file: any failure
## leaves the previously accepted bytes in place and consumes the disposable stage.
static func _publish_profile(path: String, payload: String, after: Dictionary) -> bool:
	var staged := path + STAGED_SUFFIX
	var file := FileAccess.open(staged, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(payload)
	file.close()
	if not _staged_profile_matches(staged, payload, after):
		DirAccess.remove_absolute(staged)
		return false
	# The previously accepted profile is the exact state a failed publish must leave
	# in the file, so its bytes are read before any replace happens.
	var had_prior := FileAccess.file_exists(path)
	var prior := PackedByteArray()
	if had_prior:
		var previous := FileAccess.open(path, FileAccess.READ)
		if previous != null:
			prior = previous.get_buffer(previous.get_length())
			previous.close()
	# The staged bytes hold the complete new profile. The rename itself replaces the
	# old target, which is never removed first, so a failed replace leaves the
	# previously accepted profile intact.
	if DirAccess.rename_absolute(staged, path) != OK:
		DirAccess.remove_absolute(staged)
		return false
	# A fresh readback of the published file proves later runs load exactly the new
	# progress, never stale or partial bytes.
	var published := FileAccess.open(path, FileAccess.READ)
	if published == null:
		_undo_replaced_publish(path, had_prior, prior)
		return false
	var readback := published.get_buffer(published.get_length())
	published.close()
	if readback == payload.to_utf8_buffer():
		return true
	# A readback that fails its proof after the replace is still a failed publish:
	# the previously accepted profile goes back byte for byte.
	_undo_replaced_publish(path, had_prior, prior)
	return false


## A staged candidate only counts when its fresh readback holds the complete bytes
## and parses into exactly the expected progress. JSON reads whole numbers as
## floats, so the values are compared as the integer progress they must carry.
static func _staged_profile_matches(staged: String, payload: String, after: Dictionary) -> bool:
	var file := FileAccess.open(staged, FileAccess.READ)
	if file == null:
		return false
	var readback := file.get_buffer(file.get_length())
	file.close()
	if readback != payload.to_utf8_buffer():
		return false
	var parsed: Variant = JSON.parse_string(readback.get_string_from_utf8())
	if not parsed is Dictionary or parsed.size() != after.size():
		return false
	for key in after:
		if not (parsed.get(key) is float or parsed.get(key) is int) or int(parsed[key]) != int(after[key]):
			return false
	return true


## Best-effort rollback of a publish whose final verification failed after the
## replace: put the previously accepted profile's exact bytes back, or remove the
## published file again when no prior profile existed.
static func _undo_replaced_publish(path: String, had_prior: bool, prior: PackedByteArray) -> void:
	if not had_prior:
		DirAccess.remove_absolute(path)
		return
	if prior.is_empty():
		return
	var restored := FileAccess.open(path, FileAccess.WRITE)
	if restored == null:
		return
	restored.store_buffer(prior)
	restored.close()
