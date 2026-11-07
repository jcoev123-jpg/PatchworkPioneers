extends Control

var run_difficulty := RunDifficulty.new()
var heirloom_unlocked := false
const PROFILE_VERSION := 1
@export var difficulty_save_path := "user://quilt_difficulty.json"
## S9d: what Wren's room remembers between nights. Only the running game's root writes it.
@export var bedroom_save_path := "user://wren_room.json"
var bedroom_record: Dictionary = {}
var _bedroom_noted_run := 0


func difficulty_state() -> Dictionary:
	return run_difficulty.get_state()


## Save/profile boundary: only idle title state can restore this two-field record.
func restore_difficulty_state(state: Variant) -> bool:
	if run_map != null or deck != null or is_instance_valid(base_screen) \
		or not is_instance_valid(title_view) or not title_view.is_visible_in_tree():
		return false
	return run_difficulty.restore_state(state)


## The public RunDifficulty contract stays exactly two fields. Only the app owns
## progression's versioned envelope, and both branches restore atomically.
func profile_state() -> Dictionary:
	return {"version": PROFILE_VERSION, "difficulty": difficulty_state(),
		"heirloom_unlocked": heirloom_unlocked}


func restore_profile_state(raw: Variant) -> bool:
	if not (raw is Dictionary):
		return false
	var difficulty: Variant = raw
	var unlocked := false
	if raw.has("version"):
		if raw.size() != 3 or typeof(raw.get("version")) not in [TYPE_INT, TYPE_FLOAT] \
				or not is_finite(float(raw["version"])) or raw["version"] != PROFILE_VERSION \
				or not raw.has("difficulty") or typeof(raw.get("heirloom_unlocked")) != TYPE_BOOL:
			return false
		difficulty = raw["difficulty"]
		unlocked = raw["heirloom_unlocked"]
	# A separate validator protects the live difficulty and progression flag
	# from partial restoration when the saved tier is malformed or unearned.
	var validator := RunDifficulty.new()
	if not validator.restore_state(difficulty) or not restore_difficulty_state(difficulty):
		return false
	heirloom_unlocked = unlocked
	return true


## Only the running game's root owns the profile file. Embedded app views
## (including previews) retain their own state without writing the profile.
func _load_difficulty_progress() -> void:
	if get_tree().current_scene != self or difficulty_save_path.is_empty() \
		or not FileAccess.file_exists(difficulty_save_path):
		return
	var file := FileAccess.open(difficulty_save_path, FileAccess.READ)
	if file != null:
		restore_profile_state(JSON.parse_string(file.get_as_text()))


func _save_difficulty_progress() -> void:
	if get_tree().current_scene != self or difficulty_save_path.is_empty():
		return
	var file := FileAccess.open(difficulty_save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(profile_state()))
## Root of the game. The hand view delegates all card movement to CombatDeck.

const TITLE := "Patchwork Pioneers"
## One stage height shared with the roster presenter, so both lineups stay the same size.
const STAGE_ROSTER := preload("res://scripts/live_enemy_roster.gd")
## The pinned Quilt village base between the title and an opening route.
const BASE_SCREEN_SCENE := "res://scenes/base_screen.tscn"


@export var run_seed: int = 42

var title_label: Label
var stitched_run_session: StitchedRunSession
var _stitched_run_base: WeakRef
var stitched_run_panel: Control
var stitched_run_battle: StitchedBattleScreen
var stitched_run_walk: StitchedWalkScreen
## S9c: Wren's New Run intro, laid over the first map page until he begins the night.
var stitched_run_intro: Control
## S8f: new runs reach each non-boss node through a Walk. Older route tests opt out.
@export var stitched_walks := true
var stitched_run_buttons: Array[Button] = []
var stitched_run_draft: Array = []
var _stitched_run_epoch := 0
const STITCHED_SAVE_PATH := "user://stitched_run.save"
## Playtest cheats (debug builds only; delete scripts/debug/ before the full game ships).
const PLAYTEST_CHEATS_PATH := "res://scripts/debug/playtest_cheats.gd"
@export var stitched_save_path: String = STITCHED_SAVE_PATH
var stitched_continue_button: Button
var start_button: Button
var base_button: Button
var stitched_fight_button: Button
var stitched_fight_view: StitchedBattleScreen
var stitched_event_panel: LiveEventChoicePanel
var stitched_event_gate: RunV3FightEventGate
var stitched_sewing_panel: Control
var stitched_sewing_visit: RunStitchedSewingSwap
var stitched_sewing_mend_visit: RunStitchedSewingMend
var stitched_sewing_upgrade_visit: RunStitchedSewingUpgrade
var stitched_preview_satchel: Array = []
var stitched_preview_scraps := 0
## Separate from S2's 78-candle standalone preview; lasts for this title session.
var stitched_roadblock_candle: Variant = 100
var _stitched_sewing_admission: Dictionary = {}
var _stitched_admitted_fight_gate: RunV3FightEventGate
var _stitched_gear_overrides: Dictionary = {}
var _stitched_hp_carry: Dictionary = {}
## Settled victory FRAY/resolve by canonical hero ID, never by seated rank.
var _stitched_fray_carry: Dictionary = {}
## Victory-only ID -> ending rank; not a draft or user-authored rank request.
var _stitched_rank_carry: Dictionary = {}
var _stitched_sewing_quote: Dictionary = {}
var _stitched_mend_quote: Dictionary = {}
var _stitched_upgrade_quote: Dictionary = {}
var _stitched_sewing_catalog: Dictionary = {}
var _stitched_battle_ticket: WeakRef
## The one-use S6 Peddler bandage service, earned by a genuine four-survivor
## Roadblock victory followed by an authenticated Sewing Circle Leave. It has
## its own preview gold, never the legacy run wallet, cards or run RNG.
var stitched_preview_gold := 0
var _stitched_bleed_carry: Dictionary = {}
var stitched_peddler_button: Button
var stitched_peddler_panel: Control
var stitched_peddler_visit: RunStitchedPeddlerBandage
var stitched_peddler_candle_visit: RunPeddlerVisit
var stitched_peddler_part_visit: RunStitchedPeddlerPart
var _stitched_peddler_quote: Dictionary = {}
var _stitched_peddler_candle_state: Dictionary = {}
var _stitched_peddler_candle_quote: Dictionary = {}
var _stitched_peddler_part_state: Dictionary = {}
var _stitched_peddler_part_quote: Dictionary = {}
var _stitched_peddler_generation := 0
var _stitched_peddler_roster: Array = []
## This separate four-hero health authority is earned by the same terminal
## Roadblock + Circle Leave and competes for ONE postvictory stop.
var stitched_postevent_button: Button
var stitched_postevent_panel: Control
var stitched_postevent_visit: RunStitchedEventConsequence
var _stitched_postevent_roster: Array = []
var _stitched_postevent_snapshot: Dictionary = {}
var _stitched_postevent_quote: Dictionary = {}
var _stitched_postevent_offered: Dictionary = {}
var _stitched_postevent_generation := 0
var stitched_campfire_button: Button
var stitched_campfire_panel: Control
var stitched_campfire_event: RunStitchedEmberglassCampfireEvent
var _stitched_campfire_event_state: Dictionary = {}
var _stitched_campfire_event_context: Dictionary = {}
var _stitched_campfire_earned: Dictionary = {}
var stitched_campfire_visit: RunCampfireVisit
var _stitched_campfire_state: Dictionary = {}
var _stitched_campfire_roster: Array = []
var _stitched_campfire_authorized_roster: Array = []
var _stitched_campfire_generation := 0
# Separate, one-exchange Campfire authority; never shares the recovery visit.
var _stitched_campfire_swap_roster: Array = []
var _stitched_campfire_swap_satchel: Array = []
var _stitched_campfire_swap_gear: Dictionary = {}
var _stitched_campfire_swap_visit: RunStitchedSewingSwap
var _stitched_campfire_swap_state: Dictionary = {}
var _stitched_postvictory_stop_available := false
var stitched_unpicker_button: Button
var stitched_unpicker_panel: Control
var stitched_unpicker_visit: RunUnpickerVisit
var stitched_unpicker_event: RunStitchedInkblackUnpickerEvent
var _stitched_unpicker_event_receipt: Dictionary = {}
var _stitched_unpicker_service_receipt: Dictionary = {}
var _stitched_unpicker_earned: Dictionary = {}
var _stitched_unpicker_state: Dictionary = {}
var _stitched_unpicker_quote: Dictionary = {}
var _stitched_unpicker_context: Dictionary = {}
var _stitched_unpicker_generation := 0
const STITCHED_UNPICKER_NODE_ID := "s6_stitched_roadblock_unpicker"
## This is a detached, authenticated party receipt, not an editable UI request.
const STITCHED_DEFAULT_PICKS := ["warden", "seamstress", "tinker", "lantern_monk"]
var _stitched_party_picks: Array = STITCHED_DEFAULT_PICKS.duplicate()
var _stitched_party_receipt: Dictionary = StitchedPartyAdmission.admit(STITCHED_DEFAULT_PICKS)
# Only an authenticated four-survivor Sewing Circle Leave makes these picks permanent.
var _stitched_party_locked := false
var _stitched_party_draft: Array = []
var _stitched_party_checkboxes: Dictionary = {}
var _stitched_party_hint: Label
var _stitched_party_confirm_button: Button
var _stitched_party_cancel_button: Button
const STITCHED_ROADBLOCK_ID := "v3_stitchline_roadblock"
const STITCHED_SEWING_NODE_ID := "s5_scissor_crab_sewing_circle"
const STITCHED_SEWING_MEND_COST := StitchedRunSession.SEWING_COST
const STITCHED_SEWING_UPGRADE_COST := StitchedRunSession.SEWING_COST
const STITCHED_ROADBLOCK_CANDLE_COST := 8
const STITCHED_PEDDLER_NODE_ID := "s6_stitched_roadblock_peddler"
const STITCHED_CAMPFIRE_NODE_ID := "s6_stitched_roadblock_campfire"
const STITCHED_EVENT_ID := "s6_stitched_lantern_bobbin_ferry"
const STITCHED_EVENT_PATH := "res://data/events/s6_stitched_lantern_bobbin_ferry.json"
const STITCHED_EVENT_CHOICES := ["pay_gold", "mend_wick", "leave"]
const STITCHED_PEDDLER_PRICE := StitchedRunSession.PEDDLER_PRICE
const STITCHED_PEDDLER_PART_ID := "warden_head_helmet_rattle"
const STITCHED_PREVIEW_WIN_GOLD := 10
## The title Roadblock's authored trophy order. Each foe is only paid when this exact
## encounter actually killed it; the ids and parts come from the canonical S5 roster.
const STITCHED_ROADBLOCK_FOES := ["scissor_crab", "fray_scavenger", "moth_scribe"]
## Authenticated four-survivor Roadblock victories unlock this normal field.
## IDs are resolved afresh from the validated S5 catalog, never preview kits.
const STITCHED_FOLLOWON_ROADBLOCK_FOES := ["ragling", "scissor_crab", "moth_scribe"]
var _stitched_roadblock_win_count := 0
const STITCHED_TITLE_WALLET := {"gold": 0, "scraps": 0}
var base_screen: BaseScreen
## True only while an uncommitted opening chooser was launched from the Base.
var _route_from_base := false
## The Quilt village's one Path setup; null until a village opens or once cleared.
var run_seamstress_path_choice: RunSeamstressPathChoice
## Detached receipt of the Path this run carries; empty until a successful Set out.
var run_seamstress_path_receipt: Dictionary = {}
## The village's independent Tinker Path setup. Its claimed instance is kept for
## the whole run, because only it can authenticate the battle's Path authority.
var run_tinker_path_choice: RunTinkerPathChoice
## Detached receipt of the Tinker Path this run carries; empty until Set out.
var run_tinker_path_receipt: Dictionary = {}
var run_warden_path_choice: RunWardenPathChoice
var run_warden_path_receipt: Dictionary = {}
## The one validated Tinker setup receipt this village visit produced, detached
## from the setup. Empty until a Tinker option is confirmed.
var _tinker_setup_receipt: Dictionary = {}
## Opening chooser: a plain Control so each first-floor patch Button keeps its own
## authored page slot; a connected route still fills it with a VBoxContainer.
var route_view: Control
var route_atlas_overlay: Control
var run_map: RunMap
var title_view: VBoxContainer
var battle_view: MarginContainer
var deck: CombatDeck
var run_rng: RandomNumberGenerator
var party: CombatParty
var enemies: CombatEnemies
var battle_result: CombatBattleResult
# Battle-local receipt bridge for CombatQuiltBonus. It only reports committed
# hand-to-discard transactions of the mounted battle and resets on a new turn.
# The actual mounted panel activated before a presenter commits a paid play.
# This is only a visual witness; CombatDeck and the quilt receipt remain authoritative.
var session_gold := 0
var run_deck: Array[String] = []
var run_scraps := 0
var run_heroes: Array = []
var rest_view: VBoxContainer
var rest_recovery: RunRestRecovery
var shop_view: Control
# Only a claimed service gate may turn an Event into an on-node service visit.
var quiet_spool_panel: LiveEventChoicePanel
var fight_reward_claimed := false
var reward_choice_panel: LiveRunCardRewardChoicePanel
# One confirmed paid-card hit may have left the authored Quilt Termite at zero
# HP. The genuine post-card observation boundary consumes this before evaluate().
var terminal_result_panel: LiveRunTerminalResultPanel


func _ready() -> void:
	_build_title()
	_load_difficulty_progress.call_deferred()
	if OS.is_debug_build() and ResourceLoader.exists(PLAYTEST_CHEATS_PATH):
		add_child(load(PLAYTEST_CHEATS_PATH).new())


func _build_title() -> void:
	var bg := ColorRect.new()
	bg.color = Color("2b3135")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	title_view = box
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 32)
	add_child(box)

	title_label = Label.new()
	title_label.text = TITLE
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_color_override("font_color", Color("ece0c8"))
	title_label.add_theme_constant_override("outline_size", 12)
	title_label.add_theme_color_override("font_outline_color", Color("1a1d20"))
	box.add_child(title_label)

	start_button = Button.new()
	start_button.text = "New Run"
	start_button.custom_minimum_size = Vector2(240, 56)
	start_button.add_theme_font_size_override("font_size", 28)
	start_button.pressed.connect(_open_stitched_run_picker)
	box.add_child(start_button)
	var resume := Button.new()
	stitched_continue_button = resume
	resume.name = "ContinueStitchedRun"
	resume.text = "Continue run"
	resume.custom_minimum_size = Vector2(240, 56)
	resume.pressed.connect(func():
		if title_view.is_visible_in_tree() and stitched_run_session == null:
			load_stitched_run(stitched_save_path))
	box.add_child(resume)
	base_button = Button.new()
	# S9d: the base is Wren's bedroom whenever its painting ships; the village name only names the fallback.
	base_button.text = "Wren's room" if StitchedBedroom.has_art() else "Quilt village"
	base_button.custom_minimum_size = Vector2(240, 56)
	base_button.tooltip_text = "Go back to Wren's bedroom" if StitchedBedroom.has_art() else "Visit the Quilt village"
	base_button.pressed.connect(_open_base)
	box.add_child(base_button)
	stitched_fight_button = Button.new()
	stitched_fight_button.name = "StitchedFightButton"
	stitched_fight_button.text = "Stitched Roadblock"
	stitched_fight_button.tooltip_text = "Face the Stitchline Roadblock before Floor 01 combat"
	stitched_fight_button.custom_minimum_size = Vector2(240, 56)
	# Retained for regression callers; production enters combat through New Run.
	stitched_fight_button.hide()
	stitched_fight_button.disabled = true
	stitched_fight_button.focus_mode = Control.FOCUS_NONE
	box.add_child(stitched_fight_button)
	# The Peddler stays hidden and unfocusable until a real Roadblock victory
	# and Sewing Circle Leave earn it; it is never part of an unwon title.
	stitched_peddler_button = Button.new()
	stitched_peddler_button.name = "StitchedPeddlerButton"
	stitched_peddler_button.text = "Stitched Peddler"
	stitched_peddler_button.tooltip_text = "Choose a bandage, candle stub or spare body part with Roadblock gold"
	stitched_peddler_button.custom_minimum_size = Vector2(240, 56)
	stitched_peddler_button.visible = false
	stitched_peddler_button.disabled = true
	stitched_peddler_button.focus_mode = Control.FOCUS_NONE
	stitched_peddler_button.pressed.connect(_open_stitched_peddler)
	box.add_child(stitched_peddler_button)
	stitched_campfire_button = Button.new()
	stitched_campfire_button.name = "StitchedCampfireButton"
	stitched_campfire_button.text = "Stitched Campfire"
	stitched_campfire_button.tooltip_text = "Visit the Emberglass Hearth after the earned Roadblock"
	stitched_campfire_button.custom_minimum_size = Vector2(240, 56)
	stitched_campfire_button.visible = false
	stitched_campfire_button.disabled = true
	stitched_campfire_button.focus_mode = Control.FOCUS_NONE
	stitched_campfire_button.pressed.connect(_open_stitched_campfire)
	box.add_child(stitched_campfire_button)
	stitched_postevent_button = Button.new()
	stitched_postevent_button.name = "StitchedEventButton"
	stitched_postevent_button.text = "Stitched Event"
	stitched_postevent_button.tooltip_text = "Visit the Lantern Bobbin Ferry after a four-survivor Roadblock"
	stitched_postevent_button.custom_minimum_size = Vector2(240, 56)
	stitched_postevent_button.visible = false
	stitched_postevent_button.disabled = true
	stitched_postevent_button.focus_mode = Control.FOCUS_NONE
	stitched_postevent_button.pressed.connect(_open_stitched_postevent)
	box.add_child(stitched_postevent_button)
	stitched_unpicker_button = Button.new()
	stitched_unpicker_button.name = "StitchedUnpickerButton"
	stitched_unpicker_button.text = "Stitched Unpicker"
	stitched_unpicker_button.tooltip_text = "Visit the Inkblack Unpicker Van"
	stitched_unpicker_button.custom_minimum_size = Vector2(240, 56)
	stitched_unpicker_button.hide()
	stitched_unpicker_button.disabled = true
	stitched_unpicker_button.focus_mode = Control.FOCUS_NONE
	stitched_unpicker_button.pressed.connect(_open_stitched_unpicker)
	box.add_child(stitched_unpicker_button)
	for button in [start_button, resume, base_button, stitched_peddler_button,
			stitched_campfire_button, stitched_postevent_button, stitched_unpicker_button]:
		_style_stitched_title_action(button)
	_wire_stitched_title_focus()
	start_button.grab_focus.call_deferred()
	box.position -= box.get_combined_minimum_size() / 2.0


## Title-only version of the run action's authored reward-button nine-slice.
## Explicit content margins keep the seven-action earned stack compact at 720px.
func _style_stitched_title_action(button: Button) -> void:
	var art := _stitched_run_texture("res://assets/paper/ui/reward_button.png")
	if art != null:
		for face in ["normal", "hover", "pressed", "disabled", "focus"]:
			var felt := StyleBoxTexture.new()
			felt.texture = art
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				felt.set_texture_margin(side, 14)
				felt.set_content_margin(side, 20 if side in [SIDE_LEFT, SIDE_RIGHT] else 6)
			felt.modulate_color = {"normal": Color("564044"), "hover": Color("775158"),
				"pressed": Color("39282f"), "disabled": Color("363239"),
				"focus": Color("ffce82")}[face]
			if face == "focus":
				# Only the bright stitched rim overlays the current button face.
				felt.draw_center = false
				for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
					felt.set_expand_margin(side, 3)
			button.add_theme_stylebox_override(face, felt)
	button.add_theme_font_size_override("font_size", 28)
	for face in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(face, Color("f5e7cb"))
	button.add_theme_color_override("font_disabled_color", Color("ae9e8e"))
	button.add_theme_color_override("font_outline_color", Color("2b191b"))
	button.add_theme_constant_override("outline_size", 2)


## Include earned fixture stops only while their authenticated actions are eligible.
func _wire_stitched_title_focus() -> void:
	var actions: Array[Button] = []
	for button in [start_button, stitched_continue_button, base_button,
			stitched_peddler_button, stitched_campfire_button,
			stitched_postevent_button, stitched_unpicker_button]:
		if is_instance_valid(button) and button.visible and not button.disabled \
				and button.focus_mode != Control.FOCUS_NONE:
			actions.append(button)
	for index in range(actions.size()):
		actions[index].focus_next = actions[index].get_path_to(actions[(index + 1) % actions.size()])
		actions[index].focus_previous = actions[index].get_path_to(
			actions[(index - 1 + actions.size()) % actions.size()])


## Recheck after deferred cleanup so focus never lands on a retired stop.
func _focus_stitched_title(preferred: Button) -> void:
	var actions := [start_button, stitched_continue_button, base_button,
		stitched_peddler_button, stitched_campfire_button,
		stitched_postevent_button, stitched_unpicker_button]
	var origin := maxi(0, actions.find(preferred))
	for offset in range(actions.size()):
		var button: Button = actions[(origin + offset) % actions.size()]
		if is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled \
				and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
			return


## S3's regression-only, card-free Stitched encounter. The preview record is only
## the title roster: the three foes themselves come from the canonical S5 enemy
## profiles, so every live Roadblock fight uses the same authored kit as the
## catalog and every enemy trophy is resolved by the same loader.
## The S6 receipt supplies ONLY canonical identity/HP/rank. The S2 preview
## supplies its existing nonidentity base stats at each seated rank. Every
## authored hero's parts are present in the combined catalog, but only the
## four admitted heroes receive worn equipment.
func _stitched_floor_config(requested_receipt: Dictionary = {}) -> Dictionary:
	var party: Dictionary = StitchedPartyAdmission.admit(_stitched_party_picks)
	if party.get("ok") != true or party != _stitched_party_receipt \
			or (not requested_receipt.is_empty() and requested_receipt != party):
		return {}
	var config := StitchedRunSession.starter_config(_stitched_party_picks)
	if config.is_empty():
		return {}
	var selected_heroes: Array = config["heroes"]
	var catalog := StitchedParts.build_catalog(config["parts"])
	var foes: Array = config["foes"]
	if _stitched_roadblock_win_count > 0:
		foes = []
		var roster := StitchedEnemyCatalog.load_catalog()
		for foe_id in STITCHED_FOLLOWON_ROADBLOCK_FOES:
			foes.append(StitchedEnemyCatalog.foe_for(roster, foe_id))
	# A trophy is carried only for the currently selected hero by canonical ID.
	# A compatible foreign trophy is legal; its owner is not the wearer.
	for hero in selected_heroes:
		var carry_value: Variant = _stitched_gear_overrides.get(str(hero["id"]), {})
		if not carry_value is Dictionary:
			return {}
		var carried: Dictionary = carry_value
		for slot in StitchedParts.SLOTS:
			if not carried.has(slot):
				continue
			if not carried[slot] is Dictionary:
				return {}
			var gear: Dictionary = carried[slot]
			var part_id := str(gear.get("id", ""))
			var part: Dictionary = catalog["by_id"].get(part_id, {})
			if part.is_empty() or str(part.get("slot", "")) != slot \
					or not gear.get("tier") is int \
					or int(gear["tier"]) < StitchedParts.MIN_TIER \
					or int(gear["tier"]) > StitchedParts.MAX_TIER \
					or not gear.get("torn") is bool \
					or StitchedParts.ability_at_tier(part, int(gear["tier"])).is_empty():
				return {}
			hero["parts"][slot] = gear.duplicate(true)
	# Project prior terminal-victory health only after the final worn parts are set.
	# Torn equipment contributes no max HP; a lawful swap may lower the cap,
	# but cannot heal a wounded survivor for free.
	for hero in selected_heroes:
		var hero_id := str(hero["id"])
		if not _stitched_hp_carry.has(hero_id):
			continue
		var carried_hp: Variant = _stitched_hp_carry[hero_id]
		if typeof(carried_hp) != TYPE_INT or int(carried_hp) < 0:
			return {}
		var worn_max: int = int(hero["max_hp"])
		for slot in StitchedParts.SLOTS:
			var gear: Dictionary = hero["parts"][slot]
			if not bool(gear["torn"]):
				var definition: Dictionary = catalog["by_id"][str(gear["id"])]
				worn_max += int(StitchedParts.stat_at_tier(definition, int(gear["tier"])).get("max_hp", 0))
		hero["hp"] = mini(int(carried_hp), worn_max)
	# Carried Bleed is a positive integer keyed by canonical hero ID only, and
	# only for heroes this party actually seats. A malformed entry fails the
	# whole admission rather than silently healing a wounded hero.
	for carried_id in _stitched_bleed_carry:
		var carried_value: Variant = _stitched_bleed_carry[carried_id]
		if not str(carried_id) in _stitched_party_picks \
				or typeof(carried_value) != TYPE_INT or int(carried_value) <= 0:
			return {}
	for hero in selected_heroes:
		var hero_id := str(hero["id"])
		if _stitched_bleed_carry.has(hero_id):
			hero["statuses"] = {"bleed": int(_stitched_bleed_carry[hero_id])}
	# A FRAY receipt is a complete pair, validated before rules setup can roll.
	for carried_id in _stitched_fray_carry:
		if typeof(carried_id) != TYPE_STRING or not carried_id in _stitched_party_picks:
			return {}
		var value: Variant = _stitched_fray_carry[carried_id]
		if not value is Dictionary or value.size() != 2 \
				or not value.has("fray") or not value.has("resolve"):
			return {}
		var fray: Variant = value["fray"]
		var mood: Variant = value["resolve"]
		if typeof(fray) != TYPE_INT or int(fray) < 0 or int(fray) >= StitchedRules.FRAY_MAX \
				or typeof(mood) != TYPE_STRING \
				or not str(mood) in (["", "steadfast"] + StitchedS1BEffects.RESOLVE_TRAITS) \
				or (str(mood) in StitchedS1BEffects.RESOLVE_TRAITS \
				and int(fray) < StitchedRules.FRAY_RECOVER) \
				or (str(mood).is_empty() and int(fray) >= StitchedRules.FRAY_RESOLVE):
			return {}
	for hero in selected_heroes:
		var id := str(hero["id"])
		if _stitched_fray_carry.has(id):
			hero["fray"] = _stitched_fray_carry[id]["fray"]
			hero["resolve"] = _stitched_fray_carry[id]["resolve"]
	# Rules assign ranks by hero-array position, not by the rank field. Apply
	# authenticated formation only AFTER equipment, wounded HP and Bleed are
	# projected by canonical ID; any foreign/partial/duplicate rank fails closed.
	if not _stitched_rank_carry.is_empty():
		if _stitched_rank_carry.size() != 4:
			return {}
		var arranged: Array = [null, null, null, null]
		for hero in selected_heroes:
			var id := str(hero["id"])
			if not _stitched_rank_carry.has(id):
				return {}
			var carried_rank: Variant = _stitched_rank_carry[id]
			if typeof(carried_rank) != TYPE_INT or int(carried_rank) < 1 \
					or int(carried_rank) > 4 or arranged[int(carried_rank) - 1] != null:
				return {}
			arranged[int(carried_rank) - 1] = hero
		for id in _stitched_rank_carry:
			if typeof(id) != TYPE_STRING or not id in _stitched_party_picks:
				return {}
		if arranged.has(null):
			return {}
		selected_heroes = arranged
		for index in range(4):
			selected_heroes[index]["rank"] = index + 1
	config["heroes"] = selected_heroes
	config["parts"] = catalog["parts"]
	config["foes"] = foes
	config["seed"] = 4982026
	config["title"] = "Floor 01 · Stitched Crossing"
	config["subtitle"] = "Four heroes against three foes · sewn parts only"
	config["mode"] = "stitched"
	return config


## The Roadblock remains the authority for Fight/toll/Leave. This optional
## control only offers a detached four-of-eight identity selection.
func _stitched_picker_live(source: WeakRef, gate: RunV3FightEventGate,
		generation: int) -> bool:
	var panel := source.get_ref() as LiveEventChoicePanel if source != null else null
	return panel != null and panel == stitched_event_panel and panel.get_parent() == self \
		and panel.is_visible_in_tree() and panel.has_open_event() \
		and panel._wallet_mode and panel._selector != null \
		and not panel._selector.is_claimed() and panel._generation == generation \
		and gate != null and gate == stitched_event_gate and gate.is_valid() \
		and not gate.is_claimed() and not is_instance_valid(stitched_fight_view)


