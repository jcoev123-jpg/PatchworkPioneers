class_name CombatRagDuelistNeedlePrickCards
extends RefCounted
## Scene-free paid resolver for the Rag Duelist's Needle Prick and Needle Prick+ (V3-1).
##
## Needle Prick is the rapier-and-tattered-cape skirmisher's short puncture: one energy from hero
## seat 1 or 2, one chosen living enemy in slot 1-2, the printed raw damage (4, or 6 upgraded) and
## the printed Bleed rider (2, or 3). The look is a needle rapier opening a seam that keeps
## bleeding, so the damage and the Bleed are one confirmed strike, never two separate effects.
##
## The shared CombatStatusAttacks bridge owns the hit: the detached damage-status projections of
## the real attacker and defender adjust the printed base (Weak -25%, Exposed +50%, Tangled's flat
## +2 after the single rounding), and the real CombatEnemies roster absorbs Block before HP. The
## bridge call consumes no status and ages nothing. Only after a confirmed hit does the printed
## Bleed go onto that same enemy through CombatEnemies.apply_statuses, so a fully Block-absorbed
## puncture still opens the seam. Bleed then ticks against HP at the affected enemy's owner-turn
## end (bypassing Block) under the existing CombatStatuses/CombatStatusTurnBatch rules; playing
## this card never ticks, spends or ages it, and the Seamstress-only +1 passive never applies.
##
## The catalogs stay authoritative: the caller supplies only a held ID and an enemy slot, never a
## card dictionary, a damage magnitude, an owner or a position. One real CombatDeck payment spends
## exactly one energy and discards exactly one held copy. The Rag Duelist is bound by hero ID to
## his CURRENT actual seat 1-2, so a swapped seat grants no false authority and seat 3 is refused.
##
## Legitimate one-shot Blind/Dodge tokens and the authored Fear flag may already sit on either
## actor. They are validated in their canonical shape, never turned into damage modifiers, never
## consumed, and never handed to the narrower damage bridge. Every refusal is a complete read-only
## preflight before the first mutation: no energy, card, HP, Block, status, RNG draw or partial
## status effect can escape.
##
## Callable rules service only. These two IDs are not yet admitted to a live party deck, the mounted
## hand, the reward pool or any app flow; that wiring is a later task.

const OWNER := "rag_duelist"
const TARGET_KIND := "enemy_single"
const NO_TARGET_SLOT := 0

const FROM_POSITIONS: Array[int] = [1, 2]
const TO_POSITIONS: Array[int] = [1, 2]

## The two authentic printings and the exact catalog line each one must still carry.
const CARDS := {
	"rag_duelist_needle_prick": {
		"cost": 1, "damage": 4, "bleed": 2,
		"upgrade_id": "rag_duelist_needle_prick_plus",
	},
	"rag_duelist_needle_prick_plus": {
		"cost": 1, "damage": 6, "bleed": 3,
		"upgrade_of": "rag_duelist_needle_prick",
	},
}

## The status keys whose counts modify one attack, exactly as CombatStatusAttacks accepts them.
const ATTACK_STATUS_KEYS: Array[String] = ["bleed", "weak", "exposed", "tangled", "riposte"]
## The one-shot defense tokens an authoritative map may legitimately carry: integer 0 is inert and
## integer 1 is armed. Dodge protects an ATTACKER's bearer from incoming attacks and Blind makes a
## DEFENDER's own next attack miss; neither modifies the damage of this outgoing strike.
const DODGE_STATUS_KEY := "dodge_next_attack"
const BLIND_STATUS_KEY := "blind_next_attack"
const ONE_SHOT_STATUS_KEYS: Array[String] = [DODGE_STATUS_KEY, BLIND_STATUS_KEY]
## Fear is the authored `cannot_buff_next_turn: true` buff lock: a non-damage marker with no
## count, accepted only as the literal boolean true and left exactly as it was.
const FEAR_STATUS_KEY := "cannot_buff_next_turn"

var _attacks := CombatStatusAttacks.new()
var _statuses := CombatStatuses.new()


## True only for the two authentic pool printings whose base/'+' pair still carries its authored
## line. Pure lookup: nothing is charged or mutated and no RNG is touched.
func is_supported_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	return _authenticate(card_id)


