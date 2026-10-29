class_name CombatWardenV3RivetCards
extends RefCounted
## Scene-free paid resolver for the Warden's Rivet Pummel reward cards (V3-1).
##
## Rivet Pummel prints two separate 3-damage strikes on one chosen enemy in slots 1-2, and its "+"
## prints two separate 4-damage strikes on the same window; each printing then pins that enemy for
## the Warden. The strikes are never aggregated: each printed hit is resolved on its own through
## the shared CombatStatusAttacks bridge, so the target's current Block absorbs that hit before HP,
## and the second hit is omitted once the first one is lethal.
##
## The Pinned rider is not reimplemented here. The caller supplies the battle's LIVE CombatPinned
## authority. An existing cross-hero token adds its +5 before Weak/Exposed through
## CombatPinned.bonus_for_attack for the first confirmed strike only (consume_after_attack then
## spends it once), while a same-hero Warden token neither boosts nor is consumed by this card. The
## Warden's own pin is laid exactly once AFTER the strikes, and only while the original target is
## still alive; a lethal cast leaves no new token.
##
## Weak (-25% outgoing) and Exposed (+50% incoming) keep the shared floor-once rounding, because the
## detached status maps are handed to CombatStatuses.adjusted_attack_damage inside the bridge. The
## authoritative status maps may also legally carry the one-shot Dodge/Blind tokens or the literal
## boolean Fear marker: all are validated here in full and only the damage-status subset is passed
## to the bridge, so a valid non-damage token stays untouched on its actor.
##
## Every refusal is a pure no-op: no energy, hand, pile, party record, enemy record, pin token,
## status or seeded RNG change. This is the callable combat rules slice only; admitting these IDs
## into a live hand, the reward pool, the mounted battle or any app flow is a later task.

const OWNER_ID := "warden"
const TARGET_KIND := "enemy_single"
const FROM_POSITIONS: Array[int] = [1, 2]
## The printed TO line is exactly 1-2 and never widens to a third slot, even in a larger battle.
const TO_POSITIONS: Array[int] = [1, 2]

const ATTACK_STATUS_KEYS: Array[String] = ["bleed", "weak", "exposed", "tangled", "riposte"]
const ONE_SHOT_STATUS_KEYS: Array[String] = ["dodge_next_attack", "blind_next_attack"]
const FEAR_STATUS_KEY := "cannot_buff_next_turn"

## The two authentic reward printings, each with the complete catalog line it must still carry.
## Base and "+" share owner, cost, legal seats and enemy window; only printed damage differs.
const PRINTINGS := {
	"warden_v3_rivet_pummel": {
		"display_name": "Rivet Pummel",
		"cost": 2,
		"damage": 3,
		"hits": 2,
		"pinned": true,
		"effects": {"damage": 3, "hits": 2, "pinned": true},
		"to_positions": [1, 2],
		"upgrade_id": "warden_v3_rivet_pummel_plus",
	},
	"warden_v3_rivet_pummel_plus": {
		"display_name": "Rivet Pummel+",
		"cost": 2,
		"damage": 4,
		"hits": 2,
		"pinned": true,
		"effects": {"damage": 4, "hits": 2, "pinned": true},
		"to_positions": [1, 2],
		"upgrade_of": "warden_v3_rivet_pummel",
	},
}

var _attacks := CombatStatusAttacks.new()
var _catalog: RefCounted


## `catalog` is the authoritative V3WardenPoolCards instance this service authenticates against. The
## default is the shipped catalog; an explicit instance lets a test prove that a rewritten record
## for an otherwise valid, held ID is refused instead of paid for.
func _init(catalog: Variant = null) -> void:
	_catalog = catalog if catalog is V3WardenPoolCards else V3WardenPoolCards.new()


## True only for the two authentic catalog IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and PRINTINGS.has(card_id)


