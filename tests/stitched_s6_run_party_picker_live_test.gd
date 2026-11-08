extends SceneTree
## Physical input against the actual mounted title and Wren-room New Run entry.
const SAVE := "user://stitched_s6_run_party_picker_live_test.save"
const WARN_SUFFIX := "Warden at rank 4 cannot launch a signature move; Move/Pass remain possible."

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, detail: String) -> void:
	checks += 1
	if not value:
		failures.append(detail)


func _mouse(button: Button) -> void:
	await process_frame
	await process_frame
	if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
		_check(false, "physical click target missing or disabled")
		return
	var at := button.get_global_rect().get_center()
	var hover := InputEventMouseMotion.new()
	hover.position = at
	root.push_input(hover, true)
	await process_frame
	for down in [true, false]:
		var input := InputEventMouseButton.new()
		input.button_index = MOUSE_BUTTON_LEFT
		input.position = at
		input.pressed = down
		root.push_input(input, true)
		await process_frame


func _key(code: Key) -> void:
	for down in [true, false]:
		var input := InputEventKey.new()
		input.keycode = code
		input.physical_keycode = code
		input.pressed = down
		Input.parse_input_event(input)
		await process_frame


func _picker(app: Node) -> StitchedRunPartyPicker:
	if not is_instance_valid(app.stitched_run_panel):
		_check(false, "production picker exists")
		return null
	var picker := app.stitched_run_panel.find_child("StitchedRunPartyPicker", true, false) as StitchedRunPartyPicker
	_check(picker != null and picker.is_visible_in_tree()
		and app.stitched_run_buttons.size() == 2
		and app.stitched_run_buttons[0].text == "Set out"
		and app.stitched_run_buttons[1].text == "Cancel",
		"live picker and both public actions are mounted in original order")
	return picker


## Examine the real GridContainer children in row-major display order, not tiles' dictionary.
func _visual_tile_ids(picker: StitchedRunPartyPicker) -> Array:
	var result: Array = []
	for child in picker.get_children():
		if child is Button:
			result.append(child.get_meta("hero_id", ""))
	return result


func _check_order(picker: StitchedRunPartyPicker, first: Array, rest: Array, context: String) -> void:
	if picker == null:
		return
	var expected := first + rest
	var actual := _visual_tile_ids(picker)
	_check(picker.columns == 2 and actual == expected
		and picker.get_child_count() == StitchedPartyAdmission.HERO_IDS.size(),
		context + ": exactly the original two-column tiles appear selected-first (actual %s, expected %s)" % [actual, expected])
	_check(picker.displayed_rank_ids() == (first if first.size() == 4 else []),
		context + ": only a complete admission exposes four pictured ranks")
	for i in range(mini(expected.size(), picker.get_child_count())):
		var child := picker.get_child(i) as Button
		_check(child == picker.tiles.get(expected[i]) and child.name == "HeroTile_" + str(expected[i]),
			context + ": original button instance occupies visual slot %d" % i)
	for row in range(picker.get_child_count() / 2):
		var left := picker.get_child(row * 2) as Button
		var right := picker.get_child(row * 2 + 1) as Button
		var a := left.get_global_rect()
		var b := right.get_global_rect()
		_check(a.end.x <= b.position.x and absf(a.position.y - b.position.y) < 1.0,
			context + ": left/right row-major geometry %d" % row)
		if row > 0:
			var above := (picker.get_child((row - 1) * 2) as Button).get_global_rect()
			_check(above.end.y <= a.position.y, context + ": row %d stays below prior row" % row)


func _default(picker: StitchedRunPartyPicker, app: Node) -> void:
	if picker == null:
		return
	_check(picker.tiles.size() == StitchedPartyAdmission.HERO_IDS.size() and picker.selected_ids() == StitchedRunSession.DEFAULT_PICKS
		and app.stitched_run_draft == StitchedRunSession.DEFAULT_PICKS
		and picker.tiles_match_draft(), "eight tiles, four authored defaults, consistent checked draft")
	var admission := StitchedPartyAdmission.admit(StitchedRunSession.DEFAULT_PICKS)
	_check(admission.get("ok") == true and admission.get("hero_ids") == StitchedRunSession.DEFAULT_PICKS,
		"authored defaults have a real front-to-back admission receipt")
	_check_order(picker, admission.get("hero_ids", []),
		["rag_duelist", "scarecrow", "yarn_ranger", "button_golem"],
		"mounted default New Run")
	for id in StitchedPartyAdmission.HERO_IDS:
		var tile: Button = picker.tiles.get(id)
		var art: TextureRect = tile.get_node("Portrait") if tile != null else null
		var nameplate: Label = tile.get_node("DollName") if tile != null else null
		_check(tile != null and tile.focus_mode == Control.FOCUS_ALL
			and tile.button_pressed == (id in StitchedRunSession.DEFAULT_PICKS)
			and tile.get_meta("hero_id") == id and tile.get_global_rect().has_area()
			and art != null and art.get_meta("art_path") == "res://assets/paper/heroes/" + id + ".png"
			and (not ResourceLoader.exists("res://assets/paper/heroes/" + id + ".png", "Texture2D")
				or art.texture != null)
			and nameplate != null and nameplate.text.contains(id.replace("_", " ").capitalize()),
			"authored picture path, readable name, checked and focusable real hit area for " + id)
	_check_hints(picker, picker.tiles, "mounted default")
	_check(not app.stitched_run_buttons[0].disabled
		and app.stitched_run_buttons[0].focus_mode == Control.FOCUS_ALL
		and app.stitched_run_session == null and app.run_rng == null and app.deck == null,
		"default picker enables Set out but allocates no run or old deck")


