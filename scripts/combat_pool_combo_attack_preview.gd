class_name CombatPoolComboAttackPreview
extends RefCounted
## Scene-free, read-only oracle for the eight single-enemy Warden/Tinker
## Pinning Jab, Seam Breaker, Spool Launcher and Snip the Seam variants.
## Every hypothetical hit runs through the *existing* combat resolver on
## detached, deep-copied battle state. No damage, gauge or pin rule is forked.

var _targeting := CombatAttackTargeting.new()


## A zero requested_position forecasts every eligible ORIGINAL enemy slot.
## A nonzero position must be legal and forecasts that slot only. Unavailable
## responses never advertise a hit; target_positions is always Array[int].
func get_preview(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		pinned: CombatPinned, unravel: CombatUnravel,
		first_attack: CombatTinkerFirstAttack, card_id: String,
		requested_position: int = 0) -> Dictionary:
	var refused: Dictionary = _unavailable()
	if deck == null or party == null or enemies == null or pinned == null \
			or unravel == null or first_attack == null or deck._rng == null:
		return refused
	if unravel._bound_enemies != enemies or not _valid_gauges(enemies, unravel) \
			or not _valid_pins(pinned):
		return refused
	var definition: Dictionary = _targeting.combo_definition(card_id)
	if definition.is_empty():
		return refused
	var pick: Dictionary = _targeting.get_preview(deck, party, enemies, card_id)
	if not pick.get("playable", false) or not pick.get("requires_selection", false):
		return refused
	var legal: Array[int] = pick["target_positions"]
	if requested_position != 0 and not legal.has(requested_position):
		return refused

	# A partial forecast is misleading. Check all legal targets against the
	# real resolver before simulating even one; malformed authority fails shut.
	var warden: bool = definition["owner"] == "warden"
	var warden_resolver := CombatWardenPoolComboAttacks.new()
	var tinker_resolver := CombatTinkerPoolUnravelAttacks.new(first_attack, unravel, pinned)
	for position in legal:
		var permitted: bool = (warden_resolver.can_play(
			deck, party, enemies, pinned, unravel, card_id, position) if warden
			else tinker_resolver.can_play(deck, party, enemies, card_id, position))
		if not permitted:
			return refused

	var requested: Array[int] = legal.duplicate()
	if requested_position != 0:
		requested.clear()
		requested.append(requested_position)
	var results: Array[Dictionary] = []
	for position in requested:
		var forecast: Dictionary = _detached_hit(
			deck, party, enemies, pinned, unravel, first_attack,
			card_id, position, warden)
		if forecast.is_empty():
			return refused
		results.append(forecast)
	return {
		"playable": true,
		"requires_selection": true,
		"target_positions": legal.duplicate(),
		"card_id": card_id,
		"cost": definition["cost"],
		"targets": results,
	}


