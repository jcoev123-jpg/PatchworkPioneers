class_name LiveRunCardRewardChoicePanel
extends Control
## Presentation/request boundary for a prepared, witnessed M03 Fight or Elite reward.
## No RNG use, reward settlement, deck changes, gold payment or trinket grants.

signal choice_requested(node_id: String, selected_card_id: String)

const OWNER_COLORS := {
	"warden": Color("#4a5d73"),
	"seamstress": Color("#6e4f6b"),
	"tinker": Color("#c49a3a"),
	"lantern_monk": Color("#466c65"),
	"rag_duelist": Color("#823e62"),
	"scarecrow": Color("#77613d"),
	"yarn_ranger": Color("#426785"),
	"button_golem": Color("#5c577e"),
}

const RARITY_COLORS := {
	"common": Color("#5a625a"),
	"uncommon": Color("#2d6342"),
	"rare": Color("#9e3d30"),
}

const RARITY_STITCH_COLORS := {
	"common": Color("#dedbd2"),
	"uncommon": Color("#d2eed8"),
	"rare": Color("#ffd8d0"),
}

const CARD_PAPER := Color("#ece0c8")
const DARK_INK := Color("#302b29")
const LIGHT_INK := Color("#fbf3e4")
const STITCH_THREAD := Color("#c9b996")

## The pending-gold and Elite-patch receipts are sewn onto their own small felt
## ledger tabs, like the banner label and the card names, instead of reading as
## loose plain-font lines. Each tab is just a StyleBoxFlat on the existing
## label: a muted felt face inside a dark running-stitch border, with small
## side insets and only the seam's own 2px above and below the line, so the
## banner, the three offer faces, Help and Skip keep their established room.
const RECEIPT_GOLD_FELT := Color("#c8ad7d")
const RECEIPT_PATCH_FELT := Color("#aebb97")
const RECEIPT_TAB_BORDER := Color("#5a4a38")
const RECEIPT_TAB_INSET_X := 14
const RECEIPT_TAB_INSET_Y := 2

## The sewn owner strip only needs to grow enough for a readable hero name;
## the paper's top and bottom seams give up exactly those pixels (see
## _apply_patchwork_style), so no card control moves or clips.
const OWNER_STRIP_HEIGHT := 24
const OWNER_NAME_FONT_SIZE := 14
## The hero name is sewn in the middle of its ribbon, never against the seam
## that meets the Help cell, so the full visible name keeps its own breathing
## room even when a keyword card reserves a tab beside it.
const OWNER_NAME_SIDE_INSET := 8

## The card's own authored picture gets a dedicated, inert illustration window
## above the name; the name keeps a plain cream strip of its own instead of
## cropping art behind its text. The picture is a *bounded* window: it keeps its
## readable minimum and never grows with the card's spare height (see
## _mount_card), so a tall card cannot turn the illustration into the loudest
## thing on the face. Its minimum leaves 96px for the cropped picture and
## 8px of sewn backing on each edge while every face stays aligned.
const CARD_ART_HEIGHT := 112
const NAME_STRIP_HEIGHT := 32
## Card-local rhythm: every strip keeps its own measured height and the bounded
## picture gives its spare pixels to the rules well, so the name, cost coin,
## position marks, full effects and Choose stay separate, legible and inside the
## 1280x720 screen.
const CARD_CONTENT_SEPARATION := 2
const CARD_SIDE_MARGIN := 10
const PIPS_STRIP_HEIGHT := 20
const COST_COIN_SIZE := 38
const CHOOSE_HEIGHT := 48
## VIS V2 body floor at 1280x720: the short rules and the rarity tag are read
## from arm's length at the sewing table, so both keep the project body face at
## 18 px instead of the earlier 15 px. The card's own name stays on its 21 px
## display strip, so a taller body line only needs the rules strip's own room.
const BODY_FONT_SIZE := 18
## The rules well is the card's largest text region. It is a sewn cream inset
## (light paper inside a darker running seam, padded clear of the stitches) that
## takes every spare pixel the bounded picture leaves, so the authored effects
## get the card's unused height instead of the illustration. Ordinary sentences
## sit in it in full; only genuinely longer rules ever need the wheel.
const EFFECTS_WELL_MIN_HEIGHT := 54
const EFFECTS_WELL_PAPER := Color("#fbf3e4")
const EFFECTS_WELL_STITCH := Color("#b9a984")
const EFFECTS_WELL_PAD_X := 9
const EFFECTS_WELL_PAD_Y := 6
## Keyword Help gets its own sewn cell beside the owner felt, never sewn onto the
## hero's ribbon: a 10px gap of card paper separates the two patches so the full
## hero name and the Help label read independently. Its 24px cell is too short
## for the normal 22px top and bottom burlap seams (44 > 24), so only this tab
## takes a compact vertical art slice: 6 + 6 leaves a 12px centre inside the cell
## while the side seams keep BUTTON_EDGE. The cell width is measured from the
## actually drawn display label plus those side seams, with a little breath, so
## the ribbon keeps every pixel the name needs when the sewn art is absent too.
const HEADER_CELL_GAP := 10
const HELP_TAB_HEIGHT := 24
const HELP_TAB_FONT_SIZE := 14
const HELP_TAB_EDGE_VERTICAL := 6
const HELP_TAB_TEXT_BREATH := 6

## Sewn Flow/ChatGPT art in the heroes' stitched-felt style. Every piece is
## optional: a missing texture falls back to the flat procedural paper, and the
## StyleBoxFlat styles stay underneath to carry palette, hover glow and focus.
const ART_DIR := "res://assets/paper/"
const CAMP_BACKDROP := ART_DIR + "backgrounds/reward_camp.png"
## One slow deterministic cycle, confined to the existing camp image.
## Uniform overfill leaves room for the small pan even at the zoom trough.
const CAMP_MOTION_PERIOD := 18.0
const CAMP_MOTION_ZOOM := 1.065
const CAMP_MOTION_BREATH := 0.008
const CAMP_MOTION_PAN := Vector2(8.0, 5.0)
## View-only movement of authored images inside the fixed CardArt illustration.
const CARD_MOTION_PERIOD := 8.0
const CARD_IDLE_DRIFT := 2.0
const CARD_IDLE_TILT := 1.0
const CARD_FOCUS_LIFT := 4.0
const CARD_LIFT_SPEED := 8.0
const REDUCED_MOTION_SETTING := "accessibility/reduced_motion"
const QUILT_PANEL := ART_DIR + "ui/reward_panel.png"
const TITLE_BANNER := ART_DIR + "ui/reward_banner.png"
const BURLAP_BUTTON := ART_DIR + "ui/reward_button.png"
## Unstretched nine-patch edges, in pixels of the installed textures.
const QUILT_EDGE := 36
const FRAME_EDGE := 30
## The ribbon's swallow tails (left) and sewn-on patch (right) stay unstretched.
const BANNER_LEFT := 64
const BANNER_RIGHT := 86
const BANNER_HEIGHT := 72
const BUTTON_EDGE := 22
## Room the sewn borders take before any card or panel content starts.
const QUILT_INSET := 30
const FRAME_INSET := 24

@onready var paper_panel: PanelContainer = $PaperPanel
@onready var title_label: Label = $PaperPanel/ContentMargin/RewardContent/RewardTitle
@onready var gold_label: Label = $PaperPanel/ContentMargin/RewardContent/GoldLabel
@onready var trinket_label: Label = $PaperPanel/ContentMargin/RewardContent/TrinketLabel
@onready var choices_container: HBoxContainer = $PaperPanel/ContentMargin/RewardContent/CardChoices
@onready var skip_button: Button = $PaperPanel/ContentMargin/RewardContent/SkipButton
@onready var top_stitches: Label = $PaperPanel/ContentMargin/RewardContent/TopStitches
@onready var bottom_stitches: Label = $PaperPanel/ContentMargin/RewardContent/BottomStitches

var _generation: int = 0
var _is_open: bool = false
var _awaiting_ack: bool = false
var _accepted: bool = false
var _node_id: String = ""
var _node_kind: String = ""
var _receipt: Dictionary = {}
var _choice_buttons: Array[Button] = []
var _bound_choices: Dictionary = {}
var _card_panels: Array[PanelContainer] = []
var _card_hovered: Array[bool] = []
var _card_focused: Array[bool] = []
var _help_buttons: Array[Button] = []
var _help_ids: Dictionary = {}
var _help_overlay: PanelContainer = null
var _help_invoker: Button = null
var _camp_backdrop: TextureRect = null
var _camp_elapsed := 0.0
var _card_elapsed := 0.0
var _card_lifts: Array[float] = []
var _reduced_motion_override: Variant = null


func _ready() -> void:
	set_process(false)
	_apply_patchwork_style()
	close_rewards()


## The setting defaults to off. Tests/accessibility can override on a panel.
func set_reduced_motion_override(value: Variant) -> void:
	_reduced_motion_override = value if value is bool else null
	_sync_camp_motion()


func _reduced_motion() -> bool:
	if _reduced_motion_override is bool:
		return _reduced_motion_override
	return ProjectSettings.get_setting(REDUCED_MOTION_SETTING, false) == true


func _motion_visible() -> bool:
	return is_node_ready() and _is_open and is_visible_in_tree() and not _reduced_motion()


func _card_motion_available() -> bool:
	if not _motion_visible() or _awaiting_ack or _accepted:
		return false
	for card in _card_panels:
		if is_instance_valid(card):
			var art := card.get_node_or_null("CardMargin/CardContent/CardArt") as _CardIllustration
			if art != null and art.has_picture():
				return true
	return false


func _sync_camp_motion() -> void:
	_reset_camp_motion()
	_reset_card_motion()
	if _motion_visible() and is_instance_valid(_camp_backdrop) \
			and _camp_backdrop.texture != null:
		_apply_camp_motion()
	_sync_motion_processing()


func _sync_motion_processing() -> void:
	set_process((_motion_visible() and is_instance_valid(_camp_backdrop)
		and _camp_backdrop.texture != null) or _card_motion_available())


