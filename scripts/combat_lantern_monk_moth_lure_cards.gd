class_name CombatLanternMonkMothLureCards
extends RefCounted
## Scene-free paid resolver for the Lantern Monk's single-target Moth Lure printings (V3-1).
##
## Moth Lure is the Monk's v3 COMMON reward: the base printing costs 1, Moth Lure+ costs 0, both come
## only from the round lantern-bearing Monk's middle or rear seat (FROM [2, 3]), target exactly one
## enemy (`enemy_single`, TO [1, 2, 3]) and print exactly `{"blind_next_attack": true, "draw": 1}`.
## The lantern moth halo settles over one foe and lures one more card into the shared hand.
##
## Blind is the shared one-shot "this enemy's NEXT attack misses" marker, never a skipped turn, a
## duration or a stack. On the authoritative enemy record it is the canonical integer token
## `blind_next_attack: 1` (0 is inert), the same shape `CombatStatuses`, `CombatStatusTurnBatch` and
## `CombatEnemyPhase` already validate and consume. A cast re-arms it at exactly 1 and never spends
## it, so an already-armed 1 stays 1. Neither this cast nor an owner-turn status tick consumes it;
## only the existing `CombatEnemyPhase` attack beat does, and that loop is not modified here.
##
## The transaction order is charge -> discard the played copy -> arm Blind on the authoritative
## selected record -> one real `CombatDeck.draw_extra(1)`. Because the played copy is already in
## the discard pile when the draw asks for a card, a legal seeded reshuffle may hand that same copy
## straight back; the draw always runs inside `CombatDeck`, which owns the one injected generator,
## so nothing here reseeds or draws unseeded randomness, and a draw that supplies no card (for
## example a Frayed Debt consuming the slot) is a valid success that invents nothing.
##
## This card is control, not an attack: no HP or Block changes on any actor, no non-Blind status is
## written, no Exhaust, no wallet or scrap cost and no Monk passive fires. Every hero, enemy slot,
## position and status map outside the one armed token, and every hand card not actually drawn or
## discarded, is preserved exactly.
##
## The catalog stays authoritative: the caller supplies only the held card ID and one enemy slot,
## never a cost, seat, token, draw count or effect. The whole exact base/'+' printing pair is
## authenticated from LanternMonkPoolCards before anything is charged, and the complete party,
## enemy roster, status maps and target are validated before the first mutation. Every refusal is a
## pure no-op, including the injected RNG.
##
## This is callable rules-layer behaviour only. No live hand, reward, app, run-deck or view path is
## registered here; wiring the mounted hand dispatcher is a later, separately owned task.

const OWNER := "lantern_monk"
const TARGET_KIND := "enemy_single"
const BLIND_STATUS_KEY := "blind_next_attack"
const BLIND_TOKEN := 1
## Every authentic printing prints the same one-card draw; only the cost differs.
const DRAW_COUNT := 1
const FROM_POSITIONS: Array[int] = [2, 3]
const TO_POSITIONS: Array[int] = [1, 2, 3]
const EFFECTS := {"blind_next_attack": true, "draw": 1}

## One-shot integer tokens: absent or 0 is inert, 1 is armed. Nothing else is a legal shape.
const ONE_SHOT_STATUS_KEYS: Array[String] = ["dodge_next_attack", "blind_next_attack"]
## The N-turn counters the shared combat status rules accept (non-negative ints).
const COUNTER_STATUS_KEYS: Array[String] = ["bleed", "weak", "exposed", "tangled", "riposte"]
## Fear is the shared buff lock, the one canonical status that is not an integer counter: its
## single accepted value is the literal boolean true (see CombatStatuses._valid_statuses).
const FEAR_STATUS_KEY := "cannot_buff_next_turn"

## The two authentic printings and the exact catalog line each must still carry. Everything except
## the cost and the base/'+' link is identical between them.
const CARDS := {
	"lantern_monk_moth_lure": {
		"display_name": "Moth Lure",
		"cost": 1,
		"reward_eligible": true,
		"upgrade_id": "lantern_monk_moth_lure_plus",
	},
	"lantern_monk_moth_lure_plus": {
		"display_name": "Moth Lure+",
		"cost": 0,
		"reward_eligible": false,
		"upgrade_of": "lantern_monk_moth_lure",
	},
}

