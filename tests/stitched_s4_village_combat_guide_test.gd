extends SceneTree
## Real mounted S4 Quilt Village combat-guide contract: focus, modal guards,
## seeded RNG and host state stay untouched by a read-only browse.
const SCENE := preload("res://scenes/base_screen.tscn")
var failures: Array[String] = []
var checks := 0
var view: BaseScreen
var back_calls := 0
var set_out_calls := 0
var path_calls := 0
var tinker_calls := 0
var warden_calls := 0
var difficulty_calls := 0


func _initialize() -> void:
	StitchedBedroom.enabled = false
	_run.call_deferred()


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)


func _frames() -> void:
	for _i in range(3):
		await process_frame


func _key(key: Key, shifted: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.shift_pressed = shifted
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	_check(root.get_visible_rect().has_point(point), "visible pointer target " + button.name)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _paths(path: String) -> Array:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var rows: Variant = raw.get("paths", []) if raw is Dictionary else raw
	var result: Array = []
	if rows is Array:
		for record in rows:
			if record is Dictionary:
				var card: Dictionary = record.get("card", {})
				result.append({"id": String(record.get("id", "")),
					"display_name": String(record.get("display_name", "")),
					"card_name": String(card.get("display_name", ""))})
	return result


func _all_present(haystack: String, needles: Array) -> bool:
	for needle in needles:
		if not haystack.contains(needle):
			return false
	return true


func _state() -> Array:
	return [view.wallet_label.text, view.selected_path_id(),
		view.selected_tinker_path_id(), view.selected_warden_path_id(),
		view._set_out_pending, view._back_pending, view._path_pending,
		view._tinker_pending, view._warden_pending, view._difficulty_request,
		view.field_guide._atlas_is_open(), back_calls, set_out_calls, path_calls,
		tinker_calls, warden_calls, difficulty_calls]


func _run() -> void:
	root.size = Vector2i(1280, 720)
	view = SCENE.instantiate() as BaseScreen
	root.add_child(view)
	await _frames()
	var guide := view.field_guide
	var entry := view.guide_button
	_check(view.scene_file_path == "res://scenes/base_screen.tscn" and guide != null
		and entry != null and not view.has_open_village() and entry.disabled
		and not guide.is_open(), "live scene mounts one closed/disabled village guide")
	if guide == null or entry == null:
		_finish()
		return
	view._on_guide_pressed()
	_check(not guide.is_open(), "closed village refuses stale guide invocation")
	var seam := _paths("res://data/heroes/seamstress_paths.json")
	var tinker := _paths("res://data/heroes/tinker_paths.json")
	var warden := _paths("res://data/heroes/warden_paths.json")
	_check(seam.size() >= 2 and tinker.size() >= 2 and warden.size() >= 2,
		"real authored hero Path fixtures are nonempty")
	if seam.is_empty() or tinker.is_empty() or warden.is_empty():
		_finish()
		return
	_check(view.present_path_options(seam)
		and view.present_tinker_path_options(tinker)
		and view.present_warden_path_options(warden), "live village Path boards mount")
	view.present_difficulty([0, 1], 0)
	view.back_requested.connect(func() -> void: back_calls += 1)
	view.set_out_requested.connect(func() -> void: set_out_calls += 1)
	view.path_choice_requested.connect(func(_id: String) -> void: path_calls += 1)
	view.tinker_path_choice_requested.connect(func(_id: String) -> void: tinker_calls += 1)
	view.warden_path_choice_requested.connect(func(_id: String) -> void: warden_calls += 1)
	view.difficulty_choice_requested.connect(func(_tier: int) -> void: difficulty_calls += 1)
	_check(view.open_village(27, 6), "valid host opens actual Quilt Village")
	await _frames()
	var strip := view.get_node("TopStrip/StripRow")
	_check(entry.get_parent() == strip and entry.text == "Battle guide"
		and entry.focus_mode == Control.FOCUS_ALL and not entry.disabled
		and entry.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND
		and root.get_visible_rect().encloses(entry.get_global_rect())
		and not entry.get_global_rect().intersects(view.wallet_label.get_global_rect())
		and not entry.get_global_rect().intersects(view.back_button.get_global_rect()),
		"distinct focusable top-strip entry has space at 1280x720")
	_check(view.back_button.focus_next == view.back_button.get_path_to(view.heroes_house_button)
		and view.heroes_house_button.focus_next == view.heroes_house_button.get_path_to(view.camp_house_button),
		"Back -> Heroes -> Camp Tab order is preserved")
	entry.grab_focus()
	await _key(KEY_ENTER)
	_check(guide.is_open() and guide.is_visible_in_tree()
		and root.gui_get_focus_owner() == guide.tab_buttons[0] and entry.disabled,
		"Enter opens actual modal overlay and focuses first tab")
	_check(view.get_children().filter(func(node: Node) -> bool: return node is StitchedFieldGuide).size() == 1,
		"guide has exactly one mounted instance")
	_check(guide.theme == null and StitchedFieldGuide.GOTHIC == load("res://themes/gothic_theme.tres")
		and guide.get_node("FeltPanel") is NinePatchRect
		and (guide.get_node("FeltPanel") as NinePatchRect).texture != null,
		"inherited Gothic theme contract and supplied felt art mount")
	var expected_titles := ["Ranks & turns", "Seams & retreat", "Fray & resolve", "Candle & stops"]
	_check(guide.tab_buttons.size() == 4 and guide.page_labels.size() == 4
		and guide.page_scroll != null and guide.get_node("FeltPanel/GuideContent/GuideTabs").get_child_count() == 4,
		"real mounted 1280x720 guide provides four native tabs and scrollable pages")
	var tab_bounds := Rect2()
	for i in range(4):
		var tab := guide.tab_buttons[i]
		var bounds := tab.get_global_rect()
		_check(tab.text == expected_titles[i] and tab.focus_mode == Control.FOCUS_ALL
			and tab.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND
			and root.get_visible_rect().encloses(bounds)
			and (i == 0 or not bounds.intersects(tab_bounds)),
			"fourth compact button fits and every tab is focusable at 1280x720: %d" % i)
		tab_bounds = bounds
	var texts := [
		["Four allied ranks", "1 (front)", "4 (back)", "Foes", "2–3 foes",
			"fourth", "summon or split", "SPEED + 1d8", "seeded RNG",
			"Ties favour heroes", "lower ranks", "one turn", "two-turn bosses",
			"HEAD / ARMS / TORSO / LEGS", "one ability each", "launch ranks",
			"target ranks", "MOVE", "adjacent ally", "RE-TIE", "snipped", "PASS"],
		["non-boss", "75%", "consumes that hero's turn", "EACH hero +15 Fray",
			"forfeits all rewards", "SNIPPED THREAD", "healing or guard",
			"re-tied", "0 HP", "Hanging by a Thread", "still act",
			"random non-torso part", "67%", "33%"],
		["0–200", "Reaching 100", "25%", "STEADFAST", "45 Fray",
			"+10% damage", "every party member's Fray by 2", "floor ends",
			"75%", "Unravelled", "below 50", "200 Fray", "Comes Apart",
			"HP becomes 0", "Fray becomes 150", "already Hanging by a Thread",
			"LOST", "0 HP", "still act", "random non-torso part",
			"67%", "33%"],
		["Begins at 100", "each map node costs 8 Candle", "clamped at 0",
			"BRIGHT 76–100", "15% chance the party acts first", "no penalty",
			"DIM 51–75", "+10% Fray gain", "+25% loot",
			"GLOOM 26–50", "+20% Fray gain", "+5 ACC", "+10% damage", "+50% loot",
			"DARK 1–25", "+30% Fray gain", "+10 ACC", "+15% damage", "+75% loot",
			"SNUFFED 0", "+40% Fray gain", "+25% damage",
			"25% chance foes act first", "+100% loot", "do not guarantee a drop",
			"Choose ONE", "Mend heals 30% HP for each hero",
			"Tell Tales reduces each hero's Fray by 25",
			"Trim the Wick restores 50 Candle",
			"Peddler candle stub restores 25 Candle",
			"up to six spare parts", "Campfire or Sewing Circle", "never in a fight"]
	]
	for i in range(4):
		if i > 0:
			await _click(guide.tab_buttons[i])
		_check(guide.page_index == i and guide.page_labels[i].is_visible_in_tree()
			and guide.tab_buttons[i].button_pressed,
			"actual tab %d reveals one selected page" % i)
		var single := true
		for j in range(4):
			single = single and (guide.page_labels[j].visible == (i == j))
			single = single and (guide.tab_buttons[j].button_pressed == (i == j))
		_check(single and _all_present(guide.page_labels[i].text, texts[i])
			and guide.page_text(i) == guide.page_labels[i].text,
			"mounted page %d renders exact current rules with no extra active page" % i)
		var lower := guide.page_text(i).to_lower()
		_check(guide.page_labels[i].get_theme_font_size("font_size") >= 18
			and not lower.contains("energy cost") and not lower.contains("draw a card")
			and not lower.contains("deck") and not lower.contains("hand of cards")
			and not lower.contains("future s6") and not lower.contains("not active")
			and not lower.contains("s4 play"),
			"legible bone body and no retired/false future rules on page %d" % i)
	_check(guide.page_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
		and guide.page_scroll.get_v_scroll_bar().max_value > guide.page_scroll.size.y,
		"long Candle stop reference scrolls vertically at 1280x720 without shrinking text")
	# Check the full native Tab and Shift-Tab ring, including the new fourth tab.
	var focus_ring: Array[Button] = guide.tab_buttons.duplicate()
	focus_ring.append(guide.atlas_button)
	focus_ring.append(guide.close_button)
	for i in range(focus_ring.size()):
		var current := focus_ring[i]
		var next := focus_ring[(i + 1) % focus_ring.size()]
		var previous := focus_ring[(i - 1 + focus_ring.size()) % focus_ring.size()]
		_check(current.focus_next == current.get_path_to(next)
			and current.focus_previous == current.get_path_to(previous),
			"real six-control Tab/Shift-Tab ring links %s both ways" % current.name)
	guide.tab_buttons[0].grab_focus()
	for i in range(1, focus_ring.size() + 1):
		await _key(KEY_TAB)
		_check(root.gui_get_focus_owner() == focus_ring[i % focus_ring.size()],
			"Tab forward stays within guide, including atlas, Close and wrap %d" % i)
	for i in range(focus_ring.size() - 1, -1, -1):
		await _key(KEY_TAB, true)
		_check(root.gui_get_focus_owner() == focus_ring[i],
			"Shift-Tab reverse stays inside six-control ring %d" % i)
	# The same shipped atlas is reachable through the live BaseScreen guide, not a test-only scene.
	seed(820631)
	var atlas_next_rng := randi()
	seed(820631)
	var before_atlas := _state()
	await _click(guide.atlas_button)
	_check(guide._atlas_is_open() and guide.part_atlas != null
		and guide.part_atlas.is_visible_in_tree()
		and root.gui_get_focus_owner() == guide.part_atlas.get_node("CloseButton"),
		"Parts & spoils action opens shipped inspector and focuses its Close control")
	var inspector := guide.part_atlas
	if inspector != null and guide._atlas_is_open():
		_check(inspector.select_owner("warden") and inspector.select_part("warden_head_pot_helm_bonk"),
			"live BaseScreen route can select authored Warden head patch")
		await _frames()
		var patch := inspector.get_node("DetailsPanel/PatchPreview") as TextureRect
		var border := inspector.get_node("DetailsPanel/TierBorderPreview") as TextureRect
		var tier_two := inspector.get_node("DetailsPanel/TierII") as Button
		var part_path := "res://assets/paper/stitched/patches/warden_head_pot_helm_bonk.png"
		_check(patch != null and border != null, "shipped atlas includes both passive patch layers")
		if patch != null and border != null:
			var patch_rect := patch.get_global_rect()
			var no_overlap := root.get_visible_rect().encloses(patch_rect)
			for name in ["TierHeading", "TierI", "TierII", "TierIII", "PartName", "PartMeta",
					"PartText", "StatLine", "AbilityLine", "RanksLine", "NumbersLine",
					"EffectsLine", "MovementLine"]:
				no_overlap = no_overlap and not patch_rect.intersects(
					inspector.get_node("DetailsPanel/" + name).get_global_rect())
			for name in ["OwnerFilter", "SlotHead", "SlotArms", "SlotTorso", "SlotLegs",
					"PartScroll"]:
				no_overlap = no_overlap and not patch_rect.intersects(
					inspector.get_node("CatalogPanel/" + name).get_global_rect())
			_check(no_overlap and patch_rect == border.get_global_rect()
				and patch.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and border.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and patch.focus_mode == Control.FOCUS_NONE
				and border.focus_mode == Control.FOCUS_NONE,
				"aligned nonblocking patch and edging do not cover existing labels, buttons or list")
			var metadata := inspector.get_node("DetailsPanel/PartMeta") as Label
			var maker_lines := metadata.text.split("\n")
			var label_font := metadata.get_theme_font("font")
			var label_size := metadata.get_theme_font_size("font_size")
			var metadata_fits := maker_lines.size() == 2 and (
				label_font.get_height(label_size) * 2 <= metadata.size.y)
			for line in maker_lines:
				metadata_fits = metadata_fits and label_font.get_string_size(
					line, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x <= metadata.size.x
			_check(metadata_fits,
				"existing ID and appended maker-thread line both fit in the DetailsPanel")
			_check(patch.visible and patch.texture != null
				and patch.texture.resource_path == part_path and border.texture == null
				and metadata.text.contains("THREAD: CRIMSON"),
				"live catalog has bespoke head artwork and real crimson maker thread, no tier-I knot")
			await _click(tier_two)
			_check(inspector.selected_tier == 2 and patch.texture != null
				and patch.texture.resource_path == part_path
				and border.visible and border.texture != null
				and border.texture.resource_path.ends_with("border_2.png"),
				"real tier-II click layers double-stitch border without swapping patch art")
			await _key(KEY_TAB)
			_check(root.gui_get_focus_owner() == inspector.get_node("DetailsPanel/TierIII"),
				"Tab follows existing inspector tier ring despite passive art")
			await _key(KEY_TAB, true)
			_check(root.gui_get_focus_owner() == tier_two,
				"Shift-Tab returns to tier II; preview creates no extra focus target")
		await _click(inspector.get_node("CloseButton"))
		_check(not guide._atlas_is_open() and root.gui_get_focus_owner() == guide.atlas_button
			and inspector.selected_part_id.is_empty() and
			inspector.get_node("DetailsPanel/PatchPreview").texture == null and
			inspector.get_node("DetailsPanel/TierBorderPreview").texture == null,
			"inspector Close restores guide action and clears hidden textures")
		await _key(KEY_ENTER)
		_check(guide._atlas_is_open() and inspector.is_visible_in_tree(),
			"guide action reopens the atlas from keyboard")
		await _key(KEY_ESCAPE)
		_check(not guide._atlas_is_open() and root.gui_get_focus_owner() == guide.atlas_button
			and inspector.get_node("DetailsPanel/PatchPreview").texture == null,
			"atlas Escape returns focus and wipes stale preview")
		var original_catalog := guide.catalog_paths[0]
		guide.catalog_paths[0] = "res://data/parts/missing_s4_catalog.json"
		_check(not guide.open_part_atlas() and not guide._atlas_is_open()
			and inspector.selected_part_id.is_empty()
			and inspector.get_node("DetailsPanel/PatchPreview").texture == null
			and inspector.get_node("DetailsPanel/TierBorderPreview").texture == null
			and not inspector.get_node("DetailsPanel/PartMeta").text.contains("THREAD:"),
			"invalid live source fails closed without leaked art or thread metadata")
		guide.catalog_paths[0] = original_catalog
		_check(_state() == before_atlas and randi() == atlas_next_rng,
			"atlas navigation, failure and dismissal leave wallet, choices, signals and RNG untouched")
	seed(501006)
	var next_rng := randi()
	seed(501006)
	var witness := _state()
	view._on_back_pressed()
	view._on_set_out_pressed()
	view._on_parts_pressed()
	view._on_heroes_house_pressed()
	view._on_camp_house_pressed()
	view._on_path_pressed(String(seam[0]["id"]))
	view._on_tinker_path_pressed(String(tinker[0]["id"]))
	view._on_warden_path_pressed(String(warden[0]["id"]), view.warden_buttons[0])
	view._request_difficulty(0)
	_check(not view.mark_path_selected(String(seam[0]["id"]), String(seam[0]["display_name"]))
		and not view.mark_tinker_path_selected(String(tinker[0]["id"]), String(tinker[0]["display_name"]))
		and not view.mark_warden_path_selected(String(warden[0]["id"]), String(warden[0]["display_name"])),
		"host confirmation cannot select Paths through an open modal")
	view._on_guide_pressed()
	_check(guide.is_open() and view.get_children().filter(func(node: Node) -> bool: return node is StitchedFieldGuide).size() == 1,
		"repeated entry is inert, with no duplicate overlay")
	_check(_state() == witness and randi() == next_rng,
		"all stale underlying actions preserve signals, wallet, choice, parts inspector and seeded RNG")
	await _click(guide.close_button)
	_check(not guide.is_open() and not guide.visible and root.gui_get_focus_owner() == entry
		and not entry.disabled, "pointer Close dismisses and restores guide entry focus")
	await _click(entry)
	_check(guide.is_open(), "pointer reopens same mounted guide")
	await _key(KEY_ESCAPE)
	_check(not guide.is_open() and root.gui_get_focus_owner() == entry,
		"Escape dismisses and restores guide entry focus")
	await _click(view.parts_button)
	_check(view.field_guide.is_open() and entry.disabled,
		"Parts opens nested inspector and blocks both Base entries")
	view._on_guide_pressed()
	_check(guide.is_open() and guide.part_atlas.is_visible_in_tree(), "Parts-open stale guide request is inert")
	view._on_field_guide_close_requested()
	await _frames()
	_check(not view.field_guide.is_open() and not entry.disabled,
		"closing Parts inspector restores the guide entry")
	view._on_set_out_pressed()
	_check(view._set_out_pending and entry.disabled and set_out_calls == 1,
		"pending Set out blocks guide without changing existing one-shot dispatch")
	view._on_guide_pressed()
	_check(not guide.is_open(), "pending host Set out rejects guide")
	_check(view.release_set_out() and not entry.disabled, "host refusal restores entry")
	await _click(entry)
	_check(guide.is_open(), "guide opens again after pending release")
	view.hide()
	await _frames()
	_check(not guide.is_open() and not guide.visible, "hiding parent dismisses modal")
	view.show()
	await _frames()
	_check(not guide.is_open() and not entry.disabled, "showing parent has no stale guide")
	await _click(entry)
	_check(guide.is_open(), "guide remains reusable after parent hide/show")
	view.close_village()
	_check(not guide.is_open() and not view.has_open_village() and entry.disabled,
		"closing parent dismisses modal and disables entry")
	view._on_guide_pressed()
	_check(not guide.is_open(), "closed parent rejects stale entry")
	_check(view.open_village(27, 6), "second actual host entry is supported")
	await _frames()
	await _click(entry)
	_check(guide.is_open() and view.get_children().filter(func(node: Node) -> bool: return node is StitchedFieldGuide).size() == 1,
		"subsequent village uses same guide without callbacks or nodes multiplying")
	await _key(KEY_ESCAPE)
	_check(not guide.is_open() and view.wallet_label.text == "Gold 27  ·  Scraps 6"
		and not view._back_pending and not view._set_out_pending,
		"second Escape leaves real village actions live and wallet unchanged")
	view._on_back_pressed()
	_check(back_calls == 1 and view._back_pending,
		"normal original Back callback works after guide dismissal")
	view.close_village()
	view.queue_free()
	await _frames()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("stitched_s4_village_combat_guide_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		printerr("stitched_s4_village_combat_guide_test: FAIL (%d/%d)" % [failures.size(), checks])
		quit(1)
