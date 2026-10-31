class_name CombatSeamstressV3BlanketCards
extends RefCounted
## Scene-free paid resolver for the Seamstress's Blanket of Barbs reward printings (V3-1).
##
## Blanket of Barbs is the giant-needle hero's thread sweep, not a strike: the printed blanket is
## thrown over the WHOLE living enemy line, laying red thread (Bleed) and pulling loose stitches
## (Unravel) on every foe at once. Both printings cost 2, come only from her middle or rear seat
## (FROM [2, 3]) and cover every authored enemy slot (`enemy_all`, TO [1, 2, 3]). No slot is chosen
## by the caller, so this transaction takes no target at all.
##
## Printed numbers (data/cards/v3_seamstress_pool_cards.gd):
##   Blanket of Barbs  - uncommon, cost 2, effects {"bleed": 2, "unravel": 2}
##   Blanket of Barbs+ - uncommon, cost 2, effects {"bleed": 3, "unravel": 3}
## The Seamstress's authored passive (+1 Bleed whenever she applies Bleed) is added here, at
## resolution time, exactly like the red-thread printings do; it is never baked into the catalog.
## A successful base cast therefore lays Bleed 3 and Unravel 2, the "+" lays Bleed 4 and Unravel 3.
##
## The two shared battle authorities stay authoritative and are never reimplemented here:
##
## * The caller's roster-bound CombatUnravel owns the per-slot gauge, its 8/12/16 normal/elite/boss
##   threshold, clamping at the threshold, the single queued action skip, the after-skip reset and
##   the +4 threshold increase. This service only asks it to apply the printed charge to each living
##   slot; threshold, clamping and one-pending-skip behaviour remain its own.
## * CombatEnemies owns the status records. Every Bleed addition lands through its
##   can_apply_statuses / apply_statuses seam, so pre-existing Bleed stacks add up and every other
##   status (including the canonical one-shot tokens) is preserved untouched.
##
## The card is control only: it deals no damage, absorbs no Block, does not advance or skip enemy
## actions, does not tick Bleed, does not move or compact the enemy line, adds no Pinned token and
## never draws or reseeds the run RNG. A slain enemy slot is skipped even though its original slot
## is inside the printed TO window; death never renumbers the line, so effects are always reported
## by ORIGINAL slot.
##
## The catalog stays authoritative: the caller supplies only the held card ID, never a target,
## cost, effect dictionary, seat list or gauge amount. The whole exact base/'+' printing pair is
## authenticated (including reciprocal upgrade links) before anything is charged, and the complete
## party, enemy roster, every status map, the gauge binding and every affected slot's gauge are
## validated before the first mutation. Every refusal is a pure no-op: no energy, hand, pile, hero,
## enemy HP/Block/status, gauge or seeded RNG change.
##
## This is the callable rules layer only. Registering these IDs in the live hand, rewards, run deck
## or app flow is a later, separately owned task and is not claimed here.

const OWNER_ID := "seamstress"
const TARGET_KIND := "enemy_all"

## The printed FROM line is exactly 2-3: the base has no legal seat at the front.
const FROM_POSITIONS: Array[int] = [2, 3]
## The printed TO line is exactly the three original enemy slots and never widens or compacts.
const TO_POSITIONS: Array[int] = [1, 2, 3]

## GAME_DESIGN.md's authored Seamstress passive: when she applies Bleed, add one more Bleed.
## Applied at resolution time, never baked into the printed catalog entries.
const PASSIVE_BLEED := 1

## Same signed 64-bit ceiling the shared models use for their own counters.
const MAX_COUNTER := 9223372036854775807

