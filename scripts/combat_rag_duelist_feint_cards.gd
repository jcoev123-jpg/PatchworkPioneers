class_name CombatRagDuelistFeintCards
extends RefCounted
## Scene-free paid resolver for Rag Duelist's Feint cards (V3-1).
##
## Feather Feint is a v3 starter and Velvet Feint a v3 common reward card; every printing
## carries exactly {"exposed": 1, "draw": 1} from seats 1-2 onto one enemy in 1-3. This
## service authenticates the exact held ID against the catalog that owns it (never supplied
## effect data), then resolves against the real deck, party and enemy models: one energy
## charge, Exposed added to the chosen enemy, one shared-deck draw through the deck's injected
## RNG, and exactly one played copy discarded.
##
## Exposed is stored by CombatEnemies.apply_statuses, so an existing counter stacks; its damage
## math and owner-turn ticking stay in the shared status classes. Draws, refills and shuffles
## stay in CombatDeck, which also owns the seeded generator; nothing here reseeds or draws an
## unseeded random number.
##
## Callable rules service only. These four IDs are not yet admitted to a live party deck, the
## mounted hand, the reward pool or any app flow; that wiring is a later task.

const OWNER := "rag_duelist"
const TARGET_KIND := "enemy_single"
const FROM_POSITIONS := [1, 2]
const TO_POSITIONS := [1, 2, 3]
const EFFECTS := {"exposed": 1, "draw": 1}

## The four authentic IDs, the catalog that owns each one, and the exact cost it must still
## print. The base printings cost 1 and the "+" printings are free.
const CARDS := {
	"rag_duelist_feather_feint": {"catalog": "starter", "cost": 1},
	"rag_duelist_feather_feint_plus": {"catalog": "starter", "cost": 0},
	"rag_duelist_velvet_feint": {"catalog": "pool", "cost": 1},
	"rag_duelist_velvet_feint_plus": {"catalog": "pool", "cost": 0},
}


## The single paid transaction: authenticate, preflight every input, then charge, add Exposed
## to the chosen enemy, draw (before discarding, so the played copy cannot refill itself) and
## discard exactly one held copy. A rejection changes no deck, party, enemy or RNG state.
## `target_position` is an enemy slot 1-3.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int = 0) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position)
	if not plan.get("ok", false):
		return _failure()
	# Every operation below is guaranteed by the complete preflight above: the turn is active,
	# the held ID exists, the cost is affordable, the owner is alive in a printed seat, the
	# target is a living legal enemy and the Exposed addition is accepted by the roster.
	if not deck.try_spend_energy(plan["cost"]):
		return _failure()
	if not enemies.apply_statuses({plan["target_position"]: {"exposed": plan["exposed"]}}):
		return _failure()
	# Draw while the played copy is still in hand, so this card is never part of its own
	# refill; zero available cards is a legal successful draw of nothing.
	var drawn: int = deck.draw_extra(plan["draw"])
	if drawn < 0:
		return _failure()
	if not deck.discard_played(card_id):
		return _failure()
	var target: Dictionary = enemies.get_enemy(plan["target_position"])
	return {
		"ok": true,
		"card_id": card_id,
		"cost": plan["cost"],
		"owner_position": plan["owner_position"],
		"target_position": plan["target_position"],
		"exposed": plan["exposed"],
		"drawn": drawn,
		"target_statuses": target.get("statuses", {}).duplicate(true),
	}


## True only for the four authentic catalog IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


## Read-only preflight of the whole transaction. Returns a detached plan or a failure record.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int) -> Dictionary:
	if deck == null or party == null or enemies == null:
		return _failure()
	if deck.combat_state == null or deck._rng == null or not deck.turn_active:
		return _failure()
	if not party.is_valid() or not enemies.is_valid():
		return _failure()

	var card: Dictionary = CARDS.get(card_id, {})
	if card.is_empty():
		return _failure()
	if not _authentic(_catalog_definition(card_id), card_id, card):
		return _failure()
	var cost: int = card["cost"]
	# The card must be genuinely held and affordable before any state changes; 0 is a real
	# printed cost for the "+" printings.
	if not deck.hand.has(card_id) or deck.energy < cost:
		return _failure()

	# Exactly one living Rag Duelist, standing in a printed FROM seat.
	var owner_position := 0
	var owners := 0
	var heroes: Array[Dictionary] = party.get_heroes()
	for index in range(heroes.size()):
		if heroes[index].get("id") != OWNER:
			continue
		owners += 1
		owner_position = index + 1
	if owners != 1:
		return _failure()
	if not FROM_POSITIONS.has(owner_position):
		return _failure()
	if party.is_downed(owner_position):
		return _failure()

	# The printed TO line is 1-3 and the chosen slot must still hold a living enemy.
	if not TO_POSITIONS.has(target_position):
		return _failure()
	if enemies.is_slain(target_position):
		return _failure()
	if enemies.get_enemy(target_position).is_empty():
		return _failure()
	# Preflight the full status addition (which also revalidates the roster) before any spend.
	if not enemies.can_apply_statuses({target_position: {"exposed": 1}}):
		return _failure()
	return {
		"ok": true,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": target_position,
		"exposed": 1,
		"draw": 1,
	}


## Reads the exact authored record from the catalog that owns this ID (never the other hero
## catalogs) and returns a detached copy, or {} when the ID is not in that catalog.
func _catalog_definition(card_id: String) -> Dictionary:
	var card: Dictionary = CARDS.get(card_id, {})
	var source: Variant = card.get("catalog", "")
	if source == "starter":
		return RagDuelistStarterCards.new().get_definition(card_id)
	if source == "pool":
		return RagDuelistPoolCards.new().get_definition(card_id)
	return {}


## The record must still carry exactly the authored line, so a rewritten catalog (extra
## effect, another target line or a changed cost) can never be paid for as this effect.
func _authentic(definition: Dictionary, card_id: String, card: Dictionary) -> bool:
	if definition.get("id") != card_id or definition.get("owner") != OWNER:
		return false
	if definition.get("cost") != card["cost"]:
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if definition.get("from_positions") != FROM_POSITIONS:
		return false
	if definition.get("to_positions") != TO_POSITIONS:
		return false
	return definition.get("effects") == EFFECTS


func _failure() -> Dictionary:
	return {"ok": false, "card_id": "", "cost": 0, "owner_position": 0,
		"target_position": 0, "exposed": 0, "drawn": 0, "target_statuses": {}}
