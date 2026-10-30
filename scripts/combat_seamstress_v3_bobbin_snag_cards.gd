class_name CombatSeamstressV3BobbinSnagCards
extends RefCounted
## Scene-free paid resolver for the Seamstress's v3 Bobbin Snag reward printings (V3-1).
##
## Bobbin Snag and Bobbin Snag+ are needle-and-thread control, not strikes. Each pays one energy to
## charge a chosen living enemy with the printed Unravel (3 on the base, 4 on the "+") and to pin
## that same original enemy slot for the Seamstress. The card prints no damage, Block, draw, status,
## heal or enemy movement, and this service never moves an enemy, collapses original positions or
## advances the run RNG.
##
## The two shared battle authorities stay authoritative and are never reimplemented here:
##
## * The caller's roster-bound CombatUnravel owns the per-slot gauge, its 8/12/16 normal/elite/boss
##   threshold, the single queued action skip and the post-skip reset. This service only asks it to
##   apply the printed charge; crossing the threshold, clamping and the one-pending-skip rule remain
##   its own behaviour.
## * The caller's live CombatPinned owns the token map. `pin_enemy` records the Seamstress as the
##   pinner and replaces any earlier pinner on that slot; the +5 cross-hero attack bonus, its
##   consumption on a later confirmed attack by a different hero, and the preview/same-owner
##   non-consumption are all CombatPinned's rules, not this card's. No attack is resolved here.
##
## The Seamstress's authored +1 Bleed passive is irrelevant to this card and is not applied: Bobbin
## Snag never prints or lays Bleed.
##
## The catalog stays authoritative: the caller supplies only a held card ID and one target slot,
## never effects, a cost, a seat list, a gauge amount or a pinner. Every refusal is a pure no-op:
## no energy, hand, pile, hero, enemy HP/Block/status, pin token, gauge or seeded RNG change. This is
## the callable rules layer only; registering these IDs in the live hand, rewards, run deck or app
## flow is a later task.

const OWNER_ID := "seamstress"
const PINNER_ID := "seamstress"
const TARGET_KIND := "enemy_single"

## The printed FROM line is exactly 2-3: the base has no legal seat at the front.
const FROM_POSITIONS: Array[int] = [2, 3]
## The printed TO line is exactly the three original enemy slots and never widens.
const TO_POSITIONS: Array[int] = [1, 2, 3]
## Same signed 64-bit ceiling the shared models use for their own counters.
const MAX_COUNTER := 9223372036854775807

## The two authentic reward printings, each with the complete catalog line it must still carry.
## Base and "+" share owner, cost, seats, target and the boolean Pin; only printed Unravel differs.
const PRINTINGS := {
	"seamstress_v3_bobbin_snag": {
		"display_name": "Bobbin Snag",
		"cost": 1,
		"unravel": 3,
		"effects": {"unravel": 3, "pinned": true},
		"upgrade_id": "seamstress_v3_bobbin_snag_plus",
	},
	"seamstress_v3_bobbin_snag_plus": {
		"display_name": "Bobbin Snag+",
		"cost": 1,
		"unravel": 4,
		"effects": {"unravel": 4, "pinned": true},
		"upgrade_of": "seamstress_v3_bobbin_snag",
	},
}

var _catalog: RefCounted


## `catalog` is the authoritative V3SeamstressPoolCards instance this service authenticates
## against. The default is the shipped catalog; an explicit instance lets a test prove that a
## rewritten record for an otherwise valid, held ID is refused instead of paid for.
func _init(catalog: Variant = null) -> void:
	_catalog = catalog if catalog is V3SeamstressPoolCards else V3SeamstressPoolCards.new()


## True only for the two authentic catalog IDs. Pure lookup; nothing is charged or mutated, and the
## v2 `seamstress_snag` / `seamstress_snag_plus` printings are never reported as supported.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and PRINTINGS.has(card_id)


