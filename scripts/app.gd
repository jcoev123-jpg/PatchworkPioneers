extends Control
## Root of the game. The hand view delegates all card movement to CombatDeck.

signal start_run_requested

const TITLE := "Patchwork Pioneers"
const STARTER_DECK_PATH := "res://data/cards/starter_deck.json"
const STARTER_PARTY_PATH := "res://data/heroes/starter_party.json"
const STARTER_ATTACKS_PATH := "res://data/encounters/starter_attacks.json"
const STARTER_ENEMIES_PATH := "res://data/enemies/starter_enemies.json"

@export var run_seed: int = 42
@export_file("*.json") var starter_deck_path: String = STARTER_DECK_PATH
@export_file("*.json") var starter_party_path: String = STARTER_PARTY_PATH
@export_file("*.json") var starter_attacks_path: String = STARTER_ATTACKS_PATH
@export_file("*.json") var starter_enemies_path: String = STARTER_ENEMIES_PATH

var title_label: Label
var start_button: Button
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
var battle_result: CombatBattleResult
var round_flow: CombatRoundFlow
var victory_gold: RunVictoryGold
var session_gold := 0
var result_label: Label
var _battle_closed := false


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


## Single observation boundary for live updates and resolved phases.
func _observe_battle_result() -> bool:
	if battle_result == null:
		return false
	var outcome := battle_result.evaluate()
	if outcome == CombatBattleResult.ACTIVE:
		return true
	if not _battle_closed:
		_battle_closed = true
		if outcome == CombatBattleResult.VICTORY:
			session_gold = victory_gold.claim_gold(false, run_rng)
		# Enemy phases have already ended the turn; external/card damage may not have.
		if deck.turn_active:
			deck.end_turn()
		$LiveSupportHand._cancel_pending()
		_refresh_hand()
		if party.is_valid():
			_refresh_party()
		_refresh_enemy_roster()
		end_turn_button.disabled = true
		result_label.text = "Battle result: " + outcome
		if outcome == CombatBattleResult.VICTORY:
			result_label.text += " | Gold: %d" % session_gold
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
	start_button.grab_focus.call_deferred()
	box.position -= box.get_combined_minimum_size() / 2.0


func _start_run() -> void:
	if deck != null:
		return
	var cards := _load_starter_deck()
	if cards.is_empty():
		push_warning("Starter deck is invalid or unreadable; run was not started")
		return
	var selector := CombatEnemyIntents.new(_load_enemy_schedule())
	var starting_enemies := CombatEnemies.new(_load_enemy_definitions())
	if not selector.is_valid() or not starting_enemies.is_valid() or not _positions_align(selector, starting_enemies):
		push_warning("Starter enemies or schedule are invalid; run was not started")
		return
	var definitions := _load_party_definitions()
	var starting_party := CombatParty.new(definitions)
	if not starting_party.is_valid():
		push_warning("Starter party definitions are invalid; run was not started")
		return
	var starting_rng := RandomNumberGenerator.new()
	starting_rng.seed = run_seed
	var starting_deck := CombatDeck.new(cards, starting_rng)
	var starting_result := CombatBattleResult.new(starting_party, starting_enemies)
	var starting_flow := CombatRoundFlow.new(starting_deck, starting_party,
		starting_enemies, selector, starting_result)
	if not starting_flow.begin_fight():
		push_warning("Starter combat bindings are invalid; run was not started")
		return
	enemy_intents = selector
	enemy_attacks = enemy_intents.get_intents()
	party = starting_party
	enemies = starting_enemies
	run_rng = starting_rng
	deck = starting_deck
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
			if not kind is String or kind not in ["attack", "block"]:
				return []
			if not _normalize_schedule_number(action, "amount"):
				return []
			if kind == "attack" and not _normalize_schedule_number(action, "target_position"):
				return []
	# CombatEnemyIntents validates exact keys, ranges and duplicate source positions.
	return source


func _normalize_schedule_number(record: Dictionary, field: String) -> bool:
	var value = record.get(field)
	if not (value is int or value is float):
		return false
	if not is_finite(float(value)) or floor(float(value)) != float(value):
		return false
	if value < 0 or value >= float(CombatParty.MAX_INT):
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
	column.add_theme_constant_override("separation", 24)
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
	_refresh_intents()
	intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(intent_label)
	result_label = Label.new()
	result_label.name = "BattleResult"
	result_label.add_theme_font_size_override("font_size", 28)
	result_label.hide()
	column.add_child(result_label)
	var heading := Label.new()
	heading.text = "Shared hand"
	heading.add_theme_font_size_override("font_size", 32)
	column.add_child(heading)
	pile_label = Label.new()
	column.add_child(pile_label)
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
	end_turn_button.focus_next = end_turn_button.get_path_to(return_button)
	end_turn_button.focus_previous = end_turn_button.get_path_to(return_button)
	return_button.focus_next = return_button.get_path_to(end_turn_button)
	return_button.focus_previous = return_button.get_path_to(end_turn_button)


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


func _refresh_party() -> void:
	for index in range(hero_panels.size()):
		var hero := party.get_hero(index + 1)
		var label := hero_panels[index].get_child(0) as Label
		label.text = "%d - %s\nHP: %d/%d | Block: %d%s" % [
			hero["position"], hero["name"], hero["hp"], hero["max_hp"], hero["block"],
			"\nDOWNED" if party.is_downed(index + 1) else ""]


func _refresh_intents() -> void:
	if not is_instance_valid(intent_label):
		return
	var announcements: PackedStringArray = []
	var cues := CombatIntentCues.new().get_cues(enemy_intents, enemies)
	if party == null or not party.is_valid():
		cues.clear()
	for attack in cues:
		if attack.icon_key == "block":
			announcements.append("Enemy %d: %d Block" % [attack.enemy_position, attack.amount])
		else:
			announcements.append("Enemy %d -> Hero %d (%s): %d damage" % [
				attack["enemy_position"], attack["target_position"],
				party.get_hero(attack["target_position"])["name"], attack["amount"]])
	intent_label.text = "Intent: " + ("none" if announcements.is_empty() else "; ".join(announcements))


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
	round_flow = null
	remove_child(battle_view)
	battle_view.queue_free()
	battle_view = null
	hand_view = null
	pile_label = null
	end_turn_button = null
	return_button = null
	hero_view = null
	hero_panels.clear()
	intent_label = null
	result_label = null
	battle_result = null
	victory_gold = null
	session_gold = 0
	_battle_closed = false
	enemy_attacks.clear()
	enemy_intents = null
	party = null
	enemies = null
	deck = null
	run_rng = null
	title_view.show()
	start_button.grab_focus()
