class_name CombatRagDuelistNeedleBarrageCards
extends RefCounted
## V3-1 scene-free paid resolver for the Rag Duelist's rare reward-pool Needle Barrage (+).
##
## Needle Barrage is the long-legged fencer's needle rapier: three separate strikes on one chosen
## enemy in slot 1 or 2 from hero seat 1, 2 energy, printed base 3 per strike (4 upgraded). The
## catalog authors it as `{"damage": 3, "hit_count": 3, "independent_hits": true}`, so this is
## never one pooled 9/12-damage blow. Each of the three strikes is resolved on its own through the
## shared CombatStatusAttacks bridge against the real CombatEnemies roster: the current attacker and
## defender status maps adjust THAT strike, and the roster absorbs Block before HP, so a strike that
## exhausts the defender's remaining Block lands the rest on HP while the next strike starts from
## the (now empty) Block. The chosen slot never changes mid-barrage: a foe slain by strike one or
## two simply stops the remaining strikes, and no slot is compacted, retargeted or hit as a corpse.
##
## This service authenticates the exact held ID against the Rag Duelist pool catalog that owns it
## (owner, cost, FROM seat, `enemy_single` targeting, TO slots, the complete effect dictionary with
## exact Variant types and the base/'+' link in both directions) before any payment, and never
## trusts caller-supplied effects. It then resolves against the real shared CombatDeck and the real
## party/enemy models: exactly one 2-energy charge, exactly one held copy discarded, and one receipt
## per actual strike carrying that strike's damage, absorbed Block and HP loss.
##
## A refusal is decided by a complete read-only preflight BEFORE the charge and changes no deck,
## card, energy, party HP/Block/status, enemy HP/Block/status/slot or seeded RNG state. Nothing here
## draws, shuffles, moves a hero, applies a status or invents a rider (no Bleed, Riposte, Pinned,
## draw or Dodge consumption); the authoritative status maps are validated in full and left exactly
## as they were, and only their damage-adjusting subset is handed to the shared bridge.
##
## Callable rules service only. These two IDs are not yet admitted to a live party deck, the mounted
## hand, the reward pool or any app flow; that wiring is a later task.

const OWNER := "rag_duelist"
const COST := 2
const TARGET_KIND := "enemy_single"
const FROM_POSITIONS: Array[int] = [1]
const TO_POSITIONS: Array[int] = [1, 2]
const HIT_COUNT := 3
const NO_TARGET_SLOT := 0

## The two authentic printings and the per-strike base damage each one prints.
const PRINTINGS := {
	"rag_duelist_needle_barrage": 3,
	"rag_duelist_needle_barrage_plus": 4,
}

## The status keys whose counts modify one attack, exactly as CombatStatusAttacks accepts them.
const ATTACK_STATUS_KEYS: Array[String] = ["bleed", "weak", "exposed", "tangled", "riposte"]
## The one-shot defense tokens an authoritative map may legitimately carry: integer 0 is inert and
## integer 1 is armed. Dodge protects an ATTACKER's bearer from incoming attacks and Blind makes a
## DEFENDER's own next attack miss; neither modifies the damage of this outgoing strike.
const DODGE_STATUS_KEY := "dodge_next_attack"
const BLIND_STATUS_KEY := "blind_next_attack"
const ONE_SHOT_STATUS_KEYS: Array[String] = [DODGE_STATUS_KEY, BLIND_STATUS_KEY]

var _attacks := CombatStatusAttacks.new()
var _statuses := CombatStatuses.new()


## True only for the two authentic pool printings whose base/'+' pair still carries its authored
## line. Pure lookup: nothing is charged or mutated and no RNG is touched.
func is_supported_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	return _authenticate(card_id) > 0


