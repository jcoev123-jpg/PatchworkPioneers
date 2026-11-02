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
const CHARGE_ID := "spindle_ram"
const CHARGE_FLAG := "charge"
# A single actor-owned pending strike is the armed latch; its absence means unarmed.
const CHARGE_PENDING := "charge_pending"

## Authenticate charge metadata on the real roster, including an already
## floor-scaled attack. The actor is the only owner of its pending amount/target.
static func charge_attack_amount(actor: Dictionary) -> int:
	var slot := _weighted_slot(int(actor.get("position", 0)), actor.get("intent"))
	if slot.is_empty() or slot.get("target") != "front":
		return -1
	var attack_amount := -1
	for entry in slot["actions"]:
		var action: Dictionary = entry["action"]
		if action.get("type") == "attack":
			if attack_amount >= 0 or action.has("hits"):
				return -1
			attack_amount = action["amount"]
	return attack_amount


static func valid_charge_actor(actor: Dictionary) -> bool:
	var flag: Variant = actor.get(CHARGE_FLAG, false)
	if not flag is bool:
		return false
	if actor.get("id") == CHARGE_ID and flag != true:
		return false
	if flag and actor.get("id") != CHARGE_ID:
		return false
	if not flag:
		return not actor.has(CHARGE_PENDING)
	var slot := _weighted_slot(int(actor.get("position", 0)), actor.get("intent"))
	if slot.is_empty() or slot.get("target") != "front":
		return false
	var attack_count := 0
	for entry in slot["actions"]:
		var action: Dictionary = entry["action"]
		if action.get("type") == "attack":
			attack_count += 1
			if action.has("hits") or action["amount"] > CombatParty.MAX_INT / 5:
				return false
	if attack_count > 1:
		return false
	if attack_count == 0:
		# A fixture exercising only the authentic shove/Block remains inert;
		# a stored hit without an authored attack is always invalid.
		return not actor.has(CHARGE_PENDING)
	var amount := charge_attack_amount(actor)
	if amount < 0:
		return false
	if not actor.has(CHARGE_PENDING):
		return true
	var pending: Variant = actor[CHARGE_PENDING]
	return pending is Dictionary and pending.size() == 2 \
		and pending.get("amount") is int and pending["amount"] == amount \
		and pending.get("target_position") is int \
		and pending["target_position"] >= 1 \
		and pending["target_position"] <= CombatParty.PARTY_SIZE


## The display never owns the latch: an unarmed Ram shows zero damage and an
## armed Ram shows the projected strike stored on that very same actor.
static func charge_announcement(actor: Dictionary, cached: Dictionary) -> Dictionary:
	var action: Dictionary = cached.duplicate(true)
	if actor.get(CHARGE_FLAG, false) != true:
		return action
	if actor.has(CHARGE_PENDING):
		var stored: Dictionary = actor[CHARGE_PENDING]
		var quote := CombatEnemyKeywordRules.new().project_charge_step(stored["amount"], true)
		action = {"type": "attack", "amount": quote["damage"],
			"target_position": stored["target_position"],
			"enemy_position": cached["enemy_position"]}
	elif action.get("type") == "attack":
		action["amount"] = 0
	return action

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
	if definitions.is_empty() or definitions.size() > 4:
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
		if not position is int or position < 1 or position > 4 or position in seen_positions:
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
	for actor in roster:
		if not valid_charge_actor(actor):
			return false
	if roster.size() != _definitions.size() or roster.size() > enemies.get_capacity() \
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
		# The Boss catalog now also contains the Colossus. Select only the
		# authentic Behemoth record; duplicate IDs fail before any RNG draw.
		var canonical: Variant = boss_data
		if boss_data is Array:
			canonical = {}
			for candidate in boss_data:
				if not candidate is Dictionary:
					return false
				if candidate.get("id") == CombatBehemothPhaseRules.BOSS_ID:
					if not canonical.is_empty():
						return false
					canonical = candidate
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
	if body.has("hits") and not _normalize_integral(body, "hits", 2):
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


