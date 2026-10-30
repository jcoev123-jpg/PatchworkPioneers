extends Node
## Mounted input/face adapter for held target-free area attacks and self energy
## utilities. Each original resolver owns its mutation; the attack presenter
## alone owns Tinker's first-attack latch.

const SEAMSTRESS_IDS := ["seamstress_blanket_stitch", "seamstress_blanket_stitch_plus"]
## Authored V3 control sweep; reuses this fight's existing Unravel gauge.
const BLANKET_IDS := ["seamstress_v3_blanket_of_barbs", "seamstress_v3_blanket_of_barbs_plus"]
const TINKER_IDS := ["tinker_scatter_bolts", "tinker_scatter_bolts_plus",
	"tinker_ricochet", "tinker_ricochet_plus"]
## Target-free area attacks that charge the battle's shared Unravel gauge.
const UNRAVEL_TINKER_IDS := ["tinker_shrapnel_seam", "tinker_shrapnel_seam_plus"]
const ENERGY_TINKER_IDS := ["tinker_overclock", "tinker_overclock_plus"]
const ENERGY_SEAMSTRESS_IDS := ["seamstress_tailors_trance", "seamstress_tailors_trance_plus"]
const ENERGY_IDS := ENERGY_TINKER_IDS + ENERGY_SEAMSTRESS_IDS
const YARN_IDS := ["yarn_ranger_unspool", "yarn_ranger_unspool_plus"]
const SNARE_IDS := ["yarn_ranger_snare_net", "yarn_ranger_snare_net_plus"]
const SKEIN_IDS := ["yarn_ranger_endless_skein", "yarn_ranger_endless_skein_plus"]
const CROW_IDS := ["scarecrow_crow_dive", "scarecrow_crow_dive_plus",
	"scarecrow_crow_peck", "scarecrow_crow_peck_plus"]
const GOLEM_IDS := ["button_golem_popping_volley", "button_golem_popping_volley_plus",
	"button_golem_buttonstorm", "button_golem_buttonstorm_plus"]
const MOTH_IDS := ["lantern_monk_moth_cloud", "lantern_monk_moth_cloud_plus"]
const HARVEST_IDS := ["scarecrow_harvest_fright", "scarecrow_harvest_fright_plus"]
const CARD_IDS := SEAMSTRESS_IDS + BLANKET_IDS + TINKER_IDS + UNRAVEL_TINKER_IDS + ENERGY_IDS + YARN_IDS + SNARE_IDS + SKEIN_IDS + CROW_IDS + GOLEM_IDS + MOTH_IDS + HARVEST_IDS
const INSTRUCTION := "Click or focus and press Enter / Space to play"
const CUE_NAME := "BlanketStitchCue"
const CREAM := Color("#ece0c8")
const INK := Color("#3d3440")
const RUST := Color("#9e6f58")
## Darker sewn ink for the one compact rule line on an area card face.
const RULE_INK := Color("#7c4a35")
const SEAMSTRESS := Color("#6e4f6b")
const TINKER := Color("#c49a3a")
## Printed source/target pips are small drawn controls, never art files.
const PIP_SIZE := 9.0
const PIP_SLOTS := [1, 2, 3]
const PIP_GAP := 3.0
const GROUP_GAP := 9.0
const THREAD_DASH := 3.0
const THREAD_STITCH := 2.0


## The drawn position strip: three sewn source circles, three target squares and
## the stitched connection that runs through the target-square centres. Laying
## the strip out by hand (instead of a container row) keeps every stitch tied to
## a real target square rather than to the gap after the source circles.
class PipTrack:
	extends Control

	var pip_size := 9.0
	var pip_gap := 3.0
	var group_gap := 9.0
	var dash := 3.0
	var stitch := 2.0
	## One flag per authored enemy slot; a filled flag is a named target square.
	var targets: Array = []

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			layout()

	## Position the six pips and, when present, the thread through the centres of
	## the authored target squares.
	func layout() -> void:
		var total: float = 6.0 * pip_size + 4.0 * pip_gap + group_gap
		var left: float = maxf(0.0, (size.x - total) * 0.5)
		var top: float = maxf(0.0, (size.y - pip_size) * 0.5)
		for index in range(3):
			_place(get_node_or_null("From%d" % (index + 1)),
				Vector2(left + index * (pip_size + pip_gap), top))
		var to_left: float = left + 3.0 * pip_size + 2.0 * pip_gap + group_gap
		var centres: Array[float] = []
		for index in range(3):
			var at := Vector2(to_left + index * (pip_size + pip_gap), top)
			_place(get_node_or_null("To%d" % (index + 1)), at)
			if index < targets.size() and bool(targets[index]):
				centres.append(at.x + pip_size * 0.5)
		_layout_thread(centres, top + pip_size * 0.5)

	func _place(node: Node, at: Vector2) -> void:
		if not node is Control:
			return
		var control := node as Control
		control.position = at
		control.size = Vector2(pip_size, pip_size)

	## One dash per target square plus one in each gap: the dashes land on the
	## square centres, never merely beside them.
	func _layout_thread(centres: Array[float], middle: float) -> void:
		var thread := get_node_or_null("Thread") as Control
		if thread == null:
			return
		thread.position = Vector2.ZERO
		thread.size = size
		if centres.is_empty():
			thread.visible = false
			return
		thread.visible = true
		var seam := thread.get_node_or_null("Seam") as Control
		if seam != null:
			var first: float = centres[0]
			var last: float = centres[centres.size() - 1]
			seam.position = Vector2(first - pip_size * 0.5, middle - 0.5)
			seam.size = Vector2(last - first + pip_size, 1.0)
		var stitches: Array[Control] = []
		for child in thread.get_children():
			if child is Control and String(child.name).begins_with("Stitch"):
				stitches.append(child as Control)
		for index in range(stitches.size()):
			var x: float
			if index % 2 == 0:
				# Every even stitch sits exactly on one target-square centre.
				var slot := int(index / 2.0)
				if slot >= centres.size():
					break
				x = centres[slot]
			else:
				# Every odd stitch fills the gap between two target squares.
				var pair := int((index - 1) / 2.0)
				if pair + 1 >= centres.size():
					break
				x = (centres[pair] + centres[pair + 1]) * 0.5
			stitches[index].position = Vector2(x - dash * 0.5, middle - stitch * 0.5)
			stitches[index].size = Vector2(dash, stitch)

## Retained mount handle. This adapter never creates a separate action control.
var button: Button

const SINGLE_BLEED_ADAPTER = preload("res://scripts/live_seamstress_single_bleed_hand.gd")

var _service := CombatSeamstressPoolBleed.new()
var _catalog := SeamstressPoolCards.new()
var _tinker_catalog := TinkerPoolCards.new()
var last_event: Dictionary = {}
var _battle: Control
var _deck: CombatDeck
var _party: CombatParty
var _enemies: CombatEnemies
var _result: CombatBattleResult
var _rng: RandomNumberGenerator
var _intents: CombatEnemyIntents
## Key: the real hand panel, value: {"id": String, "callback": Callable}.
var _bindings: Dictionary = {}
var _pending: Dictionary = {}
var _turn := -1
var _token := 0
var _receipt_seq := 0