func _reset_camp_motion() -> void:
	_camp_elapsed = 0.0
	if is_instance_valid(_camp_backdrop):
		_camp_backdrop.position = Vector2.ZERO
		_camp_backdrop.scale = Vector2.ONE
		_camp_backdrop.pivot_offset = Vector2.ZERO


func _apply_camp_motion() -> void:
	if not is_instance_valid(_camp_backdrop):
		return
	var phase := TAU * _camp_elapsed / CAMP_MOTION_PERIOD
	var zoom := CAMP_MOTION_ZOOM + CAMP_MOTION_BREATH * sin(phase)
	_camp_backdrop.pivot_offset = _camp_backdrop.size * 0.5
	_camp_backdrop.scale = Vector2.ONE * zoom
	_camp_backdrop.position = Vector2(
		CAMP_MOTION_PAN.x * sin(phase), CAMP_MOTION_PAN.y * cos(phase))


## A bounded, deterministic clock: neither screen geometry nor gameplay RNG is touched.
## Every card starts at its neutral draw transform, with a different idle phase.
func _reset_card_motion() -> void:
	_card_elapsed = 0.0
	_card_lifts.clear()
	if _is_open:
		for index in range(3):
			_card_lifts.append(0.0)
	for card in _card_panels:
		if is_instance_valid(card):
			var art := card.get_node_or_null("CardMargin/CardContent/CardArt") as _CardIllustration
			if art != null:
				art.set_picture_motion(Vector2.ZERO, 0.0)


func _advance_card_motion(delta: float) -> void:
	if not _card_motion_available():
		_reset_card_motion()
		return
	var step := maxf(delta, 0.0)
	_card_elapsed = fposmod(_card_elapsed + step, CARD_MOTION_PERIOD)
	var time_phase := TAU * _card_elapsed / CARD_MOTION_PERIOD
	for index in range(_card_panels.size()):
		var card := _card_panels[index]
		if not is_instance_valid(card):
			continue
		var art := card.get_node_or_null("CardMargin/CardContent/CardArt") as _CardIllustration
		if art == null or not art.has_picture():
			if art != null:
				art.set_picture_motion(Vector2.ZERO, 0.0)
			continue
		var active: bool = _card_hovered[index] or _card_focused[index]
		var goal := CARD_FOCUS_LIFT if active else 0.0
		_card_lifts[index] = move_toward(_card_lifts[index], goal, CARD_LIFT_SPEED * step)
		var phase := TAU * float(index) / 3.0
		# Subtract the phase's initial value so open/rebind begins neutral,
		# while retaining index-staggered periodic movement within fixed bounds.
		var breath := 0.5 * (sin(time_phase + phase) - sin(phase))
		var tilt := 0.5 * (sin(time_phase + phase + PI / 3.0) - sin(phase + PI / 3.0))
		art.set_picture_motion(Vector2(0.0, CARD_IDLE_DRIFT * breath - _card_lifts[index]),
			CARD_IDLE_TILT * tilt)


func _process(delta: float) -> void:
	if not _motion_visible():
		_reset_camp_motion()
		_reset_card_motion()
		set_process(false)
		return
	if is_instance_valid(_camp_backdrop) and _camp_backdrop.texture != null:
		_camp_elapsed = fposmod(_camp_elapsed + maxf(delta, 0.0), CAMP_MOTION_PERIOD)
		_apply_camp_motion()
	else:
		_reset_camp_motion()
	_advance_card_motion(delta)
	_sync_motion_processing()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready():
		_sync_camp_motion()


func _exit_tree() -> void:
	_reset_camp_motion()
	_reset_card_motion()
	set_process(false)


## Display only a detached valid RunFightVictoryRewards.prepare() receipt.
## Never replace an open receipt without first closing it.
func open_rewards(node_id: Variant, node_kind: Variant, prepared: Variant) -> bool:
	if _is_open or not is_node_ready() or not _valid_receipt(node_id, node_kind, prepared):
		return false
	var snapshot: Dictionary = (prepared as Dictionary).duplicate(true)
	_generation += 1
	_node_id = node_id
	_node_kind = node_kind
	_receipt = snapshot
	_is_open = true
	_awaiting_ack = false
	_accepted = false
	_card_panels.clear()
	_help_buttons.clear()
	_help_ids.clear()
	_card_hovered = [false, false, false]
	_card_focused = [false, false, false]
	title_label.text = "%s reward" % node_kind
	gold_label.text = "Pending gold: +%d" % snapshot["gold_award"]
	trinket_label.visible = node_kind == "Elite"
	trinket_label.text = ("Patch: " + _humanize_patch(snapshot["trinket_drop_id"])) if node_kind == "Elite" else ""
	for index in range(3):
		var offered: Dictionary = snapshot["offers"][index]
		var definition: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(offered["id"])
		var card_panel := _mount_card(index, offered, definition)
		var help := card_panel.get_node_or_null("CardMargin/CardContent/CardHeader/HelpButton") as Button
		if help != null:
			_help_buttons.append(help)
			_help_ids[help] = offered["id"]
			help.pressed.connect(_on_help_pressed.bind(_generation, _node_id, index, offered["id"], help))
		_card_panels.append(card_panel)
		choices_container.add_child(card_panel)
		var button := card_panel.get_node("CardMargin/CardContent/ChooseButton") as Button
		# Right-arrow from Choose reaches this card's Help without changing the
		# existing Tab circuit through three Choose actions and Skip.
		if help != null:
			button.focus_neighbor_right = button.get_path_to(help)
			help.focus_neighbor_left = help.get_path_to(button)
		_choice_buttons.append(button)
		_bound_choices[button] = offered["id"]
		button.pressed.connect(_on_choice_pressed.bind(_generation, _node_id, offered["id"], button))
	skip_button.name = "Choice_Skip"
	skip_button.disabled = false
	skip_button.focus_mode = Control.FOCUS_ALL
	_style_button(skip_button, Color("#766351"))
	_fit_skip_button()
	_add_focus_stitch(skip_button)
	_choice_buttons.append(skip_button)
	_bound_choices[skip_button] = ""
	skip_button.pressed.connect(_on_choice_pressed.bind(_generation, _node_id, "", skip_button))
	for index in range(_choice_buttons.size()):
		var button := _choice_buttons[index]
		button.focus_next = button.get_path_to(_choice_buttons[(index + 1) % _choice_buttons.size()])
		button.focus_previous = button.get_path_to(_choice_buttons[(index + _choice_buttons.size() - 1) % _choice_buttons.size()])
	show()
	_sync_camp_motion()
	call_deferred("_focus_first", _generation)
	return true


func _valid_receipt(node_id: Variant, node_kind: Variant, prepared: Variant) -> bool:
	if not node_id is String or node_id.strip_edges().is_empty():
		return false
	if not node_kind is String or not node_kind in ["Fight", "Elite"]:
		return false
	if not prepared is Dictionary or prepared.get("ok") != true:
		return false
	var award: Variant = prepared.get("gold_award")
	if not award is int or award < (25 if node_kind == "Elite" else 10) \
			or award > (35 if node_kind == "Elite" else 20):
		return false
	var trinket: Variant = prepared.get("trinket_drop_id")
	if not trinket is String:
		return false
	if node_kind == "Elite" and trinket.strip_edges().is_empty():
		return false
	if node_kind == "Fight" and not trinket.is_empty():
		return false
	var offers: Variant = prepared.get("offers")
	if not offers is Array or offers.size() != 3:
		return false
	var ids := {}
	for offer in offers:
		if not offer is Dictionary:
			return false
		var id: Variant = offer.get("id")
		var owner: Variant = offer.get("owner")
		if not id is String or id.strip_edges().is_empty() or ids.has(id):
			return false
		if not owner is String or not OWNER_COLORS.has(owner):
			return false
		# Offers resolve against the real starter catalog or the authored D2-1
		# base pools; pool upgrades and unknown IDs are never valid rewards.
		var definition: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(id)
		if definition.is_empty() or definition.get("owner") != owner:
			return false
		if not definition.get("display_name") is String \
				or definition["display_name"].strip_edges().is_empty():
			return false
		if not definition.get("cost") is int or definition["cost"] < 0:
			return false
		ids[id] = true
	return true


