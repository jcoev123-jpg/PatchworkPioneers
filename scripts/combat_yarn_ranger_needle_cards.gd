class_name CombatYarnRangerNeedleCards
extends RefCounted
## Scene-free paid resolver for the Yarn Ranger's knitting-needle shots (V3-1).
##
## Needle Nock (starter) and Needle Arrow (pool) are single-enemy shots that deal printed
## damage and then charge that same foe's already-bound Unravel gauge with the printed
## count. Both base and upgraded printings cost one energy, fire from the middle or back
## seat (FROM 2-3) and target one living enemy in positions 1-3 (TO 1-3).
##
## The catalogs stay authoritative and single-owner: the caller supplies a held ID and a
## target seat, never a card record, damage value or Unravel count. Each ID is checked
## against the catalog that owns it before anything is paid, so a forged, rewritten,
## relinked or foreign record is refused instead of resolving as a needle shot.
##
## Damage is exactly ONE hit through CombatStatusAttacks against the target's PRE-HIT
## statuses, so the existing Weak -25%, Exposed +50%, Tangled +2 and Block-before-HP floor
## rules apply. After that hit the printed Unravel is added through the caller's existing
## CombatUnravel ledger, bound to this exact roster, and only while the same foe survives:
## a fully Block-absorbed nonlethal hit still charges the gauge, a lethal hit charges none
## (matching Tinker's Spool Launcher). This helper never creates or resets a gauge, never
## consumes a queued action skip and never touches thresholds: that stays with CombatUnravel
## and its turn consumer.
##
## Every rejection is a pure no-op: no energy, hand, pile, party, enemy, gauge or RNG change.
## A deterministic shot never draws from the shared run RNG. This is callable rules-layer
## behaviour only; dispatching a real held card from the live battle hand is a later,
## separately owned wiring task.
##
## Authoritative status maps may legitimately carry one-shot tokens the damage bridge does
## not model: an attacker's Dodge (`dodge_next_attack: 0|1`, e.g. the Rag Duelist's cape) or
## a defender's Blind (`blind_next_attack: 0|1`), plus the boolean Fear lock. Those never
## modify this shot's damage, so each map is validated in full and then only its detached
## damage-status subset is handed to the shared bridge; the real tokens are never spent,
## ticked or mutated. The opposite roles (attacker Blind, defender Dodge) stay refused, as
## the separate miss/evasion path owns them.

const OWNER := "yarn_ranger"
const TARGET_KIND := "enemy_single"
const FROM_POSITIONS := [2, 3]
const TO_POSITIONS := [1, 2, 3]
## The status keys whose counts modify one attack, exactly as CombatStatusAttacks accepts them.
const ATTACK_STATUS_KEYS: Array[String] = ["bleed", "weak", "exposed", "tangled", "riposte"]
## The one-shot token each side may already carry without changing this attack's damage.
const DODGE_STATUS_KEY := "dodge_next_attack"
const BLIND_STATUS_KEY := "blind_next_attack"
const FEAR_STATUS_KEY := "cannot_buff_next_turn"

## The four authentic printings and the exact catalog line each one must still carry.
## `display_name` is the printed name, `damage` the printed damage of the one hit,
## `unravel` the printed gauge charge added after it, and `catalog` the single catalog
## allowed to own that ID.
const CARDS := {
	"yarn_ranger_needle_nock": {
		"display_name": "Needle Nock",
		"cost": 1,
		"damage": 4,
		"unravel": 1,
		"effects": {"damage": 4, "unravel": 1},
		"catalog": "starter",
		"starting_copies": 1,
		"reward_eligible": false,
		"upgrade_id": "yarn_ranger_needle_nock_plus",
	},
	"yarn_ranger_needle_nock_plus": {
		"display_name": "Needle Nock+",
		"cost": 1,
		"damage": 6,
		"unravel": 2,
		"effects": {"damage": 6, "unravel": 2},
		"catalog": "starter",
		"starting_copies": 0,
		"reward_eligible": false,
		"upgrade_of": "yarn_ranger_needle_nock",
	},
	"yarn_ranger_needle_arrow": {
		"display_name": "Needle Arrow",
		"cost": 1,
		"damage": 5,
		"unravel": 1,
		"effects": {"damage": 5, "unravel": 1},
		"catalog": "pool",
		"starting_copies": 0,
		"reward_eligible": true,
		"upgrade_id": "yarn_ranger_needle_arrow_plus",
	},
	"yarn_ranger_needle_arrow_plus": {
		"display_name": "Needle Arrow+",
		"cost": 1,
		"damage": 7,
		"unravel": 2,
		"effects": {"damage": 7, "unravel": 2},
		"catalog": "pool",
		"starting_copies": 0,
		"reward_eligible": false,
		"upgrade_of": "yarn_ranger_needle_arrow",
	},
}

