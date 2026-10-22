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
## One stage height shared with the roster presenter, so both lineups stay the same size.
const STAGE_ROSTER := preload("res://scripts/live_enemy_roster.gd")
const STAGE_ACTOR_HEIGHT := STAGE_ROSTER.STAGE_ACTOR_HEIGHT

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
var route_map_button: Button
var route_atlas_overlay: Control
var route_atlas: RunRouteAtlas
var route_atlas_close: Button
var route_buttons: Array[Button] = []
var map_mend_buttons: Array[Button] = []
var _map_mend_serial := 0
var _mended_route_context: Array = []
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
var act_outcome: RunActBattleOutcome
var round_flow: CombatRoundFlow
var victory_gold: RunVictoryGold
var session_gold := 0
var run_deck: Array[String] = []
var run_scraps := 0
var run_stitch_descriptors: Dictionary = {}
var run_next_stitch_id := 1
var run_trinkets: Array[String] = []
var fight_reward_trinket := ""
var run_heroes: Array = []
var party_carryover: RunPartyCarryover
var _carryover_map: WeakRef
var _carryover_revision := 0
var _carryover_node := ""
var _carryover_route: Array[String] = []
var _carryover_floors: Array = []
var _carryover_party: CombatParty
var _carryover_result: CombatBattleResult
var continue_button: Button
var rest_view: VBoxContainer
var rest_patch_button: Button
var rest_patch_overlay: Control
var rest_patch_picker: LiveRestPatchResewPicker
var _rest_wardrobe: RunPatchWardrobe
var _rest_patch_context: Array = []
var _rest_patch_serial := 0
var rest_heal_button: Button
var rest_continue_button: Button
var rest_back_button: Button
var rest_hp_label: Label
var rest_recovery: RunRestRecovery
var rest_stitch: RunRestStitchCards
var rest_stitch_first: OptionButton
var rest_stitch_second: OptionButton
var rest_stitch_button: Button
var rest_stitch_guided_button: Button
var rest_stitch_overlay: Control
var rest_stitch_picker: LiveRestStitchPairPicker
var _rest_stitch_source: Dictionary = {}
var _rest_stitch_committed: Dictionary = {}
var rest_upgrade: RunRestCardUpgrade
var rest_upgrade_cards: OptionButton
var rest_upgrade_button: Button
var _rest_deck: Array[String] = []
var _rest_committed_deck: Array[String] = []
var _rest_floors: Array = []
var _rest_revision := 0
var _rest_inventory: Array = []
var _rest_ledger: Dictionary = {}
var _rest_carry: RunPartyCarryover
var _rest_rng: RandomNumberGenerator
var _rest_gold := 0
var _rest_rng_state := 0
var _rest_route: Array[String] = []
var _rest_heroes: Array = []
var _rest_committed_heroes: Array = []
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
var shop_patch_offers: OptionButton
var shop_patch_heroes: OptionButton
var shop_patch_buy_button: Button
var _shop_wardrobe: RunPatchWardrobe
var _shop_patch_context: Array = []
var run_removal_count := 0
var _shop_map: WeakRef
var _shop_route: Array[String] = []
var _connected_map: WeakRef
var _connected_route: Array[String] = []
var _placeholder_map: WeakRef
var _placeholder_route: Array[String] = []
var event_catalog_path := "res://data/events/m04_events.json"
var quiet_spool_panel: LiveEventChoicePanel
var _quiet_spool_outcome: RunQuietSpoolOutcome
var _quiet_spool_context: Array = []
var _quiet_spool_completed := false
var card_reward: RunCardRewardChoice
var fight_rewards: RunFightVictoryRewards
var multi_fight_rewards: RunMultiFightRewards
var fight_reward_offers: Array = []
var fight_reward_gold := 0
var fight_reward_claimed := false
var _reward_map: WeakRef
var reward_buttons: Array[Button] = []
var reward_choice_panel: LiveRunCardRewardChoicePanel
var _reward_return_parent: WeakRef
const INTERIM_REWARD_IDS := ["warden_strike", "seamstress_prick", "tinker_pop_shot"]
var result_label: Label
var _battle_closed := false
var terminal_result_panel: LiveRunTerminalResultPanel
var _terminal_return_connection: Callable
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
	# One battle-independent listener presents committed HP/Block changes (VIS V5).
	var combat_juice := Node.new()
	combat_juice.name = "LiveCombatJuice"
	combat_juice.set_script(preload("res://scripts/live_combat_juice.gd"))
	add_child(combat_juice)


func _process(_delta: float) -> void:
	_observe_battle_result()
	if is_instance_valid(battle_view) and battle_view.is_visible_in_tree():
		_refresh_intents()
		_refresh_swap_preview()


## Single observation boundary for live updates and resolved phases.
func _observe_battle_result() -> bool:
	if battle_result == null:
		return false
	if party_carryover != null and not _current_carryover_fight():
		return false
	if run_map != null and not _current_act_battle():
		return false
	var outcome := battle_result.evaluate()
	if outcome == CombatBattleResult.ACTIVE:
		return true
	if not _battle_closed and outcome == CombatBattleResult.VICTORY and run_map != null and _carryover_route.size() == 1 and run_map.get_node(_carryover_node).get("type") == "Fight":
		if not _commit_fight_carryover():
			return false
	if not _battle_closed and act_outcome != null:
		if not act_outcome.settle_current_battle():
			return false
	if is_instance_valid(enemy_buff_forecast_label):
		enemy_buff_forecast_label.text = ""
		enemy_buff_forecast_label.hide()
	if not _battle_closed:
		_battle_closed = true
		if outcome == CombatBattleResult.VICTORY:
			if run_map == null:
				session_gold = victory_gold.claim_gold(false, run_rng)
		# Enemy phases have already ended the turn; external/card damage may not have.
		if deck.turn_active:
			deck.end_turn()
		$LiveSupportHand._cancel_pending()
		_refresh_hand()
		if outcome == CombatBattleResult.VICTORY and (run_map == null or run_map.get_node(_carryover_node).get("type") in ["Fight", "Elite"]):
			_build_card_reward()
		if party.is_valid():
			_refresh_party()
		_refresh_enemy_roster()
		end_turn_button.disabled = true
		result_label.text = "Battle result: " + outcome
		if act_outcome != null and outcome == CombatBattleResult.DEFEAT:
			result_label.text += " | Run defeat"
		if act_outcome != null and act_outcome.get_state().run_status == RunActBattleOutcome.VICTORY:
			result_label.text += " | Run victory"
		if outcome == CombatBattleResult.VICTORY and (run_map == null or run_map.get_node(_carryover_node).get("type") in ["Fight", "Elite"]):
			result_label.text += " | Pending gold: %d" % fight_reward_gold if run_map != null else " | Gold: %d" % session_gold
		if not fight_reward_trinket.is_empty():
			result_label.text += " | Trinket: " + fight_reward_trinket
		result_label.show()
		if _terminal_result_is_current():
			_mount_terminal_result()
		else:
			return_button.grab_focus()
	return false


## Present only the settled witness for this same mounted routed combat.
func _terminal_result_is_current() -> bool:
	if not _battle_closed or not _current_act_battle() or not _current_carryover_fight() \
		or not is_instance_valid(battle_view) or not battle_view.is_visible_in_tree() \
		or battle_result == null or act_outcome == null or run_map == null:
		return false
	var state := act_outcome.get_state()
	var status: String = state.get("run_status", "")
	if status not in [RunActBattleOutcome.VICTORY, RunActBattleOutcome.DEFEAT] \
		or state.get("pending_node_id") != "" or state.get("settled_node_ids", []).is_empty() \
		or state.settled_node_ids.back() != _carryover_node:
		return false
	if status == RunActBattleOutcome.DEFEAT:
		return battle_result.get_outcome() == CombatBattleResult.DEFEAT
	return battle_result.get_outcome() == CombatBattleResult.VICTORY \
		and run_map.get_current_floor() == RunMap.FLOOR_COUNT \
		and run_map.get_node(_carryover_node).get("type") == "Boss"


func _mount_terminal_result() -> void:
	if is_instance_valid(terminal_result_panel) or not _terminal_result_is_current():
		return
	var panel := load("res://scenes/run_terminal_result_panel.tscn").instantiate() as LiveRunTerminalResultPanel
	if panel == null:
		return
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not panel.open_result(act_outcome):
		remove_child(panel)
		panel.queue_free()
		return
	terminal_result_panel = panel
	_terminal_return_connection = _return_from_terminal.bind(weakref(panel), act_outcome, run_map)
	panel.return_to_title_requested.connect(_terminal_return_connection)
	# The routed terminal view owns navigation, never the old battle Return.
	return_button.disabled = true
	return_button.release_focus()
	panel.return_button.grab_focus()


func _return_from_terminal(source: WeakRef, latch: RunActBattleOutcome, source_map: RunMap) -> void:
	var panel := source.get_ref() as LiveRunTerminalResultPanel if source != null else null
	if panel == null or panel != terminal_result_panel or latch != act_outcome \
		or source_map != run_map or not panel.has_open_result() \
		or not panel.is_visible_in_tree() or not panel._return_requested \
		or not _terminal_result_is_current():
		return
	_return_to_title()


func _clear_terminal_result() -> void:
	if is_instance_valid(terminal_result_panel):
		if _terminal_return_connection.is_valid() \
			and terminal_result_panel.return_to_title_requested.is_connected(_terminal_return_connection):
			terminal_result_panel.return_to_title_requested.disconnect(_terminal_return_connection)
		terminal_result_panel.close_result()
		remove_child(terminal_result_panel)
		terminal_result_panel.queue_free()
	terminal_result_panel = null
	_terminal_return_connection = Callable()


func _current_act_battle() -> bool:
	if act_outcome == null or act_outcome._map != run_map or not _current_carryover_fight():
		return false
	if _battle_closed:
		return true
	return act_outcome._pending_result == battle_result \
		and act_outcome._pending_node_id == run_map.get_current_node_id() \
		and act_outcome._pending_route == run_map.get_route() \
		and act_outcome._pending_floors == run_map.get_floors()


func _current_carryover_fight() -> bool:
	return party_carryover != null and _carryover_map != null \
		and run_map != null and _carryover_map.get_ref() == run_map \
		and run_map.get_generation_revision() == _carryover_revision \
		and run_map.get_route() == _carryover_route and run_map.get_floors() == _carryover_floors \
		and run_map.get_current_node_id() == _carryover_node \
		and run_map.get_node(_carryover_node).get("type") in ["Fight", "Elite", "Boss"] \
		and party == _carryover_party and battle_result == _carryover_result \
		and battle_result != null and battle_result._party == party and battle_result._enemies == enemies


func _commit_fight_carryover() -> bool:
	if not _current_carryover_fight() or _battle_closed \
		or party_carryover.read_state().completed_fights.has(_carryover_node):
		return false
	var committed := party_carryover.commit_victory(_carryover_node, battle_result, party)
	if not committed.ok:
		return false
	run_heroes = committed.heroes
	return true


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
	_open_route()


func _open_route() -> void:
	if deck != null or run_map != null:
		return
	var cards := _load_starter_deck()
	var initial_party := CombatParty.new(_load_party_definitions())
	if cards.is_empty() or not initial_party.is_valid():
		return
	var carry := RunTornCarryover.new(initial_party.get_heroes())
	if not carry.is_valid() or carry.create_next_fight_party() == null:
		return
	var owners: Array = []
	for hero in initial_party.get_heroes():
		owners.append(hero.id)
	for card in cards:
		if not owners.has(StarterCards.new().get_definition(card).get("owner")):
			return
	run_rng = RandomNumberGenerator.new()
	run_rng.seed = run_seed
	run_map = RunMap.new()
	run_map.generate(run_rng)
	fight_selection = RunFightEncounterSelection.new()
	run_deck = cards.duplicate()
	run_heroes = carry.read_state().heroes
	party_carryover = carry
	_carryover_map = weakref(run_map)
	_carryover_revision = run_map.get_generation_revision()
	_carryover_floors = run_map.get_floors()
	act_outcome = RunActBattleOutcome.new(run_map)
	_connected_map = weakref(run_map)
	_connected_route = []
	title_view.hide()
	route_view = VBoxContainer.new()
	route_view.set_anchors_preset(Control.PRESET_CENTER)
	route_view.add_theme_constant_override("separation", 16)
	add_child(route_view)
	var heading := Label.new()
	heading.text = "Opening route - choose your first node"
	route_view.add_child(heading)
	var actions: Array[Button] = []
	for id in run_map.get_legal_choices():
		var node := run_map.get_node(id)
		var button := Button.new()
		button.text = "%s: %s" % [id, node.type]
		button.set_meta("route_id", id)
		button.set_meta("route_kind", node.type)
		button.disabled = node.type not in RunMap.NORMAL_TYPES
		if button.disabled:
			button.text += " (unavailable)"
		button.custom_minimum_size = Vector2(340, 48)
		button.pressed.connect(_choose_route.bind(id, weakref(run_map)))
		route_view.add_child(button)
		route_buttons.append(button)
		if not button.disabled:
			actions.append(button)
	route_map_button = Button.new()
	route_map_button.text = "View full map"
	route_view.add_child(route_map_button)
	route_map_button.pressed.connect(_open_route_atlas.bind(
		weakref(run_map), weakref(route_view), weakref(route_map_button)))
	actions.append(route_map_button)
	route_back_button = Button.new()
	route_back_button.text = "Back"
	route_back_button.pressed.connect(_cancel_opening.bind(weakref(run_map), weakref(route_view)))
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
	if not run_map.get_legal_choices().has(id):
		return false
	for button in route_buttons:
		if button.get_meta("route_id") != id:
			continue
		var prior := run_map.get_route()
		var source: WeakRef = weakref(run_map)
		return _dispatch_route(id, source, prior, button)
	return false