func _mount_card(index: int, offer: Dictionary, definition: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Card_%d" % index
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.0
	card.custom_minimum_size = Vector2(0, 320)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.focus_mode = Control.FOCUS_NONE
	_style_card(card, String(offer["owner"]), false)
	var margin := MarginContainer.new()
	margin.name = "CardMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", CARD_SIDE_MARGIN)
	margin.add_theme_constant_override("margin_right", CARD_SIDE_MARGIN)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "CardContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", CARD_CONTENT_SEPARATION)
	margin.add_child(content)

	# Horizontal card header row: the owner ribbon keeps its own whole cell and
	# the Details tab is a second sewn cell, separated by card paper.
	var header := HBoxContainer.new()
	header.name = "CardHeader"
	header.custom_minimum_size = Vector2(0, OWNER_STRIP_HEIGHT)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", HEADER_CELL_GAP)
	content.add_child(header)

	# Owner color patch (sewn stripe at top) with the owning hero's name sewn in
	var owner := String(offer["owner"])
	var owner_patch := _OwnerPatch.new()
	owner_patch.name = "OwnerPatch"
	owner_patch.owner_color = OWNER_COLORS[owner]
	owner_patch.custom_minimum_size = Vector2(0, OWNER_STRIP_HEIGHT)
	owner_patch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owner_patch.size_flags_vertical = Control.SIZE_FILL
	header.add_child(owner_patch)
	var owner_label := _card_label("OwnerLabel", owner.capitalize(), OWNER_NAME_FONT_SIZE)
	# The hero name is sewn in the project's display face. Its measured 14px line
	# height fits the existing 24px owner felt, so no strip or card geometry moves.
	owner_label.theme_type_variation = &"PatchHeading"
	owner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owner_label.add_theme_color_override("font_color", owner_ink(owner))
	owner_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A plain FULL_RECT label can run glyphs into the felt border. The measured
	# side inset keeps the complete Warden/Seamstress/Tinker name inside its own
	# sewn cell, clear of the gap that separates it from Details.
	owner_label.offset_left = OWNER_NAME_SIDE_INSET
	owner_label.offset_right = -OWNER_NAME_SIDE_INSET
	owner_patch.add_child(owner_label)

	# Illustration window: image-only, inert to pointer and focus, and sized to
	# its own patch so the name, cost, marks, rules and Choose stay separate.
	# The resolved art keeps two distinct modes: the card's own picture fills
	# its contained window, while a fallback hero emblem sits on a wide sewn
	# owner-felt patch. With no texture the procedural stitched patch remains.
	var art := resolve_card_art(String(offer["id"]), owner)
	var illustration := _CardIllustration.new()
	illustration.name = "CardArt"
	illustration.picture = art.get("texture") as Texture2D
	illustration.mode = String(art.get("mode", _CardIllustration.MODE_NONE))
	illustration.owner_color = OWNER_COLORS[owner]
	illustration.custom_minimum_size = Vector2(0, CARD_ART_HEIGHT)
	# Bounded window: SIZE_FILL keeps the picture at its readable minimum even
	# when the card is taller. Only the rules well below takes the spare height,
	# so the illustration can never dwarf the authored effects again.
	illustration.size_flags_vertical = Control.SIZE_FILL
	content.add_child(illustration)

	# Name on its own readable torn-paper strip, never cropped illustration art
	var name_label := _card_label("NameLabel", definition["display_name"], 21)
	name_label.theme_type_variation = &"PatchHeading"
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_vertical = Control.SIZE_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(0, NAME_STRIP_HEIGHT)
	var name_box := StyleBoxFlat.new()
	name_box.bg_color = Color("#fbf3e4")
	name_box.border_color = Color("#c7b89f")
	name_box.set_border_width_all(1)
	name_box.set_corner_radius_all(4)
	name_box.content_margin_left = 6
	name_box.content_margin_right = 6
	name_box.content_margin_top = 3
	name_box.content_margin_bottom = 3
	name_label.add_theme_stylebox_override("normal", name_box)
	content.add_child(name_label)

	# Cost, rarity and six positional stitches share one measured row.
	# This frees the effects and Choose strips from competing for the same height.
	var metadata := HBoxContainer.new()
	metadata.name = "MetadataRow"
	metadata.custom_minimum_size = Vector2(0, COST_COIN_SIZE)
	metadata.add_theme_constant_override("separation", 8)
	metadata.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(metadata)

	# Rarity tag (only for pool cards with authored rarity)
	var rarity_label := _card_label("RarityLabel", "", BODY_FONT_SIZE)
	# A rarity is a single sewn tag: never split its letters into a tall column
	# when the adjacent pips request horizontal expansion.
	rarity_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	rarity_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var rarity: String = String(definition.get("rarity", "")).strip_edges().to_lower()
	if RARITY_COLORS.has(rarity):
		rarity_label.text = rarity.capitalize()
		var tag_style := StyleBoxFlat.new()
		tag_style.bg_color = RARITY_COLORS[rarity]
		tag_style.border_color = RARITY_STITCH_COLORS[rarity]
		tag_style.set_border_width_all(2)
		tag_style.set_corner_radius_all(6)
		tag_style.content_margin_left = 8
		tag_style.content_margin_right = 8
		tag_style.content_margin_top = 1
		tag_style.content_margin_bottom = 1
		rarity_label.add_theme_stylebox_override("normal", tag_style)
		rarity_label.add_theme_color_override("font_color", Color("#fffaf0"))
		rarity_label.visible = true
	else:
		rarity_label.text = ""
		rarity_label.visible = false
	metadata.add_child(rarity_label)

	# Cost as a round sewn button (numeric only)
	var cost_value: int = definition["cost"]
	var cost_button := _CostButton.new()
	cost_button.name = "CostButton"
	cost_button.cost_value = cost_value
	cost_button.owner_color = OWNER_COLORS[offer["owner"]]
	cost_button.custom_minimum_size = Vector2(COST_COIN_SIZE, COST_COIN_SIZE)
	cost_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cost_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_button.focus_mode = Control.FOCUS_NONE
	metadata.add_child(cost_button)

	# Position/target pips
	var pips_container := _PositionPips.new()
	pips_container.name = "PositionPips"
	var from_positions: Array[int] = []
	for pos in definition.get("from_positions", []):
		from_positions.append(int(pos))
	var to_positions: Array[int] = []
	for pos in definition.get("to_positions", []):
		to_positions.append(int(pos))
	pips_container.from_positions = from_positions
	pips_container.to_positions = to_positions
	pips_container.target_kind = String(definition.get("target_kind", ""))
	pips_container.owner_color = OWNER_COLORS[offer["owner"]]
	pips_container.custom_minimum_size = Vector2(108, PIPS_STRIP_HEIGHT)
	pips_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metadata.add_child(pips_container)

	# Effects text: the same detached short-sentence formatter the held hand
	# uses. No live passive boost is predicted for a detached reward offer.
	var effect_line := CardShortRules.line(definition)
	var rules_label := _card_label("RulesLabel", effect_line, BODY_FONT_SIZE)
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Inside the well the sentence fills the scroll child, so one short line is
	# centred in the sewn inset instead of hugging its top seam while the rest of
	# the well reads as blank parchment.
	rules_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rules_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The authored text is never truncated: the well takes the card's spare
	# height for the words, while long sentences remain wheel/trackpad scrollable.
	var effects := ScrollContainer.new()
	effects.name = "EffectsScroll"
	effects.custom_minimum_size = Vector2(0, EFFECTS_WELL_MIN_HEIGHT)
	effects.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effects.size_flags_vertical = Control.SIZE_EXPAND_FILL
	effects.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	effects.mouse_filter = Control.MOUSE_FILTER_PASS
	effects.add_theme_stylebox_override("panel", _effects_well_style())
	effects.add_child(rules_label)
	content.add_child(effects)

	# The face never prints a position sentence, so the hover explains the six
	# painted marks (and the slots they fill) without taking the card's action.
	card.tooltip_text = _pip_legend(definition)

	# Choose button
	var action := Button.new()
	action.name = "ChooseButton"
	action.text = "%d Choose card" % (index + 1)
	action.focus_mode = Control.FOCUS_ALL
	action.custom_minimum_size = Vector2(0, CHOOSE_HEIGHT)
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_button(action, OWNER_COLORS[offer["owner"]])
	_add_focus_stitch(action)
	content.add_child(action)

	var offered_id := String(offer["id"])
	card.gui_input.connect(_on_card_gui_input.bind(index, offered_id, action))
	card.mouse_entered.connect(_on_card_mouse_entered.bind(index))
	card.mouse_exited.connect(_on_card_mouse_exited.bind(index))
	action.focus_entered.connect(_on_card_focus_entered.bind(index))
	action.focus_exited.connect(_on_card_focus_exited.bind(index))
	# Every authenticated offer receives its own Details tab, including cards
	# without glossary rows. It stays beside the owner patch, never on Choose.
	var help := Button.new()
	help.name = "HelpButton"
	help.text = "Details"
	help.focus_mode = Control.FOCUS_ALL
	help.mouse_filter = Control.MOUSE_FILTER_STOP
	help.size_flags_horizontal = Control.SIZE_SHRINK_END
	help.size_flags_vertical = Control.SIZE_FILL
	_style_button(help, OWNER_COLORS[owner], HELP_TAB_EDGE_VERTICAL)
	help.add_theme_font_size_override("font_size", HELP_TAB_FONT_SIZE)
	_fit_help_tab(help)
	_add_focus_stitch(help)
	header.add_child(help)
	return card


## The hover legend for the six painted marks. The face prints no position, so
## this is the only place the reward view spells the exact legal slots out; a
## card that chooses a hero (or has no target) says that no square is filled.
func _pip_legend(definition: Dictionary) -> String:
	var from_text := _positions_text(definition.get("from_positions", []), "no slot")
	var parts: Array[String] = [
		"PIPS: filled circles = slots this hero may play from (%s)" % from_text,
		"outlined circles = not a source slot",
	]
	var to_positions: Array = definition.get("to_positions", [])
	if to_positions.is_empty():
		parts.append("no target square is filled (%s)" % _target_slot_text(definition))
	else:
		parts.append("filled squares = legal target slots (%s)" % _positions_text(to_positions, "?"))
		parts.append("outlined squares = not a target slot")
	match str(definition.get("target_kind", "")):
		"enemy_all":
			parts.append("a sewn thread joins every enemy square (%s = all of them)"
				% CardShortRules.ALL_TARGET)
		"party_all":
			parts.append("%s = every hero" % CardShortRules.ALL_TARGET)
	var raw_effects: Variant = definition.get("effects", {})
	if raw_effects is Dictionary \
			and bool((raw_effects as Dictionary).get("random_target_each_hit", false)):
		parts.append("%s = one random enemy per hit" % CardShortRules.RANDOM_TARGET)
	return "; ".join(parts) + "."


## The authored slots as a compact range, never a guessed position.
func _positions_text(positions: Array, empty_text: String) -> String:
	if positions.is_empty():
		return empty_text
	if positions.size() == 1:
		return str(positions[0])
	return "%s–%s" % [positions[0], positions.back()]


## The authored recipient rule for a card that fills no target square.
func _target_slot_text(definition: Dictionary) -> String:
	match str(definition.get("target_kind", "")):
		"ally_single":
			return "any hero slot"
		"party_all":
			return "every hero"
		"self":
			return "this hero"
		"adjacent_ally":
			return "the adjacent hero"
	return "no target"


func _card_label(label_name: String, value: String, point_size: int) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", DARK_INK)
	label.add_theme_font_size_override("font_size", point_size)
	return label


## The sewn inset the authored rules are read in: light cream paper inside a
## darker running seam, padded clear of the stitches. It is drawn paper, not a
## generated texture, exactly like the name strip beside it, and it only owns
## the card's own spare height (see _mount_card).
func _effects_well_style() -> StyleBoxFlat:
	var well := StyleBoxFlat.new()
	well.bg_color = EFFECTS_WELL_PAPER
	well.border_color = EFFECTS_WELL_STITCH
	well.set_border_width_all(1)
	well.set_corner_radius_all(5)
	well.content_margin_left = EFFECTS_WELL_PAD_X
	well.content_margin_right = EFFECTS_WELL_PAD_X
	well.content_margin_top = EFFECTS_WELL_PAD_Y
	well.content_margin_bottom = EFFECTS_WELL_PAD_Y
	return well


