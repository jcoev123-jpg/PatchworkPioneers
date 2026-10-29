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
func _install_run(ledger: Dictionary, wardrobe: RunPatchWardrobe = null,
		chosen: Array = []) -> void:
	var party := CombatParty.new(_definitions(HEROES) if chosen.is_empty() else chosen)
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


func _signature(ledger: Dictionary, wardrobe: RunPatchWardrobe,
		tears_by_id: Dictionary = {}) -> Dictionary:
	var summary: Dictionary = _signature_with_stats(ledger, wardrobe, tears_by_id)
	return summary

## These stitch/wardrobe recap ledgers never admitted a battle, so their genuine
## tear count is zero; a caller proving a real tear passes its by-ID map.
func _signature_with_stats(ledger: Dictionary, wardrobe: RunPatchWardrobe,
		tears_by_id: Dictionary = {}) -> Dictionary:
	var summary: Dictionary = RunSignatureSummary.summarize(ledger["deck"], ledger["descriptors"],
		ledger["next_stitch_id"], wardrobe)
	if summary.get("ok") != true or wardrobe == null or not wardrobe.is_valid():
		return summary
	var snap: Dictionary = wardrobe.get_snapshot()
	summary["gold"] = snap.get("gold", 0)
	summary["scraps"] = snap.get("scraps", 0)
	var by_id: Dictionary = {}
	for h in snap.get("heroes", []):
		if h is Dictionary and h.has("id"):
			by_id[h["id"]] = h
	for h in summary.get("heroes", []):
		var hid: String = h.get("hero_id", "")
		if by_id.has(hid):
			h["hp"] = by_id[hid].get("hp", 0)
			h["max_hp"] = by_id[hid].get("max_hp", 0)
		h["tears"] = int(tears_by_id.get(hid, 0))
	return summary

func _orig_signature(ledger: Dictionary, wardrobe: RunPatchWardrobe) -> Dictionary:
	return RunSignatureSummary.summarize(ledger["deck"], ledger["descriptors"],
		ledger["next_stitch_id"], wardrobe)


func _line_with(lines: PackedStringArray, prefix: String) -> String:
	for line in lines:
		if str(line).begins_with(prefix):
			return line
	return ""


## Independent depth oracle for an expected mounted readout: the floor the real
## generated map's own route stands on. Never the settled battle count.
func _floor_clause(ctx: Dictionary) -> String:
	var map: RunMap = ctx["map"]
	return " · Floor reached: %d/%d" % [map.get_current_floor(), RunMap.FLOOR_COUNT]


## Exact visible text of one mounted hero ribbon: the heading name printed
## beside its body detail, assembled independently of the panel's own helpers.
func _hero_row_text(row: Control) -> String:
	if row == null:
		return ""
	var name_label := row.get_node_or_null("RowInset/RowLine/HeroName") as Label
	var detail_label := row.get_node_or_null("RowInset/RowLine/HeroDetail") as Label
	if name_label == null or detail_label == null:
		return ""
	var badge := row.get_node_or_null("RowInset/RowLine/TornBadge") as Label
	if badge != null and badge.visible and not badge.text.is_empty():
		return "%s %s %s" % [name_label.text, badge.text, detail_label.text]
	return "%s %s" % [name_label.text, detail_label.text]


func _hero_rows_text() -> PackedStringArray:
	var lines := PackedStringArray()
	for row in panel.hero_rows.get_children():
		lines.append(_hero_row_text(row as Control))
	return lines


## Every mounted hero ribbon must equal the independent oracle exactly, in the
## canonical Warden/Seamstress/Tinker identity order.
func _check_hero_rows(expected: Array[String], label: String) -> void:
	var rows := _hero_rows_text()
	_check(rows.size() == expected.size() and rows.size() == 3,
		label + ": exactly three mounted hero recap ribbons")
	for index in range(mini(rows.size(), expected.size())):
		_check(rows[index] == expected[index],
			label + ": hero recap ribbon %d matches the independent oracle" % index)


## Independent hero-row oracle built straight from the authoritative summary
## fields, never from the panel's own formatter.
func _oracle_hero_lines(summary: Dictionary, defeated: bool = false) -> Array[String]:
	summary = summary.duplicate(true)
	if defeated:
		for hero in summary.get("heroes", []):
			hero["hp"] = 0
	var lines: Array[String] = []
	for hero in summary.get("heroes", []):
		var parts: Array[String] = ["%d/%d HP" % [int(hero.hp), int(hero.max_hp)]]
		parts.append("1 tear" if int(hero.tears) == 1 else "%d tears" % int(hero.tears))
		var worn: Array[String] = []
		for slot in ["HEAD", "ARM", "COAT"]:
			var patch_id: String = hero.slots[slot]
			if not patch_id.is_empty():
				worn.append("%s %s" % [slot, patch_id.capitalize()])
		parts.append(" · ".join(worn) if not worn.is_empty() else "no patches")
		var hero_name := str(hero.hero_id).capitalize()
		var detail := " · ".join(parts)
		if int(hero.hp) == 0:
			lines.append("%s %s %s" % [hero_name, "TORN", detail])
		else:
			lines.append("%s %s" % [hero_name, detail])
	return lines


func _battle(enemy_path: String, chosen: Array = []) -> Dictionary:
	var party := CombatParty.new(_definitions(HEROES) if chosen.is_empty() else chosen)
	var definitions := _definitions(enemy_path)
	if enemy_path == BOSS:
		definitions = definitions.filter(func(entry): return entry.get("id") == "patchwork_behemoth")
	var enemies := CombatEnemies.new(definitions)
	_check(party.is_valid() and enemies.is_valid(), "genuine living combat services are valid")
	var expected_ids := ["warden", "seamstress", "tinker"] if chosen.is_empty() else [chosen[0].id, chosen[1].id, chosen[2].id]
	_check(party.get_heroes().size() == 3
		and party.get_hero(1).get("id") == expected_ids[0]
		and party.get_hero(2).get("id") == expected_ids[1]
		and party.get_hero(3).get("id") == expected_ids[2],
		"authored chosen identities occupy their actual three seats")
	_check(not party.is_defeated() and not enemies.is_victorious(),
		"both battle rosters begin alive")
	if enemy_path == BOSS:
		_check(enemies.get_enemy(1).get("id") == "patchwork_behemoth"
			and enemies.get_enemy(1).get("hp") == 84,
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


func _victory(chosen: Array = []) -> Dictionary:
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
			var intermediate := _battle(FIGHT, chosen)
			_settle_win(ctx, intermediate, "floor %d %s" % [index + 1, kind])
			previous_settled += 1
			_check(ctx["latch"].get_state().run_status == RunActBattleOutcome.ACTIVE,
				"intermediate Fight/Elite win leaves run ACTIVE")
	_check(map.is_complete() and map.get_current_floor() == 12
		and map.get_node(map.get_current_node_id()).get("type") == "Boss",
		"actual selected final node is a floor-12 Boss")
	var battle := _battle(BOSS, chosen)
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


func _settle_defeat(ctx: Dictionary, battle: Dictionary) -> bool:
	app.act_outcome = ctx["latch"]
	app.run_map = ctx["map"]
	app.party = battle["party"]
	app.battle_result = battle["result"]
	return app._settle_act_battle()


func _defeat(chosen: Array = []) -> Dictionary:
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
	var battle := _battle(FIGHT, chosen)
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
	_check(_settle_defeat(ctx, battle), "observed Fight defeat settles")
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


## Independent oracle for the stage picture each validated terminal verdict must
## select: the shipped Boss battlefield for a won run, the sewn camp for a fallen
## party.
func _expected_backdrop(status: String) -> String:
	return (LiveRunTerminalResultPanel.BOSS_BACKDROP if status == "Victory"
		else LiveRunTerminalResultPanel.CAMP_BACKDROP)


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
	var button_font := button.get_theme_font("font") as Font
	_check(button.theme_type_variation == "PatchHeadingButton"
		and button_font != null and button_font.resource_path == HEADING_FONT
		and button.get_theme_font_size("font_size") == 24,
		label + " original Return action resolves to 24 px Londrina via PatchHeadingButton")
	var paper := panel.paper_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_check(paper != null and paper.border_width_left >= 4 and paper.border_width_top >= 4
		and paper.bg_color.get_luminance() > 0.5,
		label + " cream paper and thick sewn patch border")
	var backdrop := panel.get_node("SlateBackdrop") as ColorRect
	_check(backdrop != null and backdrop.color.get_luminance() < 0.3,
		label + " dark slate ColorRect covers background")
	var stage := panel.get_node_or_null("ResultBackdropArt") as TextureRect
	_check(stage != null and stage.texture != null and stage.is_visible_in_tree(),
		label + " authenticated verdict illustration is mounted and visible")
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
			var expected_backdrop := _expected_backdrop(status)
			var other_backdrop := (LiveRunTerminalResultPanel.CAMP_BACKDROP
				if expected_backdrop == LiveRunTerminalResultPanel.BOSS_BACKDROP
				else LiveRunTerminalResultPanel.BOSS_BACKDROP)
			_check(stage.texture.resource_path == expected_backdrop,
				label + " selects the already-imported picture of its own verdict")
			_check(stage.texture.resource_path != other_backdrop,
				label + " never shows the other terminal verdict's picture")
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
	var recap_rows := panel.hero_rows.get_children()
	_check(panel.hero_recap.is_visible_in_tree() and recap_rows.size() == 3,
		label + " three sewn hero recap ribbons are mounted")
	var previous_bottom := panel.description_label.get_global_rect().end.y
	_check(panel.hero_recap_title.get_global_rect().position.y >= previous_bottom - 0.5,
		label + " party recap heading follows the outcome without overlap")
	var previous_right := panel.hero_rows.get_global_rect().position.x
	for row in recap_rows:
		var ribbon := row as PanelContainer
		var ribbon_box := (ribbon.get_theme_stylebox("panel") as StyleBoxFlat) if ribbon != null else null
		_check(ribbon != null and ribbon_box != null
			and ribbon_box.bg_color.get_luminance() > 0.5
			and ribbon_box.border_width_left >= 1
			and ribbon_box.border_color.get_luminance() < 0.6,
			label + " hero ribbon wears the sewn cream felt panel: " + str(row.name))
		_check(row.get_global_rect().position.x >= previous_right - 0.5,
			label + " hero ticket follows the previous ticket without overlap")
		previous_right = row.get_global_rect().end.x
		var portrait := row.get_node_or_null("RowInset/HeroPortrait") as TextureRect
		var hero_id: String = ["warden", "seamstress", "tinker"][row.get_index()]
		_check(portrait != null and portrait.texture != null
			and portrait.texture.resource_path == "res://assets/paper/heroes/%s.png" % hero_id,
			label + " matching shipped portrait for " + hero_id)
		if portrait != null:
			_check(portrait.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and portrait.focus_mode == Control.FOCUS_NONE
				and portrait.expand_mode == TextureRect.EXPAND_IGNORE_SIZE
				and portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				and portrait.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
				label + " portrait is inert, linear filtered and aspect preserving")
		var name_label := row.get_node("RowInset/RowLine/HeroName") as Label
		var detail_label := row.get_node("RowInset/RowLine/HeroDetail") as Label
		var seat_label := row.get_node_or_null("RowInset/RowLine/SeatLabel") as Label
		var seat_index: int = row.get_index()
		_check(seat_label != null and seat_label.text == "%s  ·  %d" % [
			LiveRunTerminalResultPanel.HERO_SEAT_NAMES[seat_index], seat_index + 1]
			and seat_label.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and seat_label.get_theme_font_size("font_size") >= 18,
			label + " genuine front/middle/back sewn tab ignores pointer input")
		_check(name_label != null and name_label.theme_type_variation == "PatchHeading"
			and (name_label.get_theme_font("font") as Font).resource_path == HEADING_FONT
			and name_label.get_theme_font_size("font_size") >= 18,
			label + " hero ribbon name keeps the inherited PatchHeading face at 18 px or more")
		_check(detail_label != null and detail_label.theme_type_variation == ""
			and (detail_label.get_theme_font("font") as Font).resource_path == BODY_FONT
			and detail_label.get_theme_font_size("font_size") >= 18,
			label + " hero ribbon detail keeps the inherited body face at 18 px or more")
		_check(screen.encloses(row.get_global_rect()),
			label + " hero ribbon fits the 1280x720 stage")
		_check(detail_label.get_line_count() > 0
			and detail_label.get_visible_line_count() == detail_label.get_line_count()
			and row.get_global_rect().encloses(detail_label.get_global_rect()),
			label + " full wrapped HP/tear/patch text is inside the sewn ticket")
		_check(row.size.y >= 180.0 and row.size.y <= 260.0,
			label + " hero portrait ticket is prominent and bounded, height %s" % str(row.size.y))
	_check(panel.hero_recap.size.y <= 290.0,
		label + " three portrait tickets leave space for the ledger and Return")
	var controls: Array = [panel.paper_panel, panel.title_label, panel.description_label,
		panel.top_stitches, panel.bottom_stitches, button, panel.summary_label,
		panel.hero_recap, panel.hero_recap_title, panel.hero_rows]
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
		and not panel.stitched_section.visible and panel.stitched_rows.get_child_count() == 0
		and not panel.hero_recap.visible and panel.hero_rows.get_child_count() == 0,
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
func _test_missing_backdrop_art(ctx: Dictionary, battle: Dictionary, label: String,
		expected_backdrop: String) -> void:
	var before := _snapshot(ctx, battle)
	var stage := panel.get_node_or_null("ResultBackdropArt") as TextureRect
	_check(stage != null and stage.texture != null and stage.is_visible_in_tree()
		and stage.texture.resource_path == expected_backdrop,
		label + " starts from the verdict's own illustrated stage")
	if stage == null:
		return
	var title := panel.title_label.text
	var description := panel.description_label.text
	var summary := panel.summary_label.text
	var recap := _hero_rows_text()
	var app_before := _app_snapshot()
	for row in panel.hero_rows.get_children():
		var portrait := row.get_node("RowInset/HeroPortrait") as TextureRect
		_check(portrait != null and portrait.texture != null,
			label + " missing-portrait probe starts from a shipped texture")
		if portrait == null or portrait.texture == null:
			continue
		var original_path := portrait.texture.resource_path
		_check(not panel.apply_hero_portrait(portrait, MISSING_ART),
			label + " unavailable hero portrait selects felt fallback")
		await _frames()
		_check(portrait.texture == null and row.is_visible_in_tree()
			and row.get_theme_stylebox("panel") is StyleBoxFlat
			and _hero_rows_text() == recap and panel.summary_label.text == summary
			and not panel.return_button.disabled and panel.return_button.is_visible_in_tree(),
			label + " felt fallback preserves the full text ticket, ledger and Return")
		_check(panel.apply_hero_portrait(portrait, original_path)
			and portrait.texture.resource_path == original_path,
			label + " matching hero portrait remounts")
	_check(_app_snapshot() == app_before and _snapshot(ctx, battle) == before,
		label + " missing hero art never changes authorities or RNG")
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
		and panel.summary_label.text == summary and _hero_rows_text() == recap,
		label + " exact result text and hero ribbons survive the missing picture")
	_check(not panel.return_button.disabled and panel.return_button.is_visible_in_tree(),
		label + " sole Return action stays available without the picture")
	var fallback_font := panel.return_button.get_theme_font("font") as Font
	_check(panel.return_button.theme_type_variation == "PatchHeadingButton"
		and fallback_font != null and fallback_font.resource_path == HEADING_FONT
		and panel.return_button.get_theme_font_size("font_size") == 24,
		label + " missing picture leaves the original Return action in 24 px Londrina")
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
	_check(panel.apply_backdrop_art(expected_backdrop),
		label + " the verdict's already-imported picture remounts")
	await _frames()
	_check(stage.visible and stage.is_visible_in_tree() and stage.texture != null
		and stage.texture.resource_path == expected_backdrop,
		label + " restored illustration is the same existed picture as the verdict")
	_check(panel.title_label.text == title and panel.description_label.text == description
		and panel.summary_label.text == summary and _hero_rows_text() == recap
		and not panel.return_button.disabled,
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
	_check(panel.return_button.has_focus() and panel.return_button.is_visible_in_tree(),
		"AC1: settled Boss victory hands Return real keyboard focus with no test grab_focus")
	_validate_view("Victory", "Boss victory")
	var victory_stage := panel.get_node_or_null("ResultBackdropArt") as TextureRect
	_check(victory_stage != null and victory_stage.texture != null
		and victory_stage.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and victory_stage.texture.resource_path == LiveRunTerminalResultPanel.BOSS_BACKDROP,
		"settled Boss victory selects the shipped Boss stage behind an inert picture")
	var victory_backdrop := (victory_stage.texture.resource_path
		if victory_stage != null and victory_stage.texture != null else "")
	_check(panel.summary_label.text.begins_with(
		"Battles resolved: %d · Gold: 0 · Scraps: 0%s\n" % [victory_settled, _floor_clause(victory_ctx)]),
		"Boss victory shows correct battles resolved count and reached floor")
	var victory_floor_node := (victory_ctx["map"] as RunMap).get_node(
		(victory_ctx["map"] as RunMap).get_current_node_id())
	_check((victory_ctx["map"] as RunMap).get_current_floor() == RunMap.FLOOR_COUNT
		and victory_floor_node.get("type") == "Boss"
		and panel.summary_label.text.contains("Floor reached: %d/%d" % [RunMap.FLOOR_COUNT, RunMap.FLOOR_COUNT]),
		"AC1: the settled floor-12 Boss route prints Floor reached: 12/12")
	_check(victory_settled < RunMap.FLOOR_COUNT,
		"AC1: the real Boss route resolved fewer battles than floors, so the depth is not the battle count")
	await _test_missing_backdrop_art(victory_ctx, victory_battle, "Boss victory",
		_expected_backdrop("Victory"))
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
	var mouse_portrait := panel.hero_rows.get_child(0).get_node("RowInset/HeroPortrait") as TextureRect
	_check(mouse_portrait.texture != null and not panel.apply_hero_portrait(mouse_portrait, MISSING_ART),
		"AC3: mouse Return probe genuinely removes a previously mounted hero portrait")
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
	var defeat_stage := panel.get_node_or_null("ResultBackdropArt") as TextureRect
	_check(defeat_stage != null and panel.title_label.text == "Defeat"
		and defeat_stage.texture != null
		and defeat_stage.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and defeat_stage.texture.resource_path == LiveRunTerminalResultPanel.CAMP_BACKDROP,
		"outcome switch: defeat after a closed victory shows the camp picture")
	if victory_stage != null and defeat_stage != null:
		_check(not victory_backdrop.is_empty() and defeat_stage.texture != null
			and defeat_stage.texture.resource_path != victory_backdrop,
			"outcome switch: no stale Boss picture survives into the defeat result")
	_check(panel.find_children("*", "Button", true, false).size() == 1
		and not panel.return_button.disabled,
		"outcome switch keeps exactly one enabled Return action")
	_check(panel.summary_label.text.begins_with(
		"Battles resolved: %d · Gold: 0 · Scraps: 0%s\n" % [defeat_settled, _floor_clause(defeat_ctx)]),
		"Party defeat shows correct battles resolved count and reached floor")
	_check((defeat_ctx["map"] as RunMap).get_current_floor() == 1
		and panel.summary_label.text.contains("Floor reached: 1/%d" % RunMap.FLOOR_COUNT)
		and not panel.summary_label.text.contains("Floor reached: %d/%d" % [RunMap.FLOOR_COUNT, RunMap.FLOOR_COUNT]),
		"AC2: the opening Fight defeat prints Floor reached: 1/12, never 12/12")
	await _test_missing_backdrop_art(defeat_ctx, defeat_battle, "party defeat",
		_expected_backdrop("Defeat"))
	if old_callback.is_valid():
		old_callback.call()
	_check(returns == 1 and not panel.return_button.disabled,
		"stale previous-generation callback cannot spend reopened result")
	_check(panel.return_button.has_focus(),
		"AC1: the reopened defeat is keyboard-ready without a test grab_focus")
	var key_portrait := panel.hero_rows.get_child(1).get_node("RowInset/HeroPortrait") as TextureRect
	_check(key_portrait.texture != null and not panel.apply_hero_portrait(key_portrait, MISSING_ART),
		"AC3: keyboard Return probe genuinely removes a previously mounted hero portrait")
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
	_check(panel.summary_label.text.contains("Floor reached: 1/%d" % RunMap.FLOOR_COUNT)
		and not panel.summary_label.text.contains("Floor reached: %d/%d" % [RunMap.FLOOR_COUNT, RunMap.FLOOR_COUNT]),
		"AC2: the reopened defeat still states Floor reached: 1/12, never 12/12")
	_check(panel.return_button.has_focus(),
		"AC1: fresh reopened presentation is keyboard-ready without a test grab_focus")
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
	_check(single_lines.size() == 3,
		"AC1: two genuine count lines and one craft line hold the concise counters")
	if single_lines.size() == 3:
		_check(single_lines[0] == "Stitched: 1 made · 1 in deck",
			"AC1: exact made/in-deck count wording is preserved")
		_check(single_lines[1] == "Patches worn: 3", "AC2: exact worn count wording is preserved")
		_check(single_lines[2] == "Crafted: Strike / Prick",
			"AC1: the recap names the authored pair instead of the stitched ID")
	var single_heroes: Array[String] = []
	for hero in single_summary.heroes:
		single_heroes.append(panel._hero_recap_line(hero))
	_check(single_heroes == [
		"Warden 40/40 HP · 0 tears · HEAD Button Eye",
		"Seamstress 30/30 HP · 0 tears · ARM Pincushion Arm",
		"Tinker 26/26 HP · 0 tears · COAT Quilted Coat",
	], "AC1: each hero ribbon names only its worn patch with its own slot")
	_check(single_heroes[1] == "Seamstress 30/30 HP · 0 tears · ARM Pincushion Arm",
		"AC1: pincushion_arm is shown as the readable title-cased Pincushion Arm in its ARM slot")
	var single_all := single_text + "\n" + "\n".join(single_heroes)
	_check(not single_all.contains("stitched_000001"), "AC1: opaque stitched IDs are never shown")
	_check(not single_all.contains("more"), "AC1: a single current stitched card adds no +N more")
	_check(not single_all.contains("pincushion_arm") and not single_all.contains("button_eye")
		and not single_all.contains("quilted_coat"),
		"AC2: raw worn patch IDs are never shown")
	_check(not single_all.contains("HEAD -") and not single_all.contains("ARM -")
		and not single_all.contains("COAT -") and not single_all.contains("Tears:"),
		"AC1: no empty-slot or diagnostic fragments remain in the recap")

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
	_check(zero_lines.size() == 2, "AC3: zero current stitches add no craft line")
	_check(_line_with(zero_lines, "Stitched: ") == "Stitched: 2 made · 0 in deck",
		"AC3: historical and current totals stay distinct when the deck holds none")
	_check(_line_with(zero_lines, "Patches worn: ") == "Patches worn: 1",
		"AC2: the worn total still reflects the genuine wardrobe")
	_check(not zero_text.contains("Crafted:") and not zero_text.contains("Strike")
		and not zero_text.contains("Brace") and not zero_text.contains("stitched_"),
		"AC3: an empty current stitch recap invents no names or IDs")
	_check(panel._hero_recap_line(zero_summary.heroes[2]) == "Tinker 26/26 HP · 0 tears · no patches",
		"AC1: an empty wearer says no patches instead of printing empty slot dashes")
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
	var hero_oracle := _oracle_hero_lines(expected, true)
	_check(hero_oracle.size() == 3 and _hero_rows_text() == PackedStringArray(hero_oracle),
		label + " three mounted hero ribbons match the independent oracle")
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
		panel.stitched_scroll.grab_focus()
		await _frames()
		_check(panel.stitched_scroll.has_focus(),
			label + " retained-card list accepts keyboard focus")
		await _key(KEY_END)
		_check(panel.stitched_scroll.scroll_vertical > 0,
			label + " keyboard End scrolls to the third retained card")
		await _key(KEY_HOME)
		_check(panel.stitched_scroll.scroll_vertical == 0,
			label + " keyboard Home returns to the first retained card")
		panel.stitched_scroll.scroll_vertical = 99999
		await _frames()
		_check(panel.stitched_scroll.scroll_vertical > 0,
			label + " third retained row is accessible by vertical scrolling")
	_check(_app_snapshot() == before and _snapshot(defeat["ctx"], defeat["battle"]) == state,
		label + " open and scroll preserve App, battle, map and seeded RNG")
	panel.close_result()
	_check(not panel.stitched_section.visible and panel.stitched_rows.get_child_count() == 0
		and panel.stitched_scroll.scroll_vertical == 0
		and not panel.hero_recap.visible and panel.hero_rows.get_child_count() == 0,
		label + " close removes all rows, ribbons and resets scrolling")
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
	var signature: Dictionary = RunSignatureSummary.summarize(sewn["deck"],
		sewn["descriptors"], sewn["next_stitch_id"], wardrobe)
	_check(signature.get("ok") == true and signature.get("stitched_current") == 2
		and signature.get("worn_total") == 2,
		"real swapped-seat wardrobe validates both stitched cards and worn receipts")
	var rows: Array = signature.get("heroes", [])
	_check(rows.size() == 3, "swapped-seat signature emits exactly three rows")
	if rows.size() == 3:
		_check(rows[0].hero_id == "seamstress" and rows[0].slots.ARM == "pincushion_arm"
			and rows[1].hero_id == "warden" and rows[1].slots.HEAD == "button_eye"
			and rows[2].hero_id == "tinker",
			"signature keeps actual seat order and by-ID ownership, not legacy projection")
	var kept: Array = signature.get("current_stitched_cards", [])
	_check(kept.size() == 2 and kept[0].display_name == "Strike / Prick"
		and kept[1].display_name == "Brace / Pop Shot",
		"swapped-seat signature retains original deck-ordered stitched descriptors")
	_check(wardrobe.get_snapshot() == before,
		"repeated signature reads never alter the authentic swapped-seat wardrobe")


func _test_invalid_source(defeat: Dictionary) -> void:
	var before := _app_snapshot()
	app.run_next_stitch_id = 0
	_check(panel.open_result(defeat["ctx"]["latch"]),
		"invalid App ledger still shows authentic terminal outcome")
	_check(panel.summary_label.text.ends_with("Summary unavailable")
		and panel.return_button.disabled and not panel.stitched_section.visible
		and panel.stitched_rows.get_child_count() == 0
		and not panel.hero_recap.visible and panel.hero_rows.get_child_count() == 0,
		"invalid ledger never creates card detail, hero ribbons or an enabled Return")
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
		and panel.stitched_rows.get_child_count() == 0
		and not panel.hero_recap.visible and panel.hero_rows.get_child_count() == 0,
		"non-App host cannot authorize sewn detail, hero ribbons or Return")
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


