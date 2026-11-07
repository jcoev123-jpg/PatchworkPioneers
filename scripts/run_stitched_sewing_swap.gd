class_name RunStitchedSewingSwap
extends RefCounted
## Scene-free Design v4 (Stitched) Sewing Circle body-part exchange.
##
## One visit at one map node: any living hero may trade the part worn in a slot for a spare of
## the SAME slot from the satchel (at most six spares). Slot, never owner, controls legality, so a
## foreign or enemy part ("any" or another hero's owner) is wearable. No gold, scrap, cards,
## energy, deck or RNG is involved; an ordinary swap has no fee in Design v4. Mending and tier
## upgrades are NOT part of this service. Torn worn gear cannot be moved out by a swap: it must be
## mended first (a later S6 caller owns that price).
##
## Records (same shape StitchedRules consumes):
##   worn part:   {"id": part_id, "tier": 1|2|3, "torn": bool}          (heroes[n].parts[slot])
##   satchel part: the same fields plus "slot": "head|arms|torso|legs"
## Heroes are carried as opaque dictionaries; only heroes[n].parts[slot] ever changes, so HP, fray,
## statuses, stats and position survive untouched.
##
## API: read_state(), quote(), swap(hero_id, slot, satchel_index, expected_node_id, expected_state),
## exchange_worn(hero_a_id, hero_b_id, slot, expected_node_id, expected_state),
## leave(expected_node_id, expected_state). exchange_worn trades the intact same-slot worn parts of
## two different living heroes directly (satchel untouched, even if empty); quote() lists these as
## "worn_offers" per slot beside the satchel "offers". Every mutation must present the node id and the exact
## state last published (read_state() or the previous receipt's "state"); a stale or forged state,
## wrong node, a closed visit or any illegal request fails with {"ok": false, "error": ...} and
## changes nothing. A successful swap returns a complete receipt (changed hero, satchel, source
## snapshot and the new authoritative "state"), so another swap in the same visit can follow.
## S6 must still bind the real Sewing Circle node, satchel and four-hero ledger to this service
## and apply its committed receipts; nothing here touches the live run.

const SATCHEL_CAP := 6
const MAX_HEROES := 4

var _node_id := ""
var _heroes: Array = []
var _satchel: Array = []
var _catalog: Dictionary = {}
var _open := true
var _version := 0
var _error := ""


## node_id: the Sewing Circle node. heroes: 1-4 run-hero records with distinct ids and a full
## parts dictionary. satchel: 0-6 spare records. catalog_by_id: StitchedParts catalog "by_id".
## Everything is deep-copied; invalid input leaves a closed, unusable visit with an error.
func _init(node_id: Variant = "", heroes: Variant = [], satchel: Variant = [], catalog_by_id: Variant = {}) -> void:
	_error = _setup(node_id, heroes, satchel, catalog_by_id)
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
		"heroes": _heroes.duplicate(true),
		"satchel": _satchel.duplicate(true),
	}


## What the player may do right now: per hero and slot the worn part and the compatible spares.
## Works for an open and a closed (terminal) visit; a closed visit lists no offers.
func quote() -> Dictionary:
	if not _error.is_empty():
		return {"ok": false, "error": _error}
	var hero_quotes: Array = []
	for hero in _heroes:
		var slots: Array = []
		for slot in StitchedParts.SLOTS:
			var worn: Dictionary = hero["parts"][slot]
			var blocked := ""
			if not _open:
				blocked = "visit closed"
			elif _is_lost(hero):
				blocked = "hero is lost"
			elif bool(worn["torn"]):
				blocked = "worn part is torn: mend it first"
			var offers: Array = []
			if blocked.is_empty():
				for index in range(_satchel.size()):
					if str(_satchel[index]["slot"]) == slot:
						var offer_part := _summary(_satchel[index], slot)
						offers.append({
							"satchel_index": index,
							"part": offer_part,
							"comparison": _comparison(_summary(worn, slot), offer_part),
						})
			# Direct wearer-to-wearer exchange opportunities, in stable roster order.
			var worn_offers: Array = []
			if blocked.is_empty():
				for other in _heroes:
					if str(other["id"]) == str(hero["id"]) or _is_lost(other):
						continue
					var other_worn: Dictionary = other["parts"][slot]
					if bool(other_worn["torn"]):
						continue
					var incoming_part := _summary(other_worn, slot)
					worn_offers.append({
						"hero_id": str(other["id"]),
						"name": str(other.get("name", other["id"])),
						"part": incoming_part,
						"comparison": _comparison(_summary(worn, slot), incoming_part),
					})
			slots.append({
				"slot": slot,
				"worn": _summary(worn, slot),
				"can_swap": blocked.is_empty() and (not offers.is_empty() or not worn_offers.is_empty()),
				"blocked": blocked,
				"offers": offers,
				"worn_offers": worn_offers,
			})
		hero_quotes.append({"hero_id": str(hero["id"]), "name": str(hero.get("name", hero["id"])), "slots": slots})
	var spares: Array = []
	for index in range(_satchel.size()):
		var spare_summary := _summary(_satchel[index], str(_satchel[index]["slot"]))
		spare_summary["satchel_index"] = index
		spares.append(spare_summary)
	return {
		"ok": true,
		"node_id": _node_id,
		"open": _open,
		"version": _version,
		"heroes": hero_quotes,
		"satchel": spares,
		"satchel_count": _satchel.size(),
		"satchel_max": SATCHEL_CAP,
		"state": read_state(),
	}


