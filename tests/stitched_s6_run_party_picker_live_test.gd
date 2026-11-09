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


func _key_event(code: Key, down: bool, repeat: bool = false, modifier: String = "") -> void:
	var input := InputEventKey.new()
	input.keycode = code
	input.physical_keycode = code
	input.pressed = down
	input.echo = repeat
	input.ctrl_pressed = modifier == "ctrl"
	input.alt_pressed = modifier == "alt"
	input.shift_pressed = modifier == "shift"
	input.meta_pressed = modifier == "meta"
	Input.parse_input_event(input)
	await process_frame


func _key(code: Key) -> void:
	for down in [true, false]:
		await _key_event(code, down)


## Godot's real joypad events, not a direct call to the picker or a fake toggle.
func _joy_event(button: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = down
	event.pressure = 1.0 if down else 0.0
	Input.parse_input_event(event)
	await process_frame


func _shoulder(button: JoyButton) -> void:
	await _joy_event(button, true)
	await _joy_event(button, false)


func _pad_accept() -> void:
	# Project's native ui_accept maps joypad south/A to the original Button.
	await _joy_event(JOY_BUTTON_A, true)
	await _joy_event(JOY_BUTTON_A, false)
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
## Independent native-effect oracle, from source values rather than formatted tooltips.
func _source_effect_phrase(entry: Dictionary) -> String:
	var words: Array[String] = []
	if entry["dmg"][1] > 0:
		words.append("strike")
	var native := {
		"mark": "mark", "guard": "guard", "heal": "mend", "weak": "weaken",
		"exposed": "expose", "bleed": "bleed", "tangled": "tangle",
		"blind": "blind", "stun": "stun", "thorns": "return harm",
		"push": "push back", "pull": "pull forward", "dodge": "evade",
		"riposte": "counterattack",
	}
	for effect in StitchedParts.EFFECT_KEYS:
		if effect != "duration" and entry["effects"].has(effect):
			words.append(native.get(effect, "apply " + effect.replace("_", " ")))
	var description := "use this move"
	if words.size() == 1:
		description = words[0]
	elif words.size() > 1:
		description = ", ".join(words.slice(0, words.size() - 1)) + " and " + words[-1]
	if entry["multi"]:
		match entry["target_side"]:
			"enemy": description += " several eligible foes"
			"ally": description += " several eligible allies"
			_: description += " across eligible targets"
	return "Can " + description


## Independent target-position oracle: use each source array, not the hint helper.
func _source_target_reach(entry: Dictionary) -> String:
	if entry["target_side"] == "self":
		return " · This doll only"
	var ranks: Array = entry["target"].duplicate()
	ranks.sort()
	var words: Array[String] = []
	var names := {1: "frontmost", 2: "second", 3: "third", 4: "rearmost"}
	for rank in ranks:
		words.append(names[rank])
	var description := ", ".join(words)
	if ranks == [1, 2]:
		description = "front pair"
	elif ranks == [2, 3, 4]:
		description = "back three"
	elif ranks == [1, 2, 3, 4]:
		description = "any rank"
	var subject := "foes" if entry["target_side"] == "enemy" else "allies"
	return " · May reach %s: %s" % [subject, description]


func _check_hints(picker: StitchedRunPartyPicker, originals: Dictionary, context: String, marked_id: String = "") -> void:
	if picker == null:
		_check(false, context + ": picker is present for hints")
		return
	var catalog := StitchedS14Abilities.kits()
	_check(not catalog.is_empty(), context + ": validated S14 catalog loads")
	var sides := {"enemy": "Foe", "ally": "Ally", "self": "Self"}
	var slots := ["head", "arms", "torso", "legs"]
	var receipt := StitchedPartyAdmission.admit(picker.selected_ids())
	var four_admitted: bool = receipt.get("ok") == true
	var admitted_ids: Array = receipt.get("hero_ids", [])
	if picker.selected_ids().size() == StitchedPartyAdmission.RANK_COUNT:
		_check(four_admitted and picker.displayed_rank_ids() == admitted_ids,
			context + ": displayed four ranks are the authenticated admission, not pick order")
	var launchable := 0
	var blocked := 0
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
			var line := "%s — %s · %s · %s%s" % [
				slot.capitalize(), str(entry.get("name", "")), sides[entry["target_side"]],
				_source_effect_phrase(entry), _source_target_reach(entry)]
			if four_admitted and id in admitted_ids:
				var rank: int = admitted_ids.find(id) + 1
				var can_launch: bool = rank in entry["launch"]
				line += (" · From this rank" if can_launch else " · Needs another rank") \
					+ " (launch only; target may be unavailable)"
				if can_launch:
					launchable += 1
				else:
					blocked += 1
			lines.append(line)
			var effect_phrase: String = _source_effect_phrase(entry)
			var no_amounts := true
			for digit in "0123456789":
				if effect_phrase.contains(digit):
					no_amounts = false
			_check(effect_phrase.begins_with("Can ") and no_amounts
				and not effect_phrase.to_lower().contains("patch")
				and not effect_phrase.to_lower().contains("socket")
				and (effect_phrase.contains("several eligible") == bool(entry["multi"])),
				context + ": " + id + "/" + slot + " shows only possible native effects, without amounts or patches")
		var expected_tooltip := "\n".join(lines)
		if id == marked_id:
			expected_tooltip += "\n" + WARN_SUFFIX
		_check(lines.size() == 4 and tile.tooltip_text == expected_tooltip
			and tile.tooltip_text.split("\n").size() == (5 if id == marked_id else 4),
			context + ": " + id + " matches four source-derived rank-only launch/target-caveat lines and warning suffix")
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
	_check((launchable + blocked == StitchedPartyAdmission.RANK_COUNT * StitchedParts.SLOTS.size()
		and launchable > 0) if four_admitted else (launchable == 0 and blocked == 0),
		context + ": all sixteen selected slot fits are checked (or none for incomplete picks)")
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
	_check(picker.tiles["warden"].tooltip_text.contains("Head — Pot Helm Command · Foe · Can mark")
		and picker.tiles["warden"].tooltip_text.contains("Arms — Shield Catch · Ally · Can guard")
		and picker.tiles["warden"].tooltip_text.contains("Torso — Iron Challenge · Foe · Can strike and weaken")
		and picker.tiles["warden"].tooltip_text.contains("Legs — Rim Toss · Foe · Can strike and push back"),
		context + ": Warden's mark, guard, weak, push are distinct")
	_check(picker.tiles["seamstress"].tooltip_text.contains("Head — Mending Knot · Ally · Can mend")
		and picker.tiles["seamstress"].tooltip_text.contains("Arms — Needle Prick · Foe · Can strike and bleed")
		and picker.tiles["seamstress"].tooltip_text.contains("Torso — Shielding Hem · Ally · Can guard")
		and picker.tiles["seamstress"].tooltip_text.contains("Legs — Tether Spools · Foe · Can tangle"),
		context + ": Seamstress's ally heal/guard and foe bleed/tangle are distinct")
	_check(picker.tiles["tinker"].tooltip_text.contains("Arms — Scrap Bomb · Foe · Can strike and expose several eligible foes")
		and picker.tiles["tinker"].tooltip_text.contains("Torso — Casing Ward · Self · Can return harm")
		and picker.tiles["tinker"].tooltip_text.contains("Legs — Tune Up · Ally · Can mend"),
		context + ": Tinker's multi-foe Exposed, self Thorns and ally Heal are distinct")
	_check(picker.tiles["lantern_monk"].tooltip_text.contains(
		"Torso — Lamplight Wash · Ally · Can mend several eligible allies"),
		context + ": Lantern Monk can mend several eligible allies, not everyone")
	_check(picker.tiles["rag_duelist"].tooltip_text.contains("Torso — Feint Stitch · Self · Can evade")
		and picker.tiles["button_golem"].tooltip_text.contains("Head — Button Brow · Foe · Can stun"),
		context + ": Rag Duelist's duration Dodge and Button Golem's foe Stun are native")
	if marked_id == "warden":
		_check(picker.tiles["warden"].tooltip_text.count("Needs another rank") == StitchedParts.SLOTS.size()
			and picker.tiles["warden"].tooltip_text.count(WARN_SUFFIX) == 1,
			context + ": rank-four Warden has four blocked signatures and one warning")


## Every fixed kit is validated and projected from its own source ranks.
## An injected valid override must never change the authoritative cache.
func _target_reach_fixtures() -> void:
	var catalog := StitchedS14Abilities.kits()
	var snapshot := catalog.duplicate(true)
	var sides := {"enemy": "Foe", "ally": "Ally", "self": "Self"}
	var checked_slots := 0
	_check(not catalog.is_empty() and catalog.size() == StitchedPartyAdmission.HERO_IDS.size(),
		"target reach begins with the full validated eight-doll S14 catalog")
	for id in StitchedPartyAdmission.HERO_IDS:
		var kit: Variant = catalog.get(id)
		if not kit is Dictionary:
			_check(false, "target reach has a complete source kit for " + id)
			continue
		var shown := StitchedPartyKitHints.tooltip(id, catalog)
		var lines := shown.split("\n")
		_check(lines.size() == StitchedParts.SLOTS.size(),
			"pure target reach shows four original signature lines for " + id)
		for index in StitchedParts.SLOTS.size():
			var slot: String = StitchedParts.SLOTS[index]
			var entry: Variant = kit.get(slot)
			if not entry is Dictionary:
				_check(false, "target reach source slot exists for " + id + "/" + slot)
				continue
			var raw: Dictionary = entry.duplicate(true)
			raw.erase("slot")
			var verified := StitchedParts.validate_ability(raw)
			_check(verified.get("ok") == true and sides.has(entry.get("target_side")),
				"target reach source is independently validated for " + id + "/" + slot)
			if verified.get("ok") != true or not sides.has(entry.get("target_side")):
				continue
			var normalized: Dictionary = verified["ability"]
			var expected := "%s — %s · %s · %s%s" % [
				slot.capitalize(), normalized["name"], sides[normalized["target_side"]],
				_source_effect_phrase(normalized), _source_target_reach(normalized)]
			_check(index < lines.size() and lines[index] == expected
				and (lines[index].contains(" · This doll only") if normalized["target_side"] == "self"
					else lines[index].contains(" · May reach "))
				and not lines[index].contains("From this rank"),
				"pure " + id + "/" + slot + " preserves identity, effect, side and validated possible target positions")
			checked_slots += 1
	_check(checked_slots == StitchedPartyAdmission.HERO_IDS.size() * StitchedParts.SLOTS.size(),
		"all eight shipped kits and their four fixed slots were independently checked")
	var witnesses := [
		["warden", "torso", "warden_torso_iron_challenge", "enemy", [1, 2], " · May reach foes: front pair"],
		["seamstress", "head", "seamstress_head_mending_knot", "ally", [1, 2, 3, 4], " · May reach allies: any rank"],
		["scarecrow", "legs", "scarecrow_legs_startle_step", "enemy", [2, 3, 4], " · May reach foes: back three"],
		["tinker", "torso", "tinker_torso_casing_ward", "self", [1, 2, 3, 4], " · This doll only"],
	]
	for witness in witnesses:
		var entry: Dictionary = catalog[witness[0]][witness[1]]
		var shown := StitchedPartyKitHints.tooltip(witness[0], catalog)
		var line: String = shown.split("\n")[StitchedParts.SLOTS.find(witness[1])]
		_check(entry["id"] == witness[2] and entry["target_side"] == witness[3]
			and entry["target"] == witness[4] and line.ends_with(witness[5]),
			"authored witness " + str(witness[2]) + " describes its exact possible target ranks")
	var altered := catalog.duplicate(true)
	altered["warden"]["head"]["target"] = [3, 1]
	var altered_line: String = StitchedPartyKitHints.tooltip("warden", altered).split("\n")[0]
	var original_line: String = StitchedPartyKitHints.tooltip("warden", catalog).split("\n")[0]
	_check(altered_line.ends_with(" · May reach foes: frontmost, third")
		and original_line.ends_with(" · May reach foes: frontmost, second, third")
		and altered_line != original_line and altered["warden"]["head"]["id"] == catalog["warden"]["head"]["id"],
		"valid nonconsecutive [1,3] override enumerates actual positions without changing move identity")
	_check(StitchedS14Abilities.kits() == snapshot and catalog == snapshot
		and StitchedPartyKitHints.tooltip("warden") == StitchedPartyKitHints.tooltip("warden", snapshot),
		"altered detached target source never edits the authentic S14 kit")


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
	for malformed in [[], [1, 1], [0], [4.25], ["2"]]:
		bad = source.duplicate(true)
		bad["warden"]["head"]["target"] = malformed
		_check(StitchedPartyKitHints.tooltip("warden", bad) == "",
			"malformed injected target mask " + str(malformed) + " cannot emit partial reach or move lines")
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
	for problem in ["unknown_effect", "noninteger_effect", "orphan_dodge", "invalid_multi"]:
		bad = source.duplicate(true)
		match problem:
			"unknown_effect": bad["warden"]["head"]["effects"]["unearned_heal"] = 5
			"noninteger_effect": bad["warden"]["head"]["effects"]["mark"] = "many"
			"orphan_dodge": bad["warden"]["head"]["effects"] = {"dodge": 10}
			"invalid_multi": bad["warden"]["head"]["multi"] = "true"
		_check(StitchedPartyKitHints.tooltip("warden", bad) == "",
			"invalid injected " + problem + " cannot leak a partial or invented signature")
	var altered := source.duplicate(true)
	altered["warden"]["head"]["dmg"] = [0, 1]
	altered["warden"]["head"]["effects"] = {"blind": 1}
	altered["warden"]["head"]["multi"] = true
	var altered_text := StitchedPartyKitHints.tooltip("warden", altered)
	_check(altered_text.split("\n").size() == StitchedParts.SLOTS.size()
		and altered_text.begins_with("Head — Pot Helm Command · Foe · Can strike and blind several eligible foes")
		and not altered_text.contains("Can mark")
		and StitchedPartyKitHints.tooltip("warden", source).contains("Can mark"),
		"a valid detached source derives damage, effect and multi without stale move-specific prose")
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


## Pure fit projection must agree with source launch arrays for all four admitted
## ranks, not with the tooltip formatter or the older stranded-only reduction.
func _fit_projection_fixtures() -> void:
	var catalog := StitchedS14Abilities.kits()
	var snapshot := catalog.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 124911
	var rng_state := rng.state
	var default_picks: Array = StitchedRunSession.DEFAULT_PICKS.duplicate()
	var mixed := ["rag_duelist", "scarecrow", "button_golem", "yarn_ranger"]
	var stranded := ["rag_duelist", "scarecrow", "button_golem", "warden"]
	for picks in [default_picks, mixed, stranded]:
		var receipt := StitchedPartyAdmission.admit(picks)
		var fit := StitchedPartyKitHints.opening_launch_fit(picks, catalog)
		var all_slots: bool = receipt.get("ok") == true and fit.size() == StitchedPartyAdmission.RANK_COUNT
		var launchable := 0
		var blocked := 0
		if all_slots:
			for index in receipt["hero_ids"].size():
				var id: String = receipt["hero_ids"][index]
				var entry: Dictionary = fit.get(id, {})
				var flags: Dictionary = entry.get("slots", {})
				all_slots = all_slots and entry.get("rank") == index + 1 \
					and flags.size() == StitchedParts.SLOTS.size()
				for slot in StitchedParts.SLOTS:
					var expected: bool = index + 1 in catalog[id][slot]["launch"]
					all_slots = all_slots and flags.get(slot) == expected
					if expected:
						launchable += 1
					else:
						blocked += 1
		_check(all_slots and launchable + blocked == 16
			and (blocked == 0 if picks == default_picks else blocked > 0)
			and (fit.get("warden", {}).get("slots", {}).values().count(false) == 4 if picks == stranded else true)
			and (launchable > 0),
			"pure per-slot opening projection equals direct S14 launch arrays for " + str(picks))
		_check(StitchedPartyKitHints.opening_launch_fit(picks) == fit,
			"source-injected and authoritative projections agree for " + str(picks))
	for bad_picks in [[], ["warden"], ["warden", "seamstress", "tinker", "warden"],
			["warden", "seamstress", "tinker", "bogus"],
			["warden", "seamstress", "tinker", "lantern_monk", "scarecrow"], "bad"]:
		_check(StitchedPartyKitHints.opening_launch_fit(bad_picks, catalog).is_empty(),
			"no pure fit claims for malformed, short, repeated, unknown or overfull picks")
	var invalid_catalogs: Array = [[], {}]
	for field in ["slot", "id", "name", "launch", "target_side", "target", "missing_slot", "missing_hero"]:
		var forged := catalog.duplicate(true)
		match field:
			"slot":
				forged["warden"]["arms"]["slot"] = "head"
			"id":
				forged["warden"]["arms"]["id"] = forged["warden"]["head"]["id"]
			"name":
				forged["warden"]["head"]["name"] = "A convincing forged name"
			"launch":
				forged["warden"]["head"]["launch"] = [4]
			"target_side":
				forged["warden"]["head"]["target_side"] = "neutral"
			"target":
				forged["warden"]["head"]["target"] = [4]
			"missing_slot":
				forged["warden"].erase("legs")
			"missing_hero":
				forged.erase("warden")
		invalid_catalogs.append(forged)
	for invalid in invalid_catalogs:
		_check(StitchedPartyKitHints.opening_launch_fit(stranded, invalid).is_empty(),
			"forged or incomplete signature source cannot project any rank-fit claims")
	_check(catalog == snapshot and StitchedS14Abilities.kits() == snapshot and rng.state == rng_state,
		"pure projection never mutates the injected catalog, authoritative cache or RNG")


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
	var mixed_counts := _source_opening_counts(safe, StitchedS14Abilities.kits())
	_check(mixed_counts.size() == 4 and mixed_counts.get("button_golem", -1) == 1
		and mixed_counts.get("rag_duelist", -1) > 0
		and mixed_counts.get("scarecrow", -1) > 0
		and mixed_counts.get("yarn_ranger", -1) > 0,
		"genuine safe replacement mixes Button Golem blocked/launchable slots without a stranded warning")
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
	originals["warden"].tooltip_text = "stale line after return to genuine epoch"
	picker.draft_changed.emit(witness)
	_check(actions[0].tooltip_text == warning
		and originals["warden"].tooltip_text.ends_with(WARN_SUFFIX),
		"accepted same-draft signal restores truthful warning and slot hints even when cue is unchanged")
	_check_hints(picker, originals, "re-authenticated same-cue refresh", "warden")
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


## Shoulder buttons traverse the real current GridContainer positions. Native
## joypad A must use the original Button toggled path, not a synthetic signal.
## Return a new title-mounted picker for all pre-existing regression scenarios.
func _exercise_shoulders(app: Node, picker: StitchedRunPartyPicker) -> StitchedRunPartyPicker:
	var originals: Dictionary = picker.tiles.duplicate()
	var actions: Array[Button] = app.stitched_run_buttons.duplicate()
	var action_children: int = actions[0].get_parent().get_child_count()
	var page_children: int = app.stitched_run_panel.get_child_count()
	var initial: Array = _visual_tile_ids(picker)
	var initial_picks: Array = picker.selected_ids()
	var receipts: Array = []
	picker.draft_changed.connect(func(picks: Array) -> void: receipts.append(picks.duplicate()))
	var wallet_before := [app.session_gold, app.run_scraps]
	seed(44319)
	var expected_global := randi()
	seed(44319)
	_check(initial.size() == 8 and picker.get_child_count() == 8
		and initial == StitchedPartyAdmission.HERO_IDS
		and actions.size() == 2 and actions[0].text == "Set out" and actions[1].text == "Cancel"
		and app.stitched_run_panel.get_meta("page_kind", "") == "picker",
		"controller witness starts on eight genuine original tiles and the real page actions")
	var native_accept := InputEventJoypadButton.new()
	native_accept.button_index = JOY_BUTTON_A
	native_accept.pressed = true
	var keyboard_accept := InputEventKey.new()
	keyboard_accept.keycode = KEY_ENTER
	keyboard_accept.pressed = true
	var space_accept := InputEventKey.new()
	space_accept.keycode = KEY_SPACE
	space_accept.pressed = true
	_check(InputMap.event_is_action(native_accept, "ui_accept")
		and InputMap.event_is_action(keyboard_accept, "ui_accept")
		and InputMap.event_is_action(space_accept, "ui_accept"),
		"the actual native ui_accept maps joypad A while retaining Enter and Space")
	# A non-press and repeated down do not produce extra movement.
	originals[initial[0]].grab_focus()
	await _joy_event(JOY_BUTTON_RIGHT_SHOULDER, false)
	_check(originals[initial[0]].has_focus(), "shoulder release without press never moves focus")
	await _joy_event(JOY_BUTTON_RIGHT_SHOULDER, true)
	_check(originals[initial[1]].has_focus(), "first right-shoulder down enters next pictured tile")
	await _joy_event(JOY_BUTTON_RIGHT_SHOULDER, true)
	_check(originals[initial[1]].has_focus(), "held/repeated right-shoulder down cannot move twice")
	await _joy_event(JOY_BUTTON_RIGHT_SHOULDER, false)
	for i in range(1, 8):
		await _shoulder(JOY_BUTTON_RIGHT_SHOULDER)
		_check(root.gui_get_focus_owner() == originals[initial[(i + 1) % 8]],
			"right-shoulder edge %d follows original row-major visual child and wraps" % (i + 1))
	for i in range(8):
		await _shoulder(JOY_BUTTON_LEFT_SHOULDER)
		_check(root.gui_get_focus_owner() == originals[initial[(7 - i + 8) % 8]],
			"left-shoulder edge %d follows original row-major visual child and wraps" % (i + 1))
	_check(receipts.is_empty() and picker.selected_ids() == initial_picks
		and app.stitched_run_draft == initial_picks and picker.tiles_match_draft(),
		"all sixteen shoulder edges and repeats move focus only, with no draft receipt")
	# Both existing page actions are valid entry points but must never activate.
	actions[0].grab_focus()
	await _shoulder(JOY_BUTTON_RIGHT_SHOULDER)
	_check(originals[initial[0]].has_focus() and app.stitched_run_session == null,
		"right shoulder from focused original Set out enters first tile without starting")
	actions[1].grab_focus()
	await _shoulder(JOY_BUTTON_LEFT_SHOULDER)
	_check(originals[initial[7]].has_focus() and app.stitched_run_panel.is_visible_in_tree(),
		"left shoulder from focused original Cancel enters last tile without cancelling")
	# Focus in the page but not an authenticated tile/action must be ignored.
	var heading := app.stitched_run_panel.find_child("StitchedPageHeading", true, false) as Label
	if heading != null:
		var old_mode := heading.focus_mode
		heading.focus_mode = Control.FOCUS_ALL
		heading.grab_focus()
		_check(heading.has_focus(), "negative shoulder witness genuinely focuses the existing heading")
		await _shoulder(JOY_BUTTON_RIGHT_SHOULDER)
		_check(heading.has_focus() and receipts.is_empty(),
			"shoulder ignores a different real page control, not just null focus")
		heading.focus_mode = old_mode
	root.gui_release_focus()
	_check(root.gui_get_focus_owner() == null, "controller null-focus witness is genuine")
	await _shoulder(JOY_BUTTON_LEFT_SHOULDER)
	_check(root.gui_get_focus_owner() == null, "shoulder cannot invent focus from nowhere")
	originals[initial[0]].grab_focus()
	var epoch: int = app._stitched_run_epoch
	app._stitched_run_epoch += 1
	await _shoulder(JOY_BUTTON_RIGHT_SHOULDER)
	_check(originals[initial[0]].has_focus() and receipts.is_empty(),
		"stale picker epoch refuses shoulder navigation")
	app._stitched_run_epoch = epoch
	app.stitched_run_panel.set_meta("page_kind", "other")
	await _shoulder(JOY_BUTTON_LEFT_SHOULDER)
	_check(originals[initial[0]].has_focus() and receipts.is_empty(),
		"non-picker page kind refuses shoulder navigation")
	app.stitched_run_panel.set_meta("page_kind", "picker")
	picker.hide()
	for id in StitchedPartyAdmission.HERO_IDS:
		_check(originals[id].tooltip_text == StitchedPartyKitHints.tooltip(id),
			"hidden original tile loses transient rank-fit lines: " + id)
	await _shoulder(JOY_BUTTON_RIGHT_SHOULDER)
	_check(receipts.is_empty() and picker.selected_ids() == initial_picks,
		"hidden picker never changes its draft from shoulders")
	picker.show()
	await process_frame
	picker.update_opening_rank_cues(initial_picks)
	_check_hints(picker, originals, "visible authenticated draft rebuilds rank hints")
	originals["warden"].grab_focus()
	# South/A is the native ui_accept event on the currently focused tile.
	await _pad_accept()
	var incomplete := ["seamstress", "tinker", "lantern_monk"]
	_check(picker.selected_ids() == incomplete and app.stitched_run_draft == incomplete
		and not originals["warden"].button_pressed and receipts == [incomplete]
		and actions[0].disabled and actions[0].focus_mode == Control.FOCUS_NONE,
		"native joypad Accept unchecks the focused Warden with exactly one authentic draft_changed")
	_check_order(picker, incomplete,
		["warden", "rag_duelist", "scarecrow", "yarn_ranger", "button_golem"],
		"shoulder incomplete draft visual order")
	_check_hints(picker, originals, "controller deselect clears all fit claims")
	originals["warden"].grab_focus()
	var incomplete_order: Array = _visual_tile_ids(picker)
	for i in range(8):
		await _shoulder(JOY_BUTTON_RIGHT_SHOULDER)
		var source: int = incomplete_order.find("warden")
		_check(root.gui_get_focus_owner() == originals[incomplete_order[(source + i + 1) % 8]],
			"incomplete reflow shoulder edge %d follows latest real child position" % (i + 1))
	originals["rag_duelist"].grab_focus()
	await _pad_accept()
	var four := ["seamstress", "tinker", "lantern_monk", "rag_duelist"]
	var admission := StitchedPartyAdmission.admit(four)
	_check(admission.get("ok") == true and admission.get("hero_ids", []) != four
		and picker.selected_ids() == four and app.stitched_run_draft == four
		and originals["rag_duelist"].button_pressed and receipts == [incomplete, four]
		and not actions[0].disabled and picker.tiles_match_draft(),
		"second native joypad Accept checks original Rag tile once and restores four admitted picks")
	_check_order(picker, admission.get("hero_ids", []),
		["warden", "scarecrow", "yarn_ranger", "button_golem"],
		"shoulder four-doll canonical reflow")
	_check_hints(picker, originals, "controller fourth choice restores admitted slot launch fits")
	var canonical_order: Array = _visual_tile_ids(picker)
	originals[canonical_order[0]].grab_focus()
	for i in range(8):
		await _shoulder(JOY_BUTTON_LEFT_SHOULDER)
		_check(root.gui_get_focus_owner() == originals[canonical_order[(7 - i + 8) % 8]],
			"canonical reflow left-shoulder edge %d follows pictured order" % (i + 1))
	for i in range(8):
		await _shoulder(JOY_BUTTON_RIGHT_SHOULDER)
		_check(root.gui_get_focus_owner() == originals[canonical_order[(i + 1) % 8]],
			"canonical reflow right-shoulder edge %d follows pictured order" % (i + 1))
	originals["scarecrow"].grab_focus()
	await _pad_accept()
	_check(not originals["scarecrow"].button_pressed and picker.selected_ids() == four
		and app.stitched_run_draft == four and receipts == [incomplete, four]
		and picker.displayed_rank_ids() == admission.get("hero_ids", []),
		"native joypad Accept on fifth doll cannot evict a chosen quartet or emit a draft")
	for id in StitchedPartyAdmission.HERO_IDS:
		_check(picker.tiles[id] == originals[id] and originals[id].get_parent() == picker
			and originals[id].get_child_count() == 2
			and originals[id].get_node("Portrait").get_meta("art_path")
				== "res://assets/paper/heroes/" + id + ".png"
			and originals[id].get_node("DollName") is Label,
			"controller retains original portrait/name Button and art path for " + id)
	_check(picker.get_child_count() == 8 and actions[0].get_parent().get_child_count() == action_children
		and app.stitched_run_panel.get_child_count() == page_children
		and app.stitched_run_buttons == actions
		and app.stitched_run_session == null and app.run_rng == null and app.run_map == null
		and app.deck == null and app.run_deck.is_empty()
		and [app.session_gold, app.run_scraps] == wallet_before
		and not FileAccess.file_exists(SAVE) and randi() == expected_global,
		"all focus browsing and native selection remain child, save, wallet and RNG neutral")
	# The same original Set out Button must admit the canonical rank order.
	await _mouse(actions[0])
	var session: StitchedRunSession = app.stitched_run_session
	var expected := StitchedRunSession.start(7311, four)
	var actual_ranks: Array = []
	if session != null:
		for hero in session.heroes:
			actual_ranks.append(hero.id)
	_check(session != null and expected != null and session.is_consistent()
		and session.picks == four and actual_ranks == admission.get("hero_ids", [])
		and session.snapshot() == expected.snapshot() and app.stitched_run_intro != null,
		"original Set out starts identical seeded session from controller-chosen canonical ranks")
	app._return_stitched_run_title()
	await _shoulder(JOY_BUTTON_RIGHT_SHOULDER)
	await process_frame
	_check(app.title_view.is_visible_in_tree() and app.stitched_run_panel == null
		and app.stitched_run_session == null and app.stitched_run_draft.is_empty()
		and app.start_button.has_focus(),
		"removed/retired picker cannot capture a shoulder or reactivate a run")
	await _shoulder(JOY_BUTTON_LEFT_SHOULDER)
	_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus()
		and app.stitched_run_panel == null and not FileAccess.file_exists(SAVE),
		"title shoulder input never reopens the picker or changes save")
	await _mouse(app.start_button)
	var fresh := _picker(app)
	_check(fresh != null and fresh != picker
		and fresh.selected_ids() == StitchedRunSession.DEFAULT_PICKS,
		"controller exercise returns fresh authored defaults for existing regressions")
	return fresh


