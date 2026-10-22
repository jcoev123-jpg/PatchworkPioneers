extends Node
## Live selection only: targeting owns legality and attack cards own mutation.

signal forecast_updated

## The four authored enemy catalogs and the tier each one carries. An original
## enemy ID must map to exactly one tier or the shared gauge is not bound.
const ENEMY_TIER_CATALOGS := [
	{"path": "res://data/enemies/starter_enemies.json", "tier": "normal"},
	{"path": "res://data/enemies/run_enemies.json", "tier": "normal"},
	{"path": "res://data/enemies/m04_elites.json", "tier": "elite"},
	{"path": "res://data/enemies/boss.json", "tier": "boss"},
]

var cue: Label
var _battle: Control
var _deck: CombatDeck
var _bindings: Dictionary = {}
var _selected: Control
var _keyboard := false
var _targeting := CombatAttackTargeting.new()
var _catalog := StarterCards.new()
var _play := CombatAttackCards.new()
var _direct_fire := CombatTinkerPoolAttacks.new()
var _direct_fire_preview := CombatTinkerDirectFirePreview.new()
var _pool_strikes := CombatPoolPlainStrikes.new()
var _heavy_attacks := CombatWardenPoolHeavyAttacks.new()
var _tinker_gadgets := CombatTinkerPoolGadgets.new()
var _statuses := CombatStatuses.new()
var _on_hit := CombatOnHitStatuses.new()
## One Pinned token set and one Unravel gauge per battle session. They survive
## every hand rebuild and turn refresh, and are never reset by a preview.
var _controls := CombatSeamstressPoolControl.new()
var _pinned: CombatPinned
var _unravel: CombatUnravel
var last_event: Dictionary = {}
var _armed: Control
var _queued := false
var _token := 0
var _turn := -1
var _session: Array = []
var _stitched_preview := CombatStitchedTargetPreview.new()
var _choices: Array[int] = []
var _receipt: Dictionary = {}
var _run_map
var _target_ids: Array[String] = []
var current_forecast: Dictionary = {}
var _dragging := false
var _drag_origin := Vector2.ZERO


func _ledger() -> RunRestStitchCards:
	var app = get_parent()
	return RunRestStitchCards.new(app.run_deck, app.run_stitch_descriptors, app.run_scraps, app.run_next_stitch_id)


func _stitch_preview(id: String) -> Dictionary:
	if not id.begins_with(RunRestStitchCards.ID_PREFIX):
		return {"playable": false}
	var app = get_parent()
	return _stitched_preview.get_preview(_ledger(), app._stitch_snapshot(), _deck, app.party, app.enemies, id)


func _is_stitched(panel) -> bool:
	return _card_id(panel).begins_with(RunRestStitchCards.ID_PREFIX)


## Tier of one authored original enemy ID. Empty means unknown or classified in
## more than one tier, so the gauge is never bound to a guessed threshold.
func tier_from_catalogs(enemy_id: String, catalogs: Array) -> String:
	if not enemy_id is String or enemy_id.is_empty():
		return ""
	var found := ""
	for catalog in catalogs:
		if not catalog is Dictionary:
			return ""
		var tier: Variant = catalog.get("tier")
		var ids: Variant = catalog.get("ids")
		if not tier is String or tier not in CombatUnravel.VALID_TIERS \
				or not ids is Array:
			return ""
		if enemy_id in ids:
			if not found.is_empty() and found != tier:
				return ""
			found = tier
	return found


## Load the four authored enemy catalogs as {tier, ids}. Any unreadable or
## malformed catalog returns empty so an unauthored roster fails closed.
func authored_enemy_catalogs() -> Array:
	var catalogs: Array = []
	for entry in ENEMY_TIER_CATALOGS:
		var file := FileAccess.open(str(entry["path"]), FileAccess.READ)
		if file == null:
			return []
		var parsed = JSON.parse_string(file.get_as_text())
		if not parsed is Array:
			return []
		var ids: Array[String] = []
		for record in parsed:
			if not record is Dictionary or not record.get("id") is String \
					or String(record["id"]).is_empty():
				return []
			ids.append(record["id"])
		catalogs.append({"tier": entry["tier"], "ids": ids})
	return catalogs


## Original slot -> authored tier for this exact roster. Unknown, ambiguous or
## empty rosters return empty and therefore bind no gauge.
func enemy_tier_map(enemies: CombatEnemies) -> Dictionary:
	var tiers := {}
	if enemies == null or not enemies.is_valid():
		return tiers
	var catalogs := authored_enemy_catalogs()
	if catalogs.is_empty():
		return tiers
	var roster := enemies.get_enemies()
	if roster.is_empty():
		return tiers
	for index in range(roster.size()):
		var tier := tier_from_catalogs(str(roster[index].get("id", "")), catalogs)
		if tier.is_empty():
			return {}
		tiers[index + 1] = tier
	return tiers


## The live round flow only when it still owns exactly this battle's actors.
func _matching_flow(app, party: CombatParty, enemies: CombatEnemies) -> CombatRoundFlow:
	if app == null or app.round_flow == null or app.enemy_intents == null \
			or app.battle_result == null:
		return null
	var flow: CombatRoundFlow = app.round_flow
	if flow._deck != _deck or flow._party != party or flow._enemies != enemies \
			or flow._intents != app.enemy_intents or flow._result != app.battle_result:
		return null
	return flow


