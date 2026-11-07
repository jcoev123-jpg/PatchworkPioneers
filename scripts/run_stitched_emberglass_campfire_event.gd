class_name RunStitchedEmberglassCampfireEvent
extends RefCounted
## Scene-free Design v4 (Stitched) Emberglass Campfire Event waystation admission and settlement adapter.
##
## Wraps RunV3ServiceWaystationEventGate for the authentic Emberglass Campfire Event
## ("v3_emberglass_campfire") authored in res://data/events/v3_service_waystation_events.json.
##
## Paid choice "light_the_embers" costs {gold: 0, scraps: -1} and issues service_request: {"stop_type": "Campfire"}
## only when the party can afford the toll AND at least one Campfire recovery would actually help
## (any non-lost hero HP < max_hp, any non-lost hero FRAY > 0, or candle < 100).
## Alternate trade "sell_cinders" ({gold: +12, scraps: 0}) and "leave" ({gold: 0, scraps: 0})
## remain available as authored without issuing a service request.

const EVENT_ID := "v3_emberglass_campfire"
const EVENT_TITLE := "The Emberglass Hearth"
const SERVICE_CHOICE_ID := "light_the_embers"
const TRADE_CHOICE_ID := "sell_cinders"
const LEAVE_CHOICE_ID := "leave"
const SERVICE_KIND := "Campfire"

const HERO_COUNT := 4
const MIN_RANK := 1
const MAX_RANK := 4
const FRAY_MAX := 200
const CANDLE_MAX := 100
const PAID_SCRAPS_COST := 1
const TRADE_GOLD_GAIN := 12

const MEND_HEAL_PERCENT := 30
const TALES_FRAY_REDUCTION := 25
const WICK_CANDLE_RESTORE := 50

const CANONICAL_HERO_IDS := [
	"warden",
	"seamstress",
	"tinker",
	"lantern_monk",
	"rag_duelist",
	"scarecrow",
	"yarn_ranger",
	"button_golem",
]

var _node_id: String = ""
var _event_id: String = ""
var _service_choice_id: String = ""
var _service_kind: String = ""
var _heroes: Array = []
var _candle: int = 0
var _wallet: Dictionary = {}
var _wren_fear: int = 0

var _gate: RunV3ServiceWaystationEventGate = null
var _open: bool = false
var _valid: bool = false
var _claimed: bool = false
var _version: int = 0
var _error: String = ""


func _init(
	arg1: Variant = null,
	arg2: Variant = null,
	arg3: Variant = null,
	arg4: Variant = null,
	arg5: Variant = null,
	arg6: Variant = null,
	arg7: Variant = 0
) -> void:
	var event_target: Variant = null
	var node_id: Variant = null
	var heroes: Variant = arg3
	var candle: Variant = arg4
	var wallet: Variant = arg5
	var catalog_data: Variant = arg6
	var wren_fear: Variant = arg7

	# Disambiguate arg1 / arg2: supports (event_target, node_id, ...) or (node_id, event_target, ...)
	if _is_likely_event_target(arg1) and not _is_likely_event_target(arg2):
		event_target = arg1
		node_id = arg2
	elif _is_likely_event_target(arg2) and not _is_likely_event_target(arg1):
		event_target = arg2
		node_id = arg1
	elif typeof(arg1) == TYPE_STRING and arg1 == EVENT_ID:
		event_target = arg1
		node_id = arg2
	elif typeof(arg2) == TYPE_STRING and arg2 == EVENT_ID:
		node_id = arg1
		event_target = arg2
	else:
		# Fall back to positional convention: node_id first, event_target second
		node_id = arg1
		event_target = arg2

	# Disambiguate candle and wallet if swapped
	if typeof(candle) == TYPE_DICTIONARY and (typeof(wallet) == TYPE_INT or typeof(wallet) == TYPE_FLOAT):
		var temp: Variant = candle
		candle = wallet
		wallet = temp

	_error = _setup(node_id, event_target, heroes, candle, wallet, catalog_data, wren_fear)
	if not _error.is_empty():
		_open = false
		_valid = false
	else:
		_open = true
		_valid = true


