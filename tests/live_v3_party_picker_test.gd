extends SceneTree
## Real mounted Design-v3 chooser: actions are requests, never run admission.
const SCENE := "res://scenes/v3_party_picker.tscn"
const ORDER: Array[String] = [
	"warden", "seamstress", "tinker", "lantern_monk",
	"rag_duelist", "scarecrow", "yarn_ranger", "button_golem"]
const NAMES: Array[String] = [
	"Warden", "Seamstress", "Tinker", "Lantern Monk",
	"Rag Duelist", "Scarecrow", "Yarn Ranger", "Button Golem"]
const MOTIFS: Array[String] = [
	"HELMET", "NEEDLE", "GOGGLES", "LANTERN",
	"RAPIER", "FORK", "HOOD", "BUTTONS"]
const SIGNATURES: Array[String] = [
	"Guard", "Tether", "Overload", "Moth Cloud",
	"Riposte", "Crow Peck", "Tangled", "Pop Button"]
const ROLES: Array[String] = [
	"Bulwark", "Stitch healer", "Scrap engineer", "Light keeper",
	"Counterattacker", "Fear harrier", "Tangle hunter", "Block bruiser"]
## Independent Starting heroes oracle: exact GAME_DESIGN.md authored wording.
const LEGACY_PASSIVES := {
	"warden": "Start of combat: gain 6 Block.",
	"seamstress": "When she applies Bleed, apply 1 more.",
	"tinker": "Her first attack each turn deals +3.",
}
const LEGACY_HP := {"warden": 40, "seamstress": 30, "tinker": 26}
const POSITION_NAMES := ["Front", "Middle", "Back"]

var failures: Array[String] = []
var checks := 0
var requests: Array = []
var cancels := 0
var canonical_roster: Array = []
var canonical_legacy: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _tile(picker: Control, hero_id: String) -> Button:
	return picker.get_node_or_null("PaperPanel/Margins/Body/HeroGrid/Hero_" + hero_id) as Button


func _mouse(button: Button) -> void:
	_check(button != null and button.is_visible_in_tree(), "real visible mouse target")
	if button == null or not button.is_visible_in_tree():
		return
	var p := button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = p
	root.push_input(move, true)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = p
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		root.push_input(e, true)
	await _frames()


func _move_to(target: Control) -> void:
	_check(target != null and target.is_visible_in_tree(), "real pointer motion target")
	if target == null or not target.is_visible_in_tree():
		return
	var move := InputEventMouseMotion.new()
	move.position = target.get_global_rect().get_center()
	root.push_input(move, true)
	await _frames()


func _readout(picker: Control) -> Array[String]:
	var base := "PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/"
	var heading: Label = picker.get_node(base + "InspectionHeading")
	var facts: Label = picker.get_node(base + "InspectionFacts")
	var detail: Label = picker.get_node(base + "InspectionDetail")
	return [heading.text, detail.text, facts.text]


func _read_hero_records(path: String) -> Array:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Array:
		return []
	return parser.data


func _canonical_facts(hero_id: String) -> Dictionary:
	for index in range(canonical_legacy.size()):
		var record: Dictionary = canonical_legacy[index]
		if record.get("id") == hero_id:
			return {"hp": record.get("max_hp"), "position": index + 1,
				"passive": LEGACY_PASSIVES.get(hero_id, "")}
	for record in canonical_roster:
		if record.get("id") == hero_id:
			return {"hp": record.get("max_hp"),
				"position": record.get("default_position"),
				"passive": record.get("passive", {}).get("text", "")}
	return {}


func _check_canonical_inspection(picker: LiveV3PartyPicker, hero_id: String, note: String) -> void:
	var expected := _canonical_facts(hero_id)
	_check(not expected.is_empty() and expected.get("passive", "") != "",
		note + " independent authentic hero record found")
	if expected.is_empty():
		return
	var position: int = int(expected["position"])
	_check(position in [1, 2, 3], note + " canonical preferred position valid")
	if position not in [1, 2, 3]:
		return
	var rendered := _readout(picker)[2]
	_check(rendered == "Max HP: %d  •  Preferred: %s (%d)  •  Passive: %s" % [
		expected["hp"], POSITION_NAMES[position - 1], position, expected["passive"]],
		note + " exact canonical HP / preferred position / passive")
	var facts: Label = picker.get_node(
		"PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/InspectionFacts")
	var text_width := facts.get_theme_font("font").get_string_size(
		facts.text, HORIZONTAL_ALIGNMENT_LEFT, -1, facts.get_theme_font_size("font_size")).x
	_check(text_width <= facts.size.x + 1.0, note + " all authored passive text fits at 1280x720")
	_check(picker.selected_ids().is_empty(), note + " inspection is read-only")


func _check_seats(picker: LiveV3PartyPicker, picks: Array[String], note: String) -> void:
	var hint: Label = picker.get_node("PaperPanel/Margins/Body/Foot/Hint")
	var admitted := RunV3PartyAdmission.admit(picks)
	_check(admitted.get("ok", false) and admitted.get("party", []).size() == 3,
		note + " authentic admission result")
	if not admitted.get("ok", false):
		return
	var expected: Array[String] = []
	for index in range(3):
		_check(admitted["hero_ids"][index] == admitted["party"][index]["id"],
			note + " admitted seat identity %d" % (index + 1))
		expected.append("%d %s" % [index + 1, admitted["party"][index]["name"]])
	_check(hint.text == "Seats: " + "  |  ".join(expected),
		note + " displayed combat seats exactly match admission")
	_check(picker.selected_ids() == picks, note + " seat projection retains click order")
	var width := hint.get_theme_font("font").get_string_size(
		hint.text, HORIZONTAL_ALIGNMENT_LEFT, -1, hint.get_theme_font_size("font_size")).x
	_check(width <= hint.size.x + 1.0
		and hint.get_visible_line_count() == hint.get_line_count()
		and picker.get_node("PaperPanel/Margins/Body/Foot").get_global_rect().encloses(hint.get_global_rect()),
		note + " every seat label remains visible in footer")