## True when this cast's authored effects have their real authorities. A gauge
## card fails closed unless the battle's shared gauge is bound to this roster,
## so no cast can succeed while its eventual skip would be ignored.
func _control_ready(party: CombatParty, enemies: CombatEnemies, card_id: String) -> bool:
	if _pinned == null or _unravel == null or _deck == null:
		return false
	if card_id in CombatSeamstressPoolControl.NEEDLE_IDS:
		return true
	if _unravel._bound_enemies != enemies:
		return false
	return _matching_flow(get_parent(), party, enemies) != null


## Hand the same gauge instance to the live round flow, then allow the cast.
## Spending, discarding and charging stay entirely with the shared resolver.
func _share_gauge(party: CombatParty, enemies: CombatEnemies, card_id: String) -> bool:
	if not _control_ready(party, enemies, card_id):
		return false
	if card_id in CombatSeamstressPoolControl.NEEDLE_IDS:
		return true
	var flow := _matching_flow(get_parent(), party, enemies)
	if flow == null:
		return false
	flow._unravel = _unravel
	return true


## Scoped picker for the six control variants: targeted legality stays with
## CombatAttackTargeting, gauge readiness is a live-session concern.
func _control_preview(id: String) -> Dictionary:
	var app = get_parent()
	var preview := _targeting.get_preview(_deck, app.party, app.enemies, id)
	if not preview.get("playable", false):
		return preview
	if not _control_ready(app.party, app.enemies, id):
		return {"playable": false, "requires_selection": false, "target_positions": []}
	return preview


func _cancel_choice() -> void:
	if is_instance_valid(_armed):
		_armed.set_meta("aiming", false)
	_dragging = false
	current_forecast.clear()
	_token += 1
	_queued = false
	_armed = null
	_choices.clear()
	_target_ids.clear()
	_receipt.clear()


func _arm_stitch() -> void:
	_choices.clear()
	_target_ids.clear()
	_receipt = get_parent()._stitch_snapshot()
	_run_map = get_parent().run_map
	get_viewport().gui_release_focus()
	_skip_automatic()


func _skip_automatic() -> void:
	var preview := _stitch_preview(_card_id(_armed))
	if not preview.playable:
		return
	while _choices.size() < 2 and not preview.halves[_choices.size()].requires_selection:
		_choices.append(0)
		_target_ids.append("")


func _choose_stitch(position: int, side: String = "") -> void:
	if _queued or not _eligible(_armed) or _receipt != get_parent()._stitch_snapshot() or _run_map != get_parent().run_map:
		return
	var preview := _stitch_preview(_card_id(_armed))
	if not preview.playable:
		return
	if _choices.size() < 2:
		var half: Dictionary = preview.halves[_choices.size()]
		if (not side.is_empty() and side != half.side) or position not in half.target_positions:
			return
		_choices.append(position)
		var app = get_parent()
		_target_ids.append(app.party.get_hero(position).id if half.side == "ally" else app.enemies.get_enemy(position).id)
		_skip_automatic()
	if _choices.size() == 2:
		_queued = true
		_commit_stitch.call_deferred(_armed, _card_id(_armed), _token, _session.duplicate(), _turn, _choices.duplicate(), _target_ids.duplicate(), _receipt.duplicate(true), _deck, _run_map)
	_refresh()


func _commit_stitch(panel, id: String, token: int, session: Array, turn: int, choices: Array, ids: Array, receipt: Dictionary, deck, map) -> void:
	var app = get_parent()
	if not is_inside_tree() or app == null or app.get_node_or_null("LiveAttackPreview") != self or token != _token or not _queued:
		return
	_queued = false
	if not _bindings.has(panel) or panel != _armed or not _eligible(panel) or _card_id(panel) != id or _bindings[panel].id != id:
		_reject_stitch()
		return
	if app.deck != deck or app.run_map != map or app._stitch_snapshot() != receipt or choices != _choices or ids != _target_ids \
		or session != [app.party, app.enemies, app.battle_result, app.run_rng, app.enemy_intents] \
		or app.enemy_intents == null or app.enemy_intents._turn_index != turn or _turn != turn:
		_reject_stitch()
		return
	var preview := _stitch_preview(id)
	if not preview.playable or choices.size() != 2:
		_reject_stitch()
		return
	for index in range(2):
		var half: Dictionary = preview.halves[index]
		if half.requires_selection:
			if choices[index] not in half.target_positions:
				_reject_stitch()
				return
			var actor: Dictionary = app.party.get_hero(choices[index]) if half.side == "ally" else app.enemies.get_enemy(choices[index])
			if actor.id != ids[index]:
				_reject_stitch()
				return
		elif choices[index] != 0:
			_reject_stitch()
			return
	last_event = CombatStitchedCards.new(_play).play_stitched(deck, app.party, app.enemies, _ledger(), id, choices[0], choices[1])
	if last_event.ok:
		_after_attack()
	else:
		_cancel_choice()
		_refresh()


## A real, current commit that failed revalidation retires its stale cue so no
## projection or armed arrow survives the rejection. Obsolete callbacks that
## arrive before this point return without touching a newer choice.
func _reject_stitch() -> void:
	_cancel_choice()
	_refresh()