func _dispatch_route(id: String, source: WeakRef, prior: Array[String], button) -> bool:
	if run_map == null or not is_instance_valid(button) \
		or button.get_meta("route_kind", "") != run_map.get_node(id).get("type"):
		return false
	match run_map.get_node(id).get("type"):
		"Fight", "Elite", "Boss":
			return _choose_battle_route(id, source, prior, button)
		"Rest":
			return _choose_rest_route(id, source, prior, button)
		"Shop":
			return _choose_shop_route(id, source, prior, button)
		"Event", "Treasure":
			return _choose_placeholder_route(id, source, prior, button)
	return false


func _route_atlas_source(source_map: WeakRef, source_view: WeakRef, source_action: WeakRef) -> bool:
	return source_map != null and source_map.get_ref() == run_map and run_map != null \
		and _can_choose_connected_route() \
		and is_instance_valid(route_view) and source_view != null and source_view.get_ref() == route_view \
		and route_view.get_parent() == self and is_instance_valid(route_map_button) \
		and source_action != null and source_action.get_ref() == route_map_button \
		and route_map_button.get_parent() == route_view


func _open_route_atlas(source_map: WeakRef, source_view: WeakRef, source_action: WeakRef) -> void:
	if not _route_atlas_source(source_map, source_view, source_action) \
		or not route_view.is_visible_in_tree() or is_instance_valid(route_atlas_overlay):
		return
	route_atlas_overlay = Control.new()
	route_atlas_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(route_atlas_overlay)
	var background := ColorRect.new()
	background.color = Color("2b3135")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	route_atlas_overlay.add_child(background)
	route_atlas = RunRouteAtlas.new()
	route_atlas.position = Vector2(20, 20)
	route_atlas.bind_map(run_map)
	route_atlas_overlay.add_child(route_atlas)
	var choices := {}
	for button in route_buttons:
		choices[button.get_meta("route_id")] = weakref(button)
	# Admission clears marker controls; wait until the emitting Button has finished its signal.
	route_atlas.node_requested.connect(_choose_atlas_opening.bind(source_map, source_view,
		source_action, weakref(route_atlas_overlay), weakref(route_atlas),
		run_map.get_generation_revision(), run_map.get_floors(), choices, run_map.get_route()), CONNECT_DEFERRED)
	route_atlas_close = Button.new()
	route_atlas_close.text = "Close map"
	route_atlas_close.position = Vector2(520, 640)
	route_atlas_close.size = Vector2(240, 48)
	route_atlas_overlay.add_child(route_atlas_close)
	route_atlas_close.focus_next = NodePath(".")
	route_atlas_close.focus_previous = NodePath(".")
	route_atlas_close.pressed.connect(_close_route_atlas.bind(source_map, source_view,
		source_action, weakref(route_atlas_overlay)))
	route_view.hide()
	route_atlas_close.grab_focus()


func _choose_atlas_opening(id: String, source_map: WeakRef, source_view: WeakRef,
		source_action: WeakRef, source_overlay: WeakRef, source_atlas: WeakRef,
		generation: int, graph: Array, choices: Dictionary, prior: Array[String]) -> bool:
	if not _route_atlas_source(source_map, source_view, source_action) \
		or route_view.visible or route_map_button.disabled \
		or not is_instance_valid(route_atlas_overlay) or source_overlay == null \
		or source_overlay.get_ref() != route_atlas_overlay \
		or route_atlas_overlay.get_parent() != self or not route_atlas_overlay.is_visible_in_tree() \
		or not is_instance_valid(route_atlas) or source_atlas == null \
		or source_atlas.get_ref() != route_atlas or route_atlas.get_parent() != route_atlas_overlay \
		or not route_atlas.is_visible_in_tree() or route_atlas._map != run_map:
		return false
	if run_map.get_generation_revision() != generation or run_map.get_floors() != graph \
		or run_map.get_route() != prior \
		or not run_map.get_legal_choices().has(id) or not choices.has(id) \
		or run_map.get_node(id).get("type") not in RunMap.NORMAL_TYPES + ["Boss"]:
		return false
	var button = choices[id].get_ref()
	if not is_instance_valid(button) or not route_buttons.has(button) \
		or button.get_parent() != route_view or button.get_meta("route_id") != id \
		or button.disabled or not button.visible:
		return false
	_clear_route_atlas()
	route_view.show()
	button.grab_focus()
	return _dispatch_route(id, source_map, prior, button)


func _close_route_atlas(source_map: WeakRef, source_view: WeakRef,
		source_action: WeakRef, source_overlay: WeakRef) -> void:
	if not _route_atlas_source(source_map, source_view, source_action) \
		or route_view.visible or not is_instance_valid(route_atlas_overlay) \
		or source_overlay == null or source_overlay.get_ref() != route_atlas_overlay \
		or route_atlas_overlay.get_parent() != self:
		return
	_clear_route_atlas()
	route_view.show()
	route_map_button.grab_focus()


func _clear_route_atlas() -> void:
	if is_instance_valid(route_atlas):
		route_atlas.bind_map(null)
	if is_instance_valid(route_atlas_overlay):
		if route_atlas_overlay.get_parent() != null:
			route_atlas_overlay.get_parent().remove_child(route_atlas_overlay)
		route_atlas_overlay.queue_free()
	route_atlas_overlay = null
	route_atlas = null
	route_atlas_close = null


func _clear_route_view() -> void:
	_clear_route_atlas()
	map_mend_buttons.clear()
	if is_instance_valid(route_view):
		remove_child(route_view)
		route_view.queue_free()
	route_view = null
	route_back_button = null
	route_map_button = null
	route_buttons.clear()


func _cancel_route() -> void:
	if deck != null or route_view == null:
		return
	_return_to_title()


func _cancel_opening(source_map: WeakRef, source_view: WeakRef) -> void:
	if source_map.get_ref() == run_map and source_view.get_ref() == route_view \
		and run_map != null and run_map.get_route().is_empty() \
		and is_instance_valid(route_view) and route_view.is_visible_in_tree():
		_cancel_route()


func _start_battle(shared_rng: RandomNumberGenerator = null, encounter_definitions: Array = [],
		selected_enemies: CombatEnemies = null) -> bool:
	if deck != null or (shared_rng == null and run_map != null):
		return false
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
	var starting_carryover: RunPartyCarryover
	var starting_outcome: RunActBattleOutcome
	if shared_rng != null:
		starting_outcome = RunActBattleOutcome.new(run_map)
		if not starting_outcome.begin_current_battle(starting_result):
			return false
		starting_carryover = RunTornCarryover.new(starting_party.get_heroes())
		if not starting_carryover.is_valid():
			return false
	var rng_before := starting_rng.state
	starting_deck.draw_pile.assign(cards)
	starting_deck._shuffle_draw_pile()
	if not starting_flow.begin_fight():
		starting_rng.state = rng_before
		push_warning("Starter combat bindings are invalid; run was not started")
		return false
	if starting_carryover != null and not starting_carryover.begin_battle(run_map.get_current_node_id(), starting_result, starting_party):
		starting_rng.state = rng_before
		return false
	enemy_intents = selector
	enemy_attacks = enemy_intents.get_intents()
	party = starting_party
	enemies = starting_enemies
	run_rng = starting_rng
	deck = starting_deck
	run_deck = cards.duplicate()
	battle_result = starting_result
	act_outcome = starting_outcome
	party_carryover = starting_carryover
	if party_carryover != null:
		_carryover_map = weakref(run_map)
		_carryover_revision = run_map.get_generation_revision()
		_carryover_node = run_map.get_current_node_id()
		_carryover_route = run_map.get_route()
		_carryover_floors = run_map.get_floors()
		_carryover_party = party
		_carryover_result = battle_result
	round_flow = starting_flow
	victory_gold = RunVictoryGold.new(battle_result)
	session_gold = 0
	run_scraps = 0
	run_stitch_descriptors.clear()
	run_next_stitch_id = 1
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
	for side in ["left", "right"]:
		battle_view.add_theme_constant_override("margin_" + side, 32)
	# The side-view stage owns the top of the screen edge to edge; the hand and action
	# bar keep their own rows so nothing is pushed below the 720 px viewport.
	for side in ["top", "bottom"]:
		battle_view.add_theme_constant_override("margin_" + side, 0)
	add_child(battle_view)
	var column := VBoxContainer.new()
	# Compact rows keep the large actor stage, the hero meters, five cards and the
	# action row inside 1280x720 even when every meter shows status and Bleed lines.
	column.add_theme_constant_override("separation", 2)
	battle_view.add_child(column)
	hero_view = HBoxContainer.new()
	hero_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_view.add_theme_constant_override("separation", 16)
	column.add_child(hero_view)
	for index in range(CombatParty.PARTY_SIZE):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, STAGE_ACTOR_HEIGHT)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# The battle stage shows unboxed actors: drop the shared framed panel here only,
		# so the theme keeps its boxed look on every other screen.
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		hero_view.add_child(panel)
		hero_panels.append(panel)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	heading.add_theme_font_size_override("font_size", 24)
	previews.add_child(heading)
	for pair in [1, 2]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(240, 32)
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
	hand_view.name = "SharedHand"
	hand_view.custom_minimum_size.y = 120
	# The stage above owns the free vertical space; the card row keeps its own height.
	hand_view.size_flags_vertical = Control.SIZE_FILL
	hand_view.add_theme_constant_override("separation", 16)
	hand_view.sort_children.connect(_fan_hand, CONNECT_DEFERRED)
	column.add_child(hand_view)
	var support_hud := HBoxContainer.new()
	support_hud.name = "SupportHUD"
	support_hud.custom_minimum_size.y = 76
	support_hud.add_theme_constant_override("separation", 16)
	column.add_child(support_hud)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	support_hud.add_child(actions)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	end_turn_button = Button.new()
	end_turn_button.text = "End Turn"
	end_turn_button.custom_minimum_size = Vector2(240, 48)
	end_turn_button.pressed.connect(_end_turn.bind(end_turn_button))
	actions.add_child(end_turn_button)
	return_button = Button.new()
	return_button.text = "Return to title"
	return_button.custom_minimum_size = Vector2(240, 48)
	return_button.pressed.connect(_return_from_battle.bind(return_button))
	actions.add_child(return_button)
	_mount_juice_action(actions)
	_refresh_swap_preview()


## Presentation hook: the battle-independent juice node owns its Fast toggle button.
func _mount_juice_action(actions: HBoxContainer) -> void:
	var juice = get_node_or_null("LiveCombatJuice")
	if juice != null:
		juice.attach_fast_button(actions)


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
	# End Turn still leads to Return; the Fast toggle follows it during the live turn.
	var juice = get_node_or_null("LiveCombatJuice")
	if not _battle_closed and juice != null and is_instance_valid(juice.fast_button):
		actions.append(juice.fast_button)
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
	if run_map != null and (not _current_carryover_fight() \
		or run_map.get_node(_carryover_node).get("type") not in ["Fight", "Elite"]):
		return
	if run_map != null and (fight_rewards != null or multi_fight_rewards != null):
		return
	var offers: Array = []
	var party_ids: Array[String] = []
	for hero in party.get_heroes():
		party_ids.append(hero.id)
	var catalog := StarterCards.new()
	var ids: Array = INTERIM_REWARD_IDS
	if run_map != null:
		var prepared: Dictionary
		if _carryover_route.size() == 1 and run_map.get_node(_carryover_node).get("type") == "Fight":
			if not party_carryover.read_state().completed_fights.has(_carryover_node):
				return
			fight_rewards = RunFightVictoryRewards.new(battle_result, run_rng, party_ids,
				catalog.get_all_card_ids(), run_deck, session_gold, false)
			prepared = fight_rewards.prepare()
		else:
			multi_fight_rewards = RunMultiFightRewards.new(run_map, run_rng, party_carryover,
				run_deck, session_gold, run_trinkets, catalog.get_all_card_ids(), _catalog_trinket_ids())
			prepared = multi_fight_rewards.prepare(_carryover_node, battle_result, party)
		if not prepared.ok:
			fight_rewards = null
			multi_fight_rewards = null
			return
		fight_reward_offers = prepared.offers
		fight_reward_gold = prepared.gold_award
		fight_reward_trinket = prepared.trinket_drop_id
		_reward_map = weakref(run_map)
		_mount_reward_choice(prepared)
		return
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
		button.pressed.connect(_claim_card_reward.bind(id, button, _routed_reward_service() if run_map != null else card_reward))


