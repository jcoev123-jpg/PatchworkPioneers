class_name CombatButtonGolemAreaCards
extends RefCounted
## V3-1 scene-free paid resolver for Button Golem's four reward-pool area printings:
## Popping Volley (+): two independent hits on every living enemy.
## Buttonstorm (+): one hit on every living enemy, scaled by earlier popped buttons.
##
## One successful call spends 2 energy, discards exactly one genuinely held copy and resolves the
## printed area attack against the real CombatEnemies roster through CombatStatusAttacks, so every
## hit is status-adjusted on its own and absorbed Block-before-HP by the roster. No enemy slot is
## selected: both printings are authored `enemy_all`, so every living slot of the ACTUAL validated
## roster is hit - the default three foes, or the explicit opt-in four - and slain slots are skipped
## without ever compacting positions. The printed TO array stays the authored [1,2,3] contract and
## is never rewritten or used as a cap: it is an authentication fact, not the target list.
##
## Popping Volley prints two INDEPENDENT hits of base 3 (4 upgraded) per living enemy. Survival is
## re-checked before every hit, so an enemy slain by its first hit never receives the second, and
## the two hits are never merged for status math or receipts.
##
## Buttonstorm prints one hit per living enemy whose raw base is the printed 4 (5 upgraded) times
## the Golem's authoritative per-combat buttons_popped count written by CombatButtonGolemPopCards.
## The counter is read, never spent, incremented or reset, and the owner's Block is untouched. A
## zero counter is a valid paid zero-damage hit, never a refusal or an invented bonus: the shared
## positive-base rule in CombatStatuses only adds Tangled's +2 to positive raw damage.
##
## Data only elsewhere: button_golem_pool_cards.gd owns the four IDs, their base/"+" link and their
## art paths, but no live hand, reward, party-picker, map or app path registers them yet. This
## helper is the callable combat rules layer a later wiring task must call, never a second live
## hand and never a run-wallet/spend path or a new combat state machine.
##
## Every failing precondition is refused by a complete read-only preflight BEFORE the energy charge,
## and no resolution path draws seeded RNG.
##
## Authoritative status maps may legitimately carry a Dodge token (`dodge_next_attack: 0|1`, e.g.
## from the Lantern Monk's Moth Shroud). Dodge never modifies this attack's damage and the shared
## CombatStatusAttacks bridge does not model it, so such a play must still land: every authoritative
## map is validated in full (including the Dodge token), then only the damage-status subset is
## handed to the shared validators and the bridge. The real tokens are never mutated or spent.

const OWNER_ID := "button_golem"
const COST := 2
const BUTTONS_KEY := "buttons_popped"
## The status keys whose counts modify one attack, exactly as CombatStatusAttacks accepts them.
const ATTACK_STATUS_KEYS: Array[String] = ["bleed", "weak", "exposed", "tangled", "riposte"]
## An authoritative one-attack Dodge token: one unspent Dodge, or an explicit zero. It is not a
## damage modifier for this attack, so it is validated here and omitted from bridge-bound maps.
const DODGE_STATUS_KEY := "dodge_next_attack"
## `enemy_all` selects no slot at all; the real living roster is what resolves. The authored TO
## window below is still authenticated exactly, but it never limits a genuine opt-in fourth foe.
const NO_TARGET_SLOT := 0
const TO_POSITIONS: Array[int] = [1, 2, 3]
const VOLLEY_FROM_POSITIONS: Array[int] = [1, 2]
const STORM_FROM_POSITIONS: Array[int] = [1]
const VOLLEY_HIT_COUNT := 2

## Exact authored printings and their printed magnitudes. Popping Volley prints damage per hit;
## Buttonstorm prints damage per earlier popped button.
const VOLLEY_PRINTINGS := {
	"button_golem_popping_volley": 3,
	"button_golem_popping_volley_plus": 4,
}
const STORM_PRINTINGS := {
	"button_golem_buttonstorm": 4,
	"button_golem_buttonstorm_plus": 5,
}


## Pure query: an authentic area printing ID, never a malformed or aliased value.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING \
		and (VOLLEY_PRINTINGS.has(card_id) or STORM_PRINTINGS.has(card_id))