func _after_attack() -> void:
	var app = get_parent()
	_cancel_choice()
	app._refresh_hand()
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_intents()
	app._observe_battle_result()
	_sync_battle()


func _process(_delta: float) -> void:
	_sync_battle()


func _input(event: InputEvent) -> void:
	_sync_battle()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_choice()
		_selected = null
		_refresh()
		return
	if event is InputEventMouseMotion and _bindings.has(_armed):
		_armed.set_meta("aim_point", event.position)
		_armed.set_meta("aiming", true)
		_armed.queue_redraw()
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _dragging:
		_dragging = false
		if is_instance_valid(_armed):
			_armed.set_meta("aiming", false)
		if _bindings.has(_armed) and not _single(_armed) and _armed.get_global_rect().has_point(event.position):
			if _is_stitched(_armed):
				_choose_stitch(0)
			else:
				_queue_attack(0)
			return
		if event.position.distance_to(_drag_origin) > 10:
			var press := InputEventMouseButton.new()
			press.position = event.position
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			_input(press)
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _bindings.has(_armed) and _is_stitched(_armed):
			var app = get_parent()
			for index in range(app.hero_panels.size()):
				var hero: Control = app.hero_panels[index]
				if hero.is_visible_in_tree() and hero.get_global_rect().has_point(event.position):
					_choose_stitch(index + 1, "ally")
					return
		var roster = get_parent().get_node_or_null("LiveEnemyRoster")
		if roster != null and is_instance_valid(_armed):
			for index in range(roster._labels.size()):
				var label: Label = roster._labels[index]
				if label.is_visible_in_tree() and label.get_global_rect().has_point(event.position):
					if _is_stitched(_armed):
						_choose_stitch(index + 1, "enemy")
					else:
						_queue_attack(index + 1 if _single(_armed) else 0)
					get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_ENTER, KEY_SPACE] and _bindings.has(_armed) and not _single(_armed):
		# Only a target-free keyboard selection owns Enter/Space. A real focused
		# control keeps its activation; P clears the inherited battle focus.
		var focus := get_viewport().gui_get_focus_owner()
		if focus == null or focus == _armed or not focus.is_visible_in_tree():
			if _is_stitched(_armed):
				if _choices.size() == 2:
					_choose_stitch(0)
			else:
				_queue_attack(0)
			get_viewport().set_input_as_handled()
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_3:
		if _bindings.has(_armed) and _is_stitched(_armed):
			_choose_stitch(event.keycode - KEY_1 + 1)
			get_viewport().set_input_as_handled()
			return
		_queue_attack(event.keycode - KEY_1 + 1)
		return
	if event.keycode != KEY_P:
		return
	var panels: Array[Control] = []
	# Cycle actual held instances, not unique IDs: identical copies own their
	# own input listeners, highlights, and pending selection.
	for panel in get_parent().hand_view.get_children():
		if _bindings.has(panel) and _eligible(panel):
			panels.append(panel)
	if panels.is_empty():
		return
	var index := panels.find(_selected)
	_selected = panels[(index + 1) % panels.size()]
	_armed = _selected
	if not _single(_armed):
		# Attack keyboard selection must not inherit End Turn/Return focus.
		get_viewport().gui_release_focus()
	_token += 1
	_queued = false
	_keyboard = true
	if _is_stitched(_armed):
		_arm_stitch()
	_refresh()
	get_viewport().set_input_as_handled()


func _single(panel) -> bool:
	if _is_stitched(panel):
		return _choices.size() < 2
	return _definition(_card_id(panel)).get("target_kind") == "enemy_single"


## Starter, plain-strike, heavy-pool and Seamstress control attacks use separate
## authored catalogs.
func _definition(card_id: String) -> Dictionary:
	if _targeting.is_pool_strike(card_id):
		return _targeting.pool_definition(card_id)
	if _targeting.is_heavy_pool_attack(card_id):
		return _targeting.heavy_definition(card_id)
	if _targeting.is_seamstress_control(card_id):
		return _targeting.control_definition(card_id)
	if _direct_fire_preview.supports(card_id):
		return _direct_fire_preview.definition(card_id)
	if _targeting.is_sight_glass(card_id):
		return _targeting.sight_glass_definition(card_id)
	return _catalog.get_definition(card_id)


func _select(event: InputEvent, panel) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _queued or not _bindings.has(panel) or not _eligible(panel) or _bindings[panel].id != _card_id(panel):
		return
	_token += 1
	_queued = false
	_armed = panel
	_dragging = true
	_drag_origin = panel.get_global_transform() * event.position
	_selected = panel
	_keyboard = true
	if _is_stitched(panel):
		_arm_stitch()
	panel.accept_event()
	_refresh()
	if _is_stitched(panel):
		return


## Scoped preview keeps CombatAttackTargeting starter-only. The direct-fire
## service itself validates each original enemy slot before it is offered.
func _target_preview(id: String) -> Dictionary:
	var app = get_parent()
	if _direct_fire_preview.supports(id):
		return _direct_fire_preview.get_preview(_deck, app.party, app.enemies, id, _direct_fire)
	if _targeting.is_seamstress_control(id):
		return _control_preview(id)
	return _targeting.get_preview(_deck, app.party, app.enemies, id)


