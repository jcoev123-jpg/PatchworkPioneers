class_name RunV3ServiceWaystationEventGate
extends RefCounted
## Scene-free, one-visit V3-4 Event service-waystation admission and settlement gate.
##
## Reads and validates res://data/events/v3_service_waystation_events.json (or an
## injected catalog dictionary that contains all required waystations and only
## valid unique records). Each visit binds one authenticated catalog record,
## verifies its metadata field `service_choice_id` against the event's offered
## choices, and delegates wallet settlement and the one-claim latch to an internal
## RunEventChoice instance.
##
## Every choice outcome uses RunEventChoice's exact two-key {gold, scraps} contract.
## Claiming the authenticated `service_choice_id` settles the signed cost and returns
## a detached pending `{stop_type: service_kind}` request in `service_request`
## (where service_kind is "Campfire", "SewingCircle", or "Unpicker", never touching
## party, deck, map, or RNG). Claiming the alternate trade or Leave settles the wallet
## and returns `service_request: {}`. Rejections leave the visit unclaimed, mutate no
## caller state, consume no RNG and return `service_request: {}`.

const CATALOG_PATH := "res://data/events/v3_service_waystation_events.json"
const LEAVE_CHOICE_ID := "leave"
const _OMITTED := &"__omitted_event_target__"

const VALID_SERVICE_KINDS := [
	"Campfire",
	"SewingCircle",
	"Unpicker",
]

const REQUIRED_EVENTS := {
	"v3_emberglass_campfire": {
		"title": "The Emberglass Hearth",
		"service_choice_id": "light_the_embers",
		"service_kind": "Campfire",
		"paid_outcome": {"gold": 0, "scraps": -1},
		"trade_choice_id": "sell_cinders",
		"trade_outcome": {"gold": 12, "scraps": 0},
		"leave_choice_id": "leave",
	},
	"v3_threadmill_sewing_circle": {
		"title": "The Threadmill Loft",
		"service_choice_id": "borrow_spools",
		"service_kind": "SewingCircle",
		"paid_outcome": {"gold": -12, "scraps": 0},
		"trade_choice_id": "untie_scraps",
		"trade_outcome": {"gold": 0, "scraps": 2},
		"leave_choice_id": "leave",
	},
	"v3_inkblack_unpicker_van": {
		"title": "The Inkblack Unpicker Van",
		"service_choice_id": "hire_unpicker",
		"service_kind": "Unpicker",
		"paid_outcome": {"gold": -10, "scraps": 0},
		"trade_choice_id": "sell_trim",
		"trade_outcome": {"gold": 0, "scraps": 1},
		"leave_choice_id": "leave",
	},
	"v3_briar_button_mending_bench": {
		"title": "The Briar-Button Hearth",
		"service_choice_id": "fuel_button_fire",
		"service_kind": "Campfire",
		"paid_outcome": {"gold": 0, "scraps": -2},
		"trade_choice_id": "take_rivets",
		"trade_outcome": {"gold": 14, "scraps": 0},
		"leave_choice_id": "leave",
	},
	"v3_moonlace_darning_parlor": {
		"title": "The Moonlace Parlour",
		"service_choice_id": "sew_at_parlor",
		"service_kind": "SewingCircle",
		"paid_outcome": {"gold": 0, "scraps": -2},
		"trade_choice_id": "trade_lace",
		"trade_outcome": {"gold": 10, "scraps": 0},
		"leave_choice_id": "leave",
	},
}

const REQUIRED_EVENT_IDS := [
	"v3_emberglass_campfire",
	"v3_threadmill_sewing_circle",
	"v3_inkblack_unpicker_van",
	"v3_briar_button_mending_bench",
	"v3_moonlace_darning_parlor",
]

var _catalog_valid: bool = false
var _catalog_events: Array[Dictionary] = []
var _catalog_by_id: Dictionary = {}
var _normalized_by_id: Dictionary = {}
var _bound: bool = false
var _valid: bool = false
var _claimed: bool = false
var _event: Dictionary = {}
var _event_id: String = ""
var _service_choice_id: String = ""
var _service_kind: String = ""
var _offered_choice_ids: Dictionary = {}
var _choice_service: RunEventChoice = null


