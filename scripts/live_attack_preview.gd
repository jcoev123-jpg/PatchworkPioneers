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
var _overload_hud: Label
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
var _overload := CombatTinkerV3OverloadCards.new()
var _casing_clamp := CombatTinkerV3CasingClampCards.new()
var _pool_strikes := CombatPoolPlainStrikes.new()
var _heavy_attacks := CombatWardenPoolHeavyAttacks.new()
var _toss := CombatWardenV3ShieldTossCards.new()
## Authenticated V3 Rivet Pummel uses this battle's existing shared _pinned authority.
var _rivet := CombatWardenV3RivetCards.new()
var _lunge := CombatRagDuelistLungeCards.new()
var _snare := CombatRagDuelistTatteredSnareCards.new()
var _prick := CombatRagDuelistNeedlePrickCards.new()
var _barrage := CombatRagDuelistNeedleBarrageCards.new()
var _needle := CombatYarnRangerNeedleCards.new()
var _monk := CombatLanternMonkBlindStrikeCards.new()
var _moth_lure := CombatLanternMonkMothLureCards.new()
## Button Golem's Knuckle/Snag resolver. It keeps no token store: every cast
## and forecast reads this battle's one shared _pinned set.
var _thread := CombatButtonGolemThreadCards.new()
var _golem_pool := ButtonGolemPoolCards.new()
var _helmet := CombatWardenV3HelmetCards.new()
var _vanguard: CombatWardenVanguardPassive
var _warden_turn := -1
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
var _warden_receipt: Dictionary = {}
var _warden_card: Dictionary = {}
var _warden_rules := CombatWardenPathCards.new()


func _bind_warden_path(app) -> void:
	_warden_receipt.clear()
	_warden_card.clear()
	var authenticated := RunWardenPathChoice.authenticate_receipt(app.run_warden_path_receipt)
	if authenticated.get("ok", false):
		_warden_receipt = authenticated.receipt
		_warden_card = _warden_receipt.card.duplicate(true)


func _is_warden_card(id: String) -> bool:
	return not _warden_card.is_empty() and id == _warden_card.get("id", "")


func warden_ready() -> bool:
	var app = get_parent()
	if app == null or _deck == null or app.deck != _deck or app._battle_closed \
			or _pinned == null or app.run_warden_path_receipt != _warden_receipt \
			or app.enemy_intents == null or _turn != app.enemy_intents._turn_index \
			or not RunWardenPathChoice.authenticate_receipt(_warden_receipt).get("ok", false) \
			or _session != [app.party, app.enemies, app.battle_result, app.run_rng, app.enemy_intents]:
		return false
	var copies := 0
	for pile in [_deck.draw_pile, _deck.hand, _deck.discard_pile]:
		for id in [CombatWardenPathCards.BULWARK_BRACE_ID, CombatWardenPathCards.LANCE_PIN_ID]:
			if id != _warden_card.id and pile.has(id):
				return false
		copies += pile.count(_warden_card.id)
	return copies == 1


func warden_preview(id: String) -> Dictionary:
	if not _is_warden_card(id) or not warden_ready():
		return {"ok": false, "playable": false, "requires_selection": false, "target_positions": []}
	var app = get_parent()
	return _warden_rules.forecast(_deck, app.party, app.enemies, id, _warden_receipt, _pinned)


func warden_path_playable(id: String) -> bool:
	return warden_preview(id).get("playable", false)


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
var _receipt_seq := 0


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
	_tether_positions.clear()
	_tether_enemy_ids.clear()
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


## The mounted support hand owns this routed battle's one healing service, already
## authenticated against the live wardrobe/torn ledgers. Only that exact deck,
## party and battle may lend it to a stitched commit, so ordinary held heals and
## authenticated stitched halves share one COAT latch. Any unavailable or stale
## sibling keeps the current unpatched stitched behavior.
func _stitched_heals(app, deck: CombatDeck, party: CombatParty) -> CombatSeamstressPoolHeals:
	if app == null or deck == null or party == null or deck != _deck \
			or not is_instance_valid(_battle) or app.battle_view != _battle:
		return null
	var support = app.get_node_or_null("LiveSupportHand")
	if support == null or not is_instance_valid(support) \
			or not support.has_method("stitched_heal_authority"):
		return null
	return support.stitched_heal_authority(deck, party, _battle)


## Forecast and commit use the same battle-bound support receipts. An attempted
## stale binding stays invalid, so neither path can silently drop its patches.
func _stitched_transaction(app) -> CombatStitchedCards:
	var transaction := CombatStitchedCards.new(_play)
	var heals := _stitched_heals(app, _deck, app.party)
	if heals != null and heals._wardrobe != null and heals._torn != null:
		if transaction.bind_patch_wardrobe(heals._wardrobe, heals._torn,
				heals._wardrobe_snapshot, heals._torn_snapshot):
			transaction.bind_borrowed_button(heals)
	return transaction


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
	# Reuse the mounted hand's exact battle-bound healing service (and its live
	# wardrobe/torn authorities) so a genuinely held stitched half notifies the same
	# once-per-combat COAT latch as an ordinary held heal. Without those bindings
	# the composite keeps its current unpatched behavior.
	var transaction := _stitched_transaction(app)
	last_event = transaction.play_stitched(deck, app.party, app.enemies,
		_ledger(), id, choices[0], choices[1], _fray)
	if last_event.ok:
		_forward_switchback_stitched_play(id, preview)
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
						_queue_attack(index + 1 if _single(_armed) or _card_id(_armed) in TETHER_STARTERS else 0)
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
	if _card_id(panel) in TETHER_STARTERS:
		return true
	if _is_stitched(panel):
		return _choices.size() < 2
	return _definition(_card_id(panel)).get("target_kind") == "enemy_single"


## Starter, plain-strike, heavy-pool, Seamstress control attacks and this
## battle's selected Path card use separate authored catalogs.
func _definition(card_id: String) -> Dictionary:
	if card_id in TETHER_STARTERS:
		return _tether_definition(card_id)
	if _moth_lure.is_supported_card(card_id):
		return _moth_lure._catalog.get_definition(card_id)
	if _monk.is_supported_card(card_id):
		return _monk.get_definition(card_id)
	if _needle.is_supported_card(card_id):
		return CombatYarnRangerNeedleCards.needle_definition(card_id)
	if _barrage.is_supported_card(card_id):
		return _barrage._catalog_definition(card_id)
	if _lunge.is_supported_card(card_id):
		var card := _lunge._catalog_definition(card_id)
		return card if _lunge._authentic(card, card_id) else {}
	if _snare.is_supported_card(card_id):
		return _snare._catalog_definition(card_id)
	if _prick.is_supported_card(card_id):
		return _prick._catalog_definition(card_id)
	if _thread.is_supported_card(card_id):
		return _golem_pool.get_definition(card_id) if not _thread._authenticate(card_id).is_empty() else {}
	if _overload.is_supported_card(card_id):
		return _overload.overload_definition(card_id)
	if _casing_clamp.is_supported_card(card_id):
		return CombatTinkerV3CasingClampCards.casing_clamp_definition(card_id)
	if _helmet.is_supported_card(card_id):
		return _helmet._catalog_definition(card_id)
	if _toss.is_supported_card(card_id):
		return _toss._catalog_definition(card_id)
	if _rivet.is_supported_card(card_id):
		return _rivet._catalog.get_definition(card_id) if not _rivet._authenticate(card_id).is_empty() else {}
	if _is_warden_card(card_id):
		return _warden_card
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
	var pointer: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var key: bool = _moth_lure.is_supported_card(_card_id(panel)) \
		and event is InputEventKey and event.pressed and not event.echo \
		and event.keycode in [KEY_ENTER, KEY_SPACE]
	if not pointer and not key:
		return
	if _queued or not _bindings.has(panel) or not _eligible(panel) or _bindings[panel].id != _card_id(panel):
		return
	_token += 1
	_queued = false
	_armed = panel
	_dragging = pointer
	if pointer:
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
	if id in TETHER_STARTERS:
		return tether_preview(id)
	if _moth_lure.is_supported_card(id):
		return _moth_lure_forecast(app.party, app.enemies, id)
	if _monk.is_supported_card(id):
		return _monk_forecast(app.party, app.enemies, id)
	if _needle.is_supported_card(id):
		return _needle_forecast(app.party, app.enemies, id)
	if _barrage.is_supported_card(id):
		return _barrage_forecast(app.party, app.enemies, id)
	if _lunge.is_supported_card(id):
		return _lunge_forecast(app.party, app.enemies, id)
	if _snare.is_supported_card(id):
		return _snare_forecast(app.party, app.enemies, id)
	if _prick.is_supported_card(id):
		return _prick_forecast(app.party, app.enemies, id)
	if _thread.is_supported_card(id):
		return _thread_forecast(app.party, app.enemies, id)
	if _overload.is_supported_card(id):
		return _overload_forecast(app.party, app.enemies, id)
	if _casing_clamp.is_supported_card(id):
		return _casing_clamp_forecast(app.party, app.enemies, id)
	if _helmet.is_supported_card(id):
		return _helmet_forecast(app.party, app.enemies, id)
	if _toss.is_supported_card(id):
		return _toss_forecast(app.party, app.enemies, id)
	if _rivet.is_supported_card(id):
		return _rivet_forecast(app.party, app.enemies, id)
	if _is_warden_card(id):
		return warden_preview(id)
	if _is_path_card(id):
		return path_preview(id)
	# The battle's one Path authority prices a qualifying Tinker card BEFORE any
	# resolver's printed-cost affordability check.
	var discount: int = tinker_cost_discount(id)
	if _direct_fire_preview.supports(id):
		if id.begins_with("tinker_spring_trap") and (_pinned == null \
				or _direct_fire.get_pinned() != _pinned or app._battle_closed \
				or app.deck != _deck or app.enemy_intents == null \
				or _turn != app.enemy_intents._turn_index \
				or _session != [app.party, app.enemies, app.battle_result, app.run_rng, app.enemy_intents]):
			return {"playable": false, "requires_selection": false, "target_positions": []}
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
	if id in TETHER_STARTERS:
		_choose_tether(position)
		return
	var preview := _target_preview(id)
	if not preview.playable or (position not in preview.target_positions if preview.requires_selection else position != 0):
		return
	_queued = true
	# A single-target target ID plus the held panel's original hand index
	# prevent an enemy replacement or equivalent-copy panel swap at commit.
	var target_id := ""
	if (_moth_lure.is_supported_card(id) or _monk.is_supported_card(id) or _needle.is_supported_card(id) or _barrage.is_supported_card(id) or _lunge.is_supported_card(id) or _snare.is_supported_card(id) or _prick.is_supported_card(id) or _thread.is_supported_card(id) or _overload.is_supported_card(id) or _casing_clamp.is_supported_card(id) or _direct_fire_preview.supports(id) or _targeting.is_sight_glass(id) \
			or _targeting.is_seamstress_control(id) \
			or _targeting.is_heavy_pool_attack(id) \
			or _toss.is_supported_card(id) or _rivet.is_supported_card(id) \
			or _helmet.is_supported_card(id) \
			or _targeting.is_pool_combo_attack(id) or _is_path_card(id) or _is_warden_card(id) \
			or id in CombatAttackCards.ATTACK_IDS) and position > 0:
		target_id = str(app.enemies.get_enemy(position).get("id", ""))
	_commit.call_deferred(_armed, id, position, _token,
		app.party, app.enemies, app.battle_result, app.run_rng, _turn, target_id,
		_armed.get_index(), _deck, _deck.hand.duplicate(), app.run_map, _pinned, _unravel)


