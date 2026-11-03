class_name CombatEnemies
extends RefCounted
## Independent enemy state. Definitions require unique nonempty String IDs and positive int max_hp.
## Invalid construction is atomic and inert; slain enemies keep their original positions.

const MAX_ENEMIES := 3
const OPT_IN_MAX_ENEMIES := 4
const MAX_INT := 9223372036854775807
## Authored once-only revival. The first HP loss that leaves a living
## `revive_once` foe at 0 HP instead leaves it at half its max HP (rounded up)
## in its own slot and latches `revived`; every later lethal loss is final.
const REVIVE_FIELD := "revive_once"
const REVIVED_FIELD := "revived"

## Embedded battle-only child: never loaded from a run/Elite/Boss catalog.
const BROODLING_ID := "moth_swarm_broodling"
const BROODLING_LATCH := "broodling_summoned"
const MOTH_ID := "moth_swarm"
const MOTH_QUEEN_ID := "moth_queen"

## Explicit, battle-local Termite split. Only the app's post-card observation
## boundary stages it, after a confirmed paid-card lethal hit; damage helpers,
## Bleed, Thorns and the enemy phase never do.
const SPLIT_FIELD := "split_on_death"
const TERMITE_ID := "quilt_termite"
const HALF_LEFT_ID := "quilt_termite_half_left"
const HALF_RIGHT_ID := "quilt_termite_half_right"


## An optional split flag must be a literal boolean, and only an authored
## Quilt Termite can request a split. Never coerce truthy numbers or strings.
static func valid_split_flags(record: Dictionary) -> bool:
	if record.has(SPLIT_FIELD) and not record[SPLIT_FIELD] is bool:
		return false
	return record.get(SPLIT_FIELD, false) != true or record.get("id") == TERMITE_ID


## Authenticate the canonical front-facing weighted Termite attack as well
## as its other alternatives. Accept difficulty-scaled HP/attack already on the
## parent; never reapply tier modifiers or use the run's RNG.
static func _termite_parent_attack(record: Dictionary, position: int) -> int:
	if record.get("id") != TERMITE_ID or record.get(SPLIT_FIELD) != true \
			or record.get("name") != "Quilt Termite" \
			or record.get("art_path") != "res://assets/paper/enemies/quilt_termite.png" \
			or record.get("chew_block_on_attack") != true \
			or not record.get("chew_block_on_attack") is bool \
			or record.has(REVIVE_FIELD) or record.has(REVIVED_FIELD):
		return -1
	if not record.get("max_hp") is int or record["max_hp"] < 26:
		return -1
	var slot := CombatEnemyIntents._weighted_slot(position, record.get("intent"))
	if slot.is_empty() or slot.get("target") != "front":
		return -1
	var actions: Array = slot["actions"]
	if actions.size() not in [3, 5]:
		return -1
	var first: Dictionary = actions[0]
	var body: Variant = first.get("action")
	if not body is Dictionary or body.get("type") != "attack" \
			or not body.get("amount") is int or body["amount"] < 6 \
			or first.get("weight") != 4 or body.keys().size() != 2:
		return -1
	if actions[1] != {"weight": 1, "action": {"type": "block", "amount": 5}} \
			or actions[2] != {"weight": 1, "action": {
				"type": "debuff", "amount": 1, "status": "exposed"}}:
		return -1
	# Named strikes extend the canonical record; children still inherit only
	# the original scaled bite. Keep legacy three-action records supported.
	if actions.size() == 5:
		if actions[3] != {"weight": 1, "action": {"type": "attack",
				"amount": body["amount"], "hits": 2, "move": "attack2"}} \
				or actions[4].get("weight") != 1:
			return -1
		var spit: Dictionary = actions[4].get("action", {})
		if spit.keys().size() != 3 or spit.get("type") != "attack" \
				or spit.get("move") != "attack3" or not spit.get("amount") is int \
				or spit["amount"] <= body["amount"]:
			return -1
	return body["amount"]


## Build fresh half-actors from approved values only. Never copy the parent's
## Block, statuses, damage flags, split flag or other mutable combat metadata.
static func _half_termite(id: String, position: int, hp: int, attack: int,
		art_path: String) -> Dictionary:
	return {"id": id, "name": "Half Quilt Termite", "max_hp": hp, "hp": hp,
		"block": 0, "position": position, "enemy_position": position,
		"art_path": art_path, "intent": {"target": "front", "actions": [
			{"type": "attack", "amount": attack, "weight": 1}]}}