var _catalog := LanternMonkPoolCards.new()


## The single paid transaction: authenticate the exact printing pair, preflight the whole request,
## then charge, discard exactly one held copy, arm one Blind token on the authoritative selected
## enemy and draw one real card through the deck. A refusal changes no deck, party, enemy, status
## or RNG state. `target_position` must be one printed enemy slot 1-3.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: Variant = 0) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# exact held ID is affordable, the unique living owner sits in an authored seat, the selected
	# slot is a living original enemy slot and every status map is well formed. Keep the defensive
	# returns so an unexpected model change still fails closed rather than paying for a partial
	# effect.
	if not deck.try_spend_energy(int(plan["cost"])):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")
	var target: int = int(plan["target_position"])
	# The real authoritative record, never a detached get_enemy copy. Set/keep the one-shot token at
	# exactly 1; never a second stack and never spent by this cast.
	var record: Dictionary = enemies._enemies[target - 1]
	if not record.has("statuses"):
		record["statuses"] = {}
	var statuses: Dictionary = record["statuses"]
	var blind_before: int = int(statuses.get(BLIND_STATUS_KEY, 0))
	statuses[BLIND_STATUS_KEY] = BLIND_TOKEN
	# One real shared-deck draw AFTER payment and discard, so a reshuffle legally supplies any card
	# in this battle's discard pile (including the copy just played). `CombatDeck` owns the seeded
	# generator; the preflight guaranteed an active turn, so a negative result is impossible and a
	# zero result (a Frayed Debt consuming the slot) is a real draw of nothing.
	var drawn: int = deck.draw_extra(DRAW_COUNT)
	if drawn < 0:
		drawn = 0
	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": int(plan["cost"]),
		"owner_position": int(plan["owner_position"]),
		"target_kind": TARGET_KIND,
		"target_position": target,
		"target_id": str(record.get("id", "")),
		"energy_before": int(plan["energy_before"]),
		"energy_after": deck.energy,
		"blind_before": blind_before,
		"blind_after": BLIND_TOKEN,
		"blind_already_active": blind_before == BLIND_TOKEN,
		"draw_requested": DRAW_COUNT,
		"cards_drawn": drawn,
	}


## True only for the two authentic catalog printings. Pure lookup; nothing is charged or mutated
## and no RNG is touched.
func is_supported_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	if not CARDS.has(id):
		return false
	return _authentic_pair(id, CARDS[id])


