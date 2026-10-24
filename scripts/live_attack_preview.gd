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
var _fray: CombatFrayfinderMitt
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
var _combo_oracle := CombatPoolComboAttackPreview.new()
var _warden_combo := CombatWardenPoolComboAttacks.new()
var _pinned: CombatPinned
var _unravel: CombatUnravel
## The selected Seamstress Path card of THIS routed battle: its genuine receipt,
## deck, party, roster and the one gauge shared with the round flow.
var _path_cards: CombatSeamstressPathCards
var _path_card: Dictionary = {}
## The one Tinker Path authority of THIS routed battle. It owns the selected
## card's commit, the per-turn Wind-up credit and Clockwork discount, and the
## first-attack/Scope bonuses reported by every successful Tinker play.
var _tinker_path: CombatTinkerPathHand
var _routed_gauge_shared := false
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
	if _pinned == null or _unravel == null or _deck == null \
			or not _controls.needle_patch_preview().get("ok", false) \
			or not _controls.head_binding_valid():
		return false
	if card_id in CombatSeamstressPoolControl.NEEDLE_IDS:
		return true
	if _unravel._bound_enemies != enemies:
		return false
	var flow := _matching_flow(get_parent(), party, enemies)
	# Never replace a different authority installed on this round flow.
	# Only an unbound flow, or the exact battle gauge, can accept a cast.
	return flow != null and (flow._unravel == null or flow._unravel == _unravel)


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


## Bind this battle's selected Path card to the genuine receipt, deck, party,
## roster and the one gauge already shared with the round flow. Only a receipt
## the combat resolver authenticates can name a Path card.
func _bind_path_cards(app) -> void:
	_path_cards = null
	_path_card.clear()
	if app == null or _deck == null or _unravel == null:
		return
	var receipt: Variant = app.run_seamstress_path_receipt
	if not receipt is Dictionary or (receipt as Dictionary).is_empty():
		return
	var resolver := CombatSeamstressPathCards.new(receipt, _unravel)
	if not resolver.is_valid_choice():
		return
	var path: Dictionary = RunSeamstressPathChoice.new().get_path(resolver.get_path_id())
	var card: Variant = path.get("card")
	if not card is Dictionary or str((card as Dictionary).get("id", "")) != resolver.get_card_id():
		return
	_path_cards = resolver
	_path_card = (card as Dictionary).duplicate(true)


func _is_path_card(card_id: String) -> bool:
	return not _path_card.is_empty() and card_id == str(_path_card.get("id", ""))


## True only while this battle really holds exactly one copy of the selected
## Path card and no copy of the other Path's card.
func path_ready() -> bool:
	if _path_cards == null or _path_card.is_empty() or _deck == null:
		return false
	var app = get_parent()
	if app == null or app.deck != _deck or not _path_cards.is_valid_choice():
		return false
	var card_id: String = str(_path_card["id"])
	var other_id: String = CombatSeamstressPathCards.FRAY_ID \
		if card_id == CombatSeamstressPathCards.LEECH_STITCH_ID \
		else CombatSeamstressPathCards.LEECH_STITCH_ID
	var occurrences := 0
	for pile in [_deck.draw_pile, _deck.hand, _deck.discard_pile]:
		if (pile as Array).has(other_id):
			return false
		occurrences += (pile as Array).count(card_id)
	return occurrences == 1


## Legal original enemy slots, straight from the shared resolver's own preview.
## Presentation never simulates Bleed, the heal or the Unravel charge itself.
func _path_positions(card_id: String) -> Array[int]:
	var positions: Array[int] = []
	if not _is_path_card(card_id) or not path_ready():
		return positions
	var app = get_parent()
	for position in range(1, CombatEnemies.MAX_ENEMIES + 1):
		if bool(_path_cards.preview(_deck, app.party, app.enemies, card_id, position).get("ok", false)):
			positions.append(position)
	return positions


## Public read-only admission for the mounted hand face and tests.
func path_preview(card_id: String) -> Dictionary:
	var positions := _path_positions(card_id)
	return {"playable": not positions.is_empty(), "requires_selection": true,
		"target_positions": positions}


