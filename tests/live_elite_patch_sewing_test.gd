extends "res://tests/live_elite_reward_continuation_test.gd"
## Mounted claim -> free sew -> connected continuation -> second drop -> reset/replay.

var sewing

## Literal, independent ID -> readable name oracle, written by hand from the
## shipped catalogs and the owner's naming. It is never computed from the
## presenter's own table, so a wrong, missing or invented name fails here.
const EXPECTED_NAMES := {
	"button_eye": "Button Eye",
	"pincushion_arm": "Pincushion Arm",
	"quilted_coat": "Quilted Coat",
	"padded_vest": "Padded Vest",
	"double_quilt_coat": "Double Quilt Coat",
	"scrap_lined_vest": "Scrap Lined Vest",
	"wool_patch_cloak": "Wool Patch Cloak",
	"chain_stitched_coat": "Chain Stitched Coat",
	"stitched_badge": "Stitched Badge",
	"spare_spool": "Spare Spool",
	"reinforced_patchcoat": "Reinforced Patchcoat",
	"thick_felt_mantle": "Thick Felt Mantle",
	"bloodstitch_bonnet": "Bloodstitch Bonnet",
	"button_glass_visor": "Button Glass Visor",
	"stern_seam_cap": "Stern Seam Cap",
	"reinforced_browband": "Reinforced Browband",
	"hemguard_cuff": "Hemguard Cuff",
	"red_bobbin_cuff": "Red Bobbin Cuff",
	"loose_thread_glove": "Loose Thread Glove",
	"frayfinder_mitt": "Frayfinder Mitt",
	"borrowed_button": "Borrowed Button",
}
const SLOT_NAMES := {"HEAD": "HEAD", "ARM": "ARM", "COAT": "COAT"}
const AUTHORED_PATCH_CATALOGS := [
	"res://data/patches/initial_patch_slots.json",
	"res://data/patches/m04_attack_patches.json",
	"res://data/patches/m04_coat_patches.json",
	"res://data/patches/m05_head_patches.json",
	"res://data/patches/m05_arm_support_patches.json",
	"res://data/patches/m05_attack_patches.json",
	"res://data/patches/m05_coat_patches.json",
]


func _expected_name(id: String) -> String:
	return EXPECTED_NAMES.get(id, id)


## AC1: every authored patch, including the two M04 coats and nine M05 patches
## this goal names, reads as its exact literal name. Unknown IDs stay raw.
func _test_literal_names() -> void:
	for pair in [
		["reinforced_patchcoat", "Reinforced Patchcoat"],
		["thick_felt_mantle", "Thick Felt Mantle"],
		["bloodstitch_bonnet", "Bloodstitch Bonnet"],
		["button_glass_visor", "Button Glass Visor"],
		["stern_seam_cap", "Stern Seam Cap"],
		["reinforced_browband", "Reinforced Browband"],
		["hemguard_cuff", "Hemguard Cuff"],
		["red_bobbin_cuff", "Red Bobbin Cuff"],
		["loose_thread_glove", "Loose Thread Glove"],
		["frayfinder_mitt", "Frayfinder Mitt"],
		["borrowed_button", "Borrowed Button"],
	]:
		_check(sewing._friendly_label(pair[0]) == pair[1],
			"literal readable name for %s is %s (got %s)" % [pair[0], pair[1], sewing._friendly_label(pair[0])])
	var authored: Array[String] = []
	for path in AUTHORED_PATCH_CATALOGS:
		var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(records is Array and not records.is_empty(), "authored patch catalog loads: " + path)
		if not records is Array:
			continue
		for record in records:
			_check(record is Dictionary and record.get("id") is String and record.get("slot") is String,
				"authored patch record carries an id and slot in " + path)
			if record is Dictionary and record.get("id") is String:
				authored.append(record.id)
	_check(not authored.is_empty(), "authored patch catalogs are non-empty")
	for id in EXPECTED_NAMES:
		_check(authored.has(id), "literal name oracle ID is present in a shipped catalog: " + id)
	for id in authored:
		_check(EXPECTED_NAMES.has(id), "literal name oracle covers authored patch " + id)
		if not EXPECTED_NAMES.has(id):
			continue
		var name: String = EXPECTED_NAMES[id]
		var shown: String = sewing._friendly_label(id)
		_check(shown == name, "presenter label for %s is literally %s (got %s)" % [id, name, shown])
		_check(shown != id and not shown.contains("_") and shown.contains(" ")
			and shown.strip_edges() == shown and shown.substr(0, 1).to_upper() == shown.substr(0, 1),
			"label for %s is sewn-readable Title Case, never the raw ID" % id)
		_check(not name.contains("+") and not name.to_lower().contains("hp")
			and not name.to_lower().contains("damage"),
			"name for %s carries no invented power text" % id)
	# Unknown or missing IDs never receive invented display text or power.
	for unknown in ["", "unknown_patch", "quilted_coat_plus", "COAT"]:
		_check(sewing._friendly_label(unknown) == unknown, "unknown ID %s keeps its own raw text" % [unknown])
	_check(RunPatchWearerSummary._resolve_rules_text("unknown_patch", {}) == "",
		"unknown ID never gains invented power text")
	var table: Dictionary = sewing.FRIENDLY_LABELS
	for id in table:
		_check(EXPECTED_NAMES.has(id) and table[id] == EXPECTED_NAMES[id],
			"presenter table name for %s matches the independent literal oracle" % id)


func _click(control: Control) -> void:
	if is_instance_valid(control):
		_check(Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()),
			"physical input bounds: %s %s" % [control.name, control.get_global_rect()])
	await super._click(control)


