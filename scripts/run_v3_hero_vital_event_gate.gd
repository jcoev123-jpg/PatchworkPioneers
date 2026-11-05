class_name RunV3HeroVitalEventGate
extends RefCounted
## Scene-free, one-visit V3-4 hero-gated vitality crossroad admission and settlement gate.
##
## Validates a legacy three-hero or Design v4 four-hero party of distinct canonical
## IDs; authenticates data/events/v3_hero_vital_events.json;
## admits only when the chosen required hero is present and living (1 <= hp <= max_hp,
## max_hp >= 10). Binds a detached opening snapshot and underlying RunEventChoice, exposing
## a non-claiming preview and a single claim latched by choose_with_vitals.
## No scene dependencies, no direct live state mutation, and no RNG use.

const CATALOG_PATH := "res://data/events/v3_hero_vital_events.json"
const HERO_IDS := [
	"warden",
	"seamstress",
	"tinker",
	"lantern_monk",
	"rag_duelist",
	"scarecrow",
	"yarn_ranger",
	"button_golem",
]
const LEAVE_CHOICE_ID := "leave"
const MIN_VITAL_MAX_HP := 10
## Legacy cards runs field exactly three heroes; a Design v4 Stitched run picks
## four of eight and places them in ranks 1-4. Membership is the distinct ID set,
## never rank, so both party sizes are admitted here.
const PARTY_SIZES := [3, 4]

const REQUIRED_EVENT_IDS := [
	"v3_warden_buckle_heart_ward",
	"v3_seamstress_crimson_quilt_surgeon",
	"v3_tinker_copper_needle_greenhouse",
	"v3_lantern_monk_thimble_moon_vigil",
	"v3_rag_duelist_velvet_straw_mender",
]

const REQUIRED_EVENTS := {
	"v3_warden_buckle_heart_ward": {
		"required_hero": "warden",
		"trades": {
			"reinforce_shield_seam": {"gold": 0, "scraps": -2, "hp": 0, "max_hp": 3},
			"sell_rivets": {"gold": 24, "scraps": 0, "hp": 0, "max_hp": -2},
		},
	},
	"v3_seamstress_crimson_quilt_surgeon": {
		"required_hero": "seamstress",
		"trades": {
			"stitch_wound": {"gold": -12, "scraps": 0, "hp": 8, "max_hp": 0},
			"donate_red_thread": {"gold": 18, "scraps": 0, "hp": -4, "max_hp": 0},
		},
	},
	"v3_tinker_copper_needle_greenhouse": {
		"required_hero": "tinker",
		"trades": {
			"buy_gear_balm": {"gold": -10, "scraps": 0, "hp": 6, "max_hp": 0},
			"harvest_barbed_gears": {"gold": 0, "scraps": 3, "hp": -6, "max_hp": 0},
		},
	},
	"v3_lantern_monk_thimble_moon_vigil": {
		"required_hero": "lantern_monk",
		"trades": {
			"moonlight_seam": {"gold": -16, "scraps": 0, "hp": 0, "max_hp": 2},
			"tend_moth_candles": {"gold": 20, "scraps": 0, "hp": -4, "max_hp": 0},
		},
	},
	"v3_rag_duelist_velvet_straw_mender": {
		"required_hero": "rag_duelist",
		"trades": {
			"mend_cape": {"gold": 0, "scraps": -2, "hp": 10, "max_hp": 0},
			"sell_cape_padding": {"gold": 22, "scraps": 0, "hp": -5, "max_hp": 0},
		},
	},
}

var _valid: bool = false
var _party_ids: Array[String] = []
var _party_set: Dictionary = {}
var _catalog_events: Array[Dictionary] = []
var _catalog_by_id: Dictionary = {}
var _eligible: Dictionary = {}

var _bound_visit: bool = false
var _claimed: bool = false
var _event: Dictionary = {}
var _snapshot: Dictionary = {}
var _choice_service: RunEventChoice = null


