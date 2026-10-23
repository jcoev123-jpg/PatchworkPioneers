class_name CombatWardenVanguardPassive
extends RefCounted
## Scene-free, battle-bound Vanguard passive. The live attack/turn router must
## supply the same authorities it passes to the heavy attack resolver.
## A quote is a pre-commit ticket, NOT a hit receipt. Confirmation replays the
## genuine resolver on detached pre-commit models and checks its entire result
## and post-commit state before pinning. No mutation occurs on preview/refusal.
## Future attack adapters may be added at their own authoritative commit seam.

const OWNER := "warden"
const PATH := "vanguard"

var _deck: CombatDeck
var _party: CombatParty
var _enemies: CombatEnemies
var _pinned: CombatPinned
var _attacks: CombatWardenPoolHeavyAttacks
var _patches: CombatPatchAttackRules
var _combat_state: CombatState
var _rng: RandomNumberGenerator
var _bound := false
var _phase := "unbound" # unstarted, active, between, unbound
var _used := false
var _battle_serial := 0
var _turn_serial := 0
var _ticket_serial := 0
var _pending: Dictionary = {}


## A receipt must match an independently claimed, exact authored Vanguard
## choice. The resolver must already share this precise CombatPinned instance.
## A bound service cannot be rebound; retire explicitly at battle teardown.
func bind_battle(receipt: Dictionary, deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies, pinned: CombatPinned,
		attacks: CombatWardenPoolHeavyAttacks) -> bool:
	if _bound or deck == null or party == null or enemies == null or pinned == null or attacks == null:
		return false
	if not party.is_valid() or not enemies.is_valid() or deck.combat_state == null or deck._rng == null:
		return false
	if attacks.get_pinned() != pinned:
		return false
	if attacks.get_patches() != null and not attacks.get_patches().is_valid():
		return false
	var chooser := RunWardenPathChoice.new()
	if not chooser.is_valid():
		return false
	var expected := chooser.choose(PATH)
	if not expected.get("ok", false) or not _exact(receipt, expected):
		return false
	var owner_count := 0
	for hero in party.get_heroes():
		if hero.get("id") == OWNER and hero.get("max_hp") == 40:
			owner_count += 1
	if owner_count != 1:
		return false
	_deck = deck
	_party = party
	_enemies = enemies
	_pinned = pinned
	_attacks = attacks
	_patches = attacks.get_patches()
	_combat_state = deck.combat_state
	_rng = deck._rng
	_bound = true
	_phase = "unstarted"
	_used = false
	_pending.clear()
	_battle_serial += 1
	_turn_serial = 0
	return true


func retire_battle() -> void:
	_pending.clear()
	_bound = false
	_phase = "unbound"
	_used = false
	_deck = null
	_party = null
	_enemies = null
	_pinned = null
	_attacks = null
	_patches = null
	_combat_state = null
	_rng = null


func _same_authorities(deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies, pinned: CombatPinned,
		attacks: CombatWardenPoolHeavyAttacks) -> bool:
	return _bound and deck != null and party != null and enemies != null and pinned != null \
		and attacks != null and _deck == deck and _party == party and _enemies == enemies \
		and _pinned == pinned and _attacks == attacks and _deck.combat_state == _combat_state \
		and _deck._rng == _rng and _attacks.get_pinned() == _pinned \
		and _attacks.get_patches() == _patches and (_patches == null or _patches.is_valid()) \
		and _party.is_valid() and _enemies.is_valid()


## Called only after CombatDeck.start_turn() actually succeeds. A second call
## on an active turn cannot replenish the passive. A later turn requires the
## deck's completed end_turn and this service's matching end notification.
func begin_player_turn(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		pinned: CombatPinned, attacks: CombatWardenPoolHeavyAttacks) -> bool:
	if not _same_authorities(deck, party, enemies, pinned, attacks):
		return false
	if _phase != "unstarted" and _phase != "between":
		return false
	if not deck.turn_active or deck.energy != CombatState.TURN_ENERGY:
		return false
	_phase = "active"
	_turn_serial += 1
	_used = false
	_pending.clear()
	return true


