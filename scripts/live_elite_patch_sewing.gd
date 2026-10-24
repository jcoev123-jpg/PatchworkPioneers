extends Node
## Post-claim presentation; the existing reward coordinator alone grants ownership.

var wardrobe: RunPatchWardrobe
var hero_buttons: Array[Button] = []
var summary: Label
## Mounted display hierarchy for the real free-sew offer: a compact sewn offer
## title, the short chooser caption and the three wearer actions. Every detailed
## rule and consequence stays in the 18 px body `_prompt` and the button tooltips.
var title_label: Label
var chooser_label: Label
var _heading_probed_path := ""
var _fallback_heading: Font = null
var _map: RunMap
var _rng: RandomNumberGenerator
var _choices: HBoxContainer
var _prompt: Label
var _claim_context: Array = []
var _service: RunMultiFightRewards
var _drop := ""
var _token := 0
var _bound_carry: RunTornCarryover
var _summary_inputs: Array = []

const INK := Color("302b29")
## The sewn display voice is the master Theme's already-shipped PatchHeading variation
## (Londrina Solid Regular). Only the compact offer title, the short chooser caption and
## the wearer actions use it; the authored rules stay in the body face. No new asset.
const HEADING_VARIATION := &"PatchHeading"
const HEADING_BUTTON_VARIATION := &"PatchHeadingButton"
const HEADING_FONT := "res://assets/fonts/LondrinaSolid-Regular.ttf"
const TITLE_FONT_SIZE := 24

const HERO_COLORS := {
    "warden": Color("4a5d73"),
    "seamstress": Color("6e4f6b"),
    "tinker": Color("c49a3a"),
}

## Sewn, readable names for every authored patch the sewing flow can display.
## Display text only: an entry never grants, changes or advertises a power (the
## authored catalog and `RunPatchWearerSummary` own the rules text). An unknown
## or future ID deliberately keeps its raw text instead of gaining a new name.
const FRIENDLY_LABELS := {
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

static func _friendly_label(id: String) -> String:
	return FRIENDLY_LABELS.get(id, id)


## A Theme's authored PatchHeading face, or null when that Theme merely falls back to
## its own body font. Read-only: the mounted Theme is never duplicated or edited.
static func heading_face(source: Theme) -> Font:
	if source == null:
		return null
	if not source.get_font_list(HEADING_VARIATION).has("font"):
		return null
	var face := source.get_font("font", HEADING_VARIATION)
	if face == null or face == source.default_font:
		return null
	return face


## The already-shipped Londrina Solid file that backs PatchHeading. An empty path or a
## missing file is null, so the caller keeps the mounted body face instead of a null font.
static func load_heading_font(path: String = HEADING_FONT) -> Font:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Font


## Sewn display lettering for one live label. A null face (fallback Theme without an
## authored PatchHeading and an unavailable file) leaves the readable body face in place.
static func apply_heading(label: Label, face: Font) -> void:
	if label == null:
		return
	label.theme_type_variation = HEADING_VARIATION
	if face != null:
		label.add_theme_font_override("font", face)


## Sewn display lettering for one live wearer action. Only the face changes: the
## existing cream paper styleboxes, dark ink and focus ring stay exactly as they are.
static func apply_heading_button(button: Button, face: Font) -> void:
	if button == null:
		return
	button.theme_type_variation = HEADING_BUTTON_VARIATION
	if face != null:
		button.add_theme_font_override("font", face)


## The nearest mounted Theme that really authors PatchHeading.
func inherited_theme() -> Theme:
	var node: Node = self
	while node != null:
		var mounted: Theme = null
		if node is Control:
			mounted = (node as Control).theme
		elif node is Window:
			mounted = (node as Window).theme
		if mounted != null and heading_face(mounted) != null:
			return mounted
		node = node.get_parent()
	return null


## Read-only display face for the offer title, chooser caption and wearer actions: the
## mounted shared Theme's PatchHeading face, else the committed Londrina Solid file.
func heading_font() -> Font:
	var mounted := inherited_theme()
	if mounted != null:
		var face := heading_face(mounted)
		if face != null:
			return face
	if HEADING_FONT != _heading_probed_path:
		_heading_probed_path = HEADING_FONT
		_fallback_heading = load_heading_font(HEADING_FONT)
	return _fallback_heading


class StitchedTag extends Control:
	var accent_color: Color = Color("c49a3a")
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)
	func _draw() -> void:
		var border_color := Color("302b29")
		var thread := Color("c9b996")
		# Draw stitched seams (dashed lines just inside border) — decorative only, no opaque fill
		var inner := Rect2(Vector2(8, 8), size - Vector2(16, 16))
		for y in [inner.position.y, inner.end.y - 1]:
			draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), thread, 1.5)
			# Small dashes for stitch effect
			for offset in range(0, int(inner.size.x), 6):
				var from_x: float = inner.position.x + offset
				var to_x: float = min(from_x + 3.0, inner.end.x)
				if to_x > from_x:
					draw_line(Vector2(from_x, y), Vector2(to_x, y), thread, 1.5)
		for x in [inner.position.x, inner.end.x - 1]:
			for offset in range(0, int(inner.size.y), 6):
				var from_y: float = inner.position.y + offset
				var to_y: float = min(from_y + 3.0, inner.end.y)
				if to_y > from_y:
					draw_line(Vector2(x, from_y), Vector2(x, to_y), thread, 1.5)
		# Pinned/button motif: small filled circle in accent color at top-left
		var pin_center := Vector2(16, 16)
		draw_circle(pin_center, 5, accent_color)
		# Small dark ring around pin
		draw_circle(pin_center, 7, border_color, false, 1.0)


