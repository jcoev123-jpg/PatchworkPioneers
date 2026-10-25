extends Node
## Reads fresh snapshots only; retained references identify the current presentation.
##
## Each presented actor owns one slim, unboxed ribbon pinned to the stage hem directly
## under its own actor slot: the HP number and bar, one Block value, and a width-aware
## flow of sewn, hoverable status chips. Chips keep their complete names at a readable
## size and wrap onto further rows when the actor's own slot is too narrow, so the
## ribbon grows with them instead of shrinking or truncating the text. The snapshot text
## stays exactly as CombatActorMeter computes it; only the long-form paragraphs are
## hidden and reachable through the button tooltips, so no rule is duplicated on the
## stage. A hero's ribbon also carries one legible sewn threat tag - "1 FOE" or "2 FOES" -
## on the right hem of its HP trough, worded from the same announced counts the enemy
## intent badges already own.

## Narrow ribbon geometry: wide enough for three status chips, never wider than the slot.
const RIBBON_MAX_WIDTH := 200.0
const RIBBON_MIN_WIDTH := 84.0
const RIBBON_HEIGHT := 64.0
## The HP trough rides under the actor with the number drawn inside it: 14 px numerals
## measure 20 px, so the bar keeps a 22 px trough and never lets the outlined ink spill
## outside the stitched fill.
const RIBBON_HP_BAR_HEIGHT := 22.0
const RIBBON_SLOT_INSET := 4.0
## Four reusable slots: fallen badge, ordinary statuses, or living enemy Thorns.
const STATUS_BUTTONS := 4
const STATUS_ORDER := ["bleed", "weak", "exposed"]
## Readable chip text: at every normal 1280x720 actor width the complete "Bleed 3"
## style name is drawn at 14 px, and the chips wrap onto a second row only when the
## actor's own slot is too narrow for the whole row. The compact names survive only as
## the fallback for a slot narrower than one complete chip; the hover text stays whole.
const STATUS_SHORT := {"bleed": "Ble", "weak": "Wea", "exposed": "Exp", "thorns": "Thr"}
const READABLE_CHIP_FONT := 14
const CHIP_FONT_SIZES := [14, 12, 11]
const CHIP_SEPARATION := 2
const CHIP_ROW_SEPARATION := 2
## Bounded, presentation-only readable names for known authored patch IDs. `_patch_power`
## below restates each M05 HEAD/ARM/COAT power as a short player sentence (worn amounts,
## wearer-only scope, real Block recipient, single-hit/once-per-turn/once-per-combat
## limits and the refused cases) instead of internal effect keys. An unknown ID keeps
## its raw authored ID and is never given a fabricated power line.
const PATCH_LABELS := {"stitched_badge": "Stitched Badge", "spare_spool": "Spare Spool",
	"button_eye": "Button Eye", "pincushion_arm": "Pincushion Arm",
	"switchback_button": "Switchback Button",
	"quilted_coat": "Quilted Coat", "padded_vest": "Padded Vest",
	"double_quilt_coat": "Double Quilt Coat", "scrap_lined_vest": "Scrap Lined Vest",
	"wool_patch_cloak": "Wool Patch Cloak", "chain_stitched_coat": "Chain Stitched Coat",
	"reinforced_patchcoat": "Reinforced Patchcoat", "thick_felt_mantle": "Thick Felt Mantle",
	"bloodstitch_bonnet": "Bloodstitch Bonnet", "button_glass_visor": "Button Glass Visor",
	"stern_seam_cap": "Stern Seam Cap", "reinforced_browband": "Reinforced Browband",
	"hemguard_cuff": "Hemguard Cuff", "red_bobbin_cuff": "Red Bobbin Cuff",
	"loose_thread_glove": "Loose Thread Glove", "frayfinder_mitt": "Frayfinder Mitt",
	"threadguard_wrap": "Threadguard Wrap",
	"borrowed_button": "Borrowed Button"}
## Committed Block icon, painted inside the meter's existing sewn glyph. Optional: a
## missing image leaves the drawn shield in place, so protection is always readable.
const UI_ART_DIR := "res://assets/paper/ui/"
const BLOCK_ART := "hud_block.png"
## The hero threat tag is one readable, grammatical word pair ("1 FOE", "2 FOES") on a
## dark felt tag with a pale stitched border, never a cryptic "! 1". Twelve px is the
## smallest size at which the count is legible on the ribbon; the tag grows to its own
## measured word and still leaves the centred HP numerals completely uncovered.
const THREAT_BADGE_FONT := 12
const THREAT_BADGE_ONE := "1 FOE"
const THREAT_BADGE_MANY := "%d FOES"
const THREAT_BADGE_MIN_WIDTH := 42.0
const THREAT_BADGE_PADDING := 10.0
const THREAT_BADGE_MARGIN := 2.0
## Pale thread on dark felt: the same high-contrast pair the other ribbon chips use.
const THREAT_BADGE_FELT := Color("3d4a45")
const THREAT_BADGE_INK := Color("f1e7d2")
const THREAT_BADGE_THREAD := Color("c9b996")

var row: Control
var _battle: Control
var _deck: CombatDeck
var _party: CombatParty
var _enemies: CombatEnemies
var _coat_bonuses: Dictionary = {}
## Presentation-only art root. A redirected or unavailable root (missing file or import)
## keeps the drawn shield instead of failing, and repaints the same mounted icon.
var art_root := UI_ART_DIR
var _art_cache: Dictionary = {}


