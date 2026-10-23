class_name RunDyeVatOutcome
extends RefCounted
## Scene-free one-visit M04 Dye Vat event transaction. It is independent of the
## live Rest-upgrade subsystem and never touches heroes, energy, draw/discard,
## Shop removals, RNG or combat.
##
## The caller passes the CURRENT authoritative run ledger (real deck IDs, the
## genuine stitched descriptor registry, scraps and the allocator cursor). The
## constructor validates the complete mixed ledger through RunRestStitchCards;
## every accepted choice returns a DETACHED proposed ledger and receipts, and
## never mutates the caller's arrays/dictionaries.
##
## 'immerse' replaces exactly one owned, unstitched, unupgraded pool BASE card
## with the exact authored catalog '+' ID (never a guessed suffix) for 3 scraps.
## 'skim_dye' gathers 1 scrap. 'leave' changes nothing. A rejected attempt does
## not latch: the visit stays usable until one valid claim succeeds.

const EVENT_ID: String = "dye_vat"
const CHOICE_IMMERSE: String = "immerse"
const CHOICE_SKIM: String = "skim_dye"
const CHOICE_LEAVE: String = "leave"
const UPGRADE_SCRAP_COST: int = 3
const SKIM_SCRAP_GAIN: int = 1
const LEAVE_SCRAP_GAIN: int = 0
const EVENT_PATH: String = "res://data/events/dye_vat.json"
const EXPECTED_SCRAPS: Dictionary = {
	CHOICE_IMMERSE: -3,
	CHOICE_SKIM: 1,
	CHOICE_LEAVE: 0,
}
const EXPECTED_GOLD: int = 0

var _deck: Array[String] = []
var _descriptors: Dictionary = {}
var _scraps: int = 0
var _next_id: int = 1
var _source_snapshot: Dictionary = {}
var _valid: bool = false
var _claimed: bool = false


## deck_ids: Array of real card IDs (starters, authored pool base/plus cards and
## registered stitched IDs). descriptors: the genuine stitched ledger. scraps and
## next_stitch_id: the run owner's allocator state. event_record: the authored
## dye_vat JSON object; when null the shipped file is loaded.
func _init(deck_ids: Variant = null, descriptors: Variant = null, scraps: Variant = null,
		next_stitch_id: Variant = 1, event_record: Variant = null) -> void:
	if typeof(deck_ids) != TYPE_ARRAY or typeof(descriptors) != TYPE_DICTIONARY:
		return
	var record: Dictionary = {}
	if typeof(event_record) == TYPE_DICTIONARY:
		record = event_record
	elif event_record == null:
		record = load_authored_event()
	if not _validate_event_record(record):
		return
	var ledger := RunRestStitchCards.new(deck_ids, descriptors, scraps, next_stitch_id)
	if not ledger.is_valid():
		return
	var snapshot: Dictionary = ledger.get_snapshot()
	_deck.assign(snapshot["deck"])
	_descriptors = (snapshot["descriptors"] as Dictionary).duplicate(true)
	_scraps = int(snapshot["remaining_scraps"])
	_next_id = int(snapshot["next_stitch_id"])
	_source_snapshot = get_snapshot()
	_valid = true


