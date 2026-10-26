class_name CombatYarnRangerSnareCards
extends RefCounted
## Scene-free paid resolver for the Yarn Ranger's Snare Net and Snare Net+ (V3-1).
##
## Both print the same knitted net: two energy, cast from the middle or back seat, binding EVERY
## living enemy with Tangled (base 1, "+" 2). Enemy positions never compact, so a slain slot keeps
## its place and is neither targeted nor changed. This is an enemy-binding card: it deals no damage,
## moves nobody, draws nothing, spends no Block and never advances the run RNG.
##
## The catalog stays authoritative: the caller supplies a held ID only, never a card record or a
## stack size. Each held ID is authenticated against its own exact pool record before anything is
## paid, so a rewritten, relinked or foreign record is refused.
##
## Tangled writes go straight into the authoritative CombatEnemies records because the shared
## CombatEnemies.can_apply_statuses/apply_statuses vocabulary is still Bleed/Weak/Exposed only;
## broadening that core API belongs to its own owners. This resolver therefore validates the whole
## roster and every recipient status map itself (through CombatStatusTurnBatch, the same validator
## the enemy owner-turn tick uses), preflights every addition including integer overflow, and only
## then pays once and adds the printed count. CombatStatuses/CombatStatusTurnBatch keep owning the
## Tangled count's owner-turn tick; nothing here invents a duration, refresh or early clear.
##
## This is callable rules-layer behaviour only. It does not register these IDs in the live hand,
## rewards, run deck or the app flow; that wiring is a later task.

const OWNER := "yarn_ranger"
const TARGET_KIND := "enemy_all"
const FROM_POSITIONS := [2, 3]
const TO_POSITIONS := [1, 2, 3]

## The two authentic printings and the exact catalog line each one must still carry. `tangled` is
## the printed count added to every living enemy; a "+" only raises it.
const CARDS := {
	"yarn_ranger_snare_net": {
		"cost": 2,
		"tangled": 1,
		"effects": {"tangled": 1, "living_targets_only": true},
		"upgrade_id": "yarn_ranger_snare_net_plus",
	},
	"yarn_ranger_snare_net_plus": {
		"cost": 2,
		"tangled": 2,
		"effects": {"tangled": 2, "living_targets_only": true},
		"upgrade_of": "yarn_ranger_snare_net",
	},
}

var _catalog := preload("res://data/cards/yarn_ranger_pool_cards.gd").new()
var _batch := CombatStatusTurnBatch.new()


## True only for the two authentic catalog IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


## The single paid transaction: authenticate, preflight every input and every recipient counter,
## then charge the printed two energy, discard exactly the held copy and add Tangled to every
## living enemy in original slot order. A refusal changes no deck, party, enemy or RNG state.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# exact held ID is affordable, the owner is alive in an authored seat, at least one living enemy
	# exists and every recipient counter can take the printed addition. Keep the defensive returns
	# so an unexpected model change still fails closed before any status is written.
	if not deck.try_spend_energy(plan["cost"]):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")
	var added: int = plan["tangled_added"]
	var targets: Array = plan["target_positions"]
	for position in targets:
		# The real authoritative enemy record, never a detached get_enemy copy. Preflight already
		# guaranteed that an absent map means "no counters" and a present one is a valid dictionary,
		# so this write cannot fail part-way through the roster.
		var record: Dictionary = enemies._enemies[int(position) - 1]
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
		"tangled_added": added,
		"target_positions": targets.duplicate(),
	}


## Read-only preflight of the whole transaction. Returns a detached plan or a refusal receipt.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant) -> Dictionary:
	if deck == null or party == null or enemies == null:
		return _refusal("invalid_request")
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	var card: Dictionary = CARDS.get(id, {})
	if card.is_empty():
		return _refusal("unsupported_card")
	# The authored pool owns this ID; a rewritten, relinked or copied record is never paid for.
	if not _authentic(_catalog.get_definition(id), id, card):
		return _refusal("catalog_mismatch")

	if deck.combat_state == null or not deck.turn_active:
		return _refusal("inactive_turn")
	if not party.is_valid() or not enemies.is_valid():
		return _refusal("invalid_roster")
	# CombatStatusTurnBatch is the shared validator for a real roster: distinct nonempty hero IDs in
	# fixed seats, one to three enemy slots with well-formed IDs, positions, HP/max HP, Block and
	# status maps. Reusing it keeps this card's accepted vocabulary identical to the owner-turn tick.
	if not _batch.tick_side("heroes", party.get_heroes()).get("ok", false):
		return _refusal("invalid_party")
	var roster: Array[Dictionary] = enemies.get_enemies()
	if not _batch.tick_side("enemies", roster).get("ok", false):
		return _refusal("invalid_enemies")

	# Bind the owner by hero ID to its *current* seat; a swapped or misplaced hero grants no authority.
	var heroes: Array[Dictionary] = party.get_heroes()
	var owner_position := 0
	for index in range(heroes.size()):
		if heroes[index]["id"] == OWNER:
			owner_position = index + 1
	if owner_position == 0:
		return _refusal("owner_missing")
	if int(heroes[owner_position - 1]["hp"]) <= 0:
		return _refusal("owner_downed")
	if not FROM_POSITIONS.has(owner_position):
		return _refusal("owner_illegal_position")

	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = card["cost"]
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	# Preflight every living recipient in original slot order before paying: a slain slot is skipped
	# untouched, and an absent Tangled count adds from zero while an existing count stacks (the same
	# additive owner-turn convention every other N-turn status uses).
	var added: int = card["tangled"]
	var targets: Array[int] = []
	for index in range(roster.size()):
		var enemy: Dictionary = roster[index]
		if int(enemy["hp"]) <= 0:
			continue
		var current: int = _current_tangled(enemy)
		if added > CombatStatuses.MAX_INT - current:
			return _refusal("status_overflow")
		targets.append(index + 1)
	if targets.is_empty():
		return _refusal("no_living_target")
	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"tangled_added": added,
		"target_positions": targets,
	}


## The Tangled count already stored on a real enemy record; absent means no counter. The roster was
## already validated, so a present map and integer count are guaranteed here.
func _current_tangled(enemy: Dictionary) -> int:
	var statuses: Dictionary = enemy.get("statuses", {})
	return int(statuses.get("tangled", 0))


## The record must still carry exactly the authored line: owner, cost, seats, the all-enemy target,
## the one printed Tangled count plus the living-only flag, and the base/"+" link in its catalog.
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
	if definition.get("effects") != card["effects"]:
		return false
	if card.has("upgrade_id"):
		return definition.get("upgrade_id") == card["upgrade_id"] \
			and not definition.has("upgrade_of")
	return definition.get("upgrade_of") == card["upgrade_of"] \
		and not definition.has("upgrade_id")


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