func _ready() -> void:
	# This action is already scene-mounted. One idempotent child handles only
	# held enemy-single Bleed cards, leaving every target-free binding intact.
	if get_node_or_null("LiveSeamstressSingleBleedHand") == null:
		var single = SINGLE_BLEED_ADAPTER.new()
		single.name = "LiveSeamstressSingleBleedHand"
		add_child(single)


func _process(_delta: float) -> void:
	_sync_battle()
	_refresh_ricochet_tooltips()


func _is_card(card_id: String) -> bool:
	return card_id in CARD_IDS


func _definition(card_id: String) -> Dictionary:
	if card_id in BLANKET_IDS:
		return V3SeamstressPoolCards.new().get_definition(card_id)
	if card_id in MOTH_IDS:
		return LanternMonkPoolCards.new().get_definition(card_id)
	if card_id in GOLEM_IDS:
		return ButtonGolemPoolCards.new().get_definition(card_id)
	if card_id in HARVEST_IDS:
		return ScarecrowPoolCards.new().get_definition(card_id)
	if card_id in CROW_IDS:
		return CombatScarecrowCrowCards.new()._catalog_definition(card_id)
	if card_id in SKEIN_IDS:
		return CombatYarnRangerEndlessSkeinCards.skein_definition(card_id)
	if card_id in YARN_IDS or card_id in SNARE_IDS:
		return YarnRangerPoolCards.new().get_definition(card_id)
	return _tinker_catalog.get_definition(card_id) if card_id in TINKER_IDS \
		or card_id in UNRAVEL_TINKER_IDS or card_id in ENERGY_TINKER_IDS \
		else _catalog.get_definition(card_id)


## Reuse the starter attack presenter's actual session- and turn-matched latch.
## Never synthesize one on a newly bound panel or for a stale presenter.
func _live_tinker_latch(app) -> CombatTinkerFirstAttack:
	var preview = app.get_node_or_null("LiveAttackPreview")
	if preview == null or not preview.is_inside_tree() \
			or preview._battle != _battle or preview._deck != _deck \
			or preview._session != [app.party, app.enemies, app.battle_result,
				app.run_rng, app.enemy_intents] or preview._turn != _turn \
			or not preview._play is CombatAttackCards:
		return null
	return preview._play._tinker


## Share the attack presenter's exact validated sewn authority (including
## its already-consumed first-hit state). A present but invalid/missing binding
## refuses the cast; a run without a wardrobe retains legacy behavior.
func _live_tinker_patch_rules(app) -> Dictionary:
	var preview = app.get_node_or_null("LiveAttackPreview")
	if preview == null or not is_instance_valid(preview) \
			or preview._battle != _battle or preview._deck != _deck \
			or preview._session != [app.party, app.enemies, app.battle_result,
				app.run_rng, app.enemy_intents] or preview._turn != _turn \
			or not preview._play is CombatAttackCards:
		return {}
	var rules: CombatPatchAttackRules = preview._play._patches
	var carry := app.party_carryover as RunTornCarryover
	if carry == null or carry._wardrobe == null:
		return {"rules": null} if rules == null else {}
	# A live run binding is explicit. Recheck its canonical run identity and
	# ledger witness before accepting the battle's persistent projection.
	var wardrobe: RunPatchWardrobe = carry._wardrobe
	if rules == null or not is_instance_valid(rules) or not rules.is_valid() \
			or wardrobe == null or not wardrobe.is_valid() or carry.torn == null \
			or not carry.torn.is_valid():
		return {}
	var current := wardrobe.get_snapshot()
	if not carry.can_bind_wardrobe(wardrobe, carry.torn, current) \
			or current.heroes != app.run_heroes or current.owned != app.run_trinkets \
			or current.cards != app.run_deck or current.scraps != app.run_scraps \
			or current.gold != app.session_gold or current.seed != app.run_seed:
		return {}
	return {"rules": rules}


## The battle's own Pinned set and Unravel gauge, exactly as the mounted
## single-target presenter created them for this session. A gauge card fails
## closed unless that one gauge is bound to this roster and the live round flow
## either shares it already or is about to. This never creates a second gauge,
## a second latch or a substitute roster.
func _live_unravel_authorities(app) -> Dictionary:
	var preview = app.get_node_or_null("LiveAttackPreview")
	if preview == null or not preview.is_inside_tree() \
			or preview._battle != _battle or preview._deck != _deck \
			or preview._session != [app.party, app.enemies, app.battle_result,
				app.run_rng, app.enemy_intents] or preview._turn != _turn:
		return {}
	var unravel: CombatUnravel = preview._unravel
	var pinned: CombatPinned = preview._pinned
	if unravel == null or pinned == null \
			or not is_instance_valid(unravel) or not is_instance_valid(pinned):
		return {}
	if unravel._bound_enemies != _enemies:
		return {}
	var flow: CombatRoundFlow = app.round_flow
	if flow == null or not is_instance_valid(flow) \
			or flow._deck != _deck or flow._party != _party \
			or flow._enemies != _enemies or flow._intents != app.enemy_intents \
			or flow._result != _result:
		return {}
	# Another gauge already bound to this fight is a real conflict, not a
	# fallback: refuse rather than replace or double-charge an authority.
	if flow._unravel != null and flow._unravel != unravel:
		return {}
	return {"unravel": unravel, "pinned": pinned, "flow": flow}


## True only for a real, currently held blank stitch panel whose mounted label,
## hand index and bound ID all agree. Never a rules authority: the service
## revalidates the complete play before it commits anything.
func _valid_panel(app, panel) -> bool:
	if not is_instance_valid(panel) or not is_instance_valid(app.hand_view):
		return false
	if panel.get_parent() != app.hand_view or _deck == null:
		return false
	if not _bindings.has(panel):
		return false
	var card_id: String = _bindings[panel]["id"]
	if not _is_card(card_id):
		return false
	var index: int = panel.get_index()
	if index < 0 or index >= _deck.hand.size() or _deck.hand[index] != card_id:
		return false
	if panel.get_child_count() < 1 or not panel.get_child(0) is Label:
		return false
	return panel.get_child(0).text == card_id


