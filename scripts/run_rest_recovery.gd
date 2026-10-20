class_name RunRestRecovery
extends RefCounted
## One Rest visit's scene-independent heal/revive transaction.
## The input is a snapshot of the persistent run party, not a CombatParty.
## Callers commit a successful result to their run party exactly once.

const PARTY_SIZE := 3

var _roster: Array = []
var _valid: bool = false
var _consumed: bool = false


func _init(run_heroes: Variant = null) -> void:
	if typeof(run_heroes) != TYPE_ARRAY:
		return
	# Neither callers nor returned results may alias the visit's stored state.
	_roster = run_heroes.duplicate(true)
	_valid = _is_valid_roster(_roster)


## A failed call never consumes the visit. The result heroes are newly copied,
## including nested dictionaries and arrays; no other run state is touched.
func choose_heal() -> Dictionary:
	if _consumed or not _valid:
		return {"ok": false, "heroes": []}

	var recovered: Array = _roster.duplicate(true)
	for hero in recovered:
		var max_hp: int = int(hero["max_hp"])
		var hp: int = int(hero["hp"])
		if hp == 0:
			hp = 1
		# Integer arithmetic: floor(30% of max HP), with no RNG or rounding.
		@warning_ignore("integer_division")
		var amount: int = (max_hp / 10) * 3 + (max_hp % 10) * 3 / 10
		hero["hp"] = mini(max_hp, hp + amount)

	_consumed = true
	return {"ok": true, "heroes": recovered}


func is_consumed() -> bool:
	return _consumed


static func _is_integral_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	return not is_nan(value) and not is_inf(value) and value == floor(value)


static func _is_valid_roster(roster: Array) -> bool:
	if roster.size() != PARTY_SIZE:
		return false
	var ids: Dictionary = {}
	var living := 0
	for index in range(PARTY_SIZE):
		var hero: Variant = roster[index]
		if typeof(hero) != TYPE_DICTIONARY:
			return false
		if not hero.has("id") or typeof(hero["id"]) != TYPE_STRING:
			return false
		var hero_id: String = hero["id"]
		if hero_id.strip_edges().is_empty() or ids.has(hero_id):
			return false
		ids[hero_id] = true

		for field in ["position", "max_hp", "hp"]:
			if not hero.has(field) or not _is_integral_number(hero[field]):
				return false
		if int(hero["position"]) != index + 1:
			return false
		var max_hp: int = int(hero["max_hp"])
		var hp: int = int(hero["hp"])
		if max_hp <= 0 or hp < 0 or hp > max_hp:
			return false
		if hp > 0:
			living += 1
	# All heroes at 0 HP is a defeated run: Rest cannot revive it.
	return living > 0
