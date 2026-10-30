class_name LiveRunTerminalResultPanel
extends Control
## Standalone M03 terminal presentation. An external host owns mounting and
## title/new-run navigation; this view only requests the return action.
## Never evaluates combat or advances, settles or mutates a run.
## The settled result keeps its genuine counters and adds one portrait ticket per
## hero, so the party's HP, permanent tears and worn patch names are readable.
## The same counters also state the reached floor, but only when the settled
## latch's own generated map can prove that the last witnessed battle is exactly
## the node the route still stands on.
## An authenticated result reads down the parchment: outcome plaque, the three
## party tickets, the run ledger and the sole Return action, with the tickets and
## ledger sharing the paper's spare height so its lower space is used.

signal return_to_title_requested

## The illustrated stage textures this view may use. Both are already imported
## shipped backgrounds, so the terminal result joins the established patchwork
## identity without introducing new art: the final Boss stage for a won run and
## the sewn camp for a fallen party (also the closed/default stage). Resolution
## is exists-guarded: a missing picture hides only this layer and never the result.
const CAMP_BACKDROP := "res://assets/paper/backgrounds/reward_camp.png"
const BOSS_BACKDROP := "res://assets/paper/backgrounds/battle_boss.png"
## Conspicuous stitched perimeter: cream thread walked on the dark felt mat and
## dark thread sewn just inside the parchment's own border.
const FELT_THREAD := Color("#e6d6b5")
const PAPER_THREAD := Color("#6b5343")
const FELT_STITCH_INSET := 8.0
const PAPER_STITCH_INSET := 6.0
## Readable body/detail text at 1280x720 (VIS V2: body >= 18 px). The sewn
## ledger, the detail heading, the composite name and its ordered halves are all
## genuine text, so each stays at or above that floor.
const LEDGER_FONT_SIZE := 19
const DETAIL_HEADING_FONT_SIZE := 19
const COMPOSITE_FONT_SIZE := 18
const HALVES_FONT_SIZE := 18
## One keyboard scroll notch for the retained-card list; Godot's ScrollContainer
## only reacts to the wheel and the grabber, so this view maps the standard
## scroll keys while the list owns focus.
const DETAIL_SCROLL_STEP := 56.0
const DETAIL_PAGE_RATIO := 0.8
## Half-width of the sewn scrollbar track, so the enlarged list keeps a visible
## "more rows below" affordance instead of a zero-width bar.
const SCROLLBAR_WIDTH := 4.0
## The single fail-closed statement for a result whose authority cannot be
## proven. It is also returned by the ledger formatter, so a row that cannot be
## rendered in full never becomes a partial result.
const UNAVAILABLE := "Summary unavailable"
## Player wording for a wearer with no sewn patch, instead of empty slot
## placeholders that once read like broken diagnostics.
const NO_PATCHES := "no patches"
## The one badge a hero receives for authenticated zero HP.
const TORN_BADGE := "TORN"
const HERO_TORN_BADGE_FONT_SIZE := 19
const HERO_TORN_BADGE_BG := Color("#e4d2b5")
## The three sewn hero tickets. Each keeps a heading name and a body detail
## line at or above the 18 px floor, on the same cream felt used by the kept
## sewn-card rows, so the recap reads as part of the patchwork result.
const HERO_NAME_FONT_SIZE := 20
const HERO_DETAIL_FONT_SIZE := 18
const HERO_PORTRAITS := {
	"warden": "res://assets/paper/heroes/warden.png",
	"seamstress": "res://assets/paper/heroes/seamstress.png",
	"tinker": "res://assets/paper/heroes/tinker.png",
	"lantern_monk": "res://assets/paper/heroes/lantern_monk.png",
	"rag_duelist": "res://assets/paper/heroes/rag_duelist.png",
	"scarecrow": "res://assets/paper/heroes/scarecrow.png",
	"yarn_ranger": "res://assets/paper/heroes/yarn_ranger.png",
	"button_golem": "res://assets/paper/heroes/button_golem.png",
}
const HERO_ROW_BG := Color("#f2e5cb")
const HERO_ROW_BORDER := Color("#8d7560")
const HERO_SEAT_COLORS := [Color("#40576b"), Color("#67465d"), Color("#52604a")]
const HERO_SEAT_NAMES := ["FRONT", "MIDDLE", "BACK"]
const HERO_NAME_INK := Color("#28363c")
const HERO_DETAIL_INK := Color("#334750")
## The permanent identity of the sole Return action, re-resolved at handoff time
## so a substituted or reparented button can never receive the player's keyboard.
const RETURN_BUTTON_PATH := "PaperPanel/ContentMargin/ResultContent/ReturnButton"

