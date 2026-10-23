class_name LiveRestPatchResewPicker
extends Control
## Reusable, unmounted Rest view. A caller owns the current run/route,
## creates a fresh operation ID, commits re_sew, then calls present again.

signal re_sew_requested(patch_id: String, from_hero: String, to_hero: String,
		rest_node_id: String, exact_snapshot: Dictionary)

const CREAM := Color("#eee2ca")
const PAPER := Color("#c8b99e")
const SLATE := Color("#252f39")
const STITCH := Color("#7f8b89")

var source_selector: OptionButton
var destination_selector: OptionButton
var confirm_button: Button
var scraps_label: Label
var preview_label: Label
var feedback_label: Label

var _wardrobe: RunPatchWardrobe
var _torn: RunTornMending
var _snapshot: Dictionary = {}
var _node_id := ""
var _options: Array = []
var _sources: Array = []
var _destinations: Array = []
var _pending := false


func _ready() -> void:
	_build()
	_clear("Awaiting an active Rest")


func present(wardrobe: RunPatchWardrobe, torn: RunTornMending,
		exact_snapshot: Dictionary, rest_node_id: String,
		owner_message: String = "") -> bool:
	if source_selector == null:
		_build()
	_wardrobe = wardrobe
	_torn = torn
	_snapshot = exact_snapshot.duplicate(true)
	_node_id = rest_node_id
	_pending = false
	var model := RunRestPatchResewOptions.project(wardrobe, torn, _snapshot, _node_id)
	if model.get("ok") != true:
		_clear("Re-sew unavailable (closed Rest, stale state, or insufficient scraps)")
		if wardrobe != null and wardrobe.is_valid() and _snapshot == wardrobe.get_snapshot():
			scraps_label.text = "Scraps: %d" % int(_snapshot.get("scraps", 0))
		return false
	_options = model["options"].duplicate(true)
	scraps_label.text = "Scraps: %d" % model["scraps"]
	feedback_label.text = owner_message if not owner_message.is_empty() else "Choose a patch and a recipient."
	source_selector.clear()
	_sources.clear()
	for option in _options:
		var already := false
		for source in _sources:
			if source["patch_id"] == option["patch_id"] and source["from_hero"] == option["from_hero"]:
				already = true
				break
		if already:
			continue
		_sources.append({"patch_id": option["patch_id"], "from_hero": option["from_hero"]})
		source_selector.add_item("%s • %s • %s%s" % [
			_nice(option["from_hero"]), option["slot"], _nice(option["patch_id"]),
			" (torn/inactive)" if not option["source_active"] else ""])
	source_selector.disabled = _sources.is_empty()
	if not _sources.is_empty():
		source_selector.select(0)
	_refresh_destinations()
	return true


func selected_option() -> Dictionary:
	if source_selector == null or _pending or _sources.is_empty() or _destinations.is_empty():
		return {}
	var i := destination_selector.selected
	if i < 0 or i >= _destinations.size():
		return {}
	return _destinations[i].duplicate(true)


func _request_selected() -> void:
	if _pending or not is_visible_in_tree() or not confirm_button.is_visible_in_tree() \
			or confirm_button.disabled or source_selector.disabled or destination_selector.disabled:
		return
	var option := selected_option()
	if option.is_empty():
		return
	# Only the ledger can commit; revalidate both legality and authored powers.
	var model := RunRestPatchResewOptions.project(_wardrobe, _torn, _snapshot, _node_id)
	var forecast := RunRestPatchResewOptions.forecast(
		_wardrobe, _torn, _snapshot, _node_id, option)
	if model.get("ok") != true or not model["options"].has(option) \
			or forecast.get("ok") != true:
		_clear("Choice expired: refresh the Rest before trying again")
		return
	_pending = true
	confirm_button.disabled = true
	source_selector.disabled = true
	destination_selector.disabled = true
	feedback_label.text = "Waiting for run owner to accept or reject this request…"
	re_sew_requested.emit(option["patch_id"], option["from_hero"],
		option["to_hero"], _node_id, _snapshot.duplicate(true))


func _refresh_destinations(_unused: int = 0) -> void:
	destination_selector.clear()
	_destinations.clear()
	if _sources.is_empty() or source_selector.selected < 0:
		_update_preview()
		return
	var chosen: Dictionary = _sources[source_selector.selected]
	for option in _options:
		if option["patch_id"] != chosen["patch_id"] or option["from_hero"] != chosen["from_hero"]:
			continue
		_destinations.append(option.duplicate(true))
		destination_selector.add_item(_nice(option["to_hero"]) + (
			" (torn/inactive)" if not option["destination_active"] else ""))
	if not _destinations.is_empty():
		destination_selector.select(0)
	_update_preview()


