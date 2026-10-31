class_name LiveEventChoicePanel
extends Control
## Presentation for an authored M04 Event, mounted by the app's routed Event flow.
## The open parchment reads as one story: the PatchHeading title and the fully
## wrapped description take only their natural height, and the authored choice
## tickets sit directly beneath them on the same sewn paper sheet (no stretch
## spacer). open_event() preserves the legacy ID-only signal.
## open_event_with_wallet() displays an opt-in, detached affordability forecast
## and emits an uncommitted wallet receipt for the run owner to validate.
## open_event_with_vitals() adds a third, opt-in presentation: one already
## authenticated living hero's vitality snapshot beside the service's signed
## gold, scraps, HP and max HP deltas, emitting an uncommitted vital receipt for
## the run owner. None of these modes updates the live run, owns RNG, or
## completes routed Events.
## Every mounted choice carries read-only hover text built from the authored
## action and the service-parsed outcome: exact signed gold/scraps, the zero
## change wording, or an honest unavailable placeholder. A wallet offering also
## repeats its own authoritative projected balance or exact shortfall.
## Each mounted choice also wears a small sewn number tag (1, 2, 3) and the open,
## visible panel answers the physical 1/2/3 keys by handing that authored-order
## choice to the same guarded pressed callback the mouse and focus path use. A
## two-choice offering simply has no third tag and ignores key 3.
## The tags and the wallet-aware balance caption are sewn in the Theme's
## PatchHeading display face; the story, ticket actions, impacts and precise
## gold/scraps forecasts keep the inherited Patrick Hand body face and wording.
## The committed crossroads scene sits behind the parchment as one inert picture
## layer: it is resolved only when that shipped image really exists, and otherwise
## the panel keeps its opaque slate with a fully working parchment and choices.

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
## The committed Event scene reused behind the parchment. It is never an
## unconditional scene dependency: the picture layer stays hidden when this file
## does not resolve, and the opaque SlateBackdrop underneath still shows.
const EVENT_BACKDROP_ART := "res://assets/paper/backgrounds/event_crossroads.png"
const EVENT_PANEL_ART := "res://assets/paper/ui/reward_panel.png"
## Sewn number tag geometry on a choice ticket: a small felt square pinned to
## the left edge, clear of the centred authored text and the wallet forecast.
const CUE_INSET := 9.0
const CUE_SIZE := 26.0
## Sewn tag palette: pale paper felt, stitched thread border, dark ink numeral.
const CUE_PAPER := Color("#f3e7cc")
const CUE_THREAD := Color("#8a6f55")
const CUE_INK := Color("#3a2c22")
## The master Theme's sewn display face. The authored Event title already wears it;
## the numbered choice tags and the wallet caption are stitched in the same face
## so they belong to the open parchment. Body labels (story, ticket actions,
## impacts and forecasts) stay in the inherited Patrick Hand face.
const DISPLAY_VARIATION := "PatchHeading"
## The open parchment reads as one coherent column, centred inside the sewn sheet:
## the story, any payer selector / forecast caption and the authored tickets share
## this bounded measure instead of hugging the parchment's left edge. The bound
## keeps long paragraphs and wide 1280x720 paper at a readable line length, and it
## is a maximum only: a narrower viewport just uses all of its width.
const MAX_COLUMN_WIDTH := 680.0

signal choice_committed(event_id: String, choice_id: String)
## Emits exactly one detached RunEventChoice receipt on a successful wallet
## selection: {ok: true, event_id: String, choice_id: String,
## wallet: {gold: int, scraps: int}}. This is NOT a live run commit.
signal wallet_choice_committed(result: Dictionary)
## Emits exactly one detached RunEventChoice receipt on a successful opt-in
## vitality selection: {ok: true, event_id: String, choice_id: String,
## state: {gold: int, scraps: int, hero: {id: String, hp: int, max_hp: int}}}.
## The caller owns that hero and settles it; this is NOT a live run commit.
signal vital_choice_committed(result: Dictionary)

