class_name CombatLanternMonkPartyCards
extends RefCounted
## Scene-free paid resolver for the Lantern Monk's party-wide Lantern Glow and Vigil Ring (V3-1).
##
## Lantern Glow is a v3 COMMON reward and Vigil Ring a v3 UNCOMMON reward; both print
## `target_kind: "party_all"` with no `to_positions`. Lantern Glow heals every living ally a
## little and removes ONE explicitly chosen present Bleed/Weak/Exposed counter completely from
## each eligible living ally; Vigil Ring heals every living ally and grants each a little Block
## and never cleanses anything. The round robed hero's glowing patchwork lantern is the whole
## look, so the whole party is the recipient and no single hero or enemy slot is selected.
##
## The catalog stays authoritative: the caller cannot supply effects, costs or seats. This
## service authenticates the exact held ID against LanternMonkPoolCards (owner, cost, FROM
## seats, party_all target, the complete effect dictionary and the base/'+' link) before it
## charges anything. CombatDeck and CombatParty own the real state (hand, energy, piles, hero
## HP/Block and each hero's authoritative status dictionary). Nothing here draws, shuffles or
## otherwise advances the run RNG; healing never revives a torn (0 HP) hero.
##
## This is callable rules-layer behaviour only. It does not register these IDs in the live hand,
## rewards, run deck or the app flow, and no view is changed; that wiring is a later task.

const OWNER := "lantern_monk"
const TARGET_KIND := "party_all"
const CLEANSE_COUNT := 1

## Only these debuffs may be cleansed. Tangled, Riposte and any unrelated entry are never
## eligible and are always left exactly as they were.
const ELIGIBLE_DEBUFFS: Array[String] = ["bleed", "weak", "exposed"]

## The four authentic IDs and the exact catalog line each one must still carry.
## `heal_all` is the only difference between a printing and its "+"; Vigil Ring additionally
## prints `block_all` and Lantern Glow prints the one-per-ally cleanse.
const CARDS := {
	"lantern_monk_lantern_glow": {
		"cost": 1, "from_positions": [1, 2, 3], "heal_all": 2,
		"cleanse_one_debuff_each_ally": 1,
		"upgrade_id": "lantern_monk_lantern_glow_plus",
	},
	"lantern_monk_lantern_glow_plus": {
		"cost": 1, "from_positions": [1, 2, 3], "heal_all": 3,
		"cleanse_one_debuff_each_ally": 1,
		"upgrade_of": "lantern_monk_lantern_glow",
	},
	"lantern_monk_vigil_ring": {
		"cost": 2, "from_positions": [2, 3], "heal_all": 4, "block_all": 4,
		"upgrade_id": "lantern_monk_vigil_ring_plus",
	},
	"lantern_monk_vigil_ring_plus": {
		"cost": 2, "from_positions": [2, 3], "heal_all": 6, "block_all": 6,
		"upgrade_of": "lantern_monk_vigil_ring",
	},
}

var _catalog := LanternMonkPoolCards.new()