func _stitched_picker_checkbox_ids() -> Array:
	var checked: Array = []
	for id in StitchedPartyAdmission.HERO_IDS:
		var box: CheckBox = _stitched_party_checkboxes.get(id)
		if not is_instance_valid(box):
			return []
		if box.button_pressed:
			checked.append(id)
	return checked


func _stitched_picker_sync() -> void:
	var panel := stitched_event_panel
	if not is_instance_valid(panel):
		return
	var buttons := panel.get_choice_buttons()
	if buttons.size() != 3:
		return
	if _stitched_party_locked:
		# Read-only survivors still have the original usable Fight and Leave tickets.
		buttons[0].disabled = StitchedPartyAdmission.admit(_stitched_party_picks) != _stitched_party_receipt
		buttons[0].focus_mode = Control.FOCUS_ALL if not buttons[0].disabled else Control.FOCUS_NONE
		return
	var receipt := StitchedPartyAdmission.admit(_stitched_party_draft)
	var checked := _stitched_picker_checkbox_ids()
	var matched := checked.size() == _stitched_party_draft.size()
	for id in _stitched_party_draft:
		if not id in checked:
			matched = false
	var valid: bool = matched and receipt.get("ok") == true
	var confirmed: bool = valid and _stitched_party_draft == _stitched_party_picks \
		and receipt == _stitched_party_receipt
	# Incomplete or not-yet-confirmed edits cannot claim the Fight ticket.
	buttons[0].disabled = not confirmed
	buttons[0].focus_mode = Control.FOCUS_NONE if not confirmed else Control.FOCUS_ALL
	_stitched_party_confirm_button.disabled = not valid
	_stitched_party_cancel_button.disabled = confirmed
	if valid:
		var names: Array[String] = []
		for hero in receipt["heroes"]:
			names.append("%d %s" % [hero["rank"], hero["name"]])
		_stitched_party_hint.text = "RANKS · " + "  /  ".join(names) \
			+ ("   · Confirm to use" if not confirmed else "   · Ready to Fight")
	else:
		_stitched_party_hint.text = "Choose exactly four distinct sewn heroes (%d/4)" % checked.size()


func _stitched_picker_changed(pressed: bool, id: String, source: WeakRef,
		gate: RunV3FightEventGate, generation: int) -> void:
	if _stitched_party_locked or not _stitched_picker_live(source, gate, generation) \
			or not id in StitchedPartyAdmission.HERO_IDS:
		return
	var box: CheckBox = _stitched_party_checkboxes.get(id)
	if not is_instance_valid(box) or box.button_pressed != pressed:
		return
	if pressed and not id in _stitched_party_draft:
		_stitched_party_draft.append(id)
	elif not pressed and id in _stitched_party_draft:
		_stitched_party_draft.erase(id)
	else:
		return
	_stitched_picker_sync()


func _stitched_picker_confirm(source: WeakRef, gate: RunV3FightEventGate,
		generation: int) -> void:
	if _stitched_party_locked or not _stitched_picker_live(source, gate, generation):
		return
	var receipt := StitchedPartyAdmission.admit(_stitched_party_draft)
	var checked := _stitched_picker_checkbox_ids()
	if receipt.get("ok") != true or checked.size() != 4 \
			or _stitched_party_draft.size() != 4:
		return
	for id in _stitched_party_draft:
		if not id in checked:
			return
	# An identical confirmation of the same four heroes in the same rank order
	# keeps the offer already earned; only a real change may invalidate it.
	var party_changed: bool = _stitched_party_draft != _stitched_party_picks \
		or receipt.get("heroes", []) != _stitched_party_receipt.get("heroes", [])
	# Update nothing until the complete canonical receipt has passed.
	_stitched_party_picks = _stitched_party_draft.duplicate()
	_stitched_party_receipt = receipt.duplicate(true)
	# Only currently selected hero IDs retain their previously won parts.
	for id in _stitched_gear_overrides.keys():
		if not id in _stitched_party_picks:
			_stitched_gear_overrides.erase(id)
	for id in _stitched_hp_carry.keys():
		if not id in _stitched_party_picks:
			_stitched_hp_carry.erase(id)
	for id in _stitched_bleed_carry.keys():
		if not id in _stitched_party_picks:
			_stitched_bleed_carry.erase(id)
	for id in _stitched_fray_carry.keys():
		if not id in _stitched_party_picks:
			_stitched_fray_carry.erase(id)
	# A changed party cannot inherit an earlier victory's Peddler offer; an
	# unchanged one must not lose it without a purchase or a free Leave.
	if party_changed:
		# A new confirmed selection starts from StitchedPartyAdmission order.
		_stitched_rank_carry.clear()
		_stitched_peddler_roster.clear()
		_stitched_campfire_roster.clear()
		_stitched_campfire_authorized_roster.clear()
		_stitched_campfire_swap_roster.clear()
		_stitched_campfire_swap_satchel.clear()
		_stitched_campfire_swap_gear.clear()
		_stitched_postevent_roster.clear()
		_stitched_postvictory_stop_available = false
		_refresh_stitched_peddler_button()
	_stitched_picker_sync()


func _stitched_picker_cancel(source: WeakRef, gate: RunV3FightEventGate,
		generation: int) -> void:
	if _stitched_party_locked or not _stitched_picker_live(source, gate, generation):
		return
	_stitched_party_draft = _stitched_party_picks.duplicate()
	for id in StitchedPartyAdmission.HERO_IDS:
		var box: CheckBox = _stitched_party_checkboxes.get(id)
		if is_instance_valid(box):
			box.set_pressed_no_signal(id in _stitched_party_draft)
	_stitched_picker_sync()


func _mount_stitched_party_picker(panel: LiveEventChoicePanel,
		gate: RunV3FightEventGate) -> bool:
	var party := StitchedPartyAdmission.admit(_stitched_party_picks)
	if party.get("ok") != true or party != _stitched_party_receipt \
			or panel.get_choice_buttons().size() != 3:
		return false
	_stitched_party_draft = _stitched_party_picks.duplicate()
	_stitched_party_checkboxes.clear()
	var generation: int = panel._generation
	var source: WeakRef = weakref(panel)
	var container := VBoxContainer.new()
	container.name = "StitchedPartyPicker"
	container.add_theme_constant_override("separation", 6)
	var heading := Label.new()
	heading.text = "SEW YOUR PARTY  ·  Four of Eight"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.theme_type_variation = "PatchHeading"
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(heading)
	if _stitched_party_locked:
		heading.text = "EARNED SURVIVORS  ·  Party locked"
		for hero in party["heroes"]:
			var survivor := Label.new()
			survivor.text = "%d  %s" % [hero["rank"], hero["name"]]
			survivor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			survivor.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(survivor)
		panel.event_content.add_child(container)
		panel.event_content.move_child(container, panel.choices_container.get_index())
		_stitched_picker_sync()
		return true
	var grid := GridContainer.new()
	grid.name = "StitchedHeroChoices"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	container.add_child(grid)
	for id in StitchedPartyAdmission.HERO_IDS:
		var checkbox := CheckBox.new()
		checkbox.name = "StitchedPick_" + id
		# These static captions are decorative; admission owns identity and HP.
		var label := str(id).replace("_", " ").capitalize()
		checkbox.text = label
		checkbox.tooltip_text = "Select " + label + " for a four-hero rank"
		checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		checkbox.custom_minimum_size = Vector2(120, 30)
		checkbox.focus_mode = Control.FOCUS_ALL
		checkbox.set_pressed_no_signal(id in _stitched_party_draft)
		grid.add_child(checkbox)
		_stitched_party_checkboxes[id] = checkbox
		checkbox.toggled.connect(_stitched_picker_changed.bind(id, source, gate, generation))
	_stitched_party_hint = Label.new()
	_stitched_party_hint.name = "StitchedRankPreview"
	_stitched_party_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stitched_party_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stitched_party_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_stitched_party_hint)
	var actions := HBoxContainer.new()
	actions.name = "StitchedPartyActions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	container.add_child(actions)
	_stitched_party_confirm_button = Button.new()
	_stitched_party_confirm_button.name = "StitchedPartyConfirm"
	_stitched_party_confirm_button.text = "Confirm party"
	_stitched_party_confirm_button.custom_minimum_size = Vector2(160, 38)
	_stitched_party_confirm_button.pressed.connect(
		_stitched_picker_confirm.bind(source, gate, generation))
	actions.add_child(_stitched_party_confirm_button)
	_stitched_party_cancel_button = Button.new()
	_stitched_party_cancel_button.name = "StitchedPartyCancel"
	_stitched_party_cancel_button.text = "Cancel edits"
	_stitched_party_cancel_button.custom_minimum_size = Vector2(160, 38)
	_stitched_party_cancel_button.pressed.connect(
		_stitched_picker_cancel.bind(source, gate, generation))
	actions.add_child(_stitched_party_cancel_button)
	# Insert above the three unmodified authored offer buttons, on their
	# existing scrollable parchment. No new graphic is drawn in code.
	panel.event_content.add_child(container)
	panel.event_content.move_child(container, panel.choices_container.get_index())
	_stitched_picker_sync()
	return true


func _open_stitched_fight() -> bool:
	if stitched_unpicker_visit != null or is_instance_valid(stitched_unpicker_panel):
		return false
	# Explicit regression entry admits only the authored Roadblock visit. No combat or
	# run objects exist until a separately authenticated Fight is committed.
	if is_instance_valid(stitched_fight_view) or is_instance_valid(stitched_event_panel) \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or stitched_sewing_mend_visit != null or stitched_sewing_upgrade_visit != null \
			or is_instance_valid(stitched_peddler_panel) or stitched_peddler_visit != null \
			or stitched_peddler_candle_visit != null or is_instance_valid(stitched_campfire_panel) \
			or stitched_campfire_visit != null or stitched_postevent_visit != null \
			or is_instance_valid(stitched_postevent_panel) or stitched_event_gate != null or deck != null or run_map != null or run_rng != null \
			or is_instance_valid(base_screen) or is_instance_valid(party_picker) \
			or is_instance_valid(route_view) or is_instance_valid(route_atlas_overlay) \
			or is_instance_valid(battle_view) or _route_from_base \
			or not is_instance_valid(title_view) or not title_view.is_visible_in_tree():
		return false
	var gate := RunV3FightEventGate.new(STITCHED_ROADBLOCK_ID)
	if not gate.is_valid() or gate.get_event_id() != STITCHED_ROADBLOCK_ID:
		return false
	var record: Dictionary = gate.get_event()
	var preview: Dictionary = gate.preview_choices(STITCHED_TITLE_WALLET.duplicate(true))
	if not preview.get("ok", false) or preview.get("event_id") != STITCHED_ROADBLOCK_ID \
			or preview.get("fight_choice_id") != gate.get_fight_choice_id() \
			or not preview.get("choices") is Array:
		return false
	var rows: Array = preview["choices"]
	var authored: Array = record.get("choices", [])
	if rows.size() != 3 or authored.size() != rows.size():
		return false
	var afforded: Dictionary = {}
	for index in range(rows.size()):
		if not rows[index] is Dictionary or not authored[index] is Dictionary:
			return false
		var row: Dictionary = rows[index]
		var choice_id: String = str(row.get("choice_id", ""))
		if choice_id != str(authored[index].get("id", "")) \
				or typeof(row.get("affordable")) != TYPE_BOOL:
			return false
		afforded[choice_id] = row["affordable"]
		var request: Dictionary = row.get("fight_request", {})
		if request != ({"node_type": "Fight"} if choice_id == gate.get_fight_choice_id() else {}):
			return false
	if afforded.get(gate.get_fight_choice_id()) != true \
			or afforded.get("leave") != true or afforded.get("pay_road_toll") != false:
		return false
	var panel := preload("res://scenes/event_choice_panel.tscn").instantiate() as LiveEventChoicePanel
	if panel == null:
		return false
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not panel.open_event_with_wallet(record, STITCHED_TITLE_WALLET.duplicate(true)):
		remove_child(panel)
		panel.queue_free()
		return false
	var buttons := panel.get_choice_buttons()
	if buttons.size() != rows.size():
		panel.close_event()
		remove_child(panel)
		panel.queue_free()
		return false
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var forecast := row.duplicate(true)
		forecast.erase("fight_request")
		if not is_instance_valid(buttons[index]) \
				or buttons[index].disabled == bool(row["affordable"]) \
				or panel._wallet_previews.get(str(row["choice_id"]), {}) != forecast:
			panel.close_event()
			remove_child(panel)
			panel.queue_free()
			return false
	stitched_event_gate = gate
	stitched_event_panel = panel
	if not _mount_stitched_party_picker(panel, gate):
		_retire_stitched_roadblock()
		return false
	panel.wallet_choice_committed.connect(_commit_stitched_roadblock.bind(weakref(panel), gate))
	title_view.hide()
	buttons[0].grab_focus.call_deferred()
	return true


func _commit_stitched_roadblock(receipt: Dictionary, source: WeakRef, gate: RunV3FightEventGate) -> void:
	var panel := source.get_ref() as LiveEventChoicePanel if source != null else null
	if panel == null or panel != stitched_event_panel or panel.get_parent() != self \
			or not panel.is_visible_in_tree() or not panel.has_open_event() \
			or not panel._wallet_mode or panel._offered_wallet != STITCHED_TITLE_WALLET \
			or panel._selector == null or not panel._selector.is_claimed() \
			or gate == null or gate != stitched_event_gate or not gate.is_valid() \
			or panel._selector.get_event() != gate.get_event() \
			or not is_instance_valid(title_view) or title_view.is_visible_in_tree() \
			or deck != null or run_map != null or run_rng != null \
			or is_instance_valid(stitched_fight_view) or is_instance_valid(base_screen) \
			or is_instance_valid(route_view) or is_instance_valid(party_picker):
		return
	# The panel's actual committed choice is the only UI witness. Do not trust
	# any supplied fight_request or node_type (especially Elite or Boss).
	if receipt != panel._committed_choice or receipt.size() != 4 \
			or receipt.get("ok") != true or receipt.get("event_id") != STITCHED_ROADBLOCK_ID \
			or receipt.get("wallet") != STITCHED_TITLE_WALLET:
		return
	var choice_id: Variant = receipt.get("choice_id")
	var preview: Dictionary = gate.preview_choices(STITCHED_TITLE_WALLET.duplicate(true))
	if preview.get("ok") != true:
		return
	var affordable := false
	for row_raw in preview.get("choices", []):
		if row_raw is Dictionary and row_raw.get("choice_id") == choice_id:
			affordable = row_raw.get("affordable") == true
			break
	if not affordable:
		return
	# Only Fight needs a confirmed four. An authentic Leave must stay usable
	# even if the player abandoned an incomplete draft.
	if choice_id == gate.get_fight_choice_id():
		var party := StitchedPartyAdmission.admit(_stitched_party_picks)
		if party.get("ok") != true or party != _stitched_party_receipt \
				or _stitched_party_draft != _stitched_party_picks:
			return
		if not _stitched_party_locked:
			if _stitched_picker_checkbox_ids().size() != 4:
				return
			for id in _stitched_party_picks:
				if not id in _stitched_picker_checkbox_ids():
					return
	# A new, once-only gate settles the same choice and immutable title wallet.
	# A cloned/forged/stale panel receipt cannot promote a visit into combat.
	var admitted: Dictionary = gate.choose_with_wallet(choice_id, STITCHED_TITLE_WALLET.duplicate(true))
	var fight_ok: bool = admitted.get("ok") == true \
			and admitted.get("event_id") == STITCHED_ROADBLOCK_ID \
			and admitted.get("choice_id") == gate.get_fight_choice_id() \
			and admitted.get("wallet") == STITCHED_TITLE_WALLET \
			and admitted.get("fight_request") == {"node_type": "Fight"}
	_retire_stitched_roadblock()
	if fight_ok:
		# Only the receipt settled by THIS panel may enter the live stage.
		_stitched_admitted_fight_gate = gate
		var mounted := _begin_stitched_battle(admitted, gate)
		_stitched_admitted_fight_gate = null
		if mounted:
			return
	_restore_stitched_title()


func _retire_stitched_roadblock() -> void:
	var panel := stitched_event_panel
	# Drop app authority before removing buttons; queued input is then inert.
	stitched_event_panel = null
	stitched_event_gate = null
	_stitched_party_draft.clear()
	_stitched_party_checkboxes.clear()
	_stitched_party_hint = null
	_stitched_party_confirm_button = null
	_stitched_party_cancel_button = null
	if is_instance_valid(panel):
		panel.close_event()
		if panel.get_parent() == self:
			remove_child(panel)
		panel.queue_free()


func _restore_stitched_title() -> void:
	if is_instance_valid(title_view):
		title_view.show()
		_focus_stitched_title.call_deferred(base_button)


func _begin_stitched_battle(admission: Dictionary, gate: RunV3FightEventGate) -> bool:
	if gate == null or gate != _stitched_admitted_fight_gate \
			or not gate.is_claimed() or admission.get("ok") != true \
			or admission.get("event_id") != STITCHED_ROADBLOCK_ID \
			or admission.get("choice_id") != gate.get_fight_choice_id() \
			or admission.get("wallet") != STITCHED_TITLE_WALLET \
			or admission.get("fight_request") != {"node_type": "Fight"} \
			or stitched_event_gate != null or is_instance_valid(stitched_event_panel) \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or stitched_sewing_mend_visit != null or stitched_sewing_upgrade_visit != null \
			or is_instance_valid(stitched_fight_view) or is_instance_valid(stitched_campfire_panel) \
			or stitched_campfire_visit != null or deck != null or run_map != null \
			or run_rng != null or not is_instance_valid(title_view) \
			or title_view.is_visible_in_tree():
		return false
	var data := _stitched_floor_config()
	if data.is_empty():
		return false
	# The charge belongs to this Roadblock entry, never the S2 preview.
	# Project first; a rejected begin cannot consume any candlelight.
	var projected_candle := maxi(0, stitched_roadblock_candle - STITCHED_ROADBLOCK_CANDLE_COST)
	data["candle"] = projected_candle
	var stage := StitchedBattleScreen.new()
	if not stage.begin(data):
		stage.free()
		return false
	stitched_fight_view = stage
	_stitched_battle_ticket = weakref(stage)
	stage.exit_requested.connect(_stitched_fight_exit.bind(weakref(stage)))
	add_child(stage)
	if stage.get_parent() != self or not stage.is_inside_tree():
		_close_stitched_fight()
		return false
	# Debit once, after the real fight is mounted with the projected rules input.
	stitched_roadblock_candle = projected_candle
	return true


func _stitched_fight_exit(source: WeakRef) -> void:
	var stage := source.get_ref() as StitchedBattleScreen if source != null else null
	if stage == null or stage != stitched_fight_view:
		return
	# Neither a forged UI receipt nor an unfinished/retreated battle can mint
	# spoils. This exact stage was created by the claimed Roadblock admission.
	var battle: StitchedRules = stage.battle
	var won: bool = _stitched_battle_ticket != null \
			and _stitched_battle_ticket.get_ref() == stage \
			and battle != null and battle.is_valid() and battle.is_over() \
			and battle.outcome() == "victory" and not stage.receipts.is_empty()
	var heroes: Array = []
	var defeated: Array = []
	var roster: Dictionary = {}
	var expected_foes: Array = STITCHED_ROADBLOCK_FOES
	if _stitched_roadblock_win_count > 0:
		expected_foes = STITCHED_FOLLOWON_ROADBLOCK_FOES
	if won:
		roster = StitchedEnemyCatalog.load_catalog()
		won = bool(roster.get("ok", false))
		if won:
			var seen_foes: Dictionary = {}
			for foe in battle.get_foes():
				var foe_id := str(foe.get("id", ""))
				# Dead foes may share their final compressed rank as the
				# formation closes; identity, death and original seat count
				# are the non-vacuous victory evidence.
				if not foe_id in expected_foes or seen_foes.has(foe_id):
					won = false
					continue
				seen_foes[foe_id] = true
				won = won and bool(foe.get("dead", false)) and int(foe.get("hp", -1)) == 0
				defeated.append(foe_id)
			won = won and defeated.size() == expected_foes.size()
		for hero in battle.get_heroes():
			if not bool(hero.get("lost", false)):
				heroes.append(hero.duplicate(true))
	# Validate all four settled hero receipts before any victory authority moves.
	var settled_fray: Dictionary = {}
	var circle_earned := false
	if won and heroes.size() == 4:
		for hero in heroes:
			var id: Variant = hero.get("id")
			var amount: Variant = hero.get("fray")
			var mood: Variant = hero.get("resolve")
			if typeof(id) != TYPE_STRING or not id in _stitched_party_picks \
					or settled_fray.has(id) or typeof(amount) != TYPE_INT \
					or int(amount) < 0 or int(amount) >= StitchedRules.FRAY_MAX \
					or typeof(mood) != TYPE_STRING \
					or not str(mood) in (["", "steadfast"] + StitchedS1BEffects.RESOLVE_TRAITS) \
					or (str(mood) in StitchedS1BEffects.RESOLVE_TRAITS \
					and int(amount) < StitchedRules.FRAY_RECOVER) \
					or (str(mood).is_empty() and int(amount) >= StitchedRules.FRAY_RESOLVE):
				won = false
				break
			settled_fray[id] = {"fray": amount, "resolve": mood}
	_close_stitched_fight()
	# Retire combat authority before giving the player another interactive node.
	if won and not heroes.is_empty():
		# A complete four-survivor victory is the only source of rank carry.
		# A partial/lost or malformed formation never overwrites prior ranks.
		if heroes.size() == 4:
			var ending_ranks: Dictionary = {}
			var used_ranks: Dictionary = {}
			for hero in heroes:
				var id: Variant = hero.get("id")
				var rank: Variant = hero.get("rank")
				if typeof(id) != TYPE_STRING or not id in _stitched_party_picks \
						or ending_ranks.has(id) or typeof(rank) != TYPE_INT \
						or int(rank) < 1 or int(rank) > 4 or used_ranks.has(rank):
					ending_ranks.clear()
					break
				ending_ranks[id] = rank
				used_ranks[rank] = true
			if ending_ranks.size() == 4:
				_stitched_rank_carry = ending_ranks
				# Rank carry and FRAY share the same genuine four-survivor proof.
				if settled_fray.size() == 4:
					_stitched_fray_carry = settled_fray
					# Only the real, settled four-survivor victory advances the
					# next title Fight. No Leave, loss or forged receipt can.
					_stitched_roadblock_win_count += 1
					circle_earned = true
		# This exact, once-only stage is the sole HP source. A lost hero is not
		# carried; failed, retreated and replayed exits leave the ledger untouched.
		for id in _stitched_party_picks:
			_stitched_hp_carry.erase(id)
		for hero in heroes:
			_stitched_hp_carry[str(hero["id"])] = int(hero["hp"])
		# One preview gold award belongs to this authenticated victory exit alone.
		# It never enters the legacy run/title wallets or uses global RNG.
		stitched_preview_gold += STITCHED_PREVIEW_WIN_GOLD
		# Only a positive integer Bleed status survives the fight, carried by
		# canonical hero ID. Anything else is dropped, never guessed.
		_stitched_bleed_carry.clear()
		for hero in heroes:
			var statuses: Variant = hero.get("statuses", {})
			if not statuses is Dictionary:
				continue
			var bleed: Variant = (statuses as Dictionary).get("bleed", 0)
			if typeof(bleed) == TYPE_INT and int(bleed) > 0:
				_stitched_bleed_carry[str(hero["id"])] = int(bleed)
		# A fresh terminal victory supersedes any Peddler offer won earlier.
		_stitched_peddler_roster.clear()
		_stitched_campfire_roster.clear()
		_stitched_campfire_authorized_roster.clear()
		_stitched_campfire_swap_roster.clear()
		_stitched_campfire_swap_satchel.clear()
		_stitched_campfire_swap_gear.clear()
		_stitched_postevent_roster.clear()
		_stitched_postvictory_stop_available = false
		_stitched_postevent_roster.clear()
		_refresh_stitched_peddler_button()
		# One preview scrap comes from this authenticated victory exit alone.
		# It never enters the legacy run/title wallets or uses global RNG.
		stitched_preview_scraps += 1
		# Only this encounter's own dead foes pay, and each pays through the one
		# canonical S5 trophy the enemy roster resolved for it.
		# Keep the Scissor Crab claw's established first-slot priority,
		# even when Ragling takes the next field's first combat rank.
		var trophy_order: Array = expected_foes.duplicate()
		trophy_order.erase("scissor_crab")
		trophy_order.push_front("scissor_crab")
		for foe_id in trophy_order:
			if not foe_id in defeated:
				continue
			if stitched_preview_satchel.size() >= RunStitchedSewingSwap.SATCHEL_CAP:
				break
			var trophy := StitchedEnemyCatalog.trophy_for(roster, str(foe_id))
			var part: Dictionary = roster.get("parts_by_id", {}).get(trophy, {})
			if trophy.is_empty() or part.is_empty():
				continue
			stitched_preview_satchel.append({
				"id": trophy, "slot": str(part["slot"]), "tier": 1, "torn": false,
			})
		# A one-use ticket exists only during this authenticated victory exit.
		if circle_earned:
			_stitched_sewing_admission = {
				"heroes": heroes.duplicate(true), "foes": expected_foes.duplicate(),
				"candle": stitched_roadblock_candle,
			}
			_open_stitched_sewing(heroes, expected_foes)
			_stitched_sewing_admission.clear()


func _open_stitched_sewing(heroes: Array, slain_foes: Array) -> bool:
	if _stitched_sewing_admission.is_empty() \
			or _stitched_sewing_admission.get("heroes") != heroes \
			or _stitched_sewing_admission.get("foes") != slain_foes \
			or _stitched_sewing_admission.get("candle") != stitched_roadblock_candle \
			or typeof(stitched_roadblock_candle) != TYPE_INT \
			or stitched_roadblock_candle < 0 or stitched_roadblock_candle > RunPeddlerVisit.CANDLE_MAX \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or stitched_sewing_mend_visit != null or stitched_sewing_upgrade_visit != null \
			or is_instance_valid(stitched_fight_view) or not is_instance_valid(title_view) \
			or not title_view.is_visible_in_tree():
		return false
	var projected_candle := maxi(0, int(stitched_roadblock_candle) - STITCHED_ROADBLOCK_CANDLE_COST)
	var config := _stitched_floor_config()
	if config.is_empty():
		return false
	var catalog := StitchedParts.build_catalog(config["parts"])
	if not bool(catalog.get("ok", false)):
		return false
	var roster := StitchedEnemyCatalog.load_catalog()
	if not bool(roster.get("ok", false)):
		return false
	for foe_id in slain_foes:
		var trophy := StitchedEnemyCatalog.trophy_for(roster, str(foe_id))
		if trophy.is_empty() or not catalog["by_id"].has(trophy):
			return false
	var visit := RunStitchedSewingSwap.new(
		STITCHED_SEWING_NODE_ID, heroes, stitched_preview_satchel, catalog["by_id"])
	var mend_visit := RunStitchedSewingMend.new(
		STITCHED_SEWING_NODE_ID, heroes, stitched_preview_scraps,
		STITCHED_SEWING_MEND_COST, catalog["by_id"])
	var upgrade_visit := RunStitchedSewingUpgrade.new(
		STITCHED_SEWING_NODE_ID, heroes, stitched_preview_scraps,
		STITCHED_SEWING_UPGRADE_COST, catalog["by_id"])
	if visit.read_state().get("ok") != true or mend_visit.read_state().get("ok") != true \
			or upgrade_visit.read_state().get("ok") != true:
		return false
	var panel := Control.new()
	panel.name = "StitchedSewingCircle"
	panel.theme = load("res://themes/gothic_theme.tres")
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.focus_mode = Control.FOCUS_ALL
	# Build every service quote and control while detached, before publishing
	# service authority or spending the node's candle entrance cost.
	if not _build_stitched_sewing(panel, visit.quote(), mend_visit.quote(), upgrade_visit.quote()):
		panel.free()
		return false
	add_child(panel)
	if not panel.is_inside_tree() or panel.get_parent() != self:
		panel.free()
		return false
	_stitched_sewing_admission.clear()
	stitched_roadblock_candle = projected_candle
	stitched_sewing_visit = visit
	stitched_sewing_mend_visit = mend_visit
	stitched_sewing_upgrade_visit = upgrade_visit
	_stitched_sewing_catalog = catalog["by_id"].duplicate(true)
	stitched_sewing_panel = panel
	_stitched_sewing_quote = visit.quote().duplicate(true)
	_stitched_mend_quote = mend_visit.quote().duplicate(true)
	_stitched_upgrade_quote = upgrade_visit.quote().duplicate(true)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_view.hide()
	panel.get_node("SewingLeave").grab_focus()
	return true


