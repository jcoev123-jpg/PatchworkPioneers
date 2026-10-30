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
	var scroll := view.get_node("DeckScroll") as ScrollContainer
	var shared := view.get_node("DeckSharedHandNote") as Label
	var frozen := picker._seat_receipt.duplicate(true)
	var signals_before := [requests.size(), cancels]
	_check(clip.encloses(view.get_global_rect())
		and picker.get_node("PaperPanel").get_global_rect().encloses(view.get_global_rect())
		and clip.encloses(scroll.get_global_rect())
		and clip.encloses(shared.get_global_rect()),
		note + " bounded scroll and shared-rule caption fit sewn inspection footprint")
	_check(shared.is_visible_in_tree()
		and shared.text == "ONE shared deck  •  3 energy per turn  •  draw 5"
		and shared.tooltip_text == shared.text,
		note + " one real 12-card shared deck with 3 energy and draw 5 rule")
	_check(scroll.focus_mode == Control.FOCUS_ALL and scroll.get_v_scroll_bar() != null
		and scroll.size.y >= 75 and scroll.get_v_scroll_bar().max_value > scroll.size.y,
		note + " passive text has a bounded keyboard-focusable mouse scroll")
	for i in range(3):
		var hero: String = actual.hero_ids[i]
		_check(actual.party[i].id == hero, note + " canonical real seat %d owner" % (i + 1))
		var canonical := _canonical_facts(hero)
		var facts_row := view.get_node("DeckScroll/DeckRows/DeckSeatFacts%d" % (i + 1)) as Label
		_check(not canonical.is_empty() and int(canonical.get("hp", 0)) > 0
			and not str(canonical.get("passive", "")).is_empty(),
			note + " seat %d has independent authored HP and passive" % (i + 1))
		var expected_facts: String = "%d  %s  •  Max HP: %d  •  Passive: %s" % [
			i + 1, actual.party[i].name, canonical.get("hp", 0), canonical.get("passive", "")]
		_check(facts_row.is_visible_in_tree() and facts_row.text == expected_facts
			and facts_row.tooltip_text == expected_facts
			and facts_row.autowrap_mode == TextServer.AUTOWRAP_WORD
			and facts_row.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			note + " seat %d prints exact independent max HP/passive in receipt order" % (i + 1))
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
		var row := view.get_node("DeckScroll/DeckRows/DeckSeat%d" % (i + 1)) as Label
		_check(row.visible and row.text == expected and row.tooltip_text == expected,
			note + " seat %d prints all distinct names, energy costs and exact xN: expected " % (i + 1) + expected + " got " + row.text)
		_check(row.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and row.get_parent() == view.get_node("DeckScroll/DeckRows")
			and row.get_theme_font_size("font_size") >= 16
			and row.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS,
			note + " row %d accessible typography, noninteractive ellipsis/tooltip" % (i + 1))
		var printed_width := row.get_theme_font("font").get_string_size(
			row.text, HORIZONTAL_ALIGNMENT_LEFT, -1, row.get_theme_font_size("font_size")).x
		_check(printed_width <= row.size.x + 1.0,
			note + " full long card names fit row %d without clipping" % (i + 1))
		for earlier in range(i):
			var before := view.get_node("DeckScroll/DeckRows/DeckSeat%d" % (earlier + 1)) as Label
			_check(not row.get_global_rect().intersects(before.get_global_rect()),
				note + " seat lines remain distinct at normal UI scale")
	scroll.grab_focus()
	_check(scroll.has_focus(), note + " scroll region accepts keyboard focus")
	scroll.scroll_vertical = 10000
	_check(scroll.scroll_vertical > 0, note + " long facts and card rows can be scrolled by pointer or keyboard")
	scroll.scroll_vertical = 0
	_check(picker.selected_ids() == picks and picker._seat_receipt == frozen
		and [requests.size(), cancels] == signals_before,
		note + " inspection and scroll leave picks, admission and signals untouched")
	_check(not picker.continue_button.disabled and picker.cancel_button.disabled == false,
		note + " inspection never conceals or disables live actions")


## Independent source oracle: use the actual per-hero catalogs, not the
## picker's caption, admission projection, or its kit lookup helper.
func _source_catalog(hero_id: String) -> Object:
	match hero_id:
		"warden", "seamstress", "tinker":
			return StarterCards.new()
		"lantern_monk":
			return LanternMonkStarterCards.new()
		"rag_duelist":
			return RagDuelistStarterCards.new()
		"scarecrow":
			return ScarecrowStarterCards.new()
		"yarn_ranger":
			return YarnRangerStarterCards.new()
		"button_golem":
			return ButtonGolemStarterCards.new()
	return null


func _source_deck(hero_id: String) -> Array[String]:
	var source := _source_catalog(hero_id)
	if source == null:
		return []
	var result: Array[String] = []
	for id in source.get_starting_deck():
		if source.get_definition(id).get("owner") == hero_id:
			result.append(id)
	return result


