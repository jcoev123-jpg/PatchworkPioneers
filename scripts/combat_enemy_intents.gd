class_name CombatEnemyIntents
extends RefCounted
## Selects announced enemy actions; never resolves damage or Block.
## The legacy constructor keeps independent authored pattern fixtures cycling
## deterministically. A live battle opts in with bind_battle(): every original
## enemy slot then announces one authored weighted action and one concrete
## target chosen by that enemy's policy from the run's single RNG.

const TARGET_POLICIES := ["front", "lowest_living_hp", "exposed", "random"]
const MAX_INT := 9223372036854775807
const BOSS_CATALOG_PATH := "res://data/enemies/boss.json"

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
# The authoritative roster is also CombatEnemyPhase's source for policy fallback.
# The boss's cached phase and that roster policy must move in the same commit.
var _enemies: CombatEnemies
var _boss_slot := 0
var _boss_phase := 0
var _boss_definition: Dictionary = {}
var _phase_two_record: Variant = null
var _quilt_tier := 0


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
		rng: RandomNumberGenerator, difficulty: RunDifficulty = null) -> bool:
	if enemies == null or not is_instance_valid(enemies) or not enemies.is_valid():
		return false
	var has_behemoth := false
	for enemy in enemies.get_enemies():
		if enemy.get("id") == CombatBehemothPhaseRules.BOSS_ID:
			has_behemoth = true
			break
	if not has_behemoth:
		return _bind_battle_with_phase_data(enemies, party, rng, null, null)
	# Production reads both authored resources once. The narrower helper is an
	# injection seam for malformed/missing data tests, never a second scheduler.
	var catalog := FileAccess.open(BOSS_CATALOG_PATH, FileAccess.READ)
	if catalog == null:
		return false
	var boss_data: Variant = JSON.parse_string(catalog.get_as_text())
	catalog.close()
	var phase_file := FileAccess.open(CombatBehemothPhaseRules.PHASE_TWO_PATH, FileAccess.READ)
	if phase_file == null:
		return false
	var phase_data: Variant = JSON.parse_string(phase_file.get_as_text())
	phase_file.close()
	return _bind_battle_with_phase_data(enemies, party, rng, boss_data, phase_data,
		difficulty.get_selected_tier() if difficulty != null else 0)


## All validation (including both boss records) happens before the first draw
## or any publication. Inputs and authentic actor dictionaries stay detached.
func _bind_battle_with_phase_data(enemies: CombatEnemies, party: CombatParty,
		rng: RandomNumberGenerator, boss_data: Variant, phase_data: Variant, tier: int = 0) -> bool:
	if not _valid or _bound or enemies == null or party == null or rng == null:
		return false
	if not is_instance_valid(enemies) or not is_instance_valid(party) \
			or not is_instance_valid(rng) or not enemies.is_valid() or not party.is_valid():
		return false
	var roster := enemies.get_enemies()
	if roster.size() != _definitions.size() or roster.size() > CombatEnemies.MAX_ENEMIES \
			or living_positions(party).is_empty():
		return false
	var boss_slot := 0
	var boss_definition: Dictionary = {}
	var phase_two: Variant = null
	var boss_phase := 0
	var boss_intent: Dictionary = {}
	for index in range(roster.size()):
		if roster[index].get("id") != CombatBehemothPhaseRules.BOSS_ID:
			continue
		if roster.size() != 1 or boss_slot != 0 \
				or not CombatBehemothPhaseRules.validate_boss_definition(boss_data) \
				or not CombatBehemothPhaseRules.validate_phase_two_record(phase_data):
			return false
		var canonical: Variant = boss_data
		if boss_data is Array:
			if boss_data.size() != 1:
				return false
			canonical = boss_data[0]
		if not canonical is Dictionary:
			return false
		if tier not in [0, 1, 2]:
			return false
		var authority := RunDifficulty.new()
		var modifiers := authority.modifiers_for_tier(tier)
		var scaled: Dictionary = canonical.duplicate(true)
		scaled.max_hp = int(scaled.max_hp) + int(ceil(scaled.max_hp * modifiers.max_hp_percent_bonus / 100.0))
		scaled.intent = RunDifficulty.scale_intent(scaled.intent, modifiers.attack_intent_bonus)
		# The Boss roster must carry the catalog's canonical identity and
		# phase-one intent. HP/Block are mutable battle state, not definitions.
		for field in ["id", "name", "max_hp", "art_path", "intent"]:
			if roster[index].get(field) != scaled.get(field):
				return false
		boss_slot = index + 1
		boss_definition = canonical.duplicate(true)
		phase_two = phase_data.duplicate(true)
		var selection := CombatBehemothPhaseRules.select_phase(
			boss_definition, roster[index].get("hp"), phase_two, tier)
		if not selection.get("ok", false):
			return false
		boss_phase = selection["phase"]
		boss_intent = selection["intent"]
	var slots: Array[Dictionary] = []
	for index in range(roster.size()):
		var spec: Variant = boss_intent if index + 1 == boss_slot else roster[index].get("intent")
		var slot := _weighted_slot(index + 1, spec)
		if slot.is_empty():
			return false
		slots.append(slot)
	var batch := _draw_batch(slots, party, rng)
	if batch.size() != slots.size():
		return false
	_party = party
	_rng = rng
	_enemies = enemies
	_slots = slots
	_cache = batch
	_boss_slot = boss_slot
	_boss_phase = boss_phase
	_boss_definition = boss_definition
	_phase_two_record = phase_two
	_quilt_tier = tier
	if boss_slot > 0:
		_enemies._enemies[boss_slot - 1]["intent"] = boss_intent.duplicate(true)
	_bound = true
	return true


