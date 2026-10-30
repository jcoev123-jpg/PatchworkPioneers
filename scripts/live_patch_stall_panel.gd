class_name LivePatchStallPanel
extends Control
## Presentation and source-bound intents only. Purchasing and sewing belong to a controller.
signal intent_requested(intent: Dictionary)

const PANEL_ART := "res://assets/paper/ui/reward_panel.png"
const CREAM := Color("#f3e6cf")
const GOLD := Color("#e9c47d")
const THREAD := Color("#b9a58d")
const PLUM := Color("#37293f")
const TEAL := Color("#214b50")
const OXBLOOD := Color("#713544")
const INK := Color("#191b2a")
const DIM := Color("#b6a9a2")
const PANEL_SIZE := Vector2(900, 630)
const DETAILS_UNAVAILABLE := "Power details unavailable"
# Canonical Leave caption for construction, refresh and authentication: the
# physical/keypad 0 alias must be visible on the honest button itself.
const LEAVE_CAPTION := "0 Leave  ·  FREE"
# Always-visible wearer header: sewing into an occupied authored slot destroys
# the patch already worn there. The visit carries no wardrobe, so this states
# the rule (and its +1 scrap) rather than guessing any hero's live loadout.
const WEARER_WARNING := "Choose wearer  ·  worn same-slot patch is destroyed (+1 scrap)"
const SLOT_WARNING := "%s slot: a patch already worn in this slot is destroyed for exactly +1 scrap.\nA free %s slot destroys nothing and gains no scrap."
# Compact second lines only: long, authenticated conditions appear in tooltips.
const SHORT_RULES := {
	"button_eye": "First successful attack/combat also gives Exposed 1",
	"pincushion_arm": "+1 damage on wearer's damaging cards",
	"switchback_button": "+2 Block once/turn after a different living hero's play",
	"quilted_coat": "+6 maximum HP",
	"padded_vest": "+4 maximum HP",
	"double_quilt_coat": "+8 maximum HP",
	"scrap_lined_vest": "+3 maximum HP",
	"wool_patch_cloak": "+5 maximum HP",
	"chain_stitched_coat": "+7 maximum HP",
	"reinforced_patchcoat": "+9 maximum HP",
	"thick_felt_mantle": "+10 maximum HP",
	"bloodstitch_bonnet": "+1 Bleed on wearer's eligible Bleed cards",
	"button_glass_visor": "+1 Exposed on wearer's eligible Exposed cards",
	"stern_seam_cap": "+1 Weak on wearer's eligible Weak cards",
	"reinforced_browband": "+2 Block on wearer's eligible Block cards",
	"hemguard_cuff": "+2 Block on wearer's eligible Block cards",
	"threadguard_wrap": "+1 Block on wearer's cards already granting Block",
	"red_bobbin_cuff": "+1 Bleed on wearer's eligible Bleed cards",
	"loose_thread_glove": "+1 Unravel on wearer's eligible Unravel cards",
	"frayfinder_mitt": "+2 first single-target hit at half Unravel, once/turn",
	"borrowed_button": "Ally's healing play gives wearer 3 Block once/combat",
}
# Identity and trigger fields are required before a rare preview can be shown.
# Stock price is still exclusively the service's quoted price.
const RARE_IDENTITIES := {
	"relay_bobbin": {
		"slot": "HEAD", "rarity": "rare",
		"effect": "different_hero_pinned_token_shared_energy",
		"trigger": "different_living_hero_consumes_pin_placed_by_wearer",
		"pin_must_be_placed_by_wearer": true, "consumer_must_be_living": true,
		"consumer_must_differ_from_wearer": true, "wearer_must_be_living": true,
		"wearer_must_be_untorn": true, "requires_confirmed_receipt": true,
		"shared_energy": 1, "shared_energy_cap": 3, "uses_per_combat": 1,
	},
	"hearth_lining": {
		"slot": "COAT", "rarity": "rare",
		"effect": "earned_quilt_bonus_wearer_heal",
		"trigger": "first_earned_quilt_bonus_in_combat",
		"requires_earned_bonus": true, "wearer_must_be_living": true,
		"wearer_must_be_untorn": true, "heal": 2,
		"heal_cap": "max_hp", "uses_per_combat": 1,
	},
}

class SewnBorder extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x < 24 or size.y < 24:
			return
		var r := Rect2(Vector2(9, 8), size - Vector2(18, 16))
		for y in [r.position.y, r.end.y]:
			draw_dashed_line(Vector2(r.position.x, y), Vector2(r.end.x, y), THREAD, 1.5, 8.0)
		for x in [r.position.x, r.end.x]:
			draw_dashed_line(Vector2(x, r.position.y), Vector2(x, r.end.y), THREAD, 1.5, 8.0)