func _oracle_effect_fragment(key: String, amount: Variant) -> String:
	if key in ["ignore_block", "cannot_buff_next_turn"]:
		return ("ignores foe Block" if key == "ignore_block" else "Fear: foe cannot buff next turn") if amount is bool and amount else ""
	if not amount is int or amount <= 0:
		return ""
	match key:
		"damage":
			return "%d damage" % amount
		"block":
			return "%d Block to target" % amount
		"block_self":
			return "Self gains %d Block" % amount
		"heal":
			return "Heal %d HP" % amount
		"weak", "bleed", "exposed", "unravel", "tangled":
			return "%s %d" % [key.capitalize(), amount]
		"blind":
			return "Blind %d (next attack misses)" % amount
		"draw":
			return "Draw %d card" % amount
		"cleanse_debuff":
			return "Cleanse %d debuff" % amount
		"move_self_forward":
			return "Advance self %d slot" % amount
		"riposte":
			return "Riposte %d when hit" % amount
		"duration":
			return "Lasts %d turn" % amount
		"dodge_next_attack":
			return "Dodge next %d attack" % amount
		"pull_forward":
			return "Pull target forward %d slot" % amount
		"spend_block":
			return "spends %d self Block" % amount
		"buttons_popped":
			return "successful hit, add %d button" % amount
		"swap_with_ally":
			return "Swap position with chosen living ally"
		"block_per_button_popped":
			return "%d Block per previously popped button" % amount
	return ""


func _check_kit_occurrence(picker: LiveV3PartyPicker, hero_id: String,
		occurrence: int, source_id: String, note: String) -> void:
	var source := _source_catalog(hero_id)
	var card: Dictionary = source.get_definition(source_id)
	var kit := picker.kit_readout
	_check(not card.is_empty() and card.get("owner") == hero_id and card.get("id") == source_id
		and not source_id.ends_with("_plus") and not card.has("upgrade_of"),
		note + " independent base owner and identity")
	if card.is_empty():
		return
	_check(kit.is_visible_in_tree() and picker._kit_hero == hero_id and picker._kit_index == occurrence
		and picker._kit_card(hero_id, occurrence) == card,
		note + " exact physical occurrence from independent catalog")
	_check(picker.kit_card_heading.text == "STARTER %d / 4  •  %s  •  %d EN" % [
		occurrence + 1, card.display_name, card.cost],
		note + " exact authored name, cost and physical copy index")
	var from_parts: Array[String] = []
	var to_parts: Array[String] = []
	for slot in card.from_positions:
		from_parts.append(str(slot))
	for slot in card.to_positions:
		to_parts.append(str(slot))
	var target: String = picker.kit_target.text
	_check(target.contains("Play from slots " + ", ".join(from_parts))
		and target.contains("Target: "), note + " source caster slots and target label")
	var scope := ""
	match card.target_kind:
		"enemy_single":
			scope = "one foe in slots " + ", ".join(to_parts)
		"enemy_all":
			scope = "all foes in slots " + ", ".join(to_parts)
		"enemy_back":
			scope = "backmost living foe (slots " + ", ".join(to_parts) + ")"
		"self":
			scope = "self"
		"ally_single":
			scope = "one chosen ally"
		"party_all":
			scope = "all living allies"
		"none":
			scope = "no target"
	_check(not scope.is_empty() and target.contains("Target: " + scope),
		note + " precise source target_kind and target slots")
	var effects: String = picker.kit_effects.text
	_check(not effects.is_empty() and effects == picker.kit_effects.tooltip_text,
		note + " fully available readable effect text")
	_check(card.effects is Dictionary and not card.effects.is_empty(),
		note + " non-vacuous actual authored effects")
	for key in card.effects:
		var phrase := _oracle_effect_fragment(str(key), card.effects[key])
		_check(not phrase.is_empty() and effects.contains(phrase),
			note + " describes authentic " + str(key) + " = " + str(card.effects[key]))
	_check(not effects.contains("Undescribed"), note + " every actual base effect has a clause")
	var clip := picker.inspection_panel.get_global_rect()
	var text_stack: Array[Control] = [picker.inspection_heading, picker.inspection_facts,
		picker.kit_card_heading, picker.kit_target, picker.kit_effects, picker.kit_previous,
		picker.kit_next, picker.kit_back]
	for node in text_stack:
		_check(node.is_visible_in_tree() and clip.encloses(node.get_global_rect()),
			note + " inspector control inside panel: " + node.name)
	_check(picker.kit_effects.get_visible_line_count() == picker.kit_effects.get_line_count()
		and picker.kit_target.get_visible_line_count() == picker.kit_target.get_line_count(),
		note + " target/effect wrapped text not vertically clipped")
	_check(picker.kit_effects.get_theme_font_size("font_size") >= 16
		and picker.kit_card_heading.get_theme_font_size("font_size") >= 16,
		note + " readable effect/card typography")
	_check(picker.selected_ids().is_empty() and picker._seat_receipt.is_empty(),
		note + " per-card preview cannot admit a party")


