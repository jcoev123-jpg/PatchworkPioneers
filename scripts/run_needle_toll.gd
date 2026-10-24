class_name RunNeedleToll
extends RefCounted
## Scene-free, once-per-run P7 Needle Toll transaction.
##
## The caller passes a detached run context (the current three-hero party, the
## wallet and the shared deck) plus the run's seeded RandomNumberGenerator.
## Nothing caller-owned is ever mutated: every receipt carries detached proposed
## hero/wallet/deck snapshots and a deterministic receipt hash for the future app
## owner to commit.
##
## Stage 1 is exactly one of:
##   take_safe_exit()        -> award the authored scrap and end the visit.
##   pay_toll(hero_id)       -> remove the authored HP cost from one living hero
##                              with at least minimum_hp current HP (never torn),
##                              then sample offer_count distinct authored RARE
##                              BASE cards from the active party's pools.
## Stage 2 (paid visits only) is exactly one of:
##   claim_card(card_id)     -> append that offered card once to the shared deck.
##   skip_cards()            -> add none.
## Rejected, repeated, stale and cross-branch calls change no state and consume
## no RNG. The visit latches as soon as either branch or the offer claim commits.

const EVENT_ID: String = "needle_toll"
const CHOICE_PAY: String = "pay_toll"
const CHOICE_SAFE_EXIT: String = "safe_exit"
const EVENT_PATH: String = "res://data/events/mpw_needle_toll.json"
const STAGE_OPEN: String = "open"
const STAGE_PAID: String = "paid"
const STAGE_DONE: String = "done"
const MAX_INT: int = 9223372036854775807
const MAX_SAFE_FLOAT_INT: float = 9007199254740992.0
const EXPECTED_HP_COST: int = 6
const EXPECTED_MINIMUM_HP: int = 7
const EXPECTED_EXIT_SCRAPS: int = 1
const EXPECTED_OFFER_COUNT: int = 2
const EXPECTED_RARITY: String = "rare"
const EXPECTED_VISIT_WEIGHT: int = 1

var _heroes: Array = []
var _wallet: Dictionary = {}
var _deck: Array[String] = []
var _party_ids: Array[String] = []
var _rng: RandomNumberGenerator = null
var _event: Dictionary = {}
var _hp_cost: int = 0
var _minimum_hp: int = 0
var _exit_scraps: int = 0
var _offer_count: int = 0
var _rarity: String = ""
var _stage: String = STAGE_OPEN
var _offers: Array = []
var _wounded_hero_id: String = ""
var _receipt: String = ""
var _source_snapshot: Dictionary = {}
var _valid: bool = false


## context: {"heroes": Array, "wallet": {"gold": int, "scraps": int}, "deck": Array}
## run_rng: the caller's seeded run RandomNumberGenerator.
## event_record: the authored needle_toll JSON object; null loads the shipped file.
func _init(context: Variant = null, run_rng: Variant = null, event_record: Variant = null) -> void:
	if not (run_rng is RandomNumberGenerator):
		return
	var record: Dictionary = _resolve_event_record(event_record)
	if record.is_empty() or not _read_event_record(record):
		return
	var parsed: Dictionary = _parse_context(context)
	if not parsed.get("ok", false):
		return
	_heroes = (parsed["heroes"] as Array).duplicate(true)
	_wallet = (parsed["wallet"] as Dictionary).duplicate(true)
	_deck = _copy_deck(parsed["deck"] as Array)
	_party_ids = []
	_party_ids.assign(parsed["party_ids"] as Array)
	_rng = run_rng
	_event = record.duplicate(true)
	_source_snapshot = {
		"heroes": _heroes.duplicate(true),
		"wallet": _wallet.duplicate(true),
		"deck": _copy_deck(_deck),
		"offers": [],
		"stage": STAGE_OPEN,
		"receipt": _make_receipt("source", ""),
	}
	_valid = true


