class_name LiveV3PartyPicker
extends Control
## Detached Design-v3 party request screen. The eventual run resolver owns starting
## positions, HP, decks, passives and admission; this view never constructs them.

signal party_requested(ids: Array[String])
signal cancel_requested()

const HEROES := [
	{"id": "warden", "name": "Warden", "motif": "POT HELMET  •  GIANT SHIELD", "tone": "#496b85", "thread": "#b0d4ee", "role": "Bulwark", "signature": "Guard redirects the next allied hit; Shield Toss scales with own Block; Taunt draws attacks."},
	{"id": "seamstress", "name": "Seamstress", "motif": "GIANT THREADED NEEDLE", "tone": "#73517c", "thread": "#e3b4e5", "role": "Stitch healer", "signature": "Bleed wounds; Tether shares 50% damage with a linked foe; Mend heals; Darn cleanses."},
	{"id": "tinker", "name": "Tinker", "motif": "GOGGLES  •  SCRAP PACK", "tone": "#8a673e", "thread": "#f0d28a", "role": "Scrap engineer", "signature": "Build Scrap toward Overload; Wind-up Turret deals 3 random damage at turn end for 3 turns; Jury-rig copies the last card free once."},
	{"id": "lantern_monk", "name": "Lantern Monk", "motif": "RAISED LANTERN  •  MOTHS", "tone": "#466c65", "thread": "#c7e8ac", "role": "Light keeper", "signature": "Blind makes the next enemy attack miss; lantern light heals and cleanses allies; Moth Cloud blinds all foes and Exhausts."},
	{"id": "rag_duelist", "name": "Rag Duelist", "motif": "NEEDLE RAPIER  •  RAG CAPE", "tone": "#823e62", "thread": "#f0b1c6", "role": "Counterattacker", "signature": "Riposte on hit; Lunge advances; Feint applies Exposed and draws 1; dodge avoids a blow."},
	{"id": "scarecrow", "name": "Scarecrow", "motif": "BURLAP  •  FORK  •  CROW", "tone": "#77613d", "thread": "#ebd39a", "role": "Fear harrier", "signature": "Fear brings Weak and blocks next-turn buffs; backmost Crow Peck ignores Block; Re-stuff trades 2 max HP for 10 healing."},
	{"id": "yarn_ranger", "name": "Yarn Ranger", "motif": "KNIT HOOD  •  NEEDLE BOW", "tone": "#426785", "thread": "#b3d8ee", "role": "Tangle hunter", "signature": "Tangled prevents movement and adds 2 incoming attack damage; Reel In pulls forward 1; Unspool hits Tangled foes."},
	{"id": "button_golem", "name": "Button Golem", "motif": "STACKED BUTTONS  •  FISTS", "tone": "#5c577e", "thread": "#ded0f0", "role": "Block bruiser", "signature": "Pop Button spends 5 Block to deal 9; Roll swaps position and gains Block; Sew On scales Block with popped buttons."},
]

## The legacy roster has HP/position records but no passive field; these are the
## exact Starting heroes passives in GAME_DESIGN.md (not tile signatures).
const LEGACY_PASSIVES := {
	"warden": "Start of combat: gain 6 Block.",
	"seamstress": "When she applies Bleed, apply 1 more.",
	"tinker": "Her first attack each turn deals +3.",
}
const POSITION_NAMES := ["Front", "Middle", "Back"]

const INK := Color("#171e30")
const CREAM := Color("#fff0d8")
const SOFT := Color("#d4c4ad")
const GOLD := Color("#f7d68b")
const STITCH := Color("#efcba1")

@onready var paper_panel: PanelContainer = $PaperPanel
@onready var grid: GridContainer = $PaperPanel/Margins/Body/HeroGrid
@onready var selection_count: Label = $PaperPanel/Margins/Body/Foot/SelectionCount
@onready var inspection_panel: PanelContainer = $PaperPanel/Margins/Body/InspectionPanel
@onready var inspection_heading: Label = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/InspectionHeading
@onready var inspection_detail: Label = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/InspectionDetail
@onready var inspection_facts: Label = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/InspectionFacts
@onready var inspection_starters: Label = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/InspectionStarters
@onready var seat_preview: Label = $PaperPanel/Margins/Body/Foot/Hint
@onready var continue_button: Button = $PaperPanel/Margins/Body/Foot/ContinueButton
@onready var cancel_button: Button = $PaperPanel/Margins/Body/Foot/CancelButton
@onready var inspect_deck_button: Button = $PaperPanel/Margins/Body/Foot/InspectDeckButton
@onready var inspect_cards_button: Button = $PaperPanel/Margins/Body/Foot/InspectModes/InspectCardsButton
@onready var reward_cards_button: Button = $PaperPanel/Margins/Body/Foot/InspectModes/RewardCardsButton
@onready var reward_readout: VBoxContainer = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/RewardReadout
@onready var reward_heading: Label = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/RewardReadout/RewardHeading
@onready var reward_identity: Label = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/RewardReadout/RewardIdentity
@onready var reward_target: Label = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/RewardReadout/RewardTarget
@onready var reward_scroll: ScrollContainer = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/RewardReadout/RewardScroll
@onready var reward_effects: Label = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/RewardReadout/RewardScroll/RewardEffects
@onready var reward_previous: Button = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/RewardReadout/RewardNavigation/PreviousButton
@onready var reward_next: Button = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/RewardReadout/RewardNavigation/NextButton
@onready var reward_back: Button = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/RewardReadout/RewardNavigation/BackButton
@onready var kit_readout: VBoxContainer = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/KitReadout
@onready var kit_card_heading: Label = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/KitReadout/KitCardHeading
@onready var kit_target: Label = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/KitReadout/KitTarget
@onready var kit_effects: Label = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/KitReadout/KitEffects
@onready var kit_previous: Button = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/KitReadout/KitNavigation/PreviousButton
@onready var kit_next: Button = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/KitReadout/KitNavigation/NextButton
@onready var kit_back: Button = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/KitReadout/KitNavigation/BackButton
@onready var deck_readout: VBoxContainer = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/DeckReadout
@onready var deck_rows: Array[Label] = [
	$PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/DeckReadout/DeckSeat1,
	$PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/DeckReadout/DeckSeat2,
	$PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/DeckReadout/DeckSeat3,
]