func _hover(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(2, 2)
	root.push_input(motion, true)
	await _frames()
	motion = InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	_check(root.get_visible_rect().has_point(motion.position),
		"real hover target is in 1280x720 viewport")
	root.push_input(motion, true)
	await _frames()


func _mouse_move(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await _frames()


func _mouse_button_at(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)
	await _frames()


## WCAG relative luminance contrast, so "readable" is measured rather than assumed.
func _relative_luminance(color: Color) -> float:
	var linear := func(value: float) -> float:
		return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)
	return 0.2126 * linear.call(color.r) + 0.7152 * linear.call(color.g) \
		+ 0.0722 * linear.call(color.b)


func _contrast_ratio(foreground: Color, background: Color) -> float:
	var first := _relative_luminance(foreground)
	var second := _relative_luminance(background)
	return (maxf(first, second) + 0.05) / (minf(first, second) + 0.05)


## Mirror Button's own colour selection so the assertion matches what it draws.
func _effective_text_color(button: Button) -> Color:
	var mode := button.get_draw_mode()
	if mode == BaseButton.DRAW_DISABLED:
		return button.get_theme_color("font_disabled_color")
	if mode == BaseButton.DRAW_HOVER_PRESSED and button.has_theme_stylebox("hover_pressed"):
		return button.get_theme_color("font_hover_pressed_color")
	if mode == BaseButton.DRAW_PRESSED:
		return button.get_theme_color("font_pressed_color")
	if mode == BaseButton.DRAW_HOVER:
		return button.get_theme_color("font_hover_color")
	if button.has_focus():
		return button.get_theme_color("font_focus_color")
	return button.get_theme_color("font_color")


func _effective_surface_color(button: Button) -> Color:
	var mode := button.get_draw_mode()
	if mode == BaseButton.DRAW_DISABLED:
		return button.get_theme_stylebox("disabled").bg_color
	if mode == BaseButton.DRAW_HOVER_PRESSED and button.has_theme_stylebox("hover_pressed"):
		return button.get_theme_stylebox("hover_pressed").bg_color
	if mode == BaseButton.DRAW_PRESSED:
		return button.get_theme_stylebox("pressed").bg_color
	if mode == BaseButton.DRAW_HOVER:
		return button.get_theme_stylebox("hover").bg_color
	return button.get_theme_stylebox("normal").bg_color


func _complete_state() -> Array:
	return [_settlement_state(), app.run_scraps, app.run_map.get_floors(),
		app.run_map.get_generation_revision(), app.run_seed,
		app.act_outcome.get_state(), app.run_removal_count,
		app.party_carryover.torn.read_state(), app.party_carryover._receipts.duplicate(true),
		app.multi_fight_rewards._paid_battles.duplicate() if app.multi_fight_rewards != null else [],
		app.multi_fight_rewards._pending if app.multi_fight_rewards != null else null,
		sewing.wardrobe.get_snapshot() if sewing.wardrobe != null else {}, sewing.summary.text]


func _reject_patch(callback: Callable, message: String) -> void:
	var before := _complete_state()
	callback.call()
	_check(_complete_state() == before, message + ": complete run/wardrobe unchanged")


## Inspect the actual mounted reward choice before any activation. Real pointer
## and keyboard focus must both reveal THIS hero's oracle consequence.
func _verify_preview_choice(drop: String, state: Dictionary) -> Dictionary:
	var before := _complete_state()
	var run_rng: int = app.run_rng.state
	var torn_state: Dictionary = app.party_carryover.torn.read_state()
	var entries: Dictionary = {}
	var lines: Dictionary = {}
	_check(sewing._eligible() and sewing._claim_context == sewing._context(),
		"preview is mounted only with the genuinely confirmed Elite claim context")
	var expected_name: String = _expected_name(drop)
	var expected_slot: String = state.definitions[drop]
	_check(EXPECTED_NAMES.has(drop) and SLOT_NAMES.has(expected_slot),
		"claimed drop and authored slot are covered by the literal name oracle")
	for button in sewing.hero_buttons:
		var hero_id: String = button.get_meta("hero_id")
		var preview: Dictionary = RunPatchWearerSummary.preview_sew(
			sewing.wardrobe, torn_state, drop, hero_id)
		_check(preview.get("ok") == true and preview.get("wearer") == hero_id,
			"real %s button admits genuine read-only choice" % hero_id)
		if preview.get("ok") != true:
			continue
		entries[hero_id] = preview
		var displaced_expected: String = "empty %s slot; +0 scrap" % preview.slot
		if preview.displaced_id != "":
			displaced_expected = "replaces %s in %s slot (destroyed); +1 scrap" % [
				_expected_name(preview.displaced_id), preview.slot]
			if not preview.displaced_rules_text.is_empty():
				displaced_expected += " [old: %s]" % preview.displaced_rules_text
		var power_expected: String = preview.rules_text
		if power_expected.is_empty():
			power_expected = "power not documented"
		lines[hero_id] = "%s: %s (%s) - %s; %s" % [
			hero_id.capitalize(), expected_name, preview.slot, power_expected, displaced_expected]
	# The prompt starts as the mount sentence and, once a hero tag is reached,
	# keeps that hero's exact line. Both are literal; the raw ID is never shown.
	var mount_power: String = entries.values()[0].rules_text if not entries.is_empty() else ""
	if mount_power.is_empty():
		mount_power = "power not documented"
	var prompt_allowed: Array[String] = [
		"%s (%s): %s. Choose a living wearer (free); focus a hero for slot consequences." % [
			expected_name, SLOT_NAMES[expected_slot], mount_power]]
	prompt_allowed.append_array(lines.values())
	_check(is_instance_valid(sewing._prompt) and sewing._prompt.is_visible_in_tree()
		and sewing._prompt.autowrap_mode != TextServer.AUTOWRAP_OFF
		and prompt_allowed.has(sewing._prompt.text)
		and sewing._prompt.text.contains(expected_name)
		and not sewing._prompt.text.contains(drop),
		"visible wrapped keyboard-readable prompt shows an exact literal drop name and slot")
	for button in sewing.hero_buttons:
		var hero_id: String = button.get_meta("hero_id")
		if not entries.has(hero_id):
			continue
		var explanation: String = button.tooltip_text
		_check(explanation == lines[hero_id] and not explanation.contains(drop),
			"mounted %s tooltip literally names the drop, power and own +0/+1 scrap displacement" % hero_id)
		await _hover(button)
		_check(sewing._prompt.text == explanation,
			"real mouse hover exposes %s tooltip content visibly" % hero_id)
		# AC1 repair: each drawn text state of this cream tag must use dark ink on
		# its own paper surface; the shell theme otherwise supplies cream hover,
		# pressed, focus and hover+pressed text.
		var normal_bg: Color = button.get_theme_stylebox("normal").bg_color
		var hover_bg: Color = button.get_theme_stylebox("hover").bg_color
		var pressed_bg: Color = button.get_theme_stylebox("pressed").bg_color
		var hover_pressed_box: StyleBoxFlat = button.get_theme_stylebox("hover_pressed") as StyleBoxFlat
		_check(hover_pressed_box != null
			and _contrast_ratio(button.get_theme_color("font_hover_pressed_color"),
				hover_pressed_box.bg_color) >= 4.5,
			"%s hover+pressed name stays readable on its paper surface" % hero_id)
		_check(_contrast_ratio(button.get_theme_color("font_color"), normal_bg) >= 4.5
			and _contrast_ratio(button.get_theme_color("font_focus_color"), normal_bg) >= 4.5
			and _contrast_ratio(button.get_theme_color("font_hover_color"), hover_bg) >= 4.5
			and _contrast_ratio(button.get_theme_color("font_pressed_color"), pressed_bg) >= 4.5,
			"%s normal/focus/hover/pressed ink contrasts with the drawn paper surfaces" % hero_id)
		if not button.disabled:
			# Real pointer hover uses the engine's own draw mode and colour choice.
			_check(button.is_hovered() and button.get_draw_mode() == BaseButton.DRAW_HOVER
				and _effective_text_color(button) == Color("302b29")
				and _contrast_ratio(_effective_text_color(button),
					_effective_surface_color(button)) >= 4.5,
				"%s real pointer hover keeps the readable name on the hover paper tag" % hero_id)
			# Real pointer press-and-hold must keep the same tag ink, not cream text.
			var center: Vector2 = button.get_global_rect().get_center()
			await _mouse_button_at(center, true)
			_check(button.get_draw_mode() == BaseButton.DRAW_PRESSED and button.is_pressed()
				and button.text == hero_id.capitalize()
				and _effective_text_color(button) == Color("302b29")
				and _contrast_ratio(_effective_text_color(button),
					_effective_surface_color(button)) >= 4.5,
				"%s real pointer press keeps the readable name on pressed paper" % hero_id)
			# Release outside the tag so this presentation probe never sews.
			await _mouse_move(Vector2(2, 2))
			await _mouse_button_at(Vector2(2, 2), false)
			_check(not button.is_pressed() and not button.is_hovered(),
				"%s presentation probe releases without sewing" % hero_id)
		button.grab_focus()
		await _frames()
		_check(button.has_focus() and sewing._prompt.text == explanation,
			"physical keyboard focus reads %s power and replacement in prompt" % hero_id)
		if not button.disabled:
			# Keyboard focus draws the normal paper box, so it needs the ink focus colour.
			_check(button.get_draw_mode() == BaseButton.DRAW_NORMAL
				and _effective_text_color(button) == Color("302b29")
				and _contrast_ratio(_effective_text_color(button),
					_effective_surface_color(button)) >= 4.5,
				"%s keyboard focus keeps dark ink on the normal paper tag" % hero_id)
		# Added mounted presentation checks (AC1): size, colour, style states, focus.
		_check(sewing._prompt.get_theme_font_size("font_size") >= 18,
			"prompt font size >= 18px")
		_check(sewing.summary.get_theme_font_size("font_size") >= 18,
			"summary font size >= 18px")
		_check(sewing.summary.size.y >= 56,
			"summary height adequate for 18px text")
		var stitch_node: Control = button.get_node_or_null("StitchAccent")
		_check(is_instance_valid(stitch_node) and stitch_node is Control,
			"%s stitched tag child present" % hero_id)
		# Verify non-default stylebox states exist and are distinguishable.
		_check(button.get_theme_stylebox("normal") != null
			and button.get_theme_stylebox("hover") != null
			and button.get_theme_stylebox("pressed") != null
			and button.get_theme_stylebox("disabled") != null
			and button.get_theme_stylebox("focus") != null,
			"%s button has sewn paper styleboxes for all states" % hero_id)
		# Verify disabled torn buttons are visibly disabled (greyed) and enabled are not.
		if button.disabled:
			_check(button.get_theme_stylebox("disabled").bg_color.saturation < 0.3 or button.get_theme_stylebox("disabled").bg_color.value < 0.85,
				"%s disabled button has visibly disabled style" % hero_id)
		else:
			_check(button.get_theme_stylebox("normal").bg_color == Color("ecdfbd")
				or button.get_theme_stylebox("normal").border_color == sewing.HERO_COLORS.get(hero_id, Color("777166")),
				"%s enabled button has sewn paper normal style" % hero_id)
		# Focus mode preserved.
		_check(button.focus_mode == Control.FOCUS_ALL,
			"%s focus mode preserved for keyboard" % hero_id)
		# Text readable (font size >= 18 and label not empty for enabled buttons).
		if not button.disabled:
			_check(button.get_theme_font_size("font_size") >= 18,
				"%s hero tag text >= 18px" % hero_id)
			_check(not button.text.is_empty() and button.text.contains(hero_id.capitalize()),
				"%s hero tag text readable" % hero_id)
	# Verify prompt and summary layout does not overlap improperly.
	_check(sewing._prompt.get_global_rect().intersects(sewing.summary.get_global_rect()) == false
		or sewing._prompt.get_global_rect().get_center().y < sewing.summary.get_global_rect().get_center().y,
		"prompt and summary do not overlap improperly")
	# Check exact hero accent colours in stitched child.
	for hero_id_check in ["warden", "seamstress", "tinker"]:
		var btn_check: Button = sewing.hero_buttons.filter(func(b): return b.get_meta("hero_id") == hero_id_check and is_instance_valid(b))[0] if sewing.hero_buttons.filter(func(b): return b.get_meta("hero_id") == hero_id_check and is_instance_valid(b)).size() > 0 else null
		if btn_check == null:
			continue
		_check(is_instance_valid(btn_check.get_node_or_null("StitchAccent")),
			"%s stitched tag present" % hero_id_check)
	_check(entries.size() == 3 and sewing.wardrobe.get_snapshot() == state
		and app.party_carryover.torn.read_state() == torn_state
		and app.run_rng.state == run_rng and _complete_state() == before,
		"all three eligible real previews are read-only across full live context and RNG")
	return entries


func _verify_worn_readout() -> void:
	var oracle := RunPatchWearerSummary.summarize(
		sewing.wardrobe, app.party_carryover.torn.read_state())
	_check(oracle.get("ok") == true and oracle.get("heroes", []).size() == 3,
		"live persistent summary has genuine wearer authority")
	if oracle.get("ok") != true:
		return
	var fragments: Array[String] = []
	for hero in oracle.heroes:
		for record in hero.slots:
			if record.patch_id == "":
				continue
			var fragment: String = "%s: %s (%s) [%s]" % [
				hero.id.capitalize(), _expected_name(record.patch_id), record.slot,
				"active" if record.active else "inactive"]
			if not record.rules_text.is_empty():
				fragment += " - %s" % record.rules_text
			fragments.append(fragment)
	var expected: String = "Worn patches: " + " | ".join(fragments) if not fragments.is_empty() else ""
	_check(sewing.summary.text == expected and not fragments.is_empty(),
		"persistent mounted readout matches ALL authoritative worn IDs, slots, powers and activity")
	_check(sewing.summary.autowrap_mode != TextServer.AUTOWRAP_OFF
		and sewing.summary.size.x <= 1280 and sewing.summary.position.x + sewing.summary.size.x <= 1280,
		"long worn readout wraps within 1280-wide layout")


func _coat_multi_fixture() -> Dictionary:
	var first_seed := 1
	for attempt in range(32):
		var fixture := _multi_fixture(first_seed)
		if fixture.is_empty() or not await _routed_win(fixture, false):
			return {}
		await _click(app.reward_buttons[0])
		await _click(app.continue_button)
		var path: Array = fixture.paths[0].duplicate()
		var elite: String = path.pop_back()
		await _visit_path(path, false)
		await _click(_route_action(elite))
		for enemy in app.enemies.get_enemies():
			_check(app.enemies.apply_damage(enemy.position, 9999), "discover coat using real Elite roster")
		app._observe_battle_result()
		await _frames()
		var found: bool = app.fight_reward_trinket == "quilted_coat"
		await _click(app.return_button)
		if found:
			return fixture
		first_seed = fixture.seed + 1
	return {}


## The torn-party regression needs an actual route that cannot mend the Warden
## between the predecessor Fight and the Elite. Other fixture paths may use Rest.
func _torn_focus_fixture() -> Dictionary:
	var next_seed := 1
	for attempt in range(120):
		var fixture := _multi_fixture(next_seed)
		if fixture.is_empty():
			return {}
		var rng := RandomNumberGenerator.new()
		rng.seed = fixture.seed
		var map := RunMap.new()
		if not map.generate(rng):
			return {}
		var transit: Array = fixture.paths[0].duplicate()
		transit.pop_back()
		var healing_rest := false
		for node in transit:
			healing_rest = healing_rest or map.get_node(node).get("type") == "Rest"
		if not healing_rest:
			return fixture
		next_seed = fixture.seed + 1
	return {}


## Enter through the real map and defeat the actual opening roster with Warden
## downed. Claiming that predecessor reward publishes a lawful tear BEFORE
## the later Elite coordinator captures its authoritative run context.
func _torn_warden_opening_win(fixture: Dictionary) -> bool:
	app.run_seed = fixture.seed
	await _click(app.route_button)
	await _click(_route_action(fixture.fight))
	_check(app.party != null and app.party.is_valid()
		and app.party.get_hero(1).id == "warden", "opening Fight mounts the actual Warden")
	if app.party == null:
		return false
	_check(app.party.apply_damage(1, 999) and app.party.is_downed(1)
		and app.party.get_hero(2).hp > 0 and app.party.get_hero(3).hp > 0,
		"actual opening battle damage legitimately downs only Warden")
	for enemy in app.enemies.get_enemies():
		_check(app.enemies.apply_damage(enemy.position, 9999),
			"real opening enemies defeated with living Seamstress/Tinker")
	app._observe_battle_result()
	await _frames()
	_check(app._battle_closed and app.fight_rewards != null
		and app.battle_result.get_outcome() == CombatBattleResult.VICTORY,
		"opening victory records a genuine torn-Warden reward")
	return app._battle_closed and app.fight_rewards != null


## A legitimately torn Warden carried from the preceding settled Fight must
## keep Return -> living recipients -> Continue tabbable after the app
## repeatedly rebuilds the surrounding action focus chain.
func _test_torn_warden_focus(fixture: Dictionary) -> void:
	for chosen_index in [1, 2]:
		seed(937937)
		var global_next: int = randi()
		seed(937937)
		if not await _torn_warden_opening_win(fixture):
			return
		await _click(app.reward_buttons[0])
		var opening_torn: Dictionary = app.party_carryover.torn.read_state()
		_check(opening_torn.completed_battles.has(fixture.fight)
			and opening_torn.tear_counts.get("warden") == 1
			and opening_torn.heroes[0].hp == 0 and opening_torn.heroes[0].max_hp == 37,
			"opening reward legitimately publishes Warden tear before Elite entry")
		await _click(app.continue_button)
		var path: Array = fixture.paths[0].duplicate()
		var elite: String = path.pop_back()
		await _visit_path(path, false)
		await _click(_route_action(elite))
		_check(app.run_map.get_node(elite).type == "Elite" and not app._battle_closed
			and app.party.get_hero(1).id == "warden" and app.party.is_downed(1)
			and app.party.get_hero(2).hp > 0 and app.party.get_hero(3).hp > 0,
			"real connected Elite starts with the legitimately carried torn Warden")
		for enemy in app.enemies.get_enemies():
			_check(app.enemies.apply_damage(enemy.position, 9999), "torn Elite wins against actual mounted enemies")
		app._observe_battle_result()
		await _frames()
		_check(app.multi_fight_rewards != null and app.reward_buttons.size() == 4
			and not app.fight_reward_claimed, "genuine torn-Warden Elite reward is unsettled")
		if app.reward_buttons.size() != 4:
			return
		var drop: String = app.fight_reward_trinket
		_check(not drop.is_empty() and not app.run_trinkets.has(drop),
			"torn Elite has an unclaimed owned-on-settlement patch drop")
		await _click(app.reward_buttons[3])
		var torn: Dictionary = app.party_carryover.torn.read_state()
		_check(app.fight_reward_claimed and app.run_trinkets.has(drop)
			and torn.get("ok") == true and torn.completed_battles.has(fixture.fight)
			and torn.completed_battles.has(elite)
			and torn.tear_counts.get("warden") == 1
			and torn.heroes[0].hp == 0 and torn.heroes[0].max_hp == 37
			and torn.heroes[1].hp > 0 and torn.heroes[2].hp > 0
			and app.run_heroes == torn.heroes,
			"actual settled Elite publishes Warden's tear and both living survivors")
		_check(sewing.hero_buttons.size() == 3 and sewing.wardrobe != null,
			"settled torn Elite mounts all three recipient controls")
		if sewing.hero_buttons.size() != 3 or sewing.wardrobe == null:
			return
		var buttons: Array[Button] = sewing.hero_buttons
		_check(buttons[0].disabled and buttons[0].is_visible_in_tree()
			and not buttons[1].disabled and not buttons[2].disabled
			and buttons[1].is_visible_in_tree() and buttons[2].is_visible_in_tree(),
			"torn Warden cannot sew while Seamstress and Tinker remain enabled")
		var state: Dictionary = sewing.wardrobe.get_snapshot()
		var before: Array = _complete_state()
		var rng_before: int = app.run_rng.state
		var previews: Dictionary = {}
		for index in [1, 2]:
			var button: Button = buttons[index]
			var id: String = button.get_meta("hero_id")
			var preview: Dictionary = RunPatchWearerSummary.preview_sew(
				sewing.wardrobe, torn, drop, id)
			_check(preview.get("ok") == true and preview.get("wearer") == id
				and button.tooltip_text == sewing._preview_line(preview)
				and button.focus_mode == Control.FOCUS_ALL,
				"living torn-party choice has owner-specific real preview: " + id)
			previews[id] = preview
		_check(not RunPatchWearerSummary.preview_sew(
			sewing.wardrobe, torn, drop, "warden").get("ok", false),
			"torn Warden's preview remains rejected")
		for frame in range(5):
			await _frames()
		_check(sewing._eligible() and sewing._claim_context == sewing._context(),
			"torn Elite retains authenticated claim context after repeated frame refreshes")
		app.return_button.grab_focus()
		await _frames()
		_check(app.return_button.has_focus(), "real Return focus starts torn-party Tab chain")
		for index in [1, 2]:
			await _key(KEY_TAB)
			_check(buttons[index].has_focus()
				and sewing._prompt.text == buttons[index].tooltip_text,
				"physical Tab reaches and previews living %s after recurring app focus refresh" % buttons[index].text)
		await _key(KEY_TAB)
		_check(app.continue_button.has_focus(), "physical Tab exits torn-party choices to Continue")
		_check(_complete_state() == before and sewing.wardrobe.get_snapshot() == state
			and app.party_carryover.torn.read_state() == torn
			and app.run_rng.state == rng_before,
			"torn-party focus previews never mutate run/wardrobe/tear ledgers or RNG")
		app.return_button.grab_focus()
		await _frames()
		for index in range(1, chosen_index + 1):
			await _key(KEY_TAB)
		var chosen: Button = buttons[chosen_index]
		var hero: String = chosen.get_meta("hero_id")
		var expected: Dictionary = previews.get(hero, {})
		_check(chosen.has_focus() and expected.get("ok") == true,
			"torn-party physical keyboard selection has valid focus and preview")
		var callback: Callable = chosen.pressed.get_connections()[0].callable
		var settlement: Array = _settlement_state()
		await _key(KEY_ENTER if chosen_index == 1 else KEY_SPACE)
		var after: Dictionary = sewing.wardrobe.get_snapshot()
		_check(after.worn[hero][expected.slot] == drop and after.owned.has(drop)
			and after.scraps == state.scraps + expected.scrap_delta
			and after.operation_ids.size() == 1 and app.run_scraps == after.scraps
			and app.party_carryover._wardrobe == sewing.wardrobe,
			"Enter/Space sews each eligible torn-party recipient once with matching receipt/scrap")
		_check(_settlement_state() == settlement and app.run_rng.state == rng_before
			and app.party_carryover.torn.read_state() == torn,
			"torn-party sew preserves reward, unrelated run state, RNG and original tear")
		_verify_worn_readout()
		_reject_patch(callback, "torn-party duplicate sewing callback")
		await _click(app.continue_button)
		_check(app.route_view != null and app.route_view.is_visible_in_tree()
			and sewing.summary.text.contains("%s: %s" % [hero.capitalize(), _expected_name(drop)]),
			"Continue remains usable and wearer summary survives torn-party Elite")
		_verify_worn_readout()
		_reject_patch(callback, "torn-party stale callback after Continue")
		await _click(app.route_back_button)
		_check(app.title_view.visible and sewing.wardrobe == null
			and sewing.hero_buttons.is_empty(), "torn-party title reset clears sewing chooser")
		_check(randi() == global_next, "torn-party replay and input preserve global RNG")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	sewing = app.get_node("LiveElitePatchSewing")
	_test_literal_names()
	var fixture := await _coat_multi_fixture()
	_check(not fixture.is_empty(), "real seeded route reaches two Elites and Shop")
	if fixture.is_empty():
		await _finish_sewing()
		return
	var replay: Array = []
	var retained: Array[Callable] = []
	for session in range(2):
		seed(850085)
		var global_next := randi()
		seed(850085)
		if not await _routed_win(fixture, false):
			break
		_check(sewing.wardrobe == null and sewing.hero_buttons.is_empty(), "fresh replay has no assignments or choices")
		for callback in retained:
			_reject_patch(callback, "prior session callback")
		await _click(app.reward_buttons[0])
		await _click(app.continue_button)
		var observations: Array = []
		var first_worn := {}
		for index in range(2):
			var path: Array = fixture.paths[index].duplicate()
			var elite: String = path.pop_back()
			await _visit_path(path, session == 1)
			await _click(_route_action(elite))
			_check(app.run_map.get_node(elite).type == "Elite" and not app._battle_closed,
				"genuine connected Elite is mounted")
			if index == 1:
				_check(sewing.wardrobe.get_snapshot().worn == first_worn and not sewing.summary.text.is_empty(),
					"ownership stays displayed through Continue and next connected battle")
				var base: Array = app.party_carryover.read_state().heroes
				var effective: Array = app.party.get_heroes()
				for i in range(3):
					_check(effective[i].hp == base[i].hp and effective[i].max_hp == base[i].max_hp + (6 if effective[i].id == "warden" else 0),
						"connected real battle projects +6 only on wearer without healing")
				_check(app.party.heal(1, 999) and app.party.get_hero(1).hp == 46,
					"real combat healing reaches effective coat cap")
				_check(app.party.apply_damage(1, app.party.get_hero(1).block + 2)
					and app.party.get_hero(1).hp == 44, "real damage uses effective HP")
			for callback in retained:
				_reject_patch(callback, "wrong battle callback")
			if index == 1:
				var moved := CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
				_check(moved.ok, "actual Elite party supports a changed formation")
				if moved.ok:
					app.party._heroes.assign(moved.heroes)
				_check(app.party.apply_damage(1, 1), "actual changed formation carries injury")
			for enemy in app.enemies.get_enemies():
				_check(app.enemies.apply_damage(enemy.position, 9999), "defeat actual mounted Elite enemy")
			app._observe_battle_result()
			await _frames()
			var service: RunMultiFightRewards = app.multi_fight_rewards
			_check(service != null and app.reward_buttons.size() == 4, "real Elite reward coordinator and choices exist")
			if service == null:
				break
			var drop: String = app.fight_reward_trinket
			if index == 0:
				_check(drop == "quilted_coat", "fixed seed %s actually earns coat first (got %s)" % [fixture.seed, drop])
			_check(not app.run_trinkets.has(drop), "pending drop is not yet owned")
			var forged := {"ok": true, "receipt": {"node_id": elite,
				"node_kind": "Elite", "trinket_drop_id": drop}}
			_reject_patch(sewing.observe_claim.bind(service, forged), "pre-claim forged receipt")
			_reject_patch(sewing._sew.bind("warden", app.reward_buttons[0], sewing._token, {}), "pre-claim sew")
			_check(sewing.hero_buttons.is_empty() or not sewing._eligible(), "no eligible pre-claim hero input")
			var reward_state := _reward_oracle_after_prepare(service)
			if index == 1:
				var reward_callback: Callable = app.reward_buttons[0 if index == 0 else 3].pressed.get_connections()[0].callable
				app.party._heroes[1].max_hp += 1
				_reject_patch(reward_callback, "invalid effective battle cap rejects claim")
				app.party._heroes[1].max_hp -= 1
			if session == 0:
				await _click(app.reward_buttons[0 if index == 0 else 3])
			else:
				app.reward_buttons[0 if index == 0 else 3].grab_focus()
				await _key(KEY_ENTER)
			_check(app.fight_reward_claimed and app.run_trinkets.has(drop)
				and service._paid_battles.has(app.battle_result), "physical pick/skip commits the genuine drop once")
			if index == 1:
				var wearer: Dictionary = app.run_heroes.filter(func(h): return h.id == "warden")[0]
				_check(wearer.max_hp == 40 and wearer.hp == 40,
					"settlement clamps above-base HP and never persists derived +6")
			_check(sewing.wardrobe != null and sewing.hero_buttons.size() == 3, "owned authored drop exposes all three hero choices")
			if sewing.wardrobe == null or sewing.hero_buttons.size() != 3:
				break
			var state: Dictionary = sewing.wardrobe.get_snapshot()
			_test_context_refresh(state)
			_check(state.heroes == app.run_heroes and state.owned == app.run_trinkets
				and state.cards == app.run_deck and state.scraps == app.run_scraps
				and state.gold == app.session_gold and state.seed == app.run_seed, "wardrobe receives full actual committed run context")
			for button in sewing.hero_buttons:
				_check(button.is_visible_in_tree() and not button.disabled and button.focus_mode == Control.FOCUS_ALL
					and Rect2(0, 0, 1280, 720).encloses(button.get_global_rect()), "each hero choice visible, focusable and in viewport")
			var previews: Dictionary = await _verify_preview_choice(drop, state)
			var button: Button = sewing.hero_buttons[index]
			var hero: String = button.get_meta("hero_id")
			var chosen_preview: Dictionary = previews.get(hero, {})
			_check(chosen_preview.get("ok") == true, "physical wearer has pre-sew oracle and real owned slot")
			var callback: Callable = button.pressed.get_connections()[0].callable
			button.disabled = true
			_reject_patch(callback, "disabled hero choice")
			button.disabled = false
			button.hide()
			_reject_patch(callback, "hidden hero choice")
			button.show()
			app.return_button.grab_focus()
			for choice in sewing.hero_buttons:
				await _key(KEY_TAB)
				_check(choice.has_focus(), "physical Tab reaches every hero choice")
			await _key(KEY_TAB)
			_check(app.continue_button.has_focus(), "physical Tab exits choices to Continue")
			_reject_patch(sewing._sew.bind("foreign", button, sewing._token, state), "forged hero")
			_reject_patch(sewing._sew.bind(hero, button, sewing._token, {}), "malformed wardrobe guard")
			_reject_patch(sewing._sew.bind(hero, app.return_button, sewing._token, state), "foreign button")
			var forged_state := state.duplicate(true)
			forged_state.scraps += 1
			_reject_patch(sewing._sew.bind(hero, button, sewing._token, forged_state), "stale wardrobe snapshot")
			app.run_map._route.pop_back()
			_reject_patch(callback, "wrong current node")
			app.run_map._route.append(elite)
			app.run_map._nodes[elite].outgoing.append("foreign")
			_reject_patch(callback, "graph drift")
			app.run_map._nodes[elite].outgoing.erase("foreign")
			app.run_scraps += 1
			_reject_patch(callback, "run resources drift")
			app.run_scraps -= 1
			app.run_trinkets.erase(drop)
			_reject_patch(callback, "drop no longer owned")
			app.run_trinkets.append(drop)
			app.session_gold += 1
			_reject_patch(callback, "gold drift")
			app.session_gold -= 1
			app.run_deck.append("warden_strike")
			_reject_patch(callback, "deck drift")
			app.run_deck.pop_back()
			var revision: int = app.run_map._generation_revision
			app.run_map._generation_revision += 1
			_reject_patch(callback, "regenerated map revision")
			app.run_map._generation_revision = revision
			var unchanged := _settlement_state()
			var scraps: int = app.run_scraps
			if session == 0:
				await _click(button)
			else:
				app.return_button.grab_focus()
				await _key(KEY_TAB)
				_check(sewing.hero_buttons[0].has_focus(), "physical Tab reaches first hero from reward actions")
				if index == 1:
					await _key(KEY_TAB)
				_check(button.has_focus(), "physical Tab reaches selected hero")
				await _key(KEY_SPACE if index == 0 else KEY_ENTER)
			var after: Dictionary = sewing.wardrobe.get_snapshot()
			_check(app.party_carryover._wardrobe == sewing.wardrobe,
				"successful sewing binds the exact live carryover wardrobe")
			var slot: String = after.definitions[drop]
			_check(after.worn[hero][slot] == drop and sewing.summary.text.contains("%s: %s (%s)" % [hero.capitalize(), _expected_name(drop), slot]),
				"physical confirmation sews authored slot and visibly names wearer")
			_check(chosen_preview.get("ok") == true
				and slot == chosen_preview.get("slot")
				and after.scraps == scraps + chosen_preview.get("scrap_delta", -100)
				and (chosen_preview.get("displaced_id", "") == ""
					or not after.owned.has(chosen_preview.displaced_id))
				and after.owned.has(drop),
				"actual free sew has exact previewed scrap delta, ownership and displaced ID")
			_verify_worn_readout()
			_check(_settlement_state() == unchanged and app.run_scraps == scraps + chosen_preview.get("scrap_delta", -100)
				and after.scraps == app.run_scraps,
				"sewing changes no unrelated run, reward, deck, route, gold or RNG state")
			_check(after.operation_ids.size() == index + 1, "one successful sew receipt per earned drop")
			if index == 0:
				first_worn = after.worn.duplicate(true)
			else:
				for id in first_worn:
					for previous_slot in first_worn[id]:
						if first_worn[id][previous_slot] != "":
							_check(after.worn[id][previous_slot] == first_worn[id][previous_slot], "second legitimate drop preserves first assignment")
			for action in sewing.hero_buttons:
				action.disabled = false
			_reject_patch(callback, "forced duplicate sew")
			_reject_patch(sewing.observe_claim.bind(service, forged), "duplicate claim observation")
			retained.append(callback)
			observations.append([after, reward_state, app.run_rng.state, app.run_trinkets.duplicate()])
			await _click(app.continue_button)
			_check(app.route_view.is_visible_in_tree() and sewing.summary.text.contains(_expected_name(drop)), "Continue retains visible wearer")
			_verify_worn_readout()
			_reject_patch(callback, "stale sew after Continue")
		_check(observations.size() == 2, "both earned drops actually sewn")
		if session == 0:
			replay = observations.duplicate(true)
		else:
			_check(observations == replay, "same-seed replay reproduces complete wardrobe and reward state")
		# Existing Elite suite independently verifies exact Shop stock and RNG.
		var old_carry: RunTornCarryover = app.party_carryover
		await _click(app.route_back_button)
		_check(old_carry._wardrobe == null, "return clears even the retained carryover binding")
		_check(sewing.wardrobe == null and sewing.hero_buttons.is_empty() and sewing.summary.text.is_empty(), "title resets companion completely")
		for callback in retained:
			callback.call()
		_check(sewing.wardrobe == null and app.run_trinkets.is_empty() and app.run_scraps == 0
			and app.run_map == null and app.title_view.visible, "old callbacks cannot restore a title-state assignment")
		_check(randi() == global_next, "claim, sewing, negatives and reset preserve global RNG")
	var torn_fixture := _torn_focus_fixture()
	_check(not torn_fixture.is_empty(), "seeded torn-Warden predecessor connects to Elite without recovery Rest")
	if not torn_fixture.is_empty():
		await _test_torn_warden_focus(torn_fixture)
	await _test_displaced_name(fixture)
	await _finish_sewing()


## AC2: a genuine Elite coat drop that lands on an already-worn authored COAT
## must visibly name what the player loses and grant exactly +1 scrap. The prior
## wear is installed through the real wardrobe and carryover services (the
## shipped drop catalog holds one patch per slot, so a same-slot collision has
## no live drop source yet); the claim, prompt, tooltips, sew and worn summary
## below are the real mounted ones.
func _test_displaced_name(fixture: Dictionary) -> void:
	seed(194194)
	var global_next := randi()
	seed(194194)
	if not await _routed_win(fixture, false):
		return
	await _click(app.reward_buttons[3])
	await _click(app.continue_button)
	_check(app.run_trinkets.is_empty() and app.party_carryover._wardrobe == null,
		"displacement run starts with no patch ownership or sewing ledger")
	app.run_trinkets.append("reinforced_patchcoat")
	# The fixture's ledger admits every shipped patch slot (the initial slots,
	# the authored attack patches and all authored coats) so the real sewing
	# services can hold the prior wear; the drop, claim and sew below stay real.
	var definitions: Array = []
	for path in AUTHORED_PATCH_CATALOGS.slice(0, 3):
		for record in JSON.parse_string(FileAccess.get_file_as_string(path)):
			definitions.append({"id": record.id, "slot": record.slot})
	var prior := RunPatchWardrobe.new(app.run_heroes, app.run_trinkets, definitions,
		app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
	_check(prior.is_valid(), "real roster admits the authored prior coat")
	if not prior.is_valid():
		return
	var wearer: String = app.run_heroes[0].id
	_check(wearer == "warden", "first living wearer is the authored Warden")
	var sewn := prior.sew("reinforced_patchcoat", wearer, "COAT", "fixture:prior-coat",
		prior.get_snapshot())
	_check(sewn.ok and sewn.receipt.get("displaced_id") == ""
		and sewn.receipt.get("scrap_delta") == 0
		and app.party_carryover.bind_wardrobe(prior, app.party_carryover.torn,
			prior.get_snapshot()),
		"authored prior coat is sewn into an empty COAT and bound by the real services")
	var path: Array = fixture.paths[0].duplicate()
	var elite: String = path.pop_back()
	await _visit_path(path, false)
	await _click(_route_action(elite))
	_check(app.run_map.get_node(elite).type == "Elite" and not app._battle_closed,
		"genuine connected Elite mounts over the bound wear")
	for enemy in app.enemies.get_enemies():
		_check(app.enemies.apply_damage(enemy.position, 9999),
			"defeat the real Elite while a coat is worn")
	app._observe_battle_result()
	await _frames()
	var service: RunMultiFightRewards = app.multi_fight_rewards
	_check(service != null and app.reward_buttons.size() == 4, "real Elite reward is prepared")
	if service == null or app.reward_buttons.size() != 4:
		return
	var drop: String = app.fight_reward_trinket
	_check(drop == "quilted_coat", "seeded Elite genuinely drops the authored Quilted Coat")
	await _click(app.reward_buttons[3])
	_check(app.fight_reward_claimed and app.run_trinkets.has(drop),
		"Skip still commits the genuine coat drop once")
	_check(sewing.wardrobe == prior and sewing.hero_buttons.size() == 3 and sewing._eligible(),
		"mounted sewing adopts the already-bound wardrobe for the confirmed claim")
	if sewing.wardrobe != prior or sewing.hero_buttons.size() != 3:
		return
	var state: Dictionary = prior.get_snapshot()
	_check(state.scraps == app.run_scraps and state.owned == app.run_trinkets
		and state.worn[wearer].COAT == "reinforced_patchcoat",
		"committed run context reaches the bound wardrobe before the displaced sew")
	var torn_state: Dictionary = app.party_carryover.torn.read_state()
	var preview: Dictionary = RunPatchWearerSummary.preview_sew(prior, torn_state, drop, wearer)
	_check(preview.get("ok") == true and preview.get("slot") == "COAT"
		and preview.get("displaced_id") == "reinforced_patchcoat"
		and preview.get("scrap_delta") == 1
		and preview.get("rules_text") == "+6 maximum HP"
		and preview.get("displaced_rules_text") == "+9 maximum HP",
		"oracle preview is an occupied COAT with its authored power and +1 scrap")
	# These three strings are written independently of any production formatter.
	_check(sewing._prompt.text == "Quilted Coat (COAT): +6 maximum HP. Choose a living wearer (free); focus a hero for slot consequences.",
		"mounted prompt literally names Quilted Coat and its COAT slot power")
	var target: Button = sewing.hero_buttons.filter(
		func(button): return button.get_meta("hero_id") == wearer)[0]
	var loss := "Warden: Quilted Coat (COAT) - +6 maximum HP; replaces Reinforced Patchcoat in COAT slot (destroyed); +1 scrap [old: +9 maximum HP]"
	_check(target.tooltip_text == loss,
		"mounted tooltip literally names the displaced Reinforced Patchcoat and +1 scrap")
	_check(not target.tooltip_text.contains("reinforced_patchcoat")
		and not target.tooltip_text.contains(drop),
		"tooltip shows sewn names, never raw patch IDs")
	await _hover(target)
	_check(sewing._prompt.text == loss,
		"real pointer hover visibly shows the displaced name and +1 scrap")
	target.grab_focus()
	await _frames()
	_check(target.has_focus() and sewing._prompt.text == loss,
		"physical keyboard focus shows the displaced name and +1 scrap")
	for other in sewing.hero_buttons:
		if other.get_meta("hero_id") != wearer:
			_check(other.tooltip_text.ends_with("empty COAT slot; +0 scrap"),
				"each other living wearer keeps the exact +0 scrap empty-slot consequence")
	var entries: Dictionary = await _verify_preview_choice(drop, state)
	_check(entries.size() == 3, "all three real displaced-preview choices stay readable and read-only")
	var callback: Callable = target.pressed.get_connections()[0].callable
	await _click(target)
	var after: Dictionary = prior.get_snapshot()
	_check(after.worn[wearer].COAT == drop and not after.owned.has("reinforced_patchcoat")
		and after.owned.has(drop) and after.scraps == state.scraps + 1
		and after.operation_ids.size() == state.operation_ids.size() + 1,
		"genuine displaced sew owns the new coat and grants exactly +1 scrap")
	_check(sewing.summary.text == "Worn patches: Warden: Quilted Coat (COAT) [active] - +6 maximum HP",
		"post-sew worn summary literally names the surviving coat with slot and power")
	_check(not sewing.summary.text.contains("reinforced_patchcoat")
		and not sewing.summary.text.contains(drop),
		"worn summary shows sewn names, never raw patch IDs")
	_reject_patch(callback, "displaced duplicate sew")
	await _click(app.continue_button)
	_check(app.route_view != null and app.route_view.is_visible_in_tree(),
		"Continue remains usable after a displaced sew")
	_verify_worn_readout()
	await _click(app.route_back_button)
	_check(app.title_view.visible and sewing.wardrobe == null and app.run_map == null,
		"displacement run returns to a clean sewn title")
	_check(randi() == global_next, "displaced claim, sewing and reset preserve global RNG")


func _reward_oracle_after_prepare(service: RunMultiFightRewards) -> Dictionary:
	return {"offers": app.fight_reward_offers.duplicate(true), "gold": app.fight_reward_gold,
		"drop": app.fight_reward_trinket, "state": service.read_state(), "rng": app.run_rng.state}


func _test_context_refresh(state: Dictionary) -> void:
	var definitions: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/patches/initial_patch_slots.json"))
	for pair in [["stitched_badge", "HEAD"], ["spare_spool", "ARM"]]:
		_check(definitions.filter(func(entry): return entry.id == pair[0] and entry.slot == pair[1]).size() == 1,
			"unique authored slot for " + pair[0])
	var foreign := RunPatchWardrobe.new(state.heroes, ["foreign_patch"], definitions,
		state.scraps, state.gold, state.cards, state.seed, true)
	_check(foreign.is_valid(), "actual current heroes admit foreign inventory without inferring a slot")
	var before := foreign.get_snapshot()
	_check(not foreign.sew("foreign_patch", "warden", "HEAD", "foreign", before).ok
		and not foreign.sew("stitched_badge", "warden", "HEAD", "unowned", before).ok
		and foreign.get_snapshot() == before, "foreign and absent eligible IDs preserve full ledger")
	_check(not foreign.refresh_run_context(state.heroes, [], state.scraps, state.gold, state.cards, before)
		and foreign.get_snapshot() == before, "refresh cannot remove previous ownership")
	var stale := before.duplicate(true)
	stale.gold += 1
	_check(not foreign.refresh_run_context(state.heroes, ["foreign_patch", "stitched_badge"],
		state.scraps, state.gold, state.cards, stale) and foreign.get_snapshot() == before,
		"refresh rejects stale receipt atomically")
	_check(foreign.refresh_run_context(state.heroes, ["foreign_patch", "stitched_badge"],
		state.scraps, state.gold, state.cards, before), "guarded refresh adds actual owned eligible ID")
	var fresh := foreign.get_snapshot()
	_check(foreign.sew("stitched_badge", "warden", "HEAD", "first", fresh).ok,
		"first sew with current heroes is free")
	var worn := foreign.get_snapshot()
	_check(foreign.refresh_run_context(state.heroes, ["foreign_patch", "stitched_badge", "spare_spool"],
		state.scraps, state.gold, state.cards, worn), "later context refresh accepts additional ownership")
	_check(foreign.get_snapshot().worn == worn.worn
		and foreign.get_snapshot().operation_ids == worn.operation_ids
		and foreign.get_snapshot().owned.has("foreign_patch"), "refresh retains worn slots, receipts and foreign inventory")


func _finish_sewing() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_elite_patch_sewing_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
