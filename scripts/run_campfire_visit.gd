class_name RunCampfireVisit
extends RefCounted
## A scene-free, single-decision Campfire visit. The eventual map controller
## supplies the node ID and the complete authoritative run roster, then owns
## applying a successful receipt to its ledgers. This class owns no run ledgers.

const INVALID := "invalid"
const OPEN := "open"
const HEALED := "healed"
const LEFT := "left"

## Opt-in Design v4 four-hero mode. The legacy two-argument service stays the
## playable cards-mode path; this Stitched branch is service-only until S6
## wires the real four-hero run roster, meters and gothic stop panel.
const STITCHED := "stitched"
const STITCHED_OPEN := "stitched_open"
const STITCHED_DECIDED := "stitched_decided"
const MEND := "mend"
const TELL_TALES := "tell_tales"
const TRIM_THE_WICK := "trim_the_wick"
const STITCHED_LEAVE := "leave"

const STITCHED_PARTY_SIZE := 4
const STITCHED_FRAY_MAX := 200
const STITCHED_CANDLE_MAX := 100
const MEND_HEAL_PERCENT := 30
const TALES_FRAY_REDUCTION := 25
const WICK_CANDLE_RESTORE := 50

var _node_id: String = ""
var _heroes: Array = []
var _status: String = INVALID
var _mode: String = ""
var _candle: int = 0
# Opt-in part-swap extension (null/empty unless opened with a satchel).
var _swap: RunStitchedSewingSwap = null
var _satchel: Array = []
var _swap_state: Dictionary = {}


func _init(node_id: Variant = null, run_heroes: Variant = null,
		mode: Variant = null, candle: Variant = null) -> void:
	if not _valid_node_id(node_id) or typeof(run_heroes) != TYPE_ARRAY:
		return
	if mode == null:
		# Legacy three-hero service, byte-for-byte unchanged.
		# Share exactly Rest's admission rules, including rejecting total defeat.
		# Validate before copying; no invalid data can become an open visit.
		if not RunRestRecovery._is_valid_roster(run_heroes):
			return
		_node_id = node_id
		_heroes = run_heroes.duplicate(true)
		_status = OPEN
		return
	# Opt-in Stitched mode; any other mode argument fails closed.
	if typeof(mode) != TYPE_STRING or mode != STITCHED:
		return
	if not _is_valid_stitched_party(run_heroes, candle):
		return
	_mode = STITCHED
	_node_id = node_id
	_heroes = run_heroes.duplicate(true)
	_candle = int(candle)
	_status = STITCHED_OPEN


## Opt-in Stitched entry point: the usual four-hero Campfire plus a satchel of
## 0..6 spare parts and the canonical part catalog (StitchedParts "by_id").
## Heroes must also carry full worn slot records. Any invalid input fails
## closed and returns the same invalid visit as a rejected constructor call.
static func open_stitched_with_satchel(node_id: Variant, run_heroes: Variant,
		candle: Variant, satchel: Variant, catalog_by_id: Variant) -> RunCampfireVisit:
	var visit := RunCampfireVisit.new(node_id, run_heroes, STITCHED, candle)
	if visit._status != STITCHED_OPEN:
		return RunCampfireVisit.new()
	var swap := RunStitchedSewingSwap.new(node_id, run_heroes, satchel, catalog_by_id)
	var swap_state: Dictionary = swap.read_state()
	if swap_state.get("ok") != true:
		return RunCampfireVisit.new()
	visit._swap = swap
	visit._swap_state = swap_state
	# Hold the swap authority's normalised records so later comparisons agree.
	visit._heroes = swap_state["heroes"].duplicate(true)
	visit._satchel = swap_state["satchel"].duplicate(true)
	return visit


## The detached part-swap quote of an opted-in visit (empty otherwise).
func swap_quote() -> Dictionary:
	if _swap == null:
		return {}
	return _swap.quote()