## Builds a catalog-validated gate. When `event_target` (an authored event ID
## String or an authentic event record Dictionary) is supplied, binds this instance as a
## one-visit gate for that event. When `event_target` is omitted, the instance
## validates the catalog and can either be bound once via `prepare()` or spawn
## independent per-visit gates via `open_visit()` / `enter()`.
func _init(event_target: Variant = _OMITTED, catalog_data: Variant = null) -> void:
	_catalog_valid = _load_and_validate_catalog(catalog_data)
	if typeof(event_target) == TYPE_STRING_NAME and event_target == _OMITTED:
		return
	_bind_visit(event_target)


## Loads and parses the shipped JSON catalog from disk as a detached Dictionary.
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


## True when the catalog loaded and all required plus extra records validated.
func is_catalog_valid() -> bool:
	return _catalog_valid


## Detached list of validated catalog records in catalog order.
func get_catalog_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _catalog_valid:
		return result
	for record: Dictionary in _catalog_events:
		result.append(record.duplicate(true))
	return result


## Detached validated catalog record for `event_id`, or `{}` if unknown/invalid.
func get_event_record(event_id: Variant) -> Dictionary:
	if not _catalog_valid or not (event_id is String):
		return {}
	var key: String = event_id
	if not _catalog_by_id.has(key):
		return {}
	return (_catalog_by_id[key] as Dictionary).duplicate(true)


## Picks one authenticated waystation Event record from the catalog using the
## caller's seeded RandomNumberGenerator.
## Returns exactly {"ok": true, "event": deep_detached_record} on success, or
## {"ok": false, "event": {}} with zero RNG draws on any refusal.
func select_event(rng: Variant, excluded_ids: Variant = null) -> Dictionary:
	if not (rng is RandomNumberGenerator):
		return _selection_rejection()
	if not _catalog_valid:
		return _selection_rejection()
	var parsed: Dictionary = _parse_exclusions(excluded_ids)
	if not parsed.get("ok", false):
		return _selection_rejection()
	var excluded: Dictionary = parsed["ids"]
	var eligible: Array = []
	for record: Dictionary in _catalog_events:
		var event_id: String = String(record.get("id", ""))
		if not excluded.has(event_id):
			eligible.append(event_id)
	if eligible.is_empty():
		return _selection_rejection()
	eligible.sort()
	var generator: RandomNumberGenerator = rng
	var picked_id: String = eligible[generator.randi_range(0, eligible.size() - 1)]
	if not _catalog_by_id.has(picked_id):
		return _selection_rejection()
	var selected_record: Dictionary = (_catalog_by_id[picked_id] as Dictionary).duplicate(true)
	return {
		"ok": true,
		"event": selected_record,
	}


static func _selection_rejection() -> Dictionary:
	return {
		"ok": false,
		"event": {},
	}


static func _parse_exclusions(excluded_ids: Variant) -> Dictionary:
	var ids: Dictionary = {}
	if excluded_ids == null:
		return {"ok": true, "ids": ids}
	if not (excluded_ids is Array):
		return {"ok": false}
	for value: Variant in (excluded_ids as Array):
		if not (value is String):
			return {"ok": false}
		var event_id: String = value
		if event_id.strip_edges().is_empty():
			return {"ok": false}
		ids[event_id] = true
	return {"ok": true, "ids": ids}


## Creates a fresh, independent one-visit gate for `event_target` (an event ID
## String or an authentic event record Dictionary). Returns null if rejected.
func open_visit(event_target: Variant) -> RunV3ServiceWaystationEventGate:
	if not _catalog_valid or event_target == null:
		return null
	var visit := RunV3ServiceWaystationEventGate.new(_OMITTED, {"events": get_catalog_events()})
	if not visit._bind_visit(event_target) or not visit.is_valid():
		return null
	return visit


## Alias for `open_visit()`.
func enter(event_target: Variant) -> RunV3ServiceWaystationEventGate:
	return open_visit(event_target)


