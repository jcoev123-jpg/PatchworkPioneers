class_name CombatEnemyIntents
extends RefCounted
## Selects announced enemy actions; never resolves damage or Block.
## The legacy constructor keeps independent authored pattern fixtures cycling
## deterministically. A live battle opts in with bind_battle(): every original
## enemy slot then announces one authored weighted action and one concrete
## target chosen by that enemy's policy from the run's single RNG.

const TARGET_POLICIES := ["front", "lowest_living_hp", "exposed", "random"]
const MAX_INT := 9223372036854775807

var _definitions: Array[Dictionary] = []
var _turn_index := 0
var _valid := false
# Opt-in battle-bound weighted cache. The legacy schedule above stays untouched
# so encounters and fixtures keep their authored cycles.
var _bound := false
var _party: CombatParty
var _rng: RandomNumberGenerator
var _slots: Array[Dictionary] = []
var _cache: Array[Dictionary] = []


func _init(definitions: Array = []) -> void:
	# Validate the entire copied schedule before publishing any of it.
	if definitions.is_empty() or definitions.size() > 3:
		return
	var snapshot := definitions.duplicate(true)
	var seen_positions: Array[int] = []
	var validated: Array[Dictionary] = []
	for definition in snapshot:
		if not definition is Dictionary or definition.size() != 2:
			return
		if not definition.has("enemy_position") or not definition.has("pattern"):
			return
		var position = definition["enemy_position"]
		if not position is int or position < 1 or position > 3 or position in seen_positions:
			return
		var pattern = definition["pattern"]
		if not pattern is Array or pattern.is_empty():
			return
		for action in pattern:
			if not valid_action(action):
				return
		seen_positions.append(position)
		validated.append({"enemy_position": position, "pattern": pattern})
	_definitions = validated
	_valid = true


## Opt one already-validated fight into the authored weighted intentions. Every
## source's authored spec and the whole roster are validated before the run RNG
## is touched, then exactly one announcement per original slot is cached. The
## caller must supply the genuine roster, party and run generator.
func bind_battle(enemies: CombatEnemies, party: CombatParty,
		rng: RandomNumberGenerator) -> bool:
	if not _valid or _bound or enemies == null or party == null or rng == null:
		return false
	if not is_instance_valid(enemies) or not is_instance_valid(party) \
			or not is_instance_valid(rng) or not enemies.is_valid() or not party.is_valid():
		return false
	var roster := enemies.get_enemies()
	if roster.size() != _definitions.size() or roster.size() > CombatEnemies.MAX_ENEMIES:
		return false
	var slots: Array[Dictionary] = []
	for index in range(roster.size()):
		var spec = roster[index].get("intent")
		if not spec is Dictionary or spec.size() != 2 \
				or not spec.has("target") or not spec.has("actions"):
			return false
		var policy = spec["target"]
		if not policy is String or not policy in TARGET_POLICIES:
			return false
		var raw_actions = spec["actions"]
		if not raw_actions is Array or raw_actions.is_empty():
			return false
		var actions: Array[Dictionary] = []
		var total_weight := 0
		for raw in raw_actions:
			var action := weighted_action(raw)
			if action.is_empty():
				return false
			# Keep the announcement roll's weight sum inside a safe integer.
			if int(action["weight"]) > MAX_INT - total_weight:
				return false
			total_weight += int(action["weight"])
			actions.append(action)
		slots.append({"enemy_position": index + 1, "target": policy, "actions": actions})
	var batch := _draw_batch(slots, party, rng)
	if batch.size() != slots.size():
		return false
	_party = party
	_rng = rng
	_slots = slots
	_cache = batch
	_bound = true
	return true


## True only for a live fight bound to authored weighted intentions.
func is_bound() -> bool:
	return _valid and _bound