## Constructs either a party offers service or a bound single-visit gate.
## When `event_target` and `snapshot` are provided, directly binds a single visit.
## If `event_target` is a catalog dictionary (has "events") and snapshot is null,
## it is treated as `catalog_data`.
func _init(party_ids: Variant = null, event_target: Variant = null, snapshot: Variant = null, catalog_data: Variant = null) -> void:
	if event_target is Dictionary and (event_target as Dictionary).has("events") and snapshot == null and catalog_data == null:
		catalog_data = event_target
		event_target = null

	var parsed_party: Dictionary = _parse_party(party_ids)
	if not parsed_party.get("ok", false):
		return
	_party_ids = parsed_party["party_ids"]
	_party_set = parsed_party["party_set"]

	var parsed_catalog: Dictionary = _load_and_validate_catalog(catalog_data)
	if not parsed_catalog.get("ok", false):
		return
	_catalog_events = parsed_catalog["events"]
	_catalog_by_id = parsed_catalog["by_id"]

	for record: Dictionary in _catalog_events:
		var hero: String = record.get("required_hero", "")
		if _party_set.has(hero):
			_eligible[record["id"]] = record.duplicate(true)

	if event_target != null:
		if not _bind_visit(event_target, snapshot):
			_valid = false
			return
		_valid = true
	else:
		_valid = true


## Loads and parses the shipped catalog from disk as a detached Dictionary.
static func load_shipped_catalog() -> Dictionary:
	if not FileAccess.file_exists(CATALOG_PATH):
		return {}
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {}
	if not (parser.data is Dictionary):
		return {}
	return (parser.data as Dictionary).duplicate(true)


## True while this service or unclaimed visit is schema-valid.
func is_valid() -> bool:
	if _bound_visit:
		return _valid and not _claimed and _choice_service != null and _choice_service.is_valid()
	return _valid


## True once a choice has been committed on this visit.
func is_claimed() -> bool:
	return _claimed and _choice_service != null and _choice_service.is_claimed()


## Returns a detached array of eligible offers whose required hero is in the party.
func get_offers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _valid:
		return result
	for event_id: String in _eligible:
		result.append((_eligible[event_id] as Dictionary).duplicate(true))
	return result


## Detached copy of the bound authored event record (or {} if unbound).
func get_event() -> Dictionary:
	if not _bound_visit or not _valid:
		return {}
	return _event.duplicate(true)


## Bound event ID (or "" if unbound).
func get_event_id() -> String:
	if not _bound_visit or not _valid:
		return ""
	return String(_event.get("id", ""))


## Detached copy of the bound vital snapshot (or {} if unbound).
func get_snapshot() -> Dictionary:
	if not _bound_visit or not _valid:
		return {}
	return _snapshot.duplicate(true)


## Underlying RunEventChoice instance (or null if unbound).
func get_choice_service() -> RunEventChoice:
	return _choice_service


## Admits entry to an offered event for a living snapshot of the required hero.
## Returns a new bound RunV3HeroVitalEventGate visit, or null on any refusal.
func enter(event_target: Variant, snapshot: Variant = null) -> RunV3HeroVitalEventGate:
	if not _valid or event_target == null or snapshot == null:
		return null
	var visit := RunV3HeroVitalEventGate.new(_party_ids, event_target, snapshot, {"events": _catalog_events})
	if visit == null or not visit.is_valid():
		return null
	return visit


## Alias for enter().
func open_visit(event_target: Variant, snapshot: Variant = null) -> RunV3HeroVitalEventGate:
	return enter(event_target, snapshot)


## Read-only vitality choice preview delegating to RunEventChoice.
## Uses the bound snapshot when snapshot is null or omitted.
## Pure paid HP heals where projected HP equals opening HP are marked unaffordable
## with an unchanged projected snapshot.
func preview_vital_choices(snapshot: Variant = null) -> Dictionary:
	var denied := {"ok": false, "event_id": "", "choices": []}
	if not _bound_visit or not is_valid():
		return denied
	var target_snapshot: Dictionary
	if snapshot == null:
		target_snapshot = _snapshot
	else:
		var parsed: Dictionary = _parse_vital_snapshot(snapshot)
		if not parsed.get("ok", false):
			return denied
		if parsed["snapshot"]["hero"]["id"] != _event.get("required_hero", ""):
			return denied
		target_snapshot = parsed["snapshot"]
	var preview: Dictionary = _choice_service.preview_vital_choices(target_snapshot)
	if not preview.get("ok", false):
		return denied
	var raw_choices: Variant = preview.get("choices")
	if not (raw_choices is Array):
		return denied
	var opening_hp: int = target_snapshot["hero"]["hp"]
	var result_choices: Array = []
	for raw_entry: Variant in (raw_choices as Array):
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = (raw_entry as Dictionary).duplicate(true)
		if _is_wasted_paid_heal(entry, opening_hp):
			entry["affordable"] = false
			entry["state"] = target_snapshot.duplicate(true)
		result_choices.append(entry)
	return {
		"ok": true,
		"event_id": String(preview.get("event_id", "")),
		"choices": result_choices,
	}


