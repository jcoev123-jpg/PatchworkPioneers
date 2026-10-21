class_name RunTornMending
extends RefCounted
## M04 scene-free run transaction. A future run owner supplies actual combat
## start/end snapshots, visit receipts and its authoritative scrap balance.
## This service neither owns a purse nor admits the next CombatParty (the
## existing M03 carryover still requires each hero's original maximum HP).

const STARTING_HP := {"warden": 40, "seamstress": 30, "tinker": 26}
const PARTY_SIZE := 3
const TEAR_LOSS := 3
const MIN_MAX_HP := 10
const MEND_COST := 2

var _heroes: Array = []
var _tear_counts: Dictionary = {}
var _battles: Dictionary = {}
var _used_nodes: Dictionary = {}
var _mend_receipts: Array[String] = []
var _rest_nodes: Array[String] = []
var _valid := false
var _defeated := false


func _init(initial_heroes: Variant = null) -> void:
	if not _valid_roster(initial_heroes) or not _is_starter(initial_heroes):
		return
	_heroes = initial_heroes.duplicate(true)
	for hero in _heroes:
		_tear_counts[hero["id"]] = 0
	_valid = true


func is_valid() -> bool:
	return _valid


func read_state() -> Dictionary:
	if not _valid:
		return {"ok": false, "heroes": [], "tear_counts": {},
			"completed_battles": [], "completed_mends": [], "completed_rests": [],
			"defeated": false}
	return {"ok": true, "heroes": _heroes.duplicate(true),
		"tear_counts": _tear_counts.duplicate(true),
		"completed_battles": _battles.keys().duplicate(),
		"completed_mends": _mend_receipts.duplicate(),
		"completed_rests": _rest_nodes.duplicate(),
		"defeated": _defeated}


## Accept one genuine battle's start and end observations. The start must
## match the held run state except for opening combat Block; an actor cannot
## change ID, slot or max HP in combat, or revive during a battle. End-of-
## battle statuses are retained; Block is discarded at the node boundary.
## Exact repeat observations are idempotent, but a reused node carrying a
## different observation is stale and refused.
func observe_battle_end(node_id: Variant, battle_start: Variant, battle_end: Variant) -> Dictionary:
	if not _valid or _defeated or not _valid_id(node_id):
		return _rejected()
	if _battles.has(node_id):
		var previous: Dictionary = _battles[node_id]
		if previous["start"] == battle_start and previous["end"] == battle_end:
			return _accepted()
		return _rejected()
	if _used_nodes.has(node_id) or not _valid_roster(battle_start) or not _valid_roster(battle_end):
		return _rejected()
	for i in range(PARTY_SIZE):
		var held: Dictionary = _heroes[i]
		var starting: Dictionary = battle_start[i]
		var ending: Dictionary = battle_end[i]
		var expected_start: Dictionary = held.duplicate(true)
		expected_start["block"] = starting["block"]
		if starting != expected_start:
			return _rejected()
		if ending["id"] != held["id"] or ending["position"] != held["position"]:
			return _rejected()
		if ending["max_hp"] != held["max_hp"]:
			return _rejected()
		if starting["hp"] == 0 and ending["hp"] != 0:
			return _rejected()
	var next_heroes: Array = battle_end.duplicate(true)
	var next_counts := _tear_counts.duplicate(true)
	var any_living := false
	for i in range(PARTY_SIZE):
		var hero: Dictionary = next_heroes[i]
		if battle_start[i]["hp"] > 0 and hero["hp"] == 0:
			hero["max_hp"] = maxi(MIN_MAX_HP, int(hero["max_hp"]) - TEAR_LOSS)
			next_counts[hero["id"]] += 1
		hero["block"] = 0
		if hero["hp"] > 0:
			any_living = true
	_heroes = next_heroes
	_tear_counts = next_counts
	_defeated = not any_living
	_battles[node_id] = {"start": battle_start.duplicate(true), "end": battle_end.duplicate(true)}
	_used_nodes[node_id] = true
	return _accepted()