var _ids: Array[String] = []
var _tiles: Dictionary = {}
var _generation: int = 0
var _open: bool = false
var _latched: bool = false
var _hovered_id: String = ""
var _focused_id: String = ""
var _canonical_heroes: Dictionary = {}
var _seat_receipt: Dictionary = {}
var _deck_mode: bool = false
var _kit_mode: bool = false
var _kit_hero: String = ""
var _kit_index: int = 0
var _reward_mode: bool = false
var _reward_index: int = 0
var _reward_candidates: Array[Dictionary] = []


## A drawn stand-in for not-yet-delivered portraits. These five faces are
## emblematic ragdoll silhouettes, NOT combat sprites or generated PNG art.
class HeroMotif:
	extends Control
	var hero_id: String = ""
	var cloth: Color = Color("#718c94")
	var highlight: Color = Color("#f7d68b")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_set_transform(Vector2(size.x / 2.0 - 58.0, 0), 0.0,
			Vector2(116.0 / 128.0, size.y / 112.0))
		var outline := Color("#182038")
		var paper := Color("#ead8bb")
		# The jointed, plump handmade doll stays recognizable without art.
		draw_colored_polygon(PackedVector2Array([
			Vector2(37, 107), Vector2(29, 77), Vector2(41, 57),
			Vector2(86, 57), Vector2(99, 84), Vector2(90, 107)]), outline)
		draw_colored_polygon(PackedVector2Array([
			Vector2(42, 103), Vector2(37, 78), Vector2(45, 62),
			Vector2(82, 62), Vector2(91, 84), Vector2(85, 103)]), cloth)
		draw_circle(Vector2(63, 39), 29, outline)
		draw_circle(Vector2(63, 38), 24, paper)
		draw_circle(Vector2(55, 38), 4, outline)
		draw_line(Vector2(72, 36), Vector2(78, 40), outline, 3)
		draw_line(Vector2(59, 52), Vector2(66, 54), outline, 2)
		# Crossed stitches on the chest, part of each fallback puppet.
		for p in [Vector2(51, 73), Vector2(65, 83), Vector2(78, 94)]:
			draw_line(p - Vector2(3, 3), p + Vector2(3, 3), highlight, 2)
			draw_line(p + Vector2(-3, 3), p + Vector2(3, -3), highlight, 2)
		match hero_id:
			"warden":
				draw_rect(Rect2(40, 8, 46, 10), outline)
				draw_rect(Rect2(43, 10, 40, 6), cloth)
				draw_circle(Vector2(24, 75), 24, outline)
				draw_circle(Vector2(24, 75), 20, highlight)
			"seamstress":
				draw_line(Vector2(110, 0), Vector2(92, 104), outline, 7)
				draw_line(Vector2(110, 0), Vector2(92, 104), highlight, 3)
				draw_arc(Vector2(103, 14), 10, 0.0, TAU, 20, paper, 2)
			"tinker":
				draw_rect(Rect2(82, 63, 26, 36), outline)
				draw_rect(Rect2(86, 66, 17, 28), highlight)
				for x in [47, 74]:
					draw_circle(Vector2(x, 37), 11, outline)
					draw_circle(Vector2(x, 37), 8, cloth)
				draw_line(Vector2(58, 37), Vector2(63, 37), outline, 3)
			"lantern_monk":
				draw_colored_polygon(PackedVector2Array([
					Vector2(41, 18), Vector2(63, 2), Vector2(89, 19),
					Vector2(88, 49), Vector2(40, 49)]), cloth)
				draw_line(Vector2(86, 74), Vector2(105, 38), outline, 7)
				draw_line(Vector2(104, 38), Vector2(104, 15), highlight, 3)
				draw_rect(Rect2(94, 19, 22, 26), outline)
				draw_rect(Rect2(98, 23, 14, 18), GOLD)
				for p in [Vector2(89, 5), Vector2(119, 9), Vector2(121, 49)]:
					draw_circle(p, 3, highlight)
					draw_line(p + Vector2(-5, 0), p + Vector2(5, 0), paper, 1)
			"rag_duelist":
				draw_colored_polygon(PackedVector2Array([
					Vector2(40, 55), Vector2(8, 66), Vector2(22, 110),
					Vector2(41, 94)]), highlight)
				draw_line(Vector2(91, 83), Vector2(122, 14), paper, 4)
				draw_line(Vector2(85, 67), Vector2(104, 75), outline, 5)
				draw_line(Vector2(91, 82), Vector2(91, 91), highlight, 3)
			"scarecrow":
				draw_colored_polygon(PackedVector2Array([
					Vector2(30, 24), Vector2(91, 24), Vector2(81, 12),
					Vector2(39, 12)]), cloth)
				draw_line(Vector2(99, 104), Vector2(99, 9), outline, 5)
				for x in [86, 99, 112]:
					draw_line(Vector2(x, 9), Vector2(x, 36), highlight, 4)
				draw_line(Vector2(86, 35), Vector2(112, 35), highlight, 3)
				draw_circle(Vector2(112, 52), 9, outline)
				draw_colored_polygon(PackedVector2Array([
					Vector2(116, 51), Vector2(128, 56), Vector2(115, 60)]), highlight)
				draw_circle(Vector2(114, 48), 2, paper)
			"yarn_ranger":
				draw_arc(Vector2(63, 34), 30, PI, TAU, 25, highlight, 7)
				for x in [45, 55, 65, 75]:
					draw_line(Vector2(x, 12), Vector2(x + 5, 19), paper, 2)
				draw_line(Vector2(104, 7), Vector2(104, 106), highlight, 4)
				draw_arc(Vector2(102, 56), 41, -PI / 2, PI / 2, 22, outline, 4)
				draw_line(Vector2(102, 15), Vector2(102, 97), paper, 2)
				draw_circle(Vector2(21, 93), 11, highlight)
				draw_circle(Vector2(32, 101), 7, cloth)
			"button_golem":
				for p in [Vector2(63, 70), Vector2(63, 92),
						Vector2(25, 83), Vector2(106, 83)]:
					draw_circle(p, 15, outline)
					draw_circle(p, 12, highlight)
					for offset in [Vector2(-4, -3), Vector2(4, -3),
							Vector2(-4, 4), Vector2(4, 4)]:
						draw_circle(p + offset, 2, outline)
				draw_circle(Vector2(64, 23), 12, cloth)
		draw_set_transform(Vector2.ZERO)