## A caller rejection re-enables this exact prepared offer; acceptance latches it.
## Acknowledgements while closed or without an outstanding request do nothing.
func acknowledge(accepted: bool) -> void:
	if not _is_open or not _awaiting_ack or _accepted:
		return
	_awaiting_ack = false
	if accepted:
		_accepted = true
		_reset_card_motion()
		_sync_motion_processing()
		return
	for button in _choice_buttons:
		if is_instance_valid(button):
			button.disabled = false
	_reset_card_motion()
	_sync_motion_processing()


func close_rewards() -> void:
	_reset_camp_motion()
	_reset_card_motion()
	set_process(false)
	_dismiss_help(false)
	_generation += 1
	_is_open = false
	_awaiting_ack = false
	_accepted = false
	_node_id = ""
	_node_kind = ""
	_receipt.clear()
	hide()
	if not is_node_ready():
		return
	title_label.text = ""
	gold_label.text = ""
	trinket_label.text = ""
	trinket_label.hide()
	for connection in skip_button.pressed.get_connections():
		skip_button.pressed.disconnect(connection["callable"])
	for button in _choice_buttons:
		if is_instance_valid(button):
			button.disabled = true
			button.release_focus()
	for card in choices_container.get_children():
		choices_container.remove_child(card)
		card.queue_free()
	_choice_buttons.clear()
	_bound_choices.clear()
	_help_buttons.clear()
	_help_ids.clear()
	_card_panels.clear()
	_card_hovered.clear()
	_card_focused.clear()
	_card_lifts.clear()
	skip_button.disabled = true
	skip_button.release_focus()


func has_open_rewards() -> bool:
	return _is_open


func get_choice_buttons() -> Array[Button]:
	return _choice_buttons.duplicate()


func _focus_first(generation: int) -> void:
	if _is_open and _generation == generation and not _choice_buttons.is_empty() \
			and is_visible_in_tree() and _help_overlay == null and not _choice_buttons[0].disabled:
		_choice_buttons[0].grab_focus()


func _on_choice_pressed(generation: int, node_id: String, selected_card_id: String, button: Button) -> void:
	if not _is_open or _accepted or _awaiting_ack or _generation != generation \
			or _node_id != node_id or not is_visible_in_tree():
		return
	if not is_instance_valid(button) or not button.is_inside_tree() \
			or not button.is_visible_in_tree() or button.disabled:
		return
	if not _choice_buttons.has(button) or not _bound_choices.has(button) \
			or _bound_choices[button] != selected_card_id:
		return
	if button != skip_button and not choices_container.is_ancestor_of(button):
		return
	if button == skip_button and selected_card_id != "":
		return
	_dismiss_help(false)
	_awaiting_ack = true
	_reset_card_motion()
	_sync_motion_processing()
	for choice in _choice_buttons:
		choice.disabled = true
	choice_requested.emit(_node_id, selected_card_id)



## Help callbacks carry the original generation, node, offer ID and button.
## An old callable cannot inspect a newly mounted receipt or steal its focus.
func _on_help_pressed(generation: int, node_id: String, index: int,
		card_id: String, button: Variant) -> void:
	if not _is_open or _accepted or _awaiting_ack or _generation != generation \
			or _node_id != node_id or not is_visible_in_tree():
		return
	if not is_instance_valid(button) or not button is Button \
			or not button.is_inside_tree() or not button.is_visible_in_tree() or button.disabled:
		return
	if not _help_buttons.has(button) or _help_ids.get(button, "") != card_id:
		return
	if index < 0 or index >= _card_panels.size() or index >= _receipt.get("offers", []).size():
		return
	if _card_panels[index].get_node_or_null(
			"CardMargin/CardContent/CardHeader/HelpButton") != button \
			or String(_receipt["offers"][index].get("id", "")) != card_id:
		return
	var definition := RunPoolCardRewardOffers.resolve_reward_definition(card_id)
	if definition.is_empty() or definition.get("owner") != _receipt["offers"][index].get("owner"):
		return
	var keywords: Array[Dictionary] = CardKeywordGlossary.describe(definition)
	_dismiss_help(false)
	_help_invoker = button
	_mount_help_overlay(definition, keywords, generation, node_id, index, card_id, button)


## The sheet prints the resolver's *authored* record, not a promise of
## combat support. Keep every effect key/value even when short rules or the
## keyword glossary know nothing about it.
func _details_label(label_name: String, value: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", DARK_INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _details_seats(positions: Array) -> String:
	if positions.is_empty():
		return "none printed"
	var parts: Array[String] = []
	for seat in positions:
		parts.append(str(seat))
	return ", ".join(parts)


func _details_summary(definition: Dictionary) -> String:
	var owner := String(definition.get("owner", "")).replace("_", " ").capitalize()
	var source: Array = definition.get("from_positions", [])
	var target: Array = definition.get("to_positions", [])
	var kind := String(definition.get("target_kind", ""))
	var recipient := "Target rule not described; consult printed target seats."
	match kind:
		"enemy_single":
			recipient = "Choose one living enemy in the printed enemy seats."
		"enemy_all":
			recipient = "All enemies in the printed enemy seats."
		"enemy_back":
			recipient = "Backmost eligible living enemy in the printed enemy seats."
		"ally_single":
			recipient = "Choose one living ally in the party."
		"self":
			recipient = "The owning hero only."
		"party_all":
			recipient = "Every hero in the party."
		"adjacent_ally":
			recipient = "An adjacent ally of the owning hero."
	if target.is_empty():
		recipient += " No target squares are printed; none are implied."
	return "%s  |  %s\nOwner: %s  |  Energy cost: %s  |  Rarity: %s\nSource hero seats: %s\nTarget kind: %s  |  Target seats: %s\n%s\nPips: filled circles show source seats; filled squares show printed target seats.\nCard face: %s\nThese are catalog-authored rules, not a claim of live combat implementation." % [
		String(definition.get("display_name", "")), String(definition.get("id", "")),
		owner, str(definition.get("cost", "?")),
		String(definition.get("rarity", "not printed")).capitalize(),
		_details_seats(source), kind, _details_seats(target), recipient,
		CardShortRules.line(definition)]


func _details_effects(definition: Dictionary) -> String:
	var raw: Variant = definition.get("effects", {})
	if not raw is Dictionary:
		return "Authored effects: unreadable printed effect block."
	var effects: Dictionary = raw
	var lines: Array[String] = ["Authored effects (literal printed key = value):"]
	if effects.is_empty():
		lines.append("None printed.")
	for key in effects:
		# Every entry is visible even if CardShortRules has no description for it.
		var name := String(key)
		var value: Variant = effects[key]
		var explanation := ""
		if name == "max_hp_loss" and value is int:
			explanation = " (lose %d maximum HP)" % value
		elif name == "heal" and value is int:
			explanation = " (heal %d HP)" % value
		elif not CardShortRules.KNOWN_EFFECT_KEYS.has(name):
			explanation = " — unexplained authored effect"
		lines.append("• %s = %s%s" % [name, str(value), explanation])
	if String(definition.get("id", "")) == "scarecrow_re_stuff" \
			and effects.get("max_hp_loss") == 2 and effects.get("heal") == 10:
		lines.append("Re-Stuff exchange: lose 2 maximum HP, then heal 10 HP.")
	return "\n".join(lines)


func _mount_help_overlay(definition: Dictionary, keywords: Array[Dictionary],
		generation: int, node_id: String, index: int, card_id: String,
		invoker: Button) -> void:
	var owner: String = String(definition.get("owner", ""))
	var felt: Color = OWNER_COLORS.get(owner, Color("#736451"))
	var overlay := PanelContainer.new()
	overlay.name = "KeywordHelpOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.anchor_left = 0.22
	overlay.anchor_right = 0.78
	overlay.anchor_top = 0.19
	overlay.anchor_bottom = 0.81
	var paper := StyleBoxFlat.new()
	paper.bg_color = CARD_PAPER
	paper.border_color = felt
	paper.set_border_width_all(6)
	paper.set_corner_radius_all(12)
	paper.content_margin_left = 20
	paper.content_margin_right = 20
	paper.content_margin_top = 15
	paper.content_margin_bottom = 14
	paper.shadow_color = Color(0.07, 0.06, 0.07, 0.85)
	paper.shadow_size = 18
	overlay.add_theme_stylebox_override("panel", paper)
	add_child(overlay)
	_help_overlay = overlay
	var column := VBoxContainer.new()
	column.name = "HelpContent"
	column.add_theme_constant_override("separation", 9)
	overlay.add_child(column)
	var title := Label.new()
	title.name = "HelpTitle"
	title.text = String(definition["display_name"]) + "  •  Details"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.theme_type_variation = &"PatchHeading"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", owner_ink(owner))
	var felt_box := StyleBoxFlat.new()
	felt_box.bg_color = felt
	felt_box.content_margin_left = 12
	felt_box.content_margin_right = 12
	felt_box.content_margin_top = 8
	felt_box.content_margin_bottom = 8
	felt_box.set_corner_radius_all(5)
	title.add_theme_stylebox_override("normal", felt_box)
	column.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.name = "KeywordScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "DetailBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	var summary := _details_label("DetailsSummary", _details_summary(definition))
	body.add_child(summary)
	var effects := _details_label("AuthoredEffects", _details_effects(definition))
	body.add_child(effects)
	var list := VBoxContainer.new()
	list.name = "KeywordLines"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 13)
	body.add_child(list)
	for item: Dictionary in keywords:
		var line := Label.new()
		line.name = "KeywordLine_%d" % list.get_child_count()
		line.text = "%s — %s" % [item["keyword"], item["explanation"]]
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", 18)
		line.add_theme_color_override("font_color", DARK_INK)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(line)
	var close := Button.new()
	close.name = "CloseHelpButton"
	close.text = "Close details"
	close.focus_mode = Control.FOCUS_ALL
	close.custom_minimum_size = Vector2(0, 42)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(close, felt)
	close.add_theme_font_size_override("font_size", 18)
	_add_focus_stitch(close)
	column.add_child(close)
	close.pressed.connect(_on_help_close_pressed.bind(
		generation, node_id, index, card_id, invoker, overlay))
	close.grab_focus()