## The single paid transaction: authenticate, preflight every input, then charge the printed
## cost, discard exactly the held copy and apply the printed party-wide effect to every living
## hero. A refusal changes no deck, party or RNG state.
##
## `target_position` must stay 0: a party-wide card selects no single enemy or ally slot.
## `cleanse_selections` is an optional per-position Dictionary `{position: debuff}`. Every living
## ally carrying at least one positive Bleed/Weak/Exposed counter needs one explicit selection of
## a present kind, exactly like the Seamstress cleansing service; an ally with no eligible counter
## needs no (or an explicitly empty) selection, and nothing here invents a cleanse priority.
## Vigil Ring cleanses nothing, so it accepts only an empty selection map.
func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int = 0, cleanse_selections: Variant = {}) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, card_id, target_position, cleanse_selections)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above: the turn is active,
	# the exact held ID is affordable, the owner sits in its authored seat, the whole roster and
	# every status map are well formed, and every required cleanse selection names a present
	# counter on a living ally. Keep the defensive returns so an unexpected model change still
	# fails closed.
	if not deck.try_spend_energy(int(plan["cost"])):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")

	var heal_all: int = int(plan["heal_all"])
	var block_all: int = int(plan["block_all"])
	var selections: Dictionary = plan["cleanse_selections"]
	var allies: Array[Dictionary] = []
	for position: int in range(1, CombatParty.PARTY_SIZE + 1):
		# The real authoritative record, never a detached get_hero copy.
		var record: Dictionary = party._heroes[position - 1]
		var hp_before: int = int(record["hp"])
		# Torn (0 HP) heroes are not eligible for healing, Block or cleansing and stay exactly
		# as they were: this play never revives anyone.
		if hp_before == 0:
			continue
		party.heal(position, heal_all)
		var hp_after: int = int(record["hp"])
		var block_before: int = int(record["block"])
		if block_all > 0:
			party.gain_block(position, block_all)
		var block_after: int = int(record["block"])
		var cleansed_debuff := ""
		var cleansed_count := 0
		if selections.has(position):
			# The preflight proved this is a present positive eligible counter on this hero.
			var statuses: Dictionary = record.get("statuses", {})
			cleansed_debuff = str(selections[position])
			cleansed_count = int(statuses[cleansed_debuff])
			statuses.erase(cleansed_debuff)
			record["statuses"] = statuses
		allies.append({
			"position": position,
			"id": str(record["id"]),
			"hp_before": hp_before,
			"hp_after": hp_after,
			"healed": hp_after - hp_before,
			"block_before": block_before,
			"block_after": block_after,
			"block_gained": block_after - block_before,
			"cleansed_debuff": cleansed_debuff,
			"cleansed_count": cleansed_count,
		})

	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": int(plan["cost"]),
		"owner_position": int(plan["owner_position"]),
		"target_kind": TARGET_KIND,
		"target_position": 0,
		"heal_all": heal_all,
		"block_all": block_all,
		"energy_before": int(plan["energy_before"]),
		"energy_after": deck.energy,
		"allies": allies,
	}


## True only for the four authentic catalog printings. Pure lookup; nothing is charged or
## mutated and no RNG is touched.
func is_supported_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	if not CARDS.has(id):
		return false
	var card: Dictionary = CARDS[id]
	return _authentic_pair(id, card)


## Read-only preflight of the whole transaction. Returns a detached plan or a refusal receipt.
func _prepare(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int, cleanse_selections: Variant) -> Dictionary:
	if deck == null or party == null:
		return _refusal("invalid_request")
	if deck.combat_state == null or deck._rng == null or not deck.turn_active:
		return _refusal("inactive_turn")
	if not party.is_valid() or party._heroes.size() != CombatParty.PARTY_SIZE:
		return _refusal("invalid_party")
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	if not CARDS.has(id):
		return _refusal("unsupported_card")
	var card: Dictionary = CARDS[id]
	if not _authentic_pair(id, card):
		return _refusal("catalog_mismatch")
	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = int(card["cost"])
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")
	# Both cards are party_all: any selected enemy or ally slot is an invalid request.
	if target_position != 0:
		return _refusal("invalid_target")

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

	var heal_all: int = int(card["heal_all"])
	var block_all: int = int(card.get("block_all", 0))
	if heal_all < 0 or block_all < 0:
		return _refusal("catalog_mismatch")
	# Block gain must be representable on every living recipient before anything is paid.
	if block_all > 0:
		for index in range(CombatParty.PARTY_SIZE):
			var hero: Dictionary = heroes[index]
			if int(hero["hp"]) == 0:
				continue
			if block_all > CombatParty.MAX_INT - int(hero["block"]):
				return _refusal("invalid_party")

	var selections: Dictionary = _cleanse_plan(heroes, card, cleanse_selections)
	if not selections.get("ok", false):
		return _refusal(str(selections.get("reason", "invalid_cleanse")))

	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"heal_all": heal_all,
		"block_all": block_all,
		"cleanse_selections": selections["selections"],
		"energy_before": deck.energy,
	}