func _commit(panel, id: String, position: int, token: int, party, enemies, result, rng,
		turn: int, target_id: String = "", panel_index: int = -1,
		queued_deck = null, queued_hand: Array = [], queued_map = null,
		queued_pinned: CombatPinned = null, queued_unravel: CombatUnravel = null) -> void:
	var app = get_parent()
	if not is_inside_tree() or app == null or app.get_node_or_null("LiveAttackPreview") != self or token != _token or not _queued:
		return
	_queued = false
	var direct := _direct_fire_preview.supports(id)
	var control := _targeting.is_seamstress_control(id)
	var combo := _targeting.is_pool_combo_attack(id)
	var path := _is_path_card(id) or _is_warden_card(id)
	var heavy := _targeting.is_heavy_pool_attack(id)
	var toss := _toss.is_supported_card(id) or _helmet.is_supported_card(id)
	var rivet := _rivet.is_supported_card(id)
	var overload := _overload.is_supported_card(id)
	var casing_clamp := _casing_clamp.is_supported_card(id)
	var lunge := _lunge.is_supported_card(id)
	var snare := _snare.is_supported_card(id)
	var prick := _prick.is_supported_card(id)
	var barrage := _barrage.is_supported_card(id)
	var needle := _needle.is_supported_card(id)
	var monk := _monk.is_supported_card(id)
	var moth_lure := _moth_lure.is_supported_card(id)
	var thread := _thread.is_supported_card(id)
	var guarded := moth_lure or monk or needle or barrage or lunge or snare or prick or thread or direct or control or combo or path or heavy or toss or rivet or overload or casing_clamp or id in CombatAttackCards.ATTACK_IDS
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
	if direct and id.begins_with("tinker_spring_trap") and (_pinned == null \
			or queued_pinned != _pinned or _direct_fire.get_pinned() != _pinned):
		_reject_stitch()
		return
	if (_is_warden_card(id) or rivet) and (_pinned == null or queued_pinned != _pinned):
		_reject_stitch()
		return
	# Knuckle/Snag read and write the Pinned set the selection was quoted against.
	if thread and (_pinned == null or queued_pinned != _pinned):
		_reject_stitch()
		return
	if needle and (queued_unravel != _unravel or not _needle_binding_ready(party, enemies)):
		_reject_stitch()
		return
	var energy_before: int = _deck.energy
	if (moth_lure or monk or needle or barrage or lunge or snare or prick or thread or direct or combo or path or heavy or toss or rivet or overload or casing_clamp) and (app._battle_closed \
			or (target_id.is_empty() and not (_is_warden_card(id) and position == 0)) \
			or app.deck._rng != rng or (combo and not app._combo_battle_current())):
		_reject_stitch()
		return
	var preview := _target_preview(id)
	if not preview.playable or (position not in preview.target_positions if preview.requires_selection else position != 0) \
			or (((_targeting.is_sight_glass(id) or direct) and (app._battle_closed or target_id.is_empty() \
			or app.enemies.get_enemy(position).get("id") != target_id)) \
			or ((moth_lure or monk or needle or barrage or lunge or snare or prick or thread or control or combo or path or heavy or toss or rivet or overload or casing_clamp or id in CombatAttackCards.ATTACK_IDS) \
				and position > 0 and (app._battle_closed or target_id.is_empty() \
				or app.enemies.get_enemy(position).get("id") != target_id))):
		if guarded or _targeting.is_sight_glass(id):
			_reject_stitch()
		return
	var definition := _definition(id)
	_pinned.begin_confirmed_cast(id, str(definition.get("owner", "")),
		int(definition.cost) if (overload or casing_clamp) else maxi(0, int(definition.get("cost", 0)) - tinker_cost_discount(id)))
	# The lethal-card boundary needs the exact pre-hit roster of this one paid
	# commit; forecasts and rejected selections never reach this point.
	var roster_before: Array = enemies.get_enemies()
	last_event = _resolve_attack(party, enemies, id, position)
	if last_event.ok:
		app._note_card_damage(enemies, roster_before, last_event)
		# Every real Tinker play feeds the battle's one Path authority, so its
		# first-hit latch, Scope and Clockwork state can never drift from combat.
		# A non-Tinker card fails closed inside the authority.
		if _tinker_path != null:
			report_tinker_play(id, energy_before)
		_pinned.finish_confirmed_cast(last_event)
		_forward_switchback_ordinary_play(id)
		_after_attack()
	else:
		_pinned.finish_confirmed_cast(last_event)
		if guarded:
			_reject_stitch()


