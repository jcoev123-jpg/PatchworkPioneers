class_name CombatTinkerV3CasingClampCards
extends RefCounted
## Scene-free paid resolver for Tinker's Brass Casing and Spring Clamp (V3-1).
##
## Brass Casing / Brass Casing+ ram a salvaged casing into one enemy: both print one energy, are cast
## only from the middle or back seat (FROM 2-3), target one living enemy (enemy_single, TO 1-3) and
## deal 4 / 6 raw damage plus exactly one Combat Scrap.
##
## Spring Clamp / Spring Clamp+ snap a sprung clamp onto one enemy: both print one energy, share the
## same FROM 2-3 seats and enemy_single target, deal 3 / 4 raw damage, add Weak 1 and gain exactly one
## Combat Scrap. The Weak lands even when the enemy's Block absorbs the whole hit.
##
## Combat Scrap is Tinker's COMBAT counter stored on his own authoritative hero record
## (`combat_scrap`, an optional non-negative int that is absent - read as zero - on a fresh party). It
## is never the run-wallet `scraps` currency: this resolver reads no wallet and writes no wallet.
##
## The authored V3TinkerPoolCards catalog stays authoritative: the caller supplies a held ID and a
## target slot, never a card record, a cost, a damage figure, a Weak amount or a scrap amount. Each ID
## is authenticated against its own printed record before anything is paid, so a forged, rewritten,
## relinked or foreign record is refused instead of resolving as one of these attacks.
##
## A confirmed play pays the printed cost once, discards exactly one held copy, lands exactly one
## unmodified printed raw hit on the chosen living enemy (that enemy's Block absorbs before HP), adds
## the printed Weak through the existing CombatEnemies status API and increments only the living
## Tinker's own counter by one. Weak's 25% attack reduction, its duration and its expiry remain in the
## existing CombatStatuses/CombatStatusTurnBatch rules; this slice neither applies nor ages it.
##
## This slice does NOT add Tinker's first-attack +3 passive, reward rolls, the live hand wiring,
## status aging, a second RNG or any new combat resource. Every rejection is a pure no-op: no energy,
## hand, pile, party, enemy, counter or RNG change.

const OWNER := "tinker"
const TARGET_KIND := "enemy_single"
const FROM_POSITIONS := [2, 3]
const TO_POSITIONS := [1, 2, 3]

## The four authentic printings and the exact catalog line each one must still carry. `damage` is the
## printed raw damage (no status modifier), `weak` the printed Weak stacks, `combat_scrap_gain` the
## printed counter gain and `effects` the complete authored effect dictionary (no extra or missing
## keys). A "+" only raises the printed damage.
const CARDS := {
	"tinker_v3_brass_casing": {
		"cost": 1,
		"damage": 4,
		"weak": 0,
		"combat_scrap_gain": 1,
		"is_upgrade": false,
		"upgrade_id": "tinker_v3_brass_casing_plus",
		"effects": {"damage": 4, "combat_scrap_gain": 1},
	},
	"tinker_v3_brass_casing_plus": {
		"cost": 1,
		"damage": 6,
		"weak": 0,
		"combat_scrap_gain": 1,
		"is_upgrade": true,
		"base_id": "tinker_v3_brass_casing",
		"effects": {"damage": 6, "combat_scrap_gain": 1},
	},
	"tinker_v3_spring_clamp": {
		"cost": 1,
		"damage": 3,
		"weak": 1,
		"combat_scrap_gain": 1,
		"is_upgrade": false,
		"upgrade_id": "tinker_v3_spring_clamp_plus",
		"effects": {"damage": 3, "weak": 1, "combat_scrap_gain": 1},
	},
	"tinker_v3_spring_clamp_plus": {
		"cost": 1,
		"damage": 4,
		"weak": 1,
		"combat_scrap_gain": 1,
		"is_upgrade": true,
		"base_id": "tinker_v3_spring_clamp",
		"effects": {"damage": 4, "weak": 1, "combat_scrap_gain": 1},
	},
}

const _CATALOG := preload("res://data/cards/v3_tinker_pool_cards.gd")

var _catalog := _CATALOG.new()


## True only for the four authentic catalog printings. Pure lookup; nothing is charged or mutated and
## no RNG is touched.
func is_supported_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	if not CARDS.has(id):
		return false
	return is_authentic_definition(_catalog.get_definition(id), id)


## A detached, shape-checked casing/clamp definition from V3TinkerPoolCards, or {} for anything else.
## Unrelated cards, forged spellings, tampered records and the v2 Tinker pool all resolve to {}.
static func casing_clamp_definition(card_id: Variant) -> Dictionary:
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
## integer values, no extra keys) and the base/"+" link expressed with V3TinkerPoolCards'
## base_id/upgrade_id/is_upgrade fields. A stray `upgrade_of` is a foreign shape.
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
	if not _matches_authored(definition.get("from_positions"), FROM_POSITIONS):
		return false
	if not _matches_authored(definition.get("to_positions"), TO_POSITIONS):
		return false
	if not _matches_authored(definition.get("effects"), card["effects"]):
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


