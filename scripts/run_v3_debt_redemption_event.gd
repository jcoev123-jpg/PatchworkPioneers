class_name RunV3DebtRedemptionEvent
extends RefCounted
## Scene-free V3-4 Unsewing Booth event helper (v3_frayed_debt_redemption).
##
## Uses res://data/events/v3_debt_redemption.json as the sole canonical choice
## and price source. Accepts a detached 6-key run snapshot:
##   {"deck", "descriptors", "next_stitch_id", "gold", "scraps", "prior_removals"}
## Authenticates the deck, stitched descriptor registry and allocator cursor via
## RunRestStitchCards and the Frayed Debt curse contract via MpwFrayedDebt.
##
## Preview is read-only and returns detached per-choice forecasts with
## affordable/denied status and projected snapshot fields. Choosing requires the
## exact opening source snapshot, revalidates the selected authored choice,
## settles on a fresh copy, latches at most once, and consumes no RNG.

const EVENT_PATH := "res://data/events/v3_debt_redemption.json"
const EVENT_ID := "v3_frayed_debt_redemption"
const EVENT_TITLE := "The Unsewing Booth"

const CHOICE_CUT_DEBT := "cut_debt"
const CHOICE_SELL_OFFCUTS := "sell_offcuts"
const CHOICE_LEAVE := "leave"

const EFFECT_REMOVE_CURSE := "remove_curse"
const EFFECT_WALLET := "wallet"
const EFFECT_NONE := "none"

const MAX_INT := 9223372036854775807
const MAX_SAFE_FLOAT_INT := 9007199254740992.0

const SNAPSHOT_KEYS := [
	"deck",
	"descriptors",
	"next_stitch_id",
	"gold",
	"scraps",
	"prior_removals",
]

var _valid := false
var _consumed := false
var _event: Dictionary = {}
var _source: Dictionary = {}
var _current: Dictionary = {}
var _last_choice_id: String = ""
var _last_effect_kind: String = ""
var _last_removed_index: int = -1
var _last_removed_card_id: String = ""
var _last_gold_delta: int = 0
var _last_scraps_delta: int = 0
var _last_receipt: String = ""


func _init(source_snapshot: Variant = null, event_record: Variant = null, curse_catalog: Variant = null) -> void:
	if source_snapshot != null:
		prepare(source_snapshot, event_record, curse_catalog)


