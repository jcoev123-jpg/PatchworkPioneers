class_name CombatScarecrowFearCards
extends RefCounted
## V3-1 scene-free paid resolver for the Scarecrow's single-target sack-face Fear printings.
##
## Sack Glare (a dedicated v3 starter) and Sack Grin (a v3 reward-pool card), each with its "+"
## upgrade, print one energy, an enemy slot 1-3 reachable from hero seat 1-3, and Weak plus Fear.
## The look is the stitched burlap sack head with its unnerving grin, so the face itself does the
## work: the target is Weakened and, for its next enemy turn only, cannot buff. There is no damage
## and no Block here.
##
## The catalogs stay authoritative: the caller supplies only a held card ID and a target slot,
## never a card dictionary, a Weak magnitude, an owner or a license to change the shared status
## model. This service authenticates the exact held catalog record (owner, cost, seating, single
## enemy targeting, the exact effect dictionary with Variant types, and the base/"+" link in both
## directions), then, after a complete read-only preflight, charges exactly one shared energy,
## discards exactly that held copy, adds the printed Weak stack to the selected enemy's existing
## Weak through CombatEnemies' own status path and finally writes the canonical Fear flag
## `cannot_buff_next_turn: true` onto that same authoritative status record.
##
## Fear is a literal boolean, not a count: CombatStatuses.can_apply_buff reads it on the enemy's
## next owner turn and CombatStatusTurnBatch.tick_side('enemies', ...) expires it at that owner
## turn's end, while Weak is authored and aged separately. This resolver never ticks, ages or
## shortens anything: no owner-turn boundary is applied at card-play time, and the flag carries no
## turn count to lengthen.
##
## Every rejection is a strict no-op: the rosters, every authoritative status map (including the
## projected post-play map), the target slot, the affordability and the Weak addition are
## preflighted before the first mutation, and no shuffle, draw or random target can advance the
## run RNG.
##
## This is callable rules-layer behaviour only. It does not register these IDs in the live hand,
## rewards, run deck or the app flow, and the enemy phase does not yet consult can_apply_buff; a
## later task owns hand/attack dispatch and enemy buff-action wiring.

const OWNER := "scarecrow"
const COST := 1
const TARGET_KIND := "enemy_single"
const FROM_POSITIONS: Array[int] = [1, 2, 3]
const TO_POSITIONS: Array[int] = [1, 2, 3]
const NO_TARGET_SLOT := 0

## Fear's canonical status key and value: the authored `cannot_buff_next_turn` flag, stored as the
## literal boolean true. `false`, 1, 1.0 and "true" are malformed, never inactive.
const FEAR_STATUS_KEY := "cannot_buff_next_turn"
const WEAK_STATUS_KEY := "weak"

## The four authentic printings, each bound to the one catalog allowed to own it, the printed Weak
## count and the authored catalog facts this service must still find before paying.
const CARDS := {
	"scarecrow_sack_glare": {
		"catalog": "starter", "weak": 1, "starting_copies": 1, "reward_eligible": false,
		"upgrade_id": "scarecrow_sack_glare_plus",
	},
	"scarecrow_sack_glare_plus": {
		"catalog": "starter", "weak": 2, "starting_copies": 0, "reward_eligible": false,
		"upgrade_of": "scarecrow_sack_glare",
	},
	"scarecrow_sack_grin": {
		"catalog": "pool", "weak": 1, "starting_copies": 0, "reward_eligible": true,
		"upgrade_id": "scarecrow_sack_grin_plus",
	},
	"scarecrow_sack_grin_plus": {
		"catalog": "pool", "weak": 2, "starting_copies": 0, "reward_eligible": false,
		"upgrade_of": "scarecrow_sack_grin",
	},
}