## Recursive exact-shape comparison: every level must carry the authored keys, values and Variant
## types, so `3.0`, `"3"` or a missing/extra key never authenticates as the printed record.
static func _matches_authored(value: Variant, expected: Variant) -> bool:
	if typeof(expected) == TYPE_DICTIONARY:
		if typeof(value) != TYPE_DICTIONARY:
			return false
		var actual: Dictionary = value
		var wanted: Dictionary = expected
		if actual.size() != wanted.size():
			return false
		for key in wanted:
			if not actual.has(key):
				return false
			if not _matches_authored(actual[key], wanted[key]):
				return false
		return true
	if typeof(expected) == TYPE_ARRAY:
		if typeof(value) != TYPE_ARRAY:
			return false
		var actual_items: Array = value
		var wanted_items: Array = expected
		if actual_items.size() != wanted_items.size():
			return false
		for index in range(wanted_items.size()):
			if not _matches_authored(actual_items[index], wanted_items[index]):
				return false
		return true
	if typeof(value) != typeof(expected):
		return false
	return value == expected


## Read-only preflight of the whole transaction: it authenticates the held ID, the living Tinker at an
## authored seat, a living enemy at an authored original slot, the energy, the enemy status data, a
## representable Weak addition and the Tinker-only Combat Scrap counter. Returns a detached plan or a
## refusal receipt; no state changes.
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
	var definition: Dictionary = casing_clamp_definition(id)
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
	# These cards print FROM 2-3: the front seat is never a legal caster.
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
	var enemy_before: Dictionary = enemy_records[target_position - 1]
	if int(enemy_before["hp"]) == 0:
		return _refusal("target_slain")

	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = int(card["cost"])
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	var raw_damage: int = int(card["damage"])
	var weak: int = int(card["weak"])
	var gain: int = int(card["combat_scrap_gain"])
	if raw_damage < 0 or weak < 0 or gain < 0:
		return _refusal("catalog_mismatch")
	# The printed counter gain must stay representable on the Tinker's own record.
	var counter_before: int = int(heroes[owner_position - 1].get("combat_scrap", 0))
	if gain > CombatParty.MAX_INT - counter_before:
		return _refusal("combat_scrap_overflow")
	# Validate every roster's status shape before touching any status counter; an empty application
	# set still runs the existing status batch validator.
	if not enemies.can_apply_statuses({}):
		return _refusal("invalid_statuses")
	var weak_before: int = int(enemy_before.get("statuses", {}).get("weak", 0))
	if weak > 0 and weak > CombatParty.MAX_INT - weak_before:
		return _refusal("status_overflow")

	return {
		"ok": true,
		"reason": "legal",
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": target_position,
		"raw_damage": raw_damage,
		"weak": weak,
		"combat_scrap_before": counter_before,
		"combat_scrap_gain": gain,
		"energy_before": deck.energy,
		"enemy_hp_before": int(enemy_before["hp"]),
		"enemy_block_before": int(enemy_before["block"]),
		"enemy_weak_before": weak_before,
	}


## The single paid transaction: preflight the whole request, then pay the printed energy, discard
## exactly the held copy, land one unmodified raw hit on the chosen living enemy (Block before HP),
## add the printed Weak 1 through the existing status API even when Block absorbed the hit, and add
## the printed Combat Scrap to the living Tinker's own authoritative record. A refusal changes no
## deck, party, enemy, counter or RNG state.
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
	var counter_before: int = int(plan["combat_scrap_before"])
	var gain: int = int(plan["combat_scrap_gain"])
	party._heroes[owner_position - 1]["combat_scrap"] = counter_before + gain
	var target: int = int(plan["target_position"])
	var raw_damage: int = int(plan["raw_damage"])
	if not enemies.apply_damage(target, raw_damage):
		return _refusal("damage_rejected")
	var weak: int = int(plan["weak"])
	if weak > 0 and not enemies.apply_statuses({target: {"weak": weak}}):
		return _refusal("status_rejected")
	var after: Dictionary = enemies.get_enemy(target)
	var hp_loss: int = int(plan["enemy_hp_before"]) - int(after["hp"])
	var block_absorbed: int = int(plan["enemy_block_before"]) - int(after["block"])
	var weak_after: int = int(after.get("statuses", {}).get("weak", 0))
	return {
		"ok": true,
		"reason": "applied",
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": target,
		"raw_damage": raw_damage,
		"damage": raw_damage,
		"weak": weak,
		"statuses": {"weak": weak} if weak > 0 else {},
		"combat_scrap_before": counter_before,
		"combat_scrap_gained": gain,
		"combat_scrap_after": counter_before + gain,
		"enemy_hp_before": int(plan["enemy_hp_before"]),
		"enemy_hp_after": int(after["hp"]),
		"hp_loss": hp_loss,
		"enemy_block_before": int(plan["enemy_block_before"]),
		"enemy_block_after": int(after["block"]),
		"block_absorbed": block_absorbed,
		"enemy_weak_before": int(plan["enemy_weak_before"]),
		"enemy_weak_after": weak_after,
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
	# Roster structure only; living target eligibility and status shapes are checked separately.
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
