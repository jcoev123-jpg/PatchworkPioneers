class_name CombatWardenPathCards
extends RefCounted
## Scene-free Warden Hero Path held-card rules (D2-5 / M06).
##
## Resolves the two authored Warden Path cards against a committed shared
## CombatDeck, using a genuine RunWardenPathChoice receipt:
##   Bulwark  -> warden_bulwark_brace: cost 1, from positions 1-3, self,
##               effects {"block": 9}. On success the living current Warden
##               gains exactly 9 Block; no enemy and no other hero is touched.
##   Vanguard -> warden_lance_pin: cost 1, from position 1, enemy_single in
##               slots 1-2, effects {"damage": 6, "pinned": true}. On success
##               the hit uses CombatStatusAttacks (Weak -25%, Exposed +50%,
##               floor rounding) and normal enemy Block-before-HP damage. Any
##               existing cross-owner Pinned contributes +5 BEFORE Weak/Exposed
##               and is consumed; a surviving target receives a Warden-owned
##               Pinned token (replacing the old one), a lethal hit leaves none.
##
## Path selection is exclusive: a Bulwark receipt can only hold Bulwark Brace
## and a Vanguard receipt can only hold Lance Pin. No PRNG is drawn, no
## wall-clock is read, and no scene state is used. The live hand dispatch that
## passes the selected receipt/deck here is a later M06 integration task.
##
## Both Paths keep their passives (replaced opening Block 10 / first confirmed
## attack pins) out of this service; passive application is a later hookup.

const WARDEN_ID := "warden"
const BULWARK_PATH := "bulwark"
const VANGUARD_PATH := "vanguard"
const BULWARK_BRACE_ID := "warden_bulwark_brace"
const LANCE_PIN_ID := "warden_lance_pin"
const PATH_CARD := {
	BULWARK_PATH: BULWARK_BRACE_ID,
	VANGUARD_PATH: LANCE_PIN_ID,
}

var _status_attacks := CombatStatusAttacks.new()
var _statuses := CombatStatuses.new()


## Attempts to play one Warden Path card from the shared hand.
## Success: {ok: true, card_id, path_id, energy_spent, discarded, ...}.
## Rejection: {ok: false} with no deck, party, enemy, Pinned or RNG mutation.
## target_position is the enemy slot for enemy_single cards and 0 for self cards.
## pinned is the battle's shared CombatPinned authority (never a private store).
func play(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies, card_id: String,
		target_position: int, receipt: Dictionary, pinned: CombatPinned) -> Dictionary:
	var plan := _prepare(deck, party, enemies, card_id, target_position, receipt, pinned)
	if not plan.get("ok", false):
		return {"ok": false}
	if plan["path_id"] == BULWARK_PATH:
		return _execute_bulwark_brace(deck, party, plan)
	return _execute_lance_pin(deck, enemies, pinned, plan)


## Pure forecast for later live previews: reports the playable target slots and
## the expected Block/damage/pin without mutating any gameplay state.
func forecast(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies, card_id: String,
		receipt: Dictionary, pinned: CombatPinned) -> Dictionary:
	var rejected := {
		"ok": false,
		"playable": false,
		"card_id": "",
		"path_id": "",
		"requires_selection": false,
		"target_positions": [],
		"targets": [],
		"expected_block": 0,
		"expected_damage": 0,
		"pinned_bonus": 0,
		"will_apply_pin": false,
	}
	var gate := _validate_receipt(receipt, card_id)
	if not gate.get("ok", false):
		return rejected
	var card: Dictionary = gate["card"]
	if card.get("target_kind") == "self":
		var self_plan := _prepare(deck, party, enemies, card_id, 0, receipt, pinned)
		if not self_plan.get("ok", false):
			return rejected
		return {
			"ok": true,
			"playable": true,
			"card_id": card_id,
			"path_id": gate["path_id"],
			"requires_selection": false,
			"target_positions": [],
			"targets": [],
			"expected_block": self_plan["block_amount"],
			"expected_damage": 0,
			"pinned_bonus": 0,
			"will_apply_pin": false,
		}

	var target_positions: Array[int] = []
	var targets: Array = []
	for raw_position in card.get("to_positions", []):
		var position: int = int(raw_position)
		var plan := _prepare(deck, party, enemies, card_id, position, receipt, pinned)
		if not plan.get("ok", false):
			continue
		target_positions.append(position)
		targets.append({
			"position": position,
			"expected_damage": plan["damage"],
			"pinned_bonus": plan["pinned_bonus"],
			"will_apply_pin": true,
		})
	if target_positions.is_empty():
		return rejected
	var first: Dictionary = targets[0]
	return {
		"ok": true,
		"playable": true,
		"card_id": card_id,
		"path_id": gate["path_id"],
		"requires_selection": true,
		"target_positions": target_positions,
		"targets": targets,
		"expected_block": 0,
		"expected_damage": first["expected_damage"],
		"pinned_bonus": first["pinned_bonus"],
		"will_apply_pin": true,
	}


