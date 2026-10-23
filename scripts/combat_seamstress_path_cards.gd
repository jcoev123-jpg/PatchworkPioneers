class_name CombatSeamstressPathCards
extends RefCounted
## Deterministic scene-free combat resolver for Seamstress Hero Path cards (D2-5).
## Resolves Bloodline Leech Stitch and Unpicker Fray from a genuine shared CombatDeck.
## No scene dependencies, no UI or wall-clock calls, and no RNG advance.
##
## Bloodline:
##   Replaces Seamstress's passive with +1 Bleed when she applies Bleed.
##   Path card: seamstress_leech_stitch, cost 1, single enemy 1-3.
##   Applies Bleed 4 (3 authored + 1 Bloodline passive) to target enemy.
##   Heals the weakest living ally min(2, missing HP). Weakest living ally is
##   the hero with the lowest current HP (living only, HP > 0). Ties are broken
##   by the frontmost living party slot (position 1 > 2 > 3).
##   Downed heroes (HP 0) cannot be healed.
##
## Unpicker:
##   Replaces Seamstress's passive: when one of her cards applies Bleed, add +2 Unravel.
##   Path card: seamstress_fray, cost 1, single enemy 1-3.
##   Applies 6 Unravel in total (4 authored + 2 Unpicker passive) and Bleed 1.
##   Does not do direct damage, does not acquire Bloodline's extra Bleed.
##   Roster-bound CombatUnravel handles pending action skips and threshold progression.
##   Does not simulate the later turn-end Bleed tick during card play.
##
## Path selection is exclusive: Bloodline can use only Leech Stitch, Unpicker can use only Fray.
## Receipts are verified against authored data/heroes/seamstress_paths.json.

const OWNER_ID := "seamstress"
const BLOODLINE_PATH := "bloodline"
const UNPICKER_PATH := "unpicker"
const LEECH_STITCH_ID := "seamstress_leech_stitch"
const FRAY_ID := "seamstress_fray"

const BLOODLINE_BLEED := 4 # 3 authored + 1 Bloodline passive
const LEECH_STITCH_HEAL := 2 # 2 HP capped to missing HP
const FRAY_BLEED := 1 # 1 authored, no Bloodline bonus
const FRAY_UNRAVEL := 6 # 4 authored + 2 Unpicker passive
const CARD_COST := 1

var _receipt: Dictionary = {}
var _unravel: CombatUnravel = null


func _init(receipt: Variant = null, unravel: CombatUnravel = null) -> void:
	if receipt is Dictionary:
		bind_choice(receipt)
	if unravel is CombatUnravel:
		bind_unravel(unravel)


func bind_choice(receipt: Variant) -> bool:
	if not receipt is Dictionary or (receipt as Dictionary).is_empty():
		_receipt = {}
		return false
	var path_id = receipt.get("path_id")
	var card_id := ""
	if path_id == BLOODLINE_PATH:
		card_id = LEECH_STITCH_ID
	elif path_id == UNPICKER_PATH:
		card_id = FRAY_ID
	else:
		_receipt = {}
		return false
	var check: Dictionary = _validate_receipt(receipt, card_id)
	if not check.get("ok", false):
		_receipt = {}
		return false
	_receipt = (receipt as Dictionary).duplicate(true)
	return true


func bind_unravel(unravel: CombatUnravel) -> void:
	_unravel = unravel


func get_receipt() -> Dictionary:
	return _receipt.duplicate(true)


func get_path_id() -> String:
	return str(_receipt.get("path_id", ""))


func get_card_id() -> String:
	return str(_receipt.get("card", {}).get("id", ""))


func is_valid_choice() -> bool:
	if _receipt.is_empty():
		return false
	var path_id = _receipt.get("path_id")
	var card_id := ""
	if path_id == BLOODLINE_PATH:
		card_id = LEECH_STITCH_ID
	elif path_id == UNPICKER_PATH:
		card_id = FRAY_ID
	return _validate_receipt(_receipt, card_id).get("ok", false)