func _refresh_stitched_sewing() -> void:
	var panel := stitched_sewing_panel
	var visit := stitched_sewing_visit
	var mend_visit := stitched_sewing_mend_visit
	var upgrade_visit := stitched_sewing_upgrade_visit
	if not is_instance_valid(panel) or visit == null or mend_visit == null or upgrade_visit == null:
		return
	for old_child in panel.get_children():
		panel.remove_child(old_child)
		old_child.queue_free()
	var quote: Dictionary = visit.quote()
	var mend_quote: Dictionary = mend_visit.quote()
	var upgrade_quote: Dictionary = upgrade_visit.quote()
	if not _build_stitched_sewing(panel, quote, mend_quote, upgrade_quote):
		return
	_stitched_sewing_quote = quote.duplicate(true)
	_stitched_mend_quote = mend_quote.duplicate(true)
	_stitched_upgrade_quote = upgrade_quote.duplicate(true)


func _build_stitched_sewing(panel: Control, quote: Dictionary,
		mend_quote: Dictionary, upgrade_quote: Dictionary) -> bool:
	if quote.get("ok") != true or quote.get("open") != true \
			or mend_quote.get("ok") != true or mend_quote.get("open") != true \
			or upgrade_quote.get("ok") != true or upgrade_quote.get("open") != true \
			or quote["state"]["heroes"] != mend_quote["state"]["heroes"] \
			or quote["state"]["heroes"] != upgrade_quote["state"]["heroes"] \
			or int(mend_quote["scraps"]) != stitched_preview_scraps \
			or int(upgrade_quote["scraps"]) != stitched_preview_scraps \
			or int(upgrade_quote["upgrade_cost"]) != STITCHED_SEWING_UPGRADE_COST:
		return false
	# All the framing is shipped textile artwork, never code-drawn panels.
	var frame := NinePatchRect.new()
	var art_path := "res://assets/paper/ui/panel_felt.png"
	if ResourceLoader.exists(art_path, "Texture2D"):
		frame.texture = load(art_path)
		frame.patch_margin_left = 24
		frame.patch_margin_right = 24
		frame.patch_margin_top = 24
		frame.patch_margin_bottom = 24
	frame.position = Vector2(120, 40)
	frame.size = Vector2(1040, 640)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	var heading := Label.new()
	heading.text = "SEWING CIRCLE  ·  SPOILS OF THE STITCHED ROADBLOCK"
	heading.position = Vector2(165, 78)
	heading.size = Vector2(960, 54)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 27)
	panel.add_child(heading)
	var description := Label.new()
	description.text = "A crab claw, scavenger sack and Scribe inkbrush await the needle. Sew new arms on a living hero without coin."
	description.position = Vector2(170, 143)
	description.size = Vector2(950, 64)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(description)
	var count := Label.new()
	count.text = "SATCHEL %d / %d  ·  SCRAPS %d  ·  Mend: %d / Upgrade tier: %d" % [
		int(quote["satchel_count"]), int(quote["satchel_max"]),
		stitched_preview_scraps, STITCHED_SEWING_MEND_COST, STITCHED_SEWING_UPGRADE_COST]
	count.position = Vector2(183, 224)
	count.size = Vector2(910, 36)
	panel.add_child(count)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(180, 278)
	scroll.size = Vector2(920, 270)
	panel.add_child(scroll)
	var offers := VBoxContainer.new()
	offers.custom_minimum_size.x = 890
	offers.add_theme_constant_override("separation", 8)
	scroll.add_child(offers)
	var first_button: Button
	var expected_state: Dictionary = quote["state"].duplicate(true)
	var mend_state: Dictionary = mend_quote["state"].duplicate(true)
	var upgrade_state: Dictionary = upgrade_quote["state"].duplicate(true)
	for hero_row in quote["heroes"]:
		for slot_row in hero_row["slots"]:
			var worn: Dictionary = slot_row["worn"]
			var hero_name := str(hero_row["name"])
			var blocked := str(slot_row["blocked"])
			# The upgrade service owns all tier, affordability and authored
			# effect projections. Disabled offers stay visible and unfocusable.
			for up_hero in upgrade_quote["heroes"]:
				if str(up_hero["hero_id"]) != str(hero_row["hero_id"]):
					continue
				for up_slot in up_hero["slots"]:
					if str(up_slot["slot"]) != str(slot_row["slot"]):
						continue
					var upgrade_button := Button.new()
					upgrade_button.name = "Upgrade_%s_%s" % [str(hero_row["hero_id"]), str(slot_row["slot"])]
					upgrade_button.custom_minimum_size = Vector2(850, 52)
					upgrade_button.disabled = not bool(up_slot["can_upgrade"])
					upgrade_button.focus_mode = Control.FOCUS_NONE if upgrade_button.disabled else Control.FOCUS_ALL
					var up_reason := str(up_slot["blocked"])
					var next_label := "max" if int(up_slot["next_tier"]) == 0 else str(up_slot["next_tier"])
					upgrade_button.text = "Upgrade %s's %s · tier %d → %s · %d scraps%s" % [
						hero_name, str(up_slot["worn"]["name"]), int(up_slot["current_tier"]),
						next_label, int(up_slot["cost"]),
						(" — " + up_reason) if not up_reason.is_empty() else ""]
					upgrade_button.tooltip_text = "CURRENT stat %s / ability %s\nNEXT stat %s / ability %s" % [
						JSON.stringify(up_slot["current_stat"]), JSON.stringify(up_slot["current_ability"]),
						JSON.stringify(up_slot["next_stat"]), JSON.stringify(up_slot["next_ability"])]
					upgrade_button.pressed.connect(_stitched_sewing_upgrade.bind(
						str(hero_row["hero_id"]), str(slot_row["slot"]), upgrade_state.duplicate(true), weakref(panel)))
					offers.add_child(upgrade_button)
					var effects := Label.new()
					effects.name = "UpgradeEffects_%s_%s" % [str(hero_row["hero_id"]), str(slot_row["slot"])]
					effects.custom_minimum_size = Vector2(850, 0)
					effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					effects.text = "NOW %s  /  NEXT %s" % [
						_stitched_upgrade_effects(up_slot["current_stat"], up_slot["current_ability"]),
						_stitched_upgrade_effects(up_slot["next_stat"], up_slot["next_ability"])
							if int(up_slot["next_tier"]) > 0 else "max tier"]
					offers.add_child(effects)
					if not upgrade_button.disabled and first_button == null:
						first_button = upgrade_button
			# Only quoted torn worn parts get a Mend control. Unaffordable
			# and lost-hero requests remain visible but disabled with a reason.
			if bool(worn["torn"]):
				for mend_hero in mend_quote["heroes"]:
					if str(mend_hero["hero_id"]) != str(hero_row["hero_id"]):
						continue
					for mend_slot in mend_hero["slots"]:
						if str(mend_slot["slot"]) != str(slot_row["slot"]):
							continue
						var mend_button := Button.new()
						mend_button.name = "Mend_%s_%s" % [str(hero_row["hero_id"]), str(slot_row["slot"])]
						mend_button.custom_minimum_size = Vector2(850, 48)
						mend_button.disabled = not bool(mend_slot["can_mend"])
						mend_button.focus_mode = Control.FOCUS_NONE if mend_button.disabled else Control.FOCUS_ALL
						var reason := str(mend_slot["blocked"])
						mend_button.text = "Mend %s's torn %s · %d scraps%s" % [
							hero_name, str(worn["name"]), int(mend_slot["cost"]),
							(" — " + reason) if not reason.is_empty() else ""]
						mend_button.tooltip_text = reason
						mend_button.pressed.connect(_stitched_sewing_mend.bind(
							str(hero_row["hero_id"]), str(slot_row["slot"]), mend_state.duplicate(true), weakref(panel)))
						offers.add_child(mend_button)
						if not mend_button.disabled and first_button == null:
							first_button = mend_button
			if not blocked.is_empty():
				var warning := Label.new()
				warning.text = "%s · %s — %s" % [hero_name, str(worn["name"]), blocked]
				offers.add_child(warning)
			for spare in slot_row["offers"]:
				var button := Button.new()
				button.name = "Swap_%s_%d" % [str(hero_row["hero_id"]), int(spare["satchel_index"])]
				button.custom_minimum_size = Vector2(850, 48)
				button.text = "Sew %s onto %s (replace %s · tier %d)" % [
					str(spare["part"]["name"]), hero_name, str(worn["name"]), int(worn["tier"])]
				button.pressed.connect(_stitched_sewing_swap.bind(
					str(hero_row["hero_id"]), str(slot_row["slot"]),
					int(spare["satchel_index"]), expected_state.duplicate(true), weakref(panel)))
				offers.add_child(button)
				if first_button == null:
					first_button = button
	var leave_button := Button.new()
	leave_button.name = "SewingLeave"
	leave_button.text = "Leave the Circle · Return to title"
	leave_button.position = Vector2(405, 576)
	leave_button.size = Vector2(470, 54)
	leave_button.pressed.connect(_stitched_sewing_leave.bind(expected_state.duplicate(true), weakref(panel)))
	panel.add_child(leave_button)
	if first_button != null and panel.is_inside_tree():
		first_button.grab_focus()
	elif panel.is_inside_tree():
		leave_button.grab_focus()
	return true


func _stitched_upgrade_effects(stat: Dictionary, ability: Dictionary) -> String:
	# These are authored per-tier values, never a caller-side scaling rule.
	return "stat %s · %s · dmg %s · acc %s · crit %s · effects %s" % [
		JSON.stringify(stat), str(ability.get("id", "none")),
		JSON.stringify(ability.get("dmg", [])), str(ability.get("acc", "-")),
		str(ability.get("crit", "-")), JSON.stringify(ability.get("effects", {}))]


# All three independent services must describe the same real node, equipped party,
# preview balance and displayed snapshots before either can change the visit.
func _stitched_sewing_consistent() -> bool:
	if stitched_sewing_visit == null or stitched_sewing_mend_visit == null \
			or stitched_sewing_upgrade_visit == null:
		return false
	var swap_state: Dictionary = stitched_sewing_visit.read_state()
	var mend_state: Dictionary = stitched_sewing_mend_visit.read_state()
	var upgrade_state: Dictionary = stitched_sewing_upgrade_visit.read_state()
	return swap_state.get("ok") == true and mend_state.get("ok") == true \
		and upgrade_state.get("ok") == true \
		and swap_state.get("open") == true and mend_state.get("open") == true \
		and upgrade_state.get("open") == true \
		and swap_state.get("node_id") == STITCHED_SEWING_NODE_ID \
		and mend_state.get("node_id") == STITCHED_SEWING_NODE_ID \
		and upgrade_state.get("node_id") == STITCHED_SEWING_NODE_ID \
		and swap_state.get("heroes") == mend_state.get("heroes") \
		and swap_state.get("heroes") == upgrade_state.get("heroes") \
		and swap_state.get("satchel") == stitched_preview_satchel \
		and mend_state.get("scraps") == stitched_preview_scraps \
		and upgrade_state.get("scraps") == stitched_preview_scraps \
		and mend_state.get("mend_cost") == STITCHED_SEWING_MEND_COST \
		and upgrade_state.get("upgrade_cost") == STITCHED_SEWING_UPGRADE_COST \
		and _stitched_sewing_quote.get("state") == swap_state \
		and _stitched_mend_quote.get("state") == mend_state \
		and _stitched_upgrade_quote.get("state") == upgrade_state


## A live button may spend scraps only against its displayed service quote,
## exact current node and synced swap/mend authority. Service is the only tier
## mutator; its complete receipt is checked before touching the real run.
func _stitched_sewing_upgrade(hero_id: String, slot: String,
		expected_state: Dictionary, source: WeakRef) -> Dictionary:
	var panel: Control = source.get_ref() as Control if source != null else null
	if not is_instance_valid(panel) or panel != stitched_sewing_panel or not panel.is_visible_in_tree() \
			or is_instance_valid(stitched_fight_view) or not _stitched_sewing_consistent() \
			or _stitched_upgrade_quote.get("state", {}) != expected_state:
		return {"ok": false, "error": "stale Sewing Circle upgrade"}
	var offered: Dictionary = {}
	for hero_row in _stitched_upgrade_quote.get("heroes", []):
		if str(hero_row["hero_id"]) != hero_id:
			continue
		for slot_row in hero_row["slots"]:
			if str(slot_row["slot"]) == slot and bool(slot_row["can_upgrade"]) \
					and int(slot_row["cost"]) == STITCHED_SEWING_UPGRADE_COST:
				offered = slot_row
	if offered.is_empty() or stitched_preview_scraps < STITCHED_SEWING_UPGRADE_COST:
		return {"ok": false, "error": "not a displayed affordable upgrade"}
	var expected_heroes: Array = expected_state["heroes"].duplicate(true)
	var part_id := ""
	var tier_before := 0
	var changed_hero: Dictionary = {}
	for hero in expected_heroes:
		if str(hero["id"]) != hero_id:
			continue
		var worn: Dictionary = hero["parts"].get(slot, {})
		if worn.is_empty() or worn != {
				"id": offered["worn"]["id"],
				"tier": offered["current_tier"], "torn": false}:
			return {"ok": false, "error": "quoted worn part differs"}
		part_id = str(worn["id"])
		tier_before = int(worn["tier"])
		hero["parts"][slot]["tier"] = tier_before + 1
		changed_hero = hero.duplicate(true)
	if changed_hero.is_empty() or int(offered["next_tier"]) != tier_before + 1:
		return {"ok": false, "error": "not a quoted tier progression"}
	var receipt: Dictionary = stitched_sewing_upgrade_visit.upgrade(
		hero_id, slot, STITCHED_SEWING_NODE_ID, expected_state)
	var result: Dictionary = receipt.get("state", {})
	if receipt.get("ok") != true or receipt.get("action") != "upgrade" \
			or receipt.get("node_id") != STITCHED_SEWING_NODE_ID \
			or receipt.get("source_state") != expected_state \
			or receipt.get("hero_id") != hero_id or receipt.get("slot") != slot \
			or receipt.get("part_id") != part_id \
			or receipt.get("tier_before") != tier_before \
			or receipt.get("tier_after") != tier_before + 1 \
			or receipt.get("charged_scraps") != STITCHED_SEWING_UPGRADE_COST \
			or receipt.get("scraps_before") != stitched_preview_scraps \
			or receipt.get("scraps") != stitched_preview_scraps - STITCHED_SEWING_UPGRADE_COST \
			or result.get("open") != true \
			or result.get("version") != int(expected_state["version"]) + 1 \
			or result.get("heroes") != expected_heroes \
			or result != stitched_sewing_upgrade_visit.read_state() \
			or receipt.get("changed_heroes") != [changed_hero] \
			or receipt.get("changed_hero") != changed_hero:
		return {"ok": false, "error": "upgrade receipt rejected"}
	var next_swap := RunStitchedSewingSwap.new(
		STITCHED_SEWING_NODE_ID, expected_heroes, stitched_preview_satchel,
		_stitched_sewing_catalog)
	var next_mend := RunStitchedSewingMend.new(
		STITCHED_SEWING_NODE_ID, expected_heroes, int(receipt["scraps"]),
		STITCHED_SEWING_MEND_COST, _stitched_sewing_catalog)
	if next_swap.read_state().get("ok") != true or next_mend.read_state().get("ok") != true:
		return {"ok": false, "error": "could not rebind after upgrade"}
	stitched_sewing_visit.leave(STITCHED_SEWING_NODE_ID, _stitched_sewing_quote["state"])
	stitched_sewing_mend_visit.leave(STITCHED_SEWING_NODE_ID, _stitched_mend_quote["state"])
	stitched_sewing_visit = next_swap
	stitched_sewing_mend_visit = next_mend
	stitched_preview_scraps = int(receipt["scraps"])
	var carried: Dictionary = _stitched_gear_overrides.get(hero_id, {}).duplicate(true)
	carried[slot] = changed_hero["parts"][slot].duplicate(true)
	_stitched_gear_overrides[hero_id] = carried
	_refresh_stitched_sewing()
	return receipt


func _stitched_sewing_mend(hero_id: String, slot: String,
		expected_state: Dictionary, source: WeakRef) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	if panel == null or panel != stitched_sewing_panel or not panel.is_visible_in_tree() \
			or is_instance_valid(stitched_fight_view) or not _stitched_sewing_consistent() \
			or _stitched_mend_quote.get("state", {}) != expected_state:
		return {"ok": false, "error": "stale Sewing Circle mend"}
	var offered := false
	for hero_row in _stitched_mend_quote.get("heroes", []):
		if str(hero_row["hero_id"]) != hero_id:
			continue
		for slot_row in hero_row["slots"]:
			if str(slot_row["slot"]) == slot \
					and bool(slot_row["can_mend"]) and bool(slot_row["worn"]["torn"]):
				offered = true
	if not offered:
		return {"ok": false, "error": "not a quoted affordable torn part"}
	var receipt: Dictionary = stitched_sewing_mend_visit.mend(
		hero_id, slot, STITCHED_SEWING_NODE_ID, expected_state)
	if receipt.get("ok") != true or receipt.get("source_state") != expected_state \
			or receipt.get("charged_scraps") != STITCHED_SEWING_MEND_COST \
			or receipt.get("scraps") != stitched_preview_scraps - STITCHED_SEWING_MEND_COST:
		return {"ok": false, "error": "mend rejected"}
	# Rebind the swap ledger to the exact mended party, keeping satchel order;
	# close its previous authority so an old state cannot be used again.
	var rebound := RunStitchedSewingSwap.new(
		STITCHED_SEWING_NODE_ID, receipt["state"]["heroes"],
		stitched_preview_satchel, _stitched_sewing_catalog)
	var upgrade_rebound := RunStitchedSewingUpgrade.new(
		STITCHED_SEWING_NODE_ID, receipt["state"]["heroes"], int(receipt["scraps"]),
		STITCHED_SEWING_UPGRADE_COST, _stitched_sewing_catalog)
	if rebound.read_state().get("ok") != true or upgrade_rebound.read_state().get("ok") != true:
		return {"ok": false, "error": "could not rebind swap/upgrade visit"}
	stitched_sewing_visit.leave(STITCHED_SEWING_NODE_ID, _stitched_sewing_quote["state"])
	stitched_sewing_upgrade_visit.leave(STITCHED_SEWING_NODE_ID, _stitched_upgrade_quote["state"])
	stitched_sewing_visit = rebound
	stitched_sewing_upgrade_visit = upgrade_rebound
	stitched_preview_scraps = int(receipt["scraps"])
	for changed in receipt["changed_heroes"]:
		var changed_id := str(changed["id"])
		var carried: Dictionary = _stitched_gear_overrides.get(changed_id, {}).duplicate(true)
		carried[slot] = changed["parts"][slot].duplicate(true)
		_stitched_gear_overrides[changed_id] = carried
	_refresh_stitched_sewing()
	return receipt


func _stitched_sewing_swap(hero_id: String, slot: String, satchel_index: int,
		expected_state: Dictionary, source: WeakRef) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	if panel == null or panel != stitched_sewing_panel or not panel.is_visible_in_tree() \
			or stitched_sewing_visit == null or is_instance_valid(stitched_fight_view) \
			or _stitched_sewing_quote.get("state", {}) != expected_state \
			or not _stitched_sewing_consistent():
		return {"ok": false, "error": "stale Sewing Circle"}
	# Authorise only a currently displayed compatible quote, not arbitrary
	# client-supplied indices or a cloned receipt.
	var matched := false
	for hero_row in _stitched_sewing_quote.get("heroes", []):
		if str(hero_row["hero_id"]) != hero_id:
			continue
		for slot_row in hero_row["slots"]:
			if str(slot_row["slot"]) != slot or not bool(slot_row["can_swap"]):
				continue
			for offered in slot_row["offers"]:
				if int(offered["satchel_index"]) == satchel_index:
					matched = true
	if not matched:
		return {"ok": false, "error": "not an offered compatible part"}
	var receipt: Dictionary = stitched_sewing_visit.swap(
		hero_id, slot, satchel_index, STITCHED_SEWING_NODE_ID, expected_state)
	if receipt.get("ok") != true or receipt.get("source_state") != expected_state:
		return {"ok": false, "error": "swap rejected"}
	# A successful swap changes the authoritative hero snapshot used by Mend.
	# Retire the old mend authority and rebind without awarding or spending scrap.
	var rebound := RunStitchedSewingMend.new(
		STITCHED_SEWING_NODE_ID, receipt["state"]["heroes"], stitched_preview_scraps,
		STITCHED_SEWING_MEND_COST, _stitched_sewing_catalog)
	var upgrade_rebound := RunStitchedSewingUpgrade.new(
		STITCHED_SEWING_NODE_ID, receipt["state"]["heroes"], stitched_preview_scraps,
		STITCHED_SEWING_UPGRADE_COST, _stitched_sewing_catalog)
	if rebound.read_state().get("ok") != true or upgrade_rebound.read_state().get("ok") != true:
		return {"ok": false, "error": "could not rebind mend/upgrade visit"}
	stitched_sewing_mend_visit.leave(STITCHED_SEWING_NODE_ID, _stitched_mend_quote["state"])
	stitched_sewing_upgrade_visit.leave(STITCHED_SEWING_NODE_ID, _stitched_upgrade_quote["state"])
	stitched_sewing_mend_visit = rebound
	stitched_sewing_upgrade_visit = upgrade_rebound
	stitched_preview_satchel = receipt["satchel"].duplicate(true)
	for changed in receipt["changed_heroes"]:
		var changed_id := str(changed["id"])
		var carried: Dictionary = _stitched_gear_overrides.get(changed_id, {}).duplicate(true)
		carried[slot] = changed["parts"][slot].duplicate(true)
		_stitched_gear_overrides[changed_id] = carried
	_refresh_stitched_sewing()
	return receipt


func _stitched_sewing_leave(expected_state: Dictionary, source: WeakRef) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	if panel == null or panel != stitched_sewing_panel or not panel.is_visible_in_tree() \
			or stitched_sewing_visit == null or is_instance_valid(stitched_fight_view) \
			or _stitched_sewing_quote.get("state", {}) != expected_state \
			or not _stitched_sewing_consistent():
		return {"ok": false, "error": "stale Sewing Circle"}
	var mend_expected: Dictionary = _stitched_mend_quote["state"].duplicate(true)
	var upgrade_expected: Dictionary = _stitched_upgrade_quote["state"].duplicate(true)
	var receipt: Dictionary = stitched_sewing_visit.leave(STITCHED_SEWING_NODE_ID, expected_state)
	if receipt.get("ok") != true:
		return {"ok": false, "error": "swap Leave rejected"}
	var mend_receipt: Dictionary = stitched_sewing_mend_visit.leave(
		STITCHED_SEWING_NODE_ID, mend_expected)
	if mend_receipt.get("ok") != true:
		return {"ok": false, "error": "mend Leave rejected"}
	var upgrade_receipt: Dictionary = stitched_sewing_upgrade_visit.leave(
		STITCHED_SEWING_NODE_ID, upgrade_expected)
	if upgrade_receipt.get("ok") != true:
		return {"ok": false, "error": "upgrade Leave rejected"}
	# Only all three authenticated, one-shot terminal receipts can carry equipment.
	# A service's closed state preserves exactly the worn heroes it was given.
	var swap_final: Dictionary = receipt.get("state", {})
	var mend_final: Dictionary = mend_receipt.get("state", {})
	var upgrade_final: Dictionary = upgrade_receipt.get("state", {})
	if receipt.get("action") != "leave" or mend_receipt.get("action") != "leave" \
			or upgrade_receipt.get("action") != "leave" \
			or receipt.get("node_id") != STITCHED_SEWING_NODE_ID \
			or mend_receipt.get("node_id") != STITCHED_SEWING_NODE_ID \
			or upgrade_receipt.get("node_id") != STITCHED_SEWING_NODE_ID \
			or receipt.get("source_state") != expected_state \
			or mend_receipt.get("source_state") != mend_expected \
			or upgrade_receipt.get("source_state") != upgrade_expected \
			or swap_final.get("open") != false or mend_final.get("open") != false \
			or upgrade_final.get("open") != false \
			or swap_final.get("version") != int(expected_state["version"]) + 1 \
			or mend_final.get("version") != int(mend_expected["version"]) + 1 \
			or upgrade_final.get("version") != int(upgrade_expected["version"]) + 1 \
			or swap_final.get("heroes") != mend_final.get("heroes") \
			or swap_final.get("heroes") != upgrade_final.get("heroes") \
			or swap_final.get("heroes") != expected_state.get("heroes") \
			or swap_final.get("satchel") != stitched_preview_satchel \
			or mend_final.get("scraps") != stitched_preview_scraps \
			or upgrade_final.get("scraps") != stitched_preview_scraps \
			or upgrade_receipt.get("charged_scraps") != 0:
		return {"ok": false, "error": "inconsistent Sewing Circle Leave"}
	var next_overrides: Dictionary = _stitched_gear_overrides.duplicate(true)
	for hero in swap_final["heroes"]:
		var hero_id := str(hero["id"])
		var carried: Dictionary = next_overrides.get(hero_id, {}).duplicate(true)
		for slot in StitchedParts.SLOTS:
			var worn: Dictionary = hero["parts"][slot]
			if bool(worn["torn"]):
				# Do not replace lawful swap/mend overrides or unrelated gear.
				carried[slot] = worn.duplicate(true)
		if not carried.is_empty():
			next_overrides[hero_id] = carried
	_stitched_gear_overrides = next_overrides
	# No attempted or stale Leave may lock the roster. Require the four
	# authenticated survivors' exact IDs and earned carry before sealing it.
	var earned_ids: Array = []
	for hero in swap_final["heroes"]:
		if hero is Dictionary and typeof(hero.get("id")) == TYPE_STRING:
			earned_ids.append(hero["id"])
	if earned_ids.size() == 4 and _stitched_party_picks.size() == 4 \
			and _stitched_rank_carry.size() == 4 and _stitched_hp_carry.size() == 4:
		var same_party := true
		for id in _stitched_party_picks:
			if earned_ids.count(id) != 1 or not _stitched_rank_carry.has(id) \
					or not _stitched_hp_carry.has(id):
				same_party = false
		if same_party:
			_stitched_party_locked = true
	_close_stitched_sewing()
	# The Peddler is earned only by this exact terminal victory + Circle Leave.
	_offer_stitched_peddler(swap_final["heroes"])
	_offer_stitched_campfire(swap_final["heroes"])
	_stitched_unpicker_earned = _stitched_unpicker_live_context()
	_stitched_campfire_earned = _stitched_unpicker_live_context()
	_refresh_stitched_peddler_button()
	return receipt


func _close_stitched_sewing() -> void:
	# Forced UI cleanup must also retire old service objects held by callers.
	# Each close is free, one-shot and consumes neither wallet nor RNG.
	if stitched_sewing_visit != null:
		var swap_state: Dictionary = stitched_sewing_visit.read_state()
		if swap_state.get("ok") == true and swap_state.get("open") == true:
			stitched_sewing_visit.leave(STITCHED_SEWING_NODE_ID, swap_state)
	if stitched_sewing_mend_visit != null:
		var mend_state: Dictionary = stitched_sewing_mend_visit.read_state()
		if mend_state.get("ok") == true and mend_state.get("open") == true:
			stitched_sewing_mend_visit.leave(STITCHED_SEWING_NODE_ID, mend_state)
	if stitched_sewing_upgrade_visit != null:
		var upgrade_state: Dictionary = stitched_sewing_upgrade_visit.read_state()
		if upgrade_state.get("ok") == true and upgrade_state.get("open") == true:
			stitched_sewing_upgrade_visit.leave(STITCHED_SEWING_NODE_ID, upgrade_state)
	var panel := stitched_sewing_panel
	stitched_sewing_panel = null
	stitched_sewing_visit = null
	stitched_sewing_mend_visit = null
	stitched_sewing_upgrade_visit = null
	_stitched_sewing_quote.clear()
	_stitched_mend_quote.clear()
	_stitched_upgrade_quote.clear()
	_stitched_sewing_catalog.clear()
	if is_instance_valid(panel):
		if panel.get_parent() == self:
			remove_child(panel)
		panel.queue_free()
	_restore_stitched_title()