## CombatStatuses owns this vocabulary: the five N-turn counters with non-negative integer counts
## and the two one-shot tokens as integer 0 (inert) or 1 (armed). Any other key or shape is a
## malformed authoritative map and refuses the play instead of being coerced into a legal stack.
const ATTACK_STATUS_KEYS: Array[String] = ["bleed", "weak", "exposed", "tangled", "riposte"]
const ONE_SHOT_STATUS_KEYS: Array[String] = ["dodge_next_attack", "blind_next_attack"]


## True only for the four authentic catalog IDs whose authored line is still intact. Pure lookup:
## nothing is charged, discarded or mutated and no RNG is touched.
func is_supported_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	return _authenticate(card_id)


## The single paid transaction: authenticate, preflight every input, then charge the printed cost,
## discard exactly the held copy, add the printed Weak and write canonical Fear on that enemy.
##
## `target_position` must name a living enemy in the authored 1-3 window; slots outside it fail
## closed even when the roster has room.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int = NO_TARGET_SLOT) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# exact held ID is affordable, the unique living owner sits in an authored seat, the target is a
	# living enemy in the printed window, every status map is canonical and the projected map (Weak
	# stack plus canonical Fear) is admissible and still tickable. Keep the defensive returns so an
	# unexpected model change still fails closed.
	var card_id_value: String = plan["card_id"]
	var target_position_value: int = plan["target_position"]
	if not deck.try_spend_energy(COST):
		return _refusal("insufficient_energy")
	if not deck.discard_played(card_id_value):
		return _refusal("card_not_held")
	# The printed Weak is an enemy-side stack: CombatEnemies adds it to the existing counter (it
	# never replaces a stack) after validating the whole roster and the admission itself.
	if not enemies.apply_statuses({target_position_value: {WEAK_STATUS_KEY: plan["weak"]}}):
		return _refusal("malformed_statuses")
	var target_record = enemies._enemies[target_position_value - 1]
	if not target_record is Dictionary:
		return _refusal("invalid_target")
	if not target_record.get("statuses", {}) is Dictionary:
		return _refusal("malformed_statuses")
	# Fear is written canonically on the authoritative record here instead of being dropped by (or
	# smuggled through) CombatEnemies.can_apply_statuses, which accepts integer Weak only.
	target_record["statuses"][FEAR_STATUS_KEY] = true
	var after: Dictionary = enemies.get_enemy(target_position_value)
	var statuses: Dictionary = after.get("statuses", {})
	return {
		"ok": true,
		"reason": "applied",
		"card_id": card_id_value,
		"cost": COST,
		"energy_before": plan["energy_before"],
		"energy_after": deck.energy,
		"owner_position": plan["owner_position"],
		"target_position": target_position_value,
		"weak_applied": plan["weak"],
		"weak_before": plan["weak_before"],
		"weak_after": int(statuses.get(WEAK_STATUS_KEY, 0)),
		"fear_applied": statuses.get(FEAR_STATUS_KEY) == true,
		"fear_before": plan["fear_before"],
		"target_hp": int(after["hp"]),
		"target_block": int(after["block"]),
		"cannot_buff_next_turn": statuses.get(FEAR_STATUS_KEY) == true,
	}