## The single paid transaction: authenticate, preflight every input, then charge the printed cost,
## discard exactly one held copy, resolve the Block/HP strike and add the printed Bleed.
## `target_position` is an enemy slot from the printed TO line (1 or 2).
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int = NO_TARGET_SLOT) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# exact held ID is affordable, the unique living owner sits in an authored seat, the target is a
	# living enemy in the printed window, the bridge-status projections are well formed and the
	# printed Bleed addition is representable. Keep the defensive checks so an unexpected model
	# change still fails closed instead of inventing a free strike.
	var card_id_value: String = plan["card_id"]
	var target: int = plan["target_position"]
	var base_damage: int = plan["base_damage"]
	if not deck.try_spend_energy(plan["cost"]):
		return _refusal("insufficient_energy")
	if not deck.discard_played(card_id_value):
		return _refusal("card_not_held")
	var event: Dictionary = _attacks.resolve_vs_enemy(enemies, target, base_damage,
		plan["attacker_statuses"], plan["defender_statuses"])
	if not event.get("ok", false):
		return _partial_failure(plan, "bridge_rejected")
	# A confirmed hit opens the seam even when Block soaked the whole puncture, so the printed
	# Bleed always lands on that one enemy. It is not ticked, aged or spent here.
	if not enemies.apply_statuses({target: {"bleed": int(plan["bleed"])}}):
		return _partial_failure(plan, "malformed_statuses")
	var after: Dictionary = enemies.get_enemy(target)
	return {
		"ok": true,
		"reason": "applied",
		"card_id": card_id_value,
		"cost": plan["cost"],
		"owner_position": plan["owner_position"],
		"owner_id": OWNER,
		"target_position": target,
		"base_damage": base_damage,
		"damage": int(event["damage"]),
		"hp_before": plan["hp_before"],
		"hp_after": int(after["hp"]),
		"hp_loss": plan["hp_before"] - int(after["hp"]),
		"block_before": plan["block_before"],
		"block_after": int(after["block"]),
		"block_absorbed": plan["block_before"] - int(after["block"]),
		"bleed_applied": plan["bleed"],
		"bleed_before": plan["bleed_before"],
		"bleed_after": int(after.get("statuses", {}).get("bleed", 0)),
		"energy_before": plan["energy_before"],
		"energy_after": deck.energy,
		"energy_spent": plan["cost"],
	}


## Read-only preflight of the whole transaction. Returns a detached plan on success or the same
## receipt shape with `ok: false`, a reason and no mutation of any input.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int) -> Dictionary:
	if typeof(card_id) != TYPE_STRING or not CARDS.has(card_id):
		return _refusal("unsupported_card")
	var id: String = card_id
	# Fetch the authored records from the one pool catalog that owns them; a rewritten, relinked or
	# copied record can never be paid for as this effect.
	if not _authenticate(id):
		return _refusal("catalog_mismatch")
	if deck == null or party == null or enemies == null:
		return _refusal("invalid_request")
	if deck.combat_state == null or deck._rng == null:
		return _refusal("invalid_deck")
	if not _valid_heroes(party) or not _valid_enemies(enemies):
		return _refusal("invalid_roster")
	if not deck.turn_active:
		return _refusal("inactive_turn")

	# Bind the Rag Duelist to its actual current seat; a swapped seat grants no false authority.
	var owner_position := 0
	for hero: Dictionary in party._heroes:
		if hero.get("id") != OWNER:
			continue
		if owner_position != 0:
			return _refusal("duplicate_owner")
		owner_position = int(hero["position"])
	if owner_position == 0:
		return _refusal("owner_missing")
	if not FROM_POSITIONS.has(owner_position):
		return _refusal("owner_illegal_position")
	var owner: Dictionary = party._heroes[owner_position - 1]
	if int(owner["hp"]) <= 0:
		return _refusal("owner_downed")
	if not _distinct_hero_ids(party):
		return _refusal("invalid_roster")

	# Every authoritative status map is validated in full, including the one-shot defense tokens
	# and the Fear flag, so a malformed map can never reach the narrower bridge after payment.
	if not _valid_authoritative_statuses_roster(party, enemies):
		return _refusal("malformed_statuses")

	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = CARDS[id]["cost"]
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	# The printed TO line is 1-2 and the chosen slot must still hold a living enemy; original
	# slots never compact after deaths, so a slain slot is refused without retargeting.
	if not TO_POSITIONS.has(target_position):
		return _refusal("invalid_target")
	var roster: Array[Dictionary] = enemies.get_enemies()
	if target_position > roster.size():
		return _refusal("invalid_target")
	if int(roster[target_position - 1]["hp"]) <= 0:
		return _refusal("target_slain")

	# CombatStatuses owns the Weak/Exposed/Tangled rounding: integer floor once, then a positive-
	# base Tangled defender adds its flat +2. Only the damage counters reach the bridge; one-shot
	# tokens and Fear stay on the authoritative maps untouched.
	var attacker_statuses: Dictionary = _damage_statuses(owner.get("statuses", {}))
	var defender_statuses: Dictionary = _damage_statuses(
		roster[target_position - 1].get("statuses", {}))
	var base_damage: int = CARDS[id]["damage"]
	if base_damage > 0 and _statuses.adjusted_attack_damage(base_damage, attacker_statuses,
			defender_statuses) <= 0:
		return _refusal("arithmetic_overflow")

	# The printed Bleed is an enemy-side stack; preflight the exact addition so a malformed or
	# overflowing counter refuses BEFORE anything is charged.
	var bleed: int = CARDS[id]["bleed"]
	if not enemies.can_apply_statuses({target_position: {"bleed": bleed}}):
		return _refusal("malformed_statuses")

	var target: Dictionary = roster[target_position - 1]
	return {
		"ok": true,
		"reason": "ready",
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": target_position,
		"base_damage": base_damage,
		"bleed": bleed,
		"hp_before": int(target["hp"]),
		"block_before": int(target["block"]),
		"bleed_before": int(_statuses_of(target).get("bleed", 0)),
		"energy_before": deck.energy,
		"attacker_statuses": attacker_statuses,
		"defender_statuses": defender_statuses,
	}