## Paid resolution against real model state. Refusals return a receipt with exactly the same field
## set, reason "..." and no state change at all: no energy, card, discard, damage, Block, popped
## button, hero record, enemy record or seeded RNG draw.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int = NO_TARGET_SLOT) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position)
	if not plan["ok"]:
		return plan
	# Every operation below is guaranteed by preflight and nothing here draws RNG.
	var id: String = plan["card_id"]
	deck.try_spend_energy(int(plan["cost"]))
	deck.discard_played(id)
	plan["energy_spent"] = int(plan["cost"])
	var owner: Dictionary = party._heroes[int(plan["owner_position"]) - 1]
	var attacks := CombatStatusAttacks.new()
	var base_damage: int = int(plan["base_damage"])
	var hit_count: int = int(plan["hit_count"])
	var targets: Array[int] = plan["targets"]
	var owner_statuses: Variant = _attack_statuses(owner.get("statuses", {}))
	var hits: Array[Dictionary] = []
	for position: int in targets:
		for hit_index in range(1, hit_count + 1):
			# Re-check survival before EVERY hit: a lethal first hit skips the second, and a slain
			# slot is never targeted and never moves the surviving positions.
			if enemies.is_slain(position):
				break
			var target: Dictionary = enemies.get_enemy(position)
			var target_statuses: Variant = _attack_statuses(target.get("statuses", {}))
			var event: Dictionary = {}
			if owner_statuses != null and target_statuses != null:
				# Detached attack-status maps: preflight already validated the authoritative maps,
				# including a Dodge token the damage bridge deliberately never sees.
				event = attacks.resolve_vs_enemy(enemies, position, base_damage, owner_statuses,
					target_statuses)
			if not event.get("ok", false):
				# Preflight proves every bridge call can succeed; if one still refuses, report the
				# truth (the energy is already spent) instead of claiming a resolved attack.
				plan["hits"] = hits
				plan["ok"] = false
				plan["reason"] = "bridge_rejected"
				return plan
			hits.append({
				"position": position,
				"hit": hit_index,
				"base_damage": base_damage,
				"damage": int(event["damage"]),
				"block_absorbed": int(event["block_absorbed"]),
				"hp_loss": int(event["hp_loss"]),
			})
	plan["hits"] = hits
	plan["reason"] = "applied"
	return plan