func _sync_battle() -> void:
	var app = get_parent()
	if app == null or app.deck == null or app.party == null or app.enemies == null \
			or app.battle_result == null \
			or not is_instance_valid(app.battle_view) or not is_instance_valid(app.hand_view):
		if _battle != null or not _bindings.is_empty() or not _pending.is_empty():
			_clear()
		return
	# A new battle, hand owner or session retires every old binding and receipt.
	if _battle != app.battle_view or _deck != app.deck or _party != app.party \
			or _enemies != app.enemies or _result != app.battle_result or _rng != app.run_rng \
			or _intents != app.enemy_intents:
		_clear()
		_battle = app.battle_view
		_deck = app.deck
		_party = app.party
		_enemies = app.enemies
		_result = app.battle_result
		_rng = app.run_rng
		_intents = app.enemy_intents
		_turn = _turn_index(app)
		last_event.clear()
		_service = CombatSeamstressPoolBleed.new()
		var carry = app.party_carryover
		if carry is RunTornCarryover and carry._wardrobe != null:
			var wardrobe: RunPatchWardrobe = carry._wardrobe
			var current: Dictionary = wardrobe.get_snapshot() if wardrobe != null else {}
			if wardrobe != null and carry.torn != null and wardrobe.is_valid() and carry.torn.is_valid() \
					and carry.can_bind_wardrobe(wardrobe, carry.torn, current) \
					and current.heroes == app.run_heroes and current.owned == app.run_trinkets \
					and current.cards == app.run_deck and current.scraps == app.run_scraps \
					and current.gold == app.session_gold and current.seed == app.run_seed:
				_service.bind_patch_wardrobe(wardrobe, carry.torn)
			else:
				_service.bind_patch_wardrobe(null, null)
		_battle.tree_exiting.connect(_clear, CONNECT_ONE_SHOT)
	elif _turn != _turn_index(app):
		_turn = _turn_index(app)
		_cancel()
	# Never claim a panel in a session whose result does not witness these rosters.
	var consistent: bool = app.party.is_valid() and app.enemies.is_valid() \
		and app.battle_result._party == app.party and app.battle_result._enemies == app.enemies
	if not consistent:
		for panel in _bindings.keys():
			_unbind(panel)
		_cancel()
		return
	for panel in _bindings.keys():
		if not _valid_panel(app, panel):
			_unbind(panel)
	for panel in app.hand_view.get_children():
		if panel.get_child_count() < 1 or not panel.get_child(0) is Label:
			continue
		var label := panel.get_child(0) as Label
		if not _is_card(label.text):
			continue
		var index: int = panel.get_index()
		if index < 0 or index >= _deck.hand.size() or _deck.hand[index] != label.text:
			continue
		if _bindings.has(panel):
			_exclusive_energy_input(panel, label.text)
			continue
		_bind(panel, label.text)
	# Up from the action row may enter this hand only while a held area card exists.
	if not _bindings.is_empty():
		_focus_chain()


func _turn_index(app) -> int:
	if app.enemy_intents == null:
		return -1
	var turn_value: Variant = app.enemy_intents._turn_index
	if not turn_value is int:
		return -1
	return turn_value


## The only panels this adapter ever claims are the matching real held cards.
func _bind(panel: Control, card_id: String) -> void:
	var callback := _on_card_input.bind(panel, card_id)
	_bindings[panel] = {"id": card_id, "callback": callback}
	panel.focus_mode = Control.FOCUS_ALL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.get_child(0).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color("ece0c8")
	focus.set_border_width_all(3)
	panel.add_theme_stylebox_override("focus", focus)
	panel.tooltip_text = INSTRUCTION + "\n" + _rule_text(card_id)
	# The shared support presenter already recognizes these four IDs. Keep its
	# other cards untouched, but route each self card through this ONE mounted
	# input adapter rather than racing two deferred service transactions.
	_exclusive_energy_input(panel, card_id)
	panel.gui_input.connect(callback)
	_mount_cue(panel, card_id)
	_focus_chain()


## The tooltip is an immediate conditional quote, not a cached prediction.
## Refresh only held, focused/hovered Ricochet panels. Re-run the original
## resolver preflight after every live state change; it clones the battle RNG.
## Removing focus, losing legality or retiring a panel clears any old route.
func _refresh_ricochet_tooltips() -> void:
	var app = get_parent()
	if app == null:
		return
	for panel in _bindings.keys():
		if not is_instance_valid(panel):
			continue
		var id: String = _bindings[panel]["id"]
		if id != "tinker_ricochet" and id != "tinker_ricochet_plus":
			continue
		var hint := INSTRUCTION + "\n" + _rule_text(id)
		if panel.has_focus() or panel.get_viewport().gui_get_hovered_control() == panel:
			var route: Dictionary = {}
			if _eligible(panel, id) and _deck._rng == _rng and _turn_index(app) == _turn:
				var latch: CombatTinkerFirstAttack = _live_tinker_latch(app)
				if latch != null:
					# Same null-Pinned and Path discount as the actual area commit.
					route = CombatTinkerPoolAttacks.new(latch).preview_ricochet_route(
						_deck, _party, _enemies, id, _live_tinker_discount(id))
			if route.get("ok", false):
				var parts: Array[String] = []
				var positions: Array = route.get("positions", [])
				for index in range(positions.size()):
					parts.append("hit %d → enemy %d" % [index + 1, int(positions[index])])
				if not parts.is_empty():
					hint += "\nIf played now: " + "; ".join(parts)
				else:
					hint += "\nIf played now: unavailable"
			else:
				hint += "\nIf played now: unavailable"
		if panel.tooltip_text != hint:
			panel.tooltip_text = hint

func _exclusive_energy_input(panel: Control, card_id: String) -> void:
	if card_id not in ENERGY_IDS:
		return
	var support = get_parent().get_node_or_null("LiveSupportHand")
	if support == null or not support._bindings.has(panel):
		return
	var callback: Callable = support._bindings[panel]
	if panel.gui_input.is_connected(callback):
		panel.gui_input.disconnect(callback)