func _ready() -> void:
	get_parent().start_run_requested.connect(_sync_battle, CONNECT_DEFERRED)


func _process(_delta: float) -> void:
	_sync_battle()


## Resolved path of the committed Block icon under the current presentation-only root.
func block_art_path() -> String:
	return art_root + BLOCK_ART


## Cached, optional Block icon. A missing image is cached as null too, so the drawn sewn
## shield stays the fallback and an unavailable file is never probed twice.
func block_texture() -> Texture2D:
	var path := block_art_path()
	if not _art_cache.has(path):
		_art_cache[path] = LiveEnemyIntentBadge.load_icon_texture(path)
	return _art_cache[path] as Texture2D


func _sync_battle() -> void:
	var app = get_parent()
	if app.deck == null or app.party == null or app.enemies == null \
			or not is_instance_valid(app.battle_view):
		_clear()
		return
	if not app.battle_view.is_visible_in_tree() or not app.party.is_valid() or not app.enemies.is_valid():
		_clear()
		return
	if _battle != app.battle_view or _deck != app.deck or _party != app.party or _enemies != app.enemies:
		_clear()
		_mount(app)
	var unravel := _bound_unravel(app)
	var threats := _announced_threat_counts(app, unravel)
	var patches := _current_patches(app)
	var needed_height := RIBBON_HEIGHT
	var forecast := {"ok": false, "heroes": []}
	if app.enemy_intents != null and app.enemy_intents.is_valid():
		forecast = CombatIncomingAttackPreview.new().forecast(
			_party.get_heroes(), _enemies.get_enemies(), app.enemy_intents.get_intents(),
			app.enemy_intents.is_bound())
	for index in range(row.get_child_count()):
		var meter := row.get_child(index) as CombatActorMeter
		if meter == null:
			continue
		var side := "hero" if index < CombatParty.PARTY_SIZE else "enemy"
		var position: int = index + 1 if side == "hero" else index - CombatParty.PARTY_SIZE + 1
		var snapshot: Dictionary = _party.get_hero(position) if side == "hero" else _enemies.get_enemy(position)
		var shown := meter.show_actor(snapshot, side)
		_compact(meter)
		_sync_block_icon(meter, snapshot)
		if side == "hero":
			_sync_threat_pin(meter, threats[position - 1])
		if side == "enemy":
			_sync_unravel_thread(meter, snapshot, position, unravel)
		# The forecast is written before the tooltip is composed, so a hover can never
		# show a stale or half-built line; the long paragraph itself stays hidden.
		var incoming := meter.get_node_or_null("Padding/Content/IncomingForecast") as Label
		if incoming != null:
			incoming.text = _incoming_text(snapshot, forecast, position)
			incoming.hide()
		var slot := _slot_control(app, side, position)
		var width := _ribbon_width(slot)
		if shown:
			_sync_status_buttons(meter, snapshot, side, incoming, width)
		if side == "hero":
			_sync_patch_buttons(meter, snapshot, patches.get(snapshot.get("id", ""), {}))
		needed_height = maxf(needed_height, meter.get_combined_minimum_size().y)
		_place(meter, slot, width)
	# VBox siblings (including the shared-hand pile counts) must be laid out BELOW
	# the full optional patch row, not across its hover area.
	var target_min := Vector2(0, needed_height + 2.0)
	if row.custom_minimum_size != target_min:
		row.custom_minimum_size = target_min


## Only the admission-owned service of the active, still-identical fight is readable.
## Neither the stage nor its badges may synthesize a replacement gauge.
func _bound_unravel(app) -> CombatUnravel:
	if app._battle_closed or app.deck == null or app.party == null or app.enemies == null \
			or app.enemy_intents == null or app.battle_result == null:
		return null
	var flow: CombatRoundFlow = app.round_flow
	if flow == null or not is_instance_valid(flow) or not flow._started \
			or flow._deck != app.deck or flow._party != app.party \
			or flow._enemies != app.enemies or flow._intents != app.enemy_intents \
			or flow._result != app.battle_result \
			or flow._battle_deck != app.deck or flow._battle_party != app.party \
			or flow._battle_enemies != app.enemies or flow._battle_intents != app.enemy_intents \
			or flow._battle_result != app.battle_result:
		return null
	var service: CombatUnravel = flow._unravel
	if service == null or not is_instance_valid(service) \
			or service._bound_enemies != app.enemies or not flow._valid_unravel_binding():
		return null
	return service


## A single slim stitched felt trough immediately below HP, owned by the enemy
## ribbon alone. A hover-only carrier exposes the truthful tooltip; no gameplay action,
## focus or target from the authoritative stage slots.
func _make_unravel_thread(content: VBoxContainer, meter: CombatActorMeter) -> void:
	var thread := ProgressBar.new()
	thread.name = "UnravelThread"
	thread.show_percentage = false
	thread.custom_minimum_size = Vector2(0, 17)
	thread.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thread.focus_mode = Control.FOCUS_NONE
	thread.min_value = 0
	thread.max_value = 1
	thread.value = 0
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color("192830")
	backing.border_color = Color("a69a85")
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(2)
	thread.add_theme_stylebox_override("background", backing)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("b8775c")
	fill.set_corner_radius_all(2)
	thread.add_theme_stylebox_override("fill", fill)
	content.add_child(thread)
	content.move_child(thread, meter.hp_bar.get_index() + 1)
	var stitch := CombatActorMeter.BarStitch.new()
	stitch.name = "ThreadStitch"
	thread.add_child(stitch)
	# The decorative ProgressBar ignores input; a transparent, unfocusable
	# and actionless hover carrier exposes its tooltip without drawing on
	# the loose-thread fill or issuing any gameplay action.
	var hover := Button.new()
	hover.name = "ThreadHover"
	hover.flat = true
	hover.mouse_filter = Control.MOUSE_FILTER_STOP
	hover.focus_mode = Control.FOCUS_NONE
	hover.mouse_default_cursor_shape = Control.CURSOR_HELP
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		hover.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	thread.add_child(hover)
	hover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var number := Label.new()
	number.name = "ThreadFraction"
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.focus_mode = Control.FOCUS_NONE
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", 11)
	number.add_theme_color_override("font_color", Color("eee1ca"))
	number.add_theme_color_override("font_outline_color", Color("192830"))
	number.add_theme_constant_override("outline_size", 3)
	thread.add_child(number)
	number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	thread.hide()