func _check_all_kits(picker: LiveV3PartyPicker) -> void:
	var special_keys := {
		"lantern_monk": "cleanse_debuff", "rag_duelist": "move_self_forward",
		"scarecrow": "cannot_buff_next_turn", "yarn_ranger": "tangled",
		"button_golem": "block_per_button_popped"}
	var seen: Dictionary = {}
	var controls := [picker.inspect_cards_button, picker.kit_previous, picker.kit_next, picker.kit_back]
	for button in controls:
		_check(button.focus_mode == Control.FOCUS_ALL,
			"real Inspect Cards and navigation buttons accept keyboard focus")
	for hero_id in ORDER:
		var actual: Array[String] = _source_deck(hero_id)
		_check(actual.size() == 4, hero_id + " four actual source deck occurrences")
		if actual.size() != 4:
			continue
		# Repeated legacy IDs are separate physical steps, never deduplicated.
		var copies: Dictionary = {}
		for id in actual:
			copies[id] = int(copies.get(id, 0)) + 1
		if hero_id in ["warden", "seamstress", "tinker"]:
			_check(copies.values().has(2), hero_id + " duplicated starter is traversable twice")
		# A mouse hover or keyboard focus drives the actual UI, not the helper.
		await _key_focus(_tile(picker, hero_id))
		await _key(picker.inspect_cards_button, KEY_ENTER)
		_check(picker._kit_mode and not picker.inspect_cards_button.disabled
			and picker.kit_previous.disabled and not picker.kit_next.disabled,
			hero_id + " real keyboard Inspect Cards opens at first copy")
		for index in range(actual.size()):
			_check_kit_occurrence(picker, hero_id, index, actual[index],
				hero_id + " card %d" % (index + 1))
			var record: Dictionary = _source_catalog(hero_id).get_definition(actual[index])
			for key in record.effects:
				seen[hero_id + "/" + str(key)] = true
			if index < actual.size() - 1:
				await _key(picker.kit_next, KEY_ENTER)
		_check(picker.kit_next.disabled and not picker.kit_previous.disabled,
			hero_id + " last occurrence stops Next")
		var last := picker.kit_card_heading.text
		picker.kit_next.pressed.emit()
		_check(picker.kit_card_heading.text == last and picker._kit_index == 3,
			hero_id + " refused Next never wraps")
		for index in range(2, -1, -1):
			await _key(picker.kit_previous, KEY_SPACE)
			_check_kit_occurrence(picker, hero_id, index, actual[index],
				hero_id + " backwards copy %d" % (index + 1))
		picker.kit_previous.pressed.emit()
		_check(picker._kit_index == 0, hero_id + " refused Previous never wraps")
		await _key(picker.kit_back, KEY_ENTER)
		_check(not picker._kit_mode and not picker.kit_readout.visible
			and picker.inspection_starters.visible,
			hero_id + " Back restores hero description and starter caption")
	for hero_id in special_keys:
		_check(seen.has(hero_id + "/" + special_keys[hero_id]),
			hero_id + " distinctive exotic effect came from actual card definition")
	for hero_id in ORDER:
		var first: String = _source_deck(hero_id)[0]
		_check(picker._kit_card_by_id(hero_id, first) == _source_catalog(hero_id).get_definition(first)
			and picker._kit_card_by_id(hero_id, first + "_plus").is_empty()
			and picker._kit_card_by_id(hero_id, "forged_card_id").is_empty(),
			hero_id + " base authentic; reward/upgrade/forged IDs fail closed")
	_check(picker._kit_card("warden", -1).is_empty()
		and picker._kit_card("warden", 4).is_empty()
		and picker._kit_card("nonexistent", 0).is_empty()
		and picker._kit_effect_clause("unsupported_effect_key", 9).contains("Undescribed"),
		"unrecognized source IDs, indexes and effects never fabricate valid previews")
	# A different tile really replaces the active kit hero and resets index.
	await _key_focus(_tile(picker, "warden"))
	await _mouse(picker.inspect_cards_button)
	await _key(picker.kit_next, KEY_ENTER)
	_check(picker._kit_index == 1, "mouse Inspect Cards and keyboard Next both work")
	await _move_to(_tile(picker, "yarn_ranger"))
	_check(picker._kit_mode and picker._kit_hero == "yarn_ranger" and picker._kit_index == 0
		and picker.kit_card_heading.text.contains(_source_catalog("yarn_ranger")
			.get_definition(_source_deck("yarn_ranger")[0]).display_name),
		"new hovered hero switches immediately to its first authentic starter")
	await _move_to(picker.get_node("PaperPanel/Margins/Body/SubTitle"))
	await _key_focus(_tile(picker, "button_golem"))
	_check(picker._kit_hero == "button_golem" and picker._kit_index == 0,
		"new keyboard-focused hero replaces hover kit without stale card")
	await _key(picker.kit_back, KEY_SPACE)
	_check(picker.selected_ids().is_empty(), "all source inspections keep selection empty")


