class_name RunStitchedHeroVitalSeams
extends RefCounted
## Bounded Stitched-only, deterministic, no-scene Event adapter for genuine hero-gated vitality crossroads.
##
## Validates a Design v4 four-doll party (ranks 1-4 of distinct canonical IDs) and wallet,
## authenticates authored events against data/events/v3_hero_vital_events.json,
## quotes four-key outcomes {gold, scraps, hp, max_hp}, and returns an authenticated one-use receipt
## with signed resource/HP/max-HP intents.
## No scene dependencies, no live run mutations, no RNG creation or consumption.

const CATALOG_PATH := "res://data/events/v3_hero_vital_events.json"

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

const MIN_VITAL_MAX_HP := 10
const PARTY_SIZE := 4
const MIN_RANK := 1
const MAX_RANK := 4
const MAX_INT := 9223372036854775807

var _node_id: String = ""
var _event_id: String = ""
var _event_record: Dictionary = {}
var _required_hero: String = ""
var _party: Array = []
var _party_by_id: Dictionary = {}
var _wallet: Dictionary = {"gold": 0, "scraps": 0}

var _valid: bool = false
var _open: bool = false
var _claimed: bool = false
var _version: int = 0
var _error: String = ""


## Suggested static entry point for opening an authentic Stitched hero vitality crossroad visit.
static func open_stitched(
	node_id: Variant,
	authentic_event_record: Variant,
	four_hero_snapshot: Variant,
	wallet: Variant
) -> RunStitchedHeroVitalSeams:
	return RunStitchedHeroVitalSeams.new(node_id, authentic_event_record, four_hero_snapshot, wallet)


func _init(
	node_id: Variant = null,
	authentic_event_record: Variant = null,
	four_hero_snapshot: Variant = null,
	wallet: Variant = null
) -> void:
	if node_id == null and authentic_event_record == null and four_hero_snapshot == null and wallet == null:
		_valid = false
		_open = false
		_error = "uninitialized visit"
		return

	_error = _setup(node_id, authentic_event_record, four_hero_snapshot, wallet)
	if _error.is_empty():
		_valid = true
		_open = true
		_claimed = false
		_version = 0
	else:
		_valid = false
		_open = false
		_claimed = false


func is_valid() -> bool:
	return _valid and _error.is_empty() and not _claimed


func is_open() -> bool:
	return _open and _valid and not _claimed and _error.is_empty()


func is_claimed() -> bool:
	return _claimed


func get_node_id() -> String:
	return _node_id


func get_event_id() -> String:
	return _event_id


func get_required_hero() -> String:
	return _required_hero


func get_wallet() -> Dictionary:
	return _wallet.duplicate(true)


func get_party() -> Array:
	return _party.duplicate(true)


func get_version() -> int:
	return _version


func get_error() -> String:
	return _error


func read_state() -> Dictionary:
	if not _error.is_empty():
		return {
			"ok": false,
			"error": _error,
			"node_id": _node_id,
			"event_id": _event_id,
			"required_hero": _required_hero,
			"open": false,
			"claimed": _claimed,
			"version": _version,
			"wallet": _wallet.duplicate(true),
			"party": _party.duplicate(true),
		}
	return {
		"ok": true,
		"error": "",
		"node_id": _node_id,
		"event_id": _event_id,
		"required_hero": _required_hero,
		"open": is_open(),
		"claimed": _claimed,
		"version": _version,
		"wallet": _wallet.duplicate(true),
		"party": _party.duplicate(true),
	}


func get_state() -> Dictionary:
	return read_state()