## Prepares an unbound gate instance for a single visit. Fails closed without
## mutating state if this instance was already bound or claimed.
func prepare(event_target: Variant, catalog_data: Variant = null) -> bool:
	if _bound or _claimed:
		return false
	if catalog_data != null:
		_catalog_valid = _load_and_validate_catalog(catalog_data)
	return _bind_visit(event_target)


## True only while this visit is bound to an authenticated record and unclaimed.
func is_valid() -> bool:
	return (
		_catalog_valid
		and _valid
		and not _claimed
		and _choice_service != null
		and _choice_service.is_valid()
		and not _choice_service.is_claimed()
	)


## True once a choice has been settled and latched on this visit.
func is_claimed() -> bool:
	return _claimed and _choice_service != null and _choice_service.is_claimed()


## Detached deep copy of the bound authored event record (or `{}` if invalid).
func get_event() -> Dictionary:
	if not _valid:
		return {}
	return _event.duplicate(true)


## Bound event ID (or `""` if invalid).
func get_event_id() -> String:
	return _event_id if _valid else ""


## Authenticated service choice ID for the bound event (or `""` if invalid).
func get_service_choice_id() -> String:
	return _service_choice_id if _valid else ""


## Authenticated service kind ("Campfire", "SewingCircle", "Unpicker") or `""` if invalid.
func get_service_kind() -> String:
	return _service_kind if _valid else ""


## Read-only wallet preview delegating directly to RunEventChoice.
func preview_wallet_choices(wallet: Variant) -> Dictionary:
	if not is_valid():
		return {"ok": false, "event_id": "", "choices": []}
	return _choice_service.preview_wallet_choices(wallet)


## Read-only choice preview that includes each choice's pending `service_request`
## (`{"stop_type": service_kind}` for the authenticated service choice, `{}` otherwise).
func preview_choices(wallet: Variant) -> Dictionary:
	var denied := {
		"ok": false,
		"event_id": "",
		"service_choice_id": "",
		"service_kind": "",
		"choices": [],
	}
	if not is_valid():
		return denied
	var raw_preview: Dictionary = _choice_service.preview_wallet_choices(wallet)
	if not raw_preview.get("ok", false):
		return denied
	var entries: Array = []
	for item_raw: Variant in raw_preview.get("choices", []):
		if not (item_raw is Dictionary):
			return denied
		var item: Dictionary = (item_raw as Dictionary).duplicate(true)
		var cid: String = String(item.get("choice_id", ""))
		item["service_request"] = (
			{"stop_type": _service_kind}
			if cid == _service_choice_id
			else {}
		)
		entries.append(item)
	return {
		"ok": true,
		"event_id": _event_id,
		"service_choice_id": _service_choice_id,
		"service_kind": _service_kind,
		"choices": entries,
	}


## Settles one choice on this visit through RunEventChoice.choose_with_wallet().
## Returns a detached receipt:
##   {"ok": bool, "event_id": String, "choice_id": String,
##    "wallet": Dictionary, "service_request": Dictionary}
## where `service_request` is `{"stop_type": service_kind}` only when the authenticated
## `service_choice_id` is successfully claimed, and `{}` on any other branch or
## any rejection.
func choose_with_wallet(choice_id: Variant, wallet: Variant = null) -> Dictionary:
	var parsed_wallet: Dictionary = _parse_wallet(wallet)
	if not parsed_wallet.get("ok", false):
		return _rejection({})
	var base_wallet: Dictionary = parsed_wallet["wallet"]
	if not is_valid():
		return _rejection(base_wallet)
	if not _is_trimmed_nonblank_string(choice_id):
		return _rejection(base_wallet)
	var target_id: String = choice_id
	if not _offered_choice_ids.has(target_id):
		return _rejection(base_wallet)
	if not _offered_choice_ids.has(_service_choice_id):
		return _rejection(base_wallet)
	var settlement: Dictionary = _choice_service.choose_with_wallet(target_id, base_wallet)
	if not settlement.get("ok", false):
		return _rejection(base_wallet)
	_claimed = true
	var settled_wallet: Dictionary = (settlement.get("wallet", {}) as Dictionary).duplicate(true)
	var service_request: Dictionary = (
		{"stop_type": _service_kind}
		if target_id == _service_choice_id
		else {}
	)
	return {
		"ok": true,
		"event_id": String(settlement.get("event_id", "")),
		"choice_id": String(settlement.get("choice_id", "")),
		"wallet": settled_wallet,
		"service_request": service_request,
	}