func _queue_attack(position: int) -> void:
	if _queued or not _bindings.has(_armed) or not _eligible(_armed):
		return
	var app = get_parent()
	var id: String = _card_id(_armed)
	var preview := _target_preview(id)
	if not preview.playable or (position not in preview.target_positions if preview.requires_selection else position != 0):
		return
	_queued = true
	# A single-target target ID plus the held panel's original hand index
	# prevent an enemy replacement or equivalent-copy panel swap at commit.
	var target_id := ""
	if (_direct_fire_preview.supports(id) or _targeting.is_sight_glass(id) \
			or _targeting.is_seamstress_control(id)) and position > 0:
		target_id = str(app.enemies.get_enemy(position).get("id", ""))
	_commit.call_deferred(_armed, id, position, _token,
		app.party, app.enemies, app.battle_result, app.run_rng, _turn, target_id,
		_armed.get_index(), _deck, _deck.hand.duplicate(), app.run_map)


func _commit(panel, id: String, position: int, token: int, party, enemies, result, rng,
		turn: int, target_id: String = "", panel_index: int = -1,
		queued_deck = null, queued_hand: Array = [], queued_map = null) -> void:
	var app = get_parent()
	if not is_inside_tree() or app == null or app.get_node_or_null("LiveAttackPreview") != self or token != _token or not _queued:
		return
	_queued = false
	var direct := _direct_fire_preview.supports(id)
	var control := _targeting.is_seamstress_control(id)
	var guarded := direct or control
	if not _bindings.has(panel) or panel != _armed or not _eligible(panel) or _card_id(panel) != id or _bindings[panel].id != id:
		if guarded or _targeting.is_sight_glass(id):
			_reject_stitch()
		return
	if app.party != party or app.enemies != enemies or app.battle_result != result or app.run_rng != rng \
			or app.enemy_intents == null or app.enemy_intents._turn_index != turn or _turn != turn \
			or _session != [party, enemies, result, rng, app.enemy_intents]:
		if guarded or _targeting.is_sight_glass(id):
			_reject_stitch()
		return
	if guarded and (app.deck != queued_deck or app.run_map != queued_map or panel_index < 0 \
			or panel.get_index() != panel_index or app.deck.hand != queued_hand):
		_reject_stitch()
		return
	if direct and (app._battle_closed or target_id.is_empty() or app.deck._rng != rng):
		_reject_stitch()
		return
	var preview := _target_preview(id)
	if not preview.playable or (position not in preview.target_positions if preview.requires_selection else position != 0) \
			or (((_targeting.is_sight_glass(id) or direct) and (app._battle_closed or target_id.is_empty() \
			or app.enemies.get_enemy(position).get("id") != target_id)) \
			or (control and (app._battle_closed or target_id.is_empty() \
			or app.enemies.get_enemy(position).get("id") != target_id))):
		if guarded or _targeting.is_sight_glass(id):
			_reject_stitch()
		return
	last_event = _resolve_attack(party, enemies, id, position)
	if last_event.ok:
		_after_attack()
	elif guarded:
		_reject_stitch()


func _resolve_attack(party: CombatParty, enemies: CombatEnemies, id: String, position: int, forecast: bool = false) -> Dictionary:
	if _direct_fire_preview.supports(id):
		if forecast:
			return _direct_fire_preview.get_preview(_deck, party, enemies, id, _direct_fire)
		return _direct_fire.play_attack(_deck, party, enemies, id, position)
	if _targeting.is_sight_glass(id):
		if forecast:
			return _sight_forecast(party, enemies, id)
		return _tinker_gadgets.resolve_sight_glass(_deck, party, enemies, id, position)
	if _targeting.is_seamstress_control(id):
		if forecast:
			return _control_forecast(party, enemies, id)
		# The shared resolver owns spending, discarding and every effect; the
		# battle's own gauge is handed to the round flow first so the queued
		# skip is consumed by the real enemy phase.
		if not _share_gauge(party, enemies, id) or _controls == null:
			return {"ok": false}
		return _controls.play_card(_deck, party, enemies, _pinned, _unravel, id, position)
	if _targeting.is_pool_strike(id):
		# Reward-pool strikes have their own resolver. Starter on-hit counters,
		# Tinker bonuses, Seamstress passives and worn-patch bonuses must never
		# be layered onto them.
		if forecast:
			return _pool_forecast(party, enemies, id)
		return _pool_strikes.play_card(_deck, party, enemies, id, position)
	if _targeting.is_heavy_pool_attack(id):
		if forecast:
			return _heavy_forecast(party, enemies, id)
		return _heavy_attacks.play_attack(_deck, party, enemies, id, position)
	var owner_statuses: Dictionary = {}
	var owner: String = _catalog.get_definition(id).get("owner", "")
	for hero in party.get_heroes():
		if hero.id == owner:
			# Malformed authoritative status fields must reject rather than coerce.
			if not hero.get("statuses", {}) is Dictionary:
				return {"playable": false, "requires_selection": false, "hits": []} if forecast else {"ok": false, "hits": []}
			owner_statuses = hero.get("statuses", {})
	var enemy_statuses := {}
	for enemy in enemies.get_enemies():
		enemy_statuses[enemy.position] = enemy.get("statuses", {})
	if forecast:
		return _play.forecast_attack(_deck, party, enemies, id, owner_statuses, enemy_statuses)
	return _play.play_attack(_deck, party, enemies, id, position, owner_statuses, enemy_statuses)