## Wheel-scroll the hovered control with real pointer wheel events.
func _wheel(control: Control, button_index: MouseButton, times: int) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for i in range(times):
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = button_index
		event.pressed = true
		root.push_input(event, true)
	await _frames()


func _font_path(label: Label) -> String:
	var font := label.get_theme_font("font") as Font
	return font.resource_path if font != null else ""


## Text rectangle a label can actually print inside, honouring its paper style.
func _label_interior(label: Label) -> Vector2:
	var box := label.get_theme_stylebox("normal") as StyleBox
	if box == null:
		return label.size
	return Vector2(label.size.x - box.get_margin(SIDE_LEFT) - box.get_margin(SIDE_RIGHT),
		label.size.y - box.get_margin(SIDE_TOP) - box.get_margin(SIDE_BOTTOM))


## Independent TextServer measurement of the label's own text at its resolved
## font and width, so "readable" means the glyphs really fit the control.
func _printed_text_size(label: Label, width: float) -> Vector2:
	return label.get_theme_font("font").get_multiline_string_size(label.text,
		label.horizontal_alignment, width, label.get_theme_font_size("font_size"))


## VIS V2 readability of the mounted run ledger and kept-card details. Every
## genuine body/detail control must resolve to at least 18 px while keeping the
## master body/heading font resources, and the retained list must still scroll
## to its last row with the wheel and the keyboard and leave Return reachable.
func _test_readable_typography(victory: Dictionary, defeat: Dictionary) -> void:
	var theme := load("res://assets/fonts/patchwork_theme.tres") as Theme
	_check(theme != null and theme.default_font != null
		and theme.default_font.resource_path == BODY_FONT
		and (theme.get_font("font", "PatchHeading") as Font).resource_path == HEADING_FONT,
		"AC1: the shipped patchwork theme still owns the same body and heading faces")
	var sewn := _stitch_pairs(_starter_deck(), [
		["warden_strike", "seamstress_prick"],
		["warden_brace", "seamstress_mend"],
		["warden_shield_bash", "tinker_pop_shot"],
	], 9)
	_check(not sewn.is_empty(), "AC2: readable-result fixture commits three genuine stitches")
	if sewn.is_empty():
		return
	var wardrobe := _wardrobe(sewn["deck"], [
		["button_eye", "warden", "HEAD", "readable_sew_warden"],
		["pincushion_arm", "seamstress", "ARM", "readable_sew_seamstress"],
		["quilted_coat", "tinker", "COAT", "readable_sew_tinker"],
	])
	var expected := _signature(sewn, wardrobe)
	var cards: Array = expected.get("current_stitched_cards", [])
	_check(expected.get("ok") == true and cards.size() >= 3,
		"AC2: three retained stitched cards come from the authentic projection")
	_install_run(sewn, wardrobe)
	var before := _app_snapshot()
	_check(panel.open_result(victory["ctx"]["latch"]), "AC1: genuine settled Victory opens for readability")
	await _frames()
	await _audit_result_readability("Victory", expected, victory, before, "AC1/AC2 Boss victory")
	panel.close_result()
	_check(not panel.has_open_result() and panel.stitched_rows.get_child_count() == 0
		and panel.stitched_scroll.scroll_vertical == 0
		and panel.hero_rows.get_child_count() == 0,
		"AC2: closing the readable result clears every retained row, ribbon and scroll offset")
	_check(panel.open_result(defeat["ctx"]["latch"]), "AC1: genuine settled Defeat opens for readability")
	await _frames()
	await _audit_result_readability("Defeat", expected, defeat, before, "AC1/AC2 party defeat")
	panel.close_result()
	_check(_app_snapshot() == before,
		"AC3: readability and list scrolling never alter run, deck, wardrobe or currency")