## Real pointer motion must land on the original Button, not a new hint control.
func _hover(tile: Button) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = tile.get_global_rect().get_center()
	root.push_input(motion, true)
	await process_frame


## Independently reconstruct displayed strings from shipped S14 records rather
## than comparing the formatter with itself or keeping a second ability table.
func _check_hints(picker: StitchedRunPartyPicker, originals: Dictionary, context: String, marked_id: String = "") -> void:
	if picker == null:
		_check(false, context + ": picker is present for hints")
		return
	var catalog := StitchedS14Abilities.kits()
	_check(not catalog.is_empty(), context + ": validated S14 catalog loads")
	var sides := {"enemy": "Foe", "ally": "Ally", "self": "Self"}
	var slots := ["head", "arms", "torso", "legs"]
	var focusable := 0
	for child in picker.get_children():
		if child is Control and child.focus_mode != Control.FOCUS_NONE:
			focusable += 1
	_check(picker.get_child_count() == StitchedPartyAdmission.HERO_IDS.size()
		and focusable == StitchedPartyAdmission.HERO_IDS.size(),
		context + ": hints add no visible or focusable controls")
	for id in StitchedPartyAdmission.HERO_IDS:
		var tile: Button = picker.tiles.get(id)
		var kit: Variant = catalog.get(id)
		if tile == null or not kit is Dictionary:
			_check(false, context + ": real tile and validated kit exist for " + id)
			continue
		var lines: Array[String] = []
		for slot in slots:
			var entry: Variant = kit.get(slot)
			if not entry is Dictionary or not sides.has(entry.get("target_side", null)):
				_check(false, context + ": complete authored " + slot + " entry for " + id)
				continue
			lines.append("%s — %s · %s" % [
				slot.capitalize(), str(entry.get("name", "")), sides[entry["target_side"]]])
		var expected_tooltip := "\n".join(lines)
		if id == marked_id:
			expected_tooltip += "\n" + WARN_SUFFIX
		_check(lines.size() == 4 and tile.tooltip_text == expected_tooltip
			and tile.tooltip_text.split("\n").size() == (5 if id == marked_id else 4),
			context + ": " + id + " keeps all four S14 lines and only its authentic warning suffix")
		var nameplate: Label = tile.get_node("DollName")
		_check(tile.get_child_count() == 2 and nameplate.get_theme_color("font_color")
			== (StitchedRunPartyPicker.WARNING_BONE if id == marked_id else (
				StitchedRunPartyPicker.AMBER if tile.button_pressed else StitchedRunPartyPicker.BONE))
			and nameplate.get_theme_color("font_shadow_color")
			== (StitchedRunPartyPicker.OXBLOOD if id == marked_id else StitchedRunPartyPicker.SHADOW),
			context + ": " + id + " retains exactly its original portrait/name, with reversible bone/oxblood cue")
		var pressed := tile.get_theme_stylebox("pressed") as StyleBoxTexture
		if pressed != null:
			_check(pressed.modulate_color == (StitchedRunPartyPicker.OXBLOOD if id == marked_id
				else Color("#d4a160")),
				context + ": " + id + " retains the image-skinned tile, tinted only for warning")
		_check(tile == originals.get(id) and tile.name == "HeroTile_" + id
			and tile.get_meta("hero_id") == id and tile.focus_mode == Control.FOCUS_ALL
			and tile.get_node_or_null("Portrait") is TextureRect
			and tile.get_node_or_null("DollName") is Label,
			context + ": original portrait/name/focusable Button remains attached to " + id)
	_check(picker.tiles["warden"].tooltip_text.contains("Head — Pot Helm Command · Foe")
		and picker.tiles["warden"].tooltip_text.contains("Arms — Shield Catch · Ally")
		and picker.tiles["warden"].tooltip_text.contains("Torso — Iron Challenge · Foe")
		and picker.tiles["warden"].tooltip_text.contains("Legs — Rim Toss · Foe"),
		context + ": Warden's four contrasting authored move names are legible")
	_check(picker.tiles["seamstress"].tooltip_text.contains("Head — Mending Knot · Ally")
		and picker.tiles["seamstress"].tooltip_text.contains("Arms — Needle Prick · Foe")
		and picker.tiles["seamstress"].tooltip_text.contains("Torso — Shielding Hem · Ally")
		and picker.tiles["seamstress"].tooltip_text.contains("Legs — Tether Spools · Foe"),
		context + ": Seamstress's ally and foe moves are distinguished")
	_check(picker.tiles["tinker"].tooltip_text.contains("Torso — Casing Ward · Self"),
		context + ": Tinker's self-only move is labelled Self")