func _path_quote(card_id: String, position: int) -> Dictionary:
	if not _is_path_card(card_id) or not path_ready():
		return {"ok": false}
	var app = get_parent()
	return _path_cards.preview(_deck, app.party, app.enemies, card_id, position)


## Fray's skipped action is consumed by this battle's own enemy phase, so the
## battle gauge is handed to the matching round flow before the commit.
func _share_path_gauge() -> bool:
	var app = get_parent()
	if _unravel == null or app == null or app.enemies == null:
		return false
	if _unravel._bound_enemies != app.enemies:
		return false
	var flow := _matching_flow(app, app.party, app.enemies)
	if flow == null:
		return false
	if flow._unravel != null and flow._unravel != _unravel:
		return false
	flow._unravel = _unravel
	return true


## One exact projection of a Path card's own committed effects on an original
## enemy slot: Bleed before/after, Unravel gauge before/after and the weak ally
## heal. Nothing here resolves the later turn-end Bleed tick.
func _path_quote_text(position: int, quote: Dictionary) -> String:
	if not quote.get("ok", false):
		return "%d: unavailable" % position
	var app = get_parent()
	var parts: PackedStringArray = []
	var bleed: int = int(quote.get("bleed_applied", 0))
	if bleed > 0:
		var enemy: Dictionary = app.enemies.get_enemy(position)
		var bleed_before: int = int(enemy.get("statuses", {}).get("bleed", 0))
		parts.append("Bleed %d → %d" % [bleed_before, bleed_before + bleed])
	var unravel: int = int(quote.get("unravel_applied", 0))
	if unravel > 0 and _unravel != null:
		var gauge: Dictionary = _unravel.get_snapshot(position)
		if gauge.size() == 4:
			var gauge_after: int = mini(int(gauge["gauge"]) + unravel, int(gauge["threshold"]))
			parts.append("Unravel %d → %d/%d%s" % [unravel, gauge_after,
				int(gauge["threshold"]), " skip" if gauge_after == int(gauge["threshold"]) else ""])
	if int(quote.get("healed_slot", 0)) > 0:
		var hero: Dictionary = app.party.get_hero(int(quote["healed_slot"]))
		if not hero.is_empty():
			var healed: int = int(quote.get("healed_amount", 0))
			parts.append("heal %s %d → %d/%d" % [str(hero.get("id", "")).capitalize(), healed,
				int(hero.get("hp", 0)) + healed, int(hero.get("max_hp", 0))])
	if parts.is_empty():
		return "%d: no effect" % position
	return "%d: %s" % [position, ", ".join(parts)]


## Bind this battle's selected Tinker Path to the genuine claimed setup, the
## detached run receipt, this real deck and party. Only a matching trio can name
## a Path card or expose the one rules authority the hand commits through.
func _bind_tinker_path(app) -> void:
	_tinker_path = null
	if app == null or _deck == null or app.party == null:
		return
	var receipt: Variant = app.run_tinker_path_receipt
	var choice: Variant = app.run_tinker_path_choice
	if not receipt is Dictionary or (receipt as Dictionary).is_empty():
		return
	if not choice is RunTinkerPathChoice or not (choice as RunTinkerPathChoice).has_selection():
		return
	var selection: Dictionary = (choice as RunTinkerPathChoice).get_selection()
	if String(selection.get("path_id", "")) != String((receipt as Dictionary).get("path_id", "")) \
			or String(selection.get("card_id", "")) != String((receipt as Dictionary).get("card_id", "")) \
			or String(selection.get("passive_id", "")) != String((receipt as Dictionary).get("passive_id", "")):
		return
	var hand := CombatTinkerPathHand.new(choice, _deck, app.party)
	if hand.is_bound():
		_tinker_path = hand


## True only while this battle holds exactly one copy of the selected Tinker
## Path card, no copy of the other Path's card, and its genuine authority.
func tinker_ready() -> bool:
	if _tinker_path == null or _deck == null:
		return false
	var app = get_parent()
	return app != null and app.deck == _deck and _tinker_path.is_bound()


