extends SceneTree
## Mounted contract for a standalone, unwired terminal view. Outcomes must be
## observed by real combat services and settled by the real run latch.
const PANEL_SCENE := "res://scenes/run_terminal_result_panel.tscn"
const APP_SCENE := "res://scenes/app.tscn"
const HEROES := "res://data/heroes/starter_party.json"
const BOSS := "res://data/enemies/boss.json"
const FIGHT := "res://data/enemies/starter_enemies.json"
const STARTER_DECK := "res://data/cards/starter_deck.json"
const HEADING_FONT := "res://assets/fonts/LondrinaSolid-Regular.ttf"
const BODY_FONT := "res://assets/fonts/PatrickHand-Regular.ttf"
## Controlled synthetic path for the guarded-fallback branch. It is never
## asserted that any committed art is absent: this name simply never resolves.
const MISSING_ART := "res://assets/paper/backgrounds/__cycle178_missing_art__.png"
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
var app: Variant
var failures: Array[String] = []
var checks: int = 0
var returns: int = 0
## Genuine Composite/Halves labels mounted and checked for master typography.
var sewn_rows_checked: int = 0


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


## Publish exactly the ledger against which the real parent App is validated.
## This is a test-only staging step, never a production mutation by the panel.
func _install_run(ledger: Dictionary, wardrobe: RunPatchWardrobe = null) -> void:
	var party := CombatParty.new(_definitions(HEROES))
	_check(party.is_valid(), "App presentation fixture uses genuine authored party")
	app.run_heroes = party.get_heroes()
	app.run_deck.assign(ledger["deck"])
	app.run_stitch_descriptors = ledger["descriptors"].duplicate(true)
	app.run_next_stitch_id = ledger["next_stitch_id"]
	var carry := RunTornCarryover.new(app.run_heroes)
	_check(carry.is_valid(), "App carryover matches authored party")
	if wardrobe != null:
		var snap: Dictionary = wardrobe.get_snapshot()
		app.run_trinkets.assign(snap.owned)
		app.run_scraps = snap.scraps
		app.session_gold = snap.gold
		_check(carry.bind_wardrobe(wardrobe, carry.torn, snap),
			"live wardrobe bound to App carryover with genuine snapshot")
	else:
		app.run_trinkets.clear()
		app.run_scraps = 0
		app.session_gold = 0
	app.party_carryover = carry


func _app_snapshot() -> Dictionary:
	return {
		"heroes": app.run_heroes.duplicate(true),
		"deck": app.run_deck.duplicate(),
		"descriptors": app.run_stitch_descriptors.duplicate(true),
		"cursor": app.run_next_stitch_id,
		"trinkets": app.run_trinkets.duplicate(),
		"scraps": app.run_scraps,
		"gold": app.session_gold,
		"carry": app.party_carryover.read_state(),
		"wardrobe": app.party_carryover._wardrobe.get_snapshot()
			if app.party_carryover._wardrobe != null else {},
	}


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


func _connected_draws(target: Control, method: String) -> int:
	if target == null:
		return 0
	var total := 0
	for entry in target.draw.get_connections():
		var callable: Callable = entry.get("callable", Callable())
		if callable.is_valid() and callable.get_method() == method:
			total += 1
	return total