func _invalid_hints() -> void:
	var source := StitchedS14Abilities.kits()
	_check(not source.is_empty() and source.has("warden") and source.has("tinker"),
		"negative projections start from genuine validated S14 kits")
	_check(StitchedPartyKitHints.tooltip("not_a_doll", source) == ""
		and StitchedPartyKitHints.tooltip("warden", {}) == ""
		and StitchedPartyKitHints.tooltip("warden", []) == "",
		"unknown hero, absent kit and invalid source claim no ability names")
	var bad := source.duplicate(true)
	bad.erase("warden")
	_check(StitchedPartyKitHints.tooltip("warden", bad) == "", "missing hero kit fails closed")
	bad = source.duplicate(true)
	bad["warden"].erase("legs")
	_check(StitchedPartyKitHints.tooltip("warden", bad) == "", "incomplete four-slot kit fails closed")
	bad = source.duplicate(true)
	bad["warden"]["arms"]["slot"] = "head"
	_check(StitchedPartyKitHints.tooltip("warden", bad) == "", "mismatched slot fails closed")
	bad = source.duplicate(true)
	bad["warden"]["arms"] = bad["warden"]["head"].duplicate(true)
	bad["warden"]["arms"]["slot"] = "arms"
	_check(StitchedPartyKitHints.tooltip("warden", bad) == "", "duplicate move IDs fail closed")
	bad = source.duplicate(true)
	bad["warden"]["head"]["target_side"] = "friend"
	_check(StitchedPartyKitHints.tooltip("warden", bad) == "", "unknown side fails closed")
	bad = source.duplicate(true)
	bad["warden"]["head"].erase("target_side")
	_check(StitchedPartyKitHints.tooltip("warden", bad) == "", "missing side fails closed")
	bad = source.duplicate(true)
	bad["warden"]["torso"]["name"] = ""
	_check(StitchedPartyKitHints.tooltip("warden", bad) == "", "empty move name fails closed")
	bad = source.duplicate(true)
	bad["warden"]["legs"]["acc"] = -1
	_check(StitchedPartyKitHints.tooltip("warden", bad) == "", "invalid S14 ability field fails closed")
	bad = source.duplicate(true)
	bad["warden"]["extra_slot"] = bad["warden"]["head"].duplicate(true)
	_check(StitchedPartyKitHints.tooltip("warden", bad) == "", "fifth unexpected slot fails closed")
	_check(StitchedS14Abilities.kits() == source
		and not StitchedPartyKitHints.tooltip("warden").is_empty(),
		"in-memory corruptions neither poison the shipped cache nor prevent later hints")


## Independent source-based oracle: use admission's canonical seating and read the
## four real checked signatures directly, without calling the advisory formatter.
func _source_opening_counts(picks: Array, catalog: Dictionary) -> Dictionary:
	var admission := StitchedPartyAdmission.admit(picks)
	if admission.get("ok") != true:
		return {}
	var result := {}
	for index in admission["hero_ids"].size():
		var id: String = admission["hero_ids"][index]
		var count := 0
		for slot in StitchedParts.SLOTS:
			var signature: Dictionary = catalog[id][slot]
			if index + 1 in signature["launch"]:
				count += 1
		result[id] = count
	return result