func _tinker_hero() -> Dictionary:
	var app = get_parent()
	if app == null or app.party == null:
		return {}
	for hero in app.party.get_heroes():
		if hero.get("id") == "tinker":
			return hero
	return {}


func _tinker_position() -> int:
	return int(_tinker_hero().get("position", 0))


func _is_tinker_path_card(card_id: String) -> bool:
	if _tinker_path == null or card_id.is_empty():
		return false
	return card_id == String(_tinker_path._selected_card.get("id", ""))


## Read-only quote of the genuine held Path card through the shared authority's
## own authenticated metadata/position/energy check. A preview never charges,
## discards or arms anything.
func tinker_path_quote(card_id: String) -> Dictionary:
	if not _is_tinker_path_card(card_id) or not tinker_ready():
		return {"ok": false}
	var card: Dictionary = _tinker_path._selected_card
	return _tinker_path.preview_path_card(card_id, String(card.get("owner", "")),
		int(card.get("cost", -1)), _tinker_position(), String(card.get("target_kind", "")))


## Public admission for the mounted shared hand: the genuine selected Tinker Path
## card of this battle, bound to its authenticated authority right now.
func tinker_path_is_card(card_id: String) -> bool:
	return _is_tinker_path_card(card_id) and tinker_ready()


## Public read-only admission for the mounted hand face and tests.
func tinker_path_playable(card_id: String) -> bool:
	return bool(tinker_path_quote(card_id).get("ok", false))


## Target-free hand commit of the selected Path card. The PRESENTED face metadata
## and the real Tinker position are authenticated by the shared battle service;
## spending, discarding and every effect stay inside that one authority.
func commit_tinker_path_card(card_id: String, owner: String, printed_cost: int,
		target_kind: String) -> Dictionary:
	if not tinker_ready():
		return {"ok": false}
	var receipt: Dictionary = _tinker_path.commit_path_card(card_id, owner,
		printed_cost, _tinker_position(), target_kind)
	if not receipt.get("ok", false):
		return receipt
	_apply_tinker_path_receipt(receipt)
	return receipt


## Arm the authored Path bonus on the same battle-scoped first-attack latch every
## Tinker resolver and forecast already reads, so the projected +4 is real damage.
func _apply_tinker_path_receipt(receipt: Dictionary) -> void:
	if not bool(receipt.get("arms_scope", false)) or _play == null:
		return
	var effects: Variant = _tinker_path._selected_card.get("effects", {})
	var bonus: int = int((effects as Dictionary).get("next_attack_damage_bonus", 0)) \
		if effects is Dictionary else 0
	_play._tinker.arm_path_bonus(bonus)


## The battle's one Path authority's authored Clockwork reduction for a live cast,
## evaluated BEFORE any resolver's printed-cost check. Zero for every other card,
## a spent discount or a foreign/stale authority.
func tinker_cost_discount(card_id: String) -> int:
	if _tinker_path == null or _deck == null or not _deck.turn_active or not tinker_ready():
		return 0
	var tinker := _tinker_hero()
	if tinker.is_empty() or int(tinker.get("hp", 0)) <= 0:
		return 0
	return _tinker_path.get_rules().discount_for(card_id, int(tinker["position"]),
		int(tinker["hp"]))


## One real, successful Tinker card play is reported to this battle's one Path
## authority. It revalidates the card, the live Tinker position/HP and the
## pre-spend energy before recording the first hit, Scope and Clockwork state.
## The resolver already charged the authority's own discounted cost, so nothing
## is refunded here.
func report_tinker_play(card_id: String, energy_before: int) -> Dictionary:
	if _tinker_path == null or not tinker_ready():
		return {}
	var tinker := _tinker_hero()
	if tinker.is_empty() or int(tinker.get("hp", 0)) <= 0:
		return {}
	var result: Dictionary = _tinker_path.get_rules().commit_successful(card_id,
		int(tinker["position"]), int(tinker["hp"]), energy_before, true)
	if not result.get("ok", false):
		return {}
	_apply_tinker_path_receipt(result)
	return result


