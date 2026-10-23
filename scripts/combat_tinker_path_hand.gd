class_name CombatTinkerPathHand
extends RefCounted
## Battle-scoped bridge from the one selected Tinker Path into the real shared
## CombatDeck. The SAME rules object is exposed for later successful attacks.

var deck: CombatDeck
var party: CombatParty
var rules: CombatTinkerPathRules

var _selected_card: Dictionary = {}
var _active: bool = false


func _init(choice: RunTinkerPathChoice = null, combat_deck: CombatDeck = null,
		combat_party: CombatParty = null) -> void:
	if choice == null or not choice.has_selection() or combat_deck == null or combat_party == null:
		return
	var selection: Dictionary = choice.get_selection()
	var path: Dictionary = choice.get_definition(str(selection.get("path_id", "")))
	if path.is_empty() or selection.get("passive_id") != path.get("passive_id"):
		return
	var card: Dictionary = path.get("card", {})
	if card.is_empty() or selection.get("card_id") != card.get("id"):
		return
	var selected_rules := CombatTinkerPathRules.new(str(path["id"]))
	if not selected_rules.is_valid_path():
		return
	deck = combat_deck
	party = combat_party
	rules = selected_rules
	_selected_card = card.duplicate(true)
	if not is_bound():
		deck = null
		party = null
		rules = null
		_selected_card.clear()


## Both a genuine successful run choice and exactly one conserved Path-card
## occurrence are required. A different Path card may never enter this battle.
func is_bound() -> bool:
	if deck == null or party == null or rules == null or not rules.is_valid_path():
		return false
	if not party.is_valid() or not _valid_roster() or _selected_card.is_empty():
		return false
	var selected_id: String = str(_selected_card.get("id", ""))
	var other_id: String = "tinker_wind_up" if selected_id == "tinker_scope" else "tinker_scope"
	if not ["tinker_scope", "tinker_wind_up"].has(selected_id):
		return false
	var occurrences := 0
	for pile in [deck.draw_pile, deck.hand, deck.discard_pile]:
		if pile.has(other_id):
			return false
		occurrences += pile.count(selected_id)
	return occurrences == 1


func get_rules() -> CombatTinkerPathRules:
	return rules


## This entry point starts the REAL deck turn (reset to 3 and draw five),
## then claims a queued Wind-up credit exactly once, after that reset.
func start_player_turn() -> bool:
	if not is_bound() or _active or deck.turn_active:
		return false
	if not deck.start_turn():
		return false
	# A valid CombatParty cannot refuse its turn reset.
	party.start_player_turn()
	if not rules.start_player_turn():
		return false
	_active = true
	var credit: int = rules.take_next_turn_energy_bonus()
	if credit > 0:
		deck.combat_state.energy += credit
	return true


func end_player_turn() -> bool:
	if not _active or deck == null or not deck.turn_active:
		return false
	if not deck.end_turn():
		return false
	rules.end_player_turn()
	_active = false
	return true


## The caller supplies only the presented card's identity/printed metadata,
## NEVER an effect dictionary or a success flag. Both metadata and the real
## Tinker position are matched against the authoritative selected definition.
func preview_path_card(card_id: String, owner: String, printed_cost: int,
		from_position: int, target_kind: String) -> Dictionary:
	if not is_bound() or not _active or not deck.turn_active:
		return {"ok": false}
	if card_id != _selected_card.get("id") or owner != _selected_card.get("owner") \
			or printed_cost != _selected_card.get("cost") \
			or target_kind != _selected_card.get("target_kind") or target_kind != "none":
		return {"ok": false}
	var tinker: Dictionary = _tinker()
	if tinker.is_empty() or int(tinker["hp"]) <= 0 \
			or int(tinker["position"]) != from_position \
			or not _selected_card["from_positions"].has(from_position) \
			or deck.hand.count(card_id) != 1:
		return {"ok": false}
	var quote: Dictionary = rules.preview(card_id, from_position, int(tinker["hp"]), deck.energy)
	if not quote.get("ok", false) or quote.get("printed_cost") != printed_cost \
			or quote.get("cost", -1) > deck.energy:
		return {"ok": false}
	return quote


## No commit of the rules happens until a held occurrence is discarded and
## its exact projected energy charge has succeeded on the authoritative deck.
func commit_path_card(card_id: String, owner: String, printed_cost: int,
		from_position: int, target_kind: String) -> Dictionary:
	var quote: Dictionary = preview_path_card(card_id, owner, printed_cost,
		from_position, target_kind)
	if not quote.get("ok", false):
		return {"ok": false}
	var tinker: Dictionary = _tinker()
	var energy_before: int = deck.energy
	var hand_index: int = deck.hand.find(card_id)
	var cost: int = int(quote["cost"])
	if not deck.try_spend_energy(cost):
		return {"ok": false}
	if not deck.discard_played(card_id):
		deck.combat_state.energy = energy_before
		return {"ok": false}
	var result: Dictionary = rules.commit_successful(card_id, from_position,
		int(tinker["hp"]), energy_before, true)
	if not result.get("ok", false):
		# Defensive rollback if an external caller disturbed the rule authority.
		deck.discard_pile.pop_back()
		deck.hand.insert(hand_index, card_id)
		deck.combat_state.energy = energy_before
		return {"ok": false}
	return result


func _valid_roster() -> bool:
	var heroes: Array[Dictionary] = party.get_heroes()
	if heroes.size() != 3:
		return false
	var seen: Dictionary = {}
	for hero in heroes:
		var id: String = str(hero.get("id", ""))
		if not ["warden", "seamstress", "tinker"].has(id) or seen.has(id):
			return false
		seen[id] = true
	return seen.size() == 3


func _tinker() -> Dictionary:
	for hero in party.get_heroes():
		if hero.get("id") == "tinker":
			return hero
	return {}