func _validate_view(status: String, label: String) -> void:
	_check(panel.has_open_result() and panel.is_visible_in_tree(),
		label + " mounted and visible")
	_check(panel.get_presented_status() == status.to_upper() and panel.title_label.text == status,
		label + " authoritative terminal heading and presentation state")
	_check(panel.title_label.theme_type_variation == "PatchHeading"
		and (panel.title_label.get_theme_font("font") as Font).resource_path == HEADING_FONT,
		label + " witnessed outcome title wears the master PatchHeading Londrina face")
	var sentence := ("The final boss has fallen. The run is complete."
		if status == "Victory" else "The party has fallen. The run has ended.")
	_check(panel.description_label.text == sentence, label + " short distinct neutral sentence")
	_check(panel.description_label.theme_type_variation == ""
		and (panel.description_label.get_theme_font("font") as Font).resource_path == BODY_FONT
		and panel.summary_label.theme_type_variation == ""
		and (panel.summary_label.get_theme_font("font") as Font).resource_path == BODY_FONT,
		label + " outcome sentence and run ledger stay in the inherited body font")
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
	var stage := panel.get_node_or_null("ResultBackdropArt") as TextureRect
	_check(stage != null and stage.texture != null and stage.is_visible_in_tree(),
		label + " established illustrated camp stage is mounted and visible")
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	if stage != null:
		_check(stage.get_index() < panel.paper_panel.get_index()
			and backdrop != null and stage.get_index() > backdrop.get_index(),
			label + " illustration is a full-rect sibling before the paper")
		_check(stage.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and stage.expand_mode == TextureRect.EXPAND_IGNORE_SIZE
			and stage.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED,
			label + " inert illustration preserves the picture aspect while covering")
		_check(stage.get_global_rect() == screen,
			label + " illustration covers the whole 1280x720 stage")
		if stage.texture != null:
			_check(stage.texture.resource_path == LiveRunTerminalResultPanel.CAMP_BACKDROP,
				label + " only the already-imported camp picture is used")
	var felt := panel.get_node_or_null("FeltMat") as PanelContainer
	var felt_box := (felt.get_theme_stylebox("panel") as StyleBoxFlat) if felt != null else null
	_check(felt != null and felt.is_visible_in_tree()
		and felt.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and felt_box != null and felt_box.bg_color.get_luminance() < 0.3
		and felt.get_global_rect().encloses(panel.paper_panel.get_global_rect())
		and felt.get_index() < panel.paper_panel.get_index(),
		label + " dark felt mat lies behind and around the parchment")
	_check(_connected_draws(panel.paper_panel, "_draw_paper_stitches") >= 1
		and _connected_draws(felt, "_draw_felt_stitches") >= 1,
		label + " conspicuous stitched perimeter is drawn on parchment and felt")
	_check(paper != null and felt_box != null
		and absf(LiveRunTerminalResultPanel.PAPER_THREAD.get_luminance()
			- paper.bg_color.get_luminance()) > 0.3
		and absf(LiveRunTerminalResultPanel.FELT_THREAD.get_luminance()
			- felt_box.bg_color.get_luminance()) > 0.3,
		label + " seam threads contrast with both parchment and felt")
	_check(panel.title_label.get_theme_stylebox("normal") is StyleBoxFlat
		and panel.summary_label.get_theme_stylebox("normal") is StyleBoxFlat
		and panel.title_label.get_theme_font_size("font_size")
			> panel.description_label.get_theme_font_size("font_size")
		and panel.description_label.get_theme_font_size("font_size")
			>= panel.summary_label.get_theme_font_size("font_size"),
		label + " sewn title plaque, bounded ledger and descending text hierarchy")
	_check(panel.top_stitches.text.contains("×") and panel.bottom_stitches.text.contains("×")
		and panel.top_stitches.get_theme_color("font_color") != Color.TRANSPARENT,
		label + " visible decorative running stitches")
	_check(paper != null and absf(paper.bg_color.get_luminance()
		- panel.title_label.get_theme_color("font_color").get_luminance()) > 0.4,
		label + " readable paper/heading contrast")
	_check(button.get_theme_stylebox("normal") is StyleBoxFlat
		and button.get_theme_stylebox("focus") is StyleBoxFlat,
		label + " procedural cardboard button and focus ring")
	var controls: Array = [panel.paper_panel, panel.title_label, panel.description_label,
		panel.top_stitches, panel.bottom_stitches, button, panel.summary_label]
	if stage != null:
		controls.append(stage)
	if felt != null:
		controls.append(felt)
	if panel.stitched_section.visible:
		controls.append(panel.stitched_section)
		controls.append(panel.stitched_heading)
		controls.append(panel.stitched_scroll)
		var detail_paper := panel.stitched_section.get_theme_stylebox("panel") as StyleBoxFlat
		_check(detail_paper != null and detail_paper.bg_color.get_luminance() > 0.5
			and detail_paper.border_width_left >= 2,
			label + " bounded sewn-card paper has high contrast and dark stitched border")
	for control in controls:
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
		and panel.get_presented_status() == "" and panel.return_button.disabled
		and not panel.stitched_section.visible and panel.stitched_rows.get_child_count() == 0,
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