## The single paid transaction: authenticate the printing, preflight the whole request, then charge
## 2 energy, discard exactly one held copy, resolve the printed separate strikes (each with its own
## current Block-before-HP receipt and its own Pinned projection) and lay one Warden pin on a
## surviving target. A refusal changes no deck, party, enemy, pin or RNG state.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		pinned: Variant, card_id: Variant, target_position: int) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, pinned, card_id, target_position)
	if not plan["ok"]:
		return plan
	var authority: CombatPinned = pinned
	# Every operation below is guaranteed by the complete preflight above, and nothing here draws
	# from the seeded run RNG.
	deck.try_spend_energy(plan["cost"])
	plan["energy_spent"] = int(plan["cost"])
	deck.discard_played(plan["card_id"])

	var hits: Array[Dictionary] = []
	for index in range(int(plan["hits_printed"])):
		if index > 0 and enemies.is_slain(target_position):
			break
		# Project the live Pinned token again for this specific hit: a cross-hero +5 can only ever
		# ride the first strike, because the confirmed first hit consumes it.
		var pin_bonus: int = authority.bonus_for_attack(enemies, target_position, OWNER_ID)
		var base_damage: int = int(plan["hit_damage"]) + pin_bonus
		var event: Dictionary = _attacks.resolve_vs_enemy(enemies, target_position, base_damage,
			plan["attacker_statuses"], plan["defender_statuses"])
		if not event.get("ok", false):
			# Preflight proves the bridge accepts these maps; if a model change still refuses, never
			# publish an applied receipt for a hit no event backs. Report the truth: the energy and
			# the held copy were already paid above.
			plan["ok"] = false
			plan["reason"] = "bridge_rejected"
			plan["hits"] = hits
			plan["hit_count"] = hits.size()
			plan["pinned"] = false
			return plan
		var consumed: bool = authority.consume_after_attack(target_position, OWNER_ID, true)
		hits.append({
			"hit": index,
			"base_damage": base_damage,
			"pin_bonus": pin_bonus,
			"pin_consumed": consumed,
			"damage": int(event["damage"]),
			"block_absorbed": int(event["block_absorbed"]),
			"hp_loss": int(event["hp_loss"]),
		})
		if enemies.is_slain(target_position):
			break

	var target: Dictionary = enemies.get_enemy(target_position)
	var laid_pin := false
	if bool(plan["applies_pinned"]) and not enemies.is_slain(target_position):
		laid_pin = authority.pin_enemy(enemies, target_position, OWNER_ID)
	plan["ok"] = true
	plan["reason"] = "applied"
	plan["hits"] = hits
	plan["hit_count"] = hits.size()
	plan["pinned"] = laid_pin
	plan["pinner"] = authority.pinner_for_enemy(target_position)
	plan["target_hp"] = int(target.get("hp", 0))
	plan["target_block"] = int(target.get("block", 0))
	plan["target_slain"] = enemies.is_slain(target_position)
	return plan


