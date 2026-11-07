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
## An Unravelled resolve persists until FRAY is strictly below this value.
const RESOLVE_CLEAR_BELOW := 50
const WICK_CANDLE_RESTORE := 50
## Opt-in Wren FEAR (STITCHED_DESIGN 9c): Tell Tales also soothes 15 FEAR.
const FEAR_MAX := 100
const TALES_FEAR_RELIEF := 15

var _node_id: String = ""
var _heroes: Array = []
var _status: String = INVALID
var _mode: String = ""
var _candle: int = 0
# Opt-in part-swap extension (null/empty unless opened with a satchel).
var _swap: RunStitchedSewingSwap = null
var _satchel: Array = []
var _swap_state: Dictionary = {}
# Opt-in Wren FEAR scalar (only held when a real 0..100 integer was supplied).
var _has_fear: bool = false
var _fear: int = 0


func _init(node_id: Variant = null, run_heroes: Variant = null,
		mode: Variant = null, candle: Variant = null, fear: Variant = null) -> void:
	if not _valid_node_id(node_id) or typeof(run_heroes) != TYPE_ARRAY:
		return
	if mode == null:
		# Legacy three-hero service, byte-for-byte unchanged. A fear input is
		# only meaningful for Stitched, so it fails closed here.
		if fear != null:
			return
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
	if fear != null:
		if not _is_valid_fear(fear):
			return
		_has_fear = true
		_fear = int(fear)
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
		candle: Variant, satchel: Variant, catalog_by_id: Variant,
		fear: Variant = null) -> RunCampfireVisit:
	var visit := RunCampfireVisit.new(node_id, run_heroes, STITCHED, candle, fear)
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
	var swap_receipt := {
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
	if _has_fear:
		swap_receipt["fear"] = _fear
	return swap_receipt


## One optional direct exchange of the intact same-slot worn parts of two
## different living dolls before the single recovery decision. Works with an
## empty satchel and has no price, tier change, movement, healing or RNG draw.
## expected_state follows swap_part's convention (latest swap_state or the
## complete latest read_state()). RunStitchedSewingSwap.exchange_worn remains
## the only authority for legality; this only gates and reconciles the result.
func exchange_worn_parts(hero_a_id: Variant, hero_b_id: Variant, slot: Variant,
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
	var result: Dictionary = _swap.exchange_worn(hero_a_id, hero_b_id, slot, expected_node_id, swap_expected)
	if result.get("ok") != true:
		return _swap_rejected(str(result.get("error", "exchange refused")))
	# Reconcile both changed dolls' gear records; every other field is kept.
	var changed: Array = result.get("changed_heroes", [])
	for changed_hero in changed:
		for index in range(_heroes.size()):
			if str(_heroes[index]["id"]) == str(changed_hero["id"]):
				_heroes[index]["parts"] = changed_hero["parts"].duplicate(true)
	_satchel = result["satchel"].duplicate(true)
	_swap_state = result["state"].duplicate(true)
	var exchange_receipt := {
		"ok": true,
		"error": "",
		"action": "exchange_worn",
		"node_id": _node_id,
		"hero_a_id": str(hero_a_id),
		"hero_b_id": str(hero_b_id),
		"slot": str(slot),
		"worn_before": result["worn_before"].duplicate(true),
		"worn_after": result["worn_after"].duplicate(true),
		"heroes": _heroes.duplicate(true),
		"satchel": _satchel.duplicate(true),
		"candle": _candle,
		"swap_state": _swap_state.duplicate(true),
	}
	if _has_fear:
		exchange_receipt["fear"] = _fear
	return exchange_receipt


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
		if _has_fear:
			state["fear"] = _fear
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
		expected_heroes: Variant, expected_candle: Variant,
		expected_fear: Variant = null) -> Dictionary:
	if not _matches_stitched_open(expected_node_id, expected_heroes, expected_candle) or not _is_stitched_decision(decision):
		return _stitched_rejected()
	# An opted-in visit needs the exact current fear; a visit without fear
	# accepts none. A missing or stale value never authorises a selection.
	if _has_fear:
		if typeof(expected_fear) != TYPE_INT or int(expected_fear) != _fear:
			return _stitched_rejected()
	elif expected_fear != null:
		return _stitched_rejected()
	# A choice that cannot change anything is not advertised, so it is refused
	# here without consuming the visit or touching the swap opportunity.
	if not _stitched_choices().has(String(decision)):
		return _stitched_rejected()
	var updated: Array = _heroes.duplicate(true)
	var candle: int = _candle
	var fear: int = _fear
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
				# Any heal above 0 HP ends Hanging. Only an explicit true flag
				# is cleared; an absent key is never fabricated.
				if hero.get("hanging", false) == true and int(hero["hp"]) > 0:
					hero["hanging"] = false
		TELL_TALES:
			for hero in updated:
				var reduced: int = maxi(0, int(hero["fray"]) - TALES_FRAY_REDUCTION)
				hero["fray"] = reduced
				# An Unravelled trait ends once FRAY is strictly below 50 (exactly
				# 50 keeps it). Only a present, known trait is cleared; Steadfast,
				# empty, unknown and missing resolve stay as they were. No roll.
				if reduced < RESOLVE_CLEAR_BELOW and hero.has("resolve") \
						and str(hero["resolve"]) in StitchedS1BEffects.RESOLVE_TRAITS:
					hero["resolve"] = ""
			if _has_fear:
				fear = maxi(0, fear - TALES_FEAR_RELIEF)
		TRIM_THE_WICK:
			candle = mini(STITCHED_CANDLE_MAX, candle + WICK_CANDLE_RESTORE)
		STITCHED_LEAVE:
			pass
		_:
			return _stitched_rejected()
	_heroes = updated
	_candle = candle
	_fear = fear
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
	if _has_fear and _fear > 0:
		return true
	for hero in _heroes:
		if int(hero["fray"]) > 0:
			return true
	return false


func _stitched_quote() -> Dictionary:
	var choices: Array = _stitched_choices()
	if choices.is_empty():
		return {"text": "The fire has been tended; no choice remains.", "choices": choices}
	# Each phrase keeps the authored maximum and adds the actual cap-aware
	# total the held party and candle would gain right now.
	var phrases: Array = []
	for choice in choices:
		match String(choice):
			MEND:
				phrases.append("Mend %d%% max HP (+%d HP now)%s" % [MEND_HEAL_PERCENT, _mend_gain_now(),
					_beneficiary_suffix(_mend_gains_by_doll(), "+%d HP") + _mend_hanging_ends_suffix()])
			TELL_TALES:
				var relief := "-%d FRAY now" % _tales_fray_relief_now()
				if _has_fear:
					relief += "; -%d Wren FEAR now" % _tales_fear_relief_now()
				phrases.append("Tell Tales up to %d FRAY each (%s)%s%s" % [TALES_FRAY_REDUCTION, relief,
					_beneficiary_suffix(_tales_relief_by_doll(), "-%d FRAY"),
					_tales_resolve_clear_suffix()])
			TRIM_THE_WICK:
				phrases.append("Trim the Wick up to %d CANDLE (+%d now)" % [WICK_CANDLE_RESTORE, _wick_gain_now()])
			STITCHED_LEAVE:
				phrases.append("Leave (free, no change)")
	var text := "Four ragdoll stitches settle round the guttering flame. "
	if phrases.size() == 1:
		text += "No stitch needs tending tonight; " + String(phrases[0]) + "."
	else:
		text += "Choose one: " + ", ".join(phrases.slice(0, phrases.size() - 1)) + ", or " \
			+ String(phrases[phrases.size() - 1]) + "."
	return {"text": text, "choices": choices}


## Per-doll Mend gains in held roster order (zero for LOST or full dolls).
func _mend_gains_by_doll() -> Array:
	var gains: Array = []
	for hero in _heroes:
		var gain: int = 0
		if not _is_lost_hero(hero):
			var max_hp: int = int(hero["max_hp"])
			@warning_ignore("integer_division")
			var amount: int = (max_hp * MEND_HEAL_PERCENT) / 100
			gain = mini(amount, max_hp - int(hero["hp"]))
		gains.append(gain)
	return gains


## Pure preview of select(MEND)'s Hanging release, in held roster order:
## " [Hanging ends: Name, ...]" for each non-LOST doll at 0 HP whose actual Mend
## gain is positive. Empty when nobody qualifies. Never mutates state.
func _mend_hanging_ends_suffix() -> String:
	var gains: Array = _mend_gains_by_doll()
	var parts: Array = []
	for index in range(mini(gains.size(), _heroes.size())):
		var hero: Dictionary = _heroes[index]
		if _is_lost_hero(hero) or int(hero["hp"]) != 0 or int(gains[index]) <= 0:
			continue
		parts.append(str(hero.get("name", hero["id"])))
	if parts.is_empty():
		return ""
	return " [Hanging ends: " + ", ".join(parts) + "]"


## Per-doll Tell Tales FRAY relief in held roster order (LOST included).
func _tales_relief_by_doll() -> Array:
	var reliefs: Array = []
	for hero in _heroes:
		reliefs.append(mini(TALES_FRAY_REDUCTION, int(hero["fray"])))
	return reliefs


## Pure preview of select(TELL_TALES)'s resolve clearing, in held roster order:
## " [Resolve clears: Name (trait), ...]" for each doll whose post-Tales FRAY is
## below RESOLVE_CLEAR_BELOW and whose present resolve is a named Unravelled
## trait. Empty when nobody qualifies. Mirrors select(); never mutates state.
func _tales_resolve_clear_suffix() -> String:
	var parts: Array = []
	for hero in _heroes:
		var reduced: int = maxi(0, int(hero["fray"]) - TALES_FRAY_REDUCTION)
		if reduced >= RESOLVE_CLEAR_BELOW or not hero.has("resolve"):
			continue
		var trait_name: String = str(hero["resolve"])
		if not (trait_name in StitchedS1BEffects.RESOLVE_TRAITS):
			continue
		parts.append("%s (%s)" % [str(hero.get("name", hero["id"])), trait_name])
	if parts.is_empty():
		return ""
	return " [Resolve clears: " + ", ".join(parts) + "]"


## " [Name +N HP, ...]" listing only positive deltas; empty when nobody benefits.
func _beneficiary_suffix(deltas: Array, delta_format: String) -> String:
	var parts: Array = []
	for index in range(mini(deltas.size(), _heroes.size())):
		var delta: int = int(deltas[index])
		if delta <= 0:
			continue
		var hero: Dictionary = _heroes[index]
		parts.append("%s %s" % [str(hero.get("name", hero["id"])), delta_format % delta])
	if parts.is_empty():
		return ""
	return " [" + ", ".join(parts) + "]"


## Actual HP Mend would restore now: per non-LOST doll min(floor(30% max), missing HP).
func _mend_gain_now() -> int:
	var total: int = 0
	for hero in _heroes:
		if _is_lost_hero(hero):
			continue
		var max_hp: int = int(hero["max_hp"])
		var hp: int = int(hero["hp"])
		@warning_ignore("integer_division")
		var amount: int = (max_hp * MEND_HEAL_PERCENT) / 100
		total += mini(amount, max_hp - hp)
	return total


## Actual FRAY Tell Tales would remove now, across every held record (LOST included).
func _tales_fray_relief_now() -> int:
	var total: int = 0
	for hero in _heroes:
		total += mini(TALES_FRAY_REDUCTION, int(hero["fray"]))
	return total


## Actual Wren FEAR Tell Tales would soothe now (zero when FEAR is not supplied).
func _tales_fear_relief_now() -> int:
	if not _has_fear:
		return 0
	return mini(TALES_FEAR_RELIEF, _fear)


## Actual CANDLE Trim the Wick would restore now.
func _wick_gain_now() -> int:
	return mini(WICK_CANDLE_RESTORE, STITCHED_CANDLE_MAX - _candle)


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
	if _has_fear:
		receipt["fear"] = _fear
	return receipt


## Only a realinteger 0..100 is a Wren FEAR; bool, float and string are not.
static func _is_valid_fear(candidate: Variant) -> bool:
	return typeof(candidate) == TYPE_INT and int(candidate) >= 0 and int(candidate) <= FEAR_MAX


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