var title_label: Label
var wallet_label: Label
var wearer_label: Label
var status_label: Label
var wearer_buttons: Array[Button] = []
var offer_buttons: Array[Button] = []
var leave_button: Button

var _visit: RunPatchStallVisit
var _source: Dictionary = {}
var _quoted: Dictionary = {}
var _slots: Dictionary = {}
var _descriptions: Dictionary = {}
var _epoch := 0
var _submitted := false
var _wearer_index := 0
var _connections: Dictionary = {} # Only view-owned Button.pressed -> Callable.

func _ready() -> void:
	size = PANEL_SIZE
	custom_minimum_size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backing := Panel.new()
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backing)
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backing.add_theme_stylebox_override("panel", _panel_style())
	backing.add_child(SewnBorder.new())
	title_label = _label("PATCH STALL    ✕    sewn power patches", Vector2(40, 24), Vector2(820, 48), 32, GOLD)
	wallet_label = _label("", Vector2(43, 76), Vector2(808, 36), 25, CREAM)
	wearer_label = _label(WEARER_WARNING, Vector2(43, 128), Vector2(760, 31), 22, GOLD)
	for i in range(3):
		wearer_buttons.append(_button("", Vector2(43 + i * 278, 165), Vector2(264, 57), TEAL, 22))
	for i in range(3):
		offer_buttons.append(_button("", Vector2(43, 239 + i * 99), Vector2(814, 90), OXBLOOD, 20))
	leave_button = _button(LEAVE_CAPTION, Vector2(43, 545), Vector2(814, 60), TEAL, 26)
	status_label = _label("", Vector2(43, 612), Vector2(814, 15), 12, DIM)
	_refresh()
	_focus_initial()

## The physical number keys are an alias for the four mounted Buttons: a valid
## press only forwards to that Button's own `pressed` signal, so keyboard,
## mouse, Tab and Enter share the one authenticated path and this handler never
## buys, leaves, spends or mints an intent of its own. It stays inert - and
## leaves the key to the rest of the game - when the panel is not open/visible,
## the GUI focus belongs elsewhere, the key is a release/echo/modified/unrelated
## one, or the addressed action is detached, hidden or disabled (sold or
## unaffordable).
func _input(event: InputEvent) -> void:
	if not _active():
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	# is_ancestor_of() needs a real node: with nothing focused (or focus on a
	# control outside this panel) no shortcut belongs to the Patch Stall.
	if focus_owner == null or (focus_owner != self and not is_ancestor_of(focus_owner)):
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.is_pressed() or key_event.is_echo():
		return
	if key_event.shift_pressed or key_event.alt_pressed or key_event.ctrl_pressed or key_event.meta_pressed:
		return

	var button: Button = null
	match key_event.keycode:
		KEY_1, KEY_KP_1:
			button = offer_buttons[0]
		KEY_2, KEY_KP_2:
			button = offer_buttons[1]
		KEY_3, KEY_KP_3:
			button = offer_buttons[2]
		KEY_0, KEY_KP_0:
			button = leave_button

	if button == null:
		return
	# Only an authentic, still-mounted, visible and ENABLED action of this panel
	# may receive the key press. An unaffordable or sold row neither emits a
	# synthetic Button.pressed nor swallows the key from the rest of the game.
	if not _attached(button) or button.disabled:
		return
	get_viewport().set_input_as_handled()
	button.pressed.emit()

func _panel_style() -> StyleBox:
	if ResourceLoader.exists(PANEL_ART, "Texture2D"):
		var texture := ResourceLoader.load(PANEL_ART) as Texture2D
		if texture != null:
			var style := StyleBoxTexture.new()
			style.texture = texture
			style.modulate_color = Color("#635264")
			style.set_texture_margin_all(24)
			return style
	return _style(PLUM, THREAD, 5)

func _style(fill: Color, edge: Color, width: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(8)
	return style

func _label(value: String, at: Vector2, extent: Vector2, font_size: int, ink: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = extent
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ink)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 2)
	add_child(label)
	return label

func _button(value: String, at: Vector2, extent: Vector2, fill: Color, font_size: int) -> Button:
	var button := Button.new()
	button.text = value
	button.position = at
	button.size = extent
	button.custom_minimum_size = extent
	button.focus_mode = Control.FOCUS_ALL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, CREAM)
	button.add_theme_color_override("font_disabled_color", DIM)
	button.add_theme_stylebox_override("normal", _style(fill, INK))
	button.add_theme_stylebox_override("hover", _style(fill.lightened(0.13), GOLD))
	button.add_theme_stylebox_override("pressed", _style(fill.darkened(0.12), GOLD))
	button.add_theme_stylebox_override("disabled", _style(PLUM, DIM))
	var focus := _style(Color.TRANSPARENT, GOLD, 4)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)
	add_child(button)
	button.add_child(SewnBorder.new())
	return button

