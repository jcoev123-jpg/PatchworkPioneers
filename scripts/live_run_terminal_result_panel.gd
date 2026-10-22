class_name LiveRunTerminalResultPanel
extends Control
## Standalone M03 terminal presentation. An external host owns mounting and
## title/new-run navigation; this view only requests the return action.
## Never observes combat or advances, settles or mutates a run.

signal return_to_title_requested

@onready var paper_panel: PanelContainer = $PaperPanel
@onready var title_label: Label = $PaperPanel/ContentMargin/ResultContent/ResultTitle
@onready var description_label: Label = $PaperPanel/ContentMargin/ResultContent/ResultDescription
@onready var summary_label: Label = $PaperPanel/ContentMargin/ResultContent/RunSignature
@onready var return_button: Button = $PaperPanel/ContentMargin/ResultContent/ReturnButton
@onready var top_stitches: Label = $PaperPanel/ContentMargin/ResultContent/TopStitches
@onready var bottom_stitches: Label = $PaperPanel/ContentMargin/ResultContent/BottomStitches

var _generation: int = 0
var _is_open: bool = false
var _return_requested: bool = false
var _presented_status: String = ""
var _button_connection: Callable


func _ready() -> void:
	_apply_patchwork_style()
	close_result()


## Only an already-settled, witnessed terminal RunActBattleOutcome is eligible.
## Rejection leaves a closed panel closed and never replaces a current result.
func open_result(latch: RunActBattleOutcome) -> bool:
	if not is_node_ready() or _is_open or latch == null:
		return false
	var state: Dictionary = latch.get_state()
	var status: Variant = state.get("run_status")
	if status != RunActBattleOutcome.VICTORY and status != RunActBattleOutcome.DEFEAT:
		return false
	if state.get("pending_node_id") != "":
		return false
	var settled: Variant = state.get("settled_node_ids")
	if not settled is Array or settled.is_empty():
		return false

	_generation += 1
	_is_open = true
	_return_requested = false
	_presented_status = status
	title_label.text = "Victory" if status == RunActBattleOutcome.VICTORY else "Defeat"
	description_label.text = ("The final boss has fallen. The run is complete."
		if status == RunActBattleOutcome.VICTORY
		else "The party has fallen. The run has ended.")
	summary_label.text = _signature_text()
	return_button.disabled = false
	return_button.focus_mode = Control.FOCUS_ALL
	_button_connection = _on_return_pressed.bind(_generation, return_button)
	return_button.pressed.connect(_button_connection)
	visible = true
	return true


## Hides, releases keyboard focus and invalidates any retained old callback.
func close_result() -> void:
	_generation += 1
	_is_open = false
	_return_requested = false
	_presented_status = ""
	visible = false
	if not is_node_ready():
		return
	if _button_connection.is_valid() and return_button.pressed.is_connected(_button_connection):
		return_button.pressed.disconnect(_button_connection)
	_button_connection = Callable()
	return_button.disabled = true
	return_button.release_focus()
	title_label.text = ""
	description_label.text = ""
	summary_label.text = ""


