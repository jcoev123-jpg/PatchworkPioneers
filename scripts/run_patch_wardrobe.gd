class_name RunPatchWardrobe
extends RefCounted
## M04 scene-free patch ledger; not wired to the M03 Shop or combat powers.
## The supplied definitions are authored fixture metadata: [{"id", "slot"}].
## Unrecognized owned Shop trinkets remain owned but cannot be sewn until
## their actual slot is authored. The caller confirms Rest entry/exit.
##
## Every mutator requires the EXACT get_snapshot() of the current ledger as
## an optimistic-concurrency guard and a fresh operation ID. Rejections do
## not spend, reserve IDs, or return success receipts.

const SLOTS := ["HEAD", "ARM", "COAT"]
const STARTING_HP := {"warden": 40, "seamstress": 30, "tinker": 26}
const HERO_IDS := ["warden", "seamstress", "tinker"]
const MAX_INT := 9223372036854775807

var _valid := false
var _heroes: Array = []
var _owned: Array = []
var _definitions: Dictionary = {}
var _worn: Dictionary = {}
var _scraps := 0
var _gold := 0
var _cards: Array = []
var _seed := 0
var _rest_id := ""
var _rest_ids: Array[String] = []
var _operations: Array[String] = []


func _init(heroes: Variant = null, owned_trinket_ids: Variant = null,
		patch_definitions: Variant = null, scraps: Variant = null,
		gold: Variant = 0, cards: Variant = [], run_seed: Variant = 0,
		current_run: bool = false) -> void:
	if not _valid_roster(heroes, not current_run) or typeof(owned_trinket_ids) != TYPE_ARRAY:
		return
	if typeof(patch_definitions) != TYPE_ARRAY or typeof(scraps) != TYPE_INT or scraps < 0:
		return
	if typeof(gold) != TYPE_INT or gold < 0 or typeof(run_seed) != TYPE_INT:
		return
	if typeof(cards) != TYPE_ARRAY:
		return
	var seen_owned := {}
	for id in owned_trinket_ids:
		if not _id(id) or seen_owned.has(id):
			return
		seen_owned[id] = true
	for card in cards:
		if not _id(card):
			return
	var parsed := {}
	for value in patch_definitions:
		if typeof(value) != TYPE_DICTIONARY:
			return
		if value.size() != 2 or not value.has("id") or not value.has("slot"):
			return
		var id: Variant = value["id"]
		var slot: Variant = value["slot"]
		if not _id(id) or typeof(slot) != TYPE_STRING or not SLOTS.has(slot) or parsed.has(id):
			return
		parsed[id] = slot
	_heroes = heroes.duplicate(true)
	_owned = owned_trinket_ids.duplicate(true)
	_definitions = parsed.duplicate(true)
	_scraps = scraps
	_gold = gold
	_cards = cards.duplicate(true)
	_seed = run_seed
	for hero in _heroes:
		_worn[hero.id] = {"HEAD": "", "ARM": "", "COAT": ""}
	_valid = true


func is_valid() -> bool:
	return _valid


## The run owner supplies newly committed context, never a pending reward.
## Refresh is atomic and retains worn slots and operation receipts.
func refresh_run_context(heroes: Variant, owned: Variant, scraps: Variant,
		gold: Variant, cards: Variant, expected: Variant) -> bool:
	if not _matches(expected):
		return false
	var candidate := RunPatchWardrobe.new(heroes, owned, _definition_records(),
		scraps, gold, cards, _seed, true)
	if not candidate.is_valid():
		return false
	for id in _owned:
		if not candidate._owned.has(id):
			return false
	_heroes = candidate._heroes
	_owned = candidate._owned
	_scraps = candidate._scraps
	_gold = candidate._gold
	_cards = candidate._cards
	return true


func _definition_records() -> Array:
	var records := []
	for id in _definitions:
		records.append({"id": id, "slot": _definitions[id]})
	return records