## Normalize one complete spec without changing its owner or any source data.
static func _weighted_slot(position: int, spec: Variant) -> Dictionary:
	if not spec is Dictionary or spec.size() != 2 \
			or not spec.has("target") or not spec.has("actions"):
		return {}
	var policy = spec["target"]
	if not policy is String or not policy in TARGET_POLICIES:
		return {}
	var raw_actions = spec["actions"]
	if not raw_actions is Array or raw_actions.is_empty():
		return {}
	var actions: Array[Dictionary] = []
	var total_weight := 0
	for raw in raw_actions:
		var action := weighted_action(raw)
		if action.is_empty() or int(action["weight"]) > MAX_INT - total_weight:
			return {}
		total_weight += int(action["weight"])
		actions.append(action)
	return {"enemy_position": position, "target": policy, "actions": actions}


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
	if probe.get("type") in ["attack", "debuff", "shove", "snip_block"]:
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


## The hero an authored forward pull really moves. The policy's own target keeps
## the beat when it can already step forward; otherwise the front-most living
## hero with a living hero directly in front of it is pulled instead, which is
## the middle-to-front signature of a zipped pull. 0 means the party has no legal
## forward pair at all, so the caller's pre-existing fallback stays in charge.
static func forward_pull_target(party: CombatParty, policy_target: int) -> int:
	if shove_is_legal(party, policy_target, -1):
		return policy_target
	for candidate in range(2, CombatParty.PARTY_SIZE + 1):
		if shove_is_legal(party, candidate, -1):
			return candidate
	return 0


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
		if action["type"] in ["attack", "debuff", "shove", "snip_block"]:
			var target := _choose_target(party, policy, rng)
			if target < 1:
				return []
			action["target_position"] = target
			if action["type"] == "shove":
				var direction: int = action["direction"]
				# An authored forward pull names the hero it drags toward slot 1.
				# The front policy's own hero cannot step forward, so announce the
				# nearest legal middle-to-front pair and keep the pull direction
				# instead of reversing the enemy's signature move into a push.
				if direction == -1:
					var pulled := forward_pull_target(party, target)
					if pulled > 0:
						target = pulled
						action["target_position"] = pulled
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
	if kind not in ["attack", "shove", "debuff", "snip_block"]:
		return false
	var target = action.get("target_position")
	if not target is int or target < 1 or target > 3:
		return false
	if kind == "attack":
		return action.size() == 3
	if kind == "snip_block":
		return action.size() == 3 and amount == 0
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
		var next_slots: Array[Dictionary] = _slots
		var next_phase := _boss_phase
		var next_intent: Dictionary = {}
		if _boss_slot > 0:
			var boss := _enemies.get_enemy(_boss_slot)
			var hp = boss.get("hp")
			if boss.get("id") != CombatBehemothPhaseRules.BOSS_ID \
					or not hp is int or hp < 0 or hp > CombatBehemothPhaseRules.BOSS_MAX_HP:
				return false
			if hp > 0:
				var choice := CombatBehemothPhaseRules.select_phase(
					_boss_definition, hp, _phase_two_record, _quilt_tier)
				if not choice.get("ok", false):
					return false
				# Phase two is sticky within the fight; a cached announcement
				# cannot regress to a weaker phase on a later advance.
				if _boss_phase == CombatBehemothPhaseRules.PHASE_TWO \
						and choice["phase"] == CombatBehemothPhaseRules.PHASE_ONE:
					choice = CombatBehemothPhaseRules.select_phase(_boss_definition,
						CombatBehemothPhaseRules.PHASE_TWO_THRESHOLD, _phase_two_record, _quilt_tier)
				if not choice.get("ok", false):
					return false
				next_phase = choice["phase"]
				next_intent = choice["intent"]
				var next_slot := _weighted_slot(_boss_slot, next_intent)
				if next_slot.is_empty():
					return false
				next_slots = _slots.duplicate(true)
				next_slots[_boss_slot - 1] = next_slot
		var batch := _draw_batch(next_slots, _party, _rng)
		if batch.size() != next_slots.size():
			return false
		# One commit: the next cached action and CombatEnemyPhase's policy
		# fallback must observe the same phase. Reads never enter this branch.
		_slots = next_slots
		_cache = batch
		if not next_intent.is_empty():
			_enemies._enemies[_boss_slot - 1]["intent"] = next_intent.duplicate(true)
			_boss_phase = next_phase
	_turn_index += 1
	return true
