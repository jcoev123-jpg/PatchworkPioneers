class_name RunTornMending
extends RefCounted
## M04 scene-free run transaction. A future run owner supplies actual combat
## start/end snapshots, visit receipts and its authoritative scrap balance.
## This service neither owns a purse nor admits the next CombatParty (the
## existing M03 carryover still requires each hero's original maximum HP).
## The initial roster may be any canonical trio of the eight authored heroes.

const PARTY_SIZE := 3
const TEAR_LOSS := 3
const MIN_MAX_HP := 10
const MEND_COST := 2

var _heroes: Array = []
var _vital_cap_offsets: Dictionary = {}
var _initial_caps: Dictionary = {}
var _tear_counts: Dictionary = {}
var _battles: Dictionary = {}
var _used_nodes: Dictionary = {}
var _mend_receipts: Array[String] = []
var _vital_nodes: Array[String] = []
var _rest_nodes: Array[String] = []
var _valid := false
var _defeated := false


func _init(initial_heroes: Variant = null) -> void:
	if not _valid_roster(initial_heroes) or not _is_starter(initial_heroes):
		return
	_heroes = initial_heroes.duplicate(true)
	for hero in _heroes:
		_tear_counts[hero["id"]] = 0
		_initial_caps[hero.id] = hero.max_hp
	_valid = true


func is_valid() -> bool:
	return _valid


func read_state() -> Dictionary:
	if not _valid:
		return {"ok": false, "heroes": [], "tear_counts": {},
			"completed_battles": [], "completed_mends": [], "completed_rests": [], "completed_vital_events": [], "vital_cap_offsets": {},
			"defeated": false}
	return {"ok": true, "heroes": _heroes.duplicate(true),
		"vital_cap_offsets": _vital_cap_offsets.duplicate(),
		"tear_counts": _tear_counts.duplicate(true),
		"completed_battles": _battles.keys().duplicate(),
		"completed_mends": _mend_receipts.duplicate(),
		"completed_rests": _rest_nodes.duplicate(),
		"completed_vital_events": _vital_nodes.duplicate(),
		"defeated": _defeated}


## Accept one genuine battle's start and end observations. The start must
## match the held run state except for opening combat Block. Heroes may
## change slots during combat, but their unique IDs and max HP stay attached
## to the same actor, and a downed hero cannot revive. End-of-battle statuses
## are retained; Block is discarded at the node boundary.
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
	var starting_by_id: Dictionary = {}
	for i in range(PARTY_SIZE):
		var held: Dictionary = _heroes[i]
		var starting: Dictionary = battle_start[i]
		var expected_start: Dictionary = held.duplicate(true)
		expected_start["block"] = starting["block"]
		if starting != expected_start:
			return _rejected()
		starting_by_id[starting["id"]] = starting
	# Both rosters have exactly three distinct IDs and positions 1..3.
	# Membership against the witnessed start permits only a whole-party
	# permutation, never a foreign/duplicated actor or an invented slot.
	for ending in battle_end:
		var hero_id: String = ending["id"]
		if not starting_by_id.has(hero_id):
			return _rejected()
		var starting: Dictionary = starting_by_id[hero_id]
		if ending["max_hp"] != starting["max_hp"]:
			return _rejected()
		if starting["hp"] == 0 and ending["hp"] != 0:
			return _rejected()
	var next_heroes: Array = battle_end.duplicate(true)
	var next_counts := _tear_counts.duplicate(true)
	var any_living := false
	for hero in next_heroes:
		var prior: Dictionary = starting_by_id[hero["id"]]
		if prior["hp"] > 0 and hero["hp"] == 0:
			hero["max_hp"] = maxi(MIN_MAX_HP, int(hero["max_hp"]) - TEAR_LOSS)
			next_counts[hero["id"]] += 1
		hero["block"] = 0
		if hero["hp"] > 0:
			any_living = true
	_heroes = next_heroes
	_tear_counts = next_counts
	_refresh_vital_cap_offsets()
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


## Recompute the authored claim against the first living actor and exact ledger.
func apply_vital_event(node: Variant, record: Dictionary, receipt: Dictionary,
		snapshot: Dictionary, expected: Dictionary) -> Dictionary:
	if not _valid or _defeated or expected != read_state() or not _valid_id(node) \
		or _used_nodes.has(node):
		return _rejected()
	var target := -1
	for index in range(_heroes.size()):
		if _heroes[index].hp > 0:
			target = index
			break
	if target < 0:
		return _rejected()
	var hero: Dictionary = _heroes[target]
	if snapshot.get("hero") != {"id": hero.id, "hp": hero.hp, "max_hp": hero.max_hp}:
		return _rejected()
	var claim := RunEventChoice.new(record).choose_with_vitals(receipt.get("choice_id"), snapshot)
	if not claim.ok or claim != receipt:
		return _rejected()
	_heroes[target].hp = claim.state.hero.hp
	_heroes[target].max_hp = claim.state.hero.max_hp
	_used_nodes[node] = true
	_vital_nodes.append(node)
	_refresh_vital_cap_offsets()
	return _accepted()


## Keep cap evidence independent of read_state so a tampered hero cannot
## authenticate its own cap. Recompute only after accepted cap transactions.
func _refresh_vital_cap_offsets() -> void:
	if _vital_nodes.is_empty():
		return
	for hero in _heroes:
		var count: int = _tear_counts[hero.id]
		var starting: int = _initial_caps[hero.id]
		var threshold := ceili(float(starting - MIN_MAX_HP) / TEAR_LOSS)
		var torn_cap: int = MIN_MAX_HP if count >= threshold else starting - count * TEAR_LOSS
		_vital_cap_offsets[hero.id] = hero.max_hp - torn_cap


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


## An admitted canonical trio in its default-position order, at full authored HP.
static func _is_starter(heroes: Array) -> bool:
	if RunPartyCarryover.canonical_caps(heroes, true).is_empty():
		return false
	for hero in heroes:
		if hero["hp"] != hero["max_hp"] or hero["block"] != 0:
			return false
	return true