func _resolve_attack(party: CombatParty, enemies: CombatEnemies, id: String, position: int, forecast: bool = false) -> Dictionary:
	if _moth_lure.is_supported_card(id):
		if forecast:
			return _moth_lure_forecast(party, enemies, id)
		# Control only: the paid resolver draws and arms Blind, never manufactures a hit.
		return _moth_lure.play_card(_deck, party, enemies, id, position)
	if _monk.is_supported_card(id):
		if forecast:
			return _monk_forecast(party, enemies, id)
		var paid := _monk.play_card(_deck, party, enemies, id, position)
		if paid.get("ok", false):
			# Existing confirmed-cast observers consume hit receipts; never reapply damage or Blind.
			paid["hits"] = [{"position": paid.target_position, "damage": paid.damage,
				"hp_loss": paid.hp_loss, "block_absorbed": paid.block_absorbed}]
		return paid
	if _needle.is_supported_card(id):
		if forecast:
			return _needle_forecast(party, enemies, id)
		# Never pay unless the round flow accepts this battle's existing gauge.
		if not _share_path_gauge():
			return {"ok": false, "reason": "unbound_unravel"}
		return _needle.play_card(_deck, party, enemies, _unravel, id, position)
	if _barrage.is_supported_card(id):
		if forecast:
			return _barrage_forecast(party, enemies, id)
		return _barrage.play_card(_deck, party, enemies, id, position)
	if _lunge.is_supported_card(id):
		if forecast:
			return _lunge_forecast(party, enemies, id)
		return _lunge.play_card(_deck, party, enemies, id, position)
	if _snare.is_supported_card(id):
		if forecast:
			return _snare_forecast(party, enemies, id)
		return _snare.play_card(_deck, party, enemies, id, position)
	if _prick.is_supported_card(id):
		if forecast:
			return _prick_forecast(party, enemies, id)
		var paid := _prick.play_card(_deck, party, enemies, id, position)
		if paid.get("ok", false):
			# Pass the one confirmed strike to existing hit observers; never hit twice.
			paid["hits"] = [{"position": paid.target_position, "damage": paid.damage,
				"hp_loss": paid.hp_loss, "block_absorbed": paid.block_absorbed}]
		return paid
	if _thread.is_supported_card(id):
		if forecast:
			return _thread_forecast(party, enemies, id)
		var receipt := _thread.play_card(_deck, party, enemies, id, position, _pinned)
		if receipt.get("ok", false):
			# The shared Pinned set reconciles a consumed token against hit receipts.
			receipt["hits"] = [{"position": position, "damage": receipt.damage,
				"hp_loss": receipt.hp_loss, "block_absorbed": receipt.block_absorbed}]
		return receipt
	if _overload.is_supported_card(id):
		if forecast:
			return _overload_forecast(party, enemies, id)
		return _overload.play_card(_deck, party, enemies, id, position)
	if _casing_clamp.is_supported_card(id):
		if forecast:
			return _casing_clamp_forecast(party, enemies, id)
		var paid := _casing_clamp.play_card(_deck, party, enemies, id, position)
		if paid.get("ok", false):
			# Confirmed-hit observers receive one real paid hit, not a forecast.
			paid["hits"] = [{"position": paid.target_position, "damage": paid.raw_damage,
				"hp_loss": paid.hp_loss, "block_absorbed": paid.block_absorbed}]
		return paid
	if _helmet.is_supported_card(id):
		if forecast:
			return _helmet_forecast(party, enemies, id)
		var snapshots := _toss_statuses(party, enemies, position)
		if not snapshots.get("ok", false):
			return {"ok": false}
		return _helmet.play_card(_deck, party, enemies, id, position,
			snapshots.attacker, snapshots.defender)
	if _toss.is_supported_card(id):
		if forecast:
			return _toss_forecast(party, enemies, id)
		var snapshots := _toss_statuses(party, enemies, position)
		if not snapshots.get("ok", false):
			return {"ok": false}
		return _toss.play_card(_deck, party, enemies, id, position,
			snapshots.attacker, snapshots.defender)
	if _rivet.is_supported_card(id):
		if forecast:
			return _rivet_forecast(party, enemies, id)
		var paid := _rivet.play_card(_deck, party, enemies, _pinned, id, position)
		if paid.get("ok", false):
			# Feed each actual strike to existing observers once; the resolver owns damage.
			for hit in paid["hits"]:
				hit["position"] = position
		return paid
	if _is_warden_card(id):
		if not warden_ready() or party != get_parent().party or enemies != get_parent().enemies:
			return {"ok": false}
		if forecast:
			return warden_preview(id)
		return _warden_rules.play(_deck, party, enemies, id, position, _warden_receipt, _pinned)
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
		return _direct_fire.play_attack(_deck, party, enemies, id, position, _pinned, direct_discount)
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
		return _pool_strikes.play_card(_deck, party, enemies, id, position, _pinned)
	if _targeting.is_heavy_pool_attack(id):
		if forecast:
			return _heavy_forecast(party, enemies, id)
		if _vanguard != null and not _warden_current():
			return {"ok": false}
		var pin_quote := {}
		if _vanguard != null:
			pin_quote = _vanguard.quote_attack(_deck, party, enemies, _pinned,
				_heavy_attacks, id, position)
		var mitt_quote := {}
		if _fray != null:
			mitt_quote = _fray.quote_heavy_hit(id, position)
		var committed := _heavy_attacks.play_attack(_deck, party, enemies, id, position,
			{}, {}, _pinned, _play._patches, _fray, mitt_quote)
		var mitt_confirmed := true
		if committed.get("ok", false) and mitt_quote.get("bonus") == 2:
			mitt_confirmed = _fray.consume_confirmed_hit(mitt_quote, committed)
		if committed.get("ok", false) and mitt_confirmed and pin_quote.get("ok", false):
			_vanguard.confirm_attack(_deck, party, enemies, _pinned, _heavy_attacks,
				pin_quote, committed)
		return committed
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
	# The live hand owns the single turn-synchronized Heirloom; this
	# presenter owns the real Pinned identity and committed target.
	var needle_rules: CombatHeirloomPatchTriggers = null
	var needle_quote := {}
	if CombatHeirloomPatchTriggers.NEEDLE_STARTERS.has(id) and position > 0:
		var definition: Dictionary = _catalog.get_definition(id)
		if definition.get("id") == id and definition.get("target_kind") == "enemy_single" \
				and definition.get("owner") == owner and _deck.hand.has(id):
			var hand = get_parent().get_node_or_null("LiveSupportHand")
			if hand != null:
				var current: CombatHeirloomPatchTriggers = hand.current_attack_heirloom(_deck, party)
				if current != null and current._pinned == _pinned and current._enemies == enemies:
					var offered: Dictionary = current.quote_needle_hit(owner, position, id)
					if offered.get("ok", false):
						needle_rules = current
						needle_quote = offered
	var committed := _play.play_attack(_deck, party, enemies, id, position,
		owner_statuses, enemy_statuses, discount, _fray, mitt_quote,
		needle_rules, needle_quote)
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
		var pin_bonus := _pinned.bonus_for_attack(enemies, position, str(owner)) if _pinned != null else 0
		hits.append({"position": position,
			"damage": _statuses.adjusted_attack_damage(damage + pin_bonus, owner_statuses, defender)})
	return {"playable": true, "requires_selection": true, "hits": hits}


## Each offered slot passes the same authenticated, read-only plan as the paid cast.
func _overload_forecast(party: CombatParty, enemies: CombatEnemies, id: String) -> Dictionary:
	var preview := {"playable": false, "requires_selection": true,
		"target_positions": [], "hits": []}
	var app = get_parent()
	if app == null or _deck == null or app.deck != _deck or app._battle_closed \
			or app.enemy_intents == null or _turn != app.enemy_intents._turn_index \
			or _deck._rng != app.run_rng or party != app.party or enemies != app.enemies \
			or _session != [party, enemies, app.battle_result, app.run_rng, app.enemy_intents]:
		return preview
	for position in CombatTinkerV3OverloadCards.TO_POSITIONS:
		var plan := _overload.preflight(_deck, party, enemies, id, position)
		if not plan.get("ok", false):
			continue
		preview.target_positions.append(position)
		preview.hits.append({"position": position, "damage": plan.raw_damage,
			"combat_scrap_spent": plan.combat_scrap_before})
	preview.playable = not preview.target_positions.is_empty()
	return preview


## Offer only legal original slots from the authenticated paid preflight.
func _casing_clamp_forecast(party: CombatParty, enemies: CombatEnemies, id: String) -> Dictionary:
	var preview := {"playable": false, "requires_selection": true,
		"target_positions": [], "hits": []}
	var app = get_parent()
	if app == null or _deck == null or app.deck != _deck or app._battle_closed \
			or app.enemy_intents == null or _turn != app.enemy_intents._turn_index \
			or _deck._rng != app.run_rng or party != app.party or enemies != app.enemies \
			or _session != [party, enemies, app.battle_result, app.run_rng, app.enemy_intents]:
		return preview
	for position in CombatTinkerV3CasingClampCards.TO_POSITIONS:
		var plan := _casing_clamp.preflight(_deck, party, enemies, id, position)
		if not plan.get("ok", false):
			continue
		preview.target_positions.append(position)
		preview.hits.append({"position": position, "damage": plan.raw_damage,
			"weak": plan.weak, "combat_scrap_gain": plan.combat_scrap_gain,
			"combat_scrap_before": plan.combat_scrap_before})
	preview.playable = not preview.target_positions.is_empty()
	return preview


## The same authenticated, read-only preflight as the paid Moth Lure service.
## It never predicts damage: the control card only arms Blind and draws one.
func _moth_lure_forecast(party: CombatParty, enemies: CombatEnemies, id: String) -> Dictionary:
	var preview := {"playable": false, "requires_selection": true,
		"target_positions": [], "hits": []}
	var app = get_parent()
	if app == null or _deck == null or app.deck != _deck or app._battle_closed \
			or app.enemy_intents == null or _turn != app.enemy_intents._turn_index \
			or _deck._rng != app.run_rng or party != app.party or enemies != app.enemies \
			or _session != [party, enemies, app.battle_result, app.run_rng, app.enemy_intents]:
		return preview
	for position in CombatLanternMonkMothLureCards.TO_POSITIONS:
		var plan := _moth_lure._prepare(_deck, party, enemies, id, position)
		if not plan.get("ok", false):
			continue
		preview.target_positions.append(position)
		preview.hits.append({"position": position, "blind_before": int(plan.blind_before),
			"blind_after": 1, "draw": CombatLanternMonkMothLureCards.DRAW_COUNT})
	preview.playable = not preview.target_positions.is_empty()
	return preview


## The paid Monk preflight is also the live read-only per-slot oracle: it checks
## the authentic held printing, living owner/target and all status capacities.
## No forecast charges, mutates or consumes Blind, Exposed or RNG.
func _monk_forecast(party: CombatParty, enemies: CombatEnemies, id: String) -> Dictionary:
	var preview := {"playable": false, "requires_selection": true,
		"target_positions": [], "hits": []}
	if _deck == null or party == null or enemies == null:
		return preview
	for position in CombatLanternMonkBlindStrikeCards.TO_POSITIONS:
		var plan := _monk._prepare(_deck, party, enemies, id, position)
		if not plan.get("ok", false):
			continue
		var status: Dictionary = enemies.get_enemy(position).get("statuses", {})
		var damage: int = _statuses.adjusted_attack_damage(int(plan.base_damage),
			plan.attacker_statuses, plan.defender_statuses)
		preview.target_positions.append(position)
		preview.hits.append({"position": position, "damage": damage,
			"blind_before": int(status.get("blind_next_attack", 0)),
			"blind_after": 1, "exposed_before": int(status.get("exposed", 0)),
			"exposed_added": int(plan.exposed),
			"exposed_after": int(status.get("exposed", 0)) + int(plan.exposed)})
	preview.playable = not preview.target_positions.is_empty()
	return preview


## Read live snapshots without coercion; the paid service validates their contents.
func _toss_statuses(party: CombatParty, enemies: CombatEnemies, position: int) -> Dictionary:
	if party == null or enemies == null:
		return {"ok": false}
	for hero in party.get_heroes():
		if hero.get("id") == CombatWardenV3ShieldTossCards.OWNER:
			var attacker: Variant = hero.get("statuses", {})
			var defender: Variant = enemies.get_enemy(position).get("statuses", {})
			if attacker is Dictionary and defender is Dictionary:
				return {"ok": true, "attacker": attacker, "defender": defender}
	return {"ok": false}