## Pure preflight shared by play() and forecast(). Never mutates gameplay state.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies, card_id: String,
		target_position: int, receipt: Dictionary, pinned: CombatPinned) -> Dictionary:
	if deck == null or party == null or enemies == null:
		return {"ok": false}
	if pinned == null or not (pinned is CombatPinned):
		return {"ok": false}
	if not deck.turn_active or not party.is_valid() or not enemies.is_valid():
		return {"ok": false}
	if enemies.is_victorious():
		return {"ok": false}

	# The receipt must be exactly the receipt a fresh single claim produces for
	# this path, and it must carry this path's own card (never the other path's).
	var gate := _validate_receipt(receipt, card_id)
	if not gate.get("ok", false):
		return {"ok": false}
	var card: Dictionary = gate["card"]
	var path_id: String = gate["path_id"]

	if not deck.hand.has(card_id):
		return {"ok": false}
	var cost: int = card.get("cost", -1)
	if cost < 0 or deck.energy < cost:
		return {"ok": false}

	# The Warden's current party slot can differ from the starting slot; read it.
	var warden_position := 0
	var warden_count := 0
	for hero in party.get_heroes():
		if hero.get("id") == WARDEN_ID:
			warden_count += 1
			warden_position = int(hero.get("position", 0))
	if warden_count != 1 or warden_position < 1 or warden_position > CombatParty.PARTY_SIZE:
		return {"ok": false}
	if party.is_downed(warden_position):
		return {"ok": false}
	var from_positions: Array = card.get("from_positions", [])
	if not from_positions.has(warden_position):
		return {"ok": false}

	var effects: Dictionary = card.get("effects", {})
	var target_kind: String = card.get("target_kind", "")
	if target_kind == "self":
		# Self cards take no enemy selection; the only recipient is the Warden.
		if target_position != 0:
			return {"ok": false}
		var block_amount: int = effects.get("block", -1)
		if block_amount < 0:
			return {"ok": false}
		return {
			"ok": true,
			"path_id": path_id,
			"card_id": card_id,
			"cost": cost,
			"warden_position": warden_position,
			"target_position": warden_position,
			"block_amount": block_amount,
		}

	if target_kind != "enemy_single":
		return {"ok": false}
	var to_positions: Array = card.get("to_positions", [])
	if not to_positions.has(target_position):
		return {"ok": false}
	var enemy := enemies.get_enemy(target_position)
	if enemy.is_empty() or enemies.is_slain(target_position):
		return {"ok": false}

	var base_damage: int = effects.get("damage", -1)
	if base_damage < 0:
		return {"ok": false}
	var warden_hero := party.get_hero(warden_position)
	var attacker_statuses: Dictionary = warden_hero.get("statuses", {})
	var defender_statuses: Dictionary = enemy.get("statuses", {})
	if not _valid_statuses(attacker_statuses) or not _valid_statuses(defender_statuses):
		return {"ok": false}

	# Existing cross-owner Pinned adds +5 before Weak/Exposed; the same owner gets 0.
	var pinned_bonus: int = pinned.bonus_for_attack(enemies, target_position, WARDEN_ID)
	var total_base: int = base_damage + pinned_bonus
	var adjusted: int = _statuses.adjusted_attack_damage(
		total_base, attacker_statuses, defender_statuses)
	if total_base > 0 and adjusted <= 0:
		# The existing formula failed closed for valid statuses; never spend on it.
		return {"ok": false}

	return {
		"ok": true,
		"path_id": path_id,
		"card_id": card_id,
		"cost": cost,
		"warden_position": warden_position,
		"target_position": target_position,
		"base_damage": base_damage,
		"total_base_damage": total_base,
		"damage": adjusted,
		"pinned_bonus": pinned_bonus,
		"attacker_statuses": attacker_statuses,
		"defender_statuses": defender_statuses,
	}


func _execute_bulwark_brace(deck: CombatDeck, party: CombatParty, plan: Dictionary) -> Dictionary:
	# Preflight proved every step can succeed; a false below is unreachable.
	var cost: int = plan["cost"]
	var card_id: String = plan["card_id"]
	var warden_position: int = plan["warden_position"]
	var block_amount: int = plan["block_amount"]
	if not deck.try_spend_energy(cost):
		return {"ok": false}
	if not deck.discard_played(card_id):
		return {"ok": false}
	if not party.gain_block(warden_position, block_amount):
		return {"ok": false}
	return {
		"ok": true,
		"card_id": plan["card_id"],
		"path_id": plan["path_id"],
		"energy_spent": plan["cost"],
		"discarded": plan["card_id"],
		"warden_position": plan["warden_position"],
		"block_gained": plan["block_amount"],
		"pinned_bonus": 0,
		"pinned_applied": false,
		"pinner": "",
		"hits": [{
			"position": plan["warden_position"],
			"damage": 0,
			"block_absorbed": 0,
			"hp_loss": 0,
			"block_gained": plan["block_amount"],
			"statuses": {},
		}],
	}


