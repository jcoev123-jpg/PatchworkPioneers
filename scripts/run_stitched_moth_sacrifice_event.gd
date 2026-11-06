class_name RunStitchedMothSacrificeEvent
extends RefCounted
## Scene-free Design v4 (Stitched) Moth Infestation spare-part sacrifice and alternate choices service.
##
## Milestone S6. Established service contract for the authored "moth_infestation" event
## in res://data/events/stitched_route_effects.json.
## Choices:
## - "sacrifice_part": consumes exactly ONE chosen carried spare body part, awards +2 scraps.
##   Available only when a specific existing spare is selected.
## - "fumigate": spends 1 scrap, no part change. Requires at least 1 scrap.
## - "escape": leaves both scraps and satchel unchanged. Always available.
##
## Follows the guarded, detached node+snapshot/quote contract:
## - No RNG creation or draws.
## - No mutation of caller data (deep copies throughout).
## - Requires both nonblank node ID and exact detached state snapshot guards on every choose/claim path.
## - Refuses forged or missing part/index, empty satchel, malformed catalog or record,
##   wrong node, stale expected state, insufficient scraps, and duplicate claim without latching.

const EVENT_ID := "moth_infestation"
const EVENT_CATALOG_PATH := "res://data/events/stitched_route_effects.json"
const DEFAULT_PARTS_CATALOG_PATH := "res://data/parts/enemy_parts.json"

const CHOICE_SACRIFICE := "sacrifice_part"
const CHOICE_FUMIGATE := "fumigate"
const CHOICE_ESCAPE := "escape"
const CHOICE_LEAVE := "leave"

const SATCHEL_MIN := 0
const SATCHEL_CAP := 6

var _node_id: String = ""
var _event_id: String = EVENT_ID
var _title: String = ""
var _description: String = ""
var _event_record: Dictionary = {}
var _choices_by_id: Dictionary = {}
var _scraps: int = 0
var _satchel: Array = []
var _catalog: Dictionary = {} # part_id -> part_dict
var _open: bool = false
var _valid: bool = false
var _claimed: bool = false
var _version: int = 0
var _error: String = ""


static func open_stitched(
	arg1: Variant = "",
	arg2: Variant = null,
	arg3: Variant = null,
	arg4: Variant = null,
	arg5: Variant = null
) -> RunStitchedMothSacrificeEvent:
	return RunStitchedMothSacrificeEvent.new(arg1, arg2, arg3, arg4, arg5)


func _init(
	arg1: Variant = "",
	arg2: Variant = null,
	arg3: Variant = null,
	arg4: Variant = null,
	arg5: Variant = null
) -> void:
	_error = _setup(arg1, arg2, arg3, arg4, arg5)
	if _error.is_empty():
		_open = true
		_valid = true
	else:
		_open = false
		_valid = false


func is_valid() -> bool:
	return _error.is_empty() and not _claimed and _valid


func is_open() -> bool:
	return _open and not _claimed and _error.is_empty() and _valid


func is_claimed() -> bool:
	return _claimed


func get_node_id() -> String:
	return _node_id


func get_event_id() -> String:
	return _event_id


func get_scraps() -> int:
	return _scraps


func get_satchel() -> Array:
	return _satchel.duplicate(true)


func get_version() -> int:
	return _version


func get_error() -> String:
	return _error


func read_state() -> Dictionary:
	if not _error.is_empty():
		return {"ok": false, "error": _error}
	return {
		"ok": true,
		"node_id": _node_id,
		"event_id": _event_id,
		"open": is_open(),
		"claimed": _claimed,
		"version": _version,
		"scraps": _scraps,
		"satchel": _satchel.duplicate(true),
		"satchel_count": _satchel.size(),
	}


func quote(selected_spare_index: Variant = null) -> Dictionary:
	return preview(selected_spare_index)


func preview_choices(selected_spare_index: Variant = null) -> Dictionary:
	return preview(selected_spare_index)