## The single paid transaction: authenticate, preflight every input, then charge the printed cost,
## discard exactly one held copy and resolve up to three independent strikes on the chosen enemy.
## `target_position` is an enemy slot from the printed TO line (1 or 2).
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int = NO_TARGET_SLOT) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position)
	if not plan["ok"]:
		return plan
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# exact held ID is held and affordable, the unique living owner sits in printed seat 1, the
	# target is a living enemy in slot 1-2, every roster and status map is well formed, and the
	# status-adjusted strike is representable, so the charge and the discard cannot be refused.
	var card_id_value: String = plan["card_id"]
	var target: int = int(plan["target_position"])
	var base_damage: int = int(plan["base_damage"])
	var attacker_statuses: Dictionary = plan["attacker_statuses"]
	deck.try_spend_energy(int(plan["cost"]))
	deck.discard_played(card_id_value)
	plan["energy_spent"] = int(plan["cost"])
	plan["energy_after"] = deck.energy

	var hits: Array[Dictionary] = []
	for hit_index in range(1, HIT_COUNT + 1):
		# Survival is re-checked before EVERY strike: a foe slain by an earlier one receives no
		# more hits, no other slot is ever targeted and the roster never compacts.
		if enemies.is_slain(target):
			break
		var defender: Dictionary = enemies.get_enemy(target)
		var defender_statuses: Variant = _attack_statuses(defender.get("statuses", {}), "defender")
		if defender_statuses == null:
			return _partial_failure(plan, hits, "bridge_rejected")
		var event: Dictionary = _attacks.resolve_vs_enemy(enemies, target, base_damage,
			attacker_statuses, defender_statuses)
		if not event.get("ok", false):
			return _partial_failure(plan, hits, "bridge_rejected")
		var after: Dictionary = enemies.get_enemy(target)
		hits.append({
			"position": target,
			"hit": hit_index,
			"base_damage": base_damage,
			"damage": int(event["damage"]),
			"block_absorbed": int(event["block_absorbed"]),
			"hp_loss": int(event["hp_loss"]),
			"target_hp_after": int(after["hp"]),
			"target_block_after": int(after["block"]),
		})

	var final: Dictionary = enemies.get_enemy(target)
	plan["hits"] = hits
	plan["hit_count"] = hits.size()
	plan["target_hp_after"] = int(final["hp"])
	plan["target_block_after"] = int(final["block"])
	plan["reason"] = "applied"
	return plan


## Read-only preflight of the whole transaction. Returns a detached plan on success or the same
## receipt shape with `ok: false`, a reason and no mutation of any input.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int) -> Dictionary:
	var plan: Dictionary = {
		"ok": false, "reason": "unsupported_card",
		"card_id": "" if typeof(card_id) != TYPE_STRING else str(card_id),
		"cost": 0, "owner_position": 0, "owner_id": OWNER,
		"target_position": target_position,
		"printed_hit_count": HIT_COUNT, "hit_count": 0, "base_damage": 0,
		"energy_before": 0, "energy_after": 0, "energy_spent": 0,
		"target_hp_before": 0, "target_hp_after": 0,
		"target_block_before": 0, "target_block_after": 0,
		"attacker_statuses": {}, "hits": [],
	}
	if typeof(card_id) != TYPE_STRING or not PRINTINGS.has(card_id):
		return plan
	var base_damage: int = _authenticate(card_id)
	if base_damage <= 0:
		plan["reason"] = "catalog_mismatch"
		return plan
	plan["cost"] = COST
	plan["base_damage"] = base_damage
	if deck == null or party == null or enemies == null:
		plan["reason"] = "invalid_request"
		return plan
	if deck.combat_state == null or deck._rng == null:
		plan["reason"] = "invalid_deck"
		return plan
	plan["energy_before"] = deck.energy
	plan["energy_after"] = deck.energy
	if not _valid_heroes(party) or not _valid_enemies(enemies):
		plan["reason"] = "invalid_roster"
		return plan
	if not deck.turn_active:
		plan["reason"] = "inactive_turn"
		return plan

	# Bind the Rag Duelist to its actual current seat; a swapped seat grants no false authority.
	var owner_position := 0
	for hero: Dictionary in party._heroes:
		if hero.get("id") != OWNER:
			continue
		if owner_position != 0:
			plan["reason"] = "duplicate_owner"
			return plan
		owner_position = int(hero["position"])
	if owner_position == 0:
		plan["reason"] = "owner_missing"
		return plan
	plan["owner_position"] = owner_position
	if not FROM_POSITIONS.has(owner_position):
		plan["reason"] = "invalid_owner_position"
		return plan
	var owner: Dictionary = party._heroes[owner_position - 1]
	if int(owner["hp"]) <= 0:
		plan["reason"] = "owner_torn"
		return plan
	if not _distinct_hero_ids(party):
		plan["reason"] = "invalid_roster"
		return plan

	# Every authoritative status map is validated in full, including the one-shot defense tokens,
	# so a malformed map can never reach the bridge after payment.
	if not _valid_authoritative_statuses_roster(party, enemies):
		plan["reason"] = "malformed_statuses"
		return plan
	var attacker_statuses: Variant = _attack_statuses(owner.get("statuses", {}), "attacker")
	if attacker_statuses == null:
		# An armed Blind on the attacker belongs to the miss/evasion path, which this resolver
		# must never skip silently.
		plan["reason"] = "owner_blinded"
		return plan

	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(card_id):
		plan["reason"] = "card_not_held"
		return plan
	if deck.energy < COST:
		plan["reason"] = "insufficient_energy"
		return plan

	# The printed TO line is 1-2 and the chosen slot must still hold a living enemy.
	if not TO_POSITIONS.has(target_position):
		plan["reason"] = "invalid_target"
		return plan
	if target_position > enemies.get_enemies().size():
		plan["reason"] = "invalid_target"
		return plan
	if enemies.is_slain(target_position):
		plan["reason"] = "target_slain"
		return plan
	var target: Dictionary = enemies.get_enemy(target_position)
	if target.is_empty():
		plan["reason"] = "invalid_target"
		return plan
	var defender_statuses: Variant = _attack_statuses(target.get("statuses", {}), "defender")
	if defender_statuses == null:
		# A Dodge token on the defender belongs to the evasion path, which this resolver must
		# never skip silently.
		plan["reason"] = "target_dodging"
		return plan

	# A positive printed strike the shared status rules collapse to zero is an overflow, never a
	# silent free hit; the very first adjusted strike must be representable before payment.
	if base_damage > 0 and _statuses.adjusted_attack_damage(base_damage, attacker_statuses,
			defender_statuses) <= 0:
		plan["reason"] = "arithmetic_overflow"
		return plan

	plan["target_hp_before"] = int(target["hp"])
	plan["target_hp_after"] = int(target["hp"])
	plan["target_block_before"] = int(target["block"])
	plan["target_block_after"] = int(target["block"])
	plan["attacker_statuses"] = attacker_statuses
	plan["ok"] = true
	plan["reason"] = "ready"
	return plan