## Alias for preview_vital_choices().
func preview_choices(snapshot: Variant = null) -> Dictionary:
	return preview_vital_choices(snapshot)


## Commits a single choice on this visit through RunEventChoice.choose_with_vitals().
## Uses the bound snapshot when snapshot is null or omitted.
## Returns {"ok": bool, "event_id": String, "choice_id": String, "state": Dictionary}.
func choose_with_vitals(choice_id: Variant, snapshot: Variant = null) -> Dictionary:
	var target_snapshot: Dictionary
	if snapshot == null:
		target_snapshot = _snapshot
	else:
		var parsed: Dictionary = _parse_vital_snapshot(snapshot)
		if not parsed.get("ok", false):
			return _vital_rejection({})
		if parsed["snapshot"]["hero"]["id"] != _event.get("required_hero", ""):
			return _vital_rejection(parsed["snapshot"])
		target_snapshot = parsed["snapshot"]

	if not _bound_visit or not is_valid() or _claimed:
		return _vital_rejection(target_snapshot)

	if not _is_trimmed_nonblank_string(choice_id):
		return _vital_rejection(target_snapshot)

	var target_id: String = String(choice_id)
	var offered := false
	for choice: Variant in _event.get("choices", []):
		if choice is Dictionary and (choice as Dictionary).get("id") == target_id:
			offered = true
			break
	if not offered:
		return _vital_rejection(target_snapshot)

	var preview: Dictionary = preview_vital_choices(target_snapshot)
	if not preview.get("ok", false):
		return _vital_rejection(target_snapshot)
	var choice_entry: Dictionary = {}
	for c: Variant in preview.get("choices", []):
		if c is Dictionary and (c as Dictionary).get("choice_id") == target_id:
			choice_entry = c
			break
	if choice_entry.is_empty() or not choice_entry.get("affordable", false):
		return _vital_rejection(target_snapshot)

	var settlement: Dictionary = _choice_service.choose_with_vitals(target_id, target_snapshot)
	if not settlement.get("ok", false):
		return _vital_rejection(target_snapshot)

	_claimed = true
	_snapshot = (settlement.get("state", {}) as Dictionary).duplicate(true)
	return {
		"ok": true,
		"event_id": String(settlement.get("event_id", "")),
		"choice_id": target_id,
		"state": _snapshot.duplicate(true),
	}


## Alias for choose_with_vitals().
func choose(choice_id: Variant, snapshot: Variant = null) -> Dictionary:
	return choose_with_vitals(choice_id, snapshot)


## Alias for choose_with_vitals().
func claim_choice(choice_id: Variant, snapshot: Variant = null) -> Dictionary:
	return choose_with_vitals(choice_id, snapshot)


