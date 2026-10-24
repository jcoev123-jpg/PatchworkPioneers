class_name LiveRunTerminalResultPanel
extends Control
## Standalone M03 terminal presentation. An external host owns mounting and
## title/new-run navigation; this view only requests the return action.
## Never observes combat or advances, settles or mutates a run.

signal return_to_title_requested

## The one illustrated stage texture this view may use. It is already imported
## by the reward panel's sewn camp, so the terminal result joins the established
## patchwork identity without introducing new art. Resolution is exists-guarded:
## a missing picture hides only this layer and never the result.
const CAMP_BACKDROP := "res://assets/paper/backgrounds/reward_camp.png"
## Conspicuous stitched perimeter: cream thread walked on the dark felt mat and
## dark thread sewn just inside the parchment's own border.
const FELT_THREAD := Color("#e6d6b5")
const PAPER_THREAD := Color("#6b5343")
const FELT_STITCH_INSET := 8.0
const PAPER_STITCH_INSET := 6.0

@onready var backdrop_art: TextureRect = $ResultBackdropArt
@onready var felt_mat: PanelContainer = $FeltMat
@onready var paper_panel: PanelContainer = $PaperPanel
@onready var title_label: Label = $PaperPanel/ContentMargin/ResultContent/ResultTitle
@onready var description_label: Label = $PaperPanel/ContentMargin/ResultContent/ResultDescription
@onready var summary_label: Label = $PaperPanel/ContentMargin/ResultContent/RunSignature
@onready var return_button: Button = $PaperPanel/ContentMargin/ResultContent/ReturnButton
@onready var top_stitches: Label = $PaperPanel/ContentMargin/ResultContent/TopStitches
@onready var bottom_stitches: Label = $PaperPanel/ContentMargin/ResultContent/BottomStitches
@onready var stitched_section: PanelContainer = $PaperPanel/ContentMargin/ResultContent/StitchedSection
@onready var stitched_heading: Label = $PaperPanel/ContentMargin/ResultContent/StitchedSection/DetailMargin/DetailContent/DetailTitle
@onready var stitched_scroll: ScrollContainer = $PaperPanel/ContentMargin/ResultContent/StitchedSection/DetailMargin/DetailContent/StitchedScroll
@onready var stitched_rows: VBoxContainer = $PaperPanel/ContentMargin/ResultContent/StitchedSection/DetailMargin/DetailContent/StitchedScroll/StitchedRows

var _generation: int = 0
var _is_open: bool = false
var _return_requested: bool = false
var _can_return: bool = false
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
	var battles_resolved: int = (settled as Array).size()
	var signature: Dictionary = _validated_signature()
	_can_return = signature.get("ok") == true
	var signature_text := _format_signature(signature) if _can_return else "Summary unavailable"
	summary_label.text = "Battles resolved: %d\n%s" % [battles_resolved, signature_text]
	_clear_details()
	if _can_return:
		_populate_details(signature)
	return_button.disabled = not _can_return
	return_button.focus_mode = Control.FOCUS_ALL if _can_return else Control.FOCUS_NONE
	if _can_return:
		_button_connection = _on_return_pressed.bind(_generation, return_button)
		return_button.pressed.connect(_button_connection)
	visible = true
	return true


## Hides, releases keyboard focus and invalidates any retained old callback.
func close_result() -> void:
	_generation += 1
	_is_open = false
	_return_requested = false
	_can_return = false
	_presented_status = ""
	visible = false
	if not is_node_ready():
		return
	if _button_connection.is_valid() and return_button.pressed.is_connected(_button_connection):
		return_button.pressed.disconnect(_button_connection)
	_button_connection = Callable()
	return_button.disabled = true
	return_button.focus_mode = Control.FOCUS_NONE
	return_button.release_focus()
	_clear_details()
	title_label.text = ""
	description_label.text = ""
	summary_label.text = ""


