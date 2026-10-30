class_name CombatScarecrowHarvestFrightCards
extends RefCounted
## Scene-free Harvest Fright resolver. No hand/app registration; a later task owns live wiring.
## One paid enemy_all play hits each living authored slot independently, then Weaks/Fears survivors.
## CombatStatuses and CombatStatusTurnBatch alone own Fear's next-owner-turn expiry.

const BASE_ID := "scarecrow_harvest_fright"
const PLUS_ID := "scarecrow_harvest_fright_plus"
const OWNER_ID := "scarecrow"
const COST := 3
const NO_TARGET_SLOT := 0
const TO_POSITIONS: Array[int] = [1, 2, 3]
const FROM_POSITIONS: Array[int] = [1, 2, 3]
const FEAR_KEY := "cannot_buff_next_turn"
const WEAK_KEY := "weak"
const DAMAGE_STATUS_KEYS := ["bleed", "weak", "exposed", "tangled", "riposte"]

func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and (card_id == BASE_ID or card_id == PLUS_ID) \
		and _authenticate()


## The caller supplies only the held ID; enemy_all has no selected target (zero sentinel).
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int = NO_TARGET_SLOT) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position)
	if not plan.get("ok", false):
		return {"ok": false, "reason": plan.get("reason", "refused")}
	# All spending, status admissions and individual hit arithmetic have already been checked.
	if not deck.try_spend_energy(COST):
		return {"ok": false, "reason": "insufficient_energy"}
	if not deck.discard_played(plan["card_id"]):
		return {"ok": false, "reason": "card_not_held"}
	var attacker: Dictionary = _attack_statuses(party._heroes[plan["owner_position"] - 1].get("statuses", {}))
	var bridge := CombatStatusAttacks.new()
	var hits: Array[Dictionary] = []
	for position: int in plan["targets"]:
		# Positions are fixed. A slain slot must not inherit the effects of another slot.
		if enemies.is_slain(position):
			continue
		var before: Dictionary = enemies.get_enemy(position)
		var defender: Dictionary = _attack_statuses(before.get("statuses", {}))
		var attack: Dictionary = bridge.resolve_vs_enemy(enemies, position, plan["base_damage"],
			attacker, defender)
		# Guaranteed by preflight, including valid per-foe damage and model eligibility.
		if not attack.get("ok", false):
			return {"ok": false, "reason": "bridge_rejected", "hits": hits,
				"energy_spent": COST}
		var survived: bool = not enemies.is_slain(position)
		if survived:
			enemies.apply_statuses({position: {WEAK_KEY: plan["weak"]}})
			enemies._enemies[position - 1]["statuses"][FEAR_KEY] = true
		var after: Dictionary = enemies.get_enemy(position)
		hits.append({
			"position": position,
			"base_damage": plan["base_damage"],
			"damage": attack["damage"],
			"block_absorbed": attack["block_absorbed"],
			"hp_loss": attack["hp_loss"],
			"hp_before": before["hp"], "hp_after": after["hp"],
			"block_before": before["block"], "block_after": after["block"],
			"weak_applied": plan["weak"] if survived else 0,
			"fear_applied": survived,
		})
	return {"ok": true, "reason": "applied", "card_id": plan["card_id"],
		"cost": COST, "energy_spent": COST, "energy_before": plan["energy_before"],
		"energy_after": deck.energy, "owner_position": plan["owner_position"],
		"target_position": NO_TARGET_SLOT, "targets": plan["targets"].duplicate(),
		"hits": hits}


