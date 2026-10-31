class_name CombatScarecrowCrowFlockCards
extends RefCounted
## V3-1 scene-free paid resolver for the Scarecrow's two Crow Flock reward printings.
##
## Crow Flock (a reward-pool uncommon) and its "+" upgrade print two energy, an enemy-wide area
## effect reachable from hero seats 2-3, and Weak plus Fear. The flock does the work without a
## selected target: every living enemy in the printed 1-3 slots is Weakened and, for its next enemy
## turn only, cannot buff. There is no damage and no Block here.
##
## The catalog stays authoritative: the caller supplies only an actual held card ID, never a card
## dictionary, a Weak magnitude, a Fear value, an owner or a license to change the shared status
## model. This service authenticates the exact held catalog record (owner, cost, seating, area
## targeting, the exact effect dictionary with Variant types, and the reciprocal base/"+" link in
## both directions), then, after a complete read-only preflight of the party, the roster and every
## projected status map, charges exactly two shared energy, discards exactly that held copy, adds the
## printed Weak stack to every living enemy in slots 1-3 through CombatEnemies' own status path and
## finally writes the canonical Fear flag `cannot_buff_next_turn: true` onto each of those same
## authoritative status records. Slain slots, slots outside the printed window, HP, Block and every
## other status are left exactly as they were, each actor keeps its fixed slot identity, and no card
## is drawn.
##
## Fear is a literal boolean, not a count: CombatStatuses.can_apply_buff reads it on the enemy's
## next owner turn and CombatStatusTurnBatch.tick_side('enemies', ...) expires it at that owner
## turn's end, while Weak is authored and aged separately. This resolver never ticks, ages or
## shortens anything: no owner-turn boundary is applied at card-play time, and the flag carries no
## turn count to lengthen. Playing an authentic copy again simply re-arms the same flag; it can never
## become "Fear 2".
##
## Every rejection is a strict no-op: the rosters, every authoritative status map (including the
## projected post-play maps), the affordability and the Weak additions are preflighted before the
## first mutation, and no shuffle, draw or random target can advance the run RNG.
##
## This is callable rules-layer behaviour only. It does not register these IDs in the live hand,
## rewards, run deck or the app flow; a later task owns hand/attack dispatch.

const BASE_ID := "scarecrow_crow_flock"
const PLUS_ID := "scarecrow_crow_flock_plus"
const OWNER := "scarecrow"
const COST := 2
const TARGET_KIND := "enemy_all"
const FROM_POSITIONS: Array[int] = [2, 3]
const TO_POSITIONS: Array[int] = [1, 2, 3]
const NO_TARGET_SLOT := 0
const DISPLAY_NAME := "Crow Flock"

## Fear's canonical status key and value: the authored `cannot_buff_next_turn` flag, stored as the
## literal boolean true. `false`, 1, 1.0 and "true" are malformed, never inactive.
const FEAR_STATUS_KEY := "cannot_buff_next_turn"
const WEAK_STATUS_KEY := "weak"

## The two authentic printings, each bound to the printed Weak count and the authored pool facts
## this service must still find before paying.
const CARDS := {
	"scarecrow_crow_flock": {"weak": 1, "upgraded": false},
	"scarecrow_crow_flock_plus": {"weak": 2, "upgraded": true},
}

## CombatStatuses owns this vocabulary: the five N-turn counters with non-negative integer counts
## and the two one-shot tokens as integer 0 (inert) or 1 (armed). Any other key or shape is a
## malformed authoritative map and refuses the play instead of being coerced into a legal stack.
const ATTACK_STATUS_KEYS: Array[String] = ["bleed", "weak", "exposed", "tangled", "riposte"]
const ONE_SHOT_STATUS_KEYS: Array[String] = ["dodge_next_attack", "blind_next_attack"]


## True only for the two authentic catalog IDs whose authored line is still intact. Pure lookup:
## nothing is charged, discarded or mutated and no RNG is touched.
func is_supported_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	if not CARDS.has(card_id):
		return false
	return _authenticate()