## Exchanges heroes[hero_id].parts[slot] with satchel[satchel_index]; the replaced worn part takes
## exactly that satchel position (so no part instance is duplicated or lost).
func swap(hero_id: Variant, slot: Variant, satchel_index: Variant, expected_node_id: Variant, expected_state: Variant) -> Dictionary:
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
	if _is_lost(_heroes[hero_index]):
		return _fail("hero is lost")
	if typeof(satchel_index) != TYPE_INT or int(satchel_index) < 0 or int(satchel_index) >= _satchel.size():
		return _fail("invalid satchel index")
	var slot_key := str(slot)
	var spare: Dictionary = _satchel[int(satchel_index)]
	if str(spare["slot"]) != slot_key or str(_catalog[str(spare["id"])]["slot"]) != slot_key:
		return _fail("spare part does not fit the %s slot" % slot_key)
	var worn: Dictionary = _heroes[hero_index]["parts"][slot_key]
	if bool(worn["torn"]):
		return _fail("worn part is torn: mend it before swapping it out")
	var before := read_state()
	var incoming := {"id": str(spare["id"]), "tier": int(spare["tier"]), "torn": bool(spare["torn"])}
	var outgoing := {"id": str(worn["id"]), "tier": int(worn["tier"]), "torn": bool(worn["torn"]), "slot": slot_key}
	_heroes[hero_index]["parts"][slot_key] = incoming
	_satchel[int(satchel_index)] = outgoing
	_version += 1
	var after := read_state()
	return {
		"ok": true,
		"error": "",
		"action": "swap",
		"node_id": _node_id,
		"hero_id": str(hero_id),
		"slot": slot_key,
		"satchel_index": int(satchel_index),
		"worn_before": before["heroes"][hero_index]["parts"][slot_key],
		"worn_after": incoming.duplicate(true),
		"satchel_before": before["satchel"][int(satchel_index)],
		"satchel_after": outgoing.duplicate(true),
		"changed_heroes": [after["heroes"][hero_index]],
		"satchel": after["satchel"],
		"source_state": before,
		"state": after,
	}


## Directly exchanges the intact parts two DIFFERENT living heroes wear in the same slot. Each
## original {id, tier, torn} record goes, unchanged, to the other wearer: no empty slot, satchel
## change, gold/scrap, HP/fray/rank change or RNG. Uses the same node/snapshot gate and advances
## the version exactly once; any refusal changes nothing.
func exchange_worn(hero_a_id: Variant, hero_b_id: Variant, slot: Variant, expected_node_id: Variant, expected_state: Variant) -> Dictionary:
	var gate := _gate(expected_node_id, expected_state)
	if not gate.is_empty():
		return _fail(gate)
	if typeof(hero_a_id) != TYPE_STRING or typeof(hero_b_id) != TYPE_STRING or typeof(slot) != TYPE_STRING:
		return _fail("hero ids and slot must be strings")
	if str(hero_a_id) == str(hero_b_id):
		return _fail("an exchange needs two different heroes")
	if not str(slot) in StitchedParts.SLOTS:
		return _fail("unknown slot: " + str(slot))
	var index_a := -1
	var index_b := -1
	for index in range(_heroes.size()):
		if str(_heroes[index]["id"]) == str(hero_a_id):
			index_a = index
		elif str(_heroes[index]["id"]) == str(hero_b_id):
			index_b = index
	if index_a < 0:
		return _fail("unknown hero: " + str(hero_a_id))
	if index_b < 0:
		return _fail("unknown hero: " + str(hero_b_id))
	if _is_lost(_heroes[index_a]) or _is_lost(_heroes[index_b]):
		return _fail("hero is lost")
	var slot_key := str(slot)
	var worn_a: Dictionary = _heroes[index_a]["parts"][slot_key]
	var worn_b: Dictionary = _heroes[index_b]["parts"][slot_key]
	if bool(worn_a["torn"]) or bool(worn_b["torn"]):
		return _fail("worn part is torn: mend it before exchanging it")
	var before := read_state()
	var record_a := {"id": str(worn_a["id"]), "tier": int(worn_a["tier"]), "torn": bool(worn_a["torn"])}
	var record_b := {"id": str(worn_b["id"]), "tier": int(worn_b["tier"]), "torn": bool(worn_b["torn"])}
	_heroes[index_a]["parts"][slot_key] = record_b.duplicate(true)
	_heroes[index_b]["parts"][slot_key] = record_a.duplicate(true)
	_version += 1
	var after := read_state()
	return {
		"ok": true,
		"error": "",
		"action": "exchange_worn",
		"node_id": _node_id,
		"slot": slot_key,
		"hero_a_id": str(hero_a_id),
		"hero_b_id": str(hero_b_id),
		"worn_before": {str(hero_a_id): record_a.duplicate(true), str(hero_b_id): record_b.duplicate(true)},
		"worn_after": {str(hero_a_id): record_b.duplicate(true), str(hero_b_id): record_a.duplicate(true)},
		"changed_heroes": [after["heroes"][index_a], after["heroes"][index_b]],
		"satchel": after["satchel"],
		"source_state": before,
		"state": after,
	}