func _mount_reward_choice(prepared: Dictionary) -> void:
	reward_choice_panel = load("res://scenes/run_card_reward_choice_panel.tscn").instantiate()
	add_child(reward_choice_panel)
	if not reward_choice_panel.open_rewards(_carryover_node,
		run_map.get_node(_carryover_node).type, prepared):
		_clear_reward_choice()
		return
	reward_buttons = reward_choice_panel.get_choice_buttons()
	for button in reward_buttons:
		var callback: Callable = button.pressed.get_connections()[0].callable
		button.pressed.disconnect(callback)
		button.pressed.connect(_forward_reward_choice.bind(weakref(reward_choice_panel), callback))
	# Existing post-claim Elite presentation mounts beside this empty reward slot.
	var slot := HBoxContainer.new()
	slot.name = "CardReward"
	slot.add_child(Label.new())
	hand_view.add_child(slot)
	reward_choice_panel.choice_requested.connect(_request_routed_reward.bind(
		weakref(reward_choice_panel), _routed_reward_service()))
	_reward_return_parent = weakref(return_button.get_parent())
	return_button.reparent(reward_choice_panel)
	return_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	return_button.custom_minimum_size = Vector2(240, 48)
	return_button.position = Vector2(20, 666)
	return_button.size = Vector2(240, 48)
	return_button.focus_next = return_button.get_path_to(reward_buttons[0])
	return_button.focus_previous = return_button.get_path_to(reward_buttons[3])


func _forward_reward_choice(source: WeakRef, callback: Callable) -> void:
	if source != null and source.get_ref() == reward_choice_panel \
		and is_instance_valid(reward_choice_panel) and reward_choice_panel.get_parent() == self \
		and reward_choice_panel.is_visible_in_tree() and callback.is_valid():
		callback.call()


func _request_routed_reward(node_id: String, id: String, source: WeakRef, offering) -> void:
	if not is_instance_valid(reward_choice_panel) or source == null \
		or source.get_ref() != reward_choice_panel or reward_choice_panel.get_parent() != self \
		or not reward_choice_panel.is_visible_in_tree() or not reward_choice_panel._awaiting_ack \
		or reward_choice_panel._accepted:
		return
	var accepted: bool = node_id == _carryover_node and reward_choice_panel._node_id == node_id \
		and _settle_routed_reward(id, offering)
	reward_choice_panel.acknowledge(accepted)
	if accepted:
		reward_choice_panel.paper_panel.hide()
		reward_choice_panel.get_node("SlateBackdrop").hide()
		reward_choice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _clear_reward_choice() -> void:
	if is_instance_valid(reward_choice_panel):
		if is_instance_valid(return_button) and return_button.get_parent() == reward_choice_panel \
			and _reward_return_parent != null and is_instance_valid(_reward_return_parent.get_ref()):
			return_button.reparent(_reward_return_parent.get_ref())
		reward_choice_panel.close_rewards()
		if reward_choice_panel.get_parent() != null:
			reward_choice_panel.get_parent().remove_child(reward_choice_panel)
		reward_choice_panel.queue_free()
	reward_choice_panel = null
	_reward_return_parent = null
	if run_map != null:
		reward_buttons.clear()


## Elite drops use the existing Shop catalog; no separate reward pool.
func _catalog_trinket_ids() -> Array:
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
	if not catalog is Dictionary or not catalog.get("trinkets") is Array:
		return []
	var ids: Array = []
	for entry in catalog.trinkets:
		if not entry is Dictionary or not entry.get("id") is String:
			return []
		ids.append(entry.id)
	return ids


func _routed_reward_service():
	return multi_fight_rewards if multi_fight_rewards != null else fight_rewards


func _settle_routed_reward(id: String, offering) -> bool:
	if offering != _routed_reward_service() or fight_reward_claimed or _reward_map == null \
		or _reward_map.get_ref() != run_map or run_map == null or not _battle_closed \
		or not _current_carryover_fight() \
		or battle_result == null or battle_result._party != party or battle_result._enemies != enemies \
		or battle_result.get_outcome() != CombatBattleResult.VICTORY \
		or party == null or not party.is_valid() or party.is_defeated() \
		or not is_instance_valid(reward_choice_panel) or not reward_choice_panel._awaiting_ack:
		return false
	if fight_reward_offers.size() != 3 or (not id.is_empty() and not fight_reward_offers.any(
		func(offer: Dictionary) -> bool: return offer.id == id)):
		return false
	if offering is RunFightVictoryRewards:
		if offering._battle != battle_result or offering._rng != run_rng \
			or offering._source_deck != run_deck or offering._starting_gold != session_gold \
			or offering._owned_trinket_ids != run_trinkets:
			return false
	if offering is RunMultiFightRewards:
		if offering._map != run_map or offering._rng != run_rng or offering._carry != party_carryover \
			or offering.read_state().deck != run_deck or offering.read_state().gold != session_gold \
			or offering.read_state().party.heroes != run_heroes \
			or offering.read_state().trinkets != run_trinkets:
			return false
	var torn_carry := party_carryover as RunTornCarryover
	if torn_carry == null or torn_carry.read_state().heroes != run_heroes \
		or torn_carry.preview_reward(_carryover_node, battle_result, party) == null:
		return false
	var result: Dictionary = offering.choose(_carryover_node, id) if offering is RunMultiFightRewards else offering.choose(id)
	if not result.ok:
		return false
	var carried := torn_carry.apply_reward(_carryover_node, battle_result, party)
	if not carried.ok:
		return false
	var settled: Dictionary = result.state if offering is RunMultiFightRewards else result
	run_deck.assign(settled.deck)
	session_gold = settled.gold
	if offering is RunMultiFightRewards:
		run_trinkets.assign(settled.trinkets)
	run_heroes = carried.heroes.duplicate(true)
	run_scraps += 2 if run_map.get_node(_carryover_node).get("type") == "Elite" else 1
	_sync_bound_wardrobe(torn_carry)
	fight_reward_claimed = true
	result_label.text = "Battle result: victory | Gold: %d" % session_gold
	_finish_card_reward(offering)
	$LiveElitePatchSewing.observe_claim(offering, result)
	return true

## A confirmed routed reward publishes new run resources. A wardrobe bound at an
## earlier routed Shop receives exactly those committed values through its own
## snapshot guard, so the same object, worn slots and operation IDs carry on
## while unsolicited ledger drift still fails closed.
func _sync_bound_wardrobe(carry: RunTornCarryover) -> void:
	if carry == null:
		return
	var wardrobe := carry._wardrobe
	if wardrobe == null or not wardrobe.is_valid():
		return
	wardrobe.refresh_run_context(run_heroes, run_trinkets, run_scraps,
		session_gold, run_deck, wardrobe.get_snapshot())


func _claim_card_reward(id: String, button, offering) -> void:
	if offering is RunFightVictoryRewards or offering is RunMultiFightRewards:
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
		continue_button.custom_minimum_size = Vector2(160, 48)
		return_button.get_parent().add_child(continue_button)
		continue_button.pressed.connect(_continue_to_rest_route.bind(offering, weakref(run_map), continue_button))
		continue_button.position = Vector2(1000, 666)
		continue_button.size = Vector2(240, 48)
		continue_button.focus_next = continue_button.get_path_to(return_button)
		return_button.focus_next = return_button.get_path_to(continue_button)
	_refresh_swap_preview()
	return_button.grab_focus()


## The terminal Fight stays separate from persistent run data and future encounters.
func _can_leave_fight() -> bool:
	return _current_carryover_fight() \
		and run_map.get_node(run_map.get_current_node_id()).get("type") in ["Fight", "Elite"] \
		and _battle_closed and battle_result != null \
		and battle_result._party == party and battle_result._enemies == enemies \
		and battle_result.get_outcome() == CombatBattleResult.VICTORY \
		and party != null and party.is_valid() and not party.is_defeated() \
		and _routed_reward_service() != null and fight_reward_claimed \
		and party_carryover != null and party_carryover.read_state().heroes == run_heroes \
		and (multi_fight_rewards == null or (party_carryover.read_state().completed_fights.has(_carryover_node) \
			and party_carryover.read_state().heroes == run_heroes \
			and multi_fight_rewards.read_state().trinkets == run_trinkets)) \
		and RunRestRecovery._is_valid_roster(run_heroes)


func _continue_to_rest_route(offering, source_map: WeakRef, button) -> void:
	if not _can_leave_fight() or offering != _routed_reward_service() or source_map == null \
		or source_map.get_ref() != run_map or not is_instance_valid(button) \
		or button != continue_button or button.disabled or not button.is_visible_in_tree() \
		or is_instance_valid(route_view) or (is_instance_valid(rest_view) and rest_view.visible):
		return
	button.disabled = true
	_clear_reward_choice()
	battle_view.hide()
	_present_connected_route(source_map)


func _present_connected_route(source_map: WeakRef) -> void:
	_connected_map = source_map
	_connected_route = run_map.get_route()
	# Only legitimate visit completion refreshes committed run resources. Rejected
	# input callbacks must never repair a drifted wardrobe or roster.
	var carry := party_carryover as RunTornCarryover
	if carry != null and carry._wardrobe != null and _can_choose_connected_route():
		var wardrobe := carry._wardrobe
		wardrobe.refresh_run_context(run_heroes, run_trinkets, run_scraps,
			session_gold, run_deck, wardrobe.get_snapshot())
	route_view = VBoxContainer.new()
	route_view.set_anchors_preset(Control.PRESET_CENTER)
	route_view.add_theme_constant_override("separation", 8)
	add_child(route_view)
	var heading := Label.new()
	heading.text = "Connected route - choose your next node"
	route_view.add_child(heading)
	var wallet := Label.new()
	wallet.text = "Gold: %d | Scraps: %d | Mend: %d scraps" % [
		session_gold, run_scraps, RunMapMendChoices.MEND_COST]
	route_view.add_child(wallet)
	_present_route_patch_summary(carry)
	var prior := run_map.get_route()
	for id in run_map.get_legal_choices():
		var node := run_map.get_node(id)
		var action := Button.new()
		action.text = "%s: %s" % [id, node.type]
		action.set_meta("route_id", id)
		action.set_meta("route_kind", node.type)
		action.disabled = node.type not in ["Rest", "Shop", "Event", "Treasure", "Fight", "Elite", "Boss"]
		if action.disabled:
			action.text += " (unavailable)"
		action.custom_minimum_size = Vector2(440, 48)
		action.pressed.connect(_dispatch_route.bind(id, source_map, prior, action))
		route_view.add_child(action)
		route_buttons.append(action)
	var context := _map_mend_context()
	var mends := _project_map_mends()
	if mends.get("ok") == true:
		for option in mends.options:
			var mend := Button.new()
			mend.text = "Mend %s (position %d) - %d scraps, to %d HP" % [
				String(option.hero_id).capitalize(), option.position,
				option.cost, option.post_mend_hp]
			mend.set_meta("hero_id", option.hero_id)
			mend.set_meta("hero_position", option.position)
			mend.set_meta("mend_option", option.duplicate(true))
			mend.custom_minimum_size = Vector2(440, 40)
			mend.disabled = option.affordable != true or not _can_choose_connected_route()
			route_view.add_child(mend)
			map_mend_buttons.append(mend)
			mend.pressed.connect(_choose_map_mend.bind(option.hero_id, option.position,
				weakref(mend), weakref(route_view), context))
		if map_mend_buttons.is_empty():
			_append_map_mend_unavailable("Mend unavailable - no torn heroes")
	else:
		_append_map_mend_unavailable("Mend unavailable - invalid source")
	route_map_button = Button.new()
	route_map_button.text = "View full map"
	route_view.add_child(route_map_button)
	route_map_button.pressed.connect(_open_route_atlas.bind(
		weakref(run_map), weakref(route_view), weakref(route_map_button)))
	route_back_button = Button.new()
	route_back_button.text = "Return to title"
	route_back_button.pressed.connect(_return_from_visit.bind(route_view))
	route_view.add_child(route_back_button)
	_focus_visit(route_view)


func _present_route_patch_summary(carry: RunTornCarryover) -> void:
	var readout := HBoxContainer.new()
	readout.name = "PatchWearerSummary"
	readout.add_theme_constant_override("separation", 12)
	route_view.add_child(readout)
	var unavailable := ""
	var summary: Dictionary = {}
	if carry == null:
		unavailable = "Patches unavailable - no carryover"
	elif carry.torn == null:
		unavailable = "Patches unavailable - invalid source"
	elif carry._wardrobe == null:
		# A pre-Shop run legitimately owns nothing yet. Owned patches without a
		# bound wardrobe, or a corrupted ledger, must never look empty.
		if not run_trinkets.is_empty():
			unavailable = "Patches unavailable - no wardrobe bound"
		elif not carry.is_valid() or carry._observer() == null:
			unavailable = "Patches unavailable - invalid source"
		else:
			var empty_message := Label.new()
			empty_message.text = "No patches sewn"
			readout.add_child(empty_message)
			return
	else:
		summary = RunPatchWearerSummary.summarize(carry._wardrobe, carry.torn.read_state())
		if not summary.ok:
			unavailable = "Patches unavailable - invalid source"
	if not unavailable.is_empty():
		var message := Label.new()
		message.text = unavailable
		readout.add_child(message)
		return
	for hero in summary.heroes:
		var status := Label.new()
		status.set_meta("hero_id", hero.id)
		status.custom_minimum_size.x = 300
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.add_theme_font_size_override("font_size", 14)
		status.text = "%s - patches" % hero.id.capitalize()
		for slot in hero.slots:
			var worn: String = "empty"
			if not slot.patch_id.is_empty():
				worn = "%s (%s)" % [slot.patch_id, "active" if slot.active else "inactive"]
				# Only the validated, nonempty text supplied by the service is
				# shown; slot-only patches never gain invented rules.
				if not slot.rules_text.is_empty():
					worn += " - %s" % slot.rules_text
			status.text += "\n%s: %s" % [slot.slot, worn]
		readout.add_child(status)