@onready var paper_panel: PanelContainer = $PaperPanel
@onready var content_margin: MarginContainer = $PaperPanel/ContentMargin
@onready var backdrop_art: TextureRect = $EventBackdrop
@onready var scroll_stack: VBoxContainer = $PaperPanel/ContentMargin/ScrollStack
@onready var story_scroll: ScrollContainer = $PaperPanel/ContentMargin/ScrollStack/StoryScroll
@onready var column_margin: MarginContainer = $PaperPanel/ContentMargin/ScrollStack/StoryScroll/ColumnMargin
@onready var event_content: VBoxContainer = $PaperPanel/ContentMargin/ScrollStack/StoryScroll/ColumnMargin/EventContent
@onready var scroll_hint: Label = $PaperPanel/ContentMargin/ScrollStack/ScrollHint
@onready var title_label: Label = $PaperPanel/ContentMargin/ScrollStack/StoryScroll/ColumnMargin/EventContent/EventTitle
@onready var description_label: Label = $PaperPanel/ContentMargin/ScrollStack/StoryScroll/ColumnMargin/EventContent/EventDescription
@onready var choices_container: VBoxContainer = $PaperPanel/ContentMargin/ScrollStack/StoryScroll/ColumnMargin/EventContent/Choices
@onready var top_stitches: Label = $PaperPanel/ContentMargin/ScrollStack/StoryScroll/ColumnMargin/EventContent/TopStitches
@onready var bottom_stitches: Label = $PaperPanel/ContentMargin/ScrollStack/StoryScroll/ColumnMargin/EventContent/BottomStitches

var _selector: RunEventChoice = null
var needle_payer: OptionButton
var auction_payer: OptionButton


## Presentation only: the route owner authenticates and applies the Parcel.
func open_frayed_debt_parcel(outcome: RunFrayedDebtParcel) -> bool:
	if outcome == null or not outcome.is_valid() or outcome.is_consumed():
		return false
	var record := RunFrayedDebtParcel.load_authored_event()
	var offers := outcome.get_offers()
	if offers.size() != 2:
		return false
	for index in range(2):
		var card: Dictionary = offers[index]
		record.choices[index] = {"id": card.id, "text": "Take %s (%s, uncommon) + one removable Frayed Debt\n%s" % [card.display_name, card.owner, CardShortRules.line(card)]}
	if not open_event(record):
		return false
	for index in range(3):
		_choice_buttons[index].tooltip_text = record.choices[index].text
	return true


func open_fate_pin_auction(outcome: RunFatePinAuction) -> bool:
	if outcome == null or not outcome.is_valid() or not open_event(outcome.get_event()):
		return false
	var record := outcome.get_event()
	var offers := outcome.get_offers()
	for index in range(2):
		var caption := "%s (%s, %s): -%d HP, -%d gold; sew on payer" % [
			String(offers[index].id).capitalize(), offers[index].slot, record.rarity, record.hp_cost, record.gold_cost]
		_choice_buttons[index].text = caption
		_choice_buttons[index].tooltip_text = caption + "\nReplacement destroys the old patch for +1 scrap."
	_choice_buttons[2].text = "Leave safely (+%d scrap)" % record.exit_scraps
	_choice_buttons[2].tooltip_text = _choice_buttons[2].text
	auction_payer = OptionButton.new()
	auction_payer.name = "AuctionPayer"
	auction_payer.custom_minimum_size.y = 44
	auction_payer.add_theme_font_size_override("font_size", 21)
	for hero in outcome.get_source().heroes:
		if outcome.eligible_payers().has(hero.id):
			auction_payer.add_item("%s: %d HP" % [String(hero.id).capitalize(), hero.hp])
			auction_payer.set_item_metadata(auction_payer.item_count - 1, hero.id)
	choices_container.get_parent().add_child(auction_payer)
	choices_container.get_parent().move_child(auction_payer, choices_container.get_index())
	auction_payer.disabled = auction_payer.item_count == 0
	var controls: Array[Control] = []
	if not auction_payer.disabled:
		controls.append(auction_payer)
	for index in range(3):
		_choice_buttons[index].disabled = index < 2 and (auction_payer.disabled or outcome.get_source().gold < record.gold_cost)
		if not _choice_buttons[index].disabled:
			controls.append(_choice_buttons[index])
	for index in range(controls.size()):
		controls[index].focus_next = controls[index].get_path_to(controls[(index + 1) % controls.size()])
		controls[index].focus_previous = controls[index].get_path_to(controls[(index - 1 + controls.size()) % controls.size()])
	controls[0].grab_focus()
	return true