func preview(selected_spare_index: Variant = null) -> Dictionary:
	if not is_valid():
		return {
			"ok": false,
			"error": _error if not _error.is_empty() else "service is closed",
			"choices": [],
			"state": read_state(),
		}

	var sac_effect: Dictionary = _choices_by_id[CHOICE_SACRIFICE]["stitched_effect"]
	var fum_effect: Dictionary = _choices_by_id[CHOICE_FUMIGATE]["stitched_effect"]
	var esc_effect: Dictionary = _choices_by_id[CHOICE_ESCAPE]["stitched_effect"]

	var sac_scraps_delta: int = int(sac_effect["scraps"])
	var fum_scraps_delta: int = int(fum_effect["scraps"])
	var fum_cost: int = -fum_scraps_delta
	var esc_scraps_delta: int = int(esc_effect.get("scraps", 0))

	var sacrifice_available := false
	var sacrifice_blocked := ""
	var selected_part: Dictionary = {}
	var sel_idx := -1

	if _satchel.is_empty():
		sacrifice_blocked = "satchel is empty"
	elif selected_spare_index == null:
		sacrifice_blocked = "no spare part selected"
	elif typeof(selected_spare_index) != TYPE_INT:
		sacrifice_blocked = "selected spare part index must be an integer"
	else:
		sel_idx = int(selected_spare_index)
		if sel_idx < 0 or sel_idx >= _satchel.size():
			sacrifice_blocked = "selected spare part index out of bounds"
		else:
			sacrifice_available = true
			selected_part = _satchel[sel_idx].duplicate(true)

	var sacrifice_entry := {
		"id": CHOICE_SACRIFICE,
		"choice_id": CHOICE_SACRIFICE,
		"text": str(_choices_by_id[CHOICE_SACRIFICE]["text"]),
		"scraps_delta": sac_scraps_delta,
		"projected_scraps": _scraps + sac_scraps_delta,
		"scraps": _scraps + sac_scraps_delta,
		"available": sacrifice_available,
		"affordable": true,
		"actionable": sacrifice_available,
		"selected_index": sel_idx,
		"blocked": sacrifice_blocked,
		"stitched_effect": sac_effect.duplicate(true),
	}
	if sacrifice_available:
		sacrifice_entry["selected_part"] = selected_part
		sacrifice_entry["projected_satchel_count"] = _satchel.size() - 1

	var fumigate_affordable := (_scraps >= fum_cost)
	var fumigate_entry := {
		"id": CHOICE_FUMIGATE,
		"choice_id": CHOICE_FUMIGATE,
		"text": str(_choices_by_id[CHOICE_FUMIGATE]["text"]),
		"scraps_delta": fum_scraps_delta,
		"projected_scraps": _scraps + fum_scraps_delta if fumigate_affordable else _scraps,
		"scraps": _scraps + fum_scraps_delta if fumigate_affordable else _scraps,
		"available": fumigate_affordable,
		"affordable": fumigate_affordable,
		"actionable": fumigate_affordable,
		"blocked": "" if fumigate_affordable else "insufficient scraps",
		"stitched_effect": fum_effect.duplicate(true),
	}

	var escape_entry := {
		"id": CHOICE_ESCAPE,
		"choice_id": CHOICE_ESCAPE,
		"text": str(_choices_by_id[CHOICE_ESCAPE]["text"]),
		"scraps_delta": esc_scraps_delta,
		"projected_scraps": _scraps + esc_scraps_delta,
		"scraps": _scraps + esc_scraps_delta,
		"available": true,
		"affordable": true,
		"actionable": true,
		"blocked": "",
		"stitched_effect": esc_effect.duplicate(true),
	}

	return {
		"ok": true,
		"node_id": _node_id,
		"event_id": _event_id,
		"title": _title,
		"description": _description,
		"open": is_open(),
		"claimed": _claimed,
		"scraps": _scraps,
		"satchel": _satchel.duplicate(true),
		"satchel_count": _satchel.size(),
		"choices": [sacrifice_entry, fumigate_entry, escape_entry],
		"state": read_state(),
	}


func sacrifice_part(
	selected_index: Variant = null,
	expected_node_id: Variant = null,
	expected_state: Variant = null
) -> Dictionary:
	return choose(CHOICE_SACRIFICE, selected_index, expected_node_id, expected_state)


func fumigate(
	expected_node_id: Variant = null,
	expected_state: Variant = null
) -> Dictionary:
	return choose(CHOICE_FUMIGATE, expected_node_id, expected_state)