## Independent source oracle for reward browsing. The expected list comes
## only from the stock API, not the picker's cached browse projection.
func _source_rewards(hero_id: String) -> Array[Dictionary]:
	var expected: Array[Dictionary] = []
	for candidate: Dictionary in RunPoolCardRewardOffers.get_authored_base_candidates():
		if candidate.get("owner") != hero_id:
			continue
		var card := RunPoolCardRewardOffers.resolve_reward_definition(candidate["id"])
		_check(not card.is_empty() and card.get("id") == candidate.get("id")
			and card.get("owner") == hero_id and card.get("rarity") == candidate.get("rarity")
			and (card.get("reward_eligible") == true or card.get("is_upgrade") == false)
			and card.get("starting_copies") == 0
			and not card.has("upgrade_of") and not str(card.get("id", "")).ends_with("_plus"),
			hero_id + " every published stock entry resolves to authentic base definition")
		if not card.is_empty():
			expected.append(card)
	return expected


## Source-driven wording checks keep the published catalog as the numeric
## oracle, while exercising the human explanation rather than raw JSON keys.
func _check_reward_effect_copy(expected: Dictionary, text_value: String, note: String) -> void:
	var effects: Dictionary = expected["effects"]
	var short_line := str(CardShortRules.describe(expected).get("line", "")).replace(
		CardShortRules.UNKNOWN_SENTENCE, "").strip_edges()
	if not short_line.is_empty():
		_check(text_value.contains(short_line), note + " audited short rules retained")
	for key in effects:
		var amount: Variant = effects[key]
		match str(key):
			"damage", "block", "block_all", "heal", "weak", "bleed", "exposed", \
					"unravel", "tangled", "draw", "thorns", "riposte", "energy", \
					"gain_energy", "self_hp_loss":
				if amount is int and amount > 0:
					_check(text_value.contains(str(amount)),
						note + " authentic positive " + str(key) + " amount")
			"heal_all":
				_check(text_value.contains("Heal each living ally %d HP" % amount),
					note + " party healing is visible")
			"cleanse_one_debuff_each_ally":
				_check(text_value.contains("Cleanse one debuff from each living ally"),
					note + " party cleanse visible")
			"move_self_forward":
				_check(text_value.contains("Move yourself %d position(s)" % amount),
					note + " lunge destination visible")
			"pull_forward":
				_check(text_value.contains("Pull the foe %d position(s)" % amount),
					note + " hooked foe movement visible")
			"max_hp_loss":
				_check(text_value.contains("First lose %d maximum HP" % amount),
					note + " max HP loss before healing")
			"require_owner_block":
				_check(text_value.contains("Requires at least %d" % amount),
					note + " Block eligibility before hit")
			"spend_owner_block":
				_check(text_value.contains("Spend %d" % amount),
					note + " Block spend after prerequisite")
			"buttons_popped_gain":
				_check(text_value.contains("%d additional popped button" % amount),
					note + " successful button gain")
			"swap_with_target_ally":
				_check(text_value.contains("Swap positions with the chosen living ally"),
					note + " chosen-ally swap")
			"block_per_button_popped":
				_check(text_value.contains("Gain %d Block for each button previously popped" % amount),
					note + " non-consuming Block scaling")
			"damage_per_button_popped":
				_check(text_value.contains("Deal %d damage per button previously popped" % amount),
					note + " non-consuming damage scaling")
			"requires_target_status":
				_check(text_value.contains("Only affects foes already Tangled"),
					note + " Unspool condition precedes damage")
				_check(text_value.find("Only affects") < text_value.find("Deal"),
					note + " conditional damage is never advertised first")
			"independent_hits":
				_check(text_value.contains("Each hit resolves independently"),
					note + " independent hit condition")
			"duration":
				_check(text_value.contains("Lasts "), note + " authored duration")
			"conditional_damage":
				_check(amount is Dictionary and text_value.contains(
					"Empowered hit: %d damage" % amount.get("damage", -1))
					and text_value.contains("Unravelled OR")
					and text_value.contains("at least half the current threshold"),
					note + " all nested Snip predicates and alternative amount")
			"pinned":
				if amount is Dictionary:
					_check(text_value.contains("different hero gains 5 damage")
						and text_value.contains("before Weak/Exposed")
						and text_value.contains("same hero does not consume"),
						note + " nested Pin trigger, timing and one-time consumption")
			"living_targets_only":
				_check(text_value.contains("Only living foes"), note + " living-only restriction")
			"random_target_each_hit":
				_check(text_value.contains("fresh random living foe for each hit"),
					note + " independent RNG target per hit")