const _STARTER_CATALOG := preload("res://data/cards/yarn_ranger_starter_cards.gd")
const _POOL_CATALOG := preload("res://data/cards/yarn_ranger_pool_cards.gd")

var _batch := CombatStatusTurnBatch.new()
var _attacks := CombatStatusAttacks.new()
var _statuses := CombatStatuses.new()


## True only for the four authentic catalog IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


## A detached, shape-checked needle definition from the catalog that owns the ID, or {} for
## anything else. Unrelated cards, forged spellings and tampered records all resolve to {}.
static func needle_definition(card_id: Variant) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return {}
	var id: String = card_id
	var card: Dictionary = CARDS.get(id, {})
	if card.is_empty():
		return {}
	var definition: Dictionary = {}
	if card["catalog"] == "starter":
		definition = _STARTER_CATALOG.new().get_definition(id)
	else:
		definition = _POOL_CATALOG.new().get_definition(id)
	if not is_authentic_definition(definition, id):
		return {}
	return definition


## The record must still carry exactly the authored line: id, printed name, owner, printed
## one-energy cost, the middle/back FROM line, the single-enemy target, the 1-3 TO line,
## exactly the printed damage and Unravel (integer types only, no extra keys), the authored
## copy/reward metadata and the base/"+" link in its own catalog.
static func is_authentic_definition(definition: Variant, card_id: Variant) -> bool:
	if typeof(definition) != TYPE_DICTIONARY or typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	var card: Dictionary = CARDS.get(id, {})
	if card.is_empty():
		return false
	if definition.get("id") != id or definition.get("owner") != OWNER:
		return false
	if definition.get("display_name") != card["display_name"]:
		return false
	if typeof(definition.get("cost")) != TYPE_INT or definition["cost"] != card["cost"]:
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if typeof(definition.get("from_positions")) != TYPE_ARRAY \
			or definition["from_positions"] != FROM_POSITIONS:
		return false
	var to_positions: Variant = definition.get("to_positions")
	if typeof(to_positions) != TYPE_ARRAY or to_positions != TO_POSITIONS:
		return false
	var effects: Variant = definition.get("effects")
	if typeof(effects) != TYPE_DICTIONARY or (effects as Dictionary).size() != 2:
		return false
	var damage: Variant = (effects as Dictionary).get("damage")
	var unravel: Variant = (effects as Dictionary).get("unravel")
	if typeof(damage) != TYPE_INT or typeof(unravel) != TYPE_INT:
		return false
	if damage != card["damage"] or unravel != card["unravel"]:
		return false
	if effects != card["effects"]:
		return false
	if typeof(definition.get("starting_copies")) != TYPE_INT \
			or definition["starting_copies"] != card["starting_copies"]:
		return false
	if typeof(definition.get("reward_eligible")) != TYPE_BOOL \
			or definition["reward_eligible"] != card["reward_eligible"]:
		return false
	if card["catalog"] == "pool":
		if definition.get("rarity") != "common":
			return false
	elif definition.has("rarity"):
		return false
	if card.has("upgrade_id"):
		return definition.get("upgrade_id") == card["upgrade_id"] \
			and not definition.has("upgrade_of")
	return definition.get("upgrade_of") == card["upgrade_of"] \
		and not definition.has("upgrade_id")