## Mounted audit of one genuine settled result: font sizes on real controls,
## unclipped signed lines, exact card order/names/owners, and mouse plus keyboard
## access to the last retained row while Return stays reachable.
func _audit_result_readability(status: String, expected: Dictionary,
		terminal: Dictionary, app_before: Dictionary, label: String) -> void:
	var state := _snapshot(terminal["ctx"], terminal["battle"])
	var ctx: Dictionary = terminal["ctx"]
	var settled := (ctx["latch"].get_state().get("settled_node_ids") as Array).size()
	_check(panel.has_open_result() and panel.is_visible_in_tree()
		and panel.get_presented_status() == status.to_upper(), label + ": mounted settled result")
	var title := panel.title_label
	_check(title.theme_type_variation == "PatchHeading" and _font_path(title) == HEADING_FONT
		and title.get_theme_font_size("font_size") >= 40,
		label + ": result title keeps the 40 px PatchHeading hierarchy")
	var ledger := panel.summary_label
	_check(ledger.get_theme_font_size("font_size") >= 18,
		label + ": mounted run ledger resolves to at least 18 px")
	_check(ledger.theme_type_variation == "" and _font_path(ledger) == BODY_FONT,
		label + ": run ledger keeps the inherited body face")
	var sentence := panel.description_label
	_check(sentence.get_theme_font_size("font_size") >= 18 and _font_path(sentence) == BODY_FONT,
		label + ": outcome sentence keeps readable body text")
	var detail := panel.stitched_heading
	_check(detail.theme_type_variation == "PatchHeading" and _font_path(detail) == HEADING_FONT
		and detail.get_theme_font_size("font_size") >= 18,
		label + ": stitched-card heading resolves to at least 18 px on the heading face")
	# Exact authoritative signature, with an independent line oracle.
	var lines := ledger.text.split("\n")
	var expected_lines: Array[String] = [
		"Battles resolved: %d · Gold: %d · Scraps: %d%s" % [settled, expected.gold,
			expected.scraps, _floor_clause(ctx)],
		"Stitched: %d made · %d in deck" % [expected.stitched_created, expected.stitched_current],
		"Patches worn: %d" % expected.worn_total,
	]
	var stitched_ids: Array = expected.stitched_ids
	if not stitched_ids.is_empty():
		var names: Array[String] = []
		for index in range(mini(stitched_ids.size(), 2)):
			names.append(expected.descriptors[stitched_ids[index]].display_name)
		var craft := "Crafted: " + "  ·  ".join(names)
		if stitched_ids.size() > names.size():
			craft += " +%d more" % (stitched_ids.size() - names.size())
		expected_lines.append(craft)
	_check(lines.size() == expected_lines.size(), label + ": exact number of signed counter lines")
	for index in range(mini(lines.size(), expected_lines.size())):
		_check(lines[index] == expected_lines[index],
			label + ": signed counter line %d is unchanged" % index)
	var hero_lines := _oracle_hero_lines(expected, status == "Defeat")
	_check(hero_lines.size() == 3, label + ": hero oracle is non-vacuous")
	_check_hero_rows(hero_lines, label)
	var detail_text := "\n".join(_hero_rows_text())
	_check(not ledger.text.contains("HEAD -") and not ledger.text.contains("ARM -")
		and not ledger.text.contains("COAT -") and not ledger.text.contains("Tears:")
		and not detail_text.contains("HEAD -") and not detail_text.contains("ARM -")
		and not detail_text.contains("COAT -") and not detail_text.contains("Tears:"),
		label + ": mounted recap prints no empty-slot or diagnostic fragments")
	var interior := _label_interior(ledger)
	var printed := _printed_text_size(ledger, interior.x)
	_check(printed.y <= interior.y + 0.5 and printed.x <= interior.x + 0.5,
		label + ": every signed counter line prints unclipped inside its paper")
	for row in panel.hero_rows.get_children():
		var hero_name := row.get_node("RowInset/RowLine/HeroName") as Label
		var hero_detail := row.get_node("RowInset/RowLine/HeroDetail") as Label
		_check(hero_name != null and hero_detail != null
			and _printed_text_size(hero_name, hero_name.size.x).x <= hero_name.size.x + 0.5
			and _printed_text_size(hero_detail, hero_detail.size.x).y <= hero_detail.size.y + 0.5,
			label + ": hero ribbon text prints unclipped beside its name")
	# Kept-card rows: exact order, names, halves and owners, all readable.
	var cards: Array = expected.get("current_stitched_cards", [])
	_check(panel.stitched_section.visible
		and panel.stitched_rows.get_child_count() == cards.size(),
		label + ": every retained card is mounted in its signed order")
	_check(panel.result_content.alignment == BoxContainer.ALIGNMENT_BEGIN
			and panel.run_ledger.size_flags_vertical == Control.SIZE_EXPAND_FILL
			and panel.hero_recap.size_flags_vertical == Control.SIZE_EXPAND_FILL,
			label + ": sewn-card run shares parchment height between tickets and scroll")
	_check(printed.y > 0 and panel.stitched_rows.get_child_count() >= 3,
		label + ": readability oracle is non-vacuous")
	for index in range(mini(cards.size(), panel.stitched_rows.get_child_count())):
		var card: Dictionary = cards[index]
		var first: Dictionary = RunRestStitchCards.resolve_card_definition(card.half_ids[0])
		var second: Dictionary = RunRestStitchCards.resolve_card_definition(card.half_ids[1])
		var row := panel.stitched_rows.get_child(index) as Control
		var composite := row.get_node("CardInset/CardLines/Composite") as Label
		var halves := row.get_node("CardInset/CardLines/Halves") as Label
		_check(composite.get_theme_font_size("font_size") >= 18
			and composite.theme_type_variation == "PatchHeading"
			and _font_path(composite) == HEADING_FONT,
			label + ": composite name resolves to at least 18 px on the heading face")
		_check(halves.get_theme_font_size("font_size") >= 18 and halves.theme_type_variation == ""
			and _font_path(halves) == BODY_FONT,
			label + ": both ordered halves keep the body face at 18 px or more")
		_check(composite.text == "%s  ·  %d energy" % [card.display_name, card.cost],
			label + ": retained composite name and cost are unchanged")
		_check(halves.text == "1 · %s (%s)    →    2 · %s (%s)" % [
			first.display_name, str(first.owner).capitalize(),
			second.display_name, str(second.owner).capitalize()],
			label + ": retained half names and owners are unchanged in order")
		_check(_printed_text_size(composite, composite.size.x).y <= composite.size.y + 0.5
			and _printed_text_size(halves, halves.size.x).y <= halves.size.y + 0.5,
			label + ": composite name and half description print unclipped")
		_check(row.size.y >= row.get_combined_minimum_size().y - 0.5,
			label + ": retained row is allocated its full readable height")
	var scroll := panel.stitched_scroll
	var bar := scroll.get_v_scroll_bar()
	var last_row := panel.stitched_rows.get_child(panel.stitched_rows.get_child_count() - 1) as Control
	var stage := Rect2(Vector2.ZERO, Vector2(root.size))
	_check(bar.max_value > scroll.size.y and scroll.size.y >= 80.0,
		label + ": retained list viewport is shorter than its three rows")
	scroll.scroll_vertical = 0
	await _frames()
	await _wheel(scroll, MOUSE_BUTTON_WHEEL_DOWN, 40)
	_check(scroll.scroll_vertical >= int(bar.max_value - scroll.size.y) - 1,
		label + ": mouse wheel scrolls the retained list to its end")
	_check(scroll.get_global_rect().encloses(last_row.get_global_rect()),
		label + ": the last retained card row is fully visible after wheel scrolling")
	await _wheel(scroll, MOUSE_BUTTON_WHEEL_UP, 40)
	_check(scroll.scroll_vertical == 0, label + ": mouse wheel scrolls back to the first row")
	_check(scroll.focus_mode == Control.FOCUS_ALL, label + ": retained list accepts keyboard focus")
	scroll.grab_focus()
	await _frames()
	_check(scroll.has_focus(), label + ": retained list takes real keyboard focus")
	await _key(KEY_DOWN)
	_check(scroll.scroll_vertical > 0, label + ": Down key scrolls the retained list")
	await _key(KEY_PAGEDOWN)
	_check(scroll.scroll_vertical >= int(bar.max_value - scroll.size.y) - 1,
		label + ": Page Down reaches the end of the retained list")
	await _key(KEY_HOME)
	_check(scroll.scroll_vertical == 0, label + ": Home returns to the first retained row")
	await _key(KEY_END)
	_check(scroll.get_global_rect().encloses(last_row.get_global_rect()),
		label + ": End key brings the last retained row into view")
	scroll.release_focus()
	scroll.scroll_vertical = 0
	await _frames()
	var button := panel.return_button
	_check(button.text == "Return to Title" and not button.disabled
		and button.focus_mode == Control.FOCUS_ALL and button.is_visible_in_tree(),
		label + ": Return to Title stays visible, enabled and focusable")
	_check(panel.paper_panel.get_global_rect().encloses(button.get_global_rect())
		and stage.encloses(button.get_global_rect()),
		label + ": Return to Title is fully inside the paper and the stage")
	var recap_rect := panel.hero_recap.get_global_rect()
	_check(recap_rect.end.y <= ledger.get_global_rect().position.y
		and recap_rect.end.y <= detail.get_global_rect().position.y
		and ledger.get_global_rect().end.x <= panel.stitched_section.get_global_rect().position.x
		and ledger.get_global_rect().end.y <= button.get_global_rect().position.y
		and panel.stitched_section.get_global_rect().end.y <= button.get_global_rect().position.y,
		label + ": counters, hero ribbons, retained list and Return never overlap")
	button.grab_focus()
	await _frames()
	_check(button.has_focus(), label + ": Return action still takes focus after list scrolling")
	button.release_focus()
	_check(_app_snapshot() == app_before and _snapshot(ctx, terminal["battle"]) == state,
		label + ": typography and scrolling change no signed run state or RNG")


## M05 AC1, AC2, AC3: Synchronized wallet (gold/scraps) and hero HP with swap and tear.
func _test_terminal_wallet_and_health(victory: Dictionary, defeat: Dictionary) -> void:
	var starter_defs := _definitions(HEROES)
	var party := CombatParty.new(starter_defs)
	var carry := RunTornCarryover.new(party.get_heroes())
	_check(carry.is_valid(), "AC1/AC2: authentic carryover starts valid")

	# Battle 1 with position swaps and lethal damage on Warden to cause a tear:
	var p1 := carry.create_next_fight_party()
	var e1 := CombatEnemies.new([{"id": "dummy", "max_hp": 8}])
	var r1 := CombatBattleResult.new(p1, e1)
	_check(carry.begin_battle("node_tear", r1, p1), "AC2: battle 1 begins")
	# Swaps: swap Warden (pos 1) and Seamstress (pos 2)
	var s1 := CombatPositionSwaps.preview_adjacent_swap(p1, 1, 1)
	p1._heroes.assign(s1.heroes)
	# Swap Warden (pos 2) and Tinker (pos 3)
	var s2 := CombatPositionSwaps.preview_adjacent_swap(p1, 2, 1)
	p1._heroes.assign(s2.heroes)
	# Swap Seamstress (pos 1) and Tinker (pos 2)
	var s3 := CombatPositionSwaps.preview_adjacent_swap(p1, 1, 1)
	p1._heroes.assign(s3.heroes)
	# Swap Seamstress (pos 2) and Warden (pos 3)
	var s4 := CombatPositionSwaps.preview_adjacent_swap(p1, 2, 1)
	p1._heroes.assign(s4.heroes)
	_check(p1.get_hero(1)["id"] == "tinker" and p1.get_hero(2)["id"] == "warden" and p1.get_hero(3)["id"] == "seamstress",
		"AC2: party swapped to Tinker 1, Warden 2, Seamstress 3")

	# Lethal damage to Warden at position 2:
	_check(p1.apply_damage(2, p1.get_hero(2)["hp"]), "AC2: Warden takes lethal damage in battle 1")
	_check(e1.apply_damage(1, 8), "AC2: slay dummy enemy 1")
	_check(r1.evaluate() == CombatBattleResult.VICTORY, "AC2: battle 1 victory evaluated")
	_check(carry.commit_victory("node_tear", r1, p1).ok, "AC2: battle 1 victory committed")
	_check(carry.apply_reward("node_tear", r1, p1).ok, "AC2: battle 1 reward applied (tear on Warden)")

	# Mend Warden at rest node:
	_check(carry.choose_mend("node_rest", "receipt_mend", "warden", 2, 10, carry.read_state(), null, true).ok,
		"AC2: Warden mended at rest stop")

	# Battle 2: set final HP (Tinker: 12/26, Warden: 18/37, Seamstress: 22/30):
	var p2 := carry.create_next_fight_party()
	var e2 := CombatEnemies.new([{"id": "dummy2", "max_hp": 8}])
	var r2 := CombatBattleResult.new(p2, e2)
	_check(carry.begin_battle("node_fight_2", r2, p2), "AC2: battle 2 begins")
	_check(p2.apply_damage(1, 14), "AC2: Tinker takes damage to 12 HP")
	_check(p2.apply_damage(3, 8), "AC2: Seamstress takes damage to 22 HP")
	p2._heroes[1]["hp"] = 18
	_check(e2.apply_damage(1, 8), "AC2: slay dummy enemy 2")
	_check(r2.evaluate() == CombatBattleResult.VICTORY, "AC2: battle 2 victory evaluated")
	_check(carry.commit_victory("node_fight_2", r2, p2).ok, "AC2: battle 2 victory committed")
	_check(carry.apply_reward("node_fight_2", r2, p2).ok, "AC2: battle 2 reward applied")

	var gold := 43
	var scraps := 2
	var single := _stitch_pairs(_starter_deck(), [["warden_strike", "seamstress_prick"]], 3)
	var heroes_state: Array = carry.read_state().heroes.duplicate(true)
	_check(heroes_state.size() == 3 and heroes_state[0]["id"] == "tinker" and heroes_state[0]["hp"] == 12 and heroes_state[0]["max_hp"] == 26
		and heroes_state[1]["id"] == "warden" and heroes_state[1]["hp"] == 18 and heroes_state[1]["max_hp"] == 37
		and heroes_state[2]["id"] == "seamstress" and heroes_state[2]["hp"] == 22 and heroes_state[2]["max_hp"] == 30,
		"AC2: carryover heroes state matches expected swapped order and reduced Warden max HP")

	var wardrobe := RunPatchWardrobe.new(heroes_state,
		["button_eye", "pincushion_arm", "quilted_coat"],
		PATCH_DEFINITIONS.duplicate(true),
		scraps, gold, single["deck"], 5801, true)
	_check(wardrobe.is_valid(), "AC1/AC2: wardrobe with swapped heroes and tear is valid")
	_check(wardrobe.sew("button_eye", "warden", "HEAD", "sew_warden_custom", wardrobe.get_snapshot()).ok, "sew Button Eye on Warden")
	_check(wardrobe.sew("pincushion_arm", "seamstress", "ARM", "sew_seamstress_custom", wardrobe.get_snapshot()).ok, "sew Pincushion Arm on Seamstress")
	_check(wardrobe.sew("quilted_coat", "tinker", "COAT", "sew_tinker_custom", wardrobe.get_snapshot()).ok, "sew Quilted Coat on Tinker")
	_check(carry.bind_wardrobe(wardrobe, carry.torn, wardrobe.get_snapshot()), "AC1/AC2: carryover binds wardrobe snapshot")

	app.run_heroes = heroes_state.duplicate(true)
	app.party_carryover = carry
	app.session_gold = gold
	app.run_scraps = scraps
	app.run_deck.assign(single["deck"])
	app.run_stitch_descriptors = single["descriptors"].duplicate(true)
	app.run_next_stitch_id = single["next_stitch_id"]
	app.run_trinkets.assign(wardrobe.get_snapshot().owned)

	# AC1 & AC2: Victory check
	var victory_latch: RunActBattleOutcome = victory["ctx"]["latch"]
	var victory_settled: int = (victory_latch.get_state().get("settled_node_ids") as Array).size()
	var snap_before_vic := _app_snapshot()
	_check(panel.open_result(victory_latch), "AC1: opens valid settled Victory with wallet and hero health")
	await _frames()
	_check(panel.has_open_result() and panel.is_visible_in_tree(), "AC1: Victory result is mounted and open")
	var vic_lines := panel.summary_label.text.split("\n")
	_check(vic_lines[0] == "Battles resolved: %d · Gold: 43 · Scraps: 2%s" % [
		victory_settled, _floor_clause(victory["ctx"])],
		"AC1: Victory shows exact nonnegative gold and scraps beside battles resolved")
	_check(vic_lines[1] == "Stitched: 1 made · 1 in deck", "AC3: Victory preserves stitched counts")
	_check(vic_lines[2] == "Patches worn: 3", "AC3: Victory preserves patches worn total")
	_check(vic_lines[3] == "Crafted: Strike / Prick", "AC3: Victory preserves crafted card name")
	_check(vic_lines.size() == 4, "AC1: Victory counters hold exactly the battles, stitched, worn and craft lines")
	_check_hero_rows([
		"Tinker 12/26 HP · 0 tears · COAT Quilted Coat",
		"Warden 18/37 HP · 1 tear · HEAD Button Eye",
		"Seamstress 22/30 HP · 0 tears · ARM Pincushion Arm",
	], "AC2: Victory hero ribbons")
	_check(_hero_row_text(panel.hero_rows.get_child(0)).contains("Tinker 12/26 HP")
		and _hero_row_text(panel.hero_rows.get_child(1)).contains("Warden 18/37 HP")
		and _hero_row_text(panel.hero_rows.get_child(2)).contains("Seamstress 22/30 HP"),
		"AC2: hero ribbons follow authentic swapped seats with identity-bound HP")
	_check(not panel.return_button.disabled and panel.return_button.focus_mode == Control.FOCUS_ALL,
		"AC3: Return button is enabled and focusable")
	panel.close_result()
	_check(not panel.has_open_result(), "panel closes cleanly")
	_check(_app_snapshot() == snap_before_vic, "AC1: Victory open/close leaves wallet, seed, deck and heroes completely unchanged")

	# AC1 & AC2: Defeat check
	var defeat_latch: RunActBattleOutcome = defeat["ctx"]["latch"]
	var defeat_settled: int = (defeat_latch.get_state().get("settled_node_ids") as Array).size()
	var snap_before_def := _app_snapshot()
	_check(panel.open_result(defeat_latch), "AC1: opens valid settled Defeat with wallet and hero health")
	await _frames()
	_check(panel.has_open_result() and panel.is_visible_in_tree(), "AC1: Defeat result is mounted and open")
	var def_lines := panel.summary_label.text.split("\n")
	_check(def_lines[0] == "Battles resolved: %d · Gold: 43 · Scraps: 2%s" % [
		defeat_settled, _floor_clause(defeat["ctx"])],
		"AC1: Defeat shows exact nonnegative gold and scraps beside battles resolved")
	_check(def_lines[1] == "Stitched: 1 made · 1 in deck", "AC3: Defeat preserves stitched counts")
	_check(def_lines[2] == "Patches worn: 3", "AC3: Defeat preserves patches worn total")
	_check(def_lines[3] == "Crafted: Strike / Prick", "AC3: Defeat preserves crafted card name")
	_check(def_lines.size() == 4, "AC1: Defeat counters hold exactly the battles, stitched, worn and craft lines")
	_check_hero_rows([
		"Tinker TORN 0/26 HP · 0 tears · COAT Quilted Coat",
		"Warden TORN 0/37 HP · 1 tear · HEAD Button Eye",
		"Seamstress TORN 0/30 HP · 0 tears · ARM Pincushion Arm",
	], "AC2: Defeat hero ribbons")
	panel.close_result()
	_check(_app_snapshot() == snap_before_def, "AC1: Defeat open/close leaves wallet, seed, deck and heroes completely unchanged")

	# AC3: Negative and Fail-Closed Checks
	var original_gold: int = app.session_gold
	app.session_gold = 999
	_check(panel.open_result(victory_latch), "panel opens outcome even with mismatched wallet")
	_check(panel.summary_label.text.ends_with("Summary unavailable"), "AC3: mismatched gold shows Summary unavailable")
	_check(not panel.summary_label.text.contains("Gold:"), "AC3: no unvalidated gold is displayed")
	_check(not panel.summary_label.text.contains("HP"), "AC3: no unvalidated HP is displayed")
	_check(not panel.hero_recap.visible and panel.hero_rows.get_child_count() == 0,
		"AC3: mismatched wallet mounts no hero ribbons")
	_check(panel.return_button.disabled, "AC3: mismatched wallet disables Return button")
	panel.close_result()
	app.session_gold = original_gold

	var original_scraps: int = app.run_scraps
	app.run_scraps = 999
	_check(panel.open_result(victory_latch), "panel opens outcome even with mismatched scraps")
	_check(panel.summary_label.text.ends_with("Summary unavailable"), "AC3: mismatched scraps shows Summary unavailable")
	_check(not panel.summary_label.text.contains("Scraps:"), "AC3: no unvalidated scraps is displayed")
	_check(not panel.summary_label.text.contains("HP"), "AC3: no unvalidated HP is displayed")
	_check(not panel.hero_recap.visible and panel.hero_rows.get_child_count() == 0,
		"AC3: mismatched scraps mounts no hero ribbons")
	_check(panel.return_button.disabled, "AC3: mismatched scraps disables Return button")
	panel.close_result()
	app.run_scraps = original_scraps

	app.session_gold = -5
	_check(panel.open_result(victory_latch), "panel opens outcome with negative gold")
	_check(panel.summary_label.text.ends_with("Summary unavailable"), "AC3: negative gold rejected")
	_check(not panel.summary_label.text.contains("Gold:"), "AC3: negative gold not displayed")
	_check(not panel.hero_recap.visible and panel.hero_rows.get_child_count() == 0,
		"AC3: negative gold mounts no hero ribbons")
	_check(panel.return_button.disabled, "AC3: negative gold disables Return")
	panel.close_result()
	app.session_gold = original_gold

	app.run_scraps = -1
	_check(panel.open_result(victory_latch), "panel opens outcome with negative scraps")
	_check(panel.summary_label.text.ends_with("Summary unavailable"), "AC3: negative scraps rejected")
	_check(not panel.hero_recap.visible and panel.hero_rows.get_child_count() == 0,
		"AC3: negative scraps mounts no hero ribbons")
	_check(panel.return_button.disabled, "AC3: negative scraps disables Return")
	panel.close_result()
	app.run_scraps = original_scraps

	var original_heroes: Array = app.run_heroes.duplicate(true)
	app.run_heroes[0]["hp"] = 999
	_check(panel.open_result(victory_latch), "panel opens outcome with mismatched hero HP")
	_check(panel.summary_label.text.ends_with("Summary unavailable"), "AC3: mismatched hero HP rejected")
	_check(not panel.summary_label.text.contains("HP"), "AC3: no unvalidated HP displayed")
	_check(not panel.hero_recap.visible and panel.hero_rows.get_child_count() == 0,
		"AC3: mismatched hero HP mounts no hero ribbons")
	_check(panel.return_button.disabled, "AC3: mismatched hero HP disables Return")
	panel.close_result()
	app.run_heroes = original_heroes