## One optional same-slot exchange before the single recovery decision.
## expected_state is the latest swap state ("swap_state" of read_state() or of
## the previous swap receipt) or the complete latest read_state().
func swap_part(hero_id: Variant, slot: Variant, satchel_index: Variant,
		expected_node_id: Variant, expected_state: Variant) -> Dictionary:
	if _swap == null or _status != STITCHED_OPEN:
		return _swap_rejected("no open part-swap opportunity")
	if not _valid_node_id(expected_node_id) or expected_node_id != _node_id:
		return _swap_rejected("wrong node")
	if typeof(expected_state) != TYPE_DICTIONARY:
		return _swap_rejected("expected state must be a dictionary")
	var swap_expected: Variant = expected_state
	if expected_state.has("swap_state"):
		if JSON.stringify(expected_state, "", true) != JSON.stringify(read_state(), "", true):
			return _swap_rejected("stale or forged state")
		swap_expected = expected_state["swap_state"]
	var result: Dictionary = _swap.swap(hero_id, slot, satchel_index, expected_node_id, swap_expected)
	if result.get("ok") != true:
		return _swap_rejected(str(result.get("error", "swap refused")))
	# Reconcile only the committed gear records and the satchel.
	var changed: Array = result.get("changed_heroes", [])
	for changed_hero in changed:
		for index in range(_heroes.size()):
			if str(_heroes[index]["id"]) == str(changed_hero["id"]):
				_heroes[index]["parts"] = changed_hero["parts"].duplicate(true)
	_satchel = result["satchel"].duplicate(true)
	_swap_state = result["state"].duplicate(true)
	return {
		"ok": true,
		"error": "",
		"action": "swap",
		"node_id": _node_id,
		"hero_id": str(hero_id),
		"slot": str(slot),
		"satchel_index": int(satchel_index),
		"worn_before": result["worn_before"].duplicate(true),
		"worn_after": result["worn_after"].duplicate(true),
		"satchel_before": result["satchel_before"].duplicate(true),
		"satchel_after": result["satchel_after"].duplicate(true),
		"heroes": _heroes.duplicate(true),
		"satchel": _satchel.duplicate(true),
		"candle": _candle,
		"swap_state": _swap_state.duplicate(true),
	}


func _swap_rejected(message: String) -> Dictionary:
	return {"ok": false, "error": message}


func read_state() -> Dictionary:
	if _mode == STITCHED:
		var state := {
			"ok": _status != INVALID,
			"node_id": _node_id,
			"status": _status,
			"mode": STITCHED,
			"quote": _stitched_quote(),
			"heroes": _heroes.duplicate(true),
			"candle": _candle,
		}
		if _swap != null:
			state["satchel"] = _satchel.duplicate(true)
			state["swap_state"] = _swap_state.duplicate(true)
			state["swap_quote"] = _swap.quote()
		return state
	return {
		"ok": _status != INVALID,
		"node_id": _node_id,
		"status": _status,
		"heroes": _heroes.duplicate(true),
	}


## A receipt is always the same shape. An unsuccessful attempt has no
## committed decision or publishable roster, and leaves the visit untouched.
func choose_heal(expected_node_id: Variant, expected_heroes: Variant) -> Dictionary:
	if not _matches_open_visit(expected_node_id, expected_heroes):
		return _rejected()
	# Rest remains the single authority for revive-first, floor(30%) and caps.
	var recovery := RunRestRecovery.new(_heroes)
	var healed: Dictionary = recovery.choose_heal()
	if healed.get("ok") != true or typeof(healed.get("heroes")) != TYPE_ARRAY:
		return _rejected()
	_heroes = healed["heroes"].duplicate(true)
	_status = HEALED
	return _receipt("heal")


func leave(expected_node_id: Variant, expected_heroes: Variant) -> Dictionary:
	if not _matches_open_visit(expected_node_id, expected_heroes):
		return _rejected()
	_status = LEFT
	return _receipt("leave")


