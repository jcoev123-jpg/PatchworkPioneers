class_name CombatTinkerV3OverloadCards
extends RefCounted
## Scene-free paid resolver for Tinker's Overload and Overload+ (V3-1).
##
## Overload is the payoff of the scrap backpack: Tinker dumps every loose part he has salvaged into the
## scrap blunderbuss and fires one raw hit. The card prints 2 damage plus 3 more for every Combat Scrap
## held (Overload+ prints 3 plus 4), and it spends ALL of that counter on a confirmed play. Both print
## one energy, are cast only from the middle or back seat (FROM 2-3) and target one living enemy
## (enemy_single, TO 1-3).
##
## Combat Scrap is Tinker's COMBAT counter stored on his own authoritative hero record (`combat_scrap`,
## an optional non-negative int that is absent - read as zero - on a fresh party). It is never the
## run-wallet `scraps` currency: this resolver reads no wallet and writes no wallet. Gear Brace and
## Spare Screws are the accepted producers of that same counter.
##
## The authored V3TinkerPoolCards catalog stays authoritative: the caller supplies a held ID and a
## target slot, never a card record, a cost, a damage figure or a scrap amount. Each ID is
## authenticated against its own printed record before anything is paid, so a forged, rewritten,
## relinked or foreign record is refused instead of resolving as Overload.
##
## A confirmed play pays the printed cost once, discards exactly one held copy, zeroes the Tinker's own
## counter (even when it was already zero) and lands exactly one raw hit on the chosen living enemy,
## with that enemy's Block absorbing before HP. The receipt reports the independent arithmetic
## (`base` + `per` * `combat_scrap_before`) and the real absorption.
##
## This slice resolves the card's UNMODIFIED raw damage. The live hand uses this same transaction
## and forwards its successful receipt through the existing outcome/ordinary-play observers without
## layering starter bonuses onto it. Nothing seeds or draws the run RNG or touches another counter.
##
## The same service also owns Tinker's second Combat Scrap spender, Scrapstorm / Scrapstorm+. Both
## print two energy, are cast only from the BACK seat (FROM 3), cover the whole authored enemy line
## (enemy_all, TO 1-3) and splash every LIVING enemy for printed base damage (3 / 4) plus one more
## per Combat Scrap spent, spending at most three of the counter and keeping any surplus. A downed
## enemy slot stays downed and is never hit; the ordered receipt lists each living target's own
## Block absorption and HP loss next to the spent and remaining counter. The single-target Overload
## contract below is untouched: Scrapstorm has its own named preflight and paid play, its own
## authenticator and its own catalog table, and neither ID resolves through the other.

const OWNER := "tinker"
const TARGET_KIND := "enemy_single"
const FROM_POSITIONS := [2, 3]
const TO_POSITIONS := [1, 2, 3]

const SCRAPSTORM := "tinker_v3_scrapstorm"
const SCRAPSTORM_PLUS := "tinker_v3_scrapstorm_plus"
const SCRAPSTORM_TARGET_KIND := "enemy_all"
const SCRAPSTORM_FROM_POSITIONS := [3]
const SCRAPSTORM_TO_POSITIONS := [1, 2, 3]
## `enemy_all` names no caller-chosen slot, so the only legal request is this whole-line sentinel.
const SCRAPSTORM_ALL_TARGET := 0

## The two authentic Scrapstorm printings and the exact catalog line each one must still carry.
## `damage` is the printed flat damage to each living enemy, `combat_scrap_spend_max` the most
## Combat Scrap one play may spend and `bonus_damage_per_combat_scrap` the printed bonus per spent
## scrap; `effects` is the complete authored effect dictionary (no extra or missing keys).
const SCRAPSTORM_CARDS := {
	"tinker_v3_scrapstorm": {
		"cost": 2,
		"rarity": "rare",
		"damage": 3,
		"combat_scrap_spend_max": 3,
		"bonus_damage_per_combat_scrap": 1,
		"is_upgrade": false,
		"effects": {"damage": 3, "combat_scrap_spend_max": 3,
			"bonus_damage_per_combat_scrap": 1, "living_targets_only": true},
	},
	"tinker_v3_scrapstorm_plus": {
		"cost": 2,
		"rarity": "rare",
		"damage": 4,
		"combat_scrap_spend_max": 3,
		"bonus_damage_per_combat_scrap": 1,
		"is_upgrade": true,
		"effects": {"damage": 4, "combat_scrap_spend_max": 3,
			"bonus_damage_per_combat_scrap": 1, "living_targets_only": true},
	},
}

