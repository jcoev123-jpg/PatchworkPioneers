class_name CombatYarnRangerEndlessSkeinCards
extends RefCounted
## Scene-free paid resolver for the Yarn Ranger's rare Endless Skein and Endless Skein+ (V3-1).
##
## Both printings cost three energy, cast from the middle or back seat (FROM 2-3) and strike
## EVERY living enemy in original slots 1-3 with printed damage (base 4, "+" 6); each struck
## foe then gains printed Tangled (base 2, "+" 3). The card deals no secondary hit, draws
## nothing, moves nobody, exhausts nothing and never advances the run RNG.
##
## The catalog stays authoritative: the caller supplies a held ID only, never a card record,
## damage value or Tangled count. Each ID is authenticated against its own exact pool record
## before anything is paid, so a rewritten, relinked or foreign record is refused instead of
## resolving as a skein.
##
## Damage is resolved through CombatStatusAttacks against each target's PRE-HIT statuses, so an
## enemy already Tangled confers its flat +2 even when the damage is fully absorbed by Block.
## The NEW Tangled added by this same cast never boosts that same hit. After each hit the printed
## Tangled count is added to that same authoritative enemy slot; a confirmed lethal hit therefore
## keeps its status on the nonmoving original slot. Slain slots are skipped untouched, preserving
## their position, HP and counters. CombatStatuses/CombatStatusTurnBatch keep owning the Tangled
## count's owner-turn tick; nothing here invents a duration, refresh or early clear.
##
## Every rejection is a pure no-op: no energy, hand, pile, party, enemy or RNG change. This is
## callable rules-layer behaviour only; registering these IDs in the live hand, rewards or app
## flow is a later, separately owned wiring task, so this file does not claim live playability.

const OWNER := "yarn_ranger"
const TARGET_KIND := "enemy_all"
const FROM_POSITIONS := [2, 3]
const TO_POSITIONS := [1, 2, 3]

## The two authentic printings and the exact catalog line each one must still carry. `name` is
## the printed display name, `damage` the printed per-foe damage, `tangled` the printed count
## added to every struck foe, and `effects` the complete authored descriptor.
const CARDS := {
	"yarn_ranger_endless_skein": {
		"name": "Endless Skein",
		"cost": 3,
		"damage": 4,
		"tangled": 2,
		"effects": {"damage": 4, "tangled": 2, "living_targets_only": true},
		"upgrade_id": "yarn_ranger_endless_skein_plus",
	},
	"yarn_ranger_endless_skein_plus": {
		"name": "Endless Skein+",
		"cost": 3,
		"damage": 6,
		"tangled": 3,
		"effects": {"damage": 6, "tangled": 3, "living_targets_only": true},
		"upgrade_of": "yarn_ranger_endless_skein",
	},
}

const _POOL_CATALOG := preload("res://data/cards/yarn_ranger_pool_cards.gd")

var _batch := CombatStatusTurnBatch.new()
var _attacks := CombatStatusAttacks.new()


## True only for the two authentic catalog IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


## A detached, shape-checked skein definition from the pool catalog that owns the ID, or {} for
## anything else. Unrelated cards, forged spellings and tampered records all resolve to {}.
static func skein_definition(card_id: Variant) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return {}
	var id: String = card_id
	if not CARDS.has(id):
		return {}
	var definition: Dictionary = _POOL_CATALOG.new().get_definition(id)
	if not is_authentic_definition(definition, id):
		return {}
	return definition


## The record must still carry the authored rare line: id, printed name, owner, three-energy
## cost, the middle/back FROM seats, the all-enemy target, the 1-3 TO line, exactly the printed
## damage/Tangled plus the living-only flag, and the base/"+" link in its own catalog.
static func is_authentic_definition(definition: Variant, card_id: Variant) -> bool:
	if typeof(definition) != TYPE_DICTIONARY or typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	var card: Dictionary = CARDS.get(id, {})
	if card.is_empty():
		return false
	if definition.get("id") != id or definition.get("owner") != OWNER:
		return false
	if definition.get("display_name") != card["name"]:
		return false
	if typeof(definition.get("cost")) != TYPE_INT or definition["cost"] != card["cost"]:
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if typeof(definition.get("from_positions")) != TYPE_ARRAY \
			or definition["from_positions"] != FROM_POSITIONS:
		return false
	if typeof(definition.get("to_positions")) != TYPE_ARRAY \
			or definition["to_positions"] != TO_POSITIONS:
		return false
	var effects: Variant = definition.get("effects")
	if typeof(effects) != TYPE_DICTIONARY or (effects as Dictionary).size() != 3:
		return false
	var printed: Dictionary = card["effects"]
	var damage: Variant = (effects as Dictionary).get("damage")
	var tangled: Variant = (effects as Dictionary).get("tangled")
	var living_only: Variant = (effects as Dictionary).get("living_targets_only")
	if typeof(damage) != TYPE_INT or typeof(tangled) != TYPE_INT:
		return false
	if damage != card["damage"] or tangled != card["tangled"] or living_only != true:
		return false
	if effects != printed:
		return false
	if card.has("upgrade_id"):
		return definition.get("upgrade_id") == card["upgrade_id"] \
			and not definition.has("upgrade_of")
	return definition.get("upgrade_of") == card["upgrade_of"] \
		and not definition.has("upgrade_id")