func _helmet_forecast(party: CombatParty, enemies: CombatEnemies, id: String) -> Dictionary:
	var preview := {"playable": false, "requires_selection": true,
		"target_positions": [], "hits": []}
	for position in CombatWardenV3HelmetCards.TO_POSITIONS:
		var snapshots := _toss_statuses(party, enemies, position)
		if not snapshots.get("ok", false):
			continue
		var plan := _helmet._prepare(_deck, party, enemies, id, position,
			snapshots.attacker, snapshots.defender)
		if not plan.get("ok", false):
			continue
		var damage := _statuses.adjusted_attack_damage(plan.base_damage,
			plan.attacker_statuses, plan.defender_statuses)
		preview.target_positions.append(position)
		preview.hits.append({"position": position, "damage": damage})
	preview.playable = not preview.target_positions.is_empty()
	return preview


func _toss_forecast(party: CombatParty, enemies: CombatEnemies, id: String) -> Dictionary:
	var preview := {"playable": false, "requires_selection": true,
		"target_positions": [], "hits": []}
	for position in CombatWardenV3ShieldTossCards.TO_POSITIONS:
		var snapshots := _toss_statuses(party, enemies, position)
		if not snapshots.get("ok", false):
			continue
		var plan := _toss._prepare(_deck, party, enemies, id, position,
			snapshots.attacker, snapshots.defender)
		if not plan.get("ok", false):
			continue
		var damage := _statuses.adjusted_attack_damage(plan.base_damage,
			plan.attacker_statuses, plan.defender_statuses)
		preview.target_positions.append(position)
		preview.hits.append({"position": position, "damage": damage})
	preview.playable = not preview.target_positions.is_empty()
	return preview


## Read-only Rivet Pummel quote: authenticated per-slot preflight, two distinct
## Block-before-HP strikes, and only the first cross-hero Pinned bonus. No
## deck, enemy, token or RNG state is written while projecting the survivor.
func _rivet_forecast(party: CombatParty, enemies: CombatEnemies, id: String) -> Dictionary:
	var preview := {"playable": false, "requires_selection": true,
		"target_positions": [], "hits": [], "cost": 2}
	var app = get_parent()
	if app == null or _deck == null or _pinned == null or app.deck != _deck \
			or app._battle_closed or app.enemy_intents == null \
			or _turn != app.enemy_intents._turn_index or app.run_rng != _deck._rng \
			or _session != [party, enemies, app.battle_result, app.run_rng, app.enemy_intents] \
			or party != app.party or enemies != app.enemies:
		return preview
	for position in CombatWardenV3RivetCards.TO_POSITIONS:
		var plan := _rivet._prepare(_deck, party, enemies, _pinned, id, position)
		if not plan.get("ok", false):
			continue
		var target: Dictionary = enemies.get_enemy(position)
		var remaining_hp: int = int(target.hp)
		var remaining_block: int = int(target.block)
		var strikes: Array[Dictionary] = []
		var bonus: int = _pinned.bonus_for_attack(enemies, position, "warden")
		for index in range(int(plan.hits_printed)):
			if remaining_hp <= 0:
				break
			var dealt: int = _statuses.adjusted_attack_damage(
				int(plan.hit_damage) + (bonus if index == 0 else 0),
				plan.attacker_statuses, plan.defender_statuses)
			var absorbed: int = mini(dealt, remaining_block)
			var hp_loss: int = mini(remaining_hp, dealt - absorbed)
			remaining_block -= absorbed
			remaining_hp -= hp_loss
			strikes.append({"hit": index, "damage": dealt,
				"block_absorbed": absorbed, "hp_loss": hp_loss})
		preview.target_positions.append(position)
		preview.hits.append({"position": position, "hit_count": strikes.size(),
			"strikes": strikes, "first_damage": strikes[0].damage,
			"second_damage": strikes[1].damage if strikes.size() > 1 else 0,
			"pin_bonus": bonus, "pin_consumed": bonus > 0,
			"weak": int(plan.attacker_statuses.get("weak", 0)),
			"exposed": int(plan.defender_statuses.get("exposed", 0)),
			"applies_pinned": remaining_hp > 0,
			"hp_after": remaining_hp, "block_after": remaining_block})
	preview.playable = not preview.target_positions.is_empty()
	return preview


## Identical read-only damage preview, but express Pin and Pound as two
## sequential hits on the chosen target, not a single damage packet, and include
## any conditional first-hit bonus without mutating or latching anything.
func _heavy_forecast(party: CombatParty, enemies: CombatEnemies, id: String) -> Dictionary:
	var preview := _pool_forecast(party, enemies, id)
	if not preview.playable:
		return preview
	var effects: Dictionary = _definition(id).get("effects", {})
	var count: int = int(effects.get("hits", 1))
	var definition := _definition(id)
	var damage: int = int(effects.get("damage", 0))
	var owner: Variant = definition.get("owner")
	var owner_statuses: Dictionary = {}
	for hero in party.get_heroes():
		if hero.get("id") == owner:
			owner_statuses = hero.get("statuses", {})
			break
	for hit in preview.hits:
		hit["hit_count"] = count
		var position: int = int(hit.get("position", 0))
		var mitt_bonus := 0
		if _fray != null:
			var quote: Dictionary = _fray.quote_heavy_hit(id, position)
			mitt_bonus = int(quote.get("bonus", 0))
		var enemy: Dictionary = enemies.get_enemy(position)
		var defender: Dictionary = enemy.get("statuses", {})
		var hit1_dmg: int = _statuses.adjusted_attack_damage(damage + mitt_bonus, owner_statuses, defender)
		hit["damage"] = hit1_dmg
		if count == 2:
			var hit2_dmg: int = _statuses.adjusted_attack_damage(damage, owner_statuses, defender)
			hit["first_damage"] = hit1_dmg
			hit["second_damage"] = hit2_dmg
			if mitt_bonus > 0:
				hit["mitt_bonus"] = mitt_bonus
		elif mitt_bonus > 0:
			hit["mitt_bonus"] = mitt_bonus
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
	var path_ok: bool = (_is_path_card(id) and not _path_positions(id).is_empty()) \
		or (_is_warden_card(id) and warden_preview(id).get("playable", false))
	return (id in TETHER_STARTERS or _moth_lure.is_supported_card(id) or _monk.is_supported_card(id) or _needle.is_supported_card(id) or _barrage.is_supported_card(id) or _lunge.is_supported_card(id) or _snare.is_supported_card(id) or _prick.is_supported_card(id) or _thread.is_supported_card(id) or _overload.is_supported_card(id) or _casing_clamp.is_supported_card(id) or _targeting.supports(id) or _helmet.is_supported_card(id) or _toss.is_supported_card(id) or _rivet.is_supported_card(id) or _direct_fire_preview.supports(id) or _stitch_preview(id).playable or path_ok) and index < _deck.hand.size() and _deck.hand[index] == id


