extends Control
## Root of the game. The hand view delegates all card movement to CombatDeck.

signal start_run_requested

const TITLE := "Patchwork Pioneers"
const STARTER_DECK_PATH := "res://data/cards/starter_deck.json"
const STARTER_PARTY_PATH := "res://data/heroes/starter_party.json"
const STARTER_ATTACKS_PATH := "res://data/encounters/starter_attacks.json"
const STARTER_ENEMIES_PATH := "res://data/enemies/starter_enemies.json"
const RUN_ENEMIES_PATH := "res://data/enemies/run_enemies.json"
const FIGHT_ROSTERS := {
	"starter_attacks": ["ragling", "ragling_guard"],
	"guard_counterattack": ["button_guard", "fray_scavenger"],
	"ragling_rearline_feint": ["spool_stalker", "seam_ripper"],
}
const FIGHT_ENCOUNTER_PATHS := {
	"starter_attacks": STARTER_ATTACKS_PATH,
	"guard_counterattack": "res://data/encounters/guard_counterattack.json",
	"ragling_rearline_feint": "res://data/encounters/ragling_rearline_feint.json",
}

@export var run_seed: int = 42
@export_file("*.json") var starter_deck_path: String = STARTER_DECK_PATH
@export_file("*.json") var starter_party_path: String = STARTER_PARTY_PATH
@export_file("*.json") var starter_attacks_path: String = STARTER_ATTACKS_PATH
@export_file("*.json") var starter_enemies_path: String = STARTER_ENEMIES_PATH

var title_label: Label
var start_button: Button
var route_button: Button
var route_view: VBoxContainer
var route_back_button: Button
var route_buttons: Array[Button] = []
var run_map: RunMap
var fight_encounter_paths: Dictionary = FIGHT_ENCOUNTER_PATHS.duplicate()
var fight_rosters: Dictionary = FIGHT_ROSTERS.duplicate(true)
var run_enemies_path: String = RUN_ENEMIES_PATH
var fight_selection: RunFightEncounterSelection
var encounter_id := ""
var title_view: VBoxContainer
var battle_view: MarginContainer
var hand_view: HBoxContainer
var pile_label: Label
var end_turn_button: Button
var return_button: Button
var deck: CombatDeck
var run_rng: RandomNumberGenerator
var party: CombatParty
var enemies: CombatEnemies
var hero_view: HBoxContainer
var hero_panels: Array[PanelContainer] = []
var enemy_attacks: Array = []
var enemy_intents: CombatEnemyIntents
var intent_label: Label
var enemy_buff_forecast_label: Label
var battle_result: CombatBattleResult
var round_flow: CombatRoundFlow
var victory_gold: RunVictoryGold
var session_gold := 0
var run_deck: Array[String] = []
var run_heroes: Array = []
var continue_button: Button
var rest_view: VBoxContainer
var rest_heal_button: Button
var rest_back_button: Button
var rest_hp_label: Label
var rest_recovery: RunRestRecovery
var _rest_route: Array[String] = []
var _rest_heroes: Array = []
var _rest_map: WeakRef
var shop_view: VBoxContainer
var shop_cards: OptionButton
var shop_remove_button: Button
var shop_back_button: Button
var shop_continue_button: Button
var shop_label: Label
var shop_visit: RunShopVisit
var shop_purchases: RunShopPurchases
var shop_offers: OptionButton
var shop_buy_button: Button
var run_removal_count := 0
var _shop_map: WeakRef
var _shop_route: Array[String] = []
var _connected_map: WeakRef
var _connected_route: Array[String] = []
var card_reward: RunCardRewardChoice
var fight_rewards: RunFightVictoryRewards
var fight_reward_offers: Array = []
var fight_reward_gold := 0
var fight_reward_claimed := false
var _reward_map: WeakRef
var reward_buttons: Array[Button] = []
const INTERIM_REWARD_IDS := ["warden_strike", "seamstress_prick", "tinker_pop_shot"]
var result_label: Label
var _battle_closed := false
var swap_preview_buttons: Array[Button] = []
var swap_preview_cue: Label
var _swap_preview_pair := 0


func _ready() -> void:
	_build_title()
	start_run_requested.connect(_start_run)
	var attack_preview := Node.new()
	attack_preview.name = "LiveAttackPreview"
	attack_preview.set_script(preload("res://scripts/live_attack_preview.gd"))
	add_child(attack_preview)


func _process(_delta: float) -> void:
	_observe_battle_result()
	if is_instance_valid(battle_view) and battle_view.is_visible_in_tree():
		_refresh_intents()
		_refresh_swap_preview()


## Single observation boundary for live updates and resolved phases.
func _observe_battle_result() -> bool:
	if battle_result == null:
		return false
	var outcome := battle_result.evaluate()
	if outcome == CombatBattleResult.ACTIVE:
		return true
	if is_instance_valid(enemy_buff_forecast_label):
		enemy_buff_forecast_label.text = ""
		enemy_buff_forecast_label.hide()
	if not _battle_closed:
		_battle_closed = true
		if outcome == CombatBattleResult.VICTORY:
			if run_map == null:
				session_gold = victory_gold.claim_gold(false, run_rng)
			if run_map != null:
				run_heroes = party.get_heroes()
		# Enemy phases have already ended the turn; external/card damage may not have.
		if deck.turn_active:
			deck.end_turn()
		$LiveSupportHand._cancel_pending()
		_refresh_hand()
		if outcome == CombatBattleResult.VICTORY:
			_build_card_reward()
		if party.is_valid():
			_refresh_party()
		_refresh_enemy_roster()
		end_turn_button.disabled = true
		result_label.text = "Battle result: " + outcome
		if outcome == CombatBattleResult.VICTORY:
			result_label.text += " | Pending gold: %d" % fight_reward_gold if run_map != null else " | Gold: %d" % session_gold
		result_label.show()
		return_button.grab_focus()
	return false