## The routed round flow owns the real deck turn. This advances only the Path's
## own view of it: the previous turn closes (Scope expires, Clockwork re-arms)
## and the new one opens, claiming a queued Wind-up credit exactly once after the
## deck reset.
func _advance_tinker_path_turn() -> void:
	if _tinker_path == null or not tinker_ready() or _deck == null or not _deck.turn_active:
		return
	_tinker_path.release_open_turn()
	_tinker_path.adopt_open_turn()


## A selectable combo must belong to this actual routed battle, with the
## identical gauge that the enemy phase will consume. The oracle is detached.
func _combo_preview(id: String) -> Dictionary:
	var app = get_parent()
	if not app._combo_battle_current() or not _control_ready(app.party, app.enemies, id):
		return {"playable": false, "requires_selection": false, "target_positions": [], "targets": []}
	return _combo_oracle.get_preview(_deck, app.party, app.enemies,
		_pinned, _unravel, _play._tinker, id, 0, _play._patches)


## Scoped picker for the six control variants: targeted legality stays with
## CombatAttackTargeting, gauge readiness is a live-session concern.
func _control_preview(id: String) -> Dictionary:
	var app = get_parent()
	var preview := _targeting.get_preview(_deck, app.party, app.enemies, id)
	if not preview.get("playable", false):
		return preview
	if not _control_ready(app.party, app.enemies, id):
		return {"playable": false, "requires_selection": false, "target_positions": []}
	if id in CombatSeamstressPoolControl.NEEDLE_IDS:
		var patch := _controls.needle_patch_preview()
		var filtered: Array[int] = []
		for position in preview.target_positions:
			if app.enemies.can_apply_statuses({position: patch.statuses}):
				filtered.append(position)
		preview["target_positions"] = filtered
		preview["playable"] = not filtered.is_empty()
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
	last_event = CombatStitchedCards.new(_play).play_stitched(deck, app.party, app.enemies,
		_ledger(), id, choices[0], choices[1], _fray)
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
	if not _single(_armed) or _targeting.is_pool_combo_attack(_card_id(_armed)):
		# Combo P-selection must not leave Space bound to End Turn.
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


## Starter, plain-strike, heavy-pool, Seamstress control attacks and this
## battle's selected Path card use separate authored catalogs.
func _definition(card_id: String) -> Dictionary:
	if _is_path_card(card_id):
		return _path_card
	if _targeting.is_pool_strike(card_id):
		return _targeting.pool_definition(card_id)
	if _targeting.is_heavy_pool_attack(card_id):
		return _targeting.heavy_definition(card_id)
	if _targeting.is_seamstress_control(card_id):
		return _targeting.control_definition(card_id)
	if _targeting.is_pool_combo_attack(card_id):
		return _targeting.combo_definition(card_id)
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
	if _is_path_card(id):
		return path_preview(id)
	# The battle's one Path authority prices a qualifying Tinker card BEFORE any
	# resolver's printed-cost affordability check.
	var discount: int = tinker_cost_discount(id)
	if _direct_fire_preview.supports(id):
		return _direct_fire_preview.get_preview(_deck, app.party, app.enemies, id, _direct_fire, discount)
	if _targeting.is_seamstress_control(id):
		return _control_preview(id)
	if _targeting.is_pool_combo_attack(id):
		var forecast := _combo_preview(id)
		return {"playable": forecast.get("playable", false),
			"requires_selection": forecast.get("requires_selection", false),
			"target_positions": forecast.get("target_positions", [])}
	return _targeting.get_preview(_deck, app.party, app.enemies, id, discount)


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
			or _targeting.is_seamstress_control(id) \
			or _targeting.is_pool_combo_attack(id) or _is_path_card(id) \
			or id in CombatAttackCards.ATTACK_IDS) and position > 0:
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
	var combo := _targeting.is_pool_combo_attack(id)
	var path := _is_path_card(id)
	var guarded := direct or control or combo or path or id in CombatAttackCards.ATTACK_IDS
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
	var energy_before: int = _deck.energy
	if (direct or combo or path) and (app._battle_closed or target_id.is_empty() \
			or app.deck._rng != rng or (combo and not app._combo_battle_current())):
		_reject_stitch()
		return
	var preview := _target_preview(id)
	if not preview.playable or (position not in preview.target_positions if preview.requires_selection else position != 0) \
			or (((_targeting.is_sight_glass(id) or direct) and (app._battle_closed or target_id.is_empty() \
			or app.enemies.get_enemy(position).get("id") != target_id)) \
			or ((control or combo or path or id in CombatAttackCards.ATTACK_IDS) \
				and position > 0 and (app._battle_closed or target_id.is_empty() \
				or app.enemies.get_enemy(position).get("id") != target_id))):
		if guarded or _targeting.is_sight_glass(id):
			_reject_stitch()
		return
	last_event = _resolve_attack(party, enemies, id, position)
	if last_event.ok:
		# Every real Tinker play feeds the battle's one Path authority, so its
		# first-hit latch, Scope and Clockwork state can never drift from combat.
		# A non-Tinker card fails closed inside the authority.
		if _tinker_path != null:
			report_tinker_play(id, energy_before)
		_after_attack()
	elif guarded:
		_reject_stitch()


