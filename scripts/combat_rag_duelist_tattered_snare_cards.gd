class_name CombatRagDuelistTatteredSnareCards
extends RefCounted
## Scene-free paid resolver for the Rag Duelist's Tattered Snare and Tattered Snare+ (V3-1).
##
## Both printings cost one energy, cast from seat 1 or 2 onto a single chosen living enemy
## in slot 1-3, and add the printed Tangled count (base 2, + 3) to that foe's existing
## counter. No damage, draw, Block, movement or RNG consumption accompanies this status-only
## card. The authoritative status map writes go straight into the real CombatEnemies record,
## because the shared apply_statuses vocabulary is still Bleed/Weak/Exposed only; this resolver
## preflights every recipient counter for overflow and leaves the existing owner-turn tick
## rules untouched.
##
## This is callable rules-layer behaviour only. No live hand, reward, save, run-deck or app
## wiring is implemented here.

const OWNER := "rag_duelist"
const TARGET_KIND := "enemy_single"
const FROM_POSITIONS: Array[int] = [1, 2]
const TO_POSITIONS: Array[int] = [1, 2, 3]

const CARDS := {
	"rag_duelist_tattered_snare": {
		"cost": 1,
		"tangled": 2,
		"effects": {"tangled": 2},
		"upgrade_id": "rag_duelist_tattered_snare_plus",
	},
	"rag_duelist_tattered_snare_plus": {
		"cost": 1,
		"tangled": 3,
		"effects": {"tangled": 3},
		"upgrade_of": "rag_duelist_tattered_snare",
	},
}

var _catalog := preload("res://data/cards/rag_duelist_pool_cards.gd").new()
var _batch := CombatStatusTurnBatch.new()


func is_supported_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	if not CARDS.has(id):
		return false
	return _authentic(id, CARDS[id])


func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int = 0) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Defensive: the complete preflight guarantees these operations succeed.
	if not deck.try_spend_energy(plan["cost"]):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")

	var added: int = plan["tangled_added"]
	var target_slot: int = plan["target_position"]
	var record: Dictionary = enemies._enemies[target_slot - 1]
	if not record.has("statuses"):
		record["statuses"] = {}
	var statuses: Dictionary = record["statuses"]
	statuses["tangled"] = int(statuses.get("tangled", 0)) + added

	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": plan["cost"],
		"owner_position": plan["owner_position"],
		"owner_id": OWNER,
		"target_position": target_slot,
		"tangled_added": added,
	}


func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int) -> Dictionary:
	if deck == null or party == null or enemies == null:
		return _refusal("invalid_request")
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	if not CARDS.has(id):
		return _refusal("unsupported_card")
	var card: Dictionary = CARDS[id]
	if not _authentic(id, card):
		return _refusal("catalog_mismatch")

	if deck.combat_state == null or not deck.turn_active:
		return _refusal("inactive_turn")
	if not party.is_valid() or not enemies.is_valid():
		return _refusal("invalid_roster")

	# Validate the full hero roster (same validator the owner-turn tick uses).
	if not _batch.tick_side("heroes", party.get_heroes()).get("ok", false):
		return _refusal("invalid_party")
	var roster: Array[Dictionary] = enemies.get_enemies()
	if not _batch.tick_side("enemies", roster).get("ok", false):
		return _refusal("invalid_enemies")

	# Bind the owner by its current seat.
	var heroes: Array[Dictionary] = party.get_heroes()
	var owner_position := 0
	var owners := 0
	for index in range(heroes.size()):
		if heroes[index]["id"] == OWNER:
			owners += 1
			owner_position = index + 1
	if owners != 1:
		return _refusal("invalid_party")
	if owner_position == 0 or not FROM_POSITIONS.has(owner_position):
		return _refusal("invalid_owner_position")
	if int(heroes[owner_position - 1]["hp"]) <= 0:
		return _refusal("owner_downed")

	# Target validation: must be a living enemy in the printed TO line.
	if not TO_POSITIONS.has(target_position):
		return _refusal("invalid_target")
	if target_position > roster.size():
		return _refusal("invalid_target")
	if int(roster[target_position - 1]["hp"]) <= 0:
		return _refusal("target_slain")

	# Hand and payment.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = card["cost"]
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	# Preflight the Tangled addition against the target's current counter.
	var added: int = card["tangled"]
	var target_statuses: Dictionary = roster[target_position - 1].get("statuses", {})
	var current: int = 0
	if target_statuses.has("tangled"):
		current = int(target_statuses.get("tangled", 0))
	if current < 0:
		return _refusal("invalid_target")
	if added > CombatStatuses.MAX_INT - current:
		return _refusal("status_overflow")

	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": target_position,
		"tangled_added": added,
	}


func _authentic(id: String, card: Dictionary) -> bool:
	var definition: Dictionary = _catalog.get_definition(id)
	if definition.is_empty():
		return false
	if definition.get("id") != id or definition.get("owner") != OWNER:
		return false
	if definition.get("cost") != card["cost"]:
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if definition.get("from_positions") != FROM_POSITIONS:
		return false
	if definition.get("to_positions") != TO_POSITIONS:
		return false
	if definition.get("effects") != card["effects"]:
		return false
	if card.has("upgrade_id"):
		return definition.get("upgrade_id") == card["upgrade_id"] \
			and not definition.has("upgrade_of")
	return definition.get("upgrade_of") == card["upgrade_of"] \
		and not definition.has("upgrade_id")


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