## Render detached rules state; only the app may publish a transaction.
func open_needle_toll(outcome: RunNeedleToll) -> bool:
	if _is_open or outcome == null or not outcome.is_valid():
		return false
	var record := outcome.get_event()
	var captions: Array[String] = []
	var card_tooltips: Array[String] = []
	if outcome.is_paid():
		record.choices = []
		for id in outcome.get_offered_ids():
			var card := RunPoolCardRewardOffers.resolve_reward_definition(id)
			var caption := "Claim %s (%s, rare)" % [card.get("display_name", id), card.get("owner", "")]
			caption += "\nCost %d energy · %s" % [card.cost, CardShortRules.line(card)]
			card_tooltips.append(caption + "\n" + _needle_position_legend(card))
			record.choices.append({"id": id, "text": caption})
			captions.append(caption)
		record.choices.append({"id": "skip", "text": "Skip - take no card"})
		captions.append("Skip - take no card")
	else:
		captions.assign(["Pay toll with selected hero: -6 HP; choose a rare card", record.choices[1].text])
	if not open_event(record):
		return false
	for index in range(_choice_buttons.size()):
		_choice_buttons[index].text = captions[index]
		_choice_buttons[index].tooltip_text = captions[index]
		if index < card_tooltips.size():
			_choice_buttons[index].tooltip_text = card_tooltips[index]
			_choice_buttons[index].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_choice_buttons[index].custom_minimum_size.y = 96
			_choice_buttons[index].add_theme_font_size_override("font_size", 20)
	if outcome.is_open():
		needle_payer = OptionButton.new()
		needle_payer.name = "NeedlePayer"
		needle_payer.custom_minimum_size.y = 44
		needle_payer.add_theme_font_size_override("font_size", 21)
		for id in outcome.get_eligible_hero_ids():
			for hero in outcome.get_snapshot().heroes:
				if hero.id == id:
					needle_payer.add_item("%s: %d HP" % [id.capitalize(), hero.hp])
					needle_payer.set_item_metadata(needle_payer.item_count - 1, id)
		choices_container.get_parent().add_child(needle_payer)
		choices_container.get_parent().move_child(needle_payer, choices_container.get_index())
		needle_payer.disabled = needle_payer.item_count == 0
		_choice_buttons[0].disabled = needle_payer.disabled
	var controls: Array[Control] = []
	if is_instance_valid(needle_payer) and not needle_payer.disabled:
		controls.append(needle_payer)
	for button in _choice_buttons:
		if not button.disabled:
			controls.append(button)
	for index in range(controls.size()):
		controls[index].focus_next = controls[index].get_path_to(controls[(index + 1) % controls.size()])
		controls[index].focus_previous = controls[index].get_path_to(controls[(index - 1 + controls.size()) % controls.size()])
	controls[0].grab_focus()
	return true