func _check_inspection(picker: Control, name: String, motif: String,
		role: String, signature: String, note: String) -> void:
	var rendered := _readout(picker)
	_check(rendered[0].contains(name) and rendered[0].contains(motif)
		and rendered[0].contains(role), note + " name / drawn motif / role")
	_check(rendered[1].contains(signature), note + " intended signature")
	_check(not rendered[1].contains("PLAY NOW"), note + " not falsely playable")


func _key_focus(button: Button) -> void:
	_check(button != null and button.focus_mode == Control.FOCUS_ALL,
		"real keyboard-focus target exists")
	if button == null:
		return
	button.grab_focus()
	await _frames()
	_check(button.has_focus(), "focus event reaches real tile")


func _key(button: Button, code: Key) -> void:
	_check(button != null and button.focus_mode == Control.FOCUS_ALL,
		"keyboard target focusable")
	if button == null:
		return
	button.grab_focus()
	await _frames()
	_check(button.has_focus(), "keyboard target really owns focus")
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		root.push_input(e, true)
	await _frames()


func _on_party(ids: Array[String]) -> void:
	requests.append(ids)


func _on_cancel() -> void:
	cancels += 1


func _ids(picker: LiveV3PartyPicker, expected: Array[String], note: String, latched: bool = false) -> void:
	_check(picker.selected_ids() == expected, note + " ordered selected IDs")
	var count: Label = picker.get_node(
		"PaperPanel/Margins/Body/Foot/SelectionCount")
	_check(count.text == "Selected %d/3" % expected.size(),
		note + " visible selected counter")
	var button: Button = picker.get_node(
		"PaperPanel/Margins/Body/Foot/ContinueButton")
	_check(button.disabled == (expected.size() != 3 or latched), note + " Continue gate")