## The authored Quilt Termite split publishes one replacement half in its own
## slot and one appended half. The bound schedule must grow with that roster:
## the replaced source's stale announcement is swapped for the left child's own
## single front attack and the right child appends its own. Both children carry
## exactly one alternative, so this admission consumes no run RNG; every other
## slot's cached announcement stays untouched.
func can_admit_split(enemies: CombatEnemies, source: Variant,
		proposed: Variant = null) -> bool:
	return not _split_proposal(enemies, source, proposed).is_empty()


## Commit the preflighted split announcements. It re-derives the same proposal
## from the current bound roster before writing, so a stale or forged caller can
## never publish a partial schedule.
func admit_split(enemies: CombatEnemies, source: Variant) -> bool:
	var proposal := _split_proposal(enemies, source, null)
	if proposal.is_empty():
		return false
	_slots = proposal["slots"]
	_cache = proposal["cache"]
	return true


func _split_proposal(enemies: CombatEnemies, source: Variant,
		proposed: Variant = null) -> Dictionary:
	if not _valid or not _bound or enemies == null or not is_instance_valid(enemies) \
			or enemies != _enemies or _rng == null or not is_instance_valid(_rng) \
			or _party == null or not is_instance_valid(_party):
		return {}
	if not enemies.is_valid() or not _party.is_valid() \
			or living_positions(_party).is_empty():
		return {}
	var roster: Array = []
	if proposed == null:
		roster = enemies.get_enemies()
	elif proposed is Array:
		roster = proposed
	else:
		return {}
	var old_size := _slots.size()
	if old_size < 1 or old_size >= enemies.get_capacity() \
			or roster.size() != old_size + 1 or _cache.size() != old_size:
		return {}
	if not source is int or source < 1 or source > old_size:
		return {}
	for index in range(old_size):
		if _slots[index].get("enemy_position") != index + 1 \
				or _cache[index].get("enemy_position") != index + 1:
			return {}
	var left: Dictionary = roster[source - 1]
	var right: Dictionary = roster[old_size]
	if not _valid_split_half(left, source, CombatEnemies.HALF_LEFT_ID) \
			or not _valid_split_half(right, old_size + 1, CombatEnemies.HALF_RIGHT_ID):
		return {}
	var left_slot := _weighted_slot(source, left.get("intent"))
	var right_slot := _weighted_slot(old_size + 1, right.get("intent"))
	if left_slot.is_empty() or right_slot.is_empty():
		return {}
	var batch := _draw_batch([left_slot, right_slot], _party, _rng)
	if batch.size() != 2 or batch[0].get("enemy_position") != source \
			or batch[1].get("enemy_position") != old_size + 1:
		return {}
	var slots: Array[Dictionary] = _slots.duplicate(true)
	slots[source - 1] = left_slot
	slots.append(right_slot)
	var cache: Array[Dictionary] = _cache.duplicate(true)
	cache[source - 1] = batch[0]
	cache.append(batch[1])
	return {"slots": slots, "cache": cache}


## Only the freshly built half-actors from CombatEnemies.stage_split_on_death
## qualify: full half HP, no inherited Block/status/special flag and exactly one
## plain front attack. Any other roster change is refused.
static func _valid_split_half(record: Dictionary, position: int, id: String) -> bool:
	if record.get("id") != id or record.get("position") != position:
		return false
	var maximum = record.get("max_hp")
	if not maximum is int or maximum <= 0 or record.get("hp") != maximum \
			or record.get("block") != 0:
		return false
	if record.has("enemy_position") and record["enemy_position"] != position:
		return false
	if record.has("statuses") or record.has(CombatEnemies.SPLIT_FIELD) \
			or record.has("revive_once") or record.has("revived") \
			or record.has("chew_block_on_attack"):
		return false
	var spec = record.get("intent")
	if not spec is Dictionary or spec.get("target") != "front":
		return false
	var actions = spec.get("actions")
	if not actions is Array or actions.size() != 1:
		return false
	var action = actions[0]
	return action is Dictionary and action.get("type") == "attack" \
		and action.get("amount") is int and action["amount"] >= 1 \
		and action.get("weight") == 1 and action.size() == 3