## Nonattack utility forecast: status stacks and draw only, never a hit or
## starter passive. Every target comes from the same read-only legal picker.
func _sight_forecast(party: CombatParty, enemies: CombatEnemies, id: String) -> Dictionary:
	var unavailable := {"playable": false, "requires_selection": false, "hits": []}
	var preview := _targeting.get_preview(_deck, party, enemies, id)
	if not preview.get("playable", false) or not preview.get("requires_selection", false):
		return unavailable
	var effects: Dictionary = _targeting.sight_glass_definition(id).get("effects", {})
	var hits: Array[Dictionary] = []
	for position in preview.target_positions:
		var before: int = int(enemies.get_enemy(position).get("statuses", {}).get("exposed", 0))
		hits.append({"position": position, "exposed_before": before,
			"exposed_after": before + int(effects["exposed"])})
	return {"playable": true, "requires_selection": true, "hits": hits, "draw": int(effects["draw"])}


## Read-only authored control forecast. Needle Pin reports real Weak/Exposed
## damage plus any cross-hero Pinned bonus; Snag and Unpick report their Weak
## and per-slot gauge charge. It never spends, discards, pins or charges.
func _control_forecast(party: CombatParty, enemies: CombatEnemies, id: String) -> Dictionary:
	var unavailable := {"playable": false, "requires_selection": false, "hits": []}
	var preview := _control_preview(id)
	if not preview.get("playable", false) or not preview.get("requires_selection", false):
		return unavailable
	var definition: Dictionary = _targeting.control_definition(id)
	var effects: Variant = definition.get("effects")
	if not effects is Dictionary:
		return unavailable
	var needle := id in CombatSeamstressPoolControl.NEEDLE_IDS
	var owner_statuses: Dictionary = {}
	if needle:
		var owner_count := 0
		for hero in party.get_heroes():
			if hero.get("id") == "seamstress":
				owner_count += 1
				var statuses: Variant = hero.get("statuses", {})
				if not statuses is Dictionary or not _valid_statuses(statuses):
					return unavailable
				owner_statuses = statuses
		if owner_count != 1:
			return unavailable
	var hits: Array[Dictionary] = []
	var positions: Array[int] = preview["target_positions"]
	for position in positions:
		var enemy: Dictionary = enemies.get_enemy(position)
		var defender: Variant = enemy.get("statuses", {})
		if enemy.is_empty() or enemies.is_slain(position) \
				or not defender is Dictionary or not _valid_statuses(defender):
			return unavailable
		var hit: Dictionary = {"position": position}
		if needle:
			var bonus := 0
			if _pinned != null:
				bonus = _pinned.bonus_for_attack(enemies, position, "seamstress")
			hit["damage"] = _statuses.adjusted_attack_damage(
				int(effects["damage"]) + bonus, owner_statuses, defender)
			hit["pinned_bonus"] = bonus
		else:
			var gauge: Dictionary = _unravel.get_snapshot(position) if _unravel != null else {}
			if gauge.size() != 4:
				return unavailable
			var amount: int = int(effects["unravel"])
			var current: int = int(gauge["gauge"])
			var threshold: int = int(gauge["threshold"])
			hit["unravel"] = amount
			hit["gauge"] = current
			hit["gauge_after"] = mini(current + amount, threshold)
			hit["threshold"] = threshold
			if id in CombatSeamstressPoolControl.SNAG_IDS:
				hit["weak_applied"] = int(effects["weak"])
		hits.append(hit)
	return {"playable": true, "requires_selection": true, "hits": hits}


## Read-only forecast for the four plain pool strikes. It mirrors the resolver's
## statuses-only damage (real Weak on the owner, real Exposed on each target) and
## never mutates a card, roster, status or RNG. Brass Buckle's authored Block
## gain stays a separate self effect, never extra target damage.
func _pool_forecast(party: CombatParty, enemies: CombatEnemies, id: String) -> Dictionary:
	var unavailable := {"playable": false, "requires_selection": false, "hits": []}
	var definition := _definition(id)
	var preview := _targeting.get_preview(_deck, party, enemies, id)
	if not preview.get("playable", false) or not preview.get("requires_selection", false):
		return unavailable
	var owner: Variant = definition.get("owner")
	var owner_statuses: Dictionary = {}
	var owner_count := 0
	for hero in party.get_heroes():
		if hero.get("id") == owner:
			owner_count += 1
			var statuses: Variant = hero.get("statuses", {})
			if not statuses is Dictionary or not _valid_statuses(statuses):
				return unavailable
			owner_statuses = statuses
	if owner_count != 1:
		return unavailable
	var effects: Variant = definition.get("effects")
	if not effects is Dictionary:
		return unavailable
	var damage: Variant = effects.get("damage")
	if not damage is int or damage <= 0:
		return unavailable
	var hits: Array[Dictionary] = []
	var positions: Array[int] = preview["target_positions"]
	for position in positions:
		var enemy: Dictionary = enemies.get_enemy(position)
		var defender: Variant = enemy.get("statuses", {})
		if enemy.is_empty() or enemies.is_slain(position) \
				or not defender is Dictionary or not _valid_statuses(defender):
			return unavailable
		hits.append({"position": position,
			"damage": _statuses.adjusted_attack_damage(damage, owner_statuses, defender)})
	return {"playable": true, "requires_selection": true, "hits": hits}