## A terminal result whose validated authority fails must show the same
## fail-closed statement, with no enabled Return and no partial hero/tear data,
## and must leave the tampered fixture and every other ledger byte untouched.
func _expect_unavailable(latch: RunActBattleOutcome, label: String) -> void:
	var before := _app_snapshot()
	var torn_before: Dictionary = app.party_carryover.torn.read_state()
	_check(panel.open_result(latch), label + ": the settled outcome still opens")
	_check(panel.summary_label.text.ends_with("Summary unavailable"),
		label + ": fails closed as Summary unavailable")
	_check(not panel.summary_label.text.contains("tear")
		and not panel.summary_label.text.contains("HP")
		and not panel.summary_label.text.contains("TORN")
		and _hero_rows_text().is_empty(),
		label + ": no fabricated hero, tear or torn-badge data is displayed")
	_check(not panel.hero_recap.visible and panel.hero_rows.get_child_count() == 0,
		label + ": no hero ribbon survives or is invented")
	_check(not panel.summary_label.text.contains("Gold:")
		and not panel.summary_label.text.contains("Scraps:"),
		label + ": no partial totals are displayed")
	_check(panel.return_button.disabled and panel.return_button.focus_mode == Control.FOCUS_NONE,
		label + ": Return is disabled and unreachable")
	_check(not panel.stitched_section.visible and panel.stitched_rows.get_child_count() == 0,
		label + ": no stitched detail accompanies the refusal")
	var earlier := returns
	panel.return_button.pressed.emit()
	_check(returns == earlier, label + ": a forced Return signal is refused")
	panel.close_result()
	_check(_app_snapshot() == before and app.party_carryover.torn.read_state() == torn_before,
		label + ": the refusal mutates no hero, deck, purse, wardrobe or torn ledger")


## M05 terminal tear seams. Every hero row must state its genuine by-ID tear
## count from the same validated carryover's torn ledger, TORN must follow only
## that hero's authenticated zero HP, and a legal mend or Rest revive must keep
## the permanent seam count and reduced cap without this view mutating a byte.
func _test_terminal_tears(victory: Dictionary, defeat: Dictionary) -> void:
	var starter := _starter_deck()
	if starter.is_empty():
		return
	var victory_latch: RunActBattleOutcome = victory["ctx"]["latch"]
	var defeat_latch: RunActBattleOutcome = defeat["ctx"]["latch"]
	var victory_battle: Dictionary = victory["battle"]
	var settled: int = (victory_latch.get_state().settled_node_ids as Array).size()

	# A fresh run genuinely carries zero tears, stated per hero instead of hidden.
	_install_run({"deck": starter, "descriptors": {}, "next_stitch_id": 1})
	var zero_app := _app_snapshot()
	var zero_run := _snapshot(defeat["ctx"], defeat["battle"])
	_check(panel.open_result(defeat_latch), "AC1: a settled defeat opens on an untorn run")
	await _frames()
	var zero_rows := panel.summary_label.text.split("\n")
	_check(zero_rows.size() == 3,
		"AC1: an untorn ledger keeps its wallet line plus the two genuine count lines")
	_check_hero_rows([
		"Warden TORN 0/40 HP · 0 tears · no patches",
		"Seamstress TORN 0/30 HP · 0 tears · no patches",
		"Tinker TORN 0/26 HP · 0 tears · no patches",
	], "AC1: fresh run ribbons")
	_check(panel.find_children("TornBadge", "", true, false).size() == 3,
		"AC1: witnessed fallen heroes are TORN although carryover still lives")
	_check(_app_snapshot() == zero_app and _snapshot(defeat["ctx"], defeat["battle"]) == zero_run,
		"AC1: reading zero tears changes no hero, deck, purse, wardrobe or RNG")
	panel.close_result()

	# One genuine tear, published by the carryover's own real reward claim.
	var party := CombatParty.new(_definitions(HEROES))
	var carry := RunTornCarryover.new(party.get_heroes())
	_check(carry.is_valid(), "AC1: the tear fixture carryover is authentic")
	var fight := carry.create_next_fight_party()
	_check(fight != null, "AC1: the run admits a genuine next-fight party")
	if fight == null:
		return
	var enemies := CombatEnemies.new([{"id": "tear_dummy", "max_hp": 8}])
	var result := CombatBattleResult.new(fight, enemies)
	_check(carry.begin_battle("tear_node", result, fight),
		"AC1: a real battle begins before the tear")
	_check(fight.apply_damage(1, fight.get_hero(1)["hp"]) and fight.is_downed(1),
		"AC1: the Warden is genuinely downed in battle")
	_check(enemies.apply_damage(1, 8) and enemies.is_victorious(),
		"AC1: the party survives and the enemy is slain")
	_check(result.evaluate() == CombatBattleResult.VICTORY, "AC1: the tear battle is witnessed")
	_check(carry.commit_victory("tear_node", result, fight).get("ok") == true,
		"AC1: the tear battle victory commits")
	_check(carry.apply_reward("tear_node", result, fight).get("ok") == true,
		"AC1: the reward claim publishes the torn ledger")
	var torn_state: Dictionary = carry.torn.read_state()
	_check(torn_state.get("tear_counts") == {"warden": 1, "seamstress": 0, "tinker": 0},
		"AC1: the torn ledger holds exactly one genuine Warden tear by ID")
	var torn_heroes: Array = carry.read_state().heroes
	_check(torn_heroes[0].id == "warden" and torn_heroes[0].hp == 0 and torn_heroes[0].max_hp == 37,
		"AC1: the tear costs 3 maximum HP and leaves the Warden downed")
	_check(torn_state.get("heroes") == torn_heroes,
		"AC1: the torn ledger publishes the same authenticated carryover heroes")
	var wardrobe := RunPatchWardrobe.new(torn_heroes, ["button_eye", "pincushion_arm", "quilted_coat"],
		PATCH_DEFINITIONS.duplicate(true), 5, 43, starter, 5801, true)
	_check(wardrobe.is_valid(), "AC1: the torn wardrobe validates against the reduced roster")
	_check(wardrobe.sew("button_eye", "seamstress", "HEAD", "tear_sew_seamstress",
		wardrobe.get_snapshot()).get("ok") == true, "AC1: the living Seamstress wears the HEAD patch")
	_check(wardrobe.sew("quilted_coat", "tinker", "COAT", "tear_sew_tinker",
		wardrobe.get_snapshot()).get("ok") == true, "AC1: the living Tinker wears the COAT patch")
	_check(carry.bind_wardrobe(wardrobe, carry.torn, wardrobe.get_snapshot()),
		"AC1: the torn wardrobe binds to this same carryover and torn ledger")
	app.run_heroes = torn_heroes.duplicate(true)
	app.party_carryover = carry
	app.session_gold = 43
	app.run_scraps = 5
	app.run_deck.assign(starter)
	app.run_stitch_descriptors = {}
	app.run_next_stitch_id = 1
	app.run_trinkets.assign(wardrobe.get_snapshot().owned)
	var before := _app_snapshot()
	var run_before := _snapshot(victory["ctx"], victory_battle)
	_check(panel.open_result(victory_latch), "AC1: a settled victory opens on a genuinely torn ledger")
	await _frames()
	var rows := panel.summary_label.text.split("\n")
	_check(rows.size() == 3, "AC1: the torn ledger keeps the preserved wallet and count lines")
	_check(rows[0] == "Battles resolved: %d · Gold: 43 · Scraps: 5%s" % [
		settled, _floor_clause(victory["ctx"])],
		"AC1: the torn ledger keeps the exact wallet line")
	_check_hero_rows([
		"Warden TORN 0/37 HP · 1 tear · no patches",
		"Seamstress 30/30 HP · 0 tears · HEAD Button Eye",
		"Tinker 26/26 HP · 0 tears · COAT Quilted Coat",
	], "AC1: torn run ribbons")
	var row_warden: Control = panel.hero_rows.get_child(0)
	var warden_badge := row_warden.get_node_or_null("RowInset/RowLine/TornBadge") as Label
	_check(warden_badge != null, "AC1: 0-HP Warden row contains TornBadge node")
	if warden_badge != null:
		_check(warden_badge.text == "TORN", "AC1: TornBadge text is exactly TORN")
		_check(warden_badge.theme_type_variation == "PatchHeading", "AC1: TornBadge uses PatchHeading variation")
		var badge_font := warden_badge.get_theme_font("font") as Font
		_check(badge_font != null and badge_font.resource_path == HEADING_FONT,
			"AC1: TornBadge font resolves to LondrinaSolid-Regular display font")
		_check(warden_badge.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and warden_badge.focus_mode == Control.FOCUS_NONE,
			"AC1: TornBadge is decorative and noninteractive")
		var b_style := warden_badge.get_theme_stylebox("normal") as StyleBoxFlat
		_check(b_style != null and b_style.border_width_left >= 1,
			"AC1: TornBadge has sewn border style")
	var warden_torn_labels := row_warden.find_children("*", "Label", true, false).filter(
		func(l: Label): return l.text == "TORN")
	_check(warden_torn_labels.size() == 1, "AC1: exactly one TORN badge in Warden row")
	var warden_detail := row_warden.get_node("RowInset/RowLine/HeroDetail") as Label
	_check(not warden_detail.text.contains("TORN"), "AC1: no duplicate TORN word in HeroDetail")
	_check(warden_detail.text == "0/37 HP · 1 tear · no patches",
		"AC1: authentic HP, tear and patch values preserved in HeroDetail")
	var row_seamstress: Control = panel.hero_rows.get_child(1)
	var row_tinker: Control = panel.hero_rows.get_child(2)
	_check(row_seamstress.get_node_or_null("RowInset/RowLine/TornBadge") == null
		and row_tinker.get_node_or_null("RowInset/RowLine/TornBadge") == null,
		"AC2: living heroes receive no TORN badge")
	_check(not (row_seamstress.get_node("RowInset/RowLine/HeroDetail") as Label).text.contains("TORN")
		and not (row_tinker.get_node("RowInset/RowLine/HeroDetail") as Label).text.contains("TORN"),
		"AC2: living hero details contain no TORN text")
	var projected: Array = carry._projected_heroes()
	var projected_tinker := 0
	for hero in projected:
		if hero is Dictionary and hero.get("id") == "tinker":
			projected_tinker = hero.get("max_hp", 0)
	_check(projected_tinker == 32 and _hero_rows_text()[2].begins_with("Tinker 26/26 HP"),
		"AC1: a worn COAT raises only the effective combat cap, never the ledger tear or maximum")
	_check(_app_snapshot() == before and _snapshot(victory["ctx"], victory_battle) == run_before,
		"AC1: the torn ledger view mutates no hero, deck, purse, wardrobe or RNG")
	panel.close_result()

	# A legal mend removes TORN, never the permanent seam or its cap loss.
	var mend: Dictionary = carry.choose_mend("tear_rest", "tear_mend_receipt", "warden", 1, 5,
		carry.read_state(), wardrobe.get_snapshot(), true)
	_check(mend.get("ok") == true and mend.get("remaining_scraps") == 3,
		"AC2: the legal mend commits and spends exactly 2 of 5 scraps")
	var mended: Array = mend.get("heroes", [])
	_check(mended.size() == 3 and mended[0].id == "warden" and mended[0].hp == 9
		and mended[0].max_hp == 37, "AC2: a mend revives to floor(25% of 37) without restoring the cap")
	_check(carry.torn.read_state().get("tear_counts") == {"warden": 1, "seamstress": 0, "tinker": 0},
		"AC2: mending never erases the historical tear")
	app.run_heroes = mended.duplicate(true)
	app.run_scraps = mend.get("remaining_scraps", 0)
	app.run_trinkets.assign(wardrobe.get_snapshot().owned)
	before = _app_snapshot()
	run_before = _snapshot(victory["ctx"], victory_battle)
	_check(panel.open_result(victory_latch), "AC2: the mended run reopens its settled victory")
	await _frames()
	rows = panel.summary_label.text.split("\n")
	_check_hero_rows([
		"Warden 9/37 HP · 1 tear · no patches",
		"Seamstress 30/30 HP · 0 tears · HEAD Button Eye",
		"Tinker 26/26 HP · 0 tears · COAT Quilted Coat",
	], "AC2: mended run ribbons")
	_check(not "\n".join(_hero_rows_text()).contains("TORN"),
		"AC2: no hero is TORN once the only downed hero has been revived")
	_check(_app_snapshot() == before and _snapshot(victory["ctx"], victory_battle) == run_before,
		"AC2: displaying the mended ledger mutates no state and consumes no RNG")
	panel.close_result()

	# A second genuine tear, then the real Rest revival of that hero.
	var fight_two := carry.create_next_fight_party()
	_check(fight_two != null, "AC2: the torn run admits its second real party")
	if fight_two == null:
		return
	var enemies_two := CombatEnemies.new([{"id": "tear_dummy_two", "max_hp": 8}])
	var result_two := CombatBattleResult.new(fight_two, enemies_two)
	_check(carry.begin_battle("tear_node_two", result_two, fight_two),
		"AC2: a second real battle begins")
	_check(fight_two.apply_damage(2, fight_two.get_hero(2)["hp"]),
		"AC2: the Seamstress is downed for a second genuine tear")
	_check(enemies_two.apply_damage(1, 8) and result_two.evaluate() == CombatBattleResult.VICTORY,
		"AC2: the second battle is won and witnessed")
	_check(carry.commit_victory("tear_node_two", result_two, fight_two).get("ok") == true
		and carry.apply_reward("tear_node_two", result_two, fight_two).get("ok") == true,
		"AC2: the second tear is published by the real reward claim")
	var tears_two: Dictionary = carry.torn.read_state().get("tear_counts", {})
	_check(tears_two == {"warden": 1, "seamstress": 1, "tinker": 0},
		"AC2: tears are counted per hero ID across the run")
	var rested: Dictionary = carry.choose_rest_heal("tear_rest_node")
	_check(rested.get("ok") == true, "AC2: the real Rest revive commits")
	var rested_heroes: Array = rested.get("heroes", [])
	_check(rested_heroes.size() == 3 and rested_heroes[0].hp == 20 and rested_heroes[0].max_hp == 37
		and rested_heroes[1].hp == 9 and rested_heroes[1].max_hp == 27,
		"AC2: Rest revives the downed hero while both reduced caps stay permanent")
	_check(carry.torn.read_state().get("tear_counts") == tears_two,
		"AC2: Rest removes no historical tear")
	app.run_heroes = rested_heroes.duplicate(true)
	app.run_trinkets.assign(wardrobe.get_snapshot().owned)
	before = _app_snapshot()
	run_before = _snapshot(victory["ctx"], victory_battle)
	_check(panel.open_result(victory_latch), "AC2: the Rest-revived run opens its settled victory")
	await _frames()
	rows = panel.summary_label.text.split("\n")
	_check_hero_rows([
		"Warden 20/37 HP · 1 tear · no patches",
		"Seamstress 9/27 HP · 1 tear · HEAD Button Eye",
		"Tinker 26/26 HP · 0 tears · COAT Quilted Coat",
	], "AC2: Rest-revived run ribbons")
	_check(not "\n".join(_hero_rows_text()).contains("TORN"),
		"AC2: a Rest revival clears TORN while the tear count stays")
	_check(_app_snapshot() == before and _snapshot(victory["ctx"], victory_battle) == run_before,
		"AC2: the Rest-revived ledger is shown without any state or RNG mutation")
	panel.close_result()

	# AC3: an inconsistent torn ledger is never presented partially or invented.
	var saved_counts: Dictionary = carry.torn._tear_counts.duplicate(true)
	var saved_heroes: Array = carry.torn._heroes.duplicate(true)
	var saved_valid: bool = carry.torn._valid
	carry.torn._tear_counts["warden"] = -1
	_expect_unavailable(victory_latch, "AC3: negative tear count")
	carry.torn._tear_counts = saved_counts.duplicate(true)

	carry.torn._tear_counts["tinker"] = "0"
	_expect_unavailable(victory_latch, "AC3: non-integer tear count")
	carry.torn._tear_counts = saved_counts.duplicate(true)

	carry.torn._tear_counts.erase("seamstress")
	_expect_unavailable(victory_latch, "AC3: missing tear count")
	carry.torn._tear_counts = saved_counts.duplicate(true)

	carry.torn._heroes[0]["hp"] = 7
	_expect_unavailable(victory_latch, "AC3: torn heroes diverged from the carryover")
	carry.torn._heroes = saved_heroes.duplicate(true)

	carry.torn._valid = false
	_expect_unavailable(victory_latch, "AC3: invalid torn ledger")
	carry.torn._valid = saved_valid

	_check(carry.torn.read_state().get("tear_counts") == saved_counts
		and carry.torn.read_state().get("heroes") == saved_heroes,
		"AC3: the refusals never repaired or rewrote the torn ledger")
	before = _app_snapshot()
	run_before = _snapshot(victory["ctx"], victory_battle)
	_check(panel.open_result(victory_latch), "AC3: the restored torn ledger opens again")
	await _frames()
	_check(_hero_rows_text()[0] == "Warden 20/37 HP · 1 tear · no patches"
		and not panel.return_button.disabled,
		"AC3: only the genuine restored ledger is presented with a usable Return")
	_check(_app_snapshot() == before and _snapshot(victory["ctx"], victory_battle) == run_before,
		"AC3: the positive control also mutates no state")
	panel.close_result()

	# A third genuine tear makes one hero's count plural: the recap must stay
	# exact ("2 tears"), keep TORN only for the downed hero and keep both the
	# worn patch and the honest empty wearer readable beside it.
	var fight_three := carry.create_next_fight_party()
	_check(fight_three != null, "AC2: the revived run admits a third real party")
	if fight_three == null:
		return
	var enemies_three := CombatEnemies.new([{"id": "tear_dummy_three", "max_hp": 8}])
	var result_three := CombatBattleResult.new(fight_three, enemies_three)
	_check(carry.begin_battle("tear_node_three", result_three, fight_three),
		"AC2: a third real battle begins")
	_check(fight_three.apply_damage(1, fight_three.get_hero(1)["hp"]),
		"AC2: the Warden is downed a second time in the run")
	_check(enemies_three.apply_damage(1, 8) and result_three.evaluate() == CombatBattleResult.VICTORY,
		"AC2: the third battle is won and witnessed")
	_check(carry.commit_victory("tear_node_three", result_three, fight_three).get("ok") == true
		and carry.apply_reward("tear_node_three", result_three, fight_three).get("ok") == true,
		"AC2: the second Warden tear is published by the real reward claim")
	_check(carry.torn.read_state().get("tear_counts") == {"warden": 2, "seamstress": 1, "tinker": 0},
		"AC2: the same hero's repeated tears accumulate by ID")
	var thrice: Array = carry.read_state().heroes
	_check(thrice.size() == 3 and thrice[0].id == "warden" and thrice[0].hp == 0
		and thrice[0].max_hp == 34 and thrice[1].id == "seamstress" and thrice[1].hp == 9
		and thrice[1].max_hp == 27, "AC2: two tears cost six maximum HP and leave the Warden TORN")
	app.run_heroes = thrice.duplicate(true)
	app.run_scraps = wardrobe.get_snapshot().scraps
	app.run_trinkets.assign(wardrobe.get_snapshot().owned)
	before = _app_snapshot()
	run_before = _snapshot(victory["ctx"], victory_battle)
	_check(panel.open_result(victory_latch), "AC2: the repeatedly torn run opens its settled victory")
	await _frames()
	rows = panel.summary_label.text.split("\n")
	_check_hero_rows([
		"Warden TORN 0/34 HP · 2 tears · no patches",
		"Seamstress 9/27 HP · 1 tear · HEAD Button Eye",
		"Tinker 26/26 HP · 0 tears · COAT Quilted Coat",
	], "AC2: repeatedly torn run ribbons")
	var row_w2: Control = panel.hero_rows.get_child(0)
	var badge_w2 := row_w2.get_node_or_null("RowInset/RowLine/TornBadge") as Label
	_check(badge_w2 != null and badge_w2.text == "TORN"
		and badge_w2.theme_type_variation == "PatchHeading",
		"AC2: repeatedly torn Warden maintains distinct TORN badge")
	_check(not (row_w2.get_node("RowInset/RowLine/HeroDetail") as Label).text.contains("TORN"),
		"AC2: no duplicate TORN in repeatedly torn Warden detail")
	_check(_app_snapshot() == before and _snapshot(victory["ctx"], victory_battle) == run_before,
		"AC2: presenting plural tear counts mutates no hero, deck, purse, wardrobe or RNG")
	panel.close_result()


