class_name RunStitchedInkblackUnpickerEvent
extends RefCounted
## One-use Stitched Event admission. The inner Unpicker action settles separately.

const EVENT_ID := "v3_inkblack_unpicker_van"
const SERVICE_CHOICE_ID := "hire_unpicker"
const SERVICE_KIND := "Unpicker"

var _node_id := ""
var _heroes: Array = []
var _satchel: Array = []
var _wallet: Dictionary = {}
var _quoted_calm_price := 0
var _quoted_scrap_yield := 0
var _gate: RunV3ServiceWaystationEventGate
var _error := ""
var _claimed := false
var _version := 0
var _visit_id := ""


func _init(event_target: Variant = null, node_id: Variant = null,
		heroes: Variant = null, satchel: Variant = null, wallet: Variant = null,
		quoted_calm_price: Variant = null, quoted_scrap_yield: Variant = null,
		catalog_data: Variant = null) -> void:
	_error = _setup(event_target, node_id, heroes, satchel, wallet,
		quoted_calm_price, quoted_scrap_yield, catalog_data)
	if _error.is_empty():
		_visit_id = str(get_instance_id())


func _setup(event_target: Variant, node_id: Variant, heroes: Variant,
		satchel: Variant, wallet: Variant, calm_price: Variant, scrap_yield: Variant,
		catalog_data: Variant) -> String:
	var parsed := RunV3ServiceWaystationEventGate._parse_wallet(wallet)
	if not parsed.get("ok", false):
		return "invalid wallet"
	# The real Stitched service validates the complete detached prospective input,
	# including four distinct ranks, FRAY, spare shapes, capacity and yield overflow.
	var visit := RunUnpickerVisit.open_stitched(node_id, heroes, parsed.wallet.gold,
		calm_price, satchel, parsed.wallet.scraps, scrap_yield)
	if not visit.is_valid():
		return "invalid Stitched Unpicker inputs"
	# A supplied rank alias must agree with the position used by the service.
	for hero: Dictionary in heroes:
		if hero.has("rank") and (typeof(hero.rank) != TYPE_INT or hero.rank != hero.position):
			return "inconsistent hero rank"
	_gate = RunV3ServiceWaystationEventGate.new(event_target, catalog_data)
	if not _gate.is_valid() or _gate.get_event_id() != EVENT_ID \
			or _gate.get_service_choice_id() != SERVICE_CHOICE_ID \
			or _gate.get_service_kind() != SERVICE_KIND:
		return "invalid Inkblack event"
	_node_id = node_id
	_heroes = heroes.duplicate(true)
	_satchel = satchel.duplicate(true)
	_wallet = parsed.wallet.duplicate(true)
	_quoted_calm_price = calm_price
	_quoted_scrap_yield = scrap_yield
	return ""


func is_valid() -> bool:
	return _error.is_empty() and not _claimed and _gate != null and _gate.is_valid()


func is_open() -> bool:
	return is_valid()


func is_claimed() -> bool:
	return _claimed


func read_state() -> Dictionary:
	if not _error.is_empty():
		return {"ok": false, "error": _error}
	return {
		"ok": true, "visit_id": _visit_id, "node_id": _node_id,
		"event_id": EVENT_ID, "service_choice_id": SERVICE_CHOICE_ID,
		"service_kind": SERVICE_KIND, "open": not _claimed, "claimed": _claimed,
		"version": _version, "heroes": _heroes.duplicate(true),
		"satchel": _satchel.duplicate(true), "wallet": _wallet.duplicate(true),
		"quoted_calm_price": _quoted_calm_price, "quoted_scrap_yield": _quoted_scrap_yield,
	}


func preview_choices() -> Dictionary:
	if not is_valid():
		return {"ok": false, "choices": [], "state": read_state()}
	var preview := _gate.preview_choices(_wallet)
	if not preview.get("ok", false):
		return {"ok": false, "choices": [], "state": read_state()}
	for item: Dictionary in preview.choices:
		var available: bool = item.affordable
		item["service_request"] = {}
		if item.choice_id == SERVICE_CHOICE_ID:
			available = available and _has_usable_action(item.wallet)
			if available:
				item["service_request"] = {"stop_type": SERVICE_KIND}
		item["available"] = available
		item["actionable"] = available
	preview["state"] = read_state()
	return preview


func quote() -> Dictionary:
	return preview_choices()


func _has_usable_action(post_toll_wallet: Dictionary) -> bool:
	var prospective := RunUnpickerVisit.open_stitched(_node_id, _heroes.duplicate(true),
		post_toll_wallet.gold, _quoted_calm_price, _satchel.duplicate(true),
		post_toll_wallet.scraps, _quoted_scrap_yield)
	var offered := prospective.quote()
	if not offered.get("ok", false):
		return false
	for action: String in offered.choices:
		if action != "leave":
			return true
	return false


func choose(choice_id: Variant, expected_node_id: Variant = null,
		expected_state: Variant = null) -> Dictionary:
	if not is_valid():
		return _fail("visit is invalid or closed")
	if typeof(expected_node_id) != TYPE_STRING or expected_node_id != _node_id:
		return _fail("wrong node")
	if not RunV3ServiceWaystationEventGate._same_value(expected_state, read_state()):
		return _fail("stale or forged state")
	if typeof(choice_id) != TYPE_STRING:
		return _fail("invalid choice id")
	var offered := preview_choices()
	var selected: Dictionary = {}
	for item: Dictionary in offered.get("choices", []):
		if item.choice_id == choice_id:
			selected = item
	if selected.is_empty() or not selected.available:
		return _fail("choice is unavailable or actionless")
	var before := read_state()
	var settlement := _gate.choose_with_wallet(choice_id, _wallet)
	if not settlement.get("ok", false):
		return _fail("settlement refused")
	_wallet = settlement.wallet.duplicate(true)
	_claimed = true
	_version += 1
	return {
		"ok": true, "event_id": EVENT_ID, "choice_id": choice_id,
		"wallet": _wallet.duplicate(true),
		"service_request": selected.service_request.duplicate(true),
		"source_state": before, "state": read_state(),
	}


func leave(expected_node_id: Variant = null, expected_state: Variant = null) -> Dictionary:
	return choose("leave", expected_node_id, expected_state)


func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "event_id": "", "choice_id": "",
		"wallet": _wallet.duplicate(true), "service_request": {}, "state": read_state()}
