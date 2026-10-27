class_name RunPartyCarryover
extends RefCounted
## Scene-free persistence between run nodes. Initialize from a detached
## CombatParty.get_heroes() snapshot. A next-fight party can be hydrated:
## the live run-entry integration must call this at Fight entry.
##
## read_state() returns {"ok", "heroes", "completed_fights", "completed_rests"};
## get_next_fight_heroes() returns a detached, Block-free Array;
## commit_victory(node_id, evaluated_result, authoritative_party) and
## choose_rest_heal(node_id) return {"ok", "heroes"} (empty on rejection).
## A node is recorded only after its entire transaction succeeds.

const PARTY_SIZE := 3

var _heroes: Array = []
var _max_hp_by_id: Dictionary = {}
## Authored caps of the initial trio, fixed at construction; {} when that trio is
## not an admitted canonical lineup. Next-fight hydration is anchored to it.
var _admitted_caps: Dictionary = {}
var _fight_ids: Array[String] = []
var _rest_ids: Array[String] = []
var _valid := false


func _init(initial_heroes: Variant = null) -> void:
	if typeof(initial_heroes) != TYPE_ARRAY:
		return
	if not _valid_roster(initial_heroes, true):
		return
	_heroes = initial_heroes.duplicate(true)
	for hero in _heroes:
		_max_hp_by_id[hero["id"]] = hero["max_hp"]
		hero["block"] = 0
	_admitted_caps = canonical_caps(_heroes, false)
	_valid = true


func is_valid() -> bool:
	return _valid


func read_state() -> Dictionary:
	if not _valid:
		return {"ok": false, "heroes": [], "completed_fights": [], "completed_rests": []}
	return {"ok": true, "heroes": _heroes.duplicate(true),
		"completed_fights": _fight_ids.duplicate(),
		"completed_rests": _rest_ids.duplicate()}


func get_next_fight_heroes() -> Array:
	if not _valid:
		return []
	return _heroes.duplicate(true)


## Restore a detached live party from initial carry, a witnessed victory or recorded Rest. Construct a
## canonical CombatParty first, then replace its full-HP actor snapshots.
## The one-shot Warden Block belongs to later combat startup, never transit.
func create_next_fight_party() -> CombatParty:
	if not _valid or not _valid_roster(_heroes, true) or not _same_identities(_heroes):
		return null
	if _admitted_caps.is_empty() or _max_hp_by_id.size() != _admitted_caps.size():
		return null
	for hero_id in _admitted_caps:
		if _max_hp_by_id.get(hero_id) != _admitted_caps[hero_id]:
			return null
	var persisted: Array = _heroes.duplicate(true)
	for hero in persisted:
		if hero["block"] != 0:
			return null
	var party := CombatParty.new(persisted)
	if not party.is_valid():
		return null
	party._heroes.assign(persisted.duplicate(true))
	return party


## A result must have *already* witnessed VICTORY on this exact battle party,
## with slain enemies and a surviving party. Never call evaluate() here or
## accept a client-supplied outcome string. Do not tick statuses between nodes.
func commit_victory(node_id: Variant, result: CombatBattleResult, party: CombatParty) -> Dictionary:
	if not can_commit_victory(node_id, result, party):
		return _rejected()
	var persisted: Array = party.get_heroes()
	for hero in persisted:
		hero["block"] = 0
	_heroes = persisted
	_fight_ids.append(node_id)
	return {"ok": true, "heroes": _heroes.duplicate(true)}


## Read-only admission for coordinators staging a larger atomic transaction.
func can_commit_victory(node_id: Variant, result: CombatBattleResult, party: CombatParty) -> bool:
	if not _valid or not _valid_id(node_id) or _fight_ids.has(node_id):
		return false
	if not _valid_roster(_heroes, true) or not _same_identities(_heroes):
		return false
	if result == null or party == null or not party.is_valid():
		return false
	if result._party != party or result._enemies == null:
		return false
	if result.get_outcome() != CombatBattleResult.VICTORY:
		return false
	if not result._enemies.is_valid() or not result._enemies.is_victorious() or party.is_defeated():
		return false

	var proposed: Array = party.get_heroes()
	if not _valid_roster(proposed, true) or not _same_identities(proposed):
		return false
	# Downed heroes remain down until a legitimate Rest choice. The party's
	# public combat heal API cannot revive them during a battle.
	for hero in proposed:
		for previous in _heroes:
			if hero["id"] == previous["id"] and previous["hp"] == 0 and hero["hp"] > 0:
				return false
	return true