## A valid bind captures both independently returned service receipts; no prices
## or identities can be supplied separately by the caller.
func bind(visit: RunPatchStallVisit) -> void:
	_epoch += 1
	_retire_callbacks()
	_visit = null
	_source = {}
	_quoted = {}
	_slots = {}
	_descriptions = {}
	_submitted = false
	_wearer_index = 0
	if visit != null and visit.is_valid() and not visit.is_consumed():
		var state: Dictionary = visit.read_state()
		var quote: Dictionary = visit.quote()
		var powers := RunAuthoredPatchDefinitions.load_power_definitions()
		var slots: Dictionary = {}
		for record in powers:
			if typeof(record) == TYPE_DICTIONARY and record.has("id") and record.has("slot"):
				slots[record["id"]] = record["slot"]
		if _valid_receipts(state, quote, slots):
			_visit = visit
			_source = state.duplicate(true)
			_quoted = quote.duplicate(true)
			_slots = slots.duplicate(true)
			_descriptions = _trusted_power_previews(_slots)
	if is_node_ready():
		show()
		_refresh()
		_focus_initial()

func close() -> void:
	bind(null)
	hide()

func _valid_receipts(state: Dictionary, quote: Dictionary, slots: Dictionary) -> bool:
	if state.get("status") != "available" or typeof(state.get("node_id")) != TYPE_STRING \
			or typeof(state.get("visit_id")) != TYPE_STRING \
			or str(state["node_id"]).strip_edges().is_empty() \
			or str(state["visit_id"]).strip_edges().is_empty():
		return false
	var snapshot: Variant = state.get("snapshot")
	if typeof(snapshot) != TYPE_DICTIONARY or typeof(snapshot.get("party_ids")) != TYPE_ARRAY \
			or snapshot["party_ids"].size() != 3 or typeof(snapshot.get("deck_ids")) != TYPE_ARRAY \
			or typeof(snapshot.get("owned_trinkets")) != TYPE_ARRAY \
			or typeof(snapshot.get("gold")) != TYPE_INT or snapshot["gold"] < 0:
		return false
	var seen_party := {}
	for hero in snapshot["party_ids"]:
		if typeof(hero) != TYPE_STRING or hero.strip_edges().is_empty() or seen_party.has(hero):
			return false
		seen_party[hero] = true
	if quote.get("decisions") != ["buy_patch", "leave"] or typeof(quote.get("offers")) != TYPE_ARRAY \
			or quote["offers"].size() != 3:
		return false
	var seen := {}
	for record in quote["offers"]:
		if typeof(record) != TYPE_DICTIONARY:
			return false
		var id: Variant = record.get("id")
		var price: Variant = record.get("price")
		if typeof(id) != TYPE_STRING or id.strip_edges().is_empty() or seen.has(id) \
				or not slots.has(id) or not slots[id] in ["HEAD", "ARM", "COAT"] \
				or typeof(price) != TYPE_INT or price < 0 or record.get("sold") != false \
				or snapshot["owned_trinkets"].has(id):
			return false
		seen[id] = true
	return true

func _source_current() -> bool:
	if _visit == null or _submitted or not _visit.is_valid() or _visit.is_consumed() \
			or _source.is_empty() or _quoted.is_empty():
		return false
	return _visit.read_state() == _source and _visit.quote() == _quoted \
			and _valid_receipts(_source, _quoted, _slots)

func _active() -> bool:
	return is_inside_tree() and is_visible_in_tree() and _source_current()

func _name(id: String) -> String:
	return id.replace("_", " ").capitalize()

func _wallet_caption() -> String:
	return "Wallet    ✕    %d gold" % int(_source["snapshot"]["gold"])

func _wearer_caption(i: int) -> String:
	var id: String = _source["snapshot"]["party_ids"][i]
	return ("✕  " if _wearer_index == i else "·  ") + _name(id)

