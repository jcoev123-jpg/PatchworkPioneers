extends SceneTree
## Mounted M03 prepared Fight/Elite reward view: presentation and request only.
const SCENE := "res://scenes/run_card_reward_choice_panel.tscn"
const PANEL_SCRIPT := "res://scripts/live_run_card_reward_choice_panel.gd"
const HAND_SCRIPT := "res://scripts/live_hand_card_metadata.gd"
const HEROES := "res://data/heroes/starter_party.json"
const ENEMIES := "res://data/enemies/starter_enemies.json"

var panel: LiveRunCardRewardChoicePanel
var failures: Array[String] = []
var checks: int = 0
var requests: Array[Dictionary] = []
var _hand_coin := Color.WHITE
var _hand_coin_ready := false
var _display_font_cache: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


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
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.pressed = pressed
		event.button_index = MOUSE_BUTTON_LEFT
		root.push_input(event, true)
	await _frames()


func _click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.pressed = pressed
		event.button_index = MOUSE_BUTTON_LEFT
		root.push_input(event, true)
	await _frames()


func _on_choice(node_id: String, selected_card_id: String) -> void:
	requests.append({"node": node_id, "card": selected_card_id})


func _defs(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "authored combat fixture opens: " + path)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_check(parsed is Array and not parsed.is_empty(), "authored combat array parsed: " + path)
	if not parsed is Array:
		return []
	var definitions: Array = []
	for record in parsed:
		_check(record is Dictionary, "authored roster record dictionary")
		if not record is Dictionary:
			continue
		var copy: Dictionary = record.duplicate(true)
		var hp: Variant = copy.get("max_hp")
		var valid: bool = (hp is int and hp > 0) or (hp is float and hp > 0
			and is_finite(hp) and floorf(hp) == hp)
		_check(valid, "authored roster HP positive integral")
		if valid:
			copy["max_hp"] = int(hp)
		definitions.append(copy)
	return definitions


## Return a genuine prepared receipt from previously evaluated victory,
## plus the authoritative service and models to snapshot against UI side effects.
func _prepared(is_elite: bool, seed_value: int) -> Dictionary:
	var party := CombatParty.new(_defs(HEROES))
	var enemies := CombatEnemies.new(_defs(ENEMIES))
	_check(party.is_valid() and enemies.is_valid(), "authored living battle rosters")
	var result := CombatBattleResult.new(party, enemies)
	_check(result.get_outcome() == CombatBattleResult.ACTIVE, "battle begins active")
	for slot in range(1, enemies.get_enemies().size() + 1):
		var enemy := enemies.get_enemy(slot)
		_check(enemies.apply_damage(slot, enemy.get("hp", 0)), "authored enemy killed")
	_check(result.evaluate() == CombatBattleResult.VICTORY, "service sees witnessed victory")
	var catalog := StarterCards.new()
	var cards: Array[String] = catalog.get_all_card_ids()
	var deck: Array[String] = catalog.get_starting_deck()
	var owners: Array[String] = ["warden", "seamstress", "tinker"]
	var owned: Array[String] = ["button_charm"]
	var trinket_pool: Array[String] = ["button_charm", "thread_token"]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var service := RunFightVictoryRewards.new(result, rng, owners, cards, deck, 97,
		is_elite, trinket_pool, owned)
	var receipt := service.prepare()
	_check(receipt.get("ok", false) and (receipt.get("offers", []) as Array).size() == 3,
		"actual prepared three-offer service receipt")
	_check(receipt.get("gold_award", 0) >= (25 if is_elite else 10)
		and receipt.get("gold_award", 0) <= (35 if is_elite else 20),
		"actual receipt has correct pending award band")
	_check(receipt.get("trinket_drop_id") == ("thread_token" if is_elite else ""),
		"actual prepared Elite-only unowned trinket")
	return {"receipt": receipt, "rng": rng, "service": service, "deck": deck,
		"gold": 97, "owned": owned, "party": party, "enemies": enemies, "result": result}


func _snapshot(fixture: Dictionary) -> Dictionary:
	return {
		"rng": fixture["rng"].state,
		"seed": fixture["rng"].seed,
		"deck": fixture["deck"].duplicate(true),
		"gold": fixture["gold"],
		"owned": fixture["owned"].duplicate(true),
		"party": fixture["party"].get_heroes(),
		"enemies": fixture["enemies"].get_enemies(),
		"battle": fixture["result"].get_outcome(),
		"claimed": fixture["service"]._choice.is_claimed(),
		"prepared": fixture["service"].prepare(),
	}


## Independent, explicit authored contract: protect against a formatter and
## catalog drifting together. Additional catalog entries may coexist.
func _expected_cards() -> Dictionary:
	return {
		"warden_strike": {"from": [1, 2], "to": [1, 2], "kind": "enemy_single",
			"effects": {"damage": 6}, "text": "Deal 6."},
		"warden_strike_plus": {"from": [1, 2], "to": [1, 2], "kind": "enemy_single",
			"effects": {"damage": 7}, "text": "Deal 7."},
		"warden_brace": {"from": [1, 2, 3], "to": [], "kind": "self",
			"effects": {"block": 7}, "text": "Gain 7 Block."},
		"warden_shield_bash": {"from": [1], "to": [1], "kind": "enemy_single",
			"effects": {"damage": 8, "weak": 1}, "text": "Deal 8. Weak 1."},
		"seamstress_prick": {"from": [1, 2, 3], "to": [1, 2, 3], "kind": "enemy_single",
			"effects": {"damage": 3, "bleed": 2}, "text": "Deal 3. Bleed 2."},
		"seamstress_mend": {"from": [2, 3], "to": [], "kind": "ally_single",
			"effects": {"heal": 5}, "text": "Heal ally 5 HP."},
		"seamstress_stitch_up": {"from": [1, 2, 3], "to": [], "kind": "ally_single",
			"effects": {"block": 5}, "text": "Ally gains 5 Block."},
		"warden_brace_plus": {"from": [1, 2, 3], "to": [], "kind": "self",
			"effects": {"block": 10}, "text": "Gain 10 Block."},
		"seamstress_mend_plus": {"from": [2, 3], "to": [], "kind": "ally_single",
			"effects": {"heal": 7}, "text": "Heal ally 7 HP."},
		"seamstress_stitch_up_plus": {"from": [1, 2, 3], "to": [], "kind": "ally_single",
			"effects": {"block": 7}, "text": "Ally gains 7 Block."},
		"tinker_pop_shot": {"from": [2, 3], "to": [1, 2, 3], "kind": "enemy_single",
			"effects": {"damage": 5}, "text": "Deal 5."},
		"tinker_scrap_bomb": {"from": [3], "to": [1, 2, 3], "kind": "enemy_all",
			"effects": {"damage": 4}, "text": "Deal 4 to all."},
		"tinker_tune_up": {"from": [1, 2, 3], "to": [], "kind": "none",
			"effects": {"draw": 1}, "text": "Draw 1."},
	}


## The golden felt the shared hand paints its energy coin with, read from that
## script so the reward coin cannot silently drift from the hand convention.
func _hand_coin_color() -> Color:
	if _hand_coin_ready:
		return _hand_coin
	_hand_coin_ready = true
	var script := load(HAND_SCRIPT) as Script
	_check(script != null, "shared hand metadata script loads for coin comparison")
	if script != null:
		var constants: Dictionary = script.get_script_constant_map()
		var value: Variant = constants.get("TINKER", null)
		if value is Color:
			_hand_coin = value
			return _hand_coin
	var file := FileAccess.open(HAND_SCRIPT, FileAccess.READ)
	_check(file != null, "shared hand metadata source readable")
	if file != null:
		var text := file.get_as_text()
		file.close()
		var marker := "const TINKER := Color(\"#"
		var start := text.find(marker)
		_check(start >= 0, "shared hand source declares its energy coin colour")
		if start >= 0:
			var remainder := text.substr(start + marker.length())
			var closing := remainder.find("\"")
			_check(closing > 0, "shared hand coin colour literal is closed")
			if closing > 0:
				_hand_coin = Color("#" + remainder.substr(0, closing))
	return _hand_coin


## The project's three real faces, resolved from the installed theme exactly once:
## the Label display face (PatchHeading), the Button display face
## (PatchHeadingButton) and the plain body face every other line keeps.
func _display_fonts() -> Dictionary:
	if not _display_font_cache.is_empty():
		return _display_font_cache
	var theme := load(String(ProjectSettings.get_setting("gui/theme/custom"))) as Theme
	_check(theme != null, "configured project theme loads for display typography")
	if theme == null:
		return {}
	var heading := theme.get_font(&"font", &"PatchHeading") as Font
	var action := theme.get_font(&"font", &"PatchHeadingButton") as Font
	var body := theme.default_font
	_check(heading != null and action != null and body != null,
		"project theme supplies both display variations and the body face")
	_check(theme.get_type_variation_base(&"PatchHeading") == &"Label"
		and theme.get_type_variation_base(&"PatchHeadingButton") == &"Button",
		"display variations stay bound to their Label and Button base types")
	_check(heading != null and heading.resource_path
		== "res://assets/fonts/LondrinaSolid-Regular.ttf",
		"PatchHeading resolves the authored Londrina Solid Regular display face")
	_check(action != null and action.resource_path
		== "res://assets/fonts/LondrinaSolid-Regular.ttf",
		"PatchHeadingButton resolves the authored Londrina Solid Regular display face")
	_check(heading != null and body != null and heading != body,
		"display face is a different resource from the plain body face")
	_display_font_cache = {"theme": theme, "heading": heading, "action": action, "body": body}
	return _display_font_cache


## The mounted cost coin must keep the exact catalog cost and paint that numeral
## centred inside the golden coin, measured from the font actually drawn. No
## stitch or line may cross the numeral's ink box.
func _check_cost_coin(cost_button: LiveRunCardRewardChoicePanel._CostButton,
		definition: Dictionary, card_id: String) -> void:
	var cost: int = int(definition.get("cost", -1))
	_check(cost_button.cost_value == cost,
		"mounted coin keeps exact authored cost %d: %s" % [cost, card_id])
	_check(cost_button.cost_value >= 0 and cost_button.numeral_text() == str(cost),
		"coin numeral is the authored cost text: " + card_id)
	var gold: Color = cost_button.coin_color()
	_check(gold.r > 0.6 and gold.g > 0.45 and gold.b < gold.g and gold.b < gold.r,
		"coin fill is the golden felt colour: " + card_id)
	_check(gold == _hand_coin_color(),
		"coin fill matches the shared hand energy coin: " + card_id)
	var font: Font = cost_button.get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	_check(font != null, "mounted coin resolves a drawable font: " + card_id)
	if font == null:
		return
	var center: Vector2 = cost_button.size * 0.5
	var radius: float = cost_button.coin_radius()
	_check(radius >= 18.0, "coin is large enough to read its numeral: " + card_id)
	_check(cost_button.numeral_font_size() >= 18,
		"numeral is drawn at a legible point size: " + card_id)
	var bounds: Rect2 = cost_button.numeral_bounds(font)
	_check(bounds.size.x > 0.0 and bounds.size.y > 0.0,
		"numeral reports real measured width and ascent/descent: " + card_id)
	_check(absf(bounds.get_center().x - center.x) <= 1.0,
		"numeral width is centred horizontally in the coin: " + card_id)
	_check(absf(bounds.get_center().y - center.y) <= 1.0,
		"numeral baseline centres its ink box vertically: " + card_id)
	var corners: Array[Vector2] = [bounds.position,
		Vector2(bounds.end.x, bounds.position.y),
		Vector2(bounds.position.x, bounds.end.y), bounds.end]
	for corner: Vector2 in corners:
		_check(corner.distance_to(center) <= radius - 1.5,
			"numeral ink stays inside the coin rim: " + card_id)
	var spans: Array[Vector2] = cost_button.stitch_spans()
	_check(not spans.is_empty(), "coin has a stitched circle, not a bare rim: " + card_id)
	for span: Vector2 in spans:
		_check(span.y > span.x and span.y - span.x < TAU * 0.5,
			"stitch span is a short arc, never a diameter: " + card_id)
		for fraction: float in [0.0, 0.5, 1.0]:
			var angle: float = lerpf(span.x, span.y, fraction)
			var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * cost_button.stitch_radius()
			_check(not bounds.has_point(point),
				"no stitch crosses the numeral: " + card_id)


## Each mounted offer draws exactly three source circles and three target
## squares, filled only for the positions the resolved catalog authorises.
func _check_position_marks(pips: LiveRunCardRewardChoicePanel._PositionPips,
		definition: Dictionary, card_id: String) -> void:
	var slots: Array[Dictionary] = pips.slots()
	_check(slots.size() == 6,
		"exactly six position slots, three sources and three targets: " + card_id)
	var circles: int = 0
	var squares: int = 0
	var filled_circles: Array[int] = []
	var filled_squares: Array[int] = []
	for slot: Dictionary in slots:
		var shape: String = String(slot.get("shape", ""))
		var position: int = int(slot.get("position", 0))
		var filled: bool = bool(slot.get("filled", false))
		var center: Vector2 = slot.get("center", Vector2.ZERO)
		var radius: float = float(slot.get("radius", 0.0))
		_check(position >= 1 and position <= 3, "position slot is numbered 1-3: " + card_id)
		_check(radius > 0.0 and center.x - radius >= -0.5
			and center.x + radius <= pips.size.x + 0.5
			and center.y - radius >= -0.5 and center.y + radius <= pips.size.y + 0.5,
			"position slot stays drawn inside its control: " + card_id)
		if shape == "circle":
			circles += 1
			if filled:
				filled_circles.append(position)
		elif shape == "square":
			squares += 1
			if filled:
				filled_squares.append(position)
		else:
			_check(false, "unsupported position slot shape '%s': %s" % [shape, card_id])
	_check(circles == 3, "three source circle slots are drawn: " + card_id)
	_check(squares == 3, "three target square slots are drawn: " + card_id)
	var owner: String = String(definition.get("owner", ""))
	_check(panel.OWNER_COLORS.has(owner), "authored owner palette exists: " + card_id)
	if panel.OWNER_COLORS.has(owner):
		_check(pips.owner_color == panel.OWNER_COLORS[owner],
			"legal source circles use the owner colour: " + card_id)
	var expected_from: Array[int] = []
	for value: Variant in definition.get("from_positions", []):
		expected_from.append(int(value))
	expected_from.sort()
	var expected_to: Array[int] = []
	for value: Variant in definition.get("to_positions", []):
		expected_to.append(int(value))
	expected_to.sort()
	filled_circles.sort()
	filled_squares.sort()
	_check(filled_circles.size() == expected_from.size(),
		"only authored source positions are filled: " + card_id)
	_check(filled_squares.size() == expected_to.size(),
		"only authored target positions are filled: " + card_id)
	_check(filled_circles == expected_from,
		"source circles filled exactly for from_positions: " + card_id)
	_check(filled_squares == expected_to,
		"target squares filled exactly for to_positions: " + card_id)
	_check(pips.target_kind == String(definition.get("target_kind", "")),
		"position marks keep the authored target kind: " + card_id)
	# An all-enemy cast sews its filled target squares together; no other kind
	# claims an area thread across the marks.
	var thread: PackedVector2Array = pips.thread_points()
	if String(definition.get("target_kind", "")) == "enemy_all":
		_check(thread.size() == 2,
			"all-enemy marks thread their filled squares together: " + card_id)
		if thread.size() == 2:
			var square_centres: Array[Vector2] = []
			for slot: Dictionary in slots:
				if String(slot.get("shape", "")) == "square" and bool(slot.get("filled", false)):
					square_centres.append(slot.get("center", Vector2.ZERO))
			_check(square_centres.size() >= 2 and thread[0] == square_centres.front()
				and thread[1] == square_centres.back(),
				"thread runs from the first to the last legal square: " + card_id)
			_check(thread[0].y == thread[1].y and thread[0].distance_to(thread[1]) > 0.0,
				"thread is a real horizontal seam across the marks: " + card_id)
	else:
		_check(thread.is_empty(),
			"no area thread is sewn for a non-area target kind: " + card_id)


## The sewn owner strip must name the hero who owns the offered card in ink
## that reads against that hero's felt, without disturbing the bound offer.
func _check_owner_strip(receipt: Dictionary, slot: int) -> void:
	var offer: Dictionary = receipt["offers"][slot]
	var card_id := String(offer.get("id", ""))
	var owner := String(offer.get("owner", ""))
	var card := panel.choices_container.get_child(slot) as PanelContainer
	_check(card != null, "owner strip card is mounted: " + card_id)
	if card == null:
		return
	var content := card.get_node("CardMargin/CardContent") as VBoxContainer
	var header := content.get_node_or_null("CardHeader") as HBoxContainer
	var patch: LiveRunCardRewardChoicePanel._OwnerPatch = null
	if header != null:
		patch = header.get_node_or_null("OwnerPatch") as LiveRunCardRewardChoicePanel._OwnerPatch
	elif content != null:
		patch = content.get_node_or_null("OwnerPatch") as LiveRunCardRewardChoicePanel._OwnerPatch
	var label: Label = null
	if patch != null:
		label = patch.get_node_or_null("OwnerLabel") as Label
	_check(header != null and patch != null and label != null, "owner strip mounts a hero name: " + card_id)
	if patch == null or label == null:
		return
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	# The printed name is derived from the receipt's validated owner, and the
	# stripe behind it paints that same owner's palette.
	_check(not owner.is_empty() and label.text == owner.capitalize(),
		"owner strip prints the validated owning hero '%s': %s" % [owner, card_id])
	_check(label.text.to_lower() == owner and panel.OWNER_COLORS.has(owner),
		"owner name agrees with the validated owner palette: " + card_id)
	_check(not label.text.contains("_") and not label.text.contains(card_id),
		"owner strip never prints a raw identifier: " + card_id)
	_check(patch.owner_color == panel.OWNER_COLORS[owner],
		"owner stripe paints the same validated owner: " + card_id)
	var ink: Color = label.get_theme_color("font_color")
	_check(ink == LiveRunCardRewardChoicePanel.owner_ink(owner),
		"owner name uses the readable ink for that felt: " + card_id)
	_check(ink != patch.owner_color, "owner ink is distinct from the felt behind it: " + card_id)
	var contrast: float = LiveRunCardRewardChoicePanel.contrast_ratio(ink, patch.owner_color)
	_check(contrast >= 4.5,
		"owner name ink passes 4.5:1 contrast on its felt: %s (%.2f:1)" % [card_id, contrast])
	_check(label.is_visible_in_tree() and patch.is_visible_in_tree(),
		"owner strip and its name are visibly drawn: " + card_id)
	_check(label.get_theme_font_size("font_size") >= 13,
		"owner name is drawn at a legible point size: " + card_id)
	var fonts := _display_fonts()
	if not fonts.is_empty():
		_check(label.theme_type_variation == &"PatchHeading"
			and label.get_theme_font(&"font") == fonts["heading"],
			"owner name resolves the project PatchHeading display face: " + card_id)
		_check(label.get_theme_font(&"font") != fonts["body"],
			"owner name is not left on the plain body face: " + card_id)
	# The chosen display face must still fit the established 24px felt strip.
	var owner_font: Font = label.get_theme_font(&"font")
	if owner_font != null:
		var owner_size: int = label.get_theme_font_size("font_size")
		_check(owner_font.get_height(owner_size) <= patch.size.y + 1.0,
			"owner name's display line fits inside its felt strip: " + card_id)
		_check(label.get_global_rect().size.y >= owner_font.get_height(owner_size) - 1.0,
			"owner name has the full display line's height: " + card_id)
	_check(patch.get_global_rect().size.y >= label.get_global_rect().size.y
		and patch.get_global_rect().size.y <= 40.0,
		"owner strip grows only enough for the name: " + card_id)
	_check(patch.get_global_rect().encloses(label.get_global_rect())
		and card.get_global_rect().encloses(patch.get_global_rect())
		and screen.encloses(label.get_global_rect()),
		"owner name stays inside its strip, card and 1280x720: " + card_id)
	var action := content.get_node("ChooseButton") as Button
	_check(panel._bound_choices.get(action) == card_id
		and String(panel._receipt["offers"][slot]["id"]) == card_id,
		"owner strip leaves the bound offer ID unchanged: " + card_id)


