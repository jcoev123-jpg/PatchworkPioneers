class_name CombatParty
extends RefCounted
## Definitions are dictionaries with a unique nonempty String id and positive int max_hp.
## Array order fixes positions 1-3. Invalid construction leaves an inert, invalid party.
## State readers return deep copies so callers cannot mutate the rules indirectly.

const PARTY_SIZE := 3
const MAX_INT := 9223372036854775807

var _heroes: Array[Dictionary] = []


func _init(definitions: Array) -> void:
	if definitions.size() != PARTY_SIZE:
		return
	var ids: Array[String] = []
	for definition in definitions:
		if not definition is Dictionary:
			return
		var id = definition.get("id")
		var max_hp = definition.get("max_hp")
		if not id is String or id.is_empty() or id in ids:
			return
		if not max_hp is int or max_hp <= 0:
			return
		ids.append(id)
	for index in range(PARTY_SIZE):
		var hero: Dictionary = definitions[index].duplicate(true)
		hero["position"] = index + 1
		hero["hp"] = hero["max_hp"]
		hero["block"] = 0
		_heroes.append(hero)


func is_valid() -> bool:
	return _heroes.size() == PARTY_SIZE


func get_heroes() -> Array[Dictionary]:
	return _heroes.duplicate(true)


## An invalid position returns an empty dictionary, never a live state reference.
func get_hero(position: int) -> Dictionary:
	if not _valid_position(position):
		return {}
	return _heroes[position - 1].duplicate(true)


func apply_damage(position: int, amount: int) -> bool:
	if not _can_target(position, amount):
		return false
	var hero := _heroes[position - 1]
	var absorbed: int = mini(hero["block"], amount)
	hero["block"] -= absorbed
	hero["hp"] = maxi(0, hero["hp"] - (amount - absorbed))
	return true


func gain_block(position: int, amount: int) -> bool:
	if not _can_target(position, amount):
		return false
	var hero := _heroes[position - 1]
	if amount > MAX_INT - hero["block"]:
		return false
	hero["block"] += amount
	return true


func heal(position: int, amount: int) -> bool:
	if not _can_target(position, amount):
		return false
	var hero := _heroes[position - 1]
	hero["hp"] += mini(amount, hero["max_hp"] - hero["hp"])
	return true


## This is the reset boundary; gaining Block or taking damage never resets other heroes.
func start_player_turn() -> bool:
	if not is_valid():
		return false
	for hero in _heroes:
		hero["block"] = 0
	return true


func is_downed(position: int) -> bool:
	return _valid_position(position) and _heroes[position - 1]["hp"] == 0


func is_defeated() -> bool:
	if not is_valid():
		return false
	for hero in _heroes:
		if hero["hp"] > 0:
			return false
	return true


func _valid_position(position: int) -> bool:
	return is_valid() and position >= 1 and position <= PARTY_SIZE


func _can_target(position: int, amount: int) -> bool:
	return amount >= 0 and _valid_position(position) and not is_downed(position)