func _close_stitched_fight() -> void:
	if not is_instance_valid(stitched_fight_view):
		stitched_fight_view = null
		_stitched_battle_ticket = null
		return
	var stage := stitched_fight_view
	stitched_fight_view = null
	_stitched_battle_ticket = null
	# Retire the authority *before* queued GUI signals or stale references can
	# invoke any of its action handlers again.
	stage.battle = null
	stage._selected_part = ""
	stage._target_ranks.clear()
	if stage.get_parent() == self:
		remove_child(stage)
	stage.queue_free()
	if is_instance_valid(title_view):
		title_view.show()
		_focus_stitched_title.call_deferred(base_button)


## The winning survivors, by ID and rank, are the only Peddler customers. The
## roster is rebuilt from the app's own carried HP/Bleed, so a reselected or
## unliving party fails closed instead of inheriting an earlier offer.
func _offer_stitched_peddler(survivors: Array) -> void:
	_stitched_peddler_roster.clear()
	if survivors.size() == 4 and _stitched_party_picks.size() == 4:
		var roster: Array = []
		for hero_raw in survivors:
			if not hero_raw is Dictionary:
				roster.clear()
				break
			var hero: Dictionary = hero_raw
			var hero_id := str(hero.get("id", ""))
			var rank: Variant = hero.get("rank")
			var statuses := {}
			if hero_id.is_empty() or not hero_id in _stitched_party_picks \
					or not _stitched_hp_carry.has(hero_id) \
					or typeof(rank) != TYPE_INT or int(rank) < 1 or int(rank) > 4:
				roster.clear()
				break
			if _stitched_bleed_carry.has(hero_id):
				var bleed: Variant = _stitched_bleed_carry[hero_id]
				if typeof(bleed) != TYPE_INT or int(bleed) <= 0:
					roster.clear()
					break
				statuses["bleed"] = int(bleed)
			roster.append({"id": hero_id, "name": str(hero.get("name", hero_id)),
				"rank": int(rank), "statuses": statuses})
		if roster.size() == 4:
			roster.sort_custom(func(a, b): return int(a["rank"]) < int(b["rank"]))
			_stitched_peddler_roster = roster
	if _stitched_peddler_living_roster().is_empty():
		_stitched_peddler_roster.clear()
	_refresh_stitched_peddler_button()


## Only the actual Circle Leave's four non-lost battle heroes can earn
## Campfire. Record their CURRENT battle rank, worn max HP, HP, and fray.
## Unlike Peddler, a zero-HP Hanging (not lost) hero is valid for Mend.
## The Campfire's HP-only recovery quote must remain tied to the complete,
## genuine battle-settled FRAY/resolve pairs for these exact selected IDs.
func _stitched_campfire_held_fray_valid(roster: Array) -> bool:
	if roster.size() != 4 or _stitched_fray_carry.size() != 4 \
			or _stitched_party_picks.size() != 4:
		return false
	var seen := {}
	for hero_value in roster:
		if not hero_value is Dictionary:
			return false
		var hero: Dictionary = hero_value
		var id: Variant = hero.get("id")
		if typeof(id) != TYPE_STRING or not id in _stitched_party_picks \
				or seen.has(id) or typeof(hero.get("fray")) != TYPE_INT \
				or not _stitched_fray_carry.has(id):
			return false
		var record: Variant = _stitched_fray_carry[id]
		if not record is Dictionary or record.size() != 2 \
				or typeof(record.get("fray")) != TYPE_INT \
				or typeof(record.get("resolve")) != TYPE_STRING \
				or record["fray"] != hero["fray"]:
			return false
		var fray: int = int(record["fray"])
		var mood: String = str(record["resolve"])
		if fray < 0 or fray >= StitchedRules.FRAY_MAX \
				or not mood in (["", "steadfast"] + StitchedS1BEffects.RESOLVE_TRAITS) \
				or (mood in StitchedS1BEffects.RESOLVE_TRAITS \
				and fray < StitchedRules.FRAY_RECOVER) \
				or (mood.is_empty() and fray >= StitchedRules.FRAY_RESOLVE):
			return false
		seen[id] = true
	for carried_id in _stitched_fray_carry:
		if not seen.has(carried_id):
			return false
	return true


func _offer_stitched_campfire(survivors: Array) -> void:
	_stitched_campfire_roster.clear()
	_stitched_campfire_authorized_roster.clear()
	_stitched_campfire_swap_roster.clear()
	_stitched_campfire_swap_satchel.clear()
	_stitched_campfire_swap_gear.clear()
	if survivors.size() == 4 and _stitched_party_picks.size() == 4 \
			and _stitched_fray_carry.size() == 4:
		var roster: Array = []
		for value in survivors:
			if not value is Dictionary:
				roster.clear()
				break
			var hero: Dictionary = value
			var id := str(hero.get("id", ""))
			if bool(hero.get("lost", true)) or not id in _stitched_party_picks \
					or not _stitched_hp_carry.has(id) \
					or typeof(_stitched_hp_carry[id]) != TYPE_INT \
					or typeof(hero.get("rank")) != TYPE_INT \
					or typeof(hero.get("hp")) != TYPE_INT \
					or typeof(hero.get("max_hp")) != TYPE_INT \
					or typeof(hero.get("fray")) != TYPE_INT \
					or not _stitched_fray_carry.has(id) \
					or typeof(hero.get("resolve")) != TYPE_STRING \
					or not _stitched_fray_carry[id] is Dictionary \
					or _stitched_fray_carry[id].get("fray") != hero["fray"] \
					or _stitched_fray_carry[id].get("resolve") != hero["resolve"] \
					or int(hero["hp"]) != int(_stitched_hp_carry[id]):
				roster.clear()
				break
			roster.append({"id": id, "name": str(hero.get("name", id)),
				"position": int(hero["rank"]), "hp": int(hero["hp"]),
				"max_hp": int(hero["max_hp"]), "fray": int(hero["fray"])})
		if roster.size() == 4:
			roster.sort_custom(func(a, b): return int(a["position"]) < int(b["position"]))
			var authority := RunCampfireVisit.new(
				STITCHED_CAMPFIRE_NODE_ID, roster, RunCampfireVisit.STITCHED,
				stitched_roadblock_candle)
			var state: Dictionary = authority.read_state()
			if state.get("ok") == true and state.get("heroes") == roster \
					and state.get("status") == RunCampfireVisit.STITCHED_OPEN \
					and _stitched_campfire_held_fray_valid(roster):
				_stitched_campfire_roster = roster.duplicate(true)
				_stitched_campfire_authorized_roster = roster.duplicate(true)
				# Retain the FULL worn parts from the authenticated Circle Leave,
				# not the HP/FRAY-only roster the recovery service needs.
				_stitched_campfire_swap_roster = survivors.duplicate(true)
				_stitched_campfire_swap_roster.sort_custom(
					func(a, b): return int(a["rank"]) < int(b["rank"]))
				_stitched_campfire_swap_satchel = stitched_preview_satchel.duplicate(true)
				_stitched_campfire_swap_gear = _stitched_gear_overrides.duplicate(true)
	_stitched_postvictory_stop_available = not _stitched_campfire_roster.is_empty() \
		or not _stitched_peddler_roster.is_empty()
	_refresh_stitched_peddler_button()


## A detached roster must still match every HP ledger entry and the exact
## authenticated Circle receipt. It may not be rebuilt from title defaults.
func _stitched_campfire_living_roster() -> Array:
	if not _stitched_postvictory_stop_available \
			or _stitched_campfire_roster.size() != 4 \
			or _stitched_campfire_roster != _stitched_campfire_authorized_roster \
			or _stitched_party_picks.size() != 4:
		return []
	var ids := {}
	var roster: Array = []
	for hero_value in _stitched_campfire_roster:
		if not hero_value is Dictionary:
			return []
		var hero: Dictionary = hero_value
		var id := str(hero.get("id", ""))
		if id.is_empty() or ids.has(id) or not id in _stitched_party_picks \
				or typeof(hero.get("hp")) != TYPE_INT \
				or not _stitched_hp_carry.has(id) \
				or _stitched_hp_carry[id] != hero["hp"]:
			return []
		ids[id] = true
		roster.append(hero.duplicate(true))
	if ids.size() != 4 or not _stitched_campfire_held_fray_valid(roster):
		return []
	var visit := RunCampfireVisit.new(
		STITCHED_CAMPFIRE_NODE_ID, roster, RunCampfireVisit.STITCHED,
		stitched_roadblock_candle)
	if visit.read_state().get("ok") != true:
		return []
	return roster


## A fully detached, currently lawful rank roster (ranks 1..4, four living
## selected heroes and exactly the carried Bleed statuses), or [] to fail closed.
func _stitched_peddler_living_roster() -> Array:
	if _stitched_peddler_roster.size() != 4 or _stitched_party_picks.size() != 4:
		return []
	var ids := {}
	var ranks := {}
	var roster: Array = []
	for hero_raw in _stitched_peddler_roster:
		if not hero_raw is Dictionary:
			return []
		var hero: Dictionary = hero_raw
		var hero_id := str(hero.get("id", ""))
		var rank: Variant = hero.get("rank")
		if hero_id.is_empty() or not hero_id in _stitched_party_picks or ids.has(hero_id) \
				or not _stitched_hp_carry.has(hero_id) \
				or typeof(_stitched_hp_carry[hero_id]) != TYPE_INT \
				or int(_stitched_hp_carry[hero_id]) <= 0 \
				or typeof(rank) != TYPE_INT or int(rank) < 1 or int(rank) > 4 \
				or ranks.has(int(rank)):
			return []
		var statuses: Variant = hero.get("statuses")
		if not statuses is Dictionary:
			return []
		var carried := {}
		if _stitched_bleed_carry.has(hero_id):
			var bleed: Variant = _stitched_bleed_carry[hero_id]
			if typeof(bleed) != TYPE_INT or int(bleed) <= 0:
				return []
			carried["bleed"] = int(bleed)
		if statuses != carried:
			return []
		ids[hero_id] = true
		ranks[int(rank)] = true
		roster.append({"id": hero_id, "name": str(hero.get("name", hero_id)),
			"rank": int(rank), "statuses": carried})
	if ids.size() != 4 or ranks.size() != 4:
		return []
	roster.sort_custom(func(a, b): return int(a["rank"]) < int(b["rank"]))
	return roster


## Shows the title Peddler button only while a lawful earned roster waits, and
## keeps it inside the title's keyboard ring only at that moment.
func _refresh_stitched_peddler_button() -> void:
	if not is_instance_valid(stitched_peddler_button) or not is_instance_valid(stitched_campfire_button) \
			or not is_instance_valid(stitched_postevent_button):
		return
	var peddler_ready: bool = _stitched_postvictory_stop_available \
		and not _stitched_peddler_roster.is_empty() \
		and stitched_peddler_visit == null and stitched_peddler_candle_visit == null \
		and stitched_peddler_part_visit == null \
		and not is_instance_valid(stitched_peddler_panel) \
		and stitched_campfire_visit == null and not is_instance_valid(stitched_campfire_panel)
	var campfire_ready: bool = _stitched_postvictory_stop_available \
		and not _stitched_campfire_roster.is_empty() \
		and stitched_campfire_visit == null and not is_instance_valid(stitched_campfire_panel) \
		and stitched_peddler_visit == null and not is_instance_valid(stitched_peddler_panel)
	stitched_peddler_button.visible = peddler_ready
	stitched_peddler_button.disabled = not peddler_ready
	stitched_peddler_button.focus_mode = Control.FOCUS_ALL if peddler_ready else Control.FOCUS_NONE
	stitched_campfire_button.visible = campfire_ready
	stitched_campfire_button.disabled = not campfire_ready
	stitched_campfire_button.focus_mode = Control.FOCUS_ALL if campfire_ready else Control.FOCUS_NONE
	if not is_instance_valid(title_view) or not title_view.is_inside_tree() \
			or not is_instance_valid(base_button) or not is_instance_valid(start_button):
		return
	var event_ready: bool = _stitched_postvictory_stop_available \
		and not _stitched_campfire_roster.is_empty() \
		and stitched_postevent_visit == null and not is_instance_valid(stitched_postevent_panel) \
		and stitched_peddler_visit == null and not is_instance_valid(stitched_peddler_panel) \
		and stitched_campfire_visit == null and not is_instance_valid(stitched_campfire_panel)
	stitched_postevent_button.visible = event_ready
	stitched_postevent_button.disabled = not event_ready
	stitched_postevent_button.focus_mode = Control.FOCUS_ALL if event_ready else Control.FOCUS_NONE
	var unpicker_ready := _stitched_postvictory_stop_available \
		and stitched_unpicker_visit == null and not is_instance_valid(stitched_unpicker_panel) \
		and not _stitched_unpicker_earned.is_empty() \
		and _stitched_unpicker_live_context() == _stitched_unpicker_earned
	stitched_unpicker_button.visible = unpicker_ready
	stitched_unpicker_button.disabled = not unpicker_ready
	stitched_unpicker_button.focus_mode = Control.FOCUS_ALL if unpicker_ready else Control.FOCUS_NONE
	# Four earned stops still fit the 720px title and its keyboard ring.
	title_view.add_theme_constant_override("separation", 12 if _stitched_postvictory_stop_available else 32)
	title_view.reset_size()
	title_view.position = (get_viewport_rect().size - title_view.get_combined_minimum_size()) / 2.0
	_wire_stitched_title_focus()


## The title-accessible Peddler: one quoted bandage, candle stub or canonical
## spare, or a free Leave. Only an earned roster can open it.
func _open_stitched_peddler() -> bool:
	if stitched_unpicker_visit != null or is_instance_valid(stitched_unpicker_panel):
		return false
	if not _stitched_postvictory_stop_available \
			or is_instance_valid(stitched_campfire_panel) or stitched_campfire_visit != null \
			or is_instance_valid(stitched_peddler_panel) or stitched_peddler_visit != null \
			or stitched_peddler_candle_visit != null or stitched_peddler_part_visit != null \
			or stitched_postevent_visit != null or is_instance_valid(stitched_postevent_panel) \
			or is_instance_valid(stitched_event_panel) or stitched_event_gate != null \
			or is_instance_valid(stitched_fight_view) \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or stitched_sewing_mend_visit != null or stitched_sewing_upgrade_visit != null \
			or deck != null or run_map != null or run_rng != null \
			or is_instance_valid(base_screen) or is_instance_valid(party_picker) \
			or is_instance_valid(route_view) or is_instance_valid(route_atlas_overlay) \
			or is_instance_valid(battle_view) \
			or not is_instance_valid(title_view) or not title_view.is_visible_in_tree():
		return false
	var roster := _stitched_peddler_living_roster()
	if roster.is_empty():
		return false
	# The earned Peddler is a separate node. Reject malformed live candle
	# before admitting any service, without consuming the earned stop.
	if typeof(stitched_roadblock_candle) != TYPE_INT \
			or stitched_roadblock_candle < 0 \
			or stitched_roadblock_candle > RunPeddlerVisit.CANDLE_MAX:
		return false
	var projected_candle := maxi(0,
		stitched_roadblock_candle - STITCHED_ROADBLOCK_CANDLE_COST)
	var visit := RunStitchedPeddlerBandage.open_stitched(
		STITCHED_PEDDLER_NODE_ID, roster, stitched_preview_gold, STITCHED_PEDDLER_PRICE)
	if not visit.is_valid() or not visit.is_open():
		return false
	var quote := visit.read_state()
	if quote.get("ok") != true or quote.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or quote.get("status") != RunStitchedPeddlerBandage.OPEN \
			or int(quote.get("price", 0)) != STITCHED_PEDDLER_PRICE \
			or int(quote.get("gold", -1)) != stitched_preview_gold:
		return false
	# A distinct opt-in candle ledger shares this single earned Peddler
	# entrance and wallet, never the legacy run/shop economy.
	var candle_visit := RunPeddlerVisit.open_stitched_candle(
		STITCHED_PEDDLER_NODE_ID, projected_candle,
		stitched_preview_gold, STITCHED_PEDDLER_PRICE)
	if not candle_visit.is_valid() or not candle_visit.is_open():
		return false
	var candle_state: Dictionary = candle_visit.read_state()
	var candle_quote: Dictionary = candle_visit.quote()
	if candle_state.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or candle_state.get("status") != RunPeddlerVisit.STITCHED_OPEN \
			or candle_state.get("candle") != projected_candle \
			or candle_state.get("gold") != stitched_preview_gold \
			or candle_state.get("item", {}).get("price") != STITCHED_PEDDLER_PRICE \
			or candle_quote.get("ok") != true \
			or candle_quote.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or candle_quote.get("price") != STITCHED_PEDDLER_PRICE \
			or candle_quote.get("restore") != mini(RunPeddlerVisit.CANDLE_STUB_RESTORE,
				RunPeddlerVisit.CANDLE_MAX - projected_candle) \
			or candle_quote.get("choices", []) != (
				[RunPeddlerVisit.BUY_CANDLE_STUB, RunPeddlerVisit.STITCHED_LEAVE]
				if int(candle_quote.get("restore", 0)) > 0
				and stitched_preview_gold >= STITCHED_PEDDLER_PRICE
				else [RunPeddlerVisit.STITCHED_LEAVE]):
		return false
	# The spare-stock authority is the same validated part catalog used by
	# the real Roadblock and Sewing Circle, never a hand-built UI offer.
	var config := _stitched_floor_config()
	if config.is_empty():
		return false
	var catalog := StitchedParts.build_catalog(config["parts"])
	if catalog.get("ok") != true or not catalog.get("by_id", {}).has(STITCHED_PEDDLER_PART_ID):
		return false
	var part_visit := RunStitchedPeddlerPart.open_stitched(
		STITCHED_PEDDLER_NODE_ID, stitched_preview_gold, stitched_preview_satchel,
		catalog["by_id"], STITCHED_PEDDLER_PART_ID, STITCHED_PEDDLER_PRICE)
	if not part_visit.is_valid() or not part_visit.is_open():
		return false
	var part_state: Dictionary = part_visit.read_state()
	var part_quote: Dictionary = part_visit.quote()
	var offered: Dictionary = part_quote.get("offer", {})
	if part_quote.get("ok") != true or part_quote.get("state") != part_state \
			or part_quote.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or part_quote.get("price") != STITCHED_PEDDLER_PRICE \
			or part_quote.get("gold") != stitched_preview_gold \
			or part_quote.get("satchel_count") != stitched_preview_satchel.size() \
			or part_quote.get("satchel_max") != RunStitchedPeddlerPart.SATCHEL_CAP \
			or part_quote.get("choices") != (
				[RunStitchedPeddlerPart.DECISION_BUY, RunStitchedPeddlerPart.DECISION_LEAVE]
				if part_quote.get("can_buy") == true else [RunStitchedPeddlerPart.DECISION_LEAVE]) \
			or part_state.get("satchel")!= stitched_preview_satchel \
			or part_state.get("status") != RunStitchedPeddlerPart.STATUS_OPEN \
			or offered.get("id") != STITCHED_PEDDLER_PART_ID \
			or offered.get("name") != "Helmet Rattle" \
			or offered.get("tier") != 1 or offered.get("torn") != false:
		return false
	var generation := _stitched_peddler_generation + 1
	var built := _mount_stitched_peddler(
		visit, quote, candle_state, candle_quote, part_state, part_quote, generation)
	var panel: Control = built.get("panel")
	if panel == null:
		return false
	# All three displayed ledgers belong to one exact panel generation.
	stitched_peddler_visit = visit
	stitched_peddler_candle_visit = candle_visit
	stitched_peddler_part_visit = part_visit
	stitched_peddler_panel = panel
	_stitched_peddler_quote = quote.duplicate(true)
	_stitched_peddler_candle_state = candle_state.duplicate(true)
	_stitched_peddler_candle_quote = candle_quote.duplicate(true)
	_stitched_peddler_part_state = part_state.duplicate(true)
	_stitched_peddler_part_quote = part_quote.duplicate(true)
	_stitched_peddler_generation = generation
	# Selection consumes the common earned stop, not just a purchase/Leave.
	_stitched_postvictory_stop_available = false
	_stitched_campfire_roster.clear()
	_stitched_campfire_swap_roster.clear()
	_stitched_campfire_swap_satchel.clear()
	_stitched_campfire_swap_gear.clear()
	_refresh_stitched_peddler_button()
	# All three quotes and the real panel are authoritative; debit once here,
	# before any mounted button can receive an input callback.
	stitched_roadblock_candle = projected_candle
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_view.hide()
	var first: Button = built.get("first")
	if first != null and is_instance_valid(first) and not first.disabled:
		first.grab_focus()
	else:
		panel.grab_focus()
	return true


## Gothic-themed visit board. Framing is shipped textile art; only the existing
## theme supplies button chrome, so nothing is drawn in code.
func _mount_stitched_peddler(visit: RunStitchedPeddlerBandage,
		quote: Dictionary, candle_state: Dictionary, candle_quote: Dictionary,
		part_state: Dictionary, part_quote: Dictionary, generation: int) -> Dictionary:
	if not visit.is_valid() or not visit.is_open() \
			or candle_state.get("ok") != true or candle_quote.get("ok") != true \
			or part_state.get("ok") != true or part_quote.get("ok") != true:
		return {}
	var panel := Control.new()
	panel.name = "StitchedPeddler"
	panel.set_meta("peddler_generation", generation)
	panel.theme = load("res://themes/gothic_theme.tres")
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.focus_mode = Control.FOCUS_ALL
	var frame := NinePatchRect.new()
	frame.name = "PeddlerFrame"
	var art_path := "res://assets/paper/ui/panel_felt.png"
	if ResourceLoader.exists(art_path, "Texture2D"):
		frame.texture = load(art_path)
		frame.patch_margin_left = 24
		frame.patch_margin_right = 24
		frame.patch_margin_top = 24
		frame.patch_margin_bottom = 24
	frame.position = Vector2(120, 40)
	frame.size = Vector2(1040, 640)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	var heading := Label.new()
	heading.text = "STITCHED PEDDLER  ·  BANDAGES, CANDLE & SPARE PART"
	heading.position = Vector2(165, 78)
	heading.size = Vector2(960, 54)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 27)
	panel.add_child(heading)
	var description := Label.new()
	description.text = "Choose one: cure Bleed with a bandage, restore up to 25 light with a candle stub, or buy an untorn tier-I Helmet Rattle spare."
	description.position = Vector2(170, 143)
	description.size = Vector2(950, 64)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(description)
	var wallet := Label.new()
	wallet.name = "PeddlerQuote"
	wallet.text = "PREVIEW GOLD  %d    ·    EACH OFFER  %d    ·    LEAVE FREE" % [
		int(quote["gold"]), int(quote["price"])]
	wallet.position = Vector2(183, 212)
	wallet.size = Vector2(910, 36)
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(wallet)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(180, 266)
	scroll.size = Vector2(920, 270)
	panel.add_child(scroll)
	var offers := VBoxContainer.new()
	offers.custom_minimum_size.x = 890
	offers.add_theme_constant_override("separation", 10)
	scroll.add_child(offers)
	var state: Dictionary = quote.duplicate(true)
	var first: Button = null
	var bleeding := 0
	for hero_row in quote["heroes"]:
		var hero_id := str(hero_row["id"])
		var hero_name := str(hero_row.get("name", hero_id))
		var statuses: Dictionary = hero_row["statuses"]
		var bleed := int(statuses.get("bleed", 0))
		var eligible: bool = bleed > 0 and hero_id in quote["eligible"]
		if eligible:
			bleeding += 1
		var affordable: bool = int(quote["gold"]) >= int(quote["price"])
		var button := Button.new()
		button.name = "Bandage_" + hero_id
		button.custom_minimum_size = Vector2(850, 52)
		button.disabled = not eligible or not affordable
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		if eligible:
			button.text = "Bandage %d %s · cures Bleed %d · %d gold" % [
				int(hero_row["rank"]), hero_name, bleed, int(quote["price"])]
			button.tooltip_text = "Spend %d preview gold to cure only %s's Bleed" % [
				int(quote["price"]), hero_name]
		else:
			button.text = "%d %s · not bleeding" % [int(hero_row["rank"]), hero_name]
			button.tooltip_text = "Only a hero carrying Bleed can wear a bandage"
		if eligible and not affordable:
			button.text = "Bandage %d %s · needs %d gold" % [
				int(hero_row["rank"]), hero_name, int(quote["price"])]
			button.tooltip_text = "The quote is %d preview gold; this hero keeps the Bleed" % int(
				quote["price"])
		button.pressed.connect(_stitched_peddler_buy.bind(
			hero_id, state.duplicate(true), weakref(panel)))
		offers.add_child(button)
		if not button.disabled and first == null:
			first = button
	if bleeding == 0:
		var empty := Label.new()
		empty.text = "No survivor is bleeding. Candle stubs and spare parts remain available."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		offers.add_child(empty)
	var candle_button := Button.new()
	candle_button.name = "PeddlerCandleStub"
	candle_button.custom_minimum_size = Vector2(850, 56)
	var candle_now := int(candle_state["candle"])
	var candle_gain := mini(RunPeddlerVisit.CANDLE_STUB_RESTORE,
		RunPeddlerVisit.CANDLE_MAX - candle_now)
	var candle_affordable := int(candle_quote["gold"]) >= int(candle_quote["price"])
	candle_button.disabled = candle_gain <= 0 or not candle_affordable
	candle_button.focus_mode = Control.FOCUS_NONE if candle_button.disabled \
		else Control.FOCUS_ALL
	candle_button.text = "Candle stub · +%d CANDLE (to %d / 100) · %d gold" % [
		candle_gain, candle_now + candle_gain, int(candle_quote["price"])]
	if candle_gain == 0:
		candle_button.text = "Candle full (100 / 100) · no stub needed"
	elif not candle_affordable:
		candle_button.text = "Candle stub · needs %d gold" % int(candle_quote["price"])
	candle_button.tooltip_text = "Buy a candle stub instead of a bandage; +25 CANDLE, capped at 100"
	candle_button.pressed.connect(_stitched_peddler_buy_candle.bind(
		state.duplicate(true), candle_state.duplicate(true),
		candle_quote.duplicate(true), weakref(panel), generation))
	offers.add_child(candle_button)
	if first == null and not candle_button.disabled:
		first = candle_button
	var part_offer: Dictionary = part_quote["offer"]
	var part_button := Button.new()
	part_button.name = "PeddlerHelmetRattle"
	part_button.custom_minimum_size = Vector2(850, 56)
	part_button.disabled = not bool(part_quote["can_buy"])
	part_button.focus_mode = Control.FOCUS_NONE if part_button.disabled else Control.FOCUS_ALL
	part_button.text = "%s · tier %d %s spare · %d gold" % [
		str(part_offer["name"]), int(part_offer["tier"]), str(part_offer["slot"]),
		int(part_quote["price"])]
	if part_button.disabled:
		part_button.text += " · " + str(part_quote["blocked"])
	part_button.tooltip_text = "Buy one canonical untorn %s part for the Sewing Circle" % str(
		part_offer["name"])
	part_button.pressed.connect(_stitched_peddler_buy_part.bind(
		state.duplicate(true), candle_state.duplicate(true), candle_quote.duplicate(true),
		part_state.duplicate(true), part_quote.duplicate(true), weakref(panel), generation))
	offers.add_child(part_button)
	if first == null and not part_button.disabled:
		first = part_button
	var leave_button := Button.new()
	leave_button.name = "PeddlerLeave"
	leave_button.text = "Leave the Peddler · free"
	leave_button.position = Vector2(405, 570)
	leave_button.size = Vector2(470, 54)
	leave_button.pressed.connect(_stitched_peddler_leave.bind(
		state.duplicate(true), weakref(panel)))
	panel.add_child(leave_button)
	if first == null:
		first = leave_button
	return {"panel": panel, "first": first}