func _ready() -> void:
	summary = Label.new()
	summary.name = "WornElitePatches"
	summary.position = Vector2(24, 2)
	summary.add_theme_font_size_override("font_size", 18)
	summary.size = Vector2(1232, 72)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child.call_deferred(summary)


func _process(_delta: float) -> void:
	_sync_run()
	if is_instance_valid(_choices):
		_choices.visible = _eligible()
		if _choices.visible:
			_wire_focus()
	_update_summary()


func _sync_run() -> void:
	var app = get_parent()
	if app.run_map != _map or app.run_rng != _rng:
		_clear_choices()
		if _bound_carry != null:
			_bound_carry.clear_wardrobe(wardrobe)
		_bound_carry = null
		wardrobe = null
		_summary_inputs.clear()
		_map = app.run_map
		_rng = app.run_rng
	if _map == null:
		summary.text = ""


func _clear_choices() -> void:
	_token += 1
	if is_instance_valid(_choices):
		_choices.queue_free()
	_choices = null
	_prompt = null
	title_label = null
	chooser_label = null
	hero_buttons.clear()
	_claim_context.clear()
	_service = null
	_drop = ""


func _context() -> Array:
	var app = get_parent()
	if app.run_map == null:
		return []
	return [app.run_map, app.run_rng, app.run_rng.state, app.run_seed,
		app.run_map.get_generation_revision(), app.run_map.get_floors(), app.run_map.get_route(),
		app.battle_view, app.battle_result, app.party, app.enemies,
		app.party.get_heroes(), app.enemies.get_enemies(), app.run_heroes.duplicate(true),
		app.run_trinkets.duplicate(), app.run_scraps, app.session_gold, app.run_deck.duplicate(),
		app.party_carryover.read_state(), app.multi_fight_rewards,
		app.multi_fight_rewards.read_state() if app.multi_fight_rewards != null else {}]