## AC1: a wearer keeps every patch they actually wear, each named with its own
## slot, while an empty wearer says "no patches" instead of printing empty slot
## placeholders. Mounted on a genuinely settled defeat so the exact rows and
## their printed fit are proven on the real parchment at the inherited size.
func _test_compact_hero_recap(defeat: Dictionary) -> void:
	var starter := _starter_deck()
	if starter.is_empty():
		return
	var ledger := {"deck": starter, "descriptors": {}, "next_stitch_id": 1}
	var wardrobe := _wardrobe(starter, [
		["stitched_badge", "warden", "HEAD", "compact_head"],
		["spare_spool", "warden", "ARM", "compact_arm"],
		["quilted_coat", "warden", "COAT", "compact_coat"],
		["pincushion_arm", "tinker", "ARM", "compact_tinker"],
	])
	var summary := _signature(ledger, wardrobe)
	var expected: Array[String] = [
		"Stitched: 0 made · 0 in deck",
		"Patches worn: 4",
	]
	var expected_heroes: Array[String] = [
		"Warden 40/40 HP · 0 tears · HEAD Stitched Badge · ARM Spare Spool · COAT Quilted Coat",
		"Seamstress 30/30 HP · 0 tears · no patches",
		"Tinker 26/26 HP · 0 tears · ARM Pincushion Arm",
	]
	_check(summary.get("ok") == true and summary.get("worn_total") == 4,
		"AC1: the compact recap fixture is a genuine four-patch wardrobe")
	var formatted := panel._format_signature(summary).split("\n")
	_check(formatted.size() == expected.size(),
		"AC1: the formatter emits the concise count block only")
	for index in range(mini(formatted.size(), expected.size())):
		_check(formatted[index] == expected[index],
			"AC1: formatted count line %d matches the independent oracle" % index)
	var formatted_heroes: Array[String] = []
	for hero in summary.heroes:
		formatted_heroes.append(panel._hero_recap_line(hero))
	_check(formatted_heroes == expected_heroes,
		"AC1: the pure hero oracle emits the three compact recap rows")
	_install_run(ledger, wardrobe)
	var before := _app_snapshot()
	var state := _snapshot(defeat["ctx"], defeat["battle"])
	_check(panel.open_result(defeat["ctx"]["latch"]), "AC1: the same recap mounts on a settled defeat")
	await _frames()
	var rows := panel.summary_label.text.split("\n")
	_check(rows.size() == expected.size() + 1 and rows[0].begins_with("Battles resolved: "),
		"AC1: one battles line plus the concise count block")
	for index in range(mini(rows.size() - 1, expected.size())):
		_check(rows[index + 1] == expected[index],
			"AC1: mounted count line %d matches the independent oracle" % (index + 1))
	_check_hero_rows(_oracle_hero_lines(summary, true), "AC1: fully worn fallen party ribbons")
	_validate_view("Defeat", "fully worn portrait tickets")
	_check(not panel.stitched_section.visible
			and panel.result_content.alignment == BoxContainer.ALIGNMENT_CENTER
			and panel.run_ledger.size_flags_vertical == Control.SIZE_FILL
			and panel.hero_rows.get_child_count() == CombatParty.PARTY_SIZE
			and panel.hero_rows.get_child(0).size.y >= 200.0,
			"AC3: empty-card defeat groups three sewn seats and ledger, not an expanded blank")
	var recap_text := "\n".join(_hero_rows_text())
	_check(not recap_text.contains("HEAD -")
		and not recap_text.contains("ARM -")
		and not recap_text.contains("COAT -")
		and not recap_text.contains("Tears:"),
		"AC1: a fully worn party prints no empty-slot or diagnostic fragments")
	var interior := _label_interior(panel.summary_label)
	var printed := _printed_text_size(panel.summary_label, interior.x)
	_check(printed.y <= interior.y + 0.5 and printed.x <= interior.x + 0.5,
		"AC1: the concise counters print unclipped inside the existing parchment")
	for row in panel.hero_rows.get_children():
		var detail := row.get_node("RowInset/RowLine/HeroDetail") as Label
		_check(detail != null
			and _printed_text_size(detail, detail.size.x).y <= detail.size.y + 0.5
			and detail.size.y >= detail.get_combined_minimum_size().y - 0.5,
			"AC1: every worn patch ribbon prints unclipped inside the existing parchment")
	_check(panel.summary_label.get_theme_font_size("font_size") >= 18
		and _font_path(panel.summary_label) == BODY_FONT,
		"AC1: the counters keep the inherited body face at 18 px or more")
	_check(panel.hero_recap_title.theme_type_variation == "PatchHeading"
		and _font_path(panel.hero_recap_title) == HEADING_FONT
		and panel.hero_recap_title.get_theme_font_size("font_size") >= 18,
		"AC1: the party recap heading keeps the inherited PatchHeading face")
	# A forged wear map, tear count or HP is never hidden: the whole ledger fails shut.
	var forged_slots: Dictionary = summary.duplicate(true)
	forged_slots["heroes"][0]["slots"]["ARM"] = 7
	_check(panel._format_signature(forged_slots) == LiveRunTerminalResultPanel.UNAVAILABLE,
		"AC1: a malformed wear map fails the whole recap shut rather than hiding a patch")
	var forged_tears: Dictionary = summary.duplicate(true)
	forged_tears["heroes"][1]["tears"] = -1
	_check(panel._format_signature(forged_tears) == LiveRunTerminalResultPanel.UNAVAILABLE,
		"AC1: a negative tear count fails the whole recap shut")
	var forged_hp: Dictionary = summary.duplicate(true)
	forged_hp["heroes"][2]["hp"] = 27
	_check(panel._format_signature(forged_hp) == LiveRunTerminalResultPanel.UNAVAILABLE,
		"AC1: HP above the authenticated maximum fails the whole recap shut")
	_check(panel._validated_hero_rows(forged_slots).is_empty()
		and panel._validated_hero_rows(forged_tears).is_empty()
		and panel._validated_hero_rows(forged_hp).is_empty(),
		"AC1: a forged hero never becomes a mounted ribbon")
	panel.close_result()
	_check(panel.hero_rows.get_child_count() == 0 and not panel.hero_recap.visible,
		"AC1: closing the fully worn recap removes every ribbon")
	_check(_app_snapshot() == before and _snapshot(defeat["ctx"], defeat["battle"]) == state,
		"AC1: the fully worn recap changes no wallet, deck, wardrobe, map or RNG")


## A closed view must never show the previous run's ribbons. Reopening the same
## settled outcome after the run state changed presents only the fresh heroes.
func _test_reopen_resets_recap(defeat: Dictionary) -> void:
	var starter := _starter_deck()
	if starter.is_empty():
		return
	var worn := _wardrobe(starter, [
		["button_eye", "warden", "HEAD", "reopen_sew_warden"],
		["pincushion_arm", "seamstress", "ARM", "reopen_sew_seamstress"],
	])
	_install_run({"deck": starter, "descriptors": {}, "next_stitch_id": 1}, worn)
	var worn_before := _app_snapshot()
	var state := _snapshot(defeat["ctx"], defeat["battle"])
	_check(panel.open_result(defeat["ctx"]["latch"]), "AC3: a worn run opens the settled defeat")
	await _frames()
	_check_hero_rows([
		"Warden TORN 0/40 HP · 0 tears · HEAD Button Eye",
		"Seamstress TORN 0/30 HP · 0 tears · ARM Pincushion Arm",
		"Tinker TORN 0/26 HP · 0 tears · no patches",
	], "AC3: first worn open")
	panel.close_result()
	_check(panel.hero_rows.get_child_count() == 0 and not panel.hero_recap.visible
		and panel.summary_label.text.is_empty(),
		"AC3: close removes every ribbon and clears the counters")
	_check(panel.find_children("TornBadge", "", true, false).is_empty(),
		"AC3: no TornBadge survives close")
	_check(_app_snapshot() == worn_before and _snapshot(defeat["ctx"], defeat["battle"]) == state,
		"AC3: closing the worn recap mutates nothing")
	_install_run({"deck": starter, "descriptors": {}, "next_stitch_id": 1})
	var fresh_before := _app_snapshot()
	_check(panel.open_result(defeat["ctx"]["latch"]),
		"AC3: the same settled defeat reopens on the fresh run")
	await _frames()
	_check_hero_rows([
		"Warden TORN 0/40 HP · 0 tears · no patches",
		"Seamstress TORN 0/30 HP · 0 tears · no patches",
		"Tinker TORN 0/26 HP · 0 tears · no patches",
	], "AC3: reopened fresh run")
	var reopened := "\n".join(_hero_rows_text())
	_check(not reopened.contains("Button Eye") and not reopened.contains("Pincushion Arm")
		and panel.find_children("TornBadge", "", true, false).size() == 3,
		"AC3: fresh patch names and three witnessed torn badges replace closed rows")
	panel.close_result()
	_check(panel.hero_rows.get_child_count() == 0 and _app_snapshot() == fresh_before,
		"AC3: the reopened recap closes without mutation")