## Called after CombatDeck.end_turn() succeeds; checks the actual ended deck.
func end_player_turn(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		pinned: CombatPinned, attacks: CombatWardenPoolHeavyAttacks) -> bool:
	if not _same_authorities(deck, party, enemies, pinned, attacks) or _phase != "active":
		return false
	if deck.turn_active or deck.energy != 0 or not deck.hand.is_empty():
		return false
	_phase = "between"
	_pending.clear()
	return true


## Read-only entitlement projection for a future mounted attack preview.
func is_available(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		pinned: CombatPinned, attacks: CombatWardenPoolHeavyAttacks) -> bool:
	return _same_authorities(deck, party, enemies, pinned, attacks) \
		and _phase == "active" and deck.turn_active and not _used


func current_turn() -> int:
	return _turn_serial if _bound else 0


## One pending quote at a time. Checks the real held authored heavy card,
## Warden's living legal FROM slot and the original living TO slot via the
## resolver's own can_play. Cannot spend, pin, draw, or advance RNG.
func quote_attack(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		pinned: CombatPinned, attacks: CombatWardenPoolHeavyAttacks,
		card_id: String, target_position: int) -> Dictionary:
	if not is_available(deck, party, enemies, pinned, attacks):
		return {"ok": false}
	if not attacks.is_supported_card(card_id) \
			or not attacks.can_play(deck, party, enemies, card_id, target_position):
		return {"ok": false}
	var original := enemies.get_enemy(target_position)
	if original.is_empty() or int(original.get("hp", 0)) <= 0:
		return {"ok": false}
	_ticket_serial += 1
	var ticket := {
		"ok": true,
		"battle": _battle_serial,
		"turn": _turn_serial,
		"ticket": _ticket_serial,
		"owner": OWNER,
		"card_id": card_id,
		"target_position": target_position,
		"original_enemy_id": original.get("id", ""),
	}
	_pending = {"ticket": ticket.duplicate(true), "before": _snapshot(),
		"card_id": card_id, "target_position": target_position}
	return ticket.duplicate(true)


## Confirmation is intentionally post-commit. A caller-provided ok/hit flag
## alone proves nothing: compare the full resolver result and the actual
## energy/piles, full party/foe states, Pinned tokens and RNG state against an
## isolated deterministic replay of the quoted transaction. This also proves
## a multi-hit card finished before this passive may apply a new token.
func confirm_attack(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		pinned: CombatPinned, attacks: CombatWardenPoolHeavyAttacks,
		quote: Dictionary, result: Dictionary) -> bool:
	if not is_available(deck, party, enemies, pinned, attacks) or _pending.is_empty():
		return false
	if not _exact(quote, _pending["ticket"]) or result.get("ok") != true:
		return false
	var original: Dictionary = (_pending["before"] as Dictionary).duplicate(true)
	var predicted := _replay(original, _pending["card_id"], _pending["target_position"])
	if not predicted.get("ok", false):
		return false
	if not _exact(result, predicted["result"]) or not _exact(_snapshot(), predicted["after"]):
		return false
	var slot: int = _pending["target_position"]
	var before_enemy: Dictionary = (original["enemies"] as Array)[slot - 1]
	if enemies.get_enemy(slot).get("id") != before_enemy.get("id"):
		return false
	# The confirmed attack spends the entitlement even on a lethal first hit.
	# Pinned cannot remain on a corpse, including an old same-owner token.
	if enemies.is_slain(slot):
		pinned.clear_pin(slot)
	elif not pinned.pin_enemy(enemies, slot, OWNER):
		return false
	_used = true
	_pending.clear()
	return true


func _snapshot() -> Dictionary:
	return {
		"hand": _deck.hand.duplicate(),
		"draw": _deck.draw_pile.duplicate(),
		"discard": _deck.discard_pile.duplicate(),
		"energy": _deck.energy,
		"turn_active": _deck.turn_active,
		"heroes": _party.get_heroes(),
		"enemies": _enemies.get_enemies(),
		"pins": _pinned._pinner_by_position.duplicate(true),
		"rng": _deck._rng.state,
		"patches": _patch_snapshot(_patches),
	}