## The single paid transaction: authenticate, preflight the whole roster and every Tangled
## addition, then charge once, resolve one printed hit per cast-time living enemy in original
## slot order and add the printed Tangled to each struck slot. A refusal changes no deck, party,
## enemy or RNG state.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# exact held ID is affordable, the owner is alive in an authored seat, at least one living enemy
	# exists and every recipient counter can take the printed addition. Keep the defensive returns
	# so an unexpected model change still fails closed before any partial status write.
	if not deck.try_spend_energy(plan["cost"]):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")
	var added: int = plan["tangled_added"]
	var defender_maps: Dictionary = plan["defender_statuses"]
	var hits: Array[Dictionary] = []
	for position in plan["target_positions"]:
		var slot: int = int(position)
		# The real authoritative enemy record, never a detached get_enemy copy, receives the new
		# Tangled after its hit. A confirmed lethal hit keeps its status on that original slot.
		var hit: Dictionary = _attacks.resolve_vs_enemy(
			enemies, slot, plan["base_damage"], plan["attacker_statuses"], defender_maps[slot])
		if not hit.get("ok", false):
			return _refusal("invalid_target")
		var record: Dictionary = enemies._enemies[slot - 1]
		if not record.has("statuses"):
			record["statuses"] = {}
		var statuses: Dictionary = record["statuses"]
		statuses["tangled"] = int(statuses.get("tangled", 0)) + added
		hits.append({
			"position": slot,
			"damage": hit.get("damage", 0),
			"block_absorbed": hit.get("block_absorbed", 0),
			"hp_loss": hit.get("hp_loss", 0),
			"tangled_added": added,
		})
	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": plan["cost"],
		"owner_position": plan["owner_position"],
		"base_damage": plan["base_damage"],
		"tangled_added": added,
		"target_positions": (plan["target_positions"] as Array).duplicate(),
		"hits": hits,
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
	if not is_authentic_definition(_POOL_CATALOG.new().get_definition(id), id):
		return _refusal("catalog_mismatch")

	if deck.combat_state == null or not deck.turn_active:
		return _refusal("inactive_turn")
	if not party.is_valid() or not enemies.is_valid():
		return _refusal("invalid_roster")

	# Validate the real party before touching it: distinct nonempty IDs in fixed seats with
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

	# Shared validator for the whole party and enemy roster, including status maps.
	if not _batch.tick_side("heroes", heroes).get("ok", false):
		return _refusal("invalid_party")
	var roster: Array[Dictionary] = enemies.get_enemies()
	if not _batch.tick_side("enemies", roster).get("ok", false):
		return _refusal("invalid_enemies")

	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = card["cost"]
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	# The owner's pre-hit statuses feed the shared damage rules. The shared bridge refuses an
	# attacker-side Blind (the miss/evasion path owns it), so reject that before paying.
	var attacker_raw: Variant = _read_statuses(heroes[owner_position - 1])
	if not attacker_raw is Dictionary:
		return _refusal("invalid_party")
	var attacker_statuses: Dictionary = attacker_raw
	if attacker_statuses.has("blind_next_attack"):
		return _refusal("invalid_party")

	# Preflight every cast-time living recipient in original slot order before paying: a slain
	# slot is skipped untouched, and an absent Tangled count adds from zero while an existing
	# count stacks. Validate each defender's bridge-compatible damage statuses and overflow here
	# so a paid cast cannot fail part-way through the roster.
	var added: int = card["tangled"]
	var targets: Array[int] = []
	var defender_statuses: Dictionary = {}
	for index in range(roster.size()):
		var enemy: Dictionary = roster[index]
		if int(enemy["hp"]) <= 0:
			continue
		var defender_raw: Variant = _read_statuses(enemy)
		if not defender_raw is Dictionary:
			return _refusal("invalid_enemies")
		var defender_map: Dictionary = defender_raw
		# A defender-side Dodge belongs to the separate miss/evasion path; never silently skip it.
		if defender_map.has("dodge_next_attack"):
			return _refusal("invalid_enemies")
		var current: int = int(defender_map.get("tangled", 0))
		if added > CombatStatuses.MAX_INT - current:
			return _refusal("status_overflow")
		var slot: int = index + 1
		targets.append(slot)
		defender_statuses[slot] = _bridge_statuses(defender_map, false)
	if targets.is_empty():
		return _refusal("no_living_target")

	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"base_damage": card["damage"],
		"tangled_added": added,
		"target_positions": targets,
		"attacker_statuses": _bridge_statuses(attacker_statuses, true),
		"defender_statuses": defender_statuses,
	}


func _read_statuses(actor: Dictionary) -> Variant:
	if not actor.has("statuses"):
		return {}
	return actor.get("statuses")


## Project a roster-valid status map onto the narrower CombatStatusAttacks bridge vocabulary.
## Damage counters and Fear pass through; the role-specific one-shot token is kept only for the
## role that owns it (Dodge for an attacker, Blind for a defender). The opposite token is already
## refused by the preflight above, so this never drops a live token silently.
func _bridge_statuses(statuses: Dictionary, for_attacker: bool) -> Dictionary:
	var projected: Dictionary = {}
	for name in statuses:
		if name == "dodge_next_attack":
			if for_attacker:
				projected[name] = statuses[name]
			continue
		if name == "blind_next_attack":
			if not for_attacker:
				projected[name] = statuses[name]
			continue
		projected[name] = statuses[name]
	return projected


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