## Only the live App-parent's committed, matching ledger can authorize counts.
## A never-bound wardrobe can be projected with empty wear slots; a stale
## *bound* wardrobe must not be replaced with that zero-wear projection.
func _signature_text() -> String:
	var app: Variant = get_parent()
	if app == null or app.get_script() == null \
			or app.get_script().resource_path != "res://scripts/app.gd":
		return "Summary unavailable"
	var carry := app.party_carryover as RunTornCarryover
	if carry == null or not carry.is_valid():
		return "Summary unavailable"
	var carry_state: Dictionary = carry.read_state()
	if carry_state.get("ok") != true or carry_state.get("heroes") != app.run_heroes:
		return "Summary unavailable"
	var wardrobe: RunPatchWardrobe = carry._wardrobe
	if wardrobe == null:
		# The valid first-run state owns patches but has never sewn one. No
		# catalog slots or gameplay bindings are inferred or altered here.
		wardrobe = RunPatchWardrobe.new(app.run_heroes, app.run_trinkets, [],
			app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
	else:
		if not wardrobe.is_valid():
			return "Summary unavailable"
		var snapshot: Dictionary = wardrobe.get_snapshot()
		if snapshot.get("heroes") != app.run_heroes or snapshot.get("owned") != app.run_trinkets \
				or snapshot.get("scraps") != app.run_scraps or snapshot.get("gold") != app.session_gold \
				or snapshot.get("cards") != app.run_deck:
			return "Summary unavailable"
	var summary: Dictionary = RunSignatureSummary.summarize(app.run_deck,
		app.run_stitch_descriptors, app.run_next_stitch_id, wardrobe)
	if summary.get("ok") != true:
		return "Summary unavailable"
	return _format_signature(summary)


## Consume the validated projection in its original hero and slot order.
## Empty cells stay explicitly empty instead of resembling worn inventory.
func _format_signature(summary: Dictionary) -> String:
	var lines: Array[String] = [
		"Stitched: %d made · %d in deck" % [summary.stitched_created, summary.stitched_current],
		"Patches worn: %d" % summary.worn_total,
	]
	for hero in summary.heroes:
		var slots: Array[String] = []
		for slot in RunSignatureSummary.SLOTS:
			var patch_id: String = hero.slots[slot]
			slots.append("%s %s" % [slot, patch_id.capitalize() if not patch_id.is_empty() else "-"])
		lines.append("%s  %s" % [str(hero.hero_id).capitalize(), "  ·  ".join(slots)])
	return "\n".join(lines)


func has_open_result() -> bool:
	return _is_open


## Read-only presentation state, not an authority for combat or settlement.
func get_presented_status() -> String:
	return _presented_status


func _on_return_pressed(generation: int, button: Button) -> void:
	if not _is_open or _return_requested or generation != _generation:
		return
	if not is_visible_in_tree() or not is_instance_valid(button) or button != return_button:
		return
	if not button.is_inside_tree() or not button.is_visible_in_tree() or button.disabled:
		return
	_return_requested = true
	button.disabled = true
	button.release_focus()
	return_to_title_requested.emit()


func _apply_patchwork_style() -> void:
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("#e5d5b5")
	paper.border_color = Color("#766351")
	paper.set_border_width_all(6)
	paper.set_corner_radius_all(14)
	paper.shadow_color = Color(0.04, 0.07, 0.08, 0.75)
	paper.shadow_size = 12
	paper_panel.add_theme_stylebox_override("panel", paper)
	title_label.add_theme_color_override("font_color", Color("#24343b"))
	title_label.add_theme_font_size_override("font_size", 48)
	description_label.add_theme_color_override("font_color", Color("#304046"))
	description_label.add_theme_font_size_override("font_size", 23)
	summary_label.add_theme_color_override("font_color", Color("#304046"))
	summary_label.add_theme_font_size_override("font_size", 18)
	for label in [top_stitches, bottom_stitches]:
		label.add_theme_color_override("font_color", Color("#85715b"))
		label.add_theme_font_size_override("font_size", 18)

	for state in ["normal", "hover", "pressed", "disabled"]:
		var wood := StyleBoxFlat.new()
		match state:
			"normal":
				wood.bg_color = Color("#bca17e")
			"hover":
				wood.bg_color = Color("#d2b58c")
			"pressed":
				wood.bg_color = Color("#9f805e")
			"disabled":
				wood.bg_color = Color("#948875")
		wood.border_color = Color("#6c5347")
		wood.set_border_width_all(3)
		wood.set_corner_radius_all(8)
		wood.content_margin_left = 32
		wood.content_margin_right = 32
		return_button.add_theme_stylebox_override(state, wood)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("#fff5d4")
	focus.set_border_width_all(4)
	focus.set_corner_radius_all(9)
	return_button.add_theme_stylebox_override("focus", focus)
	return_button.add_theme_color_override("font_color", Color("#27343a"))
	return_button.add_theme_color_override("font_hover_color", Color("#1e292e"))
	return_button.add_theme_color_override("font_pressed_color", Color("#1e292e"))
	return_button.add_theme_color_override("font_disabled_color", Color("#302e2d"))
	return_button.add_theme_font_size_override("font_size", 24)