func _build_title() -> void:
	var bg := ColorRect.new()
	bg.color = Color("2b3135")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	title_view = box
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 32)
	add_child(box)

	title_label = Label.new()
	title_label.text = TITLE
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_color_override("font_color", Color("ece0c8"))
	title_label.add_theme_constant_override("outline_size", 12)
	title_label.add_theme_color_override("font_outline_color", Color("1a1d20"))
	box.add_child(title_label)

	start_button = Button.new()
	start_button.text = "Start run"
	start_button.custom_minimum_size = Vector2(240, 56)
	start_button.add_theme_font_size_override("font_size", 28)
	start_button.pressed.connect(func(): start_run_requested.emit())
	box.add_child(start_button)
	route_button = Button.new()
	route_button.text = "Choose a route"
	route_button.custom_minimum_size = Vector2(240, 56)
	route_button.pressed.connect(_open_route)
	box.add_child(route_button)
	start_button.focus_next = start_button.get_path_to(route_button)
	route_button.focus_next = route_button.get_path_to(start_button)
	start_button.focus_previous = start_button.focus_next
	route_button.focus_previous = route_button.focus_next
	start_button.grab_focus.call_deferred()
	box.position -= box.get_combined_minimum_size() / 2.0


func _start_run() -> void:
	if deck != null or run_map != null:
		return
	_start_battle()


func _open_route() -> void:
	if deck != null or run_map != null:
		return
	run_rng = RandomNumberGenerator.new()
	run_rng.seed = run_seed
	run_map = RunMap.new()
	run_map.generate(run_rng)
	fight_selection = RunFightEncounterSelection.new()
	title_view.hide()
	route_view = VBoxContainer.new()
	route_view.set_anchors_preset(Control.PRESET_CENTER)
	route_view.add_theme_constant_override("separation", 16)
	add_child(route_view)
	var heading := Label.new()
	heading.text = "Opening route - choose a Fight"
	route_view.add_child(heading)
	var actions: Array[Button] = []
	for id in run_map.get_legal_choices():
		var node := run_map.get_node(id)
		var button := Button.new()
		button.text = "%s: %s" % [id, node.type]
		button.set_meta("route_id", id)
		button.disabled = node.type != "Fight"
		if button.disabled:
			button.text += " (unavailable)"
		button.custom_minimum_size = Vector2(340, 48)
		button.pressed.connect(_choose_route.bind(id, weakref(run_map)))
		route_view.add_child(button)
		route_buttons.append(button)
		if not button.disabled:
			actions.append(button)
	route_back_button = Button.new()
	route_back_button.text = "Back"
	route_back_button.pressed.connect(_cancel_route)
	route_view.add_child(route_back_button)
	actions.append(route_back_button)
	for index in range(actions.size()):
		actions[index].focus_next = actions[index].get_path_to(actions[(index + 1) % actions.size()])
		actions[index].focus_previous = actions[index].get_path_to(actions[(index - 1 + actions.size()) % actions.size()])
	route_view.position -= route_view.get_combined_minimum_size() / 2.0
	actions[0].grab_focus()


func _choose_route(id: String, source_map: WeakRef = null) -> bool:
	if deck != null or run_map == null or not is_instance_valid(route_view) \
			or not route_view.is_visible_in_tree() or not run_map.get_route().is_empty():
		return false
	if source_map != null and source_map.get_ref() != run_map:
		return false
	if not run_map.get_legal_choices().has(id) or run_map.get_node(id).get("type") != "Fight":
		return false
	if run_rng == null or fight_selection == null:
		return false
	var rng_before := run_rng.state
	var route_before := run_map.get_route()
	if not run_map.choose_node(id):
		return false
	var selected := fight_selection.select_current_battle(run_map, run_rng, {"Fight": fight_encounter_paths})
	var assembled := RunTypedBattleRoster.new().assemble(selected, fight_rosters,
		[starter_enemies_path, run_enemies_path])
	if not assembled.get("ok", false) or not _start_battle(run_rng,
			assembled.get("definitions", []), assembled.get("enemies")):
		run_map.undo_choice(id, route_before)
		run_rng.state = rng_before
		fight_selection = RunFightEncounterSelection.new()
		encounter_id = ""
		return false
	encounter_id = selected.encounter_id
	_clear_route_view()
	return true


func _clear_route_view() -> void:
	if is_instance_valid(route_view):
		remove_child(route_view)
		route_view.queue_free()
	route_view = null
	route_back_button = null
	route_buttons.clear()


func _cancel_route() -> void:
	if deck != null or route_view == null:
		return
	_clear_route_view()
	run_map = null
	run_rng = null
	fight_selection = null
	encounter_id = ""
	title_view.show()
	route_button.grab_focus()


func _start_battle(shared_rng: RandomNumberGenerator = null, encounter_definitions: Array = [],
		selected_enemies: CombatEnemies = null) -> bool:
	var cards := _load_starter_deck()
	if cards.is_empty():
		push_warning("Starter deck is invalid or unreadable; run was not started")
		return false
	var selector := CombatEnemyIntents.new(_load_enemy_schedule())
	if not selector.is_valid():
		return false
	if shared_rng != null:
		selector = CombatEnemyIntents.new(encounter_definitions)
	var starting_enemies := CombatEnemies.new(_load_enemy_definitions())
	if not starting_enemies.is_valid():
		return false
	if shared_rng != null:
		if selected_enemies == null:
			return false
		starting_enemies = selected_enemies
	if not selector.is_valid() or not starting_enemies.is_valid() or not _positions_align(selector, starting_enemies):
		push_warning("Starter enemies or schedule are invalid; run was not started")
		return false
	var definitions := _load_party_definitions()
	var starting_party := CombatParty.new(definitions)
	if not starting_party.is_valid():
		push_warning("Starter party definitions are invalid; run was not started")
		return false
	var starting_rng := shared_rng
	if starting_rng == null:
		starting_rng = RandomNumberGenerator.new()
		starting_rng.seed = run_seed
	# An empty deck performs no shuffle. Validate the current binding contract first.
	var starting_deck := CombatDeck.new([], starting_rng)
	var starting_result := CombatBattleResult.new(starting_party, starting_enemies)
	var starting_flow := CombatRoundFlow.new(starting_deck, starting_party,
		starting_enemies, selector, starting_result)
	if not starting_flow._valid_bindings():
		push_warning("Starter combat bindings are invalid; run was not started")
		return false
	var rng_before := starting_rng.state
	starting_deck.draw_pile.assign(cards)
	starting_deck._shuffle_draw_pile()
	if not starting_flow.begin_fight():
		starting_rng.state = rng_before
		push_warning("Starter combat bindings are invalid; run was not started")
		return false
	enemy_intents = selector
	enemy_attacks = enemy_intents.get_intents()
	party = starting_party
	enemies = starting_enemies
	run_rng = starting_rng
	deck = starting_deck
	run_deck = cards.duplicate()
	battle_result = starting_result
	round_flow = starting_flow
	victory_gold = RunVictoryGold.new(battle_result)
	session_gold = 0
	_battle_closed = false
	title_view.hide()
	_build_battle()
	_refresh_hand()
	_refresh_party()
	_refresh_enemy_roster()
	end_turn_button.grab_focus()
	return true