## Read-only preflight: malformed structures, forged linked printings, unheld/replayed IDs,
## bad seats, status counters, weak overflows, and invalid target all fail BEFORE mutation.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int) -> Dictionary:
	if deck == null or party == null or enemies == null:
		return _reject("invalid_request")
	if typeof(card_id) != TYPE_STRING or (card_id != BASE_ID and card_id != PLUS_ID):
		return _reject("unsupported_card")
	if not _authenticate():
		return _reject("catalog_mismatch")
	if deck.combat_state == null or deck._rng == null or not deck.turn_active:
		return _reject("inactive_turn")
	if not _valid_party(party):
		return _reject("invalid_party")
	if not _valid_enemies(enemies):
		return _reject("invalid_enemies")
	var owner_position := 0
	for hero: Dictionary in party._heroes:
		if hero["id"] == OWNER_ID:
			if owner_position != 0:
				return _reject("duplicate_owner")
			owner_position = hero["position"]
	if owner_position == 0:
		return _reject("owner_missing")
	if not FROM_POSITIONS.has(owner_position):
		return _reject("invalid_owner_position")
	if party._heroes[owner_position - 1]["hp"] == 0:
		return _reject("owner_downed")
	# Batch works on detached records: verifies canonical Fear booleans and every status key.
	if not CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes()).get("ok", false):
		return _reject("malformed_statuses")
	if not CombatStatusTurnBatch.new().tick_side("enemies", enemies._enemies.duplicate(true)).get("ok", false):
		return _reject("malformed_statuses")
	if not deck.hand.has(card_id):
		return _reject("card_not_held")
	if deck.energy < COST:
		return _reject("insufficient_energy")
	if target_position != NO_TARGET_SLOT:
		return _reject("invalid_target")
	var targets: Array[int] = []
	for position in TO_POSITIONS:
		if position <= enemies._enemies.size() and enemies._enemies[position - 1]["hp"] > 0:
			targets.append(position)
	if targets.is_empty():
		return _reject("no_living_targets")
	var weak: int = 3 if card_id == PLUS_ID else 2
	var base_damage: int = 6 if card_id == PLUS_ID else 4
	var proposed: Dictionary = {}
	var owner_statuses: Dictionary = _attack_statuses(party._heroes[owner_position - 1].get("statuses", {}))
	var rules := CombatStatuses.new()
	for position: int in targets:
		var enemy: Dictionary = enemies._enemies[position - 1]
		var statuses: Dictionary = enemy.get("statuses", {})
		# Enemies.can_apply_statuses verifies the overflow and the entire roster; no HP is changed.
		proposed[position] = {WEAK_KEY: weak}
		var projected: Dictionary = statuses.duplicate(true)
		projected[WEAK_KEY] = int(projected.get(WEAK_KEY, 0)) + weak if \
			int(projected.get(WEAK_KEY, 0)) <= CombatEnemies.MAX_INT - weak else -1
		projected[FEAR_KEY] = true
		if not rules._valid_statuses(projected):
			return _reject("malformed_statuses")
		# Bridge accepts damage statuses and Fear; role-only Dodge/Blind tokens are
		# validated above but remain untouched, not spuriously consumed by an area hit.
		if rules.adjusted_attack_damage(base_damage, owner_statuses,
				_attack_statuses(statuses)) <= 0:
			return _reject("arithmetic_overflow")
	if not enemies.can_apply_statuses(proposed):
		return _reject("malformed_statuses")
	var projected_roster: Array = enemies._enemies.duplicate(true)
	for position: int in targets:
		var projected_enemy: Dictionary = projected_roster[position - 1]
		var projected_statuses: Dictionary = projected_enemy.get("statuses", {}).duplicate(true)
		projected_statuses[WEAK_KEY] = int(projected_statuses.get(WEAK_KEY, 0)) + weak
		projected_statuses[FEAR_KEY] = true
		projected_enemy["statuses"] = projected_statuses
	if not CombatStatusTurnBatch.new().tick_side("enemies", projected_roster).get("ok", false):
		return _reject("malformed_statuses")
	return {"ok": true, "reason": "ready", "card_id": card_id,
		"owner_position": owner_position, "energy_before": deck.energy,
		"base_damage": base_damage, "weak": weak, "targets": targets}