func _ready() -> void:
	_style_screen()
	continue_button.pressed.connect(_continue_pressed)
	cancel_button.pressed.connect(_cancel_pressed)
	inspect_deck_button.pressed.connect(_inspect_deck_pressed)
	inspect_cards_button.pressed.connect(_inspect_cards_pressed)
	reward_cards_button.pressed.connect(_reward_cards_pressed)
	reward_previous.pressed.connect(_reward_step.bind(-1))
	reward_next.pressed.connect(_reward_step.bind(1))
	reward_back.pressed.connect(_reward_back_pressed)
	kit_previous.pressed.connect(_kit_step.bind(-1))
	kit_next.pressed.connect(_kit_step.bind(1))
	kit_back.pressed.connect(_kit_back_pressed)
	open_picker()


## Reuse for each opening. Old tiles are detached immediately and their
## captured generation can never activate the new opening.
func open_picker() -> void:
	if not is_node_ready():
		return
	_generation += 1
	_open = true
	_latched = false
	_ids.clear()
	_canonical_heroes = RunV3PartyAdmission._canonical_records()
	_seat_receipt = {}
	_deck_mode = false
	_kit_mode = false
	_kit_hero = ""
	_kit_index = 0
	_reward_mode = false
	_reward_index = 0
	_reward_candidates.clear()
	_hovered_id = ""
	_focused_id = ""
	for old in grid.get_children():
		grid.remove_child(old)
		old.queue_free()
	_tiles.clear()
	for definition in HEROES:
		_mount_tile(definition, _generation)
	visible = true
	_refresh()
	_update_inspection()  # Neutral until actual pointer motion or keyboard focus.



## An input-transparent comparison readout. Pointer preview takes precedence
## while over a tile; leaving it restores keyboard focus (if any).
## Every callback carries the tile generation so retired buttons are inert.
func _inspection_active(generation: int) -> bool:
	return _open and not _latched and generation == _generation


func _inspect_motion(event: InputEvent, hero_id: String, generation: int) -> void:
	if not _inspection_active(generation) or not event is InputEventMouseMotion:
		return
	_hovered_id = hero_id
	_update_inspection()


func _inspect_mouse_exit(hero_id: String, generation: int) -> void:
	if not _inspection_active(generation) or _hovered_id != hero_id:
		return
	_hovered_id = ""
	_update_inspection()


func _inspect_focus(hero_id: String, generation: int, entered: bool) -> void:
	if not _inspection_active(generation):
		return
	if entered:
		_focused_id = hero_id
	elif _focused_id == hero_id:
		_focused_id = ""
	_update_inspection()


func _update_inspection() -> void:
	# The combined readout is a projection of the current successful receipt,
	# never of separately guessed hero decks or a cached prior opening.
	if _deck_mode:
		kit_readout.hide()
		reward_readout.hide()
		var rows := _deck_receipt_rows()
		if rows.size() == 3 and _open and not _latched:
			deck_readout.show()
			for label in [inspection_heading, inspection_facts, inspection_detail, inspection_starters]:
				label.hide()
			for index in range(3):
				deck_rows[index].text = rows[index]
				deck_rows[index].tooltip_text = rows[index]
			inspect_deck_button.text = "Back"
			return
		_deck_mode = false
	deck_readout.hide()
	kit_readout.hide()
	reward_readout.hide()
	for label in [inspection_heading, inspection_facts, inspection_detail, inspection_starters]:
		label.show()
	inspect_deck_button.text = "Inspect Deck"
	var chosen: String = ""
	if _open and not _latched:
		chosen = _hovered_id if not _hovered_id.is_empty() else _focused_id
	if not chosen.is_empty() and chosen != _kit_hero:
		_kit_hero = chosen
		_kit_index = 0
		_reward_index = 0
		_reward_candidates.clear()
		if _reward_mode:
			_reward_candidates = _reward_entries(chosen)
	inspect_cards_button.disabled = not _open or _latched or _kit_hero.is_empty()
	reward_cards_button.disabled = not _open or _latched or _kit_hero.is_empty() 		or _reward_entries(_kit_hero).is_empty()
	if (_kit_mode or _reward_mode) and chosen.is_empty():
		chosen = _kit_hero
	for hero in HEROES:
		if hero["id"] == chosen:
			inspection_heading.text = "%s  •  %s  /  %s" % [
				hero["name"], hero["motif"], hero["role"]]
			inspection_detail.text = hero["signature"]
			inspection_starters.text = _starter_caption(chosen)
			inspection_facts.text = "Canonical hero details unavailable."
			if not _canonical_heroes.has(chosen):
				return
			var record: Dictionary = _canonical_heroes[chosen]
			var definition: Dictionary = record["definition"]
			var position: int = record["position"]
			var passive: String = LEGACY_PASSIVES.get(chosen, "")
			if definition.has("passive"):
				passive = definition["passive"]["text"]
			if position not in [1, 2, 3] or passive.is_empty():
				return
			inspection_facts.text = "Max HP: %d  •  Preferred: %s (%d)  •  Passive: %s" % [
				definition["max_hp"], POSITION_NAMES[position - 1], position, passive]
			if _kit_mode:
				_show_kit()
			elif _reward_mode:
				_show_reward()
			return
	inspection_heading.text = "HOVER OR FOCUS A HERO TO INSPECT"
	inspection_facts.text = "Inspect max HP, preferred position and passive."
	inspection_detail.text = "Compare sewn looks and intended roles before choosing three."
	inspection_starters.text = ""