## Validate before allocating session objects; keep authored order for the seeded shuffle.
func _load_starter_deck() -> Array[String]:
	var file := FileAccess.open(starter_deck_path, FileAccess.READ)
	if file == null:
		return []
	var text := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK:
		return []
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Array:
		return []
	var expected := {}
	for card in StarterCards.new().get_starting_deck():
		expected[card] = expected.get(card, 0) + 1
	var actual := {}
	var cards: Array[String] = []
	for card in parser.data:
		if not card is String:
			return []
		actual[card] = actual.get(card, 0) + 1
		cards.append(card)
	if actual != expected:
		return []
	return cards


func _load_party_definitions() -> Array:
	if not FileAccess.file_exists(starter_party_path):
		return []
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(starter_party_path)) != OK:
		return []
	var source = parser.data
	if not source is Array:
		return []
	for definition in source:
		if not definition is Dictionary:
			return []
		var max_hp = definition.get("max_hp")
		# JSON numbers decode as floats; reject fractions before converting for CombatParty.
		if not (max_hp is float or max_hp is int):
			return []
		if not is_finite(float(max_hp)) or max_hp <= 0 or max_hp >= float(CombatParty.MAX_INT):
			return []
		if floor(float(max_hp)) != float(max_hp):
			return []
		for field in ["name", "art_path"]:
			if not definition.get(field) is String or definition[field].is_empty():
				return []
		definition["max_hp"] = int(max_hp)
	return source


func _load_enemy_definitions() -> Array:
	if not FileAccess.file_exists(starter_enemies_path):
		return []
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(starter_enemies_path)) != OK:
		return []
	var source = parser.data
	if not source is Array:
		return []
	for definition in source:
		if not definition is Dictionary or not _normalize_schedule_number(definition, "max_hp"):
			return []
		for field in ["name", "art_path"]:
			if not definition.get(field) is String or definition[field].is_empty():
				return []
	return source


func _positions_align(selector: CombatEnemyIntents, roster: CombatEnemies) -> bool:
	var intents := selector.get_intents()
	if intents.size() != roster.get_enemies().size():
		return false
	for index in range(intents.size()):
		if intents[index].enemy_position != index + 1:
			return false
	return true


func _load_enemy_schedule() -> Array:
	if not FileAccess.file_exists(starter_attacks_path):
		return []
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(starter_attacks_path)) != OK:
		return []
	var source = parser.data
	if not source is Array or source.is_empty():
		return []
	for definition in source:
		if not definition is Dictionary or not _normalize_schedule_number(definition, "enemy_position"):
			return []
		var pattern = definition.get("pattern")
		if not pattern is Array or pattern.is_empty():
			return []
		for action in pattern:
			if not action is Dictionary:
				return []
			var kind = action.get("type")
			if not kind is String or kind not in ["attack", "block", "buff", "debuff", "shove"]:
				return []
			if not _normalize_schedule_number(action, "amount"):
				return []
			if kind in ["attack", "shove", "debuff"] and not _normalize_schedule_number(action, "target_position"):
				return []
			if kind == "shove" and not _normalize_schedule_number(action, "direction", -1):
				return []
	# CombatEnemyIntents validates exact keys, ranges and duplicate source positions.
	return source


func _normalize_schedule_number(record: Dictionary, field: String, minimum: int = 0) -> bool:
	var value = record.get(field)
	if not (value is int or value is float):
		return false
	if not is_finite(float(value)) or floor(float(value)) != float(value):
		return false
	if value < minimum or value >= float(CombatParty.MAX_INT):
		return false
	record[field] = int(value)
	return true


func _build_battle() -> void:
	battle_view = MarginContainer.new()
	battle_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		battle_view.add_theme_constant_override("margin_" + side, 32)
	add_child(battle_view)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	battle_view.add_child(column)
	hero_view = HBoxContainer.new()
	hero_view.add_theme_constant_override("separation", 16)
	column.add_child(hero_view)
	for index in range(CombatParty.PARTY_SIZE):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 100)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hero_view.add_child(panel)
		hero_panels.append(panel)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		panel.add_child(label)
	intent_label = Label.new()
	intent_label.add_theme_font_size_override("font_size", 22)
	intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var intent_column := VBoxContainer.new()
	intent_column.add_theme_constant_override("separation", 4)
	column.add_child(intent_column)
	intent_column.add_child(intent_label)
	enemy_buff_forecast_label = Label.new()
	enemy_buff_forecast_label.name = "EnemyBuffForecast"
	enemy_buff_forecast_label.add_theme_font_size_override("font_size", 18)
	enemy_buff_forecast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intent_column.add_child(enemy_buff_forecast_label)
	_refresh_intents()
	result_label = Label.new()
	result_label.name = "BattleResult"
	result_label.add_theme_font_size_override("font_size", 28)
	result_label.hide()
	column.add_child(result_label)
	var previews := HBoxContainer.new()
	previews.add_theme_constant_override("separation", 16)
	column.add_child(previews)
	var heading := Label.new()
	heading.text = "Shared hand"
	heading.add_theme_font_size_override("font_size", 32)
	previews.add_child(heading)
	for pair in [1, 2]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(240, 40)
		previews.add_child(button)
		swap_preview_buttons.append(button)
		button.pressed.connect(_preview_position_swap.bind(pair, button))
	var counts_and_preview := HBoxContainer.new()
	counts_and_preview.add_theme_constant_override("separation", 24)
	column.add_child(counts_and_preview)
	pile_label = Label.new()
	counts_and_preview.add_child(pile_label)
	swap_preview_cue = Label.new()
	swap_preview_cue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swap_preview_cue.add_theme_font_size_override("font_size", 18)
	swap_preview_cue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	counts_and_preview.add_child(swap_preview_cue)
	hand_view = HBoxContainer.new()
	hand_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_view.add_theme_constant_override("separation", 16)
	column.add_child(hand_view)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 24)
	column.add_child(actions)
	end_turn_button = Button.new()
	end_turn_button.text = "End Turn"
	end_turn_button.custom_minimum_size = Vector2(240, 56)
	end_turn_button.pressed.connect(_end_turn.bind(end_turn_button))
	actions.add_child(end_turn_button)
	return_button = Button.new()
	return_button.text = "Return to title"
	return_button.custom_minimum_size = Vector2(240, 56)
	return_button.pressed.connect(_return_to_title)
	actions.add_child(return_button)
	_refresh_swap_preview()