func can_play(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		arg4: Variant = null, arg5: Variant = null, arg6: Variant = null, arg7: Variant = null) -> bool:
	var parsed: Dictionary = _parse_args(arg4, arg5, arg6, arg7)
	var plan: Dictionary = _prepare(deck, party, enemies, parsed["card_id"], parsed["target_position"],
			parsed["unravel"], parsed["receipt"])
	return plan.get("ok", false)


func preview(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		arg4: Variant = null, arg5: Variant = null, arg6: Variant = null, arg7: Variant = null) -> Dictionary:
	var parsed: Dictionary = _parse_args(arg4, arg5, arg6, arg7)
	var plan: Dictionary = _prepare(deck, party, enemies, parsed["card_id"], parsed["target_position"],
			parsed["unravel"], parsed["receipt"])
	if not plan.get("ok", false):
		return {"ok": false}
	return {
		"ok": true,
		"card_id": plan["card_id"],
		"path_id": plan["path_id"],
		"target_position": plan["target_position"],
		"bleed_applied": plan["bleed_applied"],
		"healed_slot": plan["healed_slot"],
		"healed_amount": plan["healed_amount"],
		"unravel_applied": plan["unravel_applied"],
	}


func forecast(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		arg4: Variant = null, arg5: Variant = null, arg6: Variant = null, arg7: Variant = null) -> Dictionary:
	return preview(deck, party, enemies, arg4, arg5, arg6, arg7)


func play(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		arg4: Variant = null, arg5: Variant = null, arg6: Variant = null, arg7: Variant = null) -> Dictionary:
	return play_card(deck, party, enemies, arg4, arg5, arg6, arg7)


func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		arg4: Variant = null, arg5: Variant = null, arg6: Variant = null, arg7: Variant = null) -> Dictionary:
	var parsed: Dictionary = _parse_args(arg4, arg5, arg6, arg7)
	var plan: Dictionary = _prepare(deck, party, enemies, parsed["card_id"], parsed["target_position"],
			parsed["unravel"], parsed["receipt"])
	if not plan.get("ok", false):
		return {"ok": false}

	var cost := CARD_COST
	if not deck.try_spend_energy(cost):
		return {"ok": false}

	var card_id: String = plan["card_id"]
	if not deck.discard_played(card_id):
		return {"ok": false}

	var path_id: String = plan["path_id"]
	var target_position: int = plan["target_position"]

	if path_id == BLOODLINE_PATH:
		var bleed_amount: int = plan["bleed_applied"]
		enemies.apply_statuses({target_position: {"bleed": bleed_amount}})
		var heal_slot: int = plan["healed_slot"]
		party.heal(heal_slot, LEECH_STITCH_HEAL)
		return {
			"ok": true,
			"card_id": card_id,
			"path_id": path_id,
			"target_position": target_position,
			"bleed_applied": bleed_amount,
			"healed_slot": heal_slot,
			"healed_amount": plan["healed_amount"],
			"unravel_applied": 0,
			"unravel_snapshot": {},
		}
	else:
		var unravel_service: CombatUnravel = plan["unravel"]
		var unravel_amount: int = plan["unravel_applied"]
		unravel_service.apply_unravel(enemies, target_position, unravel_amount)
		var bleed_amount: int = plan["bleed_applied"]
		enemies.apply_statuses({target_position: {"bleed": bleed_amount}})
		return {
			"ok": true,
			"card_id": card_id,
			"path_id": path_id,
			"target_position": target_position,
			"bleed_applied": bleed_amount,
			"healed_slot": 0,
			"healed_amount": 0,
			"unravel_applied": unravel_amount,
			"unravel_snapshot": unravel_service.get_snapshot(target_position),
		}


func _parse_args(arg4: Variant, arg5: Variant, arg6: Variant, arg7: Variant) -> Dictionary:
	var card_id := ""
	var target_position := 0
	var unravel: CombatUnravel = _unravel
	var receipt: Variant = _receipt

	for arg in [arg4, arg5, arg6, arg7]:
		if arg == null:
			continue
		if arg is String:
			card_id = arg
		elif typeof(arg) == TYPE_INT:
			target_position = arg
		elif typeof(arg) == TYPE_FLOAT and is_finite(arg) and floor(arg) == arg:
			target_position = int(arg)
		elif arg is CombatUnravel:
			unravel = arg
		elif arg is Dictionary:
			receipt = arg

	return {
		"card_id": card_id,
		"target_position": target_position,
		"unravel": unravel,
		"receipt": receipt,
	}


