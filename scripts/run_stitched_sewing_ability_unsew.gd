class_name RunStitchedSewingAbilityUnsew
extends RefCounted
## Scene-free S14 Sewing Circle service: unsew one sewn ability-effect patch from a hero's own
## fixed signature ability while the very same owned patch stays in the ability inventory.
##
## Admitted data (all deep-copied, nothing aliases the caller):
##   node_id        nonempty, whitespace-normalized Sewing Circle node id
##   hero_ids       exactly four distinct owned hero ids (StitchedPartyAdmission.HERO_IDS)
##   inventory      [{"uid": positive int, "id": authored patch id, "rarity": the catalog rarity}]
##   sockets        {hero_id: {ability_id: [uid, ...]}}; every uid owned and sewn at most once, and
##                  each hero loadout (mapped uid -> patch id) passes StitchedS14Abilities.valid_loadout
## There is NO price: this service never touches scraps, gold, parts or any RNG. unsew() releases a
## patch (it stays owned) and sew() binds an owned, unbound patch onto a legal signature; several
## operations may follow in one open
## visit; leave() ends it. Every mutation must present the node id and the exact state last
## published (read_state() or the previous receipt's "state"); a refusal changes nothing.
## Live wiring (run session, journal, save) is a later task; nothing here touches the live run.

const PARTY_SIZE := 4

var _node_id := ""
var _hero_ids: Array = []
var _inventory: Array = []
var _sockets: Dictionary = {}
var _source: Dictionary = {}
var _open := true
var _version := 0
var _error := ""


func _init(node_id: Variant = "", hero_ids: Variant = [], inventory: Variant = [], sockets: Variant = {}) -> void:
	_error = _setup(node_id, hero_ids, inventory, sockets)
	if not _error.is_empty():
		_open = false
		return
	_source = _body()


## The authoritative snapshot (deep copy). Pass it back as expected_state.
func read_state() -> Dictionary:
	if not _error.is_empty():
		return {"ok": false, "error": _error}
	var state := _body()
	state["ok"] = true
	return state


func unsew(hero_id: Variant, ability_id: Variant, uid: Variant, expected_node_id: Variant, expected_state: Variant) -> Dictionary:
	var gate := _gate(expected_node_id, expected_state)
	if not gate.is_empty():
		return _fail(gate)
	if typeof(hero_id) != TYPE_STRING or typeof(ability_id) != TYPE_STRING or typeof(uid) != TYPE_INT:
		return _fail("hero id and ability id must be strings and uid an integer")
	var hero_key: String = hero_id
	var ability_key: String = ability_id
	var uid_value: int = uid
	if not hero_key in _hero_ids:
		return _fail("unknown hero: " + hero_key)
	if StitchedS14Abilities.ability(hero_key, ability_key).is_empty():
		return _fail("unknown signature ability for that hero: " + ability_key)
	var item_index := _item_index(uid_value)
	if item_index < 0:
		return _fail("unowned patch uid")
	var bound: Array = _sockets.get(hero_key, {}).get(ability_key, [])
	var position := -1
	for index in range(bound.size()):
		if int(bound[index]) == uid_value:
			position = index
	if position < 0:
		return _fail("that patch is not sewn on this signature")
	var before := read_state()
	var item: Dictionary = _inventory[item_index].duplicate(true)
	var remaining: Array = bound.duplicate()
	remaining.remove_at(position)
	var candidate: Dictionary = _sockets.duplicate(true)
	candidate[hero_key][ability_key] = remaining
	if not _loadout_ok(hero_key, candidate[hero_key]):
		return _fail("resulting loadout is invalid")
	_sockets = candidate
	_version += 1
	var after := read_state()
	if JSON.stringify(after.get("inventory"), "", true) != JSON.stringify(_source.get("inventory"), "", true):
		return _fail("inventory drifted from its source snapshot")
	return {
		"ok": true,
		"error": "",
		"action": "unsew",
		"node_id": _node_id,
		"hero_id": hero_key,
		"ability_id": ability_key,
		"uid": uid_value,
		"item": item,
		"sockets_before": before["sockets"][hero_key][ability_key].duplicate(),
		"sockets_after": after["sockets"][hero_key][ability_key].duplicate(),
		"source_state": before,
		"state": after,
	}


## Sews one owned, currently unbound patch onto one party hero's real signature ability. A patch that is
## still bound anywhere must first be released with unsew(). The inventory record is never touched.
func sew(hero_id: Variant, ability_id: Variant, uid: Variant, expected_node_id: Variant, expected_state: Variant) -> Dictionary:
	var gate := _gate(expected_node_id, expected_state)
	if not gate.is_empty():
		return _fail(gate)
	if typeof(hero_id) != TYPE_STRING or typeof(ability_id) != TYPE_STRING or typeof(uid) != TYPE_INT:
		return _fail("hero id and ability id must be strings and uid an integer")
	var hero_key: String = hero_id
	var ability_key: String = ability_id
	var uid_value: int = uid
	if not hero_key in _hero_ids:
		return _fail("unknown hero: " + hero_key)
	if StitchedS14Abilities.ability(hero_key, ability_key).is_empty():
		return _fail("unknown signature ability for that hero: " + ability_key)
	var item_index := _item_index(uid_value)
	if item_index < 0:
		return _fail("unowned patch uid")
	for bound_hero in _sockets:
		for bound_ability in _sockets[bound_hero]:
			for bound_uid in _sockets[bound_hero][bound_ability]:
				if int(bound_uid) == uid_value:
					return _fail("that patch is already sewn; unsew it first")
	var before := read_state()
	var item: Dictionary = _inventory[item_index].duplicate(true)
	var candidate: Dictionary = _sockets.duplicate(true)
	if not candidate.has(hero_key):
		candidate[hero_key] = {}
	if not candidate[hero_key].has(ability_key):
		candidate[hero_key][ability_key] = []
	var sockets_before: Array = candidate[hero_key][ability_key].duplicate()
	candidate[hero_key][ability_key].append(uid_value)
	if not _loadout_ok(hero_key, candidate[hero_key]):
		return _fail("no free socket for that patch on this signature")
	_sockets = candidate
	_version += 1
	var after := read_state()
	if JSON.stringify(after.get("inventory"), "", true) != JSON.stringify(_source.get("inventory"), "", true):
		return _fail("inventory drifted from its source snapshot")
	return {
		"ok": true,
		"error": "",
		"action": "sew",
		"node_id": _node_id,
		"hero_id": hero_key,
		"ability_id": ability_key,
		"uid": uid_value,
		"item": item,
		"sockets_before": sockets_before,
		"sockets_after": after["sockets"][hero_key][ability_key].duplicate(),
		"source_state": before,
		"state": after,
	}