## Opt-in party selector that qualifies unvisited, authenticated hero vitality
## events having at least one affordable non-Leave choice for that event's living
## required hero. Rejects invalid service/bound visits, invalid RNG, malformed
## exclusions, malformed wallet or hero snapshots, mismatched party IDs, all-Torn
## parties, and Leave-only pools before touching RNG.
## Sorts eligible record IDs lexicographically, consumes exactly one
## randi_range(0, eligible.size() - 1) draw on success, and returns a deep detached record.
func select_party_actionable_event(
	rng: Variant,
	excluded_ids: Variant = null,
	wallet: Variant = null,
	heroes: Variant = null
) -> Dictionary:
	var rejection := {"ok": false, "event": {}}
	if not _valid or _bound_visit or _claimed:
		return rejection
	if not (rng is RandomNumberGenerator):
		return rejection

	var parsed_exclusions: Dictionary = _parse_actionable_exclusions(excluded_ids)
	if not parsed_exclusions.get("ok", false):
		return rejection
	var excluded: Dictionary = parsed_exclusions["ids"]

	var parsed_wallet: Dictionary = _parse_actionable_wallet(wallet)
	if not parsed_wallet.get("ok", false):
		return rejection

	var parsed_heroes: Dictionary = _parse_actionable_heroes(heroes)
	if not parsed_heroes.get("ok", false):
		return rejection
	var living_by_id: Dictionary = parsed_heroes["living_by_id"]
	if living_by_id.is_empty():
		return rejection

	var eligible_ids: Array[String] = []
	for event_id: String in _eligible:
		if excluded.has(event_id):
			continue
		var record: Dictionary = _eligible[event_id]
		var req_hero: String = record.get("required_hero", "")
		if not living_by_id.has(req_hero):
			continue
		var hero_info: Dictionary = living_by_id[req_hero]
		var hero_snapshot := {
			"gold": parsed_wallet["gold"],
			"scraps": parsed_wallet["scraps"],
			"hero": {
				"id": hero_info["id"],
				"hp": hero_info["hp"],
				"max_hp": hero_info["max_hp"],
			},
		}
		var choice_service := RunEventChoice.new(record)
		if not choice_service.is_valid():
			continue
		var preview: Dictionary = choice_service.preview_vital_choices(hero_snapshot)
		if not preview.get("ok", false):
			continue
		var choices_raw: Variant = preview.get("choices")
		if not (choices_raw is Array):
			continue
		var has_actionable_choice := false
		for choice_entry_raw: Variant in (choices_raw as Array):
			if not (choice_entry_raw is Dictionary):
				continue
			var choice_entry: Dictionary = choice_entry_raw
			if is_choice_actionable(choice_entry, hero_info["hp"]):
				has_actionable_choice = true
				break
		if has_actionable_choice:
			eligible_ids.append(event_id)

	if eligible_ids.is_empty():
		return rejection

	eligible_ids.sort()
	var generator: RandomNumberGenerator = rng
	var index: int = generator.randi_range(0, eligible_ids.size() - 1)
	var picked_id: String = eligible_ids[index]
	var picked_record: Dictionary = (_eligible[picked_id] as Dictionary).duplicate(true)
	return {
		"ok": true,
		"event": picked_record,
	}


## Row eligibility helper delegating to RunV3VitalEventRotation.is_choice_actionable.
static func is_choice_actionable(entry: Dictionary, opening_hp: int) -> bool:
	return RunV3VitalEventRotation.is_choice_actionable(entry, opening_hp)


## Detects an affordable pure paid HP-heal choice with hp_delta > 0, max_hp_delta == 0,
## gold_delta <= 0, scraps_delta <= 0, at least one strictly negative payment,
## and projected HP equal to opening HP.
static func _is_wasted_paid_heal(entry: Dictionary, opening_hp: int) -> bool:
	if not entry.get("affordable", false):
		return false
	var hp_delta: Variant = entry.get("hp_delta")
	var max_hp_delta: Variant = entry.get("max_hp_delta")
	var gold_delta: Variant = entry.get("gold_delta")
	var scraps_delta: Variant = entry.get("scraps_delta")
	if typeof(hp_delta) != TYPE_INT or typeof(max_hp_delta) != TYPE_INT or typeof(gold_delta) != TYPE_INT or typeof(scraps_delta) != TYPE_INT:
		return false
	var projected_state: Variant = entry.get("state")
	if not (projected_state is Dictionary):
		return false
	var hero_dict: Variant = (projected_state as Dictionary).get("hero")
	if not (hero_dict is Dictionary):
		return false
	var projected_hp: Variant = (hero_dict as Dictionary).get("hp")
	if typeof(projected_hp) != TYPE_INT:
		return false

	return (
		hp_delta > 0
		and max_hp_delta == 0
		and gold_delta <= 0
		and scraps_delta <= 0
		and (gold_delta < 0 or scraps_delta < 0)
		and (projected_hp as int) == opening_hp
	)


