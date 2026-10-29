class_name CombatWardenV3GuardCards
extends RefCounted
## Scene-free paid resolver for the Warden's one-use ally Guard (V3-1).
##
## Shield Catch is a v3 starter card and Guard Stitch a v3 reward-pool card; both print a flat Block
## for one chosen living ally plus `guard_next_hit: true`. The squat shield-bearer raises his huge
## round patchwork shield over that ally, and the NEXT enemy attack aimed at that ally is redirected
## to the Warden's CURRENT seat exactly once. Block is absorbed before HP by the existing attack
## executor; this helper never applies speculative damage.
##
## The two catalogs stay authoritative: each printing is authenticated against the catalog that
## owns it (starter or pool) and must still carry its exact authored line. The service then resolves
## against the real CombatDeck and CombatParty: one shared energy, exactly one genuinely held copy,
## the printed Block on the selected living ally, and one battle-scoped pending interception.
##
## The protected actor is keyed by hero IDENTITY, never by the seat it occupied when the card was
## played. `project_interception` re-reads both the protected hero's and the Warden's current seats
## on every call, is completely read-only, and never consumes the pending guard. After the caller's
## own attack path confirms that a hit really landed (Block-absorbed still counts; a miss or a
## non-attack does not), the caller invokes `consume_confirmed_hit` exactly once. A second hit after
## that consumption is ordinary. No new expiry, stacking, damage or Block rule is introduced here.
##
## Selecting the Warden himself is legal under the catalog's `ally_single` semantics: he receives
## the printed Block, and the pending one-shot can only ever apply to a hit aimed at him, so it
## never redirects a hit away from another hero.
##
## This is the callable combat rules slice only. It does not admit these IDs into a live party
## deck, the reward pool, the mounted hand, the enemy phase or any app flow; that wiring is a later
## task. Nothing here draws from the seeded run RNG.

const OWNER_ID := "warden"
const TARGET_KIND := "ally_single"
const GUARD_EFFECT_KEY := "guard_next_hit"
## Both printings play from the Warden's two legal front seats and print no enemy TO target.
const FROM_POSITIONS: Array[int] = [1, 2]
const TO_POSITIONS: Array[int] = []

## The four authentic IDs, the catalog that owns each one, and the exact printed line it must still
## carry. A base printing and its "+" share owner, cost, legal seats and target; only Block differs.
const CARDS := {
	"warden_v3_shield_catch": {
		"catalog": "starter",
		"display_name": "Shield Catch",
		"cost": 1,
		"block": 4,
		"has_rarity": false,
		"starting_copies": 1,
		"reward_eligible": false,
		"upgrade_id": "warden_v3_shield_catch_plus",
		"upgrade_of": "",
	},
	"warden_v3_shield_catch_plus": {
		"catalog": "starter",
		"display_name": "Shield Catch+",
		"cost": 1,
		"block": 6,
		"has_rarity": false,
		"starting_copies": 0,
		"reward_eligible": false,
		"upgrade_id": "",
		"upgrade_of": "warden_v3_shield_catch",
	},
	"warden_v3_guard_stitch": {
		"catalog": "pool",
		"display_name": "Guard Stitch",
		"cost": 1,
		"block": 5,
		"has_rarity": true,
		"starting_copies": 0,
		"reward_eligible": true,
		"upgrade_id": "warden_v3_guard_stitch_plus",
		"upgrade_of": "",
	},
	"warden_v3_guard_stitch_plus": {
		"catalog": "pool",
		"display_name": "Guard Stitch+",
		"cost": 1,
		"block": 7,
		"has_rarity": true,
		"starting_copies": 0,
		"reward_eligible": false,
		"upgrade_id": "",
		"upgrade_of": "warden_v3_guard_stitch",
	},
}

## One battle owns one resolver instance. The pending guard is one-shot: a successful play arms
## the printed interception and a confirmed hit on the protected ally consumes it. A second legal
## play refreshes that same single pending guard to its own ally instead of stacking two.
var _guard_armed := false
var _guarded_hero_id := ""
var _guard_card_id := ""

var _starter_catalog: RefCounted
var _pool_catalog: RefCounted


## The default catalogs are the shipped authored ones. An explicit instance lets a test prove that
## a rewritten record for an otherwise valid, held ID is refused instead of paid for.
func _init(starter_catalog: Variant = null, pool_catalog: Variant = null) -> void:
	_starter_catalog = starter_catalog if starter_catalog is V3WardenStarterCards \
		else V3WardenStarterCards.new()
	_pool_catalog = pool_catalog if pool_catalog is V3WardenPoolCards else V3WardenPoolCards.new()