## A torn hero keeps the patches they already wear: the ribbon shows the TORN
## marker beside the genuine tear count and still names every occupied slot,
## while living heroes carry no marker.
func _test_torn_wearer_keeps_patches(defeat: Dictionary) -> void:
	var party := CombatParty.new(_definitions(HEROES))
	var carry := RunTornCarryover.new(party.get_heroes())
	_check(carry.is_valid(), "AC1: the torn-wearer fixture carryover is authentic")
	var fight := carry.create_next_fight_party()
	_check(fight != null, "AC1: the torn-wearer run admits a real party")
	if fight == null:
		return
	var enemies := CombatEnemies.new([{"id": "wear_dummy", "max_hp": 8}])
	var result := CombatBattleResult.new(fight, enemies)
	_check(carry.begin_battle("wear_tear", result, fight), "AC1: a real battle begins")
	_check(fight.apply_damage(1, fight.get_hero(1)["hp"]), "AC1: the Warden is genuinely downed")
	_check(enemies.apply_damage(1, 8) and result.evaluate() == CombatBattleResult.VICTORY,
		"AC1: the battle is won and witnessed")
	_check(carry.commit_victory("wear_tear", result, fight).get("ok") == true
		and carry.apply_reward("wear_tear", result, fight).get("ok") == true,
		"AC1: the real reward claim publishes the tear")
	var torn_heroes: Array = carry.read_state().heroes
	_check(torn_heroes[0].id == "warden" and torn_heroes[0].hp == 0 and torn_heroes[0].max_hp == 37,
		"AC1: the genuine tear leaves the Warden downed at 0/37")
	var wardrobe := RunPatchWardrobe.new(torn_heroes,
		["button_eye", "pincushion_arm"], PATCH_DEFINITIONS.duplicate(true),
		2, 10, _starter_deck(), 5801, true)
	_check(wardrobe.is_valid(), "AC1: the torn roster accepts a genuine wardrobe")
	_check(wardrobe.sew("button_eye", "warden", "HEAD", "wear_head",
		wardrobe.get_snapshot()).get("ok") == true,
		"AC1: the torn Warden keeps its sewn HEAD patch recorded")
	_check(carry.bind_wardrobe(wardrobe, carry.torn, wardrobe.get_snapshot()),
		"AC1: the wardrobe binds to the same torn ledger")
	app.run_heroes = torn_heroes.duplicate(true)
	app.party_carryover = carry
	app.session_gold = 10
	app.run_scraps = 2
	app.run_deck.assign(_starter_deck())
	app.run_stitch_descriptors = {}
	app.run_next_stitch_id = 1
	app.run_trinkets.assign(wardrobe.get_snapshot().owned)
	var before := _app_snapshot()
	var state := _snapshot(defeat["ctx"], defeat["battle"])
	_check(panel.open_result(defeat["ctx"]["latch"]), "AC1: the torn wearer result opens")
	await _frames()
	_check_hero_rows([
		"Warden TORN 0/37 HP · 1 tear · HEAD Button Eye",
		"Seamstress 30/30 HP · 0 tears · no patches",
		"Tinker 26/26 HP · 0 tears · no patches",
	], "AC1: torn wearer ribbons")
	var row_tw: Control = panel.hero_rows.get_child(0)
	var badge_tw := row_tw.get_node_or_null("RowInset/RowLine/TornBadge") as Label
	_check(badge_tw != null and badge_tw.text == "TORN"
		and badge_tw.theme_type_variation == "PatchHeading",
		"AC1: torn wearer has sewn TORN badge next to name")
	var detail_tw := row_tw.get_node("RowInset/RowLine/HeroDetail") as Label
	_check(not detail_tw.text.contains("TORN"),
		"AC1: no duplicate TORN in worn patch detail")
	_check(detail_tw.text == "0/37 HP · 1 tear · HEAD Button Eye",
		"AC1: torn wearer keeps HEAD Button Eye visible and unchanged")
	_check(row_tw.find_children("*", "Label", true, false).filter(
		func(l: Label): return l.text == "TORN").size() == 1,
		"AC1: exactly one TORN badge on torn wearer row")
	_check(panel.hero_rows.get_child(1).get_node_or_null("RowInset/RowLine/TornBadge") == null
		and panel.hero_rows.get_child(2).get_node_or_null("RowInset/RowLine/TornBadge") == null,
		"AC1: living heroes receive no badge beside torn wearer")
	_check(not _hero_rows_text()[1].contains("TORN") and not _hero_rows_text()[2].contains("TORN"),
		"AC1: living heroes carry no TORN marker beside the torn wearer")
	_check(_app_snapshot() == before and _snapshot(defeat["ctx"], defeat["battle"]) == state,
		"AC1: presenting a torn wearer mutates no ledger or RNG")
	panel.close_result()
	_check(panel.hero_rows.get_child_count() == 0, "AC1: closing the torn wearer clears its ribbons")


## AC1/AC2/AC3 of the settled-result keyboard handoff: a genuine settled result
## gives its one authorized action real keyboard focus after the deferred UI
## frame, while a refused, closed, hidden, disabled, unauthenticated, superseded
## or spent result never receives focus and never returns. Runs after the older
## suites, whose exact return counts stay independent of this one.
func _test_deferred_keyboard_focus(victory: Dictionary, defeat: Dictionary) -> void:
	var victory_latch: RunActBattleOutcome = victory["ctx"]["latch"]
	var defeat_latch: RunActBattleOutcome = defeat["ctx"]["latch"]
	var victory_state := _snapshot(victory["ctx"], victory["battle"])
	var defeat_state := _snapshot(defeat["ctx"], defeat["battle"])
	var earlier := returns
	_install_run({"deck": _starter_deck(), "descriptors": {}, "next_stitch_id": 1})

	# AC1: an authentic settled floor-12 Boss Victory.
	panel.return_button.release_focus()
	_check(not panel.return_button.has_focus(), "AC1: Return starts genuinely unfocused")
	_check(panel.open_result(victory_latch), "AC1: settled Boss Victory opens for keyboard access")
	_check(not panel.return_button.disabled and not panel.return_button.has_focus(),
		"AC1: the enabled action waits for the deferred UI frame instead of focusing synchronously")
	await _frames()
	_check(panel.return_button.has_focus() and panel.return_button.is_visible_in_tree()
		and not panel.return_button.disabled,
		"AC1: enabled Return acquires real keyboard focus with no test grab_focus")
	await _key(KEY_ENTER)
	_check(returns == earlier + 1 and panel.return_button.disabled,
		"AC1: physical Enter emits exactly one return request and disables the action")
	panel.return_button.pressed.emit()
	await _key(KEY_ENTER)
	_check(returns == earlier + 1, "AC1: the spent victory action cannot replay")
	_check(_snapshot(victory["ctx"], victory["battle"]) == victory_state,
		"AC1: keyboard return mutates no combat, map, latch or RNG state")
	panel.close_result()
	_check(not panel.return_button.has_focus() and panel.return_button.disabled,
		"AC1: close releases the focus it handed over")

	# AC1: the witnessed all-heroes-downed Defeat, now through Space.
	panel.return_button.release_focus()
	_check(panel.open_result(defeat_latch), "AC1: witnessed party Defeat opens for keyboard access")
	await _frames()
	_check(panel.return_button.has_focus(),
		"AC1: the defeat also hands Return real keyboard focus by itself")
	await _key(KEY_SPACE)
	_check(returns == earlier + 2 and panel.return_button.disabled,
		"AC1: physical Space emits exactly one return request and disables the action")
	_check(_snapshot(defeat["ctx"], defeat["battle"]) == defeat_state,
		"AC1: the Space return leaves the witnessed defeat, map and RNG untouched")
	panel.close_result()

	# AC2: a genuine pending ACTIVE latch is refused and never focused.
	var pending_ctx := _context(7711)
	var pending_map: RunMap = pending_ctx["map"]
	var pending_opening := ""
	for choice in pending_map.get_legal_choices():
		if pending_map.get_node(choice).get("type") == "Fight":
			pending_opening = choice
			break
	_check(not pending_opening.is_empty(), "AC2: a genuine opening Fight exists for the pending latch")
	if not pending_opening.is_empty():
		_select(pending_ctx, pending_opening)
		var pending_battle := _battle(FIGHT)
		var pending_latch: RunActBattleOutcome = pending_ctx["latch"]
		_check(pending_latch.begin_current_battle(pending_battle["result"]),
			"AC2: a genuine pending ACTIVE battle begins")
		var pending_before := _snapshot(pending_ctx, pending_battle)
		panel.return_button.release_focus()
		_check(not panel.open_result(pending_latch), "AC2: the pending ACTIVE latch is refused")
		await _frames()
		_check(not panel.return_button.has_focus() and panel.return_button.disabled,
			"AC2: a refused pending latch gets neither focus nor an enabled action")
		panel._take_return_focus.call_deferred(panel._generation)
		await _frames()
		_check(not panel.has_open_result() and not panel.return_button.has_focus()
			and returns == earlier + 2,
			"AC2: a forced deferred handoff cannot reach a refused result")
		panel.return_button.pressed.emit()
		_check(returns == earlier + 2 and _snapshot(pending_ctx, pending_battle) == pending_before,
			"AC2: the refused focus attempt returns nothing and mutates no combat or RNG")

	# AC2: an unavailable run signature keeps the action closed to the keyboard.
	var ledger_before := _app_snapshot()
	app.run_next_stitch_id = 0
	panel.return_button.release_focus()
	_check(panel.open_result(victory_latch), "AC2: an unavailable signature still shows the outcome")
	await _frames()
	_check(panel.return_button.disabled and panel.return_button.focus_mode == Control.FOCUS_NONE
		and not panel.return_button.has_focus(),
		"AC2: an unauthenticated signature never focuses or enables Return")
	panel._take_return_focus.call_deferred(panel._generation)
	await _frames()
	_check(not panel.return_button.has_focus() and returns == earlier + 2,
		"AC2: a forced deferred handoff cannot focus an unauthenticated result")
	panel.close_result()
	app.run_next_stitch_id = ledger_before.cursor
	_check(_app_snapshot() == ledger_before,
		"AC2: the shadowed focus attempt repairs, spends and scatters nothing")

	# AC2: a valid result closed before its queued handoff ever runs.
	panel.return_button.release_focus()
	_check(panel.open_result(defeat_latch), "AC2: a valid result queues its deferred handoff")
	panel.close_result()
	await _frames()
	_check(not panel.return_button.has_focus() and panel.return_button.disabled
		and not panel.has_open_result() and returns == earlier + 2,
		"AC2: a handoff queued before close never focuses or activates the closed action")

	# AC2: hidden panel and disabled action are unreachable for a live handoff.
	panel.return_button.release_focus()
	_check(panel.open_result(defeat_latch), "AC2: a valid defeat opens for the hidden/disabled probes")
	await _frames()
	_check(panel.return_button.has_focus(), "AC2: the hidden/disabled probe starts keyboard-ready")
	panel.hide()
	await _frames()
	_check(not panel.return_button.is_visible_in_tree() and not panel.return_button.has_focus(),
		"AC2: hiding the result makes its action unreachable and releases focus")
	panel._take_return_focus.call_deferred(panel._generation)
	await _frames()
	_check(not panel.return_button.has_focus() and returns == earlier + 2,
		"AC2: a deferred handoff cannot focus a hidden result")
	panel.show()
	await _frames()
	panel.return_button.release_focus()
	panel.return_button.disabled = true
	panel._take_return_focus.call_deferred(panel._generation)
	await _frames()
	_check(not panel.return_button.has_focus() and returns == earlier + 2,
		"AC2: a deferred handoff cannot focus or activate a disabled Return")
	panel.return_button.disabled = false
	panel.close_result()

	# AC3: valid -> close -> reopen on a new generation, then a real keyboard
	# Return, with the retained stitched-card list still independently usable.
	var sewn := _stitch_pairs(_starter_deck(), [
		["warden_strike", "seamstress_prick"],
		["warden_brace", "seamstress_mend"],
		["warden_shield_bash", "tinker_pop_shot"],
	], 9)
	_check(not sewn.is_empty(), "AC3: the generation fixture commits three genuine stitches")
	if sewn.is_empty():
		return
	var wardrobe := _wardrobe(sewn["deck"], [
		["button_eye", "warden", "HEAD", "focus_sew_warden"],
		["pincushion_arm", "seamstress", "ARM", "focus_sew_seamstress"],
		["quilted_coat", "tinker", "COAT", "focus_sew_tinker"],
	])
	_install_run(sewn, wardrobe)
	var app_before := _app_snapshot()
	var run_before := _snapshot(defeat["ctx"], defeat["battle"])
	panel.return_button.release_focus()
	_check(panel.open_result(defeat_latch), "AC3: a stitched valid defeat opens with a queued handoff")
	await _frames()
	_check(panel.stitched_rows.get_child_count() == 3 and panel.return_button.has_focus(),
		"AC3: the stitched result is retained and keyboard-ready")
	var stale_generation := panel._generation
	panel.close_result()
	_check(not panel.return_button.has_focus() and panel.stitched_rows.get_child_count() == 0,
		"AC3: close invalidates the handoff and removes the retained rows")
	_check(panel.open_result(victory_latch),
		"AC3: a different settled result reopens on a new generation")
	await _frames()
	_check(panel._generation != stale_generation and panel.return_button.has_focus(),
		"AC3: the reopened result is keyboard-ready on its own generation")
	var scroll := panel.stitched_scroll
	_check(panel.stitched_rows.get_child_count() == 3 and scroll.is_visible_in_tree()
		and scroll.focus_mode == Control.FOCUS_ALL,
		"AC3: the retained stitched-card list stays independently focusable")
	scroll.scroll_vertical = 0
	await _frames()
	scroll.grab_focus()
	await _frames()
	_check(scroll.has_focus() and not panel.return_button.has_focus(),
		"AC3: the retained list takes real keyboard focus away from Return")
	await _key(KEY_DOWN)
	_check(scroll.scroll_vertical > 0, "AC3: Down key still scrolls the retained list")
	await _key(KEY_END)
	_check(scroll.scroll_vertical >= int(scroll.get_v_scroll_bar().max_value - scroll.size.y) - 1,
		"AC3: End key still reaches the last retained row")
	panel._take_return_focus.call_deferred(stale_generation)
	await _frames()
	_check(scroll.has_focus() and not panel.return_button.has_focus() and returns == earlier + 2,
		"AC3: the earlier generation can neither steal focus nor request a return")
	scroll.release_focus()
	panel.close_result()
	await _frames()
	_check(panel.open_result(defeat_latch),
		"AC3: the valid result reopens once more on a newer generation")
	await _frames()
	_check(panel.return_button.has_focus() and panel._generation != stale_generation,
		"AC3: the reopened valid result becomes keyboard-ready with no test grab_focus")
	await _key(KEY_ENTER)
	_check(returns == earlier + 3 and panel.return_button.disabled,
		"AC3: the reopened result returns exactly once by physical Enter")
	panel.return_button.pressed.emit()
	await _key(KEY_ENTER)
	_check(returns == earlier + 3, "AC3: forced replay after the real return is refused")
	_check(_snapshot(defeat["ctx"], defeat["battle"]) == run_before and _app_snapshot() == app_before,
		"AC3: focus, scrolling, stale handoff and return leave every ledger untouched")
	panel.close_result()
	_check(not panel.has_open_result() and not panel.return_button.has_focus(),
		"AC3: the final close leaves no retained focus or open result")


## The first-choice route through the real generated 12-floor graph, read without
## selecting anything, so a fixture can inspect a path before committing to it.
func _greedy_path(map: RunMap) -> Array[String]:
	var path: Array[String] = []
	var choices := map.get_legal_choices()
	if choices.is_empty():
		return path
	var node_id: String = choices[0]
	while not node_id.is_empty():
		path.append(node_id)
		var outgoing: Array = map.get_node(node_id).get("outgoing", [])
		node_id = "" if outgoing.is_empty() else str(outgoing[0])
	return path


