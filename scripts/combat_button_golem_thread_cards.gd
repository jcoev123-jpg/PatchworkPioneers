class_name CombatButtonGolemThreadCards
extends RefCounted
## V3-1 scene-free paid resolver for Button Golem's two look-driven thread attacks, base and "+".
##
## Button Knuckle deals its printed damage and then pins that same enemy for the Golem;
## Buttonhole Snag deals its printed damage and then adds its printed Tangled to that same
## enemy. Both printings cost one energy, play from the front or middle seat (FROM 1-2) and
## strike one living enemy: Knuckle reaches enemy slots 1-2, Snag reaches 1-3.
##
## The caller supplies a held card ID, one target slot and the battle's LIVE shared CombatPinned
## authority. This helper never keeps a private token store: when another hero already pinned
## the target, the extant +5 applies before status math through CombatPinned.bonus_for_attack,
## and that token is consumed once through CombatPinned.consume_after_attack after a confirmed
## hit. A same-hero pin neither boosts nor consumes itself. Knuckle's own rider is laid only
## after that hit, so this card can never pay itself the cross-hero bonus.
##
## Damage runs through CombatStatusAttacks against the target's PRE-HIT statuses, so an enemy
## already Tangled confers its flat +2 even when Block absorbs the whole hit, and the Tangled
## this same Snag adds never boosts it. Block-before-HP, the status vocabulary and the Pinned
## rule stay owned by the shared combat models.
##
## Authoritative status maps may legitimately carry the one-shot Dodge token
## (`dodge_next_attack: 0|1`, e.g. a Rag Duelist cape) on the Golem or the one-shot Blind token
## (`blind_next_attack: 0|1`, e.g. a Lantern Monk Moth Cloud) on the chosen enemy. Both maps are
## validated in full here, then ONLY the damage-status subset is handed to CombatStatusAttacks,
## which models neither token. A legal token can therefore never turn a paid Knuckle or Snag into
## a phantom turn: the strike still lands and neither token is mutated, spent or dropped from its
## actor. Neither token is an attack-miss marker for THIS card either: Dodge protects its bearer
## against an incoming attack and Blind makes its bearer's own next attack miss, so the Golem's
## strike still connects and both tokens stay in place for the resolvers that own them.
##
## Fear is the Scarecrow's authored `cannot_buff_next_turn: true`: a one-owner-turn enemy buff
## lock whose only legal value is the literal boolean true (absent when inactive; `false`, `1`,
## `1.0` and `"true"` are malformed). It is a non-damage marker, so it is validated here in the
## same canonical shape as the status owners and deliberately omitted from the damage-status
## subset: it neither raises nor lowers this strike's damage and is never aged, consumed or
## rewritten by it. An enemy already bearing genuine Fear is therefore a perfectly legal target
## for a paid Knuckle or Snag, and keeps its marker afterwards.
##
## Every refusal is a pure no-op: no energy, hand, pile, party record, enemy record, pin token,
## status or seeded RNG change. Live hand, reward and app wiring is a later, separately owned
## task; this is the callable combat rules layer only.

const OWNER_ID := "button_golem"
const TARGET_KIND := "enemy_single"
const FROM_POSITIONS: Array[int] = [1, 2]
## The status keys whose counts modify one attack, exactly as CombatStatusAttacks accepts them.
const ATTACK_STATUS_KEYS: Array[String] = ["bleed", "weak", "exposed", "tangled", "riposte"]
## The authoritative one-shot tokens (integer 0 = inert, 1 = active). Neither modifies this
## attack's damage, so both are validated here and omitted from bridge-bound maps.
const ONE_SHOT_STATUS_KEYS: Array[String] = ["dodge_next_attack", "blind_next_attack"]
## The Scarecrow's one-owner-turn buff lock. Its only canonical value is the literal boolean
## true; it modifies no damage and is omitted from bridge-bound maps.
const FEAR_STATUS_KEY := "cannot_buff_next_turn"

