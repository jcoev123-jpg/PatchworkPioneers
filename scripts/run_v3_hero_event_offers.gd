class_name RunV3HeroEventOffers
extends RefCounted
## Scene-free admission only; these events are not yet wired into live play.
## A service is an immutable party/catalog snapshot. Each entry creates a new
## visit; RunEventChoice owns that visit's wallet receipt and one-claim latch.

const CATALOG_PATH := "res://data/events/v3_hero_choice_events.json"
const HERO_IDS := ["warden", "seamstress", "tinker", "lantern_monk",
	"rag_duelist", "scarecrow", "yarn_ranger", "button_golem"]
## Legacy cards runs field exactly three heroes; a Design v4 Stitched run picks
## four of eight and places them in ranks 1-4. This admission helper
## authenticates initial roster membership only, never rank, HP or aliveness.
const PARTY_SIZES := [3, 4]

var _eligible: Dictionary = {}
var _party_ids: Array[String] = []
var _valid := false


## catalog_data can reorder/subset the authored catalog for deterministic fixtures;
## it cannot introduce or alter records. Invalid input rejects the whole catalog.
func _init(party_ids: Variant = null, catalog_data: Variant = null) -> void:
	if not party_ids is Array:
		return
	var roster: Array = party_ids
	if not PARTY_SIZES.has(roster.size()):
		return
	var party := {}
	var bound_ids: Array[String] = []
	for hero in roster:
		if not hero is String or not HERO_IDS.has(hero) or party.has(hero):
			return
		party[hero] = true
		bound_ids.append(hero)
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return
	var authored: Variant = parser.data
	if not authored is Dictionary or not authored.get("events") is Array:
		return
	var canonical := {}
	for record in authored["events"]:
		if not _valid_record(record) or canonical.has(record["id"]):
			return
		canonical[record["id"]] = record
	var source: Variant = authored if catalog_data == null else catalog_data
	if not source is Dictionary or not source.get("events") is Array:
		return
	if source["events"].is_empty():
		return
	var seen := {}
	var eligible := {}
	for record in source["events"]:
		if not _valid_record(record):
			return
		var event_id: String = record["id"]
		if seen.has(event_id) or not canonical.has(event_id) or record != canonical[event_id]:
			return
		seen[event_id] = true
		if party.has(record["required_hero"]):
			eligible[event_id] = record.duplicate(true)
	_eligible = eligible
	_party_ids = bound_ids
	_valid = true


func is_valid() -> bool:
	return _valid


func get_offers() -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	for event_id in _eligible:
		offers.append(_eligible[event_id].duplicate(true))
	return offers


## Records (including altered returned offers), unknown and stale IDs cannot
## authorize entry. Null means admission failed; no visit or claim was made.
func enter(event_id: Variant) -> RunEventChoice:
	if not _valid or not event_id is String or not _eligible.has(event_id):
		return null
	return RunEventChoice.new(_eligible[event_id])


## Direct admission path for 4-hero Stitched services.
## Accepts a canonical eligible event ID and an explicitly provided native Array of
## distinct String IDs from this service's four-hero party, returning a fresh valid
## RunEventChoice only when the record's required_hero is not LOST.
## Returns null before constructing a visit on invalid service, wrong-size/malformed/
## duplicated/out-of-party lost_ids, unauthorized/forged event_id, or when required_hero is LOST.
func enter_stitched_survivor(event_id: Variant = null, lost_ids: Variant = null) -> RunEventChoice:
	if not _valid or _party_ids.size() != 4:
		return null
	if not (event_id is String) or not _eligible.has(event_id):
		return null
	var lost_set: Variant = _parse_lost_ids(lost_ids)
	if lost_set == null:
		return null
	var record: Dictionary = _eligible[event_id]
	if (lost_set as Dictionary).has(record.get("required_hero")):
		return null
	return RunEventChoice.new(record)


