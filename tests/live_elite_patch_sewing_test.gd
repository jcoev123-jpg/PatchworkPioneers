extends "res://tests/live_elite_reward_continuation_test.gd"
## Mounted claim -> free sew -> connected continuation -> second drop -> reset/replay.

var sewing

## Use the acquired patch through the next battle's real held-card input.
func _acquired_attack_check(patch_id: String) -> void:
	_check(app.party != null and app.enemies != null and not app._battle_closed
		and app.party.get_hero(1).id == "warden" and not app.party.is_downed(1),
		"acquired patch reaches a living Warden in a real later battle")
	for id in ["seamstress_prick", "warden_strike"]:
		while not app.deck.hand.has(id) and not app.deck.draw_pile.is_empty():
			_check(app.deck.draw_extra(1) == 1, "draw real owned attack")
		_check(app.deck.hand.has(id), "real deck contains " + id)
	app._refresh_hand()
	await _frames()
	var rng: int = app.run_rng.state
	for id in ["seamstress_prick", "warden_strike"]:
		var cost: int = StarterCards.new().get_definition(id).cost
		var energy: int = app.deck.energy
		var copies: int = app.deck.hand.count(id)
		var discarded: int = app.deck.discard_pile.count(id)
		_check(await _choose(id, false), "physically select acquired-patch attack " + id)
		await _key(KEY_1)
		var event: Dictionary = presenter.last_event
		var damage := 3 if id == "seamstress_prick" else (7 if patch_id == "pincushion_arm" else 6)
		var statuses := {"bleed": 3} if id == "seamstress_prick" else ({"exposed": 1} if patch_id == "button_eye" else {})
		_check(event.get("ok") == true and event.get("hits", []).size() == 1,
			"acquired patch attack actually commits")
		if event.get("ok") == true and event.get("hits", []).size() == 1:
			_check(event.hits[0].damage == damage and event.hits[0].statuses == statuses,
				"only living wearer receives exact authored acquired patch effect")
		_check(app.deck.energy == energy - cost and app.deck.hand.count(id) == copies - 1
			and app.deck.discard_pile.count(id) == discarded + 1 and app.run_rng.state == rng,
			"acquired patch attack spends and discards once without RNG")