## Read-only preview/quote of all authored choices with exact deltas, availability and projected wallet.
func preview_choices() -> Dictionary:
	if not _valid or not _open or _claimed or not _error.is_empty():
		var err: String = _error
		if err.is_empty():
			err = "service closed or already claimed" if (_claimed or not _open) else "invalid visit"
		return {
			"ok": false,
			"error": err,
			"node_id": _node_id,
			"event_id": _event_id,
			"required_hero": _required_hero,
			"choices": [],
			"state": read_state(),
		}

	var raw_choices: Variant = _event_record.get("choices")
	if not (raw_choices is Array):
		return {
			"ok": false,
			"error": "malformed event choices array",
			"node_id": _node_id,
			"event_id": _event_id,
			"required_hero": _required_hero,
			"choices": [],
			"state": read_state(),
		}

	var protagonist: Dictionary = _party_by_id.get(_required_hero, {})
	var protagonist_rank: int = int(protagonist.get("rank", 0))
	var protagonist_max_hp: int = int(protagonist.get("max_hp", 0))
	var protagonist_hp: int = int(protagonist.get("hp", 0))

	var choice_entries: Array = []
	for raw_choice: Variant in (raw_choices as Array):
		if not (raw_choice is Dictionary):
			continue
		var choice_dict: Dictionary = raw_choice
		var cid: String = String(choice_dict.get("id", ""))
		var ctext: String = String(choice_dict.get("text", ""))
		var parsed_outcome: Dictionary = _parse_four_key_outcome(choice_dict.get("outcome"))

		if not parsed_outcome.get("ok", false):
			var unavail_proj: Dictionary = project_vital_consequence(
				protagonist_hp,
				protagonist_max_hp,
				0,
				0,
				false
			)
			choice_entries.append({
				"id": cid,
				"choice_id": cid,
				"text": ctext,
				"gold_delta": null,
				"scraps_delta": null,
				"hp_delta": null,
				"max_hp_delta": null,
				"projected_max_hp": unavail_proj["projected_max_hp"],
				"projected_hp": unavail_proj["projected_hp"],
				"effective_hp_delta": unavail_proj["effective_hp_delta"],
				"target_hero_id": _required_hero,
				"target_hero_rank": protagonist_rank,
				"available": false,
				"affordable": false,
				"blocked": "malformed four-key outcome",
				"outcome": (choice_dict.get("outcome") if choice_dict.get("outcome") is Dictionary else {}).duplicate(true),
				"wallet": _wallet.duplicate(true),
				"projected_wallet": _wallet.duplicate(true),
				"projected_gold": _wallet["gold"],
				"projected_scraps": _wallet["scraps"],
			})
			continue

		var gold_delta: int = parsed_outcome["gold"]
		var scraps_delta: int = parsed_outcome["scraps"]
		var hp_delta: int = parsed_outcome["hp"]
		var max_hp_delta: int = parsed_outcome["max_hp"]

		var gold_ok := true
		if gold_delta < 0 and _wallet["gold"] + gold_delta < 0:
			gold_ok = false
		elif gold_delta > 0 and gold_delta > MAX_INT - _wallet["gold"]:
			gold_ok = false

		var scraps_ok := true
		if scraps_delta < 0 and _wallet["scraps"] + scraps_delta < 0:
			scraps_ok = false
		elif scraps_delta > 0 and scraps_delta > MAX_INT - _wallet["scraps"]:
			scraps_ok = false

		var max_hp_ok := true
		var projected_max: int = protagonist_max_hp + max_hp_delta
		if max_hp_delta > 0 and max_hp_delta > MAX_INT - protagonist_max_hp:
			max_hp_ok = false
		elif projected_max < MIN_VITAL_MAX_HP:
			max_hp_ok = false

		var wasted_heal: bool = is_pure_paid_heal_at_full_hp(gold_delta, scraps_delta, hp_delta, max_hp_delta, protagonist)

		var available: bool = gold_ok and scraps_ok and max_hp_ok and not wasted_heal
		var blocked := ""
		if not gold_ok:
			blocked = "insufficient gold"
		elif not scraps_ok:
			blocked = "insufficient scraps"
		elif not max_hp_ok:
			blocked = "max HP reduction below floor %d" % MIN_VITAL_MAX_HP
		elif wasted_heal:
			blocked = "target hero already at full HP"

		var proj_gold: int = _wallet["gold"] + gold_delta if available else _wallet["gold"]
		var proj_scraps: int = _wallet["scraps"] + scraps_delta if available else _wallet["scraps"]
		var proj_wallet := {"gold": proj_gold, "scraps": proj_scraps}

		var vitals_proj: Dictionary = project_vital_consequence(
			protagonist_hp,
			protagonist_max_hp,
			hp_delta,
			max_hp_delta,
			available
		)

		choice_entries.append({
			"id": cid,
			"choice_id": cid,
			"text": ctext,
			"gold_delta": gold_delta,
			"scraps_delta": scraps_delta,
			"hp_delta": hp_delta,
			"max_hp_delta": max_hp_delta,
			"projected_max_hp": vitals_proj["projected_max_hp"],
			"projected_hp": vitals_proj["projected_hp"],
			"effective_hp_delta": vitals_proj["effective_hp_delta"],
			"target_hero_id": _required_hero,
			"target_hero_rank": protagonist_rank,
			"available": available,
			"affordable": available,
			"blocked": blocked,
			"outcome": parsed_outcome["raw_outcome"].duplicate(true),
			"wallet": proj_wallet.duplicate(true),
			"projected_wallet": proj_wallet.duplicate(true),
			"projected_gold": proj_gold,
			"projected_scraps": proj_scraps,
		})

	return {
		"ok": true,
		"node_id": _node_id,
		"event_id": _event_id,
		"required_hero": _required_hero,
		"choices": choice_entries,
		"state": read_state(),
	}