func _rule_text(card_id: String) -> String:
	var definition: Dictionary = _definition(card_id)
	if definition.get("id") != card_id:
		return "Unknown card rules"
	var effects: Dictionary = definition.get("effects", {})
	if card_id in MOTH_IDS:
		return "%s | Lantern Monk | %d energy | From %s\nAll living enemies %s: Blind NEXT attack (one miss per enemy); Exhaust this held copy; no target choice" % [
			definition.display_name, definition.cost, _positions(definition.from_positions),
			_positions(definition.to_positions)]
	if card_id in HARVEST_IDS:
		return "%s | Scarecrow | %d energy | From %s\nAll living enemies %s: %d base attack damage through Block, then Weak %d and literal next-turn Fear (cannot buff) to survivors; no target choice" % [
			definition.display_name, definition.cost, _positions(definition.from_positions),
			_positions(definition.to_positions), effects.damage, effects.weak]
	if card_id in GOLEM_IDS:
		var rule: String = ("%d independent hits of %d base damage per living enemy (check survival before each hit)" % [
			int(effects.get("hit_count", 0)), int(effects.get("damage", 0))]
			if card_id.begins_with("button_golem_popping_volley") else
			"%d base damage per prior popped button to each living enemy (0 pops = 0 damage; count preserved)" % [
				int(effects.get("damage_per_button_popped", 0))])
		return "%s | Button Golem | %d energy | From %s\nAll living enemies %s: %s; Block absorbs before HP; no target choice" % [
			definition.display_name, definition.cost, _positions(definition.from_positions),
			_positions(definition.to_positions), rule]
	if card_id in SKEIN_IDS:
		return "%s | Yarn Ranger | %d energy | From %s\nAll living enemies %s: Deal %d attack damage through Block before HP, THEN add Tangled %d to each struck slot. Weak/Exposed and PRE-existing Tangled (+2) apply before new Tangled; no target choice" % [
			definition.display_name, definition.cost, _positions(definition.from_positions),
			_positions(definition.to_positions), effects.damage, effects.tangled]
	if card_id in SNARE_IDS:
		return "%s | Yarn Ranger | %d energy | From %s\nAll living enemies %s: Tangled %d; prevents own-side movement and shoves, +2 damage taken from attacks; no target choice" % [
			definition.display_name, definition.cost, _positions(definition.from_positions),
			_positions(definition.to_positions), effects.tangled]
	if card_id in CROW_IDS:
		return "%s | Scarecrow | %s catalog | %d energy | From %s\nAutomatically hit the backmost living enemy only: %d base damage; bypass Block (Block remains). Weak/Exposed/Tangled apply; no target choice" % [
			definition.display_name, CombatScarecrowCrowCards.CARDS[card_id].catalog,
			definition.cost, _positions(definition.from_positions), effects.damage]
	if card_id in YARN_IDS:
		return "%s | Yarn Ranger | %d energy | From %s\nLiving Tangled enemies %s only: %d base damage each (Weak/Exposed, Tangled +2 and Block apply); requires a living Tangled target, no target choice" % [
			definition.display_name, definition.cost, _positions(definition.from_positions),
			_positions(definition.to_positions), effects.damage]
	if card_id in BLANKET_IDS:
		return "%s | Seamstress | %d energy | From %s\nAll living enemies %s: Bleed %d (%d + Seamstress passive 1) and Unravel %d; no target choice" % [
			definition.display_name, definition.cost, _positions(definition.from_positions),
			_positions(definition.to_positions), int(effects.bleed) + 1, int(effects.bleed), int(effects.unravel)]
	if card_id in ENERGY_TINKER_IDS:
		return "%s | Tinker | %d energy | From %s\nSelf: Gain %d energy; take %d self-damage (Block absorbs first), no target choice" % [
			String(definition.get("display_name", card_id)), int(definition.get("cost", -1)),
			_positions(definition.get("from_positions", [])), int(effects.get("gain_energy", 0)),
			int(effects.get("self_hp_loss", 0))]
	if card_id in ENERGY_SEAMSTRESS_IDS:
		return "%s | Seamstress | %d energy | From %s\nSelf: Gain %d energy and draw %d cards (after paying cost), no target choice" % [
			String(definition.get("display_name", card_id)), int(definition.get("cost", -1)),
			_positions(definition.get("from_positions", [])), int(effects.get("energy", 0)),
			int(effects.get("draw", 0))]
	if card_id in TINKER_IDS:
		var detail: String = ("Scatter each living enemy for %d damage once" % int(effects.get("damage", 0))
			if definition.get("target_kind") == "enemy_all" else
			"Ricochet %d random living hits, %d damage each (run RNG)" % [
				int(effects.get("hit_count", 0)), int(effects.get("damage", 0))])
		return "%s | Tinker | %d energy | From %s\nEnemies %s: %s; first attack +3, no target choice" % [
			String(definition.get("display_name", card_id)), int(definition.get("cost", -1)),
			_positions(definition.get("from_positions", [])), _positions(definition.get("to_positions", [])), detail]
	if card_id in UNRAVEL_TINKER_IDS:
		return "%s | Tinker | %d energy | From %s\nAll living enemies %s: %d damage each and Unravel %d per survivor; first attack +3, no target choice" % [
			String(definition.get("display_name", card_id)), int(definition.get("cost", -1)),
			_positions(definition.get("from_positions", [])), _positions(definition.get("to_positions", [])),
			int(effects.get("damage", 0)), int(effects.get("unravel", 0))]
	var bleed: int = int(effects.get("bleed", 0))
	return "%s | %d energy | From %s\nAll living enemies %s: Bleed %d (%d + Seamstress passive 1), no target choice" % [
		String(definition.get("display_name", card_id)), int(definition.get("cost", -1)),
		_positions(definition.get("from_positions", [])), _positions(definition.get("to_positions", [])),
		bleed + 1, bleed]


func _positions(positions: Array) -> String:
	var values: Array[String] = []
	for position in positions:
		values.append(str(position))
	if values.is_empty():
		return "?"
	return ",".join(values)