## Stage ONLY when explicitly requested after lethal damage. Validate the
## entire occupied roster and the authentic parent before examining inert
## cases. No is_valid()/get_enemy() calls here: those settle Wraith revivals
## and could mutate an unrelated record on an otherwise rejected proposal.
## One detached proposal is published only after BOTH children validate.
func stage_split_on_death(source: Variant) -> Dictionary:
	var rejected := {"ok": false, "split": false}
	if not source is int or source < 1 or source > _enemies.size() \
			or _enemies.is_empty() or _enemies.size() > _capacity:
		return rejected
	var ids: Array[String] = []
	for index in range(_enemies.size()):
		var actor: Dictionary = _enemies[index]
		var id: Variant = actor.get("id")
		var maximum: Variant = actor.get("max_hp")
		var hp: Variant = actor.get("hp")
		var block: Variant = actor.get("block")
		var position: Variant = actor.get("position")
		if not id is String or id.is_empty() or id in ids \
				or not maximum is int or maximum <= 0 \
				or not hp is int or hp < 0 or hp > maximum \
				or not block is int or block < 0 \
				or not position is int or position != index + 1 \
				or not valid_revive_flags(actor) or not valid_split_flags(actor):
			return rejected
		if actor.has("enemy_position") and (not actor["enemy_position"] is int \
				or actor["enemy_position"] != index + 1):
			return rejected
		ids.append(id)
	var parent: Dictionary = _enemies[source - 1]
	var attack := _termite_parent_attack(parent, source)
	if attack < 0:
		return rejected
	if parent["hp"] > 0 or _enemies.size() == _capacity:
		return {"ok": true, "split": false}
	if HALF_LEFT_ID in ids or HALF_RIGHT_ID in ids:
		return rejected
	var half_hp: int = (parent["max_hp"] / 2) + (parent["max_hp"] % 2)
	var half_attack: int = (attack / 2) + (attack % 2)
	var left := _half_termite(HALF_LEFT_ID, source, half_hp, half_attack, parent["art_path"])
	var right := _half_termite(HALF_RIGHT_ID, _enemies.size() + 1,
		half_hp, half_attack, parent["art_path"])
	if CombatEnemyIntents._weighted_slot(left["position"], left["intent"]).is_empty() \
			or CombatEnemyIntents._weighted_slot(right["position"], right["intent"]).is_empty():
		return rejected
	var proposal: Array[Dictionary] = _enemies.duplicate(true)
	proposal[source - 1] = left
	proposal.append(right)
	_enemies = proposal
	return {"ok": true, "split": true, "positions": [source, right["position"]]}



static func broodling_definition() -> Dictionary:
	return {"id": BROODLING_ID, "name": "Moth Broodling", "max_hp": 8,
		"art_path": "res://assets/paper/enemies/moth_swarm_broodling.png",
		"intent": {"target": "front", "actions": [
			{"type": "attack", "amount": 5, "weight": 1}]}}