@onready var backdrop_art: TextureRect = $ResultBackdropArt
@onready var felt_mat: PanelContainer = $FeltMat
@onready var paper_panel: PanelContainer = $PaperPanel
@onready var result_content: VBoxContainer = $PaperPanel/ContentMargin/ResultContent
@onready var title_label: Label = $PaperPanel/ContentMargin/ResultContent/ResultTitle
@onready var description_label: Label = $PaperPanel/ContentMargin/ResultContent/ResultDescription
@onready var summary_label: Label = $PaperPanel/ContentMargin/ResultContent/RunLedger/RunSignature
@onready var hero_recap: VBoxContainer = $PaperPanel/ContentMargin/ResultContent/HeroRecap
@onready var hero_recap_title: Label = $PaperPanel/ContentMargin/ResultContent/HeroRecap/HeroRecapTitle
@onready var hero_rows: HBoxContainer = $PaperPanel/ContentMargin/ResultContent/HeroRecap/HeroRows
@onready var run_ledger: HBoxContainer = $PaperPanel/ContentMargin/ResultContent/RunLedger
@onready var return_button: Button = $PaperPanel/ContentMargin/ResultContent/ReturnButton
@onready var top_stitches: Label = $PaperPanel/ContentMargin/ResultContent/TopStitches
@onready var bottom_stitches: Label = $PaperPanel/ContentMargin/ResultContent/BottomStitches
@onready var stitched_section: PanelContainer = $PaperPanel/ContentMargin/ResultContent/RunLedger/StitchedSection
@onready var stitched_heading: Label = $PaperPanel/ContentMargin/ResultContent/RunLedger/StitchedSection/DetailMargin/DetailContent/DetailTitle
@onready var stitched_scroll: ScrollContainer = $PaperPanel/ContentMargin/ResultContent/RunLedger/StitchedSection/DetailMargin/DetailContent/StitchedScroll
@onready var stitched_rows: VBoxContainer = $PaperPanel/ContentMargin/ResultContent/RunLedger/StitchedSection/DetailMargin/DetailContent/StitchedScroll/StitchedRows

var _generation: int = 0
var _is_open: bool = false
var _return_requested: bool = false
var _can_return: bool = false
var _presented_status: String = ""
var _button_connection: Callable


func _ready() -> void:
	_apply_patchwork_style()
	stitched_scroll.gui_input.connect(_on_stitched_scroll_input)
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
	# Only an authenticated terminal verdict chooses its stage picture, so a
	# close/reopen can never carry the other outcome's art into this result.
	apply_backdrop_art(backdrop_for_status(status))
	title_label.text = "Victory" if status == RunActBattleOutcome.VICTORY else "Defeat"
	description_label.text = ("The final boss has fallen. The run is complete."
		if status == RunActBattleOutcome.VICTORY
		else "The party has fallen. The run has ended.")
	var battles_resolved: int = (settled as Array).size()
	var signature: Dictionary = _validated_signature()
	if status == RunActBattleOutcome.DEFEAT:
		signature = _with_defeat_hp(signature, latch, state)
	_can_return = signature.get("ok") == true
	# One successful signature fills both the counters and the three hero
	# ribbons: no second read, and no row is published from a partial result.
	var hero_recaps: Array = _validated_hero_rows(signature) if _can_return else []
	# The ledger may only be shown whole: a formatter that cannot render every
	# proven row (including each hero's tears) fails closed with the same text.
	var signature_text := _format_signature(signature) if _can_return else UNAVAILABLE
	if signature_text == UNAVAILABLE or hero_recaps.size() != CombatParty.PARTY_SIZE:
		_can_return = false
	var top_ledger := "Battles resolved: %d · Gold: %d · Scraps: %d" % [
		battles_resolved,
		signature.get("gold", 0),
		signature.get("scraps", 0),
	]
	# The depth is a verified fact from the same settled latch, never a guess:
	# an unproven map relationship simply leaves the counters without a floor.
	if _can_return:
		var floor_reached := _verified_floor_reached(latch, state)
		if floor_reached > 0:
			top_ledger += " · Floor reached: %d/%d" % [floor_reached, RunMap.FLOOR_COUNT]
	summary_label.text = ("%s\n%s" % [top_ledger, signature_text]) if _can_return else ("Battles resolved: %d\n%s" % [battles_resolved, signature_text])
	_clear_details()
	_clear_hero_rows()
	if _can_return:
		_mount_hero_rows(hero_recaps)
		_populate_details(signature)
	return_button.disabled = not _can_return
	return_button.focus_mode = Control.FOCUS_ALL if _can_return else Control.FOCUS_NONE
	if _can_return:
		_button_connection = _on_return_pressed.bind(_generation, return_button)
		return_button.pressed.connect(_button_connection)
	visible = true
	_fit_result_height()
	# Only an authorized result is handed the keyboard, and only once the opened
	# view has genuinely been laid out and drawn.
	if _can_return:
		_defer_return_focus()
	return true