## Delegate revive-at-one, floor(30%) and HP caps to the authoritative
## RunRestRecovery service. Keep positions, statuses and metadata untouched.
func choose_rest_heal(rest_node_id: Variant) -> Dictionary:
	if not _valid or not _valid_id(rest_node_id) or _rest_ids.has(rest_node_id):
		return _rejected()
	if not _valid_roster(_heroes, true) or not _same_identities(_heroes):
		return _rejected()
	var visit := RunRestRecovery.new(_heroes)
	var recovered: Dictionary = visit.choose_heal()
	if recovered.get("ok") != true:
		return _rejected()
	var next_heroes: Array = recovered["heroes"]
	if not _valid_roster(next_heroes, true) or not _same_identities(next_heroes):
		return _rejected()
	_heroes = next_heroes.duplicate(true)
	_rest_ids.append(rest_node_id)
	return {"ok": true, "heroes": _heroes.duplicate(true)}


func _same_identities(roster: Array) -> bool:
	if roster.size() != _max_hp_by_id.size():
		return false
	for hero in roster:
		if not _max_hp_by_id.has(hero["id"]) or _max_hp_by_id[hero["id"]] != hero["max_hp"]:
			return false
	return true


## {hero_id: authored max_hp} when heroes are three distinct heroes that
## RunV3PartyAdmission admits, each at its authored max HP and, for a V3 hero, with
## exactly its own authored passive; {} otherwise. ordered also requires the
## admitted default-position order (stable pick order on ties).
static func canonical_caps(heroes: Variant, ordered: bool) -> Dictionary:
	if typeof(heroes) != TYPE_ARRAY or heroes.size() != PARTY_SIZE:
		return {}
	var ids: Array = []
	for hero in heroes:
		if typeof(hero) != TYPE_DICTIONARY:
			return {}
		ids.append(hero.get("id"))
	var receipt := RunV3PartyAdmission.admit(ids)
	if not receipt.ok:
		return {}
	var authored := {}
	for index in range(PARTY_SIZE):
		if ordered and receipt.hero_ids[index] != ids[index]:
			return {}
		authored[receipt.party[index].id] = receipt.party[index]
	var caps := {}
	for hero in heroes:
		var definition: Dictionary = authored[hero.id]
		if typeof(hero.get("max_hp")) != TYPE_INT or hero.max_hp != definition.max_hp:
			return {}
		if definition.has("passive") and hero.get("passive") != definition.passive:
			return {}
		caps[hero.id] = definition.max_hp
	return caps


static func _valid_id(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not value.is_empty() and value == value.strip_edges()


static func _valid_roster(roster: Array, require_living: bool) -> bool:
	if roster.size() != PARTY_SIZE:
		return false
	var ids: Dictionary = {}
	var living := 0
	for index in range(PARTY_SIZE):
		var hero: Variant = roster[index]
		if typeof(hero) != TYPE_DICTIONARY:
			return false
		var id: Variant = hero.get("id")
		var position: Variant = hero.get("position")
		var hp: Variant = hero.get("hp")
		var max_hp: Variant = hero.get("max_hp")
		var block: Variant = hero.get("block")
		if typeof(id) != TYPE_STRING or id.strip_edges().is_empty() or ids.has(id):
			return false
		if typeof(position) != TYPE_INT or position != index + 1:
			return false
		if typeof(max_hp) != TYPE_INT or max_hp <= 0:
			return false
		if typeof(hp) != TYPE_INT or hp < 0 or hp > max_hp:
			return false
		if typeof(block) != TYPE_INT or block < 0:
			return false
		var statuses: Variant = hero.get("statuses", {})
		if typeof(statuses) != TYPE_DICTIONARY:
			return false
		for name in statuses:
			if typeof(name) != TYPE_STRING or not name in ["bleed", "weak", "exposed"]:
				return false
			if typeof(statuses[name]) != TYPE_INT or statuses[name] < 0:
				return false
		ids[id] = true
		if hp > 0:
			living += 1
	return not require_living or living > 0


static func _rejected() -> Dictionary:
	return {"ok": false, "heroes": []}