## Detached authored positions only; empty target slots never mean all targets.
func _needle_position_legend(card: Dictionary) -> String:
	var source: Array[String] = []
	for position in card.from_positions:
		source.append(str(position))
	var targets: Array[String] = []
	for position in card.to_positions:
		targets.append(str(position))
	var target: String
	match card.target_kind:
		"self": target = "self (the acting hero)"
		"ally_single": target = "one ally"
		"party_all": target = "every hero in the party"
		"enemy_single": target = "one enemy"
		"enemy_all": target = "every enemy"
		_: target = str(card.target_kind)
	target += "; target positions: " + (", ".join(targets) if not targets.is_empty() else "none specified")
	return "Source positions: %s\nTarget: %s" % [", ".join(source), target]


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
var _vital_mode: bool = false
var _offered_snapshot: Dictionary = {}
var _vital_previews: Dictionary = {}
var _vital_label: Label = null


func _ready() -> void:
	_apply_patchwork_style()
	bind_event_backdrop()
	paper_panel.minimum_size_changed.connect(_fit_parchment, CONNECT_DEFERRED)
	event_content.minimum_size_changed.connect(_fit_parchment, CONNECT_DEFERRED)
	resized.connect(_fit_parchment, CONNECT_DEFERRED)
	scroll_hint.add_theme_color_override("font_color", Color("#584632"))
	scroll_hint.add_theme_font_size_override("font_size", 17)
	scroll_hint.theme_type_variation = DISPLAY_VARIATION
	close_event()


## Display-only: bind one optional picture layer behind the parchment. The scene
## is shown only when the shipped image really resolves; a missing or empty path
## hides the layer so the opaque SlateBackdrop stays the ground and the parchment,
## title, story, tickets and their forecasts keep working unchanged. It reads no
## run wallet, selector or RNG and emits nothing.
func bind_event_backdrop(art_path: String = EVENT_BACKDROP_ART) -> void:
	if not is_instance_valid(backdrop_art):
		return
	var texture := _resolve_event_backdrop(art_path)
	backdrop_art.texture = texture
	backdrop_art.visible = texture != null


## The guarded optional load: an absent committed image is simply no picture.
func _resolve_event_backdrop(art_path: String) -> Texture2D:
	if art_path.is_empty() or not ResourceLoader.exists(art_path):
		return null
	return load(art_path) as Texture2D


## The parchment remains content-height for ordinary stories. A long wrapped
## story (or service picker) uses the same paper, capped 32px inside the
## viewport, with its full authored content and payer controls scrolling inside.
## The sewn hint lives below, not over, the choice tickets.
func _fit_parchment() -> void:
	if not is_node_ready():
		return
	_fit_column()
	var inner_height := event_content.get_combined_minimum_size().y
	var paper_insets := paper_panel.get_theme_stylebox("panel").get_minimum_size().y
	paper_insets += 26.0 + 24.0 # ContentMargin's authored paper insets.
	var available := maxf(128.0, size.y - 64.0)
	var needs_scroll := inner_height + paper_insets > available
	scroll_hint.visible = needs_scroll
	var hint_space := 0.0
	if needs_scroll:
		hint_space = scroll_hint.get_combined_minimum_size().y + scroll_stack.get_theme_constant("separation")
	var story_height := minf(inner_height, maxf(1.0, available - paper_insets - hint_space))
	story_scroll.custom_minimum_size.y = story_height
	var height := minf(available, paper_panel.get_combined_minimum_size().y)
	paper_panel.offset_top = -height * 0.5
	paper_panel.offset_bottom = height * 0.5
	# Scrollbars are still usable with a wheel, swipe, keyboard or focus. The
	# hint also makes the long-story affordance obvious on 1280x720.
	story_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if needs_scroll else ScrollContainer.SCROLL_MODE_DISABLED