## Detached state includes the full unchanged non-patch run context, Rest
## context and claim history. A receipt commits to every visible field.
func get_snapshot() -> Dictionary:
	var state := {
		"valid": _valid,
		"heroes": _heroes.duplicate(true),
		"owned": _owned.duplicate(true),
		"definitions": _definitions.duplicate(true),
		"worn": _worn.duplicate(true),
		"scraps": _scraps,
		"gold": _gold,
		"cards": _cards.duplicate(true),
		"seed": _seed,
		"rest_id": _rest_id,
		"rest_ids": _rest_ids.duplicate(),
		"operation_ids": _operations.duplicate(),
	}
	state["receipt"] = JSON.stringify([
		state["valid"], state["heroes"], state["owned"],
		_definition_entries(), state["worn"], state["scraps"],
		state["gold"], state["cards"], state["seed"], state["rest_id"],
		state["rest_ids"], state["operation_ids"]
	]).sha256_text()
	return state


func _definition_entries() -> Array:
	var ids: Array = _definitions.keys()
	ids.sort()
	var result := []
	for id in ids:
		result.append([id, _definitions[id]])
	return result


func _matches(expected: Variant) -> bool:
	return _valid and typeof(expected) == TYPE_DICTIONARY and expected == get_snapshot()


## Sewing is free and assigns an owned, unworn patch to an exact authored
## slot. The displaced patch is destroyed from ownership for exactly 1 scrap.
func sew(patch_id: Variant, hero_id: Variant, slot: Variant,
		operation_id: Variant, expected_snapshot: Variant) -> Dictionary:
	if not _matches(expected_snapshot) or not _fresh(operation_id):
		return _result(false)
	if not _id(patch_id) or not _id(hero_id) or typeof(slot) != TYPE_STRING:
		return _result(false)
	if not _worn.has(hero_id) or not _owned.has(patch_id):
		return _result(false)
	if _definitions.get(patch_id) != slot or not SLOTS.has(slot):
		return _result(false)
	if _find_wearer(patch_id) != "":
		return _result(false)
	var displaced: String = _worn[hero_id][slot]
	if displaced != "" and (_scraps == MAX_INT or not _owned.has(displaced)):
		return _result(false)
	_worn[hero_id][slot] = patch_id
	if displaced != "":
		_owned.erase(displaced)
		_scraps += 1
	_operations.append(operation_id)
	return _result(true, {"operation_id": operation_id, "kind": "sew",
		"patch_id": patch_id, "hero_id": hero_id, "slot": slot,
		"displaced_id": displaced, "scrap_delta": 1 if displaced != "" else 0})


## Rest context is externally confirmed; opening it does not choose Rest
## heal, upgrade, stitch or consume the one choice. Reused nodes are denied.
func start_rest(rest_node_id: Variant, expected_snapshot: Variant) -> Dictionary:
	if not _matches(expected_snapshot) or not _id(rest_node_id) or _rest_id != "":
		return _result(false)
	if _rest_ids.has(rest_node_id):
		return _result(false)
	_rest_id = rest_node_id
	_rest_ids.append(rest_node_id)
	return _result(true, {"kind": "start_rest", "rest_node_id": rest_node_id})


func end_rest(rest_node_id: Variant, expected_snapshot: Variant) -> Dictionary:
	if not _matches(expected_snapshot) or not _id(rest_node_id) or _rest_id != rest_node_id:
		return _result(false)
	_rest_id = ""
	return _result(true, {"kind": "end_rest", "rest_node_id": rest_node_id})