## Only the live App-parent's committed, matching ledger can authorize counts.
## A never-bound wardrobe can be projected with empty wear slots; a stale
## *bound* wardrobe must not be replaced with that zero-wear projection.
func _validated_signature() -> Dictionary:
	var app: Variant = get_parent()
	if app == null or app.get_script() == null \
			or app.get_script().resource_path != "res://scripts/app.gd":
		return {}
	var carry := app.party_carryover as RunTornCarryover
	if carry == null or not carry.is_valid():
		return {}
	var carry_state: Dictionary = carry.read_state()
	if carry_state.get("ok") != true or carry_state.get("heroes") != app.run_heroes:
		return {}
	var wardrobe: RunPatchWardrobe = carry._wardrobe
	if wardrobe == null:
		# The valid first-run state owns patches but has never sewn one. No
		# catalog slots or gameplay bindings are inferred or altered here.
		wardrobe = RunPatchWardrobe.new(app.run_heroes, app.run_trinkets, [],
			app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
	else:
		if not wardrobe.is_valid():
			return {}
		var snapshot: Dictionary = wardrobe.get_snapshot()
		if snapshot.get("heroes") != app.run_heroes or snapshot.get("owned") != app.run_trinkets \
				or snapshot.get("scraps") != app.run_scraps or snapshot.get("gold") != app.session_gold \
				or snapshot.get("cards") != app.run_deck:
			return {}
	var display_wardrobe := _canonical_signature_wardrobe(wardrobe)
	if display_wardrobe == null:
		return {}
	var summary: Dictionary = RunSignatureSummary.summarize(app.run_deck,
		app.run_stitch_descriptors, app.run_next_stitch_id, display_wardrobe)
	if summary.get("ok") != true:
		return {}
	return summary


## The summary authority requires Warden/Seamstress/Tinker row order, but an
## authentic run can exchange their battlefield positions. Rebuild a DETACHED
## presentation-only wardrobe from an already valid and matched source,
## preserving every named wear slot; never normalize the actual run or its
## receipts. A malformed source or impossible wear assignment still fails shut.
func _canonical_signature_wardrobe(source: RunPatchWardrobe) -> RunPatchWardrobe:
	if source == null or not source.is_valid():
		return null
	var state: Dictionary = source.get_snapshot()
	var heroes: Array = state.get("heroes", [])
	if heroes.size() != RunSignatureSummary.HERO_IDS.size():
		return null
	var by_id: Dictionary = {}
	for hero in heroes:
		if not hero is Dictionary or not RunSignatureSummary.HERO_IDS.has(hero.get("id")) \
				or by_id.has(hero.get("id")):
			return null
		by_id[hero["id"]] = hero.duplicate(true)
	var canonical: Array = []
	for i in range(RunSignatureSummary.HERO_IDS.size()):
		var hero_id: String = RunSignatureSummary.HERO_IDS[i]
		if not by_id.has(hero_id):
			return null
		var hero_copy: Dictionary = by_id[hero_id]
		hero_copy["position"] = i + 1
		canonical.append(hero_copy)
	if canonical == heroes:
		return source
	var definitions: Variant = state.get("definitions")
	if not definitions is Dictionary:
		return null
	var records: Array = []
	for patch_id in definitions:
		records.append({"id": patch_id, "slot": definitions[patch_id]})
	var projection := RunPatchWardrobe.new(canonical, state.get("owned"),
		records, state.get("scraps"), state.get("gold"), state.get("cards"),
		state.get("seed"), true)
	if not projection.is_valid():
		return null
	var worn: Variant = state.get("worn")
	if not worn is Dictionary or worn.size() != RunSignatureSummary.HERO_IDS.size():
		return null
	for hero_id in RunSignatureSummary.HERO_IDS:
		var slots: Variant = worn.get(hero_id)
		if not slots is Dictionary or slots.size() != RunSignatureSummary.SLOTS.size():
			return null
		for slot in RunSignatureSummary.SLOTS:
			var patch_id: Variant = slots.get(slot)
			if typeof(patch_id) != TYPE_STRING:
				return null
			if not patch_id.is_empty() and not projection.sew(patch_id, hero_id, slot,
					"signature_%s_%s" % [hero_id, slot], projection.get_snapshot()).get("ok"):
				return null
	var checked: Dictionary = projection.get_snapshot()
	if checked.get("worn") != worn or checked.get("owned") != state.get("owned") \
			or checked.get("scraps") != state.get("scraps") or checked.get("gold") != state.get("gold") \
			or checked.get("cards") != state.get("cards"):
		return null
	return projection


## This is a read-only view of the signature's current deck-ordered cards.
## Resolve each authored half by ID, with its original owner/order; never
## invent half names from stitched IDs or recalculate any combat effects.
func _populate_details(summary: Dictionary) -> void:
	var cards: Array = summary.get("current_stitched_cards", [])
	if cards.is_empty():
		return
	for index in range(cards.size()):
		var descriptor: Dictionary = cards[index]
		var owners: Array = descriptor["owners"]
		var halves: Array = descriptor["half_ids"]
		var first: Dictionary = RunRestStitchCards.resolve_card_definition(halves[0])
		var second: Dictionary = RunRestStitchCards.resolve_card_definition(halves[1])
		if first.is_empty() or second.is_empty():
			_clear_details()
			return
		var row := PanelContainer.new()
		row.name = "KeptCard%d" % index
		var felt := StyleBoxFlat.new()
		felt.bg_color = Color("#f2e5cb")
		felt.border_color = Color("#8d7560")
		felt.set_border_width_all(1)
		felt.set_corner_radius_all(5)
		row.add_theme_stylebox_override("panel", felt)
		var inset := MarginContainer.new()
		inset.name = "CardInset"
		for side in ["left", "right"]:
			inset.add_theme_constant_override("margin_" + side, 10)
		for side in ["top", "bottom"]:
			inset.add_theme_constant_override("margin_" + side, 5)
		row.add_child(inset)
		var stack := VBoxContainer.new()
		stack.name = "CardLines"
		stack.add_theme_constant_override("separation", 2)
		inset.add_child(stack)
		var name_label := Label.new()
		name_label.name = "Composite"
		name_label.text = "%s  ·  %d energy" % [descriptor["display_name"], descriptor["cost"]]
		name_label.add_theme_color_override("font_color", Color("#28363c"))
		name_label.add_theme_font_size_override("font_size", 16)
		stack.add_child(name_label)
		var halves_label := Label.new()
		halves_label.name = "Halves"
		halves_label.text = "1 · %s (%s)    →    2 · %s (%s)" % [
			first["display_name"], str(owners[0]).capitalize(),
			second["display_name"], str(owners[1]).capitalize()]
		halves_label.add_theme_color_override("font_color", Color("#334750"))
		halves_label.add_theme_font_size_override("font_size", 14)
		halves_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(halves_label)
		stitched_rows.add_child(row)
	stitched_section.show()


func _clear_details() -> void:
	if not is_node_ready():
		return
	stitched_section.hide()
	stitched_scroll.scroll_vertical = 0
	for row in stitched_rows.get_children():
		stitched_rows.remove_child(row)
		row.queue_free()


## Consume the validated projection in its original hero and slot order.
## Empty cells stay explicitly empty instead of resembling worn inventory.
## Names and slot labels are presentation only: descriptors are authored, and
## worn IDs are never recomputed into effects here.
func _format_signature(summary: Dictionary) -> String:
	var lines: Array[String] = [
		"Stitched: %d made · %d in deck" % [summary.stitched_created, summary.stitched_current],
		"Patches worn: %d" % summary.worn_total,
	]
	var crafted := _crafted_cards_line(summary)
	if not crafted.is_empty():
		lines.append(crafted)
	for hero in summary.heroes:
		var slots: Array[String] = []
		for slot in RunSignatureSummary.SLOTS:
			var patch_id: String = hero.slots[slot]
			slots.append("%s %s" % [slot, _patch_label(patch_id)])
		lines.append("%s  %s" % [str(hero.hero_id).capitalize(), "  ·  ".join(slots)])
	return "\n".join(lines)


## One compact recap line naming at most two currently held stitched cards in
## their supplied deck order, using the descriptor's authored display_name.
## Never falls back to an opaque stitched_ ID; an empty current list adds none.
func _crafted_cards_line(summary: Dictionary) -> String:
	var ids: Variant = summary.get("stitched_ids")
	var descriptors: Variant = summary.get("descriptors")
	if typeof(ids) != TYPE_ARRAY or ids.is_empty() or typeof(descriptors) != TYPE_DICTIONARY:
		return ""
	var names: Array[String] = []
	for index in range(mini(ids.size(), 2)):
		var descriptor: Variant = descriptors.get(ids[index])
		if typeof(descriptor) != TYPE_DICTIONARY:
			continue
		var display_name: Variant = descriptor.get("display_name")
		if typeof(display_name) != TYPE_STRING or display_name.is_empty():
			continue
		names.append(display_name)
	if names.is_empty():
		return ""
	var line := "Crafted: " + "  ·  ".join(names)
	var remaining: int = ids.size() - names.size()
	if remaining > 0:
		line += " +%d more" % remaining
	return line


## Readable slot label: underscores become spaces and each word is title-cased.
func _patch_label(patch_id: String) -> String:
	if patch_id.is_empty():
		return "-"
	var label := patch_id.replace("_", " ").strip_edges()
	if label.is_empty():
		return "-"
	return label.capitalize()


func has_open_result() -> bool:
	return _is_open


## Read-only presentation state, not an authority for combat or settlement.
func get_presented_status() -> String:
	return _presented_status


func _on_return_pressed(generation: int, button: Button) -> void:
	if not _is_open or not _can_return or _return_requested or generation != _generation:
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
	_style_felt_stage()
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("#e8d9ba")
	paper.border_color = Color("#5a4738")
	paper.set_border_width_all(5)
	paper.set_corner_radius_all(12)
	paper.shadow_color = Color(0.03, 0.05, 0.06, 0.85)
	paper.shadow_size = 16
	paper_panel.add_theme_stylebox_override("panel", paper)
	if paper_panel.draw.get_connections().is_empty():
		paper_panel.draw.connect(_draw_paper_stitches.bind(paper_panel))
		paper_panel.resized.connect(paper_panel.queue_redraw)
	# The outcome is sewn onto its own pale plaque, above a bounded ledger
	# strip, so the heading, the sentence and the run summary read as three
	# distinct layers instead of one flat block of text.
	var plaque := StyleBoxFlat.new()
	plaque.bg_color = Color("#f4e9d0")
	plaque.border_color = Color("#6e5a46")
	plaque.set_border_width_all(3)
	plaque.set_corner_radius_all(9)
	plaque.content_margin_left = 26
	plaque.content_margin_right = 26
	plaque.content_margin_top = 4
	plaque.content_margin_bottom = 6
	title_label.add_theme_stylebox_override("normal", plaque)
	title_label.add_theme_color_override("font_color", Color("#24343b"))
	title_label.add_theme_font_size_override("font_size", 50)
	description_label.add_theme_color_override("font_color", Color("#33454b"))
	description_label.add_theme_font_size_override("font_size", 21)
	var ledger := StyleBoxFlat.new()
	ledger.bg_color = Color("#f0e5cd")
	ledger.border_color = Color("#a08a6d")
	ledger.set_border_width_all(2)
	ledger.set_corner_radius_all(7)
	ledger.content_margin_left = 18
	ledger.content_margin_right = 18
	ledger.content_margin_top = 8
	ledger.content_margin_bottom = 8
	summary_label.add_theme_stylebox_override("normal", ledger)
	summary_label.add_theme_color_override("font_color", Color("#2f4147"))
	summary_label.add_theme_font_size_override("font_size", 17)
	summary_label.add_theme_constant_override("line_spacing", 2)
	stitched_heading.add_theme_color_override("font_color", Color("#28363c"))
	stitched_heading.add_theme_font_size_override("font_size", 16)
	var detail_paper := StyleBoxFlat.new()
	detail_paper.bg_color = Color("#e9dabc")
	detail_paper.border_color = Color("#78614e")
	detail_paper.set_border_width_all(3)
	detail_paper.set_corner_radius_all(7)
	stitched_section.add_theme_stylebox_override("panel", detail_paper)
	var scrollbar := stitched_scroll.get_v_scroll_bar()
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#d1bc99")
	track.set_corner_radius_all(3)
	scrollbar.add_theme_stylebox_override("scroll", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grip := StyleBoxFlat.new()
		grip.bg_color = Color("#75614f")
		grip.set_corner_radius_all(3)
		scrollbar.add_theme_stylebox_override(state, grip)
	for label in [top_stitches, bottom_stitches]:
		label.add_theme_color_override("font_color", Color("#85715b"))
		label.add_theme_font_size_override("font_size", 16)

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


## Dark felt mat framed by a cream running stitch, laid under the parchment.
## The mat ignores the mouse and draws only in its own felt border, so it never
## covers the parchment, its text or the sole Return action.
func _style_felt_stage() -> void:
	var felt := StyleBoxFlat.new()
	felt.bg_color = Color("#463b33")
	felt.border_color = Color("#8a7462")
	felt.set_border_width_all(2)
	felt.set_corner_radius_all(18)
	felt.shadow_color = Color(0.03, 0.05, 0.06, 0.8)
	felt.shadow_size = 14
	felt_mat.add_theme_stylebox_override("panel", felt)
	felt_mat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if felt_mat.draw.get_connections().is_empty():
		felt_mat.draw.connect(_draw_felt_stitches.bind(felt_mat))
		felt_mat.resized.connect(felt_mat.queue_redraw)
	apply_backdrop_art(CAMP_BACKDROP)


## Exists-guarded texture lookup. A missing or unreadable resource returns null
## instead of a load error, so the optional illustrated layer can simply vanish.
static func guarded_texture(path: String) -> Texture2D:
	if path.strip_edges().is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## Mount or remove the illustrated stage. The settled result never depends on
## this layer: a missing texture only hides the art (and its shade), leaving the
## slate, felt mat, stitched parchment and every line of the result readable.
func apply_backdrop_art(path: String) -> bool:
	if not is_node_ready():
		return false
	var texture := guarded_texture(path)
	backdrop_art.texture = texture
	backdrop_art.visible = texture != null
	if texture == null:
		return false
	_mount_backdrop_shade()
	return true


## A soft dark wash over the camp picture keeps the cream parchment and its
## dark ink legible against the brighter art. It lives inside the art node, so
## hiding the art layer hides the wash with it.
func _mount_backdrop_shade() -> void:
	if backdrop_art.get_node_or_null("ResultBackdropShade") != null:
		return
	var shade := ColorRect.new()
	shade.name = "ResultBackdropShade"
	shade.color = Color(0.05, 0.07, 0.09, 0.3)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop_art.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Dark running stitches around the parchment, inside its border and clear of
## every content margin.
func _draw_paper_stitches(canvas: Control) -> void:
	_stitch_rect(canvas, Rect2(Vector2.ZERO, canvas.size).grow(-PAPER_STITCH_INSET),
		PAPER_THREAD, 2.5, 9.0)


## Cream running stitches on the dark felt mat, framing the parchment.
func _draw_felt_stitches(canvas: Control) -> void:
	_stitch_rect(canvas, Rect2(Vector2.ZERO, canvas.size).grow(-FELT_STITCH_INSET),
		FELT_THREAD, 3.0, 10.0)


func _stitch_rect(canvas: CanvasItem, rect: Rect2, color: Color, width: float, dash: float) -> void:
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)]
	for index in range(corners.size()):
		canvas.draw_dashed_line(corners[index], corners[(index + 1) % corners.size()],
			color, width, dash)
