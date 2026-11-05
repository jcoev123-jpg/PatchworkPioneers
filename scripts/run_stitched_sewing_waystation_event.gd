class_name RunStitchedSewingWaystationEvent
extends RefCounted
## Scene-free Design v4 (Stitched) Sewing Circle Event waystation admission and settlement adapter.
##
## Wraps RunV3ServiceWaystationEventGate for authentic Sewing Circle Events
## ("v3_threadmill_sewing_circle" and "v3_moonlace_darning_parlor").
## A paid entrance toll may only be claimed when the player's Stitched party/satchel
## has at least one usable action (swap, mend, or 1-tier upgrade) under the post-toll wallet.
## Alternate trade choices and Leave remain accessible as authored.

const SEWING_CIRCLE_EVENT_IDS := [
	"v3_threadmill_sewing_circle",
	"v3_moonlace_darning_parlor",
]
const SATCHEL_CAP := 6
const HERO_COUNT := 4

var _node_id: String = ""
var _event_id: String = ""
var _service_choice_id: String = ""
var _service_kind: String = ""
var _heroes: Array = []
var _satchel: Array = []
var _wallet: Dictionary = {}
var _catalog: Dictionary = {}
var _quoted_mend_cost: int = 0
var _quoted_upgrade_cost: int = 0

var _gate: RunV3ServiceWaystationEventGate = null
var _open: bool = false
var _valid: bool = false
var _claimed: bool = false
var _version: int = 0
var _error: String = ""


func _init(
	event_target: Variant = "",
	node_id: Variant = "",
	heroes: Variant = [],
	satchel: Variant = [],
	wallet: Variant = {},
	catalog_by_id: Variant = {},
	quoted_mend_cost: Variant = 0,
	quoted_upgrade_cost: Variant = 0,
	catalog_data: Variant = null
) -> void:
	_error = _setup(
		event_target,
		node_id,
		heroes,
		satchel,
		wallet,
		catalog_by_id,
		quoted_mend_cost,
		quoted_upgrade_cost,
		catalog_data
	)
	if not _error.is_empty():
		_open = false
		_valid = false
	else:
		_open = true
		_valid = true


func is_valid() -> bool:
	return _error.is_empty() and _open and not _claimed and _gate != null and _gate.is_valid()


func is_claimed() -> bool:
	return _claimed


func is_open() -> bool:
	return _open


func get_event_id() -> String:
	return _event_id


func get_service_choice_id() -> String:
	return _service_choice_id


func get_service_kind() -> String:
	return _service_kind


func get_node_id() -> String:
	return _node_id


func get_wallet() -> Dictionary:
	return _wallet.duplicate(true)


func get_heroes() -> Array:
	return _heroes.duplicate(true)


func get_satchel() -> Array:
	return _satchel.duplicate(true)


func get_quoted_mend_cost() -> int:
	return _quoted_mend_cost


func get_quoted_upgrade_cost() -> int:
	return _quoted_upgrade_cost


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
		"satchel": _satchel.duplicate(true),
		"quoted_mend_cost": _quoted_mend_cost,
		"quoted_upgrade_cost": _quoted_upgrade_cost,
		"mend_cost": _quoted_mend_cost,
		"upgrade_cost": _quoted_upgrade_cost,
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

	var entries: Array = []
	for item_raw: Variant in (raw_choices as Array):
		if not (item_raw is Dictionary):
			return denied
		var item: Dictionary = (item_raw as Dictionary).duplicate(true)
		var cid: String = String(item.get("choice_id", ""))
		var affordable: bool = bool(item.get("affordable", false))

		if cid == _service_choice_id:
			if affordable:
				var post_toll_wallet_raw: Variant = item.get("wallet")
				var post_toll_scraps: int = 0
				if post_toll_wallet_raw is Dictionary:
					post_toll_scraps = int((post_toll_wallet_raw as Dictionary).get("scraps", 0))
				var has_action := _has_usable_action(post_toll_scraps)
				item["available"] = has_action
				item["actionable"] = has_action
				item["service_request"] = {"stop_type": _service_kind} if has_action else {}
			else:
				item["available"] = false
				item["actionable"] = false
				item["service_request"] = {}
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
		if not bool(target_choice_preview.get("available", false)):
			return _fail("paid service choice is unavailable or actionless")

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


func claim_choice(choice_id: Variant, expected_node_id: Variant = null, expected_state: Variant = null) -> Dictionary:
	return choose(choice_id, expected_node_id, expected_state)


func choose_with_wallet(choice_id: Variant, expected_node_id: Variant = null, expected_state: Variant = null) -> Dictionary:
	return choose(choice_id, expected_node_id, expected_state)


func leave(expected_node_id: Variant = null, expected_state: Variant = null) -> Dictionary:
	return choose(RunV3ServiceWaystationEventGate.LEAVE_CHOICE_ID, expected_node_id, expected_state)