## AC3: an unproven map relationship never invents a depth. A genuinely settled
## defeat whose route has moved on, or whose graph was regenerated, must refuse
## the recap and Return without claiming "N/12" or stale carryover HP.
func _test_unverified_floor() -> void:
	var ctx := _context(3141)
	var map: RunMap = ctx["map"]
	var opening := ""
	for choice in map.get_legal_choices():
		if map.get_node(choice).get("type") == "Fight":
			opening = choice
			break
	_check(not opening.is_empty(), "AC3: a genuine opening Fight exists for the stale-map probe")
	if opening.is_empty():
		return
	_select(ctx, opening)
	var battle := _battle(FIGHT)
	var latch: RunActBattleOutcome = ctx["latch"]
	_check(latch.begin_current_battle(battle["result"]),
		"AC3: the stale-map probe begins a real opening Fight")
	var party: CombatParty = battle["party"]
	for slot in range(1, 4):
		_check(party.apply_damage(slot, party.get_hero(slot)["hp"]),
			"AC3: the real party is downed at slot %d" % slot)
	_check(battle["result"].evaluate() == CombatBattleResult.DEFEAT,
		"AC3: the opening Fight is genuinely lost")
	_check(_settle_defeat(ctx, battle),
		"AC3: the witnessed defeat settles for the stale-map probe")
	_check(map.get_current_floor() == 1 and map.get_current_node_id() == opening,
		"AC3: the fresh settled defeat stands on floor 1")
	_check(panel._verified_floor_reached(latch, latch.get_state()) == 1,
		"AC3: the authentic floor-1 defeat verifies its own depth")

	# The formatter itself refuses every state that cannot prove a depth, without
	# mutating the latch or the map it still reads.
	var settled_state: Dictionary = latch.get_state()
	_check(panel._verified_floor_reached(null, settled_state) == -1,
		"AC3: no settled latch means no claimed depth")
	_check(panel._verified_floor_reached(latch, {"run_status": RunActBattleOutcome.ACTIVE,
		"pending_node_id": "", "settled_node_ids": [opening]}) == -1,
		"AC3: an ACTIVE run never claims a terminal depth")
	_check(panel._verified_floor_reached(latch, {"run_status": RunActBattleOutcome.DEFEAT,
		"pending_node_id": opening, "settled_node_ids": [opening]}) == -1,
		"AC3: a pending battle never claims a depth")
	_check(panel._verified_floor_reached(latch, {"run_status": RunActBattleOutcome.DEFEAT,
		"pending_node_id": "", "settled_node_ids": []}) == -1,
		"AC3: no witnessed battle never claims a depth")
	_check(panel._verified_floor_reached(latch, {"run_status": RunActBattleOutcome.VICTORY,
		"pending_node_id": "", "settled_node_ids": [opening]}) == -1,
		"AC3: a victory over a floor-1 Fight is not a floor-12 Boss victory")
	_check(map.get_current_node_id() == opening and map.get_route() == [opening]
		and map.get_current_floor() == 1,
		"AC3: those formatter refusals read the map without moving it")

	_install_run({"deck": _starter_deck(), "descriptors": {}, "next_stitch_id": 1})
	var app_before := _app_snapshot()
	var state_before := _snapshot(ctx, battle)
	var earlier := returns
	_check(panel.open_result(latch), "AC3: the verified floor-1 defeat opens")
	await _frames()
	_check(panel.summary_label.text.contains("Floor reached: 1/%d" % RunMap.FLOOR_COUNT)
		and panel.return_button.has_focus(),
		"AC3: the verified defeat states its floor and stays keyboard-ready")
	_check(_snapshot(ctx, battle) == state_before and _app_snapshot() == app_before,
		"AC3: the verified depth readout mutates no map, actor, latch or RNG")
	panel.close_result()

	# A stale route: the settled battle is no longer the node the map stands on.
	_check(not map.get_legal_choices().is_empty(),
		"AC3: the settled node offers a legal onward choice")
	_select(ctx, map.get_legal_choices()[0])
	var stale_state := _snapshot(ctx, battle)
	_check(not panel.summary_label.text.contains("Floor reached"),
		"AC3: closing the verified result clears its floor claim")
	_check(panel.open_result(latch), "AC3: the stale-map result still opens")
	await _frames()
	_check(panel.summary_label.text.ends_with("Summary unavailable"),
		"AC2: an untrusted map cannot publish the terminal ledger")
	_check(not panel.summary_label.text.contains("Floor reached"),
		"AC3: a route that moved past the witnessed battle claims no depth")
	_check(panel.return_button.disabled
		and panel.hero_rows.get_child_count() == 0,
		"AC3: stale-map defeat fails closed without recap or Return")
	_check(_snapshot(ctx, battle) == stale_state and _app_snapshot() == app_before,
		"AC3: presenting an unverified depth moves no map node, actor, latch or RNG")
	await _key(KEY_ENTER)
	_check(returns == earlier and panel.return_button.disabled,
		"AC3: the unverified result refuses keyboard replay")
	_check(_snapshot(ctx, battle) == stale_state,
		"AC3: that Return leaves the stale map and the latch untouched")
	panel.close_result()

	# A regenerated graph: identical-looking IDs, but a new empty route.
	_check(map.generate(ctx["rng"]), "AC3: a genuine new generation replaces the route")
	_check(map.get_current_node_id() == "" and map.get_current_floor() == 0,
		"AC3: the regenerated map stands on no floor at all")
	var regenerated := _snapshot(ctx, battle)
	var app_after := _app_snapshot()
	_check(panel.open_result(latch), "AC3: the closed-map result still opens")
	await _frames()
	_check(panel.summary_label.text.ends_with("Summary unavailable"),
		"AC2: an untrusted map cannot publish the terminal ledger")
	_check(not panel.summary_label.text.contains("Floor reached"),
		"AC3: a fresh empty route can never claim the old run's depth")
	_check(panel.return_button.disabled and panel.hero_rows.get_child_count() == 0,
		"AC3: regenerated-map defeat fails closed")
	_check(_snapshot(ctx, battle) == regenerated and _app_snapshot() == app_after,
		"AC3: the regenerated-map refusal mutates no run state or RNG")
	panel.close_result()
	_check(panel.summary_label.text.is_empty() and not panel.has_open_result(),
		"AC3: closing the unverified result leaves no depth or counters behind")


## A genuine mid-run defeat after at least one noncombat stop: the party reached
## a deeper floor than the number of battles it settled, so the readout can only
## come from the map's real floor.
func _test_depth_beyond_battle_count() -> void:
	var ctx: Dictionary = {}
	var path: Array[String] = []
	var target := 0
	for seed_value in range(6100, 6200):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var candidate := RunMap.new()
		if not candidate.generate(rng):
			continue
		var candidate_path := _greedy_path(candidate)
		if candidate_path.size() != RunMap.FLOOR_COUNT:
			continue
		var noncombat_seen := false
		var candidate_target := 0
		for index in range(candidate_path.size()):
			var kind: String = candidate.get_node(candidate_path[index]).get("type")
			if index >= 2 and noncombat_seen and kind in ["Fight", "Elite"]:
				candidate_target = index
				break
			if kind not in ["Fight", "Elite", "Boss"]:
				noncombat_seen = true
		if candidate_target == 0:
			continue
		ctx = {"rng": rng, "map": candidate, "latch": RunActBattleOutcome.new(candidate)}
		path = candidate_path
		target = candidate_target
		break
	_check(not ctx.is_empty() and target >= 2,
		"AC1: a real route reaches a battle after an earlier noncombat stop")
	if ctx.is_empty() or target < 2:
		return
	var map: RunMap = ctx["map"]
	var latch: RunActBattleOutcome = ctx["latch"]
	var settled_battles := 0
	for index in range(target):
		_select(ctx, path[index])
		var kind: String = map.get_node(path[index]).get("type")
		if kind in ["Fight", "Elite"]:
			_settle_win(ctx, _battle(FIGHT), "depth stop floor %d" % (index + 1))
			settled_battles += 1
	_select(ctx, path[target])
	var losing := _battle(FIGHT)
	_check(latch.begin_current_battle(losing["result"]),
		"AC1: the deeper defeat begins a real battle")
	var party: CombatParty = losing["party"]
	for slot in range(1, 4):
		_check(party.apply_damage(slot, party.get_hero(slot)["hp"]),
			"AC1: the deeper party is downed at slot %d" % slot)
	_check(losing["result"].evaluate() == CombatBattleResult.DEFEAT,
		"AC1: the deeper battle is genuinely lost")
	_check(_settle_defeat(ctx, losing), "AC1: the deeper defeat settles")
	settled_battles += 1
	var reached: int = map.get_current_floor()
	_check(reached == target + 1 and reached > settled_battles,
		"AC1: the reached floor is genuinely deeper than the settled battle count")
	_install_run({"deck": _starter_deck(), "descriptors": {}, "next_stitch_id": 1})
	var app_before := _app_snapshot()
	var state_before := _snapshot(ctx, losing)
	_check(panel.open_result(latch), "AC1: the deeper witnessed defeat opens")
	await _frames()
	_check(panel.summary_label.text.split("\n")[0] == "Battles resolved: %d · Gold: 0 · Scraps: 0%s" % [
		settled_battles, _floor_clause(ctx)],
		"AC1: the deeper defeat prints the real reached floor beside the battle count")
	_check(panel.summary_label.text.contains("Floor reached: %d/%d" % [reached, RunMap.FLOOR_COUNT])
		and not panel.summary_label.text.contains("Floor reached: %d/%d" % [settled_battles, RunMap.FLOOR_COUNT]),
		"AC1: the depth is the map floor, never the number of settled battles")
	_check(_snapshot(ctx, losing) == state_before and _app_snapshot() == app_before,
		"AC1: the deeper readout mutates no map, actor, latch or RNG")
	panel.close_result()


## AC1, AC2, AC3: Sewn TORN badge on recap ribbons for downed heroes.
## Distinguishes genuinely downed heroes with a compact sewn TORN badge next to the
## hero name, preserves three-hero identity order Warden/Seamstress/Tinker, ensures
## living heroes receive no badge and no duplicate TORN in HeroDetail, and verifies
## close/reopen and invalid-result fail-closed safety.
func _test_sewn_torn_badges(victory: Dictionary, defeat: Dictionary) -> void:
	var starter := _starter_deck()
	if starter.is_empty():
		return

	# Mixed party: Seamstress is genuinely downed in battle (0 HP), Warden & Tinker survive.
	var party := CombatParty.new(_definitions(HEROES))
	var carry := RunTornCarryover.new(party.get_heroes())
	_check(carry.is_valid(), "AC1/AC2: authentic carryover for mixed party")
	var fight := carry.create_next_fight_party()
	_check(fight != null, "AC1/AC2: mixed party admits battle")
	if fight == null:
		return
	var enemies := CombatEnemies.new([{"id": "dummy_mixed", "max_hp": 8}])
	var result := CombatBattleResult.new(fight, enemies)
	_check(carry.begin_battle("mixed_node", result, fight), "AC1/AC2: mixed battle begins")
	_check(fight.apply_damage(2, fight.get_hero(2)["hp"]) and fight.is_downed(2),
		"AC1/AC2: Seamstress takes lethal damage and is downed")
	_check(enemies.apply_damage(1, 8) and enemies.is_victorious(),
		"AC1/AC2: enemies defeated with surviving Warden and Tinker")
	_check(result.evaluate() == CombatBattleResult.VICTORY, "AC1/AC2: mixed battle evaluated VICTORY")
	_check(carry.commit_victory("mixed_node", result, fight).get("ok") == true,
		"AC1/AC2: mixed battle committed")
	_check(carry.apply_reward("mixed_node", result, fight).get("ok") == true,
		"AC1/AC2: mixed reward applied")
	var mixed_heroes: Array = carry.read_state().heroes
	_check(mixed_heroes.size() == 3
		and mixed_heroes[0].id == "warden" and mixed_heroes[0].hp == 40
		and mixed_heroes[1].id == "seamstress" and mixed_heroes[1].hp == 0 and mixed_heroes[1].max_hp == 27
		and mixed_heroes[2].id == "tinker" and mixed_heroes[2].hp == 26,
		"AC1/AC2: mixed carryover heroes state matches expected HP and Seamstress down")
	var wardrobe := RunPatchWardrobe.new(mixed_heroes,
		["button_eye", "pincushion_arm", "quilted_coat"],
		PATCH_DEFINITIONS.duplicate(true),
		4, 50, starter, 5801, true)
	_check(wardrobe.is_valid(), "AC1/AC2: wardrobe for mixed party validates")
	_check(wardrobe.sew("pincushion_arm", "seamstress", "ARM", "sew_seamstress_mixed",
		wardrobe.get_snapshot()).get("ok") == true, "AC1: sew on downed Seamstress")
	_check(wardrobe.sew("quilted_coat", "tinker", "COAT", "sew_tinker_mixed",
		wardrobe.get_snapshot()).get("ok") == true, "AC1: sew on living Tinker")
	_check(carry.bind_wardrobe(wardrobe, carry.torn, wardrobe.get_snapshot()),
		"AC1/AC2: bind wardrobe to carryover")

	app.run_heroes = mixed_heroes.duplicate(true)
	app.party_carryover = carry
	app.session_gold = 50
	app.run_scraps = 4
	app.run_deck.assign(starter)
	app.run_stitch_descriptors = {}
	app.run_next_stitch_id = 1
	app.run_trinkets.assign(wardrobe.get_snapshot().owned)

	var before := _app_snapshot()
	var state := _snapshot(victory["ctx"], victory["battle"])
	_check(panel.open_result(victory["ctx"]["latch"]), "AC1/AC2: opens mixed party Victory result")
	await _frames()
	_check(panel.has_open_result() and panel.is_visible_in_tree(), "AC1/AC2: panel is open and visible")

	var expected_mixed: Array[String] = [
		"Warden 40/40 HP · 0 tears · no patches",
		"Seamstress TORN 0/27 HP · 1 tear · ARM Pincushion Arm",
		"Tinker 26/26 HP · 0 tears · COAT Quilted Coat",
	]
	_check_hero_rows(expected_mixed, "AC2: mixed party ribbons match independent oracle")

	var seamstress_row: Control = panel.hero_rows.get_child(1)
	var badge := seamstress_row.get_node_or_null("RowInset/RowLine/TornBadge") as Label
	_check(badge != null, "AC1: downed Seamstress row contains TornBadge node")
	if badge != null:
		_check(badge.text == "TORN", "AC1: TornBadge text is exactly TORN")
		_check(badge.theme_type_variation == "PatchHeading", "AC1: TornBadge uses PatchHeading variation")
		var b_font := badge.get_theme_font("font") as Font
		_check(b_font != null and b_font.resource_path == HEADING_FONT,
			"AC1: TornBadge font resolves to LondrinaSolid-Regular display font")
		_check(badge.mouse_filter == Control.MOUSE_FILTER_IGNORE and badge.focus_mode == Control.FOCUS_NONE,
			"AC1: TornBadge ignores mouse and keyboard focus")
		var b_style := badge.get_theme_stylebox("normal") as StyleBoxFlat
		_check(b_style != null and b_style.border_width_left >= 1, "AC1: TornBadge has sewn border style")
		_check(b_style.border_color.get_luminance() < 0.6, "AC1: TornBadge border uses dark border color")
	var s_torn_labels := seamstress_row.find_children("*", "Label", true, false).filter(
		func(l: Label): return l.text == "TORN")
	_check(s_torn_labels.size() == 1, "AC1: exactly one TORN badge in Seamstress row")
	var s_detail := seamstress_row.get_node("RowInset/RowLine/HeroDetail") as Label
	_check(not s_detail.text.contains("TORN"), "AC1: no duplicate TORN in HeroDetail")
	_check(s_detail.text == "0/27 HP · 1 tear · ARM Pincushion Arm",
		"AC1: authentic HP, tears, and worn patch preserved in HeroDetail")

	var warden_row: Control = panel.hero_rows.get_child(0)
	var tinker_row: Control = panel.hero_rows.get_child(2)
	_check(warden_row.get_node_or_null("RowInset/RowLine/TornBadge") == null,
		"AC2: living Warden row has no TornBadge")
	_check(tinker_row.get_node_or_null("RowInset/RowLine/TornBadge") == null,
		"AC2: living Tinker row has no TornBadge")
	_check(not (warden_row.get_node("RowInset/RowLine/HeroDetail") as Label).text.contains("TORN"),
		"AC2: living Warden detail has no TORN")
	_check(not (tinker_row.get_node("RowInset/RowLine/HeroDetail") as Label).text.contains("TORN"),
		"AC2: living Tinker detail has no TORN")

	panel.close_result()
	_check(not panel.has_open_result() and panel.hero_rows.get_child_count() == 0,
		"AC3: close clears result and removes all hero rows")
	_check(panel.find_children("TornBadge", "", true, false).is_empty(),
		"AC3: no TornBadge survives close")
	_check(_app_snapshot() == before and _snapshot(victory["ctx"], victory["battle"]) == state,
		"AC3: presentation and close leave app and run ledgers unchanged")

	_install_run({"deck": starter, "descriptors": {}, "next_stitch_id": 1})
	_check(panel.open_result(victory["ctx"]["latch"]), "AC3: reopen with fresh untorn run")
	await _frames()
	_check(panel.find_children("TornBadge", "", true, false).is_empty(),
		"AC3: reopened living run contains zero TornBadges")
	panel.close_result()


