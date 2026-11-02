class_name CombatButtonGolemFistCards
extends RefCounted
## V3-1 scene-free paid resolver for Button Golem's two starter Button Fist printings, base and "+".
##
## Button Fist strikes one living enemy in slots 1-2 for its printed 5 damage (7 upgraded) and adds
## its printed 2 self Block (3 upgraded) to the button-bodied Golem in hero seat 1 or 2. One
## successful call spends exactly 1 energy and discards exactly one genuinely held copy; the single
## blow is resolved through the shared CombatStatusAttacks bridge against the actors' PRE-HIT
## statuses (attacker Weak -25% floored, defender Exposed +50% floored, an already-Tangled defender
## +2 flat), and the enemy roster then absorbs it Block-before-HP. This card applies no new status,
## consumes no other helper's Pinned/Unravel token, spends none of the Golem's prior Block, counts no
## popped button, moves no actor, draws no card and draws no seeded RNG value.
##
## The printed Block is this card's own effect on the confirmed paid play, so it is awarded whatever
## the blow achieved: a hit entirely absorbed by enemy Block and a lethal hit that slays the target
## both still grant it. It goes to the Golem alone, never an ally and never the enemy.
##
## Authentic catalog lookup: both IDs, their owner, printed cost, seats, target window, damage, self
## Block and base/"+" link are authenticated against data/cards/button_golem_starter_cards.gd before
## anything is charged, so a rewritten record, a foreign owner, an aliased ID or a relinked upgrade
## is refused. printed_definition() is the read-only counterpart: it authenticates and reports the
## printed facts without spending or mutating anything.
##
## Every refusal is a pure no-op: no energy, hand, pile, hero record, enemy record, status or seeded
## RNG change. This helper is the callable combat rules layer only; the live hand, target picker,
## reward and app wiring for Button Fist is a later, separately owned task.

const OWNER_ID := "button_golem"
const COST := 1
const TARGET_KIND := "enemy_single"
const FROM_POSITIONS: Array[int] = [1, 2]
const TO_POSITIONS: Array[int] = [1, 2]
## The status keys whose counts modify one attack, exactly as CombatStatusAttacks accepts them.
const ATTACK_STATUS_KEYS: Array[String] = ["bleed", "weak", "exposed", "tangled", "riposte"]
## The authoritative one-shot tokens (integer 0 = inert, 1 = active). Neither modifies this attack's
## damage, so both are validated here and omitted from bridge-bound maps.
const ONE_SHOT_STATUS_KEYS: Array[String] = ["dodge_next_attack", "blind_next_attack"]
## The Scarecrow's one-owner-turn buff lock. Its only canonical value is the literal boolean true;
## it modifies no damage and is omitted from bridge-bound maps.
const FEAR_STATUS_KEY := "cannot_buff_next_turn"

## The two authentic starter printings, each with the exact catalog line it must still carry.
## `effects` is the complete printed descriptor set (no extra keys).
const PRINTINGS := {
	"button_golem_starter_button_fist": {
		"name": "Button Fist",
		"cost": 1,
		"damage": 5,
		"block_self": 2,
		"effects": {"damage": 5, "block_self": 2},
		"starting_copies": 1,
		"upgrade_id": "button_golem_starter_button_fist_plus",
	},
	"button_golem_starter_button_fist_plus": {
		"name": "Button Fist+",
		"cost": 1,
		"damage": 7,
		"block_self": 3,
		"effects": {"damage": 7, "block_self": 3},
		"starting_copies": 0,
		"upgrade_of": "button_golem_starter_button_fist",
	},
}

const _STARTER_CATALOG := preload("res://data/cards/button_golem_starter_cards.gd")

var _attacks := CombatStatusAttacks.new()


## True only for the two authentic Button Fist IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and PRINTINGS.has(card_id)


## Read-only authentication: the detached printed facts for one genuine Fist printing, or {} for a
## foreign ID, a forged record or a broken base/"+" link. Never spends, discards or mutates state.
func printed_definition(card_id: Variant) -> Dictionary:
	if not is_supported_card(card_id):
		return {}
	return _authenticate(card_id)


