class_name RunV3VitalEventRotation
extends RefCounted
## Scene-free, read-only selector for the authored V3-4 vitality story Events.
##
## The no-argument shipping path reads res://data/events/v3_vital_story_events.json,
## the stable authored pack whose tales carry two or three choices with the exact
## four-key signed outcome {gold, scraps, hp, max_hp}. An injected
## {"events": [...]} document is validated exactly as passed and is never merged
## with the shipped file, so replay and invalid-data fixtures stay reproducible.
##
## This helper only validates the sourced catalog and returns a detached event
## record. The live run owner supplies its own seeded RandomNumberGenerator, its
## own visit history and its own authenticated living hero; this helper never
## creates or reseeds an RNG, records a visit, selects or mutates a hero, or
## settles an outcome. RunEventChoice remains the authority for previews,
## affordability and the one-visit claim once an event has been selected.
##
## Every offered record must be uniquely identified, presentable to
## RunEventChoice and carry parseable vitality outcomes, or the whole source is
## rejected: a malformed required catalog never exposes a partial pool. Future
## appended well-formed entries join the pool automatically, while the count is
## never treated as fixed. Eligibility is always sorted by event ID, so JSON
## order is not a hidden random input and a successful call consumes exactly
## one randi_range(0, eligible_count - 1) draw of the caller's RNG.

const EVENTS_PATH := "res://data/events/v3_vital_story_events.json"

## Named entries already authored in the shipped vitality pack. They must all be
## present exactly once and valid, so a truncated or malformed shipped source
## fails closed instead of pretending the vitality pool is available. Appended
## additions are additive and never need to be listed here.
const REQUIRED_EVENT_IDS := [
	"v3_lantern_quilt_infirmary",
	"v3_button_heart_shrine",
	"v3_needle_thorn_garden",
	"v3_thimble_moon_sanctuary",
	"v3_forgotten_straw_bed",
	"v3_oxblood_stitch_oracle",
	"v3_lacebound_mirror",
	"v3_ashthread_balcony",
	"v3_copper_moon_puppet",
	"v3_bone_cream_wardrobe",
	"v3_mosslit_seam_trial",
	"v3_duskwoven_cocoon",
	"v3_wakeful_darning_house",
	"v3_silver_bobbin_oath",
	"v3_crowshade_hearth",
	"v3_briar_button_sentinel",
	"v3_mossveil_patch_auditor",
	"v3_velvet_moon_ward",
]

## A snapshot shape the vitality parser accepts, used only to ask RunEventChoice
## whether it can parse every authored outcome. It is never settled here.
const VALIDATION_SNAPSHOT := {
	"gold": 0,
	"scraps": 0,
	"hero": {"id": "vital_rotation_validator", "hp": 1, "max_hp": 10},
}

var _catalog_ok: bool = false
## Sorted by ID, detached from the parsed document.
var _pool: Array = []


## Builds and validates the rotation. Pass an injected {"events": [...]}
## document (for replay or invalid-data tests); omit it to read the shipped
## vitality catalog. An absent, unparsable or malformed required source leaves
## the rotation invalid, so every selection fails closed.
func _init(catalog_source: Variant = null) -> void:
	var document: Variant = catalog_source
	if document == null:
		document = _load_shipped_catalog()
	_catalog_ok = _build_pool(document)


## True only when the sourced catalog satisfied every required named record.
func is_catalog_valid() -> bool:
	return _catalog_ok


## Read-only listing of the vitality rotation, sorted by event ID and detached
## from both this instance and the caller. Mutating the result is harmless.
func get_vital_events() -> Array:
	return _pool.duplicate(true)


## Read-only listing of the vitality rotation's event IDs, sorted.
func get_vital_event_ids() -> Array:
	var ids: Array = []
	for record in _pool:
		ids.append(record["id"])
	return ids


## Picks one vitality event uniformly from the eligible pool.
## `rng` is deliberately typed Variant so a wrong or missing caller value
## rejects here instead of failing a typed-argument error at the call site; a
## valid value must be the caller's RandomNumberGenerator (the run's seeded
## instance). `excluded_ids` is an optional Array of previously visited IDs to
## skip and never grows inside this helper.
## Returns exactly {"ok": bool, "event": Dictionary}; a rejection carries an
## empty event, changes no state and consumes no RNG draw. Eligibility is sorted
## by ID, so a successful call consumes precisely one randi_range(0, n - 1).
func select_event(rng: Variant, excluded_ids: Variant = null) -> Dictionary:
	if not rng is RandomNumberGenerator:
		return _rejection()
	if not _catalog_ok:
		return _rejection()
	var parsed: Dictionary = _parse_exclusions(excluded_ids)
	if not parsed.get("ok", false):
		return _rejection()
	var excluded: Dictionary = parsed["ids"]
	var eligible: Array = []
	for record in _pool:
		var event_id: String = record["id"]
		if not excluded.has(event_id):
			eligible.append(event_id)
	if eligible.is_empty():
		return _rejection()
	eligible.sort()
	var generator: RandomNumberGenerator = rng
	var picked_id: String = eligible[generator.randi_range(0, eligible.size() - 1)]
	for record in _pool:
		if record["id"] == picked_id:
			return {"ok": true, "event": record.duplicate(true)}
	return _rejection()


