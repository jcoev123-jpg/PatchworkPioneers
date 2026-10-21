extends SceneTree
## Mounted contract for a standalone, unwired terminal view. Outcomes must be
## observed by real combat services and settled by the real run latch.
const PANEL_SCENE := "res://scenes/run_terminal_result_panel.tscn"
const HEROES := "res://data/heroes/starter_party.json"
const BOSS := "res://data/enemies/boss.json"
const FIGHT := "res://data/enemies/starter_enemies.json"

var panel: LiveRunTerminalResultPanel
var failures: Array[String] = []
var checks: int = 0
var returns: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _mouse(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _on_return() -> void:
	returns += 1


## Strictly use actual authored JSON definitions, not synthetic combat rosters.
func _definitions(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "authored fixture file opens: " + path)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_check(parsed is Array and not parsed.is_empty(), "authored roster is nonempty: " + path)
	if not parsed is Array:
		return []
	var defs: Array = []
	for value in parsed:
		_check(value is Dictionary, "authored roster item is a dictionary")
		if not value is Dictionary:
			continue
		var definition: Dictionary = value.duplicate(true)
		var hp: Variant = definition.get("max_hp")
		var valid_hp: bool = (hp is int and hp > 0) or (hp is float and hp > 0
			and is_finite(hp) and floorf(hp) == hp)
		_check(valid_hp, "authored HP is integral and positive")
		if valid_hp:
			definition["max_hp"] = int(hp)
		defs.append(definition)
	return defs


func _battle(enemy_path: String) -> Dictionary:
	var party := CombatParty.new(_definitions(HEROES))
	var enemies := CombatEnemies.new(_definitions(enemy_path))
	_check(party.is_valid() and enemies.is_valid(), "genuine living combat services are valid")
	_check(party.get_heroes().size() == 3
		and party.get_hero(1).get("id") == "warden"
		and party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(3).get("id") == "tinker", "authored starter identities occupy slots 1-3")
	_check(not party.is_defeated() and not enemies.is_victorious(),
		"both battle rosters begin alive")
	if enemy_path == BOSS:
		_check(enemies.get_enemy(1).get("id") == "patchwork_behemoth"
			and enemies.get_enemy(1).get("hp") == 42,
			"real authored final boss fixture is alive")
	var result := CombatBattleResult.new(party, enemies)
	_check(result.get_outcome() == CombatBattleResult.ACTIVE, "combat result starts ACTIVE")
	return {"party": party, "enemies": enemies, "result": result}


func _context(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := RunMap.new()
	_check(map.generate(rng) and map.get_floors().size() == RunMap.FLOOR_COUNT,
		"seeded real 12-floor map generated")
	return {"rng": rng, "map": map, "latch": RunActBattleOutcome.new(map)}


func _snapshot(ctx: Dictionary, battle: Dictionary = {}) -> Dictionary:
	var map: RunMap = ctx["map"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var output := {
		"floors": map.get_floors(), "route": map.get_route(),
		"choices": map.get_legal_choices(),
		"current": map.get_current_node_id(),
		"floor": map.get_current_floor(), "complete": map.is_complete(),
		"revision": map.get_generation_revision(),
		"latch": ctx["latch"].get_state(),
		"seed": rng.seed, "rng": rng.state,
	}
	if not battle.is_empty():
		output["heroes"] = battle["party"].get_heroes()
		output["enemies"] = battle["enemies"].get_enemies()
		output["combat_result"] = battle["result"].get_outcome()
	return output


func _select(ctx: Dictionary, id: String) -> void:
	var map: RunMap = ctx["map"]
	_check(map.get_legal_choices().has(id), "choice %s is legally connected" % id)
	_check(map.choose_node(id), "map accepts choice " + id)
	_check(map.get_current_node_id() == id, "selected exact intended node")


func _boss_path(map: RunMap, node_id: String) -> Array[String]:
	var node := map.get_node(node_id)
	if node.is_empty():
		return []
	if node.get("floor") == RunMap.FLOOR_COUNT:
		var ending: Array[String] = []
		if node.get("type") == "Boss":
			ending.append(node_id)
		return ending
	for neighbor in node.get("outgoing", []):
		var suffix := _boss_path(map, neighbor)
		if not suffix.is_empty():
			suffix.push_front(node_id)
			return suffix
	return []


func _settle_win(ctx: Dictionary, battle: Dictionary, label: String) -> void:
	var latch: RunActBattleOutcome = ctx["latch"]
	_check(latch.begin_current_battle(battle["result"]), label + " begins with ACTIVE combat")
	var enemies: CombatEnemies = battle["enemies"]
	for position in range(1, enemies.get_enemies().size() + 1):
		var current := enemies.get_enemy(position)
		_check(current.get("hp", 0) > 0 and enemies.apply_damage(position, current["hp"]),
			label + " enemy was living and took lethal actual damage")
	_check(enemies.is_victorious() and not battle["party"].is_defeated(),
		label + " slain enemies and surviving party precondition")
	_check(battle["result"].get_outcome() == CombatBattleResult.ACTIVE,
		label + " lethal change not yet observed")
	_check(battle["result"].evaluate() == CombatBattleResult.VICTORY,
		label + " combat pipeline observes VICTORY")
	_check(latch.settle_current_battle(), label + " settles observed result")


func _victory() -> Dictionary:
	var ctx := _context(5801)
	var map: RunMap = ctx["map"]
	var path: Array[String] = []
	for opening in map.get_legal_choices():
		path = _boss_path(map, opening)
		if not path.is_empty():
			break
	_check(path.size() == RunMap.FLOOR_COUNT, "fixed seed supplies connected 12-node Boss route")
	var previous_settled := 0
	for index in range(path.size()):
		var id: String = path[index]
		_check(map.get_legal_choices().has(id), "path remains connected at floor %d" % (index + 1))
		_select(ctx, id)
		var kind: String = map.get_node(id).get("type")
		if kind == "Boss":
			break
		if kind in ["Fight", "Elite"]:
			var intermediate := _battle(FIGHT)
			_settle_win(ctx, intermediate, "floor %d %s" % [index + 1, kind])
			previous_settled += 1
			_check(ctx["latch"].get_state().run_status == RunActBattleOutcome.ACTIVE,
				"intermediate Fight/Elite win leaves run ACTIVE")
	_check(map.is_complete() and map.get_current_floor() == 12
		and map.get_node(map.get_current_node_id()).get("type") == "Boss",
		"actual selected final node is a floor-12 Boss")
	var battle := _battle(BOSS)
	var latch: RunActBattleOutcome = ctx["latch"]
	_check(latch.get_state().run_status == RunActBattleOutcome.ACTIVE,
		"merely arriving at final Boss is not a victory")
	_check(latch.begin_current_battle(battle["result"]), "Boss binds active witnessed result")
	var pending: Dictionary = _snapshot(ctx, battle)
	_check(pending["latch"]["pending_node_id"] == path.back(),
		"final Boss pending before settlement")
	_check(not panel.open_result(latch), "pending Boss never renders as terminal")
	_check(_snapshot(ctx, battle) == pending, "pending Boss refusal is read-only")
	_check(not latch.settle_current_battle(), "unobserved active Boss cannot settle")
	_check(_snapshot(ctx, battle) == pending, "active settlement refusal preserves all snapshots")
	var enemies: CombatEnemies = battle["enemies"]
	_check(enemies.apply_damage(1, enemies.get_enemy(1)["hp"]) and enemies.is_victorious(),
		"real Boss enemy takes actual lethal damage")
	_check(battle["party"].get_hero(1)["hp"] > 0, "Boss victory has surviving hero")
	_check(battle["result"].get_outcome() == CombatBattleResult.ACTIVE,
		"Boss outcome not observed before evaluate")
	_check(battle["result"].evaluate() == CombatBattleResult.VICTORY,
		"real Boss combat evaluates victory")
	_check(latch.settle_current_battle(), "observed Boss victory settles")
	_check(latch.get_state().run_status == "VICTORY"
		and latch.get_state().pending_node_id == ""
		and latch.get_state().settled_node_ids.size() == previous_settled + 1
		and latch.get_state().settled_node_ids.back() == path.back(),
		"Boss yields settled terminal run status, no pending node")
	return {"ctx": ctx, "battle": battle}


func _defeat() -> Dictionary:
	var ctx := _context(8722)
	var map: RunMap = ctx["map"]
	var opening := ""
	for choice in map.get_legal_choices():
		if map.get_node(choice).get("type") == "Fight":
			opening = choice
			break
	_check(not opening.is_empty(), "actual legal opening Fight exists")
	if opening.is_empty():
		return {}
	_select(ctx, opening)
	var battle := _battle(FIGHT)
	var latch: RunActBattleOutcome = ctx["latch"]
	_check(latch.begin_current_battle(battle["result"]), "actual Fight defeat begins active combat")
	var party: CombatParty = battle["party"]
	for slot in range(1, 4):
		var hp: int = party.get_hero(slot)["hp"]
		_check(hp > 0 and party.apply_damage(slot, hp) and party.is_downed(slot),
			"authoritative apply_damage downs hero %d" % slot)
	_check(party.is_defeated() and not battle["enemies"].is_victorious(),
		"all three heroes down while authored enemy survives")
	_check(battle["result"].get_outcome() == CombatBattleResult.ACTIVE,
		"party damage not yet combat-observed")
	_check(battle["result"].evaluate() == CombatBattleResult.DEFEAT,
		"CombatBattleResult observes party DEFEAT")
	_check(latch.settle_current_battle(), "observed Fight defeat settles")
	_check(latch.get_state() == {"run_status": "DEFEAT",
		"pending_node_id": "", "settled_node_ids": [opening]},
		"settled party defeat does not invent Boss victory")
	return {"ctx": ctx, "battle": battle}


func _validate_view(status: String, label: String) -> void:
	_check(panel.has_open_result() and panel.is_visible_in_tree(),
		label + " mounted and visible")
	_check(panel.get_presented_status() == status.to_upper() and panel.title_label.text == status,
		label + " authoritative terminal heading and presentation state")
	var sentence := ("The final boss has fallen. The run is complete."
		if status == "Victory" else "The party has fallen. The run has ended.")
	_check(panel.description_label.text == sentence, label + " short distinct neutral sentence")
	var all_buttons := panel.find_children("*", "Button", true, false)
	_check(all_buttons.size() == 1 and all_buttons[0] == panel.return_button,
		label + " exactly one mounted Button")
	var button := panel.return_button
	_check(button.text == "Return to Title" and not button.disabled
		and button.focus_mode == Control.FOCUS_ALL and button.is_visible_in_tree(),
		label + " sole enabled focusable return action")
	var paper := panel.paper_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_check(paper != null and paper.border_width_left >= 4 and paper.border_width_top >= 4
		and paper.bg_color.get_luminance() > 0.5,
		label + " cream paper and thick sewn patch border")
	var backdrop := panel.get_node("SlateBackdrop") as ColorRect
	_check(backdrop != null and backdrop.color.get_luminance() < 0.3,
		label + " dark slate ColorRect covers background")
	_check(panel.top_stitches.text.contains("×") and panel.bottom_stitches.text.contains("×")
		and panel.top_stitches.get_theme_color("font_color") != Color.TRANSPARENT,
		label + " visible decorative running stitches")
	_check(paper != null and absf(paper.bg_color.get_luminance()
		- panel.title_label.get_theme_color("font_color").get_luminance()) > 0.4,
		label + " readable paper/heading contrast")
	_check(button.get_theme_stylebox("normal") is StyleBoxFlat
		and button.get_theme_stylebox("focus") is StyleBoxFlat,
		label + " procedural cardboard button and focus ring")
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	for control in [panel.paper_panel, panel.title_label, panel.description_label,
			panel.top_stitches, panel.bottom_stitches, button]:
		_check(screen.encloses(control.get_global_rect()) and control.size.x > 0
			and control.size.y > 0, label + " full rectangle within 1280x720: " + control.name)


func _test_rejection() -> void:
	_check(not panel.open_result(null), "null RunActBattleOutcome rejected")
	var ctx := _context(4509)
	_check(not panel.open_result(ctx["latch"]), "unselected ACTIVE latch rejected")
	var map: RunMap = ctx["map"]
	var opening := ""
	for choice in map.get_legal_choices():
		if map.get_node(choice).get("type") == "Fight":
			opening = choice
			break
	_check(not opening.is_empty(), "genuine opening Fight found for ACTIVE cases")
	if opening.is_empty():
		return
	_select(ctx, opening)
	var battle := _battle(FIGHT)
	var latch: RunActBattleOutcome = ctx["latch"]
	_check(latch.begin_current_battle(battle["result"]), "pending ACTIVE actual fight begins")
	var before := _snapshot(ctx, battle)
	_check(not panel.open_result(latch), "genuine pending ACTIVE latch rejected")
	_check(not panel.visible and not panel.has_open_result()
		and panel.get_presented_status() == "" and panel.return_button.disabled,
		"all rejected submissions remain hidden and action disabled")
	panel.return_button.pressed.emit()
	_check(returns == 0 and _snapshot(ctx, battle) == before,
		"hidden button callback cannot request return or mutate gameplay")
	_settle_active_win(ctx, battle)
	before = _snapshot(ctx, battle)
	_check(latch.get_state().settled_node_ids == [opening]
		and latch.get_state().run_status == "ACTIVE",
		"observed non-Boss victory is settled but nonterminal")
	_check(not panel.open_result(latch) and not panel.visible,
		"settled ACTIVE Fight cannot masquerade as terminal")
	_check(_snapshot(ctx, battle) == before and returns == 0,
		"ACTIVE rejection leaves map, actors, latch, RNG untouched")


func _settle_active_win(ctx: Dictionary, battle: Dictionary) -> void:
	var enemies: CombatEnemies = battle["enemies"]
	for slot in range(1, enemies.get_enemies().size() + 1):
		_check(enemies.apply_damage(slot, enemies.get_enemy(slot)["hp"]),
			"real Fight enemy receives lethal damage")
	_check(battle["result"].evaluate() == "VICTORY", "intermediate Fight victory evaluated")
	_check(ctx["latch"].settle_current_battle(), "intermediate Fight victory settled")


func _test_terminal_interactions(victory: Dictionary, defeat: Dictionary) -> void:
	var victory_ctx: Dictionary = victory["ctx"]
	var victory_battle: Dictionary = victory["battle"]
	var victory_latch: RunActBattleOutcome = victory_ctx["latch"]
	var preserved := _snapshot(victory_ctx, victory_battle)
	_check(panel.open_result(victory_latch), "accepts settled Boss VICTORY")
	await _frames()
	_validate_view("Victory", "Boss victory")
	var generation := panel._generation
	var connections := panel.return_button.pressed.get_connections()
	_check(connections.size() == 1, "only one callback for Return button")
	var old_callback: Callable = connections[0]["callable"] if not connections.is_empty() else Callable()
	_check(not panel.open_result(victory_latch) and panel._generation == generation,
		"duplicate open rejected without replacing visible result")
	panel.return_button.disabled = true
	panel.return_button.pressed.emit()
	panel.return_button.disabled = false
	panel.return_button.hide()
	panel.return_button.pressed.emit()
	panel.return_button.show()
	panel.hide()
	panel.return_button.pressed.emit()
	panel.show()
	_check(returns == 0, "disabled, hidden button and hidden panel emissions inert")
	await _frames()
	await _mouse(panel.return_button)
	_check(returns == 1 and panel.return_button.disabled,
		"real pointer click requests Return exactly once and disables action")
	panel.return_button.pressed.emit()
	await _mouse(panel.return_button)
	await _key(KEY_ENTER)
	_check(returns == 1, "duplicate click, forced signal and key do not replay")
	_check(_snapshot(victory_ctx, victory_battle) == preserved,
		"Boss panel and interactions do not touch map, combat, latch or seeded RNG")
	panel.close_result()
	_check(not panel.visible and not panel.has_open_result()
		and panel.get_presented_status() == "" and panel.return_button.disabled
		and not panel.return_button.has_focus(), "close fully clears action and releases focus")
	panel.return_button.pressed.emit()
	if old_callback.is_valid():
		old_callback.call()
	_check(returns == 1, "closed old button callbacks cannot emit")

	var defeat_ctx: Dictionary = defeat["ctx"]
	var defeat_battle: Dictionary = defeat["battle"]
	var defeat_latch: RunActBattleOutcome = defeat_ctx["latch"]
	var unchanged := _snapshot(defeat_ctx, defeat_battle)
	_check(panel.open_result(defeat_latch), "new settled DEFEAT opens after close")
	await _frames()
	_validate_view("Defeat", "party defeat")
	if old_callback.is_valid():
		old_callback.call()
	_check(returns == 1 and not panel.return_button.disabled,
		"stale previous-generation callback cannot spend reopened result")
	panel.return_button.grab_focus()
	await _frames()
	_check(panel.return_button.has_focus(), "Return button receives actual keyboard focus")
	await _key(KEY_ENTER)
	_check(returns == 2 and panel.return_button.disabled,
		"real focused Enter emits exactly one new request")
	panel.return_button.pressed.emit()
	_check(returns == 2, "focused Enter cannot replay through pressed signal")
	_check(_snapshot(defeat_ctx, defeat_battle) == unchanged,
		"defeat UI preserves all authoritative state")
	panel.close_result()
	_check(panel.open_result(defeat_latch), "same settled outcome can reopen only after close")
	await _frames()
	_validate_view("Defeat", "reopened defeat")
	panel.return_button.grab_focus()
	await _frames()
	_check(panel.return_button.has_focus(), "reopened Space action has real focus")
	await _key(KEY_SPACE)
	_check(returns == 3 and panel.return_button.disabled,
		"real focused Space emits exactly one request for fresh presentation")
	panel.return_button.pressed.emit()
	_check(returns == 3 and _snapshot(defeat_ctx, defeat_battle) == unchanged,
		"Space replay fails and authoritative snapshots remain unchanged")
	panel.close_result()
	_check(returns == 3 and _snapshot(victory_ctx, victory_battle) == preserved,
		"closing final view never modifies older completed Boss run")


func _test_global_rng(defeat: Dictionary) -> void:
	var ctx: Dictionary = defeat["ctx"]
	var battle: Dictionary = defeat["battle"]
	var before := _snapshot(ctx, battle)
	seed(142993)
	var expected := randi()
	seed(142993)
	_check(panel.open_result(ctx["latch"]), "RNG probe opens genuine defeat again")
	panel.return_button.pressed.emit()
	panel.close_result()
	_check(randi() == expected, "no draws from global RNG stream on UI open, action or close")
	_check(_snapshot(ctx, battle) == before and returns == 4,
		"no seeded map RNG or model change, exactly one extra genuine return")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load(PANEL_SCENE) as PackedScene
	_check(scene != null, "dedicated terminal PackedScene loads")
	if scene == null:
		_finish()
		return
	panel = scene.instantiate() as LiveRunTerminalResultPanel
	_check(panel != null, "real mounted scene uses LiveRunTerminalResultPanel")
	if panel == null:
		_finish()
		return
	root.add_child(panel)
	panel.return_to_title_requested.connect(_on_return)
	await _frames()
	_check(panel.has_method("open_result") and panel.has_method("close_result")
		and panel.has_method("get_presented_status"), "required public panel API exists")
	_check(not panel.visible and panel.return_button.disabled
		and not panel.has_open_result(), "initial panel is genuinely closed")
	_test_rejection()
	var victory := _victory()
	var defeat := _defeat()
	if not defeat.is_empty():
		await _test_terminal_interactions(victory, defeat)
		_test_global_rng(defeat)
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_run_terminal_result_panel_test: ",
		"PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	if is_instance_valid(panel):
		panel.free()
	quit(0 if failures.is_empty() else 1)