## The single paid transaction: authenticate, preflight the whole request against the real
## active hand and the bound Unravel ledger, then charge once, resolve the printed damage as
## one CombatStatusAttacks hit, charge the printed Unravel on that same surviving foe and
## discard the held copy. A refusal changes no deck, party, enemy, gauge or RNG state.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		unravel: CombatUnravel, card_id: Variant, target_position: int) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, unravel, card_id, target_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above. Keep the
	# defensive returns so an unexpected model change still fails closed.
	if not deck.try_spend_energy(plan["cost"]):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")
	var hit: Dictionary = _attacks.resolve_vs_enemy(enemies, target_position,
		plan["damage"], plan["attacker_statuses"], plan["defender_statuses"])
	if not hit.get("ok", false):
		return _refusal("invalid_target")
	# Charge the existing ledger only while the same foe survives this hit. A lethal hit adds
	# no Unravel, and the slain seat keeps its original slot for later bookkeeping.
	var applied: int = 0
	if not enemies.is_slain(target_position):
		if unravel.apply_unravel(enemies, target_position, plan["unravel"]):
			applied = plan["unravel"]
	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": plan["cost"],
		"owner_position": plan["owner_position"],
		"target_position": target_position,
		"damage": hit.get("damage", 0),
		"block_absorbed": hit.get("block_absorbed", 0),
		"hp_loss": hit.get("hp_loss", 0),
		"unravel_added": applied,
		"unravel": unravel.get_snapshot(target_position),
	}


func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		unravel: CombatUnravel, card_id: Variant, target_position: int) -> Dictionary:
	if deck == null or party == null or enemies == null or unravel == null:
		return _refusal("invalid_request")
	if deck._rng == null:
		return _refusal("invalid_request")
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	var card: Dictionary = CARDS.get(id, {})
	if card.is_empty():
		return _refusal("unsupported_card")
	# The authored catalog that owns this ID must still carry the exact printed line.
	if needle_definition(id).is_empty():
		return _refusal("catalog_mismatch")

	if deck.combat_state == null or not deck.turn_active:
		return _refusal("inactive_turn")
	if not party.is_valid() or not enemies.is_valid():
		return _refusal("invalid_roster")
	# The Unravel ledger must already be bound to this exact encounter roster. This helper
	# never creates, rebinds or resets a gauge.
	if unravel._bound_enemies != enemies:
		return _refusal("invalid_unravel")

	# Validate the real roster before touching it: distinct nonempty IDs in fixed seats with
	# well-formed HP, max HP and Block. A malformed party can never authorize a paid play.
	var heroes: Array[Dictionary] = party.get_heroes()
	var seen_ids: Array[String] = []
	var owner_position := 0
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = heroes[index]
		var hero_id: Variant = hero.get("id")
		var position: Variant = hero.get("position")
		var hp: Variant = hero.get("hp")
		var max_hp: Variant = hero.get("max_hp")
		var current_block: Variant = hero.get("block")
		if typeof(hero_id) != TYPE_STRING or (hero_id as String).is_empty() \
				or seen_ids.has(hero_id):
			return _refusal("invalid_party")
		if typeof(position) != TYPE_INT or position != index + 1:
			return _refusal("invalid_party")
		if typeof(hp) != TYPE_INT or typeof(max_hp) != TYPE_INT \
				or max_hp <= 0 or hp < 0 or hp > max_hp:
			return _refusal("invalid_party")
		if typeof(current_block) != TYPE_INT \
				or current_block < 0 or current_block > CombatParty.MAX_INT:
			return _refusal("invalid_party")
		seen_ids.append(hero_id as String)
		if hero_id == OWNER:
			owner_position = index + 1
	if owner_position == 0:
		return _refusal("owner_missing")
	if heroes[owner_position - 1]["hp"] == 0:
		return _refusal("owner_downed")
	if not FROM_POSITIONS.has(owner_position):
		return _refusal("owner_illegal_position")

	# Shared validator for the whole party, including status maps.
	if not _batch.tick_side("heroes", heroes).get("ok", false):
		return _refusal("invalid_party")

	var roster: Array[Dictionary] = enemies.get_enemies()
	if not _batch.tick_side("enemies", roster).get("ok", false):
		return _refusal("invalid_enemies")
	for index in range(roster.size()):
		if roster[index].get("position") != index + 1:
			return _refusal("invalid_enemies")

	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = card["cost"]
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	# The target must be a living enemy in a legal slot.
	if target_position < 1 or target_position > roster.size():
		return _refusal("invalid_target")
	if enemies.is_slain(target_position):
		return _refusal("target_downed")

	# Pre-hit statuses: attacker from the Yarn Ranger, defender from the chosen foe. The
	# authoritative maps are validated in full, then projected to the detached damage-status
	# subset the shared attack bridge models so a legal Dodge/Blind/Fear token can never make
	# the paid hit fail or silently resolve as zero damage.
	var attacker_raw: Variant = _read_statuses(heroes[owner_position - 1])
	if not attacker_raw is Dictionary:
		return _refusal("invalid_party")
	var defender_record: Dictionary = enemies.get_enemy(target_position)
	var defender_raw: Variant = _read_statuses(defender_record)
	if not defender_raw is Dictionary:
		return _refusal("invalid_enemies")
	var attacker_statuses: Variant = _project_statuses(attacker_raw, DODGE_STATUS_KEY)
	if attacker_statuses == null:
		return _refusal("invalid_statuses")
	var defender_statuses: Variant = _project_statuses(defender_raw, BLIND_STATUS_KEY)
	if defender_statuses == null:
		return _refusal("invalid_statuses")

	# The bound ledger must cover this exact roster with well-formed gauges, and this card's
	# printed charge must fit that foe's current counter.
	for index in range(roster.size()):
		if not _valid_gauge(unravel.get_snapshot(index + 1)):
			return _refusal("invalid_unravel")
	var gauge_state: Dictionary = unravel.get_snapshot(target_position)
	var unravel_amount: int = card["unravel"]
	if gauge_state["gauge"] > CombatStatuses.MAX_INT - unravel_amount:
		return _refusal("invalid_unravel")

	var base_damage: int = card["damage"]
	var attacker_map: Dictionary = attacker_statuses
	var defender_map: Dictionary = defender_statuses
	# Guard the shared damage arithmetic the same way the hit will; a resolved zero-damage
	# shot must never be charged as a successful needle hit.
	if _statuses.adjusted_attack_damage(base_damage, attacker_map, defender_map) <= 0:
		return _refusal("invalid_statuses")

	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": target_position,
		"damage": base_damage,
		"unravel": unravel_amount,
		"attacker_statuses": attacker_map.duplicate(true),
		"defender_statuses": defender_map.duplicate(true),
	}