## Defeat never commits combat HP to carryover. Require the exact combat witness
## captured by the App's settlement boundary before overlaying display-only HP.
func _with_defeat_hp(summary: Dictionary, latch: RunActBattleOutcome, state: Dictionary) -> Dictionary:
	var app: Variant = get_parent()
	if summary.get("ok") != true or app == null or app.get_script() == null \
		or app.get_script().resource_path != "res://scripts/app.gd":
		return {}
	var witness: Array = app._terminal_combat_witness
	if witness.size() != 9 or app.act_outcome != latch or app.run_map != latch._map \
		or witness[0] != latch or witness[1] != app.run_map \
		or witness[2] != app.battle_result or witness[3] != app.party \
		or app.battle_result == null or app.party == null \
		or app.battle_result._party != app.party \
		or app.battle_result.get_outcome() != CombatBattleResult.DEFEAT \
		or not app.party.is_valid() or not app.party.is_defeated() \
		or app.battle_result._enemies == null or not app.battle_result._enemies.is_valid() \
		or app.battle_result._enemies.is_victorious() \
		or witness[4] != app.run_map.get_generation_revision() \
		or witness[5] != app.run_map.get_route() or witness[6] != app.run_map.get_floors() \
		or witness[7] != app.party.get_heroes() or witness[8] != state \
		or _verified_floor_reached(latch, state) < 1:
		return {}
	if not witness[7] is Array or witness[7].size() != CombatParty.PARTY_SIZE:
		return {}
	# Read only the copied, settled combat snapshot; position order can differ
	# from the canonical tickets. Every other field stays ledger-derived.
	var hp_by_id: Dictionary = {}
	var position := 0
	for hero in witness[7]:
		position += 1
		if not hero is Dictionary:
			return {}
		var id: Variant = hero.get("id")
		var hp: Variant = hero.get("hp")
		var cap: Variant = hero.get("max_hp")
		var block: Variant = hero.get("block")
		if not id is String or id.is_empty() or hp_by_id.has(id) \
			or not hp is int or hp != 0 or not cap is int or cap <= 0 \
			or not block is int or block < 0 or not hero.get("position") is int \
			or hero.position != position:
			return {}
		hp_by_id[id] = hp
	if hp_by_id.size() != summary.get("heroes", []).size():
		return {}
	for row in summary.get("heroes", []):
		if not hp_by_id.has(row.get("hero_id")):
			return {}
		row["hp"] = hp_by_id[row.hero_id]
	return summary


## Lay the authenticated result down the parchment: the title plaque, the three
## party tickets, the run ledger and the sole Return action read top to bottom.
## A fail-closed result keeps its compact block centred without empty tickets.
func _fit_result_height() -> void:
	if not is_node_ready():
		return
	var kept_cards: bool = stitched_section.visible
	# Empty-card verdicts centre the three seat tickets and concise ledger as
	# one compact group; retained-card runs share the page with the scroll.
	result_content.alignment = (BoxContainer.ALIGNMENT_BEGIN if kept_cards
		else BoxContainer.ALIGNMENT_CENTER)
	hero_recap.size_flags_vertical = (Control.SIZE_EXPAND_FILL if kept_cards
		else Control.SIZE_FILL)
	run_ledger.size_flags_vertical = (Control.SIZE_EXPAND_FILL if kept_cards
		else Control.SIZE_FILL)