## Presentation only: never install the copied proposal into the live party.
func _swap_preview_active() -> bool:
	return is_instance_valid(battle_view) and battle_view.is_visible_in_tree() \
		and not _battle_closed and deck != null and deck.turn_active \
		and party != null and party.is_valid() and not party.is_defeated() \
		and enemies != null and enemies.is_valid() and not enemies.is_victorious() \
		and battle_result != null and battle_result._party == party \
		and battle_result._enemies == enemies and battle_result.can_continue()


func _preview_position_swap(pair: int, button) -> void:
	if pair not in [1, 2] or not is_instance_valid(button) \
			or swap_preview_buttons.size() != 2 or button != swap_preview_buttons[pair - 1] \
			or not button.is_visible_in_tree():
		return
	_swap_preview_pair = pair
	_refresh_swap_preview()


func _refresh_swap_preview() -> void:
	if not is_instance_valid(swap_preview_cue):
		return
	var active := _swap_preview_active()
	var selected := {"ok": false, "heroes": []}
	var actions: Array[Button] = []
	if not end_turn_button.disabled:
		actions.append(end_turn_button)
	actions.append(return_button)
	for button in reward_buttons:
		if is_instance_valid(button) and not button.disabled:
			actions.append(button)
	if is_instance_valid(continue_button) and not continue_button.disabled:
		actions.append(continue_button)
	for index in range(swap_preview_buttons.size()):
		var pair := index + 1
		var proposal := CombatPositionSwaps.preview_adjacent_swap(party, pair, 1)
		var button := swap_preview_buttons[index]
		button.disabled = not active or not proposal.ok
		button.text = "Preview swap %d / %d%s" % [pair, pair + 1,
			" (unavailable)" if button.disabled else ""]
		if not button.disabled:
			actions.append(button)
		if pair == _swap_preview_pair and active:
			selected = proposal
	for index in range(actions.size()):
		actions[index].focus_next = actions[index].get_path_to(actions[(index + 1) % actions.size()])
		actions[index].focus_previous = actions[index].get_path_to(actions[(index - 1 + actions.size()) % actions.size()])
	if not active:
		swap_preview_cue.text = "Swap preview unavailable: battle inactive or invalid."
	elif _swap_preview_pair == 0:
		swap_preview_cue.text = "Preview only: choose adjacent living heroes. No movement or cost."
	elif not selected.ok:
		swap_preview_cue.text = "Swap preview unavailable: both heroes must be living."
	else:
		var positions: PackedStringArray = []
		for hero in selected.heroes:
			positions.append("%d: %s" % [hero.position, hero.get("name", hero.id)])
		swap_preview_cue.text = "Preview only: " + " | ".join(positions) + " (no movement or cost)"


## Routed rewards are prepared once; the standalone demo keeps its fixed offering.
func _build_card_reward() -> void:
	if not _battle_closed or battle_result == null or battle_result.get_outcome() != CombatBattleResult.VICTORY:
		return
	if run_map != null and fight_rewards != null:
		return
	var offers: Array = []
	var party_ids: Array[String] = []
	for hero in party.get_heroes():
		party_ids.append(hero.id)
	var catalog := StarterCards.new()
	var ids: Array = INTERIM_REWARD_IDS
	if run_map != null:
		fight_rewards = RunFightVictoryRewards.new(battle_result, run_rng, party_ids,
			catalog.get_all_card_ids(), run_deck, session_gold, false)
		var prepared := fight_rewards.prepare()
		if not prepared.ok:
			return
		fight_reward_offers = prepared.offers
		fight_reward_gold = prepared.gold_award
		_reward_map = weakref(run_map)
		ids = []
		for offer in fight_reward_offers:
			ids.append(offer.id)
	for id in ids:
		var definition := catalog.get_definition(id)
		if definition.get("id") != id or not party_ids.has(definition.get("owner")):
			return
		offers.append(definition)
	if run_map == null:
		card_reward = RunCardRewardChoice.new(offers, party_ids)
		if not card_reward.is_valid():
			card_reward = null
			return
	var column := HBoxContainer.new()
	column.name = "CardReward"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_view.add_child(column)
	var heading := Label.new()
	heading.text = "Card reward:"
	column.add_child(heading)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 16)
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(choices)
	for index in range(4):
		var id: String = ids[index] if index < 3 else ""
		var button := Button.new()
		button.text = "Skip"
		if not id.is_empty():
			var definition := catalog.get_definition(id)
			button.text = "%s - %s" % [definition.owner.capitalize(), definition.display_name]
			if run_map != null:
				button.text = "%s\n%s" % [definition.owner, id]
		button.custom_minimum_size = Vector2(0, 36)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choices.add_child(button)
		reward_buttons.append(button)
		button.pressed.connect(_claim_card_reward.bind(id, button, fight_rewards if run_map != null else card_reward))


