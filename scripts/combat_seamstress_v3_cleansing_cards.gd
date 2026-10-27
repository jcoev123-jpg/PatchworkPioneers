class_name CombatSeamstressV3CleansingCards
extends RefCounted
## Scene-free paid resolver for the Seamstress's v3 cleansing cards (V3-1).
##
## Two deliberately separate APIs share this service:
##
## * `play_card` / `is_supported_card` resolve the two one-ally printings only: Mending Knot (v3
##   starter) and Darn the Tear (v3 reward pool). Both print one energy, one chosen living ally,
##   `heal` and `cleanse_debuff: 1`. The tall purple patched dress's whole look is that she darns
##   one ally's wounds and one torn debuff, so the service authenticates the exact held catalog
##   record and then heals up to max HP and removes ONE caller-selected present Bleed, Weak or
##   Exposed counter completely. It never invents an automatic cleanse priority.
## * `play_party_card` / `is_supported_party_card` resolve the whole-party Midnight Loom and
##   Midnight Loom+ printings only. Each cast prints three energy, heals and Blocks EVERY living
##   member of the real three-hero CombatParty and removes one caller-selected present Bleed, Weak
##   or Exposed counter per living hero. A torn (0 HP) seat is left entirely unchanged: no revive,
##   no Block, no cleanse. Nothing is auto-picked per seat; the caller names one present kind for
##   every living hero that carries a positive eligible debuff. The two APIs never accept each
##   other's IDs.
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

## The two whole-party printings, with the exact catalog line each one must still carry. They are
## a separate table so neither API can authenticate the other's cards: `play_card` stays a
## one-ally resolver and `play_party_card` stays a party_all resolver.
const PARTY_TARGET_KIND := "party_all"

const PARTY_CARDS := {
	"seamstress_v3_midnight_loom": {
		"catalog": "pool", "cost": 3, "heal": 4, "block": 4, "from_positions": [2, 3],
		"rarity": "rare", "reward_eligible": true,
		"upgrade_id": "seamstress_v3_midnight_loom_plus",
	},
	"seamstress_v3_midnight_loom_plus": {
		"catalog": "pool", "cost": 3, "heal": 6, "block": 6, "from_positions": [2, 3],
		"rarity": "rare", "reward_eligible": false,
		"upgrade_of": "seamstress_v3_midnight_loom",
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


## True only for the two authentic whole-party Midnight Loom printings. Pure lookup; nothing is
## charged or mutated, and the one-ally IDs are never reported as supported here.
func is_supported_party_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and PARTY_CARDS.has(card_id)


## The single paid party-wide transaction: authenticate, preflight every input, then charge the
## printed three energy, discard exactly the held copy and apply the printed heal (capped at each
## living hero's max HP), printed Block and per-seat selected cleanse to every LIVING member of the
## real CombatParty. A torn hero is left entirely alone: no revive, no Block, no cleanse.
##
## `selections` is a per-living-position dictionary keyed by the real party position 1-3. A living
## hero that carries a positive Bleed, Weak or Exposed counter needs exactly one present kind named
## there; a living hero with none uses "" (or omits the entry). A downed seat may not carry an entry
## at all. One named kind loses its entire counter; every unchosen status stays exactly as it was.
## A refusal changes no deck, party or RNG state; no run RNG is ever drawn here.
func play_party_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
		selections: Variant = {}) -> Dictionary:
	var plan: Dictionary = _prepare_party(deck, party, card_id, selections)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# The complete preflight above proved the turn is active, the exact held ID is affordable, the
	# unique living owner sits in an authored seat, every seat's status map and selection is legal
	# and no living hero's Block can overflow. The defensive returns still fail closed.
	if not deck.try_spend_energy(plan["cost"]):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")

	var seats: Array[Dictionary] = []
	var total_healed := 0
	var total_cleansed := 0
	for seat: Dictionary in plan["seats"]:
		var position: int = seat["position"]
		# CombatParty owns Block, HP and the authoritative status dictionary; ask it directly and
		# never build a parallel party, energy bank or record.
		if not party.gain_block(position, plan["block"]):
			return _refusal("block_failed")
		if not party.heal(position, plan["heal"]):
			return _refusal("heal_failed")
		var cleansed_kind: String = seat["cleanse_debuff"]
		var cleansed_count := 0
		if cleansed_kind != "":
			# The real selected record, never a detached get_hero copy. The preflight proved the
			# status dictionary is a Dictionary of nonnegative int counters holding this kind.
			var record: Dictionary = party._heroes[position - 1]
			var statuses: Dictionary = record.get("statuses", {})
			cleansed_count = int(statuses[cleansed_kind])
			statuses.erase(cleansed_kind)
			record["statuses"] = statuses
		var hero: Dictionary = party.get_hero(position)
		var healed: int = int(hero["hp"]) - int(seat["hp_before"])
		total_healed += healed
		total_cleansed += cleansed_count
		# Detached receipt data: plain dictionaries of plain values, no model records.
		seats.append({
			"position": position,
			"hp_before": int(seat["hp_before"]),
			"hp_after": int(hero["hp"]),
			"healed": healed,
			"block_before": int(seat["block_before"]),
			"block_after": int(hero["block"]),
			"block_gained": int(hero["block"]) - int(seat["block_before"]),
			"cleansed_debuff": cleansed_kind,
			"cleansed_count": cleansed_count,
		})

	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": plan["cost"],
		"owner_position": plan["owner_position"],
		"heal": plan["heal"],
		"block": plan["block"],
		"healed": total_healed,
		"cleansed_count": total_cleansed,
		"seats": seats,
	}


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