## Read-only preflight: authenticate the card, validate every real roster/status/counter record,
## bind the Golem to its actual seat, prove at least one living target and size every hit before
## anything is charged.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int) -> Dictionary:
	var plan := {
		"ok": false, "reason": "unsupported_card",
		"card_id": card_id if typeof(card_id) == TYPE_STRING else "",
		"cost": 0, "owner_position": 0, "target_position": target_position,
		"buttons_popped": 0, "base_damage": 0, "hit_count": 0,
		"energy_spent": 0, "targets": [], "hits": [],
	}
	if not is_supported_card(card_id):
		return plan
	var printed: Dictionary = _authenticate(card_id)
	if printed.is_empty():
		plan["reason"] = "catalog_mismatch"
		return plan
	plan["cost"] = COST
	if deck == null or party == null or enemies == null:
		plan["reason"] = "invalid_request"
		return plan
	if deck.combat_state == null:
		plan["reason"] = "invalid_deck"
		return plan
	if not _valid_heroes(party) or not _valid_enemies(enemies):
		plan["reason"] = "invalid_roster"
		return plan
	if not deck.turn_active:
		plan["reason"] = "inactive_turn"
		return plan

	# Bind the Golem to its actual current ID/seat; never assume a fixed slot.
	var owner_position := 0
	for hero: Dictionary in party._heroes:
		if hero.get("id") != OWNER_ID:
			continue
		if owner_position != 0:
			plan["reason"] = "duplicate_owner"
			return plan
		owner_position = int(hero["position"])
	if owner_position == 0:
		plan["reason"] = "owner_missing"
		return plan
	plan["owner_position"] = owner_position
	var from_positions: Array[int] = printed["from_positions"]
	if not from_positions.has(owner_position):
		plan["reason"] = "invalid_owner_position"
		return plan
	var owner: Dictionary = party._heroes[owner_position - 1]
	if owner["hp"] <= 0:
		plan["reason"] = "owner_torn"
		return plan
	if not _distinct_hero_ids(party):
		plan["reason"] = "invalid_roster"
		return plan
	# The shared turn-batch validator applies the exact CombatStatuses keys and counts, over the
	# damage-status subset of every authoritative map (Dodge is validated separately, never lost).
	if not _valid_statuses(party, enemies):
		plan["reason"] = "malformed_statuses"
		return plan
	var owner_statuses: Variant = _attack_statuses(owner.get("statuses", {}))
	if owner_statuses == null:
		plan["reason"] = "malformed_statuses"
		return plan
	# The counter is authoritative state: malformed or negative values refuse the play outright,
	# even for Popping Volley, which reads but never spends it.
	var button_count_value: Variant = owner.get(BUTTONS_KEY, 0)
	if not button_count_value is int or button_count_value < 0:
		plan["reason"] = "malformed_button_count"
		return plan
	var button_count: int = button_count_value
	plan["buttons_popped"] = button_count
	if not deck.hand.has(card_id):
		plan["reason"] = "card_not_held"
		return plan
	if deck.energy < COST:
		plan["reason"] = "insufficient_energy"
		return plan
	if target_position != NO_TARGET_SLOT:
		plan["reason"] = "invalid_target"
		return plan

	# `enemy_all` hits every enemy that is alive now, in roster order, with no slot chosen.
	var targets: Array[int] = []
	var roster: Array[Dictionary] = enemies.get_enemies()
	for index in range(roster.size()):
		var position := index + 1
		if enemies.is_slain(position):
			continue
		targets.append(position)
	if targets.is_empty():
		plan["reason"] = "no_living_targets"
		return plan

	var base_damage: Variant = _raw_base_damage(printed, button_count)
	if base_damage == null:
		plan["reason"] = "arithmetic_overflow"
		return plan
	var base: int = base_damage

	# Every hit must be sizeable before payment. A positive-base attack the shared status rules
	# collapse to zero is an overflow, never a silent free hit; zero raw damage stays zero.
	if base > 0:
		var rules := CombatStatuses.new()
		for position: int in targets:
			var target: Dictionary = enemies.get_enemy(position)
			var target_statuses: Variant = _attack_statuses(target.get("statuses", {}))
			if target_statuses == null:
				plan["reason"] = "malformed_statuses"
				return plan
			if rules.adjusted_attack_damage(base, owner_statuses, target_statuses) <= 0:
				plan["reason"] = "arithmetic_overflow"
				return plan
	plan["base_damage"] = base
	plan["hit_count"] = int(printed["hit_count"])
	plan["targets"] = targets
	plan["ok"] = true
	plan["reason"] = "ready"
	return plan


## The raw printed base before any status adjustment. Buttonstorm multiplies the printed per-pop
## value by the Golem's earlier Pop count, checked so the product cannot overflow.
func _raw_base_damage(printed: Dictionary, button_count: int) -> Variant:
	if str(printed["shape"]) != "storm":
		return int(printed["damage"])
	var per_pop: int = int(printed["per_pop"])
	@warning_ignore("integer_division")
	var max_count: int = CombatParty.MAX_INT / per_pop
	if button_count > max_count:
		return null
	return button_count * per_pop


## Authenticate one printing against its own authored pool record. Both printings must still point
## at each other, so a rewritten, relinked or unauthentic record is never paid for.
func _authenticate(card_id: String) -> Dictionary:
	var base_id: String = card_id.trim_suffix("_plus")
	var plus_id: String = base_id + "_plus"
	if not is_supported_card(base_id) or not is_supported_card(plus_id):
		return {}
	var base_record: Dictionary = _catalog_definition(base_id)
	var plus_record: Dictionary = _catalog_definition(plus_id)
	if not _matches_authored(base_record, base_id, false):
		return {}
	if not _matches_authored(plus_record, plus_id, true):
		return {}
	if base_record.get("upgrade_id") != plus_id:
		return {}
	if plus_record.get("upgrade_of") != base_id:
		return {}
	if VOLLEY_PRINTINGS.has(card_id):
		return {"shape": "volley", "from_positions": VOLLEY_FROM_POSITIONS.duplicate(),
			"hit_count": VOLLEY_HIT_COUNT, "damage": int(VOLLEY_PRINTINGS[card_id])}
	return {"shape": "storm", "from_positions": STORM_FROM_POSITIONS.duplicate(),
		"hit_count": 1, "per_pop": int(STORM_PRINTINGS[card_id])}