## The two authentic printings and the exact catalog line each one must still carry. `damage` is the
## printed flat damage, `damage_per_combat_scrap` the printed bonus per held Combat Scrap and
## `effects` the complete authored effect dictionary (no extra or missing keys).
const CARDS := {
	"tinker_v3_overload": {
		"cost": 1,
		"damage": 2,
		"damage_per_combat_scrap": 3,
		"is_upgrade": false,
		"effects": {"damage": 2, "damage_per_combat_scrap": 3,
			"consume_all_combat_scrap": true},
	},
	"tinker_v3_overload_plus": {
		"cost": 1,
		"damage": 3,
		"damage_per_combat_scrap": 4,
		"is_upgrade": true,
		"effects": {"damage": 3, "damage_per_combat_scrap": 4,
			"consume_all_combat_scrap": true},
	},
}

const _CATALOG := preload("res://data/cards/v3_tinker_pool_cards.gd")

var _catalog := _CATALOG.new()


## True only for the two authentic catalog printings. Pure lookup; nothing is charged or mutated and
## no RNG is touched.
func is_supported_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	if not CARDS.has(id):
		return false
	return is_authentic_definition(_catalog.get_definition(id), id)


## A detached, shape-checked Overload definition from V3TinkerPoolCards, or {} for anything else.
## Unrelated cards, forged spellings, tampered records and the v2 Tinker pool all resolve to {}.
static func overload_definition(card_id: Variant) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return {}
	var id: String = card_id
	if not CARDS.has(id):
		return {}
	var definition: Dictionary = _CATALOG.new().get_definition(id)
	if not is_authentic_definition(definition, id):
		return {}
	return definition


## The record must still carry exactly the authored line: id, Tinker owner, the printed integer cost,
## the single-enemy target, the exact FROM/TO seats, exactly the printed effect dictionary (typed
## integer damage values and a boolean spend flag, no extra keys) and the base/"+" link expressed with
## V3TinkerPoolCards' base_id/upgrade_id/is_upgrade fields. A stray `upgrade_of` is a foreign shape.
static func is_authentic_definition(definition: Variant, card_id: Variant) -> bool:
	if typeof(definition) != TYPE_DICTIONARY or typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	var card: Dictionary = CARDS.get(id, {})
	if card.is_empty():
		return false
	if definition.get("id") != id or definition.get("owner") != OWNER:
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
	if typeof(effects) != TYPE_DICTIONARY:
		return false
	var effect_map: Dictionary = effects
	if effect_map.size() != (card["effects"] as Dictionary).size():
		return false
	for key in card["effects"]:
		if not effect_map.has(key):
			return false
		if typeof(effect_map[key]) != typeof(card["effects"][key]):
			return false
		if effect_map[key] != card["effects"][key]:
			return false
	if definition.has("upgrade_of"):
		return false
	var base_id: String = id.trim_suffix("_plus") if card["is_upgrade"] else id
	if definition.get("base_id") != base_id:
		return false
	if definition.get("upgrade_id") != base_id + "_plus":
		return false
	if typeof(definition.get("is_upgrade")) != TYPE_BOOL:
		return false
	return definition["is_upgrade"] == card["is_upgrade"]