func escape(
	expected_node_id: Variant = null,
	expected_state: Variant = null
) -> Dictionary:
	return choose(CHOICE_ESCAPE, expected_node_id, expected_state)


func leave(
	expected_node_id: Variant = null,
	expected_state: Variant = null
) -> Dictionary:
	return choose(CHOICE_ESCAPE, expected_node_id, expected_state)


func claim(
	choice_id: Variant,
	arg2: Variant = null,
	arg3: Variant = null,
	arg4: Variant = null,
	arg5: Variant = null
) -> Dictionary:
	return choose(choice_id, arg2, arg3, arg4, arg5)


func claim_choice(
	choice_id: Variant,
	arg2: Variant = null,
	arg3: Variant = null,
	arg4: Variant = null,
	arg5: Variant = null
) -> Dictionary:
	return choose(choice_id, arg2, arg3, arg4, arg5)


func choose(
	choice_id: Variant,
	arg2: Variant = null,
	arg3: Variant = null,
	arg4: Variant = null,
	arg5: Variant = null
) -> Dictionary:
	if not _error.is_empty():
		return _fail(_error)
	if not _open or _claimed or not _valid:
		return _fail("service already claimed or closed")

	var active_choice: Variant = choice_id
	var rem2: Variant = arg2
	var rem3: Variant = arg3
	var rem4: Variant = arg4
	var rem5: Variant = arg5

	# Support calling with (event_id, choice_id, ...)
	if typeof(active_choice) == TYPE_STRING and (str(active_choice) == EVENT_ID or str(active_choice) == "moth_infestation"):
		active_choice = rem2
		rem2 = rem3
		rem3 = rem4
		rem4 = rem5
		rem5 = null

	var selected_index: Variant = null
	var expected_node_id: Variant = null
	var expected_state: Variant = null

	# Disambiguate arguments across sacrifice_part and no-index choices (fumigate/escape)
	if rem2 == null:
		if typeof(rem3) == TYPE_STRING:
			expected_node_id = rem3
			expected_state = rem4
		elif rem3 is Dictionary:
			expected_state = rem3
			expected_node_id = rem4
		else:
			expected_node_id = rem3
			expected_state = rem4
	elif typeof(rem2) == TYPE_INT:
		selected_index = rem2
		expected_node_id = rem3
		expected_state = rem4
	elif typeof(rem2) == TYPE_STRING:
		expected_node_id = rem2
		if rem3 is Dictionary:
			expected_state = rem3
			selected_index = rem4
		elif typeof(rem3) == TYPE_INT:
			selected_index = rem3
			expected_state = rem4
		else:
			expected_state = rem3
			selected_index = rem4
	elif rem2 is Dictionary:
		expected_state = rem2
		if typeof(rem3) == TYPE_STRING:
			expected_node_id = rem3
			selected_index = rem4
		elif typeof(rem3) == TYPE_INT:
			selected_index = rem3
			expected_node_id = rem4
		else:
			expected_node_id = rem3
			selected_index = rem4
	else:
		selected_index = rem2
		expected_node_id = rem3
		expected_state = rem4

	# Mandatory guarded node check: must be matching trimmed non-blank string
	if expected_node_id == null:
		return _fail("missing expected node id")
	if typeof(expected_node_id) != TYPE_STRING:
		return _fail("expected node id must be a string")
	var exp_node_str: String = expected_node_id
	if exp_node_str.strip_edges().is_empty() or exp_node_str != exp_node_str.strip_edges() or exp_node_str != _node_id:
		return _fail("wrong node")

	# Mandatory guarded state check: must exactly match current detached read_state()
	if expected_state == null:
		return _fail("missing expected state")
	if not (expected_state is Dictionary):
		return _fail("expected state must be a dictionary")
	if not _same_value(expected_state, read_state()):
		return _fail("stale or forged expected state")

	if typeof(active_choice) != TYPE_STRING:
		return _fail("choice id must be a string")

	var target_choice := str(active_choice)
	if not target_choice in [CHOICE_SACRIFICE, CHOICE_FUMIGATE, CHOICE_ESCAPE, CHOICE_LEAVE]:
		return _fail("unknown choice: " + target_choice)

	if target_choice == CHOICE_LEAVE:
		target_choice = CHOICE_ESCAPE

	var sac_effect: Dictionary = _choices_by_id[CHOICE_SACRIFICE]["stitched_effect"]
	var fum_effect: Dictionary = _choices_by_id[CHOICE_FUMIGATE]["stitched_effect"]
	var esc_effect: Dictionary = _choices_by_id[CHOICE_ESCAPE]["stitched_effect"]

	var sac_scraps_delta: int = int(sac_effect["scraps"])
	var fum_scraps_delta: int = int(fum_effect["scraps"])
	var fum_cost: int = -fum_scraps_delta
	var esc_scraps_delta: int = int(esc_effect.get("scraps", 0))

	if target_choice == CHOICE_SACRIFICE:
		if _satchel.is_empty():
			return _fail("satchel is empty")
		if selected_index == null or typeof(selected_index) != TYPE_INT:
			return _fail("missing or invalid spare part index")
		var idx := int(selected_index)
		if idx < 0 or idx >= _satchel.size():
			return _fail("spare part index %d out of bounds (0..%d)" % [idx, _satchel.size() - 1])

		var removed_desc: Dictionary = _satchel[idx].duplicate(true)
		var part_id := str(removed_desc.get("id", ""))
		if not _catalog.has(part_id):
			return _fail("forged or uncatalogued spare part '%s'" % part_id)

		var before_state := read_state()
		var scraps_before := _scraps
		var satchel_before := _satchel.duplicate(true)

		_satchel.remove_at(idx)
		_scraps += sac_scraps_delta
		_claimed = true
		_open = false
		_version += 1
		var after_state := read_state()

		return {
			"ok": true,
			"error": "",
			"event_id": _event_id,
			"choice_id": CHOICE_SACRIFICE,
			"decision": CHOICE_SACRIFICE,
			"node_id": _node_id,
			"removed_descriptor": removed_desc.duplicate(true),
			"part": removed_desc.duplicate(true),
			"removed_index": idx,
			"satchel_index": idx,
			"scraps_before": scraps_before,
			"scraps": _scraps,
			"scraps_after": _scraps,
			"scraps_delta": sac_scraps_delta,
			"satchel_before": satchel_before,
			"satchel": _satchel.duplicate(true),
			"satchel_after": _satchel.duplicate(true),
			"source_state": before_state,
			"state": after_state,
			"open": false,
			"claimed": true,
		}

	elif target_choice == CHOICE_FUMIGATE:
		if _scraps < fum_cost:
			return _fail("insufficient scraps for fumigate (requires %d, have %d)" % [fum_cost, _scraps])

		var before_state := read_state()
		var scraps_before := _scraps
		var satchel_before := _satchel.duplicate(true)

		_scraps += fum_scraps_delta
		_claimed = true
		_open = false
		_version += 1
		var after_state := read_state()

		return {
			"ok": true,
			"error": "",
			"event_id": _event_id,
			"choice_id": CHOICE_FUMIGATE,
			"decision": CHOICE_FUMIGATE,
			"node_id": _node_id,
			"removed_descriptor": {},
			"removed_index": -1,
			"satchel_index": -1,
			"scraps_before": scraps_before,
			"scraps": _scraps,
			"scraps_after": _scraps,
			"scraps_delta": fum_scraps_delta,
			"satchel_before": satchel_before,
			"satchel": _satchel.duplicate(true),
			"satchel_after": _satchel.duplicate(true),
			"source_state": before_state,
			"state": after_state,
			"open": false,
			"claimed": true,
		}

	else: # CHOICE_ESCAPE
		var before_state := read_state()
		var scraps_before := _scraps
		var satchel_before := _satchel.duplicate(true)

		_scraps += esc_scraps_delta
		_claimed = true
		_open = false
		_version += 1
		var after_state := read_state()

		return {
			"ok": true,
			"error": "",
			"event_id": _event_id,
			"choice_id": CHOICE_ESCAPE,
			"decision": CHOICE_ESCAPE,
			"node_id": _node_id,
			"removed_descriptor": {},
			"removed_index": -1,
			"satchel_index": -1,
			"scraps_before": scraps_before,
			"scraps": _scraps,
			"scraps_after": _scraps,
			"scraps_delta": esc_scraps_delta,
			"satchel_before": satchel_before,
			"satchel": _satchel.duplicate(true),
			"satchel_after": _satchel.duplicate(true),
			"source_state": before_state,
			"state": after_state,
			"open": false,
			"claimed": true,
		}