func _has_usable_action(post_toll_scraps: int) -> bool:
	var swap_service := RunStitchedSewingSwap.new(_node_id, _heroes, _satchel, _catalog)
	var swap_quote := swap_service.quote()

	var mend_service := RunStitchedSewingMend.new(_node_id, _heroes, post_toll_scraps, _quoted_mend_cost, _catalog)
	var mend_quote := mend_service.quote()

	var upgrade_service := RunStitchedSewingUpgrade.new(_node_id, _heroes, post_toll_scraps, _quoted_upgrade_cost, _catalog)
	var upgrade_quote := upgrade_service.quote()

	var swap_heroes_map := _index_hero_quotes(swap_quote)
	var mend_heroes_map := _index_hero_quotes(mend_quote)
	var upgrade_heroes_map := _index_hero_quotes(upgrade_quote)

	for hero_raw: Variant in _heroes:
		if not (hero_raw is Dictionary):
			continue
		var hero: Dictionary = hero_raw
		if typeof(hero.get("lost")) == TYPE_BOOL and bool(hero["lost"]):
			continue
		var hero_id: String = String(hero.get("id", ""))
		var s_slots: Dictionary = swap_heroes_map.get(hero_id, {})
		var m_slots: Dictionary = mend_heroes_map.get(hero_id, {})
		var u_slots: Dictionary = upgrade_heroes_map.get(hero_id, {})

		for slot: String in StitchedParts.SLOTS:
			if s_slots.has(slot):
				var s_slot: Dictionary = s_slots[slot]
				if bool(s_slot.get("can_swap", false)):
					return true
			if m_slots.has(slot):
				var m_slot: Dictionary = m_slots[slot]
				if bool(m_slot.get("can_mend", false)):
					return true
			if u_slots.has(slot):
				var u_slot: Dictionary = u_slots[slot]
				if bool(u_slot.get("can_upgrade", false)):
					return true

	return false