func _resolve_attack(party: CombatParty, enemies: CombatEnemies, id: String, position: int, forecast: bool = false) -> Dictionary:
	if _is_path_card(id):
		if forecast:
			return _path_quote(id, position)
		if not path_ready():
			return {"ok": false}
		# Unpicker's skip is only real when this battle's enemy phase owns the
		# gauge, so the handoff happens inside the same commit boundary.
		if _path_cards.get_path_id() == CombatSeamstressPathCards.UNPICKER_PATH \
				and not _share_path_gauge():
			return {"ok": false}
		return _path_cards.play_card(_deck, party, enemies, id, position)
	if _direct_fire_preview.supports(id):
		var direct_discount: int = tinker_cost_discount(id)
		if forecast:
			return _direct_fire_preview.get_preview(_deck, party, enemies, id, _direct_fire, direct_discount)
		return _direct_fire.play_attack(_deck, party, enemies, id, position, null, direct_discount)
	if _targeting.is_pool_combo_attack(id):
		if forecast:
			return _combo_preview(id)
		if not get_parent()._combo_battle_current() or not _share_gauge(party, enemies, id):
			return {"ok": false}
		if CombatWardenPoolComboAttacks.SUPPORTED_CARD_IDS.has(id):
			return _warden_combo.play_attack(_deck, party, enemies, _pinned, _unravel, id, position)
		var tinker_combo := CombatTinkerPoolUnravelAttacks.new(_play._tinker, _unravel, _pinned)
		tinker_combo.set_patch_rules(_play._patches)
		return tinker_combo.play_attack(_deck, party, enemies, id, position)
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
	# The one Path authority prices a qualifying Tinker card before the starter
	# resolver checks or charges the printed cost.
	var discount: int = tinker_cost_discount(id)
	if forecast:
		return _play.forecast_attack(_deck, party, enemies, id, owner_statuses,
			enemy_statuses, discount)
	# Only an actual selected starter commit may request this sealed quote.
	# Forecasts and hover never touch Frayfinder's per-turn latch.
	var mitt_quote := {}
	if _fray != null and id in CombatAttackCards.ATTACK_IDS:
		mitt_quote = _fray.quote_starter_hit(id, position, 1, discount)
	var committed := _play.play_attack(_deck, party, enemies, id, position,
		owner_statuses, enemy_statuses, discount, _fray, mitt_quote)
	if committed.get("ok", false) and mitt_quote.get("bonus") == 2:
		_fray.consume_confirmed_hit(mitt_quote, committed)
	return committed


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
	var patch := _controls.needle_patch_preview()
	if not patch.get("ok", false):
		return unavailable
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
	var snag_weak := {}
	if id in CombatSeamstressPoolControl.SNAG_IDS:
		snag_weak = _controls.snag_weak_preview(id)
		if not snag_weak.get("ok", false):
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
				int(effects["damage"]) + int(patch.damage_bonus) + bonus, owner_statuses, defender)
			hit["pinned_bonus"] = bonus
			if not patch.statuses.is_empty():
				hit["exposed_applied"] = int(patch.statuses.get("exposed", 0))
				hit["exposed_before"] = int(defender.get("exposed", 0))
				hit["exposed_after"] = int(defender.get("exposed", 0)) + int(patch.statuses.get("exposed", 0))
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
				hit["weak_applied"] = int(snag_weak["weak"])
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
	# Combo admission additionally requires a current battle and its real
	# gauge/round-flow binding, not merely scene-free targeting legality.
	if _targeting.is_pool_combo_attack(id) and (not app._combo_battle_current() \
			or not _control_ready(app.party, app.enemies, id)):
		return false
	var index: int = panel.get_index()
	var path_ok: bool = _is_path_card(id) and not _path_positions(id).is_empty()
	return (_targeting.supports(id) or _direct_fire_preview.supports(id) or _stitch_preview(id).playable or path_ok) and index < _deck.hand.size() and _deck.hand[index] == id


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
		_fray = null
		_controls = CombatSeamstressPoolControl.new()
		var head_rules: CombatM05HeadPatchRules = null
		_direct_fire = CombatTinkerPoolAttacks.new(_play._tinker)
		# Capture the genuine run's sewn wearer projection at battle entry only.
		# An invalid present binding must reject attacks, not fall back to vanilla.
		var carry := app.party_carryover as RunTornCarryover
		if carry != null and carry._wardrobe != null:
			head_rules = CombatM05HeadPatchRules.new()
			var wardrobe: RunPatchWardrobe = carry._wardrobe
			var current: Dictionary = wardrobe.get_snapshot()
			if carry.can_bind_wardrobe(wardrobe, carry.torn, current) \
					and current.heroes == app.run_heroes and current.owned == app.run_trinkets \
					and current.cards == app.run_deck and current.scraps == app.run_scraps \
					and current.gold == app.session_gold and current.seed == app.run_seed:
				_play.bind_patch_wardrobe(wardrobe, carry.torn)
				head_rules.bind_wardrobe(wardrobe, carry.torn)
			else:
				_play.bind_patch_wardrobe(null, null)
		# Needle Pin shares the exact starter attack object and once-per-combat
		# latch, including an explicitly failed wardrobe admission.
		_controls.bind_patch_rules(_play._patches)
		_warden_combo.set_patches(_play._patches)
		_controls.bind_head_patch_rules(head_rules)
		if head_rules != null:
			_play.bind_head_patch_rules(head_rules)
		last_event = {}
		# One Pinned set and one Unravel gauge live for this whole battle session.
		# They are created here and never recreated or reset by a hand refresh.
		_pinned = CombatPinned.new()
		_unravel = CombatUnravel.new()
		_routed_gauge_shared = false
		var tiers := enemy_tier_map(app.enemies)
		if tiers.is_empty() or not _unravel.bind_roster(app.enemies, tiers):
			# Keep the owned gauge unbound: a gauge-card cast then fails closed.
			_unravel = CombatUnravel.new()
		# Frayfinder uses THIS exact Unravel authority, not a parallel gauge.
		# An unowned/invalid patch run simply plays with no M05 effect.
		if carry != null and carry._wardrobe != null and _play._patches != null \
				and _play._patches.is_valid() and _unravel._bound_enemies == app.enemies:
			var mitt := CombatFrayfinderMitt.new()
			if mitt.bind_battle(_deck, app.party, app.enemies, _unravel,
					carry._wardrobe, carry.torn, _play):
				_fray = mitt
		# The selected Path card is bound only to this battle's genuine receipt,
		# deck, party, roster and the one gauge shared with its round flow.
		_bind_path_cards(app)
		# The Tinker Path is bound the same way, from its own claimed setup and
		# authenticated run receipt.
		_bind_tinker_path(app)
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
		# A new intent index is published only by the real round transition.
		# An old active latch cannot be reset by a hover or a hand redraw.
		if _fray != null:
			if _fray._turn_open:
				_fray.advance_confirmed_turn()
			else:
				_fray.begin_player_turn()
		# The Path authority follows the same genuine player-turn boundary, so an
		# unspent Scope expires and a queued Wind-up credit is claimed once.
		_advance_tinker_path_turn()
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
	# Real routed fights can accrue Unravel from enemy Bleed before the first
	# combo cast. Share once on route admission, never replace a foreign gauge
	# or rebind a deliberately cleared flow on a later hover/hand refresh.
	# Standalone battles bind on their first successful gauge-bearing cast.
	if not _routed_gauge_shared and app.run_map != null and app._combo_battle_current():
		_routed_gauge_shared = _share_gauge(app.party, app.enemies, "")
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
						var status_text := ""
						for status in ["weak", "bleed"]:
							if int(hit.get("statuses", {}).get(status, 0)) > 0:
								status_text += ", %s %d" % [status.capitalize(), hit.statuses[status]]
						effects.append("enemy %d: %d damage%s" % [hit.position, hit.damage, status_text])
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
	if _is_path_card(id):
		# The resolver's per-slot previews are the only Path forecast: no Bleed
		# tick or Unravel charge is simulated here, only the projected card.
		var path_slots := _path_positions(id)
		var path_details: PackedStringArray = []
		for position in path_slots:
			path_details.append(_path_quote_text(position, _path_quote(id, position)))
		var path_reading := "Unavailable: no legal target, receipt or shared gauge"
		if not path_slots.is_empty():
			path_reading = "Choose one enemy slot: " + "; ".join(path_details)
			current_forecast = {"ok": true, "card_id": id, "target_positions": path_slots}
		cue.text = "%s | %d energy | P / click card; %s / click enemy\n%s" % [
			definition.display_name, definition.cost, _key_hint(path_slots), path_reading]
		return
	var preview := _resolve_attack(app.party, app.enemies, id, 0, true)
	if _targeting.is_pool_combo_attack(id):
		current_forecast = preview.duplicate(true)
		# Reuse the existing detailed oracle formatter, but make the live input
		# affordance explicit: this panel now commits, rather than forecasting only.
		cue.text = app._combo_forecast_text(id, preview).replace(
			"Forecast only (nothing played): P / hover selects; Esc cancels",
			"P / click card; %s / click enemy; Esc cancels" % _key_hint(
				preview.get("target_positions", [])))
		return
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
				if int(hit.get("exposed_applied", 0)) > 0:
					damage_line += " (Exposed %d → %d after hit)" % [
						int(hit.exposed_before), int(hit.exposed_after)]
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
	var additions_by_position: Dictionary = {}
	if not is_pool and not is_heavy and not is_direct and preview.playable:
		# This is the same pure status preflight as the confirmed attack, including
		# the authored passive, HEAD bonus, M04 rider and capacity eligibility.
		var status_plan := _play._prepare(_deck, app.party, app.enemies, id, 0,
			{}, {}, false, tinker_cost_discount(id))
		if status_plan.get("ok", false):
			additions_by_position = status_plan.applications
	for hit in preview.hits:
		var detail := ("%d: 2 hits x %d damage each" % [hit.position, hit.damage]
			if int(hit.get("hit_count", 1)) == 2 else "%d: %d damage" % [hit.position, hit.damage])
		var enemy: Dictionary = app.enemies.get_enemy(hit.position)
		var current: Dictionary = enemy.get("statuses", {})
		var additions: Dictionary = additions_by_position.get(hit.position, {})
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
	# The one Path authority may already have discounted this cast: the strip
	# reports the energy that will really be charged, never a printed price the
	# resolver no longer asks for.
	var shown_cost: int = maxi(0, int(definition.cost) - tinker_cost_discount(id))
	cue.text = "%s | %d energy | %s\n%s" % [definition.display_name, shown_cost, controls, description]


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
	_path_cards = null
	_path_card.clear()
	_tinker_path = null
	_routed_gauge_shared = false
	_fray = null
	_play = CombatAttackCards.new() # Return/title retires the prior battle's wearer latch.
	_controls = CombatSeamstressPoolControl.new()
	_direct_fire = CombatTinkerPoolAttacks.new(_play._tinker)
	_selected = null