func _claim_card_reward(id: String, button, offering) -> void:
	if offering is RunFightVictoryRewards:
		if offering != fight_rewards or fight_reward_claimed or _reward_map == null \
			or _reward_map.get_ref() != run_map or run_map == null or not _battle_closed \
			or battle_result == null or battle_result._party != party or battle_result._enemies != enemies \
			or battle_result.get_outcome() != CombatBattleResult.VICTORY \
			or party == null or not party.is_valid() or party.is_defeated() \
			or not is_instance_valid(button) or button not in reward_buttons \
			or button.disabled or not button.is_visible_in_tree():
			return
		var index := reward_buttons.find(button)
		if fight_reward_offers.size() != 3 or index > 3 \
			or id != (fight_reward_offers[index].id if index < 3 else ""):
			return
		var result: Dictionary = offering.choose(id)
		if not result.ok:
			return
		run_deck.assign(result.deck)
		session_gold = result.gold
		fight_reward_claimed = true
		result_label.text = "Battle result: victory | Gold: %d" % session_gold
		_finish_card_reward(offering)
		return
	if offering == null or offering != card_reward or not _battle_closed \
			or battle_result == null or battle_result.get_outcome() != CombatBattleResult.VICTORY \
			or not is_instance_valid(button) or button not in reward_buttons \
			or button.disabled or not button.is_visible_in_tree():
		return
	var index := reward_buttons.find(button)
	if id != (INTERIM_REWARD_IDS[index] if index < 3 else ""):
		return
	# Revalidate actual catalog ownership, beyond the transaction's structural checks.
	var party_ids: Array[String] = []
	for hero in party.get_heroes():
		party_ids.append(hero.id)
	var catalog := StarterCards.new()
	for offered_id in INTERIM_REWARD_IDS:
		var definition := catalog.get_definition(offered_id)
		if definition.get("id") != offered_id or not party_ids.has(definition.get("owner")):
			return
	var result: Dictionary = offering.claim(run_deck, id)
	if not result.ok:
		return
	run_deck = result.deck
	_finish_card_reward(offering)


func _finish_card_reward(offering) -> void:
	for action in reward_buttons:
		action.disabled = true
	if run_map != null:
		continue_button = Button.new()
		continue_button.text = "Continue"
		continue_button.custom_minimum_size = Vector2(160, 56)
		return_button.get_parent().add_child(continue_button)
		continue_button.pressed.connect(_continue_to_rest_route.bind(offering, weakref(run_map), continue_button))
	_refresh_swap_preview()
	return_button.grab_focus()


## The terminal Fight stays separate from persistent run data and future encounters.
func _can_leave_fight() -> bool:
	return run_map != null and run_map.get_route().size() == 1 \
		and run_map.get_node(run_map.get_current_node_id()).get("type") == "Fight" \
		and _battle_closed and battle_result != null \
		and battle_result._party == party and battle_result._enemies == enemies \
		and battle_result.get_outcome() == CombatBattleResult.VICTORY \
		and party != null and party.is_valid() and not party.is_defeated() \
		and fight_rewards != null and fight_reward_claimed \
		and RunRestRecovery._is_valid_roster(run_heroes)


func _continue_to_rest_route(offering, source_map: WeakRef, button) -> void:
	if not _can_leave_fight() or offering != fight_rewards or source_map == null \
		or source_map.get_ref() != run_map or not is_instance_valid(button) \
		or button != continue_button or button.disabled or not button.is_visible_in_tree() \
		or is_instance_valid(route_view) or is_instance_valid(rest_view):
		return
	button.disabled = true
	battle_view.hide()
	_present_connected_route(source_map)


func _present_connected_route(source_map: WeakRef) -> void:
	_connected_map = source_map
	_connected_route = run_map.get_route()
	route_view = VBoxContainer.new()
	route_view.set_anchors_preset(Control.PRESET_CENTER)
	route_view.add_theme_constant_override("separation", 16)
	add_child(route_view)
	var heading := Label.new()
	heading.text = "Connected route - choose Rest or Shop"
	route_view.add_child(heading)
	var prior := run_map.get_route()
	for id in run_map.get_legal_choices():
		var node := run_map.get_node(id)
		var action := Button.new()
		action.text = "%s: %s" % [id, node.type]
		action.set_meta("route_id", id)
		action.disabled = node.type not in ["Rest", "Shop"]
		if action.disabled:
			action.text += " (unavailable)"
		action.custom_minimum_size = Vector2(440, 48)
		if node.type == "Shop":
			action.pressed.connect(_choose_shop_route.bind(id, source_map, prior, action))
		else:
			action.pressed.connect(_choose_rest_route.bind(id, source_map, prior, action))
		route_view.add_child(action)
		route_buttons.append(action)
	route_back_button = Button.new()
	route_back_button.text = "Return to title"
	route_back_button.pressed.connect(_return_from_visit.bind(route_view))
	route_view.add_child(route_back_button)
	_focus_visit(route_view)


func _can_choose_connected_route() -> bool:
	if run_map == null or _connected_map == null or _connected_map.get_ref() != run_map \
		or run_map.get_route() != _connected_route or not RunRestRecovery._is_valid_roster(run_heroes):
		return false
	if run_map.get_node(run_map.get_current_node_id()).get("type") == "Fight":
		return _can_leave_fight()
	return _current_shop_ledger("closed")


func _current_shop_ledger(status: String = "") -> bool:
	if shop_visit == null or run_map == null or _shop_map == null or _shop_map.get_ref() != run_map \
		or run_map.get_route() != _shop_route or _shop_route.is_empty() \
		or run_map.get_node(run_map.get_current_node_id()).get("type") != "Shop":
		return false
	var ledger := shop_visit.get_state()
	return ledger.valid and ledger.shop_node_id == run_map.get_current_node_id() \
		and ledger.deck == run_deck and ledger.gold == session_gold \
		and ledger.prior_removals == run_removal_count \
		and (ledger.status == status if not status.is_empty() else ledger.status in ["available", "used"])


func _continue_from_shop(visit: RunShopVisit, source_map: WeakRef, prior: Array[String], button) -> void:
	if visit == null or visit != shop_visit or not _current_shop_ledger() \
		or source_map == null or source_map.get_ref() != run_map or prior != _shop_route \
		or not RunRestRecovery._is_valid_roster(run_heroes) \
		or not is_instance_valid(shop_view) or not shop_view.is_visible_in_tree() \
		or not is_instance_valid(button) or button != shop_continue_button or button.disabled \
		or not button.is_visible_in_tree() or is_instance_valid(route_view):
		return
	if not visit.close_visit():
		return
	button.disabled = true
	shop_view.hide()
	_present_connected_route(source_map)


