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
## A torn seam can never take a hero's maximum HP below this floor.
const MIN_VITAL_MAX_HP := 10

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
	var settlement: Dictionary = _project_wallet(base_wallet, parsed_outcome["gold"], parsed_outcome["scraps"])
	if not settlement.get("ok", false):
		return _wallet_rejection(base_wallet)
	_claimed = true
	return {
		"ok": true,
		"event_id": _event.get("id", ""),
		"choice_id": target_id,
		"wallet": settlement["wallet"],
	}


## Read-only, ordered affordability forecast for the current authored event.
## Malformed outcomes keep their choice slot but have null deltas and cannot
## settle; every returned balance is detached from the caller and its siblings.
func preview_wallet_choices(wallet: Variant) -> Dictionary:
	var denied := {"ok": false, "event_id": "", "choices": []}
	if not _valid or _claimed:
		return denied
	var parsed_wallet: Dictionary = _parse_wallet(wallet)
	if not parsed_wallet.get("ok", false):
		return denied
	var base_wallet: Dictionary = parsed_wallet["wallet"]
	var previews: Array = []
	var choices: Array = _event.get("choices", [])
	for choice in choices:
		var parsed_outcome: Dictionary = _parse_choice_outcome(choice)
		var affordable := false
		var balance: Dictionary = base_wallet.duplicate(true)
		if parsed_outcome.get("ok", false):
			var settlement: Dictionary = _project_wallet(base_wallet, parsed_outcome["gold"], parsed_outcome["scraps"])
			if settlement.get("ok", false):
				affordable = true
				balance = settlement["wallet"]
		previews.append({
			"choice_id": choice["id"],
			"gold_delta": parsed_outcome.get("gold"),
			"scraps_delta": parsed_outcome.get("scraps"),
			"affordable": affordable,
			"wallet": balance,
		})
	return {"ok": true, "event_id": _event["id"], "choices": previews}


## Vitality settlement (V3-4): a separate, additive transaction over a detached
## snapshot {"gold", "scraps", "hero": {"id", "hp", "max_hp"}}. The caller picks
## and authenticates the living hero; this service only validates the shape.
## Choices must carry the exact four-key outcome {gold, scraps, hp, max_hp}; a
## wallet-only outcome is never padded with zero HP fields. Like the wallet
## preview, a malformed outcome keeps its slot with null deltas and cannot settle.
## Each entry: {"choice_id", "gold_delta", "scraps_delta", "hp_delta",
## "max_hp_delta", "affordable", "state"}; unaffordable entries keep the
## unchanged snapshot. No RNG and no mutation of the argument or this instance.
func preview_vital_choices(snapshot: Variant) -> Dictionary:
	var denied := {"ok": false, "event_id": "", "choices": []}
	if not _valid or _claimed:
		return denied
	var parsed_state: Dictionary = _parse_vital_snapshot(snapshot)
	if not parsed_state.get("ok", false):
		return denied
	var base_state: Dictionary = parsed_state["state"]
	var previews: Array = []
	var choices: Array = _event.get("choices", [])
	for choice in choices:
		var parsed_outcome: Dictionary = _parse_vital_outcome(choice)
		var affordable := false
		var state: Dictionary = base_state.duplicate(true)
		if parsed_outcome.get("ok", false):
			var settlement: Dictionary = _project_vitals(base_state, parsed_outcome)
			if settlement.get("ok", false):
				affordable = true
				state = settlement["state"]
		previews.append({
			"choice_id": choice["id"],
			"gold_delta": parsed_outcome.get("gold"),
			"scraps_delta": parsed_outcome.get("scraps"),
			"hp_delta": parsed_outcome.get("hp"),
			"max_hp_delta": parsed_outcome.get("max_hp"),
			"affordable": affordable,
			"state": state,
		})
	return {"ok": true, "event_id": _event["id"], "choices": previews}