## Read-only preflight: authenticate the card against its authored catalog, bind the Warden to its
## actual seat, require the caller's live Pinned authority, and prove every downstream mutation
## will succeed before anything is charged. Never consumes or lays a Pinned token itself.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		pinned: Variant, card_id: Variant, target_position: int) -> Dictionary:
	var plan := {
		"ok": false, "reason": "unsupported_card",
		"card_id": card_id if typeof(card_id) == TYPE_STRING else "",
		"cost": 0, "energy_spent": 0, "owner_position": 0, "target_position": target_position,
		"hit_damage": 0, "hits_printed": 0, "hits": [] as Array[Dictionary], "hit_count": 0,
		"applies_pinned": false, "pinned": false, "pinner": "",
		"target_hp": 0, "target_block": 0, "target_slain": false,
	}
	if not is_supported_card(card_id):
		return plan
	var printed: Dictionary = _authenticate(card_id)
	if printed.is_empty():
		plan["reason"] = "catalog_mismatch"
		return plan
	plan["cost"] = int(printed["cost"])
	plan["hit_damage"] = int(printed["damage"])
	plan["hits_printed"] = int(printed["hits"])
	plan["applies_pinned"] = bool(printed["pinned"])
	if deck == null or party == null or enemies == null:
		plan["reason"] = "invalid_request"
		return plan
	# The shared live authority is mandatory: this resolver never manufactures a private one.
	if not pinned is CombatPinned:
		plan["reason"] = "invalid_pinned_authority"
		return plan
	if deck.combat_state == null or deck._rng == null:
		plan["reason"] = "invalid_deck"
		return plan
	if not party.is_valid() or not enemies.is_valid() or enemies.is_victorious():
		plan["reason"] = "invalid_roster"
		return plan
	if not deck.turn_active:
		plan["reason"] = "inactive_turn"
		return plan

	# Verify the complete hero roster, then bind the Warden by ID to its actual current seat.
	var heroes: Array[Dictionary] = party.get_heroes()
	var owner_position := 0
	var seen_ids: Array[String] = []
	for index in range(heroes.size()):
		var hero: Dictionary = heroes[index]
		var hero_id: Variant = hero.get("id")
		var hero_position: Variant = hero.get("position")
		var hp: Variant = hero.get("hp")
		var max_hp: Variant = hero.get("max_hp")
		var block: Variant = hero.get("block")
		if not hero_id is String or hero_id.is_empty() or seen_ids.has(hero_id):
			plan["reason"] = "invalid_roster"
			return plan
		if not hero_position is int or hero_position != index + 1:
			plan["reason"] = "invalid_roster"
			return plan
		if not max_hp is int or max_hp <= 0 or not hp is int or hp < 0 or hp > max_hp:
			plan["reason"] = "invalid_roster"
			return plan
		if not block is int or block < 0:
			plan["reason"] = "invalid_roster"
			return plan
		seen_ids.append(hero_id)
		if hero_id == OWNER_ID:
			owner_position = index + 1
	if owner_position == 0:
		plan["reason"] = "owner_missing"
		return plan
	if not FROM_POSITIONS.has(owner_position):
		plan["reason"] = "invalid_owner_position"
		return plan
	# A downed Warden is torn and cannot swing.
	if int(heroes[owner_position - 1]["hp"]) <= 0:
		plan["reason"] = "owner_torn"
		return plan
	plan["owner_position"] = owner_position

	# Verify the whole enemy roster and the chosen original slot; positions never compact.
	var enemy_records: Array[Dictionary] = enemies.get_enemies()
	var seen_enemy_ids: Array[String] = []
	for index in range(enemy_records.size()):
		var enemy: Dictionary = enemy_records[index]
		var enemy_id: Variant = enemy.get("id")
		var enemy_position: Variant = enemy.get("position")
		var enemy_hp: Variant = enemy.get("hp")
		var enemy_max_hp: Variant = enemy.get("max_hp")
		var enemy_block: Variant = enemy.get("block")
		if not enemy_id is String or enemy_id.is_empty() or seen_enemy_ids.has(enemy_id):
			plan["reason"] = "invalid_roster"
			return plan
		if not enemy_position is int or enemy_position != index + 1:
			plan["reason"] = "invalid_roster"
			return plan
		if not enemy_max_hp is int or enemy_max_hp <= 0:
			plan["reason"] = "invalid_roster"
			return plan
		if not enemy_hp is int or enemy_hp < 0 or enemy_hp > enemy_max_hp:
			plan["reason"] = "invalid_roster"
			return plan
		if not enemy_block is int or enemy_block < 0:
			plan["reason"] = "invalid_roster"
			return plan
		seen_enemy_ids.append(enemy_id)
	# The printed TO line is 1-2 even when a third (or fourth) foe exists.
	if not TO_POSITIONS.has(target_position) or target_position > enemy_records.size():
		plan["reason"] = "invalid_target"
		return plan
	if int(enemy_records[target_position - 1]["hp"]) <= 0:
		plan["reason"] = "dead_target"
		return plan
	plan["target_position"] = target_position

	# Both authoritative status rosters and the shared token map must be well formed before any
	# payment: an unknown key, wrong Variant type, negative counter, malformed one-shot token or a
	# corrupt pin entry refuses here rather than mid-transaction.
	if not _valid_status_rosters(party, enemies):
		plan["reason"] = "malformed_statuses"
		return plan
	if not _valid_pin_tokens(pinned, enemy_records.size()):
		plan["reason"] = "malformed_pinned"
		return plan

	# The card must be genuinely held and affordable before any state changes.
	if not deck.hand.has(card_id):
		plan["reason"] = "card_not_held"
		return plan
	if deck.energy < int(plan["cost"]):
		plan["reason"] = "insufficient_energy"
		return plan

	# Project the exact bridge-bound damage-status maps the strikes will use. The authoritative
	# maps were validated in full above, including any legal Dodge/Blind/Fear token, which the
	# bridge does not model and which therefore stays on its actor untouched.
	var attacker_statuses: Variant = _attack_statuses(heroes[owner_position - 1].get("statuses", {}))
	if attacker_statuses == null:
		plan["reason"] = "malformed_statuses"
		return plan
	var defender_statuses: Variant = _attack_statuses(enemy_records[target_position - 1].get("statuses", {}))
	if defender_statuses == null:
		plan["reason"] = "malformed_statuses"
		return plan
	var rules := CombatStatuses.new()
	# Only the first strike can ever carry the shared cross-hero +5; the confirmed hit spends it.
	var projected_bonus: int = pinned.bonus_for_attack(enemies, target_position, OWNER_ID)
	for index in range(int(plan["hits_printed"])):
		var bonus: int = projected_bonus if index == 0 else 0
		var base_damage: int = int(plan["hit_damage"]) + bonus
		if base_damage > 0 and rules.adjusted_attack_damage(base_damage, attacker_statuses,
				defender_statuses) <= 0:
			# A positive printed strike the shared rules collapse is an overflow, never a free hit.
			plan["reason"] = "arithmetic_overflow"
			return plan
	plan["attacker_statuses"] = attacker_statuses
	plan["defender_statuses"] = defender_statuses
	plan["ok"] = true
	plan["reason"] = "ready"
	return plan