func _fail(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
		"choice_id": "",
		"decision": "",
		"removed_descriptor": {},
		"removed_index": -1,
		"satchel_index": -1,
		"scraps": _scraps,
		"scraps_delta": 0,
		"satchel": _satchel.duplicate(true),
		"state": read_state(),
	}


func _setup(
	arg1: Variant,
	arg2: Variant,
	arg3: Variant,
	arg4: Variant,
	arg5: Variant
) -> String:
	var node_id: Variant = arg1
	var satchel: Variant = null
	var scraps: Variant = null
	var catalog_data: Variant = null
	var event_data: Variant = null

	if typeof(arg2) == TYPE_ARRAY:
		# Standard positional: (node_id, satchel, scraps, catalog_data, event_data)
		satchel = arg2
		scraps = arg3
		catalog_data = arg4
		event_data = arg5
	elif typeof(arg1) == TYPE_DICTIONARY and ((arg1 as Dictionary).has("id") and str((arg1 as Dictionary)["id"]) == EVENT_ID or (arg1 as Dictionary).has("events")):
		# (event_data, node_id, satchel, scraps, catalog_data)
		event_data = arg1
		node_id = arg2
		satchel = arg3
		scraps = arg4
		catalog_data = arg5
	elif (typeof(arg2) == TYPE_DICTIONARY and ((arg2 as Dictionary).has("id") and str((arg2 as Dictionary)["id"]) == EVENT_ID or (arg2 as Dictionary).has("events"))) \
			or (typeof(arg2) == TYPE_STRING and (str(arg2) == EVENT_ID or str(arg2).ends_with(".json"))):
		# (node_id, event_data, satchel, scraps, catalog_data)
		event_data = arg2
		satchel = arg3
		scraps = arg4
		catalog_data = arg5
	else:
		# Fallback positional
		satchel = arg2
		scraps = arg3
		catalog_data = arg4
		event_data = arg5

	# 1. Node ID validation
	if typeof(node_id) != TYPE_STRING:
		return "node id must be a string"
	var node_str: String = node_id
	if node_str.strip_edges().is_empty() or node_str != node_str.strip_edges():
		return "node id must be a nonempty trimmed string"
	_node_id = node_str

	# 2. Scraps validation
	if scraps == null:
		return "scraps value is required"
	if typeof(scraps) == TYPE_DICTIONARY:
		var wallet: Dictionary = scraps
		if not wallet.has("scraps") or typeof(wallet["scraps"]) != TYPE_INT or wallet["scraps"] < 0:
			return "wallet dictionary must contain a nonnegative integer 'scraps'"
		_scraps = int(wallet["scraps"])
	elif typeof(scraps) == TYPE_INT:
		if scraps < 0:
			return "scraps must be a nonnegative integer"
		_scraps = int(scraps)
	elif typeof(scraps) == TYPE_FLOAT:
		var f := float(scraps)
		if not is_finite(f) or floorf(f) != f or f < 0:
			return "scraps must be a nonnegative integral number"
		_scraps = int(f)
	else:
		return "scraps must be a nonnegative integer"

	# 3. Catalog resolution
	var resolved_cat := _resolve_catalog(catalog_data)
	if not bool(resolved_cat.get("ok", false)):
		return str(resolved_cat.get("error", "malformed catalog"))
	_catalog = resolved_cat.get("by_id", {})

	# 4. Event record resolution
	var resolved_ev := _resolve_event(event_data)
	if not bool(resolved_ev.get("ok", false)):
		return str(resolved_ev.get("error", "malformed event record"))
	_event_record = resolved_ev.get("record", {})
	_event_id = str(_event_record.get("id", EVENT_ID))
	_title = str(_event_record.get("title", ""))
	_description = str(_event_record.get("description", ""))
	_choices_by_id = {}
	for ch_raw: Variant in _event_record.get("choices", []):
		if ch_raw is Dictionary:
			var ch: Dictionary = ch_raw
			if ch.has("id"):
				_choices_by_id[str(ch["id"])] = ch.duplicate(true)

	# 5. Satchel validation
	if satchel == null:
		return "satchel is required"
	var satchel_val := _validate_and_copy_satchel(satchel, _catalog)
	if not bool(satchel_val.get("ok", false)):
		return str(satchel_val.get("error", "invalid satchel"))
	_satchel = satchel_val.get("satchel", [])

	return ""