## Buys exactly one quoted bandage for one eligible hero and closes the visit.
## A stale, forged, duplicated or unaffordable request changes nothing.
func _stitched_peddler_buy(hero_id: String, expected_snapshot: Dictionary,
		source: WeakRef) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	if panel == null or panel != stitched_peddler_panel \
			or not is_instance_valid(panel) or not panel.is_visible_in_tree() \
			or stitched_peddler_visit == null \
			or is_instance_valid(stitched_fight_view) \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or _stitched_peddler_quote != expected_snapshot \
			or not hero_id in expected_snapshot.get("eligible", []):
		return {"ok": false, "error": "stale Peddler bandage"}
	if int(expected_snapshot.get("price", 0)) != STITCHED_PEDDLER_PRICE \
			or int(expected_snapshot.get("gold", -1)) != stitched_preview_gold \
			or stitched_preview_gold < STITCHED_PEDDLER_PRICE:
		return {"ok": false, "error": "unaffordable Peddler bandage"}
	var expected_heroes: Array = expected_snapshot.get("heroes", []).duplicate(true)
	var matched := false
	for hero in expected_heroes:
		if str(hero.get("id", "")) != hero_id:
			continue
		var statuses: Variant = hero.get("statuses")
		if not statuses is Dictionary or int((statuses as Dictionary).get("bleed", 0)) <= 0:
			return {"ok": false, "error": "the hero is not bleeding"}
		(statuses as Dictionary).erase("bleed")
		matched = true
	if not matched:
		return {"ok": false, "error": "unknown Peddler hero"}
	var receipt: Dictionary = stitched_peddler_visit.choose_bandage(
		hero_id, STITCHED_PEDDLER_NODE_ID, expected_snapshot)
	if receipt.get("ok") != true \
			or receipt.get("decision") != RunStitchedPeddlerBandage.BUY_BANDAGE \
			or receipt.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or receipt.get("hero_id") != hero_id \
			or int(receipt.get("price", 0)) != STITCHED_PEDDLER_PRICE \
			or int(receipt.get("charged_gold", 0)) != STITCHED_PEDDLER_PRICE \
			or int(receipt.get("gold", -1)) != stitched_preview_gold - STITCHED_PEDDLER_PRICE \
			or receipt.get("heroes") != expected_heroes:
		return {"ok": false, "error": "Peddler bandage receipt rejected"}
	stitched_preview_gold = int(receipt["gold"])
	# Only the chosen hero's carried Bleed is cured. HP, equipment, satchel,
	# scraps and candle belong to other owners and stay untouched.
	_stitched_bleed_carry.erase(hero_id)
	_stitched_peddler_roster.clear()
	_close_stitched_peddler()
	return receipt


## One mutually exclusive candle-stub purchase from the exact on-screen visit.
## Check the complete displayed bandage and candle ledgers, this panel's own
## generation and the current earned living party before accepting any debit.
func _stitched_peddler_buy_candle(expected_bandage: Dictionary,
		expected_candle: Dictionary, expected_quote: Dictionary,
		source: WeakRef, generation: int) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	if panel == null or not is_instance_valid(panel) or panel != stitched_peddler_panel \
			or not panel.is_visible_in_tree() \
			or generation != _stitched_peddler_generation \
			or panel.get_meta("peddler_generation", -1) != generation \
			or stitched_peddler_visit == null or not stitched_peddler_visit.is_open() \
			or stitched_peddler_candle_visit == null \
			or not stitched_peddler_candle_visit.is_open() \
			or is_instance_valid(stitched_fight_view) \
			or is_instance_valid(stitched_event_panel) or stitched_event_gate != null \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or _stitched_peddler_quote != expected_bandage \
			or stitched_peddler_visit.read_state() != expected_bandage \
			or _stitched_peddler_candle_state != expected_candle \
			or _stitched_peddler_candle_quote != expected_quote \
			or stitched_peddler_candle_visit.read_state() != expected_candle \
			or stitched_peddler_candle_visit.quote() != expected_quote:
		return {"ok": false, "error": "stale Peddler candle"}
	var roster := _stitched_peddler_living_roster()
	if roster.size() != 4 or roster != expected_bandage.get("heroes", []) \
			or expected_bandage.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or expected_bandage.get("status") != RunStitchedPeddlerBandage.OPEN \
			or expected_bandage.get("gold") != stitched_preview_gold \
			or expected_bandage.get("price") != STITCHED_PEDDLER_PRICE \
			or expected_candle.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or expected_candle.get("status") != RunPeddlerVisit.STITCHED_OPEN \
			or expected_candle.get("gold") != stitched_preview_gold \
			or expected_candle.get("candle") != stitched_roadblock_candle \
			or expected_candle.get("item", {}).get("price") != STITCHED_PEDDLER_PRICE \
			or expected_quote.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or expected_quote.get("item") != RunPeddlerVisit.CANDLE_STUB \
			or expected_quote.get("candle") != stitched_roadblock_candle \
			or expected_quote.get("gold") != stitched_preview_gold \
			or expected_quote.get("price") != STITCHED_PEDDLER_PRICE \
			or expected_quote.get("restore") != mini(RunPeddlerVisit.CANDLE_STUB_RESTORE,
				RunPeddlerVisit.CANDLE_MAX - stitched_roadblock_candle) \
			or stitched_preview_gold < STITCHED_PEDDLER_PRICE \
			or stitched_roadblock_candle >= RunPeddlerVisit.CANDLE_MAX:
		return {"ok": false, "error": "unauthorized Peddler candle"}
	var before: int = stitched_roadblock_candle
	var before_gold := stitched_preview_gold
	var after := mini(RunPeddlerVisit.CANDLE_MAX,
		before + RunPeddlerVisit.CANDLE_STUB_RESTORE)
	var receipt: Dictionary = stitched_peddler_candle_visit.select_stitched(
		RunPeddlerVisit.BUY_CANDLE_STUB, STITCHED_PEDDLER_NODE_ID,
		stitched_peddler_candle_visit.read_state())
	if receipt.get("ok") != true \
			or receipt.get("decision") != RunPeddlerVisit.BUY_CANDLE_STUB \
			or receipt.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or receipt.get("mode") != RunPeddlerVisit.STITCHED \
			or receipt.get("item") != RunPeddlerVisit.CANDLE_STUB \
			or receipt.get("status") != RunPeddlerVisit.STITCHED_USED \
			or receipt.get("consumed") != true \
			or receipt.get("price") != STITCHED_PEDDLER_PRICE \
			or receipt.get("charged_gold") != STITCHED_PEDDLER_PRICE \
			or receipt.get("gold") != before_gold - STITCHED_PEDDLER_PRICE \
			or receipt.get("candle_before") != before \
			or receipt.get("candle") != after \
			or receipt.get("restored") != after - before \
			or receipt.get("state") != stitched_peddler_candle_visit.read_state() \
			or not stitched_peddler_candle_visit.is_consumed():
		return {"ok": false, "error": "Peddler candle receipt rejected"}
	# Retire the other service before publishing the accepted candle receipt.
	var bandage_left: Dictionary = stitched_peddler_visit.leave(
		STITCHED_PEDDLER_NODE_ID, expected_bandage)
	if bandage_left.get("ok") != true \
			or bandage_left.get("decision") != RunStitchedPeddlerBandage.LEAVE \
			or bandage_left.get("charged_gold") != 0 \
			or bandage_left.get("gold") != before_gold \
			or bandage_left.get("heroes") != roster:
		return {"ok": false, "error": "Peddler alternative did not retire"}
	stitched_preview_gold = int(receipt["gold"])
	stitched_roadblock_candle = int(receipt["candle"])
	_stitched_peddler_roster.clear()
	_close_stitched_peddler()
	return receipt


## One canonical spare purchase competes with the bandage and candle for the
## same earned panel. Every displayed quote, service, ledger and live hero must
## still agree before this one-use receipt may debit the preview wallet.
func _stitched_peddler_buy_part(expected_bandage: Dictionary,
		expected_candle: Dictionary, expected_candle_quote: Dictionary,
		expected_part: Dictionary, expected_part_quote: Dictionary,
		source: WeakRef, generation: int) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	if panel == null or not is_instance_valid(panel) or panel != stitched_peddler_panel \
			or not panel.is_visible_in_tree() \
			or generation != _stitched_peddler_generation \
			or panel.get_meta("peddler_generation", -1) != generation \
			or stitched_peddler_visit == null or not stitched_peddler_visit.is_open() \
			or stitched_peddler_candle_visit == null \
			or not stitched_peddler_candle_visit.is_open() \
			or stitched_peddler_part_visit == null \
			or not stitched_peddler_part_visit.is_open() \
			or is_instance_valid(stitched_fight_view) \
			or is_instance_valid(stitched_event_panel) or stitched_event_gate != null \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or _stitched_peddler_quote != expected_bandage \
			or _stitched_peddler_candle_state != expected_candle \
			or _stitched_peddler_candle_quote != expected_candle_quote \
			or _stitched_peddler_part_state != expected_part \
			or _stitched_peddler_part_quote != expected_part_quote \
			or stitched_peddler_visit.read_state() != expected_bandage \
			or stitched_peddler_candle_visit.read_state() != expected_candle \
			or stitched_peddler_candle_visit.quote() != expected_candle_quote \
			or stitched_peddler_part_visit.read_state() != expected_part \
			or stitched_peddler_part_visit.quote() != expected_part_quote:
		return {"ok": false, "error": "stale Peddler spare"}
	var living := _stitched_peddler_living_roster()
	if living.size() != 4 or living != expected_bandage.get("heroes", []) \
			or expected_bandage.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or expected_bandage.get("status") != RunStitchedPeddlerBandage.OPEN \
			or expected_bandage.get("gold") != stitched_preview_gold \
			or expected_bandage.get("price") != STITCHED_PEDDLER_PRICE \
			or expected_candle.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or expected_candle.get("status") != RunPeddlerVisit.STITCHED_OPEN \
			or expected_candle.get("gold") != stitched_preview_gold \
			or expected_candle.get("candle") != stitched_roadblock_candle \
			or expected_candle.get("item", {}).get("price") != STITCHED_PEDDLER_PRICE \
			or expected_candle_quote.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or expected_candle_quote.get("item") != RunPeddlerVisit.CANDLE_STUB \
			or expected_candle_quote.get("price") != STITCHED_PEDDLER_PRICE \
			or expected_candle_quote.get("gold") != stitched_preview_gold \
			or expected_candle_quote.get("candle") != stitched_roadblock_candle \
			or expected_part.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or expected_part.get("status") != RunStitchedPeddlerPart.STATUS_OPEN \
			or expected_part.get("gold") != stitched_preview_gold \
			or expected_part.get("satchel") != stitched_preview_satchel \
			or expected_part_quote.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or expected_part_quote.get("state") != expected_part \
			or expected_part_quote.get("price") != STITCHED_PEDDLER_PRICE \
			or expected_part_quote.get("gold") != stitched_preview_gold \
			or expected_part_quote.get("satchel_count") != stitched_preview_satchel.size() \
			or expected_part_quote.get("satchel_max") != RunStitchedPeddlerPart.SATCHEL_CAP \
			or expected_part_quote.get("can_buy") != true \
			or expected_part_quote.get("blocked") != "" \
			or expected_part_quote.get("choices") != [
				RunStitchedPeddlerPart.DECISION_BUY, RunStitchedPeddlerPart.DECISION_LEAVE] \
			or expected_part_quote.get("offer", {}).get("id") != STITCHED_PEDDLER_PART_ID \
			or expected_part_quote.get("offer", {}).get("name") != "Helmet Rattle" \
			or expected_part_quote.get("offer", {}).get("tier") != 1 \
			or expected_part_quote.get("offer", {}).get("torn") != false \
			or stitched_preview_gold < STITCHED_PEDDLER_PRICE:
		return {"ok": false, "error": "unauthorized Peddler spare"}
	var before_gold := stitched_preview_gold
	var before_satchel := stitched_preview_satchel.duplicate(true)
	var wanted := {"id": STITCHED_PEDDLER_PART_ID, "slot": "head",
		"tier": 1, "torn": false}
	var expected_after := before_satchel.duplicate(true)
	expected_after.append(wanted)
	var receipt: Dictionary = stitched_peddler_part_visit.buy(
		STITCHED_PEDDLER_NODE_ID, expected_part)
	if receipt.get("ok") != true \
			or receipt.get("decision") != RunStitchedPeddlerPart.DECISION_BUY \
			or receipt.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or receipt.get("price") != STITCHED_PEDDLER_PRICE \
			or receipt.get("charged_gold") != STITCHED_PEDDLER_PRICE \
			or receipt.get("gold_before") != before_gold \
			or receipt.get("gold") != before_gold - STITCHED_PEDDLER_PRICE \
			or receipt.get("part") != wanted \
			or receipt.get("satchel_index") != before_satchel.size() \
			or receipt.get("satchel") != expected_after \
			or receipt.get("source_state") != expected_part \
			or receipt.get("status") != RunStitchedPeddlerPart.STATUS_BOUGHT \
			or receipt.get("state") != stitched_peddler_part_visit.read_state() \
			or receipt.get("state", {}).get("satchel") != expected_after \
			or receipt.get("state", {}).get("gold") != before_gold - STITCHED_PEDDLER_PRICE \
			or not stitched_peddler_part_visit.is_consumed():
		return {"ok": false, "error": "Peddler spare receipt rejected"}
	# Commit only the new spare and debit. The common teardown retires both
	# other offers, so no old focused button can charge or cure afterward.
	stitched_preview_gold = int(receipt["gold"])
	stitched_preview_satchel = receipt["satchel"].duplicate(true)
	_stitched_peddler_roster.clear()
	_close_stitched_peddler()
	return receipt


## Leaves the Peddler for free, preserving every carried status and resource.
func _stitched_peddler_leave(expected_snapshot: Dictionary, source: WeakRef) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	if panel == null or panel != stitched_peddler_panel \
			or not is_instance_valid(panel) or not panel.is_visible_in_tree() \
			or stitched_peddler_visit == null \
			or is_instance_valid(stitched_fight_view) \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or _stitched_peddler_quote != expected_snapshot:
		return {"ok": false, "error": "stale Peddler"}
	var receipt: Dictionary = stitched_peddler_visit.leave(
		STITCHED_PEDDLER_NODE_ID, expected_snapshot)
	if receipt.get("ok") != true \
			or receipt.get("decision") != RunStitchedPeddlerBandage.LEAVE \
			or receipt.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or int(receipt.get("charged_gold", 1)) != 0 \
			or int(receipt.get("gold", -1)) != stitched_preview_gold \
			or receipt.get("heroes") != expected_snapshot.get("heroes", []):
		return {"ok": false, "error": "Peddler Leave receipt rejected"}
	_stitched_peddler_roster.clear()
	_close_stitched_peddler()
	return receipt


func _close_stitched_peddler() -> void:
	var panel := stitched_peddler_panel
	# Every exit retires all three one-use ledgers; neither an old bandage nor an
	# old candle button may later spend from a superseded panel.
	if stitched_peddler_visit != null and stitched_peddler_visit.is_open():
		stitched_peddler_visit.leave(STITCHED_PEDDLER_NODE_ID,
			stitched_peddler_visit.read_state())
	if stitched_peddler_candle_visit != null:
		stitched_peddler_candle_visit.close()
	if stitched_peddler_part_visit != null and stitched_peddler_part_visit.is_open():
		stitched_peddler_part_visit.leave(STITCHED_PEDDLER_NODE_ID,
			stitched_peddler_part_visit.read_state())
	# Retire app authority before removing controls; queued input is then inert.
	stitched_peddler_panel = null
	stitched_peddler_visit = null
	stitched_peddler_candle_visit = null
	stitched_peddler_part_visit = null
	_stitched_peddler_quote.clear()
	_stitched_peddler_candle_state.clear()
	_stitched_peddler_candle_quote.clear()
	_stitched_peddler_part_state.clear()
	_stitched_peddler_part_quote.clear()
	_stitched_peddler_generation += 1
	if is_instance_valid(panel):
		if panel.get_parent() == self:
			remove_child(panel)
		panel.queue_free()
	if is_instance_valid(title_view):
		title_view.show()
	_refresh_stitched_peddler_button()
	_focus_stitched_title.call_deferred(stitched_peddler_button)


## The authenticated Circle's full carry remains the authority even though the
## Unpicker service itself needs only ranked FRAY heroes and a spare wallet.
func _stitched_unpicker_live_context() -> Dictionary:
	var roster := _stitched_campfire_authorized_roster
	if not _stitched_party_locked or roster.size() != 4 \
			or _stitched_postevent_build_snapshot(roster).is_empty() \
			or _stitched_peddler_living_roster().size() != 4:
		return {}
	var config := _stitched_floor_config()
	if config.is_empty() or _stitched_campfire_swap_roster.size() != 4 \
			or _stitched_campfire_swap_satchel != stitched_preview_satchel \
			or _stitched_campfire_swap_gear != _stitched_gear_overrides:
		return {}
	var catalog := StitchedParts.build_catalog(config["parts"])
	if catalog.get("ok") != true:
		return {}
	var parts := RunStitchedSewingSwap.new(STITCHED_UNPICKER_NODE_ID,
		_stitched_campfire_swap_roster, stitched_preview_satchel, catalog["by_id"])
	if parts.read_state().get("ok") != true:
		return {}
	return {"heroes": roster.duplicate(true), "parts": _stitched_campfire_swap_roster.duplicate(true),
		"gear": _stitched_gear_overrides.duplicate(true), "satchel": stitched_preview_satchel.duplicate(true),
		"gold": stitched_preview_gold, "scraps": stitched_preview_scraps,
		"bleed": _stitched_bleed_carry.duplicate(true), "fray": _stitched_fray_carry.duplicate(true),
		"party": _stitched_party_receipt.duplicate(true)}


func _open_stitched_unpicker() -> bool:
	if not _stitched_postvictory_stop_available or _stitched_unpicker_earned.is_empty() \
			or stitched_unpicker_visit != null or is_instance_valid(stitched_unpicker_panel) \
			or stitched_peddler_visit != null or is_instance_valid(stitched_peddler_panel) \
			or stitched_campfire_visit != null or is_instance_valid(stitched_campfire_panel) \
			or stitched_postevent_visit != null or is_instance_valid(stitched_postevent_panel) \
			or is_instance_valid(stitched_event_panel) or stitched_event_gate != null \
			or is_instance_valid(stitched_fight_view) or is_instance_valid(stitched_sewing_panel) \
			or stitched_sewing_visit != null or stitched_sewing_mend_visit != null \
			or stitched_sewing_upgrade_visit != null or deck != null or run_map != null or run_rng != null \
			or is_instance_valid(base_screen) or is_instance_valid(party_picker) \
			or is_instance_valid(route_view) or is_instance_valid(route_atlas_overlay) \
			or is_instance_valid(battle_view) or not is_instance_valid(title_view) \
			or not title_view.is_visible_in_tree():
		return false
	var context := _stitched_unpicker_live_context()
	if context.is_empty() or context != _stitched_unpicker_earned:
		return false
	var visit := RunStitchedInkblackUnpickerEvent.new(RunStitchedInkblackUnpickerEvent.EVENT_ID,
		STITCHED_UNPICKER_NODE_ID, context["heroes"], stitched_preview_satchel,
		{"gold": stitched_preview_gold, "scraps": stitched_preview_scraps}, 75, 2)
	var state := visit.read_state()
	var quote := visit.quote()
	if not visit.is_valid() or quote.get("ok") != true:
		return false
	var candle := maxi(0, int(stitched_roadblock_candle) - STITCHED_ROADBLOCK_CANDLE_COST)
	var generation := _stitched_unpicker_generation + 1
	var built := _mount_stitched_unpicker(quote, candle, generation)
	var panel: Control = built.get("panel")
	if not is_instance_valid(panel):
		return false
	add_child(panel)
	if panel.get_parent() != self or not panel.is_inside_tree() \
			or _stitched_unpicker_live_context() != context \
			or not _stitched_postvictory_stop_available or not _stitched_unpicker_screens_clear():
		panel.queue_free()
		return false
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stitched_unpicker_event = visit
	stitched_unpicker_panel = panel
	_stitched_unpicker_state = state.duplicate(true)
	_stitched_unpicker_quote = quote.duplicate(true)
	_stitched_unpicker_context = context.duplicate(true)
	_stitched_unpicker_context["candle"] = candle
	_stitched_unpicker_generation = generation
	stitched_roadblock_candle = candle
	_stitched_postvictory_stop_available = false
	_stitched_unpicker_earned.clear()
	_refresh_stitched_peddler_button()
	title_view.hide()
	var first: Button = built["first"]
	first.grab_focus()
	return true


## Mount the prospective service before claiming Hire. A failed mount leaves the
## original Event and its complete wallet quote available for another decision.
func _stitched_unpicker_event_choose(choice: String, expected: Dictionary,
		source: WeakRef, generation: int) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	var context := _stitched_unpicker_live_context()
	var live_context := context.duplicate(true)
	context["candle"] = stitched_roadblock_candle
	if not is_instance_valid(panel) or panel != stitched_unpicker_panel \
			or panel.get_parent() != self or not panel.is_visible_in_tree() \
			or generation != _stitched_unpicker_generation or stitched_unpicker_event == null \
			or stitched_unpicker_visit != null or expected != _stitched_unpicker_state \
			or stitched_unpicker_event.read_state() != expected \
			or stitched_unpicker_event.quote() != _stitched_unpicker_quote \
			or expected.get("node_id") != STITCHED_UNPICKER_NODE_ID \
			or context != _stitched_unpicker_context \
			or not _stitched_unpicker_screens_clear():
		return {"ok": false}
	var selected: Dictionary = {}
	for row: Dictionary in stitched_unpicker_event.quote().get("choices", []):
		if row.get("choice_id") == choice and row.get("available") == true:
			selected = row
	if selected.is_empty():
		return {"ok": false}
	var pending: RunUnpickerVisit
	var built: Dictionary = {}
	var next_generation := generation + 1
	if choice == RunStitchedInkblackUnpickerEvent.SERVICE_CHOICE_ID:
		pending = RunUnpickerVisit.open_stitched(STITCHED_UNPICKER_NODE_ID,
			expected["heroes"], selected["wallet"]["gold"], expected["quoted_calm_price"],
			expected["satchel"], selected["wallet"]["scraps"], expected["quoted_scrap_yield"])
		if not pending.is_valid():
			return {"ok": false}
		built = _mount_stitched_unpicker(pending.quote(), stitched_roadblock_candle, next_generation)
		var mounted: Control = built.get("panel")
		if not is_instance_valid(mounted):
			return {"ok": false}
		add_child(mounted)
		if mounted.get_parent() != self or not mounted.is_inside_tree() \
				or _stitched_unpicker_live_context() != live_context \
				or stitched_roadblock_candle != context["candle"] \
				or not _stitched_unpicker_screens_clear():
			mounted.queue_free()
			return {"ok": false}
		mounted.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var receipt := stitched_unpicker_event.choose(choice, STITCHED_UNPICKER_NODE_ID, expected)
	if receipt.get("ok") != true:
		if is_instance_valid(built.get("panel")):
			built["panel"].queue_free()
		return {"ok": false}
	_stitched_unpicker_event_receipt = receipt.duplicate(true)
	stitched_preview_gold = receipt["wallet"]["gold"]
	stitched_preview_scraps = receipt["wallet"]["scraps"]
	if pending == null:
		_close_stitched_unpicker()
	else:
		remove_child(panel)
		panel.queue_free()
		stitched_unpicker_panel = built["panel"]
		stitched_unpicker_visit = pending
		_stitched_unpicker_state = pending.read_state().duplicate(true)
		_stitched_unpicker_quote = pending.quote().duplicate(true)
		_stitched_unpicker_context = _stitched_unpicker_live_context()
		_stitched_unpicker_context["candle"] = stitched_roadblock_candle
		_stitched_unpicker_generation = next_generation
		built["first"].grab_focus()
	return receipt


func _stitched_unpicker_screens_clear() -> bool:
	return stitched_peddler_visit == null and not is_instance_valid(stitched_peddler_panel) \
		and stitched_campfire_visit == null and not is_instance_valid(stitched_campfire_panel) \
		and stitched_postevent_visit == null and not is_instance_valid(stitched_postevent_panel) \
		and not is_instance_valid(stitched_event_panel) and stitched_event_gate == null \
		and not is_instance_valid(stitched_fight_view) and not is_instance_valid(stitched_sewing_panel) \
		and stitched_sewing_visit == null and stitched_sewing_mend_visit == null \
		and stitched_sewing_upgrade_visit == null and deck == null and run_map == null and run_rng == null \
		and not is_instance_valid(base_screen) and not is_instance_valid(party_picker) \
		and not is_instance_valid(route_view) and not is_instance_valid(route_atlas_overlay) \
		and not is_instance_valid(battle_view)


func _stitched_campfire_event_screens_clear() -> bool:
	return stitched_peddler_visit == null and not is_instance_valid(stitched_peddler_panel) \
		and stitched_unpicker_visit == null and not is_instance_valid(stitched_unpicker_panel) \
		and stitched_postevent_visit == null and not is_instance_valid(stitched_postevent_panel) \
		and not is_instance_valid(stitched_event_panel) and stitched_event_gate == null \
		and not is_instance_valid(stitched_fight_view) and not is_instance_valid(stitched_sewing_panel) \
		and stitched_sewing_visit == null and stitched_sewing_mend_visit == null \
		and stitched_sewing_upgrade_visit == null and deck == null and run_map == null and run_rng == null \
		and not is_instance_valid(base_screen) and not is_instance_valid(party_picker) \
		and not is_instance_valid(route_view) and not is_instance_valid(route_atlas_overlay) \
		and not is_instance_valid(battle_view)


func _mount_stitched_unpicker(quote: Dictionary, candle: int, generation: int) -> Dictionary:
	var panel := Control.new()
	panel.name = "StitchedUnpicker"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var frame := NinePatchRect.new()
	frame.name = "UnpickerFrame"
	var art_path := "res://assets/paper/ui/panel_felt.png"
	frame.set_meta("art_path", art_path)
	if ResourceLoader.exists(art_path, "Texture2D"):
		frame.texture = load(art_path)
	frame.patch_margin_left = 24
	frame.patch_margin_right = 24
	frame.patch_margin_top = 24
	frame.patch_margin_bottom = 24
	frame.position = Vector2(120, 40)
	frame.size = Vector2(1040, 640)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	var heading := Label.new()
	heading.name = "UnpickerHeading"
	var event_mode: bool = quote.has("state")
	heading.text = "STITCHED UNPICKER\nCANDLELIGHT  %d / 100\nChoose one service" % candle
	if event_mode:
		var record := RunV3ServiceWaystationEventGate.new().get_event_record(RunStitchedInkblackUnpickerEvent.EVENT_ID)
		heading.text = "%s\nCANDLELIGHT %d / 100  ·  GOLD %d  ·  SCRAPS %d\n%s" % [
			record["title"], candle, quote["state"]["wallet"]["gold"],
			quote["state"]["wallet"]["scraps"], record["description"]]
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.position = Vector2(180, 65)
	heading.size = Vector2(920, 190 if event_mode else 110)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	panel.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(210, 280 if event_mode else 190)
	scroll.size = Vector2(860, 340 if event_mode else 430)
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var actions := VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 8)
	scroll.add_child(actions)
	var buttons: Array[Button] = []
	if event_mode:
		var record := RunV3ServiceWaystationEventGate.new().get_event_record(RunStitchedInkblackUnpickerEvent.EVENT_ID)
		for index in quote["choices"].size():
			var row: Dictionary = quote["choices"][index]
			var button := Button.new()
			button.name = "Inkblack_" + str(row["choice_id"])
			button.text = str(record["choices"][index]["text"])
			button.custom_minimum_size = Vector2(820, 64)
			button.disabled = not row["available"]
			button.focus_mode = Control.FOCUS_ALL if row["available"] else Control.FOCUS_NONE
			button.tooltip_text = "After choice · Gold %d · Scraps %d" % [row["wallet"]["gold"], row["wallet"]["scraps"]]
			button.pressed.connect(_stitched_unpicker_event_choose.bind(row["choice_id"],
				quote["state"].duplicate(true), weakref(panel), generation))
			actions.add_child(button)
			if row["available"]:
				buttons.append(button)
	for hero_id in quote.get("hero_ids", []):
		var calm := Button.new()
		calm.name = "CalmHero_" + str(hero_id)
		calm.text = "Calm %s · -50 Fray · %d gold" % [str(hero_id).replace("_", " ").capitalize(), quote["price"]]
		calm.custom_minimum_size = Vector2(820, 46)
		calm.pressed.connect(_stitched_unpicker_choose.bind(hero_id, weakref(panel), generation))
		actions.add_child(calm)
		buttons.append(calm)
	for spare in quote.get("spares", []):
		var button := Button.new()
		button.name = "UnpickSpare_%d" % spare["index"]
		button.text = "%s  -  %s  -  Tier %d%s  (+2 scraps)" % [
			str(spare["id"]).replace("_", " ").capitalize(), str(spare["slot"]),
			int(spare["tier"]), "  Torn" if spare["torn"] else ""]
		button.custom_minimum_size = Vector2(820, 46)
		button.pressed.connect(_stitched_unpicker_choose.bind(spare["index"], weakref(panel), generation))
		actions.add_child(button)
		buttons.append(button)
	if not event_mode:
		var leave := Button.new()
		leave.name = "UnpickerLeave"
		leave.text = "Leave"
		leave.custom_minimum_size = Vector2(820, 46)
		leave.pressed.connect(_stitched_unpicker_choose.bind(-1, weakref(panel), generation))
		actions.add_child(leave)
		buttons.append(leave)
	for index in buttons.size():
		buttons[index].focus_next = buttons[index].get_path_to(buttons[(index + 1) % buttons.size()])
		buttons[index].focus_previous = buttons[index].get_path_to(buttons[(index - 1 + buttons.size()) % buttons.size()])
	return {"panel": panel, "first": buttons[0]}