func _sync_battle() -> void:
	var app = get_parent()
	if app._battle_closed and not _tether_link.is_empty():
		retire_tether_battle()
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
		_heavy_attacks.set_patches(_play._patches)
		_controls.bind_head_patch_rules(head_rules)
		if head_rules != null:
			_play.bind_head_patch_rules(head_rules)
			# The direct-fire resolver reads the SAME battle-authenticated HEAD
			# projection as the starter service: a genuinely sewn Button Glass
			# Visor raises Rivet Shot's authored Exposed, and a stale projection
			# rejects the cast instead of silently playing the unpatched card.
			_direct_fire.bind_head_patch_rules(head_rules)
		last_event = {}
		# One Pinned set and one Unravel gauge live for this whole battle session.
		# They are created here and never recreated or reset by a hand refresh.
		_pinned = CombatPinned.new()
		if carry != null and carry._wardrobe != null and _play._patches != null \
				and _play._patches.is_valid():
			_pinned.bind_relay(_deck, app.party, app.enemies, carry._wardrobe, carry.torn)
		_direct_fire.set_pinned(_pinned)
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
		_heavy_attacks.set_pinned(_pinned)
		_heavy_attacks.set_mitt(_fray)
		var warden_receipt: Variant = app._warden_battle_receipt()
		if app.run_map != null and warden_receipt is Dictionary \
				and warden_receipt.get("path_id") == "vanguard":
			var passive := CombatWardenVanguardPassive.new()
			if passive.bind_battle(warden_receipt, _deck, app.party, app.enemies,
					_pinned, _heavy_attacks) and passive.begin_player_turn(_deck,
					app.party, app.enemies, _pinned, _heavy_attacks):
				_vanguard = passive
				_warden_turn = app.enemy_intents._turn_index
		# The selected Path card is bound only to this battle's genuine receipt,
		# deck, party, roster and the one gauge shared with its round flow.
		_bind_path_cards(app)
		_bind_warden_path(app)
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
		_overload_hud = Label.new()
		_overload_hud.name = "OverloadCombatScrap"
		_overload_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overload_hud.add_theme_font_size_override("font_size", 18)
		column.add_child(_overload_hud)
		column.move_child(_overload_hud, cue.get_index())
	var held_tinker_scrap := false
	for held_id in _deck.hand:
		if _overload.is_supported_card(held_id) or _casing_clamp.is_supported_card(held_id):
			held_tinker_scrap = true
	var overload_receipt: bool = _overload.is_supported_card(last_event.get("card_id", "")) and last_event.get("ok", false)
	var casing_receipt: bool = _casing_clamp.is_supported_card(last_event.get("card_id", "")) and last_event.get("ok", false)
	_overload_hud.visible = held_tinker_scrap or overload_receipt or casing_receipt
	if _overload_hud.visible:
		var scrap: Variant = _tinker_hero().get("combat_scrap", 0)
		_overload_hud.text = "Tinker Combat Scrap: %s" % str(scrap)
		if overload_receipt:
			_overload_hud.text += " | Overload: %d damage, spent %d Combat Scrap" % [last_event.damage, last_event.combat_scrap_spent]
		elif casing_receipt:
			_overload_hud.text += " | %s: %d damage, gained %d Combat Scrap" % [
				"Spring Clamp" if str(last_event.card_id).begins_with("tinker_v3_spring_clamp") else "Brass Casing",
				last_event.raw_damage, last_event.combat_scrap_gained]
	if _session != [app.party, app.enemies, app.battle_result, app.run_rng, app.enemy_intents]:
		retire_tether_battle()
		_cancel_choice()
		_session = [app.party, app.enemies, app.battle_result, app.run_rng, app.enemy_intents]
	if app.enemy_intents != null and _turn != app.enemy_intents._turn_index:
		_turn = app.enemy_intents._turn_index
		_play.start_player_turn()
		ensure_quilt_switchback_bound()
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
		# Let Enter/Space arm this targeted control without moving its click area.
		if _moth_lure.is_supported_card(_card_id(panel)):
			panel.focus_mode = Control.FOCUS_ALL
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
	ensure_quilt_switchback_bound()
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
			names.append(RunRestStitchCards.resolve_card_definition(half.card_id).display_name)
		var details: PackedStringArray = []
		for index in range(2):
			var half: Dictionary = stitched.halves[index]
			details.append("%d: %s %s" % [index + 1, half.side, str(half.target_positions) if half.requires_selection else "automatic (0), slots " + str(half.affected_positions)])
		var controls := "Half %d: 1-3 / click hero or enemy" % mini(_choices.size() + 1, 2)
		if _selected == _armed and _choices.size() == 2:
			controls = "Enter / Space / click card: cast"
		cue.text = "%s | %d energy | %s\n%s; Esc: cancel" % [" / ".join(names), stitched.cost, "; ".join(details), controls]
		if _selected == _armed and _choices.size() == 2 and _receipt == app._stitch_snapshot() and _run_map == app.run_map:
			current_forecast = CombatStitchedEffectForecast.new().get_forecast(_ledger(), _receipt, _deck, app.party, app.enemies, id, _choices[0], _choices[1], _stitched_transaction(app))
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
					if half.get("effect") == "exposed_and_draw":
						effects.append("enemy %d: Exposed %d, draw %d" % [half.target, half.exposed_applied, half.draw])
					elif half.has("effect"):
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
	if _is_warden_card(id):
		var quote := warden_preview(id)
		current_forecast = quote.duplicate(true)
		var effects := "Unavailable"
		if quote.get("ok", false):
			if definition.target_kind == "self":
				effects = "Warden gains %d Block" % int(quote.expected_block)
			else:
				var readings: PackedStringArray = []
				for target in quote.targets:
					readings.append("%d: %d damage, Pin surviving enemy" % [target.position, target.expected_damage])
				effects = "; ".join(readings)
		cue.text = "%s | %d energy | P / click card; %s\n%s" % [
			definition.display_name, definition.cost,
			"1-2 / click enemy" if definition.target_kind == "enemy_single" else "Enter / Space",
			effects]
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
	if id in TETHER_STARTERS:
		var link_preview := tether_preview(id)
		var first := ""
		if _selected == _armed and _tether_positions.size() == 1:
			first = "First foe %d selected; choose a different second foe. " % _tether_positions[0]
		cue.text = "%s | %d energy | P / click card; 1-3 / click each foe; Esc: cancel\n%sLink TWO distinct living foes: later confirmed card HP loss echoes 50%% (rounded down) to the partner through Block; no immediate damage. Available %s" % [
			definition.display_name, definition.cost, first,
			str(link_preview.target_positions) if link_preview.playable else "none"]
		current_forecast = link_preview.duplicate(true)
		return
	var preview := _resolve_attack(app.party, app.enemies, id, 0, true)
	if _moth_lure.is_supported_card(id):
		current_forecast = preview.duplicate(true)
		var readings: PackedStringArray = []
		for target in preview.hits:
			readings.append("%d: Blind %d → 1, draw %d" % [
				target.position, target.blind_before, target.draw])
		cue.text = "%s | %d energy | P / click card; %s / click enemy; Esc: cancel\n%s" % [
			definition.display_name, definition.cost, _key_hint(preview.target_positions),
			"Choose one enemy slot: " + "; ".join(readings) if preview.playable else
			"Unavailable: no held/affordable Moth Lure, living Monk in 2-3, or legal enemy"]
		return
	if _monk.is_supported_card(id):
		current_forecast = preview.duplicate(true)
		var choices: PackedStringArray = []
		for hit in preview.hits:
			var line := "%d: %d damage, then Blind next attack" % [hit.position, hit.damage]
			if int(hit.get("exposed_added", 0)) > 0:
				line += ", then Exposed %d → %d" % [hit.exposed_before, hit.exposed_after]
			choices.append(line)
		cue.text = "%s | %d energy | P / click card; %s / click enemy; Esc: cancel\n%s" % [
			definition.display_name, definition.cost, _key_hint(preview.target_positions),
			"Choose one enemy slot: " + "; ".join(choices) if preview.playable else "Unavailable: no legal lantern strike target or energy"]
		return
	if _needle.is_supported_card(id):
		current_forecast = preview.duplicate(true)
		var choices: PackedStringArray = []
		for hit in preview.hits:
			choices.append("%d: %d damage, then Unravel +%d if alive (gauge %d/%d)" % [
				int(hit.position), int(hit.damage), int(hit.unravel),
				int(hit.gauge), int(hit.threshold)])
		var reading := "Unavailable: no held/affordable needle, living target or shared gauge"
		if preview.playable:
			reading = "Choose one enemy slot: " + "; ".join(choices)
		cue.text = "%s | %d energy | P / click card; %s / click enemy; Esc: cancel\n%s" % [
			definition.display_name, definition.cost, _key_hint(preview.target_positions), reading]
		return
	if _rivet.is_supported_card(id):
		current_forecast = preview.duplicate(true)
		var details: PackedStringArray = []
		for target in preview.hits:
			var line := "%d: %d + %d damage" % [target.position,
				target.first_damage, target.second_damage]
			if target.hit_count < 2:
				line += " (first hit lethal)"
			if target.pin_bonus > 0:
				line += " (+%d cross-hero Pin on first)" % target.pin_bonus
			if target.weak > 0:
				line += ", Weak %d" % target.weak
			if target.exposed > 0:
				line += ", Exposed %d" % target.exposed
			line += ", Block %d, HP %d, %s" % [target.block_after,
				target.hp_after, "Pin survivor" if target.applies_pinned else "no Pin on slain foe"]
			details.append(line)
		cue.text = "%s | 2 energy | P / click card; %s / click enemy; Esc: cancel\n%s" % [
			definition.display_name, _key_hint(preview.target_positions),
			"Two printed hits; choose foe: " + "; ".join(details) if preview.playable else
			"Unavailable: no held/affordable Rivet, living Warden in 1-2 or legal foe in 1-2"]
		return
	if _barrage.is_supported_card(id):
		current_forecast = preview.duplicate(true)
		var choices: PackedStringArray = []
		for hit in preview.hits:
			choices.append("enemy %d: 3 separate strikes x %d base damage" % [hit.position, hit.base_damage])
		var reading := "Unavailable: no legal target or 2 energy"
		if preview.playable:
			reading = "Choose one foe (all 3 hits stay on it): " + "; ".join(choices)
		cue.text = "%s | %d energy | P / click card; %s / click enemy; Esc: cancel\n%s" % [
			definition.display_name, definition.cost, _key_hint(preview.target_positions), reading]
		return
	if _prick.is_supported_card(id):
		current_forecast = preview.duplicate(true)
		var details: PackedStringArray = []
		for hit in preview.hits:
			details.append("%d: %d damage, then Bleed %d -> %d (even through Block)" % [
				hit.position, hit.damage, hit.bleed_before, hit.bleed_after])
		var reading := "Unavailable: no legal living target, owner or energy"
		if preview.playable:
			reading = "Choose one enemy slot: " + "; ".join(details)
		cue.text = "%s | %d energy | P / click card; %s / click enemy; Esc: cancel\n%s" % [
			definition.display_name, definition.cost, _key_hint(preview.target_positions), reading]
		return
	if _snare.is_supported_card(id):
		current_forecast = preview.duplicate(true)
		var details: PackedStringArray = []
		for target in preview.targets:
			details.append("%d: Tangled %d -> %d (+%d)" % [target.position,
				target.tangled_before, target.tangled_after, target.tangled_added])
		var reading := "Unavailable: no legal living enemy, owner, energy or Tangled capacity"
		if preview.playable:
			reading = "Choose one enemy slot: " + "; ".join(details)
		cue.text = "%s | %d energy | P / click card; %s / click enemy; Esc: cancel\n%s" % [
			definition.display_name, definition.cost, _key_hint(preview.target_positions), reading]
		return
	if _lunge.is_supported_card(id):
		current_forecast = preview.duplicate(true)
		var details: PackedStringArray = []
		for hit in preview.hits:
			details.append("%d: %d damage" % [hit.position, hit.damage])
		var reading := "Unavailable: no legal target, energy or forward swap"
		if preview.playable:
			reading = "Choose one enemy slot: %s; move forward %d -> %d" % [
				"; ".join(details), preview.owner_position, preview.destination_position]
		cue.text = "%s | %d energy | P / click card; %s / click enemy; Esc: cancel\n%s" % [
			definition.display_name, definition.cost, _key_hint(preview.target_positions), reading]
		return
	if _thread.is_supported_card(id):
		current_forecast = preview.duplicate(true)
		var details: PackedStringArray = []
		for hit in preview.hits:
			var detail := "%d: %d damage" % [hit.position, hit.damage]
			if int(hit.pin_bonus) > 0:
				detail += " (+%d Pinned, consumed)" % int(hit.pin_bonus)
			if hit.applies_pinned:
				detail += ", then Pin if it survives"
			if int(hit.tangled_added) > 0:
				detail += ", then Tangled %d -> %d" % [int(hit.tangled_before),
					int(hit.tangled_before) + int(hit.tangled_added)]
			details.append(detail)
		var reading := "Unavailable: no legal target, energy or Golem in seat 1-2"
		if preview.playable:
			reading = "Choose one enemy slot: " + "; ".join(details)
		cue.text = "%s | %d energy | P / click card; %s / click enemy; Esc: cancel\n%s" % [
			definition.display_name, definition.cost, _key_hint(preview.target_positions), reading]
		return
	if _overload.is_supported_card(id) or _casing_clamp.is_supported_card(id) or _toss.is_supported_card(id) or _helmet.is_supported_card(id):
		current_forecast = preview.duplicate(true)
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
	if not is_pool and not is_heavy and not is_direct and not _overload.is_supported_card(id) and not _casing_clamp.is_supported_card(id) and not _toss.is_supported_card(id) and not _helmet.is_supported_card(id) and preview.playable:
		# This is the same pure status preflight as the confirmed attack, including
		# the authored passive, HEAD bonus, M04 rider and capacity eligibility.
		var status_plan := _play._prepare(_deck, app.party, app.enemies, id, 0,
			{}, {}, false, tinker_cost_discount(id))
		if status_plan.get("ok", false):
			additions_by_position = status_plan.applications
	for hit in preview.hits:
		var detail: String
		if int(hit.get("hit_count", 1)) == 2:
			if hit.has("first_damage") and hit.has("second_damage") and hit["first_damage"] != hit["second_damage"]:
				detail = "%d: 2 hits (%d + %d damage)" % [hit.position, hit.first_damage, hit.second_damage]
			else:
				detail = "%d: 2 hits x %d damage each" % [hit.position, hit.damage]
		else:
			detail = "%d: %d damage" % [hit.position, hit.damage]
		var enemy: Dictionary = app.enemies.get_enemy(hit.position)
		var current: Dictionary = enemy.get("statuses", {})
		var additions: Dictionary = additions_by_position.get(hit.position, {})
		for status in additions:
			var amount: int = additions[status]
			var previous: int = current.get(status, 0)
			detail += " (%s %d → %d on confirmed hit)" % [status.capitalize(), previous, previous + amount]
		if is_direct and int(hit.get("exposed_added", 0)) > 0:
			detail += " (Exposed %d → %d after hit)" % [hit.exposed_before, hit.exposed_after]
		if _helmet.is_supported_card(id):
			detail += " (then Weak 1)"
		if _casing_clamp.is_supported_card(id) and int(hit.get("weak", 0)) > 0:
			detail += " (then Weak %d even through Block)" % int(hit.weak)
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
	elif is_pool or is_heavy or is_direct or _overload.is_supported_card(id) or _casing_clamp.is_supported_card(id) or _toss.is_supported_card(id) or _helmet.is_supported_card(id):
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
	if _overload.is_supported_card(id) and preview.playable:
		description += " | Combat Scrap %d -> 0" % int(preview.hits[0].combat_scrap_spent)
	if _casing_clamp.is_supported_card(id) and preview.playable:
		description += " | Tinker Combat Scrap %d -> %d" % [
			int(preview.hits[0].combat_scrap_before),
			int(preview.hits[0].combat_scrap_before) + int(preview.hits[0].combat_scrap_gain)]
	var shown_cost: int = int(definition.cost) if (_overload.is_supported_card(id) or _casing_clamp.is_supported_card(id)) else maxi(0, int(definition.cost) - tinker_cost_discount(id))
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
	retire_tether_battle()
	if _vanguard != null:
		_vanguard.retire_battle()
	_vanguard = null
	_warden_turn = -1
	_cancel_choice()
	_turn = -1
	for panel in _bindings.keys():
		_unbind(panel)
	if is_instance_valid(_battle) and _battle.tree_exiting.is_connected(_clear):
		_battle.tree_exiting.disconnect(_clear)
	if is_instance_valid(cue):
		cue.queue_free()
	cue = null
	if is_instance_valid(_overload_hud):
		_overload_hud.queue_free()
	_overload_hud = null
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
	_warden_receipt.clear()
	_warden_card.clear()
	_routed_gauge_shared = false
	_fray = null
	_heavy_attacks = CombatWardenPoolHeavyAttacks.new()
	_play = CombatAttackCards.new() # Return/title retires the prior battle's wearer latch.
	_controls = CombatSeamstressPoolControl.new()
	_direct_fire = CombatTinkerPoolAttacks.new(_play._tinker)
	_selected = null
	_receipt_seq = 0