static func _resolve_catalog(catalog_data: Variant) -> Dictionary:
	if catalog_data == null:
		var loaded := StitchedParts.load_catalog(DEFAULT_PARTS_CATALOG_PATH)
		if not bool(loaded.get("ok", false)):
			return {"ok": false, "error": "failed to load default parts catalog: " + str(loaded.get("error", ""))}
		return {"ok": true, "by_id": loaded.get("by_id", {})}

	if catalog_data is String:
		var loaded_str := StitchedParts.load_catalog(str(catalog_data))
		if not bool(loaded_str.get("ok", false)):
			return {"ok": false, "error": str(loaded_str.get("error", "failed to load catalog"))}
		return {"ok": true, "by_id": loaded_str["by_id"]}

	if catalog_data is Array:
		var built_arr := StitchedParts.build_catalog(catalog_data)
		if not bool(built_arr.get("ok", false)):
			return {"ok": false, "error": str(built_arr.get("error", "invalid catalog array"))}
		return {"ok": true, "by_id": built_arr["by_id"]}

	if catalog_data is Dictionary:
		var d: Dictionary = catalog_data
		if d.has("ok") and not bool(d["ok"]):
			return {"ok": false, "error": "supplied catalog reports error: " + str(d.get("error", ""))}

		var raw_dict: Dictionary = {}
		if d.has("by_id"):
			if not (d["by_id"] is Dictionary):
				return {"ok": false, "error": "catalog by_id must be a dictionary"}
			raw_dict = d["by_id"]
		elif d.has("parts") and d["parts"] is Array:
			var built := StitchedParts.build_catalog(d["parts"])
			if not bool(built.get("ok", false)):
				return {"ok": false, "error": str(built.get("error", "invalid catalog parts"))}
			return {"ok": true, "by_id": built["by_id"]}
		else:
			raw_dict = d

		if raw_dict.is_empty():
			return {"ok": false, "error": "parts catalog is empty"}

		var part_array: Array = []
		var seen_ids: Dictionary = {}
		for key in raw_dict.keys():
			if typeof(key) != TYPE_STRING:
				return {"ok": false, "error": "catalog key must be a string"}
			var key_str: String = key
			if key_str.strip_edges().is_empty() or key_str != key_str.strip_edges():
				return {"ok": false, "error": "catalog key must be a trimmed non-empty string"}
			var item: Variant = raw_dict[key]
			if not (item is Dictionary):
				return {"ok": false, "error": "catalog entry for '%s' is not a dictionary" % key_str}
			var part_dict: Dictionary = item
			if not part_dict.has("id") or typeof(part_dict["id"]) != TYPE_STRING:
				return {"ok": false, "error": "catalog entry for '%s' missing valid id" % key_str}
			var item_id: String = str(part_dict["id"])
			if item_id != key_str:
				return {"ok": false, "error": "catalog key '%s' does not match part id '%s'" % [key_str, item_id]}
			if seen_ids.has(item_id):
				return {"ok": false, "error": "duplicate part id: " + item_id}
			seen_ids[item_id] = true
			part_array.append(part_dict)

		var built := StitchedParts.build_catalog(part_array)
		if not bool(built.get("ok", false)):
			return {"ok": false, "error": str(built.get("error", "invalid catalog parts"))}
		return {"ok": true, "by_id": built["by_id"]}

	return {"ok": false, "error": "invalid catalog data type"}