## Ends the visit without changing any equipment.
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
		"satchel": after["satchel"],
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


## Only a native boolean lost == true is LOST (same rule as the mend and upgrade services);
## HP 0 or Hanging is not LOST.
func _is_lost(hero: Dictionary) -> bool:
	return typeof(hero.get("lost")) == TYPE_BOOL and bool(hero["lost"])


func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "state": read_state()}


const COMPARISON_FIELDS := ["name", "launch", "target", "target_side", "dmg", "acc", "crit", "effects", "self_move"]


## Before/after projection for one offer: the worn and incoming abilities at their actual tiers
## plus the signed stat change (incoming minus worn; a missing key counts as 0; unchanged keys omitted).
## Everything is a fresh deep copy derived from the two part summaries.
func _comparison(worn_summary: Dictionary, offer_summary: Dictionary) -> Dictionary:
	var stat_delta: Dictionary = {}
	var worn_stat: Dictionary = worn_summary["stat"]
	var offer_stat: Dictionary = offer_summary["stat"]
	var keys: Dictionary = {}
	for key in worn_stat:
		keys[key] = true
	for key in offer_stat:
		keys[key] = true
	for key in keys:
		var delta := int(offer_stat.get(key, 0)) - int(worn_stat.get(key, 0))
		if delta != 0:
			stat_delta[str(key)] = delta
	return {
		"ability_before": _ability_view(worn_summary["ability"]),
		"ability_after": _ability_view(offer_summary["ability"]),
		"stat_delta": stat_delta,
	}


func _ability_view(ability: Dictionary) -> Dictionary:
	var view: Dictionary = {}
	for field in COMPARISON_FIELDS:
		if ability.has(field):
			var value: Variant = ability[field]
			view[field] = value.duplicate(true) if (value is Array or value is Dictionary) else value
	return view


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
		"ability": ability.duplicate(true),
		"stat": StitchedParts.stat_at_tier(entry, tier),
		"text": str(entry["text"]),
	}


func _setup(node_id: Variant, heroes: Variant, satchel: Variant, catalog_by_id: Variant) -> String:
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
			var result := _normalize(raw["parts"].get(slot), slot, false)
			if not bool(result["ok"]):
				return "hero %s %s: %s" % [hero_id, slot, str(result["error"])]
			parts[slot] = result["part"]
		if raw["parts"].size() != StitchedParts.SLOTS.size():
			return "hero %s has an unknown slot" % hero_id
		hero["parts"] = parts
		clean_heroes.append(hero)
	if not satchel is Array or satchel.size() > SATCHEL_CAP:
		return "satchel holds at most %d parts" % SATCHEL_CAP
	var clean_satchel: Array = []
	for raw_spare in satchel:
		if not raw_spare is Dictionary or typeof(raw_spare.get("slot")) != TYPE_STRING:
			return "satchel record needs a slot"
		var spare_result := _normalize(raw_spare, str(raw_spare["slot"]), true)
		if not bool(spare_result["ok"]):
			return "satchel: " + str(spare_result["error"])
		clean_satchel.append(spare_result["part"])
	_heroes = clean_heroes
	_satchel = clean_satchel
	_node_id = str(node_id)
	return ""


## Validates one part record against the catalog and returns the normalised shape:
## worn {id, tier, torn}; satchel {id, tier, torn, slot}.
func _normalize(raw: Variant, slot: String, with_slot: bool) -> Dictionary:
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
	var part := {"id": str(raw["id"]), "tier": int(tier), "torn": bool(raw["torn"])}
	if with_slot:
		part["slot"] = slot
	return {"ok": true, "error": "", "part": part}