## The kit is a projection of the authenticated four-occurrence base deck, not
## a playable card or a synthetic tooltip. Catalog lookup is deliberately
## independent of the summary caption and of any currently selected party.
func _kit_catalog(hero_id: String) -> Object:
	match hero_id:
		"warden", "seamstress", "tinker":
			return StarterCards.new()
		"lantern_monk":
			return LanternMonkStarterCards.new()
		"rag_duelist":
			return RagDuelistStarterCards.new()
		"scarecrow":
			return ScarecrowStarterCards.new()
		"yarn_ranger":
			return YarnRangerStarterCards.new()
		"button_golem":
			return ButtonGolemStarterCards.new()
	return null


func _kit_card_by_id(hero_id: String, card_id: String) -> Dictionary:
	if hero_id not in RunV3PartyAdmission.HERO_IDS or card_id.is_empty() or card_id.ends_with("_plus"):
		return {}
	var ids := RunV3PartyAdmission._starters(hero_id, null)
	if ids.size() != RunV3PartyAdmission.STARTERS_PER_HERO or not ids.has(card_id):
		return {}
	var catalog := _kit_catalog(hero_id)
	if catalog == null:
		return {}
	var card: Dictionary = catalog.get_definition(card_id)
	if card.get("id") != card_id or card.get("owner") != hero_id \
			or card.has("upgrade_of") or not card.get("cost") is int \
			or int(card["cost"]) < 0 or not card.get("display_name") is String \
			or String(card["display_name"]).is_empty() or not card.get("effects") is Dictionary \
			or not card.get("from_positions") is Array or not card.get("to_positions") is Array \
			or not card.get("target_kind") is String:
		return {}
	for field in ["from_positions", "to_positions"]:
		for slot in card[field]:
			if not slot is int or slot not in [1, 2, 3]:
				return {}
	if not card["target_kind"] in ["enemy_single", "enemy_all", "enemy_back",
			"self", "ally_single", "party_all", "none"]:
		return {}
	return card


func _kit_card(hero_id: String, occurrence: int) -> Dictionary:
	if hero_id not in RunV3PartyAdmission.HERO_IDS:
		return {}
	var ids := RunV3PartyAdmission._starters(hero_id, null)
	if ids.size() != RunV3PartyAdmission.STARTERS_PER_HERO \
			or occurrence < 0 or occurrence >= ids.size():
		return {}
	return _kit_card_by_id(hero_id, ids[occurrence])


func _kit_target_line(card: Dictionary) -> String:
	var from: Array[String] = []
	var to: Array[String] = []
	for position in card["from_positions"]:
		from.append(str(position))
	for position in card["to_positions"]:
		to.append(str(position))
	var kind: String = card["target_kind"]
	var recipient := ""
	match kind:
		"enemy_single":
			recipient = "one foe in slots " + ", ".join(to)
		"enemy_all":
			recipient = "all foes in slots " + ", ".join(to)
		"enemy_back":
			recipient = "backmost living foe (slots " + ", ".join(to) + ")"
		"ally_single":
			recipient = "one chosen ally"
		"party_all":
			recipient = "all living allies"
		"self":
			recipient = "self"
		"none":
			recipient = "no target"
	return "Play from slots %s  •  Target: %s" % [", ".join(from), recipient]


## Every printed clause is keyed to an actual field. Never use the compact
## CardShortRules line as a claim that it covers V3 movement or Block trades.
func _kit_effect_clause(key: String, value: Variant) -> String:
	if key in ["cannot_buff_next_turn", "ignore_block"] and value is bool and value:
		return ("Fear: foe cannot buff next turn" if key == "cannot_buff_next_turn"
			else "This hit ignores foe Block")
	if not value is int or value <= 0:
		return "Undescribed effect: " + key
	match key:
		"damage":
			return "Deal %d damage" % value
		"block":
			return "Grant %d Block to target" % value
		"block_self":
			return "Self gains %d Block" % value
		"heal":
			return "Heal %d HP per target" % value
		"weak", "bleed", "exposed", "unravel", "tangled":
			return "Apply %s %d" % [key.capitalize(), value]
		"blind":
			return "Apply Blind %d (next attack misses)" % value
		"draw":
			return "Draw %d card(s)" % value
		"cleanse_debuff":
			return "Cleanse %d debuff(s) per target" % value
		"move_self_forward":
			return "Advance self %d slot(s)" % value
		"riposte":
			return "Riposte %d when hit" % value
		"duration":
			return "Lasts %d turn(s)" % value
		"dodge_next_attack":
			return "Dodge next %d attack(s)" % value
		"pull_forward":
			return "Pull target forward %d slot(s)" % value
		"spend_block":
			return "Requires and spends %d self Block" % value
		"buttons_popped":
			return "On successful hit, add %d button(s) popped" % value
		"swap_with_ally":
			return "Swap position with chosen living ally"
		"block_per_button_popped":
			return "Self gains %d Block per previously popped button" % value
	return "Undescribed effect: " + key


