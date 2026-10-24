class_name RunM04EventRotation
extends RefCounted
## Scene-free, read-only selector for the authored generic M04 wallet Events in
## res://data/events/m04_events.json: button_trail, loose_seam, thimble_well,
## frayed_signpost, needle_gate, quilting_bee and estate_sale.
##
## The future run owner supplies its own seeded RandomNumberGenerator, its own
## wallet and its own visit history. This helper only validates the shipped
## catalog at construction and returns a detached event record; it never
## creates or reseeds an RNG, commits a wallet, advances a map or records a
## visit. A rejected call consumes no RNG state, and a successful call consumes
## exactly one randi_range() draw after sorting the eligible IDs, so JSON order
## is never a hidden random input.
##
## quiet_spool is a separately routed special and never enters the generic
## rotation. Unrecognized future catalog additions are preserved: a well-formed
## unique extra record simply joins the eligible pool, while the event count is
## never treated as fixed.

const EVENTS_PATH := "res://data/events/m04_events.json"

const REQUIRED_EVENT_IDS := [
	"button_trail",
	"loose_seam",
	"thimble_well",
	"frayed_signpost",
	"needle_gate",
	"quilting_bee",
	"estate_sale",
]

## Separately routed specials that live in the same JSON but must never become
## part of the generic rotation. Moth Infestation and Dye Vat are routed from
## their own records elsewhere and are not present here.
const SPECIAL_EVENT_IDS := ["quiet_spool"]

var _catalog_ok: bool = false
## Sorted by ID, detached from the parsed document.
var _pool: Array = []


## Builds and validates the rotation. Pass an injected {"events": [...]}
## document (for tests or another catalog source); omit it to read the shipped
## M04 JSON. An absent, unparsable or malformed-required catalog leaves the
## rotation invalid, so every selection fails closed.
func _init(catalog_source: Variant = null) -> void:
	var document: Variant = catalog_source
	if document == null:
		document = _load_shipped_catalog()
	_catalog_ok = _build_pool(document)


## True only when the sourced catalog satisfied every required named record.
func is_catalog_valid() -> bool:
	return _catalog_ok


## Read-only listing of the generic rotation, sorted by event ID and detached
## from both this instance and the caller. Mutating the result is harmless.
func get_generic_events() -> Array:
	return _pool.duplicate(true)


## Read-only listing of the generic rotation's event IDs, sorted.
func get_generic_event_ids() -> Array:
	var ids: Array = []
	for record in _pool:
		ids.append(record["id"])
	return ids


## Picks one generic event uniformly from the eligible pool.
## `rng` is deliberately typed Variant so a wrong or missing caller value
## rejects here instead of failing a typed-argument error at the call site; a
## valid value must be the caller's RandomNumberGenerator (the run's seeded
## instance). `excluded_ids` is an optional Array of previously visited generic
## IDs to skip and never grows inside this helper.
## Returns exactly {"ok": bool, "event": Dictionary}; a rejection carries an
## empty event, changes no state and consumes no RNG draw. Eligibility is sorted
## by ID, so a successful call consumes precisely one randi_range(0, n - 1).
func select_event(rng: Variant, excluded_ids: Variant = null) -> Dictionary:
	if not rng is RandomNumberGenerator:
		return _rejection()
	if not _catalog_ok:
		return _rejection()
	var parsed: Dictionary = _parse_exclusions(excluded_ids)
	if not parsed.get("ok", false):
		return _rejection()
	var excluded: Dictionary = parsed["ids"]
	var eligible: Array = []
	for record in _pool:
		var event_id: String = record["id"]
		if not excluded.has(event_id):
			eligible.append(event_id)
	if eligible.is_empty():
		return _rejection()
	eligible.sort()
	var generator: RandomNumberGenerator = rng
	var picked_id: String = eligible[generator.randi_range(0, eligible.size() - 1)]
	for record in _pool:
		if record["id"] == picked_id:
			return {"ok": true, "event": record.duplicate(true)}
	return _rejection()


func _rejection() -> Dictionary:
	return {"ok": false, "event": {}}


## Null means "no exclusions". Anything other than an Array, or an array with a
## non-String or blank entry, is malformed and rejects the whole call before any
## draw. Unknown but well-formed IDs are ignored: an ID that left the catalog
## can never enter the pool.
func _parse_exclusions(excluded_ids: Variant) -> Dictionary:
	var ids: Dictionary = {}
	if excluded_ids == null:
		return {"ok": true, "ids": ids}
	if not excluded_ids is Array:
		return {"ok": false}
	for value in excluded_ids:
		if not value is String:
			return {"ok": false}
		var event_id: String = value
		if event_id.strip_edges().is_empty():
			return {"ok": false}
		ids[event_id] = true
	return {"ok": true, "ids": ids}


## Validates the required records and builds the generic pool.
## Required IDs must appear exactly once, be presentable to the event panel
## (RunEventChoice validity) and have fully parseable wallet outcomes, or the
## whole rotation fails closed. Other records are additive: an unknown but
## well-formed unique record joins the pool, while malformed, duplicated or
## special records are simply excluded.
func _build_pool(document: Variant) -> bool:
	_pool = []
	if not document is Dictionary:
		return false
	var events: Variant = (document as Dictionary).get("events")
	if not events is Array:
		return false
	var by_id: Dictionary = {}
	for record in events:
		if not record is Dictionary:
			continue
		var raw_id: Variant = (record as Dictionary).get("id")
		if not raw_id is String:
			continue
		var event_id: String = raw_id
		if event_id.strip_edges().is_empty():
			continue
		if by_id.has(event_id):
			# Duplicate IDs are ambiguous; a required duplicate rejects below.
			by_id[event_id] = null
			continue
		by_id[event_id] = record
	var required: Dictionary = {}
	for event_id in REQUIRED_EVENT_IDS:
		required[event_id] = true
		if not by_id.has(event_id) or not by_id[event_id] is Dictionary:
			return false
		if not _is_presentable(by_id[event_id]):
			return false
	var pool: Array = []
	for event_id in by_id.keys():
		var record: Variant = by_id[event_id]
		if not record is Dictionary:
			continue
		if SPECIAL_EVENT_IDS.has(event_id):
			continue
		if not required.has(event_id) and not _is_presentable(record):
			continue
		pool.append((record as Dictionary).duplicate(true))
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["id"]) < String(b["id"]))
	_pool = pool
	return true


## A record is presentable when RunEventChoice accepts its schema and every
## authored choice carries a parseable signed gold/scraps outcome. Both checks
## reuse the existing contracts and leave the record untouched.
func _is_presentable(record: Variant) -> bool:
	if not record is Dictionary:
		return false
	var service := RunEventChoice.new(record)
	if not service.is_valid():
		return false
	var preview: Dictionary = service.preview_wallet_choices({"gold": 0, "scraps": 0})
	if not preview.get("ok", false):
		return false
	var previews: Variant = preview.get("choices")
	if not previews is Array:
		return false
	var choices: Variant = (record as Dictionary).get("choices")
	if not choices is Array or (previews as Array).size() != (choices as Array).size():
		return false
	for entry in previews:
		if not entry is Dictionary:
			return false
		if (entry as Dictionary).get("gold_delta") == null:
			return false
		if (entry as Dictionary).get("scraps_delta") == null:
			return false
	return true


static func _load_shipped_catalog() -> Variant:
	if not FileAccess.file_exists(EVENTS_PATH):
		return null
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return null
	return parser.data