## Validate one authored weighted alternative after JSON number normalization.
## Authored entries carry a positive integer weight plus the exact action shape
## CombatEnemyPhase executes; the target policy, never the author, picks target.
static func weighted_action(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not raw.has("weight"):
		return {}
	var weight := positive_weight(raw["weight"])
	if weight < 1:
		return {}
	var body: Dictionary = {}
	for key in raw:
		if key == "weight":
			continue
		if key in ["target_position", "enemy_position", "target_policy"]:
			return {}
		body[key] = raw[key]
	if not _normalize_integral(body, "amount", 0):
		return {}
	if body.has("direction") and not _normalize_integral(body, "direction", -1):
		return {}
	var probe: Dictionary = body.duplicate(true)
	if probe.get("type") in ["attack", "debuff", "shove"]:
		probe["target_position"] = 2
	if not valid_action(probe):
		return {}
	return {"weight": weight, "action": body}


## JSON numbers decode as floats; accept only exactly integral, safely sized
## integers for authored gameplay amounts and weights.
static func positive_weight(value: Variant) -> int:
	var number := 0
	if value is int:
		number = value
	elif value is float and is_finite(value) and floorf(value) == value \
			and absf(value) <= 9007199254740991.0:
		number = int(value)
	else:
		return 0
	return number if number >= 1 and number <= MAX_INT else 0


static func _normalize_integral(record: Dictionary, field: String, minimum: int) -> bool:
	if not record.has(field):
		return false
	var value = record[field]
	if value is int:
		if value < minimum:
			return false
	elif value is float and is_finite(value) and floorf(value) == value \
			and absf(value) <= 9007199254740991.0:
		value = int(value)
		if value < minimum or value >= MAX_INT:
			return false
	else:
		return false
	record[field] = value
	return true


## The given party's living positions, always in ascending slot order.
static func living_positions(party: CombatParty) -> Array[int]:
	var living: Array[int] = []
	if party == null or not party.is_valid():
		return living
	for index in range(CombatParty.PARTY_SIZE):
		if party.get_hero(index + 1).get("hp", 0) > 0:
			living.append(index + 1)
	return living


## Deterministic priority target with no RNG: front, lowest living HP (ties to
## the front-most slot), or the living Exposed hero (falling back to front).
static func priority_target(party: CombatParty, policy: String) -> int:
	var living := living_positions(party)
	if living.is_empty():
		return 0
	if policy == "lowest_living_hp":
		var best: int = living[0]
		for position in living:
			if party.get_hero(position).get("hp", 0) < party.get_hero(best).get("hp", 0):
				best = position
		return best
	if policy == "exposed":
		for position in living:
			if party.get_hero(position).get("statuses", {}).get("exposed", 0) > 0:
				return position
	return living[0]


## The authored target policy of one original roster slot, or "" for a fixture
## roster without authored intentions (which keeps the legacy inert behavior).
static func policy_for(enemies: CombatEnemies, position: int) -> String:
	if enemies == null or not enemies.is_valid() or position < 1 \
			or position > enemies.get_enemies().size():
		return ""
	var spec = enemies.get_enemy(position).get("intent")
	if not spec is Dictionary:
		return ""
	var policy = spec.get("target")
	return policy if policy is String and policy in TARGET_POLICIES else ""


## A shove needs both its announced hero and the adjacent destination alive.
static func shove_is_legal(party: CombatParty, target: int, direction: int) -> bool:
	if party == null or not party.is_valid():
		return false
	var destination := target + direction
	if destination < 1 or destination > CombatParty.PARTY_SIZE:
		return false
	return not party.is_downed(target) and not party.is_downed(destination)


## Resolve one cached announcement against the actors as they stand now. A
## policy action whose announced hero is already downed falls back to the
## policy's first living choice, deterministically and without fresh RNG.
## A roster without authored intentions keeps its exact legacy target.
static func resolve_announced_action(party: CombatParty, action: Dictionary,
		enemies: CombatEnemies) -> Dictionary:
	var resolved: Dictionary = action.duplicate(true)
	var source = resolved.get("enemy_position")
	var policy := policy_for(enemies, source if source is int else 0)
	if policy.is_empty() or party == null or not party.is_valid() \
			or not resolved.has("target_position"):
		return resolved
	var announced = resolved["target_position"]
	if not announced is int or announced < 1 or announced > CombatParty.PARTY_SIZE \
			or not party.is_downed(announced):
		return resolved
	var fallback := priority_target(party, policy)
	if fallback < 1:
		return resolved
	resolved["target_position"] = fallback
	if resolved.get("type") == "shove":
		var direction = resolved.get("direction")
		if not direction is int:
			return resolved
		# Keep the authored push when it stays inside living neighbours, else
		# use the opposite push; the phase skips a beat with no living neighbour.
		if not shove_is_legal(party, fallback, direction):
			resolved["direction"] = -direction
	return resolved


## One announcement per slot. A single authored alternative needs no draw; a
## real weighted choice and a random target each consume the run RNG once.
static func _draw_batch(slots: Array, party: CombatParty,
		rng: RandomNumberGenerator) -> Array[Dictionary]:
	var batch: Array[Dictionary] = []
	# Nothing is drawn for a party with no living hero to announce against.
	if living_positions(party).is_empty():
		return batch
	for slot in slots:
		var actions: Array = slot["actions"]
		var total := 0
		for entry in actions:
			total += int(entry["weight"])
		var action: Dictionary = actions[0]["action"].duplicate(true)
		if actions.size() > 1:
			var roll := rng.randi_range(1, total)
			for entry in actions:
				roll -= int(entry["weight"])
				if roll <= 0:
					action = entry["action"].duplicate(true)
					break
		action["enemy_position"] = slot["enemy_position"]
		var policy: String = slot["target"]
		if action["type"] in ["attack", "debuff", "shove"]:
			var target := _choose_target(party, policy, rng)
			if target < 1:
				return []
			action["target_position"] = target
			if action["type"] == "shove":
				var direction: int = action["direction"]
				if target + direction < 1 or target + direction > CombatParty.PARTY_SIZE \
						or (not shove_is_legal(party, target, direction)
							and shove_is_legal(party, target, -direction)):
					action["direction"] = -direction
		batch.append(action)
	batch.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["enemy_position"] < b["enemy_position"])
	return batch