## The production shared pool must naturally roll each new drop.
func _attack_patch_claims() -> void:
	## Verified starting seeds are hints only; every offer is still rolled and checked live.
	var drop_seeds := {"button_eye": 962, "pincushion_arm": 2998,
		"HEAD": 61, "ARM": 1848, "COAT": 2010}
	var search_seed := 1
	for patch_id in ["button_eye", "pincushion_arm", "HEAD", "ARM", "COAT"]:
		var next_seed: int = drop_seeds.get(patch_id, search_seed)
		var obtained := false
		for attempt in range(maxi(40, RunAuthoredPatchDefinitions.load_definitions().size() * 8)):
			var fixture := _multi_fixture(next_seed, maxi(30000, next_seed + 10000))
			if not fixture.is_empty():
				search_seed = maxi(search_seed, fixture.seed + 1)
			_check(not fixture.is_empty(), "seeded Elite route exists for " + patch_id)
			if fixture.is_empty():
				return
			var map := RunMap.new()
			var route_rng := RandomNumberGenerator.new()
			route_rng.seed = fixture.seed
			_check(map.generate(route_rng), "real candidate map generates")
			if _path_to(map, fixture.paths[0].back(), "Fight").is_empty():
				next_seed = fixture.seed + 1
				continue
			if not await _routed_win(fixture, false):
				return
			await _click(app.reward_buttons[3])
			await _click(app.continue_button)
			var path: Array = fixture.paths[0].duplicate()
			var elite: String = path.pop_back()
			await _visit_path(path, false)
			await _click(_route_action(elite))
			var rng: int = app.run_rng.state
			var ids: Array = app._catalog_trinket_ids()
			for definition in RunAuthoredPatchDefinitions.load_definitions():
				if definition.id in ["relay_bobbin", "hearth_lining"]:
					continue # P8 rare patches use a separate stock mechanism (deferred)
				_check(ids.count(definition.id) == 1, "real Elite pool retains candidate once: " + definition.id)
			_check(app.run_rng.state == rng, "reading shared Elite catalog consumes no RNG")
			for enemy in app.enemies.get_enemies():
				_check(app.enemies.apply_damage(enemy.position, 9999), "win actual Elite")
			var oracle := _reward_oracle()
			app._observe_battle_result()
			await _frames()
			_check(app.fight_reward_trinket == oracle.drop and app.run_rng.state == oracle.rng,
				"real Elite drop and RNG match independent shared-pool oracle")
			drop_seeds[app.fight_reward_trinket] = fixture.seed
			var dropped: String = app.fight_reward_trinket
			if dropped not in ["stitched_badge", "spare_spool", "quilted_coat", "button_eye", "pincushion_arm"]:
				for definition in RunAuthoredPatchDefinitions.load_definitions():
					if definition.id == dropped:
						drop_seeds[definition.slot] = fixture.seed
			if patch_id in RunPatchWardrobe.SLOTS and dropped not in [
				"stitched_badge", "spare_spool", "quilted_coat", "button_eye", "pincushion_arm"]:
				for definition in RunAuthoredPatchDefinitions.load_definitions():
					if definition.id == dropped and definition.slot == patch_id:
						patch_id = dropped
						break
			if dropped != patch_id:
				await _click(app.return_button)
				next_seed = fixture.seed + 1
				continue
			var service: RunMultiFightRewards = app.multi_fight_rewards
			var claim: Callable = app.reward_buttons[3].pressed.get_connections()[0].callable
			await _click(app.reward_buttons[3])
			_check(app.fight_reward_claimed and service._pending == null
				and app.run_trinkets.has(patch_id) and sewing.hero_buttons.size() == 3,
				"real Elite claim owns attack patch before sewing")
			_reject_patch(claim, "new patch reward replay")
			if sewing.hero_buttons.size() != 3:
				return
			var state: Dictionary = sewing.wardrobe.get_snapshot()
			var target: Button = sewing.hero_buttons[0]
			var callback: Callable = target.pressed.get_connections()[0].callable
			_reject_patch(sewing._sew.bind("foreign", target, sewing._token, state), "new patch invalid wearer")
			var stale := state.duplicate(true)
			stale.gold += 1
			_reject_patch(sewing._sew.bind("warden", target, sewing._token, stale), "new patch stale sew")
			_check(not sewing._prompt.text.begins_with("Sewn "), "no success confirmation before commit")
			await _click(target)
			var after: Dictionary = sewing.wardrobe.get_snapshot()
			var slot: String = state.definitions[patch_id]
			_check(after.worn.warden[slot] == patch_id and after.gold == state.gold
				and after.scraps == state.scraps and after.operation_ids.size() == state.operation_ids.size() + 1
				and app.party_carryover._wardrobe == sewing.wardrobe,
				"new Elite patch sews exact slot free and once")
			var expected_confirmation := "Sewn %s to Warden (%s); +0 scraps (empty slot)." % [
				_expected_name(patch_id), slot]
			_check(is_instance_valid(sewing._prompt) and sewing._prompt.text == expected_confirmation,
				"committed empty slot sew updates prompt to explicit success receipt: " + expected_confirmation)
			_check(sewing._prompt.text.contains(_expected_name(patch_id))
				and sewing._prompt.text.contains("Warden")
				and sewing._prompt.text.contains(slot)
				and sewing._prompt.text.contains("+0"),
				"empty slot receipt names patch, wearer, slot and +0")
			_reject_patch(callback, "new patch sew replay")
			await _click(app.continue_button)
			_reject_patch(callback, "new patch retired sew")
			var fight_path := _path_to(app.run_map, app.run_map.get_current_node_id(), "Fight")
			_check(not fight_path.is_empty(), "claimed attack patch has a later connected Fight")
			if not fight_path.is_empty():
				var fight: String = fight_path.pop_back()
				await _visit_path(fight_path, false)
				await _click(_route_action(fight))
				_check(app.party != null and app.enemies != null and not app._battle_closed
					and app.run_map.get_current_node_id() == fight
					and app.party_carryover._wardrobe == sewing.wardrobe
					and sewing.wardrobe.get_snapshot().worn == after.worn,
					"new Elite assignment persists into actual next Fight")
				if patch_id in ["button_eye", "pincushion_arm"]:
					await _acquired_attack_check(patch_id)
				await _click(app.return_button)
			else:
				await _click(app.route_back_button)
			obtained = true
			break
		_check(obtained, "production Elite pool claimed, sewed and activated " + patch_id)


## Literal, independent ID -> readable name oracle, written by hand from the
## shipped catalogs and the owner's naming. It is never computed from the
## presenter's own table, so a wrong, missing or invented name fails here.
const EXPECTED_NAMES := {
	"button_eye": "Button Eye",
	"pincushion_arm": "Pincushion Arm",
	"switchback_button": "Switchback Button",
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
	"threadguard_wrap": "Threadguard Wrap",
}
const SLOT_NAMES := {"HEAD": "HEAD", "ARM": "ARM", "COAT": "COAT"}
const HEADING_FONT_PATH := "res://assets/fonts/LondrinaSolid-Regular.ttf"
const BODY_FONT_PATH := "res://assets/fonts/PatrickHand-Regular.ttf"
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
	var prompt_before: String = sewing._prompt.text if is_instance_valid(sewing._prompt) else ""
	callback.call()
	_check(_complete_state() == before, message + ": complete run/wardrobe unchanged")
	var prompt_after: String = sewing._prompt.text if is_instance_valid(sewing._prompt) else ""
	_check(prompt_after == prompt_before, message + ": prompt unchanged on rejection")
	if not prompt_before.begins_with("Sewn "):
		_check(not prompt_after.begins_with("Sewn "),
			message + ": rejected sew never prints success receipt")