## The shared hand metadata presenter (owned by another lane) intentionally paints
## an unadvertised pool ID as "Unknown card". These authored pool IDs are real
## cards, so the adapter mounts its own visible, noninteractive face over that
## placeholder: name, cost and a compact rule for target-free area cards, or the
## unchanged self-utility rows for the energy skills. The original first-child ID
## Label, the panel's input routing and every shared control stay exactly as they
## were.
func _mount_cue(panel: Control, card_id: String) -> void:
	var definition: Dictionary = _definition(card_id)
	if definition.get("id") != card_id:
		return
	var is_tinker: bool = card_id in TINKER_IDS or card_id in UNRAVEL_TINKER_IDS \
		or card_id in ENERGY_TINKER_IDS
	var is_energy: bool = card_id in ENERGY_IDS
	var owner_color: Color = TINKER if is_tinker else SEAMSTRESS
	if card_id in YARN_IDS or card_id in SNARE_IDS or card_id in SKEIN_IDS or card_id in CROW_IDS or card_id in HARVEST_IDS:
		owner_color = INK
	if card_id in GOLEM_IDS:
		owner_color = RUST
	if card_id in MOTH_IDS:
		owner_color = SEAMSTRESS
	for existing in panel.get_children():
		if existing.name == CUE_NAME:
			panel.remove_child(existing)
			existing.free()
	var upgraded: bool = card_id.ends_with("_plus")
	var cue := PanelContainer.new()
	cue.name = CUE_NAME
	cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cue.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.border_color = owner_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	cue.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.focus_mode = Control.FOCUS_NONE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 4)
	cue.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.focus_mode = Control.FOCUS_NONE
	column.add_theme_constant_override("separation", 1)
	margin.add_child(column)
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.focus_mode = Control.FOCUS_NONE
	column.add_child(title_row)
	var name_label := _cue_label(String(definition.get("display_name", card_id)), 14, INK)
	name_label.name = "CardName"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_label)
	var cost_label := _cue_label("%d energy" % int(definition.get("cost", -1)), 11, INK)
	cost_label.name = "Cost"
	cost_label.custom_minimum_size = Vector2(48, 0)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(cost_label)
	var effects: Dictionary = definition.get("effects", {}) if definition.get("effects", {}) is Dictionary else {}
	var labels: Dictionary = {}
	var pip_state: Dictionary = {}
	if is_energy:
		# The self energy skills keep their existing face copy and behaviour.
		var variant_label := _cue_label("%s | %s | From %s" % [
			"Upgraded" if upgraded else "Base", "Tinker" if is_tinker else "Seamstress",
			_positions(definition.get("from_positions", []))], 9, owner_color)
		variant_label.name = "Variant"
		column.add_child(variant_label)
		var area_label := _cue_label("Self (no enemy target)", 11, INK)
		area_label.name = "Area"
		column.add_child(area_label)
		var detail: String = "Gain %d energy; %d self-damage (Block first)" % [
			int(effects.get("gain_energy", 0)), int(effects.get("self_hp_loss", 0))]
		if card_id in ENERGY_SEAMSTRESS_IDS:
			detail = "Gain %d energy; draw %d cards" % [
				int(effects.get("energy", 0)), int(effects.get("draw", 0))]
		var bleed_label := _cue_label(detail, 11, RUST)
		bleed_label.name = "Effect"
		column.add_child(bleed_label)
		var target_label := _cue_label("No target choice", 9, RUST)
		target_label.name = "Target"
		column.add_child(target_label)
		labels["variant"] = variant_label
		labels["area"] = area_label
		labels["bleed"] = bleed_label
		labels["target"] = target_label
	else:
		# One short rule and the drawn positions only: no "From"/"Target" prose,
		# no living-target note and no passive or first-attack arithmetic. At a
		# five-card hand the title row is wide enough for one line; a crowded
		# hand wraps the authored name instead of clipping it.
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.clip_text = false
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cost_label.add_theme_font_size_override("font_size", 10)
		cost_label.custom_minimum_size = Vector2(40, 0)
		var effect_label := _cue_label(_short_effect(definition), 13, RULE_INK)
		effect_label.name = "Effect"
		effect_label.clip_text = false
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(effect_label)
		if card_id in YARN_IDS or card_id in SNARE_IDS or card_id in SKEIN_IDS or card_id in CROW_IDS or card_id in GOLEM_IDS or card_id in MOTH_IDS or card_id in HARVEST_IDS:
			var owner_name := "Lantern Monk" if card_id in MOTH_IDS else ("Button Golem" if card_id in GOLEM_IDS else ("Scarecrow" if card_id in CROW_IDS or card_id in HARVEST_IDS else "Yarn Ranger"))
			var owner_label := _cue_label(owner_name, 9, owner_color)
			owner_label.name = "Owner"
			column.add_child(owner_label)
			labels["owner"] = owner_label
		var pips := _pip_row(definition, owner_color)
		pips.name = "Positions"
		column.add_child(pips)
		labels["effect"] = effect_label
		labels["pips"] = pips
		pip_state = _pip_state(definition)
	panel.add_child(cue)
	var binding: Dictionary = _bindings[panel]
	binding["cue"] = cue
	binding["cue_name"] = name_label
	binding["cue_cost"] = cost_label
	for key in labels:
		binding["cue_" + str(key)] = labels[key]
	if not pip_state.is_empty():
		binding["pips"] = pip_state


## The compact rule printed on one target-free area card. Amounts come from the
## authored record only: the Seamstress's Bleed face is the same +1 passive the
## resolver applies, printed without its arithmetic.
func _short_effect(definition: Dictionary) -> String:
	var effects: Dictionary = definition.get("effects", {})
	if definition.get("id", "") in HARVEST_IDS:
		return "Deal %d to all; Weak %d and Fear survivors." % [
			int(effects.get("damage", 0)), int(effects.get("weak", 0))]
	if definition.get("id", "") in MOTH_IDS:
		return "Blind NEXT attack on all; Exhaust."
	if definition.get("id", "") in GOLEM_IDS:
		if effects.has("hit_count"):
			return "Deal %d x%d independent hits to all living enemies." % [
				int(effects.get("damage", 0)), int(effects.get("hit_count", 0))]
		return "Deal %d per prior popped button to all living enemies." % int(
			effects.get("damage_per_button_popped", 0))
	if definition.get("id", "") in SKEIN_IDS:
		return "Deal %d to all; then Tangled %d." % [effects.damage, effects.tangled]
	if definition.get("id", "") in SNARE_IDS:
		return "Tangled %d to all living enemies." % effects.tangled
	if definition.get("id", "") in CROW_IDS:
		return "Deal %d to backmost living enemy; bypass Block." % effects.damage
	if definition.get("id", "") in YARN_IDS:
		return "Deal %d to living Tangled enemies only." % effects.damage
	if str(definition.get("target_kind", "")) == "enemy_random":
		return "Deal %d x%d, random." % [int(effects.get("damage", 0)),
			int(effects.get("hit_count", 1))]
	var clauses: Array[String] = []
	if effects.has("damage"):
		clauses.append("Deal %d to all." % int(effects.get("damage", 0)))
	if effects.has("bleed"):
		clauses.append("Bleed %d to all." % (int(effects.get("bleed", 0)) + 1))
	if effects.has("unravel"):
		clauses.append("Unravel %d." % int(effects.get("unravel", 0)))
	return " ".join(clauses)


## Which of the three hero slots and three enemy slots this authored card names.
func _pip_state(definition: Dictionary) -> Dictionary:
	var from_positions: Array = definition.get("from_positions", [])
	var to_positions: Array = definition.get("to_positions", [])
	var from_flags: Array[bool] = []
	var to_flags: Array[bool] = []
	for position in PIP_SLOTS:
		from_flags.append(position in from_positions)
		to_flags.append(position in to_positions)
	return {"from": from_flags, "to": to_flags,
		"thread": str(definition.get("target_kind", "")) == "enemy_all"}


## Three small source circles and three small target squares. Only a
## simultaneous every-enemy cast stitches them together, and that thread runs
## through the target-square centres; a random cast leaves the squares unlinked
## because each hit picks its own living slot.
func _pip_row(definition: Dictionary, owner_color: Color) -> Control:
	var state: Dictionary = _pip_state(definition)
	var track := PipTrack.new()
	track.name = "Positions"
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.focus_mode = Control.FOCUS_NONE
	track.pip_size = PIP_SIZE
	track.pip_gap = PIP_GAP
	track.group_gap = GROUP_GAP
	track.dash = THREAD_DASH
	track.stitch = THREAD_STITCH
	track.targets = (state["to"] as Array).duplicate()
	track.custom_minimum_size = Vector2(
		6.0 * PIP_SIZE + 4.0 * PIP_GAP + GROUP_GAP, PIP_SIZE + 3.0)
	for index in range(PIP_SLOTS.size()):
		track.add_child(_pip("From%d" % int(PIP_SLOTS[index]), bool(state["from"][index]),
			owner_color, true))
	for index in range(PIP_SLOTS.size()):
		track.add_child(_pip("To%d" % int(PIP_SLOTS[index]), bool(state["to"][index]),
			owner_color, false))
	if bool(state["thread"]):
		track.add_child(_thread(owner_color, state["to"]))
	track.layout()
	return track