## The single Stitched selection. It accepts only the current node, a detached
## expected open-state snapshot (heroes and candle) and one quoted decision.
## A refusal never consumes the visit or changes held state.
func select(decision: Variant, expected_node_id: Variant,
		expected_heroes: Variant, expected_candle: Variant) -> Dictionary:
	if not _matches_stitched_open(expected_node_id, expected_heroes, expected_candle) or not _is_stitched_decision(decision):
		return _stitched_rejected()
	# A choice that cannot change anything is not advertised, so it is refused
	# here without consuming the visit or touching the swap opportunity.
	if not _stitched_choices().has(String(decision)):
		return _stitched_rejected()
	var updated: Array = _heroes.duplicate(true)
	var candle: int = _candle
	match String(decision):
		MEND:
			for hero in updated:
				# A LOST doll is unpicked and is never restored by Campfire.
				if _is_lost_hero(hero):
					continue
				var max_hp: int = int(hero["max_hp"])
				# floor(30% of max HP), capped at max HP; a Hanging 0-HP hero
				# receives exactly this heal, with no revive-first bonus.
				@warning_ignore("integer_division")
				var amount: int = (max_hp * MEND_HEAL_PERCENT) / 100
				hero["hp"] = mini(max_hp, int(hero["hp"]) + amount)
		TELL_TALES:
			for hero in updated:
				hero["fray"] = maxi(0, int(hero["fray"]) - TALES_FRAY_REDUCTION)
		TRIM_THE_WICK:
			candle = mini(STITCHED_CANDLE_MAX, candle + WICK_CANDLE_RESTORE)
		STITCHED_LEAVE:
			pass
		_:
			return _stitched_rejected()
	_heroes = updated
	_candle = candle
	_status = STITCHED_DECIDED
	if _swap != null:
		# The one decision also closes the swap opportunity.
		var closed: Dictionary = _swap.leave(_node_id, _swap_state)
		if closed.get("ok") == true:
			_swap_state = closed["state"].duplicate(true)
	return _stitched_receipt(String(decision))


## The ordered recovery choices that can still change the held party or candle.
## Leave is always offered while the visit is open; a decided visit offers none.
func _stitched_choices() -> Array:
	var choices: Array = []
	if _status != STITCHED_OPEN:
		return choices
	if _mend_changes_party():
		choices.append(MEND)
	if _tales_changes_party():
		choices.append(TELL_TALES)
	if _candle < STITCHED_CANDLE_MAX:
		choices.append(TRIM_THE_WICK)
	choices.append(STITCHED_LEAVE)
	return choices


func _mend_changes_party() -> bool:
	for hero in _heroes:
		if _is_lost_hero(hero):
			continue
		var max_hp: int = int(hero["max_hp"])
		var hp: int = int(hero["hp"])
		@warning_ignore("integer_division")
		var amount: int = (max_hp * MEND_HEAL_PERCENT) / 100
		if mini(max_hp, hp + amount) > hp:
			return true
	return false


## Only an explicit lost == true marks a LOST doll; a missing or false flag is
## a non-lost hero (a Hanging 0-HP hero is not lost and stays healable).
static func _is_lost_hero(hero: Variant) -> bool:
	return typeof(hero) == TYPE_DICTIONARY and hero.get("lost", false) == true


func _tales_changes_party() -> bool:
	for hero in _heroes:
		if int(hero["fray"]) > 0:
			return true
	return false