## The illustrated stage is optional presentation. A deliberately missing
## picture must remove only that layer: the settled result, its exact text, the
## felt/paper framing and the sole Return action all stay intact, and no run
## state, currency or RNG moves. A controlled synthetic path is used, so this
## never asserts that any committed art file is absent.
func _test_missing_backdrop_art(ctx: Dictionary, battle: Dictionary, label: String) -> void:
	var before := _snapshot(ctx, battle)
	var stage := panel.get_node_or_null("ResultBackdropArt") as TextureRect
	_check(stage != null and stage.texture != null and stage.is_visible_in_tree(),
		label + " starts from the real illustrated stage")
	if stage == null:
		return
	var title := panel.title_label.text
	var description := panel.description_label.text
	var summary := panel.summary_label.text
	var felt := panel.get_node_or_null("FeltMat") as PanelContainer
	var felt_box := (felt.get_theme_stylebox("panel") as StyleBoxFlat) if felt != null else null
	var paper := panel.paper_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_check(LiveRunTerminalResultPanel.guarded_texture(MISSING_ART) == null
		and LiveRunTerminalResultPanel.guarded_texture("") == null,
		label + " guarded picture lookup fails closed for empty and missing paths")
	_check(not panel.apply_backdrop_art(MISSING_ART),
		label + " missing picture reports no illustrated layer")
	await _frames()
	_check(not stage.visible and stage.texture == null and not stage.is_visible_in_tree(),
		label + " only the picture layer disappears")
	_check(panel.is_visible_in_tree() and panel.has_open_result()
		and panel.title_label.text == title and panel.description_label.text == description
		and panel.summary_label.text == summary,
		label + " exact result text survives the missing picture")
	_check(not panel.return_button.disabled and panel.return_button.is_visible_in_tree(),
		label + " sole Return action stays available without the picture")
	var slate := panel.get_node("SlateBackdrop") as ColorRect
	_check(slate.is_visible_in_tree() and slate.color.get_luminance() < 0.3,
		label + " slate keeps the stage dark without the picture")
	_check(felt != null and felt.is_visible_in_tree() and felt_box != null
		and felt_box.bg_color.get_luminance() < 0.3
		and paper != null and paper.bg_color.get_luminance() > 0.5
		and panel.stitched_section.visible == (panel.stitched_rows.get_child_count() > 0),
		label + " felt and parchment framing stays readable without the picture")
	_check(_snapshot(ctx, battle) == before,
		label + " missing picture and stage changes never alter run state or RNG")
	_check(panel.apply_backdrop_art(LiveRunTerminalResultPanel.CAMP_BACKDROP),
		label + " the already-imported camp picture remounts")
	await _frames()
	_check(stage.visible and stage.is_visible_in_tree() and stage.texture != null
		and stage.texture.resource_path == LiveRunTerminalResultPanel.CAMP_BACKDROP,
		label + " restored illustration is the same existed camp picture")
	_check(panel.title_label.text == title and panel.description_label.text == description
		and panel.summary_label.text == summary and not panel.return_button.disabled,
		label + " restoring the picture never rewrites the settled result")
	_check(_snapshot(ctx, battle) == before,
		label + " remounting the illustrated stage preserves authoritative state")


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
	await _test_missing_backdrop_art(victory_ctx, victory_battle, "Boss victory")
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
	await _test_missing_backdrop_art(defeat_ctx, defeat_battle, "party defeat")
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
	await _mounted_composites(triple, triple_wardrobe, triple_summary, defeat,
		"three retained composites")
	await _mounted_composites(ledger_one, one_wardrobe, one_summary, defeat,
		"Shop single survivor")
	await _mounted_composites(ledger_zero, zero_wardrobe, zero_summary, defeat,
		"fully removed composites")
	_check(sewn_rows_checked >= 3,
		"genuine sewn rows were mounted and their heading/half typography actually checked")