## Map-only atomic proposal: the eventual purse owner must commit returned
## remaining_scraps and heroes together, and call only with a fresh receipt.
## expected_heroes is an optimistic concurrency guard against stale choices.
## Failed proposals never spend scraps, consume a receipt or alter held state.
func choose_mend(node_id: Variant, receipt_id: Variant, hero_id: Variant,
		position: Variant, available_scraps: Variant, expected_heroes: Variant,
		between_nodes: Variant) -> Dictionary:
	if not _valid or _defeated or between_nodes is not bool or not between_nodes:
		return _mend_rejected(available_scraps)
	if not _valid_id(node_id) or not _valid_id(receipt_id):
		return _mend_rejected(available_scraps)
	if _used_nodes.has(node_id) or _mend_receipts.has(receipt_id):
		return _mend_rejected(available_scraps)
	if typeof(available_scraps) != TYPE_INT or available_scraps < MEND_COST:
		return _mend_rejected(available_scraps)
	if not _valid_id(hero_id) or typeof(position) != TYPE_INT:
		return _mend_rejected(available_scraps)
	if not _valid_roster(expected_heroes) or expected_heroes != _heroes:
		return _mend_rejected(available_scraps)
	if position < 1 or position > PARTY_SIZE:
		return _mend_rejected(available_scraps)
	var candidate: Dictionary = _heroes[position - 1]
	if candidate["id"] != hero_id or candidate["hp"] != 0:
		return _mend_rejected(available_scraps)
	var next_heroes: Array = _heroes.duplicate(true)
	@warning_ignore("integer_division")
	next_heroes[position - 1]["hp"] = maxi(1, int(candidate["max_hp"]) / 4)
	_heroes = next_heroes
	_used_nodes[node_id] = true
	_mend_receipts.append(receipt_id)
	return {"ok": true, "heroes": _heroes.duplicate(true),
		"remaining_scraps": available_scraps - MEND_COST}


## This is only an application path for the *actual* Rest choice; do not
## replicate its revive-at-one or floor(30%) rule here.
func apply_rest(node_id: Variant, expected_heroes: Variant, between_nodes: Variant) -> Dictionary:
	if not _valid or _defeated or between_nodes is not bool or not between_nodes:
		return _rejected()
	if not _valid_id(node_id) or _used_nodes.has(node_id):
		return _rejected()
	if not _valid_roster(expected_heroes) or expected_heroes != _heroes:
		return _rejected()
	var visit := RunRestRecovery.new(_heroes)
	var recovered: Dictionary = visit.choose_heal()
	if recovered.get("ok") != true:
		return _rejected()
	if not _valid_roster(recovered.get("heroes")) or not _same_owners(recovered["heroes"]):
		return _rejected()
	_heroes = recovered["heroes"].duplicate(true)
	_used_nodes[node_id] = true
	_rest_nodes.append(node_id)
	return _accepted()


func _same_owners(proposed: Array) -> bool:
	for i in range(PARTY_SIZE):
		var expected: Dictionary = _heroes[i].duplicate(true)
		expected["hp"] = proposed[i]["hp"]
		if proposed[i] != expected:
			return false
	return true


func _accepted() -> Dictionary:
	return {"ok": true, "heroes": _heroes.duplicate(true)}


static func _rejected() -> Dictionary:
	return {"ok": false, "heroes": []}


static func _mend_rejected(available_scraps: Variant) -> Dictionary:
	return {"ok": false, "heroes": [], "remaining_scraps": available_scraps}


static func _valid_id(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not value.is_empty() and value == value.strip_edges()


static func _valid_roster(roster: Variant) -> bool:
	if typeof(roster) != TYPE_ARRAY or roster.size() != PARTY_SIZE:
		return false
	var ids: Dictionary = {}
	for i in range(PARTY_SIZE):
		var hero: Variant = roster[i]
		if typeof(hero) != TYPE_DICTIONARY or not _valid_id(hero.get("id")):
			return false
		if ids.has(hero["id"]):
			return false
		ids[hero["id"]] = true
		for field in ["position", "hp", "max_hp", "block"]:
			if typeof(hero.get(field)) != TYPE_INT:
				return false
		if hero["position"] != i + 1 or hero["max_hp"] < MIN_MAX_HP:
			return false
		if hero["hp"] < 0 or hero["hp"] > hero["max_hp"] or hero["block"] < 0:
			return false
		var statuses: Variant = hero.get("statuses", {})
		if typeof(statuses) != TYPE_DICTIONARY:
			return false
		for status in statuses:
			if typeof(status) != TYPE_STRING or status not in ["bleed", "weak", "exposed"]:
				return false
			if typeof(statuses[status]) != TYPE_INT or statuses[status] < 0:
				return false
	return true


static func _is_starter(heroes: Array) -> bool:
	for i in range(PARTY_SIZE):
		var hero: Dictionary = heroes[i]
		if hero["id"] != ["warden", "seamstress", "tinker"][i]:
			return false
		if hero["max_hp"] != STARTING_HP[hero["id"]]:
			return false
		if hero["hp"] != hero["max_hp"] or hero["block"] != 0:
			return false
	return true
