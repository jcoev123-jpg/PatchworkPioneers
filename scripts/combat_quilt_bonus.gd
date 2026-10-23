class_name CombatQuiltBonus
extends RefCounted
## Scene-free receipt tracker. Only callers of successfully committed card plays
## may record an owner; stitched plays report each of their two owners afterward.

const HERO_IDS: Array[String] = ["warden", "seamstress", "tinker"]
const FELT_COLORS := {
	"warden": "#4a5d73",
	"seamstress": "#6e4f6b",
	"tinker": "#c49a3a",
}
const BLOCK_REWARD := 3

var _party: CombatParty
var _deck: CombatDeck
var _active := false
var _awarded := false
var _played: Dictionary = {}


func _init(party: CombatParty, deck: CombatDeck) -> void:
	_party = party
	_deck = deck
	_clear_progress()


## Call once immediately after a successful CombatDeck.start_turn().
func begin_player_turn() -> bool:
	if _active or not _bindings_valid() or not _deck.turn_active:
		return false
	_clear_progress()
	_awarded = false
	_active = true
	return true


## This never executes an attempted play: the caller supplies a committed owner.
## The currently living ID set is authoritative even after a swap or a downing.
func record_confirmed_play(owner_id: String) -> Dictionary:
	var rejected := {"ok": false, "triggered": false, "drawn": 0}
	if not _active or not _bindings_valid() or not _deck.turn_active:
		return rejected
	if not _played.has(owner_id):
		return rejected
	var living := _living_heroes()
	if living.is_empty():
		return rejected
	var owner_lives := false
	for hero in living:
		if hero["id"] == owner_id:
			owner_lives = true
			break
	if not owner_lives:
		return rejected
	if _awarded or _played[owner_id]:
		return {"ok": true, "triggered": false, "drawn": 0}

	# Preflight every recipient before changing any Block. A full Block
	# recipient must not cause a partially applied party-wide reward.
	var completes := true
	for hero in living:
		if hero["id"] != owner_id and not _played[hero["id"]]:
			completes = false
	if completes:
		for hero in living:
			var block = hero.get("block")
			if not block is int or block < 0 or block > CombatParty.MAX_INT - BLOCK_REWARD:
				return rejected

	_played[owner_id] = true
	if not completes:
		return {"ok": true, "triggered": false, "drawn": 0}
	for hero in living:
		_party.gain_block(hero["position"], BLOCK_REWARD)
	var drawn: int = _deck.draw_extra(1)
	_awarded = true
	return {"ok": true, "triggered": true, "drawn": drawn}


## Two-owner confirmation for a successfully committed stitched card. Both owners
## are credited as one boundary; never executes, charges or resolves the card.
func record_confirmed_stitched_play(first_owner_id: String, second_owner_id: String) -> Dictionary:
	var rejected := {"ok": false, "triggered": false, "drawn": 0}
	if not _active or not _bindings_valid() or not _deck.turn_active:
		return rejected
	if first_owner_id == second_owner_id:
		return rejected
	if not _played.has(first_owner_id) or not _played.has(second_owner_id):
		return rejected
	var living := _living_heroes()
	if living.is_empty():
		return rejected
	var first_lives := false
	var second_lives := false
	for hero in living:
		if hero["id"] == first_owner_id:
			first_lives = true
		if hero["id"] == second_owner_id:
			second_lives = true
	if not first_lives or not second_lives:
		return rejected
	if _awarded:
		return {"ok": true, "triggered": false, "drawn": 0}
	var mark_first: bool = not _played[first_owner_id]
	var mark_second: bool = not _played[second_owner_id]
	if not mark_first and not mark_second:
		return {"ok": true, "triggered": false, "drawn": 0}

	var completes := true
	for hero in living:
		var id: String = hero["id"]
		var will_be_played: bool = _played.get(id, false)
		if id == first_owner_id or id == second_owner_id:
			will_be_played = true
		if not will_be_played:
			completes = false
	if completes:
		for hero in living:
			var block = hero.get("block")
			if not block is int or block < 0 or block > CombatParty.MAX_INT - BLOCK_REWARD:
				return rejected

	if mark_first:
		_played[first_owner_id] = true
	if mark_second:
		_played[second_owner_id] = true
	if not completes:
		return {"ok": true, "triggered": false, "drawn": 0}
	for hero in living:
		_party.gain_block(hero["position"], BLOCK_REWARD)
	var drawn: int = _deck.draw_extra(1)
	_awarded = true
	return {"ok": true, "triggered": true, "drawn": drawn}


## Call after CombatDeck.end_turn(); do not close an active hand prematurely.
func end_player_turn() -> void:
	if _active and _deck != null and not _deck.turn_active:
		_active = false


## A fully detached read keyed by stable hero ID for the later felt-bar UI.
func get_patch_progress() -> Dictionary:
	var living_ids: Array[String] = []
	if _party != null and _party.is_valid():
		for hero in _party.get_heroes():
			if hero.get("hp", 0) > 0 and hero.get("id") in HERO_IDS:
				living_ids.append(hero["id"])
	var patches := {}
	for id in HERO_IDS:
		patches[id] = {
			"living": id in living_ids,
			"played": _played.get(id, false),
			"color": FELT_COLORS[id],
		}
	return {"active": _active, "awarded": _awarded, "patches": patches}


func _clear_progress() -> void:
	_played = {"warden": false, "seamstress": false, "tinker": false}


func _bindings_valid() -> bool:
	if _party == null or _deck == null or not is_instance_valid(_party) or not is_instance_valid(_deck):
		return false
	if not _party.is_valid() or _deck.combat_state == null or _deck._rng == null:
		return false
	var ids: Array[String] = []
	var heroes := _party.get_heroes()
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = heroes[index]
		var id = hero.get("id")
		if not id is String or not id in HERO_IDS or id in ids:
			return false
		if hero.get("position") != index + 1 or not hero.get("hp") is int:
			return false
		ids.append(id)
	return ids.size() == HERO_IDS.size()


func _living_heroes() -> Array[Dictionary]:
	var living: Array[Dictionary] = []
	for hero in _party.get_heroes():
		if hero["hp"] > 0:
			living.append(hero)
	return living