static func _index_hero_quotes(quote_dict: Dictionary) -> Dictionary:
	var index := {}
	if not quote_dict.get("ok", false):
		return index
	var heroes: Variant = quote_dict.get("heroes")
	if not (heroes is Array):
		return index
	for hero_quote_raw: Variant in (heroes as Array):
		if not (hero_quote_raw is Dictionary):
			continue
		var hero_quote: Dictionary = hero_quote_raw
		var hid: String = String(hero_quote.get("hero_id", ""))
		var slots_map := {}
		var slots_raw: Variant = hero_quote.get("slots")
		if slots_raw is Array:
			for slot_quote_raw: Variant in (slots_raw as Array):
				if not (slot_quote_raw is Dictionary):
					continue
				var slot_quote: Dictionary = slot_quote_raw
				var slot_name: String = String(slot_quote.get("slot", ""))
				slots_map[slot_name] = slot_quote
		index[hid] = slots_map
	return index


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
	event_target: Variant,
	node_id: Variant,
	heroes: Variant,
	satchel: Variant,
	wallet: Variant,
	catalog_by_id: Variant,
	quoted_mend_cost: Variant,
	quoted_upgrade_cost: Variant,
	catalog_data: Variant
) -> String:
	if typeof(node_id) != TYPE_STRING or str(node_id).strip_edges().is_empty() or str(node_id) != str(node_id).strip_edges():
		return "node id must be a nonempty trimmed string"
	_node_id = str(node_id)

	var parsed_wallet := RunV3ServiceWaystationEventGate._parse_wallet(wallet)
	if not parsed_wallet.get("ok", false):
		return "wallet must be a dictionary with nonnegative integer gold and scraps"
	_wallet = (parsed_wallet["wallet"] as Dictionary).duplicate(true)

	if typeof(quoted_mend_cost) != TYPE_INT or int(quoted_mend_cost) <= 0:
		return "quoted mend cost must be a positive integer"
	_quoted_mend_cost = int(quoted_mend_cost)

	if typeof(quoted_upgrade_cost) != TYPE_INT or int(quoted_upgrade_cost) <= 0:
		return "quoted upgrade cost must be a positive integer"
	_quoted_upgrade_cost = int(quoted_upgrade_cost)

	if not (catalog_by_id is Dictionary) or (catalog_by_id as Dictionary).is_empty():
		return "catalog is missing"
	for key: Variant in (catalog_by_id as Dictionary).keys():
		var entry: Variant = (catalog_by_id as Dictionary)[key]
		if typeof(key) != TYPE_STRING or not (entry is Dictionary):
			return "catalog entry is malformed"
		var edict: Dictionary = entry
		if str(edict.get("id", "")) != str(key) or not str(edict.get("slot", "")) in StitchedParts.SLOTS:
			return "catalog entry is malformed: " + str(key)
		if not (edict.get("ability") is Dictionary) or not edict.has("name") or not edict.has("owner") or not edict.has("text"):
			return "catalog entry is incomplete: " + str(key)
	_catalog = (catalog_by_id as Dictionary).duplicate(true)

	if not (heroes is Array) or (heroes as Array).size() != HERO_COUNT:
		return "roster needs exactly %d heroes" % HERO_COUNT
	var seen: Dictionary = {}
	var ranks: Dictionary = {}
	var clean_heroes: Array = []
	for raw: Variant in (heroes as Array):
		if not (raw is Dictionary) or typeof((raw as Dictionary).get("id")) != TYPE_STRING or str((raw as Dictionary)["id"]).is_empty():
			return "hero record needs a nonempty id"
		var raw_dict: Dictionary = raw
		var hero_id := str(raw_dict["id"])
		if seen.has(hero_id):
			return "duplicate hero id: " + hero_id
		seen[hero_id] = true

		var rank: Variant = raw_dict.get("rank", raw_dict.get("position", 0))
		if typeof(rank) != TYPE_INT or int(rank) < 1 or int(rank) > HERO_COUNT or ranks.has(int(rank)):
			return "hero %s needs a distinct ranked position 1-%d" % [hero_id, HERO_COUNT]
		ranks[int(rank)] = true

		if not (raw_dict.get("parts") is Dictionary):
			return "hero %s needs a parts dictionary" % hero_id
		var raw_parts: Dictionary = raw_dict["parts"]
		if raw_dict.get("lost") == true and raw_dict.get("hp") == 0 and raw_parts.is_empty():
			clean_heroes.append(raw_dict.duplicate(true))
			continue
		if raw_parts.size() != StitchedParts.SLOTS.size():
			return "hero %s has an unknown slot" % hero_id

		var clean_hero: Dictionary = raw_dict.duplicate(true)
		var clean_parts: Dictionary = {}
		for slot: String in StitchedParts.SLOTS:
			var part_res := _normalize_part(raw_parts.get(slot), slot, false)
			if not bool(part_res["ok"]):
				return "hero %s %s: %s" % [hero_id, slot, str(part_res["error"])]
			clean_parts[slot] = part_res["part"]
		clean_hero["parts"] = clean_parts
		clean_heroes.append(clean_hero)
	_heroes = clean_heroes

	if not (satchel is Array) or (satchel as Array).size() > SATCHEL_CAP:
		return "satchel holds at most %d parts" % SATCHEL_CAP
	var clean_satchel: Array = []
	for raw_spare: Variant in (satchel as Array):
		if not (raw_spare is Dictionary) or typeof((raw_spare as Dictionary).get("slot")) != TYPE_STRING:
			return "satchel record needs a slot"
		var slot_name := str((raw_spare as Dictionary)["slot"])
		var spare_res := _normalize_part(raw_spare, slot_name, true)
		if not bool(spare_res["ok"]):
			return "satchel: " + str(spare_res["error"])
		clean_satchel.append(spare_res["part"])
	_satchel = clean_satchel

	var gate := RunV3ServiceWaystationEventGate.new(event_target, catalog_data)
	if not gate.is_valid():
		return "invalid event target or catalog"
	if gate.get_service_kind() != "SewingCircle":
		return "event is not a SewingCircle waystation"
	if not SEWING_CIRCLE_EVENT_IDS.has(gate.get_event_id()):
		return "event ID is not an authentic SewingCircle waystation"
	_gate = gate
	_event_id = _gate.get_event_id()
	_service_choice_id = _gate.get_service_choice_id()
	_service_kind = _gate.get_service_kind()

	return ""


func _normalize_part(raw: Variant, slot: String, with_slot: bool) -> Dictionary:
	if not (raw is Dictionary):
		return {"ok": false, "error": "part record is missing or malformed", "part": {}}
	var rdict: Dictionary = raw
	if typeof(rdict.get("id")) != TYPE_STRING or not _catalog.has(str(rdict["id"])):
		return {"ok": false, "error": "unknown part id", "part": {}}
	var catalog_slot := str(_catalog[str(rdict["id"])]["slot"])
	if catalog_slot != slot:
		return {"ok": false, "error": "part %s does not fit slot %s" % [str(rdict["id"]), slot], "part": {}}
	var tier: Variant = rdict.get("tier")
	var tier_ok := typeof(tier) == TYPE_INT
	if typeof(tier) == TYPE_FLOAT:
		var tier_float := float(tier)
		tier_ok = is_finite(tier_float) and tier_float == floorf(tier_float)
	if not tier_ok or int(tier) < StitchedParts.MIN_TIER or int(tier) > StitchedParts.MAX_TIER:
		return {"ok": false, "error": "invalid tier", "part": {}}
	if typeof(rdict.get("torn")) != TYPE_BOOL:
		return {"ok": false, "error": "torn must be a boolean", "part": {}}
	var part := {"id": str(rdict["id"]), "tier": int(tier), "torn": bool(rdict["torn"])}
	if with_slot:
		part["slot"] = slot
	return {"ok": true, "error": "", "part": part}