## The hover legend the mounted card must show: the only place the reward view
## spells the six painted marks out, including the no-square ally/self cases.
func _expected_legend(definition: Dictionary) -> String:
	var parts: Array[String] = [
		"PIPS: filled circles = slots this hero may play from (%s)"
			% _slots_text(definition.get("from_positions", []), "no slot"),
		"outlined circles = not a source slot",
	]
	var to_positions: Array = definition.get("to_positions", [])
	if to_positions.is_empty():
		parts.append("no target square is filled (%s)" % _target_slots_text(definition))
	else:
		parts.append("filled squares = legal target slots (%s)"
			% _slots_text(to_positions, "?"))
		parts.append("outlined squares = not a target slot")
	match str(definition.get("target_kind", "")):
		"enemy_all":
			parts.append("a sewn thread joins every enemy square (ALL = all of them)")
		"party_all":
			parts.append("ALL = every hero")
	var raw_effects: Variant = definition.get("effects", {})
	if raw_effects is Dictionary \
			and bool((raw_effects as Dictionary).get("random_target_each_hit", false)):
		parts.append("RND = one random enemy per hit")
	return "; ".join(parts) + "."


func _slots_text(positions: Array, empty_text: String) -> String:
	if positions.is_empty():
		return empty_text
	if positions.size() == 1:
		return str(positions[0])
	return "%s–%s" % [positions[0], positions.back()]


func _target_slots_text(definition: Dictionary) -> String:
	match str(definition.get("target_kind", "")):
		"ally_single":
			return "any hero slot"
		"party_all":
			return "every hero"
		"self":
			return "this hero"
		"adjacent_ally":
			return "the adjacent hero"
	return "no target"


## The face must never print the old targeting/position prose again: legal
## positions live only in the painted marks and the hover legend.
func _assert_no_position_prose(text: String, card_id: String) -> void:
	for banned in ["From:", "Target:", "living", "pick 1", "front", "middle", "back"]:
		_check(not text.contains(banned),
			"face prints no old position prose '%s': %s" % [banned, card_id])


## Source slice of one nested renderer class, used for the drawing checks that
## a mounted rectangle assertion cannot see.
func _class_source(class_name_marker: String, next_marker: String) -> String:
	var start_marker := "class " + class_name_marker
	var start := _source_slice_position(start_marker)
	if start < 0:
		_check(false, "reward renderer source defines class " + class_name_marker)
		return ""
	return _source_from(start, next_marker)


## Source slice starting at an arbitrary declaration marker (functions, not
## only nested classes), ended by the next marker or the end of the file.
func _source_slice(start_marker: String, next_marker: String) -> String:
	var start := _source_slice_position(start_marker)
	_check(start >= 0, "reward renderer source defines " + start_marker)
	if start < 0:
		return ""
	return _source_from(start, next_marker)


func _source_slice_position(start_marker: String) -> int:
	var file := FileAccess.open(PANEL_SCRIPT, FileAccess.READ)
	_check(file != null, "reward renderer source readable for inspection")
	if file == null:
		return -1
	var text := file.get_as_text()
	file.close()
	return text.find(start_marker)