func _check_reward_entry(picker: LiveV3PartyPicker, hero_id: String,
		index: int, expected: Dictionary) -> void:
	var note := hero_id + " reward " + str(index + 1)
	_check(picker._reward_mode and not picker._kit_mode and not picker._deck_mode
		and picker._kit_hero == hero_id and picker._reward_index == index
		and picker.reward_readout.is_visible_in_tree() and not picker.kit_readout.visible,
		note + " independent Reward Cards mode is mounted")
	_check(picker._reward_card(hero_id, index) == expected,
		note + " exact unaltered published definition")
	_check(picker.reward_heading.text == "REWARD %d / %d  •  %s  •  %s  •  %d EN" % [
			index + 1, picker._reward_candidates.size(), expected["display_name"],
			String(expected["rarity"]).capitalize(), expected["cost"]],
		note + " genuine name, rarity, energy and actual pool index")
	_check(picker.reward_identity.text == "Owner: %s  •  Published card preview" % NAMES[ORDER.find(hero_id)],
		note + " named owner and honest preview, no raw identity")
	var from: Array[String] = []
	var to: Array[String] = []
	for slot in expected["from_positions"]:
		from.append("%s (%d)" % [POSITION_NAMES[slot - 1], slot])
	for slot in expected["to_positions"]:
		to.append("%s (%d)" % [POSITION_NAMES[slot - 1], slot])
	var recipient := ""
	match expected["target_kind"]:
		"enemy_single":
			recipient = "one foe in " + ", ".join(to)
		"enemy_all":
			recipient = "all living foes in " + ", ".join(to)
		"enemy_back":
			recipient = "backmost living foe (in " + ", ".join(to) + ")"
		"enemy_random":
			recipient = "a random living foe per hit (in " + ", ".join(to) + ")"
		"self":
			recipient = "yourself"
		"ally_single":
			recipient = "one chosen living ally"
		"party_all":
			recipient = "your whole living party"
		"none":
			recipient = "no target"
	_check(picker.reward_target.text == "Play from %s  •  Target: %s" % [
		", ".join(from), recipient],
		note + " authentic battle positions and human target kind")
	var effects: String = picker.reward_effects.text
	_check(expected["effects"] is Dictionary and not expected["effects"].is_empty()
		and not effects.is_empty() and not effects.contains("Printed rules:")
		and not effects.contains("Authored effect fields")
		and not effects.contains("printed intent")
		and not effects.contains("JSON")
		and not effects.contains("target_kind")
		and not effects.contains(str(expected["id"]))
		and not picker.reward_identity.text.contains(str(expected["id"]))
		and not picker.reward_target.text.contains("slots"),
		note + " player-facing wording without developer field dump or card ID")
	_check_reward_effect_copy(expected, effects, note)
	_check(effects == picker.reward_effects.tooltip_text
		and picker.reward_target.tooltip_text == picker.reward_target.text
		and picker.reward_identity.tooltip_text == picker.reward_identity.text,
		note + " full target and effects in tooltips")
	_check(picker.reward_scroll.focus_mode == Control.FOCUS_ALL
		and picker.reward_scroll.get_v_scroll_bar() != null
		and picker.reward_scroll.size.y >= 40,
		note + " keyboard and scrolling still available")
	var clip := picker.inspection_panel.get_global_rect()
	_check(clip.encloses(picker.reward_readout.get_global_rect())
		and clip.encloses(picker.reward_heading.get_global_rect())
		and clip.encloses(picker.reward_identity.get_global_rect())
		and clip.encloses(picker.reward_target.get_global_rect())
		and clip.encloses(picker.reward_scroll.get_global_rect())
		and clip.encloses(picker.reward_back.get_global_rect()),
		note + " all reward controls stay inside existing 1280x720 inspection area")
	_check(picker.selected_ids().is_empty() and picker._seat_receipt.is_empty(),
		note + " reward inspection never selects heroes or makes a deck")