## Check every admitted physical starter occurrence against the shipped
## resolver, in the exact receipt deck order (including repeated IDs).
func _check_deck_rows(picker: LiveV3PartyPicker, picks: Array[String], note: String) -> void:
	var actual := RunV3PartyAdmission.admit(picks)
	var base := "PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/DeckReadout"
	var view := picker.get_node(base) as VBoxContainer
	var heading := view.get_node("DeckHeading") as Label
	var toggle := picker.get_node("PaperPanel/Margins/Body/Foot/InspectDeckButton") as Button
	_check(actual.get("ok", false) and actual.deck.size() == 12
		and actual.party.size() == 3 and actual.hero_ids.size() == 3,
		note + " successful twelve-occurrence authoritative receipt")
	if not actual.get("ok", false):
		return
	_check(picker._seat_receipt == actual and picker.selected_ids() == picks,
		note + " displayed receipt and click order unchanged: wanted " + str(picks) + " got " + str(picker.selected_ids()))
	_check(view.visible and view.is_visible_in_tree() and heading.text == "SHARED DECK  •  12 starting cards / 3 heroes"
		and toggle.text == "Back" and not toggle.disabled,
		note + " three-hero combined inspection is visible")
	var clip := picker.inspection_panel.get_global_rect()
	_check(clip.encloses(view.get_global_rect())
		and picker.get_node("PaperPanel").get_global_rect().encloses(view.get_global_rect()),
		note + " all three rows inside the existing sewn inspection footprint")
	for i in range(3):
		var hero: String = actual.hero_ids[i]
		_check(actual.party[i].id == hero, note + " canonical real seat %d owner" % (i + 1))
		var ids: Array = actual.deck.slice(i * 4, (i + 1) * 4)
		_check(ids.size() == 4, note + " four physical occurrences in seat %d" % (i + 1))
		var unique: Array[String] = []
		var copies := {}
		var labels := {}
		for id in ids:
			var card: Dictionary = RunRestStitchCards.resolve_card_definition(id)
			_check(not card.is_empty() and card.get("owner") == hero
				and card.get("id") == id and typeof(card.get("cost")) == TYPE_INT
				and typeof(card.get("display_name")) == TYPE_STRING,
				note + " authentic printed owner/name/cost " + str(id))
			if card.is_empty():
				continue
			if not copies.has(id):
				unique.append(id)
				copies[id] = 0
				labels[id] = "%d EN %s" % [card.cost, card.display_name]
			copies[id] += 1
		var parts: Array[String] = []
		for id in unique:
			parts.append(labels[id] + (" x%d" % copies[id] if copies[id] > 1 else ""))
		var expected: String = "%d  %s  •  %s" % [i + 1, actual.party[i].name, "   |   ".join(parts)]
		var row := view.get_node("DeckSeat%d" % (i + 1)) as Label
		_check(row.visible and row.text == expected and row.tooltip_text == expected,
			note + " seat %d prints all distinct names, energy costs and exact xN: expected " % (i + 1) + expected + " got " + row.text)
		_check(row.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and clip.encloses(row.get_global_rect())
			and row.get_theme_font_size("font_size") >= 16
			and row.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS,
			note + " row %d accessible typography, noninteractive ellipsis/tooltip" % (i + 1))
		var printed_width := row.get_theme_font("font").get_string_size(
			row.text, HORIZONTAL_ALIGNMENT_LEFT, -1, row.get_theme_font_size("font_size")).x
		_check(printed_width <= row.size.x + 1.0,
			note + " full long card names fit row %d without clipping" % (i + 1))
		for earlier in range(i):
			var before := view.get_node("DeckSeat%d" % (earlier + 1)) as Label
			_check(not row.get_global_rect().intersects(before.get_global_rect()),
				note + " seat lines remain distinct at normal UI scale")
	_check(not picker.continue_button.disabled and picker.cancel_button.disabled == false,
		note + " inspection never conceals or disables live actions")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	canonical_roster = _read_hero_records("res://data/heroes/v3_party_roster.json")
	canonical_legacy = _read_hero_records("res://data/heroes/starter_party.json")
	_check(canonical_roster.size() >= 5 and canonical_legacy.size() == 3,
		"both shipped canonical hero records are loaded")
	for id in ORDER:
		_check(not _canonical_facts(id).is_empty(),
			"all eight IDs resolve to the authentic hero records: " + id)
	for id in LEGACY_HP:
		_check(_canonical_facts(id).get("hp") == LEGACY_HP[id],
			"legacy HP matches GAME_DESIGN.md: " + id)
	var packed := load(SCENE) as PackedScene
	_check(packed != null, "actual .tscn resource loads")
	if packed == null:
		_finish()
		return
	var picker := packed.instantiate() as LiveV3PartyPicker
	_check(picker != null, "actual .tscn has the chooser script")
	if picker == null:
		_finish()
		return
	root.add_child(picker)
	await _frames()
	_check(picker.is_node_ready() and picker.is_visible_in_tree(),
		"instanced, opened chooser is visible")
	_check(picker.size.x >= 1200 and picker.size.y >= 690,
		"1280x720 scene anchors fill the view")
	var panel: PanelContainer = picker.get_node("PaperPanel")
	var grid: GridContainer = picker.get_node(
		"PaperPanel/Margins/Body/HeroGrid")
	_check(grid.columns == 4 and grid.get_child_count() == 8,
		"four columns, exactly two rows and eight actual buttons")
	_check(picker.get_signal_connection_list("party_requested").is_empty(),
		"new view is detached from any run controller")
	picker.party_requested.connect(_on_party)
	picker.cancel_requested.connect(_on_cancel)
	var input_bounds := Rect2(Vector2.ZERO, Vector2(1280, 720))
	for i in range(8):
		var tile := _tile(picker, ORDER[i])
		_check(tile != null, "authored hero button exists: " + ORDER[i])
		if tile == null:
			continue
		_check(tile.focus_mode == Control.FOCUS_ALL and not tile.disabled,
			"enabled, focusable hero button " + ORDER[i])
		var name_label := tile.get_node_or_null(
			"Inset/Stack/NameLabel") as Label
		var motif_label := tile.get_node_or_null(
			"Inset/Stack/MotifLabel") as Label
		_check(name_label != null and name_label.text == NAMES[i],
			"named tile %s" % ORDER[i])
		_check(motif_label != null and
			motif_label.text.contains(MOTIFS[i]),
			"authentic visible sewn look motif " + ORDER[i])
		var face := tile.get_node_or_null("Inset/Stack/Face")
		var portrait := face.get_node_or_null("Portrait") if face != null else null
		var fallback := face.get_node_or_null("FallbackMotif") if face != null else null
		_check((portrait != null) != (fallback != null),
			"exactly texture or drawn fall-back for " + ORDER[i])
		if portrait != null:
			_check((portrait as TextureRect).texture != null,
				"real imported portrait texture: " + ORDER[i])
		if fallback != null:
			_check(fallback is Control and fallback.is_visible_in_tree()
				and fallback.size.x > 60 and fallback.size.y > 60,
				"measurable drawn silhouette fallback: " + ORDER[i])
		_check(input_bounds.encloses(tile.get_global_rect()),
			"visible hit target stays on 1280x720: " + ORDER[i])
		_check(panel.get_global_rect().encloses(tile.get_global_rect()),
			"each button inside the sewn panel: " + ORDER[i])
		_check(name_label == null or
			name_label.get_theme_font_size("font_size") >= 20,
			"readable tile name typography: " + ORDER[i])
		for j in range(i):
			var prior := _tile(picker, ORDER[j])
			if prior != null:
				_check(not prior.get_global_rect().intersects(tile.get_global_rect()),
					"distinct button footprints: " + ORDER[j] + " / " + ORDER[i])
	var action: Button = picker.get_node(
		"PaperPanel/Margins/Body/Foot/ContinueButton")
	var cancel: Button = picker.get_node(
		"PaperPanel/Margins/Body/Foot/CancelButton")
	var deck_button: Button = picker.get_node(
		"PaperPanel/Margins/Body/Foot/InspectDeckButton")
	var deck_view: VBoxContainer = picker.get_node(
		"PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/DeckReadout")
	_check(deck_button != null and deck_button.focus_mode == Control.FOCUS_ALL,
		"real keyboard and pointer Inspect Deck button exists")
	_check(deck_view != null and deck_view.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"shared-deck rows live inside input-transparent original inspection")
	_check(input_bounds.encloses(action.get_global_rect()) and
		input_bounds.encloses(cancel.get_global_rect()),
		"Continue and Cancel reachable in viewport")
	var inspection: PanelContainer = picker.get_node(
		"PaperPanel/Margins/Body/InspectionPanel")
	var heading: Label = inspection.get_node("Inset/Stack/InspectionHeading")
	var detail: Label = inspection.get_node("Inset/Stack/InspectionDetail")
	var facts: Label = inspection.get_node("Inset/Stack/InspectionFacts")
	_check(inspection.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and heading.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and detail.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and facts.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and inspection.focus_mode == Control.FOCUS_NONE,
		"sewn readout never intercepts mouse or keyboard")
	_check(heading.get_theme_font_size("font_size") >= 18
		and detail.get_theme_font_size("font_size") >= 16
		and facts.get_theme_font_size("font_size") >= 16,
		"legible stitched heading and signature sizes")
	_check(input_bounds.encloses(inspection.get_global_rect())
		and panel.get_global_rect().encloses(inspection.get_global_rect()),
		"stitched readout wholly visible at 1280x720")
	_check(inspection.get_global_rect().encloses(heading.get_global_rect())
		and inspection.get_global_rect().encloses(detail.get_global_rect())
		and inspection.get_global_rect().encloses(facts.get_global_rect())
		and not facts.get_global_rect().intersects(heading.get_global_rect())
		and not facts.get_global_rect().intersects(detail.get_global_rect())
		and detail.get_visible_line_count() == detail.get_line_count(),
		"readout fits all rendered text lines")
	for i in range(8):
		var tile := _tile(picker, ORDER[i])
		if tile != null:
			_check(not tile.get_global_rect().intersects(inspection.get_global_rect()),
				"inspector does not overlap hero hit target " + ORDER[i])
	for button in [cancel, action]:
		_check(not button.get_global_rect().intersects(inspection.get_global_rect()),
			"inspector does not overlap action " + button.name)
	_check(not action.get_global_rect().intersects(cancel.get_global_rect()),
		"action buttons have distinct footprints")
	_check(_readout(picker)[0].contains("HOVER OR FOCUS")
		and _readout(picker)[1].contains("before choosing three"),
		"fresh open has neutral guidance, not an auto-focused hero")
	var hint: Label = picker.get_node("PaperPanel/Margins/Body/Foot/Hint")
	_check(hint.text.contains("Choose three") and hint.text.contains("preview"),
		"empty opening gives guidance instead of fictitious combat seats")
	_check(not cancel.disabled and action.disabled and deck_button.disabled
		and not deck_view.visible, "fresh zero selection gate and blank combined deck")
	deck_button.pressed.emit()
	_check(not deck_view.visible and picker._seat_receipt.is_empty(),
		"invalid direct Inspect Deck press cannot invent starting deck")
	_check(picker.selected_ids().is_empty(), "fresh selection is empty")
	var before_json := FileAccess.get_file_as_string("res://data/heroes/starter_party.json")
	_check(before_json.contains("warden") and before_json.contains("seamstress")
		and before_json.contains("tinker"), "real unmodified three-hero fixture")

	# Guard interaction against using the global RNG (no runtime random draw).
	seed(48109)
	var first := randi()
	var second := randi()
	seed(48109)
	_check(randi() == first, "global RNG oracle established")

	# Genuine pointer and focus transitions inspect without picking.
	await _key_focus(_tile(picker, "lantern_monk"))
	_check_inspection(picker, "Lantern Monk", "LANTERN", "Light keeper",
		"Moth Cloud", "real Lantern Monk focus")
	await _move_to(_tile(picker, "warden"))
	_check_inspection(picker, "Warden", "HELMET", "Bulwark",
		"Shield Toss", "hover overrides the different focused hero")
	await _move_to(picker.get_node("PaperPanel/Margins/Body/SubTitle"))
	_check_inspection(picker, "Lantern Monk", "LANTERN", "Light keeper",
		"Blind", "mouse exit restores keyboard inspection")
	await _move_to(_tile(picker, "scarecrow"))
	_check_inspection(picker, "Scarecrow", "FORK", "Fear harrier",
		"Crow Peck", "real Scarecrow pointer hover")
	await _move_to(picker.get_node("PaperPanel/Margins/Body/SubTitle"))
	await _key_focus(_tile(picker, "button_golem"))
	_check_inspection(picker, "Button Golem", "BUTTONS", "Block bruiser",
		"Pop Button", "real Button Golem focus")
	for i in range(8):
		await _move_to(_tile(picker, ORDER[i]))
		_check_inspection(picker, NAMES[i], MOTIFS[i], ROLES[i],
			SIGNATURES[i], "all eight distinct designed signatures: " + ORDER[i])
		_check_canonical_inspection(picker, ORDER[i], "pointer " + ORDER[i])
		_check(detail.get_visible_line_count() == detail.get_line_count()
			and facts.get_visible_line_count() == facts.get_line_count()
			and inspection.get_global_rect().encloses(detail.get_global_rect())
			and inspection.get_global_rect().encloses(facts.get_global_rect()),
			"inspected hero signature / canonical facts fully visible: " + ORDER[i])
		await _move_to(picker.get_node("PaperPanel/Margins/Body/SubTitle"))
		await _key_focus(_tile(picker, ORDER[i]))
		_check_inspection(picker, NAMES[i], MOTIFS[i], ROLES[i],
			SIGNATURES[i], "keyboard signature: " + ORDER[i])
		_check_canonical_inspection(picker, ORDER[i], "keyboard " + ORDER[i])
	await _move_to(picker.get_node("PaperPanel/Margins/Body/SubTitle"))
	_ids(picker, [], "inspection never changes requested picks")
	await _mouse(_tile(picker, "warden"))
	_ids(picker, ["warden"], "mouse first")
	await _key(_tile(picker, "seamstress"), KEY_SPACE)
	_ids(picker, ["warden", "seamstress"], "Space second")
	_check(deck_button.disabled and not deck_view.visible, "two picks have no inspectable deck")
	deck_button.pressed.emit()
	_check(not deck_view.visible and picker.selected_ids().size() == 2,
		"disabled two-pick inspection leaves selection alone")
	await _mouse(_tile(picker, "tinker"))
	_ids(picker, ["warden", "seamstress", "tinker"], "mouse third")
	_check_seats(picker, ["warden", "seamstress", "tinker"], "legacy trio")
	await _key(deck_button, KEY_SPACE)
	_check_deck_rows(picker, ["warden", "seamstress", "tinker"], "legacy three seat deck via keyboard")
	_check(deck_view.get_node("DeckSeat1").text.contains("1 EN Strike x2")
		and deck_view.get_node("DeckSeat2").text.contains("1 EN Prick x2"),
		"genuine legacy duplicate starters count exactly twice, not collapsed or repeated")
	_check(requests.is_empty() and cancels == 0, "Inspect Deck fires no run or cancel signals")
	await _mouse(deck_button)
	_check(not deck_view.visible and deck_button.text == "Inspect Deck",
		"pointer Back restores hero inspection mode")
	await _move_to(_tile(picker, "warden"))
	_check_inspection(picker, "Warden", "HELMET", "Bulwark", "Guard",
		"Back restores original hover details")
	await _mouse(_tile(picker, "lantern_monk"))
	_ids(picker, ["warden", "seamstress", "tinker"], "fourth blocked")
	await _mouse(deck_button)
	_check_deck_rows(picker, ["warden", "seamstress", "tinker"], "inspect before unpick")
	await _key(_tile(picker, "seamstress"), KEY_ENTER)
	_ids(picker, ["warden", "tinker"], "Enter unpicks second")
	_check(not hint.text.contains("Seats:") and action.disabled,
		"deselection removes prospective seats and closes Continue gate")
	_check(not deck_view.visible and deck_button.disabled
		and picker._seat_receipt.is_empty(),
		"unpick while Inspect Deck open immediately retires all old card rows")
	await _key(_tile(picker, "lantern_monk"), KEY_SPACE)
	_ids(picker, ["warden", "tinker", "lantern_monk"],
		"re-pick appends to order")
	_check_seats(picker, ["warden", "tinker", "lantern_monk"],
		"replacement selection sorted independent of click order")
	await _mouse(deck_button)
	_check_deck_rows(picker, ["warden", "tinker", "lantern_monk"],
		"mixed legacy and new three-hero deck after replacement")
	var snapshot: Array[String] = picker.selected_ids()
	snapshot.clear()
	_ids(picker, ["warden", "tinker", "lantern_monk"],
		"returned accessor is detached")
	await _mouse(action)
	_check(requests.size() == 1 and
		requests[0] == ["warden", "tinker", "lantern_monk"],
		"Continue emits one deterministic three-ID request")
	_check(not deck_view.visible and deck_button.disabled and deck_button.text == "Inspect Deck",
		"Continue retires combined inspection even while it is open")
	deck_button.pressed.emit()
	_check(requests.size() == 1, "stale Inspect after Continue emits no extra request")
	_check(action.disabled and cancel.disabled
		and _tile(picker, "warden").disabled,
		"Continue latches all actions and retains submitted view")
	action.pressed.emit()
	cancel.pressed.emit()
	_tile(picker, "rag_duelist").pressed.emit()
	_check(requests.size() == 1 and cancels == 0,
		"duplicate, canceled and mutation presses ignored after Continue")
	_ids(picker, ["warden", "tinker", "lantern_monk"], "latched snapshot", true)
	_check(not hint.text.contains("Seats:"), "latched view no longer advertises an active seat projection")

	# Reopening replaces the actual buttons; an old generation cannot inject.
	var stale := _tile(picker, "warden")
	picker.open_picker()
	stale.pressed.emit()
	var stale_motion := InputEventMouseMotion.new()
	stale_motion.position = stale.get_global_rect().get_center()
	stale.gui_input.emit(stale_motion)
	stale.focus_entered.emit()
	stale.mouse_exited.emit()
	_check(picker.selected_ids().is_empty(), "stale generation ignored")
	_check(_readout(picker)[0].contains("HOVER OR FOCUS"),
		"retired hovered / focused / pressed tile cannot overwrite fresh inspection")
	await _frames()
	_ids(picker, [], "reopened")
	_check(not hint.text.contains("Seats:"), "full reopen retires previous party preview")
	_check(_readout(picker)[0].contains("HOVER OR FOCUS"),
		"neutral reset survives next mounted frame")
	_check(not cancel.disabled and picker.is_visible_in_tree(),
		"open_picker resets latch and visibility")
	_check(deck_button.disabled and not deck_view.visible and deck_button.text == "Inspect Deck",
		"fresh opening has no previous deck-mode state")
	await _mouse(_tile(picker, "scarecrow"))
	_ids(picker, ["scarecrow"], "fresh selection after reopen")
	_check(not hint.text.contains("Seats:"), "one picked hero has no invented seat order")
	var cancelled_tile := _tile(picker, "scarecrow")
	await _key(cancel, KEY_ENTER)
	_check(cancels == 1 and requests.size() == 1,
		"Cancel emits only cancel_requested")
	_check(not picker.visible and cancel.disabled, "Cancel closes/latches view")
	cancel.pressed.emit()
	_tile(picker, "scarecrow").pressed.emit()
	_check(cancels == 1 and picker.selected_ids() == ["scarecrow"],
		"cancelled opening ignores stale actions")
	picker.open_picker()
	cancelled_tile.gui_input.emit(stale_motion)
	cancelled_tile.focus_entered.emit()
	cancelled_tile.pressed.emit()
	await _frames()
	_ids(picker, [], "reopen after cancel")
	_check(not hint.text.contains("Seats:"), "cancel and reopen never retain a stale party")
	_check(_readout(picker)[0].contains("HOVER OR FOCUS"),
		"cancelled tile callbacks cannot inspect newly opened chooser")
	await _key(_tile(picker, "button_golem"), KEY_ENTER)
	await _mouse(_tile(picker, "yarn_ranger"))
	await _mouse(_tile(picker, "rag_duelist"))
	_ids(picker, ["button_golem", "yarn_ranger", "rag_duelist"],
		"second ordered full party")
	_check_seats(picker, ["button_golem", "yarn_ranger", "rag_duelist"],
		"two preferred-front heroes retain their pick-order tie")
	await _key(deck_button, KEY_ENTER)
	_check_deck_rows(picker, ["button_golem", "yarn_ranger", "rag_duelist"],
		"V3 three-seat deck stable front ties")
	await _key(deck_button, KEY_SPACE)
	_check(not deck_view.visible, "keyboard Back exits combined preview")
	await _key(action, KEY_SPACE)
	_check(requests.size() == 2 and
		requests[1] == ["button_golem", "yarn_ranger", "rag_duelist"],
		"new opening emits fresh three IDs via Space Continue")
	(requests[1] as Array)[0] = "forged"
	_check(picker.selected_ids() == ["button_golem", "yarn_ranger", "rag_duelist"],
		"signal payload detached from stored selection")
	_check(requests[0] == ["warden", "tinker", "lantern_monk"],
		"first request unchanged by subsequent opening")
	# Show the exact two-front tie example without emitting a third request.
	picker.open_picker()
	await _mouse(_tile(picker, "button_golem"))
	await _mouse(_tile(picker, "rag_duelist"))
	await _mouse(_tile(picker, "lantern_monk"))
	_ids(picker, ["button_golem", "rag_duelist", "lantern_monk"], "front tie example")
	_check_seats(picker, ["button_golem", "rag_duelist", "lantern_monk"],
		"both preferred front heroes occupy actual seats 1 and 2")
	await _mouse(deck_button)
	_check_deck_rows(picker, ["button_golem", "rag_duelist", "lantern_monk"],
		"exact same-position tie order and seat deck projection")
	await _key_focus(_tile(picker, "lantern_monk"))
	_check(deck_view.visible, "keyboard focus never silently replaces an open deck view")
	await _key(deck_button, KEY_ENTER)
	await _move_to(_tile(picker, "lantern_monk"))
	_check_inspection(picker, "Lantern Monk", "LANTERN", "Light keeper", "Blind",
		"Back restores latest real tile focus/hover")
	await _mouse(_tile(picker, "rag_duelist"))
	_ids(picker, ["button_golem", "lantern_monk"], "tie example deselection")
	_check(not hint.text.contains("Seats:"), "two heroes cannot display admitted positions")
	await _mouse(_tile(picker, "scarecrow"))
	_ids(picker, ["button_golem", "lantern_monk", "scarecrow"],
		"replacement hero joins in click order")
	_check_seats(picker, ["button_golem", "lantern_monk", "scarecrow"],
		"middle-position tie retains click order")
	await _key(deck_button, KEY_SPACE)
	_check_deck_rows(picker, ["button_golem", "lantern_monk", "scarecrow"],
		"replacement reprojects current receipt while in deck mode")
	await _mouse(deck_button)
	# A malformed internal request models a failed admission: no fabricated
	# seats, no enabled Continue, and no detached party emission.
	picker._ids.assign(["warden", "warden", "scarecrow"])
	picker._refresh()
	_check(hint.text == "Party admission unavailable" and action.disabled,
		"invalid canonical admission produces no authoritative seating")
	_check(deck_button.disabled and not deck_view.visible
		and picker._deck_receipt_rows().is_empty(),
		"invalid admission gates Inspect Deck with no stale or forged list")
	action.pressed.emit()
	_check(requests.size() == 2, "failed admission cannot emit party_requested")
	picker.open_picker()
	await _frames()  # New tile geometry must settle before synthesizing pointer events.
	_ids(picker, [], "failed admission full reopen")
	await _key(_tile(picker, "warden"), KEY_ENTER)
	await _key(_tile(picker, "tinker"), KEY_SPACE)
	await _key(_tile(picker, "yarn_ranger"), KEY_ENTER)
	await _mouse(deck_button)
	_check_deck_rows(picker, ["warden", "tinker", "yarn_ranger"],
		"reopened mixed card deck before cancellation")
	var pre_cancel := requests.size()
	await _key(cancel, KEY_ENTER)
	_check(not deck_view.visible and deck_button.disabled and not picker.visible
		and cancels == 2 and requests.size() == pre_cancel,
		"Cancel with combined deck visible clears it and emits only cancel")
	picker.open_picker()
	_check(deck_button.disabled and not deck_view.visible and picker.selected_ids().is_empty(),
		"reopen after deck Cancel is neutral and has no receipt")
	deck_button.pressed.emit()
	_check(not deck_view.visible and picker._seat_receipt.is_empty(),
		"retired deck action cannot resurrect cancelled preview")
	_check(not hint.text.contains("Seats:"), "invalid party cannot survive reopen")
	_check(randi() == second, "all input/reopen operations consume no global RNG")
	_check(FileAccess.get_file_as_string(
		"res://data/heroes/starter_party.json") == before_json,
		"view changed no authoritative authored hero data")
	picker.queue_free()
	await _frames()
	await _live_start_checks()
	_finish()