## Detached snapshots only; a slain, invalid or replaced roster gets neither
## a stale fraction nor a stray hover target.
func _sync_unravel_thread(meter: CombatActorMeter, actor: Dictionary, position: int,
		service: CombatUnravel) -> void:
	var thread := meter.get_node("Padding/Content/UnravelThread") as ProgressBar
	var fraction := thread.get_node("ThreadFraction") as Label
	var state: Dictionary = {}
	if service != null and actor.get("hp", 0) > 0 and actor.get("position") == position:
		state = service.get_snapshot(position)
	if state.is_empty():
		# Keep the node for this position, but detach every old readout and tooltip.
		if thread.visible:
			thread.hide()
		thread.value = 0
		thread.max_value = 1
		thread.tooltip_text = ""
		(thread.get_node("ThreadHover") as Button).tooltip_text = ""
		fraction.text = ""
		return
	var gauge: int = state["gauge"]
	var threshold: int = state["threshold"]
	thread.max_value = threshold
	thread.value = gauge
	fraction.text = "%d/%d" % [gauge, threshold]
	thread.tooltip_text = "Unravel: %d/%d threads — %s" % [
		gauge, threshold, "UNRAVELLED: next action skipped" if state["skip_pending"]
			else "next action skipped when full"]
	(thread.get_node("ThreadHover") as Button).tooltip_text = thread.tooltip_text
	if not thread.visible:
		thread.show()


## Narrow, unboxed ribbon shell built once per mounted meter.
func _make_ribbon(meter: CombatActorMeter, side: String) -> void:
	meter.custom_minimum_size = Vector2.ZERO
	meter.size_flags_horizontal = Control.SIZE_FILL
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.focus_mode = Control.FOCUS_NONE
	# Drop the shared framed panel locally: the ribbon sits directly on the hem.
	var panel_style := meter._panel_style as StyleBoxFlat
	if panel_style != null:
		panel_style.bg_color = Color(0, 0, 0, 0)
		panel_style.set_border_width_all(0)
		panel_style.set_corner_radius_all(0)
	var padding := meter.get_node("Padding") as MarginContainer
	for edge in ["left", "right"]:
		padding.add_theme_constant_override("margin_" + edge, 2)
	for edge in ["top", "bottom"]:
		padding.add_theme_constant_override("margin_" + edge, 1)
	var content := meter.get_node("Padding/Content") as VBoxContainer
	content.add_theme_constant_override("separation", 0)
	meter.actor_heading.add_theme_font_size_override("font_size", 12)
	meter.actor_heading.hide()
	meter.hp_text.add_theme_font_size_override("font_size", 14)
	meter.hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meter.hp_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	meter.hp_bar.custom_minimum_size = Vector2(0, RIBBON_HP_BAR_HEIGHT)
	if side == "enemy":
		_make_unravel_thread(content, meter)
	else:
		# A legible target-count felt tag overlays the right hem of the existing HP
		# trough: it fills its own measured word, never covers the centred numerals,
		# and stays a pointer/keyboard-inert picture.
		var pin := Panel.new()
		pin.name = "ThreatPin"
		pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pin.focus_mode = Control.FOCUS_NONE
		pin.anchor_left = 1.0
		pin.anchor_right = 1.0
		pin.anchor_bottom = 1.0
		pin.offset_left = -THREAT_BADGE_MIN_WIDTH - THREAT_BADGE_MARGIN
		pin.offset_right = -THREAT_BADGE_MARGIN
		pin.offset_top = 1.0
		pin.offset_bottom = -1.0
		var felt := StyleBoxFlat.new()
		felt.bg_color = THREAT_BADGE_FELT
		felt.border_color = THREAT_BADGE_THREAD
		felt.set_border_width_all(2)
		felt.set_corner_radius_all(4)
		pin.add_theme_stylebox_override("panel", felt)
		meter.hp_bar.add_child(pin)
		var text := Label.new()
		text.name = "Count"
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.focus_mode = Control.FOCUS_NONE
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.add_theme_font_size_override("font_size", THREAT_BADGE_FONT)
		text.add_theme_color_override("font_color", THREAT_BADGE_INK)
		text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pin.add_child(text)
		pin.hide()
	meter.block_text.add_theme_font_size_override("font_size", 12)
	meter.block_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meter.block_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	meter.block_bar.custom_minimum_size = Vector2(0, 6)
	meter.block_bar.hide()
	# Authored Block icon inside the existing sewn glyph slot. It is a picture only: the
	# authoritative amount stays the meter's own Block label and the badge keeps its width.
	var block_icon := TextureRect.new()
	block_icon.name = "BlockIcon"
	block_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block_icon.focus_mode = Control.FOCUS_NONE
	block_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	block_icon.stretch_mode = TextureRect.STRETCH_SCALE
	block_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	block_icon.visible = false
	meter.block_shield.add_child(block_icon)
	meter.status_text.add_theme_font_size_override("font_size", 11)
	meter.status_text.hide()
	meter.modifier_explanation.add_theme_font_size_override("font_size", 10)
	meter.modifier_explanation.hide()
	meter.bleed_warning.add_theme_font_size_override("font_size", 10)
	meter.bleed_warning.hide()
	if side == "hero":
		var incoming := Label.new()
		incoming.name = "IncomingForecast"
		incoming.mouse_filter = Control.MOUSE_FILTER_IGNORE
		incoming.focus_mode = Control.FOCUS_NONE
		incoming.add_theme_font_size_override("font_size", 12)
		incoming.autowrap_mode = TextServer.AUTOWRAP_OFF
		incoming.add_theme_color_override("font_color", CombatActorMeter.INK)
		content.add_child(incoming)
	var buttons := HFlowContainer.new()
	buttons.name = "StatusButtons"
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.focus_mode = Control.FOCUS_NONE
	buttons.add_theme_constant_override("h_separation", CHIP_SEPARATION)
	buttons.add_theme_constant_override("v_separation", CHIP_ROW_SEPARATION)
	content.add_child(buttons)
	buttons.hide()
	for index in range(STATUS_BUTTONS):
		buttons.add_child(_make_status_button(index))
	if side == "hero":
		var patches := HBoxContainer.new()
		patches.name = "PatchButtons"
		patches.mouse_filter = Control.MOUSE_FILTER_IGNORE
		patches.focus_mode = Control.FOCUS_NONE
		patches.add_theme_constant_override("separation", 2)
		content.add_child(patches)
		patches.hide()
		for slot in RunPatchWardrobe.SLOTS:
			var chip := _make_status_button(patches.get_child_count())
			chip.name = "Patch" + slot
			patches.add_child(chip)