func _reject(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


## Validate the entire authored record including metadata, not only damage/Weak fields.
## The matching base AND '+' records must exist and name each other reciprocally.
func _authenticate() -> bool:
	return _same_typed(_catalog_definition(BASE_ID), _expected_definition(false)) \
		and _same_typed(_catalog_definition(PLUS_ID), _expected_definition(true))


## Overrideable lookup for negative forged-catalog regressions; never trusts caller records.
func _catalog_definition(card_id: String) -> Dictionary:
	return ScarecrowPoolCards.new().get_definition(card_id)


func _expected_definition(upgraded: bool) -> Dictionary:
	var definition := {
		"id": PLUS_ID if upgraded else BASE_ID,
		"display_name": "Harvest Fright+" if upgraded else "Harvest Fright",
		"owner": OWNER_ID, "cost": COST,
		"from_positions": FROM_POSITIONS.duplicate(),
		"target_kind": "enemy_all", "to_positions": TO_POSITIONS.duplicate(),
		"effects": {"damage": 6 if upgraded else 4, "weak": 3 if upgraded else 2,
			"cannot_buff_next_turn": true},
		"illustration_path": "res://assets/paper/cards/" + BASE_ID + ".png",
		"starting_copies": 0, "rarity": "rare", "reward_eligible": not upgraded,
	}
	if upgraded:
		definition["upgrade_of"] = BASE_ID
	else:
		definition["upgrade_id"] = PLUS_ID
	return definition


func _same_typed(actual: Variant, expected: Variant) -> bool:
	if typeof(actual) != typeof(expected):
		return false
	if expected is Dictionary:
		if actual.size() != expected.size():
			return false
		for key in expected:
			if not actual.has(key) or not _same_typed(actual[key], expected[key]):
				return false
		return true
	if expected is Array:
		if actual.size() != expected.size():
			return false
		for index in range(expected.size()):
			if not _same_typed(actual[index], expected[index]):
				return false
		return true
	return actual == expected


func _valid_party(party: CombatParty) -> bool:
	if party._heroes.size() != CombatParty.PARTY_SIZE:
		return false
	var seen: Dictionary = {}
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = party._heroes[index]
		if not _valid_actor(hero, index + 1, seen):
			return false
	return true


func _valid_enemies(enemies: CombatEnemies) -> bool:
	var count: int = enemies._enemies.size()
	if count < 1 or count > CombatEnemies.MAX_ENEMIES:
		return false
	var seen: Dictionary = {}
	for index in range(count):
		var enemy: Dictionary = enemies._enemies[index]
		if not _valid_actor(enemy, index + 1, seen) \
				or not CombatEnemies.valid_revive_flags(enemy) \
				or not CombatEnemies.valid_split_flags(enemy):
			return false
		# A pending death-revival is not a stable preflight state: reading it would mutate
		# an otherwise rejected attempt, so refuse instead of settling it in this service.
		if enemy["hp"] == 0 and CombatEnemies.revive_pending(enemy):
			return false
	return true


func _valid_actor(actor: Dictionary, position: int, seen: Dictionary) -> bool:
	var id: Variant = actor.get("id")
	var seat: Variant = actor.get("position")
	var maximum: Variant = actor.get("max_hp")
	var hp: Variant = actor.get("hp")
	var block: Variant = actor.get("block")
	if not id is String or id.is_empty() or seen.has(id) \
			or not seat is int or seat != position \
			or not maximum is int or maximum <= 0 \
			or not hp is int or hp < 0 or hp > maximum \
			or not block is int or block < 0 \
			or not actor.get("statuses", {}) is Dictionary:
		return false
	seen[id] = true
	return true


## Use the shared attack bridge only for damage modifiers, preserving canonical one-shot tokens
## and other statuses in the untouched authoritative maps.
func _attack_statuses(statuses: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in statuses:
		if key in DAMAGE_STATUS_KEYS or key == FEAR_KEY:
			result[key] = statuses[key]
	return result
