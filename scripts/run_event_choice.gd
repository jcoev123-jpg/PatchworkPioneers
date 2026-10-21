class_name RunEventChoice
extends RefCounted
## One-visit authored M04 event choice service.
## Each instance holds a single authored event record; the first offered choice
## that validates is claimed exactly once and every later choice is rejected.
## No scene dependencies, no RNG use, and no outcome effects on choose(): a
## legacy claim only commits the opaque authored choice ID (no healing, gold,
## card or trinket results), while choose_with_wallet() validates and settles
## authored gold/scraps choice outcomes into a detached wallet dictionary. Like
## RunCardRewardChoice, a consumed instance reports is_valid() == false while
## is_claimed() stays true.

const MAX_INT := 9223372036854775807
const MAX_SAFE_FLOAT_INT := 9007199254740992.0

var _event: Dictionary = {}
var _valid: bool = false
var _claimed: bool = false


func _init(event_record: Variant = null) -> void:
	# Fail closed on anything that is not a Dictionary; never coerce types.
	if not event_record is Dictionary:
		return
	var copy: Dictionary = (event_record as Dictionary).duplicate(true)
	if not _is_nonblank_string(copy.get("id")):
		return
	if not _is_nonblank_string(copy.get("title")):
		return
	if not _is_nonblank_string(copy.get("description")):
		return
	var choices: Variant = copy.get("choices")
	if not choices is Array:
		return
	if (choices as Array).size() < 2 or (choices as Array).size() > 3:
		return
	var seen := {}
	for choice in choices:
		if not choice is Dictionary:
			return
		var choice_id: Variant = (choice as Dictionary).get("id")
		var text: Variant = (choice as Dictionary).get("text")
		if not _is_nonblank_string(choice_id) or not _is_nonblank_string(text):
			return
		if seen.has(choice_id):
			return
		seen[choice_id] = true
	_event = copy
	_valid = true


## True only while this offering is schema-valid and still unclaimed.
func is_valid() -> bool:
	return _valid and not _claimed


## True once a choice has been committed on this instance.
func is_claimed() -> bool:
	return _claimed


## A detached deep copy of the authored event; mutating it never reaches
## this instance or the caller's original record.
func get_event() -> Dictionary:
	return _event.duplicate(true)


## Attempts the single allowed claim.
## Returns exactly {"ok": bool, "event_id": String, "choice_id": String}.
## Rejections (invalid construction, blank/unoffered choice, replay) return
## ok=false with empty IDs and consume no claim, mutating no state.
func choose(choice_id: String) -> Dictionary:
	if not _valid or _claimed:
		return _rejection()
	if choice_id.strip_edges().is_empty():
		return _rejection()
	var choices: Array = _event.get("choices", [])
	for choice in choices:
		if choice is Dictionary and (choice as Dictionary).get("id") == choice_id:
			_claimed = true
			return {"ok": true, "event_id": _event.get("id", ""), "choice_id": choice_id}
	return _rejection()


## Attempts the single allowed claim with caller wallet settlement.
## Validates the wallet, selector state, choice ID and authored choice outcome
## before latching the claim.
## Returns {"ok": bool, "event_id": String, "choice_id": String, "wallet": Dictionary}
## where success contains exact updated integer gold/scraps and rejection carries
## a detached unchanged valid wallet (or an empty wallet on malformed input).
func choose_with_wallet(choice_id: Variant, wallet: Variant = null) -> Dictionary:
	var parsed_wallet: Dictionary = _parse_wallet(wallet)
	if not parsed_wallet.get("ok", false):
		return _wallet_rejection({})
	var base_wallet: Dictionary = parsed_wallet["wallet"]
	if not _valid or _claimed:
		return _wallet_rejection(base_wallet)
	if not _is_nonblank_string(choice_id):
		return _wallet_rejection(base_wallet)
	var target_id: String = choice_id
	var matched_choice: Variant = null
	var choices: Array = _event.get("choices", [])
	for choice in choices:
		if choice is Dictionary and (choice as Dictionary).get("id") == target_id:
			matched_choice = choice
			break
	if not matched_choice is Dictionary:
		return _wallet_rejection(base_wallet)
	var parsed_outcome: Dictionary = _parse_choice_outcome(matched_choice as Dictionary)
	if not parsed_outcome.get("ok", false):
		return _wallet_rejection(base_wallet)
	var gold_delta: int = parsed_outcome["gold"]
	var scraps_delta: int = parsed_outcome["scraps"]
	var base_gold: int = base_wallet["gold"]
	var base_scraps: int = base_wallet["scraps"]
	if gold_delta > MAX_INT - base_gold or scraps_delta > MAX_INT - base_scraps:
		return _wallet_rejection(base_wallet)
	_claimed = true
	return {
		"ok": true,
		"event_id": _event.get("id", ""),
		"choice_id": target_id,
		"wallet": {
			"gold": base_gold + gold_delta,
			"scraps": base_scraps + scraps_delta,
		},
	}


func _rejection() -> Dictionary:
	return {"ok": false, "event_id": "", "choice_id": ""}


func _wallet_rejection(wallet: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"event_id": "",
		"choice_id": "",
		"wallet": wallet.duplicate(true),
	}


func _parse_wallet(wallet: Variant) -> Dictionary:
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


func _parse_choice_outcome(choice: Dictionary) -> Dictionary:
	if choice.size() != 3 or not choice.has("id") or not choice.has("text") or not choice.has("outcome"):
		return {"ok": false}
	var raw_outcome: Variant = choice.get("outcome")
	if typeof(raw_outcome) != TYPE_DICTIONARY:
		return {"ok": false}
	var outcome: Dictionary = raw_outcome
	if outcome.size() != 2 or not outcome.has("gold") or not outcome.has("scraps"):
		return {"ok": false}
	var gold: int = _read_outcome_amount(outcome.get("gold"))
	var scraps: int = _read_outcome_amount(outcome.get("scraps"))
	if gold < 0 or scraps < 0:
		return {"ok": false}
	return {
		"ok": true,
		"gold": gold,
		"scraps": scraps,
	}


func _read_outcome_amount(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var amount: int = value
		return amount if amount >= 0 else -1
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if not is_finite(number) or number < 0.0 or number > MAX_SAFE_FLOAT_INT or floor(number) != number:
			return -1
		return int(number)
	return -1


func _is_nonblank_string(value: Variant) -> bool:
	if not value is String:
		return false
	var text: String = value
	return not text.strip_edges().is_empty()