## Identical read-only damage preview, but express Pin and Pound as two
## sequential hits on the chosen target, not a single damage packet.
func _heavy_forecast(party: CombatParty, enemies: CombatEnemies, id: String) -> Dictionary:
	var preview := _pool_forecast(party, enemies, id)
	if not preview.playable:
		return preview
	var effects: Dictionary = _definition(id).get("effects", {})
	var count: int = int(effects.get("hits", 1))
	for hit in preview.hits:
		hit["hit_count"] = count
	return preview


## Same shape rules as the shared status services: only known, non-negative ints.
func _valid_statuses(statuses: Dictionary) -> bool:
	for name in statuses:
		if not name is String or name not in ["bleed", "weak", "exposed"]:
			return false
		var count: Variant = statuses[name]
		if not count is int or count < 0:
			return false
	return true


## Keyboard hint for the legal slots this preview actually offers.
func _key_hint(positions) -> String:
	var keys: PackedStringArray = []
	if positions is Array:
		for position in positions:
			keys.append(str(position))
	if keys.is_empty():
		return "1-%d" % CombatEnemies.MAX_ENEMIES
	if keys.size() > 1 and int(positions.back()) - int(positions.front()) == keys.size() - 1:
		return "%s-%s" % [keys[0], keys[keys.size() - 1]]
	return ", ".join(keys)


func _card_id(panel) -> String:
	if not is_instance_valid(panel) or panel.get_child_count() == 0 or not panel.get_child(0) is Label:
		return ""
	return panel.get_child(0).text


func _eligible(panel) -> bool:
	var app = get_parent()
	if not is_inside_tree() or app == null or not is_instance_valid(panel) or not is_instance_valid(_battle) or _deck == null:
		return false
	if app.deck != _deck or app.battle_view != _battle or not is_instance_valid(app.hand_view):
		return false
	if not _battle.is_ancestor_of(app.hand_view) or not _battle.is_visible_in_tree() or not panel.is_visible_in_tree() or panel.get_parent() != app.hand_view:
		return false
	if app.party == null or app.enemies == null or not app.party.is_valid() or not app.enemies.is_valid():
		return false
	if not _deck.turn_active or app.party.is_defeated() or app.enemies.is_victorious():
		return false
	if app.battle_result == null or not app.battle_result.can_continue():
		return false
	if app.battle_result._party != app.party or app.battle_result._enemies != app.enemies:
		return false
	var id := _card_id(panel)
	var index: int = panel.get_index()
	return (_targeting.supports(id) or _direct_fire_preview.supports(id) or _stitch_preview(id).playable) and index < _deck.hand.size() and _deck.hand[index] == id


func _sync_battle() -> void:
	var app = get_parent()
	if app.deck == null or not is_instance_valid(app.battle_view) or not is_instance_valid(app.hand_view):
		_clear()
		return
	if _battle != app.battle_view or _deck != app.deck:
		_clear()
		_battle = app.battle_view
		_deck = app.deck
		_session = [app.party, app.enemies, app.battle_result, app.run_rng, app.enemy_intents]
		_play = CombatAttackCards.new()
		_direct_fire = CombatTinkerPoolAttacks.new(_play._tinker)
		# Capture the genuine run's sewn wearer projection at battle entry only.
		# An invalid present binding must reject attacks, not fall back to vanilla.
		var carry := app.party_carryover as RunTornCarryover
		if carry != null and carry._wardrobe != null:
			var wardrobe: RunPatchWardrobe = carry._wardrobe
			var current: Dictionary = wardrobe.get_snapshot()
			if carry.can_bind_wardrobe(wardrobe, carry.torn, current) \
					and current.heroes == app.run_heroes and current.owned == app.run_trinkets \
					and current.cards == app.run_deck and current.scraps == app.run_scraps \
					and current.gold == app.session_gold and current.seed == app.run_seed:
				_play.bind_patch_wardrobe(wardrobe, carry.torn)
			else:
				_play.bind_patch_wardrobe(null, null)
		last_event = {}
		# One Pinned set and one Unravel gauge live for this whole battle session.
		# They are created here and never recreated or reset by a hand refresh.
		_pinned = CombatPinned.new()
		_unravel = CombatUnravel.new()
		var tiers := enemy_tier_map(app.enemies)
		if tiers.is_empty() or not _unravel.bind_roster(app.enemies, tiers):
			# Keep the owned gauge unbound: a gauge-card cast then fails closed.
			_unravel = CombatUnravel.new()
		_battle.tree_exiting.connect(_clear, CONNECT_ONE_SHOT)
		cue = Label.new()
		cue.name = "AttackPreviewCue"
		cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cue.add_theme_font_size_override("font_size", 18)
		cue.custom_minimum_size.y = 44
		cue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Mount idle: only a real forecast should claim the lower-third strip.
		cue.visible = false
		var column: Node = app.hand_view.get_parent()
		column.add_child(cue)
		column.move_child(cue, app.hand_view.get_index())
	if _session != [app.party, app.enemies, app.battle_result, app.run_rng, app.enemy_intents]:
		_cancel_choice()
		_session = [app.party, app.enemies, app.battle_result, app.run_rng, app.enemy_intents]
	if app.enemy_intents != null and _turn != app.enemy_intents._turn_index:
		_turn = app.enemy_intents._turn_index
		_play.start_player_turn()
		_cancel_choice()
	if _bindings.has(_armed) and _is_stitched(_armed) and (_receipt != app._stitch_snapshot() or _run_map != app.run_map):
		_cancel_choice()
	for panel in _bindings.keys():
		if not _eligible(panel) or _bindings[panel].id != _card_id(panel):
			_unbind(panel)
	for panel in app.hand_view.get_children():
		if not _eligible(panel) or _bindings.has(panel):
			continue
		# Labels ignore input; the real card panel receives selection.
		panel.get_child(0).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var entered := _hover.bind(panel)
		var exited := _leave.bind(panel)
		var input := _select.bind(panel)
		_bindings[panel] = {"id": _card_id(panel), "entered": entered, "exited": exited, "input": input}
		panel.gui_input.connect(input)
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.mouse_entered.connect(entered)
		panel.mouse_exited.connect(exited)
	_refresh()


