extends SceneTree
## Mounted contract for a standalone, unwired terminal view. Outcomes must be
## observed by real combat services and settled by the real run latch.
const PANEL_SCENE := "res://scenes/run_terminal_result_panel.tscn"
const HEROES := "res://data/heroes/starter_party.json"
const BOSS := "res://data/enemies/boss.json"
const FIGHT := "res://data/enemies/starter_enemies.json"
const STARTER_DECK := "res://data/cards/starter_deck.json"
## Authored patch metadata for the genuine wardrobe projection; the same
## fixture shapes used by tests/run_signature_summary_test.gd.
const PATCH_DEFINITIONS := [
	{"id": "button_eye", "slot": "HEAD"},
	{"id": "stitched_badge", "slot": "HEAD"},
	{"id": "pincushion_arm", "slot": "ARM"},
	{"id": "spare_spool", "slot": "ARM"},
	{"id": "quilted_coat", "slot": "COAT"},
]

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


## Shipped starter deck IDs in authored order. Presence of the stitch halves
## is asserted, never a catalog size or a complete ordered ID list.
func _starter_deck() -> Array[String]:
	var source: String = FileAccess.get_file_as_string(STARTER_DECK)
	var authored: Variant = JSON.parse_string(source)
	var deck: Array[String] = []
	_check(authored is Array and not authored.is_empty(), "shipped starter deck parses nonempty")
	if authored is Array:
		for id in authored:
			if typeof(id) == TYPE_STRING:
				deck.append(id)
	for required in ["warden_strike", "warden_brace", "warden_shield_bash",
			"seamstress_prick", "seamstress_mend", "tinker_pop_shot"]:
		_check(deck.has(required), "shipped starter deck contains stitch half " + required)
	return deck


## Commits one real Rest stitch per requested different-hero pair, threading the
## service's own committed deck/descriptor/cursor ledger between visits.
func _stitch_pairs(deck: Array[String], pairs: Array, scraps: int) -> Dictionary:
	var current: Array[String] = deck.duplicate()
	var descriptors: Dictionary = {}
	var cursor := 1
	var remaining := scraps
	for pair in pairs:
		var first_id: String = pair[0]
		var second_id: String = pair[1]
		var first_index: int = current.find(first_id)
		var second_index: int = current.find(second_id)
		var label := "%s + %s" % [first_id, second_id]
		_check(first_index >= 0 and second_index >= 0 and first_index != second_index,
			"real stitch fixture finds distinct halves: " + label)
		if first_index < 0 or second_index < 0 or first_index == second_index:
			return {}
		var service := RunRestStitchCards.new(current, descriptors, remaining, cursor)
		_check(service.is_valid(), "real stitch service accepts the current ledger: " + label)
		if not service.is_valid():
			return {}
		var result: Dictionary = service.choose_stitch(first_index, second_index, service.get_snapshot())
		_check(result.get("ok") == true, "real stitch transaction commits " + label)
		if result.get("ok") != true:
			return {}
		current.assign(result["deck"])
		descriptors = result["descriptors"].duplicate(true)
		remaining = result["remaining_scraps"]
		cursor = result["next_stitch_id"]
	return {"deck": current, "descriptors": descriptors, "next_stitch_id": cursor}


## A genuine RunPatchWardrobe over real party heroes, sewn through its own
## optimistic-concurrency API in the given [patch, hero, slot, op] order.
func _wardrobe(deck: Array[String], sew_operations: Array) -> RunPatchWardrobe:
	var party := CombatParty.new(_definitions(HEROES))
	_check(party.is_valid(), "authored party is valid for the wardrobe projection")
	var owned: Array = []
	for definition in PATCH_DEFINITIONS:
		owned.append(definition["id"])
	var wardrobe := RunPatchWardrobe.new(party.get_heroes(), owned,
		PATCH_DEFINITIONS.duplicate(true), 5, 500, deck, 424242)
	_check(wardrobe.is_valid(), "genuine wardrobe validates against the committed deck")
	for operation in sew_operations:
		var receipt: Dictionary = wardrobe.sew(operation[0], operation[1], operation[2],
			operation[3], wardrobe.get_snapshot())
		_check(receipt.get("ok") == true,
			"real sew places %s on %s %s" % [operation[0], operation[1], operation[2]])
	return wardrobe


