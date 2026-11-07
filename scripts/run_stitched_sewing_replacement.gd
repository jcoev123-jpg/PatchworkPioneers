class_name RunStitchedSewingReplacement
extends RefCounted
## Scene-free Design v4 (Stitched) Sewing Circle replacement of ONE LOST doll (S6 recovery rule).
##
## One single-use visit at one map node. A doll at 0 HP is only HANGING and stays in the party; only a
## record with a native boolean lost == true may be replaced. The owner (the later run caller) supplies
## prepared candidate templates: unused roster heroes with their OWN starter profile (id, max_hp, hp and
## four tier-1, untorn starter parts). This service validates and copies them; it never samples a hero,
## invents a stat or part, charges a fee or heals. The lost doll's gear already went to the satchel
## through the existing loss path, so nothing is sent there again. It never touches RNG, candles, gold,
## scraps, satchel, patches, pockets, cards, map traversal or battle state.
##
## Party record: {"id", "rank": 1-4 (distinct), "lost": bool, "hp", "max_hp", "parts", ...opaque}.
## Survivors wear four valid slots; LOST records have hp == 0 and parts == {}.
## Candidate template: {"id", "max_hp": int > 0, "hp": 1..max_hp, "parts": {four slots: tier 1, untorn,
## catalog slot and owner == candidate id}, ...opaque}; "rank" and "lost" are assigned by the service.
##
## API: read_state(), quote(), replace(lost_id, candidate_id, expected_node_id, expected_state),
## leave(expected_node_id, expected_state). Every mutation must present the node id and the exact state
## last published; a stale or forged state, wrong node, a closed visit or any illegal request fails with
## {"ok": false, "error": ...} and changes nothing and does not consume the visit. A successful replace or
## leave closes the visit for good.

const PARTY_SIZE := 4

var _node_id := ""
var _party: Array = []
var _candidates: Array = []
var _catalog: Dictionary = {}
var _open := true
var _version := 0
var _error := ""


func _init(node_id: Variant = "", party: Variant = [], candidates: Variant = [], catalog_by_id: Variant = {}) -> void:
	_error = _setup(node_id, party, candidates, catalog_by_id)
	if not _error.is_empty():
		_open = false


## The authoritative snapshot (deep copy). Pass it back as expected_state.
func read_state() -> Dictionary:
	if not _error.is_empty():
		return {"ok": false, "error": _error}
	return {
		"ok": true,
		"node_id": _node_id,
		"open": _open,
		"version": _version,
		"party": _party.duplicate(true),
		"candidates": _candidates.duplicate(true),
	}


## Allowed replacements right now. Candidate ids are named only while the visit is open and a LOST doll
## exists; Leave is always listed (available only while open).
func quote() -> Dictionary:
	if not _error.is_empty():
		return {"ok": false, "error": _error}
	var lost: Array = []
	for hero in _party:
		if _is_lost(hero):
			lost.append({"hero_id": str(hero["id"]), "name": str(hero.get("name", hero["id"])), "rank": int(hero["rank"])})
	var offers: Array = []
	if _open and not lost.is_empty():
		for candidate in _candidates:
			offers.append(_candidate_summary(candidate))
	return {
		"ok": true,
		"node_id": _node_id,
		"open": _open,
		"version": _version,
		"lost": lost,
		"can_replace": not offers.is_empty(),
		"candidates": offers,
		"leave": {"action": "leave", "available": _open},
		"state": read_state(),
	}


## Puts candidate_id in the vacated party slot (same rank and party index) of the LOST doll lost_id.
func replace(lost_id: Variant, candidate_id: Variant, expected_node_id: Variant, expected_state: Variant) -> Dictionary:
	var gate := _gate(expected_node_id, expected_state)
	if not gate.is_empty():
		return _fail(gate)
	if typeof(lost_id) != TYPE_STRING or typeof(candidate_id) != TYPE_STRING:
		return _fail("lost id and candidate id must be strings")
	var party_index := -1
	for index in range(_party.size()):
		if str(_party[index]["id"]) == str(lost_id):
			party_index = index
	if party_index < 0:
		return _fail("unknown doll: " + str(lost_id))
	if not _is_lost(_party[party_index]):
		return _fail("doll is not lost")
	var candidate: Dictionary = {}
	for entry in _candidates:
		if str(entry["id"]) == str(candidate_id):
			candidate = entry
	if candidate.is_empty():
		return _fail("unknown candidate: " + str(candidate_id))
	var before := read_state()
	var rank := int(_party[party_index]["rank"])
	var hero: Dictionary = candidate.duplicate(true)
	hero["rank"] = rank
	hero["lost"] = false
	_party[party_index] = hero
	_open = false
	_version += 1
	var after := read_state()
	var unchanged: Array = []
	for index in range(_party.size()):
		if index != party_index:
			unchanged.append(str(_party[index]["id"]))
	return {
		"ok": true,
		"error": "",
		"action": "replace",
		"node_id": _node_id,
		"lost_id": str(lost_id),
		"candidate_id": str(candidate_id),
		"rank": rank,
		"party_index": party_index,
		"hero_before": before["party"][party_index],
		"hero_after": after["party"][party_index],
		"changed_heroes": [after["party"][party_index]],
		"unchanged_ids": unchanged,
		"charged_gold": 0,
		"charged_scraps": 0,
		"healed": 0,
		"source_state": before,
		"state": after,
	}


