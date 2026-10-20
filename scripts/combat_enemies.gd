class_name CombatEnemies
extends RefCounted
## Independent enemy state. Definitions require unique nonempty String IDs and positive int max_hp.
## Invalid construction is atomic and inert; slain enemies keep their original positions.

const MAX_ENEMIES := 3
const MAX_INT := 9223372036854775807

var _enemies: Array[Dictionary] = []


func _init(definitions: Array) -> void:
	if definitions.is_empty() or definitions.size() > MAX_ENEMIES:
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
	for index in range(definitions.size()):
		var enemy: Dictionary = definitions[index].duplicate(true)
		enemy["position"] = index + 1
		enemy["hp"] = enemy["max_hp"]
		enemy["block"] = 0
		_enemies.append(enemy)


func is_valid() -> bool:
	return not _enemies.is_empty() and _enemies.size() <= MAX_ENEMIES


func get_enemies() -> Array[Dictionary]:
	return _enemies.duplicate(true)


func get_enemy(position: int) -> Dictionary:
	if not _valid_position(position):
		return {}
	return _enemies[position - 1].duplicate(true)


func apply_damage(position: int, amount: int) -> bool:
	if not _can_target(position, amount):
		return false
	var enemy := _enemies[position - 1]
	var absorbed: int = mini(enemy["block"], amount)
	enemy["block"] -= absorbed
	enemy["hp"] = maxi(0, enemy["hp"] - (amount - absorbed))
	return true


func gain_block(position: int, amount: int) -> bool:
	if not _can_target(position, amount):
		return false
	var enemy := _enemies[position - 1]
	if amount > MAX_INT - enemy["block"]:
		return false
	enemy["block"] += amount
	return true


func is_slain(position: int) -> bool:
	return _valid_position(position) and _enemies[position - 1]["hp"] == 0


## Death query by position; invalid positions and invalid rosters fail closed.
func is_dead(position: int) -> bool:
	return is_slain(position)


## The caller may declare victory only when a valid roster is entirely slain.
func is_defeated() -> bool:
	if not is_valid():
		return false
	for enemy in _enemies:
		if enemy["hp"] > 0:
			return false
	return true


## Victory query; invalid rosters fail closed and only the final death wins.
func is_victorious() -> bool:
	return is_defeated()


func _valid_position(position: int) -> bool:
	return is_valid() and position >= 1 and position <= _enemies.size()


func _can_target(position: int, amount: int) -> bool:
	return amount >= 0 and _valid_position(position) and not is_slain(position)