## Alias for `choose_with_wallet()`.
func choose(choice_id: Variant, wallet: Variant = null) -> Dictionary:
	return choose_with_wallet(choice_id, wallet)


## Alias for `choose_with_wallet()`.
func claim_choice(choice_id: Variant, wallet: Variant = null) -> Dictionary:
	return choose_with_wallet(choice_id, wallet)


func _bind_visit(event_target: Variant) -> bool:
	_bound = true
	_valid = false
	_event = {}
	_event_id = ""
	_service_choice_id = ""
	_service_kind = ""
	_offered_choice_ids = {}
	_choice_service = null
	if not _catalog_valid or _claimed:
		return false
	var target_id: String = ""
	if event_target is String:
		var candidate_id: String = event_target
		if not _is_trimmed_nonblank_string(candidate_id) or not _catalog_by_id.has(candidate_id):
			return false
		target_id = candidate_id
	elif event_target is Dictionary:
		var candidate_record: Dictionary = event_target
		var validated: Dictionary = _validate_record(candidate_record)
		if not validated.get("ok", false):
			return false
		var candidate_id: String = validated["id"]
		if not _normalized_by_id.has(candidate_id):
			return false
		if not _same_value(validated["normalized"], _normalized_by_id[candidate_id]):
			return false
		target_id = candidate_id
	else:
		return false
	var canonical_record: Dictionary = (_catalog_by_id[target_id] as Dictionary).duplicate(true)
	var service_id: Variant = canonical_record.get("service_choice_id")
	var service_k: Variant = canonical_record.get("service_kind")
	if not _is_trimmed_nonblank_string(service_id) or String(service_id) == LEAVE_CHOICE_ID:
		return false
	if not _is_trimmed_nonblank_string(service_k) or not VALID_SERVICE_KINDS.has(String(service_k)):
		return false
	var service := RunEventChoice.new(canonical_record)
	if not service.is_valid() or service.is_claimed():
		return false
	var offered: Dictionary = {}
	var choices_raw: Variant = canonical_record.get("choices")
	if not (choices_raw is Array) or (choices_raw as Array).size() != 3:
		return false
	for choice_raw: Variant in (choices_raw as Array):
		if not (choice_raw is Dictionary):
			return false
		var cid: Variant = (choice_raw as Dictionary).get("id")
		if not _is_trimmed_nonblank_string(cid) or offered.has(String(cid)):
			return false
		offered[String(cid)] = true
	if not offered.has(String(service_id)) or not offered.has(LEAVE_CHOICE_ID):
		return false
	_event = canonical_record
	_event_id = target_id
	_service_choice_id = String(service_id)
	_service_kind = String(service_k)
	_offered_choice_ids = offered
	_choice_service = service
	_valid = true
	return true


func _load_and_validate_catalog(catalog_data: Variant) -> bool:
	_catalog_events = []
	_catalog_by_id = {}
	_normalized_by_id = {}
	var shipped: Dictionary = load_shipped_catalog()
	var parsed_shipped: Dictionary = _parse_catalog_document(shipped, {})
	if not parsed_shipped.get("ok", false):
		return false
	var canonical_normalized: Dictionary = parsed_shipped["normalized_by_id"]
	if catalog_data == null:
		_catalog_events = parsed_shipped["events"]
		_catalog_by_id = parsed_shipped["by_id"]
		_normalized_by_id = canonical_normalized
		return true
	var parsed_custom: Dictionary = _parse_catalog_document(catalog_data, canonical_normalized)
	if not parsed_custom.get("ok", false):
		return false
	_catalog_events = parsed_custom["events"]
	_catalog_by_id = parsed_custom["by_id"]
	_normalized_by_id = parsed_custom["normalized_by_id"]
	return true