func _on_help_close_pressed(generation: int, node_id: String, index: int,
		card_id: String, invoker: Variant, overlay: Variant) -> void:
	if not _is_open or _accepted or _awaiting_ack or not is_visible_in_tree() \
			or _generation != generation or _node_id != node_id \
			or not is_instance_valid(invoker) or not is_instance_valid(overlay) \
			or _help_overlay != overlay or _help_invoker != invoker \
			or not _help_buttons.has(invoker) or _help_ids.get(invoker, "") != card_id:
		return
	if index < 0 or index >= _card_panels.size() \
			or index >= _receipt.get("offers", []).size():
		return
	if String(_receipt["offers"][index].get("id", "")) != card_id \
			or _card_panels[index].get_node_or_null(
				"CardMargin/CardContent/CardHeader/HelpButton") != invoker:
		return
	_dismiss_help(true)


## Route numbered shortcuts through the same guarded, mounted Button callbacks
## as pointer/focus choices. Never bypass the host's acknowledgement boundary.
func _input(event: InputEvent) -> void:
	if not _is_open or _accepted or _awaiting_ack or not is_visible_in_tree() \
			or not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if _help_overlay != null:
		if event.keycode == KEY_ESCAPE:
			_dismiss_help(true)
			get_viewport().set_input_as_handled()
		return
	if event.shift_pressed or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	var index := -1
	match event.keycode:
		KEY_1, KEY_KP_1:
			index = 0
		KEY_2, KEY_KP_2:
			index = 1
		KEY_3, KEY_KP_3:
			index = 2
		KEY_0, KEY_KP_0:
			index = 3
	if index < 0 or index >= _choice_buttons.size():
		return
	var button := _choice_buttons[index]
	if not is_instance_valid(button) or not button.is_inside_tree() \
			or not button.is_visible_in_tree() or button.disabled:
		return
	button.pressed.emit()
	get_viewport().set_input_as_handled()


func _dismiss_help(restore_focus: bool) -> void:
	var invoker := _help_invoker
	_help_invoker = null
	if _help_overlay != null:
		var overlay := _help_overlay
		_help_overlay = null
		if is_instance_valid(overlay):
			if overlay.get_parent() == self:
				remove_child(overlay)
			overlay.queue_free()
	if restore_focus and _is_open and is_visible_in_tree() \
			and is_instance_valid(invoker) and invoker.is_inside_tree() \
			and invoker.is_visible_in_tree() and not invoker.disabled \
			and _help_buttons.has(invoker):
		invoker.grab_focus()


func _style_card(card: PanelContainer, owner: String, active: bool) -> void:
	var patch := StyleBoxFlat.new()
	patch.bg_color = CARD_PAPER
	if OWNER_COLORS.has(owner):
		patch.border_color = OWNER_COLORS[owner]
	else:
		patch.border_color = Color("#736451")
	patch.set_border_width_all(8 if active else 5)
	patch.set_corner_radius_all(10)
	patch.content_margin_left = 10
	patch.content_margin_right = 10
	patch.content_margin_top = 12
	patch.content_margin_bottom = 12
	patch.shadow_color = Color(0.03, 0.06, 0.07, 0.8)
	patch.shadow_size = 18 if active else 12
	patch.shadow_offset = Vector2(0, 4) if active else Vector2.ZERO
	var frame := art_texture(ART_DIR + "ui/card_frame_%s.png" % owner)
	if frame != null:
		# The sewn felt frame is painted over this box; the box keeps only its
		# owner border colour and the hover/focus glow around the frame.
		patch.bg_color = Color(CARD_PAPER, 0.0)
		patch.set_border_width_all(0)
		patch.shadow_color = Color("#f3d58a", 0.75) if active else Color(0.02, 0.03, 0.04, 0.7)
		patch.shadow_size = 16 if active else 10
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			patch.set_content_margin(side, FRAME_INSET)
		# Stretch (not tile) so the hero badge is never repeated; the badge
		# itself is drawn again unstretched by _draw_sewn_frame.
		card.set_meta("sewn_frame", nine_patch(frame, Vector2(FRAME_EDGE, FRAME_EDGE), false))
		card.set_meta("frame_badge", art_texture(ART_DIR + "ui/card_badge_%s.png" % owner))
		if not card.draw.is_connected(_draw_sewn_frame):
			card.draw.connect(_draw_sewn_frame.bind(card))
	card.add_theme_stylebox_override("panel", patch)
	card.queue_redraw()


## A reward card's own illustration lives in cards/art/<base_id>.png; only a
## final "_plus" shares its base card's picture. Fallback order: authored
## picture, then the owning hero's stitched emblem, then a drawn paper patch
## (null), so a valid offer always mounts.
static func card_art_path(card_id: String) -> String:
	return ART_DIR + "cards/art/%s.png" % card_id.trim_suffix("_plus")


static func emblem_path(owner: String) -> String:
	return ART_DIR + "cards/emblem_%s.png" % owner


## Resolve the card face's art once, keeping the authored picture and the owner
## emblem in separate modes so the view can present them differently. Priority:
## the card's own picture, then the owning hero's stitched emblem, then nothing
## (the illustrative view then draws its procedural paper patch).
static func resolve_card_art(card_id: String, owner: String) -> Dictionary:
	var own := art_texture(card_art_path(card_id))
	if own != null:
		return {"mode": _CardIllustration.MODE_CARD_ART, "texture": own}
	var emblem := art_texture(emblem_path(owner))
	if emblem != null:
		return {"mode": _CardIllustration.MODE_EMBLEM, "texture": emblem}
	return {"mode": _CardIllustration.MODE_NONE, "texture": null}


## Texture-only lookup kept for the other mounted card faces (the visit tiles),
## which present the picture and the emblem the same way.
static func _card_art_texture(card_id: String, owner: String) -> Texture2D:
	return resolve_card_art(card_id, owner).get("texture") as Texture2D


static func art_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func nine_patch(texture: Texture2D, edge: Vector2, tile := true) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.texture_margin_left = edge.x
	box.texture_margin_right = edge.x
	box.texture_margin_top = edge.y
	box.texture_margin_bottom = edge.y
	if tile:
		# Repeat the sewn squares along long edges instead of smearing them.
		box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	# Tiled quilts leave their centre to the flat linen underneath (no seams).
	box.draw_center = not tile
	return box


func _draw_sewn_frame(card: PanelContainer) -> void:
	var frame: Variant = card.get_meta("sewn_frame", null)
	if frame is StyleBoxTexture:
		card.draw_style_box(frame, Rect2(Vector2.ZERO, card.size))
	var badge: Variant = card.get_meta("frame_badge", null)
	if badge is Texture2D:
		card.draw_texture(badge, Vector2(roundf((card.size.x - badge.get_width()) * 0.5), 0.0))




func _draw_quilt(control: Control, box: StyleBoxTexture) -> void:
	control.draw_style_box(box, Rect2(Vector2.ZERO, control.size))


func _on_card_gui_input(event: InputEvent, index: int, card_id: String, button: Button) -> void:
	if not _is_open or _accepted or _awaiting_ack:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	_on_choice_pressed(_generation, _node_id, card_id, button)


func _on_card_mouse_entered(index: int) -> void:
	if index < 0 or index >= _card_hovered.size():
		return
	_card_hovered[index] = true
	_update_card_style(index)


func _on_card_mouse_exited(index: int) -> void:
	if index < 0 or index >= _card_hovered.size():
		return
	_card_hovered[index] = false
	_update_card_style(index)


func _on_card_focus_entered(index: int) -> void:
	if index < 0 or index >= _card_focused.size():
		return
	_card_focused[index] = true
	_update_card_style(index)


func _on_card_focus_exited(index: int) -> void:
	if index < 0 or index >= _card_focused.size():
		return
	_card_focused[index] = false
	_update_card_style(index)


func _update_card_style(index: int) -> void:
	if not _is_open or index < 0 or index >= _card_panels.size():
		return
	var card := _card_panels[index]
	if not is_instance_valid(card):
		return
	var owner := ""
	if index < _receipt.get("offers", []).size():
		owner = String((_receipt["offers"][index] as Dictionary).get("owner", ""))
	if owner.is_empty():
		return
	_style_card(card, owner, _card_hovered[index] or _card_focused[index])


func _apply_patchwork_style() -> void:
	title_label.theme_type_variation = &"PatchHeading"
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("#e9dcc3")
	paper.border_color = Color("#736451")
	paper.set_border_width_all(5)
	paper.set_corner_radius_all(14)
	paper.shadow_color = Color(0.03, 0.06, 0.07, 0.8)
	paper.shadow_size = 12
	paper_panel.add_theme_stylebox_override("panel", paper)
	# The readable owner strip is paid for out of the paper's vertical seams so
	# the three cards keep their name, cost, pips, rules and Choose geometry.
	var content_margin := get_node_or_null("PaperPanel/ContentMargin") as MarginContainer
	if content_margin != null:
		content_margin.add_theme_constant_override("margin_top", 15)
		content_margin.add_theme_constant_override("margin_bottom", 15)
	for label in [title_label, gold_label, trinket_label]:
		label.add_theme_color_override("font_color", Color("#263137"))
	title_label.add_theme_font_size_override("font_size", 31)
	gold_label.add_theme_font_size_override("font_size", 22)
	trinket_label.add_theme_font_size_override("font_size", 19)
	_sew_receipt_tab(gold_label, RECEIPT_GOLD_FELT)
	_sew_receipt_tab(trinket_label, RECEIPT_PATCH_FELT)
	for label in [top_stitches, bottom_stitches]:
		label.add_theme_color_override("font_color", Color("#77624f"))
		label.add_theme_font_size_override("font_size", 17)
	_apply_sewn_art(paper, content_margin)