func quote() -> Dictionary:
	return preview_choices()


func preview() -> Dictionary:
	return preview_choices()


## Commits an eligible choice once, strictly guarded by expected_node_id and expected_state.
## Returns detached authenticated receipt on success; refuses without mutation on any error.
func choose(
	choice_id: Variant,
	expected_node_id: Variant = null,
	expected_state: Variant = null
) -> Dictionary:
	if not _error.is_empty():
		return _fail(_error)
	if not _valid or not _open or _claimed:
		return _fail("service closed or already claimed")

	# Disambiguate call if called with (event_id, choice_id, node_id, state)
	var active_choice: Variant = choice_id
	var exp_node: Variant = expected_node_id
	var exp_state: Variant = expected_state

	if typeof(active_choice) == TYPE_STRING and String(active_choice) == _event_id:
		active_choice = exp_node
		exp_node = exp_state
		exp_state = null

	# Validate expected node ID guard
	if exp_node == null:
		return _fail("missing expected node id")
	if typeof(exp_node) != TYPE_STRING:
		return _fail("expected node id must be a string")
	var node_str: String = exp_node
	if node_str.strip_edges().is_empty() or node_str != node_str.strip_edges() or node_str != _node_id:
		return _fail("wrong node ID: expected '%s', got '%s'" % [_node_id, node_str])

	# Validate expected state guard
	if exp_state == null:
		return _fail("missing expected state")
	if not (exp_state is Dictionary):
		return _fail("expected state must be a dictionary")
	if not _same_value(exp_state, read_state()):
		return _fail("stale or forged expected state")

	# Validate choice ID
	if active_choice == null or typeof(active_choice) != TYPE_STRING:
		return _fail("choice id must be a non-empty string")
	var target_cid: String = String(active_choice).strip_edges()
	if target_cid.is_empty():
		return _fail("choice id must be a non-empty string")

	# Locate choice in authored record
	var matched_choice: Dictionary = {}
	var raw_choices: Variant = _event_record.get("choices")
	if raw_choices is Array:
		for item: Variant in (raw_choices as Array):
			if item is Dictionary and String((item as Dictionary).get("id", "")) == target_cid:
				matched_choice = item
				break
	if matched_choice.is_empty():
		return _fail("unoffered choice ID: " + target_cid)

	# Validate choice outcome
	var parsed_outcome: Dictionary = _parse_four_key_outcome(matched_choice.get("outcome"))
	if not parsed_outcome.get("ok", false):
		return _fail("malformed four-key outcome for choice: " + target_cid)

	var gold_delta: int = parsed_outcome["gold"]
	var scraps_delta: int = parsed_outcome["scraps"]
	var hp_delta: int = parsed_outcome["hp"]
	var max_hp_delta: int = parsed_outcome["max_hp"]

	# Wallet affordability
	if gold_delta < 0 and _wallet["gold"] + gold_delta < 0:
		return _fail("insufficient gold for choice %s (cost %d, have %d)" % [target_cid, -gold_delta, _wallet["gold"]])
	if gold_delta > 0 and gold_delta > MAX_INT - _wallet["gold"]:
		return _fail("integer overflow on gold award")

	if scraps_delta < 0 and _wallet["scraps"] + scraps_delta < 0:
		return _fail("insufficient scraps for choice %s (cost %d, have %d)" % [target_cid, -scraps_delta, _wallet["scraps"]])
	if scraps_delta > 0 and scraps_delta > MAX_INT - _wallet["scraps"]:
		return _fail("integer overflow on scraps award")

	# Max HP floor
	var protagonist: Dictionary = _party_by_id.get(_required_hero, {})
	var protagonist_max_hp: int = int(protagonist.get("max_hp", 0))
	var protagonist_hp: int = int(protagonist.get("hp", 0))
	var projected_max: int = protagonist_max_hp + max_hp_delta
	if max_hp_delta > 0 and max_hp_delta > MAX_INT - protagonist_max_hp:
		return _fail("integer overflow on max HP credit")
	if projected_max < MIN_VITAL_MAX_HP:
		return _fail("max HP reduction below vitality floor %d (current %d, delta %d, result %d)" % [MIN_VITAL_MAX_HP, protagonist_max_hp, max_hp_delta, projected_max])

	# Pure paid heal at full HP
	if is_pure_paid_heal_at_full_hp(gold_delta, scraps_delta, hp_delta, max_hp_delta, protagonist):
		return _fail("target hero already at full HP")

	# Commit and latch exactly once
	var before_state: Dictionary = (exp_state as Dictionary).duplicate(true)
	var wallet_before: Dictionary = _wallet.duplicate(true)

	_wallet["gold"] += gold_delta
	_wallet["scraps"] += scraps_delta
	_claimed = true
	_open = false
	_version += 1

	var wallet_after: Dictionary = _wallet.duplicate(true)
	var after_state: Dictionary = read_state()

	var receipt_dict := {
		"event_id": _event_id,
		"choice_id": target_cid,
		"node_id": _node_id,
		"hero_id": _required_hero,
		"target_hero_id": _required_hero,
		"target_hero_rank": int(protagonist.get("rank", 0)),
		"gold_delta": gold_delta,
		"scraps_delta": scraps_delta,
		"hp_delta": hp_delta,
		"max_hp_delta": max_hp_delta,
		"wallet": wallet_after.duplicate(true),
	}

	var vitals_proj: Dictionary = project_vital_consequence(
		protagonist_hp,
		protagonist_max_hp,
		hp_delta,
		max_hp_delta,
		true
	)

	return {
		"ok": true,
		"error": "",
		"event_id": _event_id,
		"choice_id": target_cid,
		"decision": target_cid,
		"node_id": _node_id,
		"hero_id": _required_hero,
		"target_hero_id": _required_hero,
		"target_hero_rank": int(protagonist.get("rank", 0)),
		"target_hero": protagonist.duplicate(true),
		"gold_delta": gold_delta,
		"scraps_delta": scraps_delta,
		"hp_delta": hp_delta,
		"max_hp_delta": max_hp_delta,
		"projected_max_hp": vitals_proj["projected_max_hp"],
		"projected_hp": vitals_proj["projected_hp"],
		"effective_hp_delta": vitals_proj["effective_hp_delta"],
		"wallet_before": wallet_before,
		"wallet": wallet_after,
		"wallet_after": wallet_after,
		"intents": {
			"hero_id": _required_hero,
			"hp_delta": hp_delta,
			"max_hp_delta": max_hp_delta,
			"gold_delta": gold_delta,
			"scraps_delta": scraps_delta,
		},
		"receipt": receipt_dict,
		"source_state": before_state,
		"state": after_state,
		"open": false,
		"claimed": true,
	}