func _pip(pip_name: String, filled: bool, owner_color: Color, round: bool) -> Panel:
	var pip := Panel.new()
	pip.name = pip_name
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip.focus_mode = Control.FOCUS_NONE
	pip.custom_minimum_size = Vector2(PIP_SIZE, PIP_SIZE)
	pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = owner_color if filled else Color(0, 0, 0, 0)
	style.border_color = owner_color if filled else Color(INK, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(ceilf(PIP_SIZE * 0.5)) if round else 0)
	pip.add_theme_stylebox_override("panel", style)
	return pip


## A short stitched thread: an owner-coloured seam under one drawn dash per
## target square and one per gap, never an image. The track positions every
## stitch on a real target-square centre, so the seam visibly links the squares.
func _thread(owner_color: Color, targets: Array) -> Control:
	var thread := Control.new()
	thread.name = "Thread"
	thread.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thread.focus_mode = Control.FOCUS_NONE
	var seam := ColorRect.new()
	seam.name = "Seam"
	seam.color = owner_color.darkened(0.4)
	seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seam.focus_mode = Control.FOCUS_NONE
	thread.add_child(seam)
	var squares := 0
	for flag in targets:
		if bool(flag):
			squares += 1
	var stitches: int = maxi(squares * 2 - 1, 1)
	for index in range(stitches):
		var stitch := ColorRect.new()
		stitch.name = "Stitch%d" % index
		stitch.color = CREAM
		stitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stitch.focus_mode = Control.FOCUS_NONE
		stitch.custom_minimum_size = Vector2(THREAD_DASH, THREAD_STITCH)
		thread.add_child(stitch)
	return thread