## Ends the visit without changing anything.
func leave(expected_node_id: Variant, expected_state: Variant) -> Dictionary:
	var gate := _gate(expected_node_id, expected_state)
	if not gate.is_empty():
		return _fail(gate)
	var before := read_state()
	_open = false
	_version += 1
	var after := read_state()
	return {
		"ok": true,
		"error": "",
		"action": "leave",
		"node_id": _node_id,
		"changed_heroes": [],
		"source_state": before,
		"state": after,
	}


func _gate(expected_node_id: Variant, expected_state: Variant) -> String:
	if not _error.is_empty():
		return _error
	if not _open:
		return "visit is closed"
	if typeof(expected_node_id) != TYPE_STRING or str(expected_node_id) != _node_id:
		return "wrong node"
	if not expected_state is Dictionary:
		return "expected state must be a dictionary"
	if JSON.stringify(expected_state, "", true) != JSON.stringify(read_state(), "", true):
		return "stale or forged state"
	return ""


func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "state": read_state()}


## Only a native boolean lost == true is LOST; HP 0 (Hanging) is not.
func _is_lost(hero: Dictionary) -> bool:
	return typeof(hero.get("lost")) == TYPE_BOOL and bool(hero["lost"])


func _candidate_summary(candidate: Dictionary) -> Dictionary:
	var parts: Dictionary = {}
	for slot in StitchedParts.SLOTS:
		var worn: Dictionary = candidate["parts"][slot]
		var entry: Dictionary = _catalog[str(worn["id"])]
		var ability: Dictionary = StitchedParts.ability_at_tier(entry, int(worn["tier"])).duplicate(true)
		var stat: Dictionary = StitchedParts.stat_at_tier(entry, int(worn["tier"])).duplicate(true)
		parts[slot] = {
			"id": str(worn["id"]),
			"name": str(entry["name"]),
			"slot": slot,
			"owner": str(entry["owner"]),
			"tier": int(worn["tier"]),
			"torn": bool(worn["torn"]),
			"ability": ability,
			"stat": stat,
			"text": str(entry["text"]),
		}
	return {
		"candidate_id": str(candidate["id"]),
		"name": str(candidate.get("name", candidate["id"])),
		"max_hp": int(candidate["max_hp"]),
		"hp": int(candidate["hp"]),
		"parts": parts,
	}