func _check_all_rewards(picker: LiveV3PartyPicker) -> void:
	var controls: Array[Button] = [picker.reward_cards_button,
		picker.reward_previous, picker.reward_next, picker.reward_back]
	for button in controls:
		_check(button.focus_mode == Control.FOCUS_ALL
			and picker.get_node("PaperPanel").get_global_rect().encloses(button.get_global_rect()),
			"Reward Cards entry and navigation are genuinely reachable at 1280x720")
	var witnesses := {
		"warden": "warden_hold_the_line",
		"seamstress": "seamstress_running_stitch",
		"tinker": "tinker_rivet_shot",
		"lantern_monk": "lantern_monk_wick_flicker",
		"rag_duelist": "rag_duelist_needle_prick",
		"scarecrow": "scarecrow_pitchfork_prick",
		"yarn_ranger": "yarn_ranger_needle_arrow",
		"button_golem": "button_golem_pop_button",
	}
	var run_rng := RandomNumberGenerator.new()
	run_rng.seed = 839121
	var state: int = run_rng.state
	var before_signals := [requests.size(), cancels]
	for hero_id in ORDER:
		var expected := _source_rewards(hero_id)
		var ids: Array[String] = []
		for card in expected:
			ids.append(card["id"])
		_check(not ids.is_empty() and ids.has(witnesses[hero_id]),
			hero_id + " stock contains earlier authored base printing, not fixed total")
		var unique_ids := {}
		for id in ids:
			unique_ids[id] = true
		_check(ids.size() == unique_ids.size()
			and not ids.has(_source_deck(hero_id)[0]),
			hero_id + " reward stock is separate from starter occurrences")
		await _key_focus(_tile(picker, hero_id))
		_check(not picker.reward_cards_button.disabled,
			hero_id + " genuine tile focus enables Reward Cards")
		if hero_id == "seamstress" or hero_id == "button_golem":
			await _mouse(picker.reward_cards_button)
		else:
			await _key(picker.reward_cards_button, KEY_ENTER)
		_check(picker._reward_mode and picker._reward_candidates.size() == ids.size()
			and picker.reward_previous.disabled and not picker.reward_back.disabled,
			hero_id + " mouse / keyboard opens real catalog count from first entry")
		var seen: Array[String] = []
		for index in range(expected.size()):
			_check_reward_entry(picker, hero_id, index, expected[index])
			if hero_id == "tinker" and expected[index]["id"] == "tinker_snip_the_seam":
				# Long nested conditions must be genuinely reachable with scroll,
				# both at pointer position and through focused keyboard input.
				await _frames()
				var bar := picker.reward_scroll.get_v_scroll_bar()
				_check(bar.max_value > bar.page,
					"long conditional Reward Cards prose overflows into scrolling")
				var mouse_move := InputEventMouseMotion.new()
				mouse_move.position = picker.reward_scroll.get_global_rect().get_center()
				root.push_input(mouse_move, true)
				var wheel := InputEventMouseButton.new()
				wheel.position = mouse_move.position
				wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
				wheel.pressed = true
				root.push_input(wheel, true)
				await _frames()
				_check(picker.reward_scroll.scroll_vertical > 0,
					"real mouse-wheel scroll reveals the long nested rule")
				picker.reward_scroll.scroll_vertical = 0
				picker.reward_scroll.grab_focus()
				var pagedown := InputEventKey.new()
				pagedown.keycode = KEY_PAGEDOWN
				pagedown.pressed = true
				root.push_input(pagedown, true)
				await _frames()
				_check(picker.reward_scroll.scroll_vertical > 0,
					"focused keyboard PageDown scrolls the Reward Cards explanation")
			seen.append(picker._reward_candidates[picker._reward_index]["id"])
			if index + 1 < expected.size():
				if hero_id == "seamstress" and index == 0:
					await _mouse(picker.reward_next)
				else:
					await _key(picker.reward_next, KEY_ENTER)
		var got := seen.duplicate()
		got.sort()
		var want := ids.duplicate()
		want.sort()
		_check(got == want, hero_id + " complete browse ID set equals published base candidates")
		_check(picker.reward_next.disabled and not picker.reward_previous.disabled,
			hero_id + " Next cannot wrap past last real card")
		var final_id: String = picker.reward_identity.text
		picker.reward_next.pressed.emit()
		_check(picker.reward_identity.text == final_id
			and picker._reward_index == expected.size() - 1,
			hero_id + " stale Next never wraps")
		for index in range(expected.size() - 2, -1, -1):
			if hero_id == "button_golem" and index == expected.size() - 2:
				await _mouse(picker.reward_previous)
			else:
				await _key(picker.reward_previous, KEY_SPACE)
			_check_reward_entry(picker, hero_id, index, expected[index])
		picker.reward_previous.pressed.emit()
		_check(picker._reward_index == 0, hero_id + " Previous cannot wrap")
		if hero_id == "tinker":
			await _mouse(picker.reward_back)
		else:
			await _key(picker.reward_back, KEY_ENTER)
		_check(not picker._reward_mode and not picker.reward_readout.visible
			and picker.inspection_starters.visible,
			hero_id + " Back exits reward browse without selecting hero")
	# The formatter also fails closed for new effect descriptors and altered
	# nested predicates, without mutating the genuine catalog definition.
	var snip := RunPoolCardRewardOffers.resolve_reward_definition("tinker_snip_the_seam")
	var pristine := snip.duplicate(true)
	_check(not snip.is_empty() and snip["effects"].has("conditional_damage"),
		"genuine Snip nested-effect fixture exists")
	var unknown := snip.duplicate(true)
	unknown["effects"]["unmapped_spell"] = {"when": [{"mystery": 17}]}
	var unknown_text: String = picker._reward_effect_line(unknown)
	_check(unknown_text.contains("Some authored effect details are not fully described.")
		and not unknown_text.contains("unmapped_spell")
		and not unknown_text.contains("mystery")
		and not unknown_text.contains("{"),
		"unknown nested effect is not shown as raw JSON or promised gameplay")
	var changed_condition := snip.duplicate(true)
	changed_condition["effects"]["conditional_damage"]["operator"] = "and"
	var changed_text: String = picker._reward_effect_line(changed_condition)
	_check(changed_text.contains("Some authored effect details are not fully described.")
		and not changed_text.contains("Empowered hit:"),
		"altered nested predicate does not borrow the canonical empowered claim")
	_check(snip == pristine
		and RunPoolCardRewardOffers.resolve_reward_definition("tinker_snip_the_seam") == pristine,
		"test and browser keep original resolved source definitions unchanged")
	_check(run_rng.state == state and [requests.size(), cancels] == before_signals
		and picker.selected_ids().is_empty(),
		"reward browse rolls no supplied run RNG and emits no request/cancel")
	# An invalid candidate/definition fails closed instead of using a cached
	# card from another owner. Check while the scene is still mounted.
	await _key_focus(_tile(picker, "warden"))
	await _key(picker.reward_cards_button, KEY_ENTER)
	var candidates := picker._reward_candidates.duplicate(true)
	for invalid in [
		{"id": "unknown_card_id", "owner": "warden", "rarity": "common"},
		{"id": "seamstress_running_stitch", "owner": "warden", "rarity": "common"},
		{"id": "warden_hold_the_line_plus", "owner": "warden", "rarity": "common"}
	]:
		picker._reward_candidates.assign([invalid])
		picker._reward_index = 0
		picker._update_inspection()
		_check(picker.reward_heading.text.contains("Unavailable")
			and picker.reward_effects.text.contains("Unavailable")
			and not picker.reward_identity.text.contains("seamstress"),
			"unknown, foreign-owner, plus reward lookup displays Unavailable")
	picker._reward_candidates = candidates
	picker._update_inspection()
	_check_reward_entry(picker, "warden", 0, _source_rewards("warden")[0])
	# Switch inspected owner during browsing, then retire the mode through
	# Back; the old hero and its callbacks cannot leak across hover/focus.
	await _move_to(_tile(picker, "scarecrow"))
	_check(picker._kit_hero == "scarecrow" and picker._reward_index == 0
		and picker.reward_identity.text.contains("Owner: Scarecrow"),
		"hover switches reward browse to new owner and resets index")
	await _key(picker.reward_back, KEY_SPACE)
	_check(not picker._reward_mode and picker._reward_candidates.is_empty()
		and picker.selected_ids().is_empty(),
		"Reward Back clears catalog state without making a pick")
	await _move_to(picker.get_node("PaperPanel/Margins/Body/SubTitle"))


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
	await _check_all_kits(picker)
	await _check_all_rewards(picker)

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
	var admitted_before_rewards := picker._seat_receipt.duplicate(true)
	await _key(picker.reward_cards_button, KEY_ENTER)
	_check(picker._reward_mode and picker.reward_readout.visible
		and picker._kit_hero == "tinker", "three-picked party can inspect Tinker's rewards")
	await _key(picker.reward_next, KEY_SPACE)
	_check(picker._reward_index == 1
		and picker._seat_receipt == admitted_before_rewards
		and picker.selected_ids() == ["warden", "seamstress", "tinker"]
		and not action.disabled and requests.is_empty(),
		"reward Next leaves canonical selected party, Continue gate, deck and signals untouched")
	await _key(picker.reward_back, KEY_ENTER)
	await _key(deck_button, KEY_SPACE)
	_check_deck_rows(picker, ["warden", "seamstress", "tinker"], "legacy three seat deck via keyboard")
	_check(deck_view.get_node("DeckScroll/DeckRows/DeckSeat1").text.contains("1 EN Strike x2")
		and deck_view.get_node("DeckScroll/DeckRows/DeckSeat2").text.contains("1 EN Prick x2"),
		"genuine legacy duplicate starters count exactly twice, not collapsed or repeated")
	_check(requests.is_empty() and cancels == 0, "Inspect Deck fires no run or cancel signals")
	picker.inspect_cards_button.pressed.emit()
	picker.reward_cards_button.pressed.emit()
	_check(deck_view.visible and not picker._reward_mode,
		"Reward Cards cannot replace the combined deck while it is open")
	_check(deck_view.visible and not picker._kit_mode,
		"Inspect Cards refuses to replace an active combined-deck receipt")
	await _mouse(deck_button)
	_check(not deck_view.visible and deck_button.text == "Inspect Deck",
		"pointer Back restores hero inspection mode")
	await _move_to(_tile(picker, "warden"))
	_check_inspection(picker, "Warden", "HELMET", "Bulwark", "Guard",
		"Back restores original hover details")
	await _key(picker.inspect_cards_button, KEY_ENTER)
	await _key(picker.kit_next, KEY_ENTER)
	_check(picker._kit_mode and picker._kit_index == 1
		and picker._seat_receipt.get("ok", false) and picker.selected_ids() == ["warden", "seamstress", "tinker"],
		"one-hero card navigation retains admitted three-hero selection/receipt")
	await _key(deck_button, KEY_ENTER)
	_check(deck_view.visible and not picker.kit_readout.visible and not picker._kit_mode,
		"Inspect Deck replaces per-card view without losing source receipt")
	_check_deck_rows(picker, ["warden", "seamstress", "tinker"],
		"combined receipt from individual card kit")
	await _key(deck_button, KEY_SPACE)
	_check(not deck_view.visible and not picker._kit_mode,
		"Back from shared deck restores normal hero readout")
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
	picker.reward_cards_button.pressed.emit()
	picker.reward_next.pressed.emit()
	picker.reward_back.pressed.emit()
	_check(not picker._reward_mode and not picker.reward_readout.visible
		and picker.reward_cards_button.disabled,
		"latched Continue disables reward entry and stale browse callbacks")
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
	_check(_readout(picker)[0].contains("HOVER OR FOCUS")
		and not picker._reward_mode and picker._reward_candidates.is_empty()
		and not picker.reward_readout.visible,
		"retired hovered / focused / pressed tile cannot overwrite fresh reward inspection")
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
	await _key(picker.inspect_cards_button, KEY_ENTER)
	await _key(picker.kit_next, KEY_SPACE)
	_check(picker._kit_mode and picker._kit_index == 1,
		"Cancel case starts from an actual nonfirst Scarecrow kit card")
	await _key(picker.reward_cards_button, KEY_ENTER)
	await _key(picker.reward_next, KEY_SPACE)
	_check(picker._reward_mode and picker._reward_index == 1
		and picker.reward_identity.text.contains("Owner: Scarecrow"),
		"Cancel case also visits nonfirst actual Scarecrow reward")
	await _key(cancel, KEY_ENTER)
	_check(cancels == 1 and requests.size() == 1,
		"Cancel emits only cancel_requested")
	_check(not picker.visible and cancel.disabled and not picker._kit_mode
		and not picker.kit_readout.visible and picker.inspect_cards_button.disabled
		and not picker._reward_mode and picker._reward_candidates.is_empty()
		and not picker.reward_readout.visible and picker.reward_cards_button.disabled,
		"Cancel closes/latches view and clears selected kit")
	picker.kit_next.pressed.emit()
	picker.inspect_cards_button.pressed.emit()
	picker.reward_next.pressed.emit()
	picker.reward_back.pressed.emit()
	picker.reward_cards_button.pressed.emit()
	_check(not picker._kit_mode and not picker._reward_mode, "retired kit navigation cannot reopen on Cancel")
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
	_check(_readout(picker)[0].contains("HOVER OR FOCUS")
		and picker._kit_hero.is_empty() and not picker._kit_mode
		and not picker._reward_mode and picker._reward_candidates.is_empty(),
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
	# An incomplete real receipt must clear every previously printed fact,
	# card and rule, even if an old combined inspection is currently visible.
	var intact_receipt: Dictionary = picker._seat_receipt.duplicate(true)
	picker._seat_receipt["deck"].pop_back()
	picker._update_inspection()
	_check(not deck_view.visible and deck_button.disabled and action.disabled
		and picker.deck_shared_note.text.is_empty()
		and picker.deck_rows[0].text.is_empty() and picker.deck_facts[0].text.is_empty()
		and picker.deck_facts[2].tooltip_text.is_empty(),
		"incomplete admission retires all shared rules, names, cards and facts")
	var prior_requests := requests.size()
	picker._continue_pressed()
	_check(requests.size() == prior_requests, "incomplete receipt cannot dispatch Continue")
	picker._seat_receipt = intact_receipt
	picker._refresh()
	await _mouse(deck_button)
	_check_deck_rows(picker, ["button_golem", "lantern_monk", "scarecrow"],
		"restored canonical receipt can be inspected again")
	var intact_sources: Dictionary = picker._canonical_heroes.duplicate(true)
	picker._canonical_heroes.erase("scarecrow")
	picker._update_inspection()
	_check(not deck_view.visible and deck_button.disabled and action.disabled
		and picker.deck_shared_note.text.is_empty()
		and picker.deck_facts[1].text.is_empty() and picker.deck_rows[2].tooltip_text.is_empty(),
		"missing authenticated facts retires combined readout without fabricated HP")
	picker._continue_pressed()
	_check(requests.size() == prior_requests, "missing canonical source cannot dispatch")
	picker._canonical_heroes = intact_sources
	picker._refresh()
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