## Small sewn chip: pointer-hoverable for its rules, never focusable or activating.
## The label takes its own measured width inside the wrapping row, so the chip never
## squeezes or clips its text; the layout below only ever shortens or shrinks the text
## when a single complete chip cannot fit the actor's slot at all.
func _make_status_button(index: int) -> Button:
	var button := Button.new()
	button.name = "StatusButton%d" % (index + 1)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_HELP
	button.custom_minimum_size = Vector2(0, _chip_height(READABLE_CHIP_FONT))
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.clip_text = false
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.add_theme_font_size_override("font_size", READABLE_CHIP_FONT)
	button.add_theme_color_override("font_color", CombatActorMeter.INK)
	button.add_theme_color_override("font_hover_color", CombatActorMeter.INK)
	button.add_theme_color_override("font_pressed_color", CombatActorMeter.INK)
	button.add_theme_color_override("font_focus_color", CombatActorMeter.INK)
	_set_chip_style(button, false)
	button.hide()
	return button


## One chip style per chip kind: the fallen badge reads as a distinct sewn patch.
func _set_chip_style(button: Button, fallen: bool, hazard: bool = false) -> void:
	if button.has_meta("fallen_chip") and button.has_meta("hazard_chip") \
			and bool(button.get_meta("fallen_chip")) == fallen \
			and bool(button.get_meta("hazard_chip")) == hazard:
		return
	button.set_meta("fallen_chip", fallen)
	button.set_meta("hazard_chip", hazard)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, _chip_style(state == "hover", fallen, hazard))


func _chip_style(hovered: bool, fallen: bool = false, hazard: bool = false) -> StyleBoxFlat:
	var chip := StyleBoxFlat.new()
	if fallen:
		chip.bg_color = Color("5b3c34") if hovered else Color("46302b")
		chip.border_color = Color("e8b7a4") if hovered else Color("c0806e")
	elif hazard:
		chip.bg_color = Color("704434") if hovered else Color("583328")
		chip.border_color = Color("f0c49c") if hovered else Color("d99c77")
	else:
		chip.bg_color = Color("3d4a45") if hovered else Color("2f3b36")
		chip.border_color = Color("c9b996") if hovered else Color("6d7a70")
	chip.set_border_width_all(1)
	chip.set_corner_radius_all(3)
	chip.content_margin_left = 2.0
	chip.content_margin_right = 2.0
	chip.content_margin_top = 0.0
	chip.content_margin_bottom = 0.0
	return chip


func _mount(app) -> void:
	_battle = app.battle_view
	_deck = app.deck
	_party = app.party
	_enemies = app.enemies
	_battle.tree_exiting.connect(_clear, CONNECT_ONE_SHOT)
	row = Control.new()
	row.name = "CombatMeters"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.focus_mode = Control.FOCUS_NONE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, RIBBON_HEIGHT)
	var column := app.intent_label.get_parent() as VBoxContainer
	# Reserve room for the ribbons while leaving the existing target panels actionable.
	column.add_theme_constant_override("separation", 6)
	column.add_child(row)
	column.move_child(row, app.intent_label.get_index())
	var ribbon_height := RIBBON_HEIGHT
	for side in ["hero", "enemy"]:
		var count: int = CombatParty.PARTY_SIZE if side == "hero" else _enemies.get_enemies().size()
		for position in range(1, count + 1):
			var meter := CombatActorMeter.new()
			meter.name = "%s%d" % [side, position]
			_make_ribbon(meter, side)
			row.add_child(meter)
			ribbon_height = maxf(ribbon_height, meter.get_combined_minimum_size().y)
	row.custom_minimum_size = Vector2(0, ribbon_height + 2.0)