func _replay(before: Dictionary, card_id: String, slot: int) -> Dictionary:
	# Copies are never bound to the live models or live RNG; only the real
	# CombatWardenPoolHeavyAttacks executes the transaction.
	var clone_rng := RandomNumberGenerator.new()
	clone_rng.state = before["rng"]
	var empty_ids: Array[String] = []
	var clone_deck := CombatDeck.new(empty_ids, clone_rng)
	clone_deck.hand.assign(before["hand"])
	clone_deck.draw_pile.assign(before["draw"])
	clone_deck.discard_pile.assign(before["discard"])
	clone_deck.combat_state.player_turn_active = before["turn_active"]
	clone_deck.combat_state.energy = before["energy"]
	var hero_defs: Array = []
	for hero in before["heroes"]:
		hero_defs.append({"id": hero["id"], "max_hp": hero["max_hp"]})
	var clone_party := CombatParty.new(hero_defs)
	clone_party._heroes.assign((before["heroes"] as Array).duplicate(true))
	var enemy_defs: Array = []
	for enemy in before["enemies"]:
		enemy_defs.append({"id": enemy["id"], "max_hp": enemy["max_hp"]})
	var clone_enemies := CombatEnemies.new(enemy_defs)
	clone_enemies._enemies.assign((before["enemies"] as Array).duplicate(true))
	var clone_pin := CombatPinned.new()
	clone_pin._pinner_by_position = (before["pins"] as Dictionary).duplicate(true)
	var clone_patches: CombatPatchAttackRules = null
	if before["patches"] != null:
		var patch_data: Dictionary = before["patches"]
		clone_patches = CombatPatchAttackRules.new()
		clone_patches._valid = patch_data["valid"]
		clone_patches._active = (patch_data["active"] as Dictionary).duplicate(true)
		clone_patches._consumed = (patch_data["consumed"] as Dictionary).duplicate(true)
		clone_patches._worn = (patch_data["worn"] as Dictionary).duplicate(true)
		clone_patches._living = (patch_data["living"] as Dictionary).duplicate(true)
	var clone_attacks := CombatWardenPoolHeavyAttacks.new(clone_pin, clone_patches)
	if not clone_attacks.can_play(clone_deck, clone_party, clone_enemies, card_id, slot):
		return {"ok": false}
	var receipt := clone_attacks.play_attack(clone_deck, clone_party, clone_enemies, card_id, slot)
	if not receipt.get("ok", false) or (receipt.get("hits", []) as Array).is_empty():
		return {"ok": false}
	# A successful attack must truly change the original enemy's HP/Block.
	var old_foe: Dictionary = (before["enemies"] as Array)[slot - 1]
	var new_foe := clone_enemies.get_enemy(slot)
	if old_foe["hp"] == new_foe["hp"] and old_foe["block"] == new_foe["block"]:
		return {"ok": false}
	return {
		"ok": true,
		"result": receipt,
		"after": {
			"hand": clone_deck.hand.duplicate(),
			"draw": clone_deck.draw_pile.duplicate(),
			"discard": clone_deck.discard_pile.duplicate(),
			"energy": clone_deck.energy,
			"turn_active": clone_deck.turn_active,
			"heroes": clone_party.get_heroes(),
			"enemies": clone_enemies.get_enemies(),
			"pins": clone_pin._pinner_by_position.duplicate(true),
			"rng": clone_deck._rng.state,
			"patches": _patch_snapshot(clone_patches),
		},
	}


static func _patch_snapshot(patches: CombatPatchAttackRules) -> Variant:
	if patches == null:
		return null
	return {
		"valid": patches._valid,
		"active": patches._active.duplicate(true),
		"consumed": patches._consumed.duplicate(true),
		"worn": patches._worn.duplicate(true),
		"living": patches._living.duplicate(true),
	}


static func _exact(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		var left: Dictionary = a
		var right: Dictionary = b
		if left.size() != right.size():
			return false
		for key in left:
			if not right.has(key) or not _exact(left[key], right[key]):
				return false
		return true
	if a is Array:
		var left: Array = a
		var right: Array = b
		if left.size() != right.size():
			return false
		for index in left.size():
			if not _exact(left[index], right[index]):
				return false
		return true
	return a == b