## The four authentic pool printings, each with the exact catalog line it must still carry.
## `effects` is the complete printed descriptor set (no extra keys), `to_positions` the printed
## enemy window and `name` the printed display name. Base IDs are reward eligible; the "+"
## printings are upgrades only.
const PRINTINGS := {
	"button_golem_button_knuckle": {
		"name": "Button Knuckle",
		"cost": 1,
		"damage": 5,
		"effects": {"damage": 5, "pinned": true},
		"to_positions": [1, 2],
		"tangled": 0,
		"upgrade_id": "button_golem_button_knuckle_plus",
	},
	"button_golem_button_knuckle_plus": {
		"name": "Button Knuckle+",
		"cost": 1,
		"damage": 7,
		"effects": {"damage": 7, "pinned": true},
		"to_positions": [1, 2],
		"tangled": 0,
		"upgrade_of": "button_golem_button_knuckle",
	},
	"button_golem_buttonhole_snag": {
		"name": "Buttonhole Snag",
		"cost": 1,
		"damage": 3,
		"effects": {"damage": 3, "tangled": 2},
		"to_positions": [1, 2, 3],
		"tangled": 2,
		"upgrade_id": "button_golem_buttonhole_snag_plus",
	},
	"button_golem_buttonhole_snag_plus": {
		"name": "Buttonhole Snag+",
		"cost": 1,
		"damage": 4,
		"effects": {"damage": 4, "tangled": 3},
		"to_positions": [1, 2, 3],
		"tangled": 3,
		"upgrade_of": "button_golem_buttonhole_snag",
	},
}

const _POOL_CATALOG := preload("res://data/cards/button_golem_pool_cards.gd")

var _attacks := CombatStatusAttacks.new()


## True only for the four authentic catalog IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and PRINTINGS.has(card_id)


## The single paid transaction: authenticate the printing, preflight the whole request, then
## charge once, discard one held copy, resolve printed damage (with the shared cross-hero +5)
## against the target's pre-hit statuses, consume that token once, and lay this card's printed
## rider on the same original enemy slot. A refusal changes no deck, party, enemy, pin or RNG
## state.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int, pinned: Variant = null) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position, pinned)
	if not plan["ok"]:
		return plan
	# Every operation below is guaranteed by the complete preflight above, and nothing here
	# draws a seeded RNG value.
	var authority: CombatPinned = pinned
	var pin_bonus: int = int(plan["pin_bonus"])
	deck.try_spend_energy(plan["cost"])
	plan["energy_spent"] = int(plan["cost"])
	deck.discard_played(plan["card_id"])
	var hit: Dictionary = _attacks.resolve_vs_enemy(enemies, target_position,
		plan["base_damage"], plan["attacker_statuses"], plan["defender_statuses"])
	if not hit.get("ok", false):
		# Preflight proves the bridge accepts these detached maps; if a model change still
		# refuses, never publish an applied receipt for a hit no event backs. Report the truth:
		# the energy and the held copy were already paid above.
		plan["ok"] = false
		plan["reason"] = "bridge_rejected"
		plan["damage"] = 0
		plan["pin_bonus"] = 0
		plan["block_absorbed"] = 0
		plan["hp_loss"] = 0
		plan["pinned"] = false
		plan["tangled_added"] = 0
		plan["applies_pinned"] = false
		return plan
	# Consume the pre-existing shared token exactly once, before this card lays its own rider.
	authority.consume_after_attack(target_position, OWNER_ID, true)
	plan["damage"] = int(hit["damage"])
	plan["block_absorbed"] = int(hit["block_absorbed"])
	plan["hp_loss"] = int(hit["hp_loss"])
	plan["pin_bonus"] = pin_bonus
	# Add the NEW Tangled after the hit; it never boosts this same hit, and the slot is
	# retained on a confirmed lethal hit so the status lands on the nonmoving original slot.
	if plan["tangled_added"] > 0:
		var record: Dictionary = enemies._enemies[target_position - 1]
		if not record.has("statuses"):
			record["statuses"] = {}
		var statuses: Dictionary = record["statuses"]
		statuses["tangled"] = int(statuses.get("tangled", 0)) + int(plan["tangled_added"])
	if plan["applies_pinned"]:
		# Knuckle pins only a living enemy; a confirmed lethal hit leaves no token.
		plan["pinned"] = not enemies.is_slain(target_position) \
			and authority.pin_enemy(enemies, target_position, OWNER_ID)
	plan["ok"] = true
	plan["reason"] = "applied"
	return plan