## Exercise the actual App-mounted scene, not just a formatting helper.
## Compare each visible card to the detached canonical projection and scroll
## through the third row while proving the App, battle and map remain unchanged.
func _mounted_composites(ledger: Dictionary, wardrobe: RunPatchWardrobe,
		expected: Dictionary, defeat: Dictionary, label: String) -> void:
	_install_run(ledger, wardrobe)
	var before: Dictionary = _app_snapshot()
	var state: Dictionary = _snapshot(defeat["ctx"], defeat["battle"])
	_check(expected.get("ok") == true, label + " source oracle is authentic")
	_check(panel.open_result(defeat["ctx"]["latch"]),
		label + " opens genuine DEFEAT under App")
	await _frames()
	_validate_view("Defeat", label)
	var cards: Array = expected.get("current_stitched_cards", [])
	_check(panel.stitched_section.visible == not cards.is_empty()
		and panel.stitched_rows.get_child_count() == cards.size(),
		label + " detail visibility and exact retained count")
	for i in range(cards.size()):
		var card: Dictionary = cards[i]
		var first: Dictionary = RunRestStitchCards.resolve_card_definition(card.half_ids[0])
		var second: Dictionary = RunRestStitchCards.resolve_card_definition(card.half_ids[1])
		_check(not first.is_empty() and not second.is_empty()
			and card.owners == [first.owner, second.owner]
			and first.owner != second.owner,
			label + " authentic first/second owner pairing")
		var row := panel.stitched_rows.get_child(i)
		var name_label := row.get_node("CardInset/CardLines/Composite") as Label
		var halves_label := row.get_node("CardInset/CardLines/Halves") as Label
		_check(name_label.text == "%s  ·  %d energy" % [card.display_name, card.cost],
			label + " name and capped cost in deck order")
		_check(halves_label.text == "1 · %s (%s)    →    2 · %s (%s)" % [
			first.display_name, str(first.owner).capitalize(),
			second.display_name, str(second.owner).capitalize()],
			label + " authored halves and distinct owners in order")
		_check(panel.stitched_heading.theme_type_variation == "PatchHeading"
			and (panel.stitched_heading.get_theme_font("font") as Font).resource_path == HEADING_FONT,
			label + " stitched detail heading wears the master PatchHeading face")
		_check(name_label.theme_type_variation == "PatchHeading"
			and (name_label.get_theme_font("font") as Font).resource_path == HEADING_FONT,
			label + " genuine composite name wears the master PatchHeading face")
		_check(halves_label.theme_type_variation == ""
			and (halves_label.get_theme_font("font") as Font).resource_path == BODY_FONT,
			label + " both ordered half descriptions stay in the inherited body font")
		sewn_rows_checked += 1
	if cards.size() >= 3:
		var bar := panel.stitched_scroll.get_v_scroll_bar()
		_check(bar.max_value > panel.stitched_scroll.size.y,
			label + " scroll viewport is shorter than three retained rows")
		panel.stitched_scroll.scroll_vertical = 99999
		await _frames()
		_check(panel.stitched_scroll.scroll_vertical > 0,
			label + " third retained row is accessible by vertical scrolling")
	_check(_app_snapshot() == before and _snapshot(defeat["ctx"], defeat["battle"]) == state,
		label + " open and scroll preserve App, battle, map and seeded RNG")
	panel.close_result()
	_check(not panel.stitched_section.visible and panel.stitched_rows.get_child_count() == 0
		and panel.stitched_scroll.scroll_vertical == 0,
		label + " close removes all rows and resets scrolling")
	_check(_app_snapshot() == before, label + " close preserves full App/wardrobe state")