func _warden_current(turn_offset: int = 0) -> bool:
	var app = get_parent()
	return app != null and app._combo_battle_current() and app.deck == _deck \
		and app.enemy_intents._turn_index == _warden_turn + turn_offset \
		and _session == [app.party, app.enemies, app.battle_result, app.run_rng, app.enemy_intents] \
		and app._warden_battle_receipt() == app.run_warden_path_receipt


## Only the app's successful End Turn owns this notification. Refresh and hover
## cannot re-arm, and duplicate notifications see the same intent index.
func advance_warden_turn() -> void:
	var app = get_parent()
	if _vanguard == null or app == null or app.deck != _deck \
			or app.enemy_intents == null or not _warden_current(1):
		return
	if _vanguard.advance_confirmed_turn():
		_warden_turn = app.enemy_intents._turn_index



## Ensure combat Quilt authority is bound to an authentic sewn wardrobe and torn ledger.
## Fails closed for absent, stale, unrelated or unequipped wardrobe.
func ensure_quilt_switchback_bound() -> void:
	var app = get_parent()
	if app == null or not is_instance_valid(app):
		return
	var quilt: CombatQuiltBonus = app._quilt_bonus
	if quilt == null or not is_instance_valid(quilt) or not quilt is CombatQuiltBonus:
		return
	var carry := app.party_carryover as RunTornCarryover
	if carry == null or not is_instance_valid(carry) or carry._wardrobe == null or carry.torn == null:
		if quilt.is_switchback_active():
			quilt.disable_switchback()
		return
	var wardrobe: RunPatchWardrobe = carry._wardrobe
	var torn: RunTornMending = carry.torn
	if not is_instance_valid(wardrobe) or not is_instance_valid(torn):
		if quilt.is_switchback_active():
			quilt.disable_switchback()
		return
	if not wardrobe.is_valid() or not torn.is_valid():
		if quilt.is_switchback_active():
			quilt.disable_switchback()
		return
	var current: Dictionary = wardrobe.get_snapshot()
	if not carry.can_bind_wardrobe(wardrobe, torn, current):
		if quilt.is_switchback_active():
			quilt.disable_switchback()
		return
	if current.heroes != app.run_heroes or current.owned != app.run_trinkets \
			or current.cards != app.run_deck or current.scraps != app.run_scraps \
			or current.gold != app.session_gold or current.seed != app.run_seed:
		if quilt.is_switchback_active():
			quilt.disable_switchback()
		return
	var worn: Dictionary = current.get("worn", {})
	var has_switchback := false
	for hero_id in worn:
		var hero_worn: Dictionary = worn.get(hero_id, {})
		if hero_worn.get("HEAD") == "switchback_button":
			has_switchback = true
			break
	if not has_switchback:
		if quilt.is_switchback_active():
			quilt.disable_switchback()
		return
	if not quilt.is_switchback_active() or quilt._switchback_wardrobe != wardrobe or quilt._switchback_torn != torn:
		quilt.enable_switchback(wardrobe, torn)


func _owner_for_attack_card(card_id: String) -> String:
	if _is_path_card(card_id):
		return CombatSeamstressPathCards.OWNER_ID
	if _tinker_path != null and card_id == str(_tinker_path._selected_card.get("id", "")):
		return "tinker"
	var def := _definition(card_id)
	var owner: String = str(def.get("owner", ""))
	if owner in CombatQuiltBonus.HERO_IDS:
		return owner
	return ""


func _forward_switchback_ordinary_play(card_id: String) -> void:
	var app = get_parent()
	if app == null or not is_instance_valid(app):
		return
	ensure_quilt_switchback_bound()
	var quilt: CombatQuiltBonus = app._quilt_bonus
	if quilt == null or not is_instance_valid(quilt) or not quilt is CombatQuiltBonus or not quilt.is_switchback_active():
		return
	var owner: String = _owner_for_attack_card(card_id)
	if owner.is_empty() or not owner in CombatQuiltBonus.HERO_IDS:
		return
	_receipt_seq += 1
	var receipt_id := "attack_%d" % _receipt_seq
	quilt.observe_confirmed_play(receipt_id, owner)