func _bind_visit(event_target: Variant, snapshot: Variant) -> bool:
	_bound_visit = true
	_claimed = false
	_event = {}
	_snapshot = {}
	_choice_service = null

	var target_id := ""
	if event_target is String:
		target_id = event_target
		if not _is_trimmed_nonblank_string(target_id) or not _eligible.has(target_id):
			return false
	elif event_target is Dictionary:
		var candidate: Dictionary = event_target
		var validated: Dictionary = _validate_record(candidate)
		if not validated.get("ok", false):
			return false
		target_id = validated["id"]
		if not _eligible.has(target_id):
			return false
		if not _same_value(candidate, _eligible[target_id]):
			return false
	else:
		return false

	var canonical: Dictionary = (_eligible[target_id] as Dictionary).duplicate(true)
	var required_hero: String = canonical.get("required_hero", "")
	if required_hero.is_empty() or not _party_set.has(required_hero):
		return false

	var parsed_snapshot: Dictionary = _parse_vital_snapshot(snapshot)
	if not parsed_snapshot.get("ok", false):
		return false
	var valid_snapshot: Dictionary = parsed_snapshot["snapshot"]
	if valid_snapshot["hero"]["id"] != required_hero:
		return false

	var service := RunEventChoice.new(canonical)
	if not service.is_valid() or service.is_claimed():
		return false

	_event = canonical
	_snapshot = valid_snapshot
	_choice_service = service
	return true


static func _parse_party(party_ids: Variant) -> Dictionary:
	if not (party_ids is Array):
		return {"ok": false}
	var list: Array = party_ids
	if not PARTY_SIZES.has(list.size()):
		return {"ok": false}
	var seen: Dictionary = {}
	var result_ids: Array[String] = []
	for hero: Variant in list:
		if not (hero is String):
			return {"ok": false}
		var hero_id: String = hero
		if not HERO_IDS.has(hero_id) or seen.has(hero_id):
			return {"ok": false}
		seen[hero_id] = true
		result_ids.append(hero_id)
	return {"ok": true, "party_ids": result_ids, "party_set": seen}


static func _parse_vital_snapshot(snapshot: Variant) -> Dictionary:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return {"ok": false}
	var dict: Dictionary = snapshot
	if dict.size() != 3 or not dict.has("gold") or not dict.has("scraps") or not dict.has("hero"):
		return {"ok": false}
	var gold: Variant = dict.get("gold")
	var scraps: Variant = dict.get("scraps")
	if typeof(gold) != TYPE_INT or typeof(scraps) != TYPE_INT:
		return {"ok": false}
	var gold_int: int = gold
	var scraps_int: int = scraps
	if gold_int < 0 or scraps_int < 0:
		return {"ok": false}

	var raw_hero: Variant = dict.get("hero")
	if typeof(raw_hero) != TYPE_DICTIONARY:
		return {"ok": false}
	var hero_dict: Dictionary = raw_hero
	if hero_dict.size() != 3 or not hero_dict.has("id") or not hero_dict.has("hp") or not hero_dict.has("max_hp"):
		return {"ok": false}
	var hero_id_raw: Variant = hero_dict.get("id")
	var hp_raw: Variant = hero_dict.get("hp")
	var max_hp_raw: Variant = hero_dict.get("max_hp")
	if not _is_trimmed_nonblank_string(hero_id_raw) or typeof(hp_raw) != TYPE_INT or typeof(max_hp_raw) != TYPE_INT:
		return {"ok": false}
	var hero_id: String = hero_id_raw
	if not HERO_IDS.has(hero_id):
		return {"ok": false}
	var hp_int: int = hp_raw
	var max_hp_int: int = max_hp_raw
	if hp_int < 1 or max_hp_int < MIN_VITAL_MAX_HP or hp_int > max_hp_int:
		return {"ok": false}

	return {
		"ok": true,
		"snapshot": {
			"gold": gold_int,
			"scraps": scraps_int,
			"hero": {
				"id": hero_id,
				"hp": hp_int,
				"max_hp": max_hp_int,
			},
		},
	}


static func _load_and_validate_catalog(catalog_data: Variant) -> Dictionary:
	var shipped: Dictionary = load_shipped_catalog()
	var parsed_shipped: Dictionary = _parse_catalog_document(shipped, {}, true)
	if not parsed_shipped.get("ok", false):
		return {"ok": false}
	if catalog_data == null:
		return parsed_shipped
	return _parse_catalog_document(catalog_data, parsed_shipped["by_id"], false)