## Ends the visit; no binding changes.
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
		"source_state": before,
		"state": after,
	}


func _body() -> Dictionary:
	return {
		"node_id": _node_id,
		"open": _open,
		"version": _version,
		"hero_ids": _hero_ids.duplicate(),
		"inventory": _inventory.duplicate(true),
		"sockets": _sockets.duplicate(true),
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


func _item_index(uid: int) -> int:
	for index in range(_inventory.size()):
		if int(_inventory[index]["uid"]) == uid:
			return index
	return -1


## Maps owned uids to authored patch ids and asks the real S14 rules to validate one hero loadout.
func _loadout_ok(hero_id: String, hero_sockets: Variant) -> bool:
	if not hero_sockets is Dictionary:
		return false
	var mapped := {}
	for ability_id in hero_sockets:
		if not hero_sockets[ability_id] is Array:
			return false
		var ids: Array = []
		for uid in hero_sockets[ability_id]:
			if typeof(uid) != TYPE_INT:
				return false
			var index := _item_index(int(uid))
			if index < 0:
				return false
			ids.append(str(_inventory[index]["id"]))
		mapped[ability_id] = ids
	return StitchedS14Abilities.valid_loadout(hero_id, mapped)


func _setup(node_id: Variant, hero_ids: Variant, inventory: Variant, sockets: Variant) -> String:
	if typeof(node_id) != TYPE_STRING:
		return "node id must be a string"
	var node: String = node_id
	if node.is_empty() or node != node.strip_edges() or node.contains("  "):
		return "node id must be nonempty and whitespace-normalized"
	if not hero_ids is Array or hero_ids.size() != PARTY_SIZE:
		return "exactly four hero ids are required"
	var party: Array = []
	for hero in hero_ids:
		if typeof(hero) != TYPE_STRING or not str(hero) in StitchedPartyAdmission.HERO_IDS or str(hero) in party:
			return "hero ids must be four distinct known heroes"
		party.append(str(hero))
	var catalog := StitchedS14Abilities.patches()
	if catalog.is_empty() or StitchedS14Abilities.kits().is_empty():
		return "S14 catalogs are unavailable"
	if not inventory is Array:
		return "inventory must be an array"
	var items: Array = []
	var owned := {}
	for raw in inventory:
		if not raw is Dictionary or raw.size() != 3 or typeof(raw.get("uid")) != TYPE_INT \
				or typeof(raw.get("id")) != TYPE_STRING or typeof(raw.get("rarity")) != TYPE_STRING:
			return "inventory item must be {uid, id, rarity}"
		var uid: int = raw["uid"]
		var patch_id: String = raw["id"]
		if uid <= 0 or owned.has(uid):
			return "inventory uid must be a unique positive integer"
		if not catalog.by_id.has(patch_id) or str(catalog.by_id[patch_id].rarity) != str(raw["rarity"]):
			return "inventory item is not an authentic patch"
		owned[uid] = true
		items.append({"uid": uid, "id": patch_id, "rarity": str(raw["rarity"])})
	if not sockets is Dictionary:
		return "sockets must be a dictionary"
	var clean := {}
	var used := {}
	for hero in sockets:
		if typeof(hero) != TYPE_STRING or not str(hero) in party or not sockets[hero] is Dictionary:
			return "sockets name an unknown hero"
		var hero_clean := {}
		for ability_id in sockets[hero]:
			var list: Variant = sockets[hero][ability_id]
			if typeof(ability_id) != TYPE_STRING or not list is Array \
					or StitchedS14Abilities.ability(str(hero), str(ability_id)).is_empty():
				return "socket names an unknown signature"
			var uids: Array = []
			for uid in list:
				if typeof(uid) != TYPE_INT or not owned.has(int(uid)) or used.has(int(uid)):
					return "socket uid is unowned or sewn twice"
				used[int(uid)] = true
				uids.append(int(uid))
			hero_clean[str(ability_id)] = uids
		clean[str(hero)] = hero_clean
	_node_id = node
	_hero_ids = party
	_inventory = items
	_sockets = clean
	for hero in clean:
		if not _loadout_ok(str(hero), clean[hero]):
			_node_id = ""
			_hero_ids = []
			_inventory = []
			_sockets = {}
			return "mounted sockets are not a valid loadout"
	return ""