func _append_map_mend_unavailable(message: String) -> void:
	var unavailable := Button.new()
	unavailable.text = message
	unavailable.disabled = true
	unavailable.custom_minimum_size = Vector2(440, 40)
	route_view.add_child(unavailable)
	map_mend_buttons.append(unavailable)


## The canonical map Mend projection owns hero, slot, cost and post-Mend HP.
## The view only renders those values; an invalid live authority yields nothing
## actionable instead of a re-derived price or healing rule.
func _project_map_mends() -> Dictionary:
	var carry := party_carryover as RunTornCarryover
	if carry == null:
		return {"ok": false, "options": []}
	var wardrobe: Variant = null
	if carry._wardrobe != null:
		wardrobe = carry._wardrobe.get_snapshot()
	return RunMapMendChoices.project(carry, carry.read_state(), wardrobe, run_scraps, true)


func _map_mend_context() -> Array:
	var carry := party_carryover as RunTornCarryover
	if carry == null or run_map == null or run_rng == null:
		return []
	return [run_map, run_map.get_generation_revision(), run_map.get_floors(), run_map.get_route(),
		run_rng, run_rng.state, carry, carry.read_state(), carry.torn.read_state(),
		run_heroes.duplicate(true), run_scraps, session_gold, run_deck.duplicate(),
		run_trinkets.duplicate(), carry._wardrobe,
		null if carry._wardrobe == null else carry._wardrobe.get_snapshot(),
		fight_reward_claimed, _routed_reward_service(), act_outcome.get_state(),
		run_stitch_descriptors.duplicate(true), run_next_stitch_id, run_removal_count, _map_mend_serial]


func _choose_map_mend(hero: Variant, position: Variant, source_action: WeakRef,
		source_view: WeakRef, expected: Array) -> void:
	if not _can_choose_connected_route() or not is_instance_valid(route_view) \
		or source_view == null or source_view.get_ref() != route_view \
		or route_view.get_parent() != self or not route_view.is_visible_in_tree() \
		or source_action == null or not is_instance_valid(source_action.get_ref()) \
		or expected.is_empty() or _map_mend_context() != expected \
		or typeof(hero) != TYPE_STRING or typeof(position) != TYPE_INT:
		return
	var button = source_action.get_ref()
	if button not in map_mend_buttons or button.get_parent() != route_view \
		or button.disabled or not button.is_visible_in_tree() \
		or button.get_meta("hero_id", "") != hero or button.get_meta("hero_position", 0) != position:
		return
	var carry := party_carryover as RunTornCarryover
	# Reproject from the live authority: only an exact offered option (identity
	# AND slot) may name a canonical price or post-Mend HP.
	var view := _project_map_mends()
	if carry == null or view.get("ok") != true:
		return
	var option: Dictionary = {}
	for offered in view.options:
		if offered.get("hero_id") == hero and offered.get("position") == position:
			option = offered
			break
	if option.is_empty() or button.get_meta("mend_option", {}) != option:
		return
	var wardrobe: Variant = null
	if carry._wardrobe != null:
		wardrobe = carry._wardrobe.get_snapshot()
	var operation := "map_mend:%d" % _map_mend_serial
	var result := RunMapMendChoices.choose(carry, option, operation, operation + ":receipt",
		carry.read_state(), wardrobe, run_scraps, true)
	if result.get("ok") != true:
		return
	run_heroes = result.heroes
	run_scraps = result.remaining_scraps
	_map_mend_serial += 1
	# The completed visit's original wallet/hero guards describe its own
	# transaction. Preserve admission for this exact subsequent map transaction.
	_mended_route_context = _map_mend_context()
	var source := _connected_map
	_clear_route_view()
	_present_connected_route(source)


## Zero completed fights is legal only for this run's witnessed noncombat prefix.
func _unfought_run() -> bool:
	var carry := party_carryover as RunTornCarryover
	if carry == null or not carry.is_valid() or run_map == null or run_rng == null \
		or _carryover_map == null or _carryover_map.get_ref() != run_map \
		or _carryover_revision != run_map.get_generation_revision() \
		or _carryover_floors != run_map.get_floors() or deck != null or battle_result != null \
		or is_instance_valid(battle_view) or not carry._node.is_empty() \
		or carry.read_state().heroes != run_heroes or not carry.read_state().completed_fights.is_empty() \
		or carry._observer() == null or act_outcome == null or act_outcome._map != run_map \
		or act_outcome.get_state() != {"run_status": RunActBattleOutcome.ACTIVE,
			"pending_node_id": "", "settled_node_ids": []} or act_outcome._pending_result != null:
		return false
	for id in run_map.get_route():
		if run_map.get_node(id).get("type") not in ["Rest", "Shop", "Event", "Treasure"]:
			return false
	if run_map.get_route().is_empty():
		return run_deck == _load_starter_deck() and run_heroes == carry._initial \
			and carry.read_state().completed_rests.is_empty() and LiveWebPlaytestBoot.has_opening_wallet(self) \
			and run_trinkets.is_empty() and run_removal_count == 0 \
			and run_stitch_descriptors.is_empty() and run_next_stitch_id == 1
	return true


func _can_choose_connected_route() -> bool:
	if is_instance_valid(quiet_spool_panel):
		return false
	if run_map == null or _connected_map == null or _connected_map.get_ref() != run_map \
		or run_map.get_route() != _connected_route or not RunRestRecovery._is_valid_roster(run_heroes) \
		or act_outcome == null or act_outcome._map != run_map \
		or act_outcome.get_state().run_status != RunActBattleOutcome.ACTIVE \
		or not act_outcome.get_state().pending_node_id.is_empty() or act_outcome._pending_result != null:
		return false
	if party_carryover == null or not party_carryover.is_valid() \
		or party_carryover.read_state().heroes != run_heroes:
		return false
	if not _mended_route_context.is_empty() and _mended_route_context == _map_mend_context():
		return true
	if party_carryover.read_state().completed_fights.is_empty() and not _unfought_run():
		return false
	if run_map.get_route().is_empty():
		return _unfought_run()
	if run_map.get_node(run_map.get_current_node_id()).get("type") in ["Fight", "Elite"]:
		return _can_leave_fight()
	if run_map.get_node(run_map.get_current_node_id()).get("type") == "Rest":
		return _current_completed_rest() and is_instance_valid(rest_view) and not rest_view.visible \
			and is_instance_valid(rest_continue_button) and rest_continue_button.disabled
	if run_map.get_node(run_map.get_current_node_id()).get("type") in ["Event", "Treasure"]:
		return _placeholder_map != null and _placeholder_map.get_ref() == run_map \
			and not _placeholder_route.is_empty() and run_map.get_route() == _placeholder_route
	return _current_shop_ledger("closed")


## Stage every combat model before replacing the last mounted battle. The entry
## service shares the run selector/RNG; restore both if later admission fails.
func _choose_battle_route(id: String, source_map: WeakRef, prior: Array[String], button) -> bool:
	if not _can_choose_connected_route() or source_map == null or source_map.get_ref() != run_map \
		or run_map.get_route() != prior or not is_instance_valid(route_view) \
		or not route_view.is_visible_in_tree() or not is_instance_valid(button) \
		or button not in route_buttons or button.get_parent() != route_view \
		or button.disabled or not button.is_visible_in_tree() or button.get_meta("route_id") != id \
		or not run_map.get_legal_choices().has(id) \
		or run_map.get_node(id).get("type") not in ["Fight", "Elite", "Boss"] \
		or run_rng == null or fight_selection == null or party_carryover == null \
		or _carryover_map == null or _carryover_map.get_ref() != run_map:
		return false
	var ledger := party_carryover.read_state()
	if not ledger.ok or ledger.heroes != run_heroes or (ledger.completed_fights.is_empty() and not _unfought_run()) \
		or act_outcome.get_state().settled_node_ids.has(id) \
		or ledger.completed_fights.has(id) or run_deck.size() < CombatDeck.TURN_DRAW:
		return false
	# Rest composites are run-owned cards, validated against their full ledger.
	var stitch_ledger := RunRestStitchCards.new(run_deck, run_stitch_descriptors, run_scraps, run_next_stitch_id)
	if not stitch_ledger.is_valid():
		return false
	var snapshot := stitch_ledger.get_snapshot()
	var next_party := party_carryover.create_next_fight_party()
	if next_party == null:
		return false
	var rng_before := run_rng.state
	var bound_before := fight_selection._bound_map
	var selected_before := fight_selection._selected.duplicate(true)
	var torn_carry := party_carryover as RunTornCarryover
	if torn_carry == null:
		return false
	var witness_before := [torn_carry._node, torn_carry._result, torn_carry._party, torn_carry._start.duplicate(true)]
	if not run_map.choose_node(id):
		return false
	var entry := RunAuthoredBattleEntry.new().entry_current_battle(run_map, run_rng, fight_selection)
	var staged := false
	var next_deck: CombatDeck
	var next_result: CombatBattleResult
	var next_flow: CombatRoundFlow
	if entry.get("success", false):
		var admission := RunStitchedBattleHandEntry.new().admit_next_fight(
			run_deck, run_stitch_descriptors, run_scraps, run_next_stitch_id, snapshot.receipt, run_rng)
		if admission.get("ok", false) and admission.snapshot == snapshot:
			next_deck = admission.combat_deck
			next_result = CombatBattleResult.new(next_party, entry.enemies)
			next_flow = CombatRoundFlow.new(next_deck, next_party, entry.enemies, entry.intents, next_result)
			staged = next_flow.begin_fight()
			if staged:
				staged = torn_carry.begin_battle(id, next_result, next_party)
	if not staged or not act_outcome.begin_current_battle(next_result):
		run_map.undo_choice(id, prior)
		run_rng.state = rng_before
		fight_selection._bound_map = bound_before
		fight_selection._selected = selected_before
		torn_carry._node = witness_before[0]
		torn_carry._result = witness_before[1]
		torn_carry._party = witness_before[2]
		torn_carry._start = witness_before[3]
		return false
	# No fallible model work remains. Detach old controls before mounting fresh ones.
	$LiveSupportHand._cancel_pending()
	_clear_route_view()
	if is_instance_valid(battle_view):
		remove_child(battle_view)
		battle_view.queue_free()
	hero_panels.clear()
	swap_preview_buttons.clear()
	_swap_preview_pair = 0
	reward_buttons.clear()
	continue_button = null
	card_reward = null
	fight_rewards = null
	multi_fight_rewards = null
	fight_reward_offers.clear()
	fight_reward_gold = 0
	fight_reward_trinket = ""
	fight_reward_claimed = false
	_reward_map = null
	party = next_party
	enemies = entry.enemies
	enemy_intents = entry.intents
	enemy_attacks = enemy_intents.get_intents()
	deck = next_deck
	battle_result = next_result
	round_flow = next_flow
	encounter_id = entry.encounter_id
	victory_gold = RunVictoryGold.new(battle_result)
	_carryover_node = id
	_carryover_revision = run_map.get_generation_revision()
	_carryover_route = run_map.get_route()
	_carryover_floors = run_map.get_floors()
	_carryover_party = party
	_carryover_result = battle_result
	_battle_closed = false
	_build_battle()
	_refresh_hand()
	_refresh_party()
	_refresh_enemy_roster()
	end_turn_button.grab_focus()
	return true


func _choose_placeholder_route(id: String, source_map: WeakRef, prior: Array[String], button) -> bool:
	if not _can_choose_connected_route() or run_rng == null or run_deck.is_empty() \
		or source_map == null or source_map.get_ref() != run_map or run_map.get_route() != prior \
		or not is_instance_valid(route_view) or not route_view.is_visible_in_tree() \
		or not is_instance_valid(button) or button not in route_buttons \
		or button.get_parent() != route_view or button.disabled or not button.is_visible_in_tree() \
		or button.get_meta("route_id") != id or not run_map.get_legal_choices().has(id) \
		or run_map.get_node(id).get("type") not in ["Event", "Treasure"]:
		return false
	if run_map.get_node(id).type == "Event" and not _quiet_spool_completed:
		return _open_quiet_spool(id, source_map)
	if not run_map.choose_node(id):
		return false
	_placeholder_map = source_map
	_placeholder_route = run_map.get_route()
	_clear_route_view()
	_present_connected_route(source_map)
	return true


