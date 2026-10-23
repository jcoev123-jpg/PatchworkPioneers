class_name RunWardenPathChoice
extends RefCounted
## Deterministic one-claim pre-run Warden Path projector (D2-5 / M06 data slice).
## Loads and validates data/heroes/warden_paths.json and the genuine authored
## twelve-copy starter deck, lets a caller pick exactly one of the two authored
## Paths once, and returns a detached receipt of that Path's replacement passive,
## its Path card and a proposed starter deck with exactly one appended Path card.
## No scene dependencies, no RNG, no combat/catalog mutation: Path cards are not
## part of the live hand or card catalog until a later M06 hookup.
##
## Authored record schema (data/heroes/warden_paths.json):
## {
##   id: String, display_name: String, max_hp: int, base_passive: Dictionary,
##   palette: Dictionary, paths: Array[ { id, display_name, passive, card } ]
## }

const AUTHORED_PATH := "res://data/heroes/warden_paths.json"
const STARTER_DECK_PATH := "res://data/cards/starter_deck.json"
const OWNER_ID := "warden"
const PATH_IDS: Array[String] = ["bulwark", "vanguard"]
const STARTER_DECK_SIZE := 12
const MIN_POSITION := 1
const MAX_POSITION := 3
const MAX_SAFE_FLOAT_INT := 9007199254740992.0
const MAX_HP := 40
const TARGET_KINDS: Array[String] = ["enemy_single", "enemy_all", "self", "ally_single", "none"]

var _paths: Array[Dictionary] = []
var _deck: Array[String] = []
var _valid: bool = false
var _claimed: bool = false
var _receipt: Dictionary = {}


## Optionally accepts an already-parsed authored record and starter deck.
## Null arguments load the authored files from res://.
func _init(authored: Variant = null, starter_deck: Variant = null) -> void:
	var record: Variant = authored
	if record == null:
		record = load_authored_record()
	var deck_source: Variant = starter_deck
	if deck_source == null:
		deck_source = load_authored_starter_deck()
	_build(record, deck_source)


## Parsed authored Path record, or null when the file is missing/unparseable.
static func load_authored_record() -> Variant:
	return _load_json(AUTHORED_PATH)


## Parsed authored starter deck array, or null when the file is missing/unparseable.
static func load_authored_starter_deck() -> Variant:
	return _load_json(STARTER_DECK_PATH)


static func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges().is_empty():
		return null
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return null
	return parser.data


## True only while the authored source and starter deck validated and the single
## claim is still available.
func is_valid() -> bool:
	return _valid and not _claimed


## True once a Path choice has been committed on this instance.
func is_claimed() -> bool:
	return _claimed


## Detached authored Path records in authored order; never mutated by claiming.
func get_authored_paths() -> Array:
	var out: Array = []
	for path in _paths:
		out.append(path.duplicate(true))
	return out


## Detached copy of the validated base starter deck (order preserved).
func get_base_deck() -> Array[String]:
	var out: Array[String] = []
	for card_id in _deck:
		out.append(card_id)
	return out


## Detached copy of the last successful receipt, or an empty dictionary before
## any successful choice. Mutating it never reaches this instance.
func get_receipt() -> Dictionary:
	return _receipt.duplicate(true)


## Attempts the single allowed Path claim.
## Returns {ok, owner, path_id, display_name, passive, card, starter_deck}.
## Rejections (invalid construction, unoffered/blank/non-string path, replay)
## return ok=false with empty identity fields and a detached unchanged base deck,
## consuming no claim and mutating no state.
func choose(path_id: Variant) -> Dictionary:
	if not _valid or _claimed:
		return _rejection()
	if not path_id is String:
		return _rejection()
	var target: String = path_id
	var chosen: Dictionary = {}
	for path in _paths:
		if path.get("id") == target:
			chosen = path
			break
	if chosen.is_empty():
		return _rejection()
	var card: Dictionary = chosen["card"]
	var proposed: Array[String] = []
	for card_id in _deck:
		proposed.append(card_id)
	proposed.append(card["id"])
	_claimed = true
	_receipt = {
		"ok": true,
		"owner": OWNER_ID,
		"path_id": target,
		"display_name": chosen["display_name"],
		"passive": (chosen["passive"] as Dictionary).duplicate(true),
		"card": card.duplicate(true),
		"starter_deck": proposed,
	}
	return _receipt.duplicate(true)


## Authenticates an untrusted detached choice against an independent, freshly
## loaded authored selection. This never consumes any caller's choice instance
## or trusts a claimed card ID without comparing the entire typed receipt.
## Success exposes only detached canonical battle-admission fields.
static func authenticate_receipt(candidate: Variant) -> Dictionary:
	if typeof(candidate) != TYPE_DICTIONARY:
		return {"ok": false}
	var receipt: Dictionary = candidate
	if typeof(receipt.get("path_id")) != TYPE_STRING:
		return {"ok": false}
	var path_id: String = receipt["path_id"]
	if not PATH_IDS.has(path_id):
		return {"ok": false}
	var fresh := RunWardenPathChoice.new()
	if not fresh.is_valid():
		return {"ok": false}
	var canonical := fresh.choose(path_id)
	if not canonical.get("ok", false) or not fresh._exactly_equal(receipt, canonical):
		return {"ok": false}
	return {
		"ok": true,
		"path_id": path_id,
		"card_id": canonical["card"]["id"],
		"receipt": canonical.duplicate(true),
	}