## The single paid transaction: authenticate the printing, preflight the whole request, then charge
## once, discard one held copy, resolve the one printed blow through the shared status bridge and
## grant the printed self Block to the Golem. A refusal changes no deck, party, enemy or RNG state.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position)
	if not plan["ok"]:
		return plan
	# Every operation below is guaranteed by the complete preflight above, and nothing here draws
	# a seeded RNG value.
	var id: String = plan["card_id"]
	var target: int = int(plan["target_position"])
	deck.try_spend_energy(int(plan["cost"]))
	plan["energy_spent"] = int(plan["cost"])
	deck.discard_played(id)
	var attacker_statuses: Dictionary = plan["attacker_statuses"]
	var defender_statuses: Dictionary = plan["defender_statuses"]
	var hit: Dictionary = _attacks.resolve_vs_enemy(enemies, target,
		int(plan["printed_damage"]), attacker_statuses, defender_statuses)
	if not hit.get("ok", false):
		# Preflight proves the bridge accepts these detached maps; if a model change still refuses,
		# never publish an applied receipt for a hit no event backs. Report the truth: the energy and
		# the held copy were already paid above.
		plan["ok"] = false
		plan["reason"] = "bridge_rejected"
		plan["damage"] = 0
		plan["block_absorbed"] = 0
		plan["hp_loss"] = 0
		plan["block_gained"] = 0
		return plan
	plan["damage"] = int(hit["damage"])
	plan["block_absorbed"] = int(hit["block_absorbed"])
	plan["hp_loss"] = int(hit["hp_loss"])
	# The printed self Block is granted on the confirmed paid play alone: a fully absorbed hit and a
	# lethal hit both still add it, and it never touches any other actor's Block.
	party.gain_block(int(plan["owner_position"]), int(plan["block_gained"]))
	plan["reason"] = "applied"
	return plan