## The one authored record for an ID, detached. A subclass may serve a forged record so a
## rewritten catalog can be proven inert before any energy, hand, HP, Block or RNG state moves.
func _catalog_definition(card_id: String) -> Dictionary:
	return ButtonGolemPoolCards.new().get_definition(card_id)


## Exact contract for one record: identity, owner, energy cost, `enemy_all` FROM/TO slots, the
## complete printed effect set with exact Variant types and magnitudes, no starter copies and the
## base/"+" reward eligibility the catalog authors. Rarity is deliberately not part of the contract.
func _matches_authored(definition: Dictionary, card_id: String, upgraded: bool) -> bool:
	if definition.is_empty() or definition.get("id") != card_id:
		return false
	if definition.get("owner") != OWNER_ID:
		return false
	var cost: Variant = definition.get("cost")
	if not cost is int or cost != COST:
		return false
	if definition.get("target_kind") != "enemy_all":
		return false
	var from_positions: Array[int] = VOLLEY_FROM_POSITIONS if VOLLEY_PRINTINGS.has(card_id) \
		else STORM_FROM_POSITIONS
	if not _exact_positions(definition.get("from_positions"), from_positions):
		return false
	if not _exact_positions(definition.get("to_positions"), TO_POSITIONS):
		return false
	var effects_value: Variant = definition.get("effects")
	if not effects_value is Dictionary:
		return false
	var effects: Dictionary = effects_value
	var expected_effects: Dictionary = _expected_effects(card_id)
	if effects.size() != expected_effects.size():
		return false
	for key: String in expected_effects:
		if not effects.has(key):
			return false
		var value: Variant = effects[key]
		var expected: Variant = expected_effects[key]
		if typeof(value) != typeof(expected) or value != expected:
			return false
	var starting_copies: Variant = definition.get("starting_copies")
	if not starting_copies is int or starting_copies != 0:
		return false
	var reward_eligible: Variant = definition.get("reward_eligible")
	if not reward_eligible is bool or reward_eligible != (not upgraded):
		return false
	return true


## The complete printed effect set for one printing, keyed exactly as the pool authored it.
func _expected_effects(card_id: String) -> Dictionary:
	if VOLLEY_PRINTINGS.has(card_id):
		return {"damage": int(VOLLEY_PRINTINGS[card_id]), "hit_count": VOLLEY_HIT_COUNT,
			"independent_hits": true, "living_targets_only": true}
	return {"damage_per_button_popped": int(STORM_PRINTINGS[card_id]),
		"living_targets_only": true}


func _exact_positions(value: Variant, expected: Array[int]) -> bool:
	if not value is Array or value.size() != expected.size():
		return false
	for index in range(expected.size()):
		if not value[index] is int or value[index] != expected[index]:
			return false
	return true


## Three genuine seats in order with nonempty string IDs and sane per-combat records.
## ID uniqueness is checked separately so a second Golem reports duplicate_owner first.
func _valid_heroes(party: CombatParty) -> bool:
	if not party.is_valid() or party._heroes.size() != CombatParty.PARTY_SIZE:
		return false
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Variant = party._heroes[index]
		if not hero is Dictionary:
			return false
		var record: Dictionary = hero
		var hero_id: Variant = record.get("id")
		if not hero_id is String or hero_id.is_empty():
			return false
		var position: Variant = record.get("position")
		if not position is int or position != index + 1:
			return false
		var max_hp: Variant = record.get("max_hp")
		if not max_hp is int or max_hp <= 0:
			return false
		var hp: Variant = record.get("hp")
		if not hp is int or hp < 0 or hp > max_hp:
			return false
		var block: Variant = record.get("block")
		if not block is int or block < 0:
			return false
		if not record.get("statuses", {}) is Dictionary:
			return false
	return true