static func _resolve_event(event_data: Variant) -> Dictionary:
	var record: Dictionary = {}
	if event_data == null:
		if not FileAccess.file_exists(EVENT_CATALOG_PATH):
			return {"ok": false, "error": "missing event catalog file: " + EVENT_CATALOG_PATH}
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EVENT_CATALOG_PATH))
		if not (parsed is Dictionary) or not (parsed.get("events") is Array):
			return {"ok": false, "error": "failed to load route effects catalog"}
		for ev: Variant in parsed["events"]:
			if ev is Dictionary and str(ev.get("id")) == EVENT_ID:
				record = (ev as Dictionary).duplicate(true)
				break
	elif event_data is Dictionary:
		var d: Dictionary = event_data
		if d.has("events") and d["events"] is Array:
			for ev: Variant in d["events"]:
				if ev is Dictionary and str(ev.get("id")) == EVENT_ID:
					record = (ev as Dictionary).duplicate(true)
					break
		elif str(d.get("id", "")) == EVENT_ID:
			record = d.duplicate(true)
		else:
			return {"ok": false, "error": "event record id '%s' is not '%s'" % [str(d.get("id", "")), EVENT_ID]}
	elif event_data is String:
		var s: String = str(event_data)
		if s == EVENT_ID:
			return _resolve_event(null)
		if FileAccess.file_exists(s):
			var parsed_str: Variant = JSON.parse_string(FileAccess.get_file_as_string(s))
			if parsed_str is Dictionary:
				return _resolve_event(parsed_str)
		return {"ok": false, "error": "event file not found: " + s}
	else:
		return {"ok": false, "error": "invalid event data type"}

	if record.is_empty():
		return {"ok": false, "error": "event '%s' not found" % EVENT_ID}

	# RunEventChoice envelope validation (title, description, choices with id and text)
	var envelope := RunEventChoice.new(record)
	if not envelope.is_valid():
		return {"ok": false, "error": "record fails RunEventChoice envelope validation"}

	if str(record.get("id", "")) != EVENT_ID:
		return {"ok": false, "error": "event id must be '%s'" % EVENT_ID}

	# Moth action validation: actions.sacrifice_part must be "unpick"
	if not record.has("actions") or not (record["actions"] is Dictionary):
		return {"ok": false, "error": "event actions must be a dictionary"}
	var actions: Dictionary = record["actions"]
	if str(actions.get("sacrifice_part", "")) != "unpick":
		return {"ok": false, "error": "event actions.sacrifice_part must be 'unpick'"}

	# Choices validation
	var choices_raw: Variant = record.get("choices")
	if not (choices_raw is Array):
		return {"ok": false, "error": "event choices must be an Array"}
	var choices_arr: Array = choices_raw
	if choices_arr.size() != 3:
		return {"ok": false, "error": "event must contain exactly 3 choices"}

	var choices_by_id: Dictionary = {}
	for ch_raw: Variant in choices_arr:
		if not (ch_raw is Dictionary):
			return {"ok": false, "error": "choice must be a dictionary"}
		var ch: Dictionary = ch_raw
		var cid := str(ch.get("id", ""))
		choices_by_id[cid] = ch

	if not choices_by_id.has(CHOICE_SACRIFICE):
		return {"ok": false, "error": "missing '%s' choice in event" % CHOICE_SACRIFICE}
	if not choices_by_id.has(CHOICE_FUMIGATE):
		return {"ok": false, "error": "missing '%s' choice in event" % CHOICE_FUMIGATE}
	if not choices_by_id.has(CHOICE_ESCAPE):
		return {"ok": false, "error": "missing '%s' choice in event" % CHOICE_ESCAPE}

	# Validate stitched_effect for each choice
	for cid in [CHOICE_SACRIFICE, CHOICE_FUMIGATE, CHOICE_ESCAPE]:
		var ch: Dictionary = choices_by_id[cid]
		if not ch.has("stitched_effect") or not (ch["stitched_effect"] is Dictionary):
			return {"ok": false, "error": "choice '%s' missing stitched_effect dictionary" % cid}
		var eff: Dictionary = ch["stitched_effect"]
		if str(eff.get("target", "")) != "party":
			return {"ok": false, "error": "choice '%s' stitched_effect target must be 'party'" % cid}
		if not eff.has("candle") or not _integral_equal(eff.get("candle"), 0):
			return {"ok": false, "error": "choice '%s' stitched_effect candle must be 0" % cid}
		if not eff.has("fray") or not _integral_equal(eff.get("fray"), 0):
			return {"ok": false, "error": "choice '%s' stitched_effect fray must be 0" % cid}
		if eff.has("gold") and not _integral_equal(eff.get("gold"), 0):
			return {"ok": false, "error": "choice '%s' contains contradictory gold delta" % cid}
		if eff.has("hp") and not _integral_equal(eff.get("hp"), 0):
			return {"ok": false, "error": "choice '%s' contains contradictory hp delta" % cid}

	var sac_eff: Dictionary = choices_by_id[CHOICE_SACRIFICE]["stitched_effect"]
	if not sac_eff.has("scraps") or not _integral_equal(sac_eff.get("scraps"), 2):
		return {"ok": false, "error": "choice '%s' stitched_effect scraps must be 2" % CHOICE_SACRIFICE}

	var fum_eff: Dictionary = choices_by_id[CHOICE_FUMIGATE]["stitched_effect"]
	if not fum_eff.has("scraps") or not _integral_equal(fum_eff.get("scraps"), -1):
		return {"ok": false, "error": "choice '%s' stitched_effect scraps must be -1" % CHOICE_FUMIGATE}

	var esc_eff: Dictionary = choices_by_id[CHOICE_ESCAPE]["stitched_effect"]
	if esc_eff.has("scraps") and not _integral_equal(esc_eff.get("scraps"), 0):
		return {"ok": false, "error": "choice '%s' contains contradictory scraps delta" % CHOICE_ESCAPE}

	return {"ok": true, "record": record}