func _rejection() -> Dictionary:
	return {
		"ok": false,
		"owner": "",
		"path_id": "",
		"display_name": "",
		"passive": {},
		"card": {},
		"starter_deck": get_base_deck(),
	}


func _build(record: Variant, deck_source: Variant) -> void:
	_paths = []
	_deck = []
	_valid = false
	if not record is Dictionary:
		return
	var owner_record: Dictionary = _normalize(record)
	if owner_record.get("id") != OWNER_ID:
		return
	if not _is_nonblank_string(owner_record.get("display_name")):
		return
	if not _exactly_equal(owner_record.get("max_hp"), MAX_HP):
		return
	var base_passive: Variant = owner_record.get("base_passive")
	if not base_passive is Dictionary:
		return
	if not _exactly_equal(base_passive, _expected_base_passive()):
		return
	var deck := _validate_deck(deck_source)
	if deck.is_empty():
		return
	var raw_paths: Variant = owner_record.get("paths")
	if not raw_paths is Array:
		return
	var list: Array = raw_paths
	if list.size() != PATH_IDS.size():
		return
	var seen_paths: Dictionary = {}
	var seen_cards: Dictionary = {}
	for raw_path in list:
		var path: Dictionary = _validate_path(raw_path)
		if path.is_empty():
			return
		var path_id: String = path["id"]
		if not PATH_IDS.has(path_id) or seen_paths.has(path_id):
			return
		var card_id: String = (path["card"] as Dictionary)["id"]
		if seen_cards.has(card_id) or deck.has(card_id):
			return
		seen_paths[path_id] = true
		seen_cards[card_id] = true
		_paths.append(path)
	if seen_paths.size() != PATH_IDS.size():
		return
	_deck = deck
	_valid = true


func _validate_deck(source: Variant) -> Array[String]:
	var out: Array[String] = []
	var empty: Array[String] = []
	if not source is Array:
		return empty
	var raw: Array = source
	if raw.size() != STARTER_DECK_SIZE:
		return empty
	var catalog := StarterCards.new()
	var expected: Array[String] = catalog.get_starting_deck()
	if expected.size() != STARTER_DECK_SIZE:
		return empty
	var counts: Dictionary = {}
	for item in raw:
		if not item is String:
			return empty
		var card_id: String = item
		if card_id.strip_edges().is_empty() or not catalog.has_card(card_id):
			return empty
		if int(catalog.get_definition(card_id).get("starting_copies", 0)) <= 0:
			return empty
		counts[card_id] = int(counts.get(card_id, 0)) + 1
		out.append(card_id)
	var expected_counts: Dictionary = {}
	for card_id in expected:
		expected_counts[card_id] = int(expected_counts.get(card_id, 0)) + 1
	if counts != expected_counts:
		return empty
	return out