## Read-only preflight of the whole transaction. Returns a detached plan on success or a refusal
## receipt; nothing is charged, discarded or written on refusal.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int) -> Dictionary:
	if deck == null or party == null or enemies == null:
		return _refusal("invalid_request")
	if deck.combat_state == null or deck._rng == null or not deck.turn_active:
		return _refusal("inactive_turn")
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	if not CARDS.has(id):
		return _refusal("unsupported_card")
	var card: Dictionary = CARDS[id]
	# Fetch the authored record from the one catalog that owns this ID; a rewritten, relinked or
	# copied record can never be paid for as this effect.
	if not _authenticate(id):
		return _refusal("catalog_mismatch")

	# Verify the complete hero roster and every authoritative hero status shape, then bind the owner
	# by hero ID to its actual current slot. Swapping seats grants no false authority.
	if not _valid_party(party):
		return _refusal("invalid_party")
	var heroes: Array[Dictionary] = party.get_heroes()
	var owner_position := 0
	for index in range(heroes.size()):
		var hero: Dictionary = heroes[index]
		if hero.get("id") != OWNER:
			continue
		if owner_position != 0:
			return _refusal("invalid_party")
		owner_position = index + 1
	for index in range(heroes.size()):
		if not _valid_statuses(heroes[index].get("statuses", {})):
			return _refusal("malformed_statuses")
	if owner_position == 0:
		return _refusal("owner_missing")
	if not FROM_POSITIONS.has(owner_position):
		return _refusal("owner_illegal_position")
	if int(heroes[owner_position - 1]["hp"]) == 0:
		return _refusal("owner_downed")

	# Verify every enemy slot's authoritative shape and status map before the target query, so a
	# malformed roster never masquerades as a legal target.
	if not _valid_enemies(enemies):
		return _refusal("invalid_enemies")
	var roster: Array[Dictionary] = enemies.get_enemies()
	for index in range(roster.size()):
		if not _valid_statuses(roster[index].get("statuses", {})):
			return _refusal("malformed_statuses")

	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	if deck.energy < COST:
		return _refusal("insufficient_energy")

	# The sack face only reaches the authored 1-3 enemy slots, and only a living one.
	if not TO_POSITIONS.has(target_position):
		return _refusal("invalid_target")
	if target_position < 1 or target_position > roster.size():
		return _refusal("invalid_target")
	var target: Dictionary = roster[target_position - 1]
	if int(target["hp"]) == 0:
		return _refusal("invalid_target")
	var target_statuses: Dictionary = target.get("statuses", {})
	var weak: int = card["weak"]

	# The printed Weak is preflighted through the enemy model's own validator (which also rechecks
	# the whole roster), so a malformed or overflowing counter refuses BEFORE anything is charged.
	if not enemies.can_apply_statuses({target_position: {WEAK_STATUS_KEY: weak}}):
		return _refusal("malformed_statuses")

	# Fear is not part of that shared validator, so the exact post-play map is projected here and
	# proven canonical and still tickable at the owner-turn boundary before payment.
	var projected: Dictionary = target_statuses.duplicate(true)
	projected[WEAK_STATUS_KEY] = int(projected.get(WEAK_STATUS_KEY, 0)) + weak
	projected[FEAR_STATUS_KEY] = true
	if not _valid_statuses(projected):
		return _refusal("malformed_statuses")
	if not _projected_roster_ticks(roster, target_position, projected):
		return _refusal("malformed_statuses")

	return {
		"ok": true,
		"reason": "ready",
		"card_id": id,
		"weak": weak,
		"weak_before": int(target_statuses.get(WEAK_STATUS_KEY, 0)),
		"fear_before": target_statuses.get(FEAR_STATUS_KEY) == true,
		"energy_before": deck.energy,
		"owner_position": owner_position,
		"target_position": target_position,
	}


## True only when the ID is one of the four authentic printings and its owning catalog record still
## carries every authored field. Read-only; a missing or rewritten record is simply unsupported.
func _authenticate(card_id: String) -> bool:
	if not CARDS.has(card_id):
		return false
	var card: Dictionary = CARDS[card_id]
	var definition: Dictionary = _catalog_definition(card_id, str(card["catalog"]))
	if not _matches_authored(definition, card_id, card):
		return false
	if card.has("upgrade_id"):
		return definition.get("upgrade_id") == card["upgrade_id"] \
			and not definition.has("upgrade_of")
	return definition.get("upgrade_of") == card["upgrade_of"] \
		and not definition.has("upgrade_id")


## Reads the exact authored record from the catalog that owns this ID (never the other Scarecrow
## catalog) and returns a detached copy, or {} when the ID is not in that catalog.
func _catalog_definition(card_id: String, catalog: String) -> Dictionary:
	if catalog == "starter":
		return ScarecrowStarterCards.new().get_definition(card_id)
	if catalog == "pool":
		return ScarecrowPoolCards.new().get_definition(card_id)
	return {}