func _setup(node_id: Variant, party: Variant, candidates: Variant, catalog_by_id: Variant) -> String:
	if typeof(node_id) != TYPE_STRING or str(node_id).is_empty():
		return "node id must be a nonempty string"
	if not catalog_by_id is Dictionary or catalog_by_id.is_empty():
		return "catalog is missing"
	for key in catalog_by_id:
		var entry: Variant = catalog_by_id[key]
		if typeof(key) != TYPE_STRING or not entry is Dictionary:
			return "catalog entry is malformed"
		if str(entry.get("id", "")) != str(key) or not str(entry.get("slot", "")) in StitchedParts.SLOTS:
			return "catalog entry is malformed: " + str(key)
		if not entry.get("ability") is Dictionary or not entry.has("name") or not entry.has("owner") or not entry.has("text"):
			return "catalog entry is incomplete: " + str(key)
	_catalog = catalog_by_id.duplicate(true)
	if not party is Array or party.size() != PARTY_SIZE:
		return "party needs exactly %d dolls" % PARTY_SIZE
	var seen_ids: Dictionary = {}
	var seen_ranks: Dictionary = {}
	var clean_party: Array = []
	for raw in party:
		if not raw is Dictionary or typeof(raw.get("id")) != TYPE_STRING or str(raw["id"]).is_empty():
			return "party record needs a nonempty id"
		var hero_id := str(raw["id"])
		if seen_ids.has(hero_id):
			return "duplicate party id: " + hero_id
		seen_ids[hero_id] = true
		if typeof(raw.get("rank")) != TYPE_INT or int(raw["rank"]) < 1 or int(raw["rank"]) > PARTY_SIZE:
			return "doll %s needs an integer rank 1-%d" % [hero_id, PARTY_SIZE]
		if seen_ranks.has(int(raw["rank"])):
			return "duplicate rank: %d" % int(raw["rank"])
		seen_ranks[int(raw["rank"])] = true
		if typeof(raw.get("lost")) != TYPE_BOOL:
			return "doll %s needs a boolean lost flag" % hero_id
		if typeof(raw.get("max_hp")) != TYPE_INT or int(raw["max_hp"]) <= 0 \
				or typeof(raw.get("hp")) != TYPE_INT or int(raw["hp"]) < 0 or int(raw["hp"]) > int(raw["max_hp"]):
			return "doll %s has invalid HP" % hero_id
		# Loss already unpicked every part into the satchel. Only that exact empty,
		# zero-HP state is legal; an empty survivor or an equipped LOST doll is not.
		if _is_lost(raw):
			if raw["hp"] != 0 or not raw.get("parts") is Dictionary or not raw["parts"].is_empty():
				return "doll %s has invalid lost state" % hero_id
			clean_party.append(raw.duplicate(true))
			continue
		var parts_error := _check_parts(raw.get("parts"), false, "")
		if not parts_error.is_empty():
			return "doll %s: %s" % [hero_id, parts_error]
		clean_party.append(raw.duplicate(true))
	if not candidates is Array or candidates.is_empty():
		return "candidates must be a nonempty array"
	var seen_candidates: Dictionary = {}
	var clean_candidates: Array = []
	for raw_candidate in candidates:
		if not raw_candidate is Dictionary or typeof(raw_candidate.get("id")) != TYPE_STRING or str(raw_candidate["id"]).is_empty():
			return "candidate needs a nonempty id"
		var candidate_id := str(raw_candidate["id"])
		if seen_candidates.has(candidate_id):
			return "duplicate candidate id: " + candidate_id
		seen_candidates[candidate_id] = true
		if seen_ids.has(candidate_id):
			return "candidate already in party: " + candidate_id
		if raw_candidate.has("rank") or raw_candidate.has("lost"):
			return "candidate %s must not carry rank or lost" % candidate_id
		if typeof(raw_candidate.get("max_hp")) != TYPE_INT or int(raw_candidate["max_hp"]) <= 0:
			return "candidate %s needs a positive integer max_hp" % candidate_id
		if typeof(raw_candidate.get("hp")) != TYPE_INT or int(raw_candidate["hp"]) < 1 or int(raw_candidate["hp"]) > int(raw_candidate["max_hp"]):
			return "candidate %s needs an integer hp from 1 to max_hp" % candidate_id
		var starter_error := _check_parts(raw_candidate.get("parts"), true, candidate_id)
		if not starter_error.is_empty():
			return "candidate %s: %s" % [candidate_id, starter_error]
		clean_candidates.append(raw_candidate.duplicate(true))
	_party = clean_party
	_candidates = clean_candidates
	_node_id = str(node_id)
	return ""


## Empty when the parts dictionary holds exactly four valid records. starter: tier 1, untorn and owned
## by owner_id.
func _check_parts(parts: Variant, starter: bool, owner_id: String) -> String:
	if not parts is Dictionary or parts.size() != StitchedParts.SLOTS.size():
		return "needs exactly four slots"
	for slot in StitchedParts.SLOTS:
		var worn: Variant = parts.get(slot)
		if not worn is Dictionary or worn.size() != 3:
			return "%s part record is missing or malformed" % slot
		if typeof(worn.get("id")) != TYPE_STRING or not _catalog.has(str(worn["id"])):
			return "%s has an unknown part id" % slot
		var entry: Dictionary = _catalog[str(worn["id"])]
		if str(entry["slot"]) != slot:
			return "part %s does not fit slot %s" % [str(worn["id"]), slot]
		if typeof(worn.get("tier")) != TYPE_INT or int(worn["tier"]) < StitchedParts.MIN_TIER or int(worn["tier"]) > StitchedParts.MAX_TIER:
			return "%s has an invalid tier" % slot
		if typeof(worn.get("torn")) != TYPE_BOOL:
			return "%s torn must be a boolean" % slot
		if starter:
			if int(worn["tier"]) != 1:
				return "%s starter part must be tier 1" % slot
			if bool(worn["torn"]):
				return "%s starter part must not be torn" % slot
			if str(entry["owner"]) != owner_id:
				return "%s starter part belongs to %s" % [slot, str(entry["owner"])]
	return ""