func claim(
	choice_id: Variant,
	expected_node_id: Variant = null,
	expected_state: Variant = null
) -> Dictionary:
	return choose(choice_id, expected_node_id, expected_state)


func _fail(reason: String) -> Dictionary:
	return {
		"ok": false,
		"error": reason,
		"event_id": _event_id if _valid else "",
		"choice_id": "",
		"node_id": _node_id if _valid else "",
		"hero_id": _required_hero if _valid else "",
		"wallet": _wallet.duplicate(true),
		"state": read_state(),
		"receipt": {},
		"intents": {},
	}


func _setup(
	node_id: Variant,
	authentic_event_record: Variant,
	four_hero_snapshot: Variant,
	wallet: Variant
) -> String:
	# 1. Validate node ID
	if node_id == null or typeof(node_id) != TYPE_STRING:
		return "node_id must be a non-empty string"
	var n_str: String = node_id
	if n_str.strip_edges().is_empty() or n_str != n_str.strip_edges():
		return "node_id must be a trimmed non-empty string"
	_node_id = n_str

	# 2. Authenticate event against genuine shipped catalog
	var shipped_catalog: Dictionary = RunV3HeroVitalEventGate.load_shipped_catalog()
	if shipped_catalog.is_empty() or not shipped_catalog.has("events") or not (shipped_catalog["events"] is Array):
		return "failed to load shipped hero vital events catalog"

	var catalog_events: Array = shipped_catalog["events"]
	var shipped_by_id: Dictionary = {}
	for ev_raw: Variant in catalog_events:
		if ev_raw is Dictionary and (ev_raw as Dictionary).has("id"):
			shipped_by_id[String((ev_raw as Dictionary)["id"])] = ev_raw

	var genuine_event: Dictionary = {}
	if typeof(authentic_event_record) == TYPE_STRING:
		var ev_id_str: String = String(authentic_event_record).strip_edges()
		if not shipped_by_id.has(ev_id_str):
			return "uncatalogued hero vital event ID: " + ev_id_str
		genuine_event = (shipped_by_id[ev_id_str] as Dictionary).duplicate(true)
	elif authentic_event_record is Dictionary:
		var cand_dict: Dictionary = authentic_event_record
		var cand_id: String = String(cand_dict.get("id", "")).strip_edges()
		if not shipped_by_id.has(cand_id):
			return "uncatalogued hero vital event ID: " + cand_id
		var canonical: Dictionary = shipped_by_id[cand_id]
		if not _same_value(cand_dict, canonical):
			return "forged event record does not match shipped catalog for " + cand_id
		genuine_event = canonical.duplicate(true)
	else:
		return "authentic_event_record must be an event ID string or matching Dictionary"

	var req_hero: String = String(genuine_event.get("required_hero", "")).strip_edges()
	if req_hero.is_empty() or not CANONICAL_HERO_IDS.has(req_hero):
		return "event specifies invalid or uncanonical required hero: " + req_hero

	_event_record = genuine_event
	_event_id = String(genuine_event.get("id", ""))
	_required_hero = req_hero

	# 3. Validate four-hero snapshot
	var raw_heroes: Array = []
	if four_hero_snapshot is Array:
		raw_heroes = four_hero_snapshot
	elif four_hero_snapshot is Dictionary:
		var d: Dictionary = four_hero_snapshot
		if d.has("heroes") and d["heroes"] is Array:
			raw_heroes = d["heroes"]
		elif d.has("party") and d["party"] is Array:
			raw_heroes = d["party"]
		elif d.has("roster") and d["roster"] is Array:
			raw_heroes = d["roster"]
		elif d.has("dolls") and d["dolls"] is Array:
			raw_heroes = d["dolls"]
		else:
			return "four_hero_snapshot dictionary missing heroes/party array"
	else:
		return "four_hero_snapshot must be an Array or Dictionary"

	if raw_heroes.size() != PARTY_SIZE:
		return "four_hero_snapshot must contain exactly %d heroes, got %d" % [PARTY_SIZE, raw_heroes.size()]

	var seen_ids: Dictionary = {}
	var seen_ranks: Dictionary = {}
	var parsed_party: Array = []
	var by_id: Dictionary = {}

	for hero_raw: Variant in raw_heroes:
		if not (hero_raw is Dictionary):
			return "hero snapshot entry must be a dictionary"
		var h_dict: Dictionary = hero_raw

		# ID check
		var hid_val: Variant = h_dict.get("id")
		if hid_val == null or typeof(hid_val) != TYPE_STRING:
			return "hero missing valid string id"
		var hid: String = String(hid_val).strip_edges()
		if not CANONICAL_HERO_IDS.has(hid):
			return "hero id '%s' is not one of the canonical hero IDs" % hid
		if seen_ids.has(hid):
			return "duplicate hero id '%s' in party" % hid
		seen_ids[hid] = true

		# Rank check
		var rank_val: Variant = h_dict.get("rank", h_dict.get("position"))
		if rank_val == null or typeof(rank_val) != TYPE_INT:
			return "hero '%s' missing integer rank 1..%d" % [hid, MAX_RANK]
		var rank_int: int = int(rank_val)
		if rank_int < MIN_RANK or rank_int > MAX_RANK:
			return "hero '%s' rank %d out of bounds (1..%d)" % [hid, rank_int, MAX_RANK]
		if seen_ranks.has(rank_int):
			return "duplicate rank %d in party" % rank_int
		seen_ranks[rank_int] = true

		# Lost check (native bool)
		var lost_val: Variant = h_dict.get("lost")
		if lost_val == null or typeof(lost_val) != TYPE_BOOL:
			return "hero '%s' missing native bool lost" % hid
		var is_lost: bool = bool(lost_val)

		# HP and Max HP checks
		var hp_val: Variant = h_dict.get("hp")
		if hp_val == null or typeof(hp_val) != TYPE_INT:
			return "hero '%s' missing native int hp" % hid
		var hp_int: int = int(hp_val)

		var max_hp_val: Variant = h_dict.get("effective_max_hp", h_dict.get("max_hp"))
		if max_hp_val == null or typeof(max_hp_val) != TYPE_INT:
			return "hero '%s' missing native int max_hp" % hid
		var max_hp_int: int = int(max_hp_val)

		if max_hp_int < MIN_VITAL_MAX_HP:
			return "hero '%s' max_hp %d is below minimum floor %d" % [hid, max_hp_int, MIN_VITAL_MAX_HP]
		if hp_int < 0 or hp_int > max_hp_int:
			return "hero '%s' hp %d out of range (0..%d)" % [hid, hp_int, max_hp_int]

		var clean_hero: Dictionary = h_dict.duplicate(true)
		clean_hero["id"] = hid
		clean_hero["rank"] = rank_int
		clean_hero["lost"] = is_lost
		clean_hero["hp"] = hp_int
		clean_hero["max_hp"] = max_hp_int

		parsed_party.append(clean_hero)
		by_id[hid] = clean_hero

	if seen_ranks.size() != PARTY_SIZE:
		return "party must cover all ranks 1..%d" % PARTY_SIZE

	# Required hero presence and living check
	if not by_id.has(_required_hero):
		return "required hero '%s' is not present in party" % _required_hero
	if bool(by_id[_required_hero]["lost"]):
		return "required hero '%s' is LOST" % _required_hero

	_party = parsed_party
	_party_by_id = by_id

	# 4. Validate wallet
	if wallet == null or not (wallet is Dictionary):
		return "wallet must be a Dictionary"
	var w_dict: Dictionary = wallet
	var gold_val: Variant = w_dict.get("gold")
	var scraps_val: Variant = w_dict.get("scraps")
	if gold_val == null or typeof(gold_val) != TYPE_INT or int(gold_val) < 0:
		return "wallet gold must be a non-negative integer"
	if scraps_val == null or typeof(scraps_val) != TYPE_INT or int(scraps_val) < 0:
		return "wallet scraps must be a non-negative integer"

	_wallet = {
		"gold": int(gold_val),
		"scraps": int(scraps_val),
	}

	return ""


