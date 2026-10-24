class_name LiveEventChoicePanel
extends Control
## Standalone, unwired presentation for an authored M04 Event.
## The open parchment reads as one story: the PatchHeading title and the fully
## wrapped description take only their natural height, and the authored choice
## tickets sit directly beneath them on the same sewn paper sheet (no stretch
## spacer). open_event() preserves the legacy ID-only signal.
## open_event_with_wallet() displays an opt-in, detached affordability forecast
## and emits an uncommitted wallet receipt for the run owner to validate.
## Neither mode updates the live run, owns RNG, or completes routed Events.
## Every mounted choice carries read-only hover text built from the authored
## action and the service-parsed outcome: exact signed gold/scraps, the zero
## change wording, or an honest unavailable placeholder. A wallet offering also
## repeats its own authoritative projected balance or exact shortfall.
## Each mounted choice also wears a small sewn number tag (1, 2, 3) and the open,
## visible panel answers the physical 1/2/3 keys by handing that authored-order
## choice to the same guarded pressed callback the mouse and focus path use. A
## two-choice offering simply has no third tag and ignores key 3.

## Printed when the service could not parse a choice outcome. No amount, name or
## affordability is invented for such a branch.
const OUTCOME_UNAVAILABLE := "Outcome unavailable: this choice cannot be settled."
## Printed on a legacy ticket whose authored outcome changes nothing.
const NO_CHANGE := "No change to gold or scraps."
## Printed on a legacy ticket that does change a resource. A legacy offering has
## no run wallet, so its neutral zero-wallet service preview says nothing about
## what this run can afford and is never shown as an affordability claim.
const AUTHORED_ONLY := "Authored outcome; your run's wallet is not checked here."
## The neutral wallet used only to parse legacy authored deltas.
const NEUTRAL_WALLET := {"gold": 0, "scraps": 0}
## Sewn number tag geometry on a choice ticket: a small felt square pinned to
## the left edge, clear of the centred authored text and the wallet forecast.
const CUE_INSET := 9.0
const CUE_SIZE := 26.0
## Sewn tag palette: pale paper felt, stitched thread border, dark ink numeral.
const CUE_PAPER := Color("#f3e7cc")
const CUE_THREAD := Color("#8a6f55")
const CUE_INK := Color("#3a2c22")

signal choice_committed(event_id: String, choice_id: String)
## Emits exactly one detached RunEventChoice receipt on a successful wallet
## selection: {ok: true, event_id: String, choice_id: String,
## wallet: {gold: int, scraps: int}}. This is NOT a live run commit.
signal wallet_choice_committed(result: Dictionary)

@onready var paper_panel: PanelContainer = $PaperPanel
@onready var title_label: Label = $PaperPanel/ContentMargin/EventContent/EventTitle
@onready var description_label: Label = $PaperPanel/ContentMargin/EventContent/EventDescription
@onready var choices_container: VBoxContainer = $PaperPanel/ContentMargin/EventContent/Choices
@onready var top_stitches: Label = $PaperPanel/ContentMargin/EventContent/TopStitches
@onready var bottom_stitches: Label = $PaperPanel/ContentMargin/EventContent/BottomStitches

var _selector: RunEventChoice = null
var _generation: int = 0
var _is_open: bool = false
var _choice_buttons: Array[Button] = []
## One sewn number tag per mounted choice, in the same authored order.
var _choice_cues: Array[Label] = []
var _bound_choices: Dictionary = {}
var _committed_choice: Dictionary = {}
var _wallet_mode: bool = false
var _offered_wallet: Dictionary = {}
var _wallet_previews: Dictionary = {}
var _wallet_label: Label = null


func _ready() -> void:
	_apply_patchwork_style()
	paper_panel.minimum_size_changed.connect(_fit_parchment, CONNECT_DEFERRED)
	close_event()


## Follow wrapped story and live selector minimums, including later picker mounts.
## Equal vertical anchors keep the complete content-sized parchment centred.
func _fit_parchment() -> void:
	var height := paper_panel.get_combined_minimum_size().y
	paper_panel.offset_top = -height * 0.5
	paper_panel.offset_bottom = height * 0.5