func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int, unravel: CombatUnravel, receipt: Variant) -> Dictionary:
	if deck == null or not (deck is CombatDeck):
		return {"ok": false}
	if party == null or not (party is CombatParty) or not party.is_valid():
		return {"ok": false}
	if enemies == null or not (enemies is CombatEnemies) or not enemies.is_valid() or enemies.is_defeated():
		return {"ok": false}

	var receipt_val: Dictionary = _validate_receipt(receipt, card_id)
	if not receipt_val.get("ok", false):
		return {"ok": false}
	var path_id: String = receipt_val["path_id"]

	if not deck.turn_active:
		return {"ok": false}
	if not deck.hand.has(card_id):
		return {"ok": false}
	if deck.energy < CARD_COST:
		return {"ok": false}

	# Verify Seamstress in party
	var heroes: Array[Dictionary] = party.get_heroes()
	if not CombatStatusTurnBatch.new().tick_side("heroes", heroes)["ok"]:
		return {"ok": false}
	var seamstress_count := 0
	var seamstress_hero: Dictionary = {}
	for hero in heroes:
		if hero.get("id") == OWNER_ID:
			seamstress_count += 1
			seamstress_hero = hero
	if seamstress_count != 1:
		return {"ok": false}
	var seamstress_pos: int = int(seamstress_hero.get("position", 0))
	if seamstress_pos < 1 or seamstress_pos > CombatParty.PARTY_SIZE:
		return {"ok": false}
	if party.is_downed(seamstress_pos) or int(seamstress_hero.get("hp", 0)) <= 0:
		return {"ok": false}

	# Verify target enemy
	if target_position < 1 or target_position > CombatEnemies.MAX_ENEMIES:
		return {"ok": false}
	var enemy: Dictionary = enemies.get_enemy(target_position)
	if enemy.is_empty():
		return {"ok": false}
	if enemies.is_slain(target_position) or int(enemy.get("hp", 0)) <= 0:
		return {"ok": false}
	if not CombatStatusTurnBatch.new().tick_side("enemies", enemies.get_enemies())["ok"]:
		return {"ok": false}

	var weakest_slot := 0
	var healed_amount := 0

	if path_id == BLOODLINE_PATH:
		if not enemies.can_apply_statuses({target_position: {"bleed": BLOODLINE_BLEED}}):
			return {"ok": false}

		# Find weakest living ally (lowest current HP, frontmost position tie-break)
		var lowest_hp := CombatParty.MAX_INT
		for pos in range(1, CombatParty.PARTY_SIZE + 1):
			if party.is_downed(pos):
				continue
			var h: Dictionary = party.get_hero(pos)
			if h.is_empty() or int(h.get("hp", 0)) <= 0:
				continue
			var hp: int = int(h.get("hp", 0))
			if hp < lowest_hp:
				lowest_hp = hp
				weakest_slot = pos

		if weakest_slot < 1:
			return {"ok": false}
		var target_hero: Dictionary = party.get_hero(weakest_slot)
		var missing_hp: int = maxi(0, int(target_hero.get("max_hp", 0)) - int(target_hero.get("hp", 0)))
		healed_amount = mini(LEECH_STITCH_HEAL, missing_hp)
	elif path_id == UNPICKER_PATH:
		if unravel == null or not (unravel is CombatUnravel):
			return {"ok": false}
		if unravel._bound_enemies != enemies:
			return {"ok": false}
		if unravel.get_snapshot(target_position).is_empty():
			return {"ok": false}
		if not enemies.can_apply_statuses({target_position: {"bleed": FRAY_BLEED}}):
			return {"ok": false}
	else:
		return {"ok": false}

	return {
		"ok": true,
		"card_id": card_id,
		"path_id": path_id,
		"target_position": target_position,
		"bleed_applied": BLOODLINE_BLEED if path_id == BLOODLINE_PATH else FRAY_BLEED,
		"healed_slot": weakest_slot,
		"healed_amount": healed_amount,
		"unravel_applied": 0 if path_id == BLOODLINE_PATH else FRAY_UNRAVEL,
		"unravel": unravel,
	}