## Exercise physical top-row digits on the actual title-mounted picker. A fresh
## picker is returned so the existing pointer, focus, Warden and replay tests
## still drive their original production route and controls.
func _exercise_number_shortcuts(app: Node, picker: StitchedRunPartyPicker) -> StitchedRunPartyPicker:
	var actions: Array[Button] = app.stitched_run_buttons.duplicate()
	var originals: Dictionary = picker.tiles.duplicate()
	var heading := app.stitched_run_panel.find_child("StitchedPageHeading", true, false) as Label
	_check(heading != null and heading.tooltip_text == "Keys 1–8: choose dolls · Esc/B: cancel"
		and actions.size() == 2 and actions[0].text == "Set out" and actions[1].text == "Cancel",
		"original heading offers both shortcuts in its native tooltip without a new control")
	var receipts: Array = []
	picker.draft_changed.connect(func(picks: Array) -> void: receipts.append(picks.duplicate()))
	var wallet_before := [app.session_gold, app.run_scraps]
	var default_picks: Array = StitchedRunSession.DEFAULT_PICKS.duplicate()
	seed(33081)
	var expected_global := randi()
	seed(33081)
	# No false key-up, repeat, modified, keypad or unrelated-key toggles.
	await _key_event(KEY_1, false)
	await _key_event(KEY_1, true, true)
	for modifier in ["ctrl", "alt", "shift", "meta"]:
		await _key_event(KEY_1, true, false, modifier)
	await _key_event(KEY_KP_1, true)
	await _key_event(KEY_9, true)
	await _key_event(KEY_F8, true)
	await _key(KEY_LEFT)
	_check(picker.selected_ids() == default_picks and app.stitched_run_draft == default_picks
		and picker.tiles_match_draft() and receipts.is_empty()
		and originals["warden"].button_pressed,
		"releases, echo, four modifiers, keypad, out-of-range and navigation keys do not toggle dolls")
	root.gui_release_focus()
	_check(root.gui_get_focus_owner() == null,
		"negative focus witness genuinely relinquishes current UI focus")
	await _key(KEY_1)
	_check(picker.selected_ids() == default_picks and app.stitched_run_draft == default_picks
		and receipts.is_empty(), "unfocused picker does not capture a digit")
	actions[0].grab_focus()
	await _key(KEY_5)
	_check(not originals["rag_duelist"].button_pressed and picker.selected_ids() == default_picks
		and app.stitched_run_draft == default_picks and receipts.is_empty(),
		"KEY_5 is refused as a genuine fifth Button toggle, without a draft receipt")
	var codes := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8]
	var draft: Array = default_picks.duplicate()
	for i in range(4):
		var id: String = StitchedPartyAdmission.HERO_IDS[i]
		var prior: int = receipts.size()
		await _key(codes[i])
		draft.erase(id)
		_check(not originals[id].button_pressed and picker.selected_ids() == draft
			and app.stitched_run_draft == draft and picker.tiles_match_draft()
			and receipts.size() == prior + 1 and receipts.back() == draft,
			"unmodified top-row KEY_%d unchecks its original Button and emits the one authentic draft" % (i + 1))
		if i == 0:
			_check(root.gui_get_focus_owner() != null
				and picker.is_ancestor_of(root.gui_get_focus_owner()),
				"disabling focused Set out via a digit leaves focus on a live original tile")
	_check(draft.is_empty() and actions[0].disabled
		and actions[0].focus_mode == Control.FOCUS_NONE,
		"four distinct digit deselections leave no picks and disable Set out")
	var back_four: Array = []
	for i in range(4, 8):
		var id: String = StitchedPartyAdmission.HERO_IDS[i]
		var prior: int = receipts.size()
		await _key(codes[i])
		back_four.append(id)
		_check(originals[id].button_pressed and picker.selected_ids() == back_four
			and app.stitched_run_draft == back_four and picker.tiles_match_draft()
			and receipts.size() == prior + 1 and receipts.back() == back_four,
			"unmodified top-row KEY_%d checks its original Button through draft_changed" % (i + 1))
	var back_receipt := StitchedPartyAdmission.admit(back_four)
	_check(back_receipt.get("ok") == true and picker.displayed_rank_ids() == back_receipt.hero_ids
		and not actions[0].disabled and picker.tiles_match_draft(),
		"keyboard-only back-four admission enables the unchanged Set out control")
	await _key(KEY_1)
	_check(picker.selected_ids() == back_four and app.stitched_run_draft == back_four
		and not originals["warden"].button_pressed and receipts.size() == 8,
		"another full-quartet fifth digit cannot evict the selected dolls")
	for i in range(7, 3, -1):
		await _key(codes[i])
	_check(picker.selected_ids().is_empty() and actions[0].disabled,
		"all four selected back-row digits toggle their own originals off")
	# This draft's admitted visible rank order differs from its keyboard input order.
	var witness := ["seamstress", "tinker", "lantern_monk", "rag_duelist"]
	for code in [KEY_2, KEY_3, KEY_4]:
		await _key(code)
	originals["tinker"].grab_focus()
	await _key(KEY_5)
	var admitted := StitchedPartyAdmission.admit(witness)
	_check(admitted.get("ok") == true and admitted.get("hero_ids", []) != witness
		and picker.selected_ids() == witness and app.stitched_run_draft == witness
		and picker.displayed_rank_ids() == admitted.hero_ids and picker.tiles_match_draft()
		and not actions[0].disabled and actions[0].focus_mode == Control.FOCUS_ALL
		and receipts.size() == 16 and receipts.back() == witness,
		"four distinct keys produce a valid authentic draft and canonical, non-click-order ranks")
	_check(originals["tinker"].has_focus(),
		"deferred keyboard reflow restores focused original Tinker tile")
	_check_order(picker, admitted.hero_ids,
		["warden", "scarecrow", "yarn_ranger", "button_golem"],
		"keyboard-only four-key witness selected-first order")
	for id in StitchedPartyAdmission.HERO_IDS:
		_check(picker.tiles[id] == originals[id] and originals[id].get_parent() == picker
			and originals[id].get_node("Portrait") is TextureRect
			and originals[id].get_node("DollName") is Label,
			"KEY_1–KEY_8 retain the eight original portrait/name Buttons for " + id)
	_check_hints(picker, originals, "after eight physical number keys")
	var unchanged_receipts: int = receipts.size()
	picker.draft_changed.emit(["warden", "warden", "tinker", "lantern_monk"])
	_check(app.stitched_run_draft == witness and picker.selected_ids() == witness
		and receipts.size() == unchanged_receipts + 1,
		"fabricated draft_changed does not override authenticated keyboard draft")
	var epoch: int = app._stitched_run_epoch
	app._stitched_run_epoch += 1
	await _key(KEY_2)
	_check(picker.selected_ids() == witness and app.stitched_run_draft == witness
		and originals["seamstress"].button_pressed and receipts.size() == unchanged_receipts + 1,
		"stale picker epoch refuses even a physical selected-digit key press")
	app._stitched_run_epoch = epoch
	_check(app.stitched_run_session == null and app.run_rng == null and app.run_map == null
		and app.deck == null and app.run_deck.is_empty() and not FileAccess.file_exists(SAVE)
		and [app.session_gold, app.run_scraps] == wallet_before and randi() == expected_global,
		"negative shortcuts, full cap and real toggles allocate no run, save, cards, RNG or wallet")
	await _mouse(actions[0])
	var session: StitchedRunSession = app.stitched_run_session
	var expected := StitchedRunSession.start(7311, witness)
	var seeded_ids: Array = []
	if session != null:
		for hero in session.heroes:
			seeded_ids.append(hero.id)
	_check(session != null and expected != null and session.is_consistent()
		and session.picks == witness and seeded_ids == admitted.get("hero_ids", [])
		and session.snapshot() == expected.snapshot() and app.stitched_run_intro != null
		and app.run_rng == null and app.deck == null,
		"original Set out launches seeded canonical four-rank session from keyboard-only witness")
	app._return_stitched_run_title()
	await process_frame
	_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus()
		and app.stitched_run_session == null, "keyboard-started run cleans up to focused title")
	await _key(KEY_1)
	_check(app.stitched_run_panel == null and app.stitched_run_draft.is_empty(),
		"digits at the title without the picker never reopen or mutate the draft")
	await _mouse(app.start_button)
	var fresh := _picker(app)
	_check(fresh != null and fresh != picker and fresh.selected_ids() == default_picks,
		"new title picker restores all four authored defaults after keyboard-started run")
	return fresh