func _source_from(start: int, next_marker: String) -> String:
	var file := FileAccess.open(PANEL_SCRIPT, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	var end := text.length()
	if not next_marker.is_empty():
		var following := text.find(next_marker, start)
		if following > start:
			end = following
	return text.substr(start, end - start)


## Renderer drawing checks: a gold filled coin measured from real font metrics
## with no line through its numeral, and six plain slots with no pictogram text.
func _test_renderer_source() -> void:
	var coin := _class_source("_CostButton", "## Authored position marks")
	_check(not coin.is_empty(), "cost coin drawing source located")
	_check(coin.contains("draw_circle("), "cost coin source fills a circle")
	_check(coin.contains("COIN_GOLD"), "cost coin source paints the golden felt")
	_check(coin.contains("draw_arc("), "cost coin source stitches a ring")
	_check(coin.contains("draw_string("), "cost coin source draws the numeral")
	_check(coin.contains("get_string_size(") and coin.contains("get_ascent(")
		and coin.contains("get_descent(") and coin.contains("numeral_font_size()"),
		"cost coin measures width/ascent/baseline at the font size it draws")
	_check(not coin.contains("draw_dashed_line") and not coin.contains("draw_line("),
		"cost coin never draws a dashed or straight line through the numeral")
	var marks := _class_source("_PositionPips", "")
	_check(not marks.is_empty(), "position mark drawing source located")
	_check(marks.contains("draw_circle(") and marks.contains("draw_rect("),
		"position marks draw circles and squares")
	_check(marks.contains("thread_points(") and marks.contains("draw_dashed_line(")
		and marks.contains("\"enemy_all\""),
		"an all-enemy cast sews its filled squares together with a dashed thread")
	_check(not marks.contains("draw_string("),
		"position marks draw no miniature numbers")
	var ascii_only := true
	for index in range(marks.length()):
		if marks.unicode_at(index) > 127:
			ascii_only = false
			break
	_check(ascii_only,
		"position marks need no unsupported Unicode pictogram")
	for pictogram in ["→", "←", "↔", "⟲", "↺", "—"]:
		_check(not marks.contains(pictogram),
			"position marks never print the removed symbol " + pictogram)


## The focus perimeter is real drawing, not a colour swap: dark dashed seams
## that never fill the face and never take pointer input. The per-owner ink is
## chosen from measured contrast instead of one ink for every felt.
func _test_focus_and_ink_sources() -> void:
	var stitch := _class_source("_FocusStitch", "## Round sewn energy coin")
	_check(not stitch.is_empty(), "focus stitch drawing source located")
	_check(stitch.contains("draw_line(") and stitch.contains("DARK_FOCUS_INK"),
		"focus stitch draws dark seam segments")
	_check(stitch.contains("stitch_dashes(") and stitch.contains("DASH") and stitch.contains("GAP"),
		"focus stitch is dashed rather than a solid outline")
	_check(stitch.contains("MOUSE_FILTER_IGNORE") and stitch.contains("FOCUS_NONE")
		and not stitch.contains("MOUSE_FILTER_STOP"),
		"focus stitch cannot block pointer input or take focus")
	_check(not stitch.contains("draw_rect(") and not stitch.contains("draw_circle("),
		"focus stitch never fills or covers the button face")
	var button_style := _source_slice("func _style_button", "## A dark, hand-sewn dashed perimeter")
	_check(button_style.contains("font_focus_color"),
		"button styling overrides the focused text ink explicitly")
	_check(button_style.contains("_FocusStitch.DARK_FOCUS_INK"),
		"button focus style uses the same dark ink as the stitched perimeter")
	var expected := {
		"warden": LiveRunCardRewardChoicePanel.LIGHT_INK,
		"seamstress": LiveRunCardRewardChoicePanel.LIGHT_INK,
		"tinker": LiveRunCardRewardChoicePanel.DARK_INK,
	}
	for owner: String in expected:
		var felt: Color = LiveRunCardRewardChoicePanel.OWNER_COLORS[owner]
		var ink: Color = LiveRunCardRewardChoicePanel.owner_ink(owner)
		_check(ink == expected[owner],
			"owner name ink is the documented legible ink for " + owner)
		var chosen: float = LiveRunCardRewardChoicePanel.contrast_ratio(ink, felt)
		_check(chosen >= 4.5, "owner name ink has 4.5:1 contrast on %s felt (%.2f)" % [owner, chosen])
		var rejected: Color = LiveRunCardRewardChoicePanel.DARK_INK \
			if ink != LiveRunCardRewardChoicePanel.DARK_INK else LiveRunCardRewardChoicePanel.LIGHT_INK
		_check(chosen >= LiveRunCardRewardChoicePanel.contrast_ratio(rejected, felt),
			"owner name ink is the better-contrasting choice for " + owner)
	_check(LiveRunCardRewardChoicePanel.contrast_ratio(Color.WHITE, Color.BLACK) > 20.0,
		"contrast helper reproduces the WCAG white-on-black extreme")


## Focused action: dark ink on beige and a dark, visibly dashed perimeter that
## follows keyboard focus without blocking the pointer.
func _check_focus_style(button: Button, label: String) -> void:
	_check(button.has_focus(), "real keyboard input leaves focus on: " + label)
	var focus_ink: Color = button.get_theme_color("font_focus_color")
	_check(focus_ink == panel.DARK_INK and focus_ink.get_luminance() < 0.25,
		"focused action text stays dark ink: " + label)
	var beige := Color("#d4bf9e")
	_check(LiveRunCardRewardChoicePanel.contrast_ratio(focus_ink, beige) >= 4.5,
		"focused action text stays readable on the beige face: " + label)
	var focus_box := button.get_theme_stylebox("focus") as StyleBoxFlat
	_check(focus_box != null, "focused action keeps a drawn focus style: " + label)
	if focus_box != null:
		_check(focus_box.border_color == LiveRunCardRewardChoicePanel._FocusStitch.DARK_FOCUS_INK
			and focus_box.border_color.get_luminance() < 0.2,
			"focus style border is dark ink, not a pale glow: " + label)
	var stitch := button.get_node_or_null("FocusStitch") as LiveRunCardRewardChoicePanel._FocusStitch
	_check(stitch != null, "focused action mounts its stitched perimeter: " + label)
	if stitch == null:
		return
	_check(stitch.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and stitch.focus_mode == Control.FOCUS_NONE,
		"focus perimeter never blocks input or steals focus: " + label)
	_check(stitch.is_stitching(), "focus perimeter follows the focused action: " + label)
	_check(LiveRunCardRewardChoicePanel.contrast_ratio(
		LiveRunCardRewardChoicePanel._FocusStitch.DARK_FOCUS_INK, beige) >= 4.5,
		"focus perimeter ink is visible on the beige face: " + label)
	var button_rect := Rect2(Vector2.ZERO, button.size)
	var rect: Rect2 = stitch.perimeter_rect()
	_check(button_rect.encloses(rect) and rect.size.x >= button.size.x - 12.0
		and rect.size.y >= button.size.y - 12.0,
		"focus perimeter hugs the action inside its own rect: " + label)
	var dashes: Array[PackedVector2Array] = stitch.stitch_dashes()
	_check(dashes.size() >= 12, "focus perimeter is stitched from many short dashes: " + label)
	var stitched_length := 0.0
	for dash: PackedVector2Array in dashes:
		_check(dash.size() == 2, "each focus seam is one short dash: " + label)
		if dash.size() != 2:
			continue
		var length: float = dash[0].distance_to(dash[1])
		stitched_length += length
		_check(length > 0.5 and length <= stitch.DASH + 0.01,
			"focus dash length stays short: " + label)
		_check(rect.grow(0.5).has_point(dash[0]) and rect.grow(0.5).has_point(dash[1]),
			"focus dash stays on the perimeter: " + label)
	var perimeter: float = 2.0 * (rect.size.x + rect.size.y)
	_check(stitched_length > 0.0 and stitched_length < perimeter * 0.8,
		"focus perimeter is visibly dashed, never a solid outline: " + label)


## Real Tab input walks all three Choose actions to Skip and back to the first
## Choose, where the dark stitched perimeter follows focus; Skip stays usable.
## Measure the complete Skip label against the installed font and the
## burlap inset, then check the entire visible vertical family in screen space.
func _check_skip_and_vertical_fit(label: String) -> void:
	var skip := panel.skip_button
	_check(skip.text == "Skip — take no card",
		label + " preserves every word of the Skip action")
	var font: Font = skip.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var point_size: int = skip.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(skip.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x
	var text_height: float = font.get_height(point_size)
	var safe_width: float = text_width + float(panel.BUTTON_EDGE + 8) * 2.0
	_check(skip.size.x >= safe_width and skip.custom_minimum_size.x >= safe_width
		and skip.size.y >= text_height + 16.0,
		label + " full Skip glyphs fit within the burlap's sewn border")
	_check(skip.theme_type_variation == &"PatchHeadingButton",
		label + " Skip action wears the PatchHeadingButton variation")
	var fonts := _display_fonts()
	if not fonts.is_empty():
		_check(font == fonts["action"] and font != fonts["body"],
			label + " Skip measures the project display face, never the body face")
	# The fitted minimum must come from that final face: no stale body metric may
	# leave the complete Skip label overflowing the sewn burlap.
	_check(is_equal_approx(skip.custom_minimum_size.x,
			ceilf(text_width + float(panel.BUTTON_EDGE + 12) * 2.0))
		and is_equal_approx(skip.custom_minimum_size.y, maxf(54.0, text_height + 20.0)),
		label + " Skip's minimum size is derived from the final display font")
	var burlap := skip.get_node_or_null("BurlapPatch") as NinePatchRect
	if burlap != null:
		_check(burlap.get_global_rect().encloses(skip.get_global_rect()),
			label + " burlap patch covers the entire fitted Skip face")
		_check(burlap.patch_margin_top == panel.BUTTON_EDGE
			and burlap.patch_margin_bottom == panel.BUTTON_EDGE,
			label + " Skip keeps the established normal-size burlap slice")
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	var panel_bounds := panel.paper_panel.get_global_rect()
	var family: Array[Control] = [panel.top_stitches, panel.title_label,
		panel.gold_label]
	if panel.trinket_label.visible:
		family.append(panel.trinket_label)
	family.append(panel.choices_container)
	family.append(skip)
	family.append(panel.bottom_stitches)
	for i in range(family.size()):
		var rect := family[i].get_global_rect()
		_check(screen.encloses(rect) and panel_bounds.encloses(rect),
			label + " essential reward row %d fits screen and sewn panel" % i)
		if i > 0:
			_check(family[i - 1].get_global_rect().end.y <= rect.position.y + 0.5,
				label + " reward rows stay vertically ordered without overlap")


func _test_focus_navigation(actions: Array[Button], label: String) -> void:
	requests.clear()
	_check_skip_and_vertical_fit(label)
	_check(actions[0].has_focus(), label + " opens focused on the first Choose")
	_check_focus_style(actions[0], label + " first Choose")
	for index in range(1, 4):
		await _key(KEY_TAB)
		_check(actions[index].has_focus(), "%s Tab reaches action %d" % [label, index])
		var stitch := actions[index].get_node_or_null("FocusStitch") \
			as LiveRunCardRewardChoicePanel._FocusStitch
		_check(stitch != null and stitch.is_stitching(),
			"%s focus perimeter follows action %d" % [label, index])
		var previous := actions[index - 1].get_node_or_null("FocusStitch") \
			as LiveRunCardRewardChoicePanel._FocusStitch
		_check(previous != null and not previous.is_stitching(),
			"%s only the focused action keeps a perimeter" % label)
	await _key(KEY_TAB)
	_check(actions[0].has_focus(), label + " Tab wraps from Skip back to the first Choose")
	_check_focus_style(actions[0], label + " wrapped Choose")
	_check(actions[3] == panel.skip_button and actions[3].is_visible_in_tree()
		and not actions[3].disabled and actions[3].focus_mode == Control.FOCUS_ALL
		and actions[3].text.contains("Skip"),
		label + " fourth Skip option stays available under keyboard focus")
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	_check(screen.encloses(actions[3].get_global_rect()),
		label + " Skip stays inside 1280x720")
	_check(requests.is_empty(), label + " focus navigation never requests a choice")


func _test_all_catalog_rules(base: Dictionary) -> void:
	var catalog := StarterCards.new()
	var expected := _expected_cards()
	var original := base.duplicate(true)
	var authored_before := {}
	for card_id in expected:
		var definition: Dictionary = catalog.get_definition(card_id)
		_check(not definition.is_empty(), "required catalog ID exists: " + card_id)
		if definition.is_empty():
			continue
		authored_before[card_id] = definition.duplicate(true)
		var case: Dictionary = expected[card_id]
		_check(definition.get("from_positions") == case["from"]
			and definition.get("to_positions") == case["to"]
			and definition.get("target_kind") == case["kind"]
			and definition.get("effects") == case["effects"],
			"independent authored fields and base effects: " + card_id)
		var detached: Dictionary = definition.duplicate(true)
		_check(CardShortRules.line(detached) == case["text"],
			"one short-sentence formatter matches authored effects: " + card_id)
		_check(detached == definition, "formatter never mutates detached catalog card: " + card_id)
	# Mount valid three-offer groups through the same live receipt path. No
	# synthetic service or selection logic, and the final short group reuses
	# two other distinct IDs as legal fillers.
	var ids := expected.keys()
	for offset in range(0, ids.size(), 3):
		var receipt := base.duplicate(true)
		for slot in range(3):
			var id: String = ids[(offset + slot) % ids.size()]
			receipt["offers"][slot] = {"id": id, "owner": catalog.get_definition(id)["owner"]}
		var before := receipt.duplicate(true)
		_check(panel.open_rewards("catalog_preview", "Fight", receipt),
			"valid catalog-backed three-offer variant mounts " + str(offset))
		await _frames()
		_validate(receipt, "Fight", "catalog_preview")
		_check(receipt == before, "preview leaves variant receipt intact " + str(offset))
		panel.close_rewards()
		await _frames()
	_check(base == original, "authoritative prepared receipt unchanged by every variant")
	for card_id in authored_before:
		_check(catalog.get_definition(card_id) == authored_before[card_id],
			"authored catalog unchanged by formatter/mount: " + card_id)


## Explicit mounted cases from the real reward-eligible catalogs: cost 0, 1 and 2
## with every authored target kind, checked against detached catalog records.
func _cost_and_target_cases() -> Array[String]:
	return [
		"warden_quick_darn",        # cost 0, target self
		"seamstress_thimble_tea",   # cost 0, target ally_single
		"seamstress_field_mend",    # cost 2, target party_all
		"tinker_ricochet",          # cost 1, target enemy_random
		"tinker_scatter_bolts",     # cost 1, target enemy_all
		"warden_pinning_jab",       # cost 1, target enemy_single
	]


func _starter_cost_cases() -> Array[String]:
	return [
		"tinker_tune_up",     # cost 0, target none
		"warden_strike",      # cost 1, target enemy_single
		"warden_shield_bash", # cost 2, target enemy_single
	]


## One mounted offer checked against the resolved catalog definition: exact
## cost in a centred gold coin, six position slots, the shared short-sentence
## effect text and the hover legend for the exact slots.
func _check_mounted_face(receipt: Dictionary, slot: int) -> void:
	var offer: Dictionary = receipt["offers"][slot]
	var card_id := String(offer.get("id", ""))
	var definition: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(card_id)
	var card := panel.choices_container.get_child(slot) as PanelContainer
	_check(card != null and not definition.is_empty(),
		"mounted cost/target face resolves in the catalog: " + card_id)
	if card == null or definition.is_empty():
		return
	var content := card.get_node("CardMargin/CardContent") as VBoxContainer
	var cost_button := content.get_node("CostButton") as LiveRunCardRewardChoicePanel._CostButton
	var pips := content.get_node("PositionPips") as LiveRunCardRewardChoicePanel._PositionPips
	var rules_label := content.get_node("RulesLabel") as Label
	_check(cost_button != null and pips != null and rules_label != null,
		"cost/target card mounts its coin, marks and rules: " + card_id)
	if cost_button == null or pips == null or rules_label == null:
		return
	_check_cost_coin(cost_button, definition, card_id)
	_check_position_marks(pips, definition, card_id)
	var expected_line: String = CardShortRules.line(definition)
	_check(not expected_line.is_empty() and rules_label.text == expected_line,
		"face prints the shared short-sentence line: " + card_id)
	_assert_no_position_prose(rules_label.text, card_id)
	_check(card.tooltip_text == _expected_legend(definition),
		"hover states the exact source and recipient slots: " + card_id)
	_check(card.mouse_filter == Control.MOUSE_FILTER_STOP
		and not card.tooltip_text.is_empty(),
		"hover legend is reachable without changing the card's action: " + card_id)


func _test_cost_and_marks(fight_base: Dictionary, elite_base: Dictionary) -> void:
	var pool_cases: Array[String] = _cost_and_target_cases()
	var starter_cases: Array[String] = _starter_cost_cases()
	var seen_costs: Dictionary = {}
	var seen_kinds: Dictionary = {}
	var all_ids: Array[String] = []
	all_ids.append_array(pool_cases)
	all_ids.append_array(starter_cases)
	for card_id: String in all_ids:
		var definition: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(card_id)
		_check(not definition.is_empty(),
			"cost/target case is a reward-eligible authored card: " + card_id)
		if definition.is_empty():
			continue
		seen_costs[int(definition.get("cost", -1))] = true
		seen_kinds[String(definition.get("target_kind", ""))] = true
	var bases := {"Fight": fight_base, "Elite": elite_base}
	for kind: String in ["Fight", "Elite"]:
		var base: Dictionary = bases[kind]
		for offset in range(0, pool_cases.size(), 3):
			var receipt := base.duplicate(true)
			for slot in range(3):
				var card_id: String = pool_cases[(offset + slot) % pool_cases.size()]
				var definition: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(card_id)
				_check(not definition.is_empty(), "cost/target offer resolves in the catalog: " + card_id)
				if definition.is_empty():
					continue
				receipt["offers"][slot] = {"id": card_id,
					"owner": String(definition.get("owner", ""))}
			var before := receipt.duplicate(true)
			_check(panel.open_rewards("cost_marks", kind, receipt),
				"%s pool cost/target receipt mounts through the real panel %d" % [kind, offset])
			if not panel.has_open_rewards():
				continue
			await _frames()
			_validate_pool(receipt, kind, "cost_marks")
			for slot in range(3):
				_check_mounted_face(receipt, slot)
			_check(receipt == before,
				"%s cost/target preview leaves its receipt intact %d" % [kind, offset])
			panel.close_rewards()
			await _frames()
		var starter_receipt := base.duplicate(true)
		for slot in range(3):
			var card_id: String = starter_cases[slot]
			var definition: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(card_id)
			_check(not definition.is_empty(), "starter cost case resolves in the catalog: " + card_id)
			starter_receipt["offers"][slot] = {"id": card_id,
				"owner": String(definition.get("owner", ""))}
		var starter_before := starter_receipt.duplicate(true)
		_check(panel.open_rewards("cost_marks", kind, starter_receipt),
			"%s starter cost/target receipt mounts through the real panel" % kind)
		if panel.has_open_rewards():
			await _frames()
			_validate(starter_receipt, kind, "cost_marks")
			for slot in range(3):
				_check_mounted_face(starter_receipt, slot)
			_check(starter_receipt == starter_before,
				"%s starter cost/target preview leaves its receipt intact" % kind)
			panel.close_rewards()
			await _frames()
	_check(seen_costs.has(0) and seen_costs.has(1) and seen_costs.has(2),
		"mounted cases really cover authored costs 0, 1 and 2")
	for kind in ["enemy_single", "enemy_all", "enemy_random", "self", "ally_single",
			"party_all", "none"]:
		_check(seen_kinds.has(kind), "mounted cases really cover target kind " + kind)


## Every mounted reward action and owner strip wears the project display faces:
## Choose/Skip/Help on PatchHeadingButton and owner names on PatchHeading, while
## card names keep PatchHeading and rules, rarity, pips and the coin numeral keep
## their existing body contracts. Hover, focus and disabled stay visibly distinct.
func _check_display_typography() -> void:
	var fonts := _display_fonts()
	if fonts.is_empty():
		return
	var action_font: Font = fonts["action"]
	var body_font: Font = fonts["body"]
	_check(panel.has_open_rewards() and panel.choices_container.get_child_count() == 3,
		"display typography inspected on a mounted three-offer reward")
	if not panel.has_open_rewards() or panel.choices_container.get_child_count() != 3:
		return
	var actions := panel.get_choice_buttons()
	_check(actions.size() == 4, "display typography inspects all four reward actions")
	for index in range(mini(actions.size(), 4)):
		var button := actions[index]
		var action_name := "Skip" if button == panel.skip_button else "Choose %d" % index
		_check(button.theme_type_variation == &"PatchHeadingButton",
			"%s resolves the PatchHeadingButton variation" % action_name)
		_check(button.get_theme_font(&"font") == action_font,
			"%s resolves the project display font" % action_name)
		_check(button.get_theme_font(&"font") != body_font,
			"%s is lettered in the display face, not the body face" % action_name)
		_check(button.get_theme_font_size(&"font_size") == 20,
			"%s keeps its authored 20 point size" % action_name)
		var state_boxes: Array[StyleBoxFlat] = []
		for state in ["normal", "hover", "disabled"]:
			var box := button.get_theme_stylebox(state) as StyleBoxFlat
			_check(box != null, "%s keeps a drawn %s face" % [action_name, state])
			state_boxes.append(box)
		if state_boxes.size() == 3 and state_boxes[0] != null \
				and state_boxes[1] != null and state_boxes[2] != null:
			_check(state_boxes[0].bg_color != state_boxes[1].bg_color
				and state_boxes[0].bg_color != state_boxes[2].bg_color,
				"%s keeps visibly distinct hover and disabled faces" % action_name)
		_check(button.get_theme_color("font_focus_color") == panel.DARK_INK,
			"%s keeps its dark focused ink" % action_name)
	for index in range(panel.choices_container.get_child_count()):
		var content := panel.choices_container.get_child(index).get_node(
			"CardMargin/CardContent") as VBoxContainer
		var card_id := String(panel._receipt["offers"][index].get("id", ""))
		var header := content.get_node_or_null("CardHeader") as HBoxContainer
		var owner_label := header.get_node_or_null("OwnerPatch/OwnerLabel") as Label if header != null else content.get_node_or_null("OwnerPatch/OwnerLabel") as Label
		_check(owner_label != null and owner_label.theme_type_variation == &"PatchHeading"
			and owner_label.get_theme_font(&"font") == fonts["heading"]
			and owner_label.get_theme_font(&"font") != body_font,
			"owner strip is lettered in PatchHeading: " + card_id)
		var help := header.get_node_or_null("HelpButton") as Button if header != null else content.get_node_or_null("OwnerPatch/HelpCorner/HelpButton") as Button
		if help == null:
			continue
		_check(help.theme_type_variation == &"PatchHeadingButton"
			and help.get_theme_font(&"font") == action_font,
			"Help tab resolves the PatchHeadingButton display font: " + card_id)
		_check(help.get_theme_font_size(&"font_size") >= 12,
			"Help tab keeps a legible compact point size: " + card_id)
		var help_size: int = help.get_theme_font_size(&"font_size")
		var help_width: float = action_font.get_string_size(help.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, help_size).x
		_check(help.get_global_rect().size.x >= help_width + 12.0
			and help.get_global_rect().size.y
				>= action_font.get_height(help_size) - 1.0,
			"Help tab leaves room for its complete display label: " + card_id)


func _check_reward_typography(receipt: Dictionary) -> void:
	var project_theme := load(String(ProjectSettings.get_setting("gui/theme/custom"))) as Theme
	_check(project_theme != null, "configured project theme loads")
	if project_theme == null:
		return
	_check(project_theme.get_type_variation_base(&"PatchHeading") == &"Label"
		and project_theme.has_font(&"font", &"PatchHeading"),
		"project PatchHeading supplies a Label font")
	var heading_font := project_theme.get_font(&"font", &"PatchHeading")
	_check(heading_font != null and heading_font.resource_path
		== "res://assets/fonts/LondrinaSolid-Regular.ttf",
		"project heading resolves to authored Londrina Solid Regular")
	_check(panel.has_open_rewards() and panel.title_label.is_visible_in_tree(),
		"typography inspected on an open mounted reward")
	_check_display_typography()
	_check(panel.title_label.theme_type_variation == &"PatchHeading"
		and panel.title_label.get_theme_font(&"font") == heading_font,
		"mounted reward banner resolves the project PatchHeading font")
	_check(panel.title_label.get_theme_font_size(&"font_size") == 31,
		"reward banner retains its authored point size")
	var is_elite: bool = panel._node_kind == "Elite"
	_check(panel.gold_label.is_visible_in_tree() and not panel.gold_label.text.is_empty(),
		"a visible pending-gold receipt is mounted for inspection")
	var receipts: Array[Label] = [panel.gold_label]
	if is_elite:
		_check(panel.trinket_label.is_visible_in_tree()
			and not panel.trinket_label.text.is_empty(),
			"Elite mounts a separate visible patch receipt beside the gold receipt")
		receipts.append(panel.trinket_label)
	else:
		_check(not panel.trinket_label.visible and panel.trinket_label.text.is_empty(),
			"plain Fight leaves the patch receipt hidden and empty")
	for receipt_label: Label in receipts:
		_check_receipt_tab(receipt_label, heading_font, project_theme)
	if receipts.size() == 2:
		_check(panel.gold_label.get_theme_stylebox("normal") is StyleBoxFlat
			and panel.trinket_label.get_theme_stylebox("normal") is StyleBoxFlat
			and (panel.gold_label.get_theme_stylebox("normal") as StyleBoxFlat).bg_color
				!= (panel.trinket_label.get_theme_stylebox("normal") as StyleBoxFlat).bg_color,
			"gold and patch receipts wear distinct sewn tabs")
	_check(panel.gold_label.text == "Pending gold: +%d" % int(receipt.get("gold_award", 0)),
		"sewn gold receipt keeps the exact pending-gold wording")
	var offers: Array = receipt.get("offers", [])
	_check(offers.size() == 3 and panel.choices_container.get_child_count() == 3,
		"typography inspects all three actual mounted offers")
	if offers.size() != 3 or panel.choices_container.get_child_count() != 3:
		return
	var starter := StarterCards.new()
	for index in range(3):
		var card_id := String(offers[index]["id"])
		var definition := starter.get_definition(card_id)
		if definition.is_empty():
			definition = _base_pool_definition(card_id)
		_check(not definition.is_empty(), "typography has an authored definition: " + card_id)
		var content := panel.choices_container.get_child(index).get_node("CardMargin/CardContent")
		var name_label := content.get_node("NameLabel") as Label
		_check(name_label.is_visible_in_tree() and name_label.theme_type_variation == &"PatchHeading"
			and name_label.get_theme_font(&"font") == heading_font,
			"mounted name resolves project PatchHeading: " + card_id)
		_check(not name_label.text.is_empty()
			and name_label.text == String(definition.get("display_name", ""))
			and name_label.get_theme_font_size(&"font_size") == 21,
			"mounted name retains authored text and size, including after reopen: " + card_id)
		for label_name in ["RulesLabel", "RarityLabel"]:
			var label := content.get_node(label_name) as Label
			_check(label.theme_type_variation == &""
				and label.get_theme_font(&"font") == project_theme.default_font
				and label.get_theme_font_size(&"font_size") == 15,
				"body/rarity keep default font and size: %s %s" % [card_id, label_name])
		var cost := content.get_node("CostButton") as LiveRunCardRewardChoicePanel._CostButton
		_check(cost.theme_type_variation == &""
			and cost.get_theme_default_font() == project_theme.default_font,
			"cost coin keeps default font: " + card_id)


## Pending gold and the Elite patch are sewn labels: the project display face,
## their authored point size, dark ink on a muted felt tab inside a dark stitch,
## and no pointer capture. Measured from the mounted label, not a screenshot: the
## tab only owns the seam around its own line, so the three offers, Help tabs,
## banner and Skip keep their established vertical room.
func _check_receipt_tab(label: Label, heading_font: Font, project_theme: Theme) -> void:
	var label_name := String(label.name)
	var point_size: int = 22 if label_name == "GoldLabel" else 19
	_check(label.is_visible_in_tree() and not label.text.is_empty(),
		"sewn receipt is on screen with its bound text: " + label_name)
	_check(label.theme_type_variation == &"PatchHeading"
		and label.get_theme_font(&"font") == heading_font,
		"sewn receipt resolves the project PatchHeading font: " + label_name)
	_check(label.get_theme_font(&"font") != project_theme.default_font,
		"sewn receipt uses the display face, not the plain body font: " + label_name)
	_check(label.get_theme_font_size(&"font_size") == point_size,
		"sewn receipt keeps its authored %d point size: %s" % [point_size, label_name])
	_check(label.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"sewn receipt never captures the pointer: " + label_name)
	var tab := label.get_theme_stylebox("normal") as StyleBoxFlat
	_check(tab != null, "sewn receipt has its own paper/felt tab: " + label_name)
	if tab == null:
		return
	var felt: Color = tab.bg_color
	_check(felt.a > 0.0 and felt.get_luminance() > 0.3 and felt.get_luminance() < 0.8,
		"receipt tab is muted felt rather than bare paper or pure black: " + label_name)
	_check(tab.border_width_left >= 2 and tab.border_width_top >= 2
		and tab.border_width_right >= 2 and tab.border_width_bottom >= 2,
		"receipt tab is outlined by a sewn border: " + label_name)
	_check(tab.border_color.get_luminance() < felt.get_luminance(),
		"receipt stitch border is darker than its felt: " + label_name)
	_check(tab.corner_radius_top_left >= 4 and tab.corner_radius_bottom_right >= 4,
		"receipt tab has sewn rounded corners: " + label_name)
	var ink: Color = label.get_theme_color("font_color")
	_check(ink.get_luminance() < felt.get_luminance(),
		"receipt text is dark ink on its felt tab: " + label_name)
	_check(LiveRunCardRewardChoicePanel.contrast_ratio(ink, felt) >= 4.5,
		"receipt ink passes 4.5:1 contrast on its tab: %s (%.2f:1)"
			% [label_name, LiveRunCardRewardChoicePanel.contrast_ratio(ink, felt)])
	var paper := panel.paper_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if paper != null:
		_check(LiveRunCardRewardChoicePanel.contrast_ratio(felt, paper.bg_color) >= 1.15,
			"receipt felt separates from the reward paper behind it: " + label_name)
	# The tab owns only its seam: modest insets and a measured height close to
	# one display line, so no wrapper crowds the cards, banner, Help or Skip.
	var font: Font = label.get_theme_font(&"font")
	if font == null:
		font = ThemeDB.fallback_font
	var line_height: float = font.get_height(point_size)
	_check(label.size.x > 0.0 and label.size.y > 0.0,
		"receipt tab has real measured room on the page: " + label_name)
	_check(tab.content_margin_top <= 4.0 and tab.content_margin_bottom <= 4.0,
		"receipt tab keeps only modest vertical insets: " + label_name)
	_check(label.size.y <= line_height + 10.0,
		"receipt tab adds only its seam to one line (%.1fpx line, %.1fpx tab): %s"
			% [line_height, label.size.y, label_name])
	var text_width: float = font.get_string_size(label.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x
	_check(label.size.x <= text_width + tab.content_margin_left
		+ tab.content_margin_right + 8.0,
		"receipt tab hugs its own line instead of spanning the page (%.1fpx text, %.1fpx tab): %s"
			% [text_width, label.size.x, label_name])


func _validate(receipt: Dictionary, kind: String, node_id: String) -> void:
	_check_reward_typography(receipt)
	_check(panel.has_open_rewards() and panel.is_visible_in_tree(), "actual scene mounted: " + kind)
	_check(panel.title_label.text.contains(kind), "reward title contains kind: " + kind)
	_check(not panel.title_label.text.contains(node_id) and not panel.title_label.text.contains("_"),
		"reward title is human-readable without raw node ID: " + kind)
	_check(panel.gold_label.text == "Pending gold: +%d" % receipt["gold_award"],
		"exact prepared pending gold visible: " + kind)
	_check(panel.gold_label.is_visible_in_tree()
		and int(receipt["gold_award"]) >= (25 if kind == "Elite" else 10)
		and int(receipt["gold_award"]) <= (35 if kind == "Elite" else 20),
		"sewn %s gold receipt shows its actual documented award band: " % kind
			+ panel.gold_label.text)
	_check(panel.trinket_label.visible == (kind == "Elite"), "Elite-only trinket label visibility")
	if kind == "Elite":
		_check(panel.trinket_label.is_visible_in_tree()
			and panel.trinket_label.text == "Patch: Thread Token",
			"separate sewn patch receipt names the humanised Elite drop: " + kind)
		_check(panel.trinket_label.text.contains("Thread Token"), "human-readable patch name visible: " + kind)
		_check(not panel.trinket_label.text.contains(receipt["trinket_drop_id"]) and not panel.trinket_label.text.contains("_"),
			"patch label does not expose raw trinket identifier or underscore")
	else:
		_check(panel.trinket_label.text.is_empty(), "non-Elite trinket label is empty")
		_check(not panel.trinket_label.is_visible_in_tree(),
			"plain Fight never displays a patch receipt just because its style exists")
	var paper := panel.paper_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_check(paper != null and paper.bg_color.get_luminance() > 0.55
		and paper.border_width_left >= 4, "cream stitched paper")
	var slate := panel.get_node("SlateBackdrop") as ColorRect
	_check(slate != null and slate.color.get_luminance() < 0.3, "dark slate backing")
	_check(panel.top_stitches.text.contains("×") and panel.bottom_stitches.text.contains("×"),
		"visible hand-drawn stitches")
	var actions := panel.get_choice_buttons()
	_check(actions.size() == 4 and panel.choices_container.get_child_count() == 3,
		"three genuine card panels and one Skip")
	if actions.size() != 4:
		return
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	_check(screen.encloses(panel.paper_panel.get_global_rect()), "paper within 1280x720")
	var catalog := StarterCards.new()
	for index in range(3):
		var offer: Dictionary = receipt["offers"][index]
		var definition: Dictionary = catalog.get_definition(offer["id"])
		_check(not definition.is_empty() and definition["owner"] == offer["owner"],
			"prepared offer backed by authored catalog " + str(index))
		var card := panel.choices_container.get_child(index) as PanelContainer
		_check(card != null and card.name == "Card_%d" % index, "stable mounted card index")
		if card == null:
			continue
		var content := card.get_node("CardMargin/CardContent") as VBoxContainer
		var header := content.get_node_or_null("CardHeader") as HBoxContainer
		var owner_patch := (header.get_node("OwnerPatch") as Control) if header != null else (content.get_node("OwnerPatch") as Control)
		var name_label := content.get_node("NameLabel") as Label
		var rarity_label := content.get_node("RarityLabel") as Label
		var cost_button := content.get_node("CostButton") as Control
		var pips_container := content.get_node("PositionPips") as Control
		var rules_label := content.get_node_or_null("RulesLabel") as Label
		var action := content.get_node("ChooseButton") as Button
		_check(action == actions[index], "real action bound to card " + str(index))
		_check(cost_button != null and (cost_button as LiveRunCardRewardChoicePanel._CostButton).cost_value == definition.get("cost", 0),
			"exact cost value matches authored definition (including 0): " + str(index))
		_check(name_label.text == definition["display_name"],
			"exact authored display name: " + str(index))
		_check(owner_patch != null
			and (owner_patch as LiveRunCardRewardChoicePanel._OwnerPatch).owner_color == panel.OWNER_COLORS.get(offer.get("owner", ""), Color.WHITE),
			"author patch color matches owner's palette: " + str(index))
		_check_owner_strip(receipt, index)
		_check(pips_container != null
			and (pips_container as LiveRunCardRewardChoicePanel._PositionPips).from_positions == definition.get("from_positions", [])
			and (pips_container as LiveRunCardRewardChoicePanel._PositionPips).to_positions == definition.get("to_positions", [])
			and (pips_container as LiveRunCardRewardChoicePanel._PositionPips).target_kind == String(definition.get("target_kind", "")),
			"position/target pips match catalog definition: " + str(index))
		if cost_button != null and pips_container != null:
			_check_cost_coin(cost_button as LiveRunCardRewardChoicePanel._CostButton,
				definition, String(offer["id"]))
			_check_position_marks(pips_container as LiveRunCardRewardChoicePanel._PositionPips,
				definition, String(offer["id"]))
		_check(rarity_label != null and (not rarity_label.visible or rarity_label.text.is_empty()),
			"legacy starter offer receives honest no-rarity presentation: " + str(index))
		_check(rarity_label != null and rarity_label.text != "Common",
			"starter offer never receives false Common: " + str(index))
		_assert_no_raw_identifiers(card, offer["id"], node_id, receipt.get("trinket_drop_id", ""))
		var expected := _expected_cards()
		_check(rules_label != null, "RulesLabel exists on live card " + str(index))
		if rules_label != null:
			_check(expected.has(offer["id"]), "prepared card has independent rule expectations " + offer["id"])
			if expected.has(offer["id"]):
				var authored: Dictionary = expected[offer["id"]]
				_check(definition["from_positions"] == authored["from"]
					and definition["to_positions"] == authored["to"]
					and definition["target_kind"] == authored["kind"]
					and definition["effects"] == authored["effects"],
					"authoritative definition matches displayed positional/effect contract " + offer["id"])
				_check(rules_label.text == authored["text"],
					"mounted card shows exact authored rules (including amounts) " + offer["id"])
				_check(rules_label.text == CardShortRules.line(definition),
					"mounted card uses the one shared short-sentence formatter " + offer["id"])
				_assert_no_position_prose(rules_label.text, String(offer["id"]))
			_check(rules_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
				and rules_label.get_theme_font_size("font_size") >= 15
				and rules_label.get_line_count() <= 3
				and rules_label.get_visible_line_count() == rules_label.get_line_count(),
				"rules are readable in at most three complete rendered lines " + offer["id"])
			_check(card.tooltip_text == _expected_legend(definition),
				"mounted card hover states the exact source and recipient slots " + offer["id"])
			_check(card.mouse_filter == Control.MOUSE_FILTER_STOP
				and not card.tooltip_text.is_empty(),
				"mounted card hover legend is reachable beside its action " + offer["id"])
			_check(card.get_global_rect().encloses(rules_label.get_global_rect())
				and screen.encloses(rules_label.get_global_rect())
				and cost_button.get_global_rect().end.y <= rules_label.get_global_rect().position.y
				and rules_label.get_global_rect().end.y <= action.get_global_rect().position.y,
				"rules label fits card and never overlaps cost or button " + offer["id"])
		_check(name_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
			and name_label.size.y >= name_label.get_minimum_size().y
			and name_label.get_visible_line_count() == name_label.get_line_count()
			and not name_label.clip_text,
			"long valid display name supports robust wrapping")
		var style := card.get_theme_stylebox("panel") as StyleBoxFlat
		_check(style != null and style.border_color == panel.OWNER_COLORS[offer["owner"]],
			"authored owner palette visible")
		_check(screen.encloses(card.get_global_rect()) and screen.encloses(action.get_global_rect()),
			"card and actionable button fully within viewport")
	for index in range(4):
		var button: Button = actions[index]
		_check(button.focus_mode == Control.FOCUS_ALL and button.is_visible_in_tree()
			and not button.disabled, "four enabled focusable actions " + str(index))
		_check(screen.encloses(button.get_global_rect()), "action fully within viewport " + str(index))
		_check(button.get_theme_stylebox("normal") is StyleBoxFlat
			and button.get_theme_stylebox("focus") is StyleBoxFlat,
			"procedural normal and obvious focus styles " + str(index))
	_check(actions[3] == panel.skip_button and actions[3].text.contains("Skip"),
		"fourth action Skip, not a card")


func _test_long_name_wrap() -> void:
	var card := panel.choices_container.get_child(0) as PanelContainer
	var name_label := card.get_node("CardMargin/CardContent/NameLabel") as Label
	var original := name_label.text
	name_label.text = "A Patient Stitcher Carefully Repairs Every Loose Thread Along The Long Patchwork Trail"
	await _frames()
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	_check(name_label.get_line_count() >= 3 and name_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		"long authored-style name wraps across multiple visible lines")
	_check(card.get_global_rect().encloses(name_label.get_global_rect())
		and screen.encloses(name_label.get_global_rect())
		and screen.encloses(panel.skip_button.get_global_rect()),
		"wrapped name and Skip remain inside card and 1280x720 viewport")
	name_label.text = original
	await _frames()


func _exercise(fixture: Dictionary, kind: String, physical: int) -> void:
	var receipt: Dictionary = fixture["receipt"]
	var node_id := "floor_02_elite" if kind == "Elite" else "floor_01_fight"
	var before := _snapshot(fixture)
	requests.clear()
	_check(panel.open_rewards(node_id, kind, receipt), kind + " scene opens service receipt")
	await _frames()
	_validate(receipt, kind, node_id)
	await _test_long_name_wrap()
	var actions := panel.get_choice_buttons()
	if actions.size() != 4:
		panel.close_rewards()
		return
	_check(actions[0].has_focus(), kind + " first action receives keyboard focus")
	await _test_focus_navigation(actions, kind + " starter")
	_check(not panel.open_rewards("replacement", kind, receipt), "cannot replace active prepared reward")
	_check(panel.title_label.text.contains(kind), "refused overwrite keeps title")
	# Caller mutation cannot change the displayed choice or callback binding.
	var original := receipt.duplicate(true)
	receipt["offers"][0]["id"] = "forged"
	receipt["offers"][1]["owner"] = "forged"
	receipt["gold_award"] = 999
	receipt["trinket_drop_id"] = "forged"
	_validate(original, kind, node_id)
	_check(panel._receipt == original, "detached nested prepared receipt unchanged")
	# Forced invisible and disabled Button signals must fail closed.
	actions[0].hide()
	actions[0].pressed.emit()
	actions[0].show()
	actions[0].disabled = true
	actions[0].pressed.emit()
	actions[0].disabled = false
	panel.hide()
	actions[0].pressed.emit()
	panel.show()
	_check(requests.is_empty(), "hidden/disabled/closed-parent actions cannot request")
	var gen := panel._generation
	panel._on_choice_pressed(gen, node_id, "unoffered", actions[0])
	panel._on_choice_pressed(gen, node_id, original["offers"][1]["id"], actions[0])
	var rogue := Button.new()
	panel.choices_container.add_child(rogue)
	panel._on_choice_pressed(gen, node_id, original["offers"][0]["id"], rogue)
	rogue.queue_free()
	_check(requests.is_empty() and not panel._awaiting_ack,
		"forged card/button bindings reject without consuming offer")
	# Full-card paper/label clicks route through the same guarded action.
	requests.clear()
	var full_card := panel.choices_container.get_child(0) as PanelContainer
	var full_name := full_card.get_node("CardMargin/CardContent/NameLabel") as Label
	await _click(full_name)
	_check(requests == [{"node": node_id, "card": original["offers"][0]["id"]}],
		kind + " full-card label click requests exact offer once")
	for button in actions:
		_check(button.disabled, "full-card request disables all choices")
		button.pressed.emit()
	_check(requests.size() == 1, "duplicate pending requests rejected after full-card click")
	panel.acknowledge(false)
	_check(actions.all(func(button: Button) -> bool: return not button.disabled),
		"rejection re-enables after full-card click")
	# Paper-area click on another card.
	requests.clear()
	var second_card := panel.choices_container.get_child(1) as PanelContainer
	var paper_point := second_card.get_global_rect().position + Vector2(6, 6)
	var motion := InputEventMouseMotion.new()
	motion.position = paper_point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = paper_point
		event.pressed = pressed
		event.button_index = MOUSE_BUTTON_LEFT
		root.push_input(event, true)
	await _frames()
	_check(requests == [{"node": node_id, "card": original["offers"][1]["id"]}],
		kind + " full-card paper click requests exact offer once")
	panel.acknowledge(false)
	_check(actions.all(func(button: Button) -> bool: return not button.disabled),
		"rejection re-enables after paper click")
	requests.clear()
	# Physical pointer on Fight, physical Enter on Elite.
	var selected_index := 1 if kind == "Fight" else 2
	if physical == 0:
		await _mouse(actions[selected_index])
	else:
		actions[selected_index].grab_focus()
		await _frames()
		_check(actions[selected_index].has_focus(), "Enter choice actually focused")
		await _key(KEY_ENTER)
	_check(requests == [{"node": node_id, "card": original["offers"][selected_index]["id"]}],
		"physical action makes exactly one node/card request")
	for button in actions:
		_check(button.disabled, "request disables all choices while pending")
		button.pressed.emit()
	_check(requests.size() == 1, "duplicate pending physical/signal requests rejected")
	panel.acknowledge(false)
	_check(actions.all(func(button: Button) -> bool: return not button.disabled),
		"explicit rejection permits retry of SAME offers")
	_validate(original, kind, node_id)
	# Physically press Space on Skip after rejection.
	actions[3].grab_focus()
	await _frames()
	_check(actions[3].has_focus(), "Skip focused before Space")
	await _key(KEY_SPACE)
	_check(requests.size() == 2 and requests[1] == {"node": node_id, "card": ""},
		"physical Space requests empty Skip ID once")
	panel.acknowledge(true)
	_check(panel._accepted and not panel._awaiting_ack, "accepted acknowledgement latched")
	for button in actions:
		_check(button.disabled, "accepted acknowledgement locks all four actions")
		button.pressed.emit()
	panel.acknowledge(false)
	panel.acknowledge(true)
	_check(requests.size() == 2 and actions.all(func(button: Button) -> bool: return button.disabled),
		"duplicate acknowledgements and actions cannot replay")
	_check(_snapshot(fixture) == before, "all ledger, battle and injected RNG state untouched")
	panel.close_rewards()
	_check(not panel.has_open_rewards() and not panel.visible
		and panel.get_choice_buttons().is_empty(), "close clears all active actions")
	await _frames()


func _malformed(base: Dictionary) -> void:
	var invalids: Array[Dictionary] = []
	var wrong_ok := base.duplicate(true)
	wrong_ok["ok"] = false
	invalids.append(wrong_ok)
	for missing in ["ok", "gold_award", "offers", "trinket_drop_id"]:
		var value := base.duplicate(true)
		value.erase(missing)
		invalids.append(value)
	for reward in [0, 9, 21, "15"]:
		var value := base.duplicate(true)
		value["gold_award"] = reward
		invalids.append(value)
	for invalid_offers in [[], base["offers"].slice(0, 2), base["offers"] + [base["offers"][0]], "invalid"]:
		var value := base.duplicate(true)
		value["offers"] = invalid_offers
		invalids.append(value)
	for invalid in [
			{"id": "bogus", "owner": "warden"},
			{"id": base["offers"][1]["id"], "owner": base["offers"][1]["owner"]},
			{"id": base["offers"][0]["id"], "owner": "alien"},
			{"id": base["offers"][0]["id"], "owner": 5},
			{"id": 5, "owner": "warden"},
			{"owner": "warden"}, "not_a_dictionary"]:
		var value := base.duplicate(true)
		value["offers"][0] = invalid
		invalids.append(value)
	var no_trinket := base.duplicate(true)
	no_trinket["trinket_drop_id"] = "fabric_drop"
	invalids.append(no_trinket)
	requests.clear()
	for index in range(invalids.size()):
		var input := invalids[index]
		var preserved := input.duplicate(true)
		_check(not panel.open_rewards("node", "Fight", input), "bad offer fails closed " + str(index))
		_check(not panel.visible and panel.get_choice_buttons().is_empty()
			and not panel.has_open_rewards(), "bad offer mounts no controls " + str(index))
		_check(input == preserved and requests.is_empty(), "bad offer makes no mutations " + str(index))
	for kind in ["Boss", "", 4]:
		_check(not panel.open_rewards("node", kind, base), "invalid node type rejects " + str(kind))
	for node_id in ["", "  ", 5]:
		_check(not panel.open_rewards(node_id, "Fight", base), "invalid node identity rejected")
	var bad_elite := base.duplicate(true)
	bad_elite["gold_award"] = 30
	_check(not panel.open_rewards("node", "Elite", bad_elite),
		"Elite without supplied trinket rejects instead of synthesizing drop")
	_check(requests.is_empty(), "malformed suite never emits requests")


func _replay_and_stale(base: Dictionary) -> void:
	var independent: Array = []
	var first_generation := -1
	var old_callback: Callable
	var first_button: Button
	requests.clear()
	for pass_index in range(2):
		_check(panel.open_rewards("same_node", "Fight", base), "fresh independent replay opens")
		# Exercise retained callback while old Button is queued (not yet freed).
		if pass_index == 1 and old_callback.is_valid() and is_instance_valid(first_button):
			old_callback.call()
			panel._on_choice_pressed(first_generation, "same_node", base["offers"][0]["id"], first_button)
			_check(requests.is_empty(), "prior closed/reopened callable cannot emit")
			_check(panel._generation != first_generation
				and panel._receipt == base and not panel._awaiting_ack,
				"new offer intact after stale callback")
		await _frames()
		_check_reward_typography(base)
		var buttons := panel.get_choice_buttons()
		if buttons.size() != 4:
			panel.close_rewards()
			break
		if pass_index == 0:
			first_generation = panel._generation
			first_button = buttons[0]
			var connections := first_button.pressed.get_connections()
			_check(connections.size() == 1, "real first callback captured")
			if not connections.is_empty():
				old_callback = connections[0]["callable"]
		var ui: Array = []
		for index in range(3):
			var content := panel.choices_container.get_child(index).get_node("CardMargin/CardContent")
			var header := content.get_node_or_null("CardHeader") as HBoxContainer
			var owner_patch_node := (header.get_node("OwnerPatch") if header != null else content.get_node("OwnerPatch")) as LiveRunCardRewardChoicePanel._OwnerPatch
			var cost_btn := content.get_node("CostButton") as LiveRunCardRewardChoicePanel._CostButton
			var pips := content.get_node("PositionPips") as LiveRunCardRewardChoicePanel._PositionPips
			var owner_name := (header.get_node_or_null("OwnerPatch/OwnerLabel") if header != null else content.get_node_or_null("OwnerPatch/OwnerLabel")) as Label
			ui.append([owner_patch_node.owner_color if owner_patch_node != null else Color.WHITE,
				owner_name.text if owner_name != null else "",
				content.get_node("NameLabel").text,
				content.get_node("RarityLabel").text,
				cost_btn.cost_value if cost_btn != null else -1,
				content.get_node("RulesLabel").text,
				pips.from_positions if pips != null else [],
				pips.to_positions if pips != null else [],
				pips.target_kind if pips != null else ""])
		independent.append(ui)
		buttons[0].pressed.emit()
		_check(requests.size() == 1 and requests[0] == {"node": "same_node",
			"card": base["offers"][0]["id"]}, "fresh presentation emits one current request")
		panel.acknowledge(true)
		panel.close_rewards()
		requests.clear()
		if pass_index == 1:
			await _frames()
	_check(independent.size() == 2 and independent[0] == independent[1],
		"two independent seeded presentations produce identical full card text")


## A genuine prepared receipt whose offers come from the routed weighted path.
func _prepared_pool(is_elite: bool, seed_value: int) -> Dictionary:
	var party := CombatParty.new(_defs(HEROES))
	var enemies := CombatEnemies.new(_defs(ENEMIES))
	_check(party.is_valid() and enemies.is_valid(), "authored living battle rosters for pool receipt")
	var result := CombatBattleResult.new(party, enemies)
	for slot in range(1, enemies.get_enemies().size() + 1):
		_check(enemies.apply_damage(slot, enemies.get_enemy(slot).get("hp", 0)),
			"pool receipt enemy killed")
	_check(result.evaluate() == CombatBattleResult.VICTORY, "pool receipt witnessed victory")
	var deck: Array[String] = StarterCards.new().get_starting_deck()
	var owners: Array[String] = ["warden", "seamstress", "tinker"]
	var records: Array = RunPoolCardRewardOffers.get_authored_base_candidates()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var service := RunFightVictoryRewards.new(result, rng, owners, records, deck, 97,
		is_elite, ["button_charm", "thread_token"], ["button_charm"])
	var receipt := service.prepare()
	_check(receipt.get("ok", false) and (receipt.get("offers", []) as Array).size() == 3,
		"weighted pool receipt prepares three distinct offers")
	for offer: Dictionary in receipt.get("offers", []):
		var definition := _base_pool_definition(String(offer.get("id", "")))
		_check(not definition.is_empty() and definition.get("owner") == offer.get("owner"),
			"weighted receipt offer resolves in its authored base pool: " + String(offer.get("id", "")))
	return {"receipt": receipt, "service": service, "rng": rng, "deck": deck}


## Direct catalog lookup for every reward-eligible D2-1 base card.
func _base_pool_definition(card_id: String) -> Dictionary:
	var warden := WardenPoolCards.new()
	if warden.get_base_ids().has(card_id):
		return warden.get_definition(card_id)
	var seamstress := SeamstressPoolCards.new()
	if seamstress.get_base_ids().has(card_id):
		return seamstress.get_definition(card_id)
	var tinker := TinkerPoolCards.new()
	if tinker.get_pool_card_ids().has(card_id):
		return tinker.get_definition(card_id)
	return {}


func _authored_base_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.append_array(WardenPoolCards.new().get_base_ids())
	ids.append_array(SeamstressPoolCards.new().get_base_ids())
	ids.append_array(TinkerPoolCards.new().get_pool_card_ids())
	return ids


## Independent copy of the documented preview contract, written from the
## authored catalog semantics for EVERY target kind and base-pool effect key.
## It intentionally does not call the panel formatter or its helpers, so a
## formatter that drops authored metadata cannot agree with this oracle.
func _expected_rules(definition: Dictionary) -> String:
	var kind: String = String(definition.get("target_kind", ""))
	var effects: Dictionary = definition.get("effects", {})
	var hits: int = 1
	if effects.get("hits") is int:
		hits = maxi(1, int(effects["hits"]))
	elif effects.get("hit_count") is int:
		hits = maxi(1, int(effects["hit_count"]))
	var random_each: bool = bool(effects.get("random_target_each_hit", false))
	var sentences: Array[String] = []
	# One combat sentence for damage, statuses, Unravel and Pin.
	var enemy_keys := ["damage", "conditional_damage", "exposed", "weak", "bleed",
		"unravel", "bleed_multiplier", "pinned"]
	var has_enemy := false
	for key: String in enemy_keys:
		if effects.has(key):
			has_enemy = true
	if has_enemy:
		var object_suffix: String = _sentence_object_suffix(definition)
		var clauses: Array[String] = []
		var damage := ""
		if effects.has("damage"):
			damage = "deal %d" % int(effects["damage"])
			if hits > 1:
				damage += " x%d" % hits
			damage += ", random" if random_each else object_suffix
		if effects.has("conditional_damage"):
			var condition: Dictionary = effects["conditional_damage"] \
				if effects["conditional_damage"] is Dictionary else {}
			var empowered: int = int(condition.get("damage", -1))
			if damage.is_empty():
				damage = "deal %d%s%s if %s" % [empowered, "" if random_each else object_suffix,
					", random" if random_each else "", _condition_terms(condition)]
			else:
				damage += ", or %d if %s" % [empowered, _condition_terms(condition)]
		if not damage.is_empty():
			clauses.append(damage)
		var statuses: Array[String] = []
		for status: String in ["exposed", "weak", "bleed"]:
			if effects.has(status):
				statuses.append("%s %d" % [status.capitalize(), int(effects[status])])
		if not statuses.is_empty():
			clauses.append(", ".join(statuses) + object_suffix)
		if effects.has("unravel"):
			clauses.append("unravel %d%s" % [int(effects["unravel"]), object_suffix])
		if effects.has("pinned"):
			# The face names the keyword; the +5 and its different-owner rule
			# belong to the Help glossary, not to the short sentence.
			clauses.append("pin%s" % object_suffix)
		for clause: String in clauses:
			sentences.append(_sentence_capital(clause) + ".")
		if effects.has("bleed_multiplier"):
			var multiplier: int = int(effects["bleed_multiplier"])
			if multiplier == 2:
				sentences.append("Double Bleed%s." % object_suffix)
			else:
				sentences.append("Multiply Bleed x%d%s." % [multiplier, object_suffix])
	# A descriptor heal names its own recipient instead of the cast's target.
	if effects.get("heal") is Dictionary:
		var heal: Dictionary = effects["heal"]
		var who := "weakest ally" \
			if String(heal.get("target", "")) == "weakest_living_ally" else _sentence_recipient(definition)
		var sentence := "Heal %s %d HP" % [who, int(heal.get("amount", -1))]
		if String(heal.get("cap", "")) == "missing_hp":
			sentence += " (up to missing HP)"
		sentences.append(sentence + ".")
	if kind == "ally_single":
		var clauses: Array[String] = []
		var healed := false
		if effects.get("heal") is int:
			clauses.append("heal ally %d HP" % int(effects["heal"]))
			healed = true
		if effects.has("block"):
			clauses.append(("grant %d Block" % int(effects["block"])) if healed
				else ("ally gains %d Block" % int(effects["block"])))
		if not clauses.is_empty():
			sentences.append(_sentence_capital(_sentence_join(clauses)) + ".")
	if kind == "party_all":
		var clauses: Array[String] = []
		if effects.get("heal") is int:
			clauses.append("heal all allies %d HP" % int(effects["heal"]))
		if effects.has("block_all"):
			clauses.append("all allies gain %d Block" % int(effects["block_all"]))
		if not clauses.is_empty():
			sentences.append(_sentence_capital(_sentence_join(clauses)) + ".")
	# Self-directed effects and other-ally Block keep separate compact clauses.
	var self_clauses: Array[String] = []
	if effects.has("block") and kind != "ally_single":
		self_clauses.append("gain %d Block" % int(effects["block"]))
	if effects.has("other_ally_block"):
		self_clauses.append("other allies gain %d Block" % int(effects["other_ally_block"]))
	if effects.has("draw"):
		var drawn: int = int(effects["draw"])
		self_clauses.append("draw %d" % drawn)
	if effects.has("gain_energy"):
		self_clauses.append("gain %d energy" % int(effects["gain_energy"]))
	elif effects.has("energy"):
		self_clauses.append("gain %d energy" % int(effects["energy"]))
	if effects.has("next_turn_energy"):
		self_clauses.append("gain %d energy next turn" % int(effects["next_turn_energy"]))
	if effects.has("next_attack_damage_bonus"):
		var timing := " this turn" \
			if String(effects.get("expires", "")) == "end_of_player_turn" else ""
		self_clauses.append("your next attack%s deals +%d damage"
			% [timing, int(effects["next_attack_damage_bonus"])])
	if effects.has("self_hp_loss"):
		self_clauses.append("lose %d HP" % int(effects["self_hp_loss"]))
	if effects.has("guarding"):
		self_clauses.append("Guard")
	if effects.has("thorns"):
		self_clauses.append("gain %d Thorns" % int(effects["thorns"]))
	if not self_clauses.is_empty():
		for clause: String in self_clauses:
			sentences.append(_sentence_capital(clause) + ".")
	return " ".join(sentences)


## The recipient the face sentence names for one authored target kind.
func _sentence_recipient(definition: Dictionary) -> String:
	match str(definition.get("target_kind", "")):
		"enemy_single": return "one enemy"
		"enemy_all": return "every enemy"
		"enemy_random": return "a random enemy"
		"ally_single": return "a chosen ally"
		"party_all": return "every ally"
		"self": return "yourself"
	return "the target"


## The compact object a face clause carries: an area cast says "to all", a
## random cast names its random enemy, and a single enemy needs no wording.
func _sentence_object_suffix(definition: Dictionary) -> String:
	match str(definition.get("target_kind", "")):
		"enemy_single": return ""
		"enemy_all": return " to all"
		"enemy_random": return " to a random enemy"
		"ally_single": return " to a chosen ally"
		"party_all": return " to every ally"
		"self": return " to yourself"
	return " to the target"


func _condition_terms(condition: Dictionary) -> String:
	var terms: Array[String] = []
	for item: Variant in condition.get("conditions", []):
		if not item is Dictionary:
			continue
		var part: Dictionary = item
		if str(part.get("status", "")) == "unravelled":
			if not terms.has("Unravelled"):
				terms.append("Unravelled")
		elif str(part.get("gauge", "")) == "unravel" \
				and str(part.get("comparison", "")) == "at_least_half":
			if not terms.has("half gauge"):
				terms.append("half gauge")
	if terms.is_empty():
		return "an unstated condition"
	var joiner := " and " if String(condition.get("operator", "or")) == "and" else " or "
	return joiner.join(terms)


func _sentence_join(parts: Array[String]) -> String:
	if parts.is_empty():
		return ""
	if parts.size() == 1:
		return parts[0]
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts.back()


func _sentence_capital(text: String) -> String:
	if text.is_empty():
		return text
	return text.substr(0, 1).to_upper() + text.substr(1)


## Structural qualifier keys that never render their own clause; every other
## authored effect key must produce one, and the oracle above must cover it.
func _covered_effect_keys() -> Array[String]:
	return ["damage", "block", "block_all", "other_ally_block", "heal", "draw", "weak",
		"bleed", "bleed_multiplier", "unravel", "exposed", "pinned", "guarding", "thorns",
		"energy", "gain_energy", "self_hp_loss", "conditional_damage", "hits", "hit_count",
		"random_target_each_hit", "rng_source", "living_targets_only", "duration"]


## Explicit authored phrases the mounted preview must show, so a shared
## omission in formatter and oracle cannot pass unnoticed.
func _required_rule_phrases(card_id: String) -> Array[String]:
	match card_id:
		"warden_bastion_quilt":
			return ["All allies gain 10 Block"]
		"warden_hold_the_line":
			return ["Other allies gain 2 Block"]
		"seamstress_darning":
			return ["Heal ally 4 HP", "grant 3 Block"]
		"seamstress_stitch_up":
			return ["Ally gains 5 Block"]
		"tinker_sight_glass":
			return ["Exposed 2", "Draw 1"]
		"seamstress_red_thread":
			return ["Bleed 6", "Exposed 1"]
		"tinker_overclock":
			return ["Gain 1 energy", "Lose 3 HP"]
		"tinker_ricochet":
			return ["Deal 4 x3, random"]
	return []


## The mounted card must show the real authored pool card it resolves to.
func _validate_pool(receipt: Dictionary, kind: String, node_id: String) -> void:
	_check_reward_typography(receipt)
	_check(panel.has_open_rewards() and panel.is_visible_in_tree(), "pool reward mounted: " + kind)
	_check(panel.title_label.text.contains(kind), "pool title contains kind: " + kind)
	_check(not panel.title_label.text.contains(node_id) and not panel.title_label.text.contains("_"),
		"pool title is human-readable without raw node ID: " + kind)
	_check(panel.gold_label.text == "Pending gold: +%d" % receipt["gold_award"],
		"exact prepared pool pending gold visible: " + kind)
	_check(panel.trinket_label.visible == (kind == "Elite"), "Elite-only pool trinket label visibility")
	if kind == "Elite":
		_check(panel.trinket_label.text.contains("Thread Token"), "human-readable pool patch name visible: " + kind)
		_check(not panel.trinket_label.text.contains(receipt["trinket_drop_id"]) and not panel.trinket_label.text.contains("_"),
			"pool patch label does not expose raw trinket identifier or underscore")
	else:
		_check(panel.trinket_label.text.is_empty(), "non-Elite pool trinket label is empty")
	var actions := panel.get_choice_buttons()
	_check(actions.size() == 4 and panel.choices_container.get_child_count() == 3,
		"pool reward shows three genuine cards and Skip")
	if actions.size() != 4:
		return
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	for index in range(3):
		var offer: Dictionary = receipt["offers"][index]
		var card_id := String(offer.get("id", ""))
		var owner := String(offer.get("owner", ""))
		var definition := _base_pool_definition(card_id)
		_check(not definition.is_empty() and definition.get("owner") == owner,
			"prepared pool offer backed by its authored catalog: " + card_id)
		if definition.is_empty():
			continue
		_check(_authored_base_ids().has(card_id) and not card_id.ends_with("_plus"),
			"only reward-eligible base pool cards are offered: " + card_id)
		var card := panel.choices_container.get_child(index) as PanelContainer
		_check(card != null and card.name == "Card_%d" % index, "stable pool card index")
		if card == null:
			continue
		var content := card.get_node("CardMargin/CardContent") as VBoxContainer
		var header := content.get_node_or_null("CardHeader") as HBoxContainer
		var owner_patch := (header.get_node("OwnerPatch") as Control) if header != null else (content.get_node("OwnerPatch") as Control)
		var name_label := content.get_node("NameLabel") as Label
		var rarity_label := content.get_node("RarityLabel") as Label
		var cost_button := content.get_node("CostButton") as Control
		var pips_container := content.get_node("PositionPips") as Control
		var rules_label := content.get_node("RulesLabel") as Label
		var action := content.get_node("ChooseButton") as Button
		_check(action == actions[index], "real pool action bound to card " + str(index))
		_check(cost_button != null and (cost_button as LiveRunCardRewardChoicePanel._CostButton).cost_value == definition.get("cost", 0),
			"exact pool cost value matches authored definition (including 0): " + card_id)
		_check(name_label.text == definition["display_name"],
			"exact pool authored display name: " + card_id)
		_check(owner_patch != null
			and (owner_patch as LiveRunCardRewardChoicePanel._OwnerPatch).owner_color == panel.OWNER_COLORS.get(owner, Color.WHITE),
			"pool author patch color matches owner's palette: " + card_id)
		_check_owner_strip(receipt, index)
		_check(pips_container != null
			and (pips_container as LiveRunCardRewardChoicePanel._PositionPips).from_positions == definition.get("from_positions", [])
			and (pips_container as LiveRunCardRewardChoicePanel._PositionPips).to_positions == definition.get("to_positions", [])
			and (pips_container as LiveRunCardRewardChoicePanel._PositionPips).target_kind == String(definition.get("target_kind", "")),
			"pool position/target pips match catalog definition: " + card_id)
		if cost_button != null and pips_container != null:
			_check_cost_coin(cost_button as LiveRunCardRewardChoicePanel._CostButton,
				definition, card_id)
			_check_position_marks(pips_container as LiveRunCardRewardChoicePanel._PositionPips,
				definition, card_id)
		var expected_line: String = _expected_rules(definition)
		_check(not expected_line.is_empty() and rules_label.text == expected_line,
			"pool card rules match its authored catalog definition: " + card_id)
		var expected_rarity: String = String(definition.get("rarity", "")).capitalize()
		_check(rarity_label != null and rarity_label.visible and rarity_label.text == expected_rarity,
			"RarityLabel matches authored rarity: %s (%s)" % [expected_rarity, card_id])
		var sewn_box := rarity_label.get_theme_stylebox("normal") as StyleBoxFlat
		_check(sewn_box != null and sewn_box.border_width_left >= 1,
			"RarityLabel has visible sewn accent border: " + card_id)
		_check(sewn_box != null and sewn_box.border_color != panel.OWNER_COLORS[owner],
			"RarityLabel sewn border color distinguishable from owner: " + card_id)
		_check(sewn_box != null and sewn_box.bg_color != panel.OWNER_COLORS[owner],
			"RarityLabel sewn tag color distinguishable from owner: " + card_id)
		_assert_no_raw_identifiers(card, card_id, node_id, receipt.get("trinket_drop_id", ""))
		_check(rules_label.text == _expected_rules(definition),
			"pool card rules match its authored catalog definition: " + card_id)
		_check(rules_label.text == CardShortRules.line(definition),
			"pool card face comes from the one shared formatter: " + card_id)
		_check(not rules_label.text.contains("\n") and rules_label.text.strip_edges() != "",
			"pool card shows one nonblank short-sentence effect line: " + card_id)
		_check(rules_label.text.ends_with(".")
			and rules_label.text.substr(0, 1) == rules_label.text.substr(0, 1).to_upper(),
			"pool card effect line is a complete sentence: " + card_id)
		_assert_no_position_prose(rules_label.text, card_id)
		_check(card.tooltip_text == _expected_legend(definition),
			"pool card hover states the exact source and recipient slots: " + card_id)
		_check(card.mouse_filter == Control.MOUSE_FILTER_STOP
			and not card.tooltip_text.is_empty(),
			"pool card hover legend is reachable beside its action: " + card_id)
		var effects: Dictionary = definition.get("effects", {})
		for effect_key: String in effects:
			_check(_covered_effect_keys().has(effect_key),
				"authored pool effect key is rendered: %s (%s)" % [effect_key, card_id])
			var value: Variant = effects[effect_key]
			# A doubled Bleed is printed as the word "Double", never as a bare 2.
			if value is int and effect_key != "bleed_multiplier":
				_check(rules_label.text.contains(str(value)),
					"authored pool value %d visible for %s" % [int(value), card_id])
		for phrase: String in _required_rule_phrases(card_id):
			_check(rules_label.text.contains(phrase),
				"authored rule phrase '%s' visible for %s" % [phrase, card_id])
		_check(rules_label.get_visible_line_count() == rules_label.get_line_count()
			and rules_label.get_theme_font_size("font_size") >= 15,
			"pool rules fully rendered and readable: " + card_id)
		_check(card.get_global_rect().encloses(rules_label.get_global_rect())
			and screen.encloses(rules_label.get_global_rect())
			and screen.encloses(card.get_global_rect()) and screen.encloses(action.get_global_rect()),
			"pool card, rules and action fit the card and 1280x720 viewport: " + card_id)
		for control: Control in [owner_patch, name_label, rarity_label, cost_button, pips_container, rules_label]:
			_check(card.get_global_rect().encloses(control.get_global_rect())
				and screen.encloses(control.get_global_rect()),
				"pool control stays visible on the card and in 1280x720: " + card_id)
		var style := card.get_theme_stylebox("panel") as StyleBoxFlat
		_check(style != null and style.border_color == panel.OWNER_COLORS[owner],
			"authored pool owner palette visible: " + card_id)
	_check(actions[3] == panel.skip_button and actions[3].text.contains("Skip"),
		"fourth pool action is Skip, never a card")
	_check(screen.encloses(panel.skip_button.get_global_rect())
		and panel.skip_button.is_visible_in_tree() and not panel.skip_button.disabled,
		"pool Skip control stays visible in 1280x720")


func _exercise_pool(fixture: Dictionary, kind: String) -> void:
	var node_id := "floor_02_elite" if kind == "Elite" else "floor_01_fight"
	var receipt: Dictionary = fixture["receipt"]
	var prepared_before: Dictionary = fixture["service"].prepare()
	var rng_state: int = fixture["rng"].state
	requests.clear()
	_check(panel.open_rewards(node_id, kind, receipt), kind + " weighted receipt opens the real panel")
	await _frames()
	_validate_pool(receipt, kind, node_id)
	for slot in range(3):
		var art := panel.choices_container.get_child(slot).get_node(
			"CardMargin/CardContent/CardArt") as LiveRunCardRewardChoicePanel._CardIllustration
		_check(art != null, kind + " authentic pool offer mounts an illustration")
		if art == null:
			continue
		var offer: Dictionary = receipt["offers"][slot]
		var resolved := LiveRunCardRewardChoicePanel.resolve_card_art(offer["id"], offer["owner"])
		_check(art.picture == resolved["texture"] and art.mode == resolved["mode"],
			kind + " authentic pool offer uses the real art lookup")
		if art.is_emblem():
			_check_emblem_felt(art, kind + " authentic " + String(offer["id"]))
	var actions := panel.get_choice_buttons()
	if actions.size() != 4:
		panel.close_rewards()
		return
	await _test_focus_navigation(actions, kind + " pool")
	# Full-card click on a pool card label routes through the same guard.
	requests.clear()
	var pool_card := panel.choices_container.get_child(0) as PanelContainer
	var pool_name := pool_card.get_node("CardMargin/CardContent/NameLabel") as Label
	await _click(pool_name)
	_check(requests == [{"node": node_id, "card": receipt["offers"][0]["id"]}],
		"pool full-card label click requests exact offer once")
	panel.acknowledge(false)
	_check(actions.all(func(button: Button) -> bool: return not button.disabled),
		"pool rejection re-enables after full-card click")
	requests.clear()
	var target: int = 1 if kind == "Fight" else 2
	await _mouse(actions[target])
	_check(requests == [{"node": node_id, "card": receipt["offers"][target]["id"]}],
		"physical mouse pick requests exactly the weighted pool ID")
	panel.acknowledge(false)
	_check(actions.all(func(button: Button) -> bool: return not button.disabled),
		"rejection re-enables the same pool offers")
	_validate_pool(receipt, kind, node_id)
	actions[3].grab_focus()
	await _frames()
	_check(actions[3].has_focus(), "pool Skip focused before Space")
	await _key(KEY_SPACE)
	_check(requests.size() == 2 and requests[1] == {"node": node_id, "card": ""},
		"physical keyboard Skip requests the empty skip ID once")
	panel.acknowledge(true)
	_check(panel._accepted, "accepted pool claim stays latched")
	for button in actions:
		_check(button.disabled, "accepted pool claim locks every action")
	_check(fixture["service"].prepare() == prepared_before and fixture["rng"].state == rng_state,
		"panel never rerolls or settles the weighted reward transaction")
	panel.close_rewards()
	await _frames()
	_check(not panel.has_open_rewards() and panel.get_choice_buttons().is_empty(),
		"weighted pool reward closes cleanly")


func _test_pool_replay(first: Dictionary) -> void:
	var second := _prepared_pool(false, 18203)
	_check(second["receipt"].get("offers") == first["receipt"].get("offers"),
		"same seeded stream prepares identical weighted pool offers")
	var presentations: Array = []
	for fixture in [first, second]:
		_check(panel.open_rewards("replay_node", "Fight", fixture["receipt"]),
			"seeded weighted receipt reopens")
		await _frames()
		_check_reward_typography(fixture["receipt"])
		var ui: Array = []
		for index in range(3):
			var content := panel.choices_container.get_child(index).get_node("CardMargin/CardContent")
			var header := content.get_node_or_null("CardHeader") as HBoxContainer
			var owner_patch_node := (header.get_node("OwnerPatch") if header != null else content.get_node("OwnerPatch")) as LiveRunCardRewardChoicePanel._OwnerPatch
			var cost_btn := content.get_node("CostButton") as LiveRunCardRewardChoicePanel._CostButton
			var pips := content.get_node("PositionPips") as LiveRunCardRewardChoicePanel._PositionPips
			var owner_name := (header.get_node_or_null("OwnerPatch/OwnerLabel") if header != null else content.get_node_or_null("OwnerPatch/OwnerLabel")) as Label
			ui.append([owner_patch_node.owner_color if owner_patch_node != null else Color.WHITE,
				owner_name.text if owner_name != null else "",
				content.get_node("NameLabel").text,
				content.get_node("RarityLabel").text,
				cost_btn.cost_value if cost_btn != null else -1,
				content.get_node("RulesLabel").text,
				pips.from_positions if pips != null else [],
				pips.to_positions if pips != null else [],
				pips.target_kind if pips != null else ""])
		presentations.append(ui)
		panel.close_rewards()
		await _frames()
	_check(presentations.size() == 2 and presentations[0] == presentations[1],
		"same-seed weighted receipts present identical pool card text")


## Every authored reward-eligible base card must mount, while upgrades and
## mislabelled/unknown pool-shaped IDs stay rejected.
func _test_all_pool_cards(base: Dictionary) -> void:
	var ids := _authored_base_ids()
	_check(ids.size() >= 3, "authored reward pools expose base cards")
	# The three defect cards must really be mounted by the loop below.
	for required in ["warden_bastion_quilt", "tinker_overclock", "tinker_ricochet"]:
		_check(ids.has(required), "defect card is an authored reward-eligible base card: " + required)
	requests.clear()
	for offset in range(0, ids.size(), 3):
		var receipt := base.duplicate(true)
		for slot in range(3):
			var card_id: String = ids[(offset + slot) % ids.size()]
			receipt["offers"][slot] = {"id": card_id,
				"owner": String(_base_pool_definition(card_id).get("owner", ""))}
		var before := receipt.duplicate(true)
		_check(panel.open_rewards("pool_preview", "Fight", receipt),
			"authored base pool cards mount " + str(offset))
		if not panel.has_open_rewards():
			continue
		await _frames()
		_validate_pool(receipt, "Fight", "pool_preview")
		_check(receipt == before, "pool preview leaves its receipt intact " + str(offset))
		panel.close_rewards()
		await _frames()
	for plus_id in ["warden_hold_the_line_plus", "seamstress_needle_pin_plus", "tinker_rivet_shot_plus"]:
		var owner := String(_base_pool_definition(plus_id.trim_suffix("_plus")).get("owner", ""))
		var receipt := base.duplicate(true)
		receipt["offers"][0] = {"id": plus_id, "owner": owner}
		_check(not panel.open_rewards("pool_preview", "Fight", receipt),
			"pool upgrade is never a reward offer: " + plus_id)
		_check(not panel.visible and not panel.has_open_rewards(),
			"rejected pool upgrade mounts no controls: " + plus_id)
	var mislabelled := base.duplicate(true)
	mislabelled["offers"][1] = {"id": "warden_hold_the_line", "owner": "tinker"}
	_check(not panel.open_rewards("pool_preview", "Fight", mislabelled),
		"pool offer with a wrong owner rejects")
	var foreign := base.duplicate(true)
	foreign["offers"][2] = {"id": "warden_bogus_pool_card", "owner": "warden"}
	_check(not panel.open_rewards("pool_preview", "Fight", foreign),
		"unknown pool-shaped ID rejects instead of resolving")
	_check(requests.is_empty(), "pool mount suite never emits a request")



func _assert_no_raw_identifiers(card_panel: PanelContainer, card_id: String, node_id: String, trinket_id: String) -> void:
	var labels: Array[Label] = [panel.title_label, panel.gold_label, panel.trinket_label]
	var content := card_panel.get_node("CardMargin/CardContent")
	for child in content.get_children():
		if child is Label:
			labels.append(child)
		# Nested labels (the sewn owner strip's hero name) are player-visible too.
		for grandchild in child.get_children():
			if grandchild is Label:
				labels.append(grandchild)
	for label: Label in labels:
		if label.visible and not label.text.is_empty():
			_check(not label.text.contains(card_id),
				"visible label %s never contains raw card id %s" % [label.name, card_id])
			_check(not label.text.contains(node_id),
				"visible label %s never contains raw node id %s" % [label.name, node_id])
			if not trinket_id.is_empty():
				_check(not label.text.contains(trinket_id),
					"visible label %s never contains raw trinket id %s" % [label.name, trinket_id])


func _test_three_tier_rarities(base: Dictionary) -> void:
	var common_cand := {}
	var uncommon_cand := {}
	var rare_cand := {}
	for cand in RunPoolCardRewardOffers.get_authored_base_candidates():
		var r: String = cand.get("rarity", "")
		var o: String = cand.get("owner", "")
		if r == "common" and o == "warden" and common_cand.is_empty():
			common_cand = cand
		elif r == "uncommon" and o == "tinker" and uncommon_cand.is_empty():
			uncommon_cand = cand
		elif r == "rare" and o == "seamstress" and rare_cand.is_empty():
			rare_cand = cand
	_check(not common_cand.is_empty() and not uncommon_cand.is_empty() and not rare_cand.is_empty(),
		"authored catalog provides distinct candidates across all three rarities and heroes")
	if common_cand.is_empty() or uncommon_cand.is_empty() or rare_cand.is_empty():
		return

	var receipt: Dictionary = base.duplicate(true)
	receipt["offers"] = [
		{"id": common_cand["id"], "owner": common_cand["owner"]},
		{"id": uncommon_cand["id"], "owner": uncommon_cand["owner"]},
		{"id": rare_cand["id"], "owner": rare_cand["owner"]},
	]
	var node_id := "floor_01_fight"
	requests.clear()
	_check(panel.open_rewards(node_id, "Fight", receipt), "three-tier rarity receipt mounts successfully")
	await _frames()
	_validate_pool(receipt, "Fight", node_id)

	var expected_tiers := ["Common", "Uncommon", "Rare"]
	var card_cands := [common_cand, uncommon_cand, rare_cand]
	for i in range(3):
		var card := panel.choices_container.get_child(i) as PanelContainer
		var content := card.get_node("CardMargin/CardContent") as VBoxContainer
		var rarity_label := content.get_node("RarityLabel") as Label
		_check(rarity_label != null and rarity_label.visible and rarity_label.text == expected_tiers[i],
			"card %d displays exact stitched rarity %s" % [i, expected_tiers[i]])
		var sewn_box := rarity_label.get_theme_stylebox("normal") as StyleBoxFlat
		_check(sewn_box != null and sewn_box.border_width_left >= 1,
			"card %d rarity has visible sewn accent border" % i)
		_check(sewn_box != null and sewn_box.bg_color == panel.RARITY_COLORS[card_cands[i]["rarity"]],
			"card %d rarity tag uses distinct palette" % i)

	var buttons := panel.get_choice_buttons()
	await _mouse(buttons[2])
	_check(requests == [{"node": node_id, "card": rare_cand["id"]}],
		"physical click emits exact opaque node_id and rare card_id")
	panel.acknowledge(true)
	panel.close_rewards()
	await _frames()


## The illustration window's own drawing contract, read from the mounted control:
## the source region is painted without stretching, centred, and
## entirely inside the sewn window it is mounted in.
func _check_picture_geometry(art: LiveRunCardRewardChoicePanel._CardIllustration,
		card_id: String) -> void:
	var texture: Texture2D = art.picture
	_check(texture != null, "mounted art binds a real texture: " + card_id)
	if texture == null:
		return
	var texture_size: Vector2 = texture.get_size()
	_check(texture_size.x > 0.0 and texture_size.y > 0.0,
		"bound texture reports a real size: " + card_id)
	var rect: Rect2 = art.picture_rect()
	var window := Rect2(Vector2.ZERO, art.size)
	_check(art.size.x > 0.0 and art.size.y >= LiveRunCardRewardChoicePanel.CARD_ART_HEIGHT,
		"illustration window keeps its readable minimum height: " + card_id)
	_check(rect.size.x > 0.0 and rect.size.y > 0.0 and window.encloses(rect),
		"picture is painted inside its sewn window: " + card_id)
	var source: Rect2 = art.picture_source_rect()
	_check(source.size.x > 0.0 and source.size.y > 0.0,
		"picture has a nonempty source region: " + card_id)
	if source.size.x <= 0.0 or source.size.y <= 0.0:
		return
	_check(Rect2(Vector2.ZERO, texture_size).encloses(source),
		"source crop stays inside texture bounds: " + card_id)
	_check(source.get_center().is_equal_approx(texture_size * 0.5),
		"source crop is centred on the authored picture: " + card_id)
	_check(absf(rect.size.x / rect.size.y - source.size.x / source.size.y) <= 0.001
		and is_equal_approx(rect.size.x / source.size.x, rect.size.y / source.size.y),
		"source maps to destination with equal scale on both axes: " + card_id)
	_check(absf(rect.get_center().x - window.get_center().x) <= 1.0
		and absf(rect.get_center().y - window.get_center().y) <= 1.0,
		"picture is centred in its sewn window: " + card_id)
	if art.is_card_art():
		var drawable: Rect2 = window.grow(-8.0)
		_check(rect.size.x >= drawable.size.x * 0.9
			and rect.size.y >= drawable.size.y * 0.9 and rect.is_equal_approx(drawable),
			"authored picture covers both axes of the sewn inset: " + card_id)
		var expected_scale := maxf(drawable.size.x / texture_size.x, drawable.size.y / texture_size.y)
		_check(is_equal_approx(rect.size.x / source.size.x, expected_scale)
			and source.size.is_equal_approx(drawable.size / expected_scale),
			"cover uses the largest centered source crop at uniform scale: " + card_id)
		var backing := art.sewn_backing_rect()
		_check(backing == window and backing.encloses(rect)
			and backing.size.is_equal_approx(rect.size + Vector2(16, 16)),
			"sewn backing frames the full illustration inset: " + card_id)
	else:
		_check(source == Rect2(Vector2.ZERO, texture_size),
			"contained emblem preserves its entire source picture: " + card_id)


## The hero emblem fills a broad owner-felt patch rather than a tiny disc.
func _check_emblem_felt(art: LiveRunCardRewardChoicePanel._CardIllustration,
		card_id: String) -> void:
	_check(art.mode == LiveRunCardRewardChoicePanel._CardIllustration.MODE_EMBLEM
		and art.is_emblem() and not art.is_card_art() and art.has_picture(),
		"emblem fallback mounts in distinct felt mode: " + card_id)
	_check(art.owner_color != Color.WHITE, "owner felt colour: " + card_id)
	var window := Rect2(Vector2.ZERO, art.size)
	var backing: Rect2 = art.emblem_backing_rect()
	_check(window.encloses(backing) and backing.size.x >= window.size.x * 0.9
		and backing.size.y >= window.size.y * 0.85,
		"felt spans the window rather than a tiny medallion: " + card_id)
	_check(backing.get_center().distance_to(window.get_center()) <= 0.5,
		"felt backing is centred: " + card_id)
	_check(art.picture != null, "backdrop has an emblem texture: " + card_id)
	if art.picture == null:
		return
	var texture_size := art.picture.get_size()
	var destination := art.emblem_backdrop_rect()
	var source := art.emblem_backdrop_source_rect()
	var inset := window.grow(-8.0)
	_check(destination.size.x > 0.0 and destination.size.y > 0.0
		and window.encloses(destination) and destination == backing
		and destination.size.x >= inset.size.x * 0.9
		and destination.size.y >= inset.size.y * 0.9,
		"emblem-derived backdrop fills both inset axes: " + card_id)
	_check(source.size.x > 0.0 and source.size.y > 0.0,
		"backdrop uses a nonempty crop: " + card_id)
	if source.size.x <= 0.0 or source.size.y <= 0.0:
		return
	_check(Rect2(Vector2.ZERO, texture_size).encloses(source)
		and source.get_center().is_equal_approx(texture_size * 0.5)
		and destination.get_center().is_equal_approx(window.get_center()),
		"backdrop crop is legal and centered: " + card_id)
	var expected_scale := maxf(destination.size.x / texture_size.x,
		destination.size.y / texture_size.y)
	_check(is_equal_approx(destination.size.x / source.size.x, expected_scale)
		and is_equal_approx(destination.size.y / source.size.y, expected_scale)
		and source.size.is_equal_approx(destination.size / expected_scale),
		"backdrop uses maximal cover crop with uniform scale: " + card_id)
	_check_picture_geometry(art, card_id)
	var rect: Rect2 = art.picture_rect()
	var inner: Rect2 = backing.grow(-art.EMBLEM_INSET)
	_check(inner.encloses(rect),
		"whole emblem stays within the sewn felt inset: " + card_id)
	_check(rect.size.x >= inner.size.x * 0.9 or rect.size.y >= inner.size.y * 0.9,
		"emblem fills a generous axis of its patch: " + card_id)
	_check(art.EMBLEM_INSET > 4.0 and art.FELT_INSET > 0.0,
		"seams lie outside the emblem: " + card_id)


## The reward face must bind the canonical individual card art (cards/art/
## <base_id>.png), fall back to the hero emblem and then a drawn patch, and keep
## that illustration in its own inert window above a legible plain name strip.
func _test_illustration_art(base: Dictionary, kind: String) -> void:
	for starter in ["warden_strike", "seamstress_prick", "tinker_pop_shot"]:
		_check(LiveRunCardRewardChoicePanel.card_art_path(starter)
			== "res://assets/paper/cards/art/%s.png" % starter,
			"canonical individual art path for " + starter)
	for plus_id in ["warden_strike_plus", "seamstress_mend_plus"]:
		var base_id: String = plus_id.trim_suffix("_plus")
		_check(LiveRunCardRewardChoicePanel.card_art_path(plus_id)
			== LiveRunCardRewardChoicePanel.card_art_path(base_id)
			and LiveRunCardRewardChoicePanel.card_art_path(plus_id)
			== "res://assets/paper/cards/art/%s.png" % base_id,
			"upgrade resolves its base picture: " + plus_id)
	for owner in ["warden", "seamstress", "tinker"]:
		_check(LiveRunCardRewardChoicePanel.emblem_path(owner)
			== "res://assets/paper/cards/emblem_%s.png" % owner,
			"hero emblem fallback path for " + owner)
	var ids := ["warden_strike", "seamstress_prick", "tinker_pop_shot"]
	var catalog := StarterCards.new()
	var receipt := base.duplicate(true)
	for slot in range(3):
		var definition := catalog.get_definition(ids[slot])
		_check(not definition.is_empty(), "illustration case is an authored card: " + ids[slot])
		receipt["offers"][slot] = {"id": ids[slot],
			"owner": String(definition.get("owner", ""))}
	var before := receipt.duplicate(true)
	requests.clear()
	_check(panel.open_rewards("art_preview", kind, receipt),
		"illustration receipt mounts through the real panel")
	if not panel.has_open_rewards():
		return
	await _frames()
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	for slot in range(3):
		var card_id: String = ids[slot]
		var definition := catalog.get_definition(card_id)
		var card := panel.choices_container.get_child(slot) as PanelContainer
		var content := card.get_node("CardMargin/CardContent") as VBoxContainer
		var art := content.get_node_or_null("CardArt") as LiveRunCardRewardChoicePanel._CardIllustration
		var name_label := content.get_node("NameLabel") as Label
		_check(art != null, "illustration window mounts: " + card_id)
		if art == null:
			continue
		_check(art.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and art.focus_mode == Control.FOCUS_NONE,
			"illustration window takes no pointer input or focus: " + card_id)
		_check(art.get_global_rect().size.y >= 40.0
			and card.get_global_rect().encloses(art.get_global_rect())
			and screen.encloses(art.get_global_rect()),
			"illustration window has a real area inside the card and 1280x720: " + card_id)
		_check(art.get_global_rect().end.y <= name_label.get_global_rect().position.y + 0.5,
			"illustration window stays above the name strip: " + card_id)
		var art_path: String = LiveRunCardRewardChoicePanel.card_art_path(card_id)
		var emblem: String = LiveRunCardRewardChoicePanel.emblem_path(String(definition.get("owner", "")))
		_check(ResourceLoader.exists(art_path), "required committed picture exists: " + card_id)
		if ResourceLoader.exists(art_path):
			_check(art.has_picture() and art.picture.resource_path == art_path,
				"committed individual art is bound: " + card_id)
			# Authored art keeps the card-art mode: a real picture covering the inset,
			# never the emblem medallion and never the drawn placeholder.
			_check(art.mode == LiveRunCardRewardChoicePanel._CardIllustration.MODE_CARD_ART
				and art.is_card_art() and not art.is_emblem() and not art.is_paper_patch(),
				"authored art renders in its own card-art mode: " + card_id)
			_check_picture_geometry(art, card_id)
			_check(art.picture_rect().size.y >= 96.0,
				"mounted authored picture is at least 96px high: " + card_id)
		elif ResourceLoader.exists(emblem):
			_check(art.has_picture() and art.picture.resource_path == emblem,
				"missing art falls back to the hero emblem: " + card_id)
			_check_emblem_felt(art, card_id)
		else:
			_check(not art.has_picture() and art.is_paper_patch(),
				"unpictured card keeps the drawn paper patch without failing: " + card_id)
		var strip := name_label.get_theme_stylebox("normal") as StyleBoxFlat
		_check(strip != null, "name strip uses its own paper style: " + card_id)
		if strip != null:
			_check(strip.bg_color == Color("#fbf3e4"),
				"name keeps its own cream torn-paper strip: " + card_id)
			_check(LiveRunCardRewardChoicePanel.contrast_ratio(
				name_label.get_theme_color("font_color"), strip.bg_color) >= 4.5,
				"name ink stays legible on its own strip: " + card_id)
		_check(name_label.text == String(definition.get("display_name", "")),
			"name strip keeps the authored display name: " + card_id)
		_check(name_label.is_visible_in_tree() and art.is_visible_in_tree(),
			"illustration and name are both visibly drawn: " + card_id)
		_check_mounted_art_clearance(card, card_id)
		if slot > 0:
			var first := panel.choices_container.get_child(0) as Control
			for strip_name in ["CardArt", "NameLabel", "CostButton", "PositionPips", "RulesLabel", "ChooseButton"]:
				var peer := first.get_node("CardMargin/CardContent/" + strip_name) as Control
				var current := content.get_node(strip_name) as Control
				_check(absf(peer.global_position.y - current.global_position.y) <= 0.5,
					"three authored faces align their " + strip_name)
	# Controlled texture shapes on the real mounted Fight/Elite faces prove both
	# vertical and horizontal cropping independently of installed art dimensions.
	var controlled_art := panel.choices_container.get_child(0).get_node(
		"CardMargin/CardContent/CardArt") as LiveRunCardRewardChoicePanel._CardIllustration
	var original_picture: Texture2D = controlled_art.picture
	for dimensions: Vector2i in [Vector2i(120, 480), Vector2i(1200, 120), Vector2i(400, 300)]:
		var texture := PlaceholderTexture2D.new()
		texture.size = Vector2(dimensions)
		controlled_art.picture = texture
		controlled_art.mode = controlled_art.MODE_CARD_ART
		controlled_art.queue_redraw()
		await _frames()
		_check_picture_geometry(controlled_art, "%s controlled %s" % [kind, dimensions])
		var crop := controlled_art.picture_source_rect()
		_check(crop.size.x < dimensions.x or crop.size.y < dimensions.y,
			"mismatched aspect actually crops source pixels: %s %s" % [kind, dimensions])
		if dimensions.x < dimensions.y:
			_check(is_equal_approx(crop.size.x, dimensions.x) and crop.size.y < dimensions.y,
				"portrait crop removes equal top/bottom portions: " + kind)
		elif dimensions.x == 1200:
			_check(is_equal_approx(crop.size.y, dimensions.y) and crop.size.x < dimensions.x,
				"wide landscape crop removes equal left/right portions: " + kind)
		_check(controlled_art.emblem_backdrop_rect() == Rect2()
			and controlled_art.emblem_backdrop_source_rect() == Rect2(),
			"authored cover has no emblem backdrop: " + kind)
		controlled_art.mode = controlled_art.MODE_EMBLEM
		controlled_art.queue_redraw()
		await _frames()
		_check_emblem_felt(controlled_art, "%s controlled emblem %s" % [kind, dimensions])
		var backdrop_crop := controlled_art.emblem_backdrop_source_rect()
		_check(backdrop_crop.size.x < dimensions.x or backdrop_crop.size.y < dimensions.y,
			"emblem backdrop really crops the mismatched source: " + kind)
		if dimensions.x < dimensions.y:
			_check(is_equal_approx(backdrop_crop.size.x, dimensions.x)
				and backdrop_crop.size.y < dimensions.y,
				"portrait emblem backdrop crops top and bottom: " + kind)
		elif dimensions.x == 1200:
			_check(is_equal_approx(backdrop_crop.size.y, dimensions.y)
				and backdrop_crop.size.x < dimensions.x,
				"wide emblem backdrop crops left and right: " + kind)
	controlled_art.picture = original_picture
	controlled_art.mode = controlled_art.MODE_CARD_ART
	controlled_art.queue_redraw()
	# Force both resource-loss branches on actual mounted faces, independent of
	# whether optional pool-card images are later supplied by the art pipeline.
	var fallback_card := panel.choices_container.get_child(1) as PanelContainer
	var fallback_art := fallback_card.get_node("CardMargin/CardContent/CardArt") as LiveRunCardRewardChoicePanel._CardIllustration
	fallback_art.picture = load(LiveRunCardRewardChoicePanel.emblem_path("seamstress")) as Texture2D
	fallback_art.mode = fallback_art.MODE_EMBLEM
	fallback_art.queue_redraw()
	await _frames()
	_check_emblem_felt(fallback_art, "mounted emblem")
	_check_mounted_art_clearance(fallback_card, "mounted emblem")
	fallback_art.picture = null
	fallback_art.mode = fallback_art.MODE_NONE
	fallback_art.queue_redraw()
	await _frames()
	_check(fallback_art.is_paper_patch() and fallback_art.picture_rect() == Rect2()
		and fallback_art.emblem_backdrop_rect() == Rect2()
		and fallback_art.emblem_backdrop_source_rect() == Rect2(),
		"mounted missing art keeps a visible placeholder without a picture")
	_check_mounted_art_clearance(fallback_card, "mounted placeholder")
	# A pointer click over the illustration passes through to the card action
	# exactly once, so the picture never swallows the player's choice.
	requests.clear()
	var first_content := (panel.choices_container.get_child(0) as PanelContainer) \
		.get_node("CardMargin/CardContent") as VBoxContainer
	var first_art := first_content.get_node("CardArt") as Control
	await _click(first_art)
	_check(requests == [{"node": "art_preview", "card": ids[0]}],
		"illustration click routes to the card action exactly once")
	panel.acknowledge(false)
	_check(panel.get_choice_buttons().all(func(button: Button) -> bool: return not button.disabled),
		"rejection re-enables after illustration click")
	_check(receipt == before, "illustration preview leaves its receipt intact")
	panel.close_rewards()
	await _frames()
	await _test_illustration_fallback(base, kind)


func _check_mounted_art_clearance(card: PanelContainer, context: String) -> void:
	var content := card.get_node("CardMargin/CardContent") as VBoxContainer
	var art := content.get_node("CardArt") as Control
	var screen := Rect2(Vector2.ZERO, Vector2(1280, 720))
	for strip in ["CardHeader", "NameLabel", "CostButton", "PositionPips", "RulesLabel", "ChooseButton"]:
		var control := content.get_node(strip) as Control
		_check(control.is_visible_in_tree() and control.size.x > 0 and control.size.y > 0
			and screen.encloses(control.get_global_rect())
			and card.get_global_rect().encloses(control.get_global_rect())
			and not art.get_global_rect().intersects(control.get_global_rect()),
			"mounted art leaves %s readable inside the viewport: %s" % [strip, context])
	_check(screen.encloses(panel.skip_button.get_global_rect()) and not panel.skip_button.disabled,
		"Skip stays reachable beside mounted art: " + context)


## The reward face resolves art by priority: the card's own authored picture,
## then the owning hero's stitched emblem, then a drawn paper patch. Any of
## those is valid, so the expectation is conditional on the actual lookup; we
## never assert that optional art stays missing.
func _test_illustration_fallback(base: Dictionary, kind: String) -> void:
	var ids := _authored_base_ids()
	_check(ids.size() >= 3, "authored pool cards exist for the fallback case")
	if ids.size() < 3:
		return
	var receipt := base.duplicate(true)
	for slot in range(3):
		var card_id: String = ids[slot]
		receipt["offers"][slot] = {"id": card_id,
			"owner": String(_base_pool_definition(card_id).get("owner", ""))}
	requests.clear()
	_check(panel.open_rewards("art_fallback", kind, receipt),
		"unpictured pool cards still mount a valid reward offer")
	if not panel.has_open_rewards():
		return
	await _frames()
	for slot in range(3):
		var card_id: String = ids[slot]
		var owner := String((receipt["offers"][slot] as Dictionary).get("owner", ""))
		var content := panel.choices_container.get_child(slot).get_node("CardMargin/CardContent") as VBoxContainer
		var art := content.get_node_or_null("CardArt") as LiveRunCardRewardChoicePanel._CardIllustration
		_check(art != null, "fallback illustration window mounts: " + card_id)
		if art == null:
			continue
		_check(art.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and art.focus_mode == Control.FOCUS_NONE,
			"fallback illustration stays inert: " + card_id)
		var art_path: String = LiveRunCardRewardChoicePanel.card_art_path(card_id)
		var emblem: String = LiveRunCardRewardChoicePanel.emblem_path(owner)
		# Mounted picture follows the real lookup priority; none of these
		# branches requires optional art to be absent.
		if ResourceLoader.exists(art_path):
			_check(art.has_picture() and art.picture.resource_path == art_path,
				"authored card picture is bound when present: " + card_id)
			_check(art.mode == LiveRunCardRewardChoicePanel._CardIllustration.MODE_CARD_ART
				and art.is_card_art(), "present card art keeps the card-art mode: " + card_id)
			_check_picture_geometry(art, card_id)
		elif ResourceLoader.exists(emblem):
			_check(art.has_picture() and art.picture.resource_path == emblem,
				"hero emblem stands in for absent art: " + card_id)
			_check_emblem_felt(art, card_id)
		else:
			_check(not art.has_picture() and art.is_paper_patch(),
				"absent art and emblem keep the drawn paper patch: " + card_id)
		_check((content.get_node("NameLabel") as Label).text
			== String(_base_pool_definition(card_id).get("display_name", "")),
			"fallback face keeps its authored name: " + card_id)
	# Controlled absent-texture case: an impossible id/owner pair deterministically
	# exercises the ultimate drawn-paper branch (null texture) without relying on
	# any committed art staying missing forever.
	var nowhere_id := "zz_no_such_reward_art_card"
	var nowhere_owner := "zz_no_such_reward_owner"
	var nowhere := LiveRunCardRewardChoicePanel.resolve_card_art(nowhere_id, nowhere_owner)
	_check(nowhere.get("mode") == LiveRunCardRewardChoicePanel._CardIllustration.MODE_NONE
		and nowhere.get("texture") == null,
		"synthetic id with no picture or emblem resolves to the placeholder mode")
	_check(LiveRunCardRewardChoicePanel._card_art_texture(nowhere_id, nowhere_owner) == null,
		"synthetic id with no picture or emblem falls through to the drawn paper patch")
	# The drawn/emblem patch is still pointer-inert: a click over it picks the card.
	requests.clear()
	var first_art := (panel.choices_container.get_child(0) as PanelContainer) \
		.get_node("CardMargin/CardContent/CardArt") as Control
	await _click(first_art)
	_check(requests == [{"node": "art_fallback", "card": ids[0]}],
		"fallback illustration click still routes the offer once")
	panel.acknowledge(false)
	panel.close_rewards()
	await _frames()


## Source inspection of the two illustration modes and the placeholder, because a
## mounted rectangle assertion cannot see which brush each branch used.
func _test_illustration_source() -> void:
	var art := _class_source("_CardIllustration", "## Owner color patch")
	_check(not art.is_empty(), "illustration drawing source located")
	for marker in ["MODE_CARD_ART", "MODE_EMBLEM", "MODE_NONE"]:
		_check(art.contains(marker), "illustration source keeps mode " + marker)
	_check(art.contains("func is_card_art(") and art.contains("func is_emblem(")
		and art.contains("func is_paper_patch("),
		"illustration source exposes its three presentation modes")
	_check(art.contains("func picture_rect(") and art.contains("emblem_backing_rect()")
		and art.contains("area = emblem_backing_rect().grow(-EMBLEM_INSET)"),
		"emblem picture fills the inset felt patch with original aspect")
	_check(art.contains("func _draw_felt_fallback(")
		and art.contains("draw_colored_polygon(") and art.contains("draw_dashed_line("),
		"fallback source draws wide owner felt, corner patches and sewn seams")
	_check(art.contains("func _draw_contained_picture(")
		and art.contains("draw_texture_rect(picture, target, false)"),
		"emblem is drawn contained from its measured aspect rect, never tiled")
	var draw := art.substr(art.find("func _draw()"),
		art.find("func _draw_cover_picture()") - art.find("func _draw()")).replace("\r\n", "\n")
	_check(draw.contains("if is_card_art():\n\t\t\t\t_draw_cover_picture()")
		and draw.contains("if is_emblem():\n\t\t\t_draw_felt_fallback()\n\t\t\t_draw_contained_picture()"),
		"draw routes authored art to cover and emblem to contained felt")
	var cover := art.substr(art.find("func _draw_cover_picture()"),
		art.find("func _draw_contained_picture()") - art.find("func _draw_cover_picture()"))
	_check(cover.contains("var target: Rect2 = picture_rect()")
		and cover.contains("var source: Rect2 = picture_source_rect()")
		and cover.contains("draw_texture_rect_region(picture, target, source)")
		and not cover.contains("draw_texture_rect(picture"),
		"authored art draws the measured source crop into the measured cover destination")
	var felt := art.substr(art.find("func _draw_felt_fallback()"),
		art.find("func _draw_paper_patch(") - art.find("func _draw_felt_fallback()"))
	var backdrop_draw := felt.find("draw_texture_rect_region(picture, emblem_backdrop_rect(), source, Color(1, 1, 1, 0.45))")
	_check(felt.contains("var source: Rect2 = emblem_backdrop_source_rect()")
		and backdrop_draw > felt.find("draw_colored_polygon(right_piece")
		and backdrop_draw < felt.find("draw_rect(backing, Color(\"#3b2f2a\")")
		and backdrop_draw < felt.find("draw_dashed_line(")
		and not felt.contains("draw_texture_rect(picture"),
		"subdued emblem crop paints above flat felt, beneath its border and stitches")
	_check(draw.find("_draw_felt_fallback()") < draw.find("_draw_contained_picture()")
		and draw.find("_draw_contained_picture()") < draw.find("_draw_sewn_seam(rect)"),
		"complete contained emblem sits above textured felt and below the outer seam")
	_check(art.contains("func _draw_paper_patch(") and art.contains("draw_dashed_line("),
		"missing art and emblem still draw the stitched paper patch")
	_check(not art.contains("load(\"res://assets"), "illustration never loads art by itself")
	var resolver := _source_slice("static func resolve_card_art", "## Texture-only lookup kept")
	_check(not resolver.is_empty(), "reward art resolver source located")
	_check(resolver.find("card_art_path(") >= 0
		and resolver.find("card_art_path(") < resolver.find("emblem_path("),
		"authored card art is tried before the owner emblem")
	_check(resolver.contains("MODE_NONE"), "missing art and emblem fall through to the placeholder")
	var mount := _source_slice("func _mount_card", "## The hover legend for the six painted marks")
	_check(mount.contains("resolve_card_art(") and mount.contains("illustration.mode ="),
		"the live card mounts the resolved mode instead of a bare texture")
	_check(mount.contains("CARD_ART_HEIGHT") and mount.contains("SIZE_EXPAND_FILL"),
		"the mounted picture window keeps its readable minimum and takes card slack")
	_check(mount.contains("CardShortRules.line("),
		"the mounted reward face gets its effect text from the shared formatter")
	_check(mount.contains("card.tooltip_text = _pip_legend("),
		"the mounted reward face carries the hover legend for its marks")
	_check(not mount.contains("_format_rules"),
		"the reward face keeps no independent position-target formatter")


## The deliberate null-art/null-emblem path: a mounted window with no texture
## keeps drawing the stitched paper patch and stays inert, so a valid offer can
## never fail to mount even when every optional resource is missing.
func _test_missing_art_placeholder() -> void:
	var nowhere := LiveRunCardRewardChoicePanel.resolve_card_art(
		"zz_no_such_reward_art_card", "zz_no_such_reward_owner")
	_check(nowhere.get("mode") == LiveRunCardRewardChoicePanel._CardIllustration.MODE_NONE
		and nowhere.get("texture") == null,
		"missing art and emblem resolve to the placeholder mode")
	var default_probe := LiveRunCardRewardChoicePanel._CardIllustration.new()
	_check(default_probe.mode == LiveRunCardRewardChoicePanel._CardIllustration.MODE_CARD_ART,
		"mounted card faces keep the card-art default mode")
	default_probe.free()
	var probe := LiveRunCardRewardChoicePanel._CardIllustration.new()
	probe.name = "NullArtProbe"
	probe.mode = String(nowhere.get("mode"))
	probe.picture = nowhere.get("texture")
	probe.owner_color = panel.OWNER_COLORS["warden"]
	root.add_child(probe)
	probe.size = Vector2(304.0, LiveRunCardRewardChoicePanel.CARD_ART_HEIGHT)
	await _frames()
	_check(probe.is_paper_patch() and not probe.has_picture()
		and not probe.is_card_art() and not probe.is_emblem(),
		"null art and emblem mount the drawn paper patch")
	_check(probe.picture_rect() == Rect2()
		and probe.emblem_backdrop_rect() == Rect2()
		and probe.emblem_backdrop_source_rect() == Rect2(),
		"placeholder window paints no picture rect")
	_check(probe.is_visible_in_tree() and probe.size.y
		>= LiveRunCardRewardChoicePanel.CARD_ART_HEIGHT,
		"placeholder window still occupies a real, visible area")
	_check(probe.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and probe.focus_mode == Control.FOCUS_NONE,
		"placeholder window takes no pointer input or focus")
	_check(probe.emblem_backing_rect().size.x > 0.0,
		"placeholder still knows its owner felt backing size")
	probe.size = Vector2.ZERO
	_check(probe.emblem_backing_rect().size == Vector2.ZERO
		and probe.picture_rect() == Rect2(),
		"a collapsed window reports no drawable art instead of failing")
	probe.picture = PlaceholderTexture2D.new()
	probe.mode = probe.MODE_EMBLEM
	_check(probe.emblem_backdrop_rect() == Rect2()
		and probe.emblem_backdrop_source_rect() == Rect2(),
		"collapsed emblem also reports no drawable backdrop")
	root.remove_child(probe)
	probe.free()


## The optional burlap art must stay optional: with no texture the sewn reward
## action keeps opaque normal/hover/pressed/disabled faces, a dark focus stitch
## and readable ink, so a legible fallback never needs a generated asset. The
## same faces still take the art slice when the shipped texture resolves.
func _test_burlap_fallback() -> void:
	var accent := Color("#766351")
	var probe := Button.new()
	probe.name = "FallbackBurlapProbe"
	root.add_child(probe)
	panel._apply_sewn_faces(probe, accent)
	panel._sew_burlap(probe, accent, panel.BUTTON_EDGE, null)
	await _frames()
	_check(probe.get_node_or_null("BurlapPatch") == null,
		"absent burlap texture mounts no art patch")
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		_check(probe.has_theme_stylebox_override(state),
			"absent burlap texture keeps a sewn %s face" % state)
		var box := probe.get_theme_stylebox(state) as StyleBoxFlat
		_check(box != null and box.bg_color.a >= 1.0,
			"absent burlap texture keeps an opaque %s face" % state)
		_check(box != null and box.border_color == accent
			and box.border_width_top >= 2 and box.corner_radius_top_left >= 4,
			"absent burlap texture keeps the owner-sewn %s border" % state)
	var focus := probe.get_theme_stylebox("focus") as StyleBoxFlat
	_check(focus != null and probe.has_theme_stylebox_override("focus")
		and focus.bg_color.a == 0.0
		and focus.border_color == LiveRunCardRewardChoicePanel._FocusStitch.DARK_FOCUS_INK,
		"absent burlap texture keeps the dark focus stitch face")
	_check(probe.get_theme_color("font_color") == Color("#263137")
		and probe.get_theme_color("font_focus_color") == LiveRunCardRewardChoicePanel.DARK_INK,
		"absent burlap texture keeps readable dark ink on the beige face")
	# The art branch is not dead: when the shipped texture resolves it mounts the
	# established normal-size slice, exactly what Choose, Skip and Close keep.
	var art := LiveRunCardRewardChoicePanel.art_texture(
		LiveRunCardRewardChoicePanel.BURLAP_BUTTON)
	var art_probe := Button.new()
	art_probe.name = "ArtBurlapProbe"
	root.add_child(art_probe)
	panel._apply_sewn_faces(art_probe, accent)
	panel._sew_burlap(art_probe, accent, panel.BUTTON_EDGE, art)
	await _frames()
	var art_patch := art_probe.get_node_or_null("BurlapPatch") as NinePatchRect
	_check((art != null) == (art_patch != null),
		"burlap art patch follows the resolved texture")
	if art_patch != null:
		_check(art_patch.get_parent() == art_probe
			and art_patch.patch_margin_top == panel.BUTTON_EDGE
			and art_patch.patch_margin_bottom == panel.BUTTON_EDGE
			and art_patch.patch_margin_left == panel.BUTTON_EDGE
			and art_patch.patch_margin_right == panel.BUTTON_EDGE,
			"resolved burlap mounts the established normal-size slice behind its action")
		var normal := art_probe.get_theme_stylebox("normal") as StyleBoxFlat
		_check(normal != null and normal.bg_color.a == 0.0,
			"resolved burlap makes the procedural face see-through")
	root.remove_child(probe)
	probe.free()
	root.remove_child(art_probe)
	art_probe.free()


## The Help cell must stay readable when the optional sewn button art is absent:
## the procedural face is opaque and the same measured label fit reserves both
## sewn side seams, so the fallback never crowds the owner ribbon either.
func _test_help_cell_without_art() -> void:
	var accent := Color("#766351")
	var probe := Button.new()
	probe.name = "HelpCellFallbackProbe"
	probe.text = "Help"
	probe.theme_type_variation = &"PatchHeadingButton"
	probe.add_theme_font_size_override("font_size",
		LiveRunCardRewardChoicePanel.HELP_TAB_FONT_SIZE)
	panel._apply_sewn_faces(probe, accent)
	panel._sew_burlap(probe, accent,
		LiveRunCardRewardChoicePanel.HELP_TAB_EDGE_VERTICAL, null)
	root.add_child(probe)
	await _frames()
	panel._fit_help_tab(probe)
	probe.size = probe.custom_minimum_size
	await _frames()
	_check(probe.get_node_or_null("BurlapPatch") == null,
		"absent sewn art mounts no Help burlap patch")
	var face := probe.get_theme_stylebox("normal") as StyleBoxFlat
	_check(face != null and face.bg_color.a >= 1.0 and face.border_color == accent,
		"absent sewn art keeps an opaque owner-accent Help cell")
	_check(face != null and LiveRunCardRewardChoicePanel.contrast_ratio(
		probe.get_theme_color("font_color"), face.bg_color) >= 4.5,
		"absent sewn art keeps dark Help ink readable on the felt")
	var font: Font = probe.get_theme_font(&"font")
	if font == null:
		font = ThemeDB.fallback_font
	var point_size: int = probe.get_theme_font_size(&"font_size")
	var text_width: float = font.get_string_size(probe.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x
	var required: float = text_width + float(panel.BUTTON_EDGE) * 2.0 \
		+ float(panel.HELP_TAB_TEXT_BREATH)
	_check(text_width > 0.0 and probe.custom_minimum_size.x >= required - 0.01
		and probe.custom_minimum_size.x <= ceilf(required),
		"absent sewn art measures the Help label with both side seams reserved")
	_check(probe.custom_minimum_size.y >= font.get_height(point_size) - 1.0
		and probe.custom_minimum_size.y <= LiveRunCardRewardChoicePanel.HELP_TAB_HEIGHT,
		"absent sewn art keeps the Help label inside its 24px cell")
	if face != null:
		_check(probe.size.x >= text_width + face.content_margin_left
			+ face.content_margin_right,
			"absent sewn art leaves the complete Help label room inside its cell")
	root.remove_child(probe)
	probe.free()


## AC2 composition guard for the Help tab: it is a second sewn cell beside the
## owner ribbon, never sewn onto the hero's name. Measured text fit proves the
## full hero name and the Help label both keep their own room at 1280x720, with
## or without the optional burlap art. The final rhythm is judged by screenshots,
## not by new coordinate goldens.
func _test_art_and_help_clearance(base: Dictionary, kind: String) -> void:
	# One keyword-bearing authored card for each hero, so the full Warden,
	# Seamstress and Tinker names are inspected beside a real Help cell.
	var ids: Array[String] = ["warden_pinning_jab", "seamstress_red_thread", "tinker_ricochet"]
	var receipt := base.duplicate(true)
	for slot in range(3):
		var definition := _base_pool_definition(ids[slot])
		_check(not definition.is_empty()
			and not CardKeywordGlossary.describe(definition).is_empty(),
			"clearance case is an authored card with help keywords: " + ids[slot])
		receipt["offers"][slot] = {"id": ids[slot],
			"owner": String(definition.get("owner", ""))}
	requests.clear()
	_check(panel.open_rewards("help_clearance", kind, receipt),
		"help clearance receipt mounts through the real panel")
	if not panel.has_open_rewards():
		return
	await _frames()
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	var clearance_checks := 0
	var burlap_checks := 0
	var mounted_owners: Array[String] = []
	var burlap_art := LiveRunCardRewardChoicePanel.art_texture(
		LiveRunCardRewardChoicePanel.BURLAP_BUTTON)
	for slot in range(3):
		var card_id: String = ids[slot]
		var card := panel.choices_container.get_child(slot) as PanelContainer
		if card == null:
			_check(false, "help clearance card mounts: " + card_id)
			continue
		var content := card.get_node("CardMargin/CardContent") as VBoxContainer
		var header := content.get_node_or_null("CardHeader") as HBoxContainer
		_check(header != null, "card header exists: " + card_id)
		if header == null:
			continue
		var help := header.get_node_or_null("HelpButton") as Button if header != null else card.get_node_or_null("CardMargin/CardContent/OwnerPatch/HelpCorner/HelpButton") as Button
		_check(help != null and help.is_visible_in_tree() and not help.disabled,
			"keyword card keeps a live Help tab: " + card_id)
		if help == null:
			continue
		var help_rect := help.get_global_rect()
		var owner_patch := (header.get_node("OwnerPatch") if header != null else content.get_node("OwnerPatch")) as Control
		var owner_label := owner_patch.get_node("OwnerLabel") as Label
		var owner_rect := owner_patch.get_global_rect()
		var header_rect := header.get_global_rect()
		_check(card.get_global_rect().encloses(help_rect) and screen.encloses(help_rect),
			"Help tab stays inside its card and 1280x720: " + card_id)
		_check(help.get_parent() == header and owner_patch.get_parent() == header,
			"header contains owner patch and Help tab as sibling cells: " + card_id)
		_check(not help_rect.intersects(owner_rect),
			"Help tab and owner ribbon do not overlap: " + card_id)
		_check(header_rect.encloses(help_rect) and header_rect.encloses(owner_rect),
			"card header row fits both owner patch and Help tab: " + card_id)
		_check(is_equal_approx(header.size.y, 24.0) and help.size.y <= 24.0 and owner_patch.size.y <= 24.0,
			"card header keeps to one 24px line: " + card_id)
		# Measured text fit: the mount measures the real display label and the
		# sewn side seams, so neither cell borrows from the other. The gap of card
		# paper between them is the structural separation the screenshot judges.
		var owner := String(receipt["offers"][slot]["owner"])
		mounted_owners.append(owner)
		var help_font: Font = help.get_theme_font(&"font")
		if help_font == null:
			help_font = ThemeDB.fallback_font
		var help_point: int = help.get_theme_font_size(&"font_size")
		var help_label_width: float = help_font.get_string_size(help.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, help_point).x
		var help_required: float = help_label_width \
			+ float(panel.BUTTON_EDGE) * 2.0 + float(panel.HELP_TAB_TEXT_BREATH)
		_check(help_font != null and help_label_width > 0.0,
			"Help label measures real display glyphs: " + card_id)
		_check(is_equal_approx(help.custom_minimum_size.x, ceilf(help_required))
			and help.size.x >= help_required - 0.01,
			"Help cell is measured to its label plus both sewn side seams: %s (custom %.1f, size %.1f, required %.1f)"
				% [card_id, help.custom_minimum_size.x, help.size.x, help_required])
		_check(help.size.y >= help_font.get_height(help_point) - 1.0,
			"Help label keeps its complete display line height: " + card_id)
		var owner_font: Font = owner_label.get_theme_font(&"font")
		if owner_font == null:
			owner_font = ThemeDB.fallback_font
		var owner_point: int = owner_label.get_theme_font_size(&"font_size")
		var owner_label_width: float = owner_font.get_string_size(owner_label.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, owner_point).x
		_check(owner_label_width > 0.0 and owner_label.size.x >= owner_label_width,
			"complete '%s' name fits its own ribbon cell: %s" % [owner_label.text, card_id])
		_check(absf(owner_label.size.x
				- (owner_patch.size.x - 2.0 * float(panel.OWNER_NAME_SIDE_INSET))) <= 0.5,
			"owner name keeps its measured side insets clear of the seam: " + card_id)
		_check(owner_rect.encloses(owner_label.get_global_rect())
			and not owner_label.clip_text and owner_label.get_line_count() == 1,
			"full hero name is sewn whole, never clipped by the Help cell: " + card_id)
		_check(header.get_theme_constant("separation") == panel.HEADER_CELL_GAP
			and help_rect.position.x - owner_rect.end.x >= float(panel.HEADER_CELL_GAP) - 0.5,
			"card paper separates the Help cell from the owner ribbon: " + card_id)
		var help_face := help.get_theme_stylebox("normal") as StyleBoxFlat
		_check(help_face != null and help_face.border_width_left >= 2
			and help_face.border_color.r == panel.OWNER_COLORS[owner].r
			and help_face.border_color.g == panel.OWNER_COLORS[owner].g
			and help_face.border_color.b == panel.OWNER_COLORS[owner].b,
			"Help cell keeps its own owner-accent sewn border: " + card_id)
		# The Help cell is only 24px tall, so its burlap must not carry the normal
		# 22px top+bottom seams (44 > 24). The mounted NinePatchRect itself proves
		# the art slice still has a positive centre inside that cell.
		var help_burlap := help.get_node_or_null("BurlapPatch") as NinePatchRect
		_check((burlap_art != null) == (help_burlap != null),
			"mounted Help burlap follows the shipped texture: " + card_id)
		if help_burlap != null:
			burlap_checks += 1
			var top_edge: int = help_burlap.patch_margin_top
			var bottom_edge: int = help_burlap.patch_margin_bottom
			var centre_height: float = LiveRunCardRewardChoicePanel.HELP_TAB_HEIGHT \
				- float(top_edge) - float(bottom_edge)
			_check(help_burlap.get_parent() == help,
				"Help burlap patch belongs to this Help control: " + card_id)
			_check(help_burlap.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and help_burlap.focus_mode == Control.FOCUS_NONE,
				"Help burlap patch stays pointer-inert and unfocusable: " + card_id)
			_check(top_edge >= 0 and bottom_edge >= 0,
				"Help burlap vertical margins are nonnegative: " + card_id)
			_check(top_edge + bottom_edge < int(LiveRunCardRewardChoicePanel.HELP_TAB_HEIGHT)
				and centre_height > 0.0,
				"Help burlap seams leave a positive centre inside the 24px cell: " + card_id)
			var burlap_size: Vector2 = help_burlap.texture.get_size() \
				if help_burlap.texture != null else Vector2.ZERO
			_check(burlap_size.x > float(help_burlap.patch_margin_left
					+ help_burlap.patch_margin_right)
				and burlap_size.y > float(top_edge + bottom_edge),
				"Help burlap nine-slice leaves a real source centre: " + card_id)
			_check(help_burlap.patch_margin_left == LiveRunCardRewardChoicePanel.BUTTON_EDGE
				and help_burlap.patch_margin_right == LiveRunCardRewardChoicePanel.BUTTON_EDGE,
				"Help burlap keeps the established side seams: " + card_id)
		_check(not help_rect.intersects(owner_label.get_global_rect())
			and not help_rect.intersects(panel.title_label.get_global_rect())
			and not help_rect.intersects(panel.gold_label.get_global_rect())
			and (not panel.trinket_label.visible
				or not help_rect.intersects(panel.trinket_label.get_global_rect())),
			"Help avoids owner name and every reward banner line: " + card_id)
		var art := content.get_node("CardArt") as LiveRunCardRewardChoicePanel._CardIllustration
		var picture := Rect2(art.global_position + art.picture_rect().position,
			art.picture_rect().size) if art != null and art.has_picture() else Rect2()
		for other: String in ["CardArt", "NameLabel", "RulesLabel", "ChooseButton",
				"CostButton", "PositionPips"]:
			var control := content.get_node_or_null(other) as Control
			_check(control != null, "clearance sibling exists: %s (%s)" % [other, card_id])
			if control == null:
				continue
			clearance_checks += 1
			_check(not help_rect.intersects(control.get_global_rect()),
				"Help tab never covers %s: %s" % [other, card_id])
		if picture.size.x > 0.0:
			_check(not help_rect.intersects(picture),
				"Help tab never covers the drawn picture: " + card_id)
		var receipt_before: Dictionary = panel._receipt.duplicate(true)
		await _mouse(help)
		var overlay := panel.get_node_or_null("KeywordHelpOverlay") as PanelContainer
		_check(overlay != null and panel._help_overlay == overlay,
			"mouse Help opens the real glossary for this card: " + card_id)
		if overlay != null:
			var help_title := overlay.get_node("HelpContent/HelpTitle") as Label
			var lines := overlay.get_node("HelpContent/KeywordScroll/KeywordLines") as VBoxContainer
			_check(help_title.text.contains(String(_base_pool_definition(card_id)["display_name"]))
				and lines.get_child_count() > 0,
				"glossary names the offered card and explains real keywords: " + card_id)
			var close := overlay.get_node("HelpContent/CloseHelpButton") as Button
			await _mouse(close)
			_check(panel._help_overlay == null and help.has_focus(),
				"mouse Close returns focus to the owning Help: " + card_id)
		var choose := content.get_node("ChooseButton") as Button
		var choose_patch := choose.get_node_or_null("BurlapPatch") as NinePatchRect
		if choose_patch != null:
			_check(choose_patch.patch_margin_top == LiveRunCardRewardChoicePanel.BUTTON_EDGE
				and choose_patch.patch_margin_bottom == LiveRunCardRewardChoicePanel.BUTTON_EDGE,
				"Choose keeps the established normal-size burlap slice: " + card_id)
		choose.grab_focus()
		await _key(KEY_RIGHT)
		_check(help.has_focus(),
			"keyboard Right from Choose navigates focus to Help: " + card_id)
		await _key(KEY_ENTER)
		_check(panel._help_overlay != null,
			"keyboard Enter on this Help opens glossary: " + card_id)
		if panel._help_overlay != null:
			await _key(KEY_ESCAPE)
			_check(panel._help_overlay == null and help.has_focus(),
				"keyboard Escape closes glossary and restores Help focus: " + card_id)
		await _key(KEY_SPACE)
		_check(panel._help_overlay != null,
			"keyboard Space on this Help opens glossary: " + card_id)
		if panel._help_overlay != null:
			await _key(KEY_ESCAPE)
			_check(panel._help_overlay == null and help.has_focus(),
				"keyboard Escape closes glossary and restores Help focus: " + card_id)
		await _key(KEY_LEFT)
		_check(choose.has_focus(),
			"keyboard Left returns focus from Help to Choose: " + card_id)
		_check(requests.is_empty() and panel._receipt == receipt_before
			and not panel._awaiting_ack,
			"mouse/keyboard Help never requests or changes the prepared choice: " + card_id)
	_check(clearance_checks >= 18, "help clearance really inspected every sibling")
	_check(mounted_owners == ["warden", "seamstress", "tinker"],
		"clearance mounts keyword Help beside all three full hero names: " + str(mounted_owners))
	_check(burlap_checks == (3 if burlap_art != null else 0),
		"every mounted keyword Help tab was inspected against its burlap art")
	_check(receipt["offers"][0]["id"] == ids[0], "help clearance receipt stays authentic")
	var old_help := panel._help_buttons[0] as Button
	var connections := old_help.pressed.get_connections()
	_check(connections.size() == 1, "Help owns exactly one glossary callback before close")
	var stale_help: Callable
	if connections.size() == 1:
		stale_help = connections[0]["callable"]
	panel.close_rewards()
	await _frames()
	_check(panel.open_rewards("help_clearance", kind, receipt),
		"fresh prepared reward remounts after glossary close")
	await _frames()
	if stale_help.is_valid():
		stale_help.call()
	_check(panel._help_overlay == null and requests.is_empty()
		and not panel._awaiting_ack and panel._receipt == receipt,
		"closed-generation Help cannot open a new receipt's glossary or mutate it")
	panel.close_rewards()
	await _frames()


## A valid reward offer with no authored keyword mounts no Help tab at all, while
## a keyword offer in the same three-offer receipt keeps its separate tab. The
## three owner strips cover Warden, Seamstress and Tinker, and the glossary's
## Close action wears the same display face as every reward action.
func _test_no_keyword_card_without_help(base: Dictionary, kind: String) -> void:
	var ids: Array[String] = ["warden_strike", "seamstress_prick", "tinker_pop_shot"]
	var catalog := StarterCards.new()
	var receipt := base.duplicate(true)
	for slot in range(3):
		var definition := catalog.get_definition(ids[slot])
		_check(not definition.is_empty(), "keyword-presence case is an authored card: " + ids[slot])
		if definition.is_empty():
			return
		receipt["offers"][slot] = {"id": ids[slot],
			"owner": String(definition.get("owner", ""))}
	var before := receipt.duplicate(true)
	var fonts := _display_fonts()
	_check(not fonts.is_empty(), "display faces resolve for the keyword-presence case")
	if fonts.is_empty():
		return
	requests.clear()
	_check(panel.open_rewards("keyword_presence", kind, receipt),
		"%s keyword-presence receipt mounts through the real panel" % kind)
	if not panel.has_open_rewards():
		return
	await _frames()
	var owners: Array[String] = []
	var keyword_cards := 0
	var plain_cards := 0
	var first_help: Button = null
	for slot in range(3):
		var card_id := ids[slot]
		var content := panel.choices_container.get_child(slot).get_node(
			"CardMargin/CardContent") as VBoxContainer
		var header := content.get_node_or_null("CardHeader") as HBoxContainer
		_check(header != null, "card header exists: " + card_id)
		var help := header.get_node_or_null("HelpButton") as Button if header != null else content.get_node_or_null("OwnerPatch/HelpCorner/HelpButton") as Button
		var choose := content.get_node("ChooseButton") as Button
		var owner_patch := (header.get_node("OwnerPatch") if header != null else content.get_node("OwnerPatch")) as Control
		var owner_label := owner_patch.get_node("OwnerLabel") as Label
		var keywords := CardKeywordGlossary.describe(catalog.get_definition(card_id))
		owners.append(String(receipt["offers"][slot]["owner"]))
		_check(choose.theme_type_variation == &"PatchHeadingButton"
			and choose.get_theme_font(&"font") == fonts["action"]
			and choose.get_theme_font(&"font") != fonts["body"],
			"Choose action wears the display face: " + card_id)
		_check(owner_label.theme_type_variation == &"PatchHeading"
			and owner_label.get_theme_font(&"font") == fonts["heading"],
			"owner label wears PatchHeading: " + card_id)
		if keywords.is_empty():
			plain_cards += 1
			_check(help == null and (header == null or header.get_node_or_null("HelpButton") == null),
				"no-keyword offer mounts no Help tab at all: " + card_id)
			_check(owner_patch != null and header != null and is_equal_approx(owner_patch.size.x, header.size.x),
				"owner ribbon occupies full width of card header when no Help tab: " + card_id)
			continue
		keyword_cards += 1
		_check(help != null and help.is_visible_in_tree() and not help.disabled,
			"keyword offer keeps a live Help tab: " + card_id)
		if help == null:
			continue
		_check(help.theme_type_variation == &"PatchHeadingButton"
			and help.get_theme_font(&"font") == fonts["action"],
			"Help tab wears the display face: " + card_id)
		var help_size: int = help.get_theme_font_size(&"font_size")
		var help_width: float = fonts["action"].get_string_size(help.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, help_size).x
		_check(help.get_global_rect().size.x >= help_width + 12.0
			and help.get_global_rect().size.y
				>= fonts["action"].get_height(help_size) - 1.0,
			"compact Help tab still fits its complete display label: " + card_id)
		if first_help == null:
			first_help = help
	_check(keyword_cards >= 1 and plain_cards >= 1,
		"the case really mounts a keyword Help tab and a no-keyword offer")
	_check(owners.size() == 3 and owners[0] == "warden" and owners[1] == "seamstress"
		and owners[2] == "tinker",
		"the three resolved owner labels cover all three heroes: " + str(owners))
	var actions := panel.get_choice_buttons()
	_check(actions.size() == 4 and actions[3].theme_type_variation == &"PatchHeadingButton"
		and actions[3].text == "Skip — take no card",
		"%s Skip keeps its complete display label" % kind)
	if first_help != null:
		await _mouse(first_help)
		var overlay := panel.get_node_or_null("KeywordHelpOverlay") as PanelContainer
		_check(overlay != null and panel._help_overlay == overlay,
			"keyword Help opens the real glossary for its offer")
		if overlay != null:
			var close := overlay.get_node_or_null("HelpContent/CloseHelpButton") as Button
			_check(close != null and close.theme_type_variation == &"PatchHeadingButton"
				and close.get_theme_font(&"font") == fonts["action"]
				and close.get_theme_font_size(&"font_size") >= 18,
				"glossary Close action wears the display face")
			if close != null:
				var close_patch := close.get_node_or_null("BurlapPatch") as NinePatchRect
				if close_patch != null:
					_check(close_patch.patch_margin_top == LiveRunCardRewardChoicePanel.BUTTON_EDGE
						and close_patch.patch_margin_bottom == LiveRunCardRewardChoicePanel.BUTTON_EDGE,
						"glossary Close keeps the established normal-size burlap slice")
				await _mouse(close)
				_check(panel._help_overlay == null and first_help.has_focus(),
					"closing the glossary returns focus to its Help tab")
	_check(requests.is_empty() and panel._receipt == before and not panel._awaiting_ack,
		"keyword-presence presentation never requests or mutates the receipt: " + kind)
	panel.close_rewards()
	await _frames()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var loaded := load(SCENE) as PackedScene
	_check(loaded != null, "actual .tscn loads")
	if loaded == null:
		_finish()
		return
	panel = loaded.instantiate() as LiveRunCardRewardChoicePanel
	_check(panel != null, "real panel scene uses required script class")
	if panel == null:
		_finish()
		return
	root.add_child(panel)
	panel.choice_requested.connect(_on_choice)
	await _frames()
	_check(panel.has_method("open_rewards") and panel.has_method("close_rewards")
		and panel.has_method("acknowledge") and panel.has_method("get_choice_buttons"),
		"all four required public methods exist")
	_check(not panel.visible and panel.get_choice_buttons().is_empty(), "initial panel closed")
	_test_focus_and_ink_sources()
	var fight := _prepared(false, 18203)
	var elite := _prepared(true, 18203)
	if not fight["receipt"].get("ok", false) or not elite["receipt"].get("ok", false):
		_finish()
		return
	var original_fight: Dictionary = fight["receipt"].duplicate(true)
	var original_elite: Dictionary = elite["receipt"].duplicate(true)
	await _exercise(fight, "Fight", 0)
	await _exercise(elite, "Elite", 1)
	await _test_all_catalog_rules(original_fight)
	_test_renderer_source()
	await _test_cost_and_marks(original_fight, original_elite)
	await _test_illustration_art(original_fight, "Fight")
	await _test_illustration_art(original_elite, "Elite")
	_test_illustration_source()
	await _test_missing_art_placeholder()
	await _test_burlap_fallback()
	await _test_help_cell_without_art()
	await _test_art_and_help_clearance(original_fight, "Fight")
	await _test_art_and_help_clearance(original_elite, "Elite")
	await _test_no_keyword_card_without_help(original_fight, "Fight")
	await _test_no_keyword_card_without_help(original_elite, "Elite")
	_malformed(original_fight)
	await _replay_and_stale(original_fight)
	var pool_fight := _prepared_pool(false, 18203)
	var pool_elite := _prepared_pool(true, 18203)
	_check(pool_fight["receipt"].get("ok", false) and pool_elite["receipt"].get("ok", false),
		"live weighted Fight and Elite receipts exist")
	if pool_fight["receipt"].get("ok", false) and pool_elite["receipt"].get("ok", false):
		await _exercise_pool(pool_fight, "Fight")
		await _exercise_pool(pool_elite, "Elite")
		await _test_pool_replay(pool_fight)
		await _test_all_pool_cards(original_fight)
		await _test_three_tier_rarities(original_fight)
	# Fresh global seeded stream must also survive panel interactions.
	seed(3941)
	var expected := randi()
	seed(3941)
	_check(panel.open_rewards("rng_node", "Fight", original_fight), "global RNG test opens")
	panel.get_choice_buttons()[0].pressed.emit()
	panel.acknowledge(false)
	panel.get_choice_buttons()[3].pressed.emit()
	panel.acknowledge(true)
	panel.close_rewards()
	_check(randi() == expected, "global seeded RNG receives zero view draws")
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_run_card_reward_choice_panel_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	if is_instance_valid(panel):
		panel.free()
	quit(0 if failures.is_empty() else 1)