## The single paid transaction: authenticate, preflight every input, then charge the printed cost,
## discard exactly the held copy, add the printed Weak to every living enemy in slots 1-3 and write
## canonical Fear on each of them.
##
## enemy_all has no selected target, so `target_position` must stay the zero sentinel; any other
## value fails closed even when the roster has room.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int = NO_TARGET_SLOT) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# exact held ID is affordable, the unique living owner sits in an authored seat, every status map
	# is canonical and every projected post-play map is admissible and still tickable. Keep the
	# defensive returns so an unexpected model change still fails closed.
	var card_id_value: String = plan["card_id"]
	var targets: Array = plan["targets"]
	if not deck.try_spend_energy(COST):
		return _refusal("insufficient_energy")
	if not deck.discard_played(card_id_value):
		return _refusal("card_not_held")
	# The printed Weak is an enemy-side stack: one CombatEnemies call adds it to each living target's
	# existing counter (it never replaces a stack) after validating the whole roster and every
	# addition, so no target is written before all of them are admissible.
	var applications: Dictionary = {}
	for position: int in targets:
		applications[position] = {WEAK_STATUS_KEY: plan["weak"]}
	if not enemies.apply_statuses(applications):
		return _refusal("malformed_statuses")
	# Fear is written canonically on each authoritative record here instead of being dropped by (or
	# smuggled through) CombatEnemies.can_apply_statuses, which accepts integer Weak only.
	for position: int in targets:
		var target_record: Dictionary = enemies._enemies[position - 1]
		var statuses: Dictionary = target_record["statuses"]
		statuses[FEAR_STATUS_KEY] = true
	var applied: Array[Dictionary] = []
	for position: int in targets:
		var after: Dictionary = enemies.get_enemy(position)
		var statuses: Dictionary = after.get("statuses", {})
		applied.append({
			"position": position,
			"weak_before": int(plan["weak_before"][position]),
			"weak_after": int(statuses.get(WEAK_STATUS_KEY, 0)),
			"fear_before": bool(plan["fear_before"][position]),
			"fear_applied": statuses.get(FEAR_STATUS_KEY) == true,
		})
	return {
		"ok": true,
		"reason": "applied",
		"card_id": card_id_value,
		"cost": COST,
		"energy_before": plan["energy_before"],
		"energy_after": deck.energy,
		"owner_position": plan["owner_position"],
		"target_position": NO_TARGET_SLOT,
		"targets": targets.duplicate(),
		"weak": plan["weak"],
		"applied": applied,
	}