func observe_claim(offering, result: Dictionary) -> void:
	_sync_run()
	var app = get_parent()
	if not offering is RunMultiFightRewards or offering != app.multi_fight_rewards \
		or not result.get("ok", false) or not result.get("receipt") is Dictionary:
		return
	var receipt: Dictionary = result.receipt
	if not _confirmed(offering) or receipt.get("node_id") != _map.get_current_node_id() \
		or receipt.get("node_kind") != "Elite":
		return
	var drop: Variant = receipt.get("trinket_drop_id")
	if not drop is String or not app.run_trinkets.has(drop):
		return
	# A receipt is accepted once per actual coordinator; repeated observation cannot
	# refresh the guard or invalidate a player's already captured selection.
	if offering == _service:
		return
	var definitions: Array = RunAuthoredPatchDefinitions.load_definitions()
	if definitions.is_empty():
		return
	var carry := app.party_carryover as RunTornCarryover
	if carry == null or (_bound_carry != null and carry._wardrobe != null and wardrobe != carry._wardrobe):
		return
	# An earlier skipped Elite may have an unbound, unworn presentation ledger.
	# A subsequently committed Shop wardrobe is the run's authoritative owner.
	if carry._wardrobe != null:
		wardrobe = carry._wardrobe
		_bound_carry = carry
	if wardrobe == null:
		var candidate := RunPatchWardrobe.new(app.run_heroes, app.run_trinkets, definitions,
			app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
		if not candidate.is_valid():
			return
		wardrobe = candidate
	elif not wardrobe.refresh_run_context(app.run_heroes, app.run_trinkets, app.run_scraps,
		app.session_gold, app.run_deck, wardrobe.get_snapshot()):
		return
	_clear_choices()
	_service = offering
	_drop = drop
	_claim_context = _context()
	var state := wardrobe.get_snapshot()
	if not state.definitions.has(drop) or wardrobe._find_wearer(drop) != "":
		_update_summary()
		return
	var reward = app.hand_view.get_node_or_null("CardReward")
	if reward == null:
		return
	if carry.torn == null:
		return
	var carry_state: Dictionary = carry.torn.read_state()
	# The existing chooser only appears once the actual owned drop and
	# authoritative ledger admit a read-only choice for a living wearer.
	var previews: Dictionary = {}
	for hero in app.run_heroes:
		if hero.hp > 0:
			var preview: Dictionary = RunPatchWearerSummary.preview_sew(
				wardrobe, carry_state, drop, hero.id)
			if preview.get("ok") != true:
				return
			previews[hero.id] = preview
	if previews.is_empty():
		return
	var column := VBoxContainer.new()
	column.name = "ElitePatchReward"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Preflight the complete actual choice before moving the reward control.
	app.hand_view.get_parent().add_theme_constant_override("separation", 12)
	app.hand_view.add_child(column)
	reward.reparent(column)
	# Compact sewn offer title in the shipped display face, above the authored rules.
	var face := heading_font()
	title_label = Label.new()
	title_label.name = "ElitePatchOfferTitle"
	title_label.text = "Sew %s" % _friendly_label(drop)
	title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_heading(title_label, face)
	column.add_child(title_label)
	_prompt = Label.new()
	_prompt.name = "ElitePatchPowerPreview"
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_prompt)
	var first_preview: Dictionary = previews.values()[0]
	var power: String = first_preview["rules_text"]
	if power.is_empty():
		power = "power not documented"
	_prompt.text = "%s (%s): %s. Choose a living wearer (free); focus a hero for slot consequences." % [
		_friendly_label(drop), _friendly_label(state.definitions[drop]), power]
	_choices = HBoxContainer.new()
	column.add_child(_choices)
	# Short chooser caption keeps its exact wording and takes only the display face.
	chooser_label = Label.new()
	chooser_label.name = "SewChooserCaption"
	chooser_label.text = "Sew to (free):"
	apply_heading(chooser_label, face)
	_choices.add_child(chooser_label)
	for hero in app.run_heroes:
		var button := Button.new()
		button.text = hero.id.capitalize()
		button.set_meta("hero_id", hero.id)
		button.disabled = hero.hp == 0 or not previews.has(hero.id)
		button.custom_minimum_size = Vector2(170, 52)
		# Wearer actions speak in the shipped PatchHeadingButton display face; the
		# cream paper tag, hero-colour border, ink and focus ring below are unchanged.
		apply_heading_button(button, face)
		# Styled sewn-paper tag appearance (>=18px text, cream fill, stitched seams).
		# The shell theme paints cream text for felt buttons, so every drawn state
		# of this cream tag (normal, focus, hover, pressed, hover+pressed) needs
		# its own dark-ink text to stay readable against the paper surface.
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", INK)
		button.add_theme_color_override("font_hover_pressed_color", INK)
		button.add_theme_color_override("font_hover_color", INK)
		button.add_theme_color_override("font_pressed_color", INK)
		button.add_theme_color_override("font_focus_color", INK)
		button.add_theme_color_override("font_disabled_color", Color("777166"))
		# Custom styleboxes for each state
		var paper_normal := StyleBoxFlat.new()
		paper_normal.bg_color = Color("ecdfbd")
		paper_normal.border_color = HERO_COLORS.get(hero.id, Color("777166"))
		paper_normal.set_border_width_all(3)
		paper_normal.set_corner_radius_all(4)
		button.add_theme_stylebox_override("normal", paper_normal)
		var paper_hover := StyleBoxFlat.new()
		paper_hover.bg_color = Color("f5f0e6")
		paper_hover.border_color = Color("302b29")
		paper_hover.set_border_width_all(3)
		paper_hover.set_corner_radius_all(4)
		button.add_theme_stylebox_override("hover", paper_hover)
		var paper_pressed := StyleBoxFlat.new()
		paper_pressed.bg_color = Color("dcd8b8")
		paper_pressed.border_color = INK
		paper_pressed.set_border_width_all(3)
		paper_pressed.set_corner_radius_all(4)
		button.add_theme_stylebox_override("pressed", paper_pressed)
		# The shell theme defines a dark felt "hover_pressed" surface, which the
		# engine would draw (with font_hover_pressed_color) during shortcut
		# feedback. Keep that state sewn paper as well so the ink text stays legible.
		var paper_hover_pressed := paper_pressed.duplicate()
		button.add_theme_stylebox_override("hover_pressed", paper_hover_pressed)
		var paper_disabled := StyleBoxFlat.new()
		paper_disabled.bg_color = Color("d6d2c8")
		paper_disabled.border_color = Color("777166")
		paper_disabled.set_border_width_all(3)
		paper_disabled.set_corner_radius_all(4)
		button.add_theme_stylebox_override("disabled", paper_disabled)
		# Focus ring in dark ink
		var focus_box := StyleBoxFlat.new()
		focus_box.bg_color = Color.TRANSPARENT
		focus_box.border_color = Color("302b29")
		focus_box.set_border_width_all(3)
		focus_box.draw_center = false
		focus_box.expand_margin_left = 3
		focus_box.expand_margin_right = 3
		focus_box.expand_margin_top = 3
		focus_box.expand_margin_bottom = 3
		button.add_theme_stylebox_override("focus", focus_box)
		# Add stitched accent control as a child (drawn over button face)
		var stitch := StitchedTag.new()
		stitch.accent_color = HERO_COLORS.get(hero.id, Color("c49a3a"))
		stitch.name = "StitchAccent"
		button.add_child(stitch)
		if previews.has(hero.id):
			button.tooltip_text = _preview_line(previews[hero.id])
		else:
			button.tooltip_text = "%s is torn; mend before sewing." % hero.id.capitalize()
		_choices.add_child(button)
		hero_buttons.append(button)
		button.pressed.connect(_sew.bind(hero.id, button, _token, state))
		button.focus_entered.connect(_show_preview.bind(hero.id, _token))
		button.mouse_entered.connect(_show_preview.bind(hero.id, _token))
	_wire_focus()
	_update_summary()