## True only for the four authentic catalog IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


## True only when the live catalog that owns this ID still carries the exact authored record.
func is_authentic_card(card_id: Variant) -> bool:
	if not is_supported_card(card_id):
		return false
	var id: String = card_id
	return _authentic(_catalog_definition(id), id, CARDS[id])


## The single paid transaction: authenticate the printing, preflight the whole request, then charge
## one shared energy, discard exactly one genuinely held copy, add the printed Block to the chosen
## living ally and arm that ally's one-use interception.
## `target_position` is the chosen living ally's current seat (the Warden's own seat is legal).
## A rejection changes no deck, party, pending guard or RNG state.
func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, card_id, target_position)
	if not plan.get("ok", false):
		return plan
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# held ID is authentic and affordable, the Warden is living in a printed FROM seat, the chosen
	# ally is living and the Block addition fits. Keep the defensive returns so an unexpected model
	# change still fails closed.
	if not deck.try_spend_energy(int(plan["cost"])):
		plan["ok"] = false
		plan["reason"] = "energy_rejected"
		return plan
	if not deck.discard_played(plan["card_id"]):
		deck.combat_state.energy += int(plan["cost"])
		plan["ok"] = false
		plan["reason"] = "discard_rejected"
		return plan
	if not party.gain_block(int(plan["target_position"]), int(plan["block_gained"])):
		deck.combat_state.energy += int(plan["cost"])
		plan["ok"] = false
		plan["reason"] = "block_rejected"
		return plan

	# One pending one-shot per battle: a second legal play refreshes it to its own ally.
	_guard_armed = true
	_guarded_hero_id = str(plan["target_hero_id"])
	_guard_card_id = str(plan["card_id"])

	plan["energy_spent"] = int(plan["cost"])
	plan["energy_after"] = deck.energy
	plan["block_after"] = int(party.get_hero(int(plan["target_position"])).get("block", 0))
	plan["guard_armed"] = true
	plan["guarded_hero_id"] = _guarded_hero_id
	plan["ok"] = true
	plan["reason"] = "applied"
	return plan


## True while one one-use ally interception waits for a confirmed enemy hit.
func has_pending_guard() -> bool:
	return _guard_armed


## The hero identity currently protected by the pending one-shot, or "" when nothing is armed.
func get_guarded_hero_id() -> String:
	return _guarded_hero_id


## The most recent legal Guard card that armed the pending interception, or "" when none is armed.
func get_pending_guard_card_id() -> String:
	return _guard_card_id


## Read-only projection of one announced enemy attack. `announced_target_position` is the seat the
## enemy phase chose; `actual_target_position` is the seat that really takes the hit. A hit aimed at
## the living protected ally is redirected to the living Warden's CURRENT seat once, unless the
## protected ally already is the Warden. An absent, torn or otherwise unavailable Warden preserves
## the announced target. Nothing is consumed and no party, deck or RNG state is touched.
func project_interception(party: CombatParty, announced_target_position: int) -> Dictionary:
	var receipt := _projection()
	receipt["announced_target_position"] = announced_target_position
	receipt["actual_target_position"] = announced_target_position
	if party == null or not party.is_valid():
		receipt["reason"] = "invalid_roster"
		return receipt
	if announced_target_position < 1 or announced_target_position > CombatParty.PARTY_SIZE:
		receipt["reason"] = "invalid_target"
		return receipt
	receipt["ok"] = true
	if not _guard_armed:
		receipt["reason"] = "not_armed"
		return receipt
	receipt["guarded_hero_id"] = _guarded_hero_id
	var guarded_position: int = _hero_position(party, _guarded_hero_id)
	receipt["guarded_position"] = guarded_position
	if guarded_position == 0:
		receipt["reason"] = "guarded_missing"
		return receipt
	if announced_target_position != guarded_position:
		receipt["reason"] = "not_guarded_target"
		return receipt
	if party.is_downed(guarded_position):
		receipt["reason"] = "guarded_torn"
		return receipt
	var warden_position: int = _hero_position(party, OWNER_ID)
	receipt["warden_position"] = warden_position
	if warden_position == 0:
		receipt["reason"] = "warden_unavailable"
		return receipt
	if party.is_downed(warden_position):
		receipt["reason"] = "warden_torn"
		return receipt
	# Self-selected Warden: he already is the announced recipient, so the hit stays where it is.
	var redirect: bool = warden_position != guarded_position
	receipt["eligible"] = true
	receipt["redirected"] = redirect
	receipt["actual_target_position"] = warden_position if redirect else announced_target_position
	receipt["reason"] = "redirected" if redirect else "self_guard"
	return receipt