func _validate_receipt(receipt: Variant, card_id: String) -> Dictionary:
	if not receipt is Dictionary or (receipt as Dictionary).is_empty():
		return {"ok": false}
	var r: Dictionary = receipt
	if r.get("ok") != true:
		return {"ok": false}
	if r.get("owner") != OWNER_ID:
		return {"ok": false}
	var path_id: Variant = r.get("path_id")
	if not path_id is String:
		return {"ok": false}
	if path_id != BLOODLINE_PATH and path_id != UNPICKER_PATH:
		return {"ok": false}

	# Exclusivity: Bloodline can only use Leech Stitch, Unpicker can only use Fray
	if path_id == BLOODLINE_PATH and card_id != LEECH_STITCH_ID:
		return {"ok": false}
	if path_id == UNPICKER_PATH and card_id != FRAY_ID:
		return {"ok": false}

	var choice := RunSeamstressPathChoice.new()
	if not choice.is_valid():
		return {"ok": false}
	var expected_path: Dictionary = choice.get_path(path_id)
	if expected_path.is_empty():
		return {"ok": false}

	if r.get("display_name") != expected_path.get("display_name"):
		return {"ok": false}
	if not _deep_equal(r.get("passive"), expected_path.get("passive")):
		return {"ok": false}
	if not _deep_equal(r.get("card"), expected_path.get("card")):
		return {"ok": false}

	var deck_val: Variant = r.get("deck")
	if not deck_val is Array:
		return {"ok": false}
	var candidate_deck: Array = deck_val
	var base_deck: Array[String] = choice.get_base_deck()
	if candidate_deck.size() != base_deck.size() + 1:
		return {"ok": false}

	var expected_counts: Dictionary = {}
	for base_id in base_deck:
		expected_counts[base_id] = int(expected_counts.get(base_id, 0)) + 1
	expected_counts[card_id] = int(expected_counts.get(card_id, 0)) + 1

	var candidate_counts: Dictionary = {}
	for item in candidate_deck:
		if not item is String:
			return {"ok": false}
		var item_id: String = item
		candidate_counts[item_id] = int(candidate_counts.get(item_id, 0)) + 1

	if candidate_counts != expected_counts:
		return {"ok": false}

	# Must not contain the other path card
	var other_path_card: String = FRAY_ID if path_id == BLOODLINE_PATH else LEECH_STITCH_ID
	if candidate_counts.get(other_path_card, 0) > 0:
		return {"ok": false}

	return {"ok": true, "path_id": path_id, "path": expected_path}


func _deep_equal(a: Variant, b: Variant) -> bool:
	var norm_a: Variant = _normalize(a)
	var norm_b: Variant = _normalize(b)
	if typeof(norm_a) != typeof(norm_b):
		return false
	if norm_a is Array:
		var arr_a: Array = norm_a
		var arr_b: Array = norm_b
		if arr_a.size() != arr_b.size():
			return false
		for i in range(arr_a.size()):
			if not _deep_equal(arr_a[i], arr_b[i]):
				return false
		return true
	if norm_a is Dictionary:
		var dict_a: Dictionary = norm_a
		var dict_b: Dictionary = norm_b
		if dict_a.size() != dict_b.size():
			return false
		for key in dict_a:
			if not dict_b.has(key):
				return false
			if not _deep_equal(dict_a[key], dict_b[key]):
				return false
		return true
	return norm_a == norm_b


func _normalize(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT:
		var f: float = value
		if is_finite(f) and floor(f) == f:
			return int(f)
		return f
	if value is Array:
		var res: Array = []
		for item in value:
			res.append(_normalize(item))
		return res
	if value is Dictionary:
		var res: Dictionary = {}
		for k in value:
			res[k] = _normalize(value[k])
		return res
	return value