## The single paid transaction: authenticate the printing, preflight the whole request, then charge
## one energy, discard exactly one held copy, add the printed Unravel to the bound gauge for the
## chosen original enemy slot and pin that same slot for the Seamstress. A refusal changes no deck,
## party, enemy, pin, gauge or RNG state.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		pinned: Variant, unravel: Variant, card_id: Variant,
		target_position: int = 0) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, pinned, unravel, card_id,
		target_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	var authority: CombatPinned = pinned
	var gauge_authority: CombatUnravel = unravel
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# exact held ID is affordable, the unique living owner sits in a printed seat, the target is a
	# living original enemy slot inside the printed TO window, the gauge is bound to this exact
	# roster and its charge cannot overflow. Keep the defensive returns so an unexpected model
	# change still fails closed. Nothing here draws cards or touches the seeded run RNG.
	if not deck.try_spend_energy(int(plan["cost"])):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")
	if not gauge_authority.apply_unravel(enemies, int(plan["target_position"]),
			int(plan["unravel_applied"])):
		return _refusal("unravel_rejected")
	if not authority.pin_enemy(enemies, int(plan["target_position"]), PINNER_ID):
		return _refusal("pin_rejected")

	var position: int = int(plan["target_position"])
	var gauge: Dictionary = gauge_authority.get_snapshot(position)
	var target: Dictionary = enemies.get_enemy(position)
	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": int(plan["cost"]),
		"energy_spent": int(plan["cost"]),
		"owner_position": int(plan["owner_position"]),
		"target_position": position,
		"printed_unravel": int(plan["printed_unravel"]),
		"unravel_applied": int(plan["unravel_applied"]),
		"unravel_snapshot": gauge,
		"gauge_before": plan["gauge_before"],
		"gauge": int(gauge.get("gauge", 0)),
		"threshold": int(gauge.get("threshold", 0)),
		"unravelled": gauge.get("unravelled") == true,
		"skip_pending": gauge.get("skip_pending") == true,
		"pinned": true,
		"pinner": authority.pinner_for_enemy(position),
		"prior_pinner": plan["prior_pinner"],
		"damage": 0,
		"hp_loss": 0,
		"block_absorbed": 0,
		"hp_before": int(plan["hp_before"]),
		"hp_after": int(target.get("hp", 0)),
		"block_before": int(plan["block_before"]),
		"block_after": int(target.get("block", 0)),
		"target_slain": enemies.is_slain(position),
	}


