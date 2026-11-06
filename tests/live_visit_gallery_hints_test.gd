extends SceneTree
const LEGACY_ENTRY := preload("res://tests/legacy_card_app_fixture.gd")
## Deterministic checks for the mounted Shop/Rest gallery guidance typography.
##
## The gallery's visit hint, section prompts and empty-state notes are built by
## LiveVisitCardTiles.build_gallery_hint/build_gallery_note, the same factories
## the mounted gallery calls. The detached labels below check the complete
## published sentences, body-size type, word wrap, dark ink on cream paper and
## pointer/keyboard inertness. The real ?screen=shop and ?screen=rest previews
## then confirm that the labels actually on screen carry that same treatment at
## 1280x720. No screenshot, no guessed coordinate and no parallel label copy.

const GALLERY := preload("res://scripts/live_visit_card_tiles.gd")
## The gallery board's cream paper, copied from the published art direction so
## the contrast oracle never borrows the presenter's own ink/paper constants.
const PAPER := Color("#e8dcc4")
## MILESTONES VIS V2 body-text minimum and the AA body-text contrast minimum.
const MIN_BODY_SIZE := 18
const MIN_CONTRAST := 4.5
## A deliberately narrow probe column: narrower than the real gallery, so every
## published sentence below must wrap instead of being clipped or shortened.
const PROBE_WIDTH := 180.0