## Threats are unique *original* living enemy sources aimed at a still-living hero.
## This reads the complete, bound cached batch; the policy fallback is pure and
## may change its display target without rerolling or editing the announcement.
func _announced_threat_counts(app, unravel: CombatUnravel) -> Array[int]:
	var counts: Array[int] = [0, 0, 0]
	if unravel == null or app._battle_closed or app.enemy_intents == null \
			or not app.enemy_intents.is_bound() or app.enemy_intents._party != _party \
			or app.enemy_intents._rng != app.run_rng or _enemies != app.enemies \
			or _party != app.party or _battle != app.battle_view:
		return counts
	var roster := _enemies.get_enemies()
	var intents: Array[Dictionary] = app.enemy_intents.get_intents()
	var ordered := CombatIncomingAttackPreview.new()._validated_actions(roster.size(), intents)
	if ordered.size() != roster.size():
		return counts
	for action in ordered:
		var source: int = action["enemy_position"]
		if roster[source - 1].get("position") != source or _enemies.is_slain(source) \
				or unravel.get_snapshot(source).get("skip_pending", false) \
				or action.get("type") not in ["attack", "debuff", "shove"] \
				or CombatEnemyIntents.policy_for(_enemies, source).is_empty():
			continue
		var effective := CombatEnemyIntents.resolve_announced_action(_party, action, _enemies)
		var target = effective.get("target_position")
		if target is int and target >= 1 and target <= CombatParty.PARTY_SIZE \
				and not _party.is_downed(target):
			counts[target - 1] += 1
	return counts


## The already-computed announced count, worded for the reader: "1 FOE", "2 FOES", and
## nothing at all when no live source targets this hero. The tag only reflects the count
## `_announced_threat_counts` bound; it never asks the scheduler for another draw.
func _sync_threat_pin(meter: CombatActorMeter, count: int) -> void:
	var pin := meter.hp_bar.get_node_or_null("ThreatPin") as Panel
	if pin == null:
		return
	var label := pin.get_node("Count") as Label
	var text := "" if count <= 0 else (THREAT_BADGE_ONE if count == 1
		else THREAT_BADGE_MANY % count)
	if label.text != text:
		label.text = text
	var shown := count > 0
	if pin.visible != shown:
		pin.visible = shown
	if not shown:
		return
	# Fill the tag with its own measured word, up to a readable cap, and keep it on the
	# right hem where the centred HP numerals never reach it.
	var room := maxf(THREAT_BADGE_MIN_WIDTH,
		meter.hp_bar.size.x * 0.4 - THREAT_BADGE_MARGIN * 2.0)
	var width := clampf(label.get_combined_minimum_size().x + THREAT_BADGE_PADDING,
		THREAT_BADGE_MIN_WIDTH, room)
	var wanted := -THREAT_BADGE_MARGIN - width
	if not is_equal_approx(pin.offset_left, wanted):
		pin.offset_left = wanted


## Hide the long-form paragraphs after each show_actor without deleting or rewriting them.
func _compact(meter: CombatActorMeter) -> void:
	meter.actor_heading.hide()
	meter.block_bar.hide()
	meter.modifier_explanation.hide()
	meter.bleed_warning.hide()


## The committed Block icon lives inside the meter's own sewn glyph and is only painted
## while the model value is positive. The amount, tooltip, badge width and every HP/status
## child of the ribbon are untouched; a missing image falls back to the drawn shield.
func _sync_block_icon(meter: CombatActorMeter, actor: Dictionary) -> void:
	var icon := meter.block_shield.get_node_or_null("BlockIcon") as TextureRect
	if icon == null:
		return
	var art := block_texture()
	if icon.texture != art:
		icon.texture = art
	var shown: bool = art != null and int(actor.get("block", 0)) > 0
	if icon.visible != shown:
		icon.visible = shown