func _read_statuses(actor: Dictionary) -> Variant:
	if not actor.has("statuses"):
		return {}
	return actor.get("statuses")


## A detached copy of one authoritative status map holding only the counts that modify attack
## damage. Returns null for a non-Dictionary map, an unknown key, a non-int or negative count, a
## miss/evasion token on the wrong side, or a malformed Fear flag. The authoritative map itself
## is never modified, so a legal token stays on the real actor.
func _project_statuses(statuses: Variant, allowed_token: String) -> Variant:
	if not statuses is Dictionary:
		return null
	var authoritative: Dictionary = statuses
	var detached := {}
	for name in authoritative:
		if not name is String:
			return null
		var value: Variant = authoritative[name]
		if name == allowed_token:
			if typeof(value) != TYPE_INT or (value != 0 and value != 1):
				return null
			continue
		if name == FEAR_STATUS_KEY:
			if typeof(value) != TYPE_BOOL or not value:
				return null
			continue
		if name not in ATTACK_STATUS_KEYS:
			return null
		if typeof(value) != TYPE_INT or value < 0:
			return null
		detached[name] = value
	return detached


## A real CombatUnravel snapshot for one original seat: integer gauge inside a positive
## threshold with both one-shot flags present. Anything else is a tampered ledger.
func _valid_gauge(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	for field in ["gauge", "threshold"]:
		if typeof(snapshot.get(field)) != TYPE_INT:
			return false
	if snapshot["threshold"] <= 0 or snapshot["gauge"] < 0 \
			or snapshot["gauge"] > snapshot["threshold"]:
		return false
	return typeof(snapshot.get("unravelled")) == TYPE_BOOL \
		and typeof(snapshot.get("skip_pending")) == TYPE_BOOL


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
