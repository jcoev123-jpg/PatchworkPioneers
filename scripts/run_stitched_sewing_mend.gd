class_name RunStitchedSewingMend
extends RefCounted
## Scene-free Design v4 (Stitched) Sewing Circle mending of torn EQUIPPED body parts.
##
## One visit at one map node: a living hero may pay SCRAPS to clear the torn flag of a worn part.
## The price is quoted from outside (quoted_mend_cost, a positive integer supplied by the later S6
## caller); this service never invents a fee. It mints no part, tier, slot or replacement and does not
## touch a satchel, swap, gold, candles, HP, fray, cards, patches or any RNG. Swapping a mended part
## stays with RunStitchedSewingSwap, which refuses a torn worn part until it is mended.
##
## Records (same shape StitchedRules / RunStitchedSewingSwap consume):
##   worn part: {"id": part_id, "tier": 1|2|3, "torn": bool}   (heroes[n].parts[slot])
## Heroes are opaque dictionaries; only heroes[n].parts[slot].torn ever changes. A hero whose
## "lost" field is true is not eligible (same rule as StitchedRules.mend_part).
##
## API: read_state(), quote(), mend(hero_id, slot, expected_node_id, expected_state),
## leave(expected_node_id, expected_state). Every mutation must present the node id and the exact
## state last published (read_state() or the previous receipt's "state"); a stale or forged state,
## wrong node, a closed visit or any illegal request fails with {"ok": false, "error": ...} and
## changes nothing. A successful mend returns a complete receipt, so another mend in the same visit
## can follow. S6 must still authenticate the real node, quote the fee, apply the receipt to the
## live wallet and party and show the button; nothing here touches the live run.

const MAX_HEROES := 4

var _node_id := ""
var _heroes: Array = []
var _scraps := 0
var _cost := 0
var _catalog: Dictionary = {}
var _open := true
var _version := 0
var _error := ""


## node_id: the Sewing Circle node. heroes: 1-4 run-hero records with distinct ids and a full parts
## dictionary. scraps: nonnegative integer balance. quoted_mend_cost: positive integer price per mend.
## catalog_by_id: StitchedParts catalog "by_id". Everything is deep-copied; invalid input leaves a
## closed, unusable visit with an error.
func _init(node_id: Variant = "", heroes: Variant = [], scraps: Variant = 0, quoted_mend_cost: Variant = 0, catalog_by_id: Variant = {}) -> void:
	_error = _setup(node_id, heroes, scraps, quoted_mend_cost, catalog_by_id)
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
		"scraps": _scraps,
		"mend_cost": _cost,
		"heroes": _heroes.duplicate(true),
	}


## What the player may do right now: per hero and slot the worn part, whether it can be mended and
## why not. Works for an open and a closed (terminal) visit; a closed visit offers nothing.
func quote() -> Dictionary:
	if not _error.is_empty():
		return {"ok": false, "error": _error}
	var hero_quotes: Array = []
	for hero in _heroes:
		var slots: Array = []
		for slot in StitchedParts.SLOTS:
			var worn: Dictionary = hero["parts"][slot]
			var blocked := _blocked(hero, worn)
			slots.append({
				"slot": slot,
				"worn": _summary(worn, slot),
				"can_mend": blocked.is_empty(),
				"blocked": blocked,
				"cost": _cost,
			})
		hero_quotes.append({"hero_id": str(hero["id"]), "name": str(hero.get("name", hero["id"])), "slots": slots})
	return {
		"ok": true,
		"node_id": _node_id,
		"open": _open,
		"version": _version,
		"scraps": _scraps,
		"mend_cost": _cost,
		"heroes": hero_quotes,
		"state": read_state(),
	}


## Clears the torn flag of heroes[hero_id].parts[slot] and charges exactly the quoted price once.
func mend(hero_id: Variant, slot: Variant, expected_node_id: Variant, expected_state: Variant) -> Dictionary:
	var gate := _gate(expected_node_id, expected_state)
	if not gate.is_empty():
		return _fail(gate)
	if typeof(hero_id) != TYPE_STRING or typeof(slot) != TYPE_STRING:
		return _fail("hero id and slot must be strings")
	if not str(slot) in StitchedParts.SLOTS:
		return _fail("unknown slot: " + str(slot))
	var hero_index := -1
	for index in range(_heroes.size()):
		if str(_heroes[index]["id"]) == str(hero_id):
			hero_index = index
	if hero_index < 0:
		return _fail("unknown hero: " + str(hero_id))
	var slot_key := str(slot)
	var worn: Dictionary = _heroes[hero_index]["parts"][slot_key]
	var blocked := _blocked(_heroes[hero_index], worn)
	if not blocked.is_empty():
		return _fail(blocked)
	var before := read_state()
	var scraps_before := _scraps
	_heroes[hero_index]["parts"][slot_key]["torn"] = false
	_scraps -= _cost
	_version += 1
	var after := read_state()
	return {
		"ok": true,
		"error": "",
		"action": "mend",
		"node_id": _node_id,
		"hero_id": str(hero_id),
		"slot": slot_key,
		"part_id": str(worn["id"]),
		"tier": int(worn["tier"]),
		"charged_scraps": _cost,
		"scraps_before": scraps_before,
		"scraps": _scraps,
		"changed_hero": after["heroes"][hero_index],
		"changed_heroes": [after["heroes"][hero_index]],
		"source_state": before,
		"state": after,
	}


