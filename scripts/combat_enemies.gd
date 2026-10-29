class_name CombatEnemies
extends RefCounted
## Independent enemy state. Definitions require unique nonempty String IDs and positive int max_hp.
## Invalid construction is atomic and inert; slain enemies keep their original positions.

const MAX_ENEMIES := 3
const MAX_INT := 9223372036854775807
## Authored once-only revival. The first HP loss that leaves a living
## `revive_once` foe at 0 HP instead leaves it at half its max HP (rounded up)
## in its own slot and latches `revived`; every later lethal loss is final.
const REVIVE_FIELD := "revive_once"
const REVIVED_FIELD := "revived"

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
		if not valid_revive_flags(definition):
			return
		ids.append(id)
	for index in range(definitions.size()):
		var enemy: Dictionary = definitions[index].duplicate(true)
		enemy["position"] = index + 1
		enemy["hp"] = enemy["max_hp"]
		enemy["block"] = 0
		_enemies.append(enemy)


func is_valid() -> bool:
	_settle_revivals()
	return not _enemies.is_empty() and _enemies.size() <= MAX_ENEMIES


## `revive_once` and `revived` are each absent or a literal boolean, and a
## `revived` latch is only meaningful on an authored reviver.
static func valid_revive_flags(record: Dictionary) -> bool:
	for field in [REVIVE_FIELD, REVIVED_FIELD]:
		if record.has(field) and not record[field] is bool:
			return false
	return not (bool(record.get(REVIVED_FIELD, false)) and not bool(record.get(REVIVE_FIELD, false)))


## True for a well-formed authored reviver that has not spent its revival yet.
static func revive_pending(record: Dictionary) -> bool:
	return valid_revive_flags(record) and bool(record.get(REVIVE_FIELD, false)) \
		and not bool(record.get(REVIVED_FIELD, false))


static func revive_hp(max_hp: int) -> int:
	return maxi(1, ceili(max_hp / 2.0))


## The single once-only lifecycle contract. A record left at 0 HP by a lethal
## loss revives in place exactly once: only `hp` and the `revived` latch change,
## so slot, Block, statuses, intent and every authored field are kept.
static func settle_revival(record: Dictionary) -> bool:
	var hp: Variant = record.get("hp")
	if not hp is int or hp != 0 or not record.get("max_hp") is int or not revive_pending(record):
		return false
	record["hp"] = revive_hp(record["max_hp"])
	record[REVIVED_FIELD] = true
	return true


## Owner-turn Bleed is resolved on a detached CombatStatusTurnBatch proposal and
## committed field by field into these records by CombatRoundFlow. Its lethal
## tick therefore lands as 0 HP and is settled here by the same contract before
## any reader (victory, slain, snapshot) can observe the roster.
func _settle_revivals() -> void:
	for enemy in _enemies:
		settle_revival(enemy)


func get_enemies() -> Array[Dictionary]:
	_settle_revivals()
	return _enemies.duplicate(true)


func get_enemy(position: int) -> Dictionary:
	_settle_revivals()
	if not _valid_position(position):
		return {}
	return _enemies[position - 1].duplicate(true)


## Validate the complete roster and additions before writing any counter.
## Slain slots remain valid recipients so a confirmed lethal hit can persist.
func can_apply_statuses(applications: Dictionary) -> bool:
	if not CombatStatusTurnBatch.new().tick_side("enemies", get_enemies())["ok"]:
		return false
	for position in applications:
		if not position is int or not _valid_position(position):
			return false
		var additions: Variant = applications[position]
		if not additions is Dictionary:
			return false
		for status in additions:
			if not status is String or status not in ["bleed", "weak", "exposed"]:
				return false
			var count: Variant = additions[status]
			if not count is int or count < 0:
				return false
			var current: int = _enemies[position - 1].get("statuses", {}).get(status, 0)
			if count > MAX_INT - current:
				return false
	return true


func apply_statuses(applications: Dictionary) -> bool:
	if not can_apply_statuses(applications):
		return false
	for position in applications:
		var enemy: Dictionary = _enemies[position - 1]
		for status in applications[position]:
			if applications[position][status] == 0:
				continue
			if not enemy.has("statuses"):
				enemy["statuses"] = {}
			enemy["statuses"][status] = enemy["statuses"].get(status, 0) + applications[position][status]
	return true


func apply_damage(position: int, amount: int) -> bool:
	if not _can_target(position, amount):
		return false
	var enemy := _enemies[position - 1]
	# A malformed revive flag refuses the hit before Block or HP is written.
	if not valid_revive_flags(enemy):
		return false
	var absorbed: int = mini(enemy["block"], amount)
	enemy["block"] -= absorbed
	enemy["hp"] = maxi(0, enemy["hp"] - (amount - absorbed))
	settle_revival(enemy)
	return true


func gain_block(position: int, amount: int) -> bool:
	if not _can_target(position, amount):
		return false
	var enemy := _enemies[position - 1]
	if amount > MAX_INT - enemy["block"]:
		return false
	enemy["block"] += amount
	return true


## Restore HP on a living slot, clamped to max_hp. Healing never revives a slain
## enemy, never overheals, and preserves position, id, Block, metadata and statuses.
func heal(position: int, amount: int) -> bool:
	if not _can_target(position, amount):
		return false
	var enemy := _enemies[position - 1]
	enemy["hp"] += mini(amount, enemy["max_hp"] - enemy["hp"])
	return true


## Persist the authored Enrage stack counter on one existing slot. Only the
## `enrage_stacks` key is written: HP, Block, position, statuses and every other
## authored field stay exactly as they were, and a slain slot stays slain.
## The keyword's cap belongs to CombatEnemyKeywordRules; this model only refuses
## an invalid slot or a negative counter.
func set_enrage_stacks(position: int, stacks: int) -> bool:
	if not _valid_position(position) or stacks < 0:
		return false
	_enemies[position - 1]["enrage_stacks"] = stacks
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