## The achieved terminal depth in floors, proven read-only from the settled
## latch's own generated map: the last witnessed battle must be exactly the node
## the route still stands on, that node's floor must be the map's current floor,
## and the floor must exist in this act. A run victory additionally requires the
## final Boss. Anything stale, closed, pending or mismatched yields -1, so the
## view prints no depth rather than an invented N/12. Depth is never derived by
## splitting a node ID or by counting settled battles: noncombat stops make that
## count smaller than the floor the party actually reached.
func _verified_floor_reached(latch: RunActBattleOutcome, state: Dictionary) -> int:
	if latch == null:
		return -1
	var status: Variant = state.get("run_status")
	if status != RunActBattleOutcome.VICTORY and status != RunActBattleOutcome.DEFEAT:
		return -1
	if state.get("pending_node_id") != "":
		return -1
	var settled: Variant = state.get("settled_node_ids")
	if not settled is Array or (settled as Array).is_empty():
		return -1
	var last_settled: Variant = (settled as Array).back()
	if typeof(last_settled) != TYPE_STRING or last_settled.is_empty():
		return -1
	var map: RunMap = latch._map
	if map == null or not map.is_generated():
		return -1
	if map.get_current_node_id() != last_settled:
		return -1
	var floor_reached: int = map.get_current_floor()
	if floor_reached < 1 or floor_reached > RunMap.FLOOR_COUNT:
		return -1
	var node: Dictionary = map.get_node(last_settled)
	if node.is_empty() or node.get("id") != last_settled \
			or node.get("floor") != floor_reached:
		return -1
	var kind: Variant = node.get("type")
	if kind != "Fight" and kind != "Elite" and kind != "Boss":
		return -1
	if status == RunActBattleOutcome.VICTORY \
			and (kind != "Boss" or floor_reached != RunMap.FLOOR_COUNT):
		return -1
	return floor_reached


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
	_clear_hero_rows()
	stitched_scroll.release_focus()
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
	# Summarize the real bound wardrobe directly: reconstructing a legacy
	# roster would erase the chosen trio and detach the authenticated seats.
	var summary: Dictionary = RunSignatureSummary.summarize(app.run_deck,
		app.run_stitch_descriptors, app.run_next_stitch_id, wardrobe)
	if summary.get("ok") != true:
		return {}
	if typeof(app.session_gold) != TYPE_INT or app.session_gold < 0 \
			or typeof(app.run_scraps) != TYPE_INT or app.run_scraps < 0:
		return {}
	summary["gold"] = app.session_gold
	summary["scraps"] = app.run_scraps

	var heroes_by_id: Dictionary = {}
	if app.run_heroes.size() != CombatParty.PARTY_SIZE:
		return {}
	for hero_item in app.run_heroes:
		if not hero_item is Dictionary or not hero_item.has("id"):
			return {}
		var hero_id: Variant = hero_item.get("id")
		var hp: Variant = hero_item.get("hp")
		var max_hp: Variant = hero_item.get("max_hp")
		if typeof(hero_id) != TYPE_STRING or not RunV3PartyAdmission.HERO_IDS.has(hero_id) \
				or heroes_by_id.has(hero_id) or typeof(hp) != TYPE_INT or typeof(max_hp) != TYPE_INT:
			return {}
		if hp < 0 or max_hp <= 0 or hp > max_hp:
			return {}
		heroes_by_id[hero_id] = {
			"hp": hp,
			"max_hp": max_hp,
		}

	# Permanent tear seams come only from the torn ledger that belongs to this
	# exact validated carryover. It must publish these same authenticated
	# heroes, and every hero needs exactly one nonnegative integer count keyed
	# by ID (never by current position, and never inferred from max HP: a worn
	# COAT can raise the effective cap without mending a single seam).
	var torn: RunTornMending = carry.torn
	if torn == null or not torn.is_valid():
		return {}
	var torn_state: Dictionary = torn.read_state()
	if torn_state.get("ok") != true or torn_state.get("heroes") != carry_state.get("heroes"):
		return {}
	var counts: Variant = torn_state.get("tear_counts")
	if typeof(counts) != TYPE_DICTIONARY or counts.size() != heroes_by_id.size():
		return {}
	var tears_by_id: Dictionary = {}
	for hero_id in heroes_by_id:
		var count: Variant = counts.get(hero_id)
		if typeof(count) != TYPE_INT or count < 0:
			return {}
		tears_by_id[hero_id] = count

	for hero_row in summary.get("heroes", []):
		var hero_id: String = hero_row.get("hero_id", "")
		if not heroes_by_id.has(hero_id):
			return {}
		hero_row["hp"] = heroes_by_id[hero_id]["hp"]
		hero_row["max_hp"] = heroes_by_id[hero_id]["max_hp"]
		hero_row["tears"] = tears_by_id[hero_id]

	return summary


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
		# A genuine sewn row's name is a heading; its two ordered halves stay body text.
		name_label.theme_type_variation = "PatchHeading"
		name_label.add_theme_color_override("font_color", Color("#28363c"))
		name_label.add_theme_font_size_override("font_size", COMPOSITE_FONT_SIZE)
		stack.add_child(name_label)
		var halves_label := Label.new()
		halves_label.name = "Halves"
		halves_label.text = "1 · %s (%s)    →    2 · %s (%s)" % [
			first["display_name"], str(owners[0]).capitalize(),
			second["display_name"], str(owners[1]).capitalize()]
		halves_label.add_theme_color_override("font_color", Color("#334750"))
		halves_label.add_theme_font_size_override("font_size", HALVES_FONT_SIZE)
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