## Loads and parses the shipped JSON event record from disk as a detached Dictionary.
static func load_authored_event() -> Dictionary:
	if not FileAccess.file_exists(EVENT_PATH):
		return {}
	var file := FileAccess.open(EVENT_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	return (parsed as Dictionary).duplicate(true)


## True while prepared with a valid source snapshot and event record and unclaimed.
func is_valid() -> bool:
	return _valid and not _consumed


## True once prepared with a valid source snapshot and event record.
func is_prepared() -> bool:
	return _valid


## True once one valid choice has been settled and latched.
func is_consumed() -> bool:
	return _consumed


## Alias for is_consumed().
func is_claimed() -> bool:
	return _consumed


## Detached copy of the validated authored event record, or {} when unprepared.
func get_event() -> Dictionary:
	if not _valid:
		return {}
	return _event.duplicate(true)


## Detached copy of the opening 6-key source snapshot, or {} when unprepared.
func get_source_snapshot() -> Dictionary:
	if not _valid:
		return {}
	return _source.duplicate(true)


## Detached copy of the current 6-key snapshot (opening state before claim,
## settled state after claim), or {} when unprepared.
func get_current_snapshot() -> Dictionary:
	if not _valid:
		return {}
	return _current.duplicate(true)


## Prepares this visit from a detached opening snapshot. A failed preparation
## leaves the instance unprepared so a subsequent valid preparation can succeed;
## once prepared, re-preparing is rejected without mutating state.
func prepare(source_snapshot: Variant, event_record: Variant = null, curse_catalog: Variant = null) -> Dictionary:
	if _valid or _consumed:
		return _build_receipt(false, "", "", -1, "", 0, 0)
	var raw_event: Variant = load_authored_event() if event_record == null else event_record
	var parsed_event := _parse_and_validate_event(raw_event, curse_catalog)
	if not parsed_event.get("ok", false):
		return _build_receipt(false, "", "", -1, "", 0, 0)
	var parsed_source := _parse_source_snapshot(source_snapshot, curse_catalog)
	if not parsed_source.get("ok", false):
		return _build_receipt(false, "", "", -1, "", 0, 0)
	_event = (parsed_event["event"] as Dictionary).duplicate(true)
	_source = (parsed_source["snapshot"] as Dictionary).duplicate(true)
	_current = _source.duplicate(true)
	_valid = true
	return _build_receipt(true, "", "", -1, "", 0, 0)


## Read-only forecast of all three authored choices against the opening snapshot.
## Never mutates caller containers, service state, or RNG.
func preview_choices(event_override: Variant = null, curse_catalog: Variant = null) -> Dictionary:
	var denied := {
		"ok": false,
		"event_id": "",
		"title": "",
		"description": "",
		"choices": [],
		"by_id": {},
		"source_snapshot": get_source_snapshot(),
	}
	if not _valid or _consumed:
		return denied
	var active_event: Dictionary = _event
	if event_override != null:
		var check_event := _parse_and_validate_event(event_override, curse_catalog)
		if not check_event.get("ok", false):
			return denied
		active_event = check_event["event"]
	elif curse_catalog != null:
		var recheck_event := _parse_and_validate_event(_event, curse_catalog)
		if not recheck_event.get("ok", false):
			return denied
	var recheck_source := _parse_source_snapshot(_source, curse_catalog)
	if not recheck_source.get("ok", false):
		return denied

	var forecasts: Array[Dictionary] = []
	var by_id: Dictionary = {}
	var choices: Array = active_event.get("choices", [])
	for choice_raw: Variant in choices:
		var choice: Dictionary = choice_raw
		var projection := _project_choice(_source, choice, curse_catalog)
		var entry := _format_choice_forecast(choice, projection)
		forecasts.append(entry)
		by_id[String(choice["id"])] = entry.duplicate(true)
	return {
		"ok": true,
		"event_id": String(active_event["id"]),
		"title": String(active_event["title"]),
		"description": String(active_event["description"]),
		"choices": forecasts,
		"by_id": by_id,
		"source_snapshot": get_source_snapshot(),
	}


## Convenience read-only forecast for a single named choice ID, or {ok: false} if unknown/invalid.
func preview_choice(choice_id: Variant, event_override: Variant = null, curse_catalog: Variant = null) -> Dictionary:
	if typeof(choice_id) != TYPE_STRING or String(choice_id).is_empty():
		return {"ok": false}
	var all_previews := preview_choices(event_override, curse_catalog)
	if not all_previews.get("ok", false):
		return {"ok": false}
	var by_id: Dictionary = all_previews.get("by_id", {})
	var key: String = choice_id
	if not by_id.has(key):
		return {"ok": false}
	var forecast: Dictionary = (by_id[key] as Dictionary).duplicate(true)
	forecast["ok"] = true
	return forecast


## Settles the selected authored choice at most once when expected_snapshot
## matches the exact opening snapshot and the choice is legal and affordable.
## Any refusal leaves the source snapshot and an unclaimed visit untouched.
func choose(choice_id: Variant, expected_snapshot: Variant = null, event_override: Variant = null, curse_catalog: Variant = null) -> Dictionary:
	if not _valid or _consumed:
		return _build_receipt(false, "", "", -1, "", 0, 0)
	if typeof(choice_id) != TYPE_STRING or String(choice_id).is_empty():
		return _build_receipt(false, "", "", -1, "", 0, 0)
	if not (expected_snapshot is Dictionary) or not _same_snapshot(expected_snapshot, _source):
		return _build_receipt(false, "", "", -1, "", 0, 0)

	var active_event: Dictionary = _event
	if event_override != null:
		var check_event := _parse_and_validate_event(event_override, curse_catalog)
		if not check_event.get("ok", false):
			return _build_receipt(false, "", "", -1, "", 0, 0)
		active_event = check_event["event"]
	else:
		var check_event := _parse_and_validate_event(_event, curse_catalog)
		if not check_event.get("ok", false):
			return _build_receipt(false, "", "", -1, "", 0, 0)

	var check_source := _parse_source_snapshot(_source, curse_catalog)
	if not check_source.get("ok", false):
		return _build_receipt(false, "", "", -1, "", 0, 0)

	var target_id: String = choice_id
	var matched_choice: Dictionary = {}
	var choices: Array = active_event.get("choices", [])
	for choice_raw: Variant in choices:
		if choice_raw is Dictionary and String((choice_raw as Dictionary).get("id", "")) == target_id:
			matched_choice = (choice_raw as Dictionary).duplicate(true)
			break
	if matched_choice.is_empty():
		return _build_receipt(false, "", "", -1, "", 0, 0)

	var projection := _project_choice(_source, matched_choice, curse_catalog)
	if not projection.get("affordable", false):
		return _build_receipt(false, "", "", -1, "", 0, 0)

	var next_snapshot: Dictionary = (projection["snapshot"] as Dictionary).duplicate(true)
	var verify_next := _parse_source_snapshot(next_snapshot, curse_catalog)
	if not verify_next.get("ok", false):
		return _build_receipt(false, "", "", -1, "", 0, 0)

	_current = next_snapshot.duplicate(true)
	_consumed = true
	_last_choice_id = target_id
	_last_effect_kind = String(matched_choice["effect_kind"])
	_last_removed_index = int(projection["removed_index"])
	_last_removed_card_id = String(projection["removed_card_id"])
	_last_gold_delta = int(projection["gold_delta"])
	_last_scraps_delta = int(projection["scraps_delta"])
	_last_receipt = _compute_receipt_hash(_source, target_id, _current)
	return _build_receipt(
		true,
		_last_choice_id,
		_last_effect_kind,
		_last_removed_index,
		_last_removed_card_id,
		_last_gold_delta,
		_last_scraps_delta
	)


func _format_choice_forecast(choice: Dictionary, projection: Dictionary) -> Dictionary:
	var projected_snapshot: Dictionary = (projection["snapshot"] as Dictionary).duplicate(true)
	var affordable: bool = bool(projection.get("affordable", false))
	return {
		"choice_id": String(choice["id"]),
		"id": String(choice["id"]),
		"text": String(choice["text"]),
		"effect_kind": String(choice["effect_kind"]),
		"card_id": String(choice.get("card_id", "")),
		"gold_delta": int(choice["gold"]),
		"scraps_delta": int(choice["scraps"]),
		"affordable": affordable,
		"denied": not affordable,
		"status": "affordable" if affordable else "denied",
		"reason": String(projection.get("reason", "")),
		"removed_index": int(projection.get("removed_index", -1)),
		"removed_card_id": String(projection.get("removed_card_id", "")),
		"snapshot": projected_snapshot.duplicate(true),
		"deck": (projected_snapshot["deck"] as Array).duplicate(),
		"descriptors": (projected_snapshot["descriptors"] as Dictionary).duplicate(true),
		"next_stitch_id": int(projected_snapshot["next_stitch_id"]),
		"gold": int(projected_snapshot["gold"]),
		"scraps": int(projected_snapshot["scraps"]),
		"prior_removals": int(projected_snapshot["prior_removals"]),
	}


func _project_choice(base_snapshot: Dictionary, choice: Dictionary, curse_catalog: Variant = null) -> Dictionary:
	var unchanged := base_snapshot.duplicate(true)
	var effect_kind := String(choice.get("effect_kind", ""))
	var gold_delta := int(choice.get("gold", 0))
	var scraps_delta := int(choice.get("scraps", 0))
	var base_gold := int(base_snapshot["gold"])
	var base_scraps := int(base_snapshot["scraps"])

	if gold_delta < 0 and base_gold < -gold_delta:
		return {
			"affordable": false,
			"reason": "insufficient_gold",
			"gold_delta": gold_delta,
			"scraps_delta": scraps_delta,
			"removed_index": -1,
			"removed_card_id": "",
			"snapshot": unchanged,
		}
	if gold_delta > 0 and gold_delta > MAX_INT - base_gold:
		return {
			"affordable": false,
			"reason": "gold_overflow",
			"gold_delta": gold_delta,
			"scraps_delta": scraps_delta,
			"removed_index": -1,
			"removed_card_id": "",
			"snapshot": unchanged,
		}
	if scraps_delta < 0 and base_scraps < -scraps_delta:
		return {
			"affordable": false,
			"reason": "insufficient_scraps",
			"gold_delta": gold_delta,
			"scraps_delta": scraps_delta,
			"removed_index": -1,
			"removed_card_id": "",
			"snapshot": unchanged,
		}
	if scraps_delta > 0 and scraps_delta > MAX_INT - base_scraps:
		return {
			"affordable": false,
			"reason": "scraps_overflow",
			"gold_delta": gold_delta,
			"scraps_delta": scraps_delta,
			"removed_index": -1,
			"removed_card_id": "",
			"snapshot": unchanged,
		}

	var next_snapshot := base_snapshot.duplicate(true)
	next_snapshot["gold"] = base_gold + gold_delta
	next_snapshot["scraps"] = base_scraps + scraps_delta
	var removed_index := -1
	var removed_card_id := ""

	if effect_kind == EFFECT_REMOVE_CURSE:
		var card_id := String(choice.get("card_id", ""))
		if not _authenticate_curse_id(card_id, curse_catalog):
			return {
				"affordable": false,
				"reason": "invalid_curse",
				"gold_delta": gold_delta,
				"scraps_delta": scraps_delta,
				"removed_index": -1,
				"removed_card_id": "",
				"snapshot": unchanged,
			}
		var deck_copy: Array[String] = []
		deck_copy.assign(next_snapshot["deck"])
		var descriptors_copy: Dictionary = next_snapshot["descriptors"]
		if descriptors_copy.has(card_id):
			return {
				"affordable": false,
				"reason": "invalid_curse",
				"gold_delta": gold_delta,
				"scraps_delta": scraps_delta,
				"removed_index": -1,
				"removed_card_id": "",
				"snapshot": unchanged,
			}
		var first_index := deck_copy.find(card_id)
		if first_index < 0:
			return {
				"affordable": false,
				"reason": "missing_curse",
				"gold_delta": gold_delta,
				"scraps_delta": scraps_delta,
				"removed_index": -1,
				"removed_card_id": "",
				"snapshot": unchanged,
			}
		deck_copy.remove_at(first_index)
		if deck_copy.is_empty():
			return {
				"affordable": false,
				"reason": "empty_deck",
				"gold_delta": gold_delta,
				"scraps_delta": scraps_delta,
				"removed_index": -1,
				"removed_card_id": "",
				"snapshot": unchanged,
			}
		next_snapshot["deck"] = deck_copy
		removed_index = first_index
		removed_card_id = card_id
	elif effect_kind == EFFECT_WALLET or effect_kind == EFFECT_NONE:
		pass
	else:
		return {
			"affordable": false,
			"reason": "invalid_effect",
			"gold_delta": gold_delta,
			"scraps_delta": scraps_delta,
			"removed_index": -1,
			"removed_card_id": "",
			"snapshot": unchanged,
		}

	return {
		"affordable": true,
		"reason": "",
		"gold_delta": gold_delta,
		"scraps_delta": scraps_delta,
		"removed_index": removed_index,
		"removed_card_id": removed_card_id,
		"snapshot": next_snapshot,
	}


func _build_receipt(
		ok: bool,
		choice_id: String,
		effect_kind: String,
		removed_index: int,
		removed_card_id: String,
		gold_delta: int,
		scraps_delta: int) -> Dictionary:
	var snap: Dictionary = _current.duplicate(true) if _valid else {}
	var deck_copy: Array[String] = []
	if snap.has("deck"):
		deck_copy.assign(snap["deck"])
	var descriptors_copy: Dictionary = (snap.get("descriptors", {}) as Dictionary).duplicate(true)
	return {
		"ok": ok,
		"consumed": _consumed,
		"claimed": _consumed,
		"event_id": EVENT_ID if _valid else "",
		"choice_id": choice_id,
		"effect_kind": effect_kind,
		"removed_index": removed_index,
		"removed_card_id": removed_card_id,
		"gold_delta": gold_delta,
		"scraps_delta": scraps_delta,
		"snapshot": snap.duplicate(true),
		"source_snapshot": _source.duplicate(true) if _valid else {},
		"deck": deck_copy,
		"descriptors": descriptors_copy,
		"next_stitch_id": int(snap.get("next_stitch_id", 1)),
		"gold": int(snap.get("gold", 0)),
		"scraps": int(snap.get("scraps", 0)),
		"prior_removals": int(snap.get("prior_removals", 0)),
		"receipt": _last_receipt if (ok or _consumed) else "",
	}


static func _parse_source_snapshot(snapshot: Variant, curse_catalog: Variant = null) -> Dictionary:
	if not (snapshot is Dictionary):
		return {"ok": false}
	var dict: Dictionary = snapshot
	if dict.size() != SNAPSHOT_KEYS.size():
		return {"ok": false}
	for key: String in SNAPSHOT_KEYS:
		if not dict.has(key):
			return {"ok": false}

	var raw_deck: Variant = dict.get("deck")
	var raw_descriptors: Variant = dict.get("descriptors")
	var raw_cursor: Variant = dict.get("next_stitch_id")
	var raw_gold: Variant = dict.get("gold")
	var raw_scraps: Variant = dict.get("scraps")
	var raw_prior: Variant = dict.get("prior_removals")

	if typeof(raw_deck) != TYPE_ARRAY or typeof(raw_descriptors) != TYPE_DICTIONARY:
		return {"ok": false}
	if typeof(raw_cursor) != TYPE_INT or typeof(raw_gold) != TYPE_INT \
			or typeof(raw_scraps) != TYPE_INT or typeof(raw_prior) != TYPE_INT:
		return {"ok": false}

	var cursor: int = raw_cursor
	var gold: int = raw_gold
	var scraps: int = raw_scraps
	var prior_removals: int = raw_prior
	if cursor < 1 or cursor >= MAX_INT or gold < 0 or scraps < 0 or prior_removals < 0:
		return {"ok": false}

	if not _authenticate_curse_id(MpwFrayedDebt.CARD_ID, curse_catalog):
		return {"ok": false}

	var deck_array: Array = raw_deck
	if deck_array.is_empty():
		return {"ok": false}
	var deck_copy: Array[String] = []
	for entry: Variant in deck_array:
		if typeof(entry) != TYPE_STRING or String(entry).is_empty():
			return {"ok": false}
		deck_copy.append(String(entry))

	var descriptors_copy: Dictionary = (raw_descriptors as Dictionary).duplicate(true)
	if descriptors_copy.has(MpwFrayedDebt.CARD_ID):
		return {"ok": false}

	var ledger := RunRestStitchCards.new(deck_copy, descriptors_copy, scraps, cursor)
	if not ledger.is_valid():
		return {"ok": false}

	var owners: Dictionary = {}
	for card_id: String in deck_copy:
		if card_id == MpwFrayedDebt.CARD_ID:
			if not _authenticate_curse_id(card_id, curse_catalog):
				return {"ok": false}
			continue
		if descriptors_copy.has(card_id):
			var desc: Dictionary = descriptors_copy[card_id]
			for owner_id: Variant in desc.get("owners", []):
				if typeof(owner_id) != TYPE_STRING or String(owner_id).is_empty():
					return {"ok": false}
				owners[String(owner_id)] = true
		else:
			var def: Dictionary = RunRestStitchCards.resolve_card_definition(card_id)
			var owner_id: Variant = def.get("owner", "")
			if typeof(owner_id) != TYPE_STRING or String(owner_id).is_empty():
				return {"ok": false}
			owners[String(owner_id)] = true
	if owners.is_empty() or owners.size() > CombatParty.PARTY_SIZE:
		return {"ok": false}

	return {
		"ok": true,
		"snapshot": {
			"deck": deck_copy,
			"descriptors": descriptors_copy,
			"next_stitch_id": cursor,
			"gold": gold,
			"scraps": scraps,
			"prior_removals": prior_removals,
		},
	}


static func _authenticate_curse_id(card_id: Variant, curse_catalog: Variant = null) -> bool:
	if typeof(card_id) != TYPE_STRING or String(card_id) != MpwFrayedDebt.CARD_ID:
		return false
	var canonical_catalog := MpwFrayedDebt.new()
	if canonical_catalog.get_card_ids() != [MpwFrayedDebt.CARD_ID]:
		return false
	var canonical_def := canonical_catalog.get_definition(MpwFrayedDebt.CARD_ID)
	var candidate_def: Dictionary = {}
	if curse_catalog == null:
		candidate_def = canonical_def.duplicate(true)
	elif curse_catalog is Dictionary:
		candidate_def = (curse_catalog as Dictionary).duplicate(true)
	elif curse_catalog is Object and curse_catalog.has_method("get_definition"):
		if curse_catalog.has_method("get_card_ids") and curse_catalog.get_card_ids() != [MpwFrayedDebt.CARD_ID]:
			return false
		var resolved: Variant = curse_catalog.get_definition(card_id)
		if not (resolved is Dictionary):
			return false
		candidate_def = (resolved as Dictionary).duplicate(true)
	else:
		return false

	if candidate_def.is_empty() or not _same_snapshot(candidate_def, canonical_def):
		return false
	return (
		candidate_def.get("id") == MpwFrayedDebt.CARD_ID
		and candidate_def.get("card_type") == "curse"
		and candidate_def.get("playable") == false
		and candidate_def.get("removable") == true
		and candidate_def.get("can_upgrade") == false
		and candidate_def.get("can_stitch") == false
		and candidate_def.get("reward_eligible") == false
		and candidate_def.get("starting_copies") == 0
		and candidate_def.get("exhaust_on_first_draw") == true
		and candidate_def.get("consumes_draw") == true
	)


static func _parse_and_validate_event(record: Variant, curse_catalog: Variant = null) -> Dictionary:
	var canonical := _parse_event_structure(load_authored_event(), curse_catalog)
	if not canonical.get("ok", false):
		return {"ok": false}
	var parsed := _parse_event_structure(record, curse_catalog)
	if not parsed.get("ok", false):
		return {"ok": false}
	if not _same_snapshot(parsed["event"], canonical["event"]):
		return {"ok": false}
	return parsed


static func _parse_event_structure(record: Variant, curse_catalog: Variant = null) -> Dictionary:
	if not (record is Dictionary):
		return {"ok": false}
	var dict: Dictionary = record
	if dict.size() != 4 or not dict.has("id") or not dict.has("title") \
			or not dict.has("description") or not dict.has("choices"):
		return {"ok": false}
	if typeof(dict.get("id")) != TYPE_STRING or String(dict["id"]) != EVENT_ID:
		return {"ok": false}
	if typeof(dict.get("title")) != TYPE_STRING or String(dict["title"]) != EVENT_TITLE:
		return {"ok": false}
	if typeof(dict.get("description")) != TYPE_STRING:
		return {"ok": false}
	var desc := String(dict["description"])
	if desc.strip_edges().is_empty() or not desc.contains("button-eyed clerk") \
			or not desc.contains("unpicking a loaned crimson seam"):
		return {"ok": false}

	var raw_choices: Variant = dict.get("choices")
	if typeof(raw_choices) != TYPE_ARRAY:
		return {"ok": false}
	var choices_list: Array = raw_choices
	if choices_list.size() != 3:
		return {"ok": false}

	var expected_specs := {
		CHOICE_CUT_DEBT: {
			"text": "Pay 18 gold to unpick one Frayed Debt",
			"effect_kind": EFFECT_REMOVE_CURSE,
			"card_id": MpwFrayedDebt.CARD_ID,
			"gold": -18,
			"scraps": 0,
			"key_count": 6,
		},
		CHOICE_SELL_OFFCUTS: {
			"text": "Sell two scrap bundles for 20 gold",
			"effect_kind": EFFECT_WALLET,
			"gold": 20,
			"scraps": -2,
			"key_count": 5,
		},
		CHOICE_LEAVE: {
			"text": "Leave the ledger sealed",
			"effect_kind": EFFECT_NONE,
			"gold": 0,
			"scraps": 0,
			"key_count": 5,
		},
	}
	var expected_order := [CHOICE_CUT_DEBT, CHOICE_SELL_OFFCUTS, CHOICE_LEAVE]
	var normalized_choices: Array[Dictionary] = []
	var seen_ids: Dictionary = {}

	for idx in range(choices_list.size()):
		var raw_choice: Variant = choices_list[idx]
		if not (raw_choice is Dictionary):
			return {"ok": false}
		var choice: Dictionary = raw_choice
		var cid_var: Variant = choice.get("id")
		var text_var: Variant = choice.get("text")
		var kind_var: Variant = choice.get("effect_kind")
		if typeof(cid_var) != TYPE_STRING or typeof(text_var) != TYPE_STRING or typeof(kind_var) != TYPE_STRING:
			return {"ok": false}
		var cid := String(cid_var)
		if cid != expected_order[idx] or seen_ids.has(cid) or not expected_specs.has(cid):
			return {"ok": false}
		seen_ids[cid] = true
		var spec: Dictionary = expected_specs[cid]
		if choice.size() != int(spec["key_count"]):
			return {"ok": false}
		if not choice.has("id") or not choice.has("text") or not choice.has("effect_kind") \
				or not choice.has("gold") or not choice.has("scraps"):
			return {"ok": false}
		if String(text_var) != String(spec["text"]) or String(kind_var) != String(spec["effect_kind"]):
			return {"ok": false}

		var parsed_gold := _read_json_int(choice.get("gold"))
		var parsed_scraps := _read_json_int(choice.get("scraps"))
		if not parsed_gold.get("ok", false) or not parsed_scraps.get("ok", false):
			return {"ok": false}
		var gold_val: int = int(parsed_gold["value"])
		var scraps_val: int = int(parsed_scraps["value"])
		if gold_val != int(spec["gold"]) or scraps_val != int(spec["scraps"]):
			return {"ok": false}

		var normalized_entry := {
			"id": cid,
			"text": String(text_var),
			"effect_kind": String(kind_var),
			"gold": gold_val,
			"scraps": scraps_val,
		}
		if spec.has("card_id"):
			if not choice.has("card_id") or typeof(choice.get("card_id")) != TYPE_STRING:
				return {"ok": false}
			var card_id := String(choice["card_id"])
			if card_id != String(spec["card_id"]) or not _authenticate_curse_id(card_id, curse_catalog):
				return {"ok": false}
			normalized_entry["card_id"] = card_id
		elif choice.has("card_id"):
			return {"ok": false}

		normalized_choices.append(normalized_entry)

	return {
		"ok": true,
		"event": {
			"id": EVENT_ID,
			"title": EVENT_TITLE,
			"description": desc,
			"choices": normalized_choices,
		},
	}


static func _read_json_int(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_INT:
		return {"ok": true, "value": int(value)}
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if not is_finite(number) or absf(number) > MAX_SAFE_FLOAT_INT or floor(number) != number:
			return {"ok": false}
		return {"ok": true, "value": int(number)}
	return {"ok": false}


static func _compute_receipt_hash(source: Dictionary, choice_id: String, settled: Dictionary) -> String:
	return JSON.stringify([
		EVENT_ID,
		choice_id,
		_canonicalize_snapshot(source),
		_canonicalize_snapshot(settled),
	]).sha256_text()


static func _canonicalize_snapshot(snapshot: Dictionary) -> Array:
	var descriptors: Dictionary = snapshot.get("descriptors", {})
	var sorted_ids: Array = descriptors.keys()
	sorted_ids.sort()
	var sorted_registry: Array = []
	for id: Variant in sorted_ids:
		sorted_registry.append([id, descriptors[id]])
	return [
		snapshot.get("deck", []),
		sorted_registry,
		snapshot.get("next_stitch_id", 1),
		snapshot.get("gold", 0),
		snapshot.get("scraps", 0),
		snapshot.get("prior_removals", 0),
	]


static func _same_snapshot(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		var dict_a: Dictionary = a
		var dict_b: Dictionary = b
		if dict_a.size() != dict_b.size():
			return false
		for key: Variant in dict_a:
			if not dict_b.has(key) or not _same_snapshot(dict_a[key], dict_b[key]):
				return false
		return true
	if a is Array:
		var arr_a: Array = a
		var arr_b: Array = b
		if arr_a.size() != arr_b.size():
			return false
		for i in range(arr_a.size()):
			if not _same_snapshot(arr_a[i], arr_b[i]):
				return false
		return true
	return a == b