## Read-only preflight of the whole transaction. Returns a detached plan or a refusal receipt.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		pinned: Variant, unravel: Variant, card_id: Variant,
		target_position: int) -> Dictionary:
	var plan := {
		"ok": false, "reason": "unsupported_card",
		"card_id": card_id if typeof(card_id) == TYPE_STRING else "",
		"cost": 0, "owner_position": 0, "target_position": target_position,
		"printed_unravel": 0, "unravel_applied": 0, "gauge_before": {},
		"prior_pinner": "", "hp_before": 0, "block_before": 0,
	}
	if not is_supported_card(card_id):
		return plan
	var printed: Dictionary = _authenticate(card_id)
	if printed.is_empty():
		plan["reason"] = "catalog_mismatch"
		return plan
	plan["cost"] = int(printed["cost"])
	plan["printed_unravel"] = int(printed["unravel"])
	if deck == null or party == null or enemies == null:
		plan["reason"] = "invalid_request"
		return plan
	# Both shared battle authorities are mandatory: this resolver never manufactures a private
	# token map or gauge.
	if not pinned is CombatPinned:
		plan["reason"] = "invalid_pinned_authority"
		return plan
	if not unravel is CombatUnravel:
		plan["reason"] = "invalid_unravel_authority"
		return plan
	if deck.combat_state == null or deck._rng == null:
		plan["reason"] = "invalid_deck"
		return plan
	if not party.is_valid() or party._heroes.size() != CombatParty.PARTY_SIZE:
		plan["reason"] = "invalid_party"
		return plan
	if not enemies.is_valid() or enemies.is_victorious():
		plan["reason"] = "invalid_roster"
		return plan
	if not deck.turn_active:
		plan["reason"] = "inactive_turn"
		return plan

	# Verify the complete hero roster, then bind the Seamstress by ID to its actual current seat.
	# A swapped, torn, mislabelled or duplicated Seamstress grants no authority.
	var heroes: Array[Dictionary] = party.get_heroes()
	var owner_position := 0
	var seen_ids: Array[String] = []
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = heroes[index]
		var hero_id: Variant = hero.get("id")
		var hero_position: Variant = hero.get("position")
		var hp: Variant = hero.get("hp")
		var max_hp: Variant = hero.get("max_hp")
		var block: Variant = hero.get("block")
		if not hero_id is String or hero_id.is_empty() or seen_ids.has(hero_id):
			plan["reason"] = "invalid_party"
			return plan
		if not hero_position is int or hero_position != index + 1:
			plan["reason"] = "invalid_party"
			return plan
		if not max_hp is int or max_hp <= 0 or not hp is int or hp < 0 or hp > max_hp:
			plan["reason"] = "invalid_party"
			return plan
		if not block is int or block < 0:
			plan["reason"] = "invalid_party"
			return plan
		seen_ids.append(hero_id)
		if hero_id == OWNER_ID:
			owner_position = index + 1
	if owner_position == 0:
		plan["reason"] = "owner_missing"
		return plan
	if not FROM_POSITIONS.has(owner_position):
		plan["reason"] = "owner_illegal_position"
		return plan
	# A torn (0 HP) Seamstress cannot snag.
	if int(heroes[owner_position - 1]["hp"]) <= 0:
		plan["reason"] = "owner_downed"
		return plan
	plan["owner_position"] = owner_position

	# Verify every enemy slot's authoritative shape before the target query, so a malformed roster
	# never masquerades as a legal target. Original positions never compact.
	var roster: Array[Dictionary] = enemies.get_enemies()
	var seen_enemy_ids: Array[String] = []
	for index in range(roster.size()):
		var enemy: Dictionary = roster[index]
		var enemy_id: Variant = enemy.get("id")
		var enemy_position: Variant = enemy.get("position")
		var enemy_hp: Variant = enemy.get("hp")
		var enemy_max_hp: Variant = enemy.get("max_hp")
		var enemy_block: Variant = enemy.get("block")
		if not enemy_id is String or enemy_id.is_empty() or seen_enemy_ids.has(enemy_id):
			plan["reason"] = "invalid_roster"
			return plan
		if not enemy_position is int or enemy_position != index + 1:
			plan["reason"] = "invalid_roster"
			return plan
		if not enemy_max_hp is int or enemy_max_hp <= 0:
			plan["reason"] = "invalid_roster"
			return plan
		if not enemy_hp is int or enemy_hp < 0 or enemy_hp > enemy_max_hp:
			plan["reason"] = "invalid_roster"
			return plan
		if not enemy_block is int or enemy_block < 0:
			plan["reason"] = "invalid_roster"
			return plan
		seen_enemy_ids.append(enemy_id)
	# The chosen enemy must be a LIVING actor in the printed TO window, addressed by its original
	# roster slot. A slain slot is refused, never replaced by a surviving neighbour.
	if target_position < 1 or target_position > roster.size():
		plan["reason"] = "invalid_target"
		return plan
	if not TO_POSITIONS.has(target_position):
		plan["reason"] = "invalid_target"
		return plan
	var target_record: Dictionary = roster[target_position - 1]
	if int(target_record["position"]) != target_position or int(target_record["hp"]) == 0:
		plan["reason"] = "invalid_target"
		return plan

	# The canonical status schema, over the COMPLETE rosters: an unknown key, a wrong Variant type,
	# a negative counter or a malformed one-shot token refuses before anything is charged. Nothing
	# here adds, ages or removes a status; this card prints none.
	var batch := CombatStatusTurnBatch.new()
	if not batch.tick_side("heroes", heroes).get("ok", false):
		plan["reason"] = "malformed_statuses"
		return plan
	if not batch.tick_side("enemies", roster).get("ok", false):
		plan["reason"] = "malformed_statuses"
		return plan

	# The gauge must belong to THIS battle's exact roster instance (never a detached copy, a
	# different fight or a partially bound service) and must carry a well-formed record for the
	# chosen original slot before any payment.
	var gauge_authority: CombatUnravel = unravel
	if gauge_authority._bound_enemies != enemies:
		plan["reason"] = "wrong_roster_unravel"
		return plan
	var gauge: Dictionary = gauge_authority.get_snapshot(target_position)
	if not CombatUnravel._valid_gauge(gauge):
		plan["reason"] = "invalid_gauge"
		return plan
	# A printed charge that would overflow the counter is refused, not silently made free.
	if int(gauge["gauge"]) > MAX_COUNTER - int(plan["printed_unravel"]):
		plan["reason"] = "unravel_overflow"
		return plan

	# The shared token map may only hold authored pinner IDs on real original slots; a corrupt
	# entry refuses before payment rather than being silently ignored by the pin write.
	var authority_pinned: CombatPinned = pinned
	if not _valid_pin_tokens(authority_pinned, roster.size()):
		plan["reason"] = "malformed_pinned"
		return plan

	# The card must be genuinely held and affordable before any state changes.
	if not deck.hand.has(card_id):
		plan["reason"] = "card_not_held"
		return plan
	if deck.energy < int(plan["cost"]):
		plan["reason"] = "insufficient_energy"
		return plan

	plan["unravel_applied"] = int(plan["printed_unravel"])
	plan["gauge_before"] = gauge
	plan["prior_pinner"] = authority_pinned.pinner_for_enemy(target_position)
	plan["hp_before"] = int(target_record["hp"])
	plan["block_before"] = int(target_record["block"])
	plan["ok"] = true
	plan["reason"] = "ready"
	return plan