static func _parse_catalog_document(document: Variant, canonical_by_id: Dictionary, require_required_ids: bool) -> Dictionary:
	if typeof(document) != TYPE_DICTIONARY:
		return {"ok": false}
	var dict: Dictionary = document
	if dict.size() != 1 or not dict.has("events"):
		return {"ok": false}
	var raw_events: Variant = dict.get("events")
	if typeof(raw_events) != TYPE_ARRAY:
		return {"ok": false}
	var list: Array = raw_events
	if list.is_empty():
		return {"ok": false}

	var events: Array[Dictionary] = []
	var by_id: Dictionary = {}
	for entry_raw: Variant in list:
		var validated: Dictionary = _validate_record(entry_raw)
		if not validated.get("ok", false):
			return {"ok": false}
		var event_id: String = validated["id"]
		if by_id.has(event_id):
			return {"ok": false}
		var copy: Dictionary = (entry_raw as Dictionary).duplicate(true)
		if not canonical_by_id.is_empty():
			if not canonical_by_id.has(event_id) or not _same_value(copy, canonical_by_id[event_id]):
				return {"ok": false}
		events.append(copy)
		by_id[event_id] = copy

	if require_required_ids:
		for required_id: String in REQUIRED_EVENT_IDS:
			if not by_id.has(required_id):
				return {"ok": false}

	return {
		"ok": true,
		"events": events,
		"by_id": by_id,
	}


static func _validate_record(record_raw: Variant) -> Dictionary:
	if typeof(record_raw) != TYPE_DICTIONARY:
		return {"ok": false}
	var record: Dictionary = record_raw
	if record.size() != 5:
		return {"ok": false}
	for key: String in ["id", "title", "description", "required_hero", "choices"]:
		if not record.has(key):
			return {"ok": false}

	var id_raw: Variant = record.get("id")
	var title_raw: Variant = record.get("title")
	var desc_raw: Variant = record.get("description")
	var hero_raw: Variant = record.get("required_hero")
	if not _is_trimmed_nonblank_string(id_raw) or not _is_nonblank_string(title_raw) or not _is_nonblank_string(desc_raw):
		return {"ok": false}
	if not _is_trimmed_nonblank_string(hero_raw) or not HERO_IDS.has(String(hero_raw)):
		return {"ok": false}

	var choices_raw: Variant = record.get("choices")
	if typeof(choices_raw) != TYPE_ARRAY or (choices_raw as Array).size() != 3:
		return {"ok": false}

	var choices: Array = choices_raw
	var seen_choices: Dictionary = {}
	var has_leave := false
	var trade_count := 0
	for choice_raw: Variant in choices:
		if typeof(choice_raw) != TYPE_DICTIONARY:
			return {"ok": false}
		var choice: Dictionary = choice_raw
		if choice.size() != 3 or not choice.has("id") or not choice.has("text") or not choice.has("outcome"):
			return {"ok": false}
		var cid_raw: Variant = choice.get("id")
		var text_raw: Variant = choice.get("text")
		var outcome_raw: Variant = choice.get("outcome")
		if not _is_trimmed_nonblank_string(cid_raw) or not _is_nonblank_string(text_raw) or typeof(outcome_raw) != TYPE_DICTIONARY:
			return {"ok": false}
		var cid: String = cid_raw
		if seen_choices.has(cid):
			return {"ok": false}
		seen_choices[cid] = true

		var outcome: Dictionary = outcome_raw
		if outcome.size() != 4 or not outcome.has("gold") or not outcome.has("scraps") or not outcome.has("hp") or not outcome.has("max_hp"):
			return {"ok": false}

		for okey: String in ["gold", "scraps", "hp", "max_hp"]:
			var val: Variant = outcome.get(okey)
			if not (typeof(val) == TYPE_INT or (typeof(val) == TYPE_FLOAT and is_finite(val) and floor(val) == val)):
				return {"ok": false}

		if cid == LEAVE_CHOICE_ID:
			has_leave = true
			if int(outcome["gold"]) != 0 or int(outcome["scraps"]) != 0 or int(outcome["hp"]) != 0 or int(outcome["max_hp"]) != 0:
				return {"ok": false}
		else:
			trade_count += 1

	if not has_leave or trade_count != 2:
		return {"ok": false}

	var selector := RunEventChoice.new(record)
	if not selector.is_valid():
		return {"ok": false}

	var event_id: String = id_raw
	if REQUIRED_EVENTS.has(event_id):
		var spec: Dictionary = REQUIRED_EVENTS[event_id]
		if String(hero_raw) != String(spec["required_hero"]):
			return {"ok": false}
		var trades: Dictionary = spec["trades"]
		for trade_id: String in trades:
			if not seen_choices.has(trade_id):
				return {"ok": false}
			var expected_trade: Dictionary = trades[trade_id]
			for choice_raw: Variant in choices:
				var cdict: Dictionary = choice_raw
				if cdict.get("id") == trade_id:
					var out: Dictionary = cdict["outcome"]
					for okey: String in ["gold", "scraps", "hp", "max_hp"]:
						if int(out[okey]) != int(expected_trade[okey]):
							return {"ok": false}

	return {
		"ok": true,
		"id": event_id,
	}