static func _validate_and_copy_satchel(raw_satchel: Variant, catalog_by_id: Dictionary) -> Dictionary:
	if not (raw_satchel is Array):
		return {"ok": false, "error": "satchel must be an Array"}
	var satchel_array: Array = raw_satchel
	if satchel_array.size() < SATCHEL_MIN or satchel_array.size() > SATCHEL_CAP:
		return {"ok": false, "error": "satchel size must be between %d and %d, got %d" % [SATCHEL_MIN, SATCHEL_CAP, satchel_array.size()]}
	var clean: Array = []
	for i in range(satchel_array.size()):
		var item: Variant = satchel_array[i]
		if not (item is Dictionary):
			return {"ok": false, "error": "satchel entry at index %d is not a Dictionary" % i}
		var d: Dictionary = item
		if not d.has("id") or typeof(d["id"]) != TYPE_STRING or str(d["id"]).is_empty():
			return {"ok": false, "error": "satchel entry at index %d missing valid part id" % i}
		var part_id := str(d["id"])
		if not catalog_by_id.has(part_id):
			return {"ok": false, "error": "satchel entry at index %d has uncatalogued part id '%s'" % [i, part_id]}
		if not d.has("tier") or typeof(d["tier"]) != TYPE_INT:
			return {"ok": false, "error": "satchel entry at index %d missing valid integer tier" % i}
		var tier := int(d["tier"])
		if tier < StitchedParts.MIN_TIER or tier > StitchedParts.MAX_TIER:
			return {"ok": false, "error": "satchel entry at index %d has tier %d out of bounds (1..3)" % [i, tier]}
		clean.append(d.duplicate(true))
	return {"ok": true, "satchel": clean}


static func _same_value(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		var dict_a: Dictionary = a
		var dict_b: Dictionary = b
		if dict_a.size() != dict_b.size():
			return false
		for key: Variant in dict_a.keys():
			if not dict_b.has(key) or not _same_value(dict_a[key], dict_b[key]):
				return false
		return true
	if a is Array:
		var arr_a: Array = a
		var arr_b: Array = b
		if arr_a.size() != arr_b.size():
			return false
		for index in range(arr_a.size()):
			if not _same_value(arr_a[index], arr_b[index]):
				return false
		return true
	return a == b


static func _integral_equal(val: Variant, expected: int) -> bool:
	if typeof(val) == TYPE_INT:
		return int(val) == expected
	if typeof(val) == TYPE_FLOAT:
		var f := float(val)
		return is_finite(f) and floorf(f) == f and int(f) == expected
	return false