static func open(
	node_id: Variant,
	event_target: Variant,
	heroes: Variant,
	candle: Variant,
	wallet: Variant,
	catalog_data: Variant = null,
	wren_fear: Variant = 0
) -> RunStitchedEmberglassCampfireEvent:
	return RunStitchedEmberglassCampfireEvent.new(
		node_id,
		event_target,
		heroes,
		candle,
		wallet,
		catalog_data,
		wren_fear
	)


func is_valid() -> bool:
	return _error.is_empty() and _open and not _claimed and _gate != null and _gate.is_valid()


func is_open() -> bool:
	return _open


func is_claimed() -> bool:
	return _claimed


func get_node_id() -> String:
	return _node_id


func get_event_id() -> String:
	return _event_id


func get_event_title() -> String:
	return EVENT_TITLE if _valid else ""


func get_title() -> String:
	return EVENT_TITLE if _valid else ""


func get_service_choice_id() -> String:
	return _service_choice_id


func get_service_kind() -> String:
	return _service_kind


func get_candle() -> int:
	return _candle


func get_wren_fear() -> int:
	return _wren_fear


func get_fear() -> int:
	return _wren_fear


func get_wallet() -> Dictionary:
	return _wallet.duplicate(true)


func get_heroes() -> Array:
	return _heroes.duplicate(true)


func get_version() -> int:
	return _version


func get_error() -> String:
	return _error


func get_event() -> Dictionary:
	return _gate.get_event() if _gate != null else {}


func can_mend() -> bool:
	for hero_raw: Variant in _heroes:
		if not (hero_raw is Dictionary):
			continue
		var hero: Dictionary = hero_raw
		if bool(hero.get("lost", false)):
			continue
		if int(hero.get("hp", 0)) < int(hero.get("max_hp", 0)):
			return true
	return false


func can_tell_tales() -> bool:
	if _wren_fear > 0:
		return true
	for hero_raw: Variant in _heroes:
		if not (hero_raw is Dictionary):
			continue
		var hero: Dictionary = hero_raw
		if bool(hero.get("lost", false)):
			continue
		if int(hero.get("fray", 0)) > 0:
			return true
	return false


func can_trim_wick() -> bool:
	return _candle < CANDLE_MAX


func has_useful_recovery() -> bool:
	return can_mend() or can_tell_tales() or can_trim_wick()


func has_useful_remedy() -> bool:
	return has_useful_recovery()


func read_state() -> Dictionary:
	if not _error.is_empty():
		return {"ok": false, "error": _error}
	return {
		"ok": true,
		"node_id": _node_id,
		"event_id": _event_id,
		"service_choice_id": _service_choice_id,
		"service_kind": _service_kind,
		"open": _open,
		"claimed": _claimed,
		"version": _version,
		"wallet": _wallet.duplicate(true),
		"heroes": _heroes.duplicate(true),
		"candle": _candle,
		"wren_fear": _wren_fear,
	}


func preview_choices(wallet: Variant = null) -> Dictionary:
	var denied := {
		"ok": false,
		"node_id": _node_id,
		"event_id": _event_id,
		"service_choice_id": _service_choice_id,
		"service_kind": _service_kind,
		"open": _open,
		"version": _version,
		"choices": [],
		"state": read_state(),
	}
	if not is_valid() or _claimed or not _error.is_empty():
		return denied

	var active_wallet: Dictionary = _wallet
	if wallet != null:
		var parsed_wallet := RunV3ServiceWaystationEventGate._parse_wallet(wallet)
		if not parsed_wallet.get("ok", false):
			return denied
		active_wallet = parsed_wallet["wallet"]

	var raw_preview: Dictionary = _gate.preview_choices(active_wallet)
	if not raw_preview.get("ok", false):
		return denied

	var raw_choices: Variant = raw_preview.get("choices")
	if not (raw_choices is Array):
		return denied

	var useful := has_useful_recovery()
	var entries: Array = []
	for item_raw: Variant in (raw_choices as Array):
		if not (item_raw is Dictionary):
			return denied
		var item: Dictionary = (item_raw as Dictionary).duplicate(true)
		var cid: String = String(item.get("choice_id", ""))
		var affordable: bool = bool(item.get("affordable", false))

		if cid == _service_choice_id:
			var can_act := affordable and useful
			item["available"] = can_act
			item["actionable"] = can_act
			item["service_request"] = {"stop_type": _service_kind} if can_act else {}
		else:
			item["available"] = affordable
			item["actionable"] = true
			item["service_request"] = {}

		entries.append(item)

	return {
		"ok": true,
		"node_id": _node_id,
		"event_id": _event_id,
		"service_choice_id": _service_choice_id,
		"service_kind": _service_kind,
		"open": _open,
		"version": _version,
		"choices": entries,
		"state": read_state(),
	}