## Read-only preflight of the whole transaction. Returns a detached plan on success or a refusal
## receipt; nothing is charged, discarded or written on refusal.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int) -> Dictionary:
	if deck == null or party == null or enemies == null:
		return _refusal("invalid_request")
	if deck.combat_state == null or deck._rng == null or not deck.turn_active:
		return _refusal("inactive_turn")
	if typeof(card_id) != TYPE_STRING or not CARDS.has(card_id):
		return _refusal("unsupported_card")
	var id: String = card_id
	# Fetch both authored records from the one catalog that owns them; a rewritten, relinked or
	# copied record can never be paid for as this effect, and the base/"+" pair must still name
	# each other reciprocally.
	if not _authenticate():
		return _refusal("catalog_mismatch")

	# Verify the complete hero roster and every authoritative hero status shape, then bind the owner
	# by hero ID to its actual current slot. Swapping seats grants no false authority.
	if not _valid_party(party):
		return _refusal("invalid_party")
	var heroes: Array[Dictionary] = party._heroes
	for index in range(heroes.size()):
		if not _valid_statuses(heroes[index].get("statuses", {})):
			return _refusal("malformed_statuses")
	var owner_position := 0
	for index in range(heroes.size()):
		var hero: Dictionary = heroes[index]
		if hero.get("id") != OWNER:
			continue
		if owner_position != 0:
			return _refusal("invalid_party")
		owner_position = index + 1
	if owner_position == 0:
		return _refusal("owner_missing")
	if not FROM_POSITIONS.has(owner_position):
		return _refusal("owner_illegal_position")
	if int(heroes[owner_position - 1]["hp"]) == 0:
		return _refusal("owner_downed")

	# Verify every enemy slot's authoritative shape and status map before any target query, so a
	# malformed roster never masquerades as a legal area. Reading the model's own fields (rather than
	# is_valid()/get_enemies()) keeps a refused play from settling an unrelated pending revival.
	if not _valid_enemies(enemies):
		return _refusal("invalid_enemies")
	var roster: Array[Dictionary] = enemies._enemies
	for index in range(roster.size()):
		if not _valid_statuses(roster[index].get("statuses", {})):
			return _refusal("malformed_statuses")

	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	if deck.energy < COST:
		return _refusal("insufficient_energy")

	# Crow Flock has no selected target: the zero sentinel is the only accepted value.
	if target_position != NO_TARGET_SLOT:
		return _refusal("invalid_target")

	# The flock only reaches the authored 1-3 enemy slots, and only the living ones. Slain slots and
	# any slot outside the window keep their fixed identity and every one of their fields.
	var weak: int = int(CARDS[id]["weak"])
	var targets: Array = []
	var weak_before: Dictionary = {}
	var fear_before: Dictionary = {}
	for position: int in TO_POSITIONS:
		if position > roster.size():
			break
		var target: Dictionary = roster[position - 1]
		if int(target["hp"]) == 0:
			continue
		var target_statuses: Dictionary = target.get("statuses", {})
		var current_weak: int = int(target_statuses.get(WEAK_STATUS_KEY, 0))
		if current_weak > CombatEnemies.MAX_INT - weak:
			return _refusal("malformed_statuses")
		targets.append(position)
		weak_before[position] = current_weak
		fear_before[position] = target_statuses.get(FEAR_STATUS_KEY) == true
	if targets.is_empty():
		return _refusal("no_living_targets")

	# The printed Weak is preflighted through the enemy model's own validator (which also rechecks
	# the whole roster), so a malformed or overflowing counter refuses BEFORE anything is charged.
	var proposed: Dictionary = {}
	for position: int in targets:
		proposed[position] = {WEAK_STATUS_KEY: weak}
	if not enemies.can_apply_statuses(proposed):
		return _refusal("malformed_statuses")

	# Fear is not part of that shared validator, so every exact post-play map is projected here and
	# proven canonical and still tickable at the owner-turn boundary before payment.
	var projected_roster: Array = enemies._enemies.duplicate(true)
	for position: int in targets:
		var projected: Dictionary = projected_roster[position - 1].get("statuses", {}).duplicate(true)
		projected[WEAK_STATUS_KEY] = int(weak_before[position]) + weak
		projected[FEAR_STATUS_KEY] = true
		if not _valid_statuses(projected):
			return _refusal("malformed_statuses")
		projected_roster[position - 1]["statuses"] = projected
	if not CombatStatusTurnBatch.new().tick_side("enemies", projected_roster).get("ok", false):
		return _refusal("malformed_statuses")

	return {
		"ok": true,
		"reason": "ready",
		"card_id": id,
		"weak": weak,
		"weak_before": weak_before,
		"fear_before": fear_before,
		"energy_before": deck.energy,
		"owner_position": owner_position,
		"targets": targets,
	}


## True only when both authentic printings still carry every authored field and their upgrade links
## name each other. Read-only; a missing or rewritten record is simply unsupported.
func _authenticate() -> bool:
	return _same_typed(_catalog_definition(BASE_ID), _expected_definition(BASE_ID)) \
		and _same_typed(_catalog_definition(PLUS_ID), _expected_definition(PLUS_ID))