## Read-only preflight of the whole transaction. Returns a detached plan or a refusal receipt.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: Variant) -> Dictionary:
	if deck == null or party == null or enemies == null:
		return _refusal("invalid_request")
	if deck.combat_state == null or deck._rng == null:
		return _refusal("invalid_deck")
	if not deck.turn_active:
		return _refusal("inactive_turn")
	if not party.is_valid() or party._heroes.size() != CombatParty.PARTY_SIZE:
		return _refusal("invalid_party")
	if not enemies.is_valid():
		return _refusal("invalid_enemies")
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	if not CARDS.has(id):
		return _refusal("unsupported_card")
	var card: Dictionary = CARDS[id]
	if not _authentic_pair(id, card):
		return _refusal("catalog_mismatch")
	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = int(card["cost"])
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")
	# `enemy_single` selects exactly one printed original slot, and the slot is never a string, a
	# float or a bool standing in for an int position.
	if typeof(target_position) != TYPE_INT:
		return _refusal("invalid_target")
	var target: int = target_position
	if not TO_POSITIONS.has(target):
		return _refusal("invalid_target")

	# Verify the complete party roster and every hero's authoritative status shape, then bind the
	# single owner by hero ID to its actual current slot. Swapping seats, duplicating or tearing the
	# owner grants no authority.
	var heroes: Array[Dictionary] = party.get_heroes()
	if heroes.size() != CombatParty.PARTY_SIZE:
		return _refusal("invalid_party")
	var owner_position := 0
	var owner_count := 0
	var seen_ids: Array[String] = []
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = heroes[index]
		var hero_id = hero.get("id")
		var position = hero.get("position")
		var hp = hero.get("hp")
		var max_hp = hero.get("max_hp")
		var block = hero.get("block")
		if not hero_id is String or hero_id.is_empty() or seen_ids.has(hero_id):
			return _refusal("invalid_party")
		if not position is int or position != index + 1:
			return _refusal("invalid_party")
		if not max_hp is int or max_hp <= 0:
			return _refusal("invalid_party")
		if not hp is int or hp < 0 or hp > max_hp:
			return _refusal("invalid_party")
		if not block is int or block < 0:
			return _refusal("invalid_party")
		if not _valid_status_shape(hero.get("statuses", {})):
			return _refusal("malformed_statuses")
		seen_ids.append(hero_id)
		if hero_id == OWNER:
			owner_count += 1
			owner_position = index + 1
	# The shared turn-batch validator must also accept every authoritative hero record and map.
	if not CombatStatusTurnBatch.new().tick_side("heroes", heroes).get("ok", false):
		return _refusal("invalid_party")
	if owner_count != 1:
		return _refusal("owner_missing" if owner_count == 0 else "duplicate_owner")
	if not FROM_POSITIONS.has(owner_position):
		return _refusal("owner_illegal_position")
	if int(heroes[owner_position - 1]["hp"]) == 0:
		return _refusal("owner_downed")

	# The full enemy roster must still be the vocabulary the shared status rules accept (unknown
	# keys, wrong Variant types, negative counters and a non-0/1 Blind or Dodge token all fail) and
	# every slot keeps its original position; death never compacts the roster.
	var roster: Array[Dictionary] = enemies.get_enemies()
	if roster.is_empty() or roster.size() > CombatEnemies.MAX_ENEMIES:
		return _refusal("invalid_enemies")
	var seen_enemy_ids: Array[String] = []
	for index in range(roster.size()):
		var enemy: Dictionary = roster[index]
		var enemy_id = enemy.get("id")
		var hp = enemy.get("hp")
		var max_hp = enemy.get("max_hp")
		var block = enemy.get("block")
		if not enemy_id is String or enemy_id.is_empty() or seen_enemy_ids.has(enemy_id):
			return _refusal("invalid_enemies")
		seen_enemy_ids.append(enemy_id)
		if enemy.get("position") != index + 1:
			return _refusal("invalid_enemies")
		if not max_hp is int or max_hp <= 0:
			return _refusal("invalid_enemies")
		if not hp is int or hp < 0 or hp > max_hp:
			return _refusal("invalid_enemies")
		if not block is int or block < 0:
			return _refusal("invalid_enemies")
		if not _valid_status_shape(enemy.get("statuses", {})):
			return _refusal("malformed_statuses")
	if not CombatStatusTurnBatch.new().tick_side("enemies", roster).get("ok", false):
		return _refusal("malformed_statuses")

	# The chosen original slot must be occupied by a living enemy right now.
	if target > roster.size():
		return _refusal("invalid_target")
	if int(roster[target - 1]["hp"]) == 0:
		return _refusal("target_slain")

	var selected: Dictionary = roster[target - 1]
	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": target,
		"energy_before": deck.energy,
		"blind_before": int(selected.get("statuses", {}).get(BLIND_STATUS_KEY, 0)),
	}


## The status shape the shared combat rules accept: named N-turn counters with non-negative int
## counts, the two one-shot tokens as integer 0/1, and Fear (`cannot_buff_next_turn`) as the
## literal boolean true only. Anything else fails closed before mutation.
func _valid_status_shape(statuses: Variant) -> bool:
	if not statuses is Dictionary:
		return false
	var values: Dictionary = statuses
	for name in values:
		if not name is String or (name as String).is_empty():
			return false
		var count = values[name]
		if name == FEAR_STATUS_KEY:
			# The canonical Fear lock is a literal boolean, never an int/string/float stand-in.
			if not count is bool or not bool(count):
				return false
			continue
		if not count is int:
			return false
		if name in ONE_SHOT_STATUS_KEYS:
			if int(count) != 0 and int(count) != 1:
				return false
			continue
		if not COUNTER_STATUS_KEYS.has(name) or int(count) < 0:
			return false
	return true


