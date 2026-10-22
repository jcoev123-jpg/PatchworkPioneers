extends Node
## Reads fresh snapshots only; retained references identify the current presentation.
##
## Each presented actor owns one slim, unboxed ribbon pinned to the stage hem directly
## under its own actor slot: the HP number and bar, one Block value, and a single row of
## small hoverable status buttons. The snapshot text stays exactly as CombatActorMeter
## computes it; only the long-form paragraphs are hidden and reachable through the
## button tooltips, so no rule is duplicated on the stage.

## Narrow ribbon geometry: wide enough for three status chips, never wider than the slot.
const RIBBON_MAX_WIDTH := 200.0
const RIBBON_MIN_WIDTH := 84.0
const RIBBON_HEIGHT := 64.0
const RIBBON_SLOT_INSET := 4.0
## One chip per Bleed/Weak/Exposed stack plus the downed/slain badge.
const STATUS_BUTTONS := 4
const STATUS_ORDER := ["bleed", "weak", "exposed"]
## A fallen actor keeps its Bleed, Weak and Exposed stacks, so four chips can share one
## narrow row. Four entries use compact-but-complete labels ("Ble 3") and a font size
## that fits, so every name and count stays legible instead of being clipped.
const STATUS_SHORT := {"bleed": "Ble", "weak": "Wea", "exposed": "Exp"}
const CHIP_FONT_SIZES := [11, 10, 9]
const CHIP_SEPARATION := 2
const PATCH_LABELS := {"stitched_badge": "Stitched Badge", "spare_spool": "Spare Spool",
	"button_eye": "Button Eye", "pincushion_arm": "Pincushion Arm",
	"quilted_coat": "Quilted Coat"}

var row: Control
var _battle: Control
var _deck: CombatDeck
var _party: CombatParty
var _enemies: CombatEnemies


func _ready() -> void:
	get_parent().start_run_requested.connect(_sync_battle, CONNECT_DEFERRED)


func _process(_delta: float) -> void:
	_sync_battle()


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
	var patches := _current_patches(app)
	var needed_height := RIBBON_HEIGHT
	var forecast := {"ok": false, "heroes": []}
	if app.enemy_intents != null and app.enemy_intents.is_valid():
		forecast = CombatIncomingAttackPreview.new().forecast(
			_party.get_heroes(), _enemies.get_enemies(), app.enemy_intents.get_intents())
	for index in range(row.get_child_count()):
		var meter := row.get_child(index) as CombatActorMeter
		if meter == null:
			continue
		var side := "hero" if index < CombatParty.PARTY_SIZE else "enemy"
		var position: int = index + 1 if side == "hero" else index - CombatParty.PARTY_SIZE + 1
		var snapshot: Dictionary = _party.get_hero(position) if side == "hero" else _enemies.get_enemy(position)
		var shown := meter.show_actor(snapshot, side)
		_compact(meter)
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
	meter.hp_bar.custom_minimum_size = Vector2(0, 9)
	meter.block_text.add_theme_font_size_override("font_size", 12)
	meter.block_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meter.block_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	meter.block_bar.custom_minimum_size = Vector2(0, 6)
	meter.block_bar.hide()
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
	var buttons := HBoxContainer.new()
	buttons.name = "StatusButtons"
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.focus_mode = Control.FOCUS_NONE
	buttons.add_theme_constant_override("separation", 2)
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
## The label is sized by the container and never clipped, so shortening the text is the
## only way a chip can lose information; `_fit_chips` keeps every name and count whole.
func _make_status_button(index: int) -> Button:
	var button := Button.new()
	button.name = "StatusButton%d" % (index + 1)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_HELP
	button.custom_minimum_size = Vector2(0, 18)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = false
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.add_theme_font_size_override("font_size", CHIP_FONT_SIZES[0])
	button.add_theme_color_override("font_color", CombatActorMeter.INK)
	button.add_theme_color_override("font_hover_color", CombatActorMeter.INK)
	button.add_theme_color_override("font_pressed_color", CombatActorMeter.INK)
	button.add_theme_color_override("font_focus_color", CombatActorMeter.INK)
	_set_chip_style(button, false)
	button.hide()
	return button