func _update_preview(_unused: int = 0) -> void:
	var option := selected_option()
	if option.is_empty():
		preview_label.text = "No eligible re-sew choices"
		confirm_button.disabled = true
		destination_selector.disabled = _pending or _destinations.is_empty()
		return
	var estimate := RunRestPatchResewOptions.forecast(
		_wardrobe, _torn, _snapshot, _node_id, option)
	if estimate.get("ok") != true:
		_clear("Preview expired: refresh the Rest before trying again")
		return
	var exchange := "empty destination" if estimate["kind"] == "MOVE" else (
		"swap with %s" % _nice(estimate["exchanged_id"]))
	preview_label.text = "%s • %s • %s → %s • %s • Cost: %d scrap\n%s\n%s\n%s\n%s" % [
		estimate["kind"], estimate["slot"], _nice(estimate["source"]["hero_id"]),
		_nice(estimate["destination"]["hero_id"]), exchange, estimate["cost"],
		_wearer_preview(estimate["source"], "before"),
		_wearer_preview(estimate["source"], "after"),
		_wearer_preview(estimate["destination"], "before"),
		_wearer_preview(estimate["destination"], "after")]
	confirm_button.disabled = _pending
	destination_selector.disabled = _pending or _destinations.is_empty()


static func _wearer_preview(wearer: Dictionary, phase: String) -> String:
	var state: Dictionary = wearer[phase]
	var summary := []
	for slot in RunRestPatchResewOptions.SLOTS:
		var patch: Dictionary = state["slots"][slot]
		var id: String = patch["id"]
		if id == "":
			summary.append("%s empty" % slot)
		else:
			var activity := "active" if patch["active"] else "dormant"
			var power: String = " — " + patch["effect"] if not patch["effect"].is_empty() else ""
			summary.append("%s %s (%s)%s" % [slot, _nice(id), activity, power])
	return "%s %s • HP %d/%d, effective cap %d • %s" % [
		_nice(wearer["hero_id"]), phase.to_upper(),
		state["hp"], state["base_max_hp"], state["effective_max_hp"],
		" | ".join(summary)]


func _clear(message: String) -> void:
	_pending = false
	_options.clear()
	_sources.clear()
	_destinations.clear()
	source_selector.clear()
	destination_selector.clear()
	source_selector.disabled = true
	destination_selector.disabled = true
	confirm_button.disabled = true
	preview_label.text = "No eligible re-sew choices"
	feedback_label.text = message
	scraps_label.text = "Scraps: --"


func _build() -> void:
	if source_selector != null:
		return
	mouse_filter = Control.MOUSE_FILTER_PASS
	var paper := StyleBoxFlat.new()
	paper.bg_color = SLATE
	paper.border_color = STITCH
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(8)
	var panel := PanelContainer.new()
	panel.name = "StitchedPaperRestPanel"
	panel.add_theme_stylebox_override("panel", paper)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -420
	panel.offset_right = 420
	panel.offset_top = -310
	panel.offset_bottom = 310
	add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 24)
	padding.add_theme_constant_override("margin_right", 24)
	padding.add_theme_constant_override("margin_top", 12)
	padding.add_theme_constant_override("margin_bottom", 12)
	panel.remove_child(body)
	panel.add_child(padding)
	padding.add_child(body)
	var title := _label("REST  /  RE-SEW PATCHES", 23)
	body.add_child(title)
	var rule := _label("Each transfer costs 1 scrap. Your Heal / Upgrade / Stitch choice stays available.", 13)
	body.add_child(rule)
	scraps_label = _label("Scraps: --", 18)
	body.add_child(scraps_label)
	body.add_child(_label("Worn patch / source hero", 15))
	source_selector = OptionButton.new()
	source_selector.name = "SourcePatch"
	source_selector.custom_minimum_size = Vector2(0, 40)
	source_selector.focus_mode = Control.FOCUS_ALL
	source_selector.item_selected.connect(_refresh_destinations)
	_style_button(source_selector)
	body.add_child(source_selector)
	body.add_child(_label("Destination hero (same slot only)", 15))
	destination_selector = OptionButton.new()
	destination_selector.name = "DestinationHero"
	destination_selector.custom_minimum_size = Vector2(0, 40)
	destination_selector.focus_mode = Control.FOCUS_ALL
	destination_selector.item_selected.connect(_update_preview)
	_style_button(destination_selector)
	body.add_child(destination_selector)
	preview_label = _label("No eligible re-sew choices", 14)
	preview_label.custom_minimum_size = Vector2(0, 190)
	body.add_child(preview_label)
	confirm_button = Button.new()
	confirm_button.name = "ConfirmResew"
	confirm_button.text = "Re-sew (1 scrap)"
	confirm_button.custom_minimum_size = Vector2(0, 47)
	confirm_button.focus_mode = Control.FOCUS_ALL
	_style_button(confirm_button)
	confirm_button.pressed.connect(_request_selected)
	body.add_child(confirm_button)
	feedback_label = _label("", 13)
	body.add_child(feedback_label)


func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", CREAM)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _style_button(button: Control) -> void:
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_focus_color", CREAM)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#3a4851")
	box.border_color = PAPER
	box.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("focus", box.duplicate())


static func _nice(id: String) -> String:
	return id.replace("_", " ").capitalize()