## One optional explicit selection per living ally that carries a positive eligible counter.
## Returns `{"ok": true, "selections": {position: debuff}}` or a refusal; it never guesses.
func _cleanse_plan(heroes: Array[Dictionary], card: Dictionary,
		cleanse_selections: Variant) -> Dictionary:
	if not cleanse_selections is Dictionary:
		return _refusal("invalid_cleanse")
	var provided: Dictionary = cleanse_selections
	var selections: Dictionary = {}
	# Vigil Ring prints no cleanse at all, so any explicit selection is an invalid request.
	if not card.has("cleanse_one_debuff_each_ally"):
		if not provided.is_empty():
			return _refusal("invalid_cleanse")
		return {"ok": true, "selections": selections}

	for key in provided:
		if not key is int or key < 1 or key > CombatParty.PARTY_SIZE:
			return _refusal("invalid_cleanse")
		var value = provided[key]
		if not value is String:
			return _refusal("invalid_cleanse")
		var position: int = key
		var hero: Dictionary = heroes[position - 1]
		# Torn heroes are never eligible recipients, so naming one is not a legal selection.
		if int(hero["hp"]) == 0:
			return _refusal("invalid_cleanse")
		var present: Array[String] = _present_debuffs(hero)
		var selection: String = value
		if selection.is_empty():
			# An explicitly empty choice is the same as no selection: legal only when there is
			# nothing eligible to remove.
			if not present.is_empty():
				return _refusal("cleanse_required")
			continue
		if present.is_empty():
			return _refusal("cleanse_not_present")
		if not present.has(selection):
			return _refusal("cleanse_not_present")
		selections[position] = selection

	# Every living ally carrying an eligible counter still needs its explicit choice.
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = heroes[index]
		if int(hero["hp"]) == 0 or selections.has(index + 1):
			continue
		if not _present_debuffs(hero).is_empty():
			return _refusal("cleanse_required")
	return {"ok": true, "selections": selections}


## The positive eligible Bleed/Weak/Exposed kinds on a hero, in the fixed vocabulary order.
func _present_debuffs(hero: Dictionary) -> Array[String]:
	var present: Array[String] = []
	var statuses: Dictionary = hero.get("statuses", {})
	for debuff: String in ELIGIBLE_DEBUFFS:
		if int(statuses.get(debuff, 0)) > 0:
			present.append(debuff)
	return present


## Reads the exact authored record from LanternMonkPoolCards and proves both printings of the
## pair still carry their authored line, so a rewritten catalog (extra effect, another seat,
## target or cost) can never be paid for as this effect.
func _authentic_pair(card_id: String, card: Dictionary) -> bool:
	var definition: Dictionary = _catalog.get_definition(card_id)
	if not _authentic_record(definition, card_id, card):
		return false
	if card.has("upgrade_id"):
		var plus_id: String = str(card["upgrade_id"])
		if not CARDS.has(plus_id):
			return false
		var plus: Dictionary = _catalog.get_definition(plus_id)
		if plus.get("upgrade_of") != card_id or plus.get("upgrade_id") != null:
			return false
		var plus_card: Dictionary = CARDS[plus_id]
		return _authentic_record(plus, plus_id, plus_card)
	var base_id: String = str(card["upgrade_of"])
	if not CARDS.has(base_id):
		return false
	var base: Dictionary = _catalog.get_definition(base_id)
	if base.get("upgrade_id") != card_id or base.get("upgrade_of") != null:
		return false
	var base_card: Dictionary = CARDS[base_id]
	return _authentic_record(base, base_id, base_card)


func _authentic_record(definition: Dictionary, card_id: String, card: Dictionary) -> bool:
	if definition.get("id") != card_id or definition.get("owner") != OWNER:
		return false
	if not definition.get("cost") is int or int(definition.get("cost")) != int(card["cost"]):
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if definition.get("from_positions") != card["from_positions"]:
		return false
	var to_positions = definition.get("to_positions")
	if not to_positions is Array or not (to_positions as Array).is_empty():
		return false
	var expected_effects: Dictionary = {"heal_all": int(card["heal_all"])}
	if card.has("cleanse_one_debuff_each_ally"):
		expected_effects["cleanse_one_debuff_each_ally"] = CLEANSE_COUNT
	if card.has("block_all"):
		expected_effects["block_all"] = int(card["block_all"])
	if definition.get("effects") != expected_effects:
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