func _detached_hit(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		pinned: CombatPinned, unravel: CombatUnravel,
		first_attack: CombatTinkerFirstAttack, card_id: String,
		position: int, warden: bool) -> Dictionary:
	var rng_copy := RandomNumberGenerator.new()
	rng_copy.seed = deck._rng.seed
	rng_copy.state = deck._rng.state
	var deck_copy := CombatDeck.new([], rng_copy)
	deck_copy.draw_pile.assign(deck.draw_pile)
	deck_copy.hand.assign(deck.hand)
	deck_copy.discard_pile.assign(deck.discard_pile)
	deck_copy.combat_state.player_turn_active = deck.turn_active
	deck_copy.combat_state.energy = deck.energy

	var party_copy := CombatParty.new(party.get_heroes())
	party_copy._heroes.assign(party.get_heroes())
	var enemies_copy := CombatEnemies.new(enemies.get_enemies())
	enemies_copy._enemies.assign(enemies.get_enemies())

	var pinned_copy := CombatPinned.new()
	pinned_copy._pinner_by_position = pinned._pinner_by_position.duplicate(true)
	var unravel_copy := CombatUnravel.new()
	if not unravel_copy.bind_roster(enemies_copy, unravel._tiers_by_position.duplicate(true)):
		return {}
	unravel_copy._gauges = unravel._gauges.duplicate(true)
	var latch_copy := CombatTinkerFirstAttack.new()
	latch_copy._consumed = first_attack._consumed
	latch_copy._path_bonus = first_attack._path_bonus

	var gauge_before: Dictionary = unravel.get_snapshot(position)
	var pin_before: String = pinned.pinner_for_enemy(position)
	var pin_bonus: int = pinned.bonus_for_attack(enemies, position, "warden" if warden else "tinker")
	var first_bonus: int = 0 if warden else first_attack.bonus_for_attack(card_id)
	var event: Dictionary
	if warden:
		event = CombatWardenPoolComboAttacks.new().play_attack(
			deck_copy, party_copy, enemies_copy, pinned_copy, unravel_copy,
			card_id, position)
	else:
		event = CombatTinkerPoolUnravelAttacks.new(
			latch_copy, unravel_copy, pinned_copy).play_attack(
			deck_copy, party_copy, enemies_copy, card_id, position)
	if not event.get("ok", false):
		return {}
	var hits: Array = event.get("hits", [])
	if hits.size() != 1 or not hits[0] is Dictionary:
		return {}
	var hit: Dictionary = hits[0]
	var gauge_after: Dictionary = unravel_copy.get_snapshot(position)
	var skip_after: Dictionary = {}
	if gauge_after.get("skip_pending", false) and not enemies_copy.is_slain(position):
		# Model only the future skip, using the existing authoritative service.
		if not unravel_copy.consume_action_skip(enemies_copy, position):
			return {}
		skip_after = unravel_copy.get_snapshot(position)
	var surviving: bool = not enemies_copy.is_slain(position)
	var before_enemy: Dictionary = enemies.get_enemy(position)
	var after_enemy: Dictionary = enemies_copy.get_enemy(position)
	var added: int = int(hit.get("unravel_added", 0) if warden else hit.get("unravel", 0))
	return {
		"position": position,
		"damage": hit["damage"],
		"block_absorbed": hit["block_absorbed"],
		"hp_loss": hit["hp_loss"],
		"hp_after": after_enemy["hp"],
		"block_after": after_enemy["block"],
		"survives": surviving,
		"pin_bonus": pin_bonus,
		"pin_owner_before": pin_before,
		"pin_owner_after": pinned_copy.pinner_for_enemy(position),
		"pin_consumed": bool(hit.get("pin_consumed", false)) if warden else pin_bonus > 0,
		"pin_applied": bool(hit.get("pin_applied", false)) if warden else false,
		"unravel_added": added,
		"unravel_before": gauge_before,
		"unravel_after": gauge_after,
		"after_action_skip": skip_after,
		"tinker_first_attack_bonus": first_bonus,
		"conditional_empowered": not warden and card_id.begins_with("tinker_snip_the_seam") \
			and (gauge_before["unravelled"] or gauge_before["skip_pending"] \
			or gauge_before["gauge"] * 2 >= gauge_before["threshold"]),
		"target_hp_before": before_enemy["hp"],
		"target_block_before": before_enemy["block"],
	}


func _valid_gauges(enemies: CombatEnemies, unravel: CombatUnravel) -> bool:
	if not enemies.is_valid():
		return false
	var roster: Array[Dictionary] = enemies.get_enemies()
	if unravel._gauges.size() != roster.size() or unravel._tiers_by_position.size() != roster.size():
		return false
	for index in range(roster.size()):
		var position: int = index + 1
		var tier: Variant = unravel._tiers_by_position.get(position)
		if not tier is String or tier not in CombatUnravel.VALID_TIERS:
			return false
		var initial: int = (CombatUnravel.THRESHOLD_NORMAL if tier == "normal" else
			CombatUnravel.THRESHOLD_ELITE if tier == "elite" else CombatUnravel.THRESHOLD_BOSS)
		var snap: Dictionary = unravel.get_snapshot(position)
		if not CombatWardenPoolComboAttacks.new()._valid_gauge(snap):
			return false
		var threshold: int = snap["threshold"]
		if threshold < initial or (threshold - initial) % CombatUnravel.THRESHOLD_INCREMENT != 0:
			return false
		if snap["skip_pending"] and snap["gauge"] != threshold:
			return false
		if roster[index].get("position") != position:
			return false
		if not enemies.is_slain(position) \
				and not unravel._validate_roster_and_position(enemies, position):
			return false
	return true


func _valid_pins(pinned: CombatPinned) -> bool:
	for position in pinned._pinner_by_position:
		if not position is int or position < 1 or position > CombatEnemies.MAX_ENEMIES:
			return false
		var owner: Variant = pinned._pinner_by_position[position]
		if not owner is String or not pinned._valid_pinner_id(owner):
			return false
	return true


func _unavailable() -> Dictionary:
	var positions: Array[int] = []
	var targets: Array[Dictionary] = []
	return {
		"playable": false,
		"requires_selection": false,
		"target_positions": positions,
		"card_id": "",
		"cost": 0,
		"targets": targets,
	}