## Read-only preflight: authenticate the card against its authored catalog, bind the Golem to
## its actual seat, require the caller's live Pinned authority, and prove every downstream
## mutation will succeed before anything is charged. Never consumes the Pinned token itself.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int, pinned: Variant) -> Dictionary:
	var plan := {
		"ok": false, "reason": "unsupported_card",
		"card_id": card_id if typeof(card_id) == TYPE_STRING else "",
		"cost": 0, "owner_position": 0, "target_position": target_position,
		"printed_damage": 0, "base_damage": 0, "pin_bonus": 0, "damage": 0,
		"energy_spent": 0,
		"block_absorbed": 0, "hp_loss": 0, "pinned": false, "tangled_added": 0,
		"applies_pinned": false,
	}
	if not is_supported_card(card_id):
		return plan
	var printed: Dictionary = _authenticate(card_id)
	if printed.is_empty():
		plan["reason"] = "catalog_mismatch"
		return plan
	plan["cost"] = int(printed["cost"])
	if deck == null or party == null or enemies == null:
		plan["reason"] = "invalid_request"
		return plan
	# The shared live authority is mandatory: this resolver never manufactures a private one.
	if not pinned is CombatPinned:
		plan["reason"] = "invalid_pinned_authority"
		return plan
	if deck.combat_state == null:
		plan["reason"] = "invalid_deck"
		return plan
	if not party.is_valid() or not enemies.is_valid():
		plan["reason"] = "invalid_roster"
		return plan
	if not deck.turn_active:
		plan["reason"] = "inactive_turn"
		return plan

	# Bind the Golem to its actual ID/seat; never assume a fixed slot.
	var owner_position := 0
	for hero: Dictionary in party._heroes:
		if hero.get("id") != OWNER_ID:
			continue
		if owner_position != 0:
			plan["reason"] = "duplicate_owner"
			return plan
		owner_position = int(hero["position"])
	if owner_position == 0:
		plan["reason"] = "owner_missing"
		return plan
	plan["owner_position"] = owner_position
	var owner: Dictionary = party._heroes[owner_position - 1]
	if owner["hp"] <= 0:
		plan["reason"] = "owner_torn"
		return plan
	if not FROM_POSITIONS.has(owner_position):
		plan["reason"] = "invalid_owner_position"
		return plan
	if not _distinct_hero_ids(party):
		plan["reason"] = "invalid_roster"
		return plan
	# Both authoritative status rosters must be well formed before any payment.
	if not _valid_status_rosters(party, enemies):
		plan["reason"] = "malformed_statuses"
		return plan
	if not deck.hand.has(card_id):
		plan["reason"] = "card_not_held"
		return plan
	if deck.energy < plan["cost"]:
		plan["reason"] = "insufficient_energy"
		return plan

	# The chosen enemy must be a living actor in this card's printed TO window.
	if target_position < 1 or target_position > enemies._enemies.size():
		plan["reason"] = "invalid_target"
		return plan
	if not printed["to_positions"].has(target_position):
		plan["reason"] = "invalid_target"
		return plan
	var target_record: Dictionary = enemies._enemies[target_position - 1]
	if target_record.get("position") != target_position or target_record.get("hp", 0) <= 0:
		plan["reason"] = "invalid_target"
		return plan

	# Reserve the shared Pinned's possible +5 before any payment, then project the exact
	# bridge-compatible damage-status maps the paid hit will use: the authoritative maps are
	# already validated in full above (including any Dodge/Blind one-shot token and the
	# Scarecrow's boolean Fear lock), while CombatStatusAttacks admits only the damage-status
	# subset.
	var attacker_statuses: Variant = _attack_statuses(owner.get("statuses", {}))
	if attacker_statuses == null:
		plan["reason"] = "malformed_statuses"
		return plan
	var defender: Dictionary = enemies.get_enemy(target_position)
	var defender_statuses: Variant = _attack_statuses(defender.get("statuses", {}))
	if defender_statuses == null:
		plan["reason"] = "malformed_statuses"
		return plan
	var pin_bonus: int = pinned.bonus_for_attack(enemies, target_position, OWNER_ID)
	if int(printed["damage"]) > CombatStatuses.MAX_INT - pin_bonus:
		plan["reason"] = "arithmetic_overflow"
		return plan
	var base_damage: int = int(printed["damage"]) + pin_bonus
	var current_tangled: int = int((defender_statuses as Dictionary).get("tangled", 0))
	if int(printed["tangled"]) > CombatStatuses.MAX_INT - current_tangled:
		plan["reason"] = "status_overflow"
		return plan
	# Size the exact hit before payment: a positive-base attack the shared status rules collapse
	# to zero is an overflow, never a silent free hit, and the bridge cannot refuse later.
	if base_damage > 0 and CombatStatuses.new().adjusted_attack_damage(base_damage,
			attacker_statuses, defender_statuses) <= 0:
		plan["reason"] = "arithmetic_overflow"
		return plan

	plan["printed_damage"] = int(printed["damage"])
	plan["base_damage"] = base_damage
	plan["pin_bonus"] = pin_bonus
	plan["tangled_added"] = int(printed["tangled"])
	plan["applies_pinned"] = bool(printed["pinned"])
	plan["attacker_statuses"] = attacker_statuses
	plan["defender_statuses"] = defender_statuses
	plan["ok"] = true
	plan["reason"] = "ready"
	return plan


