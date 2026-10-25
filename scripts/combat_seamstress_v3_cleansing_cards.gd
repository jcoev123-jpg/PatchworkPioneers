class_name CombatSeamstressV3CleansingCards
extends RefCounted
## Scene-free paid resolver for the Seamstress's v3 Mending Knot and Darn the Tear (V3-1).
##
## Mending Knot is a v3 starter and Darn the Tear a v3 reward-pool card; both print one energy,
## one chosen living ally, `heal` and `cleanse_debuff: 1`. The tall purple patched dress's whole
## look is that she darns one ally's wounds and one torn debuff, so this service authenticates the
## exact held catalog record and then heals up to max HP and removes ONE caller-selected present
## Bleed, Weak or Exposed counter completely. It never invents an automatic cleanse priority.
##
## The catalogs stay authoritative: the caller cannot supply effects, costs or seats. CombatDeck
## and CombatParty own the real state (hand, energy, piles, hero HP/Block and each hero's
## authoritative status dictionary). Nothing here draws, shuffles or otherwise advances the run
## RNG; a refusal is strictly inert.
##
## This is callable rules-layer behaviour only. It does not register these IDs in the live hand,
## rewards, run deck or the app flow; that wiring is a later task.

const OWNER := "seamstress"
const TARGET_KIND := "ally_single"
const CLEANSE_COUNT := 1

## Only these debuffs may be cleansed. Tangled, Riposte and any unrelated entry are never eligible
## and are always left exactly as they were.
const ELIGIBLE_DEBUFFS: Array[String] = ["bleed", "weak", "exposed"]

## The four authentic IDs and the exact catalog line each one must still carry.
## `heal` is the only difference between a base card and its "+".
const CARDS := {
	"seamstress_v3_mending_knot": {
		"catalog": "starter", "cost": 1, "heal": 4, "from_positions": [2, 3],
		"upgrade_id": "seamstress_v3_mending_knot_plus",
	},
	"seamstress_v3_mending_knot_plus": {
		"catalog": "starter", "cost": 1, "heal": 6, "from_positions": [2, 3],
		"upgrade_of": "seamstress_v3_mending_knot",
	},
	"seamstress_v3_darn_the_tear": {
		"catalog": "pool", "cost": 1, "heal": 4, "from_positions": [1, 2, 3],
		"upgrade_id": "seamstress_v3_darn_the_tear_plus",
	},
	"seamstress_v3_darn_the_tear_plus": {
		"catalog": "pool", "cost": 1, "heal": 6, "from_positions": [1, 2, 3],
		"upgrade_of": "seamstress_v3_darn_the_tear",
	},
}


## The single paid transaction: authenticate, preflight every input, then charge the printed cost,
## discard exactly the held copy, heal the chosen ally (capped at max HP) and remove one selected
## present debuff kind. A refusal changes no deck, party or RNG state.
##
## `cleanse_debuff` must name a present positive Bleed/Weak/Exposed counter, or be "" exactly when
## the chosen ally has no positive eligible counter. One named kind loses its entire counter.
func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int = 0, cleanse_debuff: Variant = "") -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, card_id, target_position, cleanse_debuff)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above: the turn is active,
	# the exact held ID is affordable, the owner sits in its authored seat, the chosen ally lives
	# and the selected debuff contract matches the authoritative status dictionary. Keep the
	# defensive returns so an unexpected model change still fails closed.
	if not deck.try_spend_energy(plan["cost"]):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")
	if not party.heal(plan["target_position"], plan["heal"]):
		return _refusal("heal_failed")

	var selection: String = plan["cleanse_debuff"]
	var cleansed_count := 0
	if selection != "":
		# The real selected record, never a detached get_hero copy. The preflight proved the
		# status dictionary is a Dictionary of nonnegative int counters and contains this kind.
		var record: Dictionary = party._heroes[plan["target_position"] - 1]
		var statuses: Dictionary = record.get("statuses", {})
		cleansed_count = int(statuses[selection])
		statuses.erase(selection)
		record["statuses"] = statuses

	var hp_after: int = party.get_hero(plan["target_position"])["hp"]
	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": plan["cost"],
		"owner_position": plan["owner_position"],
		"target_position": plan["target_position"],
		"heal": plan["heal"],
		"healed": hp_after - plan["hp_before"],
		"hp_before": plan["hp_before"],
		"hp_after": hp_after,
		"cleansed_debuff": selection,
		"cleansed_count": cleansed_count,
	}


## True only for the four authentic catalog IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