func _forward_switchback_stitched_play(stitched_id: String, preview: Dictionary) -> void:
	var app = get_parent()
	if app == null or not is_instance_valid(app):
		return
	ensure_quilt_switchback_bound()
	var quilt: CombatQuiltBonus = app._quilt_bonus
	if quilt == null or not is_instance_valid(quilt) or not quilt is CombatQuiltBonus:
		return
	if not quilt.is_switchback_active():
		return
	var halves: Array = preview.get("halves", [])
	if halves.size() != 2:
		return
	var first_owner: String = str(halves[0].get("owner", ""))
	var second_owner: String = str(halves[1].get("owner", ""))
	if not first_owner in CombatQuiltBonus.HERO_IDS or not second_owner in CombatQuiltBonus.HERO_IDS:
		return
	_receipt_seq += 1
	var first_receipt := "stitched_%d_0" % _receipt_seq
	var second_receipt := "stitched_%d_1" % _receipt_seq
	quilt.observe_confirmed_stitched_play(first_receipt, first_owner, second_receipt, second_owner)


## Read-only Knuckle/Snag offer: the resolver's own preflight against this
## battle's shared Pinned set, slot by original slot. Nothing is paid or consumed.
func _thread_forecast(party: CombatParty, enemies: CombatEnemies, id: String) -> Dictionary:
	var unavailable := {"playable": false, "requires_selection": true, "target_positions": [], "hits": []}
	var app = get_parent()
	if app == null or _deck == null or _pinned == null or app.deck != _deck or app._battle_closed \
			or app.enemy_intents == null or _turn != app.enemy_intents._turn_index \
			or _deck._rng != app.run_rng or party != app.party or enemies != app.enemies \
			or _session != [party, enemies, app.battle_result, app.run_rng, app.enemy_intents]:
		return unavailable
	var positions: Array[int] = []
	var hits: Array[Dictionary] = []
	var seat := 0
	for position in range(1, enemies.get_enemies().size() + 1):
		var plan := _thread._prepare(_deck, party, enemies, id, position, _pinned)
		if not plan.ok:
			continue
		seat = plan.owner_position
		positions.append(position)
		hits.append({"position": position, "damage": _statuses.adjusted_attack_damage(
			plan.base_damage, plan.attacker_statuses, plan.defender_statuses),
			"pin_bonus": plan.pin_bonus, "applies_pinned": plan.applies_pinned,
			"tangled_added": plan.tangled_added,
			"tangled_before": int(plan.defender_statuses.get("tangled", 0))})
	if positions.is_empty():
		return unavailable
	return {"playable": true, "requires_selection": true, "target_positions": positions,
		"hits": hits, "owner_position": seat}


## A needle preview is read-only and uses the paid resolver's exact preflight
## for each ORIGINAL enemy seat. No alternate damage or gauge mutator is used.
func _needle_binding_ready(party: CombatParty, enemies: CombatEnemies) -> bool:
	var app = get_parent()
	if app == null or _unravel == null or _pinned == null or _deck == null \
			or app.deck != _deck or app.party != party or app.enemies != enemies \
			or _unravel._bound_enemies != enemies or app._battle_closed:
		return false
	var flow := _matching_flow(app, party, enemies)
	return flow != null and (flow._unravel == null or flow._unravel == _unravel)


func _needle_forecast(party: CombatParty, enemies: CombatEnemies, id: String) -> Dictionary:
	var unavailable := {"playable": false, "requires_selection": true,
		"target_positions": [], "hits": []}
	var app = get_parent()
	if not _needle.is_supported_card(id) or not _needle_binding_ready(party, enemies) \
			or app.enemy_intents == null or _turn != app.enemy_intents._turn_index \
			or _deck._rng != app.run_rng \
			or _session != [party, enemies, app.battle_result, app.run_rng, app.enemy_intents]:
		return unavailable
	var positions: Array[int] = []
	var hits: Array[Dictionary] = []
	for position in CombatYarnRangerNeedleCards.TO_POSITIONS:
		var plan: Dictionary = _needle._prepare(_deck, party, enemies, _unravel, id, position)
		if not plan.get("ok", false):
			continue
		var gauge := _unravel.get_snapshot(position)
		positions.append(position)
		hits.append({"position": position,
			"damage": _statuses.adjusted_attack_damage(int(plan.damage),
				plan.attacker_statuses, plan.defender_statuses),
			"unravel": int(plan.unravel), "gauge": int(gauge.gauge),
			"threshold": int(gauge.threshold)})
	return {"playable": not positions.is_empty(), "requires_selection": true,
		"target_positions": positions, "hits": hits}


## The paid Needle Barrage resolver owns both admission and every sequential strike.
## Only its read-only preflight offers original living enemy slots; no pooled
## three-hit damage or speculative adjusted HP/Block totals are shown.
func _barrage_forecast(party: CombatParty, enemies: CombatEnemies, id: String) -> Dictionary:
	var unavailable := {"playable": false, "requires_selection": true, "target_positions": [], "hits": []}
	var app = get_parent()
	if app == null or _deck == null or app.deck != _deck or app._battle_closed \
			or app.enemy_intents == null or _turn != app.enemy_intents._turn_index \
			or _deck._rng != app.run_rng or party != app.party or enemies != app.enemies \
			or _session != [party, enemies, app.battle_result, app.run_rng, app.enemy_intents]:
		return unavailable
	var positions: Array[int] = []
	var hits: Array[Dictionary] = []
	for position in CombatRagDuelistNeedleBarrageCards.TO_POSITIONS:
		var plan: Dictionary = _barrage._prepare(_deck, party, enemies, id, position)
		if not plan.get("ok", false):
			continue
		positions.append(position)
		hits.append({"position": position, "hit_count": 3,
			"base_damage": int(plan.base_damage)})
	return {"playable": not positions.is_empty(), "requires_selection": true,
		"target_positions": positions, "hits": hits}


## Needle Prick offers only original slots authenticated by the paid preflight.
## The projected status-adjusted hit and post-hit Bleed never mutate either roster.
func _prick_forecast(party: CombatParty, enemies: CombatEnemies, id: String) -> Dictionary:
	var unavailable := {"playable": false, "requires_selection": true,
		"target_positions": [], "hits": []}
	var app = get_parent()
	if app == null or _deck == null or app.deck != _deck or app._battle_closed \
			or app.enemy_intents == null or _turn != app.enemy_intents._turn_index \
			or _deck._rng != app.run_rng or party != app.party or enemies != app.enemies \
			or _session != [party, enemies, app.battle_result, app.run_rng, app.enemy_intents] \
			or not _prick.is_supported_card(id):
		return unavailable
	var positions: Array[int] = []
	var hits: Array[Dictionary] = []
	for position in CombatRagDuelistNeedlePrickCards.TO_POSITIONS:
		var plan: Dictionary = _prick._prepare(_deck, party, enemies, id, position)
		if not plan.get("ok", false):
			continue
		var damage: int = _statuses.adjusted_attack_damage(int(plan.base_damage),
			plan.attacker_statuses, plan.defender_statuses)
		positions.append(position)
		hits.append({"position": position, "damage": damage,
			"base_damage": int(plan.base_damage), "bleed_applied": int(plan.bleed),
			"bleed_before": int(plan.bleed_before),
			"bleed_after": int(plan.bleed_before) + int(plan.bleed)})
	return {"playable": not positions.is_empty(), "requires_selection": true,
		"target_positions": positions, "hits": hits}


## Status-only forecast delegates legality, including Tangled overflow, to the
## paid authority for each ORIGINAL enemy slot. Never invent a damage hit.
func _snare_forecast(party: CombatParty, enemies: CombatEnemies, id: String) -> Dictionary:
	var unavailable := {"playable": false, "requires_selection": true,
		"target_positions": [], "targets": []}
	var app = get_parent()
	if app == null or _deck == null or app.deck != _deck or app._battle_closed \
			or app.enemy_intents == null or _turn != app.enemy_intents._turn_index \
			or _deck._rng != app.run_rng or party != app.party or enemies != app.enemies \
			or _session != [party, enemies, app.battle_result, app.run_rng, app.enemy_intents] \
			or not _snare.is_supported_card(id):
		return unavailable
	var slots: Array[int] = []
	var targets: Array[Dictionary] = []
	for position in CombatRagDuelistTatteredSnareCards.TO_POSITIONS:
		var plan: Dictionary = _snare._prepare(_deck, party, enemies, id, position)
		if not plan.get("ok", false):
			continue
		var enemy: Dictionary = enemies.get_enemy(position)
		var before: int = int(enemy.get("statuses", {}).get("tangled", 0))
		slots.append(position)
		targets.append({"position": position, "tangled_before": before,
			"tangled_added": int(plan.tangled_added), "tangled_after": before + int(plan.tangled_added)})
	return {"playable": not slots.is_empty(), "requires_selection": true,
		"target_positions": slots, "targets": targets}