## The per-strike base damage of one authentic printing, or 0 when the ID is not one of the two
## authored Needle Barrage printings with an intact base/'+' link.
func _authenticate(card_id: String) -> int:
	if not PRINTINGS.has(card_id):
		return 0
	var base_id: String = card_id.trim_suffix("_plus")
	var plus_id: String = base_id + "_plus"
	if not PRINTINGS.has(base_id) or not PRINTINGS.has(plus_id):
		return 0
	var base_record: Dictionary = _catalog_definition(base_id)
	var plus_record: Dictionary = _catalog_definition(plus_id)
	if not _matches_authored(base_record, base_id, false):
		return 0
	if not _matches_authored(plus_record, plus_id, true):
		return 0
	# The two records must still point at each other, so a copied, relinked or unauthentic record
	# can never be paid for under the other printing's ID.
	if base_record.get("upgrade_id") != plus_id or base_record.has("upgrade_of"):
		return 0
	if plus_record.get("upgrade_of") != base_id or plus_record.has("upgrade_id"):
		return 0
	return int(PRINTINGS[card_id])


## The one authored record for an ID, detached. A subclass may serve a forged record so a rewritten
## catalog can be proven inert before any energy, hand, HP, Block or RNG state moves.
func _catalog_definition(card_id: String) -> Dictionary:
	return RagDuelistPoolCards.new().get_definition(card_id)


## Exact contract for one record: identity, owner, energy cost, FROM seat, `enemy_single`
## targeting, TO slots, the complete printed effect set with exact Variant types and magnitudes,
## no starter copies and the base/'+' reward eligibility the catalog authors.
func _matches_authored(definition: Dictionary, card_id: String, upgraded: bool) -> bool:
	if definition.is_empty() or definition.get("id") != card_id:
		return false
	if definition.get("owner") != OWNER:
		return false
	var cost: Variant = definition.get("cost")
	if not cost is int or cost != COST:
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
	var expected_effects := {
		"damage": int(PRINTINGS[card_id]), "hit_count": HIT_COUNT, "independent_hits": true,
	}
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


func _exact_positions(value: Variant, expected: Array[int]) -> bool:
	if not value is Array or value.size() != expected.size():
		return false
	var positions: Array = value
	for index in range(expected.size()):
		if not positions[index] is int or positions[index] != expected[index]:
			return false
	return true