func _load_quiet_spool() -> Dictionary:
	if not FileAccess.file_exists(event_catalog_path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(event_catalog_path)) != OK:
		return {}
	var catalog: Variant = parser.data
	if not catalog is Dictionary or not catalog.get("events") is Array:
		return {}
	var matches: Array = catalog.events.filter(func(record):
		return record is Dictionary and record.get("id") == "quiet_spool")
	if matches.size() != 1 or not RunEventChoice.new(matches[0]).is_valid():
		return {}
	var record: Dictionary = matches[0]
	if record.choices.size() != 2:
		return {}
	var ids: Array = []
	for choice in record.choices:
		ids.append(choice.id)
	if not ids.has("watch") or not ids.has("ignore"):
		return {}
	for id in ["watch", "ignore"]:
		var receipt := RunEventChoice.new(record).choose_with_wallet(id, {"gold": 0, "scraps": 0})
		if not receipt.ok or receipt.wallet != {"gold": 0, "scraps": 1 if id == "watch" else 0}:
			return {}
	return record


func _quiet_spool_snapshot() -> Array:
	if run_map == null or run_rng == null or party_carryover == null or act_outcome == null \
		or not is_instance_valid(quiet_spool_panel) or quiet_spool_panel._selector == null:
		return []
	var carry := party_carryover as RunTornCarryover
	if carry == null:
		return []
	return [run_map, run_map.get_generation_revision(), run_map.get_floors(),
		run_map.get_route(), run_rng, run_rng.state, run_seed, run_deck.duplicate(),
		run_heroes.duplicate(true), run_trinkets.duplicate(), session_gold, run_scraps,
		run_removal_count, run_stitch_descriptors.duplicate(true), run_next_stitch_id,
		carry, carry.read_state(), carry.torn.read_state(), carry._wardrobe,
		carry._wardrobe.get_snapshot() if carry._wardrobe != null else {},
		act_outcome, act_outcome.get_state(), quiet_spool_panel, _quiet_spool_outcome,
		quiet_spool_panel._selector, quiet_spool_panel._selector.get_event()]


func _open_quiet_spool(id: String, source: WeakRef) -> bool:
	var record := _load_quiet_spool()
	if record.is_empty() or run_scraps < 0 or run_scraps == 9223372036854775807:
		return false
	var panel := preload("res://scenes/event_choice_panel.tscn").instantiate() as LiveEventChoicePanel
	add_child(panel)
	if not panel.open_event(record):
		panel.free()
		return false
	if not run_map.choose_node(id):
		panel.free()
		return false
	_clear_route_view()
	quiet_spool_panel = panel
	_quiet_spool_outcome = RunQuietSpoolOutcome.new()
	_quiet_spool_context = _quiet_spool_snapshot()
	panel.choice_committed.connect(_commit_quiet_spool.bind(panel, _quiet_spool_outcome, source))
	var buttons := panel.get_choice_buttons()
	for index in range(buttons.size()):
		buttons[index].focus_next = buttons[index].get_path_to(buttons[(index + 1) % buttons.size()])
		buttons[index].focus_previous = buttons[index].focus_next
	buttons[0].grab_focus()
	return true


func _commit_quiet_spool(event_id: String, choice_id: String, panel,
		outcome: RunQuietSpoolOutcome, source: WeakRef) -> void:
	if not is_instance_valid(panel) or panel != quiet_spool_panel or panel.get_parent() != self \
		or not panel.is_visible_in_tree() or not panel.has_open_event() \
		or outcome == null or outcome != _quiet_spool_outcome or outcome.is_consumed() \
		or source == null or source.get_ref() != run_map \
		or _quiet_spool_context.is_empty() or _quiet_spool_snapshot() != _quiet_spool_context \
		or panel._selector == null or not panel._selector.is_claimed() \
		or panel._committed_choice != {"ok": true, "event_id": event_id, "choice_id": choice_id} \
		or event_id != "quiet_spool" or choice_id not in ["watch", "ignore"]:
		return
	var receipt := outcome.choose(event_id, choice_id, run_scraps)
	if not receipt.ok:
		return
	run_scraps = receipt.scraps
	_quiet_spool_completed = true
	_placeholder_map = source
	_placeholder_route = run_map.get_route()
	_clear_quiet_spool()
	_present_connected_route(source)


func _clear_quiet_spool() -> void:
	_quiet_spool_context.clear()
	_quiet_spool_outcome = null
	if is_instance_valid(quiet_spool_panel):
		quiet_spool_panel.close_event()
		remove_child(quiet_spool_panel)
		quiet_spool_panel.queue_free()
	quiet_spool_panel = null


func _current_completed_rest() -> bool:
	return rest_recovery != null and ((rest_recovery.is_consumed() and _rest_committed_deck.is_empty() \
		and rest_stitch != null and not rest_stitch.is_consumed() \
		and rest_upgrade != null and not rest_upgrade.is_consumed() \
		and _stitch_snapshot() == _rest_stitch_source) or _completed_rest_upgrade() or _completed_rest_stitch()) \
		and run_map != null and _rest_map != null and _rest_map.get_ref() == run_map \
		and not _rest_route.is_empty() and run_map.get_route() == _rest_route \
		and run_map.get_node(run_map.get_current_node_id()).get("type") == "Rest" \
		and not _rest_committed_heroes.is_empty() and run_heroes == _rest_committed_heroes \
		and RunRestRecovery._is_valid_roster(run_heroes)


func _rest_upgrade_context() -> bool:
	return (_rest_wardrobe == null or _rest_patch_current(not rest_view.visible)) \
		and run_map != null and _rest_map != null and _rest_map.get_ref() == run_map \
		and not _rest_route.is_empty() and run_map.get_route() == _rest_route \
		and run_map.get_current_node_id() == _rest_route.back() \
		and run_map.get_node(_rest_route.back()).get("type") == "Rest" \
		and run_map.get_floors() == _rest_floors and run_map.get_generation_revision() == _rest_revision \
		and run_heroes == _rest_heroes and RunRestRecovery._is_valid_roster(run_heroes) \
		and party_carryover != null and party_carryover == _rest_carry \
		and _carryover_map != null and _carryover_map.get_ref() == run_map \
		and party_carryover.read_state() == _rest_ledger and _rest_ledger.get("ok", false) \
		and _rest_ledger.get("heroes") == run_heroes \
		and not _rest_ledger.get("completed_rests", []).has(_rest_route.back()) \
		and run_rng != null and run_rng == _rest_rng and run_rng.state == _rest_rng_state \
		and session_gold == _rest_gold and [run_trinkets, run_removal_count] == _rest_inventory


func _completed_rest_upgrade() -> bool:
	return rest_upgrade != null and rest_upgrade.is_consumed() \
		and rest_recovery != null and not rest_recovery.is_consumed() \
		and not _rest_committed_deck.is_empty() and run_deck == _rest_committed_deck \
		and run_scraps == _rest_stitch_source.remaining_scraps \
		and run_stitch_descriptors == _rest_stitch_source.descriptors \
		and run_next_stitch_id == _rest_stitch_source.next_stitch_id \
		and (rest_stitch == null or not rest_stitch.is_consumed()) \
		and _rest_upgrade_context()


func _upgrade_at_rest(visit: RunRestCardUpgrade, button, choices) -> void:
	if is_instance_valid(rest_patch_overlay) or visit == null or visit != rest_upgrade or visit.is_consumed() \
		or rest_stitch == null or rest_stitch.is_consumed() or _stitch_snapshot() != _rest_stitch_source \
		or rest_recovery == null or rest_recovery.is_consumed() or not rest_recovery._valid \
		or rest_recovery._roster != _rest_heroes or not _rest_upgrade_context() \
		or not _rest_committed_heroes.is_empty() or not _rest_committed_deck.is_empty() or run_deck != _rest_deck \
		or not visit._valid or visit._source != _rest_deck or visit._deck != _rest_deck \
		or visit._upgrades != {"warden_strike": "warden_strike_plus"} \
		or not is_instance_valid(rest_view) or rest_view.get_parent() != self or not rest_view.is_visible_in_tree() \
		or not is_instance_valid(button) or button != rest_upgrade_button or button.get_parent() != rest_view \
		or button.disabled or not button.is_visible_in_tree() \
		or not is_instance_valid(choices) or choices != rest_upgrade_cards or choices.get_parent() != rest_view \
		or choices.disabled or not choices.is_visible_in_tree():
		return
	# Validate the complete visible index list, not just the selected display name.
	var indices: Array[int] = []
	for index in range(_rest_deck.size()):
		if _rest_deck[index] == "warden_strike":
			indices.append(index)
	if choices.item_count != indices.size() or choices.selected < 0 or choices.selected >= indices.size():
		return
	for item in range(indices.size()):
		if typeof(choices.get_item_metadata(item)) != TYPE_INT \
			or choices.get_item_metadata(item) != indices[item] or choices.is_item_disabled(item) \
			or choices.get_item_text(item) != _rest_upgrade_text(indices[item]):
			return
	var catalog := StarterCards.new()
	var original := catalog.get_definition("warden_strike")
	var replacement := catalog.get_definition("warden_strike_plus")
	if replacement.get("id") != "warden_strike_plus" or replacement.get("effects") != {"damage": 7} \
		or replacement.get("cost") != 1 or replacement.get("display_name") != "Strike+":
		return
	for field in ["owner", "from_positions", "to_positions", "target_kind"]:
		if replacement.get(field) != original.get(field):
			return
	for card_id in _rest_deck:
		if not catalog.has_card(card_id):
			return
	var result := visit.choose_upgrade(indices[choices.selected])
	if not result.ok:
		return
	run_deck.assign(result.deck)
	_rest_committed_deck = run_deck.duplicate()
	_rest_committed_heroes = run_heroes.duplicate(true)
	_finish_rest_choice()


func _stitch_snapshot() -> Dictionary:
	return RunRestStitchCards.new(run_deck, run_stitch_descriptors, run_scraps, run_next_stitch_id).get_snapshot()


func _rest_stitch_text(index: int) -> String:
	var definition := StarterCards.new().get_definition(_rest_deck[index])
	return "Deck #%d: %s - %s" % [index + 1, definition.owner, definition.display_name]


func _completed_rest_stitch() -> bool:
	return rest_stitch != null and rest_stitch.is_consumed() \
		and rest_recovery != null and not rest_recovery.is_consumed() \
		and rest_upgrade != null and not rest_upgrade.is_consumed() \
		and not _rest_stitch_committed.is_empty() and _stitch_snapshot() == _rest_stitch_committed \
		and run_deck == _rest_committed_deck and _rest_upgrade_context()


func _stitch_at_rest(visit: RunRestStitchCards, button, first, second) -> void:
	if is_instance_valid(rest_patch_overlay) or visit == null or visit != rest_stitch or not visit.is_valid() or visit.is_consumed() \
		or rest_recovery == null or not rest_recovery._valid or rest_recovery.is_consumed() \
		or rest_recovery._roster != _rest_heroes or rest_upgrade == null or rest_upgrade.is_consumed() \
		or not _rest_committed_deck.is_empty() or not _rest_committed_heroes.is_empty() \
		or not _rest_upgrade_context() or run_deck != _rest_deck \
		or not is_instance_valid(rest_view) or rest_view.get_parent() != self or not rest_view.is_visible_in_tree():
		return
	for pair in [[button, rest_stitch_button], [first, rest_stitch_first], [second, rest_stitch_second]]:
		var control = pair[0]
		if not is_instance_valid(control) or control != pair[1] or control.get_parent() != rest_view \
			or control.disabled or not control.is_visible_in_tree():
			return
	var indices: Array[int] = []
	for index in range(_rest_deck.size()):
		if StarterCards.new().has_card(_rest_deck[index]):
			indices.append(index)
	for selector in [first, second]:
		if selector.item_count != indices.size() or selector.selected < 0 or selector.selected >= indices.size():
			return
		for item in range(indices.size()):
			if typeof(selector.get_item_metadata(item)) != TYPE_INT or selector.get_item_metadata(item) != indices[item] \
				or selector.is_item_disabled(item) or selector.get_item_text(item) != _rest_stitch_text(indices[item]):
				return
	var current := _stitch_snapshot()
	if current != _rest_stitch_source or visit.get_snapshot() != current or visit._source_snapshot != current:
		return
	var result := visit.choose_stitch(indices[first.selected], indices[second.selected], current)
	if not result.ok:
		return
	# Synchronous transaction: publish every result field together before enabling Continue.
	run_deck.assign(result.deck)
	run_stitch_descriptors = result.descriptors.duplicate(true)
	run_scraps = result.remaining_scraps
	run_next_stitch_id = result.next_stitch_id
	_rest_stitch_committed = visit.get_snapshot()
	_rest_committed_deck = run_deck.duplicate()
	_rest_committed_heroes = run_heroes.duplicate(true)
	_finish_rest_choice()


func _refresh_rest_stitch_guided() -> void:
	for connection in rest_stitch_guided_button.pressed.get_connections():
		rest_stitch_guided_button.pressed.disconnect(connection.callable)
	rest_stitch_guided_button.disabled = rest_recovery.is_consumed() or rest_upgrade.is_consumed() \
		or RunRestStitchPairOptions.new(rest_stitch, _rest_stitch_source).first_options().is_empty()
	rest_stitch_guided_button.pressed.connect(_open_rest_stitch.bind(rest_stitch, rest_stitch_guided_button))