## The published guidance copied from the visit contract, not read back from the
## presenter, so a shortened or replaced sentence fails this oracle.
const SHOP_GUIDANCE := "Choose a card, then press Buy or Remove."
const SHOP_SALE_HINT := "Choose a card, then press Buy to pay its price."
const SHOP_REMOVE_HINT := "Every copy in your deck has its own card. Choose one, then press Remove."
const SHOP_EMPTY_NOTE := "No cards are for sale at this Shop."
const SHOP_REMOVE_EMPTY_NOTE := "This Shop is not removing cards today."
const REST_GUIDANCE := "Choose a card, then press Upgrade — or take Heal instead."
const REST_MEND_HINT := "Choose one owned copy, then press Upgrade. Heal is still available."
const REST_EMPTY_NOTE := "No card can be mended at this Rest; Heal is still available."

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _frames() -> void:
	for frame in range(4):
		await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	await _check_detached_labels()
	await _check_mounted_labels("shop")
	await _check_mounted_labels("rest")
	for failure in failures:
		printerr(failure)
	print("live_visit_gallery_hints_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


# --- detached labels from the presenter's own factories -------------------

## AC1/AC2: every guidance family - the visit hint, both Shop section prompts,
## the Rest section prompt and all three empty-state notes - is built by the
## same presenter factory the mounted gallery uses, keeps its complete sentence,
## and measures body size, wrapped, dark on paper and inert.
func _check_detached_labels() -> void:
	var gallery = GALLERY.new()
	gallery.name = "GalleryHintProbe"
	root.add_child(gallery)
	await process_frame
	var cases: Array = [
		[gallery.build_gallery_hint("GalleryHint", SHOP_GUIDANCE),
			"GalleryHint", SHOP_GUIDANCE, "Shop visit guidance"],
		[gallery.build_gallery_hint("GalleryHint", REST_GUIDANCE),
			"GalleryHint", REST_GUIDANCE, "Rest visit guidance"],
		[gallery.build_gallery_hint("GallerySectionHint1", SHOP_SALE_HINT),
			"GallerySectionHint1", SHOP_SALE_HINT, "Shop Cards for sale prompt"],
		[gallery.build_gallery_hint("GallerySectionHint2", SHOP_REMOVE_HINT),
			"GallerySectionHint2", SHOP_REMOVE_HINT, "Shop Remove a card prompt"],
		[gallery.build_gallery_hint("GallerySectionHint1", REST_MEND_HINT),
			"GallerySectionHint1", REST_MEND_HINT, "Rest Mend a card prompt"],
		[gallery.build_gallery_note("GalleryNote1", SHOP_EMPTY_NOTE),
			"GalleryNote1", SHOP_EMPTY_NOTE, "Shop empty-offer note"],
		[gallery.build_gallery_note("GalleryNote2", SHOP_REMOVE_EMPTY_NOTE),
			"GalleryNote2", SHOP_REMOVE_EMPTY_NOTE, "Shop empty-removal note"],
		[gallery.build_gallery_note("GalleryNote1", REST_EMPTY_NOTE),
			"GalleryNote1", REST_EMPTY_NOTE, "Rest empty-mend note"],
	]
	_check(cases.size() == 8, "the detached probe covers every guidance family and visit")
	# One narrow column per label keeps each node's own published name while the
	# column width forces the autowrapped sentence onto more than one line.
	var columns: Array = []
	for entry in cases:
		var column := VBoxContainer.new()
		column.name = "ProbeColumn"
		column.add_theme_constant_override("separation", 6)
		column.size = Vector2(PROBE_WIDTH, 260.0)
		column.add_child(entry[0])
		root.add_child(column)
		columns.append(column)
	await _frames()
	for entry in cases:
		_check_hint_label(entry[0], entry[1], entry[2], entry[3], null)
	for column in columns:
		column.free()
	gallery.free()
	await process_frame


# --- the real mounted previews --------------------------------------------

## AC1/AC2: on the real 1280x720 Shop and Rest preview, the mounted GalleryHint
## and every section prompt are the complete published sentences at body size
## with wrap, dark ink on the gallery's own paper and no pointer/keyboard target.
## The board still fits inside the window and mounting it changes no wallet,
## deck or RNG state.
func _check_mounted_labels(screen: String) -> void:
	var app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var boot = root.get_node("LiveWebPlaytestBoot")
	var entered: bool = await LEGACY_ENTRY.enter_preview(boot, app, screen)
	_check(entered, "real mounted " + screen + " preview precondition")
	if screen == "shop":
		await _check_peddler_labels(app)
		app.free()
		await process_frame
		return
	var gallery = app.get_node_or_null("LiveVisitCardTiles")
	_check(gallery != null and gallery.is_gallery_mounted()
		and gallery.gallery_kind() == screen.capitalize(),
		screen + " mounts the real visit card gallery")
	if gallery == null or not gallery.is_gallery_mounted():
		app.free()
		await process_frame
		return
	var panel: Control = gallery.gallery_panel()
	_check(panel != null and panel.is_visible_in_tree(),
		screen + " gallery panel is mounted and visible")
	if panel == null:
		app.free()
		await process_frame
		return
	var wallet := [app.session_gold, app.run_scraps, app.run_deck.duplicate(true)]
	var rng = app.run_rng
	var rng_state: Variant = rng.state if rng != null else null

	var hint := panel.find_child("GalleryHint", true, false) as Label
	_check_hint_label(hint, "GalleryHint",
		SHOP_GUIDANCE if screen == "shop" else REST_GUIDANCE,
		screen + " mounted visit hint", panel, false)
	var section_hints: Array = panel.find_children("GallerySectionHint*", "Label", true, false)
	_check(not section_hints.is_empty(), screen + " mounts real section prompts")
	var expected_prompts: Array = [SHOP_SALE_HINT, SHOP_REMOVE_HINT] \
		if screen == "shop" else [REST_MEND_HINT]
	for expected in expected_prompts:
		var found: Label = null
		for node in section_hints:
			if (node as Label).text == expected:
				found = node
				break
		_check(found != null, screen + " mounts its complete section prompt: " + expected)
		if found != null:
			_check_hint_label(found, String(found.name), expected,
				screen + " mounted section prompt", panel, false, true)

	var board: StyleBox = panel.get_theme_stylebox("panel")
	_check(board is StyleBoxFlat and (board as StyleBoxFlat).bg_color == PAPER,
		screen + " gallery board really is the published cream paper")
	_check(Rect2(0, 0, 1280, 720).grow(0.5).encloses(panel.get_global_rect()),
		screen + " gallery with body-size guidance still fits inside 1280x720")

	await _frames()
	_check([app.session_gold, app.run_scraps, app.run_deck] == wallet,
		screen + " mounting and reading the guidance spends nothing and leaves the deck alone")
	if rng != null:
		_check(app.run_rng.state == rng_state, screen + " reading the guidance draws no RNG")
	app.free()
	await process_frame


# --- one guidance label ----------------------------------------------------

## The routed Shop now prints its guidance and exact prices directly on the
## one-choice Peddler rail. The detached legacy gallery typography checks and
## the complete mounted Rest gallery assertions above remain in place.
func _check_peddler_labels(app) -> void:
	_check(app.peddler_visit != null and app.peddler_visit.is_open()
		and app.peddler_buttons.size() == 4 and is_instance_valid(app.shop_view),
		"real Peddler preview has an open authority and four direct choices")
	if app.peddler_visit == null or not is_instance_valid(app.shop_view):
		return
	var before: Dictionary = app._sewing_context()
	var bound: Dictionary = app.peddler_visit.read_state()
	var panel: LivePeddlerPanel = app.shop_view
	var title: Label = panel.title_label
	_check(title != null and title.text == LivePeddlerPanel.TITLE_TEXT
		and title.get_theme_font_size("font_size") >= MIN_BODY_SIZE,
		"mounted Peddler guidance states the single-purchase rule at readable size")
	var wallet: Label = app.shop_label
	_check(wallet.text == "Wallet  ·  %d gold" % bound.state.gold and wallet.is_visible_in_tree()
		and wallet.get_theme_font_size("font_size") >= MIN_BODY_SIZE,
		"mounted wallet prints the complete authoritative gold amount at body size")
	for label: Label in [title, wallet]:
		_check(not label.clip_text and label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING
			and label.mouse_filter == Control.MOUSE_FILTER_IGNORE and label.focus_mode == Control.FOCUS_NONE
			and label.gui_input.get_connections().is_empty(), "Peddler guidance stays complete and input-inert")
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
	var prices := {}
	for record in authored.cards + authored.trinkets:
		prices[record.id] = int(record.price)
	var offers: Array = bound.stock.cards + bound.stock.trinkets
	for i in range(4):
		var offer: Dictionary = offers[i]
		var expected: String = panel._card_caption(i) if i < 3 else panel._patch_caption()
		var button: Button = app.peddler_buttons[i]
		_check(button.text == expected and button.get_meta("offer_id") == offer.id
			and offer.price == prices[offer.id] and button.disabled == (offer.sold or bound.state.gold < offer.price),
			"every direct Peddler choice prints its complete catalog name and authored price")
		var size := button.get_theme_font_size("font_size")
		# VIS-A compact tickets: each choice caption is two stacked lines, so the
		# honest fit oracle is the widest actual rendered line. Measuring both
		# lines as one string would demand their sum fit a single row.
		var widest := 0.0
		for line in expected.split("\n"):
			widest = maxf(widest, button.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		_check(size >= MIN_BODY_SIZE and widest + button.get_theme_stylebox("normal").get_minimum_size().x <= button.size.x,
			"short Peddler price sentence fits its real sewn button without truncation")
	_check(app.peddler_leave_button.text == LivePeddlerPanel.LEAVE_TEXT and not app.peddler_leave_button.disabled,
		"Peddler always prints an available free Leave")
	for control in [app.shop_view, title, wallet] + app.peddler_buttons + [app.peddler_leave_button]:
		_check(control.is_visible_in_tree() and Rect2(0, 0, 1280, 720).grow(0.5).encloses(control.get_global_rect()),
			"Peddler guidance and every priced action fit the live viewport")
	await _frames()
	_check(app._sewing_context() == before and app.peddler_visit.read_state() == bound,
		"reading Peddler guidance changes no run ledger, stock or seeded RNG")


## One guidance label's real measured facts: its complete published text and
## node name, effective body size, word wrap with no trimming, dark ink against
## the gallery paper, inert pointer/keyboard state, and (when mounted in a
## gallery) a rect inside the board. A label that wrapped is proven by its own
## line count, not by the string alone.
func _check_hint_label(label: Variant, expected_name: String, expected_text: String,
		label_text: String, panel: Control, must_wrap := true,
		in_scroll := false) -> void:
	_check(label != null and label is Label, label_text + " is a real Label")
	if not (label is Label):
		return
	var hint := label as Label
	_check(String(hint.name) == expected_name,
		label_text + " keeps its published node name: " + expected_name)
	_check(hint.text == expected_text,
		label_text + " keeps the complete published sentence without truncation")
	_check(not hint.clip_text and hint.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING,
		label_text + " never clips or trims its sentence")
	_check(hint.get_theme_font_size("font_size") >= MIN_BODY_SIZE,
		label_text + " uses body type of at least " + str(MIN_BODY_SIZE) + " px")
	var font: Font = hint.get_theme_font("font")
	var size: int = hint.get_theme_font_size("font_size")
	_check(font != null and size >= MIN_BODY_SIZE and font.get_height(size) >= 16.0,
		label_text + " resolves a real body face at its body size")
	_check(hint.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		label_text + " keeps smart word wrap")
	if must_wrap:
		_check(hint.get_line_count() >= 2,
			label_text + " wraps onto more than one line in a narrow column instead of overflowing")
	_check(hint.size.y + 0.5 >= hint.get_minimum_size().y and hint.size.y > 0.0,
		label_text + " is laid out tall enough for every wrapped line")
	var ink: Color = hint.get_theme_color("font_color")
	_check(_luminance(ink) < 0.2, label_text + " prints dark ink")
	_check(_contrast(ink, PAPER) >= MIN_CONTRAST,
		label_text + " keeps body-text contrast on the cream paper ("
			+ str(snappedf(_contrast(ink, PAPER), 0.01)) + ")")
	_check(not (label is BaseButton),
		label_text + " is guidance text, not a pressed action")
	_check(hint.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		label_text + " is not a pointer target")
	_check(hint.focus_mode == Control.FOCUS_NONE,
		label_text + " is not a keyboard focus target")
	_check(hint.gui_input.get_connections().is_empty(),
		label_text + " has no click handler")
	if panel != null and is_instance_valid(panel):
		var paper := panel.get_global_rect().grow(0.5)
		var rect := hint.get_global_rect()
		_check(rect.position.x >= paper.position.x and rect.end.x <= paper.end.x,
			label_text + " stays inside the mounted gallery's paper width")
		if not in_scroll:
			_check(paper.encloses(rect),
				label_text + " sits fully inside the mounted gallery paper")


func _luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b


func _contrast(a: Color, b: Color) -> float:
	var high := maxf(_luminance(a), _luminance(b))
	var low := minf(_luminance(a), _luminance(b))
	return (high + 0.05) / (low + 0.05)