func _test_live_lethal_fight() -> Dictionary:
	var live: Variant = load(APP_SCENE).instantiate()
	root.add_child(live)
	live.run_seed = 8722
	live.start_button.pressed.emit()
	preload("res://tests/party_choice.gd").choose(live)
	await _frames()
	_check(live.run_map != null and live.run_rng != null, "AC1: live Start admits party and seeded map")
	if live.run_map == null:
		live.queue_free()
		return {}
	var chosen := ""
	for id in live.run_map.get_legal_choices():
		if live.run_map.get_node(id).get("type") == "Fight":
			chosen = id
			break
	_check(not chosen.is_empty() and live._choose_route(chosen), "AC1: live legal Fight route mounts combat")
	if live.party == null:
		live.queue_free()
		return {}
	var carried: Array = live.run_heroes.duplicate(true)
	_check(carried.size() == 3 and carried.all(func(h): return h.hp > 0),
		"AC1: carryover genuinely starts with three living heroes")
	for turn in range(100):
		if live._battle_closed:
			break
		live.end_turn_button.pressed.emit()
		await _frames()
	_check(live.party.is_defeated() and live.battle_result.get_outcome() == CombatBattleResult.DEFEAT,
		"AC1: actual enemy phases down the full live party")
	var recap: LiveRunTerminalResultPanel = live.terminal_result_panel
	var replay: Dictionary = {}
	_check(is_instance_valid(recap) and recap.is_visible_in_tree(), "AC1: settled live Defeat auto-mounts recap")
	if is_instance_valid(recap):
		_check(recap.hero_rows.get_child_count() == 3, "AC1: live recap has three tickets")
		for index in range(recap.hero_rows.get_child_count()):
			var row: Control = recap.hero_rows.get_child(index)
			var ledger: Dictionary = carried[index]
			var text := _hero_row_text(row)
			_check(text == "%s TORN 0/%d HP · 0 tears · no patches" % [ledger.id.capitalize(), ledger.max_hp]
				and row.get_node_or_null("RowInset/RowLine/TornBadge") != null,
				"AC1: exact live witnessed HP, cap and TORN ticket " + ledger.id)
		replay = {"heroes": live.party.get_heroes(), "rng": live.run_rng.state,
			"summary": recap.summary_label.text, "state": live.act_outcome.get_state()}
		_check(live.run_heroes == carried and live.party_carryover.read_state().heroes == carried,
			"AC1: display leaves uncommitted living carryover unchanged")
		recap.return_button.pressed.emit()
		await _frames()
		_check(live.title_view.is_visible_in_tree() and live.run_map == null
			and live.party == null and live._terminal_combat_witness.is_empty(),
			"AC3: actual terminal Return clears run and combat witness")
	live.queue_free()
	await _frames()
	return replay


func _test_defeat_witness_rejections(defeat: Dictionary) -> void:
	var latch: RunActBattleOutcome = defeat.ctx.latch
	var witness: Array = app._terminal_combat_witness.duplicate(true)
	var actual_party: CombatParty = app.party
	var actual_result: CombatBattleResult = app.battle_result
	var actual_map: RunMap = app.run_map
	var before := _snapshot(defeat.ctx, defeat.battle)
	for kind in ["missing", "latch", "party", "battle", "map", "identity", "hp", "block", "position", "snapshot", "revision"]:
		app._terminal_combat_witness = witness.duplicate(true)
		match kind:
			"missing": app._terminal_combat_witness = []
			"latch": app.act_outcome = RunActBattleOutcome.new(actual_map)
			"party": app.party = CombatParty.new(_definitions(HEROES))
			"battle": app.battle_result = CombatBattleResult.new(actual_party, defeat.battle.enemies)
			"map": app.run_map = RunMap.new()
			"identity": actual_party._heroes[0]["id"] = "forged_hero"
			"hp": actual_party._heroes[0]["hp"] = -1
			"block": actual_party._heroes[0]["block"] = -1
			"position": actual_party._heroes[0]["position"] = 2
			"snapshot": actual_party._heroes[0]["block"] += 1
			"revision": app._terminal_combat_witness[4] += 1
		# Also tamper with the copy: matching malformed actors are still invalid.
		if kind in ["identity", "hp", "block", "position"]:
			app._terminal_combat_witness[7] = actual_party.get_heroes()
		_expect_unavailable(latch, "AC2: rejects " + kind + " combat witness")
		actual_party._heroes.assign(witness[7].duplicate(true))
		app.act_outcome = latch
		app.run_map = actual_map
		app.party = actual_party
		app.battle_result = actual_result
	app._terminal_combat_witness = witness.duplicate(true)
	_check(_snapshot(defeat.ctx, defeat.battle) == before, "AC2: refusals preserve combat, latch, map and RNG")
	_check(panel.open_result(latch) and not panel.return_button.disabled
		and panel.hero_rows.get_child_count() == 3, "AC2: restored genuine witness reopens after rejection")
	panel.close_result()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var replay := await _test_live_lethal_fight()
	var repeated := await _test_live_lethal_fight()
	_check(not replay.is_empty() and repeated == replay, "AC1/AC2: real lethal Fight and terminal recap replay exactly, including RNG")
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
		_test_defeat_witness_rejections(defeat)
		await _test_terminal_interactions(victory, defeat)
		await _test_crafted_recap(defeat)
		await _test_compact_hero_recap(defeat)
		await _test_torn_wearer_keeps_patches(victory)
		await _test_reopen_resets_recap(defeat)
		_test_reordered_heroes()
		_test_global_rng(defeat)
		_test_invalid_source(defeat)
		await _test_readable_typography(victory, defeat)
		await _test_terminal_wallet_and_health(victory, defeat)
		await _test_terminal_tears(victory, defeat)
		await _test_sewn_torn_badges(victory, defeat)
		await _test_deferred_keyboard_focus(victory, defeat)
		await _test_depth_beyond_battle_count()
		await _test_unverified_floor()
		await _test_v3_chosen_mounted_results()
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

## Two real admitted V3 trios, with genuine stitched halves, sewn patches and
## witnessed terminal outcomes. The source ledgers (not panel-derived fields)
## are the oracle. Includes an all-new-hero trio and a legacy/V3 mixture.
func _test_v3_chosen_mounted_results() -> void:
	for picks in [
			["lantern_monk", "scarecrow", "yarn_ranger"],
			["warden", "rag_duelist", "button_golem"]]:
		var name := str(picks)
		var admission := RunV3PartyAdmission.admit(picks)
		_check(admission.ok and admission.party.size() == 3 and admission.deck.size() == 12,
			name + " chosen trio authentic admission and 12 starter occurrences")
		if not admission.ok:
			continue
		var original_party := CombatParty.new(admission.party)
		_check(original_party.is_valid(), name + " actual three-hero combat party")
		if not original_party.is_valid():
			continue
		var fresh_heroes: Array = original_party.get_heroes()
		var unstitched: Array[String] = []
		unstitched.assign(admission.deck)
		var two_halves: Array[String] = []
		for hero in fresh_heroes:
			for id in unstitched:
				if RunRestStitchCards.resolve_card_definition(id).get("owner") == hero.id:
					two_halves.append(id)
					break
			if two_halves.size() == 2:
				break
		_check(two_halves.size() == 2, name + " two distinct chosen owners have real starter halves")
		if two_halves.size() != 2:
			continue
		var sewn := _stitch_pairs(unstitched, [[two_halves[0], two_halves[1]]], 6)
		_check(not sewn.is_empty(), name + " genuine Rest stitch committed")
		if sewn.is_empty():
			continue
		var carry := RunTornCarryover.new(fresh_heroes)
		_check(carry.is_valid(), name + " genuine V3 torn carryover")
		if not carry.is_valid():
			continue
		# Authentically tear the middle chosen hero while surviving and claiming
		# the reward. Use the ledger's effective HP cap (never 3*count math).
		var fight := carry.create_next_fight_party()
		_check(fight != null, name + " real prior battle party")
		if fight == null:
			continue
		var enemies := CombatEnemies.new([{"id": "v3_torn_witness", "max_hp": 8}])
		var win_result := CombatBattleResult.new(fight, enemies)
		_check(carry.begin_battle("v3_torn_node", win_result, fight),
			name + " tear battle admitted")
		_check(fight.apply_damage(2, fight.get_hero(2).hp)
			and fight.is_downed(2), name + " chosen second hero genuinely downed")
		_check(enemies.apply_damage(1, 8)
			and win_result.evaluate() == CombatBattleResult.VICTORY,
			name + " authentic prior win observed")
		_check(carry.commit_victory("v3_torn_node", win_result, fight).ok
			and carry.apply_reward("v3_torn_node", win_result, fight).ok,
			name + " torn carryover published by real reward claim")
		var heroes: Array = carry.read_state().heroes.duplicate(true)
		var tear_counts: Dictionary = carry.torn.read_state().tear_counts.duplicate(true)
		_check(tear_counts.get(heroes[1].id) == 1
			and heroes[1].hp == 0 and heroes[0].hp > 0 and heroes[2].hp > 0,
			name + " chosen hero's exact by-ID tear and living peers")
		var owned: Array = ["button_eye", "pincushion_arm", "quilted_coat"]
		var wardrobe := RunPatchWardrobe.new(heroes, owned, PATCH_DEFINITIONS.duplicate(true),
			7, 43, sewn.deck, 424242, true)
		_check(wardrobe.is_valid(), name + " genuine torn V3 wardrobe")
		if not wardrobe.is_valid():
			continue
		var wear := [["button_eye", heroes[0].id, "HEAD"],
			["pincushion_arm", heroes[1].id, "ARM"],
			["quilted_coat", heroes[2].id, "COAT"]]
		for i in range(wear.size()):
			var op: Array = wear[i]
			_check(wardrobe.sew(op[0], op[1], op[2], "v3_wear_%d" % i,
				wardrobe.get_snapshot()).ok,
				name + " authentic worn patch owner/slot receipt")
		_check(carry.bind_wardrobe(wardrobe, carry.torn, wardrobe.get_snapshot()),
			name + " exact V3 torn/wardrobe binding is genuine")
		app.run_heroes = heroes.duplicate(true)
		app.party_carryover = carry
		app.run_deck.assign(sewn.deck)
		app.run_stitch_descriptors = sewn.descriptors.duplicate(true)
		app.run_next_stitch_id = sewn.next_stitch_id
		app.run_trinkets.assign(owned)
		app.run_scraps = 7
		app.session_gold = 43
		var ledger_before := _app_snapshot()
		var wear_before := wardrobe.get_snapshot()
		var torn_before := carry.torn.read_state()
		var expectation: Array[String] = []
		for i in range(heroes.size()):
			var hero: Dictionary = heroes[i]
			var op: Array = wear[i]
			var torn_label := " TORN" if hero.hp == 0 else ""
			expectation.append("%s%s %d/%d HP · %s · %s %s" % [
				str(hero.id).capitalize(), torn_label, hero.hp, hero.max_hp,
				"1 tear" if tear_counts[hero.id] == 1 else "%d tears" % tear_counts[hero.id],
				op[2], str(op[0]).replace("_", " ").capitalize()])
		for outcome in ["VICTORY", "DEFEAT"]:
			# Route, battle and terminal settlement are witnessed by real
			# services using this admitted trio, never fabricated verdicts.
			var terminal := _victory(admission.party) if outcome == "VICTORY" else _defeat(admission.party)
			if terminal.is_empty():
				continue
			var ctx: Dictionary = terminal.ctx
			var witnessed := _snapshot(ctx, terminal.battle)
			var before_panel := _app_snapshot()
			var wardrobe_pre := wardrobe.get_snapshot()
			var torn_pre := carry.torn.read_state()
			var rng_pre: int = ctx.rng.state
			_check(panel.open_result(ctx.latch), name + " " + outcome + " opens genuinely settled latch")
			await _frames()
			_check(panel.has_open_result() and panel.get_presented_status() == outcome,
				name + " " + outcome + " selected truthful terminal heading")
			var expected: Array[String] = expectation.duplicate()
			if outcome == "DEFEAT":
				expected.clear()
				for i in range(heroes.size()):
					var hero: Dictionary = heroes[i]
					var op: Array = wear[i]
					expected.append("%s TORN 0/%d HP · %s · %s %s" % [
						str(hero.id).capitalize(), hero.max_hp,
						"1 tear" if tear_counts[hero.id] == 1 else "%d tears" % tear_counts[hero.id],
						op[2], str(op[0]).replace("_", " ").capitalize()])
			_check_hero_rows(expected, name + " " + outcome + " original ledger hero rows")
			_check(panel.summary_label.text.contains("Gold: 43 · Scraps: 7")
				and panel.summary_label.text.contains("Stitched: 1 made · 1 in deck")
				and panel.summary_label.text.contains("Patches worn: 3")
				and panel.summary_label.text.contains("Battles resolved: ")
				and panel.summary_label.text.contains("Floor reached: "),
				name + " " + outcome + " genuine settlement, wallet and stitch counts")
			var card_id: String = sewn.descriptors.keys()[0]
			var source_descriptor: Dictionary = sewn.descriptors[card_id]
			var first_def: Dictionary = RunRestStitchCards.resolve_card_definition(two_halves[0])
			var second_def: Dictionary = RunRestStitchCards.resolve_card_definition(two_halves[1])
			_check(source_descriptor.half_ids == two_halves
				and source_descriptor.owners == [first_def.owner, second_def.owner],
				name + " actual sewn receipt records original halves and owners")
			_check(panel.stitched_rows.get_child_count() == 1,
				name + " exactly one original stitched card remains displayed")
			if panel.stitched_rows.get_child_count() == 1:
				var lines := panel.stitched_rows.get_child(0).get_node("CardInset/CardLines")
				var mounted_name: Label = lines.get_node("Composite")
				var mounted_halves: Label = lines.get_node("Halves")
				_check(mounted_name.text == "%s  ·  %d energy" % [
					source_descriptor.display_name, source_descriptor.cost]
					and mounted_halves.text == "1 · %s (%s)    →    2 · %s (%s)" % [
						first_def.display_name, str(first_def.owner).capitalize(),
						second_def.display_name, str(second_def.owner).capitalize()],
					name + " exact descriptor cost and authentic ordered half/owner labels")
			var right := -1.0
			for i in range(panel.hero_rows.get_child_count()):
				var ticket := panel.hero_rows.get_child(i) as PanelContainer
				var hero: Dictionary = heroes[i]
				var portrait := ticket.get_node("RowInset/HeroPortrait") as TextureRect
				var name_label := ticket.get_node("RowInset/RowLine/HeroName") as Label
				var detail_label := ticket.get_node("RowInset/RowLine/HeroDetail") as Label
				var image_path: String = LiveRunTerminalResultPanel.HERO_PORTRAITS.get(hero.id, "")
				_check(name_label.text == str(hero.id).capitalize()
					and name_label.get_theme_font_size("font_size") >= 18
					and detail_label.get_theme_font_size("font_size") >= 18,
					name + " readable exact chosen hero ticket")
				_check((portrait.texture == null and not portrait.visible)
					if image_path.is_empty() else
					(portrait.texture != null and portrait.texture.resource_path == image_path),
					name + " uses shipped legacy art or clear blank ticket, no invented portrait")
				_check(ticket.get_global_rect().position.x >= right - 0.5
					and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(ticket.get_global_rect()),
					name + " 1280x720 nonoverlapping sewn hero tickets")
				right = ticket.get_global_rect().end.x
			_check(_app_snapshot() == before_panel and wardrobe.get_snapshot() == wardrobe_pre
				and carry.torn.read_state() == torn_pre and ctx.rng.state == rng_pre
				and _snapshot(ctx, terminal.battle) == witnessed,
				name + " " + outcome + " read mutates no run, wardrobe, tears or RNG")
			var earlier_returns := returns
			var stale_callback: Callable = panel.return_button.pressed.get_connections()[0].callable
			panel.return_button.pressed.emit()
			_check(returns == earlier_returns + 1 and panel.return_button.disabled,
				name + " " + outcome + " Return exactly once")
			panel.close_result()
			_check(panel.open_result(ctx.latch), name + " " + outcome + " close/reopen")
			await _frames()
			stale_callback.call()
			_check(returns == earlier_returns + 1 and not panel.return_button.disabled,
				name + " stale Return generation cannot consume a reopened result")
			_check_hero_rows(expected, name + " reopened real chosen tickets")
			panel.close_result()
			_check(_app_snapshot() == before_panel and wardrobe.get_snapshot() == wardrobe_pre
				and carry.torn.read_state() == torn_pre and _snapshot(ctx, terminal.battle) == witnessed,
				name + " reopen fully read-only")
		_check(wardrobe.get_snapshot() == wear_before and carry.torn.read_state() == torn_before,
			name + " original authentic seam/wardrobe unchanged after both outcomes")
		# Stale mismatched selected party is deliberately refused wholesale.
		var mismatch: Array = app.run_heroes.duplicate(true)
		app.run_heroes[0].id = "ninth_hero"
		var terminal_invalid := _victory(admission.party)
		_check(panel.open_result(terminal_invalid.ctx.latch),
			name + " malformed party still allows truthful settled heading")
		_check(panel.summary_label.text.ends_with("Summary unavailable")
			and panel.hero_rows.get_child_count() == 0 and panel.return_button.disabled,
			name + " forged chosen ID never displays partial recap or enables Return")
		panel.close_result()
		app.run_heroes = mismatch
		# A separately valid fresh carryover is nevertheless stale for this
		# genuinely torn trio. It must never yield a partial mixed recap.
		var authentic_carry: RunTornCarryover = app.party_carryover
		var alien_carry := RunTornCarryover.new(fresh_heroes)
		_check(alien_carry.is_valid(), name + " independent carryover is valid")
		app.party_carryover = alien_carry
		_check(panel.open_result(terminal_invalid.ctx.latch)
			and panel.summary_label.text.ends_with("Summary unavailable")
			and panel.hero_rows.get_child_count() == 0 and panel.return_button.disabled,
			name + " valid but mismatched torn ledger cannot authorize hero rows")
		panel.close_result()
		app.party_carryover = authentic_carry
		_check(_app_snapshot() == ledger_before,
			name + " malformed refusals restore exact source snapshots")