## AC1: after a genuine claim, the mounted offer takes the already-shipped sewn display
## face for its compact title, short chooser caption and three wearer actions, while the
## full authored rules stay 18 px Patrick Hand body text. Every literal body string is
## checked independently in _verify_preview_choice below.
func _verify_sewing_heading(drop: String) -> void:
	await _frames()
	var expected_title := "Sew " + _expected_name(drop)
	var mounted: Theme = sewing.inherited_theme()
	var heading: Font = sewing.heading_font()
	_check(mounted != null and heading != null
		and heading.resource_path == HEADING_FONT_PATH
		and (mounted.get_font("font", "PatchHeading") as Font).resource_path == HEADING_FONT_PATH,
		"the mounted sewing choice resolves PatchHeading from the shared Theme")
	var title: Label = sewing.title_label
	_check(is_instance_valid(title) and title.is_visible_in_tree()
		and title.text == expected_title and not title.text.contains(drop),
		"mounted offer title literally reads the authored friendly name: " + expected_title)
	if not is_instance_valid(title) or not is_instance_valid(sewing._prompt):
		return
	var title_font: Font = title.get_theme_font("font")
	_check(title.theme_type_variation == &"PatchHeading" and title_font != null
		and title_font.resource_path == HEADING_FONT_PATH
		and title.get_theme_font_size("font_size") >= 20
		and title.get_theme_font_size("font_size") <= 28
		and title.autowrap_mode != TextServer.AUTOWRAP_OFF
		and Rect2(0, 0, 1280, 720).encloses(title.get_global_rect()),
		"offer title is compact Londrina PatchHeading inside the 1280x720 viewport")
	var chooser: Label = sewing.chooser_label
	_check(is_instance_valid(chooser) and chooser.is_visible_in_tree()
		and chooser.text == "Sew to (free):"
		and chooser.theme_type_variation == &"PatchHeading"
		and (chooser.get_theme_font("font") as Font).resource_path == HEADING_FONT_PATH
		and sewing._choices.is_ancestor_of(chooser),
		"short free-sew chooser label keeps its wording in the PatchHeading face")
	var body_font: Font = sewing._prompt.get_theme_font("font")
	_check(sewing._prompt.get_theme_font_size("font_size") == 18
		and body_font != null and body_font.resource_path == BODY_FONT_PATH
		and body_font != title_font
		and sewing._prompt.autowrap_mode != TextServer.AUTOWRAP_OFF,
		"full authored patch description stays 18 px Patrick Hand body text")
	_check(not title.get_global_rect().intersects(sewing._prompt.get_global_rect())
		and not sewing._prompt.get_global_rect().intersects(sewing._choices.get_global_rect())
		and title.get_global_rect().end.y <= sewing._choices.get_global_rect().position.y,
		"sewn offer title, body rules and wearer row stack without overlap")
	for button in sewing.hero_buttons:
		var hero_id: String = button.get_meta("hero_id")
		var face: Font = button.get_theme_font("font")
		_check(button.theme_type_variation == &"PatchHeadingButton" and face != null
			and face.resource_path == HEADING_FONT_PATH
			and button.get_theme_font_size("font_size") >= 18,
			"%s wearer action wears the shipped PatchHeadingButton face" % hero_id)
		_check(button.get_theme_color("font_color") == Color("302b29")
			and button.get_theme_color("font_hover_color") == Color("302b29")
			and button.get_theme_color("font_pressed_color") == Color("302b29")
			and button.get_theme_color("font_focus_color") == Color("302b29")
			and button.get_theme_color("font_hover_pressed_color") == Color("302b29"),
			"%s display lettering keeps dark ink on every cream paper state" % hero_id)


## AC1 fallback: a mounted Theme that authors no PatchHeading, and an unavailable display
## file, resolve no display face at all; the lettering then keeps the readable body face
## instead of ever assigning a null font.
func _verify_heading_fallback() -> void:
	var body: Font = load(BODY_FONT_PATH)
	var bare := Theme.new()
	bare.default_font = body
	_check(sewing.heading_face(bare) == null and sewing.heading_face(null) == null
		and sewing.load_heading_font("res://assets/fonts/absent.ttf") == null
		and sewing.load_heading_font("") == null,
		"a fallback Theme and an unavailable display file resolve no display face")
	var probe := Label.new()
	probe.text = "Sew Button Eye"
	probe.theme = bare
	root.add_child(probe)
	var probe_button := Button.new()
	probe_button.text = "Warden"
	probe_button.theme = bare
	root.add_child(probe_button)
	await _frames()
	sewing.apply_heading(probe, sewing.heading_face(bare))
	sewing.apply_heading_button(probe_button,
		sewing.load_heading_font("res://assets/fonts/absent.ttf"))
	await _frames()
	for control in [probe, probe_button]:
		var font: Font = control.get_theme_font("font")
		_check(font != null and font.resource_path == BODY_FONT_PATH,
			"%s keeps the readable body face instead of a null font" % control.text)
	_check(probe.theme_type_variation == &"PatchHeading"
		and probe_button.theme_type_variation == &"PatchHeadingButton",
		"fallback lettering still selects the sewn PatchHeading variations")
	probe.free()
	probe_button.free()