static func _preview_line(preview: Dictionary) -> String:
	if preview.get("ok") != true:
		return ""
	var power: String = preview["rules_text"]
	if power.is_empty():
		power = "power not documented"
	var displaced: String = "empty %s slot; +0 scrap" % preview["slot"]
	if preview["displaced_id"] != "":
		displaced = "replaces %s in %s slot (destroyed); +1 scrap" % [
			_friendly_label(preview["displaced_id"]), preview["slot"]]
		if not preview["displaced_rules_text"].is_empty():
			displaced += " [old: %s]" % preview["displaced_rules_text"]
	return "%s: %s (%s) - %s; %s" % [
		preview["wearer"].capitalize(), _friendly_label(preview["patch_id"]),
		preview["slot"], power, displaced]


func _show_preview(hero_id: String, token: int) -> void:
	if token != _token or not is_instance_valid(_prompt) or not _eligible():
		return
	if wardrobe != null and wardrobe._find_wearer(_drop) != "":
		return
	var carry := get_parent().party_carryover as RunTornCarryover
	if carry == null or carry.torn == null:
		return
	var preview: Dictionary = RunPatchWearerSummary.preview_sew(
		wardrobe, carry.torn.read_state(), _drop, hero_id)
	if preview.get("ok") == true:
		_prompt.text = _preview_line(preview)


func _wire_focus() -> void:
	var app = get_parent()
	var available: Array[Button] = []
	for button in hero_buttons:
		if is_instance_valid(button) and not button.disabled and button.is_visible_in_tree():
			available.append(button)
	if available.is_empty():
		return
	# The app rebuilds its action cycle each frame; extend it after that refresh.
	# Use only living, visible recipients, even when the first hero is torn.
	app.return_button.focus_next = app.return_button.get_path_to(available[0])
	for index in range(available.size()):
		var button: Button = available[index]
		var previous: Control = app.return_button if index == 0 else available[index - 1]
		var next: Control = app.continue_button if index == available.size() - 1 else available[index + 1]
		button.focus_previous = button.get_path_to(previous)
		button.focus_next = button.get_path_to(next)
	app.continue_button.focus_previous = app.continue_button.get_path_to(available.back())