## Displays a detached authored offering; refuses invalid records and refuses
## to replace an open offer (including an already-claimed offer) until closed.
func open_event(event_record: Dictionary) -> bool:
	if _is_open:
		return false
	var offered := RunEventChoice.new(event_record)
	if not offered.is_valid():
		return false
	_mount_offering(offered, false, {}, [])
	return true


## Opt-in wallet-aware opening. The wallet must have *exactly* integer,
## nonnegative gold/scraps. Preview is the authoritative affordability source;
## a malformed wallet or preview fails before an offering is mounted.
func open_event_with_wallet(event_record: Dictionary, wallet: Variant) -> bool:
	if _is_open:
		return false
	var offered := RunEventChoice.new(event_record)
	if not offered.is_valid():
		return false
	var preview: Dictionary = offered.preview_wallet_choices(wallet)
	if not preview.get("ok", false) or preview.get("event_id") != event_record.get("id"):
		return false
	var entries: Variant = preview.get("choices")
	var snapshot := offered.get_event()
	if not entries is Array or (entries as Array).size() != (snapshot["choices"] as Array).size():
		return false
	for i in range((entries as Array).size()):
		var row: Variant = entries[i]
		if not row is Dictionary or row.get("choice_id") != snapshot["choices"][i]["id"]:
			return false
		if typeof(row.get("affordable")) != TYPE_BOOL:
			return false
	# preview_wallet_choices() has already strictly parsed both wallet fields.
	var clean_wallet := {"gold": wallet["gold"], "scraps": wallet["scraps"]}
	_mount_offering(offered, true, clean_wallet, entries)
	return true