## The shipped authored dye_vat event object, or {} when it cannot be parsed.
static func load_authored_event() -> Dictionary:
	if not FileAccess.file_exists(EVENT_PATH):
		return {}
	var file := FileAccess.open(EVENT_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func is_valid() -> bool:
	return _valid and not _claimed


func is_claimed() -> bool:
	return _claimed


## A detached view of the untouched source ledger plus claim state.
func get_snapshot() -> Dictionary:
	return {
		"deck": _deck.duplicate(),
		"descriptors": _descriptors.duplicate(true),
		"remaining_scraps": _scraps,
		"next_stitch_id": _next_id,
		"claimed": _claimed,
	}


## Attempts the single allowed claim. Returns a detached receipt; on success
## it carries the proposed deck/descriptors/next_stitch_id/scraps. Rejections
## return ok=false with the unchanged ledger and never latch the visit.
func choose(event_id: Variant = null, choice_id: Variant = null, selected_index: Variant = null) -> Dictionary:
	if not _valid or _claimed:
		return _rejection()
	if typeof(event_id) != TYPE_STRING or String(event_id) != EVENT_ID:
		return _rejection()
	if typeof(choice_id) != TYPE_STRING:
		return _rejection()
	var choice_key: String = choice_id

	if choice_key == CHOICE_SKIM:
		_claimed = true
		var skim := _success_receipt(choice_key)
		skim["scraps"] = _scraps + SKIM_SCRAP_GAIN
		skim["earned_scraps"] = SKIM_SCRAP_GAIN
		skim["receipt"] = _receipt_for(skim)
		return skim

	if choice_key == CHOICE_LEAVE:
		_claimed = true
		var leave := _success_receipt(choice_key)
		leave["earned_scraps"] = LEAVE_SCRAP_GAIN
		leave["receipt"] = _receipt_for(leave)
		return leave

	if choice_key != CHOICE_IMMERSE:
		return _rejection()
	if typeof(selected_index) != TYPE_INT:
		return _rejection()
	var index: int = selected_index
	if index < 0 or index >= _deck.size():
		return _rejection()
	if _scraps < UPGRADE_SCRAP_COST:
		return _rejection()
	var card_id: String = _deck[index]
	var upgrade: Dictionary = resolve_authored_pool_upgrade(card_id)
	if upgrade.is_empty():
		return _rejection()

	var next_deck: Array = []
	next_deck.assign(_deck)
	next_deck[index] = String(upgrade["upgrade_id"])
	_claimed = true
	var result := _success_receipt(choice_key)
	result["deck"] = next_deck
	result["scraps"] = _scraps - UPGRADE_SCRAP_COST
	result["spent_scraps"] = UPGRADE_SCRAP_COST
	result["selected_index"] = index
	result["replaced_card_id"] = card_id
	result["upgrade_card_id"] = String(upgrade["upgrade_id"])
	result["receipt_ids"] = [card_id, String(upgrade["upgrade_id"])]
	result["receipt"] = _receipt_for(result)
	return result


## Resolves a deck entry to its EXACT authored pool upgrade pair, or {} when the
## entry is a starter, an already-plus card, a stitched/composite ID, a
## counterfeit ID or any card whose catalog records do not agree.
static func resolve_authored_pool_upgrade(card_id: Variant) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return {}
	var id: String = card_id
	if id.is_empty() or id.ends_with("_plus"):
		return {}
	if StarterCards.new().has_card(id):
		return {}
	var reward_def: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(id)
	if reward_def.is_empty() or String(reward_def.get("id", "")) != id:
		return {}
	for pool in [WardenPoolCards.new(), SeamstressPoolCards.new(), TinkerPoolCards.new()]:
		var base_ids: Array = []
		if pool.has_method("get_base_ids"):
			base_ids = pool.get_base_ids()
		elif pool.has_method("get_pool_card_ids"):
			base_ids = pool.get_pool_card_ids()
		if not base_ids.has(id):
			continue
		var base: Dictionary = pool.get_definition(id)
		if base.is_empty() or String(base.get("id", "")) != id:
			return {}
		if base.get("is_upgrade") == true or base.get("reward_eligible") == false:
			return {}
		var upgrade_id: String = pool.get_upgrade_id(id)
		if upgrade_id.is_empty() or upgrade_id == id:
			return {}
		if String(base.get("upgrade_id", "")) != upgrade_id:
			return {}
		var plus: Dictionary = pool.get_definition(upgrade_id)
		if plus.is_empty() or String(plus.get("id", "")) != upgrade_id:
			return {}
		if plus.has("base_id") and String(plus.get("base_id", "")) != id:
			return {}
		if not RunRestStitchCards.is_authored_pool_plus(upgrade_id):
			return {}
		return {
			"base_id": id,
			"upgrade_id": upgrade_id,
			"base": base,
			"plus": plus,
		}
	return {}


## Read-only enumeration of legal immerse targets: one entry per actual deck
## occurrence that resolves to an authored pool upgrade. Never mutates state or RNG.
func get_immerse_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if not _valid or _claimed:
		return options
	if _scraps < UPGRADE_SCRAP_COST:
		return options
	for index in range(_deck.size()):
		var upgrade: Dictionary = resolve_authored_pool_upgrade(_deck[index])
		if upgrade.is_empty():
			continue
		options.append({
			"index": index,
			"card_id": String(_deck[index]),
			"upgrade_id": String(upgrade["upgrade_id"]),
			"display_name": String((upgrade["base"] as Dictionary).get("display_name", "")),
		})
	return options


func _success_receipt(choice_key: String) -> Dictionary:
	var plain_deck: Array = []
	plain_deck.assign(_deck)
	return {
		"ok": true,
		"event_id": EVENT_ID,
		"choice_id": choice_key,
		"deck": plain_deck,
		"descriptors": _descriptors.duplicate(true),
		"next_stitch_id": _next_id,
		"scraps": _scraps,
		"spent_scraps": 0,
		"earned_scraps": 0,
		"selected_index": -1,
		"replaced_card_id": "",
		"upgrade_card_id": "",
		"receipt_ids": [],
		"receipt": "",
	}


func _rejection() -> Dictionary:
	var receipt := _success_receipt("")
	receipt["ok"] = false
	receipt["receipt"] = String(_source_snapshot.get("receipt", ""))
	return receipt


func _receipt_for(receipt: Dictionary) -> String:
	var sorted_ids: Array = (receipt["descriptors"] as Dictionary).keys()
	sorted_ids.sort()
	var sorted_registry: Array = []
	for id in sorted_ids:
		sorted_registry.append([id, (receipt["descriptors"] as Dictionary)[id]])
	return JSON.stringify([
		receipt["deck"],
		sorted_registry,
		receipt["scraps"],
		receipt["next_stitch_id"],
	]).sha256_text()


static func _validate_event_record(record: Dictionary) -> bool:
	if record.is_empty():
		return false
	if typeof(record.get("id")) != TYPE_STRING or String(record["id"]) != EVENT_ID:
		return false
	var title: Variant = record.get("title")
	var description: Variant = record.get("description")
	if typeof(title) != TYPE_STRING or String(title).strip_edges().is_empty():
		return false
	if typeof(description) != TYPE_STRING or String(description).strip_edges().is_empty():
		return false
	var choices: Variant = record.get("choices")
	if typeof(choices) != TYPE_ARRAY:
		return false
	var list: Array = choices
	if list.size() != 3:
		return false
	var seen: Dictionary = {}
	for choice_raw: Variant in list:
		if typeof(choice_raw) != TYPE_DICTIONARY:
			return false
		var choice: Dictionary = choice_raw
		var cid: Variant = choice.get("id")
		var text: Variant = choice.get("text")
		var outcome: Variant = choice.get("outcome")
		if typeof(cid) != TYPE_STRING or typeof(text) != TYPE_STRING:
			return false
		var choice_id: String = cid
		if String(text).strip_edges().is_empty() or not EXPECTED_SCRAPS.has(choice_id):
			return false
		if seen.has(choice_id):
			return false
		seen[choice_id] = true
		if typeof(outcome) != TYPE_DICTIONARY:
			return false
		var amounts: Dictionary = outcome
		var gold: Dictionary = _read_authored_amount(amounts.get("gold"))
		var scraps: Dictionary = _read_authored_amount(amounts.get("scraps"))
		if not gold.get("ok", false) or not scraps.get("ok", false):
			return false
		if int(gold["amount"]) != EXPECTED_GOLD:
			return false
		if int(scraps["amount"]) != int(EXPECTED_SCRAPS[choice_id]):
			return false
	return seen.size() == 3


## JSON numbers parse as floats; accept only finite integral values.
static func _read_authored_amount(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_INT:
		return {"ok": true, "amount": int(value)}
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if not is_finite(number) or number > 9007199254740992.0 or floor(number) != number:
			return {"ok": false}
		return {"ok": true, "amount": int(number)}
	return {"ok": false}