## Read-only mirror of the Lunge authority's preflight; mutation stays in play_card.
func _lunge_forecast(party: CombatParty, enemies: CombatEnemies, id: String) -> Dictionary:
	var unavailable := {"playable": false, "requires_selection": true, "target_positions": [], "hits": []}
	var app = get_parent()
	if app == null or _deck == null or app.deck != _deck or app._battle_closed \
			or app.enemy_intents == null or _turn != app.enemy_intents._turn_index \
			or _deck._rng != app.run_rng or party != app.party or enemies != app.enemies \
			or _session != [party, enemies, app.battle_result, app.run_rng, app.enemy_intents]:
		return unavailable
	if _deck == null or _deck.combat_state == null or _deck._rng == null \
			or not _deck.turn_active or not _deck.hand.has(id) or _deck.energy < 1 \
			or party == null or enemies == null or not party.is_valid() or not enemies.is_valid() \
			or not _lunge._authentic(_lunge._catalog_definition(id), id) \
			or not _lunge._valid_actors(party.get_heroes()) \
			or not _lunge._valid_actors(enemies.get_enemies()):
		return unavailable
	var seat := 0
	for hero in party.get_heroes():
		if hero.id == "rag_duelist":
			seat = hero.position
	if seat not in [2, 3] or not CombatPositionSwaps.preview_adjacent_swap(party, seat, -1).ok:
		return unavailable
	var mover := party.get_hero(seat)
	if CombatPositionSwaps._tangled_blocks(mover) \
			or CombatPositionSwaps._tangled_blocks(party.get_hero(seat - 1)):
		return unavailable
	var positions: Array[int] = []
	var hits: Array[Dictionary] = []
	for position in [1, 2]:
		var enemy := enemies.get_enemy(position)
		if enemy.is_empty() or enemies.is_slain(position):
			continue
		positions.append(position)
		hits.append({"position": position, "damage": _statuses.adjusted_attack_damage(
			_lunge.CARDS[id], mover.get("statuses", {}), enemy.get("statuses", {}))})
	return {"playable": not positions.is_empty(), "requires_selection": true,
		"target_positions": positions, "hits": hits, "owner_position": seat,
		"destination_position": seat - 1}


## Only the starter Tether Loop pair is payable here. The pool Stitch pair
## remains a rules-layer definition, not a live hand action.
const TETHER_STARTERS := ["seamstress_v3_tether_loop", "seamstress_v3_tether_loop_plus"]
var _tether_rules := CombatSeamstressTetherRules.new()
var _tether_link: Dictionary = {}
var _tether_link_session: Array = []
var _tether_link_map
var _tether_positions: Array[int] = []
var _tether_enemy_ids: Array[String] = []


func _tether_definition(card_id: String) -> Dictionary:
	if card_id not in TETHER_STARTERS:
		return {}
	return _tether_rules.get_tether_definition(card_id)


## An authentic, currently held printing and a real matching mounted fight.
## Never let preview or a selection reserve energy or alter the roster.
func tether_preview(card_id: String) -> Dictionary:
	var unavailable := {"playable": false, "requires_selection": true, "target_positions": []}
	var app = get_parent()
	var definition := _tether_definition(card_id)
	if definition.is_empty() or _deck == null or app == null or app.deck != _deck \
			or app.enemies == null or app.party == null or app.enemy_intents == null \
			or not app._combo_battle_current() or _deck._rng != app.run_rng \
			or _session != [app.party, app.enemies, app.battle_result, app.run_rng, app.enemy_intents] \
			or _turn != app.enemy_intents._turn_index or not _deck.hand.has(card_id) \
			or _deck.energy < int(definition.cost):
		return unavailable
	var seamstress := {}
	for hero in app.party.get_heroes():
		if hero.get("id") == "seamstress":
			if not seamstress.is_empty():
				return unavailable
			seamstress = hero
	if seamstress.is_empty() or int(seamstress.get("hp", 0)) <= 0 \
			or int(seamstress.get("position", 0)) not in definition.from_positions:
		return unavailable
	var positions: Array[int] = []
	for pos in definition.to_positions:
		var enemy: Dictionary = app.enemies.get_enemy(int(pos))
		if not enemy.is_empty() and not app.enemies.is_slain(int(pos)) \
				and int(enemy.get("hp", 0)) > 0:
			positions.append(int(pos))
	if positions.size() < 2:
		return unavailable
	return {"playable": true, "requires_selection": true, "target_positions": positions}


func _choose_tether(position: int) -> void:
	if _queued or not _bindings.has(_armed) or not _eligible(_armed):
		return
	var card_id := _card_id(_armed)
	var preview := tether_preview(card_id)
	if not preview.playable or position not in preview.target_positions:
		return
	if _tether_positions.size() > 0 and _tether_positions[0] == position:
		return # Duplicate is not a second target, and never pays.
	var app = get_parent()
	var enemy_id := str(app.enemies.get_enemy(position).get("id", ""))
	if enemy_id.is_empty():
		return
	_tether_positions.append(position)
	_tether_enemy_ids.append(enemy_id)
	if _tether_positions.size() == 1:
		_refresh()
		return
	_queued = true
	_commit_tether.call_deferred(_armed, card_id, _token,
		_tether_positions.duplicate(), _tether_enemy_ids.duplicate(),
		_armed.get_index(), _deck, _deck.hand.duplicate(),
		_session.duplicate(), _turn, app.run_map)
	_refresh()


## Commit on the next frame so all mouse/keyboard paths share the identical
## fail-closed hand, pair, seat, budget, identity and battle revalidation.
func _commit_tether(panel, card_id: String, token: int, positions: Array,
		enemy_ids: Array, panel_index: int, queued_deck, queued_hand: Array,
		session: Array, turn: int, queued_map) -> void:
	var app = get_parent()
	if token != _token or not _queued or app == null or not is_inside_tree():
		return
	_queued = false
	var legal: bool = positions.size() == 2 and enemy_ids.size() == 2 \
		and positions[0] != positions[1] and not _tether_definition(card_id).is_empty() \
		and _bindings.has(panel) and panel == _armed and _eligible(panel) \
		and _card_id(panel) == card_id and _bindings[panel].id == card_id \
		and panel_index >= 0 and panel.get_index() == panel_index \
		and app.get_node_or_null("LiveAttackPreview") == self \
		and app.deck == queued_deck and _deck == queued_deck \
		and _deck.hand == queued_hand and app.run_map == queued_map \
		and _session == session and _turn == turn \
		and app.enemy_intents != null and app.enemy_intents._turn_index == turn
	if not legal:
		_reject_stitch()
		return
	var preview := tether_preview(card_id)
	if not preview.playable or positions[0] not in preview.target_positions \
			or positions[1] not in preview.target_positions \
			or app.enemies.get_enemy(int(positions[0])).get("id") != enemy_ids[0] \
			or app.enemies.get_enemy(int(positions[1])).get("id") != enemy_ids[1]:
		_reject_stitch()
		return
	var pair := _tether_rules.authorize_pair_link(app.enemies,
		_tether_definition(card_id), positions[0], positions[1])
	if not pair.get("ok", false) or pair.first_id != enemy_ids[0] \
			or pair.second_id != enemy_ids[1]:
		_reject_stitch()
		return
	var cost: int = int(pair.card_definition.cost)
	# All payment preconditions are now confirmed on these SAME models. A
	# denied spend cannot discard or install a link.
	if not _deck.try_spend_energy(cost):
		_reject_stitch()
		return
	_deck.discard_played(card_id)
	_tether_link = pair.duplicate(true)
	_tether_link_session = _session.duplicate()
	_tether_link_map = app.run_map
	last_event = {"ok": true, "card_id": card_id, "linked": positions.duplicate(),
		"energy_spent": cost, "hits": []}
	_after_attack()


func retire_tether_battle() -> void:
	_tether_link.clear()
	_tether_link_session.clear()
	_tether_link_map = null
	_tether_rules = CombatSeamstressTetherRules.new()


func _tether_link_current(enemies: CombatEnemies) -> bool:
	var app = get_parent()
	return not _tether_link.is_empty() and app != null and not app._battle_closed \
		and app.enemies == enemies and app.deck == _deck \
		and app._combo_battle_current() and app.run_map == _tether_link_map \
		and _session == _tether_link_session \
		and _tether_rules.is_valid_pair_link(_tether_link)


## Called only with a successful, real paid-card resolver receipt from the
## mounted flow, after that resolver mutated the actual roster. Reconstitute
## the precise four-field CombatStatusAttacks hit receipt (never its forecast).
## One hit per enemy is necessary for an unambiguous before/after transition;
## multi-hit sequences cannot be mistaken for one bridge receipt.
func apply_tether_confirmed_hits(enemies: CombatEnemies, before: Array,
		confirmed_card: Dictionary) -> void:
	if not _tether_link_current(enemies) or confirmed_card.get("ok") != true \
			or not confirmed_card.get("hits") is Array:
		return
	var after: Array = enemies.get_enemies()
	if before.size() != after.size():
		return
	var hits: Array = confirmed_card.hits
	for hit in hits:
		if not hit is Dictionary or not hit.get("position") is int:
			continue
		var pos: int = hit.position
		if pos < 1 or pos > before.size() or not before[pos - 1] is Dictionary:
			continue
		var occurrences := 0
		for entry in hits:
			if entry is Dictionary and entry.get("position") == pos:
				occurrences += 1
		if occurrences != 1:
			continue
		if not hit.get("damage") is int or not hit.get("hp_loss") is int \
				or not hit.get("block_absorbed") is int:
			continue
		var receipt := {"ok": true, "damage": hit.damage,
			"hp_loss": hit.hp_loss, "block_absorbed": hit.block_absorbed}
		var echo := _tether_rules.resolve_confirmed_hit_echo(enemies, _tether_link,
			pos, before[pos - 1], receipt)
		if echo.get("applied", false):
			last_event["tether_echo"] = echo.duplicate(true)