## Three genuine seats in order with nonempty string IDs and sane per-combat records. ID
## uniqueness is checked separately so a second Rag Duelist reports duplicate_owner first.
func _valid_heroes(party: CombatParty) -> bool:
	if not party.is_valid() or party._heroes.size() != CombatParty.PARTY_SIZE:
		return false
	for index in range(CombatParty.PARTY_SIZE):
		var record: Variant = party._heroes[index]
		if not record is Dictionary:
			return false
		var hero: Dictionary = record
		var hero_id: Variant = hero.get("id")
		if not hero_id is String or hero_id.is_empty():
			return false
		var position: Variant = hero.get("position")
		if not position is int or position != index + 1:
			return false
		var max_hp: Variant = hero.get("max_hp")
		if not max_hp is int or max_hp <= 0:
			return false
		var hp: Variant = hero.get("hp")
		if not hp is int or hp < 0 or hp > max_hp:
			return false
		var block: Variant = hero.get("block")
		if not block is int or block < 0:
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


## One to three genuine enemy slots in order with nonempty distinct string IDs and sane records.
## Slain slots remain valid; target eligibility is checked separately.
func _valid_enemies(enemies: CombatEnemies) -> bool:
	if not enemies.is_valid():
		return false
	var roster: Array[Dictionary] = enemies.get_enemies()
	if roster.is_empty() or roster.size() > CombatEnemies.MAX_ENEMIES:
		return false
	var seen: Dictionary = {}
	for index in range(roster.size()):
		var enemy: Dictionary = roster[index]
		var enemy_id: Variant = enemy.get("id")
		if not enemy_id is String or enemy_id.is_empty() or seen.has(enemy_id):
			return false
		seen[enemy_id] = true
		var position: Variant = enemy.get("position")
		if not position is int or position != index + 1:
			return false
		var max_hp: Variant = enemy.get("max_hp")
		if not max_hp is int or max_hp <= 0:
			return false
		var hp: Variant = enemy.get("hp")
		if not hp is int or hp < 0 or hp > max_hp:
			return false
		var block: Variant = enemy.get("block")
		if not block is int or block < 0:
			return false
	return true


## Every authoritative status map on both sides must be well formed before any hit is sized: named
## N-turn counters with non-negative int counts and the two one-shot tokens as integer 0 or 1.
func _valid_authoritative_statuses_roster(party: CombatParty, enemies: CombatEnemies) -> bool:
	for hero: Dictionary in party.get_heroes():
		if not _valid_authoritative_statuses(hero.get("statuses", {})):
			return false
	for enemy: Dictionary in enemies.get_enemies():
		if not _valid_authoritative_statuses(enemy.get("statuses", {})):
			return false
	return true


func _valid_authoritative_statuses(statuses: Variant) -> bool:
	if not statuses is Dictionary:
		return false
	var values: Dictionary = statuses
	for name in values:
		if not name is String or (name as String).is_empty():
			return false
		var count: Variant = values[name]
		if not count is int:
			return false
		if name in ONE_SHOT_STATUS_KEYS:
			if count != 0 and count != 1:
				return false
			continue
		if not ATTACK_STATUS_KEYS.has(name) or count < 0:
			return false
	return true


## A detached copy of one authoritative status map holding only what the damage bridge accepts for
## that role: the five attack counters plus the role's own one-shot token (Dodge for an attacker,
## Blind for a defender). Returns null for a malformed map or for an ARMED opposite-role token,
## which the shared bridge refuses so a miss/evasion path is never skipped silently; an inert 0
## token is simply omitted. The authoritative map itself is never modified and its tokens are never
## consumed.
func _attack_statuses(statuses: Variant, role: String) -> Variant:
	if not statuses is Dictionary:
		return null
	var authoritative: Dictionary = statuses
	var role_token: String = DODGE_STATUS_KEY if role == "attacker" else BLIND_STATUS_KEY
	var refused_token: String = BLIND_STATUS_KEY if role == "attacker" else DODGE_STATUS_KEY
	var detached := {}
	for name in authoritative:
		if not name is String:
			return null
		var count: Variant = authoritative[name]
		if not count is int:
			return null
		if name == refused_token:
			if count != 0:
				return null
			continue
		if name == role_token:
			if count != 0 and count != 1:
				return null
			detached[name] = count
			continue
		if not ATTACK_STATUS_KEYS.has(name) or count < 0:
			return null
		detached[name] = count
	return detached


## The truth after a bridge call refused something the preflight had proved: the energy and the
## card are already spent, so report the strikes that did land instead of claiming a resolved card.
func _partial_failure(plan: Dictionary, hits: Array[Dictionary], reason: String) -> Dictionary:
	plan["hits"] = hits
	plan["hit_count"] = hits.size()
	plan["ok"] = false
	plan["reason"] = reason
	return plan