func _advisory_fixtures() -> void:
	var catalog := StitchedS14Abilities.kits()
	var witness := ["rag_duelist", "scarecrow", "button_golem", "warden"]
	var admission := StitchedPartyAdmission.admit(witness)
	_check(not catalog.is_empty() and admission.get("ok") == true
		and admission.get("hero_ids") == witness and admission.get("heroes", []).size() == 4,
		"real S14 witness admits Rag, Scarecrow, Golem, Warden to ranks 1, 2, 3, 4")
	if catalog.is_empty() or admission.get("ok") != true:
		return
	var counts := _source_opening_counts(witness, catalog)
	var warden_launches: Array = []
	for slot in StitchedParts.SLOTS:
		warden_launches.append(catalog["warden"][slot]["launch"])
	var warn := StitchedPartyKitHints.opening_rank_advisory(witness, catalog)
	var stranded := StitchedPartyKitHints.opening_rank_stranded(witness, catalog)
	_check(stranded == [{"id": "warden", "name": "Warden", "rank": 4}]
		and StitchedPartyKitHints.opening_rank_stranded(witness) == stranded,
		"pure validated rank helper identifies exactly the admitted original Warden tile")
	_check(counts.size() == 4 and counts.get("warden", -1) == 0
		and counts.get("rag_duelist", 0) > 0 and counts.get("scarecrow", 0) > 0
		and counts.get("button_golem", 0) > 0
		and warden_launches == [[1, 2, 3], [1, 2, 3], [1, 2], [1, 2, 3]],
		"independent four-slot authored launches strand only rank-4 Warden")
	_check(warn.contains("Warden") and warn.contains("rank 4")
		and warn.contains("cannot launch") and warn.contains("Move") and warn.contains("Pass")
		and not warn.contains("Scarecrow at rank"),
		"only rank-4 Warden is warned, and Move/Pass stays available")
	_check(StitchedPartyKitHints.opening_rank_stranded(StitchedRunSession.DEFAULT_PICKS, catalog).is_empty()
		and StitchedPartyKitHints.opening_rank_stranded(
			["rag_duelist", "scarecrow", "button_golem", "yarn_ranger"], catalog).is_empty(),
		"safe default and safe replacement have no stranded tile ids or ranks")
	var default_counts := _source_opening_counts(StitchedRunSession.DEFAULT_PICKS, catalog)
	var default_safe := default_counts.size() == StitchedPartyAdmission.RANK_COUNT
	for count in default_counts.values():
		default_safe = default_safe and count > 0
	_check(default_safe and StitchedPartyKitHints.opening_rank_advisory(
		StitchedRunSession.DEFAULT_PICKS, catalog) == ""
		and StitchedPartyKitHints.opening_rank_advisory(
			["rag_duelist", "scarecrow", "button_golem", "yarn_ranger"], catalog) == "",
		"independent launch fixture confirms defaults and alternate re-pick require no warning")
	_check(StitchedPartyKitHints.opening_rank_advisory(witness) == warn
		and StitchedPartyKitHints.opening_rank_advisory([]) == ""
		and StitchedPartyKitHints.opening_rank_advisory(["warden"]) == ""
		and StitchedPartyKitHints.opening_rank_advisory(
			["warden", "seamstress", "tinker", "warden"]) == ""
		and StitchedPartyKitHints.opening_rank_advisory(
			["warden", "seamstress", "tinker", "bogus"]) == ""
		and StitchedPartyKitHints.opening_rank_advisory(
			["warden", "seamstress", "tinker", "lantern_monk", "scarecrow"]) == ""
		and StitchedPartyKitHints.opening_rank_advisory("not picks") == ""
		and StitchedPartyKitHints.opening_rank_advisory(witness, []) == "",
		"authentic default catalog agrees; incomplete, duplicate, unknown, overfull and forged picks fail closed")
	var invalid := catalog.duplicate(true)
	invalid.erase("warden")
	_check(StitchedPartyKitHints.opening_rank_advisory(witness, invalid) == "",
		"missing selected hero kit gives no opening claim")
	invalid = catalog.duplicate(true)
	invalid["warden"].erase("legs")
	_check(StitchedPartyKitHints.opening_rank_advisory(witness, invalid) == "",
		"missing selected signature gives no opening claim")
	invalid = catalog.duplicate(true)
	invalid["warden"]["arms"]["slot"] = "head"
	_check(StitchedPartyKitHints.opening_rank_advisory(witness, invalid) == "",
		"forged signature slot gives no opening claim")
	invalid = catalog.duplicate(true)
	invalid["warden"]["head"].erase("launch")
	_check(StitchedPartyKitHints.opening_rank_advisory(witness, invalid) == "",
		"missing authored launch array gives no opening claim")
	invalid = catalog.duplicate(true)
	invalid["warden"]["head"]["launch"] = [4, 4]
	_check(StitchedPartyKitHints.opening_rank_advisory(witness, invalid) == "",
		"duplicate authored launch rank cannot falsely clear warning")
	invalid = catalog.duplicate(true)
	invalid["warden"]["head"]["launch"] = [4.0]
	_check(StitchedPartyKitHints.opening_rank_advisory(witness, invalid) == "",
		"non-integer authored launch array is rejected")
	invalid = catalog.duplicate(true)
	invalid["warden"]["head"]["target_side"] = "neutral"
	_check(StitchedPartyKitHints.opening_rank_advisory(witness, invalid) == "",
		"invalid signature target side gives no opening claim")
	invalid = catalog.duplicate(true)
	invalid["warden"]["head"]["target"] = []
	_check(StitchedPartyKitHints.opening_rank_advisory(witness, invalid) == "",
		"invalid signature target ranks give no opening claim")
	invalid = catalog.duplicate(true)
	invalid["warden"]["arms"]["id"] = invalid["warden"]["head"]["id"]
	_check(StitchedPartyKitHints.opening_rank_advisory(witness, invalid) == "",
		"duplicate signature identifiers give no opening claim")
	# The tile service has no second, less-strict ability parser.
	var invalid_picks: Array = [[], ["warden"], "not picks",
		["warden", "seamstress", "tinker", "warden"],
		["warden", "seamstress", "tinker", "bogus"],
		["warden", "seamstress", "tinker", "lantern_monk", "scarecrow"]]
	for draft in invalid_picks:
		_check(StitchedPartyKitHints.opening_rank_stranded(draft, catalog).is_empty(),
			"malformed, duplicate, unknown and overfull rank-helper inputs give no cue")
	var invalid_catalogs: Array = []
	for field in ["slot", "launch", "target_side", "target", "name", "id"]:
		var forged := catalog.duplicate(true)
		match field:
			"slot":
				forged["warden"]["arms"]["slot"] = "head"
			"launch":
				forged["warden"]["head"]["launch"] = [4.0]
			"target_side":
				forged["warden"]["head"]["target_side"] = "neutral"
			"target":
				forged["warden"]["head"]["target"] = []
			"name":
				forged["warden"]["arms"]["name"] = forged["warden"]["head"]["name"]
			"id":
				forged["warden"]["arms"]["id"] = forged["warden"]["head"]["id"]
		invalid_catalogs.append(forged)
	var missing := catalog.duplicate(true)
	missing.erase("warden")
	invalid_catalogs.append(missing)
	missing = catalog.duplicate(true)
	missing["warden"].erase("legs")
	invalid_catalogs.append(missing)
	for forged in invalid_catalogs:
		_check(StitchedPartyKitHints.opening_rank_stranded(witness, forged).is_empty()
			and StitchedPartyKitHints.opening_rank_advisory(witness, forged) == "",
			"forged signature validation rejects both advisory and tile cues")
	_check(StitchedPartyKitHints.opening_rank_stranded(witness, []).is_empty()
		and StitchedPartyKitHints.opening_rank_stranded(witness, {}).is_empty()
		and StitchedS14Abilities.kits() == catalog,
		"nondictionary, absent and corrupt fixture sources leave S14 cache untouched")
	_check(StitchedS14Abilities.kits() == catalog
		and StitchedPartyKitHints.opening_rank_advisory(witness) == warn,
		"negative fixture mutations cannot corrupt cached real S14 signatures")