## The caller's explicit one-use consumption, invoked only after its own attack path has confirmed
## that an attack really hit. `confirmed_attack_hit` is true for a landed attack even when Block
## absorbed the whole damage, and false for a miss or a non-attack; a false value consumes nothing
## and leaves the pending guard armed. Only a confirmed hit aimed at the living protected ally
## consumes the interception. The receipt reports the announced seat and the actual recipient the
## caller should have used; the caller owns the damage and the ordinary Block-before-HP maths.
func consume_confirmed_hit(party: CombatParty, announced_target_position: int,
		confirmed_attack_hit: bool) -> Dictionary:
	var receipt := _consumption()
	receipt["announced_target_position"] = announced_target_position
	receipt["actual_target_position"] = announced_target_position
	var projection: Dictionary = project_interception(party, announced_target_position)
	if not projection.get("ok", false):
		receipt["reason"] = str(projection.get("reason", "invalid_roster"))
		return receipt
	receipt["ok"] = true
	receipt["guarded_hero_id"] = str(projection.get("guarded_hero_id", ""))
	receipt["warden_position"] = int(projection.get("warden_position", 0))
	receipt["actual_target_position"] = int(projection.get("actual_target_position", 0))
	if not confirmed_attack_hit:
		receipt["reason"] = "no_confirmed_hit"
		return receipt
	if not projection.get("eligible", false):
		receipt["reason"] = str(projection.get("reason", "not_eligible"))
		return receipt
	# Only now does the pending one-shot leave the battle.
	_guard_armed = false
	_guarded_hero_id = ""
	_guard_card_id = ""
	receipt["consumed"] = true
	receipt["reason"] = "consumed"
	return receipt


## Read-only preflight of the whole transaction. Returns a detached plan or a failure record.
func _prepare(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int) -> Dictionary:
	var plan: Dictionary = _failure()
	if not is_supported_card(card_id):
		return plan
	var id: String = card_id
	plan["card_id"] = id
	var printed: Dictionary = CARDS[id]
	plan["cost"] = int(printed["cost"])
	if not _authentic(_catalog_definition(id), id, printed):
		plan["reason"] = "catalog_mismatch"
		return plan
	if deck == null or party == null:
		plan["reason"] = "invalid_request"
		return plan
	if deck.combat_state == null or deck._rng == null:
		plan["reason"] = "invalid_deck"
		return plan
	if not _valid_roster(party):
		plan["reason"] = "invalid_roster"
		return plan
	if not deck.turn_active:
		plan["reason"] = "inactive_turn"
		return plan

	# Bind the unique living Warden to its actual current seat; the printed FROM line is 1-2.
	var heroes: Array[Dictionary] = party.get_heroes()
	var warden_count := 0
	var warden_position := 0
	for index in range(CombatParty.PARTY_SIZE):
		if heroes[index]["id"] != OWNER_ID:
			continue
		warden_count += 1
		warden_position = index + 1
	if warden_count == 0:
		plan["reason"] = "owner_missing"
		return plan
	if warden_count > 1:
		plan["reason"] = "duplicate_owner"
		return plan
	plan["owner_position"] = warden_position
	if not FROM_POSITIONS.has(warden_position):
		plan["reason"] = "invalid_owner_position"
		return plan
	if party.is_downed(warden_position):
		plan["reason"] = "owner_torn"
		return plan

	# The chosen ally is a current seat, not a remembered one.
	if target_position < 1 or target_position > CombatParty.PARTY_SIZE:
		plan["reason"] = "invalid_target"
		return plan
	if party.is_downed(target_position):
		plan["reason"] = "target_torn"
		return plan
	var target: Dictionary = heroes[target_position - 1]
	plan["target_position"] = target_position
	plan["target_hero_id"] = str(target["id"])

	# The card must be genuinely held and affordable before any state changes.
	if not deck.hand.has(id):
		plan["reason"] = "card_not_held"
		return plan
	if deck.energy < int(plan["cost"]):
		plan["reason"] = "insufficient_energy"
		return plan

	# The printed Block must fit the chosen ally's current Block before the charge.
	var block_gain: int = int(printed["block"])
	var current_block: int = int(target["block"])
	if block_gain > CombatParty.MAX_INT - current_block:
		plan["reason"] = "block_overflow"
		return plan
	plan["block_gained"] = block_gain
	plan["block_after"] = current_block + block_gain
	plan["ok"] = true
	plan["reason"] = "ready"
	return plan