## Opt-in selector that qualifies only unvisited vitality events having at least
## one affordable non-Leave choice for the caller's living hero snapshot
## {gold, scraps, hero: {id, hp, max_hp}}. Rejects invalid RNG, unvalidated
## catalogs, malformed exclusions, invalid snapshots and Leave-only/empty pools
## before any RNG draw. Preserves sorted-ID single-draw uniformity, detached
## returned records and no-settlement semantics.
func select_actionable_event(rng: Variant, excluded_ids: Variant = null, snapshot: Variant = null) -> Dictionary:
	if not rng is RandomNumberGenerator:
		return _rejection()
	if not _catalog_ok:
		return _rejection()
	var parsed: Dictionary = _parse_exclusions(excluded_ids)
	if not parsed.get("ok", false):
		return _rejection()
	var excluded: Dictionary = parsed["ids"]
	var eligible: Array = []
	for record in _pool:
		var event_id: String = record["id"]
		if excluded.has(event_id):
			continue
		if _is_actionable_for_snapshot(record, snapshot):
			eligible.append(event_id)
	if eligible.is_empty():
		return _rejection()
	eligible.sort()
	var generator: RandomNumberGenerator = rng
	var picked_id: String = eligible[generator.randi_range(0, eligible.size() - 1)]
	for record in _pool:
		if record["id"] == picked_id:
			return {"ok": true, "event": record.duplicate(true)}
	return _rejection()


## Opt-in party selector that qualifies unvisited vitality events having at least
## one affordable non-Leave choice for ANY living hero in the caller's three-hero
## party snapshots [{id, hp, max_hp}, ...] and wallet {gold, scraps}. Rejects
## invalid RNG, unvalidated catalogs, malformed exclusions, malformed wallet or
## hero snapshots, and all-Torn/Leave-only pools before any RNG draw. Preserves
## sorted-ID single-draw uniformity, detached returned records and no-settlement
## semantics.
func select_party_actionable_event(
	rng: Variant,
	excluded_ids: Variant = null,
	wallet: Variant = null,
	heroes: Variant = null
) -> Dictionary:
	if not rng is RandomNumberGenerator:
		return _rejection()
	if not _catalog_ok:
		return _rejection()
	var parsed_exclusions: Dictionary = _parse_exclusions(excluded_ids)
	if not parsed_exclusions.get("ok", false):
		return _rejection()
	var parsed_wallet: Dictionary = _parse_party_wallet(wallet)
	if not parsed_wallet.get("ok", false):
		return _rejection()
	var parsed_heroes: Dictionary = _parse_party_heroes(heroes)
	if not parsed_heroes.get("ok", false):
		return _rejection()
	var living_heroes: Array = parsed_heroes["living_heroes"]
	var excluded: Dictionary = parsed_exclusions["ids"]
	var eligible: Array = []
	for record in _pool:
		var event_id: String = record["id"]
		if excluded.has(event_id):
			continue
		if _is_actionable_for_party(record, parsed_wallet, living_heroes):
			eligible.append(event_id)
	if eligible.is_empty():
		return _rejection()
	eligible.sort()
	var generator: RandomNumberGenerator = rng
	var picked_id: String = eligible[generator.randi_range(0, eligible.size() - 1)]
	for record in _pool:
		if record["id"] == picked_id:
			return {"ok": true, "event": record.duplicate(true)}
	return _rejection()


static func _is_actionable_for_party(record: Dictionary, wallet: Dictionary, living_heroes: Array) -> bool:
	for hero in living_heroes:
		var snapshot := {
			"gold": wallet["gold"],
			"scraps": wallet["scraps"],
			"hero": {
				"id": hero["id"],
				"hp": hero["hp"],
				"max_hp": hero["max_hp"],
			},
		}
		if _is_actionable_for_snapshot(record, snapshot):
			return true
	return false


static func _parse_party_wallet(wallet: Variant) -> Dictionary:
	if typeof(wallet) != TYPE_DICTIONARY:
		return {"ok": false}
	var dict: Dictionary = wallet
	if dict.size() != 2 or not dict.has("gold") or not dict.has("scraps"):
		return {"ok": false}
	var gold: Variant = dict.get("gold")
	var scraps: Variant = dict.get("scraps")
	if typeof(gold) != TYPE_INT or typeof(scraps) != TYPE_INT:
		return {"ok": false}
	var gold_int: int = gold
	var scraps_int: int = scraps
	if gold_int < 0 or scraps_int < 0:
		return {"ok": false}
	return {"ok": true, "gold": gold_int, "scraps": scraps_int}