func _stitched_unpicker_choose(index: Variant, source: WeakRef, generation: int) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	if not is_instance_valid(panel) or panel != stitched_unpicker_panel \
			or panel.get_parent() != self or not panel.is_visible_in_tree() \
			or generation != _stitched_unpicker_generation or stitched_unpicker_visit == null \
			or stitched_unpicker_visit.read_state() != _stitched_unpicker_state \
			or stitched_unpicker_visit.quote() != _stitched_unpicker_quote \
			or not _stitched_unpicker_screens_clear():
		return {"ok": false}
	var context := _stitched_unpicker_live_context()
	context["candle"] = stitched_roadblock_candle
	var calm: bool = typeof(index) == TYPE_STRING and _stitched_unpicker_quote["hero_ids"].has(index)
	var spare: bool = typeof(index) == TYPE_INT and _stitched_unpicker_quote["spare_indices"].has(index)
	var leave: bool = typeof(index) == TYPE_INT and index == -1
	if context != _stitched_unpicker_context or not (leave or calm or spare):
		return {"ok": false}
	var state := _stitched_unpicker_state
	var receipt: Dictionary
	if leave:
		receipt = stitched_unpicker_visit.leave(state["visit_id"], STITCHED_UNPICKER_NODE_ID, state)
	elif calm:
		receipt = stitched_unpicker_visit.calm_hero(index, state["visit_id"], STITCHED_UNPICKER_NODE_ID, state)
	else:
		receipt = stitched_unpicker_visit.unpick_spare(index, state["visit_id"], STITCHED_UNPICKER_NODE_ID, state)
	if receipt.get("ok") != true or receipt.get("source_snapshot") != state \
			or receipt.get("source_receipt") != state["receipt"] or receipt.get("consumed") != true:
		return {"ok": false}
	_stitched_unpicker_service_receipt = receipt.duplicate(true)
	if calm:
		stitched_preview_gold = receipt["gold"]
		for hero: Dictionary in receipt["heroes"]:
			_stitched_fray_carry[hero["id"]] = {"fray": hero["fray"], "resolve": hero.get("resolve", "")}
	elif spare:
		stitched_preview_satchel = receipt["satchel"].duplicate(true)
		stitched_preview_scraps = receipt["scraps_after"]
	_close_stitched_unpicker()
	return receipt


func _close_stitched_unpicker() -> void:
	var panel := stitched_unpicker_panel
	if stitched_unpicker_event != null and stitched_unpicker_event.is_valid():
		stitched_unpicker_event.leave(STITCHED_UNPICKER_NODE_ID, stitched_unpicker_event.read_state())
	if stitched_unpicker_visit != null and not stitched_unpicker_visit.is_consumed():
		var state := stitched_unpicker_visit.read_state()
		stitched_unpicker_visit.leave(state["visit_id"], STITCHED_UNPICKER_NODE_ID, state)
	stitched_unpicker_panel = null
	stitched_unpicker_visit = null
	stitched_unpicker_event = null
	_stitched_unpicker_state.clear()
	_stitched_unpicker_quote.clear()
	_stitched_unpicker_context.clear()
	_stitched_unpicker_generation += 1
	if is_instance_valid(panel):
		if panel.get_parent() == self:
			remove_child(panel)
		panel.queue_free()
	_restore_stitched_title()
	_refresh_stitched_peddler_button()


## The earned Campfire button first admits the Emberglass Event. Only a
## one-use Circle receipt can supply its complete current carry.
func _open_stitched_campfire() -> bool:
	if stitched_unpicker_visit != null or is_instance_valid(stitched_unpicker_panel):
		return false
	if not _stitched_postvictory_stop_available \
			or is_instance_valid(stitched_campfire_panel) or stitched_campfire_visit != null \
			or is_instance_valid(stitched_peddler_panel) or stitched_peddler_visit != null \
			or stitched_peddler_candle_visit != null \
			or stitched_postevent_visit != null or is_instance_valid(stitched_postevent_panel) \
			or is_instance_valid(stitched_event_panel) or stitched_event_gate != null \
			or is_instance_valid(stitched_fight_view) \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or stitched_sewing_mend_visit != null or stitched_sewing_upgrade_visit != null \
			or deck != null or run_map != null or run_rng != null \
			or is_instance_valid(base_screen) or is_instance_valid(party_picker) \
			or is_instance_valid(route_view) or is_instance_valid(route_atlas_overlay) \
			or is_instance_valid(battle_view) \
			or not is_instance_valid(title_view) or not title_view.is_visible_in_tree():
		return false
	var roster: Array = _stitched_campfire_living_roster()
	if roster.size() != 4:
		return false
	if typeof(stitched_roadblock_candle) != TYPE_INT \
			or stitched_roadblock_candle < 0 or stitched_roadblock_candle > 100:
		return false
	var context := _stitched_unpicker_live_context()
	if context.is_empty() or context != _stitched_campfire_earned:
		return false
	var projected_candle := maxi(0, stitched_roadblock_candle - STITCHED_ROADBLOCK_CANDLE_COST)
	var wallet := {"gold": stitched_preview_gold, "scraps": stitched_preview_scraps}
	# Validate the original carry as well as the post-entry recovery offering.
	var original := RunStitchedEmberglassCampfireEvent.new(
		RunStitchedEmberglassCampfireEvent.EVENT_ID, STITCHED_CAMPFIRE_NODE_ID,
		roster, stitched_roadblock_candle, wallet)
	var event := RunStitchedEmberglassCampfireEvent.new(
		RunStitchedEmberglassCampfireEvent.EVENT_ID, STITCHED_CAMPFIRE_NODE_ID,
		roster, projected_candle, wallet)
	if not original.is_valid() or not event.is_valid():
		return false
	var quote := event.quote()
	var generation := _stitched_campfire_generation + 1
	var mounted := _mount_stitched_campfire_event(quote, generation)
	var panel: Control = mounted.get("panel")
	if not is_instance_valid(panel):
		return false
	add_child(panel)
	if panel.get_parent() != self or not panel.is_inside_tree() \
			or _stitched_unpicker_live_context() != context \
			or stitched_roadblock_candle != original.get_candle() \
			or not _stitched_postvictory_stop_available or not _stitched_unpicker_screens_clear():
		panel.queue_free()
		return false
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stitched_campfire_event = event
	stitched_campfire_panel = panel
	_stitched_campfire_event_state = event.read_state()
	_stitched_campfire_event_context = context.duplicate(true)
	_stitched_campfire_event_context["candle"] = projected_candle
	_stitched_campfire_generation = generation
	stitched_roadblock_candle = projected_candle
	_stitched_postvictory_stop_available = false
	_stitched_campfire_earned.clear()
	_refresh_stitched_peddler_button()
	title_view.hide()
	mounted["first"].grab_focus()
	return true


func _stitched_campfire_event_choose(choice: String, expected: Dictionary,
		source: WeakRef, generation: int) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	var context := _stitched_unpicker_live_context()
	context["candle"] = stitched_roadblock_candle
	if not is_instance_valid(panel) or panel != stitched_campfire_panel \
			or panel.get_parent() != self or not panel.is_visible_in_tree() \
			or generation != _stitched_campfire_generation or stitched_campfire_event == null \
			or stitched_campfire_visit != null or expected != _stitched_campfire_event_state \
			or stitched_campfire_event.read_state() != expected \
			or context != _stitched_campfire_event_context \
			or _stitched_campfire_roster != _stitched_campfire_authorized_roster \
			or not _stitched_campfire_event_screens_clear():
		return {"ok": false}
	var selected: Dictionary = {}
	for row: Dictionary in stitched_campfire_event.quote().get("choices", []):
		if row.get("choice_id") == choice and row.get("available") == true:
			selected = row
	if selected.is_empty():
		return {"ok": false}
	var prepared: Dictionary = {}
	var built: Dictionary = {}
	var next_generation := generation + 1
	if choice == RunStitchedEmberglassCampfireEvent.SERVICE_CHOICE_ID:
		prepared = _prepare_stitched_campfire(expected["heroes"], stitched_roadblock_candle)
		if prepared.is_empty():
			return {"ok": false}
		built = _mount_stitched_campfire(prepared["state"], next_generation, prepared["swap_quote"])
		var mounted: Control = built.get("panel")
		if not is_instance_valid(mounted):
			return {"ok": false}
		add_child(mounted)
		var live_context := _stitched_unpicker_live_context()
		live_context["candle"] = stitched_roadblock_candle
		if mounted.get_parent() != self or not mounted.is_inside_tree() or live_context != context \
				or not _stitched_campfire_event_screens_clear():
			mounted.queue_free()
			return {"ok": false}
		mounted.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var receipt := stitched_campfire_event.choose(choice, STITCHED_CAMPFIRE_NODE_ID, expected)
	if receipt.get("ok") != true:
		if is_instance_valid(built.get("panel")):
			built["panel"].queue_free()
		return {"ok": false}
	stitched_preview_gold = receipt["wallet"]["gold"]
	stitched_preview_scraps = receipt["wallet"]["scraps"]
	if prepared.is_empty():
		_close_stitched_campfire()
	else:
		remove_child(panel)
		panel.queue_free()
		stitched_campfire_event = null
		_stitched_campfire_event_state.clear()
		_stitched_campfire_event_context.clear()
		stitched_campfire_panel = built["panel"]
		stitched_campfire_visit = prepared["visit"]
		_stitched_campfire_state = prepared["state"].duplicate(true)
		_stitched_campfire_swap_visit = prepared["swap_visit"]
		_stitched_campfire_swap_state = prepared["swap_state"].duplicate(true)
		_stitched_campfire_generation = next_generation
		_stitched_campfire_roster.clear()
		_stitched_peddler_roster.clear()
		built["first"].grab_focus()
	return receipt


func _mount_stitched_campfire_event(quote: Dictionary, generation: int) -> Dictionary:
	var panel := Control.new()
	panel.name = "StitchedEmberglass"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var frame := NinePatchRect.new()
	frame.name = "EmberglassFrame"
	var art_path := "res://assets/paper/ui/panel_felt.png"
	frame.set_meta("art_path", art_path)
	if ResourceLoader.exists(art_path, "Texture2D"):
		frame.texture = load(art_path)
	frame.patch_margin_left = 24
	frame.patch_margin_right = 24
	frame.patch_margin_top = 24
	frame.patch_margin_bottom = 24
	frame.position = Vector2(120, 40)
	frame.size = Vector2(1040, 640)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	var heading := Label.new()
	heading.name = "EmberglassHeading"
	var candle: int = quote["state"]["candle"]
	var record := RunV3ServiceWaystationEventGate.new().get_event_record(RunStitchedEmberglassCampfireEvent.EVENT_ID)
	heading.text = "%s\nCANDLELIGHT %d / 100  ·  GOLD %d  ·  SCRAPS %d\n%s" % [
		record["title"], candle, quote["state"]["wallet"]["gold"],
		quote["state"]["wallet"]["scraps"], record["description"]]
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.position = Vector2(180, 65)
	heading.size = Vector2(920, 190)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	panel.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(210, 280)
	scroll.size = Vector2(860, 340)
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var actions := VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 8)
	scroll.add_child(actions)
	var buttons: Array[Button] = []
	for index in quote["choices"].size():
		var row: Dictionary = quote["choices"][index]
		var button := Button.new()
		button.name = "Emberglass_" + str(row["choice_id"])
		button.text = str(record["choices"][index]["text"])
		button.custom_minimum_size = Vector2(820, 64)
		button.disabled = not row["available"]
		button.focus_mode = Control.FOCUS_ALL if row["available"] else Control.FOCUS_NONE
		button.tooltip_text = "After choice · Gold %d · Scraps %d" % [row["wallet"]["gold"], row["wallet"]["scraps"]]
		button.pressed.connect(_stitched_campfire_event_choose.bind(row["choice_id"],
			quote["state"].duplicate(true), weakref(panel), generation))
		actions.add_child(button)
		if row["available"]:
			buttons.append(button)
	for index in buttons.size():
		buttons[index].focus_next = buttons[index].get_path_to(buttons[(index + 1) % buttons.size()])
		buttons[index].focus_previous = buttons[index].get_path_to(buttons[(index - 1 + buttons.size()) % buttons.size()])
	return {"panel": panel, "first": buttons[0]}


func _prepare_stitched_campfire(roster: Array, projected_candle: int) -> Dictionary:
	# Recovery borrows the Event node and its already-paid entry candle.
	var visit := RunCampfireVisit.new(
		STITCHED_CAMPFIRE_NODE_ID, roster, RunCampfireVisit.STITCHED,
		projected_candle)
	var state: Dictionary = visit.read_state()
	if state.get("ok") != true or state.get("mode") != RunCampfireVisit.STITCHED \
			or state.get("status") != RunCampfireVisit.STITCHED_OPEN \
			or state.get("node_id") != STITCHED_CAMPFIRE_NODE_ID \
			or state.get("heroes") != roster \
			or state.get("candle") != projected_candle \
			or state.get("quote") != visit.read_state().get("quote") \
			or not state.get("quote", {}).get("choices", []).has(RunCampfireVisit.STITCHED_LEAVE) \
			or not _stitched_campfire_held_fray_valid(roster):
		return {}
	# Build a distinct swap service from the FINAL Circle Leave parts and six-slot
	# satchel. Recovery remains the ordinary RunCampfireVisit with its own quote.
	var swap_visit: RunStitchedSewingSwap = null
	var swap_state: Dictionary = {}
	var swap_quote: Dictionary = {}
	var config := _stitched_floor_config()
	var source: Array = _stitched_campfire_swap_roster.duplicate(true)
	var lawful := source.size() == 4 and not config.is_empty() \
		and _stitched_campfire_swap_satchel == stitched_preview_satchel \
		and _stitched_campfire_swap_gear == _stitched_gear_overrides
	if lawful:
		for index in range(4):
			var hero: Dictionary = source[index]
			var recovered: Dictionary = roster[index]
			if str(hero.get("id", "")) != str(recovered["id"]) \
					or int(hero.get("rank", -1)) != int(recovered["position"]) \
					or hero.get("hp") != recovered["hp"] \
					or hero.get("max_hp") != recovered["max_hp"] \
					or hero.get("fray") != recovered["fray"] \
					or not hero.get("parts") is Dictionary \
					or hero["parts"] != config["heroes"][index]["parts"]:
				lawful = false
				break
	if lawful:
		var catalog: Dictionary = StitchedParts.build_catalog(config["parts"])
		if catalog.get("ok") == true:
			var candidate := RunStitchedSewingSwap.new(
				STITCHED_CAMPFIRE_NODE_ID, source, stitched_preview_satchel, catalog["by_id"])
			var candidate_state: Dictionary = candidate.read_state()
			var candidate_quote: Dictionary = candidate.quote()
			if candidate_state.get("ok") == true and candidate_state.get("open") == true \
					and candidate_state.get("node_id") == STITCHED_CAMPFIRE_NODE_ID \
					and candidate_state.get("heroes", []).size() == 4 \
					and candidate_state.get("satchel") == stitched_preview_satchel \
					and candidate_quote.get("state") == candidate_state:
				swap_visit = candidate
				swap_state = candidate_state
				swap_quote = candidate_quote
	return {"visit": visit, "state": state, "swap_visit": swap_visit,
		"swap_state": swap_state, "swap_quote": swap_quote}


func _mount_stitched_campfire(state: Dictionary, generation: int,
		swap_quote: Dictionary) -> Dictionary:
	var panel := Control.new()
	panel.name = "StitchedCampfire"
	panel.set_meta("campfire_generation", generation)
	panel.theme = load("res://themes/gothic_theme.tres")
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.focus_mode = Control.FOCUS_ALL
	var frame := NinePatchRect.new()
	frame.name = "CampfireFrame"
	var art_path := "res://assets/paper/ui/panel_felt.png"
	if ResourceLoader.exists(art_path, "Texture2D"):
		frame.texture = load(art_path)
		frame.patch_margin_left = 24
		frame.patch_margin_right = 24
		frame.patch_margin_top = 24
		frame.patch_margin_bottom = 24
	frame.position = Vector2(120, 40)
	frame.size = Vector2(1040, 640)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	var heading := Label.new()
	heading.name = "CampfireHeading"
	heading.text = "STITCHED CAMPFIRE  ·  TEND THE EMBERS"
	heading.position = Vector2(165, 72)
	heading.size = Vector2(950, 50)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	panel.add_child(heading)
	var quote := Label.new()
	quote.name = "CampfireQuote"
	var choice_labels: Array[String] = []
	for action in state["quote"]["choices"]:
		match str(action):
			RunCampfireVisit.MEND:
				choice_labels.append("Mend HP")
			RunCampfireVisit.TELL_TALES:
				choice_labels.append("Tell Tales (-25 FRAY)")
			RunCampfireVisit.TRIM_THE_WICK:
				choice_labels.append("Trim Wick (+%d CANDLE)" % mini(50, 100 - int(state["candle"])))
			RunCampfireVisit.STITCHED_LEAVE:
				choice_labels.append("Leave")
	quote.text = "One earned free choice: " + "  ·  ".join(choice_labels)
	quote.position = Vector2(185, 135)
	quote.size = Vector2(910, 75)
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(quote)
	var candle := Label.new()
	candle.name = "CampfireCandle"
	var wick_gain: int = mini(RunCampfireVisit.WICK_CANDLE_RESTORE, \
		RunCampfireVisit.STITCHED_CANDLE_MAX - int(state["candle"]))
	candle.text = "CANDLELIGHT  %d / 100  ·  TRIM +%d → %d / 100" % [
		int(state["candle"]), wick_gain, int(state["candle"]) + wick_gain]
	candle.position = Vector2(250, 215)
	candle.size = Vector2(780, 40)
	candle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(candle)
	for index in range(state["heroes"].size()):
		var hero: Dictionary = state["heroes"][index]
		var maximum: int = int(hero["max_hp"])
		@warning_ignore("integer_division")
		var heal: int = mini(maximum - int(hero["hp"]),
			(maximum * RunCampfireVisit.MEND_HEAL_PERCENT) / 100)
		var row := Label.new()
		row.name = "CampfireHero_%s" % str(hero["id"])
		row.text = "%d  %s  HP %d/%d  FRAY %d  MEND +%d" % [
			int(hero["position"]), str(hero["name"]), int(hero["hp"]),
			maximum, int(hero["fray"]), heal]
		row.position = Vector2(165, 270 + index * 57)
		row.size = Vector2(535, 47)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		panel.add_child(row)
	# Actual per-hero, same-slot catalog offers, in a keyboard-scrollable column.
	# No fabricated tier or spare is ever displayed as actionable.
	var swap_heading := Label.new()
	swap_heading.name = "CampfireSwapHeading"
	swap_heading.text = "EXCHANGE ONE SPARE  ·  FREE"
	swap_heading.position = Vector2(705, 268)
	swap_heading.size = Vector2(430, 36)
	panel.add_child(swap_heading)
	var scroll := ScrollContainer.new()
	scroll.name = "CampfireSwapOffers"
	scroll.position = Vector2(700, 305)
	scroll.size = Vector2(430, 225)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(scroll)
	var offers_box := VBoxContainer.new()
	offers_box.name = "CampfireSwapChoices"
	offers_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(offers_box)
	var swap_buttons: Array[Button] = []
	if swap_quote.get("ok") == true and swap_quote.get("open") == true:
		for hero_row in swap_quote.get("heroes", []):
			for slot_row in hero_row.get("slots", []):
				if not bool(slot_row.get("can_swap", false)):
					continue
				for offer in slot_row.get("offers", []):
					var hero_id := str(hero_row["hero_id"])
					var slot := str(slot_row["slot"])
					var satchel_index := int(offer["satchel_index"])
					var button := Button.new()
					button.name = "CampfireSwap_%s_%s_%d" % [hero_id, slot, satchel_index]
					button.text = "%s · %s: %s → %s (T%d%s)" % [
						str(hero_row["name"]), slot,
						str(slot_row["worn"]["name"]), str(offer["part"]["name"]),
						int(offer["part"]["tier"]),
						" torn" if bool(offer["part"]["torn"]) else ""]
					button.custom_minimum_size = Vector2(409, 42)
					button.focus_mode = Control.FOCUS_ALL
					button.pressed.connect(_stitched_campfire_swap_part.bind(
						hero_id, slot, satchel_index, swap_quote["state"].duplicate(true),
						weakref(panel), generation))
					offers_box.add_child(button)
					swap_buttons.append(button)
	if swap_buttons.is_empty():
		var empty := Label.new()
		empty.name = "CampfireNoSwap"
		empty.text = "No lawful untorn, same-slot spare available."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		offers_box.add_child(empty)
	# Only service-offered decisions are mounted; Tab and Up reach all.
	var recovery_buttons: Array[Button] = []
	for choice in state["quote"]["choices"]:
		var decision: String = str(choice)
		var button := Button.new()
		match decision:
			RunCampfireVisit.MEND:
				button.name = "CampfireMend"
				button.text = "Mend · +30% HP · free"
			RunCampfireVisit.TELL_TALES:
				button.name = "CampfireTales"
				button.text = "Tell Tales · -25 FRAY · free"
			RunCampfireVisit.TRIM_THE_WICK:
				button.name = "CampfireWick"
				button.text = "Trim Wick · +%d CANDLE · free" % wick_gain
			RunCampfireVisit.STITCHED_LEAVE:
				button.name = "CampfireLeave"
				button.text = "Leave Campfire · free"
			_:
				continue
		button.position = Vector2(165 + recovery_buttons.size() * 237, 550)
		button.size = Vector2(225, 58)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_stitched_campfire_choose.bind(
			decision, state.duplicate(true), weakref(panel), generation))
		panel.add_child(button)
		recovery_buttons.append(button)
	if recovery_buttons.is_empty():
		panel.free()
		return {}
	for index in range(recovery_buttons.size()):
		var button: Button = recovery_buttons[index]
		var previous: Button = recovery_buttons[(index + recovery_buttons.size() - 1) % recovery_buttons.size()]
		var following: Button = recovery_buttons[(index + 1) % recovery_buttons.size()]
		button.focus_previous = button.get_path_to(previous)
		button.focus_next = button.get_path_to(following)
	if not swap_buttons.is_empty():
		# Tab stays in the quoted recovery ring; Up reaches the swaps.
		for button in recovery_buttons:
			button.focus_neighbor_top = button.get_path_to(swap_buttons[0])
		for index in range(swap_buttons.size()):
			var previous: Button = recovery_buttons[-1] if index == 0 else swap_buttons[index - 1]
			var following: Button = recovery_buttons[0] if index == swap_buttons.size() - 1 else swap_buttons[index + 1]
			swap_buttons[index].focus_previous = swap_buttons[index].get_path_to(previous)
			swap_buttons[index].focus_next = swap_buttons[index].get_path_to(following)
	return {"panel": panel, "first": recovery_buttons[0]}


## Commit ONE quoted exchange on this specific mounted Campfire panel. The
## recovery visit stays open, with its original HP/FRAY/CANDLE authority.
func _stitched_campfire_swap_part(hero_id: String, slot: String, satchel_index: int,
		expected: Dictionary, source: WeakRef, generation: int) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	var service := _stitched_campfire_swap_visit
	if panel == null or not is_instance_valid(panel) or panel != stitched_campfire_panel \
			or not panel.is_visible_in_tree() or not panel.is_inside_tree() \
			or panel.get_meta("campfire_generation", -1) != generation \
			or generation != _stitched_campfire_generation \
			or service == null or service.read_state().get("open") != true \
			or _stitched_campfire_swap_state != expected \
			or service.read_state() != expected \
			or expected.get("node_id") != STITCHED_CAMPFIRE_NODE_ID \
			or expected.get("heroes") != _stitched_campfire_swap_roster \
			or expected.get("satchel") != stitched_preview_satchel \
			or _stitched_campfire_swap_satchel != stitched_preview_satchel \
			or _stitched_campfire_swap_gear != _stitched_gear_overrides \
			or stitched_campfire_visit == null \
			or stitched_campfire_visit.read_state() != _stitched_campfire_state \
			or _stitched_campfire_state.get("status") != RunCampfireVisit.STITCHED_OPEN \
			or _stitched_campfire_state.get("node_id") != STITCHED_CAMPFIRE_NODE_ID \
			or _stitched_campfire_state.get("heroes") != _stitched_campfire_authorized_roster \
			or _stitched_campfire_state.get("candle") != stitched_roadblock_candle \
			or _stitched_hp_carry.size() != 4 \
			or not _stitched_campfire_held_fray_valid(_stitched_campfire_authorized_roster) \
			or is_instance_valid(stitched_fight_view) \
			or is_instance_valid(stitched_peddler_panel) or stitched_peddler_visit != null \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null:
		return {"ok": false, "error": "stale or forged Campfire exchange"}
	for hero in _stitched_campfire_authorized_roster:
		if not _stitched_hp_carry.has(str(hero["id"])) \
				or _stitched_hp_carry[str(hero["id"])] != hero["hp"]:
			return {"ok": false, "error": "changed survivor authority"}
	var quote: Dictionary = service.quote()
	if quote.get("ok") != true or quote.get("open") != true \
			or quote.get("state") != expected:
		return {"ok": false, "error": "no current exchange quote"}
	var chosen_hero := -1
	var offered := false
	for index in range(quote.get("heroes", []).size()):
		var hero_row: Dictionary = quote["heroes"][index]
		if str(hero_row["hero_id"]) != hero_id:
			continue
		chosen_hero = index
		for slot_row in hero_row["slots"]:
			if str(slot_row["slot"]) != slot or not bool(slot_row["can_swap"]) \
					or bool(slot_row["worn"]["torn"]):
				continue
			for spare_offer in slot_row["offers"]:
				if int(spare_offer["satchel_index"]) == satchel_index \
						and str(spare_offer["part"]["slot"]) == slot:
					offered = true
	if not offered or chosen_hero < 0 or not slot in StitchedParts.SLOTS \
			or satchel_index < 0 or satchel_index >= expected["satchel"].size():
		return {"ok": false, "error": "not an offered same-slot spare"}
	var worn: Dictionary = expected["heroes"][chosen_hero]["parts"][slot]
	var spare: Dictionary = expected["satchel"][satchel_index]
	if bool(worn["torn"]) or str(spare["slot"]) != slot:
		return {"ok": false, "error": "torn or wrong-slot part"}
	var incoming := {"id": str(spare["id"]), "tier": int(spare["tier"]),
		"torn": bool(spare["torn"])}
	var outgoing := {"id": str(worn["id"]), "tier": int(worn["tier"]),
		"torn": bool(worn["torn"]), "slot": slot}
	var after_state: Dictionary = expected.duplicate(true)
	after_state["version"] = int(expected["version"]) + 1
	after_state["heroes"][chosen_hero]["parts"][slot] = incoming.duplicate(true)
	after_state["satchel"][satchel_index] = outgoing.duplicate(true)
	var receipt: Dictionary = service.swap(
		hero_id, slot, satchel_index, STITCHED_CAMPFIRE_NODE_ID, expected)
	var complete := {"ok": true, "error": "", "action": "swap",
		"node_id": STITCHED_CAMPFIRE_NODE_ID, "hero_id": hero_id,
		"slot": slot, "satchel_index": satchel_index,
		"worn_before": worn, "worn_after": incoming,
		"satchel_before": spare, "satchel_after": outgoing,
		"changed_heroes": [after_state["heroes"][chosen_hero]],
		"satchel": after_state["satchel"], "source_state": expected, "state": after_state}
	if receipt != complete or service.read_state() != after_state:
		return {"ok": false, "error": "incomplete Campfire swap receipt"}
	# Close swap only, NOT the separate one-decision recovery service.
	var closed: Dictionary = service.leave(STITCHED_CAMPFIRE_NODE_ID, after_state)
	var closed_state: Dictionary = after_state.duplicate(true)
	closed_state["open"] = false
	closed_state["version"] = int(after_state["version"]) + 1
	if closed != {"ok": true, "error": "", "action": "leave",
			"node_id": STITCHED_CAMPFIRE_NODE_ID, "changed_heroes": [],
			"satchel": closed_state["satchel"], "source_state": after_state,
			"state": closed_state} or service.read_state() != closed_state:
		return {"ok": false, "error": "Campfire exchange did not close"}
	# Only now publish precisely the worn slot and same satchel index.
	var carried: Dictionary = _stitched_gear_overrides.get(hero_id, {}).duplicate(true)
	carried[slot] = incoming.duplicate(true)
	_stitched_gear_overrides[hero_id] = carried
	stitched_preview_satchel = after_state["satchel"].duplicate(true)
	_stitched_campfire_swap_state = closed_state.duplicate(true)
	for button in panel.find_children("CampfireSwap_*", "Button", true, false):
		button.disabled = true
	var heading: Label = panel.find_child("CampfireSwapHeading", true, false)
	if heading != null:
		heading.text = "SPARE EXCHANGED  ·  RECOVERY STILL AVAILABLE"
	for name in ["CampfireMend", "CampfireTales", "CampfireWick", "CampfireLeave"]:
		var recovery: Button = panel.find_child(name, true, false)
		if recovery != null:
			recovery.grab_focus()
			break
	return receipt