## Read-only preflight: authenticate the card, validate every real roster/status record, bind the
## Golem to its actual seat, size the single hit and the Block gain before anything is charged.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int) -> Dictionary:
	var plan := {
		"ok": false, "reason": "unsupported_card",
		"card_id": card_id if typeof(card_id) == TYPE_STRING else "",
		"cost": 0, "owner_position": 0, "target_position": target_position,
		"printed_damage": 0, "damage": 0, "block_absorbed": 0, "hp_loss": 0,
		"block_gained": 0, "energy_spent": 0,
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

	# Bind the Golem to its actual ID/seat; never assume a fixed slot.
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
	var owner: Dictionary = party._heroes[owner_position - 1]
	if owner["hp"] <= 0:
		plan["reason"] = "owner_torn"
		return plan
	if not FROM_POSITIONS.has(owner_position):
		plan["reason"] = "invalid_owner_position"
		return plan
	if not _distinct_hero_ids(party):
		plan["reason"] = "invalid_roster"
		return plan
	# Authoritative status/roster data must be well formed before any payment. The shared turn-batch
	# validator applies the exact CombatStatuses keys and counts over the COMPLETE rosters.
	if not _valid_status_rosters(party, enemies):
		plan["reason"] = "malformed_statuses"
		return plan
	if not deck.hand.has(card_id):
		plan["reason"] = "card_not_held"
		return plan
	if deck.energy < plan["cost"]:
		plan["reason"] = "insufficient_energy"
		return plan

	# The chosen enemy must be a living actor in this card's printed TO window.
	if target_position < 1 or target_position > enemies._enemies.size():
		plan["reason"] = "invalid_target"
		return plan
	if not TO_POSITIONS.has(target_position):
		plan["reason"] = "invalid_target"
		return plan
	var target_record: Dictionary = enemies._enemies[target_position - 1]
	if not target_record.get("position") is int \
			or target_record["position"] != target_position \
			or not target_record.get("hp") is int or target_record["hp"] <= 0:
		plan["reason"] = "invalid_target"
		return plan

	# Guarantee the printed Block can really be added before charging, so gain_block cannot refuse
	# after payment. Prior Block is retained and never spent by this card.
	var block_now: Variant = owner.get("block")
	if not block_now is int or block_now < 0:
		plan["reason"] = "malformed_block"
		return plan
	var block_self: int = int(printed["block_self"])
	if block_self > CombatParty.MAX_INT - int(block_now):
		plan["reason"] = "block_overflow"
		return plan

	# Project the exact bridge-compatible damage-status maps the paid hit will use: the authoritative
	# maps are already validated in full above (including any Dodge/Blind one-shot token and the
	# Scarecrow's boolean Fear lock), while CombatStatusAttacks admits only the damage-status subset.
	var attacker_statuses: Variant = _attack_statuses(owner.get("statuses", {}))
	if attacker_statuses == null:
		plan["reason"] = "malformed_statuses"
		return plan
	var defender: Dictionary = enemies.get_enemy(target_position)
	var defender_statuses: Variant = _attack_statuses(defender.get("statuses", {}))
	if defender_statuses == null:
		plan["reason"] = "malformed_statuses"
		return plan
	# Size the exact hit before payment: a positive-base attack the shared status rules collapse to
	# zero is an overflow, never a silent free hit, and the bridge cannot refuse later.
	if int(printed["damage"]) > 0 \
			and CombatStatuses.new().adjusted_attack_damage(int(printed["damage"]),
				attacker_statuses, defender_statuses) <= 0:
		plan["reason"] = "arithmetic_overflow"
		return plan

	plan["printed_damage"] = int(printed["damage"])
	plan["block_gained"] = block_self
	plan["attacker_statuses"] = attacker_statuses
	plan["defender_statuses"] = defender_statuses
	plan["ok"] = true
	plan["reason"] = "ready"
	return plan


## Authenticate one printing against the starter catalog that owns it. Both printings must still
## point at each other, so a rewritten, relinked or unauthentic record is never paid for.
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
	var spec: Dictionary = PRINTINGS[card_id]
	return {
		"card_id": card_id,
		"display_name": str(spec["name"]),
		"cost": int(spec["cost"]),
		"damage": int(spec["damage"]),
		"block_self": int(spec["block_self"]),
		"from_positions": FROM_POSITIONS.duplicate(),
		"to_positions": TO_POSITIONS.duplicate(),
	}


## The one authored record for an ID, detached. A subclass may serve a forged record so a rewritten
## catalog can be proven inert before any energy, hand, HP, Block or RNG state moves.
func _catalog_definition(card_id: String) -> Dictionary:
	return _STARTER_CATALOG.new().get_definition(card_id)


## Exact contract for one record: identity, printed name, Golem owner, printed one-energy cost, the
## single-enemy target, both position arrays, the complete printed effect set with matching value
## types, authored starter copy count, authored reward eligibility and the base/"+" link.
func _matches_authored(definition: Dictionary, card_id: String, upgraded: bool) -> bool:
	if definition.is_empty() or definition.get("id") != card_id:
		return false
	if definition.get("owner") != OWNER_ID:
		return false
	var spec: Dictionary = PRINTINGS[card_id]
	if definition.get("display_name") != str(spec["name"]):
		return false
	var cost: Variant = definition.get("cost")
	if not cost is int or cost != int(spec["cost"]):
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if not _exact_positions(definition.get("from_positions"), FROM_POSITIONS):
		return false
	if not _exact_positions(definition.get("to_positions"), TO_POSITIONS):
		return false
	var effects_value: Variant = definition.get("effects")
	if not effects_value is Dictionary:
		return false
	var effects: Dictionary = effects_value
	var expected: Dictionary = spec["effects"]
	if effects.size() != expected.size():
		return false
	for key: String in expected:
		if not effects.has(key):
			return false
		var value: Variant = effects[key]
		if not value is int or value != int(expected[key]):
			return false
	var starting_copies: Variant = definition.get("starting_copies")
	if not starting_copies is int or starting_copies != int(spec["starting_copies"]):
		return false
	var reward_eligible: Variant = definition.get("reward_eligible")
	if not reward_eligible is bool or bool(reward_eligible):
		return false
	if upgraded:
		return definition.get("upgrade_of") == spec["upgrade_of"] \
			and not definition.has("upgrade_id")
	return definition.get("upgrade_id") == spec["upgrade_id"] \
		and not definition.has("upgrade_of")


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


## One to three genuine enemy slots in order with nonempty distinct string IDs and sane records.
## Slain slots remain valid; target eligibility is checked separately against the printed window.
func _valid_enemies(enemies: CombatEnemies) -> bool:
	if not enemies.is_valid():
		return false
	var roster: Array[Dictionary] = enemies.get_enemies()
	if roster.is_empty() or roster.size() > CombatEnemies.MAX_ENEMIES:
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


func _distinct_hero_ids(party: CombatParty) -> bool:
	var seen: Dictionary = {}
	for hero: Dictionary in party._heroes:
		var hero_id: Variant = hero.get("id")
		if not hero_id is String:
			return false
		if seen.has(hero_id):
			return false
		seen[hero_id] = true
	return true


## Fail closed on a malformed authoritative status map on either side, using the shared turn-batch
## validator over the COMPLETE authoritative rosters (unknown keys, wrong Variant types, negative
## counters and a non-0/1 Dodge or Blind token all refuse here), so preflight accepts exactly the
## vocabulary the status owners define.
func _valid_status_rosters(party: CombatParty, enemies: CombatEnemies) -> bool:
	var batch := CombatStatusTurnBatch.new()
	if not batch.tick_side("heroes", party.get_heroes()).get("ok", false):
		return false
	return batch.tick_side("enemies", enemies.get_enemies()).get("ok", false)


## A detached copy of one authoritative status map holding only the counts that modify attack
## damage. Returns null for a non-Dictionary map, a non-String key, a non-int count, an unknown
## key, a negative counter, a one-shot token that is not exactly 0 or 1, or a Fear flag that is
## not exactly the literal boolean true. The one-shot tokens and the Fear flag are non-damage
## markers: they are validated here and left out of the returned map, so the authoritative record
## itself is never modified and every legal marker stays on its actor.
func _attack_statuses(statuses: Variant) -> Variant:
	if not statuses is Dictionary:
		return null
	var authoritative: Dictionary = statuses
	var detached := {}
	for name in authoritative:
		if not name is String:
			return null
		var count: Variant = authoritative[name]
		if name == FEAR_STATUS_KEY:
			if not count is bool or not bool(count):
				return null
			continue
		if not count is int:
			return null
		if name in ONE_SHOT_STATUS_KEYS:
			if count != 0 and count != 1:
				return null
			continue
		if name not in ATTACK_STATUS_KEYS or count < 0:
			return null
		detached[name] = count
	return detached