## Centres one bounded story column inside the sewn sheet: equal horizontal paper
## margins around the EventContent stack, so the title, story, payer controls and
## tickets all share the same readable measure instead of filling only the left
## third of the parchment. The measure comes from the sheet's own live anchors and
## its real stylebox/margin insets, never from the content's minimum width: a long
## unbroken caption therefore cannot feed back into a growing column. Ordinary
## offerings keep their natural content height; this only sets two margins.
func _fit_column() -> void:
	if not is_node_ready():
		return
	var available := _parchment_inner_width()
	if available <= 0.0:
		return
	var column := minf(available, MAX_COLUMN_WIDTH)
	var pad := int(floorf(maxf(0.0, (available - column) * 0.5)))
	if column_margin.get_theme_constant("margin_left") != pad:
		column_margin.add_theme_constant_override("margin_left", pad)
	if column_margin.get_theme_constant("margin_right") != pad:
		column_margin.add_theme_constant_override("margin_right", pad)


## The parchment's real inner width: its anchored width from the scene, less the
## sewn stylebox's own content inset and the ContentMargin's authored paper insets,
## less a vertical scrollbar that is actually showing. It reads live nodes and
## theme values only, so it stays responsive and cannot be inflated by content.
func _parchment_inner_width() -> float:
	var width := size.x * (paper_panel.anchor_right - paper_panel.anchor_left) \
		+ (paper_panel.offset_right - paper_panel.offset_left)
	var style := paper_panel.get_theme_stylebox("panel")
	if style != null:
		width -= style.content_margin_left + style.content_margin_right
	if is_instance_valid(content_margin):
		width -= content_margin.get_theme_constant("margin_left") \
			+ content_margin.get_theme_constant("margin_right")
	var bar := story_scroll.get_v_scroll_bar()
	if bar != null and bar.is_visible_in_tree():
		width -= bar.size.x
	return width


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


## Opt-in vitality-aware opening for one caller-authenticated living hero.
## The snapshot must be exactly {gold, scraps, hero: {id, hp, max_hp}} with
## native nonnegative gold/scraps and 1 <= hp <= max_hp, max_hp >= 10; the
## service's preview is the only authority for affordability, deltas and
## projections. A malformed snapshot or preview fails before any button, hero
## caption or latched state exists.
func open_event_with_vitals(event_record: Dictionary, snapshot: Variant) -> bool:
	if _is_open:
		return false
	var offered := RunEventChoice.new(event_record)
	if not offered.is_valid():
		return false
	var preview: Dictionary = offered.preview_vital_choices(snapshot)
	if not preview.get("ok", false) or preview.get("event_id") != event_record.get("id"):
		return false
	var entries: Variant = preview.get("choices")
	var mounted: Dictionary = offered.get_event()
	if not entries is Array or (entries as Array).size() != (mounted["choices"] as Array).size():
		return false
	for i in range((entries as Array).size()):
		var row: Variant = (entries as Array)[i]
		if not row is Dictionary or row.get("choice_id") != mounted["choices"][i]["id"]:
			return false
		if typeof(row.get("affordable")) != TYPE_BOOL or not (row.get("state") is Dictionary):
			return false
	var clean_snapshot := _clean_vital_snapshot(snapshot)
	if clean_snapshot.is_empty():
		return false
	_mount_vital_offering(offered, clean_snapshot, entries)
	return true


## A detached exact three-key snapshot copy, rebuilt only after the service has
## strictly parsed it. Never keeps a reference into the caller's dictionary.
func _clean_vital_snapshot(snapshot: Variant) -> Dictionary:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return {}
	var dict: Dictionary = snapshot
	if dict.size() != 3 or not dict.has("gold") or not dict.has("scraps") or not dict.has("hero"):
		return {}
	var gold: Variant = dict.get("gold")
	var scraps: Variant = dict.get("scraps")
	var hero: Variant = dict.get("hero")
	if typeof(gold) != TYPE_INT or typeof(scraps) != TYPE_INT or not hero is Dictionary:
		return {}
	var actor: Dictionary = hero
	if actor.size() != 3 or not actor.has("id") or not actor.has("hp") or not actor.has("max_hp"):
		return {}
	var hero_id: Variant = actor.get("id")
	var hp: Variant = actor.get("hp")
	var max_hp: Variant = actor.get("max_hp")
	if not hero_id is String or (hero_id as String).strip_edges().is_empty():
		return {}
	if typeof(hp) != TYPE_INT or typeof(max_hp) != TYPE_INT:
		return {}
	return {
		"gold": int(gold),
		"scraps": int(scraps),
		"hero": {"id": String(hero_id), "hp": int(hp), "max_hp": int(max_hp)},
	}