## Reads the exact authored record from the catalog that owns this ID (never the other hero's
## catalog) and returns a detached copy, or {} when the ID is not in that catalog.
func _catalog_definition(card_id: String) -> Dictionary:
	var card: Dictionary = CARDS.get(card_id, {})
	var source: String = str(card.get("catalog", ""))
	if source == "starter":
		return _starter_catalog.get_definition(card_id)
	if source == "pool":
		return _pool_catalog.get_definition(card_id)
	return {}


## Exact contract for one record: identity, printed name, Warden owner, printed one-energy cost, the
## single-ally target with FROM 1-2 and empty TO, the complete printed effect set with exact types
## and magnitudes, authored starter/reward identity and the base/"+" link inside its own catalog.
## Rarity is checked only where the owning catalog authors it.
func _authentic(definition: Dictionary, card_id: String, printed: Dictionary) -> bool:
	if definition.is_empty() or definition.get("id") != card_id:
		return false
	if definition.get("owner") != OWNER_ID:
		return false
	if definition.get("display_name") != printed["display_name"]:
		return false
	var cost: Variant = definition.get("cost")
	if not cost is int or cost != int(printed["cost"]):
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
	var expected_effects: Dictionary = {"block": int(printed["block"])}
	expected_effects[GUARD_EFFECT_KEY] = true
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
	if not starting_copies is int or starting_copies != int(printed["starting_copies"]):
		return false
	var reward_eligible: Variant = definition.get("reward_eligible")
	if not reward_eligible is bool or reward_eligible != bool(printed["reward_eligible"]):
		return false
	if bool(printed["has_rarity"]):
		if definition.get("rarity") != "common":
			return false
	elif definition.has("rarity"):
		return false
	var base_id: String = str(printed["upgrade_of"])
	if base_id.is_empty():
		return definition.get("upgrade_id") == printed["upgrade_id"] \
			and not definition.has("upgrade_of")
	return definition.get("upgrade_of") == base_id and not definition.has("upgrade_id")


func _exact_positions(value: Variant, expected: Array[int]) -> bool:
	if not value is Array or value.size() != expected.size():
		return false
	for index in range(expected.size()):
		if not value[index] is int or value[index] != expected[index]:
			return false
	return true


## Three genuine seats in order with unique nonempty IDs and sane per-combat records, read through
## the public snapshot so a corrupted roster fails closed before any charge.
func _valid_roster(party: CombatParty) -> bool:
	if not party.is_valid() or party.get_heroes().size() != CombatParty.PARTY_SIZE:
		return false
	var heroes: Array[Dictionary] = party.get_heroes()
	var seen_ids: Array[String] = []
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = heroes[index]
		var hero_id: Variant = hero.get("id")
		var position: Variant = hero.get("position")
		var hp: Variant = hero.get("hp")
		var max_hp: Variant = hero.get("max_hp")
		var block: Variant = hero.get("block")
		if not hero_id is String or (hero_id as String).is_empty() \
				or seen_ids.has(hero_id as String):
			return false
		if not position is int or (position as int) != index + 1:
			return false
		if not max_hp is int or (max_hp as int) <= 0:
			return false
		if not hp is int or (hp as int) < 0 or (hp as int) > (max_hp as int):
			return false
		if not block is int or (block as int) < 0:
			return false
		seen_ids.append(hero_id as String)
	return true


## The current seat of one hero identity, or 0 when that identity is absent. Never trusts a
## remembered position, so a legal seat change is followed automatically.
static func _hero_position(party: CombatParty, hero_id: String) -> int:
	if party == null or not party.is_valid() or hero_id.is_empty():
		return 0
	for hero: Dictionary in party.get_heroes():
		if hero.get("id") != hero_id:
			continue
		var position: Variant = hero.get("position")
		return position if position is int and position >= 1 \
			and position <= CombatParty.PARTY_SIZE else 0
	return 0


func _projection() -> Dictionary:
	return {
		"ok": false,
		"eligible": false,
		"redirected": false,
		"reason": "invalid_roster",
		"announced_target_position": 0,
		"actual_target_position": 0,
		"guarded_hero_id": "",
		"warden_position": 0,
		"guarded_position": 0,
	}


func _consumption() -> Dictionary:
	return {
		"ok": false,
		"consumed": false,
		"reason": "invalid_roster",
		"announced_target_position": 0,
		"actual_target_position": 0,
		"guarded_hero_id": "",
		"warden_position": 0,
	}


func _failure() -> Dictionary:
	return {
		"ok": false,
		"reason": "unsupported_card",
		"card_id": "",
		"cost": 0,
		"energy_spent": 0,
		"owner_position": 0,
		"target_position": 0,
		"target_hero_id": "",
		"block_gained": 0,
		"block_after": 0,
		"guard_armed": false,
		"guarded_hero_id": "",
		"energy_after": 0,
	}