static func _parse_four_key_outcome(raw_outcome: Variant) -> Dictionary:
	if raw_outcome == null or not (raw_outcome is Dictionary):
		return {"ok": false}
	var outcome: Dictionary = raw_outcome
	for key: String in ["gold", "scraps", "hp", "max_hp"]:
		if not outcome.has(key):
			return {"ok": false}
		var val: Variant = outcome[key]
		# Disallow fractional numbers and non-numeric values
		if typeof(val) == TYPE_INT:
			continue
		elif typeof(val) == TYPE_FLOAT:
			var f: float = float(val)
			if not is_finite(f) or f != floorf(f):
				return {"ok": false}
		else:
			return {"ok": false}

	return {
		"ok": true,
		"gold": int(outcome["gold"]),
		"scraps": int(outcome["scraps"]),
		"hp": int(outcome["hp"]),
		"max_hp": int(outcome["max_hp"]),
		"raw_outcome": outcome,
	}


static func _same_value(a: Variant, b: Variant) -> bool:
	if (typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT) and (typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT):
		return is_finite(a) and is_finite(b) and a == b
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
		for i in range(arr_a.size()):
			if not _same_value(arr_a[i], arr_b[i]):
				return false
		return true
	return a == b


## Pure paid HP heal at full HP predicate:
## hp_delta > 0 AND max_hp_delta == 0 AND gold_delta <= 0 AND scraps_delta <= 0
## AND (gold_delta < 0 OR scraps_delta < 0) AND recipient.hp == recipient.max_hp
static func is_pure_paid_heal_at_full_hp(
	gold_delta: Variant,
	scraps_delta: Variant,
	hp_delta: Variant = null,
	max_hp_delta: Variant = null,
	recipient: Variant = null
) -> bool:
	var g: int = 0
	var s: int = 0
	var h: int = 0
	var m: int = 0
	var rec: Dictionary = {}
	if gold_delta is Dictionary and scraps_delta is Dictionary:
		var outcome: Dictionary = gold_delta
		rec = scraps_delta
		g = int(outcome.get("gold", 0))
		s = int(outcome.get("scraps", 0))
		h = int(outcome.get("hp", 0))
		m = int(outcome.get("max_hp", 0))
	else:
		g = int(gold_delta)
		s = int(scraps_delta)
		h = int(hp_delta)
		m = int(max_hp_delta)
		if recipient is Dictionary:
			rec = recipient
	if rec.is_empty():
		return false
	var hero_hp: int = int(rec.get("hp", 0))
	var hero_max_hp: int = int(rec.get("max_hp", 0))
	return (
		h > 0
		and m == 0
		and g <= 0
		and s <= 0
		and (g < 0 or s < 0)
		and hero_hp == hero_max_hp
	)