## Authenticate one printing through the pool catalog that owns it. Returns the authored pay
## contract or {} when the record no longer prints exactly this card.
func _authenticate(card_id: String) -> Dictionary:
	var card: Dictionary = PRINTINGS.get(card_id, {})
	if card.is_empty():
		return {}
	if not _matches_authored(_catalog.get_definition(card_id), card_id, card):
		return {}
	return {"cost": int(card["cost"]), "unravel": int(card["unravel"])}


## Exact contract for one record: identity, printed name, Seamstress owner, printed one-energy cost,
## the single-enemy target, both position windows, the complete printed effect set with matching
## value types (the boolean Pin included), the common rarity, authored copy/reward eligibility and
## the base/"+" link inside the pool catalog.
func _matches_authored(definition: Dictionary, card_id: String, card: Dictionary) -> bool:
	if definition.is_empty() or definition.get("id") != card_id:
		return false
	if definition.get("owner") != OWNER_ID:
		return false
	if definition.get("display_name") != card["display_name"]:
		return false
	var cost: Variant = definition.get("cost")
	if not cost is int or cost != card["cost"]:
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
	var expected: Dictionary = card["effects"]
	if effects.size() != expected.size():
		return false
	for key: String in expected:
		if not effects.has(key):
			return false
		if not _same_value(effects[key], expected[key]):
			return false
	if definition.get("rarity") != "common":
		return false
	var copies: Variant = definition.get("starting_copies")
	if not copies is int or copies != 0:
		return false
	var upgraded: bool = card.has("upgrade_of")
	var eligible: Variant = definition.get("reward_eligible")
	if not eligible is bool or eligible != (not upgraded):
		return false
	if upgraded:
		return definition.get("upgrade_of") == card["upgrade_of"] \
			and not definition.has("upgrade_id")
	return definition.get("upgrade_id") == card["upgrade_id"] \
		and not definition.has("upgrade_of")


func _exact_positions(value: Variant, expected: Array) -> bool:
	if not value is Array or value.size() != expected.size():
		return false
	for index in range(expected.size()):
		if not value[index] is int or value[index] != expected[index]:
			return false
	return true


## Typed equality rejects coercible metadata (for example a float cost or a string "pinned") as
## well as altered seats, effects or upgrade links.
func _same_value(actual: Variant, expected: Variant) -> bool:
	if typeof(actual) != typeof(expected):
		return false
	if expected is Dictionary:
		if actual.size() != expected.size():
			return false
		for key in expected:
			if not actual.has(key) or not _same_value(actual[key], expected[key]):
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


## The shared token map may only hold authored pinner IDs on real original slots.
func _valid_pin_tokens(pinned: CombatPinned, enemy_count: int) -> bool:
	for position in pinned._pinner_by_position:
		if not position is int or position < 1 or position > enemy_count:
			return false
		var pinner: Variant = pinned._pinner_by_position[position]
		if not pinner is String or not pinned._valid_pinner_id(pinner):
			return false
	return true


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