## Keyboard access to the kept-card list. The ScrollContainer itself only
## follows the wheel and the grabber, so the standard scroll actions move this
## read-only offset while the list owns focus. Rows, order and ledger text are
## untouched: this only reveals rows the viewport already holds.
func _on_stitched_scroll_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not _is_open:
		return
	var page: float = stitched_scroll.size.y * DETAIL_PAGE_RATIO
	var current: float = stitched_scroll.scroll_vertical
	if key.is_action_pressed(&"ui_down"):
		_scroll_details_to(current + DETAIL_SCROLL_STEP)
	elif key.is_action_pressed(&"ui_up"):
		_scroll_details_to(current - DETAIL_SCROLL_STEP)
	elif key.is_action_pressed(&"ui_page_down"):
		_scroll_details_to(current + page)
	elif key.is_action_pressed(&"ui_page_up"):
		_scroll_details_to(current - page)
	elif key.is_action_pressed(&"ui_home"):
		_scroll_details_to(0.0)
	elif key.is_action_pressed(&"ui_end"):
		_scroll_details_to(INF)
	else:
		return
	stitched_scroll.accept_event()


## Clamp the requested offset to the real content height so the last row can be
## fully reached and never over-scrolled past it.
func _scroll_details_to(offset: float) -> void:
	var bar := stitched_scroll.get_v_scroll_bar()
	var limit: float = maxf(0.0, bar.max_value - stitched_scroll.size.y)
	stitched_scroll.scroll_vertical = int(roundf(clampf(offset, 0.0, limit)))


## Consume the validated projection's genuine counters. The three hero ribbons
## are mounted separately from the same signature; a malformed hero still fails
## the whole block shut, so a partial result never reaches the player.
func _format_signature(summary: Dictionary) -> String:
	if summary.get("ok") != true:
		return UNAVAILABLE
	var lines: Array[String] = [
		"Stitched: %d made · %d in deck" % [summary.stitched_created, summary.stitched_current],
		"Patches worn: %d" % summary.worn_total,
	]
	var crafted := _crafted_cards_line(summary)
	if not crafted.is_empty():
		lines.append(crafted)
	if _validated_hero_rows(summary).size() != CombatParty.PARTY_SIZE:
		return UNAVAILABLE
	return "\n".join(lines)