## The two authentic printings, each with the complete catalog line it must still carry.
## Base and "+" share owner, cost, seats, target, rarity, art and copy metadata; only the printed
## Bleed and Unravel rise, and the base/'+' link reverses between the pair.
const PRINTINGS := {
	"seamstress_v3_blanket_of_barbs": {
		"display_name": "Blanket of Barbs",
		"cost": 2,
		"bleed": 2,
		"unravel": 2,
		"effects": {"bleed": 2, "unravel": 2},
		"upgrade_id": "seamstress_v3_blanket_of_barbs_plus",
	},
	"seamstress_v3_blanket_of_barbs_plus": {
		"display_name": "Blanket of Barbs+",
		"cost": 2,
		"bleed": 3,
		"unravel": 3,
		"effects": {"bleed": 3, "unravel": 3},
		"upgrade_of": "seamstress_v3_blanket_of_barbs",
	},
}

## One-shot integer tokens: absent or 0 is inert, 1 is armed. Nothing else is a legal shape.
const ONE_SHOT_STATUS_KEYS: Array[String] = ["dodge_next_attack", "blind_next_attack"]
## The N-turn counters the shared combat status rules accept (non-negative ints).
const COUNTER_STATUS_KEYS: Array[String] = ["bleed", "weak", "exposed", "tangled", "riposte"]
## Fear is the shared buff lock, the one canonical status that is not an integer counter: its
## single accepted value is the literal boolean true (see CombatStatuses._valid_statuses).
const FEAR_STATUS_KEY := "cannot_buff_next_turn"
## The one status this card writes.
const BLEED_STATUS_KEY := "bleed"

var _catalog: RefCounted


## `catalog` is the authoritative V3SeamstressPoolCards instance this service authenticates
## against. The default is the shipped catalog; an explicit instance lets a test prove that a
## rewritten record for an otherwise valid, held ID is refused instead of paid for.
func _init(catalog: Variant = null) -> void:
	_catalog = catalog if catalog is V3SeamstressPoolCards else V3SeamstressPoolCards.new()


## True only for the two authentic catalog printings, and only while BOTH records of the pair still
## carry their authored line. Pure lookup; nothing is charged or mutated and no RNG is touched.
func is_supported_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	if not PRINTINGS.has(id):
		return false
	return _authentic_pair(id)


## The single paid transaction: authenticate the printing pair, preflight the whole request, then
## charge the printed energy, discard exactly one held copy, add the printed Bleed plus her passive
## to every LIVING enemy slot and apply the printed Unravel through the bound gauge. There is no
## target slot: `enemy_all` covers the authored line. A refusal changes no deck, party, enemy,
## status, gauge or RNG state.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		unravel: Variant, card_id: Variant) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, unravel, card_id)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	var gauge_authority: CombatUnravel = unravel
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# exact held ID is affordable, the unique living owner sits in a printed seat, every affected
	# slot is a living original enemy slot whose Bleed addition is admissible, and the gauge is
	# bound to this exact roster with a well-formed, non-overflowing record for every slot. Keep the
	# defensive returns so an unexpected model change still fails closed. Nothing here draws cards
	# or touches the seeded run RNG.
	if not deck.try_spend_energy(int(plan["cost"])):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")
	# One authoritative status write for the whole line: only each living slot's Bleed key is
	# touched, so pre-existing Bleed stacks add up and every other status is preserved.
	if not enemies.apply_statuses(plan["status_additions"]):
		return _refusal("malformed_statuses")

	var targets: Array = plan["targets"]
	var additions: Dictionary = plan["status_additions"]
	var gauges_before: Dictionary = plan["gauges_before"]
	var unravel_applied: int = int(plan["unravel_applied"])
	var effects: Array[Dictionary] = []
	var applied_slots: Array[int] = []
	for target: Dictionary in targets:
		var position: int = int(target["position"])
		# The real roster-bound gauge authority applies its own clamp/pending-skip rules; a charge
		# that it refuses fails closed rather than being reported as applied.
		if not gauge_authority.apply_unravel(enemies, position, unravel_applied):
			return _refusal("unravel_rejected")
		applied_slots.append(position)
		var live: Dictionary = enemies.get_enemy(position)
		var live_statuses: Dictionary = _live_statuses(live)
		var bleed_added: int = int(additions[position][BLEED_STATUS_KEY])
		effects.append({
			"position": position,
			"id": str(live.get("id", "")),
			"bleed_before": int(target["bleed_before"]),
			"bleed_after": int(live_statuses.get(BLEED_STATUS_KEY, 0)),
			"bleed_added": bleed_added,
			"gauge_before": gauges_before[position],
			"gauge_after": gauge_authority.get_snapshot(position),
			"hp_before": int(target["hp_before"]),
			"hp_after": int(live.get("hp", 0)),
			"block_before": int(target["block_before"]),
			"block_after": int(live.get("block", 0)),
			"slain": enemies.is_slain(position),
		})
	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": int(plan["cost"]),
		"energy_spent": int(plan["cost"]),
		"energy_before": int(plan["energy_before"]),
		"energy_after": deck.energy,
		"owner_position": int(plan["owner_position"]),
		"target_kind": TARGET_KIND,
		"targets": applied_slots,
		"target_count": applied_slots.size(),
		"printed_bleed": int(plan["printed_bleed"]),
		"passive_bleed": PASSIVE_BLEED,
		"bleed_applied": int(plan["bleed_applied"]),
		"printed_unravel": int(plan["printed_unravel"]),
		"unravel_applied": unravel_applied,
		"effects": effects,
		"damage": 0,
		"hp_loss": 0,
		"block_absorbed": 0,
	}