func _cue_label(value: String, point_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.focus_mode = Control.FOCUS_NONE
	label.clip_text = true
	label.add_theme_font_size_override("font_size", point_size)
	label.add_theme_color_override("font_color", color)
	return label


## Visible cue text actually mounted on the real panel, for mounted regressions.
## Area faces also report their drawn source/target pip states.
func face_text(panel) -> Dictionary:
	if not _bindings.has(panel):
		return {}
	var binding: Dictionary = _bindings[panel]
	var text := {}
	for key in ["cue_name", "cue_cost", "cue_variant", "cue_area", "cue_bleed",
			"cue_target", "cue_effect", "cue_owner"]:
		var label = binding.get(key)
		if is_instance_valid(label):
			text[key.trim_prefix("cue_")] = label.text
	var pips: Dictionary = binding.get("pips", {})
	if not pips.is_empty():
		text["from_pips"] = (pips.get("from", []) as Array).duplicate()
		text["to_pips"] = (pips.get("to", []) as Array).duplicate()
		text["thread"] = bool(pips.get("thread", false))
	return text


## Every node genuinely mounted under the sewn cue, depth first. Mounted
## regressions use it to prove the text and pips are real visible children rather
## than a layout that was never attached to the cue.
func face_children(panel) -> Array[Node]:
	var found: Array[Node] = []
	if not _bindings.has(panel):
		return found
	var cue = _bindings[panel].get("cue")
	if not is_instance_valid(cue):
		return found
	for child in cue.get_children():
		_collect_children(child, found)
	return found


func _collect_children(node: Node, found: Array[Node]) -> void:
	found.append(node)
	for child in node.get_children():
		_collect_children(child, found)


## Keep the held blank stitch panels inside the existing hand focus loop without
## touching the attack or support cards' own navigation.
func _focus_chain() -> void:
	var app = get_parent()
	if app == null or not is_instance_valid(app.end_turn_button):
		return
	var panels: Array[Control] = []
	for panel in _bindings.keys():
		if is_instance_valid(panel):
			panels.append(panel)
	if panels.is_empty():
		return
	for index in range(panels.size()):
		var panel: Control = panels[index]
		panel.focus_next = panel.get_path_to(panels[(index + 1) % panels.size()])
		panel.focus_previous = panel.get_path_to(panels[(index - 1 + panels.size()) % panels.size()])
		panel.focus_neighbor_top = panel.get_path_to(app.end_turn_button)
		panel.focus_neighbor_bottom = panel.get_path_to(app.end_turn_button)
	# Up enters the hand from the action row only when no other card owns that entry.
	if app.end_turn_button.focus_neighbor_top.is_empty():
		app.end_turn_button.focus_neighbor_top = app.end_turn_button.get_path_to(panels[0])


func _unbind(panel) -> void:
	if not _bindings.has(panel):
		return
	var callback: Callable = _bindings[panel]["callback"]
	var cue = _bindings[panel].get("cue")
	if is_instance_valid(panel):
		panel.tooltip_text = INSTRUCTION + "\n" + _rule_text(_bindings[panel]["id"])
		if panel.gui_input.is_connected(callback):
			panel.gui_input.disconnect(callback)
		if panel.get_parent() != get_parent().hand_view:
			panel.focus_mode = Control.FOCUS_NONE
			panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
			panel.focus_next = NodePath()
			panel.focus_previous = NodePath()
			panel.focus_neighbor_top = NodePath()
			panel.focus_neighbor_bottom = NodePath()
			panel.remove_theme_stylebox_override("focus")
	if is_instance_valid(cue):
		cue.free()
	_bindings.erase(panel)
	if _pending.get("panel") == panel:
		_cancel()


## Mouse click and focused Enter / Space both use the same receipt and the same
## single deferred commit. A duplicate input while one is pending is inert.
func _on_card_input(event: InputEvent, panel, card_id: String) -> void:
	if event == null or not _eligible(panel, card_id):
		return
	var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var accept: bool = event is InputEventKey and panel.has_focus() \
		and event.is_action_pressed("ui_accept") and not event.echo
	if not click and not accept:
		return
	panel.accept_event()
	if _pending.get("panel") == panel:
		return
	_cancel()
	var receipt := _receipt(panel, card_id)
	_pending = {"panel": panel, "id": card_id, "token": _token, "receipt": receipt}
	_commit.call_deferred(panel, card_id, _token, receipt)


## Battle, deck, party, enemy, result, RNG, turn, panel, index and ID receipt.
func _receipt(panel: Control, card_id: String) -> Dictionary:
	return {"battle": _battle, "deck": _deck, "party": _party, "enemies": _enemies,
		"result": _result, "rng": _rng, "turn": _turn, "panel": panel,
		"index": panel.get_index(), "id": card_id, "intents": get_parent().enemy_intents}


func _receipt_valid(receipt: Dictionary) -> bool:
	var app = get_parent()
	if app == null or not is_inside_tree():
		return false
	if app.get_node_or_null("LiveAreaAttackAction") != self:
		return false
	if receipt.get("battle") != _battle or receipt.get("deck") != _deck \
			or receipt.get("party") != _party or receipt.get("enemies") != _enemies \
			or receipt.get("result") != _result or receipt.get("rng") != _rng:
		return false
	if app.enemy_intents != receipt.get("intents") or app.enemy_intents == null:
		return false
	if app.battle_view != _battle or app.deck != _deck or app.party != _party \
			or app.enemies != _enemies or app.battle_result != _result or app.run_rng != _rng:
		return false
	var panel = receipt.get("panel")
	if not is_instance_valid(panel) or panel.get_index() != receipt.index:
		return false
	return _turn_index(app) == receipt.turn and _turn == receipt.turn


## Complete combat eligibility for one real cast. Presentation preflight only:
## the service independently revalidates and owns every mutation.
func _eligible(panel, card_id: String) -> bool:
	var app = get_parent()
	if app == null or _deck == null or _party == null or _enemies == null \
			or _result == null or not is_instance_valid(_battle):
		return false
	if not _is_card(card_id) or not _valid_panel(app, panel):
		return false
	if _bindings[panel]["id"] != card_id:
		return false
	if not panel.is_visible_in_tree() or not _battle.is_visible_in_tree():
		return false
	if app._battle_closed or not _deck.turn_active:
		return false
	if not _result.can_continue() or _result._party != _party or _result._enemies != _enemies:
		return false
	if not _party.is_valid() or _party.is_defeated():
		return false
	if not _enemies.is_valid() or _enemies.is_victorious():
		return false
	if card_id in HARVEST_IDS:
		if app.enemy_intents != _intents or _deck._rng != _rng \
				or not _receipt_valid(_receipt(panel, card_id)) \
				or not CombatScarecrowHarvestFrightCards.new()._prepare(
					_deck, _party, _enemies, card_id, 0).get("ok", false):
			return false
	if card_id in MOTH_IDS:
		if app.enemy_intents != _intents or _deck._rng != _rng \
				or not _receipt_valid(_receipt(panel, card_id)) \
				or not CombatLanternMonkMothCloudCards.new()._prepare(
					_deck, _party, _enemies, card_id, 0).get("ok", false):
			return false
	if card_id in GOLEM_IDS:
		if app.enemy_intents != _intents or _deck._rng != _rng or not _receipt_valid(_receipt(panel, card_id)) \
				or not CombatButtonGolemAreaCards.new()._prepare(
					_deck, _party, _enemies, card_id, 0).get("ok", false):
			return false
	if card_id in CROW_IDS:
		if not _receipt_valid(_receipt(panel, card_id)) or not _crow_preflight(card_id).get("ok", false):
			return false
	if card_id in YARN_IDS:
		if not _receipt_valid(_receipt(panel, card_id)) or not _yarn_playable(card_id):
			return false
	if card_id in SKEIN_IDS:
		if app.enemy_intents != _intents or _deck._rng != _rng or not _receipt_valid(_receipt(panel, card_id)) \
				or not CombatYarnRangerEndlessSkeinCards.new()._prepare(
					_deck, _party, _enemies, card_id).get("ok", false):
			return false
	if card_id in SNARE_IDS:
		if not _receipt_valid(_receipt(panel, card_id)) or not CombatYarnRangerSnareCards.new()._prepare(
				_deck, _party, _enemies, card_id).get("ok", false):
			return false
	if card_id in BLANKET_IDS:
		var authorities := _live_unravel_authorities(app)
		if app.enemy_intents != _intents or _deck._rng != _rng \
				or not _receipt_valid(_receipt(panel, card_id)) or authorities.is_empty() \
				or not CombatSeamstressV3BlanketCards.new()._prepare(
					_deck, _party, _enemies, authorities.unravel, card_id).get("ok", false):
			return false
	return app.deck == _deck and app.party == _party and app.enemies == _enemies \
		and app.battle_result == _result and app.run_rng == _rng and app.battle_view == _battle


## Target selection is refreshed from the real roster, including at deferred commit.
func _crow_backmost() -> int:
	return CombatScarecrowCrowCards.new()._backmost_living_position(_enemies.get_enemies())


func _crow_preflight(card_id: String) -> Dictionary:
	var backmost := _crow_backmost()
	if backmost == 0:
		return {"ok": false}
	return CombatScarecrowCrowCards.new()._prepare(
		_deck, _party, _enemies, card_id, backmost, {}, {})


## Read-only admission; the existing resolver remains the paid rules authority.
func _yarn_playable(card_id: String) -> bool:
	var definition := _definition(card_id)
	if _deck.energy < definition.cost or card_id not in _deck.hand:
		return false
	var owners := 0
	var resolver := CombatYarnRangerUnspoolCards.new()
	for hero in _party.get_heroes():
		if hero.id == definition.owner:
			if hero.position not in definition.from_positions or _party.is_downed(hero.position):
				return false
			var statuses: Variant = hero.get("statuses", {})
			if not statuses is Dictionary or not resolver._valid_statuses(statuses):
				return false
			owners += 1
	if owners != 1:
		return false
	var eligible := false
	for enemy in _enemies.get_enemies():
		if _enemies.is_slain(enemy.position):
			continue
		var statuses: Variant = enemy.get("statuses", {})
		if not statuses is Dictionary:
			return false
		var tangled: Variant = statuses.get("tangled", 0)
		if tangled is int and tangled > 0:
			if not resolver._valid_statuses(statuses):
				return false
			eligible = true
	return eligible


func _commit(panel, card_id: String, token: int, receipt: Dictionary) -> void:
	if not is_inside_tree() or token != _token or _pending.get("token") != token:
		return
	if _pending.get("panel") != panel or _pending.get("id") != card_id:
		return
	_pending.clear()
	if not _receipt_valid(receipt) or not _eligible(panel, card_id):
		_cancel()
		return
	# The existing resolvers revalidate every condition before mutation.
	var event: Dictionary
	var energy_before: int = receipt.deck.energy
	# Exact pre-hit roster for the app's confirmed lethal-card boundary.
	var roster_before: Array = receipt.enemies.get_enemies()
	if card_id in HARVEST_IDS:
		event = CombatScarecrowHarvestFrightCards.new().play_card(
			receipt.deck, receipt.party, receipt.enemies, card_id, 0)
	elif card_id in MOTH_IDS:
		event = CombatLanternMonkMothCloudCards.new().play_card(
			receipt.deck, receipt.party, receipt.enemies, card_id, 0)
	elif card_id in GOLEM_IDS:
		event = CombatButtonGolemAreaCards.new().play_card(
			receipt.deck, receipt.party, receipt.enemies, card_id, 0)
	elif card_id in CROW_IDS:
		event = CombatScarecrowCrowCards.new().play_card(
			receipt.deck, receipt.party, receipt.enemies, card_id, _crow_backmost())
	elif card_id in YARN_IDS:
		event = CombatYarnRangerUnspoolCards.new().play_card(
			receipt.deck, receipt.party, receipt.enemies, card_id)
	elif card_id in SKEIN_IDS:
		event = CombatYarnRangerEndlessSkeinCards.new().play_card(
			receipt.deck, receipt.party, receipt.enemies, card_id)
	elif card_id in SNARE_IDS:
		event = CombatYarnRangerSnareCards.new().play_card(
			receipt.deck, receipt.party, receipt.enemies, card_id)
	elif card_id in BLANKET_IDS:
		var authorities: Dictionary = _live_unravel_authorities(get_parent())
		if authorities.is_empty():
			_cancel()
			return
		event = CombatSeamstressV3BlanketCards.new().play_card(
			receipt.deck, receipt.party, receipt.enemies, authorities.unravel, card_id)
		if event.get("ok", false):
			# The end-turn enemy phase must consume the SAME gauge's queued skip.
			var flow: CombatRoundFlow = authorities.flow
			flow._unravel = authorities.unravel
	elif card_id in ENERGY_IDS:
		if not CombatPoolEnergyCards.new().play_card(receipt.deck, receipt.party, card_id, 0):
			_cancel()
			return
		event = {"ok": true, "card_id": card_id, "target_kind": "self"}
	elif card_id in TINKER_IDS:
		var latch: CombatTinkerFirstAttack = _live_tinker_latch(get_parent())
		if latch == null:
			_cancel()
			return
		event = CombatTinkerPoolAttacks.new(latch).play_attack(receipt.deck,
			receipt.party, receipt.enemies, card_id, 0, null,
			_live_tinker_discount(card_id))
	elif card_id in UNRAVEL_TINKER_IDS:
		# Reuse the starter presenter's latch and this battle's single Pinned
		# and Unravel authorities. A missing or foreign gauge refuses the cast.
		var shared_latch: CombatTinkerFirstAttack = _live_tinker_latch(get_parent())
		var authorities: Dictionary = _live_unravel_authorities(get_parent())
		var patch_authority: Dictionary = _live_tinker_patch_rules(get_parent())
		if shared_latch == null or authorities.is_empty() or patch_authority.is_empty():
			_cancel()
			return
		var resolver := CombatTinkerPoolUnravelAttacks.new(shared_latch)
		if not resolver.set_patch_rules(patch_authority["rules"]):
			_cancel()
			return
		# The authority's authored reduction is charged by the resolver itself.
		if not resolver.set_cost_discount(_live_tinker_discount(card_id)):
			_cancel()
			return
		event = resolver.play_attack(receipt.deck,
			receipt.party, receipt.enemies, card_id, 0,
			authorities.unravel, authorities.pinned)
		if event.get("ok", false):
			# The real round flow now shares that same gauge, so its turn end
			# consumes the queued skip. Never a second gauge or a reset.
			var flow: CombatRoundFlow = authorities["flow"]
			flow._unravel = authorities["unravel"]
	else:
		event = _service.play_card(receipt.deck, receipt.party, receipt.enemies, card_id, 0)
	if not event.get("ok", false):
		_cancel()
		return
	# A real, successful Tinker cast still feeds the battle's one Path authority,
	# so its first-hit, Scope and Clockwork state can never drift from combat.
	# A Blind-only Exhaust cast is not an attack, damage or Tinker first-hit event.
	if card_id not in MOTH_IDS:
		get_parent()._note_card_damage(receipt.enemies, roster_before)
		_report_tinker_path_play(card_id, energy_before)
	_forward_switchback_ordinary_play(card_id)
	last_event = event.duplicate(true)
	_after_cast()


## Report one committed Tinker cast to the mounted battle's own Path authority.
## A missing, stale or foreign presenter contributes nothing.
func _report_tinker_path_play(card_id: String, energy_before: int) -> void:
	var app = get_parent()
	if app == null:
		return
	var preview = app.get_node_or_null("LiveAttackPreview")
	if preview == null or not is_instance_valid(preview) or preview._battle != _battle \
			or preview._deck != _deck or preview._turn != _turn:
		return
	preview.report_tinker_play(card_id, energy_before)


## The one Path authority's authored Clockwork reduction for this card, read
## before the resolver's printed-cost check. Zero for a stale/foreign presenter.
func _live_tinker_discount(card_id: String) -> int:
	var app = get_parent()
	if app == null:
		return 0
	var preview = app.get_node_or_null("LiveAttackPreview")
	if preview == null or not is_instance_valid(preview) or preview._battle != _battle \
			or preview._deck != _deck or preview._turn != _turn:
		return 0
	return int(preview.tinker_cost_discount(card_id))


## Existing app refresh and terminal observation, in the shared attack order.
func _after_cast() -> void:
	var app = get_parent()
	_cancel()
	app._refresh_hand()
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_intents()
	if app._observe_battle_result() and is_instance_valid(app.end_turn_button):
		app.end_turn_button.grab_focus()
	_sync_battle()


func _cancel() -> void:
	_token += 1
	_pending.clear()


## Battle, hand and title lifecycle changes drop every binding, receipt and hint.
func _clear() -> void:
	_receipt_seq = 0
	_cancel()
	for panel in _bindings.keys():
		_unbind(panel)
	_bindings.clear()
	if is_instance_valid(_battle) and _battle.tree_exiting.is_connected(_clear):
		_battle.tree_exiting.disconnect(_clear)
	_battle = null
	_deck = null
	_party = null
	_enemies = null
	_result = null
	_rng = null
	_intents = null
	_turn = -1
	_service = CombatSeamstressPoolBleed.new()
	last_event.clear()


func _exit_tree() -> void:
	_clear()



func _ensure_quilt_switchback_bound() -> void:
	var app = get_parent()
	if app == null:
		return
	var presenter = app.get_node_or_null("LiveAttackPreview")
	if presenter != null and presenter.has_method("ensure_quilt_switchback_bound"):
		presenter.ensure_quilt_switchback_bound()


func _owner_for_area_card(card_id: String) -> String:
	var def: Dictionary = _definition(card_id)
	var owner: String = str(def.get("owner", ""))
	if owner in CombatQuiltBonus.HERO_IDS:
		return owner
	return ""


func _forward_switchback_ordinary_play(card_id: String) -> void:
	var app = get_parent()
	if app == null or not is_instance_valid(app):
		return
	_ensure_quilt_switchback_bound()
	var quilt: CombatQuiltBonus = app._quilt_bonus
	if quilt == null or not is_instance_valid(quilt) or not quilt is CombatQuiltBonus or not quilt.is_switchback_active():
		return
	var owner: String = _owner_for_area_card(card_id)
	if owner.is_empty() or not owner in CombatQuiltBonus.HERO_IDS:
		return
	_receipt_seq += 1
	var receipt_id := "area_%d" % _receipt_seq
	quilt.observe_confirmed_play(receipt_id, owner)