## Read-only preflight of the whole transaction: it authenticates the held ID, the living Tinker at an
## authored seat, a living enemy at an authored slot, the energy, the non-negative integer counter and
## a representable damage total. Returns a detached plan or a refusal receipt; no state changes.
func preflight(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int) -> Dictionary:
	if deck == null or party == null or enemies == null:
		return _refusal("invalid_request")
	if deck.combat_state == null or deck._rng == null or not deck.turn_active:
		return _refusal("inactive_turn")
	if not party.is_valid() or party._heroes.size() != CombatParty.PARTY_SIZE:
		return _refusal("invalid_party")
	# CombatEnemies.is_valid() permits an all-slain roster, so the chosen target is checked separately.
	if not enemies.is_valid():
		return _refusal("invalid_enemies")
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	if not CARDS.has(id):
		return _refusal("unsupported_card")
	# Fetch the authored record from the catalog that owns this ID before anything is paid.
	var definition: Dictionary = overload_definition(id)
	if definition.is_empty():
		return _refusal("catalog_mismatch")
	var card: Dictionary = CARDS[id]

	# Validate the complete hero roster, then bind the owner by hero ID to its ACTUAL current slot.
	var scan: Dictionary = _scan_party(party)
	if not scan.get("ok", false):
		return _refusal(str(scan.get("reason", "invalid_party")))
	var heroes: Array[Dictionary] = party.get_heroes()
	var owner_position: int = int(scan.get("owner_position", 0))

	if owner_position == 0:
		return _refusal("owner_missing")
	# Overload prints FROM 2-3: the front seat is never a legal caster.
	if not FROM_POSITIONS.has(owner_position):
		return _refusal("owner_illegal_position")
	if int(heroes[owner_position - 1]["hp"]) == 0:
		return _refusal("owner_downed")

	# Verify the whole enemy roster and the chosen original slot; positions never compact.
	var enemy_scan: Dictionary = _scan_enemies(enemies)
	if not enemy_scan.get("ok", false):
		return _refusal(str(enemy_scan.get("reason", "invalid_enemies")))
	var enemy_records: Array[Dictionary] = enemies.get_enemies()
	if not target_position is int or not TO_POSITIONS.has(target_position) \
			or target_position > enemy_records.size():
		return _refusal("invalid_target")
	if int(enemy_records[target_position - 1]["hp"]) == 0:
		return _refusal("target_slain")

	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = int(card["cost"])
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	var base_damage: int = int(card["damage"])
	var per_scrap: int = int(card["damage_per_combat_scrap"])
	var counter_before: int = int(heroes[owner_position - 1].get("combat_scrap", 0))
	# Representable raw damage: base + per * counter must stay inside the int range.
	if per_scrap <= 0 or base_damage < 0:
		return _refusal("catalog_mismatch")
	if counter_before > (CombatParty.MAX_INT - base_damage) / per_scrap:
		return _refusal("damage_overflow")
	var scrap_damage: int = per_scrap * counter_before

	return {
		"ok": true,
		"reason": "legal",
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": target_position,
		"combat_scrap_before": counter_before,
		"base_damage": base_damage,
		"damage_per_combat_scrap": per_scrap,
		"damage_from_combat_scrap": scrap_damage,
		"raw_damage": base_damage + scrap_damage,
		"energy_before": deck.energy,
		"enemy_hp_before": int(enemy_records[target_position - 1]["hp"]),
		"enemy_block_before": int(enemy_records[target_position - 1]["block"]),
	}