## Read-only preflight of the whole transaction. Returns a detached plan or a refusal receipt.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		unravel: Variant, card_id: Variant) -> Dictionary:
	if not is_supported_card(card_id):
		return _refusal("unsupported_card")
	var printed: Dictionary = _authenticated(card_id)
	if printed.is_empty():
		return _refusal("catalog_mismatch")
	if deck == null or party == null or enemies == null:
		return _refusal("invalid_request")
	# The roster-bound gauge is mandatory: this resolver never manufactures a private one.
	if not unravel is CombatUnravel:
		return _refusal("invalid_unravel_authority")
	if deck.combat_state == null or deck._rng == null:
		return _refusal("invalid_deck")
	if not party.is_valid() or party._heroes.size() != CombatParty.PARTY_SIZE:
		return _refusal("invalid_party")
	# CombatEnemies.is_valid() permits an all-slain roster; a swept line needs a living target.
	if not enemies.is_valid() or enemies.is_victorious():
		return _refusal("invalid_roster")
	if not deck.turn_active:
		return _refusal("inactive_turn")

	# Verify the complete hero roster, every authoritative status map, then bind the owner by hero ID
	# to its actual current seat. A swapped, torn, mislabelled or duplicated Seamstress grants no
	# authority, and a copied record can never stand in for another hero.
	var heroes: Array[Dictionary] = party.get_heroes()
	if heroes.size() != CombatParty.PARTY_SIZE:
		return _refusal("invalid_party")
	var owner_position := 0
	var owner_count := 0
	var seen_ids: Array[String] = []
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = heroes[index]
		var hero_id: Variant = hero.get("id")
		var hero_position: Variant = hero.get("position")
		var hp: Variant = hero.get("hp")
		var max_hp: Variant = hero.get("max_hp")
		var block: Variant = hero.get("block")
		if not hero_id is String or hero_id.is_empty() or seen_ids.has(hero_id):
			return _refusal("invalid_party")
		if not hero_position is int or hero_position != index + 1:
			return _refusal("invalid_party")
		if not max_hp is int or max_hp <= 0 or not hp is int or hp < 0 or hp > max_hp:
			return _refusal("invalid_party")
		if not block is int or block < 0:
			return _refusal("invalid_party")
		if not _valid_status_shape(hero.get("statuses", {})):
			return _refusal("malformed_statuses")
		seen_ids.append(hero_id)
		if hero_id == OWNER_ID:
			owner_count += 1
			owner_position = index + 1
	# The shared turn-batch validator must also accept every authoritative hero record and map.
	if not CombatStatusTurnBatch.new().tick_side("heroes", heroes).get("ok", false):
		return _refusal("malformed_statuses")
	if owner_count != 1:
		return _refusal("owner_missing" if owner_count == 0 else "duplicate_owner")
	if not FROM_POSITIONS.has(owner_position):
		return _refusal("owner_illegal_position")
	# A torn (0 HP) Seamstress cannot throw the blanket.
	if int(heroes[owner_position - 1]["hp"]) == 0:
		return _refusal("owner_downed")

	# Verify every enemy slot's authoritative shape and status map before collecting targets, so a
	# malformed roster never masquerades as a legal line. Original positions never compact.
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
			return _refusal("invalid_roster")
		if not enemy_position is int or enemy_position != index + 1:
			return _refusal("invalid_roster")
		if not enemy_max_hp is int or enemy_max_hp <= 0:
			return _refusal("invalid_roster")
		if not enemy_hp is int or enemy_hp < 0 or enemy_hp > enemy_max_hp:
			return _refusal("invalid_roster")
		if not enemy_block is int or enemy_block < 0:
			return _refusal("invalid_roster")
		if not _valid_status_shape(enemy.get("statuses", {})):
			return _refusal("malformed_statuses")
		seen_enemy_ids.append(enemy_id)
	if not CombatStatusTurnBatch.new().tick_side("enemies", roster).get("ok", false):
		return _refusal("malformed_statuses")

	# The gauge must belong to THIS battle's exact roster instance (never a detached copy, a
	# different fight or a partially bound service) and every original slot must carry a well-formed
	# record before any payment.
	var gauge_authority: CombatUnravel = unravel
	if gauge_authority._bound_enemies != enemies:
		return _refusal("wrong_roster_unravel")
	var gauges_before: Dictionary = {}
	for index in range(roster.size()):
		var position: int = index + 1
		var gauge: Dictionary = gauge_authority.get_snapshot(position)
		if not CombatUnravel._valid_gauge(gauge):
			return _refusal("invalid_gauge")
		gauges_before[position] = gauge

	# Collect the LIVING original slots inside the printed TO window. A slain slot is skipped even
	# though its original position is printed; it is never replaced by a surviving neighbour.
	var targets: Array[Dictionary] = []
	for position: int in TO_POSITIONS:
		if position > roster.size():
			continue
		var record: Dictionary = roster[position - 1]
		if int(record["hp"]) == 0:
			continue
		targets.append({
			"position": position,
			"hp_before": int(record["hp"]),
			"block_before": int(record["block"]),
			"bleed_before": int(_live_statuses(record).get(BLEED_STATUS_KEY, 0)),
		})
	if targets.is_empty():
		return _refusal("no_living_targets")

	var printed_bleed: int = int(printed["bleed"])
	var bleed_applied: int = printed_bleed + PASSIVE_BLEED
	var unravel_applied: int = int(printed["unravel"])
	var status_additions: Dictionary = {}
	for target: Dictionary in targets:
		var position: int = int(target["position"])
		if bleed_applied > MAX_COUNTER - int(target["bleed_before"]):
			return _refusal("status_overflow")
		# A printed charge that would overflow the counter is refused, not silently made free.
		var gauge: Dictionary = gauges_before[position]
		if int(gauge["gauge"]) > MAX_COUNTER - unravel_applied:
			return _refusal("unravel_overflow")
		status_additions[position] = {BLEED_STATUS_KEY: bleed_applied}
	# Preflight the exact cumulative Bleed counters through the shared enemy seam so a malformed
	# or overflowing stack refuses BEFORE anything is charged.
	if not enemies.can_apply_statuses(status_additions):
		return _refusal("malformed_statuses")

	# The card must be genuinely held and affordable before any state changes.
	if not deck.hand.has(card_id):
		return _refusal("card_not_held")
	var cost: int = int(printed["cost"])
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	return {
		"ok": true,
		"reason": "ready",
		"card_id": card_id,
		"cost": cost,
		"owner_position": owner_position,
		"printed_bleed": printed_bleed,
		"bleed_applied": bleed_applied,
		"printed_unravel": unravel_applied,
		"unravel_applied": unravel_applied,
		"energy_before": deck.energy,
		"targets": targets,
		"status_additions": status_additions,
		"gauges_before": gauges_before,
	}