## Resolve the actual bound run ledgers afresh. The saved torn roster validates ownership,
## while the live party supplies position and *current* HP (a wearer can fall mid-Fight).
## No snapshot or projection here is ever written back to a rules service.
func _current_patches(app) -> Dictionary:
	var carry := app.party_carryover as RunTornCarryover
	if carry == null or not carry.is_valid() or carry._wardrobe == null or carry.torn == null:
		return {}
	var wardrobe: RunPatchWardrobe = carry._wardrobe
	if not wardrobe.is_valid() or not carry.torn.is_valid():
		return {}
	var state: Dictionary = wardrobe.get_snapshot()
	var torn_state: Dictionary = carry.torn.read_state()
	if torn_state.get("ok") != true or carry.read_state().get("heroes") != torn_state.get("heroes"):
		return {}
	var shop_slots: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		CombatShopPatchRules.SLOTS_CATALOG))
	var attacks: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		CombatPatchAttackRules.CATALOG))
	var coats: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_coat_patches.json"))
	if not CombatShopPatchRules._valid_slot_catalog(shop_slots) \
			or not CombatPatchAttackRules.new()._valid_catalog(attacks) \
			or not (coats is Array) or not RunPatchCoatRules._valid_authored(coats):
		return {}
	var projected: Dictionary = RunPatchCoatRules.project_health(torn_state, wardrobe, coats)
	if projected.get("ok") != true:
		return {}
	var definitions: Dictionary = state.get("definitions", {})
	for id in CombatShopPatchRules.EFFECTS:
		if definitions.has(id) and definitions[id] != CombatShopPatchRules.EFFECTS[id]["slot"]:
			return {}
	for id in CombatPatchAttackRules.EFFECTS:
		if definitions.has(id) and definitions[id] != CombatPatchAttackRules.EFFECTS[id]["slot"]:
			return {}
	if _coat_bonuses.is_empty():
		for entry in coats:
			_coat_bonuses[entry["id"]] = int(entry["max_hp_bonus"])
	for entry in coats:
		var coat_id: String = entry["id"]
		if definitions.has(coat_id) and definitions[coat_id] != "COAT":
			return {}
	# A position swap is legal, but a borrowed ID, modified effective cap or
	# resurrection of a persistently torn hero is not evidence of an active patch.
	var live := _party.get_heroes()
	var expected_by_id := {}
	var held_by_id := {}
	for hero in projected["heroes"]:
		expected_by_id[hero["id"]] = hero
	for hero in torn_state["heroes"]:
		held_by_id[hero["id"]] = hero
	if live.size() != CombatParty.PARTY_SIZE:
		return {}
	var result := {}
	for hero in live:
		var id: Variant = hero.get("id")
		if not expected_by_id.has(id) or result.has(id) \
				or hero.get("max_hp") != expected_by_id[id]["max_hp"] \
				or (held_by_id[id]["hp"] == 0 and hero.get("hp", 0) > 0):
			return {}
		result[id] = state["worn"][id].duplicate(true)
	return result if result.size() == CombatParty.PARTY_SIZE else {}


func _patch_power(id: String) -> String:
	match id:
		CombatShopPatchRules.STITCHED_BADGE_ID:
			return "+%d Block at combat opening (living wearer; stacks with Warden Block)." % \
				CombatShopPatchRules.EFFECTS[id]["amount"]
		CombatShopPatchRules.SPARE_SPOOL_ID:
			return "+%d positive healing from cards owned by this living wearer." % \
				CombatShopPatchRules.EFFECTS[id]["amount"]
		"button_eye":
			return "First successful attack in this combat also applies Exposed %d." % \
				CombatPatchAttackRules.EFFECTS[id]["amount"]
		"pincushion_arm":
			return "Damage-dealing cards owned by this wearer deal +%d damage." % \
				CombatPatchAttackRules.EFFECTS[id]["amount"]
		"bloodstitch_bonnet":
			return "This wearer's cards that already apply Bleed add 1 more Bleed."
		"button_glass_visor":
			return "This wearer's cards that already apply Exposed add 1 more Exposed."
		"stern_seam_cap":
			return "This wearer's cards that already apply Weak add 1 more Weak."
		"reinforced_browband":
			return "This wearer's cards that already grant Block grant 2 more Block, to the card's actual recipient (even an ally)."
		"hemguard_cuff":
			return "This wearer's cards that already grant Block grant 2 more Block."
		"threadguard_wrap":
			return "This wearer's cards that already grant Block grant 1 more Block, to the card's actual recipient; a damage-only card that grants no Block gains no Block from it."
		"red_bobbin_cuff":
			return "This wearer's cards that already apply Bleed add 1 more Bleed; it never multiplies Hemorrhage Hem."
		"loose_thread_glove":
			return "This wearer's cards that already grant Unravel grant 1 more Unravel."
		"frayfinder_mitt":
			return "Once per player turn, this living wearer's first confirmed single-target attack hit of the player turn deals +2 attack damage before Weak/Exposed, but only if that enemy's Unravel was already at least 1/2 of its current threshold before the hit. Normal/elite/boss base thresholds 8/12/16, grow +4 per break. Never an Unravel gauge gain, not any area/multi-hit/later hit, and no bonus on a rejected play."
		"switchback_button":
			return "Once per player turn, when a different living hero's committed card or ordered stitched half immediately precedes this living, untorn wearer's committed card or half, the wearer gains +2 Block; each ordered stitched half counts for its real owner, and a failed, invalid or uncommitted play never sets or claims it."
		"borrowed_button":
			return "Once per combat, when a different living hero's committed card or ordered stitched half actually restores at least 1 HP to this living, untorn wearer, that wearer gains 3 Block; never from this wearer's own play, a heal that restores 0 HP, Rest mending or a failed play."
	if _coat_bonuses.is_empty():
		var coats_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/patches/m04_coat_patches.json"))
		if coats_raw is Array and RunPatchCoatRules._valid_authored(coats_raw):
			for entry in coats_raw:
				_coat_bonuses[entry["id"]] = int(entry["max_hp_bonus"])
	if _coat_bonuses.has(id):
		return "+%d effective maximum HP while living; no free healing." % _coat_bonuses[id]
	return ""