func _validate_path(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var record: Dictionary = _normalize(raw)
	if not _is_nonblank_string(record.get("id")):
		return {}
	if not _is_nonblank_string(record.get("display_name")):
		return {}
	var passive: Variant = record.get("passive")
	if not passive is Dictionary:
		return {}
	var passive_dict: Dictionary = passive
	if not _is_nonblank_string(passive_dict.get("kind")):
		return {}
	if passive_dict.has("starting_block") and not _is_integral_number(passive_dict.get("starting_block"), false):
		return {}
	if passive_dict.has("replaced_starting_block") and not _is_integral_number(passive_dict.get("replaced_starting_block"), false):
		return {}
	var card: Variant = record.get("card")
	if not card is Dictionary:
		return {}
	var card_dict: Dictionary = card
	if not _is_nonblank_string(card_dict.get("id")):
		return {}
	if not String(card_dict["id"]).begins_with(OWNER_ID + "_"):
		return {}
	if not _is_nonblank_string(card_dict.get("display_name")):
		return {}
	if card_dict.get("owner") != OWNER_ID:
		return {}
	if not _is_integral_number(card_dict.get("cost"), false):
		return {}
	if not _valid_positions(card_dict.get("from_positions"), false):
		return {}
	if not _valid_positions(card_dict.get("to_positions"), true):
		return {}
	var target_kind: Variant = card_dict.get("target_kind")
	if not target_kind is String or not TARGET_KINDS.has(target_kind):
		return {}
	var to_positions: Array = card_dict.get("to_positions", [])
	if target_kind == "self" and not to_positions.is_empty():
		return {}
	if target_kind != "self" and target_kind != "none" and to_positions.is_empty():
		return {}
	var effects: Variant = card_dict.get("effects")
	if not effects is Dictionary or (effects as Dictionary).is_empty():
		return {}
	for key in (effects as Dictionary):
		if not _is_nonblank_string(key):
			return {}
		var value: Variant = (effects as Dictionary)[key]
		if value is bool:
			continue
		if not _is_integral_number(value, false):
			return {}
	var art: Variant = card_dict.get("illustration_path")
	if not _is_nonblank_string(art):
		return {}
	var art_path: String = art
	if not art_path.begins_with("res://") or not art_path.ends_with(".png"):
		return {}
	# Fail closed unless this record is exactly the authored contract for its ID:
	# a type-consistent but altered rule value (10 -> 16 Block, once_per_turn
	# false, Lance Pin damage 8, another warden_-prefixed card ID, ...) is invalid.
	var path_id: String = record["id"]
	if not PATH_IDS.has(path_id):
		return {}
	if not _exactly_equal(record, _expected_path(path_id)):
		return {}
	return record


func _valid_positions(value: Variant, allow_empty: bool) -> bool:
	if not value is Array:
		return false
	var list: Array = value
	if list.is_empty():
		return allow_empty
	var seen: Dictionary = {}
	for item in list:
		if not _is_integral_number(item, false):
			return false
		var position: int = int(item)
		if position < MIN_POSITION or position > MAX_POSITION:
			return false
		if seen.has(position):
			return false
		seen[position] = true
	return true


## Normalizes JSON integral floats to ints so receipts and comparisons are exact.
func _normalize(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if is_finite(number) and floor(number) == number and absf(number) <= MAX_SAFE_FLOAT_INT:
			return int(number)
		return value
	if value is Array:
		var out_list: Array = []
		for item in value:
			out_list.append(_normalize(item))
		return out_list
	if value is Dictionary:
		var out_dict: Dictionary = {}
		for key in value:
			out_dict[key] = _normalize(value[key])
		return out_dict
	return value


func _is_integral_number(value: Variant, allow_negative: bool) -> bool:
	if typeof(value) == TYPE_INT:
		return allow_negative or int(value) >= 0
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		return is_finite(number) and floor(number) == number and number <= MAX_SAFE_FLOAT_INT \
			and (allow_negative or number >= 0.0)
	return false


func _is_nonblank_string(value: Variant) -> bool:
	if not value is String:
		return false
	return not (value as String).strip_edges().is_empty()


## The exact authored base Warden passive (start combat gain 6 Block).
func _expected_base_passive() -> Dictionary:
	return {"kind": "starting_block", "starting_block": 6}


## The exact authored Path record for one stable Path ID. Built fresh per call so
## callers can never mutate a shared expected record.
func _expected_path(path_id: String) -> Dictionary:
	if path_id == "bulwark":
		return {
			"id": "bulwark",
			"display_name": "Bulwark",
			"passive": {
				"kind": "replaces_starting_block",
				"replaced_kind": "starting_block",
				"replaced_starting_block": 6,
				"starting_block": 10,
				"stacks": false,
			},
			"card": {
				"id": "warden_bulwark_brace",
				"display_name": "Bulwark Brace",
				"owner": OWNER_ID,
				"cost": 1,
				"from_positions": [1, 2, 3],
				"target_kind": "self",
				"to_positions": [],
				"effects": {"block": 9},
				"illustration_path": "res://assets/paper/cards/warden_bulwark_brace.png",
			},
		}
	if path_id == "vanguard":
		return {
			"id": "vanguard",
			"display_name": "Vanguard",
			"passive": {
				"kind": "first_attack_per_turn_pins",
				"applies_to": OWNER_ID,
				"trigger": "first_confirmed_attack_each_player_turn",
				"once_per_turn": true,
				"status": "pinned",
			},
			"card": {
				"id": "warden_lance_pin",
				"display_name": "Lance Pin",
				"owner": OWNER_ID,
				"cost": 1,
				"from_positions": [1],
				"target_kind": "enemy_single",
				"to_positions": [1, 2],
				"effects": {"damage": 6, "pinned": true},
				"illustration_path": "res://assets/paper/cards/warden_lance_pin.png",
			},
		}
	return {}


## Exact recursive comparison: same keys, same array order, same value types
## (so JSON true never matches 1), with numbers already normalized to ints.
func _exactly_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Array:
		var left_list: Array = a
		var right_list: Array = b
		if left_list.size() != right_list.size():
			return false
		for index in left_list.size():
			if not _exactly_equal(left_list[index], right_list[index]):
				return false
		return true
	if a is Dictionary:
		var left_dict: Dictionary = a
		var right_dict: Dictionary = b
		if left_dict.size() != right_dict.size():
			return false
		for key in left_dict:
			if not right_dict.has(key):
				return false
			if not _exactly_equal(left_dict[key], right_dict[key]):
				return false
		return true
	return a == b