func _stitched_quote() -> Dictionary:
	var choices: Array = _stitched_choices()
	if choices.is_empty():
		return {"text": "The fire has been tended; no choice remains.", "choices": choices}
	var phrases: Array = []
	for choice in choices:
		match String(choice):
			MEND:
				phrases.append("Mend each hero for 30% of their utmost HP")
			TELL_TALES:
				phrases.append("Tell Tales to unravel 25 FRAY from every hero")
			TRIM_THE_WICK:
				phrases.append("Trim the Wick to recover 50 CANDLE")
			STITCHED_LEAVE:
				phrases.append("Leave the fire as it is")
	var text := "Four ragdoll stitches settle round the guttering flame. "
	if phrases.size() == 1:
		text += "No stitch needs tending tonight; " + String(phrases[0]) + "."
	else:
		text += ", ".join(phrases.slice(0, phrases.size() - 1)) + ", or " \
			+ String(phrases[phrases.size() - 1]) + "."
	return {"text": text, "choices": choices}


func _matches_stitched_open(expected_node_id: Variant,
		expected_heroes: Variant, expected_candle: Variant) -> bool:
	return (
		_status == STITCHED_OPEN
		and _valid_node_id(expected_node_id)
		and expected_node_id == _node_id
		and typeof(expected_heroes) == TYPE_ARRAY
		and expected_heroes == _heroes
		and RunRestRecovery._is_integral_number(expected_candle)
		and int(expected_candle) == _candle
	)


static func _is_stitched_decision(decision: Variant) -> bool:
	if typeof(decision) != TYPE_STRING:
		return false
	var value: String = decision
	return value == MEND or value == TELL_TALES or value == TRIM_THE_WICK or value == STITCHED_LEAVE


static func _is_valid_stitched_party(party: Variant, candle: Variant) -> bool:
	if typeof(party) != TYPE_ARRAY or party.size() != STITCHED_PARTY_SIZE:
		return false
	if not RunRestRecovery._is_integral_number(candle):
		return false
	var candle_value := int(candle)
	if candle_value < 0 or candle_value > STITCHED_CANDLE_MAX:
		return false
	var ids: Dictionary = {}
	for index in range(STITCHED_PARTY_SIZE):
		var hero: Variant = party[index]
		if typeof(hero) != TYPE_DICTIONARY:
			return false
		if not hero.has("id") or typeof(hero["id"]) != TYPE_STRING:
			return false
		var hero_id: String = hero["id"]
		if hero_id.strip_edges().is_empty() or ids.has(hero_id):
			return false
		ids[hero_id] = true
		for field in ["position", "max_hp", "hp", "fray"]:
			if not hero.has(field) or not RunRestRecovery._is_integral_number(hero[field]):
				return false
		if int(hero["position"]) != index + 1:
			return false
		var max_hp: int = int(hero["max_hp"])
		if max_hp <= 0 or int(hero["hp"]) < 0 or int(hero["hp"]) > max_hp:
			return false
		var fray: int = int(hero["fray"])
		if fray < 0 or fray > STITCHED_FRAY_MAX:
			return false
	return true


static func _stitched_rejected() -> Dictionary:
	return {"ok": false, "decision": "", "node_id": "", "heroes": [], "candle": 0}


func _stitched_receipt(decision: String) -> Dictionary:
	var receipt := {
		"ok": true,
		"decision": decision,
		"node_id": _node_id,
		"heroes": _heroes.duplicate(true),
		"candle": _candle,
	}
	if _swap != null:
		receipt["satchel"] = _satchel.duplicate(true)
	return receipt


func _matches_open_visit(expected_node_id: Variant, expected_heroes: Variant) -> bool:
	return _status == OPEN and _valid_node_id(expected_node_id) \
		and expected_node_id == _node_id \
		and typeof(expected_heroes) == TYPE_ARRAY \
		and expected_heroes == _heroes


static func _valid_node_id(candidate: Variant) -> bool:
	if typeof(candidate) != TYPE_STRING:
		return false
	var value: String = candidate
	return not value.is_empty() and value == value.strip_edges()


static func _rejected() -> Dictionary:
	return {"ok": false, "decision": "", "node_id": "", "heroes": []}


func _receipt(decision: String) -> Dictionary:
	return {
		"ok": true,
		"decision": decision,
		"node_id": _node_id,
		"heroes": _heroes.duplicate(true),
	}