func _open_rest_stitch(visit: RunRestStitchCards, button) -> void:
	if visit == null or visit != rest_stitch or not is_instance_valid(button) \
		or button != rest_stitch_guided_button or button.disabled or button.get_parent() != rest_view \
		or not button.is_visible_in_tree() or not _rest_upgrade_context() \
		or rest_recovery.is_consumed() or rest_upgrade.is_consumed() \
		or _stitch_snapshot() != _rest_stitch_source \
		or RunRestStitchPairOptions.new(visit, _rest_stitch_source).first_options().is_empty() \
		or is_instance_valid(rest_patch_overlay) or is_instance_valid(rest_stitch_overlay):
		return
	rest_stitch_overlay = Control.new()
	add_child(rest_stitch_overlay)
	rest_stitch_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.8)
	rest_stitch_overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rest_stitch_picker = LiveRestStitchPairPicker.new()
	rest_stitch_overlay.add_child(rest_stitch_picker)
	rest_stitch_picker.position = Vector2(285, 75)
	rest_stitch_picker.bind(visit, _rest_stitch_source)
	var back := Button.new()
	back.text = "Back to Rest"
	back.name = "DismissStitch"
	back.position = Vector2(315, 590)
	back.size = Vector2(650, 40)
	rest_stitch_overlay.add_child(back)
	back.pressed.connect(_dismiss_rest_stitch.bind(rest_stitch_overlay, back))
	rest_stitch_picker.stitch_requested.connect(_guided_stitch_at_rest.bind(rest_stitch_picker, rest_stitch_overlay, visit))
	var controls := [rest_stitch_picker.first_selector, rest_stitch_picker.second_selector,
		rest_stitch_picker.confirm_button, back]
	for index in range(controls.size()):
		controls[index].focus_next = controls[index].get_path_to(controls[(index + 1) % controls.size()])
		controls[index].focus_previous = controls[index].get_path_to(controls[(index - 1 + controls.size()) % controls.size()])
	back.grab_focus()


func _dismiss_rest_stitch(overlay, button) -> void:
	if not is_instance_valid(overlay) or overlay != rest_stitch_overlay or overlay.get_parent() != self \
		or not overlay.is_visible_in_tree() or not is_instance_valid(button) \
		or button != overlay.get_node("DismissStitch") or button.disabled:
		return
	_clear_rest_stitch_overlay()
	rest_stitch_guided_button.grab_focus()


func _clear_rest_stitch_overlay() -> void:
	if is_instance_valid(rest_stitch_picker):
		rest_stitch_picker.clear()
		for connection in rest_stitch_picker.stitch_requested.get_connections():
			rest_stitch_picker.stitch_requested.disconnect(connection.callable)
	if is_instance_valid(rest_stitch_overlay):
		remove_child(rest_stitch_overlay)
		rest_stitch_overlay.queue_free()
	rest_stitch_picker = null
	rest_stitch_overlay = null


func _guided_stitch_at_rest(first_index: int, second_index: int, expected: Dictionary,
		picker, overlay, visit: RunRestStitchCards) -> void:
	if not is_instance_valid(picker) or picker != rest_stitch_picker \
		or not is_instance_valid(overlay) or overlay != rest_stitch_overlay \
		or overlay.get_parent() != self or picker.get_parent() != overlay \
		or not picker.is_visible_in_tree() or visit != rest_stitch or visit == null \
		or is_instance_valid(rest_patch_overlay) or expected != _rest_stitch_source \
		or _stitch_snapshot() != expected or picker.confirm_button.disabled \
		or picker._model._service != visit:
		return
	var pair: Dictionary = picker._current_pair()
	if pair.is_empty() or pair.first_index != first_index or pair.second_index != second_index \
		or pair.source_snapshot != expected:
		return
	var rows: Array[int] = []
	for wanted in [first_index, second_index]:
		var row := -1
		for item in range(rest_stitch_first.item_count):
			if rest_stitch_first.get_item_metadata(item) == wanted:
				row = item
		if row < 0:
			return
		rows.append(row)
	rest_stitch_first.select(rows[0])
	rest_stitch_second.select(rows[1])
	_stitch_at_rest(visit, rest_stitch_button, rest_stitch_first, rest_stitch_second)


func _rest_upgrade_text(index: int) -> String:
	return "Deck #%d: Warden Strike -> Strike+ (7 damage, 1 energy)" % (index + 1)


func _finish_rest_choice() -> void:
	_clear_rest_stitch_overlay()
	rest_stitch_guided_button.disabled = true
	_sync_rest_patches()
	rest_heal_button.disabled = true
	rest_stitch_button.disabled = true
	rest_stitch_first.disabled = true
	rest_stitch_second.disabled = true
	rest_upgrade_button.disabled = true
	rest_upgrade_cards.disabled = true
	_refresh_rest_hp()
	rest_continue_button.disabled = false
	rest_continue_button.focus_next = rest_continue_button.get_path_to(rest_back_button)
	rest_continue_button.focus_previous = rest_continue_button.get_path_to(rest_back_button)
	rest_back_button.focus_next = rest_back_button.get_path_to(rest_continue_button)
	rest_back_button.focus_previous = rest_back_button.get_path_to(rest_continue_button)
	rest_back_button.grab_focus()
	if not rest_patch_button.disabled:
		var actions := [rest_continue_button, rest_patch_button, rest_back_button]
		for index in range(actions.size()):
			actions[index].focus_next = actions[index].get_path_to(actions[(index + 1) % actions.size()])
			actions[index].focus_previous = actions[index].get_path_to(actions[(index - 1 + actions.size()) % actions.size()])


func _rest_patch_snapshot() -> Array:
	var carry := party_carryover as RunTornCarryover
	if carry == null or _rest_wardrobe == null or run_map == null or run_rng == null:
		return []
	return [run_map, run_map.get_route(), run_map.get_floors(), run_map.get_generation_revision(),
		run_rng, run_rng.state, run_seed, carry, carry.read_state(), carry.torn, carry.torn.read_state(),
		carry._wardrobe, _rest_wardrobe, _rest_wardrobe.get_snapshot(),
		run_heroes.duplicate(true), run_deck.duplicate(), run_trinkets.duplicate(), session_gold,
		run_scraps, run_removal_count, _stitch_snapshot(), rest_recovery, rest_recovery.is_consumed(),
		rest_upgrade, rest_upgrade.is_consumed(), rest_stitch, rest_stitch.get_snapshot(), rest_stitch.is_consumed()]


func _rest_patch_current(closed: bool = false) -> bool:
	if _rest_patch_context.is_empty() or _rest_patch_snapshot() != _rest_patch_context:
		return false
	var carry := party_carryover as RunTornCarryover
	var state := _rest_wardrobe.get_snapshot()
	return _rest_map != null and _rest_map.get_ref() == run_map and run_map.get_route() == _rest_route \
		and state.rest_id == ("" if closed else _rest_route.back()) and carry._wardrobe == _rest_wardrobe \
		and state.heroes == run_heroes and state.cards == run_deck and state.owned == run_trinkets \
		and state.scraps == run_scraps and state.gold == session_gold and state.seed == run_seed \
		and carry.can_bind_wardrobe(_rest_wardrobe, carry.torn, state)


func _sync_rest_patches() -> void:
	# Only called after an authorized primary choice commits.
	if _rest_wardrobe == null:
		return
	_rest_wardrobe.refresh_run_context(run_heroes, run_trinkets, run_scraps,
		session_gold, run_deck, _rest_wardrobe.get_snapshot())
	_rest_patch_context = _rest_patch_snapshot()


func _open_rest_patches(button) -> void:
	if not is_instance_valid(button) or button != rest_patch_button or button.disabled \
		or not button.is_visible_in_tree() or not _rest_patch_current() \
		or is_instance_valid(rest_patch_overlay) or is_instance_valid(rest_stitch_overlay):
		return
	rest_patch_overlay = Control.new()
	add_child(rest_patch_overlay)
	rest_patch_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.8)
	rest_patch_overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rest_patch_picker = LiveRestPatchResewPicker.new()
	rest_patch_overlay.add_child(rest_patch_picker)
	rest_patch_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var close := Button.new()
	close.name = "DismissResew"
	close.text = "Back to Rest"
	close.position = Vector2(960, 12)
	close.size = Vector2(180, 36)
	rest_patch_overlay.add_child(close)
	close.pressed.connect(_dismiss_rest_patches.bind(rest_patch_overlay, close))
	var carry := party_carryover as RunTornCarryover
	rest_patch_picker.present(_rest_wardrobe, carry.torn, _rest_wardrobe.get_snapshot(), _rest_route.back())
	rest_patch_picker.re_sew_requested.connect(_resew_at_rest.bind(rest_patch_picker, _rest_wardrobe, carry))
	var controls := [rest_patch_picker.source_selector, rest_patch_picker.destination_selector,
		rest_patch_picker.confirm_button, close]
	for index in range(controls.size()):
		controls[index].focus_next = controls[index].get_path_to(controls[(index + 1) % controls.size()])
		controls[index].focus_previous = controls[index].get_path_to(controls[(index - 1 + controls.size()) % controls.size()])
	close.grab_focus()


func _dismiss_rest_patches(overlay, button) -> void:
	if is_instance_valid(overlay) and overlay == rest_patch_overlay and overlay.is_visible_in_tree() \
		and is_instance_valid(button) and button.get_parent() == overlay and not button.disabled:
		_clear_rest_patch_overlay()
		rest_patch_button.grab_focus()


func _clear_rest_patch_overlay() -> void:
	if is_instance_valid(rest_patch_picker):
		for connection in rest_patch_picker.re_sew_requested.get_connections():
			rest_patch_picker.re_sew_requested.disconnect(connection.callable)
	if is_instance_valid(rest_patch_overlay):
		remove_child(rest_patch_overlay)
		rest_patch_overlay.queue_free()
	rest_patch_overlay = null
	rest_patch_picker = null


func _resew_at_rest(patch_id: String, from_hero: String, to_hero: String,
		node: String, expected: Dictionary, picker, wardrobe, carry) -> void:
	if not is_instance_valid(picker) or picker != rest_patch_picker or not picker.is_visible_in_tree() \
		or not is_instance_valid(rest_patch_overlay) or picker.get_parent() != rest_patch_overlay \
		or not is_instance_valid(rest_view) or not rest_view.is_visible_in_tree() \
		or wardrobe != _rest_wardrobe or carry != party_carryover or not _rest_patch_current() \
		or node != _rest_route.back() or expected != wardrobe.get_snapshot() \
		or not picker._pending or picker._snapshot != expected or picker._node_id != node:
		return
	var selected: int = picker.destination_selector.selected
	if selected < 0 or selected >= picker._destinations.size() \
		or not picker.confirm_button.is_visible_in_tree() \
		or not picker.source_selector.is_visible_in_tree() or not picker.destination_selector.is_visible_in_tree():
		return
	var choice: Dictionary = picker._destinations[selected]
	if [choice.patch_id, choice.from_hero, choice.to_hero] != [patch_id, from_hero, to_hero]:
		return
	var options := RunRestPatchResewOptions.project(wardrobe, carry.torn, expected, node)
	if not options.ok or not options.options.any(func(option): return option.patch_id == patch_id \
		and option.from_hero == from_hero and option.to_hero == to_hero):
		return
	var result: Dictionary = wardrobe.re_sew(patch_id, from_hero, to_hero, node,
		"rest:%s:resew:%d" % [node, _rest_patch_serial], expected)
	if not result.ok:
		return
	_rest_patch_serial += 1
	run_scraps = result.state.scraps
	carry.bind_wardrobe(wardrobe, carry.torn, result.state)
	# Rebase the live purse guard without replacing completed primary receipts.
	if rest_stitch.is_consumed():
		_rest_stitch_committed = _stitch_snapshot()
	else:
		if _rest_committed_deck.is_empty():
			rest_stitch = RunRestStitchCards.new(run_deck, run_stitch_descriptors, run_scraps, run_next_stitch_id)
			for connection in rest_stitch_button.pressed.get_connections():
				rest_stitch_button.pressed.disconnect(connection.callable)
			rest_stitch_button.pressed.connect(_stitch_at_rest.bind(rest_stitch, rest_stitch_button, rest_stitch_first, rest_stitch_second))
			if not rest_recovery.is_consumed():
				rest_stitch_button.disabled = run_scraps < RunRestStitchCards.SCRAP_COST
				rest_stitch_first.disabled = rest_stitch_button.disabled
				rest_stitch_second.disabled = rest_stitch_button.disabled
		# Upgrade changes the deck, so retain its original source deck in this guard.
		_rest_stitch_source = RunRestStitchCards.new(_rest_stitch_source.deck,
			_rest_stitch_source.descriptors, run_scraps, _rest_stitch_source.next_stitch_id).get_snapshot()
	_rest_patch_context = _rest_patch_snapshot()
	rest_view.get_node("RestStitchCost").text = "Stitch two different owners: 3 scraps (owned: %d)" % run_scraps
	_refresh_rest_stitch_guided()
	picker.present(wardrobe, carry.torn, result.state, node, "Re-sewn for 1 scrap.")