## The full mounted route covers a reordered carried run. Here independently
## verify that a snapshot-only projection preserves real worn hero slots and
## stitched receipts without inventing a starter carryover.
func _test_reordered_heroes() -> void:
	var sewn := _stitch_pairs(_starter_deck(), [
		["warden_strike", "seamstress_prick"],
		["warden_brace", "tinker_pop_shot"],
	], 6)
	if sewn.is_empty():
		return
	var reordered := _definitions(HEROES)
	var first: Dictionary = reordered[0]
	reordered[0] = reordered[1]
	reordered[1] = first
	var party := CombatParty.new(reordered)
	_check(party.is_valid(), "authored CombatParty permits reordered hero positions")
	if not party.is_valid():
		return
	var wardrobe := RunPatchWardrobe.new(party.get_heroes(),
		["button_eye", "pincushion_arm"], PATCH_DEFINITIONS.duplicate(true),
		4, 35, sewn["deck"], 424242, true)
	_check(wardrobe.is_valid(), "authentic reordered wardrobe validates")
	if not wardrobe.is_valid():
		return
	_check(wardrobe.sew("button_eye", "warden", "HEAD", "ordered_head",
		wardrobe.get_snapshot()).get("ok") == true, "genuine reordered HEAD sewing")
	_check(wardrobe.sew("pincushion_arm", "seamstress", "ARM", "ordered_arm",
		wardrobe.get_snapshot()).get("ok") == true, "genuine reordered ARM sewing")
	var before := wardrobe.get_snapshot()
	var projection: RunPatchWardrobe = panel._canonical_signature_wardrobe(wardrobe)
	_check(projection != null and projection != wardrobe and projection.is_valid(),
		"reordered real wardrobe yields an independent valid read-only projection")
	if projection == null:
		return
	var projected := projection.get_snapshot()
	_check(projected["heroes"][0].id == "warden"
		and projected["heroes"][1].id == "seamstress"
		and projected["heroes"][2].id == "tinker",
		"presentation-only positions are canonical for the signature reader")
	_check(projected["worn"] == before["worn"] and projected["owned"] == before["owned"]
		and projected["scraps"] == before["scraps"] and projected["gold"] == before["gold"]
		and projected["cards"] == before["cards"],
		"every authored wearer and real deck/currency survives the detached projection")
	var signature: Dictionary = RunSignatureSummary.summarize(sewn["deck"],
		sewn["descriptors"], sewn["next_stitch_id"], projection)
	_check(signature.get("ok") == true and signature.get("stitched_current") == 2
		and signature.get("worn_total") == 2,
		"canonical signature validates both real stitched cards and both wear receipts")
	_check(signature["heroes"][0].slots.HEAD == "button_eye"
		and signature["heroes"][1].slots.ARM == "pincushion_arm",
		"summary attributes worn patches to real owners, not physical party order")
	var kept: Array = signature.get("current_stitched_cards", [])
	_check(kept.size() == 2 and kept[0].display_name == "Strike / Prick"
		and kept[1].display_name == "Brace / Pop Shot",
		"reordered projection keeps authored ordered stitched descriptors unchanged")
	_check(wardrobe.get_snapshot() == before,
		"repeated projection and signature reads never alter the actual wardrobe receipt")


func _test_invalid_source(defeat: Dictionary) -> void:
	var before := _app_snapshot()
	app.run_next_stitch_id = 0
	_check(panel.open_result(defeat["ctx"]["latch"]),
		"invalid App ledger still shows authentic terminal outcome")
	_check(panel.summary_label.text.ends_with("Summary unavailable")
		and panel.return_button.disabled and not panel.stitched_section.visible
		and panel.stitched_rows.get_child_count() == 0,
		"invalid ledger never creates card detail or an enabled Return")
	var earlier := returns
	panel.return_button.pressed.emit()
	_check(returns == earlier, "invalid run source refuses injected Return signal")
	panel.close_result()
	app.run_next_stitch_id = before.cursor
	_check(_app_snapshot() == before, "invalid panel visit cannot mutate or repair source ledger")
	panel.reparent(root)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_check(panel.open_result(defeat["ctx"]["latch"]),
		"non-App mounted panel can show terminal sentence without fabricated summary")
	_check(panel.summary_label.text.ends_with("Summary unavailable")
		and panel.return_button.disabled and not panel.stitched_section.visible
		and panel.stitched_rows.get_child_count() == 0,
		"non-App host cannot authorize sewn detail or Return")
	panel.return_button.pressed.emit()
	_check(returns == earlier, "non-App host refuses a forced Return signal")
	panel.close_result()
	panel.reparent(app)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_check(_app_snapshot() == before, "non-App rejection preserves source state")


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
	var app_scene := load(APP_SCENE) as PackedScene
	_check(scene != null and app_scene != null, "dedicated terminal and App scenes load")
	if scene == null or app_scene == null:
		_finish()
		return
	panel = scene.instantiate() as LiveRunTerminalResultPanel
	_check(panel != null, "real mounted scene uses LiveRunTerminalResultPanel")
	if panel == null:
		_finish()
		return
	app = app_scene.instantiate()
	root.add_child(app)
	app.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.return_to_title_requested.connect(_on_return)
	await _frames()
	var initial := _starter_deck()
	_install_run({"deck": initial, "descriptors": {}, "next_stitch_id": 1})
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
		_test_reordered_heroes()
		_test_global_rng(defeat)
		_test_invalid_source(defeat)
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