## Only publish text after both the power-only ID/slot projection and the
## existing per-effect catalog audit agree. Unknown future powers remain neutral.
## The optional inputs allow tests to supply contradictory records without
## editing the shipped files or undermining source quote validation.
func _trusted_power_previews(slots: Dictionary, catalogs: Dictionary = {},
		rare_source: Variant = null) -> Dictionary:
	var verified: Dictionary = RunPatchWearerSummary._authority(catalogs)
	var known_slots: Dictionary = verified.get("slots", {})
	var previews: Dictionary = {}
	for id in slots:
		if RARE_IDENTITIES.has(id) or not SHORT_RULES.has(id) 				or not known_slots.has(id) or slots[id] != known_slots[id]:
			continue
		var full: String = RunPatchWearerSummary._resolve_rules_text(id, known_slots)
		if not full.is_empty():
			previews[id] = {"short": SHORT_RULES[id], "full": full}

	var rares: Variant = rare_source
	if rares == null:
		rares = JSON.parse_string(FileAccess.get_file_as_string(
				"res://data/patches/mpw_synergy_patches.json"))
	if typeof(rares) != TYPE_ARRAY:
		return previews
	var matched := {}
	var duplicates := {}
	for record in rares:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var id: Variant = record.get("id")
		if typeof(id) != TYPE_STRING or not RARE_IDENTITIES.has(id):
			continue
		if matched.has(id):
			duplicates[id] = true
			continue
		matched[id] = record
	for id in RARE_IDENTITIES:
		if duplicates.has(id) or not slots.has(id) or not matched.has(id) 				or slots[id] != RARE_IDENTITIES[id]["slot"]:
			continue
		var record: Dictionary = matched[id]
		var consistent := true
		for key in RARE_IDENTITIES[id]:
			if not record.has(key) or record[key] != RARE_IDENTITIES[id][key]:
				consistent = false
				break
		if not consistent:
			continue
		if id == "relay_bobbin":
			previews[id] = {
				"short": "+1 shared energy (cap 3) when ally uses your Pin, 1/combat",
				"full": "Once per combat, if a different living hero consumes a Pinned token placed by this living, untorn wearer (confirmed receipt), gain +1 shared energy, capped at 3."
			}
		elif id == "hearth_lining":
			previews[id] = {
				"short": "First earned Quilt bonus/combat heals wearer 2 HP",
				"full": "Once per combat, at the first EARNED Quilt bonus, heal this living, untorn wearer 2 HP, up to maximum HP."
			}
	return previews

func _offer_caption(i: int) -> String:
	var offer: Dictionary = _quoted["offers"][i]
	var id: String = offer["id"]
	var price: int = offer["price"]
	var shortfall: int = maxi(0, price - int(_source["snapshot"]["gold"]))
	var cost := "%d gold" % price if shortfall == 0 else "%d gold  ·  short %d" % [price, shortfall]
	var power: String = _descriptions.get(id, {}).get("short", DETAILS_UNAVAILABLE)
	return "%d  %s  [%s]  ✕ %s  ·  %s\n%s" % [i + 1, _name(id), id, _slots[id], cost, power]

func _offer_tooltip(i: int) -> String:
	var id: String = _quoted["offers"][i]["id"]
	var full: String = _descriptions.get(id, {}).get("full", DETAILS_UNAVAILABLE)
	return "%s [%s]\n%s\nPatch powers do not work while the wearer is Torn.\n%s" % [
		_name(id), id, full, SLOT_WARNING % [_slots[id], _slots[id]]]

func _retire_callbacks() -> void:
	for button in _connections:
		if is_instance_valid(button) and button.pressed.is_connected(_connections[button]):
			button.pressed.disconnect(_connections[button])
	_connections.clear()

func _attach(button: Button, callback: Callable) -> void:
	button.pressed.connect(callback)
	_connections[button] = callback

func _refresh() -> void:
	if title_label == null:
		return
	_retire_callbacks()
	var open := _source_current()
	wallet_label.text = _wallet_caption() if open else "Wallet unavailable"
	wearer_label.text = WEARER_WARNING if open else "Patch Stall unavailable"
	status_label.text = "Choose one patch or Leave.  ·  1-3 Buy / 0 Leave" if open else "No open quote."
	for i in range(3):
		var pin := wearer_buttons[i]
		var offer_button := offer_buttons[i]
		pin.disabled = not open
		pin.text = _wearer_caption(i) if open else ""
		pin.set_meta("wearer_id", _source["snapshot"]["party_ids"][i] if open else "")
		pin.add_theme_stylebox_override("normal", _style(OXBLOOD if open and i == _wearer_index else TEAL, GOLD if open and i == _wearer_index else INK))
		offer_button.text = _offer_caption(i) if open else ""
		offer_button.tooltip_text = _offer_tooltip(i) if open else ""
		offer_button.set_meta("patch_id", _quoted["offers"][i]["id"] if open else "")
		offer_button.disabled = not open or int(_source["snapshot"]["gold"]) < int(_quoted["offers"][i]["price"]) if open else true
		if open:
			_attach(pin, _choose_wearer.bind(i, pin, _epoch, _visit))
			_attach(offer_button, _request_patch.bind(i, offer_button, _epoch, _visit))
	leave_button.text = LEAVE_CAPTION
	leave_button.disabled = not open
	if open:
		_attach(leave_button, _request_leave.bind(_epoch, _visit))
	_wire_focus()