## Sew one reward receipt onto a small tab of its own. The label keeps the exact
## text, visibility, dark ink and point size that open_rewards binds; this only
## gives that line the display face and a muted felt face inside a dark seam.
## Size stays in the label (no wrapper), so the receipt costs one stitched line
## and never crowds the banner, the three cards, Help or Skip.
func _sew_receipt_tab(label: Label, felt: Color) -> void:
	label.theme_type_variation = &"PatchHeading"
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tab := StyleBoxFlat.new()
	tab.bg_color = felt
	tab.border_color = RECEIPT_TAB_BORDER
	tab.set_border_width_all(2)
	tab.set_corner_radius_all(6)
	tab.content_margin_left = RECEIPT_TAB_INSET_X
	tab.content_margin_right = RECEIPT_TAB_INSET_X
	tab.content_margin_top = RECEIPT_TAB_INSET_Y
	tab.content_margin_bottom = RECEIPT_TAB_INSET_Y + 1
	tab.shadow_color = Color(0.16, 0.12, 0.08, 0.35)
	tab.shadow_size = 3
	tab.shadow_offset = Vector2(0, 1)
	label.add_theme_stylebox_override("normal", tab)


## Lays the Flow/ChatGPT patchwork art over the procedural paper: the stitched
## tailor's camp behind everything, a quilt border around the reward, and the
## title sewn onto a felt ribbon. Each piece is skipped when its PNG is absent.
func _apply_sewn_art(paper: StyleBoxFlat, content_margin: MarginContainer) -> void:
	var camp := art_texture(CAMP_BACKDROP)
	if camp != null and get_node_or_null("CampBackdrop") == null:
		var backdrop := TextureRect.new()
		backdrop.name = "CampBackdrop"
		backdrop.texture = camp
		_camp_backdrop = backdrop
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(backdrop)
		move_child(backdrop, 1)
		var shade := ColorRect.new()
		shade.name = "CampShade"
		shade.color = Color(0.04, 0.05, 0.08, 0.35)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(shade)
		move_child(shade, 2)
		# The quilt can now reach almost to the top; the camp shows around it.
		paper_panel.anchor_top = 0.015
		paper_panel.anchor_bottom = 0.985
		paper_panel.anchor_left = 0.02
		paper_panel.anchor_right = 0.98
	var quilt := art_texture(QUILT_PANEL)
	if quilt != null:
		# Plain linen under the quilt's centre, matching the quilt's own weave.
		paper.bg_color = Color("#e3d0b5")
		paper.border_color = Color(paper.border_color, 0.0)
		paper.shadow_size = 18
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			paper.set_content_margin(side, QUILT_INSET)
		if content_margin != null:
			content_margin.add_theme_constant_override("margin_top", 0)
			content_margin.add_theme_constant_override("margin_bottom", 0)
			content_margin.add_theme_constant_override("margin_left", 12)
			content_margin.add_theme_constant_override("margin_right", 12)
		paper_panel.draw.connect(_draw_quilt.bind(paper_panel,
			nine_patch(quilt, Vector2(QUILT_EDGE, QUILT_EDGE))))
		for label in [top_stitches, bottom_stitches]:
			label.add_theme_font_size_override("font_size", 12)
	var banner := art_texture(TITLE_BANNER)
	if banner != null:
		var ribbon := nine_patch(banner, Vector2.ZERO, false)
		ribbon.texture_margin_left = BANNER_LEFT
		ribbon.texture_margin_right = BANNER_RIGHT
		ribbon.content_margin_left = BANNER_LEFT + 24
		ribbon.content_margin_right = BANNER_RIGHT + 24
		ribbon.content_margin_top = 4
		ribbon.content_margin_bottom = 8
		title_label.add_theme_stylebox_override("normal", ribbon)
		title_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		title_label.custom_minimum_size = Vector2(420, BANNER_HEIGHT)
		title_label.add_theme_color_override("font_color", LIGHT_INK)
		title_label.add_theme_color_override("font_shadow_color", Color(0.12, 0.05, 0.03, 0.8))
		title_label.add_theme_constant_override("shadow_offset_y", 2)