func quote() -> Dictionary:
	return preview_choices()


func choose(choice_id: Variant, expected_node_id: Variant = null, expected_state: Variant = null) -> Dictionary:
	var gate_err := _gate_check(expected_node_id, expected_state)
	if not gate_err.is_empty():
		return _fail(gate_err)

	if not (choice_id is String) or String(choice_id).strip_edges().is_empty():
		return _fail("choice id must be a nonempty string")
	var target_id := String(choice_id)

	var preview := preview_choices()
	if not preview.get("ok", false):
		return _fail("failed to preview choices")

	var target_choice_preview: Dictionary = {}
	for item_raw: Variant in preview.get("choices", []):
		if item_raw is Dictionary and String((item_raw as Dictionary).get("choice_id", "")) == target_id:
			target_choice_preview = item_raw
			break

	if target_choice_preview.is_empty():
		return _fail("unknown or unoffered choice id: " + target_id)

	if target_id == _service_choice_id:
		if not has_useful_recovery():
			return _fail("paid service choice is unavailable or actionless")
		if not bool(target_choice_preview.get("available", false)):
			return _fail("paid service choice is unavailable or actionless")
	else:
		if not bool(target_choice_preview.get("available", false)):
			return _fail("choice is unaffordable")

	var before_state := read_state()
	var settlement := _gate.choose_with_wallet(target_id, _wallet)
	if not settlement.get("ok", false):
		return _fail("settlement refused by underlying gate")

	_claimed = true
	_open = false
	_version += 1
	_wallet = (settlement.get("wallet", {}) as Dictionary).duplicate(true)
	var after_state := read_state()

	var service_request: Dictionary = (
		{"stop_type": _service_kind}
		if target_id == _service_choice_id
		else {}
	)

	return {
		"ok": true,
		"error": "",
		"event_id": _event_id,
		"choice_id": target_id,
		"wallet": _wallet.duplicate(true),
		"service_request": service_request,
		"source_state": before_state,
		"state": after_state,
	}


func claim(choice_id: Variant, expected_node_id: Variant = null, expected_state: Variant = null) -> Dictionary:
	return choose(choice_id, expected_node_id, expected_state)


func claim_choice(choice_id: Variant, expected_node_id: Variant = null, expected_state: Variant = null) -> Dictionary:
	return choose(choice_id, expected_node_id, expected_state)


func choose_with_wallet(choice_id: Variant, expected_node_id: Variant = null, expected_state: Variant = null) -> Dictionary:
	return choose(choice_id, expected_node_id, expected_state)


func leave(expected_node_id: Variant = null, expected_state: Variant = null) -> Dictionary:
	return choose(LEAVE_CHOICE_ID, expected_node_id, expected_state)


func _gate_check(expected_node_id: Variant, expected_state: Variant) -> String:
	if not _error.is_empty():
		return _error
	if not _open or _claimed:
		return "visit is closed"
	if typeof(expected_node_id) != TYPE_STRING or str(expected_node_id).strip_edges().is_empty() or str(expected_node_id) != _node_id:
		return "wrong node"
	if not (expected_state is Dictionary):
		return "expected state must be a dictionary"
	if JSON.stringify(expected_state, "", true) != JSON.stringify(read_state(), "", true):
		return "stale or forged state"
	return ""