## The exact authored record from the one catalog allowed to own these IDs. Overridable so a
## negative regression can prove a forged catalog never pays.
func _catalog_definition(card_id: String) -> Dictionary:
	return ScarecrowPoolCards.new().get_definition(card_id)


## The full authored line this service is bound to, including the metadata and the base/"+" link.
func _expected_definition(card_id: String) -> Dictionary:
	var upgraded: bool = card_id == PLUS_ID
	var definition := {
		"id": PLUS_ID if upgraded else BASE_ID,
		"display_name": DISPLAY_NAME + ("+" if upgraded else ""),
		"owner": OWNER,
		"cost": COST,
		"from_positions": FROM_POSITIONS.duplicate(),
		"target_kind": TARGET_KIND,
		"to_positions": TO_POSITIONS.duplicate(),
		"effects": {
			WEAK_STATUS_KEY: int(CARDS[PLUS_ID if upgraded else BASE_ID]["weak"]),
			FEAR_STATUS_KEY: true,
		},
		"illustration_path": "res://assets/paper/cards/" + BASE_ID + ".png",
		"starting_copies": 0,
		"rarity": "uncommon",
		"reward_eligible": not upgraded,
	}
	if upgraded:
		definition["upgrade_of"] = BASE_ID
	else:
		definition["upgrade_id"] = PLUS_ID
	return definition


## Literal, type-exact recursive comparison: an int where a bool belongs (or a missing/extra key)
## is a forgery, never an equivalent value.
func _same_typed(actual: Variant, expected: Variant) -> bool:
	if typeof(actual) != typeof(expected):
		return false
	if expected is Dictionary:
		if actual.size() != expected.size():
			return false
		for key in expected:
			if not actual.has(key) or not _same_typed(actual[key], expected[key]):
				return false
		return true
	if expected is Array:
		if actual.size() != expected.size():
			return false
		for index in range(expected.size()):
			if not _same_typed(actual[index], expected[index]):
				return false
		return true
	return actual == expected


## Three genuine seats in order with distinct nonempty string IDs and sane per-combat records.
func _valid_party(party: CombatParty) -> bool:
	if party._heroes.size() != CombatParty.PARTY_SIZE:
		return false
	var seen: Dictionary = {}
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = party._heroes[index]
		if not _valid_actor(hero, index + 1, seen):
			return false
	return true


## One to four genuine enemy slots in order with distinct nonempty string IDs and sane records.
## Slain slots remain structurally valid; target eligibility is checked separately.
func _valid_enemies(enemies: CombatEnemies) -> bool:
	var count: int = enemies._enemies.size()
	if count < 1 or count > CombatEnemies.MAX_ENEMIES:
		return false
	var seen: Dictionary = {}
	for index in range(count):
		var enemy: Dictionary = enemies._enemies[index]
		if not _valid_actor(enemy, index + 1, seen):
			return false
		if not CombatEnemies.valid_revive_flags(enemy) \
				or not CombatEnemies.valid_split_flags(enemy):
			return false
		# A pending death-revival is not a stable preflight state: reading it would settle (mutate) an
		# otherwise rejected attempt, so refuse instead of settling it inside this service.
		if int(enemy["hp"]) == 0 and CombatEnemies.revive_pending(enemy):
			return false
	return true


func _valid_actor(actor: Dictionary, position: int, seen: Dictionary) -> bool:
	var id: Variant = actor.get("id")
	var seat: Variant = actor.get("position")
	var maximum: Variant = actor.get("max_hp")
	var hp: Variant = actor.get("hp")
	var block: Variant = actor.get("block")
	if not id is String or (id as String).is_empty() or seen.has(id) \
			or not seat is int or seat != position \
			or not maximum is int or maximum <= 0 \
			or not hp is int or hp < 0 or hp > maximum \
			or not block is int or block < 0 \
			or not actor.get("statuses", {}) is Dictionary:
		return false
	seen[id] = true
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


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