## Measure the actual full label and leave the burlap's sewn edge outside
## the glyph bounds, even with a project font wider than the default. The
## display face is already assigned by _style_button, so this measures the
## exact font the fitted Skip action draws.
func _fit_skip_button() -> void:
	var font: Font = skip_button.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var point_size: int = skip_button.get_theme_font_size("font_size")
	var label_width: float = font.get_string_size(skip_button.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x
	var border_space: float = float(BUTTON_EDGE + 12) * 2.0
	skip_button.custom_minimum_size = Vector2(
		ceilf(label_width + border_space),
		maxf(54.0, font.get_height(point_size) + 20.0))


## Resolve the display face a reward action draws with even before the card
## subtree is inside the SceneTree (Control.get_theme_font() cannot yet see the
## project theme there). Once mounted this is the same PatchHeadingButton font
## resource the button resolves, so the measured Help cell matches the label.
func _action_display_font(control: Control) -> Font:
	var theme_path := String(ProjectSettings.get_setting("gui/theme/custom", ""))
	if not theme_path.is_empty():
		var project_theme := load(theme_path) as Theme
		if project_theme != null:
			var themed := project_theme.get_font(&"font", &"PatchHeadingButton")
			if themed != null:
				return themed
	var font: Font = control.get_theme_font(&"font")
	if font != null:
		return font
	return ThemeDB.fallback_font


## Measure the actual Help label in the display face it is drawn with and keep
## the sewn side seams (BUTTON_EDGE each) outside the glyphs, plus a little
## breath. The cell never borrows the owner ribbon's width and the same measured
## minimum serves the procedural face when the burlap art is absent.
func _fit_help_tab(help: Button) -> void:
	var font: Font = _action_display_font(help)
	var point_size: int = help.get_theme_font_size(&"font_size")
	var label_width: float = font.get_string_size(help.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x
	var side_space: float = float(BUTTON_EDGE) * 2.0
	help.custom_minimum_size = Vector2(
		ceilf(label_width + side_space + HELP_TAB_TEXT_BREATH), HELP_TAB_HEIGHT)


func _style_button(button: Button, accent: Color, vertical_edge: int = BUTTON_EDGE) -> void:
	# Every reward action (Choose, Skip, Help and the glossary's Close) is lettered
	# in the project's display face. Assigning the variation first means a later
	# _fit_skip_button measures the font that is actually drawn.
	button.theme_type_variation = &"PatchHeadingButton"
	_apply_sewn_faces(button, accent)
	button.add_theme_font_size_override("font_size", 20)
	_sew_burlap(button, accent, vertical_edge, art_texture(BURLAP_BUTTON))


## The procedural sewn face shared by every reward action: an opaque beige felt
## per draw state, a transparent dark focus stitch and readable ink. It is also
## the complete face when the optional burlap art is missing, so the fallback
## never needs a generated asset to stay readable.
func _apply_sewn_faces(button: Button, accent: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		match state:
			"normal": box.bg_color = Color("#d4bf9e")
			"hover": box.bg_color = Color("#e2cba5")
			"pressed": box.bg_color = Color("#ae9472")
			"disabled": box.bg_color = Color("#a89b87")
		box.border_color = accent
		box.set_border_width_all(3)
		box.set_corner_radius_all(7)
		box.content_margin_left = 10
		box.content_margin_right = 10
		button.add_theme_stylebox_override(state, box)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = _FocusStitch.DARK_FOCUS_INK
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(7)
	button.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		button.add_theme_color_override(state, Color("#263137"))
	# Keyboard focus keeps dark ink on the beige face instead of relying on the
	# engine default focus colour.
	button.add_theme_color_override("font_focus_color", DARK_INK)


## Burlap patch sewn behind a button's label; the procedural face above it is
## made see-through so hover, press and disabled tints still read on top. The
## art is optional: with no texture this returns before touching the opaque
## faces, so the plain sewn button keeps serving every action.
## `vertical_edge` shrinks only the top and bottom slice, for the short Help tab;
## the left and right seams always keep the normal BUTTON_EDGE width.
func _sew_burlap(button: Button, accent: Color, vertical_edge: int,
		burlap: Texture2D) -> void:
	if burlap == null:
		return
	var tints := {"normal": Color(1, 1, 1, 0.0), "hover": Color(1, 0.97, 0.88, 0.22),
		"pressed": Color(0.2, 0.15, 0.1, 0.2), "disabled": Color(0.35, 0.33, 0.3, 0.45)}
	for state: String in tints:
		var box := button.get_theme_stylebox(state) as StyleBoxFlat
		if box != null:
			box.bg_color = tints[state]
			box.border_color = Color(accent, 0.85)
			box.set_border_width_all(2)
			box.set_corner_radius_all(10)
	if button.get_node_or_null("BurlapPatch") != null:
		return
	var patch := NinePatchRect.new()
	patch.name = "BurlapPatch"
	patch.texture = burlap
	patch.patch_margin_left = BUTTON_EDGE
	patch.patch_margin_right = BUTTON_EDGE
	patch.patch_margin_top = vertical_edge
	patch.patch_margin_bottom = vertical_edge
	patch.show_behind_parent = true
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(patch)
	button.move_child(patch, 0)


## A dark, hand-sewn dashed perimeter that follows this button's keyboard focus.
## The stitch is decoration only: it takes no focus and ignores the mouse.
func _add_focus_stitch(button: Button) -> void:
	if button.get_node_or_null("FocusStitch") != null:
		return
	var stitch := _FocusStitch.new()
	stitch.name = "FocusStitch"
	stitch.target = button
	button.add_child(stitch)


## WCAG relative luminance of a sRGB colour, used only to pick the readable ink
## for each owner felt. Pure helper: no palette or layout state.
static func relative_luminance(color: Color) -> float:
	var channels: Array[float] = [color.r, color.g, color.b]
	var linear: Array[float] = []
	for channel: float in channels:
		linear.append(channel / 12.92 if channel <= 0.03928
			else pow((channel + 0.055) / 1.055, 2.4))
	return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


static func contrast_ratio(first: Color, second: Color) -> float:
	var first_light: float = relative_luminance(first)
	var second_light: float = relative_luminance(second)
	return (maxf(first_light, second_light) + 0.05) / (minf(first_light, second_light) + 0.05)


## The hero name sewn on the owner strip must stay legible on that hero's felt,
## so the better-contrasting ink is chosen per palette colour instead of blindly
## using dark ink on the dark warden/seamstress felts.
static func owner_ink(owner: String) -> Color:
	var felt: Color = OWNER_COLORS.get(owner, Color("#736451"))
	if contrast_ratio(DARK_INK, felt) >= contrast_ratio(LIGHT_INK, felt):
		return DARK_INK
	return LIGHT_INK


static func _humanize_patch(id: String) -> String:
	if id.is_empty():
		return ""
	var parts: PackedStringArray = id.split("_")
	var words: PackedStringArray = []
	for part in parts:
		if not part.is_empty():
			words.append(part.capitalize())
	return " ".join(words)


## The card's illustration window. Three modes, in fallback order:
## authored card art (cover, aspect preserved), the owning hero's
## emblem (complete above a cropped texture backing), or, when both
## resources are missing, a drawn cream/stitched paper patch. It never takes
## pointer input or focus, so the card's own click and every button keep working
## exactly as before.
class _CardIllustration extends Control:
	const MODE_CARD_ART := "card_art"
	const MODE_EMBLEM := "emblem"
	const MODE_NONE := "none"
	## Full-width stitched owner-felt inset for the hero emblem.
	const FELT_INSET := 5.0
	const EMBLEM_INSET := 8.0

	@export var picture: Texture2D
	## How `picture` is presented. Card art covers the illustration inset;
	## the reward panel
	## asks for the broad sewn-felt mode when only an owner emblem was available.
	@export var mode: String = MODE_CARD_ART
	@export var owner_color: Color = Color.WHITE
	## Paint-only offsets. The Control, its hit rect, and its sewn seam never move.
	var picture_offset := Vector2.ZERO
	var picture_degrees := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		clip_contents = true
		resized.connect(queue_redraw)

	func set_picture_motion(offset: Vector2, degrees: float) -> void:
		if picture == null:
			offset = Vector2.ZERO
			degrees = 0.0
		if picture_offset == offset and picture_degrees == degrees:
			return
		picture_offset = offset
		picture_degrees = degrees
		queue_redraw()

	func _paint_picture_transform() -> void:
		# Rotate around the image window centre, *inside* the clipped window.
		draw_set_transform(size * 0.5 + picture_offset, deg_to_rad(picture_degrees))

	func _end_picture_transform() -> void:
		draw_set_transform(Vector2.ZERO)

	## True when a real authored picture or hero emblem is bound.
	func has_picture() -> bool:
		return picture != null

	## The authored card picture is bound and covers the illustration inset.
	func is_card_art() -> bool:
		return picture != null and mode == MODE_CARD_ART

	## Only an owner emblem was available, so it uses the wide felt backing.
	func is_emblem() -> bool:
		return picture != null and mode == MODE_EMBLEM

	## Neither resource loaded: the window draws its own stitched paper patch.
	func is_paper_patch() -> bool:
		return picture == null

	func window_rect() -> Rect2:
		return Rect2(Vector2.ZERO, size)

	## Wide sewn backing that fills almost the whole illustration window.
	func emblem_backing_rect() -> Rect2:
		var inset: float = minf(FELT_INSET, minf(size.x, size.y) * 0.25)
		return Rect2(Vector2.ONE * inset,
			(size - Vector2.ONE * inset * 2.0).max(Vector2.ZERO))

	## A second copy of the same emblem fills the felt beneath the complete one.
	func emblem_backdrop_rect() -> Rect2:
		if not is_emblem():
			return Rect2()
		var target: Rect2 = emblem_backing_rect()
		if target.size.x <= 0.0 or target.size.y <= 0.0:
			return Rect2()
		return target

	func emblem_backdrop_source_rect() -> Rect2:
		var target: Rect2 = emblem_backdrop_rect()
		if target.size.x <= 0.0 or target.size.y <= 0.0:
			return Rect2()
		var art_size: Vector2 = picture.get_size()
		if art_size.x <= 0.0 or art_size.y <= 0.0:
			return Rect2()
		var scale_factor: float = maxf(target.size.x / art_size.x, target.size.y / art_size.y)
		var crop_size: Vector2 = (target.size / scale_factor).min(art_size)
		return Rect2((art_size - crop_size) * 0.5, crop_size)

	## Exact destination rect the picture is painted into. Card art covers the
	## sewn window's inset; an emblem fits its felt inset
	## and leaves its full image bounds clear of the perimeter stitches.
	func picture_rect() -> Rect2:
		if picture == null:
			return Rect2()
		var art_size: Vector2 = picture.get_size()
		if art_size.x <= 0.0 or art_size.y <= 0.0:
			return Rect2()
		var area: Rect2 = window_rect().grow(-8.0)
		if mode == MODE_EMBLEM:
			area = emblem_backing_rect().grow(-EMBLEM_INSET)
		if area.size.x <= 0.0 or area.size.y <= 0.0:
			return Rect2()
		if mode == MODE_CARD_ART:
			return area
		var fit: float = minf(area.size.x / art_size.x, area.size.y / art_size.y)
		var target: Vector2 = art_size * fit
		return Rect2(area.get_center() - target * 0.5, target)

	## Centered source crop matching the destination aspect, without stretching.
	## Emblems retain their entire source image.
	func picture_source_rect() -> Rect2:
		var target: Rect2 = picture_rect()
		if target.size.x <= 0.0 or target.size.y <= 0.0:
			return Rect2()
		var art_size: Vector2 = picture.get_size()
		if mode != MODE_CARD_ART:
			return Rect2(Vector2.ZERO, art_size)
		var scale_factor: float = maxf(target.size.x / art_size.x, target.size.y / art_size.y)
		var crop_size: Vector2 = (target.size / scale_factor).min(art_size)
		return Rect2((art_size - crop_size) * 0.5, crop_size)

	## Back the full illustration inset with its sewn frame.
	func sewn_backing_rect() -> Rect2:
		return window_rect()

	func _draw() -> void:
		var rect := sewn_backing_rect()
		if is_emblem():
			_draw_felt_fallback()
			_draw_contained_picture()
		elif picture != null:
			draw_rect(rect, Color("#ddcfb7"))
			if is_card_art():
				_draw_cover_picture()
			else:
				_draw_contained_picture()
		else:
			draw_rect(rect, Color("#f1e6cf"))
			_draw_paper_patch(rect)
		_draw_sewn_seam(rect)

	func _draw_cover_picture() -> void:
		var target: Rect2 = picture_rect()
		var source: Rect2 = picture_source_rect()
		if source.size.x <= 0.0 or source.size.y <= 0.0:
			return
		_paint_picture_transform()
		draw_texture_rect_region(picture, Rect2(target.position - size * 0.5, target.size), source)
		_end_picture_transform()

	## The whole emblem, contained (never distorted) and centred.
	func _draw_contained_picture() -> void:
		var target: Rect2 = picture_rect()
		if target.size.x <= 0.0 or target.size.y <= 0.0:
			return
		_paint_picture_transform()
		draw_texture_rect(picture, Rect2(target.position - size * 0.5, target.size), false)
		_end_picture_transform()

	## A matte felt landscape patch, off-centre corner pieces and running seams.
	## The sewn backing is wide; no empty cream box surrounds a tiny emblem.
	func _draw_felt_fallback() -> void:
		var backing: Rect2 = emblem_backing_rect()
		if backing.size.x <= 0.0 or backing.size.y <= 0.0:
			return
		draw_rect(backing, owner_color)
		var left_piece := PackedVector2Array([
			backing.position, backing.position + Vector2(backing.size.x * 0.22, 0),
			backing.position + Vector2(0, backing.size.y * 0.85)])
		draw_colored_polygon(left_piece, owner_color.lightened(0.12))
		var right_piece := PackedVector2Array([
			backing.end, backing.end - Vector2(backing.size.x * 0.22, 0),
			backing.end - Vector2(0, backing.size.y * 0.85)])
		draw_colored_polygon(right_piece, owner_color.darkened(0.12))
		var source: Rect2 = emblem_backdrop_source_rect()
		if source.size.x > 0.0 and source.size.y > 0.0:
			draw_texture_rect_region(picture, emblem_backdrop_rect(), source, Color(1, 1, 1, 0.45))
		draw_rect(backing, Color("#3b2f2a"), false, 2.0)
		var seam: Rect2 = backing.grow(-4.0)
		if seam.size.x > 0.0 and seam.size.y > 0.0:
			for y: float in [seam.position.y, seam.end.y]:
				draw_dashed_line(Vector2(seam.position.x, y),
					Vector2(seam.end.x, y), Color("#f1e6cf"), 1.6, 9.0)
			for x: float in [seam.position.x, seam.end.x]:
				draw_dashed_line(Vector2(x, seam.position.y),
					Vector2(x, seam.end.y), Color("#f1e6cf"), 1.6, 9.0)

	## Drawn paper fallback: an owner-felt cross-stitch on cream.
	func _draw_paper_patch(rect: Rect2) -> void:
		draw_rect(rect.grow(-8.0), Color(owner_color, 0.16))
		var center: Vector2 = rect.size * 0.5
		var reach: float = minf(rect.size.x, rect.size.y) * 0.3
		draw_dashed_line(center - Vector2(reach, 0.0), center + Vector2(reach, 0.0),
			owner_color, 2.0, 5.0)
		draw_dashed_line(center - Vector2(0.0, reach), center + Vector2(0.0, reach),
			owner_color, 2.0, 5.0)

	## Dark felt edge and a cream running stitch around the whole window.
	func _draw_sewn_seam(rect: Rect2) -> void:
		draw_rect(rect, Color("#3b2f2a"), false, 3.0)
		var inner: Rect2 = rect.grow(-6.0)
		draw_dashed_line(inner.position, Vector2(inner.end.x, inner.position.y),
			Color("#f1e6cf", 0.9), 2.0, 7.0)
		draw_dashed_line(Vector2(inner.end.x, inner.position.y), inner.end,
			Color("#f1e6cf", 0.9), 2.0, 7.0)
		draw_dashed_line(inner.end, Vector2(inner.position.x, inner.end.y),
			Color("#f1e6cf", 0.9), 2.0, 7.0)
		draw_dashed_line(Vector2(inner.position.x, inner.end.y), inner.position,
			Color("#f1e6cf", 0.9), 2.0, 7.0)


## Owner color patch (sewn stripe at top of card)
class _OwnerPatch extends Control:
	@export var owner_color: Color = Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var rect := Rect2(Vector2(0, 0), size)
		# Draw the patch background
		draw_rect(rect, owner_color)
		# Draw running stitch along bottom edge
		var y := rect.end.y - 2
		draw_dashed_line(Vector2(rect.position.x + 8, y), Vector2(rect.end.x - 8, y), STITCH_THREAD, 1.5, 6.0)
		# Draw running stitch along top edge
		y = rect.position.y + 2
		draw_dashed_line(Vector2(rect.position.x + 8, y), Vector2(rect.end.x - 8, y), STITCH_THREAD, 1.5, 6.0)


## Dark, visibly dashed seam that follows one button's keyboard focus. The
## dashes walk all four sides inside the control's own rect and nothing is
## filled, so the beige button face and its dark label keep their contrast.
## Input passes straight through: it takes no focus and ignores the mouse.
class _FocusStitch extends Control:
	const DARK_FOCUS_INK := Color("#2b2624")
	const INSET := 5.0
	const THICKNESS := 2.0
	const DASH := 7.0
	const GAP := 5.0

	@export var target: Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)
		if target != null:
			target.focus_entered.connect(queue_redraw)
			target.focus_exited.connect(queue_redraw)

	## Only a real, focused and enabled button paints the perimeter.
	func is_stitching() -> bool:
		if target == null or not is_instance_valid(target):
			return false
		if not target.is_visible_in_tree() or not target.has_focus():
			return false
		if target is BaseButton and (target as BaseButton).disabled:
			return false
		return true

	func perimeter_rect() -> Rect2:
		var inset := Vector2(INSET, INSET)
		return Rect2(inset, (size - inset * 2.0).max(Vector2.ZERO))

	## Short dashes walked around the four sides in reading order, so the
	## perimeter is visibly stitched rather than a solid outline.
	func stitch_dashes() -> Array[PackedVector2Array]:
		var rect: Rect2 = perimeter_rect()
		var dashes: Array[PackedVector2Array] = []
		_walk(rect.position, Vector2(rect.end.x, rect.position.y), dashes)
		_walk(Vector2(rect.end.x, rect.position.y), rect.end, dashes)
		_walk(rect.end, Vector2(rect.position.x, rect.end.y), dashes)
		_walk(Vector2(rect.position.x, rect.end.y), rect.position, dashes)
		return dashes

	func _walk(from: Vector2, to: Vector2, dashes: Array[PackedVector2Array]) -> void:
		var length: float = from.distance_to(to)
		if length <= 0.0:
			return
		var travelled: float = 0.0
		while travelled < length:
			var dash_end: float = minf(travelled + DASH, length)
			if dash_end - travelled >= DASH * 0.5:
				dashes.append(PackedVector2Array([
					from.lerp(to, travelled / length),
					from.lerp(to, dash_end / length),
				]))
			travelled = dash_end + GAP

	func _draw() -> void:
		if not is_stitching():
			return
		for dash: PackedVector2Array in stitch_dashes():
			draw_line(dash[0], dash[1], DARK_FOCUS_INK, THICKNESS, true)


## Round sewn energy coin, drawn exactly like the shared hand's cost coin: a
## golden felt disc with a pale rim and a stitched ring around a centred numeral.
## Decoration only; the authored cost text is drawn from the coin's own font
## metrics so 0, 1 and 2 stay centred inside their glyph bounds.
class _CostButton extends Control:
	@export var cost_value: int = 0
	## Kept because every mounted offer records its owner palette here; the coin
	## itself matches the hand's gold regardless of owner.
	@export var owner_color: Color = Color.WHITE

	## Same golden felt the live hand paints its energy coin with.
	const COIN_GOLD := Color("#c49a3a")
	const COIN_RIM := Color("#ece0c8")
	const STITCH_COUNT := 12

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		resized.connect(queue_redraw)

	func coin_color() -> Color:
		return COIN_GOLD

	func coin_radius() -> float:
		return minf(size.x, size.y) * 0.5

	## One font size for every numeral, decided once from the coin's own size.
	func numeral_font_size() -> int:
		return maxi(18, int(coin_radius() * 0.9))

	func numeral_text() -> String:
		return str(cost_value)

	## The exact baseline origin draw_string() needs: the advance width comes
	## from the drawn point size and the baseline is offset by half the real
	## ascent/descent so the numeral's ink box sits on the coin's centre.
	func numeral_origin(font: Font) -> Vector2:
		var point_size: int = numeral_font_size()
		var advance: Vector2 = font.get_string_size(numeral_text(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, point_size)
		var ascent: float = font.get_ascent(point_size)
		var descent: float = font.get_descent(point_size)
		var center: Vector2 = size * 0.5
		return Vector2(center.x - advance.x * 0.5, center.y + (ascent - descent) * 0.5)

	## Measured ink box of the numeral at the font size actually drawn.
	func numeral_bounds(font: Font) -> Rect2:
		var point_size: int = numeral_font_size()
		var origin: Vector2 = numeral_origin(font)
		var advance: Vector2 = font.get_string_size(numeral_text(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, point_size)
		var ascent: float = font.get_ascent(point_size)
		var descent: float = font.get_descent(point_size)
		return Rect2(origin.x, origin.y - ascent, advance.x, ascent + descent)

	## Ring radius for the stitches: inside the rim, outside every numeral bound.
	func stitch_radius() -> float:
		return maxf(0.0, coin_radius() - 4.0)

	## Dashed ring spans, as (start_angle, end_angle). Never a diameter line.
	func stitch_spans() -> Array[Vector2]:
		var spans: Array[Vector2] = []
		var step: float = TAU / float(STITCH_COUNT)
		for index in range(STITCH_COUNT):
			var start: float = step * float(index) + step * 0.15
			spans.append(Vector2(start, start + step * 0.55))
		return spans

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = coin_radius()
		var font: Font = get_theme_default_font()
		if font == null:
			font = ThemeDB.fallback_font
		draw_circle(center, radius, COIN_GOLD)
		draw_arc(center, maxf(0.0, radius - 1.0), 0.0, TAU, 32, COIN_RIM, 1.5, true)
		for span: Vector2 in stitch_spans():
			draw_arc(center, stitch_radius(), span.x, span.y, 6, STITCH_THREAD, 2.0, true)
		draw_string(font, numeral_origin(font), numeral_text(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, numeral_font_size(), DARK_INK)


## Authored position marks, identical in convention to the shared hand's pips:
## three source circles (owner-colour filled when legal, outlined when not) and
## three target squares (ink filled when legal, outlined when not). Slot 1 is
## always the front. An all-enemy cast also sews its filled squares together.
## The readable target kind lives in the hover legend; this control draws no
## glyph and no miniature number.
class _PositionPips extends Control:
	@export var from_positions: Array[int] = []
	@export var to_positions: Array[int] = []
	@export var target_kind: String = ""
	@export var owner_color: Color = Color.WHITE

	const SLOT_COUNT := 3
	const SLOT_RADIUS := 6.0
	const SLOT_GAP := 15.0
	const GROUP_GAP := 24.0
	const OUTLINE := Color("#9e6f58")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	## Exactly six drawable slots in a stable order: three circles (source
	## positions 1..3) then three squares (target positions 1..3). Filled only
	## when the resolved definition authorises that position.
	func slots() -> Array[Dictionary]:
		var markers: Array[Dictionary] = []
		var radius: float = SLOT_RADIUS
		var group_width: float = float(SLOT_COUNT - 1) * SLOT_GAP + radius * 2.0
		var total_width: float = group_width * 2.0 + GROUP_GAP
		var first_x: float = maxf(radius + 2.0, (size.x - total_width) * 0.5 + radius)
		var y: float = size.y * 0.5
		for index in range(1, SLOT_COUNT + 1):
			markers.append({
				"shape": "circle",
				"position": index,
				"center": Vector2(first_x + SLOT_GAP * float(index - 1), y),
				"radius": radius,
				"filled": from_positions.has(index),
			})
		var square_x: float = first_x + group_width + GROUP_GAP
		for index in range(1, SLOT_COUNT + 1):
			markers.append({
				"shape": "square",
				"position": index,
				"center": Vector2(square_x + SLOT_GAP * float(index - 1), y),
				"radius": radius,
				"filled": to_positions.has(index),
			})
		return markers

	## The sewn thread across an all-enemy cast: from the first filled square to
	## the last. Empty for every other target kind or fewer than two squares.
	func thread_points() -> PackedVector2Array:
		var filled: Array[Vector2] = []
		for marker: Dictionary in slots():
			if String(marker["shape"]) == "square" and bool(marker["filled"]):
				filled.append(marker["center"] as Vector2)
		if target_kind == "enemy_all" and filled.size() >= 2:
			return PackedVector2Array([filled.front(), filled.back()])
		return PackedVector2Array()

	func _draw() -> void:
		for marker: Dictionary in slots():
			var center: Vector2 = marker["center"]
			var radius: float = marker["radius"]
			var filled: bool = marker["filled"]
			if String(marker["shape"]) == "circle":
				if filled:
					draw_circle(center, radius, owner_color)
					draw_arc(center, radius, 0.0, TAU, 16, STITCH_THREAD, 1.0, true)
				else:
					draw_arc(center, radius, 0.0, TAU, 16, OUTLINE, 1.5, true)
			else:
				var box := Rect2(center - Vector2(radius, radius), Vector2.ONE * radius * 2.0)
				if filled:
					draw_rect(box, DARK_INK, true)
				else:
					draw_rect(box, CARD_PAPER, true)
					draw_rect(box, OUTLINE, false, 1.5)
		# The thread is drawn last so it visibly joins the legal squares of a
		# whole-area cast; no other target kind claims an area.
		var thread := thread_points()
		if thread.size() == 2:
			draw_dashed_line(thread[0], thread[1], STITCH_THREAD, 1.5, 4.0)