func _fail(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
		"event_id": "",
		"choice_id": "",
		"wallet": _wallet.duplicate(true),
		"service_request": {},
		"state": read_state(),
	}


func _setup(
	node_id: Variant,
	event_target: Variant,
	heroes: Variant,
	candle: Variant,
	wallet: Variant,
	catalog_data: Variant,
	wren_fear: Variant
) -> String:
	# 1. Node ID
	if typeof(node_id) != TYPE_STRING or str(node_id).strip_edges().is_empty() or str(node_id) != str(node_id).strip_edges():
		return "node id must be a nonempty trimmed string"
	_node_id = str(node_id)

	# 2. Candle
	if candle == null:
		return "candle is required"
	var candle_ok := typeof(candle) == TYPE_INT
	if typeof(candle) == TYPE_FLOAT:
		var c_float := float(candle)
		candle_ok = is_finite(c_float) and c_float == floorf(c_float)
	if not candle_ok:
		return "candle must be an integer"
	var candle_val := int(candle)
	if candle_val < 0 or candle_val > CANDLE_MAX:
		return "candle must be between 0 and %d" % CANDLE_MAX
	_candle = candle_val

	# 3. Wallet
	var parsed_wallet := RunV3ServiceWaystationEventGate._parse_wallet(wallet)
	if not parsed_wallet.get("ok", false):
		return "wallet must be a dictionary with nonnegative integer gold and scraps"
	_wallet = (parsed_wallet["wallet"] as Dictionary).duplicate(true)

	# 4. Event Target / Gate
	if event_target == null:
		return "event target is required"
	var gate := RunV3ServiceWaystationEventGate.new(event_target, catalog_data)
	if not gate.is_valid():
		return "invalid event target or catalog"
	if gate.get_service_kind() != SERVICE_KIND:
		return "event is not a Campfire waystation"
	if gate.get_event_id() != EVENT_ID:
		return "event ID is not authentic Emberglass Campfire"
	if gate.get_service_choice_id() != SERVICE_CHOICE_ID:
		return "service choice ID does not match Emberglass"

	var ev_record := gate.get_event()
	if String(ev_record.get("title", "")) != EVENT_TITLE:
		return "event title does not match The Emberglass Hearth"

	var raw_choices: Variant = ev_record.get("choices")
	if not (raw_choices is Array) or (raw_choices as Array).size() != 3:
		return "event must offer exactly three choices"

	_gate = gate
	_event_id = gate.get_event_id()
	_service_choice_id = gate.get_service_choice_id()
	_service_kind = gate.get_service_kind()

	# 5. Heroes
	if not (heroes is Array) or (heroes as Array).size() != HERO_COUNT:
		return "roster needs exactly %d heroes" % HERO_COUNT

	var seen_ids := {}
	var seen_ranks := {}
	var clean_heroes: Array = []

	for hero_raw: Variant in (heroes as Array):
		if not (hero_raw is Dictionary):
			return "hero record must be a dictionary"
		var hero_dict: Dictionary = hero_raw

		# Hero ID
		if not hero_dict.has("id") or typeof(hero_dict["id"]) != TYPE_STRING:
			return "hero record needs an id string"
		var hero_id := str(hero_dict["id"])
		if hero_id.strip_edges().is_empty():
			return "hero id cannot be blank"
		if not CANONICAL_HERO_IDS.has(hero_id):
			return "hero %s is not a canonical hero id" % hero_id
		if seen_ids.has(hero_id):
			return "duplicate hero id: " + hero_id
		seen_ids[hero_id] = true

		# Rank / Position (explicit, no defaults or inferred roster values)
		var has_rank := hero_dict.has("rank")
		var has_pos := hero_dict.has("position")
		if not has_rank and not has_pos:
			return "hero %s is missing rank" % hero_id
		var raw_rank: Variant = hero_dict["rank"] if has_rank else hero_dict["position"]
		var rank_ok := typeof(raw_rank) == TYPE_INT
		if typeof(raw_rank) == TYPE_FLOAT:
			var r_float := float(raw_rank)
			rank_ok = is_finite(r_float) and r_float == floorf(r_float)
		if not rank_ok:
			return "hero %s rank must be an integer" % hero_id
		var rank_int := int(raw_rank)
		if rank_int < MIN_RANK or rank_int > MAX_RANK:
			return "hero %s rank must be 1..%d" % [hero_id, MAX_RANK]
		if seen_ranks.has(rank_int):
			return "duplicate rank %d" % rank_int
		seen_ranks[rank_int] = true

		# max_hp (must be positive)
		if not hero_dict.has("max_hp"):
			return "hero %s is missing max_hp" % hero_id
		var raw_max_hp: Variant = hero_dict["max_hp"]
		var max_hp_ok := typeof(raw_max_hp) == TYPE_INT
		if typeof(raw_max_hp) == TYPE_FLOAT:
			var m_float := float(raw_max_hp)
			max_hp_ok = is_finite(m_float) and m_float == floorf(m_float)
		if not max_hp_ok or int(raw_max_hp) <= 0:
			return "hero %s max_hp must be a positive integer" % hero_id
		var max_hp_int := int(raw_max_hp)

		# hp (0..max_hp)
		if not hero_dict.has("hp"):
			return "hero %s is missing hp" % hero_id
		var raw_hp: Variant = hero_dict["hp"]
		var hp_ok := typeof(raw_hp) == TYPE_INT
		if typeof(raw_hp) == TYPE_FLOAT:
			var h_float := float(raw_hp)
			hp_ok = is_finite(h_float) and h_float == floorf(h_float)
		if not hp_ok or int(raw_hp) < 0 or int(raw_hp) > max_hp_int:
			return "hero %s hp must be 0..max_hp" % hero_id
		var hp_int := int(raw_hp)

		# fray (0..200)
		if not hero_dict.has("fray"):
			return "hero %s is missing fray" % hero_id
		var raw_fray: Variant = hero_dict["fray"]
		var fray_ok := typeof(raw_fray) == TYPE_INT
		if typeof(raw_fray) == TYPE_FLOAT:
			var f_float := float(raw_fray)
			fray_ok = is_finite(f_float) and f_float == floorf(f_float)
		if not fray_ok or int(raw_fray) < 0 or int(raw_fray) > FRAY_MAX:
			return "hero %s fray must be 0..%d" % [hero_id, FRAY_MAX]
		var fray_int := int(raw_fray)

		# Optional lost boolean
		var is_lost := false
		if hero_dict.has("lost"):
			if typeof(hero_dict["lost"]) != TYPE_BOOL:
				return "hero %s lost field must be boolean" % hero_id
			is_lost = bool(hero_dict["lost"])

		var clean_hero := hero_dict.duplicate(true)
		clean_hero["id"] = hero_id
		if has_rank:
			clean_hero["rank"] = rank_int
		if has_pos:
			clean_hero["position"] = rank_int
		clean_hero["max_hp"] = max_hp_int
		clean_hero["hp"] = hp_int
		clean_hero["fray"] = fray_int
		if hero_dict.has("lost"):
			clean_hero["lost"] = is_lost
		clean_heroes.append(clean_hero)

	if seen_ranks.size() != HERO_COUNT:
		return "party must cover all ranks 1..%d" % HERO_COUNT

	_heroes = clean_heroes

	# 6. Wren Fear (0..100)
	if wren_fear == null:
		return "wren fear is required"
	var fear_ok := typeof(wren_fear) == TYPE_INT
	if typeof(wren_fear) == TYPE_FLOAT:
		var f_float := float(wren_fear)
		fear_ok = is_finite(f_float) and f_float == floorf(f_float)
	if not fear_ok:
		return "wren fear must be an integer"
	var fear_val := int(wren_fear)
	if fear_val < 0 or fear_val > 100:
		return "wren fear must be between 0 and 100"
	_wren_fear = fear_val

	return ""


static func _is_likely_event_target(val: Variant) -> bool:
	if typeof(val) == TYPE_DICTIONARY:
		var d: Dictionary = val
		return d.has("id") and d.has("choices") and d.has("service_choice_id")
	return false