func _execute_lance_pin(deck: CombatDeck, enemies: CombatEnemies,
		pinned: CombatPinned, plan: Dictionary) -> Dictionary:
	# Preflight proved every step can succeed; a false below is unreachable.
	var cost: int = plan["cost"]
	var card_id: String = plan["card_id"]
	var target_position: int = plan["target_position"]
	var total_base_damage: int = plan["total_base_damage"]
	var attacker_statuses: Dictionary = plan["attacker_statuses"]
	var defender_statuses: Dictionary = plan["defender_statuses"]
	if not deck.try_spend_energy(cost):
		return {"ok": false}
	if not deck.discard_played(card_id):
		return {"ok": false}

	var result := _status_attacks.resolve_vs_enemy(
		enemies, target_position, total_base_damage,
		attacker_statuses, defender_statuses)
	if not result.get("ok", false):
		return {"ok": false}

	# A confirmed cross-owner pin is consumed once by this hit; a same-owner
	# token stays (and is simply replaced below).
	pinned.consume_after_attack(target_position, WARDEN_ID, true)

	var after := enemies.get_enemy(target_position)
	var survived := not after.is_empty() and int(after.get("hp", 0)) > 0
	if survived:
		if not pinned.pin_enemy(enemies, target_position, WARDEN_ID):
			return {"ok": false}
	elif pinned.pinner_for_enemy(target_position) == WARDEN_ID:
		# A lethal hit never leaves the Warden's own pin on the slain enemy.
		pinned.clear_pin(target_position)

	return {
		"ok": true,
		"card_id": plan["card_id"],
		"path_id": plan["path_id"],
		"energy_spent": plan["cost"],
		"discarded": plan["card_id"],
		"warden_position": plan["warden_position"],
		"target_position": target_position,
		"damage": result["damage"],
		"block_absorbed": result["block_absorbed"],
		"hp_loss": result["hp_loss"],
		"pinned_bonus": plan["pinned_bonus"],
		"pinned_applied": survived,
		"pinner": WARDEN_ID if survived else "",
		"hits": [{
			"position": target_position,
			"damage": result["damage"],
			"block_absorbed": result["block_absorbed"],
			"hp_loss": result["hp_loss"],
			"pinned_bonus": plan["pinned_bonus"],
			"pinned_applied": survived,
			"statuses": {"pinned": 1} if survived else {},
		}],
	}


## Verifies the receipt is exactly the detached receipt a fresh single claim for
## this card's Path produces: correct owner/Path/card, authored passive and
## display name, and the proposed 12-card starter deck plus this one Path card.
## A forged, altered, wrong-Path or replayed-claim receipt never passes.
func _validate_receipt(receipt: Dictionary, card_id: String) -> Dictionary:
	if receipt.is_empty() or receipt.get("ok") != true:
		return {}
	if receipt.get("owner") != WARDEN_ID:
		return {}
	var path_id: Variant = receipt.get("path_id")
	if not path_id is String or not PATH_CARD.has(path_id):
		return {}
	if PATH_CARD[path_id] != card_id:
		# The other Path's card can never ride this Path's receipt.
		return {}
	var choice := RunWardenPathChoice.new()
	if not choice.is_valid():
		return {}
	var genuine: Dictionary = choice.choose(path_id)
	if not genuine.get("ok", false):
		return {}
	if not _exact_equal(receipt, genuine):
		return {}
	return {
		"ok": true,
		"path_id": path_id,
		"card": (genuine["card"] as Dictionary).duplicate(true),
	}


func _valid_statuses(statuses: Dictionary) -> bool:
	for name in statuses:
		if not name is String or name not in ["bleed", "weak", "exposed"]:
			return false
		var count = statuses[name]
		if not count is int or count < 0:
			return false
	return true


## Exact recursive comparison: same keys, same array order, same value types
## (so a tampered bool/int/float can never match an authored receipt).
func _exact_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Array:
		var left_list: Array = a
		var right_list: Array = b
		if left_list.size() != right_list.size():
			return false
		for index in left_list.size():
			if not _exact_equal(left_list[index], right_list[index]):
				return false
		return true
	if a is Dictionary:
		var left_dict: Dictionary = a
		var right_dict: Dictionary = b
		if left_dict.size() != right_dict.size():
			return false
		for key in left_dict:
			if not right_dict.has(key):
				return false
			if not _exact_equal(left_dict[key], right_dict[key]):
				return false
		return true
	return a == b