func _continue_from_rest(visit: RunRestRecovery, source_map: WeakRef, prior: Array[String], button) -> void:
	if is_instance_valid(rest_patch_overlay) or visit == null or visit != rest_recovery or not _current_completed_rest() \
		or source_map == null or source_map.get_ref() != run_map or prior != _rest_route \
		or not is_instance_valid(rest_view) or not rest_view.is_visible_in_tree() \
		or not is_instance_valid(button) or button != rest_continue_button or button.disabled \
		or not button.is_visible_in_tree() or is_instance_valid(route_view):
		return
	if _rest_wardrobe != null:
		if not _rest_patch_current() or not _rest_wardrobe.end_rest(_rest_route.back(), _rest_wardrobe.get_snapshot()).ok:
			return
		_clear_rest_patch_overlay()
		_rest_patch_context = _rest_patch_snapshot()
	button.disabled = true
	_clear_rest_stitch_overlay()
	rest_view.hide()
	_present_connected_route(source_map)


func _current_shop_ledger(status: String = "") -> bool:
	if shop_visit == null or run_map == null or _shop_map == null or _shop_map.get_ref() != run_map \
		or run_map.get_route() != _shop_route or _shop_route.is_empty() \
		or run_map.get_node(run_map.get_current_node_id()).get("type") != "Shop":
		return false
	var ledger := shop_visit.get_state()
	return ledger.valid and ledger.shop_node_id == run_map.get_current_node_id() \
		and ledger.deck == run_deck and ledger.gold == session_gold \
		and ledger.trinkets == run_trinkets and ledger.prior_removals == run_removal_count \
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
	if not _can_choose_connected_route() or run_rng == null or party_carryover == null \
		or source_map == null or source_map.get_ref() != run_map \
		or run_map.get_route() != prior or not is_instance_valid(route_view) \
		or not route_view.is_visible_in_tree() or not is_instance_valid(button) \
		or button not in route_buttons or button.disabled or not button.is_visible_in_tree() \
		or button.get_meta("route_id") != id or not run_map.get_legal_choices().has(id) \
		or run_map.get_node(id).get("type") != "Rest":
		return false
	var carry := party_carryover as RunTornCarryover
	var wardrobe := carry._wardrobe if carry != null else null
	if wardrobe != null:
		var state := wardrobe.get_snapshot()
		if state.heroes != run_heroes or state.owned != run_trinkets or state.scraps != run_scraps \
			or state.gold != session_gold or state.cards != run_deck or state.seed != run_seed \
			or state.rest_id != "" or state.rest_ids.has(id) \
			or not carry.can_bind_wardrobe(wardrobe, carry.torn, state):
			return false
	if not run_map.choose_node(id):
		return false
	_clear_rest_stitch_overlay()
	_rest_wardrobe = wardrobe
	_rest_patch_serial = 0
	if wardrobe != null:
		wardrobe.start_rest(id, wardrobe.get_snapshot())
	if is_instance_valid(rest_view):
		remove_child(rest_view)
		rest_view.queue_free()
	rest_continue_button = null
	_rest_committed_heroes.clear()
	_rest_committed_deck.clear()
	rest_stitch = RunRestStitchCards.new(run_deck, run_stitch_descriptors, run_scraps, run_next_stitch_id)
	_rest_stitch_source = _stitch_snapshot()
	_rest_stitch_committed.clear()
	rest_recovery = RunRestRecovery.new(run_heroes)
	rest_upgrade = RunRestCardUpgrade.new(run_deck, {"warden_strike": "warden_strike_plus"})
	_rest_deck = run_deck.duplicate()
	_rest_floors = run_map.get_floors()
	_rest_revision = run_map.get_generation_revision()
	_rest_gold = session_gold
	_rest_rng = run_rng
	_rest_rng_state = run_rng.state
	_rest_inventory = [run_trinkets.duplicate(), run_removal_count]
	_rest_carry = party_carryover
	_rest_ledger = party_carryover.read_state()
	_rest_heroes = run_heroes.duplicate(true)
	_rest_route = run_map.get_route()
	_rest_map = weakref(run_map)
	_clear_route_view()
	rest_view = VBoxContainer.new()
	rest_view.set_anchors_preset(Control.PRESET_CENTER)
	rest_view.add_theme_constant_override("separation", 8)
	add_child(rest_view)
	var heading := Label.new()
	heading.text = "Rest - " + id
	rest_view.add_child(heading)
	rest_hp_label = Label.new()
	rest_view.add_child(rest_hp_label)
	_refresh_rest_hp()
	var stitch_label := Label.new()
	stitch_label.name = "RestStitchCost"
	stitch_label.text = "Stitch two different owners: 3 scraps (owned: %d)" % run_scraps
	rest_view.add_child(stitch_label)
	rest_stitch_first = OptionButton.new()
	rest_stitch_second = OptionButton.new()
	for selector in [rest_stitch_first, rest_stitch_second]:
		selector.custom_minimum_size = Vector2(480, 36)
		for index in range(run_deck.size()):
			if StarterCards.new().has_card(run_deck[index]):
				selector.add_item(_rest_stitch_text(index))
				selector.set_item_metadata(selector.item_count - 1, index)
		rest_view.add_child(selector)
	rest_heal_button = Button.new()
	rest_heal_button.text = "Heal party (30% max HP; revive downed heroes)"
	rest_heal_button.custom_minimum_size = Vector2(480, 56)
	rest_heal_button.pressed.connect(_heal_at_rest.bind(rest_recovery, rest_heal_button))
	rest_view.add_child(rest_heal_button)
	rest_upgrade_cards = OptionButton.new()
	rest_upgrade_cards.custom_minimum_size = Vector2(480, 40)
	for index in range(run_deck.size()):
		if run_deck[index] == "warden_strike":
			rest_upgrade_cards.add_item(_rest_upgrade_text(index))
			rest_upgrade_cards.set_item_metadata(rest_upgrade_cards.item_count - 1, index)
	rest_view.add_child(rest_upgrade_cards)
	rest_upgrade_button = Button.new()
	rest_upgrade_button.text = "Upgrade selected Strike (instead of Heal)"
	rest_upgrade_button.custom_minimum_size = Vector2(480, 48)
	rest_upgrade_button.disabled = rest_upgrade_cards.item_count == 0
	rest_upgrade_cards.disabled = rest_upgrade_button.disabled
	rest_upgrade_button.pressed.connect(_upgrade_at_rest.bind(rest_upgrade, rest_upgrade_button, rest_upgrade_cards))
	rest_view.add_child(rest_upgrade_button)
	rest_stitch_button = Button.new()
	rest_stitch_button.text = "Stitch selected cards (instead of Heal / Upgrade)"
	rest_stitch_button.custom_minimum_size = Vector2(480, 40)
	rest_stitch_button.disabled = not rest_stitch.is_valid() or run_scraps < RunRestStitchCards.SCRAP_COST
	rest_stitch_first.disabled = rest_stitch_button.disabled
	rest_stitch_second.disabled = rest_stitch_button.disabled
	rest_stitch_button.pressed.connect(_stitch_at_rest.bind(rest_stitch, rest_stitch_button, rest_stitch_first, rest_stitch_second))
	rest_view.add_child(rest_stitch_button)
	rest_stitch_guided_button = Button.new()
	rest_stitch_guided_button.text = "Guided Stitch: preview two cards (3 scraps)"
	rest_view.add_child(rest_stitch_guided_button)
	_refresh_rest_stitch_guided()
	rest_continue_button = Button.new()
	rest_continue_button.text = "Continue"
	rest_continue_button.custom_minimum_size = Vector2(480, 48)
	rest_continue_button.disabled = true
	rest_continue_button.pressed.connect(_continue_from_rest.bind(rest_recovery, _rest_map, _rest_route.duplicate(), rest_continue_button))
	rest_view.add_child(rest_continue_button)
	rest_patch_button = Button.new()
	rest_patch_button.text = "Re-sew patches (1 scrap per transfer)"
	rest_patch_button.disabled = _rest_wardrobe == null
	rest_patch_button.pressed.connect(_open_rest_patches.bind(rest_patch_button))
	rest_view.add_child(rest_patch_button)
	rest_back_button = Button.new()
	rest_back_button.text = "Return to title"
	rest_back_button.pressed.connect(_return_from_visit.bind(rest_view))
	rest_view.add_child(rest_back_button)
	_focus_visit(rest_view)
	if not rest_upgrade_button.disabled:
		var actions: Array[Control] = [rest_heal_button, rest_upgrade_cards, rest_upgrade_button]
		if not rest_stitch_button.disabled:
			actions.append_array([rest_stitch_first, rest_stitch_second, rest_stitch_button])
		if not rest_stitch_guided_button.disabled:
			actions.append(rest_stitch_guided_button)
		if not rest_patch_button.disabled:
			actions.append(rest_patch_button)
		actions.append(rest_back_button)
		for index in range(actions.size()):
			actions[index].focus_next = actions[index].get_path_to(actions[(index + 1) % actions.size()])
			actions[index].focus_previous = actions[index].get_path_to(actions[(index - 1 + actions.size()) % actions.size()])
	_rest_patch_context = _rest_patch_snapshot()
	return true


func _heal_at_rest(visit: RunRestRecovery, button) -> void:
	if is_instance_valid(rest_patch_overlay) or visit == null or visit != rest_recovery or visit.is_consumed() \
		or rest_stitch == null or rest_stitch.is_consumed() or _stitch_snapshot() != _rest_stitch_source \
		or not _rest_upgrade_context() \
		or (rest_upgrade != null and rest_upgrade.is_consumed()) or not _rest_committed_deck.is_empty() \
		or not is_instance_valid(rest_view) or not rest_view.is_visible_in_tree() \
		or not is_instance_valid(button) or button != rest_heal_button \
		or button.disabled or not button.is_visible_in_tree() or run_map == null \
		or _rest_map == null or _rest_map.get_ref() != run_map \
		or run_map.get_route() != _rest_route or _rest_route.is_empty() \
		or run_map.get_current_node_id() != _rest_route.back() \
		or run_map.get_node(run_map.get_current_node_id()).get("type") != "Rest" \
		or run_heroes != _rest_heroes or not RunRestRecovery._is_valid_roster(run_heroes):
		return
	# Preflight both scene-free transactions before consuming either. These
	# synchronous services cannot fail after their complete source validation.
	if not visit._valid or visit._roster != _rest_heroes \
		or party_carryover == null or _carryover_map == null or _carryover_map.get_ref() != run_map:
		return
	var ledger := party_carryover.read_state()
	var current_id: String = run_map.get_current_node_id()
	if not ledger.ok or ledger.heroes != _rest_heroes or ledger.completed_rests.has(current_id) \
		or not RunPartyCarryover._valid_roster(ledger.heroes, true) \
		or not party_carryover._same_identities(ledger.heroes):
		return
	for hero in ledger.heroes:
		if hero.block != 0:
			return
	var committed := party_carryover.choose_rest_heal(current_id)
	var result := visit.choose_heal()
	if not committed.ok or not result.ok or committed.heroes != result.heroes:
		return
	run_heroes = result.heroes.duplicate(true)
	_rest_committed_heroes = run_heroes.duplicate(true)
	_finish_rest_choice()
	rest_back_button.grab_focus()


func _refresh_rest_hp() -> void:
	var preview: Dictionary = {}
	if rest_recovery != null and not rest_recovery.is_consumed() \
		and rest_upgrade != null and not rest_upgrade.is_consumed() \
		and rest_stitch != null and not rest_stitch.is_consumed() \
		and _rest_committed_heroes.is_empty() and _rest_committed_deck.is_empty():
		preview = RunRestHealPreview.preview(run_heroes)
	var lines: PackedStringArray = []
	for index in range(run_heroes.size()):
		var hero: Dictionary = run_heroes[index]
		var line := "%s: HP %d/%d" % [hero.id.capitalize(), hero.hp, hero.max_hp]
		if preview.get("ok") == true:
			var forecast: Dictionary = preview.forecasts[index]
			line += " -> %d/%d (+%d)%s" % [forecast.hp_after, preview.heroes[index].max_hp,
				forecast.hp_delta, " Revive" if forecast.revived else ""]
		lines.append(line)
	rest_hp_label.text = "\n".join(lines)