## The shipped authored needle_toll event object, or {} when it cannot be parsed.
static func load_authored_event() -> Dictionary:
	if not FileAccess.file_exists(EVENT_PATH):
		return {}
	var file := FileAccess.open(EVENT_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func is_valid() -> bool:
	return _valid and _stage != STAGE_DONE


func is_claimed() -> bool:
	return _valid and _stage == STAGE_DONE


func is_open() -> bool:
	return _valid and _stage == STAGE_OPEN


func is_paid() -> bool:
	return _valid and _stage == STAGE_PAID


func get_stage() -> String:
	return _stage if _valid else ""


## A detached deep copy of the authored record for presentation wiring later.
func get_event() -> Dictionary:
	return _event.duplicate(true)


## The untouched constructor context, for a future owner's stale-source check.
func get_source_snapshot() -> Dictionary:
	return _source_snapshot.duplicate(true)


## Detached current proposed state plus the visit stage and last receipt.
func get_snapshot() -> Dictionary:
	if not _valid:
		return {"heroes": [], "wallet": {}, "deck": [], "offers": [], "stage": "", "receipt": ""}
	return {
		"heroes": _heroes.duplicate(true),
		"wallet": _wallet.duplicate(true),
		"deck": _copy_deck(_deck),
		"offers": _offers.duplicate(true),
		"stage": _stage,
		"receipt": _receipt,
	}


## Read-only ordered IDs of living heroes that may pay the toll. Draws no RNG.
func get_eligible_hero_ids() -> Array[String]:
	var ids: Array[String] = []
	if not _valid or _stage != STAGE_OPEN:
		return ids
	for hero: Dictionary in _heroes:
		if int(hero.get("hp", 0)) >= _minimum_hp:
			ids.append(String(hero.get("id", "")))
	return ids


## Detached paid-visit offers. Empty before payment, after a safe exit or after claim.
func get_offers() -> Array:
	return _offers.duplicate(true)


func get_offered_ids() -> Array[String]:
	return _offered_ids()


## Stage 1 safe exit: award exactly exit_scraps and end the visit without RNG.
func take_safe_exit() -> Dictionary:
	if not _valid or _stage != STAGE_OPEN:
		return _rejection()
	var scraps: Variant = _wallet.get("scraps")
	if typeof(scraps) != TYPE_INT:
		return _rejection()
	var current_scraps: int = scraps
	if current_scraps > MAX_INT - _exit_scraps:
		return _rejection()
	var next_wallet: Dictionary = _wallet.duplicate(true)
	next_wallet["scraps"] = current_scraps + _exit_scraps
	_wallet = next_wallet
	_stage = STAGE_DONE
	_receipt = _make_receipt("safe_exit", "")
	return _success("safe_exit", "", 0, _exit_scraps, "", false)


## Stage 1 paid branch: wound exactly one eligible hero, then roll the rare offers.
## All preconditions (visit stage, hero, catalogs, offer availability) are checked
## before the exactly offer_count RNG draws.
func pay_toll(hero_id: Variant) -> Dictionary:
	if not _valid or _stage != STAGE_OPEN:
		return _rejection()
	if typeof(hero_id) != TYPE_STRING:
		return _rejection()
	var target_id: String = hero_id
	if target_id.is_empty() or target_id != target_id.strip_edges():
		return _rejection()
	var hero_index: int = -1
	for index in range(_heroes.size()):
		if String((_heroes[index] as Dictionary).get("id", "")) == target_id:
			hero_index = index
			break
	if hero_index < 0:
		return _rejection()
	var target: Dictionary = _heroes[hero_index]
	var current_hp: int = int(target.get("hp", 0))
	if current_hp < _minimum_hp or current_hp - _hp_cost < 1:
		return _rejection()
	var pool: Array[String] = _eligible_rare_ids()
	if pool.size() < _offer_count:
		return _rejection()

	var offers: Array = []
	for pick in range(_offer_count):
		var pick_index: int = _rng.randi_range(0, pool.size() - 1)
		var card_id: String = pool[pick_index]
		pool.remove_at(pick_index)
		var definition: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(card_id)
		if definition.is_empty() or String(definition.get("id", "")) != card_id:
			return _rejection()
		if not _party_ids.has(String(definition.get("owner", ""))):
			return _rejection()
		if String(definition.get("rarity", "")) != _rarity:
			return _rejection()
		offers.append({
			"id": card_id,
			"owner": String(definition.get("owner", "")),
			"rarity": String(definition.get("rarity", "")),
		})

	var next_heroes: Array = _heroes.duplicate(true)
	var wounded: Dictionary = next_heroes[hero_index]
	wounded["hp"] = current_hp - _hp_cost
	next_heroes[hero_index] = wounded
	_heroes = next_heroes
	_offers = offers.duplicate(true)
	_wounded_hero_id = target_id
	_stage = STAGE_PAID
	_receipt = _make_receipt("pay_toll", "")
	return _success("paid", target_id, _hp_cost, 0, "", false)


## Stage 2 claim: append exactly the selected offered card once to the shared deck.
func claim_card(card_id: Variant) -> Dictionary:
	if not _valid or _stage != STAGE_PAID:
		return _rejection()
	if typeof(card_id) != TYPE_STRING:
		return _rejection()
	var selected_id: String = card_id
	if not _offered_ids().has(selected_id):
		return _rejection()
	var next_deck: Array[String] = _copy_deck(_deck)
	next_deck.append(selected_id)
	_deck = next_deck
	_stage = STAGE_DONE
	_receipt = _make_receipt("claim", selected_id)
	return _success("paid", _wounded_hero_id, _hp_cost, 0, selected_id, false)


## Stage 2 skip: latch the paid visit without adding any card.
func skip_cards() -> Dictionary:
	if not _valid or _stage != STAGE_PAID:
		return _rejection()
	_stage = STAGE_DONE
	_receipt = _make_receipt("skip", "")
	return _success("paid", _wounded_hero_id, _hp_cost, 0, "", true)


func _eligible_rare_ids() -> Array[String]:
	var ids: Array[String] = []
	var party_set: Dictionary = {}
	for party_id: String in _party_ids:
		party_set[party_id] = true
	var seen: Dictionary = {}
	var candidates: Array = RunPoolCardRewardOffers.get_authored_base_candidates()
	for item_raw: Variant in candidates:
		if not (item_raw is Dictionary):
			return []
		var item: Dictionary = item_raw
		var id_raw: Variant = item.get("id")
		var owner_raw: Variant = item.get("owner")
		var rarity_raw: Variant = item.get("rarity")
		if typeof(id_raw) != TYPE_STRING or typeof(owner_raw) != TYPE_STRING or typeof(rarity_raw) != TYPE_STRING:
			return []
		var card_id: String = id_raw
		var owner: String = owner_raw
		var rarity: String = rarity_raw
		if card_id.is_empty() or owner.is_empty() or card_id.ends_with("_plus"):
			return []
		if rarity != _rarity or not party_set.has(owner):
			continue
		if seen.has(card_id):
			return []
		# Resolve every candidate individually so only real rare BASE definitions
		# owned by this active party can ever be offered.
		var definition: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(card_id)
		if definition.is_empty() or String(definition.get("id", "")) != card_id:
			return []
		if String(definition.get("owner", "")) != owner:
			return []
		if String(definition.get("rarity", "")) != _rarity:
			return []
		if definition.get("reward_eligible") == false:
			return []
		if definition.has("upgrade_of") or definition.get("is_upgrade") == true:
			return []
		seen[card_id] = true
		ids.append(card_id)
	ids.sort()
	return ids


func _success(branch: String, wounded_hero_id: String, hp_cost: int,
		awarded_scraps: int, claimed_card_id: String, skipped: bool) -> Dictionary:
	return {
		"ok": true,
		"event_id": EVENT_ID,
		"branch": branch,
		"heroes": _heroes.duplicate(true),
		"wallet": _wallet.duplicate(true),
		"deck": _copy_deck(_deck),
		"offers": _offers.duplicate(true),
		"offered_ids": _offered_ids(),
		"wounded_hero_id": wounded_hero_id,
		"hp_cost": hp_cost,
		"awarded_scraps": awarded_scraps,
		"claimed_card_id": claimed_card_id,
		"skipped": skipped,
		"receipt": _receipt,
	}


func _rejection() -> Dictionary:
	return {
		"ok": false,
		"event_id": "",
		"branch": "",
		"heroes": _heroes.duplicate(true),
		"wallet": _wallet.duplicate(true),
		"deck": _copy_deck(_deck),
		"offers": _offers.duplicate(true),
		"offered_ids": _offered_ids(),
		"wounded_hero_id": "",
		"hp_cost": 0,
		"awarded_scraps": 0,
		"claimed_card_id": "",
		"skipped": false,
		"receipt": _receipt,
	}


func _offered_ids() -> Array[String]:
	var ids: Array[String] = []
	for offer: Dictionary in _offers:
		ids.append(String(offer.get("id", "")))
	return ids


func _make_receipt(action: String, claimed_card_id: String) -> String:
	return JSON.stringify([
		EVENT_ID,
		action,
		_heroes,
		_wallet,
		_copy_deck(_deck),
		_offers,
		claimed_card_id,
	]).sha256_text()


func _resolve_event_record(event_record: Variant) -> Dictionary:
	if typeof(event_record) == TYPE_DICTIONARY:
		return (event_record as Dictionary).duplicate(true)
	if event_record == null:
		return load_authored_event()
	return {}


func _read_event_record(record: Dictionary) -> bool:
	if typeof(record.get("id")) != TYPE_STRING or String(record["id"]) != EVENT_ID:
		return false
	if not _is_nonblank_string(record.get("title")):
		return false
	if not _is_nonblank_string(record.get("description")):
		return false
	var hp_cost: Dictionary = _authored_int(record.get("hp_cost"))
	var minimum_hp: Dictionary = _authored_int(record.get("minimum_hp"))
	var exit_scraps: Dictionary = _authored_int(record.get("exit_scraps"))
	var offer_count: Dictionary = _authored_int(record.get("offer_count"))
	var visit_weight: Dictionary = _authored_int(record.get("visit_weight"))
	if not hp_cost.get("ok", false) or int(hp_cost["amount"]) != EXPECTED_HP_COST:
		return false
	if not minimum_hp.get("ok", false) or int(minimum_hp["amount"]) != EXPECTED_MINIMUM_HP:
		return false
	if not exit_scraps.get("ok", false) or int(exit_scraps["amount"]) != EXPECTED_EXIT_SCRAPS:
		return false
	if not offer_count.get("ok", false) or int(offer_count["amount"]) != EXPECTED_OFFER_COUNT:
		return false
	if not visit_weight.get("ok", false) or int(visit_weight["amount"]) != EXPECTED_VISIT_WEIGHT:
		return false
	if typeof(record.get("rarity")) != TYPE_STRING or String(record["rarity"]) != EXPECTED_RARITY:
		return false
	if record.get("once_per_run") != true:
		return false
	if typeof(record.get("choices")) != TYPE_ARRAY:
		return false
	var choices: Array = record["choices"]
	if choices.size() != 2:
		return false
	var seen: Dictionary = {}
	for choice_raw: Variant in choices:
		if not (choice_raw is Dictionary):
			return false
		var choice: Dictionary = choice_raw
		if not _is_nonblank_string(choice.get("id")) or not _is_nonblank_string(choice.get("text")):
			return false
		var choice_id: String = String(choice["id"])
		if choice_id != CHOICE_PAY and choice_id != CHOICE_SAFE_EXIT:
			return false
		if seen.has(choice_id):
			return false
		seen[choice_id] = true
	if seen.size() != 2:
		return false
	_hp_cost = int(hp_cost["amount"])
	_minimum_hp = int(minimum_hp["amount"])
	_exit_scraps = int(exit_scraps["amount"])
	_offer_count = int(offer_count["amount"])
	_rarity = String(record["rarity"])
	return true


func _parse_context(context: Variant) -> Dictionary:
	if typeof(context) != TYPE_DICTIONARY:
		return {"ok": false}
	var dict: Dictionary = context
	if dict.size() != 3 or not dict.has("heroes") or not dict.has("wallet") or not dict.has("deck"):
		return {"ok": false}
	var heroes_raw: Variant = dict.get("heroes")
	if typeof(heroes_raw) != TYPE_ARRAY:
		return {"ok": false}
	var heroes: Array = heroes_raw
	var carry := RunPartyCarryover.new(heroes)
	if not carry.is_valid():
		return {"ok": false}
	var party_ids: Array[String] = []
	var seen: Dictionary = {}
	for hero_raw: Variant in heroes:
		if not (hero_raw is Dictionary):
			return {"ok": false}
		var hero: Dictionary = hero_raw
		var hero_id: String = String(hero.get("id", ""))
		if hero_id.is_empty() or seen.has(hero_id):
			return {"ok": false}
		seen[hero_id] = true
		party_ids.append(hero_id)
	var wallet: Dictionary = _parse_wallet(dict.get("wallet"))
	if not wallet.get("ok", false):
		return {"ok": false}
	var deck: Dictionary = _parse_deck(dict.get("deck"))
	if not deck.get("ok", false):
		return {"ok": false}
	return {
		"ok": true,
		"heroes": heroes.duplicate(true),
		"wallet": wallet["wallet"],
		"deck": deck["deck"],
		"party_ids": party_ids,
	}


func _parse_wallet(wallet: Variant) -> Dictionary:
	if typeof(wallet) != TYPE_DICTIONARY:
		return {"ok": false}
	var dict: Dictionary = wallet
	if dict.size() != 2 or not dict.has("gold") or not dict.has("scraps"):
		return {"ok": false}
	if typeof(dict.get("gold")) != TYPE_INT or typeof(dict.get("scraps")) != TYPE_INT:
		return {"ok": false}
	var gold: int = dict["gold"]
	var scraps: int = dict["scraps"]
	if gold < 0 or scraps < 0:
		return {"ok": false}
	return {"ok": true, "wallet": {"gold": gold, "scraps": scraps}}


func _parse_deck(deck: Variant) -> Dictionary:
	if typeof(deck) != TYPE_ARRAY:
		return {"ok": false}
	var entries: Array = deck
	if entries.is_empty():
		return {"ok": false}
	var copied: Array[String] = []
	for entry_raw: Variant in entries:
		if typeof(entry_raw) != TYPE_STRING:
			return {"ok": false}
		var card_id: String = entry_raw
		if card_id.is_empty() or card_id != card_id.strip_edges():
			return {"ok": false}
		copied.append(card_id)
	return {"ok": true, "deck": copied}


static func _copy_deck(source: Array) -> Array[String]:
	var copied: Array[String] = []
	for entry: Variant in source:
		if typeof(entry) == TYPE_STRING:
			copied.append(String(entry))
	return copied


static func _is_nonblank_string(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	return not String(value).strip_edges().is_empty()


## JSON numbers parse as floats; accept only finite integral values.
static func _authored_int(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_INT:
		return {"ok": true, "amount": int(value)}
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if not is_finite(number) or number > MAX_SAFE_FLOAT_INT or number < -MAX_SAFE_FLOAT_INT or floor(number) != number:
			return {"ok": false}
		return {"ok": true, "amount": int(number)}
	return {"ok": false}