func _wire_focus() -> void:
	var focusables: Array[Button] = []
	for button in wearer_buttons + offer_buttons + [leave_button]:
		if not button.disabled:
			focusables.append(button)
	for i in range(focusables.size()):
		focusables[i].focus_next = focusables[i].get_path_to(focusables[(i + 1) % focusables.size()])
		focusables[i].focus_previous = focusables[i].get_path_to(focusables[(i + focusables.size() - 1) % focusables.size()])

func _focus_initial() -> void:
	if not is_inside_tree() or not _source_current():
		return
	if _leave_is_only_exit():
		leave_button.grab_focus()
		return
	wearer_buttons[0].grab_focus()

## True when none of the three authenticated quoted patches can be bought from
## the bound snapshot's gold and the free Leave button is mounted, visible and
## enabled: Enter on arrival must then address the only possible exit.
func _leave_is_only_exit() -> bool:
	if not _attached(leave_button) or leave_button.disabled:
		return false
	var gold := int(_source["snapshot"]["gold"])
	for offer in _quoted["offers"]:
		if gold >= int(offer["price"]):
			return false
	return true

func _auth(epoch: int, source: RunPatchStallVisit) -> bool:
	if epoch != _epoch or source == null or not is_same(source, _visit) or not _active():
		return false
	if title_label.text != "PATCH STALL    ✕    sewn power patches" \
			or wallet_label.text != _wallet_caption() or wearer_label.text != WEARER_WARNING \
			or leave_button.text != LEAVE_CAPTION:
		return false
	for i in range(3):
		if not _attached(wearer_buttons[i]) or wearer_buttons[i].disabled \
				or wearer_buttons[i].text != _wearer_caption(i) \
				or wearer_buttons[i].get_meta("wearer_id") != _source["snapshot"]["party_ids"][i]:
			return false
		if not _attached(offer_buttons[i]) or offer_buttons[i].text != _offer_caption(i) \
				or offer_buttons[i].get_meta("patch_id") != _quoted["offers"][i]["id"] \
				or offer_buttons[i].tooltip_text != _offer_tooltip(i) \
				or offer_buttons[i].disabled != (int(_source["snapshot"]["gold"]) < int(_quoted["offers"][i]["price"])):
			return false
	return _attached(leave_button) and not leave_button.disabled

func _attached(button: Button) -> bool:
	return is_instance_valid(button) and button.get_parent() == self \
			and button.is_inside_tree() and button.is_visible_in_tree()

func _choose_wearer(index: int, button: Button, epoch: int, source: RunPatchStallVisit) -> void:
	if not _auth(epoch, source) or index < 0 or index >= wearer_buttons.size() \
			or wearer_buttons[index] != button or button.disabled:
		return
	_wearer_index = index
	for i in range(3):
		wearer_buttons[i].text = _wearer_caption(i)
		wearer_buttons[i].add_theme_stylebox_override("normal",
			_style(OXBLOOD if i == index else TEAL, GOLD if i == index else INK))

func _request_patch(index: int, button: Button, epoch: int, source: RunPatchStallVisit) -> void:
	if not _auth(epoch, source) or index < 0 or index >= offer_buttons.size() \
			or button != offer_buttons[index] or button.disabled \
			or _wearer_index < 0 or _wearer_index >= 3:
		return
	var offer: Dictionary = _quoted["offers"][index]
	if int(_source["snapshot"]["gold"]) < int(offer["price"]):
		return
	_submit({
		"action": "buy_patch", "patch_id": offer["id"],
		"wearer_id": _source["snapshot"]["party_ids"][_wearer_index],
		"node_id": _source["node_id"], "visit_id": _source["visit_id"],
		"expected_snapshot": _source["snapshot"].duplicate(true),
	})

func _request_leave(epoch: int, source: RunPatchStallVisit) -> void:
	if not _auth(epoch, source):
		return
	_submit({
		"action": "leave", "node_id": _source["node_id"],
		"visit_id": _source["visit_id"],
		"expected_snapshot": _source["snapshot"].duplicate(true),
	})

func _submit(intent: Dictionary) -> void:
	_submitted = true
	for button in wearer_buttons + offer_buttons + [leave_button]:
		button.disabled = true
	_retire_callbacks()
	intent_requested.emit(intent.duplicate(true))