## The authenticated pay contract for one printing, or {} when the pair no longer matches.
func _authenticated(card_id: Variant) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return {}
	var id: String = card_id
	if not PRINTINGS.has(id):
		return {}
	if not _authentic_pair(id):
		return {}
	var card: Dictionary = PRINTINGS[id]
	return {
		"cost": int(card["cost"]),
		"bleed": int(card["bleed"]),
		"unravel": int(card["unravel"]),
	}


## Reads the exact authored records and proves BOTH printings of the pair still carry their whole
## authored line, so a rewritten catalog (extra effect, another seat, target, cost, rarity, copy
## count, art path or broken upgrade link) can never be paid for as this effect.
func _authentic_pair(card_id: String) -> bool:
	var card: Dictionary = PRINTINGS.get(card_id, {})
	if card.is_empty():
		return false
	if not _authentic_record(_catalog_definition(card_id), card_id, card):
		return false
	if card.has("upgrade_id"):
		var plus_id: String = str(card["upgrade_id"])
		if not PRINTINGS.has(plus_id):
			return false
		var plus: Dictionary = _catalog_definition(plus_id)
		if plus.get("upgrade_of") != card_id or plus.has("upgrade_id"):
			return false
		return _authentic_record(plus, plus_id, PRINTINGS[plus_id])
	var base_id: String = str(card["upgrade_of"])
	if not PRINTINGS.has(base_id):
		return false
	var base: Dictionary = _catalog_definition(base_id)
	if base.get("upgrade_id") != card_id or base.has("upgrade_of"):
		return false
	return _authentic_record(base, base_id, PRINTINGS[base_id])