## True only when both records of the pair still carry their authored line and still point at each
## other. A copied, relinked, rewritten or mistyped record is never authenticated, whichever
## printing the caller names.
func _authenticate(card_id: String) -> bool:
	if not CARDS.has(card_id):
		return false
	var base_id: String = card_id.trim_suffix("_plus")
	var plus_id: String = base_id + "_plus"
	if not CARDS.has(base_id) or not CARDS.has(plus_id):
		return false
	var base_record: Dictionary = _catalog_definition(base_id)
	var plus_record: Dictionary = _catalog_definition(plus_id)
	if not _matches_authored(base_record, base_id, false):
		return false
	if not _matches_authored(plus_record, plus_id, true):
		return false
	return base_record.get("upgrade_id") == plus_id and not base_record.has("upgrade_of") \
		and plus_record.get("upgrade_of") == base_id and not plus_record.has("upgrade_id")


## The one authored record for an ID, detached. A subclass may serve a forged record so a rewritten
## catalog can be proven inert before any energy, hand, HP, Block or RNG state moves.
func _catalog_definition(card_id: String) -> Dictionary:
	return RagDuelistPoolCards.new().get_definition(card_id)


## Exact contract for one record: identity, owner, energy cost, FROM seat, `enemy_single`
## targeting, TO slots, the complete printed effect set with exact Variant types and magnitudes,
## no starter copies, the common rarity and the base-only reward eligibility the pool authors.
func _matches_authored(definition: Dictionary, card_id: String, upgraded: bool) -> bool:
	if definition.is_empty() or definition.get("id") != card_id:
		return false
	if definition.get("owner") != OWNER:
		return false
	if not _exact_int(definition.get("cost"), int(CARDS[card_id]["cost"])):
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if not _exact_positions(definition.get("from_positions"), FROM_POSITIONS):
		return false
	if not _exact_positions(definition.get("to_positions"), TO_POSITIONS):
		return false
	if not _exact_effects(definition.get("effects"), card_id):
		return false
	if not _exact_int(definition.get("starting_copies"), 0):
		return false
	if definition.get("rarity") != "common":
		return false
	var reward_eligible: Variant = definition.get("reward_eligible")
	if not reward_eligible is bool or reward_eligible != (not upgraded):
		return false
	return true


func _exact_int(value: Variant, expected: int) -> bool:
	return value is int and int(value) == expected


## The two printed effects and nothing else, with integer values (never floats or strings).
func _exact_effects(value: Variant, card_id: String) -> bool:
	if not value is Dictionary:
		return false
	var effects: Dictionary = value
	if effects.size() != 2:
		return false
	if not _exact_int(effects.get("damage"), int(CARDS[card_id]["damage"])):
		return false
	return _exact_int(effects.get("bleed"), int(CARDS[card_id]["bleed"]))


func _exact_positions(value: Variant, expected: Array[int]) -> bool:
	if not value is Array or value.size() != expected.size():
		return false
	var positions: Array = value
	for index in range(expected.size()):
		if not positions[index] is int or positions[index] != expected[index]:
			return false
	return true