func _collect_actionable_ids(wallet: Variant, excluded_ids: Variant, lost_set: Dictionary = {}) -> Array[String]:
	if not _valid_wallet(wallet):
		return []
	var excluded := {}
	if excluded_ids != null:
		if typeof(excluded_ids) != TYPE_ARRAY:
			return []
		for item in excluded_ids:
			if not (item is String) or (item as String).strip_edges().is_empty():
				return []
			excluded[item] = true
	var actionable_ids: Array[String] = []
	for event_id in _eligible:
		var record: Dictionary = _eligible[event_id]
		if not lost_set.is_empty() and lost_set.has(record.get("required_hero")):
			continue
		if excluded.has(event_id):
			continue
		var selector := RunEventChoice.new(record)
		if not selector.is_valid():
			return []
		var preview := selector.preview_wallet_choices(wallet)
		if not preview.get("ok", false):
			return []
		if _has_affordable_non_leave_choice(preview):
			actionable_ids.append(event_id)
	actionable_ids.sort()
	return actionable_ids


## Uniformly samples one party-eligible authored event that is not in excluded_ids
## and has at least one affordable non-Leave choice for wallet.
## Rejects with {ok: false, event: {}} without advancing rng when the service,
## rng, excluded_ids or wallet is invalid, or when no actionable record remains.
func select_actionable_event(rng: Variant, excluded_ids: Variant = null, wallet: Variant = null) -> Dictionary:
	var rejected := {"ok": false, "event": {}}
	if not _valid or not (rng is RandomNumberGenerator) or not _valid_wallet(wallet):
		return rejected
	var actionable_ids := _collect_actionable_ids(wallet, excluded_ids)
	if actionable_ids.is_empty():
		return rejected
	var index: int = (rng as RandomNumberGenerator).randi_range(0, actionable_ids.size() - 1)
	var chosen_id: String = actionable_ids[index]
	return {"ok": true, "event": _eligible[chosen_id].duplicate(true)}


## Uniformly samples one party-eligible authored event that is not in excluded_ids
## and has at least one affordable non-Leave choice for wallet, returning the
## detached canonical event record and an authentic RunEventChoice wallet preview.
## Rejects with {ok: false, event: {}, preview: {}} without advancing rng when the
## service, rng, excluded_ids or wallet is invalid, or when no actionable record remains.
func select_actionable_event_with_preview(rng: Variant, excluded_ids: Variant = null, wallet: Variant = null) -> Dictionary:
	var rejected := {"ok": false, "event": {}, "preview": {}}
	var selection := select_actionable_event(rng, excluded_ids, wallet)
	if not selection.get("ok", false):
		return rejected
	var selected_event: Variant = selection.get("event")
	if not selected_event is Dictionary:
		return rejected
	var event_id: Variant = selected_event.get("id")
	if not event_id is String or not _eligible.has(event_id):
		return rejected
	var visit := enter(event_id)
	if visit == null or not visit.is_valid():
		return rejected
	var preview := visit.preview_wallet_choices(wallet)
	if not preview.get("ok", false) or preview.get("event_id") != event_id:
		return rejected
	return {
		"ok": true,
		"event": (selected_event as Dictionary).duplicate(true),
		"preview": preview.duplicate(true),
	}


## Uniformly samples one surviving party-eligible authored event that is not in
## excluded_ids, whose required_hero is not in lost_ids, and has at least one
## affordable non-Leave choice for wallet. Valid only for 4-hero Stitched services.
## Returns detached canonical event record and an authentic RunEventChoice wallet preview.
## Rejects with {ok: false, event: {}, preview: {}} without advancing rng when the
## service, rng, lost_ids, excluded_ids or wallet is invalid, or when no actionable record remains.
func select_stitched_survivor_event_with_preview(
	rng: Variant,
	lost_ids: Variant = null,
	excluded_ids: Variant = null,
	wallet: Variant = null
) -> Dictionary:
	var outcome := select_stitched_survivor_visit_with_preview(rng, lost_ids, excluded_ids, wallet)
	if not outcome.get("ok", false):
		return {"ok": false, "event": {}, "preview": {}}
	return {
		"ok": true,
		"event": (outcome["event"] as Dictionary).duplicate(true),
		"preview": (outcome["preview"] as Dictionary).duplicate(true),
	}