static func is_wasted_paid_heal(
	gold_delta: Variant,
	scraps_delta: Variant,
	hp_delta: Variant = null,
	max_hp_delta: Variant = null,
	recipient: Variant = null
) -> bool:
	return is_pure_paid_heal_at_full_hp(gold_delta, scraps_delta, hp_delta, max_hp_delta, recipient)


## Calculates prospective HP and max HP projections for an authored vitality choice outcome.
## When available is true:
##   projected_max_hp = hero.max_hp + max_hp_delta
##   projected_hp = clamp(hero.hp + hp_delta, 0, projected_max_hp)
##   effective_hp_delta = projected_hp - hero.hp
## When available is false:
##   shows unchanged opening HP / max HP with effective_hp_delta = 0.
static func project_vital_consequence(
	opening_hp: int,
	opening_max_hp: int,
	hp_delta: int,
	max_hp_delta: int,
	available: bool
) -> Dictionary:
	if not available:
		return {
			"projected_max_hp": opening_max_hp,
			"projected_hp": opening_hp,
			"effective_hp_delta": 0,
		}
	var proj_max: int = opening_max_hp + max_hp_delta
	var proj_hp: int = clampi(opening_hp + hp_delta, 0, proj_max)
	return {
		"projected_max_hp": proj_max,
		"projected_hp": proj_hp,
		"effective_hp_delta": proj_hp - opening_hp,
	}