## One optional reusable row on heroes only; each sewn slot has one hover-only
## button, with a distinct dormant tint. Hidden/invalid bindings leave no tooltip.
func _sync_patch_buttons(meter: CombatActorMeter, hero: Dictionary, worn: Dictionary) -> void:
	var buttons := meter.get_node("Padding/Content/PatchButtons") as HBoxContainer
	var any_worn := false
	for slot in RunPatchWardrobe.SLOTS:
		var button := buttons.get_node("Patch" + slot) as Button
		var id: String = worn.get(slot, "")
		var present := not id.is_empty()
		button.visible = present
		if not present:
			button.text = ""
			button.tooltip_text = ""
			continue
		any_worn = true
		var active: bool = hero.get("hp", 0) > 0
		var name: String = PATCH_LABELS.get(id, id)
		var power := _patch_power(id)
		var tooltip := "%s (%s)\n%s (%s) — %s\n%s" % [
			hero.get("name", String(hero["id"]).capitalize()), hero["id"],
			name, id, slot, "ACTIVE" if active else "DORMANT"]
		if not power.is_empty():
			tooltip += "\n" + power
		button.text = slot
		button.tooltip_text = tooltip
		_set_chip_style(button, not active)
	buttons.visible = any_worn


func _incoming_text(hero: Dictionary, forecast: Dictionary, position: int) -> String:
	if hero.get("hp", 0) == 0:
		return "DOWNED"
	if not forecast["ok"]:
		return "Incoming: unavailable"
	var next: Dictionary = forecast["heroes"][position - 1]
	# Attack-only loss after the owner tick; the Bleed paragraph owns Bleed loss.
	return "Incoming: none" if next["incoming"] == 0 else (
		"Incoming: %d Block, %d HP" % [next["block_absorbed"], next["hp_lost"]])


## One chip flow per ribbon: authoritative counts and a clear fallen badge.
## The complete labels are laid out at the readable size first and wrap inside the
## actor's own ribbon width; only a slot narrower than one whole chip falls back to the
## compact name or a smaller size, and a chip never clips its own text.
func _sync_status_buttons(meter: CombatActorMeter, snapshot: Dictionary, side: String,
		incoming: Label, ribbon_width: float) -> void:
	var entries: Array[Dictionary] = []
	if snapshot.get("hp", 0) == 0:
		var fallen := "DOWNED" if side == "hero" else "SLAIN"
		entries.append({"kind": "fallen", "full": fallen, "short": fallen})
	var statuses: Dictionary = snapshot.get("statuses", {})
	for key in STATUS_ORDER:
		var count: int = statuses.get(key, 0)
		if count > 0:
			entries.append({"kind": key,
				"full": "%s %d" % [String(key).capitalize(), count],
				"short": "%s %d" % [STATUS_SHORT[key], count]})
	# Passive contact hazard: not a timed status or a scheduled intent.
	var thorns = snapshot.get("thorns", 0)
	if side == "enemy" and snapshot.get("hp", 0) is int and snapshot["hp"] > 0 \
			and thorns is int and thorns > 0:
		entries.append({"kind": "thorns", "full": "Thorns %d" % thorns,
			"short": "%s %d" % [STATUS_SHORT["thorns"], thorns]})
	var tooltip := _compose_tooltip(meter, incoming)
	var buttons := meter.get_node("Padding/Content/StatusButtons") as HFlowContainer
	var fit: Dictionary = {"texts": [], "font_size": READABLE_CHIP_FONT,
		"chip_height": _chip_height(READABLE_CHIP_FONT), "height": 0.0}
	if not entries.is_empty():
		fit = _layout_chips(buttons, entries, ribbon_width)
	for index in range(buttons.get_child_count()):
		var button := buttons.get_child(index) as Button
		var active := index < entries.size()
		var text := String(fit["texts"][index]) if active else ""
		var rule := (thorns_tooltip(int(thorns)) if entries[index]["kind"] == "thorns"
			else tooltip) if active else ""
		if button.visible != active:
			button.visible = active
		if button.text != text:
			button.text = text
		if button.tooltip_text != rule:
			button.tooltip_text = rule
		var font_size: int = fit["font_size"]
		if button.get_theme_font_size("font_size") != font_size:
			button.add_theme_font_size_override("font_size", font_size)
		var chip_height: float = fit["chip_height"]
		if button.custom_minimum_size.y != chip_height:
			button.custom_minimum_size = Vector2(0, chip_height)
		if active:
			_set_chip_style(button, entries[index]["kind"] == "fallen",
				entries[index]["kind"] == "thorns")
	# The flow reserves the rows it really uses, so a wrapped ribbon pushes the shared
	# hand and action rows down instead of drawing its chips across them.
	var reserved := Vector2(0, float(fit["height"]))
	if buttons.custom_minimum_size != reserved:
		buttons.custom_minimum_size = reserved
	# Collapsing the whole container avoids an empty stitched box or hit target.
	buttons.visible = not entries.is_empty()


## Exact confirmed-positive-hit contract from CombatEnemyKeywordRules: enemy Block
## can absorb a positive hit without suppressing Thorns retaliation.
static func thorns_tooltip(amount: int) -> String:
	return "Thorns %d: Each confirmed positive-damage hit on this enemy deals %d damage back to its attacking hero, even if enemy Block absorbs that hit. Hero Block absorbs the retaliation before HP. Misses, failed plays, zero-damage attacks and previews do not retaliate." % [amount, amount]


## Height of one sewn chip at a font size: the text box plus the 1 px stitched border.
func _chip_height(font_size: int) -> float:
	return float(font_size + 6)