## One chip style per chip kind: the fallen badge reads as a distinct sewn patch.
func _set_chip_style(button: Button, fallen: bool) -> void:
	if button.has_meta("fallen_chip") and bool(button.get_meta("fallen_chip")) == fallen:
		return
	button.set_meta("fallen_chip", fallen)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, _chip_style(state == "hover", fallen))


func _chip_style(hovered: bool, fallen: bool = false) -> StyleBoxFlat:
	var chip := StyleBoxFlat.new()
	if fallen:
		chip.bg_color = Color("5b3c34") if hovered else Color("46302b")
		chip.border_color = Color("e8b7a4") if hovered else Color("c0806e")
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


## Hide the long-form paragraphs after each show_actor without deleting or rewriting them.
func _compact(meter: CombatActorMeter) -> void:
	meter.actor_heading.hide()
	meter.block_bar.hide()
	meter.modifier_explanation.hide()
	meter.bleed_warning.hide()


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
	if definitions.has(RunPatchCoatRules.BONUS_ID) \
			and definitions[RunPatchCoatRules.BONUS_ID] != "COAT":
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
		RunPatchCoatRules.BONUS_ID:
			return "+%d effective maximum HP while living; no free healing." % \
				RunPatchCoatRules.BONUS
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


## One chip row per ribbon: authoritative counts and a clear fallen badge.
## Four entries (a fallen actor that keeps all three stacks) use compact labels and the
## largest font size whose complete labels fit the ribbon, so nothing is truncated.
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
	var tooltip := _compose_tooltip(meter, incoming)
	var buttons := meter.get_node("Padding/Content/StatusButtons") as HBoxContainer
	var fit := {"texts": [], "font_size": CHIP_FONT_SIZES[0]}
	if not entries.is_empty():
		fit = _fit_chips(buttons, entries, ribbon_width)
	for index in range(buttons.get_child_count()):
		var button := buttons.get_child(index) as Button
		var active := index < entries.size()
		var text := String(fit["texts"][index]) if active else ""
		var rule := tooltip if active else ""
		if button.visible != active:
			button.visible = active
		if button.text != text:
			button.text = text
		if button.tooltip_text != rule:
			button.tooltip_text = rule
		var font_size: int = fit["font_size"]
		if button.get_theme_font_size("font_size") != font_size:
			button.add_theme_font_size_override("font_size", font_size)
		if active:
			_set_chip_style(button, entries[index]["kind"] == "fallen")
	# Collapsing the whole container avoids an empty stitched box or hit target.
	buttons.visible = not entries.is_empty()


## Four entries can never spell every long status name in one narrow row, so they use
## the compact labels first; otherwise full names are preferred. Both shrink the font
## before anything could be cut off, and a chip never clips its own text.
func _fit_chips(buttons: HBoxContainer, entries: Array[Dictionary], ribbon_width: float) -> Dictionary:
	var available := maxf(0.0, ribbon_width - RIBBON_SLOT_INSET)
	var modes: Array = []
	if entries.size() >= STATUS_BUTTONS:
		modes.append(true)
	else:
		modes.append(false)
		modes.append(true)
	var narrowest: Dictionary = {}
	for mode in modes:
		var compact: bool = mode
		for size_value in CHIP_FONT_SIZES:
			var font_size: int = size_value
			var texts := _chip_texts(entries, compact)
			var total := 0.0
			for index in range(texts.size()):
				var button := buttons.get_child(index) as Button
				if button.text != texts[index]:
					button.text = texts[index]
				if button.get_theme_font_size("font_size") != font_size:
					button.add_theme_font_size_override("font_size", font_size)
				total += button.get_minimum_size().x
			total += float(CHIP_SEPARATION * (texts.size() - 1))
			narrowest = {"texts": texts, "font_size": font_size, "compact": compact}
			if total <= available:
				return narrowest
	return narrowest


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