## Read-only preflight of the whole transaction. Returns a detached plan or a refusal receipt.
func _prepare(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int, cleanse_debuff: Variant) -> Dictionary:
	if deck == null or party == null:
		return _refusal("invalid_request")
	if deck.combat_state == null or deck._rng == null or not deck.turn_active:
		return _refusal("inactive_turn")
	if not party.is_valid() or party._heroes.size() != CombatParty.PARTY_SIZE:
		return _refusal("invalid_party")
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	var card: Dictionary = CARDS.get(id, {})
	if card.is_empty():
		return _refusal("unsupported_card")
	var definition: Dictionary = _catalog_definition(id)
	if not _authentic(definition, id, card):
		return _refusal("catalog_mismatch")
	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = card["cost"]
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	# Verify the complete roster and every hero's authoritative status shape, then bind the
	# owner by hero ID to its actual current slot. Swapping seats grants no false authority.
	var heroes: Array[Dictionary] = party.get_heroes()
	var owner_position := 0
	var seen_ids: Array[String] = []
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
		var statuses_value = hero.get("statuses", {})
		if not statuses_value is Dictionary:
			return _refusal("malformed_statuses")
		for name in statuses_value:
			if not name is String or name.is_empty():
				return _refusal("malformed_statuses")
			var count = statuses_value[name]
			if not count is int or count < 0:
				return _refusal("malformed_statuses")
		seen_ids.append(hero_id)
		if hero_id == OWNER:
			owner_position = index + 1

	if owner_position == 0:
		return _refusal("owner_missing")
	if not card["from_positions"].has(owner_position):
		return _refusal("owner_illegal_position")
	if int(heroes[owner_position - 1]["hp"]) == 0:
		return _refusal("owner_downed")
	# A living recipient in 1-3; healing never revives a torn (0 HP) ally.
	if target_position < 1 or target_position > CombatParty.PARTY_SIZE:
		return _refusal("invalid_target")
	if int(heroes[target_position - 1]["hp"]) == 0:
		return _refusal("target_downed")

	# The chosen ally's live authoritative status record. Present positive Bleed/Weak/Exposed
	# counters require an explicit one-of selection; with none present the empty selection is the
	# only legal request. No automatic first-debuff priority is invented here.
	var statuses: Variant = _statuses_of(party, target_position)
	if not statuses is Dictionary:
		return _refusal("malformed_statuses")
	var present: Array[String] = []
	for debuff: String in ELIGIBLE_DEBUFFS:
		if int(statuses.get(debuff, 0)) > 0:
			present.append(debuff)
	if typeof(cleanse_debuff) != TYPE_STRING:
		return _refusal("invalid_cleanse")
	var selection: String = cleanse_debuff
	if present.is_empty():
		if selection != "":
			return _refusal("cleanse_not_present")
	elif selection.is_empty() or not present.has(selection):
		return _refusal("cleanse_required")

	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": target_position,
		"heal": int(card["heal"]),
		"cleanse_debuff": selection,
		"hp_before": int(heroes[target_position - 1]["hp"]),
	}


## The live status dictionary stored on the real selected hero record, never a detached snapshot.
## A hero with no statuses key carries no active counters; any other non-dictionary value is
## malformed and the transaction refuses rather than coercing it.
func _statuses_of(party: CombatParty, position: int) -> Variant:
	if party == null or party._heroes.size() != CombatParty.PARTY_SIZE:
		return null
	if position < 1 or position > CombatParty.PARTY_SIZE:
		return null
	var record: Dictionary = party._heroes[position - 1]
	if not record.has("statuses"):
		return {}
	return record["statuses"]


## Reads the exact authored record from the catalog that owns this ID (never the other hero
## catalogs) and returns a detached copy, or {} when the ID is not in that catalog.
func _catalog_definition(card_id: String) -> Dictionary:
	var card: Dictionary = CARDS.get(card_id, {})
	var source: Variant = card.get("catalog", "")
	if source == "starter":
		return V3SeamstressStarterCards.new().get_definition(card_id)
	if source == "pool":
		return V3SeamstressPoolCards.new().get_definition(card_id)
	return {}


## The record must still carry exactly the authored base line, so a rewritten catalog (extra
## heal, another effect, a different seat or target) can never be paid for as this effect.
func _authentic(definition: Dictionary, card_id: String, card: Dictionary) -> bool:
	if definition.get("id") != card_id or definition.get("owner") != OWNER:
		return false
	if definition.get("cost") != card["cost"]:
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if definition.get("from_positions") != card["from_positions"]:
		return false
	var to_positions = definition.get("to_positions")
	if not to_positions is Array or not (to_positions as Array).is_empty():
		return false
	if definition.get("effects") != {"heal": card["heal"], "cleanse_debuff": CLEANSE_COUNT}:
		return false
	# The base and "+" records must still point at each other, so a copied or relinked record
	# cannot be paid for under the other printing's ID.
	if card.has("upgrade_id"):
		return definition.get("upgrade_id") == card["upgrade_id"] \
			and not definition.has("upgrade_of")
	return definition.get("upgrade_of") == card["upgrade_of"] \
		and not definition.has("upgrade_id")


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