## The app accepts only this live panel generation and its WHOLE quoted
## service state; a forged request never publishes a private service result.
func _stitched_campfire_choose(decision: String, expected: Dictionary,
		source: WeakRef, generation: int) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	if panel == null or not is_instance_valid(panel) \
			or panel != stitched_campfire_panel or not panel.is_visible_in_tree() \
			or panel.get_meta("campfire_generation", -1) != generation \
			or generation != _stitched_campfire_generation \
			or stitched_campfire_visit == null \
			or is_instance_valid(stitched_peddler_panel) or stitched_peddler_visit != null \
			or is_instance_valid(stitched_fight_view) \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or _stitched_campfire_state != expected \
			or stitched_campfire_visit.read_state() != expected \
			or expected.get("node_id") != STITCHED_CAMPFIRE_NODE_ID \
			or expected.get("status") != RunCampfireVisit.STITCHED_OPEN \
			or expected.get("mode") != RunCampfireVisit.STITCHED \
			or expected.get("heroes", []) != _stitched_campfire_authorized_roster \
			or expected.get("candle") != stitched_roadblock_candle \
			or not expected.get("quote", {}).get("choices", []).has(decision):
		return {"ok": false, "error": "stale, forged or unoffered Campfire"}
	var before: Array = expected["heroes"].duplicate(true)
	if before.size() != 4 or _stitched_hp_carry.size() != 4 \
			or not _stitched_campfire_held_fray_valid(before):
		return {"ok": false, "error": "missing survivor FRAY/HP authority"}
	var after: Array = before.duplicate(true)
	var next_fray: Dictionary = _stitched_fray_carry.duplicate(true)
	for hero in after:
		var id := str(hero["id"])
		if not _stitched_hp_carry.has(id) or _stitched_hp_carry[id] != hero["hp"]:
			return {"ok": false, "error": "changed survivor HP"}
		match decision:
			RunCampfireVisit.MEND:
				@warning_ignore("integer_division")
				var heal: int = (int(hero["max_hp"]) * RunCampfireVisit.MEND_HEAL_PERCENT) / 100
				hero["hp"] = mini(int(hero["max_hp"]), int(hero["hp"]) + heal)
			RunCampfireVisit.TELL_TALES:
				var reduced := maxi(0, int(hero["fray"]) - RunCampfireVisit.TALES_FRAY_REDUCTION)
				hero["fray"] = reduced
				var mood: String = str(next_fray[id]["resolve"])
				# Unravelled recovers only below 50; Steadfast persists.
				if mood in StitchedS1BEffects.RESOLVE_TRAITS \
						and reduced < StitchedRules.FRAY_RECOVER:
					mood = ""
				if (mood.is_empty() and reduced >= StitchedRules.FRAY_RESOLVE) \
						or (mood in StitchedS1BEffects.RESOLVE_TRAITS \
						and reduced < StitchedRules.FRAY_RECOVER):
					return {"ok": false, "error": "illegal resolve transition"}
				next_fray[id] = {"fray": reduced, "resolve": mood}
	var after_candle: int = int(expected["candle"])
	if decision == RunCampfireVisit.TRIM_THE_WICK:
		after_candle = mini(RunCampfireVisit.STITCHED_CANDLE_MAX,
			after_candle + RunCampfireVisit.WICK_CANDLE_RESTORE)
	var receipt: Dictionary = stitched_campfire_visit.select(
		decision, STITCHED_CAMPFIRE_NODE_ID, before, int(expected["candle"]))
	var committed: Dictionary = stitched_campfire_visit.read_state()
	if receipt != {"ok": true, "decision": decision,
			"node_id": STITCHED_CAMPFIRE_NODE_ID, "heroes": after,
			"candle": after_candle} \
			or committed.get("status") != RunCampfireVisit.STITCHED_DECIDED \
			or committed.get("heroes") != after or committed.get("candle") != after_candle:
		return {"ok": false, "error": "Campfire receipt rejected"}
	# Only after verifying the exact service receipt publish the chosen ledger.
	if decision == RunCampfireVisit.MEND:
		for hero in after:
			_stitched_hp_carry[str(hero["id"])] = int(hero["hp"])
	elif decision == RunCampfireVisit.TELL_TALES:
		_stitched_fray_carry = next_fray
	elif decision == RunCampfireVisit.TRIM_THE_WICK:
		stitched_roadblock_candle = after_candle
	_close_stitched_campfire()
	return receipt

func _close_stitched_campfire() -> void:
	if stitched_campfire_event != null and stitched_campfire_event.is_valid():
		stitched_campfire_event.leave(STITCHED_CAMPFIRE_NODE_ID, stitched_campfire_event.read_state())
	stitched_campfire_event = null
	_stitched_campfire_event_state.clear()
	_stitched_campfire_event_context.clear()
	var panel := stitched_campfire_panel
	if _stitched_campfire_swap_visit != null:
		var swap_open: Dictionary = _stitched_campfire_swap_visit.read_state()
		if swap_open.get("ok") == true and swap_open.get("open") == true:
			_stitched_campfire_swap_visit.leave(STITCHED_CAMPFIRE_NODE_ID, swap_open)
	_stitched_campfire_swap_visit = null
	_stitched_campfire_swap_state.clear()
	_stitched_campfire_swap_roster.clear()
	_stitched_campfire_swap_satchel.clear()
	_stitched_campfire_swap_gear.clear()
	if stitched_campfire_visit != null:
		var open: Dictionary = stitched_campfire_visit.read_state()
		if open.get("status") == RunCampfireVisit.STITCHED_OPEN:
			stitched_campfire_visit.select(RunCampfireVisit.STITCHED_LEAVE,
				STITCHED_CAMPFIRE_NODE_ID, open["heroes"], open["candle"])
	stitched_campfire_panel = null
	stitched_campfire_visit = null
	_stitched_campfire_state.clear()
	_stitched_campfire_roster.clear()
	_stitched_campfire_authorized_roster.clear()
	_stitched_campfire_generation += 1
	if is_instance_valid(panel):
		if panel.get_parent() == self:
			remove_child(panel)
		panel.queue_free()
	if is_instance_valid(title_view):
		title_view.show()
	_refresh_stitched_peddler_button()
	_focus_stitched_title.call_deferred(stitched_campfire_button)


## S6's third, mutually-exclusive post-Circle stop. Only a real four-survivor
## Circle Leave can offer it; every action is quote-checked against live carry.
func _stitched_postevent_build_snapshot(roster: Array) -> Dictionary:
	if roster.size() != 4 or _stitched_party_picks.size() != 4 \
			or StitchedPartyAdmission.admit(_stitched_party_picks) != _stitched_party_receipt \
			or _stitched_rank_carry.size() != 4 or _stitched_hp_carry.size() != 4 \
			or _stitched_fray_carry.size() != 4 \
			or typeof(stitched_roadblock_candle) != TYPE_INT \
			or stitched_roadblock_candle < 0 or stitched_roadblock_candle > 100 \
			or typeof(stitched_preview_scraps) != TYPE_INT or stitched_preview_scraps < 0 \
			or typeof(stitched_preview_gold) != TYPE_INT or stitched_preview_gold < 0 \
			or not _stitched_campfire_held_fray_valid(roster):
		return {}
	var ids := {}
	var ranks := {}
	var party: Array = []
	for raw in roster:
		if not raw is Dictionary:
			return {}
		var hero: Dictionary = raw
		var id: String = str(hero.get("id", ""))
		var rank: Variant = hero.get("position")
		var hp: Variant = hero.get("hp")
		var fray: Variant = hero.get("fray")
		if id.is_empty() or not id in _stitched_party_picks or ids.has(id) \
				or typeof(rank) != TYPE_INT or int(rank) < 1 or int(rank) > 4 \
				or ranks.has(rank) or _stitched_rank_carry.get(id) != rank \
				or typeof(hp) != TYPE_INT or int(hp) < 0 \
				or _stitched_hp_carry.get(id) != hp \
				or typeof(fray) != TYPE_INT or int(fray) < 0 or int(fray) >= 200 \
				or not _stitched_fray_carry.has(id) \
				or _stitched_fray_carry[id].get("fray") != fray:
			return {}
		ids[id] = true
		ranks[rank] = true
		party.append({"id": id, "fray": int(fray)})
	if ids.size() != 4 or ranks.size() != 4:
		return {}
	return {"candle": stitched_roadblock_candle, "party": party,
		"gold": stitched_preview_gold, "scraps": stitched_preview_scraps}


func _stitched_postevent_live_snapshot() -> Dictionary:
	if _stitched_postevent_roster.size() != 4 \
			or _stitched_postevent_roster != _stitched_campfire_authorized_roster:
		return {}
	return _stitched_postevent_build_snapshot(_stitched_postevent_roster)


## The consequence service includes all valid authored rows. The one paid
## repair that would waste a scrap at 100 CANDLE is deliberately not actionable.
func _stitched_postevent_row_available(row: Dictionary, snapshot: Dictionary) -> bool:
	if row.get("available") != true:
		return false
	if row.get("choice_id") == "mend_wick" \
			and int(row.get("candle", -1)) <= int(snapshot.get("candle", 100)):
		return false
	return true


func _open_stitched_postevent() -> bool:
	if stitched_unpicker_visit != null or is_instance_valid(stitched_unpicker_panel):
		return false
	if not _stitched_postvictory_stop_available \
			or is_instance_valid(stitched_postevent_panel) or stitched_postevent_visit != null \
			or is_instance_valid(stitched_campfire_panel) or stitched_campfire_visit != null \
			or is_instance_valid(stitched_peddler_panel) or stitched_peddler_visit != null \
			or stitched_peddler_candle_visit != null or stitched_peddler_part_visit != null \
			or is_instance_valid(stitched_fight_view) \
			or is_instance_valid(stitched_event_panel) or stitched_event_gate != null \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or stitched_sewing_mend_visit != null or stitched_sewing_upgrade_visit != null \
			or deck != null or run_map != null or run_rng != null \
			or is_instance_valid(base_screen) or is_instance_valid(party_picker) \
			or is_instance_valid(route_view) or is_instance_valid(route_atlas_overlay) \
			or is_instance_valid(battle_view) \
			or not is_instance_valid(title_view) or not title_view.is_visible_in_tree():

		return false
	var roster: Array = _stitched_campfire_living_roster()
	var original := _stitched_postevent_build_snapshot(roster)
	if original.is_empty():

		return false
	# This earned Event is a separate node. Quote the post-entry candle,
	# keeping live carry untouched until the complete panel builds successfully.
	var snapshot := original.duplicate(true)
	snapshot["candle"] = maxi(0, int(original["candle"]) - STITCHED_ROADBLOCK_CANDLE_COST)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STITCHED_EVENT_PATH))
	if not parsed is Dictionary:

		return false
	var record: Dictionary = parsed
	if record.get("id") != STITCHED_EVENT_ID or not record.get("choices") is Array:

		return false
	var authored: Array = record["choices"]
	if authored.size() != STITCHED_EVENT_CHOICES.size():

		return false
	# JSON.parse_string represents authored numeric tokens as floats; compare
	# the exact integral JSON values, then let the consequence service validate.
	var expected_effects := [
		{"target": "party", "fray": 0.0, "candle": 0.0, "gold": -10.0, "scraps": 2.0},
		{"target": "party", "fray": 0.0, "candle": 8.0, "gold": 0.0, "scraps": -1.0},
		{"target": "party", "fray": 0.0, "candle": 0.0, "gold": 0.0, "scraps": 0.0},
	]
	for i in range(authored.size()):
		if not authored[i] is Dictionary \
				or authored[i].get("id") != STITCHED_EVENT_CHOICES[i] \
				or str(authored[i].get("text", "")).strip_edges().is_empty() \
				or authored[i].get("stitched_effect") != expected_effects[i]:

			return false
	var visit := RunStitchedEventConsequence.new(record)
	if not visit.is_valid():

		return false
	var quote: Dictionary = visit.preview(snapshot.duplicate(true))
	if quote.get("ok") != true or quote.get("event_id") != STITCHED_EVENT_ID \
			or quote.get("candle") != snapshot["candle"] \
			or not quote.get("choices") is Array \
			or quote["choices"].size() != STITCHED_EVENT_CHOICES.size():

		return false
	var offered := {}
	for i in range(STITCHED_EVENT_CHOICES.size()):
		var row: Variant = quote["choices"][i]
		if not row is Dictionary or row.get("choice_id") != STITCHED_EVENT_CHOICES[i] \
				or row.get("target") != "party" or row.get("hero_id") != "" \
				or row.get("fray_delta") != 0 or row.get("fray") != {} \
				or row.get("gold_delta") != expected_effects[i]["gold"] \
				or row.get("scraps_delta") != expected_effects[i]["scraps"] \
				or row.get("candle_delta") != expected_effects[i]["candle"]:

			return false
		offered[str(row["choice_id"])] = _stitched_postevent_row_available(row, snapshot)
	if offered.get("leave") != true:

		return false
	var generation := _stitched_postevent_generation + 1
	var mounted: Dictionary = _mount_stitched_postevent(
		record, snapshot, quote, offered, generation)
	var panel: Control = mounted.get("panel")
	if panel == null:

		return false
	# Publish authority only after the complete preview and panel are verified.
	stitched_roadblock_candle = int(snapshot["candle"])
	stitched_postevent_visit = visit
	stitched_postevent_panel = panel
	_stitched_postevent_roster = roster.duplicate(true)
	_stitched_postevent_snapshot = snapshot.duplicate(true)
	_stitched_postevent_quote = quote.duplicate(true)
	_stitched_postevent_offered = offered.duplicate(true)
	_stitched_postevent_generation = generation
	_stitched_postvictory_stop_available = false
	_stitched_peddler_roster.clear()
	_stitched_campfire_roster.clear()
	_stitched_campfire_swap_roster.clear()
	_stitched_campfire_swap_satchel.clear()
	_stitched_campfire_swap_gear.clear()
	_refresh_stitched_peddler_button()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_view.hide()
	var first: Button = mounted.get("first")
	if is_instance_valid(first):
		first.grab_focus()
	return true


func _mount_stitched_postevent(record: Dictionary, snapshot: Dictionary,
		quote: Dictionary, offered: Dictionary, generation: int) -> Dictionary:
	var panel := Control.new()
	panel.name = "StitchedFerryEvent"
	panel.theme = load("res://themes/gothic_theme.tres")
	panel.focus_mode = Control.FOCUS_ALL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("stitched_event_generation", generation)
	var frame := NinePatchRect.new()
	frame.name = "FerryEventFrame"
	var art_path := "res://assets/paper/ui/panel_felt.png"
	if ResourceLoader.exists(art_path, "Texture2D"):
		frame.texture = load(art_path)
		frame.patch_margin_left = 24
		frame.patch_margin_right = 24
		frame.patch_margin_top = 24
		frame.patch_margin_bottom = 24
	frame.position = Vector2(180, 55)
	frame.size = Vector2(920, 600)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	var heading := Label.new()
	heading.name = "FerryEventHeading"
	heading.text = str(record["title"]).to_upper()
	heading.position = Vector2(235, 95)
	heading.size = Vector2(810, 50)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	panel.add_child(heading)
	var description := Label.new()
	description.name = "FerryEventDescription"
	description.text = str(record["description"])
	description.position = Vector2(250, 164)
	description.size = Vector2(780, 95)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(description)
	var wallet := Label.new()
	wallet.name = "FerryEventWallet"
	wallet.text = "GOLD %d   ·   SCRAPS %d   ·   CANDLE %d/100" % [
		snapshot["gold"], snapshot["scraps"], snapshot["candle"]]
	wallet.position = Vector2(240, 268)
	wallet.size = Vector2(800, 42)
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(wallet)
	var first: Button = null
	var buttons: Array[Button] = []
	for i in range(STITCHED_EVENT_CHOICES.size()):
		var id: String = STITCHED_EVENT_CHOICES[i]
		var row: Dictionary = quote["choices"][i]
		var button := Button.new()
		match id:
			"pay_gold":
				button.name = "FerryPayGold"
			"mend_wick":
				button.name = "FerryMendWick"
			"leave":
				button.name = "FerryLeave"
		button.text = str(record["choices"][i]["text"])
		if id == "mend_wick":
			button.text += "  (to %d/100)" % int(row["candle"])
		button.position = Vector2(300, 325 + i * 78)
		button.size = Vector2(680, 58)
		button.disabled = not bool(offered.get(id, false))
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		button.pressed.connect(_stitched_postevent_choose.bind(
			id, snapshot.duplicate(true), quote.duplicate(true),
			weakref(panel), generation))
		panel.add_child(button)
		buttons.append(button)
		if first == null and not button.disabled:
			first = button
	for i in range(buttons.size()):
		if buttons[i].disabled:
			continue
		var prev: Button = buttons[2]
		var next: Button = buttons[2]
		for back in range(1, 4):
			var candidate: Button = buttons[(i + buttons.size() - back) % buttons.size()]
			if not candidate.disabled:
				prev = candidate
				break
		for forward in range(1, 4):
			var candidate: Button = buttons[(i + forward) % buttons.size()]
			if not candidate.disabled:
				next = candidate
				break
		buttons[i].focus_previous = buttons[i].get_path_to(prev)
		buttons[i].focus_next = buttons[i].get_path_to(next)
	if first == null:
		panel.free()
		return {}
	return {"panel": panel, "first": first}


func _stitched_postevent_choose(choice_id: String, expected_snapshot: Dictionary,
		expected_quote: Dictionary, source: WeakRef, generation: int) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	if panel == null or not is_instance_valid(panel) \
			or panel != stitched_postevent_panel or not panel.is_visible_in_tree() \
			or panel.get_meta("stitched_event_generation", -1) != generation \
			or generation != _stitched_postevent_generation \
			or stitched_postevent_visit == null or not stitched_postevent_visit.is_valid() \
			or stitched_postevent_visit.is_claimed() \
			or is_instance_valid(stitched_fight_view) or is_instance_valid(stitched_sewing_panel) \
			or is_instance_valid(stitched_peddler_panel) or is_instance_valid(stitched_campfire_panel) \
			or _stitched_postvictory_stop_available \
			or deck != null or run_map != null or run_rng != null \
			or _stitched_postevent_snapshot != expected_snapshot \
			or _stitched_postevent_quote != expected_quote \
			or not choice_id in STITCHED_EVENT_CHOICES \
			or _stitched_postevent_offered.get(choice_id) != true:
		return {"ok": false, "error": "stale or unoffered Stitched Event"}
	var live := _stitched_postevent_live_snapshot()
	if live.is_empty() or live != expected_snapshot \
			or stitched_postevent_visit.preview(live.duplicate(true)) != expected_quote:
		return {"ok": false, "error": "changed Stitched Event resources or party"}
	var index: int = STITCHED_EVENT_CHOICES.find(choice_id)
	if index < 0 or index >= expected_quote.get("choices", []).size():
		return {"ok": false, "error": "missing quoted Event choice"}
	var row: Dictionary = expected_quote["choices"][index]
	if row.get("choice_id") != choice_id or not _stitched_postevent_row_available(row, live) \
			or row.get("fray") != {} or row.get("target") != "party" \
			or row.get("hero_id") != "":
		return {"ok": false, "error": "unavailable quoted Event choice"}
	var expected_receipt := {"ok": true, "event_id": STITCHED_EVENT_ID,
		"choice_id": choice_id, "target": "party", "hero_id": "",
		"candle": row["candle"], "fray": {},
		"gold_delta": row["gold_delta"], "gold": row["gold"],
		"scraps_delta": row["scraps_delta"], "scraps": row["scraps"]}
	# No service claim occurs before all live-state and exact-choice checks.
	var receipt: Dictionary = stitched_postevent_visit.choose(choice_id, live.duplicate(true))
	if receipt != expected_receipt:
		return {"ok": false, "error": "Stitched Event receipt mismatch"}
	stitched_preview_gold = int(receipt["gold"])
	stitched_preview_scraps = int(receipt["scraps"])
	stitched_roadblock_candle = int(receipt["candle"])
	_close_stitched_postevent()
	return receipt


func _close_stitched_postevent() -> void:
	var panel := stitched_postevent_panel
	stitched_postevent_panel = null
	stitched_postevent_visit = null
	_stitched_postevent_roster.clear()
	_stitched_postevent_snapshot.clear()
	_stitched_postevent_quote.clear()
	_stitched_postevent_offered.clear()
	_stitched_campfire_authorized_roster.clear()
	_stitched_postevent_generation += 1
	if is_instance_valid(panel):
		if panel.get_parent() == self:
			remove_child(panel)
		panel.queue_free()
	_restore_stitched_title()
	_refresh_stitched_peddler_button()


## Full-screen Quilt village with no run, RNG, deck or currency allocation.
func _open_base() -> bool:
	if deck != null or run_map != null or not is_instance_valid(title_view) \
		or not title_view.is_visible_in_tree() or is_instance_valid(base_screen):
		return false
	var scene := load(BASE_SCREEN_SCENE) as PackedScene
	if scene == null:
		return false
	var view := scene.instantiate() as BaseScreen
	if view == null:
		return false
	base_screen = view
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not view.open_village(session_gold, run_scraps):
		_close_base(view)
		return false
	# One fresh Path setup per village visit. An unreadable authored record keeps
	# the village itself usable but offers no Path options (fail closed).
	var choice := RunSeamstressPathChoice.new()
	run_seamstress_path_choice = choice if choice.is_valid() else null
	if run_seamstress_path_choice != null:
		view.present_path_options(_seamstress_path_options(run_seamstress_path_choice))
	# The Tinker Path is its own board and its own validated offer set. A record
	# that does not validate simply offers no Tinker Path.
	_tinker_setup_receipt = {}
	var tinker := RunTinkerPathChoice.new()
	run_tinker_path_choice = tinker if not tinker.get_offers().is_empty() else null
	if run_tinker_path_choice != null:
		view.present_tinker_path_options(_tinker_path_options(run_tinker_path_choice))
	view.path_choice_requested.connect(_base_path_choice.bind(weakref(view)))
	view.tinker_path_choice_requested.connect(_base_tinker_path_choice.bind(weakref(view)))
	run_warden_path_choice = RunWardenPathChoice.new()
	var warden_options: Array = []
	for path in run_warden_path_choice.get_authored_paths():
		warden_options.append({"id": path.id, "display_name": path.display_name,
			"card_name": path.card.display_name})
	view.present_warden_path_options(warden_options)
	view.warden_path_choice_requested.connect(_base_warden_path_choice.bind(weakref(view)))
	view.set_out_requested.connect(_base_set_out.bind(weakref(view)))
	_present_base_difficulty(view)
	view.difficulty_choice_requested.connect(_base_difficulty_choice.bind(weakref(view)))
	view.back_requested.connect(_base_back.bind(weakref(view)))
	view.present_bedroom(_bedroom_state())
	title_view.hide()
	return true


func _bedroom_state() -> Dictionary:
	if bedroom_record.is_empty():
		bedroom_record = StitchedBedroomRecord.load_file(bedroom_save_path) \
			if get_tree().current_scene == self else StitchedBedroomRecord.fresh()
	return bedroom_record


## Each finished run is one night in the room's record, counted once.
func _note_bedroom_run(session: StitchedRunSession) -> void:
	if session == null or _bedroom_noted_run == session.get_instance_id():
		return
	_bedroom_noted_run = session.get_instance_id()
	bedroom_record = StitchedBedroomRecord.after_run(_bedroom_state(), session)
	if get_tree().current_scene == self:
		StitchedBedroomRecord.save_file(bedroom_save_path, bedroom_record)


func _return_stitched_run_room() -> void:
	_return_stitched_run_title()
	if title_view.is_visible_in_tree():
		_open_base()


func _base_difficulty_choice(tier: int, source: WeakRef) -> void:
	var view := _live_base(source)
	if view == null or view._set_out_pending or view._back_pending \
		or view._difficulty_request != tier:
		return
	view._difficulty_request = -1
	if run_difficulty.select_tier(tier):
		_save_difficulty_progress()
		_present_base_difficulty(view)


func _present_base_difficulty(view: BaseScreen) -> void:
	view.present_difficulty(run_difficulty.get_available_tiers(), run_difficulty.get_selected_tier())
	for tier in range(view.difficulty_buttons.size()):
		var modifiers := run_difficulty.modifiers_for_tier(tier)
		view.difficulty_buttons[tier].tooltip_text += "\nEnemies: +%d%% max HP (round up), +%d attack intent damage" % [
			modifiers.max_hp_percent_bonus, modifiers.attack_intent_bonus]


## Detached presentation records for the two authored Paths, in authored order.
func _seamstress_path_options(choice: RunSeamstressPathChoice) -> Array:
	var options: Array = []
	for path in choice.get_paths():
		var card: Dictionary = path.get("card", {})
		options.append({
			"id": String(path.get("id", "")),
			"display_name": String(path.get("display_name", "")),
			"card_name": String(card.get("display_name", "")),
		})
	return options


## Detached presentation records for the two authored Tinker Paths, in authored
## order. Read from the same validated offer set the run service uses.
func _tinker_path_options(choice: RunTinkerPathChoice) -> Array:
	var options: Array = []
	for path in choice.get_offers():
		var card: Dictionary = path.get("card", {})
		options.append({
			"id": String(path.get("id", "")),
			"display_name": String(path.get("display_name", "")),
			"card_name": String(card.get("display_name", "")),
		})
	return options


## A Tinker Path pick is only live while it is this app's mounted, visible
## village, the offer set still validates, and no Tinker receipt was committed.
func _base_tinker_path_choice(path_id: String, source: WeakRef) -> void:
	var view := _live_base(source)
	if view == null:
		return
	if not run_tinker_path_receipt.is_empty():
		view.release_tinker_path_choice()
		return
	var choice := run_tinker_path_choice
	if choice == null or choice.get_offers().is_empty() or choice.has_selection():
		view.release_tinker_path_choice()
		return
	var receipt := choice.choose(path_id, StarterCards.new().get_starting_deck())
	if not bool(receipt.get("ok", false)):
		view.release_tinker_path_choice()
		return
	var definition: Dictionary = choice.get_definition(String(receipt.get("path_id", "")))
	_tinker_setup_receipt = receipt.duplicate(true)
	view.mark_tinker_path_selected(String(receipt["path_id"]),
		String(definition.get("display_name", "")))


## A Path pick is only live while it is this app's mounted, visible village, the
## setup still offers it once, and no run receipt was committed yet.
func _base_path_choice(path_id: String, source: WeakRef) -> void:
	var view := _live_base(source)
	if view == null:
		return
	if not run_seamstress_path_receipt.is_empty():
		view.release_path_choice()
		return
	var choice := run_seamstress_path_choice
	if choice == null or not choice.is_valid() or choice.is_claimed():
		view.release_path_choice()
		return
	var receipt := choice.choose(path_id, StarterCards.new().get_starting_deck())
	if not bool(receipt.get("ok", false)):
		view.release_path_choice()
		return
	view.mark_path_selected(String(receipt["path_id"]), String(receipt["display_name"]))