## Reads the exact authored records from LanternMonkPoolCards and proves BOTH printings of the pair
## still carry their whole authored line, so a rewritten catalog (extra effect, another seat,
## target, cost, rarity, copy count, art path or a broken upgrade link) can never be paid for as
## this effect.
func _authentic_pair(card_id: String, card: Dictionary) -> bool:
	var definition: Dictionary = _catalog_definition(card_id)
	if not _authentic_record(definition, card_id, card):
		return false
	if card.has("upgrade_id"):
		var plus_id: String = str(card["upgrade_id"])
		if not CARDS.has(plus_id):
			return false
		var plus: Dictionary = _catalog_definition(plus_id)
		if plus.get("upgrade_of") != card_id or plus.has("upgrade_id"):
			return false
		return _authentic_record(plus, plus_id, CARDS[plus_id])
	var base_id: String = str(card["upgrade_of"])
	if not CARDS.has(base_id):
		return false
	var base: Dictionary = _catalog_definition(base_id)
	if base.get("upgrade_id") != card_id or base.has("upgrade_of"):
		return false
	return _authentic_record(base, base_id, CARDS[base_id])


## The one catalog read of this service, so a test double can prove that a rewritten catalog record
## is refused rather than paid for. Production always reads the real Lantern Monk pool.
func _catalog_definition(card_id: String) -> Dictionary:
	return _catalog.get_definition(card_id)


## The exact contract for one printing: identity, printed name, Monk owner, printed cost, the
## `enemy_single` target with the authored FROM/TO slots, the complete effect dictionary with exact
## Variant types, zero starting copies, common rarity, the printed reward flag, the base art path
## and the base/'+' link. Any missing, extra, retyped or altered field refuses.
func _authentic_record(definition: Dictionary, card_id: String, card: Dictionary) -> bool:
	if definition.get("id") != card_id:
		return false
	if definition.get("display_name") != card["display_name"]:
		return false
	if definition.get("owner") != OWNER:
		return false
	if not definition.get("cost") is int or int(definition.get("cost")) != int(card["cost"]):
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if not _exact_positions(definition.get("from_positions"), FROM_POSITIONS):
		return false
	if not _exact_positions(definition.get("to_positions"), TO_POSITIONS):
		return false
	if not _same_value(definition.get("effects"), EFFECTS):
		return false
	if definition.get("rarity") != "common":
		return false
	var starting_copies: Variant = definition.get("starting_copies")
	if not starting_copies is int or starting_copies != 0:
		return false
	var reward_eligible: Variant = definition.get("reward_eligible")
	if not reward_eligible is bool or bool(reward_eligible) != bool(card["reward_eligible"]):
		return false
	# Both printings share the one authored base-card illustration.
	if definition.get("illustration_path") != "res://assets/paper/cards/lantern_monk_moth_lure.png":
		return false
	# The base and "+" records must still point at each other, so a copied or relinked record
	# cannot be paid for under the other printing's ID.
	if card.has("upgrade_id"):
		return definition.get("upgrade_id") == card["upgrade_id"] \
			and not definition.has("upgrade_of")
	return definition.get("upgrade_of") == card["upgrade_of"] \
		and not definition.has("upgrade_id")


func _exact_positions(value: Variant, expected: Array[int]) -> bool:
	if not value is Array or value.size() != expected.size():
		return false
	for index in range(expected.size()):
		if not value[index] is int or value[index] != expected[index]:
			return false
	return true


## Typed equality rejects coercible metadata (e.g. a String "1" or an int 1 standing in for the
## boolean Blind descriptor, or a bool standing in for an int draw/cost) as well as changed effects.
func _same_value(actual: Variant, expected: Variant) -> bool:
	if typeof(actual) != typeof(expected):
		return false
	if expected is Dictionary:
		var expected_dict: Dictionary = expected
		if actual.size() != expected_dict.size():
			return false
		for key in expected_dict:
			if not (actual as Dictionary).has(key):
				return false
			if not _same_value(actual[key], expected_dict[key]):
				return false
		return true
	if expected is Array:
		if actual.size() != expected.size():
			return false
		for index in range(expected.size()):
			if not _same_value(actual[index], expected[index]):
				return false
		return true
	return actual == expected


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