func _signature(ledger: Dictionary, wardrobe: RunPatchWardrobe) -> Dictionary:
	return RunSignatureSummary.summarize(ledger["deck"], ledger["descriptors"],
		ledger["next_stitch_id"], wardrobe)


func _line_with(lines: PackedStringArray, prefix: String) -> String:
	for line in lines:
		if str(line).begins_with(prefix):
			return line
	return ""


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
	var victory_settled: int = (victory_latch.get_state().get("settled_node_ids") as Array).size()
	_check(panel.open_result(victory_latch), "accepts settled Boss VICTORY")
	await _frames()
	_validate_view("Victory", "Boss victory")
	_check(panel.summary_label.text.begins_with("Battles resolved: %d\n" % victory_settled),
		"Boss victory shows correct battles resolved count")
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
	var defeat_settled: int = (defeat_latch.get_state().get("settled_node_ids") as Array).size()
	_check(panel.open_result(defeat_latch), "new settled DEFEAT opens after close")
	await _frames()
	_validate_view("Defeat", "party defeat")
	_check(panel.summary_label.text.begins_with("Battles resolved: %d\n" % defeat_settled),
		"Party defeat shows correct battles resolved count")
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


## M05 craft recap presentation: authored stitched names and readable patch
## labels, formatted from genuine stitch and wardrobe projections while a
## settled terminal result is actually open on the shipped view.
func _test_crafted_recap(defeat: Dictionary) -> void:
	var starter := _starter_deck()
	if starter.is_empty():
		return
	_check(panel.open_result(defeat["ctx"]["latch"]),
		"AC1: recap runs against a genuinely settled, accepted terminal result")
	await _frames()
	_check(panel.has_open_result() and panel.is_visible_in_tree(),
		"AC1: the recap formatter runs while the terminal view is mounted and visible")

	# One current stitched card: the authored ordered "First / Second" name.
	var single := _stitch_pairs(starter, [["warden_strike", "seamstress_prick"]], 3)
	if single.is_empty():
		panel.close_result()
		return
	var single_wardrobe := _wardrobe(single["deck"], [
		["button_eye", "warden", "HEAD", "recap_sew_warden"],
		["pincushion_arm", "seamstress", "ARM", "recap_sew_seamstress"],
		["quilted_coat", "tinker", "COAT", "recap_sew_tinker"],
	])
	var single_summary := _signature(single, single_wardrobe)
	_check(single_summary.get("ok") == true, "AC1: one-stitch summary projection is authoritative")
	_check(single_summary.get("stitched_created") == 1 and single_summary.get("stitched_current") == 1,
		"AC1: one stitch is both made and currently held")
	_check(single_summary.get("stitched_ids") == ["stitched_000001"],
		"AC1: exactly one current stitched ID comes from the authentic deck")
	var single_descriptors: Dictionary = single_summary.get("descriptors", {})
	var single_descriptor: Dictionary = single_descriptors.get("stitched_000001", {})
	_check(single_descriptor.get("display_name") == "Strike / Prick",
		"AC1: the descriptor carries the authored ordered display_name")
	var single_text := panel._format_signature(single_summary)
	var single_lines := single_text.split("\n")
	_check(single_lines.size() == 6, "AC1: two count lines, one craft line and three hero rows")
	if single_lines.size() == 6:
		_check(single_lines[0] == "Stitched: 1 made · 1 in deck",
			"AC1: exact made/in-deck count wording is preserved")
		_check(single_lines[1] == "Patches worn: 3", "AC2: exact worn count wording is preserved")
		_check(single_lines[2] == "Crafted: Strike / Prick",
			"AC1: the recap names the authored pair instead of the stitched ID")
		_check(single_lines[3] == "Warden  HEAD Button Eye  ·  ARM -  ·  COAT -",
			"AC2: Warden row keeps HEAD/ARM/COAT order with a dash for empty slots")
		_check(single_lines[4] == "Seamstress  HEAD -  ·  ARM Pincushion Arm  ·  COAT -",
			"AC2: pincushion_arm is shown as the readable title-cased Pincushion Arm")
		_check(single_lines[5] == "Tinker  HEAD -  ·  ARM -  ·  COAT Quilted Coat",
			"AC2: Tinker row keeps its order with readable coat name and empty dashes")
	_check(not single_text.contains("stitched_000001"), "AC1: opaque stitched IDs are never shown")
	_check(not single_text.contains("more"), "AC1: a single current stitched card adds no +N more")
	_check(not single_text.contains("pincushion_arm") and not single_text.contains("button_eye")
		and not single_text.contains("quilted_coat"),
		"AC2: raw worn patch IDs are never shown")

	# Three current stitched cards: exactly two names plus an accurate +1 more.
	var triple := _stitch_pairs(starter, [
		["warden_strike", "seamstress_prick"],
		["warden_brace", "seamstress_mend"],
		["warden_shield_bash", "tinker_pop_shot"],
	], 9)
	if triple.is_empty():
		panel.close_result()
		return
	var triple_wardrobe := _wardrobe(triple["deck"], [
		["button_eye", "warden", "HEAD", "recap3_sew_warden"],
		["pincushion_arm", "seamstress", "ARM", "recap3_sew_seamstress"],
		["quilted_coat", "tinker", "COAT", "recap3_sew_tinker"],
	])
	var triple_summary := _signature(triple, triple_wardrobe)
	_check(triple_summary.get("ok") == true, "AC1: three-stitch summary projection is authoritative")
	_check(triple_summary.get("stitched_created") == 3 and triple_summary.get("stitched_current") == 3,
		"AC1: three stitches are all made and held")
	_check(triple_summary.get("stitched_ids") == ["stitched_000001", "stitched_000002", "stitched_000003"],
		"AC1: three current stitched IDs are supplied in deck order")
	var triple_text := panel._format_signature(triple_summary)
	var triple_lines := triple_text.split("\n")
	_check(_line_with(triple_lines, "Stitched: ") == "Stitched: 3 made · 3 in deck",
		"AC1: three-stitch totals keep the preserved wording")
	_check(_line_with(triple_lines, "Crafted: ") == "Crafted: Strike / Prick  ·  Brace / Mend +1 more",
		"AC1: at most two authored names appear with an accurate +1 more")
	_check(not triple_text.contains("Shield Bash") and not triple_text.contains("Pop Shot"),
		"AC1: the third current name is counted, not listed")
	_check(not triple_text.contains("+2") and not triple_text.contains("stitched_"),
		"AC1: the extra count is exact and no opaque IDs appear")

	# Removed-but-previously-made stitches: historical and current stay distinct.
	var pair := _stitch_pairs(starter, [
		["warden_strike", "seamstress_prick"],
		["warden_brace", "seamstress_mend"],
	], 6)
	if pair.is_empty():
		panel.close_result()
		return
	var removed_once: Dictionary = RunShopCardRemoval.try_remove_with_stitch_ledger(
		pair["deck"], pair["descriptors"], pair["next_stitch_id"], 500, 0, "stitched_000001")
	_check(removed_once.get("ok") == true and removed_once.get("price") == 75
		and removed_once.get("gold") == 425,
		"AC3: a genuine shop removal retires the first stitched card for 75 gold")
	var deck_one: Array[String] = []
	deck_one.assign(removed_once.get("deck", []))
	var ledger_one := {
		"deck": deck_one,
		"descriptors": removed_once.get("descriptors", {}).duplicate(true),
		"next_stitch_id": removed_once.get("next_stitch_id", 0),
	}
	_check(not deck_one.has("stitched_000001") and deck_one.has("stitched_000002"),
		"AC3: only the surviving stitched card remains in the deck")
	var one_wardrobe := _wardrobe(deck_one, [
		["stitched_badge", "warden", "HEAD", "recap_one_sew_warden"],
	])
	var one_summary := _signature(ledger_one, one_wardrobe)
	_check(one_summary.get("ok") == true, "AC3: post-removal summary projection is authoritative")
	_check(one_summary.get("stitched_created") == 2 and one_summary.get("stitched_current") == 1,
		"AC3: made count keeps the retired stitch while the in-deck count falls to one")
	_check(one_summary.get("stitched_created") != one_summary.get("stitched_current"),
		"AC3: historical and current stitch totals are genuinely distinct")
	_check(one_summary.get("stitched_ids") == ["stitched_000002"],
		"AC3: a removed stitch is never listed as currently held")
	var one_text := panel._format_signature(one_summary)
	var one_lines := one_text.split("\n")
	_check(_line_with(one_lines, "Stitched: ") == "Stitched: 2 made · 1 in deck",
		"AC3: the removed stitch still counts as made but not in deck")
	_check(_line_with(one_lines, "Crafted: ") == "Crafted: Brace / Mend",
		"AC1: the surviving authored name is shown without a +N more suffix")
	_check(not one_text.contains("Strike") and not one_text.contains("stitched_000001"),
		"AC3: the retired stitch name and ID are not listed as currently held")

	var removed_twice: Dictionary = RunShopCardRemoval.try_remove_with_stitch_ledger(
		ledger_one["deck"], ledger_one["descriptors"], ledger_one["next_stitch_id"],
		425, 1, "stitched_000002")
	_check(removed_twice.get("ok") == true and removed_twice.get("price") == 100
		and removed_twice.get("gold") == 325,
		"AC3: the second genuine removal costs 100 gold")
	var deck_zero: Array[String] = []
	deck_zero.assign(removed_twice.get("deck", []))
	var ledger_zero := {
		"deck": deck_zero,
		"descriptors": removed_twice.get("descriptors", {}).duplicate(true),
		"next_stitch_id": removed_twice.get("next_stitch_id", 0),
	}
	var zero_wardrobe := _wardrobe(deck_zero, [
		["stitched_badge", "warden", "HEAD", "recap_zero_sew_warden"],
	])
	var zero_summary := _signature(ledger_zero, zero_wardrobe)
	_check(zero_summary.get("ok") == true, "AC3: zero-current summary projection is authoritative")
	_check(zero_summary.get("stitched_created") == 2 and zero_summary.get("stitched_current") == 0,
		"AC3: both retired stitches still count as made with none in deck")
	_check(zero_summary.get("stitched_ids") == [],
		"AC3: zero current stitched cards are actually reported")
	var zero_text := panel._format_signature(zero_summary)
	var zero_lines := zero_text.split("\n")
	_check(zero_lines.size() == 5, "AC3: zero current stitches add no craft line")
	_check(_line_with(zero_lines, "Stitched: ") == "Stitched: 2 made · 0 in deck",
		"AC3: historical and current totals stay distinct when the deck holds none")
	_check(_line_with(zero_lines, "Patches worn: ") == "Patches worn: 1",
		"AC2: the worn total still reflects the genuine wardrobe")
	_check(not zero_text.contains("Crafted:") and not zero_text.contains("Strike")
		and not zero_text.contains("Brace") and not zero_text.contains("stitched_"),
		"AC3: an empty current stitch recap invents no names or IDs")
	_check(zero_lines[4] == "Tinker  HEAD -  ·  ARM -  ·  COAT -",
		"AC2: empty slots remain explicit dashes in the final hero row")
	panel.close_result()
	_check(not panel.has_open_result(), "AC3: the recap view closes back to its shipped closed state")


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
		await _test_crafted_recap(defeat)
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