func _choose_rest_route(id: String, source_map: WeakRef, prior: Array[String], button) -> bool:
	if not _can_choose_connected_route() or source_map == null or source_map.get_ref() != run_map \
		or run_map.get_route() != prior or not is_instance_valid(route_view) \
		or not route_view.is_visible_in_tree() or not is_instance_valid(button) \
		or button not in route_buttons or button.disabled or not button.is_visible_in_tree() \
		or button.get_meta("route_id") != id or not run_map.get_legal_choices().has(id) \
		or run_map.get_node(id).get("type") != "Rest":
		return false
	if not run_map.choose_node(id):
		return false
	rest_recovery = RunRestRecovery.new(run_heroes)
	_rest_heroes = run_heroes.duplicate(true)
	_rest_route = run_map.get_route()
	_rest_map = weakref(run_map)
	_clear_route_view()
	rest_view = VBoxContainer.new()
	rest_view.set_anchors_preset(Control.PRESET_CENTER)
	rest_view.add_theme_constant_override("separation", 24)
	add_child(rest_view)
	var heading := Label.new()
	heading.text = "Rest - " + id
	rest_view.add_child(heading)
	rest_hp_label = Label.new()
	rest_view.add_child(rest_hp_label)
	_refresh_rest_hp()
	rest_heal_button = Button.new()
	rest_heal_button.text = "Heal party (30% max HP; revive downed heroes)"
	rest_heal_button.custom_minimum_size = Vector2(480, 56)
	rest_heal_button.pressed.connect(_heal_at_rest.bind(rest_recovery, rest_heal_button))
	rest_view.add_child(rest_heal_button)
	rest_back_button = Button.new()
	rest_back_button.text = "Return to title"
	rest_back_button.pressed.connect(_return_from_visit.bind(rest_view))
	rest_view.add_child(rest_back_button)
	_focus_visit(rest_view)
	return true


func _heal_at_rest(visit: RunRestRecovery, button) -> void:
	if visit == null or visit != rest_recovery or visit.is_consumed() \
		or not is_instance_valid(rest_view) or not rest_view.is_visible_in_tree() \
		or not is_instance_valid(button) or button != rest_heal_button \
		or button.disabled or not button.is_visible_in_tree() or run_map == null \
		or _rest_map == null or _rest_map.get_ref() != run_map \
		or run_map.get_route() != _rest_route or _rest_route.is_empty() \
		or run_map.get_node(run_map.get_current_node_id()).get("type") != "Rest" \
		or run_heroes != _rest_heroes or not RunRestRecovery._is_valid_roster(run_heroes):
		return
	var result := visit.choose_heal()
	if not result.ok:
		return
	run_heroes = result.heroes.duplicate(true)
	button.disabled = true
	_refresh_rest_hp()
	rest_back_button.grab_focus()


func _refresh_rest_hp() -> void:
	var lines: PackedStringArray = []
	for hero in run_heroes:
		lines.append("%s: HP %d/%d" % [hero.id.capitalize(), hero.hp, hero.max_hp])
	rest_hp_label.text = "\n".join(lines)


func _choose_shop_route(id: String, source_map: WeakRef, prior: Array[String], button) -> bool:
	if not _can_choose_connected_route() or source_map == null or source_map.get_ref() != run_map \
		or run_map.get_route() != prior or not is_instance_valid(route_view) \
		or not route_view.is_visible_in_tree() or not is_instance_valid(button) \
		or button not in route_buttons or button.disabled or not button.is_visible_in_tree() \
		or button.get_meta("route_id") != id or not run_map.get_legal_choices().has(id) \
		or run_map.get_node(id).get("type") != "Shop":
		return false
	var visit := RunShopVisit.new(run_deck, session_gold, run_removal_count)
	var offers: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
	if not (offers is Dictionary) or not (offers.get("cards") is Array) \
		or not (offers.get("trinkets") is Array) or run_rng == null:
		return false
	var party_ids: Array[String] = []
	for hero in run_heroes:
		if not (hero is Dictionary) or not (hero.get("id") is String):
			return false
		party_ids.append(hero.id)
	var rng_before := run_rng.state
	var stock := RunShopStockOffers.generate(run_rng, party_ids, offers.cards, offers.trinkets, [])
	if not stock.ok:
		run_rng.state = rng_before
		return false
	var purchases := RunShopPurchases.new(party_ids, run_deck, [], session_gold, stock.cards, stock.trinkets)
	if not purchases.is_valid():
		run_rng.state = rng_before
		return false
	if not visit.get_state().valid or not run_map.choose_node(id):
		run_rng.state = rng_before
		return false
	if not visit.open_visit(id):
		run_map.undo_choice(id, prior)
		run_rng.state = rng_before
		return false
	shop_visit = visit
	shop_purchases = purchases
	_shop_map = weakref(run_map)
	_shop_route = run_map.get_route()
	_clear_route_view()
	if is_instance_valid(shop_view):
		remove_child(shop_view)
		shop_view.queue_free()
	shop_view = VBoxContainer.new()
	shop_view.set_anchors_preset(Control.PRESET_CENTER)
	shop_view.add_theme_constant_override("separation", 12)
	add_child(shop_view)
	var heading := Label.new()
	heading.text = "Shop - " + id
	shop_view.add_child(heading)
	shop_label = Label.new()
	shop_view.add_child(shop_label)
	shop_offers = OptionButton.new()
	shop_offers.custom_minimum_size = Vector2(440, 48)
	shop_view.add_child(shop_offers)
	shop_offers.item_selected.connect(_select_shop_offer)
	shop_buy_button = Button.new()
	shop_buy_button.text = "Buy selected card"
	shop_buy_button.custom_minimum_size = Vector2(440, 48)
	shop_buy_button.pressed.connect(_buy_at_shop.bind(visit, purchases, shop_buy_button))
	shop_view.add_child(shop_buy_button)
	shop_cards = OptionButton.new()
	shop_cards.custom_minimum_size = Vector2(440, 48)
	for card_id in run_deck:
		shop_cards.add_item(card_id)
	shop_view.add_child(shop_cards)
	shop_remove_button = Button.new()
	shop_remove_button.text = "Remove selected card"
	shop_remove_button.custom_minimum_size = Vector2(440, 56)
	shop_remove_button.pressed.connect(_remove_at_shop.bind(visit, shop_remove_button))
	shop_view.add_child(shop_remove_button)
	shop_continue_button = Button.new()
	shop_continue_button.text = "Continue"
	shop_continue_button.custom_minimum_size = Vector2(440, 48)
	shop_continue_button.pressed.connect(_continue_from_shop.bind(visit, _shop_map, _shop_route.duplicate(), shop_continue_button))
	shop_view.add_child(shop_continue_button)
	shop_back_button = Button.new()
	shop_back_button.text = "Return to title (skip remaining removal)"
	shop_back_button.pressed.connect(_return_from_visit.bind(shop_view))
	shop_view.add_child(shop_back_button)
	_refresh_shop()
	_focus_visit(shop_view)
	var actions: Array[Control] = [shop_offers, shop_buy_button, shop_cards, shop_remove_button, shop_continue_button, shop_back_button]
	for index in range(actions.size()):
		actions[index].focus_next = actions[index].get_path_to(actions[(index + 1) % actions.size()])
		actions[index].focus_previous = actions[index].get_path_to(actions[(index - 1 + actions.size()) % actions.size()])
	shop_offers.grab_focus()
	return true