## Inspect the actual mounted reward choice before any activation. Real pointer
## and keyboard focus must both reveal THIS hero's oracle consequence.
func _verify_preview_choice(drop: String, state: Dictionary) -> Dictionary:
	var before := _complete_state()
	var run_rng: int = app.run_rng.state
	var torn_state: Dictionary = app.party_carryover.torn.read_state()
	await _verify_sewing_heading(drop)
	await _verify_heading_fallback()
	var entries: Dictionary = {}
	var lines: Dictionary = {}
	var tooltips: Dictionary = {}
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
		var old_name := "empty"
		var old_fate := ""
		if preview.displaced_id != "":
			old_name = _expected_name(preview.displaced_id)
			old_fate = " (old patch destroyed)"
		var power_expected: String = preview.rules_text
		if power_expected.is_empty():
			power_expected = "power not documented"
		lines[hero_id] = "%s · %s · %s\nPower: %s\nSew: %s → %s%s • +%d scrap" % [
			hero_id.capitalize(), preview.slot, expected_name, power_expected,
			old_name, expected_name, old_fate, preview.scrap_delta]
		tooltips[hero_id] = lines[hero_id]
		if preview.displaced_id != "" and not preview.displaced_rules_text.is_empty():
			tooltips[hero_id] += "\nOld power (%s): %s" % [
				_expected_name(preview.displaced_id), preview.displaced_rules_text]
	# The prompt starts as the mount sentence and, once a hero tag is reached,
	# keeps that hero's exact line. Both are literal; the raw ID is never shown.
	var mount_power: String = entries.values()[0].rules_text if not entries.is_empty() else ""
	if mount_power.is_empty():
		mount_power = "power not documented"
	var prompt_allowed: Array[String] = [
		"%s · %s\nPower: %s\nFree sew • Focus a living wearer for +0/+1 scrap." % [
			expected_name, expected_slot, mount_power]]
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
		_check(explanation == tooltips[hero_id] and not explanation.contains(drop),
			"mounted %s tooltip literally names the drop, power and own +0/+1 scrap displacement" % hero_id)
		await _hover(button)
		_check(sewing._prompt.text == lines[hero_id],
			"real mouse hover exposes %s concise consequence visibly" % hero_id)
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
		_check(button.has_focus() and sewing._prompt.text == lines[hero_id],
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


func _coat_multi_fixture(reward_index: int = 0, prior_coat: bool = false) -> Dictionary:
	var first_seed := 5052 if prior_coat else 1
	for attempt in range(maxi(40, RunAuthoredPatchDefinitions.load_definitions().size() * 8)):
		var fixture := _multi_fixture(first_seed, maxi(30000, first_seed + 20000))
		if fixture.is_empty() or not await _routed_win(fixture, false):
			return {}
		await _click(app.reward_buttons[reward_index])
		await _click(app.continue_button)
		if prior_coat:
			app.run_trinkets.append("reinforced_patchcoat")
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
		var fixture := _multi_fixture(next_seed, maxi(3000, next_seed + 12000))
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
		# AC1: the disabled torn action wears the same sewn action face, so the offer
		# reads as one display hierarchy even when a wearer is unavailable.
		_check(buttons[0].theme_type_variation == &"PatchHeadingButton"
			and (buttons[0].get_theme_font("font") as Font).resource_path == HEADING_FONT_PATH
			and buttons[0].get_theme_font_size("font_size") >= 18
			and buttons[0].get_theme_color("font_disabled_color") != Color("302b29"),
			"disabled torn Warden action keeps the PatchHeadingButton face and its own grey ink")
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
				and button.tooltip_text == sewing._preview_tooltip(preview)
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
				and sewing._prompt.text == sewing._preview_line(
					previews[buttons[index].get_meta("hero_id")]),
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
		_check(not sewing._prompt.text.begins_with("Sewn "),
			"torn-party prompt has no confirmation before committed sew")
		_reject_patch(sewing._sew.bind("warden", buttons[0], sewing._token, state),
			"torn Warden direct sew rejected without confirmation")
		var callback: Callable = chosen.pressed.get_connections()[0].callable
		var settlement: Array = _settlement_state()
		await _key(KEY_ENTER if chosen_index == 1 else KEY_SPACE)
		var after: Dictionary = sewing.wardrobe.get_snapshot()
		_check(after.worn[hero][expected.slot] == drop and after.owned.has(drop)
			and after.scraps == state.scraps + expected.scrap_delta
			and after.operation_ids.size() == 1 and app.run_scraps == after.scraps
			and app.party_carryover._wardrobe == sewing.wardrobe,
			"Enter/Space sews each eligible torn-party recipient once with matching receipt/scrap")
		var torn_expected_confirmation := "Sewn %s to %s (%s); +0 scraps (empty slot)." % [
			_expected_name(drop), hero.capitalize(), expected.slot]
		_check(is_instance_valid(sewing._prompt) and sewing._prompt.text == torn_expected_confirmation,
			"torn-party committed sew updates prompt to receipt: " + torn_expected_confirmation)
		_check(sewing._prompt.text.contains(_expected_name(drop))
			and sewing._prompt.text.contains(hero.capitalize())
			and sewing._prompt.text.contains(expected.slot)
			and sewing._prompt.text.contains("+0"),
			"torn-party receipt names patch, living wearer, slot and +0")
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
	await _attack_patch_claims()
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
			_check(not sewing._prompt.text.begins_with("Sewn "), "prompt has no confirmation before committed sew")
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
			var session_expected_prompt: String
			if chosen_preview.displaced_id != "":
				session_expected_prompt = "Sewn %s to %s (%s); +1 scrap from replacing %s." % [
					_expected_name(drop), hero.capitalize(), slot, _expected_name(chosen_preview.displaced_id)]
			else:
				session_expected_prompt = "Sewn %s to %s (%s); +0 scraps (empty slot)." % [
					_expected_name(drop), hero.capitalize(), slot]
			_check(is_instance_valid(sewing._prompt) and sewing._prompt.text == session_expected_prompt,
				"physical confirmation updates prompt to receipt")
			if chosen_preview.displaced_id != "":
				_check(sewing._prompt.text.contains(_expected_name(drop))
					and sewing._prompt.text.contains(hero.capitalize())
					and sewing._prompt.text.contains(slot)
					and sewing._prompt.text.contains(_expected_name(chosen_preview.displaced_id))
					and sewing._prompt.text.contains("+1"),
					"session sew receipt names patch, wearer, slot, old patch and +1 scrap")
			else:
				_check(sewing._prompt.text.contains(_expected_name(drop))
					and sewing._prompt.text.contains(hero.capitalize())
					and sewing._prompt.text.contains(slot)
					and sewing._prompt.text.contains("+0"),
					"session sew receipt names patch, wearer, slot and +0 scraps")
			_check(chosen_preview.get("ok") == true
				and slot == chosen_preview.get("slot")
				and after.scraps == scraps + chosen_preview.get("scrap_delta", -100)
				and (chosen_preview.get("displaced_id", "") == ""
					or not after.owned.has(chosen_preview.displaced_id))
				and after.owned.has(drop),
				"actual free sew has exact previewed scrap delta, ownership and displaced ID")
			_verify_worn_readout()
			var expected_settlement: Array = unchanged.duplicate(true)
			if chosen_preview.displaced_id != "":
				expected_settlement[2].trinkets.erase(chosen_preview.displaced_id)
				expected_settlement[8].erase(chosen_preview.displaced_id)
			_check(_settlement_state() == expected_settlement and app.run_scraps == scraps + chosen_preview.get("scrap_delta", -100)
				and after.scraps == app.run_scraps,
				"sewing changes no unrelated run, reward, deck, route, gold or RNG state")
			_check(after.operation_ids.size() == index + 1, "one successful sew receipt per earned drop")
			if index == 0:
				first_worn = after.worn.duplicate(true)
			else:
				var expected_worn: Dictionary = first_worn.duplicate(true)
				expected_worn[hero][slot] = drop
				_check(after.worn == expected_worn, "second legitimate drop changes only chosen wearer slot")
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
		_check(sewing.wardrobe == null and sewing.hero_buttons.is_empty() and sewing.summary.text.is_empty()
			and sewing.title_label == null and sewing.chooser_label == null,
			"title resets companion completely")
		for callback in retained:
			callback.call()
		_check(sewing.wardrobe == null and app.run_trinkets.is_empty() and app.run_scraps == 0
			and app.run_map == null and app.title_view.visible, "old callbacks cannot restore a title-state assignment")
		_check(randi() == global_next, "claim, sewing, negatives and reset preserve global RNG")
	var torn_fixture := _torn_focus_fixture()
	_check(not torn_fixture.is_empty(), "seeded torn-Warden predecessor connects to Elite without recovery Rest")
	if not torn_fixture.is_empty():
		await _test_torn_warden_focus(torn_fixture)
	var displaced_fixture := await _coat_multi_fixture(3, true)
	_check(not displaced_fixture.is_empty(), "Skip reward seed naturally drops coat for displacement")
	if not displaced_fixture.is_empty():
		await _test_displaced_name(displaced_fixture)
	await _test_authored_live_claims(fixture)
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
	var definitions: Array = RunAuthoredPatchDefinitions.load_definitions()
	_check(not definitions.is_empty(), "prior-bound wardrobe uses complete authored projection")
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
	_check(sewing._prompt.text == "Quilted Coat · COAT\nPower: +6 maximum HP\nFree sew • Focus a living wearer for +0/+1 scrap.",
		"mounted prompt literally names Quilted Coat and its COAT slot power")
	var target: Button = sewing.hero_buttons.filter(
		func(button): return button.get_meta("hero_id") == wearer)[0]
	var visible := "Warden · COAT · Quilted Coat\nPower: +6 maximum HP\nSew: Reinforced Patchcoat → Quilted Coat (old patch destroyed) • +1 scrap"
	var full := visible + "\nOld power (Reinforced Patchcoat): +9 maximum HP"
	_check(target.tooltip_text == full,
		"mounted tooltip literally names the displaced Reinforced Patchcoat and +1 scrap")
	_check(not target.tooltip_text.contains("reinforced_patchcoat")
		and not target.tooltip_text.contains(drop),
		"tooltip shows sewn names, never raw patch IDs")
	await _hover(target)
	_check(sewing._prompt.text == visible,
		"real pointer hover visibly shows the displaced name and +1 scrap")
	target.grab_focus()
	await _frames()
	_check(target.has_focus() and sewing._prompt.text == visible,
		"physical keyboard focus shows the displaced name and +1 scrap")
	for other in sewing.hero_buttons:
		if other.get_meta("hero_id") != wearer:
			_check(other.tooltip_text.contains("Sew: empty → Quilted Coat • +0 scrap"),
				"each other living wearer keeps the exact +0 scrap empty-slot consequence")
	var entries: Dictionary = await _verify_preview_choice(drop, state)
	_check(entries.size() == 3, "all three real displaced-preview choices stay readable and read-only")
	var callback: Callable = target.pressed.get_connections()[0].callable
	_check(not sewing._prompt.text.begins_with("Sewn "), "displaced prompt has no confirmation before committed sew")
	await _click(target)
	var after: Dictionary = prior.get_snapshot()
	_check(after.worn[wearer].COAT == drop and not after.owned.has("reinforced_patchcoat")
		and after.owned.has(drop) and after.scraps == state.scraps + 1
		and after.operation_ids.size() == state.operation_ids.size() + 1,
		"genuine displaced sew owns the new coat and grants exactly +1 scrap")
	var displaced_expected_receipt := "Sewn Quilted Coat to Warden (COAT); +1 scrap from replacing Reinforced Patchcoat."
	_check(is_instance_valid(sewing._prompt) and sewing._prompt.text == displaced_expected_receipt,
		"displaced sew updates prompt to explicit receipt: " + displaced_expected_receipt)
	_check(sewing._prompt.text.contains("Quilted Coat")
		and sewing._prompt.text.contains("Warden")
		and sewing._prompt.text.contains("COAT")
		and sewing._prompt.text.contains("Reinforced Patchcoat")
		and sewing._prompt.text.contains("+1 scrap"),
		"displaced receipt explicitly names new patch, wearer, slot, old patch, and +1 scrap")
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


## Install a fresh, real RunMultiFightRewards using one authored test candidate.
## The production Shop drop pool is intentionally unchanged; all later actions
## still pass through the mounted reward panel, app claim, signed service receipt,
## carryover settlement, Elite chooser and physical hero button.
func _authored_reward_fixture(drop: String) -> RunMultiFightRewards:
	_check(not app.fight_reward_claimed and app.multi_fight_rewards != null
		and app.reward_buttons.size() == 4 and not app.run_trinkets.has(drop),
		"unclaimed actual Elite battle is ready for an authored fixture pool")
	var owners: Array[String] = []
	for hero in app.party.get_heroes():
		owners.append(hero.id)
	var records: Array = app._reward_candidate_records(owners)
	var service := RunMultiFightRewards.new(app.run_map, app.run_rng, app.party_carryover,
		app.run_deck, app.session_gold, app.run_trinkets, records, [drop],
		app.run_stitch_descriptors, app.run_next_stitch_id)
	var prepared: Dictionary = service.prepare(app._carryover_node, app.battle_result, app.party)
	_check(prepared.get("ok") == true and prepared.get("trinket_drop_id") == drop
		and service._pending != null and service._paid_battles.is_empty(),
		"real coordinator prepares one seeded authored drop: " + drop)
	if prepared.get("ok") != true:
		return null
	app._clear_reward_choice()
	app.multi_fight_rewards = service
	app.fight_reward_offers = prepared.offers
	app.fight_reward_gold = prepared.gold_award
	app.fight_reward_trinket = prepared.trinket_drop_id
	app._mount_reward_choice(prepared)
	await _frames()
	_check(app.reward_buttons.size() == 4
		and app.reward_choice_panel.is_visible_in_tree() and not app.fight_reward_claimed,
		"real reward controls bind the new, still-unclaimed service")
	return service


## Genuine committed M05 HEAD/ARM/COAT receipts and a formerly-bound
## incompatible wardrobe. ARM/COAT replace an actual previously worn patch;
## HEAD uses a vacant slot. No forged result is passed to observe_claim.
func _test_authored_live_claims(fixture: Dictionary) -> void:
	for case in [
		{"drop": "bloodstitch_bonnet", "slot": "HEAD", "prior": ""},
		{"drop": "hemguard_cuff", "slot": "ARM", "prior": "spare_spool"},
		{"drop": "borrowed_button", "slot": "COAT", "prior": "reinforced_patchcoat"},
		{"drop": "bloodstitch_bonnet", "slot": "HEAD", "prior": "spare_spool",
			"incompatible": true},
	]:
		var drop: String = case.drop
		var expected_slot: String = case.slot
		seed(307307)
		var global_next := randi()
		seed(307307)
		if not await _routed_win(fixture, false):
			return
		await _click(app.reward_buttons[3])
		await _click(app.continue_button)
		var prior: RunPatchWardrobe = null
		var prior_id: String = case.prior
		if prior_id != "":
			app.run_trinkets.append(prior_id)
			var definitions: Array = (JSON.parse_string(FileAccess.get_file_as_string(
				"res://data/patches/initial_patch_slots.json"))
				if case.get("incompatible", false)
				else RunAuthoredPatchDefinitions.load_definitions())
			prior = RunPatchWardrobe.new(app.run_heroes, app.run_trinkets, definitions,
				app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
			_check(prior.is_valid(), "fixture creates a valid bound earlier wardrobe")
			if not prior.is_valid():
				return
			var old_slot: String = prior.get_snapshot().definitions[prior_id]
			var old_sew := prior.sew(prior_id, "warden", old_slot,
				"fixture:prior:" + prior_id, prior.get_snapshot())
			_check(old_sew.ok and old_sew.receipt.scrap_delta == 0
				and app.party_carryover.bind_wardrobe(prior, app.party_carryover.torn,
					prior.get_snapshot()), "prior wear and carryover binding are canonical")
		var path: Array = fixture.paths[0].duplicate()
		var elite: String = path.pop_back()
		await _visit_path(path, false)
		await _click(_route_action(elite))
		_check(app.run_map.get_current_node_id() == elite and not app._battle_closed,
			"real Elite was entered through the connected route")
		for enemy in app.enemies.get_enemies():
			_check(app.enemies.apply_damage(enemy.position, 9999),
				"actual Elite opponent defeated for " + drop)
		app._observe_battle_result()
		await _frames()
		var service: RunMultiFightRewards = await _authored_reward_fixture(drop)
		if service == null or app.reward_buttons.size() != 4:
			return
		var pre_claim := _complete_state()
		_check(not app.run_trinkets.has(drop), "authored power not owned before actual claim")
		await _click(app.reward_buttons[3])
		_check(app.fight_reward_claimed and service._paid_battles.has(app.battle_result)
			and service._pending == null and app.run_trinkets.has(drop),
			"mounted Skip commits canonical Elite receipt and adds owned " + drop)
		_check(_complete_state() != pre_claim,
			"actual reward changes run state before any sewing is possible")
		if case.get("incompatible", false):
			_check(sewing.wardrobe == prior and app.party_carryover._wardrobe == prior
				and not prior.get_snapshot().definitions.has(drop)
				and prior.get_snapshot().owned.has(drop)
				and sewing.hero_buttons.is_empty(),
				"incompatible previously bound Shop-style wardrobe is kept and denies missing ID")
			var denied_state := _complete_state()
			var signed_receipt := {"ok": true, "receipt": {"node_id": elite,
				"node_kind": "Elite", "trinket_drop_id": drop}}
			sewing.observe_claim(service, signed_receipt)
			_check(_complete_state() == denied_state,
				"re-observation cannot replace or expand a bound incompatible wardrobe")
			await _click(app.continue_button)
			_check(app.route_view.is_visible_in_tree() and app.party_carryover._wardrobe == prior,
				"rejected sewing still permits normal continuation with same authoritative ledger")
			await _click(app.route_back_button)
			_check(randi() == global_next, "incompatible receipt preserves global RNG")
			continue
		_check(sewing.wardrobe != null and sewing.hero_buttons.size() == 3
			and sewing._eligible(), "complete live wardrobe offers 3 recipients for " + drop)
		if sewing.wardrobe == null or sewing.hero_buttons.size() != 3:
			return
		var state: Dictionary = sewing.wardrobe.get_snapshot()
		_check(state.definitions.get(drop) == expected_slot and state.owned.has(drop)
			and state.heroes == app.run_heroes and app.party_carryover.torn.read_state().heroes == state.heroes,
			"committed authored patch has correct slot, ownership and torn-roster preconditions")
		var previews: Dictionary = await _verify_preview_choice(drop, state)
		var target: Button = sewing.hero_buttons[0]
		var result_preview: Dictionary = previews.get("warden", {})
		var replaced: String = prior_id
		_check(result_preview.get("ok") == true
			and result_preview.get("slot") == expected_slot
			and result_preview.get("displaced_id") == replaced
			and result_preview.get("scrap_delta") == (1 if replaced != "" else 0),
			"mounted authentic preview distinguishes empty-slot free sew from replacement")
		var callback: Callable = target.pressed.get_connections()[0].callable
		_reject_patch(sewing._sew.bind("foreign", target, sewing._token, state),
			"authored signed receipt rejects foreign wearer")
		var forged := state.duplicate(true)
		forged.gold += 1
		_reject_patch(sewing._sew.bind("warden", target, sewing._token, forged),
			"authored signed receipt rejects stale wardrobe")
		var torn_before: Dictionary = app.party_carryover.torn.read_state()
		var unaffected := [app.session_gold, app.run_deck.duplicate(true), app.run_rng.state,
			app.run_seed, app.fight_reward_claimed, app.fight_reward_offers.duplicate(true),
			service.read_state().deck, service.read_state().gold,
			service.read_state().party, service._paid_battles.duplicate(),
			service._pending, app.run_map.get_route(), app.run_map.get_floors()]
		var worn_expected: Dictionary = state.worn.duplicate(true)
		worn_expected["warden"][expected_slot] = drop
		_check(not sewing._prompt.text.begins_with("Sewn "), "authored claim prompt has no confirmation before commit")
		await _click(target)
		var after: Dictionary = sewing.wardrobe.get_snapshot()
		_check(after.worn == worn_expected and after.owned.has(drop)
			and (replaced == "" or not after.owned.has(replaced))
			and after.scraps == state.scraps + (1 if replaced != "" else 0)
			and after.operation_ids.size() == state.operation_ids.size() + 1,
			"real hero button sews exact authored slot and destroys only displaced patch")
		if is_instance_valid(sewing._prompt):
			var expected_receipt: String
			if replaced != "":
				expected_receipt = "Sewn %s to Warden (%s); +1 scrap from replacing %s." % [
					_expected_name(drop), expected_slot, _expected_name(replaced)]
			else:
				expected_receipt = "Sewn %s to Warden (%s); +0 scraps (empty slot)." % [
					_expected_name(drop), expected_slot]
			_check(sewing._prompt.text == expected_receipt,
				"committed authored sew updates prompt with receipt for %s (%s, replaced: %s)" % [
					drop, expected_slot, replaced])
			if replaced != "":
				_check(sewing._prompt.text.contains(_expected_name(drop))
					and sewing._prompt.text.contains(_expected_name(replaced))
					and sewing._prompt.text.contains("Warden")
					and sewing._prompt.text.contains(expected_slot)
					and sewing._prompt.text.contains("+1"),
					"authored displaced receipt names old/new patches, wearer, slot, and +1 scrap")
			else:
				_check(sewing._prompt.text.contains(_expected_name(drop))
					and sewing._prompt.text.contains("Warden")
					and sewing._prompt.text.contains(expected_slot)
					and sewing._prompt.text.contains("+0"),
					"authored empty-slot receipt names patch, wearer, slot, and +0 scraps")
		_check(app.run_trinkets == after.owned and app.run_scraps == after.scraps
			and service.read_state().trinkets == after.owned
			and app.party_carryover._wardrobe == sewing.wardrobe
			and app.party_carryover.torn.read_state() == torn_before,
			"run wallet, owned list, bound carryover and torn ledger match exact sewing result")
		_check(unaffected == [app.session_gold, app.run_deck.duplicate(true), app.run_rng.state,
			app.run_seed, app.fight_reward_claimed, app.fight_reward_offers.duplicate(true),
			service.read_state().deck, service.read_state().gold,
			service.read_state().party, service._paid_battles.duplicate(),
			service._pending, app.run_map.get_route(), app.run_map.get_floors()],
			"sew preserves gold, deck, reward, RNG, seed and route")
		_verify_worn_readout()
		_reject_patch(callback, "authored duplicate hero click")
		await _click(app.continue_button)
		_check(app.route_view.is_visible_in_tree()
			and sewing.summary.text.contains(_expected_name(drop)),
			"authored power and wearer survive normal Continue")
		_reject_patch(callback, "authored stale callback after Continue")
		await _click(app.route_back_button)
		_check(sewing.wardrobe == null and app.title_view.visible,
			"authored power run resets all sewing selections")
		_check(randi() == global_next, "authored claimed, replaced and reset global RNG untouched")


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