func _mount_offering(offered: RunEventChoice, wallet_mode: bool, wallet: Dictionary, previews: Array) -> void:
	var snapshot: Dictionary = offered.get_event()
	# Legacy offerings parse their authored outcomes through the same service,
	# but from a neutral wallet: only the deltas are presentation truth here.
	var parsed_rows: Array = previews if wallet_mode else _legacy_previews(offered, snapshot)
	_generation += 1
	_selector = offered
	_is_open = true
	_wallet_mode = wallet_mode
	_offered_wallet = wallet.duplicate(true)
	_wallet_previews.clear()
	title_label.text = snapshot["title"]
	# The story keeps its natural wrapped height in both modes: the scene sets no
	# reserved description block, so the first authored ticket sits one small gap
	# below the text instead of after a stretch spacer.
	description_label.text = snapshot["description"]
	if wallet_mode:
		# Wallet offerings add their balance caption and keep each three-line
		# ticket's own 78px minimum; the story above still takes only its text.
		_wallet_label = Label.new()
		_wallet_label.name = "WalletBalance"
		_wallet_label.text = "Wallet  •  %d gold   /   %d scraps" % [_offered_wallet["gold"], _offered_wallet["scraps"]]
		_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_wallet_label.add_theme_color_override("font_color", Color("#343c3c"))
		_wallet_label.add_theme_font_size_override("font_size", 20)
		choices_container.get_parent().add_child(_wallet_label)
		choices_container.get_parent().move_child(_wallet_label, choices_container.get_index())
	for i in range(snapshot["choices"].size()):
		var choice: Dictionary = snapshot["choices"][i]
		var choice_id: String = choice["id"]
		var parsed_row: Dictionary = {}
		if i < parsed_rows.size() and parsed_rows[i] is Dictionary:
			parsed_row = parsed_rows[i]
		var button := Button.new()
		button.name = "Choice_%d" % _choice_buttons.size()
		button.text = choice["text"]
		button.tooltip_text = _choice_tooltip(choice["text"], parsed_row, wallet_mode)
		button.custom_minimum_size = Vector2(0.0, 56.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		_style_choice_button(button)
		if wallet_mode:
			var forecast: Dictionary = (previews[i] as Dictionary).duplicate(true)
			_wallet_previews[choice_id] = forecast
			var can_pay: bool = forecast["affordable"]
			var cost_text := "Gold %s   |   Scraps %s" % [
				_delta_label(forecast.get("gold_delta")),
				_delta_label(forecast.get("scraps_delta")),
			]
			# Third line is the authoritative forecast: the exact projected
			# after-wallet for affordable choices, or the exact shortfall that
			# makes a priced choice unavailable.
			button.text += "\n" + cost_text + "\n" + _forecast_line(forecast, _offered_wallet)
			button.custom_minimum_size.y = 78.0
			button.add_theme_font_size_override("font_size", 18)
			button.disabled = not can_pay
			button.focus_mode = Control.FOCUS_ALL if can_pay else Control.FOCUS_NONE
		else:
			button.text += "\n" + _authored_impact(parsed_row)
		_add_choice_cue(button, i)
		choices_container.add_child(button)
		_choice_buttons.append(button)
		_bound_choices[button] = choice_id
		# All bindings are captured at presentation time; caller dictionaries
		# and closed/reopened offerings cannot redirect an old pressed signal.
		button.pressed.connect(_on_choice_pressed.bind(offered, choice_id, _generation, button))
	visible = true


## A small sewn number tag pinned to the left edge of one choice ticket. It only
## repeats the authored position as a numeral: the button's own text, tooltip,
## action and layout stay exactly as authored, and the tag takes neither pointer
## nor keyboard focus.
func _add_choice_cue(button: Button, index: int) -> void:
	var cue := Label.new()
	cue.name = "ChoiceCue_%d" % index
	cue.text = str(index + 1)
	cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cue.focus_mode = Control.FOCUS_NONE
	cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cue.anchor_top = 0.5
	cue.anchor_bottom = 0.5
	cue.offset_left = CUE_INSET
	cue.offset_top = -CUE_SIZE * 0.5
	cue.offset_right = CUE_INSET + CUE_SIZE
	cue.offset_bottom = CUE_SIZE * 0.5
	var patch := StyleBoxFlat.new()
	patch.bg_color = CUE_PAPER
	patch.border_color = CUE_THREAD
	patch.set_border_width_all(2)
	patch.set_corner_radius_all(9)
	cue.add_theme_stylebox_override("normal", patch)
	cue.add_theme_color_override("font_color", CUE_INK)
	cue.add_theme_font_size_override("font_size", 15)
	button.add_child(cue)
	_choice_cues.append(cue)


## The service's own parsed rows for a legacy offering, read through a neutral
## zero wallet. Only the parsed deltas are used: the row's affordability flag
## describes that throwaway wallet, never the live run's. A malformed preview
## yields no rows so every ticket falls back to the honest placeholder.
func _legacy_previews(offered: RunEventChoice, snapshot: Dictionary) -> Array:
	var preview: Dictionary = offered.preview_wallet_choices(NEUTRAL_WALLET.duplicate(true))
	if preview.get("ok", false) != true or preview.get("event_id") != snapshot.get("id"):
		return []
	var rows: Variant = preview.get("choices")
	var choices: Array = snapshot["choices"]
	if not rows is Array or (rows as Array).size() != choices.size():
		return []
	for i in range((rows as Array).size()):
		var row: Variant = (rows as Array)[i]
		if not row is Dictionary or (row as Dictionary).get("choice_id") != choices[i]["id"]:
			return []
	return rows


## Read-only hover text for one offered choice. The authored action always comes
## first (the run owner's Moth removal and Dye upgrade live in that text), then
## the exact signed gold/scraps from the service-parsed row. A wallet offering
## finishes with its own authoritative projected balance or exact shortfall; a
## legacy offering finishes with the zero-change wording or the honest note that
## it does not read the run wallet. An unparsed outcome prints no numbers at all.
func _choice_tooltip(choice_text: String, forecast: Dictionary, wallet_mode: bool) -> String:
	var gold: Variant = forecast.get("gold_delta")
	var scraps: Variant = forecast.get("scraps_delta")
	if typeof(gold) != TYPE_INT or typeof(scraps) != TYPE_INT:
		return choice_text + "\n" + OUTCOME_UNAVAILABLE
	var lines := PackedStringArray()
	lines.append(choice_text)
	lines.append("Gold %s   |   Scraps %s" % [_delta_label(gold), _delta_label(scraps)])
	if wallet_mode:
		lines.append(_forecast_line(forecast, _offered_wallet))
	elif int(gold) == 0 and int(scraps) == 0:
		lines.append(NO_CHANGE)
	else:
		lines.append(AUTHORED_ONLY)
	return "\n".join(lines)


## Legacy tickets show only parsed authored deltas, never neutral-wallet
## affordability or a projected run balance. Unknown rows invent no amounts.
func _authored_impact(row: Dictionary) -> String:
	var gold: Variant = row.get("gold_delta")
	var scraps: Variant = row.get("scraps_delta")
	if typeof(gold) != TYPE_INT or typeof(scraps) != TYPE_INT:
		return OUTCOME_UNAVAILABLE
	var effects := PackedStringArray()
	if gold != 0:
		effects.append("Gold %+d" % gold)
	if scraps != 0:
		effects.append("Scraps %+d" % scraps)
	return NO_CHANGE if effects.is_empty() else "   |   ".join(effects)


func _delta_label(amount: Variant) -> String:
	if typeof(amount) != TYPE_INT:
		return "—"
	return "%+d" % amount


## One forecast line for a service preview row, derived only from the exact
## caller wallet and the row's own deltas — never invented arithmetic.
## Affordable rows print the service-projected after-balance; unaffordable rows
## print the exact missing amount per resource. Unknown/malformed deltas fall
## back to the neutral "UNAVAILABLE" flag.
func _forecast_line(forecast: Dictionary, wallet: Dictionary) -> String:
	if forecast.get("affordable", false) == true:
		var after: Variant = forecast.get("wallet")
		if after is Dictionary:
			return "After: %d gold | %d scraps" % [after["gold"], after["scraps"]]
		return "UNAVAILABLE"
	var needs := PackedStringArray()
	var gold_delta: Variant = forecast.get("gold_delta")
	var scraps_delta: Variant = forecast.get("scraps_delta")
	if typeof(gold_delta) == TYPE_INT and wallet.has("gold"):
		var missing_gold: int = -(int(wallet["gold"]) + gold_delta)
		if missing_gold > 0:
			needs.append("Need %d gold" % missing_gold)
	if typeof(scraps_delta) == TYPE_INT and wallet.has("scraps"):
		var missing_scraps: int = -(int(wallet["scraps"]) + scraps_delta)
		if missing_scraps > 0:
			needs.append("Need %d scraps" % missing_scraps)
	if needs.is_empty():
		return "UNAVAILABLE"
	return "   •   ".join(needs)


## Discards selector, previews and any wallet snapshot, and invalidates
## all prior callback generations before another event can be opened.
func close_event() -> void:
	_committed_choice.clear()
	_generation += 1
	_is_open = false
	_selector = null
	_wallet_mode = false
	_offered_wallet.clear()
	_wallet_previews.clear()
	visible = false
	if is_node_ready():
		title_label.text = ""
		description_label.text = ""
		# The story always takes its natural wrapped height in both modes, so a
		# closed/reopened panel starts with no reserved story block and no stale
		# wallet minimum left over.
		description_label.custom_minimum_size = Vector2.ZERO
	for button in _choice_buttons:
		if not is_instance_valid(button):
			continue
		button.disabled = true
		button.release_focus()
		if button.get_parent() == choices_container:
			choices_container.remove_child(button)
		button.queue_free()
	_choice_buttons.clear()
	_choice_cues.clear()
	_bound_choices.clear()
	if is_instance_valid(_wallet_label):
		_wallet_label.get_parent().remove_child(_wallet_label)
		_wallet_label.queue_free()
	_wallet_label = null


func has_open_event() -> bool:
	return _is_open


## Snapshot of the actual visible choice controls for external scene inspection.
func get_choice_buttons() -> Array[Button]:
	return _choice_buttons.duplicate()


## Snapshot of the sewn 1-based number tags, in the same authored order as the
## mounted choice buttons.
func get_choice_cues() -> Array[Label]:
	return _choice_cues.duplicate()


## Physical 1/2/3 hands the authored-order choice to the same guarded pressed
## callback as the mouse and focus path, so generation, selector ownership,
## visibility, disabled state and the exact bound choice ID all still decide.
## Only an open, visible offering answers; a two-choice Event has no third tag,
## so key 3 is left alone. Closed, hidden, spent and out-of-range keys are inert.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if not key.pressed or key.echo:
		return
	if not _is_open or not is_visible_in_tree():
		return
	var index := -1
	match key.keycode:
		KEY_1:
			index = 0
		KEY_2:
			index = 1
		KEY_3:
			index = 2
	if index < 0 or index >= _choice_buttons.size():
		return
	var button: Button = _choice_buttons[index]
	var choice_id: String = _bound_choices.get(button, "")
	if choice_id.is_empty():
		return
	get_viewport().set_input_as_handled()
	_on_choice_pressed(_selector, choice_id, _generation, button)


func _on_choice_pressed(offered: RunEventChoice, choice_id: String, generation: int, button: Button) -> void:
	if not _is_open or not is_visible_in_tree() or _generation != generation:
		return
	if _selector == null or _selector != offered or not offered.is_valid():
		return
	if not is_instance_valid(button) or not button.is_inside_tree():
		return
	if not button.visible or not button.is_visible_in_tree() or button.disabled:
		return
	if not _choice_buttons.has(button) or _bound_choices.get(button, "") != choice_id:
		return
	if button.get_parent() != choices_container:
		return
	var result: Dictionary
	if _wallet_mode:
		var forecast: Dictionary = _wallet_previews.get(choice_id, {})
		if forecast.get("affordable", false) != true:
			return
		result = offered.choose_with_wallet(choice_id, _offered_wallet.duplicate(true))
	else:
		result = offered.choose(choice_id)
	if result.get("ok", false) != true:
		return
	_committed_choice = result.duplicate(true)
	for current in _choice_buttons:
		current.disabled = true
		current.release_focus()
	if _wallet_mode:
		wallet_choice_committed.emit(result.duplicate(true))
	else:
		choice_committed.emit(result["event_id"], result["choice_id"])


func _apply_patchwork_style() -> void:
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("#e5d5b5")
	paper.border_color = Color("#766351")
	paper.set_border_width_all(5)
	paper.set_corner_radius_all(14)
	paper.shadow_color = Color(0.04, 0.07, 0.08, 0.75)
	paper.shadow_size = 12
	paper_panel.add_theme_stylebox_override("panel", paper)
	for label in [title_label, description_label]:
		label.add_theme_color_override("font_color", Color("#2c3437"))
	# The authored Event title speaks in the master Theme's Londrina heading face;
	# the description below it stays in the inherited Patrick Hand body font.
	title_label.theme_type_variation = "PatchHeading"
	title_label.add_theme_font_size_override("font_size", 36)
	description_label.add_theme_font_size_override("font_size", 23)
	for stitch_label in [top_stitches, bottom_stitches]:
		stitch_label.add_theme_color_override("font_color", Color("#85715b"))
		stitch_label.add_theme_font_size_override("font_size", 17)


func _style_choice_button(button: Button, art_path := "res://assets/paper/ui/reward_button.png") -> void:
	var fabric: Texture2D = load(art_path) as Texture2D if ResourceLoader.exists(art_path) else null
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var tints := {"normal": Color.WHITE, "hover": Color(1.12, 1.12, 1.12),
		"pressed": Color(0.88, 0.88, 0.88), "disabled": Color(0.94, 0.92, 0.88)}
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBox
		if fabric != null:
			var sewn := StyleBoxTexture.new()
			sewn.texture = fabric
			sewn.modulate_color = tints[state]
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				sewn.set_texture_margin(side, 12.0)
			style = sewn
		else:
			var flat := StyleBoxFlat.new()
			flat.bg_color = Color("#e6ceaa") * tints[state]
			flat.border_color = Color("#6c5347")
			flat.set_border_width_all(2)
			flat.set_corner_radius_all(7)
			style = flat
		style.content_margin_left = 40
		style.content_margin_right = 40
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("hover_pressed", button.get_theme_stylebox("pressed"))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.draw_center = false
	focus.border_color = Color("#503222")
	focus.set_border_width_all(4)
	focus.set_corner_radius_all(8)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", Color("#27343a"))
	button.add_theme_color_override("font_hover_color", Color("#1e292e"))
	button.add_theme_color_override("font_pressed_color", Color("#1e292e"))
	button.add_theme_color_override("font_hover_pressed_color", Color("#1e292e"))
	button.add_theme_color_override("font_focus_color", Color("#27343a"))
	button.add_theme_color_override("font_disabled_color", Color("#302e2d"))
	button.add_theme_font_size_override("font_size", 21)