func _distinct_hero_ids(party: CombatParty) -> bool:
	var seen: Dictionary = {}
	for hero: Dictionary in party._heroes:
		var hero_id: String = hero["id"]
		if seen.has(hero_id):
			return false
		seen[hero_id] = true
	return true


## One to the roster's genuine capacity of enemy slots in order with nonempty distinct string IDs
## and sane records. The capacity must be one the model can legitimately hold: the default three, or
## an explicit opt-in four that only `CombatEnemies.new(definitions, OPT_IN_MAX_ENEMIES)` grants.
## A default-capacity four-definition construction is empty and inert, and a tampered capacity is
## refused here, so four foes are never admitted silently. A roster that fills only part of its
## capacity stays legal. Slain slots remain valid; target eligibility is checked separately.
func _valid_enemies(enemies: CombatEnemies) -> bool:
	if not enemies.is_valid():
		return false
	var capacity: int = enemies.get_capacity()
	if capacity != CombatEnemies.MAX_ENEMIES and capacity != CombatEnemies.OPT_IN_MAX_ENEMIES:
		return false
	var roster: Array[Dictionary] = enemies.get_enemies()
	if roster.is_empty() or roster.size() > capacity:
		return false
	var seen: Dictionary = {}
	for index in range(roster.size()):
		var record: Dictionary = roster[index]
		var enemy_id: Variant = record.get("id")
		if not enemy_id is String or enemy_id.is_empty() or seen.has(enemy_id):
			return false
		seen[enemy_id] = true
		var position: Variant = record.get("position")
		if not position is int or position != index + 1:
			return false
		var max_hp: Variant = record.get("max_hp")
		if not max_hp is int or max_hp <= 0:
			return false
		var hp: Variant = record.get("hp")
		if not hp is int or hp < 0 or hp > max_hp:
			return false
		var block: Variant = record.get("block")
		if not block is int or block < 0:
			return false
		if not record.get("statuses", {}) is Dictionary:
			return false
	return true


## Fail closed on a malformed authoritative status map on either side. Every status is validated
## against the shared rules (the turn batch's exact key set), then the Dodge token is checked as
## exactly the int 0 or 1; only the damage-status subset is handed to the shared batch, which must
## accept every authoritative map the same way.
func _valid_statuses(party: CombatParty, enemies: CombatEnemies) -> bool:
	var heroes: Variant = _attack_actors(party.get_heroes())
	var roster: Variant = _attack_actors(enemies.get_enemies())
	if heroes == null or roster == null:
		return false
	var batch := CombatStatusTurnBatch.new()
	if not batch.tick_side("heroes", heroes).get("ok", false):
		return false
	# The batch validates one to three enemy actors by default; only this roster's own genuine
	# capacity (three, or an explicit opt-in four) may pass its four-actor path.
	return batch.tick_side("enemies", roster, enemies.get_capacity()).get("ok", false)


## Actor records reduced to their bridge-valid attack statuses; null when any map is malformed.
func _attack_actors(actors: Array[Dictionary]) -> Variant:
	var reduced: Array = []
	for actor: Dictionary in actors:
		var attack: Variant = _attack_statuses(actor.get("statuses", {}))
		if attack == null:
			return null
		var record: Dictionary = actor.duplicate(true)
		record["statuses"] = attack
		reduced.append(record)
	return reduced


## A detached copy of one authoritative status map holding only the counts that modify attack
## damage. Returns null for a non-Dictionary map, an unknown key, a non-int or negative count, or a
## Dodge token that is not exactly 0 or 1. The authoritative map itself is never modified.
func _attack_statuses(statuses: Variant) -> Variant:
	if not statuses is Dictionary:
		return null
	var authoritative: Dictionary = statuses
	var detached := {}
	for name in authoritative:
		if not name is String:
			return null
		var count: Variant = authoritative[name]
		if not count is int:
			return null
		if name == DODGE_STATUS_KEY:
			if count != 0 and count != 1:
				return null
			continue
		if name not in ATTACK_STATUS_KEYS or count < 0:
			return null
		detached[name] = count
	return detached