func _opening_state(app) -> Array:
	return [app.run_map, app.run_rng, app.run_deck.duplicate(), app.run_heroes.duplicate(true),
		app.session_gold, app.run_scraps, app.party_carryover, app.deck]


func _journey() -> Dictionary:
	for value in range(1, 2500):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for rest in map.get_legal_choices():
			if map.get_node(rest).type != "Rest":
				continue
			for shop in map.get_node(rest).outgoing:
				if map.get_node(shop).type != "Shop":
					continue
				for first in map.get_node(shop).outgoing:
					if map.get_node(first).type != "Fight":
						continue
					for second in map.get_node(first).outgoing:
						if map.get_node(second).type in ["Fight", "Elite"]:
							return {"seed": value, "nodes": [rest, shop, first, second]}
	return {}


func _route_button(app, id: String) -> Button:
	for button in app.route_buttons:
		if button.get_meta("route_id") == id:
			return button
	return null


func _live_start_checks() -> void:
	var app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	var idle := _opening_state(app)
	seed(17931)
	var expected := randi()
	seed(17931)
	await _mouse(app.start_button)
	var view: LiveV3PartyPicker = app.party_picker
	_check(is_instance_valid(view) and view.grid.get_child_count() == 8,
		"real title Start mounts all eight selectable heroes")
	if not is_instance_valid(view):
		app.free()
		return
	var old_request: Callable = view.party_requested.get_connections()[0].callable
	var old_cancel: Callable = view.cancel_requested.get_connections()[0].callable
	for raw in [["warden", "tinker"], ["warden", "tinker", "seamstress", "scarecrow"],
		["warden", "warden", "tinker"], ["warden", "seamstress", "tinker"]]:
		var forged: Array[String] = []
		forged.assign(raw)
		view.party_requested.emit(forged)
		old_request.call(forged)
		view.cancel_requested.emit()
		_check(_opening_state(app) == idle and app.party_picker == view,
			"forged valid/invalid request and cancel allocate and spend nothing")
	await _mouse(_tile(view, "warden"))
	await _key(_tile(view, "tinker"), KEY_SPACE)
	view.continue_button.pressed.emit()
	_check(_opening_state(app) == idle and view.continue_button.disabled,
		"two picks cannot Continue")
	await _key(view.cancel_button, KEY_ENTER)
	_check(app.party_picker == null and _opening_state(app) == idle and app.title_view.visible,
		"authentic Cancel retires picker without creating run")
	_check(randi() == expected, "picker failures, inputs and Cancel consume no global RNG")
	await _mouse(app.start_button)
	var legacy: Array[String] = ["warden", "seamstress", "tinker"]
	old_request.call(legacy)
	old_cancel.call()
	_check(app.run_map == null and is_instance_valid(app.party_picker), "retired opening callbacks cannot start or cancel fresh picker")
	app._return_to_title()
	var fixture := _journey()
	_check(not fixture.is_empty(), "authentic Rest-Shop-Fight-next-Fight/Elite path found")
	if fixture.is_empty():
		app.free()
		return
	for trio in [["scarecrow", "rag_duelist", "lantern_monk"], ["yarn_ranger", "tinker", "button_golem"]]:
		var replay: Array = []
		for attempt in range(3):
			app.run_seed = fixture.seed
			await _mouse(app.start_button)
			view = app.party_picker
			var retired: Callable = view.party_requested.get_connections()[0].callable
			for id in trio:
				await _key(_tile(view, id), KEY_SPACE)
			var admission := RunV3PartyAdmission.admit(trio)
			_check(admission.ok and view.selected_ids().size() == 3, "nondefault request is canonically admitted")
			await _key(view.continue_button, KEY_ENTER)
			_check(app.run_map != null and app.party_picker == null and app.run_rng != null,
				"real Continue publishes legal seeded run and retires picker")
			if app.run_map == null:
				app._return_to_title()
				continue
			var initial := CombatParty.new(admission.party).get_heroes()
			_check(app.run_heroes == initial and app.run_deck == admission.deck and app.run_deck.size() == 12,
				"authored canonical order, HP, passive metadata and exactly four starters per hero")
			var state := _opening_state(app)
			retired.call(legacy)
			old_request.call(legacy)
			app._start_run()
			_check(_opening_state(app) == state, "repeated Continue and all stale openings preserve run identity")
			var cards: Array = app.run_deck.duplicate()
			app.run_deck[0] = "unknown"
			_check(not app._unfought_run(), "tampered initial deck cannot borrow valid opening wallet admission")
			app.run_deck.assign(cards)
			if attempt == 2:
				# Use the shipped preview's explicit wallet fixture before entering visits.
				# The ordinary replay pair retains zero resources and twelve cards.
				var boot = root.get_node("LiveWebPlaytestBoot")
				boot._preview_map = weakref(app.run_map)
				app.session_gold = boot.GOLD
				app.run_scraps = boot.SCRAPS
				app._clear_route_view()
				app._present_connected_route(weakref(app.run_map))
			var trace: Array = [app.run_map.get_floors(), app.run_heroes.duplicate(true), app.run_deck.duplicate(), app.run_rng.state]
			var torn_id := ""
			for index in range(fixture.nodes.size()):
				var id: String = fixture.nodes[index]
				var button := _route_button(app, id)
				_check(button != null and not button.disabled, "authentic connected choice is present and enabled")
				if button == null:
					break
				if index == 2:
					var before := [app.run_map.get_route(), app.run_rng.state, app.session_gold, app.run_scraps]
					app.run_deck.append("warden_strike")
					button.pressed.emit()
					_check(app.deck == null and [app.run_map.get_route(), app.run_rng.state, app.session_gold, app.run_scraps] == before,
						"foreign starter rejected before map or RNG mutation after visits")
					app.run_deck.pop_back()
					var carry: RunTornCarryover = app.party_carryover
					var hero_id: String = initial[0].id
					carry.torn._tear_counts[hero_id] = 1
					button.pressed.emit()
					_check(app.deck == null and [app.run_map.get_route(), app.run_rng.state, app.session_gold, app.run_scraps] == before,
						"invalid torn ledger rejected atomically before first battle")
					carry.torn._tear_counts[hero_id] = 0
				var carried: Array = app.run_heroes.duplicate(true)
				await _mouse(button)
				if index == 0:
					_check(is_instance_valid(app.campfire_view), "chosen trio reaches real Campfire from Rest source")
					if is_instance_valid(app.campfire_view):
						await _mouse(app.campfire_leave_button)
				elif index == 1:
					_check(is_instance_valid(app.shop_view), "chosen trio reaches real Peddler")
					if is_instance_valid(app.shop_view):
						if attempt == 2:
							var gold_before: int = app.session_gold
							var price: int = app.peddler_visit.read_state().stock.cards[0].price
							await _mouse(app.peddler_buttons[0])
							_check(app.party_carryover._wardrobe != null and app.session_gold == gold_before - price
								and app.run_deck.size() == 13, "real chosen card purchase binds wardrobe and spends exact service quote")
						else:
							await _mouse(app.peddler_leave_button)
				else:
					_check(app.deck != null and app.party != null and app.party_carryover is RunTornCarryover,
						"chosen party enters actual routed battle")
					if app.deck == null:
						break
					var hydrated: Array = app.party.get_heroes()
					for hero in hydrated:
						hero.block = 0
					_check(hydrated == carried and app.deck.energy == 3 and app.deck.hand.size() == 5,
						"authoritative party hydration, energy three and opening draw five")
					var dealt: Array = app.deck.hand + app.deck.draw_pile + app.deck.discard_pile
					var wanted: Array = app.run_deck.duplicate()
					dealt.sort()
					wanted.sort()
					_check(dealt == wanted, "single run deck deals every starter/claimed occurrence exactly once")
					_check(app._quilt_bonus != null and app._quilt_turn_open, "real battle begins chosen-party Quilt tracking")
					for card in app.deck.hand:
						var definition := RunRestStitchCards.resolve_card_definition(card)
						_check(not definition.is_empty() and app._quilt_owners_of(card) == [definition.owner],
							"real held V3 card resolves its chosen Quilt owner")
					if index == 2:
						torn_id = app.party.get_hero(1).id
						_check(app.party.apply_damage(1, app.party.get_hero(1).hp + app.party.get_hero(1).block), "one chosen hero genuinely downed")
					for enemy in app.enemies.get_enemies():
						_check(app.enemies.apply_damage(enemy.position, enemy.hp + enemy.block), "authoritative enemy damage witnesses victory")
					app._observe_battle_result()
					_check(app._battle_closed, "real victory observation closes battle")
					_check(app.party_carryover.can_commit_victory(id, app.battle_result, app.party),
						"real victory can commit chosen carryover")
					await _frames()
					_check(app.battle_result.get_outcome() == CombatBattleResult.VICTORY and app.reward_buttons.size() == 4,
						"actual victory prepares nonempty three-card reward and Skip")
					if app.reward_buttons.size() != 4:
						break
					_check(app.fight_reward_offers.size() == 3, "prepared reward has three offers")
					for offer in app.fight_reward_offers:
						var definition := RunPoolCardRewardOffers.resolve_reward_definition(offer.id)
						_check(not definition.is_empty() and definition.owner in admission.hero_ids and definition.owner == offer.owner,
							"every live reward resolves to chosen owner's authored base pool")
					var selected: String = app.fight_reward_offers[0].id
					var prior_cards: Array = app.run_deck.duplicate()
					await _mouse(app.reward_buttons[0])
					prior_cards.append(selected)
					_check(app.fight_reward_claimed and app.run_deck == prior_cards,
						"genuine chosen reward claim commits exactly one chosen-only card")
					_check(app.party_carryover.torn.read_state().tear_counts[torn_id] == 1,
						"chosen hero's one tear persists through claim and second battle")
					_check(app.run_heroes == app.party_carryover.read_state().heroes,
						"reward publishes authoritative chosen carryover")
					trace.append([app.run_heroes.duplicate(true), app.run_deck.duplicate(), app.run_rng.state,
						app.party_carryover.torn.read_state()])
					await _mouse(app.continue_button)
			_check(app.party_carryover.read_state().completed_fights.size() == 2,
				"both genuine routed fights completed with chosen party")
			if attempt == 0:
				replay = trace.duplicate(true)
			elif attempt == 1:
				_check(trace == replay, "same-seed nondefault journey replays map, party, deck, RNG, rewards and tears exactly")
			app._return_to_title()
			_check(app.party_picker == null and app._party_receipt.is_empty() and _opening_state(app) == idle,
				"Return clears selected admission and every run model and wallet")
	app.free()
	await _frames()


func _finish() -> void:
	if failures.is_empty():
		print("PASS live_v3_party_picker_test: %d assertions" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		printerr("FAIL live_v3_party_picker_test: %d/%d" % [
			failures.size(), checks])
		quit(1)