## Authenticate both authored parents (including the weighted summon) before
## staging a birth. Attack amounts may already include an earned tier bonus;
## every other alternative and weight must still match the shipped spec.
static func authentic_broodling_mother(mother: Dictionary, position: int) -> bool:
	var id: Variant = mother.get("id")
	if id not in [MOTH_ID, MOTH_QUEEN_ID]:
		return false
	var queen: bool = id == MOTH_QUEEN_ID
	if mother.get("name") != ("Moth Queen" if queen else "Moth Swarm") \
			or mother.get("art_path") != ("res://assets/paper/enemies/moth_queen.png" if queen \
			else "res://assets/paper/enemies/moth_swarm.png") \
			or not mother.get("max_hp") is int \
			or mother["max_hp"] < (90 if queen else 21):
		return false
	if queen:
		if mother.has("chew_block_on_attack"):
			return false
	elif mother.get("chew_block_on_attack") != true \
			or not mother.get("chew_block_on_attack") is bool:
		return false
	var slot := CombatEnemyIntents._weighted_slot(position, mother.get("intent"))
	if slot.is_empty() or slot.get("target") != "front":
		return false
	var actual: Array = slot["actions"]
	var expected: Array = [
		{"weight": 4 if queen else 3, "action": {"type": "attack",
			"amount": 25 if queen else 7}}
	]
	if queen:
		expected.append({"weight": 2, "action": {"type": "summon", "amount": 0}})
		expected.append({"weight": 1, "action": {
			"type": "attack", "amount": 18, "hits": 2, "move": "attack2"}})
		expected.append({"weight": 1, "action": {
			"type": "attack", "amount": 28, "move": "attack3"}})
		expected.append({"weight": 1, "action": {
			"type": "attack", "amount": 32, "move": "attack4"}})
	else:
		expected = [
			{"weight": 2, "action": {"type": "snip_block", "amount": 0}},
			{"weight": 3, "action": {"type": "attack", "amount": 7}},
			{"weight": 1, "action": {"type": "debuff", "status": "weak", "amount": 1}},
			{"weight": 1, "action": {"type": "summon", "amount": 0}},
			{"weight": 1, "action": {"type": "attack", "amount": 6, "hits": 2, "move": "attack2"}}
		]
	if actual.size() != expected.size():
		return false
	for i in range(expected.size()):
		var candidate: Dictionary = actual[i].duplicate(true)
		var baseline: Dictionary = expected[i]
		if candidate["action"].get("type") == "attack":
			if not candidate["action"].get("amount") is int \
					or candidate["action"]["amount"] < baseline["action"]["amount"]:
				return false
			candidate["action"]["amount"] = baseline["action"]["amount"]
		if candidate != baseline:
			return false
	return true


## Only the detached phase roster calls this. Returns failure for malformed
## metadata and a successful inert beat for full, slain or already-used sources.
## No RNG is accepted here; neither a rejected nor a skipped birth can draw it.
func stage_broodling(source: int) -> Dictionary:
	var failure := {"ok": false, "spawned": false}
	if not is_valid() or source < 1 or source > _enemies.size():
		return failure
	var mother: Dictionary = _enemies[source - 1]
	var latch: Variant = mother.get(BROODLING_LATCH, false)
	if not latch is bool:
		return failure
	if not authentic_broodling_mother(mother, source):
		return failure
	var spec: Variant = mother.get("intent")
	if CombatEnemyIntents._weighted_slot(source, spec).is_empty():
		return failure
	var child := broodling_definition()
	if CombatEnemyIntents._weighted_slot(_enemies.size() + 1, child.intent).is_empty():
		return failure
	if mother["hp"] == 0 or latch or _enemies.size() >= _capacity:
		return {"ok": true, "spawned": false}
	for existing in _enemies:
		if existing.get("id") == BROODLING_ID:
			return {"ok": true, "spawned": false}
	var next: Dictionary = child.duplicate(true)
	next["position"] = _enemies.size() + 1
	next["hp"] = next["max_hp"]
	next["block"] = 0
	mother[BROODLING_LATCH] = true
	_enemies.append(next)
	return {"ok": true, "spawned": true, "position": next.position}


var _enemies: Array[Dictionary] = []
var _capacity := MAX_ENEMIES


## Only an explicit literal four admits one extra battle actor; default stays three.
## Invalid capacity requests never create a valid roster or grant extra slots.
func _init(definitions: Array, capacity: Variant = MAX_ENEMIES) -> void:
	if not capacity is int or capacity not in [MAX_ENEMIES, OPT_IN_MAX_ENEMIES] \
			or definitions.is_empty() or definitions.size() > capacity:
		return
	_capacity = capacity
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
		if not valid_revive_flags(definition) or not valid_split_flags(definition):
			return
		ids.append(id)
	for index in range(definitions.size()):
		var enemy: Dictionary = definitions[index].duplicate(true)
		enemy["position"] = index + 1
		enemy["hp"] = enemy["max_hp"]
		enemy["block"] = 0
		_enemies.append(enemy)


func get_capacity() -> int:
	return _capacity


func is_valid() -> bool:
	_settle_revivals()
	return not _enemies.is_empty() and _enemies.size() <= _capacity


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
	if not CombatStatusTurnBatch.new().tick_side("enemies", get_enemies(), _capacity)["ok"]:
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