## Physical Escape and controller B must cancel exactly like the mounted
## Cancel Button: through its own guarded pressed path, only from the live,
## focused picker page. Returns a fresh default title picker for the rest.
func _exercise_back_shortcuts(app: Node, picker: StitchedRunPartyPicker) -> StitchedRunPartyPicker:
	var actions: Array[Button] = app.stitched_run_buttons.duplicate()
	var wallet_before := [app.session_gold, app.run_scraps]
	seed(60517)
	var expected_global := randi()
	seed(60517)
	var escape_press := InputEventKey.new()
	escape_press.keycode = KEY_ESCAPE
	escape_press.physical_keycode = KEY_ESCAPE
	escape_press.pressed = true
	var pad_b := InputEventJoypadButton.new()
	pad_b.device = 0
	pad_b.button_index = JOY_BUTTON_B
	pad_b.pressed = true
	_check(InputMap.event_is_action(escape_press, "ui_cancel")
		and InputMap.event_is_action(pad_b, "ui_cancel"),
		"the real physical Escape key and controller B are the native ui_cancel inputs")
	_check(actions.size() == 2 and actions[0].text == "Set out" and actions[1].text == "Cancel",
		"back-shortcut witness starts from the original [Set out, Cancel] actions")
	# Released, echoed and repeated back input never cancels.
	picker.tiles["warden"].grab_focus()
	await _key_event(KEY_ESCAPE, false)
	await _joy_event(JOY_BUTTON_B, false)
	await _key_event(KEY_ESCAPE, true, true)
	_check(picker.is_visible_in_tree() and app.stitched_run_panel != null
		and app.stitched_run_session == null
		and app.stitched_run_draft == StitchedRunSession.DEFAULT_PICKS
		and picker.tiles["warden"].has_focus(),
		"released and echoed Escape/B input never cancels the live picker")
	# A chorded Escape is a different player input, never a picker Cancel: all
	# four modifier chords must leave the focused tile, draft and mounted page.
	for modifier in ["ctrl", "alt", "shift", "meta"]:
		await _key_event(KEY_ESCAPE, true, false, modifier)
		await _key_event(KEY_ESCAPE, false, false, modifier)
	_check(picker.is_visible_in_tree() and app.stitched_run_panel != null
		and app.stitched_run_panel.get_meta("page_kind", "") == "picker"
		and app.stitched_run_session == null and app.run_rng == null
		and app.stitched_run_draft == StitchedRunSession.DEFAULT_PICKS
		and picker.selected_ids() == StitchedRunSession.DEFAULT_PICKS
		and picker.tiles_match_draft() and picker.tiles["warden"].has_focus(),
		"all four modified Escapes keep the mounted picker, focused tile and draft")
	actions[1].grab_focus()
	for modifier in ["ctrl", "alt", "shift", "meta"]:
		await _key_event(KEY_ESCAPE, true, false, modifier)
		await _key_event(KEY_ESCAPE, false, false, modifier)
	_check(picker.is_visible_in_tree() and app.stitched_run_panel != null
		and app.stitched_run_panel.get_meta("page_kind", "") == "picker"
		and app.stitched_run_session == null and app.run_rng == null
		and app.stitched_run_draft == StitchedRunSession.DEFAULT_PICKS
		and actions[1].has_focus(),
		"all four modified Escapes keep the focused Cancel action and mounted picker")
	# Without live page focus the back inputs belong to no picker.
	root.gui_release_focus()
	_check(root.gui_get_focus_owner() == null,
		"back-shortcut negative focus witness genuinely relinquishes focus")
	await _key(KEY_ESCAPE)
	await _joy_event(JOY_BUTTON_B, true)
	await _joy_event(JOY_BUTTON_B, false)
	_check(picker.is_visible_in_tree() and app.stitched_run_panel != null,
		"an unfocused live picker ignores both physical back inputs")
	# A stale picker epoch must never cancel a newer page's state.
	picker.tiles["seamstress"].grab_focus()
	var epoch: int = app._stitched_run_epoch
	app._stitched_run_epoch += 1
	await _key(KEY_ESCAPE)
	await _joy_event(JOY_BUTTON_B, true)
	await _joy_event(JOY_BUTTON_B, false)
	_check(picker.is_visible_in_tree() and app.stitched_run_panel != null
		and app.stitched_run_session == null,
		"stale picker epoch refuses both physical back inputs")
	app._stitched_run_epoch = epoch
	app.stitched_run_panel.set_meta("page_kind", "other")
	await _key(KEY_ESCAPE)
	_check(picker.is_visible_in_tree() and app.stitched_run_panel != null,
		"a non-picker page kind ignores the physical back shortcut")
	app.stitched_run_panel.set_meta("page_kind", "picker")
	picker.hide()
	await _key(KEY_ESCAPE)
	await _joy_event(JOY_BUTTON_B, true)
	await _joy_event(JOY_BUTTON_B, false)
	_check(not picker.is_visible_in_tree() and app.stitched_run_panel != null,
		"a hidden picker ignores both physical back inputs")
	picker.show()
	await process_frame
	picker.update_opening_rank_cues(StitchedRunSession.DEFAULT_PICKS)
	_check(picker.selected_ids() == StitchedRunSession.DEFAULT_PICKS
		and picker.tiles_match_draft()
		and app.stitched_run_draft == StitchedRunSession.DEFAULT_PICKS,
		"every refused back input leaves the authored default draft untouched")
	# Physical Escape cancels a complete default title draft through Cancel.
	picker.tiles["warden"].grab_focus()
	await _key(KEY_ESCAPE)
	_check(app.title_view.is_visible_in_tree() and app.stitched_run_panel == null
		and app.stitched_run_session == null and app.stitched_run_intro == null
		and app.run_rng == null and app.run_map == null and app.deck == null
		and app.run_deck.is_empty() and app.stitched_run_draft.is_empty()
		and not FileAccess.file_exists(SAVE) and app.start_button.has_focus()
		and [app.session_gold, app.run_scraps] == wallet_before,
		"physical Escape cancels the complete default title picker to the focused title")
	# Controller B cancels the same way after a genuinely incomplete draft.
	await _mouse(app.start_button)
	var incomplete := _picker(app)
	if incomplete == null:
		return null
	await _key(KEY_1)
	_check(incomplete.selected_ids().size() == StitchedPartyAdmission.RANK_COUNT - 1
		and app.stitched_run_buttons.size() == 2 and app.stitched_run_buttons[0].disabled,
		"one real digit leaves a genuinely incomplete three-doll draft")
	await _joy_event(JOY_BUTTON_B, true)
	await _joy_event(JOY_BUTTON_B, false)
	_check(app.title_view.is_visible_in_tree() and app.stitched_run_panel == null
		and app.stitched_run_session == null and app.stitched_run_intro == null
		and app.run_rng == null and app.stitched_run_draft.is_empty()
		and not FileAccess.file_exists(SAVE) and app.start_button.has_focus()
		and [app.session_gold, app.run_scraps] == wallet_before,
		"controller B cancels the incomplete title draft to the focused title")
	# The live S9c intro ignores both picker back shortcuts.
	await _mouse(app.start_button)
	var intro_picker := _picker(app)
	if intro_picker == null:
		return null
	await _mouse(app.stitched_run_buttons[0])
	_check(app.stitched_run_session != null and app.stitched_run_intro != null
		and not app.title_view.is_visible_in_tree(),
		"seeded Set out opens the genuine Wren intro over the first map page")
	await _key(KEY_ESCAPE)
	await _joy_event(JOY_BUTTON_B, true)
	await _joy_event(JOY_BUTTON_B, false)
	_check(app.stitched_run_session != null and app.stitched_run_intro != null
		and app.stitched_run_panel != null,
		"the live intro ignores both picker back shortcuts and keeps the night")
	app._return_stitched_run_title()
	await process_frame
	_check(app.title_view.is_visible_in_tree() and app.stitched_run_session == null
		and app.start_button.has_focus(),
		"returning from the intro witness restores the focused title")
	await _mouse(app.start_button)
	var fresh := _picker(app)
	_check(fresh != null and fresh != picker
		and fresh.selected_ids() == StitchedRunSession.DEFAULT_PICKS
		and app.stitched_run_buttons[0].tooltip_text == "",
		"back-shortcut exercise returns fresh authored defaults for existing regressions")
	_check(randi() == expected_global and [app.session_gold, app.run_scraps] == wallet_before
		and not FileAccess.file_exists(SAVE),
		"every accepted and refused back input stays session, save, wallet and RNG neutral")
	return fresh


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_advisory_fixtures()
	_fit_projection_fixtures()
	_target_reach_fixtures()
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
	picker = await _exercise_shoulders(app, picker)
	if picker == null:
		app.free()
		_finish()
		return
	_default(picker, app)
	picker = await _exercise_number_shortcuts(app, picker)
	if picker == null:
		app.free()
		_finish()
		return
	_default(picker, app)
	picker = await _exercise_opening_warning(app, picker)
	if picker == null:
		app.free()
		_finish()
		return
	_default(picker, app)
	picker = await _exercise_back_shortcuts(app, picker)
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
	picker.update_opening_rank_cues(expected_picks)
	for id in StitchedPartyAdmission.HERO_IDS:
		_check(original_tiles[id].tooltip_text == StitchedPartyKitHints.tooltip(id),
			"unsolicited grid reorder cannot retain or attach rank-fit claims: " + id)
	picker.move_child(picker.tiles["rag_duelist"], 0)
	_check_order(picker, expected_ranks,
		["warden", "scarecrow", "yarn_ranger", "button_golem"],
		"restoring the genuine rank display re-enables authentic admission")
	picker.update_opening_rank_cues(expected_picks)
	_check_hints(picker, original_tiles, "restored authenticated rank order and fit annotations")
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
	_check(not picker.is_inside_tree() and app.stitched_run_panel == null
		and app.stitched_run_session == null and app.title_view.is_visible_in_tree(),
		"Cancel detaches the old picker and stale Set out fails while queued for free")
	await _key(KEY_1)
	_check(app.stitched_run_draft.is_empty() and app.stitched_run_session == null
		and app.run_rng == null and app.stitched_run_panel == null,
		"late KEY_1 after cancelling the old picker cannot touch the App draft")
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
		var bedroom_originals: Dictionary = picker.tiles.duplicate()
		var bedroom_receipts: Array = []
		picker.draft_changed.connect(func(picks: Array) -> void: bedroom_receipts.append(picks.duplicate()))
		for code in [KEY_1, KEY_2, KEY_3, KEY_4]:
			await _key(code)
		for code in [KEY_5, KEY_6, KEY_7, KEY_8]:
			await _key(code)
		var bedroom_picks := ["rag_duelist", "scarecrow", "yarn_ranger", "button_golem"]
		var bedroom_admission := StitchedPartyAdmission.admit(bedroom_picks)
		_check(bedroom_admission.get("ok") == true and bedroom_receipts.size() == 8
			and bedroom_receipts.back() == bedroom_picks
			and picker.selected_ids() == bedroom_picks and app.stitched_run_draft == bedroom_picks
			and picker.tiles_match_draft() and picker.displayed_rank_ids() == bedroom_admission.hero_ids
			and not app.stitched_run_buttons[0].disabled,
			"live Wren-room picker takes all eight genuine number keys via authentic App drafts")
		for id in StitchedPartyAdmission.HERO_IDS:
			_check(picker.tiles[id] == bedroom_originals[id]
				and bedroom_originals[id].button_pressed == (id in bedroom_picks),
				"Wren shortcut retains and updates the original " + id + " Button")
		_check_order(picker, bedroom_admission.hero_ids,
			["warden", "seamstress", "tinker", "lantern_monk"],
			"Wren-room number-key selected-first layout")
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
		# Physical Escape and controller B must return to this browsable bedroom too.
		await _mouse(village.set_out_button)
		picker = _picker(app)
		_default(picker, app)
		await _key(KEY_1)
		_check(picker != null and app.stitched_run_buttons.size() == 2
			and picker.selected_ids().size() == StitchedPartyAdmission.RANK_COUNT - 1
			and app.stitched_run_buttons[0].disabled,
			"bedroom witness holds a genuinely incomplete draft before physical back input")
		await _key(KEY_ESCAPE)
		_check(village.is_visible_in_tree() and village.has_open_village()
			and village.set_out_button.has_focus() and app.stitched_run_panel == null
			and app.stitched_run_session == null and app.run_rng == null and app.deck == null
			and app.stitched_run_draft.is_empty() and not FileAccess.file_exists(SAVE)
			and [app.session_gold, app.run_scraps] == wallet_before,
			"bedroom Escape returns the browsable bedroom and focused Set out after an incomplete draft")
		await _mouse(village.set_out_button)
		picker = _picker(app)
		_default(picker, app)
		await _joy_event(JOY_BUTTON_B, true)
		await _joy_event(JOY_BUTTON_B, false)
		_check(village.is_visible_in_tree() and village.has_open_village()
			and village.set_out_button.has_focus() and app.stitched_run_panel == null
			and app.stitched_run_session == null and app.stitched_run_draft.is_empty()
			and not FileAccess.file_exists(SAVE)
			and [app.session_gold, app.run_scraps] == wallet_before,
			"bedroom controller B returns the browsable bedroom and focus from a complete draft")
		await _joy_event(JOY_BUTTON_B, true)
		await _joy_event(JOY_BUTTON_B, false)
		_check(village.is_visible_in_tree() and village.has_open_village()
			and village.set_out_button.has_focus() and app.stitched_run_panel == null
			and app.stitched_run_session == null,
			"a retired bedroom picker never captures stray later back input")
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