## The one catalog read of this service, so a test double (an explicit `_init` catalog) can prove
## that a rewritten record is refused rather than paid for.
func _catalog_definition(card_id: String) -> Dictionary:
	return _catalog.get_definition(card_id)


## The exact contract for one printing: identity, printed name, Seamstress owner, the printed
## two-energy cost, the whole-line target with both authored position windows, the complete printed
## effect dictionary with exact Variant types, the uncommon rarity, authored copy/reward metadata,
## the shared base art path and the base/'+' link inside the pool catalog.
func _authentic_record(definition: Dictionary, card_id: String, card: Dictionary) -> bool:
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
	if not _same_value(definition.get("effects"), card["effects"]):
		return false
	if definition.get("rarity") != "uncommon":
		return false
	# Both printings share the one authored base-card illustration.
	if definition.get("illustration_path") != "res://assets/paper/cards/seamstress_v3_blanket_of_barbs.png":
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


## Typed equality rejects coercible metadata (for example a float cost or a string Bleed) as well
## as altered seats, effects or upgrade links.
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


## The status shape the shared combat rules accept: named N-turn counters with non-negative int
## counts, the two one-shot tokens as integer 0/1, and Fear (`cannot_buff_next_turn`) as the
## literal boolean true only. Anything else fails closed before mutation.
func _valid_status_shape(statuses: Variant) -> bool:
	if not statuses is Dictionary:
		return false
	var values: Dictionary = statuses
	for name in values:
		if not name is String or (name as String).is_empty():
			return false
		var count: Variant = values[name]
		if name == FEAR_STATUS_KEY:
			# The canonical Fear lock is a literal boolean, never an int/string/float stand-in.
			if not count is bool or not bool(count):
				return false
			continue
		if not count is int:
			return false
		if name in ONE_SHOT_STATUS_KEYS:
			if int(count) != 0 and int(count) != 1:
				return false
			continue
		if not COUNTER_STATUS_KEYS.has(name) or int(count) < 0:
			return false
	return true


## The authoritative status dictionary stored on a real actor record. An absent key means no active
## counters; any other non-dictionary value was already rejected by the status-shape check.
func _live_statuses(record: Dictionary) -> Dictionary:
	var value: Variant = record.get("statuses", {})
	if not value is Dictionary:
		return {}
	return value


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