static func _parse_catalog_document(document: Variant, canonical_normalized: Dictionary) -> Dictionary:
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
	var normalized_by_id: Dictionary = {}
	for entry_raw: Variant in list:
		var validated: Dictionary = _validate_record(entry_raw)
		if not validated.get("ok", false):
			return {"ok": false}
		var event_id: String = validated["id"]
		if by_id.has(event_id):
			return {"ok": false}
		var normalized_record: Dictionary = validated["normalized"]
		if canonical_normalized.has(event_id):
			if not _same_value(normalized_record, canonical_normalized[event_id]):
				return {"ok": false}
		var copy: Dictionary = (entry_raw as Dictionary).duplicate(true)
		events.append(copy)
		by_id[event_id] = copy
		normalized_by_id[event_id] = normalized_record
	for required_id: String in REQUIRED_EVENT_IDS:
		if not by_id.has(required_id):
			return {"ok": false}
	return {
		"ok": true,
		"events": events,
		"by_id": by_id,
		"normalized_by_id": normalized_by_id,
	}


static func _validate_record(record_raw: Variant) -> Dictionary:
	if typeof(record_raw) != TYPE_DICTIONARY:
		return {"ok": false}
	var record: Dictionary = record_raw
	if record.size() != 6:
		return {"ok": false}
	for key: String in ["id", "title", "description", "service_choice_id", "service_kind", "choices"]:
		if not record.has(key):
			return {"ok": false}
	var event_id_raw: Variant = record.get("id")
	var title_raw: Variant = record.get("title")
	var description_raw: Variant = record.get("description")
	var service_choice_raw: Variant = record.get("service_choice_id")
	var service_kind_raw: Variant = record.get("service_kind")
	if not _is_trimmed_nonblank_string(event_id_raw):
		return {"ok": false}
	if not _is_nonblank_string(title_raw) or not _is_nonblank_string(description_raw):
		return {"ok": false}
	if not _is_trimmed_nonblank_string(service_choice_raw):
		return {"ok": false}
	if not _is_trimmed_nonblank_string(service_kind_raw):
		return {"ok": false}
	var service_kind: String = service_kind_raw
	if not VALID_SERVICE_KINDS.has(service_kind):
		return {"ok": false}
	var event_id: String = event_id_raw
	var service_choice_id: String = service_choice_raw
	if service_choice_id == LEAVE_CHOICE_ID:
		return {"ok": false}
	var choices_raw: Variant = record.get("choices")
	if typeof(choices_raw) != TYPE_ARRAY:
		return {"ok": false}
	var choices: Array = choices_raw
	if choices.size() != 3:
		return {"ok": false}
	var selector := RunEventChoice.new(record)
	if not selector.is_valid():
		return {"ok": false}
	var preview: Dictionary = selector.preview_wallet_choices({"gold": 0, "scraps": 0})
	if not preview.get("ok", false):
		return {"ok": false}
	var preview_choices_raw: Variant = preview.get("choices")
	if typeof(preview_choices_raw) != TYPE_ARRAY or (preview_choices_raw as Array).size() != 3:
		return {"ok": false}
	var deltas_by_id: Dictionary = {}
	for entry_raw: Variant in (preview_choices_raw as Array):
		if typeof(entry_raw) != TYPE_DICTIONARY:
			return {"ok": false}
		var entry: Dictionary = entry_raw
		var cid: Variant = entry.get("choice_id")
		var gold_delta: Variant = entry.get("gold_delta")
		var scraps_delta: Variant = entry.get("scraps_delta")
		if not _is_trimmed_nonblank_string(cid):
			return {"ok": false}
		if typeof(gold_delta) != TYPE_INT or typeof(scraps_delta) != TYPE_INT:
			return {"ok": false}
		deltas_by_id[String(cid)] = {
			"gold": int(gold_delta),
			"scraps": int(scraps_delta),
		}
	var seen_choices: Dictionary = {}
	var normalized_choices: Array = []
	var choice_idx: int = 0
	var trade_choice_id: String = ""
	for choice_raw: Variant in choices:
		if typeof(choice_raw) != TYPE_DICTIONARY:
			return {"ok": false}
		var choice: Dictionary = choice_raw
		if choice.size() != 3 or not choice.has("id") or not choice.has("text") or not choice.has("outcome"):
			return {"ok": false}
		var cid_raw: Variant = choice.get("id")
		var text_raw: Variant = choice.get("text")
		var outcome_raw: Variant = choice.get("outcome")
		if not _is_trimmed_nonblank_string(cid_raw) or not _is_nonblank_string(text_raw):
			return {"ok": false}
		if typeof(outcome_raw) != TYPE_DICTIONARY:
			return {"ok": false}
		var outcome: Dictionary = outcome_raw
		if outcome.size() != 2 or not outcome.has("gold") or not outcome.has("scraps"):
			return {"ok": false}
		var cid: String = cid_raw
		if seen_choices.has(cid) or not deltas_by_id.has(cid):
			return {"ok": false}
		seen_choices[cid] = true
		var delta: Dictionary = deltas_by_id[cid]
		if choice_idx == 0:
			if cid != service_choice_id:
				return {"ok": false}
		elif choice_idx == 1:
			if cid == service_choice_id or cid == LEAVE_CHOICE_ID:
				return {"ok": false}
			trade_choice_id = cid
		elif choice_idx == 2:
			if cid != LEAVE_CHOICE_ID:
				return {"ok": false}
		normalized_choices.append({
			"id": cid,
			"text": String(text_raw),
			"outcome": {
				"gold": int(delta["gold"]),
				"scraps": int(delta["scraps"]),
			},
		})
		choice_idx += 1
	if not seen_choices.has(service_choice_id) or not seen_choices.has(LEAVE_CHOICE_ID) or trade_choice_id.is_empty():
		return {"ok": false}
	var paid_delta: Dictionary = deltas_by_id[service_choice_id]
	var paid_gold: int = int(paid_delta["gold"])
	var paid_scraps: int = int(paid_delta["scraps"])
	# First choice is paid: spend (<= 0) and not both 0
	if paid_gold > 0 or paid_scraps > 0 or (paid_gold == 0 and paid_scraps == 0):
		return {"ok": false}
	# Second choice is reward/trade: gain (>= 0) and not both 0
	var trade_delta: Dictionary = deltas_by_id[trade_choice_id]
	var trade_gold: int = int(trade_delta["gold"])
	var trade_scraps: int = int(trade_delta["scraps"])
	if trade_gold < 0 or trade_scraps < 0 or (trade_gold == 0 and trade_scraps == 0):
		return {"ok": false}
	# Third choice is Leave: zero outcomes
	var leave_delta: Dictionary = deltas_by_id[LEAVE_CHOICE_ID]
	if int(leave_delta["gold"]) != 0 or int(leave_delta["scraps"]) != 0:
		return {"ok": false}

	if REQUIRED_EVENTS.has(event_id):
		var spec: Dictionary = REQUIRED_EVENTS[event_id]
		if service_choice_id != String(spec["service_choice_id"]):
			return {"ok": false}
		if service_kind != String(spec["service_kind"]):
			return {"ok": false}
		if trade_choice_id != String(spec["trade_choice_id"]):
			return {"ok": false}
		var expected_paid: Dictionary = spec["paid_outcome"]
		if paid_gold != int(expected_paid["gold"]) or paid_scraps != int(expected_paid["scraps"]):
			return {"ok": false}
		var expected_trade: Dictionary = spec["trade_outcome"]
		if trade_gold != int(expected_trade["gold"]) or trade_scraps != int(expected_trade["scraps"]):
			return {"ok": false}
	return {
		"ok": true,
		"id": event_id,
		"normalized": {
			"id": event_id,
			"title": String(title_raw),
			"description": String(description_raw),
			"service_choice_id": service_choice_id,
			"service_kind": service_kind,
			"choices": normalized_choices,
		},
	}


static func _parse_wallet(wallet: Variant) -> Dictionary:
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
	return {
		"ok": true,
		"wallet": {
			"gold": gold_int,
			"scraps": scraps_int,
		},
	}


static func _rejection(wallet: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"event_id": "",
		"choice_id": "",
		"wallet": wallet.duplicate(true),
		"service_request": {},
	}


static func _same_value(a: Variant, b: Variant) -> bool:
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
		for index in range(arr_a.size()):
			if not _same_value(arr_a[index], arr_b[index]):
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
