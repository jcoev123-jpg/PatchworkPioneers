extends Node
## Post-claim presentation; the existing reward coordinator alone grants ownership.

var wardrobe: RunPatchWardrobe
var hero_buttons: Array[Button] = []
var summary: Label
var _map: RunMap
var _rng: RandomNumberGenerator
var _choices: HBoxContainer
var _claim_context: Array = []
var _service: RunMultiFightRewards
var _drop := ""
var _token := 0
var _bound_carry: RunTornCarryover


func _ready() -> void:
	summary = Label.new()
	summary.name = "WornElitePatches"
	summary.position = Vector2(24, 2)
	summary.add_theme_font_size_override("font_size", 14)
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child.call_deferred(summary)


func _process(_delta: float) -> void:
	_sync_run()
	if is_instance_valid(_choices):
		_choices.visible = _eligible()
		if _choices.visible and not hero_buttons.is_empty() and not hero_buttons[0].disabled:
			_wire_focus()
	_update_summary()


func _sync_run() -> void:
	var app = get_parent()
	if app.run_map != _map or app.run_rng != _rng:
		_clear_choices()
		if _bound_carry != null:
			_bound_carry.clear_wardrobe(wardrobe)
		_bound_carry = null
		wardrobe = null
		_map = app.run_map
		_rng = app.run_rng
	if _map == null:
		summary.text = ""


func _clear_choices() -> void:
	_token += 1
	if is_instance_valid(_choices):
		_choices.queue_free()
	_choices = null
	hero_buttons.clear()
	_claim_context.clear()
	_service = null
	_drop = ""


func _context() -> Array:
	var app = get_parent()
	if app.run_map == null:
		return []
	return [app.run_map, app.run_rng, app.run_rng.state, app.run_seed,
		app.run_map.get_generation_revision(), app.run_map.get_floors(), app.run_map.get_route(),
		app.battle_view, app.battle_result, app.party, app.enemies,
		app.party.get_heroes(), app.enemies.get_enemies(), app.run_heroes.duplicate(true),
		app.run_trinkets.duplicate(), app.run_scraps, app.session_gold, app.run_deck.duplicate(),
		app.party_carryover.read_state(), app.multi_fight_rewards,
		app.multi_fight_rewards.read_state() if app.multi_fight_rewards != null else {}]