## Three genuine seats in order with nonempty string IDs and sane per-combat records. ID
## uniqueness is checked separately so a second Rag Duelist reports duplicate_owner first.
func _valid_heroes(party: CombatParty) -> bool:
	if not party.is_valid() or party._heroes.size() != CombatParty.PARTY_SIZE:
		return false
	for index in range(CombatParty.PARTY_SIZE):
		var record: Variant = party._heroes[index]
		if not record is Dictionary:
			return false
		var hero: Dictionary = record
		var hero_id: Variant = hero.get("id")
		if not hero_id is String or hero_id.is_empty():
			return false
		var position: Variant = hero.get("position")
		if not position is int or position != index + 1:
			return false
		var max_hp: Variant = hero.get("max_hp")
		if not max_hp is int or max_hp <= 0:
			return false
		var hp: Variant = hero.get("hp")
		if not hp is int or hp < 0 or hp > max_hp:
			return false
		var block: Variant = hero.get("block")
		if not block is int or block < 0:
			return false
	return true


func _distinct_hero_ids(party: CombatParty) -> bool:
	var seen: Dictionary = {}
	for hero: Dictionary in party._heroes:
		var hero_id: String = hero["id"]
		if seen.has(hero_id):
			return false
		seen[hero_id] = true
	return true


## One to three genuine enemy slots in order with nonempty distinct string IDs and sane records.
## Slain slots remain valid; target eligibility is checked separately.
func _valid_enemies(enemies: CombatEnemies) -> bool:
	if not enemies.is_valid():
		return false
	var roster: Array[Dictionary] = enemies.get_enemies()
	if roster.is_empty() or roster.size() > CombatEnemies.MAX_ENEMIES:
		return false
	var seen: Dictionary = {}
	for index in range(roster.size()):
		var enemy: Dictionary = roster[index]
		var enemy_id: Variant = enemy.get("id")
		if not enemy_id is String or enemy_id.is_empty() or seen.has(enemy_id):
			return false
		seen[enemy_id] = true
		var position: Variant = enemy.get("position")
		if not position is int or position != index + 1:
			return false
		var max_hp: Variant = enemy.get("max_hp")
		if not max_hp is int or max_hp <= 0:
			return false
		var hp: Variant = enemy.get("hp")
		if not hp is int or hp < 0 or hp > max_hp:
			return false
		var block: Variant = enemy.get("block")
		if not block is int or block < 0:
			return false
	return true


## Every authoritative status map on both sides must be well formed before any hit is sized: named
## N-turn counters with non-negative int counts, the two one-shot tokens as integer 0 or 1, and the
## authored Fear flag as exactly the literal boolean true.
func _valid_authoritative_statuses_roster(party: CombatParty, enemies: CombatEnemies) -> bool:
	for hero: Dictionary in party._heroes:
		if not _valid_authoritative_statuses(hero.get("statuses", {})):
			return false
	for enemy: Dictionary in enemies.get_enemies():
		if not _valid_authoritative_statuses(enemy.get("statuses", {})):
			return false
	return true


func _valid_authoritative_statuses(statuses: Variant) -> bool:
	if not statuses is Dictionary:
		return false
	var values: Dictionary = statuses
	for name in values:
		if not name is String or (name as String).is_empty():
			return false
		var count: Variant = values[name]
		if name == FEAR_STATUS_KEY:
			# Fear is authored as `cannot_buff_next_turn: true`; any other value is malformed
			# rather than an inactive flag.
			if not count is bool or not bool(count):
				return false
			continue
		if not count is int:
			return false
		if name in ONE_SHOT_STATUS_KEYS:
			if count != 0 and count != 1:
				return false
			continue
		if not ATTACK_STATUS_KEYS.has(name) or count < 0:
			return false
	return true


## A detached copy of one authoritative status map holding only the five damage counters the
## shared bridge understands. The one-shot Blind/Dodge tokens and the Fear flag stay on the
## authoritative map untouched; they never become damage modifiers and are never consumed.
func _damage_statuses(statuses: Variant) -> Dictionary:
	var detached := {}
	if not statuses is Dictionary:
		return detached
	var values: Dictionary = statuses
	for name: String in ATTACK_STATUS_KEYS:
		if values.has(name):
			detached[name] = int(values[name])
	return detached


func _statuses_of(record: Dictionary) -> Dictionary:
	var value: Variant = record.get("statuses", {})
	return value if value is Dictionary else {}


## The truth after a bridge call refused something the preflight had proved: the energy and the
## card are already spent, so report the charge instead of claiming a resolved card.
func _partial_failure(plan: Dictionary, reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "card_id": plan.get("card_id", ""),
		"cost": plan.get("cost", 0), "owner_position": plan.get("owner_position", 0),
		"owner_id": OWNER, "target_position": plan.get("target_position", 0),
		"base_damage": plan.get("base_damage", 0), "energy_spent": plan.get("cost", 0)}


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