## One announcement per slot. A single authored alternative needs no draw; a
## real weighted choice and a random target each consume the run RNG once.
static func _draw_batch(slots: Array, party: CombatParty,
		rng: RandomNumberGenerator, forced: Dictionary = {}) -> Array[Dictionary]:
	var batch: Array[Dictionary] = []
	# Nothing is drawn for a party with no living hero to announce against.
	if living_positions(party).is_empty():
		return batch
	for slot in slots:
		if forced.has(slot["enemy_position"]):
			batch.append(forced[slot["enemy_position"]].duplicate(true))
			continue
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
	if kind == "summon":
		return action.size() == 2 and amount == 0
	if kind == "steal_gold":
		return action.size() == 2 and amount > 0
	if kind in ["block", "buff"]:
		return action.size() == 2 and (kind == "block" or amount > 0)
	if kind not in ["attack", "shove", "debuff", "snip_block"]:
		return false
	var target = action.get("target_position")
	if not target is int or target < 1 or target > 3:
		return false
	if kind == "attack":
		var extra := 0
		if action.has("move"):
			if not action.move is String or action.move != "attack2":
				return false
			extra = 1
		if action.has("hits"):
			return action.size() == 4 + extra and action.hits is int and action.hits == 2
		return action.size() == 3 + extra
	if kind == "snip_block":
		return action.size() == 3 and amount == 0
	if kind == "debuff":
		return action.size() == 4 and amount > 0 and action.get("status") is String \
			and (action.status in ["bleed", "weak", "exposed"] \
				or (action.status == "blind_next_attack" and amount == 1))
	var direction = action.get("direction")
	return action.size() == 4 and amount == 0 and direction is int \
		and direction in [-1, 1] and target + direction >= 1 and target + direction <= 3


func is_valid() -> bool:
	return _valid


func get_intents() -> Array[Dictionary]:
	if not _valid:
		return []
	if _bound:
		var result: Array[Dictionary] = _cache.duplicate(true)
		if _enemies != null:
			for index in range(result.size()):
				var actor := _enemies.get_enemy(index + 1)
				if valid_charge_actor(actor):
					result[index] = charge_announcement(actor, result[index])
		return result
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
		# A genuine spawn is appended only after its birth phase has committed.
		# Validate the complete battle-only child before any next-turn RNG draw.
		var roster := _enemies.get_enemies()
		if roster.size() != _slots.size():
			if roster.size() != _slots.size() + 1 or roster.size() > _enemies.get_capacity():
				return false
			var child: Dictionary = roster[roster.size() - 1]
			var expected := CombatEnemies.broodling_definition()
			for field in expected:
				if child.get(field) != expected[field]:
					return false
			if child.get("position") != roster.size() or child.get("hp") != 8 or child.get("block") != 0:
				return false
			var parent_latched := false
			for original in roster.slice(0, _slots.size()):
				if original.get("id") in [CombatEnemies.MOTH_ID, CombatEnemies.MOTH_QUEEN_ID] \
						and original.get(CombatEnemies.BROODLING_LATCH) == true:
					parent_latched = true
			if not parent_latched:
				return false
			var child_slot := _weighted_slot(roster.size(), child.intent)
			if child_slot.is_empty():
				return false
			next_slots = _slots.duplicate(true)
			next_slots.append(child_slot)
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
		# A held strike is this actor's next beat, not a new weighted choice.
		# Other actors draw normally; the held Ram spends no extra run RNG.
		var forced: Dictionary = {}
		for index in range(roster.size()):
			var actor: Dictionary = roster[index]
			if not valid_charge_actor(actor):
				return false
			if actor.get(CHARGE_FLAG, false) == true \
					and actor.has(CHARGE_PENDING) and actor.get("hp", 0) > 0:
				var pending: Dictionary = actor[CHARGE_PENDING]
				var step := CombatEnemyKeywordRules.new().project_charge_step(
					pending["amount"], true)
				if not step["ok"]:
					return false
				forced[index + 1] = {"type": "attack", "amount": step["damage"],
					"target_position": pending["target_position"], "enemy_position": index + 1}
		var batch := _draw_batch(next_slots, _party, _rng, forced)
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