func _shop_offer_text(offer: Dictionary) -> String:
	return "%s | %d gold%s" % [offer.id, offer.price, " | SOLD" if offer.sold else ""]


func _select_shop_offer(_index: int) -> void:
	if is_instance_valid(shop_view) and shop_view.is_visible_in_tree():
		_refresh_shop()


func _buy_at_shop(visit: RunShopVisit, purchases: RunShopPurchases, button) -> void:
	if visit == null or visit != shop_visit or purchases == null or purchases != shop_purchases \
		or run_map == null or _shop_map == null or _shop_map.get_ref() != run_map \
		or run_map.get_route() != _shop_route or _shop_route.is_empty() \
		or run_map.get_node(run_map.get_current_node_id()).get("type") != "Shop" \
		or not is_instance_valid(shop_view) or not shop_view.is_visible_in_tree() \
		or not is_instance_valid(button) or button != shop_buy_button or button.disabled \
		or not button.is_visible_in_tree() or not is_instance_valid(shop_offers) \
		or shop_offers.disabled or not shop_offers.is_visible_in_tree():
		return
	var ledger := visit.get_state()
	var state := purchases.get_state()
	if not ledger.removal_available or ledger.shop_node_id != run_map.get_current_node_id() \
		or ledger.deck != run_deck or ledger.gold != session_gold or ledger.prior_removals != run_removal_count \
		or state.deck != run_deck or state.gold != session_gold:
		return
	var index := shop_offers.selected
	var stock: Array = purchases.get_stock().cards
	if index < 0 or index >= stock.size() or index >= shop_offers.item_count:
		return
	var offer: Dictionary = stock[index]
	if offer.sold or session_gold < offer.price or shop_offers.get_item_metadata(index) != offer.id \
		or shop_offers.get_item_text(index) != _shop_offer_text(offer):
		return
	var result := purchases.buy("card", offer.id)
	if not result.ok:
		return
	if not visit.reconcile_purchase(result):
		return
	run_deck.assign(result.state.deck)
	session_gold = result.state.gold
	shop_cards.clear()
	for card_id in run_deck:
		shop_cards.add_item(card_id)
	_refresh_shop()


func _remove_at_shop(visit: RunShopVisit, button) -> void:
	if visit == null or visit != shop_visit or run_map == null \
		or _shop_map == null or _shop_map.get_ref() != run_map \
		or run_map.get_route() != _shop_route or _shop_route.is_empty() \
		or run_map.get_node(run_map.get_current_node_id()).get("type") != "Shop" \
		or not is_instance_valid(shop_view) or not shop_view.is_visible_in_tree() \
		or not is_instance_valid(button) or button != shop_remove_button \
		or button.disabled or not button.is_visible_in_tree() \
		or not is_instance_valid(shop_cards) or shop_cards.selected < 0:
		return
	var state := visit.get_state()
	if not state.removal_available or state.shop_node_id != run_map.get_current_node_id() \
		or state.deck != run_deck or state.gold != session_gold or state.prior_removals != run_removal_count:
		return
	var index := shop_cards.selected
	if index >= run_deck.size() or shop_cards.get_item_text(index) != run_deck[index]:
		return
	var result := visit.remove_card(shop_cards.get_item_text(index))
	if not result.ok:
		return
	run_deck.assign(result.deck)
	session_gold = result.gold
	run_removal_count = result.prior_removals
	_refresh_shop()
	shop_back_button.grab_focus()


func _refresh_shop() -> void:
	shop_label.text = "Gold: %d | Removal: %d gold" % [session_gold, shop_visit.quote()]
	shop_remove_button.disabled = not shop_visit.get_state().removal_available
	shop_cards.disabled = shop_remove_button.disabled
	var selected := maxi(0, shop_offers.selected)
	shop_offers.clear()
	var stock: Array = shop_purchases.get_stock().cards
	for offer in stock:
		shop_offers.add_item(_shop_offer_text(offer))
		shop_offers.set_item_metadata(shop_offers.item_count - 1, offer.id)
	shop_offers.select(selected)
	shop_offers.disabled = shop_remove_button.disabled
	shop_buy_button.disabled = shop_remove_button.disabled or stock[selected].sold or session_gold < stock[selected].price


func _focus_visit(view: VBoxContainer) -> void:
	var actions: Array[Button] = []
	for child in view.get_children():
		if child is Button and not child.disabled:
			actions.append(child)
	for index in range(actions.size()):
		actions[index].focus_next = actions[index].get_path_to(actions[(index + 1) % actions.size()])
		actions[index].focus_previous = actions[index].get_path_to(actions[(index - 1 + actions.size()) % actions.size()])
	view.position -= view.get_combined_minimum_size() / 2.0
	actions[0].grab_focus()


func _return_from_visit(view) -> void:
	if is_instance_valid(view) and view in [route_view, rest_view, shop_view] and view.is_visible_in_tree():
		_return_to_title()


func _refresh_hand() -> void:
	$LiveSupportHand._cancel_pending()
	for child in hand_view.get_children():
		child.free()
	for card_id in deck.hand:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hand_view.add_child(panel)
		var label := Label.new()
		label.text = card_id
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		panel.add_child(label)
	pile_label.text = "Draw: %d | Discard: %d" % [deck.draw_pile.size(), deck.discard_pile.size()]
	$LiveSupportHand._sync_battle()