func _hover(panel: Control) -> void:
	if not _bindings.has(panel) or not _eligible(panel) or _bindings[panel].id != _card_id(panel):
		return
	_selected = panel
	_keyboard = false
	_refresh()


func _leave(panel: Control) -> void:
	if _selected == panel and not _keyboard and _armed != panel:
		_selected = null
		_refresh()


## No hovered, armed or P-selected attack: retire the strip completely. An empty
## label that keeps its authored minimum height would still hold 44 px of the
## lower third, so idle also hides the cue and the container drops it.
func _idle_cue() -> void:
	cue.text = ""
	cue.visible = false


## Any live forecast owns the strip, so reveal it before writing the reading.
func _show_cue() -> void:
	cue.visible = true


func _refresh() -> void:
	current_forecast = {}
	if not is_instance_valid(cue):
		return
	if not _bindings.has(_selected) or not _eligible(_selected):
		_selected = null
		_idle_cue()
		return
	_show_cue()
	var app = get_parent()
	var id := _card_id(_selected)
	if _is_stitched(_selected):
		var stitched := _stitch_preview(id)
		if not stitched.playable:
			cue.text = "Unavailable stitched card"
			return
		var names: PackedStringArray = []
		for half in stitched.halves:
			names.append(_catalog.get_definition(half.card_id).display_name)
		var details: PackedStringArray = []
		for index in range(2):
			var half: Dictionary = stitched.halves[index]
			details.append("%d: %s %s" % [index + 1, half.side, str(half.target_positions) if half.requires_selection else "automatic (0), slots " + str(half.affected_positions)])
		var controls := "Half %d: 1-3 / click hero or enemy" % mini(_choices.size() + 1, 2)
		if _selected == _armed and _choices.size() == 2:
			controls = "Enter / Space / click card: cast"
		cue.text = "%s | %d energy | %s\n%s; Esc: cancel" % [" / ".join(names), stitched.cost, "; ".join(details), controls]
		if _selected == _armed and _choices.size() == 2 and _receipt == app._stitch_snapshot() and _run_map == app.run_map:
			current_forecast = CombatStitchedEffectForecast.new().get_forecast(_ledger(), _receipt, _deck, app.party, app.enemies, id, _choices[0], _choices[1], CombatStitchedCards.new(_play))
			if current_forecast.playable:
				var outcomes: PackedStringArray = []
				for index in range(2):
					var half: Dictionary = current_forecast.halves[index]
					var effects: PackedStringArray = []
					for hit in half.get("hits", []):
						effects.append("enemy %d: %d damage" % [hit.position, hit.damage])
					if half.has("effect"):
						effects.append("%s %d" % [half.effect.replace("_", " ").capitalize(), half.amount])
					outcomes.append("%d: %s" % [index + 1, ", ".join(effects)])
				cue.text = "%s | %d energy\nProjected %s" % [" / ".join(names), stitched.cost, "; ".join(outcomes)]
				forecast_updated.emit()
			else:
				cue.text = "Unavailable stitched outcome; Esc: cancel"
		return
	var is_pool := _targeting.is_pool_strike(id)
	var is_heavy := _targeting.is_heavy_pool_attack(id)
	var is_direct := _direct_fire_preview.supports(id)
	var definition := _definition(id)
	if definition.is_empty():
		# Fail closed on an unrecognised record instead of formatting a partial card.
		cue.text = "Unavailable card rules"
		return
	var preview := _resolve_attack(app.party, app.enemies, id, 0, true)
	if _targeting.is_sight_glass(id):
		current_forecast = preview.duplicate(true)
		var descriptions: PackedStringArray = []
		for target in preview.get("hits", []):
			descriptions.append("%d: Exposed %d → %d; draw %d card" % [
				target.position, target.exposed_before, target.exposed_after, int(preview.draw)])
		var detail := "Unavailable: no legal targets or energy"
		if preview.playable:
			detail = "Choose one enemy slot: " + "; ".join(descriptions)
		var legal: Array[int] = []
		for target in preview.get("hits", []):
			legal.append(int(target.position))
		cue.text = "%s | %d energy | P / click card; %s / click enemy\n%s" % [
			definition.display_name, definition.cost, _key_hint(legal), detail]
		return
	if _targeting.is_seamstress_control(id):
		current_forecast = preview.duplicate(true)
		var details: PackedStringArray = []
		var legal_slots: Array[int] = []
		for hit in preview.get("hits", []):
			legal_slots.append(int(hit.position))
			if hit.has("damage"):
				var damage_line := "%d: %d damage" % [int(hit.position), int(hit.damage)]
				if int(hit.get("pinned_bonus", 0)) > 0:
					damage_line += " (+%d Pinned)" % int(hit.pinned_bonus)
				details.append(damage_line)
			else:
				var charge_line := "%d: " % int(hit.position)
				if int(hit.get("weak_applied", 0)) > 0:
					charge_line += "Weak %d, " % int(hit.weak_applied)
				charge_line += "Unravel %d → %d/%d%s" % [int(hit.unravel),
					int(hit.gauge_after), int(hit.threshold),
					" skip" if int(hit.gauge_after) == int(hit.threshold) else ""]
				details.append(charge_line)
		var reading := "Unavailable: no legal target or shared gauge"
		if preview.playable:
			reading = "Choose one enemy slot: " + "; ".join(details)
		cue.text = "%s | %d energy | P / click card; %s / click enemy\n%s" % [
			definition.display_name, definition.cost, _key_hint(legal_slots), reading]
		return
	var targets: PackedStringArray = []
	# Only attach on-hit counters to starter attacks. Reward-pool strikes have
	# no starter passive or worn-patch hook of their own.
	var additions: Dictionary = {}
	if not is_pool and not is_heavy and not is_direct and preview.playable:
		additions = _on_hit.status_for_confirmed_hit(id, true)
		if _play._patches != null:
			var patch_statuses: Dictionary = _play._patches.exposed_for_first_hit(definition.get("owner", ""))
			for status in patch_statuses:
				additions[status] = additions.get(status, 0) + patch_statuses[status]
	for hit in preview.hits:
		var detail := ("%d: 2 hits x %d damage each" % [hit.position, hit.damage]
			if int(hit.get("hit_count", 1)) == 2 else "%d: %d damage" % [hit.position, hit.damage])
		var enemy: Dictionary = app.enemies.get_enemy(hit.position)
		var current: Dictionary = enemy.get("statuses", {})
		for status in additions:
			var amount: int = additions[status]
			var previous: int = current.get(status, 0)
			detail += " (%s %d → %d on confirmed hit)" % [status.capitalize(), previous, previous + amount]
		if is_direct and int(hit.get("exposed_added", 0)) > 0:
			detail += " (Exposed %d → %d after hit)" % [hit.exposed_before, hit.exposed_after]
		targets.append(detail)
	var description := "Unavailable: no legal targets or energy"
	if preview.playable:
		description = ("Choose one enemy slot: " if preview.requires_selection else "All enemies in slots: ") + "; ".join(targets)
		if is_pool:
			# The Warden's own Block is a self effect; never fold it into damage.
			var effects: Dictionary = definition.get("effects", {})
			var block: int = int(effects.get("block", 0))
			if block > 0:
				description += " | %s gains %d Block" % [
					String(definition.get("owner", "")).capitalize(), block]
	var controls: String
	if not _single(_selected):
		controls = "P: select; Enter / Space / click card: cast"
	elif is_pool or is_heavy or is_direct:
		# Report exactly the slots this forecast offers, never a wider key row.
		var legal: Array[int] = []
		for hit in preview.hits:
			legal.append(int(hit.position))
		controls = "P / click card; %s / click enemy" % _key_hint(legal)
	else:
		controls = "P / click card; 1-3 / click enemy"
	if is_direct:
		controls += "; Tinker FROM %s" % _key_hint(definition.from_positions)
	cue.text = "%s | %d energy | %s\n%s" % [definition.display_name, definition.cost, controls, description]