## Exactly the three chosen eligible hero rows in authentic seat order, or
## none at all. Every ticket retains its own identity even after seat swaps.
func _validated_hero_rows(summary: Dictionary) -> Array:
	if summary.get("ok") != true:
		return []
	var heroes: Variant = summary.get("heroes")
	if typeof(heroes) != TYPE_ARRAY or heroes.size() != CombatParty.PARTY_SIZE:
		return []
	var rows: Array = []
	var seen: Dictionary = {}
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Variant = heroes[index]
		if typeof(hero) != TYPE_DICTIONARY:
			return []
		var hero_id: Variant = hero.get("hero_id")
		if typeof(hero_id) != TYPE_STRING or not RunV3PartyAdmission.HERO_IDS.has(hero_id) \
				or seen.has(hero_id) or hero.get("id") != hero_id:
			return []
		seen[hero_id] = true
		var parts: Dictionary = _hero_recap_parts(hero)
		if parts.is_empty():
			return []
		rows.append(parts)
	return rows


## One hero's compact recap row. Presentation only: it re-reads the already
## authenticated summary and never re-resolves a patch, a tear or a card.
func _hero_recap_line(hero: Dictionary) -> String:
	var parts := _hero_recap_parts(hero)
	if parts.is_empty():
		return ""
	return "%s %s" % [parts["name"], parts["detail"]]


## A hero ribbon's heading name and body detail, or {} when any part of that
## hero is malformed. Authentic current/maximum HP, the single TORN badge at
## zero HP, the genuine by-ID tear count and only actually worn slots.
func _hero_recap_parts(hero: Dictionary) -> Dictionary:
	var hero_id: Variant = hero.get("hero_id")
	if typeof(hero_id) != TYPE_STRING or not RunV3PartyAdmission.HERO_IDS.has(hero_id):
		return {}
	var tears: Variant = hero.get("tears")
	if typeof(tears) != TYPE_INT or tears < 0:
		return {}
	var parts: Array[String] = []
	var is_torn: bool = false
	# HP is optional only for an unauthenticated direct formatter call; any
	# malformed wider value still fails the whole ledger shut.
	if hero.has("hp") or hero.has("max_hp"):
		var hp: Variant = hero.get("hp")
		var max_hp: Variant = hero.get("max_hp")
		if typeof(hp) != TYPE_INT or typeof(max_hp) != TYPE_INT \
				or max_hp <= 0 or hp < 0 or hp > max_hp:
			return {}
		parts.append("%d/%d HP" % [hp, max_hp])
		if hp == 0:
			is_torn = true
	parts.append(_tear_label(tears))
	var slots: Variant = hero.get("slots")
	if not slots is Dictionary:
		return {}
	var slot_map: Dictionary = slots
	# Every canonical slot must be an authenticated ID string before any row is
	# published; a malformed map must not masquerade as a bare wearer.
	for slot in RunSignatureSummary.SLOTS:
		if typeof(slot_map.get(slot)) != TYPE_STRING:
			return {}
	var worn := _worn_slots_text(slot_map)
	parts.append(worn if not worn.is_empty() else NO_PATCHES)
	return {
		"hero_id": hero_id,
		"name": str(hero_id).capitalize(),
		"detail": " · ".join(parts),
		"is_torn": is_torn,
	}