## Drive the actual mounted picker through the stranded quartet, a safe re-pick,
## and the same production Set out Button. Return to a fresh default picker so
## the existing focus, Cancel, rapid reflow and full-run checks stay intact.
func _exercise_opening_warning(app: Node, picker: StitchedRunPartyPicker) -> StitchedRunPartyPicker:
	var actions: Array = app.stitched_run_buttons.duplicate()
	var action_row: Node = actions[0].get_parent()
	var panel_children: int = app.stitched_run_panel.get_child_count()
	var wallet_before := [app.session_gold, app.run_scraps]
	var witness := ["rag_duelist", "scarecrow", "button_golem", "warden"]
	var originals: Dictionary = picker.tiles.duplicate()
	var old_pressed: StyleBox = originals["warden"].get_theme_stylebox("pressed")
	var old_hover_pressed: StyleBox = originals["warden"].get_theme_stylebox("hover_pressed")
	var old_focus: StyleBox = originals["warden"].get_theme_stylebox("focus")
	_check(actions[0].tooltip_text == "" and not actions[0].disabled,
		"mounted default Set out has no speculative rank warning")
	for id in StitchedRunSession.DEFAULT_PICKS:
		await _mouse(picker.tiles[id])
	_check(picker.selected_ids().is_empty() and app.stitched_run_draft.is_empty()
		and actions[0].disabled and actions[0].focus_mode == Control.FOCUS_NONE
		and actions[0].tooltip_text == "" and app.stitched_run_session == null,
		"empty draft disables confirm, clears warning and does not start a run")
	_check_hints(picker, originals, "empty draft strips stale cues")
	for id in witness:
		await _mouse(picker.tiles[id])
	var receipt := StitchedPartyAdmission.admit(witness)
	_check(picker.selected_ids() == witness and app.stitched_run_draft == witness
		and picker.displayed_rank_ids() == receipt.get("hero_ids", [])
		and picker.tiles_match_draft() and not actions[0].disabled
		and actions[0].focus_mode == Control.FOCUS_ALL,
		"real pointer picks reach canonical stranded rank-4 Warden without disabling Set out")
	var warning: String = actions[0].tooltip_text
	_check(warning == StitchedPartyKitHints.opening_rank_advisory(witness)
		and warning.contains("Warden") and warning.contains("rank 4")
		and warning.contains("Move") and warning.contains("Pass"),
		"existing mounted Set out Button displays only source-derived Warden warning")
	_check_hints(picker, originals, "original tiles after physical stranded picks", "warden")
	_check(originals["warden"].get_theme_stylebox("pressed") != old_pressed
		and originals["warden"].get_theme_stylebox("hover_pressed") != old_hover_pressed
		and originals["warden"].get_theme_stylebox("focus") != old_focus,
		"only Warden's existing skinned button faces are warned, not replaced by new controls")
	picker.draft_changed.emit(["warden", "warden", "tinker", "lantern_monk"])
	_check(app.stitched_run_draft == witness and actions[0].tooltip_text == warning
		and originals["warden"].tooltip_text.ends_with(WARN_SUFFIX),
		"forged draft_changed signal cannot replace accepted warning or App tile cue")
	await _mouse(picker.tiles["warden"])
	_check(actions[0].disabled and actions[0].tooltip_text == ""
		and app.stitched_run_draft.size() == 3,
		"warning is removed immediately when the stranded composition becomes incomplete")
	_check_hints(picker, originals, "deselect Warden immediately clears original styles")
	_check(originals["warden"].get_theme_stylebox("pressed") == old_pressed
		and originals["warden"].get_theme_stylebox("hover_pressed") == old_hover_pressed
		and originals["warden"].get_theme_stylebox("focus") == old_focus,
		"clearing an incomplete draft restores the identical original skinned style objects")
	await _mouse(picker.tiles["yarn_ranger"])
	var safe := ["rag_duelist", "scarecrow", "button_golem", "yarn_ranger"]
	_check(picker.selected_ids() == safe and picker.displayed_rank_ids()
		== StitchedPartyAdmission.admit(safe).get("hero_ids", [])
		and actions[0].tooltip_text == "" and not actions[0].disabled,
		"safe four-doll replacement clears old warning and leaves Set out available")
	_check_hints(picker, originals, "safe yarn-ranger replacement has no marks")
	await _mouse(picker.tiles["yarn_ranger"])
	await _mouse(picker.tiles["warden"])
	_check(picker.selected_ids() == witness and actions[0].tooltip_text == warning,
		"restoring rank-4 Warden restores the warning on the same Set out Button")
	_check_hints(picker, originals, "restored rank-4 Warden cue", "warden")
	_check(app.stitched_run_buttons == actions and action_row.get_child_count() == 2
		and app.stitched_run_panel.get_child_count() == panel_children
		and picker.get_child_count() == StitchedPartyAdmission.HERO_IDS.size(),
		"advisory adds no action, panel or extra tile and preserves original action indices")
	_check_hints(picker, originals, "after warning and safe re-pick", "warden")
	_check(app.stitched_run_session == null and app.run_rng == null and app.run_map == null
		and [app.session_gold, app.run_scraps] == wallet_before,
		"rank preview creates no session, map, RNG or wallet side effects")
	var active_epoch: int = app._stitched_run_epoch
	app._stitched_run_epoch = active_epoch + 1
	actions[0].tooltip_text = "stale signal witness"
	picker.draft_changed.emit(witness)
	_check(actions[0].tooltip_text == "stale signal witness"
		and app.stitched_run_session == null and originals["warden"].tooltip_text.ends_with(WARN_SUFFIX),
		"stale epoch draft_changed cannot rewrite previous Set out tooltip or tile cue")
	app._stitched_run_epoch = active_epoch
	picker.draft_changed.emit(witness)
	_check(actions[0].tooltip_text == warning,
		"accepted same-draft signal restores truthful warning after stale signal")
	await _mouse(actions[0])
	var session: StitchedRunSession = app.stitched_run_session
	var expected := StitchedRunSession.start(7311, witness)
	var seeded_ids: Array = []
	if session != null:
		for hero in session.heroes:
			seeded_ids.append(hero.id)
	_check(session != null and expected != null and session.is_consistent()
		and session.picks == witness and seeded_ids == receipt.get("hero_ids", [])
		and session.snapshot() == expected.snapshot() and app.stitched_run_intro != null
		and app.run_rng == null and app.deck == null,
		"warned yet enabled production Set out starts identical seeded canonical four-rank session")
	app._return_stitched_run_title()
	_check(app.stitched_run_session == null and app.stitched_run_draft != witness,
		"closing the warned run clears session and previously accepted draft")
	await process_frame
	await _mouse(app.start_button)
	var fresh := _picker(app)
	_check(fresh != null and fresh != picker and fresh.selected_ids() == StitchedRunSession.DEFAULT_PICKS
		and app.stitched_run_buttons[0].tooltip_text == "",
		"fresh picker has no stale warning after previous session and epoch")
	return fresh


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_advisory_fixtures()
	_invalid_hints()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var app: Node = (load("res://scenes/app.tscn") as PackedScene).instantiate()
	_check(app != null, "production res://scenes/app.tscn instantiates")
	if app == null:
		_finish()
		return
	app.stitched_walks = false
	app.run_seed = 7311
	app.stitched_save_path = SAVE
	app.wren_gifts_profile_path = "user://s6_run_picker_missing_gifts.json"
	root.add_child(app)
	await process_frame
	_check(app.start_button != null and app.title_view.is_visible_in_tree()
		and app.start_button.has_focus(), "actual title boots with focused New Run")
	await _mouse(app.start_button)
	var picker := _picker(app)
	if picker == null:
		app.free()
		_finish()
		return
	await process_frame
	_default(picker, app)
	picker = await _exercise_opening_warning(app, picker)
	if picker == null:
		app.free()
		_finish()
		return
	_default(picker, app)
	var original_tiles: Dictionary = picker.tiles.duplicate()
	var draft_receipts: Array = []
	picker.draft_changed.connect(func(picks: Array) -> void: draft_receipts.append(picks.duplicate()))
	await _hover(original_tiles["warden"])
	_check(root.gui_get_hovered_control() == original_tiles["warden"]
		and not original_tiles["warden"].tooltip_text.is_empty(),
		"physical pointer hovers original Warden Button with a native S14 tooltip")
	var wallet_before := [app.session_gold, app.run_scraps]
	var reachable: Dictionary = {}
	for step in range(StitchedPartyAdmission.HERO_IDS.size() + 3):
		await _key(KEY_TAB)
		for id in StitchedPartyAdmission.HERO_IDS:
			if picker.tiles[id].has_focus():
				reachable[id] = true
	_check(reachable.size() == StitchedPartyAdmission.HERO_IDS.size(),
		"physical Tab traversal reaches each of the eight pictured choices")
	var viewport := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var earlier_rects: Array[Rect2] = []
	for id in StitchedPartyAdmission.HERO_IDS:
		var tile: Button = picker.tiles[id]
		var rect := tile.get_global_rect()
		_check(viewport.encloses(rect) and rect.size.y >= 80,
			"tile " + id + " is visible at 1280x720 with a full hit target")
		for previous in earlier_rects:
			_check(not rect.intersects(previous), "distinct doll tiles never overlap")
		for action in app.stitched_run_buttons:
			_check(not rect.intersects(action.get_global_rect()), "picker actions do not cover doll hit targets")
		earlier_rects.append(rect)
	# All edits, rejected fifth clicks, and Cancel must be RNG/resource/save-neutral.
	seed(71211)
	var expected_global := randi()
	seed(71211)
	await _mouse(picker.tiles["rag_duelist"])
	_check(not picker.tiles["rag_duelist"].button_pressed
		and picker.selected_ids() == StitchedRunSession.DEFAULT_PICKS
		and app.stitched_run_draft == StitchedRunSession.DEFAULT_PICKS,
		"mouse cannot add a fifth doll while four are chosen")
	_check_order(picker, StitchedRunSession.DEFAULT_PICKS,
		["rag_duelist", "scarecrow", "yarn_ranger", "button_golem"],
		"rejected fifth pick")
	picker.tiles["warden"].grab_focus()
	await _key(KEY_SPACE)
	await process_frame  # Idle-deferred layout moves only after Space has been released.
	_check(not picker.tiles["warden"].button_pressed
		and picker.selected_ids() == ["seamstress", "tinker", "lantern_monk"]
		and app.stitched_run_draft == picker.selected_ids()
		and app.stitched_run_buttons[0].disabled
		and app.stitched_run_buttons[0].focus_mode == Control.FOCUS_NONE,
		"physical keyboard removes Warden and disables/unfocuses incomplete Set out")
	_check(picker.tiles["warden"].has_focus(), "keyboard Space preserves focused tile across reflow")
	_check_order(picker, ["seamstress", "tinker", "lantern_monk"],
		["warden", "rag_duelist", "scarecrow", "yarn_ranger", "button_golem"],
		"incomplete draft has pick order but no invented rank receipt")
	_check(draft_receipts == [["seamstress", "tinker", "lantern_monk"]],
		"one real Space dispatch emits exactly one unchanged draft_changed receipt")
	_check_hints(picker, original_tiles, "after physical deselect and reflow")
	await _hover(original_tiles["warden"])
	_check(root.gui_get_hovered_control() == original_tiles["warden"],
		"reflowed original Warden tile still accepts physical pointer hover")
	# A directly emitted disabled action is also fail-closed, not only a pointer click.
	app.stitched_run_buttons[0].pressed.emit()
	_check(app.stitched_run_session == null and app.run_rng == null,
		"disabled action cannot start a run via its public signal")
	await _mouse(picker.tiles["rag_duelist"])
	var expected_picks := ["seamstress", "tinker", "lantern_monk", "rag_duelist"]
	_check(picker.tiles["rag_duelist"].button_pressed and picker.selected_ids() == expected_picks
		and app.stitched_run_draft == expected_picks and picker.tiles_match_draft()
		and not app.stitched_run_buttons[0].disabled
		and app.stitched_run_buttons[0].focus_mode == Control.FOCUS_ALL,
		"one replacement restores exactly four and enables Set out")
	var expected_ranks := ["rag_duelist", "seamstress", "tinker", "lantern_monk"]
	_check(picker.tiles["rag_duelist"].has_focus(),
		"mouse replacement retains Rag Duelist keyboard focus across grid reorder")
	_check_order(picker, expected_ranks,
		["warden", "scarecrow", "yarn_ranger", "button_golem"],
		"alternate admitted order visibly differs from the click-order draft")
	_check(draft_receipts == [["seamstress", "tinker", "lantern_monk"], expected_picks],
		"physical replacement emits one further stable draft_changed pick-order receipt")
	_check_hints(picker, original_tiles, "after replacement and canonical rank reorder")
	await _hover(original_tiles["rag_duelist"])
	_check(root.gui_get_hovered_control() == original_tiles["rag_duelist"],
		"reordered original Rag Duelist tile still accepts physical pointer hover")
	_check(picker.selected_ids() != picker.displayed_rank_ids(),
		"visible rank order is intentionally distinct from the four-ID draft")
	for id in StitchedPartyAdmission.HERO_IDS:
		_check(picker.tiles[id] == original_tiles[id]
			and picker.tiles[id].get_node("Portrait").get_meta("art_path")
				== "res://assets/paper/heroes/" + id + ".png",
			"rank reflow retains the exact original focusable picture control for " + id)
	await _mouse(picker.tiles["scarecrow"])
	_check(not picker.tiles["scarecrow"].button_pressed and picker.selected_ids() == expected_picks,
		"a second fifth choice still does nothing")
	_check_order(picker, expected_ranks,
		["warden", "scarecrow", "yarn_ranger", "button_golem"],
		"another rejected fifth pick never moves tiles")
	_check(app.stitched_run_session == null and app.run_rng == null and app.run_map == null
		and app.deck == null and app.run_deck.is_empty()
		and [app.session_gold, app.run_scraps] == wallet_before
		and not FileAccess.file_exists(SAVE) and randi() == expected_global,
		"drafting and fifth-choice refusals spend no RNG and allocate no run/save/cards")
	app.stitched_run_draft.append("seamstress")
	app.stitched_run_buttons[0].pressed.emit()
	_check(app.stitched_run_session == null and app.run_rng == null,
		"duplicate overfull stale draft cannot publish a session")
	app.stitched_run_draft = expected_picks.duplicate()
	# A stale/mismatched visible position must not authenticate a new session.
	picker.move_child(picker.tiles["rag_duelist"], 7)
	app.stitched_run_buttons[0].pressed.emit()
	_check(app.stitched_run_session == null and app.run_rng == null,
		"confirmation rejects an internally tampered on-screen rank order")
	picker.move_child(picker.tiles["rag_duelist"], 0)
	_check_order(picker, expected_ranks,
		["warden", "scarecrow", "yarn_ranger", "button_golem"],
		"restoring the genuine rank display re-enables authentic admission")
	var expected_admission := StitchedPartyAdmission.admit(expected_picks)
	_check(expected_admission.get("ok") == true
		and expected_admission.hero_ids == expected_ranks
		and picker.displayed_rank_ids() == expected_admission.hero_ids,
		"canonical four-doll admission equals all four actual pictured ranks")
	await _mouse(app.stitched_run_buttons[0])
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.is_consistent() and app.stitched_run_intro != null,
		"real Set out starts an authentic session and keeps the S9c Wren intro")
	if session != null:
		var actual_ids: Array = []
		for hero in session.heroes:
			actual_ids.append(hero.id)
		var expected := StitchedRunSession.start(7311, expected_picks)
		_check(session.picks == expected_picks and actual_ids == expected_admission.hero_ids
			and session.heroes.size() == 4 and session.journal.is_empty()
			and expected != null and session.snapshot() == expected.snapshot()
			and session.map != null and session.rng != null,
			"original Set out starts exactly seeded canonical ranked snapshot")
		_check(app.deck == null and app.run_rng == null and app.run_map == null,
			"valid four-doll New Run never allocates legacy deck or wallet")
	app._return_stitched_run_title()
	await process_frame
	_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus()
		and app.stitched_run_session == null, "return from real run restores title")
	await _mouse(app.start_button)
	picker = _picker(app)
	_default(picker, app)
	var stale_confirm: Button = app.stitched_run_buttons[0]
	app.stitched_run_buttons[1].pressed.emit()
	stale_confirm.pressed.emit()
	_check(app.stitched_run_session == null and app.title_view.is_visible_in_tree(),
		"cancelled confirmation cannot start a second run while its old node is pending free")
	await process_frame
	await _mouse(app.start_button)
	picker = _picker(app)
	app.stitched_run_buttons[1].grab_focus()
	await _key(KEY_ENTER)
	_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus()
		and app.stitched_run_session == null and app.run_rng == null
		and [app.session_gold, app.run_scraps] == wallet_before,
		"keyboard Cancel restores original focused title with no run or wallet spend")
	await _mouse(app.base_button)
	var village: BaseScreen = app.base_screen
	_check(village != null and village.is_visible_in_tree() and village.has_open_village(),
		"real Wren-room/bedroom source opens")
	if village != null:
		await _mouse(village.set_out_button)
		picker = _picker(app)
		_default(picker, app)
		await _mouse(app.stitched_run_buttons[1])
		_check(village.is_visible_in_tree() and village.set_out_button.has_focus()
			and village.has_open_village() and app.stitched_run_session == null
			and app.run_rng == null and app.deck == null and not FileAccess.file_exists(SAVE)
			and [app.session_gold, app.run_scraps] == wallet_before,
			"Wren-room Cancel returns focus and original browseable bedroom, without save or spend")
		await _mouse(village.set_out_button)
		picker = _picker(app)
		_default(picker, app)
		await _mouse(app.stitched_run_buttons[1])
		# Legacy callers can change several controls and confirm in one event loop.
		# The queued reflow must settle before the authenticated rank check.
		await _mouse(village.set_out_button)
		picker = _picker(app)
		_default(picker, app)
		picker.tiles["warden"].button_pressed = false
		picker.tiles["rag_duelist"].button_pressed = true
		var rapid_picks := ["seamstress", "tinker", "lantern_monk", "rag_duelist"]
		var rapid_ranks := ["rag_duelist", "seamstress", "tinker", "lantern_monk"]
		_check(picker.selected_ids() == rapid_picks and app.stitched_run_draft == rapid_picks
			and picker.displayed_rank_ids() != rapid_ranks,
			"rapid draft has a genuine pending visual reorder before confirmation")
		app.stitched_run_buttons[0].pressed.emit()
		var rapid_session: StitchedRunSession = app.stitched_run_session
		var actual_ranks: Array = []
		if rapid_session != null:
			for hero in rapid_session.heroes:
				actual_ranks.append(hero.id)
		_check(rapid_session != null and rapid_session.picks == rapid_picks
			and actual_ranks == rapid_ranks and app.stitched_run_intro != null,
			"immediate Set out settles pending order and admits genuine preferred ranks")
	app.free()
	await process_frame
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s6_run_party_picker_live_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