## Authenticate one printing through the pool catalog that owns it. Returns the authored pay
## contract or {} when the record no longer prints exactly this card.
func _authenticate(card_id: String) -> Dictionary:
	var card: Dictionary = PRINTINGS.get(card_id, {})
	if card.is_empty():
		return {}
	if not _matches_authored(_catalog.get_definition(card_id), card_id, card):
		return {}
	return {
		"cost": int(card["cost"]),
		"damage": int(card["damage"]),
		"hits": int(card["hits"]),
		"pinned": bool(card["pinned"]),
		"to_positions": (card["to_positions"] as Array).duplicate(),
	}


## Exact contract for one record: identity, printed name, Warden owner, printed two-energy cost,
## the single-enemy target, both position windows, the complete printed effect set with matching
## value types, authored reward eligibility and the base/"+" link inside the pool catalog.
func _matches_authored(definition: Dictionary, card_id: String, card: Dictionary) -> bool:
	if definition.is_empty() or definition.get("id") != card_id:
		return false
	if definition.get("owner") != OWNER_ID:
		return false
	if definition.get("display_name") != card["display_name"]:
		return false
	var cost: Variant = definition.get("cost")
	if not cost is int or cost != card["cost"]:
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if not _exact_positions(definition.get("from_positions"), FROM_POSITIONS):
		return false
	if not _exact_positions(definition.get("to_positions"), card["to_positions"]):
		return false
	var effects_value: Variant = definition.get("effects")
	if not effects_value is Dictionary:
		return false
	var effects: Dictionary = effects_value
	var expected: Dictionary = card["effects"]
	if effects.size() != expected.size():
		return false
	for key: String in expected:
		if not effects.has(key):
			return false
		var value: Variant = effects[key]
		if typeof(value) != typeof(expected[key]) or value != expected[key]:
			return false
	var upgraded: bool = card.has("upgrade_of")
	var eligible: Variant = definition.get("reward_eligible")
	if not eligible is bool or eligible != (not upgraded):
		return false
	if upgraded:
		return definition.get("upgrade_of") == card["upgrade_of"] \
			and not definition.has("upgrade_id")
	return definition.get("upgrade_id") == card["upgrade_id"] \
		and not definition.has("upgrade_of")


func _exact_positions(value: Variant, expected: Array) -> bool:
	if not value is Array or value.size() != expected.size():
		return false
	for index in range(expected.size()):
		if not value[index] is int or value[index] != expected[index]:
			return false
	return true


## Fail closed on a malformed authoritative status map on either side, using the shared turn-batch
## validator over the COMPLETE rosters, so preflight accepts exactly the vocabulary the status
## owners define (including the literal boolean Fear marker).
func _valid_status_rosters(party: CombatParty, enemies: CombatEnemies) -> bool:
	var batch := CombatStatusTurnBatch.new()
	if not batch.tick_side("heroes", party.get_heroes()).get("ok", false):
		return false
	return batch.tick_side("enemies", enemies.get_enemies()).get("ok", false)


## The shared token map may only hold living legal slots and authored pinner IDs. A corrupt entry is
## refused before payment rather than silently ignored by the +5 projection.
func _valid_pin_tokens(pinned: CombatPinned, enemy_count: int) -> bool:
	for position in pinned._pinner_by_position:
		if not position is int or position < 1 or position > enemy_count:
			return false
		var pinner: Variant = pinned._pinner_by_position[position]
		if not pinner is String or not pinned._valid_pinner_id(pinner):
			return false
	return true


## A detached copy of one authoritative status map holding only the counts that modify attack
## damage. Returns null for a non-Dictionary map, a non-String key, a non-int count, an unknown
## key, a negative counter, a one-shot token that is not exactly 0 or 1, or a Fear marker that is
## not the literal boolean true. The authoritative map itself is never modified.
func _attack_statuses(statuses: Variant) -> Variant:
	if not statuses is Dictionary:
		return null
	var authoritative: Dictionary = statuses
	var detached := {}
	for name in authoritative:
		if not name is String:
			return null
		var value: Variant = authoritative[name]
		if name == FEAR_STATUS_KEY:
			if not value is bool or not bool(value):
				return null
			continue
		if not value is int:
			return null
		if name in ONE_SHOT_STATUS_KEYS:
			if value != 0 and value != 1:
				return null
			continue
		if name not in ATTACK_STATUS_KEYS or value < 0:
			return null
		detached[name] = value
	return detached