func _kit_effect_line(card: Dictionary) -> String:
	var parts: Array[String] = []
	var effects: Dictionary = card["effects"]
	for key in effects:
		parts.append(_kit_effect_clause(str(key), effects[key]))
	if parts.is_empty():
		return "Undescribed effects."
	return ". ".join(parts) + "."


func _show_kit() -> void:
	var card := _kit_card(_kit_hero, _kit_index)
	if card.is_empty():
		_kit_mode = false
		kit_readout.hide()
		return
	inspection_detail.hide()
	inspection_starters.hide()
	kit_readout.show()
	kit_card_heading.text = "STARTER %d / 4  •  %s  •  %d EN" % [
		_kit_index + 1, card["display_name"], card["cost"]]
	kit_target.text = _kit_target_line(card)
	kit_effects.text = _kit_effect_line(card)
	kit_effects.tooltip_text = kit_effects.text
	kit_previous.disabled = _kit_index == 0
	kit_next.disabled = _kit_index == 3
	kit_back.disabled = false


func _inspect_cards_pressed() -> void:
	if not _open or _latched or _deck_mode or _kit_hero.is_empty() \
			or _kit_card(_kit_hero, 0).is_empty():
		return
	_reward_mode = false
	_kit_mode = true
	_kit_index = 0
	_update_inspection()
	if not kit_next.disabled:
		kit_next.grab_focus()


func _kit_step(delta: int) -> void:
	if not _open or _latched or not _kit_mode or _deck_mode \
			or delta not in [-1, 1] or _kit_index + delta not in range(4) \
			or _kit_card(_kit_hero, _kit_index + delta).is_empty():
		return
	_kit_index += delta
	_update_inspection()
	if delta > 0 and kit_next.disabled:
		kit_previous.grab_focus()
	elif delta < 0 and kit_previous.disabled:
		kit_next.grab_focus()


func _kit_back_pressed() -> void:
	if not _open or _latched or not _kit_mode or _deck_mode:
		return
	_kit_mode = false
	_update_inspection()
	inspect_cards_button.grab_focus()