static func _choose_target(party: CombatParty, policy: String,
		rng: RandomNumberGenerator) -> int:
	var living := living_positions(party)
	if living.is_empty():
		return 0
	if policy == "random":
		if living.size() == 1:
			return living[0]
		return living[rng.randi_range(0, living.size() - 1)]
	return priority_target(party, policy)


## Accept the exact legacy action shape. The executor resolves target policies
## from the authored roster, so announcements never carry extra keys.
static func valid_action(action: Variant) -> bool:
	if not action is Dictionary:
		return false
	var kind = action.get("type")
	var amount = action.get("amount")
	if not kind is String or not amount is int or amount < 0:
		return false
	if kind in ["block", "buff"]:
		return action.size() == 2 and (kind == "block" or amount > 0)
	if kind not in ["attack", "shove", "debuff"]:
		return false
	var target = action.get("target_position")
	if not target is int or target < 1 or target > 3:
		return false
	if kind == "attack":
		return action.size() == 3
	if kind == "debuff":
		return action.size() == 4 and amount > 0 and action.get("status") is String \
			and action.status in ["bleed", "weak", "exposed"]
	var direction = action.get("direction")
	return action.size() == 4 and amount == 0 and direction is int \
		and direction in [-1, 1] and target + direction >= 1 and target + direction <= 3


func is_valid() -> bool:
	return _valid


func get_intents() -> Array[Dictionary]:
	if not _valid:
		return []
	if _bound:
		return _cache.duplicate(true)
	var intents: Array[Dictionary] = []
	for definition in _definitions:
		var pattern: Array = definition["pattern"]
		var action: Dictionary = pattern[_turn_index % pattern.size()].duplicate(true)
		action["enemy_position"] = definition["enemy_position"]
		intents.append(action)
	intents.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["enemy_position"] < b["enemy_position"])
	return intents.duplicate(true)


func advance_turn() -> bool:
	if not _valid:
		return false
	if _bound:
		var batch := _draw_batch(_slots, _party, _rng)
		if batch.size() != _slots.size():
			_cache.clear()
			return false
		_cache = batch
	_turn_index += 1
	return true