## Read-only preflight of the whole party-wide transaction. Returns a detached plan (one entry per
## LIVING seat) or a refusal receipt; nothing here writes a hero, the deck or the RNG.
func _prepare_party(deck: CombatDeck, party: CombatParty, card_id: Variant,
		selections: Variant) -> Dictionary:
	if deck == null or party == null:
		return _refusal("invalid_request")
	if deck.combat_state == null or deck._rng == null or not deck.turn_active:
		return _refusal("inactive_turn")
	if not party.is_valid() or party._heroes.size() != CombatParty.PARTY_SIZE:
		return _refusal("invalid_party")
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	var card: Dictionary = PARTY_CARDS.get(id, {})
	if card.is_empty():
		return _refusal("unsupported_card")
	var definition: Dictionary = _catalog_definition(id)
	if not _authentic_party(definition, id, card):
		return _refusal("catalog_mismatch")
	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = card["cost"]
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	# The selection dictionary itself must be a Dictionary of real party positions only. A string
	# key such as "2", a bool, a fractional number or a seat outside 1-3 is never coerced.
	if not selections is Dictionary:
		return _refusal("invalid_selections")
	var chosen: Dictionary = selections
	for key in chosen:
		if typeof(key) != TYPE_INT or int(key) < 1 or int(key) > CombatParty.PARTY_SIZE:
			return _refusal("invalid_selections")

	# Verify the complete roster and every hero's authoritative status shape, then bind the owner
	# by hero ID to its actual current slot. Swapping seats grants no false authority, and the
	# duplicate-ID check guarantees the owner is unique.
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

	# Per living seat: the selected cleanse and the Block capacity that the real gain_block would
	# accept. A torn seat is excluded entirely, so nothing can revive it, Block it or clean it.
	var seats: Array[Dictionary] = []
	for index in range(CombatParty.PARTY_SIZE):
		var seat_position := index + 1
		var hero: Dictionary = heroes[index]
		var has_entry: bool = chosen.has(seat_position)
		if int(hero["hp"]) == 0:
			if has_entry:
				return _refusal("invalid_selections")
			continue
		var raw: Variant = chosen.get(seat_position, "")
		if typeof(raw) != TYPE_STRING:
			return _refusal("invalid_selections")
		var selection: String = raw
		var statuses: Variant = hero.get("statuses", {})
		if not statuses is Dictionary:
			return _refusal("malformed_statuses")
		var present: Array[String] = []
		for debuff: String in ELIGIBLE_DEBUFFS:
			if int(statuses.get(debuff, 0)) > 0:
				present.append(debuff)
		# No automatic first-debuff priority: a living hero with a present counter needs one
		# explicit present kind, and a hero with none needs the empty selection.
		if present.is_empty():
			if selection != "":
				return _refusal("cleanse_not_present")
		elif selection.is_empty() or not present.has(selection):
			return _refusal("cleanse_required")
		# CombatParty.MAX_INT is the same ceiling gain_block itself enforces.
		if int(hero["block"]) > CombatParty.MAX_INT - int(card["block"]):
			return _refusal("block_overflow")
		seats.append({
			"position": seat_position,
			"hp_before": int(hero["hp"]),
			"block_before": int(hero["block"]),
			"cleanse_debuff": selection,
		})
	# A party with no living hero left cannot receive the card at all.
	if seats.is_empty():
		return _refusal("invalid_party")

	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"heal": int(card["heal"]),
		"block": int(card["block"]),
		"seats": seats,
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
	var card: Dictionary = CARDS.get(card_id, PARTY_CARDS.get(card_id, {}))
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


## The whole-party record must still carry exactly the authored Midnight Loom line: the same owner,
## three energy, the party_all target with no enemy TO slots, heal, Block and one cleanse, the same
## rarity and reward eligibility and the base/'+' link. A caller-supplied cost or effect never
## reaches this comparison.
func _authentic_party(definition: Dictionary, card_id: String, card: Dictionary) -> bool:
	if definition.get("id") != card_id or definition.get("owner") != OWNER:
		return false
	if definition.get("cost") != card["cost"]:
		return false
	if definition.get("target_kind") != PARTY_TARGET_KIND:
		return false
	if definition.get("from_positions") != card["from_positions"]:
		return false
	var to_positions = definition.get("to_positions")
	if not to_positions is Array or not (to_positions as Array).is_empty():
		return false
	var expected_effects := {
		"heal": card["heal"], "block": card["block"], "cleanse_debuff": CLEANSE_COUNT,
	}
	if definition.get("effects") != expected_effects:
		return false
	if definition.get("rarity") != card["rarity"]:
		return false
	if definition.get("reward_eligible") != card["reward_eligible"]:
		return false
	if definition.get("starting_copies") != 0:
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