## Sew one cream felt portrait ticket per authenticated hero. Identity comes
## from the validated row, never party position or an independent authority read.
## Art and labels ignore input; only Return and the optional card scroll focus.
func _mount_hero_rows(rows: Array) -> void:
	_clear_hero_rows()
	for index in range(rows.size()):
		var parts: Dictionary = rows[index]
		var row := PanelContainer.new()
		row.name = "HeroRow%d" % index
		row.custom_minimum_size = Vector2(0, 200)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var felt := StyleBoxFlat.new()
		felt.bg_color = HERO_ROW_BG
		felt.border_color = HERO_SEAT_COLORS[index]
		felt.set_border_width_all(3)
		felt.set_corner_radius_all(7)
		felt.content_margin_left = 9
		felt.content_margin_right = 9
		felt.content_margin_top = 7
		felt.content_margin_bottom = 7
		row.add_theme_stylebox_override("panel", felt)
		var inset := HBoxContainer.new()
		inset.name = "RowInset"
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inset.add_theme_constant_override("separation", 8)
		row.add_child(inset)
		var portrait := TextureRect.new()
		portrait.name = "HeroPortrait"
		# Reserve a compact illustration column, leaving enough width for real
		# HP, tear and three-slot text to wrap without clipping. A missing V3
		# portrait collapses the entire column rather than faking a character.
		portrait.custom_minimum_size = Vector2(76, 128)
		portrait.size_flags_horizontal = Control.SIZE_FILL
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		inset.add_child(portrait)
		# Unillustrated V3 heroes keep their named cream sewn ticket. The
		# absent portrait reserves no blank column or fabricated character art.
		portrait.visible = apply_hero_portrait(portrait, HERO_PORTRAITS.get(parts["hero_id"], ""))
		if parts.get("is_torn", false):
			portrait.modulate = Color(0.6, 0.6, 0.62, 1.0)
		else:
			portrait.modulate = Color.WHITE
		var line := VBoxContainer.new()
		line.name = "RowLine"
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("separation", 3)
		inset.add_child(line)
		# A sewn seat tab belongs to this ticket, not to the roster data.
		# It orients the three real chosen identities without inventing stats.
		var seat_label := Label.new()
		seat_label.name = "SeatLabel"
		seat_label.text = "%s  ·  %d" % [HERO_SEAT_NAMES[index], index + 1]
		seat_label.theme_type_variation = "PatchHeading"
		seat_label.add_theme_color_override("font_color", HERO_SEAT_COLORS[index])
		seat_label.add_theme_font_size_override("font_size", 18)
		seat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seat_label.focus_mode = Control.FOCUS_NONE
		line.add_child(seat_label)
		var name_label := Label.new()
		name_label.name = "HeroName"
		name_label.text = parts["name"]
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.theme_type_variation = "PatchHeading"
		name_label.add_theme_color_override("font_color", HERO_NAME_INK)
		name_label.add_theme_font_size_override("font_size", HERO_NAME_FONT_SIZE)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(name_label)
		if parts.get("is_torn", false):
			var badge := Label.new()
			badge.name = "TornBadge"
			badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			badge.text = TORN_BADGE
			badge.theme_type_variation = "PatchHeading"
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.focus_mode = Control.FOCUS_NONE
			badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge.add_theme_color_override("font_color", HERO_NAME_INK)
			badge.add_theme_font_size_override("font_size", HERO_TORN_BADGE_FONT_SIZE)
			var badge_style := StyleBoxFlat.new()
			badge_style.bg_color = HERO_TORN_BADGE_BG
			badge_style.border_color = HERO_ROW_BORDER
			badge_style.set_border_width_all(1)
			badge_style.set_corner_radius_all(3)
			badge_style.content_margin_left = 6
			badge_style.content_margin_right = 6
			badge_style.content_margin_top = 1
			badge_style.content_margin_bottom = 1
			badge.add_theme_stylebox_override("normal", badge_style)
			line.add_child(badge)
		var detail_label := Label.new()
		detail_label.name = "HeroDetail"
		detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail_label.text = parts["detail"]
		detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_label.add_theme_color_override("font_color", HERO_DETAIL_INK)
		detail_label.add_theme_font_size_override("font_size", HERO_DETAIL_FONT_SIZE)
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		detail_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(detail_label)
		hero_rows.add_child(row)
	hero_recap.visible = not rows.is_empty()


## Optional imported portrait; the cream felt ticket remains its fallback.
## This presentation seam also permits synthetic unavailable-art checks.
func apply_hero_portrait(portrait: TextureRect, path: String) -> bool:
	portrait.texture = guarded_texture(path)
	return portrait.texture != null


## Remove every ribbon and hide the recap block, so a closed or refused view
## can never show a stale hero, HP, tear or patch name.
func _clear_hero_rows() -> void:
	if not is_node_ready():
		return
	hero_recap.hide()
	for row in hero_rows.get_children():
		hero_rows.remove_child(row)
		row.queue_free()


## Named wear entries in HEAD/ARM/COAT order. Only genuinely worn patches are
## listed, each with the slot it occupies, so a patch is never hidden to
## shorten a line. The caller has already authenticated every slot value.
func _worn_slots_text(slot_map: Dictionary) -> String:
	var entries: Array[String] = []
	for slot in RunSignatureSummary.SLOTS:
		var patch_id: String = slot_map.get(slot)
		if patch_id.is_empty():
			continue
		entries.append("%s %s" % [slot, _patch_label(patch_id)])
	return " · ".join(entries)


## Exact seam count in player language: "1 tear", "0 tears", "2 tears".
func _tear_label(count: int) -> String:
	return "1 tear" if count == 1 else "%d tears" % count


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