func _refresh_party() -> void:
	_refresh_swap_preview()
	for index in range(hero_panels.size()):
		var hero := party.get_hero(index + 1)
		var label := hero_panels[index].get_child(0) as Label
		label.text = "%d - %s\nHP: %d/%d | Block: %d%s" % [
			hero["position"], hero["name"], hero["hp"], hero["max_hp"], hero["block"],
			"\nDOWNED" if party.is_downed(index + 1) else ""]


func _refresh_intents() -> void:
	_refresh_enemy_buff_forecast()
	if not is_instance_valid(intent_label):
		return
	var announcements: PackedStringArray = []
	var cues := CombatIntentCues.new().get_cues(enemy_intents, enemies)
	if party == null or not party.is_valid():
		cues.clear()
	for attack in cues:
		if attack.icon_key == "block":
			announcements.append("Enemy %d: %d Block" % [attack.enemy_position, attack.amount])
		elif attack.icon_key == "buff":
			announcements.append("Enemy %d: Buff +%d Block" % [attack.enemy_position, attack.amount])
		elif attack.icon_key == "debuff":
			announcements.append("Enemy %d -> Hero %d: %s %d" % [attack.enemy_position, attack.target_position, attack.status.capitalize(), attack.amount])
		elif attack.icon_key == "shove":
			announcements.append("Enemy %d: Shove Hero %d %s" % [attack.enemy_position, attack.target_position, "back" if attack.direction == 1 else "front"])
		else:
			announcements.append("Enemy %d -> Hero %d (%s): %d damage" % [
				attack["enemy_position"], attack["target_position"],
				party.get_hero(attack["target_position"])["name"], attack["amount"]])
	intent_label.text = "Intent: " + ("none" if announcements.is_empty() else "; ".join(announcements))


func _refresh_enemy_buff_forecast() -> void:
	if not is_instance_valid(enemy_buff_forecast_label):
		return
	var lines: PackedStringArray = []
	if is_instance_valid(battle_view) and battle_view.is_visible_in_tree() \
		and not _battle_closed and battle_result != null \
		and battle_result.get_outcome() == CombatBattleResult.ACTIVE \
		and party != null and enemies != null and not party.is_defeated() and not enemies.is_defeated() \
		and enemy_intents != null and enemy_intents.is_valid() and enemy_attacks == enemy_intents.get_intents():
		for buff in LiveEnemyBuffForecast.new().forecast(party, enemies, enemy_attacks):
			lines.append("%s Block: %d -> %d" % [buff.name, buff.before, buff.after])
	enemy_buff_forecast_label.text = "" if lines.is_empty() else "Next enemy phase: " + "; ".join(lines)
	enemy_buff_forecast_label.visible = not lines.is_empty()


func _end_turn(button: Button = null) -> void:
	if button == null or button != end_turn_button or button.disabled or not button.is_visible_in_tree():
		return
	if deck == null or party == null or enemies == null or enemy_intents == null \
			or battle_result == null or round_flow == null:
		return
	if round_flow._deck != deck or round_flow._party != party \
			or round_flow._enemies != enemies or round_flow._intents != enemy_intents \
			or round_flow._result != battle_result:
		return
	if not _observe_battle_result():
		return
	# Reject stale announcements and inactive hands before executing any enemy action.
	if not party.is_valid() or not enemies.is_valid() or enemy_attacks != enemy_intents.get_intents():
		return
	if not deck.turn_active:
		return
	# Accept one activation per input dispatch, including a burst of duplicate presses.
	button.disabled = true
	if not round_flow.end_turn():
		button.disabled = false
		return
	if not _observe_battle_result():
		return
	enemy_attacks = enemy_intents.get_intents()
	_refresh_intents()
	_refresh_hand()
	_refresh_party()
	_refresh_enemy_roster()
	_reenable_end_turn.call_deferred(button)


func _reenable_end_turn(button: Button) -> void:
	if is_instance_valid(button) and button == end_turn_button and _observe_battle_result():
		button.disabled = false


func _refresh_enemy_roster() -> void:
	var presenter := get_node_or_null("LiveEnemyRoster")
	if presenter != null:
		presenter._sync_battle()
		presenter._refresh()


func _return_to_title() -> void:
	if battle_view == null:
		return
	for action in reward_buttons:
		action.disabled = true
	if is_instance_valid(continue_button):
		continue_button.disabled = true
	end_turn_button.disabled = true
	return_button.disabled = true
	if shop_visit != null:
		shop_visit.close_visit()
	if is_instance_valid(shop_view):
		remove_child(shop_view)
		shop_view.queue_free()
	shop_view = null
	shop_cards = null
	shop_remove_button = null
	shop_back_button = null
	shop_continue_button = null
	shop_label = null
	shop_visit = null
	shop_purchases = null
	shop_offers = null
	shop_buy_button = null
	_shop_map = null
	_shop_route.clear()
	_connected_map = null
	_connected_route.clear()
	run_removal_count = 0
	if is_instance_valid(rest_view):
		remove_child(rest_view)
		rest_view.queue_free()
	rest_view = null
	rest_heal_button = null
	rest_back_button = null
	rest_hp_label = null
	rest_recovery = null
	_rest_route.clear()
	_rest_heroes.clear()
	_rest_map = null
	run_heroes.clear()
	continue_button = null
	round_flow = null
	remove_child(battle_view)
	battle_view.queue_free()
	battle_view = null
	hand_view = null
	pile_label = null
	end_turn_button = null
	return_button = null
	swap_preview_buttons.clear()
	swap_preview_cue = null
	_swap_preview_pair = 0
	hero_view = null
	hero_panels.clear()
	intent_label = null
	enemy_buff_forecast_label = null
	result_label = null
	battle_result = null
	victory_gold = null
	card_reward = null
	fight_rewards = null
	fight_reward_offers.clear()
	fight_reward_gold = 0
	fight_reward_claimed = false
	_reward_map = null
	reward_buttons.clear()
	run_deck.clear()
	session_gold = 0
	_battle_closed = false
	enemy_attacks.clear()
	enemy_intents = null
	party = null
	enemies = null
	deck = null
	run_rng = null
	run_map = null
	fight_selection = null
	encounter_id = ""
	_clear_route_view()
	title_view.show()
	start_button.grab_focus()