static func _parse_party_heroes(heroes: Variant) -> Dictionary:
	if typeof(heroes) != TYPE_ARRAY:
		return {"ok": false}
	var list: Array = heroes
	if list.size() != 3:
		return {"ok": false}
	var seen_ids: Dictionary = {}
	var living_heroes: Array = []
	for item in list:
		if typeof(item) != TYPE_DICTIONARY:
			return {"ok": false}
		var dict: Dictionary = item
		if dict.size() != 3 or not dict.has("id") or not dict.has("hp") or not dict.has("max_hp"):
			return {"ok": false}
		var hero_id: Variant = dict.get("id")
		var hp: Variant = dict.get("hp")
		var max_hp: Variant = dict.get("max_hp")
		if not _is_nonblank_string(hero_id) or typeof(hp) != TYPE_INT or typeof(max_hp) != TYPE_INT:
			return {"ok": false}
		var id_str: String = hero_id
		if seen_ids.has(id_str):
			return {"ok": false}
		seen_ids[id_str] = true
		var hp_int: int = hp
		var max_hp_int: int = max_hp
		if max_hp_int < 10:
			return {"ok": false}
		if hp_int < 0 or hp_int > max_hp_int:
			return {"ok": false}
		if hp_int > 0:
			living_heroes.append({
				"id": id_str,
				"hp": hp_int,
				"max_hp": max_hp_int,
			})
	if living_heroes.is_empty():
		return {"ok": false}
	return {"ok": true, "living_heroes": living_heroes}


static func _is_actionable_for_snapshot(record: Dictionary, snapshot: Variant) -> bool:
	var service := RunEventChoice.new(record)
	if not service.is_valid():
		return false
	var preview: Dictionary = service.preview_vital_choices(snapshot)
	if not preview.get("ok", false):
		return false
	var choices: Variant = preview.get("choices")
	if not choices is Array:
		return false
	for entry in (choices as Array):
		if not entry is Dictionary:
			return false
		var entry_dict: Dictionary = entry
		var choice_id: Variant = entry_dict.get("choice_id")
		if choice_id is String and choice_id != "leave" and entry_dict.get("affordable", false) == true:
			return true
	return false


func _rejection() -> Dictionary:
	return {"ok": false, "event": {}}


## Null means "no exclusions". Anything other than an Array, or an array with a
## non-String or blank entry, is malformed and rejects the whole call before any
## draw. Unknown but well-formed IDs are ignored: an ID that left the catalog
## can never enter the pool.
func _parse_exclusions(excluded_ids: Variant) -> Dictionary:
	var ids: Dictionary = {}
	if excluded_ids == null:
		return {"ok": true, "ids": ids}
	if not excluded_ids is Array:
		return {"ok": false}
	for value in excluded_ids:
		if not value is String:
			return {"ok": false}
		var event_id: String = value
		if event_id.strip_edges().is_empty():
			return {"ok": false}
		ids[event_id] = true
	return {"ok": true, "ids": ids}


## Validates the complete sourced document and builds the pool. Every entry must
## be an object with a unique nonblank ID, and every record must be presentable
## to RunEventChoice with fully parseable four-key vitality outcomes. Required
## authored IDs must all be present; otherwise the whole rotation fails closed.
func _build_pool(document: Variant) -> bool:
	_pool = []
	if not document is Dictionary:
		return false
	var events: Variant = (document as Dictionary).get("events")
	if not events is Array:
		return false
	if (events as Array).is_empty():
		return false
	var by_id: Dictionary = {}
	for record in events:
		if not record is Dictionary:
			return false
		var raw_id: Variant = (record as Dictionary).get("id")
		if not _is_nonblank_string(raw_id):
			return false
		var event_id: String = raw_id
		if by_id.has(event_id):
			return false
		if not _is_vital_presentable(record):
			return false
		by_id[event_id] = (record as Dictionary).duplicate(true)
	for required_id in REQUIRED_EVENT_IDS:
		if not by_id.has(required_id):
			return false
	var pool: Array = []
	for event_id in by_id.keys():
		pool.append(by_id[event_id])
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["id"]) < String(b["id"]))
	_pool = pool
	return true


## A record is presentable when RunEventChoice accepts its schema and its
## preview parses every authored choice as an exact four-key gold/scraps/hp/
## max_hp outcome. Both checks reuse the existing contracts and leave the
## record untouched.
static func _is_vital_presentable(record: Variant) -> bool:
	if not record is Dictionary:
		return false
	var service := RunEventChoice.new(record)
	if not service.is_valid():
		return false
	var preview: Dictionary = service.preview_vital_choices(VALIDATION_SNAPSHOT)
	if not preview.get("ok", false):
		return false
	var previews: Variant = preview.get("choices")
	var choices: Variant = (record as Dictionary).get("choices")
	if not previews is Array or not choices is Array:
		return false
	if (previews as Array).size() != (choices as Array).size():
		return false
	for entry in previews:
		if not entry is Dictionary:
			return false
		for key in ["gold_delta", "scraps_delta", "hp_delta", "max_hp_delta"]:
			if (entry as Dictionary).get(key) == null:
				return false
	return true


static func _load_shipped_catalog() -> Variant:
	if not FileAccess.file_exists(EVENTS_PATH):
		return null
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return null
	return parser.data


static func _is_nonblank_string(value: Variant) -> bool:
	if not value is String:
		return false
	var text: String = value
	return not text.strip_edges().is_empty()