## Width-aware chip layout. Complete names at the readable 14 px are tried first, then
## the compact names, then smaller sizes; only the first candidate whose widest single
## chip fits the actor's slot is used. Every chosen chip is measured, so the row can
## never render a label wider than its own control, and the returned row count lets the
## ribbon reserve exactly the vertical space the wrap needs.
func _layout_chips(buttons: HFlowContainer, entries: Array[Dictionary],
		ribbon_width: float) -> Dictionary:
	var available := maxf(0.0, ribbon_width - RIBBON_SLOT_INSET)
	for compact in [false, true]:
		var texts := _chip_texts(entries, compact)
		for size_value in CHIP_FONT_SIZES:
			var font_size: int = size_value
			var widths: Array[float] = []
			var widest := 0.0
			for index in range(texts.size()):
				var button := buttons.get_child(index) as Button
				if button.text != texts[index]:
					button.text = texts[index]
				if button.get_theme_font_size("font_size") != font_size:
					button.add_theme_font_size_override("font_size", font_size)
				var width := button.get_minimum_size().x
				widths.append(width)
				widest = maxf(widest, width)
			if widest > available:
				continue
			var chip_height := _chip_height(font_size)
			var rows := _wrapped_rows(widths, available)
			return {"texts": texts, "font_size": font_size, "compact": compact,
				"rows": rows, "chip_height": chip_height,
				"height": rows * chip_height + CHIP_ROW_SEPARATION * (rows - 1)}
	# A slot narrower than the smallest complete name still gets one chip per row at the
	# smallest readable size; the ribbon width itself is clamped above this width.
	var fallback := _chip_texts(entries, true)
	var fallback_height := _chip_height(CHIP_FONT_SIZES.back())
	return {"texts": fallback, "font_size": CHIP_FONT_SIZES.back(), "compact": true,
		"rows": fallback.size(), "chip_height": fallback_height,
		"height": fallback.size() * fallback_height}


## How many chip rows the flow uses for these measured widths, matching the container's
## left-to-right wrap order and its horizontal separation.
func _wrapped_rows(widths: Array[float], available: float) -> int:
	var rows := 1
	var used := 0.0
	for width in widths:
		if used <= 0.0:
			used = width
		elif used + CHIP_SEPARATION + width <= available:
			used += CHIP_SEPARATION + width
		else:
			rows += 1
			used = width
	return rows


func _chip_texts(entries: Array[Dictionary], compact: bool) -> Array[String]:
	var texts: Array[String] = []
	for entry in entries:
		texts.append(String(entry["short"] if compact else entry["full"]))
	return texts


## Stable order: the exact status model line, then its long-form modifiers, then the
## hero's next-phase forecast, then the owner-turn Bleed/LETHAL line.
func _compose_tooltip(meter: CombatActorMeter, incoming: Label) -> String:
	var lines: Array[String] = [meter.status_text.text]
	if not meter.modifier_explanation.text.is_empty():
		lines.append(meter.modifier_explanation.text)
	if incoming != null and not incoming.text.is_empty():
		lines.append(incoming.text)
	if not meter.bleed_warning.text.is_empty():
		lines.append(meter.bleed_warning.text)
	return "\n".join(lines)


## The live stage slot of one presented actor, independent of how the sides are wrapped.
func _slot_control(app, side: String, position: int) -> Control:
	if side == "hero":
		return app.hero_panels[position - 1] if position <= app.hero_panels.size() else null
	var roster: Node = app.get_node_or_null("LiveEnemyRoster")
	if roster == null:
		return null
	if is_instance_valid(roster.panel) and roster.panel.get_child_count() > 0:
		var columns: Node = roster.panel.get_child(0)
		if columns != null and columns.get_child_count() >= position:
			return columns.get_child(position - 1) as Control
	if roster._puppets.size() > CombatParty.PARTY_SIZE + position - 1:
		return roster._puppets[CombatParty.PARTY_SIZE + position - 1] as Control
	return null


## The ribbon width for one stage slot. A slot the container has not measured yet uses
## the optimistic full width, so the chips never flicker through a narrower layout.
func _ribbon_width(slot: Control) -> float:
	if not is_instance_valid(slot):
		return RIBBON_MIN_WIDTH
	var slot_width := slot.get_global_rect().size.x
	if slot_width <= 0.0:
		return RIBBON_MAX_WIDTH
	return clampf(slot_width - RIBBON_SLOT_INSET * 2.0, RIBBON_MIN_WIDTH, RIBBON_MAX_WIDTH)


## Pin the ribbon under its own actor: centred on the slot, just below the actor's feet.
func _place(meter: CombatActorMeter, slot: Control, width: float) -> void:
	if not is_instance_valid(slot) or not slot.is_visible_in_tree():
		meter.hide()
		return
	var height := maxf(RIBBON_HEIGHT, meter.get_combined_minimum_size().y)
	# The container sorts on the next layout pass; keep the readout visible until then.
	if row.size.x <= 0.0:
		meter.size = Vector2(width, height)
		return
	height = maxf(height, row.size.y)
	var origin := row.get_global_rect().position
	var rect := slot.get_global_rect()
	var x := rect.position.x + (rect.size.x - width) * 0.5 - origin.x
	var y := rect.end.y - origin.y
	var target := Vector2(roundf(x), roundf(clampf(y, 0.0, maxf(0.0, row.size.y - height))))
	if meter.position != target:
		meter.position = target
	if meter.size != Vector2(width, height):
		meter.size = Vector2(width, height)


func _clear() -> void:
	if is_instance_valid(_battle) and _battle.tree_exiting.is_connected(_clear):
		_battle.tree_exiting.disconnect(_clear)
	if is_instance_valid(row):
		row.get_parent().remove_child(row)
		row.queue_free()
	row = null
	_battle = null
	_deck = null
	_party = null
	_enemies = null
	_coat_bonuses.clear()