## Read the exact published reward stock; no tier sampling or RNG is used.
## Keep candidates separate from the definition lookup so missing / forged
## definitions display Unavailable, never the previous hero's printing.
func _reward_entries(hero_id: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if hero_id not in RunV3PartyAdmission.HERO_IDS:
		return entries
	var seen := {}
	for raw: Dictionary in RunPoolCardRewardOffers.get_authored_base_candidates():
		if raw.get("owner") != hero_id:
			continue
		var card_id: Variant = raw.get("id")
		var rarity: Variant = raw.get("rarity")
		if not card_id is String or String(card_id).is_empty() \
				or String(card_id).ends_with("_plus") or seen.has(card_id) \
				or not rarity is String or rarity not in RunPoolCardRewardOffers.TIER_ORDER:
			return []
		seen[card_id] = true
		entries.append({"id": card_id, "owner": hero_id, "rarity": rarity})
	return entries


func _reward_card(hero_id: String, index: int) -> Dictionary:
	if hero_id not in RunV3PartyAdmission.HERO_IDS or index < 0 \
			or index >= _reward_candidates.size():
		return {}
	var candidate: Dictionary = _reward_candidates[index]
	if candidate.get("owner") != hero_id or not candidate.get("id") is String \
			or not candidate.get("rarity") is String:
		return {}
	var card_id: String = candidate["id"]
	if card_id.is_empty() or card_id.ends_with("_plus") \
			or RunV3PartyAdmission._starters(hero_id, null).has(card_id):
		return {}
	var card := RunPoolCardRewardOffers.resolve_reward_definition(card_id)
	if card.get("id") != card_id or card.get("owner") != hero_id \
			or card.get("rarity") != candidate["rarity"] \
			or (card.get("reward_eligible") != true and card.get("is_upgrade") != false) \
			or card.has("upgrade_of") \
			or card.get("starting_copies") != 0 \
			or not card.get("display_name") is String \
			or String(card["display_name"]).is_empty() \
			or not card.get("cost") is int or int(card["cost"]) < 0 \
			or not card.get("effects") is Dictionary \
			or not card.get("from_positions") is Array \
			or not card.get("to_positions") is Array \
			or not card.get("target_kind") is String:
		return {}
	if card["target_kind"] not in ["enemy_single", "enemy_all", "enemy_back",
			"enemy_random", "self", "ally_single", "party_all", "none"]:
		return {}
	for field in ["from_positions", "to_positions"]:
		for slot in card[field]:
			if not slot is int or slot not in [1, 2, 3]:
				return {}
	return card


func _reward_target_line(card: Dictionary) -> String:
	var from: Array[String] = []
	var to: Array[String] = []
	for slot in card["from_positions"]:
		from.append(str(slot))
	for slot in card["to_positions"]:
		to.append(str(slot))
	var positions := ", ".join(to) if not to.is_empty() else "none"
	return "From slots %s  •  Target: %s  •  To slots: %s" % [
		", ".join(from), card["target_kind"], positions]


func _reward_effect_line(card: Dictionary) -> String:
	# The raw authored values (including nested predicates) are printed
	# verbatim. CardShortRules adds only its audited short *printed* wording.
	var parts: Array[String] = []
	var description := CardShortRules.describe(card)
	var short_line: String = str(description.get("line", ""))
	if not short_line.is_empty():
		parts.append("Printed rules: " + short_line)
	parts.append("Authored effect fields (printed intent, not guaranteed live):")
	for key in card["effects"]:
		parts.append("%s: %s" % [str(key), JSON.stringify(card["effects"][key])])
	if (card["effects"] as Dictionary).is_empty() or description.get("unknown", false):
		parts.append("Other authored effect semantics: Unavailable.")
	return "\n".join(parts)


func _show_reward() -> void:
	inspection_heading.hide()
	inspection_detail.hide()
	inspection_facts.hide()
	inspection_starters.hide()
	reward_readout.show()
	var card := _reward_card(_kit_hero, _reward_index)
	if card.is_empty():
		reward_heading.text = "REWARD CARDS  •  Unavailable"
		reward_identity.text = "Authenticated card definition unavailable."
		reward_target.text = ""
		reward_effects.text = "Authored effects: Unavailable."
	else:
		reward_heading.text = "REWARD %d / %d  •  %s  •  %s  •  %d EN" % [
			_reward_index + 1, _reward_candidates.size(), card["display_name"],
			String(card["rarity"]).capitalize(), card["cost"]]
		reward_identity.text = "ID: %s  •  Owner: %s" % [card["id"], card["owner"]]
		reward_target.text = _reward_target_line(card)
		reward_effects.text = _reward_effect_line(card)
	for label in [reward_heading, reward_identity, reward_target, reward_effects]:
		label.tooltip_text = label.text
	reward_scroll.scroll_vertical = 0
	reward_previous.disabled = _reward_index == 0
	reward_next.disabled = _reward_index >= _reward_candidates.size() - 1
	reward_back.disabled = false


func _reward_cards_pressed() -> void:
	if not _open or _latched or _deck_mode or _kit_hero.is_empty():
		return
	var candidates := _reward_entries(_kit_hero)
	if candidates.is_empty():
		return
	_reward_candidates = candidates
	_reward_mode = true
	_kit_mode = false
	_reward_index = 0
	_update_inspection()
	if not reward_next.disabled:
		reward_next.grab_focus()
	else:
		reward_back.grab_focus()


func _reward_step(delta: int) -> void:
	if not _open or _latched or not _reward_mode or _deck_mode \
			or delta not in [-1, 1] \
			or _reward_index + delta < 0 or _reward_index + delta >= _reward_candidates.size():
		return
	_reward_index += delta
	_update_inspection()
	if delta > 0 and reward_next.disabled:
		reward_previous.grab_focus()
	elif delta < 0 and reward_previous.disabled:
		reward_next.grab_focus()


func _reward_back_pressed() -> void:
	if not _open or _latched or not _reward_mode or _deck_mode:
		return
	_reward_mode = false
	_reward_candidates.clear()
	_reward_index = 0
	_update_inspection()
	reward_cards_button.grab_focus()


## Inspect only the four authenticated base occurrences owned by this hero.
## This is presentation data; never construct or allocate a run or reward deck.
func _starter_caption(hero_id: String) -> String:
	if not hero_id in RunV3PartyAdmission.HERO_IDS:
		return "STARTER CARDS: Unavailable."
	var ids: Array[String] = RunV3PartyAdmission._starters(hero_id, null)
	if ids.size() != RunV3PartyAdmission.STARTERS_PER_HERO:
		return "STARTER CARDS: Unavailable."
	var order: Array[String] = []
	var copies: Dictionary = {}
	var labels: Dictionary = {}
	for id in ids:
		var card: Dictionary = RunRestStitchCards.resolve_card_definition(id)
		if card.is_empty() or card.get("id") != id or card.get("owner") != hero_id \
				or id.ends_with("_plus") or card.has("upgrade_of") \
				or typeof(card.get("display_name")) != TYPE_STRING \
				or String(card["display_name"]).is_empty() \
				or typeof(card.get("cost")) != TYPE_INT or card["cost"] < 0:
			return "STARTER CARDS: Unavailable."
		if not copies.has(id):
			order.append(id)
			copies[id] = 0
			labels[id] = "%d EN %s" % [card["cost"], card["display_name"]]
		copies[id] += 1
	var entries: Array[String] = []
	for id in order:
		entries.append(labels[id] + (" x%d" % copies[id] if copies[id] > 1 else ""))
	return "STARTER CARDS (4)  •  " + "   |   ".join(entries)


## Format only the actual receipt.deck, in its real four-occurrence seat
## groups. Full printed names stay in each row and its tooltip if trimmed.
## Invalid/incomplete receipts expose no combined preview.
func _deck_receipt_rows() -> Array[String]:
	var rows: Array[String] = []
	if not _seat_receipt.get("ok", false):
		return rows
	var ids: Variant = _seat_receipt.get("hero_ids")
	var party: Variant = _seat_receipt.get("party")
	var deck: Variant = _seat_receipt.get("deck")
	if not ids is Array or not party is Array or not deck is Array \
			or ids.size() != 3 or party.size() != 3 or deck.size() != 12:
		return []
	for seat in range(3):
		if not ids[seat] is String or not party[seat] is Dictionary \
				or party[seat].get("id") != ids[seat] \
				or not party[seat].get("name") is String:
			return []
		var hero_id: String = ids[seat]
		var order: Array[String] = []
		var counts: Dictionary = {}
		var labels: Dictionary = {}
		for offset in range(RunV3PartyAdmission.STARTERS_PER_HERO):
			var raw: Variant = deck[seat * RunV3PartyAdmission.STARTERS_PER_HERO + offset]
			if not raw is String:
				return []
			var card_id: String = raw
			var card := RunRestStitchCards.resolve_card_definition(card_id)
			if card.is_empty() or card.get("id") != card_id or card.get("owner") != hero_id \
					or card_id.ends_with("_plus") or card.has("upgrade_of") \
					or typeof(card.get("display_name")) != TYPE_STRING \
					or String(card["display_name"]).is_empty() \
					or typeof(card.get("cost")) != TYPE_INT or card["cost"] < 0:
				return []
			if not counts.has(card_id):
				order.append(card_id)
				counts[card_id] = 0
				labels[card_id] = "%d EN %s" % [card["cost"], card["display_name"]]
			counts[card_id] += 1
		var parts: Array[String] = []
		for card_id in order:
			parts.append(labels[card_id] + (" x%d" % counts[card_id] if counts[card_id] > 1 else ""))
		rows.append("%d  %s  •  %s" % [seat + 1, party[seat]["name"], "   |   ".join(parts)])
	return rows


## Generation-bound by the mounted screen's currently open/latch guards.
## This control changes text only: no selection, signal or RNG calls.
func _inspect_deck_pressed() -> void:
	if not _open or _latched:
		return
	if _deck_mode:
		_deck_mode = false
	elif not inspect_deck_button.disabled and _deck_receipt_rows().size() == 3:
		_kit_mode = false
		_reward_mode = false
		_deck_mode = true
	_update_inspection()


func selected_ids() -> Array[String]:
	return _ids.duplicate()


func _pressed_hero(hero_id: String, generation: int) -> void:
	if not _open or _latched or generation != _generation or not _tiles.has(hero_id):
		return
	if _ids.has(hero_id):
		_ids.erase(hero_id)
	elif _ids.size() < 3:
		_ids.append(hero_id)
	_refresh()


func _continue_pressed() -> void:
	if not _open or _latched or _ids.size() != 3 or not _seat_receipt.get("ok", false):
		return
	_latched = true
	_open = false
	_deck_mode = false
	_kit_mode = false
	_kit_hero = ""
	_reward_mode = false
	_reward_candidates.clear()
	_refresh()
	_update_inspection()
	party_requested.emit(_ids.duplicate())


func _cancel_pressed() -> void:
	if not _open or _latched:
		return
	_latched = true
	_open = false
	_deck_mode = false
	_kit_mode = false
	_kit_hero = ""
	_reward_mode = false
	_reward_candidates.clear()
	_refresh()
	_update_inspection()
	visible = false
	cancel_requested.emit()


func _refresh() -> void:
	selection_count.text = "Selected %d/3" % _ids.size()
	_seat_receipt = {}
	seat_preview.text = "Choose three to preview battle seats"
	if _open and not _latched and _ids.size() == 3:
		var admitted := RunV3PartyAdmission.admit(_ids)
		if admitted.get("ok", false) and admitted["party"].size() == 3:
			_seat_receipt = admitted
			var seats: Array[String] = []
			for index in range(3):
				seats.append("%d %s" % [index + 1, admitted["party"][index]["name"]])
			seat_preview.text = "Seats: " + "  |  ".join(seats)
		else:
			seat_preview.text = "Party admission unavailable"
	continue_button.disabled = not _open or _latched or not _seat_receipt.get("ok", false)
	cancel_button.disabled = not _open or _latched
	inspect_deck_button.disabled = not _open or _latched or _deck_receipt_rows().size() != 3
	inspect_cards_button.disabled = not _open or _latched or (_hovered_id.is_empty() and _focused_id.is_empty() and not _kit_mode)
	reward_cards_button.disabled = not _open or _latched or (_hovered_id.is_empty() and _focused_id.is_empty() and not _reward_mode)
	if inspect_deck_button.disabled:
		_deck_mode = false
	for definition in HEROES:
		var hero_id: String = definition["id"]
		var tile: Button = _tiles[hero_id]
		var number := _ids.find(hero_id) + 1
		tile.disabled = not _open or _latched
		tile.get_node("Inset/Stack/PickLabel").text = (
			"PICK %d OF 3  ◆  SELECTED" % number if number > 0 else "✕  STITCH TO PARTY")
		_style_tile(tile, Color(definition["tone"]), number > 0)
	_update_inspection()


func _mount_tile(definition: Dictionary, generation: int) -> void:
	var hero_id: String = definition["id"]
	var tile := Button.new()
	tile.name = "Hero_" + hero_id
	tile.custom_minimum_size = Vector2(234, 174)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile.focus_mode = Control.FOCUS_ALL
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.clip_contents = true
	tile.pressed.connect(_pressed_hero.bind(hero_id, generation))
	tile.gui_input.connect(_inspect_motion.bind(hero_id, generation))
	tile.mouse_exited.connect(_inspect_mouse_exit.bind(hero_id, generation))
	tile.focus_entered.connect(_inspect_focus.bind(hero_id, generation, true))
	tile.focus_exited.connect(_inspect_focus.bind(hero_id, generation, false))
	grid.add_child(tile)
	_tiles[hero_id] = tile

	var inset := MarginContainer.new()
	inset.name = "Inset"
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		inset.add_theme_constant_override("margin_" + side, 9)
	inset.add_theme_constant_override("margin_top", 8)
	inset.add_theme_constant_override("margin_bottom", 7)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(inset)

	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(stack)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = definition["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", CREAM)
	name_label.add_theme_font_size_override("font_size", 23)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(name_label)

	var face := Control.new()
	face.name = "Face"
	face.custom_minimum_size = Vector2(0, 88)
	face.size_flags_vertical = Control.SIZE_EXPAND_FILL
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(face)

	var path := "res://assets/paper/heroes/%s.png" % hero_id
	var portrait: Texture2D = null
	if ResourceLoader.exists(path, "Texture2D"):
		portrait = ResourceLoader.load(path, "Texture2D") as Texture2D
	if portrait != null:
		var picture := TextureRect.new()
		picture.name = "Portrait"
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.texture = portrait
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(picture)
	else:
		var drawing := HeroMotif.new()
		drawing.name = "FallbackMotif"
		drawing.hero_id = hero_id
		drawing.cloth = Color(definition["tone"])
		drawing.highlight = Color(definition["thread"])
		drawing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.add_child(drawing)

	var motif := Label.new()
	motif.name = "MotifLabel"
	motif.text = definition["motif"]
	motif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	motif.add_theme_font_size_override("font_size", 13)
	motif.add_theme_color_override("font_color", Color(definition["thread"]))
	motif.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(motif)

	var pick := Label.new()
	pick.name = "PickLabel"
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pick.add_theme_font_size_override("font_size", 15)
	pick.add_theme_color_override("font_color", GOLD)
	pick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(pick)


func _tile_box(tone: Color, edge: Color, wide: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = tone.darkened(0.35)
	box.border_color = edge
	box.set_border_width_all(wide)
	box.set_corner_radius_all(11)
	box.set_content_margin_all(3)
	box.shadow_color = Color("#090e18ab")
	box.shadow_size = 3
	return box


func _style_tile(tile: Button, tone: Color, picked: bool) -> void:
	var edge := GOLD if picked else SOFT
	tile.add_theme_stylebox_override("normal", _tile_box(tone, edge, 4 if picked else 2))
	tile.add_theme_stylebox_override("hover", _tile_box(tone.lightened(0.14), GOLD, 4))
	tile.add_theme_stylebox_override("pressed", _tile_box(tone.lightened(0.22), GOLD, 5))
	tile.add_theme_stylebox_override("disabled", _tile_box(tone, edge, 3))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color("#fff8dc")
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(11)
	tile.add_theme_stylebox_override("focus", focus)


func _style_screen() -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#252d40")
	frame.border_color = Color("#b89069")
	frame.set_border_width_all(5)
	frame.set_corner_radius_all(17)
	frame.shadow_color = Color("#0a0b18b0")
	frame.shadow_size = 10
	paper_panel.add_theme_stylebox_override("panel", frame)
	var title: Label = $PaperPanel/Margins/Body/Title
	title.add_theme_color_override("font_color", CREAM)
	title.add_theme_font_size_override("font_size", 34)
	var subtitle: Label = $PaperPanel/Margins/Body/SubTitle
	subtitle.add_theme_color_override("font_color", SOFT)
	subtitle.add_theme_font_size_override("font_size", 16)
	for node_path in ["PaperPanel/Margins/Body/TopStitches",
			"PaperPanel/Margins/Body/BottomStitches"]:
		var label := get_node(node_path) as Label
		label.add_theme_color_override("font_color", STITCH)
		label.add_theme_font_size_override("font_size", 15)
	var readout := StyleBoxFlat.new()
	readout.bg_color = Color("#1d2639")
	readout.border_color = STITCH
	readout.set_border_width_all(2)
	readout.set_corner_radius_all(9)
	inspection_panel.add_theme_stylebox_override("panel", readout)
	inspection_heading.add_theme_color_override("font_color", GOLD)
	inspection_heading.add_theme_font_size_override("font_size", 18)
	inspection_detail.add_theme_color_override("font_color", CREAM)
	inspection_detail.add_theme_font_size_override("font_size", 16)
	inspection_facts.add_theme_color_override("font_color", SOFT)
	inspection_facts.add_theme_font_size_override("font_size", 16)
	inspection_starters.add_theme_color_override("font_color", GOLD)
	inspection_starters.add_theme_font_size_override("font_size", 14)
	kit_card_heading.add_theme_color_override("font_color", GOLD)
	kit_card_heading.add_theme_font_size_override("font_size", 17)
	kit_target.add_theme_color_override("font_color", SOFT)
	kit_target.add_theme_font_size_override("font_size", 15)
	kit_effects.add_theme_color_override("font_color", CREAM)
	kit_effects.add_theme_font_size_override("font_size", 16)
	reward_heading.add_theme_color_override("font_color", GOLD)
	reward_heading.add_theme_font_size_override("font_size", 16)
	reward_identity.add_theme_color_override("font_color", SOFT)
	reward_identity.add_theme_font_size_override("font_size", 14)
	reward_target.add_theme_color_override("font_color", SOFT)
	reward_target.add_theme_font_size_override("font_size", 14)
	reward_effects.add_theme_color_override("font_color", CREAM)
	reward_effects.add_theme_font_size_override("font_size", 15)
	var deck_heading := deck_readout.get_node("DeckHeading") as Label
	deck_heading.add_theme_color_override("font_color", GOLD)
	deck_heading.add_theme_font_size_override("font_size", 18)
	for row in deck_rows:
		row.add_theme_color_override("font_color", CREAM)
		row.add_theme_font_size_override("font_size", 16)
	seat_preview.add_theme_color_override("font_color", GOLD)
	seat_preview.add_theme_font_size_override("font_size", 15)
	selection_count.add_theme_color_override("font_color", CREAM)
	selection_count.add_theme_font_size_override("font_size", 24)
	for button in [continue_button, cancel_button, inspect_deck_button, inspect_cards_button,
			reward_cards_button, kit_previous, kit_next, kit_back,
			reward_previous, reward_next, reward_back]:
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size", 18 if button in [inspect_deck_button,
			inspect_cards_button, reward_cards_button, kit_previous, kit_next, kit_back,
			reward_previous, reward_next, reward_back] else 22)
		button.add_theme_color_override("font_color", CREAM)
		button.add_theme_color_override("font_disabled_color", Color("#abaca8"))
		var idle := _tile_box(Color("#386e65") if button == continue_button
			else Color("#765061") if button == cancel_button else Color("#496b85"), SOFT, 3)
		var hover := _tile_box(Color("#487d73") if button == continue_button
			else Color("#906179") if button == cancel_button else Color("#587b9a"), GOLD, 4)
		button.add_theme_stylebox_override("normal", idle)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
		button.add_theme_stylebox_override("disabled", _tile_box(Color("#343a48"), Color("#727585"), 2))