func _choose_shop_route(id: String, source_map: WeakRef, prior: Array[String], button) -> bool:
	if not _can_choose_connected_route() or source_map == null or source_map.get_ref() != run_map \
		or run_map.get_route() != prior or not is_instance_valid(route_view) \
		or not route_view.is_visible_in_tree() or not is_instance_valid(button) \
		or button not in route_buttons or button.disabled or not button.is_visible_in_tree() \
		or button.get_meta("route_id") != id or not run_map.get_legal_choices().has(id) \
		or run_map.get_node(id).get("type") != "Shop":
		return false
	var visit := RunShopVisit.new(run_deck, session_gold, run_removal_count, run_trinkets)
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
	var stock := RunShopStockOffers.generate(run_rng, party_ids, offers.cards, offers.trinkets, run_trinkets)
	if not stock.ok:
		run_rng.state = rng_before
		return false
	var purchases := RunShopPurchases.new(party_ids, run_deck, run_trinkets, session_gold, stock.cards, stock.trinkets)
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
	_mount_shop_patches()
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
	var actions: Array[Control] = [shop_offers, shop_buy_button, shop_cards, shop_remove_button, shop_patch_offers, shop_patch_heroes, shop_patch_buy_button, shop_continue_button, shop_back_button]
	for index in range(actions.size()):
		actions[index].focus_next = actions[index].get_path_to(actions[(index + 1) % actions.size()])
		actions[index].focus_previous = actions[index].get_path_to(actions[(index - 1 + actions.size()) % actions.size()])
	shop_offers.grab_focus()
	_shop_patch_context = _shop_patch_snapshot()
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
	if not ledger.valid or ledger.status not in ["available", "used"] or ledger.shop_node_id != run_map.get_current_node_id() \
		or ledger.deck != run_deck or ledger.gold != session_gold or ledger.prior_removals != run_removal_count \
		or state.deck != run_deck or state.gold != session_gold or state.trinkets != ledger.trinkets or ledger.trinkets != run_trinkets:
		return
	var index := shop_offers.selected
	var stock: Array = purchases.get_stock().cards
	if index < 0 or index >= stock.size() or index >= shop_offers.item_count:
		return
	var offer: Dictionary = stock[index]
	if offer.sold or session_gold < offer.price or shop_offers.get_item_metadata(index) != offer.id \
		or shop_offers.get_item_text(index) != _shop_offer_text(offer):
		return
	if not _shop_patch_current():
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
	_sync_shop_wardrobe()
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
		or state.deck != run_deck or state.gold != session_gold or state.prior_removals != run_removal_count \
		or state.trinkets != run_trinkets:
		return
	var index := shop_cards.selected
	if index >= run_deck.size() or shop_cards.get_item_text(index) != run_deck[index]:
		return
	var card_id: String = shop_cards.get_item_text(index)
	var expected := RunShopCardRemoval.try_remove(run_deck, session_gold, run_removal_count, card_id)
	if shop_purchases == null or not shop_purchases.can_rebase_removal(state, expected, card_id):
		return
	if not _shop_patch_current():
		return
	var result := visit.remove_card(card_id)
	if not result.ok:
		return
	shop_purchases.rebase_removal(state, result, card_id)
	run_deck.assign(result.deck)
	session_gold = result.gold
	run_removal_count = result.prior_removals
	_sync_shop_wardrobe()
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
	var ledger := shop_visit.get_state()
	var valid_visit: bool = ledger.valid and ledger.status in ["available", "used"]
	shop_offers.disabled = not valid_visit
	shop_buy_button.disabled = not valid_visit or stock[selected].sold or session_gold < stock[selected].price
	_refresh_shop_patches()


func _mount_shop_patches() -> void:
	var carry := party_carryover as RunTornCarryover
	_shop_wardrobe = carry._wardrobe if carry != null else null
	if _shop_wardrobe == null:
		var definitions: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/patches/initial_patch_slots.json"))
		var coats: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/patches/m04_coat_patches.json"))
		if definitions is Array and coats is Array and RunPatchCoatRules._valid_authored(coats):
			for coat in coats:
				definitions.append({"id": coat.id, "slot": coat.slot})
			_shop_wardrobe = RunPatchWardrobe.new(run_heroes, run_trinkets, definitions,
				run_scraps, session_gold, run_deck, run_seed, true)
	var row := HBoxContainer.new()
	row.name = "ShopPatchSewing"
	shop_view.add_child(row)
	shop_patch_offers = OptionButton.new()
	shop_patch_offers.custom_minimum_size = Vector2(300, 40)
	row.add_child(shop_patch_offers)
	shop_patch_heroes = OptionButton.new()
	row.add_child(shop_patch_heroes)
	for hero in run_heroes:
		shop_patch_heroes.add_item(hero.id.capitalize())
		shop_patch_heroes.set_item_metadata(shop_patch_heroes.item_count - 1, hero.id)
	shop_patch_buy_button = Button.new()
	shop_patch_buy_button.text = "Buy + sew (free)"
	row.add_child(shop_patch_buy_button)
	shop_patch_offers.item_selected.connect(func(_index): _refresh_shop_patches())
	shop_patch_buy_button.pressed.connect(_buy_shop_patch.bind(shop_visit, shop_purchases, shop_patch_buy_button))


func _shop_patch_snapshot() -> Array:
	var carry := party_carryover as RunTornCarryover
	if run_map == null or run_rng == null or carry == null or _shop_wardrobe == null \
		or shop_visit == null or shop_purchases == null:
		return []
	return [run_map, run_rng, run_rng.state, run_seed, run_map.get_generation_revision(),
		run_map.get_floors(), run_map.get_route(), party_carryover, party_carryover.read_state(),
		carry.torn.read_state(), carry._wardrobe,
		run_heroes.duplicate(true), run_trinkets.duplicate(), run_scraps, session_gold,
		run_deck.duplicate(), run_removal_count, shop_visit, shop_visit.get_state(),
		shop_purchases, shop_purchases.get_state(), shop_purchases.get_stock(),
		_shop_wardrobe, _shop_wardrobe.get_snapshot(), shop_view, shop_patch_offers, shop_patch_heroes, shop_patch_buy_button]


func _shop_patch_current() -> bool:
	if _shop_wardrobe == null or _shop_patch_context.is_empty() \
		or _shop_patch_snapshot() != _shop_patch_context:
		return false
	var w := _shop_wardrobe.get_snapshot()
	return w.heroes == run_heroes and w.owned == run_trinkets and w.scraps == run_scraps \
		and w.gold == session_gold and w.cards == run_deck and w.seed == run_seed and w.rest_id == ""


func _sync_shop_wardrobe() -> void:
	# Called only after a legitimate committed card purchase/removal.
	if _shop_wardrobe != null:
		_shop_wardrobe.refresh_run_context(run_heroes, run_trinkets, run_scraps,
			session_gold, run_deck, _shop_wardrobe.get_snapshot())
	_shop_patch_context = _shop_patch_snapshot()


func _refresh_shop_patches() -> void:
	if not is_instance_valid(shop_patch_offers):
		return
	var selected := maxi(0, shop_patch_offers.selected)
	shop_patch_offers.clear()
	var stock: Array = shop_purchases.get_stock().trinkets
	for offer in stock:
		shop_patch_offers.add_item(_shop_offer_text(offer))
		shop_patch_offers.set_item_metadata(shop_patch_offers.item_count - 1, offer.id)
	shop_patch_offers.select(selected)
	shop_patch_buy_button.disabled = _shop_wardrobe == null or selected >= stock.size() \
		or stock[selected].sold or session_gold < stock[selected].price


func _buy_shop_patch(visit: RunShopVisit, purchases: RunShopPurchases, button) -> void:
	if visit == null or visit != shop_visit or purchases == null or purchases != shop_purchases \
		or not _current_shop_ledger() or not _shop_patch_current() \
		or not is_instance_valid(shop_view) or not shop_view.is_visible_in_tree() \
		or not is_instance_valid(button) or button != shop_patch_buy_button \
		or button.disabled or not button.is_visible_in_tree():
		return
	for picker in [shop_patch_offers, shop_patch_heroes]:
		if not is_instance_valid(picker) or picker.disabled or not picker.is_visible_in_tree():
			return
	var index := shop_patch_offers.selected
	var hero_index := shop_patch_heroes.selected
	var stock: Array = purchases.get_stock().trinkets
	if index < 0 or index >= stock.size() or index >= shop_patch_offers.item_count \
		or hero_index < 0 or hero_index >= run_heroes.size() or hero_index >= shop_patch_heroes.item_count:
		return
	var offer: Dictionary = stock[index]
	var hero: Dictionary = run_heroes[hero_index]
	if not shop_patch_offers.get_item_metadata(index) is String \
		or not shop_patch_heroes.get_item_metadata(hero_index) is String \
		or shop_patch_offers.get_item_metadata(index) != offer.id \
		or shop_patch_offers.get_item_text(index) != _shop_offer_text(offer) \
		or shop_patch_heroes.get_item_metadata(hero_index) != hero.id \
		or shop_patch_heroes.get_item_text(hero_index) != hero.id.capitalize():
		return
	var expected := _shop_wardrobe.get_snapshot()
	var carry := party_carryover as RunTornCarryover
	if carry == null or not carry.can_bind_wardrobe(_shop_wardrobe, carry.torn, expected):
		return
	var result := RunShopPatchSewing.purchase_and_sew(purchases, visit, _shop_wardrobe,
		run_map.get_current_node_id(), offer.id, hero.id, expected.definitions.get(offer.id),
		"shop:%s:%s" % [run_map.get_current_node_id(), offer.id],
		purchases.get_state(), purchases.get_stock(), visit.get_state(), expected)
	if not result.ok:
		return
	run_trinkets.assign(result.wardrobe_state.owned)
	run_scraps = result.wardrobe_state.scraps
	session_gold = result.wardrobe_state.gold
	carry.bind_wardrobe(_shop_wardrobe, carry.torn, result.wardrobe_state)
	_shop_patch_context = _shop_patch_snapshot()
	_refresh_shop()


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
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		panel.custom_minimum_size.y = 120
		hand_view.add_child(panel)
		var label := Label.new()
		label.text = card_id
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		panel.add_child(label)
	pile_label.text = "Draw: %d | Discard: %d" % [deck.draw_pile.size(), deck.discard_pile.size()]
	$LiveSupportHand._sync_battle()


## Container layout and card identities stay authoritative; only the visual tilt changes.
func _fan_hand() -> void:
	if not is_instance_valid(hand_view):
		return
	var count := hand_view.get_child_count()
	for index in range(count):
		var panel := hand_view.get_child(index) as Control
		var spread := (float(index) - float(count - 1) * 0.5) / maxf(1.0, float(count - 1) * 0.5)
		panel.pivot_offset = Vector2(panel.size.x * 0.5, panel.size.y + 40)
		panel.rotation = deg_to_rad(spread * 2.0)


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


func _end_turn(button = null) -> void:
	if not is_instance_valid(button) or button != end_turn_button or button.disabled or not button.is_visible_in_tree():
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


func _reenable_end_turn(button) -> void:
	if is_instance_valid(button) and button == end_turn_button and _observe_battle_result():
		button.disabled = false


func _refresh_enemy_roster() -> void:
	var presenter := get_node_or_null("LiveEnemyRoster")
	if presenter != null:
		presenter._sync_battle()
		presenter._refresh()


func _return_from_battle(button) -> void:
	if not is_instance_valid(terminal_result_panel) \
		and is_instance_valid(button) and button == return_button and not button.disabled \
		and button.is_visible_in_tree():
		_return_to_title()


func _return_to_title() -> void:
	_clear_quiet_spool()
	_quiet_spool_completed = false
	_clear_rest_patch_overlay()
	_clear_rest_stitch_overlay()
	rest_stitch_guided_button = null
	_rest_wardrobe = null
	_rest_patch_context.clear()
	rest_patch_button = null
	_rest_patch_serial = 0
	_clear_reward_choice()
	_clear_terminal_result()
	for action in reward_buttons:
		action.disabled = true
	if is_instance_valid(continue_button):
		continue_button.disabled = true
	if is_instance_valid(end_turn_button):
		end_turn_button.disabled = true
	if is_instance_valid(return_button):
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
	shop_patch_offers = null
	shop_patch_heroes = null
	shop_patch_buy_button = null
	_shop_wardrobe = null
	_shop_patch_context.clear()
	_shop_map = null
	_shop_route.clear()
	_connected_map = null
	_connected_route.clear()
	_placeholder_map = null
	_placeholder_route.clear()
	run_removal_count = 0
	if is_instance_valid(rest_view):
		remove_child(rest_view)
		rest_view.queue_free()
	rest_view = null
	rest_heal_button = null
	rest_continue_button = null
	rest_back_button = null
	rest_hp_label = null
	rest_recovery = null
	rest_stitch = null
	rest_stitch_first = null
	rest_stitch_second = null
	rest_stitch_button = null
	_rest_stitch_source.clear()
	_rest_stitch_committed.clear()
	rest_upgrade = null
	rest_upgrade_cards = null
	rest_upgrade_button = null
	_rest_deck.clear()
	_rest_committed_deck.clear()
	_rest_floors.clear()
	_rest_inventory.clear()
	_rest_ledger.clear()
	_rest_carry = null
	_rest_rng = null
	_rest_gold = 0
	_rest_rng_state = 0
	_rest_revision = 0
	_rest_route.clear()
	_rest_heroes.clear()
	_rest_committed_heroes.clear()
	_rest_map = null
	run_heroes.clear()
	party_carryover = null
	_carryover_map = null
	_carryover_revision = 0
	_carryover_node = ""
	_carryover_route.clear()
	_carryover_floors.clear()
	_carryover_party = null
	_carryover_result = null
	continue_button = null
	round_flow = null
	if is_instance_valid(battle_view):
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
	act_outcome = null
	victory_gold = null
	card_reward = null
	fight_rewards = null
	multi_fight_rewards = null
	fight_reward_offers.clear()
	fight_reward_gold = 0
	fight_reward_trinket = ""
	fight_reward_claimed = false
	_reward_map = null
	reward_buttons.clear()
	run_deck.clear()
	run_trinkets.clear()
	session_gold = 0
	run_scraps = 0
	run_stitch_descriptors.clear()
	run_next_stitch_id = 1
	_battle_closed = false
	_map_mend_serial = 0
	_mended_route_context.clear()
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