## Uniformly samples one surviving party-eligible authored event that is not in
## excluded_ids, whose required_hero is not in lost_ids, and has at least one
## affordable non-Leave choice for wallet. Valid only for 4-hero Stitched services.
## Returns detached canonical event record, an authentic RunEventChoice wallet preview,
## and a fresh valid unclaimed RunEventChoice visit for the chosen ID.
## Rejects with {ok: false, event: {}, preview: {}, visit: null} without advancing rng when the
## service, rng, lost_ids, excluded_ids or wallet is invalid, or when no actionable record remains.
func select_stitched_survivor_visit_with_preview(
	rng: Variant,
	lost_ids: Variant = null,
	excluded_ids: Variant = null,
	wallet: Variant = null
) -> Dictionary:
	var rejected := {"ok": false, "event": {}, "preview": {}, "visit": null}
	if not _valid or _party_ids.size() != 4:
		return rejected
	if not (rng is RandomNumberGenerator) or not _valid_wallet(wallet):
		return rejected
	var lost_set: Variant = _parse_lost_ids(lost_ids)
	if lost_set == null:
		return rejected
	var actionable_ids := _collect_actionable_ids(wallet, excluded_ids, lost_set as Dictionary)
	if actionable_ids.is_empty():
		return rejected
	var index: int = (rng as RandomNumberGenerator).randi_range(0, actionable_ids.size() - 1)
	var chosen_id: String = actionable_ids[index]
	var visit := enter_stitched_survivor(chosen_id, lost_ids)
	if visit == null or not visit.is_valid():
		return rejected
	var preview := visit.preview_wallet_choices(wallet)
	if not preview.get("ok", false) or preview.get("event_id") != chosen_id:
		return rejected
	return {
		"ok": true,
		"event": _eligible[chosen_id].duplicate(true),
		"preview": preview.duplicate(true),
		"visit": visit,
	}


func _parse_lost_ids(lost_ids: Variant) -> Variant:
	if not _valid or _party_ids.size() != 4:
		return null
	if typeof(lost_ids) != TYPE_ARRAY:
		return null
	var lost_set := {}
	for item in lost_ids:
		if not (item is String):
			return null
		var hero_id: String = item
		if not _party_ids.has(hero_id) or lost_set.has(hero_id):
			return null
		lost_set[hero_id] = true
	return lost_set


func _valid_wallet(wallet: Variant) -> bool:
	if typeof(wallet) != TYPE_DICTIONARY:
		return false
	var dict: Dictionary = wallet
	if dict.size() != 2 or not dict.has("gold") or not dict.has("scraps"):
		return false
	var gold: Variant = dict.get("gold")
	var scraps: Variant = dict.get("scraps")
	if typeof(gold) != TYPE_INT or typeof(scraps) != TYPE_INT:
		return false
	return int(gold) >= 0 and int(scraps) >= 0


func _has_affordable_non_leave_choice(preview: Dictionary) -> bool:
	var choices: Variant = preview.get("choices")
	if not choices is Array:
		return false
	for choice in choices:
		if choice is Dictionary and choice.get("choice_id") != "leave" and choice.get("affordable") == true:
			return true
	return false


func _valid_record(record: Variant) -> bool:
	if not record is Dictionary:
		return false
	var selector := RunEventChoice.new(record)
	if not selector.is_valid():
		return false
	var hero: Variant = record.get("required_hero")
	if not hero is String or not HERO_IDS.has(hero):
		return false
	var hero_choices: Variant = record.get("hero_choice_ids")
	if not hero_choices is Array:
		return false
	var remaining := {}
	var has_leave := false
	for choice in record["choices"]:
		if choice["id"] == "leave":
			has_leave = true
		else:
			remaining[choice["id"]] = true
	if not has_leave or hero_choices.size() != remaining.size():
		return false
	for choice_id in hero_choices:
		if not choice_id is String or not remaining.has(choice_id):
			return false
		remaining.erase(choice_id)
	# Use the wallet authority's parser without claiming or requiring affordability.
	var preview := selector.preview_wallet_choices({"gold": 0, "scraps": 0})
	for choice in preview["choices"]:
		if choice["gold_delta"] == null or choice["scraps_delta"] == null:
			return false
	return remaining.is_empty()