## Single allowed claim with vitality settlement, sharing the one-visit latch
## with choose() and choose_with_wallet(). Validates the snapshot, selector
## state, choice ID and four-key outcome before latching.
## Returns {"ok": bool, "event_id": String, "choice_id": String, "state": Dictionary}
## where success carries the exact projected snapshot and rejection carries a
## detached unchanged valid snapshot (or an empty state for malformed input).
func choose_with_vitals(choice_id: Variant, snapshot: Variant = null) -> Dictionary:
	var parsed_state: Dictionary = _parse_vital_snapshot(snapshot)
	if not parsed_state.get("ok", false):
		return _vital_rejection({})
	var base_state: Dictionary = parsed_state["state"]
	if not _valid or _claimed:
		return _vital_rejection(base_state)
	if not _is_nonblank_string(choice_id):
		return _vital_rejection(base_state)
	var target_id: String = choice_id
	var matched_choice: Variant = null
	var choices: Array = _event.get("choices", [])
	for choice in choices:
		if choice is Dictionary and (choice as Dictionary).get("id") == target_id:
			matched_choice = choice
			break
	if not matched_choice is Dictionary:
		return _vital_rejection(base_state)
	var parsed_outcome: Dictionary = _parse_vital_outcome(matched_choice)
	if not parsed_outcome.get("ok", false):
		return _vital_rejection(base_state)
	var settlement: Dictionary = _project_vitals(base_state, parsed_outcome)
	if not settlement.get("ok", false):
		return _vital_rejection(base_state)
	_claimed = true
	return {
		"ok": true,
		"event_id": _event.get("id", ""),
		"choice_id": target_id,
		"state": settlement["state"],
	}


## Shared no-RNG, overflow-safe vitality arithmetic for preview and commit.
## Max HP is projected first (result >= MIN_VITAL_MAX_HP), then current HP: a
## debit must leave at least 1 HP, and the result is clamped to the new maximum
## (so positive healing caps and a max-HP cut pulls HP down, while a max-HP
## increase alone never heals). Call only after strict snapshot/outcome parsing.
func _project_vitals(base_state: Dictionary, outcome: Dictionary) -> Dictionary:
	var wallet: Dictionary = _project_wallet(base_state, outcome["gold"], outcome["scraps"])
	if not wallet.get("ok", false):
		return {"ok": false}
	var hero: Dictionary = base_state["hero"]
	var base_hp: int = hero["hp"]
	var base_max: int = hero["max_hp"]
	var max_delta: int = outcome["max_hp"]
	var hp_delta: int = outcome["hp"]
	if max_delta > 0 and max_delta > MAX_INT - base_max:
		return {"ok": false}
	# A valid max HP is >= 10, so adding any negative delta cannot underflow.
	var new_max: int = base_max + max_delta
	if new_max < MIN_VITAL_MAX_HP:
		return {"ok": false}
	if hp_delta > 0 and hp_delta > MAX_INT - base_hp:
		return {"ok": false}
	var new_hp: int = base_hp + hp_delta
	if new_hp < 1:
		return {"ok": false}
	if new_hp > new_max:
		new_hp = new_max
	return {"ok": true, "state": {
		"gold": wallet["wallet"]["gold"],
		"scraps": wallet["wallet"]["scraps"],
		"hero": {"id": hero["id"], "hp": new_hp, "max_hp": new_max},
	}}


func _vital_rejection(state: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"event_id": "",
		"choice_id": "",
		"state": state.duplicate(true),
	}