## The single paid transaction: preflight the whole request, then pay one energy, discard exactly the
## held copy, spend ALL of the Tinker's Combat Scrap and land one raw hit on the chosen living enemy
## with that enemy's Block before HP. A refusal changes no deck, party, enemy, counter or RNG state.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int = 0) -> Dictionary:
	var plan: Dictionary = preflight(deck, party, enemies, card_id, target_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above. Keep the defensive returns
	# so an unexpected model change still fails closed.
	var id: String = str(plan["card_id"])
	var cost: int = int(plan["cost"])
	if not deck.try_spend_energy(cost):
		return _refusal("insufficient_energy")
	if not deck.discard_played(id):
		return _refusal("card_not_held")
	# Mutate only the real authoritative hero record, never the detached get_hero copy.
	var owner_position: int = int(plan["owner_position"])
	party._heroes[owner_position - 1]["combat_scrap"] = 0
	var target_position_value: int = int(plan["target_position"])
	var raw_damage: int = int(plan["raw_damage"])
	if not enemies.apply_damage(target_position_value, raw_damage):
		return _refusal("damage_rejected")
	var after: Dictionary = enemies.get_enemy(target_position_value)
	return {
		"ok": true,
		"reason": "applied",
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": target_position_value,
		"combat_scrap_before": int(plan["combat_scrap_before"]),
		"combat_scrap_spent": int(plan["combat_scrap_before"]),
		"combat_scrap_after": 0,
		"base_damage": int(plan["base_damage"]),
		"damage_per_combat_scrap": int(plan["damage_per_combat_scrap"]),
		"damage_from_combat_scrap": int(plan["damage_from_combat_scrap"]),
		"raw_damage": raw_damage,
		"damage": raw_damage,
		"hits": [{"position": target_position_value, "damage": raw_damage,
			"block_absorbed": int(plan["enemy_block_before"]) - int(after["block"]),
			"hp_loss": int(plan["enemy_hp_before"]) - int(after["hp"]),
			"statuses": {}}],
		"enemy_block_before": int(plan["enemy_block_before"]),
		"enemy_block_after": int(after["block"]),
		"block_absorbed": int(plan["enemy_block_before"]) - int(after["block"]),
		"enemy_hp_before": int(plan["enemy_hp_before"]),
		"enemy_hp_after": int(after["hp"]),
		"hp_loss": int(plan["enemy_hp_before"]) - int(after["hp"]),
		"energy_before": int(plan["energy_before"]),
		"energy_after": deck.energy,
	}


## ---------------------------------------------------------------------------
## Scrapstorm / Scrapstorm+: the paid three-scrap area spend.
## ---------------------------------------------------------------------------


## True only for the two authentic Scrapstorm printings. Pure lookup; nothing is charged or mutated
## and no RNG is touched.
func is_supported_scrapstorm(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	if not SCRAPSTORM_CARDS.has(id):
		return false
	return is_authentic_scrapstorm_definition(_catalog.get_definition(id), id)


## A detached, shape-checked Scrapstorm definition from V3TinkerPoolCards, or {} for anything else.
## Overload, unrelated v3 cards, forged spellings, tampered records and the v2 pool all resolve to {}.
static func scrapstorm_definition(card_id: Variant) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return {}
	var id: String = card_id
	if not SCRAPSTORM_CARDS.has(id):
		return {}
	var definition: Dictionary = _CATALOG.new().get_definition(id)
	if not is_authentic_scrapstorm_definition(definition, id):
		return {}
	return definition


## The record must still carry exactly the authored line: id, Tinker owner, rare rarity, the printed
## integer cost, the whole-line target, the exact FROM/TO lines, exactly the printed effect
## dictionary (typed integer amounts and a boolean living-only flag, no extra keys) and the base/"+"
## link in its own catalog. A stray `upgrade_of` is a foreign shape.
static func is_authentic_scrapstorm_definition(definition: Variant, card_id: Variant) -> bool:
	if typeof(definition) != TYPE_DICTIONARY or typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	var card: Dictionary = SCRAPSTORM_CARDS.get(id, {})
	if card.is_empty():
		return false
	if definition.get("id") != id or definition.get("owner") != OWNER:
		return false
	if definition.get("rarity") != card["rarity"]:
		return false
	if typeof(definition.get("cost")) != TYPE_INT or definition["cost"] != card["cost"]:
		return false
	if definition.get("target_kind") != SCRAPSTORM_TARGET_KIND:
		return false
	if typeof(definition.get("from_positions")) != TYPE_ARRAY \
			or definition["from_positions"] != SCRAPSTORM_FROM_POSITIONS:
		return false
	if typeof(definition.get("to_positions")) != TYPE_ARRAY \
			or definition["to_positions"] != SCRAPSTORM_TO_POSITIONS:
		return false
	var effects: Variant = definition.get("effects")
	if typeof(effects) != TYPE_DICTIONARY:
		return false
	var effect_map: Dictionary = effects
	if effect_map.size() != (card["effects"] as Dictionary).size():
		return false
	for key in card["effects"]:
		if not effect_map.has(key):
			return false
		if typeof(effect_map[key]) != typeof(card["effects"][key]):
			return false
		if effect_map[key] != card["effects"][key]:
			return false
	if definition.has("upgrade_of"):
		return false
	if definition.get("base_id") != SCRAPSTORM:
		return false
	if definition.get("upgrade_id") != SCRAPSTORM_PLUS:
		return false
	if typeof(definition.get("is_upgrade")) != TYPE_BOOL:
		return false
	return definition["is_upgrade"] == card["is_upgrade"]


## Read-only preflight of the whole area transaction: it authenticates the held ID, the living Tinker
## in the back seat, the energy, the non-negative integer counter, at least one living enemy in the
## authored line and a representable per-target damage total. `target_position` must stay
## SCRAPSTORM_ALL_TARGET (0) because `enemy_all` names no caller-chosen slot. Returns a detached plan
## whose `targets` list the living slots in ascending order, or a refusal receipt; no state changes.
func preflight_scrapstorm(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int = SCRAPSTORM_ALL_TARGET) -> Dictionary:
	if deck == null or party == null or enemies == null:
		return _refusal("invalid_request")
	if deck.combat_state == null or deck._rng == null or not deck.turn_active:
		return _refusal("inactive_turn")
	if not party.is_valid() or party._heroes.size() != CombatParty.PARTY_SIZE:
		return _refusal("invalid_party")
	# CombatEnemies.is_valid() permits an all-slain roster, so living targets are checked separately.
	if not enemies.is_valid():
		return _refusal("invalid_enemies")
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	if not SCRAPSTORM_CARDS.has(id):
		return _refusal("unsupported_card")
	# Fetch the authored record from the catalog that owns this ID before anything is paid.
	var definition: Dictionary = scrapstorm_definition(id)
	if definition.is_empty():
		return _refusal("catalog_mismatch")
	var card: Dictionary = SCRAPSTORM_CARDS[id]

	# Validate the complete hero roster, then bind the owner by hero ID to its ACTUAL current slot.
	var scan: Dictionary = _scan_party(party)
	if not scan.get("ok", false):
		return _refusal(str(scan.get("reason", "invalid_party")))
	var heroes: Array[Dictionary] = party.get_heroes()
	var owner_position: int = int(scan.get("owner_position", 0))
	if owner_position == 0:
		return _refusal("owner_missing")
	# Scrapstorm prints FROM 3: it fires only from the back seat.
	if not SCRAPSTORM_FROM_POSITIONS.has(owner_position):
		return _refusal("owner_illegal_position")
	if int(heroes[owner_position - 1]["hp"]) == 0:
		return _refusal("owner_downed")
	# `enemy_all` prints TO 1-3, so no single caller-chosen slot is ever accepted.
	if target_position != SCRAPSTORM_ALL_TARGET:
		return _refusal("invalid_target")

	# Verify the whole enemy roster, then collect the living authored slots in ascending order.
	var enemy_scan: Dictionary = _scan_enemies(enemies)
	if not enemy_scan.get("ok", false):
		return _refusal(str(enemy_scan.get("reason", "invalid_enemies")))
	var enemy_records: Array[Dictionary] = enemies.get_enemies()
	var live_targets: Array[int] = []
	for position: int in SCRAPSTORM_TO_POSITIONS:
		if position > enemy_records.size():
			continue
		if int(enemy_records[position - 1]["hp"]) == 0:
			continue
		live_targets.append(position)
	if live_targets.is_empty():
		return _refusal("no_living_targets")

	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = int(card["cost"])
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	var counter_before: int = int(heroes[owner_position - 1].get("combat_scrap", 0))
	var spend_max: int = int(card["combat_scrap_spend_max"])
	var bonus: int = int(card["bonus_damage_per_combat_scrap"])
	var base_damage: int = int(card["damage"])
	if spend_max < 0 or bonus <= 0 or base_damage < 0:
		return _refusal("catalog_mismatch")
	# Spend at most `spend_max`; whatever is left over stays on the Tinker's own counter.
	var spent: int = mini(spend_max, counter_before)
	# Representable raw damage: base + bonus * spent must stay inside the int range.
	if spent > 0 and bonus > (CombatParty.MAX_INT - base_damage) / spent:
		return _refusal("damage_overflow")
	var targets: Array[Dictionary] = []
	for position in live_targets:
		var enemy: Dictionary = enemy_records[position - 1]
		targets.append({"position": position, "hp_before": int(enemy["hp"]),
			"block_before": int(enemy["block"])})
	return {
		"ok": true,
		"reason": "legal",
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_kind": SCRAPSTORM_TARGET_KIND,
		"targets": targets,
		"combat_scrap_before": counter_before,
		"combat_scrap_spend_max": spend_max,
		"combat_scrap_spent": spent,
		"combat_scrap_after": counter_before - spent,
		"base_damage": base_damage,
		"bonus_damage_per_combat_scrap": bonus,
		"damage_from_combat_scrap": bonus * spent,
		"raw_damage": base_damage + bonus * spent,
		"energy_before": deck.energy,
	}


## The single paid area transaction: preflight the whole request, then pay the printed energy,
## discard exactly the held copy, spend at most three Combat Scrap (keeping any surplus) and land
## one raw hit on EACH living enemy in ascending authored slot, with that enemy's own Block before
## HP. Downed slots stay downed. The ordered receipt lists every living target's Block absorption
## and HP loss beside the spent and remaining counter. A refusal changes no deck, party, enemy,
## counter or RNG state.
func play_scrapstorm_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant,
		target_position: int = SCRAPSTORM_ALL_TARGET) -> Dictionary:
	var plan: Dictionary = preflight_scrapstorm(deck, party, enemies, card_id, target_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above. Keep the defensive returns
	# so an unexpected model change still fails closed.
	var id: String = str(plan["card_id"])
	var cost: int = int(plan["cost"])
	if not deck.try_spend_energy(cost):
		return _refusal("insufficient_energy")
	if not deck.discard_played(id):
		return _refusal("card_not_held")
	# Mutate only the real authoritative hero record, never the detached get_hero copy.
	var owner_position: int = int(plan["owner_position"])
	var counter_before: int = int(plan["combat_scrap_before"])
	var spent: int = int(plan["combat_scrap_spent"])
	if spent < 0 or spent > counter_before:
		return _refusal("catalog_mismatch")
	party._heroes[owner_position - 1]["combat_scrap"] = counter_before - spent
	var raw_damage: int = int(plan["raw_damage"])
	var hits: Array[Dictionary] = []
	var targets_hit: Array[int] = []
	var block_absorbed_total := 0
	var hp_loss_total := 0
	var targets: Array = plan["targets"]
	for target: Dictionary in targets:
		var position: int = int(target["position"])
		if not enemies.apply_damage(position, raw_damage):
			return _refusal("damage_rejected")
		var after: Dictionary = enemies.get_enemy(position)
		var absorbed: int = int(target["block_before"]) - int(after["block"])
		var loss: int = int(target["hp_before"]) - int(after["hp"])
		block_absorbed_total += absorbed
		hp_loss_total += loss
		targets_hit.append(position)
		hits.append({
			"position": position,
			"raw_damage": raw_damage,
			"block_before": int(target["block_before"]),
			"block_after": int(after["block"]),
			"block_absorbed": absorbed,
			"hp_before": int(target["hp_before"]),
			"hp_after": int(after["hp"]),
			"hp_loss": loss,
			"statuses": {},
		})
	return {
		"ok": true,
		"reason": "applied",
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_kind": SCRAPSTORM_TARGET_KIND,
		"targets_hit": targets_hit,
		"hits": hits,
		"targets_hit_count": hits.size(),
		"combat_scrap_before": counter_before,
		"combat_scrap_spend_max": int(plan["combat_scrap_spend_max"]),
		"combat_scrap_spent": spent,
		"combat_scrap_after": counter_before - spent,
		"base_damage": int(plan["base_damage"]),
		"bonus_damage_per_combat_scrap": int(plan["bonus_damage_per_combat_scrap"]),
		"damage_from_combat_scrap": int(plan["damage_from_combat_scrap"]),
		"raw_damage": raw_damage,
		"damage": raw_damage,
		"block_absorbed": block_absorbed_total,
		"hp_loss": hp_loss_total,
		"energy_before": int(plan["energy_before"]),
		"energy_after": deck.energy,
	}


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


func _scan_party(party: CombatParty) -> Dictionary:
	# Validate the whole hero roster before anything is paid. A fresh party has no counter at all;
	# only an explicit non-negative integer is state.
	var heroes: Array[Dictionary] = party.get_heroes()
	var seen_ids: Array[String] = []
	var owner_position := 0
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
		var counter = hero.get("combat_scrap", 0)
		if not counter is int or counter < 0:
			return _refusal("malformed_combat_scrap")
		seen_ids.append(hero_id)
		if hero_id == OWNER:
			owner_position = index + 1
	return {"ok": true, "reason": "legal", "owner_position": owner_position}


func _scan_enemies(enemies: CombatEnemies) -> Dictionary:
	# Roster structure only; living target eligibility is the caller's own decision.
	var records: Array[Dictionary] = enemies.get_enemies()
	var seen_ids: Array[String] = []
	for index in range(records.size()):
		var enemy: Dictionary = records[index]
		var enemy_id = enemy.get("id")
		var position = enemy.get("position")
		var hp = enemy.get("hp")
		var max_hp = enemy.get("max_hp")
		var block = enemy.get("block")
		if not enemy_id is String or enemy_id.is_empty() or seen_ids.has(enemy_id):
			return _refusal("invalid_enemies")
		if not position is int or position != index + 1:
			return _refusal("invalid_enemies")
		if not max_hp is int or max_hp <= 0:
			return _refusal("invalid_enemies")
		if not hp is int or hp < 0 or hp > max_hp:
			return _refusal("invalid_enemies")
		if not block is int or block < 0:
			return _refusal("invalid_enemies")
		seen_ids.append(enemy_id)
	return {"ok": true, "reason": "legal"}