## Mounts the vitality presentation: the same sewn parchment and tickets, one
## short hero heading, and all four signed service deltas plus the service
## projected after-state (or the honest required-resource note) per ticket.
func _mount_vital_offering(offered: RunEventChoice, snapshot: Dictionary, previews: Array) -> void:
	var mounted: Dictionary = offered.get_event()
	_generation += 1
	_selector = offered
	_is_open = true
	_wallet_mode = false
	_vital_mode = true
	_offered_wallet.clear()
	_wallet_previews.clear()
	_offered_snapshot = snapshot.duplicate(true)
	_vital_previews.clear()
	title_label.text = mounted["title"]
	description_label.text = mounted["description"]
	_vital_label = Label.new()
	_vital_label.name = "VitalHero"
	_vital_label.text = _vital_heading(_offered_snapshot)
	_vital_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vital_label.theme_type_variation = DISPLAY_VARIATION
	_vital_label.add_theme_color_override("font_color", Color("#343c3c"))
	_vital_label.add_theme_font_size_override("font_size", 20)
	choices_container.get_parent().add_child(_vital_label)
	choices_container.get_parent().move_child(_vital_label, choices_container.get_index())
	for i in range(mounted["choices"].size()):
		var choice: Dictionary = mounted["choices"][i]
		var choice_id: String = choice["id"]
		var forecast: Dictionary = (previews[i] as Dictionary).duplicate(true)
		_vital_previews[choice_id] = forecast
		var can_take: bool = forecast["affordable"]
		var button := Button.new()
		button.name = "Choice_%d" % _choice_buttons.size()
		button.text = choice["text"] + "\n" + _vital_delta_line(forecast) + "\n" \
			+ _vital_forecast_line(forecast, _offered_snapshot)
		button.tooltip_text = button.text
		button.custom_minimum_size = Vector2(0.0, 78.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL if can_take else Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		# Every ticket wraps inside the centred column: a long authored action can
		# never widen the parchment or be clipped at its edge.
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_choice_button(button)
		button.add_theme_font_size_override("font_size", 18)
		button.disabled = not can_take
		_add_choice_cue(button, i)
		choices_container.add_child(button)
		_choice_buttons.append(button)
		_bound_choices[button] = choice_id
		button.pressed.connect(_on_choice_pressed.bind(offered, choice_id, _generation, button))
	visible = true
	story_scroll.scroll_vertical = 0
	_fit_parchment.call_deferred()


## Short hero heading: the offered hero's ID, current/maximum HP and wallet.
func _vital_heading(snapshot: Dictionary) -> String:
	var hero: Dictionary = snapshot["hero"]
	return "%s  •  %d / %d HP   |   %d gold   /   %d scraps" % [
		String(hero["id"]).capitalize(), hero["hp"], hero["max_hp"],
		snapshot["gold"], snapshot["scraps"],
	]


## All four signed service deltas for one vitality ticket. Unknown amounts print
## the neutral dash instead of an invented number.
func _vital_delta_line(forecast: Dictionary) -> String:
	return "Gold %s   |   Scraps %s   |   HP %s   |   Max HP %s" % [
		_delta_label(forecast.get("gold_delta")),
		_delta_label(forecast.get("scraps_delta")),
		_delta_label(forecast.get("hp_delta")),
		_delta_label(forecast.get("max_hp_delta")),
	]


## The service-projected after-state for an affordable vitality choice, or the
## honest resources the snapshot still needs. Never derives affordability from
## the printed text: only the preview row's own flag and projection are used.
func _vital_forecast_line(forecast: Dictionary, snapshot: Dictionary) -> String:
	if forecast.get("affordable", false) == true:
		var after: Variant = forecast.get("state")
		if after is Dictionary:
			var state: Dictionary = after
			var hero: Variant = state.get("hero")
			if hero is Dictionary and typeof(state.get("gold")) == TYPE_INT \
				and typeof(state.get("scraps")) == TYPE_INT \
				and typeof((hero as Dictionary).get("hp")) == TYPE_INT \
				and typeof((hero as Dictionary).get("max_hp")) == TYPE_INT:
				return "After: %d gold | %d scraps | %d/%d HP" % [
					state["gold"], state["scraps"],
					(hero as Dictionary)["hp"], (hero as Dictionary)["max_hp"],
				]
		return "UNAVAILABLE"
	var needs := _vital_needs(forecast, snapshot)
	return "UNAVAILABLE" if needs.is_empty() else "   •   ".join(needs)


## Exact required resources for one unaffordable preview row, from the caller's
## snapshot and the row's own deltas: positive gold/scraps to add, and for HP the
## current/maximum needed to clear the service's 1 HP / 10 max HP floors.
func _vital_needs(forecast: Dictionary, snapshot: Dictionary) -> Array[String]:
	var needs: Array[String] = []
	var hero: Dictionary = snapshot["hero"]
	var gold_delta: Variant = forecast.get("gold_delta")
	if typeof(gold_delta) == TYPE_INT:
		var missing_gold: int = -(int(snapshot["gold"]) + int(gold_delta))
		if missing_gold > 0:
			needs.append("Need %d gold" % missing_gold)
	var scraps_delta: Variant = forecast.get("scraps_delta")
	if typeof(scraps_delta) == TYPE_INT:
		var missing_scraps: int = -(int(snapshot["scraps"]) + int(scraps_delta))
		if missing_scraps > 0:
			needs.append("Need %d scraps" % missing_scraps)
	var hp_delta: Variant = forecast.get("hp_delta")
	if typeof(hp_delta) == TYPE_INT:
		var missing_hp: int = 1 - (int(hero["hp"]) + int(hp_delta))
		if missing_hp > 0:
			needs.append("Need %d HP" % missing_hp)
	var max_hp_delta: Variant = forecast.get("max_hp_delta")
	if typeof(max_hp_delta) == TYPE_INT:
		var missing_max: int = RunEventChoice.MIN_VITAL_MAX_HP - (int(hero["max_hp"]) + int(max_hp_delta))
		if missing_max > 0:
			needs.append("Need %d max HP" % missing_max)
	return needs


func _mount_offering(offered: RunEventChoice, wallet_mode: bool, wallet: Dictionary, previews: Array) -> void:
	var snapshot: Dictionary = offered.get_event()
	# Legacy offerings parse their authored outcomes through the same service,
	# but from a neutral wallet: only the deltas are presentation truth here.
	var parsed_rows: Array = previews if wallet_mode else _legacy_previews(offered, snapshot)
	_generation += 1
	_selector = offered
	_is_open = true
	_wallet_mode = wallet_mode
	_vital_mode = false
	_offered_snapshot.clear()
	_vital_previews.clear()
	_offered_wallet = wallet.duplicate(true)
	_wallet_previews.clear()
	title_label.text = snapshot["title"]
	# The title and story keep only their natural height in both modes: the scene
	# reserves neither a title block nor a description block, so the first authored
	# ticket sits one small gap below the text instead of after a stretch spacer.
	description_label.text = snapshot["description"]
	if wallet_mode:
		# Wallet offerings add their balance caption and keep each three-line
		# ticket's own 78px minimum; the story above still takes only its text.
		_wallet_label = Label.new()
		_wallet_label.name = "WalletBalance"
		_wallet_label.text = "Wallet  •  %d gold   /   %d scraps" % [_offered_wallet["gold"], _offered_wallet["scraps"]]
		_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_wallet_label.theme_type_variation = DISPLAY_VARIATION
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
		# Every ticket wraps inside the centred column: a long authored action can
		# never widen the parchment or be clipped at its edge.
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	story_scroll.scroll_vertical = 0
	_fit_parchment.call_deferred()


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
	# The numeral is stitched in the Event's own display face rather than the
	# ticket's body copy: same tag, same place, same inert behaviour.
	cue.theme_type_variation = DISPLAY_VARIATION
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
	if is_instance_valid(auction_payer):
		auction_payer.get_parent().remove_child(auction_payer)
		auction_payer.queue_free()
	auction_payer = null
	if is_instance_valid(needle_payer):
		needle_payer.get_parent().remove_child(needle_payer)
		needle_payer.queue_free()
	needle_payer = null
	_committed_choice.clear()
	_generation += 1
	_is_open = false
	_selector = null
	_wallet_mode = false
	_vital_mode = false
	_offered_wallet.clear()
	_wallet_previews.clear()
	_offered_snapshot.clear()
	_vital_previews.clear()
	visible = false
	if is_node_ready():
		story_scroll.scroll_vertical = 0
		scroll_hint.visible = false
		story_scroll.custom_minimum_size.y = 0.0
		story_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
	if is_instance_valid(_vital_label):
		_vital_label.get_parent().remove_child(_vital_label)
		_vital_label.queue_free()
	_vital_label = null


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
	if _vital_mode:
		var forecast: Dictionary = _vital_previews.get(choice_id, {})
		if forecast.get("affordable", false) != true:
			return
		result = offered.choose_with_vitals(choice_id, _offered_snapshot.duplicate(true))
	elif _wallet_mode:
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
	if _vital_mode:
		vital_choice_committed.emit(result.duplicate(true))
	elif _wallet_mode:
		wallet_choice_committed.emit(result.duplicate(true))
	else:
		choice_committed.emit(result["event_id"], result["choice_id"])


func _apply_patchwork_style() -> void:
	bind_event_paper()
	for label in [title_label, description_label]:
		label.add_theme_color_override("font_color", Color("#2c3437"))
	# The authored Event title speaks in the master Theme's Londrina heading face;
	# the description below it stays in the inherited Patrick Hand body font.
	title_label.theme_type_variation = DISPLAY_VARIATION
	title_label.add_theme_font_size_override("font_size", 36)
	description_label.add_theme_font_size_override("font_size", 23)
	for stitch_label in [top_stitches, bottom_stitches]:
		stitch_label.add_theme_color_override("font_color", Color("#85715b"))
		stitch_label.add_theme_font_size_override("font_size", 17)


## Reuse the existing panel; explicit content insets preserve the flat panel's
## layout independently of the fabric's unstretched 36px sewn edges.
func bind_event_paper(art_path: String = EVENT_PANEL_ART) -> void:
	var fabric: Texture2D = null
	if not art_path.is_empty() and ResourceLoader.exists(art_path, "Texture2D"):
		fabric = ResourceLoader.load(art_path) as Texture2D
	paper_panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if fabric != null:
		var sewn := StyleBoxTexture.new()
		sewn.texture = fabric
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			sewn.set_texture_margin(side, 36.0)
			sewn.set_content_margin(side, 5.0)
		paper_panel.add_theme_stylebox_override("panel", sewn)
		return
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("#e5d5b5")
	paper.border_color = Color("#766351")
	paper.set_border_width_all(5)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		paper.set_content_margin(side, 5.0)
	paper.set_corner_radius_all(14)
	paper.shadow_color = Color(0.04, 0.07, 0.08, 0.75)
	paper.shadow_size = 12
	paper_panel.add_theme_stylebox_override("panel", paper)


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