## Strict snapshot parse: exactly gold, scraps and one hero {id, hp, max_hp}
## with native integers, gold/scraps >= 0, 1 <= hp <= max_hp, max_hp >= 10.
## A Torn hero (hp 0) is therefore never a valid target.
func _parse_vital_snapshot(snapshot: Variant) -> Dictionary:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return {"ok": false}
	var dict: Dictionary = snapshot
	if dict.size() != 3 or not dict.has("gold") or not dict.has("scraps") or not dict.has("hero"):
		return {"ok": false}
	var wallet: Dictionary = _parse_wallet({"gold": dict.get("gold"), "scraps": dict.get("scraps")})
	if not wallet.get("ok", false):
		return {"ok": false}
	if typeof(dict.get("hero")) != TYPE_DICTIONARY:
		return {"ok": false}
	var hero: Dictionary = dict.get("hero")
	if hero.size() != 3 or not hero.has("id") or not hero.has("hp") or not hero.has("max_hp"):
		return {"ok": false}
	var hero_id: Variant = hero.get("id")
	var hp: Variant = hero.get("hp")
	var max_hp: Variant = hero.get("max_hp")
	if not _is_nonblank_string(hero_id) or typeof(hp) != TYPE_INT or typeof(max_hp) != TYPE_INT:
		return {"ok": false}
	var hp_int: int = hp
	var max_int: int = max_hp
	if hp_int < 1 or max_int < MIN_VITAL_MAX_HP or hp_int > max_int:
		return {"ok": false}
	return {"ok": true, "state": {
		"gold": wallet["wallet"]["gold"],
		"scraps": wallet["wallet"]["scraps"],
		"hero": {"id": hero_id, "hp": hp_int, "max_hp": max_int},
	}}


## Exactly {id, text, outcome} with an outcome of exactly the four integral keys
## gold, scraps, hp and max_hp; anything else (including a wallet-only outcome)
## is malformed.
func _parse_vital_outcome(choice: Variant) -> Dictionary:
	if typeof(choice) != TYPE_DICTIONARY:
		return {"ok": false}
	var record: Dictionary = choice
	if record.size() != 3 or not record.has("id") or not record.has("text") or not record.has("outcome"):
		return {"ok": false}
	var raw_outcome: Variant = record.get("outcome")
	if typeof(raw_outcome) != TYPE_DICTIONARY:
		return {"ok": false}
	var outcome: Dictionary = raw_outcome
	if outcome.size() != 4:
		return {"ok": false}
	var parsed := {"ok": true}
	for key in ["gold", "scraps", "hp", "max_hp"]:
		if not outcome.has(key):
			return {"ok": false}
		var amount: Dictionary = _read_outcome_amount(outcome.get(key), true)
		if not amount.get("ok", false):
			return {"ok": false}
		parsed[key] = amount["amount"]
	return parsed


## Both preview and commit use this exact no-RNG, overflow-safe arithmetic.
## Call only after strict wallet and outcome parsing.
func _project_wallet(base_wallet: Dictionary, gold_delta: int, scraps_delta: int) -> Dictionary:
	var base_gold: int = base_wallet["gold"]
	var base_scraps: int = base_wallet["scraps"]
	if gold_delta > 0:
		if gold_delta > MAX_INT - base_gold:
			return {"ok": false}
	elif base_gold + gold_delta < 0:
		return {"ok": false}
	if scraps_delta >= 0:
		if scraps_delta > MAX_INT - base_scraps:
			return {"ok": false}
	elif base_scraps + scraps_delta < 0:
		# Safe even for MIN_INT: a nonnegative balance plus a debit cannot underflow.
		return {"ok": false}
	return {"ok": true, "wallet": {
		"gold": base_gold + gold_delta,
		"scraps": base_scraps + scraps_delta,
	}}


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
	var gold: Dictionary = _read_outcome_amount(outcome.get("gold"), true)
	var scraps: Dictionary = _read_outcome_amount(outcome.get("scraps"), true)
	if not gold.get("ok", false) or not scraps.get("ok", false):
		return {"ok": false}
	return {
		"ok": true,
		"gold": gold["amount"],
		"scraps": scraps["amount"],
	}


func _read_outcome_amount(value: Variant, allow_negative: bool) -> Dictionary:
	if typeof(value) == TYPE_INT:
		var amount: int = value
		if not allow_negative and amount < 0:
			return {"ok": false}
		return {"ok": true, "amount": amount}
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if not is_finite(number) or number > MAX_SAFE_FLOAT_INT or floor(number) != number:
			return {"ok": false}
		if number < (-MAX_SAFE_FLOAT_INT if allow_negative else 0.0):
			return {"ok": false}
		return {"ok": true, "amount": int(number)}
	return {"ok": false}


func _is_nonblank_string(value: Variant) -> bool:
	if not value is String:
		return false
	var text: String = value
	return not text.strip_edges().is_empty()