static func _vital_rejection(state: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"event_id": "",
		"choice_id": "",
		"state": state.duplicate(true),
	}


static func _same_value(a: Variant, b: Variant) -> bool:
	if (typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT) and (typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT):
		return is_finite(a) and is_finite(b) and a == b
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		var dict_a: Dictionary = a
		var dict_b: Dictionary = b
		if dict_a.size() != dict_b.size():
			return false
		for key: Variant in dict_a.keys():
			if not dict_b.has(key) or not _same_value(dict_a[key], dict_b[key]):
				return false
		return true
	if a is Array:
		var arr_a: Array = a
		var arr_b: Array = b
		if arr_a.size() != arr_b.size():
			return false
		for i in range(arr_a.size()):
			if not _same_value(arr_a[i], arr_b[i]):
				return false
		return true
	return a == b


static func _is_nonblank_string(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	return not String(value).strip_edges().is_empty()


static func _is_trimmed_nonblank_string(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var text: String = value
	var trimmed: String = text.strip_edges()
	return not trimmed.is_empty() and text == trimmed



static func _parse_actionable_wallet(wallet: Variant) -> Dictionary:
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


func _parse_actionable_heroes(heroes: Variant) -> Dictionary:
	if typeof(heroes) != TYPE_ARRAY:
		return {"ok": false}
	var list: Array = heroes
	# The snapshot must describe the exact party: same count and the same ID set.
	if list.size() != _party_ids.size():
		return {"ok": false}
	var seen_ids: Dictionary = {}
	var living_by_id: Dictionary = {}
	for item: Variant in list:
		if typeof(item) != TYPE_DICTIONARY:
			return {"ok": false}
		var dict: Dictionary = item
		if dict.size() != 3 or not dict.has("id") or not dict.has("hp") or not dict.has("max_hp"):
			return {"ok": false}
		var hero_id_raw: Variant = dict.get("id")
		var hp_raw: Variant = dict.get("hp")
		var max_hp_raw: Variant = dict.get("max_hp")
		if not _is_trimmed_nonblank_string(hero_id_raw) or typeof(hp_raw) != TYPE_INT or typeof(max_hp_raw) != TYPE_INT:
			return {"ok": false}
		var hero_id: String = hero_id_raw
		if not _party_set.has(hero_id):
			return {"ok": false}
		if seen_ids.has(hero_id):
			return {"ok": false}
		seen_ids[hero_id] = true
		var hp_int: int = hp_raw
		var max_hp_int: int = max_hp_raw
		if max_hp_int < MIN_VITAL_MAX_HP:
			return {"ok": false}
		if hp_int < 0 or hp_int > max_hp_int:
			return {"ok": false}
		if hp_int > 0:
			living_by_id[hero_id] = {
				"id": hero_id,
				"hp": hp_int,
				"max_hp": max_hp_int,
			}
	if seen_ids.size() != _party_ids.size():
		return {"ok": false}
	for pid: String in _party_ids:
		if not seen_ids.has(pid):
			return {"ok": false}
	return {"ok": true, "living_by_id": living_by_id}


static func _parse_actionable_exclusions(excluded_ids: Variant) -> Dictionary:
	var ids: Dictionary = {}
	if excluded_ids == null:
		return {"ok": true, "ids": ids}
	if not (excluded_ids is Array):
		return {"ok": false}
	for value: Variant in excluded_ids:
		if not (value is String):
			return {"ok": false}
		var event_id: String = value
		if not _is_trimmed_nonblank_string(event_id):
			return {"ok": false}
		ids[event_id] = true
	return {"ok": true, "ids": ids}