func _unbind(panel) -> void:
	var binding: Dictionary = _bindings[panel]
	if is_instance_valid(panel):
		if panel.gui_input.is_connected(binding.input):
			panel.gui_input.disconnect(binding.input)
		if panel.mouse_entered.is_connected(binding.entered):
			panel.mouse_entered.disconnect(binding.entered)
		if panel.mouse_exited.is_connected(binding.exited):
			panel.mouse_exited.disconnect(binding.exited)
	_bindings.erase(panel)
	if _selected == panel:
		_selected = null
	if _armed == panel:
		_cancel_choice()


func _clear() -> void:
	_cancel_choice()
	_turn = -1
	for panel in _bindings.keys():
		_unbind(panel)
	if is_instance_valid(_battle) and _battle.tree_exiting.is_connected(_clear):
		_battle.tree_exiting.disconnect(_clear)
	if is_instance_valid(cue):
		cue.queue_free()
	cue = null
	_battle = null
	_deck = null
	_session = []
	# Return/title retires this battle's gauge from its round flow so no old
	# charge or skip can leak into the next fight.
	var app = get_parent()
	if app != null and app.round_flow != null and _unravel != null \
			and app.round_flow._unravel == _unravel:
		app.round_flow._unravel = null
	_pinned = null
	_unravel = null
	_play = CombatAttackCards.new() # Return/title retires the prior battle's wearer latch.
	_direct_fire = CombatTinkerPoolAttacks.new(_play._tinker)
	_selected = null