func _confirmed(service: RunMultiFightRewards) -> bool:
	var app = get_parent()
	return _map != null and _map == app.run_map and _rng == app.run_rng \
		and service == app.multi_fight_rewards and service._map == _map \
		and service._rng == _rng and service._carry == app.party_carryover \
		and service._map_revision == _map.get_generation_revision() \
		and service._graph == _map.get_floors() and service._route == _map.get_route() \
		and service._node == _map.get_current_node_id() \
		and _map.get_node(service._node).get("type") == "Elite" \
		and service._paid_battles.has(app.battle_result) and service._pending == null \
		and service.read_state() == {"deck": app.run_deck, "gold": app.session_gold,
			"trinkets": app.run_trinkets, "party": app.party_carryover.read_state()} \
		and app._can_leave_fight() and is_instance_valid(app.battle_view) \
		and app.battle_view.is_visible_in_tree() and is_instance_valid(app.continue_button) \
		and not app.continue_button.disabled


func _eligible() -> bool:
	return _service != null and _confirmed(_service) and _context() == _claim_context


func _sew(hero_id: String, button, token: int, expected: Dictionary) -> void:
	if token != _token or wardrobe == null or not _eligible() \
		or not is_instance_valid(button) or button not in hero_buttons \
		or button.disabled or not button.is_visible_in_tree() \
		or button.get_meta("hero_id", "") != hero_id:
		return
	var carry := get_parent().party_carryover as RunTornCarryover
	if carry == null or not carry.can_bind_wardrobe(wardrobe, carry.torn, expected) \
		or not expected.heroes.any(func(hero): return hero.id == hero_id and hero.hp > 0):
		return
	var slot: Variant = expected.definitions.get(_drop)
	var result := wardrobe.sew(_drop, hero_id, slot,
		"elite:%s:%s" % [_map.get_current_node_id(), _drop], expected)
	if not result.ok:
		return
	var sewn_state := wardrobe.get_snapshot()
	if not carry.bind_wardrobe(wardrobe, carry.torn, sewn_state):
		return
	# The wardrobe owns the replacement ledger, while the routed run exposes
	# the same inventory and scrap purse to subsequent nodes and rewards.
	var app = get_parent()
	app.run_trinkets.assign(sewn_state.owned)
	app.run_scraps = sewn_state.scraps
	# Continue checks the paid coordinator's current inventory against the run.
	# Reconcile only its post-claim inventory snapshot; its receipt, offers,
	# gold, paid battles and RNG remain untouched.
	_service._trinkets.assign(sewn_state.owned)
	_bound_carry = carry
	for action in hero_buttons:
		action.disabled = true
	if is_instance_valid(_prompt):
		var receipt: Dictionary = result.get("receipt", {})
		var patch_name: String = _friendly_label(receipt.get("patch_id", _drop))
		var hero_name: String = receipt.get("hero_id", hero_id).capitalize()
		var slot_name: String = str(receipt.get("slot", slot))
		var displaced_id: String = receipt.get("displaced_id", "")
		if displaced_id != "":
			_prompt.text = "Sewn %s to %s (%s); +1 scrap from replacing %s." % [
				patch_name, hero_name, slot_name, _friendly_label(displaced_id)]
		else:
			_prompt.text = "Sewn %s to %s (%s); +0 scraps (empty slot)." % [
				patch_name, hero_name, slot_name]
	_update_summary()


func _update_summary() -> void:
	if not is_instance_valid(summary):
		return
	if wardrobe == null:
		summary.text = ""
		_summary_inputs.clear()
		return
	var carry := get_parent().party_carryover as RunTornCarryover
	var torn_state: Variant = carry.torn.read_state() if carry != null and carry.torn != null else null
	# Avoid re-reading the three authored catalogs every render frame. Recheck
	# whenever the actual wardrobe or torn activation changes.
	var inputs: Array = [wardrobe.get_snapshot(), torn_state]
	if inputs == _summary_inputs:
		return
	_summary_inputs = inputs
	var readout: Dictionary = RunPatchWearerSummary.summarize(wardrobe, torn_state)
	if readout.get("ok") != true:
		summary.text = "Worn patches unavailable"
		return
	var lines: Array[String] = []
	for hero in readout["heroes"]:
		for worn in hero["slots"]:
			if worn["patch_id"] == "":
				continue
			var line: String = "%s: %s (%s) [%s]" % [
				hero["id"].capitalize(), _friendly_label(worn["patch_id"]), worn["slot"],
				"active" if worn["active"] else "inactive"]
			if not worn["rules_text"].is_empty():
				line += " - %s" % worn["rules_text"]
			lines.append(line)
	summary.text = "Worn patches: " + " | ".join(lines) if not lines.is_empty() else ""