func observe_claim(offering, result: Dictionary) -> void:
	_sync_run()
	var app = get_parent()
	if not offering is RunMultiFightRewards or offering != app.multi_fight_rewards \
		or not result.get("ok", false) or not result.get("receipt") is Dictionary:
		return
	var receipt: Dictionary = result.receipt
	if not _confirmed(offering) or receipt.get("node_id") != _map.get_current_node_id() \
		or receipt.get("node_kind") != "Elite":
		return
	var drop: Variant = receipt.get("trinket_drop_id")
	if not drop is String or not app.run_trinkets.has(drop):
		return
	# A receipt is accepted once per actual coordinator; repeated observation cannot
	# refresh the guard or invalidate a player's already captured selection.
	if offering == _service:
		return
	var definitions: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/initial_patch_slots.json"))
	var coats: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_coat_patches.json"))
	if not definitions is Array or not coats is Array or not RunPatchCoatRules._valid_authored(coats):
		return
	for coat in coats:
		definitions.append({"id": coat.id, "slot": coat.slot})
	var carry := app.party_carryover as RunTornCarryover
	if carry == null or (_bound_carry != null and carry._wardrobe != null and wardrobe != carry._wardrobe):
		return
	# An earlier skipped Elite may have an unbound, unworn presentation ledger.
	# A subsequently committed Shop wardrobe is the run's authoritative owner.
	if carry._wardrobe != null:
		wardrobe = carry._wardrobe
		_bound_carry = carry
	if wardrobe == null:
		var candidate := RunPatchWardrobe.new(app.run_heroes, app.run_trinkets, definitions,
			app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
		if not candidate.is_valid():
			return
		wardrobe = candidate
	elif not wardrobe.refresh_run_context(app.run_heroes, app.run_trinkets, app.run_scraps,
		app.session_gold, app.run_deck, wardrobe.get_snapshot()):
		return
	_clear_choices()
	_service = offering
	_drop = drop
	_claim_context = _context()
	var state := wardrobe.get_snapshot()
	if not state.definitions.has(drop) or wardrobe._find_wearer(drop) != "":
		_update_summary()
		return
	var reward = app.hand_view.get_node_or_null("CardReward")
	if reward == null:
		return
	var column := VBoxContainer.new()
	column.name = "ElitePatchReward"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Reserve room for the extra reward row within the 720px battle layout.
	app.hand_view.get_parent().add_theme_constant_override("separation", 12)
	app.hand_view.add_child(column)
	reward.reparent(column)
	_choices = HBoxContainer.new()
	column.add_child(_choices)
	var label := Label.new()
	label.text = "Sew %s (%s), free:" % [drop, state.definitions[drop]]
	_choices.add_child(label)
	for hero in app.run_heroes:
		var button := Button.new()
		button.text = hero.id.capitalize()
		button.set_meta("hero_id", hero.id)
		button.disabled = hero.hp == 0
		button.custom_minimum_size = Vector2(150, 40)
		_choices.add_child(button)
		hero_buttons.append(button)
		button.pressed.connect(_sew.bind(hero.id, button, _token, state))
	_wire_focus()
	_update_summary()


func _wire_focus() -> void:
	var app = get_parent()
	# The app rebuilds its action cycle each frame; extend it after that refresh.
	app.return_button.focus_next = app.return_button.get_path_to(hero_buttons[0])
	hero_buttons[0].focus_previous = hero_buttons[0].get_path_to(app.return_button)
	for index in range(hero_buttons.size()):
		var next: Control = hero_buttons[index + 1] if index < 2 else app.continue_button
		hero_buttons[index].focus_next = hero_buttons[index].get_path_to(next)
		if index > 0:
			hero_buttons[index].focus_previous = hero_buttons[index].get_path_to(hero_buttons[index - 1])
	app.continue_button.focus_previous = app.continue_button.get_path_to(hero_buttons[2])


func _confirmed(service: RunMultiFightRewards) -> bool:
	var app = get_parent()
	return _map != null and _map == app.run_map and _rng == app.run_rng \
		and service == app.multi_fight_rewards and service._map == _map \
		and service._rng == _rng and service._carry == app.party_carryover \
		and service._map_revision == _map.get_generation_revision() \
		and service._graph == _map.get_floors() and service._route == _map.get_route() \
		and service._node == _map.get_current_node_id() \
		and _map.get_node(service._node).get("type") == "Elite" \
		and service._paid_battles.has(app.battle_result) and service._pending == null \
		and service.read_state() == {"deck": app.run_deck, "gold": app.session_gold,
			"trinkets": app.run_trinkets, "party": app.party_carryover.read_state()} \
		and app._can_leave_fight() and is_instance_valid(app.battle_view) \
		and app.battle_view.is_visible_in_tree() and is_instance_valid(app.continue_button) \
		and not app.continue_button.disabled


func _eligible() -> bool:
	return _service != null and _confirmed(_service) and _context() == _claim_context


func _sew(hero_id: String, button, token: int, expected: Dictionary) -> void:
	if token != _token or wardrobe == null or not _eligible() \
		or not is_instance_valid(button) or button not in hero_buttons \
		or button.disabled or not button.is_visible_in_tree() \
		or button.get_meta("hero_id", "") != hero_id:
		return
	var carry := get_parent().party_carryover as RunTornCarryover
	if carry == null or not carry.can_bind_wardrobe(wardrobe, carry.torn, expected) \
		or not expected.heroes.any(func(hero): return hero.id == hero_id and hero.hp > 0):
		return
	var slot: Variant = expected.definitions.get(_drop)
	var result := wardrobe.sew(_drop, hero_id, slot,
		"elite:%s:%s" % [_map.get_current_node_id(), _drop], expected)
	if not result.ok:
		return
	carry.bind_wardrobe(wardrobe, carry.torn, wardrobe.get_snapshot())
	_bound_carry = carry
	for action in hero_buttons:
		action.disabled = true
	_update_summary()


func _update_summary() -> void:
	if not is_instance_valid(summary):
		return
	var lines: Array[String] = []
	if wardrobe != null:
		var worn: Dictionary = wardrobe.get_snapshot().worn
		for hero in worn:
			for slot in worn[hero]:
				if worn[hero][slot] != "":
					lines.append("%s: %s (%s)" % [hero.capitalize(), worn[hero][slot], slot])
	summary.text = "Worn patches: " + " | ".join(lines) if not lines.is_empty() else ""