## One paid transaction per fresh operation ID, not per Rest choice.
## An occupied recipient slot swaps its patch onto the former wearer.
## Neither path changes any slot other than the two same-named slots.
func re_sew(patch_id: Variant, from_hero: Variant, to_hero: Variant,
		rest_node_id: Variant, operation_id: Variant,
		expected_snapshot: Variant) -> Dictionary:
	if not _matches(expected_snapshot) or not _fresh(operation_id):
		return _result(false)
	if not _id(patch_id) or not _id(from_hero) or not _id(to_hero) or not _id(rest_node_id):
		return _result(false)
	if _rest_id == "" or _rest_id != rest_node_id or from_hero == to_hero or _scraps < 1:
		return _result(false)
	if not _worn.has(from_hero) or not _worn.has(to_hero) or not _owned.has(patch_id):
		return _result(false)
	var slot: Variant = _definitions.get(patch_id)
	if typeof(slot) != TYPE_STRING or not SLOTS.has(slot):
		return _result(false)
	if _worn[from_hero][slot] != patch_id:
		return _result(false)
	var exchanged: String = _worn[to_hero][slot]
	if exchanged != "" and (not _owned.has(exchanged) or _definitions.get(exchanged) != slot):
		return _result(false)
	_worn[to_hero][slot] = patch_id
	_worn[from_hero][slot] = exchanged
	_scraps -= 1
	_operations.append(operation_id)
	return _result(true, {"operation_id": operation_id, "kind": "re_sew",
		"patch_id": patch_id, "from_hero": from_hero,
		"to_hero": to_hero, "slot": slot,
		"exchanged_id": exchanged, "scrap_delta": -1,
		"rest_node_id": rest_node_id})


## Read-only eligibility against a genuine RunTornMending.read_state()
## snapshot supplied by the run owner. No invented patch effects/buffs.
## Assignments always remain visible; hp==0 only masks active IDs.
func project_active(torn_state: Variant) -> Dictionary:
	var rejected := {"ok": false, "worn": {}, "active": {}}
	if not _valid or typeof(torn_state) != TYPE_DICTIONARY or torn_state.get("ok") != true:
		return rejected
	var heroes: Variant = torn_state.get("heroes")
	if not _valid_roster(heroes, false):
		return rejected
	var active := {}
	for hero in heroes:
		var hero_id: String = hero["id"]
		var equipped: Array = []
		if hero["hp"] > 0:
			for slot in SLOTS:
				var patch_id: String = _worn[hero_id][slot]
				if patch_id != "":
					equipped.append(patch_id)
		active[hero_id] = equipped
	return {"ok": true, "worn": _worn.duplicate(true),
		"active": active.duplicate(true)}


func _find_wearer(patch_id: String) -> String:
	for hero_id in _worn:
		for slot in SLOTS:
			if _worn[hero_id][slot] == patch_id:
				return hero_id
	return ""


func _fresh(id: Variant) -> bool:
	return _id(id) and not _operations.has(id)


func _result(ok: bool, receipt: Dictionary = {}) -> Dictionary:
	var response := {"ok": ok, "state": get_snapshot()}
	if ok:
		response["receipt"] = receipt.duplicate(true)
	return response


static func _id(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not value.is_empty() and value == value.strip_edges()


static func _valid_roster(heroes: Variant, require_starter: bool) -> bool:
	if typeof(heroes) != TYPE_ARRAY or heroes.size() != 3:
		return false
	var seen := {}
	for i in range(3):
		var hero: Variant = heroes[i]
		if typeof(hero) != TYPE_DICTIONARY or not _id(hero.get("id")):
			return false
		var hero_id: String = hero["id"]
		if not hero_id in RunV3PartyAdmission.HERO_IDS or seen.has(hero_id):
			return false
		seen[hero_id] = true
		for field in ["position", "hp", "max_hp", "block"]:
			if typeof(hero.get(field)) != TYPE_INT:
				return false
		if hero["position"] != i + 1 or hero["max_hp"] < 10:
			return false
		if hero["hp"] < 0 or hero["hp"] > hero["max_hp"] or hero["block"] < 0:
			return false
		var statuses: Variant = hero.get("statuses", {})
		if typeof(statuses) != TYPE_DICTIONARY:
			return false
		if require_starter:
			if hero_id != HERO_IDS[i] or hero["max_hp"] != STARTING_HP[hero_id]:
				return false
			if hero["hp"] != hero["max_hp"] or hero["block"] != 0:
				return false
	return CombatStatusTurnBatch.new().tick_side("heroes", heroes).ok