## The record must still carry exactly the authored line: identity, owner, one energy, the 1-3
## seating, `enemy_single` targeting, the exact printed Weak plus Fear pair with literal Variant
## types, the authored copy/reward facts and the base/"+" link in its own catalog.
func _matches_authored(definition: Dictionary, card_id: String, card: Dictionary) -> bool:
	if definition.is_empty() or definition.get("id") != card_id:
		return false
	if definition.get("owner") != OWNER:
		return false
	var cost: Variant = definition.get("cost")
	if not cost is int or int(cost) != COST:
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
	var weak: Variant = effects.get(WEAK_STATUS_KEY)
	var fear: Variant = effects.get(FEAR_STATUS_KEY)
	if effects.size() != 2 or not weak is int or not fear is bool:
		return false
	if int(weak) != int(card["weak"]) or not bool(fear):
		return false
	var starting_copies: Variant = definition.get("starting_copies")
	if not starting_copies is int or int(starting_copies) != int(card["starting_copies"]):
		return false
	var reward_eligible: Variant = definition.get("reward_eligible")
	if not reward_eligible is bool or bool(reward_eligible) != bool(card["reward_eligible"]):
		return false
	return true


func _exact_positions(value: Variant, expected: Array[int]) -> bool:
	if not value is Array or value.size() != expected.size():
		return false
	var positions: Array = value
	for index in range(expected.size()):
		if not positions[index] is int or positions[index] != expected[index]:
			return false
	return true


## Three genuine seats in order with distinct nonempty string IDs and sane per-combat records.
func _valid_party(party: CombatParty) -> bool:
	if not party.is_valid() or party._heroes.size() != CombatParty.PARTY_SIZE:
		return false
	var seen: Dictionary = {}
	for index in range(CombatParty.PARTY_SIZE):
		var record: Variant = party._heroes[index]
		if not record is Dictionary:
			return false
		var hero: Dictionary = record
		var hero_id: Variant = hero.get("id")
		if not hero_id is String or (hero_id as String).is_empty() or seen.has(hero_id):
			return false
		seen[hero_id] = true
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


## One to three genuine enemy slots in order with distinct nonempty string IDs and sane records.
## Slain slots remain structurally valid; target eligibility is checked separately.
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
		if not enemy_id is String or (enemy_id as String).is_empty() or seen.has(enemy_id):
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


## CombatStatuses' own canonical status vocabulary and shapes: the five non-negative integer
## counters, the two one-shot integer tokens (0 or 1) and Fear as exactly the literal boolean true
## (absent when inactive).
func _valid_statuses(statuses: Variant) -> bool:
	if not statuses is Dictionary:
		return false
	var values: Dictionary = statuses
	for name in values:
		if not name is String or (name as String).is_empty():
			return false
		var count: Variant = values[name]
		if name == FEAR_STATUS_KEY:
			if not count is bool or not bool(count):
				return false
			continue
		if not count is int:
			return false
		if ONE_SHOT_STATUS_KEYS.has(name):
			if count != 0 and count != 1:
				return false
			continue
		if not ATTACK_STATUS_KEYS.has(name) or count < 0:
			return false
	return true


## The projected post-play roster must still pass the real owner-turn batch, so writing Fear can
## never produce a map that the Fear lifecycle refuses to tick. Read-only: works on deep copies.
func _projected_roster_ticks(roster: Array[Dictionary], target_position: int,
		projected: Dictionary) -> bool:
	var proposal: Array = []
	for index in range(roster.size()):
		var actor: Dictionary = roster[index].duplicate(true)
		if index + 1 == target_position:
			actor["statuses"] = projected.duplicate(true)
		proposal.append(actor)
	return bool(CombatStatusTurnBatch.new().tick_side("enemies", proposal).get("ok", false))


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