## Authenticate one printing through the pool catalog that owns it. Returns
## {"cost": 1, "damage": N, "tangled": M, "pinned": bool, "to_positions": [...]} or {}.
func _authenticate(card_id: String) -> Dictionary:
	var card: Dictionary = PRINTINGS.get(card_id, {})
	if card.is_empty():
		return {}
	if not _matches_authored(_POOL_CATALOG.new().get_definition(card_id), card_id, card):
		return {}
	return {
		"cost": int(card["cost"]),
		"damage": int(card["damage"]),
		"tangled": int(card["tangled"]),
		"pinned": (card["effects"] as Dictionary).has("pinned"),
		"to_positions": (card["to_positions"] as Array).duplicate(),
	}


## Exact contract for one record: identity, printed name, Golem owner, printed one-energy cost,
## the single-enemy target, both position arrays, the complete printed effect set with matching
## value types, authored reward eligibility and the base/"+" link inside the pool catalog.
func _matches_authored(definition: Dictionary, card_id: String, card: Dictionary) -> bool:
	if definition.is_empty() or definition.get("id") != card_id:
		return false
	if definition.get("owner") != OWNER_ID:
		return false
	if definition.get("display_name") != card["name"]:
		return false
	var cost: Variant = definition.get("cost")
	if not cost is int or cost != card["cost"]:
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if not _exact_positions(definition.get("from_positions"), FROM_POSITIONS):
		return false
	if not _exact_positions(definition.get("to_positions"), card["to_positions"]):
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
		var value: Variant = effects[key]
		if typeof(value) != typeof(expected[key]) or value != expected[key]:
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


func _distinct_hero_ids(party: CombatParty) -> bool:
	var seen: Dictionary = {}
	for hero: Dictionary in party._heroes:
		var hero_id: Variant = hero.get("id")
		if not hero_id is String:
			return false
		if seen.has(hero_id):
			return false
		seen[hero_id] = true
	return true


## Fail closed on a malformed authoritative status map on either side, using the shared
## turn-batch validator over the COMPLETE authoritative rosters (unknown keys, wrong Variant
## types, negative counters and a non-0/1 Dodge or Blind token all refuse here), so preflight
## accepts exactly the vocabulary the status owners define.
func _valid_status_rosters(party: CombatParty, enemies: CombatEnemies) -> bool:
	var batch := CombatStatusTurnBatch.new()
	if not batch.tick_side("heroes", party.get_heroes()).get("ok", false):
		return false
	return batch.tick_side("enemies", enemies.get_enemies()).get("ok", false)


## A detached copy of one authoritative status map holding only the counts that modify attack
## damage. Returns null for a non-Dictionary map, a non-String key, a non-int count, an unknown
## key, a negative counter, a one-shot token that is not exactly 0 or 1, or a Fear flag that is
## not exactly the literal boolean true. The one-shot tokens and the Fear flag are non-damage
## markers: they are validated here and left out of the returned map, so the authoritative
## record itself is never modified and every legal marker stays on its actor.
func _attack_statuses(statuses: Variant) -> Variant:
	if not statuses is Dictionary:
		return null
	var authoritative: Dictionary = statuses
	var detached := {}
	for name in authoritative:
		if not name is String:
			return null
		var count: Variant = authoritative[name]
		if name == FEAR_STATUS_KEY:
			# Fear is authored as `cannot_buff_next_turn: true`; any other value is malformed
			# rather than an inactive flag, exactly as the status owners validate it.
			if not count is bool or not bool(count):
				return null
			continue
		if not count is int:
			return null
		if name in ONE_SHOT_STATUS_KEYS:
			if count != 0 and count != 1:
				return null
			continue
		if name not in ATTACK_STATUS_KEYS or count < 0:
			return null
		detached[name] = count
	return detached