## Ends the visit without changing any hero or the wallet.
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
		"charged_scraps": 0,
		"scraps": _scraps,
		"changed_heroes": [],
		"source_state": before,
		"state": after,
	}


## Empty when the part may be mended now, otherwise the reason.
func _blocked(hero: Dictionary, worn: Dictionary) -> String:
	if not _open:
		return "visit closed"
	if typeof(hero.get("lost")) == TYPE_BOOL and bool(hero["lost"]):
		return "hero is lost"
	if not bool(worn["torn"]):
		return "part is not torn"
	if _scraps < _cost:
		return "insufficient scraps"
	return ""


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


func _summary(part: Dictionary, slot: String) -> Dictionary:
	var entry: Dictionary = _catalog[str(part["id"])]
	var tier := int(part["tier"])
	var ability: Dictionary = StitchedParts.ability_at_tier(entry, tier)
	return {
		"id": str(part["id"]),
		"name": str(entry["name"]),
		"slot": slot,
		"owner": str(entry["owner"]),
		"tier": tier,
		"torn": bool(part["torn"]),
		"ability": {"id": str(ability["id"]), "name": str(ability["name"]), "kind": str(ability["kind"])},
		"stat": StitchedParts.stat_at_tier(entry, tier),
		"text": str(entry["text"]),
	}


func _setup(node_id: Variant, heroes: Variant, scraps: Variant, quoted_mend_cost: Variant, catalog_by_id: Variant) -> String:
	if typeof(node_id) != TYPE_STRING or str(node_id).is_empty():
		return "node id must be a nonempty string"
	if typeof(scraps) != TYPE_INT or int(scraps) < 0:
		return "scraps must be a nonnegative integer"
	if typeof(quoted_mend_cost) != TYPE_INT or int(quoted_mend_cost) <= 0:
		return "quoted mend cost must be a positive integer"
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
	if not heroes is Array or heroes.size() < 1 or heroes.size() > MAX_HEROES:
		return "roster needs 1-%d heroes" % MAX_HEROES
	var seen: Dictionary = {}
	var clean_heroes: Array = []
	for raw in heroes:
		if not raw is Dictionary or typeof(raw.get("id")) != TYPE_STRING or str(raw["id"]).is_empty():
			return "hero record needs a nonempty id"
		var hero_id := str(raw["id"])
		if seen.has(hero_id):
			return "duplicate hero id: " + hero_id
		seen[hero_id] = true
		if not raw.get("parts") is Dictionary:
			return "hero %s needs a parts dictionary" % hero_id
		var hero: Dictionary = raw.duplicate(true)
		var parts: Dictionary = {}
		for slot in StitchedParts.SLOTS:
			var result := _normalize(raw["parts"].get(slot), slot)
			if not bool(result["ok"]):
				return "hero %s %s: %s" % [hero_id, slot, str(result["error"])]
			parts[slot] = result["part"]
		if raw["parts"].size() != StitchedParts.SLOTS.size():
			return "hero %s has an unknown slot" % hero_id
		hero["parts"] = parts
		clean_heroes.append(hero)
	_heroes = clean_heroes
	_scraps = int(scraps)
	_cost = int(quoted_mend_cost)
	_node_id = str(node_id)
	return ""


## Validates one worn part record against the catalog and returns {id, tier, torn}.
func _normalize(raw: Variant, slot: String) -> Dictionary:
	if not raw is Dictionary:
		return {"ok": false, "error": "part record is missing or malformed", "part": {}}
	if typeof(raw.get("id")) != TYPE_STRING or not _catalog.has(str(raw["id"])):
		return {"ok": false, "error": "unknown part id", "part": {}}
	var catalog_slot := str(_catalog[str(raw["id"])]["slot"])
	if catalog_slot != slot:
		return {"ok": false, "error": "part %s does not fit slot %s" % [str(raw["id"]), slot], "part": {}}
	var tier: Variant = raw.get("tier")
	var tier_ok := typeof(tier) == TYPE_INT
	if typeof(tier) == TYPE_FLOAT:
		var tier_float := float(tier)
		tier_ok = is_finite(tier_float) and tier_float == floorf(tier_float)
	if not tier_ok or int(tier) < StitchedParts.MIN_TIER or int(tier) > StitchedParts.MAX_TIER:
		return {"ok": false, "error": "invalid tier", "part": {}}
	if typeof(raw.get("torn")) != TYPE_BOOL:
		return {"ok": false, "error": "torn must be a boolean", "part": {}}
	return {"ok": true, "error": "", "part": {"id": str(raw["id"]), "tier": int(tier), "torn": bool(raw["torn"])}}