## Readable patch label: underscores become spaces and each word is title-cased.
## Only genuinely worn IDs reach here, so no empty placeholder is ever produced.
func _patch_label(patch_id: String) -> String:
	var label := patch_id.replace("_", " ").strip_edges()
	if label.is_empty():
		return ""
	return label.capitalize()


func has_open_result() -> bool:
	return _is_open


## Read-only presentation state, not an authority for combat or settlement.
func get_presented_status() -> String:
	return _presented_status


## Hand the keyboard to the one authorized action only after the opened result
## has genuinely been laid out and drawn: an immediate grab_focus() can be lost
## while the freshly shown view is still being laid out. The request is tagged
## with the current generation, so a close or a newer open makes it inert
## instead of focusing, or reactivating, a stale or closed action.
func _defer_return_focus() -> void:
	_take_return_focus.bind(_generation).call_deferred()


## The deferred half of that handoff. Every guard is re-checked at execution
## time: a refused, closed, hidden, disabled, unreachable or superseded result
## is never focused, and an already-spent action is never reactivated.
func _take_return_focus(generation: int) -> void:
	if generation != _generation or not _is_open or not _can_return or _return_requested:
		return
	if not is_inside_tree() or not is_visible_in_tree():
		return
	var button := get_node_or_null(RETURN_BUTTON_PATH) as Button
	if button == null or button != return_button or not is_instance_valid(return_button):
		return
	if not return_button.is_inside_tree() or not return_button.is_visible_in_tree():
		return
	if return_button.disabled or return_button.focus_mode != Control.FOCUS_ALL:
		return
	if not return_button.has_focus():
		return_button.grab_focus()


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
	ledger.content_margin_top = 6
	ledger.content_margin_bottom = 6
	summary_label.add_theme_stylebox_override("normal", ledger)
	summary_label.add_theme_color_override("font_color", Color("#2f4147"))
	summary_label.add_theme_font_size_override("font_size", LEDGER_FONT_SIZE)
	summary_label.add_theme_constant_override("line_spacing", 1)
	# Outcome and stitched-detail headings use the master Theme's Londrina heading face;
	# the sentence, ledger and half descriptions stay in the inherited body font.
	title_label.theme_type_variation = "PatchHeading"
	stitched_heading.theme_type_variation = "PatchHeading"
	stitched_heading.add_theme_color_override("font_color", Color("#28363c"))
	stitched_heading.add_theme_font_size_override("font_size", DETAIL_HEADING_FONT_SIZE)
	# The recap block's own heading uses the same sewn heading face as the kept
	# sewn-card title, so both groups read as one patchwork ledger.
	hero_recap_title.theme_type_variation = "PatchHeading"
	hero_recap_title.add_theme_color_override("font_color", Color("#28363c"))
	hero_recap_title.add_theme_font_size_override("font_size", DETAIL_HEADING_FONT_SIZE)
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
	# A real width, so the enlarged retained-card list always shows that more
	# rows are sewn below instead of hiding them behind a zero-width bar.
	track.content_margin_left = SCROLLBAR_WIDTH
	track.content_margin_right = SCROLLBAR_WIDTH
	scrollbar.add_theme_stylebox_override("scroll", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grip := StyleBoxFlat.new()
		grip.bg_color = Color("#75614f")
		grip.set_corner_radius_all(3)
		grip.content_margin_left = SCROLLBAR_WIDTH
		grip.content_margin_right = SCROLLBAR_WIDTH
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
	return_button.theme_type_variation = "PatchHeadingButton"
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


## The already-shipped stage picture each validated terminal verdict selects:
## the Boss battlefield for a witnessed run victory, the sewn camp for a downed
## party. Presentation only; never consulted for settlement or navigation.
static func backdrop_for_status(status: String) -> String:
	return BOSS_BACKDROP if status == RunActBattleOutcome.VICTORY else CAMP_BACKDROP


## Exists-guarded texture lookup. A missing or unreadable resource returns null
## instead of a load error, so the optional illustrated layer can simply vanish.
static func guarded_texture(path: String) -> Texture2D:
	if path.strip_edges().is_empty() or not ResourceLoader.exists(path, "Texture2D"):
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