## A Base action is only live while it is this app's mounted, visible village.
func _live_base(source: WeakRef) -> BaseScreen:
	if source == null or not is_instance_valid(base_screen):
		return null
	var view := source.get_ref() as BaseScreen
	if view != base_screen or view.get_parent() != self \
		or not view.is_visible_in_tree() or not view.has_open_village():
		return null
	return view


func _base_warden_path_choice(path_id: String, source: WeakRef) -> void:
	var view := _live_base(source)
	if view == null:
		return
	if not run_warden_path_receipt.is_empty() or run_warden_path_choice == null \
			or not run_warden_path_choice.is_valid():
		view.release_warden_path_choice()
		return
	var receipt := run_warden_path_choice.choose(path_id)
	if not receipt.get("ok", false):
		view.release_warden_path_choice()
		return
	view.mark_warden_path_selected(receipt.path_id, receipt.display_name)


func _close_base(view: BaseScreen = null) -> void:
	if not is_instance_valid(base_screen):
		base_screen = null
		return
	if view != null and view != base_screen:
		return
	var closing := base_screen
	base_screen = null
	closing.close_village()
	if closing.get_parent() == self:
		remove_child(closing)
	closing.queue_free()


## Village Set out uses the same four-of-eight admission as live New Run.
## The village stays mounted but inert, so cancelling the picker restores its browsing.
func _base_set_out(source: WeakRef) -> void:
	var view := _live_base(source)
	if view == null:
		return
	if deck != null or run_map != null or stitched_run_session != null \
			or is_instance_valid(stitched_run_panel) or is_instance_valid(party_picker) \
			or not view._set_out_pending:
		view.release_set_out()
		return
	_open_stitched_run_picker(true)
	if not is_instance_valid(stitched_run_panel):
		view.release_set_out()


func _base_back(source: WeakRef) -> void:
	var view := _live_base(source)
	if view == null:
		return
	_close_base(view)
	# Back to title abandons this visit's Path setup; nothing of it reaches a run.
	run_seamstress_path_choice = null
	run_seamstress_path_receipt = {}
	run_warden_path_choice = null
	run_warden_path_receipt = {}
	run_tinker_path_choice = null
	run_tinker_path_receipt = {}
	_tinker_setup_receipt = {}
	if is_instance_valid(title_view):
		title_view.show()
	if is_instance_valid(base_button):
		base_button.grab_focus()


var party_picker: LiveV3PartyPicker


func _clear_stitched_run_panel() -> void:
	_stitched_run_epoch += 1
	stitched_run_buttons.clear()
	if is_instance_valid(stitched_run_panel):
		remove_child(stitched_run_panel)
		stitched_run_panel.queue_free()
	stitched_run_panel = null


func _stitched_run_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path, "Texture2D"):
		return load(path) as Texture2D
	return null


## A single image-backed page bed; the root Theme still owns fonts and focus.
func _stitched_run_page(heading: String, page_kind: String = "picker") -> VBoxContainer:
	_clear_stitched_run_panel()
	var page := Control.new()
	page.name = "StitchedRunPage"
	page.size = Vector2(1280, 720)
	page.set_meta("page_kind", page_kind)
	add_child(page)
	stitched_run_panel = page
	var backdrop_path := "res://assets/paper/backgrounds/map_board.png"
	if page_kind.begins_with("visit:"):
		var service := page_kind.trim_prefix("visit:")
		if service == "Campfire":
			backdrop_path = "res://assets/paper/backgrounds/rest_camp.png"
		elif service in ["Peddler", "PatchStall"]:
			backdrop_path = "res://assets/paper/backgrounds/shop_stall.png"
		else:
			backdrop_path = "res://assets/paper/backgrounds/event_crossroads.png"
	elif page_kind == "victory":
		backdrop_path = "res://assets/paper/backgrounds/reward_camp.png"
	elif page_kind == "defeat":
		backdrop_path = "res://assets/paper/backgrounds/battle_boss.png"
	elif page_kind == "picker":
		backdrop_path = "res://assets/paper/backgrounds/title.png"
	var backdrop := TextureRect.new()
	backdrop.name = "StitchedSceneArt"
	backdrop.set_meta("art_path", backdrop_path)
	backdrop.texture = _stitched_run_texture(backdrop_path)
	if backdrop.texture == null:
		backdrop.texture = _stitched_run_texture("res://assets/paper/backgrounds/map_board.png")
	backdrop.position = Vector2.ZERO
	backdrop.size = page.size
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(backdrop)
	var frame := NinePatchRect.new()
	frame.name = "StitchedFeltFrame"
	frame.texture = _stitched_run_texture("res://assets/paper/ui/panel_felt.png")
	frame.patch_margin_left = 24
	frame.patch_margin_right = 24
	frame.patch_margin_top = 24
	frame.patch_margin_bottom = 24
	frame.position = Vector2(36, 24)
	frame.size = Vector2(1208, 672)
	frame.modulate.a = 0.96 if page_kind == "picker" else 0.82 if page_kind in ["victory", "defeat"] else 0.74
	page.add_child(frame)
	var content := VBoxContainer.new()
	content.name = "StitchedPageContent"
	content.position = Vector2(28, 20)
	content.size = Vector2(1152, 628)
	content.add_theme_constant_override("separation", 9)
	frame.add_child(content)
	var title := Label.new()
	title.name = "StitchedPageHeading"
	title.text = heading
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#f4e1b8"))
	content.add_child(title)
	return content


## PanelContainer uses authored felt as a true nine-slice, never code-drawn shapes.
func _stitched_run_felt(parent: Node, label: String, minimum: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = label
	panel.custom_minimum_size = minimum
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var art := _stitched_run_texture("res://assets/paper/ui/panel_felt.png")
	if art != null:
		var backing := StyleBoxTexture.new()
		backing.texture = art
		backing.texture_margin_left = 24
		backing.texture_margin_right = 24
		backing.texture_margin_top = 24
		backing.texture_margin_bottom = 24
		backing.content_margin_left = 18
		backing.content_margin_right = 18
		backing.content_margin_top = 12
		backing.content_margin_bottom = 12
		panel.add_theme_stylebox_override("panel", backing)
	parent.add_child(panel)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 7)
	panel.add_child(inside)
	return inside


func _stitched_run_caption(parent: Node, text: String, size: int = 19) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("#f4e1b8"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _stitched_run_node_icon(button: Button, kind: String) -> void:
	var path := "res://assets/paper/ui/map_node_%s.png" % kind.to_snake_case()
	match kind:
		"Treasure":
			path = "res://assets/paper/ui/map_node_event.png"
		"PatchStall":
			path = "res://assets/paper/ui/map_node_patch_stall.png"
		"Campfire":
			path = "res://assets/paper/ui/map_node_campfire.png"
	var texture := _stitched_run_texture(path)
	if texture == null:
		texture = _stitched_run_texture("res://assets/paper/ui/map_node_event.png")
	if texture == null:
		return
	var icon := TextureRect.new()
	icon.name = "AuthoredNodeIcon"
	icon.set_meta("art_path", path)
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	# Sized after it joins the button: set earlier, the texture's own size won and the stamp covered the label.
	icon.position = Vector2(9, 5)
	icon.size = Vector2(46, 46)
	for face in ["normal", "hover", "pressed", "disabled", "focus"]:
		var skin := button.get_theme_stylebox(face)
		if skin != null:
			skin = skin.duplicate()
			skin.content_margin_left = 64
			button.add_theme_stylebox_override(face, skin)


func _stitched_run_action(parent: Node, text: String, callback: Callable, enabled: bool = true) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 44)
	button.focus_mode = Control.FOCUS_ALL
	button.disabled = not enabled
	var art := _stitched_run_texture("res://assets/paper/ui/reward_button.png")
	if art != null:
		for face in ["normal", "hover", "pressed", "disabled"]:
			var felt := StyleBoxTexture.new()
			felt.texture = art
			felt.texture_margin_left = 14
			felt.texture_margin_right = 14
			felt.texture_margin_top = 14
			felt.texture_margin_bottom = 14
			# The battle chrome's dusk tints: bare parchment under bone text could not be read.
			felt.modulate_color = {"normal": Color("9b7779"), "hover": Color("e9b873"),
				"pressed": Color("714a48"), "disabled": Color("64565b9c")}[face]
			button.add_theme_stylebox_override(face, felt)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", Color("#f5e7cb"))
	button.add_theme_color_override("font_hover_color", Color("#ffedc8"))
	button.add_theme_color_override("font_disabled_color", Color("#ae9e8e"))
	button.add_theme_color_override("font_outline_color", Color("#2b191b"))
	button.add_theme_constant_override("outline_size", 2)
	parent.add_child(button)
	var epoch := _stitched_run_epoch
	button.pressed.connect(func():
		if epoch == _stitched_run_epoch and button.get_parent() == parent \
			and button.is_visible_in_tree() and not button.disabled:
			callback.call())
	stitched_run_buttons.append(button)
	return button


## Explicit focus chain, preserving the exact public button order for route tests.
func _stitched_run_keyboard_chain() -> void:
	var enabled: Array[Button] = []
	for button in stitched_run_buttons:
		if is_instance_valid(button) and not button.disabled and button.is_visible_in_tree():
			enabled.append(button)
	for index in enabled.size():
		enabled[index].focus_next = enabled[index].get_path_to(enabled[(index + 1) % enabled.size()])
		enabled[index].focus_previous = enabled[index].get_path_to(enabled[(index - 1 + enabled.size()) % enabled.size()])
	if not enabled.is_empty():
		enabled[0].grab_focus()


func _open_stitched_run_picker(from_base: bool = false) -> void:
	var village: BaseScreen = base_screen if from_base and is_instance_valid(base_screen) else null
	var from_live_base: bool = village != null and village.get_parent() == self \
		and village.is_visible_in_tree() and village.has_open_village() \
		and village._set_out_pending and not title_view.is_visible_in_tree()
	if stitched_run_session != null or is_instance_valid(stitched_run_panel) \
		or not is_instance_valid(title_view) \
		or (not from_live_base and (from_base or not title_view.is_visible_in_tree())) \
		or run_map != null or deck != null or is_instance_valid(stitched_fight_view):
		return
	stitched_run_draft = StitchedRunSession.DEFAULT_PICKS.duplicate()
	_stitched_run_base = weakref(village) if from_live_base else null
	if from_live_base:
		village.hide()
	else:
		title_view.hide()
	var content := _stitched_run_page("Choose four pioneers")
	var grid := GridContainer.new()
	grid.columns = 2
	content.add_child(grid)
	var boxes: Array[CheckButton] = []
	for id in StitchedPartyAdmission.HERO_IDS:
		var check := CheckButton.new()
		check.text = str(id).replace("_", " ").capitalize()
		check.set_meta("hero_id", id)
		check.button_pressed = id in stitched_run_draft
		check.custom_minimum_size = Vector2(480, 48)
		grid.add_child(check)
		boxes.append(check)
		check.toggled.connect(func(pressed: bool):
			if pressed and not id in stitched_run_draft:
				stitched_run_draft.append(id)
			elif not pressed:
				stitched_run_draft.erase(id))
	_stitched_run_action(content, "Set out", func():
		var selected: Array = []
		for check in boxes:
			if not is_instance_valid(check) or check.get_parent() != grid:
				return
			if check.button_pressed:
				selected.append(check.get_meta("hero_id"))
		if selected.size() != 4 or selected.size() != stitched_run_draft.size():
			return
		var selected_set := selected.duplicate()
		var draft_set := stitched_run_draft.duplicate()
		selected_set.sort()
		draft_set.sort()
		if selected_set != draft_set:
			return
		var session := StitchedRunSession.start(run_seed, stitched_run_draft)
		if session == null or (stitched_walks and not session.enable_walks()):
			return
		stitched_run_session = session
		if _stitched_run_base != null:
			var base_to_close := _stitched_run_base.get_ref() as BaseScreen
			_stitched_run_base = null
			if is_instance_valid(base_to_close) and base_to_close == base_screen:
				_close_base(base_to_close)
		_present_stitched_run()
		_show_stitched_intro())
	_stitched_run_action(content, "Cancel", _return_stitched_run_title)
	stitched_run_buttons[0].grab_focus()


## S9c: one picture of Wren with his four dolls opens a New Run. It is a child of the first
## map page, so leaving that page removes it; the page's own buttons keep their order.
func _show_stitched_intro() -> void:
	if not is_instance_valid(stitched_run_panel):
		return
	var intro := StitchedWrenLines.intro()
	var veil := Control.new()
	veil.name = "WrenIntro"
	veil.size = Vector2(1280, 720)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	stitched_run_panel.add_child(veil)
	stitched_run_intro = veil
	var path := str(intro.get("picture", ""))
	if not ResourceLoader.exists(path, "Texture2D"):
		path = str(intro.get("fallback", "res://assets/paper/kid/kid_view_bedroom.png"))
	var picture := TextureRect.new()
	picture.name = "WrenIntroArt"
	picture.set_meta("art_path", path)
	picture.texture = _stitched_run_texture(path)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.size = veil.size
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(picture)
	var strip := NinePatchRect.new()
	strip.name = "WrenIntroStrip"
	strip.texture = _stitched_run_texture("res://assets/paper/ui/panel_felt.png")
	strip.patch_margin_left = 24
	strip.patch_margin_right = 24
	strip.patch_margin_top = 24
	strip.patch_margin_bottom = 24
	# Wren, the candle and the dolls fill the left of the picture; his story sits beside them.
	strip.position = Vector2(820, 40)
	strip.size = Vector2(424, 640)
	strip.modulate.a = 0.92
	veil.add_child(strip)
	var content := VBoxContainer.new()
	content.name = "WrenIntroText"
	content.position = Vector2(44, 40)
	content.size = Vector2(336, 560)
	content.add_theme_constant_override("separation", 14)
	strip.add_child(content)
	var heading := _stitched_run_caption(content, str(intro.get("heading", "ONE NIGHT IN THE OLD HOUSE")), 26)
	heading.name = "WrenIntroHeading"
	for line in intro.get("lines", []):
		_stitched_run_caption(content, str(line), 18)
	var begin := _stitched_run_action(content, str(intro.get("button", "Begin the night")), _dismiss_stitched_intro)
	begin.name = "WrenIntroBegin"
	begin.size_flags_horizontal = Control.SIZE_SHRINK_END
	stitched_run_buttons.erase(begin)
	# The veil blocks the mouse; keyboard focus stays on Begin until it is pressed.
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		begin.set_focus_neighbor(side, begin.get_path())
	begin.focus_next = begin.get_path()
	begin.focus_previous = begin.get_path()
	begin.grab_focus()


func _dismiss_stitched_intro() -> void:
	if not is_instance_valid(stitched_run_intro):
		stitched_run_intro = null
		return
	stitched_run_intro.get_parent().remove_child(stitched_run_intro)
	stitched_run_intro.queue_free()
	stitched_run_intro = null
	if not stitched_run_buttons.is_empty() and is_instance_valid(stitched_run_buttons[0]):
		stitched_run_buttons[0].grab_focus()


func _present_stitched_run() -> void:
	var session := stitched_run_session
	if session == null or not session.is_consistent():
		return
	if session.phase == "walk":
		_clear_stitched_run_panel()
		var walker := StitchedWalkScreen.new()
		if not walker.attach(session):
			return
		stitched_run_walk = walker
		walker.walk_finished.connect(func():
			if stitched_run_session != session or stitched_run_walk != walker:
				return
			stitched_run_walk = null
			remove_child(walker)
			walker.queue_free()
			_present_stitched_run())
		add_child(walker)
		return
	if session.phase == "battle":
		_clear_stitched_run_panel()
		var stage := StitchedBattleScreen.new()
		stage.config = session.battle_config.duplicate(true)
		stage.config["kid_floor"] = session.map.get_current_floor() + 1
		stage.config["kid_kind"] = str(session.pending.kind)
		stage.kid_fear_source = func(): return session.kid_fear()
		stage.battle = session.battle
		stage.parts = session.catalog
		stitched_run_battle = stage
		stage.exit_requested.connect(func():
			if stitched_run_session != session or stitched_run_battle != stage:
				return
			if not session.settle_battle(stage.battle):
				return
			stitched_run_battle = null
			remove_child(stage)
			stage.queue_free()
			_present_stitched_run())
		if not session.changed.is_connected(_sync_stitched_run_exit):
			session.changed.connect(_sync_stitched_run_exit)
		add_child(stage)
		stage._action_buttons["exit"].text = "Continue"
		stage._action_buttons["exit"].size.x = 100
		stage._action_buttons["exit"].disabled = not session.battle.is_over()
		var save := Button.new()
		save.name = "SaveStitchedBattle"
		save.text = "Save run"
		save.position = Vector2(1149, 642)   # beside Continue; the old row hid Help & settings
		save.size = Vector2(102, 29)
		save.add_theme_font_size_override("font_size", 18)
		save.add_theme_color_override("font_color", StitchedBattleScreen.PAPER)
		save.add_theme_color_override("font_hover_color", StitchedBattleScreen.ACCENT)
		save.add_theme_color_override("font_focus_color", StitchedBattleScreen.ACCENT)
		StitchedBattleScreen.CHROME.style_button(save)
		save.pressed.connect(func():
			if stitched_run_session == session and stitched_run_battle == stage and save.is_visible_in_tree():
				StitchedRunSave.write_file(stitched_save_path, session))
		stage.add_child(save)
		return
	var terminal := session.phase in ["victory", "defeat"]
	var page_kind := session.phase
	if session.phase == "visit":
		page_kind = "visit:" + str(session.pending.get("service", "Event"))
	var heading := "THE CANDLE ENDURES / VICTORY" if session.phase == "victory" else \
		"THE THREAD HAS FALLEN / DEFEAT" if session.phase == "defeat" else \
		"THE STITCHED ROAD / FLOOR %02d OF 12" % (session.map.get_current_floor() + 1) if session.phase == "map" else \
		"ROAD ENCOUNTER / %s" % str(session.pending.get("service", "Visit")).to_upper()
	var content := _stitched_run_page(heading, page_kind)
	var ledger := Label.new()
	ledger.name = "RunLedger"
	ledger.text = "CANDLE %d / 100     GOLD %d     SCRAPS %d     SATCHEL %d / 6" % [session.candle, session.gold, session.scraps, session.satchel.size()]
	ledger.text += "     WREN FEAR %d / 100" % session.snapshot().kid_fear.fear
	ledger.add_theme_font_size_override("font_size", 22)
	ledger.add_theme_color_override("font_color", Color("#f6dda6"))
	content.add_child(ledger)
	var hero_rows := HBoxContainer.new()
	hero_rows.name = "FourHeroRecaps"
	hero_rows.add_theme_constant_override("separation", 8)
	content.add_child(hero_rows)
	for hero in session.heroes:
		var felt := _stitched_run_felt(hero_rows, "HeroPatch_" + str(hero.id), Vector2(280, 106))
		var card := HBoxContainer.new()
		card.add_theme_constant_override("separation", 8)
		felt.add_child(card)
		# The doll's own battle painting, cropped to head and shoulders, fills the felt's empty stitched frame.
		var idle_path := str(STAGE_ROSTER.art_paths(str(hero.id)).get("idle", ""))
		if ResourceLoader.exists(idle_path, "Texture2D"):
			var full := load(idle_path) as Texture2D
			var side := minf(full.get_width(), full.get_height() * 0.5)
			var bust := AtlasTexture.new()
			bust.atlas = full
			bust.region = Rect2((full.get_width() - side) / 2.0, 0.0, side, side)
			var portrait := TextureRect.new()
			portrait.name = "Bust_" + str(hero.id)
			portrait.texture = bust
			portrait.custom_minimum_size = Vector2(76, 82)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if hero.lost:
				portrait.modulate = Color(0.35, 0.3, 0.3)
			card.add_child(portrait)
		var recap := Label.new()
		recap.name = "Recap_" + str(hero.id)
		recap.add_theme_font_size_override("font_size", 17)
		recap.add_theme_color_override("font_color", Color("#e7d6b3"))
		var state := "LOST" if hero.lost else "HANGING" if hero.hp == 0 else "IN THREAD"
		recap.text = "R%d / %s
HP %d / %d  %s
FRAY %d / 200  %s" % [hero.rank, hero.name, hero.hp, hero.max_hp, state, hero.fray, hero.resolve]
		card.add_child(recap)
	if terminal:
		_note_bedroom_run(session)
		var terminal_panel := _stitched_run_felt(content, "TerminalRecap", Vector2(1120, 245))
		terminal_panel.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
		var final_art := TextureRect.new()
		final_art.name = "TerminalBanner"
		final_art.texture = _stitched_run_texture("res://assets/paper/ui/reward_banner.png")
		final_art.custom_minimum_size = Vector2(500, 85)
		final_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		final_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		final_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		terminal_panel.add_child(final_art)
		_stitched_run_caption(terminal_panel,
			"%s  /  %d FLOORS REACHED  /  %d SEALED RECEIPTS" % [
				"ALL TWELVE FLOORS CLEARED" if session.phase == "victory" else "THE ROAD ENDS HERE",
				session.map.get_current_floor(), session.receipts.size()], 22)
		_stitched_run_caption(terminal_panel,
			"All four doll records remain above with their exact HP, fray and losses. The ledger is sealed.", 18)
		var ending_actions := HBoxContainer.new()
		content.add_child(ending_actions)
		_stitched_run_action(ending_actions, "Return to title", _return_stitched_run_title)
		_stitched_run_action(ending_actions, "Save run", func(): StitchedRunSave.write_file(stitched_save_path, session))
		if StitchedBedroom.has_art():
			_stitched_run_action(ending_actions, "Back to Wren's room", _return_stitched_run_room)
		_stitched_run_keyboard_chain()
		return
	var choices_box: VBoxContainer
	var expected := session.snapshot()
	if session.phase == "map":
		# Both pages use the same captured admission, never graph-local run state.
		var mounted_page := stitched_run_panel
		var map_epoch := _stitched_run_epoch
		var mounted_legal := session.choices()
		var admit_route := func(id: String):
			if stitched_run_session == session and stitched_run_panel == mounted_page \
				and map_epoch == _stitched_run_epoch and mounted_page.is_visible_in_tree() \
				and session.phase == "map" and mounted_legal.has(id) \
				and session.snapshot() == expected and session.enter(id, expected):
				_present_stitched_run()
		var book := StitchedRouteBookView.new()
		content.add_child(book)
		choices_box = book.present(session.map, mounted_legal)
		var graph := book.graph_view
		graph.route_requested.connect(func(id: String):
			if not mounted_legal.has(id) or book.graph_view != graph \
				or not is_instance_valid(graph) or not graph.is_visible_in_tree():
				return
			var tile := graph.find_child("GraphNode_" + id, true, false) as VBoxContainer
			if tile == null or tile.get_meta("route_id", "") != id \
				or tile.get_meta("status", "") != "legal":
				return
			var control := tile.get_node_or_null("GraphNodeActivate") as Button
			if control == null or control.get_meta("route_id", "") != id \
				or control.disabled or not control.is_visible_in_tree():
				return
			admit_route.call(id))
		for id in mounted_legal:
			var node := session.map.get_node(id)
			var button := _stitched_run_action(choices_box,
				"FLOOR %02d  /  %s  /  PATH %d" % [
					node.floor, node.type, node.position + 1], func():
					admit_route.call(id))
			button.custom_minimum_size = Vector2(610, 56)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.set_meta("route_id", id)
			button.set_meta("node_kind", node.type)
			button.tooltip_text = "Connected legal node %s" % id
			book.decorate_ticket(button, str(node.type))
			_stitched_run_node_icon(button, str(node.type))
			# Left/right keyboard movement joins the lit atlas to its matching
			# right-page ticket without changing the ticket Tab chain.
			var tile := graph.find_child("GraphNode_" + id, true, false) as VBoxContainer
			var graph_button := tile.get_node("GraphNodeActivate") as Button
			button.focus_neighbor_left = button.get_path_to(graph_button)
			graph_button.focus_neighbor_right = graph_button.get_path_to(button)
			# Only inspect the authentic ticket's destination; the atlas has no
			# admission callbacks and does not modify session or RNG authority.
			button.mouse_entered.connect(func(): book.graph_view.set_inspected_route(id))
			button.mouse_exited.connect(func():
				if not button.has_focus():
					book.graph_view.clear_inspected_route(id))
			button.focus_entered.connect(func(): book.graph_view.set_inspected_route(id))
			button.focus_exited.connect(func():
				if not button.is_hovered():
					book.graph_view.clear_inspected_route(id))
	else:
		var atlas := HBoxContainer.new()
		atlas.name = "RoutedStage"
		atlas.add_theme_constant_override("separation", 12)
		atlas.custom_minimum_size = Vector2(1120, 327)
		atlas.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(atlas)
		var left := _stitched_run_felt(atlas, "RouteOrVisitStory", Vector2(384, 328))
		var right := _stitched_run_felt(atlas, "LegalChoices", Vector2(706, 328))
		var title := str(session.pending.get("title", session.pending.get("service", "Road stop")))
		_stitched_run_caption(left, title.to_upper(), 22)
		var node := session.map.get_node(str(session.pending.get("node_id", "")))
		if not node.is_empty():
			_stitched_run_caption(left, "FLOOR %02d  /  %s  /  PATH %d" % [
				node.floor, node.type, node.position + 1], 19)
		_stitched_run_caption(left, "This is a real road visit. Lit patches are legal choices; dim patches are unavailable.", 18)
		_stitched_run_caption(right, "CHOOSE YOUR NEXT STITCH", 22)
		var scroll := ScrollContainer.new()
		scroll.name = "RunActionScroll"
		scroll.custom_minimum_size = Vector2(620, 267)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right.add_child(scroll)
		choices_box = VBoxContainer.new()
		choices_box.name = "PublicRouteDecisions"
		choices_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choices_box.add_theme_constant_override("separation", 8)
		scroll.add_child(choices_box)
		for action in session.visit_actions():
			var button := _stitched_run_action(choices_box, str(action.text), func():
				if stitched_run_session == session and session.choose_visit(action.id, action.arguments, expected):
					_present_stitched_run(), action.enabled)
			button.custom_minimum_size = Vector2(620, 48)
			button.set_meta("action_id", action.id)
			button.set_meta("action_arguments", action.arguments.duplicate(true))
			button.tooltip_text = str(action.text) if action.enabled else "Unavailable: " + str(action.text)
	var navigation := HBoxContainer.new()
	navigation.name = "RunNavigation"
	content.add_child(navigation)
	_stitched_run_action(navigation, "Save run", func(): StitchedRunSave.write_file(stitched_save_path, session))
	_stitched_run_action(navigation, "Reload saved run", func(): load_stitched_run(stitched_save_path))
	_stitched_run_keyboard_chain()


func _sync_stitched_run_exit() -> void:
	var session := stitched_run_session
	var stage := stitched_run_battle
	if session != null and stage != null and stage == stitched_run_battle \
		and session.battle != null and stage._action_buttons.has("exit"):
		stage._action_buttons["exit"].disabled = not session.battle.is_over()


func load_stitched_run(path: String) -> bool:
	if deck != null or run_map != null or is_instance_valid(base_screen) \
		or is_instance_valid(stitched_fight_view) or stitched_event_gate != null:
		return false
	var restored := StitchedRunSave.read_file(path)
	if restored == null:
		return false
	# Publish only after the entire save has replayed and matched its state.
	if is_instance_valid(stitched_run_battle):
		remove_child(stitched_run_battle)
		stitched_run_battle.queue_free()
	stitched_run_battle = null
	stitched_run_session = restored
	title_view.hide()
	_present_stitched_run()
	return true


func _return_stitched_run_title() -> void:
	_clear_stitched_run_panel()
	if is_instance_valid(stitched_run_battle):
		remove_child(stitched_run_battle)
		stitched_run_battle.queue_free()
	stitched_run_battle = null
	if is_instance_valid(stitched_run_walk):
		remove_child(stitched_run_walk)
		stitched_run_walk.queue_free()
	stitched_run_walk = null
	stitched_run_session = null
	stitched_run_draft.clear()
	var village := _stitched_run_base.get_ref() as BaseScreen if _stitched_run_base != null else null
	_stitched_run_base = null
	if is_instance_valid(village) and village == base_screen and village.has_open_village():
		village.show()
		village.release_set_out()
		village.set_out_button.grab_focus()
		return
	title_view.show()
	start_button.grab_focus()


## Route/book buttons use the inherited gothic Button face and focus seam.
## Their sewn token art and authored colour-coded marker pieces stay separate.


var peddler_visit: RunPeddlerVisit

